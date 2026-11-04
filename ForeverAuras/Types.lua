-- Modified for ForeverAuras, 2026-10-07.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end

---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("Types")
---@class WeakAuras
local WeakAuras = WeakAuras;
local L = WeakAuras.L;

local LSM = LibStub("LibSharedMedia-3.0");

-- Another addon can load a different LibSharedMedia copy: a media registration it
-- rejects must not stop this file, and every aura, from loading.
local function Register(...)
  pcall(LSM.Register, LSM, ...)
end
local FONT_LOCALES = (LSM.LOCALE_BIT_western and LSM.LOCALE_BIT_ruRU) and (LSM.LOCALE_BIT_western + LSM.LOCALE_BIT_ruRU) or nil

local wipe, tinsert = wipe, tinsert
local GetNumShapeshiftForms, GetShapeshiftFormInfo = GetNumShapeshiftForms, GetShapeshiftFormInfo
local WrapTextInColorCode = WrapTextInColorCode
local MAX_NUM_TALENTS = MAX_NUM_TALENTS or 20

local function WA_GetClassColor(classFilename)
  local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFilename]
  if color then
    return color.colorStr
  end

  return "ffffffff"
end

---@type table<string, string>
Private.glow_action_types = {
  show = L["Show"],
  hide = L["Hide"]
}

---@type table<string, string>
Private.glow_frame_types = {
  UNITFRAME = L["Unit Frame"],
  NAMEPLATE = L["Nameplate"],
  FRAMESELECTOR = L["Frame Selector"],
  PARENTFRAME = L["Parent Frame"]
}

---@type table<dynamicGroupCircularTypes, string>
Private.circular_group_constant_factor_types = {
  ANGLE = L["Angle and Radius"],
  RADIUS = L["Radius"],
  SPACING = L["Spacing"]
}

---@type table<number, string>
Private.frame_strata_types = {
  [1] = L["Inherited"],
  [2] = "BACKGROUND",
  [3] = "LOW",
  [4] = "MEDIUM",
  [5] = "HIGH",
  [6] = "DIALOG",
  [7] = "FULLSCREEN",
  [8] = "FULLSCREEN_DIALOG",
  [9] = "TOOLTIP"
}

---@type table<string, string>
Private.hostility_types = {
  hostile = L["Hostile"],
  friendly = L["Friendly"]
}

---@type table<string, string>
Private.character_types = {
  player = L["Player Character"],
  npc = L["Non-player Character"]
}

---@type table<string, string>
Private.spec_position_types = {
  RANGED = L["Ranged"],
  MELEE = L["Melee"]
}

---@type table<string, string>
Private.group_sort_types = {
  ascending = L["Ascending"],
  descending = L["Descending"],
  hybrid = L["Hybrid"],
  none = L["None"],
  custom = L["Custom"]
}

---@type table<string, string>
Private.group_hybrid_position_types = {
  hybridFirst = L["Marked First"],
  hybridLast = L["Marked Last"]
}

---@type table<string, string>
Private.group_hybrid_sort_types = {
  ascending = L["Ascending"],
  descending = L["Descending"]
}

---@type table<number, string>
Private.time_format_types = {
  [0] = L["ForeverAuras Built-In (63:42 | 3:07 | 10 | 2.4)"],
  [1] = L["Old Blizzard (2h | 3m | 10s | 2.4)"],
  [2] = L["Modern Blizzard (1h 3m | 3m 7s | 10s | 2.4)"],
}

---@type table<number, string>
Private.time_precision_types = {
  [1] = "12.3",
  [2] = "12.34",
  [3] = "12.345",
}

---@type table<number, string>
Private.precision_types = {
  [0] = "12",
  [1] = "12.3",
  [2] = "12.34",
  [3] = "12.345",
}

---@type table<string, string>
Private.big_number_types = {
  ["AbbreviateNumbers"] = L["AbbreviateNumbers (Blizzard)"],
  ["AbbreviateLargeNumbers"] = L["AbbreviateLargeNumbers (Blizzard)"],
  ["BreakUpLargeNumbers"] = L["BreakUpLargeNumbers (Blizzard)"],
}

---@type table<string, string>
Private.big_number_types_with_disable = CopyTable(Private.big_number_types)
Private.big_number_types_with_disable["disable"] = L["Disabled"]

---@type table<string, string>
Private.round_types = {
  floor = L["Floor"],
  ceil = L["Ceil"],
  round = L["Round"]
}

---@type table<string, string>
Private.pad_types = {
  left = L["Left"],
  right = L["Right"]
}

---@type table<string, string>
Private.unit_color_types = {
  none = L["None"],
  class = L["Class"]
}

---@type table<string, string>
Private.unit_realm_name_types = {
  never = L["Never"],
  star = L["* Suffix"],
  differentServer = L["Only if on a different realm"],
  always = L["Always include realm"]
}

-- Client data read while this file loads is guarded: a client update that changes
-- or removes one must not stop the rest of this file (and every aura) from loading.
local function Try(func, ...)
  if type(func) ~= "function" then return end
  local results = {pcall(func, ...)}
  if results[1] then return unpack(results, 2) end
end

local timeFormatter = {}
if SecondsFormatterMixin then Mixin(timeFormatter, SecondsFormatterMixin) end
-- Without Blizzard's formatter, a plain fallback keeps time texts working.
if not timeFormatter.Format then
  timeFormatter.Format = function(_, value) return SecondsToTime and SecondsToTime(value) or tostring(math.floor(value)) end
end
Try(timeFormatter.Init, timeFormatter, 0, SecondsFormatter and SecondsFormatter.Abbreviation and SecondsFormatter.Abbreviation.OneLetter)

-- The default time formatter adds a space between the value and the unit
-- While there is a API to strip it, that API does not work on all locales, e.g. german
-- Thus, copy the interval descriptions, strip the whitespace from them
-- and hack the timeFormatter to use our interval descriptions
local timeFormatIntervalDescriptionFixed = Try(function()
  local fixed = CopyTable(SecondsFormatter.IntervalDescription)
  for i, interval in ipairs(fixed) do
    interval.formatString = CopyTable(SecondsFormatter.IntervalDescription[i].formatString)
    for j, formatString in ipairs(interval.formatString) do
      interval.formatString[j] = formatString:gsub(" ", "")
    end
  end
  return fixed
end)

-- Without the client's interval data the formatter keeps Blizzard's own (spaced) units.
if timeFormatIntervalDescriptionFixed then
  timeFormatter.GetIntervalDescription = function(self, interval)
    return timeFormatIntervalDescriptionFixed[interval]
  end

  timeFormatter.GetMaxInterval = function(self)
    return #timeFormatIntervalDescriptionFixed
  end
end

local AbbreviateNumbers = AbbreviateNumbers

local simpleFormatters = {
  AbbreviateNumbers = function(value)
    if type(value) == "string" and not issecretvalue(value) then value = tonumber(value) end
    if type(value) == "number" then return AbbreviateNumbers(value) end
    return value
  end,
  AbbreviateLargeNumbers = function(value)
    if type(value) == "string" and not issecretvalue(value) then value = tonumber(value) end
    if type(value) == "number" then return AbbreviateLargeNumbers(value) end
    return value
  end,
  BreakUpLargeNumbers = function(value)
    if type(value) == "string" and not issecretvalue(value) then value = tonumber(value) end
    if type(value) == "number" then return BreakUpLargeNumbers(value) end
    return value
  end,
  floor = function(value)
    if issecretvalue(value) then
      if type(value) == "number" then
        return string.format("%d", value)
      elseif type(value) == "string" then
        return value
      else
        return ""
      end
    end
    if type(value) == "string" then value = tonumber(value) end
    return (type(value) == "number") and floor(value) or value
  end,
  ceil = function(value)
    if issecretvalue(value) then
      if type(value) == "number" then
        return string.format("%d", value)
      elseif type(value) == "string" then
        return value
      else
        return ""
      end
    end
    if type(value) == "string" then value = tonumber(value) end
    return (type(value) == "number") and ceil(value) or value
  end,
  round = function(value)
    if issecretvalue(value) then
      if type(value) == "number" then
        return string.format("%d", value)
      elseif type(value) == "string" then
        return value
      else
        return ""
      end
    end
    if type(value) == "string" then value = tonumber(value) end
    return (type(value) == "number") and Round(value) or value
  end,
  time = {
    [0] = function(value)
      if issecretvalue(value) and type(value) == "number" then
        return string.format("%d", value)
      end
      if type(value) == "string" and not issecretvalue(value) then value = tonumber(value) end
      if type(value) == "number" then
        if value > 60 then
          return string.format("%i:", math.floor(value / 60)) .. string.format("%02i", value % 60)
        else
          return string.format("%d", value)
        end
      end
    end,
    -- Old Blizzard
    [1] = function(value)
      if issecretvalue(value) then
        if  type(value) == "number" then
          return string.format("%d", value)
        elseif type(value) == "string" then
          return value
        else
          return ""
        end
      end
      local fmt, time = SecondsToTimeAbbrev(value)
      -- Remove the space between the value and unit
      return fmt:gsub(" ", ""):format(time)
    end,
    -- Modern Blizzard
    [2] = function(value)
      if issecretvalue(value) then
        if  type(value) == "number" then
          return string.format("%d", value)
        elseif type(value) == "string" then
          return value
        else
          return ""
        end
      end
      return timeFormatter:Format(value)
    end,
    -- Fixed built-in formatter
    [99] = function(value)
      if issecretvalue(value) and type(value) == "number" then
        return string.format("%d", value)
      end
      if type(value) == "string" and not issecretvalue(value) then value = tonumber(value) end
      if type(value) == "number" then
        value = ceil(value)
        if value > 60 then
          return string.format("%i:", math.floor(value / 60)) .. string.format("%02i", value % 60)
        else
          return string.format("%d", value)
        end
      end
    end,
  },
}

---@alias optionAdder fun(name: string, option: table)
---@alias optionGetter fun(name: string): any
---@alias formatter fun(input: any): string

---@class FormatType
---@field display string
---@field AddOptions fun(symbol: string, hidden: boolean, addOption: optionAdder, get: optionGetter)
---@field CreateFormatter fun(symbol: string, get: optionGetter, withoutColor: boolean, data: table): formatter?, boolean?

