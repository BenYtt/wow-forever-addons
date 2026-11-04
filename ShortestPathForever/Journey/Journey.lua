---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- Shift-click the world map: the fastest way there from here, by foot, flight, boat, zeppelin, tram and portal,
-- with the boats' live waits. JourneySearch.lua finds the way; this follows it: the goal, the route and how far
-- along it you are, Guide and the frame driver. The tracker owns the list; closing the map leaves the journey running.
local REPLAN_EVERY = 5
local REPLAN_DUE = REPLAN_EVERY - 0.5 -- from here Itinerary.lua leaves the frames to the timed replan
local DRAW_EVERY = 0.5
-- A teleport step, by the item's or spell's own name in the game's language, after its own icon at the font's
-- height: the one step you act on from your bags or spellbook stands out from the travel around it.
local USE_ITEM, CAST_SPELL = L["Use %s"], L["Cast %s"]
-- art-ok: a square item or spell icon, square at the font's height (size 0)
local ICON = "|T%d:0|t "

local goal, result
local policyChanged
local nextPoint
local progress = { index = 1 }
local withoutHearth = false
---@class SPFJourneyDriver : Frame
---@field elapsed number
---@field replannedAt? number GetTime of the last timed replan
---@field speed? number run speed seen on the last frame
---@field progressElapsed number
---@field riding? number
---@field flying? boolean
---@field drawAt? number
---@field drawX? number
---@field drawY? number
---@field drawMap? number
---@type SPFJourneyDriver
local driver
local ARRIVAL = 15
local Search, Guide = ns.JourneySearch, ns.JourneyGuide
local RefreshTracker, StopGuide = Guide.RefreshTracker, Guide.Stop
-- Walking along a measured path from where you stood, how far off it you may stray and still be on it.
local ON_PATH = 15
-- Water Walking, Levitate and the Elixir of Water Walking make water ground. A spell you know counts too: the step
-- asks you to cast it.
local WATER_AURAS = { 546, 1706, 11319 }
local WATER_SPELLS = { 546, 1706 }
-- Yards over water worth casting for.
local WATER_HINT = 20
local WALK_FAILURE = ns.WalkFailure

-- While you are a ghost, Corpse.lua's run borrows the route drawing, the tracker and Guide; the journey waits.
local function CorpseRun()
	return ns.Corpse ~= nil and ns.Corpse.Active()
end

---@return boolean
function ns.HasJourney()
	return goal ~= nil or CorpseRun()
end

-- The plan being followed and the step under way, whatever the tracker shows (paused or behind a corpse run).
---@return SPFPlan? plan, integer index
function ns.JourneyPlan()
	return result, progress.index
end

---@param plan SPFPlan
---@param current integer
---@return SPFRow?
function ns.NewFlightPathReminderRow(plan, current)
	for index = current, #plan.legs do
		local leg = plan.legs[index]
		if leg.mode == "walk" and leg.to.undiscovered then
			return {
				key = "new-flight-path",
				text = string.format(L["Step %d: discover flight master %s before flying."], index, ns.LegLabel(leg)),
				grey = true,
			}
		end
	end
	return nil
end

-- Where the journey goes, also while it waits behind a corpse run; nil with no journey.
---@return SPFPoint?
function ns.JourneyGoal()
	return goal
end

function ns.JourneyWithoutHearth()
	return withoutHearth
end

function ns.TravelPolicyChanged()
	policyChanged = true
	if ns.ItineraryChanged then
		ns.ItineraryChanged(true)
	end
	ns.WakeTravel()
end

-- Whether walks may cross water, and the spell to cast first when none is up.
local function WaterWalking()
	for _, id in ipairs(WATER_AURAS) do
		if C_UnitAuras.GetPlayerAuraBySpellID(id) then
			return true
		end
	end
	for _, id in ipairs(WATER_SPELLS) do
		-- IsPlayerSpell is a deprecation fallback, defined only while the loadDeprecationFallbacks CVar is on.
		if C_SpellBook.IsSpellKnown(id) then
			return true, id
		end
	end
	return false
end

-- Read-only capability query shared by the public estimator and the guided planner.
ns.JourneyWaterWalking = WaterWalking

-- A missing/secret sample is not evidence that the journey is unreachable. Every read of the player's position goes
-- through this gate; ride observation alone also takes the client's height, nil while it is secret.
---@return number? x, number? y, number? z, number? map
function ns.PlayerPosition()
	local x, y, z, map = UnitPosition("player")
	if not (canaccessvalue(x) and canaccessvalue(y) and canaccessvalue(map)) or not (x and y and map) then
		return nil
	end
	return x, y, canaccessvalue(z) and z or nil, map
