local _, FLT = ...
local UI = FLT.UI

-- Boss portraits ----------------------------------------------------------------
-- Order: an icon set in the data (customIcon), the display ID from the data,
-- a display ID learned in game (target / mouseover / nameplate, see below),
-- otherwise a question mark until the boss has been seen once.

local UNKNOWN_PORTRAIT = "Interface\\Icons\\INV_Misc_QuestionMark"

-- account-wide store for what we learn about bosses in game
local function bossStore()
  if type(OneForAllDB) ~= "table" then return nil end
  local s = OneForAllDB.bossInfo
  if type(s) ~= "table" then s = {}; OneForAllDB.bossInfo = s end
  return s
end
local function learned(npcID, field)
  local s = npcID and bossStore()
  return s and s[npcID] and s[npcID][field]
end
local function remember(npcID, field, value)
  local s = npcID and value ~= nil and bossStore()
  if not s then return end
  s[npcID] = s[npcID] or {}
  s[npcID][field] = value
end

local function showDisplay(tex, displayID)
  if type(displayID) ~= "number" or displayID <= 0 or type(SetPortraitTextureFromCreatureDisplayID) ~= "function" then
    return false
  end
  FLT.SetTex(tex, nil)
  if not pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID) then return false end
  local t = tex:GetTexture()
  return t ~= nil and t ~= 0 and t ~= ""
end

-- where the shown portrait came from (/ofa portraits)
local usedSource = {}
local function note(dungeon, boss, source, detail)
  usedSource[(dungeon and dungeon.name or "?") .. " / " .. (boss and boss.name or "?")] = detail and (source .. " (" .. tostring(detail) .. ")") or source
