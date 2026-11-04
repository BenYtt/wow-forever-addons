-- Manners -- options window: the look picker, a gallery of cards. Added to the
-- kinds Widgets.lua started; see there for what a row is.
--
-- The layout places the model's Panel style (a select) with widget = "themes",
-- and this draws it in place of the dropdown: one card per look the registry
-- holds, in the dropdown's order (the dropdown is made from the same list), so
-- a look registered in Looks/ has a card with nothing more done (Looks.Card
-- says what it is called and how it is described). A card is a
-- picture of the look, its name and its line; the chosen one has a gold edge
-- and a tick, the one under the pointer a lighter edge, and a click sets the
-- control as the dropdown's pick does (Bind.Commit: the profile's style, then
-- Prompt:ApplyStyle, which waits for the end of a fight as every change on
-- this page does).
--
-- The pictures are Textures/Previews/Preview_<key>.tga, drawn by
-- tools/make_look_previews.py from the real look code on the mock client. They
-- are not live: a look keeps its regions on the one secure prompt and its text
-- layout in Prompt's own tables, so a second copy of one painting in a card is
-- not something the code can do, and nothing here touches the prompt but the
-- setting itself. So nothing in a card is secure, nothing runs on a timer, and
-- there is no OnUpdate to stop when the window closes. A look the tool has not
-- drawn has a card with the addon's icon where the picture goes.
--
-- Two things on a card are live, laid over the picture. The first is the spell icon. The picture holds a tile
-- where the look draws it (the tool has no game art), and a texture over the
-- picture, at the rectangle the tool recorded for that look (Looks.PreviewIcon),
-- shows the icon of the buff this character casts, cropped as the prompt crops
-- it. The client draws it; no spell art is in any file of the addon. A look
-- that cuts its icon round (Toast, Ribbon, Letter) has the same mask file on the
-- overlay; the others are square, as they are in the picture. A client without
-- mask textures (none of the five) draws them square. The texture is set when
-- the page is painted, so an icon the client had not loaded yet is there the
-- next time the page is drawn.
--
-- The second is the text. The pictures carry none (the tool leaves the
-- name and the reason line out of them), because a picture has one language.
-- Two font strings over each picture, at the rectangles the tool recorded for the
-- look's two lines (Looks.PreviewText), write a sample name, "Anna Aim", which is
-- a name and so the same in every language, and the reason a prompt gives for
-- somebody who buffed you in the client's own words (L["buffed you"], the
-- prompt's default for it, so no string is new). Each is written as the look
-- writes that line: its face where the looks use it (a Latin client, the player's
-- font the default one) else the prompt's own font, its size, colour, shadow and
-- outline, the size scaled with the picture. A line wider than its rectangle is
-- drawn up to a fifth smaller, then cut by the client, as the prompt's are. Set
-- when the page is painted and laid out; nothing is per frame.
--
-- A look that sets its reason line in a tag of its own (Luxe's pill) has the tag
-- drawn live as well, round the live words: baked into the picture it was the
-- English words' width, and a German or Korean reason ran past it. The tool
-- records the tag with the line (`pill`: its edges, how far it reaches past the
-- words on either side, its caps, and its layers, each the look's own file as a
-- horizontal three-slice in the look's colour), and the card lays those textures
-- over the picture, under the words, as wide as the words it has just measured.
--
-- Two or three cards to a row, as many as the page is wide enough for, every
-- row as tall as its tallest card.

local _, ns = ...
local W = ns.WindowWidgets
local T, KIND = W.Theme, W.KIND
local L = ns.L
local LSM = LibStub("LibSharedMedia-3.0")

local function Bind() return ns.WindowBind end

local GAP, PAD, TEXT_GAP = 10, 6, 6
-- The narrowest a card is drawn, and the most to a row.
local MIN_WIDTH, MAX_COLUMNS = 150, 3
-- Textures/Previews are 256 x 64.
local SHOT_RATIO = 4
local BADGE = 18
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"
-- The client's own question mark, for a character with no spell to show.
local UNKNOWN = 134400
-- How the prompt crops a spell icon (Prompt/Panel.lua).
local CROP = { 0.08, 0.92, 0.08, 0.92 }
-- The name the cards write: a name is not translated.
local SAMPLE_NAME = "Anna Aim"
-- The two lines, in the order the tool records them (Looks.PreviewText).
local LINES = { "name", "reason" }
-- The smallest letters a card writes, and how far a line is drawn smaller to fit.
local MIN_SIZE, MIN_SHRINK = 5, 0.8
-- A tag's three slices, cut from the file's quarters: the caps and the middle.
local CUTS = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
-- The sublevel the tag's first layer is drawn at, over the icon (3) and under
-- the lines (OVERLAY).
local PILL_LEVEL = 4
-- The client languages whose alphabet a look's own face (Morpheus) draws: the
-- rule the looks follow for their own text.
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true,
	itIT = true, ptBR = true }

local WASH_HOVER = { 1, 1, 1, 0.07 }
local WASH_ON = { T.gold[1], T.gold[2], T.gold[3], 0.08 }
local WASH_ON_HOVER = { T.gold[1], T.gold[2], T.gold[3], 0.14 }
local SHOT_GROUND = { 0.09, 0.10, 0.13 }
local SHOT_EDGE = { 0, 0, 0, 0.6 }
local BADGE_RING = { 0, 0, 0, 0.7 }
local BADGE_TICK = { 0.12, 0.09, 0.02 }

-- Four one-pixel lines round `anchor`, `out` units outside its edge (inside,
-- when negative).
local function Edges(owner, anchor, out, colour, layer, sublevel)
	local lines = {}
	local function line()
		local t = W.Solid(owner, layer, sublevel, colour)
		lines[#lines + 1] = t
		return t
	end
	local top = line()
	top:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
	top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
	top:SetHeight(1)
	local bottom = line()
	bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
	bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
	bottom:SetHeight(1)
	local left = line()
	left:SetPoint("TOPLEFT", anchor, "TOPLEFT", -out, out)
	left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -out, -out)
	left:SetWidth(1)
	local right = line()
	right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", out, out)
	right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", out, -out)
	right:SetWidth(1)
	return lines
end

local function ShowAll(list, on)
	for _, t in ipairs(list) do t:SetShown(on) end
end

local function Grey(c)
	return 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3]