end

-- Planning, Guide and lines share this gate. UnitPosition's third value is no floor to plan from, so the player's
-- height is unknown here.
---@return number? x, number? y, nil z, number? map
function ns.JourneyPosition()
	local x, y, _, map = ns.PlayerPosition()
	return x, y, nil, map
end

local function Here()
	local x, y, _, map = ns.JourneyPosition()
	return x and { map = map, x = x, y = y }
end

local function Near(node, reach)
	local x, y, _, map = ns.JourneyPosition()
	return x and map == node.map and (x - node.x) ^ 2 + (y - node.y) ^ 2 <= (reach or ARRIVAL) ^ 2
end

-- The client's own answer for the quests a held stop names: true inside any of their areas, false outside them
-- all, nil when the stop names none or the client has or shares no answer for any of them.
---@param point SPFPoint
---@return boolean?
local function InsideQuestArea(point)
	local insideQuestBlob = C_Minimap and C_Minimap.IsInsideQuestBlob
	if not (point.questIDs and insideQuestBlob) then
		return nil
	end
	local answer
	for _, questID in ipairs(point.questIDs) do
		local inside = insideQuestBlob(questID)
		if canaccessvalue(inside) then
			if inside == true then
				return true
			end
			answer = false
		end
	end
	return answer
end

-- Whether the client itself places the player in the area of a quest the held stop names. Only then is there an
-- area of the game's own to show in the stop's place.
---@param point SPFPoint?
---@return boolean
function ns.StopInQuestArea(point)
	return point ~= nil and point.hold == true and InsideQuestArea(point) == true
end

-- Whether the player stands in a held stop's objective area. A stop that names the quests it stands for is
-- answered by the client's own blob state, which is what its minimap draws and the player sees; a client that
-- withholds or does not have it, and a stop the guide only has circles for, falls back to the shapes and radius.
---@param point SPFPoint?
---@return boolean
function ns.StopInside(point)
	if not (point and point.hold) then
		return false
	end
	local inside = InsideQuestArea(point)
	if inside ~= nil then
		return inside
	end
	local x, y, _, map = ns.JourneyPosition()
	if not (x and map == point.map) then
		return false
	end
	if point.shapes then
		for _, shape in ipairs(point.shapes) do
			if shape.map == map and (x - shape.x) ^ 2 + (y - shape.y) ^ 2 <= shape.radius ^ 2 then
				return true
			end
		end
		return false
	end
	return point.radius ~= nil and (x - point.x) ^ 2 + (y - point.y) ^ 2 <= point.radius ^ 2
end

---@param reason "arrived"|"cleared"
local function EndJourney(reason)
	Search.Reset()
	goal, result, nextPoint = nil, nil, nil
	withoutHearth = false
	if ns.JourneyChanged then
		ns.JourneyChanged(nil, reason)
	end
	progress.index, progress.departed = 1, false
	driver:Hide()
	if not CorpseRun() then
		StopGuide()
		ns.SetJourneyRoute(nil)
	end
	RefreshTracker()
end

-- Menus and settings pass their own arguments to callbacks, so the player's clear takes none.
function ns.ClearJourney()
	EndJourney("cleared")
end

-- Completion may run inside a planner callback. Start at most one next stop on the driver's next step,
-- after that callback unwinds; coincident stops must never recurse through the whole route in one frame.
local function Arrive()
	nextPoint = ns.NextJourneyStop and ns.NextJourneyStop(goal)
	if not nextPoint then
		EndJourney("arrived")
	end
end

local function UpdateProgress()
	if not (goal and result) or nextPoint or CorpseRun() then
		return
	end
	if goal.hold and ns.StopInside(goal) then
		Guide.Pause()
		return
	end
	-- A dungeon's door is reached by going in (EnteredInstance), never by standing beside it: the stop it stands for
	-- is inside, and the next stop may be too.
	if not goal.hold and not goal.entrance and Near(goal) then
		Arrive()
		return
	end
	local riding, flying = ns.CurrentRide(), UnitOnTaxi("player")
	if ns.AdvanceJourneyProgress(result.legs, progress, goal, riding, flying, Near, Guide) or goal.entrance then
		return
	end
	Arrive()
end

-- Going in through the door of the instance a journey's stop is inside completes that stop.
local function EnteredInstance()
	if goal and goal.entrance and not nextPoint and select(8, GetInstanceInfo()) == goal.entrance then
		Arrive()
		if nextPoint then
			ns.StartJourney(nextPoint)
		end
	end
