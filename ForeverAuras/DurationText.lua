-- Modified for ForeverAuras, 2026-10-07.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...

local formatters = {}

-- The public GCD-only state is a text policy, not a duration to format. In
-- particular, a temporarily missing filtered timer must never expose the swipe
-- through GetTextDuration's fallback. Charge selection clears cdmGCDOnly.
-- A readable GCD-free timed state formats in Lua, so it needs no duration object.
local function ReadableTimed(state)
  return state.progressType == "timed" and state.expirationTime ~= nil and state.duration ~= nil
    and not hasanysecretvalues(state.expirationTime, state.duration)
end

function Private.ShouldHideDurationText(state)
  return state and state.cdmHideGCDText == true and not state.cdmTextPreview
    and (state.cdmGCDOnly == true
      or (state.cdmTextDurationRequired and not state.cdmTextDurationObject and not ReadableTimed(state)))
end

-- CDM can show a GCD swipe while its text uses only the spell/recharge timer.
-- Keep this choice independent of whether IsZero() is readable in combat.
function Private.GetTextDuration(state)
  return state.cdmTextDurationObject or state.durationObject
end

-- A regular spell can retain readable timed progress while rendering text from
-- a separate GCD-free duration. Preview text continues to use its sample state.
function Private.UsesDurationText(state)
  if not state then return false end
  if state.cdmHideGCDText and not state.cdmTextPreview then
    return WeakAuras.IsDurationObject(state.cdmTextDurationObject)
  end
  return state.progressType == "durationObject" and WeakAuras.IsDurationObject(state.durationObject)
end

-- Below the threshold (or a minute): seconds, with decimals below the threshold.
local function SecondRules(threshold, precision, rounding, suffix)
  local rules = {{threshold = 0, format = ""}, {threshold = 0.000001, format = "%d" .. suffix, step = 1, rounding = rounding}}
  if threshold > 0 then
    rules[2] = {threshold = 0.000001, format = "%." .. precision .. "f"}
    if threshold < 60 then rules[3] = {threshold = threshold, format = "%d" .. suffix, step = 1, rounding = rounding} end
  end
  return rules
end

local function Part(div, mod, rounding)
  return {div = div, mod = mod, step = 1, rounding = rounding}
end

