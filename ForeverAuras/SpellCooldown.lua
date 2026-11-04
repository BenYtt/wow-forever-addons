-- Modified for ForeverAuras, 2026-10-07.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...

local gcdStates = {}
local gcdStateSince = {}
-- Spells last seen on a real cooldown: an unreadable moment (a GCD in combat)
-- keeps them on cooldown until Blizzard reports the cooldown inactive.
local knownOnCooldown = {}

-- isOnGCD is authoritative only while handling SPELL_UPDATE_COOLDOWN.
function Private.UpdateSpellCooldownGCD(spellID)
  local info = C_Spell.GetSpellCooldown(spellID)
  local wasOnGCD = gcdStates[spellID] == true
  gcdStates[spellID] = nil
  -- Only cache an explicit public flag; an unavailable/secret value is unknown.
  if info and not issecretvalue(info.isOnGCD) and type(info.isOnGCD) == "boolean" then
    gcdStates[spellID] = info.isOnGCD
  end
  if gcdStates[spellID] ~= true then
    gcdStateSince[spellID] = nil
  elseif not wasOnGCD then
    gcdStateSince[spellID] = GetTime()
  end
end

function Private.GetSpellCooldownGCDFlag(spellID)
  return gcdStates[spellID], gcdStateSince[spellID]
end

-- Prefer the fresh filtered timer; the event-scoped flag may be stale.
function Private.IsSpellCooldownGCD(spellID)
  local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
  if duration then
    local zero = duration:IsZero()
    if not issecretvalue(zero) then return zero end
    return nil
  end
  return gcdStates[spellID]
end

function Private.ClearSpellCooldownGCD()
  wipe(gcdStates)
  wipe(gcdStateSince)
  wipe(knownOnCooldown)
end

-- Clear known GCD-only displays with an owned zero duration; otherwise use Blizzard's timer.
local emptyCooldownDuration
function Private.GetSpellCooldownDurationWithoutGCD(spellID, onGCD)
  if onGCD == true then
    if not emptyCooldownDuration then
      emptyCooldownDuration = C_DurationUtil.CreateDuration()
    end
    return emptyCooldownDuration
  end
  return C_Spell.GetSpellCooldownDuration(spellID, true)
end

-- The cooldown APIs are slow on this client (a few tenths of a millisecond
-- each), and one cooldown icon reads them several times per update. Results
-- are kept for the rest of the frame: game state only changes between frames.
-- The tables are kept across frames too, and refilled: a cast makes every
-- cooldown icon read its spell, and the tables and client results that used
-- to be made for each read (over a hundred kilobytes per cast) kept the
-- garbage collector busy for milliseconds in the frames that followed.
-- The client is asked once per spell and frame (ReadSpellBase); each variant
-- of the data (track, GCD, loss of control) is derived from that.
local cooldownCache, cooldownCacheFrame = {}, nil
local baseCache = {}
local cacheGeneration = 0

-- Called when a cooldown event arrives: a cast finishing and the cooldown it
-- starts can be reported in the same frame, so values read before the event
-- must not be served to the trigger that handles it.
function Private.InvalidateSpellCooldownCache()
  cooldownCacheFrame = nil
end
local cooldownCacheFields = {"cooldown", "conditionOnCooldown", "conditionDuration", "gcdOnly", "onCooldown",
  "paused", "count", "ready", "charges", "maxCharges", "recharging", "chargeDuration", "textDuration",
  "wandAppearanceDuration", "duration"}
local ReadSpellBase, FillSpellCooldownData

-- Returns the data table for the spell and variant; it belongs to this cache
-- and is refilled on a later frame, so callers that keep it pass `into`.
function Private.GetSpellCooldownData(spellID, track, showGCD, showLossOfControl, into)
  local now = GetTime()
  if cooldownCacheFrame ~= now then
    cooldownCacheFrame = now
    cacheGeneration = cacheGeneration + 1
  end
  local variant = (track == "charges" and 1 or track == "cooldown" and 2 or 0) + (showGCD and 4 or 0) + (showLossOfControl and 8 or 0)
  local bySpell = cooldownCache[spellID]
  if not bySpell then bySpell = {}; cooldownCache[spellID] = bySpell end
  local entry = bySpell[variant]
  if not entry then entry = {generation = 0, data = {}, present = false}; bySpell[variant] = entry end
  if entry.generation ~= cacheGeneration then
    entry.generation = cacheGeneration
    local base = ReadSpellBase(spellID)
    entry.present = base ~= nil and FillSpellCooldownData(entry.data, base, spellID, track, showGCD, showLossOfControl)
  end
  if not entry.present then return end
  local cached = entry.data
  if into then
    wipe(into)
    for _, key in ipairs(cooldownCacheFields) do into[key] = cached[key] end
    return into
  end
  return cached
end

