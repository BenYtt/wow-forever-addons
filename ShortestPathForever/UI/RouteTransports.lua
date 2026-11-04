---@class SPFNamespace
local ns = select(2, ...)

-- Boat and zeppelin routes on the world map, drawn by Route.lua's painter and shown while their dock is hovered.
local TRANSPORT_TEMPLATE = "ShortestPathForeverTransportPinTemplate"
local UNDER_ALPHA = ns.RouteUnderAlpha
local transportProvider, dockHover, highlightedRoutes
---@type SPFCanvasPool
local transportPins

-- One mouse-transparent canvas pin holds every boat and zeppelin route, each hidden until its dock is hovered.
---@class SPFTransportPin : SPFRoutePin
local TransportPin = CreateFromMixins(ns.RoutePinMixin)

function TransportPin:OnLoad()
	ns.RoutePinMixin.OnLoad(self)
	self:UseFrameLevelType("PIN_FRAME_LEVEL_FOG_OF_WAR")
	-- Its strokes outlive the draw: hovering a dock shows and hides them by route.
	self.strokes = ns.Strokes.New()
end

function TransportPin:UpdateAlpha()
	local strokes = self.strokes
	for index = 1, strokes.n do
		local alpha = highlightedRoutes and highlightedRoutes[strokes.route[index]] and 1 or 0
		self.lines[index]:SetAlpha(alpha * strokes.alpha[index])
		self.underlines[index]:SetAlpha(alpha * strokes.alpha[index] * UNDER_ALPHA)
	end
end

---@param owner SPFCanvasPin
---@param routes table<number, boolean>?
function ns.HoverTransportRoutes(owner, routes)
	if not routes and dockHover ~= owner then
		return
	end
	dockHover, highlightedRoutes = routes and owner or nil, routes
	-- Looked up rather than cached: a pin hidden with the map stays active and is not always re-acquired.
	if transportPins then
		for pin in transportPins:EnumerateActive() do
			---@cast pin SPFTransportPin
			pin:UpdateAlpha()
		end
	end
end

-- Kept strokes and paths survive a release, so the next draw of the same routes reuses them.
function TransportPin.OnReleased() end

-- The routes' layer on the world map.
---@class SPFTransportLayer
---@field signature? string
local Transports = {}
local transportGeometry = {}
local geometryRoutes, geometryDocks

function Transports.RemoveAllData()
	transportPins:ReleaseAll()
end

function Transports:RefreshAllData()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	local map = WorldMapFrame
	local mapID = map:GetMapID()
	if not (ns.db.mapRoutes and mapID and map:IsVisible()) then
		self:RemoveAllData()
		self.signature = nil
		return
	end
	local signature = mapID .. ":" .. tostring(ns.db.mapRoutes) .. ":" .. tostring(ns.db.otherFaction)
	if self.signature == signature then
		return
	end
	self:RemoveAllData()
	self.signature = signature
	if geometryRoutes ~= ns.Routes or geometryDocks ~= ns.Docks then
		transportGeometry, geometryRoutes, geometryDocks = {}, ns.Routes, ns.Docks
	end
	local geometry = {}
	local ids = {}
	for id, route in pairs(ns.Routes) do
		if (route.kind == "boat" or route.kind == "zeppelin") and ns.RouteShown(route) then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local route = ns.Routes[id]
		local cached = transportGeometry[id]
		if not cached or cached.route ~= route then
			cached = { route = route, paths = {} }
			transportGeometry[id] = cached
			-- Dock-to-dock legs preserve intermediate calls and give overview maps the actual crossing endpoints.
			for index, stop in ipairs(route.stops) do
				local onward = route.stops[index % #route.stops + 1]
				local leg = {
					mode = route.kind,
					route = id,
					from = ns.Docks[stop.dock],
					to = ns.Docks[onward.dock],
					boarding = stop,
					alighting = onward,
				}
				cached.paths[#cached.paths + 1] =
					{ mode = route.kind, route = id, points = ns.Planner.LegPoints(leg, ns.Routes) }
			end
		end
		for _, path in ipairs(cached.paths) do
			geometry[#geometry + 1] = path
		end
	end
	transportPins:Acquire(geometry)
end

function ns.RefreshTransportRoutes()
	if transportProvider then
		transportProvider:RefreshAllData()
	end
end

ns.Init(function()
	transportPins = ns.MapCanvas.Pool(WorldMapFrame, TRANSPORT_TEMPLATE, TransportPin)
	transportProvider = Transports
	ns.MapCanvas.Watch(WorldMapFrame, function(_, what)
		if what == "show" or what == "map" then
			transportProvider:RefreshAllData()
		end
	end)
end)
