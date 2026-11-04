-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class WeakAuras
local WeakAuras = WeakAuras;
local L = WeakAuras.L;

local encounter_list = ""
local zoneId_list = ""
function Private.InitializeEncounterAndZoneLists()
  if encounter_list ~= "" then
    return
  end
  -- Forever may expose journal APIs before any journal tiers exist.
  if not EJ_GetNumTiers or not EJ_GetCurrentTier or not EJ_SelectTier then return end
  local numTiers = EJ_GetNumTiers()
  if type(numTiers) ~= "number" or numTiers < 1 or numTiers % 1 ~= 0 then return end
  local currTier = EJ_GetCurrentTier()
	for tier = numTiers, numTiers do
		EJ_SelectTier(tier)
		local tierName = EJ_GetTierInfo(tier)
		for _, inRaid in ipairs({false, true}) do
			local instance_index = 1
			local instance_id = EJ_GetInstanceByIndex(instance_index, inRaid)
			local title = ("%s %s"):format(tierName , inRaid and L["Raids"] or L["Dungeons"])
			local zones = ""
			while instance_id do
				EJ_SelectInstance(instance_id)
				local instance_name, _, _, _, _, _, dungeonAreaMapID = EJ_GetInstanceInfo(instance_id)
				local ej_index = 1
				local boss, _, _, _, _, _, encounter_id = EJ_GetEncounterInfoByIndex(ej_index, instance_id)

				-- zone ids
				if dungeonAreaMapID and dungeonAreaMapID ~= 0 then
					local mapGroupId = C_Map.GetMapGroupID(dungeonAreaMapID)
					if mapGroupId then -- If there's a group id, only list that one
						zones = ("%s%s: g%d\n"):format(zones, instance_name, mapGroupId)
					else
						zones = ("%s%s: %d\n"):format(zones, instance_name, dungeonAreaMapID)
					end
				end

				-- Encounter ids
				if inRaid then
					while boss do
						if encounter_id then
							if instance_name then
								encounter_list = ("%s|cffffd200%s|r\n"):format(encounter_list, instance_name)
								instance_name = nil -- Only add it once per section
							end
							encounter_list = ("%s%s: %d\n"):format(encounter_list, boss, encounter_id)
						end
						ej_index = ej_index + 1
						boss, _, _, _, _, _, encounter_id = EJ_GetEncounterInfoByIndex(ej_index, instance_id)
					end
					encounter_list = encounter_list .. "\n"
				end
				instance_index = instance_index + 1
				instance_id = EJ_GetInstanceByIndex(instance_index, inRaid)
			end
			if zones ~= "" then
				zoneId_list = ("%s|cffffd200%s|r\n"):format(zoneId_list, title)
				zoneId_list = zoneId_list .. zones.. "\n"
			end
		end
	end
	if type(currTier) == "number" and currTier >= 1 and currTier <= numTiers and currTier % 1 == 0 then
    EJ_SelectTier(currTier) -- restore only a valid previously selected tier
  end

  encounter_list = encounter_list:sub(1, -3) .. "\n\n" .. L["Supports multiple entries, separated by commas\n"]
end

function Private.get_encounters_list()
  return encounter_list
end

function Private.get_zoneId_list()
  return zoneId_list
end

Private.talentInfo = {}
Private.talentInfoByNodeId = {}

function Private.GetTalentConfigID()
  -- Forever exposes the spec group's combat config; retail (testing only) has
  -- the active class talent config instead. Neither present: no talent data.
  if C_SpecializationInfo.GetCombatConfigIDForSpecGroup then
    local group = C_SpecializationInfo.GetActiveSpecGroup()
    return C_SpecializationInfo.GetCombatConfigIDForSpecGroup(group)
  elseif C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    return C_ClassTalents.GetActiveConfigID()
  end
end