-- The client's answers for a spell, read once per frame and shared by every
-- variant: the cooldown info and charges tables, the filtered (GCD-free) and
-- unfiltered duration objects, the charge duration and the cast count.
function ReadSpellBase(spellID)
  local base = baseCache[spellID]
  if base and base.generation == cacheGeneration then return base.valid and base or nil end
  if not base then base = {}; baseCache[spellID] = base end
  base.generation = cacheGeneration
  local info = C_Spell.GetSpellCooldown(spellID)
  local charges = C_Spell.GetSpellCharges(spellID)
  if not info then knownOnCooldown[spellID] = nil end
  base.valid = (info or charges) ~= nil
  if not base.valid then return end
  base.info, base.charges = info, charges
  -- Keep the fresh filtered timer even if a cached GCD flag disagrees.
  base.cooldown = C_Spell.GetSpellCooldownDuration(spellID, true)
  base.unfiltered = nil
  base.chargeDuration = charges and C_Spell.GetSpellChargeDuration(spellID) or nil
  base.count = C_Spell.GetSpellCastCount(spellID)
  local zero
  if base.cooldown then
    local result = base.cooldown:IsZero()
    if not issecretvalue(result) then zero = result end
  end
  base.zero = zero
  return base
end

-- Fills `result` for one variant from the spell's base reads. Returns true
-- when the spell has cooldown data.
function FillSpellCooldownData(result, base, spellID, track, showGCD, showLossOfControl)
  wipe(result)
  local info, charges, cooldown, zero = base.info, base.charges, base.cooldown, base.zero
  local onCooldown
  if info then
    if not info.isEnabled then
      onCooldown = true
    elseif not info.isActive then
      onCooldown = false
    elseif zero ~= nil then
      onCooldown = not zero
    end
  end

  -- Logical checks use public flags; desaturation follows the fresh timer.
  local conditionOnCooldown = onCooldown
  if onCooldown == nil and info and info.isActive and gcdStates[spellID] ~= nil then
    onCooldown = not gcdStates[spellID]
  end
  if onCooldown == nil and info and info.isActive and knownOnCooldown[spellID] then
    onCooldown = true
  elseif onCooldown ~= nil and info and info.isEnabled then
    knownOnCooldown[spellID] = onCooldown or nil
  end
  result.cooldown = cooldown
  result.conditionOnCooldown = conditionOnCooldown
  result.conditionDuration = cooldown
  result.gcdOnly = info and info.isActive and info.isEnabled and zero == true or false
  result.onCooldown = onCooldown
  result.paused = info and not info.isEnabled or false
  result.count = base.count
  if onCooldown ~= nil then result.ready = not onCooldown end
  if charges then
    result.charges = charges.currentCharges
    result.maxCharges = charges.maxCharges
    result.recharging = charges.isActive
    result.chargeDuration = base.chargeDuration
  end

  -- Share the copied timer with desaturation without changing logical cooldown state.
  local held
  result.textDuration, held = Private.GetWandCooldownDuration(spellID, cooldown)
  result.wandAppearanceDuration = held and not result.paused and result.textDuration or nil
  local useCharges = track == "charges"
  if track ~= "cooldown" and track ~= "charges" and charges then
    local shortCooldown = info and not issecretvalue(info.duration) and info.duration <= 1.5
    -- An idle charge timer must not replace a requested GCD with an empty swipe.
    -- When timing is restricted, the public recharge flag can still select it.
    useCharges = charges.isActive == true and (conditionOnCooldown ~= true or shortCooldown or not info)
  end
  if useCharges then
    result.duration = result.chargeDuration
    result.conditionDuration = result.chargeDuration
    result.textDuration = result.chargeDuration
    result.wandAppearanceDuration = nil -- Recharge appearance keeps its own timer.
    result.gcdOnly = false
    result.onCooldown = charges and charges.isActive or false
    result.conditionOnCooldown = result.onCooldown
    result.paused = false
  else
    if showGCD then
      -- The unfiltered timer (with the GCD) is read once per frame as well.
      if base.unfiltered == nil then base.unfiltered = C_Spell.GetSpellCooldownDuration(spellID) or false end
      result.duration = base.unfiltered or cooldown
    else
      result.duration = cooldown
    end
  end
  if showLossOfControl then
    local lossOfControl = C_Spell.GetSpellLossOfControlCooldownInfo(spellID)
    if lossOfControl and lossOfControl.shouldReplaceNormalCooldown then
      result.duration = C_Spell.GetSpellLossOfControlCooldownDuration(spellID)
      result.conditionDuration = result.duration
      result.textDuration = result.duration
      result.wandAppearanceDuration = nil -- Loss of control takes precedence.
      result.gcdOnly = false
      result.onCooldown = lossOfControl.isActive
      result.conditionOnCooldown = result.onCooldown
      result.paused = false
    end
  end
  return true
