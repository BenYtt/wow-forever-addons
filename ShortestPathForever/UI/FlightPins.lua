---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- Flight points on the world map: the addon's own pins (UI/MapCanvas.lua) in the stock flight point's place.
local FLIGHT_TEMPLATE = "ShortestPathForeverFlightPinTemplate"
local PIN_SIZE = 20
---@type SPFCanvasPool
local flightPins

-- The stock flight point (FlightPointPinMixin in FlightPointDataProvider.lua, its super-tracking from
-- SuperTrackablePinMixin), drawn by the addon: the node's atlas at its own size, scaled as a POI pin, and on a zone map
-- a left click super-tracks the node or lets it go. Above a zone the click goes through to the map, to zoom in.
---@class SPFAddonFlightPin : SPFCanvasPin
---@field Texture Texture
---@field HighlightTexture Texture
---@field SuperTrackGlow Texture
---@field SuperTrackMarker Texture
---@field poiInfo {nodeID: number, name: string, isUndiscovered: boolean, atlasName: string, textureKit?: string}
local FlightPin = CreateFromMixins(ns.MapCanvas.PinMixin)

function FlightPin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_FLIGHT_POINT")
	self:SetScalingLimits(1, 1, 1.2)
	self.takesMouse = true
	-- Closing the map hides the pin without an OnMouseLeave.
	self:SetScript("OnHide", self.OnMouseLeave)
end

-- Whether this map is a zone or smaller: above one, clicks zoom in (SuperTrackablePinMixin:DoesMapTypeAllowSuperTrack).
---@param mapID number
---@return boolean
local function SuperTrackMap(mapID)
	local info = C_Map.GetMapInfo(mapID)
	return info ~= nil and info.mapType >= Enum.UIMapType.Zone
end

function FlightPin:UpdateSuperTracked()
	local kind, id = C_SuperTrack.GetSuperTrackedMapPin()
	local tracked = kind == Enum.SuperTrackingMapPinType.TaxiNode and id == self.poiInfo.nodeID
	self.SuperTrackGlow:SetShown(tracked)
	self.SuperTrackMarker:SetShown(tracked)
	return tracked
end

function FlightPin:OnAcquired(info)
	self.poiInfo = info
	local atlas = info.textureKit and info.textureKit .. "-" .. info.atlasName or info.atlasName
	local art = ns.Art.Info(atlas)
	local width, height = art and art.width or PIN_SIZE, art and art.height or PIN_SIZE
	self:SetSize(width, height)
	ns.Art.Fit(self.Texture, atlas, width, height)
	ns.Art.Fit(self.HighlightTexture, atlas, width, height)
	local scale = (ns.db.flightPinScale or 100) / 100
	self:SetScalingLimits(1, scale, scale * 1.2)
	self:SetPosition(info.position:GetXY())
	self:UpdateSuperTracked()
end

-- The right button opens the menu. Above a zone the left button goes through to the map, to zoom in, as the stock
-- pin's click propagation does there; only that button, so a right click is the menu's alone.
function FlightPin:ShouldMouseButtonBePassthrough(button)
	return button == "LeftButton" and not SuperTrackMap(self:GetMap():GetMapID())
end

function FlightPin:OnMouseClickAction(button)
	if button == "RightButton" then
		ns.ContextMenu(self, function(_, root)
			root:CreateCheckbox(L["Flight path known"], function()
				local known = ns.KnownTaxiNodes()
				return known and known[self.poiInfo.nodeID] == true
			end, function()
				local known = ns.KnownTaxiNodes()
				ns.SetTaxiKnown(self.poiInfo.nodeID, not (known and known[self.poiInfo.nodeID]))
				ns.RefreshMap()
			end)
		end)
	elseif button == "LeftButton" and SuperTrackMap(self:GetMap():GetMapID()) then
		if self:UpdateSuperTracked() then
			C_SuperTrack.ClearAllSuperTracked()
		else
			C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.TaxiNode, self.poiInfo.nodeID)
		end
	end
end

-- A flight point's tooltip lists where you can fly from it, as many as fit.
local FLIGHTS_SHOWN = 8

