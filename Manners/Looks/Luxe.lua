-- Manners -- the Luxe look.
--
-- A slim near-black card with a soft baked shadow and a one-unit bevel lit
-- from above. Down the left edge runs a spine in the reason colour with a
-- little bloom; the spell icon is a crisp rounded square set in a ring of the
-- same colour; the reason sits under the name as a tag, tinted to match. It is
-- still at rest and only moves when something happens.
--
-- Every region is a texture from Textures/Luxe (tools/make_luxe_textures.py),
-- white or black-and-white, so the vertex colour carries every reason, both
-- palettes, a custom marker colour and the outcomes. The interface this file
-- implements is described at the top of Looks/Looks.lua.
--
-- Where it departs from the approved design, on the judges' word:
--   * the spine is 4-5 units wide with the height (3 below 36) and its
--     resting bloom is twice as strong, so the reason reads before the name;
--   * a thin ring in the reason colour sits round the icon, where the eye
--     lands first, and it and the spine keep their full colour in a fight
--     while the rest of the ink dims -- the reason survives combat;
--   * the owed pulse breathes 0.18-0.36 every 2.4 s, only while somebody owed
--     is on top, and holds still on Calm;
--   * class-coloured names are taken 85% of the way to white (classSoften),
--     so a class colour is only a tint on white: at 55% a mage's cyan landed
--     on the target reason's, and a mage's own "You" read as target. The
--     spine and the tag stay the only saturated marks, as the design has it.
--     "Colour names by class" already turns them off entirely, so a second
--     switch would only say the same thing twice;
--   * a refusal greys the icon as well as reddening the tag, which reads
--     without colour vision;
--   * the count chip steps aside when the name would be cut even at its
--     smallest size, since the name is the one thing the panel must say;
--   * "Reason colour: both" lights the card's top edge in the reason colour
--     as well, so the setting shows here too;
--   * on a panel made nearly clear the name and the tag take an outline, and
--     the tag a dark ground of its own, as the minimal look's text does;
--   * a panel shorter than Luxe's own two lines but tall enough for the
--     built-in looks' draws the tag slimmer rather than dropping it.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Luxe\\Luxe_"

local Luxe = ns.Looks.Register("luxe", {
	name = L["Luxe -- slim dark card, a spine in the reason colour"],
	title = L["Luxe"],
	description = L["slim dark card, a spine in the reason colour"],
	order = 1,
	-- The ground and the ink dim apart, so art itself stays whole.
	combatArtAlpha = 1,
	classSoften = 0.85,
	-- The tag carries its own dark ground (PaintPill), whatever the panel.
	subOnDark = true,
})

-- Where the spine sits, and what a fight does to each part: the card holds,
-- the ink (the icon, its shade and rim, the light) recedes, the text a little.
local SPINE_X = 6
local GROUND_COMBAT, INK_COMBAT, TEXT_COMBAT = 0.92, 0.62, 0.80
-- The reason with the marker switched off.
local NEUTRAL = { 0.55, 0.56, 0.62 }
-- The outcomes' own colours: the tag, the spine, the ring and the wash.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.42, 0.36 },
	sent = { 0.91, 0.86, 0.60 },
}
-- The ring is drawn this far outside a 30-unit icon, scaled with the icon:
-- RING_PAD in tools/make_luxe_textures.py, which must agree.
local RING_PAD = 3
-- The tag's and the chip's fill: the colour taken down to a fifth, nearly
-- solid. A pale tint at 0.15 came out light in the game, and the reason's
-- words on it were white on white (1.5.0). In a fight the words dim with the
-- rest of the text, so the ground under them goes darker still.
local PILL_DARK, PILL_DARK_COMBAT, PILL_ALPHA = 0.2, 0.08, 0.9
-- The light the cursor and an outcome lay over the card (ADD). The game draws
-- added light brighter than it is written: the text above it keeps 4.5:1 with
-- these counted twice, over snow (tests/scenarios/readable-luxe.lua).
local HOVER_LIGHT, RESULT_LIGHT = 0.035, 0.07

-- The tag's sizes, full or `tight`: a slimmer tag and a one-unit gap, for a
-- panel with room for the built-in looks' two lines but not for these.
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function PillHeight(fontSize, tight)
	return math.floor((tight and 1.3 or 1.5) * SubSize(fontSize) + 0.5)
end
local function Gap(fontSize, tight)
	if tight then return 1 end
	return math.max(2, math.floor(0.2 * fontSize + 0.5))
end

-- The name, the gap and the tag as one block, with four units above and below;
-- tight, two.
local function BlockHeight(fontSize, tight)
	return math.ceil(1.2 * fontSize + Gap(fontSize, tight) + PillHeight(fontSize, tight) + (tight and 4 or 8))
end

-- Never more than the built-in looks ask: a profile that showed two lines on
-- glass keeps them here, with the tag drawn tight until the full one fits.
function Luxe.TwoLineHeight(fontSize)
	return math.max(ns.TwoLineHeight(fontSize, "glass"), BlockHeight(fontSize, true))
end

-- The spine is a light as well as a mark: it carries the reason on this look,
-- so a round icon keeps its ring and the spine is there whatever the marker.
function Luxe.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false, mode ~= "off"
end

---------------------------------------------------------------------------
-- slices
---------------------------------------------------------------------------

-- Nine textures cut from one file: corners `corner` units square, cut
-- `margin` texels into a `size`-texel file. Every client draws this; the
-- one-texture slice margins are newer than some of them.
local function NineSlice(parent, layer, sublevel, file, size, margin, corner, blend)
	local s = { corner = corner }
	local u = margin / size
	local cuts = { 0, u, 1 - u, 1 }
	for row = 1, 3 do
		for col = 1, 3 do
			local t = parent:CreateTexture(nil, layer, nil, sublevel)
			t:SetTexture(file)
			t:SetTexCoord(cuts[col], cuts[col + 1], cuts[row], cuts[row + 1])
			if blend then t:SetBlendMode(blend) end
			s[#s + 1] = t
		end
	end
	return s
end

-- Placed round a box, `out` units outside it on each side (left, top, right,
-- bottom). The top row hangs from `top`, the bottom row from `bottom`, which
-- are the same region unless the slice spans two (the shadow under the card
-- and its list); the two share their left and right edges.
local function PlaceSlice(s, top, bottom, l, t, r, b)
	local c = s.corner
	for _, tex in ipairs(s) do tex:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", top, "TOPLEFT", -l, t)
	s[1]:SetSize(c, c)
	s[2]:SetPoint("TOPLEFT", top, "TOPLEFT", -l + c, t)
	s[2]:SetPoint("TOPRIGHT", top, "TOPRIGHT", r - c, t)
	s[2]:SetHeight(c)
	s[3]:SetPoint("TOPRIGHT", top, "TOPRIGHT", r, t)
	s[3]:SetSize(c, c)
	s[4]:SetPoint("TOPLEFT", top, "TOPLEFT", -l, t - c)
	s[4]:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", -l, -b + c)
	s[4]:SetWidth(c)
	s[5]:SetPoint("TOPLEFT", top, "TOPLEFT", -l + c, t - c)
	s[5]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r - c, -b + c)
	s[6]:SetPoint("TOPRIGHT", top, "TOPRIGHT", r, t - c)
	s[6]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r, -b + c)
	s[6]:SetWidth(c)
	s[7]:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", -l, -b)
	s[7]:SetSize(c, c)
	s[8]:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", -l + c, -b)
	s[8]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r - c, -b)
	s[8]:SetHeight(c)
	s[9]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r, -b)
	s[9]:SetSize(c, c)
