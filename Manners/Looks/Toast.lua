-- Manners -- the Toast look: a warm banner pinned by a round gilded medallion,
-- in the grammar of the game's own achievement toasts, drawn with restraint.
--
-- A deep warm brown banner, framed by a thin rail of old gold with a darker
-- line inside it and a small stud in each corner. A round medallion pins its
-- left end: the spell icon, a thin ring of gold rope hugging it, a band of
-- enamel in the reason colour (darkened, as fired enamel is), and a fine gold
-- rim, so the enamel lies between two lines of gold, as cloisonne does. The
-- gold is planished (hammered, worn on its crests, grimed in its channels)
-- through tools/materials.py, the one lit-material pipeline. The name
-- is the title, the reason the subtitle. It is still at rest; it moves when
-- something happens, and briefly.
--
-- The rules it keeps since 1.5.2, after 1.5.1 wore in the game a glaring
-- yellow line all round, a square bevelled frame round the icon and a bright
-- blue glow ring (tests/scenarios/look-toast.lua and readable-toast.lua):
--   * no additive light at rest. tools/render_prompt.py draws ADD far more
--     gently than the client does, so light that stays on screen is baked
--     into the art or drawn with BLEND in colours given here, and the preview
--     shows what the game shows. Only a flourish -- the rails' glints for a
--     new favour, the ring of light as it arrives, the flare and the burst
--     of a landed buff -- is ADD, and each is gone within 0.6 s;
--   * the gold is old gold, never brighter than 0.62, thin and crisp;
--   * the medallion is round, made of flat discs drawn UNDER the icon, so
--     nothing lies over the icon at all and each ring is a set number of UI
--     units wide at any height (the gold ring 1.5 to 2.5);
--   * the text stands on dark: the body under the lines is a deep brown at
--     full strength, and nothing is drawn under the lines but the body.
--
-- Every region is a texture from Textures/Toast (tools/make_toast_textures.py).
-- The gold is baked, because it is decoration; everything that means something
-- -- the enamel, the list's gems, the favour clock, the outcome -- is white or
-- grey art coloured by SetVertexColor, so one file serves all six reasons,
-- both palettes, a custom marker colour and the outcomes. The interface this
-- file implements is described at the top of Looks/Looks.lua.
--
-- Kept from the approved design and the judges' word:
--   * the rails' glints only for a new favour, never for every new face; a
--     new face gets the text's own dip and nothing else;
--   * below height 40 a finer frame, so the gilding does not turn to mush;
--   * the text at its regular weight, the hierarchy carried by size, ink and
--     shadow;
--   * the result as a verdict on the second line -- "buffed" with a tick, or
--     the game's own words with a cross -- and the name left where it was;
--   * the favour clock: a thin line in the reason colour, lighter than the
--     enamel, over a line of ash along the bottom rail, burning down as the
--     time to return the favour runs out. Brought up to date on the scan's
--     own repaint, never on a frame script; kept under Calm, because it is
--     information, and in a fight, dimmed;
--   * the bound key on a chip at the right, the count's chip beside it (never
--     on the medallion, where it covered the icon). Either chip steps aside
--     for a paint in which the name would otherwise be cut;
--   * the owed enamel breathes three times and then settles;
--   * a fight turns the gold to iron and greys the icon, the text dims, and
--     the enamel keeps its colour: the one coloured thing left is the reason;
--   * the medallion is the panel's height and stays inside the button, so the
--     whole look takes clicks and the drag and the screen clamp see what the
--     player sees; the icon is sized by the height (Options says so);
--   * the owed gold fired to a honey amber, so it never reads as more metal;
--   * with the icon off, a jewel at the banner's end carries the reason;
--   * the icon is round whatever "Round the icon off" says, as "stripe" is
--     "both" here: a squared icon in a round medallion sat in a dark hole,
--     the ring round only its corners, and read as a square dropped into a
--     porthole. Round, it fills the ring, which hugs it;
--   * a class-coloured name is taken a third of the way to white.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Toast\\Toast_"

local Toast = ns.Looks.Register("toast", {
	name = L["Toast -- warm banner, gilded medallion"],
	title = L["Toast"],
	description = L["warm banner, gilded medallion"],
	order = 2,
	-- The banner holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.35,
})

