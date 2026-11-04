---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

local MapCanvas = ns.MapCanvas
local PIN_TEMPLATE = "ShortestPathForeverDockPinTemplate"
local PORTAL_TEMPLATE = "ShortestPathForeverPortalPinTemplate"
local PING_FILE = "Interface\\Minimap\\UI-Minimap-Ping-Expand"
local PIN_SIZE = 20
local ARROW_SIZE = 15
-- The floor arrows are 13 by 14 (UiTextureAtlasMember, 1.60.1.70009), so they are fitted, never squared.
local TRANSPORT_ATLASES = {
	boat = "flightmasterferry",
	lift = "poi-door-arrow-up",
	tram = "poi-door-arrow-down",
	portal = "map-icon-suramardoor.tga",
}
-- Half a pin, as a fraction of a zoomed-out map.
local EDGE = 0.015
-- Docks closer than this many pins apart merge into one.
local OVERLAP = 0.8

-- The pins' pools on the world map (UI/MapCanvas.lua), made at load.
---@type SPFCanvasPool, SPFCanvasPool
local dockPins, portalPins
local Docks

-- The stock ferry atlas serves both surface transports. Lifts and the tram take the stock map's floor-change arrows;
-- portals use its arcane door.
---@param texture Texture
---@param kind SPFMode
---@param size number?
function ns.SetTransportIcon(texture, kind, size)
	-- The floor arrows fill their box where the ferry has a margin, so they draw smaller to match.
	size = (size or PIN_SIZE) * ((kind == "lift" or kind == "tram") and ARROW_SIZE / PIN_SIZE or 1)
	if kind == "boat" or kind == "zeppelin" then
		ns.Art.Fit(texture, "flightmasterferry", size, size)
	elseif TRANSPORT_ATLASES[kind] then
		ns.Art.Fit(texture, TRANSPORT_ATLASES[kind], size, size)
	else
		error("unknown route kind " .. tostring(kind))
	end
end

local dockKinds
---@param dockID number
---@return SPFMode
function ns.DockKind(dockID)
	if not dockKinds then
		dockKinds = {}
		for _, route in pairs(ns.Routes) do
			for _, stop in ipairs(route.stops) do
				dockKinds[stop.dock] = route.kind
			end
		end
	end
	return dockKinds[dockID]
end

local TO = {
	boat = L["Boat to %s"],
	zeppelin = L["Zeppelin to %s"],
	lift = L["Lift to %s"],
	tram = L["Tram to %s"],
	portal = L["Portal to %s"],
}
local KINDS = { boat = L["Boats"], zeppelin = L["Zeppelins"], lift = L["Lifts"], tram = L["Deeprun Tram"] }
local ORDER = { "boat", "zeppelin", "lift", "tram" }
-- A landing named by the way it lies from the others ("north pier"), or by itself when it is the only one.
local LANDING = { boat = L["%s pier"], zeppelin = L["%s tower"], lift = L["%s landing"], tram = L["%s station"] }
local LANDING_ALONE = { boat = L["dock"], zeppelin = L["tower"], lift = L["landing"], tram = L["station"] }
local COMPASS = {
	L["east"],
	L["northeast"],
	L["north"],
	L["northwest"],
	L["west"],
	L["southwest"],
	L["south"],
	L["southeast"],
}

local function StatusColor(departure)
	return departure.known and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
end

-- The click hint, only when a click has somewhere to go.
local function AddEndsLine(ends)
	if #ends == 1 then
		GameTooltip_AddInstructionLine(GameTooltip, string.format(L["Click to show %s"], ends[1].zone))
	elseif #ends > 1 then
		GameTooltip_AddInstructionLine(GameTooltip, L["Click to show where they go"])
	end
end

local function AddDepartureLines(departures)
	for _, departure in ipairs(departures) do
		GameTooltip_AddColoredDoubleLine(
			GameTooltip,
			string.format(L["to %s"], ns.Timetable.Destination(departure)),
			ns.Timetable.Status(departure),
			NORMAL_FONT_COLOR,
			StatusColor(departure)
		)
	end
end

