-- Manners -- the Ribbon look: a length of crimson cloth with a forked end, edged
-- in gold, and a round gold medallion lying over its left end with the spell
-- cut round into it.
--
-- It is an object, not a panel. The cloth is opaque (its alpha is 1 at rest:
-- tests/scenarios/look-ribbon.lua holds it there), lit from the top, shaded at
-- the hem and edged in two gold rails that follow the fork. The medallion is
-- the prompt's height, a little less: a beaded gold lip, a channel of enamel,
-- a rounded bezel, and the spell in the middle, round. The name stands on the
-- cloth in warm gold with a dark shadow, the reason under it in pale peach.
--
-- WHERE THE REASON IS. The ribbon stays crimson, because that is the object;
-- the reason is the enamel ring in the medallion (the exact colour of the
-- player's palette, fired a little deeper where it would be one more ring of
-- gold) and, for the "stripe" markers, the cloth itself, dyed deep in the
-- reason's colour (Dye): crimson for somebody owed, a teal for your target, a
-- royal blue for your group, a slate for a passer-by, a plum for somebody who
-- asked. The colour-blind palette dyes by the same rule from its own colours,
-- keeping their order of lightness. "Ring around the icon" is the enamel,
-- "Stripe on the left edge" is the cloth, "Both" is both and "None" is a dark
-- enamel and crimson cloth. Every dye is held to the contrast the name needs
-- on it (look-ribbon.lua reads the numbers).
--
-- THE FONT. The serif the game itself sets quest titles in, Morpheus, which
-- every client ships (Blizzard_Fonts_Shared, QuestFont and Fancy fonts,
-- alphabet "roman") for the languages written in Latin letters. The client
-- languages that are not -- Korean, both Chinese and Russian -- keep the font
-- their client draws its writing in, and so does a player who chose a font of
-- their own.
--
-- The art is Textures/Ribbon, drawn by tools/make_ribbon_textures.py, every
-- surface modelled in relief and lit from the upper left. The gold and the
-- badge's enamel are baked; the cloth, the ring's enamel and the gem are grey,
-- coloured here. The interface this file implements is described at the top
-- of Looks/Looks.lua.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Ribbon\\Ribbon_"

local Ribbon = ns.Looks.Register("ribbon", {
	name = L["Ribbon -- a crimson ribbon and a gold medallion"],
	title = L["Ribbon"],
	description = L["a crimson ribbon and a gold medallion"],
	order = 4,
	-- The ribbon holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	-- Every line stands on cloth of the look's own (dyed deep, so always dark),
	-- whatever the panel colour: the colour codes of the name, the reason and
	-- the list are picked for a dark ground, and a pale panel colour must not
	-- take them darker, which on the crimson left the list's reasons black.
	subOnDark = true,
	inkOnDark = true,
})

-- The figures the generator draws to (tools/make_ribbon_textures.py): the rows
-- of a ribbon file and the width of the forked end, the fork's depth, the rows
-- the shadow's canvas leaves round the ribbon, and the medallion's radii and
-- the rest as fractions of its file's half-width.
local RIBBON_PX, END_PX, NOTCH_PX, SHADOW_PX = 64, 32, 19, 56
local M_OUT, M_CH_OUT, M_CH_IN, M_BEZEL = 0.98, 0.85, 0.735, 0.635
local SHADE_FILL, RING_PEAK, RING_EDGE = 0.70, 0.70, 0.89
-- The texels of room the shadow's forked end keeps beyond the cloth's tip.
local SHADOW_ROOM = 0
-- The icon's mask file is drawn to this fraction of its half-width.
local MASK_FILL = 0.985

-- The cloth's brightest dye for somebody owed, and the greys the art lies in.
local CRIMSON = { 0.78, 0.14, 0.14 }
-- Each reason's cloth, standard palette: the brightest tone of the dye (the
-- art's lightest tone multiplies it by 0.93 and its hem by 0.55).
local DYES = {
	owed = CRIMSON,
	target = { 0.04, 0.43, 0.55 },
	group = { 0.14, 0.27, 0.82 },
	nearby = { 0.36, 0.39, 0.53 },
	asked = { 0.72, 0.15, 0.53 },
}
DYES.self = DYES.group
-- How bright the art's lit top is (the name stands on cloth up to this
-- grey), and the relative luminance the dyes are held to there.
local LIT_GREY = 0.935
-- The contrast the reason line and the verdict are held to on the cloth.
local READ = 4.6
local DYE_LUMA, DYE_LUMA_LOW, DYE_LUMA_HIGH = 0.105, 0.016, 0.125
-- The ink: the name in warm gold, the reason in pale peach, a shadow of dark
-- crimson under both (the emboss of lettering raised on a banner); the key's
-- ink dark on its gold tag, the count's pale gold on its badge's enamel.
local GOLD_INK = { 1.00, 0.88, 0.54 }
local PEACH = { 1.00, 0.88, 0.80 }
local SHADOW = { 0.16, 0.02, 0.03 }
local TAG_INK = { 0.27, 0.05, 0.04 }
local BADGE_INK = { 1.00, 0.90, 0.62 }
local ROW_INK = { 1.00, 0.89, 0.80 }
-- The enamel with the marker switched off, and with a reason it has none for.
local NEUTRAL = { 0.34, 0.10, 0.09 }
-- The outcomes' own colours, for the enamel and the verdict.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
local VERDICT = {
	cast = { 0.80, 1.00, 0.78 },
	failed = { 1.00, 0.84, 0.62 },
	sent = PEACH,
}
-- The gold in a fight: bronze, never grey; the cloth dims, the icon greys.
local GOLD_COMBAT, CLOTH_COMBAT, TEXT_COMBAT, ICON_COMBAT = { 0.66, 0.62, 0.56 }, 0.62, 0.86, 0.78
-- The owed breath: the medal's gold lit to this and back, this many breaths of
-- 2.6 s, then it settles.
local PULSE_PEAK, PULSE_ENAMEL = 0.60, 0.50
local BREATHS, BREATH = 3, 1.3
local PALE_GOLD = { 1.00, 0.86, 0.52 }
local COMMAND = "CLICK MannersPrompt:LeftButton"
-- The medallion's radius from which it carries the count as a badge on its rim,
-- and only while the badge is three quarters of that radius at most (a smaller
-- medallion, or a bigger font, would be mostly badge).
local MEDAL_BADGE_FROM = 16
-- The client languages whose "roman" alphabet Morpheus draws.
local FACE = "Fonts\\MORPHEUS.TTF"
local ROMAN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true }

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(8, fontSize - 3) end
local function NameSize(fontSize) return math.floor(fontSize * 1.1 + 0.5) end
local function Gap(fontSize) return math.max(1, fontSize * 0.1) end
-- How much taller than the cloth the medallion always stands, at the least.
local TALLER = 1.1

-- The name's size and the gap under it for two lines on cloth that holds
-- `inner` units between its rails, the reason line counted: the display face
-- at its own size, with its gap and two units to spare, where that fits (and
-- with `full`, only there); else the gap and the spare taken to a unit each and
-- the face a point smaller at a time, as far as a line too long for its room
-- is drawn (Prompt/Text.lua, FitLine) and never as small as the reason; last,
-- the same with nothing to spare (the lines' boxes then meet the rails, their
-- letters inside them). Nothing where even that does not fit.
local function Lines(fontSize, inner, full)
	local name, gap, sub = NameSize(fontSize), Gap(fontSize), SubSize(fontSize)
	if name + gap + sub + 2 <= inner then return name, gap end
	if full then return nil end
	for spare = 1, 0, -1 do
		for size = name, math.max(sub + 1, 7, math.floor(name * 0.8 + 0.5)), -1 do
			if size + 1 + sub + spare <= inner then return size, 1 end
		end
	end
	return nil