-- The discs are drawn to this fraction of their file's half-size
-- (DISC_FILL in the generator), and the icon's mask to this.
local DISC_FILL, MASK_FILL = 0.98, 0.985
-- The gold ring hugging the icon is Toast_Rope: a gold disc whose outer band,
-- this fraction of its radius, is a twist of rope (ROPE_BAND in the
-- generator, which must agree). The ring exposes less of its disc than this
-- at every height (clamp(0.045 H, 1.5, 2.5) units of a radius that grows
-- with H), so what shows is always rope and never plain gold; the medallion's
-- rim, the same gold without the rope, keeps Toast_Gold.
local ROPE_BAND = 0.125
-- The medallion's shade: where its edge sits in its file (MED_SHADE_FILL in
-- the generator, which must agree) and how dark it is.
local SHADE_FILL, SHADE_ALPHA = 0.70, 0.55
-- Where the rails run, in units in from the frame's edge for a 12-unit
-- corner, scaled with the corner: the middle of the rail, for the glints, and
-- the favour clock's line, on the dark of the banner just inside the inner
-- line (on the gold itself the owed colour, which is nearly every clock,
-- vanished). FRAMES in the generator, which must agree.
local RAIL = { rail = 1.08, clock = 4.3, slimRail = 0.93, slimClock = 3.4 }
-- The banner's own warm pair, for a panel colour nobody chose: a deep warm
-- brown, opaque, so no world shows through under the text. Dark enough for
-- the dimmest reason line at 4.5:1 (tests/scenarios/readable-toast.lua); the
-- body's file adds its own quiet fall from the top down.
local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.118, 0.072, 0.046 }, { 0.090, 0.055, 0.036 }, 1
local IVORY = { 1.00, 0.965, 0.90 }
local WARM_GREY = { 0.80, 0.75, 0.66 }
local PALE_GOLD = { 1.00, 0.86, 0.52 }
local IRON = { 0.62, 0.62, 0.64 }
-- The medallion's outer rim: the ring's gold, a shade darker, so the enamel
-- lies between two fine lines of gold.
local RIM = { 0.92, 0.92, 0.92 }
-- The dark of the medallion's edge and of the well under the icon.
local WELL = { 0.030, 0.020, 0.014 }
-- The cursor's light on the gold ring: a paler gold laid over it (BLEND).
local HOVER = { 0.80, 0.68, 0.44, 0.42 }
-- The enamel is the reason colour fired and then darkened this much: a dark
-- band, never a glow.
local ENAMEL_DARK = 0.48
-- The enamel with the marker switched off.
local NEUTRAL = { 0.46, 0.40, 0.35 }
-- The outcomes' own colours: the enamel and the verdict.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims.
local TEXT_COMBAT, ICON_COMBAT = 0.78, 0.70
-- The owed pulse: the enamel lit to this and back, this many breaths of
-- 3.2 s, then it settles to the dark enamel.
local PULSE_PEAK = 0.55
-- The warm tone on the gold ring over the same breath: how much of the pale
-- gold it takes at the top of it.
local PULSE_WARM = 0.34
local BREATHS = 3
local BREATH = 1.3
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function Gap(fontSize) return math.max(1.5, fontSize * 0.16) end

-- The medallion for a panel `H` high, in UI units: its radius and the radius
-- each disc is drawn to, from the outside in -- the dark edge, the rim, the
-- enamel, the gold ring, the well -- and the icon's size, round. Each ring is
-- a set width in units, growing a little with the panel and then holding, so
-- the gold is thin at every height.
local function Medallion(H)
	local R = H / 2
	local rim = R - Clamp(H * 0.014, 0.5, 1.0)
	local enamel = rim - Clamp(H * 0.030, 1.0, 1.5)
	local ring = enamel - Clamp(H * 0.068, 2.3, 4.0)
	local well = ring - Clamp(H * 0.045, 1.5, 2.5)
	local seam = ring + Clamp(H * 0.012, 0.45, 0.8)
	local iconR = well - Clamp(H * 0.012, 0.45, 0.8)
	local icon = 2 * iconR / MASK_FILL
	return R, rim, enamel, ring, well, icon, seam
end

-- The name, the gap and the reason as one block, and the frame round it.
function Toast.TwoLineHeight(fontSize)
	return math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 10)
end

-- The enamel carries the reason, and with the icon off the jewel at the
-- banner's end does; nothing does with the marker off.
function Toast.AccentCarriers(p)
	return (p.accentMode or "icon") ~= "off", false
end

-- The medallion is the panel's height, so the icon is sized by the height and
-- not by the slider. Options says so with this.
function Toast.IconSize(p)
	local _, _, _, _, _, icon = Medallion(p.height or 44)
	return math.floor(icon + 0.5)
end

-- More colourful than the palette's own: enamel is glass fired on metal, and
-- the owed gold has to part company with the gold round it.
local function Enamel(r, g, b)
	local l = 0.299 * r + 0.587 * g + 0.114 * b
	local k = 1.35
	return Clamp(l + (r - l) * k, 0, 1), Clamp(l + (g - l) * k, 0, 1), Clamp(l + (b - l) * k, 0, 1)
end

-- The enamel for a reason colour. A warm gold (the owed reason) is fired
-- deeper, to a honey amber, so it never reads as one more ring of gold. The
-- colour-blind set's orange and lemon are not warm golds and pass unchanged.
local function Fired(r, g, b)
	local er, eg, eb = Enamel(r, g, b)
	if er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then
		eg = eg * 0.70
		er, eg, eb = er * 0.75, eg * 0.75, eb * 0.75
	end
	return er, eg, eb
end

-- The band round the ring: the fired colour darkened.
local function Dark(r, g, b)
	return r * ENAMEL_DARK, g * ENAMEL_DARK, b * ENAMEL_DARK
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

