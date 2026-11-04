local ADDON, FLT = ...

-- Shared UI building blocks and the panel registry used by every tab.
-- Each tab lives in its own file under UI/ and registers itself with
-- UI.RegisterPanel(); MainFrame.lua builds the window and tab bar from that.
local UI = {}
FLT.UI = UI

UI.DISPLAY_NAME = FLT.DISPLAY_NAME or "OneForAll"
UI.ASSET_ROOT = FLT.ASSET_ROOT or ("Interface\\AddOns\\" .. ADDON .. "\\Assets\\")
local ASSET_ROOT = UI.ASSET_ROOT

-- Skin: one look only since 5.7.3 (user 27.10.): Gold Modern - plain lines with rounded corners, gold accents.
-- (The Gold / Dark Silver x Classic / Modern skins are gone; old saved choices are ignored and cleared in Core.lua.)
-- The helpers below stay as thin wrappers, so every tab keeps calling them the same way.
function FLT.SkinC(...) return ... end
-- modern style: these textures are drawn in place of the ornate ones
local MODERN_SWAP = { divider_ornate = "divider_plain" }
-- Pixel snapping: switching it off (beta3/4) made thin gold lines darker and lighter
-- with every pixel of window height. The game's default snapping keeps them crisp,
-- so noSnap does nothing any more (kept as a hook, see DESIGN.md).
local function noSnap(x)
  return x
end
UI.NoSnap = noSnap

-- Small yellow "!" for features that are new since the last live release, with a
-- "New" tooltip. Returns the frame (anchor it yourself).
function UI.NewMark(parent, tip)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(12, 16); f:EnableMouse(true)
  local t = f:CreateTexture(nil, "OVERLAY"); t:SetAllPoints(); t:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("New", 1, 0.82, 0)
    GameTooltip:AddLine(tip or "New in this version.", 1, 1, 1, true); GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return f
end
function FLT.SetTex(tex, path, ...)
  if type(path) == "string" then
    local swap = MODERN_SWAP[path:match("[Aa]ssets\\(.+)$") or ""]
    if swap then path = ASSET_ROOT .. swap end
  end
  tex:SetTexture(path, ...)
  noSnap(tex)
