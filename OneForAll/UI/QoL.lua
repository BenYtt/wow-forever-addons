local _, FLT = ...
local UI = FLT.UI

-- Quality of Life tab: one switch per feature (defaults in QoL.lua DEFAULTS).
-- Logic lives in QoL.lua (FLT.QoL).

local unpack = unpack or table.unpack
local GOLD = UI.GOLD
local openDropDown -- below

-- Yellow "!" (tooltip "New") next to options added since the last live release.
-- Kept for all versions of a minor line (5.7.0 ... 5.7.x); emptied when the next minor line
-- (5.8.0) starts (TODO.md "Neu-Markierungen").
local NEW_TAGS = {} -- all marks removed for 6.0.0, a clean start (user 27.10.); new ones from 6.1.0 on
-- placed left of the checkbox (or of the label when there is none), user 16.10.
local function newTag(parent, anchor, key, dx)
  if not NEW_TAGS[key] then return end
  local m = UI.NewMark(parent, "New in OneForAll " .. NEW_TAGS[key] .. ".")
  m:SetPoint("RIGHT", anchor, "LEFT", dx or -2, 0)
  return m
end

-- Shared drop-down list (UI.OpenDropDown in Widgets.lua)
openDropDown = function(...) return UI.OpenDropDown(...) end


-- Preview popup: a framed picture that shows what a feature looks like in game.
-- previews[key] = { tex, width, height (shown size), texcoord bottom }
local PREVIEWS = {
  questSparkles = { title = "Quest loot sparkles", tex = "preview_sparkles", w = 300, h = 300, t = 1 },
  bagsFull = { title = "Bags full helper", tex = "preview_bagsfull", w = 560, h = 183, t = 167 / 256 },
  questXP = { title = "Quest XP on the experience bar", tex = "preview_questxp", w = 640, h = 119, t = 190 / 256 },
  nodeGlow = { title = "Sparkle on herbs & ore", tex = "preview_nodeglow", w = 300, h = 300, t = 1 }, -- user 26.10.
  -- the user's screenshots of 01.11.2026 (tools/art/proc_qol_previews.py, source_images/qol_previews)
  bossDrops = { title = "Boss drops", tex = "preview_bossdrops", w = 462, h = 285, r = 462/512, t = 285/512 },
  buffIconOnly = { title = "Buff reminder - icon only", tex = "preview_bufficononly", w = 158, h = 178, r = 99/128, t = 111/128 },
  buffReminder = { title = "Buff reminder", tex = "preview_buffreminder", w = 451, h = 124, r = 451/512, t = 124/128 },
  classBright = { title = "Brighter colors", tex = "preview_classbright", w = 301, h = 78, r = 301/512, t = 78/128 },
  classColors = { title = "Class colors", tex = "preview_classcolors", w = 301, h = 81, r = 301/512, t = 81/128 },
  gearValue = { title = "Gear Value", tex = "preview_gearvalue", w = 352, h = 237, r = 352/512, t = 237/256 },
  lowRank = { title = "Check low spell ranks", tex = "preview_lowrank", w = 600, h = 217, r = 823/1024, t = 297/512 },
  mapButton = { title = "OneForAll button on the map", tex = "preview_mapbutton", w = 312, h = 322, r = 312/512, t = 322/512 },
  mapZoneLevel = { title = "Zone level range", tex = "preview_mapzonelevel", w = 442, h = 82, r = 442/512, t = 82/128 },
  mmCollect = { title = "Collect minimap buttons", tex = "preview_collector", w = 276, h = 97, r = 276/512, t = 97/128 },
  mmSquare = { title = "Square minimap", tex = "preview_mmsquare", w = 418, h = 498, r = 418/512, t = 498/512 },
  questMarks = { title = "Quest marks on nameplates", tex = "preview_questmarks", w = 462, h = 195, r = 462/512, t = 195/256 },
  shortStats = { title = "Short green stats", tex = "preview_shortstats", w = 465, h = 402, r = 465/512, t = 402/512 },
  spellbookTrainer = { title = "Trainer button in the spellbook", tex = "preview_spellbooktrainer", w = 600, h = 128, r = 1024/1024, t = 219/256 },
}
local previewFrame
local function showPreview(key)
  local pv = PREVIEWS[key]; if not pv then return end
  if not previewFrame then
    local f = CreateFrame("Frame", "OneForAllPreviewFrame", UIParent)
    f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    f.title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 16, -12); f.title:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -10, -10)
    f.pic = f:CreateTexture(nil, "ARTWORK"); f.pic:SetPoint("TOPLEFT", 16, -40)
    f.picFrame = CreateFrame("Frame", nil, f); f.picFrame:SetAllPoints(f.pic)
    UI.OrnateFrame(f.picFrame, f.picFrame, 10, 2, "OVERLAY", 1)
    f.note = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); f.note:SetPoint("BOTTOMLEFT", 16, 10)
    f.note:SetText("Example from the game. Click and drag to move, Escape to close.")
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllPreviewFrame") end
    previewFrame = f
  end
  local f = previewFrame
  f.title:SetText(pv.title)
  FLT.SetTex(f.pic, UI.ASSET_ROOT .. pv.tex); f.pic:SetTexCoord(0, pv.r or 1, 0, pv.t)
  f.pic:SetSize(pv.w, pv.h)
  f:SetSize(math.max(pv.w + 32, 360), pv.h + 74)
  f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:Show(); f:Raise()
end

-- "Never suggested" list of the bags full helper: one row per item with an X to
-- take it off the list again, plus "Remove all". Opens below its button.
local neverMenu
local NEVER_ROWS = 10
local function itemLook(id)
  local name, quality, icon
  pcall(function()
    local info = { (C_Item and C_Item.GetItemInfo or GetItemInfo)(id) }
    name, quality, icon = info[1], info[3], info[10]
  end)
  if not icon then pcall(function() icon = (C_Item and C_Item.GetItemIconByID or GetItemIcon)(id) end) end
  if not name then pcall(function() if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end end) end
  return name, quality, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- src (optional): another list in the same menu - { get, remove, clear, title, empty, removeTip, confirm }
