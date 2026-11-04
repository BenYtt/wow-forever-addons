-- Manners -- options window: the controls typed or dragged into -- a slider,
-- a number with nudge arrows, a one-line box, a box of many lines -- and the
-- never-offer list, which is built from five definitions. Added to the kinds
-- Widgets.lua started; see there for what a row is.
--
-- A box is never rewritten while it has the focus or shows an error, so a
-- repaint never takes what the player is typing.

local _, ns = ...
local W = ns.WindowWidgets
local T, KIND = W.Theme, W.KIND
local TextColour = W.TextColour

local function Bind() return ns.WindowBind end

local function Number(v)
	return tonumber(ns.plain(v)) or 0
end

-- What a box shows for the model's value: "" for none.
local function Current(row)
	local v = Bind().Value(row.item)
	if v == nil then return "" end
	return tostring(v)
end

-- A box in the field's dark well, in the small highlight font.
local function Box(parent, justify)
	local box = CreateFrame("EditBox", nil, parent)
	box:EnableMouse(true)
	box:SetAutoFocus(false)
	W.SetFont(box, T.fonts.small)
	TextColour(box, T.ink)
	box:SetTextInsets(7, 7, 0, 0)
	box:SetHeight(22)
	box:SetJustifyH(justify or "LEFT")
	box.look = W.Field(box)
	return box
end

-- Takes the focus away without the box committing on the way out.
local function Leave(row)
	row.leaving = true
	row.box:ClearFocus()
	row.leaving = false
end

local function Focus(row)
	if not row.off and row.box then row.box:SetFocus() end
end

local function ShowError(row, msg)
	if msg == nil then msg = Bind().Text(row.item, "usage") end
	row.error = W.Trim(msg)
	row.err:SetText(row.error)
	row.err:Show()
	W.Relayout(row)
end

local function HideError(row)
	if not row.error then return end
	row.error = nil
	row.err:SetText("")
	row.err:Hide()
	W.Relayout(row)
end

local function ErrorText(parent)
	local fs = W.Wrapping(W.Text(parent, T.fonts.small, T.red))
	fs:Hide()
	return fs
end

local function BoxLook(row)
	local box = row.box
	W.FieldLook(box.look, row.off and "off" or (box:HasFocus() and "focus" or nil))
end

---------------------------------------------------------------------------
-- a number typed into a box: range and number share Enter, Escape and
-- leaving the box, each with its own parse and its own text
---------------------------------------------------------------------------

local function ValueLeft(box)
	local row = box.row
	if not row.leaving and not W.Off(row) then
		local v = row.parse(row, box:GetText() or "")
		if v ~= nil and v ~= Number(Bind().Value(row.item)) then W.Commit(row, v) end
	end
	BoxLook(row)
	W.Settle(row)
end

local function ValueEnter(box) box:ClearFocus() end

local function ValueEscape(box)
	local row = box.row
	box:SetText(row.show(row, Number(Bind().Value(row.item))))
	Leave(row)
	BoxLook(row)
end

local function ValueFocused(box)
	box:HighlightText()
	BoxLook(box.row)
end

local function ValueScripts(box)
	box:SetScript("OnEnterPressed", function(self) ns.Guard("options box", ValueEnter, self) end)
	box:SetScript("OnEscapePressed", function(self) ns.Guard("options box", ValueEscape, self) end)
	box:SetScript("OnEditFocusLost", function(self) ns.Guard("options box", ValueLeft, self) end)
	box:SetScript("OnEditFocusGained", function(self) ns.Guard("options box", ValueFocused, self) end)
end

---------------------------------------------------------------------------
-- range: the label above a slider and an editable value; isPercent shows %.
-- Snapped to the step. The window is told while the mouse is held on it.
---------------------------------------------------------------------------

local function Decimals(step)
	local d = tostring(step or 1):match("%.(%d+)$")
	return d and #d or 0
end

local function Bounds(row)
	local def = row.item.def
	local lo, hi = tonumber(def.min) or 0, tonumber(def.max) or 100
	return lo, hi, tonumber(def.step), tonumber(def.softMin) or lo, tonumber(def.softMax) or hi
end

local function Snap(row, v)
	local lo, hi, step = Bounds(row)
	if step and step > 0 then v = lo + math.floor((v - lo) / step + 0.5) * step end
	v = math.max(lo, math.min(hi, v))
	return tonumber(("%." .. Decimals(step) .. "f"):format(v))