-- Whether this client reads an English string in its own language; the
-- verdict words are new, and a German player is better served by the lines
-- that are translated than by English in a German panel.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A frame cut from one file: corners from the outer quarters, edges from a
-- thin middle strip, so they stretch without warping. TL T TR L R BL B BR,
-- and a centre when asked for.
local CUT = {
	{ 0, 0.25, 0, 0.25 }, { 0.46, 0.54, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.46, 0.54 }, { 0.75, 1, 0.46, 0.54 },
	{ 0, 0.25, 0.75, 1 }, { 0.46, 0.54, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
	{ 0.46, 0.54, 0.46, 0.54 },
}

local function Pieces(parent, layer, sublevel, file, blend, centre, keep)
	local s = {}
	for i = 1, centre and 9 or 8 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(CUT[i][1], CUT[i][2], CUT[i][3], CUT[i][4])
		if blend then t:SetBlendMode(blend) end
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

-- The pieces round a box, corners `c` square. `open`: the left column is
-- left out and the top and bottom edges run to the box's left side, which is
-- under the medallion.
local function PlacePieces(s, rel, x0, y0, x1, y1, c, open)
	local lx = open and x0 or x0 + c
	Box(s[1], rel, x0, y0, x0 + c, y0 + c)
	Box(s[2], rel, lx, y0, x1 - c, y0 + c)
	Box(s[3], rel, x1 - c, y0, x1, y0 + c)
	Box(s[4], rel, x0, y0 + c, x0 + c, y1 - c)
	Box(s[5], rel, x1 - c, y0 + c, x1, y1 - c)
	Box(s[6], rel, x0, y1 - c, x0 + c, y1)
	Box(s[7], rel, lx, y1 - c, x1 - c, y1)
	Box(s[8], rel, x1 - c, y1 - c, x1, y1)
	if s[9] then Box(s[9], rel, x0 + c, y0 + c, x1 - c, y1 - c) end
end

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
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

-- A disc of radius `r` round the medallion's centre.
local function Disc(t, rel, cx, cy, r)
	local d = math.max(0.5, 2 * r / DISC_FILL)
	t:ClearAllPoints()
	t:SetPoint("CENTER", rel, "TOPLEFT", cx, -cy)
	t:SetSize(d, d)
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

-- A glint down a rail: in, along, out, all within FLOURISH of its start.
local function Travel(region, delay)
	local g = region:CreateAnimationGroup()
	local move = g:CreateAnimation("Translation")
	move:SetDuration(FLOURISH - 0.1 - delay)
	if move.SetStartDelay then move:SetStartDelay(delay) end
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	Alpha(g, 0, 1, 0.1, 1, delay)
	Alpha(g, 1, 0, 0.2, 1, FLOURISH - 0.3)
	g.move = move
	Park(g, region, 0)
	return g
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Toast:Build(kit)
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
	-- A flourish's light: additive, parked at nothing.
	local function light(file, sublevel, parent)
		local t = tex(parent or art, "BORDER", sublevel, file, "ADD")
		t:SetAlpha(0)
		return t
	end

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", nil, true, keep)
	self.drawerBody = tex(art, "BACKGROUND", -7, "Body")
	self.body = tex(art, "BACKGROUND", -6, "Body")
	self.drawer = Pieces(art, "BORDER", -2, ART .. "Drawer", nil, false, keep)
	self.border = Pieces(art, "BORDER", 2, ART .. "Border", nil, false, keep)

	-- The flourishes: a ring of light round the medallion as a favour
	-- arrives and as a buff lands, under the medallion's discs so it shows
	-- only outside them; the gilding's flare; a glint down each rail.
	self.ringArrive = light("RingGlow", 3)
	-- The rings that spread from the medallion when a buff lands, and the
	-- one that snaps in when one is refused: the same ring of light, in
	-- frames over the art (and under the text), parked at nothing. No echo
	-- of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do keep(f) end
	-- Where the ring file is brightest and how far out it is seen, for how far
	-- the rings may spread (measured from the file: hunt37-effects).
	kit.RingArt(ART .. "RingGlow", 0.68, 0.78)
	-- The shade the medallion throws on the banner, over the rails and under
	-- the discs: what makes it stand off the banner.
	self.shade = tex(art, "BORDER", 4, "MedShade")
	self.flare = Pieces(art, "BORDER", 5, ART .. "BorderGlow", "ADD", false, keep)
	Each(self.flare, "SetAlpha", 0)
	self.glints = {}
	for i = 1, 2 do self.glints[i] = light("Glint", 6) end

	-- The medallion: flat discs on art, under the icon (ARTWORK 0), so they
	-- are drawn after the rails and nothing of them lies over the icon. From
	-- the outside in: the dark edge, the rim, the enamel and its owed glow,
	-- a dark seam that sets the enamel apart from the gold, the gold ring
	-- and the cursor's light on it, and the well.
	self.medallion = tex(art, "ARTWORK", -8, "Disc")
	self.rim = tex(art, "ARTWORK", -7, "Gold")
	self.band = tex(art, "ARTWORK", -6, "Enamel")
	self.glow = tex(art, "ARTWORK", -5, "Disc")
	self.seam = tex(art, "ARTWORK", -4, "Disc")
	self.ring = tex(art, "ARTWORK", -3, "Rope")
	self.ringHover = tex(art, "ARTWORK", -2, "Disc")
	-- The second tone of the owed breath: the gold ring warmed towards pale
	-- gold, in BLEND like the enamel's own light.
	self.ringWarm = tex(art, "ARTWORK", -2, "Disc")
	-- The well: opaque, in the icon's place, so whenever the icon or the
	-- panel is less than opaque (a fight, the panel fading in and out)
	-- nothing behind it shows; and the dark hairline between icon and gold.
	self.well = tex(art, "ARTWORK", -1, "Disc")
	self.glow:SetAlpha(0)
	self.ringHover:SetAlpha(0)
	self.ringWarm:SetAlpha(0)

	-- The favour clock, on the bottom rail: the time spent as a line of dark
	-- ash its whole length, the time left over it, and a bead at its end.
	-- Over the rails and under the medallion, so its end tucks under the
	-- medallion's edge and never reaches the icon.
	self.ash = tex(art, "BORDER", 6, "Ember")
	self.ash:SetTexCoord(0.25, 0.75, 0, 1)
	self.ember = tex(art, "BORDER", 7, "Ember")
	self.ember:SetTexCoord(0.25, 0.75, 0, 1)
	self.bead = tex(art, "BORDER", 7, "Disc")

	-- The list's gems, and with the icon off one at the banner's end, which
	-- carries the reason in the medallion's place.
	self.gems, self.gemSets = {}, {}
	for i = 1, #kit.rows do
		self.gems[i] = tex(art, "ARTWORK", 1, "Gem")
		self.gemSets[i] = tex(art, "ARTWORK", 2, "GemSet")
	end
	self.jewel = tex(art, "ARTWORK", 1, "Gem")
	self.jewelSet = tex(art, "ARTWORK", 2, "GemSet")

	-- The chips: over the banner, at its right end; their text is on
	-- textLayer, over them.
	local base = art:GetFrameLevel()
	self.chipFrame = keep(CreateFrame("Frame", nil, art))
	self.chipFrame:SetFrameLevel(base + 3)
	for _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Chip", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Chip", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The verdict's tick or cross, before the second line.
	self.glyph = tex(textLayer, "ARTWORK", 1, "Check")

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything gold, for the iron of a fight, and the tint each wears out
	-- of one.
	self.gold = { self.ring, self.rim, self.jewelSet }
	for _, s in ipairs({ self.border, self.drawer, self.chip, self.keyChip, self.gemSets }) do
		for _, t in ipairs(s) do self.gold[#self.gold + 1] = t end
	end
	self.goldTint = { [self.rim] = RIM }

	self:BuildAnimations(anim)
end

function Toast:BuildAnimations(anim)
	-- The owed pulse: the enamel lit and let go, slowly (BLEND, the fired
	-- colour over the dark); see Attention for how long.
	local pulse = self.glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	Alpha(pulse, 0, PULSE_PEAK, BREATH, 1, nil, "IN_OUT")
	-- ...and, on the same breath, the gold ring warmed.
	local warm = self.ringWarm:CreateAnimationGroup()
	warm:SetLooping("BOUNCE")
	Alpha(warm, 0, 1, BREATH, 1, nil, "IN_OUT")
	self.pulse = { anim(pulse), anim(warm) }

	self.arrive = { anim(Flash(self.ringArrive, 1, 0.15, 0.40, nil, "IN")) }
	-- The arrival's ring converges on the medallion as it fades in: from wider
	-- to home in the 0.15 s it takes to light, so the group stays the 0.55 s
	-- the light may.
	local gather = self.arrive[1]:CreateAnimation("Scale")
	self.gather = gather
	if gather.SetScaleFrom then gather:SetScaleFrom(1.30, 1.30) end
	if gather.SetScaleTo then gather:SetScaleTo(1, 1) end
	if gather.SetOrigin then gather:SetOrigin("CENTER", 0, 0) end
	gather:SetDuration(0.15)
	gather:SetOrder(1)
	if gather.SetSmoothing then gather:SetSmoothing("OUT") end

	self.sweep = {}
	for i, t in ipairs(self.glints) do
		self.sweep[i] = anim(Travel(t, i == 1 and 0.05 or 0.12))
	end

	self.flareAnims = {}
	for i, t in ipairs(self.flare) do self.flareAnims[i] = anim(Flash(t, 0.5, 0.08, 0.42)) end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The cursor's light on the gold, both ways; from and to are set for
	-- each play.
	local hover = self.ringHover:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.ringHover, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Toast:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua).
	self.pitch = sub + 6

	-- The banner sits a few units inside the panel's height, so the medallion
	-- that overhangs it is still inside the button: the whole look takes the
	-- click and the drag.
	local ov = Clamp(math.floor(H * 0.065 + 0.5), 2, 4)
	local top, bottom = ov, H - ov
	local BH = bottom - top
	local slim = H < 40
	local C = Clamp(math.floor(BH * 0.30 + 0.5), 8, 16)
	-- The medallion is the panel's height: the banner's rails and body run in
	-- under it to its centre, so a medallion any shorter than the banner left
	-- their ends showing above and below it.
	-- A panel narrower than it is tall holds the medallion to half its width, or
	-- the name is left a sliver beside it.
	local M = showIcon and math.min(H, math.max(24, math.floor(W * 0.5))) or 0
	local cx, cy = M / 2, H / 2
	local left = showIcon and cx or 0
	-- With the icon off, a jewel at the banner's end carries the reason.
	local jewel = sub + 8
	-- Clear of the frame's inner line.
	local jewelX = C / 2 + 7
	local textX = showIcon and (M + 6) or math.floor(jewelX + jewel / 2 + 7 + 0.5)
	self.ov, self.top, self.bottom, self.C, self.M, self.cx, self.cy = ov, top, bottom, C, M, cx, cy
	self.left, self.textX, self.slim = left, textX, slim

	-- The panel colour: the look's own warm pair unless one was chosen.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local tr, tg, tb, ta, br, bg, bb
	if Untouched(c, d) then
		tr, tg, tb, ta = WARM_TOP[1], WARM_TOP[2], WARM_TOP[3], WARM_ALPHA
		br, bg, bb = WARM_BOTTOM[1], WARM_BOTTOM[2], WARM_BOTTOM[3]
	else
		tr, tg, tb, ta = c[1] or 0, c[2] or 0, c[3] or 0, c[4] == nil and 1 or c[4]
		br, bg, bb = tr * 0.62, tg * 0.62, tb * 0.66
	end
	self.bodyTop, self.bodyBottom = { tr, tg, tb, ta }, { br, bg, bb, ta }
	self.shadowAlpha = math.min(1, ta + 0.05) * (ta < 0.2 and 0 or 1)
	kit.Gradient(self.body, "VERTICAL", br, bg, bb, ta, tr, tg, tb, ta)
	Box(self.body, art, left + 0.6, top + 0.6, W - 0.6, bottom - 0.6)
	kit.Gradient(self.drawerBody, "VERTICAL", br * 0.9, bg * 0.9, bb * 0.9, ta * 0.97,
		tr * 0.8, tg * 0.8, tb * 0.8, ta * 0.97)

	local frameFile = ART .. (slim and "BorderSlim" or "Border")
	Each(self.border, "SetTexture", frameFile)
	Each(self.flare, "SetTexture", frameFile .. "Glow")
	PlacePieces(self.border, art, left, top, W, bottom, C, showIcon)
	PlacePieces(self.flare, art, left, top, W, bottom, C, showIcon)
	self.shadowBox = { left - 12 + 4, top - 9, W + 12, bottom + 15 }
	Each(self.shadow, "SetVertexColor", 1, 1, 1, self.shadowAlpha)
	self.drawnList = nil
	self:PlaceShadow(nil)

	local k = C / 12
	local railAt = (slim and RAIL.slimRail or RAIL.rail) * k
	local clockAt = (slim and RAIL.slimClock or RAIL.clock) * k

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	-- Round at either setting of "Round the icon off" (see the top).
	local maskFile = ART .. "IconMask"
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	local R, rRim, rEnamel, rRing, rWell, iconSize, rSeam = Medallion(math.max(1, M))
	self.R, self.iconSize = R, iconSize
	Disc(self.medallion, art, cx, cy, R)
	Disc(self.rim, art, cx, cy, rRim)
	Disc(self.band, art, cx, cy, rEnamel)
	Disc(self.glow, art, cx, cy, rEnamel)
	Disc(self.seam, art, cx, cy, rSeam)
	Disc(self.ring, art, cx, cy, rRing)
	Disc(self.ringHover, art, cx, cy, rRing)
	Disc(self.well, art, cx, cy, rWell)
	self.medallion:SetVertexColor(WELL[1], WELL[2], WELL[3], 1)
	self.well:SetVertexColor(WELL[1], WELL[2], WELL[3], 1)
	self.seam:SetVertexColor(WELL[1], WELL[2], WELL[3], 1)
	self.ringHover:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
	Disc(self.ringWarm, art, cx, cy, rRing)
	self.ringWarm:SetVertexColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], PULSE_WARM)
	self.shade:ClearAllPoints()
	self.shade:SetPoint("CENTER", art, "TOPLEFT", cx + 0.04 * M, -(cy + 0.07 * M))
	self.shade:SetSize(M / SHADE_FILL, M / SHADE_FILL)
	self.shade:SetVertexColor(0, 0, 0, SHADE_ALPHA)
	self.ringArrive:ClearAllPoints()
	self.ringArrive:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self.ringArrive:SetSize(1.45 * M, 1.45 * M)
	if showIcon then
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		-- The rings spread from the medallion's ring of light, in its art.
		self.fx:Place(icon, (1.45 * M - iconSize) / 2, iconSize)
		self.fx:Shape(true, ART .. "RingGlow", ART .. "RingGlow")
		-- The room the rings have: to the text (less a margin), to the
		-- medallion's own left edge and to the panel's top and bottom, which
		-- the medallion fills. The ring that gathers on it is held to the same.
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		kit.CapLock(self.gather, nil, 1.30, 1, kit.CapScale(math.min(limitH, limitV), 0.725 * M, 0.78))
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep has the icon's shape.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end

	local from = showIcon and M - 4 or C / 2
	local run = math.max(10, W - C - from)
	local gw, gh = 1.2 * BH, 0.22 * BH
	for i, t in ipairs(self.glints) do
		local y = (i == 1) and (top + railAt) or (bottom - railAt)
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", from, -y)
		t:SetSize(gw, gh)
		t:SetVertexColor(1, 0.90, 0.66, 0.8)
		self.sweep[i].move:SetOffset(run, 0)
	end
	Each(self.flare, "SetVertexColor", 1, 0.85, 0.55, 1)

	self.clockY = -(bottom - clockAt)
	local dy = (bottom - clockAt) - cy
	self.clockX = showIcon and (cx + math.sqrt(math.max(0, R * R - dy * dy)) + 1) or C
	self.clockLen = math.max(10, W - C * 0.8 - self.clockX)
	self.clockH = math.max(1.0, 0.09 * C)
	self.ember:ClearAllPoints()
	self.ember:SetPoint("LEFT", art, "TOPLEFT", self.clockX, self.clockY)
	self.ember:SetHeight(self.clockH * 16 / 11.5)
	self.ash:ClearAllPoints()
	self.ash:SetPoint("LEFT", art, "TOPLEFT", self.clockX, self.clockY)
	self.ash:SetSize(self.clockLen, self.clockH * 16 / 11.5)
	self.ash:SetVertexColor(0.30, 0.13, 0.06, 0.60)
	-- The burning end: a bead big enough to see at the game's own scale (and
	-- no bigger: it is the line's own colour, not a pearl), placed by Clock,
	-- and never back over the medallion.
	local beadD = self.clockH * 2.0
	self.bead:SetSize(beadD, beadD)
	self.beadMin = self.clockX + beadD / 2
	self.clockW = nil

	for _, t in ipairs({ self.jewel, self.jewelSet }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", jewelX, -cy)
		t:SetSize(jewel, jewel)
	end

	local gap = Gap(fs)
	local block = fs + gap + sub
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
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -9, 0)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	self.rowX = showIcon and textX or C + 14
	local rowWidth = math.max(20, W - self.rowX - 12)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip, the clock for its debt.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.medallion, self.rim, self.band, self.glow, self.seam, self.ring, self.ringHover,
		self.ringWarm, self.well, self.ringArrive, self.shade }) do
		t:SetShown(showIcon)
	end
	self.fx:SetShown(showIcon)
	for i = 1, 8 do
		local side = i == 1 or i == 4 or i == 6
		self.border[i]:SetShown(not (showIcon and side))
		self.flare[i]:SetShown(not (showIcon and side))
	end
	Each(self.drawer, "Hide")
	self.drawerBody:Hide()
	for i = 1, #self.gems do
		self.gems[i]:Hide()
		self.gemSets[i]:Hide()
	end
	self.glyph:Hide()
	self.ash:Hide()
	self.ember:Hide()
	self.bead:Hide()
	self.jewel:SetShown(not showIcon)
	self.jewelSet:SetShown(not showIcon)
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	self:Iron(false)
	if held then self:Combat(true) end

	-- The count's room: a two-digit chip and its inset. Chip widens it for a
	-- longer count.
	self.roomBase = math.ceil(chipH * 1.75) + 15
	return textX, self.roomBase
