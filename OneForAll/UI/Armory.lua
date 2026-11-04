local _, FLT = ...
local UI = FLT.UI
local unpack = unpack or table.unpack
local makeTexture = UI.makeTexture
local H = UI.DungeonHelpers or {}

-- Armory tab: item sets (raid, dungeon, PvP, crafted, world) with what the
-- character already owns, and the reputation rewards of every faction.
-- Data: Data\Armory.lua (FLT.ARMORY_SETS, FLT.ARMORY_REPUTATION).

local GOLD = UI.GOLD
local TEXT = {0.92, 0.90, 0.84}
local DIM = {0.62, 0.60, 0.56}

local CLASSES = {
  { id = 1, token = "WARRIOR", name = "Warrior" }, { id = 2, token = "PALADIN", name = "Paladin" },
  { id = 3, token = "HUNTER", name = "Hunter" },   { id = 4, token = "ROGUE", name = "Rogue" },
  { id = 5, token = "PRIEST", name = "Priest" },   { id = 7, token = "SHAMAN", name = "Shaman" },
  { id = 8, token = "MAGE", name = "Mage" },       { id = 9, token = "WARLOCK", name = "Warlock" },
  { id = 11, token = "DRUID", name = "Druid" },
}
local CLASS_NAME = {}
for _, c in ipairs(CLASSES) do CLASS_NAME[c.token] = c.name end

local GROUPS = {
  { key = "raid", label = "Raid Sets", icon = "Interface\\Icons\\INV_Helmet_08" },
  { key = "dungeon", label = "Dungeon Sets", icon = "Interface\\Icons\\INV_Chest_Cloth_05" },
  { key = "pvp", label = "PvP Sets", icon = "Interface\\Icons\\INV_BannerPVP_02" },
  { key = "crafted", label = "Crafted Sets", icon = "Interface\\Icons\\Trade_BlackSmithing" },
  { key = "world", label = "World Sets", icon = "Interface\\Icons\\INV_Misc_Map_01" },
}
local GROUP_LABEL = {}
for _, g in ipairs(GROUPS) do GROUP_LABEL[g.key] = g.label end

-- Buttons for the main sets of a group (user 22.10.): { label, sub names }; everything else of the group
-- goes into the "Other Sets" drop-down. Groups without an entry (World Sets) keep the plain list.
local TABS = {
  raid = { { "Forever T1", { "Forever Tier 1" } }, { "Tier 1", { "Tier 1 - Molten Core" } },
           { "Tier 2", { "Tier 2 - Blackwing Lair" } }, { "Tier 3", { "Tier 3 - Naxxramas" } } },
  dungeon = { { "Dungeon 1", { "Dungeon Set 1" } }, { "Dungeon 2", { "Dungeon Set 2" } } },
  pvp = { { "Rare (Rank 7-10)", { "Rank 7-10 (rare)" } }, { "Epic (Rank 12-13)", { "Rank 12-13 (epic)" } },
          { "Rank 14", { "Rank 14 weapons" } } }, -- Arathi Basin under "Other Sets" (user 22.10.)
  crafted = { { "Leatherworking", { "Leatherworking" } }, { "Blacksmithing", { "Blacksmithing" } }, { "Tailoring", { "Tailoring" } } },
}
for _, list in pairs(TABS) do
  for _, t in ipairs(list) do t.set = {}; for _, sub in ipairs(t[2]) do t.set[sub] = true end end
end

-- st: 1 obtainable, 2 made for Forever but no source known yet, 0 not in Forever yet
local STATUS = {
  [0] = { text = "Not in Forever yet", c = {0.62, 0.50, 0.46}, tip = "This set exists in the game files, but its source (raid, battleground ranks, event, ...) is not part of WoW Forever yet." },
  [2] = { text = "Source not known yet", c = {0.95, 0.70, 0.28}, tip = "A set made for WoW Forever. Where its pieces drop is not known yet." },
}
local RANK_LABEL = { [3] = "Neutral", [4] = "Friendly", [5] = "Honored", [6] = "Revered", [7] = "Exalted" }
local RANK_COLOR = { [3] = {0.85, 0.85, 0.85}, [4] = {0.30, 0.85, 0.30}, [5] = {0.30, 0.85, 0.55}, [6] = {0.30, 0.75, 0.85}, [7] = {0.75, 0.55, 1.00} }
local KINDS = { { key = "all", label = "All" }, { key = "gear", label = "Gear" }, { key = "recipe", label = "Recipes" }, { key = "other", label = "Other" } }

-- Saved choices (per character): class filter, hide unreleased sets, item kind.
local function prefs()
  if type(OneForAllCharDB) ~= "table" then return {} end
  OneForAllCharDB.armory = OneForAllCharDB.armory or {}
  return OneForAllCharDB.armory
end
local function playerClass()
  local _, token = UnitClass("player")
  return token
end

-- Item helpers ------------------------------------------------------------
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local IsEquippedItem = IsEquippedItem or (C_Item and C_Item.IsEquippedItem)

local function itemName(id, fallback)
  if fallback then return fallback end
  local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not n and GetItemInfo then n = GetItemInfo(id) end
  if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return n or ("Item " .. id)
end
local function setItemIcon(tex, id, icon)
  if type(icon) == "number" and icon > 0 then tex:SetTexture(icon)
  elseif type(icon) == "string" then tex:SetTexture("Interface\\Icons\\" .. icon)
  else
    local fid = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    tex:SetTexture(fid or "Interface\\Icons\\INV_Misc_QuestionMark")
  end
end
local function qualityColor(q)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return unpack(TEXT)
end

-- "equipped", "bags", "bank" or nil
local function ownedWhere(id)
  if not id then return nil end
  if IsEquippedItem then local ok, eq = pcall(IsEquippedItem, id); if ok and eq then return "equipped" end end
  if FLT.bagItems and FLT.bagItems[id] then return "bags" end
  if FLT.bankItems and FLT.bankItems[id] then return "bank" end
  if GetItemCount then
    local ok, n = pcall(GetItemCount, id, true)
    if ok and (n or 0) > 0 then return "bags" end
  end
  return nil
end
local function setProgress(set)
  local owned, equipped = 0, 0
  for _, it in ipairs(set.i) do
    local w = ownedWhere(it[1])
    if w then owned = owned + 1 end
    if w == "equipped" then equipped = equipped + 1 end
  end
  return owned, equipped, #set.i
