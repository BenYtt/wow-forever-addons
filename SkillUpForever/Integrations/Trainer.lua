---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- Per trainer update: which recipe each service teaches, and the one to train next.
---@type SkillUpTrainerState?
local state

-- The service tooltip carries the taught spell when the client exposes it; the
-- name is the fallback. Only an ID we have data for counts as a recipe.
---@param index integer
---@return integer?
local function TooltipRecipe(index)
	local data = C_TooltipInfo and C_TooltipInfo.GetTrainerService(index)
	local id = data and data.id
	if not (issecretvalue and issecretvalue(id)) and id and ns.RecipeData[id] then
		return id
	end
end

---@param services SkillUpTrainerService[]
---@return integer?
local function TrainerSkillLine(services)
	for _, service in pairs(services) do
		if service.recipeID then
			return ns.RecipeData[service.recipeID].skillLine
		end
	end
	local professions = ns.PlayerProfessions()
	for index in pairs(services) do
		local skillName = GetTrainerServiceSkillReq(index)
		for skillLine, profession in pairs(professions) do
			if profession.name == skillName then
				return skillLine
			end
		end
	end
end

---@param services SkillUpTrainerService[]
---@return table<integer, boolean>
local function Known(services)
	local known = {}
	for _, service in pairs(services) do
		if service.recipeID and service.kind == "used" then
			known[service.recipeID] = true
		end
	end
	return known
end

