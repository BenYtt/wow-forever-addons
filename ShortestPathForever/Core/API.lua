---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- This topology belongs exclusively to estimates: Planner.Plan mutates its cache between calls.
-- Never borrow the active journey's cache, path jobs, progress, waypoint or route drawing.
local plannerCache, knownSnapshot = {}, {}
-- legs are the planner's own, read only to build EstimateDetail's copies; they never leave this file.
---@type table<string, {at: number, seconds: number|false, legs?: SPFLeg[]}>
local estimates, order, slot = {}, {}, 1
local anchorSnapshot, context = {}, {}
local CACHE_LIMIT, CACHE_MS = 256, 5000
-- Teleports are cast from where you stand, now: only an estimate that starts within this many yards of you counts
-- them. Anywhere else is a later leg of the caller's route, when their cooldowns are unknown.
local HERE = 15
local CONTEXT_KEYS = {
	"walkSpeed",
	"faction",
	"otherFaction",
	"waterWalking",
	"docks",
	"routes",
	"taxiNodes",
	"taxiPaths",
	"portals",
	"teleports",
	"landmasses",
	"baked",
	"hearthMinimumSavings",
}

local function Number(value)
	return canaccessvalue(value) and type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function Point(map, x, y)
	if
		not Number(map)
		or map <= 0
		or map % 1 ~= 0
		or not Number(x)
		or not Number(y)
		or x < 0
		or x > 1
		or y < 0
		or y > 1
	then
		return nil
	end
	return ns.WorldPoint(map, x, y)
end

local function QuestID(questID)
	return Number(questID) and questID % 1 == 0 and questID >= 1
end

-- An objective area list: one or more places on a map, each with a yard radius. Every entry must be one this
-- client can place.
---@param shapes table
---@return boolean
local function Shapes(shapes)
	local count = #shapes
	if count < 1 then
		return false
	end
	for key, shape in pairs(shapes) do
		if not Number(key) or key % 1 ~= 0 or key < 1 or key > count then
			return false
		end
		if
			type(shape) ~= "table"
			or not Point(shape.map, shape.x, shape.y)
			or not Number(shape.radius)
			or shape.radius < 0
		then
			return false
		end
	end
	return true
end

-- The quests a held area stands for: one or more quest IDs, in order.
---@param quests table
---@return boolean
local function Quests(quests)
	local count = #quests
	if count < 1 then
		return false
	end
	for key, questID in pairs(quests) do
		if not Number(key) or key % 1 ~= 0 or key < 1 or key > count or not QuestID(questID) then
			return false
		end
	end
	return true
end

local function Ready()
	return ns.db and ns.charDB and not InCombatLockdown()
end

local function Owner(owner)
	return canaccessvalue(owner) and type(owner) == "string" and owner:find("%S") ~= nil
end

-- Only this module owns the caller's itinerary. Journey handles one destination at a time.
---@type {owner: string, points: SPFPoint[], index: integer}?
local route
local MAX_STOPS = 64
-- Why each owner's last journey ended, and when (GetTime); an owner's new journey forgets it.
---@type table<string, {reason: SPFAPIEnded, at: number}>
local ended = {}

-- Subscribe's callbacks: told once per burst what happened to guidance, after every change in it has landed.
---@class SPFSubscription
---@field callback fun(changes: SPFAPIChanges)
---@field active boolean
---@field after? SPFAPIChanges -- the burst under way when it subscribed, which it is not told about

---@type SPFSubscription[]
local subscriptions = {}
---@type SPFAPIChanges?
local pending
-- What subscribers were last told about, kept whether or not anyone listens: the destination (to tell a start from
-- a change), the owner and stop CurrentStop answers for, and Active().
---@type SPFPoint?
local guided
---@type string?
local stopOwner
---@type integer?
local stopIndex
local active = false
-- Active() as subscribers were last told it.
local heardActive = false

-- Each subscriber gets its own copy, from a copy of the list, so a callback may unsubscribe or change what it was
-- given; an error goes to the game's error handler, and to /path report, without stopping the others.
local function Flush()
	local changes = pending
	pending = nil
	if not changes then
		return
	end
	-- The guide can stop and start again within a burst (a replaced journey): only a different answer counts.
	if changes.active then
		local now = ns.IsJourneyGuided() == true
		changes.active = now ~= heardActive or nil
		heardActive = now
		if not next(changes) then
			return
		end
	end
	local current = {}
	for index, subscription in ipairs(subscriptions) do
		current[index] = subscription
	end
	for _, subscription in ipairs(current) do
		if subscription.active and subscription.after ~= changes then
			local copy = {}
			for key, value in pairs(changes) do
				copy[key] = value
			end
			ns.SafeCall("Subscribe callback", subscription.callback, copy)
		end
	end