end
-- header test (user 30.10.): Blizzard checkboxes (UICheckButtonTemplate) become the switches of the Classic Refined
-- test; the API stays (Click / GetChecked / SetChecked / SetEnabled), the button is as wide as the switch + 8
local SW_W, SW_H = 34, 18
-- ht4 (user 30.10.: "gold/gelb, aber nicht so kraeftig"): a muted gold track when on, a slightly softer knob
local SW_TRACK_OFF, SW_TRACK_ON = { 0.23, 0.23, 0.25 }, { 0.62, 0.49, 0.27 }
local SW_KNOB_OFF, SW_KNOB_ON = { 0.55, 0.56, 0.58 }, { 0.90, 0.87, 0.80 }
local function toggleSkin(cb)
  if cb._ofaToggle then return cb end
  cb._ofaToggle = true
  for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture", "GetDisabledTexture" }) do
    local t = cb[get] and cb[get](cb)
    if t then t:SetTexture(nil); t:SetAlpha(0) end
  end
  local setSize = cb.SetSize
  function cb:SetSize(_, h) setSize(self, SW_W + 8, math.max(h or SW_H, SW_H)) end
  cb:SetSize(SW_W, cb:GetHeight() or SW_H)
  local pill = CreateFrame("Frame", nil, cb); pill:SetSize(SW_W, SW_H); pill:SetPoint("CENTER", 0, 0)
  local track = UI.RoundRect(cb, pill, "ARTWORK", 0, SW_H / 2, 0, 1, 1, 1, 1, ASSET_ROOT .. "pill_fill")
  local hov = UI.RoundRect(cb, pill, "HIGHLIGHT", 0, SW_H / 2, 0, 0.07, 0.07, 0.07, 1, ASSET_ROOT .. "pill_fill")
  for _, t in ipairs(hov.pieces) do if t.SetBlendMode then t:SetBlendMode("ADD") end end
  local knob = cb:CreateTexture(nil, "OVERLAY"); knob:SetSize(14, 14); FLT.SetTex(knob, ASSET_ROOT .. "knob")
  local function paint()
    local on, en = cb:GetChecked() and true or false, cb:IsEnabled() and true or false
    track:SetColor(unpack(on and SW_TRACK_ON or SW_TRACK_OFF)); knob:SetVertexColor(unpack(on and SW_KNOB_ON or SW_KNOB_OFF))
    knob:ClearAllPoints(); knob:SetPoint(on and "RIGHT" or "LEFT", pill, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
    cb:SetAlpha(en and 1 or 0.4); hov:SetShown(en)
  end
  local setChecked, setEnabled = cb.SetChecked, cb.SetEnabled
  function cb:SetChecked(v) setChecked(self, v); paint() end
  function cb:SetEnabled(v) setEnabled(self, v); paint() end
  if cb.Enable then function cb:Enable() setEnabled(self, true); paint() end end
  if cb.Disable then function cb:Disable() setEnabled(self, false); paint() end end
  cb.Paint = paint
  cb:SetScript("PostClick", paint) -- callers set OnClick themselves (that drops hooks)
  cb:HookScript("OnShow", paint)
  local fs = cb.Text or cb.text
  if type(fs) == "table" and fs.ClearAllPoints then fs:ClearAllPoints(); fs:SetPoint("LEFT", cb, "RIGHT", 4, 0) end
  paint()
  return cb
end
-- ht12 (user 30.10.): the scroll bars of UIPanelScrollFrameTemplate thin and plain - no arrows, a 4 px grey track,
-- a grey thumb (still dragged and scrolled as before)
local function slimBar(bar)
  if type(bar) ~= "table" or bar._ofaSlim or not bar.GetRegions then return end
  bar._ofaSlim = true
  local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
  for _, r in ipairs({ bar:GetRegions() }) do
    if r ~= thumb and r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
  end
  for _, k in ipairs({ "ScrollUpButton", "ScrollDownButton", "Back", "Forward" }) do
    local btn = bar[k]
    if type(btn) == "table" and btn.SetAlpha then btn:SetAlpha(0); if btn.EnableMouse then btn:EnableMouse(false) end end
  end
  local track = bar:CreateTexture(nil, "BACKGROUND"); track:SetColorTexture(0.071, 0.082, 0.098, 1) -- ht13: Classic Refined colours
  track:SetPoint("TOP", 0, 0); track:SetPoint("BOTTOM", 0, 0); track:SetWidth(4)
  if thumb and thumb.SetColorTexture then thumb:SetColorTexture(0.431, 0.329, 0.204, 1); thumb:SetWidth(4) end
end
UI.SlimScrollBar = slimBar
function FLT.SkinBlizz(f)
  if f and f.GetObjectType and f:GetObjectType() == "CheckButton" and f.GetCheckedTexture and f:GetCheckedTexture() then
    toggleSkin(f)
  elseif f and f.GetObjectType and f:GetObjectType() == "ScrollFrame" and type(f.ScrollBar) == "table" then
    slimBar(f.ScrollBar)
  end
  return f
end
function FLT.SkinArtTex() end
-- inline colour code ("|cffRRGGBB")
function FLT.SkinHex(hex) return "|cff" .. hex end
-- grey look for disabled icons
function FLT.Desat(tex, on)
  if tex and tex.SetDesaturated then tex:SetDesaturated(on and true or false) end
end
function FLT.NewFS(owner, ...) return owner:CreateFontString(...) end

local LAYOUT = {
  BOOK_CONTENT_WIDTH = 958,
  DUNGEON_BROWSE_WIDTH = 950,
  DUNGEON_ROW_WIDTH = 930,
  QUEST_LIST_WIDTH = 350,
  QUEST_ROW_WIDTH = 338,
  QUEST_DETAIL_CHILD_WIDTH = 450,
}
UI.LAYOUT = LAYOUT

-- Window background opacity --------------------------------------------------
-- Backgrounds register here (UI.MarkBG). Settings > Window turns down only the
-- backgrounds inside the main window, so text, icons and pictures stay readable.
-- "base" = the window's own background (takes the value as it is), "inner" =
-- boxes, bands and rows on top of it: they fade faster, otherwise the stacked
-- layers would look much more solid than the bare window (uneven look in beta2).
-- Only textures are registered (weak keys: they live as long as their frame).
-- RoundRect pieces fade through their vertex colour (BG_VC), others through SetAlpha.
-- (beta4 registered the RoundRect tables themselves; nobody kept those tables, so the
-- garbage collector removed them and their pieces stayed see-through at 100 %.)
local BG = setmetatable({}, { __mode = "k" })     -- texture -> "base" | "inner"
local BG_A = setmetatable({}, { __mode = "k" })   -- texture -> its own alpha when registered
local BG_VC = setmetatable({}, { __mode = "k" })  -- RoundRect piece -> { r, g, b, a } (skinned)
local BG_IN = setmetatable({}, { __mode = "k" })  -- object -> inside the main window?
local bgAlpha = 1
local function innerMul(a)
  if a >= 0.999 then return 1 end
  local x = math.max(0, math.min(1, (a - 0.3) / 0.7))
  return x * x
end
local function insideWindow(obj)
  local known = BG_IN[obj]
  if known ~= nil then return known end
  local win = UI.mainWindow
  if not win then return false end
  local p = obj._owner or (obj.GetParent and obj:GetParent())
  for _ = 1, 40 do
    if not p then break end
    if p._ofaNoBG then break end -- popups inside the window keep their background
    if p == win then BG_IN[obj] = true; return true end
    p = p.GetParent and p:GetParent()
  end
  BG_IN[obj] = false
  return false
end
local function mulFor(t)
  local role = BG[t]
  if not role or bgAlpha >= 0.999 or not insideWindow(t) then return 1 end
  return (role == "base") and bgAlpha or innerMul(bgAlpha)
end
local function applyBG(t)
  local m = mulFor(t)
  local vc = BG_VC[t]
  if vc then t:SetVertexColor(vc[1], vc[2], vc[3], vc[4] * m)
  elseif t.SetAlpha then t:SetAlpha((BG_A[t] or 1) * m) end
end
local function markTex(t, role)
  -- own alpha only the first time (a second call while faded would store the faded value)
  if BG[t] == nil and not BG_VC[t] and t.GetAlpha then BG_A[t] = t:GetAlpha() or 1 end
  BG[t] = role or "inner"
  if bgAlpha < 0.999 then applyBG(t) end
end
-- obj: a texture, or a RoundRect / Card part (table with .pieces)
function UI.MarkBG(obj, role)
  if not obj then return obj end
  if type(obj.pieces) == "table" then
    for _, t in ipairs(obj.pieces) do markTex(t, role) end
  else
    markTex(obj, role)
  end
  return obj
end
-- shades over pictures (banner fades) must keep their alpha
function UI.UnmarkBG(obj)
  if not obj then return obj end
  for _, t in ipairs(type(obj.pieces) == "table" and obj.pieces or { obj }) do
    if BG[t] then
      BG[t] = nil
      if BG_VC[t] then applyBG(t) elseif t.SetAlpha then t:SetAlpha(BG_A[t] or 1) end
      BG_A[t] = nil
    end
  end
  return obj
end
function UI.SetBackgroundAlpha(a)
  a = math.max(0.05, math.min(1, tonumber(a) or 1))
  if a > 0.985 then a = 1 end
  if math.abs(a - bgAlpha) < 0.001 then return end
  bgAlpha = a
  for t in pairs(BG) do applyBG(t) end
end

local function makeTexture(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetColorTexture(FLT.SkinC(r, g, b, a))
  if layer == nil or layer == "BACKGROUND" or layer == "BORDER" then UI.MarkBG(t) end
  return noSnap(t)
end

local function makeButton(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)

  local bg = makeTexture(b, "BACKGROUND", 0.075, 0.065, 0.050, 0.98)
  bg:SetAllPoints()
  b._bg = bg

  local inner = makeTexture(b, "BORDER", 0.30, 0.22, 0.10, 0.28)
  inner:SetPoint("TOPLEFT", 2, -2)
  inner:SetPoint("BOTTOMRIGHT", -2, 2)
  b._inner = inner

  local function edge(point1, point2, x1, y1, x2, y2, width, height)
    local t = makeTexture(b, "ARTWORK", 0.72, 0.50, 0.16, 0.72)
    t:SetPoint(point1, b, point1, x1, y1)
    t:SetPoint(point2, b, point2, x2, y2)
    if width then t:SetWidth(width) end
    if height then t:SetHeight(height) end
    return t
  end
  edge("TOPLEFT", "TOPRIGHT", 0, 0, 0, 0, nil, 1)
  edge("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, 0, 0, nil, 1)
  edge("TOPLEFT", "BOTTOMLEFT", 0, 0, 0, 0, 1, nil)
  edge("TOPRIGHT", "BOTTOMRIGHT", 0, 0, 0, 0, 1, nil)

  local highlight = makeTexture(b, "HIGHLIGHT", 0.78, 0.55, 0.18, 0.18)
  highlight:SetPoint("TOPLEFT", 1, -1)
  highlight:SetPoint("BOTTOMRIGHT", -1, 1)
  b:SetHighlightTexture(highlight)

  local label = FLT.NewFS(b, nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER", 0, 0)
  label:SetText(text)
  label:SetTextColor(FLT.SkinC(0.96, 0.78, 0.34))
  b:SetFontString(label)
  b._label = label

  b:SetScript("OnMouseDown", function(self)
    if self:IsEnabled() then
      self._bg:SetColorTexture(FLT.SkinC(0.11, 0.085, 0.050, 1.00))
      self._label:ClearAllPoints()
      if self._labelLeft then self._label:SetPoint("LEFT", self._labelLeft + 1, -1) else self._label:SetPoint("CENTER", 1, -1) end
    end
  end)
  b:SetScript("OnMouseUp", function(self)
    self._bg:SetColorTexture(FLT.SkinC(0.075, 0.065, 0.050, 0.98))
    self._label:ClearAllPoints()
    if self._labelLeft then self._label:SetPoint("LEFT", self._labelLeft, 0) else self._label:SetPoint("CENTER", 0, 0) end
  end)

  return b
end

local function addDivider(parent, x)
  local line = makeTexture(parent, "ARTWORK", 0.55, 0.42, 0.18, 0.35)
  line:SetPoint("TOPLEFT", x, -2)
  line:SetPoint("BOTTOMLEFT", x, 2)
  line:SetWidth(1)
end




-- Art-based building blocks ---------------------------------------------------
-- RoundRect: a rounded rectangle from a 9-sliced white texture (corner radius =
-- c px), tinted with SetVertexColor. Card: border + fill (1 px border).
-- OrnateFrame: the thin rounded line around panels (Assets\modern_frame).
local unpack = unpack or table.unpack
local RR_TEX = ASSET_ROOT .. "rr_fill"
local WINDOW_TEX = ASSET_ROOT .. "window_frame" -- only a marker: the main window gets the larger radius
local MODERN_TEX = ASSET_ROOT .. "modern_frame"

local function sliceTex(owner, layer, sub, tex, l, r, t, b)
  local x = owner:CreateTexture(nil, layer, nil, sub)
  FLT.SetTex(x, tex); x:SetTexCoord(l, r, t, b)
  return noSnap(x)
end

local RING_TEX = ASSET_ROOT .. "rr_ring_w"
-- tex (optional): RING_TEX draws only the outline (no middle piece)
local function RoundRect(owner, anchor, layer, sub, c, inset, cr, cg, cb, ca, tex)
  anchor = anchor or owner; inset = inset or 0
  local RR_TEX = tex or RR_TEX
  local p = {}
  local A, B = 0.25, 0.75
  local tl = sliceTex(owner, layer, sub, RR_TEX, 0, A, 0, A); tl:SetSize(c, c); tl:SetPoint("TOPLEFT", anchor, "TOPLEFT", inset, -inset)
  local tr = sliceTex(owner, layer, sub, RR_TEX, B, 1, 0, A); tr:SetSize(c, c); tr:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -inset, -inset)
  local bl = sliceTex(owner, layer, sub, RR_TEX, 0, A, B, 1); bl:SetSize(c, c); bl:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", inset, inset)
  local br = sliceTex(owner, layer, sub, RR_TEX, B, 1, B, 1); br:SetSize(c, c); br:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -inset, inset)
  local top = sliceTex(owner, layer, sub, RR_TEX, A, B, 0, A); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
  local bot = sliceTex(owner, layer, sub, RR_TEX, A, B, B, 1); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
  local lef = sliceTex(owner, layer, sub, RR_TEX, 0, A, A, B); lef:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); lef:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
  local rig = sliceTex(owner, layer, sub, RR_TEX, B, 1, A, B); rig:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rig:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
  p.pieces = { tl, tr, bl, br, top, bot, lef, rig }
  if tex ~= RING_TEX then
    local mid = sliceTex(owner, layer, sub, RR_TEX, A, B, A, B); mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    p.pieces[9] = mid
  end
  function p:SetColor(r, g, b, a)
    local sr, sg, sb, sa = FLT.SkinC(r, g, b, a or 1)
    for _, t in ipairs(self.pieces) do
      BG_VC[t] = { sr, sg, sb, sa or 1 }
      t:SetVertexColor(sr, sg, sb, (sa or 1) * mulFor(t)) -- window opacity (UI.MarkBG)
    end
  end
  function p:SetShown(v) for _, t in ipairs(self.pieces) do t:SetShown(v) end end
  p:SetColor(cr or 1, cg or 1, cb or 1, ca or 1)
  return p
end

local function Card(owner, anchor, c, border, fill, layer, sub)
  layer = layer or "BACKGROUND"; sub = sub or 0
  local card = {}
  -- modern: the border is only a ring, so a see-through fill does not show a
  -- filled border plate behind it (grey cards in 5.6.1-beta3)
  local r_, g_, b_, a_ = unpack(border)
  card.border = RoundRect(owner, anchor, layer, sub, c, 0, r_, g_, b_, a_, RING_TEX)
  card.fill = RoundRect(owner, anchor, layer, sub + 1, math.max(1, c - 1), 1, unpack(fill))
  UI.MarkBG(card.fill)
  function card:SetBorder(r, g, b, a) self.border:SetColor(r, g, b, a) end
  function card:SetFill(r, g, b, a) self.fill:SetColor(r, g, b, a) end
  return card
end

-- plain rounded line on the anchor's edge; the window gets a slightly larger radius. Plain 9-slice of one
-- outline (no middle piece); returns the pieces, so callers can tint them.
-- The line lies inside the anchor (scroll frames clip anything outside).
local function OrnateFrame(owner, anchor, c, outset, layer, sub, tex)
  anchor = anchor or owner; layer = layer or "OVERLAY"; sub = sub or 0
  -- ht7 (user 30.10.: popups like the main window): the frame line of popups (corner 16 / 18, outset 3) is the window's
  -- outer frame now; the callers tint what they get back, so they get no pieces
  if tex ~= WINDOW_TEX and (c == 16 or c == 18) and outset == 3 and owner == anchor and UI.WindowFrame then
    local deco = CreateFrame("Frame", nil, owner); deco:SetAllPoints(owner)
    deco:SetFrameLevel((owner:GetFrameLevel() or 0) + 15)
    UI.WindowFrame(deco, owner)
    return {}
  end
  if tex == WINDOW_TEX then c = 14 else c = 8 end
  local A, B = 0.25, 0.75
  local function piece(l, r, t, b) return sliceTex(owner, layer, sub, MODERN_TEX, l, r, t, b) end
  local tl = piece(0, A, 0, A); tl:SetSize(c, c); tl:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
  local tr = piece(B, 1, 0, A); tr:SetSize(c, c); tr:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
  local bl = piece(0, A, B, 1); bl:SetSize(c, c); bl:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
  local br = piece(B, 1, B, 1); br:SetSize(c, c); br:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
  local top = piece(A, B, 0, A); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
  local bot = piece(A, B, B, 1); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
  local lef = piece(0, A, A, B); lef:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); lef:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
  local rig = piece(B, 1, A, B); rig:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rig:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
  return { tl, tr, bl, br, top, bot, lef, rig }
