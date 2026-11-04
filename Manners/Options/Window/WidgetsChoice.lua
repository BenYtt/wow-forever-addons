-- Manners -- options window: the controls that pick from a set -- a dropdown,
-- a grid of checkboxes, a colour and a key. Added to the kinds Widgets.lua
-- started; see there for what a row is.

local _, ns = ...
local W = ns.WindowWidgets
local T, KIND = W.Theme, W.KIND
local TextColour = W.TextColour

local function Bind() return ns.WindowBind end

---------------------------------------------------------------------------
-- select: the label above a field showing the current choice and a chevron;
-- a click opens the client's menu with one radio per value.
---------------------------------------------------------------------------

-- Asked while the menu draws, where a throw takes the whole menu with it.
local function IsChosen(row, key)
	local ok, now = pcall(Bind().Value, row.item)
	return ok and now ~= nil and now == key
end

-- The chosen one is committed again too: a set shown as chosen (Line set) is
-- picked again to reload it, through its confirm.
local function Pick(row, key)
	if W.Off(row) then return end
	W.Apply(row, key)
end

-- The menu is kept on the screen but never scrolls by itself, so a long list
-- (every sound or font a media pack registers, many profiles) would run past
-- the edge out of reach: past twenty entries' height it scrolls. A shorter
-- one is drawn as before.
local MENU_HEIGHT = 20 * 20

local function FillMenu(row, root, values)
	local isSelected = function(key) return IsChosen(row, key) end
	local setSelected = function(key) ns.Guard("options menu", Pick, row, key) end
	if root.SetScrollMode then root:SetScrollMode(MENU_HEIGHT) end
	for _, v in ipairs(values) do
		root:CreateRadio(v[2], isSelected, setSelected, v[1])
	end
end

-- A client without the menu gets the next choice along, so the control still
-- works.
local function Cycle(row, values)
	if #values == 0 then return end
	local now, key = Bind().Value(row.item), values[1][1]
	for i, v in ipairs(values) do
		if v[1] == now then
			key = values[i % #values + 1][1]
			break
		end
	end
	Pick(row, key)
end

local function SelectClicked(field)
	local row = field.row
	if W.Off(row) then return end
	local values = Bind().Values(row.item)
	if type(MenuUtil) ~= "table" or type(MenuUtil.CreateContextMenu) ~= "function" then
		Cycle(row, values)
		return
	end
	MenuUtil.CreateContextMenu(field, function(_, root)
		ns.Guard("options menu", FillMenu, row, root, values)
	end)
end

local function FieldHover(field, on)
	if field.row.off then return end
	W.FieldLook(field.look, on and "hover" or nil)
end

local function ChoiceLabel(row)
	local now = Bind().Value(row.item)
	for _, v in ipairs(row.values or {}) do
		if v[1] == now then return v[2] end
	end
	return ""
end

local function Widest(row)
	local w = 0
	for _, v in ipairs(row.values or {}) do
		row.measure:SetText(v[2])
		w = math.max(w, W.Measure(row.measure))
	end
	return w
end

KIND.select = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		local field = CreateFrame("Button", nil, row.frame)
		field:RegisterForClicks("LeftButtonUp")
		field:SetHeight(24)
		field.look = W.Field(field)
		local value = W.Text(field, T.fonts.small, T.ink)
		value:SetPoint("LEFT", field, "LEFT", 9, 0)
		value:SetPoint("RIGHT", field, "RIGHT", -24, 0)
		value:SetWordWrap(false)
		local chevron = field:CreateTexture(nil, "ARTWORK")
		chevron:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
		chevron:SetSize(12, 12)
		chevron:SetPoint("RIGHT", field, "RIGHT", -7, -2)
		W.Colour(chevron, T.gold)
		field:SetScript("OnClick", function(self) ns.Guard("options menu", SelectClicked, self) end)
		W.Tip(field, row, FieldHover)
		row.field, row.value, row.chevron = field, value, chevron
		row.measure = W.Text(row.frame, T.fonts.small)
		row.measure:Hide()
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		row.values = Bind().Values(row.item)
		row.value:SetText(ChoiceLabel(row))
		TextColour(row.value, row.off and T.dim or T.ink)
		-- The tint is what colours the arrow, so greying it out takes the tint.
		row.chevron:SetDesaturated(row.off and true or false)
		W.Colour(row.chevron, row.off and T.dim or T.gold)
		W.FieldLook(row.field.look, row.off and "off" or nil)
		row.field:SetEnabled(not row.off)
	end,
	-- The field fills a narrow column (half of a pair) and takes about
	-- three-fifths of a wide one, never less than its longest choice needs.
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		local fw = width
		if width > 320 then fw = math.max(200, math.min(300, math.floor(width * 0.6))) end
		fw = math.min(width, math.max(fw, math.ceil(Widest(row)) + 40))
		row.field:ClearAllPoints()
		row.field:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -lh)
		row.field:SetWidth(fw)
		row.fieldTop, row.fieldHeight = lh, 24
		return lh + 24
	end,
	Natural = function(row) return math.max(W.Measure(row.label), Widest(row) + 40) end,
}

