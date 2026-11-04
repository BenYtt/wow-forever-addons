---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- A place inside a dungeon or raid has no walking map: from outside, a journey there goes to the instance's door
-- (Data/Portals.lua ns.Entrances) and arrives when you go in. The door keeps the stop it stands for (`stop`), its
-- name, quest and title; areas and holds drawn inside the instance stay behind. Inside, the point stays as it is.
---@param point SPFPoint
---@return SPFPoint
function ns.InstanceEntrance(point)
	local entrance = ns.Entrances and ns.Entrances[point.map]
	if not entrance or select(8, GetInstanceInfo()) == point.map then
		return point
	end
	local name = GetRealZoneText(point.map)
	if not name or name == "" then
		name = entrance.name
	end
	return {
		map = entrance.map,
		x = entrance.x,
		y = entrance.y,
		z = entrance.z,
		label = point.label or L["Enter %s"]:format(name),
		questID = point.questID,
		routeTitle = point.routeTitle,
		tooltip = point.tooltip,
		entrance = point.map,
		stop = point,
	}
end

---@param uiMapID integer
---@param x number
---@param y number
---@return SPFPoint?
function ns.WorldPoint(uiMapID, x, y)
	local continent, world = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x, y))
	if continent and world then
		local worldX, worldY = world:GetXY()
		return { map = continent, x = worldX, y = worldY }
	end
end

local function PlanQuest(questID, clickedMap, isWaypoint)
	if not ns.db.journey then
		return
	end
	-- Forever takes questID and ignoreWaypoint; Ketho's Wiki stub incorrectly has zero parameters.
	---@diagnostic disable-next-line: redundant-parameter
	local uiMapID = clickedMap or GetQuestUiMapID(questID, true)
	local waypoint
	if not clickedMap or isWaypoint then
		local mapID, x, y
		if clickedMap then
			mapID = clickedMap
			x, y = C_QuestLog.GetNextWaypointForMap(questID, mapID)
		else
			mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
		end
		waypoint = { uiMapID = mapID, x = x, y = y }
	end
	local pois = not isWaypoint and uiMapID and uiMapID > 0 and C_QuestLog.GetQuestsOnMap(uiMapID) or nil
	local location = ns.Planner.QuestDestination(
		questID,
		C_QuestLog.GetTitleForQuestID(questID),
		C_QuestLog.IsComplete(questID),
		uiMapID,
		pois,
		waypoint
	)
	local point = location and ns.WorldPoint(location.uiMapID, location.x, location.y)
	if not point then
		-- Questie.API exposes icons and update notifications, but no public coordinate lookup.
		ns.Print(L["No location for that quest yet."])
		return
	end
	point.label, point.questID, point.pinBadge = location.label, questID, clickedMap ~= nil
	ns.StartJourney(point)
end

-- The World map between its continents and a continent's open sea still give a world position, on no zone: the
-- client answers with a spot off the map it names, or with the continent and no zone under the spot.
---@param point SPFPoint
---@return boolean
local function OnZone(point)
	local location = ns.Locate(point)
	if not location or location.x < 0 or location.x > 1 or location.y < 0 or location.y > 1 then
		return false
	end
	local info = C_Map.GetMapInfo(location.uiMap)
	return not info or info.mapType > Enum.UIMapType.Continent
end

-- Shift+click inserts a link into an open chat box; leave that click to Blizzard's own handlers.
-- Both globals may be absent (older builds, the headless harness); guard the call so a missing
-- one never errors inside a click handler.
local function ChatBoxOpen()
	local active = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
	return active ~= nil and active() ~= nil
end

-- A spot on a map, as a Shift-click on the world map or /way names it, with what to call it if anything.
---@param uiMapID integer
---@param x number
---@param y number
---@param label? string
---@return boolean
function ns.JourneyToMapPoint(uiMapID, x, y, label)
	local point = ns.WorldPoint(uiMapID, x, y)
	if not (point and OnZone(ns.InstanceEntrance(point))) then
		ns.Print(L["no journey can be planned to that spot."])
		return false
	end
	point.label = label
	ns.StartJourney(point)
	return true
end

local function OnCanvasClick(map, button)
	if not ns.db.journey or button ~= "LeftButton" or not IsShiftKeyDown() or ChatBoxOpen() then
		return false
	end
	ns.JourneyToMapPoint(map:GetMapID(), map:GetNormalizedCursorPosition())
	return true
end

local function OnMinimapClick(_, button)
	if not ns.db.journey or button ~= "LeftButton" or not IsShiftKeyDown() then
		return
	end
	local point = ns.MinimapPoint()
	if point then
		ns.StartJourney(point)
	else
		ns.Print(L["no journey can be planned to that spot."])
	end
end

