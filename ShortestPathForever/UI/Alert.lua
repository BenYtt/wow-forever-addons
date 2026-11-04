---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- A heads-up for anyone waiting away from the keyboard: the stock raid-warning banner, the transport's own
-- in-world sound on the Master channel (heard with the game in the background) and a flashing taskbar icon,
-- once per boat. The sound is the one the game makes for that transport, never a raid alert (WFA-26).
-- Waiting at a dock: this long before a timed boat arrives (it then stays docked about a minute).
local AT_DOCK = 30000
-- Riding: this long before the boat reaches its next dock.
local ON_BOARD = 20000
local RADIUS = 120
-- Lifts come round every few seconds, so they never alert.
local ARRIVES = {
	boat = L["Boat to %s arrives in %s"],
	zeppelin = L["Zeppelin to %s arrives in %s"],
	tram = L["Tram to %s arrives in %s"],
}
-- What the game itself plays for each, as FileDataIDs in the Forever build (sound/doodad/): the bell a ship
-- rings as it docks (boatdockedwarning.ogg), the zeppelin's horn (zeppelinhorn.ogg), the tram pulling in
-- (subwaystop.ogg).
local SOUND = { boat = 566652, zeppelin = 566719, tram = 566056 }

-- [route .. ":" .. dock] = GetTime() of the alert, so each visit alerts once.
local alerted = {}

local function Alert(key, kind, text)
	if GetTime() - (alerted[key] or -math.huge) < 120 then
		return
	end
	alerted[key] = GetTime()
	RaidWarningUtil.AddMessage(text, ChatTypeInfo.RAID_WARNING)
	if ns.db.alertSound and SOUND[kind] then
		PlaySoundFile(SOUND[kind], "Master")
	end
	FlashClientIcon()
end

local function AnnounceNewFlightPath(leg, index, approach)
	if not ns.db.flightPathReminder or not ns.db.alerts or InCombatLockdown() then
		return
	end
	local key = "new-flight-master:" .. tostring(leg.to.id)
	local text = approach
			and string.format(L["You are near the new flight master %s. Discover it before flying."], ns.LegLabel(leg))
		or string.format(L["Step %d: discover flight master %s before flying."], index, ns.LegLabel(leg))
	Alert(key .. (approach and ":approach" or ":plan"), "flightmaster", text)
end

local function CheckNewFlightPaths()
	if not ns.db.flightPathReminder or not ns.db.alerts or InCombatLockdown() then
		return
	end
	local plan, current = ns.JourneyPlan()
	if not plan then
		return
	end
	for index = current, #plan.legs do
		local leg = plan.legs[index]
		if leg.mode == "walk" and leg.to.undiscovered then
			AnnounceNewFlightPath(leg, index, false)
			if index == current then
				local x, y, map = ns.JourneyPosition()
				local node = leg.to
				if x and map == node.map and (x - node.x) ^ 2 + (y - node.y) ^ 2 <= 120 ^ 2 then
					AnnounceNewFlightPath(leg, index, true)
				end
			end
			return
		end
	end
end

local function Due(ms, lead)
	return ms <= lead and ms > lead - 5000
end

local function Check(dockID, yards)
	if not ns.db.alerts or InCombatLockdown() then
		return
	end
	local riding = ns.CurrentRide()
	if riding then
		local kind = ns.Routes[riding].kind
		local nextDock, arriveIn = ns.Timetable.NextStop(riding)
		if ARRIVES[kind] and nextDock and arriveIn and Due(arriveIn, ON_BOARD) then
			Alert(
				riding .. ":" .. nextDock,
				kind,
				string.format(L["Arriving at %s in %s"], ns.DockLabel(nextDock), ns.FormatCountdown(arriveIn))
			)
		end
		return
	end
	if not dockID or yards > RADIUS then
		return
	end
	for _, departure in ipairs(ns.Timetable.Departures(dockID)) do
		local arrives = ARRIVES[departure.kind]
		if arrives and departure.known and not departure.docked and Due(departure.arriveIn, AT_DOCK) then
			local text =
				string.format(arrives, ns.Timetable.Destination(departure), ns.FormatCountdown(departure.arriveIn))
			Alert(departure.route .. ":" .. dockID, departure.kind, text)
		end
	end
end

-- Arriving: the map's own ping (sound/interface/mapping.ogg) when a journey you planned yourself reaches its goal.
-- Not when it is cleared or replaced. A guide's journeys (Adventure Guide, RestedXP, a guide's TomTom waypoints) are
-- left quiet: they hold at each stop and move on, and the guide gives its own cues.
local ARRIVAL_SOUND = 567416
-- Nearby services starts its journeys through the API under this addon's own name: those are the player's too.
local OWN = "Shortest Path Forever"
-- Who owned the journey under way, read when it started: API.lua has forgotten the owner by the time it ends.
local owner

---@param point SPFPoint?
---@param reason? "arrived"|"cleared"
local function Arrived(point, reason)
	if point then
		owner = ns.JourneyOwner()
		return
	end
	local ended = owner
	owner = nil
	if reason == "arrived" and ns.db.arrivalSound and (ended == nil or ended == OWN) then
		PlaySoundFile(ARRIVAL_SOUND, "Master")
	end
end

ns.Init(function()
	ns.OnTravelTick(Check)
	ns.OnTravelTick(CheckNewFlightPaths)
	-- After every file has loaded, so API.lua's ns.JourneyChanged exists to hook.
	hooksecurefunc(ns, "JourneyChanged", Arrived) -- taint-ok: ns is this addon's own namespace table.
end)