---------------------------------------------------------------------------
-- multiselect: a grid of checkboxes, in the layout's columns where they fit;
-- get(info, key) and set(info, key, on).
---------------------------------------------------------------------------

local function GridClicked(hit)
	local row = hit.row
	if W.Off(row) then return end
	W.Apply(row, hit.key, not (Bind().Value(row.item, hit.key) == true))
end

local function GridBox(row, i)
	local hit = CreateFrame("Button", nil, row.frame)
	hit:RegisterForClicks("LeftButtonUp")
	hit.box = W.CheckBox(hit)
	hit.box:SetPoint("TOPLEFT", hit, "TOPLEFT", 0, 0)
	hit.text = W.Text(hit, T.fonts.label, T.ink)
	hit.text:SetPoint("TOPLEFT", hit, "TOPLEFT", 25, -2)
	hit.text:SetWordWrap(false)
	hit:SetScript("OnClick", function(self) ns.Guard("options toggle", GridClicked, self) end)
	W.Tip(hit, row)
	row.boxes[i] = hit
	return hit
end

local function GridColumns(row, width)
	local n, widest = row.count or 0, 0
	for i = 1, n do widest = math.max(widest, W.Measure(row.boxes[i].text)) end
	local layout = row.item.layout or {}
	local cols = math.max(1, math.min(n, layout.columns or 4))
	while cols > 1 and math.floor(width / cols) < widest + 31 do cols = cols - 1 end
	return cols, widest
end

KIND.multiselect = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		row.boxes = {}
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		local values, was = Bind().Values(row.item), row.count
		for i, v in ipairs(values) do
			local hit = row.boxes[i] or GridBox(row, i)
			hit.key = v[1]
			hit.text:SetText(v[2])
			TextColour(hit.text, row.off and T.dim or T.ink)
			W.CheckLook(hit.box, Bind().Value(row.item, v[1]) == true, row.off)
			hit:SetEnabled(not row.off)
			hit:Show()
		end
		for i = #values + 1, #row.boxes do row.boxes[i]:Hide() end
		row.count = #values
		if was and was ~= row.count then W.Relayout(row) end
	end,
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		local cols = GridColumns(row, width)
		local colWidth = math.floor(width / cols)
		for i = 1, row.count or 0 do
			local hit = row.boxes[i]
			local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
			hit:ClearAllPoints()
			hit:SetPoint("TOPLEFT", row.frame, "TOPLEFT", c * colWidth, -(lh + r * 24))
			hit.text:SetWidth(math.max(1, colWidth - 31))
			hit:SetSize(math.min(colWidth - 6, 25 + math.ceil(W.Measure(hit.text))), 18)
		end
		local rows = math.ceil((row.count or 0) / cols)
		row.fieldTop, row.fieldHeight = lh, 18
		return lh + math.max(0, rows * 24 - 6)
	end,
	Natural = function(row)
		local cols, widest = GridColumns(row, math.huge)
		return math.max(W.Measure(row.label), cols * (widest + 31))
	end,
}

