---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- How far right of centre the route/reagents split sits.
local ROUTE_SHARE = 50
local TRAIN_ICON = "Interface\\Icons\\INV_Misc_Book_11"
local SKIPPED_ICON = "Interface\\Icons\\INV_Misc_Note_01"
-- An Auctionator price older than a day is flagged: auction prices move that fast.
local STALE_AFTER = 24 * 3600

---@type SkillUpPage
local page
---@type SkillUpSideTab
local tab
local selected -- skill line shown on the page
local pending = false

---@param recipeID integer
---@return string
local function RecipeName(recipeID)
	return C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
end

---@param copper number
---@return string
local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(math.abs(copper)), copper < 0)
end

---@param recipeID integer
---@return SkillUpReagent?
local function Output(recipeID)
	local recipe = ns.RecipeData[recipeID]
	return recipe and recipe.output or nil
end

---@param recipeID integer
---@return fileID?
local function RecipeIcon(recipeID)
	local output = Output(recipeID)
	return output and C_Item.GetItemIconByID(output.itemID) or C_Spell.GetSpellTexture(recipeID)
end

---@param itemID integer
---@return ColorMixin?
local function QualityColor(itemID)
	local quality = C_Item.GetItemQualityByID(itemID)
	if not quality then
		return nil
	end
	local red, green, blue = C_Item.GetItemQualityColor(quality)
	return CreateColor(red, green, blue)
end

---@param tooltip GameTooltip
---@param left string
---@param right string
---@param rightColor ColorMixin?
local function AddLine(tooltip, left, right, rightColor)
	GameTooltip_AddColoredDoubleLine(tooltip, left, right, NORMAL_FONT_COLOR, rightColor or HIGHLIGHT_FONT_COLOR)
end

-- Not red when short: the route gets there before this step.
---@param tooltip GameTooltip
---@param profession SkillUpProfession
---@param reqSkill number?
local function RequiresLine(tooltip, profession, reqSkill)
	AddLine(tooltip, L["Requires"], reqSkill and string.format("%s (%d)", profession.name, reqSkill) or UNKNOWN)
end

-- The crafted item's own tooltip when there is one, else the recipe's name. Under the item's tooltip the
-- title is added only when it says more than the item's name already does.
---@param tooltip GameTooltip
---@param recipeID integer
---@param title string
local function RecipeTitle(tooltip, recipeID, title)
	local output = Output(recipeID)
	if output then
		tooltip:SetItemByID(output.itemID)
		GameTooltip_AddBlankLineToTooltip(tooltip)
		if title ~= C_Item.GetItemNameByID(output.itemID) then
			GameTooltip_AddNormalLine(tooltip, title)
		end
	else
		GameTooltip_SetTitle(tooltip, title)
	end
end

local BAND_LABELS = { orange = L["orange"], yellow = L["yellow"], green = L["green"], grey = L["grey"] }

-- "orange yellow green    120  132  145": each band's name and where it starts, in its colour.
---@param tooltip GameTooltip
---@param profession SkillUpProfession
---@param recipeID integer
local function AddBands(tooltip, profession, recipeID)
	local parts, names = {}, {}
	for index, band in ipairs(ns.RecipeBands(profession, recipeID)) do
		parts[index] = ns.COLORS[band.color]:WrapTextInColorCode(tostring(band.from))
		names[index] = ns.COLORS[band.color]:WrapTextInColorCode(BAND_LABELS[band.color])
	end
	if #parts > 0 then
		AddLine(tooltip, table.concat(names, " "), table.concat(parts, "  "))
	end
end

-- A recipe's own reagents with what the bags hold, one line each.
---@param tooltip GameTooltip
---@param recipeID integer
---@param crafts number
local function AddReagentLines(tooltip, recipeID, crafts)
	for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
		local name = C_Item.GetItemNameByID(reagent.itemID) or string.format(L["item %d"], reagent.itemID)
		local have = ns.Have(reagent.itemID)
		local need = reagent.quantity * crafts
		local color = have >= need and ns.COLORS.green or HIGHLIGHT_FONT_COLOR
		GameTooltip_AddColoredDoubleLine(
			tooltip,
			name,
			string.format("%d/%d", math.min(have, need), need),
			HIGHLIGHT_FONT_COLOR,
			color
		)
	end
end

-- The tools a recipe needs and the station it is made at, from the client. A tool the bags do not
-- hold is red, the same as the craft button's reason.
---@param tooltip GameTooltip
---@param recipeID integer
local function AddToolLines(tooltip, recipeID)
	for _, requirement in ipairs(ns.RecipeRequirements and ns.RecipeRequirements(recipeID) or {}) do
		local isTool = Enum.RecipeRequirementType ~= nil and requirement.type == Enum.RecipeRequirementType.Totem
		local color = requirement.met == false and ns.COLORS.red or HIGHLIGHT_FONT_COLOR
		AddLine(tooltip, isTool and L["Tool"] or L["Made at"], requirement.name, color)
	end
end

-- "Not this recipe", the way Adventure Guide Forever's "Not this quest" leaves a quest out: a right-click on any
-- step or suggestion that names a recipe leaves it out of every route on this character.
---@param recipeID integer
---@return fun(owner: Region, root: RootMenuDescriptionProxy)
local function RecipeMenu(recipeID)
	return function(_, root)
		root:CreateTitle(RecipeName(recipeID))
		root:CreateButton(L["Not this recipe"], function()
			ns.SetSkipped(recipeID, true)
		end)
		local pinned = ns.PinPreference(recipeID) > 0
		root:CreateButton(pinned and L["Unpin recipe"] or L["Pin for skill-ups"], function()
			ns.SetPinned(recipeID, not pinned)
		end)
	end
end

---@param tooltip GameTooltip
local function AddSkipHint(tooltip)
	GameTooltip_AddInstructionLine(tooltip, L["Right-click to pin or skip this recipe."])
end

