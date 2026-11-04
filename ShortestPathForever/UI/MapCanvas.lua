---@class SPFNamespace
local ns = select(2, ...)

-- The addon's drawings on the world map (#158), on frames of its own and with nothing written into the map.
--
-- Forever's gamepad interface runs the map's Lua from secure code. Each frame MapCanvasMixin:UpdateGamepadCursor walks
-- every pin in map.pinPools (ExecuteOnAllPins), enters the ones under the cursor and keeps them in
-- map.currentPoIPins; closing the map leaves each of them again (MapCanvasMixin:OnHide). A data provider the addon
-- adds sits in map.dataProviders, and a pin it acquires puts the addon's template, pool and frame in map.pinPools, so
-- that secure walk ran through the addon's values and tainted, and the gamepad action bar's later protected call
-- (SetPreferredGamepadInteractTarget) was blocked. So the addon adds no data provider, acquires no pin, and calls no
-- map method that writes. It only reads the map, through
--   map:GetMapID(), map:GetCanvas(), map:GetCanvasScale(), map:GetCanvasZoomPercent(), map:GetGlobalPinScale(),
--   map:IsVisible() and map:GetPinFrameLevelsManager():GetValidFrameLevel(type, index)
-- (each returns a field or works one out from fields; Blizzard_MapCanvas.lua, MapCanvas_PinFrameLevelsManager.lua),
-- plus the canvas's size and the gamepad's SoftCursor rect. tests/map_canvas_spec.lua runs the addon against a map
-- that fails on any write.
--
-- One view per map: a frame of the addon's set on the canvas (the client parents it, in C: the scroll frame clips it
-- and it shows and hides with the map), made with no parent and then moved there, since the gamepad interface follows
-- frames created inside an open window. Its OnUpdate runs only while the map is shown (a hidden frame gets none) and
-- compares a handful of reads each frame, telling its listeners what changed:
--   "show"  the map opened          "map"   another map is shown       "size"  the canvas was resized
--   "scale" the zoom or pin scale   "hide"  the map closed
-- The pins live on a layer under that frame, so combat can hide them all at once.
--
-- Pins are plain frames that take the mouse with OnEnter and OnLeave only: the gamepad interface reads a frame with a
-- click script (OnClick, OnMouseDown, OnMouseUp) as a button of the window it scans. A click is the press and release
-- of a button over the hovered pin, seen through GLOBAL_MOUSE_DOWN and GLOBAL_MOUSE_UP on a frame of the addon's. A
-- pin passes the right button through to the canvas (zoom out) unless it says otherwise, as the map's own pins do.
-- Under the gamepad interface a pin within reach of the map cursor shows its tooltip, as the map's own pins do; its
-- clicks stay with the mouse.

local MapCanvas = {}
ns.MapCanvas = MapCanvas

-- How close the gamepad's map cursor comes to a pin to hover it, as the map's own pins (MIN_PIN_DISTANCE_SQUARED).
local CURSOR_REACH = 12

---@class SPFCanvasView
---@field map SPFMapCanvas
---@field canvas Frame
---@field host Frame
---@field layer Frame
---@field shown boolean
---@field mapID? number
---@field width number
---@field height number
---@field scale number
---@field zoom number
---@field pinScale number
---@field stitched boolean
---@field companionLayers? string
---@field gamepad boolean
---@field listeners fun(view: SPFCanvasView, what: string)[]
---@field pools table<string, SPFCanvasPool>
local View = {}
View.__index = View

---@type table<SPFMapCanvas, SPFCanvasView>
local views = {}
---@type SPFCanvasPin?, SPFCanvasPin?, string?
local hovered, pressed, pressedButton
-- Whether the gamepad's map cursor, not the mouse, is hovering `hovered`.
local hoveredByCursor = false
---@type (fun(pin: SPFCanvasPin, button: string): boolean?)[]
local clickFilters = {}
local clicks

-- The frame level the map gives pins of this type, as MapCanvasPinMixin:ApplyFrameLevel asks for it.
---@param levelType? string
---@param index? number
---@return number
function View:Level(levelType, index)
	local map = self.map
	local levels = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
	local level = levelType and levels and levels.GetValidFrameLevel and levels:GetValidFrameLevel(levelType, index)
	level = level or self.canvas:GetFrameLevel() + 1
	-- OpenMap's stitched art reaches over Blizzard's pin levels: over the stitched map a pin has to be above it to show.
	local art = ns.OpenMap.TopLevel()
	if art and level <= art then
		level = art + 1
	end
	return level