end

-- The sample lines in their own colours, or grey and dimmed with the rest of a
-- greyed-out card; the tag round the reason goes grey with them.
local function TintLines(card, off)
	for _, name in ipairs(LINES) do
		local fs, spec = card.lines[name], card.textAt and card.textAt[name]
		if fs and spec then
			local c = spec.color
			if off then
				local grey = Grey(c)
				fs:SetTextColor(grey, grey, grey, c[4])
			else
				fs:SetTextColor(c[1], c[2], c[3], c[4])
			end
			fs:SetAlpha(off and 0.5 or 1)
		end
	end
	local pill = card.pillSpec
	for i, s in ipairs(card.pill) do
		local layer = pill and pill.layers[i]
		for _, t in ipairs(s) do
			if layer then
				local c = layer.color
				if off then
					local grey = Grey(c)
					t:SetVertexColor(grey, grey, grey, c[4])
				else
					t:SetVertexColor(c[1], c[2], c[3], c[4])
				end
			end
			t:SetAlpha(off and 0.5 or 1)
		end
	end
end

-- How a card reads: chosen, under the pointer, or at rest; and dimmed while
-- the control is greyed out.
local function Look(card)
	local row = card.row
	local off = row.off
	local on, hover = card.selected, card.hover and not off
	local edge = T.fieldEdge
	if off then
		edge = T.fieldOff
	elseif on then
		edge = T.gold
	elseif hover then
		edge = T.edgeHi
	end
	W.BorderColour(card.edges, edge)
	ShowAll(card.inner, on and true or false)
	card.wash:SetShown(on or hover or false)
	if on then
		W.Colour(card.wash, hover and WASH_ON_HOVER or WASH_ON)
	else
		W.Colour(card.wash, WASH_HOVER)
	end
	W.TextColour(card.title, off and T.dim or (on and T.gold or T.ink))
	W.TextColour(card.desc, off and T.dim or T.hint)
	card.badge:SetShown(on and true or false)
	-- Greyed out, the words go to the window's dim (the one tone that keeps
	-- its contrast) and the picture to grey; the card itself stays whole.
	card.shot:SetDesaturated(off and true or false)
	card.shot:SetAlpha(off and 0.5 or 1)
	-- The live icon over the picture goes grey with it.
	card.icon:SetDesaturated(off and true or false)
	card.icon:SetAlpha(off and 0.5 or 1)
	TintLines(card, off)
	card:SetEnabled(not off)
