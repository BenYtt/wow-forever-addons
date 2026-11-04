local _, FLT = ...

-- Crafting List (5.7.3, user 24.10.): plan what to craft. Recipes go on one list for the whole account ("+ List" in
-- the Professions recipe view); a window of its own shows the materials against what you have in your bags, your bank
-- and on your other characters (same realm and faction), and what is still missing. Materials you can craft
-- yourself (Bolt of Silk, bars ...) are broken down into their own materials when one of your characters knows the
-- recipe; a switch per material says "craft" or "buy" (user's choice c). Reagents a vendor sells are marked (Data/
-- VendorReagents.lua). The window stays open when OneForAll closes and only closes with its X (not with Escape).
-- Item tooltips show "Crafting List: N more needed" for missing materials.
-- Saved: OneForAllDB.craftList = { {prof, s = spell, n = items}, ... }, OneForAllDB.craftMode[itemID] = "craft" / "buy",
-- OneForAllDB.craftInv[name-realm] = { faction, bags = {[id] = n}, bank = {[id] = n} } (only reagents of our recipes),
-- OneForAllDB.craftListPos. Known recipes of the other characters: OneForAllDB.altRecipes (QoL.lua).
-- Lean: bags are counted 2 s after the last bag update (one timer), the bank while it is open; the materials are
-- worked out only when the window is open or a tooltip asks (cached until the next change).

local CL = {}
FLT.CraftList = CL
local UI = FLT.UI
local GetItemCount = GetItemCount or (C_Item and C_Item.GetItemCount)
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

local function db(key)
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB[key] = OneForAllDB[key] or {}
  return OneForAllDB[key]
end
local function list() return db("craftList") end
local function charKey()
  local n = UnitName and UnitName("player")
  return n and (n .. "-" .. (GetRealmName and GetRealmName() or "")) or nil
end