end

-- As many decimals as the step has, kept when they are zeros (1.00, 0.50),
-- as the mock-up shows them, so the box does not jump between 1 and 1.05
-- while the thumb moves.
local function RangeText(row, v)
	if row.item.def.isPercent then return ("%d%%"):format(math.floor(v * 100 + 0.5)) end
	local _, _, step = Bounds(row)
	return ("%." .. Decimals(step) .. "f"):format(v)
end

local function RangeParse(row, text)
	local n = tonumber((text:gsub("%%", ""):gsub(",", "."):gsub("[ \t]", "")))
	if not n then return nil end
	if row.item.def.isPercent then n = n / 100 end
	return Snap(row, n)
end

local function SliderMoved(slider, value)
	local row = slider.row
	if row.refreshing or W.Off(row) then return end
	local v = Snap(row, tonumber(value) or 0)
	if v == row.shown then return end
	row.shown = v
	W.Commit(row, v)
	if not row.box:HasFocus() then row.box:SetText(RangeText(row, v)) end
end

-- A hold whose release went missing: a slider laid out afresh under the
-- pointer can miss its OnMouseUp, and the client knows the button is up even
-- then. Let go here, or the slider and its box go on showing where the drag
-- ended instead of the setting. A client that will not say keeps the hold.
local function HoldLost(row)
	if not row.held or type(IsMouseButtonDown) ~= "function" or IsMouseButtonDown("LeftButton") then return end
	row.held = false
	W.Hold(row, false)
end

-- The mouse held on the slider or a nudge arrow: the window fades for a look
-- at the prompt, and a repaint leaves the thumb where the player has it. A
-- press lets go of the box beside it without committing, or the box would
-- keep the old number and put it back when it lost the focus; and a press
-- while a hold stands holds afresh, its release having gone missing.
local function Held(row, on)
	if on and row.off then return false end
	if on and row.box:HasFocus() then Leave(row) end
	if not on and not row.held then return false end
	row.held = on
	W.Hold(row, on)
	return true
end

local function SliderHeld(slider, on)
	local row = slider.row
	if Held(row, on) and not on then row:Refresh() end
end

local function ThumbLook(row)
	local top = row.off and T.thumbOffTop or T.thumbTop
	local bottom = row.off and T.thumbOffBottom or T.thumbBottom
	W.Gradient(row.thumb, "VERTICAL", bottom, top)
end

local function BuildSlider(row)
	local s = CreateFrame("Slider", nil, row.frame)
	s:EnableMouse(true)
	s:SetOrientation("HORIZONTAL")
	s:SetHeight(20)
	s:SetObeyStepOnDrag(true)
	s:SetHitRectInsets(0, 0, -4, -4)
	-- The rail is drawn on the slider itself: a child frame would sit a level
	-- above it and cut across the thumb.
	local fill = W.Solid(s, "BACKGROUND", 1)
	fill:SetPoint("LEFT", s, "LEFT", 0, 0)
	fill:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	fill:SetHeight(6)
	W.Gradient(fill, "VERTICAL", T.trackBottom, T.trackTop)
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = W.Solid(s, "BORDER", 1, T.trackEdge)
		if i <= 2 then
			t:SetPoint(side .. "LEFT", fill, side .. "LEFT", 0, 0)
			t:SetPoint(side .. "RIGHT", fill, side .. "RIGHT", 0, 0)
			t:SetHeight(1)
		else
			t:SetPoint("TOP" .. side, fill, "TOP" .. side, 0, 0)
			t:SetPoint("BOTTOM" .. side, fill, "BOTTOM" .. side, 0, 0)
			t:SetWidth(1)
		end
	end
	row.thumb = s:CreateTexture(nil, "OVERLAY")
	row.thumb:SetSize(11, 18)
	s:SetThumbTexture(row.thumb)
	s.row = row
	s:SetScript("OnValueChanged", function(self, value) ns.Guard("options slider", SliderMoved, self, value) end)
	s:SetScript("OnMouseDown", function(self) ns.Guard("options slider", SliderHeld, self, true) end)
	s:SetScript("OnMouseUp", function(self) ns.Guard("options slider", SliderHeld, self, false) end)
	return s