end

function Toast:PlaceShadow(drawer)
	local b = self.shadowBox
	local y0, y1 = b[2], b[4]
	if drawer then
		y0 = math.min(y0, drawer[2] - 9)
		y1 = math.max(y1, drawer[4] + 15)
	end
	PlacePieces(self.shadow, self.kit.art, b[1], y0, b[3], y1, 16)
end

function Toast:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen and ink.light then
		kit.name:SetTextColor(IVORY[1], IVORY[2], IVORY[3], 1)
	end
	if ink.light then
		kit.name:SetShadowColor(0, 0, 0, 0.9)
		kit.name:SetShadowOffset(1, -1)
	end
	-- The chips are dark enamel whatever the panel, so their text is pale gold
	-- as it is.
	kit.count:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	self.keyText:SetShadowOffset(0, 0)
	if ink.light then
		local r, g, b = kit.Legible(0.93, 0.90, 0.83, 4.5)
		for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
		ink.rowReason = "|cffa19685"
	end
end

function Toast:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	self.ringWarm:SetAlpha(0)
	-- The cursor's light parks where its fade was headed (and a finished fade
	-- is not stopped at all), and the cursor leaves for the next look: put it
	-- out after the Stop, or it is lit when this look comes back.
	self.ringHover:SetAlpha(0)
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
	-- The fight's dimming of the clock goes with the hold, which Combat(false)
	-- will not be here to lift.
	self.ember:SetAlpha(1)
	self.bead:SetAlpha(1)
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Toast:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	local inset = math.max(right, 12)
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
function Toast:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Toast:Fitted(fs)
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
		fs:SetPoint("RIGHT", -(self.inset or 12), self.subY)
	end
	self.glyph:SetShown((glyph and fs:IsShown()) and true or false)