end

local function SliceColor(s, r, g, b, a)
	for _, tex in ipairs(s) do tex:SetVertexColor(r, g, b, a) end
end

local function SliceShown(s, on)
	for _, tex in ipairs(s) do tex:SetShown(on) end
end

-- One vertical gradient across a slice `height` units tall: each row gets its
-- own share, so the three rows make exactly one gradient. `top` and `bottom`
-- are { r, g, b, a }.
local function SliceGradient(s, height, top, bottom, gradient)
	local c = s.corner
	local function at(y)
		local t = math.max(0, math.min(1, y / math.max(1, height)))
		return top[1] + (bottom[1] - top[1]) * t, top[2] + (bottom[2] - top[2]) * t,
			top[3] + (bottom[3] - top[3]) * t, top[4] + (bottom[4] - top[4]) * t
	end
	local rows = { { 0, c }, { c, height - c }, { height - c, height } }
	for row = 1, 3 do
		local r1, g1, b1, a1 = at(rows[row][2])
		local r2, g2, b2, a2 = at(rows[row][1])
		for col = 1, 3 do
			-- Bottom stop first: vertical gradients run bottom to top.
			gradient(s[(row - 1) * 3 + col], "VERTICAL", r1, g1, b1, a1, r2, g2, b2, a2)
		end
	end
end

-- A horizontal three-slice: caps half the height wide, from the file's outer
-- quarters, and the middle stretched.
local function ThreeSlice(parent, layer, sublevel, file)
	local s = {}
	for i, cut in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(cut[1], cut[2], 0, 1)
		s[i] = t
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

local function Mix(r, g, b, t)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

-- A one-shot fade on a frame, parked where it ends so nothing is left lit.
local function Fade(frame, to, duration, smoothing)
	local group = frame:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetDuration(duration)
	if smoothing and fade.SetSmoothing then fade:SetSmoothing(smoothing) end
	group.fade = fade
	group:SetScript("OnFinished", function() frame:SetAlpha(group.to or to or 0) end)
	return group
end

