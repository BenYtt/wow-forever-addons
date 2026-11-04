-- Modified for ForeverAuras
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraLinkedText")
local Display = Private.BlizzardAuraDisplay

local active = setmetatable({}, {__mode = "k"})
local pending = setmetatable({}, {__mode = "k"})
-- Texts whose unit the trigger's filters leave out (see UpdateLinkedText).
local excluded = setmetatable({}, {__mode = "k"})

---@return string? kind "s" or "p"
---@return number? triggerIndex
function Display.LinkedTextKind(value, parentData)
  if type(value) ~= "string" or not parentData or type(parentData.triggers) ~= "table" then return end
  local index, kind = value:match("^%%(%d+)%.([ps])$")
  if not index then index, kind = value:match("^%%{(%d+)%.([ps])}$") end
  index = tonumber(index)
  local entry = index and parentData.triggers[index]
  local trigger = type(entry) == "table" and entry.trigger
  if not trigger or trigger.type ~= "secretAura" then return end
  if Display.Enabled(parentData) or not Display.IsSingleUnit(trigger) then return end
  return kind, index
end

local function SourceData(parentData, index)
  return setmetatable({progressSource = {index, ""}}, {__index = parentData})
end

local function Style(sub, native)
  pcall(Private.CDMAuraProgress.StyleText, sub, native)
end

-- ForeverAuras: the countdown's format comes from the element's Time Format
-- settings; bound at creation and again on a restyle (ResetLinkedText), so an
-- edited format or precision applies without a reload. The binding's key
-- tells a repeat of the same settings from a change.
local function Bind(native, config, index)
  local button = native.button
  if not button then return end
  local prefix = "text_text_format_" .. index .. "." .. native.kind .. "_"
  if native.kind == "p" then
    local format = config[prefix .. "time_format"]
    local key = table.concat({tostring(format), tostring(config[prefix .. "time_legacy_floor"]),
      tostring(config[prefix .. "time_dynamic_threshold"]), tostring(config[prefix .. "time_precision"])}, "|")
    if native.formatKey == key then return end
    native.formatKey = key
    local options
    if format ~= nil and format ~= -1 then
      options = {textFormatter = Private.GetDurationTextFormatter(config[prefix .. "time_legacy_floor"] and 0 or 99,
        config[prefix .. "time_dynamic_threshold"] or 3, config[prefix .. "time_precision"] or 1, format == -2, format)}
    end
    button:ClearDurationText()
    button:SetDurationText(native.text, options)
  elseif not native.formatKey then
    native.formatKey = "stacks"
    button:SetApplicationCount(native.text)
  end
end

local function Create(sub, kind, config, index)
  local native = {owner = sub, kind = kind}
  local container = CreateFrame("AuraContainer", nil, sub, "CustomAuraContainerTemplate")
  native.container = container
  container:SetEnabled(false)
  container:SetAllPoints(sub)
  container:SetFrameLevel(sub:GetFrameLevel())
  container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
  container:AddAuraSlot("Linked", "HELPFUL", {
    candidateFilters = {includeSpellIDs = {}},
    initializeFrame = function(button)
      native.button = button
      button:SetAllPoints(container)
      button:SetFrameLevel(container:GetFrameLevel())
      button:EnableMouse(false)
      native.text = button:CreateFontString(nil, "OVERLAY")
      native.text:SetFont(sub.text:GetFont())
      Style(sub, native)
      Bind(native, config, index)
    end,
  })
  TimedHookScript(sub, "OnHide", function() container:SetEnabled(false) end)
  TimedHookScript(sub, "OnShow", function() container:SetEnabled(native.wanted == true) end)
  return native
end

local function Disable(native)
  if native and native.wanted then
    native.wanted = false
    native.container:SetEnabled(false)
  end
end

function Display.HideLinkedText(sub)
  for _, native in pairs(sub.linkedTexts or {}) do Disable(native) end
  sub.linkedTextActive = nil
  active[sub] = nil
  pending[sub] = nil
  excluded[sub] = nil
end

function Display.ResetLinkedText(sub)
  for _, native in pairs(sub.linkedTexts or {}) do native.key, native.restyle = nil, true end
end

