local _, FLT = ...
local unpack = unpack or table.unpack
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton

-- Main window: title bar, tab bar and the registered panels (see Widgets.lua).
local frame
local panels = {}      -- key -> panel frame
local tabButtons = {}  -- key -> tab button
local activeTab = nil
local defaultTab -- defined below (last used tab, else the first shown tab)

-- Panels are built the first time their tab is opened (saves memory for tabs
-- that are never used in a session).
local function ensurePanel(key)
  if panels[key] then return panels[key] end
  if not frame then return nil end
  for _, spec in ipairs(UI.panels) do
    if spec.key == key then
      local panel = spec.create(frame)
      if panel then
        panels[key] = panel; panel:Hide()
        -- the window's refresh ran before this tab existed: catch up now
        if panel.Refresh then panel:Refresh() end
      end
      return panel
    end
  end
end
function UI.EnsurePanel(key) return ensurePanel(key) end

local function setPanelTab(tab)
  activeTab = tab or defaultTab()
  ensurePanel(activeTab)
  -- remember the tab per character: the window opens on it next time
  if activeTab ~= "settings" and type(OneForAllCharDB) == "table" then OneForAllCharDB.lastTab = activeTab end
  for key, panel in pairs(panels) do
    if key == activeTab then
      panel:Show()
      -- bag/bank changes while this tab was hidden: catch up now
      if panel.ofaStale then panel.ofaStale = nil; if panel.Refresh then panel:Refresh() end end
    else panel:Hide() end
  end
  for key, b in pairs(tabButtons) do
    if b.SetActive then b:SetActive(key == activeTab)
    elseif key == activeTab then b:LockHighlight() else b:UnlockHighlight() end
  end
end

-- Window scaling: the layout is built for 1040x650 and scaled as a whole
-- (SetScale), so every tab keeps its proportions. Scale and position are
-- saved account-wide in OneForAllDB.window.
local BASE_W, BASE_H = 1040, 690
-- Header test (user 30.10.): banner with logo and name across the top, the tabs under it, then the pages (no title band)
local HDR = { bannerH = 76, tabTop = 84, tabH = 30, tabGap = 4, iconTabW = 40 }
UI.HDR = HDR
local MIN_SCALE, MAX_SCALE = 0.6, 1.4
-- The height can additionally be stretched (bottom-edge grip) so lists show
-- more rows; stored in OneForAllDB.window.height.

local applyHeight -- defined below; used by the scale grip as well

local function windowDB()
  if type(OneForAllDB) ~= "table" then return {} end
  OneForAllDB.window = OneForAllDB.window or {}
  return OneForAllDB.window
end

local function clampScale(s)
  s = tonumber(s) or 1
  if s < MIN_SCALE then s = MIN_SCALE elseif s > MAX_SCALE then s = MAX_SCALE end
  return math.floor(s * 100 + 0.5) / 100
end

-- Puts the window's top-left corner exactly on a screen pixel. Otherwise every
-- frame edge inside sits between two pixels and the game's pixel snapping makes
-- thin gold lines jump or change their brightness when the window moves or grows.
local function snapToPixels()
  local left, top = frame:GetLeft(), frame:GetTop()
  local s = frame:GetEffectiveScale()
  if not left or not top or not s or s <= 0 then return end
  local pl, pt = math.floor(left * s + 0.5) / s, math.floor(top * s + 0.5) / s
  if math.abs(pl - left) > 0.001 or math.abs(pt - top) > 0.001 then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pl, pt)
  end
end

local function savePosition()
  snapToPixels()
  local left, top = frame:GetLeft(), frame:GetTop()
  if not left or not top then return end
  local db = windowDB()
  db.left, db.top = left, top
end

-- Keeps the top-left corner in place on screen while the scale changes.
local function applyScale(newScale)
  newScale = clampScale(newScale)
  local oldScale = frame:GetScale() or 1
  local left, top = frame:GetLeft(), frame:GetTop()
  frame:SetScale(newScale)
  if left and top then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldScale / newScale, top * oldScale / newScale)
    savePosition()
  end
  windowDB().scale = newScale
  return newScale
end

