---@type string, SPFNamespace
local _, ns = ...
local L = ns.L
local SERVICES = {
	{ key = "class", label = L["Class trainer"] },
	{ key = "trainer", flag = "TRAINER", label = L["Trainers by specialty"] },
	{ key = "repair", flag = "REPAIR", label = L["Repair"] },
	{ key = "reagents", flag = "VENDOR", label = L["Reagents"] },
	{ key = "vendor", flag = "VENDOR", label = L["Vendors by specialty"] },
	{ key = "innkeeper", flag = "INNKEEPER", label = L["Innkeeper"] },
	{ key = "bank", flag = "BANKER", label = L["Bank"] },
	{ key = "auction", flag = "AUCTIONEER", label = L["Auction house"] },
	{ key = "flight", flag = "FLIGHT_MASTER", label = L["Flight master"] },
	{ key = "stable", flag = "STABLEMASTER", label = L["Stable master"] },
}
-- A reagent vendor's title, as QuestieDB gives it: in English, or in the client's language where QuestieDB has it.
-- L["Reagent Vendor"] is only ever this match, so a translation keeps it to the client's own NPC title; the menu
-- label L["Reagents"] counts too, as some vendors carry that title.
local REAGENT_TITLES = {
	["Reagents"] = true,
	["Reagent Vendor"] = true,
	[L["Reagents"]] = true,
	[L["Reagent Vendor"]] = true,
}
local index, state, menuOpen = {}, "idle", false
local Open
local function Close()
	menuOpen = false
end
-- What the menu says in place of the services: QuestieDB is still being read, is not installed, or could not be read.
local STATUS = {
	building = L["Loading QuestieDB…"],
	missing = L["Nearby services need the QuestieDB addon."],
	failed = L["Nearby services could not read QuestieDB."],
}
-- One of QuestieDB's zone tables, which it keeps as Lua source; nil when it does not read as a table.
---@param source any
---@return table?
local function Table(source)
	local chunk = type(source) == "string" and loadstring(source)
	if not chunk then
		return nil
	end
	setfenv(chunk, {})
	local ok, value = pcall(chunk)
	return ok and type(value) == "table" and value or nil
end
local function Nearest(key, world, specialty)
	local best, distance
	for _, place in ipairs(index[key] or {}) do
		if place.world.map == world.map and (not specialty or place.specialty == specialty) then
			local d = (place.world.x - world.x) ^ 2 + (place.world.y - world.y) ^ 2
			if not distance or d < distance or (d == distance and place.id < best.id) then
				best, distance = place, d
			end
		end
	end
	return best
end
local function Navigate(key, place)
	if not place then
		return false
	end
	local kind = (key == "trainer" or key == "class") and "trainer"
		or key == "innkeeper" and "innkeeper"
		or key == "flight" and "flightmaster"
		or nil
	return ShortestPathForever.API.Navigate("Shortest Path Forever", place.map, place.x, place.y, place.name, kind)
end
-- A service button's response: one that starts a journey closes every menu, one that cannot keeps the menu open.
-- The response is how a button closes its menu: the Forever client's MenuUtil has no CloseAllMenus (#161).
local function Pick(key, place)
	if Navigate(key, place) then
		Close()
		return MenuResponse.CloseAll
	end
	return MenuResponse.Open