end

---@param kind "started"|"changed"|"ended"|"stop"|"active"
local function Notify(kind)
	if not subscriptions[1] then
		return
	end
	if not pending then
		-- Scheduled first: a failure leaves nothing half-queued to swallow later bursts.
		C_Timer.After(0, Flush)
		pending = {}
	end
	pending[kind] = true
end

---@param a SPFPoint?
---@param b SPFPoint?
local function SamePlace(a, b)
	return a == b or (a and b and a.map == b.map and a.x == b.x and a.y == b.y) or false
end

-- The stop and guide state as callers read them, compared with what subscribers last heard.
local function Settle()
	local owner, index = route and route.owner, route and route.index
	if owner ~= stopOwner or index ~= stopIndex then
		stopOwner, stopIndex = owner, index
		Notify("stop")
	end
	local now = ns.IsJourneyGuided() == true
	if now ~= active then
		active = now
		Notify("active")
	end
end

-- JourneyGuide.lua: the guide started or stopped, which Active() reports.
function ns.GuideChanged()
	Settle()
end

---@param point SPFPoint?
---@param reason? "arrived"|"cleared" -- why a nil point ended the journey
function ns.JourneyChanged(point, reason)
	if ns.ProgressJourneyChanged then
		ns.ProgressJourneyChanged(point, reason)
	end
	if not SamePlace(point, guided) then
		Notify(not point and "ended" or guided and "changed" or "started")
	end
	guided = point
	if not route then
		Settle()
		return
	end
	if point and point == route.points[route.index + 1] then
		route.index = route.index + 1
	elseif not point or point ~= route.points[route.index] then
		ended[route.owner] = { reason = point and "replaced" or reason or "cleared", at = GetTime() }
		route = nil
	else
		Settle()
		return
	end
	Settle()
	ns.ItineraryChanged()
end

-- A running route's stop was relabelled in place (API.RenameStop, from a guide renaming its step): the tracker names
-- it. The label is cosmetic, so a tracker that cannot draw is not this journey's problem.
local function Relabel()
	ns.RefreshTracker()
end

function ns.JourneyRelabeled()
	if ns.RefreshTracker then
		ns.SafeCall("journey relabel", Relabel)
	end
end