end

-- Faction sets / factions of the other side are not shown.
local function sideOK(x)
  if not x.side then return true end
  local fac = UnitFactionGroup and UnitFactionGroup("player")
  return not fac or (x.side == "A") == (fac == "Alliance")
end

local function setForClass(set, token)
  if not sideOK(set) then return false end
  if not token then return true end
  if not set.cls or #set.cls == 0 then return true end
  for _, c in ipairs(set.cls) do if c == token then return true end end
  return false
end

local function setIcon(set)
  for _, it in ipairs(set.i) do if it[3] == "Chest" then return it end end
  return set.i[1]
end

-- Reputation standing of the player: standingID (1-8), value in rank, rank size.
local function standing(fid)
  if type(C_Reputation) == "table" and C_Reputation.GetFactionDataByID then
    local ok, d = pcall(C_Reputation.GetFactionDataByID, fid)
    if ok and type(d) == "table" and d.name then
      local lo, hi = d.currentReactionThreshold or 0, d.nextReactionThreshold or 0
      return d.reaction, (d.currentStanding or 0) - lo, hi - lo
    end
  end
  if GetFactionInfoByID then
    local ok, name, _, st, bmin, bmax, val = pcall(GetFactionInfoByID, fid)
    if ok and name and st then return st, (val or 0) - (bmin or 0), (bmax or 0) - (bmin or 0) end
  end
  return nil
end
local function standingLabel(st)
  if not st then return "Not met yet" end
  return _G["FACTION_STANDING_LABEL" .. st] or RANK_LABEL[st - 1] or tostring(st)
end
-- item ranks use 0-7 (4 = Friendly); the client's standingID is 1-8
local function rankReached(rank, st) return st and (st - 1) >= rank end

-- Source text -> action (open the dungeon / the Professions tab).
local function findDungeon(name)
  for _, d in ipairs(FLT.DUNGEONS or {}) do if d.name == name then return d end end
end
local function sourceAction(src)
  if type(src) ~= "string" then return nil end
  if src:find("^Crafted:") then
    return function() if FLT.OpenPanel then FLT:OpenPanel("professions") end end, "Professions"
  end
  local dname, boss = src:match("^(.-) %- (.+)$")
  if src:find("^Quest:") then dname = src:match("%(([^%)]+)%)$") end
  local d = dname and findDungeon(dname)
  if not d then return nil end
  return function()
    if FLT.OpenPanel then FLT:OpenPanel("dungeons") end
    if UI.OpenDungeon then UI.OpenDungeon(d, (not src:find("^Quest:")) and boss or nil) end
  end, d.name
end

local function newText(parent, template, w, color)
  local fs = FLT.NewFS(parent, nil, "OVERLAY", template or "GameFontHighlightSmall")
  if w then fs:SetWidth(w) end
  fs:SetJustifyH("LEFT"); fs:SetWordWrap(false)
  if color then fs:SetTextColor(FLT.SkinC(unpack(color))) end
  return fs
end
local function setFontSize(fs, size)
  local font, _, flags = fs:GetFont(); if font then fs:SetFont(font, size, flags) end
end

local function itemTooltip(owner, id, name, slot, q)
  if H.tryShowItemTooltip and H.tryShowItemTooltip(owner, { id = id, name = name, slot = slot, quality = q }) then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if not pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. id) then GameTooltip:AddLine(name or ("Item " .. id)) end
  GameTooltip:Show()
end
local function itemClick(id, name, slot, q, button)
  if H.handleDungeonItemClick then H.handleDungeonItemClick({ id = id, name = name, slot = slot, quality = q }, button) end
end

-- Scroll list with a row pool: list:SetRows(entries, build) where
-- build(row, entry) fills a recycled row; rows have a fixed height per kind.
local function scrollList(parent, width)
  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 10, -10); sf:SetPoint("BOTTOMRIGHT", -28, 8)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(width, 1); sf:SetScrollChild(child)
  UI.AutoHideScrollBar(sf)
  sf.child = child
  return sf
end

