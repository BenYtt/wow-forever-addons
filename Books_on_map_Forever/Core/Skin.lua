-- Books on map (Forever): custom skin (no game templates): rounded gradient windows with a soft
-- shadow, gold trim, eased animations (open/close, hover fades, progress fill,
-- glint and shine), buttons, checkboxes, sliders, scroll bars, sections
local ADDON, ns = ...

local S = {}
ns.Skin = S

local WHITE = "Interface\\Buttons\\WHITE8x8"
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\adds\\UI\\"
S.MEDIA = MEDIA

-- Palette ------------------------------------------------------------------
local function hex(h)
  return { tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255, 1 }
end

local C = {
  bg1      = hex("#0B1426"), -- window gradient, top
  bg2      = hex("#05080F"), -- window gradient, bottom
  well     = hex("#060A12"), -- inside of boxes, checkboxes, tracks
  trim     = hex("#3A6FB0"), -- borders
  ring     = hex("#4C8DE0"), -- active / hover border
  rule     = { 0.10, 0.16, 0.27, 1 }, -- dividers
  bar      = { 0, 0, 0, 0.30 },
  gold     = hex("#5CC8FF"), -- accent (the icon's blue glow)
  text     = hex("#E4EEFA"),
  muted    = hex("#7F90AB"),
  dim      = hex("#8C9AB2"),
  good     = hex("#6BDB8B"),
  bad      = hex("#FF6B6B"),
  btn1     = hex("#162640"), btn2 = hex("#0A111F"),
  primary1 = hex("#2F6FB8"), primary2 = hex("#173A6E"),
  pill1    = hex("#1F4F8F"), pill2 = hex("#0E2445"),
  fill1    = hex("#9BE6FF"), fill2 = hex("#1E6FD0"),
  gold1    = hex("#FFE38A"), gold2 = hex("#C4791A"), -- progress bar fill
}
C.accent, C.border, C.card, C.bg = C.gold, C.trim, C.well, C.bg2
S.C = C

local function color(t, a) return t[1], t[2], t[3], a or t[4] end
S.Color = color

local function lerp(a, b, p) return a + (b - a) * p end
local function lerpColor(c1, c2, p)
  return lerp(c1[1], c2[1], p), lerp(c1[2], c2[2], p), lerp(c1[3], c2[3], p), lerp(c1[4] or 1, c2[4] or 1, p)
end

-- gradient: c1 -> c2, top to bottom (or left to right when horizontal)
local function gradient(tex, c1, c2, horizontal, keepTexture)
  if not keepTexture then tex:SetTexture(WHITE) end
  tex:SetVertexColor(1, 1, 1, 1)
  local o = horizontal and "HORIZONTAL" or "VERTICAL"
  -- VERTICAL runs bottom -> top, HORIZONTAL left -> right
  local a, b = c1, c2
  if not horizontal then a, b = c2, c1 end
  if tex.SetGradient then
    local function col(c) return { r = c[1], g = c[2], b = c[3], a = c[4] or 1 } end
    if pcall(tex.SetGradient, tex, o, col(a), col(b)) then return end
  end
  if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, o,
    a[1], a[2], a[3], a[4] or 1, b[1], b[2], b[3], b[4] or 1) then return end
  tex:SetVertexColor(color(c1))
end
S.Gradient = gradient

-- Tweens -------------------------------------------------------------------
local ease = {
  linear = function(p) return p end,
  outCubic = function(p) return 1 - (1 - p) ^ 3 end,
  inOutCubic = function(p) return p < 0.5 and 4 * p ^ 3 or 1 - (-2 * p + 2) ^ 3 / 2 end,
  outBack = function(p) local c = 1.70158; return 1 + (c + 1) * (p - 1) ^ 3 + c * (p - 1) ^ 2 end,
}
S.Ease = ease

local tweens = {}
local running = {} -- snapshot: set/done callbacks may start or replace tweens mid-loop
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
  wipe(running)
  for key, t in pairs(tweens) do running[key] = t end
  for key, t in pairs(running) do
    if tweens[key] == t then -- not replaced or stopped by an earlier callback
      t.t = t.t + elapsed
      local p = math.min(1, t.t / t.dur)
      t.set(lerp(t.from, t.to, t.ease(p)), p)
      if p >= 1 and tweens[key] == t then
        tweens[key] = nil
        if t.done then t.done() end
      end
    end
  end
  if not next(tweens) then self:Hide() end
end)

