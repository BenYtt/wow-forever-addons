-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Player-only load conditions inferred from learned final-tier talent spells.
-- Catalog: Forever beta data from talentsforever.com and Wowhead talent records.
-- See SpecializationData-LICENSE.txt for sources and attribution.
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Keys describe talent trees, not retail specialization IDs. Include every known
-- rank so learning a higher rank cannot stop an existing aura from loading.
local specializations = {
  {"WARRIOR_ARMS", "WARRIOR", "Arms", "ability_rogue_eviscerate", {12294, 21551, 21552, 21553}}, -- Mortal Strike
  {"WARRIOR_FURY", "WARRIOR", "Fury", "ability_warrior_innerrage", {23881, 23892, 23893, 23894}}, -- Bloodthirst
  {"WARRIOR_PROTECTION", "WARRIOR", "Protection", "ability_warrior_defensivestance", {23922, 23923, 23924, 23925}}, -- Shield Slam
  {"PALADIN_HOLY", "PALADIN", "Holy", "spell_holy_holybolt", {1310911, 1311590, 1311595}}, -- Light's Vigil
  {"PALADIN_PROTECTION", "PALADIN", "Protection", "spell_holy_devotionaura", {20925, 20927, 20928}}, -- Holy Shield
  {"PALADIN_RETRIBUTION", "PALADIN", "Retribution", "spell_holy_auraoflight", {1310735}}, -- Twist of Light
  {"HUNTER_BEAST_MASTERY", "HUNTER", "Beast Mastery", "ability_hunter_beasttaming", {19574}}, -- Bestial Wrath
  {"HUNTER_MARKSMANSHIP", "HUNTER", "Marksmanship", "ability_marksmanship", {1310687, 1310785, 1310786}}, -- Sniper Shot
  {"HUNTER_SURVIVAL", "HUNTER", "Survival", "ability_hunter_swiftstrike", {1310533}}, -- Lacerating Strikes
  {"ROGUE_ASSASSINATION", "ROGUE", "Assassination", "ability_rogue_eviscerate", {1310703}}, -- Venom
  {"ROGUE_COMBAT", "ROGUE", "Combat", "ability_backstab", {13750}}, -- Adrenaline Rush
  {"ROGUE_SUBTLETY", "ROGUE", "Subtlety", "ability_stealth", {1310721}}, -- Thousand Cuts
  {"PRIEST_DISCIPLINE", "PRIEST", "Discipline", "spell_holy_wordfortitude", {10060}}, -- Power Infusion
  {"PRIEST_HOLY", "PRIEST", "Holy", "spell_holy_holybolt", {401859, 1240826, 1240827}}, -- Prayer of Mending
  {"PRIEST_SHADOW", "PRIEST", "Shadow", "spell_shadow_shadowwordpain", {15473}}, -- Shadowform
  {"SHAMAN_ELEMENTAL", "SHAMAN", "Elemental", "spell_nature_lightning", {408490, 1238299, 1238300}}, -- Lava Burst
  {"SHAMAN_ENHANCEMENT", "SHAMAN", "Enhancement", "spell_nature_lightningshield", {425336}}, -- Rage of the Farseer
  {"SHAMAN_RESTORATION", "SHAMAN", "Restoration", "spell_nature_magicimmunity", {408521, 1239242, 1239243}}, -- Riptide
  {"MAGE_ARCANE", "MAGE", "Arcane", "spell_holy_magicalsentry", {12042}}, -- Arcane Power
  {"MAGE_FIRE", "MAGE", "Fire", "spell_fire_firebolt02", {11129}}, -- Combustion
  {"MAGE_FROST", "MAGE", "Frost", "spell_frost_frostbolt02", {11426, 13031, 13032, 13033}}, -- Ice Barrier
  {"WARLOCK_AFFLICTION", "WARLOCK", "Affliction", "spell_shadow_deathcoil", {1316697}}, -- Wrack
  {"WARLOCK_DEMONOLOGY", "WARLOCK", "Demonology", "spell_shadow_metamorphosis", {425464}}, -- Demonic Pact
  {"WARLOCK_DESTRUCTION", "WARLOCK", "Destruction", "spell_shadow_rainoffire", {412758, 1293812, 1293813}}, -- Incinerate
  {"DRUID_BALANCE", "DRUID", "Balance", "spell_nature_starfall", {24858}}, -- Moonkin Form
  {"DRUID_FERAL_COMBAT", "DRUID", "Feral Combat", "ability_racial_bearform", {417141}}, -- Berserk
  {"DRUID_RESTORATION", "DRUID", "Restoration", "spell_nature_healingtouch", {408120, 1238214, 1238215}}, -- Wild Growth
}

