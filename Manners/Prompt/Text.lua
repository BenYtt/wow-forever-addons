-- Manners -- the prompt's text: made legible on whatever ground the panel
-- gives it, and fitted to the room it has.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local unpackColor = lib.unpackColor

-- What ApplyStyle worked out about the ground the text stands on, read by the
-- painters and, through the kit, by a look from Looks/.
--
--   light   the text wants to be light: a dark panel, or no panel at all
--   lo, hi  the luminance of the panel's gradient ends, over the world
--   codes   colour codes already made legible on this ground, by code
local ink = { light = true, lo = 0, hi = 0, codes = {} }

-- The world is not ours to read, so a see-through panel is judged over a
-- dusky grey: usually dark, but not black.
local WORLD_GREY = 0.15

-- Coloured text is held to 3:1 against the panel (WCAG large text), and taken
-- to 4.5:1 once it has to move at all; the plain lines are held to 4.5:1.
local CODE_CONTRAST, TEXT_CONTRAST = 3, 4.5

-- Relative luminance as the web's contrast rules define it (the sRGB curve
-- off, then weighted). Rec. 601 answers "is this panel light"; this answers
-- "can this be read on it".
local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Luminance(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

local function Ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

-- Against the worse of the panel's two ends: the name sits near the light top
-- and the reason line near the dark bottom.
local function Contrast(r, g, b)
	local l = Luminance(r, g, b)
	return math.min(Ratio(l, ink.lo), Ratio(l, ink.hi))
end

-- A colour moved `t` of the way towards white or black; towards black by
-- scaling, so a class colour keeps its hue.
local function Toward(r, g, b, t)
	if ink.light then
		return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
	end
	return r * (1 - t), g * (1 - t), b * (1 - t)
end

-- The colour itself if it already reads on this panel, otherwise the nearest
-- colour towards white or black that does, so class colours and the reason
-- tint survive.
local function Legible(r, g, b, minimum)
	r = math.max(0, math.min(1, r))
	g = math.max(0, math.min(1, g))
	b = math.max(0, math.min(1, b))
	if Contrast(r, g, b) >= minimum then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if Contrast(Toward(r, g, b, t)) >= minimum then hi = t else lo = t end
	end
	return Toward(r, g, b, hi)
end

-- One |cAARRGGBB code made legible, cached per code (ApplyStyle empties the
-- cache): the same dozen codes are rewritten on every repaint.
local function LegibleCode(a, r, g, b)
	local key = a .. r .. g .. b
	local hit = ink.codes[key]
	if hit then return hit end
	-- Left alone if it clears 3:1, taken all the way to 4.5:1 if it has to
	-- move: stopped at 3:1, white on cream came out fainter than the plain
	-- text.
	local fr, fg, fb = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
	local nr, ng, nb = fr, fg, fb
	-- A look on a ground of its own may hold every code to more (the letter's
	-- parchment: the full 4.5:1 for all of them).
	local least = S.activeLook and S.activeLook.codeContrast or CODE_CONTRAST
	if Contrast(fr, fg, fb) < least then
		nr, ng, nb = Legible(fr, fg, fb, TEXT_CONTRAST)
	end
	hit = ("|c%s%02x%02x%02x"):format(a, math.floor(nr * 255 + 0.5),
		math.floor(ng * 255 + 0.5), math.floor(nb * 255 + 0.5))
	ink.codes[key] = hit
	return hit
end

-- Every colour code in a line of panel text, made legible: the lines carry
-- colours picked for the dark panel (class colours, white names, gold). A
-- secret string passes untouched: it cannot be read, and has no codes of ours.
local function LegibleText(text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return text end
	return (text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", LegibleCode))
end

-- How the name and reason line are laid out, kept by ApplyStyle for the
-- painters: fonts, current sizes, start, and the room kept at the right (more
-- while the count chip is up). `drawn` is each line's width at the size
-- FitLine left it, when FitLine measured it there, so a look need not measure
-- again. `paths` names a face for one line where a look sets it apart (the
-- name's), the rest keeping `path`; ApplyStyle empties it for every style.
local fit = { path = nil, flags = "", base = {}, size = {}, room = {}, drawn = {}, width = 0, textX = 0,
	chipRoom = 10, right = nil, twoLine = false, paths = {}, memo = {} }

-- The inset from the right-hand edge when nothing is beside the lines.
local EDGE_ROOM = 10
-- The least room the name is given between its two points (the looks keep the
-- same floor for theirs).
local MIN_ROOM = 20

-- How wide a line's text is, or nil when the client will not say. Unbounded
-- where possible, since a bounded width always fits. Made plain: a secret name
-- makes a secret width, which throws on the comparison.
local function TextWidth(fs)
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	if not measure then return nil end
	local ok, w = pcall(measure, fs)
	w = ok and ns.plain(w) or nil
	return type(w) == "number" and w or nil
end

-- A registered font file can still fail to load, and a font string left with
-- no font throws on SetText; the game's own font stands in. The saved choice
-- is left alone.
local function SafeFont(fs, path, size, flags)
	if not fs:SetFont(path, size, flags) or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

-- A line too long for its room is drawn up to a fifth smaller before the
-- client cuts it: German runs a third longer than English, and a list row
-- with a long name and a long spell name is longer still. A list row has a
-- width of its own; the panel's two lines end where PlaceLines put them.
--
-- `text` is what the line was just set to (SetLine passes it): the answer for
-- one text at one room, base size, face and outline is the same every time, so
-- the last one is kept per line (fit.memo, emptied by StyleText), and a
-- repaint of an unchanged line costs nothing: no measure, no font set. A
-- caller that does not know the text, or a secret one, measures as ever.
local function FitLine(fs, text)
	local base = fit.base[fs]
	if not base or not fit.path then return end
	local path = fit.paths[fs] or fit.path
	local room = fit.room[fs] or math.max(MIN_ROOM, fit.width - (fit.left or fit.textX) - (fit.right or EDGE_ROOM))
	local memo = text ~= nil and fit.memo[fs] or nil
	if memo and memo.text == text and memo.room == room and memo.base == base
		and memo.path == path and memo.flags == fit.flags then
		if fit.size[fs] ~= memo.size then
			SafeFont(fs, path, memo.size, fit.flags)
			fit.size[fs] = memo.size
		end
		fit.drawn[fs] = memo.width
		if S.activeLook then S.activeLook:Fitted(fs) end
		return
	end
	if fit.size[fs] ~= base then
		SafeFont(fs, path, base, fit.flags)
		fit.size[fs] = base
	end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	local size = base
	local w
	local measured = false
	while size > least do
		w = TextWidth(fs)
		if not w then break end
		measured = true
		if w <= room + 0.5 then break end
		size = size - 1
		SafeFont(fs, path, size, fit.flags)
		w = nil
	end
	fit.size[fs] = size
	fit.drawn[fs] = w
	-- Kept only when the client gave a width to go by (a line already at its
	-- floor is as good as measured: nothing can change its size).
	if text ~= nil and (measured or size <= least) then
		memo = fit.memo[fs]
		if not memo then
			memo = {}
			fit.memo[fs] = memo
		end
		memo.text, memo.room, memo.base, memo.path, memo.flags = text, room, base, path, fit.flags
		memo.size, memo.width = size, w
	else
		fit.memo[fs] = nil
	end
	if S.activeLook then S.activeLook:Fitted(fs) end
end

-- The one way text goes onto the name and the reason line: its colours made
-- legible on this panel, and the line fitted to its room. A reason line on a
-- look's own dark ground (subOnDark) keeps codes picked for a dark ground on
-- a light panel too: taken dark for the panel, they were dark on dark. So does
-- every line of a look whose whole ground is its own (inkOnDark: Leather's).
local function SetLine(fs, text)
	local look = S.activeLook
	if not ink.light and look and (look.inkOnDark or (fs == R.subText and look.subOnDark)) then
		fs:SetText(text)
	else
		text = LegibleText(text)
		fs:SetText(text)
	end
	-- A secret string cannot be compared, so it is fitted unremembered.
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then text = nil end
	FitLine(fs, text)
end

-- Where the name and reason line end on the right: clear of the count chip
-- while it is up, at the panel's inset while it is not (nearly always), so
-- longer translations get the room.
local function PlaceLines(chipUp)
	local right = chipUp and fit.chipRoom or EDGE_ROOM
	-- At the ends of the sliders (80 wide, a big font or icon) the two points
	-- would cross and the client has nothing to draw the name in: the name
	-- keeps MIN_ROOM, its left end moving in over the icon's margin where it
	-- must. (The chip is never up over less: ShowChip.)
	local left = math.min(fit.textX, math.max(0, fit.width - MIN_ROOM - right))
	if fit.right == right and fit.left == left then return end
	fit.left = left
	fit.right = right
	R.nameText:ClearAllPoints()
	R.subText:ClearAllPoints()
	if S.activeLook then
		S.activeLook:PlaceLines(right)
	elseif fit.twoLine then
		R.nameText:SetPoint("TOPLEFT", left, -8)
		R.nameText:SetPoint("RIGHT", -right, 0)
		R.subText:SetPoint("BOTTOMLEFT", left, 8)
		R.subText:SetPoint("RIGHT", -right, 0)
	else
		R.nameText:SetPoint("LEFT", left, 0)
		R.nameText:SetPoint("RIGHT", -right, 0)
	end
	FitLine(R.nameText)
	FitLine(R.subText)
end

-- The count chip up or down, and the lines beside it given their room.
local function ShowChip(on)
	on = on and true or false
	-- A look may refuse the chip for this paint, so the name keeps its room, and
	-- may widen the room it keeps for a long count (kit.fit.chipRoom): it works
	-- that out first, so the check below is against what this count needs and not
	-- what the last one did (a wide count once left a narrow prompt refusing every
	-- later one until the next restyle).
	if S.activeLook then on = S.activeLook:Chip(on) and true or false end
	-- No chip over a name with no room left beside it, on any look.
	if on and fit.width - fit.textX - fit.chipRoom < MIN_ROOM then
		on = false
		R.countText:SetText("")
		if S.activeLook then S.activeLook:Chip(false) end
	end
	if not S.activeLook then R.countChip:SetShown(on) end
	PlaceLines(on)
end

-- Whether the player picked the text colour. AceDB strips a value equal to its
-- default on save, so white chosen and white untouched look the same, and only
-- the second can be meant: nobody picks white text for a cream panel.
local function ChosenTextColor(c)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor or { 1, 1, 1, 1 }
	if type(c) ~= "table" then return false end
	for i = 1, 3 do
		if math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return true end
	end
	return false
end

-- The shadow for a text colour: black under light text, none under dark text,
-- where a black one smudges the letters and a light one reads as a blurred
-- second copy.
local function ShadowFor(fs, r, g, b, strength)
	if Ratio(Luminance(r, g, b), 0) >= Ratio(Luminance(r, g, b), 1) then
		fs:SetShadowColor(0, 0, 0, strength)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
	end
end

-- How tall the prompt must be for a second line at this font size. Published
-- so the options page states the same figure.
function ns.TwoLineHeight(fontSize, style)
	-- The look's own figure, for the look given or the one in use.
	local look = ns.Looks.Get(style or (ns.db and ns.db.profile.prompt.style))
	if look and look.TwoLineHeight then return look.TwoLineHeight(fontSize) end
	return 16 + fontSize + math.max(7, fontSize - 3)
end

-- The glass pane's grey over its middle cell, which the panel colour is drawn
-- through under the words: PANE_MID in tools/make_panel_textures.py, which
-- must agree.
local PANE_MID = 0.78

-- The greys under the name, for a panel and for none (brighter, carried by the
-- outline). `reason` is the list's dimmer grey, a colour code the row's text
-- colour cannot reach.
local GREYS = {
	panel = { sub = { 0.60, 0.61, 0.68 }, count = { 0.72, 0.73, 0.80 }, row = { 0.62, 0.63, 0.70 },
		reason = "|cff707078" },
	bare = { sub = { 0.86, 0.87, 0.92 }, count = { 0.92, 0.93, 0.96 }, row = { 0.86, 0.87, 0.92 },
		reason = "|cffbdbfd1" },
}

-- Everything about the text that depends on the ground: ink, fonts, colours,
-- shadows and where the lines stop. The ground is measured at both ends of the
-- panel's gradient. Out of ApplyStyle, for its upvalues.
local function StyleText(p, style, fontPath, textX, chipRoom, twoLine, countSize)
	local br, bg, bb, ba = unpackColor(p.bgColor, { 0.04, 0.04, 0.06, 0.88 })
	local bare = style == "minimal"
	if bare then
		local w = Luminance(WORLD_GREY, WORLD_GREY, WORLD_GREY)
		ink.lo, ink.hi = w, w
	else
		-- The same two stops the panel's gradient is drawn with. On the glass
		-- the colour is drawn through a pane (GlassPane.tga, a grey of PANE_MID
		-- over the middle cell the words sit on; its edge falls darker, but
		-- within four units of the panel's edge, where no line is), so the
		-- ink is judged against the pane as drawn under the words.
		local pane = 1
		if style == "glass" then pane = PANE_MID end
		local function over(c, k) return c * k * ba + WORLD_GREY * (1 - ba) end
		ink.lo = Luminance(over(br, 0.62 * pane), over(bg, 0.62 * pane), over(bb, 0.72 * pane))
		ink.hi = Luminance(over(br, pane), over(bg, pane), over(bb, pane))
	end
	local onWhite = math.min(Ratio(1, ink.lo), Ratio(1, ink.hi))
	local onBlack = math.min(Ratio(0, ink.lo), Ratio(0, ink.hi))
	ink.light = onWhite >= onBlack
	ink.codes = {}
	-- A grey warmed towards the reason colour reads on a dark ground and loses
	-- the contrast the plain grey had on a light one.
	S.tintSub = ink.light

	local outline = bare and "OUTLINE" or ""
	local greys = bare and GREYS.bare or GREYS.panel
	local subSize = math.max(7, p.fontSize - 3)

	fit.path, fit.flags, fit.paths = fontPath, outline, {}
	fit.width, fit.textX, fit.chipRoom, fit.twoLine = p.width, textX, chipRoom, twoLine
	fit.base[R.nameText], fit.base[R.subText] = p.fontSize, subSize
	fit.size, fit.memo = {}, {}
	SafeFont(R.nameText, fontPath, p.fontSize, outline)
	SafeFont(R.subText, fontPath, subSize, outline)
	fit.size[R.nameText], fit.size[R.subText] = p.fontSize, subSize

	-- The name in the colour the player picked, as it is. Left at the default,
	-- white or near-black, whichever this ground wants; the near-black held to
	-- the ground as the greys are, because the glass pane darkens a pale panel
	-- under it and the ink goes as dark as that needs.
	local r, g, b, a
	if ChosenTextColor(p.fontColor) then
		r, g, b, a = unpackColor(p.fontColor, { 1, 1, 1, 1 })
	else
		local _, _, _, alpha = unpackColor(p.fontColor, { 1, 1, 1, 1 })
		if ink.light then r, g, b = 1, 1, 1 else r, g, b = Legible(0.08, 0.08, 0.10, TEXT_CONTRAST) end
		a = alpha
	end
	R.nameText:SetTextColor(r, g, b, a)

	local sr, sg, sb = Legible(greys.sub[1], greys.sub[2], greys.sub[3], TEXT_CONTRAST)
	ink.sub = { sr, sg, sb }
	R.subText:SetTextColor(sr, sg, sb, 1)
	local cr, cg, cb = Legible(greys.count[1], greys.count[2], greys.count[3], TEXT_CONTRAST)
	SafeFont(R.countText, fontPath, countSize, outline)
	R.countText:SetTextColor(cr, cg, cb, 1)
	local qr, qg, qb = Legible(greys.row[1], greys.row[2], greys.row[3], TEXT_CONTRAST)
	ink.rowReason = greys.reason
	for _, fs in ipairs(R.queueRows) do
		SafeFont(fs, fontPath, subSize, outline)
		fit.base[fs], fit.size[fs] = subSize, subSize
		fs:SetTextColor(qr, qg, qb, 1)
	end

	-- Shadows: with no panel, full black under the outline, as the game's own
	-- floating text does; on a panel, one that suits the text colour. The count
	-- has no shadow on its chip.
	if bare then
		for _, fs in ipairs({ R.nameText, R.subText, R.countText }) do
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		end
		for _, fs in ipairs(R.queueRows) do
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		end
	else
		ShadowFor(R.nameText, r, g, b, 0.9)
		ShadowFor(R.subText, sr, sg, sb, 0.8)
		R.countText:SetShadowOffset(0, 0)
		for _, fs in ipairs(R.queueRows) do ShadowFor(fs, qr, qg, qb, 0.9) end
	end

	R.subText:SetShown(twoLine and true or false)
	-- Placed afresh: the inset, the fonts or the second line may all have
	-- changed under the anchors the lines already had.
	fit.right = nil
	PlaceLines(R.countChip:IsShown())
end

lib.ink, lib.fit, lib.GREYS = ink, fit, GREYS
lib.EDGE_ROOM, lib.TEXT_CONTRAST = EDGE_ROOM, TEXT_CONTRAST
lib.Legible, lib.TextWidth, lib.FitLine, lib.SetLine = Legible, TextWidth, FitLine, SetLine
lib.ShowChip, lib.StyleText = ShowChip, StyleText