-- S.Tween(key, { dur, from, to, ease, set(value, p), done }); same key = replaces the running one
function S.Tween(key, a)
  a.t, a.dur = 0, a.dur or 0.25
  a.ease = type(a.ease) == "function" and a.ease or ease[a.ease or "outCubic"]
  tweens[key] = a
  driver:Show()
end

function S.StopTween(key) tweens[key] = nil end

-- fades a region's alpha to a value
function S.FadeTo(region, alpha, dur, done)
  S.Tween(region, { dur = dur or 0.15, from = region:GetAlpha(), to = alpha,
    set = function(v) region:SetAlpha(v) end, done = done })
end

-- Fonts --------------------------------------------------------------------
-- the game font, with a soft shadow
local fonts = {}
local function font(size)
  local key = tostring(size)
  if not fonts[key] then
    local f = CreateFont("BooksOnMapForeverFont" .. key)
    f:SetFont(STANDARD_TEXT_FONT, size, "")
    f:SetShadowColor(0, 0, 0, 0.9)
    f:SetShadowOffset(1, -1)
    fonts[key] = f
  end
  return fonts[key]
end

-- fontstring: size, palette color name (weight: kept for callers, the game font has one)
function S.Text(parent, size, col, weight, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(font(size or 13))
  fs:SetTextColor(color(C[col or "text"]))
  fs:SetJustifyH("LEFT")
  return fs
end

-- Boxes --------------------------------------------------------------------
local function setBorderColor(f, r, g, b, a)
  for _, t in ipairs(f.borders) do
    if t.isCorner then t:SetVertexColor(r, g, b, a or 1) else t:SetColorTexture(r, g, b, a or 1) end
  end
end

local function frameLines(f, layer, sub, inset)
  local t, b, l, r = f:CreateTexture(nil, layer, nil, sub), f:CreateTexture(nil, layer, nil, sub),
    f:CreateTexture(nil, layer, nil, sub), f:CreateTexture(nil, layer, nil, sub)
  t:SetPoint("TOPLEFT", inset, -inset); t:SetPoint("TOPRIGHT", -inset, -inset); t:SetHeight(1)
  b:SetPoint("BOTTOMLEFT", inset, inset); b:SetPoint("BOTTOMRIGHT", -inset, inset); b:SetHeight(1)
  l:SetPoint("TOPLEFT", inset, -inset); l:SetPoint("BOTTOMLEFT", inset, inset); l:SetWidth(1)
  r:SetPoint("TOPRIGHT", -inset, -inset); r:SetPoint("BOTTOMRIGHT", -inset, inset); r:SetWidth(1)
  return { t, b, l, r }
end

-- square box: background (color, or {top, bottom} gradient) + 1px border (false: none)
function S.Box(f, bg, border)
  f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.bg:SetAllPoints()
  if bg and type(bg[1]) == "table" then gradient(f.bg, bg[1], bg[2])
  else f.bg:SetColorTexture(color(bg or C.well)) end
  if border ~= false then
    f.borders = frameLines(f, "BORDER", 0, 0)
    f.SetBorderColor = setBorderColor
    f:SetBorderColor(color(border or C.trim))
  end
  return f
end

-- 9-slice: a square texture with `margin` px corners (out of `size`) stretched over a frame,
-- corners drawn at `cs` px; returns the pieces keyed by point, each with .row = TOP/MID/BOTTOM
local POINTS = {
  { "TOPLEFT", "TOP" }, { "TOP", "TOP" }, { "TOPRIGHT", "TOP" },
  { "LEFT", "MID" }, { "CENTER", "MID" }, { "RIGHT", "MID" },
  { "BOTTOMLEFT", "BOTTOM" }, { "BOTTOM", "BOTTOM" }, { "BOTTOMRIGHT", "BOTTOM" },
}
local function slice9(f, file, size, margin, cs, layer, sub)
  local m = margin / size
  local u = { 0, m, 1 - m, 1 }
  local tex = {}
  for i, p in ipairs(POINTS) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(file)
    t:SetTexCoord(u[col + 1], u[col + 2], u[row + 1], u[row + 2])
    t.row = p[2]
    tex[p[1]] = t
  end
  for _, k in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    tex[k]:SetSize(cs, cs); tex[k]:SetPoint(k)
  end
  tex.TOP:SetPoint("TOPLEFT", tex.TOPLEFT, "TOPRIGHT"); tex.TOP:SetPoint("BOTTOMRIGHT", tex.TOPRIGHT, "BOTTOMLEFT")
  tex.BOTTOM:SetPoint("TOPLEFT", tex.BOTTOMLEFT, "TOPRIGHT"); tex.BOTTOM:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "BOTTOMLEFT")
  tex.LEFT:SetPoint("TOPLEFT", tex.TOPLEFT, "BOTTOMLEFT"); tex.LEFT:SetPoint("BOTTOMRIGHT", tex.BOTTOMLEFT, "TOPRIGHT")
  tex.RIGHT:SetPoint("TOPLEFT", tex.TOPRIGHT, "BOTTOMLEFT"); tex.RIGHT:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "TOPRIGHT")
  tex.CENTER:SetPoint("TOPLEFT", tex.TOPLEFT, "BOTTOMRIGHT"); tex.CENTER:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "TOPLEFT")
  return tex
