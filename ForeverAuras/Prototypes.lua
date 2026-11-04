-- Modified for ForeverAuras, 2026-10-23.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("Prototypes")
-- Lua APIs
local tinsert, tsort = table.insert, table.sort
local tostring = tostring
local select, pairs, type = select, pairs, type
local ceil = ceil

-- WoW APIs
local UnitClass = UnitClass
local GetShapeshiftFormInfo, GetShapeshiftForm = GetShapeshiftFormInfo, GetShapeshiftForm
local GetRuneCooldown, UnitCastingInfo, UnitChannelInfo = GetRuneCooldown, UnitCastingInfo, UnitChannelInfo
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local MAX_NUM_TALENTS = MAX_NUM_TALENTS or 20

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local SpellRange = LibStub("SpellRange-1.0")
-- 1 in range, 0 out of range, nil when it cannot be told (no or invalid unit,
-- unknown spell, or a secret result, which reads as unknown).
function WeakAuras.IsSpellInRange(spellId, unit)
  if C_Spell.IsSpellInRange then
    local result = C_Spell.IsSpellInRange(spellId, unit)
    if issecretvalue(result) or result == nil then return nil end
    return result and 1 or 0
  end
  return SpellRange.IsSpellInRange(spellId, unit)
end

local LibRangeCheck = LibStub("LibRangeCheck-3.0")

-- Range results can be secret, and another addon may have loaded an older
-- copy of the library: an error or a secret result reads as "unknown".
function WeakAuras.GetRange(unit, checkVisible)
  local ok, min, max = pcall(LibRangeCheck.GetRange, LibRangeCheck, unit, checkVisible)
  if not ok or issecretvalue(min) or issecretvalue(max) then return end
  return min, max
end

function WeakAuras.CheckRange(unit, range, operator)
  local min, max = WeakAuras.GetRange(unit, true);
  if (type(range) ~= "number") then
    range = tonumber(range);
  end
  if (not range) then
    return
  end
  if (operator == "<=") then
    return (max or 999) <= range;
  else
    return (min or 0) >= range;
  end
end

local RangeCacheStrings = {friend = "", harm = "", misc = ""}
local function RangeCacheUpdate()
  local friend, harm, misc = {}, {}, {}
  local friendString, harmString, miscString

  for range in LibRangeCheck:GetFriendCheckers() do
    tinsert(friend, range)
  end
  tsort(friend)
  for range in LibRangeCheck:GetHarmCheckers() do
    tinsert(harm, range)
  end
  tsort(harm)
  for range in LibRangeCheck:GetMiscCheckers() do
    tinsert(misc, range)
  end
  tsort(misc)

  for _, key in pairs(friend) do
    friendString = (friendString and (friendString .. ", ") or "") .. key
  end
  for _, key in pairs(harm) do
    harmString = (harmString and (harmString .. ", ") or "") .. key
  end
  for _, key in pairs(misc) do
      miscString = (miscString and (miscString .. ", ") or "") .. key
  end
  RangeCacheStrings.friend, RangeCacheStrings.harm, RangeCacheStrings.misc = friendString, harmString, miscString
end

LibRangeCheck:RegisterCallback(LibRangeCheck.CHECKERS_CHANGED, RangeCacheUpdate)

function WeakAuras.UnitDetailedThreatSituation(unit1, unit2)
  local ok, aggro, status, threatpct, rawthreatpct, threatvalue = pcall(UnitDetailedThreatSituation, unit1, unit2)
  if ok then
    return aggro, status, threatpct, rawthreatpct, threatvalue
  end
end

WeakAuras.UnitCastingInfo = UnitCastingInfo

do
  local cacheEmpowered = {}
  WeakAuras.UnitChannelInfo = function(unit)
    local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = UnitChannelInfo(unit)
    if name == nil and cacheEmpowered[unit] then
      local holdAtMaxTime
      holdAtMaxTime, name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages = unpack(cacheEmpowered[unit])
      if endTime == nil
      or holdAtMaxTime == nil
      or issecretvalue(holdAtMaxTime)
      or issecretvalue(endTime)
      or endTime + holdAtMaxTime < GetTime()
      then -- invalid or too old data
        cacheEmpowered[unit] = nil
        return nil
      end
    end
    return name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID, _, numStages
  end
  local cacheEmpoweredFrame = CreateFrame("Frame")
  cacheEmpoweredFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
  cacheEmpoweredFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
  cacheEmpoweredFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
  cacheEmpoweredFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  cacheEmpoweredFrame:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED")
  cacheEmpoweredFrame:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
  cacheEmpoweredFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
  cacheEmpoweredFrame:SetScript("OnEvent", function(_, event, unit, ...)
    if Private.player_target_events[event] then
      unit = Private.player_target_events[event]
    end

    if event == "UNIT_SPELLCAST_EMPOWER_START"
    or event == "UNIT_SPELLCAST_EMPOWER_UPDATE"
    or (
      (Private.player_target_events[event])
      and (select(10, UnitChannelInfo(unit)) or 0) > 0  -- 10th arg of UnitChannelInfo is numStages for empowered spells
    )
    then
      cacheEmpowered[unit] = {GetUnitEmpowerHoldAtMaxTime(unit), UnitChannelInfo(unit)}
    else
      cacheEmpowered[unit] = nil
    end

    if unit == "player" and event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
      local castLatencyFrame = Private.frames["Cast Latency Handler"]
      if castLatencyFrame then
        castLatencyFrame:GetScript("OnEvent")(nil, event, unit, ...)
      end
    end
    Private.ScanUnitEvents(event.."_FAKE", unit, ...)
  end)
end

local constants = {
  nameRealmFilterDesc = "Enter full character names, including surnames. Separate names with commas; spaces stay part of the name. You can also use Name-Realm or -Realm.",
  instanceFilterDeprecated = L["Available in the Conditions tab. This existing trigger filter is kept for compatibility."],
  guildFilterDesc = L["Supports multiple entries, separated by commas. Escape with \\. Prefix with '-' for negation."]
}

---@param school integer
---@return string school
function WeakAuras.SpellSchool(school)
  return Private.combatlog_spell_school_types[school] or ""
end

---@param flag integer
---@return integer index
function WeakAuras.RaidFlagToIndex(flag)
  return Private.combatlog_raidFlags[flag] or 0
end

local function get_zoneId_list()
  local currentmap_id = C_Map.GetBestMapForUnit("player")
  local instanceId = select(8, GetInstanceInfo())
  local bottomText = L["Supports multiple entries, separated by commas. To include child zone ids, prefix with 'c', e.g. 'c2022'.\nGroup Zone IDs must be prefixed with 'g', e.g. 'g277'. \nSupports Area IDs from https://wago.tools/db2/AreaTable prefixed with 'a'. \nSupports Instance IDs prefixed with 'i'.\nEntries can be prefixed with '-' to negate."]
  if not instanceId and not currentmap_id then
    return ("%s\n\n%s"):format(Private.get_zoneId_list(), bottomText)
  elseif not currentmap_id then
    return ("%s|cffffd200%s|r\n%s: %d\n\n%s"):format(Private.get_zoneId_list(), L["Current Instance"], L["Instance Id"], instanceId, bottomText)
  end
  local currentmap_info = C_Map.GetMapInfo(currentmap_id)
  local currentmap_name = currentmap_info and currentmap_info.name or ""
  local currentmap_zone_name = ""
  local parentmap_zone_name = ""
  local mapGroupId = C_Map.GetMapGroupID(currentmap_id)
  if mapGroupId then
    currentmap_zone_name = string.format("|cffffd200%s|r\n%s: g%d\n\n",
                                         L["Current Zone Group"], currentmap_name, mapGroupId)

    -- if map is in a group, its real name is (or should be?) found in GetMapGroupMembersInfo
    for k, map in ipairs(C_Map.GetMapGroupMembersInfo(mapGroupId)) do
      if map.mapID and map.mapID == currentmap_id and map.name then
        currentmap_name = map.name
        break
      end
    end
  end
  if currentmap_info and currentmap_info.parentMapID > 0  then
    local parentmap_info = C_Map.GetMapInfo(currentmap_info.parentMapID)
    local parentmap_name = parentmap_info and parentmap_info.name or ""
    parentmap_zone_name = string.format("|cffffd200%s|r\n%s: c%d\n\n",
                                         L["Parent Zone"], parentmap_name, currentmap_info.parentMapID)
  end

  local minimapZoneText = GetMinimapZoneText()
  local currentAreaID = L["not found"]
  for id=1,30000 do
    local areaID = C_Map.GetAreaInfo(id)
    if areaID == minimapZoneText then
      currentAreaID =  "a" .. id
      break
    end
  end

  return ("%s|cffffd200%s|r\n%s: %d\n\n%s%s|cffffd200%s|r\n%s: i%d\n\n|cffffd200%s|r\n%s: %s\n\n%s"):format(
    Private.get_zoneId_list(),
    L["Current Zone"],
    currentmap_name,
    currentmap_id,
    parentmap_zone_name,
    currentmap_zone_name,
    L["Current Instance"],
    L["Instance Id"],
    instanceId,
    L["Current Area"],
    minimapZoneText,
    currentAreaID,
    bottomText
  )
end

Private.function_strings = {
  count = [[
    return function(count)
      if(count %s %s) then
        return true
      else
        return false
      end
    end
  ]],
  count_fraction = [[
    return function(count, max)
      if max == 0 then
        return false
      end
      local fraction = count/max
      if(fraction %s %s) then
        return true
      else
        return false
      end
    end
  ]],
  always = [[
    return function()
      return true
    end
  ]]
};

local hsvFrame = CreateFrame("ColorSelect")

-- HSV transition, for a much prettier color transition in many cases
-- see http://www.wowinterface.com/forums/showthread.php?t=48236
---@param perc number
---@param r1 number
---@param g1 number
---@param b1 number
---@param a1 number
---@param r2 number
---@param g2 number
---@param b2 number
---@param a2 number
---@return number r
---@return number g
---@return number b
---@return number a
function WeakAuras.GetHSVTransition(perc, r1, g1, b1, a1, r2, g2, b2, a2)
  --get hsv color for colorA
  hsvFrame:SetColorRGB(r1, g1, b1)
  local h1, s1, v1 = hsvFrame:GetColorHSV() -- hue, saturation, value
  --get hsv color for colorB
  hsvFrame:SetColorRGB(r2, g2, b2)
  local h2, s2, v2 = hsvFrame:GetColorHSV() -- hue, saturation, value
  local h3 = floor(h1 - (h1 - h2) * perc)
  -- find the shortest arc through the color circle, then interpolate
  local diff = h2 - h1
  if diff < -180 then
    diff = diff + 360
  elseif diff > 180 then
    diff = diff - 360
  end

  h3 = (h1 + perc * diff) % 360
  local s3 = s1 - ( s1 - s2 ) * perc
  local v3 = v1 - ( v1 - v2 ) * perc
  --get the RGB values of the new color
  hsvFrame:SetColorHSV(h3, s3, v3)
  local r, g, b = hsvFrame:GetColorRGB()
  --interpolate alpha
  local a = a1 - ( a1 - a2 ) * perc
  --return the new color
  return r, g, b, a
end

Private.anim_function_strings = {
straight = [[
function(progress, start, delta)
    return start + (progress * delta)
end
]],

straightTranslate = [[
function(progress, startX, startY, deltaX, deltaY)
    return startX + (progress * deltaX), startY + (progress * deltaY)
end
]],

straightScale = [[
function(progress, startX, startY, scaleX, scaleY)
    return startX + (progress * (scaleX - startX)), startY + (progress * (scaleY - startY))
end
]],

straightColor = [[
function(progress, r1, g1, b1, a1, r2, g2, b2, a2)
    return r1 + (progress * (r2 - r1)), g1 + (progress * (g2 - g1)), b1 + (progress * (b2 - b1)), a1 + (progress * (a2 - a1))
end
]],

straightHSV = [[
function(progress, r1, g1, b1, a1, r2, g2, b2, a2)
    return WeakAuras.GetHSVTransition(progress, r1, g1, b1, a1, r2, g2, b2, a2)
end
]],

circle = [[
function(progress, startX, startY, deltaX, deltaY)
    local angle = progress * 2 * math.pi
    return startX + (deltaX * math.cos(angle)), startY + (deltaY * math.sin(angle))
end
]],

circle2 = [[
function(progress, startX, startY, deltaX, deltaY)
    local angle = progress * 2 * math.pi
    return startX + (deltaX * math.sin(angle)), startY + (deltaY * math.cos(angle))
end
]],

spiral = [[
function(progress, startX, startY, deltaX, deltaY)
    local angle = progress * 2 * math.pi
    return startX + (progress * deltaX * math.cos(angle)), startY + (progress * deltaY * math.sin(angle))
end
]],

spiralandpulse = [[
function(progress, startX, startY, deltaX, deltaY)
    local angle = (progress + 0.25) * 2 * math.pi
    return startX + (math.cos(angle) * deltaX * math.cos(angle*2)), startY + (math.abs(math.cos(angle)) * deltaY * math.sin(angle*2))
end
]],

shake = [[
function(progress, startX, startY, deltaX, deltaY)
    local prog
    if(progress < 0.25) then
        prog = progress * 4
    elseif(progress < .75) then
        prog = 2 - (progress * 4)
    else
        prog = (progress - 1) * 4
    end
    return startX + (prog * deltaX), startY + (prog * deltaY)
end
]],

starShakeDecay = [[
function(progress, startX, startY, deltaX, deltaY)
    local spokes = 10
    local fullCircles = 4

    local r = min(abs(deltaX), abs(deltaY))
    local xScale = deltaX / r
    local yScale = deltaY / r

    local deltaAngle = fullCircles *2 / spokes * math.pi
    local p = progress * spokes
    local i1 = floor(p)
    p = p - i1

    local angle1 = i1 * deltaAngle
    local angle2 = angle1 + deltaAngle

    local x1 = r * math.cos(angle1)
    local y1 = r * math.sin(angle1)

    local x2 = r * math.cos(angle2)
    local y2 = r * math.sin(angle2)

    local x, y = p * x2 + (1-p) * x1, p * y2 + (1-p) * y1
    local ease = math.sin(progress * math.pi / 2)
    return ease * x * xScale, ease * y * yScale
end
]],

bounceDecay = [[
function(progress, startX, startY, deltaX, deltaY)
    local prog = (progress * 3.5) % 1
    local bounce = math.ceil(progress * 3.5)
    local bounceDistance = math.sin(prog * math.pi) * (bounce / 4)
    return startX + (bounceDistance * deltaX), startY + (bounceDistance * deltaY)
end
]],

bounce = [[
function(progress, startX, startY, deltaX, deltaY)
    local bounceDistance = math.sin(progress * math.pi)
    return startX + (bounceDistance * deltaX), startY + (bounceDistance * deltaY)
end
]],

flash = [[
function(progress, start, delta)
    local prog
    if(progress < 0.5) then
        prog = progress * 2
    else
        prog = (progress - 1) * 2
    end
    return start + (prog * delta)
end
]],

pulse = [[
function(progress, startX, startY, scaleX, scaleY)
    local angle = (progress * 2 * math.pi) - (math.pi / 2)
    return startX + (((math.sin(angle) + 1)/2) * (scaleX - 1)), startY + (((math.sin(angle) + 1)/2) * (scaleY - 1))
end
]],

alphaPulse = [[
function(progress, start, delta)
    local angle = (progress * 2 * math.pi) - (math.pi / 2)
    return start + (((math.sin(angle) + 1)/2) * delta)
end
]],

pulseColor = [[
function(progress, r1, g1, b1, a1, r2, g2, b2, a2)
    local angle = (progress * 2 * math.pi) - (math.pi / 2)
    local newProgress = ((math.sin(angle) + 1)/2);
    return r1 + (newProgress * (r2 - r1)),
         g1 + (newProgress * (g2 - g1)),
         b1 + (newProgress * (b2 - b1)),
         a1 + (newProgress * (a2 - a1))
end
]],

pulseHSV = [[
function(progress, r1, g1, b1, a1, r2, g2, b2, a2)
    local angle = (progress * 2 * math.pi) - (math.pi / 2)
    local newProgress = ((math.sin(angle) + 1)/2);
    return WeakAuras.GetHSVTransition(newProgress, r1, g1, b1, a1, r2, g2, b2, a2)
end
]],

fauxspin = [[
function(progress, startX, startY, scaleX, scaleY)
    local angle = progress * 2 * math.pi
    return math.cos(angle) * scaleX, startY + (progress * (scaleY - startY))
end
]],

fauxflip = [[
function(progress, startX, startY, scaleX, scaleY)
    local angle = progress * 2 * math.pi
    return startX + (progress * (scaleX - startX)), math.cos(angle) * scaleY
end
]],

backandforth = [[
function(progress, start, delta)
    local prog
    if(progress < 0.25) then
        prog = progress * 4
    elseif(progress < .75) then
        prog = 2 - (progress * 4)
    else
        prog = (progress - 1) * 4
    end
    return start + (prog * delta)
end
]],

wobble = [[
function(progress, start, delta)
    local angle = progress * 2 * math.pi
    return start + math.sin(angle) * delta
end
]],

hide = [[
function()
    return 0
end
]]
};

Private.anim_presets = {
  -- Start and Finish
  slidetop = {
    type = "custom",
    duration = 0.25,
    use_translate = true,
    x = 0, y = 50,
    use_alpha = true,
    alpha = 0
  },
  slideleft = {
    type = "custom",
    duration = 0.25,
    use_translate = true,
    x = -50,
    y = 0,
    use_alpha = true,
    alpha = 0
  },
  slideright = {
    type = "custom",
    duration = 0.25,
    use_translate = true,
    x = 50,
    y = 0,
    use_alpha = true,
    alpha = 0
  },
  slidebottom = {
    type = "custom",
    duration = 0.25,
    use_translate = true,
    x = 0,
    y = -50,
    use_alpha = true,
    alpha = 0
  },
  fade = {
    type = "custom",
    duration = 0.25,
    use_alpha = true,
    alpha = 0
  },
  grow = {
    type = "custom",
    duration = 0.25,
    use_scale = true,
    scalex = 2,
    scaley = 2,
    use_alpha = true,
    alpha = 0
  },
  shrink = {
    type = "custom",
    duration = 0.25,
    use_scale = true,
    scalex = 0,
    scaley = 0,
    use_alpha = true,
    alpha = 0
  },
  spiral = {
    type = "custom",
    duration = 0.5,
    use_translate = true,
    x = 100,
    y = 100,
    translateType = "spiral",
    use_alpha = true,
    alpha = 0
  },
  bounceDecay = {
    type = "custom",
    duration = 1.5,
    use_translate = true,
    x = 50,
    y = 50,
    translateType = "bounceDecay",
    use_alpha = true,
    alpha = 0
  },
  starShakeDecay = {
    type = "custom",
    duration = 1,
    use_translate = true,
    x = 50,
    y = 50,
    translateType = "starShakeDecay",
    use_alpha = true,
    alpha = 0
  },
  -- Main
  shake = {
    type = "custom",
    duration = 0.5,
    use_translate = true,
    x = 10,
    y = 0,
    translateType = "circle2"
  },
  spin = {
    type = "custom",
    duration = 1,
    use_scale = true,
    scalex = 1,
    scaley = 1,
    scaleType = "fauxspin"
  },
  flip = {
    type = "custom",
    duration = 1,
    use_scale = true,
    scalex = 1,
    scaley = 1,
    scaleType = "fauxflip"
  },
  wobble = {
    type = "custom",
    duration = 0.5,
    use_rotate = true,
    rotate = 3,
    rotateType = "wobble"
  },
  pulse = {
    type = "custom",
    duration = 0.75,
    use_scale = true,
    scalex = 1.05,
    scaley = 1.05,
    scaleType = "pulse"
  },
  alphaPulse = {
    type = "custom",
    duration = 0.5,
    use_alpha = true,
    alpha = 0.5,
    alphaType = "alphaPulse"
  },
  rotateClockwise = {
    type = "custom",
    duration = 4,
    use_rotate = true,
    rotate = -360
  },
  rotateCounterClockwise = {
    type = "custom",
    duration = 4,
    use_rotate = true,
    rotate = 360
  },
  spiralandpulse = {
    type = "custom",
    duration = 6,
    use_translate = true,
    x = 100,
    y = 100,
    translateType = "spiralandpulse"
  },
  circle = {
    type = "custom",
    duration = 4,
    use_translate = true,
    x = 100,
    y = 100,
    translateType = "circle"
  },
  orbit = {
    type = "custom",
    duration = 4,
    use_translate = true,
    x = 100,
    y = 100,
    translateType = "circle",
    use_rotate = true,
    rotate = 360
  },
  bounce = {
    type = "custom",
    duration = 0.6,
    use_translate = true,
    x = 0,
    y = 25,
    translateType = "bounce"
  }
};

WeakAuras.class_ids = {}
WeakAuras.classes_sorted = {}
for _, classID in ipairs({1, 2, 3, 4, 5, 7, 8, 9, 11}) do
  local classInfo = C_CreatureInfo.GetClassInfo(classID)
  if classInfo then
    WeakAuras.class_ids[classInfo.classFile] = classInfo.classID
    tinsert(WeakAuras.classes_sorted, classInfo.classFile)
  end
end
table.sort(WeakAuras.classes_sorted)

do
  local talentCheckFrame = CreateFrame("Frame")
  Private.frames["ForeverAuras talentCheckFrame"] = talentCheckFrame
  talentCheckFrame:RegisterEvent("TRAIT_CONFIG_CREATED")
  talentCheckFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
  talentCheckFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
  talentCheckFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  talentCheckFrame:RegisterEvent("PLAYER_LOGIN")
  talentCheckFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

  --- @type table<number, {rank: number, spellId: number}>
  local selectedTalentsById = {}

  Private.CheckTalentsForLoad = function(event)
    Private.StartProfileSystem("talent")
    -- The talents changed: the cached reading of the player's tree is stale.
    if Private.InvalidateTalentData then Private.InvalidateTalentData() end
    selectedTalentsById = {}
    local configId = Private.GetTalentConfigID()
    if configId then
      local configInfo = C_Traits.GetConfigInfo(configId)
      if configInfo then
        for _, treeId in ipairs(configInfo.treeIDs) do
          local nodes = C_Traits.GetTreeNodes(treeId)
          for _, nodeId in ipairs(nodes) do
            local node = C_Traits.GetNodeInfo(configId, nodeId)
            if node and node.ID ~= 0 then
              for _, talentId in ipairs(node.entryIDs) do
                local entryInfo = C_Traits.GetEntryInfo(configId, talentId)
                if entryInfo and entryInfo.definitionID then
                  local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                  -- A talent counts as known from its first point. The client
                  -- reports a node's points in several fields (ranksPurchased,
                  -- currentRank, activeRank, activeEntry.rank), and on this
                  -- client a partly filled multi-rank talent did not show up in
                  -- the one that was read, so the highest of them is used.
                  -- Blizzard's own talent frame reads ranksPurchased for "has points".
                  local rank = math.max(node.ranksPurchased or 0, node.currentRank or 0, node.activeRank or 0)
                  if node.activeEntry then
                    rank = node.activeEntry.entryID == talentId and math.max(rank, node.activeEntry.rank or 0) or 0
                  end
                  if node.subTreeID then
                    local subTreeInfo = C_Traits.GetSubTreeInfo(configId, node.subTreeID)
                    if not subTreeInfo.isActive then
                      rank = 0
                    end
                  end
                  selectedTalentsById[talentId] = {
                    rank = rank,
                    spellId = definitionInfo and definitionInfo.spellID
                  }
                end
              end
            end
          end
        end
      end
    end
    Private.ScanForLoads(nil, "WA_TALENT_UPDATE")
    Private.ScanEvents("WA_TALENT_UPDATE")
    C_Timer.After(0, function() Private.CleanForeignTalentsAfterLogin() end)

    Private.StopProfileSystem("talent")
  end

  talentCheckFrame:SetScript("OnEvent", Private.CheckTalentsForLoad)

  ---@param talentId integer
  ---@return string? spellName
  ---@return number? icon
  ---@return number? spellId
  ---@return number? rank
  function WeakAuras.GetTalentById(talentId)
    if selectedTalentsById[talentId] then
      local spellName, _, icon = Private.ExecEnv.GetSpellInfo(selectedTalentsById[talentId].spellId)
      return spellName, icon, selectedTalentsById[talentId].spellId, selectedTalentsById[talentId].rank
    end
  end

  ---@param talentId integer
  ---@return boolean hasTalent
  function WeakAuras.CheckTalentId(talentId)
    return selectedTalentsById[talentId] and selectedTalentsById[talentId].rank > 0
  end

  local talentLoadKeys = {"talent", "talent2", "talent3"}

  local function ClearLoadOption(load, key)
    local changed = load["use_" .. key] ~= nil
    load["use_" .. key] = nil
    if type(load[key]) == "table" then
      if load[key].single ~= nil or next(load[key].multi or {}) then changed = true end
      load[key].single = nil
      load[key].multi = {}
    end
    return changed
  end

  -- Imports from another game version can carry a spec or talent choices
  -- this client does not have. They cannot be shown or cleared in the
  -- options, and the aura never loads, so they are removed.
  -- allowView: other specs' talents may be read (only while the options are open).
  -- A spec's talent entries do not change within a session.
  local validTalents = {}
  local function ValidTalents(specId)
    if validTalents[specId] then return validTalents[specId] end
    local talents = Private.GetTalentData(specId)
    if type(talents) ~= "table" or #talents < 20 then return end
    local valid = {}
    for _, talent in ipairs(talents) do valid[talent[1]] = true end
    validTalents[specId] = valid
    return valid
  end

  function Private.CleanForeignTalents(data, allowView)
    local load = data and data.load
    if type(load) ~= "table" then return false end
    local specId = load.class_and_spec and load.class_and_spec.single
    if load.use_class_and_spec == true and type(specId) == "number" and GetSpecializationInfoByID then
      local ownSpec = Private.ExecEnv.GetSpecialization()
      local ownSpecId = ownSpec and Private.ExecEnv.GetSpecializationInfo(ownSpec)
      if ownSpecId and GetSpecializationInfoByID(ownSpecId) and not GetSpecializationInfoByID(specId) then
        local changed = ClearLoadOption(load, "class_and_spec")
        for _, key in ipairs(talentLoadKeys) do changed = ClearLoadOption(load, key) or changed end
        return changed
      end
    end
    local hasTalents = false
    for _, key in ipairs(talentLoadKeys) do
      if load["use_" .. key] ~= nil and type(load[key]) == "table" then hasTalents = true end
    end
    if not hasTalents then return false end
    specId = Private.checkForSingleLoadCondition(load, "class_and_spec")
    if type(specId) ~= "number" then return false end
    local ownSpec = Private.ExecEnv.GetSpecialization()
    local ownSpecId = ownSpec and Private.ExecEnv.GetSpecializationInfo(ownSpec)
    if specId ~= ownSpecId and not allowView then return false end
    local valid = ValidTalents(specId)
    if not valid then return false end
    local changed = false
    for _, key in ipairs(talentLoadKeys) do
      local option = load[key]
      if load["use_" .. key] ~= nil and type(option) == "table" then
        for talentKey in pairs(option.multi or {}) do
          if not valid[tonumber(talentKey)] then
            option.multi[talentKey] = nil
            changed = true
          end
        end
        if option.single ~= nil and not valid[tonumber(option.single)] then
          option.single = nil
          changed = true
        end
        if option.single == nil and not next(option.multi or {}) then
          load["use_" .. key] = nil
          changed = true
        end
      end
    end
    return changed
  end

  local talentCleanupDone, talentRetry
  function Private.CleanForeignTalentsAfterLogin()
    if talentCleanupDone then return end
    if InCombatLockdown() then
      if not talentRetry then
        talentRetry = CreateFrame("Frame")
        talentRetry:SetScript("OnEvent", function(self)
          self:UnregisterEvent("PLAYER_REGEN_ENABLED")
          Private.CleanForeignTalentsAfterLogin()
        end)
      end
      talentRetry:RegisterEvent("PLAYER_REGEN_ENABLED")
      return
    end
    local ownSpec = Private.ExecEnv.GetSpecialization()
    local ownSpecId = ownSpec and Private.ExecEnv.GetSpecializationInfo(ownSpec)
    if not (ownSpecId and ValidTalents(ownSpecId)) then return end
    talentCleanupDone = true
    for _, data in pairs(Private.db and Private.db.displays or {}) do
      if Private.CleanForeignTalents(data, false) then WeakAuras.Add(data) end
    end
  end
end

---@param spellId integer
---@return boolean hasTalent
---@return number? spellid
function WeakAuras.CheckPvpTalentBySpellId(spellId)
  local checkTalentSlotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(1)
  if checkTalentSlotInfo then
    for i = 1, 3 do
      local talentSlotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(i)
      if talentSlotInfo and talentSlotInfo.selectedTalentID then
        local selectedSpellId = select(6, GetPvpTalentInfoByID(talentSlotInfo.selectedTalentID))
        if selectedSpellId == spellId then
          return true, spellId
        end
      end
    end
    return false, spellId
  end
  return false
end

---@param loadids string
---@param currentId string
---@return boolean result
function WeakAuras.CheckNumericIds(loadids, currentId)
  if (not loadids or not currentId) then
    return false;
  end

  local searchFrom = 0;
  local startI, endI = string.find(loadids, currentId, searchFrom);
  while (startI) do
    searchFrom = endI + 1; -- start next search from end
    if (startI == 1 or tonumber(string.sub(loadids, startI - 1, startI - 1)) == nil) then
      -- Either right at start, or character before is not a number
      if (endI == string.len(loadids) or tonumber(string.sub(loadids, endI + 1, endI + 1)) == nil) then
        return true;
      end
    end
    startI, endI = string.find(loadids, currentId, searchFrom);
  end
  return false;
end

---@param info any?
---@param val any
---@return boolean isNumeric
function WeakAuras.ValidateNumeric(info, val)
  if val ~= nil and val ~= "" and (not tonumber(val) or tonumber(val) >= 2^31) then
    return false;
  end
  return true
end