-- (the own junk list, 5.7.3)
local function showNeverList(owner, onChange, src)
  local Q = FLT.QoL
  if not neverMenu then
    local catcher = CreateFrame("Button", nil, UIParent); catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG"); catcher:SetFrameLevel(1); catcher:RegisterForClicks("AnyUp"); catcher:Hide()
    local m = CreateFrame("Frame", nil, UIParent); m:SetFrameStrata("FULLSCREEN_DIALOG"); m:SetFrameLevel(20)
    m:EnableMouse(true); m:EnableMouseWheel(true); m:Hide(); m:SetWidth(300)
    UI.FramedPanel(m)
    catcher:SetScript("OnClick", function() m:Hide() end)
    m:SetScript("OnHide", function() catcher:Hide() end)
    m.catcher, m.rows, m.offset = catcher, {}, 0
    m.title = FLT.NewFS(m, nil, "OVERLAY", "GameFontNormal"); m.title:SetPoint("TOPLEFT", 12, -10); m.title:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
    m.empty = FLT.NewFS(m, nil, "OVERLAY", "GameFontDisableSmall"); m.empty:SetPoint("TOPLEFT", 12, -32); m.empty:SetWidth(276); m.empty:SetJustifyH("LEFT")
    m.empty:SetText("Nothing on the list. In the bags full helper, the X button puts an item here so it is never suggested again.")
    m.more = FLT.NewFS(m, nil, "OVERLAY", "GameFontDisableSmall")
    m.clear = UI.GoldButton(m, "Remove all", 110, 22, nil, 11); m.clear:SetPoint("BOTTOMRIGHT", -10, 10)
    m.more:SetPoint("BOTTOMLEFT", 12, 16)
    for i = 1, NEVER_ROWS do
      local r = CreateFrame("Frame", nil, m); r:SetSize(280, 22); r:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 24)
      r:EnableMouse(true)
      local hi = r:CreateTexture(nil, "BACKGROUND"); hi:SetAllPoints(); hi:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.12)); hi:Hide()
      r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 2, 0); r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 26, 0); r.text:SetWidth(222); r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
      r.x = CreateFrame("Button", nil, r); r.x:SetSize(16, 16); r.x:SetPoint("RIGHT", -4, 0)
      r.x:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); r.x:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
      r.x:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Remove from the list"); GameTooltip:AddLine(neverMenu.src.removeTip, 1, 1, 1, true); GameTooltip:Show() end)
      r.x:SetScript("OnLeave", function() GameTooltip:Hide() end)
      r:SetScript("OnEnter", function(self)
        hi:Show()
        if self.id then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); pcall(GameTooltip.SetItemByID, GameTooltip, self.id); GameTooltip:Show() end
      end)
      r:SetScript("OnLeave", function() hi:Hide(); GameTooltip:Hide() end)
      m.rows[i] = r
    end
    m:SetScript("OnMouseWheel", function(self, delta)
      local n = #(self.ids or {})
      self.offset = math.max(0, math.min(math.max(0, n - NEVER_ROWS), self.offset - delta))
      self.fill()
    end)
    neverMenu = m
  end
  local m = neverMenu
  if m:IsShown() and m.owner == owner then m:Hide(); return end
  src = src or { get = Q.GetNeverItems, remove = Q.RemoveNever, clear = Q.ClearNever, title = "Never suggested",
    empty = "Nothing on the list. In the bags full helper, the X button puts an item here so it is never suggested again.",
    removeTip = "The bags full helper may suggest this item again.", confirm = "Remove all items from the\n\"never suggest\" list?" }
  m.src = src
  m.empty:SetText(src.empty)
  local retried = false
  m.fill = function()
    local ids = src.get(); m.ids = ids
    m.offset = math.max(0, math.min(m.offset, #ids - NEVER_ROWS))
    m.title:SetText(src.title .. "  |  " .. #ids .. (#ids == 1 and " item" or " items"))
    m.empty:SetShown(#ids == 0)
    local missing = false
    for i, r in ipairs(m.rows) do
      local id = ids[i + m.offset]
      if id then
        local name, quality, icon = itemLook(id)
        if not name then missing = true end
        r.id = id
        r.icon:SetTexture(icon)
        r.text:SetText(name or ("Item " .. id))
        local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c then r.text:SetTextColor(c.r, c.g, c.b) else r.text:SetTextColor(0.92, 0.90, 0.84) end
        r.x:SetScript("OnClick", function() src.remove(id); m.fill(); if onChange then onChange() end end)
        r:Show()
      else
        r.id = nil; r:Hide()
      end
    end
    local shown = math.min(#ids, NEVER_ROWS)
    if #ids > NEVER_ROWS then m.more:SetText("Scroll for more"); m.more:Show() else m.more:Hide() end
    m.clear:SetEnabled(#ids > 0); m.clear:SetLook(#ids > 0)
    m:SetHeight(#ids == 0 and 110 or (30 + shown * 24 + 40))
    if missing and not retried and C_Timer and C_Timer.After then
      retried = true
      C_Timer.After(0.6, function() if m:IsShown() then m.fill() end end)
    end
  end
  m.clear:SetScript("OnClick", function()
    m:Hide()
    UI.Confirm(src.confirm, function() src.clear(); if onChange then onChange() end end, "Remove all")
  end)
  m.offset = 0
  m.fill()
  m:ClearAllPoints(); m:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
  m.owner = owner
  m.catcher:Show(); m:Show()
end

-- Layout (user 22.10.): a fixed list of groups on the left like Armory and Professions, the options
-- of one group on the right (one per row: switch, name, short description, controls on the right),
-- a search over all options. Opens on Interface.
local CHILD_W = 770          -- scroll child inside the right frame (body 814 - margins - scroll bar; ht6: +16)
local ROW_W = CHILD_W - 8
local function createQoLPanel(parent)
  local Q = FLT.QoL
  local panel = CreateFrame("Frame", nil, parent)
  UI.PlacePanel(panel, parent)
  UI.TitleBand(panel, { emblem = UI.ASSET_ROOT .. "emblem_qol", art = UI.ASSET_ROOT .. "qol_banner",
    title = "Quality of Life", subtitle = "Small helpers for everyday play. Switch on what you like.", fadeRight = 200 })

  local nav, navTop = UI.SideNav(panel, -74, "emblem_qol", "Quality of Life") -- ht8: the same side list in every tab
  local body = CreateFrame("Frame", nil, panel)
  body:SetPoint("TOPLEFT", 182, -74); body:SetPoint("BOTTOMRIGHT", -8, 4)

  -- header of the right side: icon, group name, one line about it, search (UI.PageHeader, shared with Dungeons / Hunter Pets)
  local onSearch -- below
  local head = UI.PageHeader(body, { placeholder = "Search all settings...", onSearch = function(t) if onSearch then onSearch(t) end end })
  local hIcon, hTitle, hSub = head.icon, head.title, head.sub
  -- ht7 (user 30.10.): no line under the group header any more

  local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate"))
  sf:SetPoint("TOPLEFT", 10, -60); sf:SetPoint("BOTTOMRIGHT", -28, 8)
  local child = CreateFrame("Frame", nil, sf); child:SetSize(CHILD_W, 10); sf:SetScrollChild(child)
  UI.PlaceScrollBar(sf)
  local empty = FLT.NewFS(child, nil, "OVERLAY", "GameFontDisable"); empty:SetPoint("TOPLEFT", 12, -12); empty:SetText("No setting matches your search."); empty:Hide()

  local refreshers, cats, current, search = {}, {}, nil, ""
  local layout, updateCounts -- below

  -- at: the option name of a row: the tooltip then sits in a fixed column of that row (user 01.11.; was right of the
  -- name, user 24.10.)
  local function hint(widget, title, text, at)
    local function show(self)
      if at then
        -- under the row, left-aligned with the name (user 03.11.: right of the text it covered the boxes and
        -- buttons; 01.11.: a fixed place, not next to the name where it jumped with every row)
        GameTooltip:SetOwner(self, "ANCHOR_NONE"); GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", at:GetParent() or at, "BOTTOMLEFT", 56, 2)
      else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      end
      GameTooltip:AddLine(title, FLT.SkinC(1, 0.82, 0))
      if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
      GameTooltip:Show()
    end
    if not at then
      widget:HookScript("OnEnter", show)
      widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
      return
    end
    -- rows: only over the name and the description, not over the controls on the right (user 03.11.: the big
    -- tooltip covered the boxes); followed while the mouse is on the row only
    local row = at:GetParent() or at
    local shown = false
    local function over(self)
      local x = GetCursorPosition and GetCursorPosition()
      local sc = self:GetEffectiveScale() or 1
      local right = math.max(at:GetRight() or 0, (row.desc and row.desc:GetRight()) or 0) + 12
      local inside = not x or (x / sc) <= right
      if inside and not shown then shown = true; show(self)
      elseif not inside and shown then shown = false; GameTooltip:Hide() end
    end
    widget:HookScript("OnEnter", function(self) shown = false; over(self); self:SetScript("OnUpdate", over) end)
    widget:HookScript("OnLeave", function(self) self:SetScript("OnUpdate", nil); shown = false; GameTooltip:Hide() end)
  end

  -- nav = shorter name for the button on the left (when the full one touches the count)
  local function category(key, label, icon, desc, nav)
    local c = { key = key, label = label, icon = icon, desc = desc, nav = nav, groups = {}, checks = {} }
    c.title = UI.SectionTitle(child, label, 8, 0, -8); c.title:Hide(); c.title.divider:Hide() -- heading in search results
    cats[#cats + 1] = c
    return c
  end
  local function group(cat, title)
    local g = { cat = cat, rows = {} }
    g.title = UI.SectionTitle(child, title, 8, 0, -8); g.title:Hide(); g.title.divider:Hide()
    g.name = title
    cat.groups[#cat.groups + 1] = g
    return g
  end

  -- one option row: name and a short grey line below; tip = the longer text in the tooltip
  local function row(g, label, desc, tip, indent)
    local r = CreateFrame("Button", nil, child); r:SetSize(ROW_W, 34); r:Hide() -- 40 -> 34 (user 01.11.: tighter)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.06))
    r.indent = indent or 0
    r.label = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.label:SetPoint("TOPLEFT", 60 + r.indent, -3); r.label:SetText(label) -- 12 pt, rows closer (user 01.11.); room for the switch (was 42)
    r.desc = FLT.NewFS(r, nil, "OVERLAY", "GameFontDisableSmall"); r.desc:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
    r.desc:SetJustifyH("LEFT"); r.desc:SetWordWrap(false); r.desc:SetText(desc or "")
    r.rightW = 0
    r.find = (label .. " " .. (desc or "") .. " " .. (tip or "") .. " " .. g.name .. " " .. g.cat.label):lower()
    if tip then hint(r, label, tip, r.label) end
    r.name, r.tip = label, tip
    g.rows[#g.rows + 1] = r
    return r
  end
  -- controls sit on the right of the row, right to left
  local function place(r, w, gap)
    w:ClearAllPoints(); w:SetPoint("RIGHT", r, "RIGHT", -10 - r.rightW, 0)
    r.rightW = r.rightW + w:GetWidth() + (gap or 6)
  end
  local function button(r, text, w, tip, onClick)
    local b = UI.GoldButton(r, text, w, 22, nil, 11); place(r, b)
    b:SetScript("OnClick", onClick)
    if tip then hint(b, text, tip) end
    return b
  end
  local function dropButton(r, w)
    local b = UI.GoldButton(r, "", w or 128, 22, nil, 11); place(r, b)
    local arrow = b:CreateTexture(nil, "OVERLAY"); arrow:SetSize(12, 12); arrow:SetPoint("RIGHT", -8, 0)
    FLT.SetTex(arrow, UI.ASSET_ROOT .. "chevron"); arrow:SetTexCoord(0, 0.5, 0, 1)
    return b, arrow
  end

  -- switch in front of the row; get/set default to Q.Get/Q.Set(key); clicking the row toggles it too
  local function switch(r, g, key, get, set, onChange)
    local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"))
    cb:SetSize(24, 24); cb:SetPoint("LEFT", 8 + r.indent, 0)
    get = get or function() return Q.Get(key) and true or false end
    set = set or function(v) Q.Set(key, v) end
    cb:SetScript("OnClick", function(b) set(b:GetChecked() and true or false); if onChange then onChange() end; updateCounts() end)
    r:SetScript("OnClick", function() cb:Click() end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get()) end
    if r.tip then hint(cb, r.name, r.tip, r.label) end
    g.cat.checks[#g.cat.checks + 1] = get
    if key then
      if newTag(r, cb, key, 4) then g.cat.new = true end
      if PREVIEWS[key] then -- small preview button behind the name for features with a picture
        local pb = CreateFrame("Button", nil, r); pb:SetSize(18, 18); pb:SetPoint("LEFT", r.label, "RIGHT", 6, 0)
        local pic = pb:CreateTexture(nil, "ARTWORK"); pic:SetAllPoints(); FLT.SetTex(pic, "Interface\\Icons\\INV_Misc_Spyglass_02"); pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        pb:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        pb:SetScript("OnClick", function() showPreview(key) end)
        hint(pb, "Show preview", "A picture of how it looks in the game.")
      end
    end
    r.cb = cb
    return cb
  end
  local function check(g, label, desc, tip, key, indent, get, set)
    local r = row(g, label, desc, tip, indent)
    switch(r, g, key, get, set)
    return r
  end
  -- drop-down on the right; onKey: optional switch in front, the drop-down is greyed out while it is off
  local function choice(g, label, desc, tip, key, options, onKey, indent)
    local r = row(g, label, desc, tip, indent)
    local b, arrow = dropButton(r)
    local function show()
      local cur, text = Q.Get(key), options[1].label
      for _, o in ipairs(options) do if o.key == cur then text = o.label end end
      b:SetLabel(text)
      if onKey then
        local on = Q.Get(onKey) and true or false
        b:SetLook(on); b:SetEnabled(on); arrow:SetAlpha(on and 1 or 0.35)
      end
    end
    b:SetScript("OnClick", function(self) openDropDown(self, options, Q.Get(key), function(v) Q.Set(key, v); show() end) end)
    if tip then hint(b, label, tip) end
    if onKey then switch(r, g, onKey, nil, nil, show) else newTag(r, r.label, key) end
    refreshers[#refreshers + 1] = show
    return r
  end

  ---------------------------------------------------------------------------------------------------
  -- INTERFACE (first, the tab opens here; user 22.10.)
  local c = category("iface", "Interface", "Interface\\Icons\\INV_Misc_Gear_01", "Camera, bags, windows, the minimap and other helpers for the game's interface.")
  local g = group(c, "General")
  check(g, "Farther camera zoom", "Lets you zoom the camera out further.", nil, "cameraZoom")
  check(g, "Free bag slots on the backpack", "Shows the number of free slots on your backpack.", "Counts all normal bags (quivers, ammo and profession bags are not counted).", "bagSlots")
  check(g, "Hide error messages", "Hides the red messages in the middle of the screen.", "Messages like \"Out of range\" or \"Not enough rage\" are no longer shown. Still shown: inventory or bags full, quest log full, not enough money, carrying too many of an item.", "hideErrors")
  g = group(c, "Windows")
  do
    local r = check(g, "Move Blizzard windows", "Drag windows like the character or quest log window anywhere.", "Drag windows such as the character, merchant or quest log window with the left mouse button. Positions are remembered.", "moveWindows")
    button(r, "Reset", 60, "Moved Blizzard windows go back to their default place.", function() Q.ResetWindowPositions() end)
  end
  do
    local r = check(g, "Resize Blizzard windows", "Drag a window with the right mouse button to change its size.", "Hold the right mouse button on a window like the character or quest log window and drag: right or down makes it larger, left or up smaller (50 - 150 %). The size shows at the cursor and is remembered.", "resizeWindows")
    button(r, "Reset", 60, "Resized Blizzard windows go back to their normal size.", function() Q.ResetWindowSizes() end)
  end
  g = group(c, "Minimap")
  do -- the logo colours as small logos to click (like the welcome setup; user 31.10.: no drop-down)
    local r = row(g, "Logo color", "The color of the OneForAll minimap button.", "Also the button of the minimap button collector.")
    local marks = {}
    for i = #Q.LOGO_COLORS, 1, -1 do
      local o = Q.LOGO_COLORS[i]
      local b = CreateFrame("Button", nil, r); b:SetSize(26, 26); place(r, b, 8)
      local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(UI.ASSET_ROOT .. "logo_round_" .. (o.key == "bronze" and "teal" or o.key))
      if FLT.TintLogo then FLT.TintLogo(t, o.key) end
      local sel = b:CreateTexture(nil, "OVERLAY"); sel:SetPoint("TOPLEFT", -4, 4); sel:SetPoint("BOTTOMRIGHT", 4, -4)
      sel:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); sel:SetBlendMode("ADD")
      b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
      b:SetScript("OnClick", function() Q.Set("logoColor", o.key); for k, m in pairs(marks) do m:SetShown(k == o.key) end end)
      b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(o.label); GameTooltip:Show() end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      marks[o.key] = sel
    end
    refreshers[#refreshers + 1] = function() local cur = Q.Get("logoColor") for k, m in pairs(marks) do m:SetShown(k == cur) end end
  end
  -- "Collect minimap buttons" and "Hide the OneForAll button" exclude each other: the one that is on greys out
  -- the other (user 24.10.; the bar needs its button)
  local collectRow, hideRow
  local function paintMinimap()
    if not (collectRow and hideRow) then return end
    if Q.Get("mmCollect") and Q.Get("mmHide") then Q.Set("mmHide", false) end -- both on (beta1): the collector wins
    local function look(r, on) r.cb:SetEnabled(on); r:SetEnabled(on); r.label:SetAlpha(on and 1 or 0.45); r.desc:SetAlpha(on and 1 or 0.45) end
    look(hideRow, not Q.Get("mmCollect")); look(collectRow, not Q.Get("mmHide"))
  end
  do
    collectRow = row(g, "Collect minimap buttons", "Puts the minimap buttons of other addons into one bar.", "The bar opens from a bigger OneForAll button that you can drag anywhere (it is not tied to the minimap). Right-click that button to open OneForAll. Switching this off puts all buttons back on the minimap. Not together with \"Hide the OneForAll button\".")
    switch(collectRow, g, "mmCollect", nil, nil, paintMinimap)
    button(collectRow, "Reset", 60, "Puts the minimap button collector back to its default place next to the minimap.", function() if FLT.ResetMinimapCollector then FLT.ResetMinimapCollector() end end)
  end
  choice(g, "Bar opens", "Where the bar opens next to the OneForAll button.", "Automatic: towards the middle of the screen.", "mmDir", Q.MM_DIR_OPTIONS, nil, 24)
  hideRow = row(g, "Hide the OneForAll button", "No OneForAll button at the minimap.", "Open OneForAll from the game's AddOns list at the minimap or with /ofa. Not together with \"Collect minimap buttons\": the bar needs its button.")
  switch(hideRow, g, "mmHide", nil, nil, paintMinimap)
  refreshers[#refreshers + 1] = paintMinimap
  do
    local mr = check(g, "Move the minimap", "Hold Shift and drag the minimap to move it.", "Moves the whole minimap with its zone text and buttons. A click without Shift still pings as usual.", "mmMove")
    button(mr, "Reset", 60, "Puts the minimap back to its default place.", function() if FLT.ResetMinimapPosition then FLT.ResetMinimapPosition() end end)
  end
  check(g, "Square minimap", "A square minimap with a thin black frame.", "The round border and the compass are hidden; minimap buttons of other addons follow the square edge. Does nothing with ElvUI or when another addon already makes the minimap square.", "mmSquare")

  ---------------------------------------------------------------------------------------------------
  -- CHAT (own entry in the list, user 31.10.)
  c = category("chat", "Chat", "Interface\\Icons\\INV_Scroll_03", "The chat windows and the chat box.")
  g = group(c, "Chat windows")
  do -- chat font size: -, value, +
    local r = row(g, "Chat font size", "The same font size for every chat window.", "Go below 10 to switch it off (then the game's own setting is kept).")
    local function step(d)
      local v = tonumber(Q.Get("chatFont"))
      if not v then v = 14 else v = v + d end
      if v < 10 then v = nil elseif v > 24 then v = 24 end
      Q.Set("chatFont", v); r.show()
    end
    button(r, "+", 26, nil, function() step(1) end)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontNormal"); val:SetWidth(46); val:SetJustifyH("CENTER"); val:SetHeight(20); place(r, val, 4)
    button(r, "-", 26, nil, function() step(-1) end)
    r.show = function() local v = tonumber(Q.Get("chatFont")); val:SetText(v and tostring(v) or "Off") end
    refreshers[#refreshers + 1] = r.show
  end
  check(g, "Copy chat button", "Adds a button to every chat window to copy its text.", "A small button at the top right of every chat window. It opens the chat text so you can select and copy it (Ctrl+C).", "copyChat")
  check(g, "Hide chat button", "A button next to the chat hides and shows it.", "It sits above the chat menu button. Also as a key: Key Bindings > OneForAll > Hide / show chat. Pressing Enter to type brings the chat back.", "chatHide")
  choice(g, "Hide chat after", "Hides the chat after that long without a new message.", "A new message or typing shows it again. Not while the mouse is on the chat.", "chatAutoHide", Q.CHAT_HIDE_OPTIONS)
  g = group(c, "Typing")
  check(g, "Message history", "Arrow up / down in the chat box brings back your last 5 messages.", "Type, send, open the chat again and press arrow up: the message is there again, Enter sends it. While typing, the arrow keys no longer turn your character.", "chatHistory")

  ---------------------------------------------------------------------------------------------------
  -- LOOT & VENDORS
  c = category("loot", "Loot & Vendors", "Interface\\Icons\\INV_Misc_Bag_10", "Looting, merchants, full bags and the loot feed.")
  g = group(c, "Looting")
  check(g, "Auto loot", "The game's own Auto Loot setting.", "Same as Options > Controls > Auto Loot.", nil, nil,
    function() return Q.GetCVarSwitch("autoLoot") end, function(v) Q.SetCVarSwitch("autoLoot", v) end)
  check(g, "Quicker loot", "Takes everything at once when the game auto loots.", "Instead of item by item.", "quickLoot")
  g = group(c, "Merchants")
  check(g, "Auto repair", "Repairs all gear at merchants that can repair.", nil, "autoRepair")
  check(g, "Sell junk", "Sells all grey items when you open a merchant.", "Also the items on your own junk list: Alt+right-click an item in your bags to put it on the list or take it off. Hold Shift at the merchant to skip.", "sellJunk")
  do -- own junk list (5.7.3, GitHub #22)
    local r = row(g, "Junk list", "Items you added with Alt+right-click in your bags.", "This character's list. Sell junk sells these items too.", 24)
    local b = dropButton(r, 110)
    local function show() local n = #Q.GetJunkItems(); b:SetLabel(n == 1 and "1 item" or (n .. " items")) end
    local JUNK = { get = Q.GetJunkItems, remove = Q.RemoveJunk, clear = Q.ClearJunk, title = "Junk list",
      empty = "Nothing on the list. Alt+right-click an item in your bags to add it - Sell junk then sells it at merchants.",
      removeTip = "Sell junk will not sell this item any more.", confirm = "Remove all items from your junk list?" }
    b:SetScript("OnClick", function(self) showNeverList(self, show, JUNK) end)
    refreshers[#refreshers + 1] = show
    newTag(r, r.label, "junkList")
  end
  g = group(c, "Full bags")
  check(g, "Bags full helper", "When loot does not fit, offers to destroy the cheapest item.", "Suggests the cheapest item in your bags (value x stack), destroys it and loots with one click. Quest items, library books, recipes, set pieces, profession tools and items without value are never suggested. Items better than grey need a second click. /ofa cheapest shows it any time.", "bagsFull")
  check(g, "Only grey and white items", "The helper only suggests poor and common items.", nil, "bagsLowOnly", 24)
  do -- items the player put on the "never suggest" list
    local r = row(g, "Never suggested", "Items you blocked with the X button in the helper.", "Open the list to allow single items again, or remove all.", 24)
    local b = dropButton(r, 110)
    local function show() local n = #Q.GetNeverItems(); b:SetLabel(n == 1 and "1 item" or (n .. " items")) end
    b:SetScript("OnClick", function(self) showNeverList(self, show) end)
    refreshers[#refreshers + 1] = show
  end
  g = group(c, "Loot feed")
  check(g, "Show loot feed", "Looted items and money float up next to your character.", "Like scrolling combat text.", "lootFeed")
  choice(g, "Minimum quality", "Items below this quality are not shown.", nil, "lootFeedQuality", Q.QUALITY_OPTIONS, nil, 24)
  check(g, "Show money", "Also shows looted money.", nil, "lootFeedMoney", 24)
  do
    local r = row(g, "Position", "Move the feed, show sample entries or put it back.", nil, 24)
    button(r, "Reset", 70, "Puts the loot feed back to its default place right of your character.", function() Q.ResetLootFeed() end)
    button(r, "Test", 70, "Shows a few sample entries.", function() Q.TestLootFeed() end)
    local move = button(r, "Move", 70, "Shows the loot feed area. Drag it where you want it, then click Lock.", nil)
    local function show() move:SetLabel(Q.IsLootFeedUnlocked() and "Lock" or "Move"); move:SetActive(Q.IsLootFeedUnlocked()) end
    move:SetScript("OnClick", function() Q.SetLootFeedUnlocked(not Q.IsLootFeedUnlocked()); show() end)
    refreshers[#refreshers + 1] = show
  end
  g = group(c, "Gathering")
  local r = check(g, "Sparkle on herbs & ore", "The herb or ore vein near you sparkles.", "Only for professions you have. Uses the game's soft targeting (interaction target): one object at a time, the nearest one around you. Vendors and other NPCs get nothing. Works only close up (about 15 yards) - a limit of the game. Changes a few game settings and gives them back when you switch this off. Idea and sparkle from the addon Lueur (MIT).", "nodeGlow")
  do -- red warning sign behind the name: it changes soft targeting (user 25.10.)
    local w = CreateFrame("Frame", nil, r); w:SetSize(22, 22); w:SetPoint("LEFT", r.label, "RIGHT", 32, 0) -- right of the preview spyglass
    local x = w:CreateTexture(nil, "ARTWORK"); x:SetAllPoints(); FLT.SetTex(x, UI.ASSET_ROOT .. "icon_warning") -- as in the gear planner
    w:EnableMouse(true) -- own tooltip, not the row's
    w:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Care!", 1, 0.25, 0.25)
      GameTooltip:AddLine("This option changes soft-targeting, read hint text!", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- QUESTS
  c = category("quests", "Quests", "Interface\\Icons\\INV_Misc_Note_01", "Quest givers and quest items in the world.")
  g = group(c, "Quest givers")
  check(g, "Accept quests automatically", "Accepts quests when you talk to a quest giver. Hold Shift to do it by hand.", nil, "autoAccept")
  check(g, "Turn in quests automatically", "Turns in finished quests. Hold Shift to do it by hand.", "If you can choose between rewards, you still pick yourself.", "autoTurnIn")
  g = group(c, "Experience")
  check(g, "Quest XP on the experience bar", "Shows the XP of your finished quests on the experience bar.", "Marks on the experience bar how much XP your finished quests give when you turn them in. The amount is also shown in the bar's tooltip.", "questXP")
  g = group(c, "In the world")
  check(g, "Best sell price on rewards", "A gold coin on the quest reward choice that sells for the most.", "In the quest log and when you turn in a quest with two or more rewards to choose from: the one with the highest vendor price (times the count) gets a gold coin at its top right. The green upgrade arrow stays at the top left, so an item can have both.", "questSellCoin")
  check(g, "Quest loot sparkles", "Quest items in the world sparkle again.", "The game's loot glow. Changes graphics settings; after switching it off, restart the game.", "questSparkles")
  check(g, "Quest marks on nameplates", "A sword or a bag with your progress on mobs you need for a quest.", "Sword: you must kill it for a quest. Bag: it drops a quest item. With the progress (3/10); nothing once that part is done. Uses the quest lines the game shows in the mob's tooltip. Not inside dungeons yet.", "questMarks")
  choice(g, "Mark position", "Where the mark sits on the nameplate.", nil, "questMarkPos", FLT.QuestMarks and FLT.QuestMarks.POS_OPTIONS or { { key = "left", label = "Left" } }, nil, 24) -- no own switch (user 31.10.)

  -- TOOLTIPS
  c = category("tips", "Tooltips", "Interface\\Icons\\INV_Misc_Spyglass_03", "Extra lines in item and unit tooltips.")
  g = group(c, "Items")
  check(g, "Boss drops", "Shows which dungeon boss drops an item.", nil, "bossDrops")
  check(g, "Gear Value", "Upgrade or downgrade in % against what you wear.", "On gear you can use: how much better (green) or worse (red) it is than what you wear, weighted for your talent spec like Armory > Gear Planner. Also a green arrow on upgrades in your bags, the loot roll window and quest rewards, and a gold star for wishlist items (/ofa rolltest shows an example).", "gearValue")
  check(g, "Arrow color by armor type", "Yellow arrow for upgrades in a lighter armor type.", "The green arrow stays for upgrades in the best armor type of your class. Upgrades in a lighter type get a yellow arrow: warriors and paladins wear plate from level 40 (mail before), hunters and shamans mail from 40 (leather before), rogues and druids leather. Cloaks, jewelry, shields and weapons are not affected. Needs \"Gear Value\".", "arrowTiers", 24)
  check(g, "Short green stats", "Long \"Equip:\" lines as short stats, e.g. \"+1% Hit\".", "\"Equip: Improves your chance to hit by 1%.\" becomes \"+1% Hit\", spell damage and healing get a line each, and \"Enchanted:\" lines put the number first. Lines it does not know stay as they are. Hover the item again after switching.", "shortStats")
  check(g, "Hide \"appearance not collected\"", "No more blue \"You haven't collected this appearance\" line on items.", "Also hides \"You've collected this appearance, but not from this item\". Hover the item again after switching.", "hideAppearance")
  check(g, "Recipes: who knows it", "Whether you, an alt or a guild member knows a recipe.", nil, "recipeTip")
  check(g, "Disable automatic compare tooltip", "Hold Shift to see your equipped item next to the tooltip.", "Item tooltips no longer show your equipped item next to them automatically.", nil, nil,
    function() return Q.GetCompareShift() end, function(v) Q.SetCompareShift(v) end)
  g = group(c, "Units")
  check(g, "Target of players", "Shows who a player or NPC under your mouse is targeting.", "\"You\" when it is you.", "unitTarget")

  -- SOCIAL
  c = category("social", "Social", "Interface\\Icons\\INV_Letter_15", "Group invites, duels, recipe sharing and thanks.")
  g = group(c, "Groups")
  choice(g, "Group invites from", "Accepts group invites from the players you choose.", "Off: OneForAll does nothing with invites.", "inviteMode", Q.WHO_OPTIONS, "inviteOn")
  choice(g, "Keyword invites from", "Invites players who whisper you the keyword.", "Off: OneForAll does nothing with whispers.", "keywordMode", Q.WHO_OPTIONS, "keywordOn")
  do
    local r = row(g, "Keyword", "The word players whisper you to get an invite.", nil, 24)
    local eb = FLT.SkinBlizz(CreateFrame("EditBox", nil, r, "InputBoxTemplate"))
    eb:SetSize(122, 20); eb:SetAutoFocus(false); eb:SetMaxLetters(24); place(r, eb)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(Q.Get("keyword") or ""); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function(self) Q.Set("keyword", self:GetText()) end)
    r:SetScript("OnClick", function() eb:SetFocus() end)
    refreshers[#refreshers + 1] = function() if not eb:HasFocus() then eb:SetText(Q.Get("keyword") or "") end end
  end
  g = group(c, "Duels")
  choice(g, "Allow duels from", "Duel requests from everyone else are declined.", "Off: OneForAll does nothing with duels.", "duelMode", Q.DUEL_OPTIONS, "duelOn")
  g = group(c, "Recipes")
  check(g, "Share recipes with other OneForAll users", "Finds OneForAll users outside your guild who know a recipe.",
    "The Search button of a recipe in Professions > All recipes asks the other OneForAll users who know it (blue marker); only a few of them answer, so it stays fast with many players. When off, you are not asked and do not search either. Guild members are always shared. Moved here from Settings in 6.1.0.",
    nil, nil, function() return FLT.IsRecipeShareEnabled and FLT.IsRecipeShareEnabled() end,
    function(v) if FLT.SetRecipeShareEnabled then FLT.SetRecipeShareEnabled(v) end end)
  g = group(c, "Buffs")
  check(g, "Thank players who buff you", "Sends a /thank to players outside your group who buff you.", "For buffs that last longer than 2 minutes. It comes 1 second later, not in combat, at most once every 5 minutes per player. Your target is not changed. /ofa thanks shows the last buffs.", "thanksBuff")

  -- WORLD MAP
  c = category("map", "World Map", "Interface\\Icons\\INV_Misc_Map_01", "Icons on the world map.")
  g = group(c, "Map Landmarks")
  check(g, "Map Landmarks", "Dungeon entrances, flight masters, ships, the tram and Library Books on the map.", "Your faction and neutral ones. Click an entrance to open that dungeon in OneForAll. Zeppelins, ships, the tram and flight masters show where they go.", "mapLandmarks")
  check(g, "Dungeon & raid entrances", "Click to open the dungeon in OneForAll.", nil, "lmDungeons", 24)
  check(g, "Flight masters", "Shows where they fly to.", nil, "lmFlight", 24)
  check(g, "Zeppelins, ships & tram", "Shows where they go.", nil, "lmTransport", 24)
  check(g, "Zone transitions", "A signpost where a road leads into the next zone.", "The tooltip names the other zone; a click shows it on the map. Places from the addon Carbonite (GPL).", "lmTransitions", 24)
  check(g, "Library Books", "A book icon where each Library Book you still need lies.", "Books in your bags or bank, turned in or marked by you are not shown. Click a book to see it in the Library Books tab.", "mapBooks", 24)
  check(g, "Skyborne: Ley Lines & Convergences", "For Skyborne: where to charge your racial for an hour.", "High Order (Alliance) see the Ley Lines for Read Leyline (Attuned: 100% regeneration for 1 hour), Windshapers (Horde) the Elemental Convergences for Skysight (Charged: 30% movement speed for 1 hour). On by default for Skyborne; other races see the spots of their faction when they switch it on. Locations from the addon \"Skyborne Leyline & Convergence Marker\" by tr0tsky.", "lmSkyborne", 24)
  g = group(c, "Quests")
  check(g, "Quest icons", "A yellow ! at quest givers with quests for your level, a ? where you turn in finished quests.", "Only quests you can take now: your level (no grey ones, none too high), your side and class, pre-quests done. Hover an icon for the quests and their levels. Hidden while Questie is loaded, it shows its own. Quest data from QuestieDB (GPL); the new Forever zones are not in it yet.", "mapQuests")
  g = group(c, "Map button")
  check(g, "OneForAll button on the map", "A logo at the top left of the world map with all these switches.", "Click it for a quick list: Map Landmarks and its parts, Remove Fog and the dungeon map. It sits below other addons' buttons there (RareScanner ...).", "mapButton")
  g = group(c, "Exploration")
  do -- with a slider for how visible the unexplored parts are (user 01.11.)
    local r = check(g, "Remove Fog", "Shows the parts of a zone you have not explored yet.", "The world map normally hides the areas you have not visited. With this the whole zone map is shown. The slider sets how visible the unexplored parts are (0 % hidden, 100 % fully shown).", "mapFog")
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.SkinC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val)
    local sl = UI.Slider(r, 130, 0, 100, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("mapFogAlpha") ~= v then Q.Set("mapFogAlpha", v) end
    end)
    place(r, sl, 10)
    hint(sl, "Unexplored areas", "How visible the parts you have not explored yet are: 0 % hidden, 100 % fully shown. Mouse wheel or drag.")
    local function show()
      local v = Q.Get("mapFogAlpha") or 100; sl:SetValue(v); val:SetText(v .. " %")
      local on = Q.Get("mapFog") and true or false; sl:SetAlpha(on and 1 or 0.4); sl:EnableMouse(on); sl:EnableMouseWheel(on)
    end
    refreshers[#refreshers + 1] = show
    r.cb:HookScript("OnClick", show) -- greyed out while Remove Fog is off
  end
  check(g, "Zone level range", "The zone's level range at the top right of the world map and when you hover a zone.", "At the top right of a zone map, and behind the zone name when you hover a zone on the continent map. Gold: your level, red: still too low, grey: you are above it.", "mapZoneLevel")
  g = group(c, "Dungeons")
  -- moved from Settings (5.6.8, user 22.10.); on by default: only an explicit "off" turns it off
  check(g, "Dungeon map on M", "Inside a dungeon, M opens OneForAll's dungeon map.", "Inside a dungeon that has a map, the world map key (M) opens OneForAll's dungeon map instead of the world map. Press it again to close. Takes effect outside combat.", nil, nil,
    function() return type(OneForAllDB) == "table" and OneForAllDB.dungeonMapKey ~= false end,
    function(v) if type(OneForAllDB) == "table" then OneForAllDB.dungeonMapKey = v and true or false end; if FLT.ApplyDungeonMapKey then FLT.ApplyDungeonMapKey() end end)

  -- UNIT FRAMES
  c = category("frames", "Unit Frames", "Interface\\Icons\\INV_Misc_Head_Human_01", "Colors and bars of the unit and raid frames.")
  g = group(c, "Player, target & party")
  check(g, "Class colors: player, target & party", "Health bars of players in their class color.", "NPCs keep their normal color.", "classColors")
  check(g, "Brighter colors", "Plain bright bars for the class colors.", "The game's health bar texture is dark; with this the class colors use a plain bright bar.", "classBright", 24)
  g = group(c, "Raid frames")
  check(g, "Class colors: raid frames", "The game's own setting.", "Same as Interface > Display Class Colors.", nil, nil,
    function() return Q.GetCVarSwitch("raidClassColor") end, function(v) Q.SetCVarSwitch("raidClassColor", v) end)
  check(g, "Power bars: raid frames", "Mana, rage and energy bars in the raid frames.", "A game setting.", nil, nil,
    function() return Q.GetCVarSwitch("raidPowerBars") end, function(v) Q.SetCVarSwitch("raidPowerBars", v) end)

  -- SPELLS
  c = category("spells", "Spells", "Interface\\Icons\\INV_Misc_Book_11", "Your action bars and the spellbook.")
  g = group(c, "Action bars")
  do
    local LR = FLT.LowRank
    local r = check(g, "Check low spell ranks", "Offers the highest rank for spells on your bars.", "Looks for spells on your action bars that use a lower rank than one you already know, and offers to put the highest rank there. After a trainer visit it waits until you close the trainer window. Macros are not checked.", "lowRank")
    button(r, "Check now", 90, "Checks your action bars right away.", function() if LR then LR.Check("button") end end)
    r = row(g, "Kept ranks", "Ranks you keep on purpose (Keep in the popup).", "Click one to have it reported again.", 24)
    local b = dropButton(r, 110)
    local function show() local n = LR and #LR.GetKept() or 0; b:SetLabel(n == 1 and "1 spell" or (n .. " spells")) end
    b:SetScript("OnClick", function(self)
      if not LR then return end
      local opts = LR.GetKept()
      for _, e in ipairs(opts) do e.remove = true end -- a click removes it: red cross
      if #opts == 0 then opts = { { key = "__none", label = "|cff9d9d9dNothing kept|r" } }
      else opts[#opts + 1] = { key = "__all", label = FLT.SkinHex("ffd35a") .. "Remove all|r" } end
      openDropDown(self, opts, nil, function(k)
        if k == "__all" then LR.ClearKept() elseif k ~= "__none" then LR.RemoveKept(k) end
        show()
      end, 260)
    end)
    refreshers[#refreshers + 1] = show
  end
  g = group(c, "Spellbook")
  check(g, "Trainer button in the spellbook", "A book button in the spellbook (P) opens the trainer window.", "Shows the spells and ranks your class trainer teaches that you do not know yet, next to the spellbook.", "spellbookTrainer",
    nil, nil, function(v) Q.Set("spellbookTrainer", v); local psf = rawget(_G, "PlayerSpellsFrame"); local b = type(psf) == "table" and psf.ofaTrainerButton; if b then b:SetShown(v) end end)
  -- POPUPS & ALERTS (moved from Settings, 5.6.8, user 22.10.)
  c = category("alerts", "Popups & Alerts", "Interface\\Icons\\INV_Misc_Bell_01", "Popups that come up on their own while you play.")
  g = group(c, "Buff reminder")
  check(g, "Buff reminder", "A small popup when one of your buffs runs out.", "Add your own buffs below (e.g. Demon Skin) with the time in seconds. When the buff has less time left, or has run out, a small popup says so; click its icon to cast the buff again (not in combat - there it only shows). It goes away by itself once you renew the buff. Drag the popup to move it.", "buffReminder")
  check(g, "Sleep in cities", "No buff reminder in the capitals.", "Stormwind, Ironforge, Darnassus, Orgrimmar, Thunder Bluff and Undercity. Buffs that ran out there are shown once you leave.", "buffSleepCities", 24)
  check(g, "Show icon only", "Only the buff's icon with the time left on it, no name.", "The time bar under it is as wide as the icon. Several icons sit next to each other.", "buffIconOnly", 24)
  do -- size slider and Test (user 01.11.): Test shows the reminder for 10 seconds to set its size and drag it
    local r = row(g, "Size", "How large the reminder is. Test shows it for 10 seconds.", nil, 24)
    button(r, "Test", 50, "Shows the reminder for 10 seconds, so you can see its size and drag it where you want it.", function() Q.BuffTest() end)
    local val = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); val:SetTextColor(FLT.SkinC(1, 0.82, 0.2))
    val:SetWidth(40); val:SetJustifyH("RIGHT"); place(r, val, 10)
    local sl = UI.Slider(r, 130, 50, 150, 5, function(v)
      val:SetText(v .. " %")
      if Q.Get("buffScale") ~= v then Q.Set("buffScale", v) end
    end)
    place(r, sl, 10)
    hint(sl, "Size", "50 - 150 %. Mouse wheel or drag.")
    refreshers[#refreshers + 1] = function() local v = Q.Get("buffScale") or 100; sl:SetValue(v); val:SetText(v .. " %") end
  end
  do
    local r = row(g, "Add a buff", "Spell name and seconds left when you want the reminder.", "Any buff name works, also without a suggestion - the list only helps. The name as in your spellbook, e.g. \"Demon Skin\". Flasks and elixirs: the name of their buff (e.g. \"Supreme Power\"). Weapon oils, sharpening stones and poisons: type their name (\"sh\" shows the sharpening stones) and pick \"(main hand)\", or add \"(off hand)\" for the other weapon; a click on the reminder uses it on that weapon when it is in your bags. Seconds: 5 - 3600.", 24)
    local list -- the list button, below
    local nameBox, secBox
    local function add()
      local n = Q.AddBuffReminder(nameBox:GetText(), secBox:GetText())
      if n then nameBox:SetText(""); nameBox:ClearFocus(); secBox:ClearFocus(); if list then list.show() end end
    end
    button(r, "Add", 50, nil, add)
    secBox = FLT.SkinBlizz(CreateFrame("EditBox", nil, r, "InputBoxTemplate"))
    -- "sec" behind the box (user 03.11.: not clear that 30 are seconds)
    local secLabel = FLT.NewFS(r, nil, "OVERLAY", "GameFontDisableSmall"); secLabel:SetText("sec")
    secLabel:SetPoint("RIGHT", r, "RIGHT", -10 - r.rightW, 0); r.rightW = r.rightW + (secLabel:GetStringWidth() or 18) + 6
    secBox:SetSize(40, 20); secBox:SetAutoFocus(false); secBox:SetMaxLetters(4); secBox:SetNumeric(true); secBox:SetText("30"); place(r, secBox, 10)
    nameBox = FLT.SkinBlizz(CreateFrame("EditBox", nil, r, "InputBoxTemplate"))
    nameBox:SetSize(150, 20); nameBox:SetAutoFocus(false); nameBox:SetMaxLetters(40); place(r, nameBox, 12)
    for _, eb in ipairs({ nameBox, secBox }) do
      eb:SetScript("OnEnterPressed", add)
      eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    -- suggestions while typing (and the class's usual buffs on an empty box): click one to take it
    local function suggest(self)
      UI.CloseDropDown()
      if not self:HasFocus() then return end
      local opts = {}
      for _, e in ipairs(Q.BuffSuggestions(self:GetText())) do
        opts[#opts + 1] = { key = e.label or e.name, label = "|T" .. Q.BuffIcon(e.name) .. ":14:14|t " .. (e.label or e.name) .. (e.preset and "  |cff9d9d9d(class buff)|r" or (e.notInBags and "  |cff9d9d9d(none in bags)|r" or "")) }
      end
      -- no suggestion: say that any name works (user 03.11.: players thought they could only pick from the list)
      if #opts == 0 and self:GetText() ~= "" then
        opts[1] = { key = "__any", label = "|cff9d9d9dNo suggestion - any buff name works: press Enter or Add|r" }
      end
      if #opts > 0 then openDropDown(self, opts, nil, function(k)
        if k == "__any" then self:SetFocus(); return end
        nameBox:SetText(k); secBox:SetFocus(); secBox:HighlightText()
      end, 340) end -- 260 was too narrow for "... (main hand)" (user 01.11.)
    end
    -- grey example while empty: any name can be typed, the list only helps (hooked after SetScript - beta13 set it
    -- before, the SetScript calls replaced the hooks and the example stayed under the typed text)
    local hint = FLT.NewFS(nameBox, nil, "ARTWORK", "GameFontDisableSmall"); hint:SetPoint("LEFT", 6, 0); hint:SetPoint("RIGHT", -4, 0)
    hint:SetJustifyH("LEFT"); hint:SetText("any buff, e.g. Demon Skin"); if hint.SetWordWrap then hint:SetWordWrap(false) end
    local function paintHint() hint:SetShown(nameBox:GetText() == "" and not nameBox:HasFocus()) end
    nameBox:SetScript("OnTextChanged", function(self, user) paintHint(); if user then suggest(self) end end)
    nameBox:SetScript("OnEditFocusGained", function(self) paintHint(); if self:GetText() == "" then suggest(self) end end)
    nameBox:SetScript("OnEditFocusLost", paintHint)
    paintHint()
    r:SetScript("OnClick", function() nameBox:SetFocus() end)
    -- the watched buffs: a click on one removes it
    local lr = row(g, "Watched buffs", "Click a buff in the list to remove it.", nil, 24)
    local b, arrow = dropButton(lr, 200)
    local function show()
      local n = #Q.GetBuffReminders()
      b:SetLabel(n == 0 and "None yet" or (n == 1 and "1 buff" or (n .. " buffs")))
    end
    b:SetScript("OnClick", function(self)
      local opts = {}
      for _, e in ipairs(Q.GetBuffReminders()) do
        opts[#opts + 1] = { key = e.name, label = "|T" .. Q.BuffIcon(e.name) .. ":14:14|t " .. (e.label or e.name) .. "  |cff9d9d9d" .. e.sec .. " s|r", remove = true }
      end
      if #opts == 0 then opts = { { key = "__none", label = "|cff9d9d9dNo buffs yet|r" } }
      else opts[#opts + 1] = { key = "__all", label = FLT.SkinHex("ffd35a") .. "Remove all|r" } end
      openDropDown(self, opts, nil, function(k)
        if k == "__all" then Q.ClearBuffReminders() elseif k ~= "__none" then Q.RemoveBuffReminder(k) end
        show()
      end, 340) -- room for "... (main hand)  60 s" (user 01.11.)
    end)
    b.show = show; list = b
    refreshers[#refreshers + 1] = show
  end
  g = group(c, "Popups")
  check(g, "Durability warning", "Warns when your gear drops to 20% durability.", nil, "durability")
  check(g, "Nearby Library Book alerts", "Popup when you are close to a missing library book.", nil, nil, nil,
    function() return FLT.IsNearbyAlertsEnabled and FLT:IsNearbyAlertsEnabled() and true or false end,
    function(v) if FLT.SetNearbyAlertsEnabled then FLT:SetNearbyAlertsEnabled(v) end end)
  check(g, "Pet ability alerts  |cff9d9d9d(Hunter)|r", "Popup when a beast nearby teaches a higher ability rank your pets can learn.", nil, nil, nil,
    function() return FLT.IsPetTeachAlertsEnabled and FLT:IsPetTeachAlertsEnabled() and true or false end,
    function(v) if FLT.SetPetTeachAlertsEnabled then FLT:SetPetTeachAlertsEnabled(v) end end)
  check(g, "Quest share popup in dungeons", "Opens when a group member can still accept one of your dungeon quests.", nil, nil, nil,
    function() return not (type(OneForAllDB) == "table" and type(OneForAllDB.questShare) == "table" and OneForAllDB.questShare.popup == false) end,
    function(v) if type(OneForAllDB) == "table" then OneForAllDB.questShare = OneForAllDB.questShare or {}; OneForAllDB.questShare.popup = v and true or false end end)
  ---------------------------------------------------------------------------------------------------

  -- left: one button per group with "on / switches"
  local navButtons = {}
  local function selectCat(key)
    current = key
    for _, b in ipairs(navButtons) do b:SetActive(b.key == key) end
    layout()
  end
  local searchBox
  for i, cat in ipairs(cats) do
    local b = UI.NavEntry(nav, navTop - (i - 1) * UI.NAV.step, cat.nav or cat.label, cat.icon)
    b.key = cat.key
    b.count = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); b.count:SetPoint("RIGHT", -5, 0)
    do local font, _, flags = b.count:GetFont(); if font then b.count:SetFont(font, 10, flags) end end
    if cat.new then local m = UI.NewMark(b, "New options in this group."); m:SetPoint("RIGHT", b.count, "LEFT", -2, 0) end
    b:SetScript("OnClick", function() if search ~= "" then searchBox:SetText("") end; selectCat(cat.key) end)
    cat.nav = b
    navButtons[i] = b
  end
  updateCounts = function()
    for _, cat in ipairs(cats) do
      local on = 0
      for _, get in ipairs(cat.checks) do if get() then on = on + 1 end end
      cat.nav.count:SetText(on .. "/" .. #cat.checks)
    end
  end

  -- search over all groups (name, description and tooltip text)
  onSearch = function(t)
    search = t
    for _, b in ipairs(navButtons) do b:SetActive(search == "" and b.key == current) end
    layout()
  end
  searchBox = head.box

  local function heading(t, y)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", 8, y); t:Show(); t.divider:Show()
    return y - 30
  end
  local function put(r, y)
    if not r.fitted then -- the grey line ends before the controls on the right
      r.desc:SetWidth(ROW_W - 60 - r.indent - r.rightW - 16); r.fitted = true
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, y); r:Show()
    return y - 36
  end
  layout = function()
    for _, cat in ipairs(cats) do
      cat.title:Hide(); cat.title.divider:Hide()
      for _, gr in ipairs(cat.groups) do gr.title:Hide(); gr.title.divider:Hide(); for _, r in ipairs(gr.rows) do r:Hide() end end
    end
    local y = -6
    if search == "" then
      local cat
      for _, x in ipairs(cats) do if x.key == current then cat = x end end
      FLT.SetTex(hIcon, cat.icon); hTitle:SetText(cat.label); hSub:SetText(cat.desc)
      for _, gr in ipairs(cat.groups) do
        y = heading(gr.title, y)
        for _, r in ipairs(gr.rows) do y = put(r, y) end
        y = y - 10
      end
      empty:Hide()
    else
      local n = 0
      for _, cat in ipairs(cats) do
        local first = true
        for _, gr in ipairs(cat.groups) do
          for _, r in ipairs(gr.rows) do
            if r.find:find(search, 1, true) then
              if first then y = heading(cat.title, y); first = false end
              y = put(r, y); n = n + 1
            end
          end
        end
        if not first then y = y - 10 end
      end
      FLT.SetTex(hIcon, "Interface\\Icons\\INV_Misc_Spyglass_02"); hTitle:SetText("Search")
      hSub:SetText(n == 1 and "1 setting found in all groups." or (n .. " settings found in all groups."))
      empty:SetShown(n == 0)
    end
    child:SetHeight(-y + 8)
    if sf.SetVerticalScroll then sf:SetVerticalScroll(0) end
  end
  selectCat("iface")

  panel:SetScript("OnShow", function() for _, f in ipairs(refreshers) do f() end; updateCounts() end)
  panel:SetScript("OnHide", function() UI.CloseDropDown(); if neverMenu then neverMenu:Hide() end end)
  panel:Hide()
  return panel
end

UI.RegisterPanel({ key="qol", label="Quality of Life", order=4, tabWidth=140, create=createQoLPanel })
