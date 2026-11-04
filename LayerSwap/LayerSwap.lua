-- LayerSwap 1.14 - host + panel.
-- A player changes layer by joining a group whose leader stands on another layer. A host
-- is somebody who invites whoever asks. This file is the host, the reading of the player's
-- own layer from creature GUIDs, the request for a swap, and the small panel on top of them.
-- What happens is written to SavedVariables so it can be read from disk after a /reload.
--
-- Measured on the Forever beta (build 69913, 19 Sep 2026):
--   * a chat sender is "First Surname" with a SPACE and no realm; UnitName("player")
--     returns that combined string, UnitName(otherUnit) returns first, surname
--   * the custom channel arrives with channelBaseName "layer" and zoneChannelID 0,
--     General with zoneChannelID 1
--   * "player" contains "layer" - requests are matched on whole words
--   * Blizzard calls a layer change a shard transfer (SHARD_TRANSFER_IMMINENT / SHARD_TRANSFER)
local ADDON = ...

-- One file for WoW Forever and for the Classic clients (Era 1.15, TBC Anniversary 2.5). Forever
-- has Blizzard's shard-transfer system; Era and Anniversary have none of it (their API docs list
-- no SHARD_TRANSFER, no GetEvictionTimeRemaining, 27 Sep 2026): there a move shows only in the
-- creature GUIDs, and names are "Name-Realm".
local TOC = (type(GetBuildInfo) == "function" and select(4, GetBuildInfo())) or 16001
local FOREVER = TOC >= 16000 and TOC < 20000
local TBC = TOC >= 20000 and TOC < 30000

LayerSwapDB = LayerSwapDB or {}

local LAYER_CHANNEL = "layer"
local PARTY_MAX = 5
local PLAYER_COOLDOWN = 60      -- seconds before the same player is invited again
local INVITE_SPACING = 1        -- seconds between two invites
local PENDING_TTL = 60          -- an unanswered invite stops counting after this long
local WATCH_AFTER_INVITE = 6    -- seconds of system/error messages logged after an invite
local LOG_MAX = 1000            -- 1.14 writes a 'spot' entry per ask on top of the rest (about 100 bytes each)
-- The chat line is a plain "inv layer" that anyone can read. What LayerSwap knows about the
-- layer (the one wanted, or the one being left) goes along out of sight as an addon message
-- in the layer channel - a "note": "want <id>", "not <id>" or "any". Only LayerSwap reads it.
-- On Forever a "zone <map id>" note goes just before it, and a host in that zone who stands on
-- the asker's own layer whispers "same" back instead of an invite that would change nothing; a
-- host that has not read its own layer yet stays out too (1.9).
-- 1.10: the zone and the layer also ride in the chat line, as a short tag (routeTag below) - on
-- 10 Oct 2026 the notes came 68-139 s late while the line took 0.13-0.34 s. The notes still go
-- out for hosts older than 1.10.
local NOTE_PREFIX = "LayerSwap"
local NOTE_TTL = 10             -- seconds a host keeps an asker's note
-- The note can land after the chat line although it was sent first (beta 26 Sep 2026: same
-- frame, just after). A plain "inv layer" - LayerSwap's own line - waits this long for it.
local NOTE_WAIT = 0.5
-- 1.14: an ask also carries the asker's position, as a note of its own ("pos <zone map id> <x> <y>",
-- whole yards), for a host that skips askers near it (the option "Skip askers near you", see
-- Near.check). Where the yards come from is one constant: "world" = UnitPosition, which needs no
-- map; "map" = the position on the zone map times the map's size in yards, the fallback, under
-- its own note kind ("posm") so the two frames are never compared with each other.
-- Everything behind it lives in this one table: Lua 5.1 allows 200 locals in a file, and this
-- file is close to that.
local Near = { SOURCE = "world", DEFAULT = 150, MIN = 50, MAX = 1000, later = {} }
Near.KIND = Near.SOURCE == "world" and "pos" or "posm"

-- The option "Skip askers near you" (1.14): off unless ticked, and its distance in yards.
function Near.on()
  return FOREVER and LayerSwapDB.skipNear == true
end

function Near.yards()
  local v = tonumber(LayerSwapDB.skipNearYards)
  if not v or v ~= v then return Near.DEFAULT end
  return math.max(Near.MIN, math.min(Near.MAX, math.floor(v / 10 + 0.5) * 10))
end