end

-- The ribbon and the medallion for a panel `W` by `H`, in units: the cloth's
-- rows, how far a texel of its files is drawn, the forked end and the fork,
-- the medallion's radius and its centre. The medallion is the prompt's height
-- less a margin for its shadow, held to half the width of a narrow panel.
-- With `two` (the font size) the prompt carries two lines, and where the cloth
-- is too narrow for them in the display face at its size it widens a unit at a
-- time, as far as keeps the medallion (with the icon off, the height it would
-- have) TALLER times the cloth, before the face gives way; `nameSz` and `gap`
-- are then the lines' (Lines, `full` passed on), nil where they do not fit.
local function Geometry(W, H, icon, two, full)
	local M = icon and math.min(H - 3, math.max(24, math.floor(W * 0.5))) or 0
	local ov = Clamp(math.floor(H * 0.115 + 0.5), 1, 14)
	if two then
		local least = math.max(1, math.ceil((H - (icon and M or H - 3) / TALLER) / 2 - 1e-6))
		while ov > least and not Lines(two, (H - 2 * ov) * (1 - 2 * 5.8 / RIBBON_PX), true) do ov = ov - 1 end
	end
	-- With no medallion the cloth has a forked end at each side, and the shadow
	-- under it ends are wider still (its canvas draws the cloth in 56 rows of
	-- 64): on a prompt much narrower than it is tall they would cross, and
	-- the middle pieces would be a negative width. The cloth is no taller than
	-- the ends leave room for.
	if not icon then ov = math.max(ov, math.ceil((H - W * 0.85) / 2)) end
	local g = { ov = ov, top = ov, bottom = H - ov }
	g.rh = g.bottom - g.top
	g.k = g.rh / RIBBON_PX
	g.endW = END_PX * g.k
	g.notch = NOTCH_PX * g.k
	-- The room the cloth leaves inside the rails.
	g.inner = g.rh * (1 - 2 * 5.8 / RIBBON_PX)
	if two then g.nameSz, g.gap = Lines(two, g.inner, full) end
	g.M, g.R = M, M / 2
	g.cx, g.cy = 1.5 + M / 2, H / 2
	g.half = g.R / M_OUT
	g.iconSize = math.floor(2 * M_BEZEL * g.half / MASK_FILL + 0.5)
	return g
end