---@param tooltip GameTooltip
---@param profession SkillUpProfession
---@param craft SkillUpPlanCraft
local function CraftTooltip(tooltip, profession, craft)
	local recipeID = craft.recipeID
	RecipeTitle(tooltip, recipeID, RecipeName(recipeID))
	AddLine(tooltip, L["Crafts"], string.format(L["%d, from %d to %d"], craft.crafts, craft.from, craft.to))
	if (craft.skillUps or 1) > 1 then
		AddLine(tooltip, L["Skill points a craft"], tostring(craft.skillUps))
	end
	AddBands(tooltip, profession, recipeID)
	AddToolLines(tooltip, recipeID)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	AddReagentLines(tooltip, recipeID, craft.crafts)
	AddLine(tooltip, L["Cost"], Money(ns.NetCost(recipeID) * craft.crafts))
	if ns.IsLearned(recipeID) and profession.skillLine == ns.OpenSkillLine() then
		GameTooltip_AddInstructionLine(tooltip, L["Click to open the recipe."])
	end
	AddSkipHint(tooltip)
end

---@param tooltip GameTooltip
---@param subcraft SkillUpSubCraft
local function SubCraftTooltip(tooltip, subcraft)
	local recipeID = subcraft.recipeID
	RecipeTitle(tooltip, recipeID, string.format(L["Craft %s"], RecipeName(recipeID)))
	AddLine(tooltip, L["Crafts"], tostring(subcraft.crafts))
	AddToolLines(tooltip, recipeID)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	AddReagentLines(tooltip, recipeID, subcraft.crafts)
	AddSkipHint(tooltip)
end

---@param tooltip GameTooltip
---@param profession SkillUpProfession
---@param step SkillUpPlanTraining
local function TrainTooltip(tooltip, profession, step)
	RecipeTitle(tooltip, step.recipeID, string.format(L["Train %s"], RecipeName(step.recipeID)))
	GameTooltip_AddHighlightLine(tooltip, string.format(L["Taught by %s trainers."], profession.name))
	AddLine(tooltip, L["Fee"], Money(step.fee))
	RequiresLine(tooltip, profession, step.reqSkill)
	AddLine(tooltip, L["First used at"], tostring(step.usedAt))
	AddBands(tooltip, profession, step.recipeID)
	ns.AddNearest(tooltip, L["Nearest trainer"], ns.NearestTrainer(profession, step.cap, true))
	AddSkipHint(tooltip)
end

---@param tooltip GameTooltip
---@param profession SkillUpProfession
---@param rank SkillUpRank
local function RankTooltip(tooltip, profession, rank)
	GameTooltip_SetTitle(tooltip, string.format("%s %s", rank.name, profession.name))
	GameTooltip_AddHighlightLine(tooltip, string.format(L["Raises your skill cap to %d."], rank.cap))
	if rank.book then
		GameTooltip_AddNormalLine(tooltip, L["No trainer teaches this rank: a book does."])
	elseif rank.quest then
		GameTooltip_AddNormalLine(tooltip, L["No trainer teaches this rank: a quest does."])
		AddLine(tooltip, L["Quest"], ns.RankQuestName(rank))
	end
	local held = ns.RankHeld(rank)
	if held then
		GameTooltip_AddNormalLine(tooltip, L["You have this book: read it."])
	elseif not rank.quest then
		AddLine(tooltip, rank.book and L["Price"] or L["Fee"], Money(rank.fee))
	end
	RequiresLine(tooltip, profession, rank.reqSkill)
	if rank.level > 0 then
		local color = UnitLevel("player") < rank.level and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
		AddLine(tooltip, L["Requires"], string.format(L["level %d"], rank.level), color)
	end
	if not held then
		local npcID, label = ns.NearestForRank(profession, rank, true)
		ns.AddNearest(tooltip, label, npcID)
	end
	if rank.quest then
		ns.AddQuestChainHint(tooltip)
	end
end

-- A waypoint to the nearest trainer teaching up to `cap`.
---@param profession SkillUpProfession
---@param cap number
---@return fun()
local function TrainerClick(profession, cap)
	return function()
		local npcID = ns.NearestTrainer(profession, cap, true)
		if npcID then
			ns.SetWaypoint(npcID)
		end
	end
end

-- A waypoint to where a rank is got: its book's vendor, its quest's giver, or a trainer.
---@param profession SkillUpProfession
---@param rank SkillUpRank
---@return fun()
local function RankClick(profession, rank)
	return function()
		local npcID = ns.NearestForRank(profession, rank, true)
		if npcID then
			ns.SetWaypoint(npcID)
		end
	end
end

---@param recipeID integer
---@return fun()
local function RecipeClick(recipeID)
	return function()
		if IsModifiedClick("CHATLINK") then
			ChatFrameUtil.InsertLink(C_Spell.GetSpellLink(recipeID))
		else
			ns.ShowRecipe(recipeID)
		end
	end
end

-- "Show again: <recipe>" for each recipe of this profession the character skipped, on the route page's
-- Skipped row and the tracker's header menu.
---@param description RootMenuDescriptionProxy|ElementMenuDescriptionProxy
---@param skillLine integer
function ns.AddSkippedMenu(description, skillLine)
	for _, recipe in ipairs(ns.SkippedRecipes(skillLine)) do
		description:CreateButton(string.format(L["Show again: %s"], recipe.name), function()
			ns.SetSkipped(recipe.recipeID, false)
		end)
	end
end

---@param description RootMenuDescriptionProxy|ElementMenuDescriptionProxy
---@param skillLine integer
function ns.AddPinnedMenu(description, skillLine)
	for _, recipe in ipairs(ns.PinnedRecipes(skillLine)) do
		description:CreateButton(string.format(L["Unpin: %s"], recipe.name), function()
			ns.SetPinned(recipe.recipeID, false)
		end)
	end
end