---@type table<string, FormatType>
Private.format_types = {
  none = {
    display = L["None"],
    AddOptions = function() end,
    CreateFormatter = function() return nil end
  },
  string = {
    display = L["String"],
    AddOptions = function(symbol, hidden, addOption, get)
      addOption(symbol .. "_abbreviate", {
        type = "toggle",
        name = L["Abbreviate"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_abbreviate_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Max Char "],
        width = WeakAuras.normalWidth,
        min = 1,
        softMax = 20,
        hidden = hidden,
        step = 1,
        disabled = function()
          return not get(symbol .. "_abbreviate")
        end
      })
      addOption(symbol .. "_pad", {
        type = "toggle",
        name = L["Pad"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_mode", {
        type = "select",
        name = L["Pad Mode"],
        width = WeakAuras.halfWidth,
        values = Private.pad_types,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Pad to"],
        width = WeakAuras.halfWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        step = 1,
      })
    end,
    CreateFormatter = function(symbol, get)
      local abbreviate = get(symbol .. "_abbreviate", false)
      local abbreviateMax = get(symbol .. "_abbreviate_max", 8)
      local pad = get(symbol .. "_pad", false)
      local padMode = get(symbol .. "_pad_mode", "left")
      local padLength = get(symbol .. "_pad_max", 8)
      if abbreviate and pad then
        return function(input)
          return WeakAuras.PadString(WeakAuras.WA_Utf8Sub(input, abbreviateMax), padMode, padLength)
        end
      elseif pad then
        return function(input)
          return WeakAuras.PadString(input, padMode, padLength)
        end
      elseif abbreviate then
        return function(input)
          return WeakAuras.WA_Utf8Sub(input, abbreviateMax)
        end
      end
      return nil
    end
  },
  timed = {
    display = L["Time Format"],
    AddOptions = function(symbol, hidden, addOption, get)
      addOption(symbol .. "_time_format", {
        type = "select",
        name = L["Format"],
        width = WeakAuras.doubleWidth,
        values = Private.time_format_types,
        hidden = hidden
      })

      addOption(symbol .. "_time_dynamic_threshold", {
        type = "range",
        control = "WeakAurasSpinBox",
        min = 0,
        max = 60,
        step = 1,
        name = L["Increase Precision Below"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })

      addOption(symbol .. "_time_precision", {
        type = "select",
        name = L["Precision"],
        width = WeakAuras.normalWidth,
        values = Private.time_precision_types,
        hidden = hidden,
        disabled = function() return get(symbol .. "_time_dynamic_threshold") == 0 end
      })

      addOption(symbol .. "_time_mod_rate", {
        type = "toggle",
        name = L["Blizzard Cooldown Reduction"],
        desc = L["Cooldown Reduction changes the duration of seconds instead of showing the real time seconds."],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })

      addOption(symbol .. "_time_legacy_floor", {
        type = "toggle",
        name = L["Use Legacy floor rounding"],
        desc = L["Enables (incorrect) round down of seconds, which was the previous default behavior."],
        width = WeakAuras.normalWidth,
        hidden = hidden,
        disabled = function() return get(symbol .. "_time_format", 0) ~= 0 end
      })
    end,
    CreateFormatter = function(symbol, get, wihoutColor, data)
      local format = get(symbol .. "_time_format", 0)
      local threshold = get(symbol .. "_time_dynamic_threshold", 60)
      local precision = get(symbol .. "_time_precision", 1)
      local modRate = get(symbol .. "_time_mod_rate", true)
      local legacyRoundingMode = get(symbol .. "_time_legacy_floor", false)
      local tint = get(symbol .. "_time_tint")
      -- Old and Modern Blizzard formats for timers Lua cannot read.
      local timeStyles = {[0] = true, [99] = true, [1] = -3, [2] = -4}

      if format == 0 and not legacyRoundingMode then
        format = 99
      end
      if not simpleFormatters.time[format] then
        format = 99
      end
      local mainFormater = simpleFormatters.time[format]

      local modRateProperty = {}
      local timePointProperty = {}

      -- For the mod rate support, we need to know which state member is the modRate, as
      -- different progressSources can have different modRates
      -- Here, we only collect the names, so that the actual formatter can quickly lookup
      -- the property
      -- This is somewhat complicated by legacy behaviour (for %p, %t) and that %foo, can
      -- be the foo of different triggers that might use different modRate properties
      -- Similarly to distinguish between time formaters for durations and timepoints,
      -- we maintain a lookup table for time points
      -- Timepoint formatters need to run every frame, so we rturn true if we
      -- are formatting a timepoint
      local triggerNum, sym = string.match(symbol, "(.+)%.(.+)")
      triggerNum = triggerNum and tonumber(triggerNum)
      sym = sym or symbol

      if triggerNum then
        if sym == "p" or sym == "t" then
          if modRate then
            modRateProperty[triggerNum] = "modRate"
          end
        else
          local progressSource = Private.GetProgressSourceFor(data, triggerNum, sym)
          if progressSource then
            if modRate and progressSource[5] then
              modRateProperty[triggerNum] = progressSource[5]
            end
            if progressSource[2] == "timer" or progressSource[2] == "elapsedTimer" then
              timePointProperty[triggerNum] = true
            end
          end
        end
      else
        if symbol == "p" or symbol == "t" then
          for i = 1, #data.triggers do
            if modRate then
              modRateProperty[i] = "modRate"
            end
          end
        else
          for i = 1, #data.triggers do
            local progressSource = Private.GetProgressSourceFor(data, i, symbol)
            if progressSource then
              if modRate and progressSource[5] then
                modRateProperty[i] = progressSource[5]
              end
              if progressSource[2] == "timer" or progressSource[2] == "elapsedTimer" then
                timePointProperty[i] = true
              end
            end
          end
        end
      end

      local formatter
      if threshold == 0 then
        formatter = function(value, state, trigger)
          if type(value) ~= 'number' then
            return ""
          end
          if issecretvalue(value) then
            return mainFormater(value)
          end
          if value == math.huge then
            return ""
          end

          if timePointProperty[trigger] then
            value = abs(GetTime() - value)
          end

          if value <= 0 then
            return ""
          end

          if modRate and trigger and modRateProperty[trigger] then
            value = value / (state[modRateProperty[trigger]] or 1.0)
          end

          return mainFormater(value)
        end
      else
        local formatString = "%." .. precision .. "f"
        formatter = function(value, state, trigger)
          if type(value) ~= 'number' then
            return ""
          end
          if issecretvalue(value) then
            return string.format(formatString, value)
          end
          if value == math.huge then
            return ""
          end

          if timePointProperty[trigger] then
            value = abs(GetTime() - value)
          end

          if value <= 0 then
            return ""
          end
          if modRate and trigger and modRateProperty[trigger] then
            value = value / (state[modRateProperty[trigger]] or 1.0)
          end
          if value < threshold then
            return string.format(formatString, value)
          else
            return mainFormater(value)
          end
        end
      end

      if sym == "p" or sym == "t" then
        -- Special case %p and %t. Since due to how the formatting
        -- work previously, the time formatter only formats %p and %t
        -- if the progress type is timed!
        return function(value, state, trigger)
          -- Hide the token itself for a known GCD, regardless of time format or
          -- whether the filtered duration is available during this refresh.
          if Private.ShouldHideDurationText(state) then return "" end
          if not state or (state.progressType ~= "timed" and state.progressType ~= "durationObject") then
            return value
          end
          if Private.UsesDurationText(state) and timeStyles[format]
            and (state.progressType ~= "timed" or issecretvalue(value)) then
            local ok, text = pcall(Private.FormatDurationText, Private.GetTextDuration(state), sym == "t", format == 0 and 0 or 99, threshold, precision, modRate, tint, timeStyles[format])
            return ok and text or ""
          end
          return formatter(value, state, trigger)
        end, next(timePointProperty) ~= nil
      else
        return formatter, next(timePointProperty) ~= nil
      end
    end
  },
  Money = {
    display = L["Money"],
    AddOptions = function(symbol, hidden, addOption)
      addOption(symbol .. "_money_format", {
        type = "select",
        name = L["Format Gold"],
        width = WeakAuras.normalWidth,
        values = Private.big_number_types_with_disable,
        hidden = hidden
      })
      addOption(symbol .. "_money_precision", {
        type = "select",
        name = L["Coin Precision"],
        width = WeakAuras.normalWidth,
        values = Private.money_precision_types,
        hidden = hidden
      })
    end,
    CreateFormatter = function(symbol, get)
      local format = get(symbol .. "_money_format", "AbbreviateNumbers")
      local precision = get(symbol .. "_money_precision", 3)

      return function(value)
        if type(value) ~= "number" then
          return ""
        end
        local gold = floor(value / 1e4)
        local silver = floor(value / 100 % 100)
        local copper = value % 100

        if (format == "AbbreviateNumbers") then
          gold = simpleFormatters.AbbreviateNumbers(gold)
        elseif (format == "BreakUpLargeNumbers") then
          gold = simpleFormatters.BreakUpLargeNumbers(gold)
        elseif (format == "AbbreviateLargeNumbers") then
          gold = simpleFormatters.AbbreviateLargeNumbers(gold)
        end

        local formatCode
        if precision == 1 then
          formatCode = "%s%s"
        elseif precision == 2 then
          formatCode = "%s%s %d%s"
        else
          formatCode = "%s%s %d%s %d%s"
        end

        return string.format(formatCode,
          tostring(gold), Private.coin_icons.gold,
          silver, Private.coin_icons.silver,
          copper, Private.coin_icons.copper
        )
      end
    end
  },
  BigNumber = {
    display = L["Big Number"],
    AddOptions = function(symbol, hidden, addOption, get)
      addOption(symbol .. "_big_number_format", {
        type = "select",
        name = L["Format"],
        width = WeakAuras.normalWidth,
        values = Private.big_number_types,
        hidden = hidden
      })
      addOption(symbol .. "_big_number_space", {
        type = "description",
        name = "",
        width = WeakAuras.normalWidth,
        hidden = hidden
      })
      addOption(symbol .. "_pad", {
        type = "toggle",
        name = L["Pad"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_mode", {
        type = "select",
        name = L["Pad Mode"],
        width = WeakAuras.halfWidth,
        values = Private.pad_types,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Pad to"],
        width = WeakAuras.halfWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        step = 1,
      })
    end,
    CreateFormatter = function(symbol, get)
      local format = get(symbol .. "_big_number_format", "AbbreviateNumbers")
      local pad = get(symbol .. "_pad", false)
      local padMode = get(symbol .. "_pad_mode", "left")
      local padLength = get(symbol .. "_pad_max", 8)
      local formatterFunc
      if (format == "AbbreviateNumbers") then
        formatterFunc = simpleFormatters.AbbreviateNumbers
      elseif (format == "BreakUpLargeNumbers") then
        formatterFunc = simpleFormatters.BreakUpLargeNumbers
      else
        formatterFunc = simpleFormatters.AbbreviateLargeNumbers
      end
      if pad then
        return function(input)
          return WeakAuras.PadString(formatterFunc(input), padMode, padLength)
        end
      end
      return formatterFunc
    end
  },
  Number = {
    display = L["Number"],
    AddOptions = function(symbol, hidden, addOption, get)
      addOption(symbol .. "_decimal_precision", {
        type = "select",
        name = L["Precision"],
        width = WeakAuras.normalWidth,
        values = Private.precision_types,
        hidden = hidden
      })
      addOption(symbol .. "_round_type", {
        type = "select",
        name = L["Round Mode"],
        width = WeakAuras.normalWidth,
        values = Private.round_types,
        hidden = hidden,
        disabled = function()
          return get(symbol .. "_decimal_precision") ~= 0
        end
      })
      addOption(symbol .. "_pad", {
        type = "toggle",
        name = L["Pad"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_mode", {
        type = "select",
        name = L["Pad Mode"],
        width = WeakAuras.halfWidth,
        values = Private.pad_types,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Pad to"],
        width = WeakAuras.halfWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        step = 1,
      })
    end,
    CreateFormatter = function(symbol, get)
      local precision = get(symbol .. "_decimal_precision", 1)
      local pad = get(symbol .. "_pad", false)
      local padMode = get(symbol .. "_pad_mode", "left")
      local padLength = get(symbol .. "_pad_max", 8)
      local formatterFunc
      if precision == 0 then
        local type = get(symbol .. "_round_type", "floor")
        formatterFunc = simpleFormatters[type]
      else
        local format = "%." .. precision .. "f"
        formatterFunc = function(value)
          if type(value) == "number" then return string.format(format, value) end
          return value
        end
      end
      if pad then
        return function(input)
          return WeakAuras.PadString(formatterFunc(input), padMode, padLength)
        end
      end
      return formatterFunc
    end
  },
  Unit = {
    display = L["Formats |cFFFFCC00%unit|r"],
    AddOptions = function(symbol, hidden, addOption, get, withoutColor)
      if not withoutColor then
        addOption(symbol .. "_color", {
          type = "select",
          name = L["Color"],
          width = WeakAuras.normalWidth,
          values = Private.unit_color_types,
          hidden = hidden,
        })
      end
      addOption(symbol .. "_realm_name", {
        type = "select",
        name = L["Realm Name"],
        width = WeakAuras.normalWidth,
        values = Private.unit_realm_name_types,
        hidden = hidden,
      })
      addOption(symbol .. "_abbreviate", {
        type = "toggle",
        name = L["Abbreviate"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_abbreviate_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Max Char"],
        width = WeakAuras.normalWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        step = 1,
        disabled = function()
          return not get(symbol .. "_abbreviate")
        end
      })
      addOption(symbol .. "_pad", {
        type = "toggle",
        name = L["Pad"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_mode", {
        type = "select",
        name = L["Pad Mode"],
        width = WeakAuras.halfWidth,
        values = Private.pad_types,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Pad to"],
        width = WeakAuras.halfWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        step = 1,
      })
    end,
    CreateFormatter = function(symbol, get, withoutColor)
      local color = not withoutColor and get(symbol .. "_color", true)
      local realm = get(symbol .. "_realm_name", "never")
      local abbreviate = get(symbol .. "_abbreviate", false)
      local abbreviateMax = get(symbol .. "_abbreviate_max", 8)
      local pad = get(symbol .. "_pad", false)
      local padMode = get(symbol .. "_pad_mode", "left")
      local padLength = get(symbol .. "_pad_max", 8)

      local nameFunc
      local colorFunc
      local abbreviateFunc
      if color == "class" then
        colorFunc = function(unit, text)
          -- Color-code construction and class-table indexing require readable values.
          if issecretvalue(text) then return text end
          if unit and Private.UnitPlayerControlledFixed(unit) then
            local classFilename = select(2, UnitClass(unit))
            if not issecretvalue(classFilename) and classFilename then
              return WrapTextInColorCode(text, WA_GetClassColor(classFilename))
            end
          end
          return text
        end
      end

      if realm == "never" then
        nameFunc = function(unit)
          return unit and WeakAuras.UnitName(unit) or ""
        end
      elseif realm == "star" then
        nameFunc = function(unit)
          if not unit then
            return ""
          end
          local name, realm = WeakAuras.UnitName(unit)
          -- A secret realm cannot be tested; show the name alone.
          if issecretvalue(realm) then return name end
          if realm then
            return name .. "*"
          end
          return name or ""
        end
      elseif realm == "differentServer" then
        nameFunc = function(unit)
          if not unit then
            return ""
          end
          local name, realm = WeakAuras.UnitName(unit)
          if issecretvalue(realm) then return name end
          if realm then
            return name .. "-" .. realm
          end
          return name or ""
        end
      elseif realm == "always" then
        nameFunc = function(unit)
          if not unit then
            return ""
          end
          local name, realm = WeakAuras.UnitNameWithRealmCustomName(unit)
          return name .. "-" .. realm
        end
      end

      if pad and abbreviate then
        abbreviateFunc = function(input)
          return WeakAuras.PadString(WeakAuras.WA_Utf8Sub(input, abbreviateMax), padMode, padLength)
        end
      elseif pad then
        abbreviateFunc = function(input)
          return WeakAuras.PadString(input, padMode, padLength)
        end
      elseif abbreviate then
        abbreviateFunc = function(input)
          return WeakAuras.WA_Utf8Sub(input, abbreviateMax)
        end
      end

      -- Do the checks on what is necessary here instead of inside the returned
      -- formatter
      if colorFunc then
        if abbreviateFunc then
          return function(unit)
            local name = abbreviateFunc(nameFunc(unit))
            return colorFunc(unit, name)
          end
        else
          return function(unit)
            local name = nameFunc(unit)
            return colorFunc(unit, name)
          end
        end
      else
        if abbreviateFunc then
          return function(unit)
            local name = nameFunc(unit)
            return abbreviateFunc(name)
          end
        else
          return nameFunc
        end
      end
    end
  },
  guid = {
    display = L["Formats Player's |cFFFFCC00%guid|r"],
    AddOptions = function(symbol, hidden, addOption, get, withoutColor)
      if not withoutColor then
        addOption(symbol .. "_color", {
          type = "select",
          name = L["Color"],
          width = WeakAuras.normalWidth,
          values = Private.unit_color_types,
          hidden = hidden,
        })
      end
      addOption(symbol .. "_realm_name", {
        type = "select",
        name = L["Realm Name"],
        width = WeakAuras.normalWidth,
        values = Private.unit_realm_name_types,
        hidden = hidden,
      })
      addOption(symbol .. "_abbreviate", {
        type = "toggle",
        name = L["Abbreviate"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_abbreviate_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Max Char "],
        width = WeakAuras.normalWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        disabled = function()
          return not get(symbol .. "_abbreviate")
        end
      })
      addOption(symbol .. "_pad", {
        type = "toggle",
        name = L["Pad"],
        width = WeakAuras.normalWidth,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_mode", {
        type = "select",
        name = L["Pad Mode"],
        width = WeakAuras.halfWidth,
        values = Private.pad_types,
        hidden = hidden,
      })
      addOption(symbol .. "_pad_max", {
        type = "range",
        control = "WeakAurasSpinBox",
        name = L["Pad to"],
        width = WeakAuras.halfWidth,
        min = 1,
        max = 20,
        hidden = hidden,
        step = 1,
      })
    end,
    CreateFormatter = function(symbol, get, withoutColor)
      local color = not withoutColor and get(symbol .. "_color", true)
      local realm = get(symbol .. "_realm_name", "never")
      local abbreviate = get(symbol .. "_abbreviate", false)
      local abbreviateMax = get(symbol .. "_abbreviate_max", 8)
      local pad = get(symbol .. "_pad", false)
      local padMode = get(symbol .. "_pad_mode", "left")
      local padLength = get(symbol .. "_pad_max", 8)

      local nameFunc
      local colorFunc
      local abbreviateFunc
      if color == "class" then
        colorFunc = function(class, text)
          if class then
            return WrapTextInColorCode(text, WA_GetClassColor(class))
          else
            return text
          end
        end
      end

      if realm == "never" then
        nameFunc = function(name, realm)
          return WeakAuras.GetName(name)
        end
      elseif realm == "star" then
        nameFunc = function(name, realm)
          name = WeakAuras.GetName(name)
          if realm ~= "" then
            return name .. "*"
          end
          return name
        end
      elseif realm == "differentServer" then
        nameFunc = function(name, realm)
          name = WeakAuras.GetName(name)
          if realm ~= "" then
            return name .. "-" .. realm
          end
          return name
        end
      elseif realm == "always" then
        nameFunc = function(name, realm)
          name = WeakAuras.GetName(name)
          if realm == "" then
            realm = select(2, WeakAuras.UnitNameWithRealm("player"))
          end
          return name .. "-" .. realm
        end
      end

      if pad and abbreviate then
        abbreviateFunc = function(input)
          return WeakAuras.PadString(WeakAuras.WA_Utf8Sub(input, abbreviateMax), padMode, padLength)
        end
      elseif pad then
        abbreviateFunc = function(input)
          return WeakAuras.PadString(input, padMode, padLength)
        end
      elseif abbreviate then
        abbreviateFunc = function(input)
          return WeakAuras.WA_Utf8Sub(input, abbreviateMax)
        end
      end

      -- Do the checks on what is necessary here instead of inside the returned
      -- formatter
      if colorFunc then
        if abbreviateFunc then
          return function(guid)
            local ok, _, class, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
            if ok and name then
              local name = abbreviateFunc(nameFunc(name, realm))
              return colorFunc(class, name)
            end
          end
        else
          return function(guid)
            local ok, _, class, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
            if ok and name then
              return colorFunc(class, nameFunc(name, realm))
            end
          end
        end
      else
        if abbreviateFunc then
          return function(guid)
            local ok, _, class, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
            if ok and name then
              return abbreviateFunc(nameFunc(name, realm))
            end
          end
        else
          return function(guid)
            local ok, _, class, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
            if ok and name then
              return nameFunc(name, realm)
            end
          end
        end
      end
    end
  },
  GCDTime = {
    display = L["Time in GCDs"],
    AddOptions = function(symbol, hidden, addOption, get)
      addOption(symbol .. "_gcd_gcd", {
        type = "toggle",
        name = L["Subtract GCD"],
        width = WeakAuras.normalWidth,
        hidden = hidden
      })
      addOption(symbol .. "_gcd_cast", {
        type = "toggle",
        name = L["Subtract Cast"],
        width = WeakAuras.normalWidth,
        hidden = hidden
      })
      addOption(symbol .. "_gcd_channel", {
        type = "toggle",
        name = L["Subtract Channel"],
        width = WeakAuras.normalWidth,
        hidden = hidden
      })
      addOption(symbol .. "_gcd_hide_zero", {
        type = "toggle",
        name = L["Hide 0 cooldowns"],
        width = WeakAuras.normalWidth,
        hidden = hidden
      })

      addOption(symbol .. "_decimal_precision", {
        type = "select",
        name = L["Precision"],
        width = WeakAuras.normalWidth,
        values = Private.precision_types,
        hidden = hidden
      })
      addOption(symbol .. "_round_type", {
        type = "select",
        name = L["Round Mode"],
        width = WeakAuras.normalWidth,
        values = Private.round_types,
        hidden = hidden,
        disabled = function()
          return get(symbol .. "_decimal_precision") ~= 0
        end
      })
    end,
    CreateFormatter = function(symbol, get)
      local gcd = get(symbol .. "_gcd_gcd", true)
      local cast = get(symbol .. "_gcd_cast", false)
      local channel = get(symbol .. "_gcd_channel", false)
      local hideZero = get(symbol .. "_gcd_hide_zero", false)
      local precision = get(symbol .. "_decimal_precision", 1)

      local numberToStringFunc
      if precision ~= 0 then
        local format = "%." .. precision .. "f"
        numberToStringFunc = function(number)
          return string.format(format, number)
        end
      else
        local type = get(symbol .. "_round_type", "ceil")
        numberToStringFunc = simpleFormatters[type]
      end

      return function(value, state)
        -- A readable cooldown shown from its duration object formats too.
        if (state.progressType ~= "timed" and state.progressType ~= "durationObject")
        or type(value) ~= "number" or issecretvalue(value) then
          return value
        end

        WeakAuras.WatchGCD()
        local result = value
        local now = GetTime()
        if gcd then
          local gcdDuration, gcdExpirationTime = WeakAuras.GetGCDInfo()
          if gcdDuration ~= 0 then
            result = now + value - gcdExpirationTime
          end
        end

        if cast then
          local _, _, _, _, endTime = WeakAuras.UnitCastingInfo("player")
          local castExpirationTime = endTime and endTime > 0 and (endTime / 1000) or 0
          if castExpirationTime > 0 then
            result = min(result, now + value - castExpirationTime)
          end
        end
        if channel then
          local _, _, _, _, endTime = WeakAuras.UnitChannelInfo("player")
          local castExpirationTime = endTime and endTime > 0 and (endTime / 1000) or 0
          if castExpirationTime > 0 then
            result = min(result, now + value - castExpirationTime)
          end
        end

        if result <= 0 then
          return hideZero and "" or "0"
        end

        return numberToStringFunc(result / WeakAuras.CalculatedGcdDuration())
      end
    end
  }
}

---@type table<string, string>
Private.format_types_display = {}
for k, v in pairs(Private.format_types) do Private.format_types_display[k] = v.display end

---@type table<string, string>
Private.sound_channel_types = {
  Master = L["Master"],
  SFX = ENABLE_SOUNDFX,
  Ambience = ENABLE_AMBIENCE,
  Music = ENABLE_MUSIC,
  Dialog = ENABLE_DIALOG
}

---@type table<string, string>
Private.sound_condition_types = {
  Play = L["Play"],
  Loop = L["Loop"],
  Stop = L["Stop"]
}

---@type table<string, string>
Private.trigger_require_types = {
  any = L["Any Triggers"],
  all = L["All Triggers"],
  custom = L["Custom Function"]
}

---@type table<string, string>
Private.trigger_require_types_one = {
  any = L["Trigger 1"],
  custom = L["Custom Function"]
}

---@type table<string, number>
Private.trigger_modes = {
  ["first_active"] = -10,
}

---@type table<string, string>
Private.debuff_types = {
  HELPFUL = L["Buff"],
  HARMFUL = L["Debuff"],
  BOTH = L["Buff/Debuff"]
}

---@type table<number, string>
Private.tooltip_count = {
  [1] = L["First"],
  [2] = L["Second"],
  [3] = L["Third"]
}

---@type table<string, string>
Private.aura_types = {
  BUFF = L["Buff"],
  DEBUFF = L["Debuff"],
}

---@type table<string, string>
Private.debuff_class_types = {
  magic = L["Magic"],
  curse = L["Curse"],
  disease = L["Disease"],
  poison = L["Poison"],
  enrage = L["Enrage"],
  none = L["None"]
}

do
  Private.debuff_class_types.bleed = L["Bleed"]
end

---@type table<string, string>
Private.player_target_events = {
  PLAYER_TARGET_CHANGED = "target",
  PLAYER_FOCUS_CHANGED = "focus",
  PLAYER_SOFT_ENEMY_CHANGED = "softenemy",
  PLAYER_SOFT_FRIEND_CHANGED = "softfriend",
}

---@type table<string, string>
Private.soft_target_cvars = {
  softenemy = "SoftTargetEnemy",
  softfriend = "SoftTargetFriend"
}

---@type table<string, string>
local target_unit_types = {
  target = L["Target"],
  softenemy = L["Soft Enemy"],
  softfriend = L["Soft Friend"]
}

do
  target_unit_types.focus = L["Focus"]
end

---@type table<string, string>
Private.unit_types = Mixin({
  player = L["Player"],
  group = L["Group"],
  member = L["Specific Unit"],
  pet = L["Pet"],
  multi = L["Multi-target"]
}, target_unit_types)

---@type table<string, string>
Private.unit_types_bufftrigger_2 = Mixin({
  player = L["Player"],
  group = L["Smart Group"],
  raid = L["Raid"],
  party = L["Party"],
  boss = L["Boss"],
  arena = L["Arena"],
  nameplate = L["Nameplate"],
  pet = L["Pet"],
  member = L["Specific Unit"],
  multi = L["Multi-target"]
}, target_unit_types)

---@type table<string, string>
Private.actual_unit_types = Mixin({
  player = L["Player"],
  pet = L["Pet"],
}, target_unit_types)

---@type table<string, string>
Private.actual_unit_types_with_specific = Mixin({
  player = L["Player"],
  pet = L["Pet"],
  member = L["Specific Unit"]
}, target_unit_types)

---@type table<string, string>
Private.actual_unit_types_cast = Mixin({
  player = L["Player"],
  group = L["Smart Group"],
  party = L["Party"],
  raid = L["Raid"],
  boss = L["Boss"],
  arena = L["Arena"],
  nameplate = L["Nameplate"],
  pet = L["Pet"],
  member = L["Specific Unit"],
}, target_unit_types)

-- Spell Cast Succeeded: cast events for any unit but the player and their
-- pet carry secret values on this client (SecretWhenUnitSpellCastRestricted),
-- so only those two can be matched.
---@type table<string, string>
Private.actual_unit_types_own_cast = {
  player = L["Player"],
  pet = L["Pet"],
}

---@type string
Private.actual_unit_types_cast_tooltip = L["• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.\n• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.\n|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.\n• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.\n• |cffffff00Smart Group|r adjusts to your current group type, matching just the \"player\" when solo, \"party\" units (including \"player\") in a party or \"raid\" units in a raid.\n\n|cffffff00*|r Yellow Unit settings will create clones for each matching unit while this trigger is providing Dynamic Info to the Aura."]

---@type table<string, string>
Private.threat_unit_types = Mixin({
  boss = L["Boss"],
  member = L["Specific Unit"],
  none = L["At Least One Enemy"]
}, target_unit_types)

---@type table<string, string>
Private.unit_types_range_check = Mixin({
  pet = L["Pet"],
  member = L["Specific Unit"]
}, target_unit_types)

---@type table<number, string>
Private.unit_threat_situation_types = {
  [-1] = L["Not On Threat Table"],
  [0] = "|cFFB0B0B0"..L["Lower Than Tank"].."|r",
  [1] = "|cFFFFFF77"..L["Higher Than Tank"].."|r",
  [2] = "|cFFFF9900"..L["Tanking But Not Highest"].."|r",
  [3] = "|cFFFF0000"..L["Tanking And Highest"].."|r"
}

WeakAuras.class_types = {}
for _, classID in ipairs({1, 2, 3, 4, 5, 7, 8, 9, 11}) do
  local classInfo = Try(C_CreatureInfo and C_CreatureInfo.GetClassInfo, classID)
  if classInfo then
    WeakAuras.class_types[classInfo.classFile] = WrapTextInColorCode(classInfo.className, WA_GetClassColor(classInfo.classFile))
  end
end

WeakAuras.race_types = {}
do
  -- Skyborne has separate Alliance and Horde race records.
  local races = {1, 2, 3, 4, 5, 6, 7, 8, 95, 96}
  for _, raceId in ipairs(races) do
    local raceInfo = Try(C_CreatureInfo and C_CreatureInfo.GetRaceInfo, raceId)
    if raceInfo then
      WeakAuras.race_types[raceInfo.clientFileString] = raceInfo.raceName
    end
  end
end

---@type table<number, string>
do
  Private.covenant_types = {}
  Private.covenant_types[0] = L["None"]
  -- Forever has no Shadowlands covenant selection.
  -- Keep the empty lookup for imported settings without querying retail data.
end

---@type table<string, string>
Private.faction_group = {
  Alliance = L["Alliance"],
  Horde = L["Horde"],
  Neutral = L["Neutral"]
}

---@type table<number, string>
Private.form_types = {};
local function update_forms()
  local oldForms = Private.form_types
  Private.form_types = {}
  Private.form_types[0] = "0 - " .. L["Humanoid"]
  for i = 1, GetNumShapeshiftForms() do
    local _, _, _, id = GetShapeshiftFormInfo(i);
    if(id) then
      local name = Private.ExecEnv.GetSpellName(id);
      if(name) then
        Private.form_types[i] = i.." - "..name
      end
    end
  end
  -- Imported auras may use positions this character does not have: keep them selectable.
  for i = 1, 10 do
    Private.form_types[i] = Private.form_types[i] or (i .. " - " .. L["Not known on this character"])
  end
  if Private.OptionsFrame and not tCompare(oldForms, Private.form_types) then
    Private.OptionsFrame():ReloadOptions()
  end
end

-- Shapeshift form IDs (GetShapeshiftFormID) are the same for every character, unlike
-- bar positions, so they can be chosen without knowing the form. Names come from the
-- form's spell; Moonkin Form reports 31 to 35 depending on race and is stored as 31,
-- and Dire Bear Form (8) counts as Bear Form (5). Listed grouped by class.
---@type table<number, string>
Private.form_id_types = {}
---@type number[]
Private.form_id_order = {}
do
  -- No form at all (GetShapeshiftFormID returns nil) is stored as 0.
  Private.form_id_types[0] = L["Humanoid"]
  Private.form_id_order[1] = 0
  local forms = {
    {5, 5487, "DRUID", "Bear Form"}, {4, 1066, "DRUID", "Aquatic Form"}, {1, 768, "DRUID", "Cat Form"},
    {3, 783, "DRUID", "Travel Form"}, {31, 24858, "DRUID", "Moonkin Form"}, {2, 33891, "DRUID", "Tree of Life"},
    {17, 2457, "WARRIOR", "Battle Stance"}, {18, 71, "WARRIOR", "Defensive Stance"}, {19, 2458, "WARRIOR", "Berserker Stance"},
    {30, 1784, "ROGUE", "Stealth"}, {28, 15473, "PRIEST", "Shadowform"}, {16, 2645, "SHAMAN", "Ghost Wolf"},
  }
  for _, form in ipairs(forms) do
    local formID, spellID, class, fallback = unpack(form)
    local name = Try(Private.ExecEnv.GetSpellName, spellID) or fallback
    local className = WeakAuras.class_types[class]
    Private.form_id_types[formID] = (className and (className .. ": ") or "") .. name
    Private.form_id_order[#Private.form_id_order + 1] = formID
  end
end

local form_frame = CreateFrame("Frame");
form_frame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
form_frame:RegisterEvent("PLAYER_LOGIN")
form_frame:SetScript("OnEvent", update_forms);

---@type table<string, string>
Private.blend_types = {
  ADD = L["Glow"],
  BLEND = L["Opaque"]
}

---@type table<string, string>
Private.texture_wrap_types = {
  CLAMP = L["Clamp"],
  MIRROR = L["Mirror"],
  REPEAT = L["Repeat"],
  CLAMPTOBLACKADDITIVE = L["No Extend"]
}

---@type table<string, string>
Private.slant_mode = {
  INSIDE = L["Keep Inside"],
  EXTEND = L["Extend Outside"]
}

---@type table<string, string>
Private.text_check_types = {
  update = L["Every Frame"],
  event = L["Trigger Update"]
}

---@type table<string, string>
Private.check_types = {
  update = L["Every Frame (High CPU usage)"],
  event = L["Event(s)"]
}

---@type table<string, string>
Private.point_types = {
  BOTTOMLEFT = L["Bottom Left"],
  BOTTOM = L["Bottom"],
  BOTTOMRIGHT = L["Bottom Right"],
  RIGHT = L["Right"],
  TOPRIGHT = L["Top Right"],
  TOP = L["Top"],
  TOPLEFT = L["Top Left"],
  LEFT = L["Left"],
  CENTER = L["Center"]
}

---@type table<string, table>
Private.default_types_for_anchor = {}
for k, v in pairs(Private.point_types) do
  Private.default_types_for_anchor[k] = {
    display = v,
    type = "point"
  }
end

Private.default_types_for_anchor["ALL"] = {
  display = L["Full Region"],
  type = "area"
}

Private.anchor_mode = {
  area = L["Fill Area"],
  point = L["Attach to Point"]
}

Private.inverse_point_types = {
  BOTTOMLEFT = "TOPRIGHT",
  BOTTOM = "TOP",
  BOTTOMRIGHT = "TOPLEFT",
  RIGHT = "LEFT",
  TOPRIGHT = "BOTTOMLEFT",
  TOP = "BOTTOM",
  TOPLEFT = "BOTTOMRIGHT",
  LEFT = "RIGHT",
  CENTER = "CENTER"
}

Private.anchor_frame_types = {
  SCREEN = L["Screen/Parent Group"],
  UIPARENT = L["Screen"],
  PRD = L["Personal Resource Display"],
  MOUSE = L["Mouse Cursor"],
  SELECTFRAME = L["Select Frame"],
  NAMEPLATE = L["Nameplates"],
  UNITFRAME = L["Unit Frames"],
  CUSTOM = L["Custom"]
}

Private.anchor_frame_types_group = {
  SCREEN = L["Screen/Parent Group"],
  UIPARENT = L["Screen"],
  PRD = L["Personal Resource Display"],
  MOUSE = L["Mouse Cursor"],
  SELECTFRAME = L["Select Frame"],
  CUSTOM = L["Custom"]
}

Private.spark_rotation_types = {
  AUTO = L["Automatic Rotation"],
  MANUAL = L["Manual Rotation"]
}

---@type table<string, string>
Private.spark_hide_types = {
  NEVER = L["Never"],
  FULL  = L["Full"],
  EMPTY = L["Empty"],
  BOTH  = L["Full/Empty"]
}

Private.tick_placement_modes = {
  AtValue = L["At Value"],
  AtMissingValue = L["At missing Value"],
  AtPercent = L["At Percent"],
  ValueOffset = L["Offset from progress"]
}

---@type table<string, string>
Private.font_flags = {
  None = L["None"],
  MONOCHROME = L["Monochrome"],
  OUTLINE = L["Outline"],
  THICKOUTLINE  = L["Thick Outline"],
  ["MONOCHROME|OUTLINE"] = L["Monochrome Outline"],
  ["MONOCHROME|THICKOUTLINE"] = L["Monochrome Thick Outline"],
  ["OUTLINE|SLUG"] = L["Outline SLUG"],
  ["THICKOUTLINE|SLUG"] = L["Thick Outline SLUG"],
}

---@type table<string, string>
Private.text_automatic_width = {
  Auto = L["Automatic"],
  Fixed = L["Fixed"]
}

---@type table<string, string>
Private.text_word_wrap = {
  WordWrap = L["Wrap"],
  Elide = L["Elide"]
}

---@type table<string, string>
Private.include_pets_types = {
  PlayersAndPets = L["Players and Pets"],
  PetsOnly = L["Pets only"]
}

---@type table<string, string>
Private.subevent_prefix_types = {
  SWING = L["Swing"],
  RANGE = L["Range"],
  SPELL = L["Spell"],
  SPELL_PERIODIC = L["Periodic Spell"],
  SPELL_BUILDING = L["Spell (Building)"],
  ENVIRONMENTAL = L["Environmental"],
  DAMAGE_SHIELD = L["Damage Shield"],
  DAMAGE_SPLIT = L["Damage Split"],
  DAMAGE_SHIELD_MISSED = L["Damage Shield Missed"],
  PARTY_KILL = L["Party Kill"],
  UNIT_DIED = L["Unit Died"],
  UNIT_DESTROYED = L["Unit Destroyed"],
  UNIT_DISSIPATES = L["Unit Dissipates"],
  ENCHANT_APPLIED = L["Enchant Applied"],
  ENCHANT_REMOVED = L["Enchant Removed"]
}

---@type table<string, string>
Private.subevent_actual_prefix_types = {
  SWING = L["Swing"],
  RANGE = L["Range"],
  SPELL = L["Spell"],
  SPELL_PERIODIC = L["Periodic Spell"],
  SPELL_BUILDING = L["Spell (Building)"],
  ENVIRONMENTAL = L["Environmental"]
}

---@type table<string, string>
Private.subevent_suffix_types = {
  _ABSORBED = L["Absorbed"],
  _DAMAGE = L["Damage"],
  _MISSED = L["Missed"],
  _HEAL = L["Heal"],
  _HEAL_ABSORBED = L["Heal Absorbed"],
  _ENERGIZE = L["Energize"],
  _DRAIN = L["Drain"],
  _LEECH = L["Leech"],
  _INTERRUPT = L["Interrupt"],
  _DISPEL = L["Dispel"],
  _DISPEL_FAILED = L["Dispel Failed"],
  _STOLEN = L["Stolen"],
  _EXTRA_ATTACKS = L["Extra Attacks"],
  _AURA_APPLIED = L["Aura Applied"],
  _AURA_REMOVED = L["Aura Removed"],
  _AURA_APPLIED_DOSE = L["Aura Applied Dose"],
  _AURA_REMOVED_DOSE = L["Aura Removed Dose"],
  _AURA_REFRESH = L["Aura Refresh"],
  _AURA_BROKEN = L["Aura Broken"],
  _AURA_BROKEN_SPELL = L["Aura Broken Spell"],
  _CAST_START = L["Cast Start"],
  _CAST_SUCCESS = L["Cast Success"],
  _CAST_FAILED = L["Cast Failed"],
  _EMPOWER_START = L["Empower Cast Start"],
  _EMPOWER_END = L["Empower Cast End"],
  _EMPOWER_INTERRUPT = L["Empower Cast Interrupt"],
  _INSTAKILL = L["Instakill"],
  _DURABILITY_DAMAGE = L["Durability Damage"],
  _DURABILITY_DAMAGE_ALL = L["Durability Damage All"],
  _CREATE = L["Create"],
  _SUMMON = L["Summon"],
  _RESURRECT = L["Resurrect"]
}

---@type table<number, string>
Private.power_types = {
  [0] = POWER_TYPE_MANA,
  [1] = POWER_TYPE_RED_POWER,
  [2] = POWER_TYPE_FOCUS,
  [3] = POWER_TYPE_ENERGY,
  [4] = COMBO_POINTS,
}

---@type table<string, string>
Private.miss_types = {
  ABSORB = L["Absorb"],
  BLOCK = L["Block"],
  DEFLECT = L["Deflect"],
  DODGE = L["Dodge"],
  EVADE = L["Evade"],
  IMMUNE = L["Immune"],
  MISS = L["Miss"],
  PARRY = L["Parry"],
  REFLECT = L["Reflect"],
  RESIST = L["Resist"]
}

---@type table<string, string>
Private.environmental_types = {
  Drowning = STRING_ENVIRONMENTAL_DAMAGE_DROWNING,
  Falling = STRING_ENVIRONMENTAL_DAMAGE_FALLING,
  Fatigue = STRING_ENVIRONMENTAL_DAMAGE_FATIGUE,
  Fire = STRING_ENVIRONMENTAL_DAMAGE_FIRE,
  Lava = STRING_ENVIRONMENTAL_DAMAGE_LAVA,
  Slime = STRING_ENVIRONMENTAL_DAMAGE_SLIME
}

---@type table<string, string>
Private.combatlog_flags_check_type = {
  Mine = L["Mine"],
  InGroup = L["In Group"],
  InParty = L["In Party"],
  NotInGroup = L["Not in Smart Group"]
}

---@type table<string, string>
Private.combatlog_flags_check_reaction = {
  Hostile = L["Hostile"],
  Neutral = L["Neutral"],
  Friendly = L["Friendly"]
}

---@type table<string, string>
Private.combatlog_flags_check_object_type = {
  Object = L["Object"],
  Guardian = L["Guardian"],
  Pet = L["Pet"],
  NPC = L["NPC"],
  Player = L["Player"]
}

---@type table<number, string>
Private.combatlog_spell_school_types = {
  [1] = STRING_SCHOOL_PHYSICAL,
  [2] = STRING_SCHOOL_HOLY,
  [4] = STRING_SCHOOL_FIRE,
  [8] = STRING_SCHOOL_NATURE,
  [16] = STRING_SCHOOL_FROST,
  [32] = STRING_SCHOOL_SHADOW,
  [64] = STRING_SCHOOL_ARCANE,
  [3] = STRING_SCHOOL_HOLYSTRIKE,
  [5] = STRING_SCHOOL_FLAMESTRIKE,
  [6] = STRING_SCHOOL_HOLYFIRE,
  [9] = STRING_SCHOOL_STORMSTRIKE,
  [10] = STRING_SCHOOL_HOLYSTORM,
  [12] = STRING_SCHOOL_FIRESTORM,
  [17] = STRING_SCHOOL_FROSTSTRIKE,
  [18] = STRING_SCHOOL_HOLYFROST,
  [20] = STRING_SCHOOL_FROSTFIRE,
  [24] = STRING_SCHOOL_FROSTSTORM,
  [33] = STRING_SCHOOL_SHADOWSTRIKE,
  [34] = STRING_SCHOOL_SHADOWLIGHT,
  [36] = STRING_SCHOOL_SHADOWFLAME,
  [40] = STRING_SCHOOL_SHADOWSTORM,
  [48] = STRING_SCHOOL_SHADOWFROST,
  [65] = STRING_SCHOOL_SPELLSTRIKE,
  [66] = STRING_SCHOOL_DIVINE,
  [68] = STRING_SCHOOL_SPELLFIRE,
  [72] = STRING_SCHOOL_SPELLSTORM,
  [80] = STRING_SCHOOL_SPELLFROST,
  [96] = STRING_SCHOOL_SPELLSHADOW,
  [28] = STRING_SCHOOL_ELEMENTAL,
  [62] = STRING_SCHOOL_CHROMATIC,
  [106] = STRING_SCHOOL_COSMIC,
  [124] = STRING_SCHOOL_CHAOS,
  [126] = STRING_SCHOOL_MAGIC,
  [127] = STRING_SCHOOL_CHAOS,
}

---@type table<number, string>
Private.combatlog_spell_school_types_for_ui = {}
for id, str in pairs(Private.combatlog_spell_school_types) do
  Private.combatlog_spell_school_types_for_ui[id] = ("%.3d - %s"):format(id, str)
end

---@type table<string, string>
Private.coin_icons = {
  ["gold"] = "|Tinterface/moneyframe/ui-goldicon:0|t",
  ["silver"] = "|Tinterface/moneyframe/ui-silvericon:0|t",
  ["copper"] = "|Tinterface/moneyframe/ui-coppericon:0|t"
}

---@type table<number, string>
Private.money_precision_types = {
  [1] = "123 " .. Private.coin_icons.gold,
  [2] = "123 " .. Private.coin_icons.gold .. " 45 " .. Private.coin_icons.silver,
  [3] = "123 " .. Private.coin_icons.gold .. " 45 " .. Private.coin_icons.silver .. " 67 " .. Private.coin_icons.copper
}

do
  Private.GetCurrencyListSize = C_CurrencyInfo.GetCurrencyListSize
  Private.GetCurrencyIDFromLink = C_CurrencyInfo.GetCurrencyIDFromLink
  Private.ExpandCurrencyList = C_CurrencyInfo.ExpandCurrencyList
  Private.GetCurrencyListInfo = C_CurrencyInfo.GetCurrencyListInfo
end

local function InitializeCurrencies()
  if Private.discovered_currencies then
    return
  end
  ---@type table<number, string>
  Private.discovered_currencies = {}
  ---@type table<number, number>
  Private.discovered_currencies_sorted = {}
  ---@type table<string, boolean>
  Private.discovered_currencies_headers = {}
  local expanded = {}

  for index = Private.GetCurrencyListSize(), 1, -1 do
    local currencyInfo = Private.GetCurrencyListInfo(index)
    if currencyInfo.isHeader and not currencyInfo.isHeaderExpanded then
      Private.ExpandCurrencyList(index, true)
      expanded[currencyInfo.name] = true
    end
  end

  for index = 1, Private.GetCurrencyListSize() do
    local currencyLink = C_CurrencyInfo.GetCurrencyListLink(index)
    local currencyInfo = Private.GetCurrencyListInfo(index)

    if currencyLink then
      local currencyID = Private.GetCurrencyIDFromLink(currencyLink)
      local icon = currencyInfo.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark" --iconFileID not available on first login
      Private.discovered_currencies[currencyID] = "|T" .. icon .. ":0|t" .. currencyInfo.name
      Private.discovered_currencies_sorted[currencyID] = index
    elseif currencyInfo.isHeader then
      Private.discovered_currencies[currencyInfo.name] = currencyInfo.name
      Private.discovered_currencies_sorted[currencyInfo.name] = index
      Private.discovered_currencies_headers[currencyInfo.name] = true
    end
  end

  for index = Private.GetCurrencyListSize(), 1, -1 do
    local currencyInfo = Private.GetCurrencyListInfo(index)
    if currencyInfo.isHeader and expanded[currencyInfo.name] then
      Private.ExpandCurrencyList(index, false)
    end
  end

  Private.discovered_currencies["member"] = "|Tinterface\\common\\ui-searchbox-icon:0:0:0:-2|t"..L["Specific Currency"];
  Private.discovered_currencies_sorted["member"] = -1;
end

---@type function
Private.GetDiscoveredCurrencies = function()
  InitializeCurrencies()
  return Private.discovered_currencies
end

---@type function
Private.GetDiscoveredCurrenciesSorted  = function()
  InitializeCurrencies()
  return Private.discovered_currencies_sorted
end

---@type function
Private.GetDiscoveredCurrenciesHeaders  = function()
  InitializeCurrencies()
  return Private.discovered_currencies_headers
end

local function InitializeReputations()
  if Private.reputations then
    return
  end

  ---@type table<number, string>
  Private.reputations = {}
  ---@type table<number, number>
  Private.reputations_sorted = {}
  ---@type table<string, boolean>
  Private.reputations_headers = {}

  -- Ensure all factions are shown by adjusting filters
  local showLegacy = true
  if not Private.ExecEnv.AreLegacyReputationsShown() then
    showLegacy = false
    C_Reputation.SetLegacyReputationsShown(true)
  end
  local sortType = 0
  if Private.ExecEnv.GetReputationSortType() > 0 then
    sortType = Private.ExecEnv.GetReputationSortType()
    C_Reputation.SetReputationSortType(0)
  end

  -- Dynamic expansion of all collapsed headers
  local collapsed = {}
  local index = 1
  while index <= Private.ExecEnv.GetNumFactions() do
    local factionData = Private.ExecEnv.GetFactionDataByIndex(index)
    if factionData and factionData.isHeader and factionData.isCollapsed then
      Private.ExecEnv.ExpandFactionHeader(index)
      collapsed[factionData.name] = true
    end
    index = index + 1
  end

  -- Process all faction data
  for i = 1, Private.ExecEnv.GetNumFactions() do
    local factionData = Private.ExecEnv.GetFactionDataByIndex(i)
    if factionData then
      if factionData.currentStanding > 0 or not factionData.isHeader then
        local factionID = factionData.factionID
        if factionID then
          Private.reputations[factionID] = factionData.name
          Private.reputations_sorted[factionID] = i
        end
      else
        local name = factionData.name
        Private.reputations[name] = name
        Private.reputations_sorted[name] = i
        Private.reputations_headers[name] = true
      end
    end
  end

  -- Collapse headers back to their original state
  for i = Private.ExecEnv.GetNumFactions(), 1, -1 do
    local factionData = Private.ExecEnv.GetFactionDataByIndex(i)
    if factionData and collapsed[factionData.name] then
      Private.ExecEnv.CollapseFactionHeader(i)
    end
  end

  -- Restore filters if they were changed
  if not showLegacy then
    C_Reputation.SetLegacyReputationsShown(false)
  end
  if sortType > 0 then
    C_Reputation.SetReputationSortType(sortType)
  end
end

---@type function
Private.GetReputations = function()
  InitializeReputations()
  return Private.reputations
end

---@type function
Private.GetReputationsSorted  = function()
  InitializeReputations()
  return Private.reputations_sorted
end

---@type function
Private.GetReputationsHeaders  = function()
  InitializeReputations()
  return Private.reputations_headers
end

---@type table<number, string>
Private.combatlog_raid_mark_check_type = {
  [0] = RAID_TARGET_NONE,
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1:14|t " .. RAID_TARGET_1, -- Star
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2:14|t " .. RAID_TARGET_2, -- Circle
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3:14|t " .. RAID_TARGET_3, -- Diamond
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4:14|t " .. RAID_TARGET_4, -- Triangle
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5:14|t " .. RAID_TARGET_5, -- Moon
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6:14|t " .. RAID_TARGET_6, -- Square
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:14|t " .. RAID_TARGET_7, -- Cross
  "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8:14|t " .. RAID_TARGET_8, -- Skull
  L["Any"]
}

---@type table<number, number>
Private.combatlog_raidFlags = {
  [0] = 0,
  [1] = 1,
  [2] = 2,
  [4] = 3,
  [8] = 4,
  [16] = 5,
  [32] = 6,
  [64] = 7,
  [128] = 8,
}

---@type table<number, string>
Private.raid_mark_check_type = CopyTable(Private.combatlog_raid_mark_check_type)
Private.raid_mark_check_type[9] = nil

Private.aurabar_tooltip_areas = {
  ICON = L["Icon"],
  BAR = L["Bar"],
  ALL = L["Bar and Icon"]
}

Private.orientation_types = {
  HORIZONTAL_INVERSE = L["Left to Right"],
  HORIZONTAL = L["Right to Left"],
  VERTICAL = L["Bottom to Top"],
  VERTICAL_INVERSE = L["Top to Bottom"]
}

---@type table<string, string>
Private.orientation_with_circle_types = {
  HORIZONTAL_INVERSE = L["Left to Right"],
  HORIZONTAL = L["Right to Left"],
  VERTICAL = L["Bottom to Top"],
  VERTICAL_INVERSE = L["Top to Bottom"],
  CLOCKWISE = L["Clockwise"],
  ANTICLOCKWISE = L["Anticlockwise"]
}

---@type table<string, string>
Private.gradient_orientations = {
  HORIZONTAL = L["Horizontal"],
  VERTICAL = L["Vertical"]
}

Private.spec_types = {
  [1] = SPECIALIZATION.." 1",
  [2] = SPECIALIZATION.." 2",
  [3] = SPECIALIZATION.." 3",
  [4] = SPECIALIZATION.." 4"
}

Private.spec_types_3 = {
  [1] = SPECIALIZATION.." 1",
  [2] = SPECIALIZATION.." 2",
  [3] = SPECIALIZATION.." 3"
}

Private.spec_types_2 = {
  [1] = SPECIALIZATION.." 1",
  [2] = SPECIALIZATION.." 2"
}

WeakAuras.spec_types_specific = {}

---@type table<number, string>
Private.spec_types_all = {}
Private.specs_sorted = {}
local function update_specs()
  for _, classFileName in pairs(WeakAuras.classes_sorted) do
    local classID = WeakAuras.class_ids[classFileName]
    WeakAuras.spec_types_specific[classFileName] = {}
    local numSpecs = Private.ExecEnv.GetNumSpecializationsForClassID(classID) -- see https://github.com/Stanzilla/WoWUIBugs/issues/559
    for i = 1, numSpecs do
      local specId, tabName, _, icon = Private.ExecEnv.GetSpecializationInfoForClassID(classID, i);
      if tabName then
        tinsert(WeakAuras.spec_types_specific[classFileName], "|T"..(icon or "error")..":0|t "..(tabName or "error"));
        local classColor = WA_GetClassColor(classFileName)
        local specIcon = numSpecs > 1 and "|T"..(icon or "error")..":0|t " or " "
        Private.spec_types_all[specId] = CreateAtlasMarkup(GetClassAtlas(classFileName:lower()))
        .. specIcon..(WrapTextInColorCode(tabName, classColor) or "error");
        tinsert(Private.specs_sorted, specId)
      end
    end
  end
end

---@type table<number, string>
Private.talent_types = {}
do
  local spec_frame = CreateFrame("Frame");
  spec_frame:RegisterEvent("PLAYER_LOGIN")
  spec_frame:SetScript("OnEvent", update_specs);
end

---@type table<number, string>
Private.talent_extra_option_types = {
    [0] = L["Talent Known"],
    [1] = L["Talent Selected"],
    [2] = L["Talent |cFFFF0000Not|r Known"],
    [3] = L["Talent |cFFFF0000Not|r Selected"],
}

-- GetTotemInfo() only works for the first 5 totems
---@type table<number, string>
Private.totem_types = {};
local totemString = L["Totem #%i"];
for i = 1, 5 do
  Private.totem_types[i] = totemString:format(i);
end

---@type table<string, string>
Private.loss_of_control_types = {
  NONE = "NONE",
  CHARM = "CHARM",
  CONFUSE = "CONFUSE",
  DISARM = "DISARM",
  FEAR = "FEAR",
  FEAR_MECHANIC = "FEAR_MECHANIC",
  PACIFY = "PACIFY",
  SILENCE = "SILENCE",
  PACIFYSILENCE = "PACIFYSILENCE",
  POSSESS = "POSSESS",
  ROOT = "ROOT",
  SCHOOL_INTERRUPT = "SCHOOL_INTERRUPT",
  STUN = "STUN",
  STUN_MECHANIC = "STUN_MECHANIC",
}

---@type table<number, string>
Private.main_spell_schools = {
  [1] = Try(C_Spell and C_Spell.GetSchoolString, 1),
  [2] = Try(C_Spell and C_Spell.GetSchoolString, 2),
  [4] = Try(C_Spell and C_Spell.GetSchoolString, 4),
  [8] = Try(C_Spell and C_Spell.GetSchoolString, 8),
  [16] = Try(C_Spell and C_Spell.GetSchoolString, 16),
  [32] = Try(C_Spell and C_Spell.GetSchoolString, 32),
  [64] = Try(C_Spell and C_Spell.GetSchoolString, 64),
}

---@type table<string, table<string, string>>
Private.texture_types = {
  ["Blizzard Alerts"] = {
    ["424570"] 	= "Spell Activation Overlay 0",
    ["449486"]  = "Arcane Missiles",
    ["449487"] 	= "Blood Surge",
    ["449488"] 	= "Brain Freeze",
    ["449489"] 	= "Frozen Fingers",
    ["449490"] 	= "Hot Streak",
    ["449491"] 	= "Imp Empowerment",
    ["449492"] 	= "Nightfall",
    ["449493"] 	= "Sudden Death",
    ["449494"] 	= "Sword and Board",
    ["450913"] 	= "Art of War",
    ["450914"] 	= "Eclipse Moon",
    ["450915"] 	= "Eclipse Sun",
    ["450916"] 	= "Focus Fire",
    ["450917"] 	= "Generic Arc 1",
    ["450918"] 	= "Generic Arc 2",
    ["450919"] 	= "Generic Arc 3",
    ["450920"] 	= "Generic Arc 4",
    ["450921"] 	= "Generic Arc 5",
    ["450922"] 	= "Generic Arc 6",
    ["450923"] 	= "Generic Top 1",
    ["450924"] 	= "Generic Top 2",
    ["450925"] 	= "Grand Crusader",
    ["450926"] 	= "Lock and Load",
    ["450927"] 	= "Maelstrom Weapon",
    ["450928"] 	= "Master Marksman",
    ["450929"] 	= "Nature's Grace",
    ["450930"] 	= "Rime",
    ["450931"] 	= "Slice and Dice",
    ["450932"] 	= "Sudden Doom",
    ["450933"] 	= "Surge of Light",
    ["457658"] 	= "Impact",
    ["458740"] 	= "Killing Machine",
    ["458741"] 	= "Molten Core",
    ["459313"] 	= "Daybreak",
    ["459314"] 	= "Hand of Light",
    ["460830"] 	= "Backslash",
    ["460831"] 	= "Fury of Stormrage",
    ["461878"] 	= "Dark Transformation",
    ["463452"] 	= "Shooting Stars",
    ["467696"] 	= "Fulmination",
    ["469752"] 	= "Serendipity",
    ["510822"] 	= "Berserk",
    ["510823"] 	= "Omen of Clarity (Feral)",
    ["511104"] 	= "Blood Boil",
    ["511105"] 	= "Necropolis",
    ["511469"] 	= "Denounce",
    ["592058"] 	= "Surge of Darkness",
    ["603338"] 	= "Dark Tiger",
    ["603339"] 	= "White Tiger",
    ["623950"] 	= "Monk Ox",
    ["623951"] 	= "Monk Serpent",
    ["623952"] 	= "Monk Tiger",
    ["627609"] 	= "Shadow of Death",
    ["627610"] 	= "Ultimatum",
    ["656728"] 	= "Shadow Word Insanity",
    ["774420"] 	= "Tooth and Claw",
    ["801266"] 	= "Backlash_Green",
    ["801267"] 	= "Imp Empowerment Green",
    ["801268"] 	= "Molten Core Green",
    ["898423"] 	= "Predatory Swiftness",
    ["962497"] 	= "Raging Blow",
    ["1001511"]	= "Monk Blackout Kick",
    ["1001512"]	= "Monk Tiger Palm",
    ["1027131"]	= "Arcane Missiles 1",
    ["1027132"]	= "Arcane Missiles 2",
    ["1027133"]	= "Arcane Missiles 3",
    ["1028091"]	= "Monk Ox 2",
    ["1028092"]	= "Monk Ox 3",
    ["1028136"]	= "Maelstrom Weapon 1",
    ["1028137"]	= "Maelstrom Weapon 2",
    ["1028138"]	= "Maelstrom Weapon 3",
    ["1028139"]	= "Maelstrom Weapon 4",
    ["1029138"]	= "Thrill of the Hunt 1",
    ["1029139"]	= "Thrill of the Hunt 2",
    ["1029140"]	= "Thrill of the Hunt 3",
    ["1030393"]	= "Bandits Guile",
    ["1057288"]	= "Echo of the Elements",
    ["1518303"] = "Predatory Swiftness Green",
    ["2851787"] = "Demonic Core",
    ["2851788"] = "High Tide",
    ["2888300"] = "Demonic Core Vertical",
    ["4699056"] = "Essence Burst",
    ["4699057"] = "Snapfire",
    ["6160020"] = "Arcane Soul",
    ["6160021"] = "Hyperthermia",
  },
  ["Icons"] = {
    ["165558"] = "Paw",
    ["165605"] = "Feathers",
    ["165607"] = "Lion",
    ["165608"] = "Cheetah",
    ["165609"] = "Hawk",
    ["165610"] = "Monkey",
    ["165611"] = "Snake",
    ["165612"] = "Wolf",
    ["166036"] = "Rage",
    ["166056"] = "Eye",
    ["166058"] = "Eyes",
    ["166125"] = "Fire",
    ["166386"] = "Snowflake",
    ["166418"] = "Inner Fire",
    ["166423"] = "Intellect",
    ["166606"] = "Leaf",
    ["166662"] = "Shield",
    ["166680"] = "Rampage",
    ["166683"] = "Rapid Fire",
    ["166706"] = "Reticle",
    ["166948"] = "Spirit",
    ["166954"] = "Bull",
    ["166984"] = "Crossed Swords",
    ["166989"] = "Stun Whirl",
    ["240925"] = "Holy Ruin",
    ["240961"] = "Crescent",
    ["240972"] = "Poison Skull",
    ["241049"] = "Star",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\cancel-icon.tga"] = "Cancel Icon",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\cancel-mark.tga"] = "Cancel Mark",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\emoji.tga"] = "Emoji",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\exclamation-mark.tga"] = "Exclamation Mark",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\eyes.tga"] = "Eyes",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\ok-icon.tga"] = "Ok Icon",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\targeting-mark.tga"] = "Targeting Mark",

  },
  ["Runes"] = {
    ["165630"] = "Ringed Aura Rune",
    ["165631"] = "Square Aura Rune",
    ["165633"] = "Tri-Circle Aura Rune",
    ["165634"] = "Tri-Circle Ringed Aura Rune",
    ["165635"] = "Spike-Ringed Aura Rune",
    ["165638"] = "Small Tri-Circle Aura Rune",
    ["165639"] = "Sliced Aura Rune",
    ["165640"] = "Oblong Aura Rune",
    ["165881"] = "Dark Summon",
    ["165885"] = "Death Rune",
    ["165922"] = "Demonic Summon",
    ["165927"] = "Demon Rune",
    ["165928"] = "Demon Rune",
    ["165929"] = "Demon Rune",
    ["166340"] = "Holy Rune",
    ["166341"] = "Holy Cross Rune",
    ["166748"] = "Filled Circular Rune",
    ["166749"] = "Ringed Circular Rune",
    ["166750"] = "Sparse Circular Rune",
    ["166753"] = "Heavy BC Rune",
    ["166754"] = "Light BC Rune",
    ["166757"] = "Circular Frost Rune",
    ["166979"] = "Star Rune",
    ["241003"] = "Dual Blades",
    ["241004"] = "Octagonal Skulls",
    ["241005"] = "Dense Circular Rune",
  },
  ["PvP Emblems"] = {
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-1"] = "Wheelchair",
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-2"] = "Recycle",
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-3"] = "Biohazard",
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-4"] = "Heart",
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-5"] = "Lightning Bolt",
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-6"] = "Bone",
    ["Interface\\PVPFrame\\PVP-Banner-Emblem-7"] = "Glove",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-2"] = "Bull",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-3"] = "Bird Claw",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-4"] = "Canary",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-5"] = "Mushroom",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-6"] = "Cherries",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-7"] = "Ninja",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-8"] = "Dog Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-9"] = "Circled Drop",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-10"] = "Circled Glove",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-11"] = "Winged Blade",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-12"] = "Circled Cross",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-13"] = "Dynamite",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-14"] = "Intellect",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-15"] = "Feather",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-16"] = "Present",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-17"] = "Giant Jaws",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-18"] = "Drums",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-19"] = "Panda",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-20"] = "Crossed Clubs",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-21"] = "Skeleton Key",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-22"] = "Heart Potion",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-23"] = "Trophy",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-24"] = "Crossed Mallets",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-25"] = "Circled Cheetah",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-26"] = "Mutated Chicken",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-27"] = "Anvil",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-28"] = "Dwarf Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-29"] = "Brooch",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-30"] = "Spider",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-31"] = "Dual Hawks",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-32"] = "Cleaver",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-33"] = "Spiked Bull",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-34"] = "Fist of Thunder",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-35"] = "Lean Bull",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-36"] = "Mug",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-37"] = "Sliced Circle",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-38"] = "Totem",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-39"] = "Skull and Crossbones",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-40"] = "Voodoo Doll",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-41"] = "Dual Wolves",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-42"] = "Wolf",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-43"] = "Crossed Wrenches",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-44"] = "Saber-toothed Tiger",
    --["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-45"] = "Targeting Eye", -- Duplicate of 53
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-46"] = "Artifact Disc",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-47"] = "Dice",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-48"] = "Fish Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-49"] = "Crossed Axes",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-50"] = "Doughnut",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-51"] = "Human Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-52"] = "Eyeball",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-53"] = "Targeting Eye",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-54"] = "Monkey Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-55"] = "Circle Skull",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-56"] = "Tipped Glass",
    --["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-57"] = "Saber-toothed Tiger", -- Duplicate of 44
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-58"] = "Pile of Weapons",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-59"] = "Mushrooms",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-60"] = "Pounding Mallet",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-61"] = "Winged Mask",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-62"] = "Axe",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-63"] = "Spiked Shield",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-64"] = "The Horns",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-65"] = "Ice Cream Cone",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-66"] = "Ornate Lockbox",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-67"] = "Roasting Marshmallow",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-68"] = "Smiley Bomb",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-69"] = "Fist",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-70"] = "Spirit Wings",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-71"] = "Ornate Pipe",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-72"] = "Scarab",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-73"] = "Glowing Ball",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-74"] = "Circular Rune",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-75"] = "Tree",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-76"] = "Flower Pot",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-77"] = "Night Elf Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-78"] = "Nested Egg",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-79"] = "Helmed Chicken",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-80"] = "Winged Boot",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-81"] = "Skull and Cross-Wrenches",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-82"] = "Cracked Skull",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-83"] = "Rocket",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-84"] = "Wooden Whistle",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-85"] = "Cogwheel",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-86"] = "Lizard Eye",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-87"] = "Baited Hook",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-88"] = "Beast Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-89"] = "Talons",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-90"] = "Rabbit",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-91"] = "4-Toed Pawprint",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-92"] = "Paw",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-93"] = "Mask",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-94"] = "Spiked Helm",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-95"] = "Dog Treat",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-96"] = "Targeted Orc",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-97"] = "Bird Face",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-98"] = "Lollipop",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-99"] = "5-Toed Pawprint",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-100"] = "Frightened Cat",
    ["Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-101"] = "Eagle Face"
  },
  ["Beams"] = {
    ["167096"] = "Gold Chain",
    ["167097"] = "Iron Chain",
    ["167098"] = "Green Fire Beam",
    ["167099"] = "Red Fire Beam",
    ["167100"] = "Brown Smoke Beam",
    ["167101"] = "Grey Smoke Beam",
    ["167102"] = "Green Vine",
    ["167103"] = "Red Vine",
    ["167104"] = "Blue Water Beam",
    ["167105"] = "Green Water Beam",
    ["186185"] = "Purple Beam",
    ["186186"] = "Red Beam",
    ["186187"] = "Red Drops Beam",
    ["186189"] = "Drain Mana Lightning",
    ["186192"] = "Ethereal Ribbon",
    ["186193"] = "Ghost Chain",
    ["186194"] = "Purple Ghost Chain",
    ["186195"] = "Heal Beam",
    ["186198"] = "Lightning",
    ["186201"] = "Red Lightning",
    ["186202"] = "Mana Beam",
    ["186205"] = "Mana Burn Beam",
    ["186208"] = "Rope",
    ["186211"] = "Shock Lightning",
    ["186214"] = "Soul Beam",
    ["241098"] = "Spirit Link Beam",
    ["241099"] = "Summon Gargoyle Beam",
    ["369749"] = "Straight Purple Beam",
    ["369750"] = "Shadow Beam",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\rainbowbar"] = "Rainbow Bar",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\StripedTexture"] = "Striped Bar",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\stripe-bar.tga"] = "Striped Bar 2",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\stripe-rainbow-bar.tga"] = "Rainbow Bar 2",
  },
  ["Shapes"] = {
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_Smooth"] = "Smooth Circle",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_Smooth_Border"] = "Smooth Circle with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_Squirrel"] = "Spiralled Circle",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_Squirrel_Border"] = "Spiralled Circle with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_White"] = "Circle",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_White_Border"] = "Circle with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_Smooth"] = "Smooth Square",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_Smooth_Border"] = "Smooth Square with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_Smooth_Border2"] = "Smooth Square with Border 2",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_Squirrel"] = "Spiralled Square",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_Squirrel_Border"] = "Spiralled Square with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_White"] = "Square",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_White_Border"] = "Square with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite"] = "Full White Square",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Triangle45"] = "45° Triangle",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Trapezoid"] = "Trapezoid",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\triangle-border.tga"] = "Triangle with Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\triangle.tga"] = "Triangle",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_Smooth2.tga"] = "Smooth Circle Small",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\circle_border5.tga"] = "Circle Border",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\ring_glow3.tga"] = "Circle Border Glow",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\square_mini.tga"] = "Small Square",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\target_indicator.tga"] = "Target Indicator",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\target_indicator_glow.tga"] = "Target Indicator Glow",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\arrows_target.tga"] = "Arrows Target",

    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_AlphaGradient_In.tga"] = "Circle Alpha Gradient In",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Circle_AlphaGradient_Out.tga"] = "Circle Alpha Gradient Out",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Ring_10px.tga"] = "Ring 10px",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Ring_20px.tga"] = "Ring 20px",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Ring_30px.tga"] = "Ring 30px",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Ring_40px.tga"] = "Ring 40px",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_AlphaGradient.tga"] = "Square Alpha Gradient",

    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\square_border_1px.tga"] = "Square Border 1px",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\square_border_5px.tga"] = "Square Border 5px",
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\square_border_10px.tga"] = "Square Border 10px",
  },
  ["Sparks"] = {
    ["130877"] = "Blizzard Spark",
    ["Insanity-Spark"] = "Blizzard Insanity Spark",
    ["XPBarAnim-OrangeSpark"] = "Blizzard XPBar Spark",
    ["GarrMission_EncounterBar-Spark"] = "Blizzard Garrison Mission Encounter Spark",
    ["Legionfall_BarSpark"]= "Blizzard Legionfall Spark",
    ["honorsystem-bar-spark"] = "Blizzard Honor System Spark",
    ["bonusobjectives-bar-spark"] = "Bonus Objectives Spark"
  },
  [BINDING_HEADER_RAID_TARGET] = {
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"] = RAID_TARGET_1,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_2"] = RAID_TARGET_2,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"] = RAID_TARGET_3,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_4"] = RAID_TARGET_4,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_5"] = RAID_TARGET_5,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_6"] = RAID_TARGET_6,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"] = RAID_TARGET_7,
    ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"] = RAID_TARGET_8,
  },
  ["ForeverAuras"] = {
    ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\foreverauras_logo.tga"] = "ForeverAuras logo"
  }
}

