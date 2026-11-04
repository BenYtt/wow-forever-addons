-- Modified for ForeverAuras, 2026-09-30.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, OptionsPrivate = ...

local function GetOptions(data, triggernum)
  local trigger = data.triggers[triggernum].trigger
  local display = OptionsPrivate.Private.BlizzardAuraDisplay
  local width = WeakAuras.normalWidth
  -- Which unit filters the selected unit supports (BlizzardAuraDisplay.lua).
  local function NotGroupUnit()
    return trigger.unit ~= "group" and trigger.unit ~= "party" and trigger.unit ~= "raid"
  end
  local function NoHostility()
    return not (display.hostilityUnits and display.hostilityUnits[trigger.unit])
  end
  local function NoClass()
    return NotGroupUnit() and not (display.classUnits and display.classUnits[trigger.unit])
  end
  local function NoSelf()
    return NotGroupUnit() and NoHostility()
  end
  local function Save(key, value)
    trigger[key] = value
    OptionsPrivate.SaveAuraTrigger(data, triggernum)
    OptionsPrivate.QueueOptionsRefresh(data.id)
  end
  -- Buff or Debuff. Blizzard's classification (processedAuraType) is not
  -- chosen here: the Blizzard debuff order sort sets it itself
  -- (AuraDisplayOptions.lua), and nothing else needs it.
  local auraTypes = {HELPFUL = L["Buff"], HARMFUL = L["Debuff"]}
  local options = {
    -- The trigger is active whenever its unit exists; Blizzard shows the auras
    -- inside (SecretAuraTrigger.lua). Kept short on request.
    alwaysActive = {type = "description", order = 1.95, width = "full", fontSize = "medium",
      name = L["|cffffffffNote: Trigger Always Active|r"]},
    -- Green/red status for this trigger's own selection (Display.TriggerStatus).
    help = {type = "description", order = 2, width = "full", fontSize = "small",
      name = function() return display.TriggerStatus(data, trigger) end},
    unitLabel = {
      type = "toggle", name = L["Unit"], order = 3, width = width,
      disabled = true, get = function() return true end,
    },
    unit = {
      type = "select", name = L["Unit"], order = 3.01, width = width,
      -- Every unit stays selectable; the status line says when a unit does
      -- not work with the rest of the selection.
      values = display.units,
      get = function() return trigger.unit end, set = function(_, value) Save("unit", value) end,
    },
    specificUnitSpace = {
      type = "description", name = "", order = 3.02, width = width,
      hidden = function() return trigger.unit ~= "member" end,
    },
    specificUnit = {
      type = "input", name = L["Specific Unit"], order = 3.03, width = width,
      desc = "party1-4, partypet1-4, raid1-40, raidpet1-40, boss1-8 or arena1-5.",
      hidden = function() return trigger.unit ~= "member" end,
      validate = function(_, value)
        if display.SpecificUnit({specificUnit = value}) then return true end
        return L["Enter a unit such as party1, raid5, boss1 or arena2."]
      end,
      get = function() return trigger.specificUnit or "" end,
      set = function(_, value) Save("specificUnit", value:lower():match("^%s*(%S+)%s*$")) end,
    },
    auraTypeLabel = {
      type = "toggle", name = L["Aura Type"], order = 4, width = width,
      disabled = true, get = function() return true end,
    },
    debuffType = {
      type = "select", name = L["Aura Type"], order = 4.01, width = width, values = auraTypes,
      sorting = {"HELPFUL", "HARMFUL"},
      get = function() return trigger.debuffType == "HARMFUL" and "HARMFUL" or "HELPFUL" end,
      set = function(_, value)
        if not auraTypes[value] then return end
        trigger.debuffType = value
        -- A classification that no longer fits the filter is dropped; the
        -- unit-frame debuff sort only applies to debuffs.
        if value == "HELPFUL" and (trigger.processedAuraType == "Debuff" or trigger.processedAuraType == "Dispel") then
          trigger.processedAuraType = "any"
          if trigger.sortMethod == "UnitFrameDebuff" then trigger.sortMethod = "Default" end
        end
        Save("debuffType", value)
      end,
    },
    -- Affected Unit Filters and Info, as on Aura (Legacy): each filter is
    -- offered only for the units it can apply to. Group filters (names,
    -- roles, class, pets, self, dead, offline, range) need a group unit; the
    -- hostility filter needs a unit that can be friend or foe.
    unitFiltersHeader = {
      type = "header", name = L["Affected Unit Filters and Info"], order = 8,
    },
    useUnitNames = {
      type = "toggle", name = L["Player Name(s)"], order = 8.1, width = "full",
      desc = L["Only track these group members. This also limits which units can play configured aura sounds."],
      hidden = NotGroupUnit,
      get = function() return trigger.useUnitNames or false end,
      set = function(_, value) Save("useUnitNames", value) end,
    },
    unitNames = {
      type = "input", name = L["Player Names"], order = 8.11, width = "full",
      desc = L["Enter character names separated by commas. Include both the first name and surname, keeping the space between them. Capitalization does not matter. Only group members whose names are available to addons can match."],
      hidden = function() return not trigger.useUnitNames or NotGroupUnit() end,
      get = function() return table.concat(trigger.unitNames or {}, ", ") end,
      set = function(_, value)
        local names = {}
        for name in value:gmatch("[^,]+") do
          name = strtrim(name)
          if name ~= "" then names[#names + 1] = name end
        end
        Save("unitNames", names)
      end,
    },
    useUnitRoles = {
      type = "toggle", name = L["Group Role"], order = 8.2, width = "full",
      desc = L["Only track members with the selected assigned group roles. This also limits configured aura sounds. Player-name and role filters must both match when enabled."],
      hidden = NotGroupUnit,
      get = function() return trigger.useUnitRoles or false end,
      set = function(_, value) Save("useUnitRoles", value) end,
    },
    unitRoles = {
      type = "multiselect", name = L["Group Roles"], order = 8.21, width = "full",
      values = {TANK = L["Tank"], HEALER = L["Healer"], DAMAGER = L["Damage"], NONE = L["Unassigned"]},
      desc = L["Uses Blizzard's assigned group role. Members without a role assigned match Unassigned."],
      hidden = function() return not trigger.useUnitRoles or NotGroupUnit() end,
      get = function(_, role) return (trigger.unitRoles or {})[role] or false end,
      set = function(_, role, value)
        trigger.unitRoles = trigger.unitRoles or {}
        trigger.unitRoles[role] = value or nil
        Save("unitRoles", trigger.unitRoles)
      end,
    },
    useUnitClass = {
      type = "toggle", name = L["Class"], order = 8.3, width = "full",
      desc = L["Only track units of the selected classes. Units left out get no part of the display."],
      hidden = NoClass,
      get = function() return trigger.useUnitClass or false end,
      set = function(_, value) Save("useUnitClass", value or nil) end,
    },
    unitClass = {
      type = "multiselect", name = L["Classes"], order = 8.31, width = "full",
      values = WeakAuras.class_types,
      hidden = function() return not trigger.useUnitClass or NoClass() end,
      get = function(_, class) return (trigger.unitClass or {})[class] or false end,
      set = function(_, class, value)
        trigger.unitClass = trigger.unitClass or {}
        trigger.unitClass[class] = value or nil
        Save("unitClass", trigger.unitClass)
      end,
    },
    useIncludePets = {
      type = "toggle", name = L["Include Pets"], order = 8.4, width = width,
      hidden = NotGroupUnit,
      get = function() return trigger.useIncludePets or false end,
      set = function(_, value) Save("useIncludePets", value) end,
    },
    includePets = {
      type = "select", name = L["Include Pets"], order = 8.41, width = width,
      values = OptionsPrivate.Private.include_pets_types,
      hidden = NotGroupUnit,
      disabled = function() return not trigger.useIncludePets end,
      get = function() return trigger.includePets or "PlayersAndPets" end,
      set = function(_, value) Save("includePets", value) end,
    },
    ignoreSelf = {
      type = "toggle", name = L["Ignore Self"], order = 8.5, width = "full",
      desc = L["Leave yourself (and your pet) out of the display."],
      hidden = NoSelf,
      get = function() return trigger.ignoreSelf or false end,
      set = function(_, value) Save("ignoreSelf", value or nil) end,
    },
    ignoreDead = {
      type = "toggle", name = L["Ignore Dead"], order = 8.6, width = "full",
      desc = L["Hide this unit's part of the display while it is dead or a ghost."],
      get = function() return trigger.ignoreDead or false end,
      set = function(_, value) Save("ignoreDead", value or nil) end,
    },
    ignoreDisconnected = {
      type = "toggle", name = L["Ignore Disconnected"], order = 8.7, width = "full",
      desc = L["Hide this unit's part of the display while it is offline."],
      get = function() return trigger.ignoreDisconnected or false end,
      set = function(_, value) Save("ignoreDisconnected", value or nil) end,
    },
    ignoreInvisible = {
      type = "toggle", name = L["Ignore out of checking range"], order = 8.8, width = "full",
      desc = L["Hide a member's part of the display while it is too far away for the client to see."],
      hidden = NotGroupUnit,
      get = function() return trigger.ignoreInvisible or false end,
      set = function(_, value) Save("ignoreInvisible", value or nil) end,
    },
    -- As Aura (Legacy)'s Filter by Hostility (BuffTrigger2.lua), same fields:
    -- nameplates, targets, focus, mouseover and specific units can be either
    -- side (Display.HostilityMatches); a group is always friendly.
    useHostility = {
      type = "toggle", name = L["Filter by Hostility"], order = 8.9, width = "full",
      hidden = NoHostility,
      get = function() return trigger.useHostility or false end,
      set = function(_, value) Save("useHostility", value or nil) end,
    },
    hostility = {
      type = "select", name = L["Hostility"], order = 8.91, width = width, values = OptionsPrivate.Private.hostility_types,
      hidden = function() return NoHostility() or not trigger.useHostility end,
      get = function() return trigger.hostility or "hostile" end,
      set = function(_, value) Save("hostility", value) end,
    },
    filtersHeader = {type = "header", name = L["Aura Filters"], order = 10},
    -- Maximum Duration is now Total Duration "<=" (AuraTriggerOptions.lua).
    includeNameplateOnly = {
      type = "toggle", name = L["Include nameplate-only auras"], order = 21, width = "full",
      desc = L["Also allows auras normally returned only for nameplate displays. Other filters still apply."],
      get = function() return trigger.includeNameplateOnly or false end, set = function(_, value) Save("includeNameplateOnly", value) end,
      hidden = function() return trigger.unit ~= "nameplate" end,
    },

  }
  options.spellSelectionHeader = {type = "header", name = L["Spell Selection Filters"], order = 4.5}
  local function SpellIDs(toggleKey, prefix, storageKey, title, inputName, order, Enabled, flag)
    options[toggleKey] = {
      type = "toggle", name = title, order = order, width = width - 0.2,
      get = function() return Enabled(trigger) end,
      set = function(_, value) Save(flag, value) end,
    }
    options[prefix .. "DisabledSpace"] = {
      type = "description", name = "", order = order + 0.001, width = width + 0.2,
      hidden = function() return Enabled(trigger) end,
    }
    local size = #(trigger[storageKey] or {}) + 1
    OptionsPrivate.CreateAuraSpellOptions(options, data, triggernum, size,
      true, false, prefix, order, flag, storageKey, inputName,
      nil,
      false, function() return Enabled(trigger) end)
    -- Unlike Legacy, these values are also sent to Blizzard's native filters.
    for i = 1, size do
      options[prefix .. i].validate = function(_, value)
        if value == "" then return true end
        local id = tonumber(value)
        if not id or id <= 0 or id >= 2147483647 or id ~= math.floor(id) then
          return L["Enter a positive whole-number Spell ID."]
        end
        return true
      end
    end
  end
  -- Rank matching has independent storage, so old exact selections keep their meaning.
  SpellIDs("useRankSpellIDs", "rankspellid", "auraRankSpellIDs", L["Spell ID(s) (All Ranks)"], L["Spell ID"], 4.95,
    display.UsesRankSpellIDs, "secretUseRankSpellIDs")
  options.useRankSpellIDs.desc = L["Enter a Spell ID to track all ranks of that spell."]
  -- Explain incomplete coverage without changing existing saved selections.
  local function UnsupportedRankIDs()
    local missing = {}
    for _, value in ipairs(trigger.auraRankSpellIDs or {}) do
      local id = tonumber(value)
      if id and not OptionsPrivate.Private.AuraSpellRankSupported(id) then
        missing[#missing + 1] = tostring(value)
      end
    end
    return missing
  end
  options.rankCoverage = {
    type = "description", order = 5.9, width = "full", fontSize = "small",
    hidden = function() return not display.UsesRankSpellIDs(trigger) or #UnsupportedRankIDs() == 0 end,
    name = function()
      return L["Other ranks could not be found for: %s"]:format(table.concat(UnsupportedRankIDs(), ", "))
        .. ". " .. L["The IDs you entered are tracked, and spells with the same name. To track another rank, add its ID under Exact Spell ID(s)."]
    end,
  }
  SpellIDs("useSpellIDs", "spellid", "auraspellids", L["Exact Spell ID(s)"], L["Exact Spell ID"], 6,
    display.UsesSpellIDs, "secretUseSpellIDs")
  -- Same-name matching always applies (Display.GetSpellIDs): said here, so
  -- "Exact" is not read as "these IDs only".
  options.useSpellIDs.desc = L["Track auras with these spell IDs, and any spell with the same name (other ranks and server variants), as Aura (Legacy) matches by name."]
  -- Spell Lists (Display.SpellList) are set by importing a pack, not here: a
  -- trigger with secretSpellList shows a one-line note so the empty ID fields
  -- make sense, and keeps working as data.
  options.spellListNote = {
    type = "description", order = 6.9, width = WeakAuras.doubleWidth, fontSize = "small",
    hidden = function() return not display.UsesSpellList(trigger) end,
    name = function() return L["Spell IDs come from the Spell List |cffffd100%s|r, set by this pack's backend aura."]:format(tostring(trigger.secretSpellList)) end,
  }
  SpellIDs("useExcludedSpellIDs", "ignorespellid", "excludedAuraSpellIDs", L["Ignored Exact Spell ID(s)"], L["Ignored Spell ID"], 7,
    display.UsesExcludedSpellIDs, "secretUseExcludedSpellIDs")
  local function TriState(key, title, order, description, GetValue, SetValue)
    options[key] = {
      type = "toggle", width = "full", order = order,
      name = function()
        local value = GetValue()
        if value == nil then return title end
        return value and "|cFF00FF00" .. title .. "|r" or "|cFFFF0000Not " .. title .. "|r"
      end,
      desc = description,
      get = function()
        local value = GetValue()
        if value == nil then return false end
        return value and "true" or "false"
      end,
      set = function(_, checked)
        if checked then SetValue(true)
        elseif GetValue() == false then SetValue(nil)
        else SetValue(false) end
      end,
    }
  end
  for index, field in ipairs(display.booleanFilters) do
    local key = field[1]
    local title = field[2]
    TriState(key, title, 10 + index,
      field[3],
      function() return trigger[key] end, function(value) Save(key, value) end)
    if key == "nameplateShowAll" or key == "nameplateShowPersonal" then
      options[key].hidden = function() return trigger.unit ~= "nameplate" end
      options[key].desc = (key == "nameplateShowAll"
        and L["Only match auras Blizzard marks for display on all nameplates."]
        or L["Only match auras marked for Blizzard's personal-debuff display on nameplates. This does not refer to your personal resource bar."])
        .. " This checks Blizzard's nameplate flag. It does not change where the icon appears or who cast the aura."
    end
  end
  for index, key in ipairs({"includeDispelTypes", "excludeDispelTypes"}) do
    options[key] = {
      type = "multiselect", name = index == 1 and L["Include dispel types"] or L["Exclude dispel types"], order = 23 + index, width = "full",
      values = display.dispelTypes,
      get = function(_, name) return trigger[key] and trigger[key][name] or false end,
      set = function(_, name, value)
        local values = {}
        for k, v in pairs(trigger[key] or {}) do values[k] = v end
        values[name] = value and true or nil
        Save(key, next(values) and values or nil)
      end,
    }
  end
  for index, field in ipairs(display.nativeFilters) do
    local key = field[1]
    TriState("native" .. key, field[2], 20 + index / 20, field[3],
      function() return (trigger.nativeFilters or {})[key] end,
      function(value)
        local filters = {}
        for k, v in pairs(trigger.nativeFilters or {}) do filters[k] = v end
        filters[key] = value
        Save("nativeFilters", next(filters) and filters or nil)
      end)
  end
  options.isFromPlayerOrPlayerPet.width = width
  options.nativePLAYER.width = width
  options.nativePLAYER.order = options.isFromPlayerOrPlayerPet.order
  options.isFromPlayerOrPlayerPet.order = options.nativePLAYER.order + 0.01
  for _, fields in ipairs({display.nativeFilters, display.booleanFilters}) do
    for _, field in ipairs(fields) do
      local key = field[1]
      local option = options[fields == display.nativeFilters and "native" .. key or key]
      if option then
        local hidden = option.hidden
        option.hidden = function()
          return not display.FilterApplies(key, trigger) or (type(hidden) == "function" and hidden()) or hidden == true
        end
      end
    end
  end
  OptionsPrivate.commonOptions.AddCommonTriggerOptions(options, data, triggernum, true)
  OptionsPrivate.AuraEditor.AddOptions(options, data, triggernum)
  OptionsPrivate.AddTriggerMetaFunctions(options, data, triggernum)
  return {["trigger." .. triggernum .. ".secretAura"] = options}
end

WeakAuras.RegisterTriggerSystemOptions({"secretAura"}, GetOptions)