end

Private.ExecEnv.GetSpellCooldownData = Private.GetSpellCooldownData
Private.ExecEnv.spellCooldownTriggerScratch = {}

local customStateScratch = {}
function WeakAuras.SetSpellCooldownState(state, spellID, showGCD, showGCDText)
  local cooldown = Private.GetSpellCooldownData(spellID, nil, showGCD, nil, customStateScratch)
  local hideGCDText = not showGCDText
  state.changed = true
  state.progressType = "durationObject"
  state.expirationTime, state.duration, state.modRate = nil, nil, nil
  state.paused, state.remaining, state.value, state.total = nil, nil, nil, nil
  state.durationObject = cooldown and cooldown.duration
  state.onCooldown = cooldown and cooldown.onCooldown
  state.spellCooldownConditionDuration = cooldown and cooldown.conditionDuration
  state.spellCooldownConditionOnCooldown = cooldown and cooldown.conditionOnCooldown
  state.wandAppearanceDuration = cooldown and not cooldown.paused and cooldown.wandAppearanceDuration or nil
  state.cdmTextPreview = false
  state.cdmHideGCDText = hideGCDText
  state.cdmGCDOnly = cooldown and cooldown.gcdOnly or false
  state.cdmTextDurationRequired = hideGCDText
  state.cdmTextDurationObject = hideGCDText and cooldown and cooldown.textDuration or nil
  state.cdmNativePaused = cooldown and cooldown.paused or false
end

-- GCD-length classification for countdown text, as EllesmereUI does it.
-- A cooldown whose TOTAL duration is at most one global cooldown (plus a
-- margin) is a GCD or a wand Shoot lockout, never a real spell cooldown, so its
-- countdown text is hidden. The game evaluates the curve against the duration
-- object, so this works on secret timers without reading them. The step
-- follows spell haste, read once per frame and rounded to 0.05s; it rises at
-- once but only falls after 2s, so a haste gain mid-GCD cannot reclassify the
-- GCD already running.
local gcdStep, gcdStepAt, gcdStepHold, gcdTextCurve, gcdTextCurveStep
local function GCDStep()
  local now = GetTime()
  if gcdStepAt ~= now then
    gcdStepAt = now
    local haste = UnitSpellHaste and UnitSpellHaste("player") or 0
    if issecretvalue(haste) or type(haste) ~= "number" then haste = 0 end
    local length = math.max(0.75, 1.5 / (1 + haste / 100))
    -- With a wand, Shoot locks the other spells for the wand's attack speed,
    -- which can be longer than a GCD; that lockout is classified the same way.
    -- Forever has no global IsEquippedItemType; it lives under C_Item.
    local isEquippedType = (C_Item and C_Item.IsEquippedItemType) or IsEquippedItemType
    local wand = isEquippedType and isEquippedType("Wands")
    if not issecretvalue(wand) and wand == true and UnitRangedDamage then
      local speed = UnitRangedDamage("player")
      if not issecretvalue(speed) and type(speed) == "number" and speed > length and speed < 5 then
        length = speed
      end
    end
    local step = math.floor((length + 0.15) * 20 + 0.5) / 20
    if not gcdStep or step >= gcdStep or now >= (gcdStepHold or 0) then
      gcdStep = step
      gcdStepHold = now + 2
    end
  end
  return gcdStep
end

-- Step curve: 0 for a total duration up to one GCD, 1 above it; nil when the
-- client has no curve support.
function Private.GetGCDTextCurve()
  if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum.LuaCurveType) then return end
  local step = GCDStep()
  if gcdTextCurveStep ~= step then
    gcdTextCurve = C_CurveUtil.CreateCurve()
    gcdTextCurve:SetType(Enum.LuaCurveType.Step)
    gcdTextCurve:AddPoint(0, 0)
    gcdTextCurve:AddPoint(step, 1)
    gcdTextCurveStep = step
  end
  return gcdTextCurve
end

-- Alpha for a countdown text drawn from duration: 0 while it is a GCD-length
-- (or wand) lockout, 1 for a real cooldown. nil when it cannot be evaluated.
-- Evaluations are kept per duration object for the rest of the frame.
local alphaCache, alphaCacheFrame = setmetatable({}, {__mode = "k"}), nil
function Private.GCDTextAlpha(duration)
  if not duration or type(duration) ~= "userdata" and type(duration) ~= "table" then return end
  if not duration.EvaluateTotalDuration then return end
  local now = GetTime()
  if alphaCacheFrame ~= now then
    alphaCacheFrame = now
    wipe(alphaCache)
  end
  local alpha = alphaCache[duration]
  if alpha ~= nil then return alpha end
  local curve = Private.GetGCDTextCurve()
  if not curve then return end
  alpha = duration:EvaluateTotalDuration(curve, 0)
  alphaCache[duration] = alpha
  return alpha
