-- Modified for ForeverAuras, 2026-10-08.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("Conditions")
local L = WeakAuras.L
local timer = WeakAuras.timer

-- Dynamic Condition functions to run. keyed on event and uid
local dynamicConditions = {};

-- Global Dynamic Condition Funcs, keyed on the event
local globalDynamicConditionFuncs = {};

-- Check Conditions Functions, keyed on uid
local checkConditions = {};

local conditionChecksTimers = {};
conditionChecksTimers.recheckTime = {};
conditionChecksTimers.recheckHandle = {};

local function OnDelete(_, uid)
  checkConditions[uid] = nil
  conditionChecksTimers.recheckTime[uid] = nil
  if (conditionChecksTimers.recheckHandle[uid]) then
    for cloneId, v in pairs(conditionChecksTimers.recheckHandle[uid]) do
      timer:CancelTimer(v)
    end
  end
  conditionChecksTimers.recheckHandle[uid] = nil

  for _, funcs in pairs(dynamicConditions) do
    funcs[uid] = nil
  end
end

Private.callbacks:RegisterCallback("Delete", OnDelete)

local function formatValueForAssignment(vType, value, pathToCustomFunction, pathToFormatters, data)
  if (value == nil) then
    value = false;
  end
  if (vType == "bool") then
    return value and tostring(value) or "false";
  elseif(vType == "number") then
    return value and tostring(value) or "0";
  elseif (vType == "list" or vType == "textureLSM") then
    if type(value) == "string" then
      return string.format("%s", Private.QuotedString(value))
    elseif type(value) == "number" then
      return tostring(value)
    end
    return "nil"
  elseif vType == "progressSource" then
    if type(value) == "table" then
      local progressSource = Private.AddProgressSourceMetaData(data, value)
      if not progressSource then
        return "{}"
      end
      local trigger = progressSource[1] or -1
      local progressType = progressSource[2] or "auto"
      local property = progressSource[3]
      local totalProperty = progressSource[4]
      local modRateProperty = progressSource[5]
      local inverseProperty = progressSource[6]
      local pausedProperty = progressSource[7]
      local remainingProperty = progressSource[8]

      if trigger == 0 then
        -- Manual progress
        local serialized = string.format("{%s, %s, %s, %s}",
            trigger,
            Private.QuotedString(progressType),
            property or "0",     -- Actually: value
            totalProperty or "100" -- Actually: total
        )
        return serialized
      else
        local serialized = string.format("{%s, %s, %s, %s, %s, %s, %s, %s}",
            trigger,
            Private.QuotedString(progressType),
            Private.QuotedString(property or "nil"),
            totalProperty and Private.QuotedString(totalProperty) or "nil",
            modRateProperty and Private.QuotedString(modRateProperty) or "nil",
            inverseProperty and Private.QuotedString(inverseProperty) or "nil",
            pausedProperty and Private.QuotedString(pausedProperty) or "nil",
            remainingProperty and Private.QuotedString(remainingProperty) or "nil"
        )
        return serialized
      end
    else
      return "nil"
    end
  elseif (vType == "icon") then
    if type(value) == "string" then
      return string.format("%s", Private.QuotedString(value))
    elseif type(value) == "number" then
      return tostring(value)
    end
    return "nil"
  elseif (vType == "string" or vType == "texture") then
    if type(value) == "string" then
      return string.format("%s", Private.QuotedString(value))
    else
      return '""'
    end
  elseif(vType == "color") then
    if (value and type(value) == "table") then
      return string.format("{%s, %s, %s, %s}",
                           tostring(value[1]), tostring(value[2]),
                           tostring(value[3]), tostring(value[4]))
    end
    return "{1, 1, 1, 1}";
  elseif(vType == "chat") then
    if (value and type(value) == "table") then
      local serialized = string.format("{message_type = %s, message = %s, message_dest = %s, message_dest_isunit = %s, r = %s, g = %s, b = %s, message_custom = %s, message_formaters = %s, message_voice = %s}",
        Private.QuotedString(tostring(value.message_type)), Private.QuotedString(tostring(value.message or "")),
        Private.QuotedString(tostring(value.message_dest)),
        tostring(value.message_dest_isunit),
        type(value.message_color) == "table" and tostring(value.message_color[1] or "1") or "1",
        type(value.message_color) == "table" and tostring(value.message_color[2] or "1") or "1",
        type(value.message_color) == "table" and tostring(value.message_color[3] or "1") or "1",
        pathToCustomFunction,
        pathToFormatters,
        tostring(value.message_voice))
      return serialized
    end
  elseif(vType == "sound") then
    if (value and type(value) == "table") then
      return string.format("{ sound = %s, sound_channel = %s, sound_path = %s, sound_fojji = %s, sound_kit_id = %s, sound_type = %s, %s, %s}",
        Private.QuotedString(tostring(value.sound or "")),
        Private.QuotedString(tostring(value.sound_channel or "")),
        Private.QuotedString(tostring(value.sound_path or "")),
        Private.QuotedString(tostring(value.sound_fojji or "")),
        Private.QuotedString(tostring(value.sound_kit_id or "")),
        Private.QuotedString(tostring(value.sound_type or "")),
        value.sound_repeat and "sound_repeat = " .. tostring(value.sound_repeat) or "nil",
        value.sound_fade and "sound_fade = " .. tostring(value.sound_fade) or "nil");
    end
  elseif(vType == "customcode") then
    return string.format("%s", pathToCustomFunction);
  elseif vType == "glowexternal" then
    if (value and type(value) == "table") then
      return ([[{ glow_action = %q, glow_frame_type = %q, glow_type = %q,
      glow_frame = %q, use_glow_color = %s, glow_color = {%s, %s, %s, %s},
      glow_startAnim = %s, glow_duration = %f, glow_lines = %d, glow_frequency = %f, glow_length = %f, glow_thickness = %f, glow_XOffset = %f, glow_YOffset = %f,
      glow_scale = %f, glow_border = %s }]]):format(
        value.glow_action or "",
        value.glow_frame_type or "",
        value.glow_type or "",
        value.glow_frame or "",
        value.use_glow_color and "true" or "false",
        type(value.glow_color) == "table" and tostring(value.glow_color[1]) or "1",
        type(value.glow_color) == "table" and tostring(value.glow_color[2]) or "1",
        type(value.glow_color) == "table" and tostring(value.glow_color[3]) or "1",
        type(value.glow_color) == "table" and tostring(value.glow_color[4]) or "1",
        value.glow_startAnim and "true" or "false",
        value.glow_duration or 1,
        value.glow_lines or 8,
        value.glow_frequency or 0.25,
        value.glow_length or 10,
        value.glow_thickness or 1,
        value.glow_XOffset or 0,
        value.glow_YOffset or 0,
        value.glow_scale or 1,
        value.glow_border and "true" or "false"
      )
    end
  end
  return "nil";
end

local function formatValueForAssignmentWithConstants(vType, value, pathToCustomFunction, pathToFormatters, data, constants)
  if constants and (vType == "bool" or vType == "color") and type(value) == "table" and type(value.checks) == "table" then
    local serializedChecks = {}
    if vType == "bool" then
      for _, check in ipairs(value.checks) do
        if type(check) == "table" and check.trigger ~= nil and check.variable ~= nil then
          local valueValue = check.value
          serializedChecks[#serializedChecks + 1] = string.format("{ trigger = %s, variable = %q, value = %s, when = %s }",
            tostring(check.trigger),
            tostring(check.variable),
            valueValue ~= nil and tostring(valueValue) or "nil",
            check.when == false and "false" or "true")
        end
      end
    elseif vType == "color" then
      for _, check in ipairs(value.checks) do
        if type(check) == "table" and check.trigger ~= nil and check.variable ~= nil then
          local color = check.color
          serializedChecks[#serializedChecks + 1] = string.format("{ trigger = %s, variable = %q, color = {%s, %s, %s, %s}, when = %s }",
            tostring(check.trigger),
            tostring(check.variable),
            tostring(color and color[1] or 1),
            tostring(color and color[2] or 1),
            tostring(color and color[3] or 1),
            tostring(color and color[4] or 1),
            check.when == false and "false" or "true")
        end
      end
    end

    local literal = string.format("{ checks = { %s } }", table.concat(serializedChecks, ", "))
    local cacheKey = vType .. ":" .. literal
    if constants.cache[cacheKey] then
      return constants.cache[cacheKey]
    end
    constants.index = constants.index + 1
    local name = "_wa_cond_value_" .. constants.index
    constants.cache[cacheKey] = name
    constants.lines[#constants.lines + 1] = "local " .. name .. " = " .. literal .. "\n"
    return name
  end

  return formatValueForAssignment(vType, value, pathToCustomFunction, pathToFormatters, data)
end

local function formatValueForCall(type, property)
  if type == "bool" or type == "number" or type == "list" or type == "icon" or type == "string" or type == "texture" or type == "textureLSM"
    or type == "progressSource"
  then
    return "propertyChanges['" .. property .. "']";
  elseif (type == "color") then
    local pcp = "propertyChanges['" .. property .. "']";
    return pcp  .. "[1], " .. pcp .. "[2], " .. pcp  .. "[3], " .. pcp  .. "[4]";
  end
  return "nil";
end

function Private.ExecEnv.CancelConditionCheck(uid, cloneId)
  if conditionChecksTimers.recheckHandle[uid] and conditionChecksTimers.recheckHandle[uid][cloneId] then
    timer:CancelTimer(conditionChecksTimers.recheckHandle[uid][cloneId])
    conditionChecksTimers.recheckHandle[uid][cloneId] = nil
  end
end

function Private.ExecEnv.ScheduleConditionCheck(time, uid, cloneId)
  conditionChecksTimers.recheckTime[uid] = conditionChecksTimers.recheckTime[uid] or {}
  conditionChecksTimers.recheckHandle[uid] = conditionChecksTimers.recheckHandle[uid] or {};

  if (conditionChecksTimers.recheckTime[uid][cloneId] and conditionChecksTimers.recheckTime[uid][cloneId] > time) then
    timer:CancelTimer(conditionChecksTimers.recheckHandle[uid][cloneId]);
    conditionChecksTimers.recheckHandle[uid][cloneId] = nil;
  end

  if (conditionChecksTimers.recheckHandle[uid][cloneId] == nil) then
    conditionChecksTimers.recheckHandle[uid][cloneId] = timer:ScheduleTimerFixed(function()
      conditionChecksTimers.recheckHandle[uid][cloneId] = nil;
      local region = Private.GetRegionByUID(uid, cloneId)
      if (region and region.toShow) then
        Private.ActivateAuraEnvironmentForRegion(region)
        checkConditions[uid](region);
        Private.ActivateAuraEnvironment()
      end
    end, time - GetTime())
    conditionChecksTimers.recheckTime[uid][cloneId] = time;
  end
end

-- Restricted timers' Alpha and Color curves are rechecked together, ten times
-- a second, by one frame rather than a timer per display.
local curveTicks, curveFrame = {}, nil
function Private.ExecEnv.ScheduleCurveCheck(uid, cloneId)
  local clones = curveTicks[uid]
  if not clones then clones = {}; curveTicks[uid] = clones end
  clones[cloneId] = true
  if not curveFrame then
    curveFrame = CreateFrame("Frame")
    curveFrame.elapsed = 0
    curveFrame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = self.elapsed + elapsed
      if self.elapsed < 0.1 then return end
      self.elapsed = 0
      Private.StartProfileSystem("timer conditions")
      local due = curveTicks
      curveTicks = {}
      for dueUid, dueClones in pairs(due) do
        for dueClone in pairs(dueClones) do
          local region = Private.GetRegionByUID(dueUid, dueClone)
          if region and region.toShow and checkConditions[dueUid] then
            Private.ActivateAuraEnvironmentForRegion(region)
            xpcall(checkConditions[dueUid], geterrorhandler(), region)
            Private.ActivateAuraEnvironment()
          end
        end
      end
      Private.StopProfileSystem("timer conditions")
      if not next(curveTicks) then self:Hide() end
    end)
  end
  curveFrame:Show()
end

function Private.ExecEnv.CallCustomConditionTest(uid, testFunctionNumber, ...)
  local ok, result = xpcall(Private.ExecEnv.conditionHelpers[uid].customTestFunctions[testFunctionNumber],
                            Private.GetErrorHandlerUid(uid, L["Condition Custom Test"]), ...)
  if (ok) then
    return result
  end
end

-- Generated built-in code only receives Private.ExecEnv, not the addon namespace.
function Private.ExecEnv.SetSecretAuraConditionProperty(region, property, ...)
  Private.BlizzardAuraDisplay.SetConditionProperty(region, property, ...)
