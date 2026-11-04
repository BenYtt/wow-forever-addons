local ADDON, FLT = ...
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- Quest share helper.
-- Inside a dungeon from the Dungeons tab, OneForAll looks for quests of that
-- dungeon in your log that can be shared and that a group member does not
-- have yet. A small popup lists them with a Share button. (The emote that was
-- posted when sharing was removed in 5.6.8, user 22.10.)
--
-- What the game tells us about other players:
--   * whether they have a quest in their log (IsUnitOnQuest)
--   * their level and faction
-- It does NOT tell us whether they already completed a quest. Group members
-- who also run OneForAll send that information via a hidden addon message;
-- for everyone else the game's own reply to the share ("has completed that
-- quest", "is not eligible", ...) is shown in the popup and remembered.

local PREFIX = "OneForAll"
local ROW_H = 46
local MAX_ROWS = 8

local popup
local rows = {}
local currentDungeon        -- dungeon table from FLT.DUNGEONS while inside it
local candidates = {}       -- list of {quest=, logIndex=, missing={names}}
local testMode = false      -- /ofa share test: fake group, nothing is sent
local remoteDone = {}       -- [playerName][questID] = true (addon messages)
local shareReplies = {}     -- [questID][playerName] = short status text
local blocked = {}          -- [questID][playerName] = true (completed / not eligible)
local dismissedSignature    -- set when the player closed the popup in this dungeon visit
local autoShown             -- popup already opened automatically in this visit
local lastGroupSize = 0
local lastShareQuest        -- questID of the last share started from the popup

local function settings()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.questShare = OneForAllDB.questShare or {}
  local s = OneForAllDB.questShare
  if s.popup == nil then s.popup = true end
  s.emote = nil -- old setting (emote when sharing, removed in 5.6.8)
  return s
end

-- ---------------------------------------------------------------------------
-- Dungeon detection
-- ---------------------------------------------------------------------------
local function normalize(s)
  s = string.lower(tostring(s or ""))
  s = s:gsub("^the ", ""):gsub("[^%a%d]", "")
  return s
end

local function findCurrentDungeon()
  if not IsInInstance then return nil end
  local inInstance, instanceType = IsInInstance()
  if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return nil end
  local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  local wanted = normalize(name)
  -- Scarlet Monastery wings share one instance ID: tell them apart by the map.
  local uiMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local byID
  for _, d in ipairs(FLT.DUNGEONS or {}) do
    if d.instanceID and instanceID and d.instanceID == instanceID then
      if d.uiMaps and uiMap then
        for _, m in ipairs(d.uiMaps) do if m == uiMap then return d end end
      end
      byID = byID or d
    end
  end
  if byID then return byID end
  for _, d in ipairs(FLT.DUNGEONS or {}) do
    local dn = normalize(d.name)
    if dn == wanted or (d.instanceName and normalize(d.instanceName) == wanted) then return d end
  end
  -- Loose match ("Excavation Site" vs "Excavation Site: Wetlands").
  if wanted ~= "" then
    for _, d in ipairs(FLT.DUNGEONS or {}) do
      local dn = normalize(d.name)
      if dn:find(wanted, 1, true) or wanted:find(dn, 1, true) then return d end
    end
  end
  return nil
end

FLT.FindCurrentDungeon = findCurrentDungeon

-- ---------------------------------------------------------------------------
-- Quest log helpers (modern C_QuestLog API with Classic fallbacks)
-- ---------------------------------------------------------------------------
local function questLogEntries()
  local list = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then list[info.questID] = { index = i, title = info.title } end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    for i = 1, GetNumQuestLogEntries() or 0 do
      local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
      if not isHeader and questID then list[questID] = { index = i, title = title } end
    end
  end
  return list
end

local function selectQuest(questID, logIndex)
  if C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, questID) end
  if SelectQuestLogEntry and logIndex then pcall(SelectQuestLogEntry, logIndex) end
end

local function isPushable(questID, logIndex)
  if C_QuestLog and C_QuestLog.IsPushableQuest then
    local ok, v = pcall(C_QuestLog.IsPushableQuest, questID)
    if ok then return v and true or false end
  end
  if GetQuestLogPushable and SelectQuestLogEntry and logIndex then
    local prev = GetQuestLogSelection and GetQuestLogSelection()
    SelectQuestLogEntry(logIndex)
    local v = GetQuestLogPushable()
    if prev and prev > 0 then SelectQuestLogEntry(prev) end
    return v and true or false
  end
  return false
