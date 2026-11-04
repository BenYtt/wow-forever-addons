---@class SPFNamespace
local ns = select(2, ...)

-- What a plan starts from, read from the client and the shipped data in one place: your run speed, faction, known
-- flight points, fresh sightings, usable teleports and the ride you are on, plus the static tables every plan
-- crosses. The journey search, the estimate, the bind-point landings and the corpse run ask here; Planner.lua's wide
-- option table stays the planner's own interface, filled by Options.
---@class SPFPlanContext
local Context = {}
ns.PlanContext = Context

local lastSpeed = 7

-- Run speed stays meaningful while standing still. Secret combat values retain the last readable speed.
---@return number
function Context.RunSpeed()
	local _, speed = GetUnitSpeed("player")
	if canaccessvalue(speed) and type(speed) == "number" and speed > 0 and speed < math.huge then
		lastSpeed = speed
	end
	return lastSpeed
end

-- The inputs every plan from here shares, read now. The caller adds what is its own: cache (topology is never
-- shared between callers), waterWalking, and the journey's ride and measured walks. teleportReady is as the client
-- reports it for where you stand; a caller planning from elsewhere clears it.
---@class SPFContextOptions : SPFPlanOptions
---@field taxiKnown table<number, boolean>
---@field anchors table<number, SPFAnchor>
---@field teleports SPFTeleportPlace[]
---@field teleportReady table<number, number>

---@param from SPFPoint
---@param to SPFPoint
---@return SPFContextOptions
function Context.Options(from, to)
	local now = ns.NowMs()
	local teleports, ready = ns.UsableTeleports(now)
	return {
		from = from,
		to = to,
		now = now,
		walkSpeed = Context.RunSpeed(),
		faction = UnitFactionGroup("player"),
		otherFaction = ns.db and ns.db.otherFaction or false,
		taxiKnown = ns.KnownTaxiNodes(),
		anchors = ns.Timetable.Anchors(),
		docks = ns.Docks,
		routes = ns.Routes,
		taxiNodes = ns.TaxiNodes,
		taxiPaths = ns.TaxiPaths,
		taxiTimes = ns.TaxiTimes and ns.TaxiTimes.Snapshot(),
		portals = ns.Portals,
		teleports = teleports,
		teleportReady = ready,
		hearthMinimumSavings = ns.db and ns.db.hearthMinimumSavings or 0,
		landmasses = ns.Landmasses,
		baked = ns.Walks,
	}
end

-- The boat, zeppelin or tram you are aboard and where it next stops, for a plan from where you stand.
---@param options SPFContextOptions from Options, planned from where you stand
---@return {route: number, dock: number, arrive: number}?
function Context.Ride(options)
	local here, now = options.from, options.now
	local routeID = ns.CurrentRide()
	if not routeID then
		return nil
	end
	if ns.Timetable.Anchor(routeID) then
		for _, stop in ipairs(ns.Routes[routeID].stops) do
			-- The observer retains a ride for 30 seconds after disembarking, enough to run 210 yards away.
			local dock = ns.Docks[stop.dock]
			if
				ns.Timetable.Visit(routeID, stop, now)
				and here.map == dock.map
				and (here.x - dock.x) ^ 2 + (here.y - dock.y) ^ 2 <= 250 ^ 2
			then
				return nil
			end
		end
	end
	local dock, arriveIn = ns.Timetable.NextStop(routeID)
	return dock and { route = routeID, dock = dock, arrive = now + arriveIn } or nil
end

-- The fixed places your faction can use, with these teleport destinations (none for a bind point's own landing).
---@param teleports? SPFTeleportPlace[]
---@return SPFPlace[] places, string faction the faction they were chosen for
function Context.Places(teleports)
	local faction = UnitFactionGroup("player")
	return ns.Planner.Places({
		docks = ns.Docks,
		taxiNodes = ns.TaxiNodes,
		portals = ns.Portals,
		teleports = teleports,
		faction = faction,
	}),
		faction
end

---@param point SPFPoint
---@return number?
function Context.Landmass(point)
	return ns.Planner.Landmass(point, ns.Landmasses or {})
end

---@param leg SPFLeg
---@return SPFWalkPoints
function Context.LegPoints(leg)
	return ns.Planner.LegPoints(leg, ns.Routes)
end