-- The least height from which the cloth, widened as far as the medallion lets
-- it, holds the name, the gap and the reason between the rails: in the display
-- face at its size, or else in the face made smaller (Lines), but only from the
-- height at which the built-in look keeps the reason line, so the reason is
-- never dropped where that one keeps it and never squeezed in where it does
-- not. "From": so does every taller prompt (the cloth's margin is whole units,
-- and a prompt a unit taller can have a unit's less cloth).
function Ribbon.TwoLineHeight(fontSize)
	local function from(full)
		local function holds(H) return Geometry(200, H, true, fontSize, full).nameSz ~= nil end
		local H = 24
		while not (holds(H) and holds(H + 1) and holds(H + 2)) do H = H + 1 end
		return H
	end
	return math.min(from(true), math.max(from(false), ns.TwoLineHeight(fontSize, "glass")))
end

-- The enamel is the ring round the icon, the cloth is the stripe: the ring
-- needs the icon; the stripe is on every look with cloth to dye.
function Ribbon.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false,
		(mode == "stripe" or mode == "both")
end

-- The medallion is sized by the panel's height, so the icon is too. Options
-- says so with this.
function Ribbon.IconSize(p)
	return Geometry(p.width or 220, p.height or 44, true).iconSize
end

---------------------------------------------------------------------------
-- colour
---------------------------------------------------------------------------

local function Lin(c)
	if c <= 0.04045 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Lum(r, g, b)
	return 0.2126 * Lin(r) + 0.7152 * Lin(g) + 0.0722 * Lin(b)
end

-- The relative luminance of the cloth's lit top for a dye.
function Ribbon.TopLum(dye)
	return Lum(dye[1] * LIT_GREY, dye[2] * LIT_GREY, dye[3] * LIT_GREY)
end

-- A deep, saturated dye in the hue of (r, g, b), as bright as keeps the lit
-- top of the cloth at relative luminance `lum`.
local function Deep(r, g, b, lum)
	local hi, lo = math.max(r, g, b), math.min(r, g, b)
	if hi <= 0 then r, g, b, hi, lo = 0.5, 0.2, 0.2, 0.5, 0.2 end
	-- The hue at full value, its weakest channel taken most of the way to
	-- nothing.
	local floor = lo / hi
	local function hue(c)
		local v = c / hi
		local full = floor < 1 and (v - floor) / (1 - floor) or v
		return v + (full - v) * 0.85
	end
	local cr, cg, cb = hue(r), hue(g), hue(b)
	local function at(v) return cr * v, cg * v, cb * v end
	local low, high = 0.02, 1
	for _ = 1, 24 do
		local mid = (low + high) / 2
		local mr, mg, mb = at(mid)
		if Lum(mr * LIT_GREY, mg * LIT_GREY, mb * LIT_GREY) > lum then high = mid else low = mid end
	end
	return at(low)
end

local function Luma(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

-- The colour taken towards white as far as it takes to hold `ratio` to 1
-- against a ground of relative luminance `ground`.
local function Raise(r, g, b, ground, ratio)
	local function at(t) return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t end
	local function ok(t)
		local l = Lum(at(t))
		return (l + 0.05) / (ground + 0.05) >= ratio
	end
	if ok(0) then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 14 do
		local mid = (lo + hi) / 2
		if ok(mid) then hi = mid else lo = mid end
	end
	return at(hi)
end

local function Same(a, b)
	return math.abs(a[1] - b[1]) < 0.002 and math.abs(a[2] - b[2]) < 0.002 and math.abs(a[3] - b[3]) < 0.002
end

-- The cloth's dye for a reason: the table's for the standard palette, and for
-- the colour-blind palette or a colour of the player's own the same hue taken
-- deep, its lightness kept in the palette's order (the colour-blind set is
-- chosen to be told apart by lightness as well as hue) across the range the
-- name's contrast allows.
function Ribbon.Dye(r, g, b, reason, palette, byReason)
	if byReason ~= false and palette ~= "colourblind" and DYES[reason] then
		local d = DYES[reason]
		return d[1], d[2], d[3]
	end
	local lum = DYE_LUMA
	if byReason ~= false then
		lum = DYE_LUMA_LOW + (DYE_LUMA_HIGH - DYE_LUMA_LOW) * Clamp((Luma(r, g, b) - 0.35) / 0.60, 0, 1) ^ 1.5
	end
	return Deep(r, g, b, lum)
end

-- The enamel for a reason colour: a little richer, and a warm gold (the owed
-- amber) fired deeper to a honey, so it never reads as one more ring of gold.
local function Fired(r, g, b)
	local l = Luma(r, g, b)
	local k = 1.25
	local er, eg, eb = Clamp(l + (r - l) * k, 0, 1), Clamp(l + (g - l) * k, 0, 1), Clamp(l + (b - l) * k, 0, 1)
	if er > 0.9 and eb < 0.4 and eg > 0.55 * er and eg < 0.92 * er then
		er, eg, eb = er * 0.93, eg * 0.66, eb * 0.60
	end
	return er, eg, eb
end

-- Whether a stored colour is the default one: AceDB strips a value equal to its
-- default, so untouched and chosen-as-default look the same, and only the
-- first can be meant. The colour only: a panel or a text colour given another
-- opacity is still the colour it was (the cloth is opaque, whatever the panel's
-- opacity says; the lettering takes the opacity itself, Styled).
local function Untouched(c, d)
	if type(c) ~= "table" or type(d) ~= "table" then return true end
	for i = 1, 3 do
		if math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return false end
	end
	return true
end

-- Whether this client reads an English string in its own language: a German
-- player is better served by the lines that are translated than by English.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

-- The face for the names and the reason: Morpheus, unless the player chose a
-- font of their own (AceDB strips a value equal to the default, so only another
-- is a choice) or the client writes in an alphabet it lacks.
local function Face(p)
	local d = ns.defaults and ns.defaults.profile.prompt.font
	if type(p.font) == "string" and p.font ~= d then return nil end
	if not ROMAN[ns.LOCALE or "enUS"] then return nil end
	return FACE
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A texture over a box given from `rel`'s top left, y running down.
local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

local function Each(list, method, ...)
	for _, t in ipairs(list) do t[method](t, ...) end
end

-- A disc of radius `r` (to the file's edge `fill`) round (cx, cy).
local function Disc(t, rel, cx, cy, size)
	t:ClearAllPoints()
	t:SetPoint("CENTER", rel, "TOPLEFT", cx, -cy)
	t:SetSize(size, size)
end

-- A horizontal three-slice: caps half the height wide from the file's outer
-- quarters, the middle stretched.
local function ThreeSlice(parent, layer, sublevel, file, keep)
	local s = {}
	for i, cut in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(cut[1], cut[2], 0, 1)
		s[i] = keep(t)
	end
	return s
end

local function PlaceThree(s, box, height)
	local cap = height / 2
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[1]:SetWidth(cap)
	s[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[3]:SetWidth(cap)
	s[2]:SetPoint("TOPLEFT", s[1], "TOPRIGHT", 0, 0)
	s[2]:SetPoint("BOTTOMRIGHT", s[3], "BOTTOMLEFT", 0, 0)
end

-- The cloth's three pieces (the middle, the forked end, the end turned round
-- for a ribbon with no medallion: the file of the end with an L) as textures of
-- one kind.
local function Cloth(parent, layer, sublevel, mid, endFile, blend, keep)
	local set = {}
	for i, file in ipairs({ mid, endFile, endFile .. "L" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		if blend then t:SetBlendMode(blend) end
		set[i] = keep(t)
	end
	return set
end

-- The three pieces laid over a ribbon from x0 to x1 and top to bottom: the
-- fork on the right, and on the left either the medallion's place (no piece)
-- or the end turned round.
local function PlaceCloth(set, rel, x0, x1, top, bottom, endW, medallion)
	local from = medallion and x0 or x0 + endW
	Box(set[1], rel, from, top, x1 - endW, bottom)
	Box(set[2], rel, x1 - endW, top, x1, bottom)
	Box(set[3], rel, x0, top, x0 + endW, bottom)
	set[3]:SetShown(not medallion)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the texture it lights, parked at
-- alpha 0 between plays, so nothing is left lit when it stops
---------------------------------------------------------------------------

local function Park(group, region, to)
	local function park() region:SetAlpha(group.to or to or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Alpha(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down, delay, smoothing)
	local g = region:CreateAnimationGroup()
	g.up = Alpha(g, 0, peak, up, 1, delay, "OUT")
	g.down = Alpha(g, peak, 0, down, 2, nil, smoothing or "OUT")
	Park(g, region, 0)
	return g
end

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Ribbon:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local function keep(x) own[#own + 1] = x return x end
	local function anim(g) anims[#anims + 1] = g return g end
	local function tex(parent, layer, sublevel, file, blend)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end

	-- The ground: the ribbon's shadow, the medallion's shade, and the cloth
	-- and its rails over them. All on `art`, below the icon, so each can be
	-- animated by itself and the list's rows (art's font strings) stay over
	-- them.
	self.drop = Cloth(art, "BACKGROUND", -8, "Drop_Mid", "Drop_End", nil, keep)
	self.shade = tex(art, "BACKGROUND", -7, "Shade")
	self.cloth = Cloth(art, "BORDER", 0, "Cloth_Mid", "Cloth_End", nil, keep)
	self.trim = Cloth(art, "BORDER", 1, "Trim_Mid", "Trim_End", nil, keep)
	-- The refusal: the cloth darkens towards red, and flashes amber. The same
	-- cloth, drawn again, over the rails, parked at nothing.
	self.dark = Cloth(art, "BORDER", 2, "Cloth_Mid", "Cloth_End", nil, keep)
	self.hot = Cloth(art, "BORDER", 3, "Cloth_Mid", "Cloth_End", "ADD", keep)
	Each(self.dark, "SetAlpha", 0)
	Each(self.hot, "SetAlpha", 0)
	-- The shine that runs along the cloth when a buff lands.
	self.sweep = tex(art, "BORDER", 4, "Sweep", "ADD")
	self.sweep:SetAlpha(0)

	-- The list's ribbons: smaller, hanging from behind the main one.
	self.rowCloth, self.rowTrim, self.gems, self.gemSets = {}, {}, {}, {}
	for i = 1, #kit.rows do
		self.rowCloth[i] = Cloth(art, "BORDER", -3, "Cloth_Mid", "Cloth_End", nil, keep)
		self.rowTrim[i] = Cloth(art, "BORDER", -2, "Trim_Mid", "Trim_End", nil, keep)
		self.rowCloth[i][3]:Hide()
		self.rowTrim[i][3]:Hide()
		self.gems[i] = tex(art, "ARTWORK", 1, "Gem")
		self.gemSets[i] = tex(art, "ARTWORK", 2, "GemSet")
	end

	-- The rings that spread from the medallion when a buff lands, and the one
	-- that snaps in when one is refused: frames over the art, under the text,
	-- in the medallion's own ring of light. No echo: nothing lies over the icon.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do keep(f) end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)

	-- The medallion, from the bottom up: its gold, the enamel and the light it
	-- takes at the breath, the gloss on it, the warm light on the metal, the
	-- cursor's, and the well under the icon (ARTWORK 0).
	self.medal = tex(art, "ARTWORK", -8, "Medal")
	self.enamel = tex(art, "ARTWORK", -7, "Enamel")
	self.enamelLit = tex(art, "ARTWORK", -6, "Enamel")
	self.gloss = tex(art, "ARTWORK", -5, "Gloss")
	self.lit = tex(art, "ARTWORK", -4, "Lit")
	self.hover = tex(art, "ARTWORK", -3, "Lit")
	self.well = tex(art, "ARTWORK", -2, "Disc")
	self.glint = tex(art, "ARTWORK", 3, "Glint", "ADD")
	self.enamelLit:SetAlpha(0)
	self.lit:SetAlpha(0)
	self.hover:SetAlpha(0)
	self.glint:SetAlpha(0)
	-- With the icon off, a jewel at the ribbon's left end carries the reason.
	self.jewel = tex(art, "ARTWORK", 1, "Gem")
	self.jewelSet = tex(art, "ARTWORK", 2, "GemSet")

	-- The chips: the key's a small gold tag over the cloth at its right, the
	-- count's a gold badge with a field of enamel on the medallion's rim,
	-- their text on textLayer over them.
	local base = art:GetFrameLevel()
	self.chipFrame = keep(CreateFrame("Frame", nil, art))
	self.chipFrame:SetFrameLevel(base + 3)
	for _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end
	-- The boxes the tags are placed from are frames of the art's own, with
	-- nothing drawn on them, so no frame of the look reaches the text's level.
	self.chipBox = keep(CreateFrame("Frame", nil, art))
	self.keyBox = keep(CreateFrame("Frame", nil, art))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Badge", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Tag", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything gold: for the bronze of a fight.
	self.gold = { self.medal, self.jewelSet }
	for _, s in ipairs({ self.trim, self.chip, self.keyChip, self.gemSets }) do
		for _, t in ipairs(s) do self.gold[#self.gold + 1] = t end
	end
	for _, s in ipairs(self.rowTrim) do
		for _, t in ipairs(s) do self.gold[#self.gold + 1] = t end
	end

	self:BuildAnimations(anim)
end

function Ribbon:BuildAnimations(anim)
	-- The owed breath: the metal lit with pale gold and the enamel brightened,
	-- slowly; see Attention for how long.
	local pulse = self.lit:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	Alpha(pulse, 0, PULSE_PEAK, BREATH, 1, nil, "IN_OUT")
	local enamel = self.enamelLit:CreateAnimationGroup()
	enamel:SetLooping("BOUNCE")
	Alpha(enamel, 0, PULSE_ENAMEL, BREATH, 1, nil, "IN_OUT")
	self.pulse = { anim(pulse), anim(enamel) }

	-- Arrival: the cloth fades in, and (not on Calm) slides out from behind the
	-- medallion; the medallion glints. The slide is a translation of the pieces,
	-- placed that far left for the length of it and put home when it ends.
	self.fade, self.slide = {}, {}
	local pieces = {}
	for _, set in ipairs({ self.cloth, self.trim, self.drop }) do
		for _, t in ipairs(set) do pieces[#pieces + 1] = t end
	end
	for i, t in ipairs(pieces) do
		local fade = t:CreateAnimationGroup()
		Alpha(fade, 0, 1, 0.26, 1, nil, "OUT")
		self.fade[i] = anim(fade)
		local slide = t:CreateAnimationGroup()
		local move = slide:CreateAnimation("Translation")
		move:SetDuration(0.30)
		move:SetOrder(1)
		if move.SetSmoothing then move:SetSmoothing("OUT") end
		self.slide[i] = anim(slide)
		self.slide[i].move = move
	end
	-- The first of them carries the others home.
	local function home()
		if Ribbon.active and Ribbon.W then Ribbon:PlaceRibbon(0) end
	end
	self.slide[1]:SetScript("OnFinished", home)
	self.slide[1]:SetScript("OnStop", home)
	self.glintAnim = anim(Flash(self.glint, 1, 0.07, 0.40))

	-- A landing: the shine along the cloth, and the medallion's flash.
	local travel = self.sweep:CreateAnimationGroup()
	local move = travel:CreateAnimation("Translation")
	move:SetDuration(0.48)
	move:SetOrder(1)
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	Alpha(travel, 0, 1, 0.10, 1)
	Alpha(travel, 1, 0, 0.18, 1, 0.30)
	Park(travel, self.sweep, 0)
	self.travel = anim(travel)
	self.travelMove = move
	self.flash = anim(Flash(self.lit, 0.95, 0.07, 0.40))

	-- A refusal: the cloth darkens towards red and flashes amber.
	self.refuse = {}
	for i, t in ipairs(self.dark) do
		self.refuse[#self.refuse + 1] = anim(Flash(t, 0.55, 0.10, 0.40, nil, "IN_OUT"))
		self.refuse[#self.refuse + 1] = anim(Flash(self.hot[i], 0.50, 0.06, 0.30))
	end

	-- The cursor's light on the metal, both ways; from and to are set for each
	-- play.
	local hover = self.hover:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hover, 0)
	self.hoverAnim = anim(hover)
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

-- The ribbon's pieces, `dx` units from home (the slide that unfurls it).
function Ribbon:PlaceRibbon(dx)
	local g = self.g
	local x0, x1 = (self.showIcon and g.cx or 0) + dx, self.W + dx
	local art = self.kit.art
	for _, set in ipairs({ self.cloth, self.trim, self.dark, self.hot }) do
		PlaceCloth(set, art, x0, x1, g.top, g.bottom, g.endW, self.showIcon)
	end
	-- The shadow: the cloth's own silhouette, blurred, lower by a unit or
	-- three (the cloth stands a little off the world), drawn on a canvas of
	-- RIBBON_PX rows of which the cloth fills SHADOW_PX, and whose end keeps
	-- ROOM texels beyond the tip. One canvas texel is `s` units. On cloth
	-- widened for two lines (Geometry) the canvas is drawn a little shorter
	-- where it would reach out of the prompt, its blur fading out inside it.
	local s = g.rh / SHADOW_PX
	local mid = (g.top + g.bottom) / 2 + Clamp(g.rh * 0.05, 1, 3)
	local half = math.min(RIBBON_PX * s / 2, self.H - mid)
	local y0, y1 = mid - half, mid + half
	local d = self.drop
	local tip, room = (END_PX - SHADOW_ROOM) * s, SHADOW_ROOM * s
	local left = self.showIcon and x0 or x0 + tip
	Box(d[1], art, left, y0, x1 - tip, y1)
	Box(d[2], art, x1 - tip, y0, x1 + room, y1)
	Box(d[3], art, x0 - room, y0, x0 + tip, y1)
	d[3]:SetShown(not self.showIcon)
end

function Ribbon:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local showIcon = p.showIcon and true or false
	-- Two lines where Prompt draws two (the test it makes, Prompt/Panel.lua):
	-- the cloth widened and the face sized to hold them (Geometry).
	local two = p.showSub and H >= Ribbon.TwoLineHeight(fs) and fs or nil
	local g = Geometry(W, H, showIcon, two)
	self.g = g
	local nameSz, sub = g.nameSz or NameSize(fs), SubSize(fs)
	self.active = true
	self.p, self.W, self.H, self.above = p, W, H, above
	self.nameSz, self.sub, self.showIcon = nameSz, sub, showIcon
	-- How far apart the list's ribbons are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua).
	self.pitch = sub + 8

	self:PlaceRibbon(0)
	-- How far the ribbon slides out from behind the medallion.
	local slide = showIcon and Clamp(g.R * 0.55, 6, 24) or 0
	self.slideBy = slide
	for _, s in ipairs(self.slide) do s.move:SetOffset(slide, 0) end

	-- The medallion.
	local cx, cy, half = g.cx, g.cy, g.half
	self.cx, self.cy, self.R = cx, cy, g.R
	local size = 2 * half
	for _, t in ipairs({ self.medal, self.enamel, self.enamelLit, self.gloss, self.lit, self.hover }) do
		Disc(t, art, cx, cy, size)
	end
	-- The well under the icon, a hair wider than the icon's frame.
	Disc(self.well, art, cx, cy, 2 * M_BEZEL * half + 1)
	self.well:SetVertexColor(0.05, 0.02, 0.02, 1)
	-- The shade the medallion throws, its edge at SHADE_FILL of its file.
	self.shade:ClearAllPoints()
	self.shade:SetPoint("CENTER", art, "TOPLEFT", cx + 0.03 * g.M, -(cy + 0.045 * g.M))
	-- A little under the medallion, so only a crescent of it is seen.
	self.shade:SetSize(1.88 * g.R / SHADE_FILL, 1.88 * g.R / SHADE_FILL)
	self.shade:SetVertexColor(0, 0, 0, 0.62)
	-- The glint sits on the lip at the upper left.
	Disc(self.glint, art, cx - 0.60 * g.R, cy - 0.60 * g.R, 0.85 * g.R)
	self.glint:SetVertexColor(1, 0.92, 0.66, 1)
	self.lit:SetVertexColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	self.hover:SetVertexColor(1, 0.90, 0.62, 1)

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	local maskFile = ART .. "Mask"
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	if showIcon then
		icon:SetSize(g.iconSize, g.iconSize)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		-- The rings spread from the medallion's rim, in its ring of light.
		local ringHalf = g.R / RING_PEAK
		self.fx:Place(icon, ringHalf - g.iconSize / 2, g.iconSize)
		self.fx:Shape(true, ART .. "Ring", ART .. "Ring")
		self.textX = math.floor(cx + g.R + 5 + 0.5)
		local limitH = math.min(self.textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep has the icon's shape.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end

	-- With the icon off, a jewel at the ribbon's left end carries the reason.
	local jewel = Clamp(g.inner - 4, 8, 22)
	local jewelX = g.endW * 0.5 + jewel / 2 + 4
	for _, t in ipairs({ self.jewel, self.jewelSet }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", jewelX, -cy)
		t:SetSize(jewel, jewel)
	end
	if not showIcon then self.textX = math.floor(jewelX + jewel / 2 + 6 + 0.5) end
	-- The room the name always keeps at the right: the fork's depth and a margin.
	self.rightBase = math.ceil(g.notch + 8)

	local gap = g.gap or Gap(fs)
	local block = nameSz + gap + sub
	self.nameY = block / 2 - nameSz / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5

	-- The tags: height from the reason's size, inside the rails.
	local chipH = Clamp(sub + 5, 10, g.inner - 2)
	self.chipH = chipH
	-- The key's tag on the reason line is a little smaller, so it sits between
	-- the rails beside the reason; the count's badge on the medallion's rim is
	-- the same, where the medallion is big enough to carry one.
	self.smallH = Clamp(sub + 2, 9, chipH)
	self.medalOK = showIcon and g.R >= MEDAL_BADGE_FROM and self.smallH <= g.R * 0.75
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -(g.notch + 5), 0)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyLane, self.keyUp = nil, nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list's rows: one small ribbon each, from under the medallion to the
	-- right edge, the text on it.
	self.rowH = self.pitch - 2
	self.rowK = self.rowH / RIBBON_PX
	self.rowEnd = END_PX * self.rowK
	self.rowNotch = NOTCH_PX * self.rowK
	self.rowX = self.textX
	self.rowLeft = showIcon and (cx + 2) or 4
	local rowWidth = math.max(20, W - 5 - self.rowNotch - 4 - self.rowX)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.medal, self.enamel, self.enamelLit, self.gloss, self.lit, self.hover, self.well,
		self.glint, self.shade }) do
		t:SetShown(showIcon)
	end
	self.fx:SetShown(showIcon)
	self.cloth[3]:SetShown(not showIcon)
	self.trim[3]:SetShown(not showIcon)
	self.dark[3]:SetShown(not showIcon)
	self.hot[3]:SetShown(not showIcon)
	self.drop[3]:SetShown(not showIcon)
	for i = 1, #self.gems do
		self.gems[i]:Hide()
		self.gemSets[i]:Hide()
		Each(self.rowCloth[i], "Hide")
		Each(self.rowTrim[i], "Hide")
	end
	self.jewel:SetShown(not showIcon)
	self.jewelSet:SetShown(not showIcon)
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- The sweep runs from the cloth's left to the fork.
	local sweepW, sweepH = g.rh * 1.5, g.rh * 0.78
	self.sweep:ClearAllPoints()
	local from = (showIcon and cx or 0) + sweepW * 0.5
	self.sweep:SetPoint("CENTER", art, "TOPLEFT", from, -cy)
	self.sweep:SetSize(sweepW, sweepH)
	self.sweep:SetVertexColor(1, 0.90, 0.62, 0.9)
	self.travelMove:SetOffset(math.max(10, W - g.notch - 4 - sweepW - from + sweepW * 0.5), 0)
	Each(self.hot, "SetVertexColor", 1, 0.40, 0.10, 1)
	Each(self.dark, "SetVertexColor", 0.12, 0.0, 0.0, 1)

	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	self.dyeNow, self.ringNow = nil, nil
	self:Cloth()
	if held then self:Combat(true) end

	-- The count's room: a two-digit tag and its inset.
	-- Chip widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + 5 + self.rightBase
	return self.textX, self.roomBase
end

function Ribbon:Styled(p)
	local kit = self.kit
	local fit = kit.fit
	-- The face: Morpheus, in the sizes this look draws, unless the player chose
	-- a font or the client has no such file (the line then keeps what Prompt
	-- set).
	local face = Face(p)
	local nameSz, sub = self.nameSz or NameSize(p.fontSize), self.sub or SubSize(p.fontSize)
	local path = fit.path or STANDARD_TEXT_FONT
	if face then
		local tried = kit.name:SetFont(face, nameSz, fit.flags) and kit.name:GetFont()
		-- A face the client refuses leaves the line with no font: put Prompt's
		-- back.
		if tried then path = face else kit.name:SetFont(path, nameSz, fit.flags) end
	else
		kit.name:SetFont(path, nameSz, fit.flags)
	end
	fit.path = path
	local function set(fs, size)
		if not fs:SetFont(path, size, fit.flags) or not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, fit.flags) end
	end
	fit.base[kit.name], fit.size[kit.name] = nameSz, nameSz
	set(kit.sub, sub)
	fit.base[kit.sub], fit.size[kit.sub] = sub, sub
	set(kit.count, sub)
	set(self.keyText, sub)
	for _, fs in ipairs(kit.rows) do
		set(fs, sub)
		fit.base[fs], fit.size[fs] = sub, sub
	end

	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table" and not Untouched(p.fontColor, d)
	if not chosen then
		local alpha = type(p.fontColor) == "table" and tonumber(p.fontColor[4]) or 1
		kit.name:SetTextColor(GOLD_INK[1], GOLD_INK[2], GOLD_INK[3], Clamp(alpha, 0, 1))
		self.nameInk = GOLD_INK
	else
		self.nameInk = p.fontColor
	end
	-- A dark shadow of crimson, under the name and the reason: the cloth's own
	-- shade, as the lettering on a banner is raised.
	kit.name:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 1)
	kit.name:SetShadowOffset(1, -1)
	kit.sub:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.95)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are gold whatever the cloth: the key's text is a dark crimson
	-- on the gold, the count's pale gold on its badge's crimson enamel.
	kit.count:SetTextColor(BADGE_INK[1], BADGE_INK[2], BADGE_INK[3], 1)
	kit.count:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.9)
	kit.count:SetShadowOffset(1, -1)
	self.keyText:SetTextColor(TAG_INK[1], TAG_INK[2], TAG_INK[3], 1)
	self.keyText:SetShadowOffset(0, 0)
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(ROW_INK[1], ROW_INK[2], ROW_INK[3], 1)
		fs:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 1)
		fs:SetShadowOffset(1, -1)
	end
	kit.ink.rowReason = "|cffe0a592"
	-- The reason's ink follows the cloth it is on.
	self:Cloth()
end

function Ribbon:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	-- A glow parked after its Stop, and the cursor, who leaves for the next
	-- look.
	for _, t in ipairs({ self.lit, self.enamelLit, self.hover, self.glint, self.sweep }) do t:SetAlpha(0) end
	Each(self.dark, "SetAlpha", 0)
	Each(self.hot, "SetAlpha", 0)
	for _, x in ipairs(self.own) do x:Hide() end
	self.pulseGen = (self.pulseGen or 0) + 1
	-- The shared regions, as the other looks expect to find them.
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetVertexColor(1, 1, 1)
	icon:SetDesaturated(false)
	if kit.cooldown then
		kit.cooldown:SetAlpha(1)
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	kit.name:SetShadowOffset(1, -1)
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.listShown, self.countMode, self.keyLane, self.keyUp = nil, nil, nil, false
	self.dyeNow, self.ringNow = nil, nil
	self.mixedText = nil
end

---------------------------------------------------------------------------
-- the lines and the tags
---------------------------------------------------------------------------

function Ribbon:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- What stands at the right of the name line: a count's tag, a key's, or the
	-- pair. The key's tag on the reason line takes the room of the reason line
	-- alone, and the count's badge on the medallion takes none.
	local inset = math.max(right, self.rightBase)
	if self.keyLane == "name" then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
	-- The two points never cross: the name keeps 20 units, the room at the right
	-- gives way.
	local least = math.max(0, self.W - self.textX - 20)
	inset = math.min(inset, least)
	self.inset = inset
	self.lineRoom = math.max(20, self.W - self.textX - inset)
	fit.room[name] = self.lineRoom
	-- The reason line keeps clear of everything the name line does (a tag's
	-- height reaches into it), and of the key's tag on its own line.
	local subInset = inset
	if self.keyLane == "sub" then subInset = math.min(math.max(inset, self.keyRoom or 0), least) end
	self.subInset = subInset
	fit.room[sub] = math.max(20, self.W - self.textX - subInset)
	if fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -inset, self.nameY)
	else
		name:SetPoint("LEFT", self.textX, 0)
		name:SetPoint("RIGHT", -inset, 0)
	end
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -subInset, self.subY)
end

-- The name's class colour (when "Colour names by class" is on) is taken most
-- of the way to the warm gold the lettering is in, or to the colour the player
-- chose: the gold is the look, and no class colour reads on every dye.
local CLASS_SHARE = 0.30

function Ribbon:Fitted(fs)
	local kit = self.kit
	if fs ~= kit.name then return end
	local text = fs:GetText()
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
	if not text:find("|c%x%x%x%x%x%x%x%x") then return end
	-- A line refitted (the tags came or went) is the text this look wrote
	-- itself: taken to the gold once, not again.
	if text == self.mixedText then return end
	local to = self.nameInk or GOLD_INK
	local mixed = text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, r, g, b)
		local function mix(hex, target)
			local v = (tonumber(hex, 16) or 255) / 255
			return math.floor((target + (v - target) * CLASS_SHARE) * 255 + 0.5)
		end
		return ("|c%s%02x%02x%02x"):format(a, mix(r, to[1]), mix(g, to[2]), mix(b, to[3]))
	end)
	-- Colour codes have no width: what FitLine measured still holds.
	self.mixedText = mixed
	fs:SetText(mixed)
