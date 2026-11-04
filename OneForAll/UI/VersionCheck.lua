local _, FLT = ...

-- New version notice, shown only right after logging in.
-- About 20 s after login the addon asks the guild, the group and the hidden
-- recipe-sharing channel which version they run ("Q" + own version). Players
-- with a newer version answer once ("V" + their version). A newer version is
-- confirmed by one guild/group member or by two different channel players.
-- The yellow note is printed during the first minutes after login only; a
-- newer version seen later is remembered and shown at the next login.

local PREFIX = "OFAVER"
local CHANNEL = "OFAShare2" -- the recipe channel (6.1.0; 6.0 and older use "OFAShare")
local LOGIN_WINDOW = 180 -- seconds after login in which the note may appear

local function myVersion()
  local v
  if C_AddOns and C_AddOns.GetAddOnMetadata then v = C_AddOns.GetAddOnMetadata("OneForAll", "Version")
  elseif GetAddOnMetadata then v = GetAddOnMetadata("OneForAll", "Version") end
  return v or "0"
end

-- "4.19.0" -> {4,19,0}; versions with a suffix (beta, test) -> nil
local function parse(v, allowSuffix)
  if type(v) ~= "string" then return nil end
  local nums, rest = v:match("^([%d%.]+)(.*)$")
  if not nums or (rest ~= "" and not allowSuffix) then return nil end
  local t = {}
  for n in nums:gmatch("%d+") do t[#t + 1] = tonumber(n) end
  return #t > 0 and t or nil
end
local function newer(a, b) -- a > b
  for i = 1, math.max(#a, #b) do
    local x, y = a[i] or 0, b[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

local mine = parse(myVersion(), true) or {0}
local reports, told = {}, {}
local loginTime

local function now() return GetTime and GetTime() or 0 end
local function enabled()
  return not (type(OneForAllDB) == "table" and OneForAllDB.versionNotice == false)
end

local function announce(v)
  if told[v] then return end
  told[v] = true
  if FLT.Msg then
    FLT.Msg("|cffffd100A newer version (" .. v .. ") is available on CurseForge. You are using " .. myVersion() .. ".|r")
  end
end

local function confirmed(v)
  if not enabled() then return end
  if loginTime and now() - loginTime <= LOGIN_WINDOW then
    announce(v)
  elseif type(OneForAllDB) == "table" then
    -- too late in the session: remember it for the next login
    local old = parse(OneForAllDB.pendingNewVersion, false)
    local t = parse(v, false)
    if not old or newer(t, old) then OneForAllDB.pendingNewVersion = v end
  end
end

local function onVersion(v, sender, trusted)
  local t = parse(v, false)
  if not (t and newer(t, mine)) or told[v] then return end
  local seen = reports[v] or {}
  reports[v] = seen
  seen[sender or "?"] = true
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  if trusted or n >= 2 then confirmed(v) end
end

local function send(msg, dist, target)
  if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
  pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, dist, target)
end

local function channelID()
  local id = GetChannelName and GetChannelName(CHANNEL)
  if id and id > 0 then return id end
end

local function ask()
  local q = "Q\t" .. myVersion()
  if IsInGuild and IsInGuild() then send(q, "GUILD") end
  if IsInRaid and IsInRaid() then send(q, "RAID") elseif IsInGroup and IsInGroup() then send(q, "PARTY") end
  local id = channelID()
  if id then send(q, "CHANNEL", id) end
end

-- Answer someone with an older version once (random delay, skipped if another
-- player already answered with the same version in the meantime).
local lastAnswer, answeredBy = {}, {}
local function answer(dist)
  local key = dist
  if lastAnswer[key] and now() - lastAnswer[key] < 60 then return end
  lastAnswer[key] = now()
  local v = myVersion()
  if not parse(v, false) then return end -- test builds never answer
  local function go()
    if answeredBy[v] and now() - answeredBy[v] < 30 then return end
    if dist == "CHANNEL" then
      local id = channelID()
      if id then send("V\t" .. v, "CHANNEL", id) end
    else
      send("V\t" .. v, dist)
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(1 + math.random() * 5, go) else go() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_LOGIN", "CHAT_MSG_ADDON"}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
  if event == "PLAYER_LOGIN" then
    loginTime = now()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    if C_Timer and C_Timer.After then
      -- a newer version seen in an earlier session
      C_Timer.After(8, function()
        if type(OneForAllDB) ~= "table" then return end
        local p = OneForAllDB.pendingNewVersion
        OneForAllDB.pendingNewVersion = nil
        local t = parse(p, false)
        if t and newer(t, mine) and enabled() then announce(p) end
      end)
      -- after the recipe-sharing channel is joined (about 12 s after login)
      C_Timer.After(20, ask)
    end
  elseif event == "CHAT_MSG_ADDON" and prefix == PREFIX and type(msg) == "string" then
    local kind, v = msg:match("^(%a)\t(.+)$")
    if not kind then return end
    local trusted = channel == "GUILD" or channel == "PARTY" or channel == "RAID"
    if kind == "V" then
      answeredBy[v] = now()
      onVersion(v, sender, trusted)
    elseif kind == "Q" then
      onVersion(v, sender, trusted) -- the asker may run a newer version too
      local t = parse(v, true)
      if t and newer(mine, t) then answer(channel) end
    end
  end
end)
