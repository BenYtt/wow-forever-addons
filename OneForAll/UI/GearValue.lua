local _, FLT = ...

-- Gear Planner "Value" (5.6.3): sum of the item's stats x the stat weights of the active spec (the talent tree
-- with the most points; user 16.10.: standard specs only, no choice yet). Weights: Data/GearWeights.lua (Sharpie's
-- Gear Judge, MIT): level 60 = the raid profile, below 60 = the spec's leveling curve at the player's level,
-- no talents = the class's general leveling curve. Ratings are turned into % first (GEAR_RATING).
-- Compared with what is worn: rings / trinkets with the weaker one, two-handers with main + off hand.
-- Lean: weights are built once per spec / level / talent change, item values are cached per item and slot,
-- worn values per slot until the gear changes. Nothing runs until a tooltip or the planner asks.

local GV = {}
FLT.GearValue = GV
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local KEYS, RATING = FLT.GEAR_STAT_KEYS or {}, FLT.GEAR_RATING or {}
local W, specName, autoTree -- current weights; the talent tree with the most points
local values = {}  -- [slot][itemID] = value
local worn = {}    -- [slot] = value of the worn item (false = empty)
local speeds = {}  -- [itemID] = weapon speed (tooltip data)
local classOK = {} -- [itemID] = false when the item has "Classes: ..." without the player's class

local function curveAt(curve, level)
  local n = #curve
  local a, b = curve[1], curve[n]
  if level <= a[1] then b = a
  elseif level >= b[1] then a = b
  else
    for i = 1, n - 1 do
      if level >= curve[i][1] and level <= curve[i + 1][1] then a, b = curve[i], curve[i + 1]; break end
    end
  end
  local t = (b[1] > a[1]) and ((level - a[1]) / (b[1] - a[1])) or 0
  local out = {}
  for k, v in pairs(a[2]) do out[k] = v end
  for k in pairs(b[2]) do out[k] = out[k] or 0 end
  for k, va in pairs(out) do
    local v = va + ((b[2][k] or 0) - va) * t
    out[k] = (v > 0 and v < 0.02) and 0 or v
  end
  return out
end

local function buildWeights()
  local _, cls = UnitClass("player")
  local data = FLT.GEAR_WEIGHTS and FLT.GEAR_WEIGHTS[cls]
  if not data then return end
  local ok, pts = pcall(FLT.TalentPointsPerTree or function() end)
  if not ok then pts = nil end
  local tree, best = nil, 0
  for i = 1, 3 do if pts and (pts[i] or 0) > best then tree, best = i, pts[i] end end
  autoTree = tree
  -- chosen in the Gear Planner (per character, user 18.10.); nil = the active spec
  local pick = type(OneForAllCharDB) == "table" and OneForAllCharDB.gearSpec
  -- own weights (5.7.3, Discord sparkledooks, user 27.10.): OneForAllCharDB.gearCustom, edited in the planner
  local custom = pick == "custom" and type(OneForAllCharDB.gearCustom) == "table" and OneForAllCharDB.gearCustom
  if custom then
    local w = {}; for k, v in pairs(custom) do if tonumber(v) then w[k] = tonumber(v) end end
    W, specName = w, "Custom"
    wipe(values); wipe(worn)
    return
  end
  if pick and data.specs[pick] then tree = pick end
  local spec = tree and data.specs[tree]
  local level = UnitLevel("player") or 1
  local w
  if spec and level >= 60 then
    w = {}; for k, v in pairs(spec.raid) do w[k] = v end
  else
    w = curveAt(data.curves[spec and spec.curve or "Leveling"] or data.curves.Leveling, level)
  end
  -- Forever has one hit and one crit rating for melee and spells (as Gear Judge does)
  w.hit = math.max(w.hit or 0, w.shit or 0); w.crit = math.max(w.crit or 0, w.scrit or 0)
  W, specName = w, spec and spec.name or "Leveling"
  wipe(values); wipe(worn)