-- Whether this client reads an English string in its own language; the
-- verdict words are new, and a German player is better served by the lines
-- that are translated than by English in a German panel.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Luxe:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own = {}
	self.own = own
	local function keep(x) own[#own + 1] = x return x end
	local function tex(parent, layer, sublevel, file, blend)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end
	local function frame(parent)
		local f = keep(CreateFrame("Frame", nil, parent))
		f:SetAlpha(0)
		return f
	end

	-- The ground. On art itself, below the list's rows and the icon, which
	-- are art's too: a frame of its own would draw over both.
	-- No gloss: white laid over the top of the card is exactly where the name
	-- sits, and the game drew it near-solid (1.5.0, "white on white").
	self.shadow = NineSlice(art, "BACKGROUND", -8, ART .. "Shadow", 128, 40, 20)
	self.card = NineSlice(art, "BACKGROUND", -6, ART .. "Card", 64, 16, 8)
	self.bevel = NineSlice(art, "BORDER", 1, ART .. "Bevel", 64, 16, 8)
	-- The list's own card, hung from a box that PaintQueue sizes.
	self.trayBox = keep(CreateFrame("Frame", nil, art))
	self.tray = NineSlice(art, "BACKGROUND", -6, ART .. "Card", 64, 16, 8)
	self.trayBevel = NineSlice(art, "BORDER", 1, ART .. "Bevel", 64, 16, 8)
	-- The top edge lit in the reason colour, for "Reason colour: both".
	self.edge = NineSlice(art, "BORDER", 2, ART .. "Edge", 64, 16, 8, "ADD")
	self.trayEdge = NineSlice(art, "BORDER", 2, ART .. "Edge", 64, 16, 8, "ADD")
	for _, s in ipairs({ self.shadow, self.card, self.bevel, self.tray, self.trayBevel, self.edge,
		self.trayEdge }) do
		for _, t in ipairs(s) do keep(t) end
	end
	self.ground = {}
	for _, s in ipairs({ self.shadow, self.card, self.bevel }) do
		for _, t in ipairs(s) do self.ground[#self.ground + 1] = t end
	end

	-- The ink. The washes lie under the icon (BORDER, the icon is ARTWORK) and
	-- the cursor's is lit by its colour, not its frame: a frame of light
	-- draws over everything on art, and the spell icon is drawn clean.
	self.wash = tex(art, "BORDER", 2, "Wash", "ADD")
	self.hoverWash = tex(art, "BORDER", 2, "Wash", "ADD")
	self.glow = tex(art, "ARTWORK", 0, "SpineGlow", "ADD")
	-- The spine on a frame of its own, over the frames of light: a glow added
	-- on top of the core pushed it to lemon or white, and the mark lost the
	-- very colour it carries. The light blooms round it instead.
	self.spineFrame = keep(CreateFrame("Frame", nil, art))
	self.spineFrame:SetAllPoints(art)
	self.spine = tex(self.spineFrame, "ARTWORK", 1, "Spine")
	-- Over the icon only its setting: the rim hugs its edge and the ring sits
	-- outside it. No shade over the spell itself.
	self.rim = tex(art, "ARTWORK", 2, "IconRim")
	self.ring = tex(art, "ARTWORK", 3, "IconRing")
	self.dots = {}
	for i = 1, #kit.rows do self.dots[i] = tex(art, "ARTWORK", 1, "Dot") end

	-- The icon's shape. Not ours to keep in `own`: it is taken off the icon in
	-- Hide.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- What moves, each on a frame of its own: only a frame can be animated.
	self.flareFrame = frame(art)
	self.flare = tex(self.flareFrame, "ARTWORK", 0, "SpineGlow", "ADD")
	self.pulseFrame = frame(art)
	self.pulseGlow = tex(self.pulseFrame, "ARTWORK", 0, "SpineGlow", "ADD")
	-- The second tone of the breath: a warm white ring hugging the reason's
	-- own, over the same breath, outside the icon like the ring it lights.
	self.pulseRing = tex(self.pulseFrame, "OVERLAY", 0, "IconRing", "ADD")
	self.hoverFrame = frame(art)
	self.hoverGlow = tex(self.hoverFrame, "ARTWORK", 0, "SpineGlow", "ADD")
	self.hoverLight = NineSlice(self.hoverFrame, "BORDER", 3, ART .. "Card", 64, 16, 8, "ADD")
	for _, t in ipairs(self.hoverLight) do keep(t) end
	SliceColor(self.hoverLight, 1, 1, 1, HOVER_LIGHT)
	self.resultFrame = frame(art)
	self.result = NineSlice(self.resultFrame, "ARTWORK", 5, ART .. "Card", 64, 16, 8, "ADD")
	for _, t in ipairs(self.result) do keep(t) end
	-- The rings that spread when a buff lands and the one that snaps in when
	-- one is refused, in this look's own ring art. No echo of the icon: the
	-- spell is drawn clean.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do keep(f) end
	-- Where the art's ring is brightest and how far out it is seen, for how
	-- far the rings may spread (measured from the files: hunt37-effects).
	kit.RingArt(ART .. "IconRing", 0.922, 0.96)
	kit.RingArt(ART .. "IconRingRound", 0.922, 0.96)
	self.burstFrame = self.fx.rings[1].frame
	self.sheenFrame = frame(art)
	self.sheen = tex(self.sheenFrame, "OVERLAY", 1, "Sheen", "ADD")
	self.glint = tex(self.sheenFrame, "OVERLAY", 2, "Glint", "ADD")

	-- The tag: its fill and edge under the reason line, which moves in with
	-- them (Apply), so the swap's cross-fade, the refusal's shake and the pop
	-- carry the whole tag.
	self.pillFrame = keep(CreateFrame("Frame", nil, textLayer))
	self.pillFill = ThreeSlice(self.pillFrame, "ARTWORK", 2, ART .. "Pill")
	self.pillEdge = ThreeSlice(self.pillFrame, "ARTWORK", 3, ART .. "PillEdge")
	self.glyph = tex(self.pillFrame, "ARTWORK", 4, "Check")
	self.chipBox = keep(CreateFrame("Frame", nil, textLayer))
	self.chipFill = ThreeSlice(textLayer, "ARTWORK", 2, ART .. "Pill")
	self.chipEdge = ThreeSlice(textLayer, "ARTWORK", 3, ART .. "PillEdge")
	for _, s in ipairs({ self.pillFill, self.pillEdge, self.chipFill, self.chipEdge }) do
		for _, t in ipairs(s) do keep(t) end
	end
	PlaceThree(self.chipFill, self.chipBox, 10)
	PlaceThree(self.chipEdge, self.chipBox, 10)

	-- Levels: the light over the art, the spine over the light, the ring's
	-- burst and the crossing light over both, the text over all of it, the
	-- tag's frame over the text's own frame (Apply: base + 4 and + 5).
	local base = art:GetFrameLevel()
	for _, f in ipairs({ self.resultFrame, self.flareFrame, self.pulseFrame, self.hoverFrame }) do
		f:SetFrameLevel(base + 1)
	end
	self.spineFrame:SetFrameLevel(base + 2)
	for _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 3) end
	self.sheenFrame:SetFrameLevel(base + 3)

	self:BuildAnimations()
end

function Luxe:BuildAnimations()
	-- The spine flares once when somebody owed arrives: up quickly, down
	-- slowly. The peak is set for each play (Calm's is half).
	local flare = self.flareFrame:CreateAnimationGroup()
	local up = flare:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetDuration(0.12)
	up:SetOrder(1)
	local down = flare:CreateAnimation("Alpha")
	down:SetToAlpha(0)
	down:SetDuration(0.9)
	down:SetOrder(2)
	if down.SetSmoothing then down:SetSmoothing("OUT") end
	flare.up, flare.down = up, down
	flare:SetScript("OnFinished", function() self.flareFrame:SetAlpha(0) end)
	flare:SetScript("OnStop", function() self.flareFrame:SetAlpha(0) end)
	self.flareAnim = flare

	-- A buff landed: the spine's light flares and lets go inside half a second,
	-- on the same frame as the arrival's flare (one at a time).
	local land = self.flareFrame:CreateAnimationGroup()
	local landUp = land:CreateAnimation("Alpha")
	landUp:SetFromAlpha(0)
	landUp:SetToAlpha(0.85)
	landUp:SetDuration(0.07)
	landUp:SetOrder(1)
	local landDown = land:CreateAnimation("Alpha")
	landDown:SetFromAlpha(0.85)
	landDown:SetToAlpha(0)
	landDown:SetDuration(0.40)
	landDown:SetOrder(2)
	if landDown.SetSmoothing then landDown:SetSmoothing("OUT") end
	land:SetScript("OnFinished", function() self.flareFrame:SetAlpha(0) end)
	land:SetScript("OnStop", function() self.flareFrame:SetAlpha(0) end)
	self.landAnim = land

	-- A favour arriving: the ring in the reason's colour locks onto the icon,
	-- from wider and faint, past and back, in a quarter of a second.
	local lock = self.ring:CreateAnimationGroup()
	local lockFade = lock:CreateAnimation("Alpha")
	lockFade:SetFromAlpha(0.25)
	lockFade:SetToAlpha(1)
	lockFade:SetDuration(0.12)
	lockFade:SetOrder(1)
	local lockIn = lock:CreateAnimation("Scale")
	if lockIn.SetScaleFrom then lockIn:SetScaleFrom(1.30, 1.30) end
	if lockIn.SetScaleTo then lockIn:SetScaleTo(0.97, 0.97) end
	if lockIn.SetOrigin then lockIn:SetOrigin("CENTER", 0, 0) end
	lockIn:SetDuration(0.15)
	lockIn:SetOrder(1)
	if lockIn.SetSmoothing then lockIn:SetSmoothing("OUT") end
	local lockSettle = lock:CreateAnimation("Scale")
	if lockSettle.SetScaleFrom then lockSettle:SetScaleFrom(0.97, 0.97) end
	if lockSettle.SetScaleTo then lockSettle:SetScaleTo(1, 1) end
	if lockSettle.SetOrigin then lockSettle:SetOrigin("CENTER", 0, 0) end
	lockSettle:SetDuration(0.10)
	lockSettle:SetOrder(2)
	if lockSettle.SetSmoothing then lockSettle:SetSmoothing("IN_OUT") end
	self.lockAnim = lock
	self.lockIn, self.lockSettle = lockIn, lockSettle

	-- Breathing while somebody owed waits: slow and faint, so the only loop
	-- on the panel never reads as flashing. 1.3 s each way, 2.6 s round.
	local pulse = self.pulseFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local breathe = pulse:CreateAnimation("Alpha")
	breathe:SetFromAlpha(0.18)
	breathe:SetToAlpha(0.36)
	breathe:SetDuration(1.3)
	if breathe.SetSmoothing then breathe:SetSmoothing("IN_OUT") end
	self.pulseAnim = pulse

	local pop = self.pillFrame:CreateAnimationGroup()
	local grow = pop:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.9, 0.9) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin("CENTER", 0, 0) end
	grow:SetDuration(0.18)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	local show = pop:CreateAnimation("Alpha")
	show:SetFromAlpha(0)
	show:SetToAlpha(1)
	show:SetDuration(0.18)
	self.popAnim = pop

	local sheen = self.sheenFrame:CreateAnimationGroup()
	local sIn = sheen:CreateAnimation("Alpha")
	sIn:SetFromAlpha(0)
	sIn:SetToAlpha(1)
	sIn:SetDuration(0.08)
	sIn:SetOrder(1)
	local move = sheen:CreateAnimation("Translation")
	move:SetDuration(0.6)
	move:SetOrder(2)
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	local sOut = sheen:CreateAnimation("Alpha")
	sOut:SetFromAlpha(1)
	sOut:SetToAlpha(0)
	sOut:SetDuration(0.3)
	if sOut.SetStartDelay then sOut:SetStartDelay(0.3) end
	sOut:SetOrder(2)
	sheen.move = move
	sheen:SetScript("OnFinished", function() self.sheenFrame:SetAlpha(0) end)
	sheen:SetScript("OnStop", function() self.sheenFrame:SetAlpha(0) end)
	self.sheenAnim = sheen

	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	self.resultAnim = Fade(self.resultFrame, 0, self.kit.OUTCOME_SECONDS, "OUT")
	self.resultAnim.fade:SetFromAlpha(1)
	self.resultAnim.fade:SetToAlpha(0)
	-- The cursor's light, both ways; from and to are set for each play.
	self.hoverAnim = Fade(self.hoverFrame, 0, 0.12, "OUT")
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Luxe:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local c = p.bgColor or {}
	local br, bg, bb, ba = c[1] or 0.04, c[2] or 0.04, c[3] or 0.06, c[4] == nil and 0.88 or c[4]

	local spineW = H < 36 and 3 or (H >= 46 and 5 or 4)
	local iconX = SPINE_X + spineW + 7
	-- Held inside the card with room for its ring: the icon slider allows up
	-- to the panel's full height.
	local iconSize = math.max(8, math.min(p.iconSize, H - 10))
	local showIcon = p.showIcon and true or false
	local spineLen = math.max(8, showIcon and math.min(iconSize, H - 14) or H - 16)
	-- Tight between the built-in looks' two-line height and Luxe's own.
	local tight = H < BlockHeight(fs)
	local sub, pillH = SubSize(fs), PillHeight(fs, tight)
	local nameH, gap = 1.2 * fs, Gap(fs, tight)
	local top = (H - (nameH + gap + pillH)) / 2
	local textX = showIcon and (iconX + iconSize + 10) or (SPINE_X + spineW + 9)
	self.p, self.W, self.H = p, W, H
	self.spineW, self.iconX, self.textX = spineW, iconX, textX
	self.sub, self.pillH, self.pitch = sub, pillH, sub + 7
	-- Measured from the centre, up positive, for SetPoint.
	self.nameY = H / 2 - (top + nameH / 2)
	self.pillTop = top + nameH + gap
	self.subRoom = math.max(20, W - textX - 10 - pillH)
	self.glyphRoom = sub + 2
	self.above = above
	-- A panel made nearly clear: the card gives the text no ground, so the
	-- text is outlined and the tag carries a dark ground of its own (Styled,
	-- PaintPill), and below 0.2 the shadow goes, a smudge round nothing.
	self.clear = ba < 0.35
	self.fitText, self.dropped = nil, nil

	-- The ground: the card is the panel colour, darker towards the bottom --
	-- the same two stops Prompt's text is measured against.
	local shadowAlpha = 0.62 * math.min(1, ba + 0.1)
	SliceColor(self.shadow, 0, 0, 0, shadowAlpha)
	PlaceSlice(self.shadow, art, art, 12, 9, 12, 15)
	self.trayShown = nil
	SliceGradient(self.card, H, { br, bg, bb, ba }, { br * 0.62, bg * 0.62, bb * 0.72, ba }, kit.Gradient)
	PlaceSlice(self.card, art, art, 0, 0, 0, 0)
	PlaceSlice(self.bevel, art, art, 1, 1, 1, 1)
	SliceColor(self.bevel, 1, 1, 1, 1)
	PlaceSlice(self.edge, art, art, 1, 1, 1, 1)
	-- The list's card: the panel's colour a shade lighter in alpha, graded
	-- here, once, for the most rows the list can hold. The gradient is per
	-- slice, so a list of fewer rows draws the same fall from top to bottom,
	-- and PaintQueue, which runs on every scan, only sets a height.
	self.trayHeight = nil
	SliceGradient(self.tray, 8 + math.max(1, p.queueRows or 1) * (sub + 7),
		{ br, bg, bb, ba * 0.9 }, { br * 0.70, bg * 0.70, bb * 0.78, ba * 0.9 }, kit.Gradient)
	PlaceSlice(self.tray, self.trayBox, self.trayBox, 0, 0, 0, 0)
	PlaceSlice(self.trayBevel, self.trayBox, self.trayBox, 1, 1, 1, 1)
	PlaceSlice(self.trayEdge, self.trayBox, self.trayBox, 1, 1, 1, 1)
	SliceColor(self.trayBevel, 1, 1, 1, 0.8)

	-- The ink. The reason's light fades out before the text starts, so the
	-- name and the tag stand on the card's own dark.
	for _, t in ipairs({ self.wash, self.hoverWash }) do
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", 1, -1)
		t:SetPoint("BOTTOMLEFT", 1, 1)
		t:SetWidth(math.min(math.floor(W * 0.52), textX + 1))
	end
	self.spine:ClearAllPoints()
	self.spine:SetPoint("LEFT", SPINE_X, 0)
	self.spine:SetSize(spineW, spineLen)
	-- The bloom round the spine, cut where the icon (or, with none, the text)
	-- begins: its frames draw over the icon, and its tail reached five units
	-- onto the spell.
	local half = spineW / 2 + 12
	local reach = (showIcon and iconX or textX) - 1 - (SPINE_X + spineW / 2)
	local glowW = half + math.max(spineW / 2, math.min(half, reach))
	for _, t in ipairs({ self.glow, self.flare, self.pulseGlow, self.hoverGlow }) do
		t:ClearAllPoints()
		t:SetPoint("LEFT", self.spine, "CENTER", -half, 0)
		t:SetSize(glowW, spineLen + 24)
		t:SetTexCoord(0, glowW / (2 * half), 0, 1)
	end
	-- Where the light over the card may start: past the icon's ring.
	local clearX = showIcon and math.ceil(iconX + iconSize + RING_PAD * iconSize / 30 + 1) or 0
	self.clearX = clearX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	local round = p.roundIcon and true or false
	local maskFile = ART .. (round and "IconMaskRound" or "IconMask")
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	self.rim:SetTexture(ART .. (round and "IconRimRound" or "IconRim"))
	self.ring:SetTexture(ART .. (round and "IconRingRound" or "IconRing"))
	self.pulseRing:SetTexture(ART .. (round and "IconRingRound" or "IconRing"))
	local rimPad = iconSize / 30
	local ringPad = RING_PAD * iconSize / 30
	if showIcon then
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", iconX, 0)
		self.rim:ClearAllPoints()
		self.rim:SetPoint("TOPLEFT", icon, "TOPLEFT", -rimPad, rimPad)
		self.rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", rimPad, -rimPad)
		for _, t in ipairs({ self.ring, self.pulseRing }) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", icon, "TOPLEFT", -ringPad, ringPad)
			t:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", ringPad, -ringPad)
		end
		-- The rings spread from where the reason's ring sits.
		self.fx:Place(icon, ringPad, iconSize)
		self.fx:Shape(round, ART .. "IconRingRound", ART .. "IconRing")
		-- The room the rings have: to the text (less a margin), to the card's
		-- left edge and to its top and bottom edges. The lock-on ring that
		-- closes on the icon is held to it as well.
		local half = iconSize / 2
		local limitH = half + math.min(textX - iconX - iconSize - kit.TEXT_MARGIN, iconX - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		kit.CapLock(self.lockIn, self.lockSettle, 1.30, 0.97,
			kit.CapScale(math.min(limitH, limitV), half + ringPad, 0.96))
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep is rounded too.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
		end
	end

	-- The light that crosses: about a fifth of the card wide, from past the
	-- icon to the far edge, its glint no wider than itself.
	local band = math.max(24, math.floor(W * 0.22))
	self.sheenFrame:ClearAllPoints()
	self.sheenFrame:SetPoint("LEFT", art, "LEFT", clearX, 0)
	self.sheenFrame:SetSize(band, H - 2)
	self.sheen:ClearAllPoints()
	self.sheen:SetAllPoints(self.sheenFrame)
	self.glint:ClearAllPoints()
	self.glint:SetPoint("CENTER", self.sheenFrame, "TOP", 0, 1)
	self.glint:SetSize(math.min(40, band), 4)
	self.sheenAnim.move:SetOffset(math.max(0, W - band - clearX), 0)

	for _, f in ipairs({ self.hoverFrame, self.resultFrame }) do
		f:ClearAllPoints()
		f:SetAllPoints(art)
	end
	PlaceSlice(self.hoverLight, self.hoverFrame, self.hoverFrame, -clearX, 0, 0, 0)
	PlaceSlice(self.result, self.resultFrame, self.resultFrame, -clearX, 0, 0, 0)

	local textLayer, subText = kit.textLayer, kit.sub
	local base = art:GetFrameLevel()
	textLayer:SetFrameLevel(base + 4)
	self.pillFrame:SetFrameLevel(base + 5)
	self.chipBox:SetFrameLevel(base + 5)
	if not self.subMoved then
		subText:SetParent(self.pillFrame)
		self.subMoved = true
	end
	self.pillFrame:ClearAllPoints()
	self.pillFrame:SetPoint("TOPLEFT", textLayer, "TOPLEFT", textX, -self.pillTop)
	self.pillFrame:SetSize(pillH * 2, pillH)
	PlaceThree(self.pillFill, self.pillFrame, pillH)
	PlaceThree(self.pillEdge, self.pillFrame, pillH)
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", self.pillFrame, "LEFT", pillH / 2 - 1, 0)
	self.glyph:SetSize(sub, sub)
	self.glyph:Hide()
	self.verdict = nil

	-- The chip rides the name line at the right (Styled, which knows where
	-- the name line is).
	local chipH = math.max(8, pillH - 1)
	self.chipH = chipH
	self.chipBox:SetSize(chipH * 2, chipH)
	PlaceThree(self.chipFill, self.chipBox, chipH)
	PlaceThree(self.chipEdge, self.chipBox, chipH)
	-- A dark chip, as the tag: solid enough that however the game weighs its
	-- alpha, the count stands on dark.
	for _, t in ipairs(self.chipFill) do
		t:SetVertexColor(NEUTRAL[1] * PILL_DARK, NEUTRAL[2] * PILL_DARK, NEUTRAL[3] * PILL_DARK, PILL_ALPHA)
	end
	for _, t in ipairs(self.chipEdge) do t:SetVertexColor(1, 1, 1, 0.12) end
	kit.count:ClearAllPoints()
	kit.count:SetPoint("CENTER", self.chipBox, "CENTER", 0, 0)

	local rowWidth = math.max(20, W - iconX - 8)
	for _, fs in ipairs(kit.rows) do
		fs:SetWidth(rowWidth)
		fit.room[fs] = rowWidth
	end

	-- Everything this look draws, shown, and then what waits: the effects on
	-- frames parked at alpha 0, the list for PaintQueue, the ring for the
	-- reason's paint, the tag for its text, the chip for a count.
	for _, x in ipairs(self.own) do x:Show() end
	for _, s in ipairs({ self.tray, self.trayBevel, self.edge, self.trayEdge }) do SliceShown(s, false) end
	if ba < 0.2 then SliceShown(self.shadow, false) end
	self.both, self.pillHex, self.pillCode = nil, nil, nil
	for _, d in ipairs(self.dots) do d:Hide() end
	for _, t in ipairs({ self.rim, self.ring }) do t:SetShown(showIcon) end
	self.fx:SetShown(showIcon)
	self.pulseRing:SetShown(showIcon)
	self.glyph:Hide()
	self:Chip(false)
	self.combat, self.hovered, self.washFor = nil, nil, nil
	-- Shown and hidden, never given an alpha: on a texture the game keeps one
	-- alpha, and SetAlpha(1) wrote over the faint one the colour set.
	self.glow:Show()
	self.wash:Show()
	self:HoverWash()
	self:SetInk(1, 1, 1)

	-- The count's room: a two-digit count and the chip's caps. Chip widens it
	-- for a longer count.
	local chipRoom = math.ceil(sub * 1.2 + 0.9 * chipH) + 14
	self.roomBase = chipRoom
	return textX, chipRoom
end

function Luxe:Styled(p, twoLine)
	local kit = self.kit
	-- The chip on the name line, wherever the name line is: centred when it
	-- is the only one.
	self.chipBox:ClearAllPoints()
	self.chipBox:SetPoint("RIGHT", kit.textLayer, "RIGHT", -8, twoLine and self.nameY or 0)
	-- A nearly clear panel: every line outlined, as on the minimal look, and
	-- the lines FitLine shrinks keep it (fit.flags).
	if self.clear then
		kit.fit.flags = "OUTLINE"
		for _, fs in ipairs({ kit.name, kit.sub, kit.count }) do
			local path, size = fs:GetFont()
			if path then fs:SetFont(path, size, "OUTLINE") end
		end
		for _, fs in ipairs(kit.rows) do
			local path, size = fs:GetFont()
			if path then fs:SetFont(path, size, "OUTLINE") end
		end
	end
	-- A shadow inside a tinted tag reads as dirt.
	kit.sub:SetShadowColor(0, 0, 0, 0)
	kit.sub:SetShadowOffset(0, 0)
	-- The count stands on its chip's own dark fill, not on the panel: held
	-- to the panel, a light one took it dark on dark.
	kit.count:SetTextColor(0.80, 0.81, 0.86, 1)
	kit.count:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.90, 0.90, 0.92, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	kit.ink.rowReason = kit.ink.light and "|cff9a9ca8" or "|cff505058"
end

function Luxe:Hide()
	local kit = self.kit
	if not kit then return end
	for _, x in ipairs(self.own) do x:Hide() end
	for _, anim in ipairs({ self.flareAnim, self.pulseAnim, self.popAnim, self.sheenAnim,
		self.burstAnim, self.resultAnim, self.hoverAnim, self.landAnim, self.lockAnim }) do
		anim:Stop()
	end
	self.fx:Stop()
	-- Stop parks nothing on a fade that has already finished, and the cursor
	-- leaves for the next look: put the light out here, or it is lit when
	-- this look comes back.
	self.hoverFrame:SetAlpha(0)
	self.resultFrame:SetAlpha(0)
	-- The shared regions, as the built-in looks expect to find them.
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetDesaturated(false)
	if kit.cooldown then
		kit.cooldown:SetAlpha(1)
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	if self.subMoved then
		kit.sub:SetParent(kit.textLayer)
		self.subMoved = nil
	end
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	for _, fs in ipairs({ kit.name, kit.sub, kit.count }) do fs:SetAlpha(1) end
	-- The reason line's room is the tag's: the built-in looks fit theirs to
	-- the panel's width, and only do so while this is nil.
	kit.fit.room[kit.sub] = nil
	self.combat, self.hovered, self.washFor, self.trayShown = nil, nil, nil, nil
	self.fitText, self.dropped = nil, nil
end

---------------------------------------------------------------------------
-- the lines
---------------------------------------------------------------------------

function Luxe:PlaceLines(right)
	local kit = self.kit
	local name, sub = kit.name, kit.sub
	-- The name keeps 20 units: the two points never cross.
	right = math.min(right, math.max(0, self.W - self.textX - 20))
	-- The reason line lost its anchor to the tag: the next fit places it again.
	self.fitText = nil
	if kit.fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -right, self.nameY)
		sub:SetPoint("LEFT", self.pillFrame, "LEFT", self.pillH / 2, 0)
		sub:SetWidth(self.subRoom)
		kit.fit.room[sub] = self.subRoom
	else
		name:SetPoint("LEFT", self.textX, 0)
		name:SetPoint("RIGHT", -right, 0)
	end
end

-- Whether the reason line holds the verdict PaintOutcome wrote, which is the
-- only time the tag carries a glyph.
function Luxe:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

-- The tag's fill and edge: in the reason's colour, or in the colour the line
-- brings with it (a line written in red is not a reason and should not sit
-- in a gold tag). The fill is that colour taken dark, under an
-- edge in the colour itself; on a nearly clear panel, black.
function Luxe:PaintPill()
	local c = self.pillCode or self.tint or NEUTRAL
	local r, g, b = c[1], c[2], c[3]
	for _, t in ipairs(self.pillEdge) do t:SetVertexColor(r, g, b, 0.50) end
	local k = (self.clear and 0) or (self.combat and PILL_DARK_COMBAT) or PILL_DARK
	for _, t in ipairs(self.pillFill) do t:SetVertexColor(r * k, g * k, b * k, PILL_ALPHA) end
end

-- The tag hugs its words. The scan repaints the same line several times a
-- second, so a line already fitted in the same room is left as it is: no
-- measuring, no anchoring, no string work.
function Luxe:Fitted(fs)
	local kit = self.kit
	if fs ~= kit.sub then return end
	local fit = kit.fit
	local verdict = self:ShowsVerdict()
	local glyph = self.glyphOn and verdict
	local room = self.subRoom - (glyph and self.glyphRoom or 0)
	if fit.room[fs] ~= room then
		-- Fitted again at the room the glyph leaves, which lands back here.
		fit.room[fs] = room
		fs:SetWidth(room)
		return kit.FitLine(fs)
	end
	local text = fs:GetText()
	local secret = issecretvalue and issecretvalue(text)
	local shown = fit.twoLine and fs:IsShown() and (secret or (type(text) == "string" and text ~= ""))
		and true or false
	local combat = self.combat or false
	if not secret and text == self.fitText and room == self.fitRoom and shown == self.fitShown
		and combat == self.fitCombat and glyph == self.fitGlyph and verdict == self.fitVerdict
		and fit.size[fs] == self.fitSize then
		if self.dropped then fs:SetText("") end
		return
	end
	self.fitText, self.fitRoom, self.fitShown = not secret and text or nil, room, shown
	self.fitCombat, self.fitGlyph, self.fitVerdict, self.fitSize = combat, glyph, verdict, fit.size[fs]
	self.dropped = nil

	-- A line with a colour of its own, when it is not the verdict and no
	-- fight holds the panel (there the tag keeps the reason round the grey
	-- "held -- in combat"). Read once per new line.
	local hex = shown and not secret and not combat and not verdict and text:match("^|c[fF][fF](%x%x%x%x%x%x)")
		or nil
	if hex ~= self.pillHex then
		self.pillHex = hex
		self.pillCode = hex and { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
			tonumber(hex:sub(5, 6), 16) / 255 } or nil
		self:PaintPill()
	end

	if not shown then
		self.pillFrame:Hide()
		return
	end
	-- What FitLine just measured; measured here only when it could not fit.
	local width = fit.drawn[fs] or kit.TextWidth(fs) or room
	if width > room + 0.5 then
		-- Cut even at its smallest: a tag ending in an ellipsis is no tag, so
		-- its words are left out of this paint. The spine still says why.
		self.dropped = true
		fs:SetText("")
		self.pillFrame:Hide()
		return
	end
	local lead = glyph and self.glyphRoom or 0
	self.pillFrame:SetWidth(math.floor(math.min(width, room) + self.pillH + lead + 0.5))
	fs:ClearAllPoints()
	fs:SetPoint("LEFT", self.pillFrame, "LEFT", self.pillH / 2 + lead, 0)
	self.glyph:SetShown(glyph and true or false)
	self.pillFrame:Show()
end

function Luxe:Chip(on)
	local kit = self.kit
	local chipW
	if on then
		-- Sized from the digits, not measured: a digit is about six tenths of
		-- the font across. The room the lines keep is this chip's, its inset and
		-- the gap, and never less than two digits' (Apply's), so the name does
		-- not run under a count of three digits and a count of one or two does
		-- not move the name.
		local text = kit.count:GetText()
		local digits = type(text) == "string" and math.max(1, #text) or 1
		chipW = math.floor(digits * 0.6 * self.sub + 0.9 * self.chipH + 0.5)
		kit.fit.chipRoom = math.max(self.roomBase or 0, chipW + 14)
	end
	if on then
		-- The name wins: a chip that would leave the name cut even at its
		-- smallest size is left out of this paint. The margin is on the
		-- chip's side, so it steps aside before the name reaches its edge.
		-- The width is the one FitLine just measured.
		local name, fit = kit.name, kit.fit
		local width, size, base = fit.drawn[name] or kit.TextWidth(name), fit.size[name], fit.base[name]
		if width and size and base and size > 0 then
			local least = math.max(7, math.floor(base * 0.8 + 0.5))
			if width * least / size > self.W - self.textX - fit.chipRoom - 0.5 then on = false end
		end
	end
	if on then self.chipBox:SetWidth(chipW) end
	for _, s in ipairs({ self.chipFill, self.chipEdge }) do
		for _, t in ipairs(s) do t:SetShown(on) end
	end
	kit.count:SetShown(on)
	return on
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The ink's alpha, for the fight: the icon and its rim dim; the spine and the
-- ring keep their colour, so the reason still reads.
function Luxe:SetInk(ink, ground, text)
	local kit = self.kit
	for _, t in ipairs(self.ground) do t:SetAlpha(ground) end
	for _, t in ipairs({ self.rim, kit.icon }) do t:SetAlpha(ink) end
	if kit.cooldown then kit.cooldown:SetAlpha(ink) end
	-- On the lines themselves, not on textLayer: Prompt's cross-fade plays
	-- on textLayer, and an animation's alpha replaces its frame's own, so a
	-- name changing in a fight flashed to full and popped back.
	kit.name:SetAlpha(text)
	kit.sub:SetAlpha(text)
	kit.count:SetAlpha(text)
end

-- The marks in one colour: the spine, its light, the ring, the tag.
function Luxe:Tint(r, g, b, ring)
	local kit = self.kit
	self.spine:SetVertexColor(r, g, b, 1)
	-- The resting bloom: stronger than the design's, so the spine is a light.
	-- Light added to a light card only greys it, so there it is a hint.
	self.glow:SetVertexColor(r, g, b, kit.ink.light and 0.26 or 0.10)
	self.wash:SetVertexColor(r, g, b, 0.11)
	self.flare:SetVertexColor(r, g, b, 1)
	self.pulseGlow:SetVertexColor(r, g, b, 1)
	self.hoverGlow:SetVertexColor(r, g, b, 0.35)
	self.ring:SetVertexColor(r, g, b, 0.85)
	self.ring:SetShown(ring and kit.icon:IsShown() and true or false)
	-- The warm white on the same ring, for the owed breath.
	local w = kit.WARM_WHITE
	self.pulseRing:SetVertexColor(w[1], w[2], w[3], 0.9)
	self.pulseRing:SetShown(ring and kit.icon:IsShown() and true or false)
	-- The top edge, shown by PaintReason for "both" only.
	SliceColor(self.edge, r, g, b, 0.45)
	SliceColor(self.trayEdge, r, g, b, 0.30)
	local tint = self.tint or {}
	tint[1], tint[2], tint[3] = r, g, b
	self.tint = tint
	self:HoverWash()
	self:PaintPill()
	-- The words stand on the tag's own dark fill, so they go light on any
	-- panel. Held to a light panel they went dark on dark; on a dark one the
	-- panel's rule can only take them lighter still.
	local tr, tg, tb = Mix(r, g, b, kit.ink.light and 0.35 or 0.5)
	if kit.ink.light then tr, tg, tb = kit.Legible(tr, tg, tb, 4.5) end
	kit.sub:SetTextColor(tr, tg, tb, 1)
	self.glyph:SetVertexColor(tr, tg, tb, 1)
end

function Luxe:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	self:Tint(r, g, b, mode == "icon" or mode == "both")
	-- "Both" is the ring and the spine, which "icon" already is on this look,
	-- and the card's top edge lit in the reason colour, which only it is.
	self.both = mode == "both"
	SliceShown(self.edge, self.both)
	SliceShown(self.trayEdge, self.both and self.trayShown or false)
	-- A refusal greyed the icon; a fight keeps it grey.
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Luxe:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	if on then
		self:SetInk(INK_COMBAT, GROUND_COMBAT, TEXT_COMBAT)
		self.pulseAnim:Stop()
		self.pulseFrame:SetAlpha(0)
		self.glow:Hide()
		self.wash:Hide()
		-- The tag keeps the reason round the fight's grey words.
		self.pillHex, self.pillCode = nil, nil
	else
		self:SetInk(1, 1, 1)
		self.glow:Show()
		self.wash:Show()
	end
	-- Its ground darker in a fight, and back after.
	self:PaintPill()
	self.kit.icon:SetDesaturated(on)
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

function Luxe:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" then
		self:StopAttention()
		return
	end
	if isNew then
		-- The spine flares once; on Calm, at half the height.
		local peak = full and 0.9 or 0.45
		self.landAnim:Stop()
		self.flareAnim:Stop()
		self.flareAnim.up:SetToAlpha(peak)
		self.flareAnim.down:SetFromAlpha(peak)
		self.flareAnim:Play()
		if full then
			self.popAnim:Stop()
			self.popAnim:Play()
			-- The ring locks onto the icon, where there is a ring to lock.
			if self.ring:IsShown() then
				self.lockAnim:Stop()
				self.lockAnim:Play()
			end
		end
	end
	-- The favour just done: light crosses the card in the reason's colour.
	if arrived and full and not self.sheenAnim:IsPlaying() then
		local t = self.tint or NEUTRAL
		self:Sheen(Mix(t[1], t[2], t[3], 0.55))
	end
	if flashStyle == "pulse" and not self.combat then
		if full then
			if not self.pulseAnim:IsPlaying() then self.pulseAnim:Play() end
		else
			-- Calm: nothing loops. The glow is held, a little brighter.
			self.pulseAnim:Stop()
			self.pulseFrame:SetAlpha(0.25)
		end
	else
		self:StopAttention()
	end
end

function Luxe:StopAttention()
	self.pulseAnim:Stop()
	self.pulseFrame:SetAlpha(0)
end

function Luxe:Sheen(r, g, b, a)
	self.sheen:SetVertexColor(r, g, b, a or 0.30)
	self.glint:SetVertexColor(Mix(r, g, b, 0.3))
	self.sheenAnim:Stop()
	self.sheenAnim:Play()
end

-- The spine's light flared once, in the colour Tint last gave it (the
-- outcome's), and let go: the glow answering the rings.
function Luxe:Flare()
	self.flareAnim:Stop()
	self.landAnim:Stop()
	self.landAnim:Play()
end

function Luxe:Flourish(kind)
	-- A refusal contracts: one ring snaps in onto the icon in red, and the
	-- spine's light (already red) flares. The text's shake is Prompt's.
	if kind == "failed" then
		local o = OUTCOME.failed
		if self.kit.icon:IsShown() then self.fx:Refuse(o[1], 0.45, 0.28) end
		self:Flare()
		return
	end
	if kind == "cast" and self.kit.icon:IsShown() then
		local o = OUTCOME.cast
		self.fx:Land(o[1], o[2], o[3])
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim. The light
	-- is the landed buff's green taken towards white: plain white over the
	-- near-black card only greys it.
	if kind == "cast" then
		local o = OUTCOME.cast
		local r, g, b = Mix(o[1], o[2], o[3], 0.6)
		self:Sheen(r, g, b, 0.30)
		self:Flare()
	end
end

function Luxe:StopFlourishes()
	self.fx:Stop()
	self.sheenAnim:Stop()
	self.landAnim:Stop()
	self.lockAnim:Stop()
end

-- The cursor's wash, under the icon: lit by its colour, at once, while the
-- cursor is on the panel (the frame of light fades the rest).
function Luxe:HoverWash()
	local t = self.tint or NEUTRAL
	self.hoverWash:SetVertexColor(t[1], t[2], t[3], self.hovered and 0.11 or 0)
end

function Luxe:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	self:HoverWash()
	local anim = self.hoverAnim
	local from = self.hoverFrame:GetAlpha()
	anim:Stop()
	anim.to = on and 1 or 0
	anim.fade:SetFromAlpha(from)
	anim.fade:SetToAlpha(anim.to)
	anim.fade:SetDuration(on and 0.12 or 0.18)
	anim:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the tag becomes the verdict, so the eye
-- never has to find the person again -- when there is a tag to carry it.
-- With one line, or no verdict word in this client's language, the name line
-- says it the built-in looks' way ("buffed Anna", translated).
function Luxe:PaintOutcome(kind, lead, sub, who, stamp)
	local kit = self.kit
	local o = OUTCOME[kind] or OUTCOME.cast
	local tag = kit.sub:IsShown()
	local word
	if kind == "failed" then
		word = (sub and sub ~= "" and sub) or (Known("could not buff") and L["could not buff"])
	elseif kind == "sent" then
		-- No fallback: the built-in sub is a sentence, not a tag.
		word = Known("sent, unconfirmed") and L["sent, unconfirmed"]
	else
		-- The built-in sub is translated and short ("the game confirmed it"):
		-- under a tick it says the same.
		word = (Known("buffed") and L["buffed"]) or (sub and sub ~= "" and sub)
	end
	local stays = tag and who and word
	kit.SetLine(kit.name, stays and who or lead)
	self:Tint(o[1], o[2], o[3], true)
	kit.icon:SetDesaturated(kind == "failed" or self.combat or false)
	self.glyph:SetTexture(ART .. (kind == "failed" and "Cross" or "Check"))
	self.glyphOn = kind ~= "sent"
	if tag then
		-- With the verdict on the name line, the tag holds what the built-in
		-- looks' second line would (nothing for a sent cast, whose sentence
		-- would fill the tag end to end).
		kit.SetLine(kit.sub, stays and word or (kind ~= "sent" and sub) or "")
		local dropped = self.dropped
		self.verdict = kit.sub:GetText()
		self:Fitted(kit.sub)
		-- The verdict would not fit the tag even at its smallest: the name
		-- line says it instead.
		if stays and (dropped or self.dropped) then kit.SetLine(kit.name, lead) end
	end
	-- The wash, once per click: a repaint during the outcome leaves it be.
	-- None for a cast nobody confirmed, which claims nothing: its words say it.
	if stamp ~= self.washFor then
		self.washFor = stamp
		self.resultAnim:Stop()
		if kind == "sent" then
			self.resultFrame:SetAlpha(0)
		else
			SliceColor(self.result, o[1], o[2], o[3], RESULT_LIGHT)
			self.resultFrame:SetAlpha(1)
			if kit.FullEffects() then
				self.resultAnim.to = 0
				self.resultAnim:Play()
			end
		end
	end
