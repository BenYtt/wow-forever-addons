local _, FLT = ...

-- Quest marks on nameplates (6.0.2, user 31.10.; idea from ForeverQuestMark by Ugge Zen, MIT - own code, nothing
-- copied). A sword when you must kill the unit for a quest, a bag when it drops a quest item, with the progress
-- ("3/10"). The game itself lists the quest objectives in a unit's tooltip data (C_TooltipInfo.GetUnit, lines of type
-- QuestObjective); "slain" / "killed" = kill, anything else = loot. Done objectives (10/10) show nothing.
-- Inside instances the game keeps that data secret: no marks there for now (no guessing, user 31.10.);
-- /ofa questmarks test shows what the game gives away there.
-- Switch qol.questMarks (off by default), position qol.questMarkPos = "left" / "top" / "right".
-- Lean: the events are only registered while the switch is on; a plate is looked at when it appears and again
-- (all shown plates) after the quest log changed, debounced.

local QM = {}
FLT.QuestMarks = QM
QM.POS_OPTIONS = { { key = "left", label = "Left" }, { key = "topleft", label = "Top left" }, { key = "top", label = "Top" },
  { key = "topright", label = "Top right" }, { key = "right", label = "Right" } } -- top left / right: user 31.10.

local KILL_ATLAS, LOOT_ATLAS = "Crosshair_Attack_32", "Crosshair_pickup_32"
local KILL_TEX, LOOT_TEX = "Interface\\Cursor\\Attack", "Interface\\Cursor\\Pickup" -- when the client has no atlas

local function Q() return FLT.QoL end
local function on() return Q() and Q().Get("questMarks") end

local function setIcon(tex, kill)
  local atlas = kill and KILL_ATLAS or LOOT_ATLAS
  if tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
    tex:SetAtlas(atlas)
  else
    tex:SetTexture(kill and KILL_TEX or LOOT_TEX)
  end
end

-- Kill or loot, in every language (user 01.11.: another addon had trouble with non-English clients): the quest log
-- knows each objective's type ("monster" = kill, "item" = loot). Its texts, without numbers and signs, are matched
-- with the tooltip line; only when nothing matches, the English words "slain" / "killed" decide.
local kinds = {} -- normalised objective text -> true (kill) / false (loot)
local function norm(t) return (t:lower():gsub("[%d%p%s]", "")) end
local function readLog()
  wipe(kinds)
  local function add(text, kind)
    if type(text) == "string" and not FLT.IsSecret(text) and kind then kinds[norm(text)] = (kind == "monster") end
  end
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and info.questID then
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do add(o.text, o.type) end
      end
    end
  elseif GetNumQuestLogEntries and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
    for i = 1, GetNumQuestLogEntries() or 0 do
      for j = 1, GetNumQuestLeaderBoards(i) or 0 do add(GetQuestLogLeaderBoard(j, i)) end
    end
  end
end

-- Loot quests (6.0.3, user 02.11.): the Forever mob tooltip lists kill objectives but not quest items (no mark on
-- Plainstriders for "The Hunt Begins", Platynator neither). Data/QuestDrops.lua (QuestieDB) says which mob drops a
-- quest item of which quest; the quest log gives the progress. Mob ID from the unit's GUID (readable outside instances).
local function npcID(unit)
  local g = UnitGUID and UnitGUID(unit)
  if type(g) ~= "string" or FLT.IsSecret(g) then return end
  local kind, id = g:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if kind == "Creature" then return tonumber(id) end
end
local function inLog(qid)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return (C_QuestLog.GetLogIndexForQuestID(qid) or 0) > 0 end
  return GetQuestLogIndexByID and (GetQuestLogIndexByID(qid) or 0) > 0
end
local function lootObjective(unit)
  local list = FLT.QUEST_DROPS and FLT.QUEST_DROPS[npcID(unit) or 0]
  if not list or not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return end
  for qid, item in list:gmatch("(%d+):(%d+)") do
    qid = tonumber(qid)
    if inLog(qid) then
      local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(tonumber(item))
      for _, o in ipairs(C_QuestLog.GetQuestObjectives(qid) or {}) do
        local text = o.text
        if o.type == "item" and not o.finished and type(text) == "string" and not FLT.IsSecret(text)
          and (not name or text:find(name, 1, true)) then
          return false, (o.numFulfilled or 0) .. "/" .. (o.numRequired or 0)
        end
      end
    end
  end
end

-- the first objective of this unit that is not done yet: kill (true/false), "3/10"
local function objective(unit)
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit and Enum and Enum.TooltipDataLineType) then return lootObjective(unit) end
  local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return lootObjective(unit) end
  local want = Enum.TooltipDataLineType.QuestObjective
  for _, line in ipairs(data.lines) do
    if TooltipUtil and TooltipUtil.SurfaceArgs and line.leftText == nil then pcall(TooltipUtil.SurfaceArgs, line) end
    local text = line.leftText
    if line.type == want and type(text) == "string" and not FLT.IsSecret(text) then
      local have, need = text:match("(%d+)%s*/%s*(%d+)")
      have, need = tonumber(have), tonumber(need)
      if have and need and have < need then
        local kill = kinds[norm(text)]
        if kill == nil then
          local lower = text:lower()
          kill = (lower:find("slain", 1, true) or lower:find("killed", 1, true)) and true or false
        end
        return kill, have .. "/" .. need
      end
    end
  end
  return lootObjective(unit)