---@class SPFDockPin : SPFCanvasPin
---@field Texture Texture
---@field HighlightTexture Texture
---@field Glow Texture
---@field cluster? table
---@field tooltipElapsed number
local DockPin = CreateFromMixins(MapCanvas.PinMixin)

function DockPin:OnLoad()
	-- Above town, flight point and dungeon icons, so a dock beside one still takes the hover.
	self:UseFrameLevelType("PIN_FRAME_LEVEL_GOSSIP")
	self:SetScalingLimits(1, 1, 1.2)
	self:SetSize(PIN_SIZE, PIN_SIZE)
	self.takesMouse = true
	self:SetScript("OnHide", self.OnMouseLeave)
end

-- cluster = { docks = { { id, x, y }... }, x, y, kind, kinds = { [kind] = true }, key = the dock ids joined by
-- commas }: one dock, or several too close to tell apart.
function DockPin:OnAcquired(cluster)
	self.cluster = cluster
	local scale = (ns.db.mapPinScale or 100) / 100
	self:SetScalingLimits(1, scale, scale * 1.2)
	ns.SetTransportIcon(self.Texture, cluster.kind)
	ns.SetTransportIcon(self.HighlightTexture, cluster.kind)
	self:SetPosition(cluster.x, cluster.y)
end

local function PierName(x, y, cx, cy, kind)
	local angle = math.atan2(cy - y, x - cx)
	local direction = COMPASS[math.floor(angle / (2 * math.pi) * 8 + 0.5) % 8 + 1]
	return string.format(LANDING[kind], direction)
end

-- Which of a cluster's docks this is: a lift's landing or tram station by name (with its site where sites
-- differ), otherwise its zone where the zones differ, and which way it lies from the pin where they do not.
local function LandingName(cluster, dock, kind)
	local site = ns.Docks[dock.id].site
	if site then
		for _, other in ipairs(cluster.docks) do
			if ns.Docks[other.id].site ~= site then
				return ns.DockTitle(dock.id)
			end
		end
		return ns.DockLabel(dock.id)
	end
	local zone, sharedZone = ns.DockZone(dock.id), false
	for _, other in ipairs(cluster.docks) do
		sharedZone = sharedZone or (other ~= dock and ns.DockZone(other.id) == zone)
	end
	if not sharedZone then
		return zone
	end
	local name = PierName(dock.x, dock.y, cluster.x, cluster.y, kind)
	return #cluster.docks > 2 and zone .. ", " .. name or (name:gsub("^%l", string.upper))
end

local dockNames = {}
---@param dockID number
---@return string
function ns.DockPierName(dockID)
	if not dockNames[dockID] then
		local dock, kind = ns.Docks[dockID], ns.DockKind(dockID)
		local place, nearest = ns.DockZone(dockID), 1000 ^ 2
		-- Flight points already name the harbour or town; use the zone only when no nearby town is known.
		for _, taxi in pairs(ns.TaxiNodes) do
			local distance = (taxi.x - dock.x) ^ 2 + (taxi.y - dock.y) ^ 2
			if taxi.map == dock.map and distance < nearest then
				place, nearest = taxi.name:match("^[^,]+"), distance
			end
		end
		local x, y, count = 0, 0, 0
		for id, other in pairs(ns.Docks) do
			if
				other.map == dock.map
				and ns.DockKind(id) == kind
				and (other.x - dock.x) ^ 2 + (other.y - dock.y) ^ 2 < 800 ^ 2
			then
				x, y, count = x - other.y, y - other.x, count + 1
			end
		end
		local landing = count > 1 and PierName(-dock.y, -dock.x, x / count, y / count, kind) or LANDING_ALONE[kind]
		dockNames[dockID] = place .. " " .. landing
	end
	return dockNames[dockID]
end