end

KIND.range = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		row.slider = BuildSlider(row)
		row.box = Box(row.frame, "CENTER")
		row.box.row = row
		row.parse, row.show = RangeParse, RangeText
		ValueScripts(row.box)
		row.low = W.Text(row.frame, T.fonts.small, T.hint)
		row.high = W.Text(row.frame, T.fonts.small, T.hint)
		row.high:SetJustifyH("RIGHT")
		W.Tip(row.slider, row)
		-- A hold ends with the page: a slider hidden under the mouse never
		-- hears the button come up.
		row.frame:SetScript("OnHide", function() ns.Guard("options slider", SliderHeld, row.slider, false) end)
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		local _, _, step, lo, hi = Bounds(row)
		local v = Number(Bind().Value(row.item))
		HoldLost(row)
		row.refreshing = true
		row.slider:SetMinMaxValues(lo, hi)
		row.slider:SetValueStep(step or 0)
		if not row.held then
			row.slider:SetValue(v)
			row.shown = v
		end
		row.refreshing = false
		if not row.box:HasFocus() then row.box:SetText(RangeText(row, row.held and row.shown or v)) end
		row.low:SetText(RangeText(row, lo))
		row.high:SetText(RangeText(row, hi))
		row.slider:SetEnabled(not row.off)
		row.box:EnableMouse(not row.off)
		TextColour(row.box, row.off and T.dim or T.ink)
		ThumbLook(row)
		BoxLook(row)
	end,
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		local cw = math.min(width, 360)
		local sw = math.max(40, cw - 68)
		row.slider:ClearAllPoints()
		row.slider:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(lh + 1))
		row.slider:SetWidth(sw)
		row.box:ClearAllPoints()
		row.box:SetPoint("TOPLEFT", row.frame, "TOPLEFT", sw + 10, -lh)
		row.box:SetWidth(58)
		row.low:ClearAllPoints()
		row.low:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(lh + 22))
		row.high:ClearAllPoints()
		row.high:SetPoint("TOPRIGHT", row.frame, "TOPLEFT", sw, -(lh + 22))
		row.fieldTop, row.fieldHeight = lh, 22
		return lh + 34
	end,
	Natural = function(row) return math.max(W.Measure(row.label), 200) end,
	Focus = Focus,
}

---------------------------------------------------------------------------
-- number: a box with up and down arrows -- 1 a click, 10 with Shift, held
-- between -2000 and 2000 (the exact position, advanced.x and .y).
---------------------------------------------------------------------------

local LIMIT = 2000

local function Clamp(v) return math.max(-LIMIT, math.min(LIMIT, v)) end

local function NumberText(_, v)
	if v == math.floor(v) then return ("%d"):format(v) end
	return ("%.1f"):format(v)
end

local function NumberParse(_, text)
	local n = tonumber((text:gsub(",", "."):gsub("[ \t]", "")))
	return n and Clamp(n) or nil
end

local function Nudge(row, by)
	if W.Off(row) then return end
	if IsShiftKeyDown and IsShiftKeyDown() then by = by * 10 end
	W.Apply(row, Clamp(Number(Bind().Value(row.item)) + by))
end

local function ArrowClicked(b) Nudge(b.row, b.step) end

local function ArrowHeld(b, on) Held(b.row, on) end

-- The arrow keys in the box nudge too, and the box shows where they got to.
local function ArrowKey(box, key)
	local row = box.row
	if key ~= "UP" and key ~= "DOWN" then return end
	Nudge(row, key == "UP" and 1 or -1)
	box:SetText(NumberText(row, Number(Bind().Value(row.item))))
end

