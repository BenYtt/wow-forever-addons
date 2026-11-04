local _, FLT = ...

-- Recipe sharing for the "All recipes" browser.
--   * GUILD (prefix OFAPR, unchanged since 5.6): guild members send the recipe spell IDs they know
--     (per profession); shown with a green check. OneForAllDB.guildRecipes[guild][member] = { t, [prof] = {spellID=true} }
--   * other OneForAll users (6.1.0, prefix OFAPR2, hidden channel OFAShare2): no recipe lists any more, only
--     searches. Opening a recipe asks the channel "who knows it?" in up to four rounds; in each round a share p of
--     the players that know it answers by whisper (picked from a hash of the search ID and their name, so nobody
--     answers twice; p grows from round to round, estimated from the answers so far, until about 8 were found). Answers are kept per recipe in OneForAllDB.recipeHits[prof][spell][player] = time.
--     A short status (zone, level, class) is sent now and then, so known players show as online (blue check);
--     its interval grows with the number of players, so every client receives at most ~3 of them per second.
-- Messages on OFAPR2 (fields split by tabs):
--   Z zone inst level class mapID session   status (channel)
--   S qid prof spell p map                   search (channel, spell in base36, p = share in millionths, map = the
--                                            searcher's map: players there answer in any case, about 8 at most)
--   A qid prof spell zone inst level class mapID   answer (whisper to the searcher)
--   X qid                                    search done, pending answers are dropped (channel, only from the searcher)
-- Plan and reviews: todo_assets/plan_rezeptkanal.md (workshop repo). /ofa channel shows the state.

local PREFIX = "OFAPR"        -- guild
local PREFIX2 = "OFAPR2"      -- channel and answers (6.1.0)
local CHANNEL = "OFAShare2"
local OLD_CHANNEL = "OFAShare" -- 5.6-6.0 channel, left on login
local GUILD_GAP = 0.35        -- seconds between guild messages
local CHANNEL_GAP = 1.2       -- channel messages are throttled harder by the server
local WHISPER_GAP = 0.5
local MAX_LEN = 240           -- payload size per message
local JOIN_RETRY = 60         -- retry the channel join every minute while it failed
-- status
local STATUS_MIN = 10 * 60    -- status interval with few players
local STATUS_RATE = 3         -- statuses per second a client may receive at most (interval grows with the players)
-- search
local MAX_ROUNDS = 4
local GROW = 10               -- a round without any answer asks 10 times as many players
local ROUND_WAIT = 3          -- seconds to collect the answers of a round
local TARGET = 8              -- stop at this many players
local MIN_HITS = 3            -- asking everyone only when fewer were found
local SEARCH_GAP = 5          -- seconds between two own searches
local SEARCH_MAX = 30         -- own searches per 10 minutes
local AGAIN_HIT = 15 * 60     -- search the same recipe again automatically after ...
local AGAIN_MISS = 2 * 60     -- ... (no answer)
local AGAIN_MANUAL = 30       -- "Search again" button
local ANSWER_MAX = 10         -- answers per minute this client sends at most ...
local ANSWER_MAX_ALL = 30     -- ... and when everyone is asked (few players know the recipe, every answer counts)
local ANSWER_DELAY = 2        -- answers wait 0.2..2 s (an "enough" message can still cancel them)
-- cache
local HIT_EXPIRE = 14 * 24 * 3600
local PER_RECIPE = 20
local MAX_HITS = 6000
-- queues
local QUEUE_MAX = { CHANNEL = 8, WHISPER = 12 }
-- load: above this many searches per second on the channel, every client starts only a matching share of its
-- own searches (the others show "busy"), so the channel stays near this rate however many players search
local SEARCH_LOAD = 8
local AGAIN_LIMITED = 30

local scheduleStatus -- forward declaration (defined further down)

local function guildName()
  if not (IsInGuild and IsInGuild()) then return nil end
  return GetGuildInfo and GetGuildInfo("player")
end

local function shortName(n)
  if not n then return nil end
  if Ambiguate then return Ambiguate(n, "short") end
  return (n:gsub("%-.*$", ""))
end

local function now() return time and time() or 0 end
local function clock() return GetTime and GetTime() or 0 end

-- Identity of the current character. On Forever several characters can share
-- the first name ("Smoergi Deadheart", "Smoergi Ironfist"), and UnitName may
-- only return the first name. The full name is taken from the guild roster
-- (matched by GUID) or from the echo of our own status, and cached per character.
local function firstName()
  local n = UnitName and UnitName("player")
  return n and shortName(n) or nil
end
local function myName()
  if type(OneForAllCharDB) == "table" and OneForAllCharDB.fullName then return OneForAllCharDB.fullName end
  return nil
end
local function isMe(name)
  if not name then return false end
  local n = shortName(name):lower()
  local full = myName()
  if full then return n == full:lower() end
  -- full name not known yet: only an exact match with UnitName counts
  local f = firstName()
  return f ~= nil and n == f:lower()
end

local function shareEnabled()
  return not (type(OneForAllDB) == "table" and OneForAllDB.recipeShareChannel == false)
end

local function guildDB(create)
  local g = guildName()
  if not g or type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.guildRecipes = OneForAllDB.guildRecipes or {}
  local t = OneForAllDB.guildRecipes[g]
  if not t and create then t = {}; OneForAllDB.guildRecipes[g] = t end
  return t
end

-- base36 encoding keeps the messages short
local DIG = "0123456789abcdefghijklmnopqrstuvwxyz"
local function enc(n)
  local s = ""
  repeat local d = n % 36; s = DIG:sub(d + 1, d + 1) .. s; n = math.floor(n / 36) until n == 0
  return s
end
local function dec(s) return tonumber(s, 36) end

-- recipe spell IDs per profession (lazy, to check incoming IDs)
local spellSets = {}
local function validRecipe(prof, spell)
  local list = prof and spell and FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof]
  if not list then return false end
  local set = spellSets[prof]
  if not set then
    set = {}
    for _, r in ipairs(list) do if r.s then set[r.s] = true end end
    spellSets[prof] = set
  end
  return set[spell] or false
end

local function ownKnown(prof, spell)
  local p = type(OneForAllCharDB) == "table" and type(OneForAllCharDB.professions) == "table" and OneForAllCharDB.professions[prof]
  return p and type(p.known) == "table" and p.known[spell] and true or false
end

