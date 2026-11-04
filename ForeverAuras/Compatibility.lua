-- Modified for ForeverAuras, 2026-10-23.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
-- This file is only for base functions that work differently or are deprecated in some versions of wow

if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

if GetSpellInfo then
  Private.ExecEnv.GetSpellInfo = GetSpellInfo
  Private.ExecEnv.GetSpellName = GetSpellInfo
else
  Private.ExecEnv.GetSpellInfo = function(spellID)
    if not spellID then
      return nil
    end
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo then
      return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange, spellInfo.spellID, spellInfo.originalIconID
    end
  end
  Private.ExecEnv.GetSpellName = C_Spell.GetSpellName
end

-- Spell name and info lookups are slow on this client and are repeated by
-- every cooldown trigger on each update. Results are cached until the
-- player's spells change (a name can then resolve to another rank).
do
  local infoCache, nameCache = {}, {}
  local GetSpellInfoRaw, GetSpellNameRaw = Private.ExecEnv.GetSpellInfo, Private.ExecEnv.GetSpellName
  local function Cacheable(key)
    return (type(key) == "number" or type(key) == "string") and not issecretvalue(key)
  end
  Private.ExecEnv.GetSpellInfo = function(spell)
    if not Cacheable(spell) then return GetSpellInfoRaw(spell) end
    local entry = infoCache[spell]
    if entry == nil then
      entry = {GetSpellInfoRaw(spell)}
      entry.n = 8
      -- A miss is not cached: spell data loads lazily on this client, and a
      -- spell asked for before its data arrived answered nil once, not for good.
      if entry[1] ~= nil then infoCache[spell] = entry end
    end
    return entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7], entry[8]
  end
  Private.ExecEnv.GetSpellName = function(spell)
    if not Cacheable(spell) then return GetSpellNameRaw(spell) end
    local name = nameCache[spell]
    if name == nil then
      name = GetSpellNameRaw(spell)
      -- A miss is not cached (see GetSpellInfo above).
      if name ~= nil then nameCache[spell] = name end
    end
    return name
  end
  local invalidate = CreateFrame("Frame")
  -- Registered one by one in protected calls: an event unknown to this client
  -- must not abort the rest of this file.
  for _, event in ipairs({"SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED"}) do
    pcall(invalidate.RegisterEvent, invalidate, event)
  end
  invalidate:SetScript("OnEvent", function()
    wipe(infoCache)
    wipe(nameCache)
  end)
end

if GetSpellTexture then
  Private.ExecEnv.GetSpellIcon = GetSpellTexture
else
  Private.ExecEnv.GetSpellIcon = C_Spell.GetSpellTexture
end

if IsUsableSpell then
  Private.ExecEnv.IsUsableSpell = IsUsableSpell
else
  Private.ExecEnv.IsUsableSpell = C_Spell.IsSpellUsable
end

-- Queued Action uses the supported spell API; unreadable results never enter trigger logic.
function Private.ExecEnv.IsQueuedSpell(spell)
  local query = tonumber(spell) or spell
  if query == nil or query == "" or query == 0 then return false end
  local current = C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
  if not current then return false end
  local value = current(query)
  if issecretvalue and issecretvalue(value) then return false end
  return type(value) == "boolean" and value or false
end

if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
  Private.ExecEnv.GetSpecialization = C_SpecializationInfo.GetSpecialization
else
  Private.ExecEnv.GetSpecialization = GetSpecialization
end
if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
  Private.ExecEnv.GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo
else
  Private.ExecEnv.GetSpecializationInfo = GetSpecializationInfo
end
if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
  Private.ExecEnv.GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID
else
  Private.ExecEnv.GetNumSpecializationsForClassID = GetNumSpecializationsForClassID
end
do
  Private.ExecEnv.GetSpecializationInfoForClassID = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID) or GetSpecializationInfoForClassID
end