if C_Texture and C_Texture.GetAtlasElements then
  if WeakAuras.buildType == "dev" and Private.AtlasList then
    WeakAuras.prettyPrint("Private.AtlasList can be removed now.")
  end

  Private.texture_types["Blizzard Atlas"] = function()
    local atlasList = C_Texture.GetAtlasElements()
    table.sort(atlasList)
    local atlasTable = {}
    for _, atlas in ipairs(atlasList) do
      atlasTable[atlas] = atlas
    end
    return atlasTable
  end
elseif Private.AtlasList then
  Private.texture_types["Blizzard Atlas"] = {}
  for _, atlas in ipairs(Private.AtlasList) do
    Private.texture_types["Blizzard Atlas"][atlas] = atlas
  end
end
local BuildInfo = select(4, GetBuildInfo())

local PowerAurasPath = "Interface\\Addons\\ForeverAuras\\PowerAurasMedia\\Auras\\"
Private.texture_types["PowerAuras Heads-Up"] = {
  [PowerAurasPath.."Aura1"] = "Runed Text",
  [PowerAurasPath.."Aura2"] = "Runed Text On Ring",
  [PowerAurasPath.."Aura3"] = "Power Waves",
  [PowerAurasPath.."Aura4"] = "Majesty",
  [PowerAurasPath.."Aura5"] = "Runed Ends",
  [PowerAurasPath.."Aura6"] = "Extra Majesty",
  [PowerAurasPath.."Aura7"] = "Triangular Highlights",
  [PowerAurasPath.."Aura11"] = "Oblong Highlights",
  [PowerAurasPath.."Aura16"] = "Thin Crescents",
  [PowerAurasPath.."Aura17"] = "Crescent Highlights",
  [PowerAurasPath.."Aura18"] = "Dense Runed Text",
  [PowerAurasPath.."Aura23"] = "Runed Spiked Ring",
  [PowerAurasPath.."Aura24"] = "Smoke",
  [PowerAurasPath.."Aura28"] = "Flourished Text",
  [PowerAurasPath.."Aura33"] = "Droplet Highlights"
}
Private.texture_types["PowerAuras Icons"] = {
  [PowerAurasPath.."Aura8"] = "Rune",
  [PowerAurasPath.."Aura9"] = "Stylized Ghost",
  [PowerAurasPath.."Aura10"] = "Skull and Crossbones",
  [PowerAurasPath.."Aura12"] = "Snowflake",
  [PowerAurasPath.."Aura13"] = "Flame",
  [PowerAurasPath.."Aura14"] = "Holy Rune",
  [PowerAurasPath.."Aura15"] = "Zig-Zag Exclamation Point",
  [PowerAurasPath.."Aura19"] = "Crossed Swords",
  [PowerAurasPath.."Aura21"] = "Shield",
  [PowerAurasPath.."Aura22"] = "Glow",
  [PowerAurasPath.."Aura25"] = "Cross",
  [PowerAurasPath.."Aura26"] = "Droplet",
  [PowerAurasPath.."Aura27"] = "Alert",
  [PowerAurasPath.."Aura29"] = "Paw",
  [PowerAurasPath.."Aura30"] = "Bull",
  --   [PowerAurasPath.."Aura31"] = "Hieroglyphics Horizontal",
  [PowerAurasPath.."Aura32"] = "Hieroglyphics",
  [PowerAurasPath.."Aura34"] = "Circled Arrow",
  [PowerAurasPath.."Aura35"] = "Short Sword",
  --   [PowerAurasPath.."Aura36"] = "Short Sword Horizontal",
  [PowerAurasPath.."Aura45"] = "Circular Glow",
  [PowerAurasPath.."Aura48"] = "Totem",
  [PowerAurasPath.."Aura49"] = "Dragon Blade",
  [PowerAurasPath.."Aura50"] = "Ornate Design",
  [PowerAurasPath.."Aura51"] = "Inverted Holy Rune",
  [PowerAurasPath.."Aura52"] = "Stylized Skull",
  [PowerAurasPath.."Aura53"] = "Exclamation Point",
  [PowerAurasPath.."Aura54"] = "Nonagon",
  [PowerAurasPath.."Aura68"] = "Wings",
  [PowerAurasPath.."Aura69"] = "Rectangle",
  [PowerAurasPath.."Aura70"] = "Low Mana",
  [PowerAurasPath.."Aura71"] = "Ghostly Eye",
  [PowerAurasPath.."Aura72"] = "Circle",
  [PowerAurasPath.."Aura73"] = "Ring",
  [PowerAurasPath.."Aura74"] = "Square",
  [PowerAurasPath.."Aura75"] = "Square Brackets",
  [PowerAurasPath.."Aura76"] = "Bob-omb",
  [PowerAurasPath.."Aura77"] = "Goldfish",
  [PowerAurasPath.."Aura78"] = "Check",
  [PowerAurasPath.."Aura79"] = "Ghostly Face",
  [PowerAurasPath.."Aura84"] = "Overlapping Boxes",
  --   [PowerAurasPath.."Aura85"] = "Overlapping Boxes 45°",
  --   [PowerAurasPath.."Aura86"] = "Overlapping Boxes 270°",
  [PowerAurasPath.."Aura87"] = "Fairy",
  [PowerAurasPath.."Aura88"] = "Comet",
  [PowerAurasPath.."Aura95"] = "Dual Spiral",
  [PowerAurasPath.."Aura96"] = "Japanese Character",
  [PowerAurasPath.."Aura97"] = "Japanese Character",
  [PowerAurasPath.."Aura98"] = "Japanese Character",
  [PowerAurasPath.."Aura99"] = "Japanese Character",
  [PowerAurasPath.."Aura100"] = "Japanese Character",
  [PowerAurasPath.."Aura101"] = "Ball of Flame",
  [PowerAurasPath.."Aura102"] = "Zig-Zag",
  [PowerAurasPath.."Aura103"] = "Thorny Ring",
  [PowerAurasPath.."Aura110"] = "Hunter's Mark",
  --   [PowerAurasPath.."Aura111"] = "Hunter's Mark Horizontal",
  [PowerAurasPath.."Aura112"] = "Kaleidoscope",
  [PowerAurasPath.."Aura113"] = "Jesus Face",
  [PowerAurasPath.."Aura114"] = "Green Mushroom",
  [PowerAurasPath.."Aura115"] = "Red Mushroom",
  [PowerAurasPath.."Aura116"] = "Fire Flower",
  [PowerAurasPath.."Aura117"] = "Radioactive",
  [PowerAurasPath.."Aura118"] = "X",
  [PowerAurasPath.."Aura119"] = "Flower",
  [PowerAurasPath.."Aura120"] = "Petal",
  [PowerAurasPath.."Aura130"] = "Shoop Da Woop",
  [PowerAurasPath.."Aura131"] = "8-Bit Symbol",
  [PowerAurasPath.."Aura132"] = "Cartoon Skull",
  [PowerAurasPath.."Aura138"] = "Stop",
  [PowerAurasPath.."Aura139"] = "Thumbs Up",
  [PowerAurasPath.."Aura140"] = "Palette",
  [PowerAurasPath.."Aura141"] = "Blue Ring",
  [PowerAurasPath.."Aura142"] = "Ornate Ring",
  [PowerAurasPath.."Aura143"] = "Ghostly Skull"
}
Private.texture_types["PowerAuras Separated"] = {
  [PowerAurasPath.."Aura46"] = "8-Part Ring 1",
  [PowerAurasPath.."Aura47"] = "8-Part Ring 2",
  [PowerAurasPath.."Aura55"] = "Skull on Gear 1",
  [PowerAurasPath.."Aura56"] = "Skull on Gear 2",
  [PowerAurasPath.."Aura57"] = "Skull on Gear 3",
  [PowerAurasPath.."Aura58"] = "Skull on Gear 4",
  [PowerAurasPath.."Aura59"] = "Rune Ring Full",
  [PowerAurasPath.."Aura60"] = "Rune Ring Empty",
  [PowerAurasPath.."Aura61"] = "Rune Ring Left",
  [PowerAurasPath.."Aura62"] = "Rune Ring Right",
  [PowerAurasPath.."Aura63"] = "Spiked Rune Ring Full",
  [PowerAurasPath.."Aura64"] = "Spiked Rune Ring Empty",
  [PowerAurasPath.."Aura65"] = "Spiked Rune Ring Left",
  [PowerAurasPath.."Aura66"] = "Spiked Rune Ring Bottom",
  [PowerAurasPath.."Aura67"] = "Spiked Rune Ring Right",
  [PowerAurasPath.."Aura80"] = "Spiked Helm Background",
  [PowerAurasPath.."Aura81"] = "Spiked Helm Full",
  [PowerAurasPath.."Aura82"] = "Spiked Helm Bottom",
  [PowerAurasPath.."Aura83"] = "Spiked Helm Top",
  [PowerAurasPath.."Aura89"] = "5-Part Ring 1",
  [PowerAurasPath.."Aura90"] = "5-Part Ring 2",
  [PowerAurasPath.."Aura91"] = "5-Part Ring 3",
  [PowerAurasPath.."Aura92"] = "5-Part Ring 4",
  [PowerAurasPath.."Aura93"] = "5-Part Ring 5",
  [PowerAurasPath.."Aura94"] = "5-Part Ring Full",
  [PowerAurasPath.."Aura104"] = "Shield Center",
  [PowerAurasPath.."Aura105"] = "Shield Full",
  [PowerAurasPath.."Aura106"] = "Shield Top Right",
  [PowerAurasPath.."Aura107"] = "Shield Top Left",
  [PowerAurasPath.."Aura108"] = "Shield Bottom Right",
  [PowerAurasPath.."Aura109"] = "Shield Bottom Left",
  [PowerAurasPath.."Aura121"] = "Vine Top Right Leaf",
  [PowerAurasPath.."Aura122"] = "Vine Left Leaf",
  [PowerAurasPath.."Aura123"] = "Vine Bottom Right Leaf",
  [PowerAurasPath.."Aura124"] = "Vine Stem",
  [PowerAurasPath.."Aura125"] = "Vine Thorns",
  [PowerAurasPath.."Aura126"] = "3-Part Circle 1",
  [PowerAurasPath.."Aura127"] = "3-Part Circle 2",
  [PowerAurasPath.."Aura128"] = "3-Part Circle 3",
  [PowerAurasPath.."Aura129"] = "3-Part Circle Full",
  [PowerAurasPath.."Aura133"] = "Sliced Orb 1",
  [PowerAurasPath.."Aura134"] = "Sliced Orb 2",
  [PowerAurasPath.."Aura135"] = "Sliced Orb 3",
  [PowerAurasPath.."Aura136"] = "Sliced Orb 4",
  [PowerAurasPath.."Aura137"] = "Sliced Orb 5",
  [PowerAurasPath.."Aura144"] = "Taijitu Bottom",
  [PowerAurasPath.."Aura145"] = "Taijitu Top"
}

