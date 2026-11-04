---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- Where recipe scrolls, vendors and trainers are, from the catalogue of what QuestieDB and AtlasLoot hold,
-- and how to get there. Everything here reads what the catalogue has already read: nothing is looked up in
-- a provider on the way.

local C = ns.Catalogue
local FACTION_CODES = { Alliance = "A", Horde = "H" }

-- This character's side as the data writes it, "A" or "H"; nil while the client doesn't say.
---@return 'A'|'H'|nil
function ns.PlayerSide()
	return FACTION_CODES[UnitFactionGroup("player") or ""]
end

---@param faction string?
---@return boolean
local function OurFaction(faction)
	return faction == "" or (faction ~= nil and faction == ns.PlayerSide())
end

-- Whether this character can deal with the NPC: one hostile to both sides, or unknown, trades with nobody.
---@param npcID integer
---@return boolean
local function Usable(npcID)
	local npc = C.NPC(npcID)
	return npc ~= nil and OurFaction(npc.side)
end

---@param source SkillUpScrollSource
---@return integer?
local function QuestFor(source)
	for _, questID in ipairs(source.quests) do
		local quest = C.Quest(questID)
		if quest and OurFaction(quest.side) then
			return questID
		end
	end
end

-- The NPC's name, zone and zone map position, as QuestieDB places it. A dungeon has only its name, and an
-- NPC QuestieDB lacks has neither.
---@param npcID integer
---@return SkillUpLocation
function ns.NPCLocation(npcID)
	local npc = C.NPC(npcID)
	if not npc then
		return { name = UNKNOWN, label = L["unknown location"] }
	end
	local info = npc.map and C_Map.GetMapInfo(npc.map)
	if info then
		return { name = npc.name, label = info.name, map = npc.map, x = npc.x, y = npc.y }
	end
	return { name = npc.name, label = npc.area and C_Map.GetAreaInfo(npc.area) or L["unknown location"] }
end

---@param where SkillUpLocation
---@return string
function ns.LocationText(where)
	if where.map then
		return string.format("%s  %.0f, %.0f", where.label, where.x * 100, where.y * 100)
	end
	return where.label
end

-- The squared distance to an NPC on the player's continent, else infinite. The client turns the map point
-- into a world one once an NPC; UnitPosition's first value is the world's north axis, as that point's is.
---@param npcID integer
---@return number
local function Distance(npcID)
	local npc = C.NPC(npcID)
	if not (npc and npc.map) then
		return math.huge
	end
	if npc.world == nil then
		local instance, position = C_Map.GetWorldPosFromMapPos(npc.map, CreateVector2D(npc.x, npc.y))
		npc.world = instance and position and { instance, position:GetXY() } or false
	end
	local px, py, _, instance = UnitPosition("player")
	local world = npc.world
	if not (px and world) or world[1] ~= instance then
		return math.huge
	end
	return (px - world[2]) ^ 2 + (py - world[3]) ^ 2
end

-- Shortest Path Forever's public API, version 1, when it is loaded; callers still
-- check each function they use.
---@return SkillUpShortestPathAPI?
local function ShortestPath()
	local api = ShortestPathForever and ShortestPathForever.API
	return api and api.version == 1 and api or nil
end

-- How many of the straight-line nearest get a travel estimate: a cold one costs
-- Shortest Path Forever a few milliseconds.
local MAX_ESTIMATES = 6

---@return {map: integer, x: number, y: number}?
local function PlayerMapPosition()
	local map = C_Map.GetBestMapForUnit("player")
	local position = map and C_Map.GetPlayerMapPosition(map, "player")
	if not position then
		return nil
	end
	local x, y = position:GetXY()
	return { map = map, x = x, y = y }
end

-- The vendor whose window is open sells these items: the catalogue is told who it is and where the player
-- stands, which is where the vendor is. True when that was news to it.
---@param itemIDs integer[]
---@return boolean
function ns.SeeVendor(itemIDs)
	-- The vendor's GUID and name are secret in some restricted states; then it is not recorded.
	local guid = ns.Readable(UnitGUID("npc"))
	local npcID = guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
	local name, where = ns.Readable(UnitName("npc")), PlayerMapPosition()
	if not (npcID and name and where) then
		return false
	end
	local side = ns.PlayerSide()
	return C.SawVendor(
		npcID,
		{ name = name, side = side, map = where.map, x = where.x, y = where.y, items = {} },
		itemIDs
	)
end

