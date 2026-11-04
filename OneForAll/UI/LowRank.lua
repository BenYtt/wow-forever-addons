local _, FLT = ...
local UI = FLT.UI

-- Quality of Life: "Check low spell ranks" (switch "lowRank", on by default since 5.6.1).
-- Finds spells on the action bars whose rank is lower than a rank you already
-- know (spellbook) and offers to put the highest rank there ("Update all").
-- Not right away: after a class trainer visit the check waits until the trainer
-- window is closed (you usually learn several spells), otherwise a few seconds
-- after the last spell was learned. Runs out of combat only.
-- Spells you keep low on purpose (downranking): "Keep" puts that rank on a
-- list (OneForAllDB.qol.lowRankKeep[spellID] = true), managed in the tab.
-- Macros are not checked, only spells placed on the bars directly.

local LR = {}
FLT.LowRank = LR

local NUM_SLOTS = 120
local MAX_ROWS = 8
local LEARN_DELAY, LOGIN_DELAY, TRAINER_DELAY = 4, 8, 0.8

local function Q() return FLT.QoL end
local function enabled() return Q() and Q().Get("lowRank") and true or false end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function msg(text) if FLT.Msg then FLT.Msg(text) end end

local function keepList()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.qol = OneForAllDB.qol or {}
  OneForAllDB.qol.lowRankKeep = OneForAllDB.qol.lowRankKeep or {}
  return OneForAllDB.qol.lowRankKeep
end

local function rankOf(sub)
  return tonumber(type(sub) == "string" and sub:match("(%d+)") or nil)
end

local function spellNameRank(id)
  local name, sub
  if C_Spell and C_Spell.GetSpellName then pcall(function() name = C_Spell.GetSpellName(id) end) end
  if not name and GetSpellInfo then pcall(function() name = GetSpellInfo(id) end) end
  if C_Spell and C_Spell.GetSpellSubtext then pcall(function() sub = C_Spell.GetSpellSubtext(id) end) end
  if not sub and GetSpellSubtext then pcall(function() sub = GetSpellSubtext(id) end) end
  return name, rankOf(sub)
end

local function spellIcon(id)
  local tex
  if C_Spell and C_Spell.GetSpellTexture then pcall(function() tex = C_Spell.GetSpellTexture(id) end) end
  if not tex and GetSpellTexture then pcall(function() tex = GetSpellTexture(id) end) end
  return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- highest known rank per spell name from the spellbook: name -> { rank =, id = }
local function bestRanks()
  local best = {}
  local function note(name, sub, id)
    local r = rankOf(sub)
    id = tonumber(id)
    if not name or not r or not id then return end
    if FLT.IsSecret(name, id) then return end
    if not best[name] or best[name].rank < r then best[name] = { rank = r, id = id } end
  end
  local book = BOOKTYPE_SPELL or "spell"
  if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    for tab = 1, GetNumSpellTabs() do
      local _, _, offset, num = GetSpellTabInfo(tab)
      for i = (offset or 0) + 1, (offset or 0) + (num or 0) do
        local name, sub = GetSpellBookItemName(i, book)
        local id
        if GetSpellBookItemInfo then id = select(2, GetSpellBookItemInfo(i, book)) end
        note(name, sub, id)
      end
    end
  elseif C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
      if li then
        for i = (li.itemIndexOffset or 0) + 1, (li.itemIndexOffset or 0) + (li.numSpellBookItems or 0) do
          local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
          if type(info) == "table" then note(info.name, info.subName, info.spellID or info.actionID) end
        end
      end
    end
  end
  return best
end