end
function FLT:PrintPortraitDebug()
  local list = {}
  for k, v in pairs(usedSource) do list[#list + 1] = k .. " -> " .. v end
  if #list == 0 then self.Msg("No boss portraits shown yet - open a dungeon first."); return end
  table.sort(list)
  self.Msg("Boss portraits (last shown):")
  for _, line in ipairs(list) do self.Msg(line) end
end

-- textures currently waiting for a boss to be seen in game, by NPC ID
local waiting = {}

local function setBossPortrait(tex, dungeon, boss)
  if not tex then return false end
  tex:SetTexCoord(0.04, 0.96, 0.04, 0.96)
  tex._ofaNpc = nil
  local npc = boss and boss.npcID
  if boss and boss.customIcon then
    FLT.SetTex(tex, boss.customIcon)
    note(dungeon, boss, "icon", boss.customIcon)
    return true
  end
  local id = boss and boss.displayID
  if showDisplay(tex, id) then note(dungeon, boss, "data", id); return true end
  id = learned(npc, "displayID")
  if showDisplay(tex, id) then note(dungeon, boss, "seen in game", id); return true end
  FLT.SetTex(tex, UNKNOWN_PORTRAIT)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if npc then
    tex._ofaNpc = npc
    waiting[npc] = waiting[npc] or setmetatable({}, { __mode = "k" })
    waiting[npc][tex] = { dungeon = dungeon, boss = boss }
  end
  note(dungeon, boss, "unknown")
  return false
end
UI.setBossPortrait = setBossPortrait

local function portraitLearned(npc, displayID)
  local list = waiting[npc]
  waiting[npc] = nil
  if not list then return end
  for tex, info in pairs(list) do
    if tex._ofaNpc == npc then setBossPortrait(tex, info.dungeon, info.boss) end
  end
end

-- Boss level: static table (QuestieDB) or learned in game.
function FLT:GetBossLevel(boss)
  if not boss then return nil end
  local B = FLT.BOSS_LEVELS
  local lv = B and ((boss.npcID and B[boss.npcID]) or (boss.name and B[boss.name]))
  if lv then return lv end
  local lv2 = learned(boss.npcID, "level")
  if lv2 then return (lv2 < 0) and "??" or tostring(lv2) end
  return nil
end

-- Creature type (Humanoid, Beast, ...) and rank (Elite / Rare / Summoned).
function FLT:GetBossType(boss)
  if not boss then return nil end
  local t = boss.npcID and FLT.BOSS_TYPES and FLT.BOSS_TYPES[boss.npcID]
  if t then return t end
  return learned(boss.npcID, "ctype")
end
function FLT:GetBossRank(boss)
  if not boss then return nil end
  if boss.rare then return "Rare" end
  if boss.npcID and FLT.BOSS_SUMMONED and FLT.BOSS_SUMMONED[boss.npcID] then return "Summoned" end
  return "Elite"
end

-- Learn level and display ID of dungeon bosses when you target or mouse over
-- them (or their nameplate appears). Updates portraits that are on screen.
do
  local bossNpc
  local function buildBossSet()
    bossNpc = {}
    for _, d in ipairs(FLT.DUNGEONS or {}) do
      for _, b in ipairs(d.bosses or {}) do if b.npcID then bossNpc[b.npcID] = true end end
    end
  end
  local probe
  local function learn(unit)
    if not (UnitExists and UnitExists(unit) and UnitGUID) then return end
    local guid = UnitGUID(unit)
    if not guid or (FLT.IsSecret and FLT.IsSecret(guid)) then return end -- hidden in combat on newer clients
    local kind, _, _, _, _, id = strsplit("-", guid)
    id = tonumber(id)
    if kind ~= "Creature" or not id then return end
    if not bossNpc then buildBossSet() end
    if not bossNpc[id] then return end
    if UnitLevel then local lv = UnitLevel(unit); if not (FLT.IsSecret and FLT.IsSecret(lv)) then remember(id, "level", lv) end end
    if UnitCreatureType then
      local ok, ctype = pcall(UnitCreatureType, unit)
      if ok and type(ctype) == "string" and ctype ~= "" and not (issecretvalue and issecretvalue(ctype)) then remember(id, "ctype", ctype) end
    end
    if learned(id, "displayID") then return end
    probe = probe or CreateFrame("PlayerModel", nil, UIParent)
    probe:SetSize(1, 1); probe:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)
    probe:Show()
    local ok = pcall(probe.SetUnit, probe, unit)
    if not ok then return end
    local tries = 0
    local function check()
      tries = tries + 1
      local okd, display = pcall(probe.GetDisplayInfo, probe)
      if okd and type(display) == "number" and display > 0 then
        remember(id, "displayID", display)
        portraitLearned(id, display)
        probe:Hide()
      elseif tries < 10 and C_Timer and C_Timer.After then
        C_Timer.After(0.2, check)
      else
        probe:Hide()
      end
    end
    check()
  end
  local ev = CreateFrame("Frame")
  for _, e in ipairs({"PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED"}) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event, unit)
    local u = (event == "PLAYER_TARGET_CHANGED" and "target") or (event == "UPDATE_MOUSEOVER_UNIT" and "mouseover") or unit
    if FLT.SafeCall then FLT.SafeCall("BossLearn", learn, u) else pcall(learn, u) end
  end)
end


