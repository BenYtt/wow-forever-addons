---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- TomTom's /way: `/way [#mapID] [zone] x y [title]`, with x and y as percentages of the map. With no map ID and no
-- zone, the point is on the map you stand on. A decimal comma reads as a point, and a comma or point straight after
-- x separates it from y, as TomTom reads them. The command plans a journey to that spot, the same way a Shift-click
-- on the world map does. /way is registered only while TomTom has not loaded (nor is enabled to load after
-- Shortest Path) and no other addon has taken it; `/path way` always works.

-- Zone names as the client spells them, folded: the suite's one fold from Forever Core's Core/Text.lua (lower case,
-- accents gone), then without spaces or punctuation, so "dun garok" finds "Dûn Garok" and "dunmorogh" still finds
-- "Dun Morogh".
---@param name string
---@return string
local function Fold(name)
	return (ns.Text.Fold(name):gsub("[%s%p]", ""))
end

-- Every map under the world the player stands in, by folded name. Built once, on the first /way that names a zone.
---@type table<string, UiMapDetails>?
local zones

---@return table<string, UiMapDetails>
local function Zones()
	if zones then
		return zones
	end
	local root = C_Map.GetBestMapForUnit("player")
	local info = root and C_Map.GetMapInfo(root)
	while info and info.parentMapID and info.parentMapID ~= 0 do
		local parent = C_Map.GetMapInfo(info.parentMapID)
		if not parent then
			break
		end
		root, info = info.parentMapID, parent
	end
	local found = {}
	for _, child in ipairs(root and C_Map.GetMapChildrenInfo(root, nil, true) or {}) do
		local key = Fold(child.name or "")
		local held = found[key]
		-- A city and a micro map can share a name; the zone is the one a player means.
		if key ~= "" and (not held or held.mapType ~= Enum.UIMapType.Zone and child.mapType == Enum.UIMapType.Zone) then
			found[key] = child
		end
	end
	if next(found) then
		zones = found
	end
	return found
end

-- The map a zone name means: its exact name, the one zone it begins, or else the one zone it is part of, as TomTom
-- reads "barrens" as The Barrens. An error says why there is none.
---@param name string
---@return integer? map, string? error
local function ZoneMap(name)
	local key, list = Fold(name), Zones()
	if list[key] then
		return list[key].mapID
	end
	local matches = {}
	for _, inside in ipairs({ false, true }) do
		for folded, info in pairs(list) do
			local at = key ~= "" and folded:find(key, 1, true)
			if at and (inside or at == 1) then
				matches[#matches + 1] = info.name
			end
		end
		if matches[1] then
			break
		end
	end
	if #matches == 1 then
		return list[Fold(matches[1])].mapID
	end
	if #matches > 1 then
		table.sort(matches)
		return nil, string.format(L["%s could be %s."], name, table.concat(matches, ", "))
	end
	return nil, string.format(L["no zone called %s."], name)
end

---@param token string?
---@return number?
local function Percent(token)
	-- "45", "45.5", "45." and ".5", as TomTom's tonumber reads them.
	local value = token and (token:match("^%d+%.?%d*$") or token:match("^%.%d+$")) and tonumber(token)
	if value and value >= 0 and value <= 100 then
		return value
	end
end

-- The map, the point on it (0-1) and the title a /way line names, or nil and why not.
---@param message string
---@return integer? map, number? x, number? y, string? title, string? error
function ns.ParseWay(message)
	-- "45.2, 61.8" and "45, 61": the separator straight after x is not a decimal one.
	message = message:gsub("(%d)[%.,]%s+(%d)", "%1 %2")
	local tokens = {}
	for token in message:gmatch("%S+") do
		tokens[#tokens + 1] = (token:gsub("(%d),(%d)", "%1.%2"))
	end
	local map, at
	local id = tokens[1] and tokens[1]:match("^#(%d+)$")
	if id then
		map, at = tonumber(id), 2
		if not (map and C_Map.GetMapInfo(map)) then
			return nil, nil, nil, nil, string.format(L["no map %s."], tokens[1])
		end
	else
		-- The zone is every word before the first two numbers.
		for index = 1, #tokens - 1 do
			if Percent(tokens[index]) and Percent(tokens[index + 1]) then
				at = index
				break
			end
		end
		if not at then
			return nil, nil, nil, nil, L["/way [zone] x y [title], with x and y from 0 to 100."]
		end
		if at > 1 then
			local err
			map, err = ZoneMap(table.concat(tokens, " ", 1, at - 1))
			if not map then
				return nil, nil, nil, nil, err
			end
		else
			map = C_Map.GetBestMapForUnit("player")
			if not map then
				return nil, nil, nil, nil, L["no journey can be planned to that spot."]
			end
		end
	end
	local x, y = Percent(tokens[at]), Percent(tokens[at + 1])
	if not (x and y) then
		return nil, nil, nil, nil, L["/way [zone] x y [title], with x and y from 0 to 100."]
	end
	local title = table.concat(tokens, " ", at + 2)
	return map, x / 100, y / 100, title ~= "" and title or nil
end

-- A /way line, from /way itself or /path way.
---@param message string
function ns.Way(message)
	if not ns.db.journey then
		ns.Print(L["Journeys are off. Turn on Shift-click to plan journeys in settings."])
		return
	end
	local map, x, y, title, err = ns.ParseWay(message)
	if not (map and x and y) then
		ns.Print(err or L["no journey can be planned to that spot."])
		return
	end
	ns.JourneyToMapPoint(map, x, y, title)
end

-- Whether TomTom has /way, or takes it as it loads after Shortest Path, or another addon has a command spelled /way.
-- Slash commands are globals named SLASH_<NAME><n>. By login every addon that loads has loaded.
---@param loggedIn boolean
---@return boolean
local function WayTaken(loggedIn)
	if loggedIn and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("TomTom") then
		return true
	end
	if not loggedIn and ns.TomTomEnabled and ns.TomTomEnabled() then
		return true
	end
	for key, value in pairs(_G) do
		if
			type(key) == "string"
			and type(value) == "string"
			and key ~= "SLASH_SHORTESTPATHFOREVERWAY1"
			and key:find("^SLASH_")
			and value:lower() == "/way"
		then
			return true
		end
	end
	return false
end

---@param claim boolean
local function Claim(claim)
	SLASH_SHORTESTPATHFOREVERWAY1 = claim and "/way" or nil
	SlashCmdList.SHORTESTPATHFOREVERWAY = claim and ns.Way or nil
end

-- /way is claimed as Shortest Path loads, ahead of addons such as Polestar that claim it at login only while it is
-- free, and looked at again at login, once every addon has loaded: TomTom, or another addon that took /way without
-- looking, keeps it.
ns.Init(function()
	Claim(not WayTaken(false))
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_LOGIN")
	login:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_LOGIN")
		Claim(not WayTaken(true))
	end)
end)