end

-- Nine: 9-sliced texture (64x64 file, 16 px corners) drawn around anchor,
-- grown by "out" px on every side (room for a glow baked into the texture).
local function Nine(owner, anchor, tex, c, out, layer, sub)
  local A, B = 0.25, 0.75
  local function piece(l, r, t, b) return sliceTex(owner, layer, sub, tex, l, r, t, b) end
  local tl = piece(0, A, 0, A); tl:SetSize(c, c); tl:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
  local tr = piece(B, 1, 0, A); tr:SetSize(c, c); tr:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
  local bl = piece(0, A, B, 1); bl:SetSize(c, c); bl:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
  local br = piece(B, 1, B, 1); br:SetSize(c, c); br:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
  local top = piece(A, B, 0, A); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
  local bot = piece(A, B, B, 1); bot:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
  local lef = piece(0, A, A, B); lef:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); lef:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
  local rig = piece(B, 1, A, B); rig:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); rig:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
  local mid = piece(A, B, A, B); mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
  local o = { pieces = { tl, tr, bl, br, top, bot, lef, rig, mid } }
  function o:SetShown(v) for _, t in ipairs(self.pieces) do t:SetShown(v) end end
  function o:SetAlpha(a) for _, t in ipairs(self.pieces) do t:SetAlpha(a) end end
  function o:SetDesaturated(v) for _, t in ipairs(self.pieces) do FLT.Desat(t, v) end end
  return o
end

-- Plate: the button/tab skin - a flat plate with a thin rim and rounded corners, a soft gold glow when active.
local BTN_GLOW_TEX = ASSET_ROOT .. "btn_glow"
local BTN_M_NORMAL_TEX, BTN_M_ACTIVE_TEX = ASSET_ROOT .. "btn_m_normal", ASSET_ROOT .. "btn_m_active"
local function Plate(b, h)
  local glowC = math.min(11, math.floor(h * 0.42))
  local c = math.min(9, math.floor(h * 0.40))
  local normalTex, activeTex = BTN_M_NORMAL_TEX, BTN_M_ACTIVE_TEX
  local glow = Nine(b, b, BTN_GLOW_TEX, glowC, math.floor(10 * glowC / 16 + 0.5), "BACKGROUND", -1); glow:SetShown(false)
  local normal = Nine(b, b, normalTex, c, 0, "BACKGROUND", 0)
  local active = Nine(b, b, activeTex, c, 0, "BACKGROUND", 1); active:SetShown(false)
  local hover = Nine(b, b, activeTex, c, 0, "HIGHLIGHT", 0); hover:SetAlpha(0.28)
  local p = {}
  function p:SetActive(on)
    on = on and true or false
    active:SetShown(on); glow:SetShown(on); normal:SetShown(not on)
  end
  function p:SetEnabledLook(on)
    normal:SetDesaturated(not on); normal:SetAlpha(on and 1 or 0.6); hover:SetShown(on and true or false)
  end
  return p
end

-- GoldButton: plate button with optional icon. b:SetActive(on) for toggles.
-- ht11 (user 30.10.): "Map" buttons are only the map symbol (like the trainer list in Professions); same API
local function MapIcon(parent, h)
  local b = CreateFrame("Button", nil, parent); local sz = math.max(18, math.min(22, (h or 20)))
  b:SetSize(sz, sz)
  local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); FLT.SetTex(t, ASSET_ROOT .. "icon_map")
  b:SetHighlightTexture(ASSET_ROOT .. "icon_map", "ADD")
  b.icon = t
  b._label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b._label:Hide()
  function b:SetLook(on) t:SetAlpha(on and 1 or 0.3); FLT.Desat(t, not on) end
  function b:SetActive() end
  function b:SetLabel() end
  b._place = function() end
  return b
end
-- plain = true: a real "Map" button with text (the dungeon / raid detail head, user 31.10.)
local function GoldButton(parent, text, w, h, icon, fontSize, plain)
  if text == "Map" and not plain and type(icon) == "string" and icon:find("icon_map$") then return MapIcon(parent, h) end
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  local plate = Plate(b, h)
  local label = FLT.NewFS(b, nil, "OVERLAY", "GameFontNormal")
  do local font, _, flags = label:GetFont(); if font then label:SetFont(font, fontSize or 12, flags) end end
  label:SetText(text); label:SetTextColor(FLT.SkinC(0.95, 0.82, 0.50))
  local function place(dx, dy)
    label:ClearAllPoints()
    if b.icon and b.icon:IsShown() then
      -- b.iconGap: room between icon and text; b.iconRight: the icon after the text (b:SetArrows, Welcome setup)
      local gap = b.iconGap or 5
      local tw = (label:GetStringWidth() or 0) + (b.icon:GetWidth() or 14) + gap
      b.icon:ClearAllPoints()
      if b.iconRight then
        label:SetPoint("LEFT", b, "CENTER", -tw / 2 + dx, dy); b.icon:SetPoint("LEFT", label, "RIGHT", gap, 0)
      else
        b.icon:SetPoint("LEFT", b, "CENTER", -tw / 2 + dx, dy); label:SetPoint("LEFT", b.icon, "RIGHT", gap, 0)
      end
    else
      label:SetPoint("CENTER", dx, dy)
    end
  end
  if icon then
    local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(h - 8, h - 8); FLT.SetTex(ic, icon)
    b.icon = ic
  end
  place(0, 0)
  b._label, b.plate = label, plate
  function b:SetActive(on)
    plate:SetActive(on)
    if on then label:SetTextColor(FLT.SkinC(1, 0.93, 0.66)) else label:SetTextColor(FLT.SkinC(0.95, 0.82, 0.50)) end
  end
  function b:SetLook(enabled)
    plate:SetEnabledLook(enabled)
    if enabled then label:SetTextColor(FLT.SkinC(0.95, 0.82, 0.50)) else label:SetTextColor(FLT.SkinC(0.5, 0.5, 0.5)) end
    if b.icon then FLT.Desat(b.icon, not enabled); b.icon:SetAlpha(enabled and 1 or 0.5) end
  end
  function b:SetLabel(t) label:SetText(t); place(0, 0) end
  -- the gold chevron of the "< Dungeons" button as a page arrow (Welcome setup, user 31.10.): dir "prev" / "next" / nil
  function b:SetArrow(dir)
    if not b.icon then b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(h - 10, h - 10); FLT.SetTex(b.icon, ASSET_ROOT .. "icon_back") end
    b.icon:SetShown(dir ~= nil); b.iconRight, b.iconGap = dir == "next", 8
    if dir == "next" then b.icon:SetTexCoord(1, 0, 0, 1) else b.icon:SetTexCoord(0, 1, 0, 1) end
    place(0, 0)
  end
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then place(1, -1) end end)
  b:SetScript("OnMouseUp", function() place(0, 0) end)
  return b
end

-- A secure button inside an addon window makes the whole window protected: in combat it then cannot be closed
-- (ADDON_ACTION_BLOCKED on OneForAllFrame:Hide(), user 30.10.). Right before combat starts (PLAYER_REGEN_DISABLED still
-- runs outside the lockdown) such buttons leave their window (parent UIParent, hidden); after combat they go back to
-- their place. onBack (optional) runs after that, e.g. to update what the button shows.
local detached, detachFrame = {}, nil
function UI.CombatDetach(btn, onBack)
  detached[#detached + 1] = { b = btn, onBack = onBack }
  if detachFrame then return end
  detachFrame = CreateFrame("Frame")
  detachFrame:RegisterEvent("PLAYER_REGEN_DISABLED"); detachFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  detachFrame:SetScript("OnEvent", function(_, event)
    for _, d in ipairs(detached) do
      local b = d.b
      if event == "PLAYER_REGEN_DISABLED" and not d.home then
        if not (InCombatLockdown and InCombatLockdown()) then
          d.home, d.shown, d.points = b:GetParent(), b:IsShown(), {}
          for i = 1, (tonumber(b:GetNumPoints()) or 0) do d.points[i] = { b:GetPoint(i) } end
          b:Hide(); b:ClearAllPoints(); b:SetParent(UIParent)
        end
      elseif event == "PLAYER_REGEN_ENABLED" and d.home then
        b:SetParent(d.home); b:ClearAllPoints()
        for _, pt in ipairs(d.points) do b:SetPoint(unpack(pt)) end
        b:SetShown(d.shown); d.home, d.points = nil, nil
        if d.onBack then d.onBack() end
      end
    end
  end)
end

UI.Nine = Nine
UI.Plate = Plate

-- Shared page layout --------------------------------------------------------
-- Panels sit PANEL_INSET px inside the window on both sides; page content is
-- CONTENT_W wide starting at x=8, so the margin to the gold frame is the same
-- left and right. List scroll bars go into the right margin (PlaceScrollBar).
UI.PANEL_INSET = 18
UI.CONTENT_W = 988
UI.GOLD = {1, 0.82, 0.20}
UI.HEAD_GOLD = {0.90, 0.74, 0.42}

-- header test (user 30.10.): pages start under the banner and the tabs; a page with a title band starts
-- TITLE_BAND_H higher, because the band is gone (UI.TitleBand)
UI.CONTENT_TOP, UI.TITLE_BAND_H = 124, 66
function UI.PlacePanel(panel, parent, up)
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", UI.PANEL_INSET, -UI.CONTENT_TOP + (up or 0))
  panel:SetPoint("BOTTOMRIGHT", -UI.PANEL_INSET, 15)
end

-- Moves a UIPanelScrollFrameTemplate bar into the right page margin and
-- hides it while there is nothing to scroll.
function UI.PlaceScrollBar(sf)
  local bar = sf.ScrollBar
  if type(bar) ~= "table" or not bar.ClearAllPoints then return end
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 1, -16)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 1, 16)
  local function upd() bar:SetShown((sf:GetVerticalScrollRange() or 0) > 0.5) end
  sf:HookScript("OnScrollRangeChanged", upd)
  sf:HookScript("OnShow", upd)
  upd()