end

-- soft halo around a frame (black by default, or col)
function S.Shadow(f, size, alpha, col)
  size = size or 14
  local holder = CreateFrame("Frame", nil, f)
  holder:SetPoint("TOPLEFT", -size, size)
  holder:SetPoint("BOTTOMRIGHT", size, -size)
  holder:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  col = col or { 0, 0, 0 }
  for _, t in pairs(slice9(holder, MEDIA .. "Shadow", 64, 16, size * 1.6, "BACKGROUND", -8)) do
    t:SetVertexColor(col[1], col[2], col[3], alpha or 0.7)
  end
  f.shadow = holder
  return holder
end

-- rounded box (radius r): vertical gradient (top, bottom) and a 1px border, both from
-- pre-drawn rounded textures so the corners line up exactly
function S.Rounded(f, r, top, bottom, border)
  r, top, bottom = r or 12, top or C.bg1, bottom or C.bg2
  local cs = r * 16 / 12 -- textures: radius 12 in a 16px margin
  for _, t in pairs(slice9(f, MEDIA .. "RoundFill", 64, 16, cs, "BACKGROUND", -7)) do
    if t.row == "TOP" then t:SetVertexColor(color(top))
    elseif t.row == "BOTTOM" then t:SetVertexColor(color(bottom))
    else gradient(t, top, bottom, false, true) end
  end
  f.borders = {}
  for _, t in pairs(slice9(f, MEDIA .. "RoundEdge", 64, 16, cs, "BORDER", 1)) do
    t.isCorner = true
    f.borders[#f.borders + 1] = t
  end
  f.SetBorderColor = setBorderColor
  f:SetBorderColor(color(border or C.trim))
  return f
end

-- line fading out on both sides (gold in the middle)
function S.Rule(parent, col, alpha)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetHeight(1)
  local c1, c2 = { col[1], col[2], col[3], 0 }, { col[1], col[2], col[3], alpha or 1 }
  local l = holder:CreateTexture(nil, "ARTWORK")
  l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMRIGHT", holder, "BOTTOM")
  gradient(l, c1, c2, true)
  local r = holder:CreateTexture(nil, "ARTWORK")
  r:SetPoint("TOPLEFT", holder, "TOP"); r:SetPoint("BOTTOMRIGHT")
  gradient(r, c2, c1, true)
  return holder
end

-- icon with a thin trim frame, cropped edges
function S.Icon(parent, size, layer)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(size, size)
  S.Box(holder, { 0, 0, 0, 1 }, C.trim)
  local tex = holder:CreateTexture(nil, layer or "ARTWORK")
  tex:SetPoint("TOPLEFT", 1, -1)
  tex:SetPoint("BOTTOMRIGHT", -1, 1)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  holder.tex = tex
  local gloss = holder:CreateTexture(nil, "OVERLAY")
  gloss:SetAllPoints(tex)
  gloss:SetTexture(MEDIA .. "Gloss")
  return holder
end

-- smooth hover: a highlight region fades in/out with the mouse
function S.HoverFade(frame, region, alpha)
  region:SetAlpha(0)
  frame:HookScript("OnEnter", function() S.FadeTo(region, alpha or 1, 0.12) end)
  frame:HookScript("OnLeave", function() S.FadeTo(region, 0, 0.25) end)
end

-- row highlight: gold wash fading to the right + gold bar on the left
function S.RowHighlight(row)
  local hl = CreateFrame("Frame", nil, row)
  hl:SetAllPoints()
  local wash = hl:CreateTexture(nil, "BACKGROUND", nil, 1)
  wash:SetAllPoints()
  gradient(wash, { 0.36, 0.78, 1, 0.14 }, { 0.36, 0.78, 1, 0 }, true)
  local bar = hl:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
  bar:SetColorTexture(color(C.gold))
  S.HoverFade(row, hl)
  return hl
end

-- Close button: gold x, red-gold glow on hover --------------------------------
function S.CloseButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  local glow = b:CreateTexture(nil, "BACKGROUND")
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetPoint("CENTER")
  glow:SetSize(30, 30)
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1, 0.35, 0.35, 0.5)
  S.HoverFade(b, glow)
  b.x = S.Text(b, 15, "muted")
  b.x:SetPoint("CENTER", 0, 1)
  b.x:SetText("x")
  b:HookScript("OnEnter", function(self) self.x:SetTextColor(color(C.gold)) end)
  b:HookScript("OnLeave", function(self) self.x:SetTextColor(color(C.muted)) end)
  b:SetScript("OnClick", onClick or function() S.Close(parent) end)
  return b