end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Toast:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, 12) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only
-- where a press casts something, as on Arcane: the button armed (a fight's
-- frozen macro too, unlocked or not), never over a held panel with nothing
-- armed, nor over an outcome.
function Toast:KeyLabel()
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

-- The room the lines leave at the right for the key's chip with the count's
-- beside it: the key's room, a two-digit chip and the gap between them.
function Toast:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - 5
end

-- Run on every repaint, which is also the clock's tick. The count's chip at
-- the right, or, with the key's chip there, a chip beside the key's; the
-- key's chip when a key is bound.
-- Either steps aside for a paint in which the name would otherwise be cut.
function Toast:Chip(on)
	local kit = self.kit
	self:Clock()
	-- The width FitLine took of the name just now (every paint sets it before
	-- the chip), measured here only where it could not; the chips' own words
	-- only when they change. Measured outright, it was a pcall on every
	-- repaint (Looks.lua: none on a per-scan path).
	self.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(w + 15)
			-- A key bound anew is a chip of a new width: Prompt places the
			-- lines again, beside it.
			kit.fit.right = nil
		end
		keyUp = self:NameFits(self.keyRoom)
	end
	if keyUp ~= self.keyUp then
		self.keyUp = keyUp
		-- Prompt places the lines again, and PlaceLines keeps the key's room.
		kit.fit.right = nil
	end
	if keyUp then self.keyBox:SetWidth(math.floor(self.keyW + 0.5)) end
	for _, t in ipairs(self.keyChip) do t:SetShown(keyUp) end
	self.keyText:SetShown(keyUp)

	-- The count's chip as wide as its words need, and the room the lines keep
	-- for it as wide too (never less than two digits'), so the name does not
	-- run under a count of three digits. Measured when its words change.
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
			-- The count's chip beside the key's, never on the medallion: a
			-- coin there covered the spell icon.
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
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -9, 0)
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
	-- Only a chip at the right takes room from the lines; PlaceLines gives a
	-- pair the room of both.
	return mode == "chip" or mode == "pair"
