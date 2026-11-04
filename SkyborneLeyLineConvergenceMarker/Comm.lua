-- Crowdsourced sightings: when the racial or a minimap scan confirms a node, broadcast it on a hidden channel with
-- the phase and server time. Other users in the same phase tint that pin green, fading to red.
--
-- Messages (":" separated, no pipes):
--   R:v:fac:phase:mapID:x:y:t          one sighting (x, y as 0-9999)
--   Q:v:fac:phase                      "what do you have for this phase?" (login / phase change)
--   S:v:fac:phase:mapID,x,y,t;...      reply to Q
--   F:v:fac                            "what have you found that isn't in Data.lua?" (/sllcm share found)
--   L:v:fac:mapID,x,y;...              reply to F: self-found locations, learned as shared ones
-- Heard but never sent (Skyborne Compass's own, same fields): a known node its minimap scan passed and found
-- no blip at in that phase.
--   XM:v:fac:phase:mapID:x:y:t         one "not there"
--   XS:v:fac:phase:mapID,x,y,t;...     its reply to a Q with the "not there"s it holds

local ADDON, ns = ...

local PREFIX = "SLLCM"
local CHANNEL_BASE = "SLLCMShare"  -- + A / H: one channel per faction
local VERSION = "1"
local TTL = 90 * 60         -- a sighting fades green to red over this many seconds, then is dropped
local MAX_PER_REPLY = 9      -- entries per S message, keeps it under 255 bytes
local MAX_FOUND_PER_REPLY = 15 -- the same for L (no time in its entries)
-- Forever's channel allowance is about 10 at once then ~0.8/s, and retrying while refused keeps it
-- refusing; a pause of a few seconds clears it
local SEND_GAP = 1.25
local THROTTLE_PAUSE = 5
local CHANNEL_RETRIES = 3    -- InvalidChannel just after joining (the join not through yet): retry this often
local CONFIRMATIONS = 2      -- different NPC kinds agreeing before a known phase is replaced
local SCAN_SECONDS = 60      -- re-read nameplates this often (the shard can change while standing still)
local RESTORE_SECONDS = 300  -- a saved phase is reused only this soon after logout / reload
local QUERY_MEMORY = 300     -- a Q for a phase (ours or one heard) from before a /reload still counts this long
local REORDER_SECONDS = 60   -- after joining, game channels arriving above ours get moved below it this long
local MAX_SWAPS = 10         -- channel swaps allowed per join (the game has about 10 channels)

local reports = {}           -- this faction's: reports[mapID] = { { phase, x, y, t, first }, ... }
local allReports = {}        -- db.crowdReports = { A = reports, H = reports }: an alt of the other faction
                             -- must never show or answer with this one's sightings
local gone = {}              -- "not there" reports (XM / XS), the same way: gone[mapID] = { { phase, x, y, t }, ... }.
                             -- Kept apart from reports: Mapzeroth reads db.crowdReports as sightings.
local allGone = {}           -- db.crowdGone = { A = gone, H = gone }
local phase                  -- current phase (zoneUID as a string), nil until learned
local phaseMap               -- zone the phase was read in
local tentativeNpc           -- phase came from one NPC kind only: any other reading replaces it
local candidates = {}        -- candidates[phase] = { [npcID] = true, n = count }
local waiting                -- own sighting made before the phase was known
local asked = {}             -- asked[phase] = true once a Q for it, ours or one heard, has gone out this session
local queried = {}           -- this faction's: queried[phase] = GetServerTime() of the last Q for it, ours or heard
                             -- (db.crowdQueried = { A = queried, H = queried }), so a /reload doesn't ask again
local joinedAt               -- GetTime() we joined the channel: after TTL we've heard every sighting there is
local pending = {}           -- pending[phase] = { mapID, x, y, ... } while we wait to answer a Q for it: what other
                             -- answers for the phase have covered meanwhile
local replying = {}          -- replying[p] = true while our answer for the phase is going out, part by part
local foundPending          -- the same for an F: locations other L answers have covered meanwhile
local foundAnswered          -- an F is answered once a session, so repeated ones can't keep the channel busy
local foundAsked             -- we sent an F this session: say what the answers teach us
local queue, sending = {}, false
local channelRetries = 0     -- InvalidChannel retries spent on queue[1]
local me = {}                -- our names as senders show them
local debug                  -- /sllcm share debug: print traffic
local reorderUntil           -- GetTime() until which our channel is kept numbered after the game's
local swapsLeft = 0          -- channel swaps still allowed in that time

-- debug lines carry the local time to a tenth of a second, to tell bursts from spread-out traffic. The clock
-- is time() pinned to GetTime() once, so the tenths stay in step with the seconds.
local clockBase = time() - GetTime()
local function Debug(msg, ...)
  if not debug then return end
  local now = clockBase + GetTime()
  ns.Print("|cff888888%s.%d " .. msg .. "|r", date("%H:%M:%S", math.floor(now)), math.floor(now * 10) % 10, ...)
end

local function Enabled()
  local db = ns.GetDB()
  return db and db.crowd
end

local function FactionTag()
  return ns.Faction().key == "LeyLines" and "A" or "H"
end

local function ChannelName()
  return CHANNEL_BASE .. FactionTag()
end

-- nil for secret values (encounters, combat) and failed reads
local function Clean(v)
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if not ok or secret then return nil end
  end
  return v
end

local function PlayerMap()
  return C_Map.GetBestMapForUnit("player")
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function ChannelIndex()
  local id = GetChannelName(ChannelName())
  return type(id) == "number" and id > 0 and id or nil
end

local function Drain()
  local msg = queue[1]
  local id = ChannelIndex()
  if not msg or not id then
    sending = false
    return
  end
  local ok, r = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "CHANNEL", id)
  -- older clients return a boolean, newer ones Enum.SendAddonMessageResult (0 = success)
  if ok and (r == nil or r == true or r == 0) then
    table.remove(queue, 1)
    channelRetries = 0
    Debug(">> %s", msg)
    C_Timer.After(SEND_GAP, Drain)
  elseif ok and (r == 3 or r == 8) then -- AddonMessageThrottle, ChannelThrottle
    Debug("throttled, pausing")
    C_Timer.After(THROTTLE_PAUSE, Drain)
  elseif ok and r == 7 and channelRetries < CHANNEL_RETRIES then -- InvalidChannel
    channelRetries = channelRetries + 1
    Debug("channel not ready (retry %d): %s", channelRetries, msg)
    C_Timer.After(THROTTLE_PAUSE, Drain)
  else
    table.remove(queue, 1)
    channelRetries = 0
    Debug("send failed (%s): %s", tostring(r), msg)
    C_Timer.After(SEND_GAP, Drain)
  end