end

-- Windows ------------------------------------------------------------------
-- opening: fade + short rise with a soft overshoot
function S.AnimateOpen(f, dx, dy)
  local p, rel, rp, x, y = f:GetPoint(1)
  if not p then return end
  f.home = f.home or { p, rel, rp, x, y }
  local h = f.home
  dx, dy = dx or 0, dy or -12
  f:SetAlpha(0)
  S.Tween(f, { dur = 0.32, from = 0, to = 1, ease = "outBack", set = function(v, pr)
    f:SetAlpha(math.min(1, pr * 2.5))
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4] + dx * (1 - v), h[5] + dy * (1 - v))
  end })
end

-- closing: quick fade, then hide
function S.Close(f)
  if not f:IsShown() then return end
  S.Tween(f, { dur = 0.14, from = f:GetAlpha(), to = 0, set = function(v) f:SetAlpha(v) end,
    done = function() f:Hide(); f:SetAlpha(1) end })
end

-- closing the other way round from AnimateOpen: slides back (dx, dy) while fading, then hides
function S.AnimateClose(f, dx, dy)
  if not f:IsShown() then return end
  local p, rel, rp, x, y = f:GetPoint(1)
  f.home = f.home or { p, rel, rp, x, y }
  local h = f.home
  dx, dy = dx or 0, dy or -12
  local a0 = f:GetAlpha()
  S.Tween(f, { dur = 0.2, from = 0, to = 1, ease = "inOutCubic", set = function(v)
    f:SetAlpha(a0 * (1 - v))
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4] + dx * v, h[5] + dy * v)
  end, done = function()
    f.closing = nil
    f:Hide()
    f:SetAlpha(1)
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4], h[5])
  end })
end

-- collapsible section: clicking the header folds the body (height + fade), with a +/- sign
-- that morphs; isOpen() / setOpen(bool) store the state
function S.Collapsible(header, body, height, isOpen, setOpen)
  if body.SetClipsChildren then pcall(body.SetClipsChildren, body, true) end
  S.Foldable(header, isOpen, setOpen, function(p)
    body:SetHeight(math.max(0.01, height * p))
    body:SetAlpha(p)
    body:SetShown(p > 0.01)
  end)
end

-- clickable header with a +/- sign (left of `anchor`, or at the right edge); apply(p) gets the
-- open fraction (1 = open, 0 = folded) at every step of the eased animation
function S.Foldable(header, isOpen, setOpen, apply, anchor)
  header:EnableMouse(true)
  local sign = CreateFrame("Frame", nil, header)
  sign:SetSize(10, 10)
  if anchor then sign:SetPoint("RIGHT", anchor, "LEFT", -10, 0) else sign:SetPoint("RIGHT", 0, 2) end
  local hLine = sign:CreateTexture(nil, "OVERLAY")
  hLine:SetSize(10, 2); hLine:SetPoint("CENTER")
  local vLine = sign:CreateTexture(nil, "OVERLAY")
  vLine:SetSize(2, 10); vLine:SetPoint("CENTER")
  local function tint(col) for _, l in ipairs({ hLine, vLine }) do l:SetColorTexture(color(col)) end end
  tint(C.muted)

  local shown = isOpen() and 1 or 0
  local function step(v)
    shown = v
    vLine:SetHeight(math.max(0.01, 10 * (1 - v))) -- minus when open, plus when folded
    apply(v)
  end
  step(shown)
  header.foldShown = function() return shown end

  header:SetScript("OnMouseUp", function()
    local open = not isOpen()
    setOpen(open)
    S.Tween(header, { dur = 0.3, from = shown, to = open and 1 or 0, ease = "outCubic", set = step })
  end)
  header:SetScript("OnEnter", function() header.label:SetTextColor(1, 1, 1); tint(C.gold) end)
  header:SetScript("OnLeave", function() header.label:SetTextColor(color(C.gold)); tint(C.muted) end)
