-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("CDMAuraProgress")
local Display = {}
Private.CDMAuraProgress = Display

function Display.IsConfigured(data)
  if not data or type(data.triggers) ~= "table" then return false end
  local source = data.progressSource and data.progressSource[1] or -1
  if source == 0 then return false end
  if source < 0 then source = data.triggers.activeTriggerMode or -1 end
  if source < 0 and #data.triggers == 1 then source = 1 end
  local entry = data.triggers[source]
  return type(entry) == "table" and entry.trigger and entry.trigger.type == "cdm" and entry.trigger.event == "Blizzard CDM Buff" or false
end

local function SourceState(parent, explicit)
  local source = explicit or (parent.progressSource and parent.progressSource[1]) or -1
  if source > 0 then return parent.states and parent.states[source] end
  if source == -1 then return parent.state end
end

function Display.IsInactive(region)
  local state = SourceState(region)
  return state and state.cdmBuff and state.auraActive == false or false
end

-- Native aura slots supply missing CDM target-debuff timers only. Player buffs,
-- helpful target auras, previews, totems and spell CDM retain their existing path.
local function NativeSource(state, anyProgress)
  if not CustomAuraContainerAuraProcessingPolicy or not state or not state.cdmBuff
      or not state.show or state.cdmTextPreview or state.cdmAuraTotem
      or state.auraActive == false or (not anyProgress and state.progressType ~= "static") then return end
  -- The player's own buffs and target debuffs (either filter) pass the
  -- container's identity gate whatever their secrecy; other units do not.
  local unit = state.cdmAuraRenderUnit
  if unit ~= "target" and unit ~= "player" then return end
  local ids = state.cdmAuraRenderSpellIDs
  if type(ids) ~= "table" or not next(ids) then return end
  return unit, state.cdmAuraFilter or "HELPFUL", ids
end

-- The first CDM Buff trigger of a display that requires a target.
local function TargetDebuffTrigger(data)
  for index, entry in ipairs(data and data.triggers or {}) do
    local trigger = type(entry) == "table" and entry.trigger
    if trigger and trigger.type == "cdm" and trigger.event == "Blizzard CDM Buff" then return index end
  end
end

-- In combat the viewer's unit and aura are secret, so NativeSource has no
-- render source and the trigger cannot tell whether its debuff is up (its
-- state is inactive with the Aura Active show mode, so the display may be
-- drawn by another trigger). A trigger that requires a target then watches
-- the player's own debuffs on the target by spell ID: the trigger's own IDs
-- plus every ID of its Names list (any of these spells), each with all its
-- ranks, as the catalog does. Nothing is bound while the answer is readable.
-- Whether a spell is cast on enemies (its aura is then a debuff on the
-- target), from spell data, which is never secret. Cached per spell.
local function SpellHarmful(spellID)
  return Private.CDMSpellTargetsEnemy(spellID)
end

local function TargetDebuffFallback(region, index, allowActive)
  local data = region.cdmProgressData
  local entry = index and data and data.triggers and data.triggers[index]
  local trigger = type(entry) == "table" and entry.trigger
  if not (trigger and trigger.type == "cdm" and trigger.event == "Blizzard CDM Buff") then return end
  local state = region.states and region.states[index]
  if (not state or state.show == nil) and Private.CDMLastOutput and WeakAuras.GetTriggerStateForTrigger then
    state = Private.CDMLastOutput(WeakAuras.GetTriggerStateForTrigger(region.id, index))
  end
  -- allowActive: a readable, active aura may bind too (the live icon copy).
  if not state or not state.cdmBuff or state.cdmTextPreview or state.cdmAuraTotem or state.auraActive == false or (not allowActive and state.auraActive ~= nil) then return end
  local ranks, seen = {}, {}
  local function AddID(id)
    id = tonumber(id)
    if not id then return end
    for _, rankID in ipairs(Private.GetAuraSpellRanks and Private.GetAuraSpellRanks(id) or {id}) do
      if type(rankID) == "number" and not seen[rankID] then seen[rankID] = true; ranks[#ranks + 1] = rankID end
    end
  end
  for _, id in ipairs(type(state.cdmAuraSpellIDs) == "table" and state.cdmAuraSpellIDs or {}) do AddID(id) end
  if trigger.cdmUseNames then for _, id in ipairs(type(trigger.cdmNames) == "table" and trigger.cdmNames or {}) do AddID(id) end end
  if trigger.cdmUseExactIDs then for _, id in ipairs(type(trigger.cdmExactIDs) == "table" and trigger.cdmExactIDs or {}) do AddID(id) end end
  if #ranks == 0 then return end
  -- The unit: a trigger that requires a target watches the target. Otherwise
  -- the spells decide: a harmful spell's aura is the player's debuff on the
  -- target, a helpful one the player's own buff (the unit the viewer frame
  -- reported while readable, kept in the state, wins when it was seen).
  local unit, filter
  if trigger.cdmRequireTarget then
    unit, filter = "target", "HARMFUL|PLAYER"
  elseif state.cdmAuraSourceSeen and (state.cdmAuraUnit == "target" or state.cdmAuraUnit == "player") then
    unit = state.cdmAuraUnit
    filter = unit == "target" and ((state.cdmAuraFilter or ""):find("HELPFUL") and "HELPFUL|PLAYER" or "HARMFUL|PLAYER") or "HELPFUL"
  else
    local harmful = false
    for _, id in ipairs(ranks) do
      if SpellHarmful(id) then harmful = true; break end
    end
    if harmful then unit, filter = "target", "HARMFUL|PLAYER" else unit, filter = "player", "HELPFUL" end
  end
  return unit, filter, ranks, state
end

-- IsForbidden only reports explicit prohibition, not conditional aura access.
-- Require the documented context check to grant public access after creation;
-- older clients, failed queries and secret answers must all skip widget calls.
local function CanStyleWidget(widget, initializing)
  if initializing then return true end
  if type(widget.CanBeAccessedInContext) ~= "function" then return false end
  local ok, allowed = pcall(widget.CanBeAccessedInContext, widget)
  return ok and not (issecretvalue and issecretvalue(allowed)) and allowed == true
end

-- Each display element owns its slot and descendants. Never reparent or read
-- back a widget after Blizzard has given its timer/text secret aspects.
local function CreateNative(owner, initialize, region)
  local native = {owner = owner, region = region or owner}
  local container = CreateFrame("AuraContainer", nil, owner, "CustomAuraContainerTemplate")
  native.container = container
  container:SetEnabled(false)
  container:SetAllPoints(owner)
  native.anchoredTo = owner
  -- Descendants inherit later level changes from this addon-accessible parent.
  -- Their own frame methods may become forbidden after initializeFrame returns.
  container:SetFrameLevel(owner:GetFrameLevel())
  container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
  container:AddAuraSlot("Timer", "HELPFUL", {
    candidateFilters = {includeSpellIDs = {}},
    initializeFrame = function(button)
      native.button = button
      button:SetAllPoints(container)
      button:SetFrameLevel(container:GetFrameLevel())
      button:EnableMouse(false)
      initialize(native, button)
      -- A visibility gate set before the button existed applies now.
      local region = owner.nativeShowGate and owner or nil
      if region and region.RealSetAlpha then
        C_Timer.After(0, function()
          if region.nativeShowGate then region:SetAlpha(region.requestedAlpha or region.animAlpha or region.alpha or 1) end
        end)
      end
    end,
  })
  -- Disable native event processing when the owning aura/subtext is hidden.
  -- The public owner controls lifecycle; native slot visibility is never read.
  TimedHookScript(owner, "OnHide", function() container:SetEnabled(false) end)
  TimedHookScript(owner, "OnShow", function() container:SetEnabled(native.wanted == true) end)
  return native
end

-- Where a native container draws: over its owner, or, while a Modern Aura
-- Group's stand-in draws the display (the region itself is parked off
-- screen then), over the stand-in's copy of the owner (its proxy for the
-- region itself). Checked on every update, since the stand-in comes and goes.
local function StandOf(region)
  local normal = region and region.flowNormal
  local stand = normal and normal.stand
  if stand and stand.active then return stand end