end
function GV.SpecName() if not W then buildWeights() end return specName end
-- the weights of a spec (nil = the active one) at the player's level, as the Value would use them
local function specWeights(i)
  local db = type(OneForAllCharDB) == "table" and OneForAllCharDB
  if not db then return {} end
  local keep = db.gearSpec
  db.gearSpec = i; W = nil; buildWeights()
  local out = {}; for k, v in pairs(W or {}) do if v ~= 0 then out[k] = math.floor(v * 100 + 0.5) / 100 end end
  db.gearSpec = keep; W = nil
  return out
end
-- own weights: created from the active spec the first time
function GV.CustomWeights()
  if type(OneForAllCharDB) ~= "table" then return {} end
  if type(OneForAllCharDB.gearCustom) ~= "table" then OneForAllCharDB.gearCustom = specWeights(nil) end
  return OneForAllCharDB.gearCustom
end
function GV.SetCustomWeight(k, v)
  local c = GV.CustomWeights()
  v = tonumber(v); c[k] = (v and v ~= 0) and v or nil
  if OneForAllCharDB.gearSpec == "custom" then GV.SetSpec("custom") end
end
-- start again from a spec's weights (nil = the active spec)
function GV.ResetCustom(i)
  if type(OneForAllCharDB) ~= "table" then return end
  OneForAllCharDB.gearCustom = specWeights(i)
  if OneForAllCharDB.gearSpec == "custom" then GV.SetSpec("custom") end
end
-- the planner's spec drop-down: the class's three specs, the one in use (nil = active spec) and the active one
function GV.Specs()
  if not W then buildWeights() end
  local _, cls = UnitClass("player")
  local data = FLT.GEAR_WEIGHTS and FLT.GEAR_WEIGHTS[cls]
  local pick = type(OneForAllCharDB) == "table" and OneForAllCharDB.gearSpec or nil
  return data and data.specs or {}, pick, autoTree
end
function GV.SetSpec(i)
  if type(OneForAllCharDB) ~= "table" then return end
  OneForAllCharDB.gearSpec = i
  W = nil; wipe(values); wipe(worn)
  if FLT.GearMarks and FLT.GearMarks.Refresh then FLT.GearMarks.Refresh() end
end

-- weapon speed is not in GetItemStats: read it once from the item's tooltip data
local function weaponSpeed(id)
  local s = speeds[id]
  if s ~= nil then return s or nil end
  s = false
  local data = C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(id)
  for _, line in ipairs(data and data.lines or {}) do
    local v = (line.rightText or ""):match("(%d+[%.,]%d+)")
    if v and (line.rightText or ""):find(SPEED or "Speed", 1, true) then s = tonumber((v:gsub(",", "."))); break end
  end
  speeds[id] = s
  return s or nil
end