end

local function markFor(plate)
  local m = plate.ofaQuestMark
  if m then return m end
  m = CreateFrame("Frame", nil, plate); m:SetSize(20, 20); m:SetFrameLevel((plate:GetFrameLevel() or 1) + 10)
  m.icon = m:CreateTexture(nil, "OVERLAY"); m.icon:SetAllPoints()
  m.text = FLT.NewFS(m, nil, "OVERLAY", "GameFontHighlightSmall")
  do local font, _, flags = m.text:GetFont(); if font then m.text:SetFont(font, 10, "OUTLINE") end end
  m:Hide()
  plate.ofaQuestMark = m
  return m
end

-- the level box right of the health bar (Classic plates): "Right" goes beyond it, it covered the box (beta8)
local function levelBox(uf)
  if not uf then return end
  for _, k in ipairs({ "LevelFrame", "levelFrame", "LevelText", "levelText" }) do
    local f = uf[k]
    if type(f) == "table" and f.IsShown and f:IsShown() then return f end
  end
end
local function place(plate, m)
  local uf = plate.UnitFrame
  local bar = uf and (uf.healthBar or uf.HealthBar) or plate
  local pos = Q().Get("questMarkPos") or "right"
  m:ClearAllPoints(); m.text:ClearAllPoints()
  if pos == "right" then
    local lv = levelBox(uf)
    if lv then m:SetPoint("LEFT", lv, "RIGHT", 3, 0) else m:SetPoint("LEFT", bar, "RIGHT", 30, 0) end
    m.text:SetPoint("LEFT", m, "RIGHT", 1, 0)
  elseif pos == "top" then
    m:SetPoint("BOTTOM", bar, "TOP", 0, 16); m.text:SetPoint("LEFT", m, "RIGHT", 1, 0)
  elseif pos == "topleft" then
    m:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 16); m.text:SetPoint("LEFT", m, "RIGHT", 1, 0)
  elseif pos == "topright" then
    m:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 16); m.text:SetPoint("RIGHT", m, "LEFT", -1, 0)
  else
    m:SetPoint("RIGHT", bar, "LEFT", -3, 0); m.text:SetPoint("RIGHT", m, "LEFT", -1, 0)
  end
end

local function update(unit)
  local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
  if not plate then return end
  local kill, progress
  if on() and not (IsInInstance and IsInInstance()) then kill, progress = objective(unit) end
  if kill == nil then
    if plate.ofaQuestMark then plate.ofaQuestMark:Hide() end
    return
  end
  local m = markFor(plate)
  place(plate, m); setIcon(m.icon, kill); m.text:SetText(progress); m:Show()
end

local function updateAll()
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  if on() then readLog() end
  for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if unit then update(unit) elseif plate.ofaQuestMark then plate.ofaQuestMark:Hide() end
  end
end

local ev = CreateFrame("Frame")
local pending = false
local function later() -- the quest log fires in bursts
  if pending then return end
  pending = true
  C_Timer.After(0.3, function() pending = false; updateAll() end)
end
local EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }
ev:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then update(unit)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
    if plate and plate.ofaQuestMark then plate.ofaQuestMark:Hide() end
  else later() end
end)
-- switch on / off: events only while it is on
function QM.Apply()
  for _, e in ipairs(EVENTS) do
    if on() then pcall(ev.RegisterEvent, ev, e) else pcall(ev.UnregisterEvent, ev, e) end
  end
  updateAll()
end
QM.UpdateAll = updateAll

-- /ofa questmarks test: what the game tells us about your target (in a dungeon: is anything readable at all?)
function QM.Test()
  local msg = FLT.Msg or print
  if not (UnitExists and UnitExists("target")) then msg("Quest marks test: target a mob first."); return end
  local guid = UnitGUID and UnitGUID("target")
  local inInst = IsInInstance and IsInInstance()
  msg(string.format("Quest marks test (%s): GUID %s", inInst and "inside an instance" or "open world",
    guid == nil and "missing" or (FLT.IsSecret(guid) and "secret" or ("readable (" .. tostring(guid) .. ")"))))
  local ok, data = false, nil
  if C_TooltipInfo and C_TooltipInfo.GetUnit then ok, data = pcall(C_TooltipInfo.GetUnit, "target") end
  if not ok or type(data) ~= "table" then msg("Tooltip data: none"); return end
  local n, secret, quest = 0, 0, 0
  local want = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective
  for _, line in ipairs(data.lines or {}) do
    n = n + 1
    if FLT.IsSecret(line.leftText) then secret = secret + 1
    elseif line.type == want then quest = quest + 1; msg("  objective: " .. tostring(line.leftText)) end
  end
  msg(string.format("Tooltip data: %d lines, %d secret, %d quest objectives", n, secret, quest))
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() if on() then QM.Apply() end end)
if FLT.QoL and FLT.QoL.On then
  FLT.QoL.On("questMarks", function() QM.Apply() end)
  FLT.QoL.On("questMarkPos", function() updateAll() end)
end
