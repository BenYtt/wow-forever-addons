---@class SPFNamespace
local ns = select(2, ...)

local MapCanvas = ns.MapCanvas
local LINE_TEMPLATE = "ShortestPathForeverRoutePinTemplate"
local GOAL_TEMPLATE = "ShortestPathForeverGoalPinTemplate"
local AREA_TEMPLATE = "ShortestPathForeverAreaPinTemplate"
-- The route's painters: the world map's pin and the minimap's frame copy Strokes.lua's strokes onto pooled lines,
-- each a core over a dark outline. RouteTransports.lua's pin paints the same way.
local Strokes = ns.Strokes
local DOT_TEXTURE = "Interface\\AddOns\\ShortestPathForever\\media\\Dot"
local UNDER_ALPHA = 0.5
-- RouteTransports.lua fades its outlines with the same share.
ns.RouteUnderAlpha = UNDER_ALPHA
-- StopPin.lua's marks. On the minimap a hollow ring circles the game's own icon at a stop with a known mark.
local GOAL_ATLAS, RING_ATLAS, STOP_SIZE = ns.GoalAtlas, "adventureguide-ring", ns.StopSize
local MINIMAP_GOAL, MINIMAP_RING = 16, 22
-- How strongly the goal's mark shows when it waits on the minimap's rim, off its face.
local EDGE_ALPHA = 0.6
local COLORS = {
	walk = NORMAL_FONT_COLOR,
	flight = CreateColor(0.2, 1, 0.35),
	boat = CreateColor(0, 0.75, 1),
	zeppelin = CreateColor(1, 0.35, 0.1),
	lift = ORANGE_FONT_COLOR,
	tram = ORANGE_FONT_COLOR,
	portal = CreateColor(0.85, 0.35, 1),
	passage = CreateColor(0.85, 0.35, 1),
	teleport = CreateColor(0.85, 0.35, 1),
}
local provider, goal, paths, worldPaths, stops, stopIndex
-- The route's pools on the world map (UI/MapCanvas.lua), made at load.
---@type SPFCanvasPool, SPFCanvasPool, SPFCanvasPool
local linePins, goalPins, areaPins
-- Whether this client has the blob widget QuestBlob.lua's pin is; nil until the first area is wanted.
---@type boolean?
local areaSupported
-- The journey's strokes are painted as soon as they are made, so the map pin and the minimap share one buffer.
local journeyStrokes = Strokes.New()
---@class SPFMinimapRoute : Frame
---@field lines Line[]
---@field underlines Line[]
---@field dots boolean[]
---@field used number
---@field Goal Texture
---@field strokeLayer SPFStrokeLayer
---@field elapsed number
---@field goalEdge? boolean the goal's mark waits on the rim, off the minimap
---@field idle number seconds the minimap has drawn nothing new
---@field ticker? FunctionContainer the slow poll while the every-frame update rests
---@field lastX? number
---@field lastY? number
---@field lastMap? number
---@field lastRadius? number
---@field lastFacing? number
---@field lastWidth? number
---@field lastHeight? number
---@field lastScale? number
---@field lastSquare? boolean
---@field revision? number
---@type SPFMinimapRoute
local minimap
local geometryRevision = 0
local loading = false

-- Each map's world corners: { continent, x and y at the top left, x and y at the bottom right }.
local corners = {}

local function Corners(mapID)
	if corners[mapID] == nil then
		local continent, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
		local other, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
		corners[mapID] = false
		if continent and continent == other and topLeft and bottomRight then
			local x0, y0 = topLeft:GetXY()
			local x1, y1 = bottomRight:GetXY()
			if x0 ~= x1 and y0 ~= y1 then
				corners[mapID] = { continent, x0, y0, x1, y1 }
			end
		end
	end
	return corners[mapID]
end

