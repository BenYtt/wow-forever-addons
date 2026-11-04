-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, Private = ...

-- Timers from this file are timed by the profiler (see Private.TimedAPI).
local _, _, _, C_Timer = Private.TimedAPI("CooldownViewerTrigger")
-- Reuse the Essential event identifier for both cooldown viewers.
function Private.MigrateCDMCooldownTrigger(trigger)
  if trigger and trigger.type == "cdm" and trigger.event == "Blizzard CDM Utility" then
    trigger.event = "Blizzard Cooldown Manager"
    trigger.cdmSource = "cooldown"
  end
  -- The Total Duration filter was removed from the Buff/Debuff trigger (your
  -- own auras' durations only vary by rank, which Remaining Time already
  -- handles): a saved one is switched off so it no longer hides anything.
  if trigger and trigger.type == "cdm" and trigger.cdmUseTotal then trigger.cdmUseTotal = nil end
end

local catalog
local refreshEvents = {
  PLAYER_ENTERING_WORLD = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  SPELLS_CHANGED = true,
  PLAYER_EQUIPMENT_CHANGED = true,
  FA_CDM_LAYOUT_CHANGED = true,
  COOLDOWN_VIEWER_DATA_LOADED = true,
  COOLDOWN_VIEWER_TABLE_HOTFIXED = true,
  COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = true,
}

local function IsReadable(value)
  return not (issecretvalue and issecretvalue(value))
end

local function IsAvailable()
  return C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet and C_CooldownViewer.GetCooldownViewerCooldownInfo and Enum and Enum.CooldownViewerCategory and C_Spell and C_Spell.GetSpellCooldownDuration
end

local catalogTime

local function CatalogRefresh(event)
  if refreshEvents[event] then return true end
  return event == "OPTIONS" and not (catalog and catalogTime == GetTime())
end

