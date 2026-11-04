-- Manners -- the Leather look: a luggage tag of stitched leather with a brass eyelet.
--
-- The prompt is one object: a tag of warm brown leather, tooled and mottled,
-- its left end gently rounded and its right end a full half circle. A dashed
-- thread is stitched all round just inside the edge. Near the right end sits
-- a polished brass eyelet with a dark hole, and the spell icon is set into
-- the left end in a stitched square, as if the leather had been sewn round
-- it. The name is a bold serif in pale cream with a dark-brown drop shadow;
-- the reason is a lighter tan under it. At rest that is all, and it is
-- opaque: the world never shows through the leather.
--
-- The reason's colour is carried where leather can carry it:
--   * the icon's marker (the default): the thread round the icon;
--   * the stripe: the thread all round the tag, dyed in the reason's colour;
--   * both: the two together;
--   * and, in every mode but off, an enamel dot set in the eyelet's hole;
--   * off: cream thread and a dark hole, the tag as it was made.
-- The thread and the enamel are lightened until they read on the leather, so
-- all five reasons stay apart in both palettes.
--
-- The list is a column of smaller tags hung on the same ring: each a little
-- leather tag of its own with a brass eyelet exactly under the eyelet above,
-- an enamel dot for the reason and the name beside it. The count and the
-- bound key are small leather patches left of the eyelet, on the reason's line,
-- so the name keeps the whole of its own.
--
-- The motion is that of a hanging object (Calm is fades only):
--   * a favour arriving: the tag swings in on its eyelet -- it drops, rebounds
--     and settles, the eyelet staying where it hangs -- and the brass glints;
--   * somebody owed: the brass and the thread catch a slow warm glow, three
--     breaths, and then it is still;
--   * a landing: a band of light crosses the leather and the stitches light
--     up in the landing's green one after another round the tag, two rings
--     spread from the icon, the brass flashes;
--   * a refusal: the tag jerks on its eyelet while the thread flashes red and
--     amber, a ring snaps in on the icon, the text shakes (Prompt's);
--   * a fight: the leather and the brass go to grey and darken, the lights go
--     out, the name dims and the reason stays readable.
-- Rotation is a texture-only animation, so the tag cannot turn with its text
-- on it; the swing is a damped movement of the whole art with the eyelet
-- held still by the opposite one.
--
-- Rules it keeps (tests/scenarios/look-leather.lua, hunt35 and hunt37): the
-- leather is opaque at rest; everything lies inside the width and height the
-- prompt is given; no text is ever over the icon, the eyelet or a chip; every
-- frame of light is under the text's frame level; nothing that moves over the
-- text is scaled; the secure list names are anchored to frames, never to a
-- region; no pcall per repaint. The leather is baked in its own colours (a
-- fight greys it); the thread, the enamel and the lights are white, so the
-- vertex colour carries every reason. Every region is a texture from
-- Textures/Leather (tools/make_leather_textures.py). The interface this file
-- implements is described at the top of Looks/Looks.lua.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Leather\\Leather_"

local Leather = ns.Looks.Register("leather", {
	name = L["Leather -- a stitched leather tag with a brass ring"],
	title = L["Leather"],
	description = L["a stitched leather tag with a brass ring"],
	order = 6,
	-- The tag holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	-- Held to 3:1 against the leather at its lightest by tests/scenarios/look-leather.lua:
	-- a dark class colour taken this far towards white reads on brown.
	classSoften = 0.70,
	-- Every line sits on leather whatever the panel colour says.
	subOnDark = true,
	inkOnDark = true,
})

-- The art is drawn 128 texels tall and shown at the prompt's height: one unit
-- is HEIGHT / DESIGN of it. The pieces' widths, the stitch's period and its
-- inset from the edge, in texels (tools/make_leather_textures.py agrees).
local DESIGN, CAP_L, CAP_R, GRAIN = 128, 32, 64, 128
local PERIOD, INSET, STRIP = 16, 9, 16
-- How far the leather's tile may be stretched to end on a whole tile, as a
-- fraction: the pebbles hide it, a seam of their phase would show.
local STRETCH = 0.20
-- The eyelet: its texture's width as a fraction of the height, where its centre
-- stands in from the right edge, and the ring's outer and the hole's radii as
-- fractions of the height (27/64 and 19/64 of the texture).
local EYE, EYE_AT = 0.46, 0.40
local EYE_RING, EYE_HOLE = 27 / 64 * EYE, 19 / 64 * EYE
-- The enamel fills this much of the hole, a dark bezel left round it.
local ENAMEL = 0.80
-- The shadow's pieces reach past the tag, in texels of the design: SHADOW_SIDE
-- left and right, SHADOW_UP above and below, and the right piece starts
-- SHADOW_BEFORE texels before the half circle does. The whole of it lies
-- within half the tag's height of the tag (tests/scenarios/look-leather.lua).
local SHADOW_SIDE, SHADOW_BEFORE, SHADOW_UP = 16, 48, 64
local SHADOW_ALPHA = 0.9
-- Where the effect ring's line sits in its file and how far out it is seen, as
-- fractions of its half-width (FX_PEAK in the generator, and hunt37-effects
-- reads the files).
local FX_PEAK, FX_EDGE = 0.70, 0.88
-- How many pieces the thread's light is cut into along each straight, for the
-- landing to run round the tag.
local PIECES = 6

local CREAM = { 0.93, 0.76, 0.54 }
local TAN = { 1.00, 0.91, 0.75 }
local NAME_INK = { 1.00, 0.95, 0.84 }
local SHADOW = { 0.14, 0.07, 0.02 }
local ROW_INK = { 1.00, 0.91, 0.75 }
local FIGHT_THREAD = { 0.56, 0.53, 0.50 }
local WARM = { 1.00, 0.60, 0.20 }
-- The outcomes' own colours and the two a refusal flashes.
local OUTCOME = {
	cast = { 0.36, 0.92, 0.50 },
	failed = { 1.00, 0.34, 0.26 },
	sent = { 0.95, 0.84, 0.48 },
}
local GHOSTS = { { 1.00, 0.26, 0.20 }, { 1.00, 0.72, 0.22 } }
-- What a fight does: the text dims, the leather and the icon darken.
local TEXT_COMBAT, LEATHER_COMBAT, ICON_COMBAT = 0.78, 0.62, 0.70
-- The owed breath: the glow lifts to this and back, this many breaths, and
-- then it is still.
local GLOW_PEAK = 0.55
local BREATHS, BREATH = 3, 1.25
-- The leather darkens a little towards its right end; the chips and the list's
-- tags are a shade darker than the tag.
local RAMP = 0.16
local PATCH = 0.80
local COMMAND = "CLICK MannersPrompt:LeftButton"
-- The name's face: Blizzard's own display serif, in every client's font files
-- (Blizzard_Fonts_Shared, GameFonts.xml) for the Latin alphabet. The clients
-- that write in another one (Korean, Chinese, Russian) keep the font they draw
-- it in.
local NAME_FACE = "Fonts\\MORPHEUS.TTF"
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true,
	ptBR = true }

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, the gap and the reason as one block, and the margin the thread and
-- the leather's edge take from the top and the bottom.
function Leather.TwoLineHeight(fontSize)
	return math.ceil((fontSize + 1) + 2 + SubSize(fontSize) + 16)
