local addonName = ...
---@class SPFNamespace
---@field ReportTitle string the localized title shown by the shared report window
---@field Report ForeverReportModule the shared report and issue window
---@field TrackerHost ForeverTrackerHostAPI
---@field Family ForeverFamilyAPI
local ns = select(2, ...)
local L = ns.L
if L then
	ns.ReportTitle = L["Shortest Path report"]
end

local Model = ns.Model
-- The settings panel registers these same defaults, so a checkbox's reset matches a fresh install.
local DEFAULTS = {
	pins = true,
	transit = true,
	portals = true,
	minimapPins = true,
	mapFlightMasters = true,
	mapRoutes = true,
	mapPinScale = 100,
	flightPinScale = 100,
	minimapPinScale = 100,
	otherFaction = false,
	tracker = true,
	alerts = true,
	alertSound = true,
	flightPathReminder = true,
	arrivalSound = false,
	journey = true,
	-- An on-screen marker over the destination, like the client's own waypoint pin. Off by default: it is
	-- new screen furniture, and a player asks for it from Settings > Guidance.
	destinationPin = false,
	resumeJourney = false,
	tomtom = true,
	tomtomFollow = false,
	restedxp = true,
	taxiRoute = true,
	teleports = true,
	hearthMinimumSavings = 0,
	share = true,
	-- Existing saved false choices remain off; missing settings join the travel journal.
	stats = true,
	statsShare = true,
	guideStops = true,
	journeyTracker = true,
	arrow = true,
	metres = false,
	minimapButton = false,
	compass = true,
	compassTime = false,
	compassScale = 100,
	arrowScale = 100,
	compassBackground = 0,
	corpse = true,
	avoidHighZones = true,
	whatsNew = true,
}
ns.Defaults = DEFAULTS

-- The shared tracker host owns the one tracker scale and its Lock switch, so they live in the host's own settings
-- rather than DEFAULTS. Saved variables arrive after the TOC loads, so answer with a throwaway default until then.
-- Lock defaults off; a table saved before it existed simply gains the key.
---@return ForeverTrackerSettings
function ns.TrackerHostSettings()
	if type(ns.db) ~= "table" then
		return { attached = true, locked = false, scale = 1 }
	end
	local settings = ns.db.trackerHost
	if type(settings) ~= "table" then
		settings = { attached = true, locked = false, scale = 1 }
		ns.db.trackerHost = settings
	end
	if type(settings.scale) ~= "number" or settings.scale ~= settings.scale then
		settings.scale = 1
	end
	if type(settings.locked) ~= "boolean" then
		settings.locked = false
	end
	return settings
end

-- Whether the game's gamepad interface is up. Under it, Forever's FrameControlsManager takes every menu and UI panel
-- that shows into its focus, in the same call: it pushes a binding set, and the gamepad action bar's
-- UpdateInteractIcons calls the protected SetPreferredGamepadInteractTarget from there. A menu, panel or map change
-- this addon's code starts makes that whole call tainted and the client blocks it (#158), so under the gamepad
-- interface the addon leaves opening menus and windows, turning the map and taking the keyboard to the game.
---@return boolean
function ns.GamepadUI()
	-- Enum.InputDeviceInterfaceType is the Forever UI's own name (Blizzard_EditMode/Shared/EditModeManager.lua).
	local styles, api = Enum.InputDeviceInterfaceType, C_InputInterfaceStyle
	return styles ~= nil and api ~= nil and api.GetCurrentStyle ~= nil and api.GetCurrentStyle() == styles.Gamepad
end