---@param nodeID number
---@param undiscovered? boolean the hovered point itself is not known yet: nothing flies from it for you
local function AddFlights(nodeID, undiscovered)
	local known, faction = ns.KnownTaxiNodes(), UnitFactionGroup("player")
	-- The flight points the planner flies to (Planner.lua's Eligible): neutral ones and your faction's, whatever the
	-- boat and zeppelin setting says.
	local flights = ns.TaxiTimes.FlightsFrom(nodeID, function(to)
		local node = ns.TaxiNodes[to]
		return node ~= nil and (not node.faction or node.faction == faction)
	end)
	if not flights[1] then
		return
	end
	GameTooltip_AddNormalLine(GameTooltip, L["Flights from here"])
	for index = 1, math.min(#flights, FLIGHTS_SHOWN) do
		local flight = flights[index]
		local time = ns.FormatCountdown(flight.seconds * 1000)
		-- A time worked out from the path's length, not timed by anyone, says so.
		if flight.estimated then
			time = string.format(L["about %s"], time)
		end
		-- Flight points you have not found yet are grey, as on the flight map; all are from one you have not found.
		local color = (undiscovered or not known[flight.to]) and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR
		GameTooltip_AddColoredDoubleLine(GameTooltip, ns.TaxiName(flight.to), time, color, color)
	end
	if #flights > FLIGHTS_SHOWN then
		GameTooltip_AddNormalLine(GameTooltip, string.format(L["and %d more"], #flights - FLIGHTS_SHOWN))
	end
end

function FlightPin:OnMouseEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, self.poiInfo.name)
	if self.poiInfo.isUndiscovered then
		GameTooltip_AddNormalLine(GameTooltip, L["Not discovered"])
	end
	AddFlights(self.poiInfo.nodeID, self.poiInfo.isUndiscovered)
	GameTooltip:Show()
end

function FlightPin:OnMouseLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

function FlightPin:OnReleased()
	self:OnMouseLeave()
end

-- The flight points the stock provider shows (FlightPointDataProviderMixin:ShouldShowTaxiNode): neutral ones and the
-- player's faction's.
---@param faction string
---@param info {faction: number}
---@return boolean
local function ShouldShowTaxiNode(faction, info)
	if info.faction == Enum.FlightPathFaction.Horde then
		return faction == "Horde"
	elseif info.faction == Enum.FlightPathFaction.Alliance then
		return faction == "Alliance"
	end
	return true
end

---@class SPFFlightLayer
---@field signature? string
---@field force? boolean
local Flights = {}

function Flights.RemoveAllData()
	flightPins:ReleaseAll()
end

function Flights:RefreshAllData()
	if InCombatLockdown() then
		ns.QueueMapRefresh()
		return
	end
	local map = WorldMapFrame
	local mapID = map:GetMapID()
	if not (ns.db.mapFlightMasters and mapID and map:IsVisible()) then
		self:RemoveAllData()
		self.signature = nil
		return
	end
	local signature = ns.CompanionMaps.Scan(map)
		.. ":"
		.. mapID
		.. ":"
		.. tostring(ns.db.mapFlightMasters)
		.. ":"
		.. tostring(ns.db.otherFaction)
		.. ":"
		.. tostring(ns.db.flightPinScale)
	if self.signature == signature and not self.force then
		return
	end
	self.force = nil
	self:RemoveAllData()
	self.signature = signature
	local known, faction = ns.KnownTaxiNodes(), UnitFactionGroup("player")
	local queried, reported = {}, {}
	local function Query(id)
		if id and not queried[id] then
			queried[id] = true
			for _, info in ipairs(C_TaxiMap.GetTaxiNodesForMap(id) or {}) do
				reported[info.nodeID] = info
			end
		end
	end
	Query(mapID)
	-- The game's own provider is left on the map. Where it draws flight points itself, those nodes are its own.
	local nativeShown = {}
	if C_TaxiMap.ShouldMapShowTaxiNodes and C_TaxiMap.ShouldMapShowTaxiNodes(mapID) then
		for id in pairs(reported) do
			nativeShown[id] = true
		end
	end
	for id, node in pairs(ns.TaxiNodes) do
		local location = ns.Locate(node)
		local x, y = ns.MapPinPosition(node, mapID)
		if x and y and location and ns.IsDockMap(location, mapID) and not nativeShown[id] then
			Query(location.uiMap)
			local unknown = known ~= nil and not known[id]
			local native = reported[id]
			-- The API's nodeID is the TaxiNodes DB2 key, also used by Taxi.lua; no name/position guessing. Its name is
			-- the client's own; its position is on whichever map was asked, so the shipped world point places the pin.
			local info = {
				nodeID = id,
				name = native and native.name ~= "" and native.name or ns.TaxiName(id),
				position = CreateVector2D(x, y),
				isUndiscovered = unknown,
				faction = Enum.FlightPathFaction[node.faction or "Neutral"],
				-- Native fallback atlases from UiTextureAtlasMember, build 1.60.1.69913.
				atlasName = unknown and "taxinode_undiscovered" or "taxinode_" .. (node.faction or "Neutral"):lower(),
			}
			if native and native.isUndiscovered == unknown and native.atlasName ~= "" then
				info.atlasName = native.atlasName
				info.textureKit = native.textureKit ~= "" and native.textureKit or nil
			end
			if ShouldShowTaxiNode(faction, info) and not ns.CompanionMaps.Suppresses("flight", x, y, "taxi", id) then
				flightPins:Acquire(info)
			end
		end
	end
end

-- Redraws the flight points: when `force` is set, even with nothing in the signature changed (a flight path learnt).
---@param force? boolean
function ns.RefreshFlightPins(force)
	if not flightPins then
		return
	end
	Flights.force = Flights.force or force
	Flights:RefreshAllData()
end

ns.Init(function()
	flightPins =
		ns.MapCanvas.Pool(WorldMapFrame, FLIGHT_TEMPLATE, FlightPin, { template = FLIGHT_TEMPLATE, marker = "flight" })
	local taxiEvents = CreateFrame("Frame")
	taxiEvents:RegisterEvent("TAXI_NODE_STATUS_CHANGED")
	taxiEvents:RegisterEvent("TAXIMAP_OPENED")
	taxiEvents:RegisterEvent("SUPER_TRACKING_CHANGED")
	local taxiPending
	taxiEvents:SetScript("OnEvent", function(_, event)
		if event == "SUPER_TRACKING_CHANGED" then
			for pin in flightPins:EnumerateActive() do
				---@cast pin SPFAddonFlightPin
				pin:UpdateSuperTracked()
			end
			return
		end
		if taxiPending or not WorldMapFrame:IsVisible() then
			return
		end
		taxiPending = true
		-- Let Taxi.lua finish updating the known-set before recolouring the pins.
		C_Timer.After(0, function()
			taxiPending = nil
			Flights.force = true
			Flights:RefreshAllData()
		end)
	end)
end)