---@param info any?
---@param val any
---@return boolean isTime
function WeakAuras.ValidateTime(info, val)
  if val ~= nil and val ~= "" then
    if not tonumber(val) then
      if val:sub(1,1) == "-" then
        val = val:sub(2, #val)
      end
      return (val:match("^%d+:%d+:[%d%.]+$") or val:match("^%d+:[%d+%.]+$")) and true or false
    elseif tonumber(val) >= 2^31 then
      return false
    end
  end
  return true
end

---@param val number|string
---@return number? result
function WeakAuras.TimeToSeconds(val)
  if tonumber(val) then
    return tonumber(val)
  else
    local sign = 1
    if val:sub(1,1) == "-" then
      sign = -1
      val = val:sub(2, #val)
    end
    local h, m, s = val:match("^(%d+):(%d+):([%d%.]+)$")
    if h and m and s then
      return (h*3600 + m*60 + s) * sign
    else
      local m, s = val:match("^(%d+):([%d%.]+)$")
      if m and s then
        return (m*60 + s) * sign
      end
    end
  end
end

Private.tinySecondFormat = function(value)
  if type(value) == "string" then value = tonumber(value) end
  if type(value) == "number" then
     local negative = value < 0
     value = math.abs(value)
     local fraction = value - math.floor(value)
     local ret
     if value > 3600 then
        ret = ("%i:%02i:%02i"):format(math.floor(value / 3600), math.floor((value % 3600) / 60), value % 60)
     elseif value > 60 then
        ret = ("%i:%02i"):format(math.floor(value / 60), value % 60)
     else
        ret = ("%i"):format(value)
     end
     local negSign = negative and "-" or ""
     if fraction > 0 then
        return negSign .. ret .. tostring(Round(fraction * 100) / 100):sub(2)
     else
        return negSign .. ret
     end
  end
end

function Private.ExecEnv.ParseStringCheck(input)
  if not input or issecretvalue(input) then return end
  local matcher = {
    entries = {},
    negativeEntries = {},
    Check = function(self, e)
      return false
    end,
    CheckBoth = function(self, e)
      if issecretvalue(e) then return false end
      return self.entries[e] and not self.negativeEntries[e]
    end,
    CheckPositive = function(self, e)
      if issecretvalue(e) then return false end
      return self.entries[e]
    end,
    CheckNegative = function(self, e)
      if issecretvalue(e) then return false end
      return not self.negativeEntries[e]
    end,
    Add = function(self, e, negate)
      if issecretvalue(e) then return false end
      if negate then
        self.negativeEntries[e] = true
      else
        self.entries[e] = true
      end
    end
  }

  local start = 1
  local escaped = false
  local partial = ""
  local negate = false
  for i = 1, #input do
    local c = input:sub(i, i)
    if escaped then
      escaped = false
    elseif c == '\\' then
      partial = partial .. input:sub(start, i - 1)
      start = i + 1
      escaped = true
    elseif c == "," then
      matcher:Add(partial .. input:sub(start, i - 1):trim(), negate)
      start = i + 1
      partial = ""
      negate = false
    elseif c == "-" and partial:trim() == "" and input:sub(start, i - 1):trim() == "" then
      start = i + 1
      negate = true
    end
  end
  matcher:Add(partial .. input:sub(start, #input):trim(), negate)

  -- Update check function
  if next(matcher.entries) and next(matcher.negativeEntries) then
    matcher.Check = matcher.CheckBoth
  elseif next(matcher.entries) then
    matcher.Check = matcher.CheckPositive
  elseif next(matcher.negativeEntries) then
    matcher.Check = matcher.CheckNegative
  end

  return matcher
end

---@param info any?
---@param val string
---@return boolean result
function WeakAuras.ValidateNumericOrPercent(info, val)
  if val ~= nil and val ~= "" then
    local index = val:find("%% *$")
    local number = index and tonumber(val:sub(1, index-1)) or tonumber(val)
    if(not number or number >= 2^31) then
      return false;
    end
  end
  return true
end

function Private.ExecEnv.CheckMPlusAffixIds(loadids, currentId)
  if (not loadids or not currentId) or type(currentId) ~= "table" then
    return false
  end
  for i=1, #currentId do
    if loadids == currentId[i] then
      return true
    end
  end
  return false
end

function Private.ExecEnv.CheckGroupMemberType(loadSetting, currentFlags)
  if loadSetting == "LEADER" then
    return bit.band(currentFlags, 1) == 1
  elseif loadSetting == "ASSIST" then
    return bit.band(currentFlags, 2) == 2
  else
    return currentFlags == 0
  end
end

function Private.ExecEnv.CheckChargesDirection(direction, triggerDirection)
  return type(direction) == "number" and not issecretvalue(direction) and
      (triggerDirection == "CHANGED"
    or (triggerDirection == "GAINED" and direction > 0)
    or (triggerDirection == "LOST" and direction < 0))
end

function Private.ExecEnv.CheckCombatLogFlags(flags, flagToCheck)
  if type(flags) ~= "number" then return end
  if(flagToCheck == "Mine") then
    return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
  elseif (flagToCheck == "InGroup") then
    return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) == 0
  elseif (flagToCheck == "InParty") then
    return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0
  elseif (flagToCheck == "NotInGroup") then
    return bit.band(flags, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER) > 0
  end
end

function Private.ExecEnv.CheckCombatLogFlagsReaction(flags, flagToCheck)
  if type(flags) ~= "number" then return end
  if (flagToCheck == "Hostile") then
    return bit.band(flags, 64) ~= 0;
  elseif (flagToCheck == "Neutral") then
    return bit.band(flags, 32) ~= 0;
  elseif (flagToCheck == "Friendly") then
    return bit.band(flags, 16) ~= 0;
  end
end

local objectTypeToBit = {
  Object = 16384,
  Guardian = 8192,
  Pet = 4096,
  NPC = 2048,
  Player = 1024,
}

function Private.ExecEnv.CheckCombatLogFlagsObjectType(flags, flagToCheck)
  if type(flags) ~= "number" then return end
  local bitToCheck = objectTypeToBit[flagToCheck]
  if not bitToCheck then return end
  return bit.band(flags, bitToCheck) ~= 0;
end

function Private.ExecEnv.CheckRaidFlags(flags, flagToCheck)
  flagToCheck = tonumber(flagToCheck)
  if not flagToCheck or not flags then return end --bailout
  if flagToCheck == 0 then --no raid mark
    return bit.band(flags, COMBATLOG_OBJECT_RAIDTARGET_MASK) == 0
  elseif flagToCheck == 9 then --any raid mark
    return bit.band(flags, COMBATLOG_OBJECT_RAIDTARGET_MASK) > 0
  else -- specific raid mark
    return bit.band(flags, _G['COMBATLOG_OBJECT_RAIDTARGET'..flagToCheck]) > 0
  end
end

local function IsSpellKnownOrOverridesAndBaseIsKnown(spell, pet)
  if spell == 0 then return false end
  if IsSpellKnown(spell, pet) then
    return true
  end
  local baseSpell = FindBaseSpellByID(spell)
  if baseSpell and baseSpell ~= spell and baseSpell ~= 0 then
    if FindSpellOverrideByID(baseSpell) == spell then
      return IsSpellKnown(baseSpell, pet)
    end
  end
end

---@param spell string|number
---@return boolean result
function WeakAuras.IsPlayerSpellOrOverridesAndBaseIsPlayerSpell(spell)
  if spell == 0 or spell >= 2^31 then return false end
  if IsPlayerSpell(spell) then
    return true
  end
  local baseSpell = FindBaseSpellByID(spell)
  if baseSpell and baseSpell ~= spell and baseSpell ~= 0 then
    if FindSpellOverrideByID(baseSpell) == spell then
      return IsPlayerSpell(baseSpell)
    end
  end
  return false
end

---@private
function WeakAuras.IsSpellKnownForLoad(spell, exact)
  if spell == 0 or spell >= 2^31 then return false end
  local result = IsPlayerSpell(spell)
                 or IsSpellKnownOrOverridesAndBaseIsKnown(spell, false)
                 or IsSpellKnownOrOverridesAndBaseIsKnown(spell, true)
  if exact or result then
    return result
  end
  -- Dance through the spellname to the current spell id
  local spellName = Private.ExecEnv.GetSpellName(spell or "")
  if (spellName) then
    local otherSpell = select(7, Private.ExecEnv.GetSpellInfo(spellName))
    if otherSpell and otherSpell ~= spell then
      return WeakAuras.IsSpellKnownForLoad(otherSpell)
    end
  else
    -- ForeverAuras: no name yet. Spell data loads lazily on this client, so
    -- a rank the player does not know (the usual case for a Spell Known
    -- condition naming one rank, matched by name) can have no name at
    -- login; the load scan then said "not known" and nothing re-asked. The
    -- data is requested, and its arrival runs the load scan again.
    Private.RequestSpellKnownData(spell)
  end
end

-- ForeverAuras: see IsSpellKnownForLoad. One load scan per frame however
-- many requested spells arrive together. A spell the client reports it could
-- not load, or whose request threw, is not asked for again this session. A
-- scan wanted before login has finished waits for it (ScanForLoads declines
-- to run until then) rather than being dropped.
do
  local requested, failed = {}, {}
  local scanQueued = false
  local function RunScan()
    if not WeakAuras.IsLoginFinished() then
      C_Timer.After(1, RunScan)
      return
    end
    scanQueued = false
    Private.ScanForLoads(nil, "SPELLS_CHANGED")
  end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("SPELL_DATA_LOAD_RESULT")
  frame:SetScript("OnEvent", function(_, _, spellId, success)
    if issecretvalue(spellId) or not requested[spellId] then return end
    requested[spellId] = nil
    if issecretvalue(success) or success == false then
      failed[spellId] = true
      return
    end
    if scanQueued then return end
    scanQueued = true
    C_Timer.After(0, RunScan)
  end)
  function Private.RequestSpellKnownData(spell)
    if type(spell) ~= "number" or requested[spell] or failed[spell] or not (C_Spell and C_Spell.RequestLoadSpellData) then return end
    if C_Spell.DoesSpellExist and not C_Spell.DoesSpellExist(spell) then return end
    requested[spell] = true
    if not pcall(C_Spell.RequestLoadSpellData, spell) then
      requested[spell] = nil
      failed[spell] = true
    end
  end
end

---@param spell string|number
---@param pet boolean?
---@return boolean result
function WeakAuras.IsSpellKnown(spell, pet)
  if spell == 0 or spell >= 2^31 then return false end
  if (pet) then
    return IsSpellKnownOrOverridesAndBaseIsKnown(spell, true)
  end
  return IsPlayerSpell(spell) or IsSpellKnownOrOverridesAndBaseIsKnown(spell, false)
end

---@param spell string|number
---@return boolean result
function WeakAuras.IsSpellKnownIncludingPet(spell)
  if (not tonumber(spell)) then
    spell = select(7, Private.ExecEnv.GetSpellInfo(spell));
  end
  if (not spell) then
    return false;
  end
  return WeakAuras.IsSpellKnown(spell, false) or WeakAuras.IsSpellKnown(spell, true)
end

do
-- A small helper to fire WA_DELAYED_SET_INFORMATION if GetNumSetItemsEquipped couldn't give
-- accurate information due to item information being unavailable
  local waitingFor = { }

  local itemDataLoadFrame = CreateFrame("Frame")

  itemDataLoadFrame:SetScript("OnEvent", function(frame, event, itemId, success)
    if waitingFor[itemId] then
      waitingFor[itemId] = nil
      if success then
        Private.ScanEvents("WA_DELAYED_SET_INFORMATION")
      end
      if next(waitingFor) == nil then
        itemDataLoadFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
      end
    end
  end)

  -- Returns the set id OR causes WA_DELAYED_SET_INFORMATION after the item information is available
  function Private.GetSetId(itemId)
    if itemId  then
      local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, setID = C_Item.GetItemInfo(itemId)
      if not name then
        if next(waitingFor) == nil then
          itemDataLoadFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        end
        waitingFor[itemId] = true
      else
        return setID
      end
    end
  end

end

---@param setID integer
---@return integer? quantity
---@return integer? maxQuantity
---@return string? setName
function WeakAuras.GetNumSetItemsEquipped(setID)
  if not setID or not type(setID) == "number" then return end
  local equipped = 0
  local setName = C_Item.GetItemSetInfo(setID)
  for i = 1, 18 do
    local item = GetInventoryItemID("player", i)
    if Private.GetSetId(item) == setID then
      equipped = equipped + 1
    end
  end
  return equipped, 18, setName
end

---@return number result
function WeakAuras.GetEffectiveAttackPower(ranged)
  local base, pos, neg
  if ranged then
    base, pos, neg = UnitRangedAttackPower("player")
  else
    base, pos, neg = UnitAttackPower("player")
  end
  if hasanysecretvalues(base, pos, neg) then
    return 0
  end
  return base + pos + neg
end

--- @type fun(): number
function WeakAuras.GetEffectiveSpellPower()
  if C_Secrets.ShouldUnitStatsBeSecret() then
    return 0
  end
  -- Straight from the PaperDoll
  local spellPower = 0
  for i = 2, MAX_SPELL_SCHOOLS or 7 do
    spellPower = max(spellPower, GetSpellBonusDamage(i))
  end
  return spellPower
end

local function valuesForTalentFunction(trigger)
  return function()
    local single_class = Private.checkForSingleLoadCondition(trigger, "class")
    if not single_class then
      single_class = select(2, UnitClass("player"));
    end

    -- If a single specific class was found, load the specific list for it
    do
      local single_class_and_spec = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
      if single_class_and_spec then
        return Private.GetTalentData(single_class_and_spec)
      else
        -- this should never happen
        return {}
      end
    end
  end
end

local function valuesForHeroTalentFunction(trigger)
  return function()
    local single_class_and_spec = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
    if single_class_and_spec then
      return select(2, Private.GetTalentData(single_class_and_spec))
    else
      -- this should never happen
      return {}
    end
  end
end

---helper to check if a condition is checked and have a single value, and return it
---@param trigger table
---@param name string
---@param validateFn? fun(value: any): boolean values that do not validate are ignored
---@return any
function Private.checkForSingleLoadCondition(trigger, name, validateFn)
  local use_name = "use_"..name
  local trigger_use_name = trigger[use_name]
  local trigger_name = trigger[name]
  if trigger_use_name == true
  and trigger_name
  and trigger_name.single ~= nil
  and (validateFn == nil or validateFn(trigger_name.single))
  then
    return trigger_name.single
  end
  if trigger_use_name == false and trigger_name and trigger_name.multi ~= nil then
    local count = 0
    local key
    for k, v in pairs(trigger_name.multi) do
      if v ~= nil
      and (validateFn == nil or validateFn(k))
      then
        count = count + 1
        key = k
      end
    end
    if count == 1 then
      return key
    end
  end
end

Private.load_prototype = {
  -- Each entry
  --   name: name of argument for load function/option for options/setting in saved data
  --   Options data
  --     display: name to be displayed in the options
  --     type: type to be used for the options
  --     width: width in the options
  --     hidden: whether the option is shown in the options, defaults to false
  --   Load Function Data
  --     enable: whether the test should be tested or not, defaults to true
  --     test: overrides the default test
  --     init: whether the argument should be a function parameter or not. "arg" for yes. Defaults to no argument
  --     events: the events on which the test must be reevaluated
  --     optional: whether the test is relevant for the options classification between loaded and unloaded, defaults to false
  args = {
    {
      name ="generalTitle",
      display = L["General"],
      type = "description",
    },
    {
      name = "combat",
      display = L["In Combat"],
      type = "tristate",
      width = WeakAuras.normalWidth,
      init = "arg",
      optional = true,
      events = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}
    },
    {
      name = "never",
      display = L["Never"],
      type = "toggle",
      width = WeakAuras.normalWidth,
      test = "false",
    },
    {
      name = "alive",
      display = L["Alive"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      events = {"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST"}
    },
    {
      name = "encounter",
      display = L["In Encounter"],
      type = "tristate",
      width = WeakAuras.normalWidth,
      init = "arg",
      optional = true,
      events = {"ENCOUNTER_START", "ENCOUNTER_END"}
    },
    {
      name = "warmode",
      display = L["In War Mode"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      enable = false,
      hidden = true,
      events = {"PLAYER_FLAGS_CHANGED"}
    },
    {
      name = "pvpmode",
      display = L["PvP Mode Active"],
      type = "tristate",
      init = nil,
      width = WeakAuras.normalWidth,
      optional = true,
      enable = false,
      hidden = true,
      events = {"PLAYER_FLAGS_CHANGED", "UNIT_FACTION", "ZONE_CHANGED"}
    },
    {
      name = "petbattle",
      display = L["In Pet Battle"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      enable = false,
      hidden = true,
      events = {"PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE"}
    },
    {
      name = "vehicle",
      display = (false) and L["On Taxi"] or L["In Vehicle"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      events = (false) and {"UNIT_FLAGS"}
               or {"VEHICLE_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UPDATE_OVERRIDE_ACTIONBAR", "UNIT_FLAGS"}
    },
    {
      name = "vehicleUi",
      display = L["Has Vehicle UI"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      enable = true,
      hidden = false,
      events = {"VEHICLE_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR"}
    },
    {
      name = "dragonriding",
      display = L["Skyriding"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      enable = false,
      hidden = true,
      events = {"WA_DRAGONRIDING_UPDATE"}
    },
    {
      name = "mounted",
      display = L["Mounted"],
      type = "tristate",
      init = "arg",
      width = WeakAuras.normalWidth,
      optional = true,
      events = {"PLAYER_MOUNT_DISPLAY_CHANGED"}
    },
    {
      name = "addonRestrictionsActive",
      display = L["Secret Restrictions Active"],
      type = "tristate",
      init = "arg",
      optional = true,
      events = {"WA_SECRET_STATE_UPDATE"},
      desc = L["Whether addon secret restrictions applied by Combat, Encounter, PvP match or active Mythic+ dungeon are currently active."],
    },
    {
      name = "hardcore",
      display = L["Hardcore"],
      type = "tristate",
      init = nil,
      width = WeakAuras.normalWidth,
      enable = false,
      hidden = true,
    },
    {
      name = "engraving",
      display = L["Season of Discovery"],
      type = "tristate",
      init = nil,
      width = WeakAuras.normalWidth,
      enable = false,
      hidden = true,
    },
    -- ForeverAuras: Load Flag. The display loads while another aura (usually a
    -- group's backend) has set the named flag with
    -- ForeverAuras.SetLoadFlag(name, true). Flags last for the session, so the
    -- backend sets them on every login; see ForeverAuras.SetLoadFlag in
    -- ForeverAuras.lua. "FA_LOAD_FLAG" is not a game event: SetLoadFlag
    -- rescans the displays recorded under it itself.
    {
      name = "loadFlag",
      display = WeakAuras.newFeatureString .. L["Load Flag"],
      type = "string",
      width = WeakAuras.doubleWidth,
      test = "ForeverAuras.LoadFlag(%q)",
      events = {"FA_LOAD_FLAG"},
      desc = L["Loads while an aura has set this flag with ForeverAuras.SetLoadFlag(name, true), for example a group's backend choosing which children to load from its custom options."],
    },
    {
      name ="playerTitle",
      display = L["Player"],
      type = "description",
    },
    {
      name = "class",
      display = L["Player Class"],
      type = "multiselect",
      values = "class_types",
      init = nil,
      enable = false,
      hidden = true,
    },
    {
      name = "class_and_spec",
      display = L["Player Class"],
      type = "multiselect",
      values = "spec_types_all",
      init = "arg",
      enable = true,
      hidden = false,
      events = {"PLAYER_TALENT_UPDATE"},
      sorted = true,
      sortOrder = Private.specs_sorted,
    },
    -- A separate opt-in load filter preserves existing Player Class imports.
    -- The normal load event system reevaluates it when talents/spells change.
    {
      name = "forever_spec",
      display = L["Specialization"],
      type = "multiselect",
      values = "forever_spec_types",
      test = "Private.ExecEnv.IsForeverSpecialization(%s)",
      -- Forever 1.60 talents are a trait config: its updates and the switch
      -- between the Primary and Secondary builds re-evaluate the tree.
      events = {"SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_ENTERING_WORLD",
        "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_SPECIALIZATION_CHANGED"},
      sorted = true,
      sortOrder = Private.forever_specs_sorted,
      -- Clicking cycles each tree: off, green (load for it), red (never load for it).
      multiTristate = true,
      checkControl = "ForeverAurasTriCheckBox",
      multiSetTest = function(multi)
        local positive, negative = {}, {}
        for key, state in pairs(multi) do
          if state == true then positive[#positive + 1] = ("[%q] = true"):format(key)
          elseif state == false then negative[#negative + 1] = ("[%q] = true"):format(key) end
        end
        return ("Private.ExecEnv.ForeverSpecLoad({%s}, {%s})"):format(table.concat(positive, ", "), table.concat(negative, ", "))
      end,
      desc = "Your specialization is the talent tree with 21 or more points; with several, the one with the most points. Click a tree once to load for it (green), twice to never load for it (red). With only red trees, every other tree loads. Feral Combat includes both cat and bear builds.",
    },
    {
      name = "talent",
      display = L["Talent"],
      type = "multiselect",
      values = valuesForTalentFunction,
      test = "WeakAuras.CheckTalentId(%d) == (%d == 4)",
      enableTest = function(trigger, talent)
        return type(talent) == "number" and talent > 0
      end,
      multiConvertKey = function(trigger, key)
        local specId = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
        if specId then
          local talentData = Private.GetTalentData(specId)
          if type(talentData) == "table" and talentData[key] then
            return talentData[key][1]
          end
        end
      end or nil,
      events = {"WA_TALENT_UPDATE"},
      inverse = function(load)
        -- Check for multi select!
        return false
      end,
      extraOption = false,
      control = "WeakAurasMiniTalent",
      multiNoSingle = true, -- no single mode
      multiTristate = true, -- values can be true/false/nil
      multiAll = true, -- require all tests
      orConjunctionGroup = "talent",
      multiUseControlWhenFalse = true,
      enable = function(trigger)
        return Private.checkForSingleLoadCondition(trigger, "class_and_spec") ~= nil
      end,
      hidden = function(trigger)
        return not (
            Private.checkForSingleLoadCondition(trigger, "class_and_spec") ~= nil)
      end,
    },
    {
      name = "talent2",
      display = L["Or Talent"] or L["And Talent"],
      type = "multiselect",
      values = valuesForTalentFunction,
      test = "WeakAuras.CheckTalentId(%d) == (%d == 4)",
      enableTest = function(trigger, talent)
        return type(talent) == "number" and talent > 0
      end,
      multiConvertKey = function(trigger, key)
        local specId = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
        if specId then
          local talentData = Private.GetTalentData(specId)
          if type(talentData) == "table" and talentData[key] then
            return talentData[key][1]
          end
        end
      end or nil,
      events = {"WA_TALENT_UPDATE"},
      inverse = function(load)
        return false
      end,
      extraOption = false,
      control = "WeakAurasMiniTalent",
      multiNoSingle = true, -- no single mode
      multiTristate = true, -- values can be true/false/nil
      multiAll = true, -- require all tests
      orConjunctionGroup  = "talent",
      multiUseControlWhenFalse = true,
      enable = function(trigger)
        return (trigger.use_talent ~= nil or trigger.use_talent2 ~= nil) and (
          Private.checkForSingleLoadCondition(trigger, "class_and_spec") ~= nil
        )
      end,
      hidden = function(trigger)
        return not((trigger.use_talent ~= nil or trigger.use_talent2 ~= nil) and (
          Private.checkForSingleLoadCondition(trigger, "class_and_spec") ~= nil)
        )
      end,
    },
    {
      name = "talent3",
      display = L["Or Talent"] or L["And Talent"],
      type = "multiselect",
      values = valuesForTalentFunction,
      test = "WeakAuras.CheckTalentId(%d) == (%d == 4)",
      enableTest = function(trigger, talent)
        return type(talent) == "number" and talent > 0
      end,
      multiConvertKey = function(trigger, key)
        local specId = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
        if specId then
          local talentData = Private.GetTalentData(specId)
          if type(talentData) == "table" and talentData[key] then
            return talentData[key][1]
          end
        end
      end or nil,
      events = {"WA_TALENT_UPDATE"},
      inverse = function(load)
        return false
      end,
      extraOption = false,
      control = "WeakAurasMiniTalent",
      multiNoSingle = true, -- no single mode
      multiTristate = true, -- values can be true/false/nil
      multiAll = true, -- require all tests
      orConjunctionGroup  = "talent",
      multiUseControlWhenFalse = true,
      enable = function(trigger)
        return ((trigger.use_talent ~= nil and trigger.use_talent2 ~= nil) or trigger.use_talent3 ~= nil) and (
          Private.checkForSingleLoadCondition(trigger, "class_and_spec") ~= nil
        )
      end,
      hidden = function(trigger)
        return not(((trigger.use_talent ~= nil and trigger.use_talent2 ~= nil) or trigger.use_talent3 ~= nil) and (
          Private.checkForSingleLoadCondition(trigger, "class_and_spec") ~= nil
        ))
      end
    },
    {
      name = "herotalent",
      display = L["Hero Talent"],
      type = "multiselect",
      values = valuesForHeroTalentFunction,
      test = "WeakAuras.CheckTalentId(%d) == (%d == 4)",
      enableTest = function(trigger, talent, arg)
        local specId = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
        if specId then
          local _, heroData = Private.GetTalentData(specId)
          if type(heroData) == "table" then
            for _, v in ipairs(heroData) do
              if talent == v[1] then
                return true
              end
            end
          end
        end
      end,
      multiConvertKey = function(trigger, key)
        local specId = Private.checkForSingleLoadCondition(trigger, "class_and_spec")
        if specId then
          local _, heroData = Private.GetTalentData(specId)
          if type(heroData) == "table" and type(heroData[key]) == "table" then
            return heroData[key][1]
          end
        end
      end or nil,
      events = {"WA_TALENT_UPDATE"},
      control = "WeakAurasMiniTalent",
      multiNoSingle = true, -- no single mode
      multiTristate = true, -- values can be true/false/nil
      multiAll = true, -- require all tests
      orConjunctionGroup = "herotalent",
      multiUseControlWhenFalse = true,
      enable = false,
      hidden = true,
    },
    {
      name = "glyph",
      display = L["Glyph"],
      type = "multiselect",
      values = "glyph_types",
      sorted = true,
      sortOrder = Private.glyph_sorted or {},
      test = "WeakAuras.IsGlyphActive(%s)",
      events = {"GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED", "USE_GLYPH"},
      enable = false,
      hidden = true,
    },
    {
      name = "spellknown",
      display = L["Spell Known"],
      type = "spell",
      test = "WeakAuras.IsSpellKnownForLoad(%s, %s)",
      events = {"SPELLS_CHANGED", "UNIT_PET"},
      showExactOption = true
    },
    {
      name = "not_spellknown",
      display = WeakAuras.newFeatureString .. L["|cFFFF0000Not|r Spell Known"],
      type = "spell",
      test = "not WeakAuras.IsSpellKnownForLoad(%s, %s)",
      events = {"SPELLS_CHANGED", "UNIT_PET"},
      showExactOption = true
    },
    {
      name = "player",
      init = "arg",
      enable = false,
      hidden = true
    },
    {
      name = "realm",
      init = "arg",
      enable = false,
      hidden = true
    },
    {
      name = "guild",
      init = "arg",
      enable = false,
      hidden = true
    },
    {
      name = "namerealm",
      display = L["Player Name/Realm"],
      type = "string",
      multiline = true,
      test = "nameRealmChecker:Check(player, realm)",
      preamble = "local nameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
      desc = constants.nameRealmFilterDesc,
    },
    {
      name = "ignoreNameRealm",
      display = L["|cFFFF0000Not|r Player Name/Realm"],
      type = "string",
      multiline = true,
      test = "not nameRealmIgnoreChecker:Check(player, realm)",
      preamble = "local nameRealmIgnoreChecker = Private.ExecEnv.ParseNameCheck(%q)",
      desc = constants.nameRealmFilterDesc,
    },
    {
      name = "guildcheck",
      display = L["Guild"],
      type = "string",
      multiline = true,
      test = "guildChecker:Check(guild)",
      preamble = "local guildChecker = Private.ExecEnv.ParseStringCheck(%q)",
      desc = constants.guildFilterDesc,
      events = {"PLAYER_GUILD_UPDATE"}
    },
    {
      name = "race",
      display = L["Player Race"],
      type = "multiselect",
      values = "race_types",
      init = "arg"
    },
    {
      name = "faction",
      display = L["Player Faction"],
      type = "multiselect",
      values = "faction_group",
      init = "arg"
    },
    {
      name = "level",
      display = L["Player Level"],
      type = "number",
      init = "arg",
      events = {"PLAYER_LEVEL_UP"},
      multiEntry = {
        operator = "and",
        limit = 2
      },
    },
    {
      name = "effectiveLevel",
      display = L["Player Effective Level"],
      type = "number",
      init = "arg",
      desc = L["The effective level differs from the level in e.g. Time Walking dungeons."],
      enable = false,
      hidden = true,
      events = {"PLAYER_LEVEL_UP", "UNIT_FLAGS", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA"},
      multiEntry = {
        operator = "and",
        limit = 2
      },
    },
    {
      name = "role",
      display = L["Spec Role"],
      type = "multiselect",
      values = "role_types",
      init = "arg",
      enable = true,
      hidden = false,
      events = {"PLAYER_ROLES_ASSIGNED", "PLAYER_TALENT_UPDATE"}
    },
    {
      name = "spec_position",
      display = WeakAuras.newFeatureString .. L["Spec Position"],
      type = "multiselect",
      values = "spec_position_types",
      init = "arg",
      enable = false,
      hidden = true,
      events = {"ACTIVE_TALENT_GROUP_CHANGED"}
    },
    {
      name = "raid_role",
      display = L["Raid Role"],
      type = "multiselect",
      values = "raid_role_types",
      init = nil,
      enable = false,
      hidden = true,
      events = {"PLAYER_ROLES_ASSIGNED"}
    },
    {
      name = "ingroup",
      display = L["Group Type"],
      type = "multiselect",
      width = WeakAuras.normalWidth,
      init = "arg",
      values = "group_types",
      events = {"GROUP_ROSTER_UPDATE"},
      optional = true,
    },
    {
      name = "groupSize",
      display = L["Group Size"],
      type = "number",
      init = "arg",
      events = {"GROUP_ROSTER_UPDATE"},
      multiEntry = {
        operator = "and",
        limit = 2
      },
      optional = true,
    },
    {
      name = "group_leader",
      display = WeakAuras.newFeatureString .. L["Group Leader/Assist"],
      type = "multiselect",
      init = "arg",
      events = {"PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE"},
      width = WeakAuras.doubleWidth,
      values = "group_member_types",
      test = "Private.ExecEnv.CheckGroupMemberType(%s, group_leader)",
      optional = true,
    },
    {
      name ="locationTitle",
      display = L["Location"],
      type = "description",
    },
    {
      name = "zone",
      display = L["Zone Name"],
      type = "string",
      multiline = true,
      init = "arg",
      preamble = "local checker = Private.ExecEnv.ParseStringCheck(%q)",
      test = "checker:Check(zone)",
      events = {"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "VEHICLE_UPDATE"},
      desc = L["Supports multiple entries, separated by commas. Escape ',' with \\. Prefix with '-' for negation."],
      optional = true,
    },
    {
      name = "zoneId",
      enable = false,
      hidden = true,
      init = "arg",
      optional = true,
    },
    {
      name = "zonegroupId",
      enable = false,
      hidden = true,
      init = "arg",
      optional = true,
    },
    {
      name = "instanceId",
      enable = false,
      hidden = true,
      init = "arg",
      optional = true,
    },
    {
      name = "minimapZoneText",
      enable = false,
      hidden = true,
      init = "arg",
      optional = true,
    },
    {
      name = "zoneIds",
      display = L["Player Location ID(s)"],
      type = "string",
      multiline = true,
      events = {"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "VEHICLE_UPDATE", "WA_DELAYED_PLAYER_ENTERING_WORLD"},
      desc = get_zoneId_list,
      preamble = "local zoneChecker = Private.ExecEnv.ParseZoneCheck(%q)",
      test = "zoneChecker:Check(zoneId, zonegroupId, instanceId, minimapZoneText)",
      optional = true,
    },
    {
      name = "encounterid",
      display = L["Encounter ID(s)"],
      type = "string",
      init = "arg",
      multiline = true,
      desc = Private.get_encounters_list,
      test = "WeakAuras.CheckNumericIds(%q, encounterid)",
      events = {"ENCOUNTER_START", "ENCOUNTER_END"},
      optional = true,
    },
    {
      name = "enabledBossModID",
      display = L["Enabled BossMod ID(BW Only)"],
      type = "string",
      multiline = true,
      desc = Private.get_encounters_list,
      preamble = "local bossModChecker = Private.ExecEnv.ParseBossModCheck(%q)",
      test = "bossModChecker:Check()",
      events = {"WA_BOSSMOD_ENABLED_STATE_CHANGED"},
      optional = true,
    },
    {
      name = "size",
      display = L["Instance Size Type"],
      type = "multiselect",
      values = "instance_types",
      sorted = true,
      init = "arg",
      events = {"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "WA_DELAYED_PLAYER_ENTERING_WORLD"},
      optional = true,
    },
    {
      name = "difficulty",
      display = L["Instance Difficulty"],
      type = "multiselect",
      values = "difficulty_types",
      init = "arg",
      enable = true,
      hidden = false,
      events = {"PLAYER_DIFFICULTY_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "WA_DELAYED_PLAYER_ENTERING_WORLD"},
      optional = true,
    },
    {
      name = "instance_type",
      display = L["Instance Type"],
      type = "multiselect",
      values = "instance_difficulty_types",
      sorted = true,
      init = "arg",
      enable = true,
      hidden = false,
      events = {"PLAYER_DIFFICULTY_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "WA_DELAYED_PLAYER_ENTERING_WORLD"},
      optional = true,
    },
    {
      name = "affixes",
      display = L["Mythic+ Affix"],
      type = "multiselect",
      values = "mythic_plus_affixes",
      init = "arg",
      test = "Private.ExecEnv.CheckMPlusAffixIds(%d, affixes)",
      enable = false,
      hidden = true,
      events = {"CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED"},
      optional = true,
    },
    {
      name ="equipmentTitle",
      display = L["Equipment"],
      type = "description",
    },
    {
      name = "itemequiped",
      display = L["Item Equipped"],
      type = "item",
      multiEntry = {
        operator = "or"
      },
      test = "C_Item.IsEquippedItem(%s or '')",
      events = { "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED"},
      only_exact = true,
    },
    {
      name = "not_itemequiped",
      display = WeakAuras.newFeatureString .. L["|cFFFF0000Not|r Item Equipped"],
      type = "item",
      multiEntry = {
        operator = "or"
      },
      test = "not C_Item.IsEquippedItem(%s or '')",
      events = { "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED"},
      only_exact = true,
    },
    {
      name = "itemtypeequipped",
      display = L["Item Type Equipped"],
      type = "multiselect",
      test = "C_Item.IsEquippedItemType(Private.ExecEnv.GetItemSubClassInfo(%s) or '')",
      events = { "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED"},
      values = "item_weapon_types"
    },
    {
      name = "item_bonusid_equipped",
      display =  L["Item Bonus Id Equipped"],
      type = "string",
      test = "WeakAuras.CheckForItemBonusId(%q)",
      events = { "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED"},
      desc = L["Supports multiple entries, separated by commas"]
    },
    {
      name = "not_item_bonusid_equipped",
      display =  WeakAuras.newFeatureString .. L["|cFFFF0000Not|r Item Bonus Id Equipped"],
      type = "string",
      test = "not WeakAuras.CheckForItemBonusId(%q)",
      events = { "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED"},
      desc = L["Supports multiple entries, separated by commas"]
    }
  }
};

local function AddUnitChangeInternalEvents(triggerUnit, t, includePets, unitisunit)
  if (triggerUnit == nil) then
    return
  end
  if (triggerUnit == "multi") then
    -- Handled by normal events"
  elseif triggerUnit == "pet" then
    tinsert(t, "PET_UPDATE")
  else
    if Private.multiUnitUnits[triggerUnit] then
      local isPet
      for unit in pairs(Private.multiUnitUnits[triggerUnit]) do
        isPet = WeakAuras.UnitIsPet(unit)
        if (includePets ~= nil and isPet) or (includePets ~= "PetsOnly" and not isPet) then
          tinsert(t, "UNIT_CHANGED_" .. string.lower(unit))
          if unitisunit then
            tinsert(t, "UNIT_IS_UNIT_CHANGED_" .. string.lower(unit) .. "_" .. string.lower(unitisunit))
          end
        end
      end
    else
      tinsert(t, "UNIT_CHANGED_" .. string.lower(triggerUnit))
      if unitisunit then
        tinsert(t, "UNIT_IS_UNIT_CHANGED_" .. string.lower(triggerUnit) .. "_" .. string.lower(unitisunit))
      end
    end
  end
end

local function AddWatchedUnits(triggerUnit, includePets, unitisunit)
  if (triggerUnit == nil) then
    return
  end
  if (triggerUnit == "multi") then
    -- Handled by normal events"
  elseif triggerUnit == "pet" then
    WeakAuras.WatchForPetDeath();
  else
    if Private.multiUnitUnits[triggerUnit] then
      local isPet
      for unit in pairs(Private.multiUnitUnits[triggerUnit]) do
        isPet = WeakAuras.UnitIsPet(unit)
        if (includePets ~= nil and isPet) or (includePets ~= "PetsOnly" and not isPet) then
          if unitisunit then
            WeakAuras.WatchUnitChange(unitisunit)
          end
          WeakAuras.WatchUnitChange(unit)
        end
      end
    else
      if unitisunit then
        WeakAuras.WatchUnitChange(unitisunit)
      end
      WeakAuras.WatchUnitChange(triggerUnit)
    end
  end
end

local function AddUnitSpecChangeInternalEvents(triggerUnit, t)
  if Private.multiUnitUnits[triggerUnit] then
    for unit in pairs(Private.multiUnitUnits[triggerUnit]) do
      local isPet = WeakAuras.UnitIsPet(unit)
      if (not isPet) then
        tinsert(t, "UNIT_SPEC_CHANGED_" .. string.lower(unit))
      end
    end
  end
end

local function AddUnitRoleChangeInternalEvents(triggerUnit, t)
  if (triggerUnit == nil) then
    return
  end

  if Private.multiUnitUnits[triggerUnit] then
    for unit in pairs(Private.multiUnitUnits[triggerUnit]) do
      if not WeakAuras.UnitIsPet(unit) then
        tinsert(t, "UNIT_ROLE_CHANGED_" .. string.lower(unit))
      end
    end
  else
    if not WeakAuras.UnitIsPet(triggerUnit) then
      tinsert(t, "UNIT_ROLE_CHANGED_" .. string.lower(triggerUnit))
    end
  end
end

local function AddRemainingCastInternalEvents(triggerUnit, t)
  if (triggerUnit == nil) then
    return
  end

  if Private.multiUnitUnits[triggerUnit] then
    for unit in pairs(Private.multiUnitUnits[triggerUnit]) do
      tinsert(t, "CAST_REMAINING_CHECK_" .. string.lower(unit))
    end
  else
    tinsert(t, "CAST_REMAINING_CHECK_" .. string.lower(triggerUnit))
  end
end

local function AddUnitEventForEvents(result, unit, event)
  if unit then
    if not result.unit_events then
      result.unit_events = {}
    end
    if not result.unit_events[unit] then
      result.unit_events[unit] = {}
    end
    tinsert(result.unit_events[unit], event)
  else
    if not result.events then
      result.events = {}
    end
    tinsert(result.events, event)
  end
end

local function AddTargetConditionEvents(result, useFocus)
  do
    if useFocus then
      tinsert(result, "PLAYER_FOCUS_CHANGED")
    end
  end
  tinsert(result, "PLAYER_SOFT_ENEMY_CHANGED")
  tinsert(result, "PLAYER_SOFT_FRIEND_CHANGED")
  tinsert(result, "PLAYER_TARGET_CHANGED")
  return result
end

Private.AddTargetConditionEvents = AddTargetConditionEvents

local unitHelperFunctions = {
  UnitChangedForceEventsWithPets = function(trigger)
    local events = {}
    local includePets = trigger.use_includePets == true and trigger.includePets or nil
    if Private.multiUnitUnits[trigger.unit] then
      local isPet
      for unit in pairs(Private.multiUnitUnits[trigger.unit]) do
        isPet = WeakAuras.UnitIsPet(unit)
        if (includePets ~= nil and isPet) or (includePets ~= "PetsOnly" and not isPet) then
          tinsert(events, {"UNIT_CHANGED_" .. unit, unit})
        end
      end
    else
      if trigger.unit then
        tinsert(events, {"UNIT_CHANGED_" .. trigger.unit, trigger.unit})
      end
    end
    return events
  end,

  UnitChangedForceEvents = function(trigger)
    local events = {}
    if Private.multiUnitUnits[trigger.unit] then
      for unit in pairs(Private.multiUnitUnits[trigger.unit]) do
        if not WeakAuras.UnitIsPet(unit) then
          tinsert(events, {"UNIT_CHANGED_" .. unit, unit})
        end
      end
    else
      if trigger.unit then
        tinsert(events, {"UNIT_CHANGED_" .. trigger.unit, trigger.unit})
      end
    end
    return events
  end,

  SpecificUnitCheck = function(trigger)
    if not trigger.use_specific_unit then
      return "local specificUnitCheck = true\n"
    end

    if trigger.unit == nil then
      return "local specificUnitCheck = false\n"
    end

    return string.format([=[
      local specificUnitCheck = Private.ExecEnv.UnitIsUnit(%q, unit)
    ]=], trigger.unit or "")
  end
}

Private.event_categories = {
  cdm = {name = "Blizzard Cooldown Manager", default = "Blizzard Cooldown Manager"},
  spell = {
    name = L["Spell"],
    default = "Cooldown Progress (Spell)"
  },
  item = {
    name = L["Item"],
    default = "Cooldown Progress (Item)"
  },
  unit = {
    name = L["Player/Unit Info"],
    default = "Conditions"
  },
  addons = {
    name = L["Other Addons"],
    default = "GTFO"
  },
  combatlog = {
    name = L["Combat Log"],
    default = "Combat Log",
  },
  event = {
    name = L["Other Events"],
    default = "Chat Message"
  },
  custom = {
    name = L["Custom"],
  }
}

local GetNameAndIconForSpellName = function(trigger)
  if type(trigger.spellName) == "table" then return end
  local effectiveSpellId = Private.ExecEnv.GetEffectiveSpellId(trigger.spellName, trigger.use_exact_spellName, not trigger.use_ignoreoverride)
  local name, _, icon = Private.ExecEnv.GetSpellInfo(effectiveSpellId)
  return name, icon
end

local castReadableArgs = {
  {"spellNames", "Name(s)"}, {"spellIds", "Exact Spell ID(s)"}, {"spellId", "Spell ID"}, {"spell", "Spellname"},
  {"interruptible", "Interruptible"}, {"remaining", "Remaining Time"},
  {"empowered", "Empowered"}, {"stage", "Stage"}, {"stageTotal", "Stage Total"}, {"charged", "Charged"},
}
local castSpellArgs = {spellNames = true, spellIds = true}

local function CastSpellNeverSecret(value)
  if not (C_Secrets and C_Secrets.GetSpellCastSecrecy and Enum and Enum.SecrecyLevel) then return false end
  local id = tonumber(value)
  if not id then
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(value)
    id = info and info.spellID
  end
  if not id or issecretvalue(id) then return false end
  local ok, secrecy = pcall(C_Secrets.GetSpellCastSecrecy, id)
  return ok and not issecretvalue(secrecy) and secrecy == Enum.SecrecyLevel.NeverSecret
end

function Private.PowerFilterable(trigger)
  return trigger.use_powertype == true and trigger.powertype == 4
end

function Private.PlayerUnitTrigger(trigger)
  return (trigger.unit or "player") == "player"
end

function Private.CurveCombatStatus(kind, trigger, data, triggernum)
  trigger = type(trigger) == "table" and trigger or {}
  if kind == "power" and trigger.use_powertype and trigger.powertype == 99 then
    return "|cffff2020Won't work in combat:|r Stagger checks."
  end
  local report = data and triggernum and Private.CurveCombatReport(data, triggernum)
  if not report then return "|cff33ff99Works in combat.|r" end
  local lines = {}
  local filters = report.filters or {}
  if #report.works > 0 then
    lines[#lines + 1] = "|cff33ff99Works in combat:|r " .. table.concat(report.works, "; ") .. "."
  end
  lines[#lines + 1] = "|cff33ff99You can use Conditions on " .. (kind == "power" and "Power" or "Health")
    .. " values to change Alpha and Color, in and out of combat.|r"
  for _, line in ipairs(filters) do lines[#lines + 1] = line end
  if #report.notes > 0 then lines[#lines + 1] = "|cffff9933" .. table.concat(report.notes, " ") .. "|r" end
  if #report.fails > 0 then
    lines[#lines + 1] = "|cffff2020Won't work in combat:|r " .. table.concat(report.fails, "; ") .. "."
  end
  return table.concat(lines, "\n")
end

function Private.CastCombatStatus(trigger)
  trigger = type(trigger) == "table" and trigger or {}
  local unit = trigger.unit or "player"
  if unit == "member" and type(trigger.specificUnit) == "string" and trigger.specificUnit:lower() == "player" then unit = "player" end
  if unit == "player" then return "|cff33ff99Works in combat.|r" end
  local blocked = {}
  for _, entry in ipairs(castReadableArgs) do
    local key, label = entry[1], entry[2]
    if trigger["use_" .. key] ~= nil then
      local readable = false
      if castSpellArgs[key] and type(trigger[key]) == "table" and #trigger[key] > 0 then
        readable = true
        for _, value in ipairs(trigger[key]) do
          if not CastSpellNeverSecret(value) then readable = false; break end
        end
      end
      if not readable then blocked[#blocked + 1] = label end
    end
  end
  -- ForeverAuras: on this server another unit's spell is secret in and out
  -- of combat (probed in game: the cast event's spell ID and UnitCastingInfo's
  -- are both secret for a party member out of combat), not only in combat.
  if #blocked > 0 then
    return "|cffff2020" .. L["Won't match:"] .. "|r " .. table.concat(blocked, ", ")
      .. ". |cffff9933" .. L["Another unit's spell is secret on this server, in and out of combat; only your own casts can be filtered by spell."] .. "|r"
  end
  return "|cffff9933" .. L["Another unit's casts are secret on this server, in and out of combat: they show with their bar and timer, but cannot be filtered by spell."] .. "|r"
end

Private.event_prototypes = {
  ["Blizzard Cooldown Manager"] = Private.CooldownViewerPrototype,
  ["Blizzard CDM Buff"] = Private.CooldownViewerBuffPrototype,
  ["Blizzard CDM Utility"] = Private.CooldownViewerUtilityPrototype,
  ["Blizzard CDM Item"] = Private.CooldownViewerItemPrototype,
  ["Swing Timer"] = {
    type = "unit",
    name = "Swing Timer",
    events = {},
    internal_events = {"FA_SWING_TIMER_UPDATE"},
    force_events = "FA_SWING_TIMER_UPDATE",
    loadFunc = function() WeakAuras.WatchSwingTimer() end,
    statesParameter = "one",
    init = function(trigger)
      local hand = tonumber(trigger.swingType) or 0
      if hand ~= 0 and hand ~= 1 and hand ~= 2 then hand = 0 end
      return ([[
        local duration, expirationTime, name, icon = WeakAuras.GetSwingTimerInfo(%d)
        local progressType = "timed"
        local active = expirationTime > GetTime()
        local inRange = WeakAuras.IsTargetInSwingRange(%d)
      ]]):format(hand, hand)
    end,
    args = {
      {name = "swingType", display = "Weapon", type = "select", required = true, default = 0,
        values = function() return {[0] = "Main Hand", [1] = "Off Hand", [2] = "Ranged"} end, test = "true"},
      {name = "inRange", display = "Target In Range", type = "tristate", init = "inRange", store = true,
        conditionType = "bool", desc = "Whether your target is within reach of this weapon."},
      {name = "duration", hidden = true, init = "duration", test = "true", store = true},
      {name = "expirationTime", hidden = true, init = "expirationTime", test = "true", store = true},
      {name = "progressType", hidden = true, init = "progressType", test = "true", store = true},
      {name = "name", display = L["Name"], hidden = true, init = "name", test = "true", store = true, conditionType = "string"},
      {name = "icon", hidden = true, init = "icon", test = "true", store = true},
      {hidden = true, test = "active"},
    },
    automaticrequired = true,
    progressType = "timed",
  },
  ["Unit Characteristics"] = {
    type = "unit",
    events = function(trigger)
      local unit = trigger.unit
      local result = {}
      AddUnitEventForEvents(result, unit, "UNIT_LEVEL")
      AddUnitEventForEvents(result, unit, "UNIT_FACTION")
      AddUnitEventForEvents(result, unit, "UNIT_NAME_UPDATE")
      AddUnitEventForEvents(result, unit, "UNIT_FLAGS")
      AddUnitEventForEvents(result, unit, "PLAYER_FLAGS_CHANGED")
      AddUnitEventForEvents(result, unit, "INCOMING_RESURRECT_CHANGED")
      AddUnitEventForEvents(result, unit, "INCOMING_SUMMON_CHANGED")
      if trigger.use_inRange then
        AddUnitEventForEvents(result, unit, "UNIT_IN_RANGE_UPDATE")
      end
      if trigger.use_ignoreInvisible then
        AddUnitEventForEvents(result, unit, "PARTY_MEMBER_DISABLE")
        AddUnitEventForEvents(result, unit, "PARTY_MEMBER_ENABLE")
      end
      return result;
    end,
    internal_events = function(trigger)
      local unit = trigger.unit
      local result = {}
      AddUnitChangeInternalEvents(unit, result, nil, trigger.use_unitisunit and trigger.unitisunit or nil)
      AddUnitRoleChangeInternalEvents(unit, result)
      AddUnitSpecChangeInternalEvents(unit, result)
      return result
    end,
    loadFunc = function(trigger)
      AddWatchedUnits(trigger.unit, nil, trigger.use_unitisunit and trigger.unitisunit or nil)
    end,
    force_events = unitHelperFunctions.UnitChangedForceEvents,
    name = L["Unit Characteristics"],
    init = function(trigger)
      trigger.unit = trigger.unit or "target";
      local ret = [=[
        unit = string.lower(unit)
        local smart = %s
        local extraUnit = %q;
        local name, realm = WeakAuras.UnitNameWithRealm(unit)
      ]=];

      ret = ret .. unitHelperFunctions.SpecificUnitCheck(trigger)

      return ret:format(trigger.unit == "group" and "true" or "false", trigger.unitisunit or "");
    end,
    statesParameter = "unit",
    args = {
      {
        name = "unit",
        required = true,
        display = L["Unit"],
        type = "unit",
        init = "arg",
        values = "actual_unit_types_cast",
        desc = Private.actual_unit_types_cast_tooltip,
        test = "true",
        store = true,
        reloadOptions = true,
      },
      {
        name = "unitisunit",
        display = L["Unit is Unit"],
        type = "unit",
        init = "Private.ExecEnv.UnitIsUnit(unit, extraUnit)",
        values = function(trigger)
          if Private.multiUnitUnits[trigger.unit] then
            return Private.actual_unit_types
          else
            return Private.actual_unit_types_with_specific
          end
        end,
        test = "unitisunit",
        desc = function() return L["Can be used for e.g. checking if \"boss1target\" is the same as \"player\"."] end,
      },
      {
        name = "name",
        display = L["Name"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        name = "realm",
        display = L["Realm"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        name = "namerealm",
        display = L["Unit Name/Realm"],
        desc = constants.nameRealmFilterDesc,
        type = "string",
        multiline = true,
        preamble = "local nameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
        test = "nameRealmChecker:Check(name, realm)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseNameCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.name, state.realm)
        end,
        operator_types = "none",
      },
      {
        name = "class",
        display = L["Class"],
        type = "select",
        init = "select(2, UnitClass(unit))",
        values = "class_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "specId",
        display = L["Specialization"],
        type = "multiselect",
        init = "WeakAuras.SpecForUnit(unit)",
        values = "spec_types_all",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return (trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party")
        end,
        desc = L["Requires syncing the specialization via LibSpecialization."],
        sorted = true,
        sortOrder = Private.specs_sorted,
      },
      {
        name = "classification",
        display = L["Classification"],
        type = "multiselect",
        init = "UnitClassification(unit)",
        values = "classification_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "creatureTypeIndex",
        display = L["Creature Type"],
        type = "multiselect",
        init = "select(2, UnitCreatureType(unit))",
        values = "creature_type_types",
        store = true,
        sorted = true,
        conditionType = "select",
        enable = true,
        hidden = false,
      },
      {
        name = "creatureType",
        display = L["Creature Type Name"],
        init = "UnitCreatureType(unit)",
        store = true,
        test = "true",
        hidden = true,
        enable = true,
      },
      {
        name = "creatureFamilyIndex",
        display = L["Creature Family"],
        type = "multiselect",
        init = "select(2, UnitCreatureFamily(unit))",
        values = "creature_family_types",
        store = true,
        sorted = true,
        conditionType = "select",
        enable = true,
        hidden = false,
      },
      {
        name = "creatureFamily",
        display = L["Creature Family Name"],
        init = "UnitCreatureFamily(unit)",
        store = true,
        test = "true",
        hidden = true,
        enable = true,
      },
      {
        name = "role",
        display = L["Assigned Role"],
        type = "select",
        init = "UnitGroupRolesAssigned(unit)",
        values = "role_types",
        store = true,
        conditionType = "select",
      },
      {
        name = "raid_role",
        display = L["Raid Role"],
        type = "select",
        init = "WeakAuras.UnitRaidRole(unit)",
        values = "raid_role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return false
        end
      },
      {
        name = "dead",
        display = L["Dead"],
        type = "tristate",
        width = WeakAuras.doubleWidth,
        init = "UnitIsDeadOrGhost(unit)",
        store = true,
        conditionType = "bool",
      },
      {
        name = "resurrectPending",
        display = L["Resurrect Pending"],
        type = "tristate",
        width = WeakAuras.doubleWidth,
        init = "UnitHasIncomingResurrection(unit)",
        store = true,
        conditionType = "bool",
      },
      {
        name = "summonPending",
        display = L["Summon Pending"],
        type = "tristate",
        width = WeakAuras.doubleWidth,
        enable = true,
        hidden = false,
        init = "C_IncomingSummon.HasIncomingSummon(unit)",
        store = true,
        conditionType = "bool",
      },
      {
        name = "ignoreSelf",
        display = L["Ignore Self"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not Private.ExecEnv.UnitIsUnit(\"player\", unit)"
      },
      {
        name = "ignoreDisconnected",
        display = L["Ignore Disconnected"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "UnitIsConnected(unit)"
      },
      {
        name = "ignoreInvisible",
        display = L["Ignore out of checking range"],
        desc = L["Uses UnitIsVisible() to check if game client has loaded a object for this unit. This distance is around 100 yards. This is polled every second."],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "UnitIsVisible(unit)",
      },
      {
        name = "hostility",
        display = L["Hostility"],
        type = "select",
        init = "WeakAuras.GetPlayerReaction(unit)",
        values = "hostility_types",
        store = true,
        conditionType = "select",
      },
      {
        name = "character",
        display = L["Character Type"],
        type = "select",
        init = "UnitIsPlayer(unit) and 'player' or 'npc'",
        values = "character_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "level",
        display = L["Level"],
        type = "number",
        init = "UnitLevel(unit)",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "npcId",
        display = L["Npc ID"],
        type = "string",
        multiline = true,
        store = true,
        init = "not issecretvalue(UnitGUID(unit)) and select(6, strsplit('-', UnitGUID(unit) or ''))",
        conditionType = "string",
        preamble = "local npcIdChecker = Private.ExecEnv.ParseStringCheck(%q)",
        test = "npcIdChecker:Check(npcId)",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseStringCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.npcId)
        end,
        operator_types = "none",
        desc = L["Supports multiple entries, separated by commas. Prefix with '-' for negation."]
      },
      {
        name = "attackable",
        display = L["Attackable"],
        type = "tristate",
        init = "UnitCanAttack('player', unit)",
        store = true,
        conditionType = "bool"
      },
      {
        name = "inCombat",
        display = L["In Combat"],
        type = "tristate",
        init = "UnitAffectingCombat(unit)",
        store = true,
        conditionType = "bool"
      },
      {
        name = "afk",
        display = L["Afk"],
        type = "tristate",
        init = "UnitIsAFK(unit)",
        store = true,
        conditionType = "bool"
      },
      {
        name = "dnd",
        display = L["Do Not Disturb"],
        type = "tristate",
        init = "UnitIsDND(unit)",
        store = true,
        conditionType = "bool"
      },
      {
        hidden = true,
        test = "WeakAuras.UnitExistsFixed(unit, smart) and specificUnitCheck"
      }
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Faction Reputation"] = {
    type = "unit",
    progressType = "static",
    events = {
      ["events"] = {
        "UPDATE_FACTION",
      }
    },
    internal_events = {"WA_DELAYED_PLAYER_ENTERING_WORLD"},
    force_events = "UPDATE_FACTION",
    name = L["Faction Reputation"],
    statesParameter = "one",
    automaticrequired = true,
    init = function(trigger)
      local ret = [=[
        local useWatched = %s
        local factionID = useWatched and Private.ExecEnv.GetWatchedFactionId() or %q
        local minValue, maxValue, currentValue
        local factionData = Private.ExecEnv.GetFactionDataByID(factionID)
        if not factionData then return end;

        local name, description = factionData.name, factionData.description
        local standingID = factionData.reaction
        local hasRep = factionData.isHeaderWithRep
        local barMin, barMax, barValue = factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding
        local atWarWith, canToggleAtWar, isHeader, isCollapsed, isWatched, isChild, hasBonusRepGain, canSetInactive = factionData.atWarWith, factionData. canToggleAtWar, factionData.isHeader, factionData.isCollapsed, factionData.isWatched, factionData.isChild, factionData.hasBonusRepGain, factionData.canSetInactive
        minValue, maxValue, currentValue = barMin, barMax, barValue
        local standing
        if tonumber(standingID) then
           standing = GetText("FACTION_STANDING_LABEL"..standingID, UnitSex("player"))
        end
        local isCapped = standingID == 8 and currentValue >= 42999
      ]=]
      do
        ret = ret .. [=[
          isCapped = standingID == MAX_REPUTATION_REACTION

          -- check if this is a friendship faction
          local friendshipRank, friendshipMaxRank
          local repInfo = factionID and C_GossipInfo.GetFriendshipReputation(factionID);
          if repInfo and repInfo.friendshipFactionID > 0 then
            standing = repInfo.reaction
            if repInfo.nextThreshold then
              minValue, maxValue, currentValue = repInfo.reactionThreshold, repInfo.nextThreshold, repInfo.standing
            else
              -- max rank, make it look like a full bar
              minValue, maxValue, currentValue = 0, 1, 1
              isCapped = true
            end
            local rankInfo = C_GossipInfo.GetFriendshipReputationRanks(factionID)
            if rankInfo.maxLevel > 0 then
              friendshipRank, friendshipMaxRank = rankInfo.currentLevel, rankInfo.maxLevel
            else
              friendshipRank, friendshipMaxRank = 1, 1
            end
          end

          -- check if this is a Major faction (renown)
          local renownLevel, maxRenownLevel, isWeeklyRenownCapped
          local isMajorFaction = factionID and C_Reputation.IsMajorFaction(factionID)
          if isMajorFaction then
            local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID)
            minValue, maxValue = 0, majorFactionData.renownLevelThreshold
            isCapped = C_MajorFactions.HasMaximumRenown(factionID)
		        currentValue = isCapped and majorFactionData.renownLevelThreshold or majorFactionData.renownReputationEarned or 0
            standing = RENOWN_LEVEL_LABEL:format(majorFactionData.renownLevel)
            renownLevel = majorFactionData.renownLevel
            local renownLevels = C_MajorFactions.GetRenownLevels(factionID)
            maxRenownLevel = renownLevels and renownLevels[#renownLevels].level
            isWeeklyRenownCapped = C_MajorFactions.IsWeeklyRenownCapped(factionID)
          end

        ]=]
      end
      return ret:format(trigger.use_watched and "true" or "false", trigger.factionID or 0)
    end,
    args = {
      {
        name = "progressType",
        hidden = true,
        init = "'static'",
        store = true,
        test = "true"
      },
      {
        name = "watched",
        display = L["Use Watched Faction"],
        type = "toggle",
        test = "true",
        reloadOptions = true,
      },
      {
        name = "factionID",
        display = L["Faction"],
        required = true,
        type = "select",
        itemControl = "Dropdown-Currency",
        values = Private.GetReputations,
        headers = Private.GetReputationsHeaders,
        sorted = true,
        sortOrder = function()
          local sorted = Private.GetReputationsSorted()
          local sortOrder = {}
          for key, value in pairs(Private.GetReputations()) do
            tinsert(sortOrder, key)
          end
          table.sort(sortOrder, function(aKey, bKey)
            local aValue = sorted[aKey]
            local bValue = sorted[bKey]
            return aValue < bValue
          end)
          return sortOrder
        end,
        conditionType = "select",
        enable = function(trigger)
          return not trigger.use_watched
        end,
        reloadOptions = true,
        test = "true",
      },
      {
        name = "name",
        display = L["Faction Name"],
        type = "string",
        store = true,
        hidden = "true",
        init = "name",
        test = "true"
      },
      {
        name = "value",
        display = L["Reputation"],
        type = "number",
        store = true,
        init = [[currentValue - minValue]],
        conditionType = "number",
        progressTotal = "total",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "total",
        display = L["Total Reputation"],
        type = "number",
        store = true,
        init = [[maxValue - minValue]],
        conditionType = "number",
        noProgressSource = true,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "percentRep",
        display = L["Reputation (%)"],
        type = "number",
        init = "total ~= 0 and (value / total) * 100 or nil",
        store = true,
        conditionType = "number",
        noProgressSource = true,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "standing",
        display = L["Standing"],
        type = "string",
        init = "standing",
        store = true,
        hidden = "true",
        test = "true"
      },
      {
        name = "standingId",
        display = L["Standing"],
        type = "select",
        values = function()
          local ret = {}
          for i = 1, 8 do
            ret[i] = GetText("FACTION_STANDING_LABEL"..i, UnitSex("player"))
          end
          return ret
        end,
        init = "standingID",
        store = true,
        conditionType = "select",
      },
      {
        name = "capped",
        display = L["Capped"],
        type = "tristate",
        init = "isCapped",
        conditionType = "bool",
        store = true,
      },
      {
        name = "atWar",
        display = L["At War"],
        type = "tristate",
        init = "atWarWith",
        conditionType = "bool",
        store = true,
      },
      {
        type = "header",
        name = "friendshipReputationHeader",
        display = L["Friendship Reputation"],
        enable = function(trigger)
          local repInfo = trigger.factionID and C_GossipInfo.GetFriendshipReputation(trigger.factionID);
          return repInfo and repInfo.friendshipFactionID > 0
        end,
        hidden = false,
      },
      {
        name = "friendshipRank",
        display = L["Friendship Rank"],
        type = "number",
        init = "friendshipRank",
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local repInfo = trigger.factionID and C_GossipInfo.GetFriendshipReputation(trigger.factionID);
          return repInfo and repInfo.friendshipFactionID > 0
        end,
        hidden = false,
        progressTotal = "friendshipMaxRank",
      },
      {
        name = "friendshipMaxRank",
        display = L["Friendship Max Rank"],
        type = "number",
        init = "friendshipMaxRank",
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local repInfo = trigger.factionID and C_GossipInfo.GetFriendshipReputation(trigger.factionID);
          return repInfo and repInfo.friendshipFactionID > 0
        end,
        hidden = false,
        noProgressSource = true,
      },
      {
        type = "header",
        name = "renownReputationHeader",
        display = L["Renown Reputation"],
        enable = function(trigger)
          local majorFactionData = trigger.factionID and C_MajorFactions.GetMajorFactionData(trigger.factionID)
          return majorFactionData and majorFactionData.renownLevel
        end,
        hidden = false,
      },
      {
        name = "renownLevel",
        display = L["Renown Level"],
        type = "number",
        conditionType = "number",
        init = "renownLevel",
        store = true,
        enable = function(trigger)
          local majorFactionData = trigger.factionID and C_MajorFactions.GetMajorFactionData(trigger.factionID)
          return majorFactionData and majorFactionData.renownLevel
        end,
        hidden = false,
        progressTotal = "maxRenownLevel",
      },
      {
        name = "maxRenownLevel",
        display = L["Renown Max Level"],
        type = "number",
        conditionType = "number",
        init = "maxRenownLevel",
        store = true,
        enable = function(trigger)
          local majorFactionData = trigger.factionID and C_MajorFactions.GetMajorFactionData(trigger.factionID)
          return majorFactionData and majorFactionData.renownLevel
        end,
        hidden = false,
        noProgressSource = true,
      },
      {
        name = "isWeeklyRenownCapped",
        display = L["Is Weekly Renown Capped"],
        type = "tristate",
        conditionType = "bool",
        init = "isWeeklyRenownCapped",
        store = true,
        enable = function(trigger)
          local majorFactionData = trigger.factionID and C_MajorFactions.GetMajorFactionData(trigger.factionID)
          return majorFactionData and majorFactionData.renownLevel
        end,
        hidden = false,
      },
    }
  },
  ["Experience"] = {
    type = "unit",
    progressType = "static",
    events = {
      ["events"] = {
        "PLAYER_XP_UPDATE",
      }
    },
    internal_events = {"WA_DELAYED_PLAYER_ENTERING_WORLD"},
    force_events = "PLAYER_XP_UPDATE",
    name = L["Player Experience"],
    init = function(trigger)
      return ""
    end,
    statesParameter = "one",
    args = {
      {
        name = "level",
        display = L["Level"],
        required = false,
        type = "number",
        store = true,
        init = [[UnitLevel("player")]],
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "currentXP",
        display = L["Current Experience"],
        type = "number",
        store = true,
        init = [[UnitXP("player")]],
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        progressTotal = "totalXP"
      },
      {
        name = "totalXP",
        display = L["Total Experience"],
        type = "number",
        store = true,
        init = [[UnitXPMax("player")]],
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "value",
        type = "number",
        store = true,
        init = "currentXP",
        hidden = true,
        test = "true",
      },
      {
        name = "total",
        type = "number",
        store = true,
        init = "totalXP",
        hidden = true,
        test = "true",
      },
      {
        name = "progressType",
        hidden = true,
        init = "'static'",
        store = true,
        test = "true"
      },
      {
        name = "percentXP",
        display = L["Experience (%)"],
        type = "number",
        init = "total ~= 0 and (value / total) * 100 or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        type = "header",
        name = "restedExperienceHeader",
        display = L["Rested Experience"],
      },
      {
        name = "showRested",
        display = L["Show Rested Overlay"],
        type = "toggle",
        test = "true",
        reloadOptions = true,
      },
      {
        name = "restedXP",
        display = L["Rested Experience"],
        init = [[GetXPExhaustion() or 0]],
        type = "number",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "percentrested",
        display = L["Rested Experience (%)"],
        init = "total ~= 0 and (restedXP / total) * 100 or nil",
        type = "number",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
    },
    overlayFuncs = {
      {
        name = L["Rested"],
        func = function(trigger, state)
          return "forward", state.restedXP
        end,
        enable = function(trigger)
          return trigger.use_showRested
        end
      },
    },
    automaticrequired = true
  },
  ["Health"] = {
    type = "unit",
    progressType = "static",
    displayOnlyProgress = true,
    includePets = "true",
    events = function(trigger)
      local unit = trigger.unit
      local result = {}
      AddUnitEventForEvents(result, unit, "UNIT_HEALTH")
      AddUnitEventForEvents(result, unit, "UNIT_MAXHEALTH")
      AddUnitEventForEvents(result, unit, "UNIT_NAME_UPDATE")
      if trigger.use_showAbsorb then AddUnitEventForEvents(result, unit, "UNIT_ABSORB_AMOUNT_CHANGED") end
      if trigger.use_showHealAbsorb then AddUnitEventForEvents(result, unit, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED") end
      if trigger.use_showIncomingHeal then AddUnitEventForEvents(result, unit, "UNIT_HEAL_PREDICTION") end
      if trigger.use_ignoreDead or trigger.use_ignoreDisconnected then AddUnitEventForEvents(result, unit, "UNIT_FLAGS") end
      return result
    end,
    internal_events = function(trigger)
      local result = {}
      local includePets = trigger.use_includePets == true and trigger.includePets or nil
      AddUnitChangeInternalEvents(trigger.unit, result, includePets)
      if includePets ~= "PetsOnly" then
        AddUnitRoleChangeInternalEvents(trigger.unit, result)
      end
      AddUnitSpecChangeInternalEvents(trigger.unit, result)
      return result
    end,
    loadFunc = function(trigger)
      local includePets = trigger.use_includePets == true and trigger.includePets or nil
      AddWatchedUnits(trigger.unit, includePets)
    end,
    force_events = unitHelperFunctions.UnitChangedForceEventsWithPets,
    name = L["Health"],
    init = function(trigger)
      trigger.unit = trigger.unit or "player"
      local ret = ([=[
        unit = string.lower(unit)
        local name, realm = WeakAuras.UnitNameWithRealm(unit)
        local smart = %s
      ]=]):format(trigger.unit == "group" and "true" or "false")
      return ret .. unitHelperFunctions.SpecificUnitCheck(trigger)
    end,
    statesParameter = "unit",
    args = {
      {
        name = "combatStatus", type = "description", display = "",
        text = function(trigger, data, triggernum) return Private.CurveCombatStatus("health", trigger, data, triggernum) end,
      },
      {
        name = "unit", required = true, display = L["Unit"], type = "unit",
        init = "arg", values = "actual_unit_types_cast", desc = Private.actual_unit_types_cast_tooltip,
        test = "true", store = true,
      },
      {
        name = "health", display = L["Health"], type = "number", secretCurve = true, hidden = true, test = "true",
        init = "UnitHealth(unit)", store = true, conditionType = "number",
        multiEntry = {operator = "and", limit = 2}, progressTotal = "maxhealth", formatter = "BigNumber",
      },
      { name = "value", hidden = true, init = "health", store = true, test = "true" },
      { name = "total", hidden = true, init = "UnitHealthMax(unit)", store = true, test = "true" },
      { name = "progressType", hidden = true, init = "'static'", store = true, test = "true" },
      {
        name = "percenthealth", display = L["Health (%)"], type = "number", secretCurve = true, hidden = true, test = "true",
        init = "UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)", store = true, conditionType = "number",
        multiEntry = {operator = "and", limit = 2}, formatter = "Number",
      },
      {
        name = "deficit", display = L["Health Deficit"], type = "number", secretCurve = true, hidden = true, test = "true",
        init = "UnitHealthMissing(unit)", store = true, conditionType = "number",
        multiEntry = {operator = "and", limit = 2}, progressTotal = "total", formatter = "BigNumber",
      },
      {
        name = "maxhealth", display = L["Max Health"], type = "number",
        hidden = function(trigger) return not Private.PlayerUnitTrigger(trigger) end, filterEnable = Private.PlayerUnitTrigger,
        init = "total", store = true, conditionType = "number",
        multiEntry = {operator = "and", limit = 2}, formatter = "BigNumber",
      },
      {
        type = "header", name = "absorbAndHealingHeader", display = L["Absorb and Healing"],
      },
      {
        name = "showAbsorb", display = L["Fetch Absorb"], type = "toggle", test = "true", reloadOptions = true,
        enable = UnitGetTotalAbsorbs ~= nil, hidden = UnitGetTotalAbsorbs == nil,
      },
      {
        name = "absorbMode", display = L["Absorb Overlay"], type = "select", test = "true", values = "absorb_modes", required = true,
        enable = function(trigger) return trigger.use_showAbsorb end, hidden = UnitGetTotalAbsorbs == nil,
      },
      {
        name = "showHealAbsorb", display = L["Fetch Heal Absorb"], type = "toggle", test = "true", reloadOptions = true,
        enable = UnitGetTotalHealAbsorbs ~= nil, hidden = UnitGetTotalHealAbsorbs == nil,
      },
      {
        name = "absorbHealMode", display = L["Absorb Heal Overlay"], type = "select", test = "true", values = "absorb_modes", required = true,
        enable = function(trigger) return trigger.use_showHealAbsorb end, hidden = UnitGetTotalHealAbsorbs == nil,
      },
      {
        name = "absorb", type = "number", display = L["Absorb"], hidden = true, test = "true",
        init = "UnitGetTotalAbsorbs(unit)", store = true, conditionType = "number",
        enable = function(trigger) return trigger.use_showAbsorb end, hidden = UnitGetTotalAbsorbs == nil,
        multiEntry = {operator = "and", limit = 2}, progressTotal = "total",
      },
      {
        name = "healabsorb", type = "number", display = L["Heal Absorb"], hidden = true, test = "true",
        init = "UnitGetTotalHealAbsorbs(unit)", store = true, conditionType = "number",
        enable = function(trigger) return trigger.use_showHealAbsorb end, hidden = UnitGetTotalHealAbsorbs == nil,
        multiEntry = {operator = "and", limit = 2},
      },
      {
        name = "showIncomingHeal", display = L["Show Incoming Heal"], type = "toggle", test = "true", reloadOptions = true,
        enable = UnitGetIncomingHeals ~= nil, hidden = UnitGetIncomingHeals == nil,
      },
      {
        name = "healprediction", type = "number", display = L["Incoming Heal"], hidden = true, test = "true",
        init = "UnitGetIncomingHeals(unit)", store = true, conditionType = "number",
        enable = function(trigger) return trigger.use_showIncomingHeal end, hidden = UnitGetIncomingHeals == nil,
        multiEntry = {operator = "and", limit = 2},
      },
      {
        name = "name",
        display = L["Unit Name"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        name = "realm",
        display = L["Realm"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        type = "header",
        name = "unitCharacteristicsHeader",
        display = L["Unit Characteristics"],
      },
      {
        name = "namerealm",
        display = L["Unit Name/Realm"],
        type = "string",
        multiline = true,
        preamble = "local nameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
        test = "nameRealmChecker:Check(name, realm)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseNameCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.name, state.realm)
        end,
        operator_types = "none",
        desc = constants.nameRealmFilterDesc,
      },
      {
        name = "npcId",
        display = L["Npc ID"],
        type = "string",
        multiline = true,
        store = true,
        init = "not issecretvalue(UnitGUID(unit)) and select(6, strsplit('-', UnitGUID(unit) or ''))",
        conditionType = "string",
        preamble = "local npcIdChecker = Private.ExecEnv.ParseStringCheck(%q)",
        test = "npcIdChecker:Check(npcId)",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseStringCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.npcId)
        end,
        operator_types = "none",
        desc = L["Supports multiple entries, separated by commas. Prefix with '-' for negation."]
      },
      {
        name = "class",
        display = L["Class"],
        type = "select",
        init = "select(2, UnitClass(unit))",
        values = "class_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "specId",
        display = L["Specialization"],
        type = "multiselect",
        init = "WeakAuras.SpecForUnit(unit)",
        values = "spec_types_all",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return (trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party")
        end,
        desc = L["Requires syncing the specialization via LibSpecialization."],
        sorted = true,
        sortOrder = Private.specs_sorted,
      },
      {
        name = "role",
        display = L["Assigned Role"],
        type = "select",
        init = "UnitGroupRolesAssigned(unit)",
        values = "role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end
      },
      {
        name = "raid_role",
        display = L["Raid Role"],
        type = "select",
        init = "WeakAuras.UnitRaidRole(unit)",
        values = "raid_role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return false
        end
      },
      {
        type = "header",
        name = "miscellaneousHeader",
        display = L["Miscellaneous"],
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
      },
      {
        name = "includePets",
        display = L["Include Pets"],
        type = "select",
        values = "include_pets_types",
        width = WeakAuras.normalWidth,
        test = "true",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end
      },
      {
        name = "ignoreSelf",
        display = L["Ignore Self"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not Private.ExecEnv.UnitIsUnit(\"player\", unit)"
      },
      {
        name = "ignoreDead",
        display = L["Ignore Dead"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not UnitIsDeadOrGhost(unit)"
      },
      {
        name = "ignoreDisconnected",
        display = L["Ignore Disconnected"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "UnitIsConnected(unit)"
      },
      {
        name = "nameplateType",
        display = L["Hostility"],
        type = "select",
        init = "WeakAuras.GetPlayerReaction(unit)",
        values = "hostility_types",
        store = true,
        conditionType = "select",
      },
      { hidden = true, test = "WeakAuras.UnitExistsFixed(unit, smart) and specificUnitCheck" },
    },
    overlayFuncs = {
      {
        name = L["Absorb"],
        func = function(trigger, state)
          local absorb = state.absorb
          if not issecretvalue(absorb) and absorb == nil then return end
          if trigger.absorbMode == "OVERLAY_FROM_START" then
            return 0, absorb
          elseif trigger.absorbMode == "OVERLAY_FROM_END" then
            return "forward", absorb
          end
          return "fromMax", absorb
        end,
        enable = function(trigger) return trigger.use_showAbsorb end
      },
      {
        name = L["Heal Absorb"],
        func = function(trigger, state)
          local healabsorb = state.healabsorb
          if not issecretvalue(healabsorb) and healabsorb == nil then return end
          if trigger.absorbHealMode == "OVERLAY_FROM_START" then
            return 0, healabsorb
          elseif trigger.absorbHealMode == "OVERLAY_FROM_END" then
            return "forward", healabsorb
          end
          return "fromMax", healabsorb
        end,
        enable = function(trigger) return trigger.use_showHealAbsorb end
      },
      {
        name = L["Incoming Heal"],
        func = function(trigger, state)
          local heal = state.healprediction
          if not issecretvalue(heal) and heal == nil then return end
          return "forward", heal
        end,
        enable = function(trigger) return trigger.use_showIncomingHeal end
      },
    },
    automaticrequired = true,
  },
  ["Power"] = {
    type = "unit",
    progressType = "static",
    events = function(trigger)
      local unit = trigger.unit
      local result = {}
      AddUnitEventForEvents(result, unit, "UNIT_POWER_FREQUENT")
      AddUnitEventForEvents(result, unit, "UNIT_MAXPOWER")
      AddUnitEventForEvents(result, unit, "UNIT_DISPLAYPOWER")
      AddUnitEventForEvents(result, unit, "UNIT_NAME_UPDATE")

      -- The api for spell power costs is not meant to be for other units
      if trigger.use_showCost and trigger.unit == "player" then
        AddUnitEventForEvents(result, "player", "UNIT_SPELLCAST_START")
        AddUnitEventForEvents(result, "player", "UNIT_SPELLCAST_STOP")
        AddUnitEventForEvents(result, "player", "UNIT_SPELLCAST_FAILED")
        AddUnitEventForEvents(result, "player", "UNIT_SPELLCAST_SUCCEEDED")
      end

      if trigger.use_ignoreDead or trigger.use_ignoreDisconnected then
        AddUnitEventForEvents(result, unit, "UNIT_FLAGS")
      end

      if trigger.use_powertype and trigger.powertype == 4 then
        do
          AddUnitEventForEvents(result, unit, "UNIT_POWER_POINT_CHARGE")
        end
      end
      if trigger.use_inRange then
        AddUnitEventForEvents(result, unit, "UNIT_IN_RANGE_UPDATE")
      end
      return result;
    end,
    internal_events = function(trigger)
      local unit = trigger.unit
      local result = {}
      local includePets = trigger.use_includePets == true and trigger.includePets or nil
      AddUnitChangeInternalEvents(unit, result, includePets)
      if includePets ~= "PetsOnly" then
        AddUnitRoleChangeInternalEvents(unit, result)
      end
      AddUnitSpecChangeInternalEvents(unit, result)
      if trigger.use_powertype and trigger.powertype == 99 and trigger.unit == "player" then
        Private.WatchStagger()
        tinsert(result, "WA_UNIT_STAGGER_CHANGED");
      end
      
      return result
    end,
    loadFunc = function(trigger)
      
      local includePets = trigger.use_includePets == true and trigger.includePets or nil
      AddWatchedUnits(trigger.unit, includePets)
    end,
    force_events = unitHelperFunctions.UnitChangedForceEventsWithPets,
    name = L["Power"],
    init = function(trigger)
      trigger.unit = trigger.unit or "player";
      local ret = {}
      table.insert(ret, ([=[
        unit = string.lower(unit)
        local name, realm = WeakAuras.UnitNameWithRealm(unit)
        local smart = %s
        local powerType = %s;
        local unitPowerType = UnitPowerType(unit);
        local powerTypeToCheck = powerType or unitPowerType;
      ]=]):format(trigger.unit == "group" and "true" or "false", trigger.use_powertype and trigger.powertype or "nil"))

      local powerType = trigger.use_powertype and trigger.powertype or nil
      do
        if powerType == 7 then
          -- Soul Shards, this mirrors the ShardBar in the wow sources
          table.insert(ret, [[
            local shardModifier = UnitPowerDisplayMod(powerType)
            local power = UnitPower(unit, powerType, true)
            local total = UnitPowerMax(unit, powerType, true)
            if not hasanysecretvalues(power, total) then
              power = power / shardModifier
              total = math.max(1, total) / shardModifier
              if Private.ExecEnv.GetSpecialization() ~= SPEC_WARLOCK_DESTRUCTION then
                power = floor(power)
              end
            end
          ]])
        elseif powerType == 99 then
          table.insert(ret, ([[
            local power = UnitStagger(unit) or 0
            local scaleStagger = %s
            local total = UnitHealthMax(unit)
            if not issecretvalue(total) then
              total = math.max(1, total * scaleStagger)
            end
          ]]):format(trigger.use_scaleStagger and trigger.scaleStagger or 1))
        elseif powerType == 4 and trigger.unit == 'player' then
          table.insert(ret, ([[
            local comboPoint = UnitPower(unit, 4)
            local chargedComboPoint = GetUnitChargedPowerPoints('player') or {}
            local countCharged = #chargedComboPoint
            if state.countCharged ~= countCharged then
              state.countCharged = countCharged
              state.changed = true
            end

            local power = UnitPower(unit, powerType)
            local total = UnitPowerMax(unit, powerType)
            if not issecretvalue(total) then
              total = math.max(1, total)
            end
          ]]))
        else
          table.insert(ret, [[
            local power = UnitPower(unit, powerType)
            local total = UnitPowerMax(unit, powerType)
            if not issecretvalue(total) then
              total = math.max(1, total)
            end
          ]])
        end
      end

      table.insert(ret, unitHelperFunctions.SpecificUnitCheck(trigger))

      local canEnableShowCost = (not trigger.use_powertype or trigger.powertype ~= 99) and trigger.unit == "player";
      if (canEnableShowCost and trigger.use_showCost) then
        table.insert(ret, [[
          if (event == "UNIT_DISPLAYPOWER") then
            local cost = WeakAuras.GetSpellCost(powerTypeToCheck)
            if state.cost ~= cost then
              state.cost = cost
              state.changed = true
            end
          elseif ( (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_SUCCEEDED") and unit == "player") or event == "WA_UNIT_QUEUED_SPELL_CHANGED" then
            local cost = WeakAuras.GetSpellCost(powerTypeToCheck)
            if state.cost ~= cost then
              state.cost = cost
              state.changed = true
            end
          end
        ]])
      end

      return table.concat(ret)
    end,
    statesParameter = "unit",
    args = {
      {
        name = "combatStatus", type = "description", display = "",
        text = function(trigger, data, triggernum) return Private.CurveCombatStatus("power", trigger, data, triggernum) end,
      },
      {
        name = "unit",
        required = true,
        display = L["Unit"],
        type = "unit",
        init = "arg",
        values = "actual_unit_types_cast",
        desc = Private.actual_unit_types_cast_tooltip,
        test = "true",
        store = true
      },
      {
        name = "powertype",
        display = L["Power Type"],
        type = "select",
        values = "power_types",
        init = "powerTypeToCheck",
        test = "true",
        store = true,
        conditionType = "select",
        reloadOptions = true
      },
      {
        name = "requirePowerType",
        display = L["Only if Primary"],
        type = "toggle",
        test = "unitPowerType == powerType",
        enable = function(trigger)
          return trigger.use_powertype
        end,
      },
      {
        name = "showCost",
        display = L["Overlay Cost of Casts"],
        type = "toggle",
        test = "true",
        enable = function(trigger)
          return (not trigger.use_powertype or trigger.powertype ~= 99) and trigger.unit == "player";
        end,
        reloadOptions = true
      },
      {
        name = "showChargedComboPoints",
        display = L["Overlay Charged Combo Points"],
        type = "toggle",
        test = "true",
        reloadOptions = true,
        enable = function(trigger)
          return trigger.unit == 'player' and trigger.use_powertype and trigger.powertype == 4
        end,
        hidden = false
      },
      {
        name = "countCharged",
        type = "number",
        display = L["Charged Combo Points"],
        conditionType = "number",
        enable = function(trigger)
          return trigger.unit == 'player'and trigger.use_powertype and trigger.powertype == 4
        end,
        hidden = true,
        test = "true"
      },
      {
        name = "scaleStagger",
        display = L["Stagger Scale"],
        type = "string",
        validate = WeakAuras.ValidateNumeric,
        enable = function(trigger)
          return trigger.use_powertype and trigger.powertype == 99
        end,
        test = "true"
      },
      {
        name = "eclipseDirection",
        display = L["Eclipse Direction"],
        type = "select",
        values = "eclipse_direction_types",
        init = "GetEclipseDirection()",
        conditionType = "select",
        store = true,
        enable = function(trigger)
          return false
        end,
      },
      {
        name = "power",
        hidden = function(trigger) return not Private.PowerFilterable(trigger) end,
        filterEnable = Private.PowerFilterable,
        display = L["Power"],
        type = "number",
        secretCurve = true,
        init = "power",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        progressTotal = "total"
      },
      {
        name = "value",
        hidden = true,
        init = "power",
        store = true,
        test = "true"
      },
      {
        name = "total",
        hidden = true,
        init = "total",
        store = true,
        test = "true"
      },
      {
        name = "stacks",
        hidden = true,
        init = "power",
        store = true,
        test = "true"
      },
      {
        name = "progressType",
        hidden = true,
        init = "'static'",
        store = true,
        test = "true"
      },
      {
        name = "percentpower",
        hidden = function(trigger) return not Private.PowerFilterable(trigger) end,
        filterEnable = Private.PowerFilterable,
        display = L["Power (%)"],
        type = "number",
        secretCurve = true,
        init = "(not hasanysecretvalues(power, total) and total ~= 0) and (power / total) * 100 or (powerType ~= 99 and UnitPowerPercent(unit, powerType, false, CurveConstants.ScaleTo100) or nil)",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "deficit",
        hidden = function(trigger) return not Private.PowerFilterable(trigger) end,
        filterEnable = Private.PowerFilterable,
        display = L["Power Deficit"],
        type = "number",
        secretCurve = true,
        init = "(not hasanysecretvalues(power, total) and total ~= 0) and (total - power) or (powerType ~= 99 and UnitPowerMissing(unit, powerType) or nil)",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        progressTotal = "total"
      },
      {
        name = "maxpower",
        display = WeakAuras.newFeatureString .. L["Max Power"],
        type = "number",
        hidden = function(trigger) return not Private.PlayerUnitTrigger(trigger) end,
        filterEnable = Private.PlayerUnitTrigger,
        init = "total",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "name",
        display = L["Unit Name"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        name = "realm",
        display = L["Realm"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        type = "header",
        name = "unitCharacteristicsHeader",
        display = L["Unit Characteristics"],
      },
      {
        name = "namerealm",
        display = L["Unit Name/Realm"],
        type = "string",
        multiline = true,
        preamble = "local nameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
        test = "nameRealmChecker:Check(name, realm)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseNameCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.name, state.realm)
        end,
        operator_types = "none",
        desc = constants.nameRealmFilterDesc,
      },
      {
        name = "npcId",
        display = L["Npc ID"],
        type = "string",
        multiline = true,
        store = true,
        init = "not issecretvalue(UnitGUID(unit)) and select(6, strsplit('-', UnitGUID(unit) or ''))",
        conditionType = "string",
        preamble = "local npcIdChecker = Private.ExecEnv.ParseStringCheck(%q)",
        test = "npcIdChecker:Check(npcId)",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseStringCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.npcId)
        end,
        operator_types = "none",
        desc = L["Supports multiple entries, separated by commas. Prefix with '-' for negation."]
      },
      {
        name = "class",
        display = L["Class"],
        type = "select",
        init = "select(2, UnitClass(unit))",
        values = "class_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "specId",
        display = L["Specialization"],
        type = "multiselect",
        init = "WeakAuras.SpecForUnit(unit)",
        values = "spec_types_all",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return (trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party")
        end,
        desc = L["Requires syncing the specialization via LibSpecialization."],
        sorted = true,
        sortOrder = Private.specs_sorted,
      },
      {
        name = "role",
        display = L["Assigned Role"],
        type = "select",
        init = "UnitGroupRolesAssigned(unit)",
        values = "role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end
      },
      {
        name = "raid_role",
        display = L["Raid Role"],
        type = "select",
        init = "WeakAuras.UnitRaidRole(unit)",
        values = "raid_role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return false
        end
      },
      {
        type = "header",
        name = "miscellaneousHeader",
        display = L["Miscellaneous"],
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
      },
      {
        name = "includePets",
        display = L["Include Pets"],
        type = "select",
        values = "include_pets_types",
        width = WeakAuras.normalWidth,
        test = "true",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end
      },
      {
        name = "ignoreSelf",
        display = L["Ignore Self"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not Private.ExecEnv.UnitIsUnit(\"player\", unit)"
      },
      {
        name = "ignoreDead",
        display = L["Ignore Dead"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not UnitIsDeadOrGhost(unit)"
      },
      {
        name = "ignoreDisconnected",
        display = L["Ignore Disconnected"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "UnitIsConnected(unit)"
      },
      {
        name = "nameplateType",
        display = L["Hostility"],
        type = "select",
        init = "WeakAuras.GetPlayerReaction(unit)",
        values = "hostility_types",
        store = true,
        conditionType = "select",
      },
      {
        hidden = true,
        test = "WeakAuras.UnitExistsFixed(unit, smart) and specificUnitCheck"
      }
    },
    overlayFuncs = {
      {
        name = L["Spell Cost"],
        func = function(trigger, state)
          return "back", type(state.cost) == "number" and state.cost;
        end,
        enable = function(trigger)
          return trigger.use_showCost and (not trigger.use_powertype or trigger.powertype ~= 99) and trigger.unit == "player";
        end
      },
      {
        name = L["Charged Combo Points"],
        func = function(trigger, state)
          if type(state.countCharged) == "number" then
            return 0, state.countCharged
          end
          return 0, 0
        end,
        enable = function(trigger)
          return trigger.unit == 'player' and trigger.use_powertype and trigger.powertype == 4 and trigger.use_showChargedComboPoints
        end,
      },
    },
    automaticrequired = true
  },
  ["Alternate Power"] = {
    type = "unit",
    progressType = "static",
    events = function(trigger)
      local unit = trigger.unit
      local result = {}
      AddUnitEventForEvents(result, unit, "UNIT_POWER_FREQUENT")
      AddUnitEventForEvents(result, unit, "UNIT_NAME_UPDATE")
      if trigger.use_ignoreDead or trigger.use_ignoreDisconnected then
        AddUnitEventForEvents(result, unit, "UNIT_FLAGS")
      end
      AddUnitEventForEvents(result, unit, "UNIT_POWER_BAR_SHOW")
      AddUnitEventForEvents(result, unit, "UNIT_POWER_BAR_HIDE")
      if trigger.use_inRange then
        AddUnitEventForEvents(result, unit, "UNIT_IN_RANGE_UPDATE")
      end
      return result
    end,
    internal_events = function(trigger)
      local unit = trigger.unit
      local result = { }
      AddUnitChangeInternalEvents(unit, result)
      AddUnitRoleChangeInternalEvents(unit, result)
      AddUnitSpecChangeInternalEvents(unit, result)
      return result
    end,
    loadFunc = function(trigger)
      AddWatchedUnits(trigger.unit)
    end,
    force_events = unitHelperFunctions.UnitChangedForceEvents,
    name = L["Alternate Power"],
    init = function(trigger)
      trigger.unit = trigger.unit or "player";
      local ret = [=[
        unit = string.lower(unit)
        local unitname, realm = WeakAuras.UnitNameWithRealm(unit)
        local smart = %s
      ]=]

      ret = ret .. unitHelperFunctions.SpecificUnitCheck(trigger)

      return ret:format(trigger.unit == "group" and "true" or "false");
    end,
    statesParameter = "unit",
    args = {
      {
        name = "unit",
        required = true,
        display = L["Unit"],
        type = "unit",
        init = "arg",
        values = "actual_unit_types_cast",
        desc = Private.actual_unit_types_cast_tooltip,
        test = "true",
        store = true
      },
      {
        name = "power",
        display = L["Alternate Power"],
        type = "number",
        init = "UnitPower(unit, 10)",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        progressTotal = "total"
      },
      {
        name = "value",
        hidden = true,
        init = "power",
        store = true,
        test = "true"
      },
      {
        name = "total",
        hidden = true,
        init = "UnitPowerMax(unit, 10)",
        store = true,
        test = "true"
      },
      {
        name = "progressType",
        hidden = true,
        init = "'static'",
        store = true,
        test = "true"
      },
      {
        name = "name",
        hidden = true,
        init = "GetUnitPowerBarStrings(unit)",
        store = true,
        test = "true"
      },
      {
        name = "unitname",
        display = L["Unit Name"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        name = "unitrealm",
        display = L["Realm"],
        type = "string",
        store = true,
        hidden = true,
        test = "true"
      },
      {
        name = "namerealm",
        display = L["Unit Name/Realm"],
        type = "string",
        multiline = true,
        preamble = "local nameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
        test = "nameRealmChecker:Check(unitname, unitrealm)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseNameCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.unitname, state.unitrealm)
        end,
        operator_types = "none",
        desc = constants.nameRealmFilterDesc,
      },
      {
        name = "icon",
        hidden = true,
        init = "GetUnitPowerBarTextureInfo(unit, 1)",
        store = true,
        test = "true"
      },
      {
        name = "class",
        display = L["Class"],
        type = "select",
        init = "select(2, UnitClass(unit))",
        values = "class_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "specId",
        display = L["Specialization"],
        type = "multiselect",
        init = "WeakAuras.SpecForUnit(unit)",
        values = "spec_types_all",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        desc = L["Requires syncing the specialization via LibSpecialization."],
        sorted = true,
        sortOrder = Private.specs_sorted,
      },
      {
        name = "role",
        display = L["Assigned Role"],
        type = "select",
        init = "UnitGroupRolesAssigned(unit)",
        values = "role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end
      },
      {
        name = "raid_role",
        display = L["Raid Role"],
        type = "select",
        init = "WeakAuras.UnitRaidRole(unit)",
        values = "raid_role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return false
        end
      },
      {
        type = "header",
        name = "miscellaneousHeader",
        display = L["Miscellaneous"],
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
      },
      {
        name = "ignoreSelf",
        display = L["Ignore Self"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not Private.ExecEnv.UnitIsUnit(\"player\", unit)"
      },
      {
        name = "ignoreDead",
        display = L["Ignore Dead"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not UnitIsDeadOrGhost(unit)"
      },
      {
        name = "ignoreDisconnected",
        display = L["Ignore Disconnected"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "UnitIsConnected(unit)"
      },
      {
        name = "nameplateType",
        display = L["Hostility"],
        type = "select",
        init = "WeakAuras.GetPlayerReaction(unit)",
        values = "hostility_types",
        store = true,
        conditionType = "select",
      },
      {
        hidden = true,
        test = "name and WeakAuras.UnitExistsFixed(unit, smart) and specificUnitCheck"
      }
    },
    automaticrequired = true
  },
  ["Spell Activation Overlay"] = {
    type = "spell",
    events = {
    },
    loadInternalEventFunc = function(trigger)
      local name
      if (trigger.use_exact_spellName) then
        name = tonumber(trigger.spellName)
      else
        name = type(trigger.spellName) == "number" and Private.ExecEnv.GetSpellName(trigger.spellName) or trigger.spellName
      end
      if name == nil then return {} end
      return { "WA_UPDATE_OVERLAY_GLOW:" .. name }
    end,
    force_events = "WA_UPDATE_OVERLAY_GLOW",
    name = L["Spell Activation Overlay Glow"],
    loadFunc = function(trigger)
      if (trigger.use_exact_spellName) then
        WeakAuras.WatchSpellActivation(tonumber(trigger.spellName));
      else
        WeakAuras.WatchSpellActivation(type(trigger.spellName) == "number" and Private.ExecEnv.GetSpellName(trigger.spellName) or trigger.spellName);
      end
    end,
    init = function(trigger)
      local spellName
      if (trigger.use_exact_spellName) then
        spellName = trigger.spellName
        local ret = [[
          local spellName = %s
          local icon = Private.ExecEnv.GetSpellIcon(spellName)
        ]]
        return string.format(ret, tonumber(spellName) or "nil");
      else
        spellName = type(trigger.spellName) == "number" and Private.ExecEnv.GetSpellName(trigger.spellName) or trigger.spellName;
        local ret = [[
          local spellName = %q
          local icon = Private.ExecEnv.GetSpellIcon(spellName)
        ]]
        return string.format(ret, spellName or "");
      end
    end,
    GetNameAndIcon = GetNameAndIconForSpellName,
    statesParameter = "one",
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        test = "true",
        showExactOption = true
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        hidden = true,
        test = "WeakAuras.SpellActivationActive(spellName)";
      }
    },
    automaticrequired = true,
    progressType = "static"
  },
  ["Cooldown Progress (Spell)"] = {
    type = "spell",
    events = function(trigger)
      if trigger.use_showlossofcontrol then
        return {
          ["events"] = {"LOSS_OF_CONTROL_UPDATE", "LOSS_OF_CONTROL_ADDED"}
        }
      else
        return {}
      end
    end,
    loadInternalEventFunc = function(trigger, untrigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0;
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      if spellName == nil then return {} end
      local events = {
        "SPELL_COOLDOWN_CHANGED:" .. spellName,
        "FA_WAND_TEXT_REFRESH", -- Refresh after Shoot starts or its shared cooldown ends.
        "COOLDOWN_REMAINING_CHECK:" .. spellName,
        "WA_DELAYED_PLAYER_ENTERING_WORLD",
      };
      if (trigger.use_showgcd) then
        tinsert(events, "GCD_START");
        tinsert(events, "GCD_CHANGE");
        tinsert(events, "GCD_END");
        -- Restricted shared GCD timing emits this public refresh instead of start/end.
        tinsert(events, "GCD_UPDATE");
      end
      return events;
    end,
    force_events = "SPELL_COOLDOWN_FORCE",
    name = L["Cooldown/Charges/Count"],
    loadFunc = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0;
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local exactMatch = trigger.use_exact_spellName
      local followoverride = not trigger.use_ignoreoverride
      WeakAuras.WatchSpellCooldown(spellName, trigger.use_matchedRune, exactMatch, followoverride)
      if (trigger.use_showgcd) then
        WeakAuras.WatchGCD();
      end
    end,
    init = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local ret = {}

      local showOnCheck = "false";
      if (trigger.genericShowOn == "showOnReady") then
        showOnCheck = "(isSecret and cooldownData and cooldownData.onCooldown == false) or (not isSecret and startTime and startTime == 0 or gcdCooldown)";
      elseif (trigger.genericShowOn == "showOnCooldown") then
        showOnCheck = "(isSecret and cooldownData and cooldownData.onCooldown == true) or (not isSecret and startTime and startTime > 0 and not gcdCooldown)";
      elseif (trigger.genericShowOn == "showAlways") then
        showOnCheck = "startTime ~= nil or durationObject ~= nil";
      end

      local trackSpecificCharge = trigger.use_trackcharge and trigger.trackcharge and trigger.trackcharge ~= ""
      local track = trigger.track or "auto"
      if track == "auto" and trackSpecificCharge then
        track = "charges"
      end

      table.insert(ret, ([=[
        local spellname = %s
        local ignoreRuneCD = %s
        local showgcd = %s;
        local showlossofcontrol = %s;
        local ignoreSpellKnown = %s;
        local useExact = %s
        local followoverride = %s
        local track = %q
        local effectiveSpellId = Private.ExecEnv.GetEffectiveSpellId(spellname, useExact, followoverride)
        local name, _, icon = Private.ExecEnv.GetSpellInfo(effectiveSpellId)
        local startTime, duration, gcdCooldown, readyTime, modRate, paused = WeakAuras.GetSpellCooldown(effectiveSpellId, ignoreRuneCD, showgcd, ignoreSpellKnown, track)
        local charges, maxCharges, spellCount, chargeGainTime, chargeLostTime = WeakAuras.GetSpellCharges(effectiveSpellId, ignoreSpellKnown)
        local isSecret = C_Secrets.ShouldSpellCooldownBeSecret(effectiveSpellId) or issecretvalue(maxCharges) or issecretvalue(spellCount)
        local stacks
        if maxCharges and maxCharges > 1 then
          stacks = charges
        elseif isSecret then
          stacks = C_Spell.GetSpellDisplayCount(effectiveSpellId)
        elseif spellCount and spellCount > 0 then
          stacks = spellCount
        end
        local cooldownData = Private.ExecEnv.GetSpellCooldownData(effectiveSpellId, track, showgcd, showlossofcontrol, Private.ExecEnv.spellCooldownTriggerScratch)
        local durationObject = cooldownData and cooldownData.duration
        local isReady = cooldownData and cooldownData.ready
        if showlossofcontrol and startTime and duration then
          local locStart, locDuration = WeakAuras.GetSpellLossOfControlCooldown(spellname);
          if locStart and locDuration and not hasanysecretvalues(locStart, locDuration) and (locStart + locDuration) > (startTime + duration) then
            startTime = locStart
            duration = locDuration
          end
        end
        if charges == nil then
          if isSecret then
            if cooldownData and cooldownData.onCooldown ~= nil then
              charges = cooldownData.onCooldown and 0 or 1
            end
          else
            charges = (duration == 0 or gcdCooldown) and 1 or 0
          end
        end
        local genericShowOn = (ignoreSpellKnown or WeakAuras.IsSpellKnownIncludingPet(effectiveSpellId)) and (%s)
        local expirationTime = startTime and duration and startTime + duration
        state.spellname = spellname;
      ]=]):format(
        spellName,
        (trigger.use_matchedRune and "true" or "false"),
        (trigger.use_showgcd and "true" or "false"),
        (trigger.use_showlossofcontrol and "true" or "false"),
        (trigger.use_ignoreSpellKnown and "true" or "false"),
        (trigger.use_exact_spellName and "true" or "false"),
        (not trigger.use_ignoreoverride and "true" or "false"),
        track,
        showOnCheck
      ))

      table.insert(ret, [=[
        -- Whether the previous update was restricted, and what it showed. A restriction change
        -- with nothing to show on either side (the spell ready, not paused and
        -- not on a global cooldown) is not a change to the display: both
        -- forms draw the same empty swipe, and entering or leaving combat with
        -- a row of ready cooldown icons otherwise refreshed every one of them
        -- at once. The timed values are still filled in quietly.
        local wasSecret, wasOnCooldown = state.secretCooldown, state.onCooldown
        state.secretCooldown = isSecret or nil
        state.onCooldown = nil
        -- Retain a GCD-free appearance source without exposing its restricted status
        -- to the ordinary condition engine. Clear it when readable tracking resumes.
        state.spellCooldownConditionDuration, state.spellCooldownConditionOnCooldown = nil, nil
        if isSecret then
          local quietEntry = not wasSecret and state.progressType == "durationObject" and wasOnCooldown == false
            and not state.paused and cooldownData and cooldownData.onCooldown == false
            and not cooldownData.gcdOnly and not cooldownData.paused
          if not quietEntry then state.changed = true end
          state.progressType = "durationObject"
          state.durationObject = durationObject
          state.onCooldown = cooldownData and cooldownData.onCooldown
          state.spellCooldownConditionDuration = cooldownData and cooldownData.conditionDuration
          state.spellCooldownConditionOnCooldown = cooldownData and cooldownData.conditionOnCooldown
          state.expirationTime, state.duration, state.modRate = nil, nil, nil
          state.paused, state.remaining = nil, nil
          state.value, state.total = nil, nil
        else
          state.durationObject = nil
      ]=])
      if (not trackSpecificCharge) then
        table.insert(ret, [=[
          if wasSecret and wasOnCooldown == false and not paused and not state.paused
          and (expirationTime or 0) == 0 and (duration or 0) == 0 then
            state.expirationTime, state.duration, state.modRate = expirationTime, duration, modRate
          end
          if paused then
            if not state.paused then
              state.paused = true
              state.expirationTime = nil
              state.changed = true
            end
            if state.remaining ~= startTime then
              state.remaining = startTime
              state.changed = true
            end
          else
            if (state.expirationTime ~= expirationTime) then
              state.expirationTime = expirationTime;
              state.changed = true;
            end

            if state.paused then
              state.paused = false
              state.remaining = nil
              state.changed = true
            end
          end
          if (state.duration ~= duration) then
            state.duration = duration;
            state.changed = true;
          end
          if (state.modRate ~= modRate) then
            state.modRate = modRate;
            state.changed = true;
          end
          state.durationObject = showgcd and durationObject or WeakAuras.GetSpellCooldownDurationNoGCD(effectiveSpellId, track);
          -- The display keeps the same form on both sides of a restriction
          -- change: a readable cooldown is also shown from its duration object
          -- (as the restricted one must be), so entering or leaving combat
          -- does not switch every cooldown display between a timed swipe and
          -- a duration-object swipe. The timed values stay in the state for
          -- conditions, custom code and tooltips. Without a duration object
          -- (never on this client) the timed form is used as before.
          if WeakAuras.IsDurationObject(state.durationObject) then
            if state.progressType ~= "durationObject" then state.changed = true end
            state.progressType = "durationObject"
            state.onCooldown = cooldownData and cooldownData.onCooldown
            if state.onCooldown == nil then
              -- The same answer the timed form's On Cooldown check gives.
              state.onCooldown = (paused or (not gcdCooldown and expirationTime ~= nil and expirationTime > GetTime())) and true or false
            end
            state.value, state.total = nil, nil
          else
            state.progressType = 'timed';
          end
        ]=])
      else -- Tracking charges
        local trackedCharge = tonumber(trigger.trackcharge) or 1;
        table.insert(ret, ([=[
          local trackedCharge = %s
          if (charges > trackedCharge) then
            if (state.expirationTime ~= 0) then
              state.expirationTime = 0;
              state.changed = true;
            end
            if (state.duration ~= 0) then
              state.duration = 0;
              state.changed = true;
            end
            state.modRate = nil;
            state.value = nil;
            state.total = nil;
            state.progressType = 'timed';
          else
            if duration then
              expirationTime = expirationTime + (trackedCharge - charges) * duration
            end
            if (state.expirationTime ~= expirationTime) then
              state.expirationTime = expirationTime;
              state.changed = true;
            end
            if (state.duration ~= duration) then
              state.duration = duration;
              state.changed = true;
            end
            if (state.modRate ~= modRate) then
              state.modRate = modRate;
              state.changed = true;
            end
            state.value = nil;
            state.total = nil;
            state.progressType = 'timed';
          end
        ]=]):format(trackedCharge - 1))
      end
      table.insert(ret, "end\n")
      -- Share the CDM text policy without sharing its timing/classification cache.
      -- Swipe, countdown text and appearance each keep the appropriate timer.
      table.insert(ret, ([=[
        state.cdmTextPreview = event == "OPTIONS"
        -- Clear this on every update, including previews and charge/LoC changes.
        state.wandAppearanceDuration = not state.cdmTextPreview and cooldownData and cooldownData.wandAppearanceDuration or nil
        state.cdmHideGCDText = %s and not state.cdmTextPreview
        state.cdmGCDOnly = cooldownData and cooldownData.gcdOnly or false
        state.cdmTextDurationRequired = state.cdmHideGCDText
        state.cdmTextDurationObject = state.cdmHideGCDText and cooldownData and cooldownData.textDuration or nil
        state.cdmNativePaused = not state.cdmTextPreview and cooldownData and cooldownData.paused or false
      ]=]):format(tostring(trigger.use_showgcdtext ~= true)))
      if trackSpecificCharge then
        table.insert(ret, "if isSecret then genericShowOn = false end\n")
      end
      if(trigger.use_remaining and trigger.genericShowOn ~= "showOnReady") then
        -- A secret cooldown's time left cannot be compared here: the state
        -- stays shown and carries the window, and the display applies it as
        -- an alpha the client evaluates from the cooldown's duration object
        -- (RegionPrototype, secretRemainingWindow). `remaining` is given a
        -- value that passes the comparison below for that case.
        local remainingValue, remainingOp = tonumber(trigger.remaining or 0) or 0, trigger.remaining_operator or "<"
        local passing = remainingValue
        if remainingOp == "<" then passing = remainingValue - 1
        elseif remainingOp == ">" or remainingOp == "~=" then passing = remainingValue + 1 end
        table.insert(ret, ([[
          local remaining = 0;
          state.secretRemainingWindow = nil
          if isSecret and state.durationObject then
            state.secretRemainingWindow = {op = %q, value = %s}
            remaining = %s
          elseif (not isSecret and not paused and expirationTime and expirationTime > 0) then
            remaining = expirationTime - GetTime();
            local remainingModRate = remaining / (modRate or 1);
            local remainingCheck = %s;
            if(remainingModRate >= remainingCheck and remainingModRate > 0) then
              local event = "COOLDOWN_REMAINING_CHECK:" .. %s
              Private.ExecEnv.ScheduleScan(expirationTime - remainingCheck * (modRate or 1), event);
            end
          end
        ]]):format(remainingOp, remainingValue, passing, remainingValue, spellName))
      end

      return table.concat(ret)
    end,
    GetNameAndIcon = GetNameAndIconForSpellName,
    statesParameter = "one",
    progressType = "timed",
    useModRate = true,
    args = {
      {
      }, -- Ignore first argument (id)
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        test = "true",
        showExactOption = true,
      },
      {
        name = "extra Cooldown Progress (Spell)",
        display = function(trigger)
          return function()
            local text = "";
            if trigger.track == "charges" then
              text = L["Tracking Charge CDs"]
            elseif trigger.track == "cooldown" then
              text = L["Tracking Only Cooldown"]
            end

            if trigger.use_ignoreoverride
            then
              text = text .. L["Ignore Spell Override"]
            end

            if trigger.use_showgcd then
              if text ~= "" then text = text .. "; " end
              text = text .. L["Show GCD"]
            end

            if trigger.use_showlossofcontrol then
              if text ~= "" then text = text .. "; " end
              text = text .. L["Show Loss of Control"]
            end

            if trigger.use_matchedRune then
              if text ~= "" then text = text .. "; " end
              text = text ..L["Ignore Rune CDs"]
            end

            if trigger.use_ignoreSpellKnown then
              if text ~= "" then text = text .. "; " end
              text = text .. L["Disabled Spell Known Check"]
            end

            if trigger.genericShowOn ~= "showOnReady" and trigger.track ~= "cooldown" then
              if trigger.use_trackcharge and trigger.trackcharge ~= "" then
                if text ~= "" then text = text .. "; " end
                text = text .. L["Tracking Charge %i"]:format(trigger.trackcharge)
              end
            end
            if trigger.use_showCooldownOverlay then
              if text ~= "" then text = text .. "; " end
              text = text .. L["Show Cooldown Overlay"]
            end
            if text == "" then
              return L["|cFFffcc00Extra Options:|r None"]
            end
            return L["|cFFffcc00Extra Options:|r %s"]:format(text)
          end
        end,
        type = "collapse",
      },
      {
        name = "track",
        display = L["Track Cooldowns"],
        type = "select",
        values = "cooldown_types",
        collapse = "extra Cooldown Progress (Spell)",
        test = "true",
        required = true,
        default = "auto"
      },
      {
        name = "showgcd",
        display = L["Show Global Cooldown"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Spell)"
      },
      {
        name = "showgcdtext",
        display = "Show Global Cooldown Text",
        desc = "Show countdown numbers for the global cooldown. Leave this off to show only spell cooldown and charge recharge text while keeping the GCD swipe.",
        type = "toggle",
        test = "true",
        enable = function(trigger) return trigger.use_showgcd == true end,
        collapse = "extra Cooldown Progress (Spell)"
      },
      {
        name = "ignoreoverride",
        display = L["Ignore Spell Override"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Spell)",
      },
      {
        name = "showlossofcontrol",
        display = WeakAuras.newFeatureString .. L["Show Loss of Control"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Spell)",
      },
      {
        name = "matchedRune",
        display = L["Ignore Rune CD"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Spell)"
      },
      {
        name = "ignoreSpellKnown",
        display = L["Disable Spell Known Check"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Spell)"
      },
      {
        name = "trackcharge",
        display = L["Show CD of Charge"],
        type = "number",
        enable = function(trigger)
          return (trigger.genericShowOn ~= "showOnReady") and trigger.track ~= "cooldown"
        end,
        test = "true",
        noOperator = true,
        collapse = "extra Cooldown Progress (Spell)"
      },
      {
        name = "showCooldownOverlay",
        display = L["Show Cooldown Overlay"],
        type = "toggle",
        test = "true",
        reloadOptions = true,
        collapse = "extra Cooldown Progress (Spell)"
      },
      {
        name = "remaining",
        display = L["Remaining Time"],
        type = "number",
        enable = function(trigger) return (trigger.genericShowOn ~= "showOnReady") end
      },
      {
        name = "charges",
        display = L["Charges"],
        type = "number",
        store = true,
        conditionType = "number",
        progressTotal = "maxCharges",
        useAdditionalProgress = true,
      },
      {
        name = "spellCount",
        display = L["Spell Count"],
        type = "number",
        store = true,
        conditionType = "number"
      },
      {
        name = "stacks",
        init = "stacks",
        hidden = true,
        test = "true",
        store = true
      },
      {
        hidden  = true,
        name = "maxCharges",
        store = true,
        display = L["Max Charges"],
        conditionType = "number",
        test = "true",
      },
      {
        hidden = true,
        name = "readyTime",
        display = L["Since Ready"],
        conditionType = "elapsedTimer",
        store = true,
        test = "true"
      },
      {
        hidden = true,
        name = "chargeGainTime",
        display = L["Since Charge Gain"],
        conditionType = "elapsedTimer",
        store = true,
        test = "true"
      },
      {
        hidden = true,
        name = "chargeLostTime",
        display = L["Since Charge Lost"],
        conditionType = "elapsedTimer",
        store = true,
        test = "true"
      },
      {
        hidden = true,
        name = "effectiveSpellId",
        display = L["Effective Spell Id"],
        conditionType = "number",
        store = true,
        test = "true",
        operator_types = "only_equal"
      },
      {
        name = "genericShowOn",
        display =  L["Show"],
        type = "select",
        values = "cooldown_progress_behavior_types",
        test = "true",
        required = true,
        default = "showOnCooldown"
      },
      {
        hidden = true,
        name = "onCooldown",
        test = "true",
        display = L["On Cooldown"],
        conditionType = "bool",
        conditionTest = function(state, needle)
          if not state or not state.show then return false end
          if state.progressType == "durationObject" then
            return state.onCooldown ~= nil and state.onCooldown == (needle == 1)
          end
          return (state.paused or (not state.gcdCooldown and state.expirationTime and state.expirationTime > GetTime())) == (needle == 1)
        end,
      },
      {
        hidden = true,
        name = "gcdCooldown",
        store = true,
        test = "true"
      },
      -- Spell checks follow the same resolved rank and override as the cooldown.
      {
        name = "spellUsable",
        display = L["Spell Usable"],
        hidden = true,
        test = "true",
        conditionType = "bool",
        conditionTest = function(state, needle)
          return state and state.show and (Private.ExecEnv.IsUsableSpell(state.effectiveSpellId or state.spellname or "") == (needle == 1))
        end,
        conditionEvents = AddTargetConditionEvents({
          "SPELL_UPDATE_USABLE",
          "UNIT_POWER_FREQUENT:player"
        }),
      },
      {
        name = "insufficientResources",
        display = L["Insufficient Resources"],
        hidden = true,
        test = "true",
        conditionType = "bool",
        conditionTest = function(state, needle)
          return state and state.show and (select(2, Private.ExecEnv.IsUsableSpell(state.effectiveSpellId or state.spellname or "")) == (needle == 1));
        end,
        conditionEvents = AddTargetConditionEvents({
          "SPELL_UPDATE_USABLE",
          "UNIT_POWER_FREQUENT:player"
        }),
      },
      {
        name = "spellInRange",
        display = L["Spell in Range"],
        hidden = true,
        test = "true",
        conditionType = "bool",
        conditionTest = function(state, needle)
          local spellId = state and (state.effectiveSpellId or state.spellname)
          return state and state.show and (UnitExists('target') and spellId and WeakAuras.IsSpellInRange(spellId, 'target') == needle)
        end,
        conditionEvents = AddTargetConditionEvents({
          "WA_SPELL_RANGECHECK",
        }),
      },
      {
        hidden = true,
        test = "genericShowOn"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        hidden = true,
        name = "isReady",
        display = L["Is Ready"],
        init = 'isReady',
        store = true,
        test = "true",
        conditionType = "bool",
      },
      {
        hidden = true,
        name = "isReady_secret",
        display = L["Is Ready (Secret)"],
        init = 'WeakAuras.IsSpellReadyFromDuration(effectiveSpellId)',
        store = true,
        test = "true",
        conditionType = "bool",
      },
    },
    overlayFuncs = {
      {
        name = L["Cooldown"],
        func = function(trigger, state)
          if state.durationObject then
            return "forward", 1, 0, state.durationObject, false
          end
        end,
        enable = function(trigger, state)
          return trigger.use_showCooldownOverlay
        end
      }
    },
    hasSpellID = true,
    automaticrequired = true,
  },
  ["Cooldown Ready (Spell)"] = {
    type = "spell",
    events = {},
    loadInternalEventFunc = function(trigger, untrigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      if spellName == nil then return {} end
      return { "SPELL_COOLDOWN_READY:" .. spellName }
    end,
    name = L["Cooldown Ready Event"],
    loadFunc = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local useExact = trigger.use_exact_spellName
      local followoverride = not trigger.use_ignoreoverride
      WeakAuras.WatchSpellCooldown(spellName, false, useExact, followoverride)
    end,
    init = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local ret = [=[
        local triggerSpellName = %s
        local useExact = %s
        local followoverride = %s
        local name, _, icon = Private.ExecEnv.GetSpellInfo(overrideSpell)
        local effectiveTriggerSpellName = Private.ExecEnv.GetEffectiveSpellId(triggerSpellName, useExact, followoverride)
        local match = overrideSpell == effectiveTriggerSpellName
      ]=]
      return ret:format(spellName,
                        trigger.use_exact_spellName and "true" or "false",
                        not trigger.use_ignoreoverride and "true" or "false")
    end,
    GetNameAndIcon = GetNameAndIconForSpellName,
    statesParameter = "one",
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        init = "arg",
        showExactOption = true,
        test = "match",
      },
      {
        name = "overrideSpell",
        init = "arg",
        hidden = true,
        test = "true"
      },
      {
        name = "ignoreoverride",
        display = L["Ignore Spell Override"],
        type = "toggle",
        test = "true",
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
    },
    hasSpellID = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Charges Changed"] = {
    type = "spell",
    events = {},
    loadInternalEventFunc = function(trigger, untrigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      if spellName == nil then return {} end
      return { "SPELL_CHARGES_CHANGED:" .. spellName }
    end,
    name = L["Charges Changed Event"],
    loadFunc = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local useExact = trigger.use_exact_spellName
      local followoverride = not trigger.use_ignoreoverride
      WeakAuras.WatchSpellCooldown(spellName, false, useExact, followoverride)
    end,
    init = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local ret = [=[
        local triggerSpellName = %s
        local useExact = %s
        local followoverride = %s
        local effectiveTriggerSpellName = Private.ExecEnv.GetEffectiveSpellId(triggerSpellName, useExact, followoverride)
        local name, _, icon = Private.ExecEnv.GetSpellInfo(overrideSpell)
        local match = overrideSpell == effectiveTriggerSpellName
      ]=]
      return ret:format(spellName,
                        trigger.use_exact_spellName and "true" or "false",
                        not trigger.use_ignoreoverride and "true" or "false")
    end,
    statesParameter = "one",
    GetNameAndIcon = GetNameAndIconForSpellName,
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        init = "arg",
        showExactOption = true,
        test = "match",
      },
      {
        name = "overrideSpell",
        init = "arg",
        hidden = true,
        test = "true"
      },
      {
        name = "ignoreoverride",
        display = L["Ignore Spell Override"],
        type = "toggle",
        test = "true",
      },
      {
        name = "direction",
        required = true,
        display = L["Charge gained/lost"],
        type = "select",
        values = "charges_change_type",
        init = "arg",
        test = "Private.ExecEnv.CheckChargesDirection(direction, %q)",
        store = true,
        conditionType = "select",
        conditionValues = "charges_change_condition_type";
        conditionTest = function(state, needle)
          return state and state.show and state.direction and Private.ExecEnv.CheckChargesDirection(state.direction, needle)
        end,
      },
      {
        name = "charges",
        display = L["Charges"],
        type = "number",
        init = "arg",
        store = true,
        conditionType = "number"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
    },
    hasSpellID = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Cooldown Progress (Item)"] = {
    type = "item",
    events = {},
    internal_events = function(trigger, untrigger)
      local itemName = type(trigger.itemName) == "number" and trigger.itemName or string.format("%q", trigger.itemName or "0")
      local events = {
        "ITEM_COOLDOWN_READY:" .. itemName,
        "ITEM_COOLDOWN_CHANGED:" .. itemName,
        "ITEM_COOLDOWN_STARTED:" .. itemName,
        "COOLDOWN_REMAINING_CHECK:" .. itemName,
        "WA_DELAYED_PLAYER_ENTERING_WORLD"
      }
      if (trigger.use_showgcd) then
        tinsert(events, "GCD_START");
        tinsert(events, "GCD_CHANGE");
        tinsert(events, "GCD_END");
      end
      return events
    end,
    force_events = "ITEM_COOLDOWN_FORCE",
    name = L["Cooldown Progress (Item)"],
    loadFunc = function(trigger)
      WeakAuras.WatchItemCooldown(trigger.itemName or 0)
      if (trigger.use_showgcd) then
        WeakAuras.WatchGCD();
      end
    end,
    init = function(trigger)
      local itemName = type(trigger.itemName) == "number" and trigger.itemName or string.format("%q", trigger.itemName or "0")
      local ret = [=[
        local itemname = %s;
        local name = C_Item.GetItemInfo(itemname or 0) or "Invalid"
        local itemId, _, _, _, icon = C_Item.GetItemInfoInstant(itemname or 0)
        local showgcd = %s
        local startTime, duration, enabled, gcdCooldown = WeakAuras.GetItemCooldown(itemname, showgcd);
        local expirationTime = startTime + duration
        local genericShowOn = %s
        state.itemname = itemname;
      ]=];
      if(trigger.use_remaining and trigger.genericShowOn ~= "showOnReady") then
        local ret2 = [[
          local remaining = expirationTime > 0 and (expirationTime - GetTime()) or 0;
          local remainingCheck = %s;
          if(remaining >= remainingCheck and remaining > 0) then
            local event = "COOLDOWN_REMAINING_CHECK:" .. %s
            Private.ExecEnv.ScheduleScan(expirationTime - remainingCheck, event);
          end
        ]];
        ret = ret..ret2:format(tonumber(trigger.remaining or 0) or 0, itemName);
      end
      return ret:format(itemName,
                        trigger.use_showgcd and "true" or "false",
                        "[[" .. (trigger.genericShowOn or "") .. "]]");
    end,
    GetNameAndIcon = function(trigger)
      local name = C_Item.GetItemInfo(trigger.itemName or 0)
      local _, _, _, _, icon = C_Item.GetItemInfoInstant(trigger.itemName or 0)
      return name, icon
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemName",
        required = true,
        display = L["Item"],
        type = "item",
        test = "true"
      },
      {
        name = "itemId",
        display = WeakAuras.newFeatureString .. L["ItemId"],
        hidden = true,
        init = "itemId",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "remaining",
        display = L["Remaining Time"],
        type = "number",
        enable = function(trigger) return (trigger.genericShowOn ~= "showOnReady") end,
        init = "remaining"
      },
      {
        name = "extra Cooldown Progress (Item)",
        display = function(trigger)
          return function()
            local text = "";
            if trigger.use_showgcd then
              if text ~= "" then text = text .. "; " end
              text = text .. L["Show GCD"]
            end
            if text == "" then
              return L["|cFFffcc00Extra Options:|r None"]
            end
            return L["|cFFffcc00Extra Options:|r %s"]:format(text)
          end
        end,
        type = "collapse",
      },
      {
        name = "showgcd",
        display = L["Show Global Cooldown"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Item)"
      },
      {
        name = "genericShowOn",
        display =  L["Show"],
        type = "select",
        values = "cooldown_progress_behavior_types",
        test = "true",
        required = true,
        default = "showOnCooldown"
      },
      {
        hidden = true,
        name = "enabled",
        store = true,
        test = "true",
      },
      {
        hidden = true,
        name = "onCooldown",
        test = "true",
        display = L["On Cooldown"],
        conditionType = "bool",
        conditionTest = function(state, needle)
          return state and state.show and (not state.gcdCooldown and state.expirationTime and state.expirationTime > GetTime() or state.enabled == 0) == (needle == 1)
        end,
      },
      {
        hidden = true,
        name = "gcdCooldown",
        store = true,
        test = "true"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "progressType",
        hidden = true,
        init = "'timed'",
        store = true,
        test = "true"
      },
      {
        name = "duration",
        hidden = true,
        init = "duration",
        test = "true",
        store = true
      },
      {
        name = "expirationTime",
        init = "expirationTime",
        hidden = true,
        test = "true",
        store = true
      },
      {
        hidden = true,
        test = "(genericShowOn == \"showOnReady\" and (startTime == 0 and enabled == 1 or gcdCooldown))" ..
        "or (genericShowOn == \"showOnCooldown\" and (startTime > 0 or enabled == 0) and not gcdCooldown) " ..
        "or (genericShowOn == \"showAlways\")"
      }
    },
    hasItemID = true,
    automaticrequired = true,
    progressType = "timed"
  },
  ["Cooldown Progress (Equipment Slot)"] = {
    type = "item",
    events = {
      ["unit_events"] = {
        ["player"] = {"UNIT_INVENTORY_CHANGED"}
      }
    },
    internal_events = function(trigger, untrigger)
      local slot = trigger.itemSlot or 0
      local events = {
        "ITEM_SLOT_COOLDOWN_STARTED:" .. slot,
        "ITEM_SLOT_COOLDOWN_CHANGED:" .. slot,
        "COOLDOWN_REMAINING_CHECK:" .. slot,
        "ITEM_SLOT_COOLDOWN_ITEM_CHANGED:" .. slot,
        "ITEM_SLOT_COOLDOWN_READY:" .. slot,
        "WA_DELAYED_PLAYER_ENTERING_WORLD"
      }

      if (trigger.use_showgcd) then
        tinsert(events, "GCD_START");
        tinsert(events, "GCD_CHANGE");
        tinsert(events, "GCD_END");
      end

      return events
    end,
    force_events = "ITEM_COOLDOWN_FORCE",
    name = L["Cooldown Progress (Slot)"],
    loadFunc = function(trigger)
      WeakAuras.WatchItemSlotCooldown(trigger.itemSlot);
      if (trigger.use_showgcd) then
        WeakAuras.WatchGCD();
      end
    end,
    init = function(trigger)
      local ret = [[
        local showgcd = %s
        local itemSlot = %s
        local startTime, duration, enable, gcdCooldown = WeakAuras.GetItemSlotCooldown(itemSlot, showgcd)
        local expirationTime = startTime + duration
        local genericShowOn = %s
        local remaining = startTime + duration - GetTime();

        local name = ""
        local item = GetInventoryItemID("player", itemSlot or 0)
        if item then
          name = (C_Item.GetItemInfo(item))
        end
        local icon = GetInventoryItemTexture("player", itemSlot or 0)
        local stacks = GetInventoryItemCount("player", itemSlot or 0)
        if ((stacks == 1) and (not GetInventoryItemTexture("player", itemSlot or 0))) then
          stacks = 0
        end
      ]];
      if(trigger.use_remaining and trigger.genericShowOn ~= "showOnReady") then
        local ret2 = [[
          local remaining = expirationTime > 0 and (expirationTime - GetTime()) or 0;
          local remainingCheck = %s;
          if(remaining >= remainingCheck and remaining > 0) then
            local event = "COOLDOWN_REMAINING_CHECK:" .. %s
            Private.ExecEnv.ScheduleScan(expirationTime - remainingCheck, event);
          end
        ]];
        ret = ret..ret2:format(tonumber(trigger.remaining or 0) or 0, trigger.itemSlot or 0);
      end
      return ret:format(trigger.use_showgcd and "true" or "false",
                        trigger.itemSlot or "0",
                        "[[" .. (trigger.genericShowOn or "") .. "]]");
    end,
    GetNameAndIcon = function(trigger)
      local item = GetInventoryItemID("player", trigger.itemSlot or 0);
      local name
      if (item) then
        name = C_Item.GetItemInfo(item)
      end
      local icon = GetInventoryItemTexture("player", trigger.itemSlot or 0)
      return name, icon
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemId",
        display = WeakAuras.newFeatureString .. L["ItemId"],
        hidden = true,
        init = "item",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "itemSlot",
        required = true,
        display = L["Equipment Slot"],
        type = "select",
        values = "item_slot_types",
        test = "true"
      },
      {
        name = "extra Cooldown Progress (Equipment Slot)",
        display = function(trigger)
          return function()
            local text = "";
            if trigger.use_showgcd then
              if text ~= "" then text = text .. "; " end
              text = text .. L["Show GCD"]
            end
            if text == "" then
              return L["|cFFffcc00Extra Options:|r None"]
            end
            return L["|cFFffcc00Extra Options:|r %s"]:format(text)
          end
        end,
        type = "collapse",
      },
      {
        name = "showgcd",
        display = L["Show Global Cooldown"],
        type = "toggle",
        test = "true",
        collapse = "extra Cooldown Progress (Equipment Slot)"
      },
      {
        name = "remaining",
        display = L["Remaining Time"],
        type = "number",
        enable = function(trigger) return (trigger.genericShowOn ~= "showOnReady") end,
        init = "remaining"
      },
      {
        name = "testForCooldown",
        display = L["is useable"],
        type = "toggle",
        test = "enable == 1"
      },
      {
        name = "genericShowOn",
        display =  L["Show"],
        type = "select",
        values = "cooldown_progress_behavior_types",
        test = "true",
        required = true,
        default = "showOnCooldown"
      },
      {
        name = "progressType",
        hidden = true,
        init = "'timed'",
        store = true,
        test = "true"
      },
      {
        name = "duration",
        hidden = true,
        init = "duration",
        test = "true",
        store = true
      },
      {
        name = "expirationTime",
        init = "expirationTime",
        hidden = true,
        test = "true",
        store = true
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "itemId",
        display = L["ItemId"],
        hidden = true,
        init = "item",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "stacks",
        display = L["Stacks"],
        init = "stacks",
        hidden = true,
        test = "true",
        store = true,
        conditionType = "number"
      },
      {
        hidden = true,
        name = "onCooldown",
        test = "true",
        display = L["On Cooldown"],
        conditionType = "bool",
        conditionTest = function(state, needle)
          return state and state.show and (not state.gcdCooldown and state.expirationTime and state.expirationTime > GetTime()) == (needle == 1);
        end,
      },
      {
        hidden = true,
        name = "gcdCooldown",
        store = true,
        test = "true"
      },
      {
        hidden = true,
        test = "(genericShowOn == \"showOnReady\" and (startTime == 0 or gcdCooldown)) " ..
        "or (genericShowOn == \"showOnCooldown\" and startTime > 0 and not gcdCooldown) " ..
        "or (genericShowOn == \"showAlways\")"
      }
    },
    automaticrequired = true,
    hasItemID = true,
    progressType = "timed"
  },
  ["Cooldown Ready (Item)"] = {
    type = "item",
    events = {},
    internal_events = function(trigger)
      return { "ITEM_COOLDOWN_READY:" .. (trigger.itemName or 0) }
    end,
    name = L["Cooldown Ready Event (Item)"],
    loadFunc = function(trigger)
      WeakAuras.WatchItemCooldown(trigger.itemName or 0)
    end,
    init = function(trigger)
      local ret = [[
        local itemName = %s
        local name = C_Item.GetItemInfo(itemName) or "Invalid"
        local itemId, _, _, _, icon = C_Item.GetItemInfoInstant(itemName)
      ]]

      local itemName = type(trigger.itemName) == "number" and trigger.itemName or string.format("%q", trigger.itemName or "0")
      return ret:format(itemName)
    end,
    GetNameAndIcon = function(trigger)
      local name = C_Item.GetItemInfo(trigger.itemName or 0)
      local _, _, _, _, icon = C_Item.GetItemInfoInstant(trigger.itemName or 0)
      return name, icon
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemName",
        required = true,
        display = L["Item"],
        type = "item",
        init = "arg"
      },
      {
        name = "itemId",
        display = WeakAuras.newFeatureString .. L["ItemId"],
        hidden = true,
        init = "itemId",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
    },
    hasItemID = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Cooldown Ready (Equipment Slot)"] = {
    type = "item",
    events = {},
    internal_events = function(trigger)
      return {
        "ITEM_SLOT_COOLDOWN_READY:" .. (trigger.itemSlot or 0)
      }
    end,
    name = L["Cooldown Ready Event (Slot)"],
    loadFunc  = function(trigger)
      WeakAuras.WatchItemSlotCooldown(trigger.itemSlot);
    end,
    init = function(trigger)
      local ret = [[
        local itemSlot = %s
        local item = GetInventoryItemID("player", itemSlot)
        local name = ""
        if (item) then
          name = C_Item.GetItemInfo(item)
        end
        local icon = GetInventoryItemTexture("player", itemSlot)
      ]]

      return ret:format(trigger.itemSlot or 0)
    end,
    GetNameAndIcon = function(trigger)
      local item = GetInventoryItemID("player", trigger.itemSlot or 0)
      local name = item and C_Item.GetItemInfo(item) or nil
      local icon = GetInventoryItemTexture("player", trigger.itemSlot or 0)
      return name, icon
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemSlot",
        required = true,
        display = L["Equipment Slot"],
        type = "select",
        values = "item_slot_types",
        init = "arg"
      },
      {
        name = "itemId",
        display = WeakAuras.newFeatureString .. L["ItemId"],
        hidden = true,
        init = "item",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
    },
    hasItemID = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["GTFO"] = {
    type = "addons",
    events = {
      ["events"] = {"GTFO_DISPLAY"}
    },
    name = L["GTFO Alert"],
    statesParameter = "one",
    args = {
      {
        name = "alertType",
        display = L["Alert Type"],
        type = "select",
        init = "arg",
        values = "gtfo_types",
        store = true,
        conditionType = "select"
      },
    },
    timedrequired = true,
    progressType = "timed"
  },
  ["Global Cooldown"] = {
    type = "spell",
    events = {},
    internal_events = {
      "GCD_START",
      "GCD_CHANGE",
      "GCD_END",
      "GCD_UPDATE",
      "FA_GCD_RECHECK", -- The trigger's own end check (Private.ExecEnv.ScheduleGCDEnd).
      "WA_DELAYED_PLAYER_ENTERING_WORLD"
    },
    force_events = "GCD_UPDATE",
    name = L["Global Cooldown"],
    loadFunc = function(trigger)
      WeakAuras.WatchGCD();
    end,
    init = function(trigger)
      local ret = [[
        local inverse = %s;
        local _, _, name, icon = WeakAuras.GetGCDInfo()
        -- Forever uses the Classic GCD reference; pass its timer directly to the renderer.
        local info = C_Spell.GetSpellCooldown(29515)
        local active
        if info and not issecretvalue(info.isActive) and type(info.isActive) == "boolean" then
          active = info.isActive
        end
        local duration, expirationTime = 0, math.huge
        local progressType = "timed"
        state.durationObject = nil
        state.changed = true
        if active then
          state.durationObject = C_Spell.GetSpellCooldownDuration(29515)
          if state.durationObject then
            progressType = "durationObject"
            duration, expirationTime = nil, nil
          end
          -- Nothing else re-reads this trigger when the GCD runs out.
          Private.ExecEnv.ScheduleGCDEnd(info)
        end
      ]];
      return ret:format(trigger.use_inverse and "true" or "false");
    end,
    statesParameter = "one",
    args = {
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "duration",
        hidden = true,
        init = "duration",
        test = "true",
        store = true
      },
      {
        name = "expirationTime",
        init = "expirationTime",
        hidden = true,
        test = "true",
        store = true
      },
      {
        name = "progressType",
        hidden = true,
        init = "progressType",
        test = "true",
        store = true
      },
      {
        hidden = true,
        test = "active ~= nil and ((inverse and not active) or (not inverse and active))"
      }
    },
    hasSpellID = true,
    automaticrequired = true,
    progressType = "timed"
  },
  ["Action Usable"] = {
    type = "spell",
    events = function()
      local events = {
        "SPELL_UPDATE_USABLE",
        "PLAYER_TARGET_CHANGED",
        "RUNE_POWER_UPDATE",
        "PLAYER_SOFT_ENEMY_CHANGED",
        "PLAYER_SOFT_FRIEND_CHANGED"
      }
      
      return {
        ["events"] = events,
        ["unit_events"] = {
          ["player"] = { "UNIT_POWER_FREQUENT" }
        }
      }
    end,
    loadInternalEventFunc = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      if spellName == nil then return {} end
      return { "SPELL_COOLDOWN_CHANGED:" .. spellName }
    end,
    force_events = "SPELL_UPDATE_USABLE",
    name = L["Spell Usable"],
    statesParameter = "one",
    loadFunc = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local useExact = trigger.use_exact_spellName
      local followoverride = not trigger.use_ignoreoverride
      WeakAuras.WatchSpellCooldown(spellName, false, useExact, followoverride)
    end,
    init = function(trigger)
      local spellName = type(trigger.spellName) ~= "table" and trigger.spellName or 0
      if type(trigger.spellName) == "string" then
        spellName = select(7, Private.ExecEnv.GetSpellInfo(spellName)) or 0
      end
      local ret = [=[
        local spellName = %s
        local useExact = %s
        local followoverride = %s
        local effectiveSpellId = Private.ExecEnv.GetEffectiveSpellId(spellName, useExact, followoverride)
        local name, _, icon = Private.ExecEnv.GetSpellInfo(effectiveSpellId)
      ]=]

      if trigger.use_ignoreSpellCooldown then
        ret = ret .. [=[local active = Private.ExecEnv.IsUsableSpell(spellName or "")]=]
      else
        ret = ret .. [=[
        local startTime, duration, gcdCooldown, readyTime, _, paused = WeakAuras.GetSpellCooldown(effectiveSpellId, nil, nil, nil, nil)
        local charges, maxCharges, spellCount, chargeGainTime, chargeLostTime = WeakAuras.GetSpellCharges(effectiveSpellId, nil)
        -- Restricted counts cannot participate in trigger comparisons or stored numeric conditions.
        if issecretvalue(charges) then charges = nil end
        if issecretvalue(maxCharges) then maxCharges = nil end
        if issecretvalue(spellCount) then spellCount = nil end
        local stacks = maxCharges and maxCharges > 1 and charges
                       or spellCount and spellCount > 0 and spellCount
                       or nil
        local ready
        if C_Secrets.ShouldSpellCooldownBeSecret(effectiveSpellId) then
          local cooldownData = Private.ExecEnv.GetSpellCooldownData(effectiveSpellId)
          ready = cooldownData and cooldownData.ready == true
        else
          if charges == nil then
            charges = (duration == 0 or gcdCooldown) and 1 or 0
          end
          ready = (startTime == 0 and not paused) or charges > 0
        end
        local active = Private.ExecEnv.IsUsableSpell(spellName or "") and ready
        ]=]
      end
      if(trigger.use_targetRequired) then
        ret = ret.."active = active and WeakAuras.IsSpellInRange(spellName or '', 'target')\n";
      end
      if(trigger.use_inverse) then
        ret = ret.."active = not active\n";
      end

      if (type(spellName) == "string") then
        spellName = string.format("%q", spellName)
      end

      return ret:format(spellName,
                        trigger.use_exact_spellName and "true" or "false",
                        not trigger.use_ignoreoverride and "true" or "false")
    end,
    GetNameAndIcon = GetNameAndIconForSpellName,
    args = {
      {
        name = "spellName",
        display = L["Spell"],
        required = true,
        type = "spell",
        test = "true",
        showExactOption = true,
        store = true
      },
      {
        name = "ignoreoverride",
        display = L["Ignore Spell Override"],
        type = "toggle",
        test = "true",
      },
      -- This parameter uses the IsSpellInRange API function, but it does not check spell range at all
      -- IsSpellInRange returns nil for invalid targets, 0 for out of range, 1 for in range (0 and 1 are both "positive" values)
      {
        name = "targetRequired",
        display = L["Require Valid Target"],
        type = "toggle",
        test = "true"
      },
      {
        name = "ignoreSpellCooldown",
        display = L["Ignore Spell Cooldown/Charges"],
        type = "toggle",
        test = "true"
      },
      {
        name = "charges",
        display = L["Charges"],
        type = "number",
        enable = function(trigger) return not trigger.use_inverse and not trigger.use_ignoreSpellCooldown end,
        store = true,
        conditionType = "number",
      },
      {
        name = "spellCount",
        display = L["Spell Count"],
        type = "number",
        enable = function(trigger) return not trigger.use_ignoreSpellCooldown end,
        store = true,
        conditionType = "number",
      },
      {
        hidden = true,
        name = "readyTime",
        display = L["Since Ready"],
        conditionType = "elapsedTimer",
        store = true,
        test = "true",
        enable = function(trigger) return not trigger.use_ignoreSpellCooldown end,
      },
      {
        hidden = true,
        name = "chargeGainTime",
        display = L["Since Charge Gain"],
        conditionType = "elapsedTimer",
        store = true,
        test = "true",
        enable = function(trigger) return not trigger.use_ignoreSpellCooldown end,
      },
      {
        hidden = true,
        name = "chargeLostTime",
        display = L["Since Charge Lost"],
        conditionType = "elapsedTimer",
        store = true,
        test = "true",
        enable = function(trigger) return not trigger.use_ignoreSpellCooldown end,
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
        reloadOptions = true
      },
      {
        name = "spellInRange",
        display = L["Spell in Range"],
        hidden = true,
        test = "true",
        conditionType = "bool",
        conditionTest = function(state, needle)
          return state and state.show and (UnitExists('target') and state.spellName and WeakAuras.IsSpellInRange(state.spellName, 'target') == needle)
        end,
        conditionEvents = AddTargetConditionEvents({
          "WA_SPELL_RANGECHECK",
        })
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "stacks",
        display = L["Stacks"],
        hidden = true,
        init = "stacks",
        test = "true",
        store = true,
        conditionType = "number",
        enable = function(trigger) return not trigger.use_ignoreSpellCooldown end,
      },
      {
        hidden = true,
        test = "active"
      }
    },
    hasSpellID = true,
    automaticrequired = true,
    progressType = "none"
  },
  ["Talent Known"] = {
    type = "unit",
    events = function()
      return {}
    end,
    internal_events = {"WA_TALENT_UPDATE"},
    force_events = "TRAIT_CONFIG_UPDATED",
    name = L["Talent Known"],
    init = function(trigger)
      local ret = {}
      if (trigger.use_talent) then
        -- Single selection
        local index = trigger.talent and trigger.talent.single;
        local tier = index and ceil(index / MAX_NUM_TALENTS)
        local column = index and ((index - 1) % MAX_NUM_TALENTS + 1)
        table.insert(ret, ([[
          local tier = %s;
          local column = %s;
          local active = false
          local name, icon, _, _, rank = Private.ExecEnv.GetTalentInfo(tier, column)
          if rank and rank > 0 then
            active = true;
            activeName = name;
            activeIcon = icon;
          end
        ]]):format(tier or 0, column or 0))
      elseif (trigger.use_talent == false) then
        if (trigger.talent.multi) then
          table.insert(ret, [[
            local active = true
            local activeIcon, activeName, _
          ]])
          do
            table.insert(ret, [[
              local index
              local rank = 0
            ]])
          end
          for index, value in pairs(trigger.talent.multi) do
            do
              table.insert(ret, ([[
                local talentId = %s
                local shouldBeActive = %s
                if talentId then
                  activeName, activeIcon, _, rank = WeakAuras.GetTalentById(talentId)
                  if activeName ~= nil then
                    if rank > 0 ~= shouldBeActive then
                      active = false
                    end
                  end
                end
              ]]):format(index, value and "true" or "false"))
            end
          end
        end
      end
      
      return table.concat(ret)
    end,
    args = {
      {
        name = "class",
        display = L["Class"],
        type = "select",
        init = "select(2, UnitClass('player'))",
        values = "class_types",
        store = true,
        conditionType = "select",
        required = true,
        enable = true,
        hidden = false,
        reloadOptions = true,
      },
      {
        name = "spec",
        display = L["Talent Specialization"],
        type = "select",
        init = "Private.ExecEnv.GetSpecialization()",
        required = true,
        values = function(trigger)
          return WeakAuras.spec_types_specific[trigger.class]
        end,
        enable = function(trigger)
          if trigger.use_class and trigger.class then
            return true
          else
            return false
          end
        end,
        reloadOptions = true,
      },
      {
        name = "talent",
        display = L["Talent"],
        type = "multiselect",
        values = function(trigger)
          local class = select(2, UnitClass("player"));
          do
            local classId
            for i = 1, GetNumClasses() do
              if select(2, GetClassInfo(i)) == trigger.class then
                classId = i
              end
            end
            if classId and trigger.spec then
              local specId = GetSpecializationInfoForClassID(classId, trigger.spec)
              if specId then
                local talentData = Private.GetTalentData(specId)
                if talentData then
                  return talentData
                end
              end
            end
            return {}
          end
        end,
        multiUseControlWhenFalse = true,
        multiAll = true,
        multiNoSingle = true,
        multiTristate = true, -- values can be true/false/nil
        control = "WeakAurasMiniTalent",
        multiConvertKey = function(trigger, key)
          local classId
          for i = 1, GetNumClasses() do
            if select(2, GetClassInfo(i)) == trigger.class then
              classId = i
            end
          end
          if classId and trigger.spec then
            local specId = GetSpecializationInfoForClassID(classId, trigger.spec)
            if specId then
              local talentData = Private.GetTalentData(specId)
              if type(talentData) == "table" and talentData[key] then
                return talentData[key][1]
              end
            end
          end
        end or nil,
        enable = function(trigger)
          do
            if trigger.use_class and trigger.class and trigger.use_spec and trigger.spec then
              return true
            else
              return false
            end
          end
        end,
        test = "active",
        reloadOptions = true,
      },
      {
        display = L["Rank"],
        desc = L["Check if a single talent match a Rank"],
        name = "stacks",
        type = "number",
        conditionType = "number",
        init = "rank",
        store = true,
        enable = function(trigger)
          do
            if trigger.use_class and trigger.class
            and trigger.use_spec and trigger.spec
            and trigger.use_talent == false
            and trigger.talent and type(trigger.talent.multi) == "table"
            then
              local count, value = 0, nil
              for _, v in pairs(trigger.talent.multi) do
                value = v
                count = count + 1
              end
              return count == 1 and value == true
            end
          end
          return false
        end,
      },
      {
        name = "herotalent",
        display = L["Hero Talent"],
        type = "multiselect",
        values = function(trigger)
          do return {} end
          local classId
          for i = 1, GetNumClasses() do
            if select(2, GetClassInfo(i)) == trigger.class then
              classId = i
            end
          end
          if classId and trigger.spec then
            local specId = GetSpecializationInfoForClassID(classId, trigger.spec)
            if specId then
              local _, heroData = Private.GetTalentData(specId)
              if heroData then
                return heroData
              end
            end
          end
          return {}
        end,
        multiUseControlWhenFalse = true,
        multiAll = true,
        multiNoSingle = true,
        multiTristate = true,
        control = "WeakAurasMiniTalent",
        multiConvertKey = function(trigger, key)
          local classId
          for i = 1, GetNumClasses() do
            if select(2, GetClassInfo(i)) == trigger.class then
              classId = i
            end
          end
          if classId and trigger.spec then
            local specId = GetSpecializationInfoForClassID(classId, trigger.spec)
            if specId then
              local _, heroData = Private.GetTalentData(specId)
              if type(heroData) == "table" and type(heroData[key]) == "table" then
                return heroData[key][1]
              end
            end
          end
        end,
        enable = function(trigger)
          return false
        end,
        test = "heroActive",
        reloadOptions = true,
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
        enable = false,
        hidden = true,
      },
      {
        hidden = true,
        name = "icon",
        init = "activeIcon",
        store = "true",
        test = "true"
      },
      {
        hidden = true,
        name = "name",
        init = "activeName",
        store = "true",
        test = "true"
      },
    },
    automaticrequired = true,
    statesParameter = "one",
    progressType = "none"
  },

  ["Class/Spec"] = {
    type = "unit",
    events = function()
      local events = { "PLAYER_TALENT_UPDATE" }
      return {
        ["events"] = events
      }
    end,
    force_events = "PLAYER_TALENT_UPDATE",
    name = L["Player Class"],
    init = function(trigger)
      return [[
         local specId, specName, _, specIcon = Private.ExecEnv.GetSpecializationInfo(Private.ExecEnv.GetSpecialization())
      ]]
    end,
    args = {
      {
        name = "specId",
        display = L["Player Class"],
        type = "multiselect",
        values = "spec_types_all",
        store = "true",
        conditionType = "select",
        sorted = true,
        sortOrder = Private.specs_sorted,
      },
      {
        hidden = true,
        name = "icon",
        init = "specIcon",
        store = "true",
        test = "true"
      },
      {
        hidden = true,
        name = "name",
        init = "specName",
        store = "true",
        test = "true"
      },
    },
    automaticrequired = true,
    statesParameter = "one",
    progressType = "none"
  },
  ["Totem"] = {
    type = "spell",
    events = {
      ["events"] = {
        "PLAYER_TOTEM_UPDATE",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED"
      }
    },
    internal_events = {
      "COOLDOWN_REMAINING_CHECK",
      "FA_TOTEM_UPDATE",
    },
    force_events = "PLAYER_ENTERING_WORLD",
    name = L["Totem"],
    statesParameter = "full",
    progressType = "timed",
    triggerFunction = function(trigger)
      local ret = [[return
      function (states, event, slotId)
        local totemType = %s;
        local triggerTotemName = %q
        local triggerTotemPattern = %q
        local triggerTotemPatternOperator = %q
        local triggerSpellId = %s
        local followoverride = %s
        local triggerTotemIcon = %s
        local triggerTotemIconOperator = %q
        local clone = %s
        local inverse = %s
        local remainingCheck = %s

        local function checkActive(remaining)
          return remaining %s remainingCheck;
        end

        if (totemType) then -- Check a specific totem slot
          if slotId and not issecretvalue(slotId) and (event == "PLAYER_TOTEM_UPDATE" or event == "FA_TOTEM_UPDATE") and totemType ~= slotId then
            -- PLAYER_TOTEM_UPDATE for a different slot
            return false
          end

          -- While the slot is secret its times are nil and durationObject is its timer.
          local haveTotem, totemName, startTime, duration, icon, modRate, spellId, durationObject = Private.ExecEnv.GetTotemSlotInfo(totemType);
          active = haveTotem and (durationObject ~= nil or (startTime and startTime ~= 0));

          if not Private.ExecEnv.CheckTotemName(totemName, triggerTotemName, triggerTotemPattern, triggerTotemPatternOperator) then
            active = false;
          end

          if not Private.ExecEnv.CheckTotemIcon(icon, triggerTotemIcon, triggerTotemIconOperator) then
            active = false
          end

          if not Private.ExecEnv.CheckTotemSpellId(spellId, triggerSpellId, followoverride) then
            active = false
          end

          if (inverse) then
            active = not active;
            if (triggerTotemName) then
              icon = Private.ExecEnv.GetSpellIcon(triggerTotemName);
            end
          elseif (active and remainingCheck and durationObject) then
            -- The remaining time of a secret totem cannot be compared.
            active = false
          elseif (active and remainingCheck) then
            local expirationTime = startTime and (startTime + duration) or 0;
            local remainingTime = expirationTime - GetTime()
            if (remainingTime >= remainingCheck) then
              Private.ExecEnv.ScheduleScan(expirationTime - remainingCheck);
            end
            active = checkActive(remainingTime);
          end
          states[""] = states[""] or {}
          local state = states[""];
          state.show = active;
          state.changed = true;
          if (active) then
            state.name = totemName;
            state.totemName = totemName;
            Private.ExecEnv.SetTotemStateTimer(state, startTime, duration, modRate, durationObject)
            state.spellId = spellId
            state.icon = icon;
          end
        elseif inverse then -- inverse without a specific slot
          local found = false;
          for i = 1, 5 do
            local haveTotem, totemName, startTime, duration, icon, modRate, spellId, durationObject = Private.ExecEnv.GetTotemSlotInfo(i);
            if (haveTotem and (durationObject ~= nil or (startTime and startTime ~= 0))
              and Private.ExecEnv.CheckTotemName(totemName, triggerTotemName, triggerTotemPattern, triggerTotemPatternOperator)
              and Private.ExecEnv.CheckTotemIcon(icon, triggerTotemIcon, triggerTotemIconOperator)
              and Private.ExecEnv.CheckTotemSpellId(spellId, triggerSpellId, followoverride)
            ) then
              found = true;
            end
          end
          local cloneId = "";
          states[cloneId] = states[cloneId] or {};
          local state = states[cloneId];
          state.show = not found;
          state.changed = true;
          state.name = triggerTotemName;
          state.totemName = triggerTotemName;
          if (triggerTotemName) then
            state.icon = Private.ExecEnv.GetSpellIcon(triggerTotemName)
          end
        else -- cloning, check all slots
          for i = 1, 5 do
            local haveTotem, totemName, startTime, duration, icon, modRate, spellId, durationObject = Private.ExecEnv.GetTotemSlotInfo(i);
            active = haveTotem and (durationObject ~= nil or (startTime and startTime ~= 0));

            if not Private.ExecEnv.CheckTotemName(totemName, triggerTotemName, triggerTotemPattern, triggerTotemPatternOperator)
              or not Private.ExecEnv.CheckTotemIcon(icon, triggerTotemIcon, triggerTotemIconOperator)
              or not Private.ExecEnv.CheckTotemSpellId(spellId, triggerSpellId, followoverride)
            then
              active = false;
            end
            if (active and remainingCheck and durationObject) then
              active = false
            elseif (active and remainingCheck) then
              local expirationTime = startTime and (startTime + duration) or 0;
              local remainingTime = expirationTime - GetTime()
              if (remainingTime >= remainingCheck) then
                Private.ExecEnv.ScheduleScan(expirationTime - remainingCheck);
              end
              active = checkActive(remainingTime);
            end

            local cloneId = clone and tostring(i) or "";
            states[cloneId] = states[cloneId] or {};
            local state = states[cloneId];
            state.show = active;
            state.changed = true;
            if (active) then
              state.name = totemName;
              state.totemName = totemName;
              Private.ExecEnv.SetTotemStateTimer(state, startTime, duration, modRate, durationObject)
              state.spellId = spellId
              state.icon = icon;
            end
            if (active and not clone) then
              break;
            end
          end
        end
        return true;
      end
      ]];
      local totemName = tonumber(trigger.totemName) and Private.ExecEnv.GetSpellName(tonumber(trigger.totemName)) or trigger.totemName;
      ret = ret:format(trigger.use_totemType and tonumber(trigger.totemType) or "nil",
        trigger.use_totemName and totemName or "",
        trigger.use_totemNamePattern and trigger.totemNamePattern or "",
        trigger.use_totemNamePattern and trigger.totemNamePattern_operator or "",
        trigger.use_totemSpellId and trigger.totemSpellId or "nil",
        not trigger.use_ignoreoverride and "true" or "false",
        trigger.use_icon and trigger.icon or "nil",
        trigger.use_icon and trigger.icon_operator or "",
        trigger.use_clones and "true" or "false",
        trigger.use_inverse and "true" or "false",
        trigger.use_remaining and tonumber(trigger.remaining or 0) or "nil",
        trigger.use_remaining and trigger.remaining_operator or "<");
      return ret;
    end,
    args = {
      {
        name = "totemType",
        display = L["Totem Number"],
        type = "select",
        values = "totem_types"
      },
      {
        name = "totemName",
        display = L["Totem Name"],
        type = "string",
        conditionType = "string",
        store = true,
        desc = L["Enter a name or a spellId"]
      },
      {
        name = "totemNamePattern",
        display = L["Totem Name Pattern Match"],
        type = "longstring",
      },
      {
        name = "totemSpellId",
        display = L["Spell Id"],
        type = "spell",
        conditionType = "number",
        operator_types = "only_equal",
        enable = true,
      },
      {
        name = "ignoreoverride",
        display = L["Ignore Spell Override"],
        type = "toggle",
        test = "true",
        enable = function(trigger)
          return trigger.use_totemSpellId and true
        end,
      },
      {
        name = "icon",
        display = L["Totem Icon"],
        type = "number",
        conditionType = "number",
        operator_types = "only_equal",
        store = true,
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
      },
      {
        name = "clones",
        display = L["Clone per Match"],
        type = "toggle",
        test = "true",
        enable = function(trigger) return not (trigger.use_totemType or trigger.use_inverse) end,
      },
      {
        name = "remaining",
        display = L["Remaining Time"],
        type = "number",
        enable = function(trigger) return not(trigger.use_inverse) end
      },
    },
    automaticrequired = true
  },
  ["Role"] = {
    type = "unit", name = "Role", statesParameter = "one",
    automaticrequired = true, progressType = "none",
    events = {events = {"PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED"}},
    force_events = "PLAYER_ENTERING_WORLD",
    init = function()
      return [[local role = UnitGroupRolesAssigned("player")
if issecretvalue(role) or role == nil or role == "NONE" then return false end
]]
    end,
    args = {
      {name = "role", display = "Role", type = "select", required = true, default = "DAMAGER",
        values = function() return {TANK = "Tank", HEALER = "Healer", DAMAGER = "Damager"} end,
        init = "role", store = true, conditionType = "select"},
      {name = "name", init = "role", hidden = true, store = true, test = "true"},
      {name = "roleNote", type = "description", display = "", text = function() return "Checks your assigned role. No match when the game reports no assigned role." end},
    },
  },
  ["Tracking"] = {
    type = "unit", name = "Tracking", statesParameter = "one",
    automaticrequired = true, progressType = "none",
    events = {events = {"MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD"}},
    force_events = "PLAYER_ENTERING_WORLD",
    init = function(trigger)
      return ([[local active, name, icon = Private.ExecEnv.GetTrackingState(%q)
if active == nil then return false end
local showOn = %q
if (showOn == "active" and not active) or (showOn == "inactive" and active) then return false end
]]):format(trigger.trackingType or "", trigger.trackingShow or "active")
    end,
    args = {
      {name = "trackingType", display = "Tracking Type", type = "select", required = true,
        values = function(trigger) return Private.ExecEnv.GetTrackingChoices(trigger.trackingType) end, test = "true"},
      {name = "trackingShow", display = "Show On", type = "select", required = true,
        default = "active", values = function() return {active = "Active", inactive = "Inactive", always = "Always"} end, test = "true"},
      {name = "active", display = "Tracking Active", init = "active", hidden = true, store = true, test = "true", conditionType = "bool"},
      {name = "name", init = "name", hidden = true, store = true, test = "true"},
      {name = "icon", init = "icon", hidden = true, store = true, test = "true"},
    },
  },
  ["Equipment Durability"] = {
    type = "item", name = "Equipment Durability", statesParameter = "one",
    automaticrequired = true, progressType = "static",
    events = {events = {"UPDATE_INVENTORY_DURABILITY","PLAYER_EQUIPMENT_CHANGED","PLAYER_ENTERING_WORLD"}},
    force_events = "PLAYER_ENTERING_WORLD",
    init = function(trigger)
      local slot = tonumber(trigger.durabilitySlot) or 0
      return ([[local lowest, overall, broken, itemCount = Private.ExecEnv.GetEquipmentDurability(%d)
if lowest == nil then return false end
local progress = %s
]]):format(slot, trigger.durabilityProgress == "lowest" and "lowest" or "overall")
    end,
    args = {
      {name = "durabilitySlot", display = "Equipment Slot", type = "select", required = true, default = 0,
        values = function()
          local slots = {[0] = "All Equipped Items"}
          for slot, name in pairs(Private.item_slot_types) do
            if slot >= 1 and slot <= 19 then slots[slot] = name end
          end
          return slots
        end, test = "true"},
      {name = "durabilityProgress", display = "Progress Value", type = "select", required = true, default = "overall",
        values = function() return {overall = "Overall Durability (%)", lowest = "Lowest Item Durability (%)"} end, test = "true"},
      {name = "durabilityNote", type = "description", display = "", text = function() return "Checks equipped items only. Empty slots and items without durability are ignored. Progress Value controls %p. Values are percentages from 0 to 100." end},
      {name = "lowest", display = "Lowest Item Durability (%)", type = "number", init = "lowest", store = true, conditionType = "number"},
      {name = "overall", display = "Overall Durability (%)", type = "number", init = "overall", store = true, conditionType = "number"},
      {name = "broken", display = "Broken Items", type = "number", init = "broken", store = true, conditionType = "number"},
      {name = "itemCount", display = "Items with Durability", type = "number", init = "itemCount", store = true, conditionType = "number", hidden = true, test = "true"},
      {name = "value", display = "Progress Value", type = "number", init = "progress", store = true, conditionType = "number", hidden = true, test = "true"},
      {name = "total", display = "Progress Total", type = "number", init = "100", store = true, conditionType = "number", hidden = true, test = "true"},
      {name = "progressType", init = "'static'", hidden = true, store = true, test = "true"},
      {name = "name", init = "'Equipment Durability'", hidden = true, store = true, test = "true"},
      {name = "icon", init = "132530", hidden = true, store = true, test = "true"},
    },
  },
  ["Bag Space"] = {
    type = "item", name = "Bag Space", statesParameter = "one",
    automaticrequired = true, progressType = "static",
    events = {events = {"BAG_UPDATE_DELAYED","BAG_CONTAINER_UPDATE","PLAYER_ENTERING_WORLD"}},
    force_events = "PLAYER_ENTERING_WORLD",
    init = function(trigger)
      return ([[local free, totalSlots, used, freePercent = Private.ExecEnv.GetBagSpace(%s)
if free == nil then return false end
]]):format(trigger.use_includeSpecialty and "true" or "false")
    end,
    args = {
      {name = "includeSpecialty", display = "Include Specialty Bags", type = "toggle", test = "true"},
      {name = "bagNote", type = "description", display = "", text = function() return "Counts carried bags, not bank storage. By default only general-purpose slots count. Specialty bags may only accept certain item types." end},
      {name = "free", display = "Free Slots", type = "number", init = "free", store = true, conditionType = "number"},
      {name = "used", display = "Used Slots", type = "number", init = "used", store = true, conditionType = "number"},
      {name = "totalSlots", display = "Total Slots", type = "number", init = "totalSlots", store = true, conditionType = "number"},
      {name = "freePercent", display = "Free Space (%)", type = "number", init = "freePercent", store = true, conditionType = "number"},
      {name = "value", display = "Progress Value", type = "number", init = "free", store = true, conditionType = "number", hidden = true, test = "true"},
      {name = "total", display = "Progress Total", type = "number", init = "totalSlots", store = true, conditionType = "number", hidden = true, test = "true"},
      {name = "progressType", init = "'static'", hidden = true, store = true, test = "true"},
      {name = "name", init = "'Bag Space'", hidden = true, store = true, test = "true"},
      {name = "icon", init = "133633", hidden = true, store = true, test = "true"},
    },
  },
  -- Count carried projectiles independently of equipped ammo.
  ["Ammo"] = {
    type = "item",
    name = "Ammo",
    statesParameter = "one",
    automaticrequired = true,
    progressType = "static",
    events = {events = {}},
    internal_events = {"FA_AMMO_UPDATE"},
    force_events = "FA_AMMO_UPDATE",
    loadFunc = function() Private.ExecEnv.WatchAmmo() end,
    init = function(trigger)
      return ([[local count, name, icon = Private.ExecEnv.GetAmmoCount(%q, %q)
if count == nil then return false end
]]):format(trigger.ammoItemIDs or "", trigger.ammoMode or "equipped")
    end,
    args = {
      {
        name = "ammoItemIDs",
        display = "Item IDs",
        type = "string",
        required = true,
        test = "true",
        default = "",
        reloadOptions = true,
        desc = "Leave blank to count the equipped ammo (or all carried ammo, see Count). Enter comma-separated item IDs to count only those ammo items. Bank storage is excluded.",
        validate = function(_, value) return Private.ExecEnv.ValidateAmmoItemIDs(value) end,
      },
      -- With the IDs blank: the equipped ammo's icon and amount (what is
      -- shot), or every kind carried under a generic icon.
      {
        name = "ammoMode",
        display = "Count",
        type = "select",
        values = "ammo_mode_types",
        required = true,
        test = "true",
        default = "equipped",
        reloadOptions = true,
        enable = function(trigger) return not trigger.ammoItemIDs or trigger.ammoItemIDs:match("^%s*$") ~= nil end,
      },
      {
        name = "count",
        display = "Ammo Count",
        type = "number",
        init = "count",
        store = true,
        conditionType = "number",
        multiEntry = {operator = "and", limit = 2}
      },
      {
        name = "stacks",
        display = L["Stacks"],
        init = "count",
        hidden = true,
        store = true,
        test = "true",
        conditionType = "number"
      },
      {
        name = "value",
        display = L["Progress Value"],
        init = "count",
        hidden = true,
        store = true,
        test = "true",
        conditionType = "number"
      },
      {
        name = "total",
        init = "0",
        hidden = true,
        store = true,
        test = "true"
      },
      {
        name = "progressType",
        init = "'static'",
        hidden = true,
        store = true,
        test = "true"
      },
      {
        name = "name",
        display = L["Name"],
        init = "name",
        hidden = true,
        store = true,
        test = "true"
      },
      {
        name = "icon",
        init = "icon",
        hidden = true,
        store = true,
        test = "true"
      },
    },
  },

  -- Range from the action bars (ActionRange.lua): the client reports range
  -- changes for the slots holding the spell, so this never polls.
  ["Spell in Range (Action Bar)"] = {
    type = "spell",
    name = "Spell in Range (Action Bar)",
    statesParameter = "one",
    automaticrequired = true,
    progressType = "none",
    events = {events = {}},
    internal_events = {"FA_ACTION_RANGE_UPDATE"},
    force_events = "FA_ACTION_RANGE_UPDATE",
    loadFunc = function(trigger)
      Private.ExecEnv.WatchActionRange(trigger.spellName, trigger.use_exact_spellName)
    end,
    init = function(trigger)
      local spell = trigger.spellName
      local literal = tonumber(spell) or string.format("%q", tostring(spell or ""))
      return ([[local inRange, checksRange, slot, name, icon = Private.ExecEnv.GetActionRange(%s, %s)
if slot == nil then return false end
local rangeState = inRange and "inRange" or (checksRange and "outOfRange") or "noTarget"
]]):format(literal, tostring(trigger.use_exact_spellName == true))
    end,
    GetNameAndIcon = GetNameAndIconForSpellName,
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        test = "true",
        showExactOption = true,
        desc = "The spell must be on an action bar (any page). Without Exact Spell ID, any rank on the bars counts.",
      },
      {
        name = "actionBarNote",
        type = "description",
        display = "",
        text = function() return "Spell must be on the Action Bar. Cheaper than the Spell in Range trigger." end,
      },
      -- Range is only ever checked against the current target; Out of Range
      -- means a target exists and is out of range, so no-target is neither.
      {
        name = "rangeState",
        display = "Show On",
        type = "select",
        values = "action_range_types",
        init = "rangeState",
        store = true,
        conditionType = "select",
      },
      {
        name = "inRange",
        display = "In Range",
        init = "inRange == true",
        hidden = true,
        store = true,
        test = "true",
        conditionType = "bool",
      },
      {
        name = "slot",
        display = "Action Slot",
        init = "slot",
        hidden = true,
        store = true,
        test = "true",
        conditionType = "number",
      },
      {
        name = "name",
        display = L["Name"],
        init = "name",
        hidden = true,
        store = true,
        test = "true"
      },
      {
        name = "icon",
        init = "icon",
        hidden = true,
        store = true,
        test = "true"
      },
    },
  },

  ["Item Count"] = {
    type = "item",
    events = {
      ["events"] = {
        "BAG_UPDATE_DELAYED",
        "PLAYER_ENTERING_WORLD"
      }
    },
    internal_events = {
      "ITEM_COUNT_UPDATE",
    },
    force_events = "BAG_UPDATE_DELAYED",
    name = L["Item Count"],
    loadFunc = function(trigger)
      if(trigger.use_includeCharges) then
        WeakAuras.RegisterItemCountWatch();
      end
    end,
    init = function(trigger)
      local itemName = type(trigger.itemName) == "number" and trigger.itemName or string.format("%q", trigger.itemName or "0")
      local ret = [[
        local itemName = %s
        local exactSpellMatch = %s
        local itemId = C_Item.GetItemInfo(itemName)
        if not exactSpellMatch and tonumber(itemName) then
          itemName = itemId
        end
        local count = C_Item.GetItemCount(itemName or "", %s, %s, nil, %s);
        local reagentQuality, reagentQualityTexture
        if itemName then
          reagentQuality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemName)
          if reagentQuality then
            local expansionID = select(15, C_Item.GetItemInfo(itemName))
            if expansionID == 11 then
              reagentQualityTexture = CreateAtlasMarkupWithAtlasSize("Professions-Icon-Quality-12-Tier" .. reagentQuality .. "-Small")
            else
              reagentQualityTexture = CreateAtlasMarkupWithAtlasSize("Professions-Icon-Quality-Tier" .. reagentQuality .. "-Small")
            end
          end
        end
      ]];
      return ret:format(
        itemName,
        trigger.use_exact_itemName and "true" or "nil",
        trigger.use_includeBank and "true" or "nil",
        trigger.use_includeCharges and "true" or "nil",
        trigger.use_includeWarBandBank and "true" or "nil"
      )
    end,
    args = {
      {
        name = "itemName",
        required = true,
        display = L["Item"],
        type = "item",
        showExactOption = true,
        test = "true"
      },
      {
        name = "itemId",
        display = WeakAuras.newFeatureString .. L["ItemId"],
        hidden = true,
        init = "itemId",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "name",
        display = L["Name"],
        init = "itemName",
        type = "string",
        hidden = true,
        store = true,
        test = "true",
        conditionType = "string"
      },
      {
        name = "includeBank",
        display = L["Include Bank"],
        type = "toggle",
        test = "true"
      },
      {
        name = "includeWarBandBank",
        display = L["Include War Band Bank"],
        type = "toggle",
        test = "true",
        enable = true,
      },
      {
        name = "includeCharges",
        display = L["Include Charges"],
        type = "toggle",
        test = "true"
      },
      {
        name = "count",
        display = L["Item Count"],
        type = "number"
      },
      {
        name = "stacks",
        display = L["Stacks"],
        init = "count",
        hidden = true,
        store = true,
        test = "true",
        conditionType = "number"
      },
      {
        name = "value",
        init = "count",
        hidden = true,
        store = true,
        test = "true",
        display = L["Progress Value"],
        conditionType = "number"
      },
      {
        name = "total",
        init = 0,
        hidden = true,
        store = true,
        test = "true",
        display = L["Progress Total"],
        conditionType = "number"
      },
      {
        name = "progressType",
        init = "'static'",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "icon",
        init = "C_Item.GetItemIconByID(itemName or '')",
        hidden = true,
        store = true,
        test = "true"
      },
      {
        name = "name",
        init = "itemName and itemName ~= '' and C_Item.GetItemNameByID(itemName) or itemName",
        hidden = true,
        store = true,
        test = "true"
      },
      {
        name = "reagentQuality ",
        display = L["Reagent Quality"],
        store = true,
        test = "true",
        enable = true,
        conditionType = "number",
        hidden = true
      },
      {
        name = "reagentQualityTexture",
        display = L["Reagent Quality Texture"],
        store = true,
        test = "true",
        enable = true,
        hidden = true
      },
    },
    statesParameter = "one",
    hasItemID = true,
    automaticrequired = true,
    progressType = "static"
  },
  ["Stance/Form/Aura"] = {
    type = "unit",
    events = {
      ["events"] = {
        "UPDATE_SHAPESHIFT_FORM",
        "UPDATE_SHAPESHIFT_COOLDOWN"
      }
    },
    internal_events = { "WA_DELAYED_PLAYER_ENTERING_WORLD" },
    force_events = "WA_DELAYED_PLAYER_ENTERING_WORLD",
    name = L["Stance/Form/Aura"],
    init = function(trigger)
      local inverse = trigger.use_inverse;
      local ret = {[[
        local form = GetShapeshiftForm()
        -- Moonkin Form reports 31 to 35 depending on race; Dire Bear Form (8) counts as Bear Form.
        local formID = GetShapeshiftFormID and GetShapeshiftFormID() or nil
        if formID and formID >= 31 and formID <= 35 then formID = 31 end
        if formID == 8 then formID = 5 end
        -- No form (humanoid) is 0, matching the Humanoid choice.
        formID = formID or 0
        local active = false
      ]]}
      -- A form chosen by ID works on every character; the bar position is kept for older auras.
      if trigger.use_formID ~= nil and trigger.formID then
        local ids = {}
        if trigger.use_formID and trigger.formID.single then
          ids[1] = tonumber(trigger.formID.single)
        elseif trigger.use_formID == false then
          for id in pairs(trigger.formID.multi or {}) do ids[#ids + 1] = tonumber(id) end
        end
        local checks = {}
        for _, id in ipairs(ids) do checks[#checks + 1] = ("formID == %d"):format(id) end
        table.insert(ret, ("active = %s\n"):format(#checks > 0 and table.concat(checks, " or ") or "false"))
        if inverse then
          table.insert(ret, "active = not active\n")
        end
      elseif trigger.use_form and trigger.form and trigger.form.single then
        -- Single selection
        table.insert(ret, ([[
          local trigger_form = %d
          active = form == trigger_form
        ]]):format(trigger.form.single))
        if inverse then
          table.insert(ret, [[
            active = not active
          ]])
        end
      elseif trigger.use_form == false and trigger.form and trigger.form.multi then
        for index in pairs(trigger.form.multi) do
          table.insert(ret, ([[
            if not active then
              local index = %d
              active = form == index
            end
          ]]):format(index))
        end
        if inverse then
          table.insert(ret, [[
            active = not active
          ]])
        end
      elseif trigger.use_form == nil then
        table.insert(ret, [[
          active = true
        ]])
      end
      return table.concat(ret)
    end,
    statesParameter = "one",
    args = {
      {
        name = "note",
        type = "description",
        display = "",
        text = function()
          return L["Note: This trigger internally stores the shapeshift position, and thus is incompatible with learning stances on the fly, like e.g. the Gladiator Rune."]
        end,
        hidden = not (C_Seasons and C_Seasons.GetActiveSeason and C_Seasons.GetActiveSeason() == 2),
      },
      {
        name = "formID",
        display = L["Form"],
        desc = L["Works on every character, whether or not the form is learned."],
        type = "multiselect",
        values = "form_id_types",
        sorted = true,
        sortOrder = Private.form_id_order,
        test = "active",
        store = true,
        conditionType = "select"
      },
      {
        name = "form",
        display = L["Form (Bar Position)"],
        desc = L["The form's position on this character's stance bar. Prefer Form, which does not depend on learned forms."],
        type = "multiselect",
        values = "form_types",
        test = "active",
        store = true,
        conditionType = "select",
        -- Shown for older auras that use it, and while no Form is chosen.
        hidden = function(trigger) return trigger.use_form == nil and trigger.use_formID ~= nil end,
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
        enable = function(trigger) return type(trigger.use_form) == "boolean" or type(trigger.use_formID) == "boolean" end
      },
    },
    nameFunc = function(trigger)
      local _, class = UnitClass("player");
      local name
      if(class == trigger.class) then
        local form = GetShapeshiftForm();
        if form > 0 then
          local _, name = GetShapeshiftFormInfo(form);
        else
          name = "Humanoid";
        end
        return name;
      else
        local types = WeakAuras[class:lower().."_form_types"];
        if(types) then
          return types[GetShapeshiftForm()];
        end
      end
    end,
    iconFunc = function(trigger)
      local icon = "136116"
      local form = GetShapeshiftForm()
      if form and form > 0 then
        icon = GetShapeshiftFormInfo(form);
      end
      return icon or "136116"
    end,
    automaticrequired = true,
    progressType = "none"
  },
  ["Weapon Enchant"] = {
    type = "item",
    events = {},
    internal_events = {
      "TENCH_UPDATE",
    },
    force_events = "TENCH_UPDATE",
    name = L["Weapon Enchant / Fishing Lure"] or L["Weapon Enchant"],
    init = function(trigger)
      WeakAuras.TenchInit();

      local ret = [[
        local triggerWeaponType = %q
        local triggerName = %q
        local triggerStack = %s
        local triggerRemaining = %s
        local triggerShowOn = %q
        local triggerEnchantKind = %q
        local _, expirationTime, duration, name, icon, stacks, enchantID

        if triggerWeaponType == "main" then
          expirationTime, duration, name, shortenedName, icon, stacks, enchantID = WeakAuras.GetMHTenchInfo(triggerEnchantKind, triggerName)
        elseif triggerWeaponType == "off" then
          expirationTime, duration, name, shortenedName, icon, stacks, enchantID = WeakAuras.GetOHTenchInfo(triggerEnchantKind, triggerName)
        end

        local remaining = expirationTime and expirationTime - GetTime()

        local nameCheck = triggerName == "" or name and triggerName == name or shortenedName and triggerName == shortenedName or tonumber(triggerName) and enchantID and tonumber(triggerName) == enchantID
        local stackCheck = not triggerStack or stacks and stacks %s triggerStack
        local remainingCheck = not triggerRemaining or remaining and remaining %s triggerRemaining
        -- A zero-length entry is expired even if the API has not removed it yet.
        local found = remaining and remaining > 0 and nameCheck and stackCheck and remainingCheck

        if(triggerRemaining and remaining and remaining >= triggerRemaining and remaining > 0) then
          Private.ExecEnv.ScheduleScan(expirationTime - triggerRemaining, "TENCH_UPDATE");
        end

        if not found then
          expirationTime = nil
          duration = nil
          remaining = nil
        end
      ]];

      local showOnActive = trigger.showOn == 'showOnActive' or not trigger.showOn

      return ret:format(trigger.weapon or "main",
      trigger.use_enchant and trigger.enchant or "",
      trigger.showOn ~= "showOnMissing" and trigger.use_stacks and tonumber(trigger.stacks or 0) or "nil",
      showOnActive and trigger.use_remaining and tonumber(trigger.remaining or 0) or "nil",
      trigger.showOn or "showOnActive",
      trigger.enchantKind or "any",
      trigger.stacks_operator or "<",
      trigger.remaining_operator or "<")
    end,
    args = {
      {
        name = "weapon",
        display = L["Weapon"],
        type = "select",
        values = "weapon_types",
        test = "true",
        default = "main",
        required = true
      },
      {
        -- Forever allows an imbue and an oil/stone/poison on one weapon at once.
        name = "enchantKind",
        display = L["Enchant Type"],
        type = "select",
        values = "weapon_enchant_kinds",
        test = "true",
        default = "any",
        required = true
      },
      {
        name = "enchant",
        display = L["Weapon Enchant"],
        desc = L["Enchant Name or ID"],
        type = "string",
        test = "true"
      },
      {
        name = "enchantID",
        hidden = true,
        test = "true",
        display = L["Enchant ID"],
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
        noProgressSource = true
      },
      {
        name = "stacks",
        display = L["Charges"],
        desc = "Charges left on the enchant, such as poison charges. Also shown as %s in texts.",
        type = "number",
        conditionType = "number",
        test = "true",
        enable = function(trigger)
          return trigger.showOn ~= "showOnMissing"
        end,
        store = true
      },
      {
        -- The same number under its own name, so texts can use %charges as
        -- well as %s (which stays for the stacks slot every trigger has).
        name = "charges",
        display = L["Charges"],
        hidden = true,
        init = "stacks",
        test = "true",
        store = true,
        noProgressSource = true
      },
      {
        name = "duration",
        hidden = true,
        init = "duration",
        test = "true",
        store = true
      },
      {
        name = "expirationTime",
        init = "expirationTime",
        hidden = true,
        test = "true",
        store = true
      },
      {
        name = "progressType",
        hidden = true,
        init = "duration and 'timed'",
        test = "true",
        store = true
      },
      {
        name = "name",
        hidden = true,
        init = "name",
        test = "true",
        store = true
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "enchanted",
        display = L["Enchanted"],
        hidden = true,
        init = "found == true",
        test = "true",
        store = true,
        conditionType = "bool",
        conditionTest = function(state, needle)
          return state and state.show and state.enchanted == (needle == 1)
        end,
      },
      {
        name = "remaining",
        display = L["Remaining Time"],
        type = "number",
        test = "true",
        enable = function(trigger)
          return not trigger.showOn or trigger.showOn == "showOnActive"
        end
      },
      {
        name = "showOn",
        display = L["Show On"],
        type = "select",
        values = "weapon_enchant_types",
        test = 'true',
        default = "showOnActive",
        required = true
      },
      {
        hidden = true,
        test = "(triggerShowOn == 'showOnActive' and found) " ..
        "or (triggerShowOn == 'showOnMissing' and not found) "  ..
        "or (triggerShowOn == 'showAlways')"
      }
    },
    automaticrequired = true,
    progressType = "timed",
    statesParameter = "one"
  },
  ["Chat Message"] = {
    type = "event",
    events = function(trigger)
      if trigger.use_messageType and trigger.messageType and Private.chat_message_types[trigger.messageType] then
        local events = {trigger.messageType}
        if Private.chat_message_leader_event[trigger.messageType] then
          table.insert(events, Private.chat_message_leader_event[trigger.messageType])
        end
        if trigger.messageType == "CHAT_MSG_EMOTE" then
          table.insert(events, "CHAT_MSG_TEXT_EMOTE")
        end
        return { events = events }
      end
      return {
        ["events"] = {
          "CHAT_MSG_INSTANCE_CHAT",
          "CHAT_MSG_INSTANCE_CHAT_LEADER",
          "CHAT_MSG_BG_SYSTEM_ALLIANCE",
          "CHAT_MSG_BG_SYSTEM_HORDE",
          "CHAT_MSG_BG_SYSTEM_NEUTRAL",
          "CHAT_MSG_BN_WHISPER",
          "CHAT_MSG_CHANNEL",
          "CHAT_MSG_EMOTE",
          "CHAT_MSG_GUILD",
          "CHAT_MSG_MONSTER_EMOTE",
          "CHAT_MSG_MONSTER_PARTY",
          "CHAT_MSG_MONSTER_SAY",
          "CHAT_MSG_MONSTER_WHISPER",
          "CHAT_MSG_MONSTER_YELL",
          "CHAT_MSG_OFFICER",
          "CHAT_MSG_PARTY",
          "CHAT_MSG_PARTY_LEADER",
          "CHAT_MSG_RAID",
          "CHAT_MSG_RAID_LEADER",
          "CHAT_MSG_RAID_BOSS_EMOTE",
          "CHAT_MSG_RAID_BOSS_WHISPER",
          "CHAT_MSG_RAID_WARNING",
          "CHAT_MSG_SAY",
          "CHAT_MSG_WHISPER",
          "CHAT_MSG_YELL",
          "CHAT_MSG_SYSTEM",
          "CHAT_MSG_TEXT_EMOTE",
          "CHAT_MSG_LOOT",
          "CHAT_MSG_COMMUNITIES_CHANNEL"
        }
      }
    end,
    name = L["Chat Message"],
    init = function(trigger)
      local ret = [[
        if hasanysecretvalues(message, sourceName, destName, sourceGUID) then return false end
        if event == 'CHAT_MSG_PARTY_LEADER' or event == 'CHAT_MSG_INSTANCE_CHAT_LEADER' then
          event = event:sub(1, -8);
        end
        if (event == 'CHAT_MSG_TEXT_EMOTE') then
          event = 'CHAT_MSG_EMOTE';
        end
        local use_cloneId = %s;
      ]];
      return ret:format(trigger.use_cloneId and "true" or "false");
    end,
    statesParameter = "all",
    args = {
      {
        name = "messageType",
        display = L["Message Type"],
        type = "select",
        values = "chat_message_types",
        sorted = true,
        test = "event == %q",
      },
      {
        name = "message",
        display = L["Message"],
        init = "arg",
        type = "longstring",
        canBeCaseInsensitive = true,
        store = true,
        conditionType = "string",
      },
      {
        name = "sourceName",
        display = L["Source Name"],
        init = "arg",
        type = "string",
        store = true,
        conditionType = "string",
      },
      { -- language Name
      },
      { -- Channel Name
      },
      {
        name = "destName",
        display = L["Destination Name"],
        init = "arg",
        type = "string",
        store = true,
        conditionType = "string",
      },
      {
        -- flags
      },
      {
        -- zone Channel id
      },
      {
        -- channel index
      },
      {
        -- channel base name
      },
      {
        -- language id
      },
      {
        -- line id
      },
      {
        name = "sourceGUID",
        display = L["Source GUID"],
        init = "arg",
        store = true,
        hidden = true,
        test = "true",
        formatter = "guid",
        formatterArgs = { color = "class" }
      },
      {
        name = "cloneId",
        display = L["Clone per Event"],
        type = "toggle",
        test = "true",
        init = "use_cloneId and WeakAuras.GetUniqueCloneId() or ''",
        reloadOptions = true
      },
    },
    countEvents = true,
    delayEvents = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Spell Cast Succeeded"] = {
    type = "event",
    events = function(trigger)
      local result = {}
      local unit = trigger.unit
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_SUCCEEDED")
      return result
    end,
    name = L["Spell Cast Succeeded"],
    init = function()
      return "if issecretvalue(unit) or issecretvalue(spellId) or spellId == nil then return false end\n"
    end,
    statesParameter = "unit",
    args = {
      {
        name = "unit",
        init = "arg",
        display = L["Caster Unit"],
        type = "unit",
        test = "true",
        -- Player and pet only: other units' cast events are secret here.
        values = "actual_unit_types_own_cast",
        default = "player",
        store = true,
        conditionType = "select",
        conditionTest = function(state, needle, op)
          return state and state.show and (Private.ExecEnv.UnitIsUnit(needle, state.unit or '') == (op == "=="))
        end
      },
      {
      },
      { -- castGUID
      },
      {
        name = "spellNames",
        display = L["Name(s)"],
        type = "spell",
        multiEntry = {
          operator = "preamble",
          preambleAdd = "spellChecker:AddName(%q)"
        },
        preamble = "local spellChecker = Private.ExecEnv.CreateSpellChecker()",
        preambleGroup = "spell",
        test = "spellChecker:Check(spellId)",
        noValidation = true,
      },
      {
        name = "spellId",
        display = L["Exact Spell ID(s)"],
        type = "spell",
        init = "arg",
        store = true,
        multiEntry = {
          operator = "preamble",
          preambleAdd = "spellChecker:AddExact(%q)"
        },
        preamble = "local spellChecker = Private.ExecEnv.CreateSpellChecker()",
        preambleGroup = "spell",
        test = "spellChecker:Check(spellId)",
        conditionType = "number",
        noProgressSource = true
      },
      {
        name = "icon",
        hidden = true,
        init = "Private.ExecEnv.GetSpellIcon(spellId or 0)",
        store = true,
        test = "true"
      },
      {
        name = "name",
        hidden = true,
        init = "Private.ExecEnv.GetSpellName(spellId or 0)",
        store = true,
        test = "true"
      },
    },
    countEvents = true,
    delayEvents = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Ready Check"] = {
    type = "event",
    events = {
      ["events"] = {"READY_CHECK"}
    },
    name = L["Ready Check"],
    args = {},
    statesParameter = "one",
    delayEvents = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Combat Events"] = {
    type = "event",
    events = {
      ["events"] = {
        "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED"
      }
    },
    name = L["Entering/Leaving Combat"],
    args = {
      {
        name = "eventtype",
        required = true,
        display = L["Type"],
        type = "select",
        values = "combat_event_type",
        test = "event == %q"
      }
    },
    statesParameter = "one",
    countEvents = true,
    delayEvents = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Encounter Events"] = {
    type = "event",
    events = {
      ["events"] = {
        "ENCOUNTER_START",
        "ENCOUNTER_END"
      }
    },
    name = L["Entering/Leaving Encounter"],
    args = {
      {
        name = "eventtype",
        required = true,
        display = L["Type"],
        type = "select",
        values = "encounter_event_type",
        test = "event == %q",
        reloadOptions = true
      },
      {
        name = "encounterId",
        display = L["Id"],
        type = "string",
        validate = WeakAuras.ValidateNumeric,
        conditionType = "number",
        store = true,
        init = "arg"
      },
      {
        name = "encounterName",
        display = L["Name"],
        type = "string",
        conditionType = "string",
        store = true,
        init = "arg"
      },
      {
        name = "difficulty",
        display = L["Difficulty"],
        type = "select",
        values = "difficulty_types",
        test = "%q == WeakAuras.InstanceDifficulty()",
        conditionType = "select",
        conditionTest = function(state, needle)
          return WeakAuras.InstanceDifficulty() == needle
        end,
        store = true,
        init = "arg"
      },
      {},
      {
        name = "success",
        display = L["Success"],
        type = "toggle",
        conditionType = "bool",
        enable = function(trigger)
          return trigger.eventtype == "ENCOUNTER_END"
        end,
        store = true,
        test = "success == 1",
        conditionTest = function(state, needle)
          return state and (state.success == needle)
        end,
        init = "arg"
      }
    },
    statesParameter = "one",
    countEvents = true,
    delayEvents = true,
    timedrequired = true,
    progressType = "timed"
  },
  ["Item Equipped"] = {
    type = "item",
    events = {
      ["events"] = {
        "PLAYER_EQUIPMENT_CHANGED",
      },
      ["unit_events"] = {
        ["player"] = {"UNIT_INVENTORY_CHANGED"}
      }
    },
    internal_events = { "WA_DELAYED_PLAYER_ENTERING_WORLD", },
    force_events = "UNIT_INVENTORY_CHANGED",
    name = L["Item Equipped"],
    init = function(trigger)
      local itemName = type(trigger.itemName) == "number" and trigger.itemName or string.format("%q", trigger.itemName or "0")

      local ret = [[
        local inverse = %s
        local triggerItemName = %s
        local itemId, _, _, _, icon = C_Item.GetItemInfoInstant(triggerItemName)
        local itemSlot = %s
      ]]

      ret = ret ..[[
        local itemName = triggerItemName
        local equipped = WeakAuras.CheckForItemEquipped(triggerItemName, itemSlot)
      ]]

      return ret:format(trigger.use_inverse and "true" or "false", itemName, trigger.use_itemSlot and trigger.itemSlot or "nil");
    end,
    GetNameAndIcon = function(trigger)
      local name = C_Item.GetItemInfo(trigger.itemName or 0)
      local _, _, _, _, icon = C_Item.GetItemInfoInstant(trigger.itemName or 0)
      return name, icon
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemName",
        display = L["Item"],
        type = "item",
        required = true,
        test = "true",
        only_exact = true
      },
      {
        name = "itemId",
        display = WeakAuras.newFeatureString .. L["ItemId"],
        hidden = true,
        init = "itemId",
        test = "true",
        store = true,
        conditionType = "number",
        operator_types = "only_equal",
      },
      {
        name = "itemSlot",
        display = WeakAuras.newFeatureString .. L["Item Slot"],
        type = "select",
        values = "item_slot_types",
        test = "true",
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "itemName",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        hidden = true,
        test = "(inverse and not equipped) or (equipped and not inverse)"
      }
    },
    hasItemID = true,
    automaticrequired = true,
    progressType = "none"
  },
  ["Item Type Equipped"] = {
    type = "item",
    events = {
      ["events"] = {
        "PLAYER_EQUIPMENT_CHANGED",
      },
      ["unit_events"] = {
        ["player"] = {"UNIT_INVENTORY_CHANGED"}
      }
    },
    init = function(trigger)
      local ret
      if trigger.use_itemSlot then
        local itemSlot = trigger.itemSlot and tonumber(trigger.itemSlot)
        if itemSlot then
          ret = string.format("local itemSlot = %s\n", trigger.itemSlot)
        else
          ret = "local itemSlot = nil\n"
        end
      else
        ret = "local itemSlot = nil\n"
      end
      return ret
    end,
    internal_events = { "WA_DELAYED_PLAYER_ENTERING_WORLD", },
    force_events = "UNIT_INVENTORY_CHANGED",
    name = L["Item Type Equipped"],
    args = {
      {
          name = "itemSlot",
          required = false,
          display = L["Equipment Slot"],
          type = "select",
          values = "item_slot_types",
          test = "true"
      },
      {
        name = "itemTypeName",
        display = L["Item Type"],
        type = "multiselect",
        values = "item_weapon_types",
        required = true,
        test = "Private.ExecEnv.IsEquippedItemType(%s, itemSlot)",
        multiNoSingle = true
      },
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Item Bonus Id Equipped"] = {
    type = "item",
    events = {
      ["events"] = {
        "PLAYER_EQUIPMENT_CHANGED",
      },
      ["unit_events"] = {
        ["player"] = {"UNIT_INVENTORY_CHANGED"}
      }
    },
    internal_events = { "WA_DELAYED_PLAYER_ENTERING_WORLD", },
    force_events = "UNIT_INVENTORY_CHANGED",
    name = L["Item Bonus Id Equipped"],
    statesParameter = "one",
    init = function(trigger)
      local ret = [=[
        local item = %q
        local inverse = %s
        local useItemSlot, slotSelected = %s, %d

        local itemBonusId, itemId, itemName, icon, itemSlot, itemSlotString = WeakAuras.GetBonusIdInfo(item, useItemSlot and slotSelected)
        local itemBonusId = tonumber(itemBonusId)

        local slotValidation = (useItemSlot and itemSlot == slotSelected) or (not useItemSlot)
      ]=]
      return ret:format(trigger.itemBonusId or "", trigger.use_inverse and "true" or "false",
                        trigger.use_itemSlot and "true" or "false", trigger.itemSlot)
    end,
    args = {
      {
        name = "itemBonusId",
        display = L["Item Bonus Id"],
        type = "string",
        store = "true",
        test = "true",
        required = true,
        desc = L["Supports multiple entries, separated by commas"],
        conditionType = "number",
        noProgressSource = true
      },
      {
        name = "name",
        display = L["Item Name"],
        hidden = "true",
        init = "itemName",
        store = "true",
        test = "true",
      },
      {
        name = "icon",
        hidden = "true",
        init = "icon",
        store = "true",
        test = "true",
      },
      {
        name = "itemId",
        display = L["Item Id"],
        hidden = "true",
        store = "true",
        test = "true",
        conditionType = "number",
        operator_types = "only_equal",
        noProgressSource = true
      },
      {
        name = "itemSlot",
        display = L["Item Slot"],
        type = "select",
        store = "true",
        conditionType = "select",
        values = "item_slot_types",
        test = "true",
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
      },
      {
        name = "itemSlotString",
        display = L["Item Slot String"],
        hidden = "true",
        store = "true",
        test = "true",
      },
      {
        hidden = true,
        test = "not inverse == (itemBonusId and slotValidation or false)",
      }
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Item Set"] = {
    type = "item",
    events = {
      ["events"] = {"PLAYER_EQUIPMENT_CHANGED"}
    },
    internal_events = {"WA_DELAYED_PLAYER_ENTERING_WORLD",
                       "WA_DELAYED_SET_INFORMATION"},
    force_events = "PLAYER_EQUIPMENT_CHANGED",
    name = L["Item Set Equipped"],
    automaticrequired = true,
    init = function(trigger)
      local ret = [[
        local setid = %s
        local value, total, name = WeakAuras.GetNumSetItemsEquipped(setid)
      ]]
      return string.format(ret, trigger.itemSetId and tonumber(trigger.itemSetId) or "0");
    end,
    GetNameAndIcon = function(trigger)
      local name = select(3, WeakAuras.GetNumSetItemsEquipped(trigger.itemSetId and tonumber(trigger.itemSetId) or 0))
      return name, nil
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemSetId",
        display = L["Item Set Id"],
        type = "string",
        test = "true",
        store = "true",
        required = true,
        validate = WeakAuras.ValidateNumeric,
        desc = function()
          do
            return L["Set IDs can be found on websites such as wowhead.com/item-sets"]
          end
        end
      },
      {
        name = "equipped",
        display = L["Equipped"],
        type = "number",
        init = "value",
        store = true,
        required = true,
        conditionType = "number"
      },
      {
        name = "progressType",
        hidden = true,
        init = "'static'",
        store = true,
        test = "true"
      },
      {
        name = "value",
        hidden = true,
        init = "value",
        store = true,
        test = "true"
      },
      {
        name = "total",
        hidden = true,
        init = "total",
        store = true,
        test = "true"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        store = true,
        test = "true",
        conditionType = "string"
      },
    },
    progressType = "static"
  },
  ["Equipment Set"] = {
    type = "item",
    events = {
      ["events"] = {
        "PLAYER_EQUIPMENT_CHANGED",
        "WEAR_EQUIPMENT_SET",
        "EQUIPMENT_SETS_CHANGED",
        "EQUIPMENT_SWAP_FINISHED",
      }
    },
    internal_events = {"WA_DELAYED_PLAYER_ENTERING_WORLD"},
    force_events = "PLAYER_EQUIPMENT_CHANGED",
    name = L["Equipment Set Equipped"],
    init = function(trigger)
      trigger.itemSetName = trigger.itemSetName or "";
      local itemSetName = type(trigger.itemSetName) == "string" and ("[=[" .. trigger.itemSetName .. "]=]") or "nil";

      local ret = [[
        local useItemSetName = %s;
        local triggerItemSetName = %s;
        local inverse = %s;
        local partial = %s;

        local itemSetName, icon, numEquipped, numItems = WeakAuras.GetEquipmentSetInfo(useItemSetName and triggerItemSetName or nil, partial);
      ]];

      return ret:format(trigger.use_itemSetName and "true" or "false", itemSetName, trigger.use_inverse and "true" or "false", trigger.use_partial and "true" or "false");
    end,
    GetNameAndIcon = function(trigger)
      local name, icon = WeakAuras.GetEquipmentSetInfo(trigger.use_itemSetName and trigger.itemSetName or nil, true)
      return name, icon
    end,
    statesParameter = "one",
    args = {
      {
        name = "itemSetName",
        display = L["Equipment Set"],
        type = "string",
        test = "true",
        store = true,
        conditionType = "string",
        init = "itemSetName"
      },
      {
        name = "partial",
        display = L["Allow partial matches"],
        type = "toggle",
        test = "true"
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true"
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "value",
        init = "numEquipped",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "total",
        init = "numItems",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "progressType",
        init = "'static'",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        hidden = true,
        test = "(inverse and itemSetName == nil) or (not inverse and itemSetName)"
      }
    },
    automaticrequired = true,
    progressType = "static"
  },
  ["Threat Situation"] = {
    type = "unit",
    events = function(trigger)
      local unit = trigger.unit
      local result = {}
      if unit and unit ~= "none" then
        AddUnitEventForEvents(result, unit, "UNIT_THREAT_LIST_UPDATE")
      else
        AddUnitEventForEvents(result, "player", "UNIT_THREAT_SITUATION_UPDATE")
      end
      return result
    end,
    internal_events = function(trigger)
      local unit = trigger.unit
      local result = {}
      if unit and unit ~= "none" then
        AddUnitChangeInternalEvents(unit, result)
      end
      return result
    end,
    loadFunc = function(trigger)
      local unit = trigger.unit
      if unit and unit ~= "none" then
        AddWatchedUnits(unit)
      end
    end,
    force_events = unitHelperFunctions.UnitChangedForceEvents,
    name = L["Threat Situation"],
    init = function(trigger)
      trigger.unit = trigger.unit or "target";
      local ret = [[
        if issecretvalue(unit) or type(unit) ~= "string" then return false end
        unit = string.lower(unit)
        if unit:match("^nameplate") then return false end
        local name = Private.ExecEnv.UnitName(unit)
        if issecretvalue(name) then return false end
        local ok = true
        local aggro, status, threatpct, rawthreatpct, threatvalue, threattotal
        if unit ~= "none" then
          aggro, status, threatpct, rawthreatpct, threatvalue = WeakAuras.UnitDetailedThreatSituation('player', unit)
          if hasanysecretvalues(aggro, status, threatpct, rawthreatpct, threatvalue) then return false end
          if type(threatpct) ~= "number" or type(threatvalue) ~= "number" then return false end
          threattotal = threatvalue * 100 / (threatpct ~= 0 and threatpct or 1)
        else
          status = UnitThreatSituation('player')
          if issecretvalue(status) then return false end
          aggro = status == 2 or status == 3
          threatpct, rawthreatpct, threatvalue, threattotal = 100, 100, 0, 100
        end
      ]];
      return ret .. unitHelperFunctions.SpecificUnitCheck(trigger);
    end,
    progressType = "static",
    statesParameter = "unit",
    args = {
      {
        name = "unit",
        display = L["Unit"],
        required = true,
        type = "unit",
        init = "arg",
        values = "threat_unit_types",
        test = "true",
        store = true,
        default = "target"
      },
      {
        name = "status",
        display = L["Status"],
        type = "select",
        values = "unit_threat_situation_types",
        store = true,
        conditionType = "select"
      },
      {
        name = "aggro",
        display = L["Aggro"],
        type = "tristate",
        store = true,
        conditionType = "bool",
      },
      {
        name = "threatpct",
        display = L["Threat Percent"],
        desc = L["Your threat on the mob as a percentage of the amount required to pull aggro. Will pull aggro at 100."],
        type = "number",
        store = true,
        conditionType = "number",
        enable = function(trigger) return trigger.unit ~= "none" end,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "rawthreatpct",
        display = L["Raw Threat Percent"],
        desc = L["Your threat as a percentage of the tank's current threat."],
        type = "number",
        store = true,
        conditionType = "number",
        enable = function(trigger) return trigger.unit ~= "none" end,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "threatvalue",
        display = L["Threat Value"],
        desc = L["Your total threat on the mob."],
        type = "number",
        store = true,
        conditionType = "number",
        enable = function(trigger) return trigger.unit ~= "none" end,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        type = "header",
        name = "unitCharacteristicsHeader",
        display = L["Unit Characteristics"],
      },
      {
        name = "name",
        display = L["Unit Name"],
        type = "string",
        store = true,
        multiline = true,
        preamble = "local nameChecker = Private.ExecEnv.ParseStringCheck(%q)",
        test = "nameChecker:Check(name)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseStringCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.name)
        end,
        operator_types = "none",
        desc = L["Supports multiple entries, separated by commas. Prefix with '-' for negation."]
      },
      {
        name = "npcId",
        display = L["Npc ID"],
        type = "string",
        multiline = true,
        store = true,
        init = "not issecretvalue(UnitGUID(unit)) and select(6, strsplit('-', UnitGUID(unit) or ''))",
        conditionType = "string",
        preamble = "local npcIdChecker = Private.ExecEnv.ParseStringCheck(%q)",
        test = "npcIdChecker:Check(npcId)",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseStringCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.npcId)
        end,
        operator_types = "none",
        desc = L["Supports multiple entries, separated by commas. Prefix with '-' for negation."]
      },
      {
        name = "value",
        hidden = true,
        init = "threatvalue",
        store = true,
        test = "true"
      },
      {
        name = "total",
        hidden = true,
        init = "threattotal",
        store = true,
        test = "true"
      },
      {
        name = "progressType",
        hidden = true,
        init = "'static'",
        store = true,
        test = "true"
      },
      {
        hidden = true,
        test = "status ~= nil and ok"
      },
      {
        hidden = true,
        test = "WeakAuras.UnitExistsFixed(unit, false) and specificUnitCheck"
      }
    },
    automaticrequired = true
  },
  ["Crowd Controlled"] = {
    type = "unit",
    events = {
      ["events"] = {
        "LOSS_OF_CONTROL_UPDATE",
        "PLAYER_ENTERING_WORLD"
      }
    },
    force_events = "LOSS_OF_CONTROL_UPDATE",
    name = L["Crowd Controlled"],
    statesParameter = "one",
    init = function(trigger)
      local ret = [=[
          local show = false
          local use_controlType = %s
          local controlType = %s
          local inverse = %s
          local use_interruptSchool = %s
          local interruptSchool = tonumber(%q)
          local duration, expirationTime, spellName, icon, spellName, spellId, locType, lockoutSchool, name, _
          for i = 1, C_LossOfControl.GetActiveLossOfControlDataCount() do
            local data = C_LossOfControl.GetActiveLossOfControlData(i)
            if data then
              if (not use_controlType)
              or (data.locType == controlType and (controlType ~= "SCHOOL_INTERRUPT" or ((not use_interruptSchool) or bit.band(data.lockoutSchool, interruptSchool) > 0)))
              then
                spellId = data.spellID
                spellName, _, icon = Private.ExecEnv.GetSpellInfo(data.spellID)
                duration = data.duration
                if data.startTime and data.duration then
                  expirationTime = data.startTime + data.duration
                end
                locType = data.locType
                lockoutSchool = data.lockoutSchool
                name = data.displayText
                show = true
                break
              end
            end
          end
      ]=]
      ret = ret:format(
        trigger.use_controlType and "true" or "false",
        type(trigger.controlType) == "string" and "[["..trigger.controlType.."]]" or [["STUN"]],
        trigger.use_inverse and "true" or "false",
        trigger.use_interruptSchool and "true" or "false",
        trigger.interruptSchool or 0
      )
      return ret
    end,
    args = {
      {
        name = "controlType",
        display = L["Specific Type"],
        type = "select",
        values = "loss_of_control_types",
        conditionType = "select",
        test = "true",
        default = "STUN",
        init = "locType",
        store = true,
      },
      {
        name = "interruptSchool",
        display = L["Interrupt School"],
        type = "select",
        values = "main_spell_schools",
        conditionType = "select",
        default = 1,
        test = "true",
        enable = function(trigger) return trigger.controlType == "SCHOOL_INTERRUPT" end,
        init = "lockoutSchool",
        store = true,
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        conditionType = "string",
        store = true,
        test = "true",
      },
      {
        name = "spellName",
        display = L["Spell Name"],
        hidden = true,
        conditionType = "string",
        store = true,
        test = "true",
      },
      {
        name = "spellId",
        display = L["Spell Id"],
        hidden = true,
        conditionType = "number",
        operator_types = "only_equal",
        store = true,
        test = "true",
        noProgressSource = true
      },
      {
        name = "lockoutSchool",
        display = L["Interrupted School Text"],
        hidden = true,
        init = "lockoutSchool and lockoutSchool > 0 and GetSchoolString(lockoutSchool) or nil",
        store = true,
        test = "true",
      },
      {
        name = "icon",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "duration",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "expirationTime",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "progressType",
        hidden = true,
        init = "'timed'",
        store = true,
        test = "true",
      },
      {
        hidden = true,
        test = "inverse ~= show",
      },
    },
    automaticrequired = true,
    progressType = "timed"
  },
  ["Cast"] = {
    type = "unit",
    events = function(trigger)
      local result = {}
      local unit = trigger.unit
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_START")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_DELAYED")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_STOP")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_CHANNEL_START")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_CHANNEL_UPDATE")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_CHANNEL_STOP")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_INTERRUPTIBLE")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
      AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_INTERRUPTED")
      AddUnitEventForEvents(result, unit, "UNIT_NAME_UPDATE")
      do
        AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_EMPOWER_START_FAKE")
        AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_EMPOWER_UPDATE_FAKE")
        AddUnitEventForEvents(result, unit, "UNIT_SPELLCAST_EMPOWER_STOP_FAKE")
      end
      AddUnitEventForEvents(result, unit, "UNIT_TARGET")
      return result
    end,
    internal_events = function(trigger)
      local unit = trigger.unit
      local result = {}
      if unit == "nameplate" and trigger.use_onUpdateUnitTarget then
        tinsert(result, "WA_UNIT_TARGET_NAME_PLATE")
      end
      AddRemainingCastInternalEvents(unit, result)
      local includePets = trigger.use_includePets == true and trigger.includePets or nil
      AddUnitChangeInternalEvents(unit, result, includePets)
      if includePets ~= "PetsOnly" then
        AddUnitRoleChangeInternalEvents(unit, result)
      end
      return result
    end,
    loadFunc = function(trigger)
      if trigger.use_showLatency and trigger.unit == "player" then
        WeakAuras.WatchForCastLatency()
      end
      if trigger.unit == "nameplate" and trigger.use_onUpdateUnitTarget then
        WeakAuras.WatchForNameplateTargetChange()
      end
      local includePets = trigger.use_includePets == true and trigger.includePets or nil
      AddWatchedUnits(trigger.unit, includePets)
    end,
    force_events = unitHelperFunctions.UnitChangedForceEventsWithPets,
    progressType = "timed",
    name = L["Cast"],
    init = function(trigger)
      trigger.unit = trigger.unit or "player";
      local ret = [=[
        unit = string.lower(unit)
        local destUnit = unit .. '-target'
        local sourceName, sourceRealm = WeakAuras.UnitNameWithRealm(unit)
        local destName, destRealm = WeakAuras.UnitNameWithRealm(destUnit)
        destName = destName or ""
        destRealm = destRealm or ""
        local smart = %s
        local remainingCheck = %s
        local inverseTrigger = %s
        local showChargedDuration = %s
        local empowered = false
        local stage = 0
        local stagesData = {}

        local show, expirationTime, castType, spell, icon, startTime, endTime, interruptible, spellId, remaining, _, stageTotal
        local durationObject, secretCast

        spell, _, icon, startTime, endTime, _, _, interruptible, spellId = WeakAuras.UnitCastingInfo(unit)
        if spell then
          castType = "cast"
        else
          spell, _, icon, startTime, endTime, _, interruptible, spellId, _, stageTotal = WeakAuras.UnitChannelInfo(unit)
          if spell then
            castType = "channel"
            if not hasanysecretvalues(startTime, endTime, stageTotal) and stageTotal and stageTotal > 0 then
              empowered = true

              local lastFinish = 0
              for i = 1, stageTotal do
                stagesData[i] = {
                  start = lastFinish,
                  finish = lastFinish + GetUnitEmpowerStageDuration(unit, i - 1) / 1000
                }
                lastFinish = stagesData[i].finish
                if startTime / 1000 + lastFinish <= GetTime() then
                  stage = i
                end
                if Round(startTime/1000) == Round(GetTime()) then
                  Private.ExecEnv.ScheduleCastCheck(startTime / 1000 + lastFinish, unit)
                end
              end
            end
          end
        end
        secretCast = hasanysecretvalues(spell, startTime, endTime, stageTotal)
        if secretCast then
          durationObject = castType == "cast" and UnitCastingDuration(unit) or UnitChannelDuration(unit)
          stageTotal = nil
        end
        if not secretCast and empowered and showChargedDuration then
          endTime = endTime + GetUnitEmpowerHoldAtMaxTime(unit)
        end
        local notInterruptible = interruptible
        if issecretvalue(interruptible) then interruptible = nil else interruptible = not interruptible end
        local important
        if type(spellId) == "number" and C_Spell.IsSpellImportant then
          important = C_Spell.IsSpellImportant(spellId)
        end
        if not secretCast then
          expirationTime = endTime and endTime > 0 and (endTime / 1000) or 0
          remaining = expirationTime - GetTime()
        end

        if remainingCheck and remaining and remaining >= remainingCheck and remaining > 0 then
          Private.ExecEnv.ScheduleCastCheck(expirationTime - remainingCheck, unit)
        end
      ]=];
      ret = ret:format(trigger.unit == "group" and "true" or "false",
                        trigger.use_remaining and tonumber(trigger.remaining or 0) or "nil",
                        trigger.use_inverse and "true" or "false",
                        trigger.use_showChargedDuration and "true" or "false"
                      );

      if trigger.use_interruptible ~= nil then
        ret = ret .. "if interruptible == nil then return false end\n"
      end
      if trigger.use_important ~= nil then
        ret = ret .. "if issecretvalue(important) then return false end\nimportant = important == true\n"
      end
      ret = ret .. unitHelperFunctions.SpecificUnitCheck(trigger)

      return ret
    end,
    statesParameter = "unit",
    args = {
      {
        name = "castStatus", type = "description", display = "",
        text = function(trigger) return Private.CastCombatStatus(trigger) end,
      },
      { name = "durationObject", hidden = true, init = "durationObject", store = true, test = "true" },
      {
        name = "unit",
        required = true,
        display = L["Unit"],
        type = "unit",
        init = "arg",
        values = function(trigger)
          if trigger.use_inverse then
            return Private.actual_unit_types_with_specific
          else
            return Private.actual_unit_types_cast
          end
        end,
        desc = Private.actual_unit_types_cast_tooltip,
        test = "true",
        store = true
      },
      {
        name = "spellNames",
        display = L["Name(s)"],
        type = "spell",
        enable = function(trigger) return not trigger.use_inverse end,
        preambleGroup = "spell",
        preamble = "local spellChecker = Private.ExecEnv.CreateSpellChecker()",
        multiEntry = {
          operator = "preamble",
          preambleAdd = "spellChecker:AddName(%q)"
        },
        test = "spellChecker:Check(spellId)",
        noValidation = true,
      },
      {
        name = "spellIds",
        display = L["Exact Spell ID(s)"],
        type = "spell",
        enable = function(trigger) return not trigger.use_inverse end,
        preambleGroup = "spell",
        preamble = "local spellChecker = Private.ExecEnv.CreateSpellChecker()",
        multiEntry = {
          operator = "preamble",
          preambleAdd = "spellChecker:AddExact(%q)"
        },
        test = "spellChecker:Check(spellId)",
      },
      {
        name = "spellId",
        display = L["Spell ID"],
        conditionType = "number",
        store = true,
        test = "true",
        hidden = true,
        noProgressSource = true
      },
      {
        name = "spell",
        display = L["Spellname"],
        type = "string",
        conditionType = "string",
        store = true,
        test = "true",
        hidden = true
      },
      {
        name = "castType",
        display = L["Cast Type"],
        type = "select",
        values = "cast_types",
        enable = function(trigger) return not trigger.use_inverse end,
        store = true,
        conditionType = "select"
      },
      {
        name = "interruptible",
        display = L["Interruptible"],
        type = "tristate",
        enable = function(trigger) return not trigger.use_inverse end,
        store = true,
        conditionType = "bool",
      },
      {
        name = "important",
        display = L["Important"],
        desc = L["Casts Blizzard marks as important. In combat, use a (Boolean) condition; this filter hides hidden casts."],
        type = "tristate",
        enable = function(trigger) return not trigger.use_inverse end,
        store = true,
        conditionType = "bool",
      },
      {
        name = "notInterruptible",
        display = L["Not Interruptible"],
        hidden = true,
        init = "notInterruptible",
        enable = function(trigger) return not trigger.use_inverse end,
        test = "true",
        store = true,
        conditionType = "bool",
      },

      {
        name = "remaining",
        display = L["Remaining Time"],
        type = "number",
        enable = function(trigger) return not trigger.use_inverse end,
      },
      {
        type = "header",
        name = "empoweredHeader",
        display = L["Empowered Cast"],
        enable = function(trigger) return not trigger.use_inverse end or false,
        hidden = false
      },
      {
        name = "empowered",
        display = L["Empowered"],
        type = "tristate",
        enable = function(trigger) return not trigger.use_inverse end or false,
        store = true,
        conditionType = "bool",
        hidden = false
      },
      {
        name = "showChargedDuration",
        display = L["Show charged duration for empowered casts"],
        type = "toggle",
        enable = function(trigger) return not trigger.use_inverse end or false,
        hidden = false,
        reloadOptions = true,
      },
      {
        name = "stage",
        display = L["Current Stage"],
        type = "number",
        enable = function(trigger) return not trigger.use_inverse end or false,
        store = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "stageTotal",
        display = L["Total Stages"],
        type = "number",
        enable = function(trigger) return not trigger.use_inverse end or false,
        store = true,
        conditionType = "number",
        hidden = false
      },
      {
        name = "charged",
        display = L["Empowered Cast Fully Charged"],
        hidden = true,
        init = "stage == stageTotal",
        test = "true",
        enable = function(trigger) return not trigger.use_inverse end or false,
        store = true,
        type = "toggle",
        conditionType = "bool",
      },
      {
        name = "name",
        hidden = true,
        init = "spell",
        test = "true",
        store = true
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        name = "duration",
        hidden = true,
        init = "not secretCast and endTime and startTime and (endTime - startTime)/1000 or nil",
        test = "true",
        store = true
      },
      {
        name = "expirationTime",
        init = "expirationTime",
        hidden = true,
        test = "true",
        store = true
      },
      {
        name = "progressType",
        hidden = true,
        init = "durationObject and 'durationObject' or 'timed'",
        test = "true",
        store = true
      },
      {
        name = "inverse",
        hidden = true,
        init = "castType == 'cast'",
        test = "true",
        store = true
      },
      {
        name = "autoHide",
        hidden = true,
        init = "not secretCast and not empowered",
        test = "true",
        store = true,
        enable = function(trigger)
          return not trigger.use_inverse
        end
      },
      {
        type = "header",
        name = "unitCharacteristicsHeader",
        display = L["Unit Characteristics"],
      },
      {
        name = "npcId",
        display = L["Npc ID"],
        type = "string",
        multiline = true,
        store = true,
        init = "not issecretvalue(UnitGUID(unit)) and select(6, strsplit('-', UnitGUID(unit) or ''))",
        conditionType = "string",
        preamble = "local npcIdChecker = Private.ExecEnv.ParseStringCheck(%q)",
        test = "npcIdChecker:Check(npcId)",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseStringCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.npcId)
        end,
        operator_types = "none",
        desc = L["Supports multiple entries, separated by commas. Prefix with '-' for negation."],
        enable = function(trigger)
          return not trigger.use_inverse
        end,
      },
      {
        name = "class",
        display = L["Class"],
        type = "select",
        init = "select(2, UnitClass(unit))",
        values = "class_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return not trigger.use_inverse
        end
      },
      {
        name = "role",
        display = L["Assigned Role"],
        type = "select",
        init = "UnitGroupRolesAssigned(unit)",
        values = "role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
                 and not trigger.use_inverse
        end
      },
      {
        name = "raid_role",
        display = L["Raid Role"],
        type = "select",
        init = "WeakAuras.UnitRaidRole(unit)",
        values = "raid_role_types",
        store = true,
        conditionType = "select",
        enable = function(trigger)
          return false
                 and not trigger.use_inverse
        end
      },
      {
        name = "nameplateType",
        display = L["Hostility"],
        type = "select",
        init = "WeakAuras.GetPlayerReaction(unit)",
        values = "hostility_types",
        store = true,
        conditionType = "select",
      },
      {
        name = "sourceUnit",
        init = "unit",
        display = L["Caster"],
        type = "unit",
        values = "actual_unit_types_with_specific",
        conditionType = "unit",
        conditionTest = function(state, unit, op)
          return state and state.show and state.unit and (Private.ExecEnv.UnitIsUnit(state.sourceUnit, unit) == (op == "=="))
        end,
        store = true,
        hidden = true,
        enable = function(trigger) return not trigger.use_inverse end,
        test = "true"
      },
      {
        name = "sourceName",
        display = L["Caster Name"],
        type = "string",
        store = true,
        hidden = true,
        test = "true",
        enable = function(trigger) return not trigger.use_inverse end,
      },
      {
        name = "sourceRealm",
        display = L["Caster Realm"],
        type = "string",
        store = true,
        hidden = true,
        test = "true",
        enable = function(trigger) return not trigger.use_inverse end,
      },
      {
        name = "sourceNameRealm",
        display = L["Source Unit Name/Realm"],
        type = "string",
        multiline = true,
        preamble = "local sourceNameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
        test = "sourceNameRealmChecker:Check(sourceName, sourceRealm)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseNameCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.sourceName, state.sourceRealm)
        end,
        operator_types = "none",
        enable = function(trigger) return not trigger.use_inverse end,
        desc = constants.nameRealmFilterDesc,
      },
      {
        name = "destUnit",
        display = L["Caster's Target"],
        type = "unit",
        values = "actual_unit_types_with_specific",
        conditionType = "unit",
        conditionTest = function(state, unit, op)
          return state and state.show and state.destUnit and (Private.ExecEnv.UnitIsUnit(state.destUnit, unit) == (op == "=="))
        end,
        store = true,
        enable = function(trigger) return not trigger.use_inverse end,
        test = "Private.ExecEnv.UnitIsUnit(destUnit, [[%s]])"
      },
      {
        name = "destName",
        display = L["Name of Caster's Target"],
        type = "string",
        store = true,
        hidden = true,
        test = "true",
        enable = function(trigger) return not trigger.use_inverse end,
      },
      {
        name = "destRealm",
        display = L["Realm of Caster's Target"],
        type = "string",
        store = true,
        hidden = true,
        test = "true",
        enable = function(trigger) return not trigger.use_inverse end,
      },
      {
        name = "destNameRealm",
        display = L["Name/Realm of Caster's Target"],
        type = "string",
        multiline = true,
        preamble = "local destNameRealmChecker = Private.ExecEnv.ParseNameCheck(%q)",
        test = "destNameRealmChecker:Check(destName, destRealm)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseNameCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.destName, state.destRealm)
        end,
        operator_types = "none",
        enable = function(trigger) return not trigger.use_inverse end,
        desc = constants.nameRealmFilterDesc,
      },
      {
        type = "header",
        name = "miscellaneousHeader",
        display = L["Miscellaneous"],
      },
      {
        name = "showLatency",
        display = L["Overlay Latency"],
        type = "toggle",
        test = "true",
        enable = function(trigger)
          return trigger.unit == "player" and not trigger.use_inverse
        end,
        reloadOptions = true
      },
      {
        name = "includePets",
        display = L["Include Pets"],
        type = "select",
        values = "include_pets_types",
        width = WeakAuras.normalWidth,
        test = "true",
        enable = function(trigger)
          return trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end
      },
      {
        name = "ignoreSelf",
        display = L["Ignore Self"],
        type = "toggle",
        width = WeakAuras.doubleWidth,
        enable = function(trigger)
          return trigger.unit == "nameplate" or trigger.unit == "group" or trigger.unit == "raid" or trigger.unit == "party"
        end,
        init = "not Private.ExecEnv.UnitIsUnit(\"player\", unit)"
      },
      {
        name = "onUpdateUnitTarget",
        display = WeakAuras.newFeatureString .. L["Advanced Caster's Target Check"],
        desc = L["Check nameplate's target every 0.2s"],
        type = "toggle",
        test = "true",
        enable = function(trigger)
          return trigger.unit == "nameplate"
        end
      },
      {
        name = "inverse",
        display = L["Inverse"],
        type = "toggle",
        test = "true",
        reloadOptions = true
      },
      {
        hidden = true,
        test = "WeakAuras.UnitExistsFixed(unit, smart) and ((not inverseTrigger and spell) or (inverseTrigger and not spell)) and specificUnitCheck"
      },
      {
        name = "stagesData",
        hidden = true,
        test = "true",
        store = true,
        init = "stagesData",
      }
    },
    overlayFuncs = {
      {
        name = L["Latency"],
        underlay = true,
        func = function(trigger, state)
          local latency = WeakAuras.GetCastLatency()
          if not latency then return 0, 0 end
          return 0, latency
        end,
        enable = function(trigger)
          return trigger.use_showLatency and trigger.unit == "player"
        end
      },
      {
        name = L["Empowered 1"],
        func = function(trigger, state)
          if not state.stageTotal or state.stageTotal < 1 then return 0, 0 end
          return state.duration - state.stagesData[1].start, state.duration - state.stagesData[1].finish
        end,
        enable = true
      },
      {
        name = L["Empowered 2"],
        func = function(trigger, state)
          if not state.stageTotal or state.stageTotal < 2 then return 0, 0 end
          return state.duration - state.stagesData[2].start, state.duration - state.stagesData[2].finish
        end,
        enable = true
      },
      {
        name = L["Empowered 3"],
        func = function(trigger, state)
          if not state.stageTotal or state.stageTotal < 3 then return 0, 0 end
          return state.duration - state.stagesData[3].start, state.duration - state.stagesData[3].finish
        end,
        enable = true
      },
      {
        name = L["Empowered 4"],
        func = function(trigger, state)
          if not state.stageTotal or state.stageTotal < 4 then return 0, 0 end
          return state.duration - state.stagesData[4].start, state.duration - state.stagesData[4].finish
        end,
        enable = true
      },
      {
        name = L["Empowered 5"],
        func = function(trigger, state)
          if not state.stageTotal or state.stageTotal < 5 then return 0, 0 end
          return state.duration - state.stagesData[5].start, state.duration - state.stagesData[5].finish
        end,
        enable = true
      },
      {
        name = L["Empowered Fully Charged"],
        func = function(trigger, state)
          if not state.stageTotal or not state.stagesData[state.stageTotal]
            or not trigger.use_showChargedDuration
          then
            return 0, 0
          end
          return state.duration - state.stagesData[state.stageTotal].finish, 0
        end,
        enable = function(trigger)
          return trigger.use_showChargedDuration
        end
      }
    },
    GetNameAndIcon = function(trigger)
      local name, icon, spellId, _
      if trigger.use_spellNames and type(trigger.spellNames) == "table" then
        for _, spellName in ipairs(trigger.spellNames) do
          spellId = WeakAuras.SafeToNumber(spellName)
          if spellId then
            name, _, icon = Private.ExecEnv.GetSpellInfo(spellName)
            if name and icon then
              return name, icon
            end
          elseif not tonumber(spellName) then
            name, _, icon = Private.ExecEnv.GetSpellInfo(spellName)
            if name and icon then
              return name, icon
            end
          end
        end
      end
      if trigger.use_spellIds and type(trigger.spellIds) == "table" then
        for _, spellIdString in ipairs(trigger.spellIds) do
          spellId = WeakAuras.SafeToNumber(spellIdString)
          if spellId then
            name, _, icon = Private.ExecEnv.GetSpellInfo(spellIdString)
            if name and icon then
              return name, icon
            end
          end
        end
      end
    end,
    automaticrequired = true,
  },
  ["Character Stats"] = {
    type = "unit",
    name = L["Character Stats"],
    events = {
      ["events"] = {
        "COMBAT_RATING_UPDATE",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_DAMAGE_DONE_MODS",
        "SPELL_POWER_CHANGED",
        "SKILL_LINES_CHANGED",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_LEVEL_UP",
        "ADDON_RESTRICTION_STATE_CHANGED"
      },
      ["unit_events"] = {
        ["player"] = {"UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_SPELL_HASTE", "UNIT_ATTACK_SPEED", "UNIT_AURA", "UNIT_RESISTANCES"}
      }
    },
    internal_events = function(trigger, untrigger)
      local events = { "WA_DELAYED_PLAYER_ENTERING_WORLD", "WA_SECRET_STATE_UPDATE" }
      if trigger.use_moveSpeed then
        tinsert(events, "PLAYER_MOVE_SPEED_UPDATE")
      end
      return events
    end,
    loadFunc = function(trigger)
      if trigger.use_moveSpeed then
        WeakAuras.WatchForPlayerMoving()
      end
    end,
    init = function()
      local ret = [[
        local statsAreSecret = C_Secrets.ShouldUnitStatsBeSecret()
        local main_stat, _
        _, _, _, _, _, main_stat = Private.ExecEnv.GetSpecializationInfo(Private.ExecEnv.GetSpecialization() or 0)
        local rangedHaste, ammoHaste, baseDefense, defenseModifier
        if not statsAreSecret then
          rangedHaste, ammoHaste = GetRangedHaste()
          baseDefense, defenseModifier = UnitDefenseSkill("player")
        end
      ]]
      return ret;
    end,
    force_events = "CONDITIONS_CHECK",
    statesParameter = "one",
    args = {
      {
        type = "header",
        name = "primaryStatsHeader",
        display = L["Primary Stats"],
      },
      {
        name = "mainstat",
        display = L["Main Stat"],
        type = "number",
        init = "select(2, UnitStat('player', main_stat or 1))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "strength",
        display = L["Strength"],
        type = "number",
        init = "select(2, UnitStat('player', LE_UNIT_STAT_STRENGTH))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "agility",
        display = L["Agility"],
        type = "number",
        init = "select(2, UnitStat('player', LE_UNIT_STAT_AGILITY))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "intellect",
        display = L["Intellect"],
        type = "number",
        init = "select(2, UnitStat('player', LE_UNIT_STAT_INTELLECT))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "spirit",
        display = L["Spirit"],
        type = "number",
        init = "select(2, UnitStat('player', LE_UNIT_STAT_SPIRIT))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "stamina",
        display = L["Stamina"],
        type = "number",
        init = "select(2, UnitStat('player', LE_UNIT_STAT_STAMINA))",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        type = "header",
        name = "secondaryStatsHeader",
        display = L["Secondary Stats"],
      },
      {
        name = "criticalrating",
        display = L["Critical Rating"],
        type = "number",
        init = "not statsAreSecret and (max(GetCombatRating(CR_CRIT_MELEE), GetCombatRating(CR_CRIT_RANGED), GetCombatRating(CR_CRIT_SPELL))) or nil",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "criticalpercent",
        display = L["Critical (%)"],
        type = "number",
        init = "not statsAreSecret and (max(GetCritChance(), GetRangedCritChance(), GetSpellCritChance())) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "meleecritpercent",
        display = L["Melee Critical (%)"],
        type = "number",
        init = "GetCritChance()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "rangedcritpercent",
        display = L["Ranged Critical (%)"],
        type = "number",
        init = "GetRangedCritChance()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "spellcritpercent",
        display = L["Spell Critical (%)"],
        type = "number",
        init = "GetSpellCritChance()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "hitrating",
        display = L["Hit Rating"],
        type = "number",
        init = "not statsAreSecret and (max(GetCombatRating(CR_HIT_MELEE), GetCombatRating(CR_HIT_RANGED), GetCombatRating(CR_HIT_SPELL))) or nil",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "hitpercent",
        display = L["Hit (%)"],
        type = "number",
        init = "not statsAreSecret and (max(GetCombatRatingBonus(CR_HIT_MELEE) + GetHitModifier(), GetCombatRatingBonus(CR_HIT_RANGED) + GetRangedHitModifier(), GetCombatRatingBonus(CR_HIT_SPELL) + GetSpellHitModifier())) or nil",
        store = true,
        conditionType = "number",
        enable = true,
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "hasterating",
        display = L["Haste Rating"],
        type = "number",
        init = "not statsAreSecret and (max(GetCombatRating(CR_HASTE_MELEE), GetCombatRating(CR_HASTE_RANGED), GetCombatRating(CR_HASTE_SPELL))) or nil",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "hastepercent",
        display = L["Haste (%)"],
        type = "number",
        init = "not statsAreSecret and (max(GetMeleeHaste(), rangedHaste + ammoHaste, UnitSpellHaste('player'))) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "meleehastepercent",
        display = L["Melee Haste (%)"],
        type = "number",
        init = "GetMeleeHaste()",
        store = true,
        conditionType = "number",
        enable = true,
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "rangedhastepercent",
        display = L["Ranged Haste (%)"],
        type = "number",
        init = "not statsAreSecret and (rangedHaste + ammoHaste) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "spellhastepercent",
        display = L["Spell Haste (%)"],
        type = "number",
        init = "UnitSpellHaste('player')",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "expertiserating",
        display = L["Expertise Rating"],
        type = "number",
        init = "GetCombatRating(CR_EXPERTISE)",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "expertisebonus",
        display = L["Expertise from Rating (%)"],
        type = "number",
        init = "GetCombatRatingBonus(CR_EXPERTISE)",
        store = true,
        conditionType = "number",
        enable = true,
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "expertisepercent",
        display = L["Expertise (%)"],
        type = "number",
        init = "not statsAreSecret and (max(GetExpertise())) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "armorpenrating",
        display = L["Armor Penetration Rating"],
        type = "number",
        init = "GetCombatRating(CR_ARMOR_PENETRATION)",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "armorpenpercent",
        display = L["Armor Penetration"],
        type = "number",
        init = "GetArmorPenetration()",
        store = true,
        conditionType = "number",
        enable = true,
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "spellpenpercent",
        display = L["Spell Penetration"],
        type = "number",
        init = "GetSpellPenetration()",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "attackpower",
        display = L["Attack Power"],
        type = "number",
        init = "not statsAreSecret and (WeakAuras.GetEffectiveAttackPower()) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "rangedattackpower",
        display = L["Ranged Attack Power"],
        type = "number",
        init = "not statsAreSecret and (WeakAuras.GetEffectiveAttackPower(true)) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "spellpower",
        display = L["Spell Power"],
        type = "number",
        init = "not statsAreSecret and (WeakAuras.GetEffectiveSpellPower()) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        enable = true,
        hidden = false,
      },
      {
        name = "bonushealing",
        display = L["Bonus Healing"],
        type = "number",
        init = "GetSpellBonusHealing()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "manaregen",
        display = L["Mana Regen (per second)"],
        type = "number",
        init = "select(2, GetManaRegen())",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "manaregenidle",
        display = L["Mana Regen Not Casting (per second)"],
        type = "number",
        init = "(GetManaRegen())",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        type = "header",
        name = "tertiaryStatsHeader",
        display = L["Movement Speed"],
      },
      {
        name = "moveSpeed",
        display = L["Continuously update Movement Speed"],
        type = "boolean",
        test = true,
        width = WeakAuras.doubleWidth
      },
      {
        name = "movespeedpercent",
        display = L["Current Movement Speed (%)"],
        type = "number",
        init = "not statsAreSecret and ((GetUnitSpeed('player') / 7 * 100)) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "runspeedpercent",
        display = L["Run Speed (%)"],
        type = "number",
        init = "not statsAreSecret and ((select(2, GetUnitSpeed('player')) / 7 * 100)) or nil",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        type = "header",
        name = "defensiveStatsHeader",
        display = L["Defensive Stats"],
      },
      {
        name = "defense",
        display = L["Defense"],
        type = "number",
        init = "not statsAreSecret and (max(0, baseDefense + defenseModifier)) or nil",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "dodgerating",
        display = L["Dodge Rating"],
        type = "number",
        init = "GetCombatRating(CR_DODGE)",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "dodgepercent",
        display = L["Dodge (%)"],
        type = "number",
        init = "GetDodgeChance()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "parryrating",
        display = L["Parry Rating"],
        type = "number",
        init = "GetCombatRating(CR_PARRY)",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "parrypercent",
        display = L["Parry (%)"],
        type = "number",
        init = "GetParryChance()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "blockpercent",
        display = L["Block (%)"],
        type = "number",
        init = "GetBlockChance()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "blockvalue",
        display = L["Block Value"],
        type = "number",
        init = "GetShieldBlock()",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "armorrating",
        display = L["Armor"],
        type = "number",
        init = "select(2, UnitArmor('player'))",
        store = true,
        conditionType = "number",
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "armorpercent",
        display = L["Armor (%)"],
        type = "number",
        init = "not statsAreSecret and (PaperDollFrame_GetArmorReduction(select(2, UnitArmor('player')), UnitEffectiveLevel('player'))) or nil",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        name = "armortargetpercent",
        display = L["Armor against Target (%)"],
        type = "number",
        init = "not statsAreSecret and (PaperDollFrame_GetArmorReductionAgainstTarget(select(2, UnitArmor('player')))) or nil",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
        formatter = "Number",
      },
      {
        type = "header",
        name = "resistanceHeader",
        display = L["Resistances"],
        hidden = false,
        enable = true,
      },
      {
        name = "resistanceholy",
        display = L["Holy Resistance"],
        type = "number",
        init = "select(3, UnitResistance('player', Enum.Damageclass.Holy))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "resistancefire",
        display = L["Fire Resistance"],
        type = "number",
        init = "select(3, UnitResistance('player', Enum.Damageclass.Fire))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "resistancenature",
        display = L["Nature Resistance"],
        type = "number",
        init = "select(3, UnitResistance('player', Enum.Damageclass.Nature))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "resistancefrost",
        display = L["Frost Resistance"],
        type = "number",
        init = "select(3, UnitResistance('player', Enum.Damageclass.Frost))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "resistanceshadow",
        display = L["Shadow Resistance"],
        type = "number",
        init = "select(3, UnitResistance('player', Enum.Damageclass.Shadow))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
      {
        name = "resistancearcane",
        display = L["Arcane Resistance"],
        type = "number",
        init = "select(3, UnitResistance('player', Enum.Damageclass.Arcane))",
        store = true,
        enable = true,
        conditionType = "number",
        hidden = false,
        multiEntry = {
          operator = "and",
          limit = 2
        },
      },
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Conditions"] = {
    type = "unit",
    events = function(trigger, untrigger)
      local events = {}
      if trigger.use_incombat ~= nil then
        tinsert(events, "PLAYER_REGEN_ENABLED")
        tinsert(events, "PLAYER_REGEN_DISABLED")
        tinsert(events, "PLAYER_ENTERING_WORLD")
      end
      if trigger.use_pvpflagged ~= nil or trigger.use_afk ~= nil then
        tinsert(events, "PLAYER_FLAGS_CHANGED")
      end
      if trigger.use_alive ~= nil then
        tinsert(events, "PLAYER_DEAD")
        tinsert(events, "PLAYER_ALIVE")
        tinsert(events, "PLAYER_UNGHOST")
      end
      if trigger.use_resting ~= nil then
        tinsert(events, "PLAYER_UPDATE_RESTING")
        tinsert(events, "PLAYER_ENTERING_WORLD")
      end
      if trigger.use_mounted ~= nil then
        tinsert(events, "PLAYER_MOUNT_DISPLAY_CHANGED")
        tinsert(events, "PLAYER_ENTERING_WORLD")
      end
      local unit_events = {}
      local pet_unit_events = {}
      if trigger.use_vehicle ~= nil then
        do
          tinsert(unit_events, "UNIT_ENTERED_VEHICLE")
          tinsert(unit_events, "UNIT_EXITED_VEHICLE")
        end
        tinsert(events, "PLAYER_ENTERING_WORLD")
      end
      if trigger.use_HasPet ~= nil then
        tinsert(pet_unit_events, "UNIT_HEALTH")
      end
      if trigger.use_ingroup ~= nil then
        tinsert(events, "GROUP_ROSTER_UPDATE")
      end
      if trigger.use_instance_difficulty ~= nil
         or trigger.use_instance_type ~= nil
         or trigger.use_instance_size ~= nil
      then
        tinsert(events, "PLAYER_DIFFICULTY_CHANGED")
      end

      return {
        ["events"] = events,
        ["unit_events"] = {
          ["player"] = unit_events,
          ["pet"] = pet_unit_events
        }
      }
    end,
    internal_events = function(trigger, untrigger)
      local events = { "CONDITIONS_CHECK"};

      if (trigger.use_ismoving ~= nil) then
        tinsert(events, "PLAYER_MOVING_UPDATE");
      end

      if trigger.use_instance_difficulty ~= nil
        or trigger.use_instance_type ~= nil
        or trigger.use_instance_size ~= nil
        or trigger.use_pvpflagged ~= nil
      then
        tinsert(events, "WA_DELAYED_PLAYER_ENTERING_WORLD")
      end

      if (trigger.use_HasPet ~= nil) then
        AddUnitChangeInternalEvents("pet", events)
      end
      if trigger.use_secret_state ~= nil then
        tinsert(events, "WA_SECRET_STATE_UPDATE")
      end

      return events;
    end,
    force_events = "CONDITIONS_CHECK",
    name = L["Conditions"],
    loadFunc = function(trigger)
      if (trigger.use_ismoving ~= nil) then
        WeakAuras.WatchForPlayerMoving();
      end
      if (trigger.use_HasPet ~= nil) then
        AddWatchedUnits("pet")
      end
    end,
    init = function(trigger)
      return "";
    end,
    args = {
      {
        name = "alwaystrue",
        display = L["Always active trigger"],
        type = "tristate",
        init = "true"
      },
      {
        name = "incombat",
        display = L["In Combat"],
        type = "tristate",
        init = "UnitAffectingCombat('player')"
      },
      {
        name = "pvpflagged",
        display = L["PvP Flagged"],
        type = "tristate",
        init = "UnitIsPVP('player')",
        enable = true,
        hidden = false
      },
      {
        name = "alive",
        display = L["Alive"],
        type = "tristate",
        init = "not UnitIsDeadOrGhost('player')"
      },
      {
        name = "vehicle",
        display = L["In Vehicle"],
        type = "tristate",
        init = "UnitInVehicle('player')",
      },
      {
        name = "resting",
        display = L["Resting"],
        type = "tristate",
        init = "IsResting()"
      },
      {
        name = "mounted",
        display = L["Mounted"],
        type = "tristate",
        init = "IsMounted()"
      },
      {
        name = "HasPet",
        display = L["HasPet"],
        type = "tristate",
        init = "UnitExists('pet') and not UnitIsDead('pet')"
      },
      {
        name = "ismoving",
        display = L["Is Moving"],
        type = "tristate",
        init = "IsPlayerMoving()"
      },
      {
        name = "afk",
        display = L["Is Away from Keyboard"],
        type = "tristate",
        init = "UnitIsAFK('player')"
      },
      {
        name = "ingroup",
        display = L["Group Type"],
        type = "multiselect",
        values = "group_types",
        init = "Private.ExecEnv.GroupType()",
      },
      {
        name = "instance_size",
        display = L["Instance Size Type"],
        desc = constants.instanceFilterDeprecated,
        hidden = function(trigger) return trigger.use_instance_size == nil end,
        type = "multiselect",
        values = "instance_types",
        sorted = true,
        init = "WeakAuras.InstanceType()",
      },
      {
        name = "instance_difficulty",
        display = L["Instance Difficulty"],
        desc = constants.instanceFilterDeprecated,
        hidden = function(trigger) return trigger.use_instance_difficulty == nil end,
        type = "multiselect",
        values = "difficulty_types",
        init = "WeakAuras.InstanceDifficulty()",
        enable = true,
      },
      {
        name = "instance_type",
        display = L["Instance Type"],
        desc = constants.instanceFilterDeprecated,
        hidden = function(trigger) return trigger.use_instance_type == nil end,
        type = "multiselect",
        values = "instance_difficulty_types",
        init = "WeakAuras.InstanceTypeRaw()",
        enable = true,
      },
      {
        name = "secret_state",
        display = L["Secret Restrictions Active"],
        type = "tristate",
        init = "WeakAuras.IsSecretStateActive()",
      },
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Spell Known"] = {
    type = "spell",
    events = {
      ["events"] = {"SPELLS_CHANGED"},
      ["unit_events"] = {
        ["player"] = {"UNIT_PET"}
      }
    },
    internal_events = {
      "WA_DELAYED_PLAYER_ENTERING_WORLD"
    },
    force_events = "SPELLS_CHANGED",
    name = L["Spell Known"],
    statesParameter = "one",
    init = function(trigger)
      local spellName;
      local ret = {};
      if (trigger.use_exact_spellName) then
        spellName = tonumber(trigger.spellName) or "nil";
        if spellName == 0 then
          spellName = "nil"
        end
        table.insert(ret, ([[
          local spellName = %s;
          local name, _, icon = Private.ExecEnv.GetSpellInfo(spellName)
        ]]):format(spellName))
      else
        local name = type(trigger.spellName) == "number" and Private.ExecEnv.GetSpellName(trigger.spellName) or trigger.spellName or "";
        table.insert(ret, ([[
          local spellName = select(7, Private.ExecEnv.GetSpellInfo(%q))
          local name, _, icon = Private.ExecEnv.GetSpellInfo(spellName)
        ]]):format(name))
      end
      if (trigger.use_inverse) then
        table.insert(ret, ([[
          local usePet = %s;
          local active = not spellName or not WeakAuras.IsSpellKnown(spellName, usePet)
        ]]):format(trigger.use_petspell and "true" or "false"))
      else
        table.insert(ret, ([[
          local usePet = %s;
          local active = spellName and WeakAuras.IsSpellKnown(spellName, usePet)
        ]]):format(trigger.use_petspell and "true" or "false"))
      end
      return table.concat(ret)
    end,
    GetNameAndIcon = function(trigger)
      local name, _, icon = Private.ExecEnv.GetSpellInfo(trigger.spellName)
      return name, icon
    end,
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        test = "true",
        showExactOption = true,
      },
      {
        name = "petspell",
        display = L["Pet Spell"],
        type = "toggle",
        test = "true"
      },
      {
        name = "inverse",
        display = WeakAuras.newFeatureString .. L["Inverse"],
        type = "toggle",
        test = "true",
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        hidden = true,
        test = "active"
      }
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Pet Behavior"] = {
    type = "unit",
    events = function(trigger)
      local result = {};
      if (trigger.use_behavior) then
        tinsert(result, "PET_BAR_UPDATE");
      end
      if (trigger.use_petspec) then
        tinsert(result, "PET_SPECIALIZATION_CHANGED");
      end
      return {
        ["events"] = result,
        ["unit_events"] = {
          ["player"] = {"UNIT_PET"}
        }
      };
    end,
    internal_events = {
      "WA_DELAYED_PLAYER_ENTERING_WORLD"
    },
    force_events = "WA_DELAYED_PLAYER_ENTERING_WORLD",
    name = L["Pet"],
    init = function(trigger)
      local ret = "local activeIcon\n";
      if (trigger.use_behavior) then
        ret = [[
            local inverse = %s
            local check_behavior = %s
            local name, i, active, behavior, _
            for index = 1, NUM_PET_ACTION_SLOTS do
              name, i, _, active = GetPetActionInfo(index)
              if active then
                activeIcon = _G[i]
                if name == "PET_MODE_AGGRESSIVE" then
                  behavior = "aggressive"
                  break
                elseif name == "PET_MODE_ASSIST" then
                  behavior = "assist"
                  break
                elseif name == "PET_MODE_DEFENSIVEASSIST" then
                  behavior = "defensive"
                  break
                elseif name == "PET_MODE_DEFENSIVE" then
                  behavior = "defensive"
                  break
                elseif name == "PET_MODE_PASSIVE" then
                  behavior = "passive"
                  break
                end
              end
            end
        ]]
        ret = ret:format(trigger.use_inverse and "true" or "false", trigger.use_behavior and ('"' .. (trigger.behavior or "") .. '"') or "nil");
      end
      if (trigger.use_petspec) then
        ret = ret .. [[
          local petspec = Private.ExecEnv.GetSpecialization(false, true)
          if (petspec) then
            activeIcon = select(4, Private.ExecEnv.GetSpecializationInfo(petspec, false, true));
          end
        ]]
      end
      return ret;
    end,
    statesParameter = "one",
    args = {
      {
        name = "behavior",
        display = L["Pet Behavior"],
        type = "select",
        values = "pet_behavior_types",
        test = "UnitExists('pet') and (not check_behavior or (inverse and check_behavior ~= behavior) or (not inverse and check_behavior == behavior))",
      },
      {
        name = "inverse",
        display = L["Inverse Pet Behavior"],
        type = "toggle",
        test = "true",
        enable = function(trigger) return trigger.use_behavior end
      },
      {
        name = "petspec",
        display = L["Pet Specialization"],
        type = "select",
        values = "pet_spec_types",
      },
      {
        hidden = true,
        name = "icon",
        init = "activeIcon",
        store = "true",
        test = "true"
      },
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Queued Action"] = {
    type = "spell",
    events = {
      -- Refresh on login and spellbook changes as well as queue transitions.
      ["events"] = {"ACTIONBAR_UPDATE_STATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED"}
    },
    internal_events = {
      "ACTIONBAR_SLOT_CHANGED",
      "ACTIONBAR_PAGE_CHANGED"
    },
    force_events = "PLAYER_ENTERING_WORLD",
    name = L["Queued Action"],
    init = function(trigger)
      trigger.spellName = trigger.spellName or 0
      local spellName
      if trigger.use_exact_spellName then
        spellName = trigger.spellName
      else
        spellName = type(trigger.spellName) == "number" and Private.ExecEnv.GetSpellInfo(trigger.spellName) or trigger.spellName
      end
      local ret = [=[
        local spellname = %q
      ]=]
      return ret:format(spellName or "")
    end,
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        desc = "Tracks whether Blizzard reports this spell as current or queued, including next-swing attacks such as Heroic Strike.",
        type = "spell",
        test = "true",
        showExactOption = true,
      },
      {
        hidden = true,
        -- Keep the legacy trigger semantics, with a readable boolean from the modern API.
        test = "Private.ExecEnv.IsQueuedSpell(spellname)";
      },
    },
    iconFunc = function(trigger)
      return Private.ExecEnv.GetSpellIcon(trigger.spellName or 0);
    end,
    automaticrequired = true,
    progressType = "none"
  },
  -- Spell in Range: active while the spell can reach the unit; Inverse, while
  -- the unit is out of the spell's range. Inactive when range cannot be told.
  ["Spell in Range"] = {
    type = "spell",
    events = {
      ["events"] = {"FRAME_UPDATE"}
    },
    name = L["Spell in Range"],
    statesParameter = "one",
    init = function(trigger)
      trigger.unit = trigger.unit or "target"
      local spell
      if trigger.use_exact_spellName then
        spell = tostring(tonumber(trigger.spellName) or 0)
      else
        local name = type(trigger.spellName) == "number" and Private.ExecEnv.GetSpellName(trigger.spellName) or trigger.spellName or ""
        spell = ("%q"):format(name)
      end
      return ([[
        local unit = %q
        local spell = %s
        local name, _, icon = Private.ExecEnv.GetSpellInfo(spell)
        local inRange = UnitExists(unit) and WeakAuras.IsSpellInRange(spell, unit) or nil
        local active = inRange == %d
      ]]):format(trigger.unit, spell, trigger.use_inverse and 0 or 1)
    end,
    GetNameAndIcon = function(trigger)
      local name, _, icon = Private.ExecEnv.GetSpellInfo(trigger.spellName)
      return name, icon
    end,
    args = {
      {
        name = "spellName",
        required = true,
        display = L["Spell"],
        type = "spell",
        test = "true",
        showExactOption = true,
      },
      {
        name = "unit",
        required = true,
        display = L["Unit"],
        type = "unit",
        init = "unit",
        values = "unit_types_range_check",
        test = "true",
        store = true
      },
      {
        name = "inverse",
        display = L["Inverse"],
        desc = "Show while the unit is out of the spell's range instead.",
        type = "toggle",
        test = "true",
      },
      {
        name = "name",
        display = L["Name"],
        hidden = true,
        init = "name",
        test = "true",
        store = true,
        conditionType = "string"
      },
      {
        name = "icon",
        hidden = true,
        init = "icon",
        test = "true",
        store = true
      },
      {
        hidden = true,
        test = "active"
      }
    },
    iconFunc = function(trigger)
      return Private.ExecEnv.GetSpellIcon(trigger.spellName or 0);
    end,
    automaticrequired = true,
    progressType = "none"
  },
  -- Range Check, as in WeakAuras. Uses LibRangeCheck through ForeverAuras.GetRange,
  -- which treats a secret or failed range check as unknown (0 to 999 yards).
  ["Range Check"] = {
    type = "unit",
    events = {
      ["events"] = {"FRAME_UPDATE"}
    },
    name = L["Range Check"],
    init = function(trigger)
      trigger.unit = trigger.unit or "target";
      local ret = [=[
          local unit = %q;
          local min, max = WeakAuras.GetRange(unit, true);
          min = min or 0;
          max = max or 999;
          local triggerResult = true;
      ]=]
      if (trigger.use_range) then
        trigger.range = trigger.range or 8;
        if (trigger.range_operator == "<=") then
          ret = ret .. "triggerResult = max <= " .. tostring(tonumber(trigger.range) or 8) .. "\n";
        else
          ret = ret .. "triggerResult = min >= " .. tostring(tonumber(trigger.range) or 8) .. "\n";
        end
      end
      return ret:format(trigger.unit);
    end,
    statesParameter = "one",
    args = {
      {
        name = "note",
        type = "description",
        display = "",
        text = function() return L["Note: This trigger type estimates the range to the hitbox of a unit. The actual range of friendly players is usually 3 yards more than the estimate. Range checking capabilities depend on your current class and known abilities as well as the type of unit being checked. Some of the ranges may also not work with certain NPCs.|n|n|cFFAAFFAAFriendly Units:|r %s|n|cFFFFAAAAHarmful Units:|r %s|n|cFFAAAAFFMiscellanous Units:|r %s"]:format(RangeCacheStrings.friend or "", RangeCacheStrings.harm or "", RangeCacheStrings.misc or "") end
      },
      {
        name = "unit",
        required = true,
        display = L["Unit"],
        type = "unit",
        init = "unit",
        values = "unit_types_range_check",
        test = "true",
        store = true
      },
      {
        hidden = true,
        name = "minRange",
        display = L["Minimum Estimate"],
        type = "number",
        init = "min",
        store = true,
        test = "true",
        conditionType = "number",
        operator_types = "without_equal",
      },
      {
        hidden = true,
        name = "maxRange",
        display = L["Maximum Estimate"],
        type = "number",
        init = "max",
        store = true,
        test = "true",
        conditionType = "number",
        operator_types = "without_equal",
      },
      {
        name = "range",
        display = L["Distance"],
        type = "number",
        operator_types = "without_equal",
        test = "triggerResult",
        conditionType = "number",
        conditionTest = function(state, needle, needle2)
          return state and WeakAuras.CheckRange(state.unit, needle, needle2);
        end,
        noProgressSource = true
      },
      {
        hidden = true,
        test = "UnitExists(unit)"
      }
    },
    automaticrequired = true,
    progressType = "none"
  },
  ["Money"] = {
    type = "unit",
    statesParameter = "one",
    progressType = "none",
    automaticrequired = true,
    events = {
      ["events"] = {"PLAYER_MONEY"}
    },
    internal_events = {"WA_DELAYED_PLAYER_ENTERING_WORLD"},
    force_events = "WA_DELAYED_PLAYER_ENTERING_WORLD",
    name = WeakAuras.newFeatureString..L["Player Money"],
    init = function()
      return [=[
        local money = GetMoney()
        local gold = floor(money / 1e4)
        local silver = floor(money / 100 % 100)
        local copper = money % 100
      ]=]
    end,
    args = {
      -- ForeverAuras: every coin part can be a trigger check and a condition
      -- (only Gold could before); Money is the total in copper.
      {
        name = "money",
        init = "money",
        type = "number",
        display = L["Money (total copper)"],
        store = true,
        conditionType = "number",
        formatter = "BigNumber"
      },
      {
        name = "gold",
        init = "gold",
        type = "number",
        display = Private.coin_icons.gold .. L["Gold"],
        store = true,
        conditionType = "number",
        formatter = "BigNumber"
      },
      {
        name = "silver",
        init = "silver",
        type = "number",
        display = Private.coin_icons.silver .. L["Silver"],
        store = true,
        conditionType = "number",
      },
      {
        name = "copper",
        init = "copper",
        type = "number",
        display = Private.coin_icons.copper .. L["Copper"],
        store = true,
        conditionType = "number",
      },
      {
        name = "icon",
        init = "C_CurrencyInfo.GetCoinIcon(money)",
        store = true,
        hidden = true,
        test = "true",
      },
    },
    GetNameAndIcon = function()
      return MONEY, C_CurrencyInfo.GetCoinIcon(GetMoney())
    end,
  },
  ["Currency"] = {
    type = "unit",
    progressType = "static",
    events = function()
      local events = {
        "CHAT_MSG_CURRENCY",
        "CURRENCY_DISPLAY_UPDATE",
      }
      do
        tinsert(events, "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED")
        tinsert(events, "CURRENCY_TRANSFER_LOG_UPDATE")
      end
      return {["events"] = events}
    end,
    internal_events = {"WA_DELAYED_PLAYER_ENTERING_WORLD"},
    force_events = "WA_DELAYED_PLAYER_ENTERING_WORLD",
    name = WeakAuras.newFeatureString..L["Currency"],
    triggerFunction = function(trigger)
      local quantityChecks, tristateChecks, cloneChecks = {}, {}, {}

      local function createQuantityCheck(property, operator, value, primary, use)
        if not use then return nil end
        if type(property) == "string" and type(operator) == "string" then
          return([[
            if not primaryCheckFailed and not ((currencyInfo["%s"] or 0) %s %s) then
              active = false
              %s
            end
          ]]):format(property, operator or "<", tonumber(value) or 0, primary and "primaryCheckFailed = true" or "")
        else
          return ""
        end
      end

      local function createTristateCheck(property, value, primary)
        if value == nil then return nil end
        return([[
          if currencyInfo["%s"] ~= %s then
            active = false
            %s
          end
        ]]):format(property, value and "true" or "false", primary and "primaryCheckFailed = true" or "")
      end

      local function createCloneCheck(property, operator, value, check_type, condition, use)
        if type(property) == "string" and type(operator) == "string" then
          if check_type == "number" and use then
            return([[
              if cloneActive and not ((currencyData["%s"] or 0) %s %s) then
                cloneActive = false
              end
            ]]):format(property, operator or "<", tonumber(value) or 0)
          elseif check_type == "tristate" and value ~= nil then
            return([[
              if cloneActive and %s ~= %s then
                cloneActive = false
              end
            ]]):format(condition, value and "true" or "false")
          else
          end
        end
        return ""
      end

      table.insert(quantityChecks, createQuantityCheck("quantity", trigger.value_operator, trigger.value, nil, trigger.use_value))
      table.insert(quantityChecks, createQuantityCheck("realCharacterQuantity", trigger.realCharacterQuantity_operator, trigger.realCharacterQuantity, nil, trigger.use_realCharacterQuantity))
      table.insert(quantityChecks, createQuantityCheck("accountQuantity", trigger.accountQuantity_operator, trigger.accountQuantity, true, trigger.use_accountQuantity))
      table.insert(quantityChecks, createQuantityCheck("realAccountQuantity", trigger.realAccountQuantity_operator, trigger.realAccountQuantity, true, trigger.use_realAccountQuantity))
      table.insert(quantityChecks, createQuantityCheck("maxQuantity", trigger.maxQuantity_operator, trigger.maxQuantity, true, trigger.use_maxQuantity))
      table.insert(quantityChecks, createQuantityCheck("quantityEarnedThisWeek", trigger.quantityEarnedThisWeek_operator, trigger.quantityEarnedThisWeek, true, trigger.use_quantityEarnedThisWeek))
      table.insert(quantityChecks, createQuantityCheck("totalEarned", trigger.totalEarned_operator, trigger.totalEarned, true, trigger.use_totalEarned))

      table.insert(tristateChecks, createTristateCheck("discovered", trigger.use_discovered))
      table.insert(tristateChecks, createTristateCheck("capped", trigger.use_capped))
      table.insert(tristateChecks, createTristateCheck("seasonCapped", trigger.use_seasonCapped, true))
      table.insert(tristateChecks, createTristateCheck("weeklyCapped", trigger.use_weeklyCapped, true))

      table.insert(cloneChecks, createCloneCheck("quantity", trigger.value_operator, trigger.value, "number", nil, trigger.use_value))
      table.insert(cloneChecks, createCloneCheck("realCharacterQuantity", trigger.realCharacterQuantity_operator, trigger.realCharacterQuantity, "number", nil, trigger.use_realCharacterQuantity))
      table.insert(cloneChecks, createCloneCheck("capped", nil, trigger.use_capped, "tristate", "(currencyData.quantity or 0) >= (currencyInfo.maxQuantity or 0)"))

      -- Concatenate checkstring-tables into strings
      local quantityCheckString = table.concat(quantityChecks, "\n")
      local tristateCheckString = table.concat(tristateChecks, "\n")
      local cloneCheckString = table.concat(cloneChecks, "\n")

      local ret = [=[return
      function(states)
        local currencyInfo = Private.ExecEnv.GetCurrencyAccountInfo(%d)
        local clone = %s
        local active = true
        local primaryCheckFailed = false
        local activeCharacterGUIDs = {}
        local changed

        -- Insert Quantity-related checks
        %s

        -- Insert Tristate checks
        %s

        local sharedStateValues = {
          name = currencyInfo.name,
          icon = currencyInfo.iconFileID,
          total = currencyInfo.maxQuantity,
          maxQuantity = currencyInfo.maxQuantity,
          progressType = "static",
          accountQuantity = currencyInfo.accountQuantity,
          realAccountQuantity = currencyInfo.realAccountQuantity,
          description = currencyInfo.description,
          quality = currencyInfo.quality,
          discovered = currencyInfo.discovered,
          transferPercentage = currencyInfo.transferPercentage,
          quantityEarnedThisWeek = currencyInfo.quantityEarnedThisWeek,
          totalEarned = currencyInfo.totalEarned,
        }

        if active then
          activeCharacterGUIDs[""] = true
          states[""] = states[""] or {}
          local state = states[""]

          if state.value ~= currencyInfo.quantity or state.realCharacterQuantity ~= currencyInfo.realCharacterQuantity then
            changed = true
            state.changed = true
            state.show = active
            state.value = currencyInfo.quantity
            state.realCharacterQuantity = currencyInfo.realCharacterQuantity
            state.capped = currencyInfo.capped
            state.seasonCapped = currencyInfo.seasonCapped
            state.weeklyCapped = currencyInfo.weeklyCapped
            state.characterName = UnitName("player")
            state.characterGUID = UnitGUID("player")
            state.mainCharacter = true
          end
        end

        -- Create clone states
        if clone and currencyInfo.accountCurrencyData and not primaryCheckFailed then
          for i, currencyData in ipairs(currencyInfo.accountCurrencyData) do
            local cloneActive = true

            -- Insert Clone-specific checks
            %s

            if cloneActive then
              local cloneId = currencyData.characterGUID or tostring(i)
              activeCharacterGUIDs[cloneId] = true
              states[cloneId] = states[cloneId] or {}
              local s = states[cloneId]

              if s.value ~= currencyData.quantity then
                changed = true
                s.changed = true
                s.value = currencyData.quantity
                s.realCharacterQuantity = currencyData.realCharacterQuantity
                s.characterName = currencyData.characterName
                s.characterGUID = currencyData.characterGUID
                s.mainCharacter = false
                s.show = true
              end
            end
          end
        end

        -- Remove inactive states or apply shared values
          for cloneId, state in pairs(states) do
            if not activeCharacterGUIDs[cloneId] then
              state.show = false
              state.changed = true
              changed = true
            else
              for key, value in pairs(sharedStateValues) do
                if state[key] ~= value then
                  state[key] = value
                  state.changed = true
                  changed = true
                end
              end
            end
          end

        return changed
      end
      ]=]

      return ret:format(
        trigger.currencyId or 1,
        trigger.use_clones and "true" or "false",
        quantityCheckString,
        tristateCheckString,
        cloneCheckString
      );
    end,
    statesParameter = "full",
    args = {
      {
        name = "currencyId",
        type = "currency",
        itemControl = "Dropdown-Currency",
        values = Private.GetDiscoveredCurrencies,
        headers = Private.GetDiscoveredCurrenciesHeaders,
        sorted = true,
        sortOrder = function()
          local discovered_currencies_sorted = Private.GetDiscoveredCurrenciesSorted()
          local sortOrder = {}
          for key, value in pairs(Private.GetDiscoveredCurrencies()) do
            tinsert(sortOrder, key)
          end
          table.sort(sortOrder, function(aKey, bKey)
            local aValue = discovered_currencies_sorted[aKey]
            local bValue = discovered_currencies_sorted[bKey]
            return aValue < bValue
          end)
          return sortOrder
        end,
        required = true,
        display = L["Currency"],
        store = true,
        test = "true",
      },
      {
        name = "name",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "value",
        type = "number",
        display = L["Quantity"],
        store = true,
        conditionType = "number",
      },
      {
        name = "total",
        type = "number",
        hidden = true,
        store = true,
        test = "true",
      },
      {
        name = "icon",
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "realCharacterQuantity",
        type = "number",
        display = L["Character Transferred Quantity"],
        desc = L["The total quantity a warband character can transfer after paying the transfer cost"],
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.isAccountTransferable
        end
      },
      {
        name = "accountQuantity",
        type = "number",
        display = L["Warband Quantity Total"],
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.isAccountTransferable
        end
      },
      {
        name = "realAccountQuantity",
        type = "number",
        display = L["Warband Transferred Quantity"],
        desc = L["The total quantity after transferring everything to your current character and paying the transfer cost"],
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.isAccountTransferable
        end
      },
      {
        name = "maxQuantity",
        type = "number",
        display = L["Max Quantity"],
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.maxQuantity and currencyInfo.maxQuantity > 0
        end
      },
      {
        name = "quantityEarnedThisWeek",
        type = "number",
        display = L["Quantity earned this week"],
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.quantityEarnedThisWeek and currencyInfo.quantityEarnedThisWeek > 0
        end,
      },
      {
        name = "totalEarned",
        type = "number",
        display = L["Total Earned in this Season"],
        store = true,
        conditionType = "number",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.useTotalEarnedForMaxQty and currencyInfo.totalEarned and currencyInfo.totalEarned > 0
        end,
      },
      -- Various Capped properties
      {-- quantity / maxQuantity cap
        name = "capped",
        type = "tristate",
        display = L["Capped"],
        store = true,
        conditionType = "bool",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.maxQuantity and currencyInfo.maxQuantity > 0
        end
      },
      {-- "Season" Cap: totalEarned / maxQuantity
        name = "seasonCapped",
        type = "tristate",
        display = L["Capped at Season Max"],
        store = true,
        conditionType = "bool",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.useTotalEarnedForMaxQty == true
        end
      },
      {-- "Weekly" Cap: quantityEarnedThisWeek / maxWeeklyQuantity
        name = "weeklyCapped",
        type = "tristate",
        display = L["Capped at Weekly Max"],
        store = true,
        conditionType = "bool",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.maxWeeklyQuantity and currencyInfo.maxWeeklyQuantity > 0
        end
      },
      {
        name = "description",
        type = "string",
        display = L["Description"],
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "quality",
        type = "number",
        display = L["Quality Id"],
        hidden = true,
        test = "true",
        store = true
      },
      {
        name = "discovered",
        type = "tristate",
        display = L["Discovered"],
        store = true,
        conditionType = "bool",
      },
      {
        name = "transferPercentage",
        type = "number",
        display = L["Warband Transfer Percentage"],
        store = true,
        conditionType = "number",
        hidden = true,
        test = "true",
      },
      {
        name = "characterName",
        type = "string",
        display = L["Character Name"],
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "characterGUID",
        type = "string",
        display = L["Character GUID"],
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "mainCharacter",
        type = "boolean",
        display = L["Main Character"],
        store = true,
        conditionType = "bool",
        hidden = true,
        test = "true",
      },
      {
        name = "clones",
        type = "toggle",
        display = L["Clone per Character"],
        test = "true",
        enable = function(trigger)
          local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
          return currencyInfo and currencyInfo.isAccountTransferable
        end
      },
    },
    GetNameAndIcon = function(trigger)
      local currencyInfo = Private.GetCurrencyInfoForTrigger(trigger)
      return currencyInfo and currencyInfo.name, currencyInfo and currencyInfo.iconFileID
    end,
    automaticrequired = true
  },
  ["Location"] = {
    type = "unit",
    events = {
      ["events"] = {
        "ZONE_CHANGED",
        "ZONE_CHANGED_INDOORS",
        "ZONE_CHANGED_NEW_AREA",
        "PLAYER_DIFFICULTY_CHANGED",
        "WA_DELAYED_PLAYER_ENTERING_WORLD"
      }
    },
    internal_events = {"INSTANCE_LOCATION_CHECK"},
    force_events = "INSTANCE_LOCATION_CHECK",
    name = WeakAuras.newFeatureString..L["Location"],
    init = function(trigger)
      local ret = [=[
        local uiMapId = C_Map.GetBestMapForUnit("player")
        local zonegroupId = uiMapId and C_Map.GetMapGroupID(uiMapId)
        local instanceName, _, _, _, _, _, _, instanceId = GetInstanceInfo()
        local minimapZoneText = GetMinimapZoneText()
        local zoneText = GetZoneText()
      ]=]
      return ret
    end,
    statesParameter = "one",
    args = {
      {
        name = "zoneIds",
        display = L["Player Location ID(s)"],
        type = "string",
        multiline = true,
        desc = get_zoneId_list,
        preamble = "local zoneChecker = Private.ExecEnv.ParseZoneCheck(%q)",
        test = "zoneChecker:Check(uiMapId, zonegroupId, instanceId, minimapZoneText)",
        conditionType = "string",
        conditionPreamble = function(input)
          return Private.ExecEnv.ParseZoneCheck(input)
        end,
        conditionTest = function(state, needle, op, preamble)
          return preamble:Check(state.zoneId, state.zonegroupId, state.instanceId, state.subzone)
        end,
        operator_types = "none",
      },
      {
        name = "zoneId",
        display = L["Zone ID"],
        init = "uiMapId",
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "zonegroupId",
        display = L["Zone Group ID"],
        init = "zonegroupId",
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "zone",
        display = L["Zone Name"],
        type = "string",
        conditionType = "string",
        store = true,
        init = "zoneText",
        multiEntry = {
          operator = "or",
        }
      },
      {
        name = "subzone",
        display = L["Subzone Name"],
        desc = L["Name of the (sub-)zone currently shown above the minimap."],
        type = "string",
        conditionType = "string",
        store = true,
        init = "minimapZoneText",
        multiEntry = {
          operator = "or",
        },
      },
      {
        type = "header",
        name = "instanceHeader",
        display = L["Instance Info"],
      },
      {
        name = "instanceId",
        display = L["Instance ID"],
        init = "instanceId",
        store = true,
        hidden = true,
        test = "true",
      },
      {
        name = "instance",
        display = L["Instance Name"],
        test = "true",
        hidden = "true",
        store = true,
      },
      {
        name = "instanceSize",
        display = L["Instance Size Type"],
        type = "multiselect",
        values = "instance_types",
        sorted = true,
        init = "WeakAuras.InstanceType()",
        conditionType = "select",
        store = true,
      },
      {
        name = "instanceDifficulty",
        display = L["Instance Difficulty"],
        type = "multiselect",
        values = "difficulty_types",
        init = "WeakAuras.InstanceDifficulty()",
        conditionType = "select",
        store = true,
        enable = true,
        hidden = false,
      },
      {
        name = "instanceType",
        display = L["Instance Type"],
        type = "multiselect",
        values = "instance_difficulty_types",
        init = "WeakAuras.InstanceTypeRaw()",
        conditionType = "select",
        store = true,
        enable = true,
        hidden = false,
      },
    },
    automaticrequired = true,
    progressType = "none"
  },
};

-- Queued Action remains registered under Spell, preserving its saved event name.

Private.category_event_prototype = {}
for name, prototype in pairs(Private.event_prototypes) do
  Private.category_event_prototype[prototype.type] = Private.category_event_prototype[prototype.type] or {}
  Private.category_event_prototype[prototype.type][name] = prototype.name
end
-- The Utility prototype is an import alias, not a separate selectable trigger.
Private.category_event_prototype.cdm["Blizzard CDM Utility"] = nil
Private.category_event_prototype.addons = Private.category_event_prototype.addons or {}

Private.dynamic_texts = {
  ["p"] = {
    get = function(state)
      -- Apply GCD text policy before reading any timer, including unformatted %p.
      if not state or Private.ShouldHideDurationText(state) then return nil end
      -- Readable timing formats in Lua; restricted timers use the duration object.
      if state.progressType == "timed" and not state.paused and state.expirationTime and state.duration
        and not hasanysecretvalues(state.expirationTime, state.duration) then
        local remaining = state.expirationTime - GetTime()
        return remaining >= 0 and remaining or nil
      end
      if Private.UsesDurationText(state) then
        return Private.GetTextDuration(state):GetRemainingDuration()
      end
      if state.progressType == "static" then
        return state.value or nil
      end
      if state.progressType == "timed" then
        if state.paused then
          return state.remaining and state.remaining >= 0 and state.remaining or nil
        end

        if not state.expirationTime or not state.duration or hasanysecretvalues(state.expirationTime, state.duration) then
          return nil
        end
        local remaining = state.expirationTime - GetTime();
        return remaining >= 0 and remaining or nil
      end
    end,
    func = function(remaining, state, progressPrecision)
      progressPrecision = progressPrecision or 1
      -- Custom-text callers also use this formatter directly with a state.
      if Private.ShouldHideDurationText(state) then return "" end

      if not state or (state.progressType ~= "timed" and state.progressType ~= "durationObject") then
        return remaining
      end
      if type(remaining) ~= "number" then
        return ""
      end
      if Private.UsesDurationText(state) then
        local precision = progressPrecision or 1
        local threshold = precision >= 4 and 3 or 60
        if precision >= 4 then precision = precision - 3 end
        return Private.FormatDurationText(Private.GetTextDuration(state), false, 0, threshold, precision)
      end
      if issecretvalue(remaining) then
        return string.format("%.1f", remaining)
      end

      local remainingStr = "";
      if remaining == math.huge then
        remainingStr = " ";
      elseif remaining > 60 then
        remainingStr = string.format("%i:", math.floor(remaining / 60));
        remaining = remaining % 60;
        remainingStr = remainingStr..string.format("%02i", remaining);
      elseif remaining > 0 then
        if progressPrecision == 4 and remaining <= 3 then
          remainingStr = remainingStr..string.format("%.1f", remaining);
        elseif progressPrecision == 5 and remaining <= 3 then
          remainingStr = remainingStr..string.format("%.2f", remaining);
        elseif progressPrecision == 6 and remaining <= 3 then
          remainingStr = remainingStr..string.format("%.3f", remaining);
        elseif (progressPrecision == 4 or progressPrecision == 5 or progressPrecision == 6) and remaining > 3 then
          remainingStr = remainingStr..string.format("%d", remaining);
        else
          remainingStr = remainingStr..string.format("%.".. progressPrecision .."f", remaining);
        end
      else
        remainingStr = " ";
      end
      return remainingStr
    end
  },
  ["t"] = {
    get = function(state)
      -- Total duration text follows the same GCD policy as remaining duration.
      if not state or Private.ShouldHideDurationText(state) then return "" end
      if Private.UsesDurationText(state) then
        return Private.GetTextDuration(state):GetTotalDuration(), true
      end
      if state.progressType == "static" then
        return state.total, false
      end
      if state.progressType == "timed" then
        if not state.duration then
          return nil
        end
        return state.duration, true
      end
    end,
    func = function(duration, state, totalPrecision)
      -- Keep direct/default formatting consistent with the configured formatter.
      if Private.ShouldHideDurationText(state) then return "" end
      if not state or (state.progressType ~= "timed" and state.progressType ~= "durationObject") then
        return duration
      end
      if type(duration) ~= "number" then
        return ""
      end
      if Private.UsesDurationText(state) then
        local precision = totalPrecision or 1
        local threshold = precision >= 4 and 3 or 60
        if precision >= 4 then precision = precision - 3 end
        return Private.FormatDurationText(Private.GetTextDuration(state), true, 0, threshold, precision)
      end
      if issecretvalue(duration) then
        return string.format("%.1f", duration)
      end
      local durationStr = "";
      if math.abs(duration) == math.huge or tostring(duration) == "nan" then
        durationStr = " ";
      elseif duration > 60 then
        durationStr = string.format("%i:", math.floor(duration / 60));
        duration = duration % 60;
        durationStr = durationStr..string.format("%02i", duration);
      elseif duration > 0 then
        if totalPrecision == 4 and duration <= 3 then
          durationStr = durationStr..string.format("%.1f", duration);
        elseif totalPrecision == 5 and duration <= 3 then
          durationStr = durationStr..string.format("%.2f", duration);
        elseif totalPrecision == 6 and duration <= 3 then
          durationStr = durationStr..string.format("%.3f", duration);
        elseif (totalPrecision == 4 or totalPrecision == 5 or totalPrecision == 6) and duration > 3 then
          durationStr = durationStr..string.format("%d", duration);
        else
          durationStr = durationStr..string.format("%."..totalPrecision.."f", duration);
        end
      else
        durationStr = " ";
      end
      return durationStr
    end
  },
  ["n"] = {
    get = function(state)
      if not state then return "" end
      return state.name or state.id or "", true
    end,
    func = function(v)
      return v
    end
  },
  ["i"] = {
    get = function(state)
      if not state then return "" end
      return state.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    end,
    func = function(v)
      return "|T".. v ..":12:12:0:0:64:64:4:60:4:60|t"
    end
  },
  ["s"] = {
    get = function(state)
      local stacks = state and state.stacks
      if type(stacks) == "number" and issecretvalue(stacks) then
        return C_StringUtil.TruncateWhenZero(stacks)
      end
      if not state or state.stacks == 0 then return "" end
      return state.stacks
    end,
    func = function(v)
      return v
    end
  }
};

-- Events in that list can be filtered by unitID
Private.UnitEventList = {
  PLAYER_GUILD_UPDATE = true,
  MINIMAP_PING = true,
  PARTY_MEMBER_DISABLE = true,
  PARTY_MEMBER_ENABLE = true,
  READY_CHECK_CONFIRM = true,
  PLAYER_GAINS_VEHICLE_DATA = true,
  PLAYER_LOSES_VEHICLE_DATA = true,
  ARENA_COOLDOWNS_UPDATE = true,
  ARENA_CROWD_CONTROL_SPELL_UPDATE = true,
  HONOR_XP_UPDATE = true,
  INCOMING_RESURRECT_CHANGED = true,
  INCOMING_SUMMON_CHANGED = true,
  KNOWN_TITLES_UPDATE = true,
  PLAYER_DAMAGE_DONE_MODS = true,
  PLAYER_FLAGS_CHANGED = true,
  PLAYER_PVP_KILLS_CHANGED = true,
  PLAYER_PVP_RANK_CHANGED = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  PLAYER_TRIAL_XP_UPDATE = true,
  PLAYER_XP_UPDATE = true,
  PVP_TIMER_UPDATE = true
}

Private.InternalEventByIDList = {
  ITEM_COOLDOWN_STARTED = true,
  ITEM_COOLDOWN_CHANGED = true,
  ITEM_COOLDOWN_READY = true,
  ITEM_SLOT_COOLDOWN_STARTED = true,
  ITEM_SLOT_COOLDOWN_CHANGED = true,
  ITEM_SLOT_COOLDOWN_READY = true,
  ITEM_SLOT_COOLDOWN_ITEM_CHANGED = true,
  SPELL_COOLDOWN_CHANGED = true,
  SPELL_COOLDOWN_READY = true,
  SPELL_CHARGES_CHANGED = true,
  WA_UPDATE_OVERLAY_GLOW = true,
}
