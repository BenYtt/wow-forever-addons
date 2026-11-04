---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- What a journey's walks keep away from: zones whose lowest level is well above yours (the idea is Ding!'s, by
-- Yendi) and the other faction's towns and capitals (Polestar's). A profile weights path choice: yards inside a
-- hazard count several times over while the route is chosen, but the walk's displayed time uses its real travel
-- cost. The zones and towns the journey starts and ends in are never avoided, though a hostile town there is still
-- named.
local LEVEL_GAP = 4 -- a zone whose lowest level is this many above yours is avoided
local ZONE_COST, TOWN_COST = 4, 6
-- A hostile town: around one of the other faction's flight masters with none of your own this near (a town both
-- sides share, like Booty Bay, has both). A walk is said to pass through one only nearer its middle: the search keeps
-- the whole radius dear, but its walk may still clip the edge.
local TOWN_RADIUS, SHARED, THROUGH = 150, 400, 100
-- Zone answers are kept per square of this many yards, and a hazard is sampled at most this far apart along a walk.
local CELL, STEP, SAMPLES = 64, 32, 32
local KEEP = 50000

---@class SPFHazards
---@field key string -- identifies the costs, for the searches' caches
---@field Point fun(map: number, x: number, y: number): number -- the factor at a world point, at least 1
---@field Chord fun(map: number, ax: number, ay: number, bx: number, by: number): number -- towns along a segment
---@field Near fun(map: number, minX: number, minY: number, maxX: number, maxY: number): boolean -- a town in the box
---@field TransportNear fun(map: number, x: number, y: number): boolean -- a dock or flight master within 200 yards
---@field ConnectorWalk fun(from: SPFPoint, to: SPFPoint): boolean -- a short walk next to a dock or flight master
---@field Segment fun(map: number, ax: number, ay: number, bx: number, by: number): number -- mean factor along it
---@field zones table<number, number> -- [uiMap] = factor, for the avoided zones and hostile capitals
---@field cities table<number, boolean> -- every hostile capital, exempt ones included
---@field towns SPFHazardTown[] -- every hostile town, exempt ones included
---@class SPFHazardTown
---@field id number -- its flight master
---@field map number
---@field x number
---@field y number
---@field exempt? boolean -- the journey starts or ends in it

---@class SPFHazardsModule
local Hazards = {}
ns.Hazards = Hazards

-- The zone map under a world point, kept per CELL square: a search asks for thousands of points.
local zoneCells, zoneCount = {}, 0
---@param map number
---@param x number
---@param y number
---@return number?
local function ZoneAt(map, x, y)
	local key = (math.floor(x / CELL) + 1024) * 2048 + math.floor(y / CELL) + 1024
	local cells = zoneCells[map]
	if not cells then
		cells = {}
		zoneCells[map] = cells
	end
	local zone = cells[key]
	if zone == nil then
		if zoneCount >= KEEP then
			zoneCells, zoneCount, cells = { [map] = {} }, 0, {}
			zoneCells[map] = cells
		end
		local cx, cy = (math.floor(x / CELL) + 0.5) * CELL, (math.floor(y / CELL) + 0.5) * CELL
		zone = ns.ZoneMap(map, cx, cy) or false
		cells[key], zoneCount = zone, zoneCount + 1
	end
	return zone or nil
end
Hazards.ZoneAt = ZoneAt

-- The level a profile plans for: the event's on a level-up, which UnitLevel can lag.
local levelSeen
---@return number
function Hazards.Level()
	local level = UnitLevel("player") or 1
	return math.max(level, levelSeen or 0)
end

local function Distance2(ax, ay, bx, by)
	return (ax - bx) ^ 2 + (ay - by) ^ 2
end

-- The share of a segment, from 0 to 1, inside a circle.
local function ShareInCircle(cx, cy, r, ax, ay, bx, by)
	local dx, dy, fx, fy = bx - ax, by - ay, ax - cx, ay - cy
	local a = dx * dx + dy * dy
	if a == 0 then
		return fx * fx + fy * fy <= r * r and 1 or 0
	end
	local b, c = 2 * (fx * dx + fy * dy), fx * fx + fy * fy - r * r
	local disc = b * b - 4 * a * c
	if disc <= 0 then
		return 0
	end
	local root = math.sqrt(disc)
	return math.max(0, math.min(1, (-b + root) / (2 * a)) - math.max(0, (-b - root) / (2 * a)))
end

-- The part of a segment inside a zone's box, as the fractions t0 < t1 along it, or nil.
local function Clip(zone, map, ax, ay, bx, by)
	if zone.map ~= map then
		return nil
	end
	local t0, t1 = 0, 1
	for _, axis in ipairs({ { ax, bx - ax, zone.minX, zone.maxX }, { ay, by - ay, zone.minY, zone.maxY } }) do
		local from, delta, low, high = axis[1], axis[2], axis[3], axis[4]
		if delta == 0 then
			if from < low or from > high then
				return nil
			end
		else
			local u, v = (low - from) / delta, (high - from) / delta
			if u > v then
				u, v = v, u
			end
			t0, t1 = math.max(t0, u), math.min(t1, v)
			if t0 >= t1 then
				return nil
			end
		end
	end
	return t0, t1
