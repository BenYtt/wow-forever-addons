---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- Where Shortest Path mentions my other Forever addons, each only while that addon isn't installed and behind the
-- shared rules in UI/ForeverFamily.lua (Suggest my other Forever addons, Don't suggest this again): a grey entry in
-- the quest menus for Adventure Guide, a grey footer in the tracker after a journey arrives with nothing more planned
-- (once a session), and a grey line on a dungeon or raid door's stop for Legacy. With Adventure Guide on, the quest
-- menus list its suggestions instead.

local ADVENTURE, LEGACY = "AdventureGuideForever", "LegacyForever"
local QUEST_MENU, ARRIVAL, ENTRANCE =
	"ShortestPathForever.questMenu", "ShortestPathForever.arrival", "ShortestPathForever.entrance"
-- At most this many Adventure Guide suggestions in a quest menu.
local SUGGESTIONS = 3
-- How long the footer stays under a finished journey with nothing else in the tracker.
local FOOTER_SECONDS = 120
-- Nearby services starts journeys through the API under this name: those are the player's own (UI/Alert.lua).
local OWN = "Shortest Path Forever"

---@class SPFFamilyHints
local Hints = {}
ns.FamilyHints = Hints

---@type { title: string, shownAt: number }?
local footer
local version = 0
---@type SPFPoint?
local journeyPoint
-- Who owned the journey under way, read when it started: API.lua has forgotten the owner by the time it ends.
---@type string?
local journeyOwner

-- With Adventure Guide loaded, its top suggestions (AdventureGuideForever.API.Suggestions, API minor 2), each started
-- as the guide's own Start does. Found by the functions, not a version. An answer other than a list of cards shows
-- nothing; an error shows nothing too, and goes to the error handler and /path report through ns.SafeCall.
---@param root table the menu description being built
---@param api SPFAdventureSuggestionsAPI
local function AddSuggestions(root, api)
	local ok, suggestions = ns.SafeCall("Adventure Guide suggestions", api.Suggestions, SUGGESTIONS)
	if not ok or type(suggestions) ~= "table" then
		return
	end
	local shown = 0
	for _, suggestion in ipairs(suggestions) do
		if shown == SUGGESTIONS then
			break
		end
		if type(suggestion) == "table" and type(suggestion.id) == "string" and type(suggestion.title) == "string" then
			if shown == 0 then
				root:CreateTitle(L["Adventure Guide suggests"])
			end
			shown = shown + 1
			local id, level = suggestion.id, suggestion.level
			local whole = type(level) == "number" and level >= 1 and level <= 1000 and level % 1 == 0
			local text = whole and L["[%d] %s"]:format(level, suggestion.title) or suggestion.title
			root:CreateButton(text, function()
				local started, accepted = ns.SafeCall("Adventure Guide start", api.StartSuggestion, id)
				-- Its route changed since the menu opened, or RestedXP waits out combat.
				if started and not accepted then
					ns.Print(L["Adventure Guide couldn't start that just now. Choose it again from its guide."])
				end
			end)
		end
	end
end

-- Adventure Guide's API when it offers suggestions.
---@return SPFAdventureSuggestionsAPI?
local function SuggestionsAPI()
	local guide = AdventureGuideForever
	local api = type(guide) == "table" and guide.API or nil
	if type(api) == "table" and type(api.Suggestions) == "function" and type(api.StartSuggestion) == "function" then
		return api --[[@as SPFAdventureSuggestionsAPI]]
	end
end

-- The quest menus, under Plan journey: Adventure Guide's suggestions when it offers them, else, while it is missing,
-- the grey entry that says what it would add.
---@param root table the menu description being built
function Hints.AddQuestMenu(root)
	local api = SuggestionsAPI()
	if api then
		AddSuggestions(root, api)
	elseif ns.Family.Hint(ns.db, QUEST_MENU, ADVENTURE) then
		root:CreateButton(
			GRAY_FONT_COLOR:WrapTextInColorCode(L["Suggest quests for my level: Adventure Guide Forever"]),
			function()
				ns.Family.ShowLink(ns.db, QUEST_MENU, ADVENTURE, nil, L)
			end
		)
	end
end

-- The stop pin's tooltip line on a dungeon or raid door. Shortest Path can't tell which instances Legacy has
-- challenges for, so every door gets it.
---@param tooltip GameTooltip
function Hints.AddEntranceLine(tooltip)
	local goal = ns.JourneyGoal()
	if goal and goal.entrance and ns.Family.Hint(ns.db, ENTRANCE, LEGACY) then
		GameTooltip_AddColoredLine(
			tooltip,
			L["Legacy Forever shows the Legacy challenges this counts toward."],
			GRAY_FONT_COLOR
		)
	end
end

-- The footer's block for the tracker, or nil. It goes when a new journey starts, the hint no longer applies (the
-- setting, a dismissal, or Adventure Guide now installed), the journey is hidden from the tracker, or
-- FOOTER_SECONDS have passed. Only RefreshTracker asks, so a footer that goes is redrawn away at once.
---@return { key: string, title: string, rows: SPFRow[] }?
function Hints.Footer()
	if
		footer
		and (
			ns.HasJourney()
			or ns.db.journeyTracker == false
			or GetTime() - footer.shownAt >= FOOTER_SECONDS
			or not ns.Family.Hint(ns.db, ARRIVAL, ADVENTURE)
		)
	then
		footer = nil
		version = version + 1
	end
	if not footer then
		return nil
	end
	return {
		key = "family",
		title = footer.title,
		rows = {
			{
				key = "family",
				text = L["What next? Adventure Guide Forever suggests quests for your level."],
				grey = true,
			},
		},
	}
end

-- Changes whenever the footer comes or goes, for the tracker's own change check.
---@return integer
function Hints.Version()
	return version
end

-- Clicking the footer shows the link and takes the footer away: it has done its job.
function Hints.OpenFooter()
	if not footer then
		return
	end
	if ns.Family.ShowLink(ns.db, ARRIVAL, ADVENTURE, nil, L) then
		footer = nil
		version = version + 1
		ns.RefreshTracker()
	end
end

-- ns.JourneyChanged: a point is the next stop; nil with "arrived" ends the journey with nothing more planned.
-- Only the player's own journeys count: a guide or another addon driving the journey has its own next step.
-- EndJourney redraws the tracker after this, so the footer only needs its version moved.
---@param point SPFPoint?
---@param reason? "arrived"|"cleared"
local function JourneyChanged(point, reason)
	if point then
		journeyPoint, journeyOwner = point, ns.JourneyOwner()
		return
	end
	local finished, owner = journeyPoint, journeyOwner
	journeyPoint, journeyOwner = nil, nil
	if reason ~= "arrived" or not finished or (owner ~= nil and owner ~= OWN) or ns.db.journeyTracker == false then
		return
	end
	if ns.Family.Hint(ns.db, ARRIVAL, ADVENTURE) and ns.Family.Once(ARRIVAL) then
		footer = {
			title = finished.routeTitle or L["Journey to %s"]:format(ns.PlaceLabel(finished)),
			shownAt = GetTime(),
		}
		version = version + 1
		C_Timer.After(FOOTER_SECONDS, ns.RefreshTracker)
	end
end

ns.Init(function()
	-- After every file has loaded, so API.lua's ns.JourneyChanged exists to hook.
	hooksecurefunc(ns, "JourneyChanged", JourneyChanged) -- taint-ok: ns is this addon's own namespace table.
end)
