-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, OptionsPrivate = ...
local Editor = {}
OptionsPrivate.AuraEditor = Editor

local auraTypes = {
  HELPFUL = L["Buff"], HARMFUL = L["Debuff"], BOTH = L["Buff or Debuff"],
  Buff = L["Blizzard: Buff"], Debuff = L["Blizzard: Debuff"], Dispel = L["Blizzard: Dispellable"],
}
local classificationFilters = {Buff = "HELPFUL", Debuff = "HARMFUL", Dispel = "HARMFUL"}

function Editor.Mode(trigger)
  if trigger.auraTracking == "native" or trigger.auraTracking == "readable" then return trigger.auraTracking end
  return trigger.type == "secretAura" and "native" or "readable"
end

function Editor.Resolve(data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  if trigger.type ~= "aura2" and trigger.type ~= "secretAura" then return end
  local mode = Editor.Mode(trigger)
  local native = mode == "native"
  local wanted = native and "secretAura" or "aura2"
  if wanted == trigger.type then return end
  if native then
    trigger.auraReadableSettings = {
      onlyMaw = trigger.onlyMaw, automaticWidth = data.automaticWidth, debuffType = trigger.debuffType,
    }
    if trigger.debuffType == "BOTH" then trigger.debuffType = "HELPFUL" end
    trigger.secretUseSpellIDs = trigger.useExactSpellId or false
    trigger.type = wanted
    OptionsPrivate.Private.BlizzardAuraDisplay.Migrate(data)
  else
    local previous = trigger.auraReadableSettings
    trigger.useExactSpellId = OptionsPrivate.Private.BlizzardAuraDisplay.UsesSpellIDs(trigger)
    if previous then
      trigger.onlyMaw = previous.onlyMaw
      data.automaticWidth = previous.automaticWidth
      if previous.debuffType == "BOTH" then trigger.debuffType = "BOTH" end
    end
    trigger.type = wanted
    trigger.auraReadableSettings = nil
  end
  OptionsPrivate.QueueOptionsRefresh(data.id)
end

function OptionsPrivate.SaveAuraTrigger(data, triggernum)
  Editor.Resolve(data, triggernum)
  WeakAuras.Add(data)
end

function Editor.AddOptions(options, data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  local native = trigger.type == "secretAura"
  local function Save() OptionsPrivate.SaveAuraTrigger(data, triggernum); OptionsPrivate.QueueOptionsRefresh(data.id) end
  if native then
    options.help.fontSize = "small"
  else
    options.auraCapabilities = {
      type = "description", order = 1.3, width = "full", fontSize = "small",
      name = L["Legacy Auras rarely function in combat as most are Blizzard-controlled."],
    }
  end
  local auraType = options.debuffType
  auraType.values = native and {HELPFUL = L["Buff"], HARMFUL = L["Debuff"]} or {HELPFUL = L["Buff"], HARMFUL = L["Debuff"], BOTH = L["Buff or Debuff"]}
  auraType.sorting = native and {"HELPFUL", "HARMFUL"} or {"HELPFUL", "HARMFUL", "BOTH"}
  auraType.get = function() return trigger.debuffType end
  auraType.set = function(_, value)
    if not auraType.values[value] then return end
    trigger.processedAuraType = "any"
    trigger.debuffType = value
    if trigger.sortMethod == "UnitFrameDebuff" then trigger.sortMethod = "Default" end
    Save()
  end
  if native then
    local display = OptionsPrivate.Private.BlizzardAuraDisplay
    -- Seconds as typed, accepting a decimal comma ("1,5") as many locales write it.
    local function Seconds(value)
      return type(value) == "string" and (value:gsub(",", ".")) or value
    end
    -- Remaining Time heads the Aura Filters section, as it heads Legacy's
    -- Active Aura Filters; like Legacy, only with Show On: Aura(s) Found.
    -- Show On: Aura(s) Gained shows an aura only while new, through its own
    -- fade; the time and stack gates hide auras through native curves, and the
    -- two cannot combine, so the gates are hidden (and cleared) with Gained.
    local function Gained() return display.RawShowOn(trigger) == "showOnActive" and trigger.secretGained == true end
    local function RemainingHidden() return display.RawShowOn(trigger) ~= "showOnActive" or Gained() end
    options.useRem = {type = "toggle", name = L["Remaining Time"], order = 10.01, width = WeakAuras.normalWidth,
      hidden = RemainingHidden,
      get = function() return trigger.secretUseRem or false end,
      set = function(_, value)
        trigger.secretUseRem = value or nil
        -- Start from "less than 5 seconds", the usual "about to run out" check.
        if value and trigger.secretRemOperator == nil then trigger.secretRemOperator = "<" end
        if value and tonumber(trigger.secretRem) == nil then trigger.secretRem = "5" end
        Save()
      end}
    options.remOperator = {type = "select", name = L["Operator"], order = 10.02, width = WeakAuras.halfWidth,
      values = display.remOperators, sorting = {"<", "<=", ">", ">="},
      hidden = function() return RemainingHidden() or not trigger.secretUseRem end,
      get = function() return trigger.secretRemOperator or "<" end,
      set = function(_, value) trigger.secretRemOperator = value; Save() end}
    options.rem = {type = "input", name = L["Remaining Time"], order = 10.03, width = WeakAuras.halfWidth,
      hidden = function() return RemainingHidden() or not trigger.secretUseRem end,
      validate = function(_, value)
        local seconds = tonumber(Seconds(value))
        if not seconds or seconds < 0 or seconds ~= seconds or seconds == math.huge then return L["Enter a number of seconds, 0 or more."] end
        return true
      end,
      get = function() return trigger.secretRem and tostring(trigger.secretRem) or "" end,
      set = function(_, value) trigger.secretRem = Seconds(value); Save() end}
    options.useRemSpace = {type = "description", name = "", order = 10.04, width = WeakAuras.normalWidth,
      hidden = function() return RemainingHidden() or trigger.secretUseRem end}
    local function ValidSeconds(value)
      local seconds = tonumber(Seconds(value))
      if not seconds or seconds <= 0 or seconds ~= seconds or seconds == math.huge then return L["Enter a number of seconds above 0."] end
      return true
    end
    -- Total Duration: a standard filter on the aura's full duration, laid out
    -- like Remaining Time. "<=" is Blizzard's own candidate filter and works
    -- everywhere; "=" and ">=" are drawn by a clip (Icons on screen). "=" also
    -- replaces every learned or described duration (glows).
    options.useTotal = {type = "toggle", name = L["Total Duration"], order = 10.05, width = WeakAuras.normalWidth,
      desc = "= matches only auras of exactly this length and sets the duration assumed for glows.",
      hidden = function() return Gained() end,
      get = function() return trigger.secretUseTotal or false end,
      set = function(_, value)
        trigger.secretUseTotal = value or nil
        if value and trigger.secretTotalOperator == nil then trigger.secretTotalOperator = "=" end
        Save()
      end}
    options.totalOperator = {type = "select", name = L["Operator"], order = 10.06, width = WeakAuras.halfWidth,
      values = display.totalOperators, sorting = {"=", "<=", ">="},
      hidden = function() return Gained() or not trigger.secretUseTotal end,
      get = function() return trigger.secretTotalOperator or "=" end,
      set = function(_, value) trigger.secretTotalOperator = value; Save() end}
    options.total = {type = "input", name = L["Total Duration"], order = 10.07, width = WeakAuras.halfWidth,
      hidden = function() return Gained() or not trigger.secretUseTotal end,
      validate = function(_, value) return ValidSeconds(value) end,
      get = function() return trigger.secretTotal and tostring(trigger.secretTotal) or "" end,
      set = function(_, value) trigger.secretTotal = Seconds(value); Save() end}
    options.useTotalSpace = {type = "description", name = "", order = 10.08, width = WeakAuras.normalWidth,
      hidden = function() return Gained() or trigger.secretUseTotal end}
    -- Stack Count: laid out like Total Duration. Blizzard has no stack filter,
    -- so it is drawn by a clip around the display (SecretAuraSingle.lua).
    options.useStacks = {type = "toggle", name = L["Stack Count"], order = 10.085, width = WeakAuras.normalWidth,
      hidden = function() return Gained() end,
      get = function() return trigger.secretUseStacks or false end,
      set = function(_, value)
        trigger.secretUseStacks = value or nil
        if value and trigger.secretStacksOperator == nil then trigger.secretStacksOperator = ">=" end
        Save()
      end}
    options.stacksOperator = {type = "select", name = L["Operator"], order = 10.086, width = WeakAuras.halfWidth,
      values = display.stackOperators, sorting = {"=", ">=", ">", "<=", "<"},
      hidden = function() return Gained() or not trigger.secretUseStacks end,
      get = function() return trigger.secretStacksOperator or ">=" end,
      set = function(_, value) trigger.secretStacksOperator = value; Save() end}
    options.stacks = {type = "input", name = L["Stack Count"], order = 10.087, width = WeakAuras.halfWidth,
      hidden = function() return Gained() or not trigger.secretUseStacks end,
      validate = function(_, value)
        local count = tonumber(value)
        if not count or count ~= math.floor(count) or count < 0 or count > display.STACK_LIMIT then
          return L["Enter a whole number from 0 to %d."]:format(display.STACK_LIMIT)
        end
        return true
      end,
      get = function() return trigger.secretStacks and tostring(trigger.secretStacks) or "" end,
      set = function(_, value) trigger.secretStacks = tonumber(value); Save() end}
    options.useStacksSpace = {type = "description", name = "", order = 10.088, width = WeakAuras.normalWidth,
      hidden = function() return Gained() or trigger.secretUseStacks end}
    options.show_settings_header = {type = "header", name = L["Show and Clone Settings"], order = 69.91}
    -- Same label/selector pair and values as Aura (Legacy). Aura(s) Found keeps
    -- the list behaviour; Missing and Always draw one aura (SecretAuraSingle.lua).
    options.use_matchesShowOn = {type = "toggle", name = L["Show On"], order = 71, width = WeakAuras.normalWidth,
      get = function() return true end, disabled = true}
    -- Aura(s) Gained is a Found list whose auras show only while new
    -- (BlizzardAuraDisplay.lua, Display.GainedSeconds): stored as Found plus
    -- secretGained, so it behaves as Found everywhere but in the drawing.
    local showOnValues = {showOnActive = L["Aura(s) Found"], showOnGained = L["Aura(s) Gained"], showOnMissing = L["Aura(s) Missing"], showAlways = L["Always"]}
    options.matchesShowOn = {type = "select", name = L["Show On"], order = 71.1, width = WeakAuras.normalWidth,
      values = showOnValues,
      sorting = {"showOnActive", "showOnGained", "showOnMissing", "showAlways"},
      desc = L["Aura(s) Gained: shows an aura only while it is new, for the seconds below."],
      get = function()
        local shown = display.RawShowOn(trigger)
        if shown == "showOnActive" and trigger.secretGained then return "showOnGained" end
        return shown
      end,
      set = function(_, value)
        if not showOnValues[value] then return end
        if value == "showOnGained" then
          trigger.secretShowOn = nil
          trigger.secretGained = true
          trigger.secretUseRem, trigger.secretUseTotal, trigger.secretUseStacks = nil, nil, nil
          if tonumber(trigger.secretGainedSeconds) == nil then trigger.secretGainedSeconds = 1.5 end
        else
          trigger.secretGained = nil
          trigger.secretShowOn = value ~= "showOnActive" and value or nil
        end
        Save()
      end}
    options.gainedSeconds = {type = "input", name = L["Shown for (seconds)"], order = 71.2, width = WeakAuras.normalWidth,
      hidden = function() return not (display.RawShowOn(trigger) == "showOnActive" and trigger.secretGained) end,
      validate = function(_, value)
        local seconds = tonumber(Seconds(value))
        if not seconds or seconds <= 0 then return L["Enter a number of seconds."] end
        return true
      end,
      get = function() return tostring(tonumber(trigger.secretGainedSeconds) or 1.5) end,
      set = function(_, value) trigger.secretGainedSeconds = tonumber(Seconds(value)); Save() end}
    -- The Missing icon's look is set with an "Aura Active = False" condition
    -- (SecretAuraConditions.lua); the former box here is migrated to one.
    -- As in Aura (Legacy): the trigger is inactive while its target, focus or
    -- pet does not exist (SecretAuraTrigger.lua), unless this is ticked.
    options.unitExists = {type = "toggle", name = L["Show If Unit Does Not Exist"], order = 71.3, width = WeakAuras.doubleWidth,
      desc = L["Ticked, this display stays as it is while there is no such unit. Unticked, it is hidden while the unit does not exist."],
      hidden = function()
        local unit = trigger.unit
        return not (unit == "target" or unit == "focus" or unit == "pet" or unit == "targettarget" or unit == "focustarget" or unit == "pettarget" or unit == "member")
      end,
      get = function() return trigger.unitExists or false end,
      set = function(_, value) trigger.unitExists = value or nil; Save() end}
    options.showClones = {type = "toggle", name = L["Auto-Clone (Show All Matches)"], order = 72, width = "full",
      get = function() return trigger.showClones or false end, disabled = true}
    options.combineMode = {type = "select", name = L["Preferred Match"], order = 72.6, width = WeakAuras.normalWidth,
      values = OptionsPrivate.Private.bufftrigger_2_preferred_match_types, get = function() return trigger.combineMode or "showLowest" end, disabled = true}
    options.nativeShowNotice = {type = "description", order = 73, width = "full", fontSize = "small",
      name = function()
        if display.IsSingle(trigger, data) then
          return L["One aura is shown, chosen by Sort by under Aura (Modern) Settings in Display."]
        end
        return L["You cannot control clones with an Aura (Modern). Use the Aura (Modern) Settings under Display."]
      end}
  end
end