end

-- Copied durations keep their total span after expiry. Evaluate remaining time
-- directly into desaturation; nested condition endpoints may also be secret.
local wandAppearanceCurve
local function SelectWandDesaturation(state, needle, valueIfTrue, valueIfFalse)
  local duration = state.wandAppearanceDuration
  if not duration then return end
  if not wandAppearanceCurve then wandAppearanceCurve = C_CurveUtil.CreateCurve() end
  wandAppearanceCurve:SetToDefaults()
  local expired, active = valueIfFalse, valueIfTrue
  if needle ~= 1 then expired, active = valueIfTrue, valueIfFalse end
  wandAppearanceCurve:AddPoint(0, expired)
  wandAppearanceCurve:AddPoint(0.001, active)
  return duration:EvaluateRemainingDuration(wandAppearanceCurve), true
end

-- Use CDM's public condition result when no copied Shoot timer applies.
function Private.ExecEnv.SelectCDMCooldownDesaturation(state, needle, valueIfTrue, valueIfFalse, publicResult)
  if not state or not state.show then return valueIfFalse end
  local value, applied = SelectWandDesaturation(state, needle, valueIfTrue, valueIfFalse)
  if applied then return value end
  if publicResult then return valueIfTrue end
  return valueIfFalse
end

function Private.ExecEnv.SelectSpellCooldownDesaturation(state, needle, valueIfTrue, valueIfFalse, publicResult)
  if not state or not state.show then return valueIfFalse end
  local value, applied = SelectWandDesaturation(state, needle, valueIfTrue, valueIfFalse)
  if applied then return value end
  if state.progressType ~= "durationObject" then
    if publicResult then return valueIfTrue end
    return valueIfFalse
  end
  local duration = state.spellCooldownConditionDuration
  -- Use fresh timer metadata for appearance and public flags for logical checks.
  local onCooldown = state.spellCooldownConditionOnCooldown
  if onCooldown == nil and not duration then onCooldown = state.onCooldown end
  if onCooldown ~= nil then
    if onCooldown == (needle == 1) then return valueIfTrue end
    return valueIfFalse
  end
  if duration and duration.IsZero and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
    if needle == 1 then
      return C_CurveUtil.EvaluateColorValueFromBoolean(duration:IsZero(), valueIfFalse, valueIfTrue)
    end
    return C_CurveUtil.EvaluateColorValueFromBoolean(duration:IsZero(), valueIfTrue, valueIfFalse)
  end
  return valueIfFalse
end

function Private.ValidateSpellCooldownSupport(data)
  local triggers = {}
  local comparisons, chargeIndex, progressTexture
  for index, entry in ipairs(data.triggers or {}) do
    local trigger = entry.trigger
    if trigger.type == "spell" and trigger.event == "Cooldown Progress (Spell)" then
      triggers[index] = true
      -- The Remaining Time filter is applied natively on a restricted
      -- cooldown (RegionPrototype, secretRemainingWindow): no warning for it.
      comparisons = comparisons or trigger.use_charges or trigger.use_spellCount
      chargeIndex = chargeIndex or trigger.use_trackcharge
      progressTexture = progressTexture or data.regionType == "progresstexture"
    end
  end
  local function CheckCondition(check)
    if not check then return end
    if triggers[check.trigger] and check.value ~= nil then
      local variable = check.variable
      comparisons = comparisons or variable == "expirationTime" or variable == "duration"
        or variable == "charges" or variable == "spellCount" or variable == "stacks"
        or variable == "readyTime" or variable == "chargeGainTime" or variable == "chargeLostTime"
    end
    for _, child in ipairs(check.checks or {}) do CheckCondition(child) end
  end
  for _, condition in ipairs(data.conditions or {}) do
    if not Private.TimerConditionHandled(data, condition) then CheckCondition(condition.check) end
  end

  local messages = {}
  if comparisons then
    table.insert(messages, "Charge and spell count comparisons, and conditions on cooldown times, cannot be evaluated while the client restricts their values. Timers and the Remaining Time filter still work, and On Cooldown uses the public cooldown status.")
  end
  if chargeIndex then
    table.insert(messages, "Tracking a specific numbered charge requires readable charge counts and is unavailable while cooldown values are restricted. Tracking the current recharge is supported.")
  end
  if progressTexture then
    table.insert(messages, "Progress textures cannot render restricted duration objects. Use an icon cooldown or progress bar for this trigger.")
  end
  if #messages > 0 then
    Private.AuraWarnings.UpdateWarning(data.uid, "restricted_cooldown_options", "warning", table.concat(messages, "\n"))
  else
    Private.AuraWarnings.UpdateWarning(data.uid, "restricted_cooldown_options")
  end
end
