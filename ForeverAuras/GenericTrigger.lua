-- Modified for ForeverAuras, 2026-09-30.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
--[[ GenericTrigger.lua
This file contains the generic trigger system. That is every trigger except the aura triggers.

It registers the GenericTrigger table for the generic trigger types and "custom" and has the following API:

Add(data)
Adds a display, creating all internal data structures for all triggers.

Delete(id)
Deletes all triggers for display id.

Rename(oldid, newid)
Updates all trigger information from oldid to newid.

LoadDisplay(id)
Loads all triggers of display id.

UnloadAll
Unloads all triggers.

UnloadDisplays(id)
Unloads all triggers of the display ids.

Modernize(data)
Modernizes all generic triggers in data.

#####################################################
# Helper functions mainly for the ForeverAuras Options #
#####################################################
GetOverlayInfo(data, triggernum)
Returns a table containing the names of all overlays

CanHaveTooltip(data, triggernum)
Returns the type of tooltip to show for the trigger.

GetNameAndIcon(data, triggernum)
Returns the name and icon to show in the options.

GetAdditionalProperties(data, triggernum)
Returns the a tooltip for the additional properties.

GetProgressSources(data, triggernum, outValues)
  Fills outValues with the potential progress sources

GetTriggerConditions(data, triggernum)
Returns potential conditions that this trigger provides.
]]--
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("GenericTrigger")
-- Lua APIs
local tinsert, tconcat, wipe = table.insert, table.concat, wipe
local tostring, pairs, type = tostring, pairs, type
local error = error
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo;

-- WoW APIs
local IsPlayerMoving = IsPlayerMoving

---@class WeakAuras
local WeakAuras = WeakAuras;
local L = WeakAuras.L;
local GenericTrigger = {};

local event_prototypes = Private.event_prototypes;

local timer = WeakAuras.timer;

local events = {}
local loaded_events = {}
local loaded_unit_events = {};
local watched_trigger_events = Private.watched_trigger_events
local delayTimerEvents = {}
local loaded_auras = {}; -- id to bool map
-- Which event and unit event lists each loaded aura was put into, so
-- UnloadDisplays can leave exactly those (see GenericTrigger.UnloadDisplays).
local loadedEventsByAura = {}

-- Local functions
local LoadEvent, HandleEvent, HandleUnitEvent, TestForTriState, TestForToggle, TestForLongString, TestForMultiSelect
local ConstructTest, ConstructFunction

local nameplateExists = {}

---@param unit UnitToken
---@param smart? boolean
---@return boolean unitExists
function WeakAuras.UnitExistsFixed(unit, smart)
  if #unit > 9 and unit:sub(1, 9) == "nameplate" then
    return nameplateExists[unit]
  end
  if smart and IsInRaid() then
    if unit:sub(1, 5) == "party" or unit == "player" or unit == "pet" then
      return false
    end
  end
  return UnitExists(unit) or UnitGUID(unit)
end

---@param input string
---@return string[] subStrings
function WeakAuras.split(input)
  input = input or "";
  local ret = {};
  local split, element = nil, nil
  split = input:find("[,%s]");
  while(split) do
    element, input = input:sub(1, split-1), input:sub(split+1);
    if(element ~= "") then
      tinsert(ret, element);
    end
    split = input:find("[,%s]");
  end
  if(input ~= "") then
    tinsert(ret, input);
  end
  return ret;
end

local function findFirstOf(input, words, start, plain)
  local startPos, endPos
  for _, w in ipairs(words) do
    local s, e = input:find(w, start, plain)
    if s and (not startPos or startPos > s) then
      startPos, endPos = s, e
    end
  end
  return startPos, endPos
end

---@param input string
---@return string[] subStrings
function Private.splitAtOr(input)
  input = input or ""
  local ret = {}
  local splitStart, splitEnd, element = nil, nil, nil
  local separators = { "|", " or "}
  splitStart, splitEnd = findFirstOf(input, separators, 1, true);
  while(splitStart) do
    element, input = input:sub(1, splitStart -1 ), input:sub(splitEnd + 1)
    if(element ~= "") then
      tinsert(ret, element)
    end
    splitStart, splitEnd = findFirstOf(input, separators, 1, true);
  end
  if(input ~= "") then
    tinsert(ret, input)
  end
  return ret;
end

function TestForTriState(trigger, arg)
  local name = arg.name;
  local test;
  if(trigger["use_"..name] == false) then
    test = "(not "..name..")";
  elseif(trigger["use_"..name]) then
    if(arg.test) then
      test = "("..arg.test:format(trigger[name])..")";
    else
      test = name;
    end
  end
  return test;
end

function TestForToggle(trigger, arg)
  local name = arg.name;
  local test;
  if(trigger["use_"..name]) then
    if(arg.test) then
      test = "("..arg.test:format(trigger[name])..")";
    else
      test = name;
    end
  end
  return test;
end

function TestForLongString(trigger, arg)
  local name = arg.name;
  local test;
  local needle = trigger[name]
  local caseInsensitive = arg.canBeCaseInsensitive and trigger[name .. "_caseInsensitive"]
  if(trigger[name.."_operator"] == "==") then
    if caseInsensitive then
      test = ("(%s and not issecretvalue(%s) and (%s):lower() == (%s):lower())"):format(name, name, name, Private.QuotedString(needle))
    else
      test = ("(not issecretvalue(%s) and %s == %s)"):format(name, name, Private.QuotedString(needle))
    end
  elseif(trigger[name.."_operator"] == "find('%s')") then
    if caseInsensitive then
      test = ("(%s and not issecretvalue(%s) and %s:lower():find((%s):lower(), 1, true))"):format(name, name, name, Private.QuotedString(needle))
    else
      test = ("(%s and not issecretvalue(%s) and %s:find(%s, 1, true))"):format(name, name, name, Private.QuotedString(needle))
    end
  elseif(trigger[name.."_operator"] == "match('%s')") then
    if caseInsensitive then
      test = ("(%s and not issecretvalue(%s) and %s:lower():match((%s):lower()))"):format(name, name, name, Private.QuotedString(needle))
    else
      test = ("(%s and not issecretvalue(%s) and %s:match(%s))"):format(name, name, name, Private.QuotedString(needle))
    end
  end
  return test;
end

function TestForMultiSelect(trigger, arg)
  local name = arg.name;
  local test;
  if(trigger["use_"..name] == false) then -- multi selection
    test = "(";
    local any = false;
    if trigger[name] and trigger[name].multi then
      for value, _ in pairs(trigger[name].multi) do
        if not arg.test then
          test = test..name.."=="..(tonumber(value) or ("[["..value.."]]")).." or ";
        else
          test = test..arg.test:format(tonumber(value) or ("[["..value.."]]")).." or ";
        end
        any = true;
      end
    end
    if(any) then
      test = test:sub(1, -5);
    else
      test = "(false";
    end
    test = test..")";
  elseif(trigger["use_"..name]) then -- single selection
    local value = trigger[name] and trigger[name].single;
    if (not value) then
      test = "false";
      return test;
    end
    if not arg.test then
      test = trigger[name].single and "("..name.."=="..(tonumber(value) or ("[["..value.."]]"))..")";
    else
      test = trigger[name].single and "("..arg.test:format(tonumber(value) or ("[["..value.."]]"))..")";
    end
  end
  return test;
end

local function singleTest(arg, trigger, name, value, operator, use_exact)
  local number = tonumber(value)
  if(arg.type == "tristate") then
    return TestForTriState(trigger, arg);
  elseif(arg.type == "multiselect") then
    return TestForMultiSelect(trigger, arg);
  elseif(arg.type == "toggle") then
    return TestForToggle(trigger, arg);
  elseif (arg.type == "spell" or arg.type == "item") then
    if arg.test then
      if arg.showExactOption then
        return "("..arg.test:format(value, tostring(use_exact) or "false") ..")";
      else
        return "("..arg.test:format(value)..")";
      end
    else
      return "(".. name .." and not issecretvalue(" .. name .. ") and "..name.."==" ..(number or ("\""..(tostring(value) or "").."\""))..")";
    end
  elseif(arg.test) then
    return "("..arg.test:format(tostring(value) or "")..")";
  elseif(arg.type == "longstring" and operator) then
    return TestForLongString(trigger, arg);
  elseif (arg.type == "string" or arg.type == "select") then
    return "(".. name .." and not issecretvalue(" .. name .. ") and "..name.."==" ..(number or ("\""..(tostring(value) or "").."\""))..")";
  elseif (arg.type == "number") then
    return "(".. name .." and not issecretvalue(" .. name ..") and "..name..(operator or "==")..(number or 0) ..")";
  else
    -- Should be unused
    return "(".. name .." and not issecretvalue(" .. name ..") and "..name..(operator or "==")..(number or ("\""..(tostring(value) or 0).."\""))..")";
  end
end

function ConstructTest(trigger, arg, preambleGroups)
  local test
  local preamble
  local name = arg.name;
  if arg.filterEnable and not (arg.filterEnable(trigger) and trigger["use_" .. name]) then
    return nil
  end

  if arg.preamble then
    if not arg.preambleGroup or not preambleGroups[arg.preambleGroup] then
      preamble = arg.preamble:format(trigger[name] or "")
    end
    if arg.preambleGroup then
      preambleGroups[arg.preambleGroup] = true
    end
  end

  if arg.hidden
    or arg.type == "tristate"
    or arg.type == "toggle"
    or (arg.type == "multiselect" and trigger["use_"..name] ~= nil)
    or ((trigger["use_"..name] or arg.required) and trigger[name])
  then
    if arg.multiEntry then
      if type(trigger[name]) == "table" and #trigger[name] > 0 then
        test = ""
        for i, value in ipairs(trigger[name]) do
          local operator = name and type(trigger[name.."_operator"]) == "table" and trigger[name.."_operator"][i]
          local use_exact = name and type(trigger["use_exact_" .. name]) == "table" and trigger["use_exact_" .. name][i]

          if arg.multiEntry.operator == "preamble" then
            preamble = preamble and (preamble .. "\n") or ""
            preamble = preamble .. arg.multiEntry.preambleAdd:format(value)
          else
            local single = singleTest(arg, trigger, name, value, operator, use_exact)
            if single then
              if test ~= "" then
                test = test .. arg.multiEntry.operator
              end
              test = test .. single
            end
          end
        end

        if arg.multiEntry.operator == "preamble" then
          test = arg.test
        end

        if test == "" then
          test = nil
        else
          test = "(" .. test .. ")"
        end
      end
    else
      local value = trigger[name]
      local operator = name and trigger[name.."_operator"]
      local use_exact = name and trigger["use_exact_" .. name]
      test = singleTest(arg, trigger, name, value, operator, use_exact)
    end
  end

  if not test or test == "(true)" then
    return nil, preamble
  end

  return test, preamble
end

function ConstructFunction(prototype, trigger)
  if (prototype.triggerFunction) then
    return prototype.triggerFunction(trigger);
  end

  local input;
  if (prototype.statesParameter) then
    if prototype.countEvents then
      input = {"state", "counter", "event"};
    else
      input = {"state", "event"};
    end
  else
    if prototype.countEvents then
      input = {"counter", "event"};
    else
      input = {"event"};
    end
  end

  local required = {};
  local tests = {};
  local debug = {};
  local store = {};
  local init;
  local preambles = "\n"
  local orConjunctionGroups = {}
  local preambleGroups = {}
  if(prototype.init) then
    init = prototype.init(trigger);
  else
    init = "";
  end
  for index, arg in pairs(prototype.args) do
    local enable = arg.type ~= "description";
    if(type(arg.enable) == "function") then
      enable = arg.enable(trigger);
    elseif type(arg.enable) == "boolean" then
      enable = arg.enable
    end
    if(enable) then
      local name = arg.name;
      if not(arg.name or arg.hidden) then
        tinsert(input, "_");
      else
        if(arg.init == "arg") then
          tinsert(input, name);
        elseif(arg.init) then
          init = init.."local "..name.." = "..arg.init.."\n";
        end
        if (arg.store) then
          tinsert(store, name);
        end
        local test, preamble = ConstructTest(trigger, arg, preambleGroups);
        if (test) then
          if(arg.required) then
            tinsert(required, test);
          else
            if arg.orConjunctionGroup then
              orConjunctionGroups[arg.orConjunctionGroup] = orConjunctionGroups[arg.orConjunctionGroup] or {}
              tinsert(orConjunctionGroups[arg.orConjunctionGroup], test)
            else
              tinsert(tests, test);
            end
          end
          if(arg.debug) then
            tinsert(debug, arg.debug:format(trigger[name]));
          end
        end
        if (preamble) then
          preambles = preambles .. preamble .. "\n"
        end
      end
    end
  end

  for _, orConjunctionGroup in pairs(orConjunctionGroups) do
    tinsert(tests, "("..table.concat(orConjunctionGroup, " or ")..")")
  end

  local ret = {preambles .. "return function("..tconcat(input, ", ")..")\n"}
  if init then
    table.insert(ret, init)
  end
  if #debug > 0 then
    table.insert(ret, tconcat(debug, "\n") or "")
  end

  table.insert(ret, "if("..((#required > 0) and tconcat(required, " and ").." and " or ""))
  table.insert(ret, #tests > 0 and tconcat(tests, " and ") or "true")
  table.insert(ret, ") then\n")
  if(#debug > 0) then
    table.insert("print('ret: true');\n")
  end

  if (prototype.statesParameter == "all") then
    table.insert(ret, "  state[cloneId] = state[cloneId] or {}\n")
    table.insert(ret, "  state = state[cloneId]\n")
    table.insert(ret, "  state.changed = true\n")
  end

  if prototype.countEvents then
    table.insert(ret, "  local count = counter:GetNext()\n")
    if trigger.use_count and type(trigger.count) == "string" and trigger.count ~= "" then
      table.insert(ret, "  local match = counter:Match()")
      table.insert(ret, "  if not match then return false end\n")
    end
    table.insert(ret, "  state.count = count\n")
    table.insert(ret, "  state.changed = true\n")
  end

  for _, v in ipairs(store) do
    table.insert(ret, "    if hasanysecretvalues(" .. v .. ", state." .. v .. ") or (state." .. v .. " ~= " .. v .. ") then\n")
    table.insert(ret, "      state." .. v .. " = " .. v .. "\n")
    table.insert(ret, "      state.changed = true\n")
    table.insert(ret, "    end\n")
  end
  table.insert(ret, "return true else return false end end")

  return table.concat(ret);
end

function Private.EndEvent(state)
  if state then
    if (state.show ~= false and state.show ~= nil) then
      state.show = false;
      state.changed = true;
    end
    return state.changed;
  else
    return false
  end
end

local function RunOverlayFuncs(event, state, id, errorHandler)
  state.additionalProgress = state.additionalProgress or {};
  local changed = false;
  for i, overlayFunc in ipairs(event.overlayFuncs) do
    state.additionalProgress[i] = state.additionalProgress[i] or {};
    local additionalProgress = state.additionalProgress[i];
    local underlay = event.overlayUnderlays and event.overlayUnderlays[i] == true or false
    if additionalProgress.underlay ~= underlay then
      additionalProgress.underlay = underlay
      changed = true
    end
    local ok, a, b, c, d, e = xpcall(overlayFunc, errorHandler or Private.GetErrorHandlerId(id, L["Overlay %s"]:format(i)), event.trigger, state);
    if (not ok) then
      additionalProgress.min = nil;
      additionalProgress.max = nil;
      additionalProgress.direction = nil;
      additionalProgress.width = nil;
      additionalProgress.offset = nil;
      additionalProgress.durationObject = nil;
      additionalProgress.durationObjectUseRemaining = nil;
    elseif (type(a) == "string") then
      if hasanysecretvalues(additionalProgress.direction, a) or additionalProgress.direction ~= a then
        additionalProgress.direction = a;
        changed = true;
      end
      if hasanysecretvalues(additionalProgress.width, b) or additionalProgress.width ~= b then
        additionalProgress.width = b;
        changed = true;
      end
      if hasanysecretvalues(additionalProgress.offset, c) or additionalProgress.offset ~= c then
        additionalProgress.offset = c;
        changed = true;
      end
      if (additionalProgress.durationObject ~= d) then
        additionalProgress.durationObject = d;
        changed = true;
      end
      if (additionalProgress.durationObjectUseRemaining ~= e) then
        additionalProgress.durationObjectUseRemaining = e;
        changed = true;
      end
      additionalProgress.min = nil;
      additionalProgress.max = nil;
    else
      if hasanysecretvalues(additionalProgress.min, a) or additionalProgress.min ~= a then
        additionalProgress.min = a;
        changed = true;
      end
      if hasanysecretvalues(additionalProgress.max, b) or additionalProgress.max ~= b then
        additionalProgress.max = b;
        changed = true;
      end
      if additionalProgress.direction then
        changed = true
      end
      if (additionalProgress.durationObject ~= c) then
        additionalProgress.durationObject = c;
        changed = true;
      end
      if (additionalProgress.durationObjectUseRemaining ~= d) then
        additionalProgress.durationObjectUseRemaining = d;
        changed = true;
      end
      additionalProgress.direction = nil;
      additionalProgress.width = nil;
      additionalProgress.offset = nil;
    end

  end
  state.changed = changed or state.changed;
end

local function callFunctionForActivateEvent(func, trigger, state, property, errorHandler)
  if not func then
    return
  end
  local ok, value = xpcall(func, errorHandler, trigger)
  if ok then
    if hasanysecretvalues(state[property], value) or state[property] ~= value then
      state[property] = value
      state.changed = true
    end
  end
end

---@type fun(id, triggernum, data, state, errorHandler)
---@return state
function Private.ActivateEvent(id, triggernum, data, state, errorHandler)
  -- ForeverAuras.PurgeSecrets(state)

  local changed = state.changed or false;
  if (state.show ~= true) then
    state.show = true;
    changed = true;
  end
  if (data.duration) then
    local expirationTime = GetTime() + data.duration;
    if (state.expirationTime ~= expirationTime) then
      state.expirationTime = expirationTime;
      changed = true;
    end
    if (state.duration ~= data.duration) then
      state.duration = data.duration;
      changed = true;
    end
    if (state.progressType ~= "timed") then
      state.progressType = "timed";
      changed = true;
    end
    local autoHide = data.automaticAutoHide;
    if (state.value or state.total or state.inverse or state.autoHide ~= autoHide) then
      changed = true;
    end
    state.value = nil;
    state.total = nil;
    state.inverse = nil;
    state.autoHide = autoHide;
  elseif (data.durationFunc) then
    local ok, arg1, arg2, arg3, inverse = xpcall(data.durationFunc, errorHandler or Private.GetErrorHandlerId(id, L["Duration Function"]), data.trigger);
    arg1 = ok and type(arg1) == "number" and arg1 or 0;
    arg2 = ok and type(arg2) == "number" and arg2 or 0;

    if (state.inverse ~= inverse) then
      state.inverse = inverse;
      changed = true;
    end

    if (arg3) then
      if (state.progressType ~= "static") then
        state.progressType = "static";
        changed = true;
      end
      if (state.duration) then
        state.duration = nil;
        changed = true;
      end
      if (state.expirationTime) then
        state.expirationTime = nil;
        changed = true;
      end

      local autoHide = nil;
      if (state.autoHide ~= autoHide) then
        changed = true;
        state.autoHide = autoHide;
      end

      if (state.value ~= arg1) then
        state.value = arg1;
        changed = true;
      end
      if (state.total ~= arg2) then
        state.total = arg2;
        changed = true;
      end
    else
      if (state.progressType ~= "timed") then
        state.progressType = "timed";
        changed = true;
      end
      if (state.duration ~= arg1) then
        state.duration = arg1;
      end
      -- The Icon's SetCooldown requires that the **startTime** is positive, so ensure that
      -- the expirationTime is bigger than the duration
      if arg2 <= arg1 then
        arg2 = arg1
      end
      if (state.expirationTime ~= arg2) then
        state.expirationTime = arg2;
        changed = true;
      end
      local autoHide = data.automaticAutoHide and arg1 > 0.01;
      if (state.autoHide ~= autoHide) then
        changed = true;
        state.autoHide = autoHide;
      end
      if (state.value or state.total) then
        changed = true;
      end
      state.value = nil;
      state.total = nil;
    end
  end

  callFunctionForActivateEvent(data.nameFunc, data.trigger, state, "name", errorHandler or Private.GetErrorHandlerId(id, L["Name Function"]))
  callFunctionForActivateEvent(data.iconFunc, data.trigger, state, "icon", errorHandler or Private.GetErrorHandlerId(id, L["Icon Function"]))
  callFunctionForActivateEvent(data.textureFunc, data.trigger, state, "texture", errorHandler or Private.GetErrorHandlerId(id, L["Texture Function"]))
  callFunctionForActivateEvent(data.stacksFunc, data.trigger, state, "stacks", errorHandler or Private.GetErrorHandlerId(id, L["Stacks Function"]))

  if (data.overlayFuncs) then
    RunOverlayFuncs(data, state, id, errorHandler);
  end

  state.changed = state.changed or changed;

  return state.changed;
end

local function ignoreErrorHandler()

end

-- The error context of each trigger number, made once: formatting it on
-- every trigger run made a string per run.
local triggerContexts = setmetatable({}, {__index = function(t, triggernum)
  local context = L["Trigger %s"]:format(triggernum)
  t[triggernum] = context
  return context
end})

local function RunTriggerFunc(allStates, data, id, triggernum, event, arg1, arg2, ...)
  local optionsEvent = event == "OPTIONS";
  -- Native CDM callbacks and filter timers dispatch internally even while the
  -- editor pauses normal game events. Only OPTIONS may replace its sample states.
  if not optionsEvent and data.prototype and data.prototype.cooldownViewerProgress
      and WeakAuras.IsOptionsOpen() then return false end
  local errorHandler = (optionsEvent and data.ignoreOptionsEventErrors) and ignoreErrorHandler or Private.GetErrorHandlerId(id, triggerContexts[triggernum])
  local updateTriggerState = false;

  local unitForUnitTrigger
  local cloneIdForUnitTrigger

  if(data.triggerFunc) then
    local untriggerCheck = false;
    if (data.statesParameter == "full") then
      local ok, returnValue
      if data.counter then
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, allStates, data.counter, event, arg1, arg2, ...);
      else
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, allStates, event, arg1, arg2, ...);
      end
      if (ok and (returnValue or (returnValue ~= false and allStates:IsChanged()))) then
        updateTriggerState = true;
      end
      allStates:SetChanged()
      for key, state in pairs(allStates) do
        if (type(state) ~= "table") then
          errorHandler(string.format(L["All States table contains a non table at key: '%s'."], key))
          wipe(allStates)
          return
        elseif issecrettable(state) then
          errorHandler(string.format(L["State at key: '%s' is a secret table."], key))
          wipe(allStates)
          return
        end
      end
      if data.fixUpShowNil then
        for _, state in pairs(allStates) do
          if state.show == nil then
            state.show = false
          end
        end
      end
    elseif (data.statesParameter == "all") then
      local ok, returnValue
      if data.counter then
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, allStates, data.counter, event, arg1, arg2, ...);
      else
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, allStates, event, arg1, arg2, ...);
      end
      if( (ok and returnValue) or optionsEvent) then
        for id, state in pairs(allStates) do
          if (state.changed) then
            if (Private.ActivateEvent(id, triggernum, data, state)) then
              updateTriggerState = true;
            end
          end
        end
      else
        untriggerCheck = true;
      end
    elseif (data.statesParameter == "unit") then
      if arg1 then
        if Private.multiUnitUnits[data.trigger.unit] then
          if data.trigger.unit == "group" and IsInRaid() and Private.multiUnitUnits.party[arg1] then
            return
          end

          unitForUnitTrigger = arg1
          cloneIdForUnitTrigger = arg1
        else
          unitForUnitTrigger = data.trigger.unit
          cloneIdForUnitTrigger = ""
        end
        allStates[cloneIdForUnitTrigger] = allStates[cloneIdForUnitTrigger] or {};
        local state = allStates[cloneIdForUnitTrigger];
        local ok, returnValue
        if data.counter then
          ok, returnValue = xpcall(data.triggerFunc, errorHandler, state, data.counter, event, unitForUnitTrigger, arg1, arg2, ...);
        else
          ok, returnValue = xpcall(data.triggerFunc, errorHandler, state, event, unitForUnitTrigger, arg1, arg2, ...);
        end
        if (ok and returnValue) or optionsEvent then
          if(Private.ActivateEvent(id, triggernum, data, state)) then
            updateTriggerState = true;
          end
        else
          untriggerCheck = true;
        end
      end
    elseif (data.statesParameter == "one") then
      allStates[""] = allStates[""] or {};
      local state = allStates[""];
      local ok, returnValue
      if data.counter then
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, state, data.counter, event, arg1, arg2, ...);
      else
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, state, event, arg1, arg2, ...);
      end
      if (ok and returnValue) or optionsEvent then
        if(Private.ActivateEvent(id, triggernum, data, state, (optionsEvent and data.ignoreOptionsEventErrors) and ignoreErrorHandler or nil)) then
          updateTriggerState = true;
        end
      else
        untriggerCheck = true;
      end
    else
      local ok, returnValue
      if data.counter then
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, data.counter, event, arg1, arg2, ...);
      else
        ok, returnValue = xpcall(data.triggerFunc, errorHandler, event, arg1, arg2, ...);
      end
      if (ok and returnValue) or optionsEvent then
        allStates[""] = allStates[""] or {};
        local state = allStates[""];
        if(Private.ActivateEvent(id, triggernum, data, state, (optionsEvent and data.ignoreOptionsEventErrors) and ignoreErrorHandler or nil)) then
          updateTriggerState = true;
        end
      else
        untriggerCheck = true;
      end
    end
    if (untriggerCheck and not optionsEvent) then
      errorHandler = (optionsEvent and data.ignoreOptionsEventErrors) and ignoreErrorHandler or Private.GetErrorHandlerId(id, L["Untrigger %s"]:format(triggernum))
      if (data.statesParameter == "all") then
        if data.untriggerFunc then
          local ok, returnValue = xpcall(data.untriggerFunc, errorHandler, allStates, event, arg1, arg2, ...);
          if ok and returnValue then
            for id, state in pairs(allStates) do
              if (state.changed) then
                if (Private.EndEvent(state)) then
                  updateTriggerState = true;
                end
              end
            end
          end
        end
      elseif data.statesParameter == "unit" then
        if data.untriggerFunc then
          if arg1 then
            local state = allStates[cloneIdForUnitTrigger]
            if state then
              local ok, returnValue =  xpcall(data.untriggerFunc, errorHandler, state, event, unitForUnitTrigger, arg1, arg2, ...);
              if ok and returnValue then
                if (Private.EndEvent(state)) then
                  updateTriggerState = true;
                end
              end
            end
          end
        end
        if not updateTriggerState and not allStates[cloneIdForUnitTrigger].show then
          -- We added this state automatically, but the trigger didn't end up using it,
          -- so remove it again
          allStates[cloneIdForUnitTrigger] = nil
        end
      elseif (data.statesParameter == "one") then
        allStates[""] = allStates[""] or {};
        local state = allStates[""];
        if data.untriggerFunc then
          local ok, returnValue = xpcall(data.untriggerFunc, errorHandler, state, event, arg1, arg2, ...);
          if (ok and returnValue) then
            if (Private.EndEvent(state)) then
              updateTriggerState = true;
            end
          end
        end
      else
        if data.untriggerFunc then
          local ok, returnValue = xpcall(data.untriggerFunc, errorHandler, event, arg1, arg2, ...);
          if ok and returnValue then
            allStates[""] = allStates[""] or {};
            local state = allStates[""];
            if(Private.EndEvent(state)) then
              updateTriggerState = true;
            end
          end
        end
      end
    end
  end
  if updateTriggerState and watched_trigger_events[id] and watched_trigger_events[id][triggernum] then
    -- if this trigger's updates are requested to be sent into one of the Aura's custom triggers
    Private.AddToWatchedTriggerDelay(id, triggernum)
  end
  return updateTriggerState;
