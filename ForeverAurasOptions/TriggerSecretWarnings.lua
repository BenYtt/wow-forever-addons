-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, OptionsPrivate = ...
local Warnings = {}
OptionsPrivate.TriggerSecretWarnings = Warnings
Warnings.text = L["|cffff0000Secret detected. Some features may be restricted in combat.|r"]

-- Missing or invalid secrecy queries leave the restriction unknown.
local function Query(name, ...)
  local func = C_Secrets and C_Secrets[name]
  if not func then return end
  local ok, value = pcall(func, ...)
  if ok and not issecretvalue(value) then return value end
end

local function Restricted(level)
  local levels = Enum and Enum.SecrecyLevel
  return level ~= nil and levels and (level == levels.AlwaysSecret or level == levels.ContextuallySecret)
end

local function SpellID(value)
  local id = tonumber(value)
  if id and id > 0 and id < 2147483647 and id == math.floor(id) then return id end
end

function Warnings.HasSecretAuraSpell(trigger)
  if trigger.type ~= "aura2" or Query("HasSecretRestrictions") == false then return false end
  local function Check(value)
    local id = SpellID(value)
    if not id then return false end
    return Restricted(Query("GetSpellAuraSecrecy", id)) or Query("ShouldSpellAuraBeSecret", id) == true
  end
  if trigger.useExactSpellId then
    for _, value in ipairs(trigger.auraspellids or {}) do
      if Check(value) then return true end
    end
  end
  -- Legacy name filters can also contain spell IDs, resolved to names at runtime.
  if trigger.useName then
    for _, value in ipairs(trigger.auranames or {}) do
      if Check(value) then return true end
    end
  end
  return false
end

local function AddConditionFields(check, triggernum, fields)
  if type(check) ~= "table" then return end
  if check.trigger == triggernum and type(check.variable) == "string" then fields[check.variable] = true end
  for _, child in ipairs(check.checks or {}) do AddConditionFields(child, triggernum, fields) end
end

local function SelectedFields(data, triggernum, trigger)
  local fields = {}
  local prototype = trigger.type ~= "custom" and OptionsPrivate.Private.event_prototypes[trigger.event]
  for _, arg in ipairs(prototype and prototype.args or {}) do
    local enabled = arg.enable ~= false and (type(arg.enable) ~= "function" or arg.enable(trigger))
    local selected = arg.name and trigger["use_" .. arg.name]
    if enabled and arg.name and selected ~= nil and (selected ~= false or arg.type == "tristate" or arg.type == "tristatestring") and arg.test ~= "true" then
      fields[arg.name] = true
    end
  end
  for _, condition in ipairs(data.conditions or {}) do
    -- Remaining Time conditions that only change Alpha or Color work in combat.
    if not OptionsPrivate.Private.TimerConditionHandled(data, condition) then AddConditionFields(condition.check, triggernum, fields) end
  end
  return fields
end

local function HasField(fields, names)
  for name in names:gmatch("%S+") do if fields[name] then return true end end
  return false
end

-- Unit APIs require concrete tokens rather than multi-unit selectors.
local function Units(trigger)
  local unit = trigger.unit or "player"
  local group = OptionsPrivate.Private.multiUnitUnits[unit]
  if group then return group end
  return type(unit) == "string" and unit ~= "none" and unit ~= "member" and {[unit] = true} or {}
end

function Warnings.GetScope(data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  if Query("HasSecretRestrictions") == false then return end
  local event = trigger.type ~= "custom" and trigger.event
  local fields = SelectedFields(data, triggernum, trigger)
  if event == "Health" then
    -- The trigger's own combat status line covers these.
    return
  elseif event == "Power" or event == "Alternate Power" then
    local powerType = event == "Alternate Power" and 10 or trigger.use_powertype and trigger.powertype or nil
    if event == "Alternate Power" and powerType and Restricted(Query("GetPowerTypeSecrecy", powerType)) then return L["Power value checks and calculations:"] end
    for unit in pairs(Units(trigger)) do
      local selected = powerType or UnitPowerType(unit)
      if not issecretvalue(selected) then
        if selected == 99 then
          if issecretvalue(UnitStagger(unit)) or Query("ShouldUnitHealthMaxBeSecret", unit) == true then return L["Stagger value checks and calculations:"] end
        elseif event == "Alternate Power" and (Restricted(Query("GetPowerTypeSecrecy", selected)) or Query("ShouldUnitPowerBeSecret", unit, selected) == true or Query("ShouldUnitPowerMaxBeSecret", unit, selected) == true) then
          return L["Power value checks and calculations:"]
        end
      end
    end
    if event == "Power" then return end
  elseif event == "Character Stats" and next(fields) and Query("ShouldUnitStatsBeSecret") == true then
    return L["Character stat checks:"]
  elseif event == "Threat Situation" then
    if trigger.unit == "none" then
      if Query("ShouldUnitThreatStateBeSecret", "player") == true then return L["Threat checks:"] end
    else
      for unit in pairs(Units(trigger)) do
        if Query("ShouldUnitThreatStateBeSecret", "player", unit) == true or Query("ShouldUnitThreatValuesBeSecret", "player", unit) == true then return L["Threat checks:"] end
      end
    end
  elseif event == "Cast" and HasField(fields, "remaining duration spellId spell spellIds spellNames interruptible") then
    for unit in pairs(Units(trigger)) do
      if Query("ShouldUnitSpellCastingBeSecret", unit) == true then return L["Cast value checks:"] end
    end
  elseif event == "Cooldown Progress (Spell)" or event == "Cooldown Ready (Spell)" or event == "Charges Changed" or event == "Action Usable" then
    local id = SpellID(trigger.spellName)
    if not id and trigger.spellName and C_Spell and C_Spell.GetSpellInfo then
      local info = C_Spell.GetSpellInfo(trigger.spellName)
      id = info and info.spellID
    end
    if not issecretvalue(id) and id then
      if HasField(fields, "remaining duration expirationTime chargeGainTime chargeLostTime") and (Restricted(Query("GetSpellCooldownSecrecy", id)) or Query("ShouldSpellCooldownBeSecret", id) == true) then
        return L["Cooldown time checks:"]
      end
      -- Cooldown secrecy does not establish that a charge/count value is secret.
      if HasField(fields, "charges maxCharges") and C_Spell and C_Spell.GetSpellCharges then
        local charges = C_Spell.GetSpellCharges(id)
        if issecretvalue(charges) or (charges and (issecretvalue(charges.currentCharges) or issecretvalue(charges.maxCharges))) then return L["Charge count checks:"] end
      end
      if fields.spellCount and C_Spell and C_Spell.GetSpellCastCount and issecretvalue(C_Spell.GetSpellCastCount(id)) then return L["Spell count checks:"] end
    end
  end

  if HasField(fields, "name namerealm unitname realm npcId guid") then
    for unit in pairs(Units(trigger)) do
      if Query("ShouldUnitIdentityBeSecret", unit) == true then return L["Unit identity checks:"] end
    end
  end
  -- Check selected fields on existing states when no metadata query applies.
  if next(fields) then
    local ok, states = pcall(WeakAuras.GetTriggerStateForTrigger, data.id, triggernum)
    if ok and type(states) == "table" then
      for _, state in pairs(states) do
        if not issecretvalue(state) and type(state) == "table" then
          for field in pairs(fields) do
            if issecretvalue(state[field]) then return L["Selected value checks:"] end
          end
        end
      end
    end
  end
end

function Warnings.GetText(data, triggernum)
  local scope = Warnings.GetScope(data, triggernum)
  return scope and Warnings.text or ""
end