end

-- The ring is the icon's setting; the stripe is the thread and the enamel in
-- the eyelet, which the tag always has: it carries the reason in every mode
-- but off.
function Leather.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false, mode ~= "off"
end

-- Whether a stored colour is the default one: AceDB strips a value equal to its
-- default, so untouched and chosen-as-default look the same, and only the
-- first can be meant.
local function Untouched(c, d)
	if type(c) ~= "table" or type(d) ~= "table" then return true end
	for i = 1, 4 do
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

-- The name's face: the display serif, unless the player chose a font of their
-- own (AceDB strips a value equal to the default, so only another is a choice)
-- or the client writes in an alphabet that file lacks.
local function Face(p)
	local d = ns.defaults and ns.defaults.profile.prompt.font
	if type(p.font) == "string" and p.font ~= d then return nil end
	if not LATIN[ns.LOCALE or "enUS"] then return nil end
	return NAME_FACE
end

local function Luminance(r, g, b)
	local function lin(c)
		if c <= 0.03928 then return c / 12.92 end
		return ((c + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

-- A colour taken towards white until it holds `least` of luminance: the thread
-- and the enamel on brown leather. The deep pink and violet of the colour-blind
-- set, and the grey of "nearby", would otherwise sink into it.
local function Bright(tint, r, g, b, least)
	for i = 0, 10 do
		local t = i / 10
		local tr, tg, tb = tint(r, g, b, t)
		if Luminance(tr, tg, tb) >= least or i == 10 then return tr, tg, tb end
	end
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A tag cut in three, from three files: left end, middle (repeated), right
-- end. The tag's own body; the small tags' (the patches and the list's rows:
-- the same object drawn for a sixth the size, its stitch baked in); and the
-- shadow the tag throws, drawn over a box past the tag's (SHADOW_* below).
-- `keep` collects what is made.
local BODY = { "BodyL", "BodyM", "BodyR" }
local PATCH_FILES = { "PatchL", "PatchM", "PatchR" }
local SHADOW_FILES = { "ShadowL", "ShadowM", "ShadowR" }

local function Slices(parent, layer, sublevel, keep, files)
	local s = {}
	files = files or BODY
	for i = 1, 3 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then
			t:SetTexture(ART .. files[i], "REPEAT", "REPEAT")
		else
			t:SetTexture(ART .. files[i])
		end
		s[i] = keep(t)
	end
	return s
end

-- A texture over a box given from `rel`'s top left, y running down.
local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

-- How many tiles of `unit` units run over `length`: the leather's own scale
-- unless a whole number is within STRETCH of it, and the thread's always a
-- whole number (a stitch cut short at the end of the straight would show).
local function Tiles(length, unit, whole)
	local n = math.max(0, length) / unit
	local r = math.max(1, math.floor(n + 0.5))
	if whole or (n > 0 and math.abs(r / math.max(n, 1e-6) - 1) <= STRETCH) then return r end
	return n
end

-- A leather tag laid over a box: the ends are the art's own proportion of its
-- height, so the tag is the same object at any size.
local function PlaceTag(s, rel, x0, y0, x1, y1)
	local h = y1 - y0
	local su = h / DESIGN
	local capL, capR = CAP_L * su, CAP_R * su
	local w = x1 - x0
	if capL + capR > w then
		local k = w / (capL + capR)
		capL, capR = capL * k, capR * k
	end
	Box(s[1], rel, x0, y0, x0 + capL, y1)
	Box(s[2], rel, x0 + capL, y0, x1 - capR, y1)
	Box(s[3], rel, x1 - capR, y0, x1, y1)
	s[2]:SetTexCoord(0, Tiles(w - capL - capR, GRAIN * su), 0, 1)
end

-- ...and over a frame of a width of its own, as the chips are: anchored to the
-- frame's corners, so they follow it.
local function PlaceTagIn(s, box, w, h)
	local su = h / DESIGN
	local capL, capR = math.min(CAP_L * su, w / 3), math.min(CAP_R * su, w / 2)
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[1]:SetWidth(capL)
	s[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[3]:SetWidth(capR)
	s[2]:SetPoint("TOPLEFT", s[1], "TOPRIGHT", 0, 0)
	s[2]:SetPoint("BOTTOMRIGHT", s[3], "BOTTOMLEFT", 0, 0)
	s[2]:SetTexCoord(0, Tiles(w - capL - capR, GRAIN * su), 0, 1)
end

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- The shadow under a tag laid over a box: its pieces reach past the tag as
-- the art says, and where the tag is too short for the left piece and the
-- right one both, the right one is cut where the left one ends.
local function PlaceShadow(s, rel, x0, y0, x1, y1)
	local h = y1 - y0
	local su = h / DESIGN
	local capR = math.min(CAP_R * su, (x1 - x0) / 2)
	local top, bottom = y0 - SHADOW_UP * su, y1 + SHADOW_UP * su
	local lEnd = x0 + (CAP_L + SHADOW_SIDE) * su
	local rStart = x1 - capR - SHADOW_BEFORE * su
	local u0 = 0
	if rStart < lEnd then
		u0 = (lEnd - rStart) / ((SHADOW_BEFORE + CAP_R + SHADOW_SIDE) * su)
		rStart = lEnd
	end
	Box(s[1], rel, x0 - SHADOW_SIDE * su, top, lEnd, bottom)
	Box(s[2], rel, lEnd, top, rStart, bottom)
	Box(s[3], rel, rStart, top, x1 + SHADOW_SIDE * su, bottom)
	s[3]:SetTexCoord(u0, 1, 0, 1)
end

-- The leather's colour over a run of slices, a shade darker towards the right
-- (the tag's own light falls off from the left), the first slice's left edge
-- at `f0` of the tag and the last one's right edge at `f1`.
local function Dye(grad, s, dye, k, f0, f1, spans)
	for i, t in ipairs(s) do
		local a, b = spans[i][1], spans[i][2]
		local ka = k * (1 - RAMP * (f0 + (f1 - f0) * a))
		local kb = k * (1 - RAMP * (f0 + (f1 - f0) * b))
		grad(t, "HORIZONTAL", dye[1] * ka, dye[2] * ka, dye[3] * ka, 1, dye[1] * kb, dye[2] * kb, dye[3] * kb, 1)
	end
end

local function Grey(list, on)
	for _, t in ipairs(list) do t:SetDesaturated(on) end
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it moves, parked between
-- plays, so nothing is left lit or displaced when it stops.
---------------------------------------------------------------------------

-- Parks `region` at `rest` alpha when the group ends or is stopped.
local function Park(group, region, rest)
	local function park() region:SetAlpha(rest or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Alpha(group, from, to, duration, order, smoothing, delay)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, dx, dy, duration, order, smoothing, delay)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Up to `peak`, then down to nothing, after `delay`.
local function Flash(region, peak, up, down, delay)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, peak, up, 1, "OUT", delay)
	Alpha(g, peak, 0, down, 2, "OUT")
	Park(g, region, 0)
	return g
end

-- Steps that sum to nothing, `step` long each: the region ends where it began.
-- `sign` -1 gives the opposite movement, for what must stay where it hangs.
local function Swing(region, steps, sign)
	local g = region:CreateAnimationGroup()
	for i, s in ipairs(steps) do
		Slide(g, sign * s[1], sign * s[2], s[3], i, s[4])
	end
	return g
end

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

-- The tag's swing in: it drops, rebounds and settles, the way a tag on a hook
-- does when it is hung up. {dx, dy, seconds, smoothing}; the steps add up to
-- nothing.
local SWING = {
	{ 0, -4, 0.09, "OUT" }, { 0, 7, 0.13, "IN_OUT" }, { 0, -6, 0.12, "IN_OUT" },
	{ 0, 4, 0.10, "IN_OUT" }, { 0, -1, 0.08, "IN_OUT" },
}
-- A refusal's jerk: short and hard, dying away.
local JERK = {
	{ 1, -3, 0.04 }, { -2, 5, 0.04 }, { 2, -4, 0.04 }, { -1, 3, 0.04 }, { 1, -2, 0.04 }, { -1, 1, 0.04 },
}

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Leather:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local base = art:GetFrameLevel()
	local function keep(x) own[#own + 1] = x return x end
	local function anim(g) anims[#anims + 1] = g return g end
	local function tex(parent, layer, sublevel, file, blend, wrap)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if wrap then t:SetTexture(ART .. file, "REPEAT", "REPEAT") else t:SetTexture(ART .. file) end
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end
	-- A frame of the tag's furniture or of light, a few levels over the art and
	-- under the text (hunt37-effects).
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end

	-- The shadow the tag throws on the world, under everything; the leather, on
	-- art itself, under the icon: the three slices, and the waxy light across
	-- its upper half.
	self.shadow = Slices(art, "BACKGROUND", -7, keep, SHADOW_FILES)
	Each(self.shadow, "SetVertexColor", 0, 0, 0, SHADOW_ALPHA)
	self.body = Slices(art, "BACKGROUND", -6, keep)
	self.sheen = tex(art, "BACKGROUND", -5, "Sheen")

	-- The thread: the straights top and bottom (repeated), the two ends.
	self.threadFrame = frame(1)
	self.thread = {
		top = tex(self.threadFrame, "ARTWORK", 0, "StitchM", nil, true),
		bottom = tex(self.threadFrame, "ARTWORK", 0, "StitchM", nil, true),
		left = tex(self.threadFrame, "ARTWORK", 0, "StitchL"),
		right = tex(self.threadFrame, "ARTWORK", 0, "StitchR"),
	}

	-- The icon's setting: its rim, over the icon's own edge, and a flash.
	self.iconFrame = frame(1)
	self.iconRim = tex(self.iconFrame, "ARTWORK", 0, "IconRim")
	self.iconFlash = tex(self.iconFrame, "ARTWORK", 1, "IconMask", "ADD")
	self.iconFlash:SetAlpha(0)

	-- The eyelet and its enamel, on a frame of their own: the swing holds them
	-- still by the opposite movement.
	self.ringFrame = frame(1)
	self.eyelet = tex(self.ringFrame, "ARTWORK", 0, "Eyelet")
	self.enamel = tex(self.ringFrame, "ARTWORK", 1, "Enamel")
	-- The window reflected in the enamel: white over the dyed dome.
	self.gloss = tex(self.ringFrame, "ARTWORK", 2, "Gloss")

	-- The owed breath: the thread's warm glow, and the brass's. Both at nothing
	-- until it breathes.
	self.glowFrame = frame(2)
	self.glowFrame:SetAlpha(0)
	self.glow = {
		top = tex(self.glowFrame, "ARTWORK", 0, "StitchM", "ADD", true),
		bottom = tex(self.glowFrame, "ARTWORK", 0, "StitchM", "ADD", true),
		left = tex(self.glowFrame, "ARTWORK", 0, "StitchL", "ADD"),
		right = tex(self.glowFrame, "ARTWORK", 0, "StitchR", "ADD"),
	}
	self.ringGlowFrame = frame(2)
	self.ringGlowFrame:SetAlpha(0)
	self.ringGlow = tex(self.ringGlowFrame, "ARTWORK", 0, "Glow", "ADD")
	-- The warm tone of the breath, which hunt35-effects looks for.
	self.warmRing = self.ringGlow

	-- The light a landing and a refusal run round the thread: the thread cut in
	-- pieces, each lit on its own turn, in the order round the tag: along the
	-- top, round the right end, back along the bottom, up the left end.
	self.litFrame = frame(2)
	self.pieces = {}
	for k = 1, PIECES do
		self.pieces[#self.pieces + 1] = { kind = "top", index = k,
			tex = tex(self.litFrame, "ARTWORK", 1, "StitchM", "ADD", true) }
	end
	self.pieces[#self.pieces + 1] = { kind = "right", tex = tex(self.litFrame, "ARTWORK", 1, "StitchR", "ADD") }
	for k = PIECES, 1, -1 do
		self.pieces[#self.pieces + 1] = { kind = "bottom", index = k,
			tex = tex(self.litFrame, "ARTWORK", 1, "StitchM", "ADD", true) }
	end
	self.pieces[#self.pieces + 1] = { kind = "left", tex = tex(self.litFrame, "ARTWORK", 1, "StitchL", "ADD") }
	for _, piece in ipairs(self.pieces) do piece.tex:SetAlpha(0) end

	-- The band of light that crosses the leather for a landing.
	self.bandFrame = frame(2)
	self.bandFrame:SetAlpha(0)
	self.band = tex(self.bandFrame, "ARTWORK", 0, "Band", "ADD")

	-- The glints on the brass, the flash of it for a landing, the cursor's
	-- light: textures of their own on one frame that stays up.
	self.starFrame = frame(2)
	self.star = tex(self.starFrame, "OVERLAY", 1, "Star", "ADD")
	self.ringFlash = tex(self.starFrame, "OVERLAY", 0, "Glow", "ADD")
	self.hoverLight = tex(self.starFrame, "OVERLAY", 0, "Glow", "ADD")
	for _, t in ipairs({ self.star, self.ringFlash, self.hoverLight }) do t:SetAlpha(0) end

	-- The rings that spread from the icon when a buff lands and the one that
	-- closes on it when one is refused, in frames over the art and under the
	-- text. No echo of the icon: its rim is the arrival's.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		keep(f)
		f:SetFrameLevel(base + 2)
	end
	kit.RingArt(ART .. "FxRing", FX_PEAK, FX_EDGE)
	kit.RingArt(ART .. "FxRingSq", FX_PEAK, FX_EDGE)

	-- The chips, left of the eyelet: leather patches; their text is on textLayer.
	self.chipFrame = frame(3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = Slices(self.chipFrame, "ARTWORK", 1, keep, PATCH_FILES)
	self.keyChip = Slices(self.chipFrame, "ARTWORK", 1, keep, PATCH_FILES)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)

	-- The list: a tag for each row, on the same ring: its eyelet, and an enamel
	-- dot for the reason.
	self.tags = {}
	for i = 1, #kit.rows do
		self.tags[i] = {
			body = Slices(art, "BACKGROUND", -6, keep, PATCH_FILES),
			eyelet = tex(art, "ARTWORK", 1, "Eyelet"),
			dot = tex(art, "ARTWORK", 2, "Enamel"),
		}
	end

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	self:BuildAnimations(anim)
end

function Leather:BuildAnimations(anim)
	local art = self.kit.art

	-- The owed breath: the thread's glow and the brass's, together, up and down.
	local function breath(region)
		local g = region:CreateAnimationGroup()
		g:SetLooping("BOUNCE")
		Alpha(g, 0, GLOW_PEAK, BREATH, 1, "IN_OUT")
		Park(g, region, 0)
		return anim(g)
	end
	self.pulse = { breath(self.glowFrame), breath(self.ringGlowFrame) }

	-- A favour arriving: the tag swings in, the eyelet and what is on it hang
	-- still by the opposite movement, the brass glints.
	local arrive = {}
	local function into(g) arrive[#arrive + 1] = anim(g) end
	self.swing = Swing(art, SWING, 1)
	into(self.swing)
	for _, f in ipairs({ self.ringFrame, self.ringGlowFrame, self.starFrame }) do into(Swing(f, SWING, -1)) end
	into(Flash(self.star, 0.95, 0.06, 0.28, 0.26))
	self.arrive = arrive

	-- A landing: a band of light crosses the leather, the thread lights up piece
	-- by piece round the tag, the brass and the icon flash.
	local band = self.bandFrame:CreateAnimationGroup()
	self.bandMove = Slide(band, 100, 0, 0.36, 1, "IN_OUT")
	Alpha(band, 0, 0.62, 0.10, 1, "OUT")
	Alpha(band, 0.62, 0, 0.20, 1, "IN", 0.16)
	Park(band, self.bandFrame, 0)
	local landing = { anim(band) }
	self.lit, self.flash = {}, {}
	for i, piece in ipairs(self.pieces) do
		local g = piece.tex:CreateAnimationGroup()
		Alpha(g, 0, 1, 0.05, 1, "OUT", (i - 1) * 0.022)
		Alpha(g, 1, 0, 0.22, 2, "IN")
		Park(g, piece.tex, 0)
		self.lit[i] = anim(g)
		landing[#landing + 1] = self.lit[i]
		-- ...and the same thread, all at once, twice, for a refusal.
		local f = piece.tex:CreateAnimationGroup()
		Alpha(f, 0, 1, 0.04, 1, "OUT")
		Alpha(f, 1, 0.15, 0.07, 2, "IN")
		Alpha(f, 0.15, 1, 0.04, 3, "OUT")
		Alpha(f, 1, 0, 0.12, 4, "IN")
		Park(f, piece.tex, 0)
		self.flash[i] = anim(f)
	end
	landing[#landing + 1] = anim(Flash(self.ringFlash, 0.85, 0.05, 0.30))
	landing[#landing + 1] = anim(Flash(self.iconFlash, 0.40, 0.05, 0.24))
	self.landing = landing

	-- A refusal: the tag jerks on its eyelet, the thread flashes red and amber,
	-- the icon and the brass flash.
	local refusal = { anim(Swing(art, JERK, 1)) }
	for _, f in ipairs({ self.ringFrame, self.ringGlowFrame, self.starFrame }) do
		refusal[#refusal + 1] = anim(Swing(f, JERK, -1))
	end
	for i = 1, #self.flash do refusal[#refusal + 1] = self.flash[i] end
	refusal[#refusal + 1] = anim(Flash(self.ringFlash, 0.70, 0.04, 0.22))
	refusal[#refusal + 1] = anim(Flash(self.iconFlash, 0.40, 0.04, 0.20))
	self.refusal = refusal

	-- Calm's landing and arrival are one fade of the thread's glow, in whichever
	-- colour it was set to.
	local soft = self.glowFrame:CreateAnimationGroup()
	Alpha(soft, 0, 0.8, 0.18, 1, "OUT")
	Alpha(soft, 0.8, 0, 0.50, 2, "IN")
	Park(soft, self.glowFrame, 0)
	self.soft = anim(soft)

	-- The cursor: the brass catches a little light, which leaves with it.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 0.5, 0.12, 1, "OUT")
	local function rest() self.hoverLight:SetAlpha(hover.to or 0) end
	hover:SetScript("OnFinished", rest)
	hover:SetScript("OnStop", rest)
	self.hoverAnim = anim(hover)
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

-- The leather's own brown, untouched, or dyed towards a panel colour the
-- player chose: its hue at the leather's brightness.
function Leather:Dye(p)
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local bc = p.bgColor
	if Untouched(bc, d) then
		self.dye = { 1, 1, 1 }
		return
	end
	local r, g, b = bc[1] or 0, bc[2] or 0, bc[3] or 0
	local m = math.max(r, g, b, 0.05)
	self.dye = { 0.45 + 0.55 * r / m, 0.45 + 0.55 * g / m, 0.45 + 0.55 * b / m }
end

-- The thread's pieces along a straight and over an end, in the tag's own
-- coordinates; one function, for the thread and for the light that follows it.
function Leather:PlaceThread(set, x0, x1, capL, capR, y, su, pieces)
	local art = self.kit.art
	local top, bottom = set and set.top, set and set.bottom
	local half = STRIP / 2 * su
	local topY, bottomY = INSET * su, self.H - INSET * su
	local length = x1 - capR - capL
	local tiles = Tiles(length, PERIOD * su, true)
	if pieces then
		-- Cut in PIECES: each its own share of the tiles and of the length.
		for _, piece in ipairs(pieces) do
			if piece.kind == "top" or piece.kind == "bottom" then
				local a, b = (piece.index - 1) / PIECES, piece.index / PIECES
				local cy = piece.kind == "top" and topY or bottomY
				Box(piece.tex, art, capL + length * a, cy - half, capL + length * b, cy + half)
				piece.tex:SetTexCoord(tiles * a, tiles * b, 0, 1)
			elseif piece.kind == "left" then
				Box(piece.tex, art, 0, 0, capL, self.H)
			else
				Box(piece.tex, art, x1 - capR, 0, x1, self.H)
			end
		end
		return
	end
	Box(top, art, capL, topY - half, capL + length, topY + half)
	top:SetTexCoord(0, tiles, 0, 1)
	Box(bottom, art, capL, bottomY - half, capL + length, bottomY + half)
	bottom:SetTexCoord(0, tiles, 0, 1)
	Box(set.left, art, 0, 0, capL, self.H)
	Box(set.right, art, x1 - capR, 0, x1, self.H)
end

function Leather:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local face = Face(p)
	local nameSize = face and fs + 1 or fs
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	local twoLine = p.showSub and H >= Leather.TwoLineHeight(fs)
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	self.nameSize, self.twoLine = nameSize, twoLine and true or false
	self:Dye(p)

	local su = H / DESIGN
	local capL, capR = CAP_L * su, CAP_R * su
	if capL + capR > W then
		local k = W / (capL + capR)
		capL, capR = capL * k, capR * k
	end
	local edge = INSET * su
	self.su, self.capL, self.capR, self.edge = su, capL, capR, edge

	-- The eyelet: where it hangs, and how much of the right end it takes.
	local eyeSize = EYE * H
	local ringX = W - EYE_AT * H
	self.ringX, self.eyeSize = ringX, eyeSize
	self.ringLeft = ringX - EYE_RING * H
	self.ringInset = math.ceil(W - self.ringLeft + 3)

	-- The lines, from the top: the name, a gap and the reason, centred.
	local block = twoLine and (nameSize + 2 + sub) or nameSize
	local m = (H - block) / 2
	local nameC = m + nameSize / 2
	local subC = m + nameSize + 2 + sub / 2
	self.nameY = H / 2 - nameC
	self.oneY = 0
	self.subY = H / 2 - subC
	self.nameC = twoLine and nameC or H / 2
	self.baseInset = self.ringInset
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua).
	self.pitch = sub + 8

	-- The icon: S across, set in just inside the thread, over the leather.
	local S = showIcon and Clamp(p.iconSize, 12, math.max(12, H - 2 * (edge + 2))) or 0
	local iconX = edge + 3.5
	local cx, cy = iconX + S / 2, H / 2
	self.S, self.iconX, self.cx, self.cy = S, iconX, cx, cy
	local textX
	if showIcon then
		textX = iconX + S + 6
	else
		textX = math.max(edge + 7, 0.2 * H)
	end
	self.textX = textX

	-- The leather.
	local spans = { { 0, capL / W }, { capL / W, 1 - capR / W }, { 1 - capR / W, 1 } }
	self.spans = spans
	PlaceTag(self.body, art, 0, 0, W, H)
	PlaceShadow(self.shadow, art, 0, 0, W, H)
	-- The sheen: across the upper half, well inside the edge and the ends.
	Box(self.sheen, art, capL * 0.8, edge + 1, math.max(capL * 0.8 + 8, W - capR * 0.9), edge + 1 + 0.55 * H)
	self.sheen:SetVertexColor(1, 1, 1, 1)

	-- The thread, the light that breathes over it and the pieces a landing runs.
	self:PlaceThread(self.thread, 0, W, capL, capR, nil, su)
	self:PlaceThread(self.glow, 0, W, capL, capR, nil, su)
	self:PlaceThread(nil, 0, W, capL, capR, nil, su, self.pieces)

	-- The eyelet, on its own frame, with the enamel in the hole.
	local function centre(t, size, x, y)
		t:ClearAllPoints()
		t:SetSize(size, size)
		t:SetPoint("CENTER", art, "TOPLEFT", x, -y)
	end
	centre(self.eyelet, eyeSize, ringX, H / 2)
	local enamelSize = math.max(3, 2 * EYE_HOLE * H * ENAMEL)
	centre(self.enamel, enamelSize, ringX, H / 2)
	centre(self.gloss, enamelSize, ringX, H / 2)
	centre(self.ringGlow, eyeSize * 1.7, ringX, H / 2)
	centre(self.star, eyeSize * 1.5, ringX - eyeSize * 0.12, H / 2 - eyeSize * 0.14)
	centre(self.ringFlash, eyeSize * 1.7, ringX, H / 2)
	centre(self.hoverLight, eyeSize * 1.7, ringX, H / 2)
	local wr, wg, wb = WARM[1], WARM[2], WARM[3]
	self.ringGlow:SetVertexColor(wr, wg, wb, 1)
	self.star:SetVertexColor(1, 0.96, 0.82, 1)
	self.hoverLight:SetVertexColor(wr, wg, wb, 1)
	for _, f in ipairs({ self.ringFrame, self.ringGlowFrame, self.starFrame }) do
		f:ClearAllPoints()
		f:SetAllPoints(art)
	end

	-- The band: from the left end of the straight to the right, as tall as the
	-- leather inside its edge.
	local bandW = math.max(10, 0.75 * H)
	self.bandFrame:ClearAllPoints()
	self.bandFrame:SetPoint("TOPLEFT", art, "TOPLEFT", capL, -(edge + 1))
	self.bandFrame:SetSize(bandW, H - 2 * (edge + 1))
	self.band:ClearAllPoints()
	self.band:SetAllPoints(self.bandFrame)
	self.band:SetVertexColor(1, 0.94, 0.78, 1)
	self.bandMove:SetOffset(math.max(8, W - capR - capL - bandW), 0)

	-- The icon: its shape, its rim over its edge, the flash.
	local round = p.roundIcon and true or false
	self.round = round
	local maskFile = ART .. (round and "IconMaskRd" or "IconMask")
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.iconFrame:ClearAllPoints()
	self.iconFrame:SetPoint("TOPLEFT", art, "TOPLEFT", iconX, -(cy - S / 2))
	self.iconFrame:SetSize(math.max(1, S), math.max(1, S))
	if showIcon then
		icon:SetSize(S, S)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		self.iconRim:SetTexture(ART .. (round and "IconRimRd" or "IconRim"))
		self.iconFlash:SetTexture(maskFile)
		for _, t in ipairs({ self.iconRim, self.iconFlash }) do
			t:ClearAllPoints()
			t:SetAllPoints(self.iconFrame)
		end
		-- The rings spread from the rim's edge: a unit and a half past the icon.
		local pad = (S / 2 + 1.5) / FX_PEAK - S / 2
		self.fx:Place(icon, pad, S)
		self.fx:Shape(round, ART .. "FxRing", ART .. "FxRingSq")
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = math.min(cy, H - cy) - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			cooldown:SetAlpha(1)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
		end
	end

	-- The chips: small leather patches left of the eyelet, on the reason's line.
	local chipH = sub + 6
	self.chipH = chipH
	local chipTop = self.nameC - chipH / 2
	self.chipTop = Clamp(chipTop, edge + 1, math.max(edge + 1, H - edge - 1 - chipH))
	-- ...or on the reason's line, where the name keeps its whole room: a
	-- little lower than the name's, so it leaves the descenders above it alone.
	self.subChipH = Clamp(sub + 4, 9, chipH)
	self.subChipTop = twoLine and Clamp(subC - self.subChipH / 2, edge + 1,
		math.max(edge + 1, H - edge - 1 - self.subChipH)) or nil
	self.chipRight = math.ceil(self.ringInset)
	self.chipW2 = math.ceil(chipH * 1.5)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("TOPRIGHT", art, "TOPRIGHT", -self.chipRight, -self.chipTop)
	self.keyBox:SetSize(self.chipW2, chipH)
	PlaceTagIn(self.keyChip, self.keyBox, self.chipW2, chipH)
	self.countMode, self.keyLane, self.keyUp = nil, nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local level = art:GetFrameLevel()
	for _, f in ipairs({ self.threadFrame, self.iconFrame, self.ringFrame }) do f:SetFrameLevel(level + 1) end
	for _, f in ipairs({ self.glowFrame, self.ringGlowFrame, self.litFrame, self.bandFrame, self.starFrame }) do
		f:SetFrameLevel(level + 2)
	end
	self.chipFrame:SetFrameLevel(level + 3)

	-- The list: each row a tag, its eyelet under the main tag's, each starting
	-- a little further in than the last.
	local pitch = self.pitch
	self.tagH = pitch - 2
	self.stagger = 5
	self.rowBase = 8
	self.dotSize = math.max(5, self.tagH * 0.42)
	self.rowOffset = math.ceil(0.45 * self.tagH + 2 + self.dotSize + 3)
	-- A name's click area begins at the tag's enamel dot.
	self.rowReach = self.rowOffset
	self.rowEye = EYE * self.tagH
	local eyeLeft = ringX - EYE_RING * self.tagH
	for i, row in ipairs(kit.rows) do
		local x = self.rowBase + (i - 1) * self.stagger + self.rowOffset
		local width = math.max(20, eyeLeft - 3 - x)
		row:SetWidth(width)
		fit.room[row] = width
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the list
	-- for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	self.fx:SetShown(showIcon)
	self.iconFrame:SetShown(showIcon)
	for _, t in ipairs({ self.iconRim, self.iconFlash }) do t:SetShown(showIcon) end
	for _, tag in ipairs(self.tags) do
		Each(tag.body, "Hide")
		tag.eyelet:Hide()
		tag.dot:Hide()
	end
	Each(self.chip, "Hide")
	Each(self.keyChip, "Hide")
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.glowSpent = nil
	for _, piece in ipairs(self.pieces) do piece.tex:SetAlpha(0) end
	for _, t in ipairs({ self.star, self.ringFlash, self.hoverLight, self.iconFlash }) do t:SetAlpha(0) end
	for _, f in ipairs({ self.glowFrame, self.ringGlowFrame, self.bandFrame }) do f:SetAlpha(0) end
	self:Tone()
	self:Accent()
	if held then self:Combat(true) end

	-- The count's room: a two-digit chip and its inset.
	return textX, self.chipRight + self.chipW2 + 4
end

-- The leather's colour and its fight state, over everything baked: the tag,
-- the chips and the list's tags a shade darker; the brass and the enamel grey
-- and dimmer in a fight.
local PATCH_SPANS = { { 0, 0.30 }, { 0.30, 0.70 }, { 0.70, 1 } }

function Leather:Tone()
	local on = self.combat and true or false
	local k = on and LEATHER_COMBAT or 1
	local grad = self.kit.Gradient
	Dye(grad, self.body, self.dye, k, 0, 1, self.spans)
	Dye(grad, self.chip, self.dye, k * PATCH, 0.2, 0.6, PATCH_SPANS)
	Dye(grad, self.keyChip, self.dye, k * PATCH, 0.2, 0.6, PATCH_SPANS)
	Grey(self.body, on)
	Grey(self.chip, on)
	Grey(self.keyChip, on)
	local v = on and 0.72 or 1
	for _, t in ipairs({ self.eyelet, self.enamel }) do
		t:SetDesaturated(on)
		t:SetVertexColor(v, v, v, 1)
	end
	self.gloss:SetVertexColor(v, v, v, on and 0.6 or 1)
	self.sheen:SetDesaturated(on)
	self.sheen:SetVertexColor(1, 1, 1, on and 0.5 or 1)
	-- The list's tags follow, whether or not they are up: PaintQueue shows them.
	for _, tag in ipairs(self.tags) do
		Dye(grad, tag.body, self.dye, k * 0.96, 0.2, 0.6, PATCH_SPANS)
		Grey(tag.body, on)
		tag.eyelet:SetDesaturated(on)
		tag.eyelet:SetVertexColor(v, v, v, 1)
		tag.dot:SetDesaturated(on)
	end
end

function Leather:Styled(p)
	local kit = self.kit
	local ink, fit = kit.ink, kit.fit
	-- The name's face: the display serif, unless the player chose a font or the
	-- client has no such file (the line then keeps what Prompt set). Only the
	-- name is set apart; FitLine keeps it in its face as it shrinks.
	local face = Face(p)
	local nameSize = self.nameSize or p.fontSize
	local ok = face and kit.name:SetFont(face, nameSize, fit.flags) and kit.name:GetFont()
	if face and not ok then kit.name:SetFont(fit.path or STANDARD_TEXT_FONT, p.fontSize, fit.flags) end
	if ok then
		fit.paths[kit.name] = face
		fit.base[kit.name], fit.size[kit.name] = nameSize, nameSize
	end
	local sub = self.sub or SubSize(p.fontSize)
	if not self.keyText:SetFont(fit.path or STANDARD_TEXT_FONT, sub, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, sub, "")
	end

	-- The ink: cream on the leather whatever the panel colour says (the leather
	-- is brown), the player's own text colour when they chose one.
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	-- A text colour too dark to read on leather is not taken: the leather is
	-- brown whatever panel colour was picked.
	if chosen and Luminance(p.fontColor[1] or 1, p.fontColor[2] or 1, p.fontColor[3] or 1) < 0.18 then
		chosen = false
	end
	if not chosen then kit.name:SetTextColor(NAME_INK[1], NAME_INK[2], NAME_INK[3], 1) end
	kit.name:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.95)
	kit.name:SetShadowOffset(1, -1)
	kit.sub:SetTextColor(TAN[1], TAN[2], TAN[3], 1)
	kit.sub:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.9)
	kit.sub:SetShadowOffset(1, -1)
	-- The chips are patches of the same leather, stamped in cream.
	kit.count:SetTextColor(NAME_INK[1], NAME_INK[2], NAME_INK[3], 1)
	kit.count:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.95)
	kit.count:SetShadowOffset(1, -1)
	self.keyText:SetTextColor(NAME_INK[1], NAME_INK[2], NAME_INK[3], 1)
	self.keyText:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.95)
	self.keyText:SetShadowOffset(1, -1)
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(ROW_INK[1], ROW_INK[2], ROW_INK[3], 1)
		fs:SetShadowColor(SHADOW[1], SHADOW[2], SHADOW[3], 0.95)
		fs:SetShadowOffset(1, -1)
	end
	ink.rowReason = "|cffc9a47c"
	self:Accent()
end

function Leather:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	for _, x in ipairs(self.own) do x:Hide() end
	self.glowGen = (self.glowGen or 0) + 1
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
	kit.sub:SetShadowOffset(1, -1)
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.fit.paths[kit.name] = nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	for _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(1) end
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.countMode, self.keyLane, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Leather:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The name line keeps what stands on it: a count's patch, a key's, or the
	-- pair. The reason line keeps clear of the same (a patch is as tall as the
	-- line) and of what stands on its own line: the key's patch, with the
	-- count's beside it.
	local inset = math.max(right, self.baseInset)
	if self.keyLane == "name" then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
	-- The two points never cross: the name keeps 20 units, the room at the
	-- right gives way.
	local least = math.max(0, self.W - self.textX - 20)
	inset = math.min(inset, least)
	local subInset = inset
	if self.keyLane == "sub" then subInset = math.max(subInset, self.keyRoom or 0) end
	if self.countMode == "sub" then
		subInset = math.max(subInset, self.keyLane == "sub" and self:PairRoom() or self:CountRoom())
	end
	subInset = math.min(subInset, least)
	self.inset, self.subInset = inset, subInset
	self.lineRoom = math.max(20, self.W - self.textX - inset)
	fit.room[name] = self.lineRoom
	if fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -inset, self.nameY)
	else
		name:SetPoint("LEFT", self.textX, self.oneY)
		name:SetPoint("RIGHT", -inset, self.oneY)
	end
	fit.room[sub] = math.max(20, self.W - self.textX - subInset)
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -subInset, self.subY)
end

-- Nothing hugs the lines' text here: the reason is plain text on the leather.
function Leather:Fitted() end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Leather:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, self.baseInset) + 0.5
end

-- Whether the reason, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip, while a patch asks.
function Leather:SubFits(room)
	local kit = self.kit
	local sub, fit = kit.sub, kit.fit
	local width, size, base = self.subWidth, fit.size[sub], fit.base[sub]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, self.baseInset) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only
-- where a press casts something: the button armed (a fight's frozen macro
-- too, unlocked or not), never over a held panel with nothing armed, nor over
-- an outcome.
function Leather:KeyLabel()
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

-- The room the lines leave at the right for the key's patch with the count's
-- beside it.
function Leather:PairRoom()
	return math.ceil((self.keyRoom or 0) + (self.countW or self.chipW2) + 3)
end

-- The room the lines leave at the right for the count's patch alone.
function Leather:CountRoom()
	return math.ceil(self.chipRight + (self.countW or self.chipW2) + 4)
end

-- Run on every repaint. The patches sit left of the eyelet, on the reason's
-- line, so the name keeps its whole room: the key's patch where the reason
-- leaves room for it (else at the name line's end, where the name does, else
-- not at all), and the count's patch beside it, or, where the reason has no
-- room for both, at the name line's end. A patch steps aside for a paint in
-- which the line it stands on would otherwise be cut.
function Leather:Chip(on)
	local kit = self.kit
	local fit = kit.fit
	-- The width FitLine took of the name just now, measured here only where it
	-- could not; the patches' own words only when they change (Looks.lua: no
	-- pcall on a per-repaint path).
	self.nameWidth = fit.drawn[kit.name] or kit.TextWidth(kit.name)
	local two = fit.twoLine and true or false

	local key = self:KeyLabel()
	local lane
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipW2, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(self.chipRight + w + 3)
			-- A key bound anew is a patch of a new width: Prompt places the
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
		-- Prompt places the lines again, and PlaceLines keeps the key's room.
		fit.right = nil
		if lane then
			self.keyBox:ClearAllPoints()
			self.keyBox:SetPoint("TOPRIGHT", kit.art, "TOPRIGHT", -self.chipRight,
				-(lane == "sub" and self.subChipTop or self.chipTop))
			self.keyBoxW = nil
		end
	end
	if lane then
		local w, h = math.floor(self.keyW + 0.5), lane == "sub" and self.subChipH or self.chipH
		self.keyBox:SetSize(w, h)
		if w ~= self.keyBoxW then
			self.keyBoxW = w
			PlaceTagIn(self.keyChip, self.keyBox, w, h)
		end
	end
	Each(self.keyChip, "SetShown", lane ~= nil)
	self.keyText:SetShown(lane ~= nil)

	-- The count's patch is as wide as its words need: the room the lines keep
	-- for it is too, so the name never runs under a count of three digits.
	if on then
		local text = kit.count:GetText()
		if text ~= self.countText then
			self.countText = text
			self.countW = math.max(self.chipW2, (kit.TextWidth(kit.count) or self.sub) + 10)
			local room = self:CountRoom()
			if fit.chipRoom ~= room then
				fit.chipRoom = room
				fit.right = nil
			end
		end
	end
	local mode
	if on then
		if two then
			self.subWidth = fit.drawn[kit.sub] or kit.TextWidth(kit.sub)
			if self:SubFits(lane == "sub" and self:PairRoom() or self:CountRoom()) then
				mode = "sub"
			elseif lane == "name" then
				if self:NameFits(self:PairRoom()) then mode = "pair" end
			elseif self:NameFits(fit.chipRoom or 0) then
				mode = "chip"
			end
		elseif lane then
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(fit.chipRoom or 0) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local h = mode == "sub" and self.subChipH or self.chipH
		local w = math.floor(self.countW + 0.5)
		if mode ~= self.countMode or lane ~= self.countLane then
			self.chipBox:ClearAllPoints()
			if mode == "pair" or (mode == "sub" and lane == "sub") then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -3, 0)
			else
				self.chipBox:SetPoint("TOPRIGHT", kit.art, "TOPRIGHT", -self.chipRight,
					-(mode == "sub" and self.subChipTop or self.chipTop))
			end
			count:ClearAllPoints()
			count:SetPoint("CENTER", self.chipBox, "CENTER", 0, 0)
		end
		self.chipBox:SetSize(w, h)
		if w ~= self.chipBoxW or mode ~= self.countMode then
			self.chipBoxW = w
			PlaceTagIn(self.chip, self.chipBox, w, h)
		end
	end
	if mode ~= self.countMode then fit.right = nil end
	self.countMode, self.countLane = mode, lane
	Each(self.chip, "SetShown", mode ~= nil)
	kit.count:SetShown(mode ~= nil)
	-- Only a patch at the name line's end takes room from that line;
	-- PlaceLines gives each line its room.
	return mode == "chip" or mode == "pair"
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The thread, the enamel and the icon's rim, painted: the reason's colour where
-- the marker mode says, an outcome's (the verdict) over all of it, cream and a
-- dark hole with the marker off.
function Leather:Accent()
	local a = self.accent
	local kit = self.kit
	if not (a and kit) then return end
	local mode = a.mode or "icon"
	local out = a.outcome
	local tint = kit.Tint
	local tr, tg, tb = Bright(tint, a[1], a[2], a[3], 0.34)
	local er, eg, eb = Bright(tint, a[1], a[2], a[3], 0.22)
	local cr, cg, cb = CREAM[1], CREAM[2], CREAM[3]
	local pr, pg, pb = cr, cg, cb
	local ir, ig, ib = cr, cg, cb
	local stripe = out or mode == "stripe" or mode == "both"
	local rim = out or mode == "icon" or mode == "both"
	if self.combat then
		cr, cg, cb = FIGHT_THREAD[1], FIGHT_THREAD[2], FIGHT_THREAD[3]
		pr, pg, pb, ir, ig, ib = cr, cg, cb, cr, cg, cb
	else
		if stripe then pr, pg, pb = tr, tg, tb end
		if rim then ir, ig, ib = tr, tg, tb end
	end
	for _, t in pairs(self.thread) do t:SetVertexColor(pr, pg, pb, 1) end
	self.iconRim:SetVertexColor(ir, ig, ib, 1)
	-- The enamel in the eyelet's hole: every mode but off, and in a fight (grey).
	local enamel = out or mode ~= "off"
	self.enamel:SetShown(enamel)
	self.gloss:SetShown(enamel)
	self.enamel:SetVertexColor(er, eg, eb, 1)
	-- The reason's words: tan, a little towards the colour.
	local sr, sg, sb = TAN[1], TAN[2], TAN[3]
	if mode ~= "off" and not out then
		local mr, mg, mb = Bright(tint, a[1], a[2], a[3], 0.78)
		sr, sg, sb = sr + (mr - sr) * 0.22, sg + (mg - sg) * 0.22, sb + (mb - sb) * 0.22
	end
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.tint = { tr, tg, tb }
end

function Leather:PaintReason(r, g, b, _, mode)
	self.accent = { r, g, b, mode = mode or "icon" }
	self:Accent()
	-- A refusal greyed the icon; a fight keeps it grey.
	self.refused = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The fight holds the tag: the leather and the brass go to grey and darken, the
-- thread to a dull grey, the icon greys and dims, the name dims, the lights go
-- out. The reason stays as it was.
function Leather:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	for _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(on and TEXT_COMBAT or 1) end
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon showed the
	-- world through one half and the tag through the other.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if on then
		self:StopAttention()
		self:StopFlourishes()
	end
	self:Tone()
	self:Accent()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breathing, let go: after its breaths, and on Calm.
function Leather:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glowFrame:SetAlpha(0)
	self.ringGlowFrame:SetAlpha(0)
end

-- The glow over the thread in the colour it wears: the reason's, warmed.
function Leather:WarmThread()
	local w = WARM
	for _, t in pairs(self.glow) do t:SetVertexColor(w[1], w[2], w[3], 1) end
end

function Leather:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.glowSpent = nil
		-- The arrival: once per new favour, never over an outcome and never on
		-- Calm (fades only: a soft glow instead).
		if not self.outcomeOn then
			if full then
				PlayAll(self.arrive)
			else
				self:WarmThread()
				self.soft:Stop()
				self.soft:Play()
			end
		end
	end
	if flashStyle ~= "pulse" then
		-- No breath: but not StopAttention, which would stop the soft fade just
		-- played above for a favour arriving on Calm with the flash on "once".
		self.glowGen = (self.glowGen or 0) + 1
		self:HoldPulse()
		return
	end
	if not full or self.glowSpent then
		-- Calm, or breathed its fill: nothing loops.
		self:HoldPulse()
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top takes its own
	-- few breaths, not what is left of the last face's.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		self:WarmThread()
		self.glowFrame:SetAlpha(0)
		self.ringGlowFrame:SetAlpha(0)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.glowGen = (self.glowGen or 0) + 1
	local gen = self.glowGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Leather.glowGen or not Leather.active then return end
			Leather.glowSpent = true
			if Leather.pulse[1]:IsPlaying() then Leather:HoldPulse() end
		end)
	end
end

function Leather:StopAttention()
	self.glowGen = (self.glowGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glowFrame:SetAlpha(0)
	self.ringGlowFrame:SetAlpha(0)
	self.soft:Stop()
end

-- The thread's pieces in one colour, or the two of a refusal in turn.
function Leather:LightThread(r, g, b)
	for _, piece in ipairs(self.pieces) do piece.tex:SetVertexColor(r, g, b, 1) end
end

function Leather:Flourish(kind)
	local icon = self.kit.icon:IsShown()
	if kind == "failed" then
		-- A refusal: the tag jerks, the thread flashes red and amber in turn, one
		-- ring closes on the icon. The text's shake is Prompt's.
		for i, piece in ipairs(self.pieces) do
			local c = GHOSTS[(i % 2) + 1]
			piece.tex:SetVertexColor(c[1], c[2], c[3], 1)
		end
		self.ringFlash:SetVertexColor(1.00, 0.42, 0.20, 1)
		self.iconFlash:SetVertexColor(1.00, 0.42, 0.20, 1)
		PlayAll(self.refusal)
		if icon then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	local o = OUTCOME.cast
	-- The thread lights up paler than it rests: it is lit, over green already.
	self:LightThread(self.kit.Tint(o[1], o[2], o[3], 0.45))
	self.ringFlash:SetVertexColor(o[1], o[2], o[3], 1)
	self.iconFlash:SetVertexColor(o[1], o[2], o[3], 1)
	PlayAll(self.landing)
	if icon then self.fx:Land(o[1], o[2], o[3], 0.70) end
end

function Leather:StopFlourishes()
	for _, g in ipairs(self.landing) do g:Stop() end
	for _, g in ipairs(self.refusal) do g:Stop() end
	self.fx:Stop()
end

function Leather:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnim, self.hoverLight
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 0.5 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the reason line becomes the verdict, so the
-- eye never has to find the person again. The thread and the enamel take the
-- outcome's colour.
function Leather:PaintOutcome(kind, lead, sub, who, stamp)
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
	-- The owed breathing is about the favour, not the click: it stops.
	-- Attention starts it again for the next person owed.
	self:HoldPulse()
	self.accent = { o[1], o[2], o[3], mode = self.p.accentMode or "icon", outcome = true }
	self:Accent()
	self.refused = kind == "failed"
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	if kit.sub:IsShown() then kit.SetLine(kit.sub, word) end
end

function Leather:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The list hangs from the tag, three units off it, above or below: a small tag
-- for each row, its eyelet in the column of the main tag's, each a little
-- further in than the last, with an enamel dot in the row's reason colour.
function Leather:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i, tag in ipairs(self.tags) do
		if not (list and i <= shown) then
			Each(tag.body, "Hide")
			tag.eyelet:Hide()
			tag.dot:Hide()
		end
	end
	if not list then
		self.listShown, self.listAt = nil, nil
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		local r, g, b = Bright(kit.Tint, c[1], c[2], c[3], 0.22)
		self.tags[i].dot:SetVertexColor(r, g, b, 1)
	end
	-- Laid out again only when the number of rows or the side changes: the scan
	-- repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch, h = self.pitch, self.tagH
	local depth = shown * pitch
	local y0
	if above then
		y0 = -3 - depth + 1
	else
		y0 = self.H + 3
	end
	local right = self.ringX + 0.38 * h
	for i = 1, shown do
		local tag = self.tags[i]
		local top = y0 + (i - 1) * pitch
		local x0 = self.rowBase + (i - 1) * self.stagger
		PlaceTag(tag.body, art, x0, top, right, top + h)
		Each(tag.body, "Show")
		-- The eyelet, centred on the main tag's column.
		tag.eyelet:ClearAllPoints()
		tag.eyelet:SetSize(self.rowEye, self.rowEye)
		tag.eyelet:SetPoint("CENTER", art, "TOPLEFT", self.ringX, -(top + h / 2))
		tag.eyelet:Show()
		-- The dot, where the name begins.
		tag.dot:ClearAllPoints()
		tag.dot:SetSize(self.dotSize, self.dotSize)
		tag.dot:SetPoint("CENTER", art, "TOPLEFT", x0 + 0.45 * h + 2 + self.dotSize / 2, -(top + h / 2))
		tag.dot:Show()
		-- The row's name on the tag's middle line, beyond the dot.
		local fs = kit.rows[i]
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", x0 + self.rowOffset, -(top + h / 2))
	end
end