-- A world point on this map, in map fractions. Under OpenMap's stitched map the point is placed on the stitched
-- canvas instead, where 0..1 is the map the map frame is on and the view carries on past it into its neighbours, so
-- the whole journey draws and not only the part of it on the host map. Otherwise lines are clipped to the map, so a
-- point past its edge still counts: the client projects only points it places on the map, and the rest follow from
-- the map's corners.
local function MapPosition(point, mapID)
	local stitchedX, stitchedY = ns.OpenMap.Canvas(point)
	if stitchedX then
		return stitchedX, stitchedY
	end
	local uiMap, position = C_Map.GetMapPosFromWorldPos(point.map, CreateVector2D(point.x, point.y), mapID)
	if uiMap == mapID and position then
		return position:GetXY()
	end
	local map = Corners(mapID)
	if map and map[1] == point.map then
		-- World x runs north and y west, so the map's x follows world y and its y follows world x.
		return (point.y - map[3]) / (map[5] - map[3]), (point.x - map[2]) / (map[4] - map[2])
	end
end

-- Whether a MapPosition result is on the map as drawn: always over OpenMap's stitched map, whose view runs past the
-- host map's rectangle, and otherwise only inside it.
---@param x number?
---@param y number?
---@return boolean
local function OnMap(x, y)
	return x ~= nil and (ns.OpenMap.Stitched() or (x >= 0 and x <= 1 and y >= 0 and y <= 1))
end
-- The journey's own placements, for the specs: the map's fractions, or the stitched canvas's.
ns.JourneyMapPosition = MapPosition

-- What Strokes.lua draws through, refilled for each drawing rather than rebuilt.
---@type SPFMapView
local mapView = {
	mapID = 0,
	position = MapPosition,
	width = 0,
	height = 0,
	scale = 1,
	zoom = 1,
	small = false,
	current = 0,
	colors = COLORS,
}
---@type SPFMinimapView
local minimapView = { width = 0, height = 0, scale = 1, goalRadius = 0, colors = COLORS }

-- Pooled lines swap between a flat colour and the dot texture only when their use changes.
local function Texture(owner, index, dot)
	if owner.dots[index] == dot then
		return
	end
	owner.dots[index] = dot
	local line, underline = owner.lines[index], owner.underlines[index]
	if dot then
		line:SetTexture(DOT_TEXTURE) -- art-ok: a route line segment, its dots along a Line
		underline:SetTexture(DOT_TEXTURE) -- art-ok: the same segment's dark underline
		underline:SetVertexColor(0.04, 0.04, 0.04)
	else
		line:SetColorTexture(1, 1, 1, 1)
		underline:SetColorTexture(0.04, 0.04, 0.04, 1)
		underline:SetVertexColor(1, 1, 1)
	end
end

local function StopPulse(layer)
	layer.animation:Stop()
	layer:SetAlpha(1)
end

local function Pulse(owner)
	local layer = owner.strokeLayer
	if not layer then
		return
	end
	if loading and owner.used > 0 and owner:IsVisible() then
		if not layer.animation:IsPlaying() then
			layer.animation:Play()
		end
	else
		StopPulse(layer)
	end
end

-- Each stroke on its own pooled pair of lines, the outline under the core; pairs left over are hidden.
---@param owner SPFRoutePin|SPFMinimapRoute
---@param strokes SPFStrokes
local function Paint(owner, strokes)
	local lines, underlines = owner.lines, owner.underlines
	for index = 1, strokes.n do
		local line, underline = lines[index], underlines[index]
		if not line then
			local layer = owner.strokeLayer or owner
			underline = layer:CreateLine(nil, "ARTWORK", nil, -1)
			underline:SetColorTexture(0.04, 0.04, 0.04, 1)
			line = layer:CreateLine(nil, "ARTWORK")
			lines[index], underlines[index] = line, underline
		end
		Texture(owner, index, strokes.dot[index])
		local x1, y1, x2, y2 = strokes.x1[index], strokes.y1[index], strokes.x2[index], strokes.y2[index]
		local ux, uy, alpha = strokes.ux[index], strokes.uy[index], strokes.alpha[index]
		underline:SetAlpha(alpha * UNDER_ALPHA)
		underline:SetThickness(strokes.under[index])
		underline:SetStartPoint("TOPLEFT", owner, x1 - ux, y1 - uy)
		underline:SetEndPoint("TOPLEFT", owner, x2 + ux, y2 + uy)
		underline:Show()
		line:SetVertexColor(strokes.color[index]:GetRGBA())
		line:SetAlpha(alpha)
		line:SetThickness(strokes.width[index])
		line:SetStartPoint("TOPLEFT", owner, x1, y1)
		line:SetEndPoint("TOPLEFT", owner, x2, y2)
		line:Show()
	end
	for index = strokes.n + 1, #lines do
		lines[index]:Hide()
		underlines[index]:Hide()
	end
	owner.used = strokes.n
	Pulse(owner)