end

-- blue light along the inner edges, fading toward the dark centre; depth 48 matches the
-- rounded box corners (radius 12), smaller depths give tighter corners
-- the glow breathes slowly
function S.EdgeGlow(f, depth, alpha)
  depth, alpha = depth or 48, alpha or 0.24
  local pieces = slice9(f, MEDIA .. "RoundGlow", 128, 48, depth, "BACKGROUND", -5)
  for _, t in pairs(pieces) do t:SetVertexColor(0.24, 0.55, 1, alpha) end

  -- own driver frame: the owner's OnUpdate stays free; runs only while visible
  local driver = CreateFrame("Frame", nil, f)
  local clock = math.random() * 6
  driver:SetScript("OnUpdate", function(_, elapsed)
    clock = clock + elapsed
    local a = 0.9 + 0.1 * math.sin(clock * 1.6) -- ~4 s cycle, gentle
    for _, t in pairs(pieces) do t:SetAlpha(a) end
  end)
end

-- rounded gradient window, shadow, title row with a fading gold rule under it
function S.Window(name, parent, width, height, title)
  local f = CreateFrame("Frame", name, parent or UIParent)
  f:SetSize(width, height)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  S.Shadow(f, 16, 0.5, { 0.12, 0.4, 0.95 }) -- blue halo outside
  S.Rounded(f, 12)
  S.EdgeGlow(f, 48, 0.18)

  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("TOPRIGHT", -1, -1)
  bar:SetHeight(38)
  f.titleBar = bar
  local rule = S.Rule(bar, C.ring, 0.9)
  rule:SetPoint("BOTTOMLEFT", 10, 0)
  rule:SetPoint("BOTTOMRIGHT", -10, 0)

  f.title = S.Text(bar, 16, "gold", "extrabold")
  f.title:SetPoint("LEFT", 14, 0)
  f.title:SetText(title or "")

  f.close = S.CloseButton(f)
  f.close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
  f.close:SetFrameLevel(bar:GetFrameLevel() + 5) -- above the title bar, which takes the mouse for dragging
  f:HookScript("OnShow", function(self) S.AnimateOpen(self, self.openDX, self.openDY) end)
  return f
end

-- makes a frame draggable by a handle (onStop: after moving)
function S.Draggable(f, handle, onStop)
  f:SetMovable(true)
  handle = handle or f
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function() S.StopTween(f); f:SetAlpha(1); f:StartMoving() end)
  handle:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, rel, rp, x, y = f:GetPoint(1)
    f.home = { p, rel, rp, x, y }
    if onStop then onStop(f) end
  end)
end

-- Section header: gold label, optional right text, rule fading to the right
function S.Section(parent, text)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(22)
  local dot = h:CreateTexture(nil, "ARTWORK")
  dot:SetSize(4, 4)
  dot:SetPoint("LEFT", 0, 2)
  dot:SetColorTexture(color(C.gold))
  h.label = S.Text(h, 13, "gold", "extrabold")
  h.label:SetPoint("LEFT", dot, "RIGHT", 7, 0)
  h.label:SetText(text or "")
  h.right = S.Text(h, 12, "muted", "medium")
  h.right:SetPoint("RIGHT", 0, 2)
  local line = h:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
  gradient(line, { C.ring[1], C.ring[2], C.ring[3], 0.7 }, { C.ring[1], C.ring[2], C.ring[3], 0 }, true)
  return h
end