end

-- Hides a UIPanelScrollFrameTemplate bar while there is nothing to scroll
-- (also after the window was resized); the bar keeps its place.
function UI.AutoHideScrollBar(sf)
  local bar = sf and sf.ScrollBar
  if type(bar) ~= "table" or not bar.SetShown then return end
  local function upd() bar:SetShown((sf:GetVerticalScrollRange() or 0) > 0.5) end
  sf:HookScript("OnScrollRangeChanged", upd)
  sf:HookScript("OnSizeChanged", upd)
  sf:HookScript("OnShow", upd)
  upd()
end

-- "Small caps": first letter of every word larger, the rest in capitals.
function UI.SmallCaps(parent, text, big, small, color, template)
  local holder = CreateFrame("Frame", nil, parent)
  local prev, total, gap = nil, 0, math.floor(small * 0.35 + 0.5)
  local function add(str, size, spacing)
    local fs = FLT.NewFS(holder, nil, "OVERLAY", template or "GameFontNormal")
    local font, _, flags = fs:GetFont(); if font then fs:SetFont(font, size, flags) end
    fs:SetText(str); fs:SetTextColor(FLT.SkinC(unpack(color)))
    -- common baseline: a font string's box includes room for descenders that
    -- grows with the font size, so bigger letters are moved down accordingly
    total = total + spacing
    fs:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", total, -math.floor(size * 0.22 + 0.5) + math.floor(small * 0.22 + 0.5))
    total = total + (fs:GetStringWidth() or 0); prev = fs
  end
  local first = true
  for word in tostring(text):gmatch("%S+") do
    add(word:sub(1, 1):upper(), big, first and 0 or gap)
    if #word > 1 then add(word:sub(2):upper(), small, 0) end
    first = false
  end
  holder:SetSize(math.max(1, total), big + 2)
  return holder
end

