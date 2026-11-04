---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- Per-character travel journal. Distance is an estimate from same-map position samples while walking; map changes,
-- secret positions, taxi flights, recognized rides and implausible jumps reset the baseline.
local DISTANCE_MILESTONES, COUNT_MILESTONES = { 1000, 10000, 100000 }, { 1, 10, 50 }
local MAX_SAMPLE_GAP, MAX_SPEED = 2.5, 60
local METRICS = {
	{ id = "distance_yards", field = "walkedYards" },
	{ id = "routes_completed", field = "routesCompleted" },
	{ id = "transports_used", field = "transportsUsed" },
	{ id = "flights_taken", field = "flightsTaken" },
	{ id = "portals_used", field = "portalsUsed" },
}
local localStats, lastPosition, lastSample, lastRide, wasFlying, lastPortalLeg
local nextSend, pendingSend = 0, false
local peer

local function Ensure()
	if not ns.charDB then
		return nil
	end
	local stats = ns.charDB.progress
	if type(stats) ~= "table" then
		stats = {
			walkedYards = 0,
			routesCompleted = 0,
			transportsUsed = 0,
			flightsTaken = 0,
			portalsUsed = 0,
			milestones = {},
			peers = {},
		}
		ns.charDB.progress = stats
	end
	for _, key in ipairs({ "walkedYards", "routesCompleted", "transportsUsed", "flightsTaken", "portalsUsed" }) do
		if type(stats[key]) ~= "number" or stats[key] < 0 or stats[key] ~= stats[key] then
			stats[key] = 0
		end
	end
	if type(stats.milestones) ~= "table" then
		stats.milestones = {}
	end
	if type(stats.peers) ~= "table" then
		stats.peers = {}
	end
	for addon in pairs(stats.peers) do
		if addon ~= "spf" or type(stats.peers[addon]) ~= "table" then
			stats.peers[addon] = nil
		end
	end
	localStats = stats
	return stats
end

local function Milestone(key, value, thresholds)
	for _, threshold in ipairs(thresholds) do
		local marker = key .. ":" .. threshold
		if value >= threshold and not localStats.milestones[marker] then
			localStats.milestones[marker] = GetServerTime()
			ns.Print(string.format(L["Travel milestone reached: %s"], marker))
		end
	end
end

---@return SPFProgressData?
local function Snapshot()
	local stats = Ensure()
	if not stats then
		return nil
	end
	return {
		walkedYards = math.floor(stats.walkedYards),
		routesCompleted = math.floor(stats.routesCompleted),
		transportsUsed = math.floor(stats.transportsUsed),
		flightsTaken = math.floor(stats.flightsTaken),
		portalsUsed = math.floor(stats.portalsUsed),
		milestones = stats.milestones,
		peers = {},
	}
end
ns.TravelStats = function()
	local snapshot = Snapshot()
	if snapshot and ns.db.stats and ns.db.statsShare then
		snapshot.peers.spf = peer:Shared()
	end
	return snapshot
end

