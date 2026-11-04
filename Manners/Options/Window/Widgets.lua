-- Manners -- options window: the controls, one row per definition.
--
-- W.Build(kind, parent, item) makes the row for one control or note of the
-- model (Options/*.lua, reached through ns.WindowBind) and hands back
-- { frame, Layout, Refresh, NaturalWidth, Focus, Flash }. The window anchors
-- the frame and decides where it goes; a row only lays out what is inside it,
-- at the width it is given, and says how tall that made it. A row with a
-- control also notes how far down it the control starts and how tall that is
-- (row.fieldTop, row.fieldHeight), so the window can line two up side by side.
--
-- Every row is plain frames: Frame, Button, EditBox, Slider and ScrollFrame,
-- borders of four textures, text in explicit font strings. No templates, no
-- CheckButton, no UIDropDownMenu (it taints on this client) and no Backdrop,
-- so the game, the test client and the renderer draw the same thing.
--
-- This file holds the theme, the shared pieces, the window's own Button and
-- confirm box, and the plain kinds; WidgetsChoice.lua and WidgetsEntry.lua add
-- the rest to W.KIND.

local _, ns = ...

local W = {}
ns.WindowWidgets = W

-- kind -> { Build, Layout, Refresh, Natural, Focus }, each a function of the row.
local KIND = {}
W.KIND = KIND

local WHITE = "Interface\\Buttons\\WHITE8X8"

---------------------------------------------------------------------------
-- the theme, shared with Window.lua
---------------------------------------------------------------------------

-- Colours from the approved mockup: a dark panel, gold headings over a thin
-- gold rule, off-white labels, grey hints, red warnings, and the game's own
-- red buttons with gold words.
local T = {
	WHITE = WHITE,
	gold = { 1, 0.82, 0 },
	goldSoft = { 0.902, 0.769, 0.369 },
	rule = { 1, 0.82, 0, 0.42 },
	ink = { 0.922, 0.902, 0.855 },
	inkSoft = { 0.788, 0.765, 0.710 },
	hint = { 0.557, 0.545, 0.518 },
	-- Greyed-out words: as light as keeps 4.5:1 on the panel, the floor the
	-- window holds all its text to.
	dim = { 0.52, 0.509, 0.481 },
	white = { 1, 1, 1 },
	red = { 1, 0.502, 0.502 },
	green = { 0.502, 0.878, 0.502 },
	dot = { 1, 0.29, 0.227 },
	panel = { 0.059, 0.059, 0.075, 0.97 },
	head1 = { 0.118, 0.110, 0.133 },
	head2 = { 0.071, 0.067, 0.086 },
	side = { 0.078, 0.078, 0.094 },
	content = { 0.051, 0.051, 0.067 },
	edge = { 0.302, 0.255, 0.173 },
	edgeHi = { 0.541, 0.424, 0.227 },
	line = { 1, 1, 1, 0.09 },
	line2 = { 1, 1, 1, 0.05 },
	hover = { 1, 1, 1, 0.09 },
	strip = { 1, 0.82, 0, 0.055 },
	field = { 0.024, 0.024, 0.031 },
	fieldEdge = { 0.239, 0.235, 0.271 },
	fieldHi = { 0.431, 0.424, 0.478 },
	fieldOff = { 0.165, 0.165, 0.188 },
	boxTop = { 0.078, 0.078, 0.094 },
	boxEdge = { 0.435, 0.384, 0.286 },
	boxOff = { 0.231, 0.224, 0.204 },
	btnTop = { 0.525, 0.102, 0.067 },
	btnBottom = { 0.263, 0.035, 0.020 },
	btnEdge = { 0.114, 0.016, 0.008 },
	btnOffTop = { 0.16, 0.158, 0.158 },
	btnOffBottom = { 0.1, 0.098, 0.098 },
	btnOffInk = { 0.6, 0.588, 0.561 },
	shine = { 1, 1, 1, 0.17 },
	trackTop = { 0.020, 0.020, 0.024 },
	trackBottom = { 0.090, 0.090, 0.110 },
	trackEdge = { 0.243, 0.227, 0.196 },
	thumbTop = { 0.965, 0.867, 0.565 },
	thumbBottom = { 0.431, 0.329, 0.094 },
	thumbOffTop = { 0.467, 0.459, 0.435 },
	thumbOffBottom = { 0.271, 0.263, 0.247 },
	modal = { 0.051, 0.051, 0.071 },
	backdrop = { 0, 0, 0, 0.55 },
	flash = { 1, 0.82, 0, 0.24 },
	remove = { 0.851, 0.475, 0.424 },
	-- A note drawn as a block: a faint well with a grey rule down its left.
	well = { 1, 1, 1, 0.03 },
	wellRule = { 0.227, 0.227, 0.251 },
	-- A box's scroll bar, as the content's: a faint track, a dark gold thumb.
	barTrack = { 1, 1, 1, 0.05 },
	barThumb = { 0.29, 0.25, 0.188 },
	-- Font objects by name, asked for when used: the client has them all.
	fonts = {
		normal = "GameFontNormal", large = "GameFontNormalLarge", normalSmall = "GameFontNormalSmall",
		label = "GameFontHighlight", small = "GameFontHighlightSmall",
		disabled = "GameFontDisable", disabledSmall = "GameFontDisableSmall",
	},
	-- Sizes the window draws at outside the font objects: a section title is
	-- Friz Quadrata 13.
	headerSize = 13,
}
W.Theme = T

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

local function Colour(region, c, alpha)
	region:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1)
end
W.Colour = Colour

local function TextColour(fs, c)
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end
W.TextColour = TextColour

-- A flat rectangle in one colour, which the caller anchors.
function W.Solid(parent, layer, sublevel, c)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	t:SetTexture(WHITE)
	if c then Colour(t, c) end
	return t
end

-- A two-colour gradient, min at the bottom or left. SetGradient's signature
-- changed between client generations, so a refusal falls back to the flat
-- colour of `max` (Prompt/Prompt.lua's Gradient does the same).
function W.Gradient(tex, orientation, min, max)
	tex:SetTexture(WHITE)
	if tex.SetGradient and CreateColor and pcall(tex.SetGradient, tex, orientation,
		CreateColor(min[1], min[2], min[3], min[4] or 1), CreateColor(max[1], max[2], max[3], max[4] or 1)) then
		return
	end
	Colour(tex, max)
end

-- A one-pixel border of four textures, inside the frame's edge.
function W.Border(frame, c, layer)
	local e = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = W.Solid(frame, layer or "BORDER", 1, c)
		if i <= 2 then
			t:SetPoint(side .. "LEFT", frame, side .. "LEFT", 0, 0)
			t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", 0, 0)
			t:SetHeight(1)
		else
			t:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, 0)
			t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 0)
			t:SetWidth(1)
		end
		e[i] = t
	end
	return e
end

function W.BorderColour(edges, c)
	for _, t in ipairs(edges) do Colour(t, c) end
end

-- The dark well a dropdown, a box or a list sits in.
function W.Field(frame)
	local fill = W.Solid(frame, "BACKGROUND", -2, T.field)
	fill:SetAllPoints(frame)
	return { fill = fill, edges = W.Border(frame, T.fieldEdge) }
end

-- "hover", "focus", "off", or nil for at rest.
function W.FieldLook(field, state)
	local c = T.fieldEdge
	if state == "hover" or state == "focus" then c = T.fieldHi elseif state == "off" then c = T.fieldOff end
	W.BorderColour(field.edges, c)
end

function W.FontPath()
	local obj = _G[T.fonts.normal]
	local path = obj and obj.GetFont and obj:GetFont()
	return path or STANDARD_TEXT_FONT
end

local FALLBACK_SIZE = { GameFontNormalLarge = 16, GameFontHighlightSmall = 10, GameFontDisableSmall = 10,
	GameFontNormalSmall = 10 }

function W.SetFont(fs, font)
	local obj = _G[font]
	if obj and fs.SetFontObject then
		fs:SetFontObject(obj)
	else
		fs:SetFont(STANDARD_TEXT_FONT, FALLBACK_SIZE[font] or 12, "")
	end
end

-- A font string in a font object and a colour said out loud, hung by its
-- top-left corner: the client's default colour is not the window's.
function W.Text(parent, font, c, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	W.SetFont(fs, font or T.fonts.label)
	fs:SetJustifyH("LEFT")
	if fs.SetJustifyV then fs:SetJustifyV("TOP") end
	TextColour(fs, c or T.ink)
	return fs
end

-- Wrapped at its width between words, and inside a word too wide for it: a
-- line of Chinese has no spaces to break at, and would be cut short.
function W.Wrapping(fs)
	fs:SetWordWrap(true)
	if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(true) end
	return fs
end

-- The unbounded width of a string's text, or an estimate where the client
-- will not say.
function W.Measure(fs)
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	local w = measure and ns.plain(measure(fs))
	if type(w) == "number" and w == w then return w end
	return #tostring(fs:GetText() or "") * 6
end

function W.TextHeight(fs)
	if (fs:GetText() or "") == "" then return 0 end
	local h = fs.GetStringHeight and ns.plain(fs:GetStringHeight())
	if type(h) == "number" and h == h then return h end
	return 12
end

-- A label above a control: wrapped to the width, nothing when empty.
-- Answers its height.
function W.PlaceLabel(fs, parent, width)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	fs:SetWidth(width)
	local h = W.TextHeight(fs)
	if h <= 0 then
		fs:Hide()
		return 0
	end
	fs:Show()
	return math.ceil(h) + 3
end

-- Text with leading and trailing blank lines dropped: AceConfig spaced its
-- notes with "\n", and the window spaces its rows itself. ASCII white space
-- only: %s follows the C library's locale, and under a Western one takes
-- 0xA0, the last byte of "à" and of the Chinese "加".
function W.Trim(s)
	return (tostring(s or ""):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

---------------------------------------------------------------------------
-- reading the model
---------------------------------------------------------------------------

local function Bind() return ns.WindowBind end

function W.Name(row)
	if not row.item.def then return row.item.title or "" end
	return Bind().Text(row.item, "name") or ""
end

-- Asked at the moment of a click as well as on a repaint, since the model
-- can change in between (a fight starting, a list emptied from chat).
function W.Off(row)
	return row.item.def ~= nil and Bind().Disabled(row.item) == true
end

local function Hold(row, on)
	local ctx = row.ctx
	if ctx and ctx.OnHold then ctx.OnHold(on) end
end
W.Hold = Hold

-- Asks the window to lay the page out again, after a row changed height by
-- itself (an error under a box, a name added to a list). The window's
-- ctx.Relayout where there is one; the row on its own otherwise.
function W.Relayout(row)
	while row.parentRow do row = row.parentRow end
	local ctx = row.ctx
	if ctx and ctx.Relayout then
		ctx.Relayout(row)
	elseif row.width then
		row:Layout(row.width)
	end
end

---------------------------------------------------------------------------
-- committing, and the confirm box
---------------------------------------------------------------------------

-- The row whose commit is under way, handed to any confirm it opens, so the
-- box can put that row right once it is answered; and the box asking now.
local pending, asking
local MODAL_WIDTH = 380

function W.Commit(row, ...)
	pending = row
	local ok, msg = Bind().Commit(row.item, ...)
	pending = nil
	return ok, msg
end

-- Whether this row's change is waiting on the confirm box.
function W.Waiting(row)
	return asking ~= nil and asking.row == row
end

function W.Asking()
	return asking
end

-- The row the window placed: a part of the never-offer list repaints the
-- whole list, since adding a name adds a line to it.
local function Outer(row)
	while row.parentRow do row = row.parentRow end
	return row
end

-- Repainted now, unless a confirm will repaint it once answered.
function W.Settle(row)
	if not W.Waiting(row) then Outer(row):Refresh() end
end

function W.Run(row)
	pending = row
	Bind().Run(row.item)
	pending = nil
	W.Settle(row)
end

function W.Apply(row, ...)
	local ok, msg = W.Commit(row, ...)
	W.Settle(row)
	return ok, msg
end

local function Answer(m, yes)
	if m.answered then return end
	m.answered = true
	if asking == m then asking = nil end
	local fn = yes and m.onYes or m.onNo
	local row = m.row
	m.onYes, m.onNo, m.row = nil, nil, nil
	m:Hide()
	if fn then fn() end
	if row then Outer(row):Refresh() end
end

local function AnswerYes(button) Answer(button.modal, true) end
local function AnswerNo(button) Answer(button.modal, false) end

local modals = setmetatable({}, { __mode = "k" })

local function BuildModal(parent)
	local m = CreateFrame("Frame", nil, parent)
	m:SetAllPoints(parent)
	m:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 50)
	-- Takes the clicks meant for the window under it while it asks.
	m:EnableMouse(true)
	W.Solid(m, "BACKGROUND", -8, T.backdrop):SetAllPoints(m)
	local box = CreateFrame("Frame", nil, m)
	box:SetPoint("CENTER", m, "CENTER", 0, 0)
	W.Solid(box, "BACKGROUND", -7, T.modal):SetAllPoints(box)
	W.Border(box, T.edgeHi)
	m.box = box
	m.text = W.Wrapping(W.Text(box, T.fonts.label, T.ink))
	if m.text.SetSpacing then m.text:SetSpacing(2) end
	m.text:SetJustifyH("CENTER")
	m.text:SetPoint("TOP", box, "TOP", 0, -16)
	m.text:SetWidth(MODAL_WIDTH - 36)
	m.yes = W.Button(box, YES, AnswerYes)
	m.no = W.Button(box, NO, AnswerNo)
	m.yes.modal, m.no.modal = m, m
	m.answered = true
	m:Hide()
	-- Shut with the window (Escape) is a No.
	m:SetScript("OnHide", function(self) ns.Guard("options confirm", Answer, self, false) end)
	return m
end

-- The confirm, over `parent` (the window): text, and YES and NO. Asking again
-- while one is open answers the first one No.
function W.Modal(parent, text, onYes, onNo)
	parent = parent or UIParent
	if asking then Answer(asking, false) end
	local m = modals[parent]
	if not m then
		m = BuildModal(parent)
		modals[parent] = m
	end
	m.answered, m.onYes, m.onNo, m.row = false, onYes, onNo, pending
	m.text:SetText(text or "")
	local width = math.max(90, W.ButtonLabel(m.yes, YES, 24), W.ButtonLabel(m.no, NO, 24))
	m.yes:SetWidth(width)
	m.no:SetWidth(width)
	m.yes:ClearAllPoints()
	m.yes:SetPoint("BOTTOMRIGHT", m.box, "BOTTOM", -6, 14)
	m.no:ClearAllPoints()
	m.no:SetPoint("BOTTOMLEFT", m.box, "BOTTOM", 6, 14)
	m.box:SetSize(MODAL_WIDTH, 16 + math.ceil(W.TextHeight(m.text)) + 16 + 24 + 14)
	asking = m
	m:Show()
	if m.Raise then m:Raise() end
	return m
end

---------------------------------------------------------------------------
-- the window's button
---------------------------------------------------------------------------

local function ButtonLook(b)
	local on = b:IsEnabled() and true or false
	W.Gradient(b.face, "VERTICAL", on and T.btnBottom or T.btnOffBottom, on and T.btnTop or T.btnOffTop)
	TextColour(b.label, on and T.gold or T.btnOffInk)
end

local function ButtonClicked(b, mouse)
	if b.onClick then b.onClick(b, mouse) end
end

-- The label, and the width it needs: the words and 12 either side. Answers
-- the width.
function W.ButtonLabel(b, label, height)
	b.label:SetText(label or "")
	if height then b.height = height end
	local w = math.max(b.minWidth or 60, math.ceil(W.Measure(b.label)) + 24)
	b:SetSize(w, b.height or 22)
	return w
end

-- A red button with gold words, as the game draws its own, sized to its
-- label. onClick(button, mouseButton) runs inside ns.Guard.
function W.Button(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:RegisterForClicks("LeftButtonUp")
	b.face = W.Solid(b, "BACKGROUND", 1)
	b.face:SetAllPoints(b)
	b.edges = W.Border(b, T.btnEdge)
	local shine = W.Solid(b, "BORDER", 2, T.shine)
	shine:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	shine:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, -1)
	shine:SetHeight(1)
	-- The HIGHLIGHT layer shows only under the mouse.
	W.Solid(b, "HIGHLIGHT", nil, { 1, 1, 1, 0.1 }):SetAllPoints(b)
	b.label = W.Text(b, T.fonts.normal, T.gold)
	b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.label:SetJustifyH("CENTER")
	b.label:SetWordWrap(false)
	b.onClick = onClick
	b:SetScript("OnClick", function(self, mouse) ns.Guard("options button", ButtonClicked, self, mouse) end)
	b:SetScript("OnEnable", function(self) ns.Guard("options button", ButtonLook, self) end)
	b:SetScript("OnDisable", function(self) ns.Guard("options button", ButtonLook, self) end)
	W.ButtonLabel(b, label)
	ButtonLook(b)
	return b
end

---------------------------------------------------------------------------
-- tooltips
---------------------------------------------------------------------------

-- The control's name in gold and its desc under it, where it has one.
local function TipShow(owner)
	local row = owner.row
	if not (row and row.item and row.item.def) then return end
	local desc = Bind().Text(row.item, "desc")
	if not desc or desc == "" then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local name = W.Trim(Bind().Text(row.item, "name"))
	if name ~= "" then GameTooltip:AddLine(name, T.gold[1], T.gold[2], T.gold[3]) end
	GameTooltip:AddLine(desc, 1, 1, 1, true)
	GameTooltip:Show()
end

local function TipEnter(owner)
	if owner.hover then owner.hover(owner, true) end
	TipShow(owner)
end

local function TipLeave(owner)
	if owner.hover then owner.hover(owner, false) end
	GameTooltip:Hide()
end

-- The row's tooltip on `frame`; `hover(frame, on)` also runs, for a field
-- that lights its border under the mouse.
function W.Tip(frame, row, hover)
	frame.row, frame.hover = row, hover
	frame:SetScript("OnEnter", function(self) ns.Guard("options tooltip", TipEnter, self) end)
	frame:SetScript("OnLeave", function(self) ns.Guard("options tooltip", TipLeave, self) end)
end

---------------------------------------------------------------------------
-- the row
---------------------------------------------------------------------------

local Row = {}
Row.__index = Row

function Row.Layout(row, width)
	width = math.max(1, math.floor(width or row.width or 1))
	local h = math.ceil(KIND[row.kind].Layout(row, width) or 0)
	row.width, row.height = width, h
	row.frame:SetSize(width, math.max(h, 1))
	return h
end

function Row.Refresh(row)
	row.off = W.Off(row)
	KIND[row.kind].Refresh(row)
end

function Row.NaturalWidth(row)
	local fn = KIND[row.kind].Natural
	return math.ceil(fn and fn(row) or 0)
end

function Row.Focus(row)
	local fn = KIND[row.kind].Focus
	if fn then fn(row) end
end

-- A gold wash over the row, fading out over 0.6 s: where search landed.
local FLASH_SECONDS = 0.6

local function FlashStep(frame, elapsed)
	local row = frame.row
	row.flashLeft = row.flashLeft - (tonumber(elapsed) or 0)
	if row.flashLeft <= 0 then
		row.flash:Hide()
		frame:SetScript("OnUpdate", nil)
		return
	end
	row.flash:SetAlpha(row.flashLeft / FLASH_SECONDS)
end

local function FlashUpdate(frame, elapsed)
	ns.Guard("options flash", FlashStep, frame, elapsed)
end

function Row.Flash(row)
	if not row.flash then
		row.flash = W.Solid(row.frame, "BACKGROUND", -8, T.flash)
		row.flash:SetPoint("TOPLEFT", row.frame, "TOPLEFT", -4, 3)
		row.flash:SetPoint("BOTTOMRIGHT", row.frame, "BOTTOMRIGHT", 4, -3)
	end
	row.flashLeft = FLASH_SECONDS
	row.flash:SetAlpha(1)
	row.flash:Show()
	row.frame:SetScript("OnUpdate", FlashUpdate)
end

-- One row for `item`, of `kind` -- the model type, or the layout's widget
-- ("number") or composite ("never"). Built, then read from the model once;
-- the window calls Layout before showing it.
function W.Build(kind, parent, item)
	local k = KIND[kind]
	if not k then error("no widget of kind " .. tostring(kind), 2) end
	item = item or {}
	local frame = CreateFrame("Frame", nil, parent)
	local row = setmetatable({ frame = frame, kind = kind, item = item, ctx = item.ctx or {} }, Row)
	frame.row = row
	k.Build(row)
	row:Refresh()
	return row
end

---------------------------------------------------------------------------
-- the plain kinds
---------------------------------------------------------------------------

-- description: wrapping text, colour codes kept. fontSize "medium" is
-- GameFontHighlight, anything else GameFontHighlightSmall; a page's lead is a
-- size up from that. The layout's `hint` draws it grey rather than in the
-- label colour (a colour code in the text still wins), and `block` in a faint
-- well with a rule down its left, the text inset.
local BLOCK_X, BLOCK_Y = 11, 6

local function NoteFont(row)
	local def = row.item.def or {}
	local size = def.fontSize
	if type(size) == "function" then size = size(row.item.info) end
	local font = size == "medium" and T.fonts.label or T.fonts.small
	local layout = row.item.layout or {}
	local key = font .. (layout.lead and "+" or "") .. (layout.hint and "~" or "")
	if row.fontKey == key then return end
	row.fontKey = key
	W.SetFont(row.text, font)
	if layout.lead then
		local path, px, flags = row.text:GetFont()
		if path then row.text:SetFont(path, (px or 12) + 2, flags or "") end
	end
	TextColour(row.text, layout.hint and T.hint or T.ink)
end

KIND.description = {
	Build = function(row)
		local block = (row.item.layout or {}).block
		local fs = W.Wrapping(W.Text(row.frame, T.fonts.small, T.ink))
		fs:SetPoint("TOPLEFT", row.frame, "TOPLEFT", block and BLOCK_X or 0, block and -BLOCK_Y or 0)
		if fs.SetSpacing then fs:SetSpacing(2) end
		row.text = fs
		if block then
			row.well = W.Solid(row.frame, "BACKGROUND", -1, T.well)
			row.well:SetAllPoints(row.frame)
			row.wellRule = W.Solid(row.frame, "BORDER", 1, T.wellRule)
			row.wellRule:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
			row.wellRule:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMLEFT", 0, 0)
			row.wellRule:SetWidth(2)
		end
	end,
	Refresh = function(row)
		NoteFont(row)
		row.text:SetText(W.Trim(W.Name(row)))
	end,
	Layout = function(row, width)
		if not row.well then
			row.text:SetWidth(width)
			return W.TextHeight(row.text)
		end
		row.text:SetWidth(math.max(1, width - BLOCK_X - 9))
		return math.ceil(W.TextHeight(row.text)) + 2 * BLOCK_Y
	end,
	Natural = function(row) return W.Measure(row.text) + (row.well and BLOCK_X + 9 or 0) end,
}

-- header: a section title in gold Friz Quadrata 13, with a thin gold rule
-- running on from it to the right edge, fading out. The window's own
-- section titles pass { title = text } instead of a model header.
KIND.header = {
	Build = function(row)
		local fs = W.Text(row.frame, T.fonts.normal, T.gold)
		fs:SetFont(W.FontPath(), T.headerSize, "")
		TextColour(fs, T.gold)
		fs:SetWordWrap(false)
		row.text = fs
		row.rule = W.Solid(row.frame, "ARTWORK")
		row.rule:SetHeight(1)
		W.Gradient(row.rule, "HORIZONTAL", T.rule, { T.gold[1], T.gold[2], T.gold[3], 0 })
	end,
	Refresh = function(row)
		row.text:SetText(W.Trim(W.Name(row)))
	end,
	Layout = function(row, width)
		local fs = row.text
		local w = math.min(math.ceil(W.Measure(fs)) + 2, width)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -4)
		fs:SetWidth(w)
		row.rule:ClearAllPoints()
		row.rule:SetPoint("LEFT", row.frame, "TOPLEFT", math.min(w + 10, width), -11)
		row.rule:SetPoint("RIGHT", row.frame, "TOPRIGHT", 0, -11)
		return 21
	end,
	Natural = function(row) return W.Measure(row.text) + 40 end,
}

-- execute: a button sized to its label, which may change (Show my settings as
-- text / Hide the text), through the definition's confirm.
local function ExecuteClicked(b)
	local row = b.row
	if W.Off(row) then return end
	W.Run(row)
end

-- The layout's `big` is a button that leads a page: taller, in the large font,
-- and not narrower than a short word makes it.
local BIG_HEIGHT, BIG_MIN_WIDTH = 34, 190

KIND.execute = {
	Build = function(row)
		local big = (row.item.layout or {}).big
		local b = W.Button(row.frame, "", ExecuteClicked)
		b.height = big and BIG_HEIGHT or 24
		if big then
			b.minWidth = BIG_MIN_WIDTH
			W.SetFont(b.label, T.fonts.large)
		end
		b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
		W.Tip(b, row)
		row.button = b
	end,
	Refresh = function(row)
		W.ButtonLabel(row.button, W.Trim(W.Name(row)))
		row.button:SetEnabled(not row.off)
	end,
	Layout = function(row, width)
		local w = W.ButtonLabel(row.button, row.button.label:GetText())
		if w > width then row.button:SetWidth(width) end
		row.fieldTop, row.fieldHeight = 0, row.button.height or 24
		return row.button.height or 24
	end,
	Natural = function(row) return row.button:GetWidth() end,
}

-- toggle: an 18 px box with the game's gold check, the label to its right,
-- wrapping when long. The box and the label are one click target.
function W.CheckBox(parent)
	local box = CreateFrame("Frame", nil, parent)
	box:SetSize(18, 18)
	local fill = W.Solid(box, "BACKGROUND", 1)
	fill:SetAllPoints(box)
	W.Gradient(fill, "VERTICAL", T.field, T.boxTop)
	box.edges = W.Border(box, T.boxEdge)
	box.check = box:CreateTexture(nil, "ARTWORK")
	box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	box.check:SetSize(24, 24)
	box.check:SetPoint("CENTER", box, "CENTER", 1, 0)
	return box
end

function W.CheckLook(box, on, off)
	box.check:SetShown(on and true or false)
	box.check:SetDesaturated(off and true or false)
	box.check:SetAlpha(off and 0.55 or 1)
	W.BorderColour(box.edges, off and T.boxOff or T.boxEdge)
end

local function ToggleClicked(hit)
	local row = hit.row
	if W.Off(row) then return end
	W.Apply(row, not (Bind().Value(row.item) == true))
end

KIND.toggle = {
	Build = function(row)
		local hit = CreateFrame("Button", nil, row.frame)
		hit:RegisterForClicks("LeftButtonUp")
		hit:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
		row.box = W.CheckBox(hit)
		row.box:SetPoint("TOPLEFT", hit, "TOPLEFT", 0, 0)
		local fs = W.Wrapping(W.Text(hit, T.fonts.label, T.ink))
		fs:SetPoint("TOPLEFT", hit, "TOPLEFT", 25, -2)
		row.label = fs
		hit:SetScript("OnClick", function(self) ns.Guard("options toggle", ToggleClicked, self) end)
		W.Tip(hit, row)
		row.hit = hit
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		W.CheckLook(row.box, Bind().Value(row.item) == true, row.off)
		row.hit:SetEnabled(not row.off)
	end,
	Layout = function(row, width)
		local room = math.max(1, width - 25)
		row.label:SetWidth(room)
		local h = math.max(18, math.ceil(W.TextHeight(row.label)) + 3)
		row.hit:SetSize(25 + math.min(room, math.ceil(W.Measure(row.label))), h)
		row.fieldTop, row.fieldHeight = 0, 18
		return h
	end,
	Natural = function(row) return 25 + W.Measure(row.label) end,
}