end
local function NativeAnchor(native)
  local owner = native.owner
  local region = native.region or owner
  local stand = StandOf(region)
  if not stand then return owner end
  -- Candidates, best first: the copy of the element (texts), the proxy that
  -- mirrors the stand-in's rect, the stand-in's own frame and its parents.
  -- A frame carrying a layout-script aspect cannot take dependents (the
  -- client refuses the anchor), so each is tried and the first that takes
  -- the container wins; the owner remains the fallback.
  local list = {}
  if owner ~= region then list[#list + 1] = stand.copies and stand.copies[owner] end
  list[#list + 1] = stand.frame
  list[#list + 1] = stand.proxy
  local parent = stand.frame and stand.frame:GetParent()
  while parent and parent ~= UIParent and #list < 8 do
    list[#list + 1] = parent
    parent = parent:GetParent()
  end
  list[#list + 1] = owner
  return list
end
local function PlaceNative(native)
  local anchor = NativeAnchor(native)
  local stand = StandOf(native.region or native.owner)
  if type(anchor) ~= "table" then
    if native.anchoredTo == anchor then return end
    native.anchoredTo = anchor
    native.container:ClearAllPoints()
    native.container:SetAllPoints(anchor)
    return
  end
  -- A frame that refused the container once is not asked again.
  local refused = native.refusedAnchors
  if not refused then refused = setmetatable({}, {__mode = "k"}); native.refusedAnchors = refused end
  for _, target in ipairs(anchor) do
    if target and not refused[target] then
      if native.anchoredTo == target then return end
      native.container:ClearAllPoints()
      if pcall(native.container.SetAllPoints, native.container, target) then
        native.anchoredTo = target
        -- Drawn above the stand-in's copies, which live in its chain frame:
        -- that frame's strata, a few levels up, whichever frame took the
        -- anchor (the slot's contents keep their offsets from the container).
        local chain = stand.frame or target
        local okS, strata = pcall(chain.GetFrameStrata, chain)
        if okS and type(strata) == "string" then pcall(native.container.SetFrameStrata, native.container, strata) end
        local okL, level = pcall(chain.GetFrameLevel, chain)
        if okL and type(level) == "number" and not issecretvalue(level) then native.container:SetFrameLevel(level + 5 + (native.levelOffset or 0)) end
        return
      end
      refused[target] = true
    end
  end
  if native.anchoredTo ~= native.owner then
    native.anchoredTo = native.owner
    native.container:ClearAllPoints()
    native.container:SetAllPoints(native.owner)
    pcall(native.container.SetFrameStrata, native.container, native.owner:GetFrameStrata())
    native.container:SetFrameLevel(native.owner:GetFrameLevel())
  end
end

-- A disabled container can keep its last button on screen (in combat the
-- button cannot be touched), so the container itself, the addon's own frame,
-- is hidden with it and shown again when it is next bound.
-- A display hidden for Aura(s) Found (its show gate hides it, RegionPrototype)
-- still draws through its slots: each container then ignores the display's
-- alpha and takes the asked-for one itself (a slot look keeps its own).
local function ApplyNativeAlpha(native)
  local container = native and native.container
  if not container or not container.SetIgnoreParentAlpha then return end
  local region = native.region or native.owner
  local gate = region and region.nativeShowGate
  local hidden = gate and gate.hide == true or false
  if native.ownAlpha then hidden = true end
  if native.ignoringAlpha ~= hidden then
    native.ignoringAlpha = hidden
    container:SetIgnoreParentAlpha(hidden)
  end
  if hidden then container:SetAlpha(native.ownAlpha or region.requestedAlpha or region.alpha or 1) end
end
local function SyncNativeAlphas(region)
  ApplyNativeAlpha(region.cdmAuraTimer)
  ApplyNativeAlpha(region.cdmAuraSaturate)
  for _, sub in ipairs(region.subRegions or {}) do
    if sub.cdmAuraTimer then ApplyNativeAlpha(sub.cdmAuraTimer) end
  end
end

local function DisableNative(native)
  if native and native.wanted then
    native.wanted = false
    native.container:SetEnabled(false)
    native.container:Hide()
  end
end

local function BindNative(native, unit, filter, ids)
  -- Cache public configuration, not aura data. FrameTick must not rebuild the
  -- native aura query or reset its timer on every text update.
  local ordered, include = {}, {}
  for _, id in ipairs(ids) do
    if not (issecretvalue and issecretvalue(id)) and type(id) == "number" and id > 0 and not include[id] then
      include[id] = true
      ordered[#ordered + 1] = id
    end
  end
  table.sort(ordered)
  local key = unit .. ":" .. filter .. ":" .. table.concat(ordered, ",")
  if native.key ~= key then
    native.container:SetEnabled(false)
    native.container:SetUnit(unit)
    native.container:SetAuraSlotFilterString("Timer", filter)
    native.container:SetAuraSlotCandidateFilters("Timer", {includeSpellIDs = include})
    native.key = key
  end
  if native.key ~= native.enabledKey or not native.wanted then
    native.wanted = true
    native.enabledKey = native.key
    native.container:Show()
    native.container:SetEnabled(native.owner:IsVisible())
  end
  PlaceNative(native)
  ApplyNativeAlpha(native)
end

-- A condition "Active is false -> Desaturate on" (or "Aura Active is false")
-- of a CDM Buff trigger: the trigger index it watches, or nil. When Blizzard
-- keeps the aura's presence secret (target debuffs in combat) the trigger
-- reads as inactive and the icon would stay grey with the debuff up, so
-- Display.UpdateSaturation draws the saturated icon natively instead.
local function InactiveDesaturateTrigger(data)
  for _, condition in ipairs(data and data.conditions or {}) do
    local check = condition.check
    if type(check) == "table" and (check.variable == "auraActive" or check.variable == "show") and (check.value == 0 or check.value == false) then
      local index = tonumber(check.trigger)
      local entry = index and data.triggers and data.triggers[index]
      if type(entry) == "table" and entry.trigger and entry.trigger.type == "cdm" and entry.trigger.event == "Blizzard CDM Buff" then
        for _, change in ipairs(condition.changes or {}) do
          if change.property == "desaturate" and change.value == true then return index end
        end
      end
    end
  end
end

-- The Aura Active conditions of a display's CDM Buff trigger: the changes
-- for "Aura Active is false" (the missing look) and "is true" (the present
-- look), plus the trigger index. While the aura's presence is secret the
-- condition engine paints the missing look (its Aura Active test reads
-- unknown as false, CooldownViewerTrigger.lua) and a native copy of the icon
-- carrying the present look is shown by Blizzard for as long as the aura is
-- up. The copy follows what a texture can: icon, colour, desaturation,
-- alpha; texts, borders and glows keep the missing look meanwhile.
local lookProperties = {desaturate = true, color = true, displayIcon = true, alpha = true, iconSource = true}
-- Defined with the native visibility gates below; used by Display.Modify.
local ApplyElementGates
local function AuraActiveLooks(data)
  local looks
  -- The Aura Active check of a condition: direct, or one of the checks of an
  -- "All of" (the other checks are evaluated by the condition engine for the
  -- missing look; the present copy applies the changes while the aura is up).
  local function AuraActiveCheck(check)
    if type(check) ~= "table" then return end
    if check.variable == "auraActive" then return check end
    if check.variable == "AND" then
      for _, child in ipairs(check.checks or {}) do
        if type(child) == "table" and child.variable == "auraActive" then return child end
      end
    end
  end
  for _, condition in ipairs(data and data.conditions or {}) do
    local check = AuraActiveCheck(condition.check)
    if check and not condition.linked then
      local index = tonumber(check.trigger)
      local entry = index and data.triggers and data.triggers[index]
      if type(entry) == "table" and entry.trigger and entry.trigger.type == "cdm" and entry.trigger.event == "Blizzard CDM Buff" then
        looks = looks or {index = index, missing = {}, present = {}, elements = {}}
        local missing = check.value == 0 or check.value == false
        local look = missing and looks.missing or looks.present
        for _, change in ipairs(condition.changes or {}) do
          if lookProperties[change.property] then look[change.property] = change.value end
          -- Visibility of a sub element (text, border, glow, texture): gated
          -- natively while the aura is secret (ElementGates).
          local sub, property = tostring(change.property or ""):match("^sub%.(%d+)%.(%a+_visible)$")
          if not sub then sub, property = tostring(change.property or ""):match("^sub%.(%d+)%.(glow)$") end
          if sub then
            local element = looks.elements[tonumber(sub)] or {}
            looks.elements[tonumber(sub)] = element
            element[missing and "missing" or "present"] = change.value == true
          end
        end
      end
    end
  end
  return looks
end

-- The Remaining Time conditions of a display's CDM Buff trigger that turn a
-- Glow element on: each becomes a native gate on the timer slot, drawn by
-- Blizzard from the aura's own remaining time (as the Modern trigger's glow
-- gate): a hidden gate text that the duration-text formatter fills inside the
-- window and empties outside it gives a clip its width, and the Glow
-- element's look is built inside that clip at the slot's creation. In combat
-- the Lua condition cannot read the time; out of combat it decides as usual
-- and the slot is not bound, so the two never both draw.
local REMAIN_EPS = 0.001
-- A comparison on a time as a window {lower, upper} (upper nil: open).
local function TimeWindow(op, value)
  if op == "<" then return {lower = 0, upper = value - REMAIN_EPS}
  elseif op == "<=" then return {lower = 0, upper = value}
  elseif op == ">" then return {lower = value + REMAIN_EPS}
  elseif op == ">=" then return {lower = value} end
  return {lower = value, upper = value}
end
-- A comparison on a stack count as a native gate: "atLeast"/"atMost"/"exactly"
-- and the count, or nil when no gate draws it (~=, or below zero).
function Private.CDMNativeStackGate(op, value)
  value = tonumber(value)
  if not value or value < 0 or value ~= math.floor(value) then return end
  if op == ">=" then return "atLeast", value
  elseif op == ">" then return "atLeast", value + 1
  elseif op == "<=" then return "atMost", value
  elseif op == "<" then if value >= 1 then return "atMost", value - 1 end
  elseif op == "==" then return "exactly", value end
end
-- The Remaining Time, Elapsed Time and Stack Count conditions of the
-- display's CDM Buff trigger that turn Glow elements on, each as a gate:
-- {property, lower, upper, subs} for the times, {stack = kind, n, subs} for
-- stacks. The trigger's own Stack Count filter takes the slot's one
-- application binding first (the gate slots), so a stack condition is drawn
-- natively only when no stack filter is set.
local gateVariables = {cdmRemaining = "RemainingDuration", cdmElapsed = "ElapsedDuration", stacks = "stacks"}
local function RemainingGlowGates(data)
  local gates
  local function GateCheck(check)
    if type(check) ~= "table" then return end
    if gateVariables[check.variable] then return check end
    if check.variable == "AND" then
      for _, child in ipairs(check.checks or {}) do
        if type(child) == "table" and gateVariables[child.variable] then return child end
      end
    end
  end
  for _, condition in ipairs(data and data.conditions or {}) do
    local check = GateCheck(condition.check)
    local value = check and tonumber(check.value)
    if check and value and value >= 0 and not condition.linked then
      local index = tonumber(check.trigger)
      local entry = index and data.triggers and data.triggers[index]
      if type(entry) == "table" and entry.trigger and entry.trigger.type == "cdm" and entry.trigger.event == "Blizzard CDM Buff" then
        local subs = {}
        for _, change in ipairs(condition.changes or {}) do
          local sub = tostring(change.property or ""):match("^sub%.(%d+)%.glow$")
          local element = sub and data.subRegions and data.subRegions[tonumber(sub)]
          if element and element.type == "subglow" and change.value == true then subs[#subs + 1] = tonumber(sub) end
        end
        if #subs > 0 then
          local op = check.op or "<"
          if check.variable == "stacks" then
            local kind, n = Private.CDMNativeStackGate(op, value)
            if kind and not entry.trigger.cdmUseStacks then
              gates = gates or {index = index}
              gates[#gates + 1] = {stack = kind, n = n, subs = subs}
            end
          else
            local window = TimeWindow(op, value)
            gates = gates or {index = index}
            gates[#gates + 1] = {property = gateVariables[check.variable], lower = window.lower, upper = window.upper, subs = subs}
          end
        end
      end
    end
  end
  return gates
end

-- The filters of the display's CDM Buff trigger that are drawn natively:
-- {remaining = window, elapsed = window, stacks = {kind, n}}, or nil when
-- none is set. (Total Duration stays a readable-only filter.)
local function RemainingFilterWindow(data)
  local index = TargetDebuffTrigger(data)
  local entry = index and data.triggers[index]
  local trigger = entry and entry.trigger
  if not trigger then return end
  local windows
  if trigger.cdmUseRemaining then
    local value = tonumber(trigger.cdmRemainingTime or 10)
    if value and value >= 0 then
      windows = windows or {}
      windows.remaining = TimeWindow(trigger.cdmRemainingOperator or "<", value)
    end
  end
  if trigger.cdmUseElapsed then
    local value = tonumber(trigger.cdmElapsedTime or 10)
    if value and value >= 0 then
      windows = windows or {}
      windows.elapsed = TimeWindow(trigger.cdmElapsedOperator or ">=", value)
    end
  end
  if trigger.cdmUseStacks then
    local kind, n = Private.CDMNativeStackGate(trigger.cdmStackOperator or ">=", trigger.cdmStackCount or 1)
    if kind then
      windows = windows or {}
      windows.stacks = {kind = kind, n = n}
    end
  end
  return windows
end
local function WindowKey(windows)
  if not windows then return "nofilter" end
  local parts = {}
  for _, key in ipairs({"remaining", "elapsed"}) do
    local window = windows[key]
    if window then parts[#parts + 1] = key .. tostring(window.lower) .. ".." .. tostring(window.upper) end
  end
  if windows.stacks then parts[#parts + 1] = "stacks" .. windows.stacks.kind .. windows.stacks.n end
  return table.concat(parts, ",")
end

-- A step colour curve: colour inside the window, transparent outside it.
local function WindowCurve(window, r, g, b, a)
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return end
  local curve = C_CurveUtil.CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  if window.lower <= 0 then curve:AddPoint(0, CreateColor(r, g, b, a))
  else
    curve:AddPoint(0, CreateColor(r, g, b, 0))
    curve:AddPoint(window.lower, CreateColor(r, g, b, a))
  end
  if window.upper then curve:AddPoint(window.upper + REMAIN_EPS, CreateColor(r, g, b, 0)) end
  return curve
end
Display.WindowCurve, Display.RemainingFilterWindow = WindowCurve, RemainingFilterWindow

local GLOW_KEYS = {"glowType", "glowLines", "glowFrequency", "glowLength", "glowThickness", "glowXOffset",
  "glowYOffset", "glowScale", "glowBorder", "glowDuration", "useGlowColor"}
local function GlowGateKey(data, gates, windows, look)
  local parts = {tostring(data.width), tostring(data.height), WindowKey(windows), look or "nolook"}
  if not gates then return table.concat(parts, "|") end
  for _, gate in ipairs(gates) do
    parts[#parts + 1] = tostring(gate.property) .. tostring(gate.lower) .. "-" .. tostring(gate.upper) .. tostring(gate.stack) .. tostring(gate.n)
    for _, sub in ipairs(gate.subs) do
      local element = data.subRegions[sub]
      parts[#parts + 1] = tostring(sub)
      for _, key in ipairs(GLOW_KEYS) do parts[#parts + 1] = tostring(element[key]) end
      if type(element.glowColor) == "table" then for i = 1, 4 do parts[#parts + 1] = tostring(element.glowColor[i]) end end
    end
  end
  return table.concat(parts, "|")
end

local invisibleCurve
local function InvisibleCurve()
  if not invisibleCurve and C_CurveUtil and C_CurveUtil.CreateColorCurve then
    invisibleCurve = C_CurveUtil.CreateColorCurve()
    invisibleCurve:SetType(Enum.LuaCurveType.Step)
    invisibleCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
  end
  return invisibleCurve
end

-- A gate's measurement on the slot's button, inside its creation window. A
-- time gate ({property, window, width, height}): a hidden text Blizzard
-- formats from the property into a fill inside the window and nothing
-- outside it, so its width is the clip's. A stack gate ({stack = "atLeast"/
-- "atMost", n, width, height}): an invisible application bar whose fill edge
-- is the clip's edge (the Aura (Modern) display's method); exactly n
-- ({stack = "exactly"}): a hidden application count text, a fill at n.
-- A button carries one duration text, one application bar and one
-- application count (a second binding of a kind replaces the first), and
-- in combat nothing of another button can be reached, so a slot draws at
-- most one gate of each kind: the first asked for wins (`used` remembers),
-- the rest stay with the readable path. Returns the part or nil.
local function BuildGatePart(button, gate, used)
  local modern = Private.BlizzardAuraDisplay
  if not modern or not modern.GateFill or not modern.GateFormatter then return end
  local kind = gate.property and "text" or (gate.stack == "exactly" and "count" or "bar")
  if used[kind] then return end
  used[kind] = true
  local width, height = gate.width or 64, gate.height or 64
  local size, fill, margin = modern.GateFill(width, height)
  if gate.property then
    local curve = InvisibleCurve()
    local enum = Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty[gate.property]
    if not curve or enum == nil then return end
    local formatter = modern.GateFormatter(gate.window.lower, gate.window.upper, fill)
    if not formatter then return end
    local text = button:CreateFontString(nil, "BACKGROUND")
    text:SetFont(STANDARD_TEXT_FONT, size, "")
    text:SetWordWrap(false)
    text:SetWidth(0)
    text:SetTextColor(0, 0, 0, 0)
    local ok = pcall(button.SetDurationText, button, text, {
      textFormat = {formatString = "{}", components = {{property = enum, formatter = formatter}}},
      textColor = {curve = curve, property = enum},
    })
    if not ok then text:Hide(); return end
    return {text = text, margin = margin}
  end
  if gate.stack == "exactly" then
    if not button.SetApplicationCount or not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter then return end
    local formatter = modern.GateFormatter(gate.n, gate.n, fill)
    if not formatter then return end
    local text = button:CreateFontString(nil, "BACKGROUND")
    text:SetFont(STANDARD_TEXT_FONT, size, "")
    text:SetWordWrap(false)
    text:SetWidth(0)
    text:SetTextColor(0, 0, 0, 0)
    text:SetAlpha(0)
    if not pcall(button.SetApplicationCount, button, text, {formatter = formatter}) then text:Hide(); return end
    return {text = text, margin = margin}
  end
  if not button.SetApplicationBar then return end
  local k = width + 2 * margin
  local max = gate.stack == "atLeast" and gate.n or gate.n + 1
  if max < 1 then return end
  local bar = CreateFrame("StatusBar", nil, button)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  bar:SetStatusBarColor(0, 0, 0, 0)
  bar:SetAlpha(0)
  bar:SetSize(max * k, height + 2 * margin)
  if not pcall(button.SetApplicationBar, button, bar, {maxApplications = max}) then bar:Hide(); return end
  return {bar = bar, margin = margin, k = k, kind = gate.stack, n = gate.n}
end

-- A clip hung on a gate's measurement, made in `parent` (the Timer button or
-- the previous clip, nesting the windows) with `frame` (the display's box)
-- for its top and bottom; the measurement is placed against that frame
-- here, in the Timer slot's creation window. Returns the clip, or nil when
-- the part was not built (its slot has not initialised, or was refused).
local function BuildGateClip(parent, frame, part)
  local modern = Private.BlizzardAuraDisplay
  if not part or not modern or not modern.ClipChildren then return end
  local margin = part.margin
  local clip = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
  clip:EnableMouse(false)
  modern.ClipChildren(clip)
  local ok = pcall(function()
    if part.text then
      modern.PlaceGateText(part.text, frame, margin)
      modern.AnchorGateClip(clip, part.text, frame, margin)
    else
      local bar, k, n = part.bar, part.k, part.n
      bar:ClearAllPoints()
      clip:ClearAllPoints()
      if part.kind == "atLeast" then
        -- The bar ends where the clip should end; its fill reaches there at
        -- n stacks and Blizzard caps the value at n.
        bar:SetPoint("LEFT", frame, "LEFT", -margin - (n - 1) * k, 0)
        clip:SetPoint("TOPLEFT", bar, "TOPLEFT", (n - 1) * k, 0)
        clip:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
      else
        -- The clip runs from the fill edge to the bar's end: it covers the
        -- display up to n stacks and closes once the bar is full at n + 1.
        bar:SetPoint("RIGHT", frame, "RIGHT", margin, 0)
        clip:SetPoint("TOPLEFT", bar:GetStatusBarTexture(), "TOPRIGHT")
        clip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
      end
    end
  end)
  if not ok then clip:Hide(); return end
  clip.gateMargin = margin
  return clip
end

-- The gates a display's slot needs, in order: the filters' windows first
-- (their clips nest, innermost last), then the Glow conditions' gates.
-- Returns the list and the number of filter gates at its head.
local function SlotGates(data, windows, gates)
  local list = {}
  local width, height = data.width or 64, data.height or 64
  if windows then
    if windows.remaining then list[#list + 1] = {property = "RemainingDuration", window = windows.remaining, width = width, height = height} end
    if windows.elapsed then list[#list + 1] = {property = "ElapsedDuration", window = windows.elapsed, width = width, height = height} end
    if windows.stacks then list[#list + 1] = {stack = windows.stacks.kind, n = windows.stacks.n, width = width, height = height} end
  end
  local filters = #list
  for _, gate in ipairs(gates or {}) do
    if gate.stack then list[#list + 1] = {stack = gate.stack, n = gate.n, width = width, height = height, subs = gate.subs}
    else list[#list + 1] = {property = gate.property, window = {lower = gate.lower, upper = gate.upper}, width = width, height = height, subs = gate.subs} end
  end
  return list, filters
end

-- Builds the condition gates inside the Timer slot's creation window: each
-- a clip on its gate slot's measurement, holding its Glows.
local function BuildGlowGates(region, native, button, data, gates, first, used)
  local modern = Private.BlizzardAuraDisplay
  if not modern or not modern.StyleElementGlow then return end
  local width, height = data.width or 64, data.height or 64
  native.glowGates = {}
  for index = first, #gates do
    local gate = gates[index]
    local clip = BuildGateClip(button, button, BuildGatePart(button, gate, used))
    if clip then
      local built = {clip = clip, entries = {}}
      for _, sub in ipairs(gate.subs or {}) do
        local element = setmetatable({glow = true}, {__index = data.subRegions[sub]})
        local entry = {}
        modern.StyleElementGlow(entry, button, clip, button, element, width, height)
        built.entries[#built.entries + 1] = entry
      end
      native.glowGates[index] = built
    end
  end
end

-- The filter gates: nested clips in the Timer slot's button, one per native
-- filter (Remaining Time, Elapsed Time, Stack Count), each hung on its gate
-- slot's measurement and open only inside its window; the swipe and the
-- slot look are built inside the innermost (the display itself is hidden
-- meanwhile, Display.Update). Returns the innermost clip, or nil.
local function BuildFilterGate(native, button, frame, gates, count, used)
  local parent = button
  native.filterClips = {}
  for index = 1, count do
    local clip = BuildGateClip(parent, frame, BuildGatePart(button, gates[index], used))
    if clip then native.filterClips[#native.filterClips + 1] = clip; parent = clip end
  end
  if parent == button then native.filterClips = nil; return end
  native.filterClip = parent
  return parent
end

-- The slot look: the display, drawn again inside the timer slot's button.
-- In combat a target slot's button and everything inside it are forbidden
-- objects to the addon (not merely secret), so nothing read from the slot
-- can gate the display's own alpha: Show On "Aura(s) Found" is kept by
-- hiding the display itself (SetShowGate) and letting Blizzard show and
-- hide this copy with the aura. The copy is built inside the creation
-- window from the display's present look (Aura Active conditions): icon,
-- Border, Texture and Glow elements, and texts not drawn by a text slot
-- (countdowns are). Like the other slot contents its look is fixed at
-- creation; a changed look rebuilds the slot (LookKey in the gate key).
local lookTypes = {subtext = true, subborder = true, subtexture = true, subglow = true}
local function ElementShown(data, index, sub, looks)
  local config = data.subRegions and data.subRegions[index]
  if not config then return false end
  local shown
  if config.type == "subglow" then shown = config.glow == true
  elseif config.type == "subtext" then shown = config.text_visible ~= false
  elseif config.type == "subborder" then shown = config.border_visible ~= false
  elseif config.type == "subtexture" then shown = config.texture_visible ~= false end
  local values = looks and looks.elements and looks.elements[index]
  if values and values.present ~= nil then shown = values.present end
  return shown
end
local function BuildSlotLook(region, native, button, parent, data, looks, gates, liveIcon)
  local modern = Private.BlizzardAuraDisplay
  if not modern or not modern.CopyElementPoints then return end
  local present = looks and looks.present or {}
  local copies = {}
  -- Copies are made in `parent` (the filter clip, when there is one, so it
  -- clips them) but anchored to the button, which has the display's box.
  local function map(value)
    if value == region then return button end
    return copies[value]
  end
  local base = button:GetFrameLevel()
  local regionLevel = region:GetFrameLevel()
  local function Level(source)
    local ok, level = pcall(source.GetFrameLevel, source)
    local offset = ok and type(level) == "number" and (level - regionLevel) or 1
    return base + math.max(1, offset)
  end
  -- The icon's anchor areas, so elements anchored to them land right.
  for _, area in ipairs({"inner", "outer"}) do
    local source = region[area]
    if source then
      local copy = CreateFrame("Frame", nil, parent)
      copy:EnableMouse(false)
      copies[source] = copy
      modern.CopyElementPoints(source, copy, map, button)
    end
  end
  if region.icon then
    -- At the button's own level, under the swipe (made after it, at that
    -- level) and the elements, as the display's icon is under its cooldown.
    local iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:EnableMouse(false)
    iconFrame:SetFrameLevel(base)
    iconFrame:SetAllPoints(button)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    copies[region.icon] = icon
    modern.CopyElementPoints(region.icon, icon, map, button)
    modern.CopyTextureLook(region.icon, icon)
    if region.icon.GetSnapToPixelGrid then
      pcall(icon.SetSnapToPixelGrid, icon, region.icon:GetSnapToPixelGrid())
      pcall(icon.SetTexelSnappingBias, icon, region.icon:GetTexelSnappingBias())
    end
    -- The present look's own icon, or, for a trigger standing for several
    -- auras, the aura's icon bound by Blizzard; otherwise the display's.
    local manual = present.displayIcon
    if manual == nil and present.iconSource == 0 then manual = data.displayIcon end
    if manual ~= nil and manual ~= "" then icon:SetTexture(manual)
    elseif liveIcon and button.SetIcon then pcall(button.SetIcon, button, icon) end
    local colour = present.color or data.color
    if type(colour) == "table" then icon:SetVertexColor(colour[1] or 1, colour[2] or 1, colour[3] or 1, colour[4] or 1) end
    local desaturate = present.desaturate
    if desaturate == nil then desaturate = data.desaturate == true end
    icon:SetDesaturated(desaturate)
  end
  -- Glow elements already drawn by a Remaining Time gate glow through it.
  local gated = {}
  for _, gate in ipairs(gates or {}) do for _, index in ipairs(gate.subs) do gated[index] = true end end
  local width, height = data.width or 64, data.height or 64
  for index, sub in ipairs(region.subRegions or {}) do
    if lookTypes[sub.type] and not gated[index] and ElementShown(data, index, sub, looks) and not (sub.type == "subtext" and Private.ParseCDMText(data.subRegions[index].text_text)) then
      local copy = CreateFrame("Frame", nil, parent, sub.type == "subborder" and "BackdropTemplateWeakAuras" or nil)
      copy:EnableMouse(false)
      copy:SetFrameLevel(Level(sub))
      copies[sub] = copy
      modern.CopyElementPoints(sub, copy, map, button)
      local okS, w, h = pcall(sub.GetSize, sub)
      if okS and type(w) == "number" and type(h) == "number" and not issecretvalue(w) and not issecretvalue(h) then copy:SetSize(w, h) end
      if sub.type == "subtext" and sub.text then
        local text = copy:CreateFontString(nil, "OVERLAY")
        modern.CopyElementPoints(sub.text, text, map, copy)
        modern.CopyFontLook(sub.text, text)
      elseif sub.type == "subborder" and sub.GetBackdrop and copy.SetBackdrop then
        local okB, backdrop = pcall(sub.GetBackdrop, sub)
        if okB and backdrop then copy:SetBackdrop(backdrop) end
        local okC, r, g, b, a = pcall(sub.GetBackdropBorderColor, sub)
        if okC and r then copy:SetBackdropBorderColor(r, g, b, a) end
        if modern.MatchBorderScale then modern.MatchBorderScale(sub, copy) end
      elseif sub.type == "subtexture" and type(sub.texture) == "table" and sub.texture.texture then
        local texture = copy:CreateTexture(nil, "ARTWORK")
        modern.CopyElementPoints(sub.texture.texture, texture, map, copy)
        modern.CopyTextureLook(sub.texture.texture, texture)
      elseif sub.type == "subglow" and modern.StyleElementGlow then
        local element = setmetatable({glow = true}, {__index = data.subRegions[index]})
        local okG, gw, gh = pcall(sub.GetSize, sub)
        if not (okG and type(gw) == "number" and gw >= 1 and type(gh) == "number" and gh >= 1) then gw, gh = width, height end
        modern.StyleElementGlow({}, button, copy, copy, element, gw, gh)
      end
    end
  end
  native.look = copies
end

-- A key naming the present look, so a changed condition rebuilds the copy
-- (its texture can only be styled when it is created).
local function LookKey(data, look)
  local colour = look.color or data.color or {1, 1, 1, 1}
  local desaturate = look.desaturate
  if desaturate == nil then desaturate = data.desaturate == true end
  local icon = look.displayIcon
  if icon == nil and look.iconSource == 0 then icon = data.displayIcon end
  return table.concat({tostring(colour[1]), tostring(colour[2]), tostring(colour[3]), tostring(colour[4]), tostring(desaturate),
    tostring(icon), tostring(look.alpha), tostring(data.zoom), tostring(data.keepAspectRatio)}, "|")
end

-- The settings of the elements the slot look copies, so a change rebuilds it.
local ELEMENT_KEYS = {"text_text", "text_color", "text_fontSize", "text_font", "text_visible", "text_anchorPoint", "text_selfPoint",
  "text_anchorXOffset", "text_anchorYOffset", "border_visible", "border_color", "border_edge", "border_size", "border_offset",
  "border_anchor_area", "texture_visible", "texture", "textureColor", "texture_anchor_area", "glow", "glowType", "glowColor", "useGlowColor",
  "glowLines", "glowFrequency", "glowLength", "glowThickness", "glowScale", "glowBorder", "glowXOffset", "glowYOffset", "glow_anchor_area"}
function Private.CDMElementLookKey(data, looks)
  local parts = {}
  for index, element in ipairs(data.subRegions or {}) do
    if lookTypes[element.type] then
      parts[#parts + 1] = tostring(index) .. element.type
      for _, key in ipairs(ELEMENT_KEYS) do
        local value = element[key]
        if type(value) == "table" then
          for i = 1, 4 do parts[#parts + 1] = tostring(value[i]) end
        elseif value ~= nil then parts[#parts + 1] = key .. "=" .. tostring(value) end
      end
      local values = looks and looks.elements and looks.elements[index]
      if values then parts[#parts + 1] = "p=" .. tostring(values.present) end
    end
  end
  return table.concat(parts, "|")
end

function Display.Modify(region, data)
  DisableNative(region.cdmAuraTimer)
  DisableNative(region.cdmAuraSaturate)
  if region.nativeShowGate and Private.SetRegionNativeShow then Private.SetRegionNativeShow(region, nil) end
  ApplyElementGates(region, nil, false)
  region.cdmProgressData = data
  region.cdmNativeProgress = nil
  region.cdmInactiveDesaturate = region.regionType == "icon" and InactiveDesaturateTrigger(data) or nil
  region.cdmAuraLooks = region.regionType == "icon" and AuraActiveLooks(data) or nil
  if region.cdmAuraLooks then region.cdmInactiveDesaturate = region.cdmAuraLooks.index end
  region.cdmGlowGates = RemainingGlowGates(data)
  region.cdmRemainingWindow = RemainingFilterWindow(data)
  Display.ForceDesaturation(region, false)
end

-- The base icon stays desaturated while the native saturated copy is in use;
-- the icon region's SetDesaturated (conditions) defers to this.
function Display.ForceDesaturation(region, forced)
  if (region.cdmForcedDesaturation == true) == forced then return end
  region.cdmForcedDesaturation = forced or nil
  local last = region.cdmLastDesaturation
  if last == nil and region.cdmProgressData then last = region.cdmProgressData.desaturate end
  if region.SetDesaturated then region:SetDesaturated(last) end
end

-- Copies the icon's texture onto the saturated copy when the client lets the
-- addon touch it (at creation, and later when it is not locked).
local function CopyIconTexture(region, native, initializing)
  local copy = native.saturated
  if not copy or not CanStyleWidget(copy, initializing) then return end
  local icon = region.icon
  local texture = icon:GetTexture()
  -- A copy bound to the aura's own icon (SetIcon) keeps it; the display's
  -- fixed texture would otherwise overwrite it (Merfin).
  if not native.iconBound and texture ~= nil and not (issecretvalue and issecretvalue(texture)) then copy:SetTexture(texture) end
  local ulx, uly, llx, lly, urx, ury, lrx, lry = icon:GetTexCoord()
  if type(ulx) == "number" and not (issecretvalue and issecretvalue(ulx)) then copy:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry) end
  copy:SetDesaturated(false)
  copy:SetAlpha(1)
  copy:Show()
end

-- Called with every progress update: while the condition's answer is secret
-- the icon is desaturated and Blizzard shows a saturated copy of it in an
-- aura slot for as long as the player's debuff is on the target.
function Display.UpdateSaturation(region)
  local index = region.cdmInactiveDesaturate or region.cdmLiveIcon
  -- A hidden trigger keeps no state on the display; its last output does.
  local state = index and region.states and region.states[index]
  if (not state or state.show == nil) and index and Private.CDMLastOutput and WeakAuras.GetTriggerStateForTrigger then
    state = Private.CDMLastOutput(WeakAuras.GetTriggerStateForTrigger(region.id, index))
  end
  local unit, filter, ids
  -- Unknown presence, or a readable active aura for the live icon copy.
  if state and (state.auraActive == nil or (region.cdmLiveIcon and state.auraActive == true)) then
    if state.show then unit, filter, ids = NativeSource(state, true) end
    -- In combat the viewer's unit is secret too, so the render source above
    -- is empty (TargetDebuffFallback).
    if not unit then unit, filter, ids = TargetDebuffFallback(region, index, region.cdmLiveIcon ~= nil) end
  end
  if not unit then
    DisableNative(region.cdmAuraSaturate)
    Display.ForceDesaturation(region, false)
    return
  end
  local data = region.cdmProgressData
  local looks = region.cdmAuraLooks
  local present = looks and looks.present or nil
  local key = present and LookKey(data, present) or "saturated"
  if region.cdmAuraSaturate and region.cdmAuraSaturate.lookKey ~= key then
    -- The copy's look is fixed at creation: a changed look needs a new slot.
    DisableNative(region.cdmAuraSaturate)
    region.cdmAuraSaturate.container:Hide()
    region.cdmAuraSaturate = nil
  end
  if not region.cdmAuraSaturate then
    region.cdmAuraSaturate = CreateNative(region, function(native, button)
      native.saturated = button:CreateTexture(nil, "ARTWORK")
      -- The button has the icon's box and follows a Modern Aura Group's stand-in.
      native.saturated:SetAllPoints(button)
      CopyIconTexture(region, native, true)
      if present then
        -- The present look, inside the creation window. A manual icon of the
        -- present look replaces the aura's; otherwise Blizzard binds the
        -- aura's own icon, so a list of auras shows the one that is up.
        local icon = present.displayIcon
        if icon == nil and present.iconSource == 0 then icon = data.displayIcon end
        if icon ~= nil and icon ~= "" then native.saturated:SetTexture(icon)
        elseif button.SetIcon then native.iconBound = pcall(button.SetIcon, button, native.saturated) end
        local colour = present.color or data.color
        if type(colour) == "table" then native.saturated:SetVertexColor(colour[1] or 1, colour[2] or 1, colour[3] or 1, colour[4] or 1) end
        local desaturate = present.desaturate
        if desaturate == nil then desaturate = data.desaturate == true end
        native.saturated:SetDesaturated(desaturate)
        -- The copy's alpha is its own, not the missing look's (ApplyNativeAlpha).
        native.ownAlpha = tonumber(present.alpha) or tonumber(data.alpha) or 1
      elseif button.SetIcon then
        native.iconBound = pcall(button.SetIcon, button, native.saturated)
      end
    end)
    region.cdmAuraSaturate.lookKey = key
  end
  local native = region.cdmAuraSaturate
  if not (native.anchoredTo and native.anchoredTo ~= native.owner) then native.container:SetFrameLevel(region:GetFrameLevel()) end
  if not present then CopyIconTexture(region, native) end
  -- The base icon greys only for a desaturate condition; a live icon copy
  -- alone (cdmLiveIcon) leaves it as it is.
  Display.ForceDesaturation(region, not present and region.cdmInactiveDesaturate ~= nil)
  BindNative(native, unit, filter, ids)
end

-- Displays whose visibility the native slot decides (cdmNativeShow): their
-- alpha gate is evaluated again whenever auras may have changed, since the
-- secret answer is read when the gate is applied, not watched by the engine.
local gated = setmetatable({}, {__mode = "k"})
local rearm = CreateFrame("Frame")
rearm:RegisterUnitEvent("UNIT_AURA", "player", "target")
rearm:RegisterEvent("PLAYER_TARGET_CHANGED")
rearm:SetScript("OnEvent", function()
  for region in pairs(gated) do
    if region.nativeShowGate and region.RealSetAlpha then
      region:SetAlpha(region.requestedAlpha or region.animAlpha or region.alpha or 1)
    end
    if region.cdmElementGated and region.cdmAuraTimer then ApplyElementGates(region, region.cdmAuraTimer, true) end
    if not region.nativeShowGate and not region.cdmElementGated then gated[region] = nil end
  end
end)

local function OtherTriggersActive(region, index)
  local data = region.cdmProgressData
  if not WeakAuras.GetTriggerStateForTrigger then return false end
  for j = 1, #(data and data.triggers or {}) do
    if j ~= index then
      for _, state in pairs(WeakAuras.GetTriggerStateForTrigger(region.id, j) or {}) do
        if state.show then return true end
      end
    end
  end
  return false
end

-- Sub elements whose visibility an Aura Active condition changes: while the
-- aura is secret, each follows the slot's visibility through its alpha
-- (SetAlphaFromBoolean takes the secret boolean): the present value while
-- the aura is up, the missing value while it is not. The element is shown by
-- Lua whenever either value shows it; the alpha does the rest. Readable
-- auras return the elements to the condition engine (alpha 1).
ApplyElementGates = function(region, native, active)
  local looks = region.cdmAuraLooks
  local elements = looks and looks.elements
  if region.cdmElementGated and (not active or not elements) then
    for sub in pairs(region.cdmElementGated) do if sub.SetAlpha then sub:SetAlpha(1) end end
    region.cdmElementGated = nil
  end
  if not active or not elements then return end
  local data = region.cdmProgressData
  local gatedSubs = region.cdmElementGated or {}
  region.cdmElementGated = gatedSubs
  for index, values in pairs(elements) do
    local sub = region.subRegions and region.subRegions[index]
    local config = data and data.subRegions and data.subRegions[index]
    if sub and config and sub.SetAlphaFromBoolean then
      local default
      if config.type == "subglow" then default = config.glow == true
      elseif config.type == "subtext" then default = config.text_visible ~= false
      elseif config.type == "subborder" then default = config.border_visible ~= false
      elseif config.type == "subtexture" then default = config.texture_visible ~= false end
      local present = values.present
      if present == nil then present = default end
      local missing = values.missing
      if missing == nil then missing = default end
      if (present or missing) and sub.SetVisible then sub:SetVisible(true) end
      local button = native and native.button
      local ok, shown = pcall(function() return button and button:IsShown() end)
      if ok and shown ~= nil then
        pcall(sub.SetAlphaFromBoolean, sub, shown, present and 1 or 0, missing and 1 or 0)
        gatedSubs[sub] = true
        -- The stand-in's copy of the element, in a Modern Aura Group.
        local stand = StandOf(region)
        local copy = stand and stand.copies and stand.copies[sub]
        if copy and copy.SetAlphaFromBoolean then
          pcall(copy.SetAlphaFromBoolean, copy, shown, present and 1 or 0, missing and 1 or 0)
          gatedSubs[copy] = true
        end
      end
    end
  end
end

local function SetShowGate(region, native, mode)
  if not mode or not native then
    if region.nativeShowGate then Private.SetRegionNativeShow(region, nil) end
    gated[region] = nil
    return
  end
  local gate = region.nativeShowGate
  if not gate or gate.native ~= native or gate.mode ~= mode then
    -- The slot's button is made by Blizzard once the container is enabled,
    -- after this runs: the gate looks it up each time it is read (nil until
    -- then, which leaves the display at its own alpha), and the button's
    -- creation applies the alpha again (CreateNative).
    gate = {native = native, mode = mode, read = function()
      local button = native.button
      if not button then return nil end
      return button:IsShown()
    end}
    -- Aura(s) Found: the display hides itself and the slot look (which
    -- Blizzard shows with the aura) stands for it; the slot cannot be read
    -- in combat for a target aura, so its shown state gates nothing.
    if mode == "active" then gate.hide = true end
    Private.SetRegionNativeShow(region, gate)
  end
  gated[region] = true
end

function Display.Update(region)
  local source = SourceState(region)
  -- A trigger standing for several auras: while the aura is secret the icon
  -- cannot follow it in Lua, so a native copy bound to the aura's own icon
  -- is shown over the fixed one (UpdateSaturation without a condition).
  region.cdmLiveIcon = nil
  if region.regionType == "icon" and source and source.cdmBuff and source.auraActive ~= false
      and (region.iconSource == -1 or region.iconSource == source.triggernum)
      and type(source.cdmAuraSpellIDs) == "table" and #source.cdmAuraSpellIDs > 1 then
    region.cdmLiveIcon = source.triggernum
  end
  region.cdmNativeProgress = nil
  local unit, filter, ids = NativeSource(source)
  local data = region.cdmProgressData
  -- No render source (in combat, or the display drawn by another trigger
  -- while the buff trigger cannot see its aura): the slot follows the aura
  -- by spell ID natively (TargetDebuffFallback).
  local fallbackState
  if not unit and data then
    -- An aura known to be up (Blizzard's viewer item says so) whose times
    -- and stacks are secret still needs the slot: its filters and gates are
    -- drawn natively (cdmNativeRemaining).
    local allowActive = source ~= nil and source.auraActive == true and (source.cdmNativeRemaining == true or (source.durationObject == nil and source.duration == nil))
    unit, filter, ids, fallbackState = TargetDebuffFallback(region, TargetDebuffTrigger(data), allowActive)
  end
  -- Show On: Aura(s) Found / Missing with a secret aura: the slot decides
  -- the display's visibility (cdmNativeShow).
  -- Only while this trigger alone shows the display: with "Any of" and
  -- another trigger active, the display is shown for that trigger's sake.
  local showMode = source and source.cdmNativeShow or nil
  if showMode and (data.triggers.disjunctive or "all") ~= "all" and OtherTriggersActive(region, source.triggernum) then showMode = nil end
  local wantsSwipe = region.regionType == "icon" and data and data.cooldown
  if not data or not unit or not (wantsSwipe or showMode or region.cdmGlowGates or region.cdmRemainingWindow) then
    DisableNative(region.cdmAuraTimer)
    SetShowGate(region, nil, nil)
    -- The icon copy may still be wanted on its own (a live icon, or the
    -- desaturate condition) without a timer slot.
    if region.cdmInactiveDesaturate or region.cdmLiveIcon then Display.UpdateSaturation(region)
    elseif region.cdmAuraSaturate then DisableNative(region.cdmAuraSaturate) end
    SyncNativeAlphas(region)
    ApplyElementGates(region, nil, false)
    return
  end
  -- The remaining-time glow gates are fixed at the slot's creation: changed
  -- conditions need a new slot.
  -- The filters' windows apply natively only while their values are secret:
  -- the display then hides itself and its slot look, inside the filter
  -- clips, stands for it (nothing outside the slot can follow a clip whose
  -- edges are secret), exactly as Show On "Aura(s) Found" draws it.
  local filterState = source and source.cdmNativeRemaining and source or fallbackState
  region.cdmFilterWanted = filterState and filterState.cdmNativeRemaining == true or nil
  if region.cdmFilterWanted and region.cdmRemainingWindow then showMode = "active" end
  -- Show On "Aura(s) Found": the slot carries a copy of the display's
  -- present look (BuildSlotLook) and the display itself is hidden.
  local lookKey
  if showMode == "active" then
    local looks = region.cdmAuraLooks
    -- A fixed icon copy follows the display's icon through the key.
    local okI, texture = pcall(function() return region.icon and region.icon:GetTexture() end)
    lookKey = LookKey(data, looks and looks.present or {}) .. "|" .. Private.CDMElementLookKey(data, looks)
      .. "|" .. tostring(region.cdmLiveIcon ~= nil) .. "|" .. (region.cdmLiveIcon == nil and okI and not issecretvalue(texture) and tostring(texture) or "live")
  end
  -- The icon copy of the desaturate condition / live icon (UpdateSaturation)
  -- draws in a slot of its own, outside the filter clips: while the slot look
  -- stands for the display it is not drawn (the look carries the present
  -- look and the live icon itself).
  if lookKey then
    DisableNative(region.cdmAuraSaturate)
    Display.ForceDesaturation(region, false)
  elseif region.cdmInactiveDesaturate or region.cdmLiveIcon then Display.UpdateSaturation(region)
  elseif region.cdmAuraSaturate then DisableNative(region.cdmAuraSaturate) end
  local gateKey = GlowGateKey(data, region.cdmGlowGates, region.cdmRemainingWindow, lookKey)
  if region.cdmAuraTimer and region.cdmAuraTimer.gateKey ~= gateKey then
    DisableNative(region.cdmAuraTimer)
    region.cdmAuraTimer.container:Hide()
    region.cdmAuraTimer = nil
    if region.nativeShowGate then Private.SetRegionNativeShow(region, nil) end
  end
  if not region.cdmAuraTimer then
    local gates, withLook, liveIcon = region.cdmGlowGates, lookKey ~= nil, region.cdmLiveIcon ~= nil
    local slotGates, filterCount = SlotGates(data, region.cdmRemainingWindow, gates)
    region.cdmAuraTimer = CreateNative(region, function(native, button)
      -- The filters' gates first (they take the button's bindings first);
      -- the swipe lives inside the innermost clip.
      local used = {}
      local parent = BuildFilterGate(native, button, button, slotGates, filterCount, used) or button
      -- The Glow conditions' gates (BuildGlowGates).
      BuildGlowGates(region, native, button, data, slotGates, filterCount + 1, used)
      -- The display's present look, drawn by the slot (BuildSlotLook).
      if withLook then
        BuildSlotLook(region, native, button, parent, data, region.cdmAuraLooks, gates, liveIcon)
        -- The copy's alpha is the present look's own (ApplyNativeAlpha).
        local present = region.cdmAuraLooks and region.cdmAuraLooks.present
        native.ownAlpha = tonumber(present and present.alpha) or tonumber(data.alpha) or 1
      end
      -- The swipe is drawn by icons only; the slot still gates visibility
      -- for the other display types.
      if region.regionType == "icon" and region.icon then
        native.cooldown = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
        -- The button has the icon's box (the slot fills its owner), and it
        -- follows a Modern Aura Group's stand-in where the icon does not.
        native.cooldown:SetAllPoints(button)
        native.cooldown:SetDrawBling(false)
        native.cooldown:SetFrameLevel(button:GetFrameLevel())
        -- The initializer is the supported configuration window. Complete all
        -- appearance setup before the provider restricts the button's subtree.
        Display.Style(region, native)
        button:SetDurationCooldown(native.cooldown)
      end
    end)
  end
  region.cdmAuraTimer.gateKey = gateKey
  if wantsSwipe then
    -- The normal icon remains the owner of appearance and conditions. Only the
    -- missing timer is delegated; a static full/paused swipe must not cover it.
    region.cdmNativeProgress = true
    region.cooldown:Hide()
    Display.Style(region)
  end
  BindNative(region.cdmAuraTimer, unit, filter, ids)
  SetShowGate(region, region.cdmAuraTimer, showMode)
  SyncNativeAlphas(region)
  -- Aura Active conditions on sub elements, while the aura is secret.
  local lookState = source and source.cdmBuff and source or fallbackState
  ApplyElementGates(region, region.cdmAuraTimer, lookState ~= nil and lookState.auraActive == nil)
  if region.cdmElementGated then gated[region] = true end
end

function Display.SyncFrameLevels(region)
  local native = region.cdmAuraTimer
  if not native then return end
  -- Over a Modern Aura Group's stand-in the level follows the stand (PlaceNative).
  if native.anchoredTo and native.anchoredTo ~= native.owner then return end
  local level = region.cooldown and region.cooldown:GetFrameLevel() or region:GetFrameLevel()
  native.container:SetFrameLevel(level)
end

function Display.Style(region, initializing)
  local native = initializing or region.cdmAuraTimer
  if not native or not native.cooldown then return end
  -- Only the container remains addon-accessible while aura widgets are locked.
  -- Keep current styling until a later update can legally apply a change.
  Display.SyncFrameLevels(region)
  if not CanStyleWidget(native.cooldown, initializing) then return end
  -- Keep the existing swipe/edge/inverse and countdown-number display options.
  local cooldown = native.cooldown
  cooldown:SetDrawSwipe(region.cooldownSwipe ~= false)
  cooldown:SetDrawEdge(region.cooldownEdge == true)
  -- The same direction as the display's own swipe draws out of combat: the
  -- Icon display turns "Inverse" into the cooldown's reverse flag together
  -- with the trigger's own inversion (Icon.lua UpdateEffectiveInverse, kept
  -- on the cooldown as faReverse); an aura's plain look is reverse = true,
  -- the swipe covering the time left. Blizzard's bound cooldown takes the
  -- flag the same way, so the native swipe looked inverted before.
  local own = region.cooldown
  local reverse = own and own.faReverse
  if reverse == nil then reverse = region.inverseDirection ~= true end
  cooldown:SetReverse(reverse)
  cooldown:SetHideCountdownNumbers(region.cdmConfiguredHideNumbers == true)
end

-- Where a text's native countdown anchors: the text, or, while a Modern
-- Aura Group's stand-in draws the display, the stand-in's copy of the text.
function Display.NativeTextAnchor(sub)
  local text = sub.text
  local link = text and text.faStand
  local copy = link and link.stand and link.stand.active and link.stand.copies[text]
  return copy or text
end

function Display.StyleText(sub, initializing)
  local native, config = initializing or sub.cdmAuraTimer, sub.cdmTextConfig
  if not native or not config then return end
  -- Fonts and anchors inherit the same restriction as the cooldown. Defer
  -- edits instead of touching a forbidden font; FrameTick retries when legal.
  native.stylePending = true
  if not CanStyleWidget(native.text, initializing) then return end
  -- Copy only ordinary subtext appearance, never the bound font's text, alpha
  -- or dimensions. The owner supplies condition visibility/alpha naturally.
  local font, size, flags = sub.text:GetFont()
  if not font then return end
  Private.ApplyTextFont(native.text, nil, font, size, flags,
    config.text_shadowColor, config.text_shadowXOffset, config.text_shadowYOffset)
  native.text:SetTextColor(sub.color_anim_r or sub.color_r or 1,
    sub.color_anim_g or sub.color_g or 1, sub.color_anim_b or sub.color_b or 1,
    sub.color_anim_a or sub.color_a or 1)
  native.text:SetJustifyH(config.text_justify or "CENTER")
  native.text:SetWidth(config.text_automaticWidth == "Fixed" and config.text_fixedWidth or 0)
  local wrap = config.text_automaticWidth ~= "Fixed" or config.text_wordWrap == "WordWrap"
  native.text:SetWordWrap(wrap)
  native.text:SetNonSpaceWrap(wrap)
  if sub.AnchorNativeText then sub:AnchorNativeText(native.text) end
  native.stylePending = nil
end

function Display.ModifyText(parent, sub, parentData, config)
  sub.cdmTextConfig = config
  Display.StyleText(sub)
end

function Display.HideText(sub)
  DisableNative(sub.cdmAuraTimer)
  sub.cdmNativeText = nil
end

function Display.UpdateText(parent, sub, config, kind, explicitTrigger)
  if not kind then Display.HideText(sub); return false end
  local state = SourceState(parent, explicitTrigger)
  local unit, filter, ids
  if state and state.cdmBuff then unit, filter, ids = NativeSource(state) end
  -- The countdown of a target debuff the trigger cannot see (in combat) is
  -- bound natively even while another trigger draws the display.
  -- Countdowns (%p) and stack counts (%s) are bound natively: the slot's
  -- duration text or application count, which Blizzard keeps right while
  -- the values are secret.
  local nativeKind = kind == "p" or kind == "bp" or kind == "s" or kind == "bs"
  if not unit and nativeKind then
    local fallbackState
    unit, filter, ids, fallbackState = TargetDebuffFallback(parent, explicitTrigger or TargetDebuffTrigger(parent.cdmProgressData))
    if unit then state = fallbackState end
  end
  -- The options window's sample is formatted by the text element itself.
  if not state or not state.cdmBuff or state.cdmTextPreview then Display.HideText(sub); return false end
  if not sub.text:GetFont() then return true end
  if unit and nativeKind then
    sub.cdmTextConfig = config
    local stackText = kind == "s" or kind == "bs"
    -- A changed Remaining Time window (or kind) needs a new text slot (the
    -- curve and the binding are fixed at creation), and so does a changed
    -- text format: the countdown's formatter is bound at creation too, so a
    -- Time > Number change (or a new precision) kept the old one (issue #138).
    local token = type(config.text_text) == "string" and (config.text_text:match("^%%{(.-)}$") or config.text_text:match("^%%(.+)$"))
    local settings = Private.CDMTextFormat and Private.CDMTextFormat(config, token)
    local formatKey = settings and table.concat({tostring(settings.format), tostring(settings.threshold), tostring(settings.precision),
      tostring(settings.secondsOnly), tostring(settings.style), tostring(type(settings.tint) == "table" and settings.tint.key or settings.tint)}, ":") or "default"
    local windowKey = WindowKey(parent.cdmRemainingWindow) .. (stackText and "|stacks" or "|time") .. "|" .. formatKey
    if sub.cdmAuraTimer and sub.cdmAuraTimer.windowKey ~= windowKey then
      DisableNative(sub.cdmAuraTimer)
      sub.cdmAuraTimer.container:Hide()
      sub.cdmAuraTimer = nil
    end
    if not sub.cdmAuraTimer then
      -- A Stack Count filter: the text lives inside a clip hung on the slot's
      -- application bar (or count text) and open only in the window. The
      -- clip takes the display's box with the gate margin around it (the text
      -- element's frame has no size of its own, and a clip hung on the bound
      -- text would take a secret size and draw nothing), so a text within
      -- the margin of the display is covered. The time filters are colour
      -- curves on the countdown's own binding below (one curve: Remaining
      -- Time first, else Elapsed Time).
      local windows = parent.cdmRemainingWindow
      local stackGate
      if windows and windows.stacks then
        local pw, ph = parent.cdmProgressData and parent.cdmProgressData.width or 64, parent.cdmProgressData and parent.cdmProgressData.height or 64
        stackGate = {stack = windows.stacks.kind, n = windows.stacks.n, width = pw, height = ph}
      end
      sub.cdmAuraTimer = CreateNative(sub, function(native, button)
        local holder = button
        if stackGate then
          local stand = StandOf(parent)
          local box = stand and stand.proxy or parent
          -- A stack text takes the slot's application count itself, so an
          -- "exactly n" gate (which needs it too) is not drawn on it.
          local clip = BuildGateClip(holder, box, BuildGatePart(button, stackGate, {count = stackText or nil}))
          if clip then holder = clip end
        end
        native.text = holder:CreateFontString(nil, "OVERLAY")
        -- A binding may render immediately, so install a font first.
        native.text:SetFont(sub.text:GetFont())
        Display.StyleText(sub, native)
        -- %s: the aura's applications, as Blizzard shows them.
        if stackText then
          pcall(button.SetApplicationCount, button, native.text)
          return
        end
        -- Use Blizzard's native formatter: expired timers are blank and the
        -- last positive fraction rounds up, so it cannot display a zero. The
        -- element's Time Format settings (precision below a threshold, the
        -- Blizzard formats) shape it, as for a %p the element formats itself.
        local formatter
        if settings then
          local ok, result = pcall(Private.GetDurationTextFormatter, settings.format, settings.threshold, settings.precision, settings.secondsOnly, settings.style, settings.tint)
          if ok then formatter = result end
        end
        local options = {textFormatter = formatter or Private.GetDurationTextFormatter(99, 0, 0)}
        -- Inside the trigger's Remaining Time window only: a colour curve on
        -- the aura's remaining time makes the text transparent outside it.
        local windows = parent.cdmRemainingWindow
        local window = windows and (windows.remaining or windows.elapsed)
        if window then
          local property = windows.remaining and "RemainingDuration" or "ElapsedDuration"
          local enum = Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty[property]
          local curve = WindowCurve(window, sub.color_r or 1, sub.color_g or 1, sub.color_b or 1, sub.color_a or 1)
          if curve and enum ~= nil then options.textColor = {curve = curve, property = enum} end
        end
        if not pcall(button.SetDurationText, button, native.text, options) then
          options.textColor = nil
          button:SetDurationText(native.text, options)
        end
      end, parent)
      sub.cdmAuraTimer.windowKey = windowKey
    end
    local native = sub.cdmAuraTimer
    native.region = parent
    -- The stand-in came or went: the countdown moves (when access allows).
    if native.text and native.text.faAnchorTarget ~= Display.NativeTextAnchor(sub) then native.stylePending = true end
    if native.stylePending then Display.StyleText(sub) end
    -- Texts sit a level above the icon's slot over a stand-in too.
    native.levelOffset = 1
    if not (native.anchoredTo and native.anchoredTo ~= native.owner) then native.container:SetFrameLevel(sub:GetFrameLevel()) end
    sub.cdmNativeText = true
    sub.text:SetText("")
    BindNative(native, unit, filter, ids)
    return true
  end
  Display.HideText(sub)
  local token = type(config.text_text) == "string" and (config.text_text:match("^%%{(.-)}$") or config.text_text:match("^%%(.+)$"))
  Private.CopyCDMCountdownText(sub.text, state, kind, Private.CDMTextFormat and Private.CDMTextFormat(config, token))
  if sub.UpdateAnchorOnTextChange then sub:UpdateAnchorOnTextChange() end
  return true
end

function Display.ModifyIndicator(parent, sub, parentData, config)
  Display.ReleaseIndicator(sub)
end
function Display.ReleaseIndicator(sub, forget)
  if sub.preview then sub.preview:Hide() end
  if sub.dispelBorder then sub.dispelBorder:Hide() end
  if sub.dispelEdges then Private.DispelTypeDisplay.Hide(sub.dispelEdges) end
end
function Display.UpdateIndicator(parent, sub, config)
  local state = SourceState(parent)
  local dispel
  if sub.visible and state and state.show and state.cdmBuff then
    -- OPTIONS always supplies a sample type, even when its sample aura is active.
    dispel = state.cdmTextPreview and "Magic" or state.cdmDispelName
  end
  if (issecretvalue and issecretvalue(dispel)) or type(dispel) ~= "string" or dispel == "" then
    Display.ReleaseIndicator(sub); return
  end
  Display.ReleaseIndicator(sub)
  if sub.dispelEdges then
    -- Public CDM type data uses the same Blizzard colours as native aura bindings.
    for _, edge in ipairs(sub.dispelEdges) do
      AuraUtil.SetAuraBorderColor(edge, dispel)
      edge:Show()
    end
  elseif sub.preview then
    AuraUtil.SetAuraDispelTypeIcon(sub.preview, dispel)
    sub.preview:SetVertexColor(1, 1, 1, 1)
    sub.preview:Show()
  end
end