end
local function Build()
	if state == "building" or state == "ready" then
		return
	end
	local lib = rawget(_G, "LibQuestieDB")
	if not lib then
		state = "missing"
		return
	end
	local zones = lib.RequireContract and lib.RequireContract(2) and lib.Support.Get("ZoneDB")
	local expansion = lib.Enum and lib.Enum.byExpansion and lib.Enum.byExpansion.Classic
	local constants = expansion and expansion.npcFlags
	-- Without the two zone tables no spawn has a map, which would read as no service anywhere.
	local private = zones and zones.private
	local area = private and Table(private.areaIdToUiMapId)
	local parents = private and Table(private.subZoneToParentZone)
	if not (area and parents and constants and lib.Npc) then
		state = "failed"
		return
	end
	index = {}
	state = "building"
	local co = coroutine.create(function()
		-- QuestieDB's own corrections to those two, which a flavour may leave out.
		local override = Table(private.areaIdToUiMapIdOverride) or {}
		local parentOverride = Table(private.subZoneToParentZoneOverride) or {}
		local faction = UnitFactionGroup("player") == "Alliance" and "A" or "H"
		local tweaks = rawget(_G, "TweaksForever")
		local classIds = {}
		if
			tweaks
			and tweaks.API
			and type(tweaks.API.version) == "number"
			and tweaks.API.version >= 2
			and tweaks.API.Trainers
		then
			for _, trainer in ipairs(tweaks.API.Trainers()) do
				classIds[trainer.npc] = true
			end
		end
		local fields = { "name", "subName", "spawns", "friendlyToFaction", "npcFlags" }
		for _, id in ipairs(lib.Npc.GetAllIds()) do
			local values = lib.Npc.GetAll(id, fields)
			if values then
				local name, specialty, spawns, friendly, flags = unpack(values, 1, values.n)
				if type(name) == "string" and (friendly == "AH" or friendly == faction) and type(flags) == "number" then
					local keys = {}
					for _, service in ipairs(SERVICES) do
						if service.flag and bit.band(flags, constants[service.flag]) ~= 0 then
							if service.key ~= "reagents" or REAGENT_TITLES[specialty] then
								keys[#keys + 1] = service.key
							end
						end
					end
					if classIds[id] then
						keys[#keys + 1] = "class"
					end
					if #keys > 0 then
						for zone, points in pairs(spawns or {}) do
							local parent = parentOverride[zone] or parents[zone]
							local map = override[zone] or area[zone] or (parent and (override[parent] or area[parent]))
							for _, spot in ipairs(points) do
								local x, y = spot[1], spot[2]
								if
									map
									and type(x) == "number"
									and type(y) == "number"
									and x >= 0
									and x <= 100
									and y >= 0
									and y <= 100
								then
									local world = ns.WorldPoint(map, x / 100, y / 100)
									if world then
										local place = {
											id = id,
											name = name,
											specialty = specialty,
											map = map,
											x = x / 100,
											y = y / 100,
											world = world,
										}
										for _, key in ipairs(keys) do
											index[key] = index[key] or {}
											index[key][#index[key] + 1] = place
										end
									end
								end
								coroutine.yield()
							end
						end
					end
				end
			end
			coroutine.yield()
		end
	end)
	local function Pump()
		if InCombatLockdown() or ns.Path.Busy() then
			C_Timer.After(0.1, Pump)
			return
		end
		local finish = debugprofilestop() + 1
		repeat
			local ok, err = coroutine.resume(co)
			if not ok then
				state = "failed"
				geterrorhandler()(err)
				return
			end
			if coroutine.status(co) == "dead" then
				state = "ready"
				if menuOpen and not InCombatLockdown() then
					Open()
				end
				return
			end
		until debugprofilestop() >= finish
		C_Timer.After(0, Pump)
	end
	C_Timer.After(0, Pump)
end
local function PlayerWorld()
	local map = C_Map.GetBestMapForUnit("player")
	local point = map and C_Map.GetPlayerMapPosition(map, "player")
	if map and point then
		return ns.WorldPoint(map, point:GetXY()) -- multi-value: x and y
	end
end
local function SpecialtyNames(key, world)
	local names = {}
	for _, place in ipairs(index[key] or {}) do
		if world and place.world.map == world.map and place.specialty then
			names[place.specialty] = true
		end
	end
	local result = {}
	for name in pairs(names) do
		result[#result + 1] = name
	end
	table.sort(result)
	return result
end

local function AddService(root, service, world)
	local place = world and Nearest(service.key, world)
	local hasSpecialties = service.key == "trainer" or service.key == "vendor"
	if hasSpecialties and place then
		local submenu = root:CreateButton(service.label)
		for _, specialty in ipairs(SpecialtyNames(service.key, world)) do
			local specialist = Nearest(service.key, world, specialty)
			submenu:CreateButton(specialty, function()
				return Pick(service.key, specialist)
			end)
		end
		submenu:CreateButton(L["Nearest"], function()
			return Pick(service.key, place)
		end)
		return
	end
	local label = place and service.label or L["%s — unavailable here"]:format(service.label)
	local entry = root:CreateButton(label, function()
		return Pick(service.key, place)
	end)
	entry:SetEnabled(place ~= nil)
end

-- The world map's tracking menu and the minimap's (Blizzard_Minimap/Mainline/Minimap.lua:645, Gethe/wow-ui-source
-- branch forever, tags it MENU_MINIMAP_TRACKING) both carry this submenu.
local function AddTrackingEntry(_, root)
	Build()
	local world = PlayerWorld()
	local submenu = root:CreateButton(L["Nearby services"])
	if not world then
		submenu:CreateTitle(L["Your position is unavailable"])
		return
	end
	if state ~= "ready" then
		submenu:CreateTitle(STATUS[state])
		return
	end
	for _, service in ipairs(SERVICES) do
		AddService(submenu, service, world)
	end
end

Open = function()
	if InCombatLockdown() then
		return
	end
	-- The services menu opens over the world map. Under the gamepad interface neither the map nor a menu the addon
	-- opens gets past the client (#158), so the map's own tracking menu, which the game opens, lists the services.
	-- The index starts loading either way.
	if ns.GamepadUI() then
		Build()
		ns.Print(L["Open the world map and choose Nearby services in its tracking menu."])
		return
	end
	ns.OpenWorldMap()
	menuOpen = true
	Build()
	local world = PlayerWorld()
	MenuUtil.CreateContextMenu(WorldMapFrame or UIParent, function(_, root)
		root:AddMenuReleasedCallback(Close)
		root:CreateTitle(L["Nearby services"])
		if state ~= "ready" then
			root:CreateTitle(STATUS[state])
			return
		end
		if not world then
			root:CreateTitle(L["Your position is unavailable"])
			return
		end
		for _, service in ipairs(SERVICES) do
			AddService(root, service, world)
		end
	end)
end

---@class SPFNearbyServices
---@field Nearest fun(key: string, world: SPFPoint, specialty?: string): SPFNearbyPlace?
---@field Index fun(): table<string, SPFNearbyPlace[]>
---@field State fun(): string
---@class SPFNearbyPlace
---@field id integer
---@field name string
---@field specialty? string
---@field map integer
---@field x number
---@field y number
---@field world SPFPoint
ns.NearbyServices = {
	Nearest = Nearest,
	Index = function()
		return index
	end,
	State = function()
		return state
	end,
}
ns.Init(function()
	Build()
	if WorldMapFrame and WorldMapFrame.HookScript then
		WorldMapFrame:HookScript("OnHide", Close)
	end
	ns.ModifyMenu("MENU_WORLD_MAP_TRACKING", "nearby", AddTrackingEntry)
	ns.ModifyMenu("MENU_MINIMAP_TRACKING", "nearby", AddTrackingEntry)
	SLASH_SPFNEAR1 = "/spfnear"
	SlashCmdList.SPFNEAR = function(message)
		local key = string.lower((message or ""):match("^%s*(.-)%s*$"))
		local world = PlayerWorld()
		if key ~= "" and state == "ready" and world then
			for _, service in ipairs(SERVICES) do
				if service.key == key then
					Navigate(key, Nearest(key, world))
					return
				end
			end
		end
		Open()
	end
end)