-- Titled by what the pin is, not where: the map already names the zone. Shared with the minimap's pins, whose
-- clusters carry the same fields.
function ns.AddDockTooltip(cluster)
	local all = {}
	local groups = {}
	for _, dock in ipairs(cluster.docks) do
		local departures = ns.Timetable.ByDestination(dock.id)
		-- A dock whose shown route a filter has since hidden has no departures; a stale cluster must not index one.
		if #departures > 0 then
			groups[#groups + 1] = { dock = dock, departures = departures }
			for _, departure in ipairs(departures) do
				all[#all + 1] = departure
			end
		end
	end
	if #all == 1 then
		local departure = all[1]
		GameTooltip_SetTitle(GameTooltip, string.format(TO[departure.kind], ns.Timetable.Destination(departure)))
		local status = ns.Timetable.Status(departure):gsub("^%l", string.upper)
		GameTooltip_AddColoredLine(GameTooltip, status, StatusColor(departure))
	else
		local titles = {}
		for _, kind in ipairs(ORDER) do
			if cluster.kinds[kind] then
				titles[#titles + 1] = KINDS[kind]
			end
		end
		GameTooltip_SetTitle(GameTooltip, table.concat(titles, " & "))
		for _, group in ipairs(groups) do
			if #groups > 1 then
				local kind = group.departures[1].kind
				GameTooltip_AddColoredLine(GameTooltip, LandingName(cluster, group.dock, kind), HIGHLIGHT_FONT_COLOR)
			end
			AddDepartureLines(group.departures)
		end
	end
	local freshest
	for _, departure in ipairs(all) do
		if departure.known and (not freshest or departure.seen < freshest.seen) then
			freshest = departure
		end
	end
	if freshest then
		local text = string.format(
			freshest.source == "you" and L["Last seen %d min ago by you"] or L["Last seen %d min ago by another player"],
			math.floor(freshest.seen / 60)
		)
		GameTooltip_AddNormalLine(GameTooltip, GRAY_FONT_COLOR:WrapTextInColorCode(text))
	end
end

function DockPin:RefreshTooltip()
	ns.AddDockTooltip(self.cluster)
	AddEndsLine(self:GetEnds())
	GameTooltip:Show()
end

function DockPin:OnMouseEnter()
	local routes = {}
	for _, dock in ipairs(self.cluster.docks) do
		for _, departure in ipairs(ns.Timetable.Departures(dock.id)) do
			routes[departure.route] = true
		end
	end
	ns.HoverTransportRoutes(self, routes)
	Docks:ShowDestinations(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	self:RefreshTooltip()
	self.tooltipElapsed = 0
	self:SetScript("OnUpdate", function(pin, elapsed)
		if not (GameTooltip:IsOwned(pin) and GameTooltip:IsShown()) then
			pin:SetScript("OnUpdate", nil)
			return
		end
		pin.tooltipElapsed = pin.tooltipElapsed + elapsed
		if pin.tooltipElapsed >= 1 then
			pin.tooltipElapsed = pin.tooltipElapsed % 1
			pin:RefreshTooltip()
		end
	end)
end

function DockPin:OnMouseLeave()
	ns.HoverTransportRoutes(self, nil)
	Docks:HideDestinations()
	self:SetScript("OnUpdate", nil)
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

function DockPin:OnReleased()
	self:OnMouseLeave()
	self.Glow:Hide()
	self.cluster = nil
end

-- The docks' layer on the world map: their pins, and the ping that marks a crossing's far end.
---@class SPFDockLayer
---@field pins? table<string, SPFDockPin> by the key of the cluster's docks
---@field pinOf? table<number, SPFDockPin> by dock id
---@field mapID? number
---@field ping? SPFPingPin
---@field pingMap? number
Docks = {}

function Docks:RemoveAllData()
	dockPins:ReleaseAll()
	-- [dockID] = the pin showing it; [key of the cluster's docks] = that pin.
	self.pinOf, self.pins = {}, {}
end

-- Where the hovered pin's boats go, glowing like the map legend's related pins.
function Docks:ShowDestinations(pin)
	for _, dock in ipairs(pin.cluster.docks) do
		for _, departure in ipairs(ns.Timetable.Departures(dock.id)) do
			for _, destination in ipairs(departure.to) do
				local target = self.pinOf[destination]
				if target and target ~= pin then
					target.Glow:Show()
				end
			end
		end
	end
end

-- The stock map ping (MapPinPingTemplate, SharedMapPoiTemplates.xml): its ring flashes twice while it grows, at
-- a point rather than a pin, as a portal's far end has none and a dock's may be filtered out.
local PING_LOOPS, PING_GROW = 2, 0.575
---@param ping SPFPingPin
local function PingArt(ping)
	ping:SetSize(70, 70)
	local ring = ping:CreateTexture(nil, "BACKGROUND")
	ring:SetPoint("CENTER")
	ns.Art.Icon(ring, PING_FILE, 50)
	ring:SetAlpha(0)
	local flash = ping:CreateAnimationGroup()
	for loop = 0, PING_LOOPS - 1 do
		for step, delay in ipairs({ 0, 0.45, 0.575, 0.95 }) do
			local alpha = flash:CreateAnimation("Alpha")
			alpha:SetTarget(ring)
			alpha:SetFromAlpha(step % 2 == 1 and 0 or 1)
			alpha:SetToAlpha(step % 2 == 1 and 1 or 0)
			alpha:SetStartDelay(loop * 1.15 + delay)
			alpha:SetDuration(0.2)
			alpha:SetOrder(1)
		end
	end
	local grow = flash:CreateAnimation("Scale")
	grow:SetTarget(ring)
	grow:SetScaleFrom(0.5, 0.5)
	grow:SetScaleTo(1.2, 1.2)
	grow:SetDuration(PING_GROW)
	grow:SetOrder(1)
	flash:SetScript("OnFinished", function()
		ping:Hide()
	end)
	ping.animation = flash
end

---@class SPFPingPin : SPFCanvasPin
---@field animation AnimationGroup
local PingPin = CreateFromMixins(MapCanvas.PinMixin)

function PingPin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_QUEST_PING")
	self:SetScalingLimits(1, 0.65, 0.65)
	PingArt(self)
end

---@param mapID? number the map the point is on, which the map is being turned to
---@param x number
---@param y number
function Docks:Ping(mapID, x, y)
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	if not self.ping then
		self.ping = MapCanvas.Pool(WorldMapFrame, "ping", PingPin):Acquire() --[[@as SPFPingPin]]
	end
	self.pingMap = mapID
	self.ping:Show()
	self.ping:SetPosition(x, y)
	self.ping.animation:Stop()
	self.ping.animation:Play()
end

function Docks:HideDestinations()
	for _, pin in pairs(self.pins) do
		pin.Glow:Hide()
	end
end

-- A dock shows on its zone and every map above it (continent, Azeroth), where both ends of a crossing fit.
local function IsDockMap(location, mapID)
	---@type UiMapDetails?
	local info = C_Map.GetMapInfo(location.uiMap)
	while info do
		if info.mapID == mapID then
			return true
		end
		info = info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID) or nil
	end
	return false
end

-- Whether a dock has any route the filters still show.
function ns.DockShown(dockID)
	for _, visit in ipairs(ns.Timetable.Visits(dockID)) do
		local route = ns.Routes[visit.route]
		if ns.RouteShown(route) and ns.KindShown(route.kind) then
			return true
		end
	end
	return false
end

-- A world point's position on this map, in map fractions, or nil when it is off the map.
local function MapPosition(point, mapID)
	local uiMap, position = C_Map.GetMapPosFromWorldPos(point.map, CreateVector2D(point.x, point.y), mapID)
	if uiMap ~= mapID or not position then
		return nil
	end
	local x, y = position:GetXY()
	if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
		-- Piers at the map's edge (Menethil) would be half cut off; keep the whole pin on the map.
		return Clamp(x, EDGE, 1 - EDGE), Clamp(y, EDGE, 1 - EDGE)
	end
end
-- FlightPins.lua places its pins the same way.
ns.MapPinPosition, ns.IsDockMap = MapPosition, IsDockMap

-- Where a pin's routes end, one per map other than this one: candidates = { { kind, point }... }, in the
-- tooltip's order. A lift's landings share one spot, so a lift has an end only from a map other than its own.
local function Ends(mapID, candidates)
	local ends, seen = {}, { [mapID] = true }
	for _, candidate in ipairs(candidates) do
		local location = ns.Locate(candidate.point)
		if location and not seen[location.uiMap] then
			seen[location.uiMap] = true
			candidate.uiMap, candidate.zone = location.uiMap, location.zone
			ends[#ends + 1] = candidate
		end
	end
	return ends
end

-- The pins live only on the world map, and the game's own handler for this request retargets it.
local function ShowEnd(target)
	if not ns.OpenWorldMap(target.uiMap) then
		return
	end
	local x, y = MapPosition(target.point, target.uiMap)
	if x and y then
		Docks:Ping(target.uiMap, x, y)
	end
end

-- One end opens straight away. A hub's ends are a menu, as the map is gone once one opens, so there is no
-- cycling through them.
local function OpenEnds(pin, button)
	if button ~= "LeftButton" or IsModifierKeyDown() then
		return
	end
	local ends = pin:GetEnds()
	if #ends == 1 then
		ShowEnd(ends[1])
	elseif #ends > 1 then
		ns.ContextMenu(pin, function(_, root)
			for _, target in ipairs(ends) do
				root:CreateButton(string.format(TO[target.kind], target.zone), function()
					ShowEnd(target)
				end)
			end
		end)
	end
end

function DockPin:GetEnds()
	local candidates = {}
	for _, dock in ipairs(self.cluster.docks) do
		for _, departure in ipairs(ns.Timetable.Departures(dock.id)) do
			for _, dockID in ipairs(departure.to) do
				candidates[#candidates + 1] = { kind = departure.kind, point = ns.DockPoint(dockID) }
			end
		end
	end
	return Ends(self:GetMap():GetMapID(), candidates)
end

DockPin.OnMouseClickAction = OpenEnds

-- The docks on this map with any route still shown, as { id, x, y } in map fractions. A lift or tram
-- landing also shows on any neighbouring zone it falls inside: the Great Lift joins the Barrens to Thousand
-- Needles, so it belongs on both.
local function MapDocks(mapID)
	local ids, docks = {}, {}
	for dockID in pairs(ns.Docks) do
		ids[#ids + 1] = dockID
	end
	table.sort(ids)
	for _, dockID in ipairs(ids) do
		local location = ns.DockLocation(dockID)
		if location and (ns.Docks[dockID].site or IsDockMap(location, mapID)) and ns.DockShown(dockID) then
			local x, y = MapPosition(ns.DockPoint(dockID), mapID)
			if x and y and not ns.CompanionMaps.Suppresses(ns.DockKind(dockID), x, y, "dock", dockID) then
				docks[#docks + 1] = { id = dockID, x = x, y = y }
			end
		end
	end
	return docks
end

-- Groups the points whose pins, `size` screen units across, would overlap on the map at its current zoom. Each group
-- lists its points in their given order, and the groups are ordered by their first point.
---@param map table
---@param points { x: number, y: number }[]
---@param size number
---@return table[][]
function ns.OverlapGroups(map, points, size)
	local canvas = map:GetCanvas()
	size = size * OVERLAP / map:GetCanvasScale()
	local reachX, reachY = size / canvas:GetWidth(), size / canvas:GetHeight()
	local root = {}
	local function Find(i)
		while root[i] ~= i do
			i = root[i]
		end
		return i
	end
	for i in ipairs(points) do
		root[i] = i
	end
	for i = 1, #points do
		for j = i + 1, #points do
			if math.abs(points[i].x - points[j].x) < reachX and math.abs(points[i].y - points[j].y) < reachY then
				root[Find(j)] = Find(i)
			end
		end
	end
	local byRoot, groups = {}, {}
	for i, point in ipairs(points) do
		local r = Find(i)
		if not byRoot[r] then
			byRoot[r] = {}
			groups[#groups + 1] = byRoot[r]
		end
		table.insert(byRoot[r], point)
	end
	return groups
end

-- Docks whose pins would overlap at this zoom share one pin, at their middle.
local function Clusters(map, docks)
	local zoom = Saturate(map:GetCanvasZoomPercent())
	local clusters = {}
	for i, group in ipairs(ns.OverlapGroups(map, docks, PIN_SIZE * map:GetGlobalPinScale() * Lerp(1, 1.2, zoom))) do
		clusters[i] = { docks = group }
	end
	for _, cluster in ipairs(clusters) do
		local x, y, ids = 0, 0, {}
		for _, dock in ipairs(cluster.docks) do
			x, y = x + dock.x, y + dock.y
			ids[#ids + 1] = dock.id
			local kind = ns.DockKind(dock.id)
			cluster.kinds = cluster.kinds or {}
			cluster.kinds[kind] = true
			cluster.kind = cluster.kind or kind
		end
		cluster.x, cluster.y = x / #cluster.docks, y / #cluster.docks
		cluster.key = table.concat(ids, ",")
	end
	return clusters
end

function Docks:RefreshAllData()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	ns.JourneyGuide.RefreshWaypointPins()
	local map = WorldMapFrame
	local mapID = map:GetMapID()
	-- A map never opened has no zoom levels yet; opening it redraws every layer anyway.
	if not (mapID and map:IsVisible()) then
		self:RemoveAllData()
		return
	end
	local clusters = Clusters(map, MapDocks(mapID))
	local wanted = {}
	for _, cluster in ipairs(clusters) do
		wanted[cluster.key] = cluster
	end
	-- Rebuild only when the set of pins changed (a new map, a zoom that merged or split docks, a filter), so a
	-- hovered pin keeps its tooltip through repeated canvas refreshes.
	local same = self.pins ~= nil and mapID == self.mapID
	for key, pin in pairs(self.pins or {}) do
		same = same and pin.cluster ~= nil and wanted[key] ~= nil
	end
	for key in pairs(wanted) do
		same = same and self.pins[key] ~= nil
	end
	self.mapID = mapID
	if same then
		for _, pin in pairs(self.pins) do
			if GameTooltip:IsOwned(pin) and GameTooltip:IsShown() then
				pin:RefreshTooltip()
			end
		end
		return
	end
	self:RemoveAllData()
	for _, cluster in ipairs(clusters) do
		local pin = dockPins:Acquire(cluster) --[[@as SPFDockPin]]
		self.pins[cluster.key] = pin
		for _, dock in ipairs(cluster.docks) do
			self.pinOf[dock.id] = pin
		end
	end
end

---@class SPFPortalPin : SPFCanvasPin
---@field Texture Texture
---@field HighlightTexture Texture
---@field portal table
local PortalPin = CreateFromMixins(MapCanvas.PinMixin)

function PortalPin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_GOSSIP")
	self:SetScalingLimits(1, 1, 1.2)
	self:SetSize(PIN_SIZE, PIN_SIZE)
	self.takesMouse = true
	-- Closing the map hides the pin without an OnMouseLeave.
	self:SetScript("OnHide", self.OnMouseLeave)
end

function PortalPin:OnAcquired(portal, x, y)
	self.portal = portal
	local scale = (ns.db.mapPinScale or 100) / 100
	self:SetScalingLimits(1, scale, scale * 1.2)
	ns.SetTransportIcon(self.Texture, "portal")
	ns.SetTransportIcon(self.HighlightTexture, "portal")
	self:SetPosition(x, y)
end

function ns.AddPortalTooltip(portal)
	local destination = ns.Locate(portal.to)
	GameTooltip_SetTitle(GameTooltip, portal.name)
	GameTooltip_AddNormalLine(
		GameTooltip,
		string.format(L["to %s"], destination and destination.zone or ns.Planner.PortalDestination(portal))
	)
end

function PortalPin:OnMouseEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	ns.AddPortalTooltip(self.portal)
	AddEndsLine(self:GetEnds())
	GameTooltip:Show()
end

function PortalPin:GetEnds()
	return Ends(self:GetMap():GetMapID(), { { kind = "portal", point = self.portal.to } })
end

PortalPin.OnMouseClickAction = OpenEnds

function PortalPin:OnMouseLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

-- Portals are faction-locked, unlike boats; the tram's entrances already show as tram pins.
function ns.PortalShown(portal)
	return portal.kind == "portal" and (not portal.faction or portal.faction == UnitFactionGroup("player"))
end

---@class SPFPortalLayer
---@field signature? string
local Portals = {}

function Portals:RemoveAllData()
	portalPins:ReleaseAll()
	self.signature = nil
end

function Portals:RefreshAllData()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	local mapID = WorldMapFrame:GetMapID()
	if not (mapID and ns.db.portals and WorldMapFrame:IsVisible()) then
		self:RemoveAllData()
		return
	end
	local signature = ns.CompanionMaps.Scan(WorldMapFrame)
		.. ":"
		.. mapID
		.. ":"
		.. tostring(ns.db.portals)
		.. ":"
		.. tostring(ns.db.otherFaction)
		.. ":"
		.. tostring(ns.db.mapPinScale)
	if self.signature == signature then
		return
	end
	self:RemoveAllData()
	self.signature = signature
	for portalID, portal in ipairs(ns.Portals) do
		local location = ns.PortalShown(portal) and ns.Locate(portal.from)
		if location and IsDockMap(location, mapID) then
			local x, y = MapPosition(portal.from, mapID)
			if x and y and not ns.CompanionMaps.Suppresses("portal", x, y, "portal", portalID * 2 - 1) then
				portalPins:Acquire(portal, x, y)
			end
		end
	end
end

-- Combat hides every pin of the addon's on the world map, and the minimap's, until it ends.
function ns.HideMapPins()
	MapCanvas.SetShown(WorldMapFrame, false)
end

function ns.ShowMapPins()
	MapCanvas.SetShown(WorldMapFrame, true)
end

function ns.RefreshMap()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	if dockPins then
		Docks:RemoveAllData()
		Docks:RefreshAllData()
		Portals:RefreshAllData()
		ns.RefreshFlightPins(true)
		ns.RefreshTransportRoutes()
	end
	ns.RefreshMinimapPins()
end

-- The world map's Map Filter ("Show:") menu gets the same switches as the settings panel.
local function AddFilters(_, rootDescription)
	rootDescription:CreateDivider()
	local function AddFilter(key, label)
		rootDescription:CreateCheckbox(label, function()
			return ns.db[key]
		end, function()
			ns.SetOption(key, not ns.db[key])
		end)
	end
	AddFilter("mapFlightMasters", L["Flight Masters"])
	AddFilter("mapRoutes", L["Boat and Zeppelin Routes"])
	AddFilter("pins", L["Boats & Zeppelins"])
	AddFilter("transit", L["Lifts & Tram"])
	AddFilter("portals", L["Portals"])
	AddFilter("otherFaction", L["Other Faction's Routes"])
end

ns.Init(function()
	local combat = CreateFrame("Frame")
	combat:RegisterEvent("PLAYER_REGEN_ENABLED")
	combat:RegisterEvent("PLAYER_REGEN_DISABLED")
	combat:SetScript("OnEvent", function()
		if InCombatLockdown() then
			ns.mapRefreshPending = true
			ns.HideMapPins()
			ns.HideMinimapPins()
		elseif ns.mapRefreshPending then
			ns.mapRefreshPending = nil
			ns.RefreshMap()
			ns.ShowMapPins()
		end
	end)
	function ns.QueueMapRefresh()
		ns.mapRefreshPending = true
	end
	dockPins = MapCanvas.Pool(WorldMapFrame, PIN_TEMPLATE, DockPin, { template = PIN_TEMPLATE, marker = "dock" })
	portalPins =
		MapCanvas.Pool(WorldMapFrame, PORTAL_TEMPLATE, PortalPin, { template = PORTAL_TEMPLATE, marker = "portal" })
	-- The map opening, turning to another map or zooming: what the stock map asked its data providers to redraw.
	MapCanvas.Watch(WorldMapFrame, function(_, what)
		if what == "show" or what == "map" then
			Docks:RefreshAllData()
			Portals:RefreshAllData()
			ns.RefreshFlightPins()
		elseif what == "scale" then
			-- Docks merge or split as the zoom changes.
			Docks:RefreshAllData()
		end
		-- A ping marks a place on the map it was set for: turning to another map or closing it leaves it.
		local ping = Docks.ping
		if ping and (what == "hide" or (what == "map" and WorldMapFrame:GetMapID() ~= Docks.pingMap)) then
			ping:Hide()
		end
	end)
	ns.ModifyMenu("MENU_WORLD_MAP_TRACKING", "map", AddFilters)
	ns.Timetable.OnChange(function()
		-- Sightings change countdowns, never the set of docks, portals, flights or route geometry.
		for _, pin in pairs(Docks.pins or {}) do
			if GameTooltip:IsOwned(pin) and GameTooltip:IsShown() then
				pin:RefreshTooltip()
			end
		end
	end)
	ns.RefreshMap()
end)
