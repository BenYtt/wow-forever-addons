-- Manners -- the Forge look: a plate of forged Khaz Modan iron, the reason
-- glowing like a bar just out of the forge in a slot beside the icon.
--
-- A plate of dark hammered iron with chamfered corners, a riveted strap along
-- its top and its bottom edge, the spell icon set in a bolted iron bezel, and
-- left of it a narrow slot cut in the metal whose floor glows in the reason
-- colour: heated steel, dull red to white as the colour says. The name and the
-- reason stand on the iron in cream; the count and the bound key sit on small
-- stamped tags at the right; the list is a second, darker plate hung under
-- (or over) the first, each row with a bead of its reason's colour. Its
-- dwarven reading is carried by the rivets and the chamfers, never by fine
-- detail: nothing stamped here is under two units on screen.
--
-- Every region is a texture from Textures/Forge (tools/make_forge_textures.py,
-- lit through tools/materials.py). The iron is baked, because it is
-- decoration; everything that means something -- the slot, its core, the
-- beads, the glyphs, the lights -- is white or grey art coloured by
-- SetVertexColor, so one file serves all six reasons, both palettes, a custom
-- marker colour and the outcomes. The interface this file implements is
-- described at the top of Looks/Looks.lua.
--
-- The rules it keeps (tests/scenarios/look-forge.lua):
--   * no additive light at rest: the heat shimmer, the bezel's white-hot
--     flash, the sparks and the rings are the only ADD regions, each a
--     flourish under 0.6 s parked at nothing; the breath and the hover are
--     BLEND in colours given here;
--   * the iron never brighter than luma 0.55; the plate under the words is
--     dark enough for cream at 4.5:1 at its brightest;
--   * nothing lies over the spell icon: the bezel starts where the icon ends,
--     and is drawn under it;
--   * the slot carries the reason in every marker mode but "off", where it is
--     a neutral warm grey (the bezel is iron and never carries it);
--   * a favour arriving: heat rises from the slot once; owed, the slot
--     breathes three times and then holds; a landing flashes the bezel
--     white-hot and throws sparks along the strap band, never up to the
--     words; a refusal quenches the slot to steel grey with a puff of steam
--     and greys the icon; a cast nobody confirmed does nothing;
--   * Calm keeps to fades: no shimmer, no loop, no sparks, no steam;
--   * a fight turns the iron to dull iron, dims the words and greys the icon;
--     the slot keeps its colour: the reason is the one coloured thing left;
--   * the icon is the slider's size and reads "Round the icon off"; the bezel
--     and its bloom are held inside the plate, and the bezel never lies over
--     the slot.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Forge\\Forge_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Forge = ns.Looks.Register("forge", {
	name = L["Forge -- forged iron, a riveted band"],
	title = L["Forge"],
	description = L["forged iron, a riveted band"],
	order = 7,
	-- The plate holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.55,
	-- The words stand on the iron whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_forge_textures.py (tests/scenarios/look-forge.lua
-- compares them): the icon fills this much of the bezel's file, the plate's
-- design height in texels, the strap's rivet tile and height in units, a
-- rivet's diameter, the slot's width and tallest height, where the ring file's
-- line sits, the tag's caps as a fraction of its height, how far above the
-- strap a spark may reach, how much larger than the bezel its bloom is drawn,
-- and the round mask's fill.
local ICON_FRAME = 0.75
local DESIGN_H = 128
local STRAP_TILE = 16
local STRAP_H = 4
local RIVET = 2.2
local SLOT_W = 3
local SLOT_H_MAX = 24
local RING_AT = 0.78
local TAG_CAPS = 0.5
local SPARK_CEIL = 3
local GLOW_SCALE = 1.1
local MASK_FILL = 0.985
-- The ring files as the generator prints them (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width
-- (hunt37-effects holds these to the files).
local RING_PEAK, RING_EDGE = 0.773, 0.94
-- The plate's three-slice: its end caps' width in design texels, and how far a
-- tile may be stretched to end on a whole one (the planish hides it).
local CAP_W, STRETCH = 32, 0.20
-- The icon's left edge at the least, and the gap the bezel keeps from the slot.
local ICON_X, SLOT_GAP = 13, 8
-- The text's distance from the bezel's right edge; with the icon off, from the
-- plate's left.
local TEXT_GAP, TEXT_X_BARE = 5, 14
-- The plate's own luminance under the words, its darkest and its brightest
-- (relative luminance of the iron's two ends), for Legible.
local PLATE_LO, PLATE_HI = 0.14, 0.30
-- A chosen panel colour is mixed this far into the iron.
local PLATE_MIX = 0.25
-- The list's plate is this much darker than the first.
local LIST_TONE = 0.70
-- The shadow: its 9-slice corner in units (32 texels at 2 texels per unit),
-- and how far past the plate its box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local CREAM = { 1.00, 0.95, 0.86 }
local TAG_INK = { 1.00, 0.92, 0.78 }
local WARM_GREY = { 0.80, 0.75, 0.66 }
local IRON = { 0.62, 0.62, 0.64 }
-- The slot with the marker off, and quenched by a refusal.
local NEUTRAL = { 0.46, 0.40, 0.35 }
local STEEL = { 0.42, 0.46, 0.52 }
local HOVER = { 0.60, 0.50, 0.35 }
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the plate dims.
local TEXT_COMBAT, ICON_COMBAT, PLATE_COMBAT = 0.78, 0.70, 0.80
-- The slot's alpha, its core at rest, lit, and held after its breaths; the
-- bezel's warm copy over the same breath and held. That copy is the rounded
-- square, bolts and mitres and all, in the slot's heat colour: past 0.12 (0.07
-- held on Calm) the iron's dark seams lift and it reads as grey under haze.
local SLOT_ALPHA = 0.85
local CORE_REST, CORE_PEAK, CORE_HELD = 0.25, 0.55, 0.40
local WARM_REST, WARM_PEAK, WARM_HELD = 0.04, 0.12, 0.07
local BREATHS, BREATH = 3, 1.25
-- The steam's frame, in units, and how far it rises.
local STEAM, STEAM_RISE = 10, 4
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, and the straps round it.
function Forge.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 16)
end

-- The bezel is iron and never carries the reason; the slot does, in every
-- mode but off.
function Forge.AccentCarriers(p)
	return false, (p.accentMode or "icon") ~= "off"
end

-- A heated colour: the reason's, more saturated about its luma, and a warm
-- gold (the owed reason) fired deeper to amber, so it never reads as one
-- more piece of metal.
local function Heated(r, g, b)
	local l = 0.299 * r + 0.587 * g + 0.114 * b
	local k = 1.2
	local er, eg, eb = Clamp(l + (r - l) * k, 0, 1), Clamp(l + (g - l) * k, 0, 1), Clamp(l + (b - l) * k, 0, 1)
	if er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then
		eg = eg * 0.70
		er, eg, eb = er * 0.75, eg * 0.75, eb * 0.75
	end
	return er, eg, eb
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

-- Whether this client reads an English string in its own language.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

-- Relative luminance of a grey, for the plate's own ink figures.
local function Luminance(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
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

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- How many tiles of `unit` a length holds: a whole number when within STRETCH
-- of one (the tile is stretched to fit), else the fraction, so the planish
-- never shows a cut cell at a strap's end. `whole` forces a whole count.
local function Tiles(length, unit, whole)
	local n = math.max(0, length) / unit
	local r = math.max(1, math.floor(n + 0.5))
	if whole or (n > 0 and math.abs(r / math.max(n, 1e-6) - 1) <= STRETCH) then return r end
	return n
end

-- A frame cut from one file into nine: corners from the outer quarters, edges
-- from the middle strips (the shadow).
local CUT = {
	{ 0, 0.25, 0, 0.25 }, { 0.25, 0.75, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.25, 0.75 }, { 0.75, 1, 0.25, 0.75 },
	{ 0, 0.25, 0.75, 1 }, { 0.25, 0.75, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
	{ 0.25, 0.75, 0.25, 0.75 },
}

local function Pieces(parent, layer, sublevel, file, keep)
	local s = {}
	for i = 1, 9 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(CUT[i][1], CUT[i][2], CUT[i][3], CUT[i][4])
		s[i] = keep(t)
	end
	return s
end

local function PlacePieces(s, rel, x0, y0, x1, y1, c)
	Box(s[1], rel, x0, y0, x0 + c, y0 + c)
	Box(s[2], rel, x0 + c, y0, x1 - c, y0 + c)
	Box(s[3], rel, x1 - c, y0, x1, y0 + c)
	Box(s[4], rel, x0, y0 + c, x0 + c, y1 - c)
	Box(s[5], rel, x1 - c, y0 + c, x1, y1 - c)
	Box(s[6], rel, x0, y1 - c, x0 + c, y1)
	Box(s[7], rel, x0 + c, y1 - c, x1 - c, y1)
	Box(s[8], rel, x1 - c, y1 - c, x1, y1)
	Box(s[9], rel, x0 + c, y0 + c, x1 - c, y1 - c)
end

-- The plate: its left end, its tiled middle and its right end, from the three
-- files at the design height.
local function Plate(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "PlateL", "PlateM", "PlateR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "REPEAT") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- A plate laid over a box: the caps are the design's proportion of its height,
-- the middle tiled along the rest.
local function PlacePlate(s, rel, x0, y0, x1, y1)
	local h = y1 - y0
	local su = h / DESIGN_H
	local cap = math.min(CAP_W * su, (x1 - x0) / 3)
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, x1 - cap, y1)
	Box(s[3], rel, x1 - cap, y0, x1, y1)
	s[2]:SetTexCoord(0, Tiles(x1 - x0 - 2 * cap, DESIGN_H * su), 0, 1)
end

-- A strap: its left end, its riveted middle (whole tiles) and its right end,
-- the same end file mirrored.
local function Strap(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "StrapEnd", "StrapM", "StrapEnd" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "REPEAT") else t:SetTexture(ART .. file) end
		if i == 3 then t:SetTexCoord(1, 0, 0, 1) end
		s[i] = keep(t)
	end
	return s
end

local function PlaceStrap(s, rel, x0, y0, x1, h)
	local y1 = y0 + h
	local cap = math.min(h, (x1 - x0) / 3)
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, x1 - cap, y1)
	Box(s[3], rel, x1 - cap, y0, x1, y1)
	-- One rivet per tile, the tile scaled with the strap's height.
	local tile = STRAP_TILE * h / STRAP_H
	s[2]:SetTexCoord(0, Tiles(x1 - x0 - 2 * cap, tile, true), 0, 1)
end

-- A horizontal three-slice from one file: caps TAG_CAPS of the height, the
-- middle stretched (the tags).
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
	local cap = height * TAG_CAPS
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

-- A texture centred at a point of `rel`'s top left, y running down.
local function At(t, rel, cx, cy, w, h)
	t:ClearAllPoints()
	t:SetPoint("CENTER", rel, "TOPLEFT", cx, -cy)
	t:SetSize(w, h or w)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights, parked between
-- plays, so nothing is left lit when it stops
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

-- Up to `peak`, then down to `rest` (nothing unless said).
local function Flash(region, peak, up, down, rest, upSmooth, downSmooth)
	local g = region:CreateAnimationGroup()
	g.up = Alpha(g, rest or 0, peak, up, 1, nil, upSmooth or "OUT")
	g.down = Alpha(g, peak, rest or 0, down, 2, nil, downSmooth or "IN")
	Park(g, region, rest or 0)
	return g
end

-- A breath: `lo` to `hi` and back, for as long as it is left to.
local function Breathe(region, lo, hi)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	Alpha(g, lo, hi, BREATH, 1, nil, "IN_OUT")
	Park(g, region, lo)
	return g
end

-- One fade from `from` to `to`, which it then holds.
local function Fade(region, from, to, duration)
	local g = region:CreateAnimationGroup()
	Alpha(g, from, to, duration, 1, nil, "OUT")
	Park(g, region, to)
	return g
end

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

local function StopAll(list)
	for _, g in ipairs(list) do g:Stop() end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Forge:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local function keep(x) own[#own + 1] = x return x end
	local function tex(parent, layer, sublevel, file, blend)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end
	local function anim(g) anims[#anims + 1] = g return g end
	local base = art:GetFrameLevel()
	-- A frame of light a few levels over the art and under the text.
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.listPlate = Plate(art, "BACKGROUND", -7, keep)
	self.plate = Plate(art, "BACKGROUND", -6, keep)
	-- The straps along the top and the bottom edge, and the list's far edge.
	self.strapTop = Strap(art, "BORDER", 1, keep)
	self.strapBottom = Strap(art, "BORDER", 1, keep)
	self.listStrap = Strap(art, "BORDER", 1, keep)
	-- The slot: the channel, and the soft core that breathes in it.
	self.slot = tex(art, "BORDER", 3, "Slot")
	self.core = tex(art, "BORDER", 4, "SlotCore")
	-- The bezel, under the icon (ARTWORK 0): nothing of it lies over the
	-- spell. Its warm copy breathes with the slot (BLEND); its hot copy is the
	-- landing's flash (ADD).
	self.bezel = tex(art, "ARTWORK", -2, "Bezel")
	self.bezelWarm = tex(art, "ARTWORK", -1, "BezelGlow")
	self.bezelHot = tex(art, "ARTWORK", -1, "BezelGlow", "ADD")
	self.bezelWarm:SetAlpha(0)
	self.bezelHot:SetAlpha(0)
	-- hunt35-effects reads the owed breath by these names: the slot's core
	-- and the warm second tone.
	self.pulseRing, self.ringWarm = self.core, self.bezelWarm

	-- The rings that spread from the bezel when a buff lands and the one that
	-- snaps in when one is refused: frames over the art, under the text. No
	-- echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)
	kit.RingArt(ART .. "RingSq", RING_PEAK, RING_EDGE)

	-- The heat over the slot as a favour arrives.
	self.heatFrame = frame(2)
	self.heat = tex(self.heatFrame, "OVERLAY", 1, "Heat", "ADD")
	self.heat:SetAllPoints(self.heatFrame)
	self.heat:SetAlpha(0)
	-- The sparks a landing throws along the strap band: six, each on a frame
	-- of its own, so each flies its own way.
	self.sparkFrames, self.sparks = {}, {}
	for i = 1, 6 do
		local f = frame(2)
		local t = tex(f, "OVERLAY", 1, "Spark", "ADD")
		t:SetAllPoints(f)
		t:SetAlpha(0)
		self.sparkFrames[i], self.sparks[i] = f, t
	end
	-- The steam as a refusal quenches the slot.
	self.steamFrame = frame(2)
	self.steam = tex(self.steamFrame, "OVERLAY", 1, "Steam")
	self.steam:SetAllPoints(self.steamFrame)
	self.steam:SetAlpha(0)
	-- The cursor's light: the top strap warmed.
	self.hoverFrame = frame(1)
	self.hoverLight = keep(self.hoverFrame:CreateTexture(nil, "OVERLAY", nil, 1))
	self.hoverLight:SetTexture(WHITE)
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's beads, one a row, in the row's reason colour.
	self.beads = {}
	for i = 1, #kit.rows do self.beads[i] = tex(art, "ARTWORK", 1, "Bead") end

	-- The chips: stamped tags at the plate's right end; their text is on
	-- textLayer, over them.
	self.chipFrame = frame(3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Tag", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Tag", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The verdict's tick or cross, before the second line.
	self.glyph = tex(textLayer, "ARTWORK", 1, "Check")

	-- The icon's round shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "MaskRd", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything iron, for a fight's dulling: the straps, the bezel, the
	-- tags, the list's plate and strap, the glyph.
	self.iron = { self.bezel, self.glyph }
	for _, s in ipairs({ self.strapTop, self.strapBottom, self.listStrap, self.chip, self.keyChip, self.listPlate }) do
		for _, t in ipairs(s) do self.iron[#self.iron + 1] = t end
	end
	self.ironTone = {}
	for _, t in ipairs(self.listPlate) do self.ironTone[t] = LIST_TONE end

	self:BuildAnimations(anim)
end

function Forge:BuildAnimations(anim)
	-- The owed breath: the slot's core lit and let go, and the bezel warmed
	-- on the same breath; see Attention for how long.
	self.pulse = { anim(Breathe(self.core, CORE_REST, CORE_PEAK)), anim(Breathe(self.bezelWarm, WARM_REST, WARM_PEAK)) }
	-- "Once": one rise and fall of 0.55 s.
	self.once = { anim(Flash(self.core, CORE_PEAK, 0.25, 0.30, CORE_REST, "OUT", "OUT")),
		anim(Flash(self.bezelWarm, WARM_PEAK, 0.25, 0.30, 0, "OUT", "OUT")) }
	-- Calm: one fade up to the held glow, and nothing after.
	self.calm = { anim(Fade(self.core, CORE_REST, CORE_HELD, 0.5)), anim(Fade(self.bezelWarm, 0, WARM_HELD, 0.5)) }
	-- The heat as a favour arrives: 0.48 s.
	self.heatAnim = anim(Flash(self.heat, 0.6, 0.08, 0.40))
	self.arrive = { self.heatAnim }
	-- The bezel white-hot as a buff lands: 0.45 s.
	self.hotAnim = anim(Flash(self.bezelHot, 0.7, 0.07, 0.38))
	-- The sparks: each flies its own way (Apply sets how far) for a little
	-- longer than the last, 0.035 s apart; the last is out by 0.555 s, under
	-- the landing's 0.7. Each head is 1.7 units and the six start 3 units
	-- apart (Apply), so no two are born together or on top of each other:
	-- six sparks leave the bezel one after another rather than one white blob
	-- for the first tenth of a second. Lit at 0.75, not 0.9.
	self.sparkAnims = {}
	for i, t in ipairs(self.sparks) do
		local g = t:CreateAnimationGroup()
		local k = i - 1
		local seconds = 0.30 + 0.016 * k
		local move = g:CreateAnimation("Translation")
		move:SetDuration(seconds)
		move:SetOrder(1)
		if move.SetStartDelay then move:SetStartDelay(0.035 * k) end
		if move.SetSmoothing then move:SetSmoothing("OUT") end
		g.move = move
		Alpha(g, 0.75, 0, seconds, 1, 0.035 * k, "IN")
		Park(g, t, 0)
		self.sparkAnims[i] = anim(g)
	end
	-- The steam: up and out, swelling a little, 0.35 s.
	local steam = self.steam:CreateAnimationGroup()
	Alpha(steam, 0, 0.5, 0.10, 1, nil, "OUT")
	Alpha(steam, 0.5, 0, 0.25, 1, 0.10, "IN")
	local swell = steam:CreateAnimation("Scale")
	self.steamSwell = swell
	if swell.SetScaleFrom then swell:SetScaleFrom(0.8, 0.8) end
	if swell.SetScaleTo then swell:SetScaleTo(1.2, 1.2) end
	if swell.SetOrigin then swell:SetOrigin("CENTER", 0, 0) end
	swell:SetDuration(0.35)
	swell:SetOrder(1)
	if swell.SetSmoothing then swell:SetSmoothing("OUT") end
	local rise = steam:CreateAnimation("Translation")
	rise:SetOffset(0, STEAM_RISE)
	rise:SetDuration(0.35)
	rise:SetOrder(1)
	if rise.SetSmoothing then rise:SetSmoothing("OUT") end
	Park(steam, self.steam, 0)
	self.steamAnim = anim(steam)
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The cursor's light on the top strap, both ways; from and to are set for
	-- each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Forge:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	local round = p.roundIcon and true or false
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua), and how far left of the text it starts.
	self.pitch = sub + 7
	self.rowReach = 18

	local slim = H < 40
	local strapH = slim and 3 or STRAP_H
	-- The bottom strap's upper edge, above the plate's bottom: the sparks' lane.
	local strapTop = strapH
	self.slim, self.strapH, self.strapLine = slim, strapH, strapTop

	-- The plate is the whole button; the straps run along its edges.
	PlacePlate(self.plate, art, 0, 0, W, H)
	PlaceStrap(self.strapTop, art, 2, 0, W - 2, strapH)
	PlaceStrap(self.strapBottom, art, 2, H - strapH, W - 2, strapH)
	-- The plate's colour: iron as it is, or a chosen panel colour mixed in.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local pr, pg, pb = 1, 1, 1
	if not Untouched(c, d) then
		pr = 1 + ((c[1] or 0) - 1) * PLATE_MIX
		pg = 1 + ((c[2] or 0) - 1) * PLATE_MIX
		pb = 1 + ((c[3] or 0) - 1) * PLATE_MIX
	end
	self.plateColour = { pr, pg, pb }
	local alpha = (type(c) == "table" and c[4]) or 1
	self.shadowAlpha = math.min(1, alpha + 0.05) * (alpha < 0.2 and 0 or 1)
	Each(self.shadow, "SetVertexColor", 0, 0, 0, self.shadowAlpha)
	self.listBox = nil
	self:PlaceShadow(nil)

	-- The slot, left of the icon, as tall as the plate allows.
	local slotH = math.min(SLOT_H_MAX, H - 10)
	self.slotH = slotH
	Box(self.slot, art, 4, (H - slotH) / 2, 4 + SLOT_W, (H + slotH) / 2)
	Box(self.core, art, 4, (H - slotH) / 2, 4 + SLOT_W, (H + slotH) / 2)
	At(self.heatFrame, art, 4 + SLOT_W / 2, H / 2, 8, math.min(H - 2, slotH + 6))
	At(self.steamFrame, art, 4 + SLOT_W / 2, H / 2, STEAM, STEAM)
	-- The steam swells no further than the plate's top allows once it has
	-- risen: a unit inside at every height.
	local cap = kit.CapScale(H / 2 - 1 - STEAM_RISE, STEAM / 2, 1.0)
	local to = math.min(1.2, cap)
	if self.steamSwell.SetScaleFrom then self.steamSwell:SetScaleFrom(math.min(0.8, to), math.min(0.8, to)) end
	if self.steamSwell.SetScaleTo then self.steamSwell:SetScaleTo(to, to) end

	-- The icon: the slider's size, held inside the plate; its left edge clear
	-- of the slot by the bezel's outset, so the bezel never covers the slot.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local outset = iconSize / 6
	local iconX = math.max(ICON_X, SLOT_GAP + outset)
	local cy = H / 2
	-- The bezel: the icon's file frame, held inside the plate. When the cap
	-- bites, the hole shrinks under the icon, which draws over it.
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local bezelRight = iconX + iconSize + outset
	local textX = showIcon and (bezelRight + TEXT_GAP) or TEXT_X_BARE
	self.iconSize, self.iconX, self.bz, self.bezelRight, self.textX = iconSize, iconX, bz, bezelRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", iconX + iconSize / 2, -cy)
	local bezelFile = ART .. (round and "BezelRd" or "Bezel")
	self.bezel:SetTexture(bezelFile)
	At(self.bezel, art, iconX + iconSize / 2, cy, bz)
	-- Its bloom, GLOW_SCALE larger, held inside the plate with the light's
	-- own margin top and bottom (THE ROOM): the capped bezel times the scale
	-- would leave the plate at any icon over 30.
	local bloom = math.min(bz * GLOW_SCALE, H - 2 * kit.EDGE_MARGIN)
	-- The bloom's bright band ends 0.88 of its half-width out. Where the cap
	-- sinks that band under the icon, which draws over it (icon 36 at the
	-- default height, the extreme size), the landing's flash is carried on
	-- the iron itself: the bezel's rim in white (BezelHot, the bezel's own
	-- outline), additive, at the bezel's size, so the rim goes white-hot
	-- inside the plate. The bezel's dark iron in ADD would barely show.
	local hotOnRim = 0.88 * bloom / 2 < iconSize / 2 + 2
	-- The bloom in the bezel's shape: a rounded square round the square
	-- bezel, whose band takes in the corner bolts (a disc cut across them),
	-- and a disc round the round one.
	local glowFile = round and "BezelGlowRd" or "BezelGlow"
	self.bezelWarm:SetTexture(ART .. glowFile)
	At(self.bezelWarm, art, iconX + iconSize / 2, cy, bloom)
	local hotFile = hotOnRim and (round and "BezelHotRd" or "BezelHot") or glowFile
	self.bezelHot:SetTexture(ART .. hotFile)
	At(self.bezelHot, art, iconX + iconSize / 2, cy, hotOnRim and bz or bloom)
	-- The warm copy takes the slot's heat colour in Tint: the iron warms, it
	-- is never whitened.
	self.bezelHot:SetVertexColor(1.00, 0.85, 0.60, 1)
	-- Round only when asked: the mask on the icon and the cooldown's swipe.
	local maskFile = ART .. "MaskRd"
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	if round and showIcon then
		if not self.masked then
			icon:AddMaskTexture(self.mask)
			self.masked = true
		end
		self.mask:Show()
	else
		if self.masked then
			icon:RemoveMaskTexture(self.mask)
			self.masked = nil
		end
		self.mask:Hide()
	end
	if showIcon then
		-- The rings spread from the bezel's edge.
		self.fx:Place(icon, self.fx.ThinPad(iconSize, outset + 1), iconSize)
		self.fx:Shape(round, ART .. "Ring", ART .. "RingSq", maskFile)
		-- The room the rings have: to the text (less a margin), to the plate's
		-- left edge, and to its top and bottom.
		local cxIcon = iconX + iconSize / 2
		local limitH = math.min(textX - cxIcon - kit.TEXT_MARGIN, cxIcon - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(round and maskFile or WHITE) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
		end
	end

	-- The sparks: from the bezel's right edge along the bottom strap, three
	-- units apart, none past the plate's end; and whether there is room for
	-- them at all under the lowest line (computed, never a fixed height). The
	-- first thrown flies furthest and each after it a little shorter, so a
	-- spark that leaves later never runs into one already in flight (when
	-- each flew further than the last, the late ones caught the early ones up
	-- and the six met in one bright knot 0.15 to 0.25 s in). Each also lands
	-- two units short of the one before, so the spray scatters as it cools
	-- instead of closing on one point.
	local block = fs + 2 + sub
	self.block = block
	local twoLine = p.showSub and H >= Forge.TwoLineHeight(fs)
	local lowest = twoLine and (H - block) / 2 or (H - fs) / 2
	local sparksOK = H >= 32 and (lowest - 2) >= strapTop + SPARK_CEIL
	local dys = { -1, 0, 1, 0, 1, -1 }
	for i, f in ipairs(self.sparkFrames) do
		local k = i - 1
		local x = (showIcon and bezelRight or TEXT_X_BARE) - 2 + 3 * k
		At(f, art, x, H - (strapTop + 0.5), 3, 3)
		local run = math.min(46 - 5 * k, W - 2 - x - 1.5)
		if run < 4 then sparksOK = false end
		self.sparkAnims[i].move:SetOffset(math.max(0, run), dys[i])
		self.sparks[i]:SetVertexColor(1.00, 0.80, 0.45, 1)
	end
	self.sparksOK = sparksOK

	-- The cursor's light over the top strap.
	Box(self.hoverFrame, art, 2, 0, W - 2, strapH)
	self.hoverLight:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], 1)

	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	local chipH = sub + 7
	self.chipH = chipH
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -8, 0)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	self.rowX = showIcon and textX or TEXT_X_BARE
	local rowWidth = math.max(20, W - self.rowX - 12)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.bezel, self.bezelWarm, self.bezelHot }) do t:SetShown(showIcon) end
	self.fx:SetShown(showIcon)
	Each(self.listPlate, "Hide")
	Each(self.listStrap, "Hide")
	for _, t in ipairs(self.beads) do t:Hide() end
	self.glyph:Hide()
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	self.core:SetAlpha(CORE_REST)
	self.bezelWarm:SetAlpha(0)
	self.bezelHot:SetAlpha(0)
	self.heat:SetAlpha(0)
	self.steam:SetAlpha(0)
	for _, t in ipairs(self.sparks) do t:SetAlpha(0) end
	self.hoverLight:SetAlpha(0)
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent, self.calmLit = nil, nil
	self:Dull(false)
	if held then self:Combat(true) end

	-- The count's room: a two-digit tag and its inset. Chip widens it for a
	-- longer count.
	self.roomBase = math.ceil(chipH * 1.75) + 15
	return textX, self.roomBase