local function Arrow(row, step, file)
	local b = CreateFrame("Button", nil, row.frame)
	b:RegisterForClicks("LeftButtonUp")
	b:SetSize(20, 11)
	b.face = W.Solid(b, "BACKGROUND", 1)
	b.face:SetAllPoints(b)
	W.Gradient(b.face, "VERTICAL", T.btnBottom, T.btnTop)
	W.Border(b, T.btnEdge)
	W.Solid(b, "HIGHLIGHT", nil, { 1, 1, 1, 0.12 }):SetAllPoints(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(file)
	b.icon:SetSize(9, 9)
	b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	W.Colour(b.icon, T.gold)
	b.row, b.step = row, step
	b:SetScript("OnClick", function(self) ns.Guard("options nudge", ArrowClicked, self) end)
	b:SetScript("OnMouseDown", function(self) ns.Guard("options nudge", ArrowHeld, self, true) end)
	b:SetScript("OnMouseUp", function(self) ns.Guard("options nudge", ArrowHeld, self, false) end)
	b:SetScript("OnHide", function(self) ns.Guard("options nudge", ArrowHeld, self, false) end)
	return b
end

KIND.number = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		row.box = Box(row.frame, "RIGHT")
		row.box.row = row
		row.parse, row.show = NumberParse, NumberText
		ValueScripts(row.box)
		row.box:SetScript("OnArrowPressed", function(self, key) ns.Guard("options nudge", ArrowKey, self, key) end)
		row.up = Arrow(row, 1, "Interface\\Buttons\\Arrow-Up-Up")
		row.down = Arrow(row, -1, "Interface\\Buttons\\Arrow-Down-Up")
		W.Tip(row.box, row)
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		if not row.box:HasFocus() then row.box:SetText(NumberText(row, Number(Bind().Value(row.item)))) end
		row.box:EnableMouse(not row.off)
		TextColour(row.box, row.off and T.dim or T.ink)
		row.up:SetEnabled(not row.off)
		row.down:SetEnabled(not row.off)
		row.up.icon:SetDesaturated(row.off and true or false)
		row.down.icon:SetDesaturated(row.off and true or false)
		BoxLook(row)
	end,
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		row.box:ClearAllPoints()
		row.box:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -lh)
		row.box:SetWidth(math.min(84, math.max(40, width - 23)))
		row.up:ClearAllPoints()
		row.up:SetPoint("TOPLEFT", row.box, "TOPRIGHT", 3, 0)
		row.down:ClearAllPoints()
		row.down:SetPoint("BOTTOMLEFT", row.box, "BOTTOMRIGHT", 3, 0)
		row.fieldTop, row.fieldHeight = lh, 22
		return lh + 22
	end,
	Natural = function(row) return math.max(W.Measure(row.label), 107) end,
	Focus = Focus,
}

---------------------------------------------------------------------------
-- input: one line. Enter commits; Escape puts it back and lets go of the
-- focus; leaving the box commits too, except for a box that is only for
-- typing into (its get is "" or nothing: Add a name, a new profile), which
-- commits on Enter alone. A box whose get is "" is empty again after. A
-- refused value says why in red under the box and keeps what was typed.
---------------------------------------------------------------------------

local function TypingOnly(row)
	local v = Bind().Value(row.item)
	return v == nil or v == ""
end

-- Answers whether the box can let go: true once committed or with nothing
-- to commit, false when the model refused it.
local function Submit(row)
	if W.Off(row) then return false end
	local text = row.box:GetText() or ""
	if text == Current(row) and not row.error then return true end
	row.busy = true
	local ok, msg = W.Commit(row, text)
	row.busy = false
	if ok == false then
		ShowError(row, msg)
		return false
	end
	HideError(row)
	return true
end

local function InputEnter(box)
	local row = box.row
	if not Submit(row) then return end
	Leave(row)
	W.Settle(row)
end

local function InputEscape(box)
	local row = box.row
	HideError(row)
	box:SetText(Current(row))
	Leave(row)
	BoxLook(row)
end

local function InputLeft(box)
	local row = box.row
	BoxLook(row)
	if row.leaving or row.busy or row.error or W.Waiting(row) or TypingOnly(row) then return end
	if Submit(row) then W.Settle(row) end
end

local function InputTyped(box, userInput)
	local row = box.row
	if userInput and row.error then HideError(row) end
end