end

-- One loading animation covers all strokes and outlines.
local function StrokeLayer(owner)
	---@class SPFStrokeLayer : Frame
	local layer = CreateFrame("Frame", nil, owner)
	owner.strokeLayer = layer
	layer:SetAllPoints(owner)
	layer:EnableMouse(false)
	local animation = layer:CreateAnimationGroup()
	animation:SetLooping("BOUNCE")
	local alpha = animation:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0.8)
	alpha:SetToAlpha(0.35)
	alpha:SetDuration(0.6)
	alpha:SetSmoothing("IN_OUT")
	layer.animation = animation
	layer:SetScript("OnShow", function()
		Pulse(owner)
	end)
	layer:SetScript("OnHide", StopPulse)
end

-- JourneyInfo's loading flag drives both the header spinner and the route, even when geometry is kept.
---@param shown boolean
function ns.RefreshJourneyPulse(shown)
	if loading == shown then
		return
	end
	loading = shown
	if linePins then
		for pin in linePins:EnumerateActive() do
			---@cast pin SPFRoutePin
			Pulse(pin)
		end
	end
	if minimap then
		Pulse(minimap)
	end
end

-- One frame the size of the canvas that grows with the terrain (no scaling limits, the pin scale ignored), holding
-- the route's strokes.
---@class SPFRoutePin : SPFCanvasPin
---@field lines Line[]
---@field underlines Line[]
---@field dots boolean[]
---@field used number
---@field paths? SPFDrawPath[]
---@field drawMap? number
---@field drawWidth? number
---@field drawHeight? number
---@field drawScale? number
---@field strokeLayer? SPFStrokeLayer
---@field strokes? SPFStrokes -- a pin that keeps its strokes between draws (RouteTransports.lua) has its own buffer
---@field UpdateAlpha? fun(self: SPFRoutePin)
local RoutePin = CreateFromMixins(MapCanvas.PinMixin)
ns.RoutePinMixin = RoutePin

function RoutePin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_QUEST_BLOB")
	self:SetIgnoreGlobalPinScale(true)
	self.lines, self.underlines, self.dots, self.used = {}, {}, {}, 0
end

function RoutePin:Draw()
	local map = self:GetMap()
	local canvas = map:GetCanvas()
	self.drawMap, self.drawWidth, self.drawHeight, self.drawScale =
		map:GetMapID(), canvas:GetWidth(), canvas:GetHeight(), self:GetEffectiveScale()
	self:SetSize(canvas:GetWidth(), canvas:GetHeight())
	self:SetPosition(0.5, 0.5)
	local info = C_Map.GetMapInfo(map:GetMapID())
	local journey = self.paths == worldPaths
	mapView.mapID = map:GetMapID()
	mapView.width, mapView.height, mapView.scale = self:GetWidth(), self:GetHeight(), self:GetEffectiveScale()
	mapView.zoom, mapView.small = map:GetCanvasScale(), info and info.mapType <= Enum.UIMapType.Continent
	mapView.stitched = ns.OpenMap.Stitched()
	mapView.marks = journey and provider and provider.stopMarks or nil
	-- The journey's own paths come first; the later hops Itinerary.lua adds after them recede.
	mapView.current = journey and #paths or math.huge
	local strokes = self.strokes or journeyStrokes
	Strokes.Map(strokes, self.paths, mapView)
	Paint(self, strokes)
	if self.strokes then
		self:UpdateAlpha()
	end
end

function RoutePin:OnReleased()
	if self.strokeLayer then
		StopPulse(self.strokeLayer)
	end
	-- Released journey pins must not keep the last route alive through the pool.
	self.paths = nil
end