-- Old Blizzard: 2h | 3m | 10s.
local function ShortRules(threshold, precision, rounding)
  local rules = SecondRules(threshold, precision, rounding, "s")
  rules[#rules + 1] = {threshold = math.max(60, threshold), format = "%dm", components = {Part(60, nil, rounding)}}
  rules[#rules + 1] = {threshold = 3600, format = "%dh", components = {Part(3600, nil, rounding)}}
  rules[#rules + 1] = {threshold = 86400, format = "%dd", components = {Part(86400, nil, rounding)}}
  return rules
end

-- Modern Blizzard: 1h 3m | 3m 7s | 10s.
local function ModernRules(threshold, precision, rounding)
  local down = Enum.NumericRuleFormatRounding.Down
  local rules = SecondRules(threshold, precision, rounding, "s")
  rules[#rules + 1] = {threshold = math.max(60, threshold), format = "%dm %ds", components = {Part(60, nil, down), Part(nil, 60, down)}}
  rules[#rules + 1] = {threshold = 3600, format = "%dh %dm", components = {Part(3600, nil, down), Part(60, 60, down)}}
  rules[#rules + 1] = {threshold = 86400, format = "%dd %dh", components = {Part(86400, nil, down), Part(3600, 24, down)}}
  return rules
end

local styledRules = {[-3] = ShortRules, [-4] = ModernRules}

-- Remaining Time conditions that color or hide a timer text, drawn by the
-- formatter itself so they also work on durations Lua cannot compare: each
-- stretch of remaining time gets the color code (or no text) of the last
-- condition covering it. style = {conds = {{lo, hi, code, visible}}, baseVisible, key}.
local function Styled(rules, style)
  local cuts = {}
  for _, cond in ipairs(style.conds) do
    for _, at in ipairs({cond[1], cond[2]}) do
      if at > 0 and at < math.huge then cuts[#cuts + 1] = at end
    end
  end
  local split = {}
  for index, rule in ipairs(rules) do
    local nextThreshold = rules[index + 1] and rules[index + 1].threshold or math.huge
    split[#split + 1] = CopyTable(rule)
    table.sort(cuts)
    for _, at in ipairs(cuts) do
      if rule.threshold < at and at < nextThreshold and split[#split].threshold < at then
        local copy = CopyTable(rule)
        copy.threshold = at
        split[#split + 1] = copy
      end
    end
  end
  for index, rule in ipairs(split) do
    if rule.format ~= "" then
      local nextThreshold = split[index + 1] and split[index + 1].threshold or rule.threshold + 1
      local mid = (rule.threshold + nextThreshold) / 2
      local code, visible = nil, style.baseVisible
      for _, cond in ipairs(style.conds) do
        if mid >= cond[1] and mid < cond[2] then
          if cond[3] then code = cond[3] end
          if cond[4] ~= nil then visible = cond[4] end
        end
      end
      if not visible then
        rule.format, rule.components = "", nil
      elseif code then
        rule.format = code .. rule.format .. "|r"
      end
    end
  end
  return split
end

local styleOps = {
  ["<="] = function(v) return -math.huge, v + 0.000001 end,
  ["<"] = function(v) return -math.huge, v end,
  [">="] = function(v) return v, math.huge end,
  [">"] = function(v) return v + 0.000001, math.huge end,
}

-- Triggers whose timers the game can restrict, given as duration objects.
function Private.RestrictedTimerTrigger(data, index)
  local entry = data.triggers and data.triggers[index]
  local trigger = type(entry) == "table" and entry.trigger
  return type(trigger) == "table" and (trigger.type == "spell" or trigger.event == "Cast") or false
end

-- The trigger a text's timer token reads, or nil when it depends on which trigger is active.
local function TokenTrigger(data, text)
  local index = text:match("%%{?(%d+)%.[pt]}?")
  if index then return tonumber(index) end
  local mode = data.triggers and data.triggers.activeTriggerMode
  if type(mode) == "number" and mode >= 1 then return mode end
  if data.triggers and #data.triggers == 1 then return 1 end
  -- Otherwise the one trigger with a cooldown or cast timer, if only one has one.
  local found
  for triggerIndex = 1, #(data.triggers or {}) do
    if Private.RestrictedTimerTrigger(data, triggerIndex) then
      if found then return end
      found = triggerIndex
    end
  end
  return found
end

-- The text's own timer conditions, or nil. element: the sub text's settings
-- (nil for a Text display); index: its position in the sub elements.
function Private.DurationTextStyle(data, element, index)
  local colorProperty = index and ("sub." .. index .. ".text_color") or "color"
  local visibleProperty = index and ("sub." .. index .. ".text_visible")
  local text = element and element.text_text or data.displayText
  if type(text) ~= "string" then return end
  local timerTrigger = TokenTrigger(data, text)
  if not timerTrigger then return end
  -- Hiding only works when the remaining time is the whole text.
  local onlyTimer = (text:match("^%s*%%[%d%.]*p%s*$") or text:match("^%s*%%{[%d%.]*p}%s*$")) ~= nil
  local conditions = type(data.conditions) == "table" and data.conditions or {}
  -- Any other condition changing the same color or visibility keeps it in the condition engine.
  local useColor, useVisible = true, onlyTimer and visibleProperty ~= nil
  for _, condition in ipairs(conditions) do
    local check = condition.check
    local own = check and not condition.linked and check.variable == "expirationTime" and check.trigger == timerTrigger
      and styleOps[check.op] and tonumber(check.value)
    if not own then
      for _, change in ipairs(type(condition.changes) == "table" and condition.changes or {}) do
        if change.property == colorProperty then useColor = false end
        if change.property == visibleProperty then useVisible = false end
      end
    end
  end
  local style = {conds = {}, baseVisible = not element or element.text_visible ~= false}
  local key = {}
  for _, condition in ipairs(conditions) do
    local check = condition.check
    local range = check and not condition.linked and check.variable == "expirationTime" and check.trigger == timerTrigger
      and styleOps[check.op]
    local value = check and tonumber(check.value)
    if range and value and type(condition.changes) == "table" then
      local code, visible
      for _, change in ipairs(condition.changes) do
        if useColor and change.property == colorProperty and type(change.value) == "table" then
          local r, g, b = tonumber(change.value[1]) or 1, tonumber(change.value[2]) or 1, tonumber(change.value[3]) or 1
          code = ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
        elseif useVisible and change.property == visibleProperty then
          visible = change.value and true or false
        end
      end
      if code or visible ~= nil then
        local lo, hi = range(value)
        style.conds[#style.conds + 1] = {lo, hi, code, visible}
        key[#key + 1] = lo .. ":" .. hi .. ":" .. tostring(code) .. ":" .. tostring(visible)
        if visible ~= nil then style.usesVisible = true end
      end
    end
  end
  if #style.conds == 0 then return end
  style.key = tostring(style.baseVisible) .. "|" .. table.concat(key, "|")
  return style
end

-- A Remaining Time condition on a restricted timer that still works in
-- combat: it only changes Alpha, a main color, or a timer text's color or visibility.
local curveProperties = {"alpha$", "^color$", "text_color$", "barColor$", "foregroundColor$", "text_visible$"}
function Private.TimerConditionHandled(data, condition)
  local check = condition and condition.check
  if not (check and check.variable == "expirationTime" and not condition.linked and styleOps[check.op]
    and tonumber(check.value) and type(condition.changes) == "table" and #condition.changes > 0
    and Private.RestrictedTimerTrigger(data, check.trigger)) then
    return false
  end
  for _, change in ipairs(condition.changes) do
    local property = type(change.property) == "string" and change.property:gsub("^sub%.%d+%.", "")
    local ok = false
    for _, pattern in ipairs(curveProperties) do
      if property and property:match(pattern) then ok = true break end
    end
    if not ok then return false end
  end
  return true
end

function Private.GetDurationTextFormatter(format, threshold, precision, secondsOnly, style, textStyle)
  local Rules = styledRules[style]
  local key = format .. ":" .. threshold .. ":" .. precision .. ":" .. tostring(secondsOnly == true) .. ":" .. tostring(Rules and style)
    .. (textStyle and (":" .. textStyle.key) or "")
  local formatter = formatters[key]
  if formatter then return formatter end
  local rounding = Enum.NumericRuleFormatRounding
  -- ForeverAuras: whole seconds round up (99, the countdown's way) or down
  -- (0); 98 rounds to the nearest second, for the Number placeholder
  -- format's "Round" mode (issue #138). Nearest is in the client's
  -- enumeration (default of a breakpoint's rounding); Up stands in if not.
  local roundMode = format == 99 and rounding.Up or format == 98 and (rounding.Nearest or rounding.Up) or rounding.Down
  local rules
  if Rules then
    rules = Rules(threshold, precision, roundMode)
  else
    rules = {
      {threshold = 0, format = ""},
      {threshold = 0.000001, format = "%d", step = 1, rounding = roundMode},
    }
    if threshold > 0 then
      rules[2] = {threshold = 0.000001, format = "%." .. precision .. "f"}
      rules[#rules + 1] = {threshold = threshold, format = "%d", step = 1, rounding = roundMode}
    end
    if not secondsOnly then
      local minuteThreshold = math.max(60, threshold)
      if threshold == minuteThreshold then table.remove(rules) end
      rules[#rules + 1] = {
        threshold = minuteThreshold, format = "%d:%02d", step = 1,
        rounding = roundMode,
        components = {{div = 60}, {mod = 60}},
      }
    end
  end
  if textStyle then rules = Styled(rules, textStyle) end
  formatter = C_StringUtil.CreateNumericRuleFormatter()
  formatter:SetBreakpoints(rules)
  formatters[key] = formatter
  return formatter
end

-- secondsOnly: no minutes:seconds form (the "Number" placeholder format).
function Private.FormatDurationText(duration, total, format, threshold, precision, modRate, textStyle, style, secondsOnly)
  local formatter = Private.GetDurationTextFormatter(format, threshold, precision, secondsOnly, style, not total and textStyle or nil)
  local modifier = modRate == false and Enum.DurationTimeModifier.BaseTime or Enum.DurationTimeModifier.RealTime
  if total then return duration:FormatTotalDuration(formatter, modifier) end
  return duration:FormatRemainingDuration(formatter, modifier)
end