end

---ScanEvents may receive composed events like `event:spellId`
---For system profiling we want extract the event
---@param composedEvent string
---@return string
local function getGameEventFromComposedEvent(composedEvent)
  local separatorPosition = composedEvent:find(":", 1, true)
  return separatorPosition == nil and composedEvent or composedEvent:sub(1, separatorPosition - 1)
end

local scannerFrame = CreateFrame("Frame")
scannerFrame.queue = {}
scannerFrame:Hide()
scannerFrame:SetScript("OnUpdate", function(self)
  local todo = self.queue
  self.queue = {}
  for _, event in ipairs(todo) do
    event.func(unpack(event.args))
  end
  -- there's a chance that a joker dispatched an event in in trigger code,
  -- so the queue might already be populated
  -- in that case, we'll process next frame by declining to hide
  if #self.queue == 0 then
    self:Hide()
  end
end)

function scannerFrame:Queue(func, ...)
  tinsert(self.queue, {func = func, args = {...}})
  self:Show()
end

function Private.ScanEventsByID(event, id, ...)
  if loaded_events[event] then
    Private.ScanEvents(event, id, ...)
  end
  local eventWithID = event .. ":" .. id
  if loaded_events[eventWithID] then
    Private.ScanEvents(eventWithID, id, ...)
  end
end

function WeakAuras.ScanEventsByID(event, id, ...)
  scannerFrame:Queue(Private.ScanEventsByID, event, id, ...)
end

---@param event string
---@param arg1? any
---@param arg2? any
---@param ... any
function Private.ScanEvents(event, arg1, arg2, ...)
  local system = getGameEventFromComposedEvent(event)
  Private.StartProfileSystem("generictrigger " .. system)
  local event_list = loaded_events[event];
  if (not event_list) then
    Private.StopProfileSystem("generictrigger " .. system)
    return
  end
  Private.ScanEventsInternal(event_list, event, arg1, arg2, ...);
  Private.StopProfileSystem("generictrigger " .. system)
end

function WeakAuras.ScanEvents(event, arg1, arg2, ...)
  if type(event) ~= "string" then
    return
  end
  scannerFrame:Queue(Private.ScanEvents, event, arg1, arg2, ...)
end

-- One reused table per nesting depth for the CDM triggers of a dispatch.
local cdmBatchPool, cdmBatchDepth = {}, 0
local function BeginCDMBatch()
  local previous = Private.cdmScanBatch
  cdmBatchDepth = cdmBatchDepth + 1
  local batch = cdmBatchPool[cdmBatchDepth]
  if batch then wipe(batch) else batch = {}; cdmBatchPool[cdmBatchDepth] = batch end
  Private.cdmScanBatch = batch
  return previous
end

local function EndCDMBatch(previous)
  cdmBatchDepth = math.max(0, cdmBatchDepth - 1)
  Private.cdmScanBatch = previous
end

---@param event string
---@param unit UnitToken
---@param ... any
function Private.ScanUnitEvents(event, unit, ...)
  -- All CDM triggers in one synchronous dispatch share catalog/frame discovery.
  -- Restore the outer snapshot for nested scans; later events always get fresh frames.
  local previousCDMBatch = BeginCDMBatch()
  Private.StartProfileSystem("generictrigger " .. event .. " " .. unit)
  local unit_list = loaded_unit_events[unit]
  local inRaid = IsInRaid()
  if unit_list then
    local event_list = unit_list[event]
    if event_list then
      for id, triggers in pairs(event_list) do
        Private.StartProfileAura(id);
        Private.ActivateAuraEnvironment(id);
        local updateTriggerState = false;
        for triggernum, data in pairs(triggers) do
          if inRaid and Private.multiUnitUnits.party[unit]
          and events[id][triggernum].ignorePartyUnitsInRaid
          and events[id][triggernum].ignorePartyUnitsInRaid[event]
          then
            -- If the unit is a group unit, we don't want to run the trigger for every party member
          else
            local delay = GenericTrigger.GetDelay(data)
            if delay == 0 then
              local allStates = WeakAuras.GetTriggerStateForTrigger(id, triggernum);
              if (RunTriggerFunc(allStates, data, id, triggernum, event, unit, ...)) then
                updateTriggerState = true;
              end
            else
              Private.RunTriggerFuncWithDelay(delay, id, triggernum, data, event, unit, ...)
            end
          end
        end
        if (updateTriggerState) then
          Private.UpdatedTriggerState(id);
        end
        Private.StopProfileAura(id);
        Private.ActivateAuraEnvironment(nil);
      end
    end
  end
  Private.StopProfileSystem("generictrigger " .. event .. " " .. unit)
  EndCDMBatch(previousCDMBatch)
end

function WeakAuras.ScanUnitEvents(event, unit, ...)
  scannerFrame:Queue(Private.ScanUnitEvents, event, unit, ...)
end

-- Range checks need no answer more often than this.
local rangeThrottles = {["Range Check"] = 0.1, ["Spell in Range"] = 0.1}

local function checkOnUpdateThrottle(data)
  if data.onUpdateThrottle then
    local now = GetTime()
    if not data.lastOnUpdate or (now - data.lastOnUpdate) >= data.onUpdateThrottle then
      data.lastOnUpdate = now
      return true
    end
    return false
  end
  return true
end

---@private
---@param event_list table<string>
---@param event string
---@param arg1? any
---@param arg2? any
---@param ... any
function Private.ScanEventsInternal(event_list, event, arg1, arg2, ... )
  -- All CDM triggers in one synchronous dispatch share catalog/frame discovery.
  -- Restore the outer snapshot for nested scans; later events always get fresh frames.
  local previousCDMBatch = BeginCDMBatch()
  for id, triggers in pairs(event_list) do
    Private.StartProfileAura(id);
    Private.ActivateAuraEnvironment(id);
    local updateTriggerState = false;
    for triggernum, data in pairs(triggers) do
      if event == "FRAME_UPDATE" then
        if checkOnUpdateThrottle(data) then
          local allStates = WeakAuras.GetTriggerStateForTrigger(id, triggernum);
          if (RunTriggerFunc(allStates, data, id, triggernum, event, arg1, arg2, ...)) then
            updateTriggerState = true
          end
        end
      else
        local delay = GenericTrigger.GetDelay(data)
        if delay == 0 then
          local allStates = WeakAuras.GetTriggerStateForTrigger(id, triggernum);
          -- Profiling breakdown: trigger functions versus the display update below.
          Private.StartProfileSystem("trigger functions")
          if (RunTriggerFunc(allStates, data, id, triggernum, event, arg1, arg2, ...)) then
            updateTriggerState = true
          end
          Private.StopProfileSystem("trigger functions")
        else
          Private.RunTriggerFuncWithDelay(delay, id, triggernum, data, event, arg1, arg2, ...)
        end
      end
    end
    if (updateTriggerState) then
      Private.StartProfileSystem("display updates")
      Private.UpdatedTriggerState(id);
      Private.StopProfileSystem("display updates")
    end
    Private.StopProfileAura(id);
    Private.ActivateAuraEnvironment(nil);
  end
  EndCDMBatch(previousCDMBatch)
end

function WeakAuras.ScanEventsInternal(event_list, event, arg1, arg2, ... )
  scannerFrame:Queue(Private.ScanEventsInternal, event_list, event, arg1, arg2, ...)
end

do
  local function RunTriggerFuncForDelay(id, triggernum, data, event, ...)
    Private.StartProfileAura(id)
    Private.ActivateAuraEnvironment(id)
    local allStates = WeakAuras.GetTriggerStateForTrigger(id, triggernum)
    if (RunTriggerFunc(allStates, data, id, triggernum, event, ...)) then
      Private.UpdatedTriggerState(id)
    end
    Private.StopProfileAura(id)
    Private.ActivateAuraEnvironment(nil)
    -- clear expired timers
    for i, t in ipairs_reverse(delayTimerEvents[id][triggernum]) do
      if t.ends <= GetTime() then
        table.remove(delayTimerEvents[id][triggernum], i)
      end
    end
  end

  ---@type fun(delay, id, triggernum, data, event, ...)
  function Private.RunTriggerFuncWithDelay(delay, id, triggernum, data, event, ...)
    delayTimerEvents[id] = delayTimerEvents[id] or {}
    delayTimerEvents[id][triggernum] = delayTimerEvents[id][triggernum] or {}
    local timerId = timer:ScheduleTimer(RunTriggerFuncForDelay, delay, id, triggernum, data, event, ...)
    tinsert(delayTimerEvents[id][triggernum], timerId)
  end
end

---@type fun(id)
function Private.CancelDelayedTrigger(id)
  if delayTimerEvents[id] then
    for triggernum, timers in pairs(delayTimerEvents[id]) do
      for _, timerId in ipairs(timers) do
        timer:CancelTimer(timerId)
      end
    end
    delayTimerEvents[id] = nil
  end
end

---@type fun()
function Private.CancelAllDelayedTriggers()
  for id in pairs(delayTimerEvents) do
    Private.CancelDelayedTrigger(id)
  end
end

---@type fun(id, watchedTriggernums)
function Private.ScanEventsWatchedTrigger(id, watchedTriggernums)
  if #watchedTriggernums == 0 then return end
  Private.StartProfileAura(id);
  Private.ActivateAuraEnvironment(id);
  local updateTriggerState = false

  for _, watchedTrigger in ipairs(watchedTriggernums) do
    if watched_trigger_events[id] and watched_trigger_events[id][watchedTrigger] then
      local updatedTriggerStates = WeakAuras.GetTriggerStateForTrigger(id, watchedTrigger)
      for observerTrigger in pairs(watched_trigger_events[id][watchedTrigger]) do
        local data = events and events[id] and events[id][observerTrigger]
        local allstates = WeakAuras.GetTriggerStateForTrigger(id, observerTrigger)
        if data and allstates and updatedTriggerStates then
          if RunTriggerFunc(allstates, data, id, observerTrigger, "TRIGGER", watchedTrigger, updatedTriggerStates) then
            updateTriggerState = true
          end
        end
      end
    end
  end
  if (updateTriggerState) then
    Private.UpdatedTriggerState(id)
  end
  Private.StopProfileAura(id)
  Private.ActivateAuraEnvironment(nil)
end

---@type fun(data: auraData, triggernum: number) : "timed"|boolean, boolean?
local function ProgressType(data, triggernum)
  local trigger = data.triggers[triggernum].trigger

  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    if prototype.progressType then
      local progressType = prototype.progressType
      if type(progressType) == "function" then
        progressType = progressType(trigger)
      end
      return progressType, prototype.useModRate
    elseif prototype.timedrequired then
      return "timed"
    end
  elseif (trigger.type == "custom") then
    if trigger.custom_type == "event" and trigger.custom_hide == "timed" and trigger.duration then
      return "timed";
    elseif (trigger.customDuration and trigger.customDuration ~= "") then
      return "timed";
    elseif (trigger.custom_type == "stateupdate") then
      return false
    end
  end
  return false
end

---@type fun(data: auraData, triggernum: integer, state: state, eventData: table)
local function AddFakeInformation(data, triggernum, state, eventData)
  state.autoHide = false
  if eventData.prototype and eventData.prototype.cooldownViewerProgress then return end
  if ProgressType(data, triggernum) == "timed" and state.expirationTime == nil then
    state.progressType = "timed"
  end
  -- A readable cooldown shown from its duration object (spell cooldown
  -- trigger) previews with the same looping sample timer as the timed form.
  if state.progressType == "durationObject" and type(state.expirationTime) == "number"
  and not issecretvalue(state.expirationTime) then
    state.progressType = "timed"
    state.durationObject = nil
  end
  if state.progressType == "timed" then
    local expirationTime = state.expirationTime
    if expirationTime and not issecretvalue(expirationTime) and type(expirationTime) == "number" and expirationTime ~= math.huge and expirationTime > GetTime() then
      return
    end
    state.progressType = "timed"
    state.expirationTime = GetTime() + 7
    state.duration = 7
  end
  if eventData.prototype and eventData.prototype.GetNameAndIcon then
    local name, icon = eventData.prototype.GetNameAndIcon(eventData.trigger)
    if state.name == nil then
      state.name = name
    end
    if state.icon == nil then
      state.icon = icon
    end
  end
end

---@type fun(id: auraId, triggernum: integer)
function GenericTrigger.CreateFakeStates(id, triggernum)
  local data = WeakAuras.GetData(id)
  local eventData = events[id][triggernum]

  Private.ActivateAuraEnvironment(id);
  local allStates = WeakAuras.GetTriggerStateForTrigger(id, triggernum);

  local arg1
  if eventData.statesParameter == "unit" then
    local unit = eventData.trigger.unit
    if Private.multiUnitUnits[unit] then
      arg1 = next(Private.multiUnitUnits[unit])
    else
      arg1 = unit
    end
  end

  RunTriggerFunc(allStates, eventData, id, triggernum, "OPTIONS", arg1)

  local shown = 0
  for id, state in pairs(allStates) do
    if state.show then
      shown = shown + 1
    end

    AddFakeInformation(data, triggernum, state, eventData)
  end

  if shown == 0 then
    local state = {}
    GenericTrigger.CreateFallbackState(data, triggernum, state)
    allStates[""] = state

    AddFakeInformation(data, triggernum, state, eventData)
  end

  Private.ActivateAuraEnvironment(nil);
end

function GenericTrigger.ScanWithFakeEvent(id, fake)
  local updateTriggerState = false;
  Private.ActivateAuraEnvironment(id);
  for triggernum, event in pairs(events[id] or {}) do
    local allStates = WeakAuras.GetTriggerStateForTrigger(id, triggernum);
    if (event.force_events) then
      if (type(event.force_events) == "string") then
        updateTriggerState = RunTriggerFunc(allStates, events[id][triggernum], id, triggernum, event.force_events) or updateTriggerState;
      elseif (type(event.force_events) == "table") then
        for index, event_args in pairs(event.force_events) do
          updateTriggerState = RunTriggerFunc(allStates, events[id][triggernum], id, triggernum, unpack(event_args)) or updateTriggerState;
        end
      elseif (type(event.force_events) == "boolean" and event.force_events) then
        for i, eventName in pairs(event.events) do
          updateTriggerState = RunTriggerFunc(allStates, events[id][triggernum], id, triggernum, eventName) or updateTriggerState;
        end
        for unit, unitData in pairs(event.unit_events) do
          for _, event in ipairs(unitData) do
            updateTriggerState = RunTriggerFunc(allStates, events[id][triggernum], id, triggernum, event, unit) or updateTriggerState
          end
        end
      end
    end
  end

  if (updateTriggerState) then
    Private.UpdatedTriggerState(id);
  end
  Private.ActivateAuraEnvironment(nil);
end

-- Events the client fires several times in one frame with identical arguments
-- around combat and action bar changes. Game state is final before Lua sees
-- any of them, so the triggers listening to them are run once per frame; the
-- later firings carry no new information. None of these events are counted
-- by trigger counters.
local onceAFrameEvents = {UNIT_FLAGS = true, PLAYER_FLAGS_CHANGED = true, SPELL_UPDATE_USABLE = true,
  ACTIONBAR_UPDATE_USABLE = true, ACTIONBAR_UPDATE_COOLDOWN = true, SPELL_UPDATE_ICON = true}
local onceAFrameSeen = {}
-- Plain and unit registrations dispatch to different trigger lists, so each
-- keeps its own key (prefix).
local function RepeatedThisFrame(prefix, event, unit)
  if not onceAFrameEvents[event] then return false end
  local key = unit and (prefix .. event .. unit) or (prefix .. event)
  local now = GetTime()
  if onceAFrameSeen[key] == now then return true end
  onceAFrameSeen[key] = now
  return false
end

function HandleEvent(frame, event, arg1, arg2, ...)
  -- Unit events registered as plain events carry their unit as the first argument.
  if RepeatedThisFrame("E", event, type(arg1) == "string" and arg1 or nil) then return end
  Private.StartProfileSystem("generictrigger " .. event);
  if event == "NAME_PLATE_UNIT_ADDED" then
    nameplateExists[arg1] = true
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    nameplateExists[arg1] = false
  end

  if not(WeakAuras.IsPaused()) then
    Private.ScanEvents(event, arg1, arg2, ...);
  end
  if (event == "PLAYER_ENTERING_WORLD") then
    timer:ScheduleTimer(function()
      HandleEvent(frame, "WA_DELAYED_PLAYER_ENTERING_WORLD", arg1, arg2)
      Private.ScanForLoads(nil, "WA_DELAYED_PLAYER_ENTERING_WORLD")
      Private.StartProfileSystem("generictrigger WA_DELAYED_PLAYER_ENTERING_WORLD");
      Private.CheckCooldownReady();
      Private.StopProfileSystem("generictrigger WA_DELAYED_PLAYER_ENTERING_WORLD");
      Private.PreShowModels()
      do
        Private.CheckTalentsForLoad("WA_DELAYED_PLAYER_ENTERING_WORLD")
      end
    end,
    0.8);  -- Data not available

    timer:ScheduleTimer(function()
      Private.PreShowModels()
    end,
    4);  -- Data not available
  end
  Private.StopProfileSystem("generictrigger " .. event);
end

-- WORKAROUND https://github.com/Stanzilla/WoWUIBugs/issues/708
-- The game fires events for areanaX when it actually should be sending for boss(X+5)
local brokenUnitMap = {
  arena1 = "boss6",
  arena2 = "boss7",
  arena3 = "boss8",
  arena4 = "boss9",
  arena5 = "boss10"
}

function HandleUnitEvent(frame, event, unit, ...)
  if type(unit) == "string" and RepeatedThisFrame("U", event, unit) then return end
  Private.StartProfileSystem("generictrigger " .. event .. " " .. unit);
  if not(WeakAuras.IsPaused()) then
    if Private.ExecEnv.UnitIsUnit(unit, frame.unit)
       or (brokenUnitMap[unit] == frame.unit and not UnitExists(unit))
    then
      Private.ScanUnitEvents(event, frame.unit, ...);
    end
  end
  Private.StopProfileSystem("generictrigger " .. event .. " " .. unit);
end

function GenericTrigger.UnloadAll()
  wipe(loaded_auras);
  wipe(loaded_events);
  wipe(loaded_unit_events);
  wipe(loadedEventsByAura);
  Private.CancelAllDelayedTriggers();
  Private.UnregisterAllEveryFrameUpdate();
end

function GenericTrigger.UnloadDisplays(toUnload)
  for id in pairs(toUnload) do
    loaded_auras[id] = nil
    -- Only the lists this aura was loaded into are touched (recorded by
    -- LoadEvent); walking every event and unit event list for each of the
    -- dozens of auras a combat change unloads was most of the unload cost.
    local record = loadedEventsByAura[id]
    if record then
      for eventname in pairs(record.events) do
        local events = loaded_events[eventname]
        if events then events[id] = nil end
      end
      for unit, unitEvents in pairs(record.unitEvents) do
        local events = loaded_unit_events[unit]
        for eventname in pairs(unitEvents) do
          if events and events[eventname] then events[eventname][id] = nil end
        end
      end
      loadedEventsByAura[id] = nil
    end

    Private.CancelDelayedTrigger(id);
    Private.UnregisterEveryFrameUpdate(id);
  end
end

local genericTriggerRegisteredEvents = {};
local genericTriggerRegisteredUnitEvents = {};

---@class WeakAurasGenericTriggerFrame: FrameScriptObject
local frame = CreateFrame("Frame");
frame.unitFrames = {};
Private.frames["ForeverAuras Generic Trigger Frame"] = frame;
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
genericTriggerRegisteredEvents["PLAYER_ENTERING_WORLD"] = true;
genericTriggerRegisteredEvents["NAME_PLATE_UNIT_ADDED"] = true;
genericTriggerRegisteredEvents["NAME_PLATE_UNIT_REMOVED"] = true;
frame:SetScript("OnEvent", HandleEvent);

function GenericTrigger.Delete(id)
  events[id] = nil
  watched_trigger_events[id] = nil
end

function GenericTrigger.Rename(oldid, newid)
  events[newid] = events[oldid];
  events[oldid] = nil;

  for eventname, events in pairs(loaded_events) do
    events[newid] = events[oldid];
    events[oldid] = nil;
  end

  for unit, events in pairs(loaded_unit_events) do
    for eventname, auras in pairs(events) do
      auras[newid] = auras[oldid]
      auras[oldid] = nil
    end
  end

  watched_trigger_events[newid] = watched_trigger_events[oldid]
  watched_trigger_events[oldid] = nil
  loadedEventsByAura[newid] = loadedEventsByAura[oldid]
  loadedEventsByAura[oldid] = nil

  Private.EveryFrameUpdateRename(oldid, newid)
end

local function MultiUnitLoop(Func, unit, includePets, ...)
  unit = string.lower(unit)
  if unit == "boss" then
    for i = 1, 10 do
      Func(unit..i, ...)
    end
  elseif unit == "arena" then
    for i = 1, 5 do
      Func(unit..i, ...)
    end
  elseif unit == "nameplate" then
    for i = 1, 40 do
      Func(unit..i, ...)
    end
  elseif unit == "group" then
    if includePets ~= "PetsOnly" then
      Func("player", ...)
    end
    if includePets ~= nil then
      Func("pet", ...)
    end
    for i = 1, 4 do
      if includePets ~= "PetsOnly" then
        Func("party"..i, ...)
      end
      if includePets ~= nil then
        Func("partypet"..i, ...)
      end
    end
    for i = 1, 40 do
      if includePets ~= "PetsOnly" then
        Func("raid"..i, ...)
      end
      if includePets ~= nil then
        Func("raidpet"..i, ...)
      end
    end
  elseif unit == "party" then
    if includePets ~= "PetsOnly" then
      Func("player", ...)
    end
    if includePets ~= nil then
      Func("pet", ...)
    end
    for i = 1, 4 do
      if includePets ~= "PetsOnly" then
        Func("party"..i, ...)
      end
      if includePets ~= nil then
        Func("partypet"..i, ...)
      end
    end
  elseif unit == "raid" then
    for i = 1, 40 do
      if includePets ~= "PetsOnly" then
        Func("raid"..i, ...)
      end
      if includePets ~= nil then
        Func("raidpet"..i, ...)
      end
    end
  else
    Func(unit, ...)
  end
end

-- Notes an event list an aura was loaded into (see loadedEventsByAura).
local function NoteLoadedEvent(id, event)
  local record = loadedEventsByAura[id]
  if not record then record = {events = {}, unitEvents = {}}; loadedEventsByAura[id] = record end
  record.events[event] = true
end

-- MultiUnitLoop callback for LoadEvent: registers one trigger for one unit event.
local function LoadUnitEvent(u, event, id, triggernum, data)
  loaded_unit_events[u] = loaded_unit_events[u] or {};
  loaded_unit_events[u][event] = loaded_unit_events[u][event] or {};
  loaded_unit_events[u][event][id] = loaded_unit_events[u][event][id] or {}
  loaded_unit_events[u][event][id][triggernum] = data;
  local record = loadedEventsByAura[id]
  if not record then record = {events = {}, unitEvents = {}}; loadedEventsByAura[id] = record end
  record.unitEvents[u] = record.unitEvents[u] or {}
  record.unitEvents[u][event] = true
end

local eventsToRegister = {};
local unitEventsToRegister = {};
-- MultiUnitLoop callback for GenericTrigger.LoadDisplays: notes a unit event the
-- frame for that unit is not registered for yet.
local function NoteUnitEventToRegister(u, event)
  if not (genericTriggerRegisteredUnitEvents[u] and genericTriggerRegisteredUnitEvents[u][event]) then
    unitEventsToRegister[u] = unitEventsToRegister[u] or {}
    unitEventsToRegister[u][event] = true
  end
end

function LoadEvent(id, triggernum, data)
  if data.events then
    for index, event in pairs(data.events) do
      loaded_events[event] = loaded_events[event] or {};
      loaded_events[event][id] = loaded_events[event][id] or {};
      loaded_events[event][id][triggernum] = data;
      NoteLoadedEvent(id, event)
    end
  end
  if (data.internal_events) then
    for index, event in pairs(data.internal_events) do
      loaded_events[event] = loaded_events[event] or {};
      loaded_events[event][id] = loaded_events[event][id] or {};
      loaded_events[event][id][triggernum] = data;
      NoteLoadedEvent(id, event)
    end
  end
  -- this special internal_events function is run when aura load instead of when it is added
  if data.loadInternalEventFunc then
    local internal_events = data.loadInternalEventFunc(data.trigger)
    for index, event in pairs(internal_events) do
      loaded_events[event] = loaded_events[event] or {};
      loaded_events[event][id] = loaded_events[event][id] or {};
      loaded_events[event][id][triggernum] = data;
      NoteLoadedEvent(id, event)
    end
  end
  if data.unit_events then
    local includePets = data.includePets
    for unit, events in pairs(data.unit_events) do
      unit = string.lower(unit)
      for index, event in pairs(events) do
        -- One shared function with arguments instead of a closure per unit event:
        -- loading many auras at once (a combat change) made hundreds of them.
        MultiUnitLoop(LoadUnitEvent, unit, includePets, event, id, triggernum, data)
      end
    end
  end

  if (data.loadFunc) then
    data.loadFunc(data.trigger);
  end