-- Title band at the top of a page: emblem, small-caps title, subtitle and
-- the tab's banner art, faded out behind the title (left) and the right end.
-- opts = { emblem=, title=, subtitle=, art=, width= }
function UI.TitleBand(parent, opts)
  local w = opts.width or UI.CONTENT_W
  -- header test (user 30.10.): no title band, no tab name, no emblem under the tabs any more: the page moves up by the
  -- band's height (its content keeps its offsets); the band stays as an empty, hidden frame for callers
  do
    local band = CreateFrame("Frame", nil, parent); band:SetPoint("TOPLEFT", 8, -8); band:SetSize(w, 58); band:Hide()
    UI.PlacePanel(parent, nil, UI.TITLE_BAND_H)
    band.title = band:CreateFontString(nil, "OVERLAY", "GameFontNormal"); band.subtitle = band:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    return band
  end
  local band = CreateFrame("Frame", nil, parent); band:SetPoint("TOPLEFT", 8, -8); band:SetSize(w, 58)
  local bg = makeTexture(band, "BACKGROUND", 0.045, 0.045, 0.058, 0.96); bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
  if opts.art then
    local art = band:CreateTexture(nil, "BORDER", nil, 0); art:SetPoint("TOPLEFT", 2, -2); art:SetPoint("BOTTOMRIGHT", -2, 2)
    FLT.SetTex(art, opts.art)
    if opts.mirror then art:SetTexCoord(1, 0, 0.18, 0.82) else art:SetTexCoord(0, 1, 0.18, 0.82) end
    local shadeL = UI.UnmarkBG(makeTexture(band, "BORDER", 0.045, 0.045, 0.058, 0.94)); shadeL:SetDrawLayer("BORDER", 1)
    shadeL:SetPoint("TOPLEFT", 2, -2); shadeL:SetPoint("BOTTOMLEFT", 2, 2); shadeL:SetWidth(opts.solid or 360)
    local fadeL = band:CreateTexture(nil, "BORDER", nil, 1); FLT.SetTex(fadeL, ASSET_ROOT .. "shade_lr"); fadeL:SetVertexColor(FLT.SkinC(0.18, 0.18, 0.23))
    fadeL:SetPoint("TOPLEFT", shadeL, "TOPRIGHT"); fadeL:SetPoint("BOTTOMLEFT", shadeL, "BOTTOMRIGHT"); fadeL:SetWidth(340)
    local fadeR = band:CreateTexture(nil, "BORDER", nil, 1); FLT.SetTex(fadeR, ASSET_ROOT .. "shade_lr"); fadeR:SetTexCoord(1, 0, 0, 1); fadeR:SetVertexColor(FLT.SkinC(0.18, 0.18, 0.23))
    fadeR:SetPoint("TOPRIGHT", -2, -2); fadeR:SetPoint("BOTTOMRIGHT", -2, 2); fadeR:SetWidth(opts.fadeRight or 300)
  end
  OrnateFrame(band, band, 15, 2, "OVERLAY", 1)
  if opts.emblem then
    local e = band:CreateTexture(nil, "ARTWORK"); e:SetSize(46, 46); e:SetPoint("LEFT", 10, 0); FLT.SetTex(e, opts.emblem)
  end
  local title = UI.SmallCaps(band, opts.title or "", 19, 15, UI.GOLD, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 66, -9)
  local sub = FLT.NewFS(band, nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", 67, -34); sub:SetText(opts.subtitle or ""); sub:SetTextColor(FLT.SkinC(0.80, 0.77, 0.70))
  band.subtitle, band.title = sub, title
  return band
end

-- Column header strip: small caps, separators. cols = { {x=,w=,text=,justify=} }
function UI.ColumnHeader(parent, cols, width, y)
  local h = CreateFrame("Frame", nil, parent); h:SetPoint("TOPLEFT", 8, y); h:SetSize(width or UI.CONTENT_W, 24)
  -- ht8: no gold bar - the column names on the page with a fine line under them
  local ln = h:CreateTexture(nil, "ARTWORK"); ln:SetColorTexture(0.50, 0.38, 0.19, 0.6); ln:SetHeight(1)
  ln:SetPoint("BOTTOMLEFT", 2, 0); ln:SetPoint("BOTTOMRIGHT", -2, 0)
  for i, c in ipairs(cols) do
    local holder = CreateFrame("Frame", nil, h); holder:SetPoint("LEFT", c.x, 0); holder:SetSize(c.w or 100, 22)
    local label = UI.SmallCaps(holder, c.text, 12, 9, UI.HEAD_GOLD)
    if c.justify == "CENTER" then label:SetPoint("LEFT", holder, "CENTER", -math.floor(label:GetWidth() / 2), 0)
    else label:SetPoint("LEFT", 10, 0) end
    if i > 1 then
      local sep = makeTexture(h, "ARTWORK", 0.72, 0.50, 0.12, 0.25); sep:SetPoint("LEFT", c.x - 2, 0); sep:SetSize(1, 12)
    end
  end
  return h
end

-- The client's dressing-room picture of the player's race (Interface\DressUpFrame, 4 pieces = 318 x 383) filling the
-- rectangle (x1, y1) - (x2, y2) of parent: scaled to its height, cropped at the sides, dimmed (6.0.1, user 30.10.:
-- behind the character in the Gear Planner). Gnome / Troll use Dwarf / Orc when the client has no own picture.
-- Returns the frame that holds it (one level above parent; raise what must stay on top).
local DRESS_PIECES = { -- point x, y, w, h, u2, v2
  { 0, 0, 256, 255, 1, 255 / 256 }, { 256, 0, 62, 255, 62 / 64, 255 / 256 },
  { 0, -255, 256, 128, 1, 1 }, { 256, -255, 62, 128, 62 / 64, 1 },
}
local DRESS_ALT = { Gnome = "Dwarf", Troll = "Orc", Goblin = "Orc", Worgen = "Human" }
function UI.RaceBackdrop(parent, x1, y1, x2, y2)
  local clip = CreateFrame("Frame", nil, parent)
  clip:SetPoint("TOPLEFT", x1, y1); clip:SetPoint("BOTTOMRIGHT", x2, y2)
  clip:SetFrameLevel(parent:GetFrameLevel() + 1)
  if clip.SetClipsChildren then clip:SetClipsChildren(true) end
  local H = math.max(1, (parent:GetHeight() or 0) + y1 - y2)
  local sc = H / 383
  local pic = CreateFrame("Frame", nil, clip); pic:SetSize(318 * sc, H); pic:SetPoint("CENTER")
  local tex = {}
  local function load(name)
    local ok = true
    for i, p in ipairs(DRESS_PIECES) do
      local t = tex[i] or pic:CreateTexture(nil, "BACKGROUND"); tex[i] = t
      if t:SetTexture("Interface\\DressUpFrame\\DressUpBackground-" .. name .. i) == false then ok = false end
      t:SetSize(p[3] * sc, p[4] * sc); t:SetPoint("TOPLEFT", p[1] * sc, p[2] * sc); t:SetTexCoord(0, p[5], 0, p[6])
    end
    return ok
  end
  local race = UnitRace and select(2, UnitRace("player")) or "Human"
  if not load(race or "Human") and DRESS_ALT[race] then load(DRESS_ALT[race]) end
  -- dimmed by a shade on a frame above the picture (a child frame draws over its parent)
  local ov = CreateFrame("Frame", nil, clip); ov:SetAllPoints(); ov:SetFrameLevel(pic:GetFrameLevel() + 1)
  local shade = ov:CreateTexture(nil, "BACKGROUND"); shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.42)
  -- the picture's lower end fades into the panel's dark (no hard edge where it stops; beta3, user 30.10.)
  local fade = ov:CreateTexture(nil, "ARTWORK"); fade:SetPoint("BOTTOMLEFT"); fade:SetPoint("BOTTOMRIGHT"); fade:SetHeight(H * 0.38)
  fade:SetColorTexture(1, 1, 1, 1)
  local r, g, b = 0.045, 0.045, 0.055 -- the panel background (FramedPanel)
  if not (fade.SetGradient and CreateColor and pcall(fade.SetGradient, fade, "VERTICAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))) then
    if fade.SetGradientAlpha then fade:SetGradientAlpha("VERTICAL", r, g, b, 1, r, g, b, 0) else fade:Hide() end
  end
  return clip
end

-- Collapsible section band (landscape silhouette, chevron box, title, info)
-- plus the framed box below it that holds the rows.
-- Returns section = { header=, box=, chevron=, info=, title=, SetCollapsed(on) }
function UI.SectionBand(parent, label, strip, width, onToggle)
  width = width or UI.CONTENT_W
  local holder = CreateFrame("Button", nil, parent); holder:SetSize(width, 34)
  do -- ht8: a quiet head, no landscape; the rows below without a box
    local chevron, title, info = UI.QuietHead(holder, label)
    local box = CreateFrame("Frame", nil, parent); box:SetWidth(width)
    local section = { header = holder, box = box, chevron = chevron, info = info, title = title }
    function section:SetCollapsed(on)
      if on then chevron:SetTexCoord(0.5, 1, 0, 1) else chevron:SetTexCoord(0, 0.5, 0, 1) end
    end
    holder:SetScript("OnClick", function() if onToggle then onToggle() end end)
    section:SetCollapsed(false)
    return section
  end
  local base = makeTexture(holder, "BACKGROUND", 0.05, 0.05, 0.065, 0.98); base:SetPoint("TOPLEFT", 2, -2); base:SetPoint("BOTTOMRIGHT", -2, 2)
  local sil = holder:CreateTexture(nil, "BORDER"); sil:SetPoint("TOPLEFT", 2, -2); sil:SetPoint("BOTTOMRIGHT", -2, 2)
  strip = (strip or 0) % 3
  FLT.SetTex(sil, ASSET_ROOT .. "band_silhouettes"); sil:SetTexCoord(0, 1, strip * 0.25, strip * 0.25 + 0.25); sil:SetAlpha(0.85)
  local cbox = CreateFrame("Frame", nil, holder); cbox:SetSize(22, 22); cbox:SetPoint("LEFT", 12, 0)
  Card(cbox, cbox, 4, {0.80, 0.60, 0.24, 0.95}, {0.06, 0.05, 0.04, 0.95}, "BACKGROUND", 0)
  local chevron = cbox:CreateTexture(nil, "OVERLAY"); chevron:SetSize(15, 15); chevron:SetPoint("CENTER", 0, 0); FLT.SetTex(chevron, ASSET_ROOT .. "chevron")
  local title = FLT.NewFS(holder, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("LEFT", 46, 0); title:SetText(label); title:SetTextColor(FLT.SkinC(unpack(UI.GOLD)))
  do local font, _, flags = title:GetFont(); if font then title:SetFont(font, 14, flags) end end
  local info = FLT.NewFS(holder, nil, "OVERLAY", "GameFontHighlightSmall"); info:SetPoint("RIGHT", -20, 0); info:SetJustifyH("RIGHT"); info:SetTextColor(FLT.SkinC(0.85, 0.82, 0.74))
  OrnateFrame(holder, holder, 13, 2, "OVERLAY", 1)
  local hhi = makeTexture(holder, "HIGHLIGHT", 0.80, 0.58, 0.18, 0.10); hhi:SetPoint("TOPLEFT", 2, -2); hhi:SetPoint("BOTTOMRIGHT", -2, 2)
  local box = CreateFrame("Frame", nil, parent); box:SetWidth(width)
  local bfill = makeTexture(box, "BACKGROUND", 0.035, 0.038, 0.048, 0.92); bfill:SetPoint("TOPLEFT", 2, -2); bfill:SetPoint("BOTTOMRIGHT", -2, 2)
  OrnateFrame(box, box, 10, 1, "BORDER", 0)
  local section = { header = holder, box = box, chevron = chevron, info = info, title = title }
  function section:SetCollapsed(on)
    if on then chevron:SetTexCoord(0.5, 1, 0, 1) else chevron:SetTexCoord(0, 0.5, 0, 1) end
  end
  holder:SetScript("OnClick", function() if onToggle then onToggle() end end)
  section:SetCollapsed(false)
  return section
end

-- Gold edge that shows while the mouse is over a button (HIGHLIGHT layer,
-- so it needs no OnEnter/OnLeave scripts and cannot get stuck).
function UI.HoverEdge(b)
  local ring = Nine(b, b, ASSET_ROOT .. "rr_ring", 4, 0, "HIGHLIGHT", 1)
  return ring
end

-- Dark panel with a thin rounded line.
function UI.FramedPanel(f, inset)
  -- flat background with the same rounded corners as the line
  UI.MarkBG(RoundRect(f, f, "BACKGROUND", 0, 7, 1, 0.045, 0.045, 0.055, 0.96))
  -- ht3 (user 30.10.: "alle Rahmen deutlich schlanker"): a 1 px line (Assets/window_ring) instead of the 1.5 px gold line
  RoundRect(f, f, "OVERLAY", 3, 8, 0, 0.50, 0.42, 0.30, 0.85, ASSET_ROOT .. "window_ring")
end
-- ht3 (user 30.10.): the side list, middle and right parts of a tab without a frame of their own; lineX: a quiet
-- upright line that far right of the column's right edge (the gap to the next column)
function UI.Column(f, lineX)
  if not lineX then return end
  local vl = f:CreateTexture(nil, "ARTWORK"); vl:SetColorTexture(0.50, 0.38, 0.19, 0.55); vl:SetWidth(1)
  vl:SetPoint("TOPLEFT", f, "TOPRIGHT", lineX, 0); vl:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", lineX, 0)
  return vl
end
-- ht3 (user 30.10.): the tab's emblem and name at the top of its side list; returns the height it takes
function UI.NavHeader(nav, emblem, title)
  local e = nav:CreateTexture(nil, "ARTWORK"); e:SetSize(36, 36); e:SetPoint("TOPLEFT", 4, -4); FLT.SetTex(e, ASSET_ROOT .. emblem)
  local t = FLT.NewFS(nav, nil, "OVERLAY", "GameFontNormalLarge"); t:SetPoint("LEFT", e, "RIGHT", 8, 0); t:SetText(title)
  t:SetTextColor(1, 0.84, 0.42); t:SetJustifyH("LEFT")
  local w = (nav:GetWidth() or 160) - 52
  if (t:GetStringWidth() or 0) > w then -- narrow lists (Talent Trees): a little smaller
    local font, _, flags = t:GetFont(); if font then t:SetFont(font, 13, flags) end
  end
  t:SetWidth(w)
  return 54 -- ht5: no line under it (user 30.10.)
end
-- ht8 (user 30.10.: "die Liste links einheitlich"): one geometry for every side list. The list frame sits 12 from the
-- window's edge, its entries 4 inside it (16 from the edge), 156 wide; the line follows 16 after them; pages from 182.
-- Entries 27 high, every 32; a separator: a quiet line with the same gap above and below.
UI.NAV = { x = -6, w = 164, line = 12, entryX = 4, entryW = 156, entryH = 27, step = 32 }
function UI.SideNav(panel, top, emblem, title)
  local nav = CreateFrame("Frame", nil, panel); nav:SetPoint("TOPLEFT", UI.NAV.x, top); nav:SetSize(UI.NAV.w, 560)
  UI.Column(nav, UI.NAV.line)
  local y = -12
  if emblem then y = y - UI.NavHeader(nav, emblem, title) end
  return nav, y
end
-- an entry at y (top), returns it and the y of the next one
function UI.NavEntry(nav, y, label, icon, h)
  local b = UI.NavButton(nav, label, UI.NAV.entryW, h or UI.NAV.entryH, icon); b:SetPoint("TOPLEFT", UI.NAV.entryX, y)
  return b, y - (h or UI.NAV.entryH) - (UI.NAV.step - UI.NAV.entryH)
end
-- a separator under the entry above y (y = the next entry's top as NavEntry returned it); returns the new y
function UI.NavSeparator(nav, y)
  local sep = nav:CreateTexture(nil, "ARTWORK"); FLT.SetTex(sep, ASSET_ROOT .. "divider_ornate"); sep:SetHeight(12)
  sep:SetPoint("LEFT", nav, "TOPLEFT", 6, y - 3); sep:SetPoint("RIGHT", nav, "TOPLEFT", UI.NAV.entryX + UI.NAV.entryW - 2, y - 3)
  return y - 11
end
-- ht8: a quiet group head (dark plate, thin line, chevron, gold title, the count right) instead of the landscape band
function UI.QuietHead(holder, label)
  UI.MarkBG(RoundRect(holder, holder, "BACKGROUND", 0, 7, 1, 0.075, 0.068, 0.058, 0.96))
  RoundRect(holder, holder, "BORDER", 0, 8, 0, 0.42, 0.33, 0.20, 0.9, ASSET_ROOT .. "window_ring")
  local hov = RoundRect(holder, holder, "HIGHLIGHT", 0, 7, 1, 0.07, 0.06, 0.04, 1); for _, t in ipairs(hov.pieces) do t:SetBlendMode("ADD") end
  local chevron = holder:CreateTexture(nil, "OVERLAY"); chevron:SetSize(14, 14); chevron:SetPoint("LEFT", 14, 0)
  FLT.SetTex(chevron, ASSET_ROOT .. "chevron")
  local title = FLT.NewFS(holder, nil, "OVERLAY", "GameFontNormal"); title:SetPoint("LEFT", 38, 0); title:SetText(label or "")
  do local font, _, flags = title:GetFont(); if font then title:SetFont(font, 14, flags) end end
  title:SetTextColor(FLT.SkinC(unpack(UI.GOLD)))
  local info = FLT.NewFS(holder, nil, "OVERLAY", "GameFontHighlightSmall"); info:SetPoint("RIGHT", -16, 0); info:SetJustifyH("RIGHT")
  info:SetTextColor(0.72, 0.70, 0.66)
  return chevron, title, info
end
-- ht8: a table row without a frame: a fine line under it and a faint hover; returns a stub with :SetBorder
function UI.QuietRow(row)
  local ln = row:CreateTexture(nil, "BORDER"); ln:SetColorTexture(0.40, 0.32, 0.20, 0.35); ln:SetHeight(1)
  ln:SetPoint("BOTTOMLEFT", 4, 0); ln:SetPoint("BOTTOMRIGHT", -4, 0)
  local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.06))
  return { SetBorder = function() end, SetFill = function() end, line = ln }
end

-- ht7: the window's outer frame (header test): a thin dark gold line with small corners (Assets/window_ring: radius 4,
-- line 1) and short, faint gold accents at the four corners (corner arc, two lines fading out along the edges, a soft
-- shine inside: fade_lr, corner_glow, edge_fade). deco: a frame above the content; frame: the window to frame.
-- The main window and every popup use it.
function UI.WindowFrame(deco, frame)
    local ring = RoundRect(deco, frame, "OVERLAY", 0, 8, 0, 1, 1, 1, 1, ASSET_ROOT .. "window_ring")
    ring:SetColor(FLT.SkinC(0.50, 0.38, 0.19, 1))
    local ACC = { FLT.SkinC(0.95, 0.72, 0.32) }
    local LINE_A, SHINE_A = 0.55, 0.16
    local function tex(file, layer, alpha, l, r, t, b)
      local x = deco:CreateTexture(nil, layer, nil, 2); FLT.SetTex(x, ASSET_ROOT .. file); x:SetBlendMode("ADD")
      x:SetVertexColor(ACC[1], ACC[2], ACC[3]); x:SetAlpha(alpha)
      if l then x:SetTexCoord(l, r, t, b) end
      return x
    end
    local CORNERS = {
      { "TOPLEFT", 1, -1, { 0, 0.25, 0, 0.25 }, false, false }, { "TOPRIGHT", -1, -1, { 0.75, 1, 0, 0.25 }, true, false },
      { "BOTTOMLEFT", 1, 1, { 0, 0.25, 0.75, 1 }, false, true }, { "BOTTOMRIGHT", -1, 1, { 0.75, 1, 0.75, 1 }, true, true },
    }
    local HLEN, VLEN, DEPTH, CG = 34, 26, 5, 10
    for _, c in ipairs(CORNERS) do
      local pt, sx, sy, fu, fv = c[1], c[2], c[3], c[5], c[6]
      local u0, u1 = fu and 1 or 0, fu and 0 or 1
      local v0, v1 = fv and 1 or 0, fv and 0 or 1
      local arc = tex("window_ring", "OVERLAY", LINE_A, unpack(c[4])); arc:SetSize(8, 8); arc:SetPoint(pt, frame, pt, 0, 0)
      local hl = tex("fade_lr", "OVERLAY", LINE_A, u0, u1, 0, 1); hl:SetSize(HLEN, 1); hl:SetPoint(pt, frame, pt, sx * 8, 0)
      local vl = tex("fade_lr", "OVERLAY", LINE_A); vl:SetSize(1, VLEN); vl:SetPoint(pt, frame, pt, 0, sy * 8)
      if sy < 0 then vl:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) else vl:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1) end
      local cg = tex("corner_glow", "ARTWORK", SHINE_A, u0, u1, v0, v1); cg:SetSize(CG, CG); cg:SetPoint(pt, frame, pt, 0, 0)
      local hs = tex("edge_fade", "ARTWORK", SHINE_A, u0, u1, v0, v1); hs:SetSize(HLEN - CG + 8, DEPTH); hs:SetPoint(pt, frame, pt, sx * CG, 0)
      local vs = tex("edge_fade", "ARTWORK", SHINE_A); vs:SetSize(DEPTH, VLEN - CG + 8); vs:SetPoint(pt, frame, pt, 0, sy * CG)
      local d0, d1 = fu and 1 or 0, fu and 0 or 1
      if sy < 0 then vs:SetTexCoord(0, d0, 1, d0, 0, d1, 1, d1) else vs:SetTexCoord(1, d0, 0, d0, 1, d1, 0, d1) end
    end
  return ring