Private.texture_types["PowerAuras Words"] = {
  [PowerAurasPath.."Aura20"] = "Power",
  [PowerAurasPath.."Aura37"] = "Slow",
  [PowerAurasPath.."Aura38"] = "Stun",
  [PowerAurasPath.."Aura39"] = "Silence",
  [PowerAurasPath.."Aura40"] = "Root",
  [PowerAurasPath.."Aura41"] = "Disorient",
  [PowerAurasPath.."Aura42"] = "Dispel",
  [PowerAurasPath.."Aura43"] = "Danger",
  [PowerAurasPath.."Aura44"] = "Buff",
  [PowerAurasPath.."Aura44"] = "Buff",
  ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\interrupt"] = "Interrupt"
}

---@type table<string, string>
Private.operator_types = {
  ["=="] = "=",
  ["~="] = "!=",
  [">"] = ">",
  ["<"] = "<",
  [">="] = ">=",
  ["<="] = "<="
}

---@type table<string, string>
Private.equality_operator_types = {
  ["=="] = "=",
  ["~="] = "!="
}

---@type table<string, string>
Private.operator_types_without_equal = {
  [">="] = ">=",
  ["<="] = "<="
}

---@type table<string, string>
Private.string_operator_types = {
  ["=="] = L["Is Exactly"],
  ["find('%s')"] = L["Contains"],
  ["match('%s')"] = L["Matches (Pattern)"]
}