end

local function Send(msg)
  if not Enabled() then return end
  queue[#queue + 1] = msg
  if not sending then
    sending = true
    Drain()
  end
end

-- Only zones with known nodes are worth asking about: the channel holds the whole megarealm's faction
local function HasNodes(mapID)
  local key, db = ns.Faction().key, ns.GetDB()
  local found = db and db.found[key][mapID]
  return mapID and ((SLLCM_Data[key][mapID] and #SLLCM_Data[key][mapID] > 0) or (found and #found > 0))
end

-- Everyone on the channel hears every sighting and every reply, whatever their phase, and keeps them. So
-- once on the channel we have everything said there; a Q is only for sightings made before we joined.
-- Each phase is asked about once a session, and not at all after TTL on the channel. For the same reason a Q heard
-- from someone else does for us (we hear the answers), and so does one from just before a /reload.
local function Query()
  if not phase or not HasNodes(phaseMap) or asked[phase] then return end
  if not joinedAt or GetTime() - joinedAt > TTL then return end
  asked[phase] = true
  local now = GetServerTime()
  if queried[phase] and now - queried[phase] <= QUERY_MEMORY then
    Debug("no Q for phase %s: one went out %d s ago, before the /reload", phase, now - queried[phase])
    return
  end
  queried[phase] = now
  Send(format("Q:%s:%s:%s", VERSION, FactionTag(), phase))
end


---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------

local function Prune(list)
  local now = GetServerTime()
  for i = #list, 1, -1 do
    if now - list[i].t > TTL then table.remove(list, i) end
  end
end

-- Sightings belong on zone maps. Another addon on the channel has been seen sending continent coordinates
-- (Kalimdor, 1414): move those to the zone at that spot. nil if there's no zone there.
local function OnZoneMap(mapID, x, y)
  local info = C_Map.GetMapInfo(mapID)
  if not info then return end
  if info.mapType ~= Enum.UIMapType.Continent then return mapID, x, y end
  local zone = C_Map.GetMapInfoAtPosition(mapID, x, y)
  if not (zone and zone.mapType == Enum.UIMapType.Zone) then return end
  local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
  if not world then return end
  local _, pos = C_Map.GetMapPosFromWorldPos(continent, world, zone.mapID)
  if pos then return zone.mapID, pos.x, pos.y end
end

-- A heard position on a zone map, fresh enough to keep; nil if not
local function Valid(mapID, x, y, t)
  local now = GetServerTime()
  if not (x >= 0 and x <= 1 and y >= 0 and y <= 1) then return end
  mapID, x, y = OnZoneMap(mapID, x, y)
  if not (mapID and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return end
  if t > now + 60 or now - t > TTL then return end
  return mapID, x, y
end

-- The entry for the same node in the same phase, and its index
local function Find(list, p, mapID, x, y)
  if not list then return end
  Prune(list)
  for i, e in ipairs(list) do
    if e.phase == p and ns.Near(mapID, e.x, e.y, x, y) then return i, e end
  end
end

local function Refresh(p, mapID)
  if p == phase and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == mapID then
    ns.Provider:RefreshAllData()
  end
end

-- A sighting. For a node and phase the newest report wins, sighting or "not there".
local function Add(p, mapID, x, y, t, mine)
  mapID, x, y = Valid(mapID, x, y, t)
  if not mapID then return end
  if ns.Watch then ns.Watch(mapID, x, y, t, mine) end -- dev copy only
  ns.LearnShared(mapID, x, y) -- a location we don't have yet is kept, whatever the phase

  local gi, g = Find(gone[mapID], p, mapID, x, y)
  if g then
    if g.t >= t then return end -- found gone since
    table.remove(gone[mapID], gi)
  end

  local list = reports[mapID] or {}
  reports[mapID] = list
  local _, r = Find(list, p, mapID, x, y)
  if r then
    r.first = math.min(r.first or r.t, t)
    if t > r.t then r.x, r.y, r.t = x, y, t end
    r.mine = r.mine or mine
  else
    list[#list + 1] = { phase = p, x = x, y = y, t = t, first = t, mine = mine }
  end
  Refresh(p, mapID)
end

-- A "not there" (XM / XS): ends an older sighting of that node in that phase. Never teaches a location.
local function AddGone(p, mapID, x, y, t)
  mapID, x, y = Valid(mapID, x, y, t)
  if not mapID then return end
  local ri, r = Find(reports[mapID], p, mapID, x, y)
  if r then
    if r.t >= t then return end -- seen since
    table.remove(reports[mapID], ri)
    if ns.WatchGone then ns.WatchGone(mapID, r, t) end -- dev copy only
  end

  local list = gone[mapID] or {}
  gone[mapID] = list
  local _, g = Find(list, p, mapID, x, y)
  if g then
    if t > g.t then g.t = t end
  else
    list[#list + 1] = { phase = p, x = x, y = y, t = t }
  end
  Refresh(p, mapID)
end

-- Current-phase sightings for a map, for the data provider. With sharing off, only our own: they're kept
-- locally either way (and Mapzeroth reads them), but others' held from before must not show.
function ns.CrowdReports(mapID)
  local out = {}
  if not (phase and reports[mapID]) then return out end
  Prune(reports[mapID])
  local all = Enabled()
  for _, r in ipairs(reports[mapID]) do
    if r.phase == phase and (all or r.mine) then out[#out + 1] = r end
  end
  return out
end

-- Current-phase "not there"s for a map, for the data provider
function ns.CrowdGone(mapID)
  local out = {}
  if not (Enabled() and phase and gone[mapID]) then return out end
  Prune(gone[mapID])
  for _, g in ipairs(gone[mapID]) do
    if g.phase == phase then out[#out + 1] = g end
  end
  return out
end

-- Drop expired sightings and "not there"s on every map, and maps left empty (keeps the saved file small)
local function PruneAll()
  for _, all in ipairs({ allReports, allGone }) do
    for _, maps in pairs(all) do
      for mapID, list in pairs(maps) do
        Prune(list)
        if #list == 0 then maps[mapID] = nil end
      end
    end
  end
end

-- 0 = just seen, 1 = about to expire
function ns.CrowdAge(r)
  return math.min(1, math.max(0, (GetServerTime() - r.t) / TTL))
end

-- How long a sighting lasts, in minutes (tooltip text)
function ns.CrowdMinutes()
  return math.floor(TTL / 60)
end

---------------------------------------------------------------------------
-- Own sightings
---------------------------------------------------------------------------

local function Broadcast(mapID, x, y, t)
  Add(phase, mapID, x, y, t, true)
  Send(format("R:%s:%s:%s:%d:%d:%d:%d", VERSION, FactionTag(), phase, mapID,
    math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5), t))
end

-- Our own sighting: kept whether sharing is on or not (Send does nothing while it's off)
function ns.OnConfirmed(mapID, x, y, t)
  if phase then
    Broadcast(mapID, x, y, t)
  else
    waiting = { mapID = mapID, x = x, y = y, t = t }
  end
end

-- A node seen some way other than the racial: its minimap blip (Scan.lua, LeyLineTest hovers), which
-- only shows while the node is up in your phase. Skipped when the node already has a sighting in this
-- phase from anyone in the last gap seconds (default REPEAT_GAP), so passing the same blip doesn't flood.
local REPEAT_GAP = 5 * 60
function SLLCM_ReportSighting(mapID, x, y, gap)
  local now = GetServerTime()
  for _, r in ipairs(reports[mapID] or {}) do
    if r.phase == phase and now - r.t < (gap or REPEAT_GAP) and ns.Near(mapID, r.x, r.y, x, y) then return end
  end
  ns.OnConfirmed(mapID, x, y, now)
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

-- in an answer heard while ours waited, or a part of ours already sent: covered = { mapID, x, y, t, ... }. With t, a heard entry covers ours only if it's at least as recent, so a
-- newer sighting still goes out after an older answer for the same node. Without t (L), the place is enough.
local function Covered(covered, mapID, x, y, t)
  for i = 1, #covered, 4 do
    if covered[i] == mapID and ns.Near(mapID, covered[i + 1], covered[i + 2], x, y)
        and not (t and covered[i + 3] < t) then
      return true
    end
  end
end

local function Cover(covered, mapID, x, y, t)
  local n = #covered
  covered[n + 1], covered[n + 2], covered[n + 3], covered[n + 4] = mapID, x, y, t or 0
end

-- One S at a time, each built just before it goes: what another answer had by then is left out, so two
-- answerers starting together don't both send every part. Our own entries go on the covered list too.
local function SendReply(p)
  local covered = pending[p]
  if not covered then return end
  local entries = {}
  for mapID, list in pairs(reports) do
    Prune(list)
    for _, r in ipairs(list) do
      if #entries < MAX_PER_REPLY and r.phase == p and not Covered(covered, mapID, r.x, r.y, r.t) then
        entries[#entries + 1] = format("%d,%d,%d,%d", mapID,
          math.floor(r.x * 10000 + 0.5), math.floor(r.y * 10000 + 0.5), r.t)
        Cover(covered, mapID, r.x, r.y, r.t)
      end
    end
  end
  if #entries == 0 then
    if not replying[p] then Debug("answer for phase %s not sent: other answers covered it", p) end
    pending[p], replying[p] = nil, nil
    return
  end
  replying[p] = true
  Send(format("S:%s:%s:%s:%s", VERSION, FactionTag(), p, table.concat(entries, ";")))
  C_Timer.After(SEND_GAP, function() SendReply(p) end)
end

-- Our self-found locations that aren't in Data.lua and no L heard meanwhile had
local function SendFound()
  local covered = foundPending
  foundPending = nil
  local key, db = ns.Faction().key, ns.GetDB()
  local entries = {}
  for foundMap, list in pairs(db.found[key]) do
    for _, p in ipairs(list) do
      -- some spots record on the continent map: compare and send on the zone, as the answers we heard were
      local mapID, x, y = OnZoneMap(foundMap, p[1], p[2])
      local known = not mapID or Covered(covered, mapID, x, y)
      for _, d in ipairs(mapID and SLLCM_Data[key][mapID] or {}) do
        known = known or ns.Near(mapID, d[1], d[2], x, y)
      end
      if not known then
        entries[#entries + 1] = format("%d,%d,%d", mapID,
          math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5))
      end
    end
  end
  Debug("answering F with %d location(s)", #entries)
  for i = 1, #entries, MAX_FOUND_PER_REPLY do
    Send(format("L:%s:%s:%s", VERSION, FactionTag(),
      table.concat(entries, ";", i, math.min(i + MAX_FOUND_PER_REPLY - 1, #entries))))
  end
end

local function OnFoundMessage(kind, list, sender)
  if kind == "F" then
    if foundAnswered then return end
    foundAnswered, foundPending = true, {}
    C_Timer.After(4 + math.random() * 8, SendFound)
  elseif kind == "L" and list then
    local learned = 0
    for entry in list:gmatch("[^;]+") do
      local mapID, x, y = strsplit(",", entry)
      mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
      if mapID and x and y and x >= 0 and x <= 10000 and y >= 0 and y <= 10000 then
        mapID, x, y = OnZoneMap(mapID, x / 10000, y / 10000)
        if mapID then
          if ns.LearnShared(mapID, x, y) then learned = learned + 1 end
          if foundPending then
            Cover(foundPending, mapID, x, y)
          end
        end
      end
    end
    if foundAsked then ns.Print("found locations from %s: %d new", sender, learned) end
    if learned > 0 and WorldMapFrame:IsShown() then ns.Provider:RefreshAllData() end
  end
end

local function OnMessage(text, sender)
  local kind, v, fac, p, rest = strsplit(":", text, 5)
  Debug("<< %s: %s%s", sender, text, p and p == phase and " |cff00ff00<< your phase|r" or "")
  if v ~= VERSION or fac ~= FactionTag() then return end
  if kind == "F" or kind == "L" then return OnFoundMessage(kind, p, sender) end -- no phase field
  if not (p and p:match("^%d+$")) then return end

  if (kind == "R" or kind == "XM") and rest then
    local mapID, x, y, t = strsplit(":", rest)
    mapID, x, y, t = tonumber(mapID), tonumber(x), tonumber(y), tonumber(t)
    if mapID and x and y and t then (kind == "R" and Add or AddGone)(p, mapID, x / 10000, y / 10000, t) end

  elseif kind == "Q" then
    -- we'll hear the answers to it, so we needn't ask about this phase ourselves
    asked[p], queried[p] = true, GetServerTime()
    -- Whoever made a sighting for the phase answers first (1-8 s); the rest wait 9-15 s and then send only
    -- the nodes no answer heard meanwhile had, so a first answer holding only some of them doesn't hide the rest.
    -- Nobody changes phase close enough to a node to need it sooner.
    if replying[p] then
      wipe(pending[p]) -- a new asker missed the parts already sent: the rest of ours starts over
      return
    end
    if pending[p] then return end
    local have, mine = false, false
    for _, list in pairs(reports) do
      for _, r in ipairs(list) do
        if r.phase == p then have, mine = true, mine or r.mine end
      end
    end
    if not have then return end
    pending[p] = {}
    C_Timer.After(mine and 1 + math.random() * 7 or 9 + math.random() * 6, function() SendReply(p) end)

  elseif (kind == "S" or kind == "XS") and rest then
    -- an XS isn't an answer to the sightings part of a Q: it doesn't cover anything of ours
    local covered = kind == "S" and pending[p]
    for entry in rest:gmatch("[^;]+") do
      local mapID, x, y, t = strsplit(",", entry)
      mapID, x, y, t = tonumber(mapID), tonumber(x), tonumber(y), tonumber(t)
      if mapID and x and y and t then
        (kind == "S" and Add or AddGone)(p, mapID, x / 10000, y / 10000, t)
        if covered then
          local m, cx, cy = Valid(mapID, x / 10000, y / 10000, t)
          if m then Cover(covered, m, cx, cy, t) end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Phase. Creature GUIDs are Creature-0-server-instance-zoneUID-npcID-spawnUID; zoneUID is the shard,
-- the same for everyone in it. The first reading is used straight away; once a second kind of NPC
-- agrees, replacing it takes CONFIRMATIONS kinds of NPC agreeing on a new one.
---------------------------------------------------------------------------

local function SetPhase(p, npcID)
  local old = phase
  phase, phaseMap, tentativeNpc = p, PlayerMap(), npcID
  wipe(candidates)
  if p == old then return end
  Debug("phase %s -> %s", tostring(old), p)
  if waiting and waiting.mapID == phaseMap then
    Broadcast(waiting.mapID, waiting.x, waiting.y, waiting.t)
  end
  waiting = nil
  Query()
  if WorldMapFrame:IsShown() then ns.Provider:RefreshAllData() end
end

local function ReadUnit(unit)
  local ok, guid = pcall(UnitGUID, unit)
  guid = ok and Clean(guid)
  if type(guid) ~= "string" then return end
  local kind, _, _, _, zone, npc = strsplit("-", guid)
  if kind ~= "Creature" and kind ~= "Vehicle" then return end
  zone, npc = tonumber(zone), tonumber(npc)
  if not zone or zone <= 0 or not npc then return end
  local p = tostring(zone)

  if p == phase then
    if tentativeNpc and npc ~= tentativeNpc then tentativeNpc = nil end -- another kind agrees
    wipe(candidates)
  elseif not phase or tentativeNpc then
    SetPhase(p, npc)
  else
    local c = candidates[p] or { n = 0 }
    candidates[p] = c
    if not c[npc] then c[npc], c.n = true, c.n + 1 end
    if c.n >= CONFIRMATIONS then SetPhase(p) end
  end
end

local function ScanNameplates()
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if Clean(UnitExists(unit)) then ReadUnit(unit) end
  end
end

---------------------------------------------------------------------------
-- Channel
---------------------------------------------------------------------------

local function HideFromChat()
  local name = ChannelName()
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local frame = _G["ChatFrame" .. i]
    if frame and frame.RemoveChannel then
      pcall(frame.RemoveChannel, frame, name)
    elseif frame and ChatFrame_RemoveChannel then
      pcall(ChatFrame_RemoveChannel, frame, name)
    end
  end
end

-- channel names shown in any chat window, lowercased
local function ShownChannels()
  local shown = {}
  if not GetChatWindowChannels then return shown end
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local list = { GetChatWindowChannels(i) } -- name, zone for each channel
    for j = 1, #list, 2 do
      if type(list[j]) == "string" then shown[list[j]:lower()] = true end
    end
  end
  return shown
end

-- the numbers of the channels people chat in, lowest first: the game's own (General, Trade, Services...)
-- and custom ones shown in a chat window. A custom channel shown nowhere is an addon's, as ours is: we
-- never move one, so an addon doing the same as us can't swap back and forth with ours.
local function ChatChannelNumbers()
  local out = {}
  if not (GetNumDisplayChannels and GetChannelDisplayInfo) then return out end
  local shown = ShownChannels()
  for i = 1, GetNumDisplayChannels() or 0 do
    local name, header, _, number, _, _, category = GetChannelDisplayInfo(i)
    local chat = category == "CHANNEL_CATEGORY_WORLD"
      or (category == "CHANNEL_CATEGORY_CUSTOM" and type(name) == "string" and shown[name:lower()])
    if not header and type(number) == "number" and number > 0 and chat then
      out[#out + 1] = number
    end
  end
  table.sort(out)
  return out
end

-- Move our channel past every chat channel numbered above it, one swap at a time, so General, Trade, a
-- player's own channels and the rest keep /1, /2, /3. A new channel takes the lowest free number, so
-- joining before they come in (a slow login, a rejoin racing them after a loading screen) takes /1. Each
-- swap moves ours up and a chat channel down, so it stops; the budget is for an addon that rearranges
-- channels itself, or one that leaves its own channel showing in chat.
local function KeepChannelLast()
  local swap = C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex
  local ours = ChannelIndex()
  if not swap or not ours then return end
  for _, n in ipairs(ChatChannelNumbers()) do
    if n > ours then
      if swapsLeft <= 0 or not pcall(swap, ours, n) then return end
      swapsLeft = swapsLeft - 1
      ours = n
    end
  end
end

local function Join()
  if not Enabled() or Clean(IsInInstance()) then return end
  -- still on it from before a /reload: start the clock now, or Query() never asks this session
  if ChannelIndex() then joinedAt = joinedAt or GetTime() return end
  reorderUntil, swapsLeft = GetTime() + REORDER_SECONDS, MAX_SWAPS
  pcall(JoinTemporaryChannel, ChannelName())
  joinedAt = GetTime()
  -- the chat frames pick the channel up a moment after joining
  C_Timer.After(1, HideFromChat)
  C_Timer.After(5, HideFromChat)
  C_Timer.After(2, Query)
end

-- At login, wait for the game's own channels (General, Trade...) to come in first: a new channel takes
-- the lowest free number, and taking /1 would send a player's "/1 hello" into ours.
local function JoinWhenSettled()
  local start, changedAt, last = GetTime(), GetTime(), -1
  local ticker
  ticker = C_Timer.NewTicker(1, function()
    local now, count = GetTime(), select("#", GetChannelList())
    if count ~= last then last, changedAt = count, now end
    -- quiet for a moment once the first channel is in: an empty list for a few seconds is the login
    if (count > 0 and now - changedAt >= 3) or now - start >= 30 then
      ticker:Cancel()
      swapsLeft = MAX_SWAPS
      KeepChannelLast() -- still on it from before a /reload, perhaps as /1
      Join()
      -- rejoin if kicked, /left by the player or lost to a client hiccup
      C_Timer.NewTicker(60, Join)
    end
  end)
end

function ns.SetCrowdEnabled(on)
  if on then
    Join()
  elseif ChannelIndex() then
    LeaveChannelByName(ChannelName())
  end
  ns.Provider:RefreshAllData()
end

function ns.ShareCommand(arg)
  if arg == "debug" then
    debug = not debug
    ns.GetDB().shareDebug = debug
    ns.Print("share debug %s", debug and "on" or "off")
    return
  elseif arg == "test clear" then
    local db = ns.GetDB()
    db.shared[ns.Faction().key] = {}
    wipe(reports)
    wipe(gone)
    ns.Provider:RefreshAllData()
    ns.Print("test: shared locations and all sightings cleared")
    return
  elseif arg == "test send" or arg == "test receive" or arg == "test new" then
    -- a fake sighting at the known node nearest you: "send" goes through our own path without
    -- touching the channel, "receive" through the message parser as if another player sent it.
    -- "new" is a receive at your own position, so an unknown spot is learned as a shared location.
    local mapID = PlayerMap()
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if pos and arg == "test new" then
      x, y = pos.x, pos.y
    elseif pos then
      x, y = ns.NearestKnown(mapID, pos.x, pos.y)
    end
    if not phase then
      ns.Print("test: phase unknown, mouse over an NPC first")
    elseif not x then
      ns.Print("test: no known node on this map")
    else
      local msg = format("R:%s:%s:%s:%d:%d:%d:%d", VERSION, FactionTag(), phase, mapID,
        math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5), GetServerTime())
      if arg == "test send" then
        Add(phase, mapID, x, y, GetServerTime())
        ns.Print("test send (not sent to the channel): %s", msg)
      else
        OnMessage(msg, "Tester")
        ns.Print("test receive: %s", msg)
      end
    end
    return
  elseif arg == "found" then
    -- ask everyone on the channel for their self-found locations that aren't in Data.lua
    if not (Enabled() and ChannelIndex()) then
      ns.Print("found: sharing is off or the channel isn't joined")
    elseif ns.GetDB().selfOnly then
      ns.Print("found: \"show only self-found\" is on, so answers wouldn't be learned")
    else
      foundAsked = true
      Send(format("F:%s:%s", VERSION, FactionTag()))
      ns.Print("found: asked; answers come in over the next 15 s or so")
    end
    return
  elseif arg == "reset" then
    -- back to a first-run state: sharing off, and the popup asks again on the next /reload
    local db = ns.GetDB()
    db.crowdAsked, db.crowd = nil, false
    ns.SetCrowdEnabled(false)
    ns.Print("sharing reset: off, and you'll be asked again after /reload")
    return
  end
  local count, here = 0, 0
  for _, list in pairs(reports) do
    Prune(list)
    for _, r in ipairs(list) do
      count = count + 1
      if r.phase == phase then here = here + 1 end
    end
  end
  ns.Print("sharing %s, channel %s, phase %s%s, %d sighting(s) held, %d in this phase, %d queued",
    Enabled() and "on" or "off", tostring(ChannelIndex() or "not joined"), tostring(phase or "unknown"),
    tentativeNpc and " (tentative)" or "", count, here, #queue)
  ns.Print("/sllcm share debug - print messages sent and received; /sllcm share found - ask others for self-found locations Data.lua lacks; /sllcm share reset - ask again;/sllcm share test send | receive | new | clear - fake sightings (see Comm.lua)")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("CHANNEL_UI_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then
    local prefix, text, _, sender = ...
    prefix, text, sender = Clean(prefix), Clean(text), Clean(sender)
    if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" or not Enabled() then return end
    sender = Ambiguate(sender, "none")
    -- the server echoes our own back
    if not me[sender] then OnMessage(text, sender) end
  elseif event == "CHANNEL_UI_UPDATE" then -- a channel joined or left (our own swaps fire it too)
    if reorderUntil and GetTime() < reorderUntil then KeepChannelLast() end
  elseif event == "PLAYER_LOGIN" then
    -- sightings survive /reload and relogs; Prune drops them as they age out
    local db = ns.GetDB()
    -- debug output remembers its setting; on by default in the dev copy (loaded as "...-Dev")
    if db.shareDebug == nil then db.shareDebug = ADDON:find("%-Dev$") ~= nil end
    debug = db.shareDebug
    allReports = type(db.crowdReports) == "table" and db.crowdReports or {}
    for k in pairs(allReports) do
      if k ~= "A" and k ~= "H" then allReports[k] = nil end -- 0.3.0 kept one list for both factions
    end
    db.crowdReports = allReports
    allReports[FactionTag()] = allReports[FactionTag()] or {}
    reports = allReports[FactionTag()]
    allGone = type(db.crowdGone) == "table" and db.crowdGone or {}
    db.crowdGone = allGone
    allGone[FactionTag()] = allGone[FactionTag()] or {}
    gone = allGone[FactionTag()]
    local allQueried = type(db.crowdQueried) == "table" and db.crowdQueried or {}
    db.crowdQueried = allQueried
    allQueried[FactionTag()] = allQueried[FactionTag()] or {}
    queried = allQueried[FactionTag()]
    for _, byPhase in pairs(allQueried) do
      for p, t in pairs(byPhase) do
        if GetServerTime() - t > QUERY_MEMORY then byPhase[p] = nil end
      end
    end
    PruneAll()
    -- on Forever, UnitName gives first name and surname apart, and senders show as "First Surname"
    local name, surname = UnitName("player")
    me[name] = true
    if surname and surname ~= "" then me[name .. " " .. surname] = true end
    JoinWhenSettled()
    C_Timer.NewTicker(SCAN_SECONDS, ScanNameplates)
  elseif event == "PLAYER_LOGOUT" then -- also /reload
    PruneAll()
    ns.GetDB().crowdPhase = phase and { phase = phase, mapID = phaseMap, at = GetServerTime() } or nil
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    -- these also fire on /reload and login without moving: only a real zone change resets the phase
    if PlayerMap() ~= phaseMap then
      phase, phaseMap, tentativeNpc, waiting = nil, nil, nil, nil
      wipe(candidates)
    end
    -- after a /reload or quick relog in the same zone, pick the saved phase back up, tentatively: the
    -- first NPC that disagrees replaces it
    local db, saved = ns.GetDB(), nil
    saved, db.crowdPhase = db.crowdPhase, nil
    if not phase and type(saved) == "table" and saved.mapID == PlayerMap()
        and GetServerTime() - (saved.at or 0) <= RESTORE_SECONDS then
      phase, phaseMap, tentativeNpc = saved.phase, saved.mapID, -1
      if WorldMapFrame:IsShown() then ns.Provider:RefreshAllData() end
    end
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    ReadUnit((...))
  elseif event == "PLAYER_TARGET_CHANGED" then
    ReadUnit("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    ReadUnit("mouseover")
  end
end)

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- colours drift while the map is open: about 30 steps over a sighting's life, at most every 15 s
C_Timer.NewTicker(math.max(1, math.min(15, TTL / 30)), function()
  if WorldMapFrame:IsShown() and phase and reports[WorldMapFrame:GetMapID()] then
    ns.Provider:RefreshAllData()
  end
end)