end

-- Left-aligned navigation button (plate skin, icon, label); b:SetActive(on).
-- glow line (Assets/glow_line, ADD): side "LEFT" upright on the left edge, else along the bottom (header test)
function UI.GlowLine(owner, side, alpha, width)
  local g = owner:CreateTexture(nil, "ARTWORK", nil, 2)
  FLT.SetTex(g, ASSET_ROOT .. "glow_line"); g:SetBlendMode("ADD"); g:SetVertexColor(1, 0.78, 0.35); g:SetAlpha(alpha or 0.85)
  if side == "LEFT" then
    g:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
    g:SetWidth(width or 10); g:SetPoint("TOP", owner, "TOPLEFT", 1, 2); g:SetPoint("BOTTOM", owner, "BOTTOMLEFT", 1, -2)
  else
    g:SetHeight(10); g:SetPoint("LEFT", owner, "BOTTOMLEFT", -2, 1); g:SetPoint("RIGHT", owner, "BOTTOMRIGHT", 2, 1)
  end
  return g
end

-- header test (user 30.10.): side lists are lists, no buttons - no plate; the chosen entry gets a dark warm plate and
-- the gold glow on its left edge, hover lightens a little
local NAV_TEXT, NAV_TEXT_ON = { 0.90, 0.86, 0.78 }, { 1, 0.86, 0.45 }
function UI.NavButton(parent, text, w, h, icon)
  local b = CreateFrame("Button", nil, parent); b:SetSize(w, h)
  local sel = RoundRect(b, b, "BACKGROUND", 1, 6, 0, 0.21, 0.15, 0.08, 0.95)
  local hov = RoundRect(b, b, "HIGHLIGHT", 0, 6, 0, 0.07, 0.06, 0.04, 1)
  for _, t in ipairs(hov.pieces) do t:SetBlendMode("ADD") end
  local glow = UI.GlowLine(b, "LEFT", 0.85, 5) -- ht6: the mark half as wide (ht5 had made it fainter instead)
  local plate = {}
  function plate:SetActive(on) sel:SetShown(on and true or false); glow:SetShown(on and true or false) end
  plate:SetActive(false)
  local ic
  if icon then ic = b:CreateTexture(nil, "ARTWORK"); ic:SetSize(h - 9, h - 9); ic:SetPoint("LEFT", 7, 0); FLT.SetTex(ic, icon) end
  local label = FLT.NewFS(b, nil, "OVERLAY", "GameFontNormal")
  do local font, _, flags = label:GetFont(); if font then label:SetFont(font, 12, flags) end end
  label:SetPoint("LEFT", icon and (h + 2) or 10, 0); label:SetJustifyH("LEFT"); label:SetText(text); label:SetTextColor(unpack(NAV_TEXT))
  b._label, b.icon = label, ic
  function b:SetActive(on)
    plate:SetActive(on)
    label:SetTextColor(unpack(on and NAV_TEXT_ON or NAV_TEXT))
  end
  return b
end

-- Rounded card for a row/tile with a gold hover ring; returns the card.
function UI.CardRow(b, fill, border)
  local card = Card(b, b, 4, border or {0.28, 0.25, 0.20, 0.90}, fill or {0.060, 0.062, 0.074, 0.97}, "BACKGROUND", 0)
  local hi = b:CreateTexture(nil, "HIGHLIGHT"); hi:SetPoint("TOPLEFT", 1, -1); hi:SetPoint("BOTTOMRIGHT", -1, 1); hi:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.07))
  UI.HoverEdge(b)
  -- selection: gold border + warm fill
  function card:SetSelected(on, nfill)
    if on then self:SetBorder(1, 0.80, 0.34, 1); self:SetFill(0.22, 0.155, 0.055, 0.98)
    else self:SetBorder(unpack(border or {0.28, 0.25, 0.20, 0.90})); self:SetFill(unpack(nfill or fill or {0.060, 0.062, 0.074, 0.97})) end
  end
  return card
end