---@param metric? string
---@return SPFProgressRank[]
function ns.TravelLeaderboard(metric)
	metric = metric or "routesCompleted"
	local allowed = {
		walkedYards = true,
		routesCompleted = true,
		transportsUsed = true,
		flightsTaken = true,
		portalsUsed = true,
	}
	if not allowed[metric] then
		metric = "routesCompleted"
	end
	local stats = Ensure()
	if not stats then
		return {}
	end
	local metricIDs = {
		walkedYards = "distance_yards",
		routesCompleted = "routes_completed",
		transportsUsed = "transports_used",
		flightsTaken = "flights_taken",
		portalsUsed = "portals_used",
	}
	local metricID = metricIDs[metric]
	local ranks = { { name = L["You (local)"], localRecord = true, value = stats[metric] } }
	local peers = ns.db.stats and ns.db.statsShare and peer:Shared() or {}
	for name, report in pairs(peers) do
		local record = report[metricID] and report[metricID].all
		if record then
			ranks[#ranks + 1] =
				{ name = string.format(L["%s (reported)"], name), localRecord = false, value = record.value }
		end
	end
	table.sort(ranks, function(a, b)
		if a.value == b.value then
			return a.name < b.name
		end
		return a.value > b.value
	end)
	return ranks
end

---@param metric string
function ns.PrintTravelLeaderboard(metric)
	local labels = {
		routesCompleted = L["Completed journeys"],
		walkedYards = L["Approximate walking distance"],
		transportsUsed = L["Transport rides"],
		flightsTaken = L["Flights taken"],
		portalsUsed = L["Portal legs"],
	}
	ns.Print(labels[metric] or labels.routesCompleted)
	ns.Print(L["Travel records from guild and group addon users. Peer totals are player-reported."])
	for index, rank in ipairs(ns.TravelLeaderboard(metric)) do
		if index <= 5 or rank.localRecord then
			local value = metric == "walkedYards" and string.format("~%s", ns.FormatDistance(rank.value))
				or tostring(rank.value)
			ns.Print(string.format(L["%d. %s - %s"], index, rank.name, value))
		end
	end
end

local function Record(key, amount)
	if not ns.db.stats then
		return
	end
	local stats = Ensure()
	if not stats then
		return
	end
	stats[key] = stats[key] + amount
	if key == "walkedYards" then
		Milestone("distance", stats[key], DISTANCE_MILESTONES)
	else
		local label = ({
			routesCompleted = "routes",
			transportsUsed = "transports",
			flightsTaken = "flights",
			portalsUsed = "portals",
		})[key]
		if label then
			Milestone(label, stats[key], COUNT_MILESTONES)
		end
	end
	if ns.db.statsShare and not pendingSend then
		pendingSend = true
		C_Timer.After(math.max(5, nextSend - GetTime()), function()
			pendingSend = false
			nextSend = GetTime() + 30
			ns.SendTravelStats()
		end)
	end
end

local function Position()
	local x, y, _, map = ns.JourneyPosition()
	if not x then
		return nil
	end
	return x, y, map
end

local function Sample()
	if not ns.db.stats then
		lastPosition, lastSample = nil, nil
		return
	end
	local now, x, y, map = GetTime(), Position()
	local flying, ride = UnitOnTaxi("player"), ns.CurrentRide and ns.CurrentRide()
	if flying and not wasFlying then
		Record("flightsTaken", 1)
	elseif ride and ride ~= lastRide then
		Record("transportsUsed", 1)
	end
	wasFlying, lastRide = flying, ride
	if not x or not IsPlayerMoving() or flying or ride then
		lastPosition, lastSample = nil, nil
		return
	end
	if lastPosition and lastSample then
		local elapsed = now - lastSample
		local dx, dy = x - lastPosition.x, y - lastPosition.y
		local distance = math.sqrt(dx * dx + dy * dy)
		if
			map == lastPosition.map
			and elapsed > 0
			and elapsed <= MAX_SAMPLE_GAP
			and distance <= MAX_SPEED * elapsed
		then
			Record("walkedYards", distance)
		end
	end
	lastPosition, lastSample = { x = x, y = y, map = map }, now
end

-- Core owns validation, identity normalization, bounded persistence and the shared send queue.
local metricConfig = {}
for _, metric in ipairs(METRICS) do
	metricConfig[metric.id] = { subject = "all" }
end
peer = ns.PeerStats.New({
	addon = "spf",
	enabled = function()
		return ns.db ~= nil and ns.db.stats == true and ns.db.statsShare == true
	end,
	db = function()
		local stats = Ensure()
		if not stats then
			return nil
		end
		stats.peers.spf = stats.peers.spf or {}
		return stats.peers.spf
	end,
	metrics = metricConfig,
	snapshot = function()
		local stats, rows = Snapshot(), {}
		if stats then
			for _, metric in ipairs(METRICS) do
				rows[#rows + 1] = { metric = metric.id, subject = "all", value = stats[metric.field] }
			end
		end
		return rows
	end,
})

function ns.SendTravelStats()
	return peer:Sync()
end

function ns.TravelSharingChanged()
	peer:SetEnabled(ns.db.stats == true and ns.db.statsShare == true)
	lastPosition, lastSample = nil, nil
end

local function OnJourneyChanged(point, reason)
	if not point and reason == "arrived" then
		Record("routesCompleted", 1)
	end
end
ns.ProgressJourneyChanged = OnJourneyChanged

ns.Init(function()
	Ensure()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function(_, event)
		if event == "ZONE_CHANGED_NEW_AREA" then
			local plan, index
			if ns.JourneyPlan then
				plan, index = ns.JourneyPlan()
			end
			local leg = plan and plan.legs[index]
			if leg and (leg.mode == "portal" or leg.mode == "passage") and leg ~= lastPortalLeg then
				Record("portalsUsed", 1)
				lastPortalLeg = leg
			elseif not leg or (leg.mode ~= "portal" and leg.mode ~= "passage") then
				lastPortalLeg = nil
			end
			lastPosition, lastSample = nil, nil
		else
			lastPosition, lastSample = nil, nil
		end
	end)
	ns.OnTravelTick(Sample)
	C_Timer.After(15, function()
		if ns.db.statsShare then
			nextSend = GetTime() + 30
			ns.SendTravelStats()
		end
	end)
end)
