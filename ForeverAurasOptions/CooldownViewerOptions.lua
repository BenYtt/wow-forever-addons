-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, OptionsPrivate = ...
local views = setmetatable({}, {__mode = "k"})
function OptionsPrivate.AddCooldownViewerOptions(options, data, triggernum)
  local Private = OptionsPrivate.Private
  local trigger = data.triggers[triggernum].trigger
  Private.MigrateCDMCooldownTrigger(trigger)
  if trigger.type == "cdm" then trigger.cdmSource = trigger.event == "Blizzard CDM Buff" and "buff" or "cooldown" end
  views[data] = views[data] or {}
  views[data][triggernum] = views[data][triggernum] or {}
  local view = views[data][triggernum]
  for key in pairs(options) do
    if key:find("cdmSpells", 1, true) or key:find("cdmShowGCD", 1, true) then options[key] = nil end
  end
  local function Refresh() WeakAuras.ClearAndUpdateOptions(data.id) end
  local function Save(key, value)
    trigger[key] = value
    WeakAuras.Add(data)
    Private.ScanForLoads({[data.id] = true})
    WeakAuras.UpdateThumbnail(data)
    Private.UpdateFakeStatesFor(data.id)
    Refresh()
  end
  local order = 10.01
  local function Add(key, option)
    option.order = order
    order = order + 0.001
    options["cdmPicker_" .. key] = option
  end
  trigger.cdmSpells = trigger.cdmSpells or {multi = {}}
  trigger.cdmSpells.multi = trigger.cdmSpells.multi or {}
  local selected = trigger.cdmSpells.multi
  if trigger.cdmSpell ~= nil then
    if trigger.cdmSelection ~= "spell" and trigger.event == "Blizzard Cooldown Manager" then
      local resolved = Private.ResolveCDMSpell(trigger, "OPTIONS")
      local entries = Private.CDMCatalog()
      local entry = #resolved == 1 and entries[resolved[1]]
      local info = entry and C_CooldownViewer.GetCooldownViewerCooldownInfo(resolved[1])
      if info then
        if info.equipSlot or info.spellCategoryID then trigger.event = "Blizzard CDM Item" end
      end
    end
    if tostring(trigger.cdmSpell):find("%S") then
      if trigger.cdmExact then
        trigger.cdmExactIDs = trigger.cdmExactIDs or {tostring(trigger.cdmSpell)}
        trigger.cdmUseExactIDs = true
      else
        trigger.cdmNames = trigger.cdmNames or {tostring(trigger.cdmSpell)}
        trigger.cdmUseNames = true
      end
    end
    trigger.cdmSpell, trigger.cdmExact = nil, nil
    C_Timer.After(0, function() WeakAuras.Add(data); Private.UpdateFakeStatesFor(data.id) end)
  end
  Add("typeSpacer", {type = "description", name = " ", width = "full"})
  -- ForeverAuras: a Buff/Debuff trigger cannot read its aura in combat; the
  -- trigger stays active then and Blizzard shows or hides the display, as
  -- for an Aura (Modern) trigger, and that is said here the same way.
  if trigger.cdmSource == "buff" then
    Add("alwaysActive", {type = "description", fontSize = "medium", width = "full",
      name = L["|cffffffffNote: Trigger Always Active while the aura is secret|r: the addon cannot read the aura then, so the trigger stays active and Blizzard's own aura display shows or hides the display. Lua conditions on this trigger's aura do not update until the aura is readable again."]})
  end
  Add("help", {type = "description", name = L["Spells must be active in the CDM to be displayed. Type /cdm and add them."], width = "full"})
  -- Blizzard's Cooldown Manager flags some entries as not known although the
  -- spell is (its Bane of Agony entry, 199777): it builds no viewer item for
  -- them, so their aura is secret in combat and the trigger falls back to the
  -- native slot (Aura(s) Missing cannot be told with a target then). Named
  -- here so the limitation is not mistaken for a ForeverAuras fault.
  local function UnrecognisedEntries()
    if trigger.cdmSource ~= "buff" or not C_CooldownViewer or not OptionsPrivate.Private.CDMCatalog then return end
    local wanted = {}
    for _, list in ipairs({trigger.cdmUseNames and trigger.cdmNames or {}, trigger.cdmUseExactIDs and trigger.cdmExactIDs or {}}) do
      for _, value in ipairs(type(list) == "table" and list or {}) do
        local id = tonumber(value)
        if id then wanted[id] = true
        elseif type(value) == "string" and value:find("%S") then wanted[value:lower()] = true end
      end
    end
    if trigger.cdmSelection == "spell" and trigger.cdmSpell then
      local id = tonumber(trigger.cdmSpell)
      if id then wanted[id] = true else wanted[tostring(trigger.cdmSpell):lower()] = true end
    end
    if not next(wanted) then return end
    local names = {}
    for entryID, entry in pairs(OptionsPrivate.Private.CDMCatalog()) do
      if entry.known == false then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(entryID)
        local ids = {}
        if info then
          if type(info.spellID) == "number" then ids[#ids + 1] = info.spellID end
          if type(info.overrideSpellID) == "number" then ids[#ids + 1] = info.overrideSpellID end
          for _, id in ipairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or {}) do if type(id) == "number" then ids[#ids + 1] = id end end
        end
        local hit
        for _, id in ipairs(ids) do
          if wanted[id] or wanted[entryID] then hit = id; break end
          local spell = C_Spell.GetSpellInfo(id)
          if spell and spell.name and wanted[spell.name:lower()] then hit = id; break end
        end
        if hit then
          local spell = C_Spell.GetSpellInfo(hit)
          names[#names + 1] = (spell and spell.name or tostring(hit)) .. " (" .. tostring(entryID) .. ")"
        end
      end
    end
    if #names == 0 then return end
    table.sort(names)
    return table.concat(names, ", ")
  end
  Add("unrecognised", {type = "description", width = "full", fontSize = "medium",
    hidden = function() return UnrecognisedEntries() == nil end,
    name = function()
      local names = UnrecognisedEntries()
      return names and ("|cffff8000" .. L["Blizzard's Cooldown Manager does not recognise this spell, so its aura cannot be read in combat: %s. Aura(s) Missing cannot be told with a target in combat."]:format(names) .. "|r") or ""
    end})
  Add("open", {type = "execute", name = L["Open CDM"], width = WeakAuras.normalWidth,
    disabled = function() return InCombatLockdown() or not C_CooldownViewer end,
    func = function()
      if not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then C_AddOns.LoadAddOn("Blizzard_CooldownViewer") end
      if CooldownViewerSettings then ShowUIPanel(CooldownViewerSettings) end
    end})
  Add("refresh", {type = "execute", name = L["Refresh from Blizzard CDM"], width = WeakAuras.normalWidth, func = Refresh})
  local buff = trigger.cdmSource == "buff"
  do
    order = 20
    Add("spellSelection", {type = "header", name = L["Spell Selection Filters"]})
    local function Selector(title, label, prefix, flag, storage, exact, baseOrder, itemID)
      options[prefix .. "Toggle"] = {
        type = "toggle", name = title, width = WeakAuras.normalWidth - 0.2, order = baseOrder,
        get = function() return trigger[flag] or false end,
        set = function(_, value) Save(flag, value) end,
      }
      options[prefix .. "DisabledSpace"] = {
        type = "description", name = "", width = WeakAuras.normalWidth + 0.2, order = baseOrder + 0.001,
        hidden = function() return trigger[flag] == true end,
      }
      local size = #(trigger[storage] or {}) + 1
      OptionsPrivate.CreateAuraSpellOptions(options, data, triggernum, size, exact, false,
        prefix, baseOrder, flag, storage, label, nil, false, function() return trigger[flag] == true end,
        function() Save(storage, trigger[storage]) end)
      for i = 1, size do
        local input = options[prefix .. i]
        if itemID then
          local function ItemName()
            local id = tonumber(trigger[storage] and trigger[storage][i])
            Private.CDMRequestItemData(id)
            return id and C_Item and C_Item.GetItemNameByID(id)
          end
          local icon = options[prefix .. "icon" .. i]
          icon.name = function() return ItemName() or "" end
          icon.image = function()
            local id = tonumber(trigger[storage] and trigger[storage][i])
            local texture = id and C_Item and C_Item.GetItemIconByID(id)
            return texture and tostring(texture) or "", 18, 18
          end
          icon.disabled = function() return not ItemName() end
          input.get = function()
            local raw = trigger[storage] and trigger[storage][i]
            if not raw then return "" end
            return ("%s (%s)"):format(raw, ItemName() or "Unknown Item") .. "\0" .. raw
          end
        end
        if exact then
          input.validate = function(_, value)
            if value == "" then return true end
            local id = tonumber(value)
            return (id and id > 0 and id < 2147483647 and id == math.floor(id)) or (itemID and L["Enter a positive whole-number Item ID."] or L["Enter a positive whole-number Spell ID."])
          end
        end
      end
    end
    Selector(L["Name(s)"], trigger.cdmSource == "buff" and L["Aura Name"] or L["Spell Name"], "cdmPicker_name", "cdmUseNames", "cdmNames", false, 21)
    Selector(L["Exact Spell ID(s)"], L["Spell ID"], "cdmPicker_spellid", "cdmUseExactIDs", "cdmExactIDs", true, 25)
    if trigger.event == "Blizzard CDM Item" then
      Selector(L["Exact Item ID(s)"], L["Item ID"], "cdmPicker_itemid", "cdmUseItemIDs", "cdmItemIDs", true, 29, true)
    end
    order = 30
  end
  -- A Cooldown trigger is laid out like the spell Cooldown/Charges/Count
  -- trigger: Extra Options (Track Cooldowns, Show Global Cooldown, Show
  -- Global Cooldown Text, Disable Spell Known Check), the Remaining Time and
  -- Charges filters, then Show (On Cooldown / Not on Cooldown / Always).
  -- Usable and Not Usable, the two Show choices this trigger used to have, are
  -- the Spell Usable / Insufficient Resources conditions now; a saved choice
  -- keeps working and shows as a fourth entry until changed.
  if not buff and trigger.event ~= "Blizzard CDM Item" then
    local cooldownOnly = function() return buff or trigger.event == "Blizzard CDM Item" end
    local function ExtraHidden() return cooldownOnly() or not view.extra end
    Add("extra", {
      type = "execute", control = "WeakAurasExpandSmall", width = "full", hidden = cooldownOnly,
      name = function()
        local settings = {}
        if trigger.cdmTrack == "cooldown" then settings[#settings + 1] = L["Cooldown"] elseif trigger.cdmTrack == "charges" then settings[#settings + 1] = L["Charge recharge"] end
        if trigger.use_cdmShowGCD then settings[#settings + 1] = L["Show GCD"] end
        if trigger.use_cdmShowGCD and trigger.cdmHideGCDText == false then settings[#settings + 1] = L["Show GCD text"] end
        if trigger.use_ignoreSpellKnown then settings[#settings + 1] = L["Disable Spell Known Check"] end
        return "|cFFffcc00" .. L["Extra Options:"] .. "|r " .. (#settings > 0 and table.concat(settings, "; ") or L["None"])
      end,
      image = function() return view.extra and "expanded" or "collapsed" end, imageWidth = 15, imageHeight = 15,
      func = function() view.extra = not view.extra; Refresh() end,
    })
    -- Laid out as on the spell trigger: the select, with its label, on the right.
    Add("trackSpacer", {type = "description", name = "", width = WeakAuras.normalWidth, hidden = ExtraHidden})
    Add("track", {type = "select", name = L["Track Cooldowns"], width = WeakAuras.normalWidth, hidden = ExtraHidden,
      values = {auto = L["Auto"], cooldown = L["Cooldown"], charges = L["Charge recharge"]},
      get = function() return trigger.cdmTrack or "auto" end, set = function(_, value) Save("cdmTrack", value) end})
    Add("includeGCD", {type = "toggle", name = L["Show Global Cooldown"], width = "full", hidden = ExtraHidden,
      get = function() return trigger.use_cdmShowGCD or false end, set = function(_, value) Save("use_cdmShowGCD", value) end})
    -- "Show Global Cooldown Text" is the saved cdmHideGCDText inverted (that
    -- flag defaults to hiding the text), so existing triggers keep their look.
    Add("showGCDText", {type = "toggle", name = L["Show Global Cooldown Text"], width = "full", hidden = ExtraHidden,
      disabled = function() return not trigger.use_cdmShowGCD end,
      get = function() return trigger.cdmHideGCDText == false end, set = function(_, value) Save("cdmHideGCDText", not value) end})
    Add("ignoreSpellKnown", {type = "toggle", name = L["Disable Spell Known Check"], width = "full", hidden = ExtraHidden,
      get = function() return trigger.use_ignoreSpellKnown or false end, set = function(_, value) Save("use_ignoreSpellKnown", value) end})
    -- Filters, one per line as on the spell trigger.
    local function Filter(key, title, flag, opKey, opDefault, valueKey, valueDefault, valueName, operators, whole, gone)
      -- `gone`: the filter is out of sight (and out of use, triggerFunction)
      -- while it does not apply; it returns with its settings when it does.
      local function Hidden() return cooldownOnly() or (gone and gone()) end
      Add(key .. "Enabled", {type = "toggle", name = title, width = WeakAuras.normalWidth, hidden = Hidden,
        get = function() return trigger[flag] or false end, set = function(_, value) Save(flag, value) end})
      Add(key .. "Spacer", {type = "description", name = "", width = WeakAuras.normalWidth, hidden = function() return Hidden() or trigger[flag] == true end})
      Add(key .. "Operator", {type = "select", name = "", width = 0.5, values = operators, hidden = function() return Hidden() or not trigger[flag] end,
        get = function() return trigger[opKey] or opDefault end, set = function(_, value) Save(opKey, value) end})
      Add(key .. "Value", {type = "input", name = valueName, width = WeakAuras.normalWidth - 0.5, hidden = function() return Hidden() or not trigger[flag] end,
        get = function() return tostring(trigger[valueKey] or valueDefault) end,
        validate = function(_, value)
          local number = tonumber(value)
          if whole then return (number and number >= 0 and number < math.huge and number == math.floor(number)) or L["Enter a non-negative whole number."] end
          return (number and number >= 0 and number < math.huge) or L["Enter a non-negative number of seconds."]
        end,
        set = function(_, value) Save(valueKey, tonumber(value)) end})
    end
    -- Remaining Time measures a running cooldown (a ready spell counts as 0
    -- seconds): gone with Show: Not on Cooldown, as on the spell trigger.
    local countOperators = {['<'] = '<', ['<='] = '<=', ['>'] = '>', ['>='] = '>=', ['=='] = '=', ['~='] = '!='}
    Filter("cdRemaining", L["Remaining Time"], "cdmUseRemaining", "cdmRemainingOperator", "<", "cdmRemainingTime", 10, L["Seconds"], {['<'] = '<', ['<='] = '<=', ['>'] = '>', ['>='] = '>='}, false,
      function() return trigger.cdmShow == "ready" end)
    Filter("cdCharges", L["Charges"], "cdmUseCharges", "cdmChargeOperator", ">=", "cdmChargeCount", 1, L["Charges"], countOperators, true)
    Filter("cdSpellCount", L["Spell Count"], "cdmUseSpellCount", "cdmSpellCountOperator", ">=", "cdmSpellCount", 1, L["Spell Count"], countOperators, true)
    -- The spell trigger's "Show" row: its always-on check on the left, the
    -- choice with its label on the right.
    Add("showCheck", {type = "toggle", name = L["Show"], width = WeakAuras.normalWidth, hidden = cooldownOnly, disabled = function() return true end, get = function() return true end, set = function() end})
    Add("show", {type = "select", name = L["Show"], width = WeakAuras.normalWidth, hidden = cooldownOnly,
      values = function()
        local values = {cooldown = L["On Cooldown"], ready = L["Not on Cooldown"], always = L["Always"]}
        local saved = trigger.cdmShow
        if saved == "usable" then values.usable = L["Usable (legacy)"] elseif saved == "unusable" then values.unusable = L["Not Usable (legacy)"] end
        return values
      end,
      sorting = function()
        local list = {"cooldown", "ready", "always"}
        if trigger.cdmShow == "usable" or trigger.cdmShow == "unusable" then list[#list + 1] = trigger.cdmShow end
        return list
      end,
      get = function() return trigger.cdmShow or "always" end, set = function(_, value) Save("cdmShow", value) end})
  end
  if buff then
    -- Aura Filters: readable timers and stacks only (unknown in combat).
    Add("auraFilters", {type = "header", name = L["Aura Filters"]})
    local function Filter(key, title, flag, opKey, opDefault, valueKey, valueDefault, valueName, operators, whole)
      Add(key .. "Enabled", {type = "toggle", name = title, width = WeakAuras.normalWidth,
        get = function() return trigger[flag] or false end,
        set = function(_, value) Save(flag, value) end})
      -- One filter per line, as on an Aura (Modern) trigger: a spacer fills the
      -- rest of the row while the filter is off.
      Add(key .. "Spacer", {type = "description", name = "", width = WeakAuras.normalWidth,
        hidden = function() return trigger[flag] == true end})
      Add(key .. "Operator", {type = "select", name = "", width = 0.5, values = operators,
        hidden = function() return not trigger[flag] end,
        get = function() return trigger[opKey] or opDefault end,
        set = function(_, value) Save(opKey, value) end})
      Add(key .. "Value", {type = "input", name = valueName, width = WeakAuras.normalWidth - 0.5,
        hidden = function() return not trigger[flag] end,
        get = function() return tostring(trigger[valueKey] or valueDefault) end,
        validate = function(_, value)
          local number = tonumber(value)
          if whole then return (number and number >= 0 and number < math.huge and number == math.floor(number)) or L["Enter a non-negative whole number."] end
          return (number and number >= 0 and number < math.huge) or L["Enter a non-negative number of seconds."]
        end,
        set = function(_, value) Save(valueKey, tonumber(value)) end})
    end
    local timeOperators = {['<'] = '<', ['<='] = '<=', ['>'] = '>', ['>='] = '>='}
    Filter("remaining", L["Remaining Time"], "cdmUseRemaining", "cdmRemainingOperator", "<", "cdmRemainingTime", 10, L["Seconds"], timeOperators)
    Filter("elapsed", L["Elapsed Time"], "cdmUseElapsed", "cdmElapsedOperator", ">=", "cdmElapsedTime", 10, L["Seconds"], timeOperators)
    Filter("stacks", L["Stack Count"], "cdmUseStacks", "cdmStackOperator", ">=", "cdmStackCount", 1, L["Stacks"],
      {['<'] = '<', ['<='] = '<=', ['>'] = '>', ['>='] = '>=', ['=='] = '=', ['~='] = '!='}, true)
    -- Show and Clone Settings, as on an Aura (Modern) trigger. "Show If Unit
    -- Does Not Exist" is the saved cdmRequireTarget inverted, so existing
    -- triggers keep their behaviour: unticked, the trigger only shows while
    -- there is a target you can attack.
    Add("showHeader", {type = "header", name = L["Show and Clone Settings"]})
    Add("buffShow", {type = "select", name = L["Show On"], width = WeakAuras.normalWidth,
      values = {active = L["Aura(s) Found"], missing = L["Aura(s) Missing"], always = L["Always"]},
      sorting = {"active", "missing", "always"},
      get = function() return trigger.cdmBuffShow or "active" end, set = function(_, value) Save("cdmBuffShow", value) end})
    -- As on an Aura trigger, the option applies to Missing and Always: with
    -- Aura(s) Found no target means no aura, and the display hides.
    Add("unitExists", {type = "toggle", name = L["Show If Unit Does Not Exist"], width = WeakAuras.normalWidth,
      desc = L["Unticked, the trigger only shows while you have a target you can attack."],
      hidden = function() return (trigger.cdmBuffShow or "active") == "active" end,
      get = function() return not trigger.cdmRequireTarget end,
      set = function(_, value) Save("cdmRequireTarget", not value) end})
    -- Auto-Clone: one clone per listed aura (the default, as before the
    -- option), or one display chosen by Preferred Match, as on a legacy Aura.
    Add("autoClone", {type = "toggle", name = L["Auto-Clone (Show All Matches)"], width = WeakAuras.normalWidth,
      desc = L["One display per listed aura; unticked, one display for whichever matches."],
      get = function() return trigger.cdmAutoClone ~= false end,
      set = function(_, value) Save("cdmAutoClone", value) end})
    Add("combineMode", {type = "select", name = L["Preferred Match"], width = WeakAuras.normalWidth,
      desc = L["Which listed aura the display follows while several are up. Remaining times that are secret cannot be compared: an aura with a readable time is preferred, and when aura information is hidden, Blizzard selects the aura shown."],
      values = {showLowest = L["Least remaining time"], showHighest = L["Most remaining time"], showFirst = L["First in the list"]},
      sorting = {"showLowest", "showHighest", "showFirst"},
      hidden = function() return trigger.cdmAutoClone ~= false end,
      get = function()
        local mode = trigger.cdmCombineMode or "showLowest"
        if mode ~= "showLowest" and mode ~= "showHighest" then mode = "showFirst" end
        return mode
      end,
      set = function(_, value) Save("cdmCombineMode", value) end})
  end
  order = 35
  Add("filters", {type = "header", name = L["Blizzard CDM Filters"]})
  Add("search", {type = "input", name = L["Search"], width = "full", get = function() return view.search or "" end,
    set = function(_, value) view.search = value; Refresh() end})
  Add("available", {type = "toggle", name = L["Show only available"], width = WeakAuras.normalWidth,
    get = function() return view.availableOnly or false end, set = function(_, value) view.availableOnly = value; Refresh() end})
  Add("maxRank", {type = "toggle", name = L["Show only max rank"], width = WeakAuras.normalWidth,
    get = function() return view.maxRank or false end, set = function(_, value) view.maxRank = value; Refresh() end})
  Add("entries", {type = "header", name = L["Blizzard CDM Entries"]})
  local catalog = C_CooldownViewer and Private.CDMCatalog() or {}
  local rows, highest = {}, {}
  local function Checked(id) return selected[id] or selected[tostring(id)] or false end
  for id, entry in pairs(catalog) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if info and Private.CDMEntryMatches(trigger, entry, info) then
      local identity = Private.CDMIdentity(id, entry, info)
      local spellID = info.spellID or identity.spellID
      local spell = spellID and C_Spell.GetSpellInfo(spellID)
      local item = trigger.event == "Blizzard CDM Item"
      local name = not item and spell and spell.name or identity.name
      local rankText = not item and spellID and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
      local rank = rankText and tonumber(rankText:match("%d+")) or 0
      local label = name .. (rankText and rankText ~= "" and (" (" .. rankText .. ")") or "")
      local shownID = item and identity.itemID or spellID
      if shownID then label = label .. " [" .. shownID .. "]" end
      rows[#rows + 1] = {id = id, name = name, label = label, rank = rank, known = entry.known, icon = not item and spell and spell.iconID or identity.icon, category = Private.CDMCategoryName(entry.category)}
      highest[name] = math.max(highest[name] or 0, rank)
    end
  end
  table.sort(rows, function(a,b) if a.name ~= b.name then return a.name < b.name end; if a.rank ~= b.rank then return a.rank > b.rank end; return a.id < b.id end)
  local query = (view.search or ""):lower()
  for _, row in ipairs(rows) do
    if (not view.availableOnly or row.known) and row.label:lower():find(query, 1, true)
      and (not view.maxRank or row.rank == highest[row.name]) then
      Add("entry" .. row.id, {type = "toggle", name = row.label, desc = row.category, width = "full", image = row.icon, imageWidth = 18, imageHeight = 18,
        get = function() return Checked(row.id) end,
        set = function(_, value)
          selected[row.id] = nil; selected[tostring(row.id)] = value or nil
          Save("cdmSpells", trigger.cdmSpells)
        end})
    end
  end

end