-- A journey to a Shift-clicked pin, labelled by its name if it has one: a flight point by its node, anything else by
-- where it stands on the map. False when there is nowhere to plan to.
---@param mapID number
---@param info? {nodeID?: number, name?: string}
---@param flight boolean
---@param x? number
---@param y? number
---@return boolean
local function JourneyToPin(mapID, info, flight, x, y)
	local node = flight and info and ns.TaxiNodes[info.nodeID]
	local point
	if node then
		point = { map = node.map, x = node.x, y = node.y, z = node.z }
	elseif x and y then
		point = ns.WorldPoint(mapID, x, y)
	end
	if not (point and OnZone(ns.InstanceEntrance(point))) then
		return false
	end
	point.label = info and info.name
	point.pinBadge = true
	ns.StartJourney(point)
	return true
end

local function OnPinClick(map, action, button)
	if
		not ns.db.journey
		or action ~= MapCanvasMixin.MouseAction.Click
		or button ~= "LeftButton"
		or not IsShiftKeyDown()
		or ChatBoxOpen()
	then
		return false
	end
	-- MapCanvas calls these handlers before POIButton.OnClick. Canvas click handlers do not run over pins.
	for _, focus in ipairs(GetMouseFoci()) do
		local pin = focus
		---@cast pin SPFQuestPin
		if pin.pinTemplate == "QuestPinTemplate" and pin:GetMap() == map and pin:GetQuestID() then
			PlanQuest(pin:GetQuestID(), map:GetMapID(), pin:GetStyle() == POIButtonUtil.Style.Waypoint)
			return true
		end
		---@cast pin SPFFlightPin
		if pin.pinTemplate and pin.pinTemplate ~= "QuestPinTemplate" and pin.GetMap and pin:GetMap() == map then
			local x, y
			if pin.GetGlobalPosition then
				x, y = pin:GetGlobalPosition()
			end
			if JourneyToPin(map:GetMapID(), pin.poiInfo, pin.pinTemplate == "FlightPointPinTemplate", x, y) then
				return true
			end
		end
	end
	return false
end

-- Shift-click on one of the addon's own map pins (UI/MapCanvas.lua), as OnPinClick does for the map's. The stop
-- buttons keep their own click.
---@param pin SPFCanvasPin
---@param button string
---@return boolean
local function OnOwnPinClick(pin, button)
	if not ns.db.journey or button ~= "LeftButton" or not IsShiftKeyDown() or ChatBoxOpen() then
		return false
	end
	local marker = pin.marker
	if marker ~= "flight" and marker ~= "dock" and marker ~= "portal" then
		return false
	end
	local x, y = pin:GetPosition()
	local info = marker == "flight" and (pin --[[@as SPFAddonFlightPin]]).poiInfo or nil
	return JourneyToPin(pin:GetMap():GetMapID(), info, marker == "flight", x, y)
end

local function AddQuestMenuEntry(root, questID)
	if ns.db.journey and questID then
		root:CreateButton(L["Plan journey"], function()
			PlanQuest(questID)
		end)
		ns.FamilyHints.AddQuestMenu(root)
	end
end

ns.Init(function()
	-- Questie owns Shift-click on its icons. Alt-click observes the map cursor
	-- through our own event frame, including icons that swallow canvas clicks.
	-- TomTom's map overlay passes LeftButton through; its waypoint gesture uses RightButton.
	local clicks = CreateFrame("Frame")
	clicks:RegisterEvent("GLOBAL_MOUSE_DOWN")
	clicks:SetScript("OnEvent", function(_, _, button)
		if
			not ns.db.journey
			or button ~= "LeftButton"
			or not IsAltKeyDown()
			or IsShiftKeyDown()
			or not WorldMapFrame:IsShown()
			or not WorldMapFrame.ScrollContainer:IsMouseOver()
		then
			return
		end
		local point = ns.WorldPoint(WorldMapFrame:GetMapID(), WorldMapFrame:GetNormalizedCursorPosition())
		if point and OnZone(ns.InstanceEntrance(point)) then
			ns.StartJourney(point)
		end
	end)
	-- The map's click registries are Blizzard's own for addons (MapCanvasSecureUtil.CreateHandlerRegistry): it keeps
	-- them outside the map's fields and calls each handler through securecallfunction, so the map's code never runs
	-- the addon's. The addon's own pins take their clicks through UI/MapCanvas.lua instead.
	WorldMapFrame:AddCanvasClickHandler(OnCanvasClick)
	WorldMapFrame:AddGlobalPinMouseActionHandler(OnPinClick)
	ns.MapCanvas.OnClick(OnOwnPinClick)
	-- The stock handler still pings the spot, which marks where the journey goes for your group too.
	Minimap:HookScript("OnMouseUp", OnMinimapClick)
	Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", function(owner, root)
		-- The native menu owner is the tracker container, with no quest ID/context data.
		-- Resolve the right-clicked HeaderButton's block; never reuse a previous hover's quest.
		for _, header in ipairs(GetMouseFoci()) do
			local block = header:GetParent()
			---@cast block SPFTrackerBlock
			if
				block
				and block.HeaderButton == header
				and block.parentModule
				and block.parentModule:GetContextMenuParent() == owner
			then
				AddQuestMenuEntry(root, block.id)
				return
			end
		end
	end)
	Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", function(owner, root)
		---@cast owner SPFQuestMenuOwner
		-- Waypoint menus share this tag, but have no questID.
		AddQuestMenuEntry(root, owner.questID)
	end)
end)