local function createResizeGrip()
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -9, 9)
  grip:SetFrameLevel(frame:GetFrameLevel() + 20)
  local GRIP = UI.ASSET_ROOT .. "grip_resize"
  grip:SetNormalTexture(GRIP)
  grip:SetHighlightTexture(GRIP)
  local ht = grip:GetHighlightTexture(); if ht and ht.SetBlendMode then ht:SetBlendMode("ADD") end
  grip:SetPushedTexture(GRIP)
  FLT.SkinArtTex(grip:GetNormalTexture()); FLT.SkinArtTex(grip:GetHighlightTexture()); FLT.SkinArtTex(grip:GetPushedTexture())
  local pt = grip:GetPushedTexture(); if pt and pt.SetVertexColor then pt:SetVertexColor(FLT.SkinC(0.7, 0.6, 0.4)) end

  local dragging
  grip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    dragging = true
    self:SetScript("OnUpdate", function()
      if not dragging then return end
      local cx = GetCursorPosition()                       -- screen pixels
      local parentScale = UIParent:GetEffectiveScale()
      local left = frame:GetLeft() * frame:GetEffectiveScale() -- screen pixels
      local width = cx - left
      if width > 0 then
        local s = clampScale(width / (BASE_W * parentScale))
        if math.abs(s - (frame:GetScale() or 1)) >= 0.01 then applyScale(s) end
      end
    end)
  end)
  local function stop(self)
    dragging = false
    self:SetScript("OnUpdate", nil)
    savePosition()
  end
  grip:SetScript("OnMouseUp", function(self) stop(self); applyHeight(frame:GetHeight()) end)
  grip:SetScript("OnHide", stop)
  grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Resize window", 1, 0.82, 0)
    GameTooltip:AddLine("Drag to scale the whole window. /ofa scale resets it.", 1, 1, 1, true)
    GameTooltip:AddLine(string.format("Current size: %d%%", math.floor((frame:GetScale() or 1) * 100 + 0.5)), 0.72, 0.72, 0.72)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Largest height that still fits on screen at the current scale.
local function maxHeight()
  local screenH = UIParent:GetHeight() * UIParent:GetEffectiveScale()
  return math.max(BASE_H, math.floor(screenH / frame:GetEffectiveScale()) - 20)
end

local function clampHeight(h)
  h = tonumber(h) or BASE_H
  if h < BASE_H then h = BASE_H end
  if frame then local m = maxHeight(); if h > m then h = m end end
  return math.floor(h + 0.5)
end

applyHeight = function(h)
  h = clampHeight(h)
  frame:SetHeight(h)
  windowDB().height = (h > BASE_H) and h or nil
  return h
end