end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Ribbon:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, self.rightBase) + 0.5
end

-- Whether the reason, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip, while a key asks.
function Ribbon:SubFits(room)
	local kit = self.kit
	local sub, fit = kit.sub, kit.fit
	local width, size, base = self.subWidth, fit.size[sub], fit.base[sub]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, self.rightBase) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only where
-- a press casts something: the button armed (a fight's frozen macro too,
-- unlocked or not), never over a held panel with nothing armed, nor over an
-- outcome.
function Ribbon:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	if not (self.kit.button:GetAttribute("type1") or (ns.Prompt and ns.Prompt:InTest())) then return nil end
	local key = GetBindingKey(COMMAND)
	if type(key) ~= "string" or key == "" then return nil end
	if type(GetBindingText) == "function" then
		local text = ns.Looks.ShortKey(key)
		if type(text) == "string" and text ~= "" then key = text end
	end
	return key
end

-- The room the lines leave at the right for the key's tag with the count's
-- beside it: the key's room, a two-digit tag and the gap between them.
function Ribbon:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.rightBase - 4
end

-- Run on every repaint. Where the tags go, so that the name keeps its room:
--   the key's tag at the right end of the reason line, short of the fork, where
--   the reason leaves room for it; else at the right of the name line, where
--   the name does; else not at all (with two lines a tag is the reason's
--   height, so that one on each line never touch);
--   the count as a small gold badge on the medallion's rim, as a level badge
--   hangs on a portrait; with no medallion (or one too small), a tag at the
--   right of the name line, beside the key's if that is there too.
-- A tag steps aside for a paint in which the line it would stand on is cut.
function Ribbon:Chip(on)
	local kit = self.kit
	local fit = kit.fit
	-- The width FitLine took of the name just now (every paint sets it before
	-- the chip), measured here only where it could not; the tags' own words
	-- only when they change. Measured outright, it was a pcall on every
	-- repaint (Looks.lua: none on a per-scan path).
	self.nameWidth = fit.drawn[kit.name] or kit.TextWidth(kit.name)
	local two = fit.twoLine and true or false

	local key = self:KeyLabel()
	local lane
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(w + self.g.notch + 10)
			-- A key bound anew is a tag of a new width: Prompt places the
			-- lines again, beside it.
			fit.right = nil
		end
		if two then
			self.subWidth = fit.drawn[kit.sub] or kit.TextWidth(kit.sub)
			if self:SubFits(self.keyRoom) then lane = "sub" end
		end
		if not lane and self:NameFits(self.keyRoom) then lane = "name" end
	end
	if lane ~= self.keyLane then
		self.keyLane, self.keyUp = lane, lane ~= nil
		fit.right = nil
		if lane then
			-- The key's tag on the reason line is a little smaller, and sits on
			-- that line's own height.
			local h = two and self.smallH or self.chipH
			self.keyBox:ClearAllPoints()
			self.keyBox:SetPoint("RIGHT", kit.art, "RIGHT", -(self.g.notch + 5),
				lane == "sub" and self.subY or (two and self.nameY or 0))
			self.keyBoxH = h
			PlaceThree(self.keyChip, self.keyBox, h)
		end
	end
	if lane then self.keyBox:SetSize(math.floor(self.keyW + 0.5), self.keyBoxH) end
	for _, t in ipairs(self.keyChip) do t:SetShown(lane ~= nil) end
	self.keyText:SetShown(lane ~= nil)

	-- The count's tag is as wide as its words need, and the room the lines keep
	-- for it as wide too (never less than two digits', Apply's), so the name
	-- does not run under a count of three digits, nor under it beside a key's
	-- tag. Measured when its words change.
	if on then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		text = count:GetText()
		if text ~= self.countText then
			self.countText = text
			self.wordsW = (kit.TextWidth(count) or self.sub) + 8
		end
		local beside = math.max((two and self.smallH or self.chipH) * 1.6, self.wordsW)
		fit.chipRoom = math.max(self.roomBase or 0, math.floor(beside + 0.5) + 5 + self.rightBase)
	end
	local mode
	if on then
		if self.medalOK then
			mode = "medal"
		elseif lane == "name" then
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(fit.chipRoom or 0) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local h = (mode == "medal" or two) and self.smallH or self.chipH
		local w = math.floor(math.max(h * 1.6, self.wordsW) + 0.5)
		if mode ~= self.countMode or w ~= self.countBoxW then
			self.countBoxW = w
			self.chipBox:ClearAllPoints()
			if mode == "medal" then
				-- On the rim, at the lower right: as far round as keeps the badge
				-- off the lines, and in the panel.
				local g = self.g
				local dx = math.min(0.6 * g.R, g.R + 3 - w / 2)
				local dy = math.min(math.sqrt(math.max(0, g.R * g.R - dx * dx)), self.H / 2 - 1 - h / 2)
				self.chipBox:SetPoint("CENTER", kit.art, "TOPLEFT", g.cx + dx, -(g.cy + dy))
			elseif mode == "pair" then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			else
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -(self.g.notch + 5), two and self.nameY or 0)
			end
			PlaceThree(self.chip, self.chipBox, h)
			count:ClearAllPoints()
			count:SetPoint("CENTER", self.chipBox, "CENTER", 0, 0)
		end
		self.chipBox:SetSize(w, h)
	end
	if mode ~= self.countMode then fit.right = nil end
	self.countMode = mode
	for _, t in ipairs(self.chip) do t:SetShown(mode ~= nil) end
	kit.count:SetShown(mode ~= nil)
	-- Only a tag at the right of the name line takes room from the lines;
	-- PlaceLines gives a pair the room of both.
	return mode == "chip" or mode == "pair"
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The cloth's dye for the settings: crimson, or the colour the player gave the
-- panel, taken deep.
function Ribbon:BaseDye()
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = self.p and self.p.bgColor
	if Untouched(c, d) then return CRIMSON[1], CRIMSON[2], CRIMSON[3] end
	return Deep(c[1] or 0.5, c[2] or 0.2, c[3] or 0.2, DYE_LUMA)