end

local function trueFunction()
  return true;
end

function GenericTrigger.LoadDisplays(toLoad, loadEvent, ...)
  -- All CDM triggers in one synchronous dispatch share catalog/frame discovery.
  -- Restore the outer snapshot for nested scans; later events always get fresh frames.
  local previousCDMBatch = BeginCDMBatch()
  for id in pairs(toLoad) do
    local register_for_frame_updates = false;
    if(events[id]) then
      loaded_auras[id] = true;
      for triggernum, data in pairs(events[id]) do
        if data.events then
          for index, event in pairs(data.events) do
            if (event == "FRAME_UPDATE") then
              register_for_frame_updates = true;
            elseif not genericTriggerRegisteredEvents[event] then
              eventsToRegister[event] = true;
            end
          end
        end
        if data.unit_events then
          local includePets = data.includePets
          for unit, events in pairs(data.unit_events) do
            for index, event in pairs(events) do
              MultiUnitLoop(NoteUnitEventToRegister, unit, includePets, event)
            end
          end
        end

        if data.counter then
          data.counter:Reset()
        end

        LoadEvent(id, triggernum, data);
      end
    end

    if(register_for_frame_updates) then
      Private.RegisterEveryFrameUpdate(id);
    else
      Private.UnregisterEveryFrameUpdate(id);
    end
  end

  for event in pairs(eventsToRegister) do
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
      xpcall(frame.RegisterEvent, trueFunction, frame, event)
      genericTriggerRegisteredEvents[event] = true;
    end
  end

  for unit, events in pairs(unitEventsToRegister) do
    for event in pairs(events) do
      if not frame.unitFrames[unit] then
        frame.unitFrames[unit] = CreateFrame("Frame")
        frame.unitFrames[unit].unit = unit
        frame.unitFrames[unit]:SetScript("OnEvent", HandleUnitEvent);
      end
      xpcall(frame.unitFrames[unit].RegisterUnitEvent, trueFunction, frame.unitFrames[unit], event, unit)
      genericTriggerRegisteredUnitEvents[unit] = genericTriggerRegisteredUnitEvents[unit] or {};
      genericTriggerRegisteredUnitEvents[unit][event] = true;
    end
  end

  for id in pairs(toLoad) do
    GenericTrigger.ScanWithFakeEvent(id);
  end

  -- Replay events that lead to loading, if we weren't already registered for them
  if (eventsToRegister[loadEvent]) then
    Private.ScanEvents(loadEvent, ...);
  end
  local loadUnit = ...
  if loadUnit and unitEventsToRegister[loadUnit] and unitEventsToRegister[loadUnit][loadEvent] then
    Private.ScanUnitEvents(loadEvent, ...);
  end

  wipe(eventsToRegister);
  wipe(unitEventsToRegister);
  EndCDMBatch(previousCDMBatch)
end

function GenericTrigger.FinishLoadUnload()
end

do
  local function ParseCron(pattern)
    local tests = {}
    for test in pattern:gmatch("[^ ,]+") do
      local startString, endString, intervalString = test:match("(%d*)-?(%d*)/?(%d*)")
      local intervalNumber = tonumber(intervalString)
      local startNumber = startString == "" and 0 or tonumber(startString) or 0
      local endNumber = tonumber(endString)
      if not endNumber then
        endNumber = intervalNumber and math.huge or startNumber
      end
      intervalNumber = intervalNumber or 1

      tinsert(tests, {
        startNumber = startNumber,
        endNumber = endNumber,
        intervalNumber = intervalNumber,
        Match = function(self, count)
          return (count >= self.startNumber and count <= self.endNumber and (count - self.startNumber) % self.intervalNumber == 0)
        end
      })
    end
    return tests
  end

  function Private.ExecEnv.CreateTriggerCounter(pattern)
    local counter = {
      count = 0,
      tests = {

      },
      fastMatches = {
      },
      Reset = function(self)
        self.count = 0
      end,
      GetNext = function(self)
        self.count = self.count + 1
        return self.count
      end,
      SetCount = function(self, count)
        self.count = count
      end,
    }
    if pattern then
      counter.tests = ParseCron(pattern)
      counter.RunTests = function(self, count)
        for _, test in ipairs(self.tests) do
          if test:Match(count) then
            return true
          end
        end
        return false
      end

      for i = 0, 20 do
        counter.fastMatches[i] = counter.RunTests(counter, i)
      end

      counter.Match = function(self)
        if self.count <= 20 then
          return counter.fastMatches[self.count]
        end
        return self:RunTests(self.count)
      end

    else
      counter.Match = function(self)
        return true
      end
    end

    return counter
  end
end