local function createHeightGrip()
  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(140, 16)
  grip:SetPoint("CENTER", frame, "BOTTOM", 0, 1) -- on the window's bottom line (user 27.10.)
  grip:SetFrameLevel(frame:GetFrameLevel() + 20)
  local bar = grip:CreateTexture(nil, "ARTWORK")
  bar:SetSize(64, 16); bar:SetPoint("CENTER")
  FLT.SetTex(bar, UI.ASSET_ROOT .. "grip_height"); bar:SetAlpha(0.8)
  local hi = grip:CreateTexture(nil, "HIGHLIGHT")
  hi:SetSize(64, 16); hi:SetPoint("CENTER")
  FLT.SetTex(hi, UI.ASSET_ROOT .. "grip_height"); hi:SetBlendMode("ADD")

  local dragging
  grip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    dragging = true
    self:SetScript("OnUpdate", function()
      if not dragging then return end
      local _, cy = GetCursorPosition()                      -- screen pixels
      local eff = frame:GetEffectiveScale()
      local top = frame:GetTop() * eff                        -- screen pixels
      local h = (top - cy) / eff
      if math.abs(h - frame:GetHeight()) >= 1 then applyHeight(h) end
    end)
  end)
  local function stop(self)
    dragging = false
    self:SetScript("OnUpdate", nil)
  end
  grip:SetScript("OnMouseUp", stop)
  grip:SetScript("OnHide", stop)
  grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Window height", 1, 0.82, 0)
    GameTooltip:AddLine("Drag up or down to make the window taller and show more rows. /ofa scale resets it.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Tab visibility is stored per character (OneForAllCharDB.tabs).
-- Without a saved choice a tab is shown, unless its panel spec lists the
-- classes it is meant for (spec.classes, e.g. a class-only tab).
local function playerClass()
  if not UnitClass then return nil end
  local _, token = UnitClass("player")
  return token
end

function UI.IsTabVisible(key)
  if key == "settings" then return true end
  local saved = type(OneForAllCharDB) == "table" and OneForAllCharDB.tabs and OneForAllCharDB.tabs[key]
  if saved ~= nil then return saved and true or false end
  for _, spec in ipairs(UI.panels) do
    if spec.key == key and spec.classes then
      local cls = playerClass()
      for _, c in ipairs(spec.classes) do if c == cls then return true end end
      return false
    end
  end
  return true
end

function UI.SetTabVisible(key, visible)
  if key == "settings" or type(OneForAllCharDB) ~= "table" then return end
  OneForAllCharDB.tabs = OneForAllCharDB.tabs or {}
  OneForAllCharDB.tabs[key] = visible and true or false
  UI.LayoutTabs()
end

function UI.ResetTabs()
  if type(OneForAllCharDB) == "table" then OneForAllCharDB.tabs = nil end
  UI.LayoutTabs()
end

-- Tab order (per character, OneForAllCharDB.tabOrder = list of keys).
-- Settings is fixed at the right window edge (6.0.1, user 30.10.); the other tabs can be moved.
local FIXED_TABS = { settings = true }
function UI.SortableTabs()
  local saved = type(OneForAllCharDB) == "table" and OneForAllCharDB.tabOrder
  local pos = {}
  if type(saved) == "table" then for i, k in ipairs(saved) do pos[k] = i end end
  local list = {}
  for i, spec in ipairs(UI.panels) do
    if not FIXED_TABS[spec.key] then list[#list + 1] = { spec = spec, def = i } end
  end
  table.sort(list, function(a, b)
    local pa, pb = pos[a.spec.key], pos[b.spec.key]
    if pa and pb then return pa < pb end
    if pa then return true end
    if pb then return false end
    return a.def < b.def
  end)
  local out = {}
  for i, e in ipairs(list) do out[i] = e.spec end
  return out
end
function UI.OrderedPanels()
  local out = {}
  for _, spec in ipairs(UI.SortableTabs()) do out[#out + 1] = spec end
  for _, spec in ipairs(UI.panels) do if FIXED_TABS[spec.key] then out[#out + 1] = spec end end
  return out
end
function UI.MoveTab(key, dir)
  if type(OneForAllCharDB) ~= "table" then return end
  local list = UI.SortableTabs()
  local idx
  for i, spec in ipairs(list) do if spec.key == key then idx = i end end
  local j = idx and idx + dir
  if not idx or j < 1 or j > #list then return end
  list[idx], list[j] = list[j], list[idx]
  local order = {}
  for i, spec in ipairs(list) do order[i] = spec.key end
  OneForAllCharDB.tabOrder = order
  UI.LayoutTabs()
end
function UI.ResetTabOrder()
  if type(OneForAllCharDB) == "table" then OneForAllCharDB.tabOrder = nil end
  UI.LayoutTabs()
end

-- Start tab: the last used tab of this character, else the first shown tab.
function defaultTab()
  local last = type(OneForAllCharDB) == "table" and OneForAllCharDB.lastTab
  if type(last) == "string" and last ~= "settings" and UI.IsTabVisible(last) then
    for _, spec in ipairs(UI.panels) do if spec.key == last then return last end end
  end
  for _, spec in ipairs(UI.SortableTabs()) do
    if UI.IsTabVisible(spec.key) then return spec.key end
  end
  return "settings"
end

function UI.LayoutTabs()
  if not frame then return end
  -- header test: the tabs fill the bar under the banner; each = glyph + name + the same padding on both sides,
  -- Settings (glyph only) fixed at the right edge (user 30.10.)
  local x, right = UI.PANEL_INSET, UI.PANEL_INSET
  local contentW, n = 0, 0
  for _, spec in ipairs(UI.OrderedPanels()) do
    local b = tabButtons[spec.key]
    if b and not FIXED_TABS[spec.key] and UI.IsTabVisible(spec.key) then n = n + 1; contentW = contentW + b:ContentWidth() end
  end
  local avail = BASE_W - x - right - HDR.iconTabW - HDR.tabGap * n - contentW
  local pad = math.max(8, math.floor(avail / math.max(1, 2 * n)))
  for _, spec in ipairs(UI.OrderedPanels()) do
    local b = tabButtons[spec.key]
    if b then
      b:ClearAllPoints()
      if FIXED_TABS[spec.key] then
        b:SetPoint("TOPRIGHT", -right, -HDR.tabTop); b:SetWidth(HDR.iconTabW); b:Show()
      elseif UI.IsTabVisible(spec.key) then
        local w = b:ContentWidth() + 2 * pad
        b:SetPoint("TOPLEFT", x, -HDR.tabTop); b:SetWidth(w); b:Show()
        x = x + w + HDR.tabGap
      else
        b:Hide()
      end
    end
  end
  if activeTab and not UI.IsTabVisible(activeTab) and panels[activeTab] then setPanelTab(defaultTab()) end
end

-- Tab button: same plate skin as the gold buttons; the active tab glows.
-- header test: a small glyph in front of each tab name (Assets/tab_icons, 4x2 atlas, own art: tools/art/tab_icons.py)
local TAB_GLYPH = { settings = 7, armory = 0, dungeons = 1, professions = 2, qol = 3, talents = 4, books = 5, pets = 6 }
-- header test (ht2, user 30.10.: "die Haupt-Tabs so wie im Refined"): browser-style tabs that stand on one line.
-- Every tab has an edge on the left, top and right and none at the bottom; inactive tabs end 1 above the line, the
-- active one reaches over it: dark warm plate, a gold sheen from the top, a gold edge, a soft glow around it and the
-- glow line along its bottom.
local TAB_TEXT, TAB_TEXT_ON = { 0.84, 0.80, 0.72 }, { 1, 0.90, 0.62 }
local TAB_ICON, TAB_ICON_ON = { 0.80, 0.62, 0.36 }, { 1, 0.80, 0.40 }
local function openBottom(rr, anchor)
  local p = rr.pieces -- tl, tr, bl, br, top, bot, left, right[, mid]
  p[3]:Hide(); p[4]:Hide(); p[6]:Hide()
  rr.pieces = { p[1], p[2], p[5], p[7], p[8], p[9] } -- SetShown / SetColor leave the bottom pieces hidden
  p[7]:ClearAllPoints(); p[7]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT"); p[7]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 8, 0)
  p[8]:ClearAllPoints(); p[8]:SetPoint("TOPRIGHT", p[2], "BOTTOMRIGHT"); p[8]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", -8, 0)
  if p[9] then p[9]:ClearAllPoints(); p[9]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT"); p[9]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -8, 0) end
  return rr
end
local function makeTab(parent, text, w, h, key)
  local RING = UI.ASSET_ROOT .. "window_ring" -- radius 4, line 1 at corner size 8
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  local inner = CreateFrame("Frame", nil, b); inner:SetPoint("TOPLEFT"); inner:SetPoint("BOTTOMRIGHT", 0, 1)
  local plateOff = UI.MarkBG(openBottom(UI.RoundRect(b, inner, "BACKGROUND", 0, 8, 0, 0.085, 0.078, 0.066, 1), inner))
  local edgeOff = openBottom(UI.RoundRect(b, inner, "BORDER", 0, 8, 0, 0.36, 0.28, 0.16, 1, RING), inner)
  local plate = UI.MarkBG(openBottom(UI.RoundRect(b, b, "BACKGROUND", 0, 8, 0, 0.21, 0.15, 0.08, 1), b))
  local sheen = b:CreateTexture(nil, "BACKGROUND", nil, 2); FLT.SetTex(sheen, UI.ASSET_ROOT .. "shade_lr")
  sheen:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) -- the left-to-right fade turned: strong at the top, none at the bottom
  sheen:SetPoint("TOPLEFT", 1, -1); sheen:SetPoint("BOTTOMRIGHT", -1, 0); sheen:SetVertexColor(1, 0.78, 0.35); sheen:SetAlpha(0.30)
  local edge = openBottom(UI.RoundRect(b, b, "BORDER", 1, 8, 0, 1, 0.80, 0.40, 1, RING), b)
  local glow = UI.Nine(b, b, UI.ASSET_ROOT .. "btn_glow", 10, 6, "BACKGROUND", -1)
  local function glowTop() for k, t in ipairs(glow.pieces) do if k == 3 or k == 4 or k == 6 or k == 9 then t:Hide() end end end
  glowTop()
  local point = UI.GlowLine(b)
  local hov = openBottom(UI.RoundRect(b, inner, "HIGHLIGHT", 0, 8, 0, 0.07, 0.06, 0.04, 1), inner)
  for _, t in ipairs(hov.pieces) do t:SetBlendMode("ADD") end
  local label = FLT.NewFS(b, nil, "OVERLAY", "GameFontNormal")
  label:SetText(text)
  do local font, _, flags = label:GetFont(); if font then label:SetFont(font, 13, flags) end end
  local gi = key and TAB_GLYPH[key]
  if gi then
    local ic = b:CreateTexture(nil, "OVERLAY"); ic:SetSize(16, 16)
    local x, y = (gi % 4) * 0.25, math.floor(gi / 4) * 0.5
    FLT.SetTex(ic, UI.ASSET_ROOT .. "tab_icons"); ic:SetTexCoord(x, x + 0.25, y, y + 0.5)
    b.glyph = ic
  end
  local function place(dx, dy)
    label:ClearAllPoints()
    if b.glyph and text ~= "" then
      local tw = 16 + 7 + (label:GetStringWidth() or 0)
      b.glyph:ClearAllPoints(); b.glyph:SetPoint("LEFT", b, "CENTER", -tw / 2 + dx, dy + 1); label:SetPoint("LEFT", b.glyph, "RIGHT", 7, 0)
    elseif b.glyph then b.glyph:ClearAllPoints(); b.glyph:SetPoint("CENTER", dx, dy + 1)
    else label:SetPoint("CENTER", dx, dy + 1) end
  end
  place(0, 0)
  b._label = label
  function b:ContentWidth() return (b.glyph and 23 or 0) + math.ceil(label:GetStringWidth() or 60) end
  function b:SetActive(on)
    on = on and true or false
    plateOff:SetShown(not on); edgeOff:SetShown(not on)
    plate:SetShown(on); edge:SetShown(on); sheen:SetShown(on); glow:SetShown(on); point:SetShown(on)
    glowTop()
    label:SetTextColor(unpack(on and TAB_TEXT_ON or TAB_TEXT))
    if b.glyph then b.glyph:SetVertexColor(unpack(on and TAB_ICON_ON or TAB_ICON)) end
  end
  b:SetActive(false)
  b:SetScript("OnMouseDown", function() place(1, -1) end)
  b:SetScript("OnMouseUp", function() place(0, 0) end)
  return b
end

-- The window's rounded line (see OrnateFrame) drawn over the template's border; the template's own border is hidden.
local function decorateWindow()
  -- the template's backgrounds have square corners that stick out of the
  -- rounded line, so they are hidden and replaced by an own rounded background
  for _, r in ipairs({ frame:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
  end
  if type(frame.Inset) == "table" and type(frame.Inset.NineSlice) == "table" then frame.Inset.NineSlice:SetAlpha(0) end
  UI.MarkBG(UI.RoundRect(frame, frame, "BACKGROUND", -8, 8, 1, 0.065, 0.058, 0.048, 0.97), "base")
  if type(frame.Inset) == "table" and type(frame.Inset.Bg) == "table" then UI.MarkBG(frame.Inset.Bg, "base") end
  if type(frame.NineSlice) == "table" then frame.NineSlice:SetAlpha(0) end
  for _, k in ipairs({ "TopLeftCorner", "TopRightCorner", "BotLeftCorner", "BotRightCorner", "TopBorder", "BottomBorder", "LeftBorder", "RightBorder" }) do
    if type(frame[k]) == "table" and frame[k].SetAlpha then frame[k]:SetAlpha(0) end
  end
  -- own opaque title bar (the template's bar leaves a see-through strip)
  if type(frame.TitleBg) == "table" and frame.TitleBg.SetAlpha then frame.TitleBg:SetAlpha(0) end
  local bar = frame:CreateTexture(nil, "BORDER", nil, 1)
  -- 4 px in, so its square corners stay under the rounded window line
  local pad = 4
  bar:SetPoint("TOPLEFT", pad, -pad); bar:SetPoint("TOPRIGHT", -pad, -pad); bar:SetHeight(28 - pad)
  bar:SetColorTexture(FLT.SkinC(0.055, 0.047, 0.038, 1)); UI.MarkBG(bar, "base")
  local barShine = frame:CreateTexture(nil, "BORDER", nil, 2)
  barShine:SetPoint("TOPLEFT", bar, "TOPLEFT"); barShine:SetPoint("TOPRIGHT", bar, "TOPRIGHT"); barShine:SetHeight(11)
  barShine:SetColorTexture(FLT.SkinC(1, 0.85, 0.45, 0.04)); UI.MarkBG(barShine, "base")
  local barLine = frame:CreateTexture(nil, "BORDER", nil, 3)
  barLine:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 6, 0); barLine:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -6, 0); barLine:SetHeight(1)
  barLine:SetColorTexture(FLT.SkinC(0.72, 0.50, 0.12, 0.75))
  bar:Hide(); barShine:Hide(); barLine:Hide() -- header test: the banner takes the title bar's place
  local deco = CreateFrame("Frame", nil, frame)
  deco:SetAllPoints()
  deco:SetFrameLevel(frame:GetFrameLevel() + 18)
  local edge = UI.OrnateFrame(deco, frame, 34, 7, "OVERLAY", 0, UI.ASSET_ROOT .. "window_frame")
  -- the height grip sits on the bottom line, with a small gap in the line around it and round line ends (user 27.10.):
  -- the bottom piece is split in two; each inner end is a 14 px tile (Assets/line_cap: the frame texture's bottom strip
  -- with a round end) placed exactly like the line piece, so it lines up with the line at any UI scale
  do
    local bl, br, bot = edge[3], edge[4], edge[6]
    local gap, capW = 34, 14 -- gap: half of the grip bar (28) + 6 px on each side
    local tex, cap = bot:GetTexture(), UI.ASSET_ROOT .. "line_cap"
    local r, g, b, a = bot:GetVertexColor()
    bot:ClearAllPoints(); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -gap - capW, 0)
    local right = deco:CreateTexture(nil, "OVERLAY", nil, 0)
    right:SetTexture(tex); right:SetTexCoord(bot:GetTexCoord()); right:SetVertexColor(r, g, b, a)
    right:SetPoint("TOPRIGHT", br, "TOPLEFT"); right:SetPoint("BOTTOMLEFT", frame, "BOTTOM", gap + capW, 0)
    local endL = deco:CreateTexture(nil, "OVERLAY", nil, 0)
    endL:SetTexture(cap); endL:SetVertexColor(r, g, b, a)
    endL:SetPoint("TOPLEFT", bot, "TOPRIGHT"); endL:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -gap, 0)
    local endR = deco:CreateTexture(nil, "OVERLAY", nil, 0)
    endR:SetTexture(cap); endR:SetTexCoord(1, 0, 0, 1); endR:SetVertexColor(r, g, b, a)
    endR:SetPoint("TOPRIGHT", right, "TOPLEFT"); endR:SetPoint("BOTTOMLEFT", frame, "BOTTOM", gap, 0)
    for _, t in ipairs({ right, endL, endR }) do t:Hide() end
  end
  for _, t in ipairs(edge) do t:Hide() end
  -- Header test (user 30.10.): the outer frame like the Classic Refined test - a thin dark gold line with small
  -- corners (Assets/window_ring: radius 4, line 1) and short, faint gold accents at the four corners (the corner arc,
  -- two lines fading out along the edges, a soft shine inside: fade_lr, corner_glow, edge_fade, tools/art/edge_glow.py)
  do
    UI.WindowFrame(deco, frame) -- ht7: shared with the popups (UI/Widgets.lua)
    -- the banner across the top (Assets/qol_banner: tavern, camp fire, landscape), solid dark behind the logo on the
    -- left, fading into the window at the bottom
    local art = frame:CreateTexture(nil, "BORDER", nil, 0)
    -- ht8 (user 30.10.: the whole griffin): the picture at the banner's height on the right (its aspect 6.38), the dark
    -- logo side fills the rest and fades into it
    -- ht10 (user 30.10.): over the whole width again
    art:SetPoint("TOPLEFT", 1, -1); art:SetPoint("TOPRIGHT", -1, -1); art:SetHeight(HDR.bannerH)
    -- ht6 (user 30.10.): the user's banner picture to try (Assets/header_banner, tools/art/header_banner.py)
    FLT.SetTex(art, UI.ASSET_ROOT .. "header_banner"); art:SetTexCoord(0, 1, 0, 1) -- ht7: the second picture
    local dim = frame:CreateTexture(nil, "BORDER", nil, 1); dim:SetAllPoints(art); dim:SetColorTexture(0, 0, 0, 0.12)
    local BG = { 0.065, 0.058, 0.048 }
    local solid = frame:CreateTexture(nil, "BORDER", nil, 2); solid:SetColorTexture(BG[1], BG[2], BG[3], 1)
    solid:SetPoint("TOPLEFT", art, "TOPLEFT"); solid:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT"); solid:SetWidth(150)
    -- 6.1.0 (user 03.11.: the picture stopped "hard" on the left): a real gradient from fully solid to clear, wider;
    -- shade_lr starts at 92 % only, which left a visible step where the solid part ends
    local fadeL = frame:CreateTexture(nil, "BORDER", nil, 2)
    fadeL:SetPoint("TOPLEFT", solid, "TOPRIGHT"); fadeL:SetPoint("BOTTOMLEFT", solid, "BOTTOMRIGHT"); fadeL:SetWidth(240)
    fadeL:SetColorTexture(1, 1, 1, 1)
    if not (fadeL.SetGradient and CreateColor and pcall(fadeL.SetGradient, fadeL, "HORIZONTAL", CreateColor(BG[1], BG[2], BG[3], 1), CreateColor(BG[1], BG[2], BG[3], 0))) then
      if fadeL.SetGradientAlpha then fadeL:SetGradientAlpha("HORIZONTAL", BG[1], BG[2], BG[3], 1, BG[1], BG[2], BG[3], 0)
      else FLT.SetTex(fadeL, UI.ASSET_ROOT .. "shade_lr"); fadeL:SetVertexColor(BG[1], BG[2], BG[3]); fadeL:SetWidth(170) end
    end
    local fadeB = frame:CreateTexture(nil, "BORDER", nil, 3); FLT.SetTex(fadeB, UI.ASSET_ROOT .. "shade_lr"); fadeB:SetVertexColor(BG[1], BG[2], BG[3])
    fadeB:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    fadeB:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT"); fadeB:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT"); fadeB:SetHeight(14)
    -- no line under the banner (user 03.11., after testing it thin and without: "sieht besser aus")
  end
  -- the gold top edge covers the template's title position: move the title down
  if type(frame.TitleText) == "table" and frame.TitleText.ClearAllPoints then
    frame.TitleText:ClearAllPoints(); frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -10)
  end
  -- own close button in the gold plate style, centred in the title bar left
  -- of the ornate corner (the template's red button is hidden)
  if type(frame.CloseButton) == "table" and frame.CloseButton.Hide then frame.CloseButton:Hide() end
  local close = UI.GoldButton(frame, "", 30, 26, UI.ASSET_ROOT .. "icon_close", 11)
  -- header test: boxed buttons at the banner's top right
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
  close:SetFrameLevel(frame:GetFrameLevel() + 25)
  if close.icon then close.icon:ClearAllPoints(); close.icon:SetSize(14, 14); close.icon:SetPoint("CENTER", 0, 0) end
  close:SetScript("OnMouseDown", nil); close:SetScript("OnMouseUp", nil)
  close:SetScript("OnClick", function() frame:Hide() end)
  close:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(CLOSE or "Close"); GameTooltip:Show() end)
  close:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- bug report button left of the close button (the skin button is gone since 5.7.3, user 27.10.)
  local bugBtn = UI.GoldButton(frame, "", 30, 26, UI.ASSET_ROOT .. "icon_bug", 11)
  bugBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
  bugBtn:SetFrameLevel(frame:GetFrameLevel() + 25)
  if bugBtn.icon then
    bugBtn.icon:ClearAllPoints(); bugBtn.icon:SetSize(14, 14); bugBtn.icon:SetPoint("CENTER", 0, 0)
    bugBtn.icon:SetVertexColor(FLT.SkinC(1, 0.80, 0.30))
  end
  bugBtn:SetScript("OnMouseDown", nil); bugBtn:SetScript("OnMouseUp", nil)
  bugBtn:SetScript("OnClick", function() UI.ShowBugReport() end)
  bugBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Report a bug")
    GameTooltip:AddLine("Where to report bugs and ideas (GitHub or CurseForge), with your last errors to copy.", 1, 1, 1)
    GameTooltip:Show()
  end)
  bugBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Discord left of the bug button (5.7.3, user 24.10.): a speech bubble (own art), opens the invite link to copy
  local dcBtn = UI.GoldButton(frame, "", 30, 26, UI.ASSET_ROOT .. "icon_chat", 11)
  dcBtn:SetPoint("RIGHT", bugBtn, "LEFT", -6, 0)
  dcBtn:SetFrameLevel(frame:GetFrameLevel() + 25)
  if dcBtn.icon then
    dcBtn.icon:ClearAllPoints(); dcBtn.icon:SetSize(14, 14); dcBtn.icon:SetPoint("CENTER", 0, 0)
    dcBtn.icon:SetVertexColor(FLT.SkinC(1, 0.80, 0.30))
  end
  dcBtn:SetScript("OnMouseDown", nil); dcBtn:SetScript("OnMouseUp", nil)
  dcBtn:SetScript("OnClick", function() GameTooltip:Hide(); UI.ShowDiscord() end)
  dcBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Discord")
    GameTooltip:AddLine("Join the OneForAll Discord: news, questions and ideas.", 1, 1, 1)
    GameTooltip:Show()
  end)
  dcBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function createUI()
  frame = CreateFrame("Frame", "OneForAllFrame", UIParent, "BasicFrameTemplateWithInset")
  UI.mainWindow = frame -- backgrounds inside it follow the window opacity (UI.MarkBG)
  frame:SetSize(BASE_W, BASE_H)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  -- Stay above other addons' frames (waypoint arrows, raid frames ...);
  -- drop back while the world map is open so map buttons stay usable.
  frame:SetFrameStrata("DIALOG"); frame:SetToplevel(true)
  if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() frame:SetFrameStrata("MEDIUM") end)
    WorldMapFrame:HookScript("OnHide", function() frame:SetFrameStrata("DIALOG") end)
  end
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition() end)

  local db = windowDB()
  frame:SetScale(clampScale(db.scale or 1))
  db.moveAlpha = nil -- "opacity while moving" (5.6.1-beta3) was removed again
  frame:HookScript("OnShow", function() UI.ApplyWindowAlpha() end)
  if db.left and db.top then
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.left, db.top)
  else
    frame:SetPoint("CENTER")
  end
  frame:HookScript("OnShow", function() snapToPixels() end)
  decorateWindow()
  createResizeGrip()
  createHeightGrip()
  applyHeight(db.height or BASE_H)
  frame.TitleText:SetText(UI.DISPLAY_NAME .. "  |cffb8b0a0- made by Smoergi|r")
  frame.TitleText:SetTextColor(FLT.SkinC(1, 0.82, 0))
  -- header test: the logo with name and "FOREVER COMPANION" on the banner's dark left side; the credit small at the
  -- bottom left (instead of the title line)
  frame.TitleText:Hide()
  do
    local logo = frame:CreateTexture(nil, "ARTWORK"); logo:SetSize(48, 48); logo:SetPoint("TOPLEFT", 16, -14)
    FLT.SetTex(logo, FLT.LogoTexture and FLT.LogoTexture("round") or (UI.ASSET_ROOT .. "minimap_icon"))
    -- ht5 (user 30.10.): the logo in bronze-gold like Classic Refined (the same file, without colour, tinted)
    logo:SetDesaturated(true); logo:SetVertexColor(1, 0.80, 0.45)
    UI.brandLogo = logo
    local name = FLT.NewFS(frame, nil, "OVERLAY", "GameFontNormalHuge"); name:SetPoint("TOPLEFT", 76, -18)
    do local font, _, flags = name:GetFont(); if font then name:SetFont(font, 22, flags) end end
    name:SetText(UI.DISPLAY_NAME); name:SetTextColor(FLT.SkinC(1, 0.93, 0.80))
    local sub = FLT.NewFS(frame, nil, "OVERLAY", "GameFontNormalSmall"); sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 1, -4)
    do local font, _, flags = sub:GetFont(); if font then sub:SetFont(font, 10, flags) end end
    sub:SetText("FOREVER COMPANION"); sub:SetTextColor(FLT.SkinC(0.90, 0.68, 0.30))
    local credit = FLT.NewFS(frame, nil, "OVERLAY", "GameFontDisableSmall"); credit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 4)
    credit:SetText("made by Smoergi")
  end

  if frame.Inset and frame.Inset.Bg then frame.Inset.Bg:SetVertexColor(FLT.SkinC(0.11, 0.085, 0.055, 0.98)) end
  if frame.Inset and frame.Inset.Bg then frame.Inset.Bg:SetAlpha(0) end -- header test: the banner shows through

  -- Close with Escape.
  if UISpecialFrames then
    local found = false
    for _, name in ipairs(UISpecialFrames) do
      if name == frame:GetName() then found = true; break end
    end
    if not found then table.insert(UISpecialFrames, frame:GetName()) end
  end

  -- Tabs sit directly below the title bar, in the order given by each
  -- panel's "order" value. Hidden tabs (Settings > Shown tabs) are skipped.
  for _, spec in ipairs(UI.panels) do
    local key = spec.key
    local b = makeTab(frame, spec.icon and "" or spec.label, spec.tabWidth or 130, HDR.tabH + 1, key) -- 1 over the line
    if spec.icon then
      local ic = b:CreateTexture(nil, "OVERLAY")
      if b.glyph then ic:Hide() end -- header test: the tab's own glyph
      ic:SetSize(19, 19); ic:SetPoint("CENTER"); FLT.SetTex(ic, spec.icon)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(spec.label); GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    b:SetScript("OnClick", function()
      -- same small click sound as the Dungeons | Raids switch (only when the tab changes)
      if key ~= activeTab and PlaySound and type(SOUNDKIT) == "table" and SOUNDKIT.IG_CHARACTER_INFO_TAB then
        pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
      end
      setPanelTab(key)
    end)
    tabButtons[key] = b
  end
  UI.LayoutTabs()

  local tabLine = makeTexture(frame, "ARTWORK", 0.72, 0.50, 0.12, 0.65)
  tabLine:SetColorTexture(0.50, 0.38, 0.19, 1) -- ht2: the tabs stand on this line, the active one covers it
  tabLine:SetPoint("TOPLEFT", 12, -(HDR.tabTop + HDR.tabH))
  tabLine:SetPoint("TOPRIGHT", -12, -(HDR.tabTop + HDR.tabH))
  tabLine:SetHeight(1)

  setPanelTab(defaultTab())
  frame:SetScript("OnShow", function() FLT:Refresh() end)
  frame:Hide()