---@param plan SkillUpPlan
---@param recipeID integer
---@return string
local function PinStatus(plan, recipeID)
	for _, craft in ipairs(plan.crafts) do
		if craft.recipeID == recipeID then
			return L["Pinned for skill-ups."]
		end
	end
	local profession = plan.profession
	local thresholds = ns.Model.Get(recipeID)
	if not thresholds then
		return L["Skill range unknown."]
	end
	if profession.skill >= thresholds[4] then
		return L["Already grey: no skill-ups."]
	end
	if ns.LearnSkill(profession, recipeID) > profession.skill then
		return string.format(L["Requires skill %d."], ns.LearnSkill(profession, recipeID) - profession.modifier)
	end
	if not ns.IsLearned(recipeID) then
		return L["Learn this recipe first."]
	end
	if ns.NetCost(recipeID) == nil then
		return L["Reagents not priced yet."]
	end
	return L["Outside this route or a newer pin takes priority."]
end

---@param list SkillUpList
---@param plan SkillUpPlan
local function RenderPinned(list, plan)
	for _, recipe in ipairs(ns.PinnedRecipes(plan.profession.skillLine)) do
		list:Add({
			icon = RecipeIcon(recipe.recipeID),
			text = string.format(L["Pinned: %s"], recipe.name),
			detail = PinStatus(plan, recipe.recipeID),
			color = NORMAL_FONT_COLOR,
			tooltip = function(tooltip)
				RecipeTitle(tooltip, recipe.recipeID, recipe.name)
				GameTooltip_AddHighlightLine(tooltip, PinStatus(plan, recipe.recipeID))
				GameTooltip_AddInstructionLine(tooltip, L["The newest pin takes priority where skill ranges overlap."])
				AddSkipHint(tooltip)
			end,
			click = RecipeClick(recipe.recipeID),
			menu = RecipeMenu(recipe.recipeID),
		})
	end
end