end

local function Clicked(card)
	local row = card.row
	if W.Off(row) or not card.key or card.selected then return end
	W.Apply(row, card.key)
end

local function Entered(card)
	card.hover = true
	Look(card)
end

local function Left(card)
	card.hover = false
	Look(card)
end

-- The icon the cards wear: the spell of the first buff the prompt would offer
-- this character (CastableBuffs, in the order the prompt walks them; the buff's
-- own icon from the capability probe, which is what the prompt's icon shows),
-- else the first of the class's own buffs it has learned (a hunter's aspect, a
-- shaman's shield), else the client's question mark. Never the icon of a spell
-- the character cannot cast: a card promises what the prompt will show.
local function BuffIcon()
	local function file(info)
		local icon = info and info.icon
		if type(icon) == "number" or type(icon) == "string" then return icon end
	end
	for _, buff in ipairs(ns.CastableBuffs()) do
		local icon = file(ns.BuffInfo(buff))
		if icon then return icon end
	end
	local own = ns.caps.own
	for _, family in ipairs(ns.GetOwnFamilies() or {}) do
		for _, spell in ipairs(family.spells or {}) do
			local info = own and own[spell.key]
			local icon = info and info.known and file(info)
			if icon then return icon end
		end
	end
	return UNKNOWN
end

-- The icon laid at its rectangle in the card's picture: the look's fractions of
-- the picture's width and height, from its top left. Placed when the picture's
-- size is known (Layout) and again when the card is given another look.
local function PlaceIcon(card)
	local at, w, h = card.at, card.picW, card.picH
	if not (at and w and h) then return end
	local icon = card.icon
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", card.ground, "TOPLEFT", at.l * w, -at.t * h)
	icon:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", at.r * w, -at.b * h)
end

-- The icon's shape: the look's own round mask on the overlay of a round look,
-- none on the others, as the prompt masks its icon where masks exist.
local function ShapeIcon(card, at)
	local icon = card.icon
	local round = at and at.round and at.mask and card.CreateMaskTexture and icon.AddMaskTexture
	if round then
		if not card.mask then card.mask = card:CreateMaskTexture() end
		card.mask:SetTexture(at.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		card.mask:ClearAllPoints()
		card.mask:SetAllPoints(icon)
		if not card.masked then
			icon:AddMaskTexture(card.mask)
			card.masked = true
		end
	elseif card.masked then
		icon:RemoveMaskTexture(card.mask)
		card.masked = false
	end
end

-- A card's live icon, for the look it is showing: `at` is where that look's
-- picture holds its icon (nil for a look without one), `file` the spell icon.
-- card.at and card.iconFile are kept for the tests.
local function DressIcon(card, at, file)
	local icon = card.icon
	card.at = at
	if not at then
		ShapeIcon(card, nil)
		card.iconFile = nil
		icon:Hide()
		return
	end
	card.iconFile = file
	icon:SetTexture(file)
	local crop = at.crop or CROP
	icon:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
	ShapeIcon(card, at)
	PlaceIcon(card)
	icon:Show()
end

-- The face a line is written in: the look's own where the looks use it (a client
-- whose alphabet it has, the player's font the default one: AceDB strips a value
-- equal to the default, so only another is a choice), else the prompt's own font.
local function LineFace(spec)
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	if spec.font then
		local own = ns.defaults and ns.defaults.profile.prompt.font
		local chosen = p and type(p.font) == "string" and p.font ~= own
		if not chosen and (not spec.latin or LATIN[ns.LOCALE or "enUS"]) then return spec.font end
	end
	return p and LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
end

local function SetFace(fs, path, size, flags)
	if not fs:SetFont(path, size, flags) or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

-- A shadow offset in the picture's units, a whole unit at the least: a fraction
-- of one is no shadow.
local function Offset(v)
	local n = math.max(1, math.floor(math.abs(v) + 0.5))
	return v < 0 and -n or n
end

-- The tag's slices for its layer `i`, made the first time a look asks for them.
local function PillSlices(card, i)
	local s = card.pill[i]
	if s then return s end
	s = {}
	for j = 1, 3 do
		local t = card:CreateTexture(nil, "ARTWORK", nil, math.min(7, PILL_LEVEL + i - 1))
		t:SetTexCoord(CUTS[j][1], CUTS[j][2], 0, 1)
		t:Hide()
		s[j] = t
	end
	card.pill[i] = s
	return s
end

local function HidePill(card, from)
	for i = from or 1, #card.pill do
		for _, t in ipairs(card.pill[i]) do t:Hide() end
	end
	if not from then card.pillSpec, card.pillBox = nil, nil end
end

-- The tag a look sets its reason line in, round the line as the card has just
-- fitted it: it reaches `lead` and `tail` past the words (what the line
-- measures, or its rectangle where the client is left to cut it), its edges and
-- its caps scaled with the picture as the letters are, each layer the look's own
-- file in the look's own colour. So a reason in any language wears a tag of its
-- own width, as it does on the prompt. card.pillBox is kept for the tests.
local function PlacePill(card, spec, fs, room)
	local pill = spec.pill
	if not pill then
		HidePill(card)
		return
	end
	local w, h = card.picW, card.picH
	local top, bottom = pill.t * h, pill.b * h
	local height = bottom - top
	local cap = (pill.cap or 0.5) * height
	local left = spec.l * w - pill.lead * h
	local right = spec.l * w + math.min(W.Measure(fs), room) + pill.tail * h
	card.pillSpec, card.pillBox = pill, { left, top, right, bottom }
	for i, layer in ipairs(pill.layers) do
		local s = PillSlices(card, i)
		for _, t in ipairs(s) do
			t:SetTexture(layer.file)
			t:ClearAllPoints()
		end
		s[1]:SetPoint("TOPLEFT", card.ground, "TOPLEFT", left, -top)
		s[1]:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", left + cap, -bottom)
		s[3]:SetPoint("TOPLEFT", card.ground, "TOPLEFT", right - cap, -top)
		s[3]:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", right, -bottom)
		s[2]:SetPoint("TOPLEFT", card.ground, "TOPLEFT", left + cap, -top)
		s[2]:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", right - cap, -bottom)
		for _, t in ipairs(s) do t:Show() end
	end
	HidePill(card, #pill.layers + 1)
end

-- One line at its rectangle in the picture, in the look's face, at the look's
-- size for this picture (a card's picture is smaller than the 248 x 62 units the
-- tool drew), drawn up to a fifth smaller where the words are wider than the
-- rectangle; what is still too wide the client cuts, as the prompt's lines are.
-- The reason line's tag, where its look has one, is laid round it.
local function PlaceLine(card, name, spec, text)
	local fs, w, h = card.lines[name], card.picW, card.picH
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", card.ground, "TOPLEFT", spec.l * w, -spec.t * h)
	fs:SetPoint("BOTTOMRIGHT", card.ground, "TOPLEFT", spec.r * w, -spec.b * h)
	fs:SetJustifyH(spec.h or "LEFT")
	fs:SetJustifyV(spec.v or "MIDDLE")
	fs:SetWordWrap(false)
	local shadow = spec.shadow
	if shadow then
		local c = shadow.color
		fs:SetShadowColor(c[1], c[2], c[3], c[4])
		fs:SetShadowOffset(Offset(shadow.x * h), Offset(shadow.y * h))
	else
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
	end
	local path, flags = LineFace(spec), spec.flags or ""
	local base = math.max(MIN_SIZE, math.floor(spec.size * h + 0.5))
	local least = math.max(MIN_SIZE, math.floor(base * MIN_SHRINK + 0.5))
	local room = (spec.r - spec.l) * w
	local size = base
	SetFace(fs, path, size, flags)
	fs:SetText(text)
	while size > least and W.Measure(fs) > room + 0.5 do
		size = size - 1
		SetFace(fs, path, size, flags)
	end
	-- Kept for the tests: the client has no call that reads the size back.
	card.lineSize[name], card.lineFace[name] = size, path
	if name == "reason" then PlacePill(card, spec, fs, room) end
	fs:Show()
end

-- A card's two lines, for the look it is showing: `at` is what the look's
-- picture records for them (nil for a look without any). card.textAt and the
-- rest are kept for the tests. Placed once the picture's size is known (Layout)
-- as well as here, which is when the language and the player's font are read.
local function PlaceText(card)
	local at, w, h = card.textAt, card.picW, card.picH
	for _, name in ipairs(LINES) do
		local spec = at and at[name]
		if spec and w and h then
			PlaceLine(card, name, spec, name == "name" and SAMPLE_NAME or L["buffed you"])
		else
			card.lines[name]:Hide()
			card.lineSize[name], card.lineFace[name] = nil, nil
			if name == "reason" then HidePill(card) end
		end
	end
end

local function DressText(card, at)
	card.textAt = at
	PlaceText(card)
end

local function BuildCard(row, i)
	local card = CreateFrame("Button", nil, row.frame)
	card:RegisterForClicks("LeftButtonUp")
	card.row = row
	card.fill = W.Solid(card, "BACKGROUND", -2, T.field)
	card.fill:SetAllPoints(card)
	card.wash = W.Solid(card, "BACKGROUND", -1, WASH_HOVER)
	card.wash:SetAllPoints(card)
	card.wash:Hide()
	card.edges = W.Border(card, T.fieldEdge)
	card.inner = Edges(card, card, -1, T.gold, "BORDER", 2)
	ShowAll(card.inner, false)

	-- The picture, on a ground of its own that shows through where there is
	-- none yet, with the addon's icon on it.
	card.ground = W.Solid(card, "ARTWORK", 0, SHOT_GROUND)
	card.shot = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.mark = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.mark:SetTexture(ICON)
	card.mark:SetAlpha(0.35)
	card.mark:SetSize(32, 32)
	card.mark:SetPoint("CENTER", card.ground, "CENTER", 0, 0)
	card.shotEdges = Edges(card, card.ground, 1, SHOT_EDGE, "ARTWORK", 2)
	-- The spell icon, over the tile the picture draws there (see the header).
	card.icon = card:CreateTexture(nil, "ARTWORK", nil, 3)
	card.icon:Hide()
	-- The tag round the reason line, for a look that has one: its slices are
	-- made when a look first asks for them (PillSlices).
	card.pill = {}
	-- The sample name and reason over the picture, in a layer above the icon's.
	card.lines, card.lineSize, card.lineFace = {}, {}, {}
	for _, name in ipairs(LINES) do
		local fs = W.Text(card, T.fonts.small, T.ink, "OVERLAY")
		fs:Hide()
		card.lines[name] = fs
	end

	card.title = W.Text(card, T.fonts.label, T.ink)
	card.title:SetWordWrap(false)
	card.desc = W.Wrapping(W.Text(card, T.fonts.small, T.hint))
	if card.desc.SetMaxLines then card.desc:SetMaxLines(2) end

	-- The tick for the chosen one: a gold disc on a dark ring, over the
	-- picture's corner, in a frame of its own so it draws over it.
	card.badge = CreateFrame("Frame", nil, card)
	card.badge:SetSize(BADGE, BADGE)
	card.badge:SetPoint("TOPRIGHT", card.ground, "TOPRIGHT", -4, -4)
	local ring = card.badge:CreateTexture(nil, "OVERLAY", nil, 1)
	ring:SetTexture(ROUND)
	ring:SetSize(BADGE + 4, BADGE + 4)
	ring:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
	W.Colour(ring, BADGE_RING)
	local disc = card.badge:CreateTexture(nil, "OVERLAY", nil, 2)
	disc:SetTexture(ROUND)
	disc:SetAllPoints(card.badge)
	W.Colour(disc, T.gold)
	local tick = card.badge:CreateTexture(nil, "OVERLAY", nil, 3)
	tick:SetTexture(CHECK)
	tick:SetSize(BADGE + 6, BADGE + 6)
	tick:SetPoint("CENTER", card.badge, "CENTER", 0, 0)
	W.Colour(tick, BADGE_TICK)
	card.badge:Hide()

	card:SetScript("OnClick", function(self) ns.Guard("options look", Clicked, self) end)
	card:SetScript("OnEnter", function(self) ns.Guard("options look", Entered, self) end)
	card:SetScript("OnLeave", function(self) ns.Guard("options look", Left, self) end)
	row.cards[i] = card
	return card
end

KIND.themes = {
	Build = function(row)
		row.cards = {}
		row.count = 0
		row.cols = 1
	end,

	Refresh = function(row)
		-- The registry's list, as the dropdown is made from it, asked at every
		-- paint: a look registered since has a card the next time the page
		-- is drawn.
		local _, values = ns.Looks.Choices()
		local now = Bind().Value(row.item)
		-- One icon for every card, asked at every paint.
		local spell = BuffIcon()
		for i, key in ipairs(values) do
			local card = row.cards[i] or BuildCard(row, i)
			card.key = key
			card.selected = now ~= nil and now == key
			-- The pointer may have left while the page was away.
			card.hover = card.hover and card:IsMouseOver() or false
			local title, line = ns.Looks.Card(key)
			card.title:SetText(W.Trim(title))
			card.desc:SetText(W.Trim(line))
			local file = ns.Looks.PreviewFile(key)
			-- Kept for the tests: the client has no call that reads a texture's
			-- file back.
			card.file = file
			if file then
				card.shot:SetTexture(file)
				card.shot:Show()
				card.mark:Hide()
			else
				card.shot:Hide()
				card.mark:Show()
			end
			DressIcon(card, file and ns.Looks.PreviewIcon(key), spell)
			DressText(card, file and ns.Looks.PreviewText(key))
			Look(card)
			card:Show()
		end
		for i = #values + 1, #row.cards do row.cards[i]:Hide() end
		local was = row.count
		row.count = #values
		if was ~= nil and was ~= row.count and was > 0 then W.Relayout(row) end
	end,

	Layout = function(row, width)
		local count = row.count
		if count == 0 then return 0 end
		local cols = math.max(1, math.min(MAX_COLUMNS, math.floor((width + GAP) / (MIN_WIDTH + GAP))))
		cols = math.min(cols, count)
		row.cols = cols
		local base = math.floor((width - (cols - 1) * GAP) / cols)
		local extra = (width - (cols - 1) * GAP) - base * cols
		-- One height for every picture, so the names line up across a row.
		local shotH = math.floor((base - 2 * PAD) / SHOT_RATIO + 0.5)
		local y, i = 0, 1
		while i <= count do
			local last = math.min(count, i + cols - 1)
			local x, tallest = 0, 0
			-- Every card of the row, the first few a unit wider where the
			-- width does not divide, so the row runs the whole width.
			local sized = {}
			for k = i, last do
				local card = row.cards[k]
				local w = base + ((k - i) < extra and 1 or 0)
				local inner = w - 2 * PAD
				card.title:SetWidth(inner)
				card.desc:SetWidth(inner)
				local titleH = math.ceil(W.TextHeight(card.title))
				local descH = math.ceil(W.TextHeight(card.desc))
				local h = PAD + shotH + TEXT_GAP + titleH + (descH > 0 and 2 + descH or 0) + PAD
				sized[#sized + 1] = { card = card, w = w, h = h, inner = inner, shotH = shotH, titleH = titleH }
				tallest = math.max(tallest, h)
			end
			for _, s in ipairs(sized) do
				local card = s.card
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", row.frame, "TOPLEFT", x, -y)
				card:SetSize(s.w, tallest)
				card.ground:ClearAllPoints()
				card.ground:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -PAD)
				card.ground:SetSize(s.inner, s.shotH)
				card.shot:ClearAllPoints()
				card.shot:SetAllPoints(card.ground)
				card.picW, card.picH = s.inner, s.shotH
				PlaceIcon(card)
				PlaceText(card)
				card.title:ClearAllPoints()
				card.title:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(PAD + s.shotH + TEXT_GAP))
				card.desc:ClearAllPoints()
				card.desc:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(PAD + s.shotH + TEXT_GAP + s.titleH + 2))
				card.x, card.y, card.w, card.h = x, y, s.w, tallest
				x = x + s.w + GAP
			end
			y = y + tallest + GAP
			i = last + 1
		end
		return y - GAP
	end,

	Natural = function() return MIN_WIDTH end,
}