function Display.UpdateLinkedText(sub, config, parentData, kind, index)
  if WeakAuras.IsOptionsOpen() or not sub.text:GetFont() then Display.HideLinkedText(sub); return false end
  local source = SourceData(parentData, index)
  local trigger = Display.GetTrigger(source)
  local unit = trigger and Display.UnitTokens(trigger)[1]
  if not unit then Display.HideLinkedText(sub); return false end
  -- A unit the trigger's filters leave out (hostility, class, self) shows a
  -- blank text, deliberately (handled, so no fallback text is drawn), and the
  -- text stays tracked: the next target, focus or side change re-judges it.
  sub.linkedTrigger = trigger
  if Display.UnitEligible and not Display.UnitEligible(trigger, unit) then
    for _, entry in pairs(sub.linkedTexts or {}) do Disable(entry) end
    sub.text:SetText("")
    sub.linkedTextActive = true
    active[sub] = nil
    pending[sub] = nil
    excluded[sub] = true
    return true
  end
  excluded[sub] = nil
  sub.linkedTexts = sub.linkedTexts or {}
  local native = sub.linkedTexts[kind]
  if not native then
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then
      pending[sub] = true
      sub.text:SetText("")
      sub.linkedTextActive = true
      return true
    end
    native = Create(sub, kind, config, index)
    sub.linkedTexts[kind] = native
  end
  for other, entry in pairs(sub.linkedTexts) do if other ~= kind then Disable(entry) end end
  if native.restyle and native.text then
    native.restyle = nil
    Style(sub, native)
    Bind(native, config, index)
  end
  local filter = Display.FilterString(trigger)
  local key = table.concat({unit, filter, table.concat(Display.GetSpellIDs(trigger, true), ","),
    table.concat(trigger.excludedAuraSpellIDs or {}, ","), tostring(parentData)}, "|")
  local container = native.container
  if native.key ~= key then
    container:SetEnabled(false)
    container:SetUnit(unit)
    container:SetAuraSlotFilterString("Linked", filter)
    container:SetAuraSlotCandidateFilters("Linked", Display.CandidateFilters(source))
    container:SetAuraSlotSortMethod("Linked", Display.SortOrder(source, trigger))
    native.key = key
  end
  container:SetFrameLevel(sub:GetFrameLevel())
  native.wanted = true
  container:SetEnabled(sub:IsVisible())
  sub.text:SetText("")
  sub.linkedTextActive = true
  active[sub] = native
  pending[sub] = nil
  return true
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "UNIT_TARGET", "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED", "UNIT_FACTION", "UNIT_NAME_UPDATE", "UPDATE_MOUSEOVER_UNIT"}) do
  events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
  -- ForeverAuras: the pet's target is watched too (Pet Target texts).
  if event == "UNIT_TARGET" and unit ~= "target" and unit ~= "focus" and unit ~= "pet" then return end
  if event == "UNIT_PET" and unit ~= "player" then return end
  -- Side and class changes only matter to the unit filters below.
  if event == "UNIT_FACTION" or event == "UNIT_NAME_UPDATE" or event == "UPDATE_MOUSEOVER_UNIT" then
    for sub, native in pairs(active) do
      local trigger = sub.linkedTrigger
      if trigger and Display.UsesUnitEligibility and Display.UsesUnitEligibility(trigger) and sub.Update then
        local token = Display.UnitTokens(trigger)[1]
        if token and not Display.UnitEligible(trigger, token) then sub:Update() end
      end
    end
    for sub in pairs(excluded) do
      if sub.Update then sub:Update() end
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" or event == "ADDON_RESTRICTION_STATE_CHANGED" then
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return end
    for sub in pairs(pending) do
      pending[sub] = nil
      if sub.Update then sub:Update() end
    end
    -- Class or side may have been unreadable while restricted: every filtered
    -- text is judged again now that the answers are readable.
    for sub in pairs(excluded) do
      if sub.Update then sub:Update() end
    end
    for sub in pairs(active) do
      local trigger = sub.linkedTrigger
      if trigger and Display.UsesUnitEligibility and Display.UsesUnitEligibility(trigger) and sub.Update then
        local token = Display.UnitTokens(trigger)[1]
        if token and not Display.UnitEligible(trigger, token) then sub:Update() end
      end
    end
    return
  end
  -- Unit filters (hostility, class, self): a text whose unit no longer
  -- qualifies goes blank, one whose unit qualifies again is rebuilt.
  for sub, native in pairs(active) do
    local trigger = sub.linkedTrigger
    if trigger and Display.UsesUnitEligibility and Display.UsesUnitEligibility(trigger) and sub.Update then
      local unit = Display.UnitTokens(trigger)[1]
      if unit and not Display.UnitEligible(trigger, unit) then sub:Update() end
    end
  end
  for sub in pairs(excluded) do
    if sub.Update then sub:Update() end
  end
  for _, native in pairs(active) do
    if native.wanted then native.container:UpdateAllAuras() end
  end
end)

events:SetScript("OnEvent", Private.Profiled("aura (modern) - linked text", events:GetScript("OnEvent")))