end

-- Writes the cloth, the enamel and the ink their colours: the dye the cloth
-- wears, the enamel's, and the reason line's. Everything a fight dims is
-- dimmed here too, so a repaint cannot undo it.
function Ribbon:Cloth()
	if not self.dyeNow then
		local r, g, b = self:BaseDye()
		self.dyeNow, self.ringNow = { r, g, b }, NEUTRAL
	end
	local dye, ring = self.dyeNow, self.ringNow
	local k = self.combat and CLOTH_COMBAT or 1
	local kit = self.kit
	Each(self.cloth, "SetVertexColor", dye[1] * k, dye[2] * k, dye[3] * k, 1)
	local rk = k * 0.86
	for i, row in ipairs(self.rowCloth) do
		local rd = self.rowDye and self.rowDye[i] or dye
		Each(row, "SetVertexColor", rd[1] * rk, rd[2] * rk, rd[3] * rk, 1)
	end
	local gold = self.combat and GOLD_COMBAT or { 1, 1, 1 }
	for _, t in ipairs(self.gold) do t:SetVertexColor(gold[1], gold[2], gold[3], 1) end
	self.enamel:SetVertexColor(ring[1] * 0.92, ring[2] * 0.92, ring[3] * 0.92, 1)
	self.enamelLit:SetVertexColor(math.min(1, ring[1] * 1.25 + 0.1), math.min(1, ring[2] * 1.25 + 0.1), math.min(1, ring[3] * 1.25 + 0.1), 1)
	self.jewel:SetVertexColor(ring[1], ring[2], ring[3], 1)
	-- The reason line: pale peach, a little towards the dye where the cloth is
	-- dyed by the reason, never darker than the contrast it needs.
	local sr, sg, sb = PEACH[1], PEACH[2], PEACH[3]
	if self.verdictInk then
		sr, sg, sb = self.verdictInk[1], self.verdictInk[2], self.verdictInk[3]
	elseif self.dyed then
		local top = math.max(dye[1], dye[2], dye[3], 0.01)
		sr = PEACH[1] * 0.7 + (0.4 + 0.6 * dye[1] / top) * 0.3
		sg = PEACH[2] * 0.7 + (0.4 + 0.6 * dye[2] / top) * 0.3
		sb = PEACH[3] * 0.7 + (0.4 + 0.6 * dye[3] / top) * 0.3
	end
	-- Held to the contrast the name has on the lightest cloth under it.
	sr, sg, sb = Raise(sr, sg, sb, Lum(dye[1] * LIT_GREY, dye[2] * LIT_GREY, dye[3] * LIT_GREY), READ)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	kit.textLayer:SetAlpha(self.combat and TEXT_COMBAT or 1)
