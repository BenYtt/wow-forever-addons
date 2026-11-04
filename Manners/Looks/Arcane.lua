-- Manners -- the Arcane look: a card of smoked glass whose rim is lit in the
-- reason colour, so the whole outline says why.
--
-- On the left the spell icon sits in a lens -- a dark well, a seam, a ring
-- lit from above -- inside a circle of runes. Along the bottom a hairline
-- drains as the time to return a favour runs out, and a keycap on the right
-- shows the key that presses the prompt. The rune circle turns once every two
-- minutes on Full; everything else moves only when something happens.
--
-- Two rules the game holds this look to, which a preview render does not
-- show (it lays added light on far more gently than the game):
--   * the spell icon is drawn clean: nothing rests on it -- no gloss, shade,
--     light or count -- only the ring hugging its edge, and a flourish that
--     crosses the card starts right of it;
--   * the text has a dark ground: a second coat of smoke under the lines
--     (Smoke) keeps the name and the reason line at 4.5:1 over snow, in a
--     fight too, where the text dims and the reason line comes up to meet
--     it (FIGHT_LEAST); and no light or wash lies under them
--     (tests/scenarios/readable-arcane.lua).
--
-- Every region is a texture from Textures/Arcane (tools/make_arcane_textures.py),
-- white, grey or black, so the vertex colour carries every reason, both
-- palettes, a custom marker colour and the outcomes. The interface this file
-- implements is described at the top of Looks/Looks.lua.
--
-- Where it departs from the approved design, on the judges' word:
--   * nothing runs per frame: the rune circle is one Rotation animation that
--     stops on Calm and in a fight, and the drain is set on the scan's own
--     tick (Clock, from Chip) rather than by a screen-long Scale and
--     Translation pair;
--   * in a fight the card holds and the reason survives: the rim, the ring
--     and the runes keep its colour while the icon greys and the light goes,
--     where the design dimmed the whole panel and left a faint rim;
--   * the outcome is a verdict on the second line, as on Luxe: the name stays
--     where it was, so the eye never has to find the person again (with no
--     second line, the name line says it); a landed buff turns the rim green
--     as a refusal turns it red;
--   * a square icon sits in a square of runes that does not turn, where the
--     design put it in the round circle and its frame covered the corners;
--   * the icon follows the icon size setting and the circle is sized round
--     it, where the design sized the icon from the circle and the top of the
--     slider did nothing;
--   * on a light or mid panel the runes, the clock and the wash are laid over
--     the glass in a deeper shade of the reason instead of added to it;
--   * no four-point sparkles (clip-art, and busy on every arrival); a new
--     favour is a flare of the bloom, the rim and the runes, and light
--     crossing once;
--   * the owed breath is a slow 2.4 s, only while somebody owed is on top, and
--     it follows the arrival flare instead of fighting it;
--   * the look does not change the player's defaults: "Colour the marker"
--     works as it does everywhere -- the rim is this look's stripe and always
--     carries the reason unless the marker is off; the ring and the runes are
--     its icon marker -- and "Round icon" is the player's own;
--   * a class-coloured name is taken 55% of the way to white, as on Luxe, so
--     a rogue's yellow never reads as the owed gold on the rim; the preview's
--     and the hints' gold is taken off the name, which is white;
--   * about thirty fewer regions: the list shares the card's shadow, and the
--     flare, the breath and the hover share their light;
--   * since 1.5.1 the lens has no highlight or shade over the icon, the glass
--     no frost and no light from the icon, the cursor lights the rim only, an
--     outcome's wash lights the lens rather than the glass under the verdict,
--     and the count stands at the right of the lines, never on the icon.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Arcane\\Arcane_"
local COMMAND = "CLICK MannersPrompt:LeftButton"

local Arcane = ns.Looks.Register("arcane", {
	name = L["Arcane -- smoked glass, a rim lit by the reason"],
	title = L["Arcane"],
	description = L["smoked glass, a rim lit by the reason"],
	order = 3,
	-- The glass holds in a fight; the ink dims itself (Combat).
	combatArtAlpha = 1,
	classSoften = 0.55,
})

-- The reason with the marker off.
local NEUTRAL = { 0.72, 0.74, 0.82 }
-- The outcomes: their colour and how strong their wash round the lens is.
local OUTCOME = {
	cast = { 0.55, 0.91, 0.55, 0.60 },
	failed = { 0.93, 0.33, 0.28, 0.44 },
	sent = { 0.91, 0.86, 0.60, 0.28 },
}
-- The resting light for each reason: the bloom and the runes. A favour owed
-- glows a little more; a passer-by least.
local REST = {
	owed = { 0.22, 0.42 },
	target = { 0.16, 0.38 },
	asked = { 0.18, 0.40 },
	group = { 0.16, 0.38 },
	self = { 0.16, 0.38 },
	nearby = { 0.10, 0.30 },
}
-- The second coat of smoke under the lines, as a share of the panel's own
-- opacity: at the default 88% the name and the reason line keep 4.5:1 over
-- snow. Only under light text; a light panel keeps its own colour.
local SMOKE = 1
-- The gold the preview and the hints put on the name line, taken off it.
local GOLD = "|c[fF][fF][fF][fF][dD]100"
-- The runes rest at this alpha so a flare has somewhere to go; their colour's
-- alpha is the resting light over it.
local RUNE_ALPHA = 0.6
-- What a fight does to the ink: the icon and its lens, the text, the runes,
-- the drain.
local COMBAT = { ink = 0.62, text = 0.80, runes = 0.35, drain = 0.60 }
-- The contrast the reason line is held to in a fight, before the text dims:
-- dimmed to COMBAT.text it still reads at 4.5:1 on the dark glass.
local FIGHT_LEAST = 4.5 / (COMBAT.text * COMBAT.text)
-- How much deeper the reason is drawn on a light panel, where it is laid
-- over rather than added.
local DEEP = 0.7
-- An icon frame texture holds the icon in its middle 96 of 128 texels.
local ICON_FRAME = 0.75
-- The icon's share of the rune circle at which its frame just clears the
-- inner runes (RuneRing's and RuneRingSq's inner hairlines).
local ICON_FIT = 0.69

function Arcane.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false, mode ~= "off"
end

local function Mix(r, g, b, t)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

---------------------------------------------------------------------------
-- slices
---------------------------------------------------------------------------

