---@class SPFNamespace
local ns = select(2, ...)

-- What a flown taxi route really took, and how much of a flight leg is left. A ride is timed from the moment the
-- client takes control to the moment it gives control back, saved per directed flight path beside the other
-- observations, and preferred over the shipped estimate by the planner. In flight, the remaining time comes from
-- the player's progress along the drawn path, so it counts down on the path's own geometry rather than on the
-- estimate. Observation only: nothing here plans or draws.

---@class SPFTaxiTimes
local TaxiTimes = {}
ns.TaxiTimes = TaxiTimes

-- A ride shorter than this is not a flight; longer than this is a bad reading, not a route.
local MIN_SECONDS, MAX_SECONDS = 5, 3600
-- A sample this far from the flown path is no longer on it.
local ON_PATH = 100
-- How near an intermediate flight point the player passes to end that hop.
local AT_NODE = 80
-- How near the player stands to a flight point to call it the ride's origin.
local AT_ORIGIN = 200
-- How near the first point of a path keeps it a candidate for a ride whose origin is not yet clear.
local AT_START = 250

---@type table<number, SPFTaxiPath[]>
local byFrom = {}

---@class SPFTaxiFlight
---@field candidates SPFTaxiPath[]
---@field startedAt number seconds the ride began
---@field hopStart number seconds the hop being flown began
---@field path? SPFTaxiPath

---@type SPFTaxiFlight?
local flight
---@type table<string, number>
local snapshot = {}
local version, snapshotVersion = 0, -1

local function Key(from, to)
	return from .. ":" .. to
end

-- The nearest segment to (map, x, y), and the yards along the path to that projection when the hop's cumulative
-- distances are given.
---@param points number[]
---@param map number
---@param x number
---@param y number
---@param distances? number[]
---@return number? off -- squared yards from the projection
---@return number? yards
local function Project(points, map, x, y, distances)
	local bestOff, bestYards
	for point = 1, #points / 3 - 1 do
		if points[point * 3 - 2] == map then
			local ax, ay = points[point * 3 - 1], points[point * 3]
			local dx, dy = points[point * 3 + 2] - ax, points[point * 3 + 3] - ay
			local length = dx * dx + dy * dy
			local t = length > 0 and ((x - ax) * dx + (y - ay) * dy) / length or 0
			t = math.max(0, math.min(1, t))
			local off = (ax + t * dx - x) ^ 2 + (ay + t * dy - y) ^ 2
			if not bestOff or off < bestOff then
				bestOff = off
				bestYards = distances and distances[point] + t * math.sqrt(length)
			end
		end
	end
	return bestOff, bestYards
end

---@param path SPFTaxiPath
---@param map number
---@param x number
---@param y number
---@return number? squared yards from the nearest point on the path
local function Nearest(path, map, x, y)
	local off = Project(path.points, map, x, y)
	return off
end

-- The player stands this near the path's last point: the hop arrived at its flight point.
---@param path SPFTaxiPath
---@param map number
---@param x number
---@param y number
---@return boolean
local function Arrived(path, map, x, y)
	local points = path.points
	local last = #points - 2
	if points[last] ~= map then
		return false
	end
	local dx, dy = points[last + 1] - x, points[last + 2] - y
	return dx * dx + dy * dy <= AT_NODE * AT_NODE
end

---@param map number
---@param x number
---@param y number
---@return number? nodeID
local function NearestNode(map, x, y)
	local bestID, best
	for id, node in pairs(ns.TaxiNodes or {}) do
		if node.map == map then
			local dx, dy = node.x - x, node.y - y
			local distance = dx * dx + dy * dy
			if not best or distance < best then
				bestID, best = id, distance
			end
		end
	end
	if best and best <= AT_ORIGIN * AT_ORIGIN then
		return bestID
	end
end