end

function Luxe:ClearOutcome()
	if not self.washFor then return end
	self.washFor = nil
	self.resultAnim:Stop()
	self.resultFrame:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

function Luxe:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	if self.trayShown ~= list or (list and self.above ~= above) then
		self.trayShown, self.above = list, above
		SliceShown(self.tray, list)
		SliceShown(self.trayBevel, list)
		SliceShown(self.trayEdge, list and self.both or false)
		-- The shadow falls under both.
		if not list then
			PlaceSlice(self.shadow, art, art, 12, 9, 12, 15)
		elseif above then
			PlaceSlice(self.shadow, self.trayBox, art, 12, 9, 12, 15)
		else
			PlaceSlice(self.shadow, art, self.trayBox, 12, 9, 12, 15)
		end
	end
	for i, dot in ipairs(self.dots) do
		if not (list and i <= shown) then dot:Hide() end
	end
	if not list then return end

	local pitch = self.pitch
	local height = 8 + shown * pitch
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second. The gradient is Apply's.
	local placed = self.trayHeight == height and self.trayAt == above
	if not placed then
		self.trayHeight, self.trayAt = height, above
		self.trayBox:ClearAllPoints()
		if above then
			self.trayBox:SetPoint("BOTTOMLEFT", art, "TOPLEFT", 0, 3)
			self.trayBox:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, 3)
		else
			self.trayBox:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, -3)
			self.trayBox:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, -3)
		end
		self.trayBox:SetHeight(height)
	end

	local dotX = SPINE_X + self.spineW / 2
	for i = 1, shown do
		local dot = self.dots[i]
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		dot:SetVertexColor(c[1], c[2], c[3], 0.95)
		dot:Show()
	end
	if placed then return end
	for i = 1, shown do
		local fs, dot = kit.rows[i], self.dots[i]
		-- Row centres, counted from the card's edge the tray hangs off.
		local y = 3 + 4 + (i - 1) * pitch + pitch / 2
		local edge = "BOTTOMLEFT"
		if above then
			y = 3 + height - 4 - (i - 1) * pitch - pitch / 2
			edge = "TOPLEFT"
		else
			y = -y
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, edge, self.iconX, y)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", art, edge, dotX, y)
		dot:SetSize(7, 7)
	end
end