---------------------------------------------------------------------------
-- color: a swatch over a checkerboard, so a see-through colour shows as one,
-- opening the game's colour picker. Changes go to the model live; Cancel puts
-- back the colour it opened on. The window is told the picker is held open,
-- so it can fade for a look at the prompt.
---------------------------------------------------------------------------

-- Tileset\Generic\Checkers, with the corner AceGUI's colour swatch uses.
local CHECKERS = 188523

local picking, hookedPicker

local function HasAlpha(row)
	local h = row.item.def and row.item.def.hasAlpha
	if type(h) == "function" then h = h(row.item.info) end
	return h == true
end

-- The opacity slider of the classic family's picker (Classic Era, TBC, Mists)
-- is the old one behind the new API: its 0 is the "+" end, opaque, so its
-- value is transparency. Forever's and retail's answer the alpha itself.
-- Both ways are the same flip; the rounding keeps 1 - (1 - a) from drifting a
-- stored alpha by a float's last digit.
local function SliderAlpha(v)
	if type(v) ~= "number" or not (ns.Flavour and ns.Flavour.family == "classic") then return v end
	return math.floor((1 - v) * 10000 + 0.5) / 10000
end

local function PickerClosed()
	local row = picking
	picking = nil
	if row then W.Hold(row, false) end
end

-- Whether the game's colour picker is up for one of these swatches. The window
-- fades for as long as it is, which a slider or arrow let go of meanwhile
-- (the window keeps one flag for all holds) must not end.
function W.PickerUp()
	local picker = _G.ColorPickerFrame
	return picking ~= nil and type(picker) == "table" and picker.IsShown and picker:IsShown() and true or false
end

-- The client calls swatchFunc and then opacityFunc for every move of the
-- picker, so the second finds nothing new and is let go: one commit, one
-- repaint and one restyle a move.
local function Live(row)
	if picking ~= row or W.Off(row) then return end
	local r, g, b = ColorPickerFrame:GetColorRGB()
	local a = 1
	if HasAlpha(row) and ColorPickerFrame.GetColorAlpha then a = SliderAlpha(ColorPickerFrame:GetColorAlpha()) end
	local last = row.live
	if last[1] == r and last[2] == g and last[3] == b and last[4] == a then return end
	last[1], last[2], last[3], last[4] = r, g, b, a
	W.Apply(row, r, g, b, a)
end

local function Restore(row)
	local p = row.before
	if p then W.Apply(row, p[1], p[2], p[3], p[4]) end
end

local function OpenPicker(row, r, g, b, a)
	local live = function() ns.Guard("options colour", Live, row) end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r, g = g, b = b, opacity = SliderAlpha(a), hasOpacity = HasAlpha(row),
		swatchFunc = live, opacityFunc = live,
		cancelFunc = function() ns.Guard("options colour", Restore, row) end,
	})
end

local function SwatchClicked(hit)
	local row = hit.row
	local picker = ColorPickerFrame
	if W.Off(row) or type(picker) ~= "table" or type(picker.SetupColorPickerAndShow) ~= "function" then return end
	if hookedPicker ~= picker and picker.HookScript then
		hookedPicker = picker
		picker:HookScript("OnHide", function() ns.Guard("options colour", PickerClosed) end)
	end
	-- A picker still up for another swatch is not shown again, so the classic
	-- one would never run its OnShow and keep the first swatch's opacity
	-- slider: closed first, as AceGUI's swatch does.
	if picker.IsShown and picker:IsShown() and picker.Hide then picker:Hide() end
	if picking and picking ~= row then W.Hold(picking, false) end
	local r, g, b, a = Bind().Value(row.item)
	r, g, b, a = tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
	row.before, row.live = { r, g, b, a }, { r, g, b, a }
	picking = row
	W.Hold(row, true)
	OpenPicker(row, r, g, b, a)