---@type table<string, string>
Private.weapon_types = {
  ["main"] = MAINHANDSLOT,
  ["off"] = SECONDARYHANDSLOT
}

---@type table<string, string>
Private.swing_types = {
  ["main"] = MAINHANDSLOT,
  ["off"] = SECONDARYHANDSLOT
}

do
  ---@type string[]
  Private.rune_specific_types = {
    [1] = L["Rune #1"],
    [2] = L["Rune #2"],
    [3] = L["Rune #3"],
    [4] = L["Rune #4"],
    [5] = L["Rune #5"],
    [6] = L["Rune #6"]
  }
  ---@type string[]
  Private.essence_specific_types = {
    [1] = L["Essence #1"],
    [2] = L["Essence #2"],
    [3] = L["Essence #3"],
    [4] = L["Essence #4"],
    [5] = L["Essence #5"],
    [6] = L["Essence #6"]
  }
end

---@type table<string, string>
Private.custom_trigger_types = {
  ["event"] = L["Event"],
  ["status"] = L["Status"],
  ["stateupdate"] = L["Trigger State Updater (Advanced)"]
}

---@type table<string, string>
Private.eventend_types = {
  ["timed"] = L["Timed"],
  ["custom"] = L["Custom"]
}

---@type table<string, string>
Private.timedeventend_types = {
  ["timed"] = L["Timed"],
}