end

-- What the map shows now; every call a read. A map never opened has no zoom levels, so its scale is read only while
-- it is visible.
---@param view SPFCanvasView
local function Read(view)
	local map, canvas = view.map, view.canvas
	local scale = map:GetCanvasScale()
	if not scale or scale <= 0 then
		scale = 1
	end
	return map:GetMapID(),
		canvas:GetWidth() or 0,
		canvas:GetHeight() or 0,
		scale,
		Saturate(map:GetCanvasZoomPercent() or 0),
		map:GetGlobalPinScale() or 1,
		ns.OpenMap.Stitched()
end

---@param view SPFCanvasView
---@param what string
---@param sized? boolean the canvas size changed since the last frame
---@param scaled? boolean the zoom or pin scale changed since the last frame
local function Fire(view, what, sized, scaled)
	-- Pins kept from before (a map shown again, a ping set on the map being turned to) follow the view first, and
	-- hear of a size or zoom that changed while the map was hidden or turned.
	if what ~= "hide" then
		for _, pool in pairs(view.pools) do
			for pin in pool:EnumerateActive() do
				pin:ApplyScale()
				pin:ApplyPosition()
				if sized then
					pin:OnCanvasSizeChanged()
				end
				if scaled then
					pin:OnCanvasScaleChanged()
				end
			end
		end
	end
	for _, listener in ipairs(view.listeners) do
		ns.SafeCall("map canvas " .. what, listener, view, what)
	end
end

---@param pin SPFCanvasPin?
local function SetHovered(pin)
	if hovered == pin then
		return
	end
	local previous = hovered
	hovered = pin
	if previous then
		if previous.SetHighlightLocked then
			previous:SetHighlightLocked(false)
		end
		previous:OnMouseLeave()
	end
	if pin then
		if pin.SetHighlightLocked then
			pin:SetHighlightLocked(true)
		end
		pin:OnMouseEnter()
	end
end

-- The pin nearest the gamepad's map cursor, within reach, among the ones that take the mouse.
---@param view SPFCanvasView
---@return SPFCanvasPin?
local function PinAtCursor(view)
	local cursor = SoftCursor
	if not (cursor and cursor:IsShown()) then
		return nil
	end
	local left, bottom, width, height = cursor:GetRect()
	if not left then
		return nil
	end
	local cursorScale = cursor:GetEffectiveScale()
	local cx, cy = (left + width / 2) * cursorScale, (bottom + height / 2) * cursorScale
	local reach = CURSOR_REACH * cursorScale
	local best, bestDistance = nil, reach * reach
	for _, pool in pairs(view.pools) do
		for pin in pool:EnumerateActive() do
			if pin.takesMouse and pin:IsVisible() then
				local x, y = pin:GetCenter()
				if x then
					local scale = pin:GetEffectiveScale()
					local dx, dy = x * scale - cx, y * scale - cy
					local distance = dx * dx + dy * dy
					if distance <= bestDistance then
						best, bestDistance = pin, distance
					end
				end
			end
		end
	end
	return best
end

local Hide

---@param view SPFCanvasView
local function Update(view)
	if not view.map:IsVisible() then
		Hide(view)
		return
	end
	local mapID, width, height, scale, zoom, pinScale, stitched = Read(view)
	local first, changedMap = not view.shown, mapID ~= view.mapID
	local stitchedChanged = stitched ~= view.stitched
	local companionLayers = ns.CompanionMaps.Scan(view.map)
	local companionsChanged = companionLayers ~= view.companionLayers
	view.companionLayers = companionLayers
	local sized = width ~= view.width or height ~= view.height
	local scaled = scale ~= view.scale or zoom ~= view.zoom or pinScale ~= view.pinScale
	view.mapID, view.width, view.height, view.scale, view.zoom, view.pinScale, view.stitched =
		mapID, width, height, scale, zoom, pinScale, stitched
	if first then
		view.shown = true
		view.gamepad = ns.GamepadUI()
		clicks:RegisterEvent("GLOBAL_MOUSE_DOWN")
		clicks:RegisterEvent("GLOBAL_MOUSE_UP")
		Fire(view, "show", sized, scaled)
	elseif changedMap or stitchedChanged or companionsChanged then
		-- The pins over OpenMap's stitched art are lifted over it (or put back under Blizzard's own), then the layers
		-- redraw: the stitched view places a point by the world, not by the map underneath.
		if stitchedChanged then
			for _, pool in pairs(view.pools) do
				for pin in pool:EnumerateActive() do
					pin:ApplyFrameLevel()
				end
			end
		end
		Fire(view, "map", sized, scaled)
	else
		if sized then
			Fire(view, "size", true, false)
		end
		if scaled then
			Fire(view, "scale", false, true)
		end
	end
	-- The map cursor hovers a pin within reach, and lets go of one it hovered; a pin the mouse is on stays hovered.
	if view.gamepad and (not hovered or hoveredByCursor) then
		local pin = PinAtCursor(view)
		if pin ~= hovered then
			SetHovered(pin)
			hoveredByCursor = pin ~= nil
		end
	end