-- low ranks on the bars, grouped by spell: { id, name, rank, newID, newRank, slots = {..} }
function LR.Scan()
  local out, byID = {}, {}
  if not GetActionInfo then return out end
  local best, keep = bestRanks(), keepList()
  for slot = 1, NUM_SLOTS do
    local kind, id = GetActionInfo(slot)
    if kind == "spell" and id and not FLT.IsSecret(kind, id) and not keep[id] then
      local name, r = spellNameRank(id)
      local b = name and best[name]
      if r and b and b.rank > r and b.id ~= id then
        local e = byID[id]
        if not e then
          e = { id = id, name = name, rank = r, newID = b.id, newRank = b.rank, slots = {} }
          byID[id] = e; out[#out + 1] = e
        end
        e.slots[#e.slots + 1] = slot
      end
    end
  end
  table.sort(out, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.rank < b.rank end)
  return out
end

-- put the highest rank into the slots (out of combat). Returns how many slots changed.
local function pickup(id)
  if C_Spell and C_Spell.PickupSpell then return pcall(C_Spell.PickupSpell, id) end
  if PickupSpell then return pcall(PickupSpell, id) end
  return false
end
local function update(e)
  if inCombat() or not PlaceAction then return 0 end
  local n = 0
  for _, slot in ipairs(e.slots) do
    if ClearCursor then ClearCursor() end
    if pickup(e.newID) and (not GetCursorInfo or GetCursorInfo()) then
      pcall(PlaceAction, slot)
      if ClearCursor then ClearCursor() end -- the old rank lands on the cursor: drop it
      local _, now = GetActionInfo(slot)
      if now == e.newID then n = n + 1 end
    end
  end
  if ClearCursor then ClearCursor() end
  return n
end

-- ---------------------------------------------------------------------------
-- Popup
-- ---------------------------------------------------------------------------
local popup, current = nil, {}
local seen = {} -- this session: "id>newID" already shown (closing the popup = not again)

local function key(e) return e.id .. ">" .. e.newID end

local function fill()
  local f = popup
  for _, r in ipairs(f.rows) do r:Hide() end
  local y = -58
  for i, e in ipairs(current) do
    if i > MAX_ROWS then break end
    local r = f.rows[i]
    if not r then
      r = CreateFrame("Frame", nil, f); r:SetSize(f:GetWidth() - 36, 30)
      r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(24, 24); r.icon:SetPoint("LEFT", 2, 0); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 34, 0); r.text:SetJustifyH("LEFT")
      r.keep = UI.GoldButton(r, "Keep", 64, 20, nil, 11); r.keep:SetPoint("RIGHT", 0, 0)
      r.keep:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Keep this rank", 1, 0.82, 0)
        GameTooltip:AddLine("For spells you use in a low rank on purpose. This rank is not reported again; Quality of Life > Spells lists the kept ranks.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      r.keep:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:EnableMouse(true)
      r:SetScript("OnEnter", function(self)
        if not self.e then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if not pcall(GameTooltip.SetSpellByID, GameTooltip, self.e.newID) then GameTooltip:SetText(self.e.name) end
        GameTooltip:Show()
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.rows[i] = r
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 18, y); y = y - 32
    r.e = e
    r.icon:SetTexture(spellIcon(e.newID))
    local slots = #e.slots > 1 and ("  |cff9d9d9d(" .. #e.slots .. " buttons)|r") or ""
    r.text:SetText(e.name .. "   |cff9d9d9dRank " .. e.rank .. "|r  >  " .. FLT.SkinHex("ffd35a") .. "Rank " .. e.newRank .. "|r" .. slots)
    r.keep:SetScript("OnClick", function()
      keepList()[e.id] = true
      LR.Check(true)
    end)
    r:Show()
  end
  local more = #current - MAX_ROWS
  f.more:SetText(more > 0 and ("+ " .. more .. " more") or "")
  f:SetHeight(-y + 58)
end

local function createPopup()
  local f = CreateFrame("Frame", "OneForAllLowRank", UIParent)
  f:SetSize(440, 200); f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  UI.FramedPanel(f)
  for _, t in ipairs(UI.OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 18, -16)
  title:SetText("Low spell ranks"); title:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
  local sub = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); sub:SetPoint("TOPLEFT", 18, -38)
  sub:SetText("These action buttons use a lower rank than you know."); sub:SetTextColor(FLT.SkinC(0.80, 0.77, 0.70))
  local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)
  f.rows = {}
  f.more = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); f.more:SetPoint("BOTTOMLEFT", 20, 22)
  local upd = UI.GoldButton(f, "Update all", 120, 24, nil, 12); upd:SetPoint("BOTTOMRIGHT", -18, 16)
  local later = UI.GoldButton(f, "Later", 90, 24, nil, 12); later:SetPoint("RIGHT", upd, "LEFT", -8, 0)
  upd:SetScript("OnClick", function()
    if inCombat() then msg("Spells can be updated after combat."); return end
    local n = 0
    for _, e in ipairs(current) do n = n + update(e) end
    if n > 0 then msg(n == 1 and "1 action button updated to the highest rank." or (n .. " action buttons updated to the highest rank.")) end
    LR.Check(true)
  end)
  upd:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Update all", 1, 0.82, 0)
    GameTooltip:AddLine("Puts the highest rank you know on these buttons (same place, same key).", 1, 1, 1, true); GameTooltip:Show()
  end)
  upd:SetScript("OnLeave", function() GameTooltip:Hide() end)
  later:SetScript("OnClick", function() f:Hide() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllLowRank") end
  f:Hide()
  return f
end

-- force: show the popup even for entries shown before (button "Check now", after Keep/Update)
function LR.Check(force)
  if inCombat() then LR.pending = true; return end
  LR.pending = false
  current = LR.Scan()
  if #current == 0 then
    if popup and popup:IsShown() then popup:Hide() end
    if force == "button" then msg("No low spell ranks on your action bars.") end
    return
  end
  local new = false
  for _, e in ipairs(current) do if not seen[key(e)] then new = true end end
  if not new and not force and not (popup and popup:IsShown()) then return end
  for _, e in ipairs(current) do seen[key(e)] = true end
  if not popup then popup = createPopup() end
  fill()
  popup:Show()
end

-- ---------------------------------------------------------------------------
-- Timing
-- ---------------------------------------------------------------------------
local trainerOpen, token = false, 0
local function later(delay)
  token = token + 1
  local my = token
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function() if my == token and enabled() and not trainerOpen then LR.Check() end end)
  elseif enabled() and not trainerOpen then LR.Check() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "TRAINER_SHOW", "TRAINER_CLOSED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
  "PLAYER_LEVEL_UP", "ACTIONBAR_SLOT_CHANGED", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local learned = false