KIND.input = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		local box = Box(row.frame)
		box.row = row
		box:SetScript("OnEnterPressed", function(self) ns.Guard("options box", InputEnter, self) end)
		box:SetScript("OnEscapePressed", function(self) ns.Guard("options box", InputEscape, self) end)
		box:SetScript("OnEditFocusLost", function(self) ns.Guard("options box", InputLeft, self) end)
		box:SetScript("OnEditFocusGained", function(self) ns.Guard("options box", BoxLook, self.row) end)
		box:SetScript("OnTextChanged", function(self, userInput) ns.Guard("options box", InputTyped, self, userInput) end)
		W.Tip(box, row)
		row.box = box
		row.err = ErrorText(row.frame)
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		local box = row.box
		if row.off and box:HasFocus() then Leave(row) end
		if not box:HasFocus() and not row.error then box:SetText(Current(row)) end
		box:EnableMouse(not row.off)
		TextColour(box, row.off and T.dim or T.ink)
		BoxLook(row)
	end,
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		row.boxTop = lh
		row.box:ClearAllPoints()
		row.box:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -lh)
		row.box:SetWidth(math.min(width, 360))
		row.fieldTop, row.fieldHeight = lh, 22
		local h = lh + 22
		if row.error then
			row.err:ClearAllPoints()
			row.err:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(h + 3))
			row.err:SetWidth(width)
			h = h + 3 + math.ceil(W.TextHeight(row.err))
		end
		return h
	end,
	Natural = function(row) return math.max(W.Measure(row.label), 200) end,
	Focus = Focus,
}

---------------------------------------------------------------------------
-- multiline: a scrolling box as many lines tall as the definition asks, with
-- a slim bar while the text runs past it, and Accept, lit only while the text
-- differs from the model's. A read-only box (its set throws typing away: the
-- settings as text, the bug report) has no Accept and selects everything when
-- clicked, ready to copy.
---------------------------------------------------------------------------

local READ_ONLY = { ["profiles.shareText"] = true, ["diagnostics.report"] = true,
	["diagnostics.selftest"] = true }

local function ReadOnly(row)
	return READ_ONLY[row.item.path] == true or (row.item.layout or {}).readOnly == true
end

local function Lines(row)
	local m = row.item.def and row.item.def.multiline
	return type(m) == "number" and m or 4
end

local function LineHeight(row)
	local _, size = row.box:GetFont()
	return (tonumber(size) or 10) + 3
end

local function AcceptState(row)
	if row.accept then row.accept:SetEnabled(not row.off and (row.box:GetText() or "") ~= Current(row)) end
end

-- The box's own slim bar, as the content's: shown only while the text runs
-- past the box, so a half-cut last line says there is more, and kept level
-- with the scroll however it moved (the wheel, the cursor, the bar).
local function BarSync(row)
	local scroll, bar = row.scroll, row.bar
	if not bar then return end
	local range = tonumber(ns.plain(scroll:GetVerticalScrollRange())) or 0
	bar:SetShown(range > 0)
	if range <= 0 then return end
	local height = tonumber(ns.plain(scroll:GetHeight())) or 0
	row.syncing = true
	bar:SetMinMaxValues(0, range)
	bar:SetValue(scroll:GetVerticalScroll())
	row.syncing = false
	row.thumb:SetHeight(math.max(16, math.floor((height - 6) * height / (height + range))))
end

local function BarMoved(bar, value)
	local row = bar.row
	if row.syncing then return end
	row.scroll:SetVerticalScroll(tonumber(value) or 0)
end

local function ScrollBar(row)
	local bar = CreateFrame("Slider", nil, row.frame)
	bar:SetOrientation("VERTICAL")
	bar:SetWidth(6)
	bar:SetMinMaxValues(0, 0)
	bar:SetValueStep(1)
	bar:SetObeyStepOnDrag(false)
	bar:EnableMouse(true)
	local level = row.scroll.GetFrameLevel and row.scroll:GetFrameLevel()
	if level and bar.SetFrameLevel then bar:SetFrameLevel(level + 2) end
	W.Solid(bar, "BACKGROUND", nil, T.barTrack):SetAllPoints(bar)
	row.thumb = W.Solid(bar, "ARTWORK", nil, T.barThumb)
	row.thumb:SetSize(6, 16)
	bar:SetThumbTexture(row.thumb)
	bar:SetPoint("TOPRIGHT", row.scroll, "TOPRIGHT", -2, -3)
	bar:SetPoint("BOTTOMRIGHT", row.scroll, "BOTTOMRIGHT", -2, 3)
	bar.row = row
	bar:Hide()
	return bar
end

local function AcceptClicked(b)
	local row = b.row
	if W.Off(row) then return end
	local ok, msg = W.Commit(row, row.box:GetText() or "")
	if ok == false then
		ShowError(row, msg)
		return
	end
	HideError(row)
	if not W.Waiting(row) then row.box:SetText(Current(row)) end
	Leave(row)
	W.Settle(row)
