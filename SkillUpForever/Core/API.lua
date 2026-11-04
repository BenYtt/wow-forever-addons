---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- SkillUpForever.API, version 1: each profession's next steps, recipes and reagents,
-- read from the same levelling plan the route tab shows, for other addons to draw.
-- Built once and kept until Core/Changes.lua says it is stale.
-- API.ShoppingList's records carry `target`: the base skill that profession's plan buys to,
-- the same number the route tab's Target box shows.

local MAX_STEPS = 3
local MAX_RECIPES = 5
-- Earlier first: what can be done with what's in the bags beats a trip.
local KIND_ORDER = { craft = 1, buy = 2, gather = 3, train = 4 }

---@type SkillUpAPIProfession[]?
local cache
-- [skill line][step index] = picks the step's NPC by travel time, for Navigate.
---@type table<integer, table<integer, fun(): integer?>>
local pickers = {}
local namesPending = false

ns.WhenStale("api", function()
	namesPending = false
	cache = nil
end)

---@param copper number
---@return string
local function Money(copper)
	return ns.FormatNet(ns.Model.RoundMoney(copper), false)
end

---@param itemID integer
---@return string
local function ItemName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if name then
		return name
	end
	namesPending = true
	C_Item.RequestLoadItemDataByID(itemID)
	return string.format(L["item %d"], itemID)
end

---@param recipeID integer
---@return integer?
local function OutputItem(recipeID)
	local recipe = ns.RecipeData[recipeID]
	return recipe and recipe.output and recipe.output.itemID or nil
end

-- "Name, Zone · fee", or the fallback when there is no NPC to name.
---@param npcID integer?
---@param fallback string
---@param copper number?
---@return string
local function Detail(npcID, fallback, copper)
	local text = fallback
	if npcID then
		local where = ns.NPCLocation(npcID)
		text = where.name .. ", " .. where.label
	end
	if copper and copper > 0 then
		text = text .. " · " .. Money(copper)
	end
	return text
end

-- [itemID] = recipes that make it, from the bundled data.
---@type table<integer, integer[]>?
local makers

---@param itemID integer
---@return boolean
local function CanCraft(itemID)
	if not makers then
		makers = {}
		for recipeID in pairs(ns.RecipeData) do
			local output = OutputItem(recipeID)
			if output then
				makers[output] = makers[output] or {}
				table.insert(makers[output], recipeID)
			end
		end
	end
	for _, recipeID in ipairs(makers[itemID] or {}) do
		if ns.IsLearned(recipeID) then
			return true
		end
	end
	return false
end

---@param item SkillUpNeededItem
---@return SkillUpAPIReagentSource?
local function ReagentSource(item)
	if item.source == "gather" then
		return "gather"
	elseif item.source == "vendor" then
		return "vendor"
	elseif CanCraft(item.itemID) then
		return "craft"
	elseif item.source == "auction" then
		return "auction"
	end
end

-- Getting `count` more of a reagent, the way its price says it is got.
---@param itemID integer
---@param count number
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Acquire(itemID, count)
	local name = ItemName(itemID)
	local price = ns.Price(itemID)
	if price and price.source == "gather" then
		return {
			kind = "gather",
			text = string.format(L["Gather %d %s"], count, name),
			detail = price.profession,
			itemID = itemID,
			count = count,
			nav = false,
		}
	end
	local cost = price and price.copper * count
	local step = {
		kind = "buy",
		text = string.format(L["Buy %d %s"], count, name),
		itemID = itemID,
		count = count,
		cost = cost,
		nav = false,
	}
	if price and price.source == "vendor" then
		local vendor = ns.NearestVendor(itemID)
		step.detail, step.nav = Detail(vendor, L["Vendor"], cost), vendor ~= nil
		return step, vendor and function()
			return ns.NearestVendor(itemID, true)
		end or nil
	elseif price then
		step.detail = Detail(nil, L["Auction house"], cost)
	end
	return step
end