end

local function Inset(region, frame, by)
	region:SetPoint("TOPLEFT", frame, "TOPLEFT", by, -by)
	region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -by, by)
end

KIND.color = {
	Build = function(row)
		local hit = CreateFrame("Button", nil, row.frame)
		hit:RegisterForClicks("LeftButtonUp")
		hit:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
		local swatch = CreateFrame("Frame", nil, hit)
		swatch:SetSize(24, 24)
		swatch:SetPoint("TOPLEFT", hit, "TOPLEFT", 0, 0)
		local checker = swatch:CreateTexture(nil, "BACKGROUND", nil, 1)
		checker:SetTexture(CHECKERS)
		checker:SetTexCoord(0.25, 0, 0.5, 0.25)
		checker:SetDesaturated(true)
		checker:SetVertexColor(1, 1, 1, 0.75)
		Inset(checker, swatch, 2)
		row.colour = W.Solid(swatch, "ARTWORK")
		Inset(row.colour, swatch, 2)
		swatch.edges = W.Border(swatch, T.boxEdge)
		local fs = W.Wrapping(W.Text(hit, T.fonts.label, T.ink))
		fs:SetPoint("TOPLEFT", hit, "TOPLEFT", 32, -5)
		hit:SetScript("OnClick", function(self) ns.Guard("options colour", SwatchClicked, self) end)
		W.Tip(hit, row)
		row.hit, row.swatch, row.label = hit, swatch, fs
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		local r, g, b, a = Bind().Value(row.item)
		row.colour:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1,
			(tonumber(a) or 1) * (row.off and 0.4 or 1))
		row.colour:SetDesaturated(row.off and true or false)
		W.BorderColour(row.swatch.edges, row.off and T.boxOff or T.boxEdge)
		row.hit:SetEnabled(not row.off)
	end,
	Layout = function(row, width)
		local room = math.max(1, width - 32)
		row.label:SetWidth(room)
		local h = math.max(24, math.ceil(W.TextHeight(row.label)) + 8)
		row.hit:SetSize(32 + math.min(room, math.ceil(W.Measure(row.label))), h)
		row.fieldTop, row.fieldHeight = 0, 24
		return h
	end,
	Natural = function(row) return 32 + W.Measure(row.label) end,
}

---------------------------------------------------------------------------
-- keybinding: a capture button. Click it, then press the key, a mouse button
-- other than the two that work it, or turn the wheel; Escape cancels, a
-- right-click clears it. Written through the definition's set
-- (Setup.SetKey), which refuses in a fight; the control is greyed out there
-- by its own disabled anyway.
---------------------------------------------------------------------------

local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true,
	RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }

-- The mouse buttons as the game spells them in a binding, as AceGUI's key
-- control took them.
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local capturing

local function KeyLook(row, hover)
	local c = T.fieldEdge
	if capturing == row then c = T.gold elseif row.off then c = T.fieldOff elseif hover then c = T.fieldHi end
	W.BorderColour(row.button.look.edges, c)
end

local function StopCapture(row)
	if not row or capturing ~= row then return end
	capturing = nil
	row.button:EnableKeyboard(false)
	row.button:EnableMouseWheel(false)
	KeyLook(row)
end

-- The keyboard and the wheel are the button's only while it waits, so
-- nothing else the player types is taken from the game, and the wheel
-- scrolls the page over it the rest of the time. A box with the focus (the
-- search box, clicked into just before) lets go of it first: the client hands
-- keys to the focused box ahead of any frame, and a click elsewhere does not
-- take its focus away.
local function StartCapture(row)
	if capturing and capturing ~= row then StopCapture(capturing) end
	local focused = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focused and focused.ClearFocus then focused:ClearFocus() end
	capturing = row
	row.button:EnableKeyboard(true)
	row.button:SetPropagateKeyboardInput(false)
	row.button:EnableMouseWheel(true)
	KeyLook(row)
