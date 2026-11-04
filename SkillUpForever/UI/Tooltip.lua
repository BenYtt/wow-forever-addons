---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

local BAR_WIDTH = 250
local MIN_LABEL_GAP = 18
-- ProfessionsRankBarTemplate's proportions: a fill 439 by 18 inside art 451 by 29, at the tooltip bar's width.
local BAR_SCALE = BAR_WIDTH / 439
local BAR_HEIGHT = 18 * BAR_SCALE
-- The fill texture Blizzard's rank bars use; tinted per difficulty band.
local BAND_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
-- Forever's rested-XP pip, taller than it is wide.
local MARKER_ATLAS = "ui-hud-experiencebar-frame-pip-camelot"
local MARKER_HEIGHT = BAR_HEIGHT * 1.3
-- The bar frame's height, its gap below the line above, and the blank lines that make room for both:
-- GameTooltipText is 12 high with 2 between lines, as GameTooltip_InsertFrame counts them.
local BAR_FRAME_HEIGHT = BAR_HEIGHT + 30
local BAR_PADDING = 4
local BAR_LINES = math.ceil(math.floor(BAR_FRAME_HEIGHT + BAR_PADDING + 0.5) / (12 + 2))

-- The profession window's header skill bar (ProfessionsRankBarTemplate art), scaled down to tooltip size at its
-- own aspect. The tooltip and the crafting page's details pane each ask ns.LayoutSkillBar for one of these.
---@return SkillUpBar
function ns.CreateSkillBar()
	local frame = CreateFrame("Frame", nil, UIParent) --[[@as SkillUpBar]]
	frame:SetSize(BAR_WIDTH, BAR_FRAME_HEIGHT)

	local track = CreateFrame("Frame", nil, frame)
	track:SetPoint("TOPLEFT")
	track:SetSize(BAR_WIDTH, BAR_HEIGHT)
	frame.track = track

	local bg = track:CreateTexture(nil, "BACKGROUND")
	ns.Art.Fit(bg, "Professions-skillbar-bg", 451 * BAR_SCALE, 29 * BAR_SCALE)
	bg:SetPoint("TOPLEFT", -5 * BAR_SCALE, 3 * BAR_SCALE)
	local border = track:CreateTexture(nil, "OVERLAY")
	ns.Art.Fit(border, "Professions-skillbar-frame", 451 * BAR_SCALE, 29 * BAR_SCALE)
	border:SetPoint("TOPLEFT", -5 * BAR_SCALE, 3 * BAR_SCALE)

	frame.segments = {}
	for i, color in ipairs({ "orange", "yellow", "green", "grey" }) do
		local seg = track:CreateTexture(nil, "ARTWORK", nil, 1)
		seg:SetTexture(BAND_TEXTURE) -- art-ok: a status bar fill, stretched to its band
		seg:SetVertexColor(ns.COLORS[color]:GetRGB())
		seg:SetHeight(BAR_HEIGHT)
		frame.segments[i] = seg
	end

	frame.labels = {}
	for i = 1, 4 do
		frame.labels[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	end

	frame.marker = track:CreateTexture(nil, "OVERLAY", nil, 7)
	ns.Art.Fit(frame.marker, MARKER_ATLAS, MARKER_HEIGHT, MARKER_HEIGHT)

	frame.you = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame:Hide()
	return frame
end

-- Lays the four colour bands out over [orange, grey + tail]; the tail keeps the
-- grey band visible and gives the marker somewhere to sit once a recipe is grey.
---@param bar SkillUpBar a frame ns.CreateSkillBar made
---@param t number[]
---@param skill number
---@return SkillUpBar
function ns.LayoutSkillBar(bar, t, skill)
	local height = BAR_HEIGHT
	local lo = t[1]
	local hi = t[4] + math.max(3, math.floor((t[4] - t[1]) * 0.12 + 0.5))
	local function X(value)
		return (math.min(math.max(value, lo), hi) - lo) / (hi - lo) * BAR_WIDTH
	end

	local edges = { t[1], t[2], t[3], t[4], hi }
	for i, seg in ipairs(bar.segments) do
		local left, right = X(edges[i]), X(edges[i + 1])
		seg:SetShown(right > left)
		seg:SetPoint("TOPLEFT", bar.track, "TOPLEFT", left, 0)
		seg:SetWidth(math.max(right - left, 0.1))
	end

	local lastX = -math.huge
	for i, label in ipairs(bar.labels) do
		local x = X(t[i])
		label:SetText(tostring(t[i]))
		label:ClearAllPoints()
		label:SetPoint("TOP", bar, "TOPLEFT", x, -height - 4)
		label:SetShown(x - lastX >= MIN_LABEL_GAP)
		if label:IsShown() then
			lastX = x
		end
	end
	bar.labels[1]:ClearAllPoints()
	bar.labels[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -height - 4)

	local mx = X(skill)
	bar.marker:SetPoint("CENTER", bar, "TOPLEFT", mx, -height / 2)
	bar.you:SetText(string.format(L["You: %d"], skill))
	bar.you:ClearAllPoints()
	bar.you:SetPoint("TOP", bar, "TOPLEFT", math.min(math.max(mx, 24), BAR_WIDTH - 24), -height - 16)
	return bar
end

-- The one bar a tooltip has, made the first time it needs it and kept afterwards.
---@type SkillUpBar?
local bar

-- The tooltips the bar has been put into, whose clearing hides it again.
---@type table<GameTooltip, true>
local hooked = {}

-- Cleared for anything else, the tooltip no longer has the bar's blank lines.
---@param tooltip GameTooltip
local function HideBar(tooltip)
	if not ns.Usable(tooltip) then
		return
	end
	if bar then
		bar:Hide()
	end
end

-- Puts the bar into the tooltip below line `after`. Blizzard's GameTooltip_InsertFrame measures the tooltip to
-- do this, and from our recipe-list handler those measurements are secret, so its arithmetic errored and the
-- error was blamed on SkillUp (#161). Here nothing reads the tooltip: the blank lines are our own, counted from
-- constants, and the bar hangs from the first of them, a line whose number we know.
---@param tooltip GameTooltip
---@param after integer the lines the tooltip has so far
---@param t number[]
---@param skill number
local function AddBar(tooltip, after, t, skill)
	bar = bar or ns.CreateSkillBar()
	local frame = ns.LayoutSkillBar(bar, t, skill)
	for _ = 1, BAR_LINES do
		GameTooltip_AddBlankLineToTooltip(tooltip)
	end
	frame:SetParent(tooltip)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", _G[tooltip:GetName() .. "TextLeft" .. (after + 1)], "TOPLEFT", 0, -BAR_PADDING)
	tooltip:SetMinimumWidth(BAR_WIDTH)
	frame:Show()
	if not hooked[tooltip] then
		hooked[tooltip] = true
		tooltip:HookScript("OnTooltipCleared", HideBar)
	end
end

---@param copper number
---@return string
local function Money(copper)
	return C_CurrencyInfo.GetCoinTextureString(math.floor(copper + 0.5))
end

-- A profit reads as a green "+"; a cost is just the coins.
---@param copper number
---@param profit boolean
---@return string
function ns.FormatNet(copper, profit)
	return (profit and "|cff40ff40+|r" or "") .. Money(copper)
end

-- A recipe's own money, on its row and tooltip: a profit leads with a green "+", a cost with a red "-"
-- (RED_FONT_COLOR's ff2020).
---@param copper number
---@param profit boolean
---@return string
function ns.FormatSigned(copper, profit)
	return (profit and "|cff40ff40+|r" or "|cffff2020-|r") .. Money(copper)
end

local DAY = 86400

-- Seconds since an auction price was seen. Auctionator reports whole days, and
-- nothing past three weeks.
---@param price SkillUpPrice
---@return number?
function ns.PriceAge(price)
	if price.source ~= "auctionator" then
		error("not an auction price: " .. tostring(price.source))
	end
	return not price.ageUnavailable and (price.days or 22) * DAY or nil
end

---@param price SkillUpPrice
---@return string
function ns.PriceAgeText(price)
	if price.source ~= "auctionator" then
		error("not an auction price: " .. tostring(price.source))
	elseif price.ageUnavailable then
		return L["unknown age"]
	elseif price.days == nil then
		return L["over 3 weeks ago"]
	elseif price.days == 0 then
		return L["today"]
	end
	return string.format(L["%dd ago"], price.days)
end

-- What to do about a reagent with no price: auction prices come only from Auctionator.
---@return string
function ns.UnpricedHint()
	if ns.HasAuctionator() then
		return L["Scan the auction house with Auctionator, or visit a vendor, to price reagents."]
	end
	return L["Visit a vendor to price reagents. Auction prices need Auctionator."]
end

---@param price SkillUpPrice
---@return string
function ns.PriceSourceText(price)
	if price.worth == "auction" then
		return string.format(L["you gather it (%s), valued at its AH price"], price.profession)
	elseif price.worth == "vendor" then
		return string.format(L["you gather it (%s), valued at its vendor sell price"], price.profession)
	elseif price.source == "gather" then
		return string.format(L["you gather it (%s)"], price.profession)
	elseif price.source == "vendor" then
		return L["vendor"]
	elseif price.source == "auctionator" then
		return string.format(L["Auctionator, %s"], ns.PriceAgeText(price))
	end
	error("unknown price source: " .. tostring(price.source))
end

-- One line per reagent with its price and source, then the craft and per-skill-up totals.
---@param tooltip GameTooltip
---@param recipeID integer
---@param d SkillUpDescription
local function AddCost(tooltip, recipeID, d)
	local reagents = ns.Reagents(recipeID)
	if not reagents or #reagents == 0 then
		return
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	for _, reagent in ipairs(reagents) do
		local name = C_Item.GetItemNameByID(reagent.itemID) or string.format(L["item %d"], reagent.itemID)
		local left = reagent.quantity > 1 and string.format("%s x%d", name, reagent.quantity) or name
		local price = ns.Price(reagent.itemID)
		if price then
			tooltip:AddDoubleLine(
				left,
				string.format("%s |cff808080(%s)|r", Money(price.copper * reagent.quantity), ns.PriceSourceText(price)),
				1,
				1,
				1,
				1,
				1,
				1
			)
		else
			tooltip:AddDoubleLine(left, L["no price"], 1, 1, 1, 0.5, 0.5, 0.5)
		end
	end
	if not d.cost then
		GameTooltip_AddDisabledLine(tooltip, ns.UnpricedHint())
		return
	end
	tooltip:AddDoubleLine(L["Reagents"], Money(d.cost), 1, 0.82, 0, 1, 1, 1)
	local net = d.net
	if d.value and net then
		local sells = d.value.quantity ~= 1 and string.format(L["Sells for x%g"], d.value.quantity) or L["Sells for"]
		tooltip:AddDoubleLine(
			sells,
			string.format(
				"%s |cff808080(%s)|r",
				Money(d.value.copper),
				d.value.source == "auction" and L["AH"] or L["vendor"]
			),
			1,
			0.82,
			0,
			1,
			1,
			1
		)
		tooltip:AddDoubleLine(
			net < 0 and L["Profit per craft"] or L["Net per craft"],
			Money(math.abs(net)),
			1,
			0.82,
			0,
			1,
			1,
			1
		)
	end
	local perSkillUp = d.perSkillUp
	if perSkillUp then
		local label = perSkillUp < 0 and L["Profit per skill-up"] or L["Per skill-up"]
		tooltip:AddDoubleLine(label, ns.FormatSigned(math.abs(perSkillUp), perSkillUp < 0), 1, 0.82, 0, 1, 1, 1)
	end
end

---@param _ SkillUpNamespace
---@param row SkillUpRecipeRow
---@param data SkillUpRecipeNodeData
function ns.ShowRecipeTooltip(_, row, data)
	local info = data.recipeInfo
	if not ns.db.showTooltip or not info then
		return
	end
	local recipeInfo = Professions.GetHighestLearnedRecipe(info) or info
	local ctx = ns.SkillContext()
	local d = ns.Describe(recipeInfo, ctx)

	local tooltip = GameTooltip
	local where = ns.db.recipeTooltip
	if where == "cursor" then
		tooltip:SetOwner(row, "ANCHOR_CURSOR")
	elseif where == "row" then
		tooltip:SetOwner(row, "ANCHOR_RIGHT")
	else
		-- Beside the window, past the side tabs on its right edge and level with the first: by the row, the
		-- tooltip covered the reagents (#163).
		tooltip:SetOwner(row, "ANCHOR_NONE")
		tooltip:SetPoint("TOPLEFT", ProfessionsFrame.ProfessionsOverviewTab or ProfessionsFrame, "TOPRIGHT", 4, 0)
	end
	GameTooltip_SetTitle(tooltip, recipeInfo.name)
	local t = d.thresholds
	if t and ctx then
		local reqColor = ctx.skill < t[1] and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
		GameTooltip_AddColoredLine(tooltip, string.format(L["Skill range starts at %d"], t[1]), reqColor)
		-- The title and the line above: SetOwner cleared the tooltip.
		AddBar(tooltip, 2, t, ctx.skill)
		if d.chance then
			GameTooltip_AddColoredLine(
				tooltip,
				string.format(L["Skill-up chance: %d%%"], math.floor(d.chance * 100 + 0.5)),
				ns.COLORS[d.color]
			)
		end
	else
		GameTooltip_AddDisabledLine(tooltip, L["No skill data for this recipe yet."])
	end
	if ns.db.showCost then
		AddCost(tooltip, recipeInfo.recipeID, d)
	end
	tooltip:Show()
end

local MAX_USES = 5
local BAND_LABELS = { orange = L["orange"], yellow = L["yellow"], green = L["green"] }
-- The threshold each band ends at.
local BAND_END = { orange = 2, yellow = 3, green = 4 }

-- "yellow until 115": the band the recipe is in now and where it ends.
---@param t number[]
---@param skill number
---@return string
---@return ColorMixin
local function Band(t, skill)
	local band = ns.Model.Color(t, skill)
	if band == "red" then
		return string.format(L["Skill range starts at %d"], t[1]), ns.COLORS.red
	elseif band == "grey" then
		return L["grey"], ns.COLORS.grey
	end
	return string.format(L["%s until %d"], BAND_LABELS[band], t[BAND_END[band]]), ns.COLORS[band]
end

-- Recipes of your professions that still skill up and use this item: learned
-- ones first, then by the skill they need.
---@param itemID integer
---@return SkillUpUse[]
local function Uses(itemID)
	local professions = ns.PlayerProfessions()
	local uses = {}
	for _, recipeID in ipairs(ns.UsedIn(itemID)) do
		local profession = professions[ns.RecipeData[recipeID].skillLine]
		local t = profession and ns.Model.Get(recipeID)
		if t and profession.skill < t[4] then
			uses[#uses + 1] = { recipeID = recipeID, t = t, skill = profession.skill, learned = ns.IsLearned(recipeID) }
		end
	end
	table.sort(uses, function(a, b)
		if a.learned ~= b.learned then
			return a.learned
		end
		if a.t[1] ~= b.t[1] then
			return a.t[1] < b.t[1]
		end
		return a.recipeID < b.recipeID
	end)
	return uses
end

-- "Route: 28/567 · Leatherworking to 150" for each tracked route that needs the item.
---@param tooltip GameTooltip
---@param itemID integer
---@return boolean
local function AddRouteNeeds(tooltip, itemID)
	local added = false
	for _, entry in ipairs(ns.TrackedNeeds()) do
		for _, item in ipairs(entry.items) do
			if item.itemID == itemID then
				if not added then
					GameTooltip_AddBlankLineToTooltip(tooltip)
					added = true
				end
				local have = ns.Have(itemID)
				local text = string.format(
					L["Route: %d/%d · %s to %d"],
					math.min(have, item.need),
					item.need,
					entry.plan.profession.name,
					entry.plan.target
				)
				GameTooltip_AddColoredLine(tooltip, text, have >= item.need and ns.COLORS.green or NORMAL_FONT_COLOR)
			end
		end
	end
	return added
end

---@param tooltip GameTooltip
---@param uses SkillUpUse[]
local function AddUsedIn(tooltip, uses)
	GameTooltip_AddBlankLineToTooltip(tooltip)
	GameTooltip_AddNormalLine(tooltip, L["Used in"])
	for i, use in ipairs(uses) do
		if i > MAX_USES then
			GameTooltip_AddDisabledLine(tooltip, string.format(L["+%d more"], #uses - MAX_USES))
			break
		end
		local band, color = Band(use.t, use.skill)
		local name = C_Spell.GetSpellName(use.recipeID) or string.format(L["recipe %d"], use.recipeID)
		local r, g, b = color:GetRGB()
		tooltip:AddDoubleLine(use.learned and name or string.format(L["%s (unlearned)"], name), band, 1, 1, 1, r, g, b)
	end
end

---@param tooltip GameTooltip
---@param data TooltipData
local function AddUses(tooltip, data)
	if not ns.Usable(tooltip) then
		return
	end
	local itemID = data and data.id
	-- Checked before anything tests the id: even its truth test errors while it is secret.
	if issecretvalue and issecretvalue(itemID) then
		return
	end
	local mode = ns.db.reagentTooltip
	if mode == "off" or not itemID then
		return
	end
	local uses = Uses(itemID)
	if mode == "route" then
		local needed = AddRouteNeeds(tooltip, itemID)
		if IsShiftKeyDown() and #uses > 0 then
			AddUsedIn(tooltip, uses)
		elseif needed and #uses > 0 then
			GameTooltip_AddDisabledLine(tooltip, string.format(L["Shift: used in %d of your recipes"], #uses))
		end
	elseif mode == "full" then
		AddRouteNeeds(tooltip, itemID)
		if #uses > 0 then
			AddUsedIn(tooltip, uses)
		end
	else
		error("unknown reagent tooltip mode: " .. tostring(mode))
	end
end

-- Shift changes what an item tooltip shows, so redraw the one on screen.
---@param key string
local function OnModifierChanged(_, _, key)
	if (key == "LSHIFT" or key == "RSHIFT") and ns.db.reagentTooltip == "route" and GameTooltip:IsShown() then
		-- Read through ns.Readable first, as AddUses does: a secret id errors even on its truth test.
		local itemID = ns.Readable((select(3, GameTooltip:GetItem())))
		if itemID and GameTooltip.RefreshData then
			GameTooltip:RefreshData()
		end
	end
end

-- Gathering (#122): the skill a herb or ore node asks, found by the name on its tooltip, and a gatherable
-- corpse's. Both are coloured from your live skill with Classic's gathering bands (Model.GatherThresholds).

-- "Mining 175" and how it colours at your skill, for a gathering profession you have; "?" for an unknown
-- requirement. Nothing for a profession you don't have.
---@param tooltip GameTooltip
---@param skillLine integer
---@param required number?
local function AddGatherLine(tooltip, skillLine, required)
	local profession = ns.PlayerProfessions()[skillLine]
	if not profession then
		return
	end
	if not required then
		local r, g, b = ns.COLORS.unknown:GetRGB()
		tooltip:AddDoubleLine(profession.name, "?", 1, 1, 1, r, g, b)
		return
	end
	local band, color = Band(ns.Model.GatherThresholds(required), profession.skill)
	local r, g, b = color:GetRGB()
	tooltip:AddDoubleLine(string.format(L["%s %d"], profession.name, required), band, 1, 1, 1, r, g, b)
end

-- The first line of a tooltip's data, when it can be read.
---@param data TooltipData?
---@return string?
local function FirstLine(data)
	local lines = data and data.lines
	local first = lines and lines[1]
	return first and ns.Readable(first.leftText)
end

-- A herb or ore node, by its tooltip's name. The bundled names are classic-db's English ones, so another
-- client language shows nothing rather than a wrong match.
---@param tooltip GameTooltip
---@param data TooltipData
local function AddNodeSkill(tooltip, data)
	if not ns.Usable(tooltip) or not ns.db.gatherTooltip or GetLocale() ~= "enUS" then
		return
	end
	local name = FirstLine(data)
	local node = name and ns.NodeSkills[name]
	if node then
		AddGatherLine(tooltip, node[1], node[2])
	end
end

-- The line the client adds to a corpse something can be gathered from, in its own words in every language,
-- and the gathering skill each one is for: Skinning, Herbalism, Mining.
---@type table<string, integer>?
local corpseLines

---@return table<string, integer>
local function CorpseLines()
	if not corpseLines then
		corpseLines = {}
		for text, skillLine in pairs({
			[UNIT_SKINNABLE_LEATHER or false] = 393,
			[UNIT_SKINNABLE_HERB or false] = 182,
			[UNIT_SKINNABLE_ROCK or false] = 186,
		}) do
			if text then
				corpseLines[text] = skillLine
			end
		end
	end
	return corpseLines
end

---@param tooltip GameTooltip
---@param data TooltipData
local function AddCorpseSkill(tooltip, data)
	if not ns.Usable(tooltip) or not ns.db.gatherTooltip then
		return
	end
	local skillLine
	local lines = CorpseLines()
	for _, line in ipairs(data and data.lines or {}) do
		local text = ns.Readable(line.leftText)
		skillLine = text and lines[text]
		if skillLine then
			break
		end
	end
	if not skillLine then
		return
	end
	-- Read before any test: a secret unit token errors even on its truth test.
	local unit = ns.Readable((select(2, tooltip:GetUnit())))
	local level = unit and ns.Readable(UnitLevel(unit))
	AddGatherLine(tooltip, skillLine, ns.Model.CorpseSkill(level))
end

function ns.AttachItemTooltips()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddUses)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Object, AddNodeSkill)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddCorpseSkill)
	local events = CreateFrame("Frame")
	events:RegisterEvent("MODIFIER_STATE_CHANGED")
	events:SetScript("OnEvent", OnModifierChanged)
end