---@type table<string, string>
Private.justify_types = {
  ["LEFT"] = L["Left"],
  ["CENTER"] = L["Center"],
  ["RIGHT"] = L["Right"]
}

---@type table<string, string>
Private.grow_types = {
  ["LEFT"] = L["Left"],
  ["RIGHT"] = L["Right"],
  ["UP"] = L["Up"],
  ["DOWN"] = L["Down"],
  ["HORIZONTAL"] = L["Centered Horizontal"],
  ["VERTICAL"] = L["Centered Vertical"],
  ["CIRCLE"] = L["Counter Clockwise"],
  ["COUNTERCIRCLE"] = L["Clockwise"],
  ["GRID"] = L["Grid"],
  ["CUSTOM"] = L["Custom"],
}

-- horizontal types: R (right), L (left)
-- vertical types: U (up), D (down)
---@type table<dynamicGroupGridType, string>
Private.grid_types = {
  RU = L["Right, then Up"],
  UR = L["Up, then Right"],
  LU = L["Left, then Up"],
  UL = L["Up, then Left"],
  RD = L["Right, then Down"],
  DR = L["Down, then Right"],
  LD = L["Left, then Down"],
  DL = L["Down, then Left"],
  HD = L["Centered Horizontal, then Down"],
  HU = L["Centered Horizontal, then Up"],
  VR = L["Centered Vertical, then Right"],
  VL = L["Centered Vertical, then Left"],
  DH = L["Down, then Centered Horizontal"],
  UH = L["Up, then Centered Horizontal"],
  LV = L["Left, then Centered Vertical"],
  RV = L["Right, then Centered Vertical"],
  HV = L["Centered Horizontal, then Centered Vertical"],
  VH = L["Centered Vertical, then Centered Horizontal"]
}

---@type table<dynamicGroupCenterType, string>
Private.centered_types_h = {
  LR = L["Left to Right"],
  RL = L["Right to Left"],
  CLR =L["Center, then alternating left and right"],
  CRL = L["Center, then alternating right and left"]
}

---@type table<dynamicGroupCenterType, string>
Private.centered_types_v = {
  LR = L["Bottom to Top"],
  RL = L["Top to Bottom"],
  CLR =L["Center, then alternating bottom and top"],
  CRL = L["Center, then alternating top and bottom"]
}

---@type table<string, string>
Private.text_rotate_types = {
  ["LEFT"] = L["Left"],
  ["NONE"] = L["None"],
  ["RIGHT"] = L["Right"]
}

---@type table<string, string>
Private.align_types = {
  ["LEFT"] = L["Left"],
  ["CENTER"] = L["Center"],
  ["RIGHT"] = L["Right"]
}

---@type table<string, string>
Private.rotated_align_types = {
  ["LEFT"] = L["Top"],
  ["CENTER"] = L["Center"],
  ["RIGHT"] = L["Bottom"]
}

---@type table<string, string>
Private.icon_side_types = {
  ["LEFT"] = L["Left"],
  ["RIGHT"] = L["Right"]
}

---@type table<string, string>
Private.rotated_icon_side_types = {
  ["LEFT"] = L["Top"],
  ["RIGHT"] = L["Bottom"]
}

---@type table<string, string>
Private.anim_types = {
  none = L["None"],
  preset = L["Preset"],
  custom = L["Custom"]
}

---@type table<string, string>
Private.anim_ease_types = {
  none = L["None"],
  easeIn = L["Ease In"],
  easeOut = L["Ease Out"],
  easeOutIn = L["Ease In and Out"]
}

---@type table<string, function>
Private.anim_ease_functions = {
  none = function(percent) return percent end,
  easeIn = function(percent, power)
    return percent ^ power;
  end,
  easeOut = function(percent, power)
    return 1.0 - (1.0 - percent) ^ power;
  end,
  easeOutIn = function(percent, power)
    if percent < .5 then
        return (percent * 2.0) ^ power * .5;
    end
    return 1.0 - ((1.0 - percent) * 2.0) ^ power * .5;
  end
}

---@type table<string, string>
Private.anim_translate_types = {
  straightTranslate = L["Normal"],
  circle = L["Circle"],
  spiral = L["Spiral"],
  spiralandpulse = L["Spiral In And Out"],
  shake = L["Shake"],
  bounce = L["Bounce"],
  bounceDecay = L["Bounce with Decay"],
  custom = L["Custom Function"]
}

---@type table<string, string>
Private.anim_scale_types = {
  straightScale = L["Normal"],
  pulse = L["Pulse"],
  fauxspin = L["Spin"],
  fauxflip = L["Flip"],
  custom = L["Custom Function"]
}

---@type table<string, string>
Private.anim_alpha_types = {
  straight = L["Normal"],
  alphaPulse = L["Pulse"],
  hide = L["Hide"],
  custom = L["Custom Function"]
}

---@type table<string, string>
Private.anim_rotate_types = {
  straight = L["Normal"],
  backandforth = L["Back and Forth"],
  wobble = L["Wobble"],
  custom = L["Custom Function"]
}

---@type table<string, string>
Private.anim_color_types = {
  straightColor = L["Legacy RGB Gradient"],
  straightHSV = L["Gradient"],
  pulseColor = L["Legacy RGB Gradient Pulse"],
  pulseHSV = L["Gradient Pulse"],
  custom = L["Custom Function"]
}

---@type table<string, string>
Private.instance_types = {
  none = L["No Instance"],
  scenario = L["Scenario"],
  party = L["5 Man Dungeon"],
  ten = L["10 Man Raid"],
  twenty = L["20 Man Raid"],
  twentyfive = L["25 Man Raid"],
  fortyman = L["40 Man Raid"],
  flexible = L["Flex Raid"],
  pvp = L["Battleground"],
  arena = L["Arena"],
  ratedpvp = L["Rated Battleground"],
  ratedarena = L["Rated Arena"]
}

---@type table
Private.instance_difficulty_types = {}

-- Use Forever's client data rather than retail's hard-coded difficulty IDs.
Private.instance_difficulty_types[0] = L["None"]
for difficultyID = 1, 240 do
  local name, instanceType = Try(GetDifficultyInfo, difficultyID)
  if name then
    Private.instance_difficulty_types[difficultyID] = string.format("%s (%s, %d)", name, instanceType or "?", difficultyID)
  end
end

---@type table<number, string>
Private.TocToExpansion = {
   [1] = L["Classic"],
   [2] = L["Burning Crusade"],
   [3] = L["Wrath of the Lich King"],
   [4] = L["Cataclysm"],
   [5] = L["Mists of Pandaria"],
   [6] = L["Warlords of Draenor"],
   [7] = L["Legion"],
   [8] = L["Battle for Azeroth"],
   [9] = L["Shadowlands"],
  [10] = L["Dragonflight"],
  [11] = L["The War Within"]
}

---@type table<string, string>
Private.group_types = {
  solo = L["Not in Group"],
  group = L["In Party"],
  raid = L["In Raid"]
}

---@type table<string, string>
do
  Private.difficulty_types = {
    none = L["None"],
    normal = PLAYER_DIFFICULTY1,
    heroic = PLAYER_DIFFICULTY2,
    mythic = PLAYER_DIFFICULTY6,
    timewalking = PLAYER_DIFFICULTY_TIMEWALKER,
    lfr = PLAYER_DIFFICULTY3,
    challenge = PLAYER_DIFFICULTY5
  }
end

---@type table<string, string>

---@type table<string, string>
Private.role_types = {
  TANK = INLINE_TANK_ICON.." "..TANK,
  DAMAGER = INLINE_DAMAGER_ICON.." "..DAMAGER,
  HEALER = INLINE_HEALER_ICON.." "..HEALER
}

---@type table<string, string>
Private.group_member_types = {
  LEADER = L["Leader"],
  ASSIST = L["Assist"],
  NONE = L["None"]
}

---@type table<string, string>
Private.classification_types = {
  worldboss = L["World Boss"],
  rareelite = L["Rare Elite"],
  elite = L["Elite"],
  rare = L["Rare"],
  normal = L["Normal"],
  trivial = L["Trivial (Low Level)"],
  minus = L["Minus (Small Nameplate)"]
}

do
  ---@type table<number, string>
  Private.creature_type_types = {}
  for _, creatureID in ipairs(Try(C_CreatureInfo and C_CreatureInfo.GetCreatureTypeIDs) or {}) do
    local creatureInfo = Try(C_CreatureInfo.GetCreatureTypeInfo, creatureID)
    if creatureInfo then
      Private.creature_type_types[creatureID] = creatureInfo.name
    end
  end
end

do
  ---@type table<number, string>
  Private.creature_family_types = {}
  for _, familyID in ipairs(Try(C_CreatureInfo and C_CreatureInfo.GetCreatureFamilyIDs) or {}) do
    local familyInfo = Try(C_CreatureInfo.GetCreatureFamilyInfo, familyID)
    if familyInfo then
      Private.creature_family_types[familyID] = familyInfo.name
    end
  end
end

---@type table<string, string>
Private.anim_start_preset_types = {
  slidetop = L["Slide from Top"],
  slideleft = L["Slide from Left"],
  slideright = L["Slide from Right"],
  slidebottom = L["Slide from Bottom"],
  fade = L["Fade In"],
  shrink = L["Grow"],
  grow = L["Shrink"],
  spiral = L["Spiral"],
  bounceDecay = L["Bounce"],
  starShakeDecay = L["Star Shake"],
}

---@type table<string, string>
Private.anim_main_preset_types = {
  shake = L["Shake"],
  spin = L["Spin"],
  flip = L["Flip"],
  wobble = L["Wobble"],
  pulse = L["Pulse"],
  alphaPulse = L["Flash"],
  rotateClockwise = L["Rotate Right"],
  rotateCounterClockwise = L["Rotate Left"],
  spiralandpulse = L["Spiral"],
  orbit = L["Orbit"],
  bounce = L["Bounce"]
}

---@type table<string, string>
Private.anim_finish_preset_types = {
  slidetop = L["Slide to Top"],
  slideleft = L["Slide to Left"],
  slideright = L["Slide to Right"],
  slidebottom = L["Slide to Bottom"],
  fade = L["Fade Out"],
  shrink = L["Shrink"],
  grow =L["Grow"],
  spiral = L["Spiral"],
  bounceDecay = L["Bounce"],
  starShakeDecay = L["Star Shake"],
}

---@type table<string, string>
Private.chat_message_types = {
  CHAT_MSG_INSTANCE_CHAT = L["Instance"],
  CHAT_MSG_BG_SYSTEM_NEUTRAL = L["BG-System Neutral"],
  CHAT_MSG_BG_SYSTEM_ALLIANCE = L["BG-System Alliance"],
  CHAT_MSG_BG_SYSTEM_HORDE = L["BG-System Horde"],
  CHAT_MSG_BN_WHISPER = L["Battle.net Whisper"],
  CHAT_MSG_CHANNEL = L["Channel"],
  CHAT_MSG_COMMUNITIES_CHANNEL = L["Communities"],
  CHAT_MSG_EMOTE = L["Emote"],
  CHAT_MSG_GUILD = L["Guild"],
  CHAT_MSG_MONSTER_YELL = L["Monster Yell"],
  CHAT_MSG_MONSTER_EMOTE = L["Monster Emote"],
  CHAT_MSG_MONSTER_SAY = L["Monster Say"],
  CHAT_MSG_MONSTER_WHISPER = L["Monster Whisper"],
  CHAT_MSG_MONSTER_PARTY = L["Monster Party"],
  CHAT_MSG_OFFICER = L["Officer"],
  CHAT_MSG_PARTY = L["Party"],
  CHAT_MSG_RAID = L["Raid"],
  CHAT_MSG_RAID_LEADER = L["Raid Leader"],
  CHAT_MSG_RAID_BOSS_EMOTE = L["Boss Emote"],
  CHAT_MSG_RAID_BOSS_WHISPER = L["Boss Whisper"],
  CHAT_MSG_RAID_WARNING = L["Raid Warning"],
  CHAT_MSG_SAY = L["Say"],
  CHAT_MSG_WHISPER = L["Whisper"],
  CHAT_MSG_YELL = L["Yell"],
  CHAT_MSG_SYSTEM = L["System"],
  CHAT_MSG_LOOT = L["Loot"],
}

---@type table<string, string>
Private.chat_message_leader_event = {
  CHAT_MSG_INSTANCE_CHAT = "CHAT_MSG_INSTANCE_CHAT_LEADER",
  CHAT_MSG_PARTY = "CHAT_MSG_PARTY_LEADER"
}

---@type table<string, string>
Private.send_chat_message_types = {
  WHISPER = L["Whisper"],
  SAY = L["Say"],
  EMOTE = L["Emote"],
  YELL = L["Yell"],
  PARTY = L["Party"],
  GUILD = L["Guild"],
  OFFICER = L["Officer"],
  RAID = L["Raid"],
  SMARTRAID = L["BG>Raid>Party>Say"],
  RAID_WARNING = L["Raid Warning"],
  INSTANCE_CHAT = L["Instance"],
  COMBAT = L["Blizzard Combat Text"],
  PRINT = L["Chat Frame"],
  ERROR = L["Error Frame"]
}

Private.send_chat_message_types.TTS = L["Text-to-speech"]