-- counters for /ofa channel
local stats = { recv = 0, recvMin = 0, recvPeak = 0, dropped = 0, searches = 0, answers = 0, hits = 0, minute = 0,
  qPeak = 0, sMin = 0, sLast = 0, zMin = 0, zLast = 0, s10 = 0, s10Last = 0, s10At = 0, dQueue = 0, dRate = 0, dBudget = 0, limited = 0 }
local function rollMinute()
  local b = math.floor(clock() / 10)
  if b ~= stats.s10At then
    stats.s10Last = (b == stats.s10At + 1) and stats.s10 or 0
    stats.s10At, stats.s10 = b, 0
  end
  local m = math.floor(clock() / 60)
  if m ~= stats.minute then
    if stats.recvMin > stats.recvPeak then stats.recvPeak = stats.recvMin end
    -- searches heard in the last full minute (0 when a minute was skipped)
    stats.sLast = (m == stats.minute + 1) and stats.sMin or 0
    stats.zLast = (m == stats.minute + 1) and stats.zMin or 0
    stats.minute, stats.recvMin, stats.sMin, stats.zMin = m, 0, 0, 0
  end
end
local function counted()
  rollMinute()
  stats.recv = stats.recv + 1
  stats.recvMin = stats.recvMin + 1
end

-- ---------------------------------------------------------------------------
-- Guild roster (online state, members who left)
-- ---------------------------------------------------------------------------
local roster, rosterCount = {}, 0
local selfIdentified -- forward: called once the own full name is known
local function readRoster()
  if not (GetNumGuildMembers and GetGuildRosterInfo) then return end
  local n = GetNumGuildMembers() or 0
  if n == 0 then return end
  wipe(roster); rosterCount = 0
  for i = 1, n do
    local name, _, _, level, _, zone, _, _, online, _, classFile, _, _, _, _, _, guid = GetGuildRosterInfo(i)
    if name then
      local short = shortName(name)
      -- find the own full name: by GUID, else online + same first name, level and class
      local mine = guid and UnitGUID and guid == UnitGUID("player")
      if not mine and not guid and online then
        local f = firstName()
        local myClass = UnitClass and select(2, UnitClass("player")) -- not "a, b = f and f()": that keeps one value
        mine = f and (short == f or short:sub(1, #f + 1) == f .. " ") and level == (UnitLevel and UnitLevel("player")) and classFile == myClass
      end
      if mine and type(OneForAllCharDB) == "table" and OneForAllCharDB.fullName ~= short then
        OneForAllCharDB.fullName = short
        selfIdentified()
      end
      roster[short:lower()] = {online = online and true or false, zone = zone, level = level, class = classFile}
      rosterCount = rosterCount + 1
    end
  end
  -- drop the old first-name-only entry of this character (older versions)
  local f, db = firstName(), guildDB(false)
  if f and db and db[f] and rosterCount > 0 and not roster[f:lower()] then db[f] = nil end
end

local function rosterInfo(name)
  if not name then return nil end
  return roster[shortName(name):lower()]
end

local function sortKnowers(out)
  table.sort(out, function(a, b) if a[2] ~= b[2] then return a[2] end return a[1] < b[1] end)
  return out
end

local lastRosterRequest = -100
function FLT.RequestGuildRoster()
  if not guildName() then return end
  local t = clock()
  if t - lastRosterRequest < 10 then return end
  lastRosterRequest = t
  if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
end

-- Guild members that know a recipe (without the player): list of {name, online, zone}.
function FLT.GetGuildRecipeKnowers(prof, spell)
  local db = guildDB(false)
  if not db then return nil end
  local out
  for member, data in pairs(db) do
    if not isMe(member) and type(data) == "table" and data[prof] and data[prof][spell] then
      if rosterCount == 0 or rosterInfo(member) ~= nil then
        out = out or {}
        local r = rosterInfo(member)
        out[#out + 1] = {member, r and r.online or false, r and r.online and r.zone or nil, nil, level = r and r.level, class = r and r.class}
      end
    end
  end
  return out and sortKnowers(out)
end

-- ---------------------------------------------------------------------------
-- Status of other OneForAll users and the search results
-- ---------------------------------------------------------------------------
-- [name] = {zone, inst, level, class, t}. Kept in OneForAllDB.shareStatus, so after a /reload
-- players heard within the online window still count as online.
local status = {}
local statusEvery, onlineWindow = STATUS_MIN, STATUS_MIN + 180

-- interval of the own status and the online window, from the number of players heard lately
local function updateIntervals()
  local n, t = 0, now()
  for _, st in pairs(status) do if (t - (st.t or 0)) < onlineWindow then n = n + 1 end end
  statusEvery = math.max(STATUS_MIN, (n + 1) / STATUS_RATE)
  onlineWindow = statusEvery * 1.25 + 180
  return n
end

local function hitsDB()
  if type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.recipeHits = OneForAllDB.recipeHits or {}
  return OneForAllDB.recipeHits
end

local hitCount = 0
-- keep MAX_HITS: drop the oldest entries of recipes many players know first (rare recipes keep theirs)
local function trimHits(db, keep)
  for limit = PER_RECIPE - 1, 1, -1 do
    if hitCount <= keep then return end
    for _, spells in pairs(db) do
      for _, players in pairs(spells) do
        local n, oldest, oldT = 0, nil, nil
        for p, t in pairs(players) do n = n + 1; if not oldT or t < oldT then oldest, oldT = p, t end end
        while n > limit and hitCount > keep do
          players[oldest] = nil; n = n - 1; hitCount = hitCount - 1
          oldest, oldT = nil, nil
          for p, t in pairs(players) do if not oldT or t < oldT then oldest, oldT = p, t end end
        end
      end
    end
  end
end

local function addHit(prof, spell, who, t)
  local db = hitsDB()
  if not db then return end
  db[prof] = db[prof] or {}
  local players = db[prof][spell]
  if not players then players = {}; db[prof][spell] = players end
  if not players[who] then
    local n, oldest, oldT = 0, nil, nil
    for p, pt in pairs(players) do n = n + 1; if not oldT or pt < oldT then oldest, oldT = p, pt end end
    if n >= PER_RECIPE then players[oldest] = nil else hitCount = hitCount + 1 end
  end
  players[who] = t
  if hitCount > MAX_HITS then trimHits(db, math.floor(MAX_HITS * 0.9)) end
end

-- once per login: drop old entries, count, take over the recipe lists of 6.0 (OneForAllDB.playerRecipes)
local function pruneHits()
  local db = hitsDB()
  if not db then return end
  local t = now()
  hitCount = 0
  for prof, spells in pairs(db) do
    for spell, players in pairs(spells) do
      for p, pt in pairs(players) do
        if type(pt) ~= "number" or (t - pt) > HIT_EXPIRE then players[p] = nil else hitCount = hitCount + 1 end
      end
      if not next(players) then spells[spell] = nil end
    end
    if not next(spells) then db[prof] = nil end
  end
  local old = OneForAllDB.playerRecipes
  if type(old) == "table" then
    OneForAllDB.playerRecipes = nil
    for player, data in pairs(old) do
      if type(data) == "table" and type(data.t) == "number" and (t - data.t) < HIT_EXPIRE then
        for prof, set in pairs(data) do
          if type(set) == "table" and FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof] then
            for spell in pairs(set) do
              if hitCount >= MAX_HITS then break end
              local players = db[prof] and db[prof][spell]
              local n = 0
              if players then for _ in pairs(players) do n = n + 1 end end
              if n < PER_RECIPE and hitCount < MAX_HITS then addHit(prof, spell, player, data.t) end
            end
          end
        end
      end
    end
  end
end

-- Other OneForAll users (not in the guild) that know a recipe: list of
-- {name, online, zone, instanceType, level=, class=, seen=}. Online = heard from within the online window.
function FLT.GetOtherRecipeKnowers(prof, spell)
  if not shareEnabled() then return nil end
  local db = hitsDB()
  local players = db and db[prof] and db[prof][spell]
  if not players then return nil end
  local gdb = guildDB(false) or {}
  local out, t = nil, now()
  for player, ht in pairs(players) do
    if not isMe(player) and rosterInfo(player) == nil and not gdb[player] then
      out = out or {}
      local st = status[player]
      local online = st and (t - st.t) < onlineWindow or false
      out[#out + 1] = {player, online, online and st.zone or nil, online and st.inst or nil,
        level = st and st.level, class = st and st.class, seen = math.max(ht, st and st.t or 0)}
    end
  end
  if not out then return nil end
  -- online first, then the ones in the own zone (the details show 8), then by name
  local here = (GetRealZoneText and GetRealZoneText()) or nil
  table.sort(out, function(a, b)
    if a[2] ~= b[2] then return a[2] end
    local za, zb = here ~= nil and a[3] == here, here ~= nil and b[3] == here
    if za ~= zb then return za end
    return a[1] < b[1]
  end)
  return out
end

local function refreshBrowser()
  if FLT.RefreshRecipeBrowser then FLT.RefreshRecipeBrowser() end
end

-- ---------------------------------------------------------------------------
-- Hidden channel
-- ---------------------------------------------------------------------------
local function channelID(name)
  if not GetChannelName then return nil end
  local id = GetChannelName(name or CHANNEL)
  if id and id > 0 then return id end
  return nil
end

local function hideChannelFromChat()
  if not ChatFrame_RemoveChannel then return end
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf then pcall(ChatFrame_RemoveChannel, cf, CHANNEL) end
  end
end

-- Move our channel behind all others, so /1 stays General (it may have been joined first).
local function moveChannelToEnd()
  local id = channelID()
  local swap = C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex
  if not (id and swap and GetChannelList) then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local last = 0
  local list = { GetChannelList() }
  for _, v in ipairs(list) do if type(v) == "number" and v > last then last = v end end -- id, name(, disabled) ...
  for i = id, last - 1 do if not pcall(swap, i, i + 1) then break end end
end

local onChannelReady -- forward (defined with the sending code)
local joinTries, joinTimer = 0, false
local function joinChannel()
  if not shareEnabled() then return end
  -- the channel of 6.0 and older carries full recipe lists: leave it
  if channelID(OLD_CHANNEL) and LeaveChannelByName then pcall(LeaveChannelByName, OLD_CHANNEL) end
  if channelID() then hideChannelFromChat(); onChannelReady(); return end
  if JoinTemporaryChannel then pcall(JoinTemporaryChannel, CHANNEL)
  elseif JoinChannelByName then pcall(JoinChannelByName, CHANNEL) end
  joinTries = joinTries + 1
  if not (C_Timer and C_Timer.After) then return end
  -- the join takes a moment; look again, and retry every minute while it failed
  C_Timer.After(3, function()
    if channelID() then hideChannelFromChat(); onChannelReady()
    elseif not joinTimer and shareEnabled() then
      joinTimer = true
      C_Timer.After(JOIN_RETRY, function() joinTimer = false; joinChannel() end)
    end
  end)
end

local channelReady = false -- set once the channel is there (onChannelReady)
local joinedAt = 0
local function leaveChannel()
  channelReady = false
  if channelID() and LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL) end
end

-- Hide join/leave notices of the share channels.
if ChatFrame_AddMessageEventFilter then
  local function ours(s)
    if type(s) ~= "string" then return false end
    s = s:lower()
    return s:find(OLD_CHANNEL:lower(), 1, true) ~= nil -- also matches OFAShare2
  end
  local function filter(_, _, _, _, _, chanString, _, _, _, _, chanName)
    return ours(chanName) or ours(chanString)
  end
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", filter)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", filter)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filter)
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------
-- queues per way: GUILD, CHANNEL and WHISPER; items { msg, target, tries, prefix }, read with a head index
local queues = { GUILD = {h = 1, t = 0}, CHANNEL = {h = 1, t = 0}, WHISPER = {h = 1, t = 0} }
local sending = { GUILD = false, CHANNEL = false, WHISPER = false }
local GAP = { GUILD = GUILD_GAP, CHANNEL = CHANNEL_GAP, WHISPER = WHISPER_GAP }
local function qlen(q) return q.t - q.h + 1 end