local function onEvent(_, event)
  if event == "TRAINER_SHOW" then
    -- profession trainers do not count
    trainerOpen = not (IsTradeskillTrainer and IsTradeskillTrainer())
    return
  end
  if event == "TRAINER_CLOSED" then
    if trainerOpen then trainerOpen = false; if learned then learned = false; later(TRAINER_DELAY) end end
    return
  end
  if not enabled() then return end
  if event == "PLAYER_LOGIN" then later(LOGIN_DELAY)
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_LEVEL_UP" then
    learned = true
    if not trainerOpen then later(LEARN_DELAY) end
  elseif event == "ACTIONBAR_SLOT_CHANGED" then
    -- keep an open list up to date (e.g. a button changed by hand)
    if popup and popup:IsShown() and not inCombat() then later(0.3) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if LR.pending then later(1) end
  end
end
ev:SetScript("OnEvent", function(...) FLT.SafeCall("LowRank", onEvent, ...) end)
if FLT.QoL and FLT.QoL.On then FLT.QoL.On("lowRank", function(on) if on then later(0.5) elseif popup then popup:Hide() end end) end

-- kept ranks for the QoL tab: sorted { id, label }
function LR.GetKept()
  local out = {}
  for id in pairs(keepList()) do
    id = tonumber(id)
    if id then
      local name, r = spellNameRank(id)
      out[#out + 1] = { key = id, label = (name or ("Spell " .. id)) .. (r and ("  (Rank " .. r .. ")") or "") }
    end
  end
  table.sort(out, function(a, b) return a.label < b.label end)
  return out
end
function LR.RemoveKept(id) keepList()[id] = nil end
function LR.ClearKept()
  if type(OneForAllDB) == "table" and OneForAllDB.qol then OneForAllDB.qol.lowRankKeep = {} end
end
-- test hooks
LR._bestRanks, LR._update, LR._onEvent = bestRanks, update, onEvent
LR._state = function() return popup ~= nil and popup._shown ~= false, #current end