---@type table<string, string>
Private.group_aura_name_info_types = {
  aura = L["Aura Name"],
  players = L["Player(s) Affected"],
  nonplayers = L["Player(s) Not Affected"]
}

---@type table<string, string>
Private.group_aura_stack_info_types = {
  count = L["Number Affected"],
  stack = L["Aura Stack"]
}

---@type table<string, string>
Private.cast_types = {
  cast = L["Cast"],
  channel = L["Channel (Spell)"]
}

-- register sounds
Register("sound", "Heartbeat Single", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\HeartbeatSingle.ogg")
Register("sound", "Batman Punch", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\BatmanPunch.ogg")
Register("sound", "Bike Horn", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\BikeHorn.ogg")
Register("sound", "Boxing Arena Gong", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\BoxingArenaSound.ogg")
Register("sound", "Bleat", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Bleat.ogg")
Register("sound", "Cat Meow", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\CatMeow2.ogg")
Register("sound", "Kitten Meow", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\KittenMeow.ogg")
Register("sound", "Robot Blip", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\RobotBlip.ogg")
Register("sound", "Sharp Punch", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\SharpPunch.ogg")
Register("sound", "Water Drop", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\WaterDrop.ogg")
Register("sound", "Air Horn", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\AirHorn.ogg")
Register("sound", "Applause", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Applause.ogg")
Register("sound", "Banana Peel Slip", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\BananaPeelSlip.ogg")
Register("sound", "Blast", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Blast.ogg")
Register("sound", "Cartoon Voice Baritone", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\CartoonVoiceBaritone.ogg")
Register("sound", "Cartoon Walking", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\CartoonWalking.ogg")
Register("sound", "Cow Mooing", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\CowMooing.ogg")
Register("sound", "Ringing Phone", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\RingingPhone.ogg")
Register("sound", "Roaring Lion", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\RoaringLion.ogg")
Register("sound", "Shotgun", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Shotgun.ogg")
Register("sound", "Squish Fart", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\SquishFart.ogg")
Register("sound", "Temple Bell", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\TempleBellHuge.ogg")
Register("sound", "Torch", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Torch.ogg")
Register("sound", "Warning Siren", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\WarningSiren.ogg")
Register("sound", "Lich King Apocalypse", 554003) -- Sound\Creature\LichKing\IC_Lich King_Special01.ogg
-- Sounds from freesound.org, see commits for attributions
Register("sound", "Sheep Blerping", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\SheepBleat.ogg")
Register("sound", "Rooster Chicken Call", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\RoosterChickenCalls.ogg")
Register("sound", "Goat Bleeting", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\GoatBleating.ogg")
Register("sound", "Acoustic Guitar", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\AcousticGuitar.ogg")
Register("sound", "Synth Chord", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\SynthChord.ogg")
Register("sound", "Chicken Alarm", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\ChickenAlarm.ogg")
Register("sound", "Xylophone", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Xylophone.ogg")
Register("sound", "Drums", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Drums.ogg")
Register("sound", "Tada Fanfare", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\TadaFanfare.ogg")
Register("sound", "Squeaky Toy Short", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\SqueakyToyShort.ogg")
Register("sound", "Error Beep", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\ErrorBeep.ogg")
Register("sound", "Oh No", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\OhNo.ogg")
Register("sound", "Double Whoosh", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\DoubleWhoosh.ogg")
Register("sound", "Brass", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Brass.mp3")
Register("sound", "Glass", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Glass.mp3")

Register("sound", "Voice: Adds", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Adds.ogg")
Register("sound", "Voice: Boss", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Boss.ogg")
Register("sound", "Voice: Circle", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Circle.ogg")
Register("sound", "Voice: Cross", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Cross.ogg")
Register("sound", "Voice: Diamond", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Diamond.ogg")
Register("sound", "Voice: Don't Release", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\DontRelease.ogg")
Register("sound", "Voice: Empowered", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Empowered.ogg")
Register("sound", "Voice: Focus", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Focus.ogg")
Register("sound", "Voice: Idiot", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Idiot.ogg")
Register("sound", "Voice: Left", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Left.ogg")
Register("sound", "Voice: Moon", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Moon.ogg")
Register("sound", "Voice: Next", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Next.ogg")
Register("sound", "Voice: Portal", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Portal.ogg")
Register("sound", "Voice: Protected", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Protected.ogg")
Register("sound", "Voice: Release", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Release.ogg")
Register("sound", "Voice: Right", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Right.ogg")
Register("sound", "Voice: Run Away", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\RunAway.ogg")
Register("sound", "Voice: Skull", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Skull.ogg")
Register("sound", "Voice: Spread", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Spread.ogg")
Register("sound", "Voice: Square", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Square.ogg")
Register("sound", "Voice: Stack", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Stack.ogg")
Register("sound", "Voice: Star", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Star.ogg")
Register("sound", "Voice: Switch", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Switch.ogg")
Register("sound", "Voice: Taunt", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Taunt.ogg")
Register("sound", "Voice: Triangle", "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\Triangle.ogg")

local PowerAurasSoundPath = "Interface\\Addons\\ForeverAuras\\PowerAurasMedia\\Sounds\\"
Register("sound", "Aggro", PowerAurasSoundPath.."aggro.ogg")
Register("sound", "Arrow Swoosh", PowerAurasSoundPath.."Arrow_swoosh.ogg")
Register("sound", "Bam", PowerAurasSoundPath.."bam.ogg")
Register("sound", "Polar Bear", PowerAurasSoundPath.."bear_polar.ogg")
Register("sound", "Big Kiss", PowerAurasSoundPath.."bigkiss.ogg")
Register("sound", "Bite", PowerAurasSoundPath.."BITE.ogg")
Register("sound", "Burp", PowerAurasSoundPath.."burp4.ogg")
Register("sound", "Cat", PowerAurasSoundPath.."cat2.ogg")
Register("sound", "Chant Major 2nd", PowerAurasSoundPath.."chant2.ogg")
Register("sound", "Chant Minor 3rd", PowerAurasSoundPath.."chant4.ogg")
Register("sound", "Chimes", PowerAurasSoundPath.."chimes.ogg")
Register("sound", "Cookie Monster", PowerAurasSoundPath.."cookie.ogg")
Register("sound", "Electrical Spark", PowerAurasSoundPath.."ESPARK1.ogg")
Register("sound", "Fireball", PowerAurasSoundPath.."Fireball.ogg")
Register("sound", "Gasp", PowerAurasSoundPath.."Gasp.ogg")
Register("sound", "Heartbeat", PowerAurasSoundPath.."heartbeat.ogg")
Register("sound", "Hiccup", PowerAurasSoundPath.."hic3.ogg")
Register("sound", "Huh?", PowerAurasSoundPath.."huh_1.ogg")
Register("sound", "Hurricane", PowerAurasSoundPath.."hurricane.ogg")
Register("sound", "Hyena", PowerAurasSoundPath.."hyena.ogg")
Register("sound", "Kaching", PowerAurasSoundPath.."kaching.ogg")
Register("sound", "Moan", PowerAurasSoundPath.."moan.ogg")
Register("sound", "Panther", PowerAurasSoundPath.."panther1.ogg")
Register("sound", "Phone", PowerAurasSoundPath.."phone.ogg")
Register("sound", "Punch", PowerAurasSoundPath.."PUNCH.ogg")
Register("sound", "Rain", PowerAurasSoundPath.."rainroof.ogg")
Register("sound", "Rocket", PowerAurasSoundPath.."rocket.ogg")
Register("sound", "Ship's Whistle", PowerAurasSoundPath.."shipswhistle.ogg")
Register("sound", "Gunshot", PowerAurasSoundPath.."shot.ogg")
Register("sound", "Snake Attack", PowerAurasSoundPath.."snakeatt.ogg")
Register("sound", "Sneeze", PowerAurasSoundPath.."sneeze.ogg")
Register("sound", "Sonar", PowerAurasSoundPath.."sonar.ogg")
Register("sound", "Splash", PowerAurasSoundPath.."splash.ogg")
Register("sound", "Squeaky Toy", PowerAurasSoundPath.."Squeakypig.ogg")
Register("sound", "Sword Ring", PowerAurasSoundPath.."swordecho.ogg")
Register("sound", "Throwing Knife", PowerAurasSoundPath.."throwknife.ogg")
Register("sound", "Thunder", PowerAurasSoundPath.."thunder.ogg")
Register("sound", "Wicked Male Laugh", PowerAurasSoundPath.."wickedmalelaugh1.ogg")
Register("sound", "Wilhelm Scream", PowerAurasSoundPath.."wilhelm.ogg")
Register("sound", "Wicked Female Laugh", PowerAurasSoundPath.."wlaugh.ogg")
Register("sound", "Wolf Howl", PowerAurasSoundPath.."wolf5.ogg")
Register("sound", "Yeehaw", PowerAurasSoundPath.."yeehaw.ogg")

---@type table<string, string>
Private.sound_types = {
  [" Fojji"] = "FojjiCore recorded voice",
  [" custom"] = " " .. L["Custom"],
  [" KitID"] = " " .. L["Sound by Kit ID"]
}

---@type table
Private.sound_file_types = {}

for name, path in next, LSM:HashTable("sound") or {} do
  Private.sound_types[path] = name
  Private.sound_file_types[path] = name
end

LSM.RegisterCallback(WeakAuras, "LibSharedMedia_Registered", function(_, mediatype, key)
  if mediatype == "sound" then
    local path = LSM:Fetch(mediatype, key)
    if path then
      Private.sound_types[path] = key
      Private.sound_file_types[path] = key
    end
  elseif mediatype == "statusbar" or mediatype == "statusbar_atlas" then
    local path = LSM:Fetch(mediatype, key)
    if path then
      Private.texture_types["LibSharedMedia Textures"][path] = key
    end
  end
end)

Private.texture_types["LibSharedMedia Textures"] = {}
for _, mediaType in ipairs{"statusbar", "statusbar_atlas"} do
  local mediaTable = LSM:HashTable(mediaType)
  if mediaTable then
    for name, path in pairs(mediaTable) do
      Private.texture_types["LibSharedMedia Textures"][path] = name
    end
  end
end

-- register options font
Register("font", "Fira Mono Medium", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\FiraMono-Medium.ttf", FONT_LOCALES)
-- Other Fira fonts
Register("font", "Fira Sans Black", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\FiraSans-Heavy.ttf", FONT_LOCALES)
Register("font", "Fira Sans Condensed Black", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\FiraSansCondensed-Heavy.ttf", FONT_LOCALES)
Register("font", "Fira Sans Condensed Medium", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\FiraSansCondensed-Medium.ttf", FONT_LOCALES)
Register("font", "Fira Sans Medium", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\FiraSans-Medium.ttf", FONT_LOCALES)
Register("font", "PT Sans Narrow Regular", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\PTSansNarrow-Regular.ttf", FONT_LOCALES)
Register("font", "PT Sans Narrow Bold", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\PTSansNarrow-Bold.ttf", FONT_LOCALES)
Register("font", "Inter", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\Inter-Regular.ttf", FONT_LOCALES)
Register("font", "Inter Medium", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\Inter-Medium.ttf", FONT_LOCALES)
Register("font", "Inter SemiBold", "Interface\\Addons\\ForeverAuras\\Media\\Fonts\\Inter-SemiBold.ttf", FONT_LOCALES)

-- register plain white border
Register("border", "Square Full White", [[Interface\AddOns\ForeverAuras\Media\Textures\Square_FullWhite.tga]])

Register("statusbar", "Clean", [[Interface\AddOns\ForeverAuras\Media\Textures\Statusbar_Clean]])
Register("statusbar", "Stripes", [[Interface\AddOns\ForeverAuras\Media\Textures\Statusbar_Stripes]])
Register("statusbar", "Thick Stripes", [[Interface\AddOns\ForeverAuras\Media\Textures\Statusbar_Stripes_Thick]])
Register("statusbar", "Thin Stripes", [[Interface\AddOns\ForeverAuras\Media\Textures\Statusbar_Stripes_Thin]])
Register("border", "Drop Shadow", [[Interface\AddOns\ForeverAuras\Media\Textures\Border_DropShadow]])

if PowerBarColor then
  local function capitalizeFirstLetter(str)
    -- Split the string into words separated by underscores
    local words = {}
    for word in string.gmatch(str, "[^_]+") do
      table.insert(words, word)
    end
    -- Capitalize the first letter of each word
    for i, word in ipairs(words) do
      words[i] = word:sub(1, 1):upper() .. word:sub(2):lower()
    end
    return table.concat(words, " ")
  end

  -- Client power colours may hold non-table entries; skip anything that is not a colour entry.
  for power, data in pairs(type(PowerBarColor) == "table" and PowerBarColor or {}) do
    local name, path
    if type(data) ~= "table" then
      -- Not a colour entry.
    elseif type(power) == "string" and type(data.atlas) == "string" then
      name = "Blizzard " .. capitalizeFirstLetter(power)
      path = data.atlas
    elseif type(data.atlasElementName) == "string" then
      name = "Blizzard " .. data.atlasElementName
      path = "UI-HUD-UnitFrame-Player-PortraitOff-Bar-" .. data.atlasElementName
    end
    if name and path then
      pcall(LSM.Register, LSM, "statusbar_atlas", name, path)
    end
  end
end

---@type table<string, string>
Private.duration_types = {
  seconds = L["Seconds"],
  relative = L["Relative"]
}

---@type table<string, string>
Private.duration_types_no_choice = {
  seconds = L["Seconds"]
}

---@type table<number, string>
Private.gtfo_types = {
  [1] = L["High Damage"],
  [2] = L["Low Damage"],
  [3] = L["Fail Alert"],
  [4] = L["Friendly Fire"]
}

---@type table<string, string>
Private.pet_behavior_types = {
  passive = PET_MODE_PASSIVE,
  defensive = PET_MODE_DEFENSIVE,
  assist = PET_MODE_ASSIST
}

---@type table<number, string>
do
  Private.pet_spec_types = {
    [1] = select(2, Try(GetSpecializationInfoByID, 74)), -- Ferocity
    [2] = select(2, Try(GetSpecializationInfoByID, 81)), -- Tenacity
    [3] = select(2, Try(GetSpecializationInfoByID, 79)) -- Cunning
  }
end

---@type table<string, string>
Private.cooldown_progress_behavior_types = {
  showOnCooldown = L["On Cooldown"],
  showOnReady = L["Not on Cooldown"],
  showAlways = L["Always"]
}

---@type table<string, string>
Private.cooldown_types = {
  auto = L["Auto"],
  charges = L["Charges"],
  cooldown = L["Cooldown"]
}

---@type table<string, string>
Private.bufftrigger_progress_behavior_types = {
  showOnActive = L["Buffed/Debuffed"],
  showOnMissing = L["Missing"],
  showAlways= L["Always"]
}

---@type table<string, string>
Private.bufftrigger_2_progress_behavior_types = {
  showOnActive = L["Aura(s) Found"],
  showOnMissing = L["Aura(s) Missing"],
  showAlways = L["Always"],
  showOnMatches = L["Match Count"]
}

---@type table<string, string>
Private.bufftrigger_2_preferred_match_types = {
  showLowest = L["Least remaining time"],
  showHighest = L["Most remaining time"],
  showLowestSpellId = L["Lowest Spell Id"],
  showHighestSpellId = L["Highest Spell Id"],
}

---@type table<string, string>
Private.bufftrigger_2_per_unit_mode = {
  affected = L["Affected"],
  unaffected = L["Unaffected"],
  all = L["All"]
}

Private.item_slot_types = {
  [1]  = HEADSLOT,
  [2]  = NECKSLOT,
  [3]  = SHOULDERSLOT,
  [5]  = CHESTSLOT,
  [6]  = WAISTSLOT,
  [7]  = LEGSSLOT,
  [8]  = FEETSLOT,
  [9]  = WRISTSLOT,
  [10] = HANDSSLOT,
  [11] = FINGER0SLOT_UNIQUE,
  [12] = FINGER1SLOT_UNIQUE,
  [13] = TRINKET0SLOT_UNIQUE,
  [14] = TRINKET1SLOT_UNIQUE,
  [15] = BACKSLOT,
  [16] = MAINHANDSLOT,
  [17] = SECONDARYHANDSLOT,
  -- Forever keeps the Classic ranged slot (bows, guns, wands, relics); the
  -- global string is absent on clients without that slot.
  [18] = RANGEDSLOT or L["Ranged"],
  [19] = TABARDSLOT,
  -- The retail profession, cooking and fishing slots (20-28) are not part of
  -- the Forever client, whose equipped slots end at the tabard.
}

-- Ammo: what a blank Item IDs field counts.
---@type table<string, string>
Private.ammo_mode_types = {
  equipped = "Equipped ammo",
  all = "All carried ammo",
}

-- Spell in Range (Action Bar): range is against the current target only.
---@type table<string, string>
Private.action_range_types = {
  inRange = "In Range",
  outOfRange = "Out of Range",
  noTarget = "No Target",
}

---@type table<string, string>
Private.charges_change_type = {
  GAINED = L["Gained"],
  LOST = L["Lost"],
  CHANGED = L["Changed"]
}

---@type table<string, string>
Private.charges_change_condition_type = {
  GAINED = L["Gained"],
  LOST = L["Lost"]
}

---@type table<string, string>
Private.combat_event_type = {
  PLAYER_REGEN_ENABLED = L["Leaving"],
  PLAYER_REGEN_DISABLED = L["Entering"]
}

---@type table<string, string>
Private.encounter_event_type = {
  ENCOUNTER_END = L["Leaving"],
  ENCOUNTER_START = L["Entering"]
}

---@type table<number, string>
Private.bool_types = {
  [0] = L["False"],
  [1] = L["True"]
}

---@type table<string, string>
Private.absorb_modes = {
  OVERLAY_FROM_START = L["Attach to Start"],
  OVERLAY_FROM_END = L["Attach to End"],
  OVERLAY_FROM_END_REVERSE = L["Attach to End, backwards"]
}

---@type table
Private.mythic_plus_affixes = {}

local mythic_plus_ignorelist = {
  [1] = true,
  [15] = true
}

do
  for i = 1, 255 do
    local r = not mythic_plus_ignorelist[i] and Try(C_ChallengeMode and C_ChallengeMode.GetAffixInfo, i)
    if r then
      Private.mythic_plus_affixes[i] = r
    end
  end
end

---@type table<number, table<string, any>>
Private.update_categories = {
  {
    name = "anchor",
    -- Note, these are special cased for child auras and considered arrangement
    fields = {
      "xOffset",
      "yOffset",
      "selfPoint",
      "anchorPoint",
      "anchorFrameType",
      "anchorFrameFrame",
      "frameStrata",
      "height",
      "width",
      "fontSize",
      "scale",
    },
    default = false,
    label = L["Size & Position"],
  },
  {
    name = "userconfig",
    fields = {"config"},
    default = false,
    label = L["Custom Configuration"],
  },
  {
    name = "name",
    fields = {"id"},
    default = true,
    label = L["Aura Names"],
  },
  {
    name = "display",
    fields = {},
    default = true,
    label = L["Display"],
  },
  {
    name = "trigger",
    fields = {"triggers"},
    default = true,
    label = L["Trigger"],
  },
  {
    name = "conditions",
    fields = {"conditions"},
    default = true,
    label = L["Conditions"],
  },
  {
    name = "load",
    fields = {"load"},
    default = true,
    label = L["Load Conditions"],
  },
  {
    name = "action",
    fields = {"actions"},
    default = true,
    label = L["Actions"],
  },
  {
    name = "animation",
    fields = {"animation"},
    default = true,
    label = L["Animations"],
  },
  {
    name = "authoroptions",
    fields = {"authorOptions"},
    default = true,
    label = L["Author Options"]
  },
  {
    name = "arrangement",
    fields = {
      "grow",
      "space",
      "stagger",
      "sort",
      "hybridPosition",
      "radius",
      "align",
      "rotation",
      "constantFactor",
      "hybridSortMode",
    },
    default = true,
    label = L["Group Arrangement"],
  },
  {
    name = "oldchildren",
    fields = {},
    default = true,
    label = L["Remove Obsolete Auras"],
    skipInSummary = true
  },
  {
    name = "newchildren",
    fields = {},
    default = true,
    label = L["Add Missing Auras"],
    skipInSummary = true
  },
  {
    name = "metadata",
    fields = {
      "url",
      "desc",
      "version",
      "semver",
      "wagoID", -- i don't *love* that we're so closely tied to wago, but eh
    },
    default = true,
    label = L["Meta Data"],
  },
  {
    name = "wasync",
    fields = {
      "exrtLastSync",
      "exrtLastSender",
      "exrtUpdateConfig",
      "exrtDefaultLoadNever",
      "rg_custom_error_handler",
      "exrtToSend",
    },
    default = false,
    label = "WASync settings",
  },
}

-- fields that are handled as special cases when importing
-- mismatch of internal fields is not counted as a difference
---@type table<string, boolean>
Private.internal_fields = {
  uid = true,
  internalVersion = true,
  sortHybridTable = true,
  tocversion = true,
  parent = true,
  controlledChildren = true,
  source = true
}

-- fields that are not included in exported data
-- these represent information which is only meaningful inside the db,
-- or are represented in other ways in exported
Private.non_transmissable_fields = {
  controlledChildren = true,
  parent = true,
  authorMode = true,
  skipWagoUpdate = true,
  ignoreWagoUpdate = true,
  preferToUpdate = true,
  information = {
    saved = true
  }
}

-- For nested groups, we do transmit parent + controlledChildren
Private.non_transmissable_fields_v2000 = {
  authorMode = true,
  skipWagoUpdate = true,
  ignoreWagoUpdate = true,
  preferToUpdate = true,
  information = {
    saved = true
  }
}

---@type table<string, any>
Private.data_stub = {
  -- note: this is the minimal data stub which prevents false positives in diff upon reimporting an aura.
  -- pending a refactor of other code which adds unnecessary fields, it is possible to shrink it
  triggers = {
    {
      trigger = {
        type = "aura2",
        names = {},
        event = "Health",
        subeventPrefix = "SPELL",
        subeventSuffix = "_CAST_START",
        spellIds = {},
        unit = "player",
        debuffType = "HELPFUL",
      },
      untrigger = {},
    },
  },
  load = {
    size = {
      multi = {},
    },
    spec = {
      multi = {},
    },
    class = {
      multi = {},
    },
    talent = {
      multi = {},
    },
  },
  actions = {
    init = {},
    start = {},
    finish = {},
  },
  animation = {
    start = {
      type = "none",
      duration_type = "seconds",
      easeType = "none",
      easeStrength = 3,
    },
    main = {
      type = "none",
      duration_type = "seconds",
      easeType = "none",
      easeStrength = 3,
    },
    finish = {
      type = "none",
      duration_type = "seconds",
      easeType = "none",
      easeStrength = 3,
    },
  },
  conditions = {},
  config = {},
  authorOptions = {},
  information = {},
}

---@type table<string, string>
Private.author_option_classes = {
  toggle = "simple",
  input = "simple",
  number = "simple",
  range = "simple",
  color = "simple",
  select = "simple",
  media = "simple",
  multiselect = "simple",
  description = "noninteractive",
  space = "noninteractive",
  header = "noninteractive",
  group = "group"
}

---@type table<string, string>
Private.author_option_types = {
  toggle = L["Toggle"],
  input = L["String"],
  number = L["Number"],
  range = L["Slider"],
  description = L["Description"],
  color = L["Color"],
  select = L["Dropdown Menu"],
  space = L["Space"],
  multiselect = L["Toggle List"],
  media = L["Media"],
  header = L["Separator"],
  group = L["Option Group"],
}

---@type table<string, table<string, any>>
Private.author_option_fields = {
  common = {
    type = true,
    name = true,
    useDesc = true,
    desc = true,
    key = true,
    width = true,
  },
  number = {
    min = 0,
    max = 1,
    step = .05,
    default = 0,
  },
  range = {
    min = 0,
    max = 1,
    step = .05,
    default = 0,
  },
  input = {
    default = "",
    useLength = false,
    length = 10,
    multiline = false,
  },
  toggle = {
    default = false,
  },
  description = {
    text = "",
    fontSize = "medium",
  },
  color = {
    default = {1, 1, 1, 1},
  },
  select = {
    values = {"val1"},
    default = 1,
  },
  space = {
    variableWidth = true,
    useHeight = false,
    height = 1,
  },
  media = {
    mediaType = "sound",
    media = "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\AirHorn.ogg"
  },
  multiselect = {
    default = {true},
    values = {"val1"},
  },
  header = {
    useName = false,
    text = "",
  },
  group = {
    groupType = "simple",
    useCollapse = true,
    collapse = false,
    limitType = "none",
    size = 10,
    nameSource = 0,
    hideReorder = true,
    entryNames = nil, -- handled as a special case in code
    subOptions = {},
    noMerge = false,
  }
}

---@type table<string, string>
Private.shared_media_types = {
  sound = L["Sound"],
  font = L["Font"],
  border = L["Border"],
  background = L["Background"],
  statusbar = L["Status Bar"]
}

---@type table<string, string>
Private.author_option_media_defaults = {
  sound = "Interface\\AddOns\\ForeverAuras\\Media\\Sounds\\AirHorn.ogg",
  font = "Friz Quadrata TT",
  border = "1 Pixel",
  background = "None",
  statusbar = "Blizzard",
}

---@type table<string, string>
Private.author_option_media_controls = {
  statusbar = "LSM30_Statusbar",
  border = "LSM30_Border",
  background = "LSM30_Background",
  font = "LSM30_Font"
}

---@type table<string, string>
Private.author_option_media_itemControls = {
  sound = "WeakAurasMediaSound"
}

---@type table<number, string>
Private.array_entry_name_types = {
  [-1] = L["Fixed Names"],
  [0] = L["Entry Order"],
  -- the rest is auto-populated with indices which are valid entry name sources
}

-- option types which can be used to generate entry names on arrays
---@type table<string, boolean>
Private.name_source_option_types = {
  input = true,
  number = true,
  range = true,
}

---@type table<string, string>
Private.group_limit_types = {
  none = L["Unlimited"],
  max = L["Limited"],
  fixed = L["Fixed Size"],
}

---@type table<string, string>
Private.group_option_types = {
  simple = L["Simple"],
  array = L["Array"],
}

---@type table<number, string>
Private.difficulty_info = {
  [1] = {
    size = "party",
    difficulty = "normal",
  },
  [2] = {
    size = "party",
    difficulty = "heroic",
  },
  [3] = {
    size = "ten",
    difficulty = "normal",
  },
  [4] = {
    size = "twentyfive",
    difficulty = "normal",
  },
  [5] = {
    size = "ten",
    difficulty = "heroic",
  },
  [6] = {
    size = "twentyfive",
    difficulty = "heroic",
  },
  [7] = {
    size = "twentyfive",
    difficulty = "lfr",
  },
  [8] = {
    size = "party",
    difficulty = "challenge",
  },
  [9] = {
    size = "fortyman",
    difficulty = "normal",
  },
  [11] = {
    size = "scenario",
    difficulty = "heroic",
  },
  [12] = {
    size = "scenario",
    difficulty = "normal",
  },
  -- 13 is unused
  [14] = {
    size = "flexible",
    difficulty = "normal",
  },
  [15] = {
    size = "flexible",
    difficulty = "heroic",
  },
  [16] = {
    size = "twenty",
    difficulty = "mythic",
  },
  [17] = {
    size = "flexible",
    difficulty = "lfr",
  },
  [23] = {
    size = "party",
    difficulty = "mythic",
  },
  [24] = {
    size = "party",
    difficulty = "timewalking",
  },
  [33] = {
    size = "flexible",
    difficulty = "timewalking",
  },
  [148] = {
    size = "twenty",
    difficulty = "normal",
  },
  [173] = {
    size = "party",
    difficulty = "normal",
  },
  [174] = {
    size = "party",
    difficulty = "heroic",
  },
  [175] = {
    size = "ten",
    difficulty = "heroic",
  },
  [176] = {
    size = "twentyfive",
    difficulty = "heroic",
  },
  [186] = {
    size = "fortyman",
    difficulty = "normal",
  },
  [226] = {
    size = "twenty",
    difficulty = "normal",
  },
  [233] = {
    size = "flexible",
    difficulty = "mythic",
  }
}

Private.glow_types = {
  ACShine = L["Autocast Shine"],
  Pixel = L["Pixel Glow"],
  buttonOverlay = L["Action Button Glow"],
}

do
  Private.glow_types.Proc = L["Proc Glow"]
end

---@type table<string, string>
Private.font_sizes = {
  small = L["Small"],
  medium = L["Medium"],
  large = L["Large"],
}

-- unitIds registerable with RegisterUnitEvent
---@type table<string, boolean>
Private.baseUnitId = {
  ["player"] = true,
  ["target"] = true,
  ["pet"] = true,
  ["focus"] = true,
  ["vehicle"] = true,
  ["softenemy"] = true,
  ["softfriend"] = true
}

---@type table<string, boolean>
Private.multiUnitId = {
  ["nameplate"] = true,
  ["boss"] = true,
  ["arena"] = true,
  ["group"] = true,
  ["grouppets"] = true,
  ["grouppetsonly"] = true,
  ["party"] = true,
  ["partypets"] = true,
  ["partypetsonly"] = true,
  ["raid"] = true,
}

Private.multiUnitUnits = {
  ["nameplate"] = {},
  ["boss"] = {},
  ["arena"] = {},
  ["group"] = {},
  ["party"] = {},
  ["raid"] = {}
}

Private.multiUnitUnits.group["player"] = true
Private.multiUnitUnits.party["player"] = true

Private.multiUnitUnits.group["pet"] = true
Private.multiUnitUnits.party["pet"] = true

for i = 1, 4 do
  Private.baseUnitId["party"..i] = true
  Private.baseUnitId["partypet"..i] = true
  Private.multiUnitUnits.group["party"..i] = true
  Private.multiUnitUnits.party["party"..i] = true
  Private.multiUnitUnits.group["partypet"..i] = true
  Private.multiUnitUnits.party["partypet"..i] = true
end

do
  for i = 1, 10 do
    Private.baseUnitId["boss"..i] = true
    Private.multiUnitUnits.boss["boss"..i] = true
  end
  for i = 1, 5 do
    Private.baseUnitId["arena"..i] = true
    Private.multiUnitUnits.arena["arena"..i] = true
  end
end

for i = 1, 40 do
  Private.baseUnitId["raid"..i] = true
  Private.baseUnitId["raidpet"..i] = true
  Private.baseUnitId["nameplate"..i] = true
  Private.multiUnitUnits.nameplate["nameplate"..i] = true
  Private.multiUnitUnits.group["raid"..i] = true
  Private.multiUnitUnits.raid["raid"..i] = true
  Private.multiUnitUnits.group["raidpet"..i] = true
  Private.multiUnitUnits.raid["raidpet"..i] = true
end

---@type table<number, string>
Private.dbm_types = {
  [1] = L["Add"],
  [2] = L["AOE"],
  [3] = L["Targeted"],
  [4] = L["Interrupt"],
  [5] = L["Role"],
  [6] = L["Phase"],
  [7] = L["Important"]
}

Private.bossmods_timerTypes = {
  PULL = L["Pull"],
  BREAK = L["Break"],
  TIMER = L["Timer"],
}

---@type table<string, string>
-- Weapon Enchant trigger: which enchant on the hand to read. "any" prefers
-- an imbue when both kinds are present, as the trigger always did. Shaman
-- weapon imbues are reported as the Imbue kind on Forever.
Private.weapon_enchant_kinds = {
  any = L["Any"],
  imbue = L["Imbue (Firestones, Mage Scrolls, Shaman Imbues)"],
  temporary = L["Oil, Stone or Poison"],
}

Private.weapon_enchant_types = {
  showOnActive = L["Enchant Found"],
  showOnMissing = L["Enchant Missing"],
  showAlways = L["Always"],
}

WeakAuras.EJIcons = {
  tank =      "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:7:25:7:25|t",
  dps =       "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:39:57:7:25|t",
  healer =    "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:71:89:7:25|t",
  mythic =    "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:103:121:7:25|t",
  deadly =    "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:135:153:7:25|t",
  important = "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:167:185:7:25|t",
  interrupt = "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:199:217:7:25|t",
  magic =     "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:231:249:7:25|t",
  curse =     "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:7:25:39:57|t",
  poison =    "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:39:57:39:57|t",
  disease =   "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:71:89:39:57|t",
  enrage =    "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:103:121:39:57|t",
  bleed =     "|TInterface\\EncounterJournal\\UI-EJ-Icons:::::256:64:158:192:32:64|t",
}

Private.reset_swing_spells = {}
Private.reset_ranged_swing_spells = {
  [2480] = true, -- Shoot Bow
  [7919] = true, -- Shoot Crossbow
  [7918] = true, -- Shoot Gun
  [2764] = true, -- Throw
  [5019] = true, -- Shoot Wands
  [75] = true, -- Auto Shot
  [5384] = true, -- Feign Death
  [467718] = true, -- Bleak Arrows
}

Private.noreset_swing_spells = {
  [23063] = true, -- Dense Dynamite
  [4054] = true, -- Rough Dynamite
  [4064] = true, -- Rough Copper Bomb
  [4061] = true, -- Coarse Dynamite
  [8331] = true, -- Ez-Thro Dynamite
  [4065] = true, -- Large Copper Bomb
  [4066] = true, -- Small Bronze Bomb
  [4062] = true, -- Heavy Dynamite
  [4067] = true, -- Big Bronze Bomb
  [4068] = true, -- Iron Grenade
  [23000] = true, -- Ez-Thro Dynamite II
  [12421] = true, -- Mithril Frag Bomb
  [4069] = true, -- Big Iron Bomb
  [12562] = true, -- The Big One
  [12543] = true, -- Hi-Explosive Bomb
  [19769] = true, -- Thorium Grenade
  [19784] = true, -- Dark Iron Bomb
  [30216] = true, -- Fel Iron Bomb
  [19821] = true, -- Arcane Bomb
  [39965] = true, -- Frost Grenade
  [30461] = true, -- The Bigger One
  [30217] = true, -- Adamantite Grenade
  [35476] = true, -- Drums of Battle
  [35475] = true, -- Drums of War
  [35477] = true, -- Drums of Speed
  [35478] = true, -- Drums of Restoration
  [34120] = true, -- Steady Shot (rank 1)
  [19434] = true, -- Aimed Shot (rank 1)
  [1464] = true, -- Slam (rank 1)
  [8820] = true, -- Slam (rank 2)
  [11604] = true, -- Slam (rank 3)
  [11605] = true, -- Slam (rank 4)
  [25241] = true, -- Slam (rank 5)
  [25242] = true, -- Slam (rank 6)
  --35474 Drums of Panic DO reset the swing timer, do not add
}

---@type table<number, string>
Private.item_weapon_types = {}

local skippedWeaponTypes = {}
skippedWeaponTypes[11] = true -- Bear Claws
skippedWeaponTypes[12] = true -- Cat Claws
skippedWeaponTypes[14] = true -- Misc
skippedWeaponTypes[17] = true -- Spears

for i = 0, 20 do
  if not skippedWeaponTypes[i] then
    Private.item_weapon_types[2 * 256 + i] = C_Item.GetItemSubClassInfo(2, i)
  end
end

-- Shields
Private.item_weapon_types[4 * 256 + 6] = C_Item.GetItemSubClassInfo(4, 6)
WeakAuras.item_weapon_types = Private.item_weapon_types

WeakAuras.StopMotion = WeakAuras.StopMotion or {}
WeakAuras.StopMotion.texture_types = WeakAuras.StopMotion.texture_types or {}
WeakAuras.StopMotion.texture_data = WeakAuras.StopMotion.texture_data or {}

WeakAuras.StopMotion.texture_types.Basic = {
  ["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\stopmotion"] = "Example",
}

WeakAuras.StopMotion.texture_data["Interface\\AddOns\\ForeverAuras\\Media\\Textures\\stopmotion"] = { count = 64, rows = 8, columns = 8 }

WeakAuras.StopMotion.animation_types = {
  loop = L["Loop"],
  bounce = L["Forward, Reverse Loop"],
  once = L["Forward"],
  progress = L["Progress"]
}