-- true when the game took the message; nil/true/0 = sent, false or another code = throttled or refused
local function accepted(ok, res)
  if not ok then return false end
  return res == nil or res == true or res == 0
end

-- item.onSent / item.onFail: called when the game took the message / gave up on it; item.cancelled: dropped unsent
local function pump(dist)
  local q = queues[dist]
  if q.h > q.t then q.h, q.t = 1, 0; sending[dist] = false; return end
  local item = q[q.h]; q[q.h] = nil; q.h = q.h + 1
  item.queued = false
  local gap = GAP[dist]
  local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
  if item.cancelled then
    gap = 0
  elseif send then
    local ok, res
    if dist == "GUILD" then
      if guildName() then ok, res = pcall(send, PREFIX, item[1], "GUILD") else ok, res = false, nil end
    elseif dist == "WHISPER" then
      if shareEnabled() then ok, res = pcall(send, PREFIX2, item[1], "WHISPER", item[2]) else ok, res = false, nil end
    else
      local id = channelID()
      if id and shareEnabled() then ok, res = pcall(send, PREFIX2, item[1], "CHANNEL", id) else ok, res = false, nil end
    end
    if accepted(ok, res) then
      if item.onSent then item.onSent() end
    elseif ok and (item[3] or 0) < 3 then
      -- throttled: try the same message again a little later (3 tries)
      item[3] = (item[3] or 0) + 1
      q.h = q.h - 1; q[q.h] = item; item.queued = true
      gap = gap * 4
    else
      if item.onFail then item.onFail() end
    end
  end
  if gap == 0 then pump(dist)
  elseif C_Timer and C_Timer.After then C_Timer.After(gap, function() pump(dist) end) else pump(dist) end