local function ReadTalentConfig(configId)
  local config = configId and C_Traits.GetConfigInfo(configId)
  local talents, byNode = {}, {}
  if not config then return talents, {}, byNode end

  for treeIndex, treeId in ipairs(config.treeIDs) do
    for _, nodeId in ipairs(C_Traits.GetTreeNodes(treeId)) do
      local node = C_Traits.GetNodeInfo(configId, nodeId)
      if node and node.ID ~= 0 then
        for index, entryId in ipairs(node.entryIDs) do
          local entry = C_Traits.GetEntryInfo(configId, entryId)
          local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
          if definition and definition.spellID then
            local targets = {}
            for _, edge in ipairs(node.visibleEdges) do
              local target = C_Traits.GetNodeInfo(configId, edge.targetNode)
              if target and target.entryIDs[1] then
                tinsert(targets, target.entryIDs[1])
              end
            end
            -- [3][6] = which tree the node is in, so the options picker can lay separate trees side by side.
            local talent = {entryId, definition.spellID, {node.posX, node.posY, index, #node.entryIDs, nil, treeIndex}, targets, node.maxRanks}
            tinsert(talents, talent)
            byNode[node.ID] = byNode[node.ID] or {}
            byNode[node.ID][index] = talent
          end
        end
      end
    end
  end
  table.sort(talents, function(a, b)
    if a[3][2] ~= b[3][2] then return a[3][2] < b[3][2] end
    if a[3][1] ~= b[3][1] then return a[3][1] < b[3][1] end
    return a[1] < b[1]
  end)
  return talents, {}, byNode
end

local viewedTalents = {}
local function ViewTalentData(specId)
  if viewedTalents[specId] then return unpack(viewedTalents[specId]) end
  local viewId = Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
  if not (viewId and C_ClassTalents and C_ClassTalents.InitializeViewLoadout and C_ClassTalents.ViewLoadout) then
    return {}, {}, {}
  end
  local level = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60
  local ok = pcall(C_ClassTalents.InitializeViewLoadout, specId, level)
  ok = ok and pcall(C_ClassTalents.ViewLoadout, {})
  if not ok then return {}, {}, {} end
  local talents, hero, byNode = ReadTalentConfig(viewId)
  if #talents > 0 then viewedTalents[specId] = {talents, hero, byNode} end
  return talents, hero, byNode
end

-- The player's own talent config, read once per config until a talent event
-- (Private.CheckTalentsForLoad) invalidates it. ReadTalentConfig walks every
-- node, entry and definition of the trait tree through C_Traits, and the load
-- options ask for it per aura, per talent key and per widget: opening the Load
-- tab of a large group read the whole tree thousands of times.
local ownTalents = {}
function Private.InvalidateTalentData()
  wipe(ownTalents)
end

function Private.GetTalentData(specId)
  local spec = Private.ExecEnv.GetSpecialization()
  local playerSpecId = spec and Private.ExecEnv.GetSpecializationInfo(spec)
  if specId ~= playerSpecId then
    return ViewTalentData(specId)
  end
  local configId = Private.GetTalentConfigID()
  local cached = configId and ownTalents[configId]
  if cached then return unpack(cached) end
  local talents, hero, byNode = ReadTalentConfig(configId)
  if configId and #talents > 0 then ownTalents[configId] = {talents, hero, byNode} end
  return talents, hero, byNode
end

function Private.GetTalentInfo(specId)
  local values = {}
  for _, talent in ipairs(Private.GetTalentData(specId)) do
    local name, _, icon = Private.ExecEnv.GetSpellInfo(talent[2])
    if name then values[talent[1]] = "|T" .. icon .. ":16|t " .. name end
  end
  return values
end

WeakAuras.StopMotion = {
	texture_data = {},
	texture_types = {
		Blizzard = {}
	}
}
local texture_data = {}

local replacementString = {}
-- Action bar GCD
texture_data["UI-HUD-ActionBar-GCD-Flipbook-2x"] = { rows = 11, columns = 2, count = 22 }
-- Arcane shock
texture_data["UF-Arcane-ShockFX"] = { rows = 5, columns = 6, count = 28 }
-- Checkmark
texture_data["activities-checkmark_flipbook-large"] = { rows = 2, columns = 4, count = 8 }
-- Chi wind
texture_data["UF-Chi-WindFX"] = { rows = 3, columns = 6, count = 17 }
-- Death knight runes
replacementString = {
	"Blood",
	"Default",
	"Frost",
	"Unholy"
}
for _, v in ipairs(replacementString) do
	local name = ("UF-DKRunes-%sDeplete"):format(v)
	texture_data[name] = { rows = 4, columns = 6, count = 23 }
end
-- Dice
texture_data["lootroll-animdice"] = { rows = 9, columns = 5, count = 44 }
-- Dragonriding vigor
texture_data["dragonriding_vigor_fill_flipbook"] = { rows = 5, columns = 4, count = 20 }
-- Druid combo points
texture_data["UF-DruidCP-Slash"] = { rows = 3, columns = 8, count = 20 }
-- Essence spinner
texture_data["UF-Essence-Flipbook-FX-Circ"] = { rows = 3, columns = 10, count = 29 }
-- Experience bars
replacementString = {
	"Rested",
	"Reputation",
	"Experience",
	"Honor",
	"ArtifactPower"
}
for _, v in ipairs(replacementString) do
	local name = ("UI-HUD-ExperienceBar-Fill-%s-2x-Flipbook"):format(v)
	texture_data[name] = { rows = 30, columns = 1, count = 30 }
end
replacementString = {
	"Rested",
	"Reputation",
	"XP",
	"Faction-Orange",
	"ArtifactPower"
}
for _, v in ipairs(replacementString) do
	local name = ("UI-HUD-ExperienceBar-Flare-%s-2x-Flipbook"):format(v)
	texture_data[name] = { rows = 7, columns = 4, count = 28 }
end
-- Great vault unlocking
texture_data["greatVault-unlocked-anim"] = { rows = 11, columns = 5, count = 54 }
-- Group finder eye
texture_data["groupfinder-eye-flipbook-initial"] = { rows = 5, columns = 11, count = 52 }
texture_data["groupfinder-eye-flipbook-searching"] = { rows = 8, columns = 11, count = 80 }
texture_data["groupfinder-eye-flipbook-mouseover"] = { rows = 1, columns = 12, count = 12 }
texture_data["groupfinder-eye-flipbook-foundfx"] = { rows = 5, columns = 15, count = 75 }
texture_data["groupfinder-eye-flipbook-found-initial"] = { rows = 7, columns = 11, count = 70 }
texture_data["groupfinder-eye-flipbook-found-loop"] = { rows = 4, columns = 11, count = 41 }
texture_data["groupfinder-eye-flipbook-poke-initial"] = { rows = 6, columns = 11, count = 66 }
texture_data["groupfinder-eye-flipbook-poke-loop"] = { rows = 6, columns = 11, count = 62 }
texture_data["groupfinder-eye-flipbook-poke-end"] = { rows = 4, columns = 11, count = 38 }
-- Holy power runes
for i = 1, 5 do
	local name = ("UF-HolyPower-DepleteRune%d"):format(i)
	texture_data[name] = { rows = 5, columns = 6, count = 26 }
end

-- Loot roll reveal
texture_data["lootroll-animreveal-a"] = { rows = 2, columns = 6, count = 12 }
-- Mail
texture_data["UI-HUD-Minimap-Mail-New-Flipbook-2x"] = { rows = 5, columns = 4, count = 20 }
texture_data["UI-HUD-Minimap-Mail-Reminder-Flipbook-2x"] = { rows = 3, columns = 4, count = 12 }
-- Ping markers
replacementString = {
	"Assist",
	"Attack",
	"OnMyWay",
	"Warning",
	"NonThreat",
	"Threat"
}
for _, v in ipairs(replacementString) do
	local name = ("Ping_Marker_FlipBook_%s"):format(v)
	texture_data[name] = { rows = 4, columns = 6, count = 21 }
end
-- Player rest
texture_data["UI-HUD-UnitFrame-Player-Rest-Flipbook"] = { rows = 7, columns = 6, count = 42 }
-- Priest void bar
texture_data["Unit_Priest_Void_Fill_Flipbook"] = { rows = 9, columns = 5, count = 45 }
-- Professions
replacementString = {
	"Alchemy",
	"Blacksmithing",
	"Cooking",
	"Engineering",
	"Fishing",
	"Herbalism",
	"Inscription",
	"Leatherworking",
	"Mining",
	"Skinning",
	"Tailoring"
}
for _, v in ipairs(replacementString) do
	local name = ("Skillbar_Fill_Flipbook_%s"):format(v)
	texture_data[name] = { rows = 30, columns = 2, count = 60 }
end
texture_data["Skillbar_Fill_Flipbook_Enchanting"] = { rows = 37, columns = 2, count = 74 }
texture_data["Skillbar_Fill_Flipbook_Jewelcrafting"] = { rows = 22, columns = 2, count = 44 }
replacementString = {
	"Alchemy",
	"Blacksmithing",
	"Enchanting",
	"Engineering",
	"Herbalism",
	"Inscription",
	"Jewelcrafting",
	"Leatherworking",
	"Mining",
	"Skinning",
	"Tailoring"
}
for _, v in ipairs(replacementString) do
	local name = ("SpecDial_Fill_Flipbook_%s"):format(v)
	texture_data[name] = { rows = 6, columns = 6, count = 36 }
	name = ("SpecDial_Pip_Flipbook_%s"):format(v)
	texture_data[name] = { rows = 4, columns = 4, count = 16 }
	name = ("SpecDial_EndPip_Flipbook_%s"):format(v)
	texture_data[name] = { rows = 4, columns = 6, count = 24 }
end
for i = 1, 5 do
	local name = ("GemAppear_T%d_Flipbook"):format(i)
	texture_data[name] = { rows = 3, columns = 4, count = 12 }
	name = ("Quality-BarFill-Flipbook-T%d-x2"):format(i)
	texture_data[name] = { rows = 15, columns = 4, count = 60 }
end
for i = 1, 4 do
	local name = ("GemDissolve_T%d_Flipbook"):format(i)
	texture_data[name] = { rows = 3, columns = 4, count = 12 }
end
-- Rogue combo points
replacementString = {
	"Red",
	"Blue"
}
for _, v in ipairs(replacementString) do
	local name = ("UF-RogueCP-Slash-%s"):format(v)
	texture_data[name] = { rows = 3, columns = 6, count = 17 }
end
-- Soul shards
replacementString = {
	"A",
	"B",
	"C"
}
for _, v in ipairs(replacementString) do
	local name = ("UF-SoulShards-Flipbook-Deplete%s"):format(v)
	texture_data[name] = { rows = 3, columns = 6, count = 15 }
end
texture_data["UF-SoulShards-Flipbook-Soul"] = { rows = 3, columns = 7, count = 18 }
-- Dragonriding
do
	local flipbooks = {
		{ pattern = "%s_fill_flipbook", duration = 1.2, rows = 5, columns = 4, count = 20 },
		{ pattern = "%s_filled_flipbook", duration = 0.6, rows = 2, columns = 4, count = 8 },
		{ pattern = "%s_burst_flipbook", duration = 0.55, rows = 4, columns = 4, count = 16 },
		{ pattern = "%s_decor_flipbook_left", duration = 0.3, rows = 2, columns = 4, count = 8 },
		{ pattern = "%s_decor_flipbook_right", duration = 0.3, rows = 2, columns = 4, count = 8 },
	}
	local kitName = "dragonriding_sgvigor"
	for _, flipbook in ipairs(flipbooks) do
		local name = flipbook.pattern:format(kitName)
		texture_data[name] = { rows = flipbook.rows, columns = flipbook.columns, count = flipbook.count }
	end
end

-- Supplement the data
for k, v in pairs(texture_data) do
	local atlasInfo = C_Texture.GetAtlasInfo(k)
	if atlasInfo then
		if atlasInfo.rawSize then
			v.tileWidth = atlasInfo.rawSize.x / v.columns
			v.tileHeight = atlasInfo.rawSize.y / v.rows
		end
		v.isBlizzardFlipbook = true
		WeakAuras.StopMotion.texture_data[k] = v
		WeakAuras.StopMotion.texture_types.Blizzard[k] = k
	end
end