end

-- The favour clock: how much of the time to return the favour is left, as a
-- line along the bottom rail that burns down towards the medallion. A
-- preview shows it part-burnt, so it can be seen while styling.
function Toast:Clock()
	local frac
	local P = ns.Prompt
	if P and P.InTest and P:InTest() then
		frac = 0.62
	else
		local name = P and P.PanelName and P:PanelName()
		local debt = name and ns.owed and ns.owed[name]
		if type(debt) == "table" and type(debt.at) == "number" and ns.DebtExpiry then
			local ends, now = ns.DebtExpiry(debt), GetTime()
			if type(ends) == "number" and ends > now and ends > debt.at then
				frac = math.min(1, (ends - now) / (ends - debt.at))
			end
		end
	end
	if not frac then
		if self.clockW then
			self.clockW = nil
			self.ash:Hide()
			self.ember:Hide()
			self.bead:Hide()
		end
		return
	end
	local width = math.max(1, frac * self.clockLen)
	if not self.clockW or math.abs(width - self.clockW) >= 0.25 then
		self.clockW = width
		self.ember:SetWidth(width)
		self.bead:ClearAllPoints()
		self.bead:SetPoint("CENTER", self.kit.art, "TOPLEFT",
			math.max(self.clockX + width, self.beadMin), self.clockY)
	end
	self.ash:Show()
	self.ember:Show()
	self.bead:Show()
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The enamel and the clock in one colour; the reason line warmed towards
-- it. An outcome leaves the clock alone: it is about the favour, not the
-- click.
function Toast:Tint(r, g, b, outcome)
	local kit = self.kit
	local er, eg, eb = Fired(r, g, b)
	local dr, dg, db = Dark(er, eg, eb)
	self.band:SetVertexColor(dr, dg, db, 1)
	self.glow:SetVertexColor(er, eg, eb, 1)
	-- The jewel halfway between the enamel and the fired colour: it carries
	-- the reason, with the enamel's restraint.
	self.jewel:SetVertexColor((er + dr) / 2, (eg + dg) / 2, (eb + db) / 2, 1)
	self.ringArrive:SetVertexColor(r, g, b, 0.55)
	if not outcome then
		-- The time left in the fired colour, lighter than the dark enamel,
		-- so it is a live line over its ash; quiet, never a second rail, and
		-- its bead in the same colour, never brighter than the gold.
		self.ember:SetVertexColor(er, eg, eb, 0.55)
		self.bead:SetVertexColor(er, eg, eb, 0.85)
	end
	-- The subtitle: warm grey taken most of the way to the reason, held to its
	-- contrast; on a light panel the plain grey, which the tint would cost.
	local sr, sg, sb
	if not kit.ink.light then
		local s = kit.ink.sub or WARM_GREY
		sr, sg, sb = s[1], s[2], s[3]
	else
		sr = WARM_GREY[1] + (r - WARM_GREY[1]) * 0.6
		sg = WARM_GREY[2] + (g - WARM_GREY[2]) * 0.6
		sb = WARM_GREY[3] + (b - WARM_GREY[3]) * 0.6
	end
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { r, g, b }
end