local hosting = false
local hosted = {}               -- [fullName] = true: players this session invited
local lastInvite = {}           -- [fullName] = GetTime() of the last invite
local pending = {}              -- [fullName] = GetTime() of an invite not yet answered
local lastInviteAt = 0
local watchUntil = 0
local stats = { requests = 0, askers = 0, invites = 0, joined = 0, skipped = 0 }
local askers = {}                -- [fullName] = true: the players who asked this session, host on or off
local notes = {}                -- [First Surname] = { want, avoid, at, zone, zoneAt, from, pos, posAt }: what an asker's notes said
local requestedAt = {}          -- [First Surname] = GetTime() of their last request line
local came = {}                 -- [fullName] = true: a player we invited who joined
-- Our own ask waits for an invite (waitingAsk, below): the host then invites nobody - a group of
-- our own would keep that invite out (Adam, 11 Oct 2026: a guest joined while he asked, and two
-- hosts' invites to him bounced off "already in a group").
local ownAskWaiting = function() return false end
-- id of the layer the player stands on, nil while unknown (read in "which layer is this?");
-- declared up here because the host needs it to answer requests that name a layer
local current

-- ---------------------------------------------------------------------------------------
-- helpers

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, s = pcall(issecretvalue, v)
  return ok and s == true
end

local function say(msg)
  print("|cff7fd4ffLayerSwap|r: " .. msg)
end

local function log(kind, a, b, c, d)
  local db = LayerSwapDB
  db.log = db.log or {}
  if #db.log >= LOG_MAX then return end
  db.log[#db.log + 1] = { t = date("%H:%M:%S"), g = math.floor(GetTime() * 100) / 100, kind = kind, a = a, b = b, c = c, d = d }
end

local function leaveParty()
  local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
  if leave then leave() end
end

local function surnameSeparator()
  local c = Constants and Constants.CharacterNameSeparatorConsts
  local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
  if type(sep) == "string" and sep ~= "" then return sep end
  return " "
end

-- Classic: every name as "Name-Realm", the shape chat senders have and invites take.
local function withRealm(name)
  if FOREVER or type(name) ~= "string" or name == "" or string.find(name, "-", 1, true) then return name end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName()
  if type(realm) ~= "string" or realm == "" then return name end
  return name .. "-" .. realm
end

-- Forever: "First Surname" for any unit. The player's own UnitName already carries both parts
-- in the first return; every other unit returns them separately.
-- Classic: "Name-Realm" (UnitName's second return is the realm, nil on our own).
local function fullName(unit)
  local first, surname = UnitName(unit)
  if isSecret(first) or type(first) ~= "string" or first == "" then return nil end
  if not FOREVER then
    if type(surname) == "string" and surname ~= "" then return first .. "-" .. surname end
    return withRealm(first)
  end
  if not isSecret(surname) and type(surname) == "string" and surname ~= "" then
    return first .. surnameSeparator() .. surname
  end
  return first
end

-- ---------------------------------------------------------------------------------------
-- is this message a request?

local REQUEST_WORDS = { inv = true, invite = true, hop = true, swap = true, switch = true, change = true,
                        pls = true, plz = true, please = true, need = true, lf = true }
-- Whole words that mean the line is about something else.
local BLOCK_WORDS = { wts = true, wtb = true, wtt = true, lfm = true, lfg = true, guild = true, raid = true,
                      enchant = true, enchanting = true, recruiting = true, selling = true, buying = true,
                      worldbuffs = true, autoinv = true }
local BLOCK_PHRASES = { "what layer", "which layer", "how many layer", "auto inv", "pst for" }
-- General and guild chat: an ask is short ("need layer inv", "can i get a layer swap")
local ASK_MAX_WORDS = 10

local function wordsOf(msg)
  local set = {}
  for w in string.gmatch(msg, "%a+") do set[w] = true end
  return set
end

-- where: "layer" (the custom channel), "general", "guild" or "whisper". Returns true/false, reason.
local function isRequest(msg, where)
  if isSecret(msg) or type(msg) ~= "string" then return false, "unreadable" end
  local lower = string.lower(msg)
  local words = wordsOf(lower)
  for w in pairs(words) do
    if BLOCK_WORDS[w] then return false, "blocked word " .. w end
  end
  for _, phrase in ipairs(BLOCK_PHRASES) do
    if string.find(lower, phrase, 1, true) then return false, "blocked phrase" end
  end
  local saysLayer = words.layer or words.layers
  local asks = false
  for w in pairs(words) do
    if REQUEST_WORDS[w] then asks = true; break end
  end
  if where == "general" or where == "guild" then
    -- people talk there: a layer word alone is chatter, not an ask - and so is a long sentence
    -- that happens to hold both (beta 8 Oct 2026: twenty words about layers, "need" among them)
    if saysLayer and asks then
      if select(2, string.gsub(lower, "%S+", "")) > ASK_MAX_WORDS then return false, "too long for an ask" end
      return true
    end
    return false, saysLayer and "no request word" or "no layer word"
  end
  -- the layer channel and whispers exist for this: either word is enough
  if saysLayer or words.inv or words.invite then return true end
  return false, "no layer word"
end

-- Nova World Buffs (Classic): the layer numbers Classic players use. NWB numbers the layers it
-- knows and shares them between its users, so "Layer 2" means the same to all of them, and
-- AutoLayer asks and answers with those numbers. Forever has no NWB: letters there.
local function nwbLayer()
  if FOREVER then return nil end
  local n = tonumber(NWB_CurrentLayer)
  if n and n > 0 and n == math.floor(n) then return n end
end

local function nwbLayerCount()
  if FOREVER or not LibStub then return nil end
  local ok, ace = pcall(LibStub, "AceAddon-3.0", true)
  if not ok or type(ace) ~= "table" or type(ace.GetAddon) ~= "function" then return nil end
  local found, nwb = pcall(ace.GetAddon, ace, "NovaWorldBuffs", true)
  local known = found and type(nwb) == "table" and type(nwb.data) == "table" and nwb.data.layers
  if type(known) ~= "table" then return nil end
  local count = 0
  for _ in pairs(known) do count = count + 1 end
  return count > 0 and count or nil
end

-- The map the player stands on - AutoLayer's zone for TBC requests.
local function mapHere()
  local ok, id = pcall(C_Map and C_Map.GetBestMapForUnit, "player")
  if ok and type(id) == "number" and id > 0 then return tostring(id) end
end

-- Forever: the zone a unit stands in, as a map id every client shares (zone names come in the
-- client's language). A cave or a building inside a zone counts as the zone - the layer is the
-- zone's, its id changes at a zone border. nil when the game does not say.
local ZONE_MAP = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local function zoneOf(unit)
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, unit)
  if not ok or isSecret(id) or type(id) ~= "number" or id <= 0 then return nil end
  local zone = id
  for _ = 1, 6 do
    local found, info = pcall(C_Map.GetMapInfo, zone)
    if not found or type(info) ~= "table" or isSecret(info.mapType) or type(info.mapType) ~= "number" then break end
    if info.mapType == ZONE_MAP then return zone end
    local up = info.parentMapID
    if info.mapType < ZONE_MAP or isSecret(up) or type(up) ~= "number" or up <= 0 then break end
    zone = up
  end
  return id
end

local function zoneName(map)
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, map)
  local name = ok and type(info) == "table" and info.name
  if isSecret(name) or type(name) ~= "string" or name == "" then return nil end
  return name
end

-- 1.14: the player's own position, for the ask's pos note and for a host that skips askers
-- near it. x and y in whole yards, and the zone map id the two sides compare on (the number
-- the route tag carries). nil and a reason when the game gives nothing readable - no zone, a
-- missing function, a secret value. Forever only.
function Near.read()
  if not FOREVER then return nil, "not Forever" end
  local zone = zoneOf("player")
  if not zone then return nil, "zone unknown" end
  if Near.SOURCE == "world" then
    if type(UnitPosition) ~= "function" then return nil, "no UnitPosition" end
    local ok, a, b = pcall(UnitPosition, "player")
    if not ok or isSecret(a) or isSecret(b) or type(a) ~= "number" or type(b) ~= "number" then return nil, "unreadable" end
    return { kind = Near.KIND, ref = tostring(zone), x = math.floor(a + 0.5), y = math.floor(b + 0.5) }
  end
  if not (C_Map and C_Map.GetPlayerMapPosition and C_Map.GetMapWorldSize) then return nil, "no map position API" end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, zone, "player")
  if not ok or type(pos) ~= "table" or isSecret(pos) then return nil, "no map position" end
  local px, py = pos.x, pos.y
  if type(pos.GetXY) == "function" then
    local okXY, gx, gy = pcall(pos.GetXY, pos)
    if okXY then px, py = gx, gy end
  end
  local okSize, w, h = pcall(C_Map.GetMapWorldSize, zone)
  if not okSize or isSecret(w) or isSecret(h) or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
    return nil, "map size unknown"
  end
  if isSecret(px) or isSecret(py) or type(px) ~= "number" or type(py) ~= "number" then return nil, "unreadable" end
  return { kind = Near.KIND, ref = tostring(zone), x = math.floor(px * w + 0.5), y = math.floor(py * h + 0.5) }
end

function Near.between(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- Every reading behind a position, raw, for the log: what the live client answers has not been
-- seen (the beta closed before this was built). One entry per ask and per /ls spot, with the
-- distance from the last reading, so a walk of ten seconds shows the yard scale.
function Near.probe(label)
  local function plain(v)
    if isSecret(v) then return "secret" end
    -- whole numbers (ids, yards) as they are; a map fraction with five decimals, which is under a
    -- yard on any zone map, so the two frames can be compared from the log
    if type(v) == "number" then return (v == math.floor(v)) and string.format("%.0f", v) or string.format("%.5f", v) end
    return tostring(v)
  end
  local best
  if C_Map and C_Map.GetBestMapForUnit then
    local ok, v = pcall(C_Map.GetBestMapForUnit, "player")
    if ok then best = v end
  end
  local zone = zoneOf("player")
  local raw = { "bestmap " .. plain(best), "zone " .. plain(zone) }
  if type(UnitPosition) == "function" then
    local ok, r1, r2, r3, r4 = pcall(UnitPosition, "player")
    raw[#raw + 1] = ok and ("unit " .. plain(r1) .. " " .. plain(r2) .. " " .. plain(r3) .. " " .. plain(r4)) or "unit error"
  else
    raw[#raw + 1] = "unit none"
  end
  local px, py, w, h
  if zone and C_Map and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, zone, "player")
    if ok and type(pos) == "table" and not isSecret(pos) then
      px, py = pos.x, pos.y
      if type(pos.GetXY) == "function" then
        local okXY, gx, gy = pcall(pos.GetXY, pos)
        if okXY then px, py = gx, gy end
      end
    end
    raw[#raw + 1] = ok and ("map " .. plain(px) .. " " .. plain(py)) or "map error"
  end
  if zone and C_Map and C_Map.GetMapWorldSize then
    local ok, a, b = pcall(C_Map.GetMapWorldSize, zone)
    if ok then w, h = a, b end
    raw[#raw + 1] = ok and ("size " .. plain(w) .. " " .. plain(h)) or "size error"
  end
  local combat = false
  if type(InCombatLockdown) == "function" then
    local ok, v = pcall(InCombatLockdown)
    combat = ok and not isSecret(v) and v == true
  end
  local p, why = Near.read()
  -- the distance from the last reading, in the chosen frame and on the map, so one walk shows
  -- whether the two scales agree (a reading inside a mine may lack the map one)
  local moved
  if p and Near.lastProbe and p.ref == Near.lastProbe.ref then
    moved = string.format("%d yards from the last reading", math.floor(Near.between(p, Near.lastProbe) + 0.5))
  end
  local m
  if zone and not isSecret(px) and not isSecret(py) and not isSecret(w) and not isSecret(h)
     and type(px) == "number" and type(py) == "number" and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
    m = { ref = tostring(zone), x = px * w, y = py * h }
    if Near.lastProbeMap and Near.lastProbeMap.ref == m.ref then
      moved = (moved and (moved .. ", ") or "") .. string.format("%d yards on the map", math.floor(Near.between(m, Near.lastProbeMap) + 0.5))
    end
  end
  log("spot", label, p and (p.kind .. " " .. p.ref .. " " .. p.x .. " " .. p.y) or ("none: " .. tostring(why)),
      table.concat(raw, "; "), (combat and "combat" or "no combat") .. (moved and (", " .. moved) or ""))
  if p then Near.lastProbe = p end
  if m then Near.lastProbeMap = m end
  return p, why, raw, moved
end

-- AutoLayer on TBC Anniversary ignores a request without its header (layerSegments is on by
-- default) and turns down one from another zone: "<AL2V1_9_7Z1946> inv layer 1,3". The version
-- in it must be 1.9.5 or later for its hosts to answer; 1.9.7 is its current one (15 Sep 2026).
local function autoLayerHeader()
  return string.format("<AL2V%d_%d_%dZ%s>", 1, 9, 7, mapHere() or "0")
end

-- AutoLayer's reading of a request: layer numbers 1-20 and ranges ("1-3"), turned around by
-- a word like "not" or "except". Returns the numbers (sorted) and whether they are the ones
-- NOT wanted.
local INVERT_WORDS = { "not", "off", "except", "but", "out", "other than", "besides", "apart from" }
local function nwbNumbersIn(msg)
  local lower, set, list = string.lower(msg), {}, {}
  for num in string.gmatch(lower, "%d+") do
    local n = tonumber(num)
    if n >= 1 and n <= 20 then set[n] = true end
  end
  for a, b in string.gmatch(lower, "(%d+)%-(%d+)") do
    a, b = tonumber(a), tonumber(b)
    if a > b then a, b = b, a end
    for n = math.max(a, 1), math.min(b, 20) do set[n] = true end
  end
  for n in pairs(set) do list[#list + 1] = n end
  table.sort(list)
  local invert = false
  for _, w in ipairs(INVERT_WORDS) do
    if string.find(lower, "%f[%w]" .. w .. "%f[%W]") then invert = true; break end
  end
  return list, invert
end

-- LayerSwap 1.0 and 1.0.1 named the layer in the chat line itself: "inv layer 4621-72594"
-- wants that one, "inv layer, not 4621-58389" any layer but that one. Newer versions send the
-- same in a note (see NOTE_PREFIX). Returns the wanted id, the avoided id (either may be nil).
local function namedLayer(msg)
  if isSecret(msg) or type(msg) ~= "string" then return nil, nil end
  local lower = string.lower(msg)
  if not FOREVER then return nil, nil end   -- Classic chat carries NWB numbers, not ids
  local avoid = string.match(lower, "not%s+(%d%d%d+%-%d+)")
  for id in string.gmatch(lower, "(%d%d%d+%-%d+)") do
    if id ~= avoid then return id, avoid end
  end
  return nil, avoid
end

-- Forever, 1.10: the route at the end of the chat line - "inv layer <LS 1431 not 6782-1753>":
-- the asker's zone (its map id) and the layer it leaves, or "want <id>" for one layer. The line
-- arrives on time when the notes do not (10 Oct 2026), and a host answers only a route it can
-- read (see answer). Hosts from 1.0 on read "not <id>" / "want <id>" in it (namedLayer).
local function routeTag(msg)
  if not FOREVER or isSecret(msg) or type(msg) ~= "string" then return nil end
  local body = string.match(msg, "<LS([^<>]*)>")
  if not body then return nil end
  return { zone = string.match(body, "^%s*(%d+)%s") or string.match(body, "^%s*(%d+)%s*$"),
           want = string.match(body, "want%s+(%d+%-%d+)"), avoid = string.match(body, "not%s+(%d+%-%d+)") }
end

local function routeText(zone, want, avoid)
  local parts = { "<LS" }
  if zone then parts[#parts + 1] = tostring(zone) end
  if want then parts[#parts + 1] = "want " .. want elseif avoid then parts[#parts + 1] = "not " .. avoid end
  return table.concat(parts, " ") .. ">"
end

-- ---------------------------------------------------------------------------------------
-- may we invite right now?

local function pendingCount()
  local now, n = GetTime(), 0
  for name, at in pairs(pending) do
    if now - at > PENDING_TTL then pending[name] = nil else n = n + 1 end
  end
  return n
end

-- The group as full names, without the player. nil when a member cannot be read.
local function groupMembers()
  local list = {}
  if not IsInGroup() then return list end
  if IsInRaid() then return nil end
  for i = 1, PARTY_MAX - 1 do
    local unit = "party" .. i
    if UnitExists(unit) then
      local name = fullName(unit)
      if not name then return nil end
      list[#list + 1] = name
    end
  end
  return list
end

local function canInvite()
  if ownAskWaiting() then return false, "our own ask waits for an invite" end
  if IsInInstance() then return false, "in an instance" end
  local members = groupMembers()
  if not members then return false, "in a raid or a group that cannot be read" end
  for _, name in ipairs(members) do
    if not hosted[name] then return false, "in a group with " .. name .. ", who was not invited by LayerSwap" end
  end
  if #members > 0 and not UnitIsGroupLeader("player") then return false, "not the group leader" end
  if 1 + #members + pendingCount() >= PARTY_MAX then return false, "group is full - /ls kick clears it" end
  return true
end

local function invite(name, source)
  if pending[name] then return end          -- an invite to this player is already out
  local now = GetTime()
  if now - lastInviteAt < INVITE_SPACING then
    C_Timer.After(INVITE_SPACING, function()
      if hosting then invite(name, source) end
    end)
    return
  end
  local ok, why = canInvite()
  if not ok then
    stats.skipped = stats.skipped + 1
    log("skip", name, why, source)
    return
  end
  lastInviteAt, lastInvite[name], pending[name], hosted[name] = now, now, now, true
  watchUntil = now + WATCH_AFTER_INVITE
  stats.invites = stats.invites + 1
  -- No hardware event is behind this call: it runs from a chat event or a timer.
  local called, err = pcall((C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit, name)
  log("invite", name, called and "called" or ("error: " .. tostring(err)), source)
  if called then say("invited " .. name .. " (" .. source .. ").") end
end

-- The client's own line for a refusal, with its "%s" (the name) taken out: every part of it in
-- the text. Reads in any language the client runs in.
local function saysGlobal(text, global)
  local s = _G[global]
  if isSecret(s) or type(s) ~= "string" or not string.find(s, "%s", 1, true) then return false end
  local found = false
  for part in string.gmatch(s .. "%s", "(.-)%%s") do
    part = strtrim(part)
    if part ~= "" then
      if not string.find(text, part, 1, true) then return false end
      found = true
    end
  end
  return found
end

-- The game's answer when our invite cannot count: the asker sits in a group already (the one
-- refusal in the logs, 8 Oct 2026: "X is already in a group." - a guest of another host), or
-- another host's invite got there first. nil for anything else.
local function refusal(text)
  local lower = string.lower(text)
  if string.find(lower, "already in a group", 1, true) or saysGlobal(text, "ERR_ALREADY_IN_GROUP_S") then
    return "already in a group"
  end
  if string.find(lower, "already been invited", 1, true) then return "already invited by another host" end
end

-- ---------------------------------------------------------------------------------------
-- host: chat and roster

local refresh = function() end      -- replaced once the panel exists
local refreshMini = function() end  -- replaced once the mini line exists
local mini, toggleMini              -- the small line and its switch, set further down

-- Several hosts hear the same ask, and the game lets one invite through; the others would only
-- put the asker on their cooldown, so the next ask goes unanswered (a user on CurseForge,
-- 9 Oct 2026: "invited by 4 different players at the same time and only one goes through ...
-- if I try to swap again no one invites me"). So a host waits a random moment first and says
-- "claim <asker>" out of sight before inviting. A claim from another host seen meanwhile means
-- that host invites, and this one stays free for the asker's next ask. Hosts older than 1.7
-- make no claim and invite at once; the game's "already been invited" then frees this host.
local CLAIM_WAIT = 1.5            -- the random delay runs up to this many seconds
local claims = {}                 -- [asker] = { by = host, at = GetTime() }

local function sendClaim(name, where)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  local kind, channel = "CHANNEL", GetChannelName(LAYER_CHANNEL)
  if where == "guild" then kind, channel = "GUILD", nil
  elseif not channel or channel == 0 then return end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, "claim " .. name, kind, channel)
  log("claim", name, ok and tostring(res) or ("error: " .. tostring(res)), where)
end


-- 1.14, the option "Skip askers near you" (a user on CurseForge, 23 Oct 2026, farming a spot with
-- Host on): an asker within the distance is skipped, so a swap does not bring someone to the
-- spot this host farms. The asker's position came as a note of its own (see onNote); without
-- one - an older LayerSwap, an ask in General, a note the game has not passed on yet - the ask
-- is skipped too, because a filter that lets through what it cannot read would invite exactly
-- the asker it is for. Each reason has its own log line, so a timing miss can be told from a
-- real skip. The host's own position is read now, at decision time, and never leaves this
-- client. Runs inside the claim delay (see claimThenInvite): a tagged ask is answered in the
-- frame its line arrives, and every asker's note a host ever logged came after its line.
function Near.check(name, where)
  local note = notes[name]
  local p = note and note.pos
  if not (p and note.posAt and note.posAt >= (requestedAt[name] or 0) - 5) then
    stats.skipped = stats.skipped + 1
    log("skip", name, "no position in the ask", where)
    return false
  end
  local here = zoneOf("player")
  if not here then
    stats.skipped = stats.skipped + 1
    log("skip", name, "own position unknown", where)
    return false
  end
  if p.ref ~= tostring(here) then
    stats.skipped = stats.skipped + 1
    log("skip", name, "position from another zone (map " .. p.ref .. ")", where)
    return false
  end
  local mine = Near.read()
  if not mine or mine.kind ~= p.kind then
    stats.skipped = stats.skipped + 1
    log("skip", name, "own position unknown", where)
    return false
  end
  local d = math.floor(Near.between(p, mine) + 0.5)
  log("spot", name, d .. " yards", where)
  if d < Near.yards() then
    stats.skipped = stats.skipped + 1
    log("skip", name, "too close (" .. d .. " yards)", where)
    return false
  end
  return true
end

local function claimThenInvite(name, where)
  -- Classic hosts (AutoLayer) make no claims; a whisper reached only us
  if not FOREVER or where == "whisper" then invite(name, where); return end
  local heardAt = GetTime()
  local near = Near.on()
  local function go()
    if not hosting then Near.settle(name, false); return end
    if near then
      -- the asker's position note has had the delay to arrive; a skip here claims nothing, so it
      -- holds back no other host, and the asker is told that this host does not invite it
      if not Near.check(name, where) then Near.settle(name, false); return end
      Near.settle(name, true)
    end
    local c = claims[name]
    if c and c.at >= heardAt - 0.5 then
      log("yield", name, c.by, string.format("claimed %.1f s ago", GetTime() - c.at), where)
      return
    end
    -- a host that cannot invite makes no claim: it would only hold back a host that can (1.10)
    if pending[name] then return end
    local ok, why = canInvite()
    if not ok then
      stats.skipped = stats.skipped + 1
      log("skip", name, why, where)
      return
    end
    sendClaim(name, where)
    invite(name, where)
    refresh()
  end
  -- with the box on the delay never runs under NOTE_WAIT: an asker's note lands after its line
  -- (32 of 32 logged, up to 0.26 s), and a check in the line's frame would never see it
  local delay = near and (NOTE_WAIT + math.random() * (CLAIM_WAIT - NOTE_WAIT)) or (math.random() * CLAIM_WAIT)
  if delay > 0 then C_Timer.After(delay, go) else go() end
end


local answer    -- below: onChat hands a request to it, now or once the note is in
local onSame    -- below: a host's "same" note to the asker, counted with the ask it answers
local onHeard   -- below: a LayerSwap user's "heard" note to the asker, with its layer and zone
local onEcho    -- below: one of our own notes came back - the ask's ping times the game (1.10)

-- With Host off, asks are still counted (the panel says how many asked - Adam, 8 Oct 2026) but
-- never answered. A whisper only counts while hosting: to anyone else "inv" is not a layer ask.
-- Every LayerSwap user who hears an ask says so to the asker, out of sight: its layer, its zone,
-- and whether it hosts (Adam, 8 Oct 2026: the layer channel held 46-56 players and hardly a host;
-- the asker's panel can now say how many LayerSwap users heard it and whether any of them hosts).
-- Only an asker whose zone note is in reads it (1.4 on) - so the reply waits a moment for the
-- note, as the host does - and only once in a while per asker. Same way back as the ask came.
-- Only a user in the asker's zone replies (Adam, 11 Oct 2026): only a host there can move the
-- asker, and every user answering every ask to the whole channel, from any zone, was traffic the
-- asker could not use - our own replies came back 95-180 s late that day.
local HEARD_COOLDOWN = 10
local heardAt = {}              -- [First Surname] = GetTime() of our last reply to them

-- tag: the route the ask carries in its line (1.10, see routeTag), so the asker reads the reply
-- and its zone is known at once - no note to wait for.
-- host: the 4th field of the reply - nil says what hosting says now; a host that skips askers
-- near it answers "-" for an ask it does not invite (1.14), the same as any Host-off user sends.
-- at: the time of the line a held-back reply answers, so its 10 s cooldown counts from the ask
-- and not from the delayed send (the asker's own cooldown is 10 s too: a re-ask the moment its
-- button lights must be answered)
local function replyHeard(where, sender, tag, host, at)
  local function send(zone)
    local here = zoneOf("player")
    if not (zone and here and tostring(here) == tostring(zone)) then return end
    if heardAt[sender] and GetTime() - heardAt[sender] < HEARD_COOLDOWN then return end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local kind, channel = "GUILD", nil
    if where == "layer" then
      kind, channel = "CHANNEL", GetChannelName(LAYER_CHANNEL)
      if not channel or channel == 0 then return end
    end
    heardAt[sender] = at or GetTime()
    local flag = host
    if flag == nil then flag = hosting end
    local text = "heard " .. sender .. "|" .. (current or "-") .. "|" .. (zoneOf("player") or "-") .. "|" .. (flag and "h" or "-")
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, text, kind, channel)
    log("heard", sender, text, ok and tostring(res) or ("error: " .. tostring(res)))
  end
  if tag then send(tag.zone); return end
  C_Timer.After(NOTE_WAIT, function()
    local note = notes[sender]
    if note and note.zoneAt and GetTime() - note.zoneAt <= NOTE_TTL then send(note.zone) end
  end)
end

-- A reply held back in onChat (a host with the box on) goes out once, when the ask is settled:
-- "h" when this host answers it like any other ask, "-" when it skips it. Nothing after the
-- first call sends a second one.
Near.settle = function(sender, host)
  local held = Near.later[sender]
  if not held then return end
  Near.later[sender] = nil
  replyHeard(held.where, sender, held.tag, host, held.at)
end

local function onChat(where, msg, sender)
  if not hosting and where == "whisper" then return end
  if isSecret(sender) or type(sender) ~= "string" or sender == "" then
    if hosting then log("skip", "?", "sender not readable", where) end
    return
  end
  sender = withRealm(sender)
  -- NWB and AutoLayer post lines of their own with the word "layer" in them
  if not isSecret(msg) and type(msg) == "string" and (string.find(msg, "^%[NWB%]") or string.find(msg, "^%[AutoLayer%]")) then
    return
  end
  -- Classic: AutoLayer's TBC header carries the asker's zone; its Era prefix ("<AZ> ") is dropped
  local scope
  if not FOREVER and not isSecret(msg) and type(msg) == "string" then
    local z, body = string.match(msg, "^<AL%d+V%d+_%d+_%d+Z(%d+)>%s*(.*)$")
    if z then scope, msg = z, body else msg = string.gsub(msg, "^<%w+> ", "") end
  end
  local wants, reason = isRequest(msg, where)
  if not wants then
    if hosting and where ~= "general" and where ~= "guild" then log("ignored", sender, reason, where) end
    return
  end
  local own = sender == fullName("player")
  if not own then
    stats.requests = stats.requests + 1
    if not askers[sender] then askers[sender], stats.askers = true, stats.askers + 1 end
  end
  requestedAt[sender] = GetTime()
  log("request", sender, string.sub(msg, 1, 120), where, (not hosting) and "host off" or nil)
  if not own and FOREVER and (where == "layer" or where == "guild") then
    if hosting and Near.on() then
      -- the reply waits for the verdict (1.14): the asker reads one reply per user, so it has to
      -- carry whether this host invites it; a timer settles it in any case
      Near.later[sender] = { where = where, tag = routeTag(msg), at = GetTime() }
      C_Timer.After(CLAIM_WAIT + 1, function() Near.settle(sender, hosting) end)
    else
      replyHeard(where, sender, routeTag(msg))
    end
  end
  if not hosting then refresh(); return end
  if own then log("skip", sender, "own message", where); return end
  local last = lastInvite[sender]
  if last and GetTime() - last < PLAYER_COOLDOWN then
    stats.skipped = stats.skipped + 1
    log("skip", sender, "invited less than " .. PLAYER_COOLDOWN .. " s ago", where)
    Near.settle(sender, hosting)
    return
  end
  local want, avoid = namedLayer(msg)
  local note = notes[sender]
  local plainAsk = string.lower(strtrim(msg))
  plainAsk = plainAsk == "inv layer" or (not FOREVER and string.find(plainAsk, "^inv layer[%d%s,%-]*$") ~= nil)
  if not (want or avoid) and not (note and note.at and GetTime() - note.at <= NOTE_TTL) and plainAsk then
    -- LayerSwap's own line, its note not here yet: give it a moment
    C_Timer.After(NOTE_WAIT, function() answer(where, msg, sender, scope) end)
    return
  end
  answer(where, msg, sender, scope)
end

-- The answer to a request that passed the checks: a host is only any use on another layer
-- than the one the asker is leaving, and only on the layer the asker named.
answer = function(where, msg, sender, scope)
  if not hosting then Near.settle(sender, false); return end
  if not FOREVER then
    -- TBC: an invite from a leader in another zone does not move the asker (AutoLayer 1.9.6)
    local here = TBC and scope and scope ~= "0" and mapHere()
    if here and here ~= scope then
      stats.skipped = stats.skipped + 1
      log("skip", sender, "asks from another zone (map " .. scope .. ", we are on " .. here .. ")", where)
      return
    end
    -- AutoLayer's numbers: only a host on one of the NWB layers asked for (or not on the ones
    -- ruled out) is any use
    local numbers, invert = nwbNumbersIn(msg)
    if #numbers > 0 then
      local mine = nwbLayer()
      local listed = false
      for _, n in ipairs(numbers) do if n == mine then listed = true end end
      local note = notes[sender]
      local noted = note and note.at and GetTime() - note.at <= NOTE_TTL   -- a LayerSwap asker: its note decides below
      if (mine and listed == invert) or (not mine and not noted) then
        stats.skipped = stats.skipped + 1
        log("skip", sender, (invert and "not " or "wants ") .. "NWB layer " .. table.concat(numbers, ",") ..
          ", we are on " .. (mine and ("Layer " .. mine) or "an NWB layer we do not know"), where)
        return
      end
    end
  end
  local want, avoid = namedLayer(msg)
  local note = notes[sender]
  -- Forever: the game moves a guest only to a host in the guest's own zone. Measured 7-9 Oct
  -- 2026 with the host's zone read from the group: every host in another zone moved nobody (6
  -- of 6 by 10 Oct). A LayerSwap asker names its zone - in the line from 1.10 (the tag), in a
  -- note from 1.4 - and a host elsewhere stays out, so the asker is not sent into a group that
  -- changes nothing (a user on CurseForge, 10 Oct 2026).
  local tag = routeTag(msg)
  local zone
  if tag then
    zone, want, avoid = tag.zone, tag.want, tag.avoid
  elseif FOREVER and note and note.zoneAt and GetTime() - note.zoneAt <= NOTE_TTL then
    zone = note.zone
  end
  if zone then
    local here = zoneOf("player")
    if not here then
      stats.skipped = stats.skipped + 1
      log("skip", sender, "own zone unknown (the asker is on map " .. zone .. ")", where)
      Near.settle(sender, hosting)
      return
    end
    if tostring(here) ~= zone then
      stats.skipped = stats.skipped + 1
      log("skip", sender, "asks from another zone (map " .. zone .. ", we are on " .. here .. ")", where)
      Near.settle(sender, hosting)
      return
    end
  elseif FOREVER and where ~= "whisper" and where ~= "general" then
    -- 1.10: no zone, no invite. Before, a host whose note had not come invited anyway, from
    -- wherever it stood (10 Oct 2026: the notes came minutes late, and every invite that day
    -- came from another zone). General is the zone's own channel, so its askers stand in ours;
    -- a whisper asked this host by name.
    stats.skipped = stats.skipped + 1
    log("skip", sender, "no zone in the ask", where)
    Near.settle(sender, hosting)
    return
  end
  if not tag and not (want or avoid) and note and note.at and GetTime() - note.at <= NOTE_TTL then
    want, avoid = note.want, note.avoid
  end
  if want and want ~= current then
    stats.skipped = stats.skipped + 1
    log("skip", sender, "wants " .. want .. ", we are on " .. (current or "an unknown layer"), where)
    Near.settle(sender, hosting)
    return
  end
  if avoid and not current then
    -- the asker leaves a layer this host cannot rule out standing on: an invite from that very
    -- layer changes nothing, so it waits for an ask a host on another layer answers (1.9)
    stats.skipped = stats.skipped + 1
    log("skip", sender, "own layer unknown (the asker leaves " .. avoid .. ")", where)
    Near.settle(sender, hosting)
    return
  end
  if avoid and avoid == current then
    stats.skipped = stats.skipped + 1
    log("skip", sender, "already on our layer " .. avoid, where)
    Near.settle(sender, hosting)
    -- the asker's zone and layer: say so out of sight, so the asker knows a host heard it and
    -- why no invite comes (instead of two minutes of waiting)
    if zone and note and note.from and C_ChatInfo and C_ChatInfo.SendAddonMessage then
      local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, "same", "WHISPER", note.from)
      log("note", "same to " .. sender, ok and tostring(res) or ("error: " .. tostring(res)))
    end
    return
  end
  claimThenInvite(sender, where)
end

-- A note from an asker: kept a few seconds for the chat line that follows it. The asker
-- sends the note first, so it is normally here before the line; one that comes after is
-- logged, to see whether that ever happens.
local function onNote(text, sender)
  if isSecret(text) or isSecret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
  -- Forever: "First Surname-Realm" -> "First Surname"; Classic keeps "Name-Realm"
  local name = FOREVER and string.match(sender, "^([^%-]+)") or withRealm(sender)
  if not name then return end
  if name == fullName("player") then
    log("note", "came back", text)
    onEcho(text)
    Near.echo(text)
    return
  end
  -- another host claims an asker (see claimThenInvite)
  local claimed = string.match(text, "^claim (.+)$")
  if claimed then
    claims[claimed] = { by = name, at = GetTime() }
    if hosting then log("claimed", claimed, name) end
    return
  end
  -- a LayerSwap user heard our ask: "heard <asker>|<layer>|<zone>|<h or ->" (see replyHeard)
  local target, layer, zone, host = string.match(text, "^heard (.-)|([^|]*)|([^|]*)|([^|]*)$")
  if target then
    if target == fullName("player") then onHeard(name, layer ~= "-" and layer or nil, zone ~= "-" and zone or nil, host == "h") end
    return
  end
  -- the asker's position (1.14): "pos <zone map id> <x> <y>" in yards, kept with the asker's other
  -- notes for a host that skips askers near it (Near.check). Only a note of this host's own kind
  -- counts ("pos" = world yards, "posm" = map yards): two frames are never compared. Hosts
  -- older than 1.14 drop it below, at the gate that drops anything but want, not and any.
  local pKind, pRef, px, py = string.match(text, "^(pos%a?) (%d+) (%-?%d+) (%-?%d+)$")
  if pKind then
    local was = notes[name]
    -- only this host's own frame, and only yards a zone can hold (world coordinates stay within
    -- about 20,000): anything else is no position, and a filter without one fails closed
    local x, y = tonumber(px), tonumber(py)
    local pos = (pKind == Near.KIND and x and y and math.abs(x) <= 100000 and math.abs(y) <= 100000)
      and { kind = pKind, ref = pRef, x = x, y = y } or nil
    notes[name] = { want = was and was.want, avoid = was and was.avoid, at = was and was.at,
                    zone = was and was.zone, zoneAt = was and was.zoneAt, from = sender,
                    pos = pos, posAt = pos and GetTime() or nil }
    if hosting then
      local late = requestedAt[name] and GetTime() - requestedAt[name] < NOTE_TTL
      log("note", name, text, late and "after the chat line" or nil)
    end
    return
  end
  local kind, id = string.match(text, "^(%a+)%s*(%S*)$")
  id = (id ~= "" and id) or nil
  -- a host in our zone on our layer heard our ask (see answer)
  if kind == "same" then onSame(name); return end
  -- the asker's zone, a note of its own just before the layer note (1.4): hosts older than
  -- that read only want/not/any and go on as before
  local old = notes[name]
  if kind == "zone" then
    notes[name] = { want = old and old.want, avoid = old and old.avoid, at = old and old.at,
                    zone = id, zoneAt = GetTime(), from = sender,
                    pos = old and old.pos, posAt = old and old.posAt }
    return
  end
  if kind ~= "want" and kind ~= "not" and kind ~= "any" then return end
  notes[name] = { want = kind == "want" and id or nil, avoid = kind == "not" and id or nil, at = GetTime(),
                  zone = old and old.zone, zoneAt = old and old.zoneAt, from = sender,
                  pos = old and old.pos, posAt = old and old.posAt }
  if hosting then
    local late = requestedAt[name] and GetTime() - requestedAt[name] < NOTE_TTL
    log("note", name, text, late and "after the chat line" or nil)
  end
end

-- How long a guest stays: someone who leaves within seconds believes the move holds after
-- leaving; the phase API could not tell who was moved (beta 26 Sep 2026: 4 of 4 guests read
-- "same shard" at the join and 5 s later).
local guestSince = {}           -- [fullName] = GetTime() of the join, while in our group

-- An invite from while we hosted can be accepted long after (160 s on 11 Oct 2026). Accepted
-- with Host off by then, it is undone: no LayerSwap group with Host off (Adam, 11 Oct 2026).
local LATE_ACCEPT = 300

local function onRoster()
  local members = groupMembers()
  if not members then return end
  local names, present, now = {}, {}, GetTime()
  for _, name in ipairs(members) do
    names[#names + 1] = name
    present[name] = true
    if not hosting and hosted[name] and not came[name] and lastInvite[name] and now - lastInvite[name] <= LATE_ACCEPT
       and UnitIsGroupLeader("player") then
      pending[name], hosted[name] = nil, nil
      local ok, err = pcall((C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit, name)
      log("kick", name, ok and "called" or tostring(err), "accepted with Host off")
      say(name .. " accepted an invite from before Host was turned off - removed from the group.")
    elseif pending[name] then
      pending[name], came[name] = nil, true
      stats.joined = stats.joined + 1
      guestSince[name] = now
      log("joined", name, string.format("%.1f s after the invite", now - (lastInvite[name] or now)))
      say(name .. " joined.")
    end
  end
  for name, since in pairs(guestSince) do
    if not present[name] then
      guestSince[name] = nil
      log("guestLeft", name, string.format("%d s after joining", math.floor(now - since + 0.5)))
    end
  end
  log("roster", table.concat(names, ", "), #members)
  refresh()
end

-- The players LayerSwap invited, out of the group. Returns how many.
-- Only in a group we lead: in another host's group (our own swap) the leader may be someone we
-- once invited, and a guest removed is forgotten, so the next Host off does not try again.
local function removeHosted(why)
  local members = groupMembers() or {}
  if #members == 0 or not UnitIsGroupLeader("player") then return 0 end
  local n = 0
  for _, name in ipairs(members) do
    if hosted[name] then
      local ok, err = pcall((C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit, name)
      log("kick", name, ok and "called" or tostring(err), why)
      hosted[name], came[name], pending[name] = nil, nil, nil
      n = n + 1
    end
  end
  return n
end

local function kickHosted()
  local n = removeHosted("/ls kick")
  say(n == 0 and "nobody to remove." or ("removed " .. n .. " hosted player(s)."))
end

local function setHosting(on)
  hosting = on
  -- the lasting choice (1.12): off stays off at every login until it is turned on again
  LayerSwapDB.hosting = on and true or false
  log("hosting", hosting and "on" or "off")
  if not on then
    -- with Host off, no LayerSwap group (Adam, 11 Oct 2026): the guests it invited go with it
    local n = removeHosted("host off")
    if n > 0 then say("Host off: removed " .. n .. (n == 1 and " player" or " players") .. " LayerSwap invited.") end
  end
  -- only ever reached from a slash command or a click, so a hardware event is behind it:
  -- the one place a channel can be joined
  if hosting and GetChannelName(LAYER_CHANNEL) == 0 then pcall(JoinChannelByName, LAYER_CHANNEL) end
  refresh()
end

-- ---------------------------------------------------------------------------------------
-- which layer is this?
--
-- The game has no layer API. A creature's GUID is Creature-0-[server]-[map]-[zoneUID]-[npc]-
-- [spawn], and server + zoneUID change when the world is refreshed (measured 19 Sep 2026:
-- three different pairs in Elwynn in one evening, and one of them came back unchanged).
-- Pets carry the pair of the place they were summoned, so only creatures are read, and a
-- layer is only believed when two different creatures agree.

local VOTES = 5
local LAYER_TTL = 3600          -- a layer not seen for an hour leaves the list
local layers = {}               -- [id] = { id, n, letter, zone, first, last }; kept in SavedVariables, times are time()
local layerCount = 0
local votes, votedGuid = {}, {}
local evictAt                  -- GetTime() when the server will move the player, if announced

local swap                      -- the running request: { at, from, inviter, joinedAt }
local swapGroup = false         -- true while in a group that was joined through a request
local leftInfo                  -- { at, layer }: set when such a group is left, until the next layer reading
-- Leaving the host's group undoes the swap: the game moves the player back to their own layer
-- (measured 19 Sep 2026 23:34 - SHARD_TRANSFER 1.2 s after leaving, back on the start layer -
-- and seen by Adam in the beta, 24 Sep 2026). A swap lasts while the player stays in the group,
-- so LayerSwap never leaves it by itself - only the group of a host who did not move us (1.9).
local AUTO_LEAVE = false
local notice, noticeUntil       -- one line for the panel, kept a little while
local held                      -- { host, from, to } after a swap, while in the host's group

local function layerLabel(id)
  local l = id and layers[id]
  if not l then return "Unknown layer" end
  if l.nwb and not FOREVER then return "Layer " .. l.nwb end
  return "Layer " .. l.letter
end

-- A layer we have stood on for a while takes NWB's number: NWB itself records nothing for
-- 180 s after a group join, and needs a moment after a move. The number belongs to one layer
-- of the zone at a time (NWB renumbers when it learns a new layer).
local currentSince, joinedGroupAt = 0, -1000
local lastShardAt = -1000      -- GetTime() of the last SHARD_TRANSFER, for the group log
local function noteNwb()
  local n = nwbLayer()
  local l = n and current and layers[current]
  if not l or l.nwb == n then return end
  local now = GetTime()
  if now - currentSince < 20 or now - joinedGroupAt < 180 then return end
  for id, other in pairs(layers) do
    if id ~= current and other.nwb == n and other.zone == l.zone then other.nwb = nil end
  end
  l.nwb = n
end

local function letterFor(n)
  if n <= 26 then return string.char(64 + n) end
  return tostring(n)
end

local function forgetSightings()
  votes, votedGuid = {}, {}
end

local function setNotice(text, seconds)
  notice, noticeUntil = text, GetTime() + (seconds or 30)
end

local function setCurrent(id)
  if id == current then return end
  local now = GetTime()
  local l = layers[id]
  if not l then
    layerCount = layerCount + 1
    l = { id = id, n = layerCount, letter = letterFor(layerCount), first = time() }
    layers[id] = l
  end
  l.last, l.zone = time(), GetRealZoneText()
  local from = current
  current, currentSince = id, now
  log("layer", id, l.letter, from)
  if swap and swap.joinedAt and swap.from and swap.from ~= id then
    -- the request worked: say so, and hand the host their group back
    log("swapped", swap.from, id, string.format("%.1f s after joining%s", now - swap.joinedAt,
      swap.want and (", asked for " .. swap.want) or ""))
    if swap.want and swap.want ~= id then
      -- a host who invites by hand may stand anywhere
      say("you are now on " .. layerLabel(id) .. " - not the " .. layerLabel(swap.want) .. " you asked for.")
      setNotice("You are on " .. layerLabel(id) .. ", not " .. layerLabel(swap.want) .. ".", 60)
    elseif FOREVER then
      say("you are now on " .. layerLabel(id) .. " while you stay in the group - leaving sends you back.")
    else
      -- Classic keeps the new layer after the group is left; AutoLayer asks its guests to leave
      say("you are now on " .. layerLabel(id) .. " - you can leave the group.")
      setNotice("On " .. layerLabel(id) .. " now - you can leave the group.", 60)
    end
    if FOREVER then held = { host = swap.inviter, from = swap.from, to = id } end
    swap = nil
    if AUTO_LEAVE then
      C_Timer.After(2, function()
        if swapGroup and IsInGroup() then pcall(leaveParty) end
      end)
    end
  end
  if leftInfo then
    -- what did leaving the host's group do to the layer?
    log("afterLeave", leftInfo.layer or "unknown", id, string.format("%.1f s after leaving", now - leftInfo.at))
    leftInfo = nil
  end
  refresh()
end

local function observe(unit)
  local guid = UnitGUID(unit)
  if isSecret(guid) or type(guid) ~= "string" or votedGuid[guid] then return end
  local kind, _, server, _, zoneUID = strsplit("-", guid)
  if (kind ~= "Creature" and kind ~= "Vehicle") or not server or not zoneUID then return end
  votedGuid[guid] = true
  local id = server .. "-" .. zoneUID
  votes[#votes + 1] = id
  if #votes > VOTES then table.remove(votes, 1) end
  local count = 0
  for _, v in ipairs(votes) do if v == id then count = count + 1 end end
  if id == current then
    layers[id].last = time()
  elseif count >= (current and 3 or 2) then
    -- Two creatures are enough while nothing is known (after a refresh the sightings start
    -- from zero). Leaving a layer that is believed takes a majority of the last five: a
    -- pair of patrols that wandered in from the next zone must not flip it.
    setCurrent(id)
  end
end

-- ---------------------------------------------------------------------------------------
-- asking for a swap. Always called from a click or a slash command: a channel message needs
-- a hardware event.

local SWAP_COOLDOWN = 10
local SWAP_TTL = 120            -- seconds a request waits for an invite
-- The Swap button turns into Stop asking while a request waits; for the first second it does
-- nothing, so a double click on Swap layer cannot ask and stop in one go.
local STOP_AFTER = 1
-- A stopped ask still counts for the cooldown, so Swap, Stop, Swap cannot post a line every two
-- seconds (beta 8 Oct 2026: three asks in four seconds from one player). GetTime() of the ask
-- that was stopped, and of its guild ask.
local stopped = { at = -1000, guildAt = -1000 }

-- Joining a host on another layer moves the player about 1.3 s later (SHARD_TRANSFER, beta
-- 19 Sep 2026). None within this many seconds: the host stands on the player's own layer - a
-- player who invites by hand cannot read the note (beta 25 Sep 2026: invited, joined, no move).
local SAME_LAYER_AFTER = 5
-- A host in our zone (or one whose zone is unknown) that has not moved us by then: LayerSwap
-- leaves its group only this long after the join (1.10). Every move so far came 1.1-1.4 s after
-- the join, but on 10 Oct 2026 the server answered minutes late, and leaving undoes a move.
local SAME_LAYER_LEAVE = 15

-- Hosts who did not move us, by name: { at, layer, elsewhere }. The invite carries no layer, and
-- a host who invites by hand invites again (the same host twice in 4 min, beta 27 Sep 2026).
-- Such a host's next invite is named in chat and in the panel; declining it is the player's
-- (1.9 declined it by itself; 1.10 does not - see warnInvite).
local SAME_HOST_TTL = 600
local sameHosts = {}

-- The game now and then stops the channel message even on a click (ADDON_ACTION_BLOCKED,
-- "UNKNOWN()": 2 of 7 asks in the beta, 25 Sep 2026). The event fires during the send, so
-- the ask can tell it went nowhere.
local sendingAsk, askHeldBack = false, false

-- The ask's own ping (see requestSwap): no echo within this many seconds, or a later one, and
-- the panel says the game is slow with addon messages - invites came late that day too.
local LAG_AFTER = 5
local pingCount = 0

-- The note for an ask, into the layer channel. Not a protected call; the result is logged
-- so the beta shows whether addon messages reach the channel at all.
local function sendNote(note, kind, channel)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or not note then return end
  if kind == "CHANNEL" and (not channel or channel == 0) then return end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, NOTE_PREFIX, note, kind, channel)
  log("note", "sent", note, ok and tostring(res) or ("error: " .. tostring(res)))
end

-- Forever: our zone goes ahead of the layer note, so only a host in this zone answers.
local function sendZone(kind, channel)
  local here = FOREVER and zoneOf("player")
  if here then sendNote("zone " .. here, kind, channel) end
end

-- 1.14: the asker's position goes first in the burst, as a note of its own. A host that skips
-- askers near it reads it (Near.check); every other host drops it. Sent first because a dropped
-- zone or layer note costs a 1.10 host nothing - the line carries both - while a missing
-- position makes that host skip the ask. The raw readings go to the log every time.
function Near.send(label, kind, channel)
  if not FOREVER then return end
  -- the probe has never run in a game client: whatever it meets, the ask itself goes out
  local ok, p, why = pcall(Near.probe, label)
  if not ok then log("pos", "error", tostring(p)); return end
  if p then sendNote(p.kind .. " " .. p.ref .. " " .. p.x .. " " .. p.y, kind, channel)
  else log("pos", "unreadable", why) end
end

-- One ask in one place (kind = CHANNEL with its number, or GUILD), from a click. Returns true
-- when it went out; otherwise it says so (button = the label to click again) and returns false
-- plus the reason for the log.
local function sendAsk(text, kind, channel, button)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  sendingAsk, askHeldBack = true, false
  local ok, err = pcall(send, text, kind, nil, channel)
  sendingAsk = false
  if askHeldBack or not ok then
    -- button: the label to click again, or the command to type again ("/ls guild")
    local again = (string.sub(button, 1, 1) == "/" and "type " or "click ") .. button .. " again."
    local line = askHeldBack and ("The game held back your request - " .. again)
      or ("Your request did not go out - " .. again)
    setNotice(line, 15)
    say(line)
    return false, askHeldBack and "held back" or tostring(err)
  end
  return true
end

-- The layers seen in this zone within the hour, newest first, without the current one - the
-- ones that can be asked for. Layers not seen for an hour are dropped on the way.
local function seenInZone()
  local seen, today, zone = {}, time(), GetRealZoneText() or ""
  for id, l in pairs(layers) do
    if today - l.last > LAYER_TTL then
      if id ~= current then layers[id] = nil end
    elseif id ~= current and l.zone == zone then seen[#seen + 1] = l end
  end
  table.sort(seen, function(a, b) return a.last > b.last end)
  return seen
end

-- The zone's name when no other layer has been seen in it within the hour: a 'same layer'
-- verdict there may mean the zone has only one layer right now, and no host can move anyone.
-- (Beta, 27 Sep 2026: four hosts in a row on the player's layer in Westfall, where one layer
-- was ever seen; in Elwynn Forest next door, with three, the move came.)
local function onlyLayerHere()
  local zone = GetRealZoneText()
  if isSecret(zone) or type(zone) ~= "string" or zone == "" or #seenInZone() > 0 then return nil end
  return zone
end

-- The host's zone, read from the group we joined: its map id, nil when the game does not say.
local function hostZone(name)
  if not (FOREVER and name) then return nil end
  for i = 1, PARTY_MAX - 1 do
    local unit = "party" .. i
    if UnitExists(unit) and fullName(unit) == name then return zoneOf(unit) end
  end
end

-- In the host's group, and the game did not move us: the host is on our layer - or, when the
-- group says so, in another zone, from where no host moves anyone (swap.elsewhere: its name).
local function hostOnOurLayer(now)
  if not FOREVER then return false end   -- no transfer event on Classic: no way to tell
  local yes = swap ~= nil and swap.joinedAt ~= nil and swapGroup and not swap.transferAt and not held
    and now - swap.joinedAt >= SAME_LAYER_AFTER
  if yes and not swap.sameLogged then
    swap.sameLogged = true
    local here, there = zoneOf("player"), hostZone(swap.inviter)
    if here and there and there ~= here then
      swap.elsewhere = zoneName(there) or "another zone"
      log("otherZone", swap.inviter, current, "no transfer " .. SAME_LAYER_AFTER .. " s after joining", swap.elsewhere)
    else
      log("sameLayer", swap.inviter, current, "no transfer " .. SAME_LAYER_AFTER .. " s after joining",
        onlyLayerHere() and "the only layer seen in this zone" or nil)
      if swap.inviter and current then sameHosts[swap.inviter] = { at = now, layer = current } end
    end
  end
  return yes
end

-- target: the id of the layer wanted, or nil for any layer but this one
-- via: the control that asked (button, row, menu, slash, again) - for the log
-- leaving: the player is on the way out of a group (Leave and ask again)
-- Returns "held" when the game stopped the message; the caller then says nothing more.
local function askText(target, wantNumber, header)
  local text = "inv layer"
  if FOREVER then
    -- the route, in the line (1.10): our zone, and the layer named or the one we leave
    return text .. " " .. routeText(zoneOf("player"), target, (not target) and current or nil)
  else
    -- Classic: the NWB numbers AutoLayer hosts read - all but ours, or the one picked
    local numbers = {}
    local wanted = wantNumber or (target and layers[target] and layers[target].nwb)
    if wanted then
      numbers = { wanted }
    elseif not target then
      local mine, count = nwbLayer(), nwbLayerCount()
      if mine and count then
        for n = 1, count do if n ~= mine then numbers[#numbers + 1] = n end end
      end
    end
    if #numbers > 0 then text = "inv layer " .. table.concat(numbers, ",") end
    if TBC and header then text = autoLayerHeader() .. " " .. text end
  end
  return text
end

-- How many players the layer channel holds, for the status line after an ask (Adam, 8 Oct 2026:
-- "how many does my click reach?"). Unmeasured on Forever: each source is logged at every ask.
-- The count includes the player. nil while unknown.
local channelCount

-- The layer channel's place in the game's channel list, and the member count listed there.
local function layerDisplay()
  if type(GetNumDisplayChannels) ~= "function" or type(GetChannelDisplayInfo) ~= "function" then return nil end
  local okN, n = pcall(GetNumDisplayChannels)
  if not okN or isSecret(n) or type(n) ~= "number" then return nil end
  for i = 1, n do
    local ok, name, _, _, _, count = pcall(GetChannelDisplayInfo, i)
    if ok and not isSecret(name) and type(name) == "string" and string.lower(name) == LAYER_CHANNEL then
      return i, (not isSecret(count) and type(count) == "number") and count or nil
    end
  end
end

local function readChannelCount(why)
  local i, count = layerDisplay()
  local members
  if type(GetNumChannelMembers) == "function" then
    local ok, m = pcall(GetNumChannelMembers, GetChannelName(LAYER_CHANNEL))
    members = ok and not isSecret(m) and type(m) == "number" and m or nil
  end
  log("channelCount", why, i or "not listed", count or "no count", members or "no member count")
  channelCount = count or members or channelCount
  -- asks the server for the channel's roster; the answer comes as CHANNEL_COUNT_UPDATE
  if i and type(SetSelectedDisplayChannel) == "function" then pcall(SetSelectedDisplayChannel, i) end
end

local function onChannelCount(ev, index, count)
  local i = layerDisplay()
  if not i or isSecret(index) or index ~= i or isSecret(count) or type(count) ~= "number" then return end
  if count ~= channelCount then log("channelCount", ev, i, count) end
  channelCount = count
  refresh()
end

local function requestSwap(target, via, leaving, wantNumber)
  local now = GetTime()
  -- an unanswered request past its time is over; it must not hide what this click says
  if swap and not swap.joinedAt and now - swap.at > SWAP_TTL then swap = nil end
  if IsInGroup() and not leaving then
    setNotice("You are in a group. Leave it to swap layers.", 10)
  elseif (swap and now - swap.at < SWAP_COOLDOWN) or now - stopped.at < SWAP_COOLDOWN then
    return
  elseif (target and target == current) or (wantNumber and wantNumber == nwbLayer()) then
    -- said straight out: an older ask still waiting would otherwise hide it
    local line = "You are already on " .. (target and layerLabel(target) or ("Layer " .. wantNumber)) .. "."
    setNotice(line, 10)
    say(line)
    refresh()
    return "held"
  elseif FOREVER and not target and not current then
    -- the ask names the layer it leaves, so a host standing on it stays out; without it any
    -- host would invite, ours included (a user on CurseForge, 10 Oct 2026). Read first (1.9).
    local line = "Reading your layer first - target or mouse over an NPC, then ask."
    setNotice(line, 10)
    say(line)
    log("ask", "layer unknown", nil, nil, via)
    refresh()
    return "held"
  else
    local channel = GetChannelName(LAYER_CHANNEL)
    if channel == 0 then
      pcall(JoinChannelByName, LAYER_CHANNEL)
      setNotice("Joined the layer channel. Click again to ask.", 15)
    else
      -- everyone reads "inv layer"; the note tells a LayerSwap host which layer: the one named,
      -- or any but the current one, so a host on this very layer does not answer
      local note = (target and ("want " .. target)) or (current and ("not " .. current)) or "any"
      Near.send("ask", "CHANNEL", channel)
      sendZone("CHANNEL", channel)
      sendNote(note, "CHANNEL", channel)
      local sent, why = sendAsk(askText(target, wantNumber, true), "CHANNEL", channel, "Swap layer")
      if not sent then
        -- nothing went out: nothing to wait for, and no cooldown before the next click
        log("ask", why, current, target, via)
        refresh()
        return "held"
      end
      -- a ping of our own after the line: its echo says whether the game is passing addon
      -- messages on time right now (0.22-0.40 s until 8 Oct 2026, 68-139 s on 10 Oct)
      pingCount = pingCount + 1
      local ping = "ping " .. pingCount .. "-" .. math.floor(now)
      sendNote(ping, "CHANNEL", channel)
      readChannelCount("ask")
      log("ask", "sent", current, target, via)
      -- a guild ask already waiting keeps waiting: both are out now
      if swap and not swap.joinedAt and swap.guildAt then swap.at, swap.channel = now, true
      else swap = { at = now, from = current, want = target, channel = true } end
      swap.ping, swap.pingAt, swap.echoAt = ping, now, nil
      notice = nil
    end
  end
  refresh()
end

-- A request that is still waiting for its invite (asked, not yet in a group, within its time).
local function waitingAsk(now)
  return swap ~= nil and not swap.joinedAt and now - swap.at <= SWAP_TTL
end
ownAskWaiting = function() return waitingAsk(GetTime()) end

-- A host in our zone on our own layer heard the ask and cannot move us: counted once per host
-- for the ask that waits, so the panel can say why no invite comes.
-- What LayerSwap users said about the ask that waits: [name] = { layer, zone, host, same }.
-- "same" comes from a host on our layer (1.4 on; such a host is hosting by definition), "heard"
-- from every LayerSwap user (1.6 on).
local function replyFrom(name)
  swap.replies = swap.replies or {}
  local r = swap.replies[name]
  if not r then r = {}; swap.replies[name] = r end
  return r
end

onSame = function(name)
  if not waitingAsk(GetTime()) then return end
  local r = replyFrom(name)
  if r.same then return end
  r.same, r.host = true, true
  log("sameReply", name, current)
  refresh()
end

onHeard = function(name, layer, zone, host)
  if not waitingAsk(GetTime()) then return end
  local r = replyFrom(name)
  r.layer, r.zone, r.host = layer, zone, host or r.host
  log("heardReply", name, layer or "?", zone or "?", host and "hosting" or nil)
  refresh()
end

onEcho = function(text)
  if not (swap and swap.ping == text and not swap.echoAt) then return end
  swap.echoAt = GetTime()
  log("echo", string.format("%.2f s", swap.echoAt - swap.pingAt))
  refresh()
end

-- Our own pos note came back: the distance to where we stand now, through the same code a host
-- runs on an asker. About 0 yards proves the whole pipeline on one client (1.14).
Near.echo = function(text)
  local pKind, pRef, px, py = string.match(text, "^(pos%a?) (%d+) (%-?%d+) (%-?%d+)$")
  if not pKind or pKind ~= Near.KIND then return end
  local mine = Near.read()
  if not mine or mine.ref ~= pRef then log("spot", "self", "unreadable now"); return end
  log("spot", "self", math.floor(Near.between(mine, { x = tonumber(px), y = tonumber(py) }) + 0.5) .. " yards")
end

-- The game is slow with addon messages right now: the ask's ping took longer than LAG_AFTER to
-- come back, or has not come back by then.
local function lagging(now)
  if not (swap and swap.pingAt) then return false end
  if swap.echoAt then return swap.echoAt - swap.pingAt > LAG_AFTER end
  return now - swap.pingAt > LAG_AFTER
end

-- The replies counted: all, hosting, on another layer in our zone, on our own layer. A layer id
-- belongs to one zone, so only replies from our zone are compared with our layer.
local function heardCounts()
  local n, h, o, s = 0, 0, 0, 0
  local here = zoneOf("player")
  here = here and tostring(here)
  for _, r in pairs(swap.replies or {}) do
    local sameZone = here ~= nil and r.zone == here
    -- a reply from another zone is no use: no host there can move us (LayerSwap 1.10 and older
    -- still answer from anywhere)
    if r.same or sameZone then
      n = n + 1
      if r.host then h = h + 1 end
      if r.same or (r.layer and current and r.layer == current) then s = s + 1
      elseif r.layer and current and r.layer ~= current then o = o + 1 end
    end
  end
  return n, h, o, s
end

-- One line on what LayerSwap users said, for the status line while the ask waits; "" until the
-- first reply.
local function heardLine()
  local n, h, o, s = heardCounts()
  if n == 0 then return "" end
  local parts = { h > 0 and (h .. " hosting") or "none hosting" }
  if o > 0 then parts[#parts + 1] = o .. " on another layer here" end
  if s > 0 then parts[#parts + 1] = s .. " on yours" end
  return n .. (n == 1 and " LayerSwap user heard you: " or " LayerSwap users heard you: ") .. table.concat(parts, ", ") .. "."
end

-- Stop asking: the wait ends here. A chat line cannot be taken back, so an invite already on
-- its way can still come - it is then the player's to decline, and it no longer counts as a swap.
local function stopAsking(via)
  local now = GetTime()
  if not waitingAsk(now) then return false end
  log("ask", "stopped", current, swap.want, via)
  stopped.at, stopped.guildAt = swap.at, swap.guildAt or -1000
  swap = nil
  setNotice("Stopped asking. An invite already on its way can still come.", 10)
  refresh()
  return true
end

-- Ask the guild (/ls guild): one line in guild chat, on its own command and never with Swap
-- layer - guild chat is where people talk, so LayerSwap never writes there by itself. No button
-- in the panel since 1.4.3 (Adam, 8 Oct 2026: it stood alone on a row of its own). A guildmate on another
-- layer is the most willing host there is, and invites by hand with or without the addon;
-- the note still goes to the guild's LayerSwap hosts. No AutoLayer header: nobody reads it there.
local function requestGuild(via)
  local now = GetTime()
  if swap and not swap.joinedAt and now - swap.at > SWAP_TTL then swap = nil end
  if not IsInGuild() then
    local line = "You are not in a guild."
    setNotice(line, 10)
    say(line)
    refresh()
    return "held"
  elseif IsInGroup() then
    setNotice("You are in a group. Leave it to swap layers.", 10)
  elseif (swap and swap.guildAt and now - swap.guildAt < SWAP_COOLDOWN) or now - stopped.guildAt < SWAP_COOLDOWN then
    return
  elseif FOREVER and not current and not (swap and not swap.joinedAt and swap.want) then
    local line = "Reading your layer first - target or mouse over an NPC, then ask."
    setNotice(line, 10)
    say(line)
    log("ask", "layer unknown", nil, nil, via)
    refresh()
    return "held"
  else
    local want = swap and not swap.joinedAt and swap.want or nil
    local note = (want and ("want " .. want)) or (current and ("not " .. current)) or "any"
    Near.send("guild", "GUILD")
    sendZone("GUILD")
    sendNote(note, "GUILD")
    local sent, why = sendAsk(askText(want, nil, false), "GUILD", nil, "/ls guild")
    if not sent then
      log("ask", why, current, want, via)
      refresh()
      return "held"
    end
    log("ask", "sent in guild", current, want, via)
    -- the wait starts over from this ask; a channel ask already out stays counted
    if swap and not swap.joinedAt then swap.at, swap.guildAt = now, now
    else swap = { at = now, from = current, want = want, guildAt = now } end
    notice = nil
  end
  refresh()
end

-- One click: out of the host's group, and the same ask once more - the click is the
-- hardware event the chat line needs. The group is let go of here, so GROUP_LEFT does not
-- wipe the new ask.
local function leaveAndAskAgain(via)
  local want = swap and swap.want
  if IsInGroup() then pcall(leaveParty) end
  log("left", current, "to ask again")
  leftInfo = { at = GetTime(), layer = current }
  swapGroup, swap = false, nil
  return requestSwap(want, via, true)
end

local function leaveSwapGroup()
  if swapGroup and IsInGroup() then pcall(leaveParty) end
  swap = nil
  refresh()
end

local function clock(seconds)
  seconds = math.max(0, math.floor(seconds))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The world refresh (Blizzard's word for it): a countdown, then "any moment" - the move came
-- 14-15 s after the timer ran out (beta 19 Sep 2026), and Blizzard's toast says "Refreshing
-- your world at any time" then. Two minutes past it, without a move, the notice is dropped.
local function refreshIn(now)
  if not evictAt then return nil end
  if evictAt > now then return clock(evictAt - now) end
  if now - evictAt < 120 then return "soon" end
end

-- The one status line under the buttons.
local function statusLine()
  local now = GetTime()
  if swap then
    if swap.joinedAt then
      local host = swap.inviter or "a host"
      if hostOnOurLayer(now) then
        if swap.elsewhere then return host .. " is in " .. swap.elsewhere .. " - only a host in your zone can move you." end
        -- two lines in the panel: the chat line names the zone
        if onlyLayerHere() then return "Host on your layer - the only one seen here. Try a busier zone." end
        return host .. " is on your layer, so nothing changed. Leave and ask again."
      end
      if not current then return "In " .. host .. "'s group. Mouse over an NPC to read the layer." end
      return "In " .. host .. "'s group, still on " .. layerLabel(current) .. ". (" .. clock(now - swap.joinedAt) .. ")"
    elseif swap.inviter then
      -- a host that did not move us before: the warning, not "accept"
      if swap.inviterSeen and notice and now < (noticeUntil or 0) then return notice end
      return swap.inviter .. " invited you. Accept to swap."
    elseif now - swap.at > SWAP_TTL then
      if swap.want then return "No host on " .. layerLabel(swap.want) .. " answered. Swap layer asks for any other." end
      local n, h, other, same = heardCounts()
      if same > 0 then
        return "No host on another layer answered; " .. same .. " here " .. (same == 1 and "is" or "are") .. " on yours. Try a busier zone."
      end
      if n > 0 and other == 0 then
        -- LayerSwap users heard it, and none of them stands on another layer in this zone
        return "No host on another layer in your zone heard you. Try again later, or in a busier zone."
      end
      if n > 0 and h == 0 then
        return n .. (n == 1 and " LayerSwap user" or " LayerSwap users") .. " heard you, but none of them hosts. Try again in a moment."
      end
      return "No host answered. Try again in a moment."
    end
    -- the request waits: the bottom line says it (askLine); this one carries what LayerSwap
    -- users said about it, if anything (Adam, 8 Oct 2026) - or that the game is slow (1.10)
    if lagging(now) then return "The game is delaying addon messages right now - an invite may come late." end
    return heardLine()
  end
  if notice and now < (noticeUntil or 0) then return notice end
  if held and swapGroup then
    -- the swap lasts only while the player stays in the host's group
    local back = (held.from and layers[held.from]) and layerLabel(held.from) or "your own layer"
    return "On " .. layerLabel(current or held.to) .. " while in " .. (held.host or "the host") ..
      "'s group. Leaving sends you back to " .. back .. "."
  end
  if FOREVER and not current then return "Swap layer asks once your layer is read, so a host on it skips you." end
  return "Swap layer asks a host in the layer channel for an invite."
end

-- The request that waits, in one line: how many it reached - the others in the layer channel,
-- when the game says - and for how long; hosts on our own layer who said so are added. The
-- panel's bottom line carries it while the request waits (Adam, 8 Oct 2026).
local function askLine(now)
  local others = swap.channel and channelCount and math.max(channelCount - 1, 0) or nil
  -- where it went is said too (Adam, 8 Oct 2026)
  local guild = swap.guildAt and " + your guild" or ""
  local reach
  if not swap.channel then
    reach = "your guild"
  elseif others == 0 then
    reach = swap.guildAt and "your guild - nobody else is in the layer channel" or "nobody else in the layer channel"
  elseif others then
    reach = others .. (others == 1 and " player" or " players") .. " in the layer channel" .. guild
  else
    reach = "the layer channel" .. guild
  end
  local line = "|cff40ff40Asked for inv|r" .. (swap.want and (" on " .. layerLabel(swap.want)) or "")
    .. ": " .. reach .. " (" .. clock(now - swap.at) .. ")"
  return line
end

-- A request out and nobody has invited yet.
local function askWaiting(now)
  return waitingAsk(now) and not swap.inviter
end

-- After an ask from a slash command or the menu (the panel may be closed): the line for chat.
local function sayStatus()
  local now = GetTime()
  say(askWaiting(now) and askLine(now) or statusLine())
end

-- ---------------------------------------------------------------------------------------
-- panel

local PANEL_W, PAD, ROWS = 260, 12, 5
local panel

-- A button's label stays inside the button: one wider than the button drops to the small font
-- (Adam's screenshot, 26 Sep 2026: "Leave and ask again" ran past both edges).
local function setButtonText(button, text)
  button:SetNormalFontObject("GameFontNormal")
  button:SetHighlightFontObject("GameFontHighlight")
  button:SetDisabledFontObject("GameFontDisable")
  button:SetText(text)
  local fs = button:GetFontString()
  if type(fs) ~= "table" or type(fs.GetStringWidth) ~= "function" then return end
  if (fs:GetStringWidth() or 0) > button:GetWidth() - 14 then
    button:SetNormalFontObject("GameFontNormalSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
  end
end

local function agoText(seconds)
  if seconds < 60 then return "just now" end
  return math.floor(seconds / 60) .. " min ago"
end

-- Every line of text is bound on both sides, so nothing can run out of its field; one-line
-- texts end in an ellipsis instead of wrapping.
local function addText(parent, font, y, lines, rightInset)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
  fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(rightInset or PAD), y)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(lines > 1)
  if fs.SetMaxLines then fs:SetMaxLines(lines) end
  local height = math.ceil((fs:GetLineHeight() or 12) * lines)
  fs:SetHeight(height)
  return fs, y - height
end

-- A "LIVE" dot, as on a news broadcast: red and pulsing while hosting, grey and still
-- when not. Solid colours cut round by the portrait mask (it exists on Forever: the dot
-- came out round in the beta). A dark ring that never pulses sits behind it - red on the
-- red Forever button was hard to see (Adam's screenshot, 24 Sep 2026). x and y place the
-- centre, counted from the middle of the parent's left edge.
local function makeLiveDot(parent, x, y)
  local function round(size, sublevel)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, sublevel)
    t:SetSize(size, size)
    t:SetPoint("CENTER", parent, "LEFT", x, y or 0)
    local mask = parent:CreateMaskTexture()
    if mask then
      mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(t)
      t:AddMaskTexture(mask)
    end
    return t
  end
  local ring = round(12, 1)
  ring:SetColorTexture(0.06, 0.02, 0.02)
  local dot = round(8, 2)
  local pulse = dot:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.3)
  fade:SetDuration(0.8)
  return dot, pulse, ring
end

local function showLive(dot, pulse, on)
  if on then
    dot:SetColorTexture(1, 0.2, 0.2)
    if not pulse:IsPlaying() then pulse:Play() end
  else
    dot:SetColorTexture(0.45, 0.45, 0.45)
    pulse:Stop()
    dot:SetAlpha(1)
  end
end

local function buildPanel()
  local p = CreateFrame("Frame", "LayerSwapPanel", UIParent)
  p:SetWidth(PANEL_W)
  p:SetPoint("CENTER", UIParent, "CENTER", 320, 120)
  p:SetFrameStrata("MEDIUM")
  p:SetClampedToScreen(true)
  p:SetMovable(true)
  p:EnableMouse(true)
  p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart", p.StartMoving)
  p:SetScript("OnDragStop", p.StopMovingOrSizing)

  local bg = p:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(p)
  bg:SetColorTexture(0.04, 0.05, 0.07, 0.92)
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                          { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
    local line = p:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.30, 0.52, 0.70, 0.9)
    line:SetPoint(side[1], p, side[1], 0, 0)
    line:SetPoint(side[2], p, side[2], 0, 0)
    if side[3] then line:SetHeight(1) else line:SetWidth(1) end
  end

  local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", p, "TOPRIGHT", 2, 2)
  -- the template's own click goes through HideUIPanel, which the game refuses in combat for an
  -- addon's window (Adam, 10 Oct 2026: the X did nothing in combat); a plain Hide works there
  close:SetScript("OnClick", function() p:Hide() end)
  p.closeButton = close

  -- the mini bar (the small line) is switched on and off from here, and with /ls mini: a
  -- real button with ON/OFF the way the Host button has it - grey text was missed (Adam, 26 Sep)
  p.lineButton = CreateFrame("Button", "LayerSwapPanelLineButton", p, "UIPanelButtonTemplate")
  p.lineButton:SetSize(92, 18)
  p.lineButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -30, -7)
  p.lineButton:SetNormalFontObject("GameFontNormalSmall")
  p.lineButton:SetHighlightFontObject("GameFontHighlightSmall")
  p.lineButton:SetScript("OnClick", function() toggleMini(); refresh() end)

  local y = -10
  p.title, y = addText(p, "GameFontNormal", y, 1, 30 + 92 + 4)
  p.title:SetText("LayerSwap")
  y = y - 10
  p.h1, y = addText(p, "GameFontDisableSmall", y, 1)
  p.h1:SetText("YOUR LAYER")
  y = y - 3
  p.layer, y = addText(p, "GameFontHighlightLarge", y, 1)
  y = y - 2
  p.detail, y = addText(p, "GameFontHighlightSmall", y, 1)
  y = y - 2
  p.evict, y = addText(p, "GameFontNormalSmall", y, 1)
  p.evict:SetTextColor(1, 0.6, 0.2)
  y = y - 10
  p.h2, y = addText(p, "GameFontDisableSmall", y, 1)
  y = y - 3
  p.rows = {}
  for i = 1, ROWS do
    local left, nextY = addText(p, "GameFontHighlightSmall", y, 1, PAD + 76)
    local right = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    right:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, y)
    right:SetWidth(72)
    right:SetHeight(math.ceil(right:GetLineHeight() or 12))
    right:SetJustifyH("RIGHT")
    right:SetWordWrap(false)
    -- the whole row is a button: click asks for that layer (only while one is listed)
    local hit = CreateFrame("Button", nil, p)
    hit:SetPoint("TOPLEFT", p, "TOPLEFT", PAD - 4, y + 1)
    hit:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(PAD - 4), y + 1)
    hit:SetHeight(y - nextY + 2)
    local lit = hit:CreateTexture(nil, "HIGHLIGHT")
    lit:SetAllPoints(hit)
    lit:SetColorTexture(1, 1, 1, 0.08)
    hit:SetScript("OnClick", function(self) if self.id then requestSwap(self.id, "row") end end)
    hit:SetScript("OnEnter", function(self)
      if not self.id then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Ask for " .. layerLabel(self.id))
      GameTooltip:AddLine("Only a LayerSwap host standing on it can tell - anyone else who invites may be anywhere.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = { left = left, right = right, y = y, hit = hit }
    y = nextY - 3
  end
  y = y - 8

  local buttonW = (PANEL_W - PAD * 2 - 8) / 2
  p.swapButton = CreateFrame("Button", "LayerSwapPanelSwapButton", p, "UIPanelButtonTemplate")
  p.swapButton:SetSize(buttonW, 24)
  p.swapButton:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, y)
  p.swapButton:SetScript("OnClick", function()
    local now = GetTime()
    if swapGroup and hostOnOurLayer(now) then leaveAndAskAgain("again")
    elseif swapGroup then leaveSwapGroup()
    elseif waitingAsk(now) and swap.channel then
      if now - swap.at >= STOP_AFTER then stopAsking("button") end
    else requestSwap(nil, "button") end
  end)
  p.hostButton = CreateFrame("Button", "LayerSwapPanelHostButton", p, "UIPanelButtonTemplate")
  p.hostButton:SetSize(buttonW, 24)
  p.hostButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, y)
  p.hostButton:SetScript("OnClick", function() setHosting(not hosting) end)
  p.hostDot, p.hostPulse = makeLiveDot(p.hostButton, 14)
  y = y - 24 - 8

  p.status, y = addText(p, "GameFontHighlightSmall", y, 2)
  y = y - 6
  p.hostLine, y = addText(p, "GameFontDisableSmall", y, 3)
  p:SetHeight(-y + 10)

  p:SetScript("OnShow", function(self)
    refresh()
    self.ticker = self.ticker or C_Timer.NewTicker(1, refresh)
  end)
  p:SetScript("OnHide", function(self)
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
  end)
  if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "LayerSwapPanel" end
  p:Hide()
  return p
end

refresh = function()
  noteNwb()
  refreshMini()
  local p = panel
  if not p or not p:IsShown() then return end
  local now = GetTime()
  local zone = GetRealZoneText() or ""
  if current then
    p.layer:SetText(layerLabel(current))
    p.detail:SetText(current .. "  -  " .. zone)
  else
    p.layer:SetText("Detecting...")
    p.detail:SetText("Target or mouse over an NPC or two.")
  end
  local r = refreshIn(now)
  p.evict:SetText(r == "soon" and "World refresh any moment now." or (r and ("World refresh in " .. r .. ".")) or "")

  local seen, today = seenInZone(), time()
  p.h2:SetText(#seen > 0 and "SEEN IN THIS ZONE - CLICK ONE TO ASK" or "SEEN IN THIS ZONE")
  local asking = swap and not swap.joinedAt and now - swap.at <= SWAP_TTL and swap.want
  for i, row in ipairs(p.rows) do
    local l = seen[i]
    -- the hint has the whole row to itself; a layer row stops short of its age on the right
    row.left:SetPoint("TOPRIGHT", p, "TOPRIGHT", -((l or i > 1) and (PAD + 76) or PAD), row.y)
    row.left:SetText(l and (layerLabel(l.id) .. "  -  " .. l.id) or (i == 1 and "Layers you have stood on appear here." or ""))
    row.right:SetText(l and (asking == l.id and "asking..." or agoText(today - l.last)) or "")
    row.hit.id = l and l.id or nil
    row.hit:SetShown(l ~= nil)
  end

  p.lineButton:SetText((mini and mini:IsShown()) and "Mini bar: |cff40ff40ON|r" or "Mini bar: |cffa0a0a0OFF|r")
  if swapGroup and hostOnOurLayer(now) then
    setButtonText(p.swapButton, "Leave and ask again")
    p.swapButton:SetEnabled(true)
  elseif swapGroup then
    setButtonText(p.swapButton, "Leave group")
    p.swapButton:SetEnabled(true)
  elseif waitingAsk(now) and swap.channel then
    -- the wait can be ended: a request is out in the layer channel and nothing has come of it
    -- yet (after /ls guild alone the button still asks the channel too; /ls stop ends either)
    setButtonText(p.swapButton, "Stop asking")
    p.swapButton:SetEnabled(now - swap.at >= STOP_AFTER)
  elseif FOREVER and not current then
    setButtonText(p.swapButton, "Reading layer...")
    p.swapButton:SetEnabled(false)
  else
    setButtonText(p.swapButton, "Swap layer")
    p.swapButton:SetEnabled(not ((swap and now - swap.at < SWAP_COOLDOWN) or now - stopped.at < SWAP_COOLDOWN))
  end
  -- ON has to be unmistakable at a glance: the LIVE dot pulses red
  p.hostButton:SetText(hosting and "Host: |cffff4040LIVE|r" or "Host: |cffa0a0a0OFF|r")
  showLive(p.hostDot, p.hostPulse, hosting)
  p.status:SetText(statusLine())
  -- "players asked for inv": the players who asked, each once, so one impatient asker does not count
  -- ten times; said in full, so it cannot be read as our own asks (Adam, 8 Oct 2026). The same line
  -- with Host off, only the label changes.
  -- Host off: the same design, the green word is "Asked for inv" (Adam, 8 Oct 2026)
  local who = stats.askers .. (stats.askers == 1 and " player" or " players")
  if askWaiting(now) then
    p.hostLine:SetText(askLine(now))
  elseif hosting then
    p.hostLine:SetText(string.format("|cff40ff40Hosting|r: %s asked for inv, %d invited, %d joined.", who, stats.invites, stats.joined))
  else
    p.hostLine:SetText(string.format("|cff40ff40Asked for inv|r: %s, %d invited, %d joined.", who, stats.invites, stats.joined))
  end
end

-- A click on any LayerSwap control is the hardware event the layer channel needs: a host who
-- never joined it (the default host) joins it here.
local function joinLayerChannel()
  if hosting and GetChannelName(LAYER_CHANNEL) == 0 then pcall(JoinChannelByName, LAYER_CHANNEL) end
end

local function togglePanel()
  joinLayerChannel()
  panel = panel or buildPanel()
  if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- ---------------------------------------------------------------------------------------
-- the layer menu: the LayerSwap logo on the mini line drops a list of the layers that can be
-- asked for - "any other layer" first, then the ones seen in this zone, then this one, greyed.

local MENU_W, MENU_ROW, MENU_LAYERS = 230, 18, 6
local menu

local function closeMenu()
  if menu then menu:Hide() end
end

local function buildMenu()
  local f = CreateFrame("Frame", "LayerSwapMenu", UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetWidth(MENU_W)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(f)
  bg:SetColorTexture(0.04, 0.04, 0.04, 0.92)
  f.items = {}
  if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "LayerSwapMenu" end
  f:Hide()
  return f
end

local function menuItem(i)
  local b = menu.items[i]
  if b then return b end
  b = CreateFrame("Button", nil, menu)
  b:SetHeight(MENU_ROW)
  b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * MENU_ROW)
  b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4 - (i - 1) * MENU_ROW)
  local lit = b:CreateTexture(nil, "HIGHLIGHT")
  lit:SetAllPoints(b)
  lit:SetColorTexture(1, 1, 1, 0.1)
  -- both texts are bound on both sides: the name stops before the age
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
  b.label:SetPoint("RIGHT", b, "RIGHT", -64, 0)
  b.label:SetJustifyH("LEFT")
  b.label:SetWordWrap(false)
  b.age = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.age:SetPoint("RIGHT", b, "RIGHT", -6, 0)
  b.age:SetWidth(56)
  b.age:SetJustifyH("RIGHT")
  b.age:SetWordWrap(false)
  b:SetScript("OnClick", function(self)
    if not self.enabled then return end
    -- nil = any layer but this one; the panel may be closed, so the status goes to chat.
    -- The ask goes out before the menu closes: nothing runs between the click and the send.
    local result = requestSwap(self.id, "menu")
    closeMenu()
    if result ~= "held" then sayStatus() end
  end)
  menu.items[i] = b
  return b
end

local function openMenu(anchor)
  menu = menu or buildMenu()
  local rows = { { text = current and "Any other layer" or "Any layer", enabled = true } }
  local seen = seenInZone()
  for i = 1, math.min(#seen, MENU_LAYERS) do
    local l = seen[i]
    rows[#rows + 1] = { text = layerLabel(l.id) .. "  -  " .. l.id, age = agoText(time() - l.last), id = l.id, enabled = true }
  end
  if #seen == 0 then rows[#rows + 1] = { text = "Layers you have stood on appear here.", enabled = false } end
  if current then rows[#rows + 1] = { text = layerLabel(current) .. "  -  you are here", enabled = false } end
  for i, r in ipairs(rows) do
    local b = menuItem(i)
    b.id, b.enabled = r.id, r.enabled
    b:EnableMouse(r.enabled)            -- a greyed row neither lights up nor clicks
    b.label:SetText(r.text)
    local shade = r.enabled and 1 or 0.55
    b.label:SetTextColor(shade, shade, shade)
    b.age:SetText(r.age or "")
    b:Show()
  end
  for i = #rows + 1, #menu.items do menu.items[i]:Hide() end
  menu:SetHeight(#rows * MENU_ROW + 8)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  menu:Show()
end

local function toggleMenu(anchor)
  if menu and menu:IsShown() then menu:Hide() else openMenu(anchor) end
end

-- ---------------------------------------------------------------------------------------
-- the mini line: stays on screen with the layer, LIVE while hosting, and the countdown when
-- the game announces a move. The logo drops the layer menu, a click elsewhere opens the
-- panel, drag moves it, /ls mini hides it.

local function miniText()
  local parts = { current and layerLabel(current) or "Detecting..." }
  if hosting then parts[#parts + 1] = "|cffff4040LIVE|r" end
  local now = GetTime()
  if swap and not swap.joinedAt and now - swap.at <= SWAP_TTL then parts[#parts + 1] = "|cffffd100asking|r" end
  local r = refreshIn(now)
  if r then parts[#parts + 1] = "|cffffb040refresh " .. (r == "soon" and "soon" or ("in " .. r)) .. "|r" end
  return table.concat(parts, "   ")
end

refreshMini = function()
  if not mini or not mini:IsShown() then return end
  mini.text:SetText(miniText())
  -- the line is as wide as its text, so the text can never run out of it
  mini:SetWidth(math.ceil(mini.text:GetStringWidth() or 0) + 52)
  showLive(mini.dot, mini.pulse, hosting)
end

local function saveMini()
  local point, _, _, x, y = mini:GetPoint()
  LayerSwapDB.mini = { point = point, x = x, y = y, hidden = not mini:IsShown() }
end

-- How dark the mini bar's background is, 0-100 (a user on CurseForge, 20 Oct 2026: "change
-- background or opacity of the minibar?"); 55 was the fixed value up to 1.12.
local MINI_BACKGROUND = 55
local function miniBackground()
  local v = LayerSwapDB.miniBackground
  if type(v) ~= "number" or v ~= v then return MINI_BACKGROUND end
  return math.max(0, math.min(100, math.floor(v + 0.5)))
end

local function applyMiniBackground()
  if mini and mini.bg then mini.bg:SetColorTexture(0, 0, 0, miniBackground() / 100) end
end

local function buildMini()
  local m = CreateFrame("Button", "LayerSwapMini", UIParent)
  m:SetHeight(20)
  m:SetFrameStrata("MEDIUM")
  m:SetClampedToScreen(true)
  m:SetMovable(true)
  m:RegisterForDrag("LeftButton")
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local pos = LayerSwapDB.mini
  if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" and type(pos.point) == "string" then
    m:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  else
    m:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
  local bg = m:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(m)
  bg:SetColorTexture(0, 0, 0, miniBackground() / 100)
  m.bg = bg
  -- the LayerSwap logo, left of the LIVE dot: a click drops the layer menu
  m.logo = CreateFrame("Button", "LayerSwapMiniLogo", m)
  m.logo:SetSize(16, 16)
  m.logo:SetPoint("LEFT", m, "LEFT", 3, 0)
  local icon = m.logo:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(m.logo)
  icon:SetTexture("Interface/AddOns/LayerSwap/Media/logo")
  local lit = m.logo:CreateTexture(nil, "HIGHLIGHT")
  lit:SetAllPoints(m.logo)
  lit:SetColorTexture(1, 1, 1, 0.15)
  m.logo:SetScript("OnClick", function() toggleMenu(m) end)
  m.dot, m.pulse = makeLiveDot(m, 30)
  m.text = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  m.text:SetPoint("LEFT", m, "LEFT", 42, 0)
  m.text:SetJustifyH("LEFT")
  m.text:SetWordWrap(false)
  m:SetScript("OnDragStart", function(self) self.moved = true; self:StartMoving() end)
  m:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); saveMini() end)
  m:SetScript("OnClick", function(self, button)
    if self.moved then self.moved = nil; return end     -- the end of a drag is not a click
    if button == "RightButton" then
      -- for anyone who does not want it on screen all the time
      toggleMini()
      say("the mini bar is hidden - the Mini bar button in the panel (/ls) or /ls mini brings it back.")
      refresh()
      return
    end
    togglePanel()
  end)
  -- no tooltips on the line: it sits on screen all the time, and one popping up at every
  -- pass of the mouse was in the way (Adam, 24 Sep 2026)
  m:SetScript("OnShow", function(self)
    refreshMini()
    self.ticker = self.ticker or C_Timer.NewTicker(1, refreshMini)   -- the countdown
  end)
  m:SetScript("OnHide", function(self)
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
    closeMenu()
  end)
  m:Hide()
  return m
end

toggleMini = function()
  mini = mini or buildMini()
  if mini:IsShown() then mini:Hide() else mini:Show() end
  saveMini()
end

-- ---------------------------------------------------------------------------------------
-- minimap button (LibDBIcon; the libraries ship inside LayerSwap): left-click the panel, right-click
-- the settings menu (Adam, 8 Oct 2026; hosting is switched in the panel or the menu). No LIVE dot
-- on the button: the mini line carries it (Adam, 25 Sep 2026)

local function minimapLibs()
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  local icons = LibStub and LibStub("LibDBIcon-1.0", true)
  return LDB, icons
end

local function minimapShown()
  return not (type(LayerSwapDB.minimap) == "table" and LayerSwapDB.minimap.hide)
end

local function toggleMinimap()
  local _, icons = minimapLibs()
  if not (icons and type(LayerSwapDB.minimap) == "table") then return end
  LayerSwapDB.minimap.hide = not LayerSwapDB.minimap.hide
  if LayerSwapDB.minimap.hide then icons:Hide("LayerSwap") else icons:Show("LayerSwap") end
end

-- ---------------------------------------------------------------------------------------
-- settings (Adam, 8 Oct 2026): a small menu on the minimap button's right-click, and the same
-- switches in the game's Options -> AddOns -> LayerSwap.

local showSettingsMenu, setupOptions
do
  local optionsFrame, optionsCategory, settingsMenu

  local function onOff(on) return on and "|cff40ff40ON|r" or "|cffa0a0a0OFF|r" end
  local function miniShown() return mini ~= nil and mini:IsShown() end
  local function panelShown() return panel ~= nil and panel:IsShown() end

  local function openOptions()
    if InCombatLockdown and InCombatLockdown() then say("the options open after combat."); return end
    if optionsCategory and Settings and Settings.OpenToCategory then
      pcall(Settings.OpenToCategory, optionsCategory:GetID())
    elseif optionsFrame and InterfaceOptionsFrame_OpenToCategory then
      -- the old options window lands on the page only at the second call
      pcall(InterfaceOptionsFrame_OpenToCategory, optionsFrame)
      pcall(InterfaceOptionsFrame_OpenToCategory, optionsFrame)
    end
  end

  local function hideMinimapButton()
    toggleMinimap()
    if not minimapShown() then
      say("the minimap button is hidden - Options -> AddOns -> LayerSwap or /ls minimap brings it back.")
    end
  end

  -- the menu: rows like the layer menu's; a switch keeps the menu open and shows its new state
  local function rows()
    return {
      { text = panelShown() and "Close the panel" or "Open the panel", run = togglePanel, close = true },
      { text = "Host: " .. onOff(hosting), run = function() setHosting(not hosting) end },
      { text = "Mini bar: " .. onOff(miniShown()), run = toggleMini },
      { text = "Minimap button: " .. onOff(true), run = hideMinimapButton, close = true },
      { text = "Options...", run = openOptions, close = true },
    }
  end

  local function render()
    local list = rows()
    for i, r in ipairs(list) do
      local b = settingsMenu.items[i]
      if not b then
        b = CreateFrame("Button", nil, settingsMenu)
        b:SetHeight(MENU_ROW)
        b:SetPoint("TOPLEFT", settingsMenu, "TOPLEFT", 4, -4 - (i - 1) * MENU_ROW)
        b:SetPoint("TOPRIGHT", settingsMenu, "TOPRIGHT", -4, -4 - (i - 1) * MENU_ROW)
        local lit = b:CreateTexture(nil, "HIGHLIGHT")
        lit:SetAllPoints(b)
        lit:SetColorTexture(1, 1, 1, 0.1)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
          local row = self.row
          if row.close then settingsMenu:Hide() end
          row.run()
          if settingsMenu:IsShown() then render() end
          refresh()
        end)
        settingsMenu.items[i] = b
      end
      b.row = r
      b.label:SetText(r.text)
      b:Show()
    end
    settingsMenu:SetHeight(#list * MENU_ROW + 8)
  end

  -- anchor: the minimap button; a second click on it closes the menu again
  showSettingsMenu = function(anchor)
    if settingsMenu and settingsMenu:IsShown() then settingsMenu:Hide(); return end
    closeMenu()
    if not settingsMenu then
      settingsMenu = CreateFrame("Frame", "LayerSwapSettingsMenu", UIParent)
      settingsMenu:SetFrameStrata("DIALOG")
      settingsMenu:SetClampedToScreen(true)
      settingsMenu:SetWidth(170)
      local bg = settingsMenu:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints(settingsMenu)
      bg:SetColorTexture(0.04, 0.04, 0.04, 0.92)
      settingsMenu.items = {}
      if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "LayerSwapSettingsMenu" end
    end
    render()
    settingsMenu:ClearAllPoints()
    if type(anchor) == "table" and anchor.GetObjectType then
      settingsMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
    else
      settingsMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    settingsMenu:Show()
  end

  -- Options -> AddOns -> LayerSwap: the same switches, each with a line on what it does
  setupOptions = function()
    if optionsFrame then return end
    local o = CreateFrame("Frame", "LayerSwapOptions", UIParent)
    o.name = "LayerSwap"
    o:Hide()
    local title = o:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", o, "TOPLEFT", 16, -16)
    title:SetText("LayerSwap")
    local sub = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetPoint("RIGHT", o, "RIGHT", -16, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText("See your layer, ask for a swap, and host swaps for others. /ls opens the panel.")
    o.checks = {}
    local y = -64
    local function check(key, label, note, get, set)
      local cb = CreateFrame("CheckButton", "LayerSwapOption" .. key, o, "UICheckButtonTemplate")
      cb:SetPoint("TOPLEFT", o, "TOPLEFT", 16, y)
      local name = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      name:SetPoint("LEFT", cb, "RIGHT", 4, 1)
      name:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      name:SetJustifyH("LEFT")
      name:SetWordWrap(false)
      name:SetText(label)
      local line = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      line:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
      line:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      line:SetJustifyH("LEFT")
      line:SetWordWrap(true)
      if line.SetMaxLines then line:SetMaxLines(2) end
      line:SetHeight(math.ceil((line:GetLineHeight() or 12) * 2))
      line:SetText(note)
      cb.get = get
      cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        self:SetChecked(get())
        refresh()
      end)
      o.checks[#o.checks + 1] = cb
      y = y - 46
    end
    o.sliders = {}
    -- A slider with its label, value and note. No Blizzard template, so it looks the same on
    -- Forever, Era and Anniversary (1.13); it glides, with no steps to snap to, and set() applies
    -- the value at once. The value text is bound on both sides, like every other text.
    local function slider(key, label, note, lines, minV, maxV, step, get, set, format)
      local sName = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      sName:SetPoint("TOPLEFT", o, "TOPLEFT", 20, y - 4)
      sName:SetText(label)
      local sValue = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      sValue:SetPoint("LEFT", sName, "RIGHT", 8, 0)
      sValue:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      sValue:SetJustifyH("LEFT")
      sValue:SetWordWrap(false)
      local sNote = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sNote:SetPoint("TOPLEFT", sName, "BOTTOMLEFT", 0, -3)
      sNote:SetPoint("RIGHT", o, "RIGHT", -16, 0)
      sNote:SetJustifyH("LEFT")
      sNote:SetWordWrap(lines > 1)
      local noteHeight = math.ceil((sNote:GetLineHeight() or 12) * lines)
      if lines > 1 then
        if sNote.SetMaxLines then sNote:SetMaxLines(lines) end
        sNote:SetHeight(noteHeight)
      end
      sNote:SetText(note)
      local s = CreateFrame("Slider", "LayerSwapOption" .. key, o)
      s:SetOrientation("HORIZONTAL")
      s:SetSize(200, 16)
      s:SetPoint("TOPLEFT", sNote, "BOTTOMLEFT", 0, -8)
      s:SetMinMaxValues(minV, maxV)
      s:SetValueStep(step)
      s:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
      local track = s:CreateTexture(nil, "BACKGROUND")
      track:SetPoint("LEFT", s, "LEFT", 0, 0)
      track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
      track:SetHeight(4)
      track:SetColorTexture(0.25, 0.25, 0.25, 0.9)
      s.get, s.valueText, s.format = get, sValue, format
      s:SetScript("OnValueChanged", function(_, value)
        sValue:SetText(format(set(tonumber(value))))
      end)
      o.sliders[#o.sliders + 1] = s
      y = y - 52 - noteHeight
    end
    -- Host: the same lasting switch as the panel's Host button and /ls host (1.12, two users on
    -- CurseForge, 14-16 Oct 2026: "no way to turn off hosting permanently" - 1.11.2's separate
    -- "Host at login" box was missed, since the Host button is the switch people see)
    check("Host", "Host", "Invite players who ask for a layer, only while you are alone. Off stays off at every login until you turn it on again.",
      function() return hosting end,
      function(on) if on ~= hosting then setHosting(on) end end)
    if FOREVER then
      -- Skip askers near you (1.14; a user on CurseForge, 23 Oct 2026, farming a spot with Host
      -- on). Off to start. The notes say what gets past it: another host in the zone, a whisper,
      -- and that an ask without a position is skipped too (see Near.check).
      check("SkipNear", "Skip askers near you",
        "With Host on, you skip anyone who asks from within the distance below, so a swap does not bring someone to the spot you farm. Other hosts in your zone still invite.",
        Near.on,
        function(on)
          LayerSwapDB.skipNear = on and true or false
          log("near", on and "on" or "off")
        end)
      slider("SkipNearDistance", "Distance",
        "Closer than this, and the asker is skipped. An ask that carries no position (an older LayerSwap, or an ask in General) is skipped too.", 2,
        Near.MIN, Near.MAX, 10, Near.yards,
        function(value)
          local n = math.max(Near.MIN, math.min(Near.MAX, math.floor((value or Near.DEFAULT) / 10 + 0.5) * 10))
          if n ~= Near.yards() then LayerSwapDB.skipNearYards = n end
          return n
        end,
        function(v) return v .. " yards" end)
    end
    check("MiniBar", "Mini bar", "The small line with your layer, the LIVE dot and the world refresh countdown.",
      miniShown, function(on) if on ~= miniShown() then toggleMini() end end)
    check("Minimap", "Minimap button", "Left-click opens the panel, right-click the settings menu.",
      minimapShown, function(on) if on ~= minimapShown() then toggleMinimap() end end)
    -- Mini bar background: a slider, 0-100 % (1.13); the line fades with it as it moves (Adam,
    -- 21 Oct 2026: "seamless"), and the value is kept across logins.
    slider("MiniBackground", "Mini bar background",
      "How dark the small line's background is. 0% is see-through, 100% is solid.", 1,
      0, 100, 1, miniBackground,
      function(value)
        local pct = math.max(0, math.min(100, math.floor((value or MINI_BACKGROUND) + 0.5)))
        if pct ~= miniBackground() then
          LayerSwapDB.miniBackground = pct
          applyMiniBackground()
        end
        return pct
      end,
      function(v) return v .. "%" end)
    local open = CreateFrame("Button", "LayerSwapOptionsOpen", o, "UIPanelButtonTemplate")
    open:SetSize(150, 22)
    open:SetPoint("TOPLEFT", o, "TOPLEFT", 20, y - 6)
    open:SetText("Open the panel")
    open:SetScript("OnClick", function() if not panelShown() then togglePanel() end end)
    o:SetScript("OnShow", function(self)
      for _, cb in ipairs(self.checks) do cb:SetChecked(cb.get()) end
      for _, s in ipairs(self.sliders) do
        s:SetValue(s.get())
        s.valueText:SetText(s.format(s.get()))
      end
    end)
    optionsFrame = o
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
      local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, o, "LayerSwap")
      if ok and category then
        optionsCategory = category
        pcall(Settings.RegisterAddOnCategory, category)
      end
    elseif InterfaceOptions_AddCategory then
      pcall(InterfaceOptions_AddCategory, o)
    end
  end
end

local function setupMinimap()
  local LDB, icons = minimapLibs()
  if not (LDB and icons) then return end
  if type(LayerSwapDB.minimap) ~= "table" then LayerSwapDB.minimap = {} end
  local launcher = LDB:NewDataObject("LayerSwap", {
    type = "launcher",
    icon = "Interface/AddOns/LayerSwap/Media/logo",
    OnClick = function(button, mouse)
      joinLayerChannel()
      if mouse == "RightButton" then showSettingsMenu(button) else togglePanel() end
    end,
    OnTooltipShow = function(tt)
      tt:AddLine("LayerSwap")
      tt:AddLine((current and layerLabel(current) or "Detecting...") .. (hosting and "   |cffff4040LIVE|r" or ""), 1, 1, 1)
      tt:AddLine("Left-click: the panel.  Right-click: settings.", 0.7, 0.7, 0.7)
    end,
  })
  icons:Register("LayerSwap", launcher, LayerSwapDB.minimap)
end

-- ---------------------------------------------------------------------------------------
-- after a host who did not move us (1.9)

-- In the group of a host on our layer, or in another zone, nothing changes until the player
-- leaves (a user on CurseForge, 10 Oct 2026: "I don't want to keep leaving party and requesting
-- again"). LayerSwap leaves by itself, and names that host if it invites again. The ask
-- itself is the player's click: the game blocks the channel line without one, while leaving the
-- group works without (both measured 10 Oct 2026: ADDON_ACTION_BLOCKED on the line, "You leave
-- the group." on the leave). So the panel opens with Swap layer ready, one click away.
local function autoLeave(joined)
  if not FOREVER then return end
  local host = joined.inviter or "The host"
  if joined.inviter and current then
    sameHosts[joined.inviter] = { at = GetTime(), layer = current, elsewhere = joined.elsewhere }
  end
  local only = not joined.elsewhere and onlyLayerHere()
  log("autoLeave", joined.inviter, current, joined.elsewhere and ("in " .. joined.elsewhere) or "on our layer",
    only and "the only layer seen in this zone" or nil)
  if IsInGroup() then pcall(leaveParty) end
  leftInfo = { at = GetTime(), layer = current }
  swapGroup, swap = false, nil
  C_Timer.After(2, function() log("leftCheck", IsInGroup() and "still in a group" or "out") end)
  local line, chat
  if joined.elsewhere then
    line = host .. " was in " .. joined.elsewhere .. ". Click Swap layer to ask again."
    chat = host .. " was in " .. joined.elsewhere .. ", so nothing changed - the game only moves you to a host in your own zone."
      .. " LayerSwap left the group - click Swap layer in the panel to ask again."
  elseif only then
    line = host .. " was on your layer - the only one seen here. Try a busier zone."
    chat = host .. " was on your layer, so nothing changed. Only one layer has been seen in " .. only
      .. " - it may have just one right now, so try a busier zone. LayerSwap left the group."
  else
    line = host .. " was on your layer. Click Swap layer to ask again."
    chat = host .. " was on your layer, so nothing changed. LayerSwap left the group - click Swap layer in the panel to ask again."
  end
  setNotice(line, 60)
  say(chat)
  panel = panel or buildPanel()
  if not panel:IsShown() then panel:Show() end
  refresh()
end

-- An invite from a host who did not move us: said, never declined - the invite is the player's
-- (1.10; 1.9 declined it while an ask waited, and a declined invite was itself reported to change
-- the layer, forever-bugs #33). The panel and chat name the host and where it was.
local function warnInvite(name, seen, ago)
  local where = seen.elsewhere and ("was in " .. seen.elsewhere) or "was on your layer"
  log("sameHostAgain", name, current, seen.elsewhere or "same layer", ago)
  say(name .. " " .. where .. " " .. ago .. " - decline and wait for another host.")
  setNotice(name .. " " .. where .. " " .. ago .. ". Decline and wait for another host.", 30)
  refresh()
end

-- ---------------------------------------------------------------------------------------
-- events

local onEnterWorld   -- below the handler: login or reload, and the login line

local f = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
                      "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE",
                      "GROUP_ROSTER_UPDATE", "GROUP_JOINED", "GROUP_LEFT", "PARTY_INVITE_REQUEST",
                      "SHARD_TRANSFER_IMMINENT", "SHARD_TRANSFER",
                      "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                      "ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED", "CHAT_MSG_ADDON",
                      "CHANNEL_COUNT_UPDATE", "CHANNEL_ROSTER_UPDATE" }) do
  pcall(f.RegisterEvent, f, ev)
end
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, NOTE_PREFIX) end

f:SetScript("OnEvent", function(_, ev, a1, a2, _, a4, _, _, zoneChannelID, _, channelBaseName)
  if ev == "NAME_PLATE_UNIT_ADDED" then
    if not isSecret(a1) and type(a1) == "string" then observe(a1) end
  elseif ev == "PLAYER_TARGET_CHANGED" then
    observe("target")
  elseif ev == "UPDATE_MOUSEOVER_UNIT" then
    observe("mouseover")
  elseif ev == "CHAT_MSG_CHANNEL" then
    local where
    if not isSecret(channelBaseName) and type(channelBaseName) == "string"
       and string.lower(channelBaseName) == LAYER_CHANNEL then
      where = "layer"
    elseif not isSecret(zoneChannelID) and zoneChannelID == 1 then
      where = "general"
    end
    if where then onChat(where, a1, a2) end
  elseif ev == "CHAT_MSG_WHISPER" then
    onChat("whisper", a1, a2)
  elseif ev == "CHAT_MSG_GUILD" then
    onChat("guild", a1, a2)
  elseif ev == "CHAT_MSG_ADDON" then
    -- prefix, text, chat type, sender
    if not isSecret(a1) and a1 == NOTE_PREFIX then onNote(a2, a4) end
  elseif ev == "CHAT_MSG_SYSTEM" or ev == "UI_ERROR_MESSAGE" then
    local text = (ev == "UI_ERROR_MESSAGE") and a2 or a1
    if not isSecret(text) and type(text) == "string" then
      if GetTime() <= watchUntil then log(ev == "UI_ERROR_MESSAGE" and "error" or "system", text) end
      -- our invite never counted - another host's got there first, or the asker sat in a group
      -- already - so the asker's next ask is ours to answer. Read at any time: on 10 Oct 2026
      -- the game's reply to an invite came later than the few seconds logged above.
      local why = refusal(text)
      if why then
        for name in pairs(pending) do
          if string.find(text, name, 1, true) then
            pending[name], lastInvite[name] = nil, nil
            log("freed", name, why)
          end
        end
      end
    end
  elseif ev == "CHANNEL_COUNT_UPDATE" or ev == "CHANNEL_ROSTER_UPDATE" then
    onChannelCount(ev, a1, a2)
  elseif ev == "GROUP_ROSTER_UPDATE" then
    onRoster()
  elseif ev == "PARTY_INVITE_REQUEST" then
    local now = GetTime()
    local name = not isSecret(a1) and type(a1) == "string" and a1 or nil
    local seen = name and sameHosts[name]
    if seen and not (current and seen.layer == current and now - seen.at <= SAME_HOST_TTL) then seen = nil end
    local mins = seen and math.floor((now - seen.at) / 60)
    local ago = mins and (mins < 1 and "a moment ago" or (mins .. " min ago"))
    if seen then warnInvite(name, seen, ago) end
    if name and waitingAsk(now) then
      swap.inviter, swap.inviterSeen = name, seen and true or nil
      log("invited", name, string.format("%.1f s after asking", now - swap.at))
      refresh()
    end
  elseif ev == "GROUP_JOINED" then
    joinedGroupAt = GetTime()
    if not FOREVER then forgetSightings() end   -- no transfer event on Classic to do it
    -- only a group someone invited us into is a host's group: a group we formed by
    -- inviting others is our own, and they came to our layer (beta, 24 Sep 2026)
    if swap and swap.inviter and not swap.joinedAt and GetTime() - swap.at <= SWAP_TTL then
      swap.joinedAt, swapGroup = GetTime(), true
      watchUntil = GetTime() + 20               -- "Party converted to Raid", who else joins ...
      log("joinedHost", swap.inviter, current)
      -- the panel may be closed: say it in chat once, if the game did not move us
      local joined = swap
      C_Timer.After(SAME_LAYER_AFTER + 0.2, function()
        log("hostZone", joined.inviter, hostZone(joined.inviter) or "unknown", zoneOf("player") or "unknown",
          joined.transferAt and "moved" or "not moved")
        if swap == joined and hostOnOurLayer(GetTime()) then
          -- out of the group by itself; the next ask is one click (1.9). A host in another
          -- zone moves nobody, so that one is left at once; one in our zone gets until
          -- SAME_LAYER_LEAVE, in case the move is only late (1.10).
          if joined.elsewhere then
            autoLeave(joined)
          else
            C_Timer.After(SAME_LAYER_LEAVE - SAME_LAYER_AFTER - 0.2, function()
              if swap == joined and hostOnOurLayer(GetTime()) then autoLeave(joined) end
            end)
          end
        end
      end)
      refresh()
    elseif FOREVER then
      -- any other group (the group finder, a friend): who leads it, where, and did the game move
      -- us? (Adam, 8 Oct 2026: a group-finder group moved him to another layer.) Logged only.
      local at = joinedGroupAt
      C_Timer.After(SAME_LAYER_AFTER + 0.2, function()
        for i = 1, PARTY_MAX - 1 do
          local unit = "party" .. i
          if UnitExists(unit) and UnitIsGroupLeader(unit) then
            log("groupZone", fullName(unit), zoneOf(unit) or "unknown", zoneOf("player") or "unknown",
              lastShardAt > at and "moved" or "not moved")
            break
          end
        end
      end)
    end
  elseif ev == "GROUP_LEFT" then
    onRoster()                                  -- a host's last guest leaving ends the group
    if swapGroup then
      swapGroup = false
      leftInfo = { at = GetTime(), layer = current }
      log("left", current)
      if swap then swap = nil end
      if held then
        held = nil
        -- Once, right after a swap that worked, and only while Host is off: the moment someone
        -- has been helped is the moment to ask them to help the next one (Adam, 8 Oct 2026 - the
        -- channel holds 46-56 players and hardly any hosts). Never again once it has been said.
        if not hosting and not LayerSwapDB.hostAsked then
          LayerSwapDB.hostAsked = true
          setNotice("Help the next one: turn Host on. You only invite while you are alone.", 60)
          say("help the next one: turn Host on in the panel - you only invite while you are alone, and the group is theirs to leave.")
        else
          setNotice("You left the group - the game moves you back to your own layer.", 30)
        end
      end
      refresh()
    end
  elseif ev == "SHARD_TRANSFER_IMMINENT" then
    local left = type(GetEvictionTimeRemaining) == "function" and GetEvictionTimeRemaining() or nil
    evictAt = (not isSecret(left) and type(left) == "number") and (GetTime() + left) or nil
    log("shard", ev, left)
    refresh()
  elseif ev == "SHARD_TRANSFER" or ev == "ZONE_CHANGED_NEW_AREA" or ev == "PLAYER_ENTERING_WORLD" then
    -- the world around the player may be another one now: believe nothing until two
    -- creatures have been seen again
    if ev == "SHARD_TRANSFER" then
      evictAt, lastShardAt = nil, GetTime()
      log("shard", ev)
      -- in the host's group: the game moved us, so the host is on another layer
      if swap and swap.joinedAt and not swap.transferAt then
        swap.transferAt = GetTime()
        log("transfer", string.format("%.1f s after joining", swap.transferAt - swap.joinedAt))
        -- a move after the 'same layer' verdict: the verdict was wrong, so it is forgotten (1.10)
        if swap.sameLogged and swap.inviter then sameHosts[swap.inviter] = nil end
      end
    end
    forgetSightings()
    if ev ~= "PLAYER_ENTERING_WORLD" or current == nil then
      if current then log("layer", "unknown", nil, current) end
      if swap and swap.joinedAt and swap.from == nil then swap.from = "unknown" end
      current = nil
    end
    if ev == "PLAYER_ENTERING_WORLD" then onEnterWorld(a1 == true, a2 == true) end
    refresh()
  elseif ev == "ADDON_ACTION_FORBIDDEN" or ev == "ADDON_ACTION_BLOCKED" then
    if a1 == ADDON then
      log("blocked", ev, a2)
      if sendingAsk then
        askHeldBack = true    -- a swap ask: requestSwap says it in plain words
      else
        say("the game blocked " .. tostring(a2) .. " - that action needs a click on this client.")
      end
    end
  elseif ev == "PLAYER_LOGIN" then
    -- One session per log. The log is read from disk after a /reload, so the session that
    -- was just written is kept one more round instead of being wiped by this login.
    LayerSwapDB.previous = { session = LayerSwapDB.session, log = LayerSwapDB.log }
    LayerSwapDB.log = {}
    LayerSwapDB.session = { started = date("%Y-%m-%d %H:%M:%S"), version = "1.14", me = fullName("player"), toc = TOC }
    -- The layers seen survive a /reload and a relog; an hour without a sighting drops one.
    local saved = type(LayerSwapDB.layers) == "table" and LayerSwapDB.layers or {}
    layers, layerCount = {}, 0
    for id, l in pairs(saved) do
      if type(l) == "table" and type(l.last) == "number" and type(l.n) == "number" and time() - l.last <= LAYER_TTL then
        layers[id] = l
        if l.n > layerCount then layerCount = l.n end
      end
    end
    LayerSwapDB.layers = layers
    -- Host is ON from the first login (Adam, 8 Oct 2026: the layer channel held 56 players and 11
    -- asks in 7 minutes, and he was the only host), and the switch lasts (1.12): off stays off at
    -- every login until it is turned on again. 1.8-1.11.2 turned it on again at every login, and
    -- two users on CurseForge read that as "no way to turn off hosting permanently". Whether this
    -- is a login or a reload is known at PLAYER_ENTERING_WORLD (onEnterWorld), where the lines
    -- are said. The host invites only while alone or leading a group it filled itself (canInvite).
    -- 1.11.2 kept the lasting choice apart, as Host at login: unticked, it is honoured once as Host
    -- off, and the key is dropped either way.
    if LayerSwapDB.hostAtLogin == false then LayerSwapDB.hosting = false end
    LayerSwapDB.hostAtLogin = nil
    hosting = LayerSwapDB.hosting ~= false
    log("hosting", hosting and "on" or "off", "at login")
    mini = mini or buildMini()
    if not (type(LayerSwapDB.mini) == "table" and LayerSwapDB.mini.hidden) then mini:Show() end
    setupMinimap()
    setupOptions()
    refresh()
  end
end)

-- The first PLAYER_ENTERING_WORLD of a session says whether it is a login or a /reload; the
-- login line is said here. Host itself was read at PLAYER_LOGIN and lasts across logins.
local entered = false
onEnterWorld = function(_, isReload)
  if entered then return end
  entered = true
  if hosting and not LayerSwapDB.hostSaid then
    -- the off switch, said plainly the first time, and in the panel when it opens
    LayerSwapDB.hostSaid = true
    say("type /ls to open the panel. Hosting is ON: you invite players who ask for a layer, only while you are alone."
      .. " The Host button in the panel or /ls host turns it off, and off stays off until you turn it on again.")
    setNotice("Hosting is on: you invite players who ask for a layer, only while you are alone. Host turns it off, and off stays off.", 300)
  elseif hosting and isReload then
    say("type /ls to open the panel. Hosting is ON.")
  elseif hosting then
    say("type /ls to open the panel. Hosting is ON - the Host button or /ls host turns it off.")
  else
    say("type /ls to open the panel. Hosting is OFF - the Host button or /ls host turns it on.")
  end
  if hosting then
    -- the layer channel can only be joined from a click; the game rejoins it by itself once joined
    C_Timer.After(10, function()
      if hosting and GetChannelName(LAYER_CHANNEL) == 0 then
        say("hosting hears General, guild chat and whispers - open the panel (/ls) once to hear the layer channel too.")
      end
    end)
  end
  refresh()
end

-- ---------------------------------------------------------------------------------------
-- slash

local function status()
  say(string.format("you are on %s%s. Hosting is %s: %d request(s) seen, %d invite(s) sent, %d joined, %d skipped.",
    layerLabel(current), current and (" (" .. current .. ")") or "", hosting and "ON" or "OFF",
    stats.requests, stats.invites, stats.joined, stats.skipped))
  if hosting then
    local ok, why = canInvite()
    say(ok and "ready to invite." or ("not inviting right now: " .. why .. "."))
    if Near.on() then say("skipping askers within " .. Near.yards() .. " yards of you.") end
    if GetChannelName(LAYER_CHANNEL) == 0 then say("you are not in the '" .. LAYER_CHANNEL .. "' channel - type /join " .. LAYER_CHANNEL) end
  end
end

SLASH_LAYERSWAP1 = "/ls"
SLASH_LAYERSWAP2 = "/layerswap"
SlashCmdList["LAYERSWAP"] = function(msg)
  msg = string.lower(strtrim(tostring(msg or "")))
  if msg == "" then
    togglePanel()
  elseif msg == "host" or msg == "on" or msg == "off" then
    if msg == "host" then setHosting(not hosting) else setHosting(msg == "on") end
    status()
  elseif msg == "swap" then
    if requestSwap(nil, "slash") ~= "held" then sayStatus() end
  elseif msg == "guild" then
    if requestGuild("slash") ~= "held" then sayStatus() end
  elseif msg == "stop" then
    if stopAsking("slash") then sayStatus() else say("you are not asking for a swap right now.") end
  elseif not FOREVER and msg:match("^swap%s+%d+$") then
    -- /ls swap 2 (Classic): NWB's layer 2 - AutoLayer hosts on it answer even if we never stood there
    local n, zone, target = tonumber(msg:match("^swap%s+(%d+)$")), GetRealZoneText()
    for id, l in pairs(layers) do
      if l.nwb == n and l.zone == zone then target = id end
    end
    if requestSwap(target, "slash", false, n) ~= "held" then sayStatus() end
  elseif msg:match("^swap%s+%a$") then
    -- /ls swap B: the letter the panel shows, in this zone
    local letter, zone, target = string.upper(msg:match("^swap%s+(%a)$")), GetRealZoneText()
    for id, l in pairs(layers) do
      if l.letter == letter and l.zone == zone then target = id end
    end
    if target then
      if requestSwap(target, "slash") ~= "held" then sayStatus() end
    else say("no Layer " .. letter .. " seen in this zone - the panel lists the ones you can ask for.") end
  elseif msg == "kick" then
    kickHosted()
  elseif msg == "status" then
    status()
  elseif msg == "mini" then
    toggleMini()
  elseif msg == "minimap" then
    toggleMinimap()
  elseif msg == "spot" and FOREVER then
    -- where the game says you stand, logged raw (1.14): the reading behind Skip askers near you
    local room = #(LayerSwapDB.log or {}) < LOG_MAX
    local ok, p, why, raw, moved = pcall(Near.probe, "probe")
    if not ok then
      say("the position reading failed: " .. tostring(p))
    else
      say((p and ("position " .. p.kind .. " " .. p.ref .. " " .. p.x .. " " .. p.y) or ("no position: " .. tostring(why)))
        .. (moved and (" - " .. moved) or "") .. " (" .. table.concat(raw, "; ") .. "). "
        .. (room and "Logged; /reload saves it to disk." or "Not logged: the log is full."))
    end
  else
    say("/ls - open the panel   |   /ls mini - show or hide the small line   |   /ls minimap - show or hide the minimap button   |   /ls swap - ask for any other layer   |   /ls swap B - ask for Layer B   |   /ls guild - ask your guild   |   /ls stop - stop asking   |   /ls host - start or stop hosting   |   /ls kick - remove the players LayerSwap invited"
      .. (FOREVER and "   |   /ls spot - log where you stand" or "") .. "   |   /ls status")
  end
end
