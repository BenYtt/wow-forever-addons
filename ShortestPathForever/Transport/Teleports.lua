---@class SPFNamespace
local ns = select(2, ...)

-- The personal teleports this character can cast now, for the planner. The client names the bind point but has no
-- position for it, so it is where you stood when you bound (beside the innkeeper), or where a Hearthstone or Astral
-- Recall last set you down, kept with that name. Bound anywhere else since (before this addon, or on another
-- client), the names disagree: no bind teleport until you bind or hearth again.

local places, placesKey, sources = {}, nil, {}
-- The setting off: no teleports for any caller.
local NONE = {}

---@return SPFBindPoint?
local function Bind()
	local bind, name = ns.charDB.bind, GetBindLocation()
	if bind and canaccessvalue(name) and bind.name == name then
		return bind
	end
end

---@param teleport SPFTeleport
local function Known(teleport)
	if teleport.item then
		return C_Item.GetItemCount(teleport.item) > 0
	end
	return C_SpellBook.IsSpellKnown(teleport.spell)
end

---@param teleport SPFTeleport
local function Stocked(teleport)
	for item, count in pairs(teleport.reagents or {}) do
		if C_Item.GetItemCount(item) < count then
			return false
		end
	end
	return true
end

-- Seconds of cooldown left, or nil while the client keeps it secret.
---@param teleport SPFTeleport
---@return number?
local function Cooldown(teleport)
	local start, duration
	if teleport.item then
		start, duration = C_Item.GetItemCooldown(teleport.item)
	else
		local info = C_Spell.GetSpellCooldown(teleport.spell)
		if info then
			start, duration = info.startTime, info.duration
		end
	end
	if not (canaccessvalue(start) and canaccessvalue(duration)) then
		return nil
	end
	return start and duration and start > 0 and math.max(0, start + duration - GetTime()) or 0
end

-- The cast time the client reports for the spell now, in ms; the shipped one when it reports none.
---@param teleport SPFTeleport
---@return number
local function CastTime(teleport)
	local info = C_Spell.GetSpellInfo(teleport.spell)
	local cast = info and info.castTime
	return canaccessvalue(cast) and cast and cast > 0 and cast or teleport.cast
end

-- The places keep their identity while the set is unchanged, so the planner keeps its topology; only readiness
-- ([index] = server ms when it can be cast) is read afresh.
---@param now number server ms
---@return SPFTeleportPlace[] places, table<number, number> ready
function ns.UsableTeleports(now)
	if not ns.db.teleports then
		return NONE, NONE
	end
	local bind, known, keys = Bind(), {}, {}
	for _, teleport in ipairs(ns.Teleports) do
		if (teleport.to or (teleport.bind and bind)) and Known(teleport) then
			known[#known + 1] = teleport
			keys[#keys + 1] = teleport.spell
		end
	end
	local key = table.concat(keys, ",") .. (bind and string.format(":%d:%.17g:%.17g", bind.map, bind.x, bind.y) or "")
	if key ~= placesKey then
		placesKey, places, sources = key, {}, known
		for index, teleport in ipairs(known) do
			local to = teleport.to or bind --[[@as SPFPoint]]
			places[index] = {
				map = to.map,
				x = to.x,
				y = to.y,
				z = to.z,
				label = not teleport.to and bind and bind.name or nil,
				bind = teleport.bind,
				spell = teleport.spell,
				item = teleport.item,
				cast = CastTime(teleport),
			}
		end
	end
	local ready = {}
	for index, teleport in ipairs(sources) do
		local wait = Stocked(teleport) and Cooldown(teleport)
		if wait then
			ready[index] = now + wait * 1000
		end
	end
	return places, ready
end

-- A bind teleport's landing: after the cast, the travel clock samples where you are, and the first jump faster than
-- any mount (or onto another map, or out of an instance with no position) is where it set you down. A loading
-- screen's end looks again; the wait ends a minute after the cast, or after the loading screen it ends in.
local JUMP_YARDS, JUMP_SPEED, WAIT, AFTER_LOADING = 100, 20, 60, 10
local bindSpells = {}
---@type {name: string, map?: number, x?: number, y?: number, at: number, deadline: number}?
local landing

local function Record(name, map, x, y)
	local bind = ns.charDB.bind
	-- The same inn, already known beside its innkeeper or from an earlier landing: kept, so its places stand.
	if bind and bind.name == name and bind.map == map and (bind.x - x) ^ 2 + (bind.y - y) ^ 2 <= JUMP_YARDS ^ 2 then
		return
	end
	ns.charDB.bind = { name = name, map = map, x = x, y = y }
end

local function Sample()
	local wait = landing
	if not wait then
		return
	end
	local now = GetTime()
	if now > wait.deadline then
		landing = nil
		return
	end
	local name = GetBindLocation()
	if not canaccessvalue(name) then
		return
	end
	if name ~= wait.name then
		landing = nil
		return
	end
	local x, y, _, map = ns.JourneyPosition()
	if not (x and y and map) then
		wait.map, wait.x, wait.y = nil, nil, nil
		return
	end
	local limit = JUMP_YARDS + JUMP_SPEED * (now - wait.at)
	if not wait.map or map ~= wait.map or (x - wait.x) ^ 2 + (y - wait.y) ^ 2 > limit ^ 2 then
		landing = nil
		Record(name, map, x, y)
		return
	end
	wait.map, wait.x, wait.y, wait.at = map, x, y, now
end

ns.Init(function()
	for _, teleport in ipairs(ns.Teleports) do
		if teleport.bind then
			bindSpells[teleport.spell] = true
		end
	end
	ns.OnTravelTick(Sample)
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("HEARTHSTONE_BOUND")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function(_, event, _, _, spell)
		if event == "PLAYER_ENTERING_WORLD" then
			if landing then
				landing.deadline = GetTime() + AFTER_LOADING
				Sample()
			end
			return
		end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and not (canaccessvalue(spell) and bindSpells[spell]) then
			return
		end
		local x, y, _, map = ns.JourneyPosition()
		local name = GetBindLocation()
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if canaccessvalue(name) and name then
				local now = GetTime()
				-- Inside an instance there is no position: the first one outside is the landing.
				landing = { name = name, map = map, x = x, y = y, at = now, deadline = now + WAIT }
				if not (x and y) then
					landing.map = nil
				end
				ns.WakeTravel()
			end
		elseif x and y and map and canaccessvalue(name) then
			landing = nil
			ns.charDB.bind = { name = name, map = map, x = x, y = y }
		else
			landing = nil
			ns.charDB.bind = nil
		end
	end)
end)