end

---@return boolean
function ns.IsJourneyGuided()
	return Guide.Active()
end

---@return boolean pending, integer settleRound, string? costError why no walk could be measured, if one could not
function ns.JourneyStatus()
	local pending, settleRound, costError = Search.Status()
	return pending > 0, settleRound, costError
end

local function StartGuide()
	Guide.Start()
	UpdateProgress()
end

function ns.ToggleJourneyGuide()
	if Guide.Active() then
		StopGuide()
	elseif CorpseRun() then
		Guide.Start()
		ns.Corpse.Steer()
	elseif goal then
		StartGuide()
	end
	RefreshTracker()
end

function ns.ShowJourneyMap()
	local place = CorpseRun() and ns.Corpse.Point() or goal
	local location = place and ns.Locate(place)
	ns.OpenWorldMap(location and location.uiMap)
end

-- The tracker and screen prompt name the same item or spell in the client's language.
---@param teleport SPFTeleportPlace
---@return string action, number? icon
function ns.TeleportAction(teleport)
	local name = teleport.item and C_Item.GetItemNameByID(teleport.item)
		or C_Spell.GetSpellName(teleport.spell)
		or UNKNOWN
	local icon = teleport.item and C_Item.GetItemIconByID(teleport.item) or (C_Spell.GetSpellTexture(teleport.spell))
	return (teleport.item and USE_ITEM or CAST_SPELL):format(name), icon
end

