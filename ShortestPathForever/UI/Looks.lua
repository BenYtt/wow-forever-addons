---@class SPFNamespace
local ns = select(2, ...)

-- What a stop is, drawn as the game draws it: a caller's kind (API.lua) turns the stop's map pin into the thing
-- itself, a quest giver's "!" or a hand-in's "?", so the pin never hides the mark it stands on. The atlases are the
-- Forever build's (UiTextureAtlasMember, 1.60.1.69913), and each is still looked up in the client: a kind whose art
-- is missing keeps the plain pin.
---@type table<SPFAPIStopKind, string[]>
local ATLASES = {
	pickup = { "QuestNormal" },
	turnin = { "QuestTurnin" },
	objective = { "questobjective", "SideInProgressquesticon" },
	innkeeper = { "innkeeper" },
	dungeon = { "dungeon" },
}
-- The minimap tracking menu's own icons (ManifestInterfaceData, same build). A file has no lookup, so these are
-- trusted to the build's manifest.
---@type table<SPFAPIStopKind, string>
local FILES = {
	trainer = "Interface\\Minimap\\Tracking\\Class",
	battlemaster = "Interface\\Minimap\\Tracking\\BattleMaster",
}
-- The map's own dock, lift, tram and portal icons (Map.lua).
local TRANSPORTS = { boat = true, zeppelin = true, lift = true, tram = true, portal = true }
local TAXI = { Alliance = "taxinode_alliance", Horde = "taxinode_horde" }

---@type table<string, true>
local kinds = { flightmaster = true }
for kind in pairs(ATLASES) do
	kinds[kind] = true
end
for kind in pairs(FILES) do
	kinds[kind] = true
end
for kind in pairs(TRANSPORTS) do
	kinds[kind] = true
end

-- The kind a caller named, when Shortest Path knows it; anything else leaves the stop's plain pin.
---@param value any
---@return SPFAPIStopKind?
function ns.StopKind(value)
	if canaccessvalue(value) and type(value) == "string" and kinds[value] then
		return value
	end
end

---@class SPFStopArt
---@field atlas? string
---@field file? string
---@field transport? boolean

---@type table<string, SPFStopArt|false>
local found = {}

---@param kind SPFAPIStopKind
---@return SPFStopArt?
local function Art(kind)
	if found[kind] == nil then
		found[kind] = false
		if TRANSPORTS[kind] then
			found[kind] = { transport = true }
		elseif FILES[kind] then
			found[kind] = { file = FILES[kind] }
		else
			local candidates = ATLASES[kind]
			if kind == "flightmaster" then
				candidates = { TAXI[UnitFactionGroup("player")] or "taxinode_neutral", "taxinode_neutral" }
			end
			for _, atlas in ipairs(candidates) do
				if ns.Art.Info(atlas) then
					found[kind] = { atlas = atlas }
					break
				end
			end
		end
	end
	return found[kind] or nil
end

-- Draws the kind on `texture`, fitted into a `size` square; false, leaving the texture alone, when the client has
-- no art for it.
---@param texture Texture
---@param kind SPFAPIStopKind
---@param size number
---@return boolean
function ns.SetStopLook(texture, kind, size)
	local art = Art(kind)
	if not art then
		return false
	elseif art.transport then
		ns.SetTransportIcon(texture, kind --[[@as SPFMode]], size)
	elseif art.file then
		ns.Art.Icon(texture, art.file, size)
	else
		ns.Art.Fit(texture, art.atlas --[[@as string]], size, size)
	end
	return true
end