-- Shows the world map on uiMap (or where you are) and returns whether it is up there. Under the gamepad interface
-- the addon neither opens nor turns it (#158): C_Map.OpenWorldMap runs the map's own handler, its pins and the
-- gamepad focus in this addon's call. A map the player already has on uiMap (or any map, with no uiMap) is used as
-- it is; otherwise the player is told what to open (`hint`, or the plain line) and false comes back.
---@param uiMap? number
---@param hint? string
---@return boolean
function ns.OpenWorldMap(uiMap, hint)
	if not ns.GamepadUI() then
		C_Map.OpenWorldMap(uiMap)
		return true
	end
	local map = WorldMapFrame
	if map and map:IsShown() then
		if not uiMap or map:GetMapID() == uiMap then
			return true
		end
		local info = C_Map.GetMapInfo(uiMap)
		if info and info.name then
			ns.Print(ns.L["Turn the world map to %s to see it."]:format(info.name))
			return false
		end
	end
	ns.Print(hint or ns.L["Open the world map to see it."])
	return false
end

-- Opens a context menu on owner (MenuUtil.CreateContextMenu) and returns it. Under the gamepad interface a menu this
-- addon opens is blocked the same way (#158), so none opens, the player is told why and nil comes back.
---@param owner Region
---@param generator fun(owner: Region, root: table)
---@return table?
function ns.ContextMenu(owner, generator)
	if ns.GamepadUI() then
		ns.Print(ns.L["This menu needs mouse and keyboard."])
		return nil
	end
	return MenuUtil.CreateContextMenu(owner, generator)
end

---@param message string
function ns.Print(message)
	print(NORMAL_FONT_COLOR:WrapTextInColorCode("Shortest Path Forever:") .. " " .. message)
end

-- Each module starts on its own, so one that fails (reported as usual, and kept for /path report) does not stop
-- the rest.
local function Start(fn)
	ns.SafeCall("module start", fn)
end

local pending, ready = {}, false
---@param fn fun()
function ns.Init(fn)
	if ready then
		Start(fn)
	else
		pending[#pending + 1] = fn
	end
end

-- Server time in ms. GetServerTime has whole seconds; it floors the true time, so its largest lead over
-- GetTime is the offset between the two clocks (reset if the clocks jump).
local offset
---@return number
function ns.NowMs()
	local lead = GetServerTime() - GetTime()
	if not offset or lead > offset or offset - lead > 2 then
		offset = lead
	end
	return (GetTime() + offset) * 1000
end

-- The zone map a world point sits on, with the point's position there and the map's info. GetMapPosFromWorldPos
-- may answer with the continent, so descend to the zone under the point when it does.
---@param map number
---@param x number
---@param y number
---@return number? uiMap, Vector2DMixin? position, UiMapDetails? info
function ns.ZoneMap(map, x, y)
	local world = CreateVector2D(x, y)
	local uiMap, position = C_Map.GetMapPosFromWorldPos(map, world)
	if not uiMap then
		return nil
	end
	local info = C_Map.GetMapInfo(uiMap)
	if info and info.mapType ~= Enum.UIMapType.Zone then
		local zone = C_Map.GetMapInfoAtPosition(uiMap, position:GetXY())
		if zone and zone.mapType == Enum.UIMapType.Zone then
			local zoneMap, zonePosition = C_Map.GetMapPosFromWorldPos(map, world, zone.mapID)
			if zoneMap then
				uiMap, position, info = zoneMap, zonePosition, zone
			end
		end
	end
	return uiMap, position, info
end

local function Resolve(point)
	local uiMap, position, info = ns.ZoneMap(point.map, point.x, point.y)
	if not uiMap or not position then
		return nil
	end
	local x, y = position:GetXY()
	return { uiMap = uiMap, x = x, y = y, zone = info and info.name or UNKNOWN }
end

local locations = setmetatable({}, { __mode = "k" })
---@param point SPFPoint
---@return SPFLocation?
function ns.Locate(point)
	if locations[point] == nil then
		locations[point] = Resolve(point) or false
	end
	return locations[point] or nil
end

-- Boat boarding points stand on the pier. A tram station on an internal map uses its city-entrance pin for display.
---@param dockID number
---@return SPFPoint
function ns.DockPoint(dockID)
	local dock = ns.Docks[dockID]
	return dock.pin or dock.walk or dock
end

---@param dockID number
---@return SPFLocation?
function ns.DockLocation(dockID)
	return ns.Locate(ns.DockPoint(dockID))
end

---@param dockID number
---@return string
function ns.DockZone(dockID)
	local location = ns.DockLocation(dockID)
	return location and location.zone or UNKNOWN
end

-- A dock as a destination: a lift's landing or a tram station by name, a pier by its zone.
---@param dockID number
---@return string
function ns.DockLabel(dockID)
	return ns.Docks[dockID].name or ns.DockZone(dockID)
end

-- A specific stop for walking directions and tracker headings; boat destinations still use DockLabel.
---@param dockID number
---@return string
function ns.DockTitle(dockID)
	local dock = ns.Docks[dockID]
	return dock.site and dock.site .. ", " .. dock.name or ns.DockPierName(dockID)
end

local dockX, dockY, dockMap, nearestDock, nearestYards
---@return number? dockID, number? yards
function ns.NearestDock()
	-- The player's height is unknown (UnitPosition's is a placeholder 0), so a lift's landings tie on the map.
	local x, y, _, map = ns.JourneyPosition()
	if not x then
		return nil
	end
	if x == dockX and y == dockY and map == dockMap then
		return nearestDock, nearestYards
	end
	local nearest, yards
	for dockID, dock in pairs(ns.Docks) do
		if dock.map == map then
			local distance = math.sqrt((dock.x - x) ^ 2 + (dock.y - y) ^ 2)
			if not yards or distance < yards or (distance == yards and dockID < nearest) then
				nearest, yards = dockID, distance
			end
		end
	end
	dockX, dockY, dockMap = x, y, map
	nearestDock, nearestYards = nearest, yards
	return nearest, yards
end

-- Opposing-faction landings can be hostile; showing and using those routes is opt-in.
---@param route SPFRoute
---@return boolean
function ns.RouteShown(route)
	return ns.db.otherFaction or not route.faction or route.faction == UnitFactionGroup("player")
end

-- Which map filter each kind of route answers to.
local FILTER = { boat = "pins", zeppelin = "pins", lift = "transit", tram = "transit" }
---@param kind SPFMode
---@return boolean?
function ns.KindShown(kind)
	return ns.db[FILTER[kind] or error("unknown route kind " .. tostring(kind))]
end

ns.FormatCountdown = Model.FormatCountdown

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
	if name ~= addonName then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	ShortestPathForeverDB = ShortestPathForeverDB or {}
	ns.db = ShortestPathForeverDB
	for key, value in pairs(DEFAULTS) do
		if ns.db[key] == nil then
			ns.db[key] = value
		end
	end
	ready = true
	for _, fn in ipairs(pending) do
		Start(fn)
	end
	pending = nil
end)

-- Passive boat/lift motion need not fire player movement events. Keep sampling near a landing and
-- through a ride; elsewhere movement/world events wake one shared clock rather than an idle ticker per listener.
local travelListeners, travelTicker = {}, nil
local moving, probes = false, 0
---@param fn fun(dockID: number?, yards: number?)
function ns.OnTravelTick(fn)
	travelListeners[#travelListeners + 1] = fn
end

local function TravelTick()
	local dockID, yards = ns.NearestDock()
	for _, fn in ipairs(travelListeners) do
		fn(dockID, yards)
	end
	local near = yards and yards <= 200
	local observing = ns.IsObservingRide()
	-- A taxi takes control without movement events, so its own flag keeps the clock sampling.
	local taxi = UnitOnTaxi("player")
	local journey = ns.HasJourney()
	probes = math.max(0, probes - 1)
	local active = near or observing or taxi or journey or ns.db.debug or moving or probes > 0
	if not active and travelTicker then
		travelTicker:Cancel()
		travelTicker = nil
	end
end

function ns.WakeTravel()
	-- Two position samples also detect a reload/zone change in the middle of a crossing.
	probes = 2
	if not travelTicker then
		travelTicker = C_Timer.NewTicker(1, TravelTick)
	end
end

ns.Init(function()
	local travel = CreateFrame("Frame")
	for _, event in ipairs({
		"PLAYER_ENTERING_WORLD",
		"PLAYER_CONTROL_GAINED",
		"ZONE_CHANGED",
		"ZONE_CHANGED_INDOORS",
		"ZONE_CHANGED_NEW_AREA",
		"PLAYER_STARTED_MOVING",
		"PLAYER_STOPPED_MOVING",
		"PLAYER_CONTROL_LOST",
		"PLAYER_REGEN_ENABLED",
	}) do
		travel:RegisterEvent(event)
	end
	travel:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
	travel:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_STARTED_MOVING" then
			moving = true
		elseif event == "PLAYER_STOPPED_MOVING" then
			moving = false
		elseif event == "PLAYER_ENTERING_WORLD" then
			moving = IsPlayerMoving()
		end
		ns.WakeTravel()
	end)
end)