end

-- returns the queued item, or nil when the queue is full (the message is dropped); onSent / onFail see pump
local function send(dist, msg, target, onSent, onFail)
  local q = queues[dist]
  if QUEUE_MAX[dist] and qlen(q) >= QUEUE_MAX[dist] then stats.dropped = stats.dropped + 1; stats.dQueue = stats.dQueue + 1; return nil end
  local item = { msg, target, queued = true, onSent = onSent, onFail = onFail }
  q.t = q.t + 1; q[q.t] = item
  if dist ~= "GUILD" and qlen(q) > stats.qPeak then stats.qPeak = qlen(q) end
  if not sending[dist] then sending[dist] = true; pump(dist) end
  return item
end

-- Store own known recipes in the guild table (for alts) and return them.
local function ownRecipes()
  local out = {}
  if type(OneForAllCharDB) ~= "table" or type(OneForAllCharDB.professions) ~= "table" then return out end
  for prof, p in pairs(OneForAllCharDB.professions) do
    if FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof] and type(p.known) == "table" and next(p.known) then
      out[prof] = p.known
    end
  end
  local db = guildDB(true)
  local me = myName()
  if db and me then
    -- older versions stored own recipes under the first name only
    local f = firstName()
    if f and f ~= me and db[f] and db[f].own then db[f] = nil end
    local rec = {t = now(), own = true}
    for prof, known in pairs(out) do local c = {}; for s in pairs(known) do c[s] = true end; rec[prof] = c end
    db[me] = rec
  end
  return out
end