end

function FLT:UIRefresh()
  -- Bag/bank events fire often; there is nothing to update while the window
  -- is closed. The frame's OnShow handler refreshes it when it is opened.
  -- Only the shown tab is redrawn; hidden tabs are marked and redraw when opened.
  if not frame or not frame:IsShown() then return end
  for _, panel in pairs(panels) do
    if panel:IsShown() then
      if panel.Refresh then panel:Refresh() end
    else panel.ofaStale = true end
  end
end

-- /ofa scale [value]: without a value resets to 100 %; accepts 0.6-1.4 or 60-140.
function UI.ResetWindow() FLT:SetWindowScale(nil) end

-- Window opacity (Settings > Window): only the backgrounds (UI.MarkBG), text and pictures stay solid.
-- 70-100 %, saved account-wide in OneForAllDB.window.alpha; not set yet = 95 % (user 15.10.).
local MIN_ALPHA, DEFAULT_ALPHA = 0.7, 0.95
function UI.GetWindowAlpha()
  return math.max(MIN_ALPHA, math.min(1, tonumber(windowDB().alpha) or DEFAULT_ALPHA))
end
function UI.ApplyWindowAlpha()
  if UI.SetBackgroundAlpha then UI.SetBackgroundAlpha(UI.GetWindowAlpha()) end