-- Section title with the ornate divider below it.
function UI.SectionTitle(parent, text, x, y, right)
  local t = FLT.NewFS(parent, nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOPLEFT", x, y); t:SetText(text); t:SetTextColor(FLT.SkinC(unpack(UI.GOLD)))
  do local font, _, flags = t:GetFont(); if font then t:SetFont(font, 14, flags) end end
  local dv = parent:CreateTexture(nil, "ARTWORK"); FLT.SetTex(dv, ASSET_ROOT .. "divider_ornate"); dv:SetHeight(14)
  -- ht5 (user 30.10.): the line right next to the word (like Classic Refined), same line, a little quieter
  dv:SetPoint("LEFT", t, "RIGHT", 12, -1); dv:SetPoint("RIGHT", parent, "RIGHT", right or -20, 0); dv:SetAlpha(0.65)
  t.divider = dv
  return t
end

-- Close button in the addon style (top right of popups); onClick defaults to
-- hiding the parent.
function UI.CloseButton(parent, onClick)
  local b = GoldButton(parent, "", 24, 20, ASSET_ROOT .. "icon_close", 11)
  if b.icon then b.icon:ClearAllPoints(); b.icon:SetSize(14, 14); b.icon:SetPoint("CENTER", 0, 0) end
  b:SetScript("OnMouseDown", nil); b:SetScript("OnMouseUp", nil)
  b:SetScript("OnClick", onClick or function() parent:Hide() end)
  b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(CLOSE or "Close"); GameTooltip:Show() end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- Puts our plate look on a Blizzard UIPanelButtonTemplate button (kept where the
-- template is needed, e.g. secure buttons); its text stays its own.
function UI.SkinBlizzButton(b, h)
  if not b then return b end
  for _, k in ipairs({ "Left", "Middle", "Right" }) do if type(b[k]) == "table" and b[k].SetAlpha then b[k]:SetAlpha(0) end end
  for _, fn in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
    local t = b[fn] and b[fn](b)
    if t and t.SetAlpha then t:SetAlpha(0) end
  end
  Plate(b, h or (b.GetHeight and b:GetHeight()) or 22)
  local fs = b.GetFontString and b:GetFontString()
  if fs and fs.SetTextColor then fs:SetTextColor(FLT.SkinC(0.95, 0.82, 0.50)) end
  return b
end

-- Horizontal slider in the addon style: thin framed track with a gold fill up
-- to the knob, mouse wheel steps. onChange(value) runs on every change.
-- Returns the Slider (SetValue / GetValue as usual).
function UI.Slider(parent, w, minV, maxV, step, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL"); s:SetSize(w, 18)
  s:SetMinMaxValues(minV, maxV); s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true); s:EnableMouseWheel(true)
  local track = CreateFrame("Frame", nil, s); track:SetHeight(6)
  track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0)
  Card(track, track, 3, {0.55, 0.42, 0.20, 0.95}, {0.04, 0.04, 0.05, 0.95}, "BACKGROUND", 0)
  local fill = makeTexture(track, "ARTWORK", 0.85, 0.64, 0.24, 0.75)
  fill:SetPoint("TOPLEFT", 1, -1); fill:SetPoint("BOTTOMLEFT", 1, 1); fill:SetWidth(1)
  local thumb = s:CreateTexture(nil, "OVERLAY"); thumb:SetSize(24, 24)
  thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  s:SetThumbTexture(thumb)
  local TW = 24 -- thumb width: the thumb's centre moves from TW/2 to width - TW/2
  local function update(v)
    local lo, hi = s:GetMinMaxValues()
    local f = (hi > lo) and ((v - lo) / (hi - lo)) or 0
    local tw = (s:GetWidth() or w)
    fill:SetWidth(math.max(1, TW / 2 + f * (tw - TW) - 1))
  end
  s:SetScript("OnValueChanged", function(self, v)
    local lo, hi = self:GetMinMaxValues()
    v = math.floor(v / step + 0.5) * step
    if v > hi - step / 2 then v = hi elseif v < lo + step / 2 then v = lo end
    update(v)
    if onChange then onChange(v) end
  end)
  s:SetScript("OnMouseWheel", function(self, d)
    local lo, hi = self:GetMinMaxValues()
    self:SetValue(math.max(lo, math.min(hi, (self:GetValue() or lo) + d * step)))
  end)
  s:HookScript("OnShow", function(self) update(self:GetValue() or minV) end)
  return s
end

-- Small gem marker (tinted stone in a gold rim). Returns a frame with
-- :SetColor(r,g,b) and the usual Show/Hide/SetShown.
UI.KNOW_COLORS = { me = {0.92, 0.78, 0.35}, guild = {0.45, 0.85, 0.45}, other = {0.45, 0.68, 0.92} }
function UI.Gem(parent, size, r, g, b)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(size, size)
  local fill = f:CreateTexture(nil, "ARTWORK", nil, 1); fill:SetAllPoints(); FLT.SetTex(fill, ASSET_ROOT .. "gem_fill")
  local rim = f:CreateTexture(nil, "ARTWORK", nil, 2); rim:SetAllPoints(); FLT.SetTex(rim, ASSET_ROOT .. "gem_rim")
  function f:SetColor(cr, cg, cb) fill:SetVertexColor(FLT.SkinC(cr, cg, cb)) end
  if r then f:SetColor(r, g, b) end
  return f
end