--- Adds a display, creating all internal data structures for all triggers.
---@param data auraData
---@param region table
function GenericTrigger.Add(data, region)
  Private.ValidateSpellCooldownSupport(data)
  local id = data.id;
  events[id] = nil;
  watched_trigger_events[id] = nil

  local warnAboutCLEUEvents = false

  for triggernum, triggerData in ipairs(data.triggers) do
    local trigger, untrigger = triggerData.trigger, triggerData.untrigger
    local triggerType;
    if(trigger and type(trigger) == "table") then
      triggerType = trigger.type;
      if(Private.category_event_prototype[triggerType] or triggerType == "custom") then
        local triggerFuncStr, triggerFunc, untriggerFunc, statesParameter;
        local trigger_events = {};
        local internal_events = {};
        local trigger_unit_events = {};
        local includePets
        local trigger_subevents = {};
        local ignorePartyUnitsInRaid
        ---@type boolean|string|table
        local force_events = false;
        local durationFunc, overlayFuncs, nameFunc, iconFunc, textureFunc, stacksFunc, loadFunc, loadInternalEventFunc;
        local overlayUnderlays
        local tsuConditionVariables;
        local prototype = nil
        local automaticAutoHide
        local duration
        local counter
        local fixUpShowNil
        if(Private.category_event_prototype[triggerType]) then
          if not(trigger.event) then
            error("Improper arguments to WeakAuras.Add - trigger type is \"event\" but event is not defined");
          elseif not(event_prototypes[trigger.event]) then
            if(event_prototypes["Conditions"]) then
              trigger.event = "Conditions";
            else
              error("Improper arguments to WeakAuras.Add - no event prototype can be found for event type \""..trigger.event.."\" and default prototype reset failed.");
            end
          else
            if (trigger.event == "Combat Log") then
              if (not trigger.subeventPrefix) then
                trigger.subeventPrefix = ""
              end
              if (not trigger.subeventSuffix) then
                trigger.subeventSuffix = "";
              end
              if not(Private.subevent_actual_prefix_types[trigger.subeventPrefix]) then
                trigger.subeventSuffix = "";
              end
            end

            prototype = event_prototypes[trigger.event]
            triggerFuncStr = ConstructFunction(prototype, trigger);
            statesParameter = prototype.statesParameter;
            triggerFunc = Private.LoadFunction(triggerFuncStr, id);

            durationFunc = prototype.durationFunc;
            nameFunc = prototype.nameFunc;
            iconFunc = prototype.iconFunc;
            textureFunc = prototype.textureFunc;
            stacksFunc = prototype.stacksFunc;
            loadFunc = prototype.loadFunc;
            loadInternalEventFunc = prototype.loadInternalEventFunc;

            if (prototype.overlayFuncs) then
              overlayFuncs = {};
              overlayUnderlays = {};
              local dest = 1;
              for i, v in ipairs(prototype.overlayFuncs) do
                local enable = true
                if type(v.enable) == "function" then
                  enable = v.enable(trigger)
                elseif type(v.enable) == "boolean" then
                  enable = v.enable
                end
                if enable then
                  overlayFuncs[dest] = v.func;
                  overlayUnderlays[dest] = v.underlay == true;
                  dest = dest + 1;
                end
              end
            end

            if (prototype.automaticrequired) then
              untriggerFunc = trueFunction
            elseif prototype.timedrequired then
              automaticAutoHide = true
              duration = tonumber(trigger.duration or "1")
            else
              WeakAuras.prettyPrint("Invalid Prototype found: " .. prototype.name)
            end

            if prototype.countEvents then
              if trigger.use_count and type(trigger.count) == "string" and trigger.count ~= "" then
                counter = Private.ExecEnv.CreateTriggerCounter(trigger.count)
              else
                counter = Private.ExecEnv.CreateTriggerCounter()
              end
            end

            if(prototype) then
              local trigger_all_events = prototype.events;
              internal_events = prototype.internal_events;
              force_events = prototype.force_events;
              if prototype.subevents then
                trigger_subevents = prototype.subevents
                if trigger_subevents and type(trigger_subevents) == "function" then
                  trigger_subevents = trigger_subevents(trigger, untrigger)
                end
              end

              if trigger.event == "Combat Log" and trigger.subeventPrefix and trigger.subeventSuffix then
                tinsert(trigger_subevents, trigger.subeventPrefix .. trigger.subeventSuffix)
              end

              if (type(trigger_all_events) == "function") then
                trigger_all_events = trigger_all_events(trigger, untrigger);
              end
              trigger_events = trigger_all_events.events
              trigger_unit_events = trigger_all_events.unit_events
              if (type(internal_events) == "function") then
                internal_events = internal_events(trigger, untrigger);
              end
              if (type(force_events) == "function") then
                force_events = force_events(trigger, untrigger)
              end

              if prototype.includePets then
                includePets = trigger.use_includePets == true and trigger.includePets or nil
              end
            end
          end
        else -- CUSTOM
          triggerFunc = WeakAuras.LoadFunction("return "..(trigger.custom or ""), data.id);
          if (trigger.custom_type == "stateupdate") then
            tsuConditionVariables = WeakAuras.LoadFunction("return function() return \n" .. (trigger.customVariables or "") .. "\n end", data.id);
            if not tsuConditionVariables then
              tsuConditionVariables = function() end
            end
            fixUpShowNil = data.information.showNilIsFalse
          end

          if(trigger.custom_type == "status" or trigger.custom_type == "event" and trigger.custom_hide == "custom") then
            untriggerFunc = WeakAuras.LoadFunction("return "..(untrigger.custom or ""), data.id);
            if (not untriggerFunc) then
              untriggerFunc = trueFunction;
            end
          end

          if(trigger.custom_type ~= "stateupdate" and trigger.customDuration and trigger.customDuration ~= "") then
            durationFunc = WeakAuras.LoadFunction("return "..trigger.customDuration, data.id);
          end
          if(trigger.custom_type ~= "stateupdate") then
            overlayFuncs = {};
            for i = 1, 7 do
              local property = "customOverlay" .. i;
              if (trigger[property] and trigger[property] ~= "") then
                overlayFuncs[i] = WeakAuras.LoadFunction("return ".. trigger[property], data.id);
              end
            end
          end
          if(trigger.custom_type ~= "stateupdate" and trigger.customName and trigger.customName ~= "") then
            nameFunc = WeakAuras.LoadFunction("return "..trigger.customName, data.id);
          end
          if(trigger.custom_type ~= "stateupdate" and trigger.customIcon and trigger.customIcon ~= "") then
            iconFunc = WeakAuras.LoadFunction("return "..trigger.customIcon, data.id);
          end
          if(trigger.custom_type ~= "stateupdate" and trigger.customTexture and trigger.customTexture ~= "") then
            textureFunc = WeakAuras.LoadFunction("return "..trigger.customTexture, data.id);
          end
          if(trigger.custom_type ~= "stateupdate" and trigger.customStacks and trigger.customStacks ~= "") then
            stacksFunc = WeakAuras.LoadFunction("return "..trigger.customStacks, data.id);
          end

          if((trigger.custom_type == "status" or trigger.custom_type == "stateupdate") and trigger.check == "update") then
            trigger_events = {"FRAME_UPDATE"};
          else
            local rawEvents = WeakAuras.split(trigger.events);
            for index, event in pairs(rawEvents) do
              -- custom events in the form of event:unit1:unit2:unitX are registered with RegisterUnitEvent
              local trueEvent
              local isTrigger = false
              local isUnitEvent = false
              for i in event:gmatch("[^:]+") do
                if not trueEvent then
                  trueEvent = string.upper(i)
                  isTrigger = trueEvent == "TRIGGER"
                elseif Private.InternalEventByIDList[trueEvent] then
                  tinsert(trigger_events, trueEvent..":"..i)
                elseif trueEvent:match("^UNIT_") or Private.UnitEventList[trueEvent] then
                  isUnitEvent = true

                  if string.lower(strsub(i, #i - 3)) == "pets" then
                    i = strsub(i, 1, #i-4)
                    includePets = "PlayersAndPets"
                  elseif string.lower(strsub(i, #i - 7)) == "petsonly" then
                    includePets = "PetsOnly"
                    i = strsub(i, 1, #i - 8)
                  elseif string.lower(i, #i - 5) == "group" then
                    ignorePartyUnitsInRaid = ignorePartyUnitsInRaid or {}
                    ignorePartyUnitsInRaid[trueEvent] = true
                  end

                  trigger_unit_events[i] = trigger_unit_events[i] or {}
                  tinsert(trigger_unit_events[i], trueEvent)
                elseif isTrigger then
                  local requestedTriggernum = tonumber(i)
                  if requestedTriggernum then
                    if watched_trigger_events[id] and watched_trigger_events[id][triggernum] and watched_trigger_events[id][triggernum][requestedTriggernum] then
                      -- if the request is reciprocal (2 custom triggers request each other which would cause a stack overflow) then prevent the reciprocal one being added.
                    elseif requestedTriggernum and requestedTriggernum ~= triggernum then
                      watched_trigger_events[id] = watched_trigger_events[id] or {}
                      watched_trigger_events[id][requestedTriggernum] = watched_trigger_events[id][requestedTriggernum] or {}
                      watched_trigger_events[id][requestedTriggernum][triggernum] = true
                    end
                  end
                end
              end
              if isUnitEvent then
                -- not added to trigger_events
              elseif isTrigger then
                -- not added to trigger_events
              else
                tinsert(trigger_events, event)
              end
            end
          end
          if trigger.custom_type == "status" or trigger.custom_type == "stateupdate" then
            force_events = data.information.forceEvents or "STATUS"
          end
          if (trigger.custom_type == "stateupdate") then
            statesParameter = "full";
          end

          if(trigger.custom_type == "event" and trigger.custom_hide == "timed") then
            automaticAutoHide = true;
            if (not trigger.dynamicDuration) then
              duration = tonumber(trigger.duration);
            end
          end
        end

        events[id] = events[id] or {};
        events[id][triggernum] = {
          trigger = trigger,
          triggerFunc = triggerFunc,
          untriggerFunc = untriggerFunc,
          statesParameter = statesParameter,
          event = trigger.event,
          events = trigger_events,
          onUpdateThrottle = trigger.onUpdateThrottle or (trigger.type ~= "custom" and rangeThrottles[trigger.event]) or nil,
          ignorePartyUnitsInRaid = ignorePartyUnitsInRaid,
          internal_events = internal_events,
          loadInternalEventFunc = loadInternalEventFunc,
          force_events = force_events,
          unit_events = trigger_unit_events,
          includePets = includePets,
          inverse = trigger.use_inverse,
          subevents = trigger_subevents,
          durationFunc = durationFunc,
          overlayFuncs = overlayFuncs,
          overlayUnderlays = overlayUnderlays,
          nameFunc = nameFunc,
          iconFunc = iconFunc,
          textureFunc = textureFunc,
          stacksFunc = stacksFunc,
          loadFunc = loadFunc,
          duration = duration,
          automaticAutoHide = automaticAutoHide,
          tsuConditionVariables = tsuConditionVariables,
          prototype = prototype,
          ignoreOptionsEventErrors = data.information.ignoreOptionsEventErrors,
          counter = counter,
          fixUpShowNil = fixUpShowNil
        };
      end
    end
  end

  if warnAboutCLEUEvents then
    Private.AuraWarnings.UpdateWarning(data.uid, "spammy_event_warning", "error",
                L["|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r\nCOMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.\nFind more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Custom-Triggers#events"])
  else
    Private.AuraWarnings.UpdateWarning(data.uid, "spammy_event_warning")
  end
end

do
  local update_clients = {};
  local update_clients_num = 0;
  local update_frame = nil
  Private.frames["Custom Trigger Every Frame Updater"] = update_frame;
  local updating = false;

  ---@type fun(id)
  function Private.RegisterEveryFrameUpdate(id)
    if not(update_clients[id]) then
      update_clients[id] = true;
      update_clients_num = update_clients_num + 1;
    end
    if not(update_frame) then
      update_frame = CreateFrame("Frame");
    end
    if not(updating) then
      update_frame:SetScript("OnUpdate", function(self, elapsed)
        if not(WeakAuras.IsPaused()) then
          Private.ScanEvents("FRAME_UPDATE", elapsed);
        end
      end);
      updating = true;
    end
  end

  ---@type fun(oldid, newid)
  function Private.EveryFrameUpdateRename(oldid, newid)
    update_clients[newid] = update_clients[oldid];
    update_clients[oldid] = nil;
  end

  ---@type fun(id)
  function Private.UnregisterEveryFrameUpdate(id)
    if(update_clients[id]) then
      update_clients[id] = nil;
      update_clients_num = update_clients_num - 1;
    end
    if(update_clients_num == 0 and update_frame and updating) then
      update_frame:SetScript("OnUpdate", nil);
      updating = false;
    end
  end

  ---@type fun()
  function Private.UnregisterAllEveryFrameUpdate()
    if (not update_frame) then
      return;
    end
    wipe(update_clients);
    update_clients_num = 0;
    update_frame:SetScript("OnUpdate", nil);
    updating = false;
  end
end

--#############################
--# Support code for triggers #
--#############################

-- CD/Rune/GCD support code
do
  local cdReadyFrame;

  local items = {};
  local itemCdDurs = {};
  local itemCdExps = {};
  local itemCdHandles = {};
  local itemCdEnabled = {};

  local itemSlots = {};
  local itemSlotsCdDurs = {};
  local itemSlotsCdExps = {};
  local itemSlotsCdHandles = {};
  local itemSlotsEnable = {};

  local runes = {};
  local runeCdDurs = {};
  local runeCdExps = {};
  local runeCdHandles = {};

  local gcdStart;
  local gcdDuration;
  local gcdSpellName;
  local gcdSpellIcon;
  local gcdEndCheck;
  local gcdModrate

  local shootStart
  local shootDuration

  local function GetRuneDuration()
    local runeDuration = -100;
    for id, _ in pairs(runes) do
      local _, duration = GetRuneCooldown(id);
      duration = duration or 0;
      runeDuration = duration > 0 and duration or runeDuration
    end
    return runeDuration
  end

  -- The shared global cooldown is read from the Classic reference spell 29515,
  -- as the Global Cooldown trigger does (Prototypes.lua): Forever reports no
  -- cooldown on retail's 61304, so the shared clock never started and every
  -- cooldown check had to broadcast GCD_UPDATE instead of GCD_START/END.
  -- Kept on 61304 for now: with 29515 the clock does run, but then every GCD
  -- start and end refreshes every "Show GCD" icon (measured 30ms+ per GCD with
  -- the Mage UI), which costs more than the unconditional refresh it replaces.
  local GCD_REFERENCE_SPELL = 61304

  local function CheckGCD(deferEvent)
    if C_Secrets.ShouldSpellCooldownBeSecret(GCD_REFERENCE_SPELL) then
      if deferEvent then return "GCD_UPDATE" end
      if not WeakAuras.IsPaused() then Private.ScanEvents("GCD_UPDATE") end
      return
    end
    local event;
    local startTime, duration, _, modRate
    if GetSpellCooldown then
      startTime, duration, _, modRate = GetSpellCooldown(GCD_REFERENCE_SPELL);
    else
      local spellCooldownInfo = C_Spell.GetSpellCooldown(GCD_REFERENCE_SPELL);
      if spellCooldownInfo then
        startTime = spellCooldownInfo.startTime
        duration = spellCooldownInfo.duration
        modRate = spellCooldownInfo.modRate
      end
    end
    -- A secret timer cannot be compared or scheduled: treat it like a restricted one.
    if hasanysecretvalues(startTime, duration, modRate) then
      if deferEvent then return "GCD_UPDATE" end
      if not WeakAuras.IsPaused() then Private.ScanEvents("GCD_UPDATE") end
      return
    end
    if(duration and duration > 0) then
      if not(gcdStart) then
        event = "GCD_START";
      elseif(gcdStart ~= startTime or gcdDuration ~= duration or gcdModrate ~= modRate) then
        event = "GCD_CHANGE";
      end
      gcdStart, gcdDuration, gcdModrate = startTime, duration, modRate
      local endCheck = startTime + duration + 0.1;
      if(gcdEndCheck ~= endCheck) then
        gcdEndCheck = endCheck;
        timer:ScheduleTimerFixed(CheckGCD, duration + 0.1);
      end
    else
      if(gcdStart) then
        event = "GCD_END"
      end
      gcdStart, gcdDuration, gcdModrate = nil, nil, nil;
      gcdSpellName, gcdSpellIcon = nil, nil;
      gcdEndCheck = 0;
    end
    -- Cooldown batches publish GCD changes after their per-spell caches are fresh.
    if deferEvent then return event end
    if(event and not WeakAuras.IsPaused()) then
      Private.ScanEvents(event);
    end
  end

  local RecheckHandles = {
    expirationTime = {},
    handles = {},
    Recheck = function(self, id)
      self.handles[id] = nil
      self.expirationTime[id] = nil
      -- One spell's cooldown ended: refresh the shared GCD clock, but do not
      -- broadcast the blanket GCD_UPDATE refresh that a restricted clock
      -- returns, which re-ran every "Show GCD" icon on each expiry timer.
      local gcdEvent = CheckGCD(true)
      if gcdEvent and gcdEvent ~= "GCD_UPDATE" and not WeakAuras.IsPaused() then
        Private.ScanEvents(gcdEvent)
      end
      Private.CheckSpellCooldown(id, GetRuneDuration())
    end,
    Schedule = function(self, expirationTime, id)
      if (not self.expirationTime[id] or expirationTime < self.expirationTime[id]) and expirationTime > 0 then
        self:Cancel(id)
        local duration = expirationTime - GetTime()
        if duration > 0 then
          self.handles[id] = timer:ScheduleTimerFixed(self.Recheck, duration, self, id)
          self.expirationTime[id] = expirationTime
        end
      end
    end,
    Cancel = function(self, id)
      if self.handles[id] then
        timer:CancelTimer(self.handles[id])
        self.handles[id] = nil
        self.expirationTime[id] = nil
      end
    end,
  }

  local function FetchSpellCooldown(self, id)
    if self.duration[id] and self.expirationTime[id] then
      return self.expirationTime[id] - self.duration[id], self.duration[id], false, self.readyTime[id], self.modRate[id] or 1.0
    elseif self.remainingTime[id] then
      return self.remainingTime[id], self.duration[id], true, self.readyTime[id], self.modRate[id] or 1.0
    end
    return 0, 0, nil, nil, 1.0
  end

  local function HandleSpell(self, id, startTime, duration, modRate, paused)
    local changed = false
    local nowReady = false
    if C_Secrets.ShouldSpellCooldownBeSecret(id) then
      local isReady = WeakAuras.IsSpellReady(id)
      changed = self.readyState[id] ~= isReady
      self.readyState[id] = isReady
      return changed, isReady
    else
      self.readyState[id] = nil
    end

    local time = GetTime()
    if self.expirationTime[id] and self.expirationTime[id] <= time and self.expirationTime[id] ~= 0 then
      self.readyTime[id] = self.expirationTime[id]
      self.duration[id] = 0
      self.expirationTime[id] = 0
      changed = true
      nowReady = true
    end
    local endTime = startTime + duration;
    if endTime <= time then
      startTime = 0
      duration = 0
      endTime = 0
    end

    if paused then
      if self.duration[id] ~= duration then
        self.duration[id] = duration
        changed = true
      end
      if self.expirationTime[id] then
        self.expirationTime[id] = nil
        changed = true
      end

      if self.modRate[id] ~= modRate then
        self.modRate[id] = modRate
        changed = true
      end

      local remaining = startTime + duration - GetTime()
      if self.remainingTime[id] ~= remaining then
        self.remainingTime[id] = remaining
        changed = true
      end

      return changed, false
    end

    if duration > 0 then
      if (startTime == gcdStart and duration == gcdDuration)
      then
        -- GCD cooldown, this could mean that the spell reset!
        if self.expirationTime[id] and self.expirationTime[id] > endTime and self.expirationTime[id] ~= 0 then
          self.duration[id] = 0
          self.expirationTime[id] = 0
          if not self.readyTime[id] then
            self.readyTime[id] = time
          end
          changed = true
          nowReady = true
        end
        RecheckHandles:Schedule(endTime, id)
        return changed, nowReady
      end
    end

    if self.remainingTime[id] then
      self.remainingTime[id] = nil
      changed = true
    end

    if self.duration[id] ~= duration then
      self.duration[id] = duration
      changed = true
    end

    if self.expirationTime[id] ~= endTime then
      self.expirationTime[id] = endTime
      changed = true
      nowReady = endTime == 0
    end

    if duration == 0 then
      if not self.readyTime[id] then
        self.readyTime[id] = time
      end
    else
      self.readyTime[id] = nil
    end

    if self.modRate[id] ~= modRate then
      self.modRate[id] = modRate
      changed = true
    end

    RecheckHandles:Schedule(endTime, id)
    return changed, nowReady
  end

  ---@class SpellCDHandler
  ---@field duration table<number, number>
  ---@field expirationTime table<number, number>
  ---@field remainingTime table<number, number>
  ---@field readyTime table<number, number>
  ---@field modRate table<number, number>
  ---@field handles table<number, any>
  ---@field readyState table<number, boolean>
  ---@field HandleSpell fun(self: SpellCDHandler, id: number, startTime: number?, duration: number?, modRate: number?, paused: boolean?)
  ---@field FetchSpellCooldown fun(self: SpellCDHandler, id: number): number, number, boolean, number, number
  local function CreateSpellCDHandler()
    local cd = {
      duration = {},
      expirationTime = {},
      remainingTime = {},
      readyTime = {},
      modRate = {},
      handles = {}, -- Share handles, and use lowest time to schedule
      readyState = {}, -- whether the spell was ready, values are niled out when spell cd is not a secret
      HandleSpell = HandleSpell,
      FetchSpellCooldown = FetchSpellCooldown
    }
    return cd
  end

  local secretPolled = {}
  local secretPoller = CreateFrame("Frame")
  secretPoller:Hide()
  local SECRET_POLL_INTERVAL = 0.1
  local secretScratch = {}
  local chargesScratch = {}
  local SECRET_MIN_COOLDOWN = 1.6
  local function IsWandOnlyTimer(spellID, startTime)
    if not Private.IsWandHeldSpell(spellID) then return false end
    local cast = Private.GetSpellLastCast(spellID)
    return not cast or math.abs(startTime - cast) > 0.5
  end
  secretPoller.elapsed = 0
  local SpellDetails
  secretPoller:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < SECRET_POLL_INTERVAL then return end
    self.elapsed = 0
    Private.StartProfileSystem("spell cooldown poll")
    SpellDetails.quietSecretCheck = true
    for id in pairs(secretPolled) do
      if SpellDetails.data[id] then
        local info = C_Spell.GetSpellCooldown(id)
        local active = info and info.isActive
        if not info or issecretvalue(active) or active ~= true or Private.GetSpellCooldownGCDFlag(id) == true then
          SpellDetails:CheckSpellCooldown(id)
        end
      else
        secretPolled[id] = nil
      end
    end
    SpellDetails.quietSecretCheck = nil
    Private.StopProfileSystem("spell cooldown poll")
    if not next(secretPolled) then self:Hide() end
  end)

  --- @class PerSpellDetails
  --- @field known boolean? whether the spell is known by the player or not
  --- @field charges number? the number of charges as returned by GetSpellCharges
  --- @field chargesMax number? the number of max charges as returned by GetSpellCharges
  --- @field chargeGainTime number?
  --- @field chargeLostTime number?
  --- @field count number?
  --- @field name string
  --- @field icon number
  --- @field id number
  --- @field watched table<number, boolean>

  -- Basic details like name, icon, charges, times per effective spell id
  -- Also contains the mapping from effective spell id to watched
  --- @class SpellDetails
  --- @field private data table<number, PerSpellDetails>
  --- @field private watchedSpellIds table<number, table<boolean, table<boolean, number>>> --- Maps user spell id to effective spell id via useExact and followoverride
  --- @field private spellCds SpellCDHandler
  --- @field private spellCdsRune SpellCDHandler
  --- @field private spellCdsOnlyCooldown SpellCDHandler
  --- @field private spellCdsOnlyCooldownRune SpellCDHandler
  --- @field private spellCdsCharges SpellCDHandler
  --- @field private AddEffectiveSpellId fun(self: SpellDetails, effectiveSpellId: number, userSpellId: number)
  --- @field CheckSpellKnown fun(self: SpellDetails) Handles the SPELLS_CHANGED event (and intial setup)
  --- @field CheckSpellCooldowns fun(self: SpellDetails, runeDuration: number?)
  --- @field CheckSpellCooldown fun(self: SpellDetails, effectiveSpellId: number, runeDuration: number?)
  --- @field SendEventsForSpell fun(self: SpellDetails, effectiveSpellId: number, event: string, ...: any[])
  --- @field GetSpellCharges fun(self: SpellDetails, effectiveSpellId: number, ignoreSpellKnown: boolean): number?, number?, number?, number?, number?
  SpellDetails = {
    -- The data per effective spellId
    data = {
    },
    -- The SpellDetails uses internally effective spell ids,
    -- But the api uses user spell ids, so we need to map in three places
    -- In the API, when SPELLS_CHANGED and when sending the events
    -- Contains the list of user spell ids we watch
    watchedSpellIds = {

    },

    -- Interprets the basic information to figure out whether an ability is on cd or not
    -- for th various different api variants we have
    -- This can probably be simplfied
    spellCds = CreateSpellCDHandler(),
    spellCdsRune = CreateSpellCDHandler(),
    spellCdsOnlyCooldown = CreateSpellCDHandler(),
    spellCdsOnlyCooldownRune = CreateSpellCDHandler(),
    spellCdsCharges = CreateSpellCDHandler(),

    -- Helper functions
    AddEffectiveSpellId = function(self, effectiveSpellId, userSpellId)
      if self.data[effectiveSpellId] then
        self.data[effectiveSpellId].watched[userSpellId] = (self.data[effectiveSpellId].watched[userSpellId] or 0) + 1
        return
      end

      local name, _, icon, _, _, _, spellId = Private.ExecEnv.GetSpellInfo(effectiveSpellId)
      self.data[effectiveSpellId] = {
        name = name,
        icon = icon,
        id = spellId,
        watched = {}
      }
      self.data[effectiveSpellId].watched[userSpellId] = 1

      local spellDetail = self.data[effectiveSpellId]
      spellDetail.known = WeakAuras.IsSpellKnownIncludingPet(effectiveSpellId)

      if C_Secrets.ShouldSpellCooldownBeSecret(effectiveSpellId) then
        return
      end

      local charges, maxCharges, startTime, duration, unifiedCooldownBecauseRune,
            startTimeCooldown, durationCooldown, cooldownBecauseRune, startTimeCharges, durationCharges,
            spellCount, unifiedModRate, modRate, modRateCharges, paused
            = WeakAuras.GetSpellCooldownUnified(effectiveSpellId, GetRuneDuration());

      spellDetail.charges = charges
      spellDetail.chargesMax = maxCharges
      spellDetail.count = spellCount
      self.spellCds:HandleSpell(effectiveSpellId, startTime, duration, unifiedModRate, paused)
      if not unifiedCooldownBecauseRune then
        self.spellCdsRune:HandleSpell(effectiveSpellId, startTime, duration, unifiedModRate, paused)
      end
      self.spellCdsOnlyCooldown:HandleSpell(effectiveSpellId, startTimeCooldown, durationCooldown, modRate, paused)
      if not cooldownBecauseRune then
        self.spellCdsOnlyCooldownRune:HandleSpell(effectiveSpellId, startTimeCooldown, durationCooldown, modRate, paused)
      end
      self.spellCdsCharges:HandleSpell(effectiveSpellId, startTimeCharges, durationCharges, modRateCharges, paused)
    end,

    -- Actual api
    CheckSpellKnown = function(self)
      -- Check for spells whose effective spell id changed
      for userSpellId, watchedData in pairs(self.watchedSpellIds) do
        for useExact, useExactData in pairs(watchedData) do
          for followoverride, oldEffectiveSpellId in pairs(useExactData) do
            local newEffectiveSpellId = Private.ExecEnv.GetEffectiveSpellId(userSpellId, useExact, followoverride)

            if oldEffectiveSpellId ~= newEffectiveSpellId then
              -- The effective spell id has changed
              -- There are lots of cases to consider here:

              -- For the new effective spell id
              self:AddEffectiveSpellId(newEffectiveSpellId, userSpellId)

              local oldSpellDetail = self.data[oldEffectiveSpellId]
              local newSpellDetail = self.data[newEffectiveSpellId]
              if oldSpellDetail and newSpellDetail then
                -- Check whether we need to emit the SPELL_CHARGES_CHANGED or SPELL_COOLDOWN_READY events
                local chargesChanged = hasanysecretvalues(oldSpellDetail.charges, newSpellDetail.charges) or oldSpellDetail.charges ~= newSpellDetail.charges or
                  hasanysecretvalues(oldSpellDetail.count, newSpellDetail.count) or oldSpellDetail.count ~= newSpellDetail.count or
                  hasanysecretvalues(oldSpellDetail.chargesMax, newSpellDetail.chargesMax) or oldSpellDetail.chargesMax ~= newSpellDetail.chargesMax
                local oldCharge = oldSpellDetail.charges or oldSpellDetail.count or 0
                local newCharge = newSpellDetail.charges or newSpellDetail.count or 0
                local chargesDifference = 0
                if not hasanysecretvalues(oldCharge, newCharge) then
                  chargesDifference = newCharge - oldCharge
                end

                local nowReady = not self.spellCdsOnlyCooldown.readyTime[oldEffectiveSpellId]
                and self.spellCdsOnlyCooldown.readyTime[newEffectiveSpellId]

                -- For the old effective spell id
                -- * Remove the spell from watched
                -- * If we removed the last mapping, remove the spell details of the effective spell id
                if oldSpellDetail.watched[userSpellId] == 1 then
                  oldSpellDetail.watched[userSpellId] = nil
                  if next(self.data[oldEffectiveSpellId].watched) == nil then
                    self.data[oldEffectiveSpellId] = nil
                    RecheckHandles:Cancel(oldEffectiveSpellId)
                  end
                else
                  oldSpellDetail.watched[userSpellId] = oldSpellDetail.watched[userSpellId] - 1
                end

                -- Finally update the watchedSpellIds mapping
                self.watchedSpellIds[userSpellId][useExact][followoverride] = newEffectiveSpellId

                -- We only send events for the userSpellId, since only those get remapped
                Private.ScanEventsByID("SPELL_COOLDOWN_CHANGED", userSpellId, newEffectiveSpellId)
                if nowReady then
                  Private.ScanEventsByID("SPELL_COOLDOWN_READY", userSpellId, newEffectiveSpellId)
                end
                if chargesChanged ~= 0 then
                  Private.ScanEventsByID("SPELL_CHARGES_CHANGED", userSpellId, newEffectiveSpellId, chargesDifference, newCharge)
                end
              end
            end
          end
        end
      end

      -- Check for changes in the effective spells
      local changed = {}
      for effectiveSpellId, spellDetailsData in pairs(self.data) do
        local known = WeakAuras.IsSpellKnownIncludingPet(effectiveSpellId)
        if (known ~= spellDetailsData.known) then
          spellDetailsData.known = known
          changed[effectiveSpellId] = true
        end

        local name, _, icon, _, _, _, spellId = Private.ExecEnv.GetSpellInfo(effectiveSpellId)
        if self.data[effectiveSpellId].name ~= name then
          self.data[effectiveSpellId].name = name
          changed[effectiveSpellId] = true
        end
        if self.data[effectiveSpellId].icon ~= icon then
          self.data[effectiveSpellId].icon = icon
          changed[effectiveSpellId] = true
        end
      end

      if not WeakAuras.IsPaused() then
        for id in pairs(changed) do
          self:SendEventsForSpell(id, "SPELL_COOLDOWN_CHANGED", id)
        end
      end
    end,

    -- Checks every watched spell. With a budget (milliseconds) the check stops
    -- once it is spent and returns false; the next call continues where it
    -- stopped (a snapshot of the ids, so spells watched meanwhile are picked up
    -- by the next full check). Without a budget everything is checked and any
    -- unfinished partial check is dropped. Returns true when the pass is done.
    CheckSpellCooldowns = function(self, runeDuration, budget, maxSpells)
      local pending = self.pendingIds
      if not pending or not (budget or maxSpells) then
        pending = {}
        for id in pairs(self.data) do pending[#pending + 1] = id end
        self.pendingIds, self.pendingIndex = pending, 1
        -- Whether this pass is a quiet one (see HandleEvent): a louder request
        -- arriving during a quiet pass restarts it, so every spell gets it.
        self.pendingQuiet = self.quietSecretCheck or nil
      end
      local deadline = budget and (debugprofilestop() + budget)
      local index = self.pendingIndex
      -- maxSpells: at most this many spells per call (see FULL_CHECK_SPELLS).
      local checked = 0
      while pending[index] do
        local id = pending[index]
        if self.data[id] then self:CheckSpellCooldown(id, runeDuration) end
        index = index + 1
        checked = checked + 1
        if pending[index] and ((deadline and debugprofilestop() > deadline) or (maxSpells and checked >= maxSpells)) then
          self.pendingIndex = index
          return false
        end
      end
      self.pendingIds, self.pendingIndex = nil, nil
      return true
    end,

    CheckSpellCooldown = function(self, effectiveSpellId, runeDuration)
      if C_Secrets.ShouldSpellCooldownBeSecret(effectiveSpellId) then
        local detail = self.data[effectiveSpellId]
        local cooldown = Private.GetSpellCooldownData(effectiveSpellId, "cooldown", nil, nil, secretScratch)
        if not detail or not cooldown then return end
        local ready, charges, maxCharges, count = cooldown.ready, cooldown.charges, cooldown.maxCharges, cooldown.count
        local now = GetTime()
        -- True when the spell only counts as not ready because a global
        -- cooldown just started (the guard below), not because of a cooldown
        -- of its own.
        local gcdGuard = false
        if ready == true then
          local onGCD, since = Private.GetSpellCooldownGCDFlag(effectiveSpellId)
          local info = onGCD == true and since and now - since < SECRET_MIN_COOLDOWN and C_Spell.GetSpellCooldown(effectiveSpellId)
          if info and info.isActive == true then ready = false; gcdGuard = true end
        end
        for _, handler in ipairs(self.cdHandlers) do
          if handler.expirationTime[effectiveSpellId] then
            handler.expirationTime[effectiveSpellId] = 0
            handler.duration[effectiveSpellId] = 0
          end
        end
        local wandOnly = false
        if detail.notReadyWand then
          local cast = Private.GetSpellLastCast(effectiveSpellId)
          wandOnly = not cast or (detail.lastReadyAt and cast < detail.lastReadyAt - 0.2) or false
        end
        detail.wandOnlyCooldown, detail.ownCooldownEnd = nil, nil
        -- A not-ready stretch that only ever came from the GCD guard ends when
        -- the guard lifts, which can be a few hundredths after the 1.6s
        -- threshold: that is a global cooldown ending, not the spell's own
        -- cooldown, so it fires no ready event unless it lasted longer than
        -- any global cooldown can.
        local gcdOnly = detail.notReadyGCD and detail.notReadySince and now - detail.notReadySince < 2.5
        if detail.ready == false and ready == true and detail.notReadySince and not wandOnly and not gcdOnly
        and now - detail.notReadySince > SECRET_MIN_COOLDOWN and not WeakAuras.IsPaused() then
          self:SendEventsForSpell(effectiveSpellId, "SPELL_COOLDOWN_READY", effectiveSpellId)
        end
        if ready == false then
          if detail.ready ~= false or not detail.notReadySince then
            detail.notReadySince = now
            detail.notReadyWand = Private.IsWandHeldSpell(effectiveSpellId) or nil
            detail.notReadyGCD = gcdGuard or nil
          elseif not gcdGuard then
            -- A cooldown of its own was seen during this stretch.
            detail.notReadyGCD = nil
          end
        else
          detail.notReadySince, detail.notReadyWand, detail.notReadyGCD = nil, nil, nil
          if ready == true then detail.lastReadyAt = now end
        end
        local stateChanged = detail.ready ~= ready
          or (not hasanysecretvalues(detail.charges, detail.chargesMax, detail.count, charges, maxCharges, count)
            and (detail.charges ~= charges or detail.chargesMax ~= maxCharges or detail.count ~= count))
        detail.ready = ready
        if ready ~= true then
          secretPolled[effectiveSpellId] = true
          secretPoller:Show()
        else
          secretPolled[effectiveSpellId] = nil
        end
        detail.charges, detail.chargesMax, detail.count = charges, maxCharges, count
        detail.chargeGainTime, detail.chargeLostTime = nil, nil
        -- A change is announced. A ready spell stays quiet otherwise: its
        -- duration object draws an empty swipe either way, and announcing
        -- every spell on every cast made every cooldown icon redraw twice per
        -- cast. A spell that is, or may be, on cooldown (ready false or
        -- unknown) is announced on every loud check as well: a restricted
        -- spell's duration object is a snapshot, and the one taken when the
        -- cast's global cooldown arrived can predate the spell's own cooldown,
        -- which the client reports in a later event with no readable change
        -- (an instant such as Thunder Clap stayed drawn as ready until combat
        -- ended). Quiet checks (usability batches, the poller) stay quiet.
        if (stateChanged or (ready ~= true and not self.quietSecretCheck)) and not WeakAuras.IsPaused() then
          self:SendEventsForSpell(effectiveSpellId, "SPELL_COOLDOWN_CHANGED", effectiveSpellId)
        end
        return
      end
      secretPolled[effectiveSpellId] = nil
      local charges, maxCharges, startTime, duration, unifiedCooldownBecauseRune,
        startTimeCooldown, durationCooldown, cooldownBecauseRune, startTimeCharges, durationCharges,
        spellCount, unifiedModRate, modRate, modRateCharges, paused
        = WeakAuras.GetSpellCooldownUnified(effectiveSpellId, runeDuration);

      local time = GetTime();

      local spellDetail = self.data[effectiveSpellId]
      spellDetail.ready = nil
      if not hasanysecretvalues(startTime, duration) and (duration == 0 or startTime == 0) then
        spellDetail.lastReadyAt = time
      end
      local chargesChanged, chargesDifference = true, 0
      if not hasanysecretvalues(spellDetail.charges, charges, spellCount, spellDetail.count) then
        chargesChanged = spellDetail.charges ~= charges or spellDetail.count ~= spellCount
          or spellDetail.chargesMax ~= maxCharges
        chargesDifference = (charges or spellCount or 0) - (spellDetail.charges or spellDetail.count or 0)
      end
      spellDetail.charges = charges
      spellDetail.chargesMax = maxCharges
      spellDetail.count = spellCount
      if chargesDifference ~= 0 then
        if chargesDifference > 0 then
          spellDetail.chargeGainTime = time
          spellDetail.chargeLostTime = nil
        else
          spellDetail.chargeGainTime = nil
          spellDetail.chargeLostTime = time
        end
      end

      local endedWandOnly = spellDetail.wandOnlyCooldown
      local changed = false
      changed = self.spellCds:HandleSpell(effectiveSpellId, startTime, duration, unifiedModRate, paused) or changed
      if not unifiedCooldownBecauseRune then
        changed = self.spellCdsRune:HandleSpell(effectiveSpellId, startTime, duration, unifiedModRate, paused) or changed
      end
      local cdChanged, nowReady = self.spellCdsOnlyCooldown:HandleSpell(effectiveSpellId, startTimeCooldown, durationCooldown, modRate, paused)
      changed = cdChanged or changed
      if not cooldownBecauseRune then
        changed = self.spellCdsOnlyCooldownRune:HandleSpell(effectiveSpellId, startTimeCooldown, durationCooldown, modRate, paused) or changed
      end
      local chargeChanged = self.spellCdsCharges:HandleSpell(effectiveSpellId, startTimeCharges, durationCharges, modRateCharges)
      changed = chargeChanged or changed
      local wandOnly = durationCooldown > 0 and IsWandOnlyTimer(effectiveSpellId, startTimeCooldown)
      spellDetail.wandOnlyCooldown = wandOnly or nil
      if durationCooldown > 0 and not wandOnly then
        spellDetail.ownCooldownEnd = startTimeCooldown + durationCooldown
      end
      local ownEnded = spellDetail.ownCooldownEnd and spellDetail.ownCooldownEnd <= time + 0.05

      if not WeakAuras.IsPaused() then
        if nowReady and (not endedWandOnly or ownEnded) then
          spellDetail.ownCooldownEnd = nil
          self:SendEventsForSpell(effectiveSpellId, "SPELL_COOLDOWN_READY", effectiveSpellId)
        end

        if changed or chargesChanged then
          self:SendEventsForSpell(effectiveSpellId, "SPELL_COOLDOWN_CHANGED", effectiveSpellId)
        end

        if (chargesDifference ~= 0 ) then
          self:SendEventsForSpell(effectiveSpellId, "SPELL_CHARGES_CHANGED", effectiveSpellId, chargesDifference, charges or spellCount or 0)
        end
      end
    end,

    WatchSpellCooldown = function(self, userSpellId, ignoreRunes, useExact, followoverride)
      if not(cdReadyFrame) then
        Private.InitCooldownReady();
      end

      if not userSpellId or userSpellId == 0 then
        return
      end

      useExact = useExact and true or false
      followoverride = followoverride and true or false

      if ignoreRunes and true then
        for i = 1, 6 do
          WeakAuras.WatchRuneCooldown(i)
        end
      end

      local effectiveSpellId = Private.ExecEnv.GetEffectiveSpellId(userSpellId, useExact, followoverride)

      self.watchedSpellIds[userSpellId] = self.watchedSpellIds[userSpellId] or {}
      self.watchedSpellIds[userSpellId][useExact] = self.watchedSpellIds[userSpellId][useExact] or {}
      if self.watchedSpellIds[userSpellId][useExact][followoverride] == effectiveSpellId then
        -- We are already watching userSpellId in the exact useExact/followoverride mode, so there's
        -- nothing to do then
        return
      end

      -- We aren't watching userSpellId yet
      self.watchedSpellIds[userSpellId][useExact][followoverride] = effectiveSpellId
      self:AddEffectiveSpellId(effectiveSpellId, userSpellId)
    end,

    SendEventsForSpell = function(self, effectiveSpellId, event, ...)
      local watchedSpells = self.data[effectiveSpellId] and self.data[effectiveSpellId].watched
      Private.ScanEventsByID(event, effectiveSpellId, ...)
      if watchedSpells then
        for userSpellId in pairs(watchedSpells) do
          if userSpellId ~= effectiveSpellId then
            Private.ScanEventsByID(event, userSpellId, ...)
          end
        end
      end
    end,

    GetSpellCharges = function(self, effectiveSpellId, ignoreSpellKnown)
      if C_Secrets.ShouldSpellCooldownBeSecret(effectiveSpellId) then
        if not ignoreSpellKnown and not WeakAuras.IsSpellKnownIncludingPet(effectiveSpellId) then return end
        local cooldown = Private.GetSpellCooldownData(effectiveSpellId, nil, nil, nil, chargesScratch)
        if cooldown then return cooldown.charges, cooldown.maxCharges, cooldown.count end
        return
      end
      local spellDetail = self.data[effectiveSpellId]
      if not spellDetail then
        return
      end

      if not spellDetail.known and not ignoreSpellKnown then
        return
      end
      return spellDetail.charges, spellDetail.chargesMax, spellDetail.count, spellDetail.chargeGainTime, spellDetail.chargeLostTime
    end,

    GetSpellCooldown = function(self, effectiveSpellId, ignoreRuneCD, showgcd, ignoreSpellKnown, track)
      if C_Secrets.ShouldSpellCooldownBeSecret(effectiveSpellId) then return end
      if (not (self.data[effectiveSpellId] and self.data[effectiveSpellId].known) and not ignoreSpellKnown) then
        return;
      end
      local startTime, duration, paused, gcdCooldown, readyTime, modRate
      if track == "charges" then
        startTime, duration, paused, readyTime, modRate = self.spellCdsCharges:FetchSpellCooldown(effectiveSpellId)
      elseif track == "cooldown" then
        if ignoreRuneCD then
          startTime, duration, paused, readyTime, modRate = self.spellCdsOnlyCooldownRune:FetchSpellCooldown(effectiveSpellId)
        else
          startTime, duration, paused, readyTime, modRate = self.spellCdsOnlyCooldown:FetchSpellCooldown(effectiveSpellId)
        end
      elseif (ignoreRuneCD) then
        startTime, duration, paused, readyTime, modRate = self.spellCdsRune:FetchSpellCooldown(effectiveSpellId)
      else
        startTime, duration, paused, readyTime, modRate = self.spellCds:FetchSpellCooldown(effectiveSpellId)
      end

      if paused then
        return startTime, duration, false, readyTime, modRate, true
      end

      if (showgcd) then
        -- An explicitly requested GCD can use this spell's public timer when the
        -- shared GCD clock is unavailable. Do not replace a longer charge recharge.
        if Private.IsSpellCooldownGCD(effectiveSpellId) == true then
          local info = C_Spell.GetSpellCooldown(effectiveSpellId)
          if info and not hasanysecretvalues(info.startTime, info.duration, info.modRate)
             and info.startTime + info.duration > startTime + duration then
            gcdCooldown = startTime == 0
            startTime, duration, modRate = info.startTime, info.duration, info.modRate
          end
        end
        if ((gcdStart or 0) + (gcdDuration or 0) > startTime + duration) then
          if startTime == 0 then
            gcdCooldown = true
          end
          startTime = gcdStart;
          duration = gcdDuration;
          modRate = gcdModrate
        end
      end

      return startTime, duration, gcdCooldown, readyTime, modRate, false
    end
  }
  SpellDetails.cdHandlers = {SpellDetails.spellCds, SpellDetails.spellCdsRune, SpellDetails.spellCdsOnlyCooldown,
    SpellDetails.spellCdsOnlyCooldownRune, SpellDetails.spellCdsCharges}
  function SpellDetails:CheckSecretCooldownsOnGCD(except)
    for id in pairs(secretPolled) do
      if id ~= except and self.data[id] and Private.GetSpellCooldownGCDFlag(id) == true then
        self:CheckSpellCooldown(id)
      end
    end
  end

  -- Milliseconds of spell cooldown checks per frame for a full check that a
  -- restriction change requested (markSpread; SpellDetails.CheckSpellCooldowns).
  local FULL_CHECK_BUDGET = 3
  -- A restriction change flips every watched spell at once, and the client
  -- sends cooldown and usability events in the same frame that requested the
  -- same full check unspread. Updating every cooldown icon in the frame of
  -- the flip was a visible hitch (the client's own cost, not Lua), so for a
  -- short while after a restriction change every full check is spread: at
  -- most FULL_CHECK_SPELLS spells (and their display updates) per frame,
  -- starting the frame after the request. A spell with an event of its own
  -- (a cast) is still checked at once.
  local FULL_CHECK_SPELLS = 4
  local SPREAD_WINDOW = 1
  local spreadUntil, spreadRequestedAt = 0, nil
  local markSpread
  local mark_ACTIONBAR_UPDATE_COOLDOWN, mark_PLAYER_ENTERING_WORLD
  -- Full cooldown checks requested by events are run once, from this frame's
  -- OnUpdate (after all of the frame's events). Entering or leaving combat
  -- fires several of them in one frame (restriction change, usability and
  -- cooldown updates), and each full check re-reads every watched spell and
  -- item and refreshes every GCD watcher. markQuiet is true while every
  -- pending request was a quiet one (SPELL_UPDATE_USABLE), false otherwise.
  local markQuiet

  ---@type fun()
  function Private.InitCooldownReady()
    ---@class CooldownReadyFrame : FrameScriptObject
    cdReadyFrame = CreateFrame("Frame");
    cdReadyFrame.inWorld = 0
    Private.frames["Cooldown Trigger Handler"] = cdReadyFrame
    do
      cdReadyFrame:RegisterEvent("RUNE_POWER_UPDATE");
      cdReadyFrame:RegisterEvent("PLAYER_TALENT_UPDATE");
      cdReadyFrame:RegisterEvent("PLAYER_PVP_TALENT_UPDATE");
    end
    cdReadyFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN");
    cdReadyFrame:RegisterEvent("SPELL_UPDATE_CHARGES");
    cdReadyFrame:RegisterEvent("LOSS_OF_CONTROL_ADDED");
    cdReadyFrame:RegisterEvent("LOSS_OF_CONTROL_UPDATE");
    cdReadyFrame:RegisterEvent("SPELL_UPDATE_USABLE")
    cdReadyFrame:RegisterEvent("UNIT_SPELLCAST_SENT");
    cdReadyFrame:RegisterEvent("BAG_UPDATE_DELAYED");
    cdReadyFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    cdReadyFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
    cdReadyFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN");
    cdReadyFrame:RegisterEvent("SPELLS_CHANGED");
    cdReadyFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
    cdReadyFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
    
    Private.callbacks:RegisterCallback("WA_SECRET_STATE_UPDATE", function()
      cdReadyFrame:HandleEvent("WA_SECRET_STATE_UPDATE")
    end)

    cdReadyFrame.HandleEvent = function(self, event, ...)
      -- Cooldown state reported by this event supersedes anything read earlier in the frame.
      if type(event) == "string" and Private.InvalidateSpellCooldownCache then Private.InvalidateSpellCooldownCache() end
      if event == "SPELL_UPDATE_USABLE" and C_Secrets.ShouldSpellCooldownBeSecret(61304) then return end
      if event == "SPELL_UPDATE_COOLDOWN" then
        -- Several events in one frame read the same cooldowns: once is enough.
        local now = GetTime()
        if cdReadyFrame.gcdFlagsAt ~= now then
          cdReadyFrame.gcdFlagsAt = now
          for id in pairs(SpellDetails.data) do
            Private.UpdateSpellCooldownGCD(id)
          end
        end
      elseif event == "PLAYER_LEAVING_WORLD" then
        Private.ClearSpellCooldownGCD()
      end
      if (event == "PLAYER_ENTERING_WORLD") then
        cdReadyFrame.inWorld = GetTime()
      end
      if (event == "PLAYER_LEAVING_WORLD") then
        cdReadyFrame.inWorld = nil
      end
      if not cdReadyFrame.inWorld then
        return
      end

      if GetTime() - cdReadyFrame.inWorld < 2 then
        mark_PLAYER_ENTERING_WORLD = true
        cdReadyFrame:Show()
        return
      end
      if (event == "ACTIONBAR_UPDATE_COOLDOWN") then
        mark_ACTIONBAR_UPDATE_COOLDOWN = true
        markQuiet = false
        cdReadyFrame:Show()
        return
      end

      Private.StartProfileSystem("generictrigger cd tracking");
      if type(event) == "number" then-- Called from OnUpdate!
        if mark_PLAYER_ENTERING_WORLD then
          SpellDetails:CheckSpellKnown()
          Private.CheckCooldownReady()
          Private.CheckItemSlotCooldowns()
          mark_PLAYER_ENTERING_WORLD = nil
          mark_ACTIONBAR_UPDATE_COOLDOWN = nil
          markQuiet = nil
          markSpread = nil
        elseif mark_ACTIONBAR_UPDATE_COOLDOWN then
          SpellDetails.quietSecretCheck = markQuiet or nil
          -- A batch of usability events alone cannot change item cooldowns.
          -- A check requested by a restriction change is spread over frames
          -- (FULL_CHECK_BUDGET): a combat change flips every watched spell at
          -- once, and one frame holding all of them and the triggers they wake
          -- was a visible hitch. The marks stay set, and the frame shown, until
          -- the pass completes.
          if SpellDetails.pendingIds and SpellDetails.pendingQuiet and not markQuiet then SpellDetails.pendingIds = nil end
          -- A spread check starts the frame after it was requested.
          if markSpread and spreadRequestedAt == GetTime() then
            Private.StopProfileSystem("generictrigger cd tracking")
            return
          end
          local done = Private.CheckCooldownReady(nil, markQuiet, markSpread and FULL_CHECK_BUDGET or nil,
            markSpread and FULL_CHECK_SPELLS or nil)
          SpellDetails.quietSecretCheck = nil
          if done then
            mark_ACTIONBAR_UPDATE_COOLDOWN = nil
            markQuiet = nil
            markSpread = nil
          end
        end
      elseif(event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "RUNE_POWER_UPDATE"
        or event == "PLAYER_TALENT_UPDATE" or event == "PLAYER_PVP_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED" or event == "RUNE_TYPE_UPDATE")
        or event == "SPELL_UPDATE_USABLE" or event == "WA_SECRET_STATE_UPDATE"
        or event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE"
      then
        local spellId = nil
        if event == "SPELL_UPDATE_COOLDOWN" then
          local arg1 = ...
          if arg1 and type(arg1) == "number" then
            spellId = arg1

          end
          mark_ACTIONBAR_UPDATE_COOLDOWN = nil
        end
        if spellId and not SpellDetails.data[spellId] then spellId = nil end
        local quiet = event == "SPELL_UPDATE_USABLE"
        if spellId == nil and event ~= "PLAYER_TALENT_UPDATE" and event ~= "PLAYER_PVP_TALENT_UPDATE"
          and event ~= "CHARACTER_POINTS_CHANGED" then
          -- A full check: run it once, from this frame's OnUpdate.
          mark_ACTIONBAR_UPDATE_COOLDOWN = true
          if markQuiet == nil then markQuiet = quiet else markQuiet = markQuiet and quiet end
          -- A restriction change flips every watched spell: that check may be
          -- spread over frames. Other full checks (a cast, a wand shot) stay
          -- in their frame, as the displays built on them expect.
          if event == "WA_SECRET_STATE_UPDATE" then spreadUntil = GetTime() + SPREAD_WINDOW end
          if GetTime() < spreadUntil then
            if not markSpread then spreadRequestedAt = GetTime() end
            markSpread = true
          end
          Private.StopProfileSystem("generictrigger cd tracking")
          cdReadyFrame:Show()
          return
        end
        SpellDetails.quietSecretCheck = quiet or nil
        Private.CheckCooldownReady(spellId)
        if spellId then
          SpellDetails.quietSecretCheck = true
          SpellDetails:CheckSecretCooldownsOnGCD(spellId)
          -- Spells sharing its cooldown (Earth and Flame Shock) get no event of
          -- their own: check every spell once, on the next frame.
          mark_ACTIONBAR_UPDATE_COOLDOWN = true
          markQuiet = false
        end
        SpellDetails.quietSecretCheck = nil
      elseif(event == "SPELLS_CHANGED") then
        SpellDetails:CheckSpellKnown()
        Private.CheckCooldownReady()
      elseif(event == "UNIT_SPELLCAST_SENT") then
        local unit, guid, castGUID, name = ...;
        if(unit == "player") then
          name = Private.ExecEnv.GetSpellName(name);
          if(gcdSpellName ~= name) then
            local icon = Private.ExecEnv.GetSpellIcon(name);
            gcdSpellName = name;
            gcdSpellIcon = icon;
            if not WeakAuras.IsPaused() then
              Private.ScanEvents("GCD_UPDATE")
            end
          end
        end
      elseif(event == "UNIT_INVENTORY_CHANGED" or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED") then
        Private.CheckItemSlotCooldowns();
      end
      Private.StopProfileSystem("generictrigger cd tracking");
      if mark_PLAYER_ENTERING_WORLD == nil and mark_ACTIONBAR_UPDATE_COOLDOWN == nil then
        cdReadyFrame:Hide()
      else
        cdReadyFrame:Show()
      end
    end
    cdReadyFrame:Hide()
    cdReadyFrame:SetScript("OnEvent", cdReadyFrame.HandleEvent)
    cdReadyFrame:SetScript("OnUpdate", cdReadyFrame.HandleEvent)
  end

  ---@param id number
  ---@return number cooldownStart
  ---@return number cooldownDuration
  function WeakAuras.GetRuneCooldown(id)
    if(runes[id] and runeCdExps[id] and runeCdDurs[id]) then
      return runeCdExps[id] - runeCdDurs[id], runeCdDurs[id];
    else
      return 0, 0;
    end
  end

  local initEssenceCooldown = false
  local essenceCache = {{},{},{},{},{},{}}
  ---@private
  function WeakAuras.InitEssenceCooldown()
    if initEssenceCooldown then
      return true
    end
    local EssenceEnum = Enum.PowerType.Essence
    local lastFullValue = 0
    local lastTime = 0
    local essenceEventFrame = CreateFrame("Frame")
    essenceEventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    essenceEventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    essenceEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    essenceEventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
    local essenceEventHandler = function(self, event, unitTarget, powerType)
      if powerType and powerType ~= "ESSENCE" then
        return
      end
      local now = GetTime()
      if lastTime == now then
        return
      end
      Private.StartProfileSystem("generictrigger essence")
      local power = UnitPower("player", EssenceEnum)
      local total = UnitPowerMax("player", EssenceEnum)
      local peace = GetPowerRegenForPowerType(EssenceEnum)
      if peace == nil or issecretvalue(peace) or peace == 0 then
        peace = 0.2
      end
      local duration = 1 / peace
      local partial = UnitPartialPower("player", EssenceEnum) / 1000

      if (partial == 0) then
        lastFullValue = now
      elseif power ~= total then
        -- UnitPartialPower is a rather poor api, which returns incorrect values
        -- This almost mirrors what the default ui does, in that the default ui
        -- starts an animation and only uses UnitPartialPower when that animation's
        -- progress differs from UnitPartialPower by 0.1
        -- This here uses a similar logic. We sync whenever partial is 0
        -- and then estimate based on that. And as long as that
        -- estimate is within 0.1 of UnitPartialPower we prefer the estimate
        local estimatedPartial = (now - lastFullValue) / duration
        estimatedPartial = estimatedPartial - floor(estimatedPartial)
        if abs(estimatedPartial - partial) < 0.1 then
          partial = estimatedPartial
        end
      end
      for i = 1, 6 do
        local essence = essenceCache[i]
        if i > total then
          essence.duration = nil
          essence.expirationTime = nil
          essence.remaining = nil
          essence.paused = nil
        elseif power >= i then
          essence.duration = duration
          essence.expirationTime = math.huge
          essence.remaining = 0
          essence.paused = true
        elseif power + 1 == i then
          essence.duration = duration
          essence.expirationTime = GetTime() + (1 - partial) * duration
          essence.paused = false
        else
          essence.duration = duration
          essence.expirationTime = GetTime() + (1 - partial) * duration + (i - 1 - power) * duration
          essence.remaining = duration
          essence.paused = false
        end
      end
      lastTime = now
      Private.StopProfileSystem("generictrigger essence")
      Private.ScanEvents("ESSENCE_UPDATE")
    end
    essenceEventFrame:SetScript("OnEvent", essenceEventHandler)
    essenceEventFrame:Show()

    essenceEventHandler()
    initEssenceCooldown = true
  end

  ---@param essence? number
  ---@return number|nil duration
  ---@return number|nil expirationTime
  ---@return number|nil remaining
  ---@return boolean|nil paused
  ---@return number|nil power
  ---@return number|nil total
  function WeakAuras.GetEssenceCooldown(essence)
    local power = UnitPower("player", Enum.PowerType.Essence)
    local total = UnitPowerMax("player", Enum.PowerType.Essence)
    if essence then
      local cache = essenceCache[essence]
      if cache and essence <= total then
        return cache.duration, cache.expirationTime, cache.remaining, cache.paused, power, total
      else
        return nil, nil, nil, nil, essence, total
      end
    else
      local cache = essenceCache[total]
      if cache and cache.duration then
        return total * cache.duration, cache.expirationTime, cache.remaining, cache.paused, power, total
      else
        return nil, nil, nil, nil, power, total
      end
    end
  end

  ---@param identifier string | number
  ---@return number? startTime, number? duration
  function WeakAuras.GetSpellLossOfControlCooldown(identifier)
    local info = C_Spell.GetSpellLossOfControlCooldownInfo(identifier)
    if info then return info.startTime, info.duration end
  end

  ---@param id string
  ---@param ignoreRuneCD boolean
  ---@param showgcd boolean
  ---@param ignoreSpellKnown boolean
  ---@param track boolean
  ---@return number? startTime
  ---@return number? duration
  ---@return number? gcdCooldown
  ---@return number? readyTime
  ---@return number? modRate
  ---@return boolean? paused
  function WeakAuras.GetSpellCooldown(id, ignoreRuneCD, showgcd, ignoreSpellKnown, track)
    return SpellDetails:GetSpellCooldown(id, ignoreRuneCD, showgcd, ignoreSpellKnown, track)
  end

  ---@param id string
  ---@param ignoreSpellKnown? boolean
  ---@return integer? charges
  ---@return integer? chargesMax
  ---@return integer? count
  ---@return number? chargeGainTime
  ---@return number? chargeLostTime
  function WeakAuras.GetSpellCharges(id, ignoreSpellKnown)
    return SpellDetails:GetSpellCharges(id, ignoreSpellKnown)
  end

  ---@param id string
  ---@param showgcd boolean
  ---@return number startTime
  ---@return number duration
  ---@return boolean enabled
  ---@return number gcdCooldown
  function WeakAuras.GetItemCooldown(id, showgcd)
    local startTime, duration, enabled, gcdCooldown;
    if(items[id] and itemCdExps[id] and itemCdDurs[id]) then
      startTime, duration, enabled = itemCdExps[id] - itemCdDurs[id], itemCdDurs[id], itemCdEnabled[id];
    else
      startTime, duration, enabled = 0, 0, itemCdEnabled[id] or 1;
    end
    if (showgcd) then
      if ((gcdStart or 0) + (gcdDuration or 0) > startTime + duration) then
        if startTime == 0 then
          gcdCooldown = true
        end
        startTime = gcdStart;
        duration = gcdDuration;
      end
    end
    return startTime, duration, enabled, gcdCooldown;
  end

  ---@return number duration
  ---@return number expirationTime
  ---@return string name
  ---@return number|string icon
  ---@return number modrate
  function WeakAuras.GetGCDInfo()
    if(gcdStart) then
      return gcdDuration, gcdStart + gcdDuration, gcdSpellName or "Invalid", gcdSpellIcon or "Interface\\Icons\\INV_Misc_QuestionMark", gcdModrate;
    else
      return 0, math.huge, gcdSpellName or "Invalid", gcdSpellIcon or "Interface\\Icons\\INV_Misc_QuestionMark", 1.0;
    end
  end

  ---@return number duration
  function WeakAuras.gcdDuration()
    return gcdDuration or 0;
  end

  ---@return string name
  function WeakAuras.GcdSpellName()
    return gcdSpellName;
  end

  ---@param id string
  ---@param showgcd boolean
  ---@return number startTime
  ---@return number duration
  ---@return boolean enabled
  ---@return number gcdCooldown
  function WeakAuras.GetItemSlotCooldown(id, showgcd)
    local startTime, duration, enabled, gcdCooldown;
    if(itemSlots[id] and itemSlotsCdExps[id] and itemSlotsCdDurs[id]) then
      startTime, duration, enabled = itemSlotsCdExps[id] - itemSlotsCdDurs[id], itemSlotsCdDurs[id], itemSlotsEnable[id];
    else
      startTime, duration, enabled = 0, 0, itemSlotsEnable[id];
    end

    if (showgcd) then
      if ((gcdStart or 0) + (gcdDuration or 0) > startTime + duration) then
        if startTime == 0 then
          gcdCooldown = true
        end
        startTime = gcdStart;
        duration = gcdDuration;
      end
    end
    return startTime, duration, enabled, gcdCooldown;
  end

  local function RuneCooldownFinished(id)
    runeCdHandles[id] = nil;
    runeCdDurs[id] = nil;
    runeCdExps[id] = nil;
    Private.ScanEvents("RUNE_COOLDOWN_READY", id);
  end

  local function ItemCooldownFinished(id)
    itemCdHandles[id] = nil;
    itemCdDurs[id] = nil;
    itemCdExps[id] = nil;
    itemCdEnabled[id] = 1;
    Private.ScanEventsByID("ITEM_COOLDOWN_READY", id);
  end

  local function ItemSlotCooldownFinished(id)
    itemSlotsCdHandles[id] = nil;
    itemSlotsCdDurs[id] = nil;
    itemSlotsCdExps[id] = nil;
    Private.ScanEventsByID("ITEM_SLOT_COOLDOWN_READY", id);
  end

  ---@type fun()
  ---@return number
  function Private.CheckRuneCooldown()
    local runeDuration = -100;
    for id, _ in pairs(runes) do
      local startTime, duration = GetRuneCooldown(id);
      startTime = startTime or 0;
      duration = duration or 0;
      runeDuration = duration > 0 and duration or runeDuration
      local time = GetTime();

      if(not startTime or startTime == 0) then
        startTime = 0
        duration = 0
      end

      if(duration > 0 and duration ~= WeakAuras.gcdDuration()) then
        -- On non-GCD cooldown
        local endTime = startTime + duration;

        if not(runeCdExps[id]) then
          -- New cooldown
          runeCdDurs[id] = duration;
          runeCdExps[id] = endTime;
          runeCdHandles[id] = timer:ScheduleTimerFixed(RuneCooldownFinished, endTime - time, id);
          Private.ScanEvents("RUNE_COOLDOWN_STARTED", id);
        elseif(runeCdExps[id] ~= endTime) then
          -- Cooldown is now different
          if(runeCdHandles[id]) then
            timer:CancelTimer(runeCdHandles[id]);
          end
          runeCdDurs[id] = duration;
          runeCdExps[id] = endTime;
          runeCdHandles[id] = timer:ScheduleTimerFixed(RuneCooldownFinished, endTime - time, id);
          Private.ScanEvents("RUNE_COOLDOWN_CHANGED", id);
        end
      elseif(duration > 0) then
      -- GCD, do nothing
      else
        if(runeCdExps[id]) then
          -- Somehow CheckCooldownReady caught the rune cooldown before the timer callback
          -- This shouldn't happen, but if it does, no problem
          if(runeCdHandles[id]) then
            timer:CancelTimer(runeCdHandles[id]);
          end
          RuneCooldownFinished(id);
        end
      end
    end
    return runeDuration;
  end

  local GetSpellCharges = GetSpellCharges or function(id)
    local chargeInfo = C_Spell.GetSpellCharges(id)
    if not chargeInfo then return end
    return chargeInfo.currentCharges, chargeInfo.maxCharges, chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate
  end
  local GetSpellCount = GetSpellCount or C_Spell.GetSpellCastCount

  ---@param id string
  ---@param runeDuration? number
  function WeakAuras.GetSpellCooldownUnified(id, runeDuration)
    local startTimeCooldown, durationCooldown, enabled, modRate
    if GetSpellCooldown then
      startTimeCooldown, durationCooldown, enabled, modRate = GetSpellCooldown(id)
      if type(enabled) == "number" then
        enabled = enabled == 1 and true or false
      end
    else
      local spellCooldownInfo = C_Spell.GetSpellCooldown(id);
      if spellCooldownInfo then
        startTimeCooldown = spellCooldownInfo.startTime
        durationCooldown = spellCooldownInfo.duration
        enabled = spellCooldownInfo.isEnabled
        modRate = spellCooldownInfo.modRate
      end
    end

    local charges, maxCharges, startTimeCharges, durationCharges, modRateCharges = GetSpellCharges(id);

    startTimeCooldown = startTimeCooldown or 0
    durationCooldown = durationCooldown or 0

    startTimeCharges = startTimeCharges or 0
    durationCharges = durationCharges or 0
    modRate = modRate or 1.0
    modRateCharges = modRateCharges or 1.0

    -- Default to
    ---@type boolean?
    local unifiedCooldownBecauseRune = false
    ---@type boolean?
    local cooldownBecauseRune = false
    local startTime, duration, unifiedModRate = startTimeCooldown, durationCooldown, modRate

    if not C_Secrets.ShouldSpellCooldownBeSecret(id) then
      -- The shared GCD timer can be restricted even when this spell's times are
      -- readable. Use Blizzard's public flag before caching the spell cooldown;
      -- otherwise Show GCD is effectively forced on when timer equality cannot work.
      -- Charge recharge times stay intact and continue through the normal selection.
      if enabled and Private.IsSpellCooldownGCD(id) == true then
        startTimeCooldown, durationCooldown = 0, 0
        startTime, duration = 0, 0
      end
      -- WORKAROUND: Sometimes the API returns very high bogus numbers causing client freezes, discard them here. CurseForge issue #1008
      if (durationCooldown > 604800) then
        durationCooldown = 0;
        startTimeCooldown = 0;
      end

      if (startTimeCooldown > GetTime() + 2^31 / 1000) then
        -- WORKAROUND: WoW wraps around negative values with 2^32/1000
        -- So if we find a cooldown in the far future, then undo the wrapping
        startTimeCooldown = startTimeCooldown - 2^32 / 1000
      end

      -- Paused cooldowns are:
      -- Spells like Presence of Mind/Nature's Swiftness that start their cooldown after the effect is consumed
      -- But also oddly some Evoker spells
      -- Presence of Might is on 0.0001 enabled == 0 cooldown while prepared
      -- For Evoker, using an empowered spell puts spells on pause. Some spells are put on an entirely bogus 0.5 paused cd
      -- Others the real cd (that continues ticking) is paused.
      -- We treat anything with less than 0.5 as not on cd, and hope for the best.
      if not enabled and durationCooldown <= 0.5 then
        startTimeCooldown, durationCooldown, enabled = 0, 0, true
      end

      local onNonGCDCD = durationCooldown and startTimeCooldown and durationCooldown > 0 and (durationCooldown ~= gcdDuration or startTimeCooldown ~= gcdStart);
      if (onNonGCDCD) then
        cooldownBecauseRune = runeDuration and durationCooldown and abs(durationCooldown - runeDuration) < 0.001;
        unifiedCooldownBecauseRune = cooldownBecauseRune
      end

      if (charges == nil) then
        -- charges is nil if the spell has no charges.
        -- Nothing to do in that case
      elseif (charges == maxCharges) then
        -- At max charges,
        startTime, duration = 0, 0;
        startTimeCharges, durationCharges = 0, 0
      else
        -- Spells can return both information via GetSpellCooldown and GetSpellCharges
        -- E.g. Rune of Power see Github-Issue: #1060
        -- So if GetSpellCooldown returned a cooldown, use that one, if it's a "significant" cooldown
        --  Otherwise check GetSpellCharges
        -- A few abilities have a minor cooldown just to prevent the user from triggering it multiple times,
        -- ignore them since practically no one wants to see them
        if duration and duration <= 1.5 or (duration == gcdDuration and startTime == gcdStart) then
          startTime, duration, unifiedModRate = startTimeCharges, durationCharges, modRateCharges
          unifiedCooldownBecauseRune = false
        end
      end
    end

    local count = GetSpellCount(id)

    local disabled
    if issecretvalue(enabled) then
      disabled = false
    else
      disabled = not enabled
    end

    return charges, maxCharges, startTime, duration, unifiedCooldownBecauseRune,
           startTimeCooldown, durationCooldown, cooldownBecauseRune, startTimeCharges, durationCharges,
           count, unifiedModRate, modRate, modRateCharges, disabled
  end

  ---@type fun(id): boolean|nil
  local queryScratch = {}
  function WeakAuras.IsSpellReady(id)
    local cooldown = Private.GetSpellCooldownData(id, "cooldown", nil, nil, queryScratch)
    return cooldown and cooldown.ready
  end

  function WeakAuras.GetSpellCooldownDuration(id, track)
    local cooldown = Private.GetSpellCooldownData(id, track, true, nil, queryScratch)
    return cooldown and cooldown.duration
  end

  function WeakAuras.GetSpellCooldownDurationNoGCD(id, track)
    local cooldown = Private.GetSpellCooldownData(id, track, false, nil, queryScratch)
    return cooldown and cooldown.duration
  end

  function WeakAuras.IsSpellReadyFromDuration(id)
    local durationObj = C_Spell.GetSpellCooldownDuration(id, true)
    if not durationObj then
      return nil
    end
    return durationObj:IsZero()
  end

  ---@type fun(id, runeDuration)
  function Private.CheckSpellCooldown(id, runeDuration)
    SpellDetails:CheckSpellCooldown(id, runeDuration)
  end

  ---@type fun()
  function Private.CheckItemCooldowns()
    for id, _ in pairs(items) do
      local startTime, duration, enabled = C_Container.GetItemCooldown(id);
      -- TODO: In 10.2.6 the apis return values changed from 1,0 for enabled to true, false
      -- We should adjust once its on all versions
      if enabled == false then
        enabled = 0
      elseif enabled == true then
        enabled = 1
      end
      if (duration == 0) then
        enabled = 1;
      end
      if (enabled == 0) then
        startTime, duration = 0, 0
      end

      local itemCdEnabledChanged = (itemCdEnabled[id] ~= enabled);
      itemCdEnabled[id] = enabled;
      startTime = startTime or 0;
      duration = duration or 0;
      local time = GetTime();

      -- We check against 1.5 and gcdDuration, as apparently the durations might not match exactly.
      -- But there shouldn't be any trinket with a actual cd of less than 1.5 anyway
      if(duration > 0 and duration > 1.5 and duration ~= WeakAuras.gcdDuration()) then
        -- On non-GCD cooldown
        local endTime = startTime + duration;

        if not(itemCdExps[id]) then
          -- New cooldown
          itemCdDurs[id] = duration;
          itemCdExps[id] = endTime;
          itemCdHandles[id] = timer:ScheduleTimerFixed(ItemCooldownFinished, endTime - time, id);
          if not WeakAuras.IsPaused() then
            Private.ScanEventsByID("ITEM_COOLDOWN_STARTED", id)
          end
          itemCdEnabledChanged = false;
        elseif(itemCdExps[id] ~= endTime) then
          -- Cooldown is now different
          if(itemCdHandles[id]) then
            timer:CancelTimer(itemCdHandles[id]);
          end
          itemCdDurs[id] = duration;
          itemCdExps[id] = endTime;
          itemCdHandles[id] = timer:ScheduleTimerFixed(ItemCooldownFinished, endTime - time, id);
          if not WeakAuras.IsPaused() then
            Private.ScanEventsByID("ITEM_COOLDOWN_CHANGED", id)
          end
          itemCdEnabledChanged = false;
        end
      elseif(duration > 0) then
      -- GCD, do nothing
      else
        if(itemCdExps[id]) then
          -- Somehow CheckCooldownReady caught the item cooldown before the timer callback
          -- This shouldn't happen, but if it does, no problem
          if(itemCdHandles[id]) then
            timer:CancelTimer(itemCdHandles[id]);
          end
          ItemCooldownFinished(id);
          itemCdEnabledChanged = false;
        end
      end
      if (itemCdEnabledChanged and not WeakAuras.IsPaused()) then
        Private.ScanEventsByID("ITEM_COOLDOWN_CHANGED", id);
      end
    end
  end

  ---@type fun()
  function Private.CheckItemSlotCooldowns()
    for id, itemId in pairs(itemSlots) do
      if itemId == true then
        itemId = GetInventoryItemID("player", id);
        itemSlots[id] = itemId or true;
      end
      local startTime, duration, enable = GetInventoryItemCooldown("player", id);
      itemSlotsEnable[id] = enable;
      startTime = startTime or 0;
      duration = duration or 0;
      local time = GetTime();

      -- We check against 1.5 and gcdDuration, as apparently the durations might not match exactly.
      -- But there shouldn't be any trinket with a actual cd of less than 1.5 anyway
      if(duration > 0 and duration > 1.5 and duration ~= WeakAuras.gcdDuration()) then
        -- On non-GCD cooldown
        local endTime = startTime + duration;

        if not(itemSlotsCdExps[id]) then
          -- New cooldown
          itemSlotsCdDurs[id] = duration;
          itemSlotsCdExps[id] = endTime;
          itemSlotsCdHandles[id] = timer:ScheduleTimerFixed(ItemSlotCooldownFinished, endTime - time, id);
          if not WeakAuras.IsPaused() then
            Private.ScanEventsByID("ITEM_SLOT_COOLDOWN_STARTED", id)
          end
        elseif(itemSlotsCdExps[id] ~= endTime) then
          -- Cooldown is now different
          if(itemSlotsCdHandles[id]) then
            timer:CancelTimer(itemSlotsCdHandles[id]);
          end
          itemSlotsCdDurs[id] = duration;
          itemSlotsCdExps[id] = endTime;
          itemSlotsCdHandles[id] = timer:ScheduleTimerFixed(ItemSlotCooldownFinished, endTime - time, id);
          if not WeakAuras.IsPaused() then
            Private.ScanEventsByID("ITEM_SLOT_COOLDOWN_CHANGED", id)
          end
        end
      elseif(duration > 0) then
      -- GCD, do nothing
      else
        if(itemSlotsCdExps[id]) then
          -- Somehow CheckCooldownReady caught the item cooldown before the timer callback
          -- This shouldn't happen, but if it does, no problem
          if(itemSlotsCdHandles[id]) then
            timer:CancelTimer(itemSlotsCdHandles[id]);
          end
          ItemSlotCooldownFinished(id);
        end
      end

      local newItemId = GetInventoryItemID("player", id);
      if (itemId ~= newItemId) then
        if not WeakAuras.IsPaused() then
          Private.ScanEventsByID("ITEM_SLOT_COOLDOWN_ITEM_CHANGED", id)
        end
        itemSlots[id] = newItemId or 0;
      end
    end
  end

  -- A GCD event found by a budgeted pass that did not finish; sent when it does.
  local pendingGcdEvent
  ---@type fun(spell: number|string?, skipItems: boolean?, budget: number?): boolean
  function Private.CheckCooldownReady(spell, skipItems, budget, maxSpells)
    -- Refresh the shared clock first, but do not let GCD listeners read the old
    -- per-spell cache and momentarily blank the swipe before this batch completes.
    local gcdEvent = CheckGCD(true);
    local runeDuration = Private.CheckRuneCooldown();
    if spell then
      if SpellDetails.data[spell] then
        SpellDetails:CheckSpellCooldown(spell, runeDuration)
      end
    else
      -- budget: milliseconds for this frame's share of the spells; the pass
      -- continues on the next call and nothing below runs before it is done.
      if gcdEvent then pendingGcdEvent = gcdEvent end
      if not SpellDetails:CheckSpellCooldowns(runeDuration, budget, maxSpells) then return false end
      gcdEvent, pendingGcdEvent = pendingGcdEvent, nil
      -- skipItems: the batch held only spell usability events (see HandleEvent).
      if not skipItems then
        Private.CheckItemCooldowns();
        Private.CheckItemSlotCooldowns();
      end
    end
    -- Refresh watched GCD timers even when the shared GCD clock emits no event
    -- (it reports nothing while restricted), but not after a quiet pass: a
    -- batch of usability events (mana changes) starts no global cooldown, and
    -- waking every icon that shows the GCD for it cost several milliseconds
    -- many times per fight.
    if not WeakAuras.IsPaused() and (gcdEvent or not skipItems) then Private.ScanEvents(gcdEvent or "GCD_UPDATE") end
    return true
  end

  ---@private
  function WeakAuras.WatchGCD()
    if not(cdReadyFrame) then
      Private.InitCooldownReady();
    end
  end

  -- The Global Cooldown trigger ends itself. Its state is re-read only on the
  -- shared GCD clock's events, and that clock (GCD_REFERENCE_SPELL above)
  -- never runs on this client, while the GCD_UPDATE refresh it used to lean on
  -- is now sent only when a cooldown check changed something. So a display
  -- that went active on a GCD stayed active (greyed, say) after the GCD ran
  -- out. With readable timing one scan is scheduled for the end; while the
  -- timing is restricted the public active flag of the reference spell is
  -- polled ten times a second until it clears. Only the Global Cooldown
  -- trigger listens to the scan, so no "Show GCD" icon is refreshed by it.
  local gcdEndPoll
  function Private.ExecEnv.ScheduleGCDEnd(info)
    if not info then return end
    local startTime, duration = info.startTime, info.duration
    if not hasanysecretvalues(startTime, duration) and type(duration) == "number" and duration > 0 then
      Private.ExecEnv.ScheduleScan(startTime + duration, "FA_GCD_RECHECK")
    elseif not gcdEndPoll then
      gcdEndPoll = C_Timer.NewTicker(0.1, function()
        local current = C_Spell.GetSpellCooldown(29515)
        local active = current and current.isActive
        if issecretvalue(active) or active ~= true then
          gcdEndPoll:Cancel()
          gcdEndPoll = nil
          if not WeakAuras.IsPaused() then Private.ScanEvents("FA_GCD_RECHECK") end
        end
      end)
    end
  end

  ---@private
  function WeakAuras.WatchRuneCooldown(id)
    if not(cdReadyFrame) then
      Private.InitCooldownReady();
    end

    if not id or id == 0 then return end

    if not(runes[id]) then
      runes[id] = true;
      local startTime, duration = GetRuneCooldown(id);

      if(not startTime or startTime == 0) then
        startTime = 0
        duration = 0
      end

      if(duration > 0 and duration ~= WeakAuras.gcdDuration()) then
        local time = GetTime();
        local endTime = startTime + duration;
        runeCdDurs[id] = duration;
        runeCdExps[id] = endTime;
        if not(runeCdHandles[id]) then
          runeCdHandles[id] = timer:ScheduleTimerFixed(RuneCooldownFinished, endTime - time, id);
        end
      end
    end
  end

  local GetOverrideSpell
  do
    GetOverrideSpell = FindSpellOverrideByID
  end

  function Private.ExecEnv.GetEffectiveSpellId(spellId, exactMatch, followoverride)
    if type(spellId) == "string" then
      spellId = select(7, Private.ExecEnv.GetSpellInfo(spellId))
    end
    if not exactMatch then
      local spellName = Private.ExecEnv.GetSpellName(spellId or "")
      if spellName then
        local spellIdForName = select(7, Private.ExecEnv.GetSpellInfo(spellName))
        if spellIdForName then
          spellId = spellIdForName
        end
      end
    end
    if followoverride then
      local override = spellId and GetOverrideSpell(spellId)
      if override then
        spellId = override
      end
    end

    return spellId
  end

  ---@private
  function WeakAuras.WatchSpellCooldown(id, ignoreRunes, useExact, followoverride)
    SpellDetails:WatchSpellCooldown(id, ignoreRunes, useExact, followoverride)
  end

  ---@private
  function WeakAuras.WatchItemCooldown(id)
    if not(cdReadyFrame) then
      Private.InitCooldownReady();
    end

    if not id or id == 0 then return end

    if not(items[id]) then
      items[id] = true;
      -- TODO: In 10.2.6 the apis return values changed from 1,0 for enabled to true, false
      -- We should adjust once its on all versions
      local startTime, duration, enabled = C_Container.GetItemCooldown(id);
      if (duration == 0) then
        enabled = 1;
      end
      if (enabled == 0) then
        startTime, duration = 0, 0
      end
      itemCdEnabled[id] = enabled;
      if(duration and duration > 0 and duration > 1.5 and duration ~= WeakAuras.gcdDuration()) then
        local time = GetTime();
        local endTime = startTime + duration;
        itemCdDurs[id] = duration;
        itemCdExps[id] = endTime;
        if not(itemCdHandles[id]) then
          itemCdHandles[id] = timer:ScheduleTimerFixed(ItemCooldownFinished, endTime - time, id);
        end
      end
    end
  end

  ---@private
  function WeakAuras.WatchItemSlotCooldown(id)
    if not(cdReadyFrame) then
      Private.InitCooldownReady();
    end

    if not id or id == 0 then return end

    if not(itemSlots[id]) then
      itemSlots[id] = GetInventoryItemID("player", id) or true;
      local startTime, duration, enable = GetInventoryItemCooldown("player", id);
      itemSlotsEnable[id] = enable;
      if(duration > 0 and duration > 1.5 and duration ~= WeakAuras.gcdDuration()) then
        local time = GetTime();
        local endTime = startTime + duration;
        itemSlotsCdDurs[id] = duration;
        itemSlotsCdExps[id] = endTime;
        if not(itemSlotsCdHandles[id]) then
          itemSlotsCdHandles[id] = timer:ScheduleTimerFixed(ItemSlotCooldownFinished, endTime - time, id);
        end
      end
    end
  end
end

do
  local spellActivationSpells = {};
  local spellActivationSpellsCurrent = {};
  local spellActivationFrame;
  local function InitSpellActivation()
    spellActivationFrame = CreateFrame("Frame");
    Private.frames["Spell Activation"] = spellActivationFrame;
    spellActivationFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW");
    spellActivationFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE");
    spellActivationFrame:SetScript("OnEvent", function(self, event, spell)
      Private.StartProfileSystem("generictrigger spell activation");
      local spellName = Private.ExecEnv.GetSpellName(spell)
      if (spellActivationSpells[spell] or spellActivationSpells[spellName]) then
        local active = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        spellActivationSpellsCurrent[spell] = active
        spellActivationSpellsCurrent[spellName] = active
        if not WeakAuras.IsPaused() then
          Private.ScanEventsByID("WA_UPDATE_OVERLAY_GLOW", spell)
          Private.ScanEventsByID("WA_UPDATE_OVERLAY_GLOW", spellName)
        end
      end

      Private.StopProfileSystem("generictrigger spell activation");
    end);
  end

  ---@private
  function WeakAuras.WatchSpellActivation(id)
    if (not id) then
      return;
    end
    if (not spellActivationFrame) then
      InitSpellActivation();
    end
    spellActivationSpells[id] = true;
  end

  ---@param id string
  ---@return boolean overlayGlowActive
  function WeakAuras.SpellActivationActive(id)
    return spellActivationSpellsCurrent[id];
  end
end

local watchUnitChange

-- Nameplates only distinguish between friends and everyone else
---@param unit UnitToken
---@return string? reaction
function WeakAuras.GetPlayerReaction(unit)
  local r = UnitReaction("player", unit)
  if r then
    return r < 5 and "hostile" or "friendly"
  end
end

---@param unit UnitToken
function WeakAuras.WatchUnitChange(unit)
  unit = string.lower(unit)
  if not watchUnitChange then
    ---@class UnitChangeFrame: FrameScriptObject
    watchUnitChange = CreateFrame("Frame");
    watchUnitChange.trackedUnits = {}
    watchUnitChange.unitIdToGUID = {}
    -- Units whose GUID is currently secret (see unitUpdate).
    watchUnitChange.secretGUID = {}
    watchUnitChange.GUIDToUnitIds = {}
    watchUnitChange.unitExists = {}
    watchUnitChange.unitRoles = {}
    watchUnitChange.unitRaidRole = {}
    watchUnitChange.inRaid = IsInRaid()
    watchUnitChange.nameplateFaction = {}
    watchUnitChange.raidmark = {}
    watchUnitChange.unitIsUnit = {}

    Private.frames["Unit Change Frame"] = watchUnitChange;
    watchUnitChange:RegisterEvent("PLAYER_TARGET_CHANGED")
    do
      watchUnitChange:RegisterEvent("PLAYER_FOCUS_CHANGED")
      watchUnitChange:RegisterEvent("ARENA_OPPONENT_UPDATE")
    end
    watchUnitChange:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    watchUnitChange:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
    watchUnitChange:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED")
    watchUnitChange:RegisterEvent("UNIT_TARGET");
    watchUnitChange:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");
    watchUnitChange:RegisterEvent("GROUP_ROSTER_UPDATE");
    watchUnitChange:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    watchUnitChange:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    watchUnitChange:RegisterEvent("UNIT_FACTION")
    watchUnitChange:RegisterEvent("PLAYER_ENTERING_WORLD")
    watchUnitChange:RegisterEvent("UNIT_PET")
    watchUnitChange:RegisterEvent("RAID_TARGET_UPDATE")

    local function unitUpdate(unitA, eventsToSend)
      local oldUnitExists = watchUnitChange.unitExists[unitA]
      local oldGUID = watchUnitChange.unitIdToGUID[unitA]
      local newGUID = WeakAuras.UnitExistsFixed(unitA) and UnitGUID(unitA)
      local unitExists = UnitExists(unitA) -- UnitExistsFixed check both UnitExists and UnitGUID, but in edge cases we are interested in UnitExists
      -- A secret GUID cannot be compared or used as a key. The event that led
      -- here (a target, focus or group change) may have changed the unit, so
      -- report a change and let the triggers evaluate the unit again. Only a
      -- readable GUID is kept for the next comparison.
      if hasanysecretvalues(newGUID, oldGUID, unitExists) then
        eventsToSend["UNIT_CHANGED_" .. unitA] = unitA
        if not issecretvalue(oldGUID) and oldGUID and watchUnitChange.GUIDToUnitIds[oldGUID] then
          watchUnitChange.GUIDToUnitIds[oldGUID][unitA] = nil
          if next(watchUnitChange.GUIDToUnitIds[oldGUID]) == nil then
            watchUnitChange.GUIDToUnitIds[oldGUID] = nil
          end
        end
        -- false keeps the unit listed for PLAYER_ENTERING_WORLD; secretGUID
        -- remembers that it exists behind a secret GUID.
        watchUnitChange.unitIdToGUID[unitA] = not issecretvalue(newGUID) and newGUID or false
        watchUnitChange.secretGUID[unitA] = issecretvalue(newGUID) or nil
        watchUnitChange.unitExists[unitA] = not issecretvalue(unitExists) and unitExists or nil
        return
      end
      if oldGUID ~= newGUID or oldUnitExists ~= unitExists then
        eventsToSend["UNIT_CHANGED_" .. unitA] = unitA
        if watchUnitChange.GUIDToUnitIds[oldGUID] then
          for unitB in pairs(watchUnitChange.GUIDToUnitIds[oldGUID]) do
            if unitA ~= unitB then
              eventsToSend["UNIT_IS_UNIT_CHANGED_" .. unitA .. "_" .. unitB] = unitA
              eventsToSend["UNIT_IS_UNIT_CHANGED_" .. unitB .. "_" .. unitA] = unitB
            end
          end
        end
        if watchUnitChange.GUIDToUnitIds[newGUID] then
          for unitB in pairs(watchUnitChange.GUIDToUnitIds[newGUID]) do
            if unitA ~= unitB then
              eventsToSend["UNIT_IS_UNIT_CHANGED_" .. unitA .. "_" .. unitB] = unitA
              eventsToSend["UNIT_IS_UNIT_CHANGED_" .. unitB .. "_" .. unitA] = unitB
            end
          end
        end
      end
      -- update data
      if oldGUID and watchUnitChange.GUIDToUnitIds[oldGUID] then
        watchUnitChange.GUIDToUnitIds[oldGUID][unitA] = nil
        if next(watchUnitChange.GUIDToUnitIds[oldGUID]) == nil then
          watchUnitChange.GUIDToUnitIds[oldGUID] = nil
        end
      end
      if newGUID then
        watchUnitChange.GUIDToUnitIds[newGUID] = watchUnitChange.GUIDToUnitIds[newGUID] or {}
        watchUnitChange.GUIDToUnitIds[newGUID][unitA] = true
      end
      watchUnitChange.unitIdToGUID[unitA] = newGUID
      watchUnitChange.secretGUID[unitA] = nil
      watchUnitChange.unitExists[unitA] = unitExists
    end

    local function reactionUpdate(unit, eventsToSend)
      local oldReaction = watchUnitChange.nameplateFaction[unit]
      local newReaction = WeakAuras.GetPlayerReaction(unit)
      if oldReaction ~= newReaction then
        eventsToSend["UNIT_CHANGED_" .. unit] = unit
        watchUnitChange.nameplateFaction[unit] = newReaction
      end
    end

    local function reactionInit(unit)
      watchUnitChange.nameplateFaction[unit] = WeakAuras.GetPlayerReaction(unit)
    end

    local function reactionClear(unit)
      watchUnitChange.nameplateFaction[unit] = nil
    end

    local roleUpdate
    
    do
      function roleUpdate(unit, eventsToSend)
        local oldRole = watchUnitChange.unitRoles[unit]
        local newRole = UnitGroupRolesAssigned(unit)
        if oldRole ~= newRole then
          eventsToSend["UNIT_ROLE_CHANGED_" .. unit] = unit
          watchUnitChange.unitRoles[unit] = newRole
        end
      end
    end

    local function handleUnit(unit, eventsToSend, ...)
      if watchUnitChange.trackedUnits[unit] then
        local fn
        for i = 1, select("#", ...) do
          fn = select(i, ...)
          fn(unit, eventsToSend)
        end
      end
    end

    local handleEvent = {
      PLAYER_ENTERING_WORLD = function(_, eventsToSend)
        for unit in pairs(watchUnitChange.unitIdToGUID) do
          handleUnit(unit, eventsToSend, unitUpdate, reactionUpdate)
        end
      end,
      NAME_PLATE_UNIT_ADDED = function(unit, eventsToSend)
        handleUnit(unit, eventsToSend, unitUpdate, reactionInit)
      end,
      NAME_PLATE_UNIT_REMOVED = function(unit, eventsToSend)
        handleUnit(unit, eventsToSend, unitUpdate, reactionClear)
      end,
      INSTANCE_ENCOUNTER_ENGAGE_UNIT = function(_, eventsToSend)
        for i = 1, 10 do
          handleUnit("boss" .. i, eventsToSend, unitUpdate, reactionInit)
          handleUnit("boss" .. i .. "target", eventsToSend, unitUpdate, reactionInit)
        end
      end,
      ARENA_OPPONENT_UPDATE = function(unit, eventsToSend)
        handleUnit(unit, eventsToSend, unitUpdate, reactionInit)
        handleUnit(unit .. "target", eventsToSend, unitUpdate, reactionInit)
      end,
      PLAYER_TARGET_CHANGED = function(_, eventsToSend)
        handleUnit("target", eventsToSend, unitUpdate, reactionInit)
        handleUnit("targettarget", eventsToSend, unitUpdate, reactionInit)
      end,
      PLAYER_FOCUS_CHANGED = function(_, eventsToSend)
        handleUnit("focus", eventsToSend, unitUpdate, reactionInit)
        handleUnit("focustarget", eventsToSend, unitUpdate, reactionInit)
      end,
      PLAYER_SOFT_ENEMY_CHANGED = function(_, eventsToSend)
        handleUnit("softenemy", eventsToSend, unitUpdate, reactionInit)
        handleUnit("softenemytarget", eventsToSend, unitUpdate, reactionInit)
      end,
      PLAYER_SOFT_FRIEND_CHANGED = function(_, eventsToSend)
        handleUnit("softfriend", eventsToSend, unitUpdate, reactionInit)
        handleUnit("softfriendtarget", eventsToSend, unitUpdate, reactionInit)
      end,
      RAID_TARGET_UPDATE = function(_, eventsToSend)
        for unit in pairs(watchUnitChange.raidmark) do
          handleUnit(unit, eventsToSend)
        end
      end,
      UNIT_FACTION = function(unit, eventsToSend)
        handleUnit(unit, eventsToSend, reactionUpdate)
      end,
      UNIT_PET = function(unit, eventsToSend)
        local pet = WeakAuras.unitToPetUnit[unit]
        if pet and watchUnitChange.trackedUnits[pet] then
          eventsToSend["UNIT_CHANGED_" .. pet] = pet
        end
      end,
      PLAYER_ROLES_ASSIGNED = function(_, eventsToSend)
        for unit in pairs(Private.multiUnitUnits.group) do
          handleUnit(unit, eventsToSend, roleUpdate)
        end
      end,
      UNIT_TARGET = function(unit, eventsToSend)
        handleUnit(unit .. "target", eventsToSend, unitUpdate, reactionInit)
      end,
      GROUP_ROSTER_UPDATE = function(_, eventsToSend)
        for unit in pairs(Private.multiUnitUnits.group) do
          handleUnit(unit, eventsToSend, unitUpdate, reactionInit)
        end
        local inRaid = IsInRaid()
        local inRaidChanged = inRaid ~= watchUnitChange.inRaid
        if inRaidChanged then
          for unit in pairs(Private.multiUnitUnits.group) do
            if watchUnitChange.trackedUnits[unit] and (watchUnitChange.unitIdToGUID[unit] or watchUnitChange.secretGUID[unit]) then
              eventsToSend["UNIT_CHANGED_" .. unit] = unit
            end
          end
          watchUnitChange.inRaid = inRaid
        end
      end
    }

    watchUnitChange:SetScript("OnEvent", function(self, event, unit)
      Private.StartProfileSystem("generictrigger unit change");
      local eventsToSend = {}
      handleEvent[event](unit, eventsToSend)
      -- send events
      for event, unit in pairs(eventsToSend) do
        Private.ScanEvents(event, unit)
      end

      Private.StopProfileSystem("generictrigger unit change");
    end)
  end
  if watchUnitChange.trackedUnits[unit] then
    return
  end
  local guid = UnitGUID(unit)
  watchUnitChange.trackedUnits[unit] = true
  -- A secret GUID is not kept: later comparisons with it would stop every
  -- change report for this unit (see unitUpdate).
  local knownGUID = WeakAuras.UnitExistsFixed(unit) and UnitGUID(unit)
  watchUnitChange.unitIdToGUID[unit] = not issecretvalue(knownGUID) and knownGUID or false
  watchUnitChange.secretGUID[unit] = issecretvalue(knownGUID) or nil
  local exists = UnitExists(unit)
  watchUnitChange.unitExists[unit] = not issecretvalue(exists) and exists or nil

  if guid and not issecretvalue(guid) then
    watchUnitChange.GUIDToUnitIds[guid] = watchUnitChange.GUIDToUnitIds[guid] or {}
    watchUnitChange.GUIDToUnitIds[guid][unit] = true
  end
  watchUnitChange.raidmark = watchUnitChange.raidmark or {}
  -- watchUnitChange.raidmark[unit] = GetRaidTargetIndex(unit) or 0
  watchUnitChange.inRaid = IsInRaid()
end

function WeakAuras.GetEquipmentSetInfo(itemSetName, partial)
  local bestMatchNumItems = 0;
  local bestMatchNumEquipped = 0;
  local bestMatchName = nil;
  local bestMatchIcon = nil;

  local equipmentSetIds = C_EquipmentSet.GetEquipmentSetIDs();
  for index, id in pairs(equipmentSetIds) do
    local name, icon, _, _, numItems, numEquipped = C_EquipmentSet.GetEquipmentSetInfo(id);
    if (itemSetName == nil or (name and itemSetName == name)) then
      if (name ~= nil) then
        local match = (not partial and numItems == numEquipped)
          or (partial and (numEquipped or 0) > bestMatchNumEquipped);
        if (match) then
          bestMatchNumEquipped = numEquipped;
          bestMatchNumItems = numItems;
          bestMatchName = name;
          bestMatchIcon = icon;
        end
      end
    end
  end
  return bestMatchName, bestMatchIcon, bestMatchNumEquipped, bestMatchNumItems;
end

-- Workaround Stagger's last tick not resulting in UNIT_ABSORB_AMOUNT_CHANGED
local staggerWatchFrame
function Private.WatchStagger()
  if not staggerWatchFrame then
    staggerWatchFrame = CreateFrame("FRAME")
    Private.frames["ForeverAuras Stagger Frame"] = staggerWatchFrame

    do
      staggerWatchFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
      staggerWatchFrame:SetScript("OnEvent", function()
        Private.StartProfileSystem("stagger")
        local stagger = UnitStagger("player")
        if issecretvalue(stagger) or stagger > 0 then
          if not staggerWatchFrame.onupdate then
            staggerWatchFrame.onupdate = true
            staggerWatchFrame:SetScript("OnUpdate", function()
              Private.StartProfileSystem("stagger")
              local stagger = UnitStagger("player")
              if not issecretvalue(stagger) then
                if stagger ~= staggerWatchFrame.stagger then
                  staggerWatchFrame.stagger = stagger
                  Private.ScanEvents("WA_UNIT_STAGGER_CHANGED", "player", stagger)
                end
                if stagger == 0 then
                  staggerWatchFrame:SetScript("OnUpdate", nil)
                  staggerWatchFrame.onupdate = nil
                end
              end
              Private.StopProfileSystem("stagger")
            end)
          end
        end

        if not issecretvalue(stagger) and stagger ~= staggerWatchFrame.stagger then
          staggerWatchFrame.stagger = stagger
          Private.ScanEvents("WA_UNIT_STAGGER_CHANGED", "player", stagger)
        end
        Private.StopProfileSystem("stagger")
      end)
    end
  end
end

function Private.ExecEnv.CheckTotemName(totemName, triggerTotemName, triggerTotemPattern, triggerTotemOperator)
  if not totemName or totemName == "" then
    return false
  end

  if triggerTotemName and #triggerTotemName > 0 and triggerTotemName ~= totemName then
    return false
  end

  if triggerTotemPattern and #triggerTotemPattern > 0 then
    if triggerTotemOperator == "==" then
      if totemName ~= triggerTotemPattern then
        return false
      end
    elseif triggerTotemOperator == "find('%s')" then
      if not totemName:find(triggerTotemPattern, 1, true) then
        return false
      end
    elseif triggerTotemOperator == "match('%s')" then
      if not totemName:match(triggerTotemPattern) then
        return false
      end
    end
  end

  return true
end

function Private.ExecEnv.CheckTotemIcon(totemIcon, triggerTotemIcon, operator)
  if not triggerTotemIcon then
    return true
  end
  return (totemIcon == triggerTotemIcon) == (operator == "==")
end

function Private.ExecEnv.CheckTotemSpellId(spellId, triggerSpellId, followoverride)
  if not triggerSpellId then
    return true
  end

  if spellId == triggerSpellId then
    return true
  end

  if followoverride then
    if spellId == FindSpellOverrideByID(triggerSpellId) then
      return true
    end
  end

  return false
end

local totemSlots = {}
local lastTotemCast = {time = -math.huge}
local TOTEM_CAST_WINDOW = 0.5

local knownTotemSlots = {}
for slot, families in pairs({
  [1] = {{3599, 6363, 6364, 6365, 10437, 10438}, {8190, 10585, 10586, 10587}, {8227, 8249, 10526, 16387}, {8181, 10478, 10479}},
  [2] = {{8071, 8154, 8155, 10406, 10407, 10408}, {5730, 6390, 6391, 6392, 10427, 10428}, {8075, 8160, 8161, 10442, 25361}, {2484}, {8143}},
  [3] = {{5394, 6375, 6377, 10462, 10463}, {5675, 10495, 10496, 10497}, {16190, 17354, 17359}, {8166}, {8170}, {8184, 10537, 10538}},
  [4] = {{8835, 10627, 25359}, {8177}, {10595, 10600, 10601}, {8512, 10613, 10614}, {15107, 15111, 15112}, {6495}},
}) do
  for _, family in ipairs(families) do
    for _, spellId in ipairs(family) do knownTotemSlots[spellId] = slot end
  end
end

local function LearnedTotemSpells()
  if not Private.db then return end
  Private.db.totemSpells = Private.db.totemSpells or {}
  return Private.db.totemSpells
end

local function LearnedTotemNames()
  if not Private.db then return end
  Private.db.totemNames = Private.db.totemNames or {}
  return Private.db.totemNames
end

local function TotemSlotForSpell(spellId)
  if type(spellId) ~= "number" then return end
  local learned = LearnedTotemSpells()
  local slot = learned and learned[spellId] or knownTotemSlots[spellId]
  if slot then return slot end
  local names = LearnedTotemNames()
  local name = names and Private.ExecEnv.GetSpellName(spellId)
  return name and names[name]
end

local function ReadTotemSlot(slot)
  local haveTotem, name, startTime, duration, icon, modRate, spellId = GetTotemInfo(slot)
  if hasanysecretvalues(haveTotem, name, startTime, duration, icon, modRate, spellId) then return end
  if haveTotem and startTime and startTime ~= 0 then
    totemSlots[slot] = {name = name, icon = icon, spellId = spellId}
    local learned = LearnedTotemSpells()
    if learned and type(spellId) == "number" and spellId > 0 then
      learned[spellId] = slot
      local spellName = Private.ExecEnv.GetSpellName(spellId)
      local names = LearnedTotemNames()
      if names and spellName then names[spellName] = slot end
    end
  else
    totemSlots[slot] = nil
  end
  return true
end

local function UpdateSecretTotemSlot(slot)
  local spellId = lastTotemCast.spellId
  if spellId and TotemSlotForSpell(spellId) == slot and GetTime() - lastTotemCast.time <= TOTEM_CAST_WINDOW then
    totemSlots[slot] = {name = Private.ExecEnv.GetSpellName(spellId), icon = Private.ExecEnv.GetSpellIcon(spellId), spellId = spellId}
    return true
  end
  local changed = totemSlots[slot] ~= nil
  totemSlots[slot] = nil
  return changed
end

local totemFrame = CreateFrame("Frame")
totemFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
totemFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
totemFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
totemFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
totemFrame:SetScript("OnEvent", function(_, event, arg1, _, spellId)
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local public = not issecretvalue(spellId) and type(spellId) == "number"
    lastTotemCast.time, lastTotemCast.spellId = GetTime(), public and spellId or nil
    local slot = public and TotemSlotForSpell(spellId)
    if slot and C_Secrets.ShouldTotemSlotBeSecret(slot) and UpdateSecretTotemSlot(slot) then
      Private.ScanEvents("FA_TOTEM_UPDATE", slot)
    end
  elseif event == "PLAYER_TOTEM_UPDATE" then
    if type(arg1) == "number" and not issecretvalue(arg1) and not ReadTotemSlot(arg1) then
      UpdateSecretTotemSlot(arg1)
    end
    Private.ScanEvents("FA_TOTEM_UPDATE", not issecretvalue(arg1) and arg1 or nil)
  else
    for slot = 1, 5 do
      if not C_Secrets.ShouldTotemSlotBeSecret(slot) then ReadTotemSlot(slot) end
    end
    Private.ScanEvents("FA_TOTEM_UPDATE")
  end
end)

function Private.ExecEnv.GetTotemSlotInfo(slot)
  if not C_Secrets.ShouldTotemSlotBeSecret(slot) and ReadTotemSlot(slot) then
    local _, name, startTime, duration, icon, modRate, spellId = GetTotemInfo(slot)
    return totemSlots[slot] ~= nil, name, startTime, duration, icon, modRate, spellId
  end
  local totem = totemSlots[slot]
  if not totem then return false end
  local ok, durationObject = pcall(GetTotemDuration, slot)
  return true, totem.name, nil, nil, totem.icon, nil, totem.spellId, ok and durationObject or nil
end

function Private.ExecEnv.SetTotemStateTimer(state, startTime, duration, modRate, durationObject)
  if durationObject then
    state.progressType = "durationObject"
    state.durationObject = durationObject
    state.duration, state.expirationTime, state.modRate = nil, nil, nil
  else
    state.progressType = "timed"
    state.durationObject = nil
    state.duration = duration
    state.expirationTime = startTime and (startTime + duration)
    state.modRate = modRate
  end
end

-- Queueable Spells

local GetSpellPowerCost = GetSpellPowerCost or C_Spell and C_Spell.GetSpellPowerCost

---@param powerTypeToCheck integer
---@return number? cost
function WeakAuras.GetSpellCost(powerTypeToCheck)
  local spellID = select(9, WeakAuras.UnitCastingInfo("player"))
  
  if spellID then
    local costTable = GetSpellPowerCost(spellID);
    if costTable then
      for _, costInfo in pairs(costTable) do
        -- When there is no required aura for a power cost, the API returns an aura ID of 0 and false for hasRequiredAura despite being valid.
        if costInfo.type == powerTypeToCheck and (costInfo.requiredAuraID == 0 or costInfo.hasRequiredAura) then
          return costInfo.cost;
        end
      end
    end
  end
end

-- Weapon Enchants
do
  -- One record per hand and enchant kind: "imbue" (Firestone, the mage imbue
  -- scrolls), "temporary" (oils, stones, poisons) and "any", which is the
  -- imbue when both are present, else whichever is there. Forever lets one
  -- weapon carry an imbue and an oil at once, so each kind is tracked on its own.
  local mh = GetInventorySlotInfo("MainHandSlot")
  local oh = GetInventorySlotInfo("SecondaryHandSlot")
  local slots = {main = mh, off = oh}
  local hands = {main = {}, off = {}}
  local weaponIcons = {}

  local tenchFrame = nil
  Private.frames["Temporary Enchant Handler"] = tenchFrame;

  local function WeaponIcon(hand)
    return weaponIcons[hand] or GetInventoryItemTexture("player", slots[hand]) or "Interface\\Icons\\INV_Misc_QuestionMark"
  end

  ---@private
  function WeakAuras.TenchInit()
    if not(tenchFrame) then
      tenchFrame = CreateFrame("Frame");
      tenchFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
      do
        tenchFrame:RegisterEvent("WEAPON_ENCHANT_CHANGED")
      end
      tenchFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
      -- Swapping a weapon must invalidate enchant art and timing together.
      tenchFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

      -- Every enchant line of the weapon's tooltip: name, name without rank,
      -- and the time it shows, so a line can be paired with the API entry
      -- whose remaining time it matches (a weapon may list two).
      local unitSeconds = {s = 1, m = 60, h = 3600, d = 86400}
      local function TenchLines(id)
        local lines = {}
        local tooltipData = C_TooltipInfo.GetInventoryItem("player", id)
        if tooltipData and tooltipData.lines then
          for _, line in ipairs(tooltipData.lines) do
            if line.leftText and not issecretvalue(line.leftText) then
              -- Format based on ITEM_ENCHANT_TIME_LEFT_MIN, ITEM_ENCHANT_TIME_LEFT_SEC
              local _, _, name, shortenedName, time = line.leftText:find("^((.-) ?+?[VI%d]*) ?%((%d+%D.+)%)$");
              if not (name and name ~= "") then
                _, _, name, shortenedName, time = line.leftText:find("^((.-) ?+?[VI%d]*)%（(%d+%D.+)%）$");
              end
              if name and name ~= "" then
                -- The rank pattern leaves a trailing space on unranked names.
                name = name:gsub("%s+$", "")
                local amount, unit = time:match("^(%d+)%s*(%a)")
                local seconds = amount and unitSeconds[(unit or ""):lower()] and tonumber(amount) * unitSeconds[unit:lower()]
                lines[#lines + 1] = {name = name, shortenedName = shortenedName, seconds = seconds}
              end
            end
          end
        end
        return lines
      end

      -- The tooltip line closest in time to the entry; with one line, that line.
      local function NameFor(lines, used, remaining)
        local best, bestDistance
        for index, line in ipairs(lines) do
          if not used[index] then
            local distance = (line.seconds and remaining) and math.abs(line.seconds - remaining / 1000) or math.huge
            if not best or distance < bestDistance then best, bestDistance = index, distance end
          end
        end
        if best then
          used[best] = true
          return lines[best].name, lines[best].shortenedName
        end
      end

      -- The API supplies remaining time, not the original full duration.
      -- Retain the longest readable observation per enchant for this session so
      -- zoning or a temporary empty read cannot restart the swipe at 100%.
      -- This changes only its scale: presence and expiration still come from the API.
      local enchantDurations = {}
      local function ObserveEnchantDuration(enchantID, remaining)
        if not remaining or remaining <= 0 then return nil end
        local duration = remaining / 1000
        if not enchantID then return duration end
        duration = math.max(enchantDurations[enchantID] or 0, duration)
        enchantDurations[enchantID] = duration
        return duration
      end

      local expiryTimer
      local function tenchUpdate()
        if expiryTimer then expiryTimer:Cancel(); expiryTimer = nil end
        Private.StartProfileSystem("generictrigger temporary enchant");
        local entries = Private.ExecEnv.GetWeaponEnchantEntries()
        -- Do not perform arithmetic or overwrite a readable snapshot with secrets.
        if not entries.readable then
          Private.StopProfileSystem("generictrigger temporary enchant")
          return
        end
        local time = GetTime();
        local nextExpiry
        for hand, slot in pairs(slots) do
          weaponIcons[hand] = GetInventoryItemTexture("player", slot)
          local lines, used = nil, {}
          local records = hands[hand]
          -- Longer-lived enchants are named first: with one line left the
          -- pairing falls back to it, so the better-known entry picks first.
          local kinds = {"imbue", "temporary"}
          local imbue, temporary = entries[hand].imbue, entries[hand].temporary
          if imbue and temporary and (temporary.timeLeft or 0) > (imbue.timeLeft or 0) then kinds = {"temporary", "imbue"} end
          for _, kind in ipairs(kinds) do
            local entry = entries[hand][kind]
            local old = records[kind]
            local exp = entry and entry.timeLeft and (time + entry.timeLeft / 1000)
            if not entry then
              records[kind] = nil
            elseif not old or old.enchantID ~= entry.enchantID or math.abs((old.exp or 0) - (exp or 0)) > 1 then
              lines = lines or TenchLines(slot)
              local name, shortenedName = NameFor(lines, used, entry.timeLeft)
              records[kind] = {
                exp = exp, dur = ObserveEnchantDuration(entry.enchantID, entry.timeLeft),
                name = name or "None", shortenedName = shortenedName or "None",
                icon = entry.enchantIconID and entry.enchantIconID > 0 and entry.enchantIconID or nil,
                charges = entry.charges, enchantID = entry.enchantID,
              }
            else
              -- Unchanged: keep the name, but its line is taken for the other kind.
              lines = lines or TenchLines(slot)
              for index, line in ipairs(lines) do
                if line.name == old.name then used[index] = true break end
              end
            end
            if entry and entry.timeLeft and entry.timeLeft > 0 then
              nextExpiry = math.min(nextExpiry or math.huge, entry.timeLeft / 1000)
            end
          end
          records.any = records.imbue or records.temporary
        end
        -- Re-read once at the earliest expiry, including when no inventory event fires.
        if nextExpiry then expiryTimer = C_Timer.NewTimer(nextExpiry + 0.1, tenchUpdate) end
        Private.ScanEvents("TENCH_UPDATE");
        Private.StopProfileSystem("generictrigger temporary enchant");
      end

      -- Inventory and enchant events can arrive together; retain only one pending read.
      local updatePending
      tenchFrame:SetScript("OnEvent", function()
        if updatePending then return end
        updatePending = true
        timer:ScheduleTimer(function()
          updatePending = nil
          tenchUpdate()
        end, 0.1)
      end);

      tenchUpdate();
    end
  end

  -- A record matches a trigger name when it is the enchant's name, its name
  -- without rank, or its enchant ID.
  local function Matches(record, triggerName)
    if not triggerName or triggerName == "" then return true end
    if not record then return false end
    return triggerName == record.name or triggerName == record.shortenedName
      or (tonumber(triggerName) ~= nil and record.enchantID == tonumber(triggerName))
  end

  -- The enchant to show for a hand: kind "imbue", "temporary" or "any". With
  -- "any" and a name, whichever of the two carries that name.
  local function TenchInfo(hand, kind, triggerName)
    local records = hands[hand]
    local record
    if (kind or "any") == "any" then
      record = records.any
      if triggerName and triggerName ~= "" then
        if Matches(records.imbue, triggerName) then record = records.imbue
        elseif Matches(records.temporary, triggerName) then record = records.temporary end
      end
    else
      record = records[kind]
    end
    if not record then return nil, nil, "None", "None", WeaponIcon(hand), nil, nil end
    return record.exp, record.dur, record.name, record.shortenedName, record.icon or WeaponIcon(hand), record.charges, record.enchantID
  end

  function WeakAuras.GetMHTenchInfo(kind, triggerName)
    return TenchInfo("main", kind, triggerName)
  end

  function WeakAuras.GetOHTenchInfo(kind, triggerName)
    return TenchInfo("off", kind, triggerName)
  end
  ForeverAuras.GetWeaponEnchantInfo = TenchInfo

  function WeakAuras.GetRangeTenchInfo()
    return nil, nil, nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark", nil, nil
  end
end

-- Pets
do
  local petFrame = nil
  Private.frames["Pet Use Handler"] = petFrame;
  ---@private
  function WeakAuras.WatchForPetDeath()
    if not(petFrame) then
      petFrame = CreateFrame("Frame");
      petFrame:RegisterUnitEvent("UNIT_PET", "player")
      petFrame:SetScript("OnEvent", function(event, unit)
        Private.StartProfileSystem("generictrigger pet update")
        Private.ScanEvents("PET_UPDATE", "pet")
        Private.StopProfileSystem("generictrigger pet update")
      end)
    end
  end
end

do
  local watchFrame
  function Private.WatchCOMBO_TARGET_CHANGED()
    if not watchFrame then
      watchFrame = CreateFrame("Frame")
      watchFrame:RegisterEvent("COMBO_TARGET_CHANGED")
      watchFrame:SetScript("OnEvent", function()
        Private.StartProfileSystem("generictrigger COMBO_TARGET_CHANGED")
        Private.ScanEvents("WA_COMBO_TARGET_CHANGED", "player")
        Private.StopProfileSystem("generictrigger COMBO_TARGET_CHANGED")
      end)
    end
  end
end

-- Cast Latency
do
  local castLatencyFrame

  ---@private
  function WeakAuras.WatchForCastLatency()
    if not castLatencyFrame then
      ---@class CastLatencyFrame: FrameScriptObject
      castLatencyFrame = CreateFrame("Frame")
      Private.frames["Cast Latency Handler"] = castLatencyFrame
      castLatencyFrame:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
      castLatencyFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
      castLatencyFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
      castLatencyFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
      castLatencyFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
      castLatencyFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
      castLatencyFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

      -- on dragonflight UNIT_SPELLCAST_EMPOWER_START and UNIT_SPELLCAST_EMPOWER_STOP OnEvent are
      -- triggered from cacheEmpoweredFrame after updating cache use by ForeverAuras.UnitChannelInfo

      castLatencyFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CURRENT_SPELL_CAST_CHANGED" then
          castLatencyFrame.sendTime = GetTime()
          return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
          castLatencyFrame.sendTime = nil
          return
        end

        if castLatencyFrame.sendTime then
          castLatencyFrame.timeDiff = (GetTime() - castLatencyFrame.sendTime)
        else
          castLatencyFrame.timeDiff = nil
        end
      end)
    end
  end

  ---@return number castLatencyF
  function WeakAuras.GetCastLatency()
    return castLatencyFrame and castLatencyFrame.timeDiff or 0
  end

end

do
  local nameplateTargetFrame = nil
  local nameplateTargets = {}

  local function nameplateTargetOnEvent(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
      nameplateTargets[unit] = UnitGUID(unit.."-target") or true
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      nameplateTargets[unit] = nil
    end
  end

  local tick_throttle = 0.2
  local throttle_update = tick_throttle
  local function nameplateTargetOnUpdate(self, delta)
    throttle_update = throttle_update - delta
    if throttle_update < 0 then
      for unit, targetGUID in pairs(nameplateTargets) do
        local newTargetGUID = UnitGUID(unit.."-target")
        if not issecretvalue(newTargetGUID) and
        (
          (newTargetGUID == nil and targetGUID ~= true)
          or (newTargetGUID ~= nil and targetGUID ~= newTargetGUID)
        )
        then
          nameplateTargets[unit] = newTargetGUID or true
          Private.ScanEvents("WA_UNIT_TARGET_NAME_PLATE", unit)
        end
      end
      throttle_update = tick_throttle
    end
  end

  Private.frames["Nameplate Target Handler"] = nameplateTargetFrame
  ---@private
  function WeakAuras.WatchForNameplateTargetChange()
    if not nameplateTargetFrame then
      nameplateTargetFrame = CreateFrame("Frame")
      nameplateTargetFrame:SetScript("OnUpdate", nameplateTargetOnUpdate)
      nameplateTargetFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
      nameplateTargetFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
      nameplateTargetFrame:SetScript("OnEvent", nameplateTargetOnEvent)
    end
  end
end

-- Player Moving
do
  --- @class PlayerMovingFrame
  --- @field moving integer|nil
  --- @field speed integer|nil

  ---@type PlayerMovingFrame|Frame|nil
  local playerMovingFrame = nil

  local function PlayerMoveUpdate()
    Private.StartProfileSystem("generictrigger player moving");
    local moving = IsPlayerMoving()
    if (playerMovingFrame.moving ~= moving or playerMovingFrame.moving == nil) then
      playerMovingFrame.moving = moving
      Private.ScanEvents("PLAYER_MOVING_UPDATE")
    end

    local speed = GetUnitSpeed("player")
    if hasanysecretvalues(playerMovingFrame.speed, speed) or playerMovingFrame.speed ~= speed then
      playerMovingFrame.speed = speed
      Private.ScanEvents("PLAYER_MOVE_SPEED_UPDATE")
    end
    Private.StopProfileSystem("generictrigger player moving");
  end

  ---@private
  function WeakAuras.WatchForPlayerMoving()
    if not(playerMovingFrame) then
      playerMovingFrame = CreateFrame("Frame");
      --- @cast playerMovingFrame PlayerMovingFrame
      Private.frames["Player Moving Frame"] =  playerMovingFrame;
      playerMovingFrame.speed = GetUnitSpeed("player")
    end
    playerMovingFrame:SetScript("OnUpdate", PlayerMoveUpdate)
  end
end

-- combat assist next cast
if C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
  local assistedCombatFrame

  local function assistedCombatUpdate(self, elapsed)
    Private.StartProfileSystem("generictrigger assisted combat next cast")
    local nextCastSpell = C_AssistedCombat.GetNextCastSpell()
    if nextCastSpell ~= assistedCombatFrame.lastSpell then
      assistedCombatFrame.lastSpell = nextCastSpell
      Private.ScanEvents("WA_ASSISTED_COMBAT_NEXT_CAST", nextCastSpell)
    end
    Private.StopProfileSystem("generictrigger assisted combat next cast")
  end

  ---@private
  function WeakAuras.WatchForAssistedCombatNextCast()
    if not assistedCombatFrame then
      assistedCombatFrame = CreateFrame("Frame")
      Private.frames["Assisted Combat Next Cast Frame"] = assistedCombatFrame
      assistedCombatFrame.lastSpell = C_AssistedCombat.GetNextCastSpell()
    end
    assistedCombatFrame:SetScript("OnUpdate", assistedCombatUpdate)
  end
end

-- Item Count
local itemCountWatchFrame
---@private
function WeakAuras.RegisterItemCountWatch()
  if not itemCountWatchFrame then
    itemCountWatchFrame = CreateFrame("Frame")
    itemCountWatchFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    itemCountWatchFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    local batchUpdateCount = function()
      itemCountWatchFrame:SetScript("OnUpdate", nil)
      Private.StartProfileSystem("generictrigger ITEM_COUNT_UPDATE")
      Private.ScanEvents("ITEM_COUNT_UPDATE")
      Private.StopProfileSystem("generictrigger ITEM_COUNT_UPDATE")
    end
    itemCountWatchFrame:SetScript("OnEvent", function(self, event)
      Private.StartProfileSystem("generictrigger itemCountFrame")
      if event == "ACTIONBAR_UPDATE_COOLDOWN" then
        -- WORKAROUND: Blizzard bug: refreshing healthstones from soulwell don't trigger BAG_UPDATE_DELAYED
        -- so, we fake it by listening to A_U_C and checking on next frame
        itemCountWatchFrame:SetScript("OnUpdate", batchUpdateCount)
      else
        -- if we *do* get a B_U_D, then cancel our fake one
        -- item count prototype already subscribes to this event so no need to also send an internal event
        itemCountWatchFrame:SetScript("OnUpdate", nil)
      end
      Private.StopProfileSystem("generictrigger itemCountFrame")
    end)
  end
end

-- LibSpecWrapper
-- We always register, because it's probably not that often called, and ScanEvents checks
-- early if anyone wants the event
do
  Private.LibSpecWrapper.Register(function(unit)
    Private.ScanEvents("UNIT_SPEC_CHANGED_" .. unit, unit)
    WeakAuras.ScanEvents("UNIT_SPEC_CHANGED", unit)
  end)
end

do
  local scheduled_scans = {};

  local function doScan(fireTime, event)
    scheduled_scans[event][fireTime] = nil;
    Private.ScanEvents(event);
  end
  function Private.ExecEnv.ScheduleScan(fireTime, event)
    event = event or "COOLDOWN_REMAINING_CHECK"
    scheduled_scans[event] = scheduled_scans[event] or {}
    if not(scheduled_scans[event][fireTime]) then
      scheduled_scans[event][fireTime] = timer:ScheduleTimerFixed(doScan, fireTime - GetTime() + 0.1, fireTime, event);
    end
  end
end

do
  local scheduled_scans = {};

  local function doCastScan(firetime, unit)
    scheduled_scans[unit][firetime] = nil;
    Private.ScanEvents("CAST_REMAINING_CHECK_" .. string.lower(unit), unit);
  end
  function Private.ExecEnv.ScheduleCastCheck(fireTime, unit)
    scheduled_scans[unit] = scheduled_scans[unit] or {}
    if not(scheduled_scans[unit][fireTime]) then
      scheduled_scans[unit][fireTime] = timer:ScheduleTimerFixed(doCastScan, fireTime - GetTime() + 0.1, fireTime, unit);
    end
  end
end

local uniqueId = 0;
---@return integer cloneId
function WeakAuras.GetUniqueCloneId()
  uniqueId = (uniqueId + 1) % 1000000;
  return uniqueId;
end

---@type fun(trigger: triggerData) : prototypeData?
function GenericTrigger.GetPrototype(trigger)
  if trigger.type and trigger.event then
    if Private.category_event_prototype[trigger.type] then
      return Private.event_prototypes[trigger.event]
    end
  end
end

---@type fun(data: auraData): number?
function GenericTrigger.GetDelay(data)
  if data.event then
    local prototype = GenericTrigger.GetPrototype(data.trigger)
    if prototype and prototype.delayEvents then
      local trigger = data.trigger
      if trigger.use_delay and type(trigger.delay) == "number" and trigger.delay > 0 then
        return trigger.delay
      end
    end
  end
  return 0
end

function GenericTrigger.GetTsuConditionVariables(id, triggernum)
  local ok, variables = xpcall(events[id][triggernum].tsuConditionVariables, Private.GetErrorHandlerId(id, L["Custom Variables"]));
  if ok then
    return variables
  end
end

---Returns a table containing the names of all overlays
---@param data auraData
---@param triggernum number
function GenericTrigger.GetOverlayInfo(data, triggernum)
  local result;

  local trigger = data.triggers[triggernum].trigger

  local prototype = GenericTrigger.GetPrototype(trigger)
  if (prototype and prototype.overlayFuncs) then
    result = {};
    local dest = 1;
    for i, v in ipairs(prototype.overlayFuncs) do
      local enable = true
      if type(v.enable) == "function" then
        enable = v.enable(trigger)
      elseif type(v.enable) == "boolean" then
        enable = v.enable
      end
      if enable then
        result[dest] = v.name;
        dest = dest + 1;
      end
    end
  end

  if (trigger.type == "custom") then
    if (trigger.custom_type == "stateupdate") then
      local count = 0;
      local variables = GenericTrigger.GetTsuConditionVariables(data.id, triggernum)
      if (type(variables) == "table") then
        if (type(variables.additionalProgress) == "table") then
          count = #variables.additionalProgress;
        elseif (type(variables.additionalProgress) == "number") then
          count = variables.additionalProgress;
        end
      else
        local allStates = setmetatable({}, Private.allstatesMetatable)
        Private.ActivateAuraEnvironment(data.id);
        RunTriggerFunc(allStates, events[data.id][triggernum], data.id, triggernum, "OPTIONS");
        Private.ActivateAuraEnvironment(nil);
        local count = 0;
        for id, state in pairs(allStates) do
          if (type(state.additionalProgress) == "table") then
            count = max(count, #state.additionalProgress);
          end
        end
      end

      count = min(count, 7);
      for i = 1, count do
        result = result or {};
        result[i] = string.format(L["Overlay %s"], i);
      end
    else
      for i = 1, 7 do
        local property = "customOverlay" .. i;
        if (trigger[property] and trigger[property] ~= "") then
          result = result or {};
          result[i] = string.format(L["Overlay %s"], i);
        end
      end
    end
  end

  return result;
end

---@type fun(data: auraData, triggernum: number): string?, string?
function GenericTrigger.GetNameAndIcon(data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  local icon, name
  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    if prototype.GetNameAndIcon then
      return prototype.GetNameAndIcon(trigger)
    else
      if prototype.iconFunc then
        icon = prototype.iconFunc(trigger)
      end
      if prototype.nameFunc then
        name = prototype.nameFunc(trigger)
      end
    end
  end

  return name, icon
end

---Returns the type of tooltip to show for the trigger.
---@param data auraData
---@param triggernum number
---@return boolean|string
function GenericTrigger.CanHaveTooltip(data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    if prototype.hasSpellID then
      return "spell";
    elseif prototype.hasItemID then
      return "item";
    end
  end

  if (trigger.type == "custom") then
    if (trigger.custom_type == "stateupdate") then
      return true;
    end
  end

  return false;
end

function GenericTrigger.SetToolTip(trigger, state)
  if (trigger.type == "custom" and trigger.custom_type == "stateupdate") then
    if (state.tooltip) then
      local lines = { strsplit("\n", state.tooltip) };
      GameTooltip:ClearLines();
      for i, line in ipairs(lines) do
        GameTooltip:AddLine(line, nil, nil, nil, state.tooltipWrap);
      end
      return true
    elseif (state.spellId) then
      GameTooltip:SetSpellByID(state.spellId);
      return true
    elseif (state.link) then
      GameTooltip:SetHyperlink(state.link);
      return true
    elseif (state.itemId) then
      GameTooltip:SetHyperlink("item:"..state.itemId..":0:0:0:0:0:0:0");
      return true
    elseif (state.unit and state.unitBuffIndex) then
      GameTooltip:SetUnitBuff(state.unit, state.unitBuffIndex, state.unitBuffFilter);
      return true
    elseif (state.unit and state.unitDebuffIndex) then
      GameTooltip:SetUnitDebuff(state.unit, state.unitDebuffIndex, state.unitDebuffFilter);
      return true
    elseif (state.unit and state.unitAuraIndex) then
      GameTooltip:SetUnitAura(state.unit, state.unitAuraIndex, state.unitAuraFilter)
      return true
    elseif (state.unit and state.unitAuraInstanceID and state.unitAuraFilter) then
      if state.unitAuraFilter == "HELPFUL" then
        GameTooltip:SetUnitBuffByAuraInstanceID(state.unit, state.unitAuraInstanceID, state.unitAuraFilter)
        return true
      elseif state.unitAuraFilter == "HARMFUL" then
        GameTooltip:SetUnitDebuffByAuraInstanceID(state.unit, state.unitAuraInstanceID, state.unitAuraFilter)
        return true
      end
    end
  end

  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    if prototype.hasSpellID then
      GameTooltip:SetSpellByID(trigger.spellName or 0);
      return true
    elseif prototype.hasItemID then
      GameTooltip:SetHyperlink("item:"..(trigger.itemName or 0)..":0:0:0:0:0:0:0")
      return true
    end
  end
  return false
end

---@type fun(data: auraData, triggernum: number): table
function GenericTrigger.GetAdditionalProperties(data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  local props = {}
  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    for _, v in pairs(prototype.args) do
      local enable = true
      if(type(v.enable) == "function") then
        enable = v.enable(trigger)
      elseif type(v.enable) == "boolean" then
        enable = v.enable
      end
      if (enable and v.store and v.name and v.display and v.conditionType ~= "bool") then
        local formatter = v.formatter
        local formatterArgs = v.formatterArgs or {}
        if not formatter then
          if v.type == "unit" then
            formatter = "Unit"
            formatterArgs = { color = "class" }
          elseif v.type == "string" then
            formatter = "string"
          end
        end
        props[v.name] = { display = v.display, formatter = formatter, formatterArgs = formatterArgs }
      end
    end
    if prototype.countEvents then
      props.count = L["Count"]
    end
  else
    if (trigger.custom_type == "stateupdate") then
      local variables = GenericTrigger.GetTsuConditionVariables(data.id, triggernum)
      if (type(variables) == "table") then
        for var, varData in pairs(variables) do
          if (type(varData) == "table") then
            props[var] = { display = varData.display or var, formatter = varData.formatter, formatterArgs = varData.formatterArgs }
          end
        end
      end
    end
  end
  return props;
end

function GenericTrigger.GetProgressSources(data, triggernum, values)
  local prototype = GenericTrigger.GetPrototype(data.triggers[triggernum].trigger)
  if prototype and prototype.cooldownViewerProgress then
    tinsert(values, {trigger = triggernum, property = "expirationTime", type = "timer", display = "Cooldown / aura duration", total = "duration", modRate = "modRate"})
    return
  end
  if prototype and prototype.displayOnlyProgress then
    tinsert(values, {trigger = triggernum, property = "value", type = "number", display = prototype.name, total = "total"})
    return
  end
  local variables = GenericTrigger.GetTriggerConditions(data, triggernum)
  if (type(variables) == "table") then
    for var, varData in pairs(variables) do
      if (type(varData) == "table") then
        if (varData.type == "number" or varData.type == "timer" or varData.type == "elapsedTimer")
           and not varData.noProgressSource
        then
          local modRateProperty = varData.modRate
          if not modRateProperty and varData.useModRate then
            modRateProperty = "modRate"
          end

          tinsert(values, {
            trigger = triggernum,
            property = var,
            type = varData.type,
            display = varData.display,
            total = varData.total,
            modRate = varData.modRate,
            inverse = varData.inverse,
            paused = varData.paused,
            remaining = varData.remaining,
            useAdditionalProgress = varData.useAdditionalProgress,
          })
        end
      end
    end
  end
end

local commonConditions = {
  expirationTime = {
    display = L["Remaining Duration"],
    type = "timer",
    total = "duration",
    inverse = "inverse",
    paused = "paused",
    remaining = "remaining",
  },
  expirationTimeModRate = {
    display = L["Remaining Duration"],
    type = "timer",
    total = "duration",
    modRate = "modRate",
    inverse = "inverse",
    paused = "paused",
    remaining = "remaining",
    useModRate = true
  },
  duration = {
    display = L["Total Duration"],
    type = "number",
    formatter = "Number",
  },
  durationModRate = {
    display = L["Total Duration"],
    type = "number",
    formatter = "Number",
    useModRate = true
  },
  paused = {
    display =L["Is Paused"],
    type = "bool",
    test = function(state, needle)
      return (state.paused and 1 or 0) == needle
    end
  },
  value = {
    display = L["Progress Value"],
    type = "number",
    total = "total"
  },
  total = {
    display = L["Progress Total"],
    type = "number",
  },
  stacks = {
    display = L["Stacks"],
    type = "number",
    formatter = "Number",
  },
  name = {
    display = L["Name"],
    type = "string"
  },
  itemInRange = {
    display = WeakAuras.newFeatureString .. L["Item in Range"],
    hidden = true,
    type = "bool",
    test = function(state, needle)
      if not state or not state.itemId or not state.show or not UnitExists('target') then
        return false
      end
      if InCombatLockdown() and not UnitCanAttack('player', 'target') then
        return false
      end
      return C_Item.IsItemInRange(state.itemId, 'target') == (needle == 1)
    end,
    events = Private.AddTargetConditionEvents({
      "WA_SPELL_RANGECHECK",
    })
  },
}

---@type fun(variables: table)
function Private.ExpandCustomVariables(variables)
  -- Make the life of tsu authors easier, by automatically filling in the details for
  -- expirationTime, duration, value, total, stacks, if those exists but aren't a table value
  -- By allowing a short-hand notation of just variable = type
  -- In addition to the long form of variable = { type = xyz, display = "desc"}
  for k, v in pairs(commonConditions) do
    if (variables[k] and type(variables[k]) ~= "table") then
      variables[k] = v;
    end
  end

  for k, v in pairs(variables) do
    if (type(v) == "string") then
      variables[k] = {
        display = k,
        type = v,
      };
    end
  end
end

function Private.GetTsuConditionVariablesExpanded(id, triggernum)
  if events[id][triggernum] and events[id][triggernum].tsuConditionVariables then
    Private.ActivateAuraEnvironment(id, nil, nil, nil, true)
    local result = GenericTrigger.GetTsuConditionVariables(id, triggernum)
    Private.ActivateAuraEnvironment(nil)
    if type(result) ~= "table" then
      return nil
    end
    Private.ExpandCustomVariables(result)
    -- Clean up, remove non table entries and check for a valid display name
    for k, v in pairs(result) do
      if type(v) ~= "table" then
        result[k] = nil
      elseif (v.display == nil or type(v.display) ~= "string") then
        if type(k) == "string" then
          v.display = k
        else
          result[k] = nil
        end
      end
    end

    return result
  end
end

function GenericTrigger.GetTriggerConditions(data, triggernum)
  local trigger = data.triggers[triggernum].trigger

  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    local result = {};

    local progressType, modRated = ProgressType(data, triggernum);
    if progressType == "timed" and not prototype.cooldownViewerProgress then
      if modRated then
        result.expirationTime = commonConditions.expirationTimeModRate;
        result.duration = commonConditions.durationModRate;
      else
        result.expirationTime = commonConditions.expirationTime;
        result.duration = commonConditions.duration;
      end
      result.paused = commonConditions.paused
    end

    if progressType == "static" and not prototype.displayOnlyProgress then
      result.value = commonConditions.value;
      result.total = commonConditions.total;
    end

    if prototype.stacksFunc then
      result.stacks = commonConditions.stacks;
    end

    if prototype.nameFunc then
      result.name = commonConditions.name;
    end

    if prototype.hasItemID then
      result.itemInRange = commonConditions.itemInRange
    end

    for _, v in pairs(prototype.args) do
      if (v.conditionType and v.name and v.display) then
        local enable = true;
        if (v.enable ~= nil) then
          if type(v.enable) == "function" then
            enable = v.enable(trigger);
          elseif type(v.enable) == "boolean" then
            enable = v.enable
          end
        end

        if (enable) then
          result[v.name] = {
            display = v.display,
            type = v.conditionType,
          }
          if (result[v.name].type == "select" or result[v.name].type == "unit") then
            if (v.conditionValues) then
              result[v.name].values = Private[v.conditionValues] or WeakAuras[v.conditionValues];
            else
              if type(v.values) == "function" then
                result[v.name].values = v.values()
              else
                result[v.name].values = Private[v.values] or WeakAuras[v.values];
              end
            end
          end
          if (v.conditionPreamble) then
            result[v.name].preamble = v.conditionPreamble;
          end
          if (v.conditionTest) then
            result[v.name].test = v.conditionTest;
          end
          if v.conditionRecheckTime then
            result[v.name].recheckTime = v.conditionRecheckTime
          end
          if (v.conditionEvents) then
            result[v.name].events = v.conditionEvents;
          end
          if (v.operator_types) then
            result[v.name].operator_types = v.operator_types;
          end
          -- for ProgressSource
          if v.noProgressSource then
            result[v.name].noProgressSource = true
          end
          if v.progressTotal then
            result[v.name].total = v.progressTotal
          end
          if v.progressModRate then
            result[v.name].modRate = v.progressModRate
          end
          if v.progressInverse then
            result[v.name].inverse = v.progressInverse
          end
          if v.progressPaused then
            result[v.name].paused = v.progressPaused
          end
          if v.progressRemaining then
            result[v.name].remaining = v.progressRemaining
          end
          if v.useAdditionalProgress then
            result[v.name].useAdditionalProgress = v.useAdditionalProgress
          end
        end
      end
    end

    if prototype.countEvents then
      result.count = {
        display = L["Count"],
        type = "number"
      }
    end

    return result;
  elseif(trigger.type == "custom") then
    if (trigger.custom_type == "status" or trigger.custom_type == "event") then
      local result = {};

      local canHaveDurationFunc = trigger.custom_type == "status" or (trigger.custom_type == "event" and (trigger.custom_hide ~= "timed" or trigger.dynamicDuration));

      if (canHaveDurationFunc and trigger.customDuration and trigger.customDuration ~= "") then
        result.expirationTime = commonConditions.expirationTime;
        result.duration = commonConditions.duration;
        result.value = commonConditions.value;
        result.total = commonConditions.total;
      end

      if (trigger.custom_type == "event" and trigger.custom_hide ~= "custom" and trigger.dynamicDuration ~= true) then
        -- This is the static duration of a event/timed trigger
        result.expirationTime = commonConditions.expirationTime;
        result.duration = commonConditions.duration;
      end

      if (trigger.customStacks and trigger.customStacks ~= "") then
        result.stacks = commonConditions.stacks;
      end

      if (trigger.customName and trigger.customName ~= "") then
        result.name = commonConditions.name;
      end

      return result;
    elseif (trigger.custom_type == "stateupdate") then
      return Private.GetTsuConditionVariablesExpanded(data.id, triggernum)
    end
  end

  return nil;
end

function GenericTrigger.CreateFallbackState(data, triggernum, state)
  state.show = true;
  state.changed = true;
  local event = events[data.id][triggernum];

  Private.ActivateAuraEnvironment(data.id, "", state);
  local trigger = data.triggers[triggernum].trigger

  if event.GetNameAndIcon then
    local ok, name, icon = xpcall(event.GetNameAndIcon, Private.GetErrorHandlerUid(data.uid, L["GetNameAndIcon Function (fallback state)"]), trigger);
    state.name = ok and name or nil;
    state.icon = ok and icon or nil;
  else
    if (event.nameFunc) then
      local ok, name = xpcall(event.nameFunc, Private.GetErrorHandlerUid(data.uid, L["Name Function (fallback state)"]), trigger);
      state.name = ok and name or nil;
    end
    if (event.iconFunc) then
      local ok, icon = xpcall(event.iconFunc, Private.GetErrorHandlerUid(data.uid, L["Icon Function (fallback state)"]), trigger);
      state.icon = ok and icon or nil;
    end
  end

  if (event.textureFunc ) then
    local ok, texture = xpcall(event.textureFunc, Private.GetErrorHandlerUid(data.uid, L["Texture Function (fallback state)"]), trigger);
    state.texture = ok and texture or nil;
  end

  if (event.stacksFunc) then
    local ok, stacks = xpcall(event.stacksFunc, Private.GetErrorHandlerUid(data.uid, L["Stacks Function (fallback state)"]), trigger);
    state.stacks = ok and stacks or nil;
  end

  if (event.durationFunc) then
    local ok, arg1, arg2, arg3, inverse = xpcall(event.durationFunc, Private.GetErrorHandlerUid(data.uid, L["Duration Function (fallback state)"]), trigger);
    if (not ok) then
      state.progressType = "timed";
      state.duration = 0;
      state.expirationTime = math.huge;
      state.value = nil;
      state.total = nil;
      Private.ActivateAuraEnvironment(nil)
      return;
    end
    arg1 = type(arg1) == "number" and arg1 or 0;
    arg2 = type(arg2) == "number" and arg2 or 0;

    if(type(arg3) == "string") then
      state.durationFunc = event.durationFunc;
    elseif (type(arg3) == "function") then
      state.durationFunc = arg3;
    else
      state.durationFunc = nil;
    end

    if (arg3) then
      state.progressType = "static";
      state.duration = nil;
      state.expirationTime = nil;
      state.value = arg1;
      state.total = arg2;
      state.inverse = inverse;
    else
      state.progressType = "timed";
      state.duration = arg1;
      state.expirationTime = arg2;
      state.autoHide = nil;
      state.value = nil;
      state.total = nil;
      state.inverse = inverse;
    end
  else
    state.progressType = "timed";
    state.duration = 0;
    state.expirationTime = math.huge;
    state.value = nil;
    state.total = nil;
  end
  if (event.overlayFuncs) then
    RunOverlayFuncs(event, state, data.id);
  end
  Private.ActivateAuraEnvironment(nil);
end

function GenericTrigger.GetName(triggerType)
  return Private.event_categories[triggerType].name
end

function GenericTrigger.GetTriggerDescription(data, triggernum, namestable)
  local trigger = data.triggers[triggernum].trigger
  local prototype = GenericTrigger.GetPrototype(trigger)
  if prototype then
    tinsert(namestable, {L["Trigger:"], (prototype.name or L["Undefined"])});
    if(trigger.event == "Combat Log" and trigger.subeventPrefix and trigger.subeventSuffix) then
      tinsert(namestable, {L["Message type:"], (Private.subevent_prefix_types[trigger.subeventPrefix] or L["Undefined"]).." "..(Private.subevent_suffix_types[trigger.subeventSuffix] or L["Undefined"])});
    end
  else
    tinsert(namestable, {L["Trigger:"], L["Custom"]});
  end
end

do
  -- Based on DejaCharacterStats: infer the global cooldown from spell timing.
  local class = select(2, UnitClass("player"))
  if class == "DEMONHUNTER"
    or class == "HUNTER" or class == "SHAMAN"
    or class == "MAGE" or class == "PRIEST" or class == "WARLOCK"
    or class == "DEATHKNIGHT" or class == "PALADIN" or class == "WARRIOR"
    or class == "EVOKER"
  then
    function WeakAuras.CalculatedGcdDuration()
      local haste = GetHaste()
      return max(0.75, 1.5 * 100 / (100+haste))
    end
  elseif class == "DRUID" then
    function WeakAuras.CalculatedGcdDuration()
      local id = GetShapeshiftFormID()
      local haste = GetHaste()
      return id == 1 and 1 or max(0.75, 1.5 * 100 / (100+haste))
    end
  elseif class == "MONK" then
    function WeakAuras.CalculatedGcdDuration()
      local spec = Private.ExecEnv.GetSpecialization()
      local primaryStat = select(6, Private.ExecEnv.GetSpecializationInfo(spec))
      if primaryStat == LE_UNIT_STAT_AGILITY then
        return 1
      end
      local haste = GetHaste()
      return max(0.75, 1.5 * 100 / (100+haste))
    end
  elseif class == "ROGUE" then
    function WeakAuras.CalculatedGcdDuration()
      return 1
    end
  end
end

local findIdInLink = function(id, itemLink, startPos)
  local findID = ":" .. tostring(id:trim())
  return itemLink:find(findID .. ":", startPos, true) or itemLink:find(findID .. "|", startPos, true)
end

---@param ids string
---@return boolean isItemBonusId
WeakAuras.CheckForItemBonusId = function(ids)
  for id in tostring(ids):gmatch('([^,]+)') do
    for slot in pairs(Private.item_slot_types) do
      local itemLink = GetInventoryItemLink('player', slot)
      if itemLink then
        local startPos = itemLink:find(":", 1, true)
        startPos = itemLink:find(":", startPos + 1 , true)
        if findIdInLink(id, itemLink, startPos) then
          return true
        end
      end
    end
  end
  return false
end

---@param ids string
---@param specificSlot? number
---@return string|nil id
---@return string|nil itemID
---@return string|nil itemName
---@return number|nil icon
---@return number|nil slot
---@return number|nil itemSlot
WeakAuras.GetBonusIdInfo = function(ids, specificSlot)
  local checkSlots = specificSlot and {[specificSlot] = true} or Private.item_slot_types
  for id in tostring(ids):gmatch('([^,]+)') do
    for slot in pairs(checkSlots) do
      local itemLink = GetInventoryItemLink('player', slot)
      if itemLink and findIdInLink(id, itemLink, 1) then
        local itemID, _, _, _, icon = C_Item.GetItemInfoInstant(itemLink)
        local itemName = itemLink:match("%[(.*)%]")
        return id, itemID, itemName, icon, slot, Private.item_slot_types[slot]
      end
    end
  end
end

---@param itemId string
---@param specificSlot? number
---@return boolean|nil isItemEquipped
WeakAuras.CheckForItemEquipped = function(itemId, specificSlot)
  if not specificSlot then
    return C_Item.IsEquippedItem(itemId or '')
  else
    local item = Item:CreateFromEquipmentSlot(specificSlot)
    if item and not item:IsItemEmpty() then
      return itemId == item:GetItemID()
    end
  end
end

Private.ExecEnv.GetItemSubClassInfo = function(i)
  local subClassId = i % 256
  local classId = (i - subClassId) / 256
  return C_Item.GetItemSubClassInfo(classId, subClassId)
end

Private.ExecEnv.IsEquippedItemType = function(itemType, itemSlot)
  if itemSlot then
    local itemId = GetInventoryItemID("player", itemSlot)
    if itemId then
      local triggerSubClassId = itemType % 256
      local triggerClassId = (itemType - triggerSubClassId) / 256
      local _, _, _, _, _, classId, subclassId = C_Item.GetItemInfoInstant(itemId)
      return classId == triggerClassId and subclassId == triggerSubClassId
    end
  else
    return C_Item.IsEquippedItemType(Private.ExecEnv.GetItemSubClassInfo(itemType) or '')
  end
end

---@return integer critChance
WeakAuras.GetCritChance = function()
  -- Based on what the wow paper doll does
  if C_Secrets.ShouldUnitStatsBeSecret() then
    return 0
  end
  local spellCrit = 0
  for i = 2, MAX_SPELL_SCHOOLS or 7 do -- WORKAROUND: MAX_SPELL_SCHOOLS is nil on classic_era
    spellCrit = max(spellCrit, GetSpellCritChance(i))
  end
  return max(spellCrit, GetRangedCritChance(), GetCritChance())
end

---@return number hitChance
WeakAuras.GetHitChance = function()
  if C_Secrets.ShouldUnitStatsBeSecret() then
    return 0
  end
  local melee = (GetCombatRatingBonus(CR_HIT_MELEE) or 0) + (GetHitModifier() or 0)
  local ranged = (GetCombatRatingBonus(CR_HIT_RANGED) or 0) + (GetHitModifier() or 0)
  local spell = (GetCombatRatingBonus(CR_HIT_SPELL) or 0) + (GetSpellHitModifier() or 0)
  return max(melee, ranged, spell)
end

---@type fun(trigger: triggerData)
---@return CurrencyInfo|nil
Private.GetCurrencyInfoForTrigger = function(trigger)
  if trigger.currencyId then
    local currencyId = tonumber(trigger.currencyId)
    if currencyId then
      return C_CurrencyInfo.GetCurrencyInfo(currencyId)
    end
  end
end

Private.ExecEnv.GetCurrencyAccountInfo = function(currencyId)
  local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyId)

  -- Gather currency data for account characters
  if currencyInfo and currencyInfo.isAccountTransferable then
    local dataReady = C_CurrencyInfo.IsAccountCharacterCurrencyDataReady()
    local accountCurrencyData = dataReady and C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters(currencyId)

    if dataReady and accountCurrencyData then
      currencyInfo.accountQuantity = currencyInfo.quantity
      currencyInfo.realAccountQuantity = currencyInfo.quantity
      if currencyInfo.transferPercentage then
        currencyInfo.realCharacterQuantity = math.floor(currencyInfo.quantity * (currencyInfo.transferPercentage / 100))
      end

      currencyInfo.accountCurrencyData = accountCurrencyData
      for _, currencyData in ipairs(currencyInfo.accountCurrencyData) do
        if currencyData.quantity then
          if currencyInfo.transferPercentage then
            currencyData.realCharacterQuantity = math.floor(currencyData.quantity * (currencyInfo.transferPercentage / 100))
          end
          currencyInfo.realAccountQuantity = currencyInfo.realAccountQuantity + (currencyData.realCharacterQuantity or currencyData.quantity)
          currencyInfo.accountQuantity = currencyInfo.accountQuantity + currencyData.quantity
        end
      end
    else
      C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
    end
  end

  if currencyInfo then
    currencyInfo.capped = currencyInfo.maxQuantity and currencyInfo.maxQuantity > 0 and currencyInfo.quantity >= currencyInfo.maxQuantity
    currencyInfo.seasonCapped = currencyInfo.maxQuantity and currencyInfo.maxQuantity > 0 and currencyInfo.useTotalEarnedForMaxQty and currencyInfo.totalEarned >= currencyInfo.maxQuantity
    currencyInfo.weeklyCapped = currencyInfo.maxWeeklyQuantity and currencyInfo.maxWeeklyQuantity > 0 and currencyInfo.quantityEarnedThisWeek >= currencyInfo.maxWeeklyQuantity
  end

  if not currencyInfo then
    local testToken = C_CurrencyInfo.GetCurrencyInfo(1) --Currency Token Test Token 4
    if testToken then
      currencyInfo = testToken
      currencyInfo.iconFileID = "Interface\\Icons\\INV_Misc_QuestionMark" --We don't want the user to think their input was valid
    end
  end

  return currencyInfo or {}
end

local types = {}
tinsert(types, "custom")
for type in pairs(Private.category_event_prototype) do
  tinsert(types, type)
end

-- The Options/GenericTrigger.lua needs this table, since at the time
-- of registering the types the options code doesn't yet have access
-- to the Private table.

-- So for now make it simply a member of ForeverAuras
WeakAuras.genericTriggerTypes = types

WeakAuras.RegisterTriggerSystem(types, GenericTrigger);