function Toast:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then
		-- Neutral enamel, and the clock a warm white.
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		self.ember:SetVertexColor(0.86, 0.76, 0.58, 0.9)
	else
		-- "stripe" is "both" here: the toast has no stripe, and the enamel is
		-- where its reason is.
		self:Tint(r, g, b)
	end
	-- A refusal greyed the icon; a fight keeps it grey.
	self.refused = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Toast:Iron(on)
	for _, t in ipairs(self.gold) do
		t:SetDesaturated(on)
		local tint = self.goldTint[t]
		if on then
			local k = tint and tint[1] or 1
			t:SetVertexColor(IRON[1] * k, IRON[2] * k, IRON[3] * k, 1)
		elseif tint then
			t:SetVertexColor(tint[1], tint[2], tint[3], 1)
		else
			t:SetVertexColor(1, 1, 1, 1)
		end
	end
end

-- The banner holds; the gold goes to iron, the icon greys, the text dims and
-- the lights go out. The enamel keeps its colour, and the clock burns on,
-- dimmed: the reason is the one coloured thing left.
function Toast:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Iron(on)
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon showed the
	-- world through one half and the banner through the other.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	self.ember:SetAlpha(on and 0.7 or 1)
	self.bead:SetAlpha(on and 0.7 or 1)
	if on then
		self:StopAttention()
		for _, g in ipairs(self.arrive) do g:Stop() end
		self:StopFlourishes()
	end
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