-- Buttons ------------------------------------------------------------------
-- gradient button with gloss; hover = border tweens to gold + inner glow. primary = gold
function S.Button(parent, text, width, height, onClick, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, height or 26)
  local border = primary and C.ring or C.trim
  S.Box(b, primary and { C.primary1, C.primary2 } or { C.btn1, C.btn2 }, border)
  local gloss = b:CreateTexture(nil, "ARTWORK", nil, 1)
  gloss:SetPoint("TOPLEFT", 1, -1); gloss:SetPoint("BOTTOMRIGHT", -1, 1)
  gloss:SetTexture(MEDIA .. "Gloss")
  local glow = b:CreateTexture(nil, "ARTWORK", nil, 2)
  glow:SetPoint("TOPLEFT", 1, -1); glow:SetPoint("BOTTOMRIGHT", -1, 1)
  gradient(glow, { 0.36, 0.78, 1, 0 }, { 0.36, 0.78, 1, primary and 0.3 or 0.18 })
  glow:SetBlendMode("ADD")
  S.HoverFade(b, glow)

  b.text = S.Text(b, 12, primary and "gold" or "text")
  b.text:SetPoint("CENTER")
  b.text:SetJustifyH("CENTER")
  b.text:SetText(text)
  local function tint(to)
    local from = b.borderNow or border
    S.Tween(b.borders, { dur = 0.18, from = 0, to = 1, set = function(v)
      local r, g, bl, a = lerpColor(from, to, v)
      b.borderNow = { r, g, bl, a }
      b:SetBorderColor(r, g, bl, a)
    end })
  end
  b:HookScript("OnEnter", function() tint(C.gold) end)
  b:HookScript("OnLeave", function() tint(border) end)
  b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 0, -1) end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER") end)
  b:SetScript("OnClick", onClick)
  function b:SetText(t) self.text:SetText(t) end
  return b
end

-- row of toggle pills, one selected: options = { {value, text, tooltip}, ... }
function S.Segmented(parent, options, width, getValue, onSelect)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width * #options, 22)
  S.Box(holder, { C.btn1, C.btn2 }, C.trim)
  -- sliding gold pill behind the selected option
  local pill = CreateFrame("Frame", nil, holder)
  pill:SetSize(width - 2, 20)
  S.Box(pill, { C.pill1, C.pill2 }, C.ring)
  holder.buttons = {}
  local current
  local function refresh(animate)
    local v = getValue()
    for i, b in ipairs(holder.buttons) do
      local on = b.value == v
      b.text:SetTextColor(color(on and C.gold or C.dim))
      if on then
        local x = (i - 1) * width + 1
        if animate and current then
          local from = current
          S.Tween(pill, { dur = 0.3, from = from, to = x, ease = "outBack", set = function(px)
            pill:SetPoint("LEFT", px, 0)
          end })
        else
          pill:SetPoint("LEFT", x, 0)
        end
        current = x
      end
    end
  end
  for i, o in ipairs(options) do
    local b = CreateFrame("Button", nil, holder)
    b:SetSize(width, 22)
    b:SetPoint("LEFT", (i - 1) * width, 0)
    b:SetFrameLevel(pill:GetFrameLevel() + 1)
    b.value = o[1]
    b.text = S.Text(b, 11)
    b.text:SetPoint("CENTER")
    b.text:SetText(o[2])
    b:SetScript("OnClick", function() onSelect(o[1]); refresh(true) end)
    b:SetScript("OnEnter", function(self)
      self.text:SetTextColor(color(C.gold))
      if o[3] then
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(o[3], 1, 1, 1)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide(); refresh() end)
    holder.buttons[i] = b
  end
  holder.Refresh = function() refresh(true) end
  refresh()
  return holder
end

