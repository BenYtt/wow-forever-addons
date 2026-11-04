---@class SPFNamespace
local ns = select(2, ...)

-- Shortest Path's own lines in /path report (UI/Report.lua; the pattern is cjber/adventure-guide-forever
-- docs/report-window.md): the travel settings, the bind point, the ride and, with /path debug on, the last samples
-- of its trace, then the corpse run and the journey with its goal and every step of its plan. The steps come last, so
-- a long plan is what the report's cap cuts. Read from the journey as it stands, paused or behind a corpse run:
-- nothing is planned or searched for the report. Field labels are English; place names are the client's.

local TRACE_SHOWN = 5
local SETTINGS = "Settings: journeys %s, teleports %s (hearth saving %ss), other faction %s, TomTom %s/follow %s, "
	.. "RestedXP %s"

---@param value any
---@return string
local function OnOff(value)
	return value == true and "on" or "off"
end

---@param ms number
---@return integer
local function Seconds(ms)
	return math.floor(ms / 1000 + 0.5)
end

-- A world point as the map shows it: "map 1429 42.1, 65.3", or its world yards when no zone holds it.
---@param point SPFPoint
---@return string
local function Place(point)
	local location = ns.Locate(point)
	if location then
		return ("map %d %s, %s"):format(location.uiMap, ns.Report.Percent(location.x), ns.Report.Percent(location.y))
	end
	return ("continent %s %.0f, %.0f"):format(tostring(point.map), point.x, point.y)
end

-- Each step as the tracker times it (its own span, the wait apart), the one under way marked, and why a walk failed.
---@param lines string[]
---@param legs SPFLeg[]
---@param index integer
local function Steps(lines, legs, index)
	for position, leg in ipairs(legs) do
		lines[#lines + 1] = ("%s%d. %s to %s, %ds%s%s"):format(
			position == index and "> " or "  ",
			position,
			leg.mode,
			ns.LegLabel(leg),
			Seconds(leg.arrive - leg.depart),
			leg.wait and leg.wait > 0 and (", waits %ds"):format(Seconds(leg.wait)) or "",
			leg.walkError and (", walk failed: %s"):format(leg.walkError) or ""
		)
	end
end

---@param lines string[]
local function Trace(lines)
	-- The raw samples are kept only while /path debug is on: server time, continent, x, y, z, speed, fits.
	local trace = ns.db.debug and ns.db.trace
	if not (trace and trace[1]) then
		lines[#lines + 1] = "Ride trace: off (/path debug keeps one)"
		return
	end
	-- The last samples taken aboard, which carry the ride's fits: a report taken after getting off still has them.
	local last = #trace
	for position = #trace, 1, -1 do
		if trace[position][7] and trace[position][7] ~= "" then
			last = position
			break
		end
	end
	local first = math.max(1, last - TRACE_SHOWN + 1)
	lines[#lines + 1] = ("Ride trace (%d to %d of %d):"):format(first, last, #trace)
	for position = first, last do
		local sample = trace[position]
		lines[#lines + 1] = ("  %s %s %.1f, %.1f, %.1f at %s %s"):format(
			tostring(sample[1]),
			tostring(sample[2]),
			tonumber(sample[3]) or 0,
			tonumber(sample[4]) or 0,
			tonumber(sample[5]) or 0,
			tostring(sample[6]),
			tostring(sample[7] or "")
		)
	end
end

-- The report's Shortest Path lines.
---@return string[]
function ns.ReportLines()
	local db = ns.db
	local lines = {
		SETTINGS:format(
			OnOff(db.journey),
			OnOff(db.teleports),
			tostring(db.hearthMinimumSavings or 0),
			OnOff(db.otherFaction),
			OnOff(db.tomtom),
			OnOff(db.tomtomFollow),
			OnOff(db.restedxp)
		),
	}
	local bind = ns.charDB.bind
	lines[#lines + 1] = ("Bind point: %s"):format(bind and (bind.name .. ", " .. Place(bind)) or "not known")
	local ride = ns.CurrentRide()
	lines[#lines + 1] = ("Ride: %s%s"):format(
		ride and ("route " .. ride) or (ns.IsObservingRide() and "being matched" or "none"),
		UnitOnTaxi("player") and ", on a flight" or ""
	)
	Trace(lines)
	local goal = ns.JourneyGoal()
	-- A corpse run guides you back first; a journey planned before it waits behind it.
	local corpse = ns.Corpse and select(3, ns.Corpse.Info())
	if corpse then
		lines[#lines + 1] = "Corpse run:" .. (goal and " the journey waits behind it" or "")
		Steps(lines, corpse.legs, 1)
	end
	if not goal then
		lines[#lines + 1] = "Journey: none"
		return lines
	end
	local owner = ns.JourneyOwner()
	local stops, stop = ns.JourneyStops()
	lines[#lines + 1] = ("Journey: %s, owner %s%s, guided %s"):format(
		ns.PlaceLabel(goal),
		owner or "player",
		stops and (", stop %d of %d"):format(stop, #stops) or "",
		OnOff(ns.IsJourneyGuided())
	)
	lines[#lines + 1] = "Goal: " .. Place(goal)
	local pending, rounds, costError = ns.JourneyStatus()
	lines[#lines + 1] = ("Search: %s, %d settle rounds%s"):format(
		pending and "under way" or "settled",
		rounds or 0,
		costError and (", walk failed: %s"):format(costError) or ""
	)
	local plan, index = ns.JourneyPlan()
	if plan then
		Steps(lines, plan.legs, index)
	else
		lines[#lines + 1] = "Plan: none yet"
	end
	return lines
end