end

-- Reason, mode: "icon" is the enamel ring, "stripe" the cloth, "both" both,
-- "off" neither.
function Ribbon:PaintReason(r, g, b, reason, mode)
	mode = mode or "icon"
	local base = { self:BaseDye() }
	local p = ns.db and ns.db.profile.prompt or self.p or {}
	local ringOn = mode == "icon" or mode == "both"
	local clothOn = mode == "stripe" or mode == "both"
	if clothOn then
		local dr, dg, db = Ribbon.Dye(r, g, b, reason, p.reasonPalette, p.accentByReason)
		self.dyeNow = { dr, dg, db }
	else
		self.dyeNow = base
	end
	self.dyed = clothOn
	if ringOn then
		self.ringNow = { Fired(r, g, b) }
	else
		self.ringNow = NEUTRAL
	end
	self.reasonColour = { r, g, b }
	self.lastPaint = { r, g, b, reason, mode }
	-- A refusal greyed the icon; a fight keeps it grey.
	self.refused = nil
	self.verdictInk = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
	self:Cloth()
end

-- The banner holds; the gold dims to bronze, the cloth darkens, the icon greys
-- and the lights go out. The enamel keeps its colour: the reason is the one
-- coloured thing left.
function Ribbon:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Cloth()
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon showed the
	-- world through one half and the banner through the other.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	if on then
		self:StopAttention()
		self:StopFlourishes()
	end
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breathing, let go: after its breaths, and on Calm.
function Ribbon:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.lit:SetAlpha(0)
	self.enamelLit:SetAlpha(0)