-- Checkbox -----------------------------------------------------------------
-- dark well, trim border, gold check that pops in; the label is part of the clickable area
function S.Check(parent, label, size)
  size = size or 18
  local c = CreateFrame("CheckButton", nil, parent)
  c:SetSize(size, size)
  S.Box(c, C.well, C.trim)
  local inner = c:CreateTexture(nil, "ARTWORK")
  inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
  gradient(inner, { C.pill1[1], C.pill1[2], C.pill1[3], 1 }, { C.pill2[1], C.pill2[2], C.pill2[3], 1 })
  local glow = c:CreateTexture(nil, "BACKGROUND", nil, -7)
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER")
  glow:SetSize(size * 2.2, size * 2.2)
  glow:SetVertexColor(0.3, 0.7, 1, 0.6)
  -- check mark drawn with two rotated lines (the game font has no check glyph)
  c.mark = CreateFrame("Frame", nil, c)
  c.mark:SetAllPoints()
  local k = size / 18
  local short = c.mark:CreateTexture(nil, "OVERLAY")
  short:SetTexture(WHITE)
  short:SetSize(6 * k, 2.2 * k)
  short:SetPoint("CENTER", -3 * k, -0.5 * k)
  short:SetRotation(math.rad(-45))
  local long = c.mark:CreateTexture(nil, "OVERLAY")
  long:SetTexture(WHITE)
  long:SetSize(11 * k, 2.2 * k)
  long:SetPoint("CENTER", 1.6 * k, 1 * k)
  long:SetRotation(math.rad(50))
  for _, l in ipairs({ short, long }) do l:SetVertexColor(color(C.fill1)) end

  local function update(self, animate)
    local on = self:GetChecked() and true or false
    if animate then
      S.FadeTo(self.mark, on and 1 or 0, 0.15)
      S.FadeTo(inner, on and 1 or 0, 0.15)
      if on then
        glow:SetAlpha(1)
        S.FadeTo(glow, 0, 0.5)
      end
    else
      self.mark:SetAlpha(on and 1 or 0)
      inner:SetAlpha(on and 1 or 0)
      glow:SetAlpha(0)
    end
  end
  local setChecked = c.SetChecked
  function c:SetChecked(v) setChecked(self, v); update(self) end
  c:SetScript("PostClick", function(self) update(self, true) end) -- callers own OnClick
  c:HookScript("OnEnter", function(self) self:SetBorderColor(color(C.gold)) end)
  c:HookScript("OnLeave", function(self) self:SetBorderColor(color(C.trim)) end)
  update(c)

  if label then
    c.text = S.Text(c, 13, "text", "medium")
    c.text:SetPoint("LEFT", c, "RIGHT", 8, 0)
    c.text:SetText(label)
    c:SetHitRectInsets(0, -(c.text:GetStringWidth() + 10), -3, -3)
    c:HookScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    c:HookScript("OnLeave", function(self) self.text:SetTextColor(color(C.text)) end)
  end
  return c
end

-- Slider -------------------------------------------------------------------
-- label above the track (left), value in gold (right); "%d" in the label is dropped
function S.Slider(parent, width, min, max, label, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(width, 16)
  s:SetMinMaxValues(min, max)
  s:SetValueStep(1)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:SetHitRectInsets(0, 0, -6, -6)
  s:EnableMouseWheel(true)

  local track = CreateFrame("Frame", nil, s)
  track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
  track:SetFrameLevel(s:GetFrameLevel())
  S.Box(track, C.well, C.trim)

  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
  gradient(fill, C.fill2, C.fill1, true)

  local glow = s:CreateTexture(nil, "OVERLAY", nil, 0)
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetBlendMode("ADD")
  glow:SetSize(30, 30)
  glow:SetVertexColor(0.3, 0.75, 1, 0.6)
  local thumb = s:CreateTexture(nil, "OVERLAY", nil, 2)
  thumb:SetTexture(WHITE)
  thumb:SetSize(8, 16)
  gradient(thumb, C.fill1, C.fill2)
  s:SetThumbTexture(thumb)
  local edge = s:CreateTexture(nil, "OVERLAY", nil, 1)
  edge:SetPoint("TOPLEFT", thumb, -1, 1); edge:SetPoint("BOTTOMRIGHT", thumb, 1, -1)
  edge:SetColorTexture(0, 0, 0, 1)
  glow:SetPoint("CENTER", thumb)
  fill:SetPoint("RIGHT", thumb, "CENTER")
  S.HoverFade(s, glow)

  s.label = S.Text(s, 12, "text", "medium")
  s.label:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 5)
  s.label:SetText((label:gsub("%s*:?%s*%%d", "")))
  s.value = S.Text(s, 12, "gold")
  s.value:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 5)

  s:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    self.value:SetText(value)
    onChange(value)
  end)
  s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d) end)
  return s
end