end

-- The shadow under the plate, and under the list's plate when it is out.
function Forge:PlaceShadow(list)
	local W, H = self.W, self.H
	local x0, y0, x1, y1 = -SHADOW_OUT + 2, -SHADOW_OUT + 2, W + SHADOW_OUT + 1, H + SHADOW_OUT + 3
	if list then
		y0 = math.min(y0, list[2] - SHADOW_OUT + 2)
		y1 = math.max(y1, list[4] + SHADOW_OUT + 3)
	end
	PlacePieces(self.shadow, self.kit.art, x0, y0, x1, y1, SHADOW_C)
end

function Forge:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the iron, whatever the panel colour: the legibility the
	-- shared code works out is held against the plate's own two ends.
	ink.light = true
	ink.lo, ink.hi = Luminance(PLATE_LO), Luminance(PLATE_HI)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen then
		kit.name:SetTextColor(CREAM[1], CREAM[2], CREAM[3], 1)
	end
	kit.name:SetShadowColor(0, 0, 0, 0.9)
	kit.name:SetShadowOffset(1, -1)
	-- The tags are iron whatever the panel, so their text is cream as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.88, 0.86, 0.82, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffa8a39b"
end

function Forge:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	-- Every parked light at nothing after the Stop: a finished fade is not
	-- stopped at all, and the cursor leaves for the next look.
	self.core:SetAlpha(CORE_REST)
	self.bezelWarm:SetAlpha(0)
	self.bezelHot:SetAlpha(0)
	self.heat:SetAlpha(0)
	self.steam:SetAlpha(0)
	for _, t in ipairs(self.sparks) do t:SetAlpha(0) end
	self.hoverLight:SetAlpha(0)
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
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
	self.pulseSpent, self.calmLit = nil, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Forge:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	local inset = math.max(right, 10)
	if self.keyUp then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
	-- The two points never cross: the name keeps 20 units, the room at the
	-- right gives way.
	inset = math.min(inset, math.max(0, self.W - self.textX - 20))
	self.inset = inset
	self.lineRoom = math.max(20, self.W - self.textX - inset)
	fit.room[name] = self.lineRoom
	if fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -inset, self.nameY)
	else
		name:SetPoint("LEFT", self.textX, 0)
		name:SetPoint("RIGHT", -inset, 0)
	end
	-- Placed again by Fitted, which knows whether the verdict's glyph leads.
	self.subLead = nil
	fit.room[sub] = self.lineRoom
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -inset, self.subY)
end

