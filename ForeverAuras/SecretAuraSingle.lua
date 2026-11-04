-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Show On, Remaining Time and Total Duration for the Aura (Modern) trigger.
--
-- Aura(s) Found lists every matching aura in a native aura group. Aura(s)
-- Missing, Always and Remaining Time watch one unit and draw at most one aura
-- in the region's own rectangle (a "single" display).
--
-- Nothing here reads aura state in combat; Blizzard's own bindings do the work:
--   Missing: an invisible native group gives its container a width only while
--     the aura is present; a clip anchored to that width hides the Missing icon.
--   Remaining Time: a Step colour curve over the remaining duration, on native
--     duration text holding the icon as inline texture markup.
--   Total Duration: a hidden text formatted from the total duration sizes a
--     clip that holds the whole aura button (StyleDurationGate).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraSingle")
local Display = Private.BlizzardAuraDisplay
local function Locked(frame) return Display.Busy ~= nil and Display.Busy(frame) end

-- Units that name one unit; group, nameplate, boss and arena are lists.
Display.singleUnits = {player = true, target = true, focus = true, pet = true, targettarget = true, focustarget = true, pettarget = true}
function Display.IsSingleUnit(trigger)
  if type(trigger) ~= "table" then return false end
  if trigger.unit == "member" then return Display.SpecificUnit(trigger) ~= nil end
  return Display.singleUnits[trigger.unit] == true
end
-- Stored in secret* fields, not the Aura (Legacy) ones, so auras converted from
-- Legacy keep their behaviour.
Display.showOnValues = {showOnActive = L["Aura(s) Found"], showOnMissing = L["Aura(s) Missing"], showAlways = L["Always"]}
Display.remOperators = {["<"] = "<", ["<="] = "<=", [">"] = ">", [">="] = ">="}

-- Keys of the extra native parts, unique within their containers.
local MISSING_GROUP = "FAMissing"
local SLOT_ICON = "FARemainIcon"
local SLOT_TEXTURE = "FARemainTexture"
-- ForeverAuras: one slot per hardcoded Text element of a Remaining Time icon.
local SLOT_TEXT = "FARemainText"
-- A Step curve point rules from its own value upwards; <= and > move the edge
-- just past the entered number.
local REMAIN_EPS = 0.001
-- Inline texture coordinates are integers of this texture size.
local TEXCOORD_UNITS = 1024

-- Screen pixels per UI unit where a frame is drawn, or nil when unknown
-- (as in SecretAuraFlow.lua).
local function PixelsPerUnit(frame)
  local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
  local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
  if type(factor) ~= "number" or factor <= 0 or type(scale) ~= "number" or issecretvalue(scale) or scale <= 0 then return nil end
  return scale / factor
end


function Display.RawShowOn(trigger)
  local value = type(trigger) == "table" and trigger.secretShowOn
  return Display.showOnValues[value] and value or "showOnActive"
end

Display.ShowOn = Display.RawShowOn

-- As in Aura (Legacy), Remaining Time applies with Show On: Aura(s) Found only.
local function UsesRemaining(trigger)
  return type(trigger) == "table" and trigger.secretUseRem == true and Display.ShowOn(trigger) == "showOnActive"
end

-- True when the settings need the single-aura drawing. With data, Remaining
-- Time counts only on Icons: bars, progress textures and texts stay a list
-- and use the gate instead (Display.RemainingGateRange). Without data it
-- counts for every display type, which the gate conflict checks rely on.
function Display.IsSingle(trigger, data)
  if Display.ShowOn(trigger) ~= "showOnActive" then return true end
  return UsesRemaining(trigger) and not (data and data.regionType ~= "icon")
end

-- Returns op, seconds when a usable Remaining Time filter is configured.
function Display.RemainingWindow(trigger)
  if not UsesRemaining(trigger) then return end
  local op, x = trigger.secretRemOperator or "<", tonumber(trigger.secretRem)
  -- A Spell List may set the seconds (a backend's slider), keeping the operator.
  local list = Display.SpellList(trigger)
  if list and list.remaining then x = list.remaining end
  if not Display.remOperators[op] or not x or x ~= x or x < 0 or x == math.huge then return end
  return op, x
end

function Display.InRemainingWindow(value, op, x)
  if op == "<" then return value < x
  elseif op == "<=" then return value <= x
  elseif op == ">" then return value > x end
  return value >= x
end

-- Step points for the window: its edge and the edge just past it.
function Display.RemainingWindowPoints(_, x)
  return {x, x + REMAIN_EPS}
end

local missingTypes = {icon = true, aurabar = true, progresstexture = true, text = true, texture = true}
Display.missingTypes = missingTypes

local function NeedsMissing(trigger)
  local showOn = Display.ShowOn(trigger)
  return showOn == "showOnMissing" or showOn == "showAlways"
end
Display.NeedsMissing = NeedsMissing

-- Aura(s) Missing and Always on unit frames or nameplates: one Missing part per unit.
function Display.UnitPlacedMissing(data, trigger)
  trigger = trigger or (data and Display.GetTrigger(data))
  if type(trigger) ~= "table" or not data or not NeedsMissing(trigger) then return false end
  local mode = Display.FrameAnchorType(data)
  if mode == "UNITFRAME" or mode == "NAMEPLATE" then return true end
  return not Display.FlowGroup(data) and Display.UsesNameplates(data)
end

-- A single aura is one aura at the region's corner.
local function DrawsOne(data)
  return Display.IsSingle(Display.GetTrigger(data), data)
end
Display.DrawsOne = DrawsOne

function Display.Growth(data)
  -- A Modern Aura Group sets the growth of all its displays.
  local flowGrowth = Display.FlowGrowth(data)
  if flowGrowth then return Display.VisibleGrowth(flowGrowth) end
  if DrawsOne(data) then return "RIGHT" end
  return data.blizzardAuraDisplay and data.blizzardAuraDisplay.growth or "RIGHT"
end

function Display.MaxAuras(data)
  local merged = Display.MergedMaxAuras and Display.MergedMaxAuras(data)
  if merged then return merged end
  return Display.RawMaxAuras(data)
end

function Display.RawMaxAuras(data)
  -- The Total Duration and Stack Count gates stack candidates: room for the
  -- right one among others.
  if Display.UsesGate(data) then return 10 end
  if DrawsOne(data) then return 1 end
  -- A Modern Aura Group sets the limit for all its displays.
  local limit = Display.FlowLimit(data)
  if limit then return limit end
  return data.blizzardAuraDisplay and data.blizzardAuraDisplay.maxIcons or 10
end

function Display.PreviewShowsMissing(data)
  local trigger = Display.GetTrigger(data)
  return Display.IsSingle(trigger) and Display.ShowOn(trigger) == "showOnMissing"
end

-- The icon drawn while the aura is absent or by the Remaining Time icon: the
-- manual icon, else the first selected spell's icon. Plain spell data only.
function Display.SingleIcon(data)
  if data.iconSource == 0 and data.displayIcon and data.displayIcon ~= "" then return data.displayIcon end
  -- A Spell List may picture the display itself.
  local list = Display.SpellList(Display.GetTrigger(data))
  if list and list.icon then return list.icon end
  local id = Display.GetSpellIDs(Display.GetTrigger(data) or {}, false)[1]
  local texture = id and C_Spell.GetSpellTexture(id)
  if texture and not issecretvalue(texture) then return texture end
  return 134400
end

-- A secret answer keeps the display shown rather than guessing that the unit
-- is gone.
function Display.SingleUnitExists(trigger)
  local unit = trigger and trigger.unit or "player"
  if unit == "player" then return true end
  if unit == "member" then
    unit = Display.SpecificUnit(trigger)
    if not unit then return false end
  end
  local ok, exists = pcall(UnitExists, unit)
  if not ok or issecretvalue(exists) then return true end
  return exists == true
end

-- Countdown colour rules may come from any Aura (Modern) trigger; all of them
-- share the one binding that the Remaining Time window also uses.
local function HasRemainingPercentConditions(data)
  for _, condition in ipairs(data.conditions or {}) do
    local check = condition.check
    if check and Display.NativeConditionKind(data, check) and Display.IsNativeDurationCondition(check) and check.variable ~= "faAuraRemaining" then
      return true
    end
  end
  return false
end

-- True when the display draws one unit in its own rectangle, as a Blizzard
-- Group needs. Several units would need one clone per unit.
function Display.FitsOneSlot(data, trigger)
  if not trigger or not Display.IsSingleUnit(trigger) then return false end
  return data.anchorFrameType ~= "UNITFRAME" and data.anchorFrameType ~= "NAMEPLATE"
end

function Display.InDynamicGroup(data)
  local parent = data and data.parent and WeakAuras.GetData(data.parent)
  while parent do
    if parent.regionType == "dynamicgroup" then return true end
    parent = parent.parent and WeakAuras.GetData(parent.parent)
  end
  return false
end

-- Pre-release test builds had a Mode setting and reused the Legacy fields;
-- those settings move to the dedicated fields.
function Display.MigrateSingle(data, trigger)
  if trigger.secretTracking == nil then return end
  if trigger.secretTracking == "single" then
    if trigger.secretShowOn == nil and Display.showOnValues[trigger.matchesShowOn] and trigger.matchesShowOn ~= "showOnActive" then
      trigger.secretShowOn = trigger.matchesShowOn
    end
    if trigger.secretUseRem == nil and trigger.useRem then
      trigger.secretUseRem, trigger.secretRemOperator, trigger.secretRem = true, trigger.remOperator, trigger.rem
    end
    data.blizzardAuraDisplay = data.blizzardAuraDisplay or {}
    data.blizzardAuraDisplay.maxIcons = 1
  end
  trigger.secretTracking = nil
end

-- Blizzard's containers refuse to pick auras by spell ID where that could
-- single out a secret aura: debuffs on friendly units and buffs on hostile
-- units (Blizzard_AuraContainerUtil, CanApplyIdentityCandidateFilters), unless
-- every selected spell is never secret. Target-like units can be either side.
local friendlyUnits = {player = true, pet = true, group = true, party = true, raid = true}
local hostileUnits = {boss = true, arena = true}

-- A spell's secrecy does not change during a session; cached per ID.
local neverSecret = {}
local function NeverSecret(ids)
  if #ids == 0 or not (C_Secrets and C_Secrets.GetSpellAuraSecrecy and Enum.SecrecyLevel) then return false end
  for _, id in ipairs(ids) do
    if neverSecret[id] == nil then
      local ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, id)
      neverSecret[id] = ok and not issecretvalue(level) and level == Enum.SecrecyLevel.NeverSecret
    end
    if not neverSecret[id] then return false end
  end
  return true
end