-- Progress bar -------------------------------------------------------------
-- gold gradient fill that eases to new values, gloss, glint on the leading edge,
-- and a shine sweeping over the fill every few seconds
function S.ProgressBar(parent, height)
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(height or 12)
  S.Box(bar, { 0.02, 0.016, 0.012, 1 }, C.trim)
  bar.min, bar.max, bar.value = 0, 1, 0

  local fill = bar:CreateTexture(nil, "ARTWORK", nil, 0)
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", 1, 1)
  gradient(fill, C.gold1, C.gold2)
  fill:SetWidth(0.01)

  local gloss = bar:CreateTexture(nil, "ARTWORK", nil, 3)
  gloss:SetPoint("TOPLEFT", fill); gloss:SetPoint("BOTTOMRIGHT", fill)
  gloss:SetTexture(MEDIA .. "Gloss")

  local glint = bar:CreateTexture(nil, "OVERLAY", nil, 1)
  glint:SetSize(3, (height or 12) + 4)
  glint:SetPoint("CENTER", fill, "RIGHT")
  glint:SetColorTexture(1, 0.97, 0.8, 1)
  local halo = bar:CreateTexture(nil, "OVERLAY", nil, 0)
  halo:SetTexture(MEDIA .. "Glow")
  halo:SetBlendMode("ADD")
  halo:SetSize(36, 36)
  halo:SetPoint("CENTER", glint)
  halo:SetVertexColor(1, 0.85, 0.3, 0.7)

  -- shine: clipped to the fill
  local clip = CreateFrame("Frame", nil, bar)
  clip:SetPoint("TOPLEFT", fill); clip:SetPoint("BOTTOMRIGHT", fill)
  local canClip = clip.SetClipsChildren and pcall(clip.SetClipsChildren, clip, true)
  local shine = clip:CreateTexture(nil, "OVERLAY")
  shine:SetTexture(MEDIA .. "Shine")
  shine:SetBlendMode("ADD")
  shine:SetSize(60, height or 12)
  shine:SetVertexColor(1, 0.95, 0.75, 0.55)
  shine:Hide()

  local inner = function() return math.max(0, bar:GetWidth() - 2) end
  local shown = 0 -- displayed fraction
  local function place(frac)
    shown = frac
    local w = inner() * frac
    fill:SetWidth(math.max(0.01, w))
    fill:SetShown(w > 0.5)
    glint:SetShown(w > 0.5 and frac < 1)
    halo:SetShown(w > 0.5 and frac < 1)
  end

  function bar:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
  function bar:SetValue(v)
    self.value = v
    local to = (self.max > self.min) and math.max(0, math.min(1, (v - self.min) / (self.max - self.min))) or 0
    if not self:IsVisible() then place(to) return end
    S.Tween(fill, { dur = 0.7, from = shown, to = to, ease = "outCubic", set = place })
  end
  bar:SetScript("OnSizeChanged", function() place(shown) end)

  -- idle: glint pulse + shine sweep
  local clock, nextSweep = 0, 1.5
  bar:SetScript("OnUpdate", function(_, elapsed)
    clock = clock + elapsed
    halo:SetAlpha(0.55 + 0.35 * math.sin(clock * 3))
    if not canClip then return end
    local w = inner() * shown
    if clock >= nextSweep and w > 20 then
      local t = clock - nextSweep
      local x = -60 + (w + 120) * (t / 1.1)
      if t >= 1.1 then
        shine:Hide()
        nextSweep = clock + 4
      else
        shine:Show()
        shine:SetPoint("LEFT", clip, "LEFT", x, 0)
      end
    end
  end)
  return bar
end

-- Scroll frame with a thin bar ---------------------------------------------
-- returns the scroll frame and its content (the caller sets the content width); smooth wheel
function S.Scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(1, 1)
  sf:SetScrollChild(content)

  local bar = CreateFrame("Slider", nil, parent)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(4)
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, -2)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 2)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0, 0, 0, 0.5)
  local thumb = bar:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(WHITE)
  thumb:SetSize(4, 30)
  thumb:SetVertexColor(color(C.trim))
  bar:SetThumbTexture(thumb)
  bar:SetMinMaxValues(0, 0)
  bar:SetValue(0)
  bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
  bar:SetScript("OnEnter", function() thumb:SetVertexColor(color(C.gold)) end)
  bar:SetScript("OnLeave", function() thumb:SetVertexColor(color(C.trim)) end)

  sf:SetScript("OnScrollRangeChanged", function(self)
    local range = self:GetVerticalScrollRange()
    local h = self:GetHeight()
    bar:SetMinMaxValues(0, range)
    bar:SetShown(range > 0)
    if h > 0 then thumb:SetHeight(math.max(20, h * h / (h + range))) end
    if bar:GetValue() > range then bar:SetValue(range) end
  end)
  sf:EnableMouseWheel(true)
  local target = 0
  sf:SetScript("OnMouseWheel", function(_, d)
    local _, hi = bar:GetMinMaxValues()
    target = math.max(0, math.min(hi, (tweens[bar] and target or bar:GetValue()) - d * 60))
    S.Tween(bar, { dur = 0.25, from = bar:GetValue(), to = target, set = function(v) bar:SetValue(v) end })
  end)
  bar:Hide()
  sf.bar = bar
  return sf, content
end