function Toast:Sweep()
	PlayAll(self.sweep)
end

-- The breathing, let go: after its breaths, and on Calm. The enamel settles
-- to its dark.
function Toast:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glow:SetAlpha(0)
	self.ringWarm:SetAlpha(0)
end

function Toast:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent = nil
		-- Glints down the rails for a new favour, never for a new face.
		if full then self:Sweep() end
	end
	-- The favour just done, or a new favour on "once": the ring of light.
	if full and (arrived or (isNew and flashStyle == "once")) then PlayAll(self.arrive) end
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
		self.glow:SetAlpha(0)
		self.ringWarm:SetAlpha(0)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Toast.pulseGen or not Toast.active then return end
			Toast.pulseSpent = true
			if Toast.pulse[1]:IsPlaying() then Toast:HoldPulse() end
		end)
	end
end

function Toast:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glow:SetAlpha(0)
	self.ringWarm:SetAlpha(0)
end

function Toast:Flourish(kind)
	-- A refusal contracts: the gilding flares in red and amber, and one ring
	-- snaps in onto the medallion. The text's shake is Prompt's.
	if kind == "failed" then
		Each(self.flare, "SetVertexColor", 1, 0.42, 0.20, 1)
		PlayAll(self.flareAnims)
		if self.kit.icon:IsShown() then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	Each(self.flare, "SetVertexColor", 1, 0.85, 0.55, 1)
	PlayAll(self.flareAnims)
	if self.kit.icon:IsShown() then
		local o = OUTCOME.cast
		self.fx:Land(o[1], o[2], o[3], 0.70)
	end
end

function Toast:StopFlourishes()
	for _, g in ipairs(self.flareAnims) do g:Stop() end
	self.fx:Stop()
	for _, g in ipairs(self.sweep) do g:Stop() end
end

function Toast:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.ringHover
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 1 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the subtitle becomes the verdict, so the
-- eye never has to find the person again. The enamel takes the outcome's
-- colour.
function Toast:PaintOutcome(kind, lead, sub, who, stamp)
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
	-- The owed breathing is about the favour, not the click: it stops, and
	-- the enamel is the outcome's dark band. Attention starts it again for
	-- the next person owed.
	self:HoldPulse()
	self:Tint(o[1], o[2], o[3], true)
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)
	kit.sub:SetTextColor(vr, vg, vb, 1)
	self.glyph:SetVertexColor(vr, vg, vb, 1)
	self.refused = kind == "failed"
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	self.glyph:SetTexture(ART .. (kind == "failed" and "Cross" or "Check"))
	self.glyphOn = kind ~= "sent"
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		self.verdict = kit.sub:GetText()
		self:Fitted(kit.sub)
	end
end

function Toast:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The drawer slides out from under the banner's rail, above or below; each
-- row wears a gem in its reason's colour.
function Toast:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.gems do
		if not (list and i <= shown) then
			self.gems[i]:Hide()
			self.gemSets[i]:Hide()
		end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			Each(self.drawer, "Hide")
			self.drawerBody:Hide()
			self:PlaceShadow(nil)
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.gems[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.gems[i]:Show()
		self.gemSets[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch = self.pitch
	local depth = 3 + 4 + shown * pitch + 5
	local x0 = self.M > 0 and self.cx + 4 or 5.5
	local x1 = self.W - 5.5
	local y0, y1
	if above then
		y1 = self.top + 3
		y0 = y1 - depth
	else
		y0 = self.bottom - 3
		y1 = y0 + depth
	end
	PlacePieces(self.drawer, art, x0, y0, x1, y1, 8)
	for i = 1, 8 do
		local topRow = i <= 3
		local bottomRow = i >= 6
		self.drawer[i]:SetShown(not ((above and bottomRow) or (not above and topRow)))
	end
	Box(self.drawerBody, art, x0 + 0.5, y0 + 0.5, x1 - 0.5, y1 - 0.5)
	self.drawerBody:Show()
	self:PlaceShadow({ x0, y0, x1, y1 })

	local gem = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = self.top - 4 - (shown - i) * pitch - pitch / 2
		else
			y = self.bottom + 4 + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		for _, t in ipairs({ self.gems[i], self.gemSets[i] }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", art, "TOPLEFT", self.rowX - 9, -y)
			t:SetSize(gem, gem)
		end
	end
end