end
function UI.SetWindowAlpha(a)
  a = math.max(MIN_ALPHA, math.min(1, tonumber(a) or 1))
  if a > 0.985 then a = 1 end
  windowDB().alpha = a
  UI.ApplyWindowAlpha()
end

function FLT:SetWindowScale(value)
  local s = tonumber(value) or 1
  if s > 5 then s = s / 100 end
  if not frame then createUI() end
  local applied = applyScale(s)
  if not value then
    applyHeight(BASE_H)
    frame:ClearAllPoints(); frame:SetPoint("CENTER"); savePosition()
  else
    applyHeight(frame:GetHeight()) -- keep it on screen at the new scale
  end
  return applied
end

-- Opens the window on a given tab (e.g. "professions", "hunterpets").
function FLT:OpenPanel(key)
  if not frame then createUI() end
  if key and ensurePanel(key) then
    -- a button asked for this tab: show it even if it was hidden in the settings
    if not UI.IsTabVisible(key) then UI.SetTabVisible(key, true) end
    setPanelTab(key)
  end
  frame:Show()
end

function UI.IsWindowShown() return frame ~= nil and frame:IsShown() end

function FLT:ToggleUI()
  if not frame then createUI() end
  if frame:IsShown() then frame:Hide(); return end
  -- Inside a dungeon: open straight on that dungeon's bosses & loot.
  local d = FLT.FindCurrentDungeon and FLT.FindCurrentDungeon()
  if d and UI.IsTabVisible("dungeons") and ensurePanel("dungeons") and UI.OpenDungeon then
    setPanelTab("dungeons")
    UI.OpenDungeon(d)
  end
  frame:Show()
end