end

-- A new favour: the cloth slides out from behind the medallion, fading in, and
-- the medallion glints; on Calm the cloth only fades in.
function Ribbon:Unfurl(full)
	PlayAll(self.fade)
	if full and self.slideBy > 0 then
		-- Stopped first, so the home its stop puts the ribbon back to is not
		-- put over the place it starts the slide from.
		for _, g in ipairs(self.slide) do g:Stop() end
		self:PlaceRibbon(-self.slideBy)
		for _, g in ipairs(self.slide) do g:Play() end
		if self.showIcon then self.glintAnim:Stop() self.glintAnim:Play() end
	end
end

function Ribbon:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent = nil
		-- The cloth's arrival.
		self:Unfurl(full)
	end
	if flashStyle ~= "pulse" then
		self:StopAttention()
		return
	end
	if not full or self.pulseSpent then
		-- Calm, or breathed its fill: nothing loops.
		self:HoldPulse()
		return
	end
	-- A repaint leaves a running pulse alone; a new favour on top keeps the
	-- breathing going but takes its own three breaths, not what is left of the
	-- last face's.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		self.lit:SetAlpha(0)
		self.enamelLit:SetAlpha(0)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Ribbon.pulseGen or not Ribbon.active then return end
			Ribbon.pulseSpent = true
			if Ribbon.pulse[1]:IsPlaying() then Ribbon:HoldPulse() end
		end)
	end
