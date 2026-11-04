-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Spell range from the action bars: the client reports when an action slot's
-- spell goes in or out of range of the target (ACTION_RANGE_CHECK_UPDATE, after
-- C_ActionBar.EnableActionRangeCheck), so no polling is needed. Its payload is
-- not secret in combat on this client (checked in game).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame = Private.TimedAPI("ActionRange")

local NUM_SLOTS = 180
-- slot -> {inRange = bool|nil, checks = bool}, for slots a watched spell sits in.
local slots = {}
-- Watched spells: key (spell name, or "id:<spellID>" for exact) -> {slots = {...}, exact = bool, spell = name|id}
local watched = {}
local frame

local function Secret(value) return issecretvalue and issecretvalue(value) end

-- The current range state of one slot, read directly (nil when no target).
local function Seed(slot)
  local inRange = C_ActionBar.IsActionInRange(slot)
  if Secret(inRange) then inRange = nil end
  slots[slot] = slots[slot] or {}
  slots[slot].inRange = inRange
  slots[slot].checks = inRange ~= nil
end

-- Finds every slot holding the spell. The client's lookup wants the base spell
-- ID; a bar can hold any rank, so a name match over the slots covers those.
local function FindSlots(entry)
  local found, seen = {}, {}
  local wantedID = tonumber(entry.spell)
  local wantedName = type(entry.spell) == "string" and entry.spell or (wantedID and Private.ExecEnv.GetSpellName(wantedID))
  if wantedID and C_ActionBar.FindSpellActionButtons then
    for _, slot in ipairs(C_ActionBar.FindSpellActionButtons(wantedID) or {}) do
      if not Secret(slot) and not seen[slot] then seen[slot] = true; found[#found + 1] = slot end
    end
  end
  if not entry.exact and wantedName then
    for slot = 1, NUM_SLOTS do
      if not seen[slot] then
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and not Secret(id) and Private.ExecEnv.GetSpellName(id) == wantedName then
          seen[slot] = true; found[#found + 1] = slot
        end
      end
    end
  end
  return found
end

local function Refresh()
  for _, entry in pairs(watched) do
    entry.slots = FindSlots(entry)
    for _, slot in ipairs(entry.slots) do
      if C_ActionBar.EnableActionRangeCheck then C_ActionBar.EnableActionRangeCheck(slot, true) end
      Seed(slot)
    end
  end
  Private.ScanEvents("FA_ACTION_RANGE_UPDATE")
end

local function OnEvent(_, event, slot, inRange, checks)
  if event == "ACTION_RANGE_CHECK_UPDATE" then
    if Secret(slot) or Secret(inRange) or Secret(checks) or not slots[slot] then return end
    if checks then slots[slot].inRange = inRange == true else slots[slot].inRange = nil end
    slots[slot].checks = checks == true
    Private.ScanEvents("FA_ACTION_RANGE_UPDATE")
  elseif event == "PLAYER_TARGET_CHANGED" then
    -- The client reports changes; a new target is read once so the first state is right.
    for s in pairs(slots) do Seed(s) end
    Private.ScanEvents("FA_ACTION_RANGE_UPDATE")
  else
    Refresh()
  end
end

local function Key(spell, exact)
  if exact then return "id:" .. tostring(tonumber(spell) or spell) end
  return type(spell) == "number" and (Private.ExecEnv.GetSpellName(spell) or tostring(spell)) or tostring(spell)
end

function Private.ExecEnv.WatchActionRange(spell, exact)
  if spell == nil or spell == "" then return end
  if not frame then
    frame = CreateFrame("Frame")
    for _, event in ipairs({"ACTION_RANGE_CHECK_UPDATE", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
      "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED"}) do
      frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", OnEvent)
  end
  local key = Key(spell, exact)
  if not watched[key] then
    watched[key] = {spell = spell, exact = exact == true, slots = {}}
    Refresh()
  end
end

-- The spell's range: in range (true/false), whether a check was possible
-- (false without a target), the slot used, and the spell's name and icon.
-- Nothing is returned for a spell that is on no action bar.
function Private.ExecEnv.GetActionRange(spell, exact)
  local entry = watched[Key(spell, exact)]
  if not entry or #entry.slots == 0 then return end
  local inRange, checks, used = nil, false, entry.slots[1]
  for _, slot in ipairs(entry.slots) do
    local state = slots[slot]
    if state and state.checks then inRange, checks, used = state.inRange, true, slot; break end
  end
  local id = tonumber(spell)
  if not id then
    local actionType, actionID = GetActionInfo(used)
    if actionType == "spell" and not Secret(actionID) then id = actionID end
  end
  local name, _, icon = Private.ExecEnv.GetSpellInfo(id or spell)
  return inRange, checks, used, name, icon
end