local catalogSecret = false
-- ForeverAuras: a catalog built before the viewer was ready (CDMCatalog
-- notes it in cdmIncompleteCatalogs) is rebuilt on its next use after a
-- second, and the triggers are run again a little later so the displays
-- follow without a manual refresh (issue #132). Bounded: ten rebuilds
-- (timed or event-driven) per episode, then the catalog stands until a
-- refresh event; a complete build ends the episode.
local catalogRetries, catalogRetryQueued = 0, false
local viewerLoadTried = false
local function CatalogIncomplete(which)
  return which ~= nil and Private.cdmIncompleteCatalogs ~= nil and Private.cdmIncompleteCatalogs[which] == true
end
local function ScheduleCatalogRetry()
  if catalogRetryQueued then return end
  catalogRetryQueued = true
  C_Timer.After(1.5, function()
    catalogRetryQueued = false
    if Private.QueueCDMRefresh then Private.QueueCDMRefresh() end
  end)
end
-- ForeverAuras: drops the catalog so the next use builds it (CooldownViewerCatalog.lua, CDMCatalogStale).
function Private.InvalidateCDMCatalog()
  catalog = nil
end
local function GetCatalog(refresh)
  local batch = Private.cdmScanBatch
  if batch and batch.catalog then return batch.catalog end
  -- ForeverAuras: a catalog built while aura data was secret is rebuilt
  -- once it is readable again (CDMCatalog remembers what it could not read).
  if catalog and catalogSecret and not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) then refresh = true end
  -- A refresh event (a loading screen, a spell change, the options' refresh)
  -- starts a new episode of bounded retries.
  if refresh then catalogRetries = 0 end
  if catalog and not refresh and CatalogIncomplete(catalog) then
    if catalogTime and GetTime() - catalogTime >= 1 then
      -- ForeverAuras: an incomplete catalog is rebuilt on any later use a
      -- second or more after it was built, however many retries have run.
      -- The retry count bounds only the timers below: after a loading screen
      -- the viewer can take longer than the timed retries to get its frames
      -- back, and it was then left incomplete until "Refresh from Blizzard
      -- CDM"; the viewer's own refresh (hooked, Private.QueueCDMRefresh) runs
      -- the triggers when the frames do come, and that use rebuilds it.
      refresh = true
      catalogRetries = catalogRetries + 1
    else
      -- Rebuilt by an event moments ago: this use (the viewer's own refresh,
      -- say, which can be what announces its frames) must still lead to
      -- another look, or the chain would end here. One timer at most is
      -- pending, and it leads to one rebuild, so a use cannot start a loop.
      ScheduleCatalogRetry()
    end
  end
  -- ForeverAuras: Blizzard's viewer is a separate, load-on-demand addon on
  -- this client; nothing loads it until its settings are opened (the "Open
  -- CDM" button does), so without that the viewer frames the triggers read
  -- never exist and every catalog is incomplete (reported: bars only after
  -- Open CDM and a refresh, on every login). Loaded here, once, out of
  -- combat, as that button does, when a catalog is needed and the viewer is
  -- not there.
  if (refresh or not catalog) and not viewerLoadTried and not InCombatLockdown()
    and C_AddOns and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then
    viewerLoadTried = true
    local ok, loaded = pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
    if ok and loaded then ScheduleCatalogRetry() end
  end
  if catalog and not refresh then
    if batch then batch.catalog = catalog end
    return catalog
  end
  catalog = IsAvailable() and Private.CDMCatalog() or {}
  catalogSecret = Private.cdmCatalogSawSecret == true
  catalogTime = GetTime()
  if CatalogIncomplete(catalog) then
    if catalogRetries < 10 then ScheduleCatalogRetry() end
  else
    catalogRetries = 0
  end
  Private.cdmCatalogForDebug = function() return catalog end
  if batch then batch.catalog = catalog end
  return catalog
end

local function SpellRank(id)
  if not IsReadable(id) or type(id) ~= "number" then return end
  local text = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
  return IsReadable(text) and type(text) == "string" and tonumber(text:match("%d+")) or nil
end

local function ExactMatch(info, id)
  if IsReadable(info.spellID) and info.spellID == id then return 2 end
  local baseRank, rank = SpellRank(info.spellID), SpellRank(id)
  if baseRank and rank and baseRank ~= rank then return 0 end
  for _, field in ipairs({"linkedSpellID", "overrideSpellID"}) do
    if IsReadable(info[field]) and info[field] == id then return 1 end
  end
  for _, linked in ipairs(info.linkedSpellIDs or {}) do
    if IsReadable(linked) and linked == id then return 1 end
  end
  return 0
end

-- nil uses the entry picker; an empty filter selects nothing.
function Private.CDMSpellQueries(trigger)
  if not (trigger.cdmUseNames or trigger.cdmUseExactIDs or (trigger.event == "Blizzard CDM Item" and trigger.cdmUseItemIDs)) then return end
  local queries, seen = {}, {}
  local function Add(values, exact, itemExact)
    for _, value in ipairs(values or {}) do
      local query = tostring(value):match("^%s*(.-)%s*$")
      local key = (itemExact and "item:" or exact and "id:" or "name:") .. query
      if query ~= "" and not seen[key] then
        seen[key] = true
        local buff = trigger.event == "Blizzard CDM Buff"
        queries[#queries + 1] = {type = "cdm", event = trigger.event, cdmSource = buff and "buff" or "cooldown",
          cdmSelection = "spell", cdmSpell = query, cdmExact = exact, cdmItemExact = itemExact == true, use_ignoreSpellKnown = trigger.use_ignoreSpellKnown,
          showGCD = trigger.use_cdmShowGCD == true, track = trigger.cdmTrack or "auto", hideGCDText = trigger.cdmHideGCDText ~= false,
          showMode = buff and (trigger.cdmBuffShow or "active") or (trigger.cdmShow or "always"),
          requireTarget = buff and trigger.cdmRequireTarget == true}
      end
    end
  end
  if trigger.cdmUseNames then Add(trigger.cdmNames, false) end
  if trigger.cdmUseExactIDs then Add(trigger.cdmExactIDs, true) end
  if trigger.event == "Blizzard CDM Item" and trigger.cdmUseItemIDs then Add(trigger.cdmItemIDs, false, true) end
  return queries
end

local resolved = {}

-- ForeverAuras: each entry's aura spell IDs as last seen readable. They are
-- static data, but an entry whose aura is up reports them secret in combat,
-- and its viewer frame keeps secret values after combat until its next aura
-- event; an index built then had no name for that entry, so a buff applied
-- in combat had no trigger state afterwards. The remembered IDs stand in
-- while the live ones are secret.
local rememberedEntrySpells = {}
local function AurasSecret()
  return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() or false
end
local function EntryAuraSpellIDs(entryID, info)
  local ids = Private.CDMAuraSpellIDs(info)
  if IsReadable(info.spellID) and #ids > 0 then
    rememberedEntrySpells[entryID] = ids
  elseif #ids == 0 and rememberedEntrySpells[entryID] then
    ids = rememberedEntrySpells[entryID]
    resolved.sawSecret = true
  end
  return ids
end

-- Resolve all buff names in one catalog pass. Login can evaluate many names in
-- several auras; avoid repeating the full entry/rank search for each name.
-- This uses only CDM-provided IDs, with the same lifetime as the existing query
-- cache. A catalog refresh drops the index, including spell/rank/known lookups.
local function BuffNameIndex(entries)
  if resolved.buffNames then return resolved.buffNames end
  local names, spells = {}, {}
  local frames = Private.CDMFrames()
  for entryID, entry in pairs(entries) do
    if Private.CDMIsBuff(entry.category) then
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(entryID)
      if info then
        local displayed = entry.displayed == true
        local ids = EntryAuraSpellIDs(entryID, info)
        local frame = frames[entryID]
        local frameSpell = frame and frame.GetSpellID and frame:GetSpellID()
        if IsReadable(frameSpell) and type(frameSpell) == "number" then ids[#ids + 1] = frameSpell
        elseif frameSpell ~= nil then resolved.sawSecret = true end
        for _, spellID in ipairs(ids) do
          local spell = spells[spellID]
          if spell == nil then
            local info = C_Spell.GetSpellInfo(spellID)
            spell = info and {name = info.name:lower(), id = spellID} or false
            spells[spellID] = spell
          end
          if spell then
            local candidates = names[spell.name]
            if not candidates then candidates = {}; names[spell.name] = candidates end
            candidates[#candidates + 1] = {spell = spell, entryID = entryID, displayed = displayed,
              direct = IsReadable(info.spellID) and info.spellID == spellID and 1 or 0}
          end
        end
      end
    end
  end
  resolved.buffNames = names
  return names
end
function Private.ResolveCDMSpell(trigger, event)
  if trigger.type == "cdm" then trigger.cdmSource = trigger.event == "Blizzard CDM Buff" and "buff" or "cooldown" end
  if refreshEvents[event] then Private.CDMResetIdentities() end
  local entries = GetCatalog(CatalogRefresh(event))
  local query = tostring(trigger.cdmSpell or ""):match("^%s*(.-)%s*$")
  if trigger.event == "Blizzard CDM Item" then
    -- Equipment and category-source identities can change without a catalog change.
    local selected = {buffSpellIDsByEntry = {}}
    local id = tonumber(query)
    local spell = id and not trigger.cdmItemExact and C_Spell.GetSpellInfo(id)
    local name = (spell and spell.name or query):lower()
    local frames = Private.CDMFrames()
    for entryID, entry in pairs(entries) do
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(entryID)
      if info and Private.CDMEntryMatches(trigger, entry, info, event == "OPTIONS") then
        local identity = Private.CDMIdentity(entryID, entry, info, frames[entryID])
        local useSpell
        if identity.itemID and C_Item and C_Item.GetItemSpell then
          local _, spellID = C_Item.GetItemSpell(identity.itemID)
          useSpell = spellID
        end
        local spellInfo = (useSpell or identity.spellID) and C_Spell.GetSpellInfo(useSpell or identity.spellID)
        local matches
        if trigger.cdmItemExact then
          matches = id and identity.itemID == id
        elseif trigger.cdmExact then
          matches = id and (ExactMatch(info, id) > 0 or identity.spellID == id or useSpell == id)
        else
          matches = query ~= "" and (identity.name:lower() == name or spellInfo and spellInfo.name:lower() == name)
        end
        if matches then selected[#selected + 1] = entryID end
      end
    end
    table.sort(selected)
    return selected
  end
  local key = tostring(trigger.cdmSelection) .. ":" .. tostring(trigger.event) .. ":" .. query .. ":" .. tostring(trigger.cdmExact) .. ":" .. (trigger.cdmSource or "cooldown") .. ":" .. tostring(trigger.use_ignoreSpellKnown) .. ":" .. tostring(event == "OPTIONS")
  if resolved.entries ~= entries then resolved = {entries = entries} end
  -- ForeverAuras: a resolution that met secret values is dropped once auras
  -- are readable again, so it is rebuilt from live data (see EntryAuraSpellIDs).
  if resolved.sawSecret and not AurasSecret() then resolved = {entries = entries} end
  if resolved[key] then return resolved[key] end
  local id = tonumber(query)
  if trigger.cdmExact and not id then return {} end
  local spell = id and C_Spell.GetSpellInfo(id)
  local name = (spell and spell.name or query):lower()
  local exact = trigger.cdmExact == true
  if event ~= "OPTIONS" and trigger.event == "Blizzard CDM Buff" and not exact then
    local bestEntry, bestSpell, bestRank, bestDirect
    for _, candidate in ipairs(BuffNameIndex(entries)[name] or {}) do
      local spell = candidate.spell
      -- Rank/known checks are lazy: unrelated names never need them. Duplicate
      -- linked IDs share this record, but each entry keeps its own tie-breakers.
      if spell.known == nil then
        spell.known = WeakAuras.IsSpellKnownIncludingPet(spell.id) == true
        if spell.known then spell.rank = SpellRank(spell.id) or 0 end
      end
      -- An entry's own spell can be a stand-in that no one learns (Blizzard's
      -- "Curses", 1319652, linking every curse): the entry being known counts.
      local known = spell.known
      if not known and entries[candidate.entryID] and entries[candidate.entryID].known == true then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(candidate.entryID)
        if info and (IsReadable(info.spellID) and info.spellID == spell.id or IsReadable(info.overrideSpellID) and info.overrideSpellID == spell.id) then
          known = true
          spell.rank = spell.rank or 0
        end
      end
      if known then
        local rank, direct, entryID = spell.rank, candidate.direct, candidate.entryID
        local displayed = candidate.displayed
        if not bestSpell or rank > bestRank or (rank == bestRank and displayed
            and (not bestEntry or direct > bestDirect or (direct == bestDirect and entryID < bestEntry))) then
          bestEntry, bestSpell, bestRank, bestDirect = displayed and entryID or nil, spell.id, rank, direct
        end
      end
    end
    -- Names follow one learned rank and one CDM entry, never a union of rank states.
    local selected = bestEntry and {bestEntry} or {}
    selected.singleClone, selected.buffName = true, name
    selected.buffResolvedSpellID = bestSpell
    selected.buffSpellIDs = bestSpell and {bestSpell} or {}
    -- The name of the entry itself (its own spell ID) stands for every aura
    -- the entry links, so the native binding follows whichever is up.
    if bestEntry and bestSpell then
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(bestEntry)
      if info and (IsReadable(info.spellID) and info.spellID == bestSpell or IsReadable(info.overrideSpellID) and info.overrideSpellID == bestSpell) then
        local ids = Private.CDMAuraSpellIDs(info)
        if #ids > 1 then selected.buffSpellIDs = ids end
      end
    end
    resolved[key] = selected
    return selected
  end
  local anyBuffRank = not exact and trigger.cdmSource == "buff"
  local buffSpellIDs, seen, buffEntryIDs = {}, {}, {}
  local function AddBuffID(spellID)
    if not IsReadable(spellID) or type(spellID) ~= "number" or seen[spellID] then return end
    local spell = C_Spell.GetSpellInfo(spellID)
    if spell and spell.name:lower() == name then seen[spellID] = true; buffSpellIDs[#buffSpellIDs + 1] = spellID end
  end
  local best, bestRank, bestScore
  local memo = event == "OPTIONS" and resolved
  if memo and not memo.entryInfo then memo.entryInfo, memo.identities, memo.spellNames = {}, {}, {} end
  local function EntryInfo(entryID)
    if not memo then return C_CooldownViewer.GetCooldownViewerCooldownInfo(entryID) end
    local cached = memo.entryInfo[entryID]
    if cached == nil then
      cached = C_CooldownViewer.GetCooldownViewerCooldownInfo(entryID) or false
      memo.entryInfo[entryID] = cached
    end
    return cached or nil
  end
  local function Identity(entryID, entry, info)
    if not memo then return Private.CDMIdentity(entryID, entry, info) end
    local cached = memo.identities[entryID]
    if not cached then
      cached = Private.CDMIdentity(entryID, entry, info)
      memo.identities[entryID] = cached
    end
    return cached
  end
  local function SpellNameLower(spellID)
    if not memo then
      local spellInfo = C_Spell.GetSpellInfo(spellID)
      return spellInfo and spellInfo.name:lower()
    end
    local cached = memo.spellNames[spellID]
    if cached == nil then
      local spellInfo = C_Spell.GetSpellInfo(spellID)
      cached = spellInfo and spellInfo.name:lower() or false
      memo.spellNames[spellID] = cached
    end
    return cached or nil
  end
  for entryID, entry in pairs(entries) do
    if (event == "OPTIONS" or entry.known or exact or anyBuffRank or trigger.use_ignoreSpellKnown) and Private.CDMIsBuff(entry.category) == (trigger.cdmSource == "buff") then
      local info = EntryInfo(entryID)
      if info and (trigger.cdmSelection ~= "spell" or Private.CDMEntryMatches(trigger, entry, info, event == "OPTIONS")) then
        local identity = Identity(entryID, entry, info)
        local score = exact and ExactMatch(info, id) or 1
        local matches = exact and score > 0 or not exact and identity.name:lower() == name
        local auraSpellIDs = anyBuffRank and EntryAuraSpellIDs(entryID, info)
        -- A CDM entry can display a linked effect with a different name from its base aura.
        if anyBuffRank and not matches then
          for _, spellID in ipairs(auraSpellIDs) do
            if SpellNameLower(spellID) == name then matches = true; break end
          end
        end
        if matches and anyBuffRank then
          buffEntryIDs[#buffEntryIDs + 1] = entryID
          AddBuffID(identity.spellID)
          for _, spellID in ipairs(auraSpellIDs) do AddBuffID(spellID) end
          score = entry.known and 1 or 0
        end
        if matches and identity.spellID then
          local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(trigger.cdmSelection == "spell" and info.spellID or identity.spellID)
          local rank = IsReadable(subtext) and type(subtext) == "string" and tonumber(subtext:match("%d+")) or 0
          if not best or score > bestScore or (score == bestScore and (rank > bestRank or (rank == bestRank and entryID < best))) then best, bestRank, bestScore = entryID, rank, score end
        end
      end
    end
  end
  -- Keep configured spell samples visible even without a usable CDM entry.
  if event == "OPTIONS" and not best then
    resolved[key] = {previewSpell = spell or {name = query, iconID = 134400, spellID = id}, singleClone = true}
    return resolved[key]
  end
  resolved[key] = best and {best} or {}
  if anyBuffRank then
    table.sort(buffSpellIDs)
    table.sort(buffEntryIDs)
    resolved[key].buffSpellIDs = buffSpellIDs
    if trigger.cdmSelection == "spell" then resolved[key].buffEntryIDs = buffEntryIDs end
  end
  if trigger.cdmSelection == "spell" then resolved[key].singleClone = true end
  return resolved[key]
end

function Private.CDMEntryMatches(trigger, entry, info, preview)
  -- Editor samples remain available when an entry is not currently displayed.
  if not preview and entry.displayed ~= true then return false end
  local c = Enum.CooldownViewerCategory
  local item = info.equipSlot ~= nil or info.spellCategoryID ~= nil
    or entry.sourceCategory == c.EquipSlotEssential or entry.sourceCategory == c.EquipSlotTracked
  if trigger.event == "Blizzard CDM Item" then return item and not Private.CDMIsBuff(entry.category) end
  if trigger.event == "Blizzard CDM Buff" then return Private.CDMIsBuff(entry.category) end
  if item then return false end
  return entry.category == c.Essential or entry.category == c.Utility
end

function Private.CDMAuraSpellIDs(info)
  local ids, seen = {}, {}
  local function Add(id)
    if IsReadable(id) and type(id) == "number" and id > 0 and not seen[id] then
      seen[id] = true; ids[#ids + 1] = id
    end
  end
  Add(info.spellID); Add(info.overrideSpellID); Add(info.overrideTooltipSpellID); Add(info.linkedSpellID)
  for _, id in ipairs(info.linkedSpellIDs or {}) do Add(id) end
  table.sort(ids)
  return ids
end

function Private.GetCDMPickerSelections(trigger, event)
  local selected = {buffSpellIDsByEntry = {}}
  local entries = GetCatalog(CatalogRefresh(event))
  for key, enabled in pairs(trigger.cdmSpells and trigger.cdmSpells.multi or {}) do
    local id = tonumber(key)
    local entry = id and entries[id]
    local info = entry and C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if enabled and info and Private.CDMEntryMatches(trigger, entry, info, event == "OPTIONS") then
      selected[#selected + 1] = id
      selected.buffSpellIDsByEntry[id] = Private.CDMAuraSpellIDs(info)
    end
  end
  table.sort(selected)
  return selected
end

function Private.CDMNativeSelections(trigger)
  local queries = Private.CDMSpellQueries(trigger)
  if queries then
    local bindings = {}
    for _, query in ipairs(queries) do
      for _, ids in ipairs(Private.CDMNativeSelections(query)) do bindings[#bindings + 1] = ids end
    end
    return bindings
  end
  if trigger.cdmSpell ~= nil and tostring(trigger.cdmSpell):find("%S") and trigger.event ~= "Blizzard CDM Item" then
    local selected = Private.ResolveCDMSpell(trigger)
    local id = trigger.cdmExact and tonumber(trigger.cdmSpell)
    return {id and selected[1] and {id} or selected.buffSpellIDs}
  end
  local selected = Private.GetCDMPickerSelections(trigger, "OPTIONS")
  local bindings = {}
  for _, id in ipairs(selected) do bindings[#bindings + 1] = selected.buffSpellIDsByEntry[id] end
  return bindings
end

local function GetSelections(trigger)
  local queries = Private.CDMSpellQueries(trigger)
  if queries then
    local selected, seen = {}, {}
    for _, query in ipairs(queries) do
      for _, id in ipairs(Private.ResolveCDMSpell(query)) do
        if not seen[id] then selected[#selected + 1] = id; seen[id] = true end
      end
    end
    return selected
  end
  if trigger.cdmSpell ~= nil and tostring(trigger.cdmSpell):find("%S") and trigger.event ~= "Blizzard CDM Item" then return Private.ResolveCDMSpell(trigger) end
  return Private.GetCDMPickerSelections(trigger)
end

local function GetValues(trigger)
  local values = {}
  local frames = Private.CDMFrames()
  for id, entry in pairs(GetCatalog(true)) do
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
    if info then
      local identity = Private.CDMIdentity(id, entry, info, frames[id])
      local placement = entry.displayed == true and "Displayed" or entry.displayed == false and "Not displayed" or "Layout unavailable"
      local learned = entry.known and "" or " â€” Not learned"
      values[id] = placement .. " â€” " .. Private.CDMCategoryName(entry.category) .. " â€” " .. identity.name .. " [" .. (identity.spellID or identity.itemID or "Unknown") .. "]" .. learned
    end
  end
  for _, id in ipairs(GetSelections(trigger)) do
    if type(id) == "number" and not values[id] then values[id] = L["Unavailable in this specialization"] end
  end
  return values
end

local function ReadBoolean(value)
  if IsReadable(value) and type(value) == "boolean" then return value end
end

local spellCooldowns = {}
local function GetSpellCooldownState(spellID, event)
  local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
  local active = info and ReadBoolean(info.isActive)
  if active == nil then return end
  local status = spellCooldowns[spellID]
  if not status then status = {}; spellCooldowns[spellID] = status end
  if not active then
    status.onCooldown, status.onGCD = false, false
  end
  -- Blizzard only guarantees isOnGCD during SPELL_UPDATE_COOLDOWN.
  -- Missing flags must not turn an unknown/GCD timer into a real cooldown.
  if active and event == "SPELL_UPDATE_COOLDOWN" and ReadBoolean(info.isOnGCD) == nil then
    status.onCooldown, status.onGCD = nil, nil
  end
  if active and event == "SPELL_UPDATE_COOLDOWN" and ReadBoolean(info.isOnGCD) ~= nil then
    local onGCD = info.isOnGCD == true
    -- The public event-scoped flag is sufficient; do not delay a visible GCD.
    status.onCooldown, status.onGCD = not onGCD, onGCD
  end
  return status.onCooldown, true, status.onGCD
end

local function QueueRefresh()
  Private.QueueCDMRefresh()
end

local built = {}
local function BuildCooldownViewerStates(allstates, selected, event, showGCD, track, hideGCDText, showMode, exactID, requireTarget, ignoreSpellKnown)
  wipe(built)
  if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then Private.CDMResetIdentities() end
  local available = GetCatalog(CatalogRefresh(event))
  local frames = Private.CDMFrames()
  for _, state in pairs(allstates) do
    state.show = false
    state.changed = true
  end

  if event ~= "FA_CDM_REFRESH" and event ~= "OPTIONS"
      and event ~= "GET_ITEM_INFO_RECEIVED" and event ~= "ITEM_DATA_LOAD_RESULT"
      and #selected > 0 then QueueRefresh() end
  -- A missing catalog entry is not a reason to hide an editor selection.
  if event == "OPTIONS" and selected.previewSpell then
    local spell = selected.previewSpell
    allstates[""] = {show = true, changed = true, progressType = "timed", duration = 6,
      expirationTime = GetTime() + 6, autoHide = false, name = spell.name, icon = spell.iconID,
      spellId = spell.spellID, cdmTextPreview = true, index = 1}
    built[""] = true
    return true
  end
  if not IsAvailable() then return true end
  if requireTarget and event ~= "OPTIONS" then
    local exists = UnitExists("target")
    local attackable = UnitCanAttack("player", "target")
    if not IsReadable(exists) or not IsReadable(attackable) then return true end
    if not exists or not attackable then return true end
  end

  for index, cooldownID in ipairs(selected) do
    local entry = available[cooldownID]
    if entry and (event == "OPTIONS" or entry.known or exactID or selected.buffSpellIDs or selected.buffSpellIDsByEntry or ignoreSpellKnown) then
      local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
      if info then
        local identity = Private.CDMIdentity(cooldownID, entry, info, frames[cooldownID])
        local displaySpellID = exactID or selected.buffResolvedSpellID
        if displaySpellID then
          local spell = C_Spell.GetSpellInfo(displaySpellID)
          identity = {spellID = displaySpellID, name = spell and spell.name or identity.name, icon = spell and spell.iconID or identity.icon}
        end
        -- A single spell's state is the trigger's plain (non-clone) state, keyed
        -- "", so the display finds it for conditions on the trigger's variables
        -- and for its Active check; a named key left those looking at nothing.
        local cloneID = selected.singleClone and "" or tostring(cooldownID)
        local state = allstates[cloneID]
        if not state then
          state = {}
          allstates[cloneID] = state
        elseif not built[cloneID] then
          wipe(state)
        end
        built[cloneID] = true
        state.show, state.changed, state.autoHide = true, true, false
        state.index, state.name, state.icon = index, identity.name, identity.icon
        state.spellId, state.itemId, state.cooldownID = identity.spellID, identity.itemID, type(cooldownID) == "number" and cooldownID or nil
        state.cdmDisplayed, state.cdmCategory = entry.displayed, Private.CDMCategoryName(entry.category)
        state.progressType, state.value, state.total = "static", 1, 1
        state.durationObject, state.duration, state.expirationTime, state.modRate = nil, nil, nil, nil
        -- Reused states must not retain a spell-only text requirement for buffs/items/previews.
        state.cdmTextDurationObject, state.cdmTextDurationRequired = nil, nil
        state.cdmSuppressGCD = false
        state.cdmBarSource = nil
        state.cdmNativePaused = false
        state.cdmBuff = Private.CDMIsBuff(entry.category)
        local bindingIDs = selected.buffSpellIDsByEntry and selected.buffSpellIDsByEntry[cooldownID]
        -- An entry picked from the list carries every aura it stands for
        -- (its linked spell IDs: Blizzard's "Curses" entry lists each curse),
        -- so the native binding and the live icon follow whichever is up.
        local entryIDs
        if state.cdmBuff and not bindingIDs and not exactID and not selected.buffSpellIDs then
          entryIDs = Private.CDMAuraSpellIDs(info)
          if #entryIDs == 0 then entryIDs = nil end
        end
        state.cdmAuraSpellIDs = state.cdmBuff and (bindingIDs or (exactID and {exactID}) or selected.buffSpellIDs or entryIDs or {identity.spellID}) or nil
        state.cdmTextPreview = event == "OPTIONS"
        -- Clear native fallback identity before selecting a fresh buff clone;
        -- an absent/changed viewer must not retain the previous aura's slot.
        state.cdmAuraRenderUnit, state.cdmAuraRenderSpellIDs = nil, nil
        state.cdmCountdownSource, state.cdmStackSource, state.cdmTextRecord, state.cdmDispelName = nil, nil, nil, nil
        state.isUsable, state.insufficientResources = nil, nil
        state.onCooldown, state.isReady, state.recharging, state.stacks, state.auraActive = nil, nil, nil, nil, nil
        state.cdmNativeShow = nil
        state.wandAppearanceDuration = nil -- No snapshot may survive source/clone reuse.
        state.cdmGCDOnly, state.cdmHideGCDText = false, hideGCDText == true

        -- OPTIONS always uses a six-second sample, never live timers or checks.
        if event == "OPTIONS" then
          state.progressType, state.duration, state.expirationTime = "timed", 6, GetTime() + 6
          state.value, state.total = nil, nil
          state.stacks, state.auraActive, state.onCooldown = 3, true, true
          state.cdmHideGCDText = false
        elseif Private.CDMIsBuff(entry.category) then
          if selected.buffEntryIDs then
            local bestAura, bestScore
            local candidates = {}
            for _, auraID in ipairs(selected.buffEntryIDs) do
              local auraInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(auraID)
              if auraInfo and available[auraID] then
                local candidate = {}
                local auraIdentity = Private.CDMIdentity(auraID, available[auraID], auraInfo, frames[auraID])
                Private.CDMApplyAura(candidate, auraIdentity, auraInfo, frames[auraID], nil, selected.buffSpellIDs)
                candidates[#candidates + 1] = candidate
                local score = candidate.auraActive == true and 2 or candidate.auraActive == nil and 1 or 0
                if not bestAura or score > bestScore then bestAura, bestScore = candidate, score end
              end
            end
            for key, value in pairs(bestAura or {}) do state[key] = value end
            -- Several entries (any of these auras): while none is known to be
            -- active, which cannot be known in combat, the native binding
            -- watches every entry's aura IDs on the unit instead of only the
            -- first entry's, so whichever of them is up drives the timer text.
            if bestAura and bestScore < 2 and #candidates > 1 then
              local unit = state.cdmAuraRenderUnit
              if not unit then
                for _, candidate in ipairs(candidates) do
                  if candidate.cdmAuraRenderUnit then unit = candidate.cdmAuraRenderUnit; break end
                end
              end
              if unit then
                local ids, seen = {}, {}
                for _, candidate in ipairs(candidates) do
                  if candidate.cdmAuraRenderUnit == unit and type(candidate.cdmAuraRenderSpellIDs) == "table" then
                    for _, id in ipairs(candidate.cdmAuraRenderSpellIDs) do
                      if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
                    end
                  end
                end
                if #ids > 0 then
                  state.cdmAuraRenderUnit, state.cdmAuraRenderSpellIDs = unit, ids
                  state.cdmAuraFilter = state.cdmAuraFilter or bestAura.cdmAuraFilter
                  -- The first entry's timer may belong to an aura that is not
                  -- up; a static progress hands swipe and countdown to the
                  -- native binding (CDMAuraProgress), which follows whichever
                  -- of the IDs is on the unit.
                  state.progressType, state.durationObject, state.duration, state.expirationTime = "static", nil, nil, nil
                  state.value, state.total, state.cdmCountdownSource, state.cdmBarSource = nil, nil, nil, nil
                end
              end
            end
            if state.progressType ~= "static" then state.value, state.total = nil, nil end
          else
          Private.CDMApplyAura(state, identity, info, frames[cooldownID], exactID, bindingIDs or selected.buffSpellIDs)
          end
        elseif identity.slot or identity.itemID then
          Private.CDMApplyItem(state, identity)
        elseif identity.spellID then
          local spellID = identity.spellID
          if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
            local override = C_SpellBook.FindSpellOverrideByID(spellID)
            if IsReadable(override) and type(override) == "number" and override > 0 then spellID = override end
          end
          -- Usability includes reactive/resource requirements, independently of cooldown readiness.
          -- Never compare or expose a secret result as a condition value.
          if C_Spell.IsSpellUsable then
            local usable, insufficientResources = C_Spell.IsSpellUsable(spellID)
            state.isUsable = ReadBoolean(usable)
            state.insufficientResources = ReadBoolean(insufficientResources)
          end
          -- Spell Count, as on the spell Cooldown trigger (the count a spell
          -- shows on its button: reagent-limited casts and the like).
          local GetSpellCount = GetSpellCount or (C_Spell and C_Spell.GetSpellCastCount)
          if GetSpellCount then
            local ok, count = pcall(GetSpellCount, spellID)
            state.spellCount = ok and IsReadable(count) and type(count) == "number" and count or nil
          end
          local onCooldown, hasCooldownFlags, onGCD = GetSpellCooldownState(spellID, event)
          -- Keep the GCD-free text source independent of native frame flags, which
          -- can be unavailable in combat or refer to the previous viewer refresh.
          local realDuration = Private.GetSpellCooldownDurationWithoutGCD(spellID, onGCD)
          local textDuration = realDuration
          local native = Private.CDMGetNativeCooldown(frames[cooldownID], identity.spellID)
          -- Text and desaturation share a copied timer during Shoot; native state
          -- and swipe keep the current cooldown.
          local wandHeld
          textDuration, wandHeld = Private.GetWandCooldownDuration(spellID, textDuration, "cdm")
          state.wandAppearanceDuration = wandHeld and textDuration or nil
          state.cdmNativeRevision = native and native.revision
          -- A hidden GCD must not re-enter through the viewer's unfiltered swipe.
          local duration = showGCD and native and native.duration or realDuration
          state.cdmNativePaused = native and native.paused == true or false
          if state.cdmNativePaused then state.wandAppearanceDuration = nil end
          if native then
            state.inRange = native.inRange
            state.stacks = native.charges
            if native.charges ~= nil then state.isReady = native.charges > 0 end
            if native.onGCD ~= nil then state.cdmGCDOnly = native.onGCD end
            if native.onCooldown ~= nil then
              state.onCooldown = native.onCooldown
              if state.stacks == nil then state.isReady = not native.onCooldown end
            end
            if native.recharging ~= nil then state.recharging = native.recharging end
          end
          -- Native frame flags can be secret even when these API flags are public.
          if onCooldown ~= nil then
            state.onCooldown, state.isReady = onCooldown, not onCooldown
            if onCooldown then
              duration = realDuration
              state.cdmGCDOnly, state.cdmNativePaused = false, false
            elseif onGCD then
              duration = showGCD and C_Spell.GetSpellCooldownDuration(spellID) or nil
              state.cdmGCDOnly, state.cdmNativePaused = true, false
            else
              duration = realDuration
              state.cdmGCDOnly, state.cdmNativePaused = false, false
            end
          elseif hasCooldownFlags and not state.cdmGCDOnly then
            -- Unknown GCD status still honors the explicit swipe choice. Text uses
            -- the separately filtered duration and needs no readable timing values.
            duration = showGCD and C_Spell.GetSpellCooldownDuration(spellID) or realDuration
            state.cdmNativePaused = false
          end
          local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
          if charges then
            local count = charges.currentCharges
            local recharging = ReadBoolean(charges.isActive)
            if recharging ~= nil then state.recharging = recharging end
            if IsReadable(count) and type(count) == "number" then
              state.stacks = count
              state.isReady, state.onCooldown = count > 0, count == 0
            elseif native and native.recharging == true then
              state.isReady, state.onCooldown = true, false
            end
          end
          if C_Spell.GetSpellChargeDuration and (track == "charges" or (track == "auto" and state.recharging == true)) then
            local chargeDuration = C_Spell.GetSpellChargeDuration(spellID)
            if chargeDuration then
              -- Recharge numbers remain visible even when the spell timer is a GCD.
              duration, textDuration = chargeDuration, chargeDuration
              state.wandAppearanceDuration = nil -- Never suppress real recharge appearance.
              state.cdmGCDOnly, state.cdmNativePaused = false, false
            end
          end
          -- Show GCD takes effect on the first update, including consecutive casts.
          -- Text suppression is independent and must not temporarily blank the swipe.
          if state.cdmGCDOnly and not showGCD then
            duration = nil
          end
          state.cdmSuppressGCD = not duration
          if duration then
            state.progressType, state.durationObject = "durationObject", duration
            state.value, state.total = nil, nil
          else
            -- Zero duration keeps %p empty and progress bars unfilled.
            state.progressType, state.duration, state.expirationTime = "timed", 0, 0
            state.value, state.total = nil, nil
          end
          if hideGCDText then
            -- Always use the independently filtered source, including when the
            -- native GCD flag cannot be read. Do not fall back to the swipe timer.
            state.cdmTextDurationObject = textDuration
            -- If the filtered API temporarily returns nothing, leave text empty
            -- until it is available instead of borrowing the unfiltered swipe.
            state.cdmTextDurationRequired = true
          end
        end
        if event ~= "OPTIONS" then
          -- These opt-in modes leave existing show modes and preview behavior unchanged.
          if showMode == "usable" then state.show = state.isUsable == true
          elseif showMode == "unusable" then state.show = state.isUsable == false end
          if not ignoreSpellKnown and not state.cdmBuff and not Private.CDMEntryMatches({event = "Blizzard CDM Item"}, entry, info) then
            local known = false
            for _, id in pairs({identity.spellID, info.spellID, info.overrideSpellID, info.linkedSpellID}) do
              if IsReadable(id) and type(id) == "number" and id > 0 and id < 2147483647
                  and WeakAuras.IsSpellKnownIncludingPet(id) then known = true; break end
            end
            if not known then state.show = false end
          end
          if state.show and showMode == "cooldown" then state.show = state.onCooldown == true elseif state.show and showMode == "ready" then state.show = state.onCooldown == false
          elseif state.show and (showMode == "active" or showMode == "missing") then
            -- Show If Unit Does Not Exist (no Require target): with no target
            -- for a target aura the display stays, in its missing look, for
            -- Found as for Missing; Require target hides it (above).
            local unitGone = false
            if state.cdmBuff and not requireTarget and event ~= "OPTIONS" then
              -- Spell data decides (every rank: a Bane's listed spell alone
              -- answers no), as the native slot's unit does; the viewer
              -- frame's unit counts only once it was actually seen, since an
              -- unseen frame reports the player for a target debuff.
              -- ForeverAuras: a frame that reported its unit decides; spell
              -- data is asked only when no frame has. Asked always, it could
              -- call a buff the frame had seen on the player a target aura,
              -- and with no target (the fight over) the buff read as absent.
              local targetAura = state.cdmAuraSourceSeen and state.cdmAuraUnit == "target"
              if not state.cdmAuraSourceSeen then targetAura = Private.CDMSpellsTargetEnemy(state.cdmAuraSpellIDs) end
              if targetAura then
                local exists = UnitExists("target")
                unitGone = IsReadable(exists) and exists == false
              end
            end
            if unitGone then
              state.auraActive = false
              -- Aura(s) Found: no target is no aura (the option belongs to
              -- Missing and Always, as on an Aura trigger).
              if showMode == "active" then state.show = false end
            -- The aura cannot be read (in combat): the state stays shown and
            -- the display's visibility follows the native aura slot instead
            -- (CDMAuraProgress, cdmNativeShow), so the trigger works in combat
            -- on its own. Readable auras decide here, as before.
            elseif state.auraActive == nil and state.cdmBuff and not state.cdmTextPreview and not state.cdmAuraTotem then
              state.cdmNativeShow = showMode
            elseif showMode == "active" then state.show = state.auraActive == true
            else state.show = state.auraActive == false end
          end
        end
        state.hasTimer = state.durationObject ~= nil or state.progressType == "timed"
      end
    end
  end
  return true
end

-- Compare snapshots because the trigger engine modifies live states.
-- Secret values and mutable aura bindings still require an update.
local snapshots = setmetatable({}, {__mode = "k"})
local persistentOutputs = setmetatable({}, {__mode = "k"})
local function GetOutputs(selected, event, showGCD, track, hideGCDText, showMode, exactID, requireTarget, ignoreSpellKnown)
  local batch = Private.cdmScanBatch
  local key = (event or "") .. ":" .. tostring(showGCD) .. ":" .. tostring(track) .. ":" .. tostring(hideGCDText)
    .. ":" .. tostring(showMode) .. ":" .. tostring(exactID) .. ":" .. tostring(requireTarget) .. ":" .. tostring(ignoreSpellKnown)
  local cache
  if batch then
    batch.outputs = batch.outputs or {}
    cache = batch.outputs[selected]
    if not cache then cache = {}; batch.outputs[selected] = cache end
    if cache[key] then return cache[key] end
  end
  local store = persistentOutputs[selected]
  if not store then store = {}; persistentOutputs[selected] = store end
  local outputs = store[key]
  if not outputs then outputs = {}; store[key] = outputs end
  BuildCooldownViewerStates(outputs, selected, event, showGCD, track, hideGCDText, showMode, exactID, requireTarget, ignoreSpellKnown)
  for cloneID in pairs(outputs) do
    if not built[cloneID] then outputs[cloneID] = nil end
  end
  if cache then cache[key] = outputs end
  return outputs
end
local function SameOutput(previous, current)
  if not previous or current.cdmBuff then return false end
  -- Combat timers can change in place while their values remain unreadable.
  if InCombatLockdown and InCombatLockdown() then return false end
  for key, value in pairs(current) do
    if key ~= "changed" then
      local old = previous[key]
      if not IsReadable(value) or not IsReadable(old) or value ~= old then return false end
    end
  end
  for key in pairs(previous) do
    if key ~= "changed" and current[key] == nil then return false end
  end
  return true
end

-- The last output of a trigger's single buff entry, shown or not: a hidden
-- state is dropped from the trigger's states, but the display still needs to
-- know whether the aura was absent or merely secret (CDMAuraProgress).
function Private.CDMLastOutput(allstates)
  local previous = allstates and snapshots[allstates]
  if not previous then return end
  for _, output in pairs(previous) do return output end
end

local function CommitStates(allstates, outputs)
  local previous = snapshots[allstates]
  if not previous then previous = {}; snapshots[allstates] = previous end
  local changed = false
  for key, output in pairs(outputs) do
    local state = allstates[key]
    local snapshot = previous[key]
    if not state or not SameOutput(snapshot, output) or state.show ~= output.show then
      if not state then state = {}; allstates[key] = state end
      if snapshot then
        for field in pairs(snapshot) do
          if field ~= "changed" then state[field] = nil end
        end
      end
      for field, value in pairs(output) do state[field] = value end
      state.changed = true
      changed = true
    end
    if snapshot then wipe(snapshot) else snapshot = {}; previous[key] = snapshot end
    for field, value in pairs(output) do snapshot[field] = value end
  end
  for key, state in pairs(allstates) do
    if not outputs[key] and state.show then
      local snapshot = previous[key]
      if snapshot then
        for field in pairs(snapshot) do
          if field ~= "changed" then state[field] = nil end
        end
      end
      state.show, state.changed = false, true
      changed = true
    end
  end
  for key in pairs(previous) do
    if not outputs[key] then previous[key] = nil end
  end
  return changed
end

-- A target change is settled a frame later: targeting a unit while one is
-- targeted (or re-targeting the same one) clears the target and sets it as
-- two events in one frame, which hid and showed every target-aura display in
-- between, re-laying out its group twice (a visible flicker). The states are
-- left as they are on the event itself and updated once, from the settled
-- target, on the frame after.
local targetSettle
local function SettleTarget()
  if targetSettle then return end
  targetSettle = C_Timer.NewTimer(0, function()
    targetSettle = nil
    if Private.ScanEvents then Private.ScanEvents("FA_CDM_TARGET_SETTLED") end
  end)
end
function Private.UpdateCooldownViewerStates(allstates, selected, event, ...)
  if event == "PLAYER_TARGET_CHANGED" then SettleTarget(); return false end
  return CommitStates(allstates, GetOutputs(selected, event, ...))
end

Private.ExecEnv.UpdateCooldownViewerStates = Private.UpdateCooldownViewerStates
Private.ExecEnv.UpdateCDMSpell = function(allstates, config, event, ...)
  local selected = Private.ResolveCDMSpell(config, event)
  return Private.UpdateCooldownViewerStates(allstates, selected, event, config.showGCD, config.track, config.hideGCDText, config.showMode, config.cdmExact and tonumber(config.cdmSpell) or nil, config.requireTarget, config.use_ignoreSpellKnown)
end

local listOutputs = setmetatable({}, {__mode = "k"})
local listClones = setmetatable({}, {__mode = "k"})
-- Auto-Clone off: the buff clones of a Names/IDs list fold into one state
-- (key ""), as a legacy Aura trigger's Preferred Match does. Among readable
-- active auras the preferred one is kept whole. When none is readable (in
-- combat) the merged state is static and carries every clone's aura IDs, so
-- the native binding (CDMAuraProgress) follows whichever of them is up.
local function PreferredClone(a, b, mode)
  local function Remaining(state)
    local expiration = state.expirationTime
    if type(expiration) ~= "number" or (issecretvalue and issecretvalue(expiration)) then return nil end
    return expiration - GetTime()
  end
  -- First in the list: the clone of the earliest Names/IDs entry.
  if mode ~= "showLowest" and mode ~= "showHighest" then
    return (tonumber(b.index) or math.huge) < (tonumber(a.index) or math.huge) and b or a
  end
  local ra, rb = Remaining(a), Remaining(b)
  if ra == nil then return rb ~= nil and b or a end
  if rb == nil then return a end
  if mode == "showHighest" then return rb > ra and b or a end
  return rb < ra and b or a
end

local function MergeClones(outputs, mode)
  local best, unknown, any = nil, {}, false
  for key, state in pairs(outputs) do
    if key ~= "" then
      any = true
      if state.auraActive == true and state.show then
        best = best and PreferredClone(best, state, mode) or state
      elseif state.auraActive == nil then
        unknown[#unknown + 1] = state
      end
    end
  end
  if not any then return end
  local merged = {}
  if best then
    for field, value in pairs(best) do merged[field] = value end
  elseif #unknown > 0 then
    for field, value in pairs(unknown[1]) do merged[field] = value end
    local ids, renderIDs, seen, seenRender = {}, {}, {}, {}
    for _, state in ipairs(unknown) do
      for _, id in ipairs(type(state.cdmAuraSpellIDs) == "table" and state.cdmAuraSpellIDs or {}) do
        if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
      end
      if state.cdmAuraRenderUnit == merged.cdmAuraRenderUnit then
        for _, id in ipairs(type(state.cdmAuraRenderSpellIDs) == "table" and state.cdmAuraRenderSpellIDs or {}) do
          if not seenRender[id] then seenRender[id] = true; renderIDs[#renderIDs + 1] = id end
        end
      end
    end
    merged.cdmAuraSpellIDs = ids
    if #renderIDs > 0 then merged.cdmAuraRenderSpellIDs = renderIDs end
    -- One clone's timer may belong to an aura that is not up: static progress
    -- hands swipe and countdown to the native binding.
    merged.progressType, merged.durationObject, merged.duration, merged.expirationTime = "static", nil, nil, nil
    merged.value, merged.total, merged.cdmCountdownSource, merged.cdmBarSource = nil, nil, nil, nil
  else
    -- Every clone is readable and none is active: the first one, hidden or
    -- shown as its Show On setting decided.
    for _, state in pairs(outputs) do for field, value in pairs(state) do merged[field] = value end break end
  end
  merged.index = nil
  for key in pairs(outputs) do outputs[key] = nil end
  outputs[""] = merged
end

function Private.ExecEnv.UpdateCDMSelectionList(allstates, queries, event, autoClone, combineMode)
  local outputs = listOutputs[allstates]
  if outputs then wipe(outputs) else outputs = {}; listOutputs[allstates] = outputs end
  local clones = listClones[allstates]
  if not clones then clones = {}; listClones[allstates] = clones end
  for queryIndex, query in ipairs(queries) do
    local selected = Private.ResolveCDMSpell(query, event)
    local temporary = GetOutputs(selected, event, query.showGCD, query.track, query.hideGCDText,
      query.showMode, query.event ~= "Blizzard CDM Item" and query.cdmExact and tonumber(query.cdmSpell) or nil, query.requireTarget, query.use_ignoreSpellKnown)
    local count = 0
    for _ in pairs(temporary) do count = count + 1 end
    for _, state in pairs(temporary) do
      -- Cooldown and item aliases share a clone; buff filters each own their clone.
      local key = tostring(state.cooldownID) .. ":" .. tostring(state.spellId or query.cdmSpell)
      if query.event == "Blizzard CDM Buff" then
        key = query.cdmExact and ("id:" .. tostring(tonumber(query.cdmSpell))) or ("name:" .. (selected.buffName or query.cdmSpell))
        local clone = clones[key]
        if clone then wipe(clone) else clone = {}; clones[key] = clone end
        for field, value in pairs(state) do clone[field] = value end
        clone.index = queryIndex
        state = clone
      end
      -- One entry in the list: the trigger's plain state (key ""), so the
      -- display finds it for conditions and its Active check, as above.
      if #queries == 1 and count == 1 then key = "" end
      if not outputs[key] or not outputs[key].show or state.show then outputs[key] = state end
    end
  end
  if autoClone == false and queries[1] and queries[1].event == "Blizzard CDM Buff" then MergeClones(outputs, combineMode) end
  return CommitStates(allstates, outputs)
end

local function BooleanCondition(field)
  return function(state, needle)
    if not state or not state.show then return false end
    -- Aura Active with a secret aura (in combat): false, so the display takes
    -- the missing look; Blizzard shows the present look over it while the
    -- aura is up (CDMAuraProgress.UpdateSaturation).
    if field == "auraActive" and state[field] == nil and state.cdmBuff and not state.cdmTextPreview then return needle == 0 end
    return state[field] ~= nil and state[field] == (needle == 1)
  end
end

Private.CooldownViewerPrototype = {
  type = "cdm",
  name = L["Cooldown"],
  statesParameter = "full",
  progressType = "timed",
  cooldownViewerProgress = true,
  automaticrequired = true,
  force_events = "PLAYER_ENTERING_WORLD",
  internal_events = {"FA_CDM_REFRESH", "FA_CDM_LAYOUT_CHANGED", "FA_CDM_TARGET_SETTLED"},
  GetNameAndIcon = function(trigger)
    local entries, frames = GetCatalog(), Private.CDMFrames()
    for _, id in ipairs(GetSelections(trigger)) do
      local info = entries[id] and C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
      if info then
        local identity = Private.CDMIdentity(id, entries[id], info, frames[id])
        return identity.name, identity.icon
      end
    end
    return "Cooldown Manager", 134400
  end,
  events = function()
    local events = {"PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_ICON", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED", "PLAYER_TOTEM_UPDATE"}
    if IsAvailable() then
      events[#events + 1] = "COOLDOWN_VIEWER_DATA_LOADED"
      events[#events + 1] = "COOLDOWN_VIEWER_TABLE_HOTFIXED"
      events[#events + 1] = "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED"
    end
    return {events = events, unit_events = {player = {"UNIT_AURA"}, target = {"UNIT_AURA", "UNIT_FACTION", "UNIT_FLAGS"}}}
  end,
  triggerFunction = function(trigger)
    -- Install buff observers when configuring the trigger, before its first activation.
    if trigger.event == "Blizzard CDM Buff" then Private.CDMFrames() end
    if trigger.event == "Blizzard CDM Buff" and (trigger.cdmUseRemaining or trigger.cdmUseStacks or trigger.cdmUseTotal or trigger.cdmUseElapsed) then
      local base = {}
      for key, value in pairs(trigger) do base[key] = value end
      base.cdmUseRemaining, base.cdmUseStacks, base.cdmUseTotal, base.cdmUseElapsed = nil, nil, nil, nil
      local source = Private.CooldownViewerPrototype.triggerFunction(base)
      return ("local update=(function() %s end)()\nlocal rawStates={}\nreturn function(allstates,event) update(rawStates,event); return Private.ExecEnv.UpdateCDMBuffFilters(allstates,rawStates,event,%q,%q,%q,%q,%q,%q,%q,%q) end"):format(source, trigger.cdmUseRemaining and tostring(trigger.cdmRemainingTime or 10) or "", trigger.cdmRemainingOperator or "<", trigger.cdmUseStacks and tostring(trigger.cdmStackCount or 1) or "", trigger.cdmStackOperator or ">=", trigger.cdmUseTotal and tostring(trigger.cdmTotalTime or 10) or "", trigger.cdmTotalOperator or "<", trigger.cdmUseElapsed and tostring(trigger.cdmElapsedTime or 10) or "", trigger.cdmElapsedOperator or ">=")
    end
    -- The Cooldown trigger's Remaining Time / Charges filters wrap its states.
    -- Remaining Time is out of sight and out of use with Show: Not on
    -- Cooldown (a ready spell has nothing to measure), as on the spell trigger.
    local useRemaining = trigger.cdmUseRemaining and trigger.cdmShow ~= "ready"
    if trigger.event == "Blizzard Cooldown Manager" and (useRemaining or trigger.cdmUseCharges or trigger.cdmUseSpellCount) then
      local base = {}
      for key, value in pairs(trigger) do base[key] = value end
      base.cdmUseRemaining, base.cdmUseCharges, base.cdmUseSpellCount = nil, nil, nil
      local source = Private.CooldownViewerPrototype.triggerFunction(base)
      return ("local update=(function() %s end)()\nlocal rawStates={}\nreturn function(allstates,event) update(rawStates,event); return Private.ExecEnv.UpdateCDMCooldownFilters(allstates,rawStates,event,%q,%q,%q,%q,%q,%q) end"):format(source,
        useRemaining and tostring(trigger.cdmRemainingTime or 10) or "", trigger.cdmRemainingOperator or "<",
        trigger.cdmUseCharges and tostring(trigger.cdmChargeCount or 1) or "", trigger.cdmChargeOperator or ">=",
        trigger.cdmUseSpellCount and tostring(trigger.cdmSpellCount or 1) or "", trigger.cdmSpellCountOperator or ">=")
    end
    local queries = Private.CDMSpellQueries(trigger)
    if queries then
      local serialized = {}
      for _, query in ipairs(queries) do
        serialized[#serialized + 1] = ("{type='cdm',event=%q,cdmSelection='spell',cdmSpell=%q,cdmExact=%s,cdmItemExact=%s,use_ignoreSpellKnown=%s,showGCD=%s,track=%q,hideGCDText=%s,showMode=%q,requireTarget=%s}"):format(
          query.event, query.cdmSpell, tostring(query.cdmExact), tostring(query.cdmItemExact), tostring(query.use_ignoreSpellKnown == true),
          tostring(query.showGCD), query.track, tostring(query.hideGCDText), query.showMode, tostring(query.requireTarget))
      end
      -- Auto-Clone (buffs): unset means clones, as before the option existed.
      return ("local queries={%s}\nreturn function(allstates,event) return Private.ExecEnv.UpdateCDMSelectionList(allstates,queries,event,%s,%q) end"):format(table.concat(serialized, ","),
        tostring(not (trigger.event == "Blizzard CDM Buff" and trigger.cdmAutoClone == false)), trigger.cdmCombineMode or "showLowest")
    end
    if trigger.type == "cdm" then trigger.cdmSource = trigger.event == "Blizzard CDM Buff" and "buff" or "cooldown" end
    if trigger.cdmSpell ~= nil and tostring(trigger.cdmSpell):find("%S") and trigger.event ~= "Blizzard CDM Item" then
      return ("local config = {type=%q,event=%q,cdmSelection=%q,cdmSpell=%q, cdmExact=%s, cdmSource=%q, showGCD=%s, track=%q, hideGCDText=%s, showMode=%q, requireTarget=%s, use_ignoreSpellKnown=%s}\nreturn function(allstates,event,...) return Private.ExecEnv.UpdateCDMSpell(allstates,config,event,...) end"):format(trigger.type or "", trigger.event or "", trigger.cdmSelection or "", trigger.cdmSpell, tostring(trigger.cdmExact == true), trigger.cdmSource or "cooldown", tostring(trigger.use_cdmShowGCD == true), trigger.cdmTrack or "auto", tostring(trigger.cdmHideGCDText ~= false), trigger.cdmSource == "buff" and (trigger.cdmBuffShow or "active") or (trigger.cdmShow or "always"), tostring(trigger.cdmSource == "buff" and trigger.cdmRequireTarget == true), tostring(trigger.use_ignoreSpellKnown == true))
    end
    local selected = {}
    for key, enabled in pairs(trigger.cdmSpells and trigger.cdmSpells.multi or {}) do
      local id = tonumber(key)
      if enabled and id then selected[#selected + 1] = ("[%d]=true"):format(id) end
    end
    return ("local config={type='cdm',event=%q,cdmSpells={multi={%s}}}\nreturn function(allstates,event,...) local selected=Private.ExecEnv.GetCDMPickerSelections(config,event); return Private.ExecEnv.UpdateCooldownViewerStates(allstates,selected,event,%s,%q,%s,%q,nil,%s,%s) end"):format(trigger.event or "Blizzard Cooldown Manager", table.concat(selected, ","), tostring(trigger.use_cdmShowGCD == true), trigger.cdmTrack or "auto", tostring(trigger.cdmHideGCDText ~= false), trigger.event == "Blizzard CDM Buff" and (trigger.cdmBuffShow or "active") or (trigger.cdmShow or "always"), tostring(trigger.event == "Blizzard CDM Buff" and trigger.cdmRequireTarget == true), tostring(trigger.use_ignoreSpellKnown == true))
  end,
  args = {
    {
      name = "cdmSpells",
      display = L["Cooldown Manager entries"],
      type = "multiselect",
      required = true,
      multiNoSingle = true,
      sorted = true,
      values = GetValues,
    },
    {
      name = "cdmShowGCD",
      display = L["Include global cooldown"],
      type = "toggle",
    },
    {
      name = "spellId",
      display = L["Spell ID"],
      hidden = true,
      conditionType = "number",
      operator_types = "only_equal",
    },
    {
      name = "name",
      display = L["Spell Name"],
      hidden = true,
      conditionType = "string",
    },
    {
      name = "onCooldown",
      display = L["On Cooldown"],
      hidden = true,
      conditionType = "bool",
      conditionTest = BooleanCondition("onCooldown"),
    },
    {
      name = "isReady",
      display = L["Is Ready"],
      hidden = true,
      conditionType = "bool",
      conditionTest = BooleanCondition("isReady"),
    },
    {
      name = "recharging",
      display = L["Recharging"],
      hidden = true,
      conditionType = "bool",
      conditionTest = BooleanCondition("recharging"),
    },
  },
}

for _, field in ipairs({{"itemId", L["Item ID"], "number"}, {"cdmCategory", L["CDM Category"], "string"}, {"cdmDisplayed", L["Displayed in CDM"], "bool"}, {"auraActive", L["Aura Active"], "bool"}, {"hasTimer", L["Timer Available"], "bool"}}) do
  local arg = {name = field[1], display = field[2], conditionType = field[3], hidden = true}
  if field[3] == "bool" then arg.conditionTest = BooleanCondition(field[1]) end
  if field[3] == "number" then arg.operator_types = "only_equal" end
  table.insert(Private.CooldownViewerPrototype.args, arg)
end

if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
    catalog = nil
    C_Timer.After(0, function()
      if Private.ScanEvents then Private.ScanEvents("FA_CDM_LAYOUT_CHANGED") end
    end)
  end, Private.CooldownViewerPrototype)
end

Private.CooldownViewerBuffPrototype = {}
for key, value in pairs(Private.CooldownViewerPrototype) do Private.CooldownViewerBuffPrototype[key] = value end
Private.CooldownViewerBuffPrototype.name = L["Buff/Debuff"]

local buffArgs, cooldownArgs = {}, {}
for _, arg in ipairs(Private.CooldownViewerPrototype.args) do
  if arg.name ~= "hasTimer" then
    -- A Buff/Debuff trigger's conditions are about its aura: the cooldown
    -- checks, the item ID and the CDM bookkeeping (category, displayed) are
    -- left to the spell and item triggers.
    if arg.name ~= "onCooldown" and arg.name ~= "isReady" and arg.name ~= "recharging" and arg.name ~= "cdmShowGCD"
        and arg.name ~= "itemId" and arg.name ~= "cdmCategory" and arg.name ~= "cdmDisplayed" then
      buffArgs[#buffArgs + 1] = arg
    end
    -- The Cooldown trigger's conditions follow the spell Cooldown trigger's
    -- set: the CDM bookkeeping (category, displayed, timer available) is
    -- left out, and Item ID belongs to the item trigger.
    if arg.name ~= "auraActive" and arg.name ~= "cdmCategory" and arg.name ~= "cdmDisplayed" and arg.name ~= "hasTimer" and arg.name ~= "itemId" then
      cooldownArgs[#cooldownArgs + 1] = arg
    end
  end
end
Private.CooldownViewerBuffPrototype.args = buffArgs
local function BuffRemainingTime(state)
  if not state or not state.show or not state.cdmBuff or state.auraActive ~= true then return end
  local remaining, timeScale = nil, 1
  if state.durationObject then
    local total = state.durationObject:GetTotalDuration()
    if not IsReadable(total) or type(total) ~= "number" or total <= 0 then return end
    remaining = state.durationObject:GetRemainingDuration()
  else
    local duration, expiration, rate = state.duration, state.expirationTime, state.modRate
    if not IsReadable(duration) or not IsReadable(expiration) or not IsReadable(rate) then return end
    if type(duration) ~= "number" or duration <= 0 or type(expiration) ~= "number" then return end
    rate = rate or 1
    if type(rate) ~= "number" or rate <= 0 then return end
    remaining = (expiration - GetTime()) / rate
    timeScale = rate
  end
  if IsReadable(remaining) and type(remaining) == "number" and remaining == remaining and remaining < math.huge then
    return math.max(0, remaining), timeScale
  end
end
local remainingCondition = {
  name = "cdmRemaining",
  display = L["Remaining Time"],
  hidden = true,
  conditionType = "number",
  noProgressSource = true,
  conditionTest = function(state, value, op)
    local remaining = BuffRemainingTime(state)
    value = tonumber(value)
    if remaining == nil or not value then return false end
    if op == "<" then return remaining < value
    elseif op == "<=" then return remaining <= value
    elseif op == ">" then return remaining > value
    elseif op == ">=" then return remaining >= value
    elseif op == "==" then return math.abs(remaining - value) < 0.05
    elseif op == "~=" then return math.abs(remaining - value) >= 0.05 end
    return false
  end,
  conditionRecheckTime = function(state, value)
    local remaining, timeScale = BuffRemainingTime(state)
    value = tonumber(value)
    if not remaining or remaining <= 0 or not value then return end
    local delay = remaining * timeScale
    for _, boundary in ipairs({value + 0.05, value, value - 0.05}) do
      if boundary >= 0 and remaining >= boundary then
        delay = math.min(delay, (remaining - boundary) * timeScale + 0.001)
      end
    end
    return GetTime() + math.max(0.001, delay)
  end,
}
buffArgs[#buffArgs + 1] = remainingCondition
local remainingWakeups = setmetatable({}, {__mode = "k"})
local function BuffStacksMatch(state, value, op)
  local stacks = state.stacks
  if state.auraActive ~= true or not IsReadable(stacks) or type(stacks) ~= "number" then return false end
  if op == "<" then return stacks < value
  elseif op == "<=" then return stacks <= value
  elseif op == ">" then return stacks > value
  elseif op == ">=" then return stacks >= value
  elseif op == "==" then return stacks == value
  elseif op == "~=" then return stacks ~= value end
  return false
end
local function BuffTimeValue(state, elapsed)
  if not state.show or not state.cdmBuff or state.auraActive ~= true then return end
  local total, value, timeScale = nil, nil, 1
  if state.durationObject then
    total = state.durationObject:GetTotalDuration()
    if not IsReadable(total) or type(total) ~= "number" or total <= 0 or total >= math.huge then return end
    if elapsed then value = state.durationObject:GetElapsedDuration()
    else value = total end
  else
    total, timeScale = state.duration, state.modRate
    if not IsReadable(total) or not IsReadable(timeScale) then return end
    timeScale = timeScale or 1
    if type(total) ~= "number" or total <= 0 or total >= math.huge then return end
    if type(timeScale) ~= "number" or timeScale <= 0 or timeScale >= math.huge then return end
    value = total / timeScale
    if elapsed then
      local expiration = state.expirationTime
      if not IsReadable(expiration) or type(expiration) ~= "number" then return end
      value = (GetTime() - (expiration - total)) / timeScale
    end
  end
  if IsReadable(value) and type(value) == "number" and value == value and value < math.huge then
    return math.max(0, value), timeScale
  end
end
-- Elapsed Time as a condition variable, like Remaining Time: evaluated here
-- while the aura is readable; in combat a native gate on the timer slot
-- draws its Glow changes (CDMAuraProgress, ElapsedDuration).
local elapsedCondition = {
  name = "cdmElapsed",
  display = L["Elapsed Time"],
  hidden = true,
  conditionType = "number",
  noProgressSource = true,
  conditionTest = function(state, value, op)
    local elapsed = BuffTimeValue(state, true)
    value = tonumber(value)
    if elapsed == nil or not value then return false end
    if op == "<" then return elapsed < value
    elseif op == "<=" then return elapsed <= value
    elseif op == ">" then return elapsed > value
    elseif op == ">=" then return elapsed >= value
    elseif op == "==" then return math.abs(elapsed - value) < 0.05
    elseif op == "~=" then return math.abs(elapsed - value) >= 0.05 end
    return false
  end,
  conditionRecheckTime = function(state, value)
    local elapsed, timeScale = BuffTimeValue(state, true)
    local remaining = BuffRemainingTime(state)
    value = tonumber(value)
    if not elapsed or not remaining or remaining <= 0 or not value then return end
    local delay = remaining * timeScale
    for _, boundary in ipairs({value - 0.05, value, value + 0.05}) do
      if boundary >= 0 and elapsed <= boundary then
        delay = math.min(delay, (boundary - elapsed) * timeScale + 0.001)
      end
    end
    return GetTime() + math.max(0.001, delay)
  end,
}
buffArgs[#buffArgs + 1] = elapsedCondition
-- Stack Count as a condition variable: the aura's applications while they
-- are readable (in combat a native gate on the timer slot draws its Glow
-- changes, CDMAuraProgress).
buffArgs[#buffArgs + 1] = {
  name = "stacks",
  display = L["Stack Count"],
  hidden = true,
  conditionType = "number",
  noProgressSource = true,
  conditionTest = function(state, value, op)
    value = tonumber(value)
    if not value then return false end
    return BuffStacksMatch(state, value, op)
  end,
}
local function BuffTimeMatches(value, threshold, op)
  if value == nil then return false end
  if op == "<" then return value < threshold
  elseif op == "<=" then return value <= threshold
  elseif op == ">" then return value > threshold
  elseif op == ">=" then return value >= threshold end
  return false
end
local filterOutputs = setmetatable({}, {__mode = "k"})
function Private.ExecEnv.UpdateCDMBuffFilters(allstates, rawStates, event, value, op, stackValue, stackOp, totalValue, totalOp, elapsedValue, elapsedOp)
  value, stackValue = tonumber(value), tonumber(stackValue)
  totalValue, elapsedValue = tonumber(totalValue), tonumber(elapsedValue)
  local outputs = filterOutputs[rawStates]
  if not outputs then outputs = {}; filterOutputs[rawStates] = outputs end
  for key in pairs(outputs) do
    if not rawStates[key] then outputs[key] = nil end
  end
  local nextCheck
  for key, state in pairs(rawStates) do
    local output = outputs[key]
    if output then wipe(output) else output = {} end
    for field, entry in pairs(state) do output[field] = entry end
    if event ~= "OPTIONS" then
      -- A value the filter cannot read (in combat: the aura's presence may be
      -- known from Blizzard's viewer item while its times and stacks are
      -- secret, or the presence itself is secret): the state stays and the
      -- native gate decides what is seen (CDMAuraProgress, cdmNativeRemaining),
      -- as the Modern trigger's Remaining Time does. Readable values decide
      -- here. Total Duration has no native gate and stays readable-only.
      local maybeUp = state.show and state.cdmBuff and state.auraActive ~= false and not state.cdmTextPreview and not state.cdmAuraTotem
      if value then
        if maybeUp and BuffRemainingTime(state) == nil then
          output.cdmNativeRemaining = true
        else
          output.show = state.show and remainingCondition.conditionTest(state, value, op) or false
          local nextTime = remainingCondition.conditionRecheckTime(state, value)
          if nextTime and (not nextCheck or nextTime < nextCheck) then nextCheck = nextTime end
        end
      end
      if stackValue then
        local stacksUnknown = not IsReadable(state.stacks) or type(state.stacks) ~= "number"
        if maybeUp and stacksUnknown and Private.CDMNativeStackGate and Private.CDMNativeStackGate(stackOp, stackValue) then output.cdmNativeRemaining = true
        else output.show = output.show and BuffStacksMatch(state, stackValue, stackOp) or false end
      end
      local secret = maybeUp and BuffTimeValue(state, true) == nil
      if totalValue then output.show = output.show and BuffTimeMatches(BuffTimeValue(state), totalValue, totalOp) or false end
      if elapsedValue and secret then
        output.cdmNativeRemaining = true
      elseif elapsedValue then
        local elapsed, timeScale = BuffTimeValue(state, true)
        output.show = output.show and BuffTimeMatches(elapsed, elapsedValue, elapsedOp) or false
        local remaining = BuffRemainingTime(state)
        if elapsed and remaining and remaining > 0 and elapsed <= elapsedValue then
          local delay = math.min((elapsedValue - elapsed) * timeScale + 0.001, remaining * timeScale)
          local nextTime = GetTime() + math.max(0.001, delay)
          if not nextCheck or nextTime < nextCheck then nextCheck = nextTime end
        end
      end
    end
    outputs[key] = output
  end
  local pending = remainingWakeups[rawStates]
  if not pending or pending.at ~= nextCheck then
    if pending and pending.timer and pending.timer.Cancel then pending.timer:Cancel() end
    remainingWakeups[rawStates] = nil
    if nextCheck then
      local wakeup = {at = nextCheck}
      remainingWakeups[rawStates] = wakeup
      local function Refresh()
        if remainingWakeups[rawStates] == wakeup then
          remainingWakeups[rawStates] = nil
          Private.QueueCDMRefresh()
        end
      end
      local delay = math.max(0.001, nextCheck - GetTime())
      if C_Timer.NewTimer then wakeup.timer = C_Timer.NewTimer(delay, Refresh)
      else C_Timer.After(delay, Refresh) end
    end
  end
  return CommitStates(allstates, outputs)
end

-- The time left on a cooldown state, in seconds, with the time scale of its
-- ticking (1 unless the timer runs at a mod rate); nil when unreadable or
-- not on cooldown.
local function CooldownRemainingTime(state)
  if not state or not state.show or state.cdmBuff then return end
  if state.progressType == "durationObject" and state.durationObject then
    local remaining = state.durationObject:GetRemainingDuration()
    if IsReadable(remaining) and type(remaining) == "number" and remaining == remaining and remaining < math.huge then return math.max(0, remaining), 1 end
    return
  end
  local duration, expiration, rate = state.duration, state.expirationTime, state.modRate
  if not IsReadable(duration) or not IsReadable(expiration) or not IsReadable(rate) then return end
  if type(duration) ~= "number" or duration <= 0 or type(expiration) ~= "number" or expiration == math.huge then return end
  rate = rate or 1
  if type(rate) ~= "number" or rate <= 0 then return end
  return math.max(0, (expiration - GetTime()) / rate), rate
end
local function Compare(value, threshold, op)
  if value == nil or threshold == nil then return false end
  if op == "<" then return value < threshold
  elseif op == "<=" then return value <= threshold
  elseif op == ">" then return value > threshold
  elseif op == ">=" then return value >= threshold
  elseif op == "==" then return value == threshold
  elseif op == "~=" then return value ~= threshold end
  return false
end
-- Conditions as on the spell Cooldown trigger: Charges, Spell Count and
-- Remaining Time here; Spell Usable, Insufficient Resources and Spell In
-- Range are added with the spell-only arguments below (spellArgs).
cooldownArgs[#cooldownArgs + 1] = {
  name = "stacks",
  display = L["Charges"],
  hidden = true,
  conditionType = "number",
  noProgressSource = true,
  conditionTest = function(state, value, op)
    value = tonumber(value)
    if not state or not state.show or not value or not IsReadable(state.stacks) or type(state.stacks) ~= "number" then return false end
    return Compare(state.stacks, value, op)
  end,
}
cooldownArgs[#cooldownArgs + 1] = {
  name = "spellCount",
  display = L["Spell Count"],
  hidden = true,
  conditionType = "number",
  noProgressSource = true,
  conditionTest = function(state, value, op)
    value = tonumber(value)
    if not state or not state.show or not value or type(state.spellCount) ~= "number" then return false end
    return Compare(state.spellCount, value, op)
  end,
  conditionEvents = {"SPELL_UPDATE_USABLE", "BAG_UPDATE", "SPELL_UPDATE_CHARGES"},
}
cooldownArgs[#cooldownArgs + 1] = {
  name = "cdmRemaining",
  display = L["Remaining Time"],
  hidden = true,
  conditionType = "number",
  noProgressSource = true,
  conditionTest = function(state, value, op)
    value = tonumber(value)
    local remaining = CooldownRemainingTime(state)
    if remaining == nil or not value then return false end
    if op == "==" then return math.abs(remaining - value) < 0.05
    elseif op == "~=" then return math.abs(remaining - value) >= 0.05 end
    return Compare(remaining, value, op)
  end,
  conditionRecheckTime = function(state, value)
    local remaining, timeScale = CooldownRemainingTime(state)
    value = tonumber(value)
    if not remaining or remaining <= 0 or not value then return end
    local delay = remaining * timeScale
    for _, boundary in ipairs({value + 0.05, value, value - 0.05}) do
      if boundary >= 0 and remaining >= boundary then delay = math.min(delay, (remaining - boundary) * timeScale + 0.001) end
    end
    return GetTime() + math.max(0.001, delay)
  end,
}
-- The Cooldown trigger's Remaining Time and Charges filters, as on the spell
-- Cooldown trigger: a state outside the filter is hidden; a time filter
-- re-evaluates itself when the time crosses the threshold.
local cooldownWakeups = setmetatable({}, {__mode = "k"})
local cooldownFilterOutputs = setmetatable({}, {__mode = "k"})
function Private.ExecEnv.UpdateCDMCooldownFilters(allstates, rawStates, event, remainingValue, remainingOp, chargeValue, chargeOp, countValue, countOp)
  remainingValue, chargeValue, countValue = tonumber(remainingValue), tonumber(chargeValue), tonumber(countValue)
  local outputs = cooldownFilterOutputs[rawStates]
  if not outputs then outputs = {}; cooldownFilterOutputs[rawStates] = outputs end
  for key in pairs(outputs) do
    if not rawStates[key] then outputs[key] = nil end
  end
  local nextCheck
  for key, state in pairs(rawStates) do
    local output = outputs[key]
    if output then wipe(output) else output = {} end
    for field, entry in pairs(state) do output[field] = entry end
    if event ~= "OPTIONS" and state.show then
      if remainingValue then
        local remaining, timeScale = CooldownRemainingTime(state)
        -- As on the spell trigger, a ready spell has 0 seconds left: with
        -- Show: Always, "< X" shows a ready spell and its last X seconds,
        -- "> X" only a longer cooldown. An unreadable time is left shown.
        if remaining == nil and state.onCooldown == false then remaining, timeScale = 0, 1 end
        if remaining ~= nil then
          output.show = Compare(remaining, remainingValue, remainingOp)
          if remaining > 0 then
            local delay = remaining * timeScale
            for _, boundary in ipairs({remainingValue + 0.001, remainingValue, remainingValue - 0.001}) do
              if boundary >= 0 and remaining >= boundary then delay = math.min(delay, (remaining - boundary) * timeScale + 0.001) end
            end
            local nextTime = GetTime() + math.max(0.001, delay)
            if not nextCheck or nextTime < nextCheck then nextCheck = nextTime end
          end
        end
      end
      if chargeValue and output.show then
        if IsReadable(state.stacks) and type(state.stacks) == "number" then output.show = Compare(state.stacks, chargeValue, chargeOp)
        else output.show = false end
      end
      if countValue and output.show then
        output.show = type(state.spellCount) == "number" and Compare(state.spellCount, countValue, countOp) or false
      end
    end
    outputs[key] = output
  end
  local pending = cooldownWakeups[rawStates]
  if not pending or pending.at ~= nextCheck then
    if pending and pending.timer and pending.timer.Cancel then pending.timer:Cancel() end
    cooldownWakeups[rawStates] = nil
    if nextCheck then
      local wakeup = {at = nextCheck}
      cooldownWakeups[rawStates] = wakeup
      local function Refresh()
        if cooldownWakeups[rawStates] == wakeup then
          cooldownWakeups[rawStates] = nil
          Private.QueueCDMRefresh()
        end
      end
      local delay = math.max(0.001, nextCheck - GetTime())
      if C_Timer.NewTimer then wakeup.timer = C_Timer.NewTimer(delay, Refresh)
      else C_Timer.After(delay, Refresh) end
    end
  end
  return CommitStates(allstates, outputs)
end
Private.CooldownViewerPrototype.args = cooldownArgs

Private.ExecEnv.GetCDMPickerSelections = Private.GetCDMPickerSelections
Private.CooldownViewerUtilityPrototype = {}
Private.CooldownViewerItemPrototype = {}
for key, value in pairs(Private.CooldownViewerPrototype) do
  Private.CooldownViewerUtilityPrototype[key] = value
  Private.CooldownViewerItemPrototype[key] = value
end
-- Support imports that are inspected before migration.
Private.CooldownViewerUtilityPrototype.name = L["Cooldown"]
Private.CooldownViewerItemPrototype.name = L["Item"]
local spellArgs = {}
for i, arg in ipairs(Private.CooldownViewerPrototype.args) do spellArgs[i] = arg end
spellArgs[#spellArgs + 1] = {name = "inRange", display = L["Spell In Range"], hidden = true,
  conditionType = "bool", conditionTest = BooleanCondition("inRange")}
-- Only spell cooldown triggers expose usability and resource checks; item and aura triggers retain their conditions.
spellArgs[#spellArgs + 1] = {name = "isUsable", display = L["Spell Usable"], hidden = true,
  conditionType = "bool", conditionTest = BooleanCondition("isUsable")}
spellArgs[#spellArgs + 1] = {name = "insufficientResources", display = L["Insufficient Resources"], hidden = true,
  conditionType = "bool", conditionTest = BooleanCondition("insufficientResources")}
Private.CooldownViewerPrototype.args = spellArgs
Private.CooldownViewerUtilityPrototype.args = spellArgs
-- Resource, stance and reactive-action changes can occur without a cooldown change.
local cooldownEvents = Private.CooldownViewerPrototype.events
local function SpellCooldownEvents()
  local result = cooldownEvents()
  for _, event in ipairs({"ACTIONBAR_UPDATE_USABLE", "ACTION_USABLE_CHANGED", "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM"}) do
    result.events[#result.events + 1] = event
  end
  return result
end
Private.CooldownViewerPrototype.events = SpellCooldownEvents
Private.CooldownViewerUtilityPrototype.events = SpellCooldownEvents
-- Item metadata events only update item triggers; they do not change the catalog.
Private.CooldownViewerItemPrototype.events = function()
  local result = cooldownEvents()
  result.events[#result.events + 1] = "GET_ITEM_INFO_RECEIVED"
  result.events[#result.events + 1] = "ITEM_DATA_LOAD_RESULT"
  return result
end