-- Whether the reason line holds the verdict PaintOutcome wrote: the only
-- time a glyph leads it.
function Forge:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Forge:Fitted(fs)
	local kit = self.kit
	if fs ~= kit.sub or not self.lineRoom then return end
	local glyph = self.glyphOn and self:ShowsVerdict()
	local lead = glyph and self.glyphRoom or 0
	local room = self.lineRoom - lead
	if kit.fit.room[fs] ~= room then
		-- Fitted again at the room the glyph leaves, which lands back here.
		kit.fit.room[fs] = room
		return kit.FitLine(fs)
	end
	if self.subLead ~= lead then
		self.subLead = lead
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", self.textX + lead, self.subY)
		fs:SetPoint("RIGHT", -(self.inset or 10), self.subY)
	end
	self.glyph:SetShown((glyph and fs:IsShown()) and true or false)
end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Forge:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, 10) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil: only
-- where a press casts something (the button armed, a fight's frozen macro
-- too), never over a held panel with nothing armed, nor over an outcome.
function Forge:KeyLabel()
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
-- beside it.
function Forge:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - 5
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Forge:Chip(on)
	local kit = self.kit
	-- The width FitLine took of the name just now, measured here only where
	-- it could not; the tags' own words only when they change (kit.TextWidth
	-- is a pcall: none on a per-scan path).
	self.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(w + 15)
			-- A key bound anew is a tag of a new width: Prompt places the
			-- lines again, beside it.
			kit.fit.right = nil
		end
		keyUp = self:NameFits(self.keyRoom)
	end
	if keyUp ~= self.keyUp then
		self.keyUp = keyUp
		kit.fit.right = nil
	end
	if keyUp then self.keyBox:SetWidth(math.floor(self.keyW + 0.5)) end
	for _, t in ipairs(self.keyChip) do t:SetShown(keyUp) end
	self.keyText:SetShown(keyUp)

	if on then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		text = count:GetText()
		if text ~= self.countText then
			self.countText = text
			self.countW = math.max(self.chipH * 1.75, (kit.TextWidth(count) or self.sub) + 10)
		end
		kit.fit.chipRoom = math.max(self.roomBase or 0, math.ceil(self.countW) + 15)
	end
	local mode
	if on then
		if keyUp then
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(kit.fit.chipRoom or 0) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local h = self.chipH
		local w = self.countW
		if mode ~= self.countMode then
			self.chipBox:ClearAllPoints()
			if mode == "pair" then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			else
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -8, 0)
			end
			PlaceThree(self.chip, self.chipBox, h)
			count:ClearAllPoints()
			count:SetPoint("CENTER", self.chipBox, "CENTER", 0, 0)
		end
		self.chipBox:SetSize(math.floor(w + 0.5), h)
	end
	self.countMode = mode
	for _, t in ipairs(self.chip) do t:SetShown(mode ~= nil) end
	kit.count:SetShown(mode ~= nil)
	-- Only a tag at the right takes room from the lines; PlaceLines gives a
	-- pair the room of both.
	return mode == "chip" or mode == "pair"
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The slot's floor and core in one colour, and the reason line warmed
-- towards it. A refusal's slot is quenched steel until the next PaintReason.
function Forge:Tint(r, g, b)
	local kit = self.kit
	if self.refused then
		self.slot:SetVertexColor(STEEL[1], STEEL[2], STEEL[3], SLOT_ALPHA)
	else
		local hr, hg, hb = Heated(r, g, b)
		self.slot:SetVertexColor(hr, hg, hb, SLOT_ALPHA)
		-- The bezel breathes in the slot's own heat.
		self.bezelWarm:SetVertexColor(hr, hg, hb, 1)
	end
	local cr, cg, cb = kit.Tint(r, g, b, 0.45)
	self.core:SetVertexColor(cr, cg, cb, 1)
	-- The reason line: warm grey taken most of the way to the reason, held to
	-- its contrast on the iron.
	local sr = WARM_GREY[1] + (r - WARM_GREY[1]) * 0.6
	local sg = WARM_GREY[2] + (g - WARM_GREY[2]) * 0.6
	local sb = WARM_GREY[3] + (b - WARM_GREY[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { r, g, b }
end

function Forge:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal quenched the slot and greyed the icon: the slot takes its
	-- colour back here, and a fight keeps the icon grey.
	self.refused = nil
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
	else
		-- "stripe" is "both" here: the slot is where the reason is.
		self:Tint(r, g, b)
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The iron dulled for a fight, or back to itself.
function Forge:Dull(on)
	for _, t in ipairs(self.iron) do
		t:SetDesaturated(on)
		local k = self.ironTone[t] or 1
		if on then
			t:SetVertexColor(IRON[1] * k, IRON[2] * k, IRON[3] * k, 1)
		else
			t:SetVertexColor(k, k, k, 1)
		end
	end
	local pc = self.plateColour or { 1, 1, 1 }
	local f = on and PLATE_COMBAT or 1
	Each(self.plate, "SetVertexColor", pc[1] * f, pc[2] * f, pc[3] * f, 1)
end

-- The plate holds; the iron dulls, the icon greys, the words dim and the
-- lights go out. The slot keeps its colour: the reason is the one coloured
-- thing left.
function Forge:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Dull(on)
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon shows two
	-- grounds.
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

-- The breathing, let go: held at its after-glow once it has breathed its
-- fill (`spent`), else at rest.
function Forge:HoldPulse(spent)
	StopAll(self.pulse)
	self.core:SetAlpha(spent and CORE_HELD or CORE_REST)
	self.bezelWarm:SetAlpha(spent and WARM_HELD or 0)
end

function Forge:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- Heat rises from the slot for a new favour, never for a new face.
		if full then PlayAll(self.arrive) end
	end
	if flashStyle ~= "pulse" then
		-- "Once": one rise and fall for the new favour, and still after.
		if isNew and full then
			self:HoldPulse()
			PlayAll(self.once)
		elseif not self.once[1]:IsPlaying() then
			self:HoldPulse()
		end
		return
	end
	if not full then
		-- Calm: one fade up to the held glow, and nothing loops.
		if not self.calmLit then
			self.calmLit = true
			StopAll(self.pulse)
			PlayAll(self.calm)
		end
		return
	end
	if self.pulseSpent then
		self:HoldPulse(true)
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top keeps the
	-- breathing going but takes its own three breaths.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		StopAll(self.calm)
		self.core:SetAlpha(CORE_REST)
		self.bezelWarm:SetAlpha(WARM_REST)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Forge.pulseGen or not Forge.active then return end
			Forge.pulseSpent = true
			if Forge.pulse[1]:IsPlaying() then Forge:HoldPulse(true) end
		end)
	end
end

function Forge:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	self.core:SetAlpha(CORE_REST)
	self.bezelWarm:SetAlpha(0)
	self.calmLit = nil
end

function Forge:Flourish(kind)
	-- A refusal quenches: the slot goes to steel with a puff of steam, and one
	-- ring snaps in onto the bezel. The text's shake is Prompt's.
	if kind == "failed" then
		local o = OUTCOME.failed
		self.refused = true
		self:Tint(o[1], o[2], o[3])
		self.steamAnim:Stop()
		self.steamAnim:Play()
		if self.kit.icon:IsShown() then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	if self.kit.icon:IsShown() then
		self.hotAnim:Stop()
		self.hotAnim:Play()
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
	-- Sparks along the strap band, only where the lowest line leaves them room.
	if self.sparksOK then PlayAll(self.sparkAnims) end
end

function Forge:StopFlourishes()
	self.hotAnim:Stop()
	StopAll(self.sparkAnims)
	self.steamAnim:Stop()
	self.fx:Stop()
end

function Forge:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.hoverLight
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 0.25 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	if g.fade.SetSmoothing then g.fade:SetSmoothing(on and "OUT" or "IN") end
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so
-- the eye never has to find the person again. The slot's core takes the
-- outcome's colour.
function Forge:PaintOutcome(kind, lead, sub, who, stamp)
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
	StopAll(self.calm)
	StopAll(self.once)
	self.core:SetVertexColor(o[1], o[2], o[3], 1)
	self.refused = kind == "failed"
	if self.refused then
		self.slot:SetVertexColor(STEEL[1], STEEL[2], STEEL[3], SLOT_ALPHA)
	end
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)
	kit.sub:SetTextColor(vr, vg, vb, 1)
	self.glyph:SetVertexColor(vr, vg, vb, 1)
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	self.glyph:SetTexture(ART .. (kind == "failed" and "Cross" or "Check"))
	self.glyphOn = kind ~= "sent"
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		self.verdict = kit.sub:GetText()
		self:Fitted(kit.sub)
	end
end

function Forge:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A second, darker plate hung under the first (or over it), its far edge
-- strapped; each row wears a bead in its reason's colour.
function Forge:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.beads do
		if not (list and i <= shown) then self.beads[i]:Hide() end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			Each(self.listPlate, "Hide")
			Each(self.listStrap, "Hide")
			self:PlaceShadow(nil)
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.beads[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.beads[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch = self.pitch
	local depth = shown * pitch + 6
	local W, H = self.W, self.H
	local y0, y1
	if above then
		y1 = 0
		y0 = -depth
	else
		y0 = H
		y1 = H + depth
	end
	PlacePlate(self.listPlate, art, 0, y0, W, y1)
	local strapH = self.strapH
	PlaceStrap(self.listStrap, art, 2, above and y0 or (y1 - strapH), W - 2, strapH)
	Each(self.listPlate, "Show")
	Each(self.listStrap, "Show")
	self:PlaceShadow({ 0, y0, W, y1 })

	local bead = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = -(3 + (shown - i) * pitch + pitch / 2)
		else
			y = H + 3 + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		At(self.beads[i], art, self.rowX - 9, y, bead)
	end
end
