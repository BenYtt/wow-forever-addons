local _, FLT = ...
local UI = FLT.UI
local unpack = unpack or table.unpack

-- Gear Planner (Armory, first view since 5.6.3): character panel with the equipped items on the left,
-- on the right two tabs - "Suggested" (items for the selected slot from our own data: dungeon loot,
-- dungeon quest rewards, set pieces, reputation rewards, crafted items) and "Wishlist" (per character,
-- star on every row) - plus a search over all those items.
-- Lean: the item index is built the first time the planner opens (GetItemInfoInstant needs no server
-- data); full item info (required level) is only asked for the rows on screen; no OnUpdate.
-- The "Value" (stat weights, Data/GearWeights.lua) follows in a later step.

local GOLD = UI.GOLD
local TEXT = {0.92, 0.90, 0.84}
local DIM = {0.62, 0.60, 0.56}
local H = UI.DungeonHelpers or {}
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Slots: left column, right column, weapons (inventory slot IDs). Shirt and tabard are shown greyed
-- (no suggestions for them), so the panel looks like the character window (user 16.10.).
local SLOTS = {
  { 1, "HeadSlot", "Head" }, { 2, "NeckSlot", "Neck" }, { 3, "ShoulderSlot", "Shoulder" }, { 15, "BackSlot", "Back" },
  { 5, "ChestSlot", "Chest" }, { 4, "ShirtSlot", "Shirt", true }, { 19, "TabardSlot", "Tabard", true }, { 9, "WristSlot", "Wrist" },
  { 10, "HandsSlot", "Hands" }, { 6, "WaistSlot", "Waist" }, { 7, "LegsSlot", "Legs" }, { 8, "FeetSlot", "Feet" },
  { 11, "Finger0Slot", "Finger" }, { 12, "Finger1Slot", "Finger" }, { 13, "Trinket0Slot", "Trinket" }, { 14, "Trinket1Slot", "Trinket" },
  { 16, "MainHandSlot", "Main Hand" }, { 17, "SecondaryHandSlot", "Off Hand" }, { 18, "RangedSlot", "Ranged" },
}
local SLOT_NAME, SLOT_INDEX = {}, {}
for i, s in ipairs(SLOTS) do SLOT_NAME[s[1]] = s[3]; SLOT_INDEX[s[1]] = i end
-- equip location -> slots it fits
local LOC_SLOTS = {
  INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CLOAK = {15}, INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5},
  INVTYPE_WRIST = {9}, INVTYPE_HAND = {10}, INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8},
  INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
  INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
  INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
  INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18}, INVTYPE_RELIC = {18},
}

-- Enchants, armor kits, spurs, spikes, counterweights, scopes, arcanums (Data/Enchants.lua, user 22.10.):
-- an option fits an item by item class, inventory type mask and subclass mask (0 = any)
local INVTYPE_NUM = {
  INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
  INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12,
  INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17,
  INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23,
  INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26,
}
local function hasBit(mask, n) mask = mask or 0; return mask == 0 or math.floor(mask / 2 ^ n) % 2 == 1 end
local enchCache = {} -- item ID -> options that fit it
local function enchantOptions(id)
  local list = enchCache[id]
  if list then return list end
  list = {}
  local _, _, _, loc, _, cid, sub = GetItemInfoInstant(id)
  local inv = INVTYPE_NUM[loc]
  if inv then
    for _, o in ipairs(FLT.ENCHANT_OPTIONS or {}) do
      if cid == o.c and hasBit(o.t, inv) and hasBit(o.m, sub or 0) then list[#list + 1] = o end
    end
  end
  enchCache[id] = list
  return list
end
local function wornEnchant(slot)
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
  return link and tonumber(link:match("item:%-?%d+:(%d*)")) or nil
end
local function enchantKey(o) return "ench:" .. (o.s and ("s" .. o.s) or ("i" .. tostring(o.i))) end
local function enchantIcon(o)
  if not o then return nil end
  if o.i then return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(o.i)) or (GetItemIcon and GetItemIcon(o.i)) end
  return (o.s and ((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(o.s)) or (GetSpellTexture and GetSpellTexture(o.s))))
    or "Interface\\Icons\\Trade_Engraving"
end
local PROF_ICON = { Enchanting = "Interface\\Icons\\Trade_Engraving", Leatherworking = "Interface\\Icons\\Trade_LeatherWorking",
  Blacksmithing = "Interface\\Icons\\Trade_BlackSmithing", Engineering = "Interface\\Icons\\Trade_Engineering",
  Tailoring = "Interface\\Icons\\Trade_Tailoring" }

-- What a class can wear / wield (Forever = Classic rules). Armor subclass: 1 cloth 2 leather 3 mail 4 plate 6 shield.
local ARMOR_MAX = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }
local RELIC = { PALADIN = 7, DRUID = 8, SHAMAN = 9 }
local WEAPONS = { -- weapon subclass IDs
  WARRIOR = {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18}, PALADIN = {0, 1, 4, 5, 6, 7, 8},
  HUNTER = {0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18}, ROGUE = {2, 3, 4, 7, 13, 15, 16, 18},
  PRIEST = {4, 10, 15, 19}, SHAMAN = {0, 1, 4, 5, 10, 13, 15}, MAGE = {7, 10, 15, 19}, WARLOCK = {7, 10, 15, 19},
  DRUID = {4, 5, 10, 13, 15},
}
FLT.CLASS_WEAPONS = WEAPONS -- also for the weapon trainers in UI/TrainerSpells.lua
local canWield = {}
for cls, list in pairs(WEAPONS) do canWield[cls] = {}; for _, s in ipairs(list) do canWield[cls][s] = true end end

-- quests of the other faction / for other classes (quest rewards); set by refreshSlots
local mySide, myClassBit
local function hasBit(mask, b) return b and math.floor(mask / b) % 2 == 1 end
local function usable(e, cls, level)
  if e.side and e.side ~= "" and mySide and e.side ~= mySide then return false end
  if e.cls and e.cls > 0 and myClassBit and not hasBit(e.cls, myClassBit) then return false end
  if e.cid == 2 then return canWield[cls] and canWield[cls][e.sub] or false end
  if e.cid ~= 4 then return true end
  if e.loc == "INVTYPE_CLOAK" or e.sub == 0 then return true end -- cloaks, rings, necks, trinkets, holdables
  if e.sub == 6 then return SHIELD[cls] or false end
  if e.sub >= 7 and e.sub <= 9 then return RELIC[cls] == e.sub end
  local max = ARMOR_MAX[cls] or 1
  if max >= 3 and (level or 60) < 40 then max = max - 1 end -- mail / plate from level 40
  return e.sub <= max
end

-- for GearValue.lua: slots per equip location, and whether the player's class can use an item
FLT.GEAR_LOC_SLOTS = LOC_SLOTS
local probe = {}
function FLT.GearCanUse(loc, cid, sub)
  local _, cls = UnitClass("player")
  probe.loc, probe.cid, probe.sub = loc, cid, sub
  return usable(probe, cls, UnitLevel and UnitLevel("player"))
end
function FLT.CanDualWield() local _, cls = UnitClass("player"); return DUAL_WIELD[cls] or false end

