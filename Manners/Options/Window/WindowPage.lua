-- Manners -- options window: the page in the content area. Its sections and
-- rows, which of them show, pairs and columns measured in the
-- player's language, the folds and their gold dots.
--
-- Each page's rows are built the first time it is opened and kept: switching
-- pages hides one set and shows another, and a repaint re-reads values and
-- moves rows, never rebuilds them, so a slider being dragged or a box being
-- typed in is never pulled out from under the player.

local _, ns = ...
local UI = ns.WindowUI

local PAD_LEFT, PAD_TOP, PAD_BOTTOM = 18, 14, 26
local CONTENT_W = UI.WIDTH - UI.SIDEBAR - 13 - PAD_LEFT - 17
local GAP, ROW_GAP, SECTION_GAP, INDENT = 18, 6, 10, 16
local C = UI.C

-- path -> { page, sec, e }, for every placed control and note
local where = {}
local models = {}

---------------------------------------------------------------------------
-- the page model: sections and entries, no frames
---------------------------------------------------------------------------

local function KindOf(item, entry)
	if entry.composite then return entry.composite end
	if entry.widget then return entry.widget end
	local t = item.def.type
	if t == "input" and item.def.multiline then return "multiline" end
	return t
end

local function IsNote(item)
	local t = item.def.type
	return t == "description" or t == "header"
end

-- A placed item's layout entry, with how the layout draws it as a note (its
-- `notes` table: grey, or a grey block) folded into a copy.
local function EntryLayout(raw)
	local entry = type(raw) == "table" and raw or { raw }
	local look = type(entry[1]) == "string" and (UI.Layout().notes or {})[entry[1]]
	if type(look) ~= "table" then return entry end
	local out = {}
	for k, v in pairs(entry) do out[k] = v end
	for k, v in pairs(look) do out[k] = v end
	return out
end