---@param profession SkillUpProfession
---@param text string
---@param cap number
---@param fee number
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Train(profession, text, cap, fee)
	local trainer = ns.NearestTrainer(profession, cap)
	local step = {
		kind = "train",
		text = text,
		detail = Detail(trainer, string.format(L["%s trainer"], profession.name), fee),
		cost = fee > 0 and fee or nil,
		nav = trainer ~= nil,
	}
	return step, trainer and function()
		return ns.NearestTrainer(profession, cap, true)
	end or nil
end

-- A rank no trainer teaches: buy its book from a vendor and read it, or only read it when the bags hold it.
---@param rank SkillUpRank
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Book(rank)
	local book = rank.book
	---@cast book integer
	-- Asked by name here so the list rebuilds when the book's name arrives.
	ItemName(book)
	if ns.RankHeld(rank) then
		return { kind = "train", text = ns.RankText(rank), itemID = book, nav = false }
	end
	local vendor = ns.NearestVendor(book)
	local step = {
		kind = "buy",
		text = ns.RankText(rank),
		detail = Detail(vendor, L["Vendor"], rank.fee),
		itemID = book,
		count = 1,
		cost = rank.fee > 0 and rank.fee or nil,
		nav = vendor ~= nil,
	}
	return step, vendor and function()
		return ns.NearestVendor(book, true)
	end or nil
end

-- A rank only a quest teaches: a train step with the quest's ID, sent to its nearest giver.
---@param profession SkillUpProfession
---@param rank SkillUpRank
---@return SkillUpAPIStep
---@return (fun(): integer?)?
local function Quest(profession, rank)
	local giver = ns.NearestForRank(profession, rank)
	local step = {
		kind = "train",
		text = ns.RankText(rank),
		detail = Detail(giver, L["Quest"]),
		questID = rank.quest,
		nav = giver ~= nil,
	}
	return step, giver and function()
		return (ns.NearestForRank(profession, rank, true))
	end or nil
end