end

-- ForeverAuras: no active condition changes the property any more; the
-- native display drops its override and paints its own look (issue #143).
function Private.ExecEnv.ResetSecretAuraConditionProperty(region, property, ...)
  Private.BlizzardAuraDisplay.ResetConditionProperty(region, property, ...)
end

function Private.ExecEnv.SetSecretAuraConditionGate(region, index, on)
  Private.BlizzardAuraDisplay.SetConditionGate(region, index, on)
end

function Private.ExecEnv.GetConditionValue(state, variable)
  if not state then return nil end
  if state.progressType == "durationObject" and WeakAuras.IsDurationObject(state.durationObject) then
    -- A readable cooldown shown from its duration object keeps its timed
    -- values; conditions read those, as they did for the timed form.
    local timed = state[variable]
    if type(timed) == "number" and not issecretvalue(timed) then return timed end
    if variable == "expirationTime" then
      return state.durationObject:GetEndTime()
    elseif variable == "duration" then
      return state.durationObject:GetTotalDuration()
    elseif variable == "remaining" then
      return state.durationObject:GetRemainingDuration()
    end
  end
  return state[variable]
end

local PowerCurve = {}
Private.ExecEnv.PowerCurve = PowerCurve
local huge = math.huge
PowerCurve.ALL = {{-huge, huge}}
PowerCurve.NONE = {}
local knownMax = {}

PowerCurve.kinds = {
  power = {value = "power", percent = "percentpower", deficit = "deficit"},
  health = {value = "health", percent = "percenthealth", deficit = "deficit"},
}

local function Readable(...)
  return not hasanysecretvalues(...)
end

local function MaxKey(kind, s)
  return kind .. ":" .. s.unit .. ":" .. tostring(s.powertype)
end

function PowerCurve.IsSecret(s, kind)
  if s == nil or not s.show then return false end
  local names = PowerCurve.kinds[kind]
  return issecretvalue(s[names.value]) or issecretvalue(s[names.percent]) or false
end

function PowerCurve.Remember(s, kind)
  if s and Readable(s.unit, s.powertype, s.total) and type(s.unit) == "string" and type(s.total) == "number" and s.total > 0 then
    knownMax[MaxKey(kind, s)] = s.total
  end
end

function PowerCurve.Begin(s, kind)
  if not Readable(s.unit, s.powertype) or type(s.unit) ~= "string" then return end
  if kind == "power" and (s.powertype == nil or s.powertype == 99) then return end
  local max = s.total
  if not Readable(max) or type(max) ~= "number" or max <= 0 then
    max = knownMax[MaxKey(kind, s)]
  end
  if not max then
    local ok, value
    if kind == "power" then
      ok, value = pcall(UnitPowerMax, s.unit, s.powertype)
    else
      ok, value = pcall(UnitHealthMax, s.unit)
    end
    if ok and Readable(value) and type(value) == "number" and value > 0 then max = value end
  end
  return {kind = kind, unit = s.unit, powerType = s.powertype, max = max}
end

local flipped = {[">="] = "<=", [">"] = "<", ["<="] = ">=", ["<"] = ">", ["=="] = "==", ["~="] = "~="}

-- Remaining Time, in seconds, on a timer Lua cannot read.
local TIMER_TOP = 1e6
function PowerCurve.BeginTimer(s)
  if s == nil or not s.show or s.progressType ~= "durationObject" then return end
  local duration = Private.GetTextDuration and Private.GetTextDuration(s) or s.durationObject
  if not WeakAuras.IsDurationObject(duration) then return end
  local ok, remaining = pcall(duration.GetRemainingDuration, duration)
  if ok and not issecretvalue(remaining) then return end
  return {kind = "timer", duration = duration, top = TIMER_TOP, flag = "timerCurveActive"}
end

function PowerCurve.Leaf(ctx, variable, op, value)
  if ctx.kind == "timer" then
    if op == ">=" then return {{value, huge}}
    elseif op == ">" then return {{value + 1e-3, huge}}
    -- A finished timer (0) is not "remaining less than".
    elseif op == "<=" then return {{1e-3, value + 1e-3}}
    elseif op == "<" then return {{1e-3, value}}
    end
    return PowerCurve.NONE
  end
  local names = PowerCurve.kinds[ctx.kind]
  if variable == names.deficit then
    if not ctx.max then return PowerCurve.NONE end
    variable, op, value = names.value, flipped[op], ctx.max - value
  end
  local lo, hi
  if variable == names.value then
    if not ctx.max then return PowerCurve.NONE end
    lo, hi = (value - 0.5) / ctx.max, (value + 0.5) / ctx.max
  else
    lo, hi = value / 100 - 1e-5, value / 100 + 1e-5
  end
  if op == ">=" then return {{lo, huge}}
  elseif op == ">" then return {{hi, huge}}
  elseif op == "<=" then return {{-huge, hi}}
  elseif op == "<" then return {{-huge, lo}}
  elseif op == "==" then return {{lo, hi}}
  elseif op == "~=" then return {{-huge, lo}, {hi, huge}}
  end
  return PowerCurve.NONE
end

local function Normalize(list)
  table.sort(list, function(a, b) return a[1] < b[1] end)
  local result = {}
  for _, range in ipairs(list) do
    if range[2] > range[1] then
      local last = result[#result]
      if last and range[1] <= last[2] then
        if range[2] > last[2] then last[2] = range[2] end
      else
        result[#result + 1] = {range[1], range[2]}
      end
    end
  end
  return result
end

function PowerCurve.Union(...)
  local list = {}
  for i = 1, select("#", ...) do
    for _, range in ipairs((select(i, ...))) do list[#list + 1] = {range[1], range[2]} end
  end
  return Normalize(list)
end

function PowerCurve.Inter(...)
  local result = PowerCurve.ALL
  for i = 1, select("#", ...) do
    local other, list = select(i, ...), {}
    for _, a in ipairs(result) do
      for _, b in ipairs(other) do
        local lo, hi = math.max(a[1], b[1]), math.min(a[2], b[2])
        if hi > lo then list[#list + 1] = {lo, hi} end
      end
    end
    result = Normalize(list)
  end
  return result
end

local function Contains(set, x)
  for _, range in ipairs(set) do
    if x >= range[1] and x < range[2] then return true end
  end
  return false
end

local function Same(a, b)
  if type(a) == "table" and type(b) == "table" then
    for i = 1, 4 do
      if (a[i] or 1) ~= (b[i] or 1) then return false end
    end
    return true
  end
  return a == b
end

function PowerCurve.Pieces(base, ops, top)
  top = top or 1
  local bounds = {0}
  local function AddBounds(set)
    for _, range in ipairs(set) do
      for j = 1, 2 do
        if range[j] > 0 and range[j] < top then bounds[#bounds + 1] = range[j] end
      end
    end
  end
  for _, op in ipairs(ops) do AddBounds(op[1]) end
  table.sort(bounds)
  local pieces = {}
  for k, x in ipairs(bounds) do
    local nextX = bounds[k + 1] or top
    if nextX - x > 1e-6 or k == #bounds then
      local mid = (x + math.max(nextX, x)) / 2
      local value = base
      for _, op in ipairs(ops) do
        if Contains(op[1], mid) then value = op[2] end
      end
      local last = pieces[#pieces]
      if not (last and Same(last[2], value)) then pieces[#pieces + 1] = {x, value} end
    end
  end
  return pieces
end

local curves = {}

local function Curve(pieces, component, top)
  top = top or 1
  local key = {top}
  for k, piece in ipairs(pieces) do
    local value = piece[2]
    if component then value = value[component] or 1 end
    key[k + 1] = piece[1] .. "=" .. value
  end
  key = table.concat(key, ";")
  if curves[key] then return curves[key] end
  -- Steps hold each value until the next point; nearly equal points in a
  -- linear curve get merged and fade between values instead.
  local curve = C_CurveUtil.CreateCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  for _, piece in ipairs(pieces) do
    local value = piece[2]
    if component then value = value[component] or 1 end
    curve:AddPoint(piece[1], value)
  end
  local last = pieces[#pieces][2]
  if component then last = last[component] or 1 end
  curve:AddPoint(top, last)
  curves[key] = curve
  return curve
end

function PowerCurve.Evaluate(ctx, pieces, component)
  if #pieces == 1 then
    local value = pieces[1][2]
    if component then return value[component] or 1 end
    return value
  end
  if ctx.kind == "timer" then
    return ctx.duration:EvaluateRemainingDuration(Curve(pieces, component, ctx.top))
  end
  if ctx.kind == "health" then
    return UnitHealthPercent(ctx.unit, true, Curve(pieces, component))
  end
  return UnitPowerPercent(ctx.unit, ctx.powerType, false, Curve(pieces, component))
end

function PowerCurve.Apply(ctx, region, propertyChanges, active, sets, plan)
  local varies = false
  for property, info in pairs(plan.props) do
    local value, ops = info.base, {}
    for _, step in ipairs(plan.steps) do
      local change = step.changes[property]
      if change ~= nil then
        if step.power then
          ops[#ops + 1] = {sets[step.condition] or PowerCurve.NONE, change}
        elseif active[step.condition] then
          value, ops = change, {}
        end
      end
    end
    if #ops > 0 then
      local pieces = PowerCurve.Pieces(value, ops, ctx.top)
      if #pieces > 1 then varies = true end
      if info.type == "color" then
        propertyChanges[property] = {PowerCurve.Evaluate(ctx, pieces, 1), PowerCurve.Evaluate(ctx, pieces, 2),
          PowerCurve.Evaluate(ctx, pieces, 3), PowerCurve.Evaluate(ctx, pieces, 4)}
      else
        propertyChanges[property] = PowerCurve.Evaluate(ctx, pieces)
      end
      region[ctx.flag or "powerCurveActive"] = true
    end
  end
  return varies
end

function PowerCurve.RestoreForced(propertyChanges, plan, active)
  for property, info in pairs(plan.forced) do
    local value = info.base
    for _, step in ipairs(plan.steps) do
      if step.visible and step.visible[property] ~= nil and active[step.condition] then value = step.visible[property] end
    end
    propertyChanges[property] = value
  end
end

-- Back to what the conditions say once the timer is readable again.
function PowerCurve.RestoreSteps(region, propertyChanges, plan, active, flag)
  region[flag] = nil
  for property, info in pairs(plan.props) do
    local value = info.base
    for _, step in ipairs(plan.steps) do
      local change = step.changes[property]
      if change ~= nil and active[step.condition] then value = change end
    end
    propertyChanges[property] = value
  end
end

-- Back to what the active conditions say once the value is readable again.
function PowerCurve.Restore(region, propertyChanges, plan, active)
  region.powerCurveActive = nil
  for property, info in pairs(plan.props) do
    if propertyChanges[property] == nil then
      local value = info.base
      for _, step in ipairs(plan.steps) do
        local change = step.changes[property]
        if change ~= nil and active and active[step.condition] then value = change end
      end
      propertyChanges[property] = value
    end
  end
end

local function CreateTestForCondition(data, input, allConditionsTemplate, usedStates)
  if Private.BlizzardAuraDisplay.ContainsNativeCondition(data, input) then return "false" end
  local uid = data.uid
  local trigger = input and input.trigger;
  local variable = input and input.variable;
  local op = input and input.op;
  local value = input and input.value;

  local check = nil;
  local recheckCode = nil;

  if (variable == "AND" or variable == "OR") then
    local test = {};
    if (input.checks) then
      for i, subcheck in ipairs(input.checks) do
        local subtest, subrecheckCode = CreateTestForCondition(data, subcheck, allConditionsTemplate, usedStates);
        if (subtest) then
          tinsert(test, "(" .. subtest .. ")");
        end
        if (subrecheckCode) then
          recheckCode = recheckCode or "";
          recheckCode = recheckCode .. subrecheckCode;
        end
      end
    end
    if (next(test)) then
      if (variable == "AND") then
        check = table.concat(test, " and ");
      else
        check = table.concat(test, " or ");
      end
    end
  end

  if (trigger and variable) then
    usedStates[trigger] = true;

    local conditionTemplate = allConditionsTemplate[trigger] and allConditionsTemplate[trigger][variable];
    local cType = conditionTemplate and conditionTemplate.type;
    local test = conditionTemplate and conditionTemplate.test;
    local recheckTime = conditionTemplate and conditionTemplate.recheckTime
    local preamble = conditionTemplate and conditionTemplate.preamble;
    local progressSource
    local modRateProperty
    local pausedProperty
    local remainingProperty
    if cType == "timer" then
      progressSource = Private.GetProgressSourceFor(data, trigger, variable)
      modRateProperty = progressSource and progressSource[5]
      pausedProperty = progressSource and progressSource[7]
      remainingProperty = progressSource[8]
    end

    local stateCheck = "state[" .. trigger .. "] and state[" .. trigger .. "].show and ";
    local stateValue = string.format("Private.ExecEnv.GetConditionValue(state[%s], %q)", trigger, variable)
    local stateVariableCheck = "not issecretvalue(" .. stateValue .. ") and " .. stateValue .. " ~= nil and "

    local preambleString

    if preamble then
      Private.ExecEnv.conditionHelpers[uid] = Private.ExecEnv.conditionHelpers[uid] or {}
      Private.ExecEnv.conditionHelpers[uid].preambles = Private.ExecEnv.conditionHelpers[uid].preambles or {}
      tinsert(Private.ExecEnv.conditionHelpers[uid].preambles, preamble(value) or "");
      local preambleNumber = #Private.ExecEnv.conditionHelpers[uid].preambles
      preambleString = string.format("Private.ExecEnv.conditionHelpers[%q].preambles[%s]", uid, preambleNumber)
    end

    if (test) then
      if (value) then
        Private.ExecEnv.conditionHelpers[uid] = Private.ExecEnv.conditionHelpers[uid] or {}
        Private.ExecEnv.conditionHelpers[uid].customTestFunctions
          = Private.ExecEnv.conditionHelpers[uid].customTestFunctions or {}
        tinsert(Private.ExecEnv.conditionHelpers[uid].customTestFunctions, test);
        local testFunctionNumber = #(Private.ExecEnv.conditionHelpers[uid].customTestFunctions);
        local valueString = type(value) == "string" and string.format("%q", value) or value;
        local opString = type(op) == "string" and string.format("%q", op) or op;
        check = string.format("state and Private.ExecEnv.CallCustomConditionTest(%q, %s, state[%s], %s, %s, %s)",
                              uid, testFunctionNumber, trigger, valueString, (opString or "nil"),
                              preambleString or "nil")
      end
    elseif (cType == "customcheck") then
      if value then
        local customCheck = WeakAuras.LoadFunction("return " .. value, data.id)
        if customCheck then
          Private.ExecEnv.conditionHelpers[uid] = Private.ExecEnv.conditionHelpers[uid] or {}
          Private.ExecEnv.conditionHelpers[uid].customTestFunctions
            = Private.ExecEnv.conditionHelpers[uid].customTestFunctions or {}
          tinsert(Private.ExecEnv.conditionHelpers[uid].customTestFunctions, customCheck);
          local testFunctionNumber = #(Private.ExecEnv.conditionHelpers[uid].customTestFunctions);

          check = string.format("state and Private.ExecEnv.CallCustomConditionTest(%q, %s, state)",
                                uid, testFunctionNumber, trigger);
        end
      end
    elseif cType == "alwaystrue" then
      check = "true"
    elseif (cType == "number" and value and op) then
      local v = tonumber(value)
      if (v) then
          check = stateCheck .. stateVariableCheck .. stateValue
                  .. op .. v;
      end
    elseif (cType == "timer" and value and op) then
      local varString = stateValue
      local remainingTime = "(" .. varString .. " - now)"
      if pausedProperty and remainingProperty then
        local pausedString = "state[" .. trigger .. "]" .. string.format("[%q]", pausedProperty)
        local remainingString = "(state[" .. trigger .. "]" .. string.format("[%q]", remainingProperty) .. " or 0)"

        remainingTime = "((" .. pausedString .. " and " .. remainingString .. ") or " ..  remainingTime .. ")"
      end

      local divideModRate = modRateProperty
            and  " / (state[" .. trigger .. "]" .. string.format("[%q]",  modRateProperty) .. " or 1.0)"
            or ""

      if (op == "==") then
        check = stateCheck .. stateVariableCheck .. varString .. "~= 0 and " .. "abs((" .. remainingTime .. "-" .. value .. ")" .. divideModRate .. ") < 0.05"
      else
        check = stateCheck .. stateVariableCheck .. varString .. "~= 0 and " .. remainingTime .. divideModRate .. op .. value
      end
    elseif (cType == "elapsedTimer" and value and op) then
      if (op == "==") then
        check = stateCheck .. stateVariableCheck .. "abs(state[" .. trigger .. "]" .. string.format("[%q]", variable)
                .. "- now +" .. value .. ") < 0.05";
      else
        check = stateCheck .. stateVariableCheck .. "now - state[" .. trigger .. "]" .. string.format("[%q]", variable)
                .. op .. value;
      end
    elseif (cType == "select" and value and op) then
      if (tonumber(value)) then
        check = stateCheck .. stateVariableCheck .. stateValue
                .. op .. tonumber(value);
      else
        check = stateCheck .. stateVariableCheck .. stateValue
                .. op .. "'" .. value .. "'";
      end
    elseif (cType == "range" and value and op and input.type and input.op_range and input.range) then
      local fn
      if input.type == "group" then
        fn = [[
          return function()
            local found = 0
            local op = %q
            local range = %s
            for unit in WA_IterateGroupMembers() do
              if not Private.ExecEnv.UnitIsUnit(unit, "player") and WeakAuras.CheckRange(unit, range, op) then
                found = found + 1
              end
            end
            return found %s %d
          end
        ]]
        fn = fn:format(input.op_range, input.range, op, value)
      elseif input.type == "enemies" then
        fn = [[
          return function()
            local found = 0
            local op = %q
            local range = %s
            for i = 1, 40 do
              local unit = "nameplate" .. i
              if UnitExists(unit) and UnitCanAttack("player", unit) and WeakAuras.CheckRange(unit, range, op) then
                found = found + 1
              end
            end
            return found %s %d
          end
        ]]
        fn = fn:format(input.op_range, input.range, op, value)
      end
      if fn then
        local customCheck = WeakAuras.LoadFunction(fn, data.id)
        if customCheck then
          Private.ExecEnv.conditionHelpers[uid] = Private.ExecEnv.conditionHelpers[uid] or {}
          Private.ExecEnv.conditionHelpers[uid].customTestFunctions
            = Private.ExecEnv.conditionHelpers[uid].customTestFunctions or {}
          tinsert(Private.ExecEnv.conditionHelpers[uid].customTestFunctions, customCheck);
          local testFunctionNumber = #(Private.ExecEnv.conditionHelpers[uid].customTestFunctions);

          check = string.format("state and Private.ExecEnv.CallCustomConditionTest(%q, %s, state)",
                                uid, testFunctionNumber, trigger);
        end
      end
    elseif (cType == "bool" and value) then
      local rightSide = value == 0 and "false" or "true";
      check = stateCheck .. stateVariableCheck .. stateValue
              .. "==" .. rightSide
    elseif (cType == "string" and value) then
      if(op == "==") then
        check = stateCheck .. stateVariableCheck .. stateValue
                .. string.format(" == %q", value)
      elseif (op  == "find('%s')") then
        check = stateCheck .. stateVariableCheck .. stateValue
                .. string.format(":find(%q, 1, true)", value)
      elseif (op == "match('%s')") then
        check = stateCheck .. stateVariableCheck .. stateValue
                .. string.format(":match(%q, 1, true)", value)
      end
    end
    -- If adding a new condition type, don't forget to adjust the validator in the options code

    if recheckTime then
      if (value) then
        Private.ExecEnv.conditionHelpers[uid] = Private.ExecEnv.conditionHelpers[uid] or {}
        Private.ExecEnv.conditionHelpers[uid].customTestFunctions
          = Private.ExecEnv.conditionHelpers[uid].customTestFunctions or {}
        tinsert(Private.ExecEnv.conditionHelpers[uid].customTestFunctions, recheckTime);
        local testFunctionNumber = #(Private.ExecEnv.conditionHelpers[uid].customTestFunctions);
        local valueString = type(value) == "string" and string.format("%q", value) or value;

        recheckCode = string.format("  nextTime = Private.ExecEnv.CallCustomConditionTest(%q, %s, state[%s], %s) \n",
                                    uid, testFunctionNumber, trigger, valueString)
        recheckCode = recheckCode .. "  if (nextTime and (not recheckTime or nextTime < recheckTime) and nextTime >= now) then\n"
        recheckCode = recheckCode .. "    recheckTime = nextTime\n";
        recheckCode = recheckCode .. "  end\n"
      end
    elseif (cType == "timer" and value) then
      local variableString =  stateValue
      local multiplyModRate = modRateProperty
            and  " * (state[" .. trigger .. "]" .. string.format("[%q]",  modRateProperty) .. " or 1.0)"
            or ""
      local andNotPaused = pausedProperty
            and "and not " .. "state[" .. trigger .. "]" .. string.format("[%q]",  pausedProperty)
            or ""

      recheckCode = "  nextTime = state[" .. trigger .. "] " .. andNotPaused
      .. " and not issecretvalue(" .. variableString .. ") and " .. variableString
      .. " and " .. "(" .. variableString .. " - " .. value .. multiplyModRate .. ")\n"

      recheckCode = recheckCode .. "  if (nextTime and (not recheckTime or nextTime < recheckTime) and nextTime >= now) then\n"
      recheckCode = recheckCode .. "    recheckTime = nextTime\n";
      recheckCode = recheckCode .. "  end\n"
    elseif (cType == "elapsedTimer" and value) then
      recheckCode = "  nextTime = state[" .. trigger .. "] and state[" .. trigger .. "]" .. string.format("[%q]",  variable) .. "and not issecretvalue(state[" .. trigger .. "]" .. string.format("[%q]",  variable) .. ")" .. " and (state[" .. trigger .. "]" .. string.format("[%q]",  variable) .. " +" .. value .. ")\n";
      recheckCode = recheckCode .. "  if (nextTime and (not recheckTime or nextTime < recheckTime) and nextTime >= now) then\n"
      recheckCode = recheckCode .. "    recheckTime = nextTime\n";
      recheckCode = recheckCode .. "  end\n"
    end
  end

  return check, recheckCode;
end

-- The ordinary part of an All of / Any of with one Aura Active check
-- (BlizzardAuraDisplay.CombinationNative): the combination without that
-- child, compiled as usual. Returns the test and the operator.
local function CombinationWithoutNative(data, condition, allConditionsTemplate, usedStates)
  local native, _, operator = Private.BlizzardAuraDisplay.CombinationNative(data, condition.check)
  if not native then return end
  local rest = CopyTable(condition.check)
  rest.checks = {}
  for _, child in ipairs(condition.check.checks or {}) do
    if child ~= native then rest.checks[#rest.checks + 1] = CopyTable(child) end
  end
  if #rest.checks == 0 then return "true", operator, nil end
  local test, recheckCode = CreateTestForCondition(data, rest, allConditionsTemplate, usedStates)
  return test or "false", operator, recheckCode
end

local function CreateCheckCondition(data, ret, condition, conditionNumber, allConditionsTemplate, nextIsLinked, debug)
  local usedStates = {};
  -- All of: the ordinary part gates the declared Aura Active look, and the
  -- condition is never active in Lua. Any of: while the ordinary part is true
  -- the condition is active like any other (its changes applied outright);
  -- otherwise the declared look applies. The gate is set after the property
  -- loop (ret.secretGates), so a withdrawn Any of restores its base values
  -- before the declared look is painted again.
  local gateTest, operator, gateRecheck = CombinationWithoutNative(data, condition, allConditionsTemplate, usedStates)
  if gateTest then
    ret.secretGates = ret.secretGates or {}
    if operator == "AND" then
      table.insert(ret.secretGates, "  Private.ExecEnv.SetSecretAuraConditionGate(region, " .. conditionNumber .. ", not hideRegion and (" .. gateTest .. ") and true or false)\n")
      return gateRecheck
    end
    table.insert(ret, "      if (" .. gateTest .. ") then\n")
    table.insert(ret, "        newActiveConditions[" .. conditionNumber .. "] = true;\n")
    table.insert(ret, "      end\n")
    table.insert(ret.secretGates, "  Private.ExecEnv.SetSecretAuraConditionGate(region, " .. conditionNumber .. ", not (not hideRegion and (" .. gateTest .. ")))\n")
    return gateRecheck
  end
  local check, recheckCode = CreateTestForCondition(data, condition.check, allConditionsTemplate, usedStates);
  if not check then
    check = "false"
  end
  if condition.linked and conditionNumber > 1 then
    table.insert(ret, "      elseif (" .. check .. ") then\n")
  else
    table.insert(ret, "      if (" .. check .. ") then\n")
  end
  table.insert(ret, "        newActiveConditions[" .. conditionNumber .. "] = true;\n")
  if not nextIsLinked then
    table.insert(ret, "      end\n")
  end

  if (check) then
    table.insert(ret, "\n")
  end
  return recheckCode;
end

local function ParseProperty(property)
  local subIndex, prop = string.match(property, "^sub%.(%d*).(.*)")
  if subIndex then
    return tonumber(subIndex), prop
  else
    return nil, property
  end
end

local function ResolveBaseProperty(property, baseProperty)
  if not baseProperty then
    return property
  end
  if string.match(baseProperty, "^sub%.") then
    return baseProperty
  end
  local subIndex = ParseProperty(property)
  if subIndex then
    return "sub." .. subIndex .. "." .. baseProperty
  end
  return baseProperty
end

local function GetBaseProperty(data, property, start)
  if (not data) then
    return nil;
  end

  local subIndex, prop = ParseProperty(property)
  if subIndex then
    return GetBaseProperty(data.subRegions[subIndex], prop, start)
  end

  start = start or 1;
  local next = string.find(property, ".", start, true);
  if (next) then
    return GetBaseProperty(data[string.sub(property, start, next - 1)], property, next + 1);
  end

  local key = string.sub(property, start);
  return data[key] or data[tonumber(key)];
end

local function CreateDeactivateCondition(ret, condition, conditionNumber, data, properties, usedProperties, debug)
  if (condition.changes) then
    table.insert(ret, "  if (activatedConditions[".. conditionNumber .. "] and not newActiveConditions[" .. conditionNumber .. "]) then\n")
    if (debug) then table.insert(ret, "    print('Deactivating condition " .. conditionNumber .. "' )\n") end
    for changeNum, change in ipairs(condition.changes) do
      if (change.property) then
        local propertyData = properties and properties[change.property]
        if (propertyData and propertyData.type and propertyData.setter) then
          local baseProperty = ResolveBaseProperty(change.property, propertyData.baseProperty or change.property)
          usedProperties[change.property] = true;
          table.insert(ret, "    propertyChanges['" .. baseProperty .. "'] = "
                .. formatValueForAssignment(propertyData.type, GetBaseProperty(data, baseProperty), nil, nil, data) .. "\n")
          if (debug) then
            table.insert(ret, "    print('- " .. change.property .. " "
                      .. formatValueForAssignment(propertyData.type, GetBaseProperty(data, baseProperty),
                                                  nil, nil, data)
                      .. "')\n")
          end
        end
      end
    end
    table.insert(ret, "  end\n")
  end

  return ret;
end

local function CreateActivateCondition(ret, id, condition, conditionNumber, data, properties, debug, constants)
  local function appendColorFromBooleanChange(change, propertyData, valueToApply)
    local baseProperty = ResolveBaseProperty(change.property, propertyData.baseProperty or change.property)
    local baseColor = GetBaseProperty(data, baseProperty)
    if type(baseColor) ~= "table" then
      baseColor = propertyData.resetFallback or {1, 1, 1, 1}
    end

    local formattedValue = formatValueForAssignmentWithConstants(propertyData.type, valueToApply, nil, nil, data, constants)
    table.insert(ret, "      local colorChange = " .. formattedValue .. "\n")
    table.insert(ret, "      if type(colorChange) == 'table' then\n")
    table.insert(ret, "        local dc1, dc2, dc3, dc4\n")
    table.insert(ret, "        if type(propertyChanges['" .. baseProperty .. "']) == 'table' then\n")
    table.insert(ret, "          dc1, dc2, dc3, dc4 = propertyChanges['" .. baseProperty .. "'][1] or " .. tostring(baseColor[1] or 1)
      .. ", propertyChanges['" .. baseProperty .. "'][2] or " .. tostring(baseColor[2] or 1)
      .. ", propertyChanges['" .. baseProperty .. "'][3] or " .. tostring(baseColor[3] or 1)
      .. ", propertyChanges['" .. baseProperty .. "'][4] or " .. tostring(baseColor[4] or 1) .. "\n")
    table.insert(ret, "        else\n")
    table.insert(ret, "          dc1, dc2, dc3, dc4 = " .. tostring(baseColor[1] or 1) .. ", " .. tostring(baseColor[2] or 1)
      .. ", " .. tostring(baseColor[3] or 1) .. ", " .. tostring(baseColor[4] or 1) .. "\n")
    table.insert(ret, "        end\n")
    table.insert(ret, "        if type(colorChange.checks) == 'table' then\n")
    table.insert(ret, "          local c1, c2, c3, c4 = dc1, dc2, dc3, dc4\n")
    table.insert(ret, "          for _, check in ipairs_reverse(colorChange.checks) do\n")
    table.insert(ret, "            if type(check) == 'table' and check.trigger ~= nil and check.variable ~= nil then\n")
    table.insert(ret, "              local boolValue = state[check.trigger] and state[check.trigger][check.variable]\n")
    table.insert(ret, "              if boolValue == nil and check.variable == 'alwaystrue' then\n")
    table.insert(ret, "                boolValue = true\n")
    table.insert(ret, "              end\n")
    table.insert(ret, "              if boolValue ~= nil then\n")
    table.insert(ret, "                local ac1, ac2, ac3, ac4\n")
    table.insert(ret, "                if check.color then\n")
    table.insert(ret, "                  ac1, ac2, ac3, ac4 = check.color[1] or 1, check.color[2] or 1, check.color[3] or 1, check.color[4] or 1\n")
    table.insert(ret, "                else\n")
    table.insert(ret, "                  ac1, ac2, ac3, ac4 = dc1, dc2, dc3, dc4\n")
    table.insert(ret, "                end\n")
    table.insert(ret, "                local tc1, tc2, tc3, tc4\n")
    table.insert(ret, "                local fc1, fc2, fc3, fc4\n")
    table.insert(ret, "                if check.when == false then\n")
    table.insert(ret, "                  tc1, tc2, tc3, tc4 = c1, c2, c3, c4\n")
    table.insert(ret, "                  fc1, fc2, fc3, fc4 = ac1, ac2, ac3, ac4\n")
    table.insert(ret, "                else\n")
    table.insert(ret, "                  tc1, tc2, tc3, tc4 = ac1, ac2, ac3, ac4\n")
    table.insert(ret, "                  fc1, fc2, fc3, fc4 = c1, c2, c3, c4\n")
    table.insert(ret, "                end\n")
    table.insert(ret, "                c1 = C_CurveUtil.EvaluateColorValueFromBoolean(boolValue, tc1, fc1)\n")
    table.insert(ret, "                c2 = C_CurveUtil.EvaluateColorValueFromBoolean(boolValue, tc2, fc2)\n")
    table.insert(ret, "                c3 = C_CurveUtil.EvaluateColorValueFromBoolean(boolValue, tc3, fc3)\n")
    table.insert(ret, "                c4 = C_CurveUtil.EvaluateColorValueFromBoolean(boolValue, tc4, fc4)\n")
    table.insert(ret, "              end\n")
    table.insert(ret, "            end\n")
    table.insert(ret, "          end\n")
    table.insert(ret, "          propertyChanges['" .. baseProperty .. "'] = { c1, c2, c3, c4 }\n")
    table.insert(ret, "        else\n")
    table.insert(ret, "          propertyChanges['" .. baseProperty .. "'] = { dc1, dc2, dc3, dc4 }\n")
    table.insert(ret, "        end\n")
    table.insert(ret, "      end\n")
  end

  local function appendValueFromBooleanChange(change, propertyData, valueToApply)
    local baseProperty = ResolveBaseProperty(change.property, propertyData.baseProperty or change.property)
    local baseValue = GetBaseProperty(data, baseProperty)
    if type(baseValue) == "boolean" then
      baseValue = baseValue and 1 or 0
    end
    if baseValue == nil and propertyData.resetFallback ~= nil then
      baseValue = propertyData.resetFallback
    end

    local formattedValue = formatValueForAssignmentWithConstants(propertyData.type, valueToApply, nil, nil, data, constants)
    table.insert(ret, "      local valueChange = " .. formattedValue .. "\n")
    table.insert(ret, "      if type(valueChange) == 'table' then\n")
    table.insert(ret, "        local currentValue\n")
    table.insert(ret, "        if type(propertyChanges['" .. baseProperty .. "']) == 'number' then\n")
    table.insert(ret, "          currentValue = propertyChanges['" .. baseProperty .. "']\n")
    table.insert(ret, "        else\n")
    table.insert(ret, "          currentValue = " .. (baseValue ~= nil and tostring(baseValue) or "0") .. "\n")
    table.insert(ret, "        end\n")
    table.insert(ret, "        if type(valueChange.checks) == 'table' then\n")
    table.insert(ret, "          for _, check in ipairs_reverse(valueChange.checks) do\n")
    table.insert(ret, "            if type(check) == 'table' and check.trigger ~= nil and check.variable ~= nil then\n")
    table.insert(ret, "              local boolValue = state[check.trigger] and state[check.trigger][check.variable]\n")
    table.insert(ret, "              if boolValue == nil and check.variable == 'alwaystrue' then\n")
    table.insert(ret, "                boolValue = true\n")
    table.insert(ret, "              end\n")
    table.insert(ret, "              if boolValue ~= nil then\n")
    table.insert(ret, "                local appliedValue = check.value\n")
    table.insert(ret, "                if appliedValue == nil then appliedValue = " .. (baseValue ~= nil and tostring(baseValue) or "0") .. " end\n")
    table.insert(ret, "                local trueValue\n")
    table.insert(ret, "                local falseValue\n")
    table.insert(ret, "                if check.when == false then\n")
    table.insert(ret, "                  trueValue = currentValue\n")
    table.insert(ret, "                  falseValue = appliedValue\n")
    table.insert(ret, "                else\n")
    table.insert(ret, "                  trueValue = appliedValue\n")
    table.insert(ret, "                  falseValue = currentValue\n")
    table.insert(ret, "                end\n")
    table.insert(ret, "                currentValue = C_CurveUtil.EvaluateColorValueFromBoolean(boolValue, trueValue, falseValue)\n")
    table.insert(ret, "              end\n")
    table.insert(ret, "            end\n")
    table.insert(ret, "          end\n")
    table.insert(ret, "          propertyChanges['" .. baseProperty .. "'] = currentValue\n")
    table.insert(ret, "        else\n")
    table.insert(ret, "          propertyChanges['" .. baseProperty .. "'] = currentValue\n")
    table.insert(ret, "        end\n")
    table.insert(ret, "      end\n")
  end
  if (condition.changes) then
    table.insert(ret, "  if (newActiveConditions[" .. conditionNumber .. "]) then\n")
    -- Apply boolean-driven changes once per active condition
    for changeNum, change in ipairs(condition.changes) do
      if (change.property) then
        local propertyData = properties and properties[change.property]
        if (propertyData and propertyData.type and propertyData.setter) then
          if propertyData.colorFromBoolean then
            local valueToApply = change.value
            if type(valueToApply) ~= "table" then
              valueToApply = propertyData.default
            end
            appendColorFromBooleanChange(change, propertyData, valueToApply)
          elseif propertyData.valueFromBoolean then
            local valueToApply = change.value
            if type(valueToApply) ~= "table" then
              valueToApply = propertyData.default
            end
            appendValueFromBooleanChange(change, propertyData, valueToApply)
          end
        end
      end
    end
    table.insert(ret, "    if (not activatedConditions[".. conditionNumber .. "]) then\n")
    if (debug) then table.insert(ret, "      print('Activating condition " .. conditionNumber .. "' )\n") end
    -- non active => active
    for changeNum, change in ipairs(condition.changes) do
      if (change.property) then
        local propertyData = properties and properties[change.property]
        if (propertyData and propertyData.type) then
          if (propertyData.setter) then
            local valueToApply = change.value
            if (propertyData.valueFromBoolean or propertyData.colorFromBoolean) and type(valueToApply) ~= "table" then
              valueToApply = propertyData.default
            end
            if not (propertyData.colorFromBoolean or propertyData.valueFromBoolean) then
              table.insert(ret, "      propertyChanges['" .. change.property .. "'] = " .. formatValueForAssignmentWithConstants(propertyData.type, valueToApply, nil, nil, data, constants) .. "\n")
              if (debug) then
                table.insert(ret, "      print('- " .. change.property .. " " .. formatValueForAssignmentWithConstants(propertyData.type, valueToApply, nil, nil, data, constants) .. "')\n")
              end
            end
          elseif (propertyData.action) then
            local pathToCustomFunction = "nil";
            local pathToFormatter = "nil"
            if (Private.ExecEnv.customConditionsFunctions[id]
              and Private.ExecEnv.customConditionsFunctions[id][conditionNumber]
              and  Private.ExecEnv.customConditionsFunctions[id][conditionNumber].changes
              and Private.ExecEnv.customConditionsFunctions[id][conditionNumber].changes[changeNum]) then
              pathToCustomFunction = string.format("Private.ExecEnv.customConditionsFunctions[%q][%s].changes[%s]",
                                                   id, conditionNumber, changeNum);
            end
            if Private.ExecEnv.conditionTextFormatters[id]
              and Private.ExecEnv.conditionTextFormatters[id][conditionNumber]
              and Private.ExecEnv.conditionTextFormatters[id][conditionNumber].changes
              and Private.ExecEnv.conditionTextFormatters[id][conditionNumber].changes[changeNum] then
              pathToFormatter = string.format("Private.ExecEnv.conditionTextFormatters[%q][%s].changes[%s]",
                                              id, conditionNumber, changeNum);
            end
            table.insert(ret, "     region:" .. propertyData.action .. "("
                      .. formatValueForAssignment(propertyData.type, change.value,
                                                  pathToCustomFunction, pathToFormatter, data)
                      .. ")" .. "\n")
            if (debug) then
              table.insert(ret, "     print('# " .. propertyData.action .. "("
                        .. formatValueForAssignment(propertyData.type, change.value,
                                                    pathToCustomFunction, pathToFormatter, data)
                        .. "')\n")
            end
          end
        end
      end
    end
    table.insert(ret, "    else\n")
    -- active => active, only override properties
    for changeNum, change in ipairs(condition.changes) do
      if (change.property) then
        local propertyData = properties and properties[change.property]
        if (propertyData and propertyData.type and propertyData.setter) then
          if not (propertyData.colorFromBoolean or propertyData.valueFromBoolean) then
            table.insert(ret, "      if(propertyChanges['" .. change.property .. "'] ~= nil) then\n")
            table.insert(ret, "        propertyChanges['" .. change.property .. "'] = "
                         .. formatValueForAssignment(propertyData.type, change.value, nil, nil, data) .. "\n")
            if (debug) then table.insert(ret, "        print('- " .. change.property .. " "
                         .. formatValueForAssignment(propertyData.type,  change.value, nil, nil, data) .. "')\n") end
            table.insert(ret, "      end\n")
          end
        end
      end
    end
    table.insert(ret, "    end\n")
    table.insert(ret, "  end\n")
    table.insert(ret, "\n")
    table.insert(ret, "  activatedConditions[".. conditionNumber .. "] = newActiveConditions[" .. conditionNumber .. "]\n")
  end

  return ret;
end

local powerCurveOps = {[">="] = true, [">"] = true, ["<="] = true, ["<"] = true, ["=="] = true, ["~="] = true}
local powerCurveReadable = {number = true, timer = true, elapsedTimer = true, select = true, bool = true, string = true, alwaystrue = true}

local function CurveTriggerKind(data, index)
  local entry = type(index) == "number" and index > 0 and data.triggers[index]
  local trigger = entry and entry.trigger
  if not trigger or trigger.type ~= "unit" then return end
  if trigger.event == "Power" and not (trigger.use_powertype and trigger.powertype == 99) then return "power" end
  if trigger.event == "Health" then return "health" end
end

local function IsCurveVariable(kind, variable)
  if kind == "timer" then return variable == "expirationTime" end
  local names = kind and Private.ExecEnv.PowerCurve.kinds[kind]
  return names and (variable == names.value or variable == names.percent or variable == names.deficit) or false
end

local function PowerCurveExpression(data, check, allConditionsTemplate, curveTrigger, kind)
  if type(check) ~= "table" then return end
  local variable = check.variable
  if variable == "AND" or variable == "OR" then
    local parts, hasPower = {}, false
    for _, subcheck in ipairs(check.checks or {}) do
      local expression, usesPower = PowerCurveExpression(data, subcheck, allConditionsTemplate, curveTrigger, kind)
      if not expression then return end
      parts[#parts + 1] = expression
      hasPower = hasPower or usesPower
    end
    if #parts == 0 then return end
    return (variable == "AND" and "PC.Inter(" or "PC.Union(") .. table.concat(parts, ", ") .. ")", hasPower
  end
  if check.trigger == curveTrigger and IsCurveVariable(kind, variable) then
    local value = tonumber(check.value)
    if not value or not powerCurveOps[check.op] then return end
    return string.format("PC.Leaf(ctx, %q, %q, %s)", variable, check.op, tostring(value)), true
  end
  local template = check.trigger and variable and allConditionsTemplate[check.trigger]
    and allConditionsTemplate[check.trigger][variable]
  if not template or not powerCurveReadable[template.type] or template.test or template.preamble or template.recheckTime then
    return
  end
  local test = CreateTestForCondition(data, check, allConditionsTemplate, {})
  if not test then return end
  return "((" .. test .. ") and PC.ALL or PC.NONE)", false
end

local function FindCurveTrigger(check, data)
  if type(check) ~= "table" then return end
  if check.variable == "AND" or check.variable == "OR" then
    for _, subcheck in ipairs(check.checks or {}) do
      local found = FindCurveTrigger(subcheck, data)
      if found then return found end
    end
  elseif IsCurveVariable(CurveTriggerKind(data, check.trigger), check.variable) then
    return check.trigger
  end
end

local function CurveSetup(data, properties)
  local conditions = data.conditions or {}
  local supported, mixed = {}, {}
  for name, propertyData in pairs(properties) do
    if propertyData.valueFromBoolean or propertyData.colorFromBoolean then
      local base = ResolveBaseProperty(name, propertyData.baseProperty or name)
      local baseData = properties[base]
      if baseData and baseData.setter and (baseData.type == "number" or baseData.type == "color") then
        supported[base] = propertyData
      end
    end
  end
  for _, condition in ipairs(conditions) do
    for _, change in ipairs(condition.changes or {}) do
      local propertyData = change.property and properties[change.property]
      if propertyData and (propertyData.valueFromBoolean or propertyData.colorFromBoolean) then
        mixed[ResolveBaseProperty(change.property, propertyData.baseProperty or change.property)] = true
      end
    end
  end

  local curveTrigger
  for _, condition in ipairs(conditions) do
    curveTrigger = curveTrigger or FindCurveTrigger(condition.check, data)
  end
  return supported, mixed, curveTrigger, curveTrigger and CurveTriggerKind(data, curveTrigger)
end

local function PowerCurveCode(data, properties, allConditionsTemplate)
  Private.AuraWarnings.UpdateWarning(data.uid, "power_curve_conditions", nil)
  if Private.BlizzardAuraDisplay.Enabled(data) then return end
  local conditions = data.conditions or {}
  local supported, mixed, curveTrigger, kind = CurveSetup(data, properties)
  if not curveTrigger then return end

  local function Base(property, propertyData)
    local base = GetBaseProperty(data, property)
    if propertyData.type == "color" then
      if type(base) ~= "table" then base = supported[property].resetFallback or {1, 1, 1, 1} end
      return {base[1] or 1, base[2] or 1, base[3] or 1, base[4] or 1}
    end
    return tonumber(base) or (property:match("alpha$") and 1) or 0
  end

  local plan = {props = {}, steps = {}}
  local expressions, limited = {}, false
  for conditionNumber, condition in ipairs(conditions) do
    local linked = condition.linked
    local expression, usesPower
    if not linked then
      expression, usesPower = PowerCurveExpression(data, condition.check, allConditionsTemplate, curveTrigger, kind)
    end
    local step = {condition = conditionNumber, power = usesPower and true or false, changes = {}}
    for _, change in ipairs(condition.changes or {}) do
      local property = change.property
      local propertyData = property and properties[property]
      if propertyData and supported[property] and not mixed[property] then
        local value = change.value
        if propertyData.type == "number" then value = tonumber(value) end
        if propertyData.type == "color" and type(value) ~= "table" then value = nil end
        if value ~= nil then
          step.changes[property] = value
          if usesPower and not plan.props[property] then
            plan.props[property] = {type = propertyData.type, base = Base(property, propertyData)}
          end
        elseif usesPower and property then
          limited = true
        end
      elseif usesPower and property then
        limited = true
      end
    end
    if usesPower then expressions[conditionNumber] = expression end
    plan.steps[#plan.steps + 1] = step
  end

  Private.AuraWarnings.UpdateWarning(data.uid, "power_curve_conditions", limited and "info" or nil,
    limited and L["While Power and Health are secret, their conditions can only change Alpha and Color."] or nil)
  if not next(plan.props) then return end

  Private.ExecEnv.conditionHelpers[data.uid] = Private.ExecEnv.conditionHelpers[data.uid] or {}
  Private.ExecEnv.conditionHelpers[data.uid].powerCurve = plan

  local ret = {}
  table.insert(ret, "  do\n")
  table.insert(ret, "    local PC = Private.ExecEnv.PowerCurve\n")
  table.insert(ret, "    local curveState = state[" .. curveTrigger .. "]\n")
  table.insert(ret, "    local plan = Private.ExecEnv.conditionHelpers[uid].powerCurve\n")
  table.insert(ret, string.format("    local ctx = not hideRegion and PC.IsSecret(curveState, %q) and PC.Begin(curveState, %q)\n", kind, kind))
  table.insert(ret, "    if ctx then\n")
  table.insert(ret, "      local sets = {}\n")
  for conditionNumber, expression in pairs(expressions) do
    table.insert(ret, "      sets[" .. conditionNumber .. "] = " .. expression .. "\n")
  end
  table.insert(ret, "      PC.Apply(ctx, region, propertyChanges, newActiveConditions, sets, plan)\n")
  table.insert(ret, "    else\n")
  table.insert(ret, string.format("      PC.Remember(curveState, %q)\n", kind))
  table.insert(ret, "      if region.powerCurveActive then PC.Restore(region, propertyChanges, plan, newActiveConditions) end\n")
  table.insert(ret, "    end\n")
  table.insert(ret, "  end\n")
  return table.concat(ret)
end

-- Remaining Time conditions on a timer Lua cannot read (cooldowns, casts and
-- other duration objects): like Power and Health, they change Alpha and Color
-- through curves the game evaluates, rechecked a few times a second. Texts
-- whose timer they color or hide are drawn by the text formatter instead.
local function FindTimerTrigger(check, allConditionsTemplate, data)
  if type(check) ~= "table" then return end
  if check.variable == "AND" or check.variable == "OR" then
    for _, subcheck in ipairs(check.checks or {}) do
      local found = FindTimerTrigger(subcheck, allConditionsTemplate, data)
      if found then return found end
    end
  elseif check.variable == "expirationTime" and type(check.trigger) == "number" and check.trigger > 0 then
    local template = allConditionsTemplate[check.trigger] and allConditionsTemplate[check.trigger].expirationTime
    if template and template.type == "timer" and Private.RestrictedTimerTrigger(data, check.trigger) then return check.trigger end
  end
end

local function StyledTextProperties(data)
  local handled, forced = {}, {}
  local style = data.regionType == "text" and Private.DurationTextStyle(data)
  if style then handled.color = true end
  for index, element in ipairs(data.subRegions or {}) do
    if element.type == "subtext" then
      style = Private.DurationTextStyle(data, element, index)
      if style then
        handled["sub." .. index .. ".text_color"] = true
        if style.usesVisible then
          handled["sub." .. index .. ".text_visible"] = true
          forced["sub." .. index .. ".text_visible"] = true
        end
      end
    end
  end
  return handled, forced
end

local function TimerCurveCode(data, properties, allConditionsTemplate)
  Private.AuraWarnings.UpdateWarning(data.uid, "timer_curve_conditions", nil)
  if Private.BlizzardAuraDisplay.Enabled(data) then return end
  local conditions = data.conditions or {}
  local timerTrigger
  for _, condition in ipairs(conditions) do
    timerTrigger = timerTrigger or FindTimerTrigger(condition.check, allConditionsTemplate, data)
  end
  if not timerTrigger then return end
  local supported, mixed = CurveSetup(data, properties)
  local handled, forced = StyledTextProperties(data)

  local function Base(property, propertyData)
    local base = GetBaseProperty(data, property)
    if propertyData.type == "color" then
      if type(base) ~= "table" then base = supported[property].resetFallback or {1, 1, 1, 1} end
      return {base[1] or 1, base[2] or 1, base[3] or 1, base[4] or 1}
    end
    return tonumber(base) or (property:match("alpha$") and 1) or 0
  end

  local plan = {props = {}, steps = {}, forced = {}}
  local expressions, limited = {}, false
  -- Properties a Power or Health curve already drives stay with it.
  local helpers = Private.ExecEnv.conditionHelpers[data.uid]
  local powerProps = helpers and helpers.powerCurve and helpers.powerCurve.props or {}
  for conditionNumber, condition in ipairs(conditions) do
    local expression, usesTimer
    -- An Else If after it would replace the curve in combat.
    local nextLinked = conditions[conditionNumber + 1] and conditions[conditionNumber + 1].linked
    if not condition.linked and not nextLinked then
      expression, usesTimer = PowerCurveExpression(data, condition.check, allConditionsTemplate, timerTrigger, "timer")
    elseif FindTimerTrigger(condition.check, allConditionsTemplate, data) then
      limited = true
    end
    local step = {condition = conditionNumber, power = usesTimer and true or false, changes = {}}
    for _, change in ipairs(condition.changes or {}) do
      local property = change.property
      local propertyData = property and properties[property]
      if usesTimer and property and forced[property] then
        plan.forced[property] = {base = GetBaseProperty(data, property) ~= false}
        step.visible = step.visible or {}
        step.visible[property] = change.value and true or false
      elseif propertyData and supported[property] and not mixed[property] and not powerProps[property] then
        local value = change.value
        if propertyData.type == "number" then value = tonumber(value) end
        if propertyData.type == "color" and type(value) ~= "table" then value = nil end
        if value ~= nil then
          step.changes[property] = value
          if usesTimer and not plan.props[property] then
            plan.props[property] = {type = propertyData.type, base = Base(property, propertyData)}
          end
        elseif usesTimer and property and not handled[property] then
          limited = true
        end
      elseif usesTimer and property and not handled[property] then
        limited = true
      end
    end
    if usesTimer then expressions[conditionNumber] = expression end
    plan.steps[#plan.steps + 1] = step
  end

  -- Only triggers whose timers the game restricts need the note.
  local entry = data.triggers[timerTrigger]
  local trigger = type(entry) == "table" and entry.trigger
  local restricted = type(trigger) == "table" and (trigger.type == "spell" or trigger.event == "Cast")
  limited = limited and restricted
  Private.AuraWarnings.UpdateWarning(data.uid, "timer_curve_conditions", limited and "info" or nil,
    limited and L["While the remaining time is secret, Remaining Time conditions can only change Alpha and Color, and color or hide a timer text, and cannot use Else If."] or nil)
  if not next(plan.props) and not next(plan.forced) then return end

  Private.ExecEnv.conditionHelpers[data.uid] = Private.ExecEnv.conditionHelpers[data.uid] or {}
  Private.ExecEnv.conditionHelpers[data.uid].timerCurve = plan

  local ret = {}
  table.insert(ret, "  do\n")
  table.insert(ret, "    local PC = Private.ExecEnv.PowerCurve\n")
  table.insert(ret, "    local plan = Private.ExecEnv.conditionHelpers[uid].timerCurve\n")
  table.insert(ret, "    local ctx = not hideRegion and PC.BeginTimer(state[" .. timerTrigger .. "])\n")
  table.insert(ret, "    if ctx then\n")
  table.insert(ret, "      local sets = {}\n")
  for conditionNumber, expression in pairs(expressions) do
    table.insert(ret, "      sets[" .. conditionNumber .. "] = " .. expression .. "\n")
  end
  table.insert(ret, "      local varies = PC.Apply(ctx, region, propertyChanges, newActiveConditions, sets, plan)\n")
  table.insert(ret, "      for property in pairs(plan.forced) do propertyChanges[property] = true end\n")
  table.insert(ret, "      region.timerCurveActive = true\n")
  table.insert(ret, "      if varies then Private.ExecEnv.ScheduleCurveCheck(uid, cloneId) end\n")
  table.insert(ret, "    elseif region.timerCurveActive then\n")
  table.insert(ret, "      PC.RestoreSteps(region, propertyChanges, plan, newActiveConditions, 'timerCurveActive')\n")
  table.insert(ret, "      PC.RestoreForced(propertyChanges, plan, newActiveConditions)\n")
  table.insert(ret, "    end\n")
  table.insert(ret, "  end\n")
  return table.concat(ret)
end

local function UsesCurveVariable(check, triggernum, kind)
  if type(check) ~= "table" then return false end
  if check.variable == "AND" or check.variable == "OR" then
    for _, subcheck in ipairs(check.checks or {}) do
      if UsesCurveVariable(subcheck, triggernum, kind) then return true end
    end
    return false
  end
  return check.trigger == triggernum and IsCurveVariable(kind, check.variable)
end

local function UsesAbsoluteCurveValue(check, triggernum, kind)
  if type(check) ~= "table" then return false end
  if check.variable == "AND" or check.variable == "OR" then
    for _, subcheck in ipairs(check.checks or {}) do
      if UsesAbsoluteCurveValue(subcheck, triggernum, kind) then return true end
    end
    return false
  end
  local names = Private.ExecEnv.PowerCurve.kinds[kind]
  return check.trigger == triggernum and names ~= nil and (check.variable == names.value or check.variable == names.deficit)
end

local function PropertyName(propertyData, property)
  local display = propertyData and propertyData.display
  if type(display) == "table" then display = table.concat(display, " ") end
  return type(display) == "string" and display ~= "" and display or property
end

-- What a Power or Health trigger does in combat, as filled-in lists for the trigger editor.
function Private.CurveCombatReport(data, triggernum)
  local kind = CurveTriggerKind(data, triggernum)
  if not kind then return end
  local report = {works = {}, notes = {}, fails = {}}
  if Private.BlizzardAuraDisplay.Enabled(data) then return report end
  local properties = Private.GetProperties(data) or {}
  local templates = Private.GetTriggerConditions(data)
  templates[-1] = Private.GetGlobalConditions(data)
  local supported, mixed, curveTrigger = CurveSetup(data, properties)
  local other = curveTrigger and curveTrigger ~= triggernum

  local trigger = data.triggers[triggernum].trigger
  local prototype = Private.event_prototypes[trigger.event]
  local friendly = {player = true, pet = true, group = true, party = true, raid = true}
  local works, outOfCombat, secret, never, enemies = {}, {}, {}, {}, {}
  for _, arg in ipairs(prototype and prototype.args or {}) do
    local name = arg.name
    local selected = name and trigger["use_" .. name]
    local enabled = arg.enable == nil or arg.enable == true or (type(arg.enable) == "function" and arg.enable(trigger))
    local hidden = arg.hidden
    if type(hidden) == "function" then hidden = hidden(trigger) end
    if name and arg.display and not hidden and arg.test ~= "true" and arg.type ~= "description" and arg.type ~= "header"
      and enabled and selected ~= nil and (selected ~= false or arg.type == "tristate") then
      local label = arg.display
      if arg.type == "number" and arg.multiEntry and type(trigger[name]) == "table" then
        local parts = {}
        for i, value in ipairs(trigger[name]) do
          local op = type(trigger[name .. "_operator"]) == "table" and trigger[name .. "_operator"][i] or "=="
          parts[#parts + 1] = ("%s %s %s"):format(arg.display, op, tostring(value))
        end
        if #parts > 0 then label = table.concat(parts, ", ") end
      end
      if arg.filterEnable then
        works[#works + 1] = label
      elseif arg.combat == "never" then
        never[#never + 1] = label
      elseif arg.secretCurve then
        outOfCombat[#outOfCombat + 1] = label
      elseif arg.combat == "secret" then
        secret[#secret + 1] = label
      elseif (name == "namerealm" or name == "npcId") and not friendly[trigger.unit] then
        enemies[#enemies + 1] = label
      else
        works[#works + 1] = label
      end
    end
  end
  if #works > 0 then report.works[#report.works + 1] = table.concat(works, ", ") end
  report.filters = {}
  local value = kind == "power" and "power" or "health"
  if #outOfCombat > 0 then
    report.filters[#report.filters + 1] = "|cffff9933Out of combat only:|r " .. table.concat(outOfCombat, ", ")
      .. ". In combat the aura hides while this filter is set. To fade or hide by " .. value
      .. " in combat, remove the filter and add a Condition that changes Alpha."
  end
  if #secret > 0 then
    report.filters[#report.filters + 1] = "|cffff9933Out of combat only:|r " .. table.concat(secret, ", ")
      .. ". In combat the aura hides while this filter is set; this can't be checked in combat."
  end
  if #enemies > 0 then
    report.filters[#report.filters + 1] = "|cffff9933In combat, won't match enemies in instances:|r " .. table.concat(enemies, ", ") .. "."
  end
  if #never > 0 then
    report.filters[#report.filters + 1] = "|cffff2020Never works as a filter:|r " .. table.concat(never, ", ")
      .. ". The game always hides this from addons. Remove the filter and add a Condition that changes Alpha; that works in and out of combat."
  end

  for conditionNumber, condition in ipairs(data.conditions or {}) do
    if UsesCurveVariable(condition.check, triggernum, kind) then
      local label = "Condition " .. conditionNumber
      local linked = condition.linked
      local expression = not other and not linked
        and PowerCurveExpression(data, condition.check, templates, triggernum, kind)
      local word = kind == "power" and "Power" or "Health"
      if (trigger.unit or "player") ~= "player" and UsesAbsoluteCurveValue(condition.check, triggernum, kind) then
        report.fails[#report.fails + 1] = label .. " (exact " .. word .. " and " .. word .. " Deficit need Max " .. word
          .. ", which the game only shows for you; use " .. word .. " (%) instead)"
      elseif other then
        report.fails[#report.fails + 1] = label .. " (only one Power or Health trigger per aura can be checked in combat)"
      elseif linked then
        report.fails[#report.fails + 1] = label .. " (Else If conditions can't be checked in combat)"
      elseif not expression then
        report.fails[#report.fails + 1] = label .. " (combined with a check that can't be read in combat)"
      else
        local good, bad = {}, {}
        for _, change in ipairs(condition.changes or {}) do
          local property = change.property
          local propertyData = property and properties[property]
          if propertyData then
            local value = change.value
            local ok = supported[property] and not mixed[property]
              and ((propertyData.type == "number" and tonumber(value)) or (propertyData.type == "color" and type(value) == "table"))
            local list = ok and good or bad
            local name = PropertyName(propertyData, property)
            if mixed[property] and supported[property] then name = name .. " (also set by a Boolean condition)" end
            if value == nil and propertyData.type == "number" then name = name .. " (no value set)" end
            list[#list + 1] = name
          end
        end
        if #good > 0 then report.conditionsWork = true end
        if #bad > 0 then report.fails[#report.fails + 1] = label .. ": " .. table.concat(bad, ", ") end
      end
    end
  end
  return report
end

function Private.GetSubRegionProperties(data, properties)
  if data.subRegions then
    local subIndex = {}
    for index, subRegion in ipairs(data.subRegions) do
      local subRegionTypeData = Private.subRegionTypes[subRegion.type];
      local propertiesFunction = subRegionTypeData and subRegionTypeData.properties
      local subProperties;
      if (type(propertiesFunction) == "function") then
        subProperties = propertiesFunction(data, subRegion);
      elseif propertiesFunction then
        subProperties = CopyTable(propertiesFunction)
      end

      if subProperties then
        for key, property in pairs(subProperties) do
          subIndex[key] = subIndex[key] and subIndex[key] + 1 or 1
          property.display = { (Private.BlizzardAuraDisplay.IsDetachedElement(data, subRegion) and "Detached " or "") .. subRegionTypeData.displayName .. " " .. subIndex[key],
                               property.display,
                               property.defaultProperty }
          properties["sub." .. index .. "." .. key ] = property;
        end
      end
    end
  end
end

function Private.GetProperties(data)
  local properties;
  local propertiesFunction = Private.regionTypes[data.regionType] and Private.regionTypes[data.regionType].properties;
  if (type(propertiesFunction) == "function") then
    properties = propertiesFunction(data);
  elseif propertiesFunction then
    properties = CopyTable(propertiesFunction);
  else
    properties = {}
  end

  Private.GetSubRegionProperties(data, properties)
  return Private.BlizzardAuraDisplay.FilterConditionProperties(data, properties);
end

function Private.LoadConditionPropertyFunctions(data)
  local id = data.id;
  if (data.conditions) then
    Private.ExecEnv.customConditionsFunctions[id] = {};
    for conditionNumber, condition in ipairs(data.conditions) do
      if (condition.changes) then
        for changeIndex, change in ipairs(condition.changes) do
          if ( (change.property == "chat" or change.property == "customcode") and type(change.value) == "table" and change.value.custom) then
            local custom = change.value.custom;
            local prefix, suffix;
            if (change.property == "chat") then
              prefix, suffix = "return ", "";
            else
              prefix, suffix = "return function()", "\nend";
            end
            local customFunc = WeakAuras.LoadFunction(prefix .. custom .. suffix, data.id);
            if (customFunc) then
              Private.ExecEnv.customConditionsFunctions[id][conditionNumber] = Private.ExecEnv.customConditionsFunctions[id][conditionNumber] or {};
              Private.ExecEnv.customConditionsFunctions[id][conditionNumber].changes = Private.ExecEnv.customConditionsFunctions[id][conditionNumber].changes or {};
              Private.ExecEnv.customConditionsFunctions[id][conditionNumber].changes[changeIndex] = customFunc;
            end
          end
          if change.property == "chat" then
            local getter = function(key, default)
              local fullKey = "message_format_" .. key
              if change.value[fullKey] == nil then
                change.value[fullKey] = default
              end
              return change.value[fullKey]
            end
            local formatters = change.value and Private.CreateFormatters(change.value.message, getter, true, data)
            Private.ExecEnv.conditionTextFormatters[id] = Private.ExecEnv.conditionTextFormatters[id] or {}
            Private.ExecEnv.conditionTextFormatters[id][conditionNumber] = Private.ExecEnv.conditionTextFormatters[id][conditionNumber] or {};
            Private.ExecEnv.conditionTextFormatters[id][conditionNumber].changes = Private.ExecEnv.conditionTextFormatters[id][conditionNumber].changes or {};
            Private.ExecEnv.conditionTextFormatters[id][conditionNumber].changes[changeIndex] = formatters;
          end
        end
      end
    end
  end
end

local globalConditions =
{
  ["instance_size"] = {
    display = L["Instance Size Type"],
    type = "select",
    values = Private.instance_types,
    events = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED"},
    globalStateUpdate = function(state)
      state.instance_size = WeakAuras.InstanceType();
    end
  },
  ["instance_difficulty"] = {
    display = L["Instance Difficulty"],
    type = "select",
    values = Private.difficulty_types,
    events = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED"},
    globalStateUpdate = function(state)
      state.instance_difficulty = WeakAuras.InstanceDifficulty();
    end
  },
  ["instance_type"] = {
    display = L["Instance Type"],
    type = "select",
    values = Private.instance_difficulty_types,
    events = {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED"},
    globalStateUpdate = function(state)
      state.instance_type = WeakAuras.InstanceTypeRaw();
    end
  },
  ["incombat"] = {
    display = L["In Combat"],
    type = "bool",
    events = {"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"},
    globalStateUpdate = function(state)
      state.incombat = UnitAffectingCombat("player");
    end
  },
  ["hastarget"] = {
    display = L["Has Target"],
    type = "bool",
    events = {"PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD"},
    globalStateUpdate = function(state)
      state.hastarget = UnitExists("target");
    end
  },
  ["rangecheck"] = {
    display = WeakAuras.newFeatureString .. L["Range Check"],
    type = "range",
    control = "WeakAurasSpinBox",
    events = {"WA_SPELL_RANGECHECK"}
  },
  ["attackabletarget"] = {
    display = L["Attackable Target"],
    type = "bool",
    events = {"PLAYER_TARGET_CHANGED", "UNIT_FACTION"},
    globalStateUpdate = function(state)
      state.attackabletarget = UnitCanAttack("player", "target");
    end
  },
  ["customcheck"] = {
    display = L["Custom Check"],
    type = "customcheck"
  },
  ["alwaystrue"] = {
    display = L["Always True"],
    type = "alwaystrue"
  }
}

function Private.GetGlobalConditions(data)
  return Private.BlizzardAuraDisplay.FilterGlobalConditions(data, globalConditions);
end

function Private.ExecEnv.SelectDesaturationByBoolean(active, yes, no)
  if active then return yes end
  return no
end

-- Compile a display-only selection for ordinary icon desaturation conditions.
-- Nested AND/OR checks select color components instead of branching on restricted
-- cooldown values. Other condition effects still use the normal public tests.
local function SpellCooldownDesaturationExpression(data, templates)
  if data.regionType ~= "icon" or Private.BlizzardAuraDisplay.Enabled(data)
      or not C_CurveUtil or not C_CurveUtil.EvaluateColorValueFromBoolean then return end
  local hasCooldownCheck = false
  local function UsesAppearance(check)
    local entry = data.triggers[check.trigger]
    local trigger = entry and entry.trigger
    local spell = trigger and trigger.type == "spell" and trigger.event == "Cooldown Progress (Spell)"
    local cdm = trigger and trigger.type == "cdm" and (trigger.event == "Blizzard Cooldown Manager" or trigger.event == "Blizzard CDM Utility")
    local custom = trigger and trigger.type == "custom" and trigger.custom_type == "stateupdate"
    return (spell or cdm or custom) and check.variable == "onCooldown" and (check.value == 0 or check.value == 1)
  end
  local function Supported(check)
    if not check then return false end
    if check.variable == "AND" or check.variable == "OR" then
      if not check.checks or #check.checks == 0 then return false end
      for _, child in ipairs(check.checks) do
        if not Supported(child) then return false end
      end
    end
    return true
  end
  local function Select(check, yes, no)
    if not check then return no end
    if check.variable == "AND" or check.variable == "OR" then
      local checks = check.checks or {}
      if #checks == 0 then return no end
      local result = check.variable == "AND" and yes or no
      for index = #checks, 1, -1 do
        if check.variable == "AND" then
          result = Select(checks[index], result, no)
        else
          result = Select(checks[index], yes, result)
        end
      end
      return result
    end
    local test = CreateTestForCondition(data, check, templates, {}) or "false"
    if not UsesAppearance(check) then
      return "Private.ExecEnv.SelectDesaturationByBoolean(not not (" .. test .. "), " .. yes .. ", " .. no .. ")"
    end
    hasCooldownCheck = true
    local trigger = data.triggers[check.trigger].trigger
    local selector = trigger.type == "cdm" and "SelectCDMCooldownDesaturation" or "SelectSpellCooldownDesaturation"
    return "Private.ExecEnv." .. selector .. "(state[" .. check.trigger .. "], "
      .. check.value .. ", " .. yes .. ", " .. no .. ", not not (" .. test .. "))"
  end

  local steps = {"local desaturation = " .. (data.desaturate and "1" or "0")}
  local expression = "desaturation"
  for index, condition in ipairs(data.conditions) do
    for _, change in ipairs(condition.changes or {}) do
      if change.property == "desaturationFromBoolean" then return end
      if change.property == "desaturate" then
        if type(change.value) ~= "boolean" then return end
        local value = change.value and "1" or "0"
        if not Supported(condition.check) then
          steps[#steps + 1] = "desaturation = C_CurveUtil.EvaluateColorValueFromBoolean(not not newActiveConditions[" .. index .. "], " .. value .. ", " .. expression .. ")"
        else
          local selected = Select(condition.check, value, expression)
          local earlier = {}
          local first = index
          while first > 1 and data.conditions[first].linked do first = first - 1 end
          for previous = first, index - 1 do
            earlier[#earlier + 1] = "newActiveConditions[" .. previous .. "]"
          end
          if #earlier > 0 then
            selected = "Private.ExecEnv.SelectDesaturationByBoolean(not not (" .. table.concat(earlier, " or ")
              .. "), " .. expression .. ", " .. selected .. ")"
          end
          steps[#steps + 1] = "desaturation = " .. selected
        end
      end
    end
  end
  if hasCooldownCheck then return table.concat(steps, "\n    ") end
end

local function ConstructConditionFunction(data)
  local debug = false
  if (not data.conditions or #data.conditions == 0) then
    return nil
  end

  if Private.BlizzardAuraDisplay.Enabled(data) and Private.BlizzardAuraDisplay.ValidateConditions(data) then return nil end

  local usedProperties = {}

  local allConditionsTemplate = Private.GetTriggerConditions(data)
  allConditionsTemplate[-1] = Private.GetGlobalConditions(data)

  local ret = {""}
  table.insert(ret, "local newActiveConditions = {};\n")
  table.insert(ret, "local propertyChanges = {};\n")
  table.insert(ret, "local nextTime;\n")
  table.insert(ret, string.format("local uid = %q\n", data.uid))
  local constants = { lines = {}, cache = {}, index = 0 }
  local constantsInsertIndex = #ret + 1
  table.insert(ret, "return function(region, hideRegion)\n")
  if (debug) then table.insert(ret, "  print('check conditions for:', region.id, region.cloneId)\n") end
  table.insert(ret, "  local id = region.id\n")
  table.insert(ret, "  local cloneId = region.cloneId or ''\n")
  table.insert(ret, "  local state = region.states\n")
  table.insert(ret, "  local activatedConditions = WeakAuras.GetActiveConditions(id, cloneId)\n")
  table.insert(ret, "  wipe(newActiveConditions)\n")
  table.insert(ret, "  local recheckTime;\n")
  table.insert(ret, "  local now = GetTime();\n")

  -- First Loop gather which conditions are active
  table.insert(ret, "  if (not hideRegion) then\n")
  local recheckCode = {}
  if (data.conditions) then
    Private.ExecEnv.conditionHelpers[data.uid] = nil
    for conditionNumber, condition in ipairs(data.conditions) do
      local nextIsLinked = data.conditions[conditionNumber + 1] and data.conditions[conditionNumber + 1].linked
      local additionalRecheckCode = CreateCheckCondition(data, ret, condition, conditionNumber, allConditionsTemplate, nextIsLinked, debug)
      if additionalRecheckCode then
        table.insert(recheckCode, additionalRecheckCode)
      end
    end
  end
  table.insert(ret, table.concat(recheckCode))
  table.insert(ret, "  end\n")

  table.insert(ret, "  if (recheckTime) then\n")
  table.insert(ret, "    Private.ExecEnv.ScheduleConditionCheck(recheckTime, uid, cloneId);\n")
  table.insert(ret, "  else\n")
  table.insert(ret, "    Private.ExecEnv.CancelConditionCheck(uid, cloneId)")
  table.insert(ret, "  end\n")

  local properties = Private.GetProperties(data)

  -- Now build a property + change list
  -- Second Loop deals with conditions that are no longer active
  table.insert(ret, "  wipe(propertyChanges)\n")
  if (data.conditions) then
    for conditionNumber, condition in ipairs(data.conditions) do
      CreateDeactivateCondition(ret, condition, conditionNumber, data, properties, usedProperties, debug)
    end
  end
  table.insert(ret, "\n")

  -- Third Loop deals with conditions that are newly active
  if (data.conditions) then
    for conditionNumber, condition in ipairs(data.conditions) do
      CreateActivateCondition(ret, data.id, condition, conditionNumber, data, properties, debug, constants)
    end
  end

  -- Recompute only the icon's desaturation, preserving condition order and the
  -- configured base value. Never put a restricted result in active-condition flags.
  local desaturation = SpellCooldownDesaturationExpression(data, allConditionsTemplate)
  if desaturation then
    table.insert(ret, "  if not hideRegion then\n")
    table.insert(ret, "    " .. desaturation .. "\n")
    table.insert(ret, "    propertyChanges['desaturate'] = desaturation\n")
    table.insert(ret, "  else\n")
    table.insert(ret, "    propertyChanges['desaturate'] = " .. (data.desaturate and "1" or "0") .. "\n")
    table.insert(ret, "  end\n")
  end

  local powerCurve = PowerCurveCode(data, properties, allConditionsTemplate)
  if powerCurve then table.insert(ret, powerCurve) end
  local timerCurve = TimerCurveCode(data, properties, allConditionsTemplate)
  if timerCurve then table.insert(ret, timerCurve) end

  -- Last apply changes to region
  for property, _  in pairs(usedProperties) do
    local propertyData = properties and properties[property]
    local baseProperty = ResolveBaseProperty(property, propertyData and propertyData.baseProperty or property)
    -- The appearance expression always assigns a component. Do not compare that
    -- possibly restricted number with nil before passing it to the texture setter.
    local directDesaturation = desaturation and baseProperty == "desaturate"
    if not directDesaturation then
      table.insert(ret, "  if issecretvalue(propertyChanges['" .. baseProperty .. "']) or propertyChanges['" .. baseProperty .. "'] ~= nil then\n")
    end
    local arg1 = ""
    if (properties[baseProperty].arg1) then
      if (type(properties[baseProperty].arg1) == "number") then
        arg1 = tostring(properties[baseProperty].arg1) .. ", "
        else
        arg1 = "'" .. properties[baseProperty].arg1 .. "', "
        end
      end

      local base = "region:"
      local subIndex = ParseProperty(baseProperty)
      if subIndex then
        base = "region.subRegions[" .. subIndex .. "]:"
      end

    if Private.BlizzardAuraDisplay.Enabled(data) and Private.BlizzardAuraDisplay.IsNativeConditionProperty(data, baseProperty) then
      -- ForeverAuras: the value alone cannot say whether a condition still
      -- controls the property or has just restored the saved setting (both
      -- reach the setter as, say, false). The native display is told which:
      -- while a condition changing this property is active the value is an
      -- override; otherwise the override is withdrawn and the display's own
      -- look (the saved setting, or an Aura Active condition) returns.
      local controllers = {}
      for conditionNumber, condition in ipairs(data.conditions or {}) do
        for _, change in ipairs(condition.changes or {}) do
          if change.property then
            local changeData = properties[change.property]
            if ResolveBaseProperty(change.property, changeData and changeData.baseProperty or change.property) == baseProperty then
              controllers[#controllers + 1] = "newActiveConditions[" .. conditionNumber .. "]"
              break
            end
          end
        end
      end
      local controlled = #controllers > 0 and table.concat(controllers, " or ") or "false"
      table.insert(ret, "    if " .. controlled .. " then\n")
      table.insert(ret, "      Private.ExecEnv.SetSecretAuraConditionProperty(region, " .. string.format("%q", baseProperty) .. ", " .. formatValueForCall(properties[baseProperty].type, baseProperty) .. ")\n")
      table.insert(ret, "    else\n")
      table.insert(ret, "      Private.ExecEnv.ResetSecretAuraConditionProperty(region, " .. string.format("%q", baseProperty) .. ", " .. formatValueForCall(properties[baseProperty].type, baseProperty) .. ")\n")
      table.insert(ret, "    end\n")
    else
      table.insert(ret, "    " .. base .. properties[baseProperty].setter .. "(" .. arg1 .. formatValueForCall(properties[baseProperty].type, baseProperty)  .. ")\n")
    end
    if (debug) then table.insert(ret, "    print('Calling "  .. properties[baseProperty].setter ..  " with', " .. arg1 ..  formatValueForCall(properties[baseProperty].type, baseProperty) .. ")\n") end
    if not directDesaturation then
      table.insert(ret, "  end\n")
    end
  end
  -- Gates for All of / Any of with an Aura Active check (CreateCheckCondition).
  for _, line in ipairs(ret.secretGates or {}) do table.insert(ret, line) end
  ret.secretGates = nil
  table.insert(ret, "end\n")

  if #constants.lines > 0 then
    for index = #constants.lines, 1, -1 do
      table.insert(ret, constantsInsertIndex, constants.lines[index])
    end
  end

  return table.concat(ret)
end

local function CancelTimers(uid)
  conditionChecksTimers.recheckTime[uid] = nil;
  if (conditionChecksTimers.recheckHandle[uid]) then
    for _, v in pairs(conditionChecksTimers.recheckHandle[uid]) do
      timer:CancelTimer(v);
    end
  end
  conditionChecksTimers.recheckHandle[uid] = nil;
end

function Private.LoadConditionFunction(data)
  CancelTimers(data.uid)

  local checkConditionsFuncStr = ConstructConditionFunction(data);
  local checkConditionsFunc = checkConditionsFuncStr and Private.LoadFunction(checkConditionsFuncStr, data.id)

  checkConditions[data.uid] = checkConditionsFunc;
end

function Private.RunConditions(region, uid, hideRegion)
  if (checkConditions[uid]) then
    Private.ActivateAuraEnvironmentForRegion(region)
    xpcall(checkConditions[uid], Private.GetErrorHandlerUid(uid, L["Execute Conditions"]), region, hideRegion);
    Private.ActivateAuraEnvironment()
  end
end

local dynamicConditionsFrame = nil;

local globalConditionAllState = {
  [""] = {
    show = true;
  }
};

local globalConditionState = globalConditionAllState[""];

function Private.GetGlobalConditionState()
  return globalConditionAllState;
end

local function runDynamicConditionFunctions(funcs)
  for uid in pairs(funcs) do
    local id = Private.UIDtoID(uid)
    Private.StartProfileAura(id)
    if (Private.IsAuraActive(uid) and checkConditions[uid]) then
      local activeStates = WeakAuras.GetActiveStates(id)
      for cloneId, state in pairs(activeStates) do
        local region = WeakAuras.GetRegion(id, cloneId)
        Private.ActivateAuraEnvironmentForRegion(region)
        checkConditions[uid](region, false)
        Private.ActivateAuraEnvironment()
      end
    end
    Private.StopProfileAura(id)
  end
end

local function UpdateDynamicConditionsStates(self, event)
  if (globalDynamicConditionFuncs[event]) then
    for i, func in ipairs(globalDynamicConditionFuncs[event]) do
      func(globalConditionState);
    end
  end
end

local function handleDynamicConditions(self, event)
  Private.StartProfileSystem("dynamic conditions")
  UpdateDynamicConditionsStates(self, event)
  if (dynamicConditions[event]) then
    runDynamicConditionFunctions(dynamicConditions[event]);
  end
  Private.StopProfileSystem("dynamic conditions")
end

local function UpdateDynamicConditionsPerUnitState(self, event, unit)
  if unit then
    local unitEvent = event..":"..unit
    if globalDynamicConditionFuncs[unitEvent] then
      for i, func in ipairs(globalDynamicConditionFuncs[unitEvent]) do
        func(globalConditionState);
      end
    end
  end
end

local function handleDynamicConditionsPerUnit(self, event, unit)
  Private.StartProfileSystem("dynamic conditions")
  if unit then
    local unitEvent = event..":"..unit
    UpdateDynamicConditionsPerUnitState(self, event, unit)
    if (dynamicConditions[unitEvent]) then
      runDynamicConditionFunctions(dynamicConditions[unitEvent]);
    end
  end
  Private.StopProfileSystem("dynamic conditions")
end

local lastDynamicConditionsUpdateCheck;
local nextFrameConditions = 0
local function handleDynamicConditionsOnUpdate(self)
  local now = GetTime()
  if now >= nextFrameConditions then
    nextFrameConditions = now + 1 / 30
    handleDynamicConditions(self, "FRAME_UPDATE");
  end
  if (not lastDynamicConditionsUpdateCheck or GetTime() - lastDynamicConditionsUpdateCheck > 0.2) then
    lastDynamicConditionsUpdateCheck = GetTime();
    handleDynamicConditions(self, "WA_SPELL_RANGECHECK");
  end
end

local registeredGlobalFunctions = {};

local function EvaluateCheckForRegisterForGlobalConditions(uid, check, allConditionsTemplate, register)
  local trigger = check and check.trigger;
  local variable = check and check.variable;

  if (trigger == -2) then
    if (check.checks) then
      for _, subcheck in ipairs(check.checks) do
        EvaluateCheckForRegisterForGlobalConditions(uid, subcheck, allConditionsTemplate, register);
      end
    end
  elseif trigger == -1 and variable == "customcheck" then
    if check.op then
      for event in string.gmatch(check.op, "[%w_:]+") do
        if (not dynamicConditions[event]) then
          register[event] = true;
          dynamicConditions[event] = {};
        end
        dynamicConditions[event][uid] = true;
      end
    end
  elseif (trigger and variable) then
    local conditionTemplate = allConditionsTemplate[trigger] and allConditionsTemplate[trigger][variable];
    if (conditionTemplate and conditionTemplate.events) then
      for _, event in ipairs(conditionTemplate.events) do
        if (not dynamicConditions[event]) then
          register[event] = true;
          dynamicConditions[event] = {};
        end
        dynamicConditions[event][uid] = true;
      end

      if (conditionTemplate.globalStateUpdate and not registeredGlobalFunctions[variable]) then
        registeredGlobalFunctions[variable] = true;
        for _, event in ipairs(conditionTemplate.events) do
          globalDynamicConditionFuncs[event] = globalDynamicConditionFuncs[event] or {};
          tinsert(globalDynamicConditionFuncs[event], conditionTemplate.globalStateUpdate);
        end
        conditionTemplate.globalStateUpdate(globalConditionState);
      end
    end
  end
end

function Private.RegisterForGlobalConditions(uid)
  local data = Private.GetDataByUID(uid);
  for event, conditionFunctions in pairs(dynamicConditions) do
    conditionFunctions[uid] = nil;
  end

  local register = {};
  if (data.conditions) then
    local allConditionsTemplate = Private.GetTriggerConditions(data);
    allConditionsTemplate[-1] = Private.GetGlobalConditions(data);

    for conditionNumber, condition in ipairs(data.conditions) do
      EvaluateCheckForRegisterForGlobalConditions(uid, condition.check, allConditionsTemplate, register);
    end
  end

  if (next(register) and not dynamicConditionsFrame) then
    dynamicConditionsFrame = CreateFrame("Frame");
    dynamicConditionsFrame:SetScript("OnEvent", handleDynamicConditions);
    dynamicConditionsFrame.units = {}
    Private.frames["Rerun Conditions Frame"] = dynamicConditionsFrame
  end

  for event in pairs(register) do
    if (event == "FRAME_UPDATE" or event == "WA_SPELL_RANGECHECK") then
      if (not dynamicConditionsFrame.onUpdate) then
        dynamicConditionsFrame:SetScript("OnUpdate", handleDynamicConditionsOnUpdate);
        dynamicConditionsFrame.onUpdate = true;
      end
    else
      local unitEvent, unit = event:match("([^:]+):([^:]+)")
      if unitEvent and unit then
        unit = unit:lower()
        if not dynamicConditionsFrame.units[unit] then
          dynamicConditionsFrame.units[unit] = CreateFrame("Frame");
          dynamicConditionsFrame.units[unit]:SetScript("OnEvent", handleDynamicConditionsPerUnit);
        end
        pcall(dynamicConditionsFrame.units[unit].RegisterUnitEvent, dynamicConditionsFrame.units[unit], unitEvent, unit);
        UpdateDynamicConditionsPerUnitState(dynamicConditionsFrame, event, unit)
      else
        pcall(dynamicConditionsFrame.RegisterEvent, dynamicConditionsFrame, event);
        UpdateDynamicConditionsStates(dynamicConditionsFrame, event)
      end
    end
  end
end

function Private.UnregisterForGlobalConditions(uid)
  for event, condFuncs in pairs(dynamicConditions) do
    condFuncs[uid] = nil;
    if next(condFuncs) == nil then
      local unitEvent, unit = event:match("([^:]+):([^:]+)")
      if unitEvent and unit then
        unit = unit:lower()
        pcall(dynamicConditionsFrame.units[unit].UnregisterEvent, dynamicConditionsFrame.units[unit], unitEvent);
      elseif (event == "FRAME_UPDATE" or event == "WA_SPELL_RANGECHECK") then
        if (event == "FRAME_UPDATE" and dynamicConditions["WA_SPELL_RANGECHECK"] == nil)
        or (event == "WA_SPELL_RANGECHECK" and dynamicConditions["FRAME_UPDATE"] == nil)
        then
          dynamicConditionsFrame:SetScript("OnUpdate", nil)
          dynamicConditionsFrame.onUpdate = false
        end
      else
        pcall(dynamicConditionsFrame.UnregisterEvent, dynamicConditionsFrame, event);
      end
      dynamicConditions[event] = nil
    end
  end
end

function Private.UnloadAllConditions()
  for uid in pairs(conditionChecksTimers.recheckTime) do
    if (conditionChecksTimers.recheckHandle[uid]) then
      for _, v in pairs(conditionChecksTimers.recheckHandle[uid]) do
        timer:CancelTimer(v)
      end
    end
  end
  wipe(conditionChecksTimers.recheckTime)
  wipe(conditionChecksTimers.recheckHandle)

  dynamicConditions = {}
  if dynamicConditionsFrame then
    dynamicConditionsFrame:UnregisterAllEvents()
    for _, frame in pairs(dynamicConditionsFrame.units) do
      frame:UnregisterAllEvents()
    end
    dynamicConditionsFrame:SetScript("OnUpdate", nil)
    dynamicConditionsFrame.onUpdate = false
  end
end

function Private.UnloadConditions(uid)
  CancelTimers(uid)
  Private.UnregisterForGlobalConditions(uid);
end