-- Shared by the tracker and the goal pin, including on a fullscreen map.
---@return string? title, SPFRow[]? rows, SPFPlan? plan, number? index, boolean? loading
function ns.JourneyInfo()
	if CorpseRun() then
		return ns.Corpse.Info()
	end
	if not goal or Guide.Paused() then
		return nil
	end
	local title = goal.routeTitle or string.format(L["Journey to %s"], ns.PlaceLabel(goal))
	local rows = {}
	local _, _, costError, loading = Search.Status()
	if not result and loading then
		rows[1] = { key = "searching", text = L["Finding the fastest way…"], grey = true }
	elseif result then
		local _, spell = WaterWalking()
		local reminder = ns.NewFlightPathReminderRow(result, progress.index)
		if reminder then
			rows[#rows + 1] = reminder
		end
		for index = progress.index, #result.legs do
			local leg = result.legs[index]
			local text
			local teleport = leg.teleport
			if teleport then
				local action, icon = ns.TeleportAction(teleport)
				text = string.format("%d. %s%s", index, icon and ICON:format(icon) or "", action)
			else
				text = string.format("%d. %s", index, ns.LegStep(leg))
			end
			if leg.mode == "walk" and leg.to.undiscovered then
				text = string.format(L["%s (new flight path)"], text)
			end
			if leg.walkError then
				text = text .. " (" .. (WALK_FAILURE[leg.walkError] or L["walking search failed"]) .. ")"
			end
			if spell and leg.wet and leg.wet >= WATER_HINT then
				text = string.format(L["%s (cast %s)"], text, C_Spell.GetSpellName(spell))
			end
			rows[#rows + 1] = {
				key = index,
				text = loading and text or text .. "   " .. ns.LegTime(leg),
				current = index == progress.index,
			}
			-- Hostile towns and high zones on this walk, under its step.
			for note, line in ipairs(leg.hazardNotes or {}) do
				rows[#rows + 1] = { key = index .. ":" .. note, text = line, grey = true }
			end
		end
	else
		rows[1] = { key = "unreachable", text = costError and WALK_FAILURE[costError] or L["No way there from here."] }
	end
	return title, rows, result, progress.index, loading
end

-- Where here falls on a walk: the segment ending at points[index], how far along it (t), and the yards still to walk
-- from there, or nil when here is more than reach (ON_PATH by default) off the walk.
local function OnWalk(points, here, reach)
	if not here then
		return nil
	end
	local lengths, total = {}, 0
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		lengths[index] = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
		total = total + lengths[index]
	end
	local walked, best, found, along, after = 0, nil, nil, nil, nil
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		local dx, dy, length = b.x - a.x, b.y - a.y, lengths[index]
		local t = length > 0 and math.max(0, math.min(1, ((here.x - a.x) * dx + (here.y - a.y) * dy) / length ^ 2)) or 0
		local off = math.sqrt((a.x + t * dx - here.x) ^ 2 + (a.y + t * dy - here.y) ^ 2)
		if here.map == a.map and off <= (reach or ON_PATH) and (not best or off < best) then
			best, found, along, after = off, index, t, total - walked - t * length
		end
		walked = walked + length
	end
	return found, along, after, total
end

ns.OnWalk = OnWalk -- Corpse.lua trims its walk the same way.
local function Refresh()
	local remaining
	if result then
		remaining = { now = result.now, arrive = result.arrive, legs = {} }
		for index = progress.index, #result.legs do
			remaining.legs[#remaining.legs + 1] = result.legs[index]
		end
		-- Draw the walk you are on from where you stand, not from where it was planned.
		local leg, here = remaining.legs[1], Here()
		if here then
			driver.drawAt, driver.drawX, driver.drawY, driver.drawMap = GetTime(), here.x, here.y, here.map
		end
		if leg and leg.mode == "walk" and here then
			local points = leg.walkPoints or ns.Planner.WalkPoints(leg.from, leg.to)
			-- A walk still being searched may be the one it replaces, which you have strayed from: join it where it is
			-- nearest.
			local found = OnWalk(points, here, not leg.measured and math.huge or nil)
			if found then
				local ahead = { here }
				for index = found, #points do
					ahead[#ahead + 1] = points[index]
				end
				remaining.legs[1] = setmetatable({ walkPoints = ahead }, { __index = leg })
			end
		end
	end
	if not CorpseRun() then
		ns.SetJourneyRoute(goal, remaining)
	end
	RefreshTracker()
end

-- Advance only the current leg. A refused Hearthstone stays out of this journey's later plans,
-- which still start at the player's actual position.
---@param index integer?
---@return boolean
function ns.SkipJourneyStep(index)
	if not goal or not result or CorpseRun() or InCombatLockdown() then
		return false
	end
	local current = progress.index
	if index ~= nil and index ~= current then
		return false
	end
	if not result.legs[current] then
		return false
	end
	if result.legs[current].teleport and result.legs[current].teleport.item == 6948 then
		withoutHearth = true
	end
	progress.index = current + 1
	progress.departed = false
	if progress.index > #result.legs then
		Arrive()
	else
		UpdateProgress()
	end
	Refresh()
	return true
end

local SamePlace = Search.SamePlace

-- Everything the search changes about what to follow arrives here, possibly while it is being started or stepped.
---@param route SPFPlan?
---@param news SPFSearchNews
local function Follow(route, news)
	if news == "searching" then
		return Refresh()
	end
	if news == "route" then
		result = route
		progress.index, progress.departed = 1, false
		Guide.Retarget()
		if not result then
			StopGuide()
		end
	elseif news == "walks" then
		Guide.Retarget()
	end
	UpdateProgress()
	if news == "times" then
		return RefreshTracker()
	end
	return Refresh()
end

-- The timed replan in Update plans in the frame, and from just before it Itinerary.lua keeps off that frame (a frame's
-- GetTime is fixed). A corpse run holds the replan, so a route queued behind it plans its hops meanwhile.
---@return boolean
function ns.JourneyReplanning()
	return not CorpseRun() and (driver.elapsed >= REPLAN_DUE or driver.replannedAt == GetTime())
end

---@param self SPFJourneyDriver
---@param elapsed number
-- One throttled frame step; keeping its gates together preserves the search/draw cadence
local function Update(self, elapsed)
	if CorpseRun() then
		return
	end
	if InCombatLockdown() then
		self.progressElapsed = self.progressElapsed + elapsed
		if self.progressElapsed >= 0.1 then
			self.progressElapsed = 0
			if goal and ns.StopInside(goal) then
				Guide.Pause()
			end
		end
		return
	end
	if not ns.db.journey then
		ns.ClearJourney()
		return
	end
	self.elapsed = self.elapsed + elapsed
	self.progressElapsed = self.progressElapsed + elapsed
	if self.progressElapsed < 0.1 then
		return
	end
	self.progressElapsed = 0
	local x, y, _, map = ns.JourneyPosition()
	if not x then
		return
	end
	local changed = policyChanged
	policyChanged = nil
	Search.Poll(changed)
	local index = progress.index
	UpdateProgress()
	if nextPoint then
		ns.StartJourney(nextPoint)
		return
	end
	if not goal then
		return
	end
	local riding, flying = ns.CurrentRide(), UnitOnTaxi("player")
	local changedRide = riding ~= self.riding or flying ~= self.flying
	self.riding, self.flying = riding, flying
	-- Edge-triggered like the ride: comparing against the last planned speed would retrigger every frame
	-- while a search is still settling and no plan has run.
	local speed = ns.PlanContext.RunSpeed()
	local changedSpeed = speed ~= (self.speed or Search.Speed())
	self.speed = speed
	if self.elapsed >= REPLAN_EVERY or changedRide or changedSpeed then
		self.elapsed, self.replannedAt = 0, GetTime()
		Search.Replan(riding, flying, changedRide)
	elseif index ~= progress.index then
		Refresh()
	end
	-- Trimming is presentation work, independent of the five-second planning/search cadence.
	if
		goal
		and result
		and GetTime() - (self.drawAt or 0) >= DRAW_EVERY
		and (x ~= self.drawX or y ~= self.drawY or map ~= self.drawMap)
	then
		Refresh()
	end
end

-- Whether the journey waiting out a corpse run was guided; one asked for while you are a ghost starts guided.
local waitingGuided = false
-- The run is starting: searches stop, and the journey keeps its goal, route and progress for later.
function ns.SuspendJourney()
	waitingGuided = goal ~= nil and Guide.Active()
	Search.Cancel()
end

-- You are alive again: the journey plans afresh from wherever that is, guided as it was.
function ns.ResumeJourney()
	if goal then
		ns.StartJourney(goal)
		-- The route you were on shows again at once, until the new plan replaces it.
		if result then
			Refresh()
		end
		if not waitingGuided then
			StopGuide()
		end
	else
		StopGuide()
		ns.SetJourneyRoute(nil)
	end
	RefreshTracker()
end

---@param point SPFPoint
---@return boolean
function ns.StartJourney(point)
	point = ns.InstanceEntrance(point)
	if CorpseRun() then
		-- Queued behind the corpse run, which ResumeJourney plans from where you come back to life.
		if not (goal and SamePlace(goal, point)) then
			result = nil
			withoutHearth = false
			Search.Clear(false)
			progress.index, progress.departed = 1, false
		end
		goal, nextPoint, waitingGuided = point, nil, true
		if ns.JourneyChanged then
			ns.JourneyChanged(point)
		end
		RefreshTracker()
		return true
	end
	local previous = Search.Clear(goal and SamePlace(goal, point)) and result
	withoutHearth = false
	if previous then
		for _, leg in ipairs(previous.legs) do
			if leg.to.kind == "goal" then
				leg.to.label = point.label
			end
		end
	end
	local index, departed = progress.index, progress.departed
	if Guide.Active() then
		StopGuide()
	end
	goal, nextPoint = point, nil
	if ns.JourneyChanged then
		ns.JourneyChanged(point)
	end
	result = previous or nil
	progress.index, progress.departed = previous and index or 1, previous and departed or false
	driver.elapsed, driver.progressElapsed = 0, 0
	if not InCombatLockdown() then
		driver:Show()
	end
	ns.WakeTravel()
	Search.Start(goal, result, progress, Follow)
	-- Every journey starts guided; the tracker header turns it off.
	if goal then
		StartGuide()
		RefreshTracker()
	end
	return true
end

ns.Init(function()
	local journeyDriver = CreateFrame("Frame", "ShortestPathForeverJourneyDriver", UIParent)
	---@cast journeyDriver SPFJourneyDriver
	driver = journeyDriver
	driver.elapsed, driver.progressElapsed = 0, 0
	driver:SetScript("OnUpdate", Update)
	driver:RegisterEvent("PLAYER_REGEN_DISABLED")
	driver:RegisterEvent("PLAYER_REGEN_ENABLED")
	driver:RegisterEvent("QUEST_TURNED_IN")
	driver:RegisterEvent("QUEST_REMOVED")
	driver:RegisterEvent("SUPER_TRACKING_CHANGED")
	driver:RegisterEvent("USER_WAYPOINT_UPDATED")
	driver:RegisterEvent("PLAYER_LOGIN")
	driver:RegisterEvent("PLAYER_ENTERING_WORLD")
	driver:SetScript("OnEvent", function(self, event, questID)
		if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
			Guide.ClearOrphan()
			EnteredInstance()
		elseif
			event == "PLAYER_REGEN_DISABLED"
			and not (goal and goal.hold and (goal.radius or goal.shapes or goal.questIDs))
		then
			self:Hide()
		elseif event == "PLAYER_REGEN_ENABLED" and goal then
			self:Show()
		end
		local questGone = event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED"
		if questGone then
			Guide.QuestGone(questID)
		end
		if questGone and goal and goal.questID == questID then
			ns.ClearJourney()
		elseif event == "SUPER_TRACKING_CHANGED" or event == "USER_WAYPOINT_UPDATED" then
			Guide.TrackingChanged(event)
		end
	end)
	driver:Hide()
end)