-- Those of these NPCs this character can deal with, nearest first. Ties keep the data's order, so the same
-- few are estimated each time.
---@param npcIDs integer[]
---@return {npcID: integer, distance: number, index: integer}[]
local function Ranked(npcIDs)
	local candidates = {}
	for index, npcID in ipairs(npcIDs) do
		if Usable(npcID) then
			candidates[#candidates + 1] = { npcID = npcID, distance = Distance(npcID), index = index }
		end
	end
	table.sort(candidates, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.index < b.index
	end)
	return candidates
end

-- Of these NPCs, the nearest this character can deal with (the other faction's
-- won't trade or train), else nil. With `byTravel` (a click or tooltip, never a
-- redraw) and Shortest Path Forever loaded, the straight-line nearest few are
-- ranked by its travel time instead, so a flight beats a walk around the coast.
-- When none has a distance (all on another continent, or the player in a dungeon)
-- only a travel time or being the only one picks an NPC: the data's order is no
-- measure of nearness, so with several and nothing to rank them by, none is named.
---@param npcIDs integer[]
---@param byTravel boolean?
---@return integer?
function ns.NearestNPC(npcIDs, byTravel)
	local candidates = Ranked(npcIDs)
	local first = candidates[1]
	local best = first and (first.distance < math.huge or #candidates == 1) and first or nil
	local api = byTravel and first and not InCombatLockdown() and ShortestPath()
	local from = api and type(api.Estimate) == "function" and PlayerMapPosition()
	if api and from then
		local bestSeconds
		for i = 1, math.min(#candidates, MAX_ESTIMATES) do
			local where = ns.NPCLocation(candidates[i].npcID)
			local seconds = where.map and api.Estimate(from.map, from.x, from.y, where.map, where.x, where.y)
			if seconds and (not bestSeconds or seconds < bestSeconds) then
				best, bestSeconds = candidates[i], seconds
			end
		end
	end
	return best and best.npcID
end

-- Shortest Path Forever's route when it takes one (it declines in combat, with its
-- journeys off or without a player position), else TomTom's arrow, else the map's
-- own waypoint, super-tracked; false when there is only a chat line to give, or no NPC to name.
---@param npcID integer
---@return boolean
function ns.SetWaypoint(npcID)
	if not C.NPC(npcID) then
		return false
	end
	local where = ns.NPCLocation(npcID)
	if not where.map then
		ns.Print(string.format(L["%s is in %s."], where.name, where.label))
		return false
	end
	local api = ShortestPath()
	if
		api
		and type(api.Navigate) == "function"
		and api.Navigate("SkillUpForever", where.map, where.x, where.y, where.name)
	then
		ns.Print(string.format(L["route set to %s, %s."], where.name, ns.LocationText(where)))
		return true
	end
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(where.map, where.x, where.y, { title = where.name, from = "SkillUp Forever" })
	elseif C_Map.CanSetUserWaypointOnMap(where.map) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(where.map, where.x, where.y))
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	else
		ns.Print(string.format(L["%s is at %s."], where.name, ns.LocationText(where)))
		return false
	end
	ns.Print(string.format(L["waypoint set to %s, %s."], where.name, ns.LocationText(where)))
	return true
end

local VENDOR, QUEST, DROP, WORLD = 1, 2, 3, 4
local KIND_TEXT = { L["vendor"], L["quest"], L["drop"], L["world drop"] }

-- Best way to get the scroll, easiest first: a vendor, a quest, a named drop, a world drop; nil when only
-- the other faction sells it or may take the quest.
---@param source SkillUpScrollSource
---@return integer?
---@return integer?
local function Kind(source)
	-- Its tooltip lists a scroll's vendors: far ones still make it a vendor's scroll.
	local vendor = ns.NearestNPC(source.vendors)
	for _, npcID in ipairs(source.vendors) do
		vendor = vendor or (Usable(npcID) and npcID or nil)
	end
	if vendor then
		return VENDOR, vendor
	elseif QuestFor(source) then
		return QUEST
	elseif source.drops[1] then
		return DROP, source.drops[1][1]
	elseif source.world then
		return WORLD
	end
end

-- Where a suggestion's click goes: the nearest vendor by travel when one sells the
-- scroll (the one it names when none can be ranked), else the likeliest drop.
---@param suggestion SkillUpSuggestionNPC A suggestion or just where a recipe's scroll comes from.
---@return integer?
function ns.SuggestionNPC(suggestion)
	if suggestion.kind == VENDOR and suggestion.source then
		return ns.NearestNPC(suggestion.source.vendors, true) or suggestion.npcID
	end
	return suggestion.npcID
end

-- Where a recipe is learned: the nearest trainer of the profession when one teaches it (up to just
-- past the skill it asks), else the nearest NPC its scroll comes from. Nil until that is read.
---@param profession SkillUpContext
---@param recipeID integer
---@return integer?
function ns.RecipeNPC(profession, recipeID)
	local training = ns.TrainingFor(profession, recipeID)
	if training then
		return ns.NearestTrainer(profession, training[2] + 1, true)
	end
	local source = C.Recipe(recipeID)
	local kind, npcID
	if source then
		kind, npcID = Kind(source)
	end
	return kind and ns.SuggestionNPC({ kind = kind, source = source, npcID = npcID }) or nil
end

-- Scroll recipes of this profession, not trainer-taught nor learned, that base
-- skill `base` can learn and that still skill up there, easiest to get and then
-- furthest-reaching first. `reach` is base skill too. Empty until the profession's sources are read.
---@param profession SkillUpContext
---@param base number
---@return SkillUpSuggestion[]
function ns.RecipeSuggestions(profession, base)
	local skill = base + profession.modifier
	local found = {}
	if not C.EnsureProfession(profession.skillLine) then
		return found
	end
	for recipeID, recipe in pairs(ns.RecipeData) do
		local source = recipe.skillLine == profession.skillLine and C.Recipe(recipeID)
		local t = source and ns.Model.Get(recipeID)
		local learnAt = source and ns.ScrollSkill(recipeID, source)
		if
			source
			and t
			and learnAt
			and learnAt <= base
			and t[4] > skill
			and not ns.IsLearned(recipeID)
			and not ns.IsSkipped(recipeID)
			and not ns.TrainingFor(profession, recipeID)
		then
			local kind, npcID = Kind(source)
			found[#found + 1] = kind
					and {
						recipeID = recipeID,
						source = source,
						kind = kind,
						kindText = KIND_TEXT[kind],
						npcID = npcID,
						reach = t[4] - profession.modifier,
						color = ns.Model.Color(t, skill),
					}
				or nil
		end
	end
	table.sort(found, function(a, b)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		elseif a.reach ~= b.reach then
			return a.reach > b.reach
		end
		return a.recipeID < b.recipeID
	end)
	return found
end

-- The base skill a scroll asks for: AtlasLoot's, else the bundled scroll item's own requirement.
-- Difficulty bands do not establish a learning requirement.
---@param recipeID integer
---@param source SkillUpScrollSource
---@return number?
function ns.ScrollSkill(recipeID, source)
	local scroll = ns.RecipeScrolls[recipeID]
	return source.skill or (scroll and scroll[2])
end

-- The scroll's price: what it last sold for at auction or at a merchant's window.
---@param source SkillUpScrollSource
---@return number?
function ns.ScrollPrice(source)
	local price = ns.Price(source.item)
	return price and price.copper or nil
end

---@param tooltip GameTooltip
---@param left string
---@param npcID integer
---@param suffix string?
---@param usable boolean
local function AddNPC(tooltip, left, npcID, suffix, usable)
	local where = ns.NPCLocation(npcID)
	GameTooltip_AddColoredDoubleLine(
		tooltip,
		left,
		where.name .. (suffix or ""),
		NORMAL_FONT_COLOR,
		usable and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
	)
	GameTooltip_AddColoredDoubleLine(tooltip, " ", ns.LocationText(where), NORMAL_FONT_COLOR, GRAY_FONT_COLOR)
end

-- A tooltip names this many of a scroll's vendors and counts the rest: each takes two lines.
local SELLERS_SHOWN = 4

-- A scroll's vendors as its tooltip lists them: `first` (where a click goes), then the others this character
-- can deal with, nearest first, then the other faction's.
---@param source SkillUpScrollSource
---@param first integer?
---@return integer[]
local function Sellers(source, first)
	local order, sells = { first }, {}
	for _, candidate in ipairs(Ranked(source.vendors)) do
		order[#order + 1] = candidate.npcID
	end
	for _, npcID in ipairs(source.vendors) do
		order[#order + 1] = npcID
		sells[npcID] = true
	end
	local sellers = {}
	for _, npcID in ipairs(order) do
		if sells[npcID] and C.NPC(npcID) then
			sells[npcID] = nil
			sellers[#sellers + 1] = npcID
		end
	end
	return sellers
end

-- Where the scroll comes from. `first` is the vendor to list first, when a click goes to one.
---@param tooltip GameTooltip
---@param source SkillUpScrollSource
---@param first integer?
function ns.AddSourceLines(tooltip, source, first)
	local sellers = Sellers(source, first)
	for index = 1, math.min(#sellers, SELLERS_SHOWN) do
		AddNPC(tooltip, L["Sold by"], sellers[index], nil, Usable(sellers[index]))
	end
	if #sellers > SELLERS_SHOWN then
		GameTooltip_AddDisabledLine(tooltip, string.format(L["+%d more"], #sellers - SELLERS_SHOWN))
	end
	for _, questID in ipairs(source.quests) do
		local quest = C.Quest(questID)
		if quest then
			GameTooltip_AddColoredDoubleLine(
				tooltip,
				L["Quest"],
				quest.title,
				NORMAL_FONT_COLOR,
				OurFaction(quest.side) and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
			)
		end
	end
	for _, drop in ipairs(source.drops) do
		if C.NPC(drop[1]) then
			AddNPC(tooltip, L["Dropped by"], drop[1], string.format("  (%s%%)", drop[2]), true)
		end
	end
	if source.world then
		GameTooltip_AddNormalLine(tooltip, L["World drop"])
	end
end

-- The nearest trainer of this profession, of your faction, who teaches up to `cap`; nil until the
-- profession's trainers are read.
---@param profession SkillUpContext
---@param cap number
---@param byTravel boolean?
---@return integer?
function ns.NearestTrainer(profession, cap, byTravel)
	if not C.EnsureProfession(profession.skillLine) then
		return nil
	end
	return ns.NearestNPC(C.Trainers(profession.skillLine, cap), byTravel)
end

-- Where a rank is got: the nearest vendor of its book, the nearest giver of its quest, else the nearest trainer
-- teaching it, and the tooltip label for that NPC.
---@param profession SkillUpContext
---@param rank SkillUpRank
---@param byTravel boolean?
---@return integer?
---@return string
function ns.NearestForRank(profession, rank, byTravel)
	if rank.book then
		-- A book you already have is not bought again.
		return not ns.RankHeld(rank) and ns.NearestVendor(rank.book, byTravel) or nil, L["Nearest vendor"]
	end
	if rank.quest then
		local quest = C.Quest(rank.quest)
		return quest and ns.NearestNPC(quest.starters, byTravel) or nil, L["Quest giver"]
	end
	return ns.NearestTrainer(profession, rank.cap, byTravel), L["Nearest trainer"]
end

-- The nearest vendor of an item, of your faction; nil until its vendors are read.
---@param itemID integer
---@param byTravel boolean?
---@return integer?
function ns.NearestVendor(itemID, byTravel)
	if not C.EnsureVendors(itemID) then
		return nil
	end
	local found = C.ItemSources(itemID)
	return found and ns.NearestNPC(found.vendors, byTravel)
end

local SHORTEST_PATH = "ShortestPathForever"
local ADVENTURE_GUIDE = "AdventureGuideForever"
-- Hint keys are shared by every Forever addon (UI/ForeverFamily.lua), so they start with this addon's folder.
local HINT_TRAVEL = "SkillUpForever:travel"
local HINT_QUEST_CHAIN = "SkillUpForever:questChain"

-- Whether Shortest Path Forever is installed but switched off in the AddOns list. A read the client won't give
-- (a secret value, or no C_AddOns) is "don't know", so no line.
---@return boolean
local function ShortestPathDisabled()
	local ok, disabled = pcall(function()
		local _, _, _, _, reason = C_AddOns.GetAddOnInfo(SHORTEST_PATH)
		return reason == "DISABLED"
	end)
	return ok and disabled == true
end

-- Under a waypoint click: what Shortest Path Forever would add. Not installed, it's one of the family hints;
-- installed but switched off, the line says how to get the feature back, under the same setting. `single` is a
-- waypoint to one fixed NPC, where there is no nearest to pick.
---@param tooltip GameTooltip
---@param single? boolean
function ns.AddCompanionHint(tooltip, single)
	local Family = ns.Family
	local state = Family.State(SHORTEST_PATH)
	if state == "missing" then
		if Family.Hint(ns.db, HINT_TRAVEL, SHORTEST_PATH) then
			GameTooltip_AddDisabledLine(
				tooltip,
				single and L["With Shortest Path Forever, a click leads you there."]
					or L["With Shortest Path Forever, this picks the nearest by travel time and leads you there."]
			)
		end
	elseif state == "off" and ns.db.suggestFamily ~= false and ShortestPathDisabled() then
		GameTooltip_AddDisabledLine(tooltip, L["Enable Shortest Path Forever for walked routes and boat times."])
	end
end

-- Under an Artisan quest step, when Adventure Guide Forever isn't installed.
---@param tooltip GameTooltip
function ns.AddQuestChainHint(tooltip)
	if ns.Family.Hint(ns.db, HINT_QUEST_CHAIN, ADVENTURE_GUIDE) then
		GameTooltip_AddDisabledLine(tooltip, L["Adventure Guide Forever can plan this quest chain."])
	end
end

-- "Nearest trainer  Name" over its zone and coordinates, and what a click does; without Questie, the one
-- line saying what would name it.
---@param tooltip GameTooltip
---@param label string
---@param npcID integer?
---@param single? boolean `npcID` is the one place, not the nearest of several
function ns.AddNearest(tooltip, label, npcID, single)
	if not npcID then
		local hint = C.Hint(true)
		if hint then
			GameTooltip_AddDisabledLine(tooltip, hint)
		end
		return
	end
	GameTooltip_AddBlankLineToTooltip(tooltip)
	AddNPC(tooltip, label, npcID, nil, true)
	GameTooltip_AddInstructionLine(tooltip, L["Click for a waypoint."])
	ns.AddCompanionHint(tooltip, single)
end