-- Returns "error" or "note" and the text for the spell ID section, or nil.
function Display.SpellIDFilterNote(trigger)
  if not (Display.UsesSpellIDs(trigger) or Display.UsesRankSpellIDs(trigger) or Display.UsesExcludedSpellIDs(trigger)) then return end
  local ids = Display.GetSpellIDs(trigger, true)
  if Display.UsesExcludedSpellIDs(trigger) then
    for _, value in ipairs(trigger.excludedAuraSpellIDs or {}) do
      if tonumber(value) then ids[#ids + 1] = tonumber(value) end
    end
  end
  if NeverSecret(ids) then return end
  local debuff = trigger.debuffType == "HARMFUL"
  local kind = debuff and "Debuffs" or "Buffs"
  local category = Display.UnitCategory(trigger)
  local label = trigger.unit == "member" and Display.SpecificUnit(trigger) or Display.units[trigger.unit] or trigger.unit
  if (debuff and friendlyUnits[category]) or (not debuff and hostileUnits[category]) then
    -- What does work there: the aura's own properties.
    if debuff and Display.friendlyDebuffUnits[category] then
      return "error", (L["Blizzard hides debuffs on %s from spell ID filters in combat: filter by Total Duration =, dispel type and flags instead."])
        :format(label)
    end
    return "error", (L["Blizzard hides %s on %s from spell ID filters in combat."])
      :format(kind:lower(), label)
  end
  if not friendlyUnits[category] and not hostileUnits[category] then
    return "note", ("%s selected by spell ID only match while the unit is %s.")
      :format(kind, debuff and "hostile" or "friendly")
  end
end

-- One short status line for the trigger editor: green when the selection works
-- in combat (with its one limit, if any), red with the reason when it does not.
local GREEN, ORANGE, RED = "|cff33ff99", "|cffff9933", "|cffff2020"
function Display.TriggerStatus(data, trigger)
  local problem = Display.Validate(data)
  -- Condition problems are a short red line of their own; the trigger works.
  if problem == "Incompatible condition." then return RED .. problem .. "|r" end
  if problem then return RED .. "Won't work:|r " .. problem end
  local severity, reason = Display.SpellIDFilterNote(trigger)
  -- Blizzard still plays Actions sounds for these spell IDs (AddAuraSound).
  if severity == "error" then return RED .. L["Won't work:"] .. "|r " .. reason .. " " .. ORANGE .. L["Sounds in Actions still play."] .. "|r" end
  local text = GREEN .. L["Works in combat."] .. "|r"
  if severity == "note" then
    text = text .. " " .. ORANGE .. (trigger.debuffType == "HARMFUL" and L["Hostile units only."] or L["Friendly units only."]) .. "|r"
  end
  if Display.InDynamicGroup(data) then
    text = text .. " " .. ORANGE .. L["In a Dynamic Group it keeps a fixed position; a Modern Aura Group is recommended."] .. "|r"
  end
  -- Only a list Icon with a Total Duration = / >= filter or a Remaining Time
  -- window still estimates the duration for its timed glow; the rest are exact.
  -- Only a list Icon with a Remaining Time window still estimates the
  -- duration for its timed glow (TimedGlowHolder); the rest are exact.
  local lateX = Display.LateGlowSpec(data, trigger)
  if lateX and data.regionType == "icon" and Display.RemainingWindow(trigger) and not Display.IsSingle(trigger, data) then
    local total = Display.LateGlowTotal(trigger)
    if not (total and total > lateX) then text = text .. " " .. ORANGE .. L["Glow starts once the aura's duration is known."] .. "|r" end
  end
  return text
end

-- Problems specific to the single-aura settings; nil when they can be drawn.
function Display.ValidateSingle(data, trigger)
  local totalProblem = Display.TotalFilterProblem(data, trigger)
  if totalProblem then return totalProblem end
  local stackProblem = Display.StackFilterProblem(data, trigger)
  if stackProblem then return stackProblem end
  local remainingProblem = Display.RemainingGateProblem(data, trigger)
  if remainingProblem then return remainingProblem end
  local fallbackProblem = Display.FallbackProblem(data)
  if fallbackProblem then return fallbackProblem end
  if not Display.IsSingle(trigger, data) then return end
  if not Display.IsSingleUnit(trigger) and not Display.UnitPlacedMissing(data, trigger) then
    return L["On the screen, Aura(s) Missing, Always and Remaining Time watch one unit: choose Player, Target, Focus, Pet, Target of Target, Target of Focus, Pet Target or a Specific Unit. Anchored to unit frames or nameplates, Missing and Always work for every unit."]
  end
  local showOn = Display.ShowOn(trigger)
  local op = Display.RemainingWindow(trigger)
  if UsesRemaining(trigger) and not op then
    return L["Remaining Time needs a comparison and a number of seconds of 0 or more."]
  end
  if NeedsMissing(trigger) or op then
    local label = op and L["Remaining Time"] or (L["Show On"] .. ": " .. Display.showOnValues[showOn])
    if op and data.regionType ~= "icon" then
      return label .. " is available for Icon displays. Use Show On: Aura(s) Found for other display types."
    end
    if not op and not missingTypes[data.regionType] then
      return label .. " is available for Icon, Bar, Progress Texture, Texture and Text displays."
    end
    if op and (Display.FrameAnchorType(data) == "UNITFRAME" or Display.FrameAnchorType(data) == "NAMEPLATE") then
      return label .. " cannot anchor to unit frames or nameplates. Anchor the aura to the screen or a frame."
    end
  end
  -- Blizzard never matches debuffs on you or your pet by spell ID while auras
  -- are secret, so a Missing icon would show even with the debuff present.
  if NeedsMissing(trigger) and trigger.debuffType == "HARMFUL" and (trigger.unit == "player" or trigger.unit == "pet")
    and (Display.UsesSpellIDs(trigger) or Display.UsesRankSpellIDs(trigger)) then
    return L["Debuffs on you or your pet can't be found by spell ID in combat: filter by Total Duration =, dispel type and flags instead."]
  end
  if op then
    if not Display.SupportsDurationColorCondition() then
      return L["This client cannot limit auras by Remaining Time."]
    end
    if HasRemainingPercentConditions(data) then
      return L["With Remaining Time, countdown conditions must use Remaining Time in seconds."]
    end
  end
end

-- How far the Missing clip reaches past the icon, for glows, borders and texts
-- placed outside it. The invisible group button is widened to match, so a
-- present aura still closes the clip completely.
local function MissingMargin(data, width, height)
  local margin = math.ceil(math.max(width, height)) * 2 + 64
  for _, element in ipairs(data.subRegions or {}) do
    local reach = math.max(math.abs(tonumber(element.anchorXOffset) or 0), math.abs(tonumber(element.anchorYOffset) or 0),
      math.abs(tonumber(element.text_anchorXOffset) or 0), math.abs(tonumber(element.text_anchorYOffset) or 0),
      math.abs(tonumber(element.glowXOffset) or 0), math.abs(tonumber(element.glowYOffset) or 0),
      math.abs(tonumber(element.xOffset) or 0), math.abs(tonumber(element.yOffset) or 0))
    if element.type == "subglow" then reach = reach + math.ceil(math.max(width, height) * (tonumber(element.glowScale) or 1)) end
    margin = math.max(margin, math.ceil(math.max(width, height)) + reach + 64)
  end
  return margin
end

local function MissingLayout(width, height, margin)
  return {elementWidth = width + 1 + 2 * margin, elementHeight = height}
end

-- Conditions from other triggers restore the display's own look; the Aura
-- Missing conditions stay on top of them.
function Display.KeepMissingDesaturated(native, data, gates)
  Display.ApplyMissingConditions(native, data, gates)
end

-- Draws the display's idle look on the static sample in the Missing clip.
-- gates: the region's condition gates (SecretAuraConditions.lua).
function Display.StyleMissingIcon(native, data, gates)
  if native.icon then native.icon:SetDesaturated(data.desaturate == true) end
  -- A removed "Aura Missing" alpha condition restores the full sample.
  native.conditionAlpha = nil
  Display.SetMissingVisible(native, native.visibleAlpha or 1)
  -- Highlights describe a present aura, except those of Aura Missing conditions.
  for _, entry in ipairs(native.conditionPreview or {}) do entry.texture:SetShown(entry.kind == "faAuraMissing") end
  Display.ApplyMissingConditions(native, data, gates)
  if native.cooldown then native.cooldown:Hide() end
  -- Dispel indicators describe the live aura's type, which an absent aura has not.
  for index, element in ipairs(data.subRegions or {}) do
    local entry = native.sharedElements and native.sharedElements[index]
    if entry and (element.type == "subcdmdispel" or element.type == "subcdmdispelborder") then
      if entry.texture then entry.texture:Hide() end
      if entry.dispelEdges then Private.DispelTypeDisplay.Hide(entry.dispelEdges) end
    end
  end
end

-- The countdown text of a plain list timer, in the display's %p settings
-- (minutes:seconds from a minute up, whole seconds below, decimals under the
-- dynamic threshold). The client's formatter objects only serve bound
-- aura text, so the text is composed here.
local function ListTimerText(remaining, element)
  if remaining <= 0 then return "" end
  if remaining >= 60 then return ("%d:%02d"):format(math.floor(remaining / 60), math.floor(remaining % 60)) end
  local threshold = element and tonumber(element.text_text_format_p_time_dynamic_threshold) or 0
  if threshold > 0 and remaining < threshold then
    return ("%." .. (element and tonumber(element.text_text_format_p_time_precision) or 1) .. "f"):format(remaining)
  end
  if element and element.text_text_format_p_time_legacy_floor then return tostring(math.floor(remaining)) end
  return tostring(math.ceil(remaining))
end

-- A spell list may carry a plain timer (SetAuraSpellList: expirationTime and
-- duration, ordinary numbers the aura read itself, e.g. a weapon enchant's
-- time left, which no aura provides). The Missing look of a Show On Always or
-- Missing icon then draws its swipe and its %p text from that timer; both
-- clear when it runs out.
local function ApplyListTimer(missing, data)
  local native = missing.native
  local button = native.button
  local list = Display.SpellList(Display.GetTrigger(data))
  local expires, duration = list and list.expirationTime, list and list.duration
  if not (expires and duration and data.regionType == "icon") then
    button:SetScript("OnUpdate", nil)
    return
  end
  local element
  for _, sub in ipairs(data.subRegions or {}) do
    if sub.type == "subtext" and sub.text_visible ~= false and Display.TextKind(sub.text_text) == "duration" then element = sub; break end
  end
  local cooldown = data.cooldown ~= false and native.cooldown or nil
  if cooldown then
    cooldown:SetCooldown(expires - duration, duration)
    cooldown:Show()
  end
  local function Tick(self, elapsed)
    self.listElapsed = (self.listElapsed or 0) + (elapsed or 1)
    if self.listElapsed < 0.05 then return end
    self.listElapsed = 0
    local remaining = expires - GetTime()
    for _, entry in ipairs(self.bindings.DurationText or {}) do entry.widget:SetText(ListTimerText(remaining, element)) end
    if remaining <= 0 then
      if cooldown then cooldown:Clear(); cooldown:Hide() end
      self:SetScript("OnUpdate", nil)
    end
  end
  button:SetScript("OnUpdate", Tick)
  Tick(button, 1)
end

local function StyleMissing(missing, region, data)
  local native = missing.native
  Display.StyleNative(native, data, region)
  native.button:ClearAllPoints()
  native.button:SetPoint("TOPLEFT", missing.slot or Display.ContentAnchor(region), "TOPLEFT")
  local trigger = Display.GetTrigger(data)
  local id = Display.GetSpellIDs(trigger, false)[1]
  local info = id and C_Spell.GetSpellInfo(id)
  local list = Display.SpellList(trigger)
  Display.FillSampleBindings(native.button, Display.SingleIcon(data), list and list.name or info and info.name or "", data, false)
  Display.StyleMissingIcon(native, data, region.secretAuraGates)
end

local function Warn(data, message)
  Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_single", message and "warning" or nil, message)
end

local function Followable(data, index)
  local entry = data.triggers and data.triggers[index]
  return type(entry) == "table" and type(entry.trigger) == "table" and entry.trigger.type ~= "secretAura"
end

local function DrivingIndex(data, trigger)
  local saved = Display.GetSavedTrigger(data)
  for index, entry in ipairs(data.triggers or {}) do
    if type(entry) == "table" and entry.trigger == saved then return index end
  end
end

local function FallbackPossible(data, trigger)
  return Display.IsSingleUnit(trigger) and missingTypes[data.regionType]
    and not (Display.FlowGroup and Display.FlowGroup(data))
    and Display.FrameAnchorType(data) ~= "UNITFRAME" and Display.FrameAnchorType(data) ~= "NAMEPLATE"
    and not (Display.RawShowOn(trigger) == "showOnActive" and trigger.secretUseRem == true)
end

function Display.FallbackChoice(data)
  local value = data.triggers and data.triggers.secretFallback
  if value == "none" then return "none" end
  return tonumber(value) or "next"
end

function Display.Fallback(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if type(trigger) ~= "table" or not FallbackPossible(data, trigger) then return end
  local m = DrivingIndex(data, trigger)
  if not m then return end
  local choice = Display.FallbackChoice(data)
  if choice == "none" then return end
  if choice ~= "next" then return choice ~= m and Followable(data, choice) and choice or nil end
  for index in ipairs(data.triggers) do
    if index ~= m and Followable(data, index) then return "next" end
  end
end

function Display.MigrateFallback(data)
  for _, entry in ipairs(type(data.triggers) == "table" and data.triggers or {}) do
    local trigger = type(entry) == "table" and entry.trigger
    if type(trigger) == "table" and trigger.secretMissingSource ~= nil then
      local index = tonumber(trigger.secretMissingSource)
      if index and data.triggers.secretFallback == nil then data.triggers.secretFallback = index end
      trigger.secretMissingSource = nil
    end
  end
end

function Display.FallbackProblem(data)
  local choice = Display.FallbackChoice(data)
  if type(choice) == "number" and not Followable(data, choice) then
    return L["Trigger Combination: the trigger chosen for when Aura (Modern) filters are not met no longer exists or is an Aura (Modern) trigger."]
  end
end

function Display.FoundFollow(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if type(trigger) ~= "table" or Display.RawShowOn(trigger) ~= "showOnActive" then return end
  return Display.Fallback(data, trigger)
end

function Display.MissingSource(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if type(trigger) ~= "table" then return end
  if Display.RawShowOn(trigger) ~= "showOnActive" and not NeedsMissing(trigger) then return end
  return Display.Fallback(data, trigger)
end

local function ResolveSource(region, data, source)
  if source ~= "next" then return source end
  local m = DrivingIndex(data)
  for index in ipairs(data.triggers or {}) do
    local state = region.states and region.states[index]
    if index ~= m and Followable(data, index) and type(state) == "table" and state.show then return index end
  end
end

local function CountdownElement(native, data, hide)
  local countdown
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subtext" and Display.TextKind(element.text_text) == "duration" then
      local entry = native.sharedElements and native.sharedElements[index]
      if entry and entry.text then entry.text:SetShown(not hide and element.text_visible ~= false) end
      if element.text_visible ~= false and not countdown then countdown = element end
    end
  end
  return countdown
end

local function ApplyIconSource(region, missing, data, source)
  local native = missing.native
  local cooldown = native.cooldown
  local state = source and region.states and region.states[source]
  if not (type(state) == "table" and state.show) then
    if missing.following then
      missing.following = nil
      native.icon:SetTexture(Display.SingleIcon(data))
      cooldown:Clear(); cooldown:Hide()
      CountdownElement(native, data, false)
    end
    return
  end
  missing.following = true
  if state.icon == nil or not pcall(native.icon.SetTexture, native.icon, state.icon) then
    native.icon:SetTexture(Display.SingleIcon(data))
  end
  local ok = false
  if state.progressType == "durationObject" and state.durationObject and cooldown.SetCooldownFromDurationObject then
    ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, state.durationObject, true)
  elseif state.progressType == "timed" then
    local duration, expiration = state.duration, state.expirationTime
    if type(duration) == "number" and type(expiration) == "number" and not issecretvalue(duration)
      and not issecretvalue(expiration) and duration > 0 and expiration ~= math.huge then
      ok = pcall(cooldown.SetCooldown, cooldown, expiration - duration, duration)
    end
  end
  if not ok then
    cooldown:Clear(); cooldown:Hide()
    CountdownElement(native, data, false)
    return
  end
  cooldown:SetDrawSwipe(data.cooldown ~= false and data.cooldownSwipe ~= false)
  cooldown:SetDrawEdge(data.cooldown ~= false and data.cooldownEdge == true)
  cooldown:SetReverse(data.inverse == true)
  local countdown = CountdownElement(native, data, true)
  if countdown then
    cooldown:SetHideCountdownNumbers(false)
    local numbers = cooldown:GetCountdownFontString()
    if numbers then Display.StyleText(numbers, native, Display.TextSettings(countdown), "text", 18, "CENTER", 0, 0) end
    local prefix = "text_text_format_p_time_"
    local format = countdown[prefix .. "format"]
    cooldown:SetCountdownFormatter(nil)
    if format ~= nil and format ~= -1 and Private.GetDurationTextFormatter then
      pcall(cooldown.SetCountdownFormatter, cooldown, Private.GetDurationTextFormatter(countdown[prefix .. "legacy_floor"] and 0 or 99,
        countdown[prefix .. "dynamic_threshold"] or 3, countdown[prefix .. "precision"] or 1, format == -2, format))
    end
  else
    cooldown:SetHideCountdownNumbers(data.cooldownTextDisabled ~= false)
  end
  cooldown:Show()
end

local function FollowDuration(missing, state)
  if state.progressType == "durationObject" and state.durationObject then return state.durationObject end
  if state.progressType ~= "timed" or not (C_DurationUtil and C_DurationUtil.CreateDuration) then return end
  local duration, expiration = state.duration, state.expirationTime
  if type(duration) ~= "number" or type(expiration) ~= "number" or issecretvalue(duration) or issecretvalue(expiration)
    or duration <= 0 or expiration == math.huge then return end
  missing.followDuration = missing.followDuration or C_DurationUtil.CreateDuration()
  if pcall(missing.followDuration.SetTimeFromStart, missing.followDuration, expiration - duration, duration) then
    return missing.followDuration
  end
end

local zeroDuration
local function ClearFollowBars(native)
  if not zeroDuration and C_DurationUtil and C_DurationUtil.CreateDuration then zeroDuration = C_DurationUtil.CreateDuration() end
  for _, entry in ipairs(native.button.bindings.DurationBar or {}) do
    local bar = entry.widget
    if zeroDuration and bar.SetTimerDuration then
      pcall(bar.SetTimerDuration, bar, zeroDuration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
    end
    bar:SetMinMaxValues(0, 6)
    bar:SetValue(0)
  end
end

local FOLLOW_TEXT_INTERVAL = 0.1
local function ApplyTimerSource(region, missing, data, source)
  local native = missing.native
  local button = native.button
  local state = source and region.states and region.states[source]
  local duration = type(state) == "table" and state.show and FollowDuration(missing, state)
  if not duration then
    if missing.following then
      missing.following = nil
      button:SetScript("OnUpdate", nil)
      ClearFollowBars(native)
      for _, entry in ipairs(button.bindings.DurationText or {}) do entry.widget:SetText("") end
      native.icon:SetTexture(Display.SingleIcon(data))
    end
    return
  end
  missing.following = true
  if state.icon == nil or not pcall(native.icon.SetTexture, native.icon, state.icon) then
    native.icon:SetTexture(Display.SingleIcon(data))
  end
  local direction = data.inverse and Enum.StatusBarTimerDirection.ElapsedTime or Enum.StatusBarTimerDirection.RemainingTime
  for _, entry in ipairs(button.bindings.DurationBar or {}) do
    local bar = entry.widget
    if bar.SetTimerDuration then pcall(bar.SetTimerDuration, bar, duration, Enum.StatusBarInterpolation.Immediate, direction) end
  end
  local texts = button.bindings.DurationText or {}
  if #texts == 0 then button:SetScript("OnUpdate", nil); return end
  local modifier = Enum.DurationTimeModifier and Enum.DurationTimeModifier.RealTime
  local fallback = Private.GetDurationTextFormatter and Private.GetDurationTextFormatter(99, 0, 0)
  local elapsed = FOLLOW_TEXT_INTERVAL
  button:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < FOLLOW_TEXT_INTERVAL then return end
    elapsed = 0
    Private.StartProfileSystem("aura (modern) - missing text")
    for _, entry in ipairs(texts) do
      local formatter = entry.options and entry.options.textFormatter or fallback
      local ok, text = pcall(duration.FormatRemainingDuration, duration, formatter, modifier)
      entry.widget:SetText(ok and text or "")
    end
    Private.StopProfileSystem("aura (modern) - missing text")
  end)
end

local function ApplyMissingSource(region, missing, data, source)
  source = ResolveSource(region, data, source)
  if data.regionType == "icon" then ApplyIconSource(region, missing, data, source)
  else ApplyTimerSource(region, missing, data, source) end
  Display.SetMissingVisible(missing.native, (not missing.foundMode or missing.following) and 1 or 0)
end

-- Paints the Missing samples again after a condition gate changed
-- (Display.SetConditionGate); the samples are the addon's own frames.
function Display.RestyleMissing(region)
  local native = region.blizzardAuraDisplay
  if not native or not native.active then return end
  local data = native.data
  for _, instance in ipairs(native.instances or {}) do
    local missing = instance.single and instance.single.missing
    if missing and missing.active and missing.native then
      StyleMissing(missing, region, data)
      local source = Display.MissingSource(data)
      if source or missing.foundMode then ApplyMissingSource(region, missing, data, source) end
    end
  end
end

function Display.UpdateMissingSource(region)
  local native = region.blizzardAuraDisplay
  if not native or not native.active then return end
  local data = native.data
  local source = Display.MissingSource(data)
  for _, instance in ipairs(native.instances or {}) do
    local missing = instance.single and instance.single.missing
    if missing and missing.active and (source or missing.following) then
      ApplyMissingSource(region, missing, data, source)
    end
  end
end
-- Cleared by Apply before styling; any part that fails sets it again.
Display.ClearSingleWarning = function(data) Warn(data) end

-- In a Modern Aura Group, a second invisible container marks where the next
-- display starts: one icon further on while the aura is missing
-- (SecretAuraFlow.lua). It follows the Missing container's unit.
local PRESENCE_GROUP = "FAPresence"
local function EnsurePresence(missing, region, data, filter, candidates, perUnit)
  missing.presenceActive = false
  if not Display.FlowGroup(data) then
    if missing.presence then missing.presence:SetEnabled(false); missing.presence:Hide() end
    return
  end
  if missing.presenceFailed then return end
  local presence = missing.presence
  if not presence then
    presence = Display.CreateAuraContainer(region, data)
    presence:SetEnabled(false)
    presence:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    -- Placed on the region first, like every aura container; moved below.
    presence:SetPoint("TOPLEFT", region, "TOPLEFT")
    local layout = Display.FlowPresenceSize(data)
    local ok, err = pcall(presence.AddAuraGroup, presence, PRESENCE_GROUP, filter, {
      candidateFilters = candidates,
      maxFrameCount = 1,
      layout = layout,
      initializeFrame = function(button)
        -- Draws nothing; only the container's size is used.
        button:SetSize(layout.elementWidth, layout.elementHeight)
        button:SetAlpha(0)
        button:EnableMouse(false)
      end,
    })
    if not ok then
      presence:Hide()
      missing.presenceFailed = true
      Warn(data, L["Blizzard could not create the Modern Aura Group spacing: %s"]:format(tostring(err)))
      return
    end
    missing.presence = presence
  else
    local layout = Display.FlowPresenceSize(data)
    presence:SetAuraGroupFilterString(PRESENCE_GROUP, filter)
    presence:SetAuraGroupCandidateFilters(PRESENCE_GROUP, candidates)
    presence:SetAuraGroupLayout(PRESENCE_GROUP, layout)
    presence:SetAuraGroupEnabled(PRESENCE_GROUP, true)
  end
  missing.presenceBoundUnit = nil
  if perUnit then
    missing.presenceActive = true
    return
  end
  if not Display.AnchorFlowPresence(region, data, presence) then
    -- Refused: the display takes a fixed icon in the group instead.
    presence:SetEnabled(false); presence:Hide()
    Warn(data, L["Blizzard refused the Modern Aura Group spacing; this display keeps a fixed space."])
    return
  end
  missing.presenceActive = true
end

-- Erased Missing look. Where the client can render a frame's subtree into a
-- frame buffer (SetIsFrameBuffer, SetFlattensRenderLayers), a Show On Always
-- icon draws its aura slot and its Missing look in one such "stage": the
-- Missing look lies beneath, and each aura button carries a texture drawn
-- with blending disabled (Display.StyleEraser) that overwrites the buffer
-- with nothing wherever the button is. The Missing look therefore disappears
-- in the very frame the aura's button appears, with no second container
-- asking the client whether the aura is present, nothing to refresh on a
-- unit change, and no frame in which both or neither are drawn. Other
-- display types, Show On Missing, unit frames, nameplates and Modern Aura
-- Groups keep the presence container.
local FRAME_BUFFER = UIParent ~= nil and UIParent.SetIsFrameBuffer ~= nil and UIParent.SetFlattensRenderLayers ~= nil
function Display.ErasedMissing(data, trigger, perUnit)
  return FRAME_BUFFER and data.regionType == "icon" and not perUnit and not Display.FlowGroup(data)
    and Display.ShowOn(trigger) == "showAlways"
end

-- The stage of a display whose Missing look is erased, for RefreshUnits:
-- the aura slot container is parented to it.
function Display.MissingStage(instance)
  local single = instance.single
  local missing = single and single.missing
  return missing and missing.active and missing.erased and single.stage or nil
end

-- Called by Style for every aura button of a display: the eraser covers the
-- Missing look's whole reach (its margin) while the look is erased.
function Display.StyleEraser(native, data)
  local eraser = native.eraser
  if not eraser then return end
  local trigger = Display.GetTrigger(data)
  if not (trigger and Display.ErasedMissing(data, trigger, Display.UnitPlacedMissing(data, trigger))) then
    eraser:Hide()
    return
  end
  local width, height = Display.Dimensions(data)
  local margin = MissingMargin(data, width, height)
  eraser:ClearAllPoints()
  eraser:SetPoint("TOPLEFT", native.button, "TOPLEFT", -margin, margin)
  eraser:SetPoint("BOTTOMRIGHT", native.button, "BOTTOMRIGHT", margin, -margin)
  eraser:Show()
end

-- The Missing part: its own container, so its width depends only on presence.
local function EnsureMissing(single, region, data, trigger, instance)
  local width, height = Display.Dimensions(data)
  local margin = MissingMargin(data, width, height)
  local filter, candidates = Display.FilterString(trigger), Display.CandidateFilters(data)
  -- A container Blizzard refused is kept aside rather than recreated on every
  -- Apply; the warning stays until the next /reload.
  if single.missingFailed then
    Warn(data, single.missingFailed)
    return
  end
  local missing = single.missing
  local perUnit = instance ~= nil
  if missing and (missing.perUnit == true) ~= perUnit then
    for _, key in ipairs({"container", "clip", "presence", "flowShadow"}) do Display.RetireFrame(missing[key]) end
    single.missing, missing = nil, nil
  end
  if not missing then
    missing = {perUnit = perUnit}
    local container = Display.CreateAuraContainer(region, data, perUnit)
    container:SetEnabled(false)
    container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    -- TOPLEFT only: Blizzard sizes the container from the group; nothing reads it.
    container:SetPoint("TOPLEFT", region, "TOPLEFT")
    local ok, err = pcall(container.AddAuraGroup, container, MISSING_GROUP, filter, {
      candidateFilters = candidates,
      maxFrameCount = 1,
      layout = MissingLayout(width, height, margin),
      initializeFrame = function(button)
        -- These buttons draw nothing; only the container's width is used.
        button:SetSize(width + 1 + 2 * margin, height)
        button:EnableMouse(false)
      end,
    })
    if not ok then
      container:Hide()
      single.missingFailed = L["Blizzard could not create the Aura(s) Missing display: %s"]:format(tostring(err))
      Warn(data, single.missingFailed)
      return
    end
    -- Frames anchored to a container that owns an aura group must opt out of
    -- untrusted layout scripts (Blizzard_CustomAuraContainer). Everything inside
    -- the clip is created in place, never re-parented into it.
    local clip = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
    Display.ClipChildren(clip)
    clip:EnableMouse(false)
    missing.container, missing.clip = container, clip
    missing.native = Display.CreateSampleNative(clip)
    single.missing = missing
  else
    missing.container:SetAuraGroupFilterString(MISSING_GROUP, filter)
    missing.container:SetAuraGroupCandidateFilters(MISSING_GROUP, candidates)
    missing.container:SetAuraGroupLayout(MISSING_GROUP, MissingLayout(width, height, margin))
    missing.container:SetAuraGroupEnabled(MISSING_GROUP, true)
  end
  -- Absent: the container is 1 px wide and the clip spans the icon plus margin.
  -- Present: its right edge moves onto the clip's right edge, closing it.
  -- Erased (Display.ErasedMissing): the clip always spans the icon inside the
  -- stage, and the presence container is not used.
  missing.erased = Display.ErasedMissing(data, trigger, perUnit)
  local anchor
  missing.container:ClearAllPoints()
  if perUnit then
    local slot = instance.missingSlot
    if not slot then
      slot = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
      slot:EnableMouse(false)
      -- On the pixel grid, like a display's start frame (SecretAuraFlow.lua).
      if slot.SetRoundLayoutToNearestPixel then slot:SetRoundLayoutToNearestPixel(true) end
      instance.missingSlot = slot
    end
    slot:SetSize(width, height)
    missing.slot, anchor = slot, slot
    missing.container:SetPoint("TOPLEFT", slot, "TOPLEFT")
  else
    missing.slot = nil
    anchor = Display.ContentAnchor(region)
    if not Display.AnchorToContent(missing.container, "TOPLEFT", region, "TOPLEFT") then anchor = region end
  end
  local clip = missing.clip
  clip:ClearAllPoints()
  if missing.erased then
    local stage = single.stage
    if not stage then
      stage = CreateFrame("Frame", nil, region)
      stage:EnableMouse(false)
      stage:SetFlattensRenderLayers(true)
      stage:SetIsFrameBuffer(true)
      single.stage = stage
    end
    -- The stage is a frame buffer: drawn at a fraction of a pixel, it moves
    -- everything in it off the grid. Its corners are a whole number of
    -- pixels from the display, and snapped by the display's own fraction
    -- (a 49-unit icon centred on the screen starts at half a pixel); at
    -- login, with no place yet, the snap is repeated a frame later.
    local px = PixelsPerUnit(region)
    local stageMargin = px and math.ceil(margin * px) / px or margin
    local function AnchorStage(attempt)
      if attempt > 0 and not missing.active then return end
      local snapX, snapY, placed = 0, 0, true
      if px then
        local ok, left, top = pcall(function() return region:GetLeft(), region:GetTop() end)
        if ok and type(left) == "number" and type(top) == "number" and not issecretvalue(left) and not issecretvalue(top) then
          snapX = (math.floor(left * px + 0.5) - left * px) / px
          snapY = (math.floor(top * px + 0.5) - top * px) / px
        elseif ok and left == nil then
          placed = false
        end
      end
      stage:ClearAllPoints()
      stage:SetPoint("TOPLEFT", region, "TOPLEFT", -stageMargin + snapX, stageMargin + snapY)
      stage:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", stageMargin + snapX, -stageMargin + snapY)
      if not placed and attempt < 5 then C_Timer.After(0, function() AnchorStage(attempt + 1) end) end
    end
    AnchorStage(0)
    stage:SetFrameLevel(region:GetFrameLevel())
    stage:Show()
    if clip:GetParent() ~= stage then clip:SetParent(stage) end
    clip:SetAllPoints(stage)
    -- Beneath the aura slot's buttons, which sit two levels above the stage.
    clip:SetFrameLevel(stage:GetFrameLevel())
  else
    if single.stage then single.stage:Hide() end
    if clip:GetParent() ~= region then clip:SetParent(region) end
    -- The clip's corners a whole number of pixels from the icon's box, so its
    -- origin is on the pixel grid: what a clip holds is rounded against the
    -- clip, and a clip at a fraction of a pixel drew the icon a pixel off.
    local px = PixelsPerUnit(anchor)
    local clipMargin = px and math.ceil(margin * px) / px or margin
    -- A display on its own can sit between pixels (a 49-unit icon centred
    -- on the screen starts at half a pixel); the clip's corner is then moved
    -- by that fraction onto a whole pixel. In a group the anchor is already
    -- on the grid, and its place may be secret: then no correction. At
    -- login the display has no place yet; the anchoring is then repeated a
    -- frame later, when it has.
    local function AnchorClip(attempt)
      if not missing.active and attempt > 0 then return end
      local snapX, snapY, placed = 0, 0, true
      if px then
        local ok, left, top = pcall(function() return anchor:GetLeft(), anchor:GetTop() end)
        if ok and type(left) == "number" and type(top) == "number" and not issecretvalue(left) and not issecretvalue(top) then
          snapX = (math.floor(left * px + 0.5) - left * px) / px
          snapY = (math.floor(top * px + 0.5) - top * px) / px
        elseif ok and left == nil then
          placed = false
        end
      end
      if Locked(clip) then return end
      clip:ClearAllPoints()
      clip:SetPoint("TOPLEFT", missing.container, "TOPRIGHT", -1 - clipMargin + snapX, clipMargin + snapY)
      clip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", clipMargin + snapX, -clipMargin + snapY)
      if not placed and attempt < 5 then C_Timer.After(0, function() AnchorClip(attempt + 1) end) end
    end
    AnchorClip(0)
    clip:SetFrameLevel(region:GetFrameLevel() + 1)
  end
  EnsurePresence(missing, region, data, filter, candidates, perUnit)
  missing.container:SetFrameLevel(region:GetFrameLevel() + 1)
  StyleMissing(missing, region, data)
  missing.active = true
  -- A plain list timer runs the look's countdown; otherwise it has none.
  ApplyListTimer(missing, data)
  if missing.following then ClearFollowBars(missing.native) end
  missing.following = nil
  missing.foundMode = single.foundMode == true
  Display.SetMissingVisible(missing.native, 1)
  local source = Display.MissingSource(data, trigger)
  if source or missing.foundMode then ApplyMissingSource(region, missing, data, source) end
end

local function DisableMissing(single)
  local missing = single.missing
  if not missing or not missing.active or Locked(missing.container) then return end
  missing.active = false
  for _, key in ipairs({"presence", "flowShadow"}) do
    if missing[key] then
      missing[key]:SetEnabled(false)
      missing[key]:Hide()
    end
  end
  missing.container:SetEnabled(false)
  missing.container:Hide()
  pcall(missing.container.SetAuraGroupEnabled, missing.container, MISSING_GROUP, false)
  missing.clip:Hide()
  missing.boundUnit = nil
end

-- A Step colour curve over the remaining duration: the colour inside the
-- window, the same colour with alpha 0 outside it. Two points: start and edge.
local function RemainingCurve(op, x, r, g, b, a)
  local curve = C_CurveUtil.CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  local below = op == "<" or op == "<="
  local edge = (op == "<=" or op == ">") and x + REMAIN_EPS or x
  local on, off = CreateColor(r, g, b, a), CreateColor(r, g, b, 0)
  if edge > 0 then curve:AddPoint(0, below and on or off) end
  curve:AddPoint(edge, below and off or on)
  return curve
end

local function Units(value) return math.floor((tonumber(value) or 0) * TEXCOORD_UNITS + 0.5) end

-- Inline texture markup: path, height, width, offsets, texture size, crop and
-- vertex colour. Opacity comes from the duration text's colour curve; its RGB
-- never tints inline textures, so the colour is written into the markup.
-- Markup wants the path without its extension, which SetTexture accepts.
local function TextureMarkup(texture, width, height, left, right, top, bottom, color)
  local path = tostring(texture):gsub("%.[tT][gG][aA]$", ""):gsub("%.[bB][lL][pP]$", "")
  local r, g, b = 255, 255, 255
  if type(color) == "table" then
    r = math.floor(math.max(0, math.min(1, color[1] or 1)) * 255 + 0.5)
    g = math.floor(math.max(0, math.min(1, color[2] or 1)) * 255 + 0.5)
    b = math.floor(math.max(0, math.min(1, color[3] or 1)) * 255 + 0.5)
  end
  return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(path, height, width,
    TEXCOORD_UNITS, TEXCOORD_UNITS, Units(left), Units(right), Units(top), Units(bottom), r, g, b)
end

-- One aura slot on the list's own container. It picks the first matching aura
-- by the same sort as the list, so both agree on which aura is shown. Its
-- widgets anchor inside the slot button, which is sized and placed on the
-- region at configuration time.
local function EnsureSlot(single, instance, region, key, trigger, data, init)
  local container = instance.container
  local filter, candidates = Display.FilterString(trigger), Display.CandidateFilters(data)
  single.slots = single.slots or {}
  local slot = single.slots[key]
  if not slot then
    slot = {}
    local ok, err = pcall(container.AddAuraSlot, container, key, filter, {
      candidateFilters = candidates,
      initializeFrame = function(button)
        -- Runs inside AddAuraSlot, before Blizzard restricts the button.
        slot.button = button
        button:EnableMouse(false)
        button:SetAllPoints(Display.ContentAnchor(region))
        if init then init(button, slot) end
      end,
    })
    if not ok or not slot.button then
      Warn(data, L["Blizzard could not create the Remaining Time display: %s"]:format(tostring(err)))
      return
    end
    single.slots[key] = slot
  end
  -- Reconfigure disabled, then enable with the current filters.
  container:SetAuraSlotEnabled(key, false)
  local width, height = Display.Dimensions(data)
  slot.button:ClearAllPoints()
  slot.button:SetSize(width, height)
  slot.button:SetPoint("TOPLEFT", Display.ContentAnchor(region), "TOPLEFT")
  container:SetAuraSlotFilterString(key, filter)
  container:SetAuraSlotCandidateFilters(key, candidates)
  container:SetAuraSlotSortMethod(key, Display.SortOrder(data, trigger))
  slot.used = true
  return slot
end

local function FirstElement(data, matches)
  for index, element in ipairs(data.subRegions or {}) do
    if not Display.IsDetachedElement(data, element) and matches(element) then return element, index end
  end
end

-- The artwork of a Remaining Time display is drawn as texture markup inside a
-- text, so it is sized and placed in units of that text. The text lives in a
-- frame scaled so that one of its units is one screen pixel: the artwork then
-- has whole-pixel sizes and lands on the pixel grid, as a native icon does.
local function PixelFrame(slot, region, corner)
  local px = PixelsPerUnit(Display.ContentAnchor(region))
  if not slot.pixel then
    slot.pixel = CreateFrame("Frame", nil, slot.button)
    slot.pixel:EnableMouse(false)
  end
  slot.pixel:SetScale(px and 1 / px or 1)
  slot.pixel:ClearAllPoints()
  -- From the button's corner on the pixel grid; centred, a 43-pixel icon in
  -- a 43.2-pixel button would start a fraction of a pixel in.
  slot.pixel:SetPoint(corner or "TOPLEFT", slot.button, corner or "TOPLEFT")
  slot.pixel:SetSize(1, 1)
  return slot.pixel, px or 1
end

-- A texture in a text does not render at its stated size (the game scales it
-- with the font), so the markup is chosen by measuring: the sizes whose
-- rendered width and height, in a plain invisible copy of the text, come
-- closest to the pixels wanted. Returns the markup and its rendered height.
local function FitMarkup(slot, frame, texture, w, h, left, right, top, bottom, color)
  if not slot.probe then
    slot.probe = frame:CreateFontString(nil, "ARTWORK")
    slot.probe:SetAlpha(0)
  end
  local probe = slot.probe
  -- Shown again after ReleaseSlotDrawing hid it (it stays at alpha 0).
  probe:Show()
  probe:SetFont(STANDARD_TEXT_FONT, 12, "")
  probe:SetWordWrap(false)
  probe:ClearAllPoints()
  probe:SetPoint("TOPLEFT", frame, "TOPLEFT")
  local function Measure(n, m)
    probe:SetText(TextureMarkup(texture, n, m, left, right, top, bottom, color))
    local pw, ph = probe:GetStringWidth(), probe:GetStringHeight()
    if type(pw) ~= "number" or type(ph) ~= "number" or issecretvalue(pw) or issecretvalue(ph) then return end
    return pw, ph
  end
  local bestW, bestH, errW, errH = w, h, math.huge, math.huge
  for n = math.max(1, w - 3), w + 3 do
    local pw = Measure(n, h)
    if pw and math.abs(pw - w) < errW then bestW, errW = n, math.abs(pw - w) end
  end
  for m = math.max(1, h - 3), h + 3 do
    local _, ph = Measure(bestW, m)
    if ph and math.abs(ph - h) < errH then bestH, errH = m, math.abs(ph - h) end
  end
  local _, renderedH = Measure(bestW, bestH)
  probe:SetText("")
  return TextureMarkup(texture, bestW, bestH, left, right, top, bottom, color), renderedH or h
end

-- The text's line is taller than a thin texture and centres the texture in
-- it, so the text is anchored by its vertical middle at the artwork's middle
-- (half the artwork's pixel height from the corner it hangs off). It always
-- starts at its left, a whole pixel in from a right corner, since a texture
-- renders a little narrower than asked and would straddle a pixel if its
-- right end were pinned instead.
local function AnchorArtwork(text, frame, corner, w, h)
  local down = corner:find("TOP") and -1 or 1
  local x = corner:find("RIGHT") and -w or 0
  text:ClearAllPoints()
  text:SetPoint("LEFT", frame, corner, x, down * h / 2)
end

-- ForeverAuras: a slot that is no longer configured (the Remaining Time window
-- removed, a Border or Texture element deleted, a glow condition dropped) only
-- stopped matching auras; its gate text, inline artwork, swipe, borders and
-- clip kept what Blizzard last drew into them, and a cleared binding leaves the
-- text's last string in place. Everything it drew is blanked and hidden here;
-- EnsureRemaining, Artwork and EnsureConditionGlow show it again when used.
local function ReleaseSlotDrawing(slot)
  local button = slot.button
  if button then
    pcall(button.ClearDurationText, button)
    pcall(button.ClearDurationCooldown, button)
  end
  for _, key in ipairs({"gate", "text", "probe"}) do
    local text = slot[key]
    if text then text:SetText(""); text:Hide() end
  end
  if slot.cooldown then slot.cooldown:Clear(); slot.cooldown:Hide() end
  for _, key in ipairs({"art", "clip", "holder"}) do
    if slot[key] then slot[key]:Hide() end
  end
  for _, entry in pairs(slot.borders or {}) do
    if entry.border then entry.border:Hide() end
  end
end

-- Remaining Time: the list keeps drawing the aura (its countdown and glow are
-- limited to the range by Blizzard, see StyleRemainingList); this slot adds the
-- display's icon as inline artwork whose opacity follows the same range.
local remainingGateCurve
-- A Glow element turned on by a "Remaining Time < X" condition, on an Icon
-- with a Remaining Time window: its own aura slot, whose hidden text (the
-- same formatter gate as the icon's) is a block while fewer than X seconds
-- are left and empty otherwise; the clip hung on that text holds the glow,
-- centred on the icon's art. Exact for every rank, as the icon's window is.
local function EnsureConditionGlow(single, instance, region, data, trigger, index, element, seconds, icon)
  local key = "FAGlow" .. index
  local slot = EnsureSlot(single, instance, region, key, trigger, data, function(button, me)
    me.clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    Display.ClipChildren(me.clip)
    me.clip:SetClipsChildren(true)
    me.holder = CreateFrame("Frame", nil, me.clip)
    me.holder:EnableMouse(false)
    me.gate = button:CreateFontString(nil, "BACKGROUND")
  end)
  if not slot or not slot.clip then return end
  local width, height = Display.Dimensions(data)
  local margin = Display.GlowMargin(width, height, element)
  slot.button:ClearAllPoints()
  slot.button:SetAllPoints(icon.button)
  local size, fill, gateMargin = Display.GateFill(width + 2 * margin, height + 2 * margin)
  local formatter = Display.GateFormatter(0, seconds, fill)
  if not formatter then slot.used = false; return end
  if not remainingGateCurve then
    remainingGateCurve = C_CurveUtil.CreateColorCurve()
    remainingGateCurve:SetType(Enum.LuaCurveType.Step)
    remainingGateCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
  end
  local gate = slot.gate
  gate:SetFont(STANDARD_TEXT_FONT, size, "")
  gate:SetWordWrap(false)
  gate:SetWidth(0)
  gate:ClearAllPoints()
  gate:SetJustifyH("LEFT")
  -- The run of W's spans the glow's reach (margin) plus the gate's own margin.
  gate:SetPoint("LEFT", slot.button, "LEFT", -margin - gateMargin, 0)
  pcall(slot.button.ClearDurationText, slot.button)
  local ok, err = pcall(slot.button.SetDurationText, slot.button, gate, {
    textFormat = {formatString = "{}", components = {{property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = formatter}}},
    textColor = {curve = remainingGateCurve, property = Enum.DurationTextBindingProperty.RemainingDuration},
  })
  if not ok then
    Warn(data, "Blizzard refused the Remaining Time glow: " .. tostring(err))
    slot.used = false
    return
  end
  gate:Show()
  Display.AnchorGateClip(slot.clip, gate, slot.button, margin + gateMargin)
  -- ForeverAuras: shown again after ReleaseSlotDrawing hid it.
  slot.clip:Show()
  slot.holder:ClearAllPoints()
  slot.holder:SetAllPoints(icon.button)
  slot.holder:Show()
  slot.glows = slot.glows or {}
  slot.glows[index] = slot.glows[index] or {}
  Display.StyleElementGlow(slot.glows[index], slot.button, slot.holder, icon.art, setmetatable({glow = true}, {__index = element}), width, height)
  pcall(slot.clip.SetFrameLevel, slot.clip, icon.cooldown:GetFrameLevel() + 2)
  instance.container:SetAuraSlotEnabled(key, true)
end

local function EnsureRemaining(single, instance, region, data, trigger, op, x)
  local icon = EnsureSlot(single, instance, region, SLOT_ICON, trigger, data)
  if not icon then return false end
  local width, height = Display.Dimensions(data)
  local color = data.color or {1, 1, 1, 1}
  local left, right, top, bottom = Display.IconTexCoords(data)
  -- The icon and its Border elements are real frames, drawn exactly as on a
  -- native button (the same border code, rounded to pixels), inside a clip
  -- that Blizzard's timer opens: a hidden text that is a large block of
  -- letters inside the Remaining Time window and empty outside it sizes the
  -- clip (as the swipe's and the gates' clips are). Nothing is drawn as
  -- texture markup, whose placement in a text is not exact to the pixel.
  if not icon.clip then
    icon.clip = CreateFrame("Frame", nil, icon.button, "DisableUntrustedLayoutScriptsTemplate")
    Display.ClipChildren(icon.clip)
    icon.art = CreateFrame("Frame", nil, icon.clip, "DisableUntrustedLayoutScriptsTemplate")
    icon.art:EnableMouse(false)
    if icon.art.SetRoundLayoutToNearestPixel then icon.art:SetRoundLayoutToNearestPixel(true) end
    icon.tex = icon.art:CreateTexture(nil, "ARTWORK")
    icon.tex:SetAllPoints(icon.art)
    -- The swipe lives on the icon's frame, under the borders (made after it),
    -- as an Icon's cooldown is under its border.
    icon.cooldown = CreateFrame("Cooldown", nil, icon.art, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.art)
    icon.cooldown:SetDrawBling(false)
    icon.cooldown:SetHideCountdownNumbers(true)
    icon.gate = icon.button:CreateFontString(nil, "BACKGROUND")
    icon.borders = {}
  end
  if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.DurationTextBindingProperty) then return false end
  local lower, upper = Display.RemainingRange(trigger)
  local size, fill, margin = Display.GateFill(width, height)
  local formatter = lower and Display.GateFormatter(lower, upper, fill)
  if not formatter then return false end
  if not remainingGateCurve then
    remainingGateCurve = C_CurveUtil.CreateColorCurve()
    remainingGateCurve:SetType(Enum.LuaCurveType.Step)
    remainingGateCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
  end
  local gate, clip, art = icon.gate, icon.clip, icon.art
  gate:SetFont(STANDARD_TEXT_FONT, size, "")
  gate:SetWordWrap(false)
  gate:SetWidth(0)
  -- The clip's origin stays on the button's pixel grid: its left, top and
  -- bottom are the button's with a whole-pixel margin, and only its right
  -- edge follows the hidden text (empty, the clip ends before the button;
  -- filled, well past it). A clip hung on a vertically centred text sits
  -- at a fraction of a pixel, and what it holds was drawn a pixel off.
  local gatePx = PixelsPerUnit(icon.button)
  local gateMargin = gatePx and math.ceil(margin * gatePx) / gatePx or margin
  -- A display on its own can sit between pixels; the clip's corner is moved
  -- by that fraction onto a whole pixel (as the Missing clip is).
  local function GateSnap()
    local snapX, snapY, placed = 0, 0, true
    if gatePx then
      local anchorFrame = Display.ContentAnchor(region)
      local ok, left, top = pcall(function() return anchorFrame:GetLeft(), anchorFrame:GetTop() end)
      if ok and type(left) == "number" and type(top) == "number" and not issecretvalue(left) and not issecretvalue(top) then
        snapX = (math.floor(left * gatePx + 0.5) - left * gatePx) / gatePx
        snapY = (math.floor(top * gatePx + 0.5) - top * gatePx) / gatePx
      elseif ok and left == nil then
        placed = false
      end
    end
    return snapX, snapY, placed
  end
  local snapX, snapY, placed = GateSnap()
  gate:ClearAllPoints()
  gate:SetJustifyH("LEFT")
  gate:SetPoint("TOPLEFT", icon.button, "TOPLEFT", -gateMargin + snapX, gateMargin + snapY)
  icon.button:ClearDurationText()
  -- A refused binding would leave the display empty: report it on the aura.
  local okIcon, iconErr = pcall(icon.button.SetDurationText, icon.button, gate, {
    textFormat = {formatString = "{}", components = {{property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = formatter}}},
    textColor = {curve = remainingGateCurve, property = Enum.DurationTextBindingProperty.RemainingDuration},
  })
  if not okIcon then
    Warn(data, "Blizzard refused the Remaining Time icon: " .. tostring(iconErr))
    return false
  end
  gate:Show()
  clip:ClearAllPoints()
  local function AnchorGateClip(sx, sy)
    gate:ClearAllPoints()
    gate:SetPoint("TOPLEFT", icon.button, "TOPLEFT", -gateMargin + sx, gateMargin + sy)
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", icon.button, "TOPLEFT", -gateMargin + sx, gateMargin + sy)
    clip:SetPoint("BOTTOMLEFT", icon.button, "BOTTOMLEFT", -gateMargin + sx, -gateMargin + sy)
    clip:SetPoint("RIGHT", gate, "RIGHT")
  end
  AnchorGateClip(snapX, snapY)
  -- ForeverAuras: shown again after ReleaseSlotDrawing hid it.
  clip:Show()
  -- At login the display has no place yet: snapped again a frame later.
  if not placed then
    local tries = 0
    local function Retry()
      tries = tries + 1
      if not icon.used then return end
      local sx, sy, ok = GateSnap()
      AnchorGateClip(sx, sy)
      if not ok and tries < 5 then C_Timer.After(0, Retry) end
    end
    C_Timer.After(0, Retry)
  end
  -- The slot button is the box: on the row's start frame, rounded to pixels
  -- like a native button (BuildButton), sized in whole pixels (36 units on a
  -- 1.2 group is 43.2 pixels: 43). The icon fills it.
  local px = PixelsPerUnit(icon.button)
  if icon.button.SetRoundLayoutToNearestPixel then pcall(icon.button.SetRoundLayoutToNearestPixel, icon.button, true) end
  icon.button:ClearAllPoints()
  icon.button:SetPoint("TOPLEFT", Display.ContentAnchor(region), "TOPLEFT")
  if px then
    icon.button:SetSize(math.max(1, math.floor(width * px + 0.5)) / px, math.max(1, math.floor(height * px + 0.5)) / px)
  else
    icon.button:SetSize(width, height)
  end
  art:ClearAllPoints()
  art:SetAllPoints(icon.button)
  icon.tex:SetSnapToPixelGrid(false)
  icon.tex:SetTexelSnappingBias(0)
  icon.tex:SetTexture(Display.SingleIcon(data))
  icon.tex:SetTexCoord(left, right, top, bottom)
  icon.tex:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
  icon.tex:SetDesaturated(data.desaturate == true)
  art:Show()
  -- The swipe: Blizzard fills it from the aura's duration.
  local cooldown = icon.cooldown
  pcall(icon.button.ClearDurationCooldown, icon.button)
  if data.cooldown ~= false then
    cooldown:SetDrawSwipe(data.cooldownSwipe ~= false)
    cooldown:SetDrawEdge(data.cooldownEdge == true)
    cooldown:SetReverse(data.inverse == true)
    cooldown:SetSwipeColor(unpack(data.blizzardAuraDisplay and data.blizzardAuraDisplay.swipeColor or {0, 0, 0, 0.8}))
    cooldown:Show()
    pcall(icon.button.SetDurationCooldown, icon.button, cooldown)
  else
    cooldown:Hide()
  end
  -- Border elements, with the native buttons' own border code.
  for _, entry in pairs(icon.borders) do if entry.border then entry.border:Hide() end end
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subborder" and element.border_visible ~= false and not Display.IsDetachedElement(data, element) then
      icon.borders[index] = icon.borders[index] or {}
      Display.StyleBorderFrame(icon.borders[index], art, art, width, height, element, Display.FlowGroup(data) ~= nil)
      icon.borders[index].border:SetAlpha(element.border_alpha or 1)
      -- Above the swipe, as an Icon's border is above its cooldown.
      pcall(icon.borders[index].border.SetFrameLevel, icon.borders[index].border, cooldown:GetFrameLevel() + 1)
      icon.borders[index].border:Show()
    end
  end
  -- Glow elements, inside the same clip: Blizzard's formatter opens it at
  -- exactly x seconds, whatever the aura's total duration. (The list button's
  -- window glow, TimedGlowHolder, needs that total, which an "All Ranks"
  -- selection cannot give: ranks differ, and the aura's rank is secret.)
  -- Present conditions that turn a glow on apply, as on the live button.
  icon.glows = icon.glows or {}
  for _, entry in pairs(icon.glows) do Display.ClearElementGlow(entry) end
  -- A glow turned on by a "Remaining Time < X" condition is drawn by a slot
  -- of its own (below), whose gate opens at X; any other condition that
  -- turns a glow on counts as on, as on the live button.
  local onAlways, onBelow = {}, {}
  for _, condition in ipairs(data.conditions or {}) do
    local check = condition.check
    for _, change in ipairs(condition.changes or {}) do
      local glowIndex = tonumber((change.property or ""):match("^sub%.(%d+)%.glow$"))
      if glowIndex and change.value == true and not condition.linked and not Display.IsDetachedProperty(data, change.property) then
        local x = Display.RemainingBelowCheck(data, check)
        if x then
          onBelow[glowIndex] = math.max(onBelow[glowIndex] or 0, x)
        else
          onAlways[glowIndex] = true
        end
      end
    end
  end
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subglow" and not Display.IsDetachedElement(data, element) then
      if element.glow or onAlways[index] then
        icon.glows[index] = icon.glows[index] or {}
        Display.StyleElementGlow(icon.glows[index], icon.button, art, art, setmetatable({glow = true}, {__index = element}), width, height)
        local holder = icon.glows[index].nativeGlow and icon.glows[index].nativeGlow.holder
        if holder then pcall(holder.SetFrameLevel, holder, cooldown:GetFrameLevel() + 2) end
      elseif onBelow[index] then
        EnsureConditionGlow(single, instance, region, data, trigger, index, element, onBelow[index], icon)
      end
    end
  end
  instance.container:SetAuraSlotEnabled(SLOT_ICON, true)
  local level = icon.button:GetFrameLevel()
  -- The swipe is drawn on the icon's frame above; the separate swipe slot
  -- of earlier versions is left unused, which turns it off.
  -- Elements listed before the Background draw below the icon, as they do on
  -- an ordinary Icon; the rest draw above it in list order.
  local backgroundIndex
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subbackground" then backgroundIndex = index; break end
  end
  -- One piece of artwork drawn by Blizzard's timer like the icon: a texture
  -- element, or one edge of a Border element.
  local function Artwork(key, index, texture, w, h, point, relative, ox, oy, tint, alpha, below)
    local slot = EnsureSlot(single, instance, region, key, trigger, data)
    if not slot then return end
    -- The slot button is placed in units; the artwork inside it in pixels,
    -- from the corner the button is anchored by (a corner of the display's
    -- box, which is on the pixel grid), or the top-left one.
    local corner = (point:find("TOP") or point:find("BOTTOM")) and (point:find("LEFT") or point:find("RIGHT")) and point or "TOPLEFT"
    local frame, scale = PixelFrame(slot, region, corner)
    w, h = math.max(1, math.floor(w * scale + 0.5)), math.max(1, math.floor(h * scale + 0.5))
    slot.button:ClearAllPoints()
    slot.button:SetSize(w / scale, h / scale)
    slot.button:SetPoint(point, Display.ContentAnchor(region), relative, ox, oy)
    pcall(slot.button.SetFrameLevel, slot.button, below and math.max(0, level - 1) or level + index)
    slot.text = slot.text or frame:CreateFontString(nil, "ARTWORK")
    slot.text:SetWordWrap(false)
    slot.text:SetFont(STANDARD_TEXT_FONT, 12, "")
    slot.button:ClearDurationText()
    local markup, rendered = FitMarkup(slot, frame, texture, w, h, 0, 1, 0, 1, tint)
    AnchorArtwork(slot.text, frame, corner, w, h)
    local ok = pcall(slot.button.SetDurationText, slot.button, slot.text, {
      textFormat = {formatString = markup, components = {}},
      textColor = {curve = RemainingCurve(op, x, tint[1] or 1, tint[2] or 1, tint[3] or 1, (tint[4] or 1) * alpha),
        property = Enum.DurationTextBindingProperty.RemainingDuration},
    })
    if ok then
      slot.text:Show()
      instance.container:SetAuraSlotEnabled(key, true)
    else
      slot.used = false
    end
  end
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subtexture" and element.textureVisible ~= false and element.textureTexture
      and not Display.IsDetachedElement(data, element) then
      local w, h, point, relative, ox, oy
      if element.anchor_mode == "point" then
        w, h = element.width or 32, element.height or 32
        point, relative = element.self_point or "CENTER", (element.anchor_point or "CENTER"):gsub("^INNER_", ""):gsub("^OUTER_", "")
        ox, oy = element.xOffset or 0, element.yOffset or 0
      else
        w, h = width + (element.xOffset or 0), height + (element.yOffset or 0)
        point, relative, ox, oy = "CENTER", "CENTER", 0, 0
      end
      Artwork(SLOT_TEXTURE .. index, index, element.textureTexture, w, h, point, relative, ox, oy,
        element.textureColor or {1, 1, 1, 1}, element.texture_alpha or 1, backgroundIndex and index < backgroundIndex)
    end
  end
  -- ForeverAuras: hardcoded Text elements ("Leyline"). The list button has
  -- one duration-text binding, which its %p countdown uses; binding a label
  -- there too replaced the countdown, which then stood still at its last
  -- number and stayed when the aura left the window. Each label gets an aura
  -- slot of its own, like a Border edge: a fixed format bound with the
  -- window's colour curve, so it shows with the icon and goes with it. The
  -- text is placed as on the button (Display.StyleText), with the Inner and
  -- Outer anchor areas a Text element may anchor to.
  for index, element in ipairs(data.subRegions or {}) do
    local literal = element.type == "subtext" and element.text_visible ~= false and not Display.IsDetachedElement(data, element)
      and Display.TextKind(element.text_text) == "literal" and (element.text_text or ""):gsub("%%%%", "%%")
    if literal and literal ~= "" then
      local key = SLOT_TEXT .. index
      local slot = EnsureSlot(single, instance, region, key, trigger, data, function(button, me)
        for _, area in ipairs({"inner", "outer"}) do
          me[area] = CreateFrame("Frame", nil, button)
          me[area]:SetPoint("CENTER", button, "CENTER")
          me[area]:EnableMouse(false)
        end
        me.text = button:CreateFontString(nil, "OVERLAY")
      end)
      if slot and slot.text then
        slot.button:ClearAllPoints()
        slot.button:SetAllPoints(icon.button)
        pcall(slot.button.SetFrameLevel, slot.button, level + index)
        slot.inner:SetSize(width * 0.8, height * 0.8)
        slot.outer:SetSize(width * 1.1, height * 1.1)
        Display.StyleText(slot.text, {button = slot.button, inner = slot.inner, outer = slot.outer},
          Display.TextSettings(element), "text", 18, "CENTER", 0, 0)
        slot.text:SetAlpha(element.text_alpha or 1)
        slot.text:SetWidth(element.text_automaticWidth == "Fixed" and (element.text_fixedWidth or 200) or 0)
        slot.text:SetWordWrap(element.text_wordWrap ~= "Elide")
        slot.text:SetNonSpaceWrap(element.text_wordWrap ~= "Elide")
        slot.text:SetText("")
        pcall(slot.button.ClearDurationText, slot.button)
        local color = Display.DurationColorCondition(data, element.text_color, "sub." .. index .. ".text_color", {op, x})
        local ok = color ~= nil and pcall(slot.button.SetDurationText, slot.button, slot.text,
          {textFormat = {formatString = literal, components = {}}, textColor = color})
        if ok then
          slot.text:Show()
          instance.container:SetAuraSlotEnabled(key, true)
        else
          slot.used = false
        end
      end
    end
  end
  return true
end

---------------------------------------------------------------------------- glow for the last seconds
-- A glow limited to a remaining-time range. Each list button carries an
-- invisible StatusBar that Blizzard fills by remaining time. With the aura's
-- total duration known, the bar is sized K px per second and placed so its fill
-- edge passes a fixed point when X seconds are left; a clip between the fill
-- edge and that point opens on the chosen side of X. The glow inside is the
-- display's own Glow element.
local LATE_K, LATE_MAX_WIDTH = 2000, 200000
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- True for a "Remaining Time < X" check on an Aura (Modern) trigger, with X.
function Display.RemainingBelowCheck(data, check)
  if type(check) ~= "table" or check.variable ~= "faAuraRemaining" or check.op ~= "<" then return end
  local entry = data.triggers and data.triggers[check.trigger]
  local trigger = type(entry) == "table" and entry.trigger
  if type(trigger) ~= "table" or trigger.type ~= "secretAura" then return end
  local x = tonumber(check.value)
  if x and x > 0 then return x end
end

-- Returns x (seconds), the glow element, its index, and whether the glow shows
-- above x (Remaining Time > / >=) instead of below it: Remaining Time with a
-- Glow turned on, or a "Remaining Time < X" condition that turns a Glow on.
function Display.LateGlowSpec(data, trigger)
  local op, x = Display.RemainingWindow(trigger)
  -- A Remaining Time window on a bar, progress texture or text is the gate on
  -- the whole display, so a Glow turned on there is an ordinary glow.
  if op and data.regionType == "icon" then
    local element, index = FirstElement(data, function(element) return element.type == "subglow" and element.glow end)
    if not element then return end
    local edge = (op == "<=" or op == ">") and x + REMAIN_EPS or x
    return edge, element, index, op == ">" or op == ">="
  end
  for _, condition in ipairs(data.conditions or {}) do
    local check = condition.check
    local x = not condition.linked and Display.RemainingBelowCheck(data, check)
    if x then
      for _, change in ipairs(condition.changes or {}) do
        if change.value == true and Display.IsGlowProperty(data, change.property) then
          local index = tonumber(change.property:match("^sub%.(%d+)%."))
          return x, data.subRegions[index], index, false
        end
      end
    end
  end
end

-- Total durations seen while auras were readable (out of combat), per spell
-- ID, saved per account. Classic ranks each have their own ID.
local watchedIDs = {}
local waitingRegions = setmetatable({}, {__mode = "k"})
local function SeenDurations()
  if type(ForeverAurasSaved) ~= "table" then return end
  ForeverAurasSaved.auraDurations = ForeverAurasSaved.auraDurations or {}
  return ForeverAurasSaved.auraDurations
end

-- A spell's description and tooltip ("Lasts for 2 min.") give its duration
-- without the aura ever being seen. Cached per spell ID; spell data that has
-- not loaded is requested, and SPELL_DATA_LOAD_RESULT tries again.
local describedDurations = {}
local pendingSpellData = {}
local loadAttempted = {}
-- The patterns come from the client's own duration strings ("%d sec",
-- "%d Sek.", "%d мин.", "%d秒"), so every language works. The longest duration
-- in the text wins; decimal commas are accepted.
local NUMBER = "(%d+[%.,]?%d*)"
local DURATION_GLOBALS = {
  {1, {"INT_SPELL_DURATION_SEC", "SPELL_DURATION_SEC", "SECONDS_ABBR", "SECOND_ONELETTER_ABBR", "D_SECONDS"}},
  {60, {"INT_SPELL_DURATION_MIN", "SPELL_DURATION_MIN", "MINUTES_ABBR", "MINUTE_ONELETTER_ABBR", "D_MINUTES"}},
  {3600, {"INT_SPELL_DURATION_HOURS", "SPELL_DURATION_HOURS", "HOURS_ABBR", "HOUR_ONELETTER_ABBR", "D_HOURS"}},
}
-- English fallback, used alongside the client's strings.
local ENGLISH_UNITS = {{1, "%d sec"}, {1, "%d secs"}, {1, "%d second"}, {1, "%d seconds"},
  {60, "%d min"}, {60, "%d mins"}, {60, "%d minute"}, {60, "%d minutes"},
  {3600, "%d hour"}, {3600, "%d hours"}, {3600, "%d hr"}, {3600, "%d hrs"}}
-- Turns one format string into a Lua pattern with the number captured.
local function DurationPattern(format)
  local forms = {}
  -- "|4singular:plural;" grammar: keep every form.
  local choice = format:match("|4([^;]*);")
  if choice then
    for form in (choice .. ":"):gmatch("([^:]*):") do forms[#forms + 1] = (format:gsub("|4[^;]*;", form, 1)) end
  else
    forms[1] = format
  end
  local patterns = {}
  for _, form in ipairs(forms) do
    -- Drop colour codes, then split around the one number placeholder.
    form = form:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    local before, after = form:match("^(.-)%%[%d%$]*[%.%d]*[dfsi](.*)$")
    if before then
      local function Escape(text)
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        -- Spaces (also non-breaking ones) may vary; everything else is literal.
        return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%s+", "%%s*"):gsub("\194\160", "%%s*"))
      end
      before, after = Escape(before), Escape(after)
      -- A unit is needed on at least one side, or every number would match.
      if before ~= "" or after ~= "" then
        -- Latin unit abbreviations must end at a word boundary: "min" in
        -- "minimum" and "sec" in "secondary" are not durations.
        local boundary = after:match("[a-z]$") and "%f[%A]" or ""
        patterns[#patterns + 1] = before .. "%s*" .. NUMBER .. "%s*" .. after .. boundary
      end
    end
  end
  return patterns
end
local durationPatterns
local function DurationPatterns()
  if durationPatterns then return durationPatterns end
  durationPatterns = {}
  local seen = {}
  local function Add(seconds, format)
    if type(format) ~= "string" then return end
    for _, pattern in ipairs(DurationPattern(format)) do
      if not seen[pattern] then
        seen[pattern] = true
        durationPatterns[#durationPatterns + 1] = {pattern, seconds}
      end
    end
  end
  for _, group in ipairs(DURATION_GLOBALS) do
    for _, name in ipairs(group[2]) do Add(group[1], _G[name]) end
  end
  for _, entry in ipairs(ENGLISH_UNITS) do Add(entry[1], entry[2]) end
  return durationPatterns
end
local function SpellText(id)
  local parts = {}
  local ok, text = pcall(C_Spell.GetSpellDescription, id)
  -- The description is what says the duration; a tooltip with only its title
  -- means the spell's text has not loaded yet. It is returned apart from the
  -- other tooltip lines (DescribedDuration reads it first).
  local loaded = ok and type(text) == "string" and not issecretvalue(text) and text ~= ""
  local description = loaded and text:lower() or nil
  if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
    local okTip, info = pcall(C_TooltipInfo.GetSpellByID, id)
    for _, line in ipairs(okTip and type(info) == "table" and info.lines or {}) do
      -- A tooltip can have right text with no left text; ipairs on the two
      -- values would stop at that nil and silently skip the duration.
      for _, key in ipairs({"leftText", "rightText"}) do
        local side = line[key]
        if not issecretvalue(side) and type(side) == "string" then parts[#parts + 1] = side end
      end
    end
  end
  return table.concat(parts, "\n"):lower(), loaded, description
end
local function DescribedDuration(id)
  if describedDurations[id] ~= nil then return describedDurations[id] or nil end
  -- Requested and still loading: nothing new to read yet.
  if pendingSpellData[id] then return end
  local text, loaded, description = SpellText(id)
  if not loaded and not loadAttempted[id] and C_Spell.RequestLoadSpellData then
    -- Not loaded yet: ask once; the load event clears the cache entry.
    pendingSpellData[id], loadAttempted[id] = true, true
    local ok = pcall(C_Spell.RequestLoadSpellData, id)
    if not ok then pendingSpellData[id] = nil end
    loaded = not ok
  elseif not loaded then
    -- Asked and answered: whatever is there is final.
    loaded = loadAttempted[id] == true
  end
  -- The description is read first; the rest of the tooltip only when the
  -- description names no duration. A tooltip also states the cooldown
  -- ("25 sec cooldown" on an 8 sec root), and the longest time in the whole
  -- text was that cooldown, which put a Remaining Time glow far too late.
  local function Longest(part)
    local best
    for _, entry in ipairs(DurationPatterns()) do
      for value in part:gmatch(entry[1]) do
        local seconds = tonumber((value:gsub(",", ".")))
        seconds = seconds and seconds * entry[2]
        if seconds and seconds > (best or 0) then best = seconds end
      end
    end
    return best
  end
  local best = description and Longest(description)
  if not best then best = Longest(text) end
  -- "No duration" is remembered only once loading has been tried, so a
  -- half-loaded tooltip is read again after the load event.
  if best or loaded then describedDurations[id] = best or false end
  return best
end

-- The longest known total duration of the selected spells, and its source.
function Display.LateGlowTotal(trigger)
  local op, total = Display.TotalFilter(trigger)
  if op == "=" then return total, "manual" end
  local ids = Display.GetSpellIDs(trigger, true)
  local seen, best = SeenDurations(), nil
  for _, id in ipairs(ids) do
    local seconds = seen and tonumber(seen[id])
    if seconds and seconds > (best or 0) then best = seconds end
  end
  if best then return best, "seen" end
  for _, id in ipairs(ids) do
    local seconds = DescribedDuration(id)
    if seconds and seconds > (best or 0) then best = seconds end
  end
  if best then return best, "described" end
end

local function GlowMargin(width, height, element)
  local offset = math.max(math.abs(tonumber(element.glowXOffset) or 0), math.abs(tonumber(element.glowYOffset) or 0))
  return math.ceil(math.max(width, height) * 0.5 * (tonumber(element.glowScale) or 1)) + offset + 4
end
Display.GlowMargin = GlowMargin

-- Called by StyleAppearance for each Glow element of a live list button
-- (icons, bars, progress textures and texts).
-- nil: an ordinary glow. false: a timed glow whose total duration is not known
-- yet (hidden). A frame: the holder inside the clip that the glow belongs in.
function Display.TimedGlowHolder(native, data, index, frame)
  if native.preview then return end
  local trigger = Display.GetTrigger(data)
  local x, element, glowIndex, above = Display.LateGlowSpec(data, trigger)
  if not x or glowIndex ~= index then return end
  -- An Icon with a Remaining Time window draws its glows in the Remaining
  -- Time slot (EnsureRemaining), opened at exactly x seconds; nothing here.
  if data.regionType == "icon" and Display.RemainingWindow(trigger) and Display.IsSingle(trigger, data) then return false end
  -- A "Remaining Time < X" condition: the button's duration text is bound to
  -- the time left with the Remaining Time slot's formatter gate and the
  -- glow's clip hangs on it (StyleGlowGate), sharing the text with a Total
  -- Duration or Remaining Time gate when there is one (CombinedGate). Exact
  -- for IDs of different lengths, which the estimated bar below is not. Only
  -- a list Icon with a Remaining Time window, drawn by its slot, keeps the bar.
  local exact = not above and not (data.regionType == "icon" and Display.RemainingWindow(trigger))
  local total
  if not exact then
    -- The estimated bar needs the button's duration bar, which a bar display
    -- uses itself: such a glow stays an ordinary glow there.
    if data.regionType ~= "icon" then return end
    total = Display.LateGlowTotal(trigger)
    if not total or total <= x then return false end
  end
  local late = native.lateGlow
  if not late then
    late = {}
    late.bar = CreateFrame("StatusBar", nil, native.button)
    late.bar:SetStatusBarTexture(WHITE)
    late.bar:SetStatusBarColor(0, 0, 0, 0)
    -- Invisible: only its fill edge serves as an anchor.
    late.bar:SetAlpha(0)
    -- Inside the Total Duration gate clip, so a rejected aura never glows.
    late.clip = CreateFrame("Frame", nil, Display.ElementHolder(native), "DisableUntrustedLayoutScriptsTemplate")
    late.clip:SetClipsChildren(true)
    late.holder = CreateFrame("Frame", nil, late.clip)
    late.holder:SetAllPoints(native.button)
    native.lateGlow = late
  end
  local width, height = Display.Dimensions(data)
  local margin = GlowMargin(width, height, element)
  late.exact = nil
  if exact then
    -- The clip is anchored to the gate text by StyleGlowGate at the end of
    -- StyleAppearance, once the text can be bound. Until then it covers the
    -- button, shown: a glow built inside a hidden clip plays its flipbook
    -- as the whole sprite sheet instead of frame by frame.
    late.exact, late.margin = x, margin
    late.clip:ClearAllPoints()
    late.clip:SetAllPoints(native.button)
    late.clip:SetFrameLevel(frame:GetFrameLevel() + 1)
    late.clip:Show()
    return late.holder
  end
  local k = math.min(LATE_K, LATE_MAX_WIDTH / total)
  late.bar:ClearAllPoints()
  late.bar:SetSize(total * k, height + 2 * margin)
  late.clip:ClearAllPoints()
  if above then
    -- Open from the icon's left edge while more than x seconds are left.
    late.bar:SetPoint("LEFT", native.button, "LEFT", -margin - x * k, 0)
    late.clip:SetPoint("TOPLEFT", late.bar, "TOPLEFT", x * k, 0)
    late.clip:SetPoint("BOTTOMRIGHT", late.bar:GetStatusBarTexture(), "BOTTOMRIGHT")
  else
    -- Open towards the icon's right edge once fewer than x seconds are left.
    late.bar:SetPoint("LEFT", native.button, "RIGHT", margin - x * k, 0)
    late.clip:SetPoint("TOPLEFT", late.bar:GetStatusBarTexture(), "TOPRIGHT")
    late.clip:SetPoint("BOTTOMRIGHT", late.bar, "BOTTOMLEFT", x * k, 0)
  end
  native.button:SetDurationBar(late.bar, {direction = Enum.StatusBarTimerDirection.RemainingTime})
  late.clip:SetFrameLevel(frame:GetFrameLevel() + 1)
  late.clip:Show()
  return late.holder
end

-- Remaining Time on a live list button: the icon, swipe, stacks, name, border
-- and other elements would show for the whole aura, so only the countdown and
-- glows stay; the icon is drawn by the Remaining Time slot instead.
function Display.StyleRemainingList(native, data)
  native.remainingHidesIcon = nil
  if native.preview then return end
  -- Icons only: other display types use the Remaining Time gate.
  local limited = data.regionType == "icon" and Display.RemainingWindow(Display.GetTrigger(data)) ~= nil
  if native.conditionOverlay then native.conditionOverlay:SetShown(not limited) end
  if not limited then return end
  -- Read by Display.StyleMasque: this button draws no icon to skin.
  native.remainingHidesIcon = true
  native.button:ClearIcon(); native.icon:Hide()
  native.button:ClearDurationCooldown(); native.cooldown:Hide()
  native.button:ClearApplicationCount(); native.button:ClearSpellName()
  native.border:Hide()
  for index, element in ipairs(data.subRegions or {}) do
    -- ForeverAuras: a hardcoded text is drawn by a slot of its own
    -- (EnsureRemaining). A button has one duration-text binding, and the
    -- countdown holds it: binding the label here as well replaced the
    -- countdown, which then stood still at its last number.
    local kind = element.type == "subtext" and Display.TextKind(element.text_text)
    local keep = element.type == "subglow" or element.type == "subbackground"
      or (element.type == "subtext" and kind == "duration")
    local frame = native.elementFrames and native.elementFrames["shared" .. index]
    if frame and not keep then frame:Hide() end
  end
end

---------------------------------------------------------------------------- learning durations
-- Timed glows need the selected spells' total durations; they are learned
-- while auras are readable (out of combat, including when combat ends with
-- the aura still up). Debuffs on friendly units cannot be found by spell ID
-- while secret: their displays filter by Total Duration =, dispel type and
-- flags instead (SpellIDFilterNote).
local learningRegions = setmetatable({}, {__mode = "k"})

local function RebuildLearningWatches()
  wipe(watchedIDs)
  for _, entry in pairs(learningRegions) do
    for _, id in ipairs(entry.ids) do
      if entry.glow then watchedIDs[id] = true end
    end
  end
end

function Display.ReleaseAuraLearning(region)
  waitingRegions[region] = nil
  if learningRegions[region] then
    learningRegions[region] = nil
    RebuildLearningWatches()
  end
end

function Display.WatchAuraLearning(region, data, trigger, glow)
  if not glow then Display.ReleaseAuraLearning(region); return end
  local ids = Display.GetSpellIDs(trigger, true)
  local key = table.concat(ids, ",") .. tostring(not not glow) .. tostring(trigger.unit)
  if not learningRegions[region] or learningRegions[region].key ~= key then
    learningRegions[region] = {ids = ids, key = key, glow = glow}
    RebuildLearningWatches()
  end
  -- Keep learned displays subscribed so later readable changes reach them too.
  waitingRegions[region] = data
end

-- Friendly units, where Blizzard refuses spell ID filters for debuffs.
Display.friendlyDebuffUnits = {player = true, pet = true, group = true, party = true, raid = true}

-- Approximate Match was removed: its learned properties are what the Total
-- Duration =, dispel type and flag filters set by hand.
function Display.UsesApproximate() return false end
function Display.ApproximateFilters(_, filters) return filters end

-- Learns total durations and debuff properties of the selected spell IDs while
-- auras are readable: on aura changes out of combat and when combat ends.
local BOTH_FILTERS, DEBUFF_FILTER = {"HELPFUL", "HARMFUL"}, {"HARMFUL"}
local FIXED_UNITS = {"player", "target", "focus", "pet"}
local learnEvents = CreateFrame("Frame")
learnEvents:RegisterEvent("UNIT_AURA")
learnEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
learnEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
learnEvents:RegisterEvent("SPELL_DATA_LOAD_RESULT")
-- Applies again every display that waits for a duration or profile.
local reapplyAfterCombat = {}
local function ReapplyWaiting(changed)
  local refresh = {}
  -- Collect affected displays first; applying one can change its subscriptions.
  for region, data in pairs(waitingRegions) do
    local entry = learningRegions[region]
    for _, id in ipairs(entry and entry.ids or {}) do
      if not changed or changed[id] then refresh[region] = data; break end
    end
  end
  for region, data in pairs(refresh) do
    if WeakAuras.GetData(data.id) == data then Display.Apply(region, data)
    else Display.ReleaseAuraLearning(region) end
  end
end
learnEvents:SetScript("OnEvent", function(_, event, unit, updateInfo)
  -- A requested spell's description is now available (unit is the spell ID).
  if event == "SPELL_DATA_LOAD_RESULT" then
    if pendingSpellData[unit] then
      pendingSpellData[unit], describedDurations[unit] = nil, nil
      loadAttempted[unit] = true
      -- Displays are only rebuilt out of combat; catch up when it ends.
      if InCombatLockdown() then reapplyAfterCombat[unit] = true else ReapplyWaiting({[unit] = true}) end
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and next(reapplyAfterCombat) then
    local changed = reapplyAfterCombat
    reapplyAfterCombat = {}
    ReapplyWaiting(changed)
  end
  if not next(watchedIDs) or InCombatLockdown()
    or (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then return end
  local seen = SeenDurations()
  if not seen then return end
  local changed = {}
  -- Reads one aura.
  local function Learn(token, aura)
    local id, duration = aura.spellId, aura.duration
    if not issecretvalue(id) and not issecretvalue(duration) and watchedIDs[id] and type(duration) == "number" and duration > 0 then
      -- Durations carry a few ms of noise; keep tenths.
      local tenths = math.floor(duration * 10 + 0.5) / 10
      if seen[id] ~= tenths then seen[id] = tenths; changed[id] = true end
    end
  end
  -- Buff durations are only needed for timed glows (watchedIDs).
  local filters = next(watchedIDs) and BOTH_FILTERS or DEBUFF_FILTER
  local function Scan(token)
    for _, filter in ipairs(filters) do
      for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, token, i, filter)
        if not ok or type(aura) ~= "table" then break end
        Learn(token, aura)
      end
    end
  end
  if event == "UNIT_AURA" then
    if unit ~= "target" and unit ~= "focus" and unit ~= "player" and unit ~= "pet" then return end
    if type(updateInfo) == "table" and not updateInfo.isFullUpdate then
      -- Only the auras that were added or changed; removals teach nothing.
      for _, aura in ipairs(updateInfo.addedAuras or {}) do Learn(unit, aura) end
      for _, instanceID in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, instanceID)
        if ok and type(aura) == "table" then Learn(unit, aura) end
      end
    else
      Scan(unit)
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    Scan("target")
  else
    -- Combat ended: auras still up become readable.
    for _, token in ipairs(FIXED_UNITS) do Scan(token) end
  end
  if next(changed) then ReapplyWaiting(changed) end
end)

---------------------------------------------------------------------------- total duration
-- "<=" is Blizzard's own maximum-duration filter. "=" and ">=" need a minimum,
-- which Blizzard does not have, so each list button gets a hidden "gate" text
-- formatted from the aura's total duration: a run of wide characters when it
-- is in range, empty otherwise. A clip spans exactly that text, and everything
-- the button draws sits inside the clip, so a wrong aura draws nothing.
-- The gate takes the button's one duration text, so %p is shown by the
-- swipe's countdown numbers. Candidates stack on one spot (Layout),
-- so rejected auras leave no gaps.
local GATE_TOLERANCE = 0.5
Display.totalOperators = {["="] = "=", ["<="] = "<=", [">="] = ">="}

-- The Total Duration filter: operator and seconds, or nil when off or invalid.
function Display.TotalFilter(trigger)
  if type(trigger) ~= "table" or not trigger.secretUseTotal then return end
  local op, x = trigger.secretTotalOperator or "=", tonumber(trigger.secretTotal)
  if not Display.totalOperators[op] or not x or x <= 0 or x ~= x or x == math.huge then return end
  return op, x
end

-- Why the gate cannot be drawn for this display, or nil.
local function GateProblem(data, trigger)
  if Display.FrameAnchorType(data) == "UNITFRAME" or Display.FrameAnchorType(data) == "NAMEPLATE" then
    return L["Total Duration = and >= can't anchor to unit frames or nameplates."]
  end
  -- Without data: Remaining Time on any display type needs the clip too.
  if Display.IsSingle(trigger) then
    return L["Total Duration = and >= only work with Show On: Aura(s) Found, without Remaining Time."]
  end
  if not (Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.TotalDuration ~= nil
    and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Display.SupportsDurationColorCondition()) then
    return L["This client can't check Total Duration = or >=."]
  end
end

-- The total-duration range the gate should let through: lower, upper (nil for
-- no upper limit), where it comes from ("filter"), and why it cannot be drawn
-- (nil when it can).
function Display.GateRange(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if not trigger then return end
  local op, x = Display.TotalFilter(trigger)
  local lower, upper, source
  if op == "=" then
    lower, upper, source = x - GATE_TOLERANCE, x + GATE_TOLERANCE, "filter"
  elseif op == ">=" then
    lower, source = x - GATE_TOLERANCE, "filter"
  end
  if not source then return end
  return math.max(0.001, lower), upper, source, GateProblem(data, trigger)
end

-- lower, upper when the gate is drawn; nil otherwise.
function Display.DurationGate(data, trigger)
  local lower, upper, _, problem = Display.GateRange(data, trigger)
  if lower and not problem then return lower, upper end
end

-- A red status for a Total Duration filter that cannot be drawn.
function Display.TotalFilterProblem(data, trigger)
  local _, _, source, problem = Display.GateRange(data, trigger)
  if source == "filter" and problem then return problem end
end

---------------------------------------------------------------------------- stack count
-- Blizzard's containers cannot filter by stacks. Each list button instead gets
-- an invisible StatusBar that Blizzard fills by the aura's stack count
-- (SetApplicationBar), and the Total Duration gate's clip is placed between a
-- fixed point and the bar's fill edge, one icon width per stack. The clip only
-- covers the icon on the chosen side of the threshold, so any other aura
-- draws nothing. Like the Total Duration gate, candidates stack on one spot.
-- "=" instead uses a hidden stack text sized by a formatter, like the Total
-- Duration gate; it takes the button's one stack text, and %s then shows the
-- known count as plain text (Display.StackTextFor).
Display.stackOperators = {["="] = "=", [">="] = ">=", [">"] = ">", ["<="] = "<=", ["<"] = "<"}
Display.STACK_LIMIT = 100

-- The Stack Count filter as ("exactly" | "atLeast" | "atMost", n), "never"
-- when nothing can match, or nil when it is off, empty or lets every aura through.
function Display.StackFilter(trigger)
  if type(trigger) ~= "table" or not trigger.secretUseStacks then return end
  local op, x = trigger.secretStacksOperator or ">=", tonumber(trigger.secretStacks)
  if not Display.stackOperators[op] or not x or x ~= math.floor(x) or x < 0 or x > Display.STACK_LIMIT then return end
  if op == "=" then return "exactly", x end
  -- Everything else becomes "at least n" or "at most n" whole stacks.
  if op == ">" then op, x = ">=", x + 1 elseif op == "<" then op, x = "<=", x - 1 end
  if op == ">=" then
    if x <= 0 then return end
    return "atLeast", x
  end
  if x < 0 then return "never" end
  return "atMost", x
end

-- Why the Stack Count filter cannot be drawn, or nil.
function Display.StackFilterProblem(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if type(trigger) ~= "table" or not trigger.secretUseStacks then return end
  local x = tonumber(trigger.secretStacks)
  if not x or x ~= math.floor(x) or x < 0 or x > Display.STACK_LIMIT then
    return L["Stack Count needs a whole number from 0 to %d."]:format(Display.STACK_LIMIT)
  end
  local kind = Display.StackFilter(trigger)
  if kind == "never" then return L["Stack Count < 0 never matches."] end
  if not kind then return end
  if Display.FrameAnchorType(data) == "UNITFRAME" or Display.FrameAnchorType(data) == "NAMEPLATE" then
    return L["Stack Count can't anchor to unit frames or nameplates."]
  end
  -- Without data: Remaining Time on any display type needs the clip too.
  if Display.IsSingle(trigger) then
    return L["Stack Count only works with Show On: Aura(s) Found, without Remaining Time."]
  end
  -- Both filters need the one clip around the button.
  if Display.GateRange(data, trigger) then
    return L["Stack Count can't be combined with Total Duration = or >=."]
  end
  if not (C_AuraContainerUtil and C_AuraContainerUtil.ProcessCustomAuraButtonApplicationBarOptions) then
    return L["This client can't check Stack Count."]
  end
end

-- kind, n when the stack gate is drawn; nil otherwise.
function Display.StackGate(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  local kind, n = Display.StackFilter(trigger)
  if (kind == "exactly" or kind == "atLeast" or kind == "atMost") and not Display.StackFilterProblem(data, trigger) then return kind, n end
end

---------------------------------------------------------------------------- remaining time gate
-- On Icons, Remaining Time draws the icon inside Blizzard's countdown text
-- (a single display). Bars, progress textures and texts cannot be drawn as
-- text, so they use the Total Duration gate on the time left instead: the
-- hidden gate text is formatted from the remaining duration and the clip
-- around the button is empty outside the range. The gate takes the button's
-- one countdown text, so %p is not shown on these displays.

-- Why Remaining Time cannot be drawn on a non-Icon display, or nil.
function Display.RemainingGateProblem(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if data.regionType == "icon" or not UsesRemaining(trigger) then return end
  if not Display.RemainingWindow(trigger) then
    return L["Remaining Time needs a comparison and a number of seconds of 0 or more."]
  end
  if Display.FrameAnchorType(data) == "UNITFRAME" or Display.FrameAnchorType(data) == "NAMEPLATE" then
    return L["Remaining Time can't anchor to unit frames or nameplates."]
  end
  -- The Total Duration gate would need the same clip.
  if Display.GateRange(data, trigger) then
    return L["On this display type, Remaining Time can't be combined with Total Duration = or >=."]
  end
  if not (Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.RemainingDuration ~= nil
    and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Display.SupportsDurationColorCondition()) then
    return L["This client can't check Remaining Time on this display type."]
  end
end

-- The remaining-time range the gate lets through on a non-Icon display:
-- lower, upper (nil for no upper limit); nil when there is no such gate.
function Display.RemainingGateRange(data, trigger)
  trigger = trigger or Display.GetTrigger(data)
  if data.regionType == "icon" or not UsesRemaining(trigger) or Display.RemainingGateProblem(data, trigger) then return end
  return Display.RemainingRange(trigger)
end

-- lower, upper (nil for no upper limit) of the Remaining Time window, or nil.
function Display.RemainingRange(trigger)
  local op, x = Display.RemainingWindow(trigger)
  if not op then return end
  if op == "<" then return 0, x - REMAIN_EPS
  elseif op == "<=" then return 0, x
  elseif op == ">" then return x + REMAIN_EPS end
  return x
end

-- True when a gate (Total Duration, Remaining Time or Stack Count) picks among
-- stacked candidates, so the list keeps a fixed spot instead of growing.
function Display.UsesGate(data)
  return Display.DurationGate(data) ~= nil or Display.RemainingGateRange(data) ~= nil or Display.StackGate(data) ~= nil
end

-- How far the gate clip reaches past the icon: room for the border, glows and
-- outer texts. Kept modest because the gate text's font size grows with it.
local function GateMargin(width, height)
  return math.ceil(math.max(width, height) * 0.5) + 8
end

-- Shared across buttons: one transparent colour curve, and one formatter per
-- range and fill text.
local invisibleCurve
local gateFormatters = {}
local function GateFormatter(lower, upper, fill)
  local key = table.concat({lower, tostring(upper), fill}, "|")
  if gateFormatters[key] then return gateFormatters[key] end
  local points
  if upper and upper < lower then
    -- An empty range ("Remaining Time < 0"): never open.
    points = {{threshold = 0, format = ""}}
  elseif lower <= 0 then
    -- Open from zero ("Remaining Time <" or "<=").
    points = {{threshold = 0, format = fill}}
  else
    points = {{threshold = 0, format = ""}, {threshold = lower, format = fill}}
  end
  if upper and upper >= lower then points[#points + 1] = {threshold = upper + REMAIN_EPS, format = ""} end
  local formatter = C_StringUtil.CreateNumericRuleFormatter()
  local ok, err = pcall(formatter.SetBreakpoints, formatter, points)
  if not ok then return nil, err end
  gateFormatters[key] = formatter
  return formatter
end
Display.GateFormatter = GateFormatter

-- Font size of every gate text: well under the client's cap (about 120).
local GATE_FONT_SIZE = 64

-- The gate text gives a clip its width: a run of wide characters on one line
-- (the formatter drops line breaks, so a taller text is not possible); the
-- clip's top and bottom come from the display itself (AnchorGateClip). An
-- empty text has no width, so the clip then shows nothing.
local function GateFill(width, height)
  local margin = GateMargin(width, height)
  local size = GATE_FONT_SIZE
  local fill = string.rep("W", math.ceil((width + 2 * margin) / (size / 2)) + 1)
  return size, fill, margin
end

-- Hangs a gate clip on its text: left and right edges from the text, top and
-- bottom from the frame with the gate margin around it.
local function AnchorGateClip(clip, text, frame, margin)
  clip:ClearAllPoints()
  clip:SetPoint("LEFT", text, "LEFT")
  clip:SetPoint("RIGHT", text, "RIGHT")
  clip:SetPoint("TOP", frame, "TOP", 0, margin)
  clip:SetPoint("BOTTOM", frame, "BOTTOM", 0, -margin)
end

local function PlaceGateText(text, button, margin)
  text:ClearAllPoints()
  text:SetJustifyH("LEFT")
  text:SetPoint("LEFT", button, "LEFT", -margin - 2, 0)
end
Display.GateFill, Display.PlaceGateText, Display.AnchorGateClip = GateFill, PlaceGateText, AnchorGateClip

-- Stack Count "=": the hidden stack text decides the clip, so every drawn
-- aura has exactly n stacks. Returns true when drawn.
local function StyleExactStackGate(native, data, n)
  local button, clip = native.button, native.gateClip
  local width, height = Display.Dimensions(data)
  local size, fill, margin = GateFill(width, height)
  -- Open at exactly n; integers only, so the range n..n closes again at n + 1.
  local formatter, err = GateFormatter(n, n, fill)
  local text = native.stackGateText
  if not text then
    text = button:CreateFontString(nil, "BACKGROUND")
    native.stackGateText = text
  end
  local ok = formatter ~= nil
  if ok then
    text:SetFont(STANDARD_TEXT_FONT, size, "")
    text:SetWordWrap(false)
    text:SetWidth(0)
    PlaceGateText(text, button, margin)
    -- Always invisible: only its size matters. Blizzard only sets its text.
    text:SetTextColor(0, 0, 0, 0)
    text:SetAlpha(0)
    ok, err = pcall(button.SetApplicationCount, button, text, {formatter = formatter})
  end
  if not ok then
    Warn(data, "Blizzard refused the Stack Count check: " .. tostring(err))
    text:Hide()
    return false
  end
  text:Show()
  Display.ClipChildren(clip)
  AnchorGateClip(clip, text, button, margin)
  -- The %s text lost its binding to the gate. The count is known, so it is
  -- written as plain text with the display's stack conditions applied.
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subtext" and Display.TextKind(element.text_text) == "stack" then
      local entry = native.sharedElements and native.sharedElements[index]
      if entry and entry.text then entry.text:SetText(Display.StackTextFor(data, "sub." .. index .. ".text_color", n)) end
    end
  end
  if native.mainText and data.regionType == "text" and Display.TextKind(data.displayText) == "stack" then
    native.mainText:SetText(Display.StackTextFor(data, "color", n))
  end
  return true
end

-- Places the gate clip for a Stack Count filter. Returns true when it did;
-- otherwise the stack bar is released and the caller resets the clip.
local function StyleStackGate(native, data, trigger)
  local button, clip = native.button, native.gateClip
  local kind, n = Display.StackGate(data, trigger)
  local bar = native.stackGate
  -- Parts of the other Stack Count gate are released first.
  if kind ~= "exactly" and native.stackGateText then native.stackGateText:Hide() end
  if (not kind or kind == "exactly") and bar then
    button:ClearApplicationBar()
    bar:Hide()
  end
  if not kind then return false end
  if kind == "exactly" then return StyleExactStackGate(native, data, n) end
  if not bar then
    bar = CreateFrame("StatusBar", nil, button)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    -- Invisible: only its fill edge serves as an anchor.
    bar:SetAlpha(0)
    native.stackGate = bar
  end
  local width, height = Display.Dimensions(data)
  local margin = GateMargin(width, height)
  -- One stack moves the fill edge by the clip's full width, so a single stack
  -- short of the threshold already leaves the clip empty.
  local k = width + 2 * margin
  local max = kind == "atLeast" and n or n + 1
  bar:ClearAllPoints()
  bar:SetSize(max * k, height + 2 * margin)
  Display.ClipChildren(clip)
  clip:ClearAllPoints()
  if kind == "atLeast" then
    -- The bar ends where the clip should end; its fill reaches there at n
    -- stacks and Blizzard caps the value at n.
    bar:SetPoint("LEFT", button, "LEFT", -margin - (n - 1) * k, 0)
    clip:SetPoint("TOPLEFT", bar, "TOPLEFT", (n - 1) * k, 0)
    clip:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
  else
    -- The clip runs from the fill edge to the bar's end: it covers the icon
    -- up to n stacks and closes once the bar is full at n + 1.
    bar:SetPoint("RIGHT", button, "RIGHT", margin, 0)
    clip:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
    clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
  end
  bar:Show()
  local ok, err = pcall(button.SetApplicationBar, button, bar, {maxApplications = max})
  if not ok then
    Warn(data, "Blizzard refused the Stack Count check: " .. tostring(err))
    bar:Hide()
    return false
  end
  return true
end

-- Width of a run of n W's in the gate font, measured on a hidden text.
local ruler
local function RulerWidth(size, n)
  if not ruler then
    ruler = UIParent:CreateFontString(nil, "BACKGROUND")
    ruler:SetAlpha(0)
    ruler:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
  end
  ruler:SetFont(STANDARD_TEXT_FONT, size, "")
  ruler:SetWordWrap(false)
  ruler:SetText(string.rep("W", n))
  local width = ruler:GetStringWidth()
  ruler:SetText("")
  return width
end

-- A clip whose left, top and bottom are the frame's with a margin and whose
-- right edge is the text's right edge moved by `offset` (negative): the clip
-- is open only while the text is wider than that, and then spans the frame.
local function AnchorEdgeClip(clip, text, frame, margin, offset)
  clip:ClearAllPoints()
  clip:SetPoint("LEFT", frame, "LEFT", -margin, 0)
  clip:SetPoint("RIGHT", text, "RIGHT", offset, 0)
  clip:SetPoint("TOP", frame, "TOP", 0, margin)
  clip:SetPoint("BOTTOM", frame, "BOTTOM", 0, -margin)
end

-- One text for a Total Duration / Remaining Time gate and a "Remaining Time
-- < X" glow condition (StyleDurationGate). The gate's formatter writes 2n W's
-- while the gate is open, the glow's n W's while fewer than X seconds are
-- left, and the text is their sum: n (glow only), 2n (gate only) or 3n
-- (both). A clip opened past 1.5n shows the display for the gate, one past
-- 2.5n the glow for both; n W's are at least twice the clip's span, so an
-- open clip always covers it. Returns the parts, or nil when the formatters
-- are refused (the gate then runs alone).
local function CombinedGate(native, data, lower, upper, property, gateMargin)
  local late = native.lateGlow
  local width, height = Display.Dimensions(data)
  local size = GATE_FONT_SIZE
  local _, _, glowGateMargin = GateFill(width + 2 * late.margin, height + 2 * late.margin)
  local margin = math.max(gateMargin, late.margin + glowGateMargin)
  -- The text starts 2 px left of the margin (PlaceGateText); 4 px of slack.
  local span = width + 2 * margin + 4
  local one = RulerWidth(size, 1)
  if not one or one <= 0 then return end
  local n = math.ceil(2 * span / one) + 1
  local unit = RulerWidth(size, n)
  if not unit or unit < 2 * span then return end
  local formatter = GateFormatter(lower, upper, string.rep("W", 2 * n))
  local glowFormatter = GateFormatter(0, late.exact, string.rep("W", n))
  if not (formatter and glowFormatter) then return end
  return {formatter = formatter, glowFormatter = glowFormatter, unit = unit, margin = margin}
end

-- A Glow element turned on by a "Remaining Time < X" condition on a list
-- display (TimedGlowHolder): no filter uses the gate text, so it is bound to the time
-- left and is a block while fewer than X seconds remain, empty otherwise; the
-- glow's clip hangs on it. The button's own clip is left to the stack gate.
local function StyleGlowGate(native, data)
  local late, gate, button = native.lateGlow, native.gateText, native.button
  local width, height = Display.Dimensions(data)
  -- The run of W's spans the glow's reach (margin) plus the gate's own margin.
  local size, fill, gateMargin = GateFill(width + 2 * late.margin, height + 2 * late.margin)
  local formatter, err = GateFormatter(0, late.exact, fill)
  local ok = formatter ~= nil
  if ok then
    gate:SetFont(STANDARD_TEXT_FONT, size, "")
    gate:SetWordWrap(false)
    gate:SetWidth(0)
    gate:ClearAllPoints()
    gate:SetJustifyH("LEFT")
    gate:SetPoint("LEFT", button, "LEFT", -late.margin - gateMargin, 0)
    -- Always transparent: only its size matters.
    if not invisibleCurve then
      invisibleCurve = C_CurveUtil.CreateColorCurve()
      invisibleCurve:SetType(Enum.LuaCurveType.Step)
      invisibleCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
    end
    ok, err = pcall(button.SetDurationText, button, gate, {
      textFormat = {formatString = "{}", components = {{property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = formatter}}},
      textColor = {curve = invisibleCurve, property = Enum.DurationTextBindingProperty.RemainingDuration},
    })
  end
  if not ok then
    Warn(data, "Blizzard refused the Remaining Time glow: " .. tostring(err))
    gate:Hide()
    return false
  end
  gate:Show()
  AnchorGateClip(late.clip, gate, button, late.margin + gateMargin)
  late.clip:Show()
  return true
end

-- The %p text lost its binding to the gate, so it is hidden and, when
-- numbers is true, a cooldown's countdown numbers show the time in its
-- place; the numbers start at `minimum` seconds of total duration.
local function HandOffCountdown(native, data, numbers, minimum)
  local button = native.button
  local countdown, settings, prefix
  if native.mainText and data.regionType == "text" and Display.TextKind(data.displayText) == "duration" then
    native.mainText:Hide()
    countdown, prefix = data, "displayText_format_p_time_"
    settings = {textFont = data.font, textSize = data.fontSize, textColor = data.color, textOutline = data.outline,
      textJustify = data.justify, textShadowColor = data.shadowColor, textShadowX = data.shadowXOffset, textShadowY = data.shadowYOffset}
  end
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subtext" and Display.TextKind(element.text_text) == "duration" then
      local entry = native.sharedElements and native.sharedElements[index]
      if entry and entry.text then entry.text:Hide() end
      if element.text_visible ~= false and not countdown then
        countdown, settings, prefix = element, Display.TextSettings(element), "text_text_format_p_time_"
      end
    end
  end
  if countdown and numbers then
    local cooldown = native.cooldown
    cooldown:Show()
    if data.regionType ~= "icon" then
      -- Only the numbers: no swipe, over the whole display.
      cooldown:ClearAllPoints()
      cooldown:SetAllPoints(button)
    end
    if data.regionType ~= "icon" or data.cooldown == false then
      -- Above every element frame (ElementFrame levels: button + index * 3 + 3).
      cooldown:SetFrameLevel(button:GetFrameLevel() + #(data.subRegions or {}) * 3 + 6)
      cooldown:SetDrawSwipe(false)
      cooldown:SetDrawEdge(false)
    end
    cooldown:SetHideCountdownNumbers(false)
    -- Blizzard's numbers carry the time; cooldown text addons cannot read it.
    if OmniCC and OmniCC.Cooldown and OmniCC.Cooldown.SetNoCooldownCount then
      pcall(OmniCC.Cooldown.SetNoCooldownCount, cooldown, true)
    elseif ElvUI and ElvUI[1] and ElvUI[1].ToggleCooldown then
      pcall(ElvUI[1].ToggleCooldown, ElvUI[1], cooldown, false)
    end
    cooldown:SetUseAuraDisplayTime(true)
    -- Second guard: no numbers for auras shorter than the range.
    cooldown:SetMinimumCountdownDuration(minimum * 1000)
    -- The numbers take the %p text's font, colour, position and time format.
    local numbers = cooldown:GetCountdownFontString()
    if numbers then Display.StyleText(numbers, native, settings, "text", 18, "CENTER", 0, 0) end
    local format = countdown[prefix .. "format"]
    cooldown:SetCountdownFormatter(nil)
    if format ~= nil and format ~= -1 and Private.GetDurationTextFormatter then
      pcall(cooldown.SetCountdownFormatter, cooldown, Private.GetDurationTextFormatter(countdown[prefix .. "legacy_floor"] and 0 or 99,
        countdown[prefix .. "dynamic_threshold"] or 3, countdown[prefix .. "precision"] or 1, format == -2, format))
    end
    button:SetDurationCooldown(cooldown)
  end
end

-- Called at the end of StyleAppearance for every live list button.
function Display.StyleDurationGate(native, data)
  if native.preview or not native.gateClip then return end
  local clip, gate, button = native.gateClip, native.gateText, native.button
  local trigger = Display.GetTrigger(data)
  local width, height = Display.Dimensions(data)
  local lower, upper = Display.DurationGate(data, trigger)
  -- Which time the gate text follows, and its name in warnings.
  local property, label = "TotalDuration", L["Total Duration"]
  if not lower then
    -- Remaining Time on bars, progress textures and texts: the same gate on
    -- the time left.
    local remainingLower, remainingUpper = Display.RemainingGateRange(data, trigger)
    if remainingLower then lower, upper, property, label = remainingLower, remainingUpper, "RemainingDuration", "Remaining Time" end
  end
  if not lower then
    gate:Hide()
    native.cooldown:SetUseAuraDisplayTime(false)
    native.cooldown:SetMinimumCountdownDuration(0)
    native.cooldown:SetCountdownFormatter(nil)
    -- A Stack Count filter uses the same clip.
    if not StyleStackGate(native, data, trigger) then
      -- No gate: the frame does not clip at all, as before the gate existed.
      clip:SetClipsChildren(false)
      clip:ClearAllPoints()
      clip:SetAllPoints(button)
    end
    -- A "Remaining Time < X" glow condition binds the gate text to its own
    -- clip; the %p text then shows as countdown numbers, as with a time gate.
    if native.lateGlow and native.lateGlow.exact and StyleGlowGate(native, data) then
      HandOffCountdown(native, data, true, 0)
    end
    return
  end
  -- The time gate owns the clip; a stale stack bar is released.
  StyleStackGate(native, data, nil)
  -- Font size and "open" text shared with the Stack Count "=" gate.
  local size, fill, margin = GateFill(width, height)
  local formatter, err = GateFormatter(lower, upper, fill)
  local ok = formatter ~= nil
  -- A "Remaining Time < X" glow condition shares the text with the gate
  -- (CombinedGate): the gate's part is twice as wide as the glow's, so the
  -- text's right edge tells both apart. Both clips then start at the same
  -- margin, the larger of the two.
  local late = native.lateGlow
  local combined = late and late.exact and ok and CombinedGate(native, data, lower, upper, property, margin)
  if combined then
    formatter, margin = combined.formatter, combined.margin
  end
  if ok then
    gate:SetFont(STANDARD_TEXT_FONT, size, "")
    gate:SetWordWrap(false)
    -- No fixed width: the text's own width follows what the formatter writes.
    gate:SetWidth(0)
    PlaceGateText(gate, button, margin)
    -- Always transparent: only its size matters.
    if not invisibleCurve then
      invisibleCurve = C_CurveUtil.CreateColorCurve()
      invisibleCurve:SetType(Enum.LuaCurveType.Step)
      invisibleCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
    end
    local components = {{property = Enum.DurationTextBindingProperty[property], formatter = formatter}}
    if combined then
      components[2] = {property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = combined.glowFormatter}
    end
    ok, err = pcall(button.SetDurationText, button, gate, {
      textFormat = {formatString = combined and "{}{}" or "{}", components = components},
      textColor = {curve = invisibleCurve, property = Enum.DurationTextBindingProperty[property]},
    })
  end
  if not ok then
    Warn(data, L["Blizzard refused the %s check: %s"]:format(label, tostring(err)))
    return
  end
  gate:Show()
  Display.ClipChildren(clip)
  if combined then
    -- Gate: open from the display's edge once the text is wider than the
    -- glow's part alone. Glow: once it is wider than the gate's part alone.
    AnchorEdgeClip(clip, gate, button, margin, -1.5 * combined.unit)
    AnchorEdgeClip(late.clip, gate, button, margin, -2.5 * combined.unit)
    late.clip:Show()
  else
    AnchorGateClip(clip, gate, button, margin)
    -- A glow that could not share the text stays hidden rather than always on.
    if late and late.exact then
      late.clip:Hide()
      Warn(data, L["The Remaining Time glow could not be measured; it stays off."])
    end
  end
  -- Icons with Remaining Time are drawn by the single display, not this gate.
  HandOffCountdown(native, data, data.regionType ~= "icon" or property == "TotalDuration",
    property == "TotalDuration" and lower or 0)
end

-- Maximum Duration becomes Total Duration "<=". Pre-release test builds had a
-- Match Exact Duration option; its duration becomes Total Duration "=".
function Display.MigrateTotal(trigger)
  if trigger.secretUseTotal == nil then
    if trigger.secretExactDuration and tonumber(trigger.secretDuration) then
      trigger.secretUseTotal, trigger.secretTotalOperator, trigger.secretTotal = true, "=", tostring(trigger.secretDuration)
      trigger.secretDuration = nil
    elseif type(trigger.maxDuration) == "number" then
      trigger.secretUseTotal, trigger.secretTotalOperator, trigger.secretTotal = true, "<=", tostring(trigger.maxDuration)
    end
  end
  trigger.maxDuration = nil
  trigger.secretExactDuration = nil
  trigger.secretDuration = nil
end

-- Called from Display.Apply for every instance at safe time, after the list is
-- configured and before units are bound. The single-aura parts use the first
-- instance only; containers left from an earlier multi-unit list are retired.
function Display.ConfigureSingle(instance, region, data, index)
  local trigger = Display.GetTrigger(data)
  local perUnit = Display.UnitPlacedMissing(data, trigger)
  local valid = (index == 1 or perUnit) and Display.ValidateSingle(data, trigger) == nil
  local isSingle = valid and Display.IsSingle(trigger, data)
  if valid and index == 1 then
    local lateX = Display.LateGlowSpec(data, trigger)
    Display.WatchAuraLearning(region, data, trigger, lateX)
  elseif index == 1 then
    Display.ReleaseAuraLearning(region)
  end
  local foundFollow = valid and not isSingle and Display.FoundFollow(data, trigger) ~= nil
  if not isSingle and not foundFollow and not instance.single then return end
  local single = instance.single or {}
  instance.single = single
  for _, slot in pairs(single.slots or {}) do slot.used = false end
  single.foundMode = foundFollow
  if (isSingle and NeedsMissing(trigger)) or foundFollow then
    EnsureMissing(single, region, data, trigger, perUnit and instance or nil)
  else
    DisableMissing(single)
  end
  local op, x = Display.RemainingWindow(trigger)
  if isSingle and op then EnsureRemaining(single, instance, region, data, trigger, op, x) end
  -- Parts no longer configured stop matching auras.
  for key, slot in pairs(single.slots or {}) do
    if not slot.used then
      pcall(instance.container.SetAuraSlotEnabled, instance.container, key, false)
      for _, entry in pairs(slot.glows or {}) do Display.ClearElementGlow(entry) end
      -- ForeverAuras: what the slot last drew is cleared too (see ReleaseSlotDrawing).
      ReleaseSlotDrawing(slot)
    end
  end
  -- Aura(s) Missing alone draws no live aura: the list is switched off and its
  -- buttons made invisible. Otherwise the list draws (Remaining Time styles it).
  local listDraws = not isSingle or Display.ShowOn(trigger) ~= "showOnMissing"
  single.listDisabled = not listDraws
  if instance.slotMain then
    instance.container:SetAuraSlotEnabled("Auras", listDraws)
  else
    instance.container:SetAuraGroupEnabled("Auras", listDraws)
  end
  for _, button in ipairs(instance.buttons or {}) do
    -- A flashing button rests at alpha 0 (BlizzardAuraDisplay.lua, StyleFlash).
    button.button:SetAlpha((listDraws and not Display.FlashRests(button)) and 1 or 0)
  end
end

-- Mirrors the aura list container's unit binding and visibility; unit = nil
-- with shown = false hides the Missing part.
local function Descendants(frame, list)
  for _, child in ipairs({frame:GetChildren()}) do
    list[#list + 1] = child
    Descendants(child, list)
  end
  return list
end

-- On unit frames the Missing look sits above the frame, like the aura list:
-- its clip and everything inside it keep their order, moved to that strata
-- and above that level.
local function RaiseMissing(missing, strata, level)
  local clip = missing.clip
  if clip:GetFrameStrata() == strata and clip:GetFrameLevel() == level and missing.raisedLevel == level then return end
  local frames = Descendants(clip, {})
  clip:SetFrameStrata(strata)
  clip:SetFrameLevel(level)
  missing.container:SetFrameStrata(strata)
  missing.container:SetFrameLevel(level)
  local lowest
  for _, frame in ipairs(frames) do
    if frame:GetFrameStrata() ~= strata then frame:SetFrameStrata(strata) end
    local own = frame:GetFrameLevel()
    if not lowest or own < lowest then lowest = own end
  end
  local delta = lowest and level + 1 - lowest or 0
  if delta > 0 then
    for _, frame in ipairs(frames) do frame:SetFrameLevel(frame:GetFrameLevel() + delta) end
  end
  missing.raisedLevel = level
end

-- ForeverAuras: the Missing veil. Across a loading screen the client reports
-- a unit's auras absent for a moment before they arrive again, and a Show On
-- Missing look flashed for that moment. From the start of a loading screen
-- until a second after PLAYER_ENTERING_WORLD such a look is veiled (the clip's
-- alpha, like a unit that does not exist). A clip the client will not let addon
-- code touch right now (combat) is tried again each second, a limited number of
-- times, so a veil never outlives combat.
local settling = false
local settleGeneration = 0
local settleRetries = 0
local settleTimer
local SETTLE_DELAY = 1
local SETTLE_RETRIES = 60

local function MissingVeiled(missing, instance)
  if not settling then return false end
  local trigger = instance.data and Display.GetTrigger(instance.data)
  return trigger ~= nil and Display.RawShowOn(trigger) == "showOnMissing"
end

local function MissingAlpha(missing, instance)
  if missing.unitExists and not instance.statusHidden and not MissingVeiled(missing, instance) then return 1 end
  return 0
end

function Display.SettleMissing()
  -- One retry timer at most: a pending one is dropped whenever a pass runs
  -- (an event, the unveil, or the timer itself).
  if settleTimer then settleTimer:Cancel() end
  settleTimer = nil
  local retry = false
  for region in Display.ActiveRegions() do
    local native = region.blizzardAuraDisplay
    for _, instance in ipairs(native and native.instances or {}) do
      local missing = instance.single and instance.single.missing
      if missing and missing.active and missing.clip then
        if Locked(missing.clip) then
          retry = true
        else
          missing.clip:SetAlpha(MissingAlpha(missing, instance))
        end
      end
    end
  end
  if retry and settleRetries < SETTLE_RETRIES then
    settleRetries = settleRetries + 1
    settleTimer = C_Timer.NewTimer(1, Display.SettleMissing)
  end
end

local settleEvents = CreateFrame("Frame")
settleEvents:RegisterEvent("LOADING_SCREEN_ENABLED")
settleEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
settleEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
settleEvents:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    -- Clips locked in combat get their veil, or its lifting, now.
    settleRetries = 0
    Display.SettleMissing()
    return
  end
  settleGeneration = settleGeneration + 1
  settleRetries = 0
  settling = true
  Display.SettleMissing()
  if event == "PLAYER_ENTERING_WORLD" then
    local generation = settleGeneration
    C_Timer.After(SETTLE_DELAY, function()
      -- A later loading screen owns the veil now.
      if generation ~= settleGeneration then return end
      settling = false
      settleRetries = 0
      Display.SettleMissing()
    end)
  end
end)

function Display.RefreshSingleStatus(instance)
  local missing = instance.single and instance.single.missing
  if missing and missing.active and not Locked(missing.clip) then
    missing.clip:SetAlpha(MissingAlpha(missing, instance))
  end
end

-- force: the unit behind the token can have changed (RefreshUnits): a shown
-- container is enabled and refreshed again even when it stayed enabled.
function Display.RefreshSingle(instance, unit, shown, force)
  local single = instance.single
  -- Enabling the container must not bring back a list the settings turned off.
  if shown and single and single.listDisabled then
    if instance.slotMain then
      pcall(instance.container.SetAuraSlotEnabled, instance.container, "Auras", false)
    else
      pcall(instance.container.SetAuraGroupEnabled, instance.container, "Auras", false)
    end
  end
  local missing = instance.single and instance.single.missing
  if not missing or not missing.active then return end
  local container = missing.container
  if Locked(container) or Locked(missing.clip) then return end
  -- Hiding keeps the bound unit, like the aura list container, so showing the
  -- same unit again does not rebind it.
  if unit and missing.boundUnit ~= unit then
    container:SetEnabled(false)
    container:SetUnit(unit)
    missing.boundUnit = unit
  end
  shown = shown and unit ~= nil
  -- Containers remember their enabled state (faEnabled, SecretAuraFlow.lua).
  -- One that already is enabled for this unit is kept: Blizzard refreshes it
  -- from UNIT_AURA, so enabling and refreshing it again on every unit event
  -- only cost client time. The full refresh below runs when it is enabled here.
  -- A unit change (force) on a container that stays enabled refreshes it in
  -- place: enabling it again makes the client clear and lay it out again.
  -- Erased: the presence container is never enabled; only the clip follows.
  local enable = not missing.erased and container.faEnabled ~= shown
  local refresh = enable or (shown and force and not missing.erased)
  if missing.erased and container.faEnabled then container:SetEnabled(false) end
  if container:IsShown() ~= shown then container:SetShown(shown) end
  if enable then container:SetEnabled(shown) end
  -- The Modern Aura Group spacing and centring shadow follow the same unit.
  for _, key in ipairs({"presence", "flowShadow"}) do
    local follower = missing[key]
    if follower and missing[key .. "Active"] and not Locked(follower) then
      if unit and missing[key .. "BoundUnit"] ~= unit then
        follower:SetEnabled(false)
        follower:SetUnit(unit)
        missing[key .. "BoundUnit"] = unit
      end
      if follower:IsShown() ~= shown then follower:SetShown(shown) end
      local followerEnable = follower.faEnabled ~= shown
      if followerEnable then follower:SetEnabled(shown) end
      if shown and (followerEnable or force) then follower:UpdateAllAuras() end
    end
  end
  -- A disabled container keeps its last width; the clip must not show then.
  missing.clip:SetShown(shown)
  if missing.slot and shown then
    local strata, level = instance.drawStrata, instance.drawLevel
    if not strata then strata = instance.container:GetFrameStrata() end
    if not level then level = instance.container:GetFrameLevel() end
    if not issecretvalue(strata) and not issecretvalue(level) then RaiseMissing(missing, strata, level + 1) end
  end
  -- No unit (no target, focus or pet): nothing is missing. The display itself
  -- stays shown, since its frames may be protected in combat; only the Missing
  -- look fades, through its alpha. With Show If Unit Does Not Exist ticked the
  -- trigger stays active without the unit, and the Missing look stays too.
  local trigger = instance.data and Display.GetTrigger(instance.data)
  local keepWithoutUnit = trigger and trigger.unitExists
  missing.unitExists = keepWithoutUnit or Display.SingleUnitExists({unit = unit})
  -- ForeverAuras: veiled across loading screens (MissingAlpha).
  missing.clip:SetAlpha(MissingAlpha(missing, instance))
  if shown and refresh then container:UpdateAllAuras(); Private.HitchCount("UpdateAllAuras") end
end

learnEvents:SetScript("OnEvent", Private.Profiled("aura (modern) - learning", learnEvents:GetScript("OnEvent")))

-- ForeverAuras: "/fa modern <id>" report. Plain reads only; secret values
-- print as such. Everything goes to chat, so a report can be pasted.
function Display.PrintDebug(id)
  local function Fmt(value)
    if value == nil then return "nil" end
    if issecretvalue(value) then return "<secret>" end
    if type(value) == "number" then return string.format("%.1f", value) end
    return tostring(value)
  end
  local function Say(...) print("|cff88ccffFA modern|r " .. table.concat({...}, " ")) end
  local data = id and WeakAuras.GetData(id)
  if not data then Say("no aura named", tostring(id)); return end
  local entry = Private.regions[id]
  local region = entry and entry.region
  Say(id, "loaded", Fmt(Private.loaded[id]), "region", Fmt(region ~= nil), "shown", Fmt(region and region:IsShown()))
  local trigger = Display.GetTrigger(data)
  if not trigger then Say("no Aura (Modern) trigger"); return end
  Say("showOn", Fmt(Display.ShowOn(trigger)), "unit", Fmt(trigger.unit), "list key", Fmt(trigger.secretSpellList))
  local list = Display.SpellList(trigger)
  if trigger.secretSpellList and trigger.secretSpellList ~= "" then
    if list then
      Say("list name", Fmt(list.name), "icon", Fmt(list.icon), "ids", table.concat(list.spellIDs, ","), "remaining", Fmt(list.remaining))
    else
      Say("list", trigger.secretSpellList, "is NOT set")
    end
  end
  Say("ids used", table.concat(Display.GetSpellIDs(trigger, true), ","), "icon", Fmt(Display.SingleIcon(data)))
  local native = region and region.blizzardAuraDisplay
  if not native then Say("no native display"); return end
  Say("native active", Fmt(native.active), "instances", Fmt(native.instances and #native.instances))
  for index, instance in ipairs(native.instances or {}) do
    local single = instance.single
    local missing = single and single.missing
    Say("instance", index, "container", Fmt(instance.container and instance.container:GetWidth()), "x", Fmt(instance.container and instance.container:GetHeight()),
      "shown", Fmt(instance.container and instance.container:IsShown()))
    if missing then
      local c, clip = missing.container, missing.clip
      Say(" missing active", Fmt(missing.active), "erased", Fmt(missing.erased), "failed", Fmt(single.missingFailed))
      Say(" presence container", Fmt(c and c:GetWidth()), "x", Fmt(c and c:GetHeight()), "left", Fmt(c and c:GetLeft()), "top", Fmt(c and c:GetTop()), "shown", Fmt(c and c:IsShown()))
      Say(" clip", Fmt(clip and clip:GetWidth()), "x", Fmt(clip and clip:GetHeight()), "left", Fmt(clip and clip:GetLeft()), "top", Fmt(clip and clip:GetTop()), "shown", Fmt(clip and clip:IsShown()))
      local sample = missing.native and missing.native.button
      local icon = missing.native and missing.native.icon
      Say(" sample", Fmt(sample and sample:GetWidth()), "left", Fmt(sample and sample:GetLeft()), "top", Fmt(sample and sample:GetTop()), "alpha", Fmt(sample and sample:GetAlpha()), "texture", Fmt(icon and icon:GetTexture()))
      for n = 1, (c and c.GetNumChildren and c:GetNumChildren() or 0) do
        local child = select(n, c:GetChildren())
        Say("  presence child", n, Fmt(child:GetWidth()), "x", Fmt(child:GetHeight()), "shown", Fmt(child:IsShown()))
      end
    end
  end
  Say("region", Fmt(region:GetWidth()), "x", Fmt(region:GetHeight()), "left", Fmt(region:GetLeft()), "top", Fmt(region:GetTop()), "scale", Fmt(region:GetEffectiveScale()))
  -- Every font string under the display that carries text: what draws it,
  -- where it hangs and whether it is visible, for a text that stays behind.
  -- The font strings this file and SecretAuraAppearance.lua make are named by
  -- their part, so a stale text can be told from a live binding.
  local labels = {}
  local function Label(object, label) if object then labels[object] = label end end
  local function LabelNative(owner, prefix)
    if not owner then return end
    Label(owner.mainText, prefix .. " main text")
    Label(owner.gateText, prefix .. " gate")
    local cooldown = owner.cooldown
    if cooldown and cooldown.GetCountdownFontString then
      local okN, numbers = pcall(cooldown.GetCountdownFontString, cooldown)
      if okN then Label(numbers, prefix .. " cooldown numbers") end
    end
    for index, element in pairs(owner.sharedElements or {}) do
      Label(element.text, prefix .. " element " .. tostring(index))
    end
  end
  for index, instance in ipairs(native.instances or {}) do
    for n, button in ipairs(instance.buttons or {}) do
      LabelNative(button, "list button " .. index .. "." .. n)
      -- Which list buttons the client is drawing: a released one that still
      -- shows would be a text left behind.
      local okS, shown = pcall(button.button.IsShown, button.button)
      local okA, alpha = pcall(button.button.GetAlpha, button.button)
      -- A secret shown state cannot be compared, only reported.
      if okS and (issecretvalue(shown) or shown == true) then
        Say(" list button", index .. "." .. n, "shown", Fmt(shown), "alpha", Fmt(okA and alpha))
      end
    end
    for key, slot in pairs(instance.single and instance.single.slots or {}) do
      local okS, shown = pcall(slot.button.IsShown, slot.button)
      Say(" slot", tostring(key), "used", Fmt(slot.used), "shown", Fmt(okS and shown))
    end
    local single = instance.single
    for key, slot in pairs(single and single.slots or {}) do
      local used = slot.used and "" or " (unused)"
      Label(slot.gate, "slot " .. tostring(key) .. " gate" .. used)
      Label(slot.text, "slot " .. tostring(key) .. " artwork" .. used)
      Label(slot.probe, "slot " .. tostring(key) .. " probe" .. used)
      LabelNative(slot, "slot " .. tostring(key) .. used)
    end
    if single and single.missing then LabelNative(single.missing.native, "missing sample") end
  end
  for index, sample in ipairs(region.secretAuraSamples or {}) do LabelNative(sample, "preview sample " .. index) end
  for index, frame in ipairs(region.subRegions or {}) do Label(frame.text, "WA element " .. index) end
  local count = 0
  local function Walk(frame, path, depth)
    if depth > 8 or count > 40 then return end
    local okR, regions = pcall(function() return {frame:GetRegions()} end)
    for _, object in ipairs(okR and regions or {}) do
      local okT, kind = pcall(object.GetObjectType, object)
      if okT and kind == "FontString" then
        local okS, text = pcall(object.GetText, object)
        -- A Blizzard aura button's text can be secret: reported, not read.
        if okS and issecretvalue(text) then text = "<secret text>" end
        if okS and type(text) == "string" and text ~= "" then
          count = count + 1
          local okV, visible = pcall(object.IsVisible, object)
          local okA, alpha = pcall(object.GetAlpha, object)
          local okL, left, top = pcall(function() return object:GetLeft(), object:GetTop() end)
          if okL and (issecretvalue(left) or issecretvalue(top)) then left, top = "<secret>", "<secret>" end
          Say(" text", string.format("%q", text), "is", labels[object] or "unknown", "at", path, "visible", Fmt(okV and visible),
            "alpha", Fmt(okA and alpha), "left", Fmt(okL and left), "top", Fmt(okL and top))
        end
      end
    end
    local okC, children = pcall(function() return {frame:GetChildren()} end)
    for index, child in ipairs(okC and children or {}) do
      local okN, name = pcall(child.GetDebugName, child)
      if not okN or type(name) ~= "string" or issecretvalue(name) then name = nil end
      local okF, faKind = pcall(function() return child.faEnabled ~= nil and "container" or nil end)
      Walk(child, path .. "/" .. (name and name:match("[^.]+$") or (okF and faKind) or tostring(index)), depth + 1)
    end
  end
  Walk(region, "region", 0)
  Say("texts with content:", count)
end