end

local function MultiTyped(box, userInput)
	local row = box.row
	if userInput and ReadOnly(row) then
		box:SetText(Current(row))
		box:HighlightText()
		return
	end
	if userInput and row.error then HideError(row) end
	AcceptState(row)
	row.scroll:UpdateScrollChildRect()
	BarSync(row)
end

local function MultiEscape(box)
	local row = box.row
	HideError(row)
	box:SetText(Current(row))
	Leave(row)
	AcceptState(row)
end

local function MultiFocus(box, on)
	local row = box.row
	W.FieldLook(row.scroll.look, row.off and "off" or (on and "focus" or nil))
	if ReadOnly(row) then
		if on then box:HighlightText() else box:HighlightText(0, 0) end
	end
end

-- Keeps the line being typed on in view. The client tells the cursor's move
-- before the box has grown to hold a new line, so the scroll range is the
-- old one until the next frame; the follow waits for that frame, as
-- Blizzard's own ScrollingEdit does, and takes the range as it then stands.
local function Follow(row)
	row.following = false
	local scroll = row.scroll
	scroll:UpdateScrollChildRect()
	local y, h = row.cursorY or 0, row.cursorH or 0
	local top, height = scroll:GetVerticalScroll(), scroll:GetHeight()
	local to = top
	if y < top then
		to = y
	elseif y + h > top + height then
		to = y + h - height
	end
	if to ~= top then
		local range = tonumber(ns.plain(scroll:GetVerticalScrollRange())) or 0
		scroll:SetVerticalScroll(math.max(0, math.min(range, to)))
	end
	BarSync(row)
end

local function FollowCursor(box, _, y, _, h)
	local row = box.row
	row.cursorY, row.cursorH = -(tonumber(y) or 0), tonumber(h) or 0
	if row.following then return end
	row.following = true
	C_Timer.After(0, function() ns.Guard("options box", Follow, row) end)
end

local function Wheel(scroll, delta)
	local row = scroll.row
	delta = tonumber(delta) or 0
	local top = scroll:GetVerticalScroll()
	local v = top - delta * LineHeight(row) * 3
	local to = math.max(0, math.min(scroll:GetVerticalScrollRange(), v))
	scroll:SetVerticalScroll(to)
	BarSync(row)
	-- The client gives the wheel to the first frame that takes it and does not
	-- pass it up, so a box with nothing left to scroll that way hands it to the
	-- page, or the page would stop under the pointer.
	if to == top and delta ~= 0 and row.ctx.ScrollPage then row.ctx.ScrollPage(delta) end
end

local function ScrollMoved(scroll) BarSync(scroll.row) end

local function ScrollClicked(scroll)
	Focus(scroll.row)
end

local function MultiScripts(row)
	local box, scroll = row.box, row.scroll
	box:SetScript("OnEscapePressed", function(self) ns.Guard("options box", MultiEscape, self) end)
	box:SetScript("OnTextChanged", function(self, userInput) ns.Guard("options box", MultiTyped, self, userInput) end)
	box:SetScript("OnCursorChanged", function(self, x, y, w, h)
		ns.Guard("options box", FollowCursor, self, x, y, w, h)
	end)
	box:SetScript("OnEditFocusGained", function(self) ns.Guard("options box", MultiFocus, self, true) end)
	box:SetScript("OnEditFocusLost", function(self) ns.Guard("options box", MultiFocus, self, false) end)
	scroll:SetScript("OnMouseDown", function(self) ns.Guard("options box", ScrollClicked, self) end)
	scroll:SetScript("OnMouseWheel", function(self, delta) ns.Guard("options box", Wheel, self, delta) end)
	-- The client's word that the text grew or shrank under the box.
	scroll:SetScript("OnScrollRangeChanged", function(self) ns.Guard("options box", ScrollMoved, self) end)
	local bar = row.bar
	bar:SetScript("OnValueChanged", function(self, value) ns.Guard("options box", BarMoved, self, value) end)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(self, delta) ns.Guard("options box", Wheel, row.scroll, delta) end)
end