-- One row under the route for what it leaves out by choice, so a skip is never silent: click or right-click
-- it to bring a recipe back.
---@param list SkillUpList
---@param profession SkillUpProfession
local function RenderSkipped(list, profession)
	local skipped = ns.SkippedRecipes(profession.skillLine)
	if #skipped == 0 then
		return
	end
	local title = string.format(L["Skipped (%d)"], #skipped)
	local function Menu(_, root)
		root:CreateTitle(title)
		ns.AddSkippedMenu(root, profession.skillLine)
	end
	list:Add({
		icon = SKIPPED_ICON,
		text = title,
		detail = L["Not in this route: you chose Not this recipe."],
		color = GRAY_FONT_COLOR,
		tooltip = function(tooltip)
			GameTooltip_SetTitle(tooltip, title)
			for _, recipe in ipairs(skipped) do
				GameTooltip_AddHighlightLine(tooltip, recipe.name)
			end
			GameTooltip_AddInstructionLine(tooltip, L["Click to show a recipe again."])
		end,
		click = function(row)
			GameTooltip_Hide()
			MenuUtil.CreateContextMenu(row, Menu)
		end,
		menu = Menu,
	})
end

local SUGGESTIONS_SHOWN = 8

---@param tooltip GameTooltip
---@param profession SkillUpProfession
---@param suggestion SkillUpSuggestion
local function SuggestionTooltip(tooltip, profession, suggestion)
	local recipeID = suggestion.recipeID
	RecipeTitle(tooltip, recipeID, RecipeName(recipeID))
	RequiresLine(tooltip, profession, ns.ScrollSkill(recipeID, suggestion.source))
	AddBands(tooltip, profession, recipeID)
	local price = ns.ScrollPrice(suggestion.source)
	if price then
		AddLine(tooltip, L["Scroll"], Money(price))
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	local npcID = ns.SuggestionNPC(suggestion)
	ns.AddSourceLines(tooltip, suggestion.source, npcID)
	if npcID then
		GameTooltip_AddInstructionLine(
			tooltip,
			string.format(L["Click for a waypoint to %s."], ns.NPCLocation(npcID).name)
		)
		ns.AddCompanionHint(tooltip, true)
	end
	GameTooltip_AddInstructionLine(tooltip, L["Shift-click to link the scroll."])
	AddSkipHint(tooltip)
end

---@param suggestion SkillUpSuggestion
---@return fun()
local function SuggestionClick(suggestion)
	return function()
		if IsModifiedClick("CHATLINK") then
			local _, link = C_Item.GetItemInfo(suggestion.source.item)
			if link then
				ChatFrameUtil.InsertLink(link)
			end
		else
			local npcID = ns.SuggestionNPC(suggestion)
			if npcID then
				ns.SetWaypoint(npcID)
			end
		end
	end
end

-- Where the known recipes run out: the scrolls that would carry the route on.
---@param list SkillUpList
---@param plan SkillUpPlan
local function RenderSuggestions(list, plan)
	local profession = plan.profession
	local suggestions = ns.RecipeSuggestions(profession, plan.reached)
	local hint = ns.Catalogue.Hint()
	if hint then
		list:Message(hint)
	end
	if #suggestions == 0 then
		return
	end
	list:Message(L["Recipes from vendors, quests and drops that would carry it on:"], NORMAL_FONT_COLOR)
	for i = 1, math.min(#suggestions, SUGGESTIONS_SHOWN) do
		local suggestion = suggestions[i]
		local price = ns.ScrollPrice(suggestion.source)
		list:Add({
			icon = C_Item.GetItemIconByID(suggestion.source.item),
			text = RecipeName(suggestion.recipeID),
			detail = string.format(
				L["%s, %s, to %d"],
				suggestion.kindText,
				price and Money(price) or "?",
				suggestion.reach
			),
			color = ns.COLORS[suggestion.color],
			tooltip = function(tooltip)
				SuggestionTooltip(tooltip, profession, suggestion)
			end,
			click = SuggestionClick(suggestion),
			menu = RecipeMenu(suggestion.recipeID),
		})
	end
end

---@param list SkillUpList
---@param plan SkillUpPlan
local function RenderRoute(list, plan)
	local profession = plan.profession
	local blocked = ns.RouteBlocked(plan)
	if blocked and profession.capped and #plan.ranks == 0 then
		list:Message(blocked)
		RenderPinned(list, plan)
		return
	end
	for _, step in ipairs(plan.steps) do
		local rank, training, craft, subcraft = step.rank, step.training, step.craft, step.subcraft
		if subcraft then
			local itemName = C_Item.GetItemNameByID(subcraft.itemID) or string.format(L["item %d"], subcraft.itemID)
			list:Add({
				icon = RecipeIcon(subcraft.recipeID),
				text = string.format(L["Craft %d× %s"], subcraft.crafts, RecipeName(subcraft.recipeID)),
				detail = string.format(L["makes %d %s"], subcraft.made, itemName),
				color = NORMAL_FONT_COLOR,
				tooltip = function(tooltip)
					SubCraftTooltip(tooltip, subcraft)
				end,
				click = RecipeClick(subcraft.recipeID),
				menu = RecipeMenu(subcraft.recipeID),
			})
		elseif rank then
			local detail
			local held = ns.RankHeld(rank)
			if held then
				detail = string.format(L["You have it, requires %s (%d)"], profession.name, rank.reqSkill)
			elseif rank.quest then
				detail = string.format(L["Quest, requires %s (%d)"], profession.name, rank.reqSkill)
			else
				local text = rank.book and L["Price %s, requires %s (%d)"] or L["Fee %s, requires %s (%d)"]
				detail = string.format(text, Money(rank.fee), profession.name, rank.reqSkill)
			end
			list:Add({
				icon = profession.icon,
				text = ns.RankText(rank),
				detail = detail,
				color = NORMAL_FONT_COLOR,
				tooltip = function(tooltip)
					RankTooltip(tooltip, profession, rank)
				end,
				-- A book you have has nowhere to send you.
				click = not held and RankClick(profession, rank) or nil,
			})
		elseif training then
			list:Add({
				icon = TRAIN_ICON,
				text = string.format(L["Train %s"], RecipeName(training.recipeID)),
				detail = string.format(
					L["Fee %s, requires %s (%d)"],
					Money(training.fee),
					profession.name,
					training.reqSkill
				),
				color = NORMAL_FONT_COLOR,
				tooltip = function(tooltip)
					TrainTooltip(tooltip, profession, training)
				end,
				click = TrainerClick(profession, training.cap),
				menu = RecipeMenu(training.recipeID),
			})
		elseif craft then
			local money = Money(ns.NetCost(craft.recipeID) * craft.crafts)
			list:Add({
				icon = RecipeIcon(craft.recipeID),
				text = RecipeName(craft.recipeID),
				detail = craft.station
						and string.format(L["%d crafts to %d, %s, at %s"], craft.crafts, craft.to, money, craft.station)
					or string.format(L["%d crafts to %d, %s"], craft.crafts, craft.to, money),
				color = ns.COLORS[craft.color],
				tooltip = function(tooltip)
					CraftTooltip(tooltip, profession, craft)
				end,
				click = RecipeClick(craft.recipeID),
				menu = RecipeMenu(craft.recipeID),
			})
		end
	end
	if #plan.crafts > 0 then
		list:Message(string.format(L["Total %s"], Money(ns.PlanCost(plan))), NORMAL_FONT_COLOR)
	end
	if blocked and plan.unpriced > 0 then
		list:Message(blocked)
	elseif plan.stopReason == "no_recipe" then
		local known = plan.unpriced > 0 and L["Nothing priced you know skills up past %d."]
			or L["Nothing you know skills up past %d."]
		list:Message(string.format(known, plan.reached), RED_FONT_COLOR)
		RenderSuggestions(list, plan)
	end
	if #plan.crafts > 0 and plan.unpriced > 0 then
		list:Message(
			string.format(L["Route incomplete: %d recipes left out, their reagents not priced yet."], plan.unpriced)
		)
	end
	if #plan.steps == 0 and not blocked and plan.stopReason ~= "no_recipe" then
		-- Nothing to craft and nothing to train: an uncapped profession with no priced craft still says so in
		-- the list, rather than drawing an empty route (#190).
		list:Message(string.format(L["No step yet: learn or train a %s recipe that skills up."], profession.name))
	end
	RenderPinned(list, plan)
	RenderSkipped(list, profession)
end

local SOURCE_TEXT = { gather = L["gather"], vendor = L["vendor"], auction = L["AH"], unknown = L["no price"] }

---@param tooltip GameTooltip
---@param item SkillUpNeededItem
local function ReagentTooltip(tooltip, item)
	tooltip:SetItemByID(item.itemID)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	local have = ns.Have(item.itemID)
	AddLine(tooltip, L["Have (bags and bank)"], tostring(have))
	AddLine(tooltip, L["Route needs"], tostring(item.need))
	for _, alt in ipairs(ns.AltCounts(item.itemID)) do
		AddLine(tooltip, string.format(L["On %s"], alt.name), tostring(alt.count), GRAY_FONT_COLOR)
	end
	local price = ns.Price(item.itemID)
	if not price then
		GameTooltip_AddDisabledLine(tooltip, ns.UnpricedHint())
		return
	end
	if price.source == "gather" then
		AddLine(tooltip, L["Source"], ns.PriceSourceText(price))
		-- Valued at what it would sell for: the cost of crafting with it instead, never a price to buy at.
		if price.worth then
			AddLine(tooltip, L["Each"], Money(price.copper))
		end
		return
	end
	AddLine(tooltip, L["Each"], string.format("%s |cff808080(%s)|r", Money(price.copper), ns.PriceSourceText(price)))
	if have < item.need then
		AddLine(tooltip, L["To buy"], Money(price.copper * (item.need - have)))
	end
	if item.source == "vendor" then
		ns.AddNearest(tooltip, L["Nearest vendor"], ns.NearestVendor(item.itemID, true))
	end
end

---@param list SkillUpList
---@param items integer[]
local function RenderUnpriced(list, items)
	for _, itemID in ipairs(items) do
		local name = C_Item.GetItemNameByID(itemID)
		if not name then
			-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
			C_Item.RequestLoadItemDataByID(itemID)
			name = string.format(L["item %d"], itemID)
		end
		list:Add({
			icon = C_Item.GetItemIconByID(itemID) or 134400,
			iconColor = QualityColor(itemID),
			text = name,
			detail = SOURCE_TEXT.unknown,
			tooltip = function(tooltip)
				tooltip:SetItemByID(itemID)
			end,
		})
	end
end

---@param list SkillUpList
---@param reagents SkillUpNeededItem[]
local function RenderReagents(list, reagents)
	if #reagents == 0 then
		list:Message(L["Nothing to buy for this route."])
		return
	end
	for _, item in ipairs(reagents) do
		local name = C_Item.GetItemNameByID(item.itemID)
		if not name then
			-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
			C_Item.RequestLoadItemDataByID(item.itemID)
			name = string.format(L["item %d"], item.itemID)
		end
		local have = ns.Have(item.itemID)
		list:Add({
			icon = C_Item.GetItemIconByID(item.itemID) or 134400,
			iconColor = QualityColor(item.itemID),
			text = name,
			detail = string.format(L["%s, %d/%d"], SOURCE_TEXT[item.source], math.min(have, item.need), item.need),
			detailColor = have >= item.need and ns.COLORS.green or HIGHLIGHT_FONT_COLOR,
			tooltip = function(tooltip)
				ReagentTooltip(tooltip, item)
			end,
			click = function()
				local _, link = C_Item.GetItemInfo(item.itemID)
				if link and IsModifiedClick() then
					HandleModifiedItemClick(link)
					return
				end
				local vendor = item.source == "vendor" and ns.NearestVendor(item.itemID, true)
				if vendor then
					ns.SetWaypoint(vendor)
				end
			end,
		})
	end
end

-- Identify the auction source and flag prices that need a fresh scan.
---@param reagents SkillUpNeededItem[]
---@return string
---@return ColorMixin
local function AuctionPriceStatus(reagents)
	local found, stale
	for _, item in ipairs(reagents) do
		local price = ns.Price(item.itemID)
		if price and price.source == "auctionator" then
			found = true
			local age = ns.PriceAge(price)
			if age == nil or age > STALE_AFTER then
				stale = true
			end
		end
	end
	if not found then
		return "", GRAY_FONT_COLOR
	end
	local text = stale and L["Latest Auctionator prices: rescan to update old prices."]
		or L["Latest Auctionator prices."]
	return text, stale and ns.COLORS.orange or GRAY_FONT_COLOR
end

-- Whether an auction price behind this route is missing or old enough to be wrong.
---@param reagents SkillUpNeededItem[]
---@return boolean
local function NeedsAuctionScan(reagents)
	for _, item in ipairs(reagents) do
		local price = ns.Price(item.itemID)
		if not price then
			return true
		end
		if price.source == "auctionator" then
			local age = ns.PriceAge(price)
			if age == nil or age > STALE_AFTER then
				return true
			end
		end
	end
	return false
end

-- Auctionator can refresh its own prices when the auction house opens. With that option off, say
-- where to turn it on; silent when the option cannot be read.
---@param reagents SkillUpNeededItem[]
---@return string?
local function AutoscanNote(reagents)
	if not NeedsAuctionScan(reagents) or ns.AuctionatorAutoscan() ~= false then
		return nil
	end
	return L["Auctionator's scan when the auction house opens is off: turn it on in Auctionator, Basic Options."]
end

-- The route's vendor reagents it still needs, whose vendor can be named.
---@param reagents SkillUpNeededItem[]
---@return integer[]
local function VendorItems(reagents)
	local items = {}
	for _, item in ipairs(reagents) do
		if item.source == "vendor" and ns.Have(item.itemID) < item.need then
			items[#items + 1] = item.itemID
		end
	end
	return items
end

-- The nearest vendor selling any of the route's missing vendor reagents, by the travel integration.
---@param itemIDs integer[]
---@return integer?
local function NearestRouteVendor(itemIDs)
	local candidates = {}
	for _, itemID in ipairs(itemIDs) do
		local npcID = ns.NearestVendor(itemID, true)
		if npcID then
			candidates[#candidates + 1] = npcID
		end
	end
	return ns.NearestNPC(candidates, true)
end

-- Whether pricing instead of gathering could change this route: at least one reagent is one of this
-- character's professions gathers, so in gather mode it costs nothing.
---@param reagents SkillUpNeededItem[]
---@return boolean
local function CollectChanges(reagents)
	local professions = ns.PlayerProfessions()
	for _, item in ipairs(reagents) do
		local skillLine = ns.GatheredBy[item.itemID]
		if skillLine and professions[skillLine] then
			return true
		end
	end
	return false
end

-- The switch always stays clickable: a box drawn checked while it is disabled is a switch you cannot turn
-- off (#162, #190). When it changes nothing for this route the label is greyed and the tooltip says so.
---@param changes boolean
local function SetCollectEnabled(changes)
	page.collectChanges = changes
	page.Collect:Enable()
	page.CollectLabel:SetTextColor((changes and NORMAL_FONT_COLOR or GRAY_FONT_COLOR):GetRGB())
end

-- "Need 7 more Light Hide" when the step is short of a reagent, else the plan's own reason.
---@param craft SkillUpCraft
---@return string?
local function CraftReason(craft)
	if not craft.missing then
		return craft.reason
	end
	local name = C_Item.GetItemNameByID(craft.missing.itemID) or string.format(L["item %d"], craft.missing.itemID)
	return string.format(L["Need %d more %s"], craft.missing.count, name)
end

---@param craft SkillUpCraft
local function SetCraft(craft)
	local button = page.Craft
	button.recipeID, button.count = craft.recipeID, craft.count
	button.title, button.planned, button.to = craft.text, craft.planned, craft.to
	button.reason = CraftReason(craft)
	button:SetText(craft.text)
	button:SetSize(math.min(button:GetTextWidth() + 32, 240), 22)
	button:SetEnabled(button.recipeID ~= nil)
end

local function Render()
	local profession = selected and ns.RouteProfessions()[selected]
	page.Profession:GenerateMenu()
	page.Skill:SetShown(profession ~= nil)
	page.Target:SetShown(profession ~= nil)
	page.Track:SetEnabled(profession ~= nil)
	page.Craft:SetShown(profession ~= nil)
	page.Collect:SetChecked(ns.CollectMode() == "auction")
	page.RouteList:Begin()
	page.ReagentList:Begin()
	if not profession then
		SetCollectEnabled(false)
		page.Vendor:Hide()
		page.vendorItems = {}
		page.RouteList:Message(L["Learn a crafting profession to plan a route."])
		page.RouteList:Finish()
		page.ReagentList:Finish()
		return
	end
	ProfessionsFrame:SetPortraitToAsset(profession.icon)
	page.Skill:SetFormattedText(L["Skill  %d/%d     Target"], profession.base, profession.max)
	local plan = ns.PlanRoute(profession)
	if not page.Target:HasFocus() then
		page.Target:SetText(tostring(plan.target))
	end
	local reagents = ns.RouteReagents(plan)
	SetCollectEnabled(CollectChanges(reagents))
	RenderRoute(page.RouteList, plan)
	local priceStatus, priceColor = AuctionPriceStatus(reagents)
	if priceStatus ~= "" then
		page.ReagentList:Message(priceStatus, priceColor)
	end
	local scan = AutoscanNote(reagents)
	if scan then
		page.ReagentList:Message(scan, ns.COLORS.orange)
	end
	RenderReagents(page.ReagentList, reagents)
	if plan.unpriced > 0 then
		-- The route is incomplete; the reagents it left out are named, not silently dropped.
		RenderUnpriced(page.ReagentList, ns.UnpricedReagents(plan))
	end
	local listName = ns.AuctionListName(profession.name)
	if listName and ns.HasAuctionator() and ns.CollectMode() == "auction" then
		page.ReagentList:Message(string.format(L["Kept in the Auctionator list '%s'."], listName))
	end
	local vendorItems = VendorItems(reagents)
	page.vendorItems = vendorItems
	page.Vendor:SetShown(#vendorItems > 0)
	local craft = ns.NextCraft(plan)
	local missingReason = craft.missing and CraftReason(craft)
	if missingReason then
		page.RouteList:Message(missingReason, RED_FONT_COLOR)
	end
	page.RouteList:Finish()
	page.ReagentList:Finish()
	page.Track:SetText(ns.IsTracked(selected) and L["Stop tracking"] or L["Track"])
	SetCraft(craft)
end

-- Coalesces bursts of list/skill/price/bag updates into one plan.
local function RefreshRoute()
	if pending or not page:IsShown() then
		return
	end
	pending = true
	C_Timer.After(0.2, function()
		pending = false
		if page:IsShown() then
			Render()
		end
	end)
end

---@param editBox EditBox
local function CommitTarget(editBox)
	local value = tonumber(editBox:GetText())
	if selected and value then
		if not ns.TargetChanged(selected, value) then
			return
		end
		ns.db.routeTargets[selected] = value
		ns.Changed("target")
	else
		RefreshRoute()
	end
end

---@param name string
---@return Frame
local function CreateInset(name)
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate") --[[@as Frame]]
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(name)
	return inset
end

local function CreateHeader()
	local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate") --[[@as DropdownButton]]
	dropdown:SetWidth(180)
	-- Clear of the portrait, which overhangs the top-left corner.
	dropdown:SetPoint("TOPLEFT", 76, -32)
	dropdown:SetupMenu(function(_, root)
		local professions = {}
		for _, profession in pairs(ns.RouteProfessions()) do
			professions[#professions + 1] = profession
		end
		table.sort(professions, function(a, b)
			return a.name < b.name
		end)
		for _, profession in ipairs(professions) do
			local skillLine = profession.skillLine
			root:CreateRadio(profession.name, function()
				return skillLine == selected
			end, function()
				selected = skillLine
				page.RouteList.scrollBox:ScrollToBegin()
				page.ReagentList.scrollBox:ScrollToBegin()
				Render()
			end)
		end
	end)
	page.Profession = dropdown

	local skill = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	skill:SetPoint("LEFT", dropdown, "RIGHT", 16, 0)
	page.Skill = skill

	local target = CreateFrame("EditBox", nil, page, "InputBoxTemplate") --[[@as EditBox]]
	target:SetSize(40, 20)
	target:SetPoint("LEFT", skill, "RIGHT", 10, 0)
	target:SetNumeric(true)
	target:SetMaxLetters(3)
	target:SetAutoFocus(false)
	target:SetScript("OnEnterPressed", target.ClearFocus)
	target:SetScript("OnEditFocusLost", CommitTarget)
	target:SetScript("OnEscapePressed", function(editBox)
		editBox:SetText("")
		editBox:ClearFocus()
	end)
	page.Target = target
end

local function CreateButtons()
	local track = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate") --[[@as Button]]
	-- Wide enough for both labels, so the Craft button beside it stays put when tracking toggles.
	track:SetText(L["Stop tracking"])
	local stop = track:GetTextWidth() + 32
	track:SetText(L["Track"])
	track:SetSize(math.max(130, stop, track:GetTextWidth() + 32), 22)
	track:SetScript("OnClick", function()
		local tracked = not ns.IsTracked(selected)
		ns.SetTracked(selected, tracked)
		Render()
		if tracked and not ns.TrackerAttached() then
			ns.Print(L["tracked, but the objective tracker section isn't attached; please report it."])
		end
	end)
	page.Track = track

	-- CraftRecipe needs this click's hardware event, so the craft is set up in Render.
	local craft = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate") --[[@as SkillUpCraftButton]]
	craft:SetScript("OnClick", function(self)
		if self.recipeID then
			C_TradeSkillUI.CraftRecipe(self.recipeID, self.count)
			-- The craft's bag and skill events redraw it; ask for one too, so a craft is never missed.
			RefreshRoute()
		end
	end)
	craft:SetMotionScriptsWhileDisabled(true)
	craft:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if self.reason then
			GameTooltip_SetTitle(GameTooltip, self.reason)
		elseif self.planned then
			GameTooltip_SetTitle(GameTooltip, self.title)
			GameTooltip_AddNormalLine(GameTooltip, string.format(L["Crafts %d now."], self.count))
			if self.count < self.planned then
				GameTooltip_AddNormalLine(
					GameTooltip,
					string.format(L["Your bags allow %d of the route's %d."], self.count, self.planned)
				)
			end
			GameTooltip_AddNormalLine(
				GameTooltip,
				string.format(
					L["The route asks for %d to reach %d in 9 runs of 10; a worse run needs more."],
					self.planned,
					self.to
				)
			)
			GameTooltip_AddInstructionLine(GameTooltip, string.format(L["Click to craft %d."], self.count))
		end
		GameTooltip:Show()
	end)
	craft:SetScript("OnLeave", GameTooltip_Hide)
	page.Craft = craft

	-- Where a reagent this character could gather or buy comes from: its own professions' gathering, or a
	-- vendor and the auction house. Sits with the route it changes, not in the settings panel.
	local collect = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate") --[[@as CheckButton]]
	collect:SetScript("OnClick", function()
		ns.SetCollectMode(ns.CollectMode() == "gather" and "auction" or "gather")
		Render()
	end)
	collect:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L["Buy reagents at the auction house"])
		if page.collectChanges ~= false then
			-- luacheck: push no max line length
			GameTooltip_AddNormalLine(
				GameTooltip,
				ns.db.valueGathered
						and L["On, a reagent you could gather is priced at a vendor or the auction house; off, gathering it costs what it would sell for."]
					or L["On, a reagent you could gather is priced at a vendor or the auction house; off, gathering it costs nothing."]
			)
			-- luacheck: pop
		else
			GameTooltip_AddDisabledLine(
				GameTooltip,
				L["Nothing on this route is yours to gather, so the switch changes nothing for it."]
			)
		end
		GameTooltip:Show()
	end)
	collect:SetScript("OnLeave", GameTooltip_Hide)
	local label = collect:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("LEFT", collect, "RIGHT", 4, 0)
	label:SetText(L["Buy reagents"])
	page.Collect = collect
	page.CollectLabel = label

	-- One click to the nearest vendor selling any vendor reagent the route still needs.
	local vendor = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate") --[[@as Button]]
	vendor:SetSize(120, 22)
	vendor:SetText(L["Nearest vendor"])
	vendor:SetWidth(math.max(120, vendor:GetTextWidth() + 32))
	vendor:SetScript("OnClick", function()
		local npcID = NearestRouteVendor(page.vendorItems)
		if npcID then
			ns.SetWaypoint(npcID)
		end
	end)
	vendor:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip_SetTitle(GameTooltip, L["Vendor reagents"])
		ns.AddNearest(GameTooltip, L["Nearest vendor"], NearestRouteVendor(page.vendorItems))
		GameTooltip:Show()
	end)
	vendor:SetScript("OnLeave", GameTooltip_Hide)
	page.Vendor = vendor
	local shoppingList = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate") --[[@as Button]]
	shoppingList:SetSize(110, 22)
	shoppingList:SetText(L["Shopping list"])
	shoppingList:SetScript("OnClick", ns.OpenShoppingList)
	page.ShoppingList = shoppingList
end

-- Occupies the crafting page's place, as the overview page does.
local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpPage]]
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	-- What's Training? paints its own page at the portrait container's level, over CraftingPage's, and never
	-- hides it when another tab is chosen. HIGH sits above that page and below dialogs, so this one keeps the
	-- clicks while both are open.
	page:SetFrameStrata("HIGH")
	page:Hide()
	CreateHeader()
	CreateButtons()

	local route = CreateInset(L["Route"])
	route:SetPoint("TOPLEFT", 16, -88)
	-- The route gets the wider half: its names are longer and its rows carry more facts.
	route:SetPoint("BOTTOMRIGHT", page, "BOTTOM", ROUTE_SHARE - 6, 44)
	page.RouteList = ns.CreateList(route)

	local reagents = CreateInset(L["Reagents  (have / need)"])
	reagents:SetPoint("TOPLEFT", page, "TOP", ROUTE_SHARE + 6, -88)
	reagents:SetPoint("BOTTOMRIGHT", -16, 44)
	page.ReagentList = ns.CreateList(reagents)

	-- The switch sits in the header row, right of the target it changes, clear of the Route heading.
	page.Collect:SetPoint("LEFT", page.Target, "RIGHT", 16, 0)
	-- One bottom row, right to left: Track under the reagents, then Craft, then Nearest vendor,
	-- each clear of the next whatever the craft label says.
	page.Track:SetPoint("TOPRIGHT", reagents, "BOTTOMRIGHT", 0, -10)
	page.Craft:SetPoint("RIGHT", page.Track, "LEFT", -8, 0)
	page.Vendor:SetPoint("RIGHT", page.Craft, "LEFT", -8, 0)
	page.ShoppingList:SetPoint("RIGHT", page.Vendor, "LEFT", -8, 0)
	-- The portrait follows the profession shown here, and is given back on the way out.
	local portrait
	page:SetScript("OnShow", function()
		portrait = ProfessionsFrame:GetPortrait():GetTexture()
		Render()
	end)
	page:SetScript("OnHide", function()
		if portrait then
			ProfessionsFrame:SetPortraitToAsset(portrait)
		end
	end)
end

-- The profession on show in the crafting page, when it is one of this character's;
-- nil until Blizzard_Professions loads, which the tracker menu can precede.
---@return integer?
function ns.OpenSkillLine()
	if not Professions then
		return nil
	end
	local info = Professions.GetProfessionInfo()
	local name = info and (info.parentProfessionName or info.professionName)
	local skillLine = info and name and ns.ProfessionSkillLine(name, info.parentProfessionID or info.professionID)
	return skillLine and ns.PlayerProfessions()[skillLine] and skillLine
end

local SyncChecks

local function SelectPage()
	ns.HideGear()
	local professions = ns.RouteProfessions()
	local open = ns.OpenSkillLine()
	selected = professions[open] and open or professions[selected] and selected or next(professions)
	-- Show the native page first so another custom page's CraftingPage hook can hand off cleanly.
	ProfessionsFrame.CraftingPage:Show()
	ProfessionsFrame.CraftingPage:Hide()
	ProfessionsFrame.BookPage:Hide()
	page:Show()
	SyncChecks()
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	page:Hide()
	tab:SetChecked(false)
end
ns.HideRoute = Deselect

-- Back to the crafting page, as its tab would, with the recipe selected.
---@param recipeID integer
function ns.ShowRecipe(recipeID)
	local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
	if not (info and info.learned and selected == ns.OpenSkillLine()) then
		return
	end
	local craftingPage = ProfessionsFrame.CraftingPage
	craftingPage:Show()
	ProfessionsFrame:RefreshRightTabs()
	if craftingPage.RecipeList and craftingPage.RecipeList.SelectRecipe then
		craftingPage.RecipeList:SelectRecipe(info, true)
	end
end

-- Directly under the last profession tab Forever shows, in the same tab art.
---@param anchor Frame
---@return Frame?
local function OccupiedSlot(anchor)
	local left = anchor:GetLeft()
	if type(left) ~= "number" then
		return nil
	end
	-- The lowest frame already anchored flush with the column, not just Blizzard's next slot: What's Training?
	-- pins its tab to the window's bottom-right corner, which lands in the same strip without joining the tab array.
	local lowest, lowestBottom
	for _, sibling in ipairs({ ProfessionsFrame:GetChildren() }) do
		if sibling ~= tab and sibling:IsShown() then
			local siblingLeft, siblingBottom = sibling:GetLeft(), sibling:GetBottom()
			if
				type(siblingLeft) == "number"
				and type(siblingBottom) == "number"
				and math.abs(siblingLeft - left) < 1
				and (not lowestBottom or siblingBottom < lowestBottom)
			then
				lowest, lowestBottom = sibling, siblingBottom
			end
		end
	end
	return lowest
end

local function PlaceTab()
	---@type Frame
	local last = ProfessionsFrame.ProfessionsOverviewTab
	for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
		if professionTab:IsShown() then
			last = professionTab
		end
	end
	-- Addons such as All The Things can already occupy the next tab slot without joining Blizzard's tab array.
	-- Use their visible tab as the anchor so the route remains reachable below it.
	last = OccupiedSlot(last) or last
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
end

-- Blizzard reselects its profession tab on skill updates; keep ours checked while our page shows.
function SyncChecks()
	local shown = page:IsShown()
	tab:SetChecked(shown)
	if shown then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
		if ns.GearTab then
			ns.GearTab:SetChecked(false)
		end
	end
end

-- The tab can be turned off in settings; an open page goes back to crafting.
local function RefreshRouteTab()
	tab:SetShown(ns.db.showRouteTab)
	if not ns.db.showRouteTab and page:IsShown() then
		Deselect()
		ProfessionsFrame.CraftingPage:Show()
	end
	-- The gear tab sits under this one, so it moves when this one does.
	if ns.PlaceGearTab then
		ns.PlaceGearTab()
	end
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate") --[[@as SkillUpSideTab]]
	-- art-ok: a square icon in the square LargeSideTabButtonTemplate sizes for it
	tab.Icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
	tab:SetFillToInterior(true)
	tab.tooltipText = L["Levelling route"]
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			SelectPage()
		end
	end)
	PlaceTab()
	RefreshRouteTab()
	ns.RouteTab = tab
	ProfessionsFrame:HookScript("OnShow", PlaceTab)
	page:HookScript("OnShow", SyncChecks)
end

function ns.AttachRoute()
	CreatePage()
	CreateTab()
	ProfessionsFrame.CraftingPage:HookScript("OnShow", Deselect)
	ProfessionsFrame.BookPage:HookScript("OnShow", Deselect)
	-- A reopened window starts on the crafting page, as Blizzard expects.
	ProfessionsFrame:HookScript("OnHide", function()
		if page:IsShown() then
			Deselect()
			ProfessionsFrame.CraftingPage:Show()
		end
	end)
	ns.WhenStale("route", RefreshRoute)
	ns.WhenStale("routeTab", RefreshRouteTab)
	-- Run after Blizzard handles the same event; never replace or hook its frame methods.
	local function AfterBlizzard()
		C_Timer.After(0, function()
			PlaceTab()
			-- The gear tab sits under this one, so it moves with it.
			if ns.PlaceGearTab then
				ns.PlaceGearTab()
			end
			SyncChecks()
			-- The window's own profession starts tracking on its own when its route has steps.
			if ProfessionsFrame:IsShown() then
				ns.AutoTrack(ns.OpenSkillLine())
			end
		end)
	end
	for _, event in ipairs({ "SKILL_LINES_CHANGED", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_SHOW" }) do
		ns.WhenEvent(event, AfterBlizzard)
	end
end