end

-- The chord as the game spells a binding: ALT-, CTRL-, SHIFT- (and META- on
-- a Mac), in that order, before the key.
local function Chord(key)
	local prefix = ""
	if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
	if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
	if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
	if IsMetaKeyDown and IsMetaKeyDown() then prefix = prefix .. "META-" end
	return prefix .. key
end

-- The key, mouse button or turn of the wheel that ends a capture, bound with
-- the modifiers held.
local function Take(row, key)
	StopCapture(row)
	if W.Off(row) then return end
	W.Apply(row, Chord(key))
end

local function KeyPressed(button, key)
	local row = button.row
	if capturing ~= row then return end
	if key == "ESCAPE" then
		StopCapture(row)
		return
	end
	-- A modifier on its own is the start of a chord, not the key.
	if MODIFIER_KEYS[key] then return end
	Take(row, key)
end

local function KeyWheel(button, delta)
	local row = button.row
	if capturing ~= row then return end
	Take(row, (tonumber(delta) or 0) >= 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function KeyClicked(button, mouse)
	local row = button.row
	if W.Off(row) then
		StopCapture(row)
		return
	end
	-- The other mouse buttons are keys to bind, and only while one is waited
	-- for.
	if MOUSE_KEYS[mouse] then
		if capturing == row then Take(row, MOUSE_KEYS[mouse]) end
		return
	end
	if mouse == "RightButton" then
		StopCapture(row)
		W.Apply(row, "")
	elseif capturing == row then
		StopCapture(row)
	else
		StartCapture(row)
	end
end

local function KeyHover(button, on) KeyLook(button.row, on) end

local function KeyText(key)
	if type(key) ~= "string" or key == "" then return nil end
	if type(GetBindingText) == "function" then
		local text = GetBindingText(key)
		if type(text) == "string" and text ~= "" then return text end
	end
	return key
end

KIND.keybinding = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		local b = CreateFrame("Button", nil, row.frame)
		b:RegisterForClicks("AnyUp")
		b:SetHeight(24)
		b.look = W.Field(b)
		b.text = W.Text(b, T.fonts.label, T.white)
		b.text:SetPoint("LEFT", b, "LEFT", 8, 0)
		b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
		b.text:SetJustifyH("CENTER")
		b.text:SetWordWrap(false)
		b:SetScript("OnClick", function(self, mouse) ns.Guard("options key", KeyClicked, self, mouse) end)
		b:SetScript("OnKeyDown", function(self, key) ns.Guard("options key", KeyPressed, self, key) end)
		b:SetScript("OnMouseWheel", function(self, delta) ns.Guard("options key", KeyWheel, self, delta) end)
		b:SetScript("OnHide", function(self) ns.Guard("options key", StopCapture, self.row) end)
		W.Tip(b, row, KeyHover)
		row.button = b
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		-- A fight starting greys it out, and a button holding the keyboard
		-- must not go on holding it.
		if row.off then StopCapture(row) end
		local text = KeyText(Bind().Value(row.item))
		row.button.text:SetText(text or NOT_BOUND or "")
		TextColour(row.button.text, row.off and T.dim or (text and T.white or T.hint))
		row.button:SetEnabled(not row.off)
		KeyLook(row)
	end,
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		local b = row.button
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -lh)
		b:SetWidth(math.min(width, math.max(150, math.ceil(W.Measure(b.text)) + 24)))
		row.fieldTop, row.fieldHeight = lh, 24
		return lh + 24
	end,
	Natural = function(row) return math.max(W.Measure(row.label), 150) end,
}

-- For the scenarios: the key row waiting for a key, or nil.
function W.Capturing() return capturing end

-- A fight starting lets go of the keyboard at once: the next key pressed is
-- for the fight, and the binding could not be set in it anyway.
function W.StopCapture()
	if capturing then StopCapture(capturing) end
end