---@param geometry SPFDrawPath[]
function RoutePin:OnAcquired(geometry)
	if not self.strokes and not self.strokeLayer then
		StrokeLayer(self)
	end
	local same = self.strokes and self.paths and #self.paths == #geometry
	if same then
		for i, path in ipairs(geometry) do
			if self.paths[i] ~= path then
				same = false
				break
			end
		end
	end
	self.paths = geometry
	local map, canvas = self:GetMap(), self:GetMap():GetCanvas()
	local width, height, scale = canvas:GetWidth(), canvas:GetHeight(), self:GetEffectiveScale()
	if
		same
		and self.drawMap == map:GetMapID()
		and self.drawWidth == width
		and self.drawHeight == height
		and self.drawScale == scale
	then
		-- The pool clears anchors on release, even when the strokes remain reusable.
		self:SetPosition(0.5, 0.5)
		self:UpdateAlpha()
		return
	end
	self:Draw()
end

function RoutePin:OnCanvasScaleChanged()
	self:Draw()
end

function RoutePin:OnCanvasSizeChanged()
	self:Draw()
end

-- Standing in the area of a quest the held stop names, on a map that shows it: the game's own area is drawn there
-- in the stop's place. The client's own conditions hold (QuestBlobPinMixin:Refresh): quest objectives are shown,
-- and the map is a zone or smaller (MapUtil.ShouldMapTypeShowQuests). A client without the widget draws none.
---@param map SPFMapCanvas
---@return boolean
local function DrawArea(map)
	local mapID = map:GetMapID()
	if areaSupported == false or goal.corpse or not ns.StopInQuestArea(goal) or not GetCVarBool("questPOI") then
		return false
	end
	local x, y = MapPosition(goal, mapID)
	local info = C_Map.GetMapInfo(mapID)
	if not (x and x >= 0 and x <= 1 and y >= 0 and y <= 1 and info and info.mapType > Enum.UIMapType.Continent) then
		return false
	end
	if areaSupported == nil then
		areaSupported = C_XMLUtil.GetTemplateInfo(AREA_TEMPLATE) ~= nil
		if not areaSupported then
			return false
		end
	end
	local pin = areaPins:Acquire(goal.questIDs) --[[@as SPFAreaPin]]
	if not pin.blob then
		areaPins:ReleaseAll()
		areaSupported = false
	end
	return areaSupported
end

-- The journey's layer on the world map: the line, the stops' buttons and the quest area.
---@class SPFRouteLayer
---@field stopsKey? string
---@field stopMarks? {x: number, y: number, radius: number}[]
---@field area? boolean
local Layer = {}

function Layer:RemoveAllData()
	linePins:ReleaseAll()
	goalPins:ReleaseAll()
	areaPins:ReleaseAll()
	self.stopsKey, self.stopMarks, self.area = nil, nil, nil
end

function Layer:RefreshAllData()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	self:RemoveAllData()
	local map = WorldMapFrame
	-- Before the map's first show its zoom levels are unset.
	if not (map:GetMapID() and map:IsVisible() and goal and (ns.db.journey or goal.corpse)) then
		return
	end
	-- The area replaces the stop and the line to it. Another zone the player browses keeps its own stops.
	self.area = DrawArea(map)
	if self.area then
		return
	end
	-- The stops go first: the line leaves a gap at each.
	self:RefreshStops()
	if #worldPaths > 0 then
		linePins:Acquire(worldPaths)
	end
end