-- Populate the usual single/multiple selection control without replacing Player
-- Class, changing imported class/spec IDs, or altering assigned-role detection.
Private.forever_spec_types = {}
Private.forever_specs_sorted = {}
local byKey = {}
for _, entry in ipairs(specializations) do
  local key, class, name, icon = entry[1], entry[2], entry[3], entry[4]
  byKey[key] = entry
  local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
  Private.forever_spec_types[key] = "|TInterface\\Icons\\" .. icon .. ":0|t " .. className .. " - " .. name
  Private.forever_specs_sorted[#Private.forever_specs_sorted + 1] = key
end

local function KnownByPlayer(spellID)
  -- Query player spell knowledge, including passives; do not inspect pet spells,
  -- buffs or CDM frames. Unavailable/restricted results do not match.
  local api = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown
  if not api then return false end
  local ok, known = pcall(api, spellID)
  if not ok or (issecretvalue and issecretvalue(known)) then return false end
  return known == true
end

-- The trees of a class, in talent tab order (the catalog lists them that way).
local treesByClass = {}
for _, entry in ipairs(specializations) do
  treesByClass[entry[2]] = treesByClass[entry[2]] or {}
  table.insert(treesByClass[entry[2]], entry)
end

local function Readable(value)
  return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Forever 1.60 draws its talent trees with the Traits system: one trait tree
-- per class holding every talent as a node, with no tabs, names or sub trees.
-- The three classic trees are the three bands of node columns (posX), left
-- to right in the catalog's tab order; a band's points are the purchased
-- ranks of its nodes. Returns the bands as tabs, or nil when the data is
-- not there (no config yet, secret values, or not three bands).
local function TraitPoints()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
    and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return nil end
  local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
  if not ok or not Readable(configID) or type(configID) ~= "number" then return nil end
  local okInfo, info = pcall(C_Traits.GetConfigInfo, configID)
  local treeID = okInfo and type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
  if not Readable(treeID) or type(treeID) ~= "number" then return nil end
  local okNodes, nodes = pcall(C_Traits.GetTreeNodes, treeID)
  if not okNodes or type(nodes) ~= "table" or #nodes == 0 then return nil end
  local columns, xs = {}, {}
  for _, nodeID in ipairs(nodes) do
    local okNode, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
    if okNode and type(node) == "table" and Readable(node.posX) and type(node.posX) == "number" then
      local ranks = Readable(node.ranksPurchased) and tonumber(node.ranksPurchased) or 0
      if not columns[node.posX] then columns[node.posX] = 0; xs[#xs + 1] = node.posX end
      columns[node.posX] = columns[node.posX] + ranks
    end
  end
  if #xs < 3 then return nil end
  table.sort(xs)
  -- Columns of one tree sit one step apart; a gap of more than two steps
  -- starts the next tree.
  local step
  for i = 2, #xs do
    local gap = xs[i] - xs[i - 1]
    if gap > 0 and (not step or gap < step) then step = gap end
  end
  if not step then return nil end
  local tabs = {{spent = columns[xs[1]]}}
  for i = 2, #xs do
    if xs[i] - xs[i - 1] > step * 2 then tabs[#tabs + 1] = {spent = 0} end
    tabs[#tabs].spent = tabs[#tabs].spent + columns[xs[i]]
  end
  if #tabs ~= 3 then return nil end
  return tabs
end

-- Points spent per talent tab, or nil when the client cannot say (no talent
-- API, or secret values). Modern clients answer through C_SpecializationInfo;
-- the classic global returns the points as its fifth value; Forever 1.60
-- through its trait tree (TraitPoints).
local function TalentPoints()
  local count = C_SpecializationInfo and C_SpecializationInfo.GetNumTalentTabs and C_SpecializationInfo.GetNumTalentTabs()
    or GetNumTalentTabs and GetNumTalentTabs()
  if not Readable(count) or type(count) ~= "number" or count == 0 then return TraitPoints() end
  local points = {}
  for tab = 1, count do
    local spent, name
    if C_SpecializationInfo and C_SpecializationInfo.GetTalentTabInfo then
      local ok, info = pcall(C_SpecializationInfo.GetTalentTabInfo, tab)
      if ok and type(info) == "table" then spent, name = info.pointsSpent, info.name end
    elseif GetTalentTabInfo then
      local ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab)
      if ok then
        if type(a) == "string" then spent, name = c, a else spent, name = e, b end
      end
    end
    if not Readable(spent) or type(spent) ~= "number" then return nil end
    points[tab] = {spent = spent, name = Readable(name) and name or nil}
  end
  return points
end

-- The chosen specialization: the tree with 21 or more points, and the most
-- points when several qualify (ties go to the earlier tab). Without readable
-- talent data, the tree whose final talent is known (any rank) stands in.
-- Reading the trait tree allocates a table per node, and every load scan
-- asks for the specialization twice per aura with a Specialization load
-- condition (UNIT_FLAGS scans run throughout combat: 46 ms and 17 MB per
-- scan on a full UI). The answer is kept until talents can have changed.
local specCache = {valid = false, value = nil}
local specEvents = CreateFrame("Frame")
for _, event in ipairs({"SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_ENTERING_WORLD",
  "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED"}) do
  pcall(specEvents.RegisterEvent, specEvents, event)
end
specEvents:SetScript("OnEvent", function() specCache.valid = false end)

local function ComputeSpecialization()
  local _, class = UnitClass("player")
  if not Readable(class) then return nil end
  local trees = treesByClass[class]
  if not trees then return nil end
  local points = TalentPoints()
  if points then
    local best, bestPoints
    for tab, info in ipairs(points) do
      local entry = trees[tab]
      -- A tab named like a tree takes that tree, whatever its index.
      if info.name then
        for _, candidate in ipairs(trees) do
          if candidate[3] == info.name then entry = candidate end
        end
      end
      if entry and info.spent >= 21 and (not bestPoints or info.spent > bestPoints) then
        best, bestPoints = entry[1], info.spent
      end
    end
    return best
  end
  for _, entry in ipairs(trees) do
    for _, spellID in ipairs(entry[5]) do
      if KnownByPlayer(spellID) then return entry[1] end
    end
  end
  return nil
end

function Private.ExecEnv.ForeverSpecialization()
  if not specCache.valid then
    specCache.value = ComputeSpecialization()
    specCache.valid = true
  end
  return specCache.value
end

-- "/fa spec": what the client reports per talent tab, and the tree chosen,
-- for reports of a specialization not being recognised.
function Private.PrintSpecialization()
  local print = WeakAuras.prettyPrint or print
  local _, class = UnitClass("player")
  print(("Class: %s"):format(tostring(class)))
  local modernCount = C_SpecializationInfo and C_SpecializationInfo.GetNumTalentTabs and C_SpecializationInfo.GetNumTalentTabs()
  local classicCount = GetNumTalentTabs and GetNumTalentTabs()
  print(("Talent tabs: C_SpecializationInfo=%s, GetNumTalentTabs=%s, active group=%s"):format(tostring(modernCount), tostring(classicCount),
    tostring(GetActiveTalentGroup and GetActiveTalentGroup() or C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup())))
  local count = tonumber(modernCount) or tonumber(classicCount) or 0
  for tab = 1, count do
    if C_SpecializationInfo and C_SpecializationInfo.GetTalentTabInfo then
      local ok, info = pcall(C_SpecializationInfo.GetTalentTabInfo, tab)
      if ok and type(info) == "table" then
        print(("  tab %d (C_SpecializationInfo): name=%s pointsSpent=%s id=%s"):format(tab, tostring(info.name), tostring(info.pointsSpent), tostring(info.id)))
      else
        print(("  tab %d (C_SpecializationInfo): %s"):format(tab, ok and type(info) or ("error " .. tostring(info))))
      end
    end
    if GetTalentTabInfo then
      local ok, a, b, c, d, e = pcall(GetTalentTabInfo, tab)
      print(("  tab %d (GetTalentTabInfo): %s, %s, %s, %s, %s"):format(tab, tostring(a), tostring(b), tostring(c), tostring(d), tostring(e)))
    end
  end
  local okC, configID = pcall(function() return C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() end)
  print(("Trait config: %s"):format(okC and tostring(configID) or ("error " .. tostring(configID))))
  local points = TalentPoints()
  if points then
    for tab, info in ipairs(points) do print(("  read: tab %d %s = %d points"):format(tab, tostring(info.name), info.spent)) end
  else
    print("  points unreadable: falling back to known final talents")
  end
  print(("Specialization: %s"):format(tostring(Private.ExecEnv.ForeverSpecialization())))
end

function Private.ExecEnv.IsForeverSpecialization(key)
  local entry = byKey[key]
  if not entry then return false end
  return Private.ExecEnv.ForeverSpecialization() == key
end

-- Multi selection: green (true) trees load the aura, red (false) trees keep
-- it from loading. With only red trees, every other tree loads.
function Private.ExecEnv.ForeverSpecLoad(positive, negative)
  local current = Private.ExecEnv.ForeverSpecialization()
  if current and negative[current] then return false end
  if next(positive) then return current ~= nil and positive[current] == true end
  return next(negative) ~= nil
end