-- One placed item: a control or a note, or the never-offer composite, which
-- is one row built from several definitions.
local function Entry(raw, sec)
	local entry = EntryLayout(raw)
	local e = { layout = entry, sec = sec }
	if entry.composite then
		e.subs = {}
		for _, path in ipairs(entry.ids or {}) do
			local sub = UI.Item(path, entry)
			if sub then e.subs[#e.subs + 1] = sub end
		end
		if #e.subs == 0 then return nil end
		e.item, e.path, e.kind, e.isControl = e.subs[1], e.subs[1].path, entry.composite, true
		return e
	end
	e.path = entry[1]
	e.item = UI.Item(e.path, entry)
	if not e.item then return nil end
	e.kind = KindOf(e.item, entry)
	e.isControl = not IsNote(e.item)
	e.standIn = entry.standIn and true or false
	return e
end

-- A page's sections and entries, made once. Controls the model does not have
-- for this character are left out.
function UI.Model(id)
	local m = models[id]
	if m then return m end
	local page = UI.Layout().pages[id]
	m = { id = id, page = page, sections = {} }
	for si, s in ipairs(page and page.sections or {}) do
		local sec = { def = s, key = s.key or (id .. "." .. si), fold = s.fold and true or false,
			entries = {}, hasControls = false, page = id }
		sec.headerItem = UI.Item(s.header)
		for _, raw in ipairs(s.items or {}) do
			local e = Entry(raw, sec)
			if e then
				sec.entries[#sec.entries + 1] = e
				sec.hasControls = sec.hasControls or e.isControl
				where[e.path] = { page = id, sec = sec, e = e }
				for _, sub in ipairs(e.subs or {}) do
					where[sub.path] = where[sub.path] or { page = id, sec = sec, e = e }
				end
			end
		end
		m.sections[#m.sections + 1] = sec
	end
	models[id] = m
	return m
end

-- Which page a control is placed on.
function UI.PageOf(path)
	if not where[path] then
		for id in pairs(UI.Layout().pages) do UI.Model(id) end
	end
	local w = where[path]
	return w and w.page or nil
end

function UI.Where(path)
	UI.PageOf(path)
	return where[path]
end

-- Whether an entry is shown by its own rules and its tab's. A composite is
-- shown while any of its controls is. A rule that throws hides its entry
-- (UI.Hidden).
local function Shown(e)
	if e.subs then
		for _, sub in ipairs(e.subs) do
			if not IsNote(sub) and not UI.Hidden(sub) then return true end
		end
		return false
	end
	return not UI.Hidden(e.item)
end
UI.EntryShown = Shown

-- A page is in the sidebar while one of its controls is shown. Notes never
-- keep it there, and their rules are never asked for a page not open.
function UI.PageVisible(id)
	for _, sec in ipairs(UI.Model(id).sections) do
		for _, e in ipairs(sec.entries) do
			if e.isControl and Shown(e) then return true end
		end
	end
	return false
end

-- The note rule: a section shows while a control in it does. A
-- note keeps it only when it stands in for a hidden control, or when the
-- section holds no controls at all; any other note is attached and never
-- keeps a section by itself.
local function Judge(sec)
	local control, standIn, note = false, false, false
	for _, e in ipairs(sec.entries) do
		e.visible = Shown(e)
		if e.visible then
			if e.isControl then
				control = true
			elseif e.standIn then
				standIn = true
			else
				note = true
			end
		end
	end
	sec.visible = control or standIn or (note and not sec.hasControls)
	return sec.visible
end

---------------------------------------------------------------------------
-- the gold dot on a fold: something inside differs from default
---------------------------------------------------------------------------

-- The profile fields each foldable control writes. Only controls shown now
-- count, so a reason text a hunter cannot see does not light the dot.
local FIELDS = {
	["who.target"] = { { "priority", "target" } },
	["who.friends"] = { { "priority", "friends" } },
	["who.readyCheck"] = { { "priority", "readyCheck" } },
	["who.revived"] = { { "priority", "revived" } },
	["advanced.retryCooldown"] = { { "timing", "retryCooldown" } },
	["advanced.scanInterval"] = { { "timing", "scanInterval" } },
	["advanced.restoreTarget"] = { { "filters", "restoreTarget" } },
	["advanced.x"] = { { "prompt", "x" }, { "prompt", "point" }, { "prompt", "relPoint" } },
	["advanced.y"] = { { "prompt", "y" }, { "prompt", "point" }, { "prompt", "relPoint" } },
}
for _, key in ipairs({ "format", "reasonTarget", "reasonOwed", "reasonAsked", "reasonSelf", "reasonGroup",
	"reasonNearby", "reasonRefresh", "reasonUnknown" }) do
	FIELDS["advanced." .. key] = { { "prompt", key } }
end
for _, key in ipairs({ "font", "fontSize", "fontColor", "classColor", "showSub", "showIcon", "iconSize",
	"roundIcon", "showCooldown", "showCount", "showQueue", "queueRows", "clickRows" }) do
	FIELDS["appearance." .. key] = { { "prompt", key } }
end

local function Profile() return ns.db.profile end

-- The line set, by its definition rather than what the box shows: a set
-- other than Role-play, or the box no longer holding the set's own lines.
local function LinesChanged()
	local speech = Profile().speech
	local choice = speech.presetChoice or "roleplay"
	if choice ~= "roleplay" then return true end
	return ns.PhraseSetText ~= nil and speech.phrases ~= ns.PhraseSetText(choice)
end

-- Controls whose shown value is computed: a later layout that folds one
-- must use these, never the value the control displays.
local DIFFERS = {
	["appearance.posPreset"] = function() return ns.CurrentPositionPreset() ~= "bars" end,
	["general.quickWho"] = function() return ns.QuickSetup.Match(ns.QuickSetup.WHO) ~= "nearby" end,
	["general.quickVoice"] = function() return ns.QuickSetup.Match(ns.QuickSetup.VOICE) ~= "silent" end,
	["who.choice"] = function() return Profile().buff.choice ~= "auto" end,
	["who.skipRaidGroups"] = function() return next(Profile().filters.skipRaidGroups or {}) ~= nil end,
	["appearance.reasonPalette"] = function() return Profile().prompt.reasonPalette == "colourblind" end,
	["general.minimap"] = function() return Profile().minimap.hide == true end,
	["click.preset"] = LinesChanged,
	["click.phrases"] = LinesChanged,
}

-- Numbers within half a step, colours per component within 0.002 (alpha 1
-- when missing), anything else exactly.
local function Same(a, b, step)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= (step and step / 2 or 1e-9)
	end
	if type(a) == "table" and type(b) == "table" then
		for i = 1, 4 do
			local x, y = a[i], b[i]
			if i == 4 then x, y = x == nil and 1 or x, y == nil and 1 or y end
			if type(x) ~= "number" or type(y) ~= "number" or math.abs(x - y) > 0.002 then return false end
		end
		return true
	end
	return a == b
end

function UI.Differs(path, item)
	local differs = DIFFERS[path]
	if differs then return differs() and true or false end
	local p = Profile()
	local skip = path:match("^who%.offer_(.+)$")
	if skip then return (p.buff.skip or {})[skip] == true end
	local family = path:match("^who%.own_(.+)$")
	if family then return (p.ownBuffs.pick or {})[family] ~= nil end
	local fields = FIELDS[path]
	if not fields then return false end
	local defaults = ns.defaults.profile
	local step = item and item.def.step
	for _, f in ipairs(fields) do
		local want = (defaults[f[1]] or {})[f[2]]
		-- A clamp to the prompt's size alone does not light the dot.
		if f[2] == "iconSize" and type(want) == "number" and ns.IconCeiling then
			want = math.min(want, ns.IconCeiling(p.prompt))
		end
		if not Same((p[f[1]] or {})[f[2]], want, step) then return true end
	end
	return false
end

function UI.FoldChanged(sec)
	for _, e in ipairs(sec.entries) do
		if e.isControl and e.visible and UI.Differs(e.path, e.item) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- frames: built once per page
---------------------------------------------------------------------------

-- A row that will not build is named in /manners errors and left out; the
-- rest of the page still works.
local function BuildRow(e, child)
	local W = ns.WindowWidgets
	local ok, row = pcall(W.Build, e.kind, child, e.item)
	if not ok then
		ns.Guard("options row " .. e.path, error, row, 0)
		return nil
	end
	row.frame:Hide()
	return row
end

local function ToggleFold(sec)
	local open = UI.State().open
	open[sec.key] = not open[sec.key] or nil
	UI.Refresh()
end

local function FoldButton(sec, child)
	local b = CreateFrame("Button", nil, child)
	b:SetHeight(26)
	b.hover = UI.Solid(b, "BACKGROUND", C.hover)
	b.hover:SetAllPoints()
	b.hover:Hide()
	local rule = UI.Solid(b, "BORDER", C.faint)
	rule:SetPoint("BOTTOMLEFT")
	rule:SetPoint("BOTTOMRIGHT")
	rule:SetHeight(1)
	b.chevron = b:CreateTexture(nil, "ARTWORK")
	b.chevron:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	b.chevron:SetSize(12, 12)
	b.chevron:SetVertexColor(C.goldSoft[1], C.goldSoft[2], C.goldSoft[3], 1)
	b.chevron:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.label = UI.Text(b, 13, C.goldSoft)
	b.label:SetPoint("LEFT", b, "LEFT", 22, 0)
	b.dot = UI.Dot(b, C.gold)
	b:SetScript("OnClick", UI.Guarded(function() ToggleFold(sec) end))
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	b:Hide()
	return b
end

local function SectionTitle(sec, child)
	sec.title = UI.Text(child, 13, C.gold)
	sec.title:Hide()
	sec.rule = child:CreateTexture(nil, "ARTWORK")
	sec.rule:SetHeight(1)
	UI.Gradient(sec.rule, "HORIZONTAL", C.goldRule, { 1, 0.82, 0, 0 })
	sec.rule:Hide()
end

-- The hairline above the folds, captioned in grey with advIntro's sentence.
local function Caption(m, child)
	local cap = {}
	cap.text = UI.Text(child, GameFontDisableSmall, C.hint)
	cap.text:SetJustifyH("CENTER")
	cap.text:SetWordWrap(true)
	if cap.text.SetNonSpaceWrap then cap.text:SetNonSpaceWrap(true) end
	cap.left = UI.Solid(child, "ARTWORK", C.line)
	cap.left:SetHeight(1)
	cap.right = UI.Solid(child, "ARTWORK", C.line)
	cap.right:SetHeight(1)
	cap.item = UI.Item(UI.Layout().foldCaption)
	m.caption = cap
	UI.ShowCaption(m, false)
end

function UI.ShowCaption(m, on)
	local cap = m.caption
	cap.text:SetShown(on)
	cap.left:SetShown(on)
	cap.right:SetShown(on)
end

local function BuildFrames(m)
	if m.built then return end
	local child = UI.view.child
	m.title = UI.Text(child, 18, C.gold)
	m.title:Hide()
	for _, sec in ipairs(m.sections) do
		if sec.fold then
			sec.button = FoldButton(sec, child)
		elseif sec.def.title or sec.headerItem then
			SectionTitle(sec, child)
		end
		for _, e in ipairs(sec.entries) do e.row = BuildRow(e, child) end
	end
	Caption(m, child)
	m.built = true
end

local function HideSection(sec)
	if sec.title then
		sec.title:Hide()
		sec.rule:Hide()
	end
	if sec.button then sec.button:Hide() end
	for _, e in ipairs(sec.entries) do
		if e.row then e.row.frame:Hide() end
	end
end

-- Put a page's frames away when another one is shown.
function UI.HidePage(id)
	local m = models[id]
	if not (m and m.built) then return end
	m.title:Hide()
	UI.ShowCaption(m, false)
	for _, sec in ipairs(m.sections) do HideSection(sec) end
end

---------------------------------------------------------------------------
-- laying a page out
---------------------------------------------------------------------------

local function NaturalWidth(e)
	local row = e.row
	local w = row and row.NaturalWidth and row.NaturalWidth(row)
	return type(w) == "number" and w or math.huge
end

-- `h` when the row was laid out at this width already.
local function Place(e, x, y, width, h)
	local row = e.row
	h = h or row.Layout(row, width) or 20
	local frame = row.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", x, -y)
	frame:SetSize(width, h)
	frame:Show()
	e.y, e.x, e.h = y, x, h
	return h
end

local function Usable(e) return e.visible and e.row ~= nil end

local function Indent(e) return e.layout.indent and INDENT or 0 end

-- How far down a row the middle of its control is: under the label for a
-- dropdown, a slider or a box, at the top for a switch or a swatch. Nil for a
-- row with no control to line up (a note).
local function Middle(row)
	if not (row and row.fieldHeight) then return nil end
	return (row.fieldTop or 0) + row.fieldHeight / 2
end

-- Two rows side by side, the one whose control sits higher moved down until
-- the two controls are level: Lock position beside its dropdown rather than
-- beside the dropdown's label.
local function PlaceTwo(a, b, x, half, y)
	local ha = a.row.Layout(a.row, half) or 20
	local hb = b.row.Layout(b.row, half) or 20
	local ma, mb = Middle(a.row), Middle(b.row)
	local da, db = 0, 0
	if ma and mb then
		if ma > mb then db = math.floor(ma - mb + 0.5) else da = math.floor(mb - ma + 0.5) end
	end
	Place(a, x, y + da, half, ha)
	Place(b, x + half + GAP, y + db, half, hb)
	return y + math.max(ha + da, hb + db) + ROW_GAP
end

-- The items from i that a run of pairs covers: a pair and the item after it,
-- and the next pair when it starts straight after (the reason boxes are one
-- run of four pairs).
local function PairRun(list, i)
	local last, k = i, i
	while list[k] and list[k].layout.pair and list[k + 1] do
		last = k + 1
		k = k + 2
	end
	return last
end

-- A run's shown items two to a row, in order, so two still share a row when
-- the ones between them are hidden (a hunter's two reason boxes), and a pair
-- whose partner is hidden is not joined to whatever follows the run. Two share
-- a row when both fit half the width, measured in this language; otherwise
-- one goes above the other.
local function PlacePairs(list, i, y)
	local last, shown = PairRun(list, i), {}
	for k = i, last do
		if Usable(list[k]) then
			shown[#shown + 1] = list[k]
		elseif list[k].row then
			list[k].row.frame:Hide()
		end
	end
	local k = 1
	while k <= #shown do
		local a, b = shown[k], shown[k + 1]
		local x, width = PAD_LEFT + Indent(a), CONTENT_W - Indent(a)
		local half = math.floor((width - GAP) / 2)
		if b and NaturalWidth(a) <= half and NaturalWidth(b) <= half then
			y = PlaceTwo(a, b, x, half, y)
			k = k + 2
		else
			y = y + Place(a, x, y, width) + ROW_GAP
			k = k + 1
		end
	end
	return y, last + 1
end

-- A run of items in `columns` columns (the per-spell switches, the reason
-- boxes), when every one fits a column; stacked otherwise.
local function PlaceColumns(list, i, y)
	local e = list[i]
	local cols = e.layout.columns
	local run, last = {}, i
	for k = i, #list do
		if list[k].layout.columns ~= cols then break end
		last = k
		if Usable(list[k]) then
			run[#run + 1] = list[k]
		elseif list[k].row then
			list[k].row.frame:Hide()
		end
	end
	local x, width = PAD_LEFT + Indent(e), CONTENT_W - Indent(e)
	local colW = math.floor((width - (cols - 1) * GAP) / cols)
	local fits = true
	for _, r in ipairs(run) do
		if NaturalWidth(r) > colW then fits = false end
	end
	if not fits then
		for _, r in ipairs(run) do y = y + Place(r, PAD_LEFT + Indent(r), y, CONTENT_W - Indent(r)) + ROW_GAP end
		return y, last + 1
	end
	local col, tallest = 0, 0
	for _, r in ipairs(run) do
		tallest = math.max(tallest, Place(r, x + col * (colW + GAP), y, colW))
		col = col + 1
		if col == cols then
			y, col, tallest = y + tallest + ROW_GAP, 0, 0
		end
	end
	if col > 0 then y = y + tallest + ROW_GAP end
	return y, last + 1
end

local function LayoutRows(sec, y)
	local list, i = sec.entries, 1
	while i <= #list do
		local e = list[i]
		local cols = e.layout.columns
		if e.layout.pair then
			y, i = PlacePairs(list, i, y)
		elseif not Usable(e) then
			if e.row then e.row.frame:Hide() end
			i = i + 1
		elseif cols and cols > 1 and e.kind ~= "multiselect" and e.kind ~= "never" then
			y, i = PlaceColumns(list, i, y)
		else
			y = y + Place(e, PAD_LEFT + Indent(e), y, CONTENT_W - Indent(e)) + ROW_GAP
			i = i + 1
		end
	end
	return y
end

local function SectionText(sec)
	if sec.def.title then return sec.def.title end
	local item = sec.headerItem
	return item and ns.WindowBind.Text(item, "name") or ""
end
UI.SectionText = SectionText

local function PlaceFold(sec, y)
	local b = sec.button
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", PAD_LEFT - 4, -y)
	b:SetWidth(CONTENT_W + 4)
	b.label:SetText(SectionText(sec))
	b.dot:ClearAllPoints()
	b.dot:SetPoint("LEFT", b.label, "LEFT", math.ceil(UI.TextWidth(b.label, 13)) + 8, 0)
	b.dot:SetShown(UI.FoldChanged(sec))
	-- Pointing right when shut, down when open.
	if UI.State().open[sec.key] then
		b.chevron:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
	else
		b.chevron:SetTexCoord(0, 1, 0, 1)
	end
	b:Show()
	sec.y = y
	return y + 26
end

-- The title, and its gold rule running on from it to the content's right
-- edge on the same line, fading out, as the mock-up and a model header row
-- (Widgets.lua) draw it.
local function PlaceTitle(sec, y)
	local child = UI.view.child
	sec.title:SetText(SectionText(sec))
	sec.title:ClearAllPoints()
	sec.title:SetPoint("TOPLEFT", child, "TOPLEFT", PAD_LEFT, -y)
	sec.title:Show()
	local h = UI.TextHeight(sec.title, 13)
	local from = math.min(math.ceil(UI.TextWidth(sec.title, 13)) + 10, CONTENT_W)
	local middle = -(y + math.floor(h / 2 + 0.5))
	sec.rule:ClearAllPoints()
	sec.rule:SetPoint("LEFT", child, "TOPLEFT", PAD_LEFT + from, middle)
	sec.rule:SetPoint("RIGHT", child, "TOPLEFT", PAD_LEFT + CONTENT_W, middle)
	sec.rule:Show()
	sec.y = y
	return y + h + 6
end

local function PlaceCaption(m, y)
	local cap = m.caption
	local text = cap.item and ns.WindowBind.Text(cap.item, "name")
	text = text and UI.Plain(text) or ""
	cap.text:SetWidth(CONTENT_W - 80)
	cap.text:SetText(text)
	local w = math.min(CONTENT_W - 80, UI.TextWidth(cap.text, 10))
	local h = UI.TextHeight(cap.text, 10)
	local mid = y + 6 + math.floor(h / 2)
	cap.text:ClearAllPoints()
	cap.text:SetPoint("TOP", UI.view.child, "TOPLEFT", PAD_LEFT + CONTENT_W / 2, -(y + 6))
	local side = math.max(8, math.floor((CONTENT_W - w) / 2) - 10)
	cap.left:ClearAllPoints()
	cap.left:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", PAD_LEFT, -mid)
	cap.left:SetWidth(side)
	cap.right:ClearAllPoints()
	cap.right:SetPoint("TOPRIGHT", UI.view.child, "TOPLEFT", PAD_LEFT + CONTENT_W, -mid)
	cap.right:SetWidth(side)
	UI.ShowCaption(m, true)
	return y + h + 16
end

local function LayoutSection(sec, y)
	if not sec.visible then
		HideSection(sec)
		return y
	end
	if sec.fold then
		y = PlaceFold(sec, y)
		if not UI.State().open[sec.key] then
			for _, e in ipairs(sec.entries) do
				if e.row then e.row.frame:Hide() end
			end
			return y + 2
		end
		y = y + 6
	elseif sec.title then
		y = PlaceTitle(sec, y)
	end
	return LayoutRows(sec, y) + SECTION_GAP
end

-- Every row re-reads its label, value and greyed-out state; the widget
-- leaves a slider being dragged and a box being typed in alone. A row that
-- throws is named once and left out of this paint.
local function RefreshRows(sec)
	for _, e in ipairs(sec.entries) do
		local row = e.row
		if row and e.visible then
			local ok, err = pcall(row.Refresh, row)
			if not ok then
				ns.Guard("options row " .. e.path, error, err, 0)
				e.visible = false
			end
		end
	end
end

-- layoutOnly: a row changed height by itself, so the rows are placed again
-- without being read again.
function UI.PaintPage(layoutOnly)
	local m = UI.Model(UI.page)
	BuildFrames(m)
	local y = PAD_TOP
	m.title:SetText(m.page.title or "")
	m.title:ClearAllPoints()
	m.title:SetPoint("TOPLEFT", UI.view.child, "TOPLEFT", PAD_LEFT, -y)
	m.title:Show()
	y = y + UI.TextHeight(m.title, 18) + 10
	local captioned, open = false, UI.State().open
	for _, sec in ipairs(m.sections) do
		-- A shut fold's rows are not drawn, so not read either.
		if Judge(sec) and not layoutOnly and not (sec.fold and not open[sec.key]) then RefreshRows(sec) end
		if sec.fold and sec.visible and not captioned then
			y = PlaceCaption(m, y)
			captioned = true
		end
		y = LayoutSection(sec, y)
	end
	if not captioned then UI.ShowCaption(m, false) end
	UI.SetContentHeight(y + PAD_BOTTOM)
end

---------------------------------------------------------------------------
-- finding a row: the search jump and the share box
---------------------------------------------------------------------------

-- Opens the page a control is on, its fold with it (remembered open), and
-- scrolls the row into view. Answers the entry, or nil when it is not shown.
function UI.Reveal(path)
	local w = UI.Where(path)
	if not w then return nil end
	if UI.page ~= w.page then UI.ShowPage(w.page) end
	if w.sec.fold then UI.State().open[w.sec.key] = true end
	UI.Refresh()
	if not UI.RowShown(path) then return nil end
	local e = w.e
	UI.ScrollTo(e.y - 30)
	return e
end

-- The row for a path on the page as built, for the search flash and tests.
function UI.RowFor(path)
	local w = UI.Where(path)
	return w and w.e.row or nil
end

-- Whether the row is drawn on the open page right now.
function UI.RowShown(path)
	local w = UI.Where(path)
	if not (w and w.page == UI.page and w.e.row and w.e.visible and w.sec.visible) then return false end
	if w.sec.fold and not UI.State().open[w.sec.key] then return false end
	return true
end