end

function Ribbon:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.lit:SetAlpha(0)
	self.enamelLit:SetAlpha(0)
end

function Ribbon:Flourish(kind)
	-- A fight is steady: the outcome is written (the verdict, the enamel) and
	-- nothing flashes.
	if self.combat then return end
	-- A refusal: the cloth darkens towards red and flashes amber, and one ring
	-- snaps in onto the medallion. The text's shake is Prompt's.
	if kind == "failed" then
		PlayAll(self.refuse)
		if self.kit.icon:IsShown() then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	-- A shine along the cloth and a flash of the medallion's gold.
	self.travel:Stop()
	self.travel:Play()
	if self.kit.icon:IsShown() then
		self.flash:Stop()
		self.flash:Play()
		self.glintAnim:Stop()
		self.glintAnim:Play()
		local o = OUTCOME.cast
		self.fx:Land(o[1], o[2], o[3], 0.70)
	end
end

function Ribbon:StopFlourishes()
	for _, g in ipairs(self.refuse) do g:Stop() end
	self.travel:Stop()
	self.flash:Stop()
	self.glintAnim:Stop()
	self.fx:Stop()
	-- The ribbon home: a slide stopped is put back (its first group's OnStop).
	for _, g in ipairs(self.slide) do g:Stop() end
	if self.W then self:PlaceRibbon(0) end
	-- The flash shared the pulse's light: a breath in progress goes on.
end

function Ribbon:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnim, self.hover
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 0.55 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so the
-- eye never has to find the person again. The enamel takes the outcome's
-- colour.
function Ribbon:PaintOutcome(kind, lead, sub, who, stamp)
	local kit = self.kit
	local o = OUTCOME[kind] or OUTCOME.cast
	local word
	if kind == "failed" then
		word = (sub and sub ~= "" and sub) or (Known("could not buff") and L["could not buff"])
	elseif kind == "sent" then
		word = Known("sent, unconfirmed") and L["sent, unconfirmed"]
	else
		word = Known("buffed") and L["buffed"]
	end
	if who and kit.sub:IsShown() then
		kit.SetLine(kit.name, who)
		-- Not in this client's language yet: the built-in looks' second line,
		-- which is, as the verdict. The name stays put in every language.
		if not word then word = sub or "" end
	else
		-- Nobody to name, or no second line to hold the verdict: the built-in
		-- looks' headline, which says both what happened and to whom.
		kit.SetLine(kit.name, lead)
		word = sub or ""
	end
	self.outcomeOn = true
	-- The owed breathing is about the favour, not the click: it stops, and the
	-- enamel is the outcome's. Attention starts it again for the next person
	-- owed.
	self:HoldPulse()
	self.ringNow = { o[1], o[2], o[3] }
	self.verdictInk = VERDICT[kind] or VERDICT.cast
	self.refused = kind == "failed"
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	self:Cloth()
	if kit.sub:IsShown() then kit.SetLine(kit.sub, word) end
end

-- The outcome is over: the enamel and the reason line go back to the reason's.
function Ribbon:ClearOutcome()
	local was = self.outcomeOn
	self.outcomeOn = nil
	self.verdictInk = nil
	local last = self.lastPaint
	if was and last then self:PaintReason(last[1], last[2], last[3], last[4], last[5]) end
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- Each row is a small ribbon, hanging from behind the main one, above or
-- below; a gem in its reason's colour sits at its left end.
function Ribbon:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.gems do
		if not (list and i <= shown) then
			self.gems[i]:Hide()
			self.gemSets[i]:Hide()
			Each(self.rowCloth[i], "Hide")
			Each(self.rowTrim[i], "Hide")
		end
	end
	if not list then
		self.listShown, self.listAt = nil, nil
		return
	end

	local p = ns.db and ns.db.profile.prompt or self.p or {}
	local mode = p.accentMode or "icon"
	local ringOn = mode == "icon" or mode == "both"
	local clothOn = mode == "stripe" or mode == "both"
	self.rowDye = self.rowDye or {}
	for i = 1, shown do
		local reason = rows[i] and rows[i].reason
		local c = kit.ReasonColor(reason)
		if mode == "off" then
			self.gems[i]:SetVertexColor(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], 1)
		else
			local er, eg, eb = Fired(c[1], c[2], c[3])
			self.gems[i]:SetVertexColor(er, eg, eb, 1)
		end
		local dye
		if clothOn then
			dye = { Ribbon.Dye(c[1], c[2], c[3], reason, p.reasonPalette, p.accentByReason) }
		else
			dye = { self:BaseDye() }
		end
		self.rowDye[i] = dye
		local k = (self.combat and CLOTH_COMBAT or 1) * 0.86
		Each(self.rowCloth[i], "SetVertexColor", dye[1] * k, dye[2] * k, dye[3] * k, 1)
		self.gems[i]:Show()
		self.gemSets[i]:Show()
		for j = 1, 2 do
			self.rowCloth[i][j]:Show()
			self.rowTrim[i][j]:Show()
		end
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local g = self.g
	local pitch, rh = self.pitch, self.rowH
	local x0, x1 = self.rowLeft, self.W - 5
	local gem = Clamp(rh - 5, 7, 16)
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way; the first tucked under the
		-- main ribbon's hem.
		local y
		if above then
			y = g.top + 2 - (shown - i) * pitch - rh / 2 - 1
		else
			y = g.bottom - 2 + (i - 1) * pitch + rh / 2 + 1
		end
		local top, bottom = y - rh / 2, y + rh / 2
		local cloth, trim = self.rowCloth[i], self.rowTrim[i]
		local from, to = x0, x1
		Box(cloth[1], art, from, top, to - self.rowEnd, bottom)
		Box(cloth[2], art, to - self.rowEnd, top, to, bottom)
		Box(trim[1], art, from, top, to - self.rowEnd, bottom)
		Box(trim[2], art, to - self.rowEnd, top, to, bottom)
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		for _, t in ipairs({ self.gems[i], self.gemSets[i] }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", art, "TOPLEFT", self.rowX - gem / 2 - 3, -y)
			t:SetSize(gem, gem)
		end
	end
end