-- Stops whose buttons would overlap at this zoom share one, as the map's docks do: at their middle, faded, or at the
-- stop being guided to and at full strength when it is among them. The buttons are rebuilt only when that grouping
-- changes, and the line redrawn around them.
function Layer:RefreshStops()
	local map = WorldMapFrame
	local mapID = map:GetMapID()
	-- The game's own tombstone marks your corpse.
	if not (mapID and map:IsVisible() and ns.db.journey and goal) or goal.corpse then
		return
	end
	local first, marks = stopIndex or 1, {}
	for index = first, stops and #stops or 1 do
		local point = stops and stops[index] or goal
		local x, y = MapPosition(point, mapID)
		if OnMap(x, y) then
			marks[#marks + 1] = {
				x = x,
				y = y,
				index = index,
				title = point.routeTitle,
				detail = point.tooltip,
				look = point.look,
				pinBadge = point.pinBadge,
			}
		end
	end
	-- Groups keep their marks in order, so the current stop leads its group.
	local groups, keys = ns.OverlapGroups(map, marks, STOP_SIZE), { mapID }
	for _, group in ipairs(groups) do
		for _, mark in ipairs(group) do
			keys[#keys + 1] = mark.index
		end
		keys[#keys + 1] = 0 -- between groups; stops count from 1
	end
	local key = table.concat(keys, ",")
	if key == self.stopsKey then
		return
	end
	self.stopsKey = key
	goalPins:ReleaseAll()
	self.stopMarks = {}
	for _, group in ipairs(groups) do
		local x, y, numbers, titles, details = 0, 0, {}, {}, {}
		for i, mark in ipairs(group) do
			x, y, numbers[i], titles[i] = x + mark.x, y + mark.y, mark.index, mark.title
			if mark.detail then
				details[#details + 1] = mark.detail
			end
		end
		local lead = group[1]
		-- A shared button stands for several places, so only a stop on its own wears its badge.
		local look = #group == 1 and lead.look or nil
		local later, numbered = lead.index ~= first, numbers
		if later then
			x, y = x / #group, y / #group
		else
			x, y, numbered = lead.x, lead.y, stops and numbers
		end
		local pin = goalPins:Acquire(x, y, numbered, titles, later, look, details, lead.pinBadge)
		self.stopMarks[#self.stopMarks + 1] = { x = x, y = y, radius = pin:GetWidth() / 2 }
	end
	for pin in linePins:EnumerateActive() do
		---@cast pin SPFRoutePin
		pin:Draw()
	end
end

function Layer:OnCanvasScaleChanged()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	-- The area pin redraws itself; there are no stops to regroup.
	if self.area then
		return
	end
	self:RefreshStops()
end

-- The minimap's view radius in yards, and how far it is turned from north-up.
local function MinimapView()
	-- Blizzard_APIDocumentationGenerated/MinimapDocumentation.lua:127 (yards).
	local radius = C_Minimap.GetViewRadius()
	if GetCVar("rotateMinimap") == "1" then
		return radius, GetPlayerFacing()
	end
	return radius, 0
end

-- The minimap's transport pins look through the same view.
ns.MinimapView = MinimapView

-- The world point under the cursor on the minimap, undoing Strokes.Project; nil off its face.
function ns.MinimapPoint()
	local x, y, _, map = ns.JourneyPosition()
	---@type number?, number?
	local radius, facing = MinimapView()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = Minimap:GetCenter()
	local mx, my = GetCursorPosition()
	local u, v = (mx / scale - cx) / (Minimap:GetWidth() / 2), (my / scale - cy) / (Minimap:GetHeight() / 2)
	if not (x and canaccessvalue(radius) and canaccessvalue(facing) and radius and facing) or u * u + v * v > 1 then
		return nil
	end
	local cosine, sine = math.cos(facing), math.sin(facing)
	local east, north = radius * (u * cosine - v * sine), radius * (u * sine + v * cosine)
	return { map = map, x = x + north, y = y - east }
end

---@param self SPFMinimapRoute
local function DrawMinimap(self)
	local x, y, _, map = ns.JourneyPosition()
	---@type number?, number?
	local radius, facing = MinimapView()
	if not (canaccessvalue(radius) and canaccessvalue(facing)) then
		radius, facing = nil, nil
	end
	local width, height = self:GetWidth(), self:GetHeight()
	local scale = self:GetEffectiveScale()
	-- GetMinimapShape is an optional addon convention (HBD-Pins:215), not a Blizzard global.
	local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
	if
		self.lastX == x
		and self.lastY == y
		and self.lastMap == map
		and self.lastRadius == radius
		and self.lastFacing == facing
		and self.lastWidth == width
		and self.lastHeight == height
		and self.lastScale == scale
		and self.lastSquare == square
		and self.revision == geometryRevision
	then
		return false
	end
	self.lastX, self.lastY, self.lastMap, self.lastRadius, self.lastFacing = x, y, map, radius, facing
	self.lastWidth, self.lastHeight, self.lastScale, self.lastSquare = width, height, scale, square
	self.revision = geometryRevision
	self.Goal:Hide()
	local view = minimapView
	view.x, view.y, view.map, view.radius, view.facing = x, y, map, radius, facing
	view.width, view.height, view.scale, view.square = width, height, scale, square
	-- Standing in the area of a quest the held stop names: the game's own blob wears the guide's gold there, and the
	-- stop's ring and the line to it step aside. A stop with no quest has no blob, so it keeps its ring and line.
	local area = goal ~= nil and not goal.corpse and ns.StopInQuestArea(goal)
	ns.SetAreaBlob(area)
	-- A goal with a known mark wears the wider ring (ns.SetJourneyRoute).
	view.goal, view.goalRadius = not area and goal or nil, (goal and goal.look and MINIMAP_RING or MINIMAP_GOAL) / 2
	local gx, gy, edge = Strokes.Minimap(journeyStrokes, area and {} or paths, view)
	if gx then
		self.Goal:SetPoint("CENTER", self, "CENTER", gx * width / 2, gy * height / 2)
		-- Off the minimap it only shows the way, a little faded, as the game's own tracked pin is at the minimap's
		-- edge, and always as the goal pin: a ring for a known mark would circle nothing there.
		self.Goal:SetAlpha(edge and EDGE_ALPHA or 1)
		if (edge or false) ~= (self.goalEdge or false) then
			self.goalEdge = edge
			local ringed = not edge and goal and goal.look ~= nil
			local size = ringed and MINIMAP_RING or MINIMAP_GOAL
			ns.Art.Fit(self.Goal, ringed and RING_ATLAS or GOAL_ATLAS, size, size)
		end
		self.Goal:Show()
	end
	Paint(self, journeyStrokes)
	return true
end

-- The minimap redraws ten times a second while you move or turn or its zoom changes. Once nothing has changed for a
-- second it drops its every-frame script, and a quarter-second poll wakes it: a mouse turn, a boat or a flight moves
-- the minimap with no event to say so.
local REDRAW_EVERY, POLL_EVERY, REST_AFTER = 0.1, 0.25, 1
local UpdateMinimap

---@param self SPFMinimapRoute
local function WakeMinimap(self)
	self.idle = 0
	if not self:GetScript("OnUpdate") then
		self.elapsed = 0
		self:SetScript("OnUpdate", UpdateMinimap)
	end
end

---@param self SPFMinimapRoute
---@param elapsed number
UpdateMinimap = function(self, elapsed)
	if not (goal and (ns.db.journey or goal.corpse)) then
		self.Goal:Hide()
		self:Hide()
		return
	end
	self.elapsed = self.elapsed + elapsed
	if self.elapsed < REDRAW_EVERY then
		return
	end
	local step = self.elapsed
	self.elapsed = 0
	if DrawMinimap(self) then
		self.idle = 0
	else
		self.idle = self.idle + step
		if self.idle >= REST_AFTER then
			self:SetScript("OnUpdate", nil)
		end
	end
end

local function PollMinimap()
	local self = minimap
	if not self or self:GetScript("OnUpdate") then
		return
	end
	if not (goal and (ns.db.journey or goal.corpse)) then
		self.Goal:Hide()
		self:Hide()
	elseif DrawMinimap(self) then
		WakeMinimap(self)
	end
end

-- The world map adds the later hops as Itinerary.lua plans them; the minimap guides along the current leg only.
local function WorldPaths()
	worldPaths = paths
	if stops then
		worldPaths = {}
		for _, path in ipairs(paths) do
			worldPaths[#worldPaths + 1] = path
		end
		for _, path in ipairs(ns.JourneyPreview()) do
			worldPaths[#worldPaths + 1] = path
		end
	end
end

-- A later hop, or one of its walks, finished planning; only the world map draws the itinerary.
function ns.RefreshJourneyPreview()
	if not stops then
		return
	end
	WorldPaths()
	if provider and WorldMapFrame:IsShown() then
		provider:RefreshAllData()
	end
end

---@param destination SPFPoint?
---@param route SPFPlan?
function ns.SetJourneyRoute(destination, route)
	goal = destination
	geometryRevision = geometryRevision + 1
	paths = {}
	for _, leg in ipairs(route and route.legs or {}) do
		paths[#paths + 1] = {
			mode = leg.mode,
			color = leg.color,
			points = ns.Planner.LegPoints(leg, ns.Routes),
		}
	end
	stops, stopIndex = nil, nil
	if destination and not destination.corpse and ns.JourneyStops then
		stops, stopIndex = ns.JourneyStops()
	end
	WorldPaths()
	-- The map refreshes every provider when it opens, so a closed one is left until then.
	if provider and (WorldMapFrame:IsShown() or not destination) then
		provider:RefreshAllData()
	end
	if minimap then
		-- Addon textures draw over the minimap's own icons, so a stop with a known mark (a "?", a flight master) is only
		-- circled there: the game's icon shows through the ring.
		local ringed = destination and destination.look ~= nil
		local size = ringed and MINIMAP_RING or MINIMAP_GOAL
		ns.Art.Fit(minimap.Goal, ringed and RING_ATLAS or GOAL_ATLAS, size, size)
		minimap.goalEdge = nil
		if destination then
			minimap:Show()
			DrawMinimap(minimap)
			WakeMinimap(minimap)
		else
			minimap.Goal:Hide()
			minimap:Hide()
			ns.SetAreaBlob(false)
		end
	end
end

ns.Init(function()
	linePins = MapCanvas.Pool(WorldMapFrame, LINE_TEMPLATE, RoutePin)
	goalPins =
		MapCanvas.Pool(WorldMapFrame, GOAL_TEMPLATE, ns.GoalPinMixin, { template = GOAL_TEMPLATE, marker = "stop" })
	areaPins = MapCanvas.Pool(
		WorldMapFrame,
		AREA_TEMPLATE,
		ns.AreaPinMixin,
		{ frameType = "QuestPOIFrame", template = AREA_TEMPLATE }
	)
	provider = Layer
	MapCanvas.Watch(WorldMapFrame, function(_, what)
		if what == "show" or what == "map" then
			provider:RefreshAllData()
		elseif what == "scale" then
			provider:OnCanvasScaleChanged()
		end
	end)
	local minimapRoute = CreateFrame("Frame", "ShortestPathForeverMinimapRoute", Minimap)
	---@cast minimapRoute SPFMinimapRoute
	minimap = minimapRoute
	minimap:SetAllPoints(Minimap)
	minimap:EnableMouse(false)
	minimap.lines, minimap.underlines, minimap.dots, minimap.used = {}, {}, {}, 0
	minimap.elapsed, minimap.idle = 0, 0
	StrokeLayer(minimap)
	minimap.Goal = Minimap:CreateTexture(nil, "OVERLAY")
	ns.Art.Fit(minimap.Goal, GOAL_ATLAS, MINIMAP_GOAL, MINIMAP_GOAL)
	minimap.Goal:Hide()
	-- The client's own "inside the quest's area" state, the one it paints the blob from, drives the tint at once.
	minimap:RegisterEvent("PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED")
	minimap:SetScript("OnEvent", function(self, event)
		if not goal then
			return
		end
		if event ~= "PLAYER_INSIDE_QUEST_BLOB_STATE_CHANGED" then
			WakeMinimap(self)
			return
		end
		self.revision = nil
		DrawMinimap(self)
		if WorldMapFrame:IsShown() then
			provider:RefreshAllData()
		end
	end)
	-- While shown: the poll, and moving, turning or zooming the minimap wake the every-frame redraw.
	minimap:SetScript("OnShow", function(self)
		if self.ticker then
			self.ticker:Cancel()
		end
		self.ticker = C_Timer.NewTicker(POLL_EVERY, PollMinimap)
		self:RegisterEvent("PLAYER_STARTED_MOVING")
		self:RegisterEvent("PLAYER_STARTED_TURNING")
		self:RegisterEvent("MINIMAP_UPDATE_ZOOM")
		WakeMinimap(self)
	end)
	minimap:SetScript("OnHide", function(self)
		if self.ticker then
			self.ticker:Cancel()
			self.ticker = nil
		end
		self:UnregisterEvent("PLAYER_STARTED_MOVING")
		self:UnregisterEvent("PLAYER_STARTED_TURNING")
		self:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
		self:SetScript("OnUpdate", nil)
	end)
	minimap:Hide()
end)