-- class-only items ("Classes: Warlock"): no Value for other classes (user 23.10.: arrow on a warlock item for a priest)
local classPat
local function forMyClass(id)
  local ok = classOK[id]
  if ok ~= nil then return ok end
  local data = type(C_TooltipInfo) == "table" and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(id)
  if not (data and data.lines and data.lines[1]) then return true end -- no data yet: ask again later
  classPat = classPat or ("^" .. (type(ITEM_CLASSES_ALLOWED) == "string" and ITEM_CLASSES_ALLOWED or "Classes: %s"):gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%s", "(.+)") .. "$")
  ok = true
  for _, line in ipairs(data.lines) do
    local list = (line.leftText or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match(classPat)
    if list then
      local _, cls = UnitClass("player")
      local m = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls] or UnitClass("player")
      local f = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[cls]
      ok = false
      for name in list:gmatch("[^,]+") do
        name = name:match("^%s*(.-)%s*$")
        if name == m or name == f then ok = true; break end
      end
      break
    end
  end
  classOK[id] = ok
  return ok
end

local function score(stats, slot, id, isWand)
  local total = 0
  for k, v in pairs(stats) do
    local s = KEYS[k]
    if s and type(v) == "number" then
      local wk = s
      if s == "dps" then
        if slot == 17 and W.dpsoh then wk = "dpsoh"
        elseif (slot == 16 or slot == 17) and W.dpsmelee then wk = "dpsmelee"
        elseif isWand and W.dpswand then wk = "dpswand" end
      end
      local w = W[wk] or 0
      if w > 0 then
        local val = RATING[s] and v / RATING[s] or v
        if slot == 17 and s == "dps" and wk ~= "dpsoh" then val = val * 0.5 end
        total = total + val * w
      end
      -- spell power also heals
      if k == "ITEM_MOD_SPELL_POWER_SHORT" and (W.heal or 0) > 0 then total = total + v * W.heal end
    end
  end
  if (slot == 16 or slot == 17) and (W.speed or 0) > 0 and stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT then
    local sp = weaponSpeed(id)
    if sp then total = total + sp * W.speed end
  end
  return total
end

-- Value of an enchant / armor kit / ... (FLT.ENCHANTS stats) on the item in a slot; nil = no Value (procs and
-- other effects). Percent values become ratings, flat weapon damage becomes DPS with the weapon's speed.
local estats = {} -- reused
function GV.EnchantValue(eid, slot, itemID)
  local e = FLT.ENCHANTS and FLT.ENCHANTS[eid]
  if not e or e[3] then return nil end
  if not W then buildWeights() end
  if not W then return nil end
  wipe(estats)
  for k, v in pairs(e[2]) do
    local pk = k:match("^PCT_(.+)$")
    if pk then
      local s = KEYS[pk]; estats[pk] = (estats[pk] or 0) + v * (s and RATING[s] or 1)
    elseif k == "WEAPON_DAMAGE" then
      local sp = itemID and weaponSpeed(itemID)
      if sp and sp > 0 then estats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = (estats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or 0) + v / sp end
    elseif KEYS[k] then estats[k] = (estats[k] or 0) + v end
  end
  local cid, sub
  if itemID and GetItemInfoInstant then cid, sub = select(6, GetItemInfoInstant(itemID)) end
  return score(estats, slot, itemID, cid == 2 and sub == 19)
end

local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
-- value of an item in a slot; nil while the client has no data for it yet
local function itemValue(id, slot, link)
  if not W then buildWeights() end
  if not W or not getStats then return nil end
  local cache = values[slot]
  if not cache then cache = {}; values[slot] = cache end
  -- by link when there is one: a worn "of the Eagle" item has stats its bare item ID lacks
  local key = link or id
  local v = cache[key]
  if v then return v end
  if not (GetItemInfo and GetItemInfo(id)) then return nil end
  local stats = getStats(link or ("item:" .. id))
  if not stats then return nil end
  local _, _, _, _, _, cid, sub = GetItemInfoInstant(id)
  v = score(stats, slot, id, cid == 2 and sub == 19)
  cache[key] = v
  return v
end

local function wornValue(slot)
  local v = worn[slot]
  if v ~= nil then return v end
  local link = GetInventoryItemLink("player", slot)
  if not link then worn[slot] = 0; return 0 end
  -- the item's own stats only: the enchant is taken out of the link (user 23.10.), its random bonus stays
  link = link:gsub("(item:%d+):%d*", "%1:0", 1)
  local id = tonumber(link:match("item:(%d+)"))
  v = id and itemValue(id, slot, link)
  if v then worn[slot] = v end
  return v
end

-- Value of the item worn in a slot, its random bonus included (for the enchant suggestions)
function GV.SlotItemValue(slot) return wornValue(slot) end

local function slotFor(loc, slots)
  if loc == "INVTYPE_WEAPONOFFHAND" then return 17 end
  return slots[1]
end

-- Value of an item and the change against what is worn: value, delta (nil = no data yet / not gear)
function GV.Upgrade(id)
  local _, _, _, loc, _, cid, sub = GetItemInfoInstant(id)
  local slots = loc and FLT.GEAR_LOC_SLOTS and FLT.GEAR_LOC_SLOTS[loc]
  if not slots then return nil end
  local slot = slotFor(loc, slots)
  local v = itemValue(id, slot)
  if not v or not forMyClass(id) then return nil end
  for _, s in ipairs(slots) do
    if GetInventoryItemID and GetInventoryItemID("player", s) == id then return v, 0, true end
  end
  local base, replaced
  if loc == "INVTYPE_2HWEAPON" then
    local a, b = wornValue(16), wornValue(17)
    base = a and b and (a + b)
  elseif #slots == 2 and (loc ~= "INVTYPE_WEAPON" or (FLT.CanDualWield() and select(6, GetItemInfoInstant(GetInventoryItemID("player", 17) or 0)) == 2)) then
    local a, b = wornValue(slots[1]), wornValue(slots[2])
    base = a and b and math.min(a, b)
    if base then replaced = (a <= b) and slots[1] or slots[2] end -- the weaker one, named in the tooltip
  else
    base = wornValue(slot)
  end
  if not base then return v end
  return v, v - base, false, base, replaced
end

-- What players see is the change in % against the worn item (user 16.10.): kind, pct
-- kind: "up" / "down" / "same" / "new" (nothing worn there, or it has no value) / "worn"; nil = no data yet;
-- third value: the slot compared with when there are two (rings, trinkets, dual wield)
function GV.Change(id)
  local v, d, equipped, base, replaced = GV.Upgrade(id)
  if not v then return nil end
  if equipped then return "worn" end
  if not d then return nil end
  if not base or base <= 0 then return v > 0 and "new" or "same" end
  local pct = d / base * 100
  if pct >= 0.5 then return "up", pct, replaced elseif pct <= -0.5 then return "down", -pct, replaced end
  return "same"
end

-- own arrows (tools/art/arrows.py); the client's Arrow-Up-Up was tiny and odd in the tooltip (beta10)
local ASSET = (FLT.UI and FLT.UI.ASSET_ROOT) or FLT.ASSET_ROOT or "Interface\\AddOns\\OneForAll\\Assets\\"
local OFA = "|cffc8961eOFA|r "  -- dark yellow (user 16.10.)
local UP = OFA .. "|T" .. ASSET .. "icon_arrow_up:16:16:0:0|t "
local DOWN = OFA .. "|T" .. ASSET .. "icon_arrow_down:16:16:0:0|t "
GV.UP, GV.DOWN = UP, DOWN
-- "OFA <gold star> Wishlist" in item tooltips (user 03.11.), the star tinted like the wishlist star
GV.WISH = OFA .. "|T" .. ASSET .. "icon_star:16:16:0:0:64:64:0:64:0:64:255:209:64|t Wishlist"
-- tooltip: green "Upgrade: 30%" with an arrow up, red "Downgrade: 12%" with an arrow down (like the user's example);
-- Quality of Life switch "gearValue", on by default (user 16.10.)
function GV.TooltipLine(tt, id)
  local _, _, _, loc, _, cid, sub = GetItemInfoInstant(id)
  if not (loc and FLT.GEAR_LOC_SLOTS and FLT.GEAR_LOC_SLOTS[loc]) or not FLT.GearCanUse(loc, cid, sub) then return end
  local kind, pct, slot = GV.Change(id)
  -- with two slots (rings, trinkets, dual wield): which worn item it is compared with (user 17.10.)
  -- only for upgrades: a downgrade replaces nothing (user 22.10.)
  local link = kind == "up" and slot and GetInventoryItemLink("player", slot)
  local which = link and link:match("%[(.-)%]")
  which = which and ("  |cffb0b0b0(replaces " .. which .. ")|r") or ""
  if kind == "up" then tt:AddLine(UP .. string.format("Upgrade: %d%%", math.floor(pct + 0.5)) .. which, 0.25, 1, 0.25)
  elseif kind == "new" then tt:AddLine(UP .. "Upgrade (slot empty)", 0.25, 1, 0.25)
  elseif kind == "down" then tt:AddLine(DOWN .. string.format("Downgrade: %d%%", math.floor(pct + 0.5)) .. which, 1, 0.3, 0.3) end
end

-- refresh: talents / level change the weights, gear changes the worn values
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED",
  "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_EQUIPMENT_CHANGED" then wipe(worn) else W = nil end
end)
GV._reset = function() W = nil; wipe(values); wipe(worn); wipe(speeds); wipe(classOK) end -- tests