-- Nine textures cut from one file, `margin` texels into a `size`-texel file,
-- drawn with corners `corner` units square (Apply may shrink them).
local function NineSlice(parent, layer, sublevel, file, size, margin, corner, blend)
	local s = { corner = corner, full = corner }
	local u = margin / size
	local cuts = { 0, u, 1 - u, 1 }
	for row = 1, 3 do
		for col = 1, 3 do
			local t = parent:CreateTexture(nil, layer, nil, sublevel)
			t:SetTexture(ART .. file)
			t:SetTexCoord(cuts[col], cuts[col + 1], cuts[row], cuts[row + 1])
			if blend then t:SetBlendMode(blend) end
			s[#s + 1] = t
		end
	end
	return s
end

-- Placed round a box, `l t r b` units outside it (negative: inside). The top
-- row hangs from `top`, the bottom row from `bottom`: the same region unless
-- the slice spans two (the shadow under the card and its list).
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

local function SliceAlpha(s, a)
	for _, tex in ipairs(s) do tex:SetAlpha(a) end
end

-- A one-shot fade on a frame or a texture, parked where it ends.
local function Fade(region, to, duration, smoothing)
	local group = region:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetDuration(duration)
	if smoothing and fade.SetSmoothing then fade:SetSmoothing(smoothing) end
	group.fade = fade
	group:SetScript("OnFinished", function() region:SetAlpha(group.to or to or 0) end)
	return group
end

-- Whether this client reads an English string in its own language: the
-- verdict words are new, and a German player is better served by the lines
-- that are translated than by English in a German panel.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

-- The key as a keycap says it: modifiers to a letter, long names cut down,
-- each through L so a German keycap can say what a German keyboard does. Made
-- when the binding changes, never per paint.
local function KeyWords()
	return {
		SHIFT = L["S"], CTRL = L["C"], ALT = L["A"], META = L["M"],
		BUTTON3 = L["M3"], BUTTON4 = L["M4"], BUTTON5 = L["M5"],
		MOUSEWHEELUP = L["MwU"], MOUSEWHEELDOWN = L["MwD"],
		SPACE = L["Spc"], ESCAPE = L["Esc"], BACKSPACE = L["BkSp"], ENTER = L["Ent"], TAB = L["Tab"],
		CAPSLOCK = L["Caps"], INSERT = L["Ins"], DELETE = L["Del"], HOME = L["Hm"], END = L["End"],
		PAGEUP = L["PgU"], PAGEDOWN = L["PgD"], UP = L["Up"], DOWN = L["Dn"], LEFT = L["Lt"],
		RIGHT = L["Rt"],
	}
end

-- The client's own short form first -- what the player's action bars print,
-- in their language -- and ours where it gives none.
local function KeyLabel(key)
	if type(key) ~= "string" or key == "" then return nil end
	if type(GetBindingText) == "function" then
		local text = ns.Looks.ShortKey(key)
		if type(text) == "string" and text ~= "" then return text end
	end
	local parts = {}
	-- The last part is the key; a lone "-" is the minus key itself.
	for part in key:gmatch("[^%-]+") do parts[#parts + 1] = part end
	if key:sub(-1) == "-" then parts[#parts + 1] = "-" end
	if #parts == 0 then return nil end
	local words = KeyWords()
	for i, part in ipairs(parts) do
		parts[i] = words[part] or part:gsub("^NUMPAD", "N")
	end
	return table.concat(parts, "-")
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Arcane:Build(kit)
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
	local function slice(parent, layer, sublevel, file, size, margin, corner, blend)
		local s = NineSlice(parent, layer, sublevel, file, size, margin, corner, blend)
		for _, t in ipairs(s) do keep(t) end
		return s
	end
	local function frame(parent)
		local f = keep(CreateFrame("Frame", nil, parent))
		f:SetAlpha(0)
		return f
	end

	-- The ground, on art itself: a frame of its own would draw over the
	-- list's rows and the icon, which are art's. Bottom to top: the shadow
	-- under the card and its list, the list's glass tucked under the card,
	-- the bloom round the card, the glass.
	self.shadow = slice(art, "BACKGROUND", -8, "Shadow", 128, 32, 16)
	self.trayBox = keep(CreateFrame("Frame", nil, art))
	self.trayGlass = slice(art, "BACKGROUND", -7, "Glass", 128, 32, 8)
	self.trayRim = slice(art, "BACKGROUND", -6, "Rim", 128, 32, 8)
	self.bloom = slice(art, "BACKGROUND", -5, "Bloom", 128, 32, 16, "ADD")
	self.glass = slice(art, "BACKGROUND", -4, "Glass", 128, 32, 8)
	-- In the glass: the second coat of smoke, the top edge, the rim, an
	-- outcome's wash round the lens, and the lens's well and runes (below
	-- the icon, which is on ARTWORK).
	self.smoke = slice(art, "BORDER", 1, "Glass", 128, 32, 8)
	self.glint = tex(art, "BORDER", 2, "Glint", "ADD")
	self.rim = slice(art, "BORDER", 3, "Rim", 128, 32, 8)
	self.wash = tex(art, "BORDER", 4, "Dot", "ADD")
	self.well = tex(art, "BORDER", 5, "Well")
	self.runes = tex(art, "BORDER", 6, "RuneRing", "ADD")
	-- Turned and slid without shimmering, where the client offers it.
	if self.runes.SetSnapToPixelGrid then self.runes:SetSnapToPixelGrid(false) end
	if self.runes.SetTexelSnappingBias then self.runes:SetTexelSnappingBias(0) end
	self.track = tex(art, "ARTWORK", 0, "Drain", "ADD")
	self.drain = tex(art, "ARTWORK", 1, "Drain", "ADD")
	self.spark = tex(art, "ARTWORK", 2, "Spark", "ADD")
	-- Over the icon (the shared icon is ARTWORK 0) only its frame, which
	-- hugs it from outside, and the tick for a buff that landed.
	self.ring = tex(art, "ARTWORK", 3, "IconRing")
	self.check = tex(art, "ARTWORK", 4, "Check")
	self.dots = {}
	for i = 1, #kit.rows do self.dots[i] = tex(art, "ARTWORK", 1, "Dot") end
	self.glassParts = {}
	for _, s in ipairs({ self.shadow, self.glass, self.rim }) do
		for _, t in ipairs(s) do self.glassParts[#self.glassParts + 1] = t end
	end

	-- The icon's shape. Not in `own`: Hide takes it off.
	self.mask = art:CreateMaskTexture()

	-- What lights up, each on a frame of its own: only a frame's alpha can
	-- be animated as one. The lift is the bloom and the rim again, added: a
	-- new favour flares it, the owed breath swells it, and it never loops on
	-- Calm. It is hollow and on the edge, so it covers nothing it is over;
	-- so is the cursor's light, the rim alone.
	self.liftFrame = frame(art)
	self.liftBloom = slice(self.liftFrame, "BACKGROUND", 0, "Bloom", 128, 32, 16, "ADD")
	self.liftRim = slice(self.liftFrame, "BORDER", 0, "Rim", 128, 32, 8, "ADD")
	-- The second tone of the owed breath: a warm white ring on the lens's own,
	-- in the lift's frame so it breathes with it. Outside the icon, like the
	-- ring it lights.
	self.warmRing = tex(self.liftFrame, "OVERLAY", 1, "IconRing", "ADD")
	self.hoverFrame = frame(art)
	self.hoverRim = slice(self.hoverFrame, "BORDER", 1, "Rim", 128, 32, 8, "ADD")
	self.shineFrame = frame(art)
	self.shine = tex(self.shineFrame, "OVERLAY", 0, "Shine", "ADD")
	-- The rings that spread when a buff lands -- the lens's ring, then the
	-- circle of runes after it -- and the one that snaps in on a refusal. No
	-- echo of the icon: the spell is drawn clean.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do keep(f) end
	-- Where each ring file is brightest and how far out it is seen, for how
	-- far the rings may spread (measured from the files: hunt37-effects).
	kit.RingArt(ART .. "IconRing", 0.758, 0.98)
	kit.RingArt(ART .. "IconRingSq", 0.758, 0.98)
	kit.RingArt(ART .. "RuneRing", 0.957, 1.0)
	kit.RingArt(ART .. "RuneRingSq", 0.785, 1.0)

	-- On textLayer, over everything and dimmed with the text: the count's
	-- coin, the keycap and its key.
	self.badgeBox = keep(CreateFrame("Frame", nil, textLayer))
	self.badge = {}
	for i, cut in ipairs({ { 0, 0.5 }, { 0.49, 0.51 }, { 0.5, 1 } }) do
		local t = tex(textLayer, "ARTWORK", 0, "Badge")
		t:SetTexCoord(cut[1], cut[2], 0, 1)
		self.badge[i] = t
	end
	self.keyBox = keep(CreateFrame("Frame", nil, textLayer))
	self.keycap = slice(textLayer, "ARTWORK", 0, "Keycap", 64, 16, 3)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	if self.keyText.SetJustifyH then self.keyText:SetJustifyH("CENTER") end
	PlaceSlice(self.keycap, self.keyBox, self.keyBox, 0, 0, 0, 0)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)

	local base = art:GetFrameLevel()
	self.liftFrame:SetFrameLevel(base + 1)
	self.hoverFrame:SetFrameLevel(base + 1)
	self.shineFrame:SetFrameLevel(base + 2)
	for _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end

	self:BuildAnimations()
end

function Arcane:BuildAnimations()
	-- A new favour: the lift up quickly and down slowly. The peak is set for
	-- each play (Calm's is lower). The breath follows it, never with it: two
	-- groups on one alpha fight.
	local flare = self.liftFrame:CreateAnimationGroup()
	local up = flare:CreateAnimation("Alpha")
	up:SetFromAlpha(0)
	up:SetDuration(0.15)
	up:SetOrder(1)
	if up.SetSmoothing then up:SetSmoothing("OUT") end
	local down = flare:CreateAnimation("Alpha")
	down:SetToAlpha(0)
	down:SetDuration(0.95)
	down:SetOrder(2)
	if down.SetSmoothing then down:SetSmoothing("OUT") end
	flare.up, flare.down = up, down
	flare:SetScript("OnFinished", function()
		self.liftFrame:SetAlpha(0)
		if self.breathe then self:Breathe() end
	end)
	self.flareAnim = flare

	-- The owed breath: slow and faint, so the only loop never reads as a
	-- flash. 1.3 s each way, 2.6 s round.
	local pulse = self.liftFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local swell = pulse:CreateAnimation("Alpha")
	swell:SetFromAlpha(0)
	swell:SetToAlpha(0.22)
	swell:SetDuration(1.3)
	if swell.SetSmoothing then swell:SetSmoothing("IN_OUT") end
	self.pulseAnim = pulse

	local spin = self.runes:CreateAnimationGroup()
	spin:SetLooping("REPEAT")
	local turn = spin:CreateAnimation("Rotation")
	if turn.SetDegrees then turn:SetDegrees(-360) end
	if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
	turn:SetDuration(120)
	self.spinAnim = spin

	local runeFlare = self.runes:CreateAnimationGroup()
	local bright = runeFlare:CreateAnimation("Alpha")
	bright:SetFromAlpha(1)
	bright:SetToAlpha(RUNE_ALPHA)
	bright:SetDuration(0.55)
	if bright.SetSmoothing then bright:SetSmoothing("OUT") end
	local grow = runeFlare:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.86, 0.86) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin("CENTER", 0, 0) end
	grow:SetDuration(0.45)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	self.runeFlareAnim = runeFlare

	local shine = self.shineFrame:CreateAnimationGroup()
	local sIn = shine:CreateAnimation("Alpha")
	sIn:SetFromAlpha(0)
	sIn:SetToAlpha(1)
	sIn:SetDuration(0.10)
	sIn:SetOrder(1)
	local move = shine:CreateAnimation("Translation")
	move:SetDuration(0.5)
	move:SetOrder(2)
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	local sOut = shine:CreateAnimation("Alpha")
	sOut:SetFromAlpha(1)
	sOut:SetToAlpha(0)
	sOut:SetDuration(0.3)
	if sOut.SetStartDelay then sOut:SetStartDelay(0.2) end
	sOut:SetOrder(2)
	shine.move = move
	shine:SetScript("OnFinished", function() self.shineFrame:SetAlpha(0) end)
	shine:SetScript("OnStop", function() self.shineFrame:SetAlpha(0) end)
	self.shineAnim = shine

	-- A favour arriving: the lens's ring locks onto the icon, from wider and
	-- faint, past and back, in a quarter of a second.
	local lock = self.ring:CreateAnimationGroup()
	local lockFade = lock:CreateAnimation("Alpha")
	lockFade:SetFromAlpha(0.25)
	lockFade:SetToAlpha(1)
	lockFade:SetDuration(0.12)
	lockFade:SetOrder(1)
	local lockIn = lock:CreateAnimation("Scale")
	if lockIn.SetScaleFrom then lockIn:SetScaleFrom(1.22, 1.22) end
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

	self.checkAnim = Fade(self.check, 1, 0.12, "OUT")
	self.checkAnim.fade:SetFromAlpha(0)
	self.checkAnim.fade:SetToAlpha(1)
	-- The wash holds for the first two fifths, so an outcome is seen from the
	-- corner of the eye, and fades over the rest.
	local seconds = self.kit.OUTCOME_SECONDS
	self.washAnim = Fade(self.wash, 0, seconds * 0.6, "OUT")
	if self.washAnim.fade.SetStartDelay then self.washAnim.fade:SetStartDelay(seconds * 0.4) end
	self.washAnim.fade:SetFromAlpha(1)
	self.washAnim.fade:SetToAlpha(0)
	-- The cursor's light, both ways; from and to are set for each play.
	self.hoverAnim = Fade(self.hoverFrame, 0, 0.12, "OUT")
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Arcane:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local c = p.bgColor or {}
	local br, bg, bb, ba = c[1] or 0.04, c[2] or 0.04, c[3] or 0.06, c[4] == nil and 0.88 or c[4]
	local showIcon = p.showIcon and true or false
	local round = p.roundIcon and true or false

	-- The lens: the rune circle wants the icon at 0.69 of it and 3-5 units above
	-- and below. An icon asked bigger than that room holds still grows with the
	-- slider, a third as fast, the circle taking a unit a side of its room: a
	-- bigger icon covers the inner runes rather than the slider going dead.
	local margin = math.max(3, math.min(5, math.floor(H / 11)))
	local asked = math.max(8, math.min(p.iconSize, H - 8))
	local M = math.max(12, math.min(H - 2 * margin, asked * 1.45))
	local fits = M * ICON_FIT
	local iconSize = asked
	if asked > fits then
		iconSize = fits + (asked - fits) * 0.35
		M = math.max(M, math.min(H - 2 * margin + 2, iconSize / ICON_FIT))
	end
	iconSize = math.max(8, math.floor(iconSize + 0.5))
	local gap = math.max(3, math.min((H - M) / 2, 7))
	local cx = gap + M / 2
	local textX = showIcon and math.floor(cx + M / 2 + 6 + 0.5) or 12
	local sub = math.max(7, fs - 3)
	local lineGap = math.max(2, math.floor(fs * 0.22 + 0.5))
	local top = (H - (fs + lineGap + sub)) / 2
	self.p, self.W, self.H, self.above = p, W, H, above
	self.cx, self.M, self.iconSize, self.textX, self.sub = cx, M, iconSize, textX, sub
	-- The two lines as one block, centred: offsets from the middle, up positive.
	self.nameY = H / 2 - (top + fs / 2)
	self.subY = H / 2 - (top + fs + lineGap + sub / 2)
	self.badgeH = sub + 5
	self.keySize = math.max(8, fs - 3)
	self.keyH = self.keySize + 7
	self.pitch = sub + 8
	self.showIcon = showIcon

	local corner = math.min(8, H / 2)
	for _, s in ipairs({ self.glass, self.smoke, self.rim, self.liftRim, self.hoverRim }) do s.corner = corner end
	for _, s in ipairs({ self.trayGlass, self.trayRim }) do s.corner = 8 end

	-- The ground. Nearly clear glass has no shadow: a grey smudge would float
	-- under nothing.
	SliceColor(self.shadow, 0, 0, 0, 0.62 * math.min(1, ba + 0.1))
	PlaceSlice(self.shadow, art, art, 10, 7, 10, 13)
	self.shadowShown = ba >= 0.2
	PlaceSlice(self.bloom, art, art, 10, 10, 10, 10)
	PlaceSlice(self.liftBloom, art, art, 10, 10, 10, 10)
	SliceColor(self.glass, br, bg, bb, ba)
	PlaceSlice(self.glass, art, art, 0, 0, 0, 0)
	-- The smoke's strength waits for the text's colour (Styled).
	for _, s in ipairs({ self.smoke, self.rim, self.liftRim, self.hoverRim }) do PlaceSlice(s, art, art, 0, 0, 0, 0) end
	SliceColor(self.smoke, 0, 0, 0, 0)
	self.smokeAlpha = SMOKE * ba
	-- The top edge's light fades on a light panel, where added white only
	-- greys it.
	local lum = 0.299 * br + 0.587 * bg + 0.114 * bb
	local clear = math.max(0, 1 - lum * 1.3)
	-- The same for what carries the reason in light: added to a light or mid
	-- panel the reason colour only whitens it, so there the runes, the clock
	-- and the wash are laid over in a deeper shade of it instead (Tint).
	self.lightGlass = clear < 0.55
	local blend = self.lightGlass and "BLEND" or "ADD"
	for _, t in ipairs({ self.runes, self.track, self.drain, self.spark, self.wash }) do
		t:SetBlendMode(blend)
	end
	self.glint:ClearAllPoints()
	self.glint:SetPoint("TOPLEFT", 6, -0.6)
	self.glint:SetPoint("TOPRIGHT", -6, -0.6)
	self.glint:SetHeight(2)
	self.glint:SetVertexColor(1, 1, 1, 0.30 * clear)
	SliceColor(self.trayGlass, br, bg, bb, ba * 0.92)
	SliceColor(self.trayRim, 0.75, 0.78, 0.90, 0.18)

	local cy = 0
	-- A square icon has a circle of its own shape: a round one round it is
	-- covered at the four corners by the icon's frame.
	self.runes:SetTexture(ART .. (round and "RuneRing" or "RuneRingSq"))
	self.round = round
	for _, t in ipairs({ self.well, self.runes }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "LEFT", cx, cy)
		t:SetSize(M, M)
	end
	self.well:SetVertexColor(1, 1, 1, 0.40)
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	local maskFile = ART .. (round and "CircleMask" or "SquircleMask")
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	self.ring:SetTexture(ART .. (round and "IconRing" or "IconRingSq"))
	self.warmRing:SetTexture(ART .. (round and "IconRing" or "IconRingSq"))
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "LEFT", cx, cy)
	for _, t in ipairs({ self.ring, self.warmRing }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", icon, "CENTER", 0, 0)
		t:SetSize(iconSize / ICON_FRAME, iconSize / ICON_FRAME)
	end
	-- The rings that spread: the lens's ring first, and the circle of runes
	-- after it, a size up.
	local w = kit.WARM_WHITE
	self.warmRing:SetVertexColor(w[1], w[2], w[3], 1)
	self.fx:Place(icon, (iconSize / ICON_FRAME - iconSize) / 2, iconSize)
	self.fx:Shape(round, ART .. "IconRing", ART .. "IconRingSq")
	local runeRing = self.fx.rings[2]
	self.fx:SetArt(2, ART .. (round and "RuneRing" or "RuneRingSq"))
	runeRing.half = M / 2
	runeRing.frame:ClearAllPoints()
	runeRing.frame:SetPoint("TOPLEFT", icon, "TOPLEFT", -(M - iconSize) / 2, (M - iconSize) / 2)
	runeRing.frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", (M - iconSize) / 2, -(M - iconSize) / 2)
	-- How far they may spread: to the text (less a margin), to the card's left
	-- edge and to its top and bottom edges. The ring that locks onto the icon
	-- is held to the same room.
	local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
	local limitV = H / 2 - kit.EDGE_MARGIN
	self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
	kit.CapLock(self.lockIn, self.lockSettle, 1.22, 0.97,
		kit.CapScale(math.min(limitH, limitV), iconSize / ICON_FRAME / 2, 0.98))
	self.check:ClearAllPoints()
	self.check:SetPoint("CENTER", icon, "CENTER", 0, 0)
	self.check:SetSize(iconSize * 0.86, iconSize * 0.86)
	self.check:SetVertexColor(0.80, 1.00, 0.82, 1)
	-- An outcome's wash lights the lens round the icon, under it, and stops
	-- short of the text: the verdict is written on the glass beside it.
	self.wash:ClearAllPoints()
	self.wash:SetPoint("CENTER", art, "LEFT", cx, cy)
	self.wash:SetSize(M + 10, M + 10)
	local cooldown = kit.cooldown
	if cooldown then
		cooldown:ClearAllPoints()
		cooldown:SetAllPoints(icon)
		-- The mask doubles as the swipe, so the sweep has the icon's shape.
		if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
		if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
	end

	local drainX = textX - 2
	self.drainFull = math.max(8, W - 9 - drainX)
	for _, t in ipairs({ self.track, self.drain }) do
		t:ClearAllPoints()
		t:SetPoint("LEFT", art, "BOTTOMLEFT", drainX, 3.4)
		t:SetHeight(4)
	end
	self.track:SetWidth(self.drainFull)
	self.drain:SetWidth(self.drainFull)
	self.spark:ClearAllPoints()
	self.spark:SetPoint("CENTER", self.drain, "RIGHT", 0, 0)
	self.spark:SetSize(10, 5)
	self.drainWidth = nil

	-- The light that crosses: about a fifth of the card wide, from the lens's
	-- edge, so it never passes over the icon.
	local band = math.max(16, math.min(48, math.floor(W * 0.18)))
	local from = showIcon and math.floor(cx + M / 2 + 0.5) or 0
	self.shineFrame:ClearAllPoints()
	self.shineFrame:SetPoint("LEFT", art, "LEFT", from, 0)
	self.shineFrame:SetSize(band, H - 2)
	self.shine:ClearAllPoints()
	self.shine:SetAllPoints(self.shineFrame)
	self.shineAnim.move:SetOffset(math.max(0, W - band - from), 0)
	for _, f in ipairs({ self.liftFrame, self.hoverFrame }) do
		f:ClearAllPoints()
		f:SetAllPoints(art)
	end

	local base = art:GetFrameLevel()
	kit.textLayer:SetFrameLevel(base + 4)
	self.badgeBox:ClearAllPoints()
	self.badgeBox:SetSize(self.badgeH, self.badgeH)
	for _, t in ipairs(self.badge) do t:ClearAllPoints() end
	self.badge[1]:SetPoint("TOPLEFT", self.badgeBox, "TOPLEFT", 0, 0)
	self.badge[1]:SetPoint("BOTTOMLEFT", self.badgeBox, "BOTTOMLEFT", 0, 0)
	self.badge[1]:SetWidth(self.badgeH / 2)
	self.badge[3]:SetPoint("TOPRIGHT", self.badgeBox, "TOPRIGHT", 0, 0)
	self.badge[3]:SetPoint("BOTTOMRIGHT", self.badgeBox, "BOTTOMRIGHT", 0, 0)
	self.badge[3]:SetWidth(self.badgeH / 2)
	self.badge[2]:SetPoint("TOPLEFT", self.badge[1], "TOPRIGHT", 0, 0)
	self.badge[2]:SetPoint("BOTTOMRIGHT", self.badge[3], "BOTTOMLEFT", 0, 0)
	kit.count:ClearAllPoints()
	kit.count:SetPoint("CENTER", self.badgeBox, "CENTER", 0, 0)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", kit.textLayer, "RIGHT", -8, 0)
	self.keyBox:SetSize(self.keyH, self.keyH)
	self.keycap.corner = 3
	PlaceSlice(self.keycap, self.keyBox, self.keyBox, 0, 0, 0, 0)
	SliceColor(self.keycap, 1, 1, 1, 0.85)

	-- The list's rows start at the text and their bead a little left of it,
	-- both inside the list's glass (5 units in) when the icon is off.
	self.dotX = math.max(textX - 8, 12)
	self.rowX = math.max(textX, self.dotX + 8)
	local rowWidth = math.max(20, W - self.rowX - 14)
	for _, fs in ipairs(kit.rows) do
		fs:SetWidth(rowWidth)
		fit.room[fs] = rowWidth
	end

	-- Everything shown, then what waits: the list for PaintQueue, the clock
	-- for Chip, the tick and the wash for an outcome, the badge for a
	-- count, the keycap for a key.
	for _, x in ipairs(self.own) do x:Show() end
	SliceShown(self.shadow, self.shadowShown)
	for _, s in ipairs({ self.trayGlass, self.trayRim }) do SliceShown(s, false) end
	for _, d in ipairs(self.dots) do d:Hide() end
	for _, t in ipairs({ self.well, self.runes, self.ring, self.warmRing }) do
		t:SetShown(showIcon)
	end
	self.fx:SetShown(showIcon)
	for _, t in ipairs({ self.track, self.drain, self.spark, self.check, self.wash }) do t:Hide() end
	self:ShowBadge(false)
	self.badgeUp = false
	self.trayShown, self.trayHeight = nil, nil
	self.combat, self.hovered, self.washFor, self.outcome = nil, nil, nil, nil
	self.breathe, self.lineRight, self.keyYield, self.boundKey = nil, nil, nil, nil
	self.drainLeft = nil
	-- Effects may have changed: whatever looped starts again from the next
	-- Attention, on Full only.
	self.pulseAnim:Stop()
	self.flareAnim:Stop()
	self.liftFrame:SetAlpha(0)
	self.keyLabel, self.keyRoom, self.keyOn = nil, 0, nil
	self:ShowKey()
	self:SetInk(false)
	self:Spin()

	-- The count stands at the right, never on the icon, and takes its room
	-- from the lines while it is up.
	-- Chip widens it for a longer count.
	local chipRoom = 10 + math.ceil(sub * 1.3 + 8) + 4
	self.roomBase = chipRoom
	return textX, chipRoom
end

function Arcane:Styled(p)
	local kit = self.kit
	local path = kit.fit.path or STANDARD_TEXT_FONT
	if not self.keyText:SetFont(path, self.keySize, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, self.keySize, "")
	end
	local r, g, b = kit.Legible(0.90, 0.91, 0.95, 4.5)
	self.keyText:SetTextColor(r, g, b, 1)
	-- A shadow under dark letters on a light panel only smudges them.
	self.keyText:SetShadowColor(0, 0, 0, kit.ink.light and 0.6 or 0)
	self.keyText:SetShadowOffset(kit.ink.light and 1 or 0, kit.ink.light and -1 or 0)
	-- The count sits on its badge, a dark pill of its own on any panel: light,
	-- whatever the panel's colour would make of it.
	kit.count:SetTextColor(0.95, 0.95, 0.98, 1)
	kit.count:SetShadowOffset(0, 0)
	r, g, b = kit.Legible(0.92, 0.92, 0.95, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	kit.ink.rowReason = kit.ink.light and "|cff9a9cb0" or "|cff505058"
	-- Light text gets its dark ground: the second coat of smoke. Dark text on
	-- a light panel keeps the panel as the player coloured it.
	SliceColor(self.smoke, 0, 0, 0, kit.ink.light and self.smokeAlpha or 0)
	-- The key, now there is a font to measure it in, and the count measured
	-- again in it (Chip) the next time it is shown.
	self:ReadKey(true)
	self.countText = nil
end

function Arcane:Hide()
	local kit = self.kit
	if not kit then return end
	for _, x in ipairs(self.own) do x:Hide() end
	for _, anim in ipairs({ self.flareAnim, self.pulseAnim, self.spinAnim, self.runeFlareAnim,
		self.shineAnim, self.checkAnim, self.washAnim, self.hoverAnim, self.lockAnim }) do
		anim:Stop()
	end
	self.fx:Stop()
	-- Stop parks nothing on a fade that has already finished, and the cursor
	-- leaves for the next look: put the rim's light out here, or it is lit
	-- when this look comes back.
	self.hoverFrame:SetAlpha(0)
	-- The shared regions, as the other looks expect to find them.
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetDesaturated(false)
	local cooldown = kit.cooldown
	if cooldown then
		cooldown:SetAlpha(1)
		if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	self.combat, self.hovered, self.washFor, self.outcome, self.trayShown = nil, nil, nil, nil, nil
	self.breathe = nil
end

---------------------------------------------------------------------------
-- the lines, the key and the count
---------------------------------------------------------------------------

function Arcane:KeyShown()
	return self.keyLabel ~= nil and not self.keyYield
end

-- `right` is Prompt's inset (more while a count at the right is up); the
-- keycap's room comes on top of it.
function Arcane:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	self.lineRight = right
	-- The count's and the keycap's room, never so much that the two points
	-- cross: the name keeps 20 units, and the room at the right gives way.
	local inset = math.min(right + (self:KeyShown() and self.keyRoom or 0), math.max(0, self.W - self.textX - 20))
	local room = math.max(20, self.W - self.textX - inset)
	name:ClearAllPoints()
	sub:ClearAllPoints()
	if fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -inset, self.nameY)
		sub:SetPoint("LEFT", self.textX, self.subY)
		sub:SetPoint("RIGHT", -inset, self.subY)
	else
		name:SetPoint("LEFT", self.textX, 0)
		name:SetPoint("RIGHT", -inset, 0)
	end
	fit.room[name], fit.room[sub] = room, room
end

-- The name wins: with the keycap up, would the name still be cut at the
-- smallest size FitLine draws it? Measured from the width at the size it has:
-- the one FitLine just took (this runs from Fitted, on every fit), measured
-- here only where it could not.
function Arcane:NameNeedsTheKeysRoom()
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = fit.drawn[name] or kit.TextWidth(name), fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return false end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	local room = self.W - self.textX - (self.lineRight or 10) - self.keyRoom
	return width * least / size > room + 0.5
end

-- The keycap up or down, and the lines given the room it leaves.
function Arcane:PlaceKey()
	local kit = self.kit
	self.placing = true
	self:ShowKey()
	if self.badgeUp then self:PlaceBadge() end
	if self.lineRight then
		self:PlaceLines(self.lineRight)
		kit.FitLine(kit.name)
		kit.FitLine(kit.sub)
	end
	self.placing = nil
end

function Arcane:CheckKey()
	if self.placing or not self.keyLabel then return end
	local yield = self:NameNeedsTheKeysRoom()
	if yield ~= (self.keyYield or false) then
		self.keyYield = yield
		self:PlaceKey()
	end
end

-- Whether a press does anything: Prompt arms the button with a macro for
-- whoever the panel names, and clears it when unlocked or when a fight left
-- nothing armed. Read, never set. The preview arms nothing and shows the key
-- anyway, to be styled.
function Arcane:Armed()
	if self.kit.button:GetAttribute("type1") then return true end
	return ns.Prompt ~= nil and ns.Prompt:InTest()
end

-- The keycap, only where pressing it casts something: a key bound, no outcome
-- over it, the button armed. Asked on every paint; drawn only on a change.
function Arcane:ShowKey()
	local on = self:KeyShown() and not self.outcome and self:Armed() and true or false
	if on == self.keyOn then return end
	self.keyOn = on
	SliceShown(self.keycap, on)
	self.keyText:SetShown(on)
end

-- The key that presses the prompt, read again when it may have changed: a
-- plain call, cheap enough for the scan's tick, so a rebinding shows without
-- an event of its own, and so do the client's words for the same key.
function Arcane:ReadKey(force)
	local key = type(GetBindingKey) == "function" and GetBindingKey(COMMAND) or nil
	if key == self.boundKey and not force then
		-- The same key, in other words: the client's glyphs change when a
		-- controller of another family is told apart, and a pad button's
		-- modifier when the player moves the CVars. Asked only where the
		-- client has the words, as the other looks ask at every repaint.
		if type(GetBindingText) ~= "function" or KeyLabel(key) == self.keyLabel then return end
	end
	self.boundKey = key
	local label = KeyLabel(key)
	self.keyLabel, self.keyYield = label, nil
	if label then
		self.keyText:SetText(label)
		local width = self.kit.TextWidth(self.keyText) or #label * self.keySize * 0.6
		local w = math.max(self.keyH, math.floor(width + 9 + 0.5))
		self.keyBox:SetSize(w, self.keyH)
		self.keyRoom = w + 5
	else
		self.keyText:SetText("")
		self.keyRoom = 0
	end
	self:PlaceKey()
	self:CheckKey()
end

function Arcane:Fitted(fs)
	if fs == self.kit.name then
		self:Whiten(fs)
		self:CheckKey()
	end
end

-- The name is white: the gold the preview and the hints put on it comes off,
-- leaving the name's own colour. Only where that gold was kept, which is on
-- dark glass (a light panel's is already darkened for it). The width is the
-- same, so the fit holds. A secret name has no codes of ours.
function Arcane:Whiten(fs)
	local text = fs:GetText()
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
	if text:find(GOLD) then fs:SetText((text:gsub(GOLD, ""))) end
end

function Arcane:ShowBadge(on)
	for _, t in ipairs(self.badge) do t:SetShown(on) end
end

-- The badge at the right: beside the keycap while that is up, at the edge
-- when not (the keycap steps aside once the name needs its room, and the badge
-- must follow it, or the lines, which stop short of the badge's own place,
-- would run under it).
function Arcane:PlaceBadge()
	local right = self:KeyShown() and (8 + self.keyRoom + 1) or 8
	self.badgeBox:ClearAllPoints()
	self.badgeBox:SetPoint("RIGHT", self.kit.textLayer, "RIGHT", -right, 0)
end

-- The count as "+N" on its coin at the right of the lines, clear of the icon
-- and of the keycap.
function Arcane:Chip(on)
	local kit = self.kit
	self:Clock()
	on = on and not self.outcome and true or false
	if on then
		local text = kit.count:GetText()
		if type(text) == "string" and text ~= "" and text:sub(1, 1) ~= "+" then
			kit.count:SetText("+" .. text)
		end
		-- Measured only when its words change (Styled forgets them with the
		-- font): every repaint shows the count, and a measure is a pcall.
		text = kit.count:GetText()
		if text ~= self.countText or not self.countW then
			self.countText = text
			self.countW = math.floor(math.max(self.badgeH, (kit.TextWidth(kit.count) or self.sub) + 8) + 0.5)
		end
		-- The room the lines keep for it is its width, the inset and a gap
		-- (never less than Apply's, a count of two digits), so the name does not
		-- run under a count of three digits. PlaceLines adds the keycap's.
		kit.fit.chipRoom = math.max(self.roomBase or 0, 10 + self.countW + 4)
		self.badgeBox:SetWidth(self.countW)
		self.badgeUp = true
		self:PlaceBadge()
	else
		self.badgeUp = false
	end
	self:ShowBadge(on)
	kit.count:SetShown(on)
	return on
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The ink's alpha, for the fight: the icon and its well, the runes, the
-- drain and the text dim; the glass, the rim and the ring hold.
function Arcane:SetInk(fight)
	local kit = self.kit
	local ink = fight and COMBAT.ink or 1
	for _, t in ipairs({ kit.icon, self.well }) do t:SetAlpha(ink) end
	if kit.cooldown then kit.cooldown:SetAlpha(ink) end
	self.runes:SetAlpha((fight and COMBAT.runes or 1) * RUNE_ALPHA)
	for _, t in ipairs({ self.track, self.drain, self.spark }) do t:SetAlpha(fight and COMBAT.drain or 1) end
	-- The bloom is the one light that goes: a glowing card says "live".
	SliceAlpha(self.bloom, fight and 0 or 1)
	kit.textLayer:SetAlpha(fight and COMBAT.text or 1)
end

-- Every mark in its colour: the rim (the stripe) and the ring and runes (the
-- icon marker), the bloom, the drain and the reason line.
function Arcane:Tint(r, g, b, ring, rest, neutral)
	local kit = self.kit
	local rimA = neutral and 0.55 or 0.80
	SliceColor(self.rim, r, g, b, rimA)
	SliceColor(self.bloom, r, g, b, neutral and 0.06 or rest[1])
	SliceColor(self.liftBloom, r, g, b, 1)
	SliceColor(self.liftRim, r, g, b, 0.6)
	SliceColor(self.hoverRim, r, g, b, 0.14)
	local lr, lg, lb = ring[1], ring[2], ring[3]
	self.ring:SetVertexColor(lr, lg, lb, 1)
	if self.lightGlass then
		-- Laid over a light panel (BLEND, Apply) in a deeper shade: added,
		-- the colour would only whiten it.
		local dr, dg, db = r * DEEP, g * DEEP, b * DEEP
		self.track:SetVertexColor(dr, dg, db, 0.22)
		self.drain:SetVertexColor(dr, dg, db, 0.95)
		self.spark:SetVertexColor(dr, dg, db, 0.9)
		-- The runes at their full resting strength: thin dark lines on a light
		-- panel are the faintest thing on it.
		self.runes:SetVertexColor(lr * DEEP, lg * DEEP, lb * DEEP, 1)
	else
		self.track:SetVertexColor(r, g, b, 0.10)
		self.drain:SetVertexColor(r, g, b, 0.85)
		local sr, sg, sb = Mix(r, g, b, 0.5)
		self.spark:SetVertexColor(sr, sg, sb, 0.9)
		self.runes:SetVertexColor(lr, lg, lb, math.min(1, rest[2] / RUNE_ALPHA))
	end
	self.tint = { r, g, b }
end

-- The reason line: a grey carried most of the way to the reason colour on
-- dark glass (a third of the way on a light panel, where the tint costs
-- contrast), held to 4.5:1 -- as it is drawn, so harder in a fight, where
-- the text dims: the reason keeps its hue and comes up to the dimming.
function Arcane:SubColor(r, g, b, plain)
	local kit = self.kit
	local base = kit.ink.sub or { 0.60, 0.61, 0.68 }
	local mix = plain and 0 or (kit.ink.light and 0.75 or 0.35)
	local sr, sg, sb = kit.Legible(base[1] + (r - base[1]) * mix, base[2] + (g - base[2]) * mix,
		base[3] + (b - base[3]) * mix, self.combat and FIGHT_LEAST or 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
end

-- Prompt skips this while the colour is the same, and with one marker colour
-- every reason is the same colour: so the reason's resting light is kept
-- apart (restFor) and Painted puts it right when only the reason changed.
function Arcane:PaintReason(r, g, b, reason, mode)
	self.reasonArgs = { r, g, b, mode or "icon" }
	self.restFor = reason
	self:Retint()
end

-- The last reason painted, again: after PaintReason, and when the person's
-- reason changes under the same colour.
function Arcane:Retint()
	local args = self.reasonArgs
	if not args then return end
	local r, g, b, mode = args[1], args[2], args[3], args[4]
	local off = mode == "off"
	if off then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	local ringOn = mode == "icon" or mode == "both"
	self:Tint(r, g, b, ringOn and { r, g, b } or NEUTRAL, REST[self.restFor] or REST.nearby, off)
	self:SubColor(r, g, b, off)
	-- A refusal greyed the icon; a fight keeps it grey.
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Arcane:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	if on then
		self:SetInk(true)
		self.breathe = nil
		self.pulseAnim:Stop()
		self.flareAnim:Stop()
		self.liftFrame:SetAlpha(0)
	else
		self:SetInk(false)
	end
	-- The reason line comes up to the dimmed text, or down again after; a
	-- verdict on it waits for the next paint, which is the reason's own.
	if not self.outcome then self:Retint() end
	self.kit.icon:SetDesaturated(on)
	self:Spin()
end

-- The rune circle turns on Full out of a fight, and holds still otherwise.
-- The square circle never turns: a square that turns wobbles. Stopped, not
-- paused, so it stands square.
function Arcane:Spin()
	local spin = self.spinAnim
	if self.kit.FullEffects() and not self.combat and self.showIcon and self.round then
		if not spin:IsPlaying() then spin:Play() end
	elseif not self.round then
		spin:Stop()
	elseif spin:IsPlaying() then
		if spin.Pause then spin:Pause() else spin:Stop() end
	end
end

---------------------------------------------------------------------------
-- the favour's clock
---------------------------------------------------------------------------

-- After every paint of a person, on the scan's own tick: the key.
function Arcane:Painted(entry)
	self:ReadKey()
	self:ShowKey()
	if entry and entry.reason ~= self.restFor then
		self.restFor = entry.reason
		self:Retint()
	end
end

-- The time left to return a favour, as the drain's length. Run by Chip, which
-- every repaint makes -- the fight's held panel and an outcome too, where
-- Painted is not called -- and read off whoever the panel names, as Toast's is.
function Arcane:Clock()
	local left
	if ns.Prompt:InTest() then
		-- The preview has no favour behind it; its clock stands part-run.
		left = 0.62
	else
		local name = ns.Prompt:PanelName()
		local debt = name and ns.owed and ns.owed[name]
		if type(debt) == "table" and type(debt.at) == "number" and ns.DebtExpiry then
			local ends = ns.DebtExpiry(debt)
			if type(ends) == "number" and ends > debt.at then
				left = (ends - GetTime()) / (ends - debt.at)
			end
		end
	end
	self:SetDrain(left)
end

function Arcane:SetDrain(left)
	-- Kept for the outcome's end, which brings the clock back.
	self.drainLeft = left
	local on = left ~= nil and left > 0 and not self.outcome
	for _, t in ipairs({ self.track, self.drain, self.spark }) do t:SetShown(on) end
	if not on then return end
	local width = math.max(1, math.floor(self.drainFull * math.min(1, left) * 2 + 0.5) / 2)
	if width ~= self.drainWidth then
		self.drainWidth = width
		self.drain:SetWidth(width)
	end
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

function Arcane:Breathe()
	self.pulseAnim:Stop()
	if self.kit.FullEffects() then
		self.pulseAnim:Play()
	else
		-- Calm: nothing loops. The light is held, a little up.
		self.liftFrame:SetAlpha(0.08)
	end
end

function Arcane:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self.breathe = nil
		self.pulseAnim:Stop()
		if not self.flareAnim:IsPlaying() then self.liftFrame:SetAlpha(0) end
		return
	end
	if isNew then
		-- The bloom and the rim flare once; on Calm, lower and with the runes
		-- still.
		local peak = full and 0.7 or 0.4
		self.pulseAnim:Stop()
		self.flareAnim:Stop()
		self.flareAnim.up:SetToAlpha(peak)
		self.flareAnim.down:SetFromAlpha(peak)
		self.flareAnim:Play()
		if full and self.showIcon then
			self.runeFlareAnim:Stop()
			self.runeFlareAnim:Play()
			-- And the lens's ring locks onto the icon.
			self.lockAnim:Stop()
			self.lockAnim:Play()
		end
	end
	-- The favour just done: light crosses the card in the reason's colour.
	if arrived and full and not self.shineAnim:IsPlaying() then
		local t = self.tint or NEUTRAL
		self:Shine(Mix(t[1], t[2], t[3], 0.6))
	end
	self.breathe = flashStyle == "pulse"
	if not self.breathe then
		self.pulseAnim:Stop()
	elseif self.flareAnim:IsPlaying() then
		-- The breath follows the flare (its OnFinished).
	elseif not (full and self.pulseAnim:IsPlaying()) then
		self:Breathe()
	end
end

function Arcane:StopAttention()
	self.breathe = nil
	self.pulseAnim:Stop()
	if not self.flareAnim:IsPlaying() then self.liftFrame:SetAlpha(0) end
	-- Unlocked, switched off or a fight with nothing armed: a press does
	-- nothing, so the keycap goes.
	self:ShowKey()
end

function Arcane:Shine(r, g, b, a)
	self.shine:SetVertexColor(r, g, b, a or 0.30)
	self.shineAnim:Stop()
	self.shineAnim:Play()
end

function Arcane:Flourish(kind)
	-- A refusal contracts: the lens's ring snaps in onto the icon in red. The
	-- rim has already turned red, and the text's shake is Prompt's.
	if kind == "failed" then
		if self.showIcon and not self.combat then
			local o = OUTCOME.failed
			self.fx:Refuse(o[1], 0.45, 0.28)
		end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim. No light
	-- across the card either: it would cross the verdict, which is up for
	-- barely longer than the light.
	if kind ~= "cast" then return end
	if self.showIcon and not self.combat then
		self.runeFlareAnim:Stop()
		self.runeFlareAnim:Play()
		self.checkAnim:Stop()
		self.checkAnim:Play()
		-- The lens's ring and the circle of runes after it spread outward in
		-- the landed buff's green.
		local o = OUTCOME.cast
		self.fx:Land(o[1], o[2], o[3], 0.85)
	end
end

function Arcane:StopFlourishes()
	self.runeFlareAnim:Stop()
	self.shineAnim:Stop()
	self.checkAnim:Stop()
	self.lockAnim:Stop()
	self.fx:Stop()
end

function Arcane:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
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

-- The name stays where it was and the reason line becomes the verdict. A
-- refusal turns the rim, the ring and the runes red and greys the icon; a
-- landed buff puts a tick on the icon; each washes the glass in its colour.
function Arcane:PaintOutcome(kind, lead, sub, who, stamp)
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
	if word and who and kit.sub:IsShown() then
		kit.SetLine(kit.name, who)
	else
		-- Not in this client's language yet, nobody to name, or no second
		-- line to write the verdict on: the built-in looks' lines, which say
		-- it on the name line.
		kit.SetLine(kit.name, lead)
		word = sub or ""
	end
	self.outcome = kind
	self:ShowKey()
	-- The clock steps aside and keeps its time, so the outcome's end brings
	-- it back, in a fight too (where nothing else would).
	self:SetDrain(self.drainLeft)
	if kind == "failed" or kind == "cast" then
		-- The rim says it: red for a refusal, green for a buff that landed.
		-- Put back by the next PaintReason, which Prompt asks for after
		-- every outcome, in a fight too.
		self:Tint(o[1], o[2], o[3], o, REST.owed)
	end
	kit.icon:SetDesaturated(kind == "failed" or self.combat or false)
	self.check:SetShown(kind == "cast" and self.showIcon)
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		local r, g, b = kit.Legible(o[1], o[2], o[3], self.combat and FIGHT_LEAST or 4.5)
		kit.sub:SetTextColor(r, g, b, 1)
	end
	-- The wash, once per click: a repaint during the outcome leaves it be.
	if stamp ~= self.washFor then
		self.washFor = stamp
		if self.lightGlass then
			self.wash:SetVertexColor(o[1] * DEEP, o[2] * DEEP, o[3] * DEEP, o[4])
		else
			self.wash:SetVertexColor(o[1], o[2], o[3], o[4])
		end
		self.washAnim:Stop()
		self.wash:SetAlpha(1)
		-- Round the lens: with no icon there is none, and the rim says it.
		self.wash:SetShown(self.showIcon)
		if kit.FullEffects() then
			self.washAnim.to = 0
			self.washAnim:Play()
		end
	end
end

function Arcane:ClearOutcome()
	if not (self.washFor or self.outcome) then return end
	self.washFor, self.outcome = nil, nil
	self.washAnim:Stop()
	self.wash:Hide()
	self.checkAnim:Stop()
	self.check:Hide()
	self:ShowKey()
	self:SetDrain(self.drainLeft)
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A slab of the same glass under the card (or over it), tucked eight units
-- beneath its edge so the card overlaps it; a bead in each row's reason
-- colour at the start of the line.
function Arcane:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	if self.trayShown ~= list or (list and self.above ~= above) then
		self.trayShown, self.above = list, above
		SliceShown(self.trayGlass, list)
		SliceShown(self.trayRim, list)
		-- One shadow under both.
		if not list then
			PlaceSlice(self.shadow, art, art, 10, 7, 10, 13)
		elseif above then
			PlaceSlice(self.shadow, self.trayBox, art, 10, 7, 10, 13)
		else
			PlaceSlice(self.shadow, art, self.trayBox, 10, 7, 10, 13)
		end
	end
	for i, dot in ipairs(self.dots) do
		if not (list and i <= shown) then dot:Hide() end
	end
	if not list then return end

	local pitch = self.pitch
	local depth = 5 + shown * pitch + 4
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	local placed = self.trayHeight == depth and self.trayAt == above
	if not placed then
		self.trayHeight, self.trayAt = depth, above
		self.trayBox:ClearAllPoints()
		if above then
			self.trayBox:SetPoint("BOTTOMLEFT", art, "TOPLEFT", 0, 0)
			self.trayBox:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, 0)
			self.trayBox:SetHeight(depth)
			PlaceSlice(self.trayGlass, self.trayBox, self.trayBox, -5, 0, -5, 8)
			PlaceSlice(self.trayRim, self.trayBox, self.trayBox, -5, 0, -5, 8)
		else
			self.trayBox:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, 0)
			self.trayBox:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, 0)
			self.trayBox:SetHeight(depth)
			PlaceSlice(self.trayGlass, self.trayBox, self.trayBox, -5, 8, -5, 0)
			PlaceSlice(self.trayRim, self.trayBox, self.trayBox, -5, 8, -5, 0)
		end
	end

	for i = 1, shown do
		local dot = self.dots[i]
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		dot:SetVertexColor(c[1], c[2], c[3], 1)
		dot:Show()
	end
	if placed then return end
	for i = 1, shown do
		local fs, dot = kit.rows[i], self.dots[i]
		-- Row centres from the card's edge the list hangs off; the first row
		-- is always the top one.
		local y, edge
		if above then
			y, edge = 5 + (shown - i) * pitch + pitch / 2, "TOPLEFT"
		else
			y, edge = -(5 + (i - 1) * pitch + pitch / 2), "BOTTOMLEFT"
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, edge, self.rowX, y)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", art, edge, self.dotX, y)
		dot:SetSize(12, 12)
	end
end