-- The paths whose first point lies near the player, for a ride whose origin node could not be named.
---@param map number
---@param x number
---@param y number
---@return SPFTaxiPath[]
local function NearStart(map, x, y)
	local candidates = {}
	for _, path in ipairs(ns.TaxiPaths or {}) do
		local points = path.points
		if points[1] == map then
			local dx, dy = points[2] - x, points[3] - y
			if dx * dx + dy * dy <= AT_START * AT_START then
				candidates[#candidates + 1] = path
			end
		end
	end
	return candidates
end

---@param map number
---@param x number
---@param y number
---@param now number
---@return SPFTaxiFlight?
local function Start(map, x, y, now)
	local origin = NearestNode(map, x, y)
	local candidates = origin and byFrom[origin] or nil
	if not candidates or #candidates == 0 then
		candidates = NearStart(map, x, y)
	end
	if #candidates == 0 then
		return nil
	end
	return { candidates = candidates, startedAt = now, hopStart = now }
end

local function Store()
	local store = ns.db.taxiTimes
	if not store then
		store = {}
		ns.db.taxiTimes = store
	end
	return store
end

-- Save the hop unless the reading is too short to be one or too long to trust.
---@param path SPFTaxiPath
---@param fromTime number
---@param toTime number
local function Record(path, fromTime, toTime)
	local seconds = math.floor(toTime - fromTime + 0.5)
	if seconds < MIN_SECONDS or seconds > MAX_SECONDS then
		return
	end
	Store()[Key(path.from, path.to)] = seconds
	version = version + 1
end

-- End the hop being flown at now, leaving the flight ready for whatever path follows.
---@param now number
local function EndHop(now)
	local current = flight
	if not current or not current.path then
		return
	end
	Record(current.path, current.hopStart, now)
	current.path, current.hopStart, current.candidates = nil, now, nil
end

---@param path SPFTaxiPath
---@param now number
local function Commit(path, now)
	local current = flight
	if not current then
		return
	end
	if current.path then
		Record(current.path, current.hopStart, now)
	end
	current.path, current.candidates = path, nil
	-- The first hop keeps the ride's start, so the shared opening is not lost to the delayed match.
	current.hopStart = current.hopStart or now
end

local function TaxiSample()
	local now = GetTime()
	if not UnitOnTaxi("player") then
		if flight then
			EndHop(now)
			flight = nil
		end
		return
	end
	local x, y, _, map = ns.JourneyPosition()
	if not (x and y and map) then
		return
	end
	if not flight then
		flight = Start(map, x, y, now)
		if not flight then
			return
		end
	end
	local current = flight
	if not current then
		return
	end
	local path = current.path
	if path then
		if Arrived(path, map, x, y) then
			-- At a flight point: the hop is over, and whatever follows starts here.
			EndHop(now)
			current.candidates = byFrom[path.to] or {}
			return
		end
		local distance = Nearest(path, map, x, y)
		if not distance or distance > ON_PATH * ON_PATH then
			-- Off the path: the map changed mid-crossing, or the reading drifted too far to attribute.
			EndHop(now)
			current.candidates = byFrom[path.to] or {}
		end
		return
	end
	local candidates = current.candidates
	if not candidates or #candidates == 0 then
		candidates = NearStart(map, x, y)
	end
	local keep = {}
	for _, candidate in ipairs(candidates) do
		local distance = Nearest(candidate, map, x, y)
		if distance and distance <= ON_PATH * ON_PATH then
			keep[#keep + 1] = candidate
		end
	end
	current.candidates = keep
	if #keep == 1 then
		Commit(keep[1], now)
	end
end

-- The flown seconds for a directed path, once a ride has measured it.
---@param from number
---@param to number
---@return number?
function TaxiTimes.Seconds(from, to)
	local store = ns.db and ns.db.taxiTimes
	return store and store[Key(from, to)]
end

---@class SPFFlightFrom
---@field to number the flight point it lands at
---@field seconds number measured on a ride of yours, else the shipped time
---@field measured boolean
---@field estimated? boolean the shipped time is worked out from the path's length, not timed

-- The direct flights from a flight point to the ones `eligible` allows: your own timings first, then the shipped,
-- each group quickest first.
---@param from number
---@param eligible fun(to: number): boolean
---@return SPFFlightFrom[]
function TaxiTimes.FlightsFrom(from, eligible)
	local flights = {}
	for _, path in ipairs(byFrom[from] or {}) do
		if eligible(path.to) then
			local measured = TaxiTimes.Seconds(from, path.to)
			flights[#flights + 1] = {
				to = path.to,
				seconds = measured or path.seconds,
				measured = measured ~= nil,
				estimated = not measured and path.estimated or nil,
			}
		end
	end
	table.sort(flights, function(a, b)
		if a.measured ~= b.measured then
			return a.measured
		end
		if a.seconds ~= b.seconds then
			return a.seconds < b.seconds
		end
		return a.to < b.to
	end)
	return flights
end

-- The measured seconds as the planner's plain data, a fresh table only when a ride has added one.
---@return table<string, number>
function TaxiTimes.Snapshot()
	if snapshotVersion ~= version then
		local copy = {}
		for key, seconds in pairs(ns.db and ns.db.taxiTimes or {}) do
			copy[key] = seconds
		end
		snapshot, snapshotVersion = copy, version
	end
	return snapshot
end

-- The committed hop of the ride in progress, so a flight leg can tell whether it is the one being flown.
---@return SPFTaxiPath?
function TaxiTimes.CurrentPath()
	return flight and flight.path or nil
end

-- Cached per-hop geometry, keyed by the leg the planner returned.
local geometry = setmetatable({}, { __mode = "k" })

---@param leg SPFLeg
---@return { before: number[], cumulative: number[][], total: number }
local function LegGeometry(leg)
	local cached = geometry[leg]
	if cached then
		return cached
	end
	local before, cumulative, total = {}, {}, 0
	for index, hop in ipairs(leg.hops) do
		before[index] = total
		local points, distances, length = hop.points, { 0 }, 0
		for point = 1, #points / 3 - 1 do
			local dx = points[point * 3 + 2] - points[point * 3 - 1]
			local dy = points[point * 3 + 3] - points[point * 3]
			length = length + math.sqrt(dx * dx + dy * dy)
			distances[point + 1] = length
		end
		cumulative[index] = distances
		total = total + length
	end
	cached = { before = before, cumulative = cumulative, total = total }
	geometry[leg] = cached
	return cached
end

-- Yards travelled along one hop, from the nearest segment to the player.
---@param hop SPFTaxiPath
---@param distances number[]
---@param map number
---@param x number
---@param y number
---@return number? yards
local function Along(hop, distances, map, x, y)
	local _, yards = Project(hop.points, map, x, y, distances)
	return yards
end

-- The milliseconds left of the flight leg being flown, read from where the player is on its drawn path, or nil
-- when this is not the leg in the air.
---@param leg SPFLeg
---@return number?
function TaxiTimes.Remaining(leg)
	if not (flight and flight.path and leg and leg.mode == "flight" and leg.hops) then
		return nil
	end
	if not UnitOnTaxi("player") then
		return nil
	end
	local x, y, _, map = ns.JourneyPosition()
	if not (x and y and map) then
		return nil
	end
	local index
	for hopIndex, hop in ipairs(leg.hops) do
		if rawequal(hop, flight.path) then
			index = hopIndex
			break
		end
	end
	if not index then
		return nil
	end
	local span = leg.arrive - leg.depart
	local shape = LegGeometry(leg)
	if span <= 0 or shape.total <= 0 then
		return nil
	end
	local yards = Along(flight.path, shape.cumulative[index], map, x, y)
	if not yards then
		return nil
	end
	local remaining = span * (shape.total - shape.before[index] - yards) / shape.total
	return math.max(0, remaining)
end

ns.Init(function()
	ns.db.taxiTimes = ns.db.taxiTimes or {}
	if ns.TaxiPaths then
		local valid = {}
		for _, path in ipairs(ns.TaxiPaths) do
			valid[Key(path.from, path.to)] = true
			local list = byFrom[path.from]
			if not list then
				list = {}
				byFrom[path.from] = list
			end
			list[#list + 1] = path
		end
		for key, seconds in pairs(ns.db.taxiTimes) do
			if not valid[key] or type(seconds) ~= "number" or seconds < MIN_SECONDS or seconds > MAX_SECONDS then
				ns.db.taxiTimes[key] = nil
			end
		end
	end
	version = version + 1
	ns.OnTravelTick(TaxiSample)
end)