end

---@param view SPFCanvasView
function Hide(view)
	if hovered and hovered.view == view then
		SetHovered(nil)
	end
	pressed = nil
	local open = false
	for _, other in pairs(views) do
		open = open or (other ~= view and other.shown)
	end
	if not open then
		clicks:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		clicks:UnregisterEvent("GLOBAL_MOUSE_UP")
	end
	if view.shown then
		view.shown = false
		Fire(view, "hide")
	end
end

-- A frame with no parent, then set under `parent`: the gamepad interface follows CreateFrame calls whose parent is
-- in an open window.
---@param frameType string
---@param parent Frame
---@param template? string
---@return Frame
local function FrameUnder(frameType, parent, template)
	local frame = CreateFrame(frameType, nil, nil, template)
	frame:SetParent(parent)
	return frame
end
MapCanvas.FrameUnder = FrameUnder

-- The view of `map`, made the first time it is asked for; `listener`, when given, hears what changes.
---@param map SPFMapCanvas
---@param listener? fun(view: SPFCanvasView, what: string)
---@return SPFCanvasView
function MapCanvas.Watch(map, listener)
	local view = views[map]
	if not view then
		local canvas = map:GetCanvas()
		view = setmetatable({
			map = map,
			canvas = canvas,
			shown = false,
			stitched = false,
			width = 0,
			height = 0,
			scale = 1,
			zoom = 0,
			pinScale = 1,
			gamepad = false,
			listeners = {},
			pools = {},
		}, View)
		local host = FrameUnder("Frame", canvas)
		host:SetAllPoints(canvas)
		host:EnableMouse(false)
		host:SetScript("OnUpdate", function()
			Update(view)
		end)
		host:SetScript("OnHide", function()
			Hide(view)
		end)
		local layer = FrameUnder("Frame", host)
		layer:SetAllPoints(host)
		layer:EnableMouse(false)
		view.host, view.layer = host, layer
		views[map] = view
	end
	if listener then
		view.listeners[#view.listeners + 1] = listener
	end
	return view
end

-- Runs the view's check now, as its next frame would. The UI checks drive the map with it.
---@param map SPFMapCanvas
function MapCanvas.Update(map)
	local view = views[map]
	if view then
		Update(view)
	end
end

-- The addon's pins on this map: shown, or hidden in combat.
---@param map SPFMapCanvas
---@param shown boolean
function MapCanvas.SetShown(map, shown)
	local view = views[map]
	if view then
		if not shown and hovered and hovered.view == view then
			SetHovered(nil)
		end
		view.layer:SetShown(shown)
	end
end

--[[ Pins ]]

-- The base of every pin: MapCanvasPinMixin's placing and scaling, worked out from the view rather than asked of the
-- map. A pin is placed at map fractions (SetPosition) and keeps a constant size on screen, between startScale zoomed
-- out and endScale zoomed in, times the map's pin scale unless it ignores it (ApplyCurrentScale). A pin with no limits
-- that ignores the pin scale grows with the terrain.
---@class SPFCanvasPin : Frame
---@field view SPFCanvasView
---@field pool SPFCanvasPool
---@field mapX? number
---@field mapY? number
---@field scaleFactor? number
---@field startScale? number
---@field endScale? number
---@field ignoreGlobalPinScale? boolean
---@field levelType? string
---@field levelIndex? number
---@field takesMouse? boolean
---@field marker? string
---@field OnMouseClickAction? fun(self: SPFCanvasPin, button: string)
local Pin = {}
MapCanvas.PinMixin = Pin

function Pin.OnLoad() end
-- Given what the pool's Acquire was given.
---@type fun(self: SPFCanvasPin, ...: any)
Pin.OnAcquired = function() end
function Pin.OnReleased() end
function Pin.OnMouseEnter() end
function Pin.OnMouseLeave() end
function Pin.OnCanvasScaleChanged() end
function Pin.OnCanvasSizeChanged() end

---@return SPFMapCanvas
function Pin:GetMap()
	return self.view.map
end

-- Whether a press of `button` goes through to the canvas, set again at each acquire: the right button, to zoom out,
-- unless the pin says not.
---@param button string
---@return boolean
function Pin.ShouldMouseButtonBePassthrough(_, button)
	return button == "RightButton"
end

---@param x number
---@param y number
function Pin:SetPosition(x, y)
	self.mapX, self.mapY = x, y
	self:ApplyPosition()
end

---@return number?, number?
function Pin:GetPosition()
	return self.mapX, self.mapY
end

---@param factor number
---@param startScale number
---@param endScale number
function Pin:SetScalingLimits(factor, startScale, endScale)
	self.scaleFactor, self.startScale, self.endScale = factor, math.max(startScale, 0.01), math.max(endScale, 0.01)
end

---@param ignore boolean
function Pin:SetIgnoreGlobalPinScale(ignore)
	self.ignoreGlobalPinScale = ignore
end

---@param levelType string
---@param index? number
function Pin:UseFrameLevelType(levelType, index)
	self.levelType, self.levelIndex = levelType, index
end

function Pin:ApplyFrameLevel()
	self:SetFrameLevel(self.view:Level(self.levelType, self.levelIndex))
end

function Pin:ApplyScale()
	local view = self.view
	local scale
	if self.startScale and self.endScale then
		scale = Lerp(self.startScale, self.endScale, Saturate(self.scaleFactor * view.zoom)) / view.scale
	elseif not self.ignoreGlobalPinScale then
		scale = 1
	end
	if scale then
		if not self.ignoreGlobalPinScale then
			scale = scale * view.pinScale
		end
		self:SetScale(scale)
	end
end

function Pin:ApplyPosition()
	local x, y = self.mapX, self.mapY
	if not (x and y) then
		return
	end
	local view, scale = self.view, self:GetScale()
	self:ClearAllPoints()
	self:SetPoint("CENTER", view.canvas, "TOPLEFT", view.width * x / scale, -view.height * y / scale)
end

--[[ Pools ]]

---@class SPFCanvasPool
---@field view SPFCanvasView
---@field mixin table
---@field frameType string
---@field template? string
---@field marker? string
---@field active SPFCanvasPin[]
---@field free SPFCanvasPin[]
local Pool = {}
Pool.__index = Pool

local function OnEnter(pin)
	hoveredByCursor = false
	SetHovered(pin)
end

local function OnLeave(pin)
	if hovered == pin then
		SetHovered(nil)
	end
end

---@return SPFCanvasPin
function Pool:Acquire(...)
	local pin = table.remove(self.free)
	if not pin then
		pin = FrameUnder(self.frameType, self.view.layer, self.template) --[[@as SPFCanvasPin]]
		Mixin(pin, self.mixin)
		pin.view, pin.pool, pin.marker = self.view, self, self.marker
		pin:OnLoad()
		if pin.takesMouse then
			pin:EnableMouse(true)
			pin:SetScript("OnEnter", OnEnter)
			pin:SetScript("OnLeave", OnLeave)
		else
			pin:EnableMouse(false)
		end
	end
	self.active[#self.active + 1] = pin
	pin:Show()
	pin:OnAcquired(...)
	pin:ApplyFrameLevel()
	pin:ApplyScale()
	pin:ApplyPosition()
	if pin.takesMouse and pin.SetPassThroughButtons then
		local through = {}
		for _, button in ipairs({ "LeftButton", "RightButton" }) do
			if pin:ShouldMouseButtonBePassthrough(button) then
				through[#through + 1] = button
			end
		end
		pin:SetPassThroughButtons(unpack(through))
	end
	return pin
end

---@param pin SPFCanvasPin
local function Release(pin)
	if hovered == pin then
		SetHovered(nil)
	end
	if pressed == pin then
		pressed = nil
	end
	pin:Hide()
	pin:ClearAllPoints()
	pin:OnReleased()
	pin.mapX, pin.mapY = nil, nil
end

function Pool:ReleaseAll()
	for index = #self.active, 1, -1 do
		local pin = self.active[index]
		self.active[index] = nil
		Release(pin)
		self.free[#self.free + 1] = pin
	end
end

---@param pin SPFCanvasPin
function Pool:Release(pin)
	for index, candidate in ipairs(self.active) do
		if candidate == pin then
			table.remove(self.active, index)
			Release(pin)
			self.free[#self.free + 1] = pin
			return
		end
	end
end

---@return fun(): SPFCanvasPin?
function Pool:EnumerateActive()
	local index, active = 0, self.active
	return function()
		index = index + 1
		return active[index]
	end
end

---@return integer
function Pool:GetNumActive()
	return #self.active
end

-- A pool of pins on `map`'s view, under `key`. The pins are frames of `frameType` (a Frame by default) from
-- `template`, wearing `mixin`, which builds on MapCanvas.PinMixin. A pool with a `marker` kind lists its pins for the
-- other Forever addons (ForeverMapMarkers, below).
---@param map SPFMapCanvas
---@param key string
---@param mixin table
---@param options? {frameType?: string, template?: string, marker?: string}
---@return SPFCanvasPool
function MapCanvas.Pool(map, key, mixin, options)
	local view = MapCanvas.Watch(map)
	local pool = view.pools[key]
	if not pool then
		options = options or {}
		pool = setmetatable({
			view = view,
			mixin = mixin,
			frameType = options.frameType or "Frame",
			template = options.template,
			marker = options.marker,
			active = {},
			free = {},
		}, Pool)
		view.pools[key] = pool
	end
	return pool
end

-- The pools on `map`, by key, for the UI checks.
---@param map SPFMapCanvas
---@return table<string, SPFCanvasPool>
function MapCanvas.Pools(map)
	local view = views[map]
	return view and view.pools or {}
end

--[[ Clicks ]]

-- `filter(pin, button)` sees a pin's click before the pin does, and takes it by returning true (Shift-click plans a
-- journey there, JourneyInput.lua).
---@param filter fun(pin: SPFCanvasPin, button: string): boolean?
function MapCanvas.OnClick(filter)
	clickFilters[#clickFilters + 1] = filter
end

---@param pin SPFCanvasPin
---@param button string
function MapCanvas.Click(pin, button)
	if pin:ShouldMouseButtonBePassthrough(button) then
		return
	end
	for _, filter in ipairs(clickFilters) do
		if filter(pin, button) then
			return
		end
	end
	if pin.OnMouseClickAction then
		pin:OnMouseClickAction(button)
	end
end

clicks = CreateFrame("Frame")
clicks:SetScript("OnEvent", function(_, event, button)
	if event == "GLOBAL_MOUSE_DOWN" then
		pressed, pressedButton = nil, button
		if hovered and hovered:IsVisible() and hovered:IsMouseOver() then
			pressed = hovered
		end
		return
	end
	local pin = pressed
	pressed = nil
	if pin and pin == hovered and button == pressedButton and pin:IsVisible() and pin:IsMouseOver() then
		ns.SafeCall("map pin click", MapCanvas.Click, pin, button)
	end
end)

--[[ ForeverMapMarkers ]]

-- The Forever addons' markers on the world map, for each other: Tweaks Forever keeps its dungeon entrances clear of
-- them. With every addon drawing on frames of its own, none can find another's through the map's pin pools any more.
-- Each addon publishes a copy of the global table with one function of its own added under its folder name (a
-- field written into a table another addon made would be a write into that addon's state), and readers look the
-- global up each time:
--   ForeverMapMarkers[addonName] = function(map) -> { { x = number, y = number, kind = string }... }
-- `map` is the map frame (WorldMapFrame); x and y are the shown markers' fractions on map:GetMapID(), in a fresh table
-- the caller may keep. A function never errors and returns an empty table for a map it does not draw on.
-- The table is the family's own, not Blizzard's: this addon adds its function to a copy it then publishes.
local markers = {}
for name, fn in pairs(ForeverMapMarkers or {}) do
	markers[name] = fn
end
ForeverMapMarkers = markers
markers.ShortestPathForever = function(map)
	local list, view = {}, views[map]
	if not (view and view.shown and view.layer:IsShown()) then
		return list
	end
	for _, pool in pairs(view.pools) do
		if pool.marker then
			for pin in pool:EnumerateActive() do
				local x, y = pin:GetPosition()
				if x and pin:IsShown() then
					list[#list + 1] = { x = x, y = y, kind = pool.marker }
				end
			end
		end
	end
	return list
end