-- The route's first few steps, each craft preceded by getting what the bags lack for it.
---@param plan SkillUpPlan
---@return SkillUpAPIStep[]
---@return table<integer, fun(): integer?>
local function Steps(plan)
	local profession = plan.profession
	local steps, picks, held = {}, {}, {}
	---@param step SkillUpAPIStep
	---@param pick (fun(): integer?)?
	local function Add(step, pick)
		if #steps < MAX_STEPS then
			steps[#steps + 1] = step
			picks[#steps] = pick
		end
	end
	for _, walk in ipairs(plan.steps) do
		if #steps >= MAX_STEPS then
			break
		end
		local rank, training, craft, subcraft = walk.rank, walk.training, walk.craft, walk.subcraft
		if subcraft then
			local name = C_Spell.GetSpellName(subcraft.recipeID) or string.format(L["recipe %d"], subcraft.recipeID)
			Add({
				kind = "craft",
				text = string.format(L["Craft %d %s"], subcraft.crafts, name),
				detail = string.format(L["for %s"], ItemName(subcraft.itemID)),
				spellID = subcraft.recipeID,
				itemID = subcraft.itemID,
				count = subcraft.crafts,
				nav = false,
			})
		elseif rank and rank.book then
			Add(Book(rank)) -- multi-value: the step and its picker
		elseif rank and rank.quest then
			Add(Quest(profession, rank)) -- multi-value: the step and its picker
		elseif rank then
			Add(Train(profession, ns.RankText(rank), rank.cap, rank.fee)) -- multi-value: the step and its picker
		elseif training then
			local name = C_Spell.GetSpellName(training.recipeID) or string.format(L["recipe %d"], training.recipeID)
			local step, pick = Train(profession, string.format(L["Train %s"], name), training.cap, training.fee)
			step.spellID, step.itemID = training.recipeID, OutputItem(training.recipeID)
			Add(step, pick)
		elseif craft then
			local recipeID = craft.recipeID
			for _, reagent in ipairs(ns.Reagents(recipeID) or {}) do
				local itemID, need = reagent.itemID, reagent.quantity * craft.crafts
				local have = held[itemID] or ns.Have(itemID)
				held[itemID] = math.max(have - need, 0)
				if have < need then
					Add(Acquire(itemID, need - have)) -- multi-value: the step and its picker
				end
			end
			local name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
			Add({
				kind = "craft",
				text = string.format(L["Craft %d %s"], craft.crafts, name),
				detail = string.format(L["%d to %d"], craft.from, craft.to),
				spellID = recipeID,
				itemID = OutputItem(recipeID),
				count = craft.crafts,
				nav = false,
			})
		end
	end
	return steps, picks
end

---@param plan SkillUpPlan
---@return SkillUpAPIRecipe[]
local function Recipes(plan)
	local training = {}
	for _, step in ipairs(plan.training) do
		training[step.recipeID] = step
	end
	local recipes = {}
	for i = 1, math.min(#plan.crafts, MAX_RECIPES) do
		local craft = plan.crafts[i]
		local recipeID, step = craft.recipeID, training[craft.recipeID]
		recipes[i] = {
			spellID = recipeID,
			itemID = OutputItem(recipeID),
			name = C_Spell.GetSpellName(recipeID),
			count = craft.crafts,
			fromRank = craft.from,
			toRank = craft.to,
			learned = ns.IsLearned(recipeID) == true,
			color = craft.color,
			trainAt = step and step.usedAt,
			cost = step and step.fee,
		}
	end
	return recipes
end

---@param plan SkillUpPlan
---@return SkillUpAPIReagent[]
local function Reagents(plan)
	local reagents = {}
	for _, item in ipairs(ns.RouteReagents(plan)) do
		reagents[#reagents + 1] =
			{ itemID = item.itemID, need = item.need, have = ns.Have(item.itemID), source = ReagentSource(item) }
	end
	return reagents
end

---@param entry SkillUpAPIProfession
---@return number
local function Urgency(entry)
	local first = entry.steps[1]
	return first and KIND_ORDER[first.kind] or 5
end

---@return SkillUpAPIProfession[]
local function Build()
	local entries, urgency = {}, {}
	pickers = {}
	for skillLine, profession in pairs(ns.RouteProfessions()) do
		local plan = ns.PlanRoute(profession)
		local steps, picks = Steps(plan)
		pickers[skillLine] = picks
		local entry = {
			name = profession.name,
			skillLineID = skillLine,
			icon = profession.icon,
			rank = profession.base,
			maxRank = profession.max,
			title = ns.RankName(profession.max),
			steps = steps,
			recipes = Recipes(plan),
			reagents = Reagents(plan),
		}
		entries[#entries + 1] = entry
		urgency[entry] = { #steps > 0 and 0 or 1, ns.IsTracked(skillLine) and 0 or 1, Urgency(entry) }
	end
	-- Something to do first, then what the player tracks, then the nearest to doing.
	table.sort(entries, function(a, b)
		local ua, ub = urgency[a], urgency[b]
		for i = 1, #ua do
			if ua[i] ~= ub[i] then
				return ua[i] < ub[i]
			end
		end
		return a.name < b.name
	end)
	return entries
end

---@class SkillUpPublicAPI
local API = { version = 1, minor = 4 }

---@param recipeID integer
---@param crafts number?
---@return {itemID: integer, count: number}[]?
function API.RequiredMaterials(recipeID, crafts)
	local _, raw = ns.RecipeMaterials(recipeID, crafts or 1)
	return raw
end

---@param recipeID integer
---@param crafts number?
---@return SkillUpSubCraft[]?
function API.SubComponents(recipeID, crafts)
	local subcrafts = ns.RecipeMaterials(recipeID, crafts or 1)
	return subcrafts
end

---@param skillLineID integer?
---@return SkillUpAPIShoppingProfession[]
function API.ShoppingList(skillLineID)
	if not ns.db then
		return {}
	end
	local entries = {}
	local tracked = ns.TrackedNeeds()
	for _, entry in ipairs(tracked) do
		if not skillLineID or entry.plan.profession.skillLine == skillLineID then
			local result = {
				profession = entry.plan.profession.name,
				skillLine = entry.plan.profession.skillLine,
				target = entry.plan.target,
				items = {},
				total = 0,
				unpriced = 0,
			}
			local bySource = {}
			for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
				bySource[source] = {}
			end
			for _, item in ipairs(entry.items) do
				local price = ns.Price(item.itemID)
				local have = ns.Have(item.itemID)
				local missing = math.max(item.need - have, 0)
				local row = {
					itemID = item.itemID,
					need = item.need,
					have = have,
					missing = missing,
					source = item.source,
					price = price and price.copper or nil,
					priceAge = price and price.source == "auctionator" and price.days or nil,
					cost = price and missing * price.copper or nil,
					alt = ns.AltCounts(item.itemID),
				}
				bySource[row.source][#bySource[row.source] + 1] = row
			end
			for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
				table.sort(bySource[source], function(a, b)
					return a.itemID < b.itemID
				end)
				for _, row in ipairs(bySource[source]) do
					result.items[#result.items + 1] = row
					if row.missing > 0 then
						if row.cost then
							result.total = result.total + row.cost
						else
							result.unpriced = result.unpriced + 1
						end
					end
				end
			end
			entries[#entries + 1] = result
		end
	end
	table.sort(entries, function(a, b)
		return a.profession == b.profession and a.skillLine < b.skillLine or a.profession < b.profession
	end)
	return entries
end
ns.ShoppingList = API.ShoppingList

---@param copper number
---@return string
local function PlainMoney(copper)
	copper = ns.Model.RoundMoney(copper)
	local text = ns.FormatNet(copper, false)
	text = text:gsub("|T.-GoldIcon.-|t", "g"):gsub("|T.-SilverIcon.-|t", "s")
	text = text:gsub("|T.-CopperIcon.-|t", "c")
	return text
end

---@param skillLineID integer?
---@return string
function ns.ShoppingText(skillLineID)
	local lists = API.ShoppingList(skillLineID)
	local professions = {}
	for _, list in ipairs(lists) do
		professions[#professions + 1] = list.profession
	end
	local lines = {
		L["SkillUp Forever shopping list"],
		#professions > 0 and table.concat(professions, ", ") or L["No tracked profession"],
	}
	local total = 0
	for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
		local bucket = {}
		for _, list in ipairs(lists) do
			for _, row in ipairs(list.items) do
				if row.source == source and row.missing > 0 then
					local name = C_Item.GetItemNameByID(row.itemID)
					if not name then
						C_Item.RequestLoadItemDataByID(row.itemID)
						name = string.format(L["item %d"], row.itemID)
					end
					local text
					if row.price then
						text = string.format(L["%d x %s - %s each"], row.missing, name, PlainMoney(row.price))
						if row.priceAge then
							text = text .. string.format(L[", price seen %d days ago"], row.priceAge)
						end
						text = text .. " - " .. PlainMoney(row.cost)
						total = total + row.cost
					else
						text = string.format(L["%d x %s - price unknown"], row.missing, name)
					end
					bucket[#bucket + 1] = text
				end
			end
		end
		if #bucket > 0 then
			local titles =
				{ gather = L["Gather"], vendor = L["Vendor"], auction = L["Auction house"], unknown = L["Unknown"] }
			lines[#lines + 1] = titles[source]
			for _, line in ipairs(bucket) do
				lines[#lines + 1] = line
			end
		end
	end
	lines[#lines + 1] = L["Total for priced items: "] .. PlainMoney(total)
	return table.concat(lines, "\n")
end

---@param skillLineID integer?
---@return boolean
function ns.ShoppingTrip(skillLineID)
	local lists = API.ShoppingList(skillLineID)
	local byVendor, vendorItems, trainers = {}, {}, {}
	local anyMissing = false
	for _, list in ipairs(lists) do
		local profession = ns.RouteProfessions()[list.skillLine]
		local plan = profession and ns.PlanRoute(profession)
		for _, row in ipairs(list.items) do
			if row.missing > 0 then
				anyMissing = true
				if row.source == "vendor" then
					local npcID = ns.NearestVendor(row.itemID, true)
					if npcID then
						byVendor[npcID] = true
						vendorItems[npcID] = vendorItems[npcID] or {}
						vendorItems[npcID][#vendorItems[npcID] + 1] = row.itemID
					end
				end
			end
		end
		if plan and plan.steps and plan.steps[1] and plan.steps[1].training then
			local npcID = ns.NearestTrainer(profession, plan.steps[1].training.cap, true)
			if npcID then
				trainers[npcID] = true
			end
		end
	end
	if not anyMissing then
		ns.Print(L["Nothing is missing from the shopping list."])
		return false
	end
	local stops = {}
	local ids = {}
	for id in pairs(byVendor) do
		ids[#ids + 1] = id
	end
	local api = ShortestPathForever and ShortestPathForever.API
	local map = C_Map.GetBestMapForUnit("player")
	local point = map and C_Map.GetPlayerMapPosition(map, "player")
	local x, y
	if point then
		x, y = point:GetXY()
	end
	local travel = {}
	for _, id in ipairs(ids) do
		local where = ns.NPCLocation(id)
		travel[id] = api
				and api.Estimate
				and map
				and x
				and y
				and where.map
				and api.Estimate(map, x, y, where.map, where.x, where.y)
			or math.huge
	end
	table.sort(ids, function(a, b)
		return travel[a] == travel[b] and a < b or travel[a] < travel[b]
	end)
	for _, id in ipairs(ids) do
		local where = ns.NPCLocation(id)
		if where.map and where.x and where.y then
			local names = {}
			for _, itemID in ipairs(vendorItems[id]) do
				names[#names + 1] = C_Item.GetItemNameByID(itemID) or string.format(L["item %d"], itemID)
			end
			stops[#stops + 1] = {
				map = where.map,
				x = where.x,
				y = where.y,
				title = where.name .. L[": "] .. table.concat(names, L[", "]),
				kind = "vendor",
			}
		end
	end
	-- The catalogue exposes no faction-aware auctioneer location contract; never guess an NPC here.
	local trainerIDs = {}
	for id in pairs(trainers) do
		trainerIDs[#trainerIDs + 1] = id
	end
	table.sort(trainerIDs)
	for _, id in ipairs(trainerIDs) do
		local where = ns.NPCLocation(id)
		if where.map and where.x and where.y then
			stops[#stops + 1] = { map = where.map, x = where.x, y = where.y, title = where.name, kind = "trainer" }
		end
	end
	while #stops > 64 do
		table.remove(stops)
	end
	if api and type(api.NavigateRoute) == "function" and #stops > 0 and api.NavigateRoute("SkillUpForever", stops) then
		return true
	end
	local first = ids[1]
	if first then
		ns.Print(L["Shortest Path Forever cannot plan the full trip; setting a waypoint to the first vendor."])
		ns.SetWaypoint(first)
	else
		ns.Print(L["Shortest Path Forever is needed to plan this trip."])
	end
	return false
end

---@return SkillUpAPIProfession[]
function API.Professions()
	if not ns.db then
		return {}
	end
	if not cache then
		cache = Build()
	end
	return cache
end

---@param skillLineID integer
---@param stepIndex integer
---@return boolean
function API.Navigate(skillLineID, stepIndex)
	API.Professions()
	local pick = pickers[skillLineID] and pickers[skillLineID][stepIndex]
	local npcID = pick and pick()
	return npcID ~= nil and ns.SetWaypoint(npcID)
end

-- The profession's window, where SkillUp's recipe colours and route tab are.
---@param skillLineID integer
---@return boolean
function API.OpenRecipes(skillLineID)
	local profession = ns.db and ns.RouteProfessions()[skillLineID]
	if not profession then
		return false
	end
	-- Forever's own profession ID opens it; the classic skill line is the fallback, asked only when it is
	-- another ID: the same one again would just repeat a request the client has refused.
	local id = profession.professionID
	if id and C_TradeSkillUI.OpenTradeSkill(id) then
		return true
	end
	return id ~= skillLineID and C_TradeSkillUI.OpenTradeSkill(skillLineID) == true
end

---@type SkillUpPublicAddon
SkillUpForever = { API = API }

ns.WhenEvent("ITEM_DATA_LOAD_RESULT", function()
	return namesPending and "names" or nil
end)