-- Which addon owns the journey under way, if one does (Resume.lua keeps only the player's own).
---@return string?
function ns.JourneyOwner()
	return route and route.owner
end

---@param point SPFPoint
---@return SPFPoint?
function ns.NextJourneyStop(point)
	-- A door stands in for the stop inside its instance (JourneyInput.lua).
	point = point.stop or point
	return route and route.points[route.index] == point and route.points[route.index + 1] or nil
end

-- Internal read-only map view; the public API never exposes these private world points.
---@return SPFPoint[]? points, integer? index
function ns.JourneyStops()
	if route and #route.points > 1 then
		return route.points, route.index
	end
end

---@class SPFPublicAPI
local API = { version = 1, minor = 1 }

local function Differs(a, b)
	for key, value in pairs(a) do
		if b[key] ~= value then
			return true
		end
	end
	for key, value in pairs(b) do
		if a[key] ~= value then
			return true
		end
	end
	return false
end

-- The planner options from here and now; a changed context drops every cached estimate.
---@param from SPFPoint
---@param to SPFPoint
local function Options(from, to)
	local options = ns.PlanContext.Options(from, to)
	local known, now, anchors = options.taxiKnown, options.now, options.anchors
	-- Discovery updates the same saved table in place; topology identity alone cannot detect it.
	local changed = Differs(known, knownSnapshot)
	if changed then
		plannerCache, knownSnapshot = {}, {}
		for id, value in pairs(known) do
			knownSnapshot[id] = value
		end
	end
	local x, y, _, map = ns.JourneyPosition()
	if not (x and map == from.map and (x - from.x) ^ 2 + (y - from.y) ^ 2 <= HERE ^ 2) then
		options.teleportReady = {}
	end
	for id, anchor in pairs(anchors) do
		if anchorSnapshot[id] ~= anchor.epoch then
			changed = true
		end
	end
	for id in pairs(anchorSnapshot) do
		if not anchors[id] then
			changed = true
		end
	end
	-- Same multimodal planner and baked walks as the arrow's initial plan. Endpoint terrain searches
	-- are asynchronous and deliberately omitted: this is an estimate, not a settled walking path.
	options.cache, options.waterWalking = plannerCache, ns.JourneyWaterWalking()
	for _, name in ipairs(CONTEXT_KEYS) do
		if context[name] ~= options[name] then
			changed = true
		end
	end
	if changed then
		estimates, order, slot, anchorSnapshot = {}, {}, 1, {}
		for id, anchor in pairs(anchors) do
			anchorSnapshot[id] = anchor.epoch
		end
		context = options
	end
	return options, now
end

-- Behind API.Estimate and EstimateDetail. Uncached, LuaJIT -joff: Auberdine -> Eastern Plaguelands 2.45 ms cold /
-- 0.51 ms warm; JIT compilation can make the first call ~4 ms. Callers should make at most one uncached call per
-- frame; AGF fetches its card estimates one per frame while its panel is open. Results are cached, 256 (origin
-- rounded to 0.0001, exact destination) for at most five seconds; cached calls measured ~0.003 ms.
---@param from SPFPoint
---@param to SPFPoint
---@param key string
local function Answer(from, to, key)
	local options, now = Options(from, to)
	local cached = estimates[key]
	if cached and now >= cached.at and now - cached.at < CACHE_MS then
		if cached.seconds then
			return cached
		end
		return nil, "unreachable"
	end
	local plan = ns.Planner.Plan(options)
	local seconds = plan and math.max(0, (plan.arrive - now) / 1000) or nil
	if not cached then
		if order[slot] then
			estimates[order[slot]] = nil
		end
		order[slot] = key
		slot = slot % CACHE_LIMIT + 1
	end
	local entry = { at = now, seconds = seconds or false, legs = plan and plan.legs }
	estimates[key] = entry
	if seconds then
		return entry
	end
	return nil, "unreachable"
end

-- The reason tells a caller whether asking again later can help: "combat" after combat, "invalid" never for bad
-- input (only if the addon had not loaded yet), "unreachable" when known flight paths or boat timings change.
local function Lookup(fromMap, fromX, fromY, toMap, toX, toY)
	if not Ready() then
		return nil, InCombatLockdown() and "combat" or "invalid"
	end
	local from, to = Point(fromMap, fromX, fromY), Point(toMap, toX, toY)
	if not from or not to then
		return nil, "invalid"
	end
	return Answer(from, to, string.format("%d:%.4f:%.4f:%d:%.17g:%.17g", fromMap, fromX, fromY, toMap, toX, toY))
end

-- Itinerary.lua draws the hops between later stops with this cheap planner; no terrain searches. It keeps each
-- hop's legs itself, so they stay out of the estimate cache the public API answers from.
---@param from SPFPoint
---@param to SPFPoint
---@return SPFLeg[]?
function ns.EstimateLegs(from, to)
	local plan = ns.Planner.Plan((Options(from, to)))
	return plan and plan.legs
end

function API.Estimate(fromMap, fromX, fromY, toMap, toX, toY)
	local entry, reason = Lookup(fromMap, fromX, fromY, toMap, toX, toY)
	if not entry then
		return nil, reason
	end
	return entry.seconds --[[@as number]] -- Lookup returns only answered entries.
end

-- Built on demand so plain estimates stay as cheap as before. Every table is new: a caller that edits or keeps
-- the result can never reach the planner's nodes or a later caller's copy.
function API.EstimateDetail(fromMap, fromX, fromY, toMap, toX, toY)
	local entry, reason = Lookup(fromMap, fromX, fromY, toMap, toX, toY)
	if not entry then
		return nil, reason
	end
	local legs, previous = {}, entry.at
	for index, leg in ipairs(entry.legs) do
		-- Planner legs carry arrival times; each span runs from the previous arrival, so it includes the wait.
		legs[index] = {
			mode = leg.mode,
			to = ns.LegLabel(leg),
			seconds = (leg.arrive - previous) / 1000,
			wait = leg.wait and leg.wait >= 60000 and leg.wait / 1000 or nil,
			newFlightPath = leg.mode == "walk" and leg.to.undiscovered or nil,
		}
		previous = leg.arrive
	end
	return {
		seconds = entry.seconds --[[@as number]],
		legs = legs,
	}
end

function API.NavigateRoute(owner, stops)
	if not Owner(owner) or not Ready() or not ns.db.journey or type(stops) ~= "table" then
		return false
	end
	local count = #stops
	if count < 1 or count > MAX_STOPS or not ns.JourneyPosition() then
		return false
	end
	for key in pairs(stops) do
		if not Number(key) or key % 1 ~= 0 or key < 1 or key > count then
			return false
		end
	end
	local points = {}
	for index = 1, count do
		local stop = stops[index]
		if
			type(stop) ~= "table"
			or (stop.title ~= nil and not (canaccessvalue(stop.title) and type(stop.title) == "string"))
			or (stop.tooltip ~= nil and not (canaccessvalue(stop.tooltip) and type(stop.tooltip) == "string"))
			or (stop.hold ~= nil and not (canaccessvalue(stop.hold) and type(stop.hold) == "boolean"))
			or (stop.radius ~= nil and (not Number(stop.radius) or stop.radius < 0))
			or (stop.questID ~= nil and not QuestID(stop.questID))
			or (stop.questIDs ~= nil and (type(stop.questIDs) ~= "table" or not Quests(stop.questIDs)))
			or (stop.shapes ~= nil and (type(stop.shapes) ~= "table" or not Shapes(stop.shapes)))
		then
			return false
		end
		local point = Point(stop.map, stop.x, stop.y)
		if not point then
			return false
		end
		point.label = stop.title
		point.tooltip = stop.tooltip
		-- A caller such as Adventure Guide may need the route to remain visible while the
		-- player completes an interaction at this location. It resubmits the route after
		-- that state changes; ordinary API stops retain automatic arrival.
		point.hold = stop.hold == true
		point.radius = stop.radius
		point.questID = stop.questID
		-- The quests whose client blobs the stop stands for, copied; StopInside prefers the client's own answer for them.
		if stop.questID or stop.questIDs then
			point.questIDs = { stop.questID }
			for _, questID in ipairs(stop.questIDs or {}) do
				if questID ~= stop.questID then
					point.questIDs[#point.questIDs + 1] = questID
				end
			end
		end
		-- The areas are copied to world points too: the caller cannot redirect a journey they no longer own.
		if stop.shapes then
			point.shapes = {}
			for _, shape in ipairs(stop.shapes) do
				local at = Point(shape.map, shape.x, shape.y) --[[@as SPFAreaShape]]
				at.radius = shape.radius
				point.shapes[#point.shapes + 1] = at
			end
		end
		-- An unknown kind is dropped, not refused: a caller written for a later vocabulary still gets its route.
		point.look = ns.StopKind(stop.kind)
		if count > 1 then
			local location = not point.label and ns.Locate(point)
			point.routeTitle = string.format(
				L["Stop %d of %d: %s"],
				index,
				count,
				point.label or location and location.zone or UNKNOWN
			)
		end
		points[index] = point
	end
	-- Validate and copy every stop before replacing guidance. Caller mutations cannot redirect a journey.
	if route and route.owner ~= owner then
		ended[route.owner] = { reason = "replaced", at = GetTime() }
	end
	ended[owner] = nil
	route = { owner = owner, points = points, index = 1 }
	ns.ItineraryChanged()
	return ns.StartJourney(points[1])
end

function API.Navigate(owner, map, x, y, title, kind)
	return API.NavigateRoute(owner, { { map = map, x = x, y = y, title = title, kind = kind } })
end

function API.CurrentStop(owner)
	return Owner(owner) and route and route.owner == owner and route.index or nil
end

function API.Cancel(owner)
	if not API.CurrentStop(owner) then
		return false
	end
	ns.ClearJourney()
	ended[owner] = { reason = "cancelled", at = GetTime() }
	return true
end

-- Relabel a running route's stop in place: a guide renames a step whose position did not move, which must not cost a
-- replan. renamePoints says which later stops are that same place, so they keep the name too. The titles only a
-- multi-stop route draws stay as they were.
---@param owner string
---@param index integer the stop to rename, usually API.CurrentStop
---@param title string
---@param renamePoints? fun(point: SPFPoint): boolean?
---@return boolean
function API.RenameStop(owner, index, title, renamePoints)
	if not Owner(owner) or not route or route.owner ~= owner or type(title) ~= "string" then
		return false
	end
	if (title ~= "" and not canaccessvalue(title)) or not route.points[index] then
		return false
	end
	-- Our own points, written before the guard above saw them: nothing to re-read here.
	local current, shares = route.points[index], nil
	if renamePoints then
		shares = {}
		for _, point in ipairs(route.points) do
			shares[point] = not not renamePoints(point)
		end
	end
	for _, point in ipairs(route.points) do
		if point == current or (shares and shares[point]) then
			point.label = title
		end
	end
	ns.JourneyRelabeled()
	return true
end

function API.Ended(owner)
	local entry = Owner(owner) and ended[owner]
	if entry then
		return entry.reason, entry.at
	end
end

function API.Subscribe(callback)
	if type(callback) ~= "function" then
		error("ShortestPathForever.API.Subscribe: callback must be a function", 2)
	end
	---@type SPFSubscription
	local subscription = { callback = callback, active = true, after = pending }
	subscriptions[#subscriptions + 1] = subscription
	return function()
		subscription.active = false
		for index, other in ipairs(subscriptions) do
			if other == subscription then
				table.remove(subscriptions, index)
				return
			end
		end
	end
end

-- Anyone's journey counts, the player's own included, so a caller can ask before replacing it.
function API.Active()
	return ns.IsJourneyGuided() == true
end

ShortestPathForever = ShortestPathForever or {}
ShortestPathForever.API = API