-- Item index ----------------------------------------------------------------------
local index, byId -- list and id -> entry
local SKIP_LOC = { INVTYPE_BAG = true, INVTYPE_AMMO = true, INVTYPE_QUIVER = true, INVTYPE_BODY = true, INVTYPE_TABARD = true }
local function add(id, name, q, src, lvl, d)
  if type(id) ~= "number" or byId[id] then return end
  local _, _, _, loc, icon, cid, sub = GetItemInfoInstant(id)
  if not loc or loc == "" or SKIP_LOC[loc] or not LOC_SLOTS[loc] then return end
  local e = { id = id, name = name, q = q, src = src, lvl = lvl, loc = loc, icon = icon, cid = cid, sub = sub, d = d }
  byId[id] = e
  index[#index + 1] = e
  return e
end

-- Quest data (Data/QuestRewards.lua, QuestieDB Forever): parsed per quest on first use
local SIDE = { Alliance = "A", Horde = "H" }
local questCache = {}
local function split(str, sep, out)
  for v in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = v end
  return out
end
local function idList(str) local o = {}; for v in str:gmatch("%d+") do o[#o + 1] = tonumber(v) end return o end
function FLT.QuestInfo(qid)
  if not qid then return nil end
  local c = questCache[qid]
  if c ~= nil then return c or nil end
  local raw = FLT.QUEST_REWARDS and FLT.QUEST_REWARDS.quests[qid]
  if not raw then
    -- class quests (Data/ClassQuests.lua, 5.7.3): "name|requiredLevel|race mask|one|all|giver|map|x|y"
    raw = FLT.CLASS_QUESTS and FLT.CLASS_QUESTS.quests[qid]
    if not raw then questCache[qid] = false; return nil end
    local t = split(raw, "|", {})
    c = { id = qid, name = t[1], lvl = tonumber(t[2]), req = tonumber(t[2]), side = "", cls = 0, races = tonumber(t[3]) or 0,
      one = idList(t[4] or ""), all = idList(t[5] or ""), giver = t[6] ~= "" and t[6] or nil }
    local map = tonumber(t[7])
    if map then c.loc = { mapID = map, x = tonumber(t[8]), y = tonumber(t[9]) } end
    -- several givers: the one in your home zones (Veteran Uzzek: Sorek in Orgrimmar for orcs)
    if t[10] and t[10] ~= "" and not FLT.IsHomeQuest(c) then
      for name, m, x, y in t[10]:gmatch("([^;~]+);(%d+);([%d.]+);([%d.]+)") do
        local alt = { mapID = tonumber(m), x = tonumber(x), y = tonumber(y) }
        if FLT.IsHomeQuest({ loc = alt }) then c.giver, c.loc = name, alt; break end
      end
    end
    questCache[qid] = c
    return c
  end
  local t = split(raw, "|", {})
  c = { id = qid, name = t[1], lvl = tonumber(t[2]), req = tonumber(t[3]), side = t[4], cls = tonumber(t[5]) or 0,
    one = idList(t[6] or ""), all = idList(t[7] or ""), giver = t[8] ~= "" and t[8] or nil }
  local map = tonumber(t[9])
  if map then c.loc = { mapID = map, x = tonumber(t[10]), y = tonumber(t[11]) } end
  questCache[qid] = c
  return c
end
-- where a quest starts: our checked dungeon quest starts (Map.lua) first, else QuestieDB
function FLT.QuestStart(qid)
  local loc = FLT.QUEST_START_MAPS and FLT.QUEST_START_MAPS[qid]
  if loc then return loc end
  local q = FLT.QuestInfo(qid)
  if not (q and q.loc) then return nil end
  if not q.loc.label then
    local m = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(q.loc.mapID)
    q.loc.label = (q.giver or q.name) .. (m and m.name and (" - " .. m.name) or "")
    q.loc.name = q.loc.label
  end
  return q.loc
end
-- the chain up to a quest, first step first; a step = list of quest IDs (more than one = any of them)
-- race variants of class quests (same quest in several cities): only those of your race, when there are any
local raceBit
function FLT.QuestForMyRace(q)
  if not (q and q.races and q.races > 0) then return true end
  if raceBit == nil then
    local id = UnitRace and select(3, UnitRace("player"))
    raceBit = id and 2 ^ (id - 1) or false
  end
  return not raceBit or math.floor(q.races / raceBit) % 2 == 1
end
-- the home zones (start zone + capital, uiMapIDs) per race: of several variants of a step the one that starts there
-- comes first (class quests: Voidwalker in Durotar for orcs, Tirisfal for the undead)
FLT.HOME_MAPS = { [1] = { [1429] = 1, [1453] = 1 }, [2] = { [1411] = 1, [1454] = 1 }, [3] = { [1426] = 1, [1455] = 1 },
  [4] = { [1438] = 1, [1457] = 1 }, [5] = { [1420] = 1, [1458] = 1 }, [6] = { [1412] = 1, [1456] = 1 },
  [7] = { [1426] = 1, [1455] = 1 }, [8] = { [1411] = 1, [1454] = 1 } }
function FLT.IsHomeQuest(q, home)
  if home == nil then local id = UnitRace and select(3, UnitRace("player")); home = id and FLT.HOME_MAPS[id] end
  return home and q and q.loc and home[q.loc.mapID] and true or false
end
function FLT.QuestChain(qid, home) -- home: FLT.HOME_MAPS entry (default: your race)
  local steps, seen = {}, {}
  local function walk(ids, depth)
    if #ids > 1 then
      local mine = {}
      for _, id in ipairs(ids) do if FLT.QuestForMyRace(FLT.QuestInfo(id)) then mine[#mine + 1] = id end end
      if #mine > 0 then ids = mine end
      for i = 2, #ids do
        if FLT.IsHomeQuest(FLT.QuestInfo(ids[i]), home) then ids = { ids[i], unpack(ids) }; table.remove(ids, i + 1); break end
      end
    end
    if seen[ids[1]] or depth > 30 then return end
    for _, id in ipairs(ids) do seen[id] = true end
    local q = FLT.QuestInfo(ids[1])
    if q then
      for _, p in ipairs(q.all) do walk({ p }, depth + 1) end
      if #q.one > 0 then walk(q.one, depth + 1) end
    end
    steps[#steps + 1] = ids
  end
  walk({ qid }, 0)
  return steps
end
local function buildIndex()
  index, byId = {}, {}
  if not GetItemInfoInstant then return end
  for _, d in ipairs(FLT.DUNGEONS or {}) do
    local where = d.short or d.name
    for _, b in ipairs(d.bosses or {}) do
      for _, it in ipairs(b.loot or {}) do
        local e = add(it.id, it.name, it.quality, where .. " - " .. b.name, d.minLevel, d)
        if e then e.boss = b.name end
      end
    end
    for _, it in ipairs(d.trashLoot or {}) do local e = add(it.id, it.name, it.quality, where .. " - trash", d.minLevel, d); if e then e.boss = "trash mobs" end end
    for _, qu in ipairs(d.quests or {}) do
      for _, it in ipairs(qu.rewards or {}) do
        local e = add(it.id, it.name, it.quality, "Quest: " .. (qu.name or "?"), qu.level)
        if e then e.qid = qu.id; e.side = SIDE[qu.side] end
      end
    end
  end
  for _, s in ipairs(FLT.ARMORY_SETS or {}) do
    if s.st ~= 0 then
      for _, it in ipairs(s.i or {}) do add(it[1], it[2], it[4], (type(it[6]) == "table" and it[6][1]) or s.n, s.lv) end
    end
  end
  local RANK = { [4] = "Friendly", [5] = "Honored", [6] = "Revered", [7] = "Exalted" }
  for _, f in ipairs(FLT.ARMORY_REPUTATION or {}) do
    if f.st ~= 0 then
      for _, it in ipairs(f.i or {}) do
        if it[7] == "gear" then add(it[1], it[2], it[4], f.n .. (RANK[it[6]] and (" (" .. RANK[it[6]] .. ")") or ""), nil) end
      end
    end
  end
  -- quest rewards outside our dungeon data (QuestieDB Forever); with several quests the one of our faction
  local QR = FLT.QUEST_REWARDS
  if QR then
    local fac = UnitFactionGroup and SIDE[UnitFactionGroup("player")]
    for id, req, qs, name in QR.items:gmatch("(%d+),(%d+),([%d/]+),([^\n]*)") do
      local pick
      for q in qs:gmatch("%d+") do
        local info = FLT.QuestInfo(tonumber(q))
        if info and (not pick or (info.side == fac and pick.side ~= fac)) then pick = info end
      end
      if pick then
        req = tonumber(req)
        local e = add(tonumber(id), name, nil, "Quest: " .. pick.name, req > 0 and req or pick.req)
        if e then
          e.qid, e.side, e.cls = pick.id, pick.side, pick.cls; if req > 0 then e.req = req end
          -- the level you can take the quest at: a reward without its own required level must not show earlier
          -- (6.0.2, user 31.10.)
          if (pick.req or 0) > 0 then e.qreq = pick.req end
        end
      end
    end
  end
  for prof, list in pairs(FLT.PROFESSION_RECIPES or {}) do
    -- level ~ skill / 5 (300 skill ~ level 60), only used to skip items far above the level limit
    for _, r in ipairs(list) do
      local sk = r.req or r.y
      if r.i then
        local e = add(r.i, r.n, r.q, prof .. (sk and (" " .. sk) or ""), sk and math.floor(sk / 5) or nil)
        if e then e.prof, e.ps = prof, r.s end -- the profession button opens this recipe (6.0.2, user 31.10.)
      end
    end
  end
end
FLT.GearIndex = function(rebuild) if rebuild or not index then buildIndex() end return index, byId end

-- required level / item level: from the game when it has the item, else the source level
local function reqLevel(e)
  local name, _, q, ilvl, minLevel = GetItemInfo(e.id)
  if name then e.name, e.q, e.ilvl, e.req = name, q or e.q, ilvl, minLevel end
  return e.req or e.lvl or 0
end

-- Wishlist (per character) ----------------------------------------------------------
local function wishlist()
  if type(OneForAllCharDB) ~= "table" then return {} end
  OneForAllCharDB.wishlist = OneForAllCharDB.wishlist or {}
  return OneForAllCharDB.wishlist
end
function FLT.IsOnWishlist(id) return id and wishlist()[id] and true or false end
function FLT.ToggleWishlist(id)
  local w = wishlist()
  if w[id] then w[id] = nil else w[id] = true end
  return w[id] and true or false
end

-- Wishlist star, shared by the planner list and the dungeon loot / quest reward rows (user 16.10.).
-- UI.WishStar(parent) -> button; star:SetItem(id) shows it for gear only and paints it; star.onToggle optional
local function paintWishStar(b)
  if FLT.IsOnWishlist(b.id) then b.tex:SetVertexColor(FLT.SkinC(1, 0.82, 0.25)); b.tex:SetAlpha(1)
  else b.tex:SetVertexColor(0.6, 0.6, 0.6); b.tex:SetAlpha(0.5) end
end
function FLT.IsGearItem(id)
  local loc = id and GetItemInfoInstant and select(4, GetItemInfoInstant(id))
  return loc and LOC_SLOTS[loc] and not SKIP_LOC[loc] and true or false
end
function UI.WishStar(parent)
  local b = CreateFrame("Button", nil, parent); b:SetSize(22, 22)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); FLT.SetTex(b.tex, UI.ASSET_ROOT .. "icon_star")
  local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); FLT.SetTex(hl, UI.ASSET_ROOT .. "icon_star"); hl:SetBlendMode("ADD"); hl:SetAlpha(0.35)
  b:SetScript("OnClick", function(self)
    FLT.ToggleWishlist(self.id); paintWishStar(self)
    if self.onToggle then self.onToggle() end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(FLT.IsOnWishlist(self.id) and "Remove from wishlist" or "Add to wishlist")
    GameTooltip:AddLine("The wishlist is in Armory > Gear Planner.", 0.8, 0.8, 0.8, true); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function b:SetItem(id) self.id = id; self:SetShown(FLT.IsGearItem(id)); if self:IsShown() then paintWishStar(self) end end
  function b:SetKey(key) self.id = key; self:Show(); paintWishStar(self) end -- not an item: enchant wishes ("ench:...")
  return b
end

local MAX_LEVEL = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60

-- Quest chain popup ------------------------------------------------------------------
-- every step of the chain up to a reward: green = done, yellow = in the quest log, Map = its quest giver
local chainPopup
local function questInLog(id)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return (C_QuestLog.GetLogIndexForQuestID(id) or 0) > 0 end
  if GetQuestLogIndexByID then return (GetQuestLogIndexByID(id) or 0) > 0 end
  return false
end
function FLT.ShowQuestChain(qid)
  if not qid then return end
  local p = chainPopup
  if not p then
    p = CreateFrame("Frame", "OneForAllQuestChain", UIParent); chainPopup = p
    p:SetSize(460, 200); p:SetPoint("CENTER", 0, 60)
    p:SetFrameStrata("DIALOG"); p:SetToplevel(true); p:EnableMouse(true); p:SetClampedToScreen(true)
    p:SetMovable(true); p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p._ofaNoBG = true
    UI.FramedPanel(p)
    for _, t in ipairs(UI.OrnateFrame(p, p, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    p.title = FLT.NewFS(p, nil, "OVERLAY", "GameFontNormalLarge"); p.title:SetPoint("TOPLEFT", 18, -16); p.title:SetPoint("RIGHT", -44, 0)
    p.title:SetJustifyH("LEFT"); p.title:SetWordWrap(false); p.title:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
    p.sub = FLT.NewFS(p, nil, "OVERLAY", "GameFontHighlightSmall"); p.sub:SetPoint("TOPLEFT", 18, -38)
    p.sub:SetText("Quest chain - green: done, yellow: in your quest log"); p.sub:SetTextColor(FLT.SkinC(0.80, 0.77, 0.70))
    UI.CloseButton(p):SetPoint("TOPRIGHT", -12, -12)
    local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate"))
    sf:SetPoint("TOPLEFT", 14, -62); sf:SetPoint("BOTTOMRIGHT", -32, 16)
    p.child = CreateFrame("Frame", nil, sf); p.child:SetSize(410, 1); sf:SetScrollChild(p.child)
    UI.AutoHideScrollBar(sf)
    p.rows = {}
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllQuestChain") end
  end
  local steps = FLT.QuestChain(qid)
  local last = FLT.QuestInfo(qid)
  p.title:SetText(last and last.name or ("Quest " .. qid))
  for _, r in ipairs(p.rows) do r:Hide() end
  local y = 0
  for i, ids in ipairs(steps) do
    local r = p.rows[i]
    if not r then
      r = CreateFrame("Frame", nil, p.child); r:SetSize(410, 40)
      r.card = UI.Card(r, r, 4, {0.28, 0.25, 0.20, 0.90}, {0.055, 0.067, 0.080, 0.90}, "BACKGROUND", 0)
      r.name = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("TOPLEFT", 10, -5); r.name:SetPoint("RIGHT", -74, 0)
      r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
      r.sub = FLT.NewFS(r, nil, "OVERLAY", "GameFontDisableSmall"); r.sub:SetPoint("TOPLEFT", 10, -22); r.sub:SetPoint("RIGHT", -74, 0)
      r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
      r.map = UI.GoldButton(r, "Map", 56, 20, UI.ASSET_ROOT .. "icon_map", 11); r.map:SetPoint("RIGHT", -8, 0)
      r.map:SetScript("OnClick", function(self) if self.loc then FLT:ShowOnMap(self.loc) end end)
      r.map:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Quest giver", 1, 0.82, 0)
        GameTooltip:AddLine(self.loc and self.loc.label or "", 1, 1, 1, true); GameTooltip:Show()
      end)
      r.map:SetScript("OnLeave", function() GameTooltip:Hide() end)
      p.rows[i] = r
    end
    r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 44
    -- a step with several quests: any one of them (breadcrumbs, faction variants); the done / in-log one counts
    local show, state = ids[1], nil
    for _, id in ipairs(ids) do
      if FLT:IsQuestDone(id) then show, state = id, "done"; break end
      if not state and questInLog(id) then show, state = id, "log" end
    end
    local q = FLT.QuestInfo(show)
    local name = q and q.name or ("Quest " .. show)
    r.name:SetText(i .. ".  " .. name)
    local parts = {}
    if q and q.lvl and q.lvl > 0 then parts[#parts + 1] = "Level " .. q.lvl end
    if q and q.giver then parts[#parts + 1] = q.giver end
    if #ids > 1 then parts[#parts + 1] = "or one of " .. (#ids - 1) .. " other" .. (#ids > 2 and "s" or "") end
    r.sub:SetText(table.concat(parts, "  ·  "))
    if state == "done" then r.card:SetFill(FLT.SkinC(0.035, 0.16, 0.055, 0.90)); r.name:SetTextColor(FLT.SkinC(0.35, 1, 0.45))
    elseif state == "log" then r.card:SetFill(FLT.SkinC(0.22, 0.17, 0.04, 0.92)); r.name:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
    else r.card:SetFill(FLT.SkinC(0.055, 0.067, 0.080, 0.90)); r.name:SetTextColor(FLT.SkinC(0.92, 0.90, 0.84)) end
    r.map.loc = FLT.QuestStart(show)
    r.map:SetShown(r.map.loc and true or false)
  end
  p.child:SetHeight(math.max(1, -y))
  p:SetHeight(math.min(520, -y + 82))
  p:Show(); p:Raise()
end

-- The view --------------------------------------------------------------------------
function UI.CreateGearPlanner(parent)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local prefs = (type(OneForAllCharDB) == "table") and OneForAllCharDB or {}
  local selected = 1 -- inventory slot
  local enchMode = false -- the right side shows the enchants of the selected slot
  local tab = "suggest"
  local search = ""

  local function newText(p, template, w, color)
    local fs = FLT.NewFS(p, nil, "OVERLAY", template or "GameFontHighlightSmall")
    if w then fs:SetWidth(w) end
    fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
    if color then fs:SetTextColor(FLT.SkinC(unpack(color))) end
    return fs
  end
  local function qcolor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return unpack(TEXT)
  end

  -- LEFT: character panel ------------------------------------------------------------
  -- fixed size (user 16.10.): a taller window must not stretch the character, the slots or the weapons;
  -- 481 = the Armory body at the base window height
  local left = CreateFrame("Frame", nil, f); left:SetPoint("TOPLEFT"); left:SetSize(350, 481)
  UI.Column(left, 4) -- ht3: no frame, a line to the right
  local refreshList -- forward
  -- name and level, then the spec the Value is for as a drop-down (default: the active spec, user 18.10.)
  local head = CreateFrame("Frame", nil, left); head:SetSize(330, 20); head:SetPoint("TOP", 0, -10)
  local who = newText(head, "GameFontNormal", nil, GOLD); who:SetPoint("LEFT")
  local specBtn = CreateFrame("Button", nil, head); specBtn:SetHeight(20); specBtn:SetPoint("LEFT", who, "RIGHT", 2, 0)
  specBtn.text = newText(specBtn, "GameFontNormal"); specBtn.text:SetPoint("LEFT"); specBtn.text:SetTextColor(0.69, 0.69, 0.69)
  specBtn.arrow = specBtn:CreateTexture(nil, "ARTWORK"); specBtn.arrow:SetSize(12, 12); specBtn.arrow:SetPoint("LEFT", specBtn.text, "RIGHT", 4, 0)
  FLT.SetTex(specBtn.arrow, UI.ASSET_ROOT .. "chevron"); specBtn.arrow:SetTexCoord(0, 0.5, 0, 1)
  local shl = UI.makeTexture(specBtn, "HIGHLIGHT", 1, 0.82, 0.3, 0.10); shl:SetAllPoints()
  specBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Spec for the Value", 1, 0.82, 0)
    GameTooltip:AddLine("The stat weights of this spec are used for the upgrades here, in tooltips, bags and loot rolls. \"Active spec\" follows your talents. \"Edit custom weights...\" sets your own weights.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local refreshSlots -- forward
  local function afterWeights() refreshSlots(); f.paintSlots(); refreshList() end
  specBtn:SetScript("OnClick", function(self)
    local GV = FLT.GearValue; if not GV then return end
    local specs, pick, auto = GV.Specs()
    local opts = { { key = 0, label = "Active spec" .. (auto and specs[auto] and ("  |cffb0b0b0(" .. specs[auto].name .. ")|r") or "") } }
    for i, sp in ipairs(specs) do opts[#opts + 1] = { key = i, label = sp.name } end
    -- own weights (5.7.3, Discord sparkledooks, user 27.10.)
    opts[#opts + 1] = { key = "custom", label = "Custom weights" }
    opts[#opts + 1] = { key = "edit", label = "|cffd9a63aEdit custom weights...|r" }
    UI.OpenDropDown(self, opts, pick or 0, function(k)
      if k == "edit" then
        GV.SetSpec("custom"); afterWeights()
        if UI.ShowWeightEditor then UI.ShowWeightEditor(afterWeights) end
        return
      end
      GV.SetSpec(k ~= 0 and k or nil)
      afterWeights()
    end, 220)
  end)
  -- DressUpModel: right-click an item in the list to try it on (user 16.10.); the model is only (re)loaded
  -- when the planner opens, the gear changes or "Reset" is clicked - reloading it on every list redraw
  -- made it flicker (beta3)
  -- the client's picture of your race behind the character, over the whole panel (6.0.1, user 30.10.); 3 px in, so its
  -- square corners stay inside the panel's rounded line
  local bgClip = UI.RaceBackdrop(left, 3, -3, -3, 3)
  local model = CreateFrame("DressUpModel", nil, left)
  model:SetPoint("TOPLEFT", 58, -40); model:SetPoint("BOTTOMRIGHT", -58, 60)
  -- mouse wheel zooms, dragging turns the character; the OnUpdate only runs while the button is held
  local zoom = 0
  local function loadModel()
    if model.SetUnit then pcall(model.SetUnit, model, "player") end
    zoom = 0; if model.SetPortraitZoom then model:SetPortraitZoom(0) end
    if model.SetFacing then model:SetFacing(0) end
  end
  model:EnableMouse(true); model:EnableMouseWheel(true)
  model:SetScript("OnMouseWheel", function(self, delta)
    zoom = math.max(0, math.min(0.9, zoom + delta * 0.1))
    if self.SetPortraitZoom then self:SetPortraitZoom(zoom) end
  end)
  local function dragUpdate(self)
    local x = GetCursorPosition()
    self:SetFacing(self.dragFacing + (x - self.dragX) / (80 * self:GetEffectiveScale()))
  end
  model:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" or not self.GetFacing then return end
    self.dragX = GetCursorPosition(); self.dragFacing = self:GetFacing() or 0
    self:SetScript("OnUpdate", dragUpdate)
  end)
  local function stopDrag(self) self:SetScript("OnUpdate", nil) end
  model:SetScript("OnMouseUp", stopDrag); model:SetScript("OnHide", stopDrag)
  local reset = UI.GoldButton(left, "Reset", 60, 20, nil, 11); reset:SetPoint("BOTTOMRIGHT", -10, 10) -- in the frame's corner (user 16.10.)
  reset:SetScript("OnClick", loadModel)
  reset:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Reset"); GameTooltip:AddLine("Shows your own gear again. Right-click an item in the list to try it on, scroll on the character to zoom, drag it to turn it.", 1, 1, 1, true); GameTooltip:Show() end)
  reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.tryOn = function(id) if model.TryOn then pcall(model.TryOn, model, "item:" .. id) end end
  local slotButtons = {}
  local function slotButton(s, x, y, anchor)
    local b = CreateFrame("Button", nil, left); b:SetSize(38, 38); b:SetPoint(anchor, x, y)
    -- rounded card as the frame (the client's square icon frame was cut off on the right, beta3)
    b.card = UI.Card(b, b, 4, {0.28, 0.25, 0.20, 0.90}, {0.05, 0.05, 0.06, 0.95}, "BACKGROUND", 0)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetPoint("TOPLEFT", 3, -3); hl:SetPoint("BOTTOMRIGHT", -3, 3); hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hl:SetBlendMode("ADD")
    b.slot, b.slotName, b.grey = s[1], s[2], s[4]
    if b.grey then b:SetAlpha(0.45) end
    b:SetScript("OnClick", function(self)
      if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        local link = GetInventoryItemLink("player", self.slot); if link then HandleModifiedItemClick(link) end; return
      end
      if self.grey then return end
      selected = self.slot; enchMode = false; search = ""; prefs.wishAll = nil; -- a slot click shows that slot again
      if f.searchBox then f.searchBox:SetText("") end
      f.paintSlots()
      refreshList()
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip.ofaNoCompare = true -- your own gear: no comparison tooltip (UI/DungeonHelpers.lua, user 31.10.)
      if not GameTooltip:SetInventoryItem("player", self.slot) then GameTooltip:SetText(SLOT_NAME[self.slot] or "") end
      GameTooltip:Show()
      if type(ShoppingTooltip1) == "table" then ShoppingTooltip1:Hide() end
      if type(ShoppingTooltip2) == "table" then ShoppingTooltip2:Hide() end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slotButtons[#slotButtons + 1] = b
    return b
  end
  for i = 1, 8 do slotButton(SLOTS[i], 12, -40 - (i - 1) * 46, "TOPLEFT") end
  for i = 9, 16 do slotButton(SLOTS[i], -12, -40 - (i - 9) * 46, "TOPRIGHT") end
  for i = 17, 19 do slotButton(SLOTS[i], (i - 18) * 46, 14, "BOTTOM") end
  -- small field next to each slot whose item can get an enchant / kit / spurs ...; shows what is on it,
  -- a click lists what fits on the right (user 22.10.)
  for _, b in ipairs(slotButtons) do
    if not b.grey then
      local e = CreateFrame("Button", nil, left); e:SetSize(19, 19); e:Hide()
      -- above the character model, which reaches over the fields and took their clicks (beta9, user 22.10.)
      e:SetFrameLevel((model:GetFrameLevel() or 1) + 5)
      local _, _, _, x = b:GetPoint(1)
      if b.slot >= 16 then e:SetPoint("BOTTOM", b, "TOP", 0, 3)
      elseif (x or 0) > 0 then e:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 3, 0)
      else e:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -3, 0) end
      e.card = UI.Card(e, e, 3, {0.28, 0.25, 0.20, 0.90}, {0.05, 0.05, 0.06, 0.95}, "BACKGROUND", 0)
      e.icon = e:CreateTexture(nil, "ARTWORK"); e.icon:SetPoint("TOPLEFT", 2, -2); e.icon:SetPoint("BOTTOMRIGHT", -2, 2)
      e.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      e.plus = FLT.NewFS(e, nil, "OVERLAY", "GameFontNormalSmall"); e.plus:SetPoint("CENTER", 0, 1); e.plus:SetText("+")
      e.plus:SetTextColor(FLT.SkinC(0.80, 0.62, 0.28))
      local hl = e:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(e.icon); hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hl:SetBlendMode("ADD")
      e.slot = b.slot
      e:SetScript("OnClick", function(self)
        selected = self.slot; enchMode = true; search = ""; if f.searchBox then f.searchBox:SetText("") end
        f.paintSlots(); refreshList()
      end)
      e:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local cur = wornEnchant(self.slot)
        local ce = cur and FLT.ENCHANTS and FLT.ENCHANTS[cur]
        GameTooltip:AddLine(cur and (ce and ce[1] or "Enchanted") or "Not enchanted", 1, 0.82, 0)
        GameTooltip:AddLine("Click: what you can put on this item (enchants, armor kits and the like).", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      e:SetScript("OnLeave", function() GameTooltip:Hide() end)
      b.ench = e
    end
  end

  -- border: gold for the selected slot, else the item quality
  function f.paintSlots()
    for _, b in ipairs(slotButtons) do
      if b.ench then
        if enchMode and b.slot == selected then b.ench.card:SetBorder(FLT.SkinC(1, 0.82, 0.25, 1))
        else b.ench.card:SetBorder(0.28, 0.25, 0.20, 0.90) end
      end
      if b.slot == selected and not enchMode then b.card:SetBorder(FLT.SkinC(1, 0.82, 0.25, 1))
      elseif b.q and b.q >= 1 then local r, g, bl = qcolor(b.q); b.card:SetBorder(r, g, bl, 1)
      else b.card:SetBorder(0.28, 0.25, 0.20, 0.90) end
    end
  end
  refreshSlots = function()
    local name = UnitName and UnitName("player") or ""
    local lvl = UnitLevel and UnitLevel("player") or 0
    local _, cls = UnitClass("player")
    -- the spec the Value is for (talent tree with the most points)
    local spec = FLT.GearValue and FLT.GearValue.SpecName()
    who:SetText(string.format("%s  |cffb0b0b0Level %d%s|r", name, lvl, spec and "  ·" or ""))
    specBtn.text:SetText(spec or ""); specBtn:SetShown(spec ~= nil)
    specBtn:SetWidth((specBtn.text:GetStringWidth() or 60) + 18)
    -- centre name + spec together
    head:SetWidth((who:GetStringWidth() or 100) + 2 + specBtn:GetWidth())
    for _, b in ipairs(slotButtons) do
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", b.slot)
      if not tex and GetInventorySlotInfo then local _, empty = GetInventorySlotInfo(b.slotName); tex = empty end
      b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
      b.q = GetInventoryItemQuality and GetInventoryItemQuality("player", b.slot)
      if b.ench then
        local id = GetInventoryItemID and GetInventoryItemID("player", b.slot)
        local opts = id and enchantOptions(id)
        b.ench:SetShown(opts and #opts > 0 or false)
        if b.ench:IsShown() then
          local cur = wornEnchant(b.slot)
          local icon
          if cur then for _, o in ipairs(opts) do if o.e == cur then icon = enchantIcon(o); break end end end
          if cur then b.ench.icon:SetTexture(icon or "Interface\\Icons\\Trade_Engraving") end
          b.ench.icon:SetShown(cur ~= nil); b.ench.plus:SetShown(cur == nil)
        end
      end
    end
    -- the item with the enchant field was taken off: back to the item list
    if enchMode then
      for _, b in ipairs(slotButtons) do if b.slot == selected and not (b.ench and b.ench:IsShown()) then enchMode = false end end
    end
    f.paintSlots()
    f.class = cls
    local classID = select(3, UnitClass("player"))
    myClassBit = classID and 2 ^ (classID - 1)
    mySide = UnitFactionGroup and SIDE[UnitFactionGroup("player")]
  end

  -- everything else of the character panel stays above the picture
  do
    local lv = bgClip:GetFrameLevel() + 2
    for _, c in ipairs({ left:GetChildren() }) do
      if c ~= bgClip and (c:GetFrameLevel() or 0) < lv then c:SetFrameLevel(lv) end
    end
  end

  -- RIGHT: tabs, search, list ------------------------------------------------------
  local right = CreateFrame("Frame", nil, f); right:SetPoint("TOPLEFT", 358, 0); right:SetPoint("BOTTOMRIGHT")
  local tabs = {}
  local function tabButton(key, label, x)
    local b = UI.GoldButton(right, label, 92, 26); b:SetPoint("TOPLEFT", x, -10)
    b:SetScript("OnClick", function() tab = key; for k, o in pairs(tabs) do o:SetActive(k == tab) end; refreshList() end)
    tabs[key] = b
  end
  tabButton("suggest", "Suggested", 12)
  tabButton("wish", "Wishlist", 108)
  tabs.suggest:SetActive(true)
  -- what the suggestions are (and are not), user 16.10.
  local warn = CreateFrame("Frame", nil, right); warn:SetSize(22, 22); warn:SetPoint("LEFT", tabs.wish, "RIGHT", 8, 0)
  local wt = warn:CreateTexture(nil, "ARTWORK"); wt:SetAllPoints(); FLT.SetTex(wt, UI.ASSET_ROOT .. "icon_warning")
  warn:EnableMouse(true)
  warn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Suggestions only", 1, 0.82, 0)
    GameTooltip:AddLine("No BiS list or simulated values. Only suggestions based on weighted stats for your talent spec.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  warn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- source filter (5.7.3, user 23.10.; several at once + Crafted since 6.0.2, user 31.10.): prefs.gearSources =
  -- { boe = true, quest = true, ... }, empty / nil = all sources. BoE comes from the client's item data (bind type 2),
  -- so an item counts once it is loaded. The button sits right of "All" (placed below, after the level row).
  local SOURCES = { { key = "boe", label = "Bind on Equip" }, { key = "quest", label = "Quest rewards" },
    { key = "dungeon", label = "Dungeon drops" }, { key = "raid", label = "Raid drops" }, { key = "crafted", label = "Crafted" } }
  local SOURCE_SHORT = { boe = "BoE", quest = "Quests", dungeon = "Dungeons", raid = "Raids", crafted = "Crafted" }
  if prefs.gearSource then prefs.gearSources = { [prefs.gearSource] = true }; prefs.gearSource = nil end -- old single choice
  local function picked() local t = prefs.gearSources; return t and next(t) and t or nil end
  local srcBtn = CreateFrame("Button", nil, right); srcBtn:SetSize(22, 22)
  srcBtn.tex = srcBtn:CreateTexture(nil, "ARTWORK"); srcBtn.tex:SetAllPoints(); FLT.SetTex(srcBtn.tex, UI.ASSET_ROOT .. "icon_filter")
  local shl2 = UI.makeTexture(srcBtn, "HIGHLIGHT", 1, 0.82, 0.3, 0.12); shl2:SetAllPoints()
  local function paintSource() srcBtn.tex:SetAlpha(picked() and 1 or 0.5) end
  local function shortNames()
    local t = picked(); if not t then return nil end
    local out = {}
    for _, o in ipairs(SOURCES) do if t[o.key] then out[#out + 1] = SOURCE_SHORT[o.key] end end
    return table.concat(out, ", ")
  end
  srcBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Source filter", 1, 0.82, 0)
    GameTooltip:AddLine(shortNames() or "All sources", 1, 1, 1)
    GameTooltip:AddLine("Pick one or more. Bind on Equip: items you can buy in the auction house. Crafted: your own professions with everything, other professions only Bind on Equip.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  srcBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local function openSources(self)
    local t = picked() or {}
    local opts = { { key = "all", label = "All sources", checked = next(t) == nil } }
    for _, o in ipairs(SOURCES) do opts[#opts + 1] = { key = o.key, label = o.label, checked = t[o.key] and true or false } end
    UI.OpenDropDown(self, opts, nil, function(k)
      if k == "all" then prefs.gearSources = nil
      else prefs.gearSources = prefs.gearSources or {}; prefs.gearSources[k] = not prefs.gearSources[k] or nil end
      paintSource(); refreshList()
      openSources(self) -- stays open for more picks; a click outside closes it
    end, 180)
  end
  srcBtn:SetScript("OnClick", openSources)
  paintSource()
  -- your professions (crafted items: Bind on Pickup only from your own, user 31.10.)
  local myProfs = {}
  local function readProfessions()
    wipe(myProfs)
    local p = type(OneForAllCharDB) == "table" and OneForAllCharDB.professions
    if type(p) == "table" then for name in pairs(p) do myProfs[name] = true end end
    if GetNumSkillLines and GetSkillLineInfo then
      for i = 1, tonumber(GetNumSkillLines()) or 0 do
        local name = GetSkillLineInfo(i)
        if name and FLT.PROFESSION_ICONS and FLT.PROFESSION_ICONS[name] then myProfs[name] = true end
      end
    end
  end
  -- a crafted item you could never get: Bind on Pickup from a profession you do not have
  local function craftedReachable(e)
    if not e.prof or myProfs[e.prof] then return true end
    return select(14, GetItemInfo(e.id)) ~= 1
  end
  local function sourceOK(e)
    if not craftedReachable(e) then return false end
    local t = picked()
    if not t then return true end
    if t.quest and e.qid ~= nil then return true end
    if t.dungeon and e.d ~= nil and not e.qid and not e.d.raid then return true end
    if t.raid and e.d ~= nil and not e.qid and e.d.raid then return true end
    if t.crafted and e.prof and not e.d and not e.qid then return true end
    if t.boe and select(14, GetItemInfo(e.id)) == 2 then return true end
    return false
  end

  local box = FLT.SkinBlizz(CreateFrame("EditBox", nil, right, "InputBoxTemplate"))
  -- search and the level row end flush with the list below (right edge -32, user 16.10.)
  box:SetHeight(20); box:SetPoint("TOPLEFT", 262, -13); box:SetPoint("TOPRIGHT", -32, -13); box:SetAutoFocus(false)
  if box.SetTextInsets then box:SetTextInsets(0, 22, 0, 0) end
  local hint = FLT.NewFS(box, nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("LEFT", 4, 0); hint:SetText("Search all items...")
  local clear = UI.GoldButton(right, "X", 20, 18, nil, 10); clear:SetPoint("RIGHT", box, "RIGHT", -1, 0); clear:Hide()
  clear:SetFrameLevel(box:GetFrameLevel() + 2)
  clear:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self)
    search = (self:GetText() or ""):lower(); hint:SetShown(search == ""); clear:SetShown(search ~= ""); refreshList()
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f.searchBox = box

  local title = newText(right, "GameFontNormal", 170, GOLD); title:SetPoint("TOPLEFT", 16, -48)
  if title.SetWordWrap then title:SetWordWrap(false) end
  -- mouseover: what the list shows and every chosen source (the line itself may be cut off)
  local titleHover = CreateFrame("Frame", nil, right); titleHover:SetAllPoints(title); titleHover:EnableMouse(true)
  titleHover:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(self.head or "", 1, 0.82, 0)
    GameTooltip:AddLine("Sources: " .. (self.sources or "all"), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  titleHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- level range (user 16.10.): two boxes plus "My lvl" (1 - own level, follows when you level up) and
  -- "All"; prefs.gearMax nil = own level
  prefs.gearLevel = nil -- the old dropdown (beta1-4)
  local function playerLevel() return UnitLevel and UnitLevel("player") or MAX_LEVEL end
  local function range()
    local lo, hi = prefs.gearMin or 1, prefs.gearMax or playerLevel()
    return lo, hi
  end
  local allBtn = UI.GoldButton(right, "All", 40, 22, nil, 11); allBtn:SetPoint("TOPRIGHT", -32, -44)
  local mineBtn = UI.GoldButton(right, "My lvl", 56, 22, nil, 11); mineBtn:SetPoint("RIGHT", allBtn, "LEFT", -4, 0)
  srcBtn:SetPoint("LEFT", allBtn, "RIGHT", 6, 0) -- the source filter: right of "All" (user 31.10.)
  local function levelBox()
    local b = FLT.SkinBlizz(CreateFrame("EditBox", nil, right, "InputBoxTemplate"))
    b:SetSize(26, 20); b:SetAutoFocus(false); b:SetNumeric(true); b:SetMaxLetters(2); b:SetJustifyH("CENTER")
    return b
  end
  local maxBox = levelBox(); maxBox:SetPoint("RIGHT", mineBtn, "LEFT", -10, 0)
  local dash = newText(right, "GameFontHighlightSmall"); dash:SetPoint("RIGHT", maxBox, "LEFT", -8, 0); dash:SetText("-")
  local minBox = levelBox(); minBox:SetPoint("RIGHT", dash, "LEFT", -6, 0)
  local lvLabel = newText(right, "GameFontNormalSmall", nil, GOLD); lvLabel:SetPoint("RIGHT", minBox, "LEFT", -8, 0); lvLabel:SetText("Level")
  local function setRange(lo, hi)
    lo = math.max(1, math.min(MAX_LEVEL, lo or 1))
    if hi then hi = math.max(1, math.min(MAX_LEVEL, hi)) end
    if hi and lo > hi then lo, hi = hi, lo end
    prefs.gearMin = lo > 1 and lo or nil; prefs.gearMax = hi
    refreshList()
  end
  local function readBoxes()
    local lo, hi = range()
    setRange(tonumber(minBox:GetText()) or lo, tonumber(maxBox:GetText()) or hi)
  end
  for _, b in ipairs({ minBox, maxBox }) do
    b:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    b:SetScript("OnEditFocusLost", readBoxes)
  end
  mineBtn:SetScript("OnClick", function() minBox:ClearFocus(); maxBox:ClearFocus(); setRange(1, nil) end)
  allBtn:SetScript("OnClick", function() minBox:ClearFocus(); maxBox:ClearFocus(); setRange(1, MAX_LEVEL) end)
  -- the level range is for items; hidden while the enchants of a slot are listed
  local function showRange(on) for _, w in ipairs({ lvLabel, minBox, dash, maxBox, mineBtn, allBtn }) do w:SetShown(on) end end
  -- "Clear wishlist" (user 03.11.): where the level range is, on the Wishlist tab (the range does not filter the
  -- wishlist). Clear all, or clear smart = the items that are no upgrade any more; both ask first.
  local clearBtn = UI.GoldButton(right, "Clear wishlist", 116, 22, nil, 11); clearBtn:SetPoint("TOPRIGHT", -32, -44); clearBtn:Hide()
  do local nm = UI.NewMark(clearBtn, "New in OneForAll 6.1.0: clear the wishlist, all or only what is no upgrade any more."); nm:SetPoint("RIGHT", clearBtn, "LEFT", -4, 0) end
  -- "All slots" (user 03.11.): the whole wishlist at once instead of the selected slot
  local allSlotsBtn = UI.GoldButton(right, "All slots", 80, 22, nil, 11); allSlotsBtn:SetPoint("RIGHT", clearBtn, "LEFT", -22, 0); allSlotsBtn:Hide()
  allSlotsBtn:SetScript("OnClick", function() prefs.wishAll = not prefs.wishAll or nil; refreshList() end)
  allSlotsBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("All slots", 1, 0.82, 0)
    GameTooltip:AddLine("Shows the whole wishlist, sorted by slot. Click again for the selected slot only.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  allSlotsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local function noUpgrades()
    local out, GV = {}, FLT.GearValue
    for id in pairs(wishlist()) do
      if type(id) == "number" and GV and GV.Change then
        local kind = GV.Change(id)
        if kind == "down" or kind == "same" or kind == "worn" then out[#out + 1] = id end -- no data yet: kept
      end
    end
    return out
  end
  clearBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Clear wishlist", 1, 0.82, 0)
    GameTooltip:AddLine("Clear all: everything on the wishlist of this character (items and enchants).", 1, 1, 1, true)
    GameTooltip:AddLine("Clear smart: only the items that are no upgrade any more (the same or worse than what you wear, for your spec). Items without data yet and enchants stay.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  clearBtn:SetScript("OnClick", function(self)
    GameTooltip:Hide()
    local all = 0
    for _ in pairs(wishlist()) do all = all + 1 end
    local smart = noUpgrades()
    UI.OpenDropDown(self, { { key = "all", label = string.format("Clear all (%d)", all) },
      { key = "smart", label = string.format("Clear smart (%d)", #smart) } }, nil, function(k)
      UI.CloseDropDown()
      if k == "all" then
        if all == 0 then return end
        UI.Confirm(string.format("Remove all %d entries from the wishlist of this character?", all), function()
          wipe(wishlist()); refreshList()
        end, "Clear all")
      else
        if #smart == 0 then
          if FLT.Msg then FLT.Msg("Every item on your wishlist is still an upgrade (or has no data yet) - nothing to remove.") end
          return
        end
        UI.Confirm(string.format("Remove the %d %s from the wishlist that %s no upgrade any more?", #smart, #smart == 1 and "item" or "items", #smart == 1 and "is" or "are"), function()
          local w = wishlist(); for _, id in ipairs(smart) do w[id] = nil end; refreshList()
        end, "Clear smart")
      end
    end, 150)
  end)
  local function paintRange()
    local wish = tab == "wish" and search == ""
    clearBtn:SetShown(wish); allSlotsBtn:SetShown(wish); allSlotsBtn:SetActive(prefs.wishAll and true or false)
    if wish then showRange(false); return end
    showRange(true)
    local lo, hi = range()
    if not minBox:HasFocus() then minBox:SetText(lo) end
    if not maxBox:HasFocus() then maxBox:SetText(hi) end
    mineBtn:SetActive(lo == 1 and prefs.gearMax == nil)
    allBtn:SetActive(lo == 1 and hi >= MAX_LEVEL and prefs.gearMax ~= nil)
  end
  local line = UI.makeTexture(right, "ARTWORK", 0.72, 0.50, 0.12, 0.45); line:SetPoint("TOPLEFT", 12, -72); line:SetPoint("TOPRIGHT", -12, -72); line:SetHeight(1)

  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 12, -80); sf:SetPoint("BOTTOMRIGHT", -30, 10)
  -- rows follow the scroll area's width (fixed 480 was wider than the area and cut the cards off, beta4)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(400, 1); sf:SetScrollChild(child)
  sf:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then child:SetWidth(w) end end)
  UI.AutoHideScrollBar(sf)
  local empty = newText(right, "GameFontDisable", 380); empty:SetPoint("TOP", 0, -110); empty:SetJustifyH("CENTER"); empty:SetWordWrap(true)

  local rows = {}
  local function row(i)
    local r = rows[i]; if r then return r end
    r = CreateFrame("Button", nil, child); r:SetHeight(40)
    r.card = UI.CardRow(r)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(30, 30); r.icon:SetPoint("LEFT", 6, 0)
    r.star = UI.WishStar(r); r.star:SetPoint("RIGHT", -10, 0)
    r.star.onToggle = function() if tab == "wish" then refreshList() end end
    -- Map: dungeon loot = the entrance, quest rewards = the quest giver; Chain: the quest chain popup
    -- the map button is only its icon (little room, user 16.10.)
    -- quest giver map: only the map icon, no frame, a bit bigger (user 17.10.), like the dungeon swirl
    r.map = CreateFrame("Button", nil, r); r.map:SetSize(22, 22); r.map:SetPoint("RIGHT", r.star, "LEFT", -14, 0)
    local mt = r.map:CreateTexture(nil, "ARTWORK"); mt:SetAllPoints(); FLT.SetTex(mt, UI.ASSET_ROOT .. "icon_map")
    local mh = r.map:CreateTexture(nil, "HIGHLIGHT"); mh:SetAllPoints(); FLT.SetTex(mh, UI.ASSET_ROOT .. "icon_map"); mh:SetBlendMode("ADD"); mh:SetAlpha(0.4)
    r.map:SetScript("OnClick", function()
      local loc = r.e.qid and FLT.QuestStart(r.e.qid)
      if loc then FLT:ShowOnMap(loc) end
    end)
    r.map:SetScript("OnEnter", function(self)
      local loc = r.e.qid and FLT.QuestStart(r.e.qid)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Quest giver", 1, 0.82, 0); GameTooltip:AddLine(loc and loc.label or "", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    r.map:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- dungeon loot: the client's dungeon / raid swirl, no frame, star size (user 16.10.; an arrow looked like
    -- "add"), opens the boss (or trash) in Dungeons & Raids
    r.go = CreateFrame("Button", nil, r); r.go:SetSize(26, 26); r.go:SetPoint("RIGHT", r.star, "LEFT", -12, 0)
    r.go.tex = r.go:CreateTexture(nil, "ARTWORK"); r.go.tex:SetAllPoints()
    r.go.hl = r.go:CreateTexture(nil, "HIGHLIGHT"); r.go.hl:SetAllPoints(); r.go.hl:SetBlendMode("ADD"); r.go.hl:SetAlpha(0.4)
    r.go:SetScript("OnClick", function()
      local d = r.e.d
      if not d then return end
      FLT:OpenPanel("dungeons")
      if UI.OpenDungeon then UI.OpenDungeon(d, r.e.boss) end
    end)
    r.go:SetScript("OnEnter", function(self)
      local d = r.e.d; GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(d and d.name or "", 1, 0.82, 0)
      GameTooltip:AddLine("Open " .. (r.e.boss == "trash mobs" and "the trash loot" or (r.e.boss or "the dungeon")) .. " in Dungeons & Raids.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    r.go:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- crafted items: the profession's icon (star size, no frame like the dungeon swirl), opens the recipe in
    -- Professions (6.0.2, user 31.10.)
    r.pro = CreateFrame("Button", nil, r); r.pro:SetSize(24, 24); r.pro:SetPoint("RIGHT", r.star, "LEFT", -13, 0)
    r.pro.tex = r.pro:CreateTexture(nil, "ARTWORK"); r.pro.tex:SetAllPoints(); r.pro.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.pro:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    r.pro:SetScript("OnClick", function()
      local e = r.e; if not (e and e.prof) then return end
      FLT:OpenPanel("professions")
      if UI.EnsurePanel then UI.EnsurePanel("professions") end
      if FLT.ShowRecipeInProfessions then FLT.ShowRecipeInProfessions(e.prof, e.ps) end
    end)
    r.pro:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(r.e and r.e.prof or "", 1, 0.82, 0)
      GameTooltip:AddLine("Crafted item. Click to open the recipe in Professions (reagents, trainer, who can make it).", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    r.pro:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.chain = UI.GoldButton(r, "Chain", 56, 20, nil, 11); r.chain:SetPoint("RIGHT", r.star, "LEFT", -8, 0)
    r.chain:SetScript("OnClick", function() FLT.ShowQuestChain(r.e.qid) end)
    r.chain:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Quest chain", 1, 0.82, 0)
      GameTooltip:AddLine(self.steps .. " quests up to this reward. Click to see them all.", 1, 1, 1, true); GameTooltip:Show()
    end)
    r.chain:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.name = newText(r, "GameFontHighlight"); r.name:SetPoint("TOPLEFT", 44, -5)
    r.sub = newText(r, "GameFontHighlightSmall", nil, DIM); r.sub:SetPoint("TOPLEFT", 44, -22)
    -- Value change against the worn item (green better, red worse)
    r.val = newText(r, "GameFontNormal", 54); r.val:SetJustifyH("RIGHT")
    -- fixed columns (user 16.10.): star, a 56 px button place (Chain or the map icon, right-aligned), value
    r.val:SetPoint("RIGHT", r.star, "LEFT", -70, 0)
    r.name:SetPoint("RIGHT", r.val, "LEFT", -4, 0); r.sub:SetPoint("RIGHT", r.val, "LEFT", -4, 0)
    r.sub._ofaNoAnchor = true -- the tooltip goes right after the item name, not after the long source line (user 16.10.)
    r:SetScript("OnEnter", function(self)
      local e = self.e
      if H.tryShowItemTooltip and H.tryShowItemTooltip(self, { id = e.id, name = e.name, quality = e.q }) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if not pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. e.id) then GameTooltip:AddLine(e.name or ("Item " .. e.id)) end
      GameTooltip:Show()
    end)
    r:HookScript("OnEnter", function()
      if GameTooltip:IsShown() then GameTooltip:AddLine("Right-click: try it on", 0.4, 0.8, 1); GameTooltip:Show() end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- the part right of the % (buttons, star) is not the row: no item tooltip popping up on the way to the star
    -- (user 16.10.); the buttons there still work and have their own tooltips
    r:SetHitRectInsets(0, 100, 0, 0)
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" then f.tryOn(self.e.id); return end
      if H.handleDungeonItemClick then H.handleDungeonItemClick({ id = self.e.id, name = self.e.name, quality = self.e.q }, button) end
    end)
    rows[i] = r
    return r
  end

  -- ENCHANT LIST (enchant field of a slot) ---------------------------------------------
  local erows = {}
  local function erow(i)
    local r = erows[i]; if r then return r end
    r = CreateFrame("Button", nil, child); r:SetHeight(40)
    r.card = UI.CardRow(r)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(30, 30); r.icon:SetPoint("LEFT", 6, 0)
    r.star = UI.WishStar(r); r.star:SetPoint("RIGHT", -10, 0)
    r.star.onToggle = function() if tab == "wish" then refreshList() end end
    -- Professions: opens the recipe there
    r.prof = CreateFrame("Button", nil, r); r.prof:SetSize(24, 24); r.prof:SetPoint("RIGHT", r.star, "LEFT", -14, 0)
    r.prof.tex = r.prof:CreateTexture(nil, "ARTWORK"); r.prof.tex:SetAllPoints(); r.prof.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.prof:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    r.prof:SetScript("OnClick", function()
      local o = r.o; if not (o and o.p and o.s) then return end
      FLT:OpenPanel("professions")
      if FLT.ShowRecipeInProfessions then FLT.ShowRecipeInProfessions(o.p, o.s) end
    end)
    r.prof:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(r.o and r.o.p or "", 1, 0.82, 0)
      GameTooltip:AddLine("Open the recipe in Professions.", 1, 1, 1, true); GameTooltip:Show()
    end)
    r.prof:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.name = newText(r, "GameFontHighlight"); r.name:SetPoint("TOPLEFT", 44, -5)
    r.sub = newText(r, "GameFontHighlightSmall", nil, DIM); r.sub:SetPoint("TOPLEFT", 44, -22)
    r.val = newText(r, "GameFontNormal", 54); r.val:SetJustifyH("RIGHT")
    r.val:SetPoint("RIGHT", r.star, "LEFT", -70, 0)
    r.name:SetPoint("RIGHT", r.val, "LEFT", -4, 0); r.sub:SetPoint("RIGHT", r.val, "LEFT", -4, 0)
    r.sub._ofaNoAnchor = true
    r:SetScript("OnEnter", function(self)
      local o = self.o
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local ok = false
      if o.i then ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. o.i)
      elseif o.s and GameTooltip.SetSpellByID then ok = pcall(GameTooltip.SetSpellByID, GameTooltip, o.s) end
      if not ok then GameTooltip:AddLine(o.n or "", 1, 1, 1) end
      local ce = FLT.ENCHANTS and FLT.ENCHANTS[o.e]
      if ce then GameTooltip:AddLine(ce[1], 0.4, 1, 0.4, true) end
      if self.where then GameTooltip:AddLine(self.where, 1, 0.82, 0, true) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetHitRectInsets(0, 100, 0, 0)
    r:SetScript("OnClick", function(self)
      local o = self.o
      if not (IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
      local link
      if o.i then link = select(2, GetItemInfo(o.i))
      elseif o.s then link = (C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(o.s)) or (GetSpellLink and GetSpellLink(o.s)) end
      if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end)
    erows[i] = r
    return r
  end
  local elist = {} -- reused
  local function refreshEnchants()
    for _, r in ipairs(rows) do r:Hide() end
    for _, r in ipairs(erows) do r:Hide() end
    showRange(false)
    local slot = selected
    local id = GetInventoryItemID and GetInventoryItemID("player", slot)
    local cur = wornEnchant(slot)
    local GV = FLT.GearValue
    local base = GV and GV.SlotItemValue(slot) or 0
    local curV = (cur and GV and GV.EnchantValue(cur, slot, id)) or 0
    title:SetText((tab == "wish" and "Wishlist: " or "Enchants: ") .. (SLOT_NAME[slot] or ""))
    wipe(elist)
    local hasCur = false
    for _, o in ipairs(id and enchantOptions(id) or {}) do
      if o.e == cur then hasCur = true end
      if tab ~= "wish" or FLT.IsOnWishlist(enchantKey(o)) then
        o.v = GV and GV.EnchantValue(o.e, slot, id) or nil
        elist[#elist + 1] = o
      end
    end
    -- what is on it now, also when it is not in our list (a raid or event enchant)
    if cur and not hasCur and tab ~= "wish" then
      local ce = FLT.ENCHANTS and FLT.ENCHANTS[cur]
      elist[#elist + 1] = { e = cur, n = ce and ce[1] or "Current enchant", v = curV, worn = true }
    end
    -- best Value first, then the ones in Forever, then the higher skill
    table.sort(elist, function(a, b)
      if (a.e == cur) ~= (b.e == cur) then return a.e == cur end
      if a.v and b.v then if a.v ~= b.v then return a.v > b.v end
      elseif a.v or b.v then return a.v ~= nil end
      if (a.st == 0) ~= (b.st == 0) then return b.st == 0 end
      return (a.req or 0) > (b.req or 0)
    end)
    local y = -2
    for i, o in ipairs(elist) do
      local r = erow(i); r.o = o
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", child, "RIGHT", -2, 0); r:Show(); y = y - 44
      r.icon:SetTexture(enchantIcon(o) or "Interface\\Icons\\Trade_Engraving"); FLT.Desat(r.icon, o.st == 0)
      r.name:SetText(o.n or "")
      if o.st == 0 then r.name:SetTextColor(0.62, 0.60, 0.56) else r.name:SetTextColor(FLT.SkinC(1, 0.93, 0.66)) end
      local ce = FLT.ENCHANTS and FLT.ENCHANTS[o.e]
      local where
      if o.p then
        where = o.p .. (o.req and (" " .. o.req) or "")
        local known, guild, other
        if FLT.RecipeKnowState and o.s then known, guild, other = FLT.RecipeKnowState(o.p, { s = o.s }) end
        if known then where = where .. "  |cff40ff40(you know it)|r"
        elseif other then where = where .. "  |cff8fd0ff(an alt knows it)|r"
        elseif guild then where = where .. "  |cffffd35a(your guild)|r" end
      elseif o.src then where = o.src .. (o.st == 0 and "  |cff9d9d9d(not in Forever yet)|r" or "") end
      r.where = where
      local parts = {}
      if ce and not o.worn then parts[#parts + 1] = ce[1] end
      if where then parts[#parts + 1] = where end
      r.sub:SetText(table.concat(parts, "  ·  "))
      if o.e == cur then r.val:SetText("|cffb0b0b0worn|r")
      elseif o.v and o.v > 0 and base + curV > 0 then
        local pct = (o.v - curV) / (base + curV) * 100
        if pct >= 0.5 then r.val:SetText(string.format("|cff40ff40+%d%%|r", math.floor(pct + 0.5)))
        elseif pct <= -0.5 then r.val:SetText(string.format("|cffff5050-%d%%|r", math.floor(-pct + 0.5)))
        else r.val:SetText("|cffb0b0b0=|r") end
      elseif o.v and o.v > 0 then r.val:SetText("|cff40ff40new|r")
      else r.val:SetText("|cffb0b0b0-|r") end
      r.prof:SetShown(o.p ~= nil and o.s ~= nil)
      if r.prof:IsShown() then r.prof.tex:SetTexture(PROF_ICON[o.p] or "Interface\\Icons\\INV_Misc_QuestionMark") end
      if o.worn then r.star:Hide() else r.star:SetKey(enchantKey(o)) end
    end
    child:SetHeight(math.max(1, -y))
    if #elist == 0 then
      empty:SetText(tab == "wish" and "No enchant for this slot on your wishlist yet.\nClick the star on an enchant to add it." or "Nothing in our data fits this item.")
      empty:Show()
    else empty:Hide() end
  end

  local list = {} -- reused
  refreshList = function()
    if not f:IsShown() then return end
    readProfessions()
    srcBtn:SetShown(not (enchMode and search == ""))
    if enchMode and search == "" then refreshEnchants(); return end
    for _, r in ipairs(erows) do r:Hide() end
    local idx, ids = FLT.GearIndex()
    local cls = f.class
    local plevel = playerLevel()
    local minLevel, maxLevel = range()
    if maxLevel >= MAX_LEVEL then maxLevel = 999 end
    paintRange()
    local w = sf:GetWidth(); if w and w > 0 then child:SetWidth(w) end
    wipe(list)
    local slotName = SLOT_NAME[selected] or ""
    local function fits(e) for _, s in ipairs(LOC_SLOTS[e.loc] or {}) do if s == selected then return true end end return false end
    local function offhandOK(e) return selected ~= 17 or e.loc ~= "INVTYPE_WEAPON" or DUAL_WIELD[cls] end
    if search ~= "" then
      title:SetText("Search: all slots")
      for _, e in ipairs(idx) do
        if (e.name or ""):lower():find(search, 1, true) and sourceOK(e) then list[#list + 1] = e; if #list >= 100 then break end end
      end
      table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    elseif tab == "wish" then
      -- "All slots" (user 03.11.): the whole wishlist, in the order of the slots, else the selected slot
      local all = prefs.wishAll and true or false
      title:SetText("Wishlist: " .. (all and "all slots" or slotName))
      for id in pairs(wishlist()) do
        local e = type(id) == "number" and ids[id]
        if not e and type(id) == "number" then -- an item that is not in our data: build a small entry
          local _, _, _, loc, icon, cid, sub = GetItemInfoInstant(id)
          if loc and LOC_SLOTS[loc] then e = { id = id, loc = loc, icon = icon, cid = cid, sub = sub }; ids[id] = e end
        end
        if e and (all or fits(e)) and sourceOK(e) then list[#list + 1] = e end
      end
      for _, e in ipairs(list) do reqLevel(e) end
      table.sort(list, function(a, b)
        if all then
          local sa, sb = SLOT_INDEX[(LOC_SLOTS[a.loc] or {})[1]] or 99, SLOT_INDEX[(LOC_SLOTS[b.loc] or {})[1]] or 99
          if sa ~= sb then return sa < sb end
        end
        return (a.req or a.lvl or 0) > (b.req or b.lvl or 0)
      end)
    else
      title:SetText(slotName) -- without "Suggested:" so the sources fit (user 31.10.); the full text is on mouseover
      for _, e in ipairs(idx) do
        if fits(e) and offhandOK(e) and usable(e, cls, plevel) and (e.lvl or 0) <= maxLevel and sourceOK(e) then
          local lv = reqLevel(e)
          if e.qreq and e.qreq > lv then lv = e.qreq end -- quest rewards: not before the quest can be taken
          -- no required level (0) counts as level 1, else the low items fell out of a "1 - x" range (6.0.2, user 31.10.)
          if lv <= maxLevel and math.max(lv, 1) >= minLevel then list[#list + 1] = e end
        end
      end
      -- biggest Value gain first (items without data yet after them), then closest to the level limit,
      -- item level and quality
      local GV = FLT.GearValue
      -- only real upgrades (user 16.10.): a higher Value than the worn item, or nothing worn there; items
      -- without data yet come in when the client has loaded them (the Armory redraws on GET_ITEM_INFO_RECEIVED)
      if GV then
        local n = 0
        for _, e in ipairs(list) do
          local kind = GV.Change(e.id)
          if kind == "up" or kind == "new" then
            local _, d = GV.Upgrade(e.id); e.delta = d; n = n + 1; list[n] = e
          end
        end
        for i = #list, n + 1, -1 do list[i] = nil end
      end
      table.sort(list, function(a, b)
        if a.delta and b.delta then if a.delta ~= b.delta then return a.delta > b.delta end
        elseif a.delta or b.delta then return a.delta ~= nil end
        local la, lb = a.req or a.lvl or 0, b.req or b.lvl or 0
        if la ~= lb then return la > lb end
        if (a.ilvl or 0) ~= (b.ilvl or 0) then return (a.ilvl or 0) > (b.ilvl or 0) end
        return (a.q or 0) > (b.q or 0)
      end)
      for i = #list, 61, -1 do list[i] = nil end
    end
    local short = shortNames()
    titleHover.head = (search == "" and tab ~= "wish") and ("Suggested: " .. slotName) or title:GetText()
    titleHover.sources = short
    if short then title:SetText(title:GetText() .. "  |cffb0b0b0" .. short .. "|r") end
    for _, r in ipairs(rows) do r:Hide() end
    local y = -2
    for i, e in ipairs(list) do
      local r = row(i); r.e = e
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", child, "RIGHT", -2, 0); r:Show(); y = y - 44
      r.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      -- quality too: quest rewards from QuestieDB come with a name but without quality (legendaries were white)
      if not e.name or not e.q then reqLevel(e) end
      -- quest rewards: the yellow quest "!" right after the name
      r.name:SetText((e.name or ("Item " .. e.id)) .. (e.qid and " |TInterface\\GossipFrame\\AvailableQuestIcon:0|t" or "")); r.name:SetTextColor(qcolor(e.q))
      local lv = e.req or e.lvl
      if e.qreq and (lv or 0) < e.qreq then lv = e.qreq end
      local parts = {}
      if lv and lv > 0 then parts[#parts + 1] = (e.req and "lvl " or "lvl ~") .. lv end
      if search ~= "" or (tab == "wish" and prefs.wishAll) then parts[#parts + 1] = SLOT_NAME[(LOC_SLOTS[e.loc] or {})[1]] end
      if e.src then parts[#parts + 1] = e.src end
      r.sub:SetText(table.concat(parts, "  ·  "))
      -- star, then Chain or the map icon in the same place (a chain has its maps in the popup)
      local d = e.d
      local hasMap = e.qid and FLT.QuestStart(e.qid)
      local steps = e.qid and FLT.QUEST_REWARDS and #FLT.QuestChain(e.qid) or 0
      if steps > 1 then hasMap = nil end -- a chain: Map is on each step in the chain popup (user 16.10.)
      r.map:SetShown(hasMap and true or false)
      r.go:SetShown(d and not hasMap and steps <= 1 and true or false)
      if r.go:IsShown() and r.go.raid ~= (d.raid and true or false) then
        r.go.raid = d.raid and true or false
        local atlas = r.go.raid and "raid" or "dungeon"
        for _, t in ipairs({ r.go.tex, r.go.hl }) do if t.SetAtlas then pcall(t.SetAtlas, t, atlas) end end
      end
      r.chain:SetShown(steps > 1); r.chain.steps = steps
      local crafted = e.prof and not d and not e.qid
      r.pro:SetShown(crafted and true or false)
      if crafted then FLT.SetTex(r.pro.tex, FLT.PROFESSION_ICONS and FLT.PROFESSION_ICONS[e.prof] or "Interface\\Icons\\INV_Misc_QuestionMark") end
      local kind, pct
      if FLT.GearValue then kind, pct = FLT.GearValue.Change(e.id) end
      if kind == "up" then r.val:SetText(string.format("|cff40ff40+%d%%|r", math.floor(pct + 0.5)))
      elseif kind == "down" then r.val:SetText(string.format("|cffff5050-%d%%|r", math.floor(pct + 0.5)))
      elseif kind == "new" then r.val:SetText("|cff40ff40new|r")
      elseif kind == "worn" then r.val:SetText("|cffb0b0b0worn|r")
      elseif kind == "same" then r.val:SetText("|cffb0b0b0=|r") else r.val:SetText("") end
      r.star:SetItem(e.id)
    end
    child:SetHeight(math.max(1, -y))
    if #list == 0 then
      empty:SetText(short and (tab ~= "wish" and search == "" and FLT.GearValue
          and "No upgrade among the \"" .. short .. "\" items for this slot in your level range.\nOnly items better than what you wear (for your spec) are listed.\nThe filter button is next to the Wishlist tab."
          or "Nothing here with the source filter \"" .. short .. "\".\nThe filter button is next to the Wishlist tab.") or search ~= "" and "No item found." or (tab == "wish" and (prefs.wishAll and "Your wishlist is empty.\nClick the star on an item to add it." or "Your wishlist has no item for this slot yet.\nClick the star on an item to add it.") or (FLT.GearValue and "No upgrade for this slot in your level range yet." or "No item from our data fits this slot and level yet.")))
      empty:Show()
    else empty:Hide() end
  end

  -- Refresh: list redraws (item data arriving, bags); the model only when the gear changed
  function f:Refresh(gearChanged)
    refreshSlots()
    if gearChanged then loadModel() end
    refreshList()
  end
  f:SetScript("OnShow", function() loadModel(); refreshSlots(); refreshList() end)
  return f
end

-- Custom weights editor (5.7.3, user 27.10.): one number per stat for this character, used when "Custom weights"
-- is picked. Starts with the active spec's weights; "Copy from" puts a spec's weights in. Built when first opened.
local WEIGHT_STATS = {
  { "str", "Strength" }, { "agi", "Agility" }, { "sta", "Stamina" }, { "int", "Intellect" }, { "spi", "Spirit" },
  { "ap", "Attack Power" }, { "rap", "Ranged Attack Power" }, { "fap", "Feral Attack Power" }, { "dps", "Weapon DPS" },
  { "wskill", "Weapon Skill (per 1 %)" }, { "hit", "Hit (per 1 %)" }, { "crit", "Crit (per 1 %)" },
  { "sp", "Spell Power" }, { "heal", "Healing" }, { "mp5", "Mana per 5 sec." }, { "armor", "Armor" },
  { "def", "Defense" }, { "dodge", "Dodge (per 1 %)" }, { "parry", "Parry (per 1 %)" }, { "block", "Block (per 1 %)" },
  { "bv", "Block Value" }, { "fire", "Fire Spell Damage" }, { "frost", "Frost Spell Damage" },
  { "shadow", "Shadow Spell Damage" }, { "arcane", "Arcane Spell Damage" }, { "nature", "Nature Spell Damage" },
  { "holy", "Holy Spell Damage" },
}
local editor
function UI.ShowWeightEditor(onChange)
  local GV = FLT.GearValue; if not GV then return end
  if not editor then
    local f = CreateFrame("Frame", "OneForAllWeightEditor", UIParent)
    f:SetSize(560, 470); f:SetPoint("CENTER", 0, 30); f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllWeightEditor") end
    UI.FramedPanel(f)
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)
    local t = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); t:SetPoint("TOPLEFT", 18, -16); t:SetText("Custom weights")
    t:SetTextColor(1, 0.82, 0.20)
    local d = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); d:SetPoint("TOPLEFT", 18, -38); d:SetWidth(520); d:SetJustifyH("LEFT")
    d:SetText("Value per point of each stat for this character (hit, crit, dodge ... per 1 %). 0 or empty = the stat does not count. Used while \"Custom weights\" is picked.")
    f.boxes = {}
    for i, st in ipairs(WEIGHT_STATS) do
      local col, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
      local x, y = 18 + col * 270, -66 - rowN * 25
      local l = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); l:SetPoint("TOPLEFT", x, y - 4); l:SetText(st[2])
      local eb = FLT.SkinBlizz(CreateFrame("EditBox", nil, f, "InputBoxTemplate"))
      eb:SetSize(60, 20); eb:SetPoint("TOPLEFT", x + 190, y); eb:SetAutoFocus(false); eb:SetMaxLetters(7)
      local function save(self)
        local v = tonumber(((self:GetText() or ""):gsub(",", ".")))
        GV.SetCustomWeight(st[1], v); self:SetText(v and v ~= 0 and tostring(v) or "")
        if f.onChange then f.onChange() end
      end
      eb:SetScript("OnEnterPressed", function(self) save(self); self:ClearFocus() end)
      eb:SetScript("OnEditFocusLost", save)
      eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      f.boxes[st[1]] = eb
    end
    f.fill = function()
      local c = GV.CustomWeights()
      for k, eb in pairs(f.boxes) do local v = c[k]; eb:SetText(v and tostring(v) or "") end
    end
    local copy = UI.GoldButton(f, "Copy from a spec", 170, 24, nil, 12); copy:SetPoint("BOTTOMLEFT", 16, 14)
    copy:SetScript("OnClick", function(self)
      local specs = GV.Specs()
      local opts = { { key = 0, label = "Active spec" } }
      for i, sp in ipairs(specs) do opts[#opts + 1] = { key = i, label = sp.name } end
      UI.OpenDropDown(self, opts, nil, function(k)
        GV.ResetCustom(k ~= 0 and k or nil); f.fill()
        if f.onChange then f.onChange() end
      end, 170)
    end)
    local done = UI.GoldButton(f, "Done", 110, 24, nil, 12); done:SetPoint("BOTTOMRIGHT", -16, 14)
    done:SetScript("OnClick", function() f:Hide() end)
    editor = f
  end
  editor.onChange = onChange
  editor.fill()
  editor:Show()
end