-- Framed portraits ---------------------------------------------------------------
-- Boss: gold frame that runs into a point at the bottom right (like the player
-- frame) with an optional level badge. Pets: plain round gold ring; pet
-- abilities: silver ring with gems. Geometry matches the 256px design files.
local ASSET = "Interface\\AddOns\\OneForAll\\Assets\\"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function roundMask(owner, tex)
  if tex.AddMaskTexture and owner.CreateMaskTexture then
    local m = owner:CreateMaskTexture()
    FLT.SetTex(m, MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(tex)
    tex:AddMaskTexture(m)
  end
end

-- Returns a holder frame with .portrait (texture to fill), .badge/.level.
-- plain: a simple gold circle instead of the ornate ring
-- (boss lists and map pins; the big portrait of the selected boss keeps the ring)
function UI.CreateBossFrame(parent, size, withBadge, plain)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  if plain then
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"); bg:SetVertexColor(0.05, 0.05, 0.06, 1)
    local portrait = f:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 2, -2); portrait:SetPoint("BOTTOMRIGHT", -2, 2)
    roundMask(f, portrait)
    local ring = f:CreateTexture(nil, "OVERLAY", nil, 1); ring:SetAllPoints(); FLT.SetTex(ring, ASSET .. "ring_plain")
    ring:SetVertexColor(FLT.SkinC(0.86, 0.66, 0.28, 1))
    f.portrait, f.ring = portrait, ring
    return f
  end
  local k = size / 256
  -- ornate gold ring (frame_boss2): portrait centred, slightly under the ring
  local r = 86 * k
  local portrait = f:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(2 * r, 2 * r); portrait:SetPoint("CENTER", f, "TOPLEFT", 128 * k, -128 * k)
  roundMask(f, portrait)
  local frame = f:CreateTexture(nil, "OVERLAY", nil, 1)
  frame:SetAllPoints(); FLT.SetTex(frame, ASSET .. "frame_boss2")
  f.portrait = portrait
  if withBadge then
    local bs = 86 * k
    local badge = f:CreateTexture(nil, "OVERLAY", nil, 3)
    badge:SetSize(bs, bs); badge:SetPoint("CENTER", f, "TOPLEFT", 52 * k, -206 * k)
    FLT.SetTex(badge, ASSET .. "frame_badge")
    local lv = FLT.NewFS(f, nil, "OVERLAY", size >= 64 and "GameFontHighlight" or "GameFontHighlightSmall")
    lv:SetPoint("CENTER", badge, "CENTER", 0, 0); lv:SetTextColor(FLT.SkinC(0.96, 0.94, 0.90))
    f.badge, f.level = badge, lv
    f.SetLevel = function(self, text)
      if text and text ~= "" then badge:Show(); lv:SetText(text); lv:Show() else badge:Hide(); lv:Hide() end
    end
  end
  return f
end

-- kind: "gold" (pet families) or "silver" (pet abilities).
function UI.CreateRingFrame(parent, size, kind)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  local d = size * 202 / 256
  local portrait = f:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(d, d); portrait:SetPoint("CENTER")
  roundMask(f, portrait)
  local ring = f:CreateTexture(nil, "OVERLAY", nil, 1)
  ring:SetAllPoints(); FLT.SetTex(ring, ASSET .. (kind == "silver" and "ring_silver" or "ring_gold"))
  f.portrait = portrait
  return f
end

-- Square icon with rounded corners and a dark border, like action bar spells
-- (uses the same mask/border artwork as the talent planner buttons).
function UI.CreateActionFrame(parent, size)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  local inset = math.floor(size * 0.07 + 0.5)
  local shadow = f:CreateTexture(nil, "BACKGROUND")
  FLT.SetTex(shadow, ASSET .. "talent_button_border")
  shadow:SetPoint("TOPLEFT", 1, -2); shadow:SetPoint("BOTTOMRIGHT", 2, -2)
  shadow:SetVertexColor(FLT.SkinC(0, 0, 0, 0.7))
  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", inset, -inset); icon:SetPoint("BOTTOMRIGHT", -inset, inset)
  if icon.AddMaskTexture and f.CreateMaskTexture then
    local m = f:CreateMaskTexture()
    FLT.SetTex(m, ASSET .. "talent_icon_mask"); m:SetAllPoints(icon)
    icon:AddMaskTexture(m)
  end
  local border = f:CreateTexture(nil, "OVERLAY", nil, 1)
  FLT.SetTex(border, ASSET .. "talent_button_border"); border:SetAllPoints()
  border:SetVertexColor(FLT.SkinC(0.16, 0.15, 0.14, 1))
  f.portrait = icon
  return f
end