-- What this trainer would teach now that the player can pay for.
---@param services SkillUpTrainerService[]
---@return {recipeID: integer, fee: number}[]
local function Offers(services)
	local offers = {}
	local money = GetMoney()
	for index, service in pairs(services) do
		local fee = GetTrainerServiceCost(index)
		if service.recipeID and service.kind == "available" and fee <= money then
			offers[#offers + 1] = { recipeID = service.recipeID, fee = fee }
		end
	end
	return offers
end

-- What this trainer charges for each rank it still offers, kept under the cap the rank trains to. A rank
-- is the one row that is no recipe and wants the skill the bundled rank does; when two rows fit, neither
-- is trusted.
---@param skillLine integer
---@param services SkillUpTrainerService[]
local function NoteRanks(skillLine, services)
	for _, rank in ipairs(ns.TrainerRanks[skillLine] or {}) do
		local cap, reqSkill = rank[1], rank[3]
		local found, fits = nil, 0
		for index, service in pairs(services) do
			local _, required = GetTrainerServiceSkillReq(index)
			if not service.recipeID and not service.ambiguous and service.kind ~= "used" and required == reqSkill then
				found, fits = index, fits + 1
			end
		end
		if found and fits == 1 then
			ns.db.trainerRanks[skillLine] = ns.db.trainerRanks[skillLine] or {}
			ns.db.trainerRanks[skillLine][cap] = GetTrainerServiceCost(found)
		end
	end
end

---@return SkillUpTrainerService[]
local function Services()
	local services = {}
	for index = 1, GetNumTrainerServices() do
		local name, kind = GetTrainerServiceInfo(index)
		services[index] = { name = name, kind = kind, recipeID = TooltipRecipe(index) }
	end
	return services
end

---@return SkillUpTrainerState
local function BuildState(services)
	services = services or Services()
	local skillLine = TrainerSkillLine(services)
	local rank, maxRank, modifier = GetTrainerTradeskillRankValues()
	if not (skillLine and rank and maxRank) then
		return { services = services }
	end
	local names = ns.RecipeNames[skillLine] or {}
	for _, service in pairs(services) do
		if not service.recipeID and service.name then
			local match = names[service.name]
			service.ambiguous = match == false
			service.recipeID = match or nil
		end
	end
	-- Every recipe this trainer teaches, its fee and required skill, for routes
	-- planned away from it (bundled base fees miss discounts and Forever changes).
	local seen = ns.db.trainer[skillLine] or {}
	ns.db.trainer[skillLine] = seen
	-- A row that shows no skill requirement keeps the bundled one: recording 0 would plan to learn it at once.
	-- The third value is the requirement the trainer showed, kept apart so /su trainers can tell the two apart.
	for index, service in pairs(services) do
		if service.recipeID then
			local _, shown = GetTrainerServiceSkillReq(index)
			local bundled = ns.TrainerFees[service.recipeID]
			local required = shown or (bundled and bundled[2])
			if required then
				seen[service.recipeID] = { GetTrainerServiceCost(index), required, shown }
			end
		end
	end
	NoteRanks(skillLine, services)
	ns.Changed("fees")
	modifier = modifier or 0
	local ctx = {
		skillLine = skillLine,
		base = rank,
		skill = rank + modifier,
		modifier = modifier,
		max = maxRank,
		capped = maxRank > 0 and rank >= maxRank,
	}
	return { services = services, ctx = ctx, best = ns.BestTraining(ctx, Known(services), Offers(services)) }
end

-- Every bundled trainer requirement a trainer could prove wrong (#124): those moved from classic-db's by how far
-- Forever moved the recipe's range or down to where players made it (SEEN_REQUIREMENTS in tools/gen_trainer.py),
-- and any a trainer showed differently. `shown` is what a trainer showed, nil
-- until this character's profession trainer has been opened since this was recorded; `visited` is whether a
-- trainer listed the recipe at all.
---@return SkillUpTrainerCheck[]
function ns.TrainerChecks()
	local checks, listed = {}, {}
	---@param skillLine integer
	---@param recipeID integer
	local function Add(skillLine, recipeID)
		local key = skillLine .. ":" .. recipeID
		if listed[key] then
			return
		end
		local seen = ns.db.trainer[skillLine] and ns.db.trainer[skillLine][recipeID]
		local bundled = ns.TrainerFees[recipeID]
		local check = {
			skillLine = skillLine,
			recipeID = recipeID,
			bundled = bundled and bundled[2],
			classic = ns.TrainerInferred[recipeID],
			shown = seen and seen[3],
			visited = seen ~= nil,
		}
		if check.classic or (check.shown and check.shown ~= check.bundled) then
			listed[key] = true
			checks[#checks + 1] = check
		end
	end
	for recipeID in pairs(ns.TrainerInferred) do
		local recipe = ns.RecipeData[recipeID]
		if recipe then
			Add(recipe.skillLine, recipeID)
		end
	end
	for skillLine, seen in pairs(ns.db.trainer) do
		for recipeID in pairs(seen) do
			Add(skillLine, recipeID)
		end
	end
	table.sort(checks, function(a, b)
		if a.skillLine ~= b.skillLine then
			return a.skillLine < b.skillLine
		end
		if (a.bundled or 0) ~= (b.bundled or 0) then
			return (a.bundled or 0) < (b.bundled or 0)
		end
		return a.recipeID < b.recipeID
	end)
	return checks
end

---@param recipeID integer
---@return string
local function RecipeName(recipeID)
	return C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
end

-- /su export trainers (#124): the requirements a trainer has actually shown this character, as a table literal for
-- tools/gen_trainer.py's SEEN_REQUIREMENTS, so a player can paste them into a report and the guess improves for
-- everyone. A row that saved only a fee and the bundled requirement has seen nothing; where two skill lines hold
-- one recipe, the longest requirement wins. Reads ns.db.trainer and formats it: nothing here writes, prints or
-- waits on the world. The keys are bracketed because Lua has no `key: value` field: that is the form loadstring
-- reads back, and the one a player can paste into the generator's dictionary by hand.
---@return string[] lines the table, empty when no trainer has shown a requirement yet
function ns.TrainerExport()
	local longest = {}
	for skillLine, recipes in pairs(ns.db.trainer) do
		for recipeID, row in pairs(recipes) do
			local shown = type(row) == "table" and row[3]
			if type(shown) == "number" and shown > 0 then
				local best = longest[recipeID]
				if not best or shown > best.shown then
					longest[recipeID] = { shown = shown, skillLine = skillLine }
				end
			end
		end
	end
	local recipeIDs = {}
	for recipeID in pairs(longest) do
		recipeIDs[#recipeIDs + 1] = recipeID
	end
	if #recipeIDs == 0 then
		return {}
	end
	table.sort(recipeIDs)
	local lines = { "SEEN_REQUIREMENTS = {" }
	for _, recipeID in ipairs(recipeIDs) do
		local entry = longest[recipeID]
		local profession = entry.skillLine and ns.Gear.ProfessionName(entry.skillLine)
		-- A control character in a name would end the comment line and break the table.
		local comment = RecipeName(recipeID):gsub("%c", " ")
		if profession then
			comment = comment .. ", " .. profession
		end
		lines[#lines + 1] = string.format("    [%d] = %d, -- %s", recipeID, entry.shown, comment)
	end
	lines[#lines + 1] = "}"
	return lines
end

-- What /su trainers prints: per profession, how many moved requirements a trainer has confirmed, each one a
-- trainer showed differently, and, for a profession this character has, the ones its trainer should teach at
-- the current skill if the bundled value is right, so a visit now settles them.
---@return string[]
function ns.TrainerReport()
	local professions = ns.PlayerProfessions()
	local lines, groups, order = {}, {}, {}
	for _, check in ipairs(ns.TrainerChecks()) do
		local group = groups[check.skillLine]
		if not group then
			group = { moved = 0, confirmed = 0, wrong = {}, now = {} }
			groups[check.skillLine] = group
			order[#order + 1] = check.skillLine
		end
		if check.classic then
			group.moved = group.moved + 1
		end
		local name = RecipeName(check.recipeID)
		if check.shown and check.shown == check.bundled then
			group.confirmed = group.confirmed + 1
		elseif check.shown then
			group.wrong[#group.wrong + 1] = string.format(
				L["%s (%d): bundled %s, the trainer wants %d"],
				name,
				check.recipeID,
				check.bundled and tostring(check.bundled) or L["none"],
				check.shown
			)
		end
		-- Between the guess and classic-db's, the trainer's answer settles which is right. A recipe a trainer
		-- already listed (with or without a requirement) has had its visit.
		local profession = professions[check.skillLine]
		if
			profession
			and check.classic
			and check.bundled
			and not check.visited
			and not ns.IsLearned(check.recipeID)
			and math.min(check.bundled, check.classic) <= profession.base
			and profession.base < math.max(check.bundled, check.classic)
		then
			group.now[#group.now + 1] = string.format(
				L["%s (%d): bundled %d, classic-db %d"],
				name,
				check.recipeID,
				check.bundled,
				check.classic
			)
		end
	end
	if #order == 0 then
		return { L["no trainer requirements to check."] }
	end
	for _, skillLine in ipairs(order) do
		local group = groups[skillLine]
		lines[#lines + 1] = string.format(
			L["%s: %d moved, %d confirmed at a trainer, %d wrong."],
			ns.Gear.ProfessionName(skillLine),
			group.moved,
			group.confirmed,
			#group.wrong
		)
		for _, line in ipairs(group.wrong) do
			lines[#lines + 1] = "  " .. line
		end
		if #group.now > 0 then
			lines[#lines + 1] = "  " .. L["Its trainer should teach these at your skill now:"]
			for _, line in ipairs(group.now) do
				lines[#lines + 1] = "    " .. line
			end
		end
	end
	return lines
end

-- The recipe to train next wears the green arrow the bags put on an upgrade, 13 tall at its own aspect.
local MARKER_ATLAS, MARKER_HEIGHT = "bags-greenarrow", 13
---@type string?
local marker

---@return string
local function Marker()
	if not marker then
		marker = C_Texture.GetAtlasInfo(MARKER_ATLAS) and ns.Art.Markup(MARKER_ATLAS, MARKER_HEIGHT) .. " " or ""
	end
	return marker
end

-- ClassTrainerSkillButtonTemplate's "Requires:" line starts 48 in (the icon at 6, 36 wide, then 6).
-- The row text sits right of it, 8 from the button's right edge, and ends in "..." rather than reach it.
local REQUIREMENT_LEFT, GAP, RIGHT = 48, 6, 8

---@param button SkillUpTrainerButton
---@param elementData SkillUpTrainerElement
local function Decorate(button, elementData)
	local text = button.SkillUpText
	if text then
		text:Hide()
	end
	elementData = elementData and (elementData.data or elementData)
	local index = elementData and elementData.skillIndex
	-- No state while a rebuild is pending; the rebuild redecorates.
	local current = state
	local service = current and index and current.services[index]
	if not (current and service and current.ctx and (service.recipeID or service.ambiguous)) then
		return
	end
	if not text then
		text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("BOTTOMRIGHT", -RIGHT, 6)
		text:SetJustifyH("RIGHT")
		text:SetWordWrap(false)
		button.SkillUpText = text
	end
	local requirement = button.subText
	local room = button:GetWidth()
		- RIGHT
		- REQUIREMENT_LEFT
		- math.min(requirement:GetStringWidth(), requirement:GetWidth())
		- GAP
	if room < 1 then
		return
	end
	text:SetWidth(room)
	if service.recipeID then
		local d = ns.Describe({ recipeID = service.recipeID, learned = service.kind == "used" }, current.ctx)
		local best = service.recipeID == current.best and Marker() or ""
		text:SetText(best .. ns.FormatRow(d))
		text:SetTextColor(ns.RowColor(d):GetRGB())
	else
		text:SetText("?")
		text:SetTextColor(ns.COLORS.unknown:GetRGB())
	end
	text:Show()
end

local function DecorateAll()
	ClassTrainerFrame.ScrollBox:ForEachFrame(function(button)
		Decorate(button, button:GetElementData())
	end)
	local step = GetTrainerServiceStepIndex()
	if step and ClassTrainerFrame.skillStepButton:IsShown() then
		Decorate(ClassTrainerFrame.skillStepButton, { skillIndex = step })
	end
end

-- Blizzard updates once per service name that arrives, and redraws the buttons
-- inside each update; drop the old state at once and rebuild once, next frame.
local pending = false
local function RefreshTrainer()
	state = nil
	if pending or not ClassTrainerFrame:IsShown() then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		local tradeskill = C_Trainer.GetTrainerType() == Enum.TrainerType.Tradeskills
		local shown = tradeskill and ClassTrainerFrame:IsShown()
		local services = shown and Services() or nil
		if services then
			-- A trainer for a profession with a route still ahead starts tracking it on its own.
			ns.AutoTrack(TrainerSkillLine(services))
		end
		state = ns.db.showTrainer and services and BuildState(services) or nil
		DecorateAll()
	end)
end

function ns.AttachTrainer()
	hooksecurefunc("ClassTrainerFrame_InitServiceButton", Decorate)
	hooksecurefunc("ClassTrainerFrame_Update", RefreshTrainer)
	ns.WhenStale("trainer", RefreshTrainer)
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_MONEY")
	events:RegisterEvent("TRAINER_CLOSED")
	events:SetScript("OnEvent", RefreshTrainer)
end