KIND.multiline = {
	Build = function(row)
		row.label = W.Wrapping(W.Text(row.frame, T.fonts.label, T.ink))
		local scroll = CreateFrame("ScrollFrame", nil, row.frame)
		scroll.look = W.Field(scroll)
		scroll:EnableMouse(true)
		scroll:EnableMouseWheel(true)
		scroll.row = row
		local box = CreateFrame("EditBox", nil, scroll)
		box:SetMultiLine(true)
		box:SetAutoFocus(false)
		box:SetMaxLetters(0)
		W.SetFont(box, T.fonts.small)
		TextColour(box, T.ink)
		box:SetTextInsets(8, 8, 6, 6)
		box.row = row
		scroll:SetScrollChild(box)
		row.scroll, row.box = scroll, box
		row.bar = ScrollBar(row)
		MultiScripts(row)
		W.Tip(box, row)
		if not ReadOnly(row) then
			row.accept = W.Button(row.frame, ACCEPT, AcceptClicked)
			row.accept.row = row
		end
		row.err = ErrorText(row.frame)
	end,
	Refresh = function(row)
		row.label:SetText(W.Trim(W.Name(row)))
		TextColour(row.label, row.off and T.dim or T.ink)
		local box = row.box
		if row.off and box:HasFocus() then Leave(row) end
		if not box:HasFocus() and not row.error then
			local v = Current(row)
			if box:GetText() ~= v then box:SetText(v) end
		end
		box:EnableMouse(not row.off)
		TextColour(box, row.off and T.dim or (ReadOnly(row) and T.inkSoft or T.ink))
		W.FieldLook(row.scroll.look, row.off and "off" or (box:HasFocus() and "focus" or nil))
		AcceptState(row)
	end,
	Layout = function(row, width)
		local lh = W.PlaceLabel(row.label, row.frame, width)
		local boxHeight = Lines(row) * LineHeight(row) + 12
		row.scroll:ClearAllPoints()
		row.scroll:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -lh)
		row.scroll:SetSize(width, boxHeight)
		row.box:SetSize(width, boxHeight)
		row.scroll:UpdateScrollChildRect()
		row.fieldTop, row.fieldHeight = lh, boxHeight
		BarSync(row)
		local y, below = lh + boxHeight, 0
		local errRoom = width
		if row.accept then
			row.accept:ClearAllPoints()
			row.accept:SetPoint("TOPRIGHT", row.frame, "TOPLEFT", width, -(y + 4))
			below = 26
			errRoom = width - row.accept:GetWidth() - 10
		end
		if row.error then
			row.err:ClearAllPoints()
			row.err:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(y + 5))
			row.err:SetWidth(math.max(1, errRoom))
			below = math.max(below, 5 + math.ceil(W.TextHeight(row.err)))
		end
		return y + below
	end,
	Natural = function(row) return math.max(W.Measure(row.label), 200) end,
	Focus = Focus,
}