end

-- The other faction's towns: its flight masters with none of yours within SHARED.
---@param faction string
---@return SPFHazardTown[]
local function HostileTowns(faction)
	local towns = {}
	for id, node in pairs(ns.TaxiNodes) do
		if node.faction and node.faction ~= faction then
			local shared = false
			for _, other in pairs(ns.TaxiNodes) do
				if
					other.map == node.map
					and other.faction == faction
					and Distance2(other.x, other.y, node.x, node.y) <= SHARED ^ 2
				then
					shared = true
					break
				end
			end
			if not shared then
				towns[#towns + 1] = { id = id, map = node.map, x = node.x, y = node.y }
			end
		end
	end
	table.sort(towns, function(a, b)
		return a.id < b.id
	end)
	return towns
end

-- The radius in which a short walk can connect a dock or flight master to the walking network.
local CONNECTOR_RADIUS = 200

local function Inside(zone, map, x, y)
	return zone.map == map and x >= zone.minX and x <= zone.maxX and y >= zone.minY and y <= zone.maxY
end

-- The costs a journey from `from` to `goal` walks with. Nothing is avoided where neither end could ever mind it, but
-- the profile always exists: the other faction's towns are on every continent.
---@param from SPFPoint
---@param goal SPFPoint
---@return SPFHazards
function Hazards.Profile(from, goal)
	local faction = UnitFactionGroup("player")
	local level = Hazards.Level()
	local exempt, keys = {}, {}
	for _, point in ipairs({ from, goal }) do
		-- The point's own zone, not its cached square's: a goal just over a border is in the zone it is in.
		local zone = ns.ZoneMap(point.map, point.x, point.y)
		if zone then
			exempt[zone] = true
		end
	end
	local zones, boxes, cities, ids = {}, {}, {}, {}
	for id, zone in pairs(ns.Zones) do
		local factor
		if zone.city then
			factor = faction and zone.city ~= faction and TOWN_COST
			cities[id] = factor and true or nil
		elseif ns.db.avoidHighZones and zone.low >= level + LEVEL_GAP then
			factor = ZONE_COST
		end
		if factor and not exempt[id] then
			zones[id] = factor
			boxes[#boxes + 1] = zone
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		keys[#keys + 1] = id
	end
	local towns, active = {}, {}
	-- A flight master inside a hostile capital is that capital's: the city itself is the hazard, named once.
	for _, town in ipairs(faction and HostileTowns(faction) or {}) do
		if not cities[ZoneAt(town.map, town.x, town.y) or 0] then
			towns[#towns + 1] = town
		end
	end
	for _, town in ipairs(towns) do
		for _, point in ipairs({ from, goal }) do
			if point.map == town.map and Distance2(point.x, point.y, town.x, town.y) <= TOWN_RADIUS ^ 2 then
				town.exempt = true
			end
		end
		if not town.exempt then
			active[#active + 1] = town
			keys[#keys + 1] = "t" .. town.id
		end
	end

	local function Point(map, x, y)
		local factor = 1
		for _, town in ipairs(active) do
			if town.map == map and Distance2(x, y, town.x, town.y) <= TOWN_RADIUS ^ 2 then
				factor = TOWN_COST
				break
			end
		end
		for _, zone in ipairs(boxes) do
			if Inside(zone, map, x, y) then
				local found = ZoneAt(map, x, y)
				return math.max(factor, found and zones[found] or 1)
			end
		end
		return factor
	end
	-- The mean factor of the towns along a segment: only the share of it inside each one counts extra.
	local function Chord(map, ax, ay, bx, by)
		local extra = 0
		for _, town in ipairs(active) do
			if town.map == map then
				extra = extra + ShareInCircle(town.x, town.y, TOWN_RADIUS, ax, ay, bx, by) * (TOWN_COST - 1)
			end
		end
		return 1 + extra
	end
	local function Near(map, minX, minY, maxX, maxY)
		for _, town in ipairs(active) do
			if
				town.map == map
				and town.x >= minX - TOWN_RADIUS
				and town.x <= maxX + TOWN_RADIUS
				and town.y >= minY - TOWN_RADIUS
				and town.y <= maxY + TOWN_RADIUS
			then
				return true
			end
		end
		return false
	end
	local function TransportNear(map, x, y)
		for _, node in pairs(ns.TaxiNodes) do
			if node.map == map and Distance2(x, y, node.x, node.y) <= CONNECTOR_RADIUS ^ 2 then
				return true
			end
		end
		for _, dock in pairs(ns.Docks or {}) do
			local point = dock.walk or dock
			if point.map == map and Distance2(x, y, point.x, point.y) <= CONNECTOR_RADIUS ^ 2 then
				return true
			end
		end
		return false
	end
	local function ConnectorWalk(start, target)
		if start.map ~= target.map then
			return false
		end
		local dx, dy = start.x - target.x, start.y - target.y
		return dx * dx + dy * dy <= CONNECTOR_RADIUS ^ 2
			and (TransportNear(start.map, start.x, start.y) or TransportNear(target.map, target.x, target.y))
	end
	-- The mean factor along a straight walk: what a walk baked without hazards costs here. A town counts the share of
	-- the walk inside it; a zone, the share of samples inside its map's box that the zone's map holds.
	local function Segment(map, ax, ay, bx, by)
		local extra, length = 0, math.sqrt(Distance2(ax, ay, bx, by))
		for _, town in ipairs(active) do
			if town.map == map then
				extra = extra + ShareInCircle(town.x, town.y, TOWN_RADIUS, ax, ay, bx, by) * (TOWN_COST - 1)
			end
		end
		for _, id in ipairs(ids) do
			local zone = ns.Zones[id]
			local t0, t1 = Clip(zone, map, ax, ay, bx, by)
			if t0 then
				local n = math.min(SAMPLES, math.max(1, math.ceil((t1 - t0) * length / CELL)))
				local inside = 0
				for i = 1, n do
					local t = t0 + (t1 - t0) * (i - 0.5) / n
					if ZoneAt(map, ax + (bx - ax) * t, ay + (by - ay) * t) == id then
						inside = inside + 1
					end
				end
				extra = extra + (t1 - t0) * inside / n * (zones[id] - 1)
			end
		end
		return 1 + extra
	end
	return {
		-- What is avoided, not why: a level-up that crosses no zone's threshold keeps every search.
		key = (faction or "") .. ":" .. table.concat(keys, ","),
		Point = Point,
		Chord = Chord,
		Near = Near,
		TransportNear = TransportNear,
		ConnectorWalk = ConnectorWalk,
		Segment = Segment,
		zones = zones,
		cities = cities,
		towns = towns,
	}
end

-- A town's name: its flight master's, without the zone after the comma.
local function TownName(town)
	return (ns.TaxiName(town.id):gsub(",.*$", ""))
end

local function ZoneName(id)
	local info = C_Map.GetMapInfo(id)
	return info and info.name or UNKNOWN
end

-- The hazards a walk's points pass through, in the order it meets them: hostile towns and capitals, exempt ones too,
-- and the zones the profile avoids. Each is { kind = "town"|"zone", id, name }.
---@param hazards SPFHazards
---@param points SPFPoint[]
---@return {kind: string, id: number, name: string}[]
local function Met(hazards, points)
	local met, seen = {}, {}
	local function add(kind, id, name)
		local key = kind .. id
		if not seen[key] then
			seen[key] = true
			met[#met + 1] = { kind = kind, id = id, name = name() }
		end
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if a.map == b.map and not a.jump then
			local n = math.max(1, math.ceil(math.sqrt(Distance2(a.x, a.y, b.x, b.y)) / STEP))
			for step = 0, n do
				local x, y = a.x + (b.x - a.x) * step / n, a.y + (b.y - a.y) * step / n
				for _, town in ipairs(hazards.towns) do
					if town.map == a.map and Distance2(x, y, town.x, town.y) <= THROUGH ^ 2 then
						add("town", town.id, function()
							return TownName(town)
						end)
					end
				end
				local zone = (next(hazards.zones) or next(hazards.cities)) and ZoneAt(a.map, x, y)
				if zone and (hazards.zones[zone] or hazards.cities[zone]) then
					add(hazards.cities[zone] and "town" or "zone", zone, function()
						return ZoneName(zone)
					end)
				end
			end
		end
	end
	return met
end

-- A level range as the notes show it: "18-30".
local function Levels(id)
	local zone = ns.Zones[id]
	return zone.low == zone.high and tostring(zone.low) or zone.low .. "-" .. zone.high
end

-- The tracker's lines under a measured walk: each hostile town it passes ("Hostile town: Crossroads"), each zone far
-- above you it must cross, and each one the straight way would have crossed that it goes round.
---@param hazards SPFHazards?
---@param leg SPFLeg
---@param points SPFWalkPoints
---@return string[]?
function Hazards.Notes(hazards, leg, points)
	if not hazards or #points < 2 then
		return nil
	end
	local notes, walked = {}, {}
	for _, hazard in ipairs(Met(hazards, points)) do
		walked[hazard.kind .. hazard.id] = true
		if hazard.kind == "town" then
			notes[#notes + 1] = string.format(L["Hostile town: %s"], hazard.name)
		else
			notes[#notes + 1] = string.format(L["Crosses %s (level %s)"], hazard.name, Levels(hazard.id))
		end
	end
	for _, hazard in ipairs(Met(hazards, { leg.from, leg.to })) do
		if hazard.kind == "zone" and not walked["zone" .. hazard.id] then
			notes[#notes + 1] = string.format(L["Avoids %s (level %s)"], hazard.name, Levels(hazard.id))
		end
	end
	return #notes > 0 and notes or nil
end

ns.Init(function()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_LEVEL_UP")
	events:SetScript("OnEvent", function(_, _, level)
		levelSeen = level
		-- A zone you have grown into is no longer avoided: plan again.
		if ns.db.avoidHighZones and ns.HasJourney() then
			ns.TravelPolicyChanged()
		end
	end)
end)