-- the own known recipes as one string (sorted spell IDs per profession), so every change is noticed
-- (the plain number missed a swap of recipes; GPT review 03.11.). Only built after a profession scan.
local function countKnown()
  local parts = {}
  if type(OneForAllCharDB) == "table" and type(OneForAllCharDB.professions) == "table" then
    for prof, p in pairs(OneForAllCharDB.professions) do
      if type(p.known) == "table" then
        local ids = {}
        for sp in pairs(p.known) do ids[#ids + 1] = tonumber(sp) or 0 end
        table.sort(ids)
        parts[#parts + 1] = prof .. ":" .. table.concat(ids, ",")
      end
    end
  end
  table.sort(parts)
  return table.concat(parts, ";")
end

local lastGuildSent = 0
local guildPending = false
local lastSentCount -- fingerprint of the recipes sent last (countKnown)
local guildTid = 0

-- own recipe lists to the guild
local function broadcastGuild()
  guildPending = false
  if not guildName() then return end
  local own = ownRecipes()
  -- which professions we have (5.6.3): receivers drop the ones that are not in the list
  local profs = {}
  for prof in pairs(own) do profs[#profs + 1] = prof end
  table.sort(profs)
  send("GUILD", "P\t" .. table.concat(profs, ","))
  for _, prof in ipairs(profs) do
    local ids = {}
    for s in pairs(own[prof]) do ids[#ids + 1] = enc(s) end
    table.sort(ids)
    local chunks, chunk = {}, ""
    for _, id in ipairs(ids) do
      if #chunk + #id + 1 > MAX_LEN - #prof - 3 - 12 then chunks[#chunks + 1] = chunk; chunk = "" end -- 12: "#i.tid,"
      chunk = (chunk == "" and id) or (chunk .. "," .. id)
    end
    if chunk ~= "" then chunks[#chunks + 1] = chunk end
    -- 6.1.0: "#n.tid" = number of data packets and transfer ID, each D starts with "#i.tid" (packet number);
    -- receivers keep the old list until all packets arrived. 6.0 ignores both (no valid base36 recipe ID).
    guildTid = guildTid + 1
    local tid = enc(guildTid) .. enc(math.random(0, 1295))
    send("GUILD", "B\t" .. prof .. "\t#" .. #chunks .. "." .. tid)
    for i, c in ipairs(chunks) do send("GUILD", "D\t" .. prof .. "\t#" .. i .. "." .. tid .. "," .. c) end
  end
  lastGuildSent = clock()
  lastSentCount = countKnown()
end

local function scheduleGuild(delay)
  if guildPending then return end
  guildPending = true
  if C_Timer and C_Timer.After then C_Timer.After(delay, broadcastGuild) else broadcastGuild() end
end

-- Called after the profession window was scanned.
function FLT.OnProfessionScan()
  local total = countKnown()
  if total ~= lastSentCount then
    if not lastSentCount then ownRecipes(); lastSentCount = total
    else scheduleGuild(5) end
  end
end

local stopSharing -- forward: drops the own search and everything still waiting to be sent (sharing turned off)
-- Settings toggle for the channel sharing.
function FLT.IsRecipeShareEnabled() return shareEnabled() end
function FLT.SetRecipeShareEnabled(v)
  if type(OneForAllDB) ~= "table" then return end
  OneForAllDB.recipeShareChannel = v and true or false
  if v then joinChannel() else leaveChannel(); stopSharing() end
  refreshBrowser()
end

-- ---------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------
local refreshPending = false
local function refreshSoon()
  if refreshPending then return end
  refreshPending = true
  if C_Timer and C_Timer.After then C_Timer.After(1, function() refreshPending = false; refreshBrowser() end)
  else refreshPending = false; refreshBrowser() end
end

selfIdentified = function()
  ownRecipes()
  refreshSoon()
end

-- Own messages come back to us. They carry this session's token, which tells
-- us the full name of the current character (also without a guild).
local SESSION = string.format("%x%x", math.random(0, 0xFFFFFF), math.floor(clock() * 1000) % 0xFFFFFF)
local function learnOwnName(name)
  if type(OneForAllCharDB) ~= "table" or not name then return end
  status[name] = nil
  if OneForAllCharDB.fullName ~= name then
    OneForAllCharDB.fullName = name
    selfIdentified()
  else
    refreshSoon()
  end
end

-- guild (prefix OFAPR): hello and recipe lists
local guildBuf = {} -- ["name\tprofession"] = list being received
local function onGuildMessage(msg, who)
  local kind, prof, data = msg:match("^(%a)\t?([^\t]*)\t?(.*)$")
  if kind == "H" and prof == SESSION then learnOwnName(who); return end
  if isMe(who) then return end
  if kind == "H" then
    if clock() - lastGuildSent > 20 then scheduleGuild(3 + math.random() * 7) end
    return
  end
  local db = guildDB(true)
  if not db then return end
  if kind == "P" then
    -- list of the sender's professions: forget the ones he no longer has
    local rec = db[who]
    if type(rec) == "table" then
      local has = {}
      for p in (prof or ""):gmatch("[^,]+") do has[p] = true end
      for key in pairs(rec) do if FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[key] and not has[key] then rec[key] = nil end end
      refreshSoon()
    end
    return
  end
  if not (prof and FLT.PROFESSION_RECIPES and FLT.PROFESSION_RECIPES[prof]) then return end
  db[who] = db[who] or {}
  local rec = db[who]
  rec.t = now()
  -- 6.1.0 senders ("#n.tid"): the list is collected and replaces the stored one only when all n different packets of
  -- this transfer arrived; incomplete ones expire after 10 s and the old list stays (GPT review 03.11.).
  -- 6.0 senders (no count): their packets are only added to the stored list - a quiet time proves nothing.
  local key = who .. "\t" .. prof
  if kind == "B" then
    local n, tid = data:match("^#(%d+)%.(%w+)")
    n = tonumber(n or "")
    if not n then return end -- 6.0: nothing to clear
    if n == 0 then rec[prof] = {}; guildBuf[key] = nil; refreshSoon(); return end
    local b = { set = {}, need = n, got = 0, have = {}, tid = tid }
    guildBuf[key] = b
    if C_Timer and C_Timer.After then C_Timer.After(10, function() if guildBuf[key] == b then guildBuf[key] = nil end end) end
  elseif kind == "D" then
    local i, tid = data:match("^#(%d+)%.(%w+),")
    i = tonumber(i or "")
    local b = guildBuf[key]
    local set
    if i then
      if not (b and b.tid == tid) or i < 1 or i > b.need or b.have[i] then return end -- other transfer, nonsense, duplicate
      b.have[i] = true; b.got = b.got + 1
      set = b.set
    else
      set = rec[prof] or {}
      rec[prof] = set
    end
    for id in data:gmatch("[^,]+") do local sp = dec(id); if sp and validRecipe(prof, sp) then set[sp] = true end end
    if i then
      if b.got >= b.need then guildBuf[key] = nil; rec[prof] = b.set; refreshSoon() end
    else
      refreshSoon()
    end
  end
end

-- own zone, instance type, level, class, map ID (for the status and the answers)
local function ownStatusFields()
  local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
  local inst = "none"
  if IsInInstance then local _, it = IsInInstance(); inst = it or "none" end
  -- in a dungeon we know: its English name, so every client can read it
  if inst ~= "none" and GetInstanceInfo then
    local instID = select(8, GetInstanceInfo())
    for _, d in ipairs(FLT.DUNGEONS or {}) do if instID and d.instanceID == instID then zone = d.name; break end end
  end
  local level = UnitLevel and UnitLevel("player") or 0
  local classFile = UnitClass and select(2, UnitClass("player"))
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or 0
  return (zone:gsub("\t", " ")) .. "\t" .. inst .. "\t" .. tostring(level or 0) .. "\t" .. (classFile or "") .. "\t" .. tostring(mapID or 0)
end

-- status fields f[i..i+4] = zone, inst, level, class, mapID -> status[who]
local function readStatus(who, f, i)
  local zone, inst = f[i] ~= "" and f[i] or nil, f[i + 1] or ""
  local mapID = tonumber(f[i + 4] or "")
  local resolved = false
  if mapID and mapID > 0 and C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if ok and info and info.name and info.name ~= "" then zone = info.name; resolved = true end
  end
  -- inside an instance the map ID is often missing: the sender's text is in his client's language then;
  -- keep it only if it is one of our (English) dungeon names, else just "(in a dungeon)" (16.10.)
  if not resolved and inst ~= "" and inst ~= "none" and zone then
    local known = false
    for _, d in ipairs(FLT.DUNGEONS or {}) do if d.name == zone then known = true; break end end
    if not known then zone = nil end
  end
  local cls = f[i + 3]
  status[who] = {zone = zone, inst = inst ~= "" and inst ~= "none" and inst or nil, level = tonumber(f[i + 2] or ""),
    class = (cls and cls ~= "") and cls or nil, map = (mapID and mapID > 0) and mapID or nil, t = now()}
end

local function ownMapID()
  local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  return (type(m) == "number" and m > 0) and m or nil
end

-- players online per map (from their status), counted at most once a minute (used for every search heard)
local mapCount, mapCountAt = {}, -100
local function playersOnMap(map)
  local t = clock()
  if t - mapCountAt > 60 then
    mapCountAt = t
    wipe(mapCount)
    local nt = now()
    for _, st in pairs(status) do
      if st.map and nt - (st.t or 0) < onlineWindow then mapCount[st.map] = (mapCount[st.map] or 0) + 1 end
    end
  end
  return mapCount[map] or 0
end

-- the own search (one at a time)
local search            -- { qid, prof, spell, round, hits = {[name]=true}, n, sent = time }
local recentQ = {}      -- own search IDs of the last minute: [qid] = { prof, spell, t } (late answers still count)
local lastSearch = {}   -- [prof .. ":" .. spell] = { t, n (players found), limited }
local searchTimes = {}  -- start times of the own searches (last 10 minutes)
local wanted            -- { prof, spell, manual } waiting for the next free slot
local lastStart = -100
local gapTimer = false
local startSearch, finishSearch -- forward

-- answering
local answeredQ = {}    -- [qid] = time
local searchOwner = {}  -- [qid] = { who, t } of searches we may answer (X only counts from him)
local cancelled = {}    -- [qid] = true after X
local answerMinute, answerCount = -1, 0
local lastS, lastZ = {}, {} -- per sender: time of the last search / status we read

local fld = {}
local function split(msg)
  wipe(fld)
  for part in (msg .. "\t"):gmatch("([^\t]*)\t") do fld[#fld + 1] = part end
  return fld
end

-- the same number for the same search and player on every client: decides who answers in which round
local function pick(qid)
  local s = qid .. ":" .. (myName() or firstName() or SESSION)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  -- a few steps of the Park-Miller generator spread names that differ only in the last letters
  for _ = 1, 4 do h = (h * 48271) % 2147483647 end
  return h / 2147483647
end

local function onSearch(who, f)
  local qid, prof, spell, share = f[2], f[3], dec(f[4] or ""), tonumber(f[5] or "")
  if not (qid and qid ~= "" and share and share > 0 and share <= 1e6 and validRecipe(prof, spell)) then return end
  local t = clock()
  -- one search message per player and second at most (rounds come 3 s apart)
  if lastS[who] and t - lastS[who] < 1 then stats.dropped = stats.dropped + 1; stats.dRate = stats.dRate + 1; return end
  lastS[who] = t
  if answeredQ[qid] or not ownKnown(prof, spell) then return end
  -- players on the searcher's map answer in any case (user 03.11.: nearby players first), at most about TARGET of
  -- them: the same assumption as the first round (a quarter of the players there know it)
  local p = share / 1e6
  local map = tonumber(f[6] or "")
  if map and map > 0 and map == ownMapID() then
    p = math.max(p, math.min(1, TARGET / (0.25 * (playersOnMap(map) + 1))))
  end
  if pick(qid) >= p then return end
  -- remember who searched (an X only counts from him; the same qid from someone else is ignored)
  if searchOwner[qid] and searchOwner[qid][1] ~= who then return end
  searchOwner[qid] = { who, t }
  local m = math.floor(t / 60)
  if m ~= answerMinute then answerMinute, answerCount = m, 0 end
  if answerCount >= (share >= 1e6 and ANSWER_MAX_ALL or ANSWER_MAX) then stats.dropped = stats.dropped + 1; stats.dBudget = stats.dBudget + 1; return end
  answerCount = answerCount + 1
  answeredQ[qid] = t
  local msg = "A\t" .. qid .. "\t" .. prof .. "\t" .. enc(spell) .. "\t" .. ownStatusFields()
  local minute = m
  local function go()
    if cancelled[qid] or not shareEnabled() then
      if answerMinute == minute then answerCount = answerCount - 1 end -- not sent: does not count
      return
    end
    send("WHISPER", msg, who, function() stats.answers = stats.answers + 1 end)
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.2 + math.random() * (ANSWER_DELAY - 0.2), go) else go() end
end

local function onAnswer(who, f)
  local qid, prof, spell = f[2], f[3], dec(f[4] or "")
  local q = recentQ[qid]
  if not (q and q[1] == prof and q[2] == spell and clock() - q[3] <= 60) then return end
  addHit(prof, spell, who, now())
  readStatus(who, f, 5)
  if search and search.qid == qid and not search.hits[who] then
    search.hits[who] = true
    search.n = search.n + 1
    search.got = search.got + 1
    stats.hits = stats.hits + 1
    if search.n >= TARGET then
      -- enough answers within the first 1.2 s of the round (answers come within 2 s): many more are on their way,
      -- stop them (costs a channel message, so only then)
      if clock() - (search.roundStart or 0) < 1.2 then send("CHANNEL", "X\t" .. qid) end
      finishSearch()
    end
  end
  refreshSoon()
end

local function onChannelMessage(prefix, msg, channel, sender)
  counted()
  local who = shortName(sender)
  if not who then return end
  local f = split(msg)
  local kind = f[1]
  if kind == "Z" and channel == "CHANNEL" then
    stats.zMin = stats.zMin + 1
    if f[7] == SESSION then learnOwnName(who); return end
    if isMe(who) then return end
    local t = clock()
    if lastZ[who] and t - lastZ[who] < 60 then stats.dropped = stats.dropped + 1; stats.dRate = stats.dRate + 1; return end
    lastZ[who] = t
    readStatus(who, f, 2) -- no refresh here: the recipe window looks again once a minute
    return
  end
  if isMe(who) then return end
  if kind == "S" and channel == "CHANNEL" then stats.sMin = stats.sMin + 1; stats.s10 = stats.s10 + 1; onSearch(who, f)
  elseif kind == "A" and channel == "WHISPER" then onAnswer(who, f)
  elseif kind == "X" and channel == "CHANNEL" then
    local o = searchOwner[f[2] or ""]
    if o and o[1] == who then cancelled[f[2]] = true end
  end
end

local function onAddonMessage(prefix, msg, channel, sender)
  if type(msg) ~= "string" then return end
  if prefix == PREFIX then
    if channel == "GUILD" then local who = shortName(sender); if who then onGuildMessage(msg, who) end end
  elseif prefix == PREFIX2 then
    if (channel == "CHANNEL" or channel == "WHISPER") and shareEnabled() then onChannelMessage(prefix, msg, channel, sender) end
  end
end

-- ---------------------------------------------------------------------------
-- Searching
-- ---------------------------------------------------------------------------
local function key(prof, spell) return prof .. ":" .. spell end

-- share of the players to ask in the next round: first as if a quarter of the players online knew it (about TARGET
-- answers; fewer channel messages matter more than a few extra whispers),
-- then from the answers so far (estimated number of players that know it), or GROW times more without answers.
-- nil = stop.
local function nextShare(s, online)
  if s.round == 0 then return math.min(1, TARGET / (0.25 * (online + 1))) end
  if s.n >= TARGET or s.p >= 1 or s.round >= MAX_ROUNDS then return nil end
  local p
  if s.got > 0 then p = s.p * (TARGET - s.n + s.got) / s.got else p = s.p * GROW end
  p = math.min(1, math.max(p, s.p * 1.5))
  -- asking everyone (or the last round) only while fewer than MIN_HITS were found
  if (p >= 1 or s.round + 1 >= MAX_ROUNDS) and s.n >= MIN_HITS then return nil end
  return p
end

-- searches per second on the channel: the last full minute, the last 10 s or the running 10 s (after 2 s),
-- whichever is highest (a sudden wave is noticed within seconds)
local function searchLoad()
  rollMinute()
  local load = math.max(stats.sLast / 60, stats.s10Last / 10)
  local part = clock() - stats.s10At * 10
  if part >= 2 then load = math.max(load, stats.s10 / part) end
  return load
end
-- under load a search (or its next round) goes ahead only with the chance SEARCH_LOAD / load
local function overLoad()
  local load = searchLoad()
  return load > SEARCH_LOAD and math.random() > SEARCH_LOAD / load
end

local function runRound(online)
  if not search then return end
  local s = search
  local p = nextShare(s, online or 0)
  if not p then finishSearch(); return end
  if s.round > 0 and overLoad() then
    if s.n == 0 then s.limited = true; stats.limited = stats.limited + 1 end
    finishSearch(); return
  end
  s.p, s.round = p, s.round + 1
  local round = s.round
  -- the round starts when the game took the message (not when it was queued)
  local function sent()
    s.roundStart = clock()
    if C_Timer and C_Timer.After then
      C_Timer.After(ROUND_WAIT, function() if search == s and s.round == round then runRound() end end)
    end
  end
  local function failed() if search == s then s.limited = true; finishSearch() end end
  -- 6th field: our map, so players nearby answer in any case
  local item = send("CHANNEL", "S\t" .. s.qid .. "\t" .. s.prof .. "\t" .. enc(s.spell) .. "\t" .. math.max(1, math.floor(p * 1e6)) .. "\t" .. (ownMapID() or 0), nil, sent, failed)
  if not item then s.limited = true; finishSearch(); return end
  if item.queued then s.pending = item end
end

finishSearch = function()
  local s = search
  if not s then return end
  search = nil
  if s.pending then s.pending.cancelled = true end -- a round still waiting in the queue is not sent any more
  lastStart = clock() -- the next search waits SEARCH_GAP after this one ended
  lastSearch[key(s.prof, s.spell)] = { t = now(), n = s.n, limited = s.limited }
  refreshSoon()
  if wanted then
    local w = wanted; wanted = nil
    FLT.SearchRecipe(w[1], w[2], w[3])
  end
end

local qidCount = 0
startSearch = function(prof, spell, manual)
  local t = clock()
  qidCount = qidCount + 1
  local qid = enc(math.random(0, 60466175)) .. "." .. enc(qidCount)
  search = { qid = qid, prof = prof, spell = spell, round = 0, p = 0, got = 0, hits = {}, n = 0 }
  recentQ[qid] = { prof, spell, t }
  lastStart = t
  searchTimes[#searchTimes + 1] = t
  stats.searches = stats.searches + 1
  -- players that confirmed this recipe within 15 min and are online count as found (no need to ask them again);
  -- "Search again" asks everyone anew
  local db = not manual and hitsDB()
  local players = db and db[prof] and db[prof][spell]
  local nt = now()
  for player, ht in pairs(players or {}) do
    local st = status[player]
    if nt - ht < AGAIN_HIT and st and nt - st.t < 300 and not isMe(player) then search.hits[player] = true; search.n = search.n + 1 end
  end
  if search.n >= TARGET then finishSearch(); return end
  -- players online: the ones we heard from, or more when the statuses on the channel say so (right after login we
  -- know only a few); in the first 3 minutes on the channel at most a tenth is asked in the first round
  rollMinute()
  local online = math.max(updateIntervals(), stats.zLast * STATUS_MIN / 60)
  if t - joinedAt < 180 then online = math.max(online, 10 * TARGET / 0.25) end
  runRound(online)
  refreshSoon()
end

-- Ask the channel who knows a recipe (when a recipe is opened). manual = "Search again" button.
function FLT.SearchRecipe(prof, spell, manual)
  if not (shareEnabled() and validRecipe(prof, spell)) then return end
  -- right after login the channel is not joined yet (about 15 s): search once it is
  if not (channelReady and channelID()) then
    if not (ownKnown(prof, spell) and not manual) then wanted = { prof, spell, manual } end
    return
  end
  if ownKnown(prof, spell) and not manual then return end
  local last = lastSearch[key(prof, spell)]
  local t = now()
  if last then
    local again = (manual or last.limited) and (last.limited and AGAIN_LIMITED or AGAIN_MANUAL) or (last.n > 0 and AGAIN_HIT or AGAIN_MISS)
    if t - last.t < again then return end
  end
  if search then
    if search.prof ~= prof or search.spell ~= spell then wanted = { prof, spell, manual } end
    return
  end
  local c = clock()
  -- at most SEARCH_MAX searches per 10 minutes
  local keep = {}
  for _, st in ipairs(searchTimes) do if c - st < 600 then keep[#keep + 1] = st end end
  searchTimes = keep
  if #searchTimes >= SEARCH_MAX or overLoad() then
    lastSearch[key(prof, spell)] = { t = t, n = 0, limited = true }
    stats.limited = stats.limited + 1
    refreshSoon()
    return
  end
  if c - lastStart < SEARCH_GAP then
    wanted = { prof, spell, manual }
    if C_Timer and C_Timer.After and not gapTimer then
      gapTimer = true
      C_Timer.After(SEARCH_GAP - (c - lastStart) + 0.1, function()
        gapTimer = false
        if not search and wanted then local w = wanted; wanted = nil; FLT.SearchRecipe(w[1], w[2], w[3]) end
      end)
    end
    return
  end
  startSearch(prof, spell, manual)
end

-- State of the search for a recipe: "off", "searching", "limited", "done", or nil (not searched yet),
-- plus seconds since the last search and whether "Search again" may be used now.
function FLT.RecipeSearchState(prof, spell)
  if not shareEnabled() then return "off" end
  if not (channelReady and channelID()) then
    -- not joined yet (right after login): a search asked for waits for the channel
    if wanted and wanted[1] == prof and wanted[2] == spell then return "connecting" end
    return nil
  end
  if search and search.prof == prof and search.spell == spell then return "searching" end
  if wanted and wanted[1] == prof and wanted[2] == spell then return "searching" end
  local last = lastSearch[key(prof, spell)]
  if not last then return nil end
  local ago = now() - last.t
  return last.limited and "limited" or "done", ago, ago >= AGAIN_MANUAL
end

-- sharing turned off: no search, nothing waiting is sent, planned answers are dropped
stopSharing = function()
  local s = search
  search, wanted = nil, nil
  if s and s.pending then s.pending.cancelled = true end
  for _, d in ipairs({ "CHANNEL", "WHISPER" }) do
    local q = queues[d]
    for i = q.h, q.t do if q[i] then q[i].cancelled = true end end
  end
  for q in pairs(answeredQ) do cancelled[q] = true end
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------
local lastStatus, statusPending, statusItem = -1e9, false, nil
local function sendStatus()
  statusPending = false
  if not (shareEnabled() and channelID()) then return end
  -- many statuses on the channel right now (login wave): wait a little, in proportion to the load
  rollMinute()
  local rate = stats.zLast / 60
  if rate > STATUS_RATE * 1.5 and math.random() > STATUS_RATE * 1.5 / rate and C_Timer and C_Timer.After then
    statusPending = true
    C_Timer.After(30 + math.random() * 90, sendStatus)
    return
  end
  local msg = "Z\t" .. ownStatusFields() .. "\t" .. SESSION
  -- a status still waiting in the queue is replaced, not queued twice
  if statusItem and statusItem.queued then statusItem[1] = msg else statusItem = send("CHANNEL", msg) end
  lastStatus = clock()
end
scheduleStatus = function(delay)
  if statusPending then return end
  statusPending = true
  -- zone changes and level-ups: at most one status per 3/4 interval (answers carry the current zone anyway)
  local wait = math.max(delay, math.max(60, statusEvery * 0.75) - (clock() - lastStatus))
  if C_Timer and C_Timer.After then C_Timer.After(wait, sendStatus) else sendStatus() end
end

-- every 2 minutes: clean-up of the per-search tables
local function cleanup()
  local t = clock()
  for q, v in pairs(answeredQ) do if t - v > 120 then answeredQ[q] = nil; cancelled[q] = nil end end
  for q, v in pairs(searchOwner) do if t - v[2] > 120 then searchOwner[q] = nil; cancelled[q] = nil end end
  for q, v in pairs(recentQ) do if t - v[3] > 60 then recentQ[q] = nil end end
  for n, v in pairs(lastS) do if t - v > 60 then lastS[n] = nil end end
  for n, v in pairs(lastZ) do if t - v > 120 then lastZ[n] = nil end end
  local nt = now()
  for n, st in pairs(status) do if nt - (st.t or 0) > onlineWindow then status[n] = nil end end
  if C_Timer and C_Timer.After then C_Timer.After(120, cleanup) end
end
-- own status once per interval (+-10 %), counted from the last one sent (a status after a zone change moves it on)
local nextDue
local function heartbeat()
  updateIntervals()
  local t = clock()
  nextDue = nextDue or (t + statusEvery * (0.9 + math.random() * 0.2))
  if channelReady and t - lastStatus >= statusEvery * 0.9 and t >= nextDue then
    scheduleStatus(0)
    nextDue = t + statusEvery * (0.9 + math.random() * 0.2)
  elseif lastStatus > -1e9 and nextDue < lastStatus + statusEvery * 0.9 then
    nextDue = lastStatus + statusEvery * (0.9 + math.random() * 0.2)
  end
  if C_Timer and C_Timer.After then C_Timer.After(math.max(30, nextDue - t), heartbeat) end
end

-- the channel is there (after login or a later retry): move it to the end, first status after 10-120 s
-- (spread out, many players log in at the same time)
onChannelReady = function()
  if channelReady then return end
  channelReady = true
  joinedAt = clock()
  -- a recipe opened before the channel was there is searched now
  if C_Timer and C_Timer.After then
    C_Timer.After(2, function()
      if wanted and not search then local w = wanted; wanted = nil; FLT.SearchRecipe(w[1], w[2], w[3]) end
      refreshSoon()
    end)
  end
  moveChannelToEnd()
  -- the first status within 10 s to 10 min: a login wave spreads out (search answers show us anyway)
  scheduleStatus(10 + math.random() * (STATUS_MIN - 10))
end

-- /ofa channel
function FLT.RecipeShareStatus()
  local online = updateIntervals()
  rollMinute()
  local last = lastStatus > -1e9 and math.floor(clock() - lastStatus) or nil
  return {
    enabled = shareEnabled(), channel = channelID(), tries = joinTries, online = online, known = hitCount,
    lastStatus = last, queued = qlen(queues.CHANNEL) + qlen(queues.WHISPER),
    every = math.floor(statusEvery), recv = stats.recv, recvMin = stats.recvMin, recvPeak = math.max(stats.recvPeak, stats.recvMin),
    dropped = stats.dropped, searches = stats.searches, answers = stats.answers, hits = stats.hits,
    qPeak = stats.qPeak, load = searchLoad(), limited = stats.limited, dQueue = stats.dQueue, dRate = stats.dRate, dBudget = stats.dBudget,
  }
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local lastRosterRefresh = -100
local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_LOGIN", "CHAT_MSG_ADDON", "GUILD_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_ADDON" then
    onAddonMessage(...)
  elseif event == "GUILD_ROSTER_UPDATE" then
    readRoster()
    local t = clock()
    if t - lastRosterRefresh > 30 then lastRosterRefresh = t; refreshSoon() end
  elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_LEVEL_UP" then
    if channelReady and lastStatus > -1e9 then scheduleStatus(10) end
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
      pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX2)
    end
    if type(OneForAllDB) == "table" then
      pruneHits()
      local saved, t = OneForAllDB.shareStatus, now()
      if type(saved) == "table" then
        -- first everything of the last hour, then the online window from that many players, then filter
        for name, st in pairs(saved) do if type(st) == "table" and (t - (st.t or 0)) < 3600 then status[name] = st end end
        onlineWindow = 3600
        updateIntervals()
        for name, st in pairs(status) do if (t - (st.t or 0)) >= onlineWindow then status[name] = nil end end
      end
      OneForAllDB.shareStatus = status
    end
    if C_Timer and C_Timer.After then
      -- guild info and channels are only ready a few seconds after login
      C_Timer.After(12, function()
        if guildName() then
          if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
          send("GUILD", "H\t" .. SESSION)
          broadcastGuild()
        end
        joinChannel()
      end)
      C_Timer.After(20, heartbeat)
      C_Timer.After(120, cleanup)
    end
  end
end)