---------------------------------------------------------------------------
-- never: the never-offer list as one piece, from five definitions (the
-- layout's ids): neverNote is the caption and the empty state; each name of
-- neverPick's values is a row with an X that does what picking it and
-- pressing neverRemove did, chat line included; neverAdd is the box under the
-- list and neverClear the button beside it, with its confirm.
---------------------------------------------------------------------------

local NEVER_PARTS = { neverNote = "note", neverPick = "pick", neverRemove = "remove",
	neverAdd = "add", neverClear = "clear" }
local NEVER_ORDER = { "note", "pick", "remove", "add", "clear" }
local LIST_WIDTH, ADD_WIDTH, LINE = 320, 240, 20

local function RemoveClicked(x)
	local row = x.row
	if not (row.pick and row.remove) or Bind().Disabled(row.pick) then return end
	Bind().Commit(row.pick, x.name)
	Bind().Run(row.remove)
	row:Refresh()
end

local function RemoveTip(x)
	local row = x.row
	local text = row.remove and Bind().Text(row.remove, "name")
	if not text or text == "" then return end
	GameTooltip:SetOwner(x, "ANCHOR_RIGHT")
	GameTooltip:AddLine(text, 1, 1, 1)
	GameTooltip:Show()
end

local function NameLine(row, i)
	local line = CreateFrame("Frame", nil, row.list)
	line:SetHeight(LINE)
	line.text = W.Text(line, T.fonts.label, T.white)
	line.text:SetPoint("LEFT", line, "LEFT", 8, 0)
	line.text:SetPoint("RIGHT", line, "RIGHT", -28, 0)
	line.text:SetWordWrap(false)
	local x = CreateFrame("Button", nil, line)
	x:RegisterForClicks("LeftButtonUp")
	x:SetSize(LINE, LINE)
	x:SetPoint("RIGHT", line, "RIGHT", -2, 0)
	local icon = x:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	icon:SetSize(14, 14)
	icon:SetPoint("CENTER", x, "CENTER", 0, 0)
	W.Solid(x, "HIGHLIGHT", nil, { 1, 0.31, 0.24, 0.16 }):SetAllPoints(x)
	x.row = row
	x:SetScript("OnClick", function(self) ns.Guard("options never", RemoveClicked, self) end)
	x:SetScript("OnEnter", function(self) ns.Guard("options tooltip", RemoveTip, self) end)
	x:SetScript("OnLeave", function() GameTooltip:Hide() end)
	line.x = x
	row.lines[i] = line
	return line
end

local function Part(row, kind, item)
	if not item then return nil end
	local sub = W.Build(kind, row.frame, item)
	sub.parentRow = row
	return sub
end

local function PlaceList(row, width, y)
	local n = row.count or 0
	row.list:SetShown(n > 0)
	if n == 0 then return y end
	local w = math.min(width, LIST_WIDTH)
	local h = 6 + n * LINE + (n - 1) * 2
	row.list:ClearAllPoints()
	row.list:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
	row.list:SetSize(w, h)
	for i = 1, n do
		local line = row.lines[i]
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", row.list, "TOPLEFT", 3, -(3 + (i - 1) * (LINE + 2)))
		line:SetWidth(w - 6)
	end
	return y + h + 8
end

-- The add box, and Clear the list level with its box when both fit across,
-- under it when not. Answers the height they take.
local function PlaceAdd(row, width, y)
	local h, addWidth = 0, 0
	if row.add then
		addWidth = math.min(width, ADD_WIDTH)
		h = row.add:Layout(addWidth)
		row.add.frame:ClearAllPoints()
		row.add.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
	end
	if row.clear then
		local cw = row.clear:NaturalWidth()
		row.clear:Layout(cw)
		row.clear.frame:ClearAllPoints()
		if row.add and addWidth + 12 + cw <= width then
			local top = (row.add.boxTop or 0) - 1
			row.clear.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", addWidth + 12, -(y + top))
			h = math.max(h, top + 24)
		else
			row.clear.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -(y + h + (h > 0 and 6 or 0)))
			h = h + (h > 0 and 6 or 0) + 24
		end
	end
	return h
end

KIND.never = {
	Build = function(row)
		local parts = {}
		for i, path in ipairs((row.item.layout or {}).ids or {}) do
			local which = NEVER_PARTS[tostring(path):match("([^.]+)$")] or NEVER_ORDER[i]
			if which then parts[which] = Bind().Item(path, {}, row.ctx) end
		end
		row.pick, row.remove = parts.pick, parts.remove
		row.note = Part(row, "description", parts.note)
		row.list = CreateFrame("Frame", nil, row.frame)
		W.Field(row.list)
		row.lines = {}
		row.add = Part(row, "input", parts.add)
		row.clear = Part(row, "execute", parts.clear)
	end,
	Refresh = function(row)
		if row.note then row.note:Refresh() end
		if row.add then row.add:Refresh() end
		if row.clear then row.clear:Refresh() end
		local names = row.pick and Bind().Values(row.pick) or {}
		for i, v in ipairs(names) do
			local line = row.lines[i] or NameLine(row, i)
			line.text:SetText(v[2])
			line.x.name = v[1]
			line:Show()
		end
		for i = #names + 1, #row.lines do row.lines[i]:Hide() end
		local was = row.count
		row.count = #names
		row.list:SetShown(#names > 0)
		if was and was ~= row.count then W.Relayout(row) end
	end,
	Layout = function(row, width)
		local y = 0
		if row.note then
			local h = row.note:Layout(width)
			row.note.frame:ClearAllPoints()
			row.note.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
			if h > 0 then y = h + 8 end
		end
		y = PlaceList(row, width, y)
		return y + PlaceAdd(row, width, y)
	end,
	Natural = function() return LIST_WIDTH end,
	Focus = function(row) if row.add then row.add:Focus() end end,
}