if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
  do
    -- Adapt Blizzard's deprecated talent query to the tuple expected by the trigger engine.
    Private.ExecEnv.GetTalentInfo = function(tabIndex, talentIndex, isInspect, isPet, groupIndex)
      -- Note: tabIndex, talentIndex, and isPet are not supported parameters in 5.5.x and onward.
      local numColumns = 3
      local talentInfoQuery = {}
      talentInfoQuery.tier = math.ceil(talentIndex / numColumns)
      talentInfoQuery.column = talentIndex % numColumns
      talentInfoQuery.groupIndex = groupIndex
      talentInfoQuery.isInspect = isInspect
      talentInfoQuery.target = nil
      local talentInfo = C_SpecializationInfo.GetTalentInfo(talentInfoQuery)
      if not talentInfo then
        return nil
      end

      -- Note: rank, maxRank, meetsPrereq, previewRank, meetsPreviewPrereq, isExceptional, and hasGoldBorder are not supported outputs in 5.5.x and onward.
      -- They have default values not reflective of actual system state.
      -- selected, available, spellID, isPVPTalentUnlocked, known, and grantedByAura are new supported outputs in 5.5.x and onward.
      return talentInfo.name, talentInfo.icon, talentInfo.tier, talentInfo.column, talentInfo.selected and talentInfo.rank or 0,
        talentInfo.maxRank, talentInfo.meetsPrereq, talentInfo.previewRank,
        talentInfo.meetsPreviewPrereq, talentInfo.isExceptional, talentInfo.hasGoldBorder,
        talentInfo.talentID
    end
  end
else
  Private.ExecEnv.GetTalentInfo = GetTalentInfo
end

Private.ExecEnv.GetNumFactions = C_Reputation.GetNumFactions or GetNumFactions

Private.ExecEnv.GetFactionDataByIndex = C_Reputation.GetFactionDataByIndex or function(index)
  local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canSetInactive = GetFactionInfo(index)
  return {
    factionID = factionID,
    name = name,
    description = description,
    reaction = standingID,
    currentReactionThreshold = barMin,
    nextReactionThreshold = barMax,
    currentStanding = barValue,
    atWarWith = atWarWith,
    canToggleAtWar = canToggleAtWar,
    isChild = isChild,
    isHeader = isHeader,
    isHeaderWithRep = hasRep,
    isCollapsed = isCollapsed,
    isWatched = isWatched,
    hasBonusRepGain = hasBonusRepGain,
    canSetInactive = canSetInactive,
    isAccountWide = nil
  }
end

Private.ExecEnv.GetFactionDataByID = C_Reputation.GetFactionDataByID or function(ID)
  local name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canSetInactive = GetFactionInfoByID(ID)
  return {
    factionID = factionID,
    name = name,
    description = description,
    reaction = standingID,
    currentReactionThreshold = barMin,
    nextReactionThreshold = barMax,
    currentStanding = barValue,
    atWarWith = atWarWith,
    canToggleAtWar = canToggleAtWar,
    isChild = isChild,
    isHeader = isHeader,
    isHeaderWithRep = hasRep,
    isCollapsed = isCollapsed,
    isWatched = isWatched,
    hasBonusRepGain = hasBonusRepGain,
    canSetInactive = canSetInactive,
    isAccountWide = nil
  }
end

-- GetWatchedFactionData behaves differentlly, but we only need the Id, so do a trival wrapper
if C_Reputation.GetWatchedFactionData then
  Private.ExecEnv.GetWatchedFactionId = function()
    local data = C_Reputation.GetWatchedFactionData()
    return data and data.factionID or nil
  end
else
  Private.ExecEnv.GetWatchedFactionId = function()
    return select(6, GetWatchedFactionInfo())
  end
end

Private.ExecEnv.ExpandFactionHeader = C_Reputation.ExpandFactionHeader or ExpandFactionHeader
Private.ExecEnv.CollapseFactionHeader = C_Reputation.CollapseFactionHeader or CollapseFactionHeader
Private.ExecEnv.AreLegacyReputationsShown = C_Reputation.AreLegacyReputationsShown or function() return true end
Private.ExecEnv.GetReputationSortType = C_Reputation.GetReputationSortType or function() return 0 end;

local lastUnitIsUnit = {}
function Private.ExecEnv.UnitIsUnit(unit1, unit2)
  if hasanysecretvalues(unit1, unit2) then
    return false
  end
  local res = UnitIsUnit(unit1, unit2)
  local key = type(unit1) == "string" and type(unit2) == "string" and unit1 .. "\0" .. unit2
  if issecretvalue(res) then
    return key and lastUnitIsUnit[key] or false
  end
  if key then lastUnitIsUnit[key] = res end
  return res
end

function Private.ExecEnv.UnitName(unit)
  if not unit then
    return nil
  end
  local name, surname = UnitName(unit)
  if hasanysecretvalues(name, surname) or not name then return nil end
  -- Forever returns party members' surnames separately; the player's name is already complete.
  if surname and surname ~= "" then return name .. " " .. surname end
  return name
end

function Private.ExecEnv.UnitFullName(unit)
  return Private.ExecEnv.UnitName(unit), select(2, UnitFullName("player"))
end