end

local function unitOnQuest(unit, questID, logIndex)
  if C_QuestLog and C_QuestLog.IsUnitOnQuest then
    local ok, v = pcall(C_QuestLog.IsUnitOnQuest, unit, questID)
    if ok then return v and true or false end
  end
  if IsUnitOnQuest and logIndex then
    local ok, v = pcall(IsUnitOnQuest, logIndex, unit)
    if ok then return v and true or false end
  end
  return false
end

local function groupUnits()
  local units = {}
  if IsInRaid and IsInRaid() then return units end -- 5-player dungeons only
  local n = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or (GetNumPartyMembers and GetNumPartyMembers()) or 0
  for i = 1, n do units[#units + 1] = "party" .. i end
  return units
end

local function unitName(unit)
  local name = UnitName and UnitName(unit)
  return name
end

-- Can this group member take the quest at all, as far as we know?
local function memberCanTake(unit, name, q)
  if blocked[q.id] and blocked[q.id][name] then return false end
  if remoteDone[name] and remoteDone[name][q.id] then return false end
  local lvl = UnitLevel and UnitLevel(unit)
  if lvl and lvl > 0 and q.required and lvl < q.required then return false end
  local faction = UnitFactionGroup and UnitFactionGroup(unit)
  if faction and q.side and q.side ~= "Both" and q.side ~= "Neutral" and q.side ~= faction then return false end
  if q.class and UnitClass then
    local _, token = UnitClass(unit)
    if token and token ~= q.class then return false end
  end
  return true
end

local function scan()
  wipe(candidates)
  if not currentDungeon then return end
  local log = questLogEntries()
  local units = groupUnits()
  if #units == 0 then return end
  for _, q in ipairs(currentDungeon.quests or {}) do
    local entry = q.id and log[q.id]
    if entry and isPushable(q.id, entry.index) then
      local missing = {}
      for _, unit in ipairs(units) do
        local name = unitName(unit)
        if name and UnitIsConnected and UnitIsConnected(unit) ~= false
          and not unitOnQuest(unit, q.id, entry.index) and memberCanTake(unit, name, q) then
          missing[#missing + 1] = name
        end
      end
      if #missing > 0 then
        candidates[#candidates + 1] = { quest = q, logIndex = entry.index, missing = missing }
      end
    end
  end
end

local function signature()
  local parts = {}
  for _, c in ipairs(candidates) do parts[#parts + 1] = c.quest.id .. ":" .. table.concat(c.missing, ",") end
  return table.concat(parts, ";")
end

-- ---------------------------------------------------------------------------
-- Sharing
-- ---------------------------------------------------------------------------
local refresh -- forward
local render  -- forward

-- Test mode: fake the game's replies.
local function shareQuestTest(c)
  local q = c.quest
  shareReplies[q.id] = shareReplies[q.id] or {}
  local first, second = c.missing[1], c.missing[2]
  if first then shareReplies[q.id][first] = "accepted" end
  if second then shareReplies[q.id][second] = "already done" end
  -- The member who accepted no longer needs it; the other one is blocked.
  local keep = {}
  for i, name in ipairs(c.missing) do if i > 2 then keep[#keep + 1] = name end end
  c.shownReplies = { first, second }
  c.missing = keep
  if render then render() end
end

local function shareQuest(c)
  if testMode then return shareQuestTest(c) end
  local q = c.quest
  selectQuest(q.id, c.logIndex)
  if not QuestLogPushQuest then return end
  lastShareQuest = q.id
  QuestLogPushQuest()
  shareReplies[q.id] = shareReplies[q.id] or {}
end

-- Turns the game's share replies into short status texts. The patterns are
-- built from the client's own global strings, so they work in every language.
local REPLIES = {
  { key = "ERR_QUEST_PUSH_ACCEPTED_S",     text = "accepted",        done = true },
  { key = "ERR_QUEST_PUSH_ALREADY_DONE_S", text = "already done",    block = true },
  { key = "ERR_QUEST_PUSH_INVALID_S",      text = "not eligible",    block = true },
  { key = "ERR_QUEST_PUSH_ONQUEST_S",      text = "already has it",  done = true },
  { key = "ERR_QUEST_PUSH_DECLINED_S",     text = "declined" },
  { key = "ERR_QUEST_PUSH_LOG_FULL_S",     text = "quest log full" },
  { key = "ERR_QUEST_PUSH_TOO_FAR_S",      text = "too far away" },
  { key = "ERR_QUEST_PUSH_BUSY_S",         text = "busy" },
  { key = "ERR_QUEST_PUSH_DEAD_S",         text = "dead" },
}
local replyPatterns
local function buildPatterns()
  replyPatterns = {}
  for _, r in ipairs(REPLIES) do
    local fmt = _G[r.key]
    if type(fmt) == "string" then
      local pat = "^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
      replyPatterns[#replyPatterns + 1] = { pattern = pat, info = r }
    end
  end
end

local function onSystemMessage(text)
  if not lastShareQuest or type(text) ~= "string" then return end
  if not replyPatterns then buildPatterns() end
  for _, p in ipairs(replyPatterns) do
    local who = text:match(p.pattern)
    if who then
      who = who:gsub("%-.*$", "")
      shareReplies[lastShareQuest] = shareReplies[lastShareQuest] or {}
      shareReplies[lastShareQuest][who] = p.info.text
      if p.info.block then
        blocked[lastShareQuest] = blocked[lastShareQuest] or {}
        blocked[lastShareQuest][who] = true
      end
      if refresh then refresh(true, true) end
      return
    end
  end
end

-- ---------------------------------------------------------------------------
-- Addon messages: group members with OneForAll tell each other which quests
-- of the current dungeon they have already completed.
-- ---------------------------------------------------------------------------
local lastSent = 0
local lastPayload
local function sendCompleted(force)
  if not currentDungeon or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
  if #groupUnits() == 0 then return end
  local now = GetTime and GetTime() or 0
  if not force and now - lastSent < 5 then return end
  local ids = {}
  for _, q in ipairs(currentDungeon.quests or {}) do
    if q.id and FLT:IsQuestDone(q.id) then ids[#ids + 1] = q.id end
  end
  local payload = "QD:" .. table.concat(ids, ",")
  if not force and payload == lastPayload then return end
  lastSent, lastPayload = now, payload
  pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, "PARTY")
end

local function onAddonMessage(prefix, message, _, sender)
  if prefix ~= PREFIX or type(message) ~= "string" then return end
  local name = sender and sender:gsub("%-.*$", "")
  if not name or name == unitName("player") then return end
  local list = message:match("^QD:(.*)$")
  if list then
    remoteDone[name] = {}
    for id in list:gmatch("%d+") do remoteDone[name][tonumber(id)] = true end
    if refresh then refresh(false, true) end
  elseif message == "QR" then
    sendCompleted(true)
  end
end

-- ---------------------------------------------------------------------------
-- Popup
-- ---------------------------------------------------------------------------
local function createPopup()
  popup = CreateFrame("Frame", "OneForAllQuestSharePopup", UIParent, "BasicFrameTemplateWithInset")
  popup:SetSize(470, 120)
  popup:SetPoint("TOP", 0, -140)
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetMovable(true); popup:EnableMouse(true); popup:RegisterForDrag("LeftButton")
  popup:SetClampedToScreen(true)
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  if popup.TitleText then popup.TitleText:SetText("OneForAll - Share dungeon quests") end
  popup:HookScript("OnHide", function()
    if testMode then testMode = false; wipe(shareReplies); wipe(candidates) end
  end)
  if popup.TitleBg then popup.TitleBg:SetVertexColor(FLT.SkinC(0.70, 0.48, 0.14, 0.95)) end
  if type(popup.CloseButton) == "table" and popup.CloseButton.HookScript then
    popup.CloseButton:HookScript("OnClick", function() dismissedSignature = signature() end)
  end

  local sub = FLT.NewFS(popup, nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", 14, -32); sub:SetWidth(440); sub:SetJustifyH("LEFT")
  sub:SetTextColor(FLT.SkinC(0.80, 0.77, 0.68))
  popup.sub = sub

  for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, popup)
    row:SetSize(440, ROW_H - 4)
    row:SetPoint("TOPLEFT", 14, -52 - (i - 1) * ROW_H)
    local bg = makeTexture(row, "BACKGROUND", 0.10, 0.075, 0.035, 0.85); bg:SetAllPoints()
    local name = FLT.NewFS(row, nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", 8, -6); name:SetWidth(320); name:SetJustifyH("LEFT")
    local info = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 8, -24); info:SetWidth(320); info:SetJustifyH("LEFT")
    local btn = makeButton(row, "Share", 90, 26)
    btn:SetPoint("RIGHT", -8, 0)
    btn:SetScript("OnClick", function(self) if self.candidate then shareQuest(self.candidate) end end)
    row.name, row.info, row.button = name, info, btn
    row:Hide()
    rows[i] = row
  end

  local auto = FLT.SkinBlizz(CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate"))
  auto:SetSize(22, 22)
  auto:SetPoint("BOTTOMLEFT", 12, 8)
  local autoLabel = FLT.NewFS(popup, nil, "OVERLAY", "GameFontHighlightSmall")
  autoLabel:SetPoint("LEFT", auto, "RIGHT", 2, 0); autoLabel:SetText("Open automatically")
  auto:SetScript("OnClick", function(self) settings().popup = self:GetChecked() and true or false end)
  popup.auto = auto

  popup:Hide()
end

local function describe(c)
  local q = c.quest
  local replies = shareReplies[q.id] or {}
  local parts = {}
  for _, name in ipairs(c.missing) do
    parts[#parts + 1] = replies[name] and (name .. " (" .. replies[name] .. ")") or name
  end
  local done = {}
  for _, name in ipairs(c.shownReplies or {}) do
    if name and replies[name] then done[#done + 1] = name .. ": " .. replies[name] end
  end
  if #parts == 0 then return "Shared. " .. table.concat(done, ", ") end
  return "Missing for: " .. table.concat(parts, ", ") .. (#done > 0 and ("   |cff9d9d9d" .. table.concat(done, ", ") .. "|r") or "")
end

render = function()
  if not popup then createPopup() end
  local s = settings()
  popup.auto:SetChecked(s.popup)
  if popup.TitleText and not testMode then popup.TitleText:SetText("OneForAll - Share dungeon quests") end
  if testMode then
    popup.sub:SetText((currentDungeon and currentDungeon.name or "?") .. ": test mode - nothing is shared.")
  elseif #candidates == 0 then
    popup.sub:SetText("All shareable quests have been shared.")
  else
    popup.sub:SetText(currentDungeon and (currentDungeon.name .. ": quests your group members can still accept.") or "")
  end
  local shown = math.min(#candidates, MAX_ROWS)
  for i = 1, MAX_ROWS do
    local row, c = rows[i], candidates[i]
    if i <= shown then
      row.name:SetText(c.quest.name or ("Quest " .. tostring(c.quest.id)))
      row.info:SetText(describe(c))
      row.button.candidate = c
      if #c.missing > 0 then row.button:Enable() else row.button:Disable() end
      row:Show()
    else
      row.button.candidate = nil
      row:Hide()
    end
  end
  popup:SetHeight(52 + shown * ROW_H + 36)
end

-- auto: true when triggered by events (respects the setting and a previous close)
refresh = function(keepOpen, auto)
  if testMode then return end
  scan()
  if #candidates == 0 then
    if popup and popup:IsShown() and not keepOpen then popup:Hide() end
    if popup and popup:IsShown() then render() end
    return
  end
  if popup and popup:IsShown() then render(); return end
  if auto then
    -- Automatic opening: only if enabled, not closed by the player in this
    -- dungeon visit, and at most once per visit / per newly joined member.
    if not settings().popup then return end
    if dismissedSignature then return end
    if autoShown then return end
    autoShown = true
  end
  render()
  popup:Show()
end

-- "Share all Quests" in the dungeon quest list (6.0.2, user 31.10.): works anywhere (in town, at the entrance), for
-- the dungeon open in OneForAll. Shares only quests that are in your log, can be shared and that at least one group
-- member is missing and can take (same checks as the popup); one after the other, 1.5 s apart (the game handles one
-- share at a time). The game's replies show in the chat as usual.
local function candidatesFor(d)
  local saved = currentDungeon
  currentDungeon = d; scan(); currentDungeon = saved
  local out = {}
  for i, c in ipairs(candidates) do out[i] = c end
  if saved and saved ~= d then scan() end -- the popup's own list back
  return out
end
function FLT.ShareAllPreview(d)
  if #groupUnits() == 0 then return nil, "You are not in a group." end
  local list = candidatesFor(d)
  if #list == 0 then return nil, "Nothing to share: your group has all quests of this dungeon you can share, or cannot take them." end
  return list
end
function FLT.ShareAllQuests(d)
  local list, why = FLT.ShareAllPreview(d)
  if not list then FLT.Msg(why); return end
  local names = {}
  for i, c in ipairs(list) do
    names[i] = c.quest.name or ("Quest " .. tostring(c.quest.id))
    if C_Timer and C_Timer.After then C_Timer.After((i - 1) * 1.5, function() shareQuest(c) end) elseif i == 1 then shareQuest(c) end
  end
  FLT.Msg("Sharing " .. #list .. (#list == 1 and " quest: " or " quests: ") .. table.concat(names, ", "))
end

function FLT:OpenQuestShare()
  currentDungeon = findCurrentDungeon()
  if not currentDungeon then
    FLT.Msg("Quest sharing works inside a dungeon from the Dungeons tab.")
    return
  end
  if #groupUnits() == 0 then
    FLT.Msg("You are not in a group.")
    return
  end
  dismissedSignature = nil
  scan()
  if #candidates == 0 then
    FLT.Msg("Nothing to share: your group members already have all shareable quests of " .. currentDungeon.name .. " (or cannot take them).")
    return
  end
  render(); popup:Show()
end

-- /ofa share test: shows the popup with two made-up group members. Share only
-- fakes the replies; nothing is sent.
function FLT:QuestShareTest()
  local d = findCurrentDungeon()
  local log = questLogEntries()
  if not d then
    -- Prefer a dungeon with one of its quests in your log, else the first one
    -- with quests for your faction.
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, dd in ipairs(FLT.DUNGEONS or {}) do
      for _, q in ipairs(dd.quests or {}) do if log[q.id] then d = d or dd end end
    end
    if not d then
      for _, dd in ipairs(FLT.DUNGEONS or {}) do
        for _, q in ipairs(dd.quests or {}) do
          if not d and (q.side == "Both" or q.side == faction) then d = dd end
        end
      end
    end
  end
  if not d then FLT.Msg("No dungeon quests found for a test."); return end
  testMode = true
  currentDungeon = d
  wipe(candidates); wipe(shareReplies)
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local inLog, other = {}, {}
  for _, q in ipairs(d.quests or {}) do
    if q.side == "Both" or not faction or q.side == faction then
      if log[q.id] then inLog[#inLog + 1] = q else other[#other + 1] = q end
    end
  end
  for _, q in ipairs(other) do inLog[#inLog + 1] = q end
  for i = 1, math.min(3, #inLog) do
    candidates[#candidates + 1] = { quest = inLog[i], missing = { "Testplayer-A", "Testplayer-B" } }
  end
  render()
  if popup.TitleText then popup.TitleText:SetText("OneForAll - Share dungeon quests (TEST)") end
  popup:Show()
end

function FLT:SetQuestShareOption(key, value)
  settings()[key] = value and true or false
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local pending
local function schedule(delay)
  if pending then return end
  pending = true
  local function run()
    pending = nil
    local d = findCurrentDungeon()
    if d ~= currentDungeon then
      currentDungeon = d
      wipe(shareReplies); wipe(blocked); dismissedSignature = nil; autoShown = nil
      if popup then popup:Hide() end
    end
    if currentDungeon then
      sendCompleted(false)
      refresh(false, true)
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay or 1, run) else run() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:RegisterEvent("CHAT_MSG_ADDON")
local function onEventSafe(_, event, ...)
  -- chat texts can be "secret" in combat on newer clients: nothing to read then
  if (event:find("^CHAT_MSG") or event == "UI_ERROR_MESSAGE") and FLT.IsSecret(...) then return end
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
  elseif event == "CHAT_MSG_SYSTEM" then
    onSystemMessage(...)
  elseif event == "CHAT_MSG_ADDON" then
    onAddonMessage(...)
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    schedule(3) -- party members' quest data needs a moment after loading
  elseif event == "GROUP_ROSTER_UPDATE" then
    local size = #groupUnits()
    local joined = size > lastGroupSize
    lastGroupSize = size
    if joined then
      autoShown = nil; dismissedSignature = nil
      if currentDungeon and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, "QR", "PARTY")
      end
    end
    schedule(2)
  else
    if currentDungeon then schedule(1) end
  end
end
ev:SetScript("OnEvent", function(...) FLT.SafeCall("QuestShare", onEventSafe, ...) end)