-- Head of a page's right side (QoL; Dungeons and Hunter Pets since 31.10., user): masked icon, gold title, one grey
-- line, a search box at the top right with an X next to it. opts = { x = left edge, y = top, right = inset of the box
-- from the right edge, placeholder = text, onSearch = function(lowerText) }. The page content starts 60 below y.
-- h:Set(icon, title, line); h.box is the edit box (h.box:SetText("") clears the search).
function UI.PageHeader(parent, opts)
  local x, y = opts.x or 0, opts.y or 0
  local h = {}
  local icon = parent:CreateTexture(nil, "ARTWORK"); icon:SetSize(30, 30); icon:SetPoint("TOPLEFT", x + 16, y - 12)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if icon.AddMaskTexture and parent.CreateMaskTexture then
    local m = parent:CreateMaskTexture(); FLT.SetTex(m, ASSET_ROOT .. "talent_icon_mask2", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(icon); icon:AddMaskTexture(m)
  end
  local title = FLT.NewFS(parent, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", x + 56, y - 12)
  title:SetTextColor(1, 0.82, 0.20)
  local sub = FLT.NewFS(parent, nil, "OVERLAY", "GameFontHighlightSmall"); sub:SetPoint("TOPLEFT", x + 56, y - 32)
  sub:SetTextColor(0.84, 0.81, 0.74)
  local box = FLT.SkinBlizz(CreateFrame("EditBox", nil, parent, "InputBoxTemplate"))
  box:SetSize(210, 20); box:SetPoint("TOPRIGHT", -(opts.right or 46), y - 18); box:SetAutoFocus(false)
  local ph = FLT.NewFS(box, nil, "OVERLAY", "GameFontDisableSmall"); ph:SetPoint("LEFT", 4, 0); ph:SetText(opts.placeholder or "Search...")
  -- X next to the box, not inside (user 22.10.)
  local clear = GoldButton(parent, "X", 20, 20, nil, 10); clear:SetPoint("LEFT", box, "RIGHT", 4, 0); clear:Hide()
  clear:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self)
    local t = (self:GetText() or ""):lower(); ph:SetShown(t == ""); clear:SetShown(t ~= "")
    if opts.onSearch then opts.onSearch(t) end
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  h.icon, h.title, h.sub, h.box = icon, title, sub, box
  function h:Set(tex, text, line) FLT.SetTex(icon, tex); title:SetText(text or ""); sub:SetText(line or "") end
  return h
end

-- Small confirmation popup: UI.Confirm(text, onYes[, yesLabel[, secureMacro]]).
-- With secureMacro the Yes button runs that macro (e.g. "/reload", which an
-- addon may not call directly) through a secure button; onYes runs first.
local confirmFrame
function UI.Confirm(text, onYes, yesLabel, secureMacro)
  if not confirmFrame then
    local f = CreateFrame("Frame", "OneForAllConfirm", UIParent)
    f:SetSize(380, 130); f:SetPoint("CENTER", 0, 80); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
    UI.FramedPanel(f)
    for _, t in ipairs(OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    f.text = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlight"); f.text:SetPoint("TOP", 0, -24); f.text:SetWidth(330); f.text:SetJustifyH("CENTER")
    f.yes = GoldButton(f, "Yes", 110, 26, nil, 13); f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -8, 18)
    f.no = GoldButton(f, "Cancel", 110, 26, nil, 13); f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 18)
    f.no:SetScript("OnClick", function() f:Hide() end)
    -- the secure twin of the Yes button is made on first use (out of combat)
    f:SetScript("OnHide", function()
      if f.secureYes and not (InCombatLockdown and InCombatLockdown()) then f.secureYes:Hide(); f.yes:SetAlpha(1) end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllConfirm") end
    confirmFrame = f
  end
  local f = confirmFrame
  f.text:SetText(text); f.yes:SetLabel(yesLabel or "Yes")
  f:SetHeight(math.max(120, (f.text:GetStringHeight() or 14) + 84))
  f.yes:SetScript("OnClick", function() f:Hide(); if onYes then onYes() end end)
  local combat = InCombatLockdown and InCombatLockdown()
  if secureMacro and not combat and not f.secureYes then
    local sy = CreateFrame("Button", "OneForAllConfirmSecure", f, "SecureActionButtonTemplate")
    sy:SetAllPoints(f.yes); sy:SetFrameLevel(f.yes:GetFrameLevel() + 5)
    sy:RegisterForClicks("AnyUp", "AnyDown")
    sy:SetAttribute("type", "macro")
    UI.Plate(sy, 26)
    sy.label = FLT.NewFS(sy, nil, "OVERLAY", "GameFontNormal"); sy.label:SetPoint("CENTER")
    do local font, _, flags = sy.label:GetFont(); if font then sy.label:SetFont(font, 13, flags) end end
    sy.label:SetTextColor(FLT.SkinC(0.95, 0.82, 0.50))
    sy:Hide()
    f.secureYes = sy
  end
  local sy = f.secureYes
  if sy then
    if combat then
      if sy:IsShown() then return end -- cannot swap the secure button in combat
    elseif secureMacro then
      sy:SetAttribute("macrotext", secureMacro)
      sy.label:SetText(yesLabel or "Yes")
      sy:SetScript("PreClick", function() if onYes then onYes() end end)
      sy:Show(); f.yes:SetAlpha(0)
    else
      sy:Hide(); f.yes:SetAlpha(1)
    end
  end
  f:Show()
end

-- Bug report window: where to report (GitHub issues or a CurseForge comment) in
-- boxes that can be copied (WoW cannot open a browser), version / class / level and
-- the last caught errors (OneForAllDB.errors, see FLT.SafeCall) to paste along.
UI.ISSUES_URL = "https://github.com/smoergi/OneForAll_Forever/issues"
UI.CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/oneforall-forever"
UI.DISCORD_URL = "https://discord.gg/bQhjSpdA3S" -- the invite does not expire (user 24.10.)
local bugFrame
-- read-only box: typing puts the text back, a click selects it all
local function copyBox(parent, w, h, multi)
  local box
  if multi then
    local sf = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate"))
    sf:SetSize(w, h)
    box = CreateFrame("EditBox", nil, sf); box:SetMultiLine(true); box:SetWidth(w - 4)
    sf:SetScrollChild(box)
    local bg = makeTexture(sf, "BACKGROUND", 0.02, 0.02, 0.03, 0.85); bg:SetPoint("TOPLEFT", -4, 4); bg:SetPoint("BOTTOMRIGHT", 4, -4)
    box.holder = sf
  else
    box = FLT.SkinBlizz(CreateFrame("EditBox", nil, parent, "InputBoxTemplate")); box:SetSize(w, h)
    box.holder = box
  end
  box:SetAutoFocus(false); box:SetFontObject("GameFontHighlightSmall")
  box:SetScript("OnTextChanged", function(b, user) if user then b:SetText(b.value or ""); b:HighlightText() end end)
  box:SetScript("OnEditFocusGained", function(b) b:HighlightText() end)
  box:SetScript("OnMouseUp", function(b) b:SetFocus(); b:HighlightText() end)
  box:SetScript("OnEscapePressed", function() parent:Hide() end)
  function box:SetValue(t) self.value = t; self:SetText(t); self:SetCursorPosition(0) end
  return box
end
function UI.ShowBugReport()
  if not bugFrame then
    local f = CreateFrame("Frame", "OneForAllBugReport", UIParent)
    f:SetSize(440, 358); f:SetPoint("CENTER", 0, 80); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
    f:SetMovable(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    for _, t in ipairs(OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)
    local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", 0, -20)
    title:SetText("Report a bug or idea"); title:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
    local text = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); text:SetPoint("TOP", 0, -44); text:SetWidth(390)
    text:SetJustifyH("CENTER")
    text:SetText("Copy a link (Ctrl+C) and open it in your browser: an issue on GitHub or a comment on CurseForge. A screenshot helps a lot.")
    local function label(t, y)
      local l = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("TOPLEFT", 28, y); l:SetText(t); l:SetTextColor(FLT.SkinC(0.90, 0.74, 0.42))
    end
    label("GitHub", -80)
    f.gh = copyBox(f, 300, 20); f.gh:SetPoint("TOPLEFT", 112, -76)
    label("CurseForge", -108)
    f.cf = copyBox(f, 300, 20); f.cf:SetPoint("TOPLEFT", 112, -104)
    label("Discord", -136)
    f.dc = copyBox(f, 300, 20); f.dc:SetPoint("TOPLEFT", 112, -132)
    label("Please add", -166)
    f.err = copyBox(f, 384, 116, true); f.err.holder:SetPoint("TOPLEFT", 28, -184)
    local ok = GoldButton(f, "Close", 110, 26, nil, 13); ok:SetPoint("BOTTOM", 0, 16)
    ok:SetScript("OnClick", function() f:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllBugReport") end
    bugFrame = f
  end
  local f = bugFrame
  local ver
  if C_AddOns and C_AddOns.GetAddOnMetadata then ver = C_AddOns.GetAddOnMetadata(ADDON, "Version")
  elseif GetAddOnMetadata then ver = GetAddOnMetadata(ADDON, "Version") end
  local class = UnitClass and UnitClass("player")
  local level = UnitLevel and UnitLevel("player")
  local lines = { string.format("OneForAll %s | %s | Level %s | %s", tostring(ver or "?"), tostring(class or "?"),
    tostring(level or "?"), GetLocale and GetLocale() or "?") }
  local errs = type(OneForAllDB) == "table" and OneForAllDB.errors
  if type(errs) == "table" and #errs > 0 then
    lines[#lines + 1] = "Last caught errors:"
    for i = 1, math.min(5, #errs) do lines[#lines + 1] = tostring(errs[i]) end
  else
    lines[#lines + 1] = "No errors caught."
  end
  f.gh:SetValue(UI.ISSUES_URL); f.cf:SetValue(UI.CURSEFORGE_URL); f.dc:SetValue(UI.DISCORD_URL)
  f.err:SetValue(table.concat(lines, "\n"))
  f:Show()
  f.gh:SetFocus(); f.gh:HighlightText()
end

-- Discord (5.7.3, title bar button): the invite link to copy, built on first use
local discordFrame
function UI.ShowDiscord()
  if not discordFrame then
    local f = CreateFrame("Frame", "OneForAllDiscord", UIParent)
    f:SetSize(400, 170); f:SetPoint("CENTER", 0, 80); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
    f:SetMovable(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.FramedPanel(f)
    for _, t in ipairs(OrnateFrame(f, f, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)
    local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", 0, -20)
    title:SetText("OneForAll on Discord"); title:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
    local text = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); text:SetPoint("TOP", 0, -46); text:SetWidth(350)
    text:SetJustifyH("CENTER")
    text:SetText("News, questions and ideas. Copy the link (Ctrl+C) and open it in your browser.")
    f.link = copyBox(f, 300, 20); f.link:SetPoint("TOP", 0, -84)
    local ok = GoldButton(f, "Close", 110, 26, nil, 13); ok:SetPoint("BOTTOM", 0, 16)
    ok:SetScript("OnClick", function() f:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllDiscord") end
    discordFrame = f
  end
  discordFrame.link:SetValue(UI.DISCORD_URL)
  discordFrame:Show()
  discordFrame.link:SetFocus(); discordFrame.link:HighlightText()
end

-- Shared drop-down list (one at a time); a click outside closes it.
-- options = { {key=, label=[, checked=][, remove=]}, ... }; the current one (or every o.checked) gets a check mark.
-- width: list width (default: the owner's width).
local ddMenu, ddCatcher
function UI.OpenDropDown(owner, options, current, onPick, width)
  if not ddMenu then
    ddCatcher = CreateFrame("Button", nil, UIParent); ddCatcher:SetAllPoints(UIParent)
    ddCatcher:SetFrameStrata("FULLSCREEN_DIALOG"); ddCatcher:SetFrameLevel(1)
    ddCatcher:RegisterForClicks("AnyUp"); ddCatcher:Hide()
    ddMenu = CreateFrame("Frame", nil, UIParent); ddMenu:SetFrameStrata("FULLSCREEN_DIALOG"); ddMenu:SetFrameLevel(20)
    ddMenu:EnableMouse(true); ddMenu:Hide()
    UI.FramedPanel(ddMenu)
    ddMenu.rows = {}
    ddCatcher:SetScript("OnClick", function() ddMenu:Hide() end)
    ddMenu:SetScript("OnHide", function() ddCatcher:Hide() end)
  end
  if ddMenu:IsShown() and ddMenu.owner == owner then ddMenu:Hide(); return end
  local w = width or owner:GetWidth() or 170
  for _, r in ipairs(ddMenu.rows) do r:Hide() end
  for i, o in ipairs(options) do
    local r = ddMenu.rows[i]
    if not r then
      r = CreateFrame("Button", nil, ddMenu); r:SetHeight(22)
      local hi = r:CreateTexture(nil, "HIGHLIGHT"); hi:SetAllPoints(); hi:SetColorTexture(FLT.SkinC(0.90, 0.66, 0.22, 0.18))
      r.text = FLT.NewFS(r, nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 22, 0)
      r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(14, 14); r.check:SetPoint("LEFT", 5, 0)
      r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check"); FLT.SkinBlizz(r)
      -- o.remove: a red cross on the right - a click on this entry deletes it (user 31.10.)
      r.del = r:CreateTexture(nil, "OVERLAY"); r.del:SetSize(14, 14); r.del:SetPoint("RIGHT", -6, 0)
      r.del:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
      ddMenu.rows[i] = r
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 22)
    r.text:SetText(o.label)
    -- the menu grows with its longest entry (6.1.0, user 03.11.: long buff names ran over the edge)
    local need = (r.text:GetStringWidth() or 0) + 22 + (o.remove and 24 or 10) + 8
    if need > w then w = math.ceil(need) end
    local sel = o.key == current
    if o.checked ~= nil then sel = o.checked end -- several picks at once (Gear Planner sources, user 31.10.)
    r.check:SetShown(sel); r.del:SetShown(o.remove and true or false)
    if sel then r.text:SetTextColor(FLT.SkinC(1, 0.82, 0.2)) else r.text:SetTextColor(0.92, 0.90, 0.84) end
    r:SetScript("OnClick", function() ddMenu:Hide(); onPick(o.key) end)
    r:Show()
  end
  for i = 1, #options do ddMenu.rows[i]:SetWidth(w - 8) end
  ddMenu:SetSize(w, #options * 22 + 8)
  ddMenu:ClearAllPoints(); ddMenu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
  ddMenu.owner = owner
  ddCatcher:Show(); ddMenu:Show()
end
function UI.CloseDropDown() if ddMenu then ddMenu:Hide() end end

UI.GoldButton = GoldButton
UI.RoundRect = RoundRect
UI.Card = Card
UI.OrnateFrame = OrnateFrame
UI.makeTexture = makeTexture
UI.makeButton = makeButton
UI.addDivider = addDivider

-- Panel registry ------------------------------------------------------------
-- spec = { key=, label=, order=, tabWidth=, create=function(parent) return frame end }
-- A panel may define panel:Refresh(), which runs whenever the window refreshes.
UI.panels = {}
function UI.RegisterPanel(spec)
  UI.panels[#UI.panels + 1] = spec
  table.sort(UI.panels, function(a, b) return (a.order or 99) < (b.order or 99) end)
end