local function createArmoryPanel(parent)
  local panel = CreateFrame("Frame", nil, parent)
  UI.PlacePanel(panel, parent)
  local P = prefs()
  -- the class filter always starts on the character's own class
  P.class = playerClass()

  local band = UI.TitleBand(panel, { emblem = UI.ASSET_ROOT .. "emblem_armory", art = UI.ASSET_ROOT .. "armory_banner",
    title = "Armory", subtitle = "Item sets and reputation rewards in WoW Forever, and which pieces you already own.", fadeRight = 60 })

  local nav, navTop = UI.SideNav(panel, -74, "emblem_armory", "Armory") -- ht8: the same side list in every tab
  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", 182, -74); body:SetPoint("BOTTOMRIGHT", -8, 4)

  local views = {}
  local navButtons = {}
  local current -- "gear", group key or "rep"
  local show -- forward

  local function hideViews() for _, v in pairs(views) do v:Hide() end end
  local function setNav(key) for k, b in pairs(navButtons) do b:SetActive(k == key) end end

  -- Class filter bar (shared by the set views) ----------------------------
  local filterBar = CreateFrame("Frame", nil, body); filterBar:SetPoint("TOPLEFT", 0, 0); filterBar:SetPoint("TOPRIGHT", 0, 0); filterBar:SetHeight(30)
  local classButtons = {}
  local refreshSets -- forward
  local function paintClassButtons()
    for _, b in ipairs(classButtons) do
      local on = (b.token or false) == (P.class or false)
      if b.ring then
        b.icon:SetAlpha(on and 1 or 0.6); FLT.Desat(b.icon, not on)
        if on then b.ring:SetVertexColor(FLT.SkinC(1, 0.84, 0.36, 1)) else b.ring:SetVertexColor(FLT.SkinC(0.55, 0.42, 0.22, 1)) end
      else
        b:SetActive(on)
      end
    end
  end
  do
    local allB = UI.GoldButton(filterBar, "All classes", 92, 26); allB:SetPoint("LEFT", 0, 0)
    allB.token = nil
    allB:SetScript("OnClick", function() P.class = false; paintClassButtons(); if refreshSets then refreshSets() end end)
    classButtons[#classButtons + 1] = allB
    local x = 98
    for _, c in ipairs(CLASSES) do
      local b = CreateFrame("Button", nil, filterBar); b:SetSize(30, 30); b:SetPoint("LEFT", x, 0); x = x + 34
      local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetPoint("TOPLEFT", 3, -3); ic:SetPoint("BOTTOMRIGHT", -3, 3)
      ic:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
      local tc = type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[c.token]
      if tc then
        local dx, dy = (tc[2] - tc[1]) * 0.06, (tc[4] - tc[3]) * 0.06
        ic:SetTexCoord(tc[1] + dx, tc[2] - dx, tc[3] + dy, tc[4] - dy)
      end
      local ring = b:CreateTexture(nil, "OVERLAY"); ring:SetAllPoints(); FLT.SetTex(ring, UI.ASSET_ROOT .. "talent_frame")
      local hl = b:CreateTexture(nil, "HIGHLIGHT"); FLT.SetTex(hl, UI.ASSET_ROOT .. "talent_frame"); hl:SetAllPoints(); hl:SetBlendMode("ADD")
      hl:SetVertexColor(FLT.SkinC(1, 0.86, 0.40, 0.85))
      b.icon, b.ring, b.token = ic, ring, c.token
      b:SetScript("OnClick", function() P.class = c.token; paintClassButtons(); if refreshSets then refreshSets() end end)
      b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(c.name); GameTooltip:Show() end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      classButtons[#classButtons + 1] = b
    end
    local hide = FLT.SkinBlizz(CreateFrame("CheckButton", nil, filterBar, "UICheckButtonTemplate"))
    hide:SetSize(24, 24); hide:SetPoint("RIGHT", -170, 0)
    local hl = newText(filterBar, "GameFontHighlightSmall", 168, TEXT); hl:SetPoint("LEFT", hide, "RIGHT", 2, 0); hl:SetText("Hide sets not in Forever yet")
    hide:SetChecked(P.hideNotYet and true or false)
    hide:SetScript("OnClick", function(self) P.hideNotYet = self:GetChecked() and true or false; if refreshSets then refreshSets() end end)
    filterBar.hide, filterBar.hideLabel = hide, hl
  end
  paintClassButtons()

  -- Set buttons of the group (TABS) + "Other Sets" drop-down -------------------
  -- tabPick[group] = index of a button, or the sub name picked under "Other Sets"; starts on the first button
  local tabBar = CreateFrame("Frame", nil, body); tabBar:SetPoint("TOPLEFT", 0, -36); tabBar:SetPoint("TOPRIGHT", 0, -36); tabBar:SetHeight(26); tabBar:Hide()
  local tabButtons, tabPick = {}, {}
  local otherB = UI.GoldButton(tabBar, "Other Sets", 170, 24, nil, 12)
  -- a long source name ends with "..." on the button, the whole name is in its tooltip (user 22.10.)
  otherB._label:SetWidth(170 - 40); otherB._label:SetWordWrap(false)
  otherB:SetScript("OnEnter", function(self)
    local pick = tabPick[current]
    if type(pick) ~= "string" then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(pick); GameTooltip:Show()
  end)
  otherB:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local otherArrow = otherB:CreateTexture(nil, "OVERLAY"); otherArrow:SetSize(12, 12); otherArrow:SetPoint("RIGHT", -8, 0)
  FLT.SetTex(otherArrow, UI.ASSET_ROOT .. "chevron"); otherArrow:SetTexCoord(0, 0.5, 0, 1)
  -- the subs of a group that have no button, in data order
  local function otherSubs(group)
    local out, seen, tabs = {}, {}, TABS[group] or {}
    for _, st in ipairs(FLT.ARMORY_SETS or {}) do
      local sub = st.sub
      if st.g == group and sub and not seen[sub] then
        local inTab = false
        for _, t in ipairs(tabs) do if t.set[sub] then inTab = true end end
        if not inTab then seen[sub] = true; out[#out + 1] = sub end
      end
    end
    return out
  end
  -- true when no set of these subs is in Forever yet (grey in the "Other Sets" drop-down)
  local function notYet(group, subs)
    for _, st in ipairs(FLT.ARMORY_SETS or {}) do if st.g == group and subs[st.sub] and st.st ~= 0 then return false end end
    return true
  end
  local function paintTabs()
    local tabs = TABS[current]
    if tabs and tabPick[current] == nil then -- the first button (user 22.10.) that has sets for the class filter
      tabPick[current] = 1
      for i = #tabs, 1, -1 do
        for _, st in ipairs(FLT.ARMORY_SETS or {}) do
          if st.g == current and tabs[i].set[st.sub or ""] and setForClass(st, P.class or nil) then tabPick[current] = i; break end
        end
      end
    end
    for i, b in ipairs(tabButtons) do
      local t = tabs and tabs[i]
      b:SetShown(t ~= nil)
      if t then
        b:SetLabel(t[1]); b:SetActive(tabPick[current] == i)
      end
    end
    local pick = tabPick[current]
    local isOther = type(pick) == "string"
    otherB:SetLabel(isOther and pick or "Other Sets"); otherB:SetActive(isOther)
    otherB:SetShown(tabs ~= nil and #otherSubs(current) > 0)
    otherB:ClearAllPoints(); otherB:SetPoint("LEFT", tabButtons[tabs and #tabs or 1], "RIGHT", 10, 0)
  end
  for i = 1, 4 do
    local b = UI.GoldButton(tabBar, "", 126, 24, nil, 12)
    if i == 1 then b:SetPoint("LEFT", 0, 0) else b:SetPoint("LEFT", tabButtons[i - 1], "RIGHT", 6, 0) end
    b:SetScript("OnClick", function() tabPick[current] = i; paintTabs(); if refreshSets then refreshSets() end end)
    tabButtons[i] = b
  end
  otherB:SetScript("OnClick", function(self)
    local opts, longest = {}, 0
    for _, sub in ipairs(otherSubs(current)) do
      local subs = { [sub] = true }
      local dim = notYet(current, subs)
      opts[#opts + 1] = { key = sub, label = dim and ("|cff9d9d9d" .. sub .. "  (not in Forever yet)|r") or sub }
      longest = math.max(longest, #sub + (dim and 20 or 0))
    end
    -- wide enough for the longest name (the list was narrower than its text, user 22.10.)
    UI.OpenDropDown(self, opts, tabPick[current], function(k) tabPick[current] = k; paintTabs(); if refreshSets then refreshSets() end end,
      math.max(220, math.floor(longest * 7.6 + 44)))
  end)

  -- SET VIEW (one for all groups) ----------------------------------------
  local setView = CreateFrame("Frame", nil, body); setView:SetPoint("TOPLEFT", 0, -36); setView:SetPoint("BOTTOMRIGHT", 0, 0); setView:Hide()
  views.sets = setView
  local LIST_W, ROW_W = 262, 258
  local left = CreateFrame("Frame", nil, setView); left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(300)
  UI.Column(left, 4)
  local lsf = scrollList(left, LIST_W)
  local right = CreateFrame("Frame", nil, setView); right:SetPoint("TOPLEFT", 308, 0); right:SetPoint("BOTTOMRIGHT")
  local dsf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate"))
  dsf:SetPoint("TOPLEFT", 14, -12); dsf:SetPoint("BOTTOMRIGHT", -28, 10)
  local DW = 452
  local detail = CreateFrame("Frame", nil, dsf); detail:SetSize(DW, 1); dsf:SetScrollChild(detail)
  UI.AutoHideScrollBar(dsf)
  local emptyText = newText(right, "GameFontDisable", 400); emptyText:SetPoint("CENTER"); emptyText:SetJustifyH("CENTER"); emptyText:SetText("No sets for this filter.")

  local selectedSet = {} -- group -> set id
  local setRows, headRows = {}, {}
  local renderDetail -- forward

  local function setRow(i)
    local r = setRows[i]; if r then return r end
    r = CreateFrame("Button", nil, lsf.child); r:SetSize(ROW_W, 38)
    r.card = UI.CardRow(r)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("LEFT", 6, 0)
    r.name = newText(r, "GameFontHighlight", 190); r.name:SetPoint("TOPLEFT", 42, -5)
    r.sub = newText(r, "GameFontHighlightSmall", 200, DIM); r.sub:SetPoint("TOPLEFT", 42, -21)
    r:SetScript("OnClick", function(self) selectedSet[current] = self.set.id; refreshSets(true) end)
    r:SetScript("OnEnter", function(self)
      local st = STATUS[self.set.st]
      if not st then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.set.n, 1, 0.82, 0)
      GameTooltip:AddLine(st.text, unpack(st.c)); GameTooltip:AddLine(st.tip, 1, 1, 1, true); GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    setRows[i] = r
    return r
  end
  local function headRow(i)
    local h = headRows[i]; if h then return h end
    h = CreateFrame("Frame", nil, lsf.child); h:SetSize(ROW_W, 22)
    h.text = newText(h, "GameFontNormalSmall", ROW_W - 8, UI.HEAD_GOLD); h.text:SetPoint("LEFT", 4, -2)
    local line = makeTexture(h, "ARTWORK", 0.72, 0.50, 0.12, 0.45); line:SetPoint("BOTTOMLEFT", 2, 0); line:SetPoint("BOTTOMRIGHT", -2, 0); line:SetHeight(1)
    headRows[i] = h
    return h
  end

  local function filteredSets(group)
    local out = {}
    for _, s in ipairs(FLT.ARMORY_SETS or {}) do
      if s.g == group and setForClass(s, P.class or nil) and not (P.hideNotYet and s.st == 0) then
        local tabs, pick = TABS[group], tabPick[group]
        local ok = true
        if tabs then
          if type(pick) == "string" then ok = s.sub == pick
          else ok = tabs[pick or 1].set[s.sub or ""] or false end
        end
        if ok then out[#out + 1] = s end
      end
    end
    -- highest level first (user 22.10.) within each source (headings stay together), otherwise the data order
    local pos, subPos = {}, {}
    for i, st in ipairs(out) do pos[st] = i; local k = st.sub or ""; subPos[k] = subPos[k] or i end
    table.sort(out, function(a, b)
      local sa, sb = subPos[a.sub or ""], subPos[b.sub or ""]
      if sa ~= sb then return sa < sb end
      local la, lb = a.lv or 0, b.lv or 0
      if la ~= lb then return la > lb end
      return pos[a] < pos[b]
    end)
    return out
  end

  refreshSets = function(keepScroll)
    if current == "gear" then return end
    if not views.sets:IsShown() then return end
    local list = filteredSets(current)
    for _, r in ipairs(setRows) do r:Hide() end
    for _, h in ipairs(headRows) do h:Hide() end
    local y, nr, nh, lastSub = -2, 0, 0, false
    local sel
    for _, s in ipairs(list) do
      if s.id == selectedSet[current] then sel = s end
    end
    sel = sel or list[1]
    if sel then selectedSet[current] = sel.id end
    for _, s in ipairs(list) do
      local sub = s.sub or GROUP_LABEL[s.g]
      local d = findDungeon(sub)
      if d and d.level then sub = sub .. "  |cff9d9d9d·  " .. d.level .. "|r" end
      if s.st == 0 then sub = sub .. "  |cff9d9d9d(not in Forever yet)|r" end
      if sub ~= lastSub then
        nh = nh + 1; local h = headRow(nh); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, y); h:Show(); y = y - 24
        h.text:SetText(sub); lastSub = sub
      end
      nr = nr + 1
      local r = setRow(nr); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 41
      r.set = s
      local first = setIcon(s)
      setItemIcon(r.icon, first[1], first[5]); FLT.Desat(r.icon, s.st == 0); r.icon:SetAlpha(s.st == 0 and 0.6 or 1)
      r.name:SetText(s.n)
      local owned, _, total = setProgress(s)
      if s.st == 0 then r.name:SetTextColor(FLT.SkinC(unpack(DIM))) else r.name:SetTextColor(qualityColor(first[4])) end
      local info = owned .. " / " .. total .. " owned"
      if s.arm then info = info .. "  ·  " .. s.arm end
      if s.lv then info = info .. "  ·  Lvl " .. s.lv end
      if s.st == 2 then info = info .. "  ·  |cfff2b347no source yet|r" end
      r.sub:SetText(info)
      r.card:SetSelected(s == sel)
    end
    lsf.child:SetHeight(math.max(1, -y))
    if not keepScroll then lsf:SetVerticalScroll(0) end
    emptyText:SetShown(sel == nil); dsf:SetShown(sel ~= nil)
    if sel then renderDetail(sel) end
  end

  -- detail pane: header, pieces, bonuses (pooled widgets)
  local dTitle = newText(detail, "GameFontNormalLarge", DW - 10, GOLD); dTitle:SetPoint("TOPLEFT", 2, -2); setFontSize(dTitle, 17)
  local dSub = newText(detail, "GameFontHighlightSmall", DW - 10, DIM); dSub:SetPoint("TOPLEFT", 2, -26)
  local dStatus = newText(detail, "GameFontHighlightSmall", DW - 10); dStatus:SetPoint("TOPLEFT", 2, -42); dStatus:SetWordWrap(true)
  local dProgress = newText(detail, "GameFontNormal", DW - 10, TEXT); dProgress:SetPoint("TOPLEFT", 2, -60)
  local piecesTitle = UI.SectionTitle(detail, "Pieces", 2, -84, -6)
  local pieceRows = {}
  local function pieceRow(i)
    local r = pieceRows[i]; if r then return r end
    r = CreateFrame("Button", nil, detail); r:SetSize(DW - 4, 36)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.card = UI.CardRow(r)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("LEFT", 5, 0)
    r.name = newText(r, "GameFontHighlight", 215); r.name:SetPoint("TOPLEFT", 40, -4)
    r.src = newText(r, "GameFontHighlightSmall", 215, DIM); r.src:SetPoint("TOPLEFT", 40, -20)
    r.own = newText(r, "GameFontHighlightSmall", 66); r.own:SetPoint("RIGHT", -96, 0); r.own:SetJustifyH("RIGHT"); r.own._ofaNoAnchor = true
    r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(16, 16); r.check:SetPoint("RIGHT", -166, 0)
    r.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    -- star far right like everywhere else, "Show" left of it (user 22.10.)
    r.star = UI.WishStar(r); r.star:SetPoint("RIGHT", -10, 0)
    r.go = UI.GoldButton(r, "Show", 54, 20, nil, 11); r.go:SetPoint("RIGHT", -38, 0)
    r:SetHitRectInsets(0, 96, 0, 0) -- no item tooltip over "Show" and the star (like the gear planner)
    r:SetScript("OnEnter", function(self) itemTooltip(self, self.it[1], self.itName, self.it[3], self.it[4]) end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, button) itemClick(self.it[1], self.itName, self.it[3], self.it[4], button) end)
    pieceRows[i] = r
    return r
  end
  local bonusTitle = UI.SectionTitle(detail, "Set bonuses", 2, -300, -6)
  local bonusLines = {}
  local function bonusLine(i)
    local b = bonusLines[i]; if b then return b end
    b = FLT.NewFS(detail, nil, "OVERLAY", "GameFontHighlightSmall"); b:SetWidth(DW - 16); b:SetJustifyH("LEFT")
    bonusLines[i] = b
    return b
  end
  local dNote = newText(detail, "GameFontDisableSmall", DW - 10); dNote:SetWordWrap(true)

  renderDetail = function(s)
    dTitle:SetText(s.n)
    local cls = {}
    for _, c in ipairs(s.cls or {}) do cls[#cls + 1] = CLASS_NAME[c] or c end
    local parts = { s.sub or GROUP_LABEL[s.g] }
    if s.arm then parts[#parts + 1] = s.arm end
    if s.lv then parts[#parts + 1] = "Requires level " .. s.lv end
    if #cls > 0 and #cls < 9 then parts[#parts + 1] = table.concat(cls, ", ") end
    dSub:SetText(table.concat(parts, "  ·  "))
    local st = STATUS[s.st]
    if st then dStatus:SetText(st.text .. ": " .. st.tip); dStatus:SetTextColor(FLT.SkinC(unpack(st.c)))
    else dStatus:SetText("Obtainable in WoW Forever"); dStatus:SetTextColor(0.35, 0.85, 0.35) end
    local owned, equipped, total = setProgress(s)
    dProgress:SetText(string.format("Owned %d / %d", owned, total) .. (equipped > 0 and string.format("   (%d equipped)", equipped) or ""))
    local y = -42 - math.max(14, dStatus:GetStringHeight() or 14) - 6
    dProgress:ClearAllPoints(); dProgress:SetPoint("TOPLEFT", 2, y); y = y - 26
    piecesTitle:ClearAllPoints(); piecesTitle:SetPoint("TOPLEFT", 2, y)
    y = y - 26
    for _, r in ipairs(pieceRows) do r:Hide() end
    for i, it in ipairs(s.i) do
      local r = pieceRow(i); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 39
      r.it = it; r.itName = itemName(it[1], it[2])
      setItemIcon(r.icon, it[1], it[5])
      r.name:SetText(r.itName); r.name:SetTextColor(qualityColor(it[4]))
      local src = it[6] and it[6][1]
      local srcText = (it[3] or "") .. (it[7] and (", " .. it[7]) or "")
      if src then srcText = srcText .. "  ·  " .. src
      elseif s.st == 1 then srcText = srcText .. "  ·  source not known yet" end
      if it[6] and #it[6] > 1 then srcText = srcText .. string.format("  (+%d)", #it[6] - 1) end
      r.src:SetText(srcText)
      r.star:SetItem(it[1])
      local w = ownedWhere(it[1])
      r.check:SetShown(w ~= nil)
      r.own:SetText(w and (w == "equipped" and "Equipped" or (w == "bank" and "Bank" or "Bags")) or "")
      r.own:SetTextColor(0.40, 0.85, 0.40)
      local action, target = sourceAction(src)
      if action then
        r.go:Show(); r.go:SetScript("OnClick", action)
        r.go:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Open " .. target, 1, 0.82, 0); GameTooltip:Show() end)
        r.go:SetScript("OnLeave", function() GameTooltip:Hide() end)
      else
        r.go:Hide()
      end
    end
    y = y - 8
    bonusTitle:ClearAllPoints(); bonusTitle:SetPoint("TOPLEFT", 2, y); y = y - 28
    for _, b in ipairs(bonusLines) do b:Hide() end
    if #(s.b or {}) == 0 then
      local b = bonusLine(1); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, y); b:Show()
      b:SetText("Set bonuses are not known yet."); b:SetTextColor(FLT.SkinC(unpack(DIM))); y = y - 18
    end
    for i, bonus in ipairs(s.b or {}) do
      local b = bonusLine(i); b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, y); b:Show()
      b:SetText(string.format("(%d) Set: %s", bonus[1], bonus[2]))
      if equipped >= bonus[1] then b:SetTextColor(0.35, 0.90, 0.35) else b:SetTextColor(FLT.SkinC(unpack(DIM))) end
      y = y - (b:GetStringHeight() or 14) - 6
    end
    y = y - 6
    dNote:ClearAllPoints(); dNote:SetPoint("TOPLEFT", 2, y)
    dNote:SetText("Bonuses light up for the pieces you wear. Hover a piece for its tooltip, Shift-click to link it.")
    y = y - 30
    detail:SetHeight(-y)
  end

  -- REPUTATION VIEW --------------------------------------------------------
  local repView = CreateFrame("Frame", nil, body); repView:SetAllPoints(); repView:Hide()
  views.rep = repView
  local rleft = CreateFrame("Frame", nil, repView); rleft:SetPoint("TOPLEFT"); rleft:SetPoint("BOTTOMLEFT"); rleft:SetWidth(300)
  UI.Column(rleft, 4)
  local rsf = scrollList(rleft, LIST_W)
  local rright = CreateFrame("Frame", nil, repView); rright:SetPoint("TOPLEFT", 308, 0); rright:SetPoint("BOTTOMRIGHT")
  local isf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, rright, "UIPanelScrollFrameTemplate"))
  isf:SetPoint("TOPLEFT", 14, -12); isf:SetPoint("BOTTOMRIGHT", -28, 10)
  local rdetail = CreateFrame("Frame", nil, isf); rdetail:SetSize(DW, 1); isf:SetScrollChild(rdetail)
  UI.AutoHideScrollBar(isf)

  local selectedFaction
  local facRows, facHeads = {}, {}
  local renderFaction, refreshRep -- forward
  local function facRow(i)
    local r = facRows[i]; if r then return r end
    r = CreateFrame("Button", nil, rsf.child); r:SetSize(ROW_W, 38)
    r.card = UI.CardRow(r)
    r.name = newText(r, "GameFontHighlight", 236); r.name:SetPoint("TOPLEFT", 10, -5)
    r.sub = newText(r, "GameFontHighlightSmall", 236, DIM); r.sub:SetPoint("TOPLEFT", 10, -21)
    r:SetScript("OnClick", function(self) selectedFaction = self.f.id; refreshRep(true) end)
    facRows[i] = r
    return r
  end
  local function facHead(i)
    local h = facHeads[i]; if h then return h end
    h = CreateFrame("Frame", nil, rsf.child); h:SetSize(ROW_W, 22)
    h.text = newText(h, "GameFontNormalSmall", ROW_W - 8, UI.HEAD_GOLD); h.text:SetPoint("LEFT", 4, -2)
    local line = makeTexture(h, "ARTWORK", 0.72, 0.50, 0.12, 0.45); line:SetPoint("BOTTOMLEFT", 2, 0); line:SetPoint("BOTTOMRIGHT", -2, 0); line:SetHeight(1)
    facHeads[i] = h
    return h
  end
  local factionVisible = sideOK

  refreshRep = function(keepScroll)
    for _, r in ipairs(facRows) do r:Hide() end
    for _, h in ipairs(facHeads) do h:Hide() end
    local y, nr, nh, lastHead = -2, 0, 0, nil
    local list = {}
    for _, f in ipairs(FLT.ARMORY_REPUTATION or {}) do if factionVisible(f) then list[#list + 1] = f end end
    local sel
    for _, f in ipairs(list) do if f.id == selectedFaction then sel = f end end
    sel = sel or list[1]
    if sel then selectedFaction = sel.id end
    for _, f in ipairs(list) do
      local head = f.st == 0 and "Not in Forever yet" or "Factions"
      if head ~= lastHead then
        nh = nh + 1; local h = facHead(nh); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, y); h:Show(); y = y - 24
        h.text:SetText(head); lastHead = head
      end
      nr = nr + 1
      local r = facRow(nr); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 41
      r.f = f
      r.name:SetText(f.n)
      if f.st == 0 then r.name:SetTextColor(FLT.SkinC(unpack(DIM))) else r.name:SetTextColor(FLT.SkinC(unpack(TEXT))) end
      local stid = standing(f.id)
      r.sub:SetText(string.format("%s  ·  %d rewards", standingLabel(stid), #f.i))
      r.card:SetSelected(f == sel)
    end
    rsf.child:SetHeight(math.max(1, -y))
    if not keepScroll then rsf:SetVerticalScroll(0) end
    if sel then renderFaction(sel) end
  end

  local fTitle = newText(rdetail, "GameFontNormalLarge", DW - 10, GOLD); fTitle:SetPoint("TOPLEFT", 2, -2); setFontSize(fTitle, 17)
  local fStanding = newText(rdetail, "GameFontHighlightSmall", DW - 10, TEXT); fStanding:SetPoint("TOPLEFT", 2, -26)
  -- standing bar: thin gold rim, dark inside, warm gold fill (same look as the button collector)
  local BAR_W = 300
  local barBg = CreateFrame("Frame", nil, rdetail); barBg:SetPoint("TOPLEFT", 2, -44); barBg:SetSize(BAR_W, 12)
  UI.RoundRect(barBg, barBg, "BACKGROUND", 0, 6, 0, 0.95, 0.76, 0.32, 1)
  UI.RoundRect(barBg, barBg, "BACKGROUND", 1, 5, 1.5, 0.06, 0.05, 0.04, 0.96)
  local bar = CreateFrame("Frame", nil, barBg); bar:SetPoint("TOPLEFT", 2, -2); bar:SetPoint("BOTTOMLEFT", 2, 2); bar:SetWidth(BAR_W - 4)
  local barFill = UI.RoundRect(bar, bar, "ARTWORK", 0, 4, 0, 0.86, 0.62, 0.20, 1)
  local vendorTitle = UI.SectionTitle(rdetail, "Vendor", 2, -64, -6)
  local vendorRows = {}
  local function vendorRow(i)
    local r = vendorRows[i]; if r then return r end
    r = CreateFrame("Frame", nil, rdetail); r:SetSize(DW - 4, 26)
    r.text = newText(r, "GameFontHighlight", DW - 100, TEXT); r.text:SetPoint("LEFT", 6, 0)
    r.map = UI.GoldButton(r, "Map", 64, 20, UI.ASSET_ROOT .. "icon_map", 11); r.map:SetPoint("RIGHT", -4, 0)
    vendorRows[i] = r
    return r
  end
  local itemsTitle = UI.SectionTitle(rdetail, "Rewards", 2, -120, -6)
  local kindButtons = {}
  for i, k in ipairs(KINDS) do
    local b = UI.GoldButton(rdetail, k.label, 70, 20, nil, 11); b.key = k.key
    b:SetScript("OnClick", function() P.kind = k.key; refreshRep(true) end)
    kindButtons[i] = b
  end
  local repItemRows = {}
  local function repItemRow(i)
    local r = repItemRows[i]; if r then return r end
    r = CreateFrame("Button", nil, rdetail); r:SetSize(DW - 4, 34)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.card = UI.CardRow(r)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(26, 26); r.icon:SetPoint("LEFT", 5, 0)
    r.name = newText(r, "GameFontHighlight", 270); r.name:SetPoint("TOPLEFT", 38, -3)
    r.sub = newText(r, "GameFontHighlightSmall", 270, DIM); r.sub:SetPoint("TOPLEFT", 38, -19)
    r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(16, 16); r.check:SetPoint("RIGHT", -40, 0)
    r.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    r.star = UI.WishStar(r); r.star:SetPoint("RIGHT", -10, 0) -- wishlist star far right (user 22.10.)
    r:SetHitRectInsets(0, 36, 0, 0) -- no item tooltip over the star
    r:SetScript("OnEnter", function(self) itemTooltip(self, self.it[1], self.itName, self.it[3], self.it[4]) end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, button) itemClick(self.it[1], self.itName, self.it[3], self.it[4], button) end)
    repItemRows[i] = r
    return r
  end
  local repNote = newText(rdetail, "GameFontDisableSmall", DW - 10); repNote:SetWordWrap(true)

  -- standing band above the rewards of each rank (like the trainer's level bands)
  -- click a band to fold its rewards in and out (user 16.10.: the chevron promised it); per session
  local repBands, repFolded, lastFaction = {}, {}, nil
  local function repBand(i)
    local h = repBands[i]; if h then return h end
    h = CreateFrame("Button", nil, rdetail); h:SetSize(DW - 4, 28)
    h:SetScript("OnClick", function(self)
      repFolded[self.key] = not repFolded[self.key]
      if lastFaction then renderFaction(lastFaction) end
    end)
    local base = h:CreateTexture(nil, "BACKGROUND"); base:SetPoint("TOPLEFT", 1, -1); base:SetPoint("BOTTOMRIGHT", -1, 1)
    base:SetColorTexture(1, 1, 1, 1)
    local r1, g1, b1 = FLT.SkinC(0.20, 0.15, 0.07)
    local r2, g2, b2 = FLT.SkinC(0.10, 0.08, 0.04)
    if base.SetGradient and CreateColor then
      pcall(base.SetGradient, base, "VERTICAL", CreateColor(r2, g2, b2, 0.92), CreateColor(r1, g1, b1, 0.92))
    else
      base:SetColorTexture(r1, g1, b1, 0.92)
    end
    for _, tx in ipairs(UI.OrnateFrame(h, h, 8, 1, "OVERLAY", 1) or {}) do tx:SetVertexColor(FLT.SkinC(0.70, 0.56, 0.32, 0.85)) end
    local ch = h:CreateTexture(nil, "ARTWORK"); ch:SetSize(14, 14); ch:SetPoint("LEFT", 10, 0)
    FLT.SetTex(ch, UI.ASSET_ROOT .. "chevron"); ch:SetTexCoord(0, 0.5, 0, 1); h.ch = ch
    local hl = UI.makeTexture(h, "HIGHLIGHT", 1, 0.82, 0.3, 0.08); hl:SetPoint("TOPLEFT", 1, -1); hl:SetPoint("BOTTOMRIGHT", -1, 1)
    h.text = FLT.NewFS(h, nil, "OVERLAY", "GameFontNormalLarge"); h.text:SetPoint("LEFT", 30, 0)
    setFontSize(h.text, 15)
    h.right = FLT.NewFS(h, nil, "OVERLAY", "GameFontHighlightSmall"); h.right:SetPoint("RIGHT", -12, 0)
    repBands[i] = h
    return h
  end
  local KIND_ORDER = { gear = 0, other = 1, recipe = 2 }

  renderFaction = function(f)
    lastFaction = f
    fTitle:SetText(f.n)
    local stid, val, max = standing(f.id)
    if f.st == 0 then
      fStanding:SetText("Not in Forever yet: the content of this faction is not part of WoW Forever yet.")
      fStanding:SetTextColor(FLT.SkinC(unpack(STATUS[0].c)))
    else
      local txt = "Your standing: " .. standingLabel(stid)
      if stid and max and max > 0 then txt = txt .. string.format("  (%d / %d)", val or 0, max) end
      fStanding:SetText(txt); fStanding:SetTextColor(FLT.SkinC(unpack(TEXT)))
    end
    local frac = (stid and max and max > 0) and math.max(0, math.min(1, (val or 0) / max)) or 0
    barBg:SetShown(stid ~= nil and f.st ~= 0); bar:SetShown(stid ~= nil and f.st ~= 0 and frac > 0.02)
    bar:SetWidth(math.max(8, (BAR_W - 4) * frac))

    local y = -64
    vendorTitle:ClearAllPoints(); vendorTitle:SetPoint("TOPLEFT", 2, y); y = y - 26
    for _, r in ipairs(vendorRows) do r:Hide() end
    local nv = 0
    for _, v in ipairs(f.v or {}) do
      nv = nv + 1
      local r = vendorRow(nv); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 28
      local where = v[6] and v[6] ~= "" and ("  |cff9d9d9d" .. v[6] .. (v[4] and string.format(" (%.1f, %.1f)", v[4], v[5]) or "") .. "|r") or ""
      r.text:SetText(v[2] .. where)
      if v[3] and v[4] then
        r.map:Show(); r.map:SetScript("OnClick", function() FLT:ShowOnMap({ mapID = v[3], x = v[4], y = v[5], zone = v[6], name = v[2] }) end)
      else r.map:Hide() end
    end
    if nv == 0 then
      nv = 1; local r = vendorRow(1); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 28
      r.text:SetText("|cff9d9d9dNot known yet|r"); r.map:Hide()
    end
    y = y - 6
    itemsTitle:ClearAllPoints(); itemsTitle:SetPoint("TOPLEFT", 2, y)
    local kind = P.kind or "all"
    local kx = DW - 4
    for i = #kindButtons, 1, -1 do
      local b = kindButtons[i]; b:ClearAllPoints(); kx = kx - 72; b:SetPoint("TOPLEFT", kx, y + 2); b:SetActive(b.key == kind)
    end
    y = y - 28
    for _, r in ipairs(repItemRows) do r:Hide() end
    for _, h in ipairs(repBands) do h:Hide() end
    local list = {}
    for i, it in ipairs(f.i) do if kind == "all" or it[7] == kind then list[#list + 1] = { it = it, i = i } end end
    table.sort(list, function(a, b)
      if a.it[6] ~= b.it[6] then return a.it[6] < b.it[6] end
      local ka, kb = KIND_ORDER[a.it[7]] or 9, KIND_ORDER[b.it[7]] or 9
      if ka ~= kb then return ka < kb end
      return a.i < b.i
    end)
    local n, nb, lastRank, folded = 0, 0, nil, false
    for _, e in ipairs(list) do
      local it = e.it
      if it[6] ~= lastRank then
        lastRank = it[6]
        nb = nb + 1
        local h = repBand(nb); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, y - (nb > 1 and 6 or 0)); h:Show()
        h.key = f.n .. ":" .. it[6]; folded = repFolded[h.key] or false
        if folded then h.ch:SetTexCoord(0.5, 1, 0, 1) else h.ch:SetTexCoord(0, 0.5, 0, 1) end
        y = y - 32 - (nb > 1 and 6 or 0)
        local rc = RANK_COLOR[it[6]] or TEXT
        h.text:SetText(RANK_LABEL[it[6]] or "?"); h.text:SetTextColor(rc[1], rc[2], rc[3])
        if f.st == 0 then h.right:SetText("")
        elseif rankReached(it[6], stid) then h.right:SetText("|cff66dd66Reached - you can buy these|r")
        else h.right:SetText("|cff9d9d9dNot reached yet|r") end
      end
      if not folded then
        n = n + 1
        local r = repItemRow(n); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:Show(); y = y - 37
        r.it = it; r.itName = itemName(it[1], it[2])
        setItemIcon(r.icon, it[1], it[5])
        r.name:SetText(r.itName); r.name:SetTextColor(qualityColor(it[4]))
        local kindText = it[7] == "recipe" and "Recipe" or (it[3] or (it[7] == "gear" and "Gear" or "Item"))
        if it[9] and #it[9] > 0 then kindText = kindText .. string.format("  ·  %d variants", #it[9] + 1) end
        r.sub:SetText(kindText)
        local reached = rankReached(it[6], stid)
        FLT.Desat(r.icon, not reached); r.icon:SetAlpha(reached and 1 or 0.6)
        r.star:SetItem(it[1])
        local own = ownedWhere(it[1])
        for _, alt in ipairs(it[9] or {}) do own = own or ownedWhere(alt) end
        r.check:SetShown(own ~= nil)
      end
    end
    if n == 0 then y = y - 4 end
    repNote:ClearAllPoints(); repNote:SetPoint("TOPLEFT", 2, y - 4)
    repNote:SetText("Rewards of the ranks you have not reached yet are greyed out. A green check marks items you own.")
    y = y - 40
    rdetail:SetHeight(-y)
  end

  -- GEAR PLANNER (UI/GearPlanner.lua) -----------------------------------------
  local gear = UI.CreateGearPlanner(body)
  views.gear = gear

  -- NAVIGATION ---------------------------------------------------------------
  show = function(key)
    current = key
    hideViews(); setNav(key)
    filterBar:SetShown(key ~= "rep" and key ~= "gear")
    if key == "gear" then gear:Show(); gear:Refresh()
    elseif key == "rep" then repView:Show(); refreshRep()
    else
      local tabs = TABS[key] ~= nil
      tabBar:SetShown(tabs)
      if tabs then paintTabs() end
      setView:ClearAllPoints(); setView:SetPoint("TOPLEFT", 0, tabs and -68 or -36); setView:SetPoint("BOTTOMRIGHT", 0, 0)
      setView:Show(); refreshSets()
    end
    if key == "gear" or key == "rep" then tabBar:Hide() end
  end
  local navY = navTop
  local function navButton(key, label, icon)
    local b; b, navY = UI.NavEntry(nav, navY, label, icon)
    b:SetScript("OnClick", function() show(key) end)
    navButtons[key] = b
    return b
  end
  local function divider() navY = UI.NavSeparator(nav, navY) end
  navButton("gear", "Gear Planner", "Interface\\Icons\\INV_Misc_Note_05")
  divider()
  for _, g in ipairs(GROUPS) do navButton(g.key, g.label, g.icon) end
  divider()
  navButton("rep", "Reputation", "Interface\\Icons\\INV_Misc_Note_02")
  divider()
  for _, l in ipairs({ { "Mounts", "Interface\\Icons\\Ability_Mount_RidingHorse" }, { "Legendaries", "Interface\\Icons\\INV_Staff_Medivh" } }) do
    local b; b, navY = UI.NavEntry(nav, navY, l[1], l[2])
    b._label:SetTextColor(0.5, 0.5, 0.5); if b.icon then FLT.Desat(b.icon, true); b.icon:SetAlpha(0.5) end
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(l[1], 1, 0.82, 0); GameTooltip:AddLine("Coming in a later version.", 1, 1, 1); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- Item names and ownership arrive later: redraw (throttled) while visible.
  local pending, gearChanged = false, false
  local function redraw()
    pending = false
    local changed = gearChanged; gearChanged = false
    if not panel:IsVisible() then return end
    if current == "rep" then refreshRep(true) elseif current == "gear" then gear:Refresh(changed) elseif current then refreshSets(true) end
  end
  local ev = CreateFrame("Frame", nil, panel)
  ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  ev:RegisterEvent("BAG_UPDATE_DELAYED")
  ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  ev:RegisterEvent("UPDATE_FACTION")
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_EQUIPMENT_CHANGED" then gearChanged = true end
    if pending or not panel:IsVisible() then return end
    pending = true
    if C_Timer and C_Timer.After then C_Timer.After(0.4, function() FLT.SafeCall("Armory", redraw) end) else redraw() end
  end)
  panel.Refresh = function() if panel:IsVisible() and current then show(current) end end

  show("gear")
  panel:Hide()
  return panel
end

UI.RegisterPanel({ key = "armory", label = "Armory", order = 1, tabWidth = 96, create = createArmoryPanel })