-- Recipe index ----------------------------------------------------------------------
local bySpell, byItem, reagent -- spell -> {r, prof}; crafted item -> list of {r, prof}; reagent / crafted ids
local function index()
  if bySpell then return end
  bySpell, byItem, reagent = {}, {}, {}
  for prof, recipes in pairs(FLT.PROFESSION_RECIPES or {}) do
    for _, r in ipairs(recipes) do
      local e = { r = r, prof = prof }
      bySpell[r.s] = e
      local selfUse = false -- e.g. "The Mortar: Reloaded" needs a Goblin Mortar to make one: never a way to make it
      for _, g in ipairs(r.r or {}) do if g[1] == r.i then selfUse = true end end
      if r.i and not selfUse then
        local l = byItem[r.i]; if not l then l = {}; byItem[r.i] = l end
        l[#l + 1] = e; reagent[r.i] = true
      end
      for _, g in ipairs(r.r or {}) do reagent[g[1]] = true end
    end
  end
end
function CL.Recipe(spell) index(); return bySpell[spell] end

-- this character can craft a recipe: known; or, with the profession, a starter recipe ("Known when you learn ...") or
-- any recipe within its skill while the profession window was never opened (nothing known yet, user 24.10.)
function CL.ICanCraft(prof, r)
  local p = FLT.GetProfessionState and FLT.GetProfessionState(prof)
  if not (p and p.known) then return false end
  if p.known[r.s] then return true end
  local skill = p.skill or 0
  if skill <= 0 then return false end
  return r.start or (next(p.known) == nil and skill >= (r.req or r.y or 1)) or false
end
-- who of my characters knows a recipe (OneForAllDB.altRecipes, kept by QoL.lua; this character live)
local function knownBy(prof, spell)
  local me = charKey()
  local x = bySpell and bySpell[spell]
  if x and CL.ICanCraft(prof, x.r) then return UnitName("player") end
  for key, data in pairs(type(OneForAllDB) == "table" and OneForAllDB.altRecipes or {}) do
    if key ~= me and type(data) == "table" and type(data[prof]) == "table" and data[prof][spell] then
      return key:match("^([^%-]+)") or key
    end
  end
end
-- the recipe that makes an item and who knows it (a known one first)
local function makerOf(id)
  local l = byItem[id]
  if not l then return nil end
  for _, e in ipairs(l) do local who = knownBy(e.prof, e.r.s); if who then return e, who end end
  return l[1], nil
end

-- Stock -----------------------------------------------------------------------------
local function numSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end
local function slotItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local i = C_Container.GetContainerItemInfo(bag, slot)
    if type(i) == "table" then return i.itemID, i.stackCount or 1 end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
    id = id or (link and tonumber(link:match("item:(%d+)")))
    return id, count or 1
  end
end
local function me()
  local key = charKey(); if not key then return nil end
  local inv = db("craftInv")
  local c = inv[key]
  if not c then c = { bags = {}, bank = {} }; inv[key] = c end
  c.faction = UnitFactionGroup and UnitFactionGroup("player") or c.faction
  return c
end
local function scan(c, field, bags)
  index()
  local t = c[field]; wipe(t)
  for _, bag in ipairs(bags) do
    for slot = 1, numSlots(bag) do
      local id, n = slotItem(bag, slot)
      if id and reagent[id] then t[id] = (t[id] or 0) + n end
    end
  end
end
local BAGS, BANK = { 0, 1, 2, 3, 4 }, { -1, 5, 6, 7, 8, 9, 10, 11 }

-- what I have of an item: total and the places (for the tooltip). This character: bags live, bank as last seen.
local places = {} -- reused
local function stock(id)
  wipe(places)
  local c, key = me(), charKey()
  local bags = GetItemCount and GetItemCount(id) or (c and c.bags[id]) or 0
  local bank = c and c.bank[id] or 0
  local total = bags + bank
  if bags > 0 then places[#places + 1] = "Bags " .. bags end
  if bank > 0 then places[#places + 1] = "Bank " .. bank end
  local realm = key and key:match("%-(.*)$")
  local fac = c and c.faction
  for k, o in pairs(db("craftInv")) do
    if k ~= key and k:match("%-(.*)$") == realm and (not fac or not o.faction or o.faction == fac) then
      local b, k2 = o.bags and o.bags[id] or 0, o.bank and o.bank[id] or 0
      if b + k2 > 0 then
        total = total + b + k2
        local parts = {}
        if b > 0 then parts[#parts + 1] = b .. " bags" end
        if k2 > 0 then parts[#parts + 1] = k2 .. " bank" end
        places[#places + 1] = (k:match("^([^%-]+)") or k) .. ": " .. table.concat(parts, ", ")
      end
    end
  end
  return total
end

-- Materials -------------------------------------------------------------------------
-- rows: { id, need, have, depth, maker = {r, prof}, who, craft = n (crafted), miss = n (to get), mode }
local rows, shop, dirty = {}, {}, true
local function compute()
  index()
  wipe(rows); wipe(shop)
  local pool = {}
  local function take(id, need)
    if pool[id] == nil then pool[id] = stock(id) end
    local use = math.min(pool[id], need); pool[id] = pool[id] - use
    return use
  end
  local mode = db("craftMode")
  local path = {} -- items being broken down in the current branch: no item inside its own branch (transmute circles)
  local function isTransmute(m) return m and (m.r.cat or ""):find("Transmut", 1, true) end
  -- noTransmute: the material of a transmute is never transmuted itself (user 26.10.: Essence of Earth <- Fire <- Air
  -- <- Water <- Earth chains); it is simply to get
  local function node(id, name, need, depth, noTransmute)
    local have = take(id, need)
    local row = { id = id, name = name, need = need, have = have, depth = depth }
    rows[#rows + 1] = row
    local miss = need - have
    local maker, who = makerOf(id)
    if noTransmute and isTransmute(maker) then maker, who = nil, nil end
    if maker then
      row.maker, row.who = maker, who
      -- transmutes are never ticked by themselves (user 24.10.: Essence of Water -> Earth -> Fire chains)
      local transmute = isTransmute(maker)
      row.default = (who and not transmute) and "craft" or "buy"
      row.mode = mode[id] or row.default
    end
    if miss > 0 and maker and row.mode == "craft" and depth < 6 and not path[id] then
      row.craft = miss
      path[id] = true
      local crafts = math.ceil(miss / (maker.r.c or 1))
      row.ok = true
      local tm = isTransmute(maker) and true or nil
      for _, g in ipairs(maker.r.r or {}) do if not node(g[1], g[3], g[2] * crafts, depth + 1, tm) then row.ok = false end end
      path[id] = nil
    elseif miss > 0 then
      row.miss = miss; shop[id] = (shop[id] or 0) + miss
    else
      row.ok = true
    end
    return row.ok
  end
  -- the direct materials of all planned recipes, added up, in list order
  local need, order, names, tmIn = {}, {}, {}, {}
  for _, e in ipairs(list()) do
    local x = bySpell[e.s]
    if x then
      local crafts = math.ceil((e.n or 1) / (x.r.c or 1))
      for _, g in ipairs(x.r.r or {}) do
        if not need[g[1]] then order[#order + 1] = g[1]; need[g[1]] = 0; names[g[1]] = g[3] end
        need[g[1]] = need[g[1]] + g[2] * crafts
        if isTransmute(x) then tmIn[g[1]] = true end -- a planned transmute: its material is not transmuted again
      end
    end
  end
  for _, id in ipairs(order) do node(id, names[id], need[id], 0, tmIn[id]) end
  dirty = false
end

-- tooltip line (QoL.lua item tooltip hook)
function CL.TooltipLine(tt, id)
  if #list() == 0 then return end
  if dirty then compute() end
  local n = shop[id]
  if n and n > 0 then tt:AddLine(string.format("Crafting List: %d more needed", n), 1, 0.82, 0.25) end
end

-- List ------------------------------------------------------------------------------
local refresh -- the window, below
local function changed() dirty = true; if refresh then refresh() end end
function CL.Add(prof, spell, n)
  n = math.max(1, math.floor(tonumber(n) or 1))
  for _, e in ipairs(list()) do if e.s == spell then e.n = e.n + n; changed(); return end end
  local l = list(); l[#l + 1] = { prof = prof, s = spell, n = n }
  changed()
end
function CL.Count(spell) for _, e in ipairs(list()) do if e.s == spell then return e.n end end return 0 end

-- Window ----------------------------------------------------------------------------
local secureCraft -- the secure Craft behaviour, below (Recipe bar)
local frame, child, sf, emptyText
local W = 360 -- a small helper next to the game, not half the screen (user 26.10.)
local pool, used = {}, 0
local GOLD = { 1, 0.82, 0.20 }

-- items not cached yet (fresh client): ask the server and redraw once a moment later (user 26.10.: "Item 3371")
local namePending
local function itemName(id, fallback)
  local n, _, q
  if GetItemInfo then n, _, q = GetItemInfo(id) end -- not "a, b = f and f()": that keeps only one value
  if not n and C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, id)
    if not namePending and C_Timer and C_Timer.After then
      namePending = true
      C_Timer.After(1, function() namePending = nil; if refresh then refresh() end end)
    end
  end
  return n or fallback or ("Item " .. id), q
end
local function qcolor(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function rowTooltip(self)
  local r = self.data
  if not r then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID and r.id then GameTooltip:SetItemByID(r.id) else GameTooltip:AddLine(itemName(r.id, r.name)) end
  if r.need then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Crafting List", GOLD[1], GOLD[2], GOLD[3])
    stock(r.id)
    if #places > 0 then for _, p in ipairs(places) do GameTooltip:AddLine(p, 1, 1, 1) end
    else GameTooltip:AddLine("None in your bags, bank or on your other characters.", 0.8, 0.8, 0.8, true) end
    if r.maker then
      GameTooltip:AddLine(r.who and ("Can be crafted by " .. r.who .. " (" .. r.maker.prof .. ")") or ("Crafted with " .. r.maker.prof .. " - none of your characters knows the recipe"), 0.6, 0.85, 1, true)
    end
    if FLT.VENDOR_REAGENTS and FLT.VENDOR_REAGENTS[r.id] then GameTooltip:AddLine("Sold by vendors", 0.45, 1, 0.45) end
  end
  GameTooltip:Show()
end

-- compact rows (user 26.10.: the window was too big); a soft green fill when the material is there
local ROW_H, ROW_STEP = 26, 28 -- a bit bigger again, same window (user 26.10.)
local function newRow()
  local b = CreateFrame("Button", nil, child); b:SetHeight(ROW_H)
  b.ok = UI.makeTexture(b, "BACKGROUND", 0.10, 0.42, 0.14, 0.22); b.ok:SetAllPoints()
  local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.07))
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(22, 22)
  b.name = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
  b.tag = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall")
  -- c3 = "have / need" (or the missing amount in "To get"), c2 = "craft N" left of it
  b.c2 = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlightSmall"); b.c2:SetWidth(50); b.c2:SetJustifyH("RIGHT"); b.c2:SetPoint("RIGHT", -62, 0)
  b.c3 = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.c3:SetWidth(58); b.c3:SetJustifyH("RIGHT"); b.c3:SetPoint("RIGHT", -4, 0)
  b.c1 = b.c2 -- anchor for the name and the small Craft button
  -- "craft it myself" for materials a recipe makes (user 24.10.: a tick instead of a Craft / Buy button)
  b.mode = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate") -- header test: stays a checkbox here (user 31.10.); b.mode:SetSize(22, 22)
  b.minus = UI.GoldButton(b, "-", 20, 20, nil, 12); b.plus = UI.GoldButton(b, "+", 20, 20, nil, 12)
  b.del = UI.GoldButton(b, "", 20, 20, UI.ASSET_ROOT .. "icon_close", 10)
  if b.del.icon then b.del.icon:ClearAllPoints(); b.del.icon:SetSize(9, 9); b.del.icon:SetPoint("CENTER") end
  b.del:SetPoint("RIGHT", -4, 0); b.plus:SetPoint("RIGHT", b.del, "LEFT", -6, 0); b.minus:SetPoint("RIGHT", b.plus, "LEFT", -28, 0)
  -- small "Craft" (user 24.10.): only the look; the secure button "overlay" is laid over it on mouse-over
  b.craftBtn = UI.GoldButton(b, "Craft", 46, 20, nil, 11)
  b.craftBtn:SetScript("OnEnter", function(self) if CL._hoverCraft then CL._hoverCraft(self) end end)
  b.count = FLT.NewFS(b, nil, "OVERLAY", "GameFontHighlight"); b.count:SetPoint("LEFT", b.minus, "RIGHT", 2, 0); b.count:SetPoint("RIGHT", b.plus, "LEFT", -2, 0)
  b:SetScript("OnEnter", rowTooltip); b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Shift-click: item link into the chat or the auction house search, Ctrl-click: dressing room (user 26.10.)
  b:SetScript("OnClick", function(self, button)
    local H = UI.DungeonHelpers
    if self.data and self.data.id and H and H.handleDungeonItemClick then H.handleDungeonItemClick({ id = self.data.id }, button) end
  end)
  return b
end
local function acquire()
  used = used + 1
  local b = pool[used]
  if not b then b = newRow(); pool[used] = b end
  b:ClearAllPoints(); b:Show()
  for _, k in ipairs({ "mode", "minus", "plus", "del", "count", "c2", "c3", "tag", "craftBtn", "ok" }) do b[k]:Hide() end
  b.data = nil
  return b
end

local headers = {}
-- cols: texts over the three number columns of the rows (same anchors)
local function header(i, text, y, cols)
  local h = headers[i]
  if not h then
    h = CreateFrame("Frame", nil, child); h:SetHeight(20)
    h.t = FLT.NewFS(h, nil, "OVERLAY", "GameFontNormal"); h.t:SetPoint("LEFT", 2, 0); h.t:SetTextColor(FLT.SkinC(unpack(GOLD)))
    h.line = UI.makeTexture(h, "ARTWORK", 0.72, 0.50, 0.12, 0.45); h.line:SetPoint("BOTTOMLEFT"); h.line:SetPoint("BOTTOMRIGHT"); h.line:SetHeight(1)
    h.c = {}
    for k, x in ipairs({ -100, -62, -4 }) do
      local c = FLT.NewFS(h, nil, "OVERLAY", "GameFontDisableSmall"); c:SetJustifyH("RIGHT"); c:SetPoint("RIGHT", x, 0); h.c[k] = c
    end
    headers[i] = h
  end
  h:ClearAllPoints(); h:SetPoint("TOPLEFT", 8, y); h:SetPoint("RIGHT", child, "RIGHT", -8, 0); h:Show()
  h.t:SetText(text)
  for k = 1, 3 do h.c[k]:SetText(cols and cols[k] or "") end
  return y - 24
end

local function place(b, y, depth, tick)
  b:SetPoint("TOPLEFT", 4, y); b:SetPoint("RIGHT", child, "RIGHT", -4, 0)
  local x = 4 + (depth or 0) * 16 + (tick and 22 or 0) -- material rows keep a column for the tick
  b.icon:ClearAllPoints(); b.icon:SetPoint("LEFT", x, 0)
  if tick then b.mode:ClearAllPoints(); b.mode:SetPoint("RIGHT", b.icon, "LEFT", -1, 0) end
  b.name:ClearAllPoints(); b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  return y - ROW_STEP
end

refresh = function()
  if not (frame and frame:IsShown()) then return end
  compute()
  for i = 1, used do pool[i]:Hide() end
  used = 0
  for _, h in pairs(headers) do h:Hide() end
  local l = list()
  emptyText:SetShown(#l == 0)
  frame.clear:SetShown(#l > 0)
  if #l == 0 then child:SetHeight(1); return end
  local y = -6
  -- planned items
  y = header(1, "Planned", y)
  for _, e in ipairs(l) do
    local x = bySpell[e.s]
    local b = acquire()
    y = place(b, y, 0)
    local r = x and x.r
    b.icon:SetTexture((r and r.i and GetItemIcon and GetItemIcon(r.i)) or "Interface\\Icons\\Trade_Engraving")
    local name, q = r and r.i and itemName(r.i, r.n) or (r and r.n or ("Recipe " .. e.s)), r and r.q
    b.name:SetText(name); b.name:SetTextColor(qcolor(q)); b.name:SetPoint("RIGHT", b.minus, "LEFT", -6, 0)
    if r and CL.ICanCraft(x.prof, r) then
      b.craftBtn:ClearAllPoints(); b.craftBtn:SetPoint("RIGHT", b.minus, "LEFT", -6, 0); b.craftBtn:SetLabel("Craft"); b.craftBtn:Show()
      b.craftBtn.target = { prof = x.prof, r = r, n = math.ceil(e.n / (r.c or 1)) }
      b.name:SetPoint("RIGHT", b.craftBtn, "LEFT", -4, 0)
    end
    b.data = r and r.i and { id = r.i } or nil
    b.count:SetText(e.n); b.count:Show(); b.minus:Show(); b.plus:Show(); b.del:Show()
    b.ok:SetShown(next(shop) == nil) -- everything for the list is there
    b.minus:SetScript("OnClick", function() if e.n > 1 then e.n = e.n - 1; changed() end end)
    b.plus:SetScript("OnClick", function() e.n = e.n + 1; changed() end)
    b.del:SetScript("OnClick", function() for j, x in ipairs(l) do if x == e then table.remove(l, j); break end end changed() end)
  end
  -- materials (tree)
  y = header(2, "Materials", y - 6, { nil, nil, "Have / Need" })
  for _, row in ipairs(rows) do
    local b = acquire()
    y = place(b, y, row.depth, true)
    b.data = row
    b.icon:SetTexture(GetItemIcon and GetItemIcon(row.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local name, q = itemName(row.id, row.name)
    b.name:SetText(name); b.name:SetTextColor(qcolor(q)); b.name:SetPoint("RIGHT", b.c2, "LEFT", -50, 0)
    if row.craft and CL.ICanCraft(row.maker.prof, row.maker.r) then
      b.craftBtn:ClearAllPoints(); b.craftBtn:SetPoint("RIGHT", b.c2, "LEFT", -2, 0); b.craftBtn:SetLabel("Craft"); b.craftBtn:Show()
      b.craftBtn.target = { prof = row.maker.prof, r = row.maker.r, n = math.ceil(row.craft / (row.maker.r.c or 1)) }
    end
    local col = row.have >= row.need and "|cff59ff73" or (row.craft and "|cff9fd0ff" or "|cffff6060")
    b.c3:SetText(col .. row.have .. "|r / " .. row.need); b.c3:Show()
    if row.craft then b.c2:SetText("|cff9fd0ffcraft " .. row.craft .. "|r"); b.c2:Show() end
    b.ok:SetShown(row.have >= row.need) -- green only when the material itself is there (not "can be crafted", user 25.10.)
    if row.maker then
      b.mode:SetChecked(row.mode == "craft"); b.mode:Show()
      b.mode:SetScript("OnClick", function(self)
        local want = self:GetChecked() and "craft" or "buy"
        db("craftMode")[row.id] = (want == row.default) and nil or want -- only differences from the default are saved
        changed()
      end)
      b.mode:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Craft yourself"); GameTooltip:Show() -- short (user 24.10.)
      end)
      b.mode:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end
  -- to get
  local ids = {}
  for id in pairs(shop) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b2) return (itemName(a)) < (itemName(b2)) end)
  y = header(3, "To get", y - 6, { nil, nil, #ids == 0 and "|cff59ff73You have everything|r" or "Missing" })
  for _, id in ipairs(ids) do
    local b = acquire()
    y = place(b, y, 0)
    b.data = { id = id }
    b.icon:SetTexture(GetItemIcon and GetItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
    local name, q = itemName(id)
    b.name:SetText(name); b.name:SetTextColor(qcolor(q)); b.name:SetPoint("RIGHT", b.c3, "LEFT", -50, 0)
    if FLT.VENDOR_REAGENTS and FLT.VENDOR_REAGENTS[id] then b.tag:SetText("Vendor"); b.tag:ClearAllPoints(); b.tag:SetPoint("RIGHT", b.c3, "LEFT", -6, 0); b.tag:Show() end
    b.c3:SetText("|cffff6060" .. shop[id] .. "|r"); b.c3:Show()
  end
  child:SetHeight(-y + 8)
end

local function create()
  frame = CreateFrame("Frame", "OneForAllCraftList", UIParent)
  -- above the OneForAll window (DIALOG), so it cannot disappear behind it (user 24.10.)
  local h = OneForAllDB and tonumber(OneForAllDB.craftListH)
  frame:SetSize(W, h or 360); frame:SetFrameStrata("FULLSCREEN"); frame:SetClampedToScreen(true)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  local pos = OneForAllDB and OneForAllDB.craftListPos
  if type(pos) == "table" then frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else frame:SetPoint("RIGHT", -60, 0) end
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    if type(OneForAllDB) == "table" then OneForAllDB.craftListPos = { p, rp, x, y } end
  end)
  UI.FramedPanel(frame)
  for _, t in ipairs(UI.OrnateFrame(frame, frame, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local close = UI.CloseButton(frame); close:SetPoint("TOPRIGHT", -12, -12) -- the only way to close it (user 24.10.)
  local title = FLT.NewFS(frame, nil, "OVERLAY", "GameFontNormal"); title:SetPoint("TOPLEFT", 18, -15)
  title:SetText("Crafting List"); title:SetTextColor(FLT.SkinC(unpack(GOLD)))
  sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 8, -34); sf:SetPoint("BOTTOMRIGHT", -30, 36)
  child = CreateFrame("Frame", nil, sf); child:SetSize(W - 38, 10); sf:SetScrollChild(child)
  if UI.PlaceScrollBar then UI.PlaceScrollBar(sf) end
  emptyText = FLT.NewFS(frame, nil, "OVERLAY", "GameFontDisable"); emptyText:SetPoint("TOP", 0, -80); emptyText:SetWidth(W - 60)
  emptyText:SetText("Nothing planned yet.\nOpen a recipe in Professions and click \"+ List\".\n\nCounts your bags, bank and other characters (a character counts once it logged in, its bank once opened).")
  frame.clear = UI.GoldButton(frame, "Clear list", 80, 20, nil, 11); frame.clear:SetPoint("BOTTOMLEFT", 14, 12)
  frame.clear:SetScript("OnClick", function()
    if UI.Confirm then UI.Confirm("Remove everything from the Crafting List?", function() wipe(list()); changed() end)
    else wipe(list()); changed() end
  end)
  -- one secure Craft button, laid over the small "Craft" of the row under the mouse (secure buttons cannot be
  -- moved in combat, rows are reused, so there is only this one; it opens the profession window, then crafts)
  local ov = CreateFrame("Button", "OneForAllCraftListCraft", frame, "SecureActionButtonTemplate"); ov:Hide()
  UI.CombatDetach(ov) -- not inside the Crafting List window in combat, so the window can still be closed
  local ohl = ov:CreateTexture(nil, "HIGHLIGHT"); ohl:SetAllPoints(); ohl:SetColorTexture(FLT.SkinC(1, 0.82, 0.3, 0.15))
  secureCraft(ov, function() if ov.t then return ov.t.prof, ov.t.r, ov.t.n end end, function(t) if ov.fake then ov.fake:SetLabel(t) end end)
  ov:SetScript("OnEnter", function(self)
    if not self.t then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Craft " .. self.t.n .. "x", 1, 0.82, 0)
    GameTooltip:AddLine("Opens your profession window if it is closed; click again to craft.", 1, 1, 1, true); GameTooltip:Show()
  end)
  ov:SetScript("OnLeave", function(self) GameTooltip:Hide(); if not (InCombatLockdown and InCombatLockdown()) then self:Hide() end end)
  CL._hoverCraft = function(fake)
    if InCombatLockdown and InCombatLockdown() then return end
    ov:ClearAllPoints(); ov:SetAllPoints(fake); ov:SetFrameLevel(fake:GetFrameLevel() + 5)
    ov.t, ov.fake = fake.target, fake
    ov:Show()
  end
  -- like the OneForAll window (user 26.10.): the corner grip scales the whole list, the bottom grip sets its height.
  -- Scale: OneForAllDB.craftListScale (unset = the OneForAll window's scale), height: OneForAllDB.craftListH.
  local function cdb() return type(OneForAllDB) == "table" and OneForAllDB or {} end
  local function setScale(sc)
    sc = math.floor(math.max(0.6, math.min(1.4, sc)) * 100 + 0.5) / 100
    local old, left, top = frame:GetScale() or 1, frame:GetLeft(), frame:GetTop()
    frame:SetScale(sc)
    if left and top then -- the top left corner stays where it is
      frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / sc, top * old / sc)
    end
    cdb().craftListScale = sc
  end
  local function savePos()
    local p, _, rp, x, y = frame:GetPoint(1)
    cdb().craftListPos = { p, rp, x, y }
  end
  local function dragGrip(g, tipTitle, tipText, onMove)
    g:SetFrameLevel(frame:GetFrameLevel() + 20)
    g:SetScript("OnMouseDown", function(self, button)
      if button ~= "LeftButton" then return end
      self:SetScript("OnUpdate", onMove) -- only while dragging
    end)
    local function stop(self) self:SetScript("OnUpdate", nil); savePos() end
    g:SetScript("OnMouseUp", stop); g:SetScript("OnHide", stop)
    g:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(tipTitle, 1, 0.82, 0)
      GameTooltip:AddLine(tipText, 1, 1, 1, true); GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local grip = CreateFrame("Button", nil, frame); grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -9, 9)
  local GRIP = UI.ASSET_ROOT .. "grip_resize"
  grip:SetNormalTexture(GRIP); grip:SetHighlightTexture(GRIP); grip:SetPushedTexture(GRIP)
  local ht = grip:GetHighlightTexture(); if ht and ht.SetBlendMode then ht:SetBlendMode("ADD") end
  if FLT.SkinArtTex then FLT.SkinArtTex(grip:GetNormalTexture()); FLT.SkinArtTex(grip:GetHighlightTexture()); FLT.SkinArtTex(grip:GetPushedTexture()) end
  dragGrip(grip, "Resize", "Drag to scale the whole list.", function()
    local cx = GetCursorPosition()
    local w = cx - frame:GetLeft() * frame:GetEffectiveScale()
    if w > 0 then
      local sc = w / (W * UIParent:GetEffectiveScale())
      if math.abs(sc - (frame:GetScale() or 1)) >= 0.01 then setScale(sc) end
    end
  end)
  local hgrip = CreateFrame("Button", nil, frame); hgrip:SetSize(90, 14); hgrip:SetPoint("BOTTOM", 0, 3)
  local bar = hgrip:CreateTexture(nil, "ARTWORK"); bar:SetSize(48, 12); bar:SetPoint("CENTER"); FLT.SetTex(bar, UI.ASSET_ROOT .. "grip_height"); bar:SetAlpha(0.8)
  local hi = hgrip:CreateTexture(nil, "HIGHLIGHT"); hi:SetSize(48, 12); hi:SetPoint("CENTER"); FLT.SetTex(hi, UI.ASSET_ROOT .. "grip_height"); hi:SetBlendMode("ADD")
  dragGrip(hgrip, "Height", "Drag up or down to show more or fewer rows.", function()
    local _, cy = GetCursorPosition()
    local eff = frame:GetEffectiveScale()
    local h = math.floor(math.max(220, math.min(760, (frame:GetTop() * eff - cy) / eff)) + 0.5)
    if h ~= math.floor(frame:GetHeight() + 0.5) then frame:SetHeight(h); cdb().craftListH = h end
  end)
  frame:SetScript("OnShow", function(self)
    local w = type(OneForAllDB) == "table" and OneForAllDB.window
    local sc = tonumber(cdb().craftListScale) or (w and tonumber(w.scale))
    if sc and sc > 0 then self:SetScale(sc) end
    refresh()
  end)
  frame:Hide()
end

function CL.Toggle(show)
  if not frame then create() end
  if show == nil then show = not frame:IsShown() end
  frame:SetShown(show)
end
function CL.Show() CL.Toggle(true) end

-- Recipe bar (Professions recipe view, bottom right): amount, "+ List", "Craft" -------------------
-- Craft: our own profession window cannot be opened by an addon, only by a real click; so the button is a secure
-- one that opens the profession (cast of the profession spell) when its window is not open, and crafts when it is
-- (DoTradeSkill / C_TradeSkillUI.CraftRecipe / DoCraft for the old Enchanting window). Needs a check in the game.
local PROF_SPELL = { Alchemy = 2259, Blacksmithing = 2018, Enchanting = 7411, Engineering = 4036, Leatherworking = 2108,
  Tailoring = 3908, Cooking = 2550, ["First Aid"] = 3273 }
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id))
end
local function profName(prof) return PROF_SPELL[prof] and spellName(PROF_SPELL[prof]) or prof end
local function call(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b, c = pcall(fn, ...); if ok then return a, b, c end end
-- 1 = old trade skill window, 2 = old craft window (Enchanting), 3 = new profession window; nil = not open
local function openWindow(prof)
  local name = profName(prof)
  local T = type(C_TradeSkillUI) == "table" and C_TradeSkillUI or nil
  if T and T.GetBaseProfessionInfo and call(T.IsTradeSkillReady) then
    local info = call(T.GetBaseProfessionInfo)
    if type(info) == "table" and info.professionName == name then return 3 end
  end
  local function shown(f) return type(f) == "table" and f.IsShown and f:IsShown() end
  if shown(TradeSkillFrame) and call(GetTradeSkillLine) == name then return 1 end
  if shown(CraftFrame) and call(GetCraftDisplaySkillLine) == name then return 2 end
end
local function say(text) if FLT.Msg then FLT.Msg(text) end end
local function craft(prof, r, n, how)
  local want = spellName(r.s) or r.n
  if how == 3 then
    if call(C_TradeSkillUI.CraftRecipe, r.s, n) == nil and not C_TradeSkillUI.CraftRecipe then say("Crafting is not possible here.") end
    return
  end
  if how == 2 then
    for i = 1, (call(GetNumCrafts) or 0) do
      if call(GetCraftInfo, i) == want then if DoCraft then DoCraft(i) end return end
    end
  else
    for i = 1, (call(GetNumTradeSkills) or 0) do
      local link = GetTradeSkillRecipeLink and call(GetTradeSkillRecipeLink, i)
      local sid = link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
      if sid == r.s or call(GetTradeSkillInfo, i) == want then if DoTradeSkill then DoTradeSkill(i, n) end return end
    end
  end
  say(want .. " was not found in the profession window (a search or filter there may hide it).")
end

-- secure craft behaviour for a SecureActionButton: target() returns prof, recipe, crafts; onState(text) shows
-- "Craft" / "Craft now"
secureCraft = function(btn, target, onState)
  local openHow
  btn:RegisterForClicks("AnyUp", "AnyDown")
  btn:SetScript("PreClick", function(self)
    openHow = nil
    local prof = target()
    if not prof or (InCombatLockdown and InCombatLockdown()) then return end
    openHow = openWindow(prof)
    if openHow then self:SetAttribute("type", nil)
    else self:SetAttribute("type", "spell"); self:SetAttribute("spell", profName(prof)) end
  end)
  btn:HookScript("OnClick", function()
    local prof, r, n = target()
    if not prof then return end
    if openHow then craft(prof, r, n, openHow); onState("Craft")
    else onState("Craft now") end -- the profession window opens: the next click crafts
  end)
end
CL._secureCraft = secureCraft

function CL.RecipeBar(parent)
  -- stacked (user 24.10.): amount and "+ List", below it "Craft", below that how many are on the list
  local bar = CreateFrame("Frame", nil, parent); bar:SetSize(104, 70)
  bar:SetFrameLevel(parent:GetFrameLevel() + 20) -- above the framed boxes of the recipe view
  local cur -- { prof, r }
  local amount = FLT.SkinBlizz(CreateFrame("EditBox", nil, bar, "InputBoxTemplate"))
  amount:SetSize(32, 20); amount:SetPoint("TOPLEFT", 6, -2); amount:SetAutoFocus(false); amount:SetNumeric(true); amount:SetMaxLetters(3)
  amount:SetJustifyH("CENTER"); amount:SetText("1")
  amount:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  amount:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local function n() return math.max(1, tonumber(amount:GetText()) or 1) end
  local add = UI.GoldButton(bar, "+ List", 60, 24, nil, 12); add:SetPoint("TOPRIGHT", 0, 0)
  local onList = FLT.NewFS(bar, nil, "OVERLAY", "GameFontDisableSmall"); onList:SetPoint("TOP", bar, "TOP", 0, -56)
  add:SetScript("OnClick", function()
    if not cur then return end
    CL.Add(cur.prof, cur.r.s, n()); amount:ClearFocus()
    onList:SetText(CL.Count(cur.r.s) .. " on the list"); CL.Show()
    if bar.onChange then bar.onChange() end -- the recipe view makes room for the "on the list" line
  end)
  add:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Add to the Crafting List", 1, 0.82, 0)
    GameTooltip:AddLine("Plans this many and shows the materials you have and still need.", 1, 1, 1, true); GameTooltip:Show()
  end)
  add:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- secure, so it may open the profession window
  local cb = CreateFrame("Button", "OneForAllCraftButton", bar, "SecureActionButtonTemplate")
  cb:SetSize(104, 24); cb:SetPoint("TOPRIGHT", 0, -28)
  UI.Plate(cb, 24)
  cb.label = FLT.NewFS(cb, nil, "OVERLAY", "GameFontNormal"); cb.label:SetPoint("CENTER")
  cb.label:SetTextColor(FLT.SkinC(0.95, 0.82, 0.50)); cb.label:SetText("Craft")
  secureCraft(cb, function() if cur then return cur.prof, cur.r, n() end end, function(t) cb.label:SetText(t) end)
  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Craft", 1, 0.82, 0)
    GameTooltip:AddLine("Opens your profession window if it is closed; click again to craft the amount on the left.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- in combat the button leaves the OneForAll window (else the window could not be closed in combat, user 30.10.)
  UI.CombatDetach(cb, function() if cur then cb:SetShown(CL.ICanCraft(cur.prof, cur.r)); cb.label:SetText("Craft") end end)
  -- height actually used: the "N on the list" line only when something is on the list (no empty line, user 24.10.)
  function bar:UsedHeight() return (onList:GetText() or "") ~= "" and 68 or 52 end
  -- the bar holds the secure Craft button, so in combat it may not be shown / hidden (ADDON_ACTION_BLOCKED,
  -- user 26.10.): then only its alpha changes, and the real show / hide follows after combat
  local wantShown
  local after = CreateFrame("Frame")
  after:SetScript("OnEvent", function(f)
    f:UnregisterAllEvents()
    bar:SetAlpha(1); bar:SetShown(wantShown)
    if cur then cb:SetShown(CL.ICanCraft(cur.prof, cur.r)); cb.label:SetText("Craft") end
  end)
  local function show(on)
    wantShown = on
    if InCombatLockdown and InCombatLockdown() then
      bar:SetAlpha(on and 1 or 0); after:RegisterEvent("PLAYER_REGEN_ENABLED")
    else bar:SetAlpha(1); bar:SetShown(on) end
  end
  function bar:SetRecipe(prof, r)
    cur = (prof and r) and { prof = prof, r = r } or nil
    show(cur ~= nil)
    if not cur then return end
    onList:SetText(CL.Count(r.s) > 0 and (CL.Count(r.s) .. " on the list") or "")
    -- the secure button can only be shown / hidden outside combat
    if not (InCombatLockdown and InCombatLockdown()) then
      cb:SetShown(CL.ICanCraft(prof, r))
      cb.label:SetText("Craft")
    end
  end
  return bar
end

-- Events: stock of this character ------------------------------------------------------
local bankOpen, pending
local function bagsLater()
  if pending or not (C_Timer and C_Timer.After) then return end
  pending = true
  C_Timer.After(2, function()
    pending = false
    local c = me(); if not c then return end
    scan(c, "bags", BAGS)
    if bankOpen then scan(c, "bank", BANK) end
    changed()
  end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event == "BANKFRAME_OPENED" then bankOpen = true; local c = me(); if c then scan(c, "bank", BANK); changed() end
  elseif event == "BANKFRAME_CLOSED" then bankOpen = false
  else bagsLater() end
end)
CL._compute = function() compute(); return rows, shop end -- tests
CL._reset = function() bySpell = nil; dirty = true end
