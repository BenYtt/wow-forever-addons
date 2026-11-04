-- Manners -- the on-screen prompt, in the files under Prompt/.
--
-- The button is a SecureActionButtonTemplate: Blizzard owns the click, and its
-- attributes, size, scale and position are protected in combat. Every visual
-- lives on `art`, an ordinary child frame, so animations never touch protected
-- state. Everything is drawn from one white texture plus gradients, alpha and
-- motion: a missing atlas or art file renders as a green placeholder, and a
-- solid texture cannot fail.
--
-- One file for all of it came to 172 of the 200 locals Lua 5.1 allows a main
-- chunk and 45 of the 60 upvalues it allows a function (beta.6 went over the
-- second and did not load at all), so it is split by concern, loaded in this
-- order from Manners.toc:
--
--   Prompt.lua   the tables the files share, the reason colours, drawing helpers
--   Text.lua     text made legible on the panel's ground and fitted to its room
--   Effects.lua  the animations
--   Hold.lua     the hysteresis: the hold, the empty-queue fuse, the cursor
--   Macro.lua    what the button casts, and at whom
--   Press.lua    PreClick and PostClick
--   Button.lua   the button's other scripts: the drag, the cursor, the tooltip
--   Panel.lua    the panel built and styled; the three looks drawn here
--   List.lua     the list of who is next
--   Rows.lua     each name in that list as a button to press
--   Paint.lua    the words on the panel, and a click's outcome over them
--   Refresh.lua  the repaint, and the preview
--
-- They share three tables, kept on ns.Prompt: `state` (S in every file), what
-- more than one of them reads or writes; `regions` (R), the panel's frames and
-- textures; and `lib`, the helpers one file defines and a later one calls,
-- copied into a local at load.

local _, ns = ...
-- Player-facing text, in the client's language: see Locales/Init.lua.
local L = ns.L

local LSM = LibStub("LibSharedMedia-3.0")

-- Guarded because a library that changed its Register signature must not stop
-- the prompt being built; the addon is then silent, not broken.
ns.Guard("register sound", function()
	LSM:Register("sound", ns.SOUND_KEY, ns.SOUND_FILE)
end)

function ns.PlayPromptSound(file)
	if not file or file == "None" then return end
	-- noDefault: an uninstalled pack's entry would resolve to "None" and play
	-- nothing. A missing key falls back to our sound here, not in the saved
	-- setting: a pack loading after this addon has not registered yet.
	local data = LSM:Fetch("sound", file, true) or LSM:Fetch("sound", ns.SOUND_KEY, true)
	if not data then return end
	local willPlay = ns.plain(PlaySoundFile(data, "Master"))
	-- The client can refuse a file outright. A toggle that is on and silent is
	-- the whole complaint, so say which sound it was rather than nothing.
	if willPlay == false and ns.db and ns.db.profile.verbose then
		ns.addon:Print(L["|cffff8080%s did not play.|r Pick another sound."]:format(tostring(file)))
	end
end

local Prompt = {}
ns.Prompt = Prompt

-- Goes into every click line, so a log says which build produced it.
ns.BUILD = "1.11.0"

-- What more than one file reads or writes. The fields that start out nil are
-- listed for what they hold.
local S = {
	-- The entry the button is armed at (ApplyTarget): whom a press files and
	-- the tooltip describes.
	current = nil,
	-- The preview (Refresh.lua): whether it is up, and when it ends.
	testMode = nil,
	testExpiry = nil,
	-- What ApplyTarget last put on the button, as a key of everything it was
	-- built from; nil when the next ApplyTarget must rebuild it.
	appliedKey = nil,
	-- Who the macro frozen for a fight is aimed at, kept when a disarm in that
	-- fight (switched off, unlocked, a preview) could only clear `current`.
	frozenEntry = nil,
	-- What the macro on the button is aimed at: { targeted, selfCast, aimedAt },
	-- or nil. PostClick copies it onto the pending click, so the settle handler
	-- judges the press by what actually went out. Set beside appliedKey. This
	-- client does not name a cast's recipient, so a /target of ours aimed at this
	-- person is the only thing tying a press to a person.
	armed = nil,
	-- The spoken line settled for the candidate on the button, and its key, so the
	-- tooltip quotes the roll the press will cast.
	phraseKey = nil,
	phraseText = nil,
	-- ...and, for an "In character" line, the line as written, which that set
	-- remembers as said once a press carries it (Press.lua, OnPostClick).
	phraseSource = nil,
	-- Whether that line is on the button now: it is kept but left out for somebody
	-- out of reach or just refused (see ApplyTarget), and the tooltip must agree.
	phraseArmed = nil,

	-- The entry last painted and when, which the hold is measured against. The
	-- whole entry, because re-arming the macro needs the buff as well as the name
	-- after the queue has dropped them. And the queue the last pick was made
	-- from, which a shout's press reads for everybody else it reaches (PostClick);
	-- in a fight, the pull's own.
	heldEntry = nil,
	heldAt = nil,
	pickedFrom = nil,
	-- When the queue first came back empty, cleared the moment it refills.
	emptyAt = nil,
	-- Whether the cursor is on the panel: set by OnEnter, cleared by OnLeave and
	-- by ClearHold. While it is, the hold and the fuse keep their clocks but not
	-- their verdicts: the player is reaching for what the panel names, and
	-- neither an empty scan nor somebody no better may pull it out from under the
	-- cursor. Somebody strictly better still takes it, and a retired entry still
	-- goes (a right-press skip, the never-offer list, a press resolved). Only a
	-- token lost is forgiven, and for HOVER_SECONDS: see CursorHolds.
	hovering = nil,
	-- The name on the panel a scan turned down (see NoteVerdicts), which the
	-- cursor then no longer holds. Kept rather than asked of each scan: the
	-- verdict is written by the scan that reached it -- a token finding them
	-- covered, the memory letting them go -- and the next scan, with no token to
	-- them, has nothing to say about them. Cleared when the panel is painted from
	-- the queue again, and by ClearHold.
	heldTurnedDown = nil,

	-- When PostClick last filed a press and last took a skip, on the prompt and
	-- (on a row's own slot) on each name in the list: one press delivers a down
	-- and an up, and each is counted once.
	clickAt = nil,
	skipAt = nil,

	-- What the last click turned into: "cast", "sent" or "failed", who it was
	-- about, and the game's own words where it had any.
	outcomeKind = nil,
	outcomeAt = nil,
	outcomeName = nil,
	outcomeDetail = nil,
	-- Who the name line is about while an outcome is over it: the outcome expires
	-- on the clock but its words stay until a repaint, and a press follows the
	-- words.
	outcomePainted = nil,

	-- The look drawn from a file of its own (Looks/), or nil for the three
	-- Panel.lua draws. Looks/Looks.lua says what it is asked and when.
	activeLook = nil,
	-- Which side of the panel the queue list hangs off, and where its text
	-- starts. Decided in ApplyStyle, because the only things that move the
	-- prompt come back through it.
	queueAbove = nil,
	queueTextX = 0,
	-- Whether the panel colour is dark enough for the reason line to carry a tint
	-- of the reason colour. On a light panel a tinted grey loses its contrast.
	tintSub = nil,
	-- What PaintAccent last painted, so a repaint in the same colour costs nothing.
	accentPainted = nil,
}

-- What a press of the bar macro is filed against (Prompt/Press.lua,
-- OnBarClick), standing in for the state above under the same names, as a list
-- row's slot does: what the lines Clicks.lua last wrote under the macro's first
-- line were written from (body, current, armed, macro, pickedFrom, and
-- phraseArmed false: the bar's copy carries no spoken line), and the press's
-- own stamps (clickAt, waitAt).
Prompt.bar = { isBar = true }

-- The panel's frames and textures, made once by Prompt:Create (Panel.lua) and
-- read by name. Prompt:Regions() hands tests a copy.
local R = {}

local lib = { LSM = LSM }

Prompt.state, Prompt.regions, Prompt.lib = S, R, lib

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- How long a click's outcome sits over the panel.
local OUTCOME_SECONDS = 0.6

-- Amber for a favour returned, the case worth noticing; the others stay quiet.
-- Picked to survive the commonest colour blindness: target and group differ in
-- lightness, owed and target are amber against blue.
-- Rec.601 greys: target 0.83, owed 0.79, group 0.56, nearby 0.54.
local REASON_COLOR = {
	target = { 0.62, 0.90, 1.00 },
	owed = { 1.00, 0.78, 0.30 },
	group = { 0.34, 0.60, 0.96 },
	nearby = { 0.52, 0.54, 0.62 },
	-- Somebody who asked in chat: a warm pink, apart from the four in hue and
	-- between owed and group in grey (0.68).
	asked = { 0.96, 0.52, 0.80 },
}

local REASON_KEY = { target = "reasonTarget", owed = "reasonOwed",
	group = "reasonGroup", nearby = "reasonNearby", asked = "reasonAsked" }
-- Your own buff (Queue.lua, SelfEntry).
REASON_KEY.self = "reasonSelf"

-- For somebody the set above still fails: chosen by search so the closest pair
-- is furthest apart in CIE76 under normal sight, protanopia and deuteranopia
-- (Machado et al. 2009); tests/scenarios/look2.lua holds it to that. Opt-in
-- under Prompt > Style. Rec.601 greys: target 0.92, owed 0.57, group 0.70,
-- nearby 0.47, asked 0.37.
local REASON_COLOR_CVD = {
	target = { 0.98, 0.96, 0.56 },
	owed = { 0.92, 0.48, 0.08 },
	group = { 0.42, 0.78, 1.00 },
	nearby = { 0.80, 0.20, 1.00 },
	-- A deep pink, searched for the same way against the four above, and
	-- darker than the violet and the orange: lightness survives all three
	-- ways of seeing.
	asked = { 0.72, 0.20, 0.34 },
}
-- Your own buff wears your group's colour in both sets rather than a sixth of
-- its own: five already strain what colour-blind sight can tell apart, and the
-- words ("You") say which it is. It is also where you stand: in the group.
REASON_COLOR.self = REASON_COLOR.group
REASON_COLOR_CVD.self = REASON_COLOR_CVD.group
local REASON_PALETTES = { standard = REASON_COLOR, colourblind = REASON_COLOR_CVD }

-- The colour for a reason in the player's palette; anything unknown reads as
-- the standard set.
local function ReasonColor(reason)
	local p = ns.db and ns.db.profile.prompt
	local set = REASON_PALETTES[p and p.reasonPalette] or REASON_COLOR
	return set[reason or "nearby"] or set.nearby
end

-- Whole minutes, like the refresh threshold: a ticking countdown reads as
-- urgency. Seconds only under a minute.
local function RemainingText(seconds)
	if type(seconds) ~= "number" or seconds <= 0 then return nil end
	if seconds < 60 then return L["%ds"]:format(math.floor(seconds)) end
	return L["%dm"]:format(math.floor(seconds / 60))
end

---------------------------------------------------------------------------
-- capability-checked drawing helpers
---------------------------------------------------------------------------

-- SetGradient changed signature between client generations and SetGradientAlpha
-- was removed. Try both, and fall back to a flat colour that always works.
local function Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
	if tex.SetGradient and CreateColor then
		if pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then
			return true
		end
	end
	if tex.SetGradientAlpha then
		if pcall(tex.SetGradientAlpha, tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2) then
			return true
		end
	end
	tex:SetVertexColor(r1, g1, b1, a1)
	return false
end

local function Solid(parent, layer, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(WHITE)
	return t
end

-- A method this client may not have, called if it is there. The effects use a
-- few calls nobody here has watched run; a missing one costs that detail,
-- never the prompt.
local function Try(obj, method, ...)
	local fn = obj and obj[method]
	if type(fn) ~= "function" then return false end
	return (pcall(fn, obj, ...))
end

-- The soft glows round the icon, drawn once by tools/make-glow.py: white, with
-- the shape in the alpha, so they take the reason colour from SetVertexColor.
local GLOW = "Interface\\AddOns\\Manners\\Textures\\Glow"
local GLOW_ROUND = "Interface\\AddOns\\Manners\\Textures\\GlowRound"
-- Where the rim of the round glow sits, as a fraction of the texture's
-- half-width: RING_AT in tools/make-glow.py, which must agree.
local GLOW_RING_AT = 0.70

-- Where each piece of the square halo is cut from Glow.tga (SetTexCoord's
-- left, right, top, bottom): quarters for corners and a thin middle line for
-- sides, so every join has matching brightness.
local MID0, MID1 = 0.49, 0.51
local HALO_CUTS = {
	{ MID0, MID1, 0, 0.5 }, -- top
	{ MID0, MID1, 0.5, 1 }, -- bottom
	{ 0, 0.5, MID0, MID1 }, -- left
	{ 0.5, 1, MID0, MID1 }, -- right
	{ 0, 0.5, 0, 0.5 },     -- top-left
	{ 0.5, 1, 0, 0.5 },     -- top-right
	{ 0, 0.5, 0.5, 1 },     -- bottom-left
	{ 0.5, 1, 0.5, 1 },     -- bottom-right
}

-- The four squares that carry the halo round the inside of a rounded corner
-- (PlaceHalo's `fill`): each one texel of Glow.tga at its middle, taken from
-- the side of the middle its corner piece starts from, so it is exactly as
-- bright as that piece's inner corner and the two sides' inner ends it meets.
local FILL_CUTS = {
	{ 0.5 - 1 / 128, 0.5, 0.5 - 1 / 128, 0.5 }, -- top-left
	{ 0.5, 0.5 + 1 / 128, 0.5 - 1 / 128, 0.5 }, -- top-right
	{ 0.5 - 1 / 128, 0.5, 0.5, 0.5 + 1 / 128 }, -- bottom-left
	{ 0.5, 0.5 + 1 / 128, 0.5, 0.5 + 1 / 128 }, -- bottom-right
}
-- Where each sits: its outer corner on the corner piece's inner one.
local FILL_AT = {
	{ "BOTTOMRIGHT", "TOPLEFT", -1, 1 },
	{ "BOTTOMLEFT", "TOPRIGHT", 1, 1 },
	{ "TOPRIGHT", "BOTTOMLEFT", -1, -1 },
	{ "TOPLEFT", "BOTTOMRIGHT", 1, -1 },
}

-- A halo round a box: the eight pieces of the square one, the four squares
-- that carry it round a rounded corner, and the ring a rounded icon wears
-- instead. Additive, so it is light added to what is there.
local function Halo(parent, layer, sublevel)
	local halo = { strips = {}, fills = {} }
	for i, cut in ipairs(HALO_CUTS) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(GLOW)
		t:SetTexCoord(cut[1], cut[2], cut[3], cut[4])
		t:SetBlendMode("ADD")
		halo.strips[i] = t
	end
	for i, cut in ipairs(FILL_CUTS) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(GLOW)
		t:SetTexCoord(cut[1], cut[2], cut[3], cut[4])
		t:SetBlendMode("ADD")
		t:Hide()
		halo.fills[i] = t
	end
	halo.round = parent:CreateTexture(nil, layer, nil, sublevel)
	halo.round:SetTexture(GLOW_ROUND)
	halo.round:SetBlendMode("ADD")
	halo.round:Hide()
	return halo
end

-- Placed round `box`, outside an inset of `gap`: `sx` out to the sides and `sy`
-- above and below. With `round` (a round icon's size, passed because the box
-- may not be laid out yet) the ring instead, its rim on the icon's edge.
-- `fill` (units, at most `gap`): the halo's inner edge carried that far in at
-- each corner, a square of its brightest light in the corner of the gap, for
-- something round-cornered the light has to follow there (the bezel's lip).
local function PlaceHalo(halo, box, sx, sy, gap, round, fill)
	local strips = halo.strips
	local top, bottom, left, right = strips[1], strips[2], strips[3], strips[4]
	for _, t in ipairs(strips) do
		t:ClearAllPoints()
		t:SetShown(not round)
	end
	fill = (not round and fill and fill > 0 and sx > 0 and sy > 0) and math.min(fill, gap) or nil
	local inset = fill and gap - fill
	for i, t in ipairs(halo.fills) do
		t:ClearAllPoints()
		t:SetShown(fill and true or false)
		if fill then
			local at = FILL_AT[i]
			t:SetPoint(at[1], box, at[2], at[3] * inset, at[4] * inset)
			t:SetSize(fill, fill)
		end
	end
	halo.round:ClearAllPoints()
	halo.round:SetShown(round and true or false)
	if round then
		local size = round / GLOW_RING_AT
		halo.round:SetPoint("CENTER", box, "CENTER", 0, 0)
		halo.round:SetSize(size, size)
		return
	end
	top:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -gap, gap)
	top:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", gap, gap)
	top:SetHeight(sy)
	bottom:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -gap, -gap)
	bottom:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", gap, -gap)
	bottom:SetHeight(sy)
	left:SetPoint("TOPRIGHT", box, "TOPLEFT", -gap, gap)
	left:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", -gap, -gap)
	left:SetWidth(sx)
	right:SetPoint("TOPLEFT", box, "TOPRIGHT", gap, gap)
	right:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", gap, -gap)
	right:SetWidth(sx)
	-- Top-left, top-right, bottom-left, bottom-right.
	for i, at in ipairs({
		{ "BOTTOMRIGHT", "TOPLEFT", -gap, gap },
		{ "BOTTOMLEFT", "TOPRIGHT", gap, gap },
		{ "TOPRIGHT", "BOTTOMLEFT", -gap, -gap },
		{ "TOPLEFT", "BOTTOMRIGHT", gap, -gap },
	}) do
		local corner = strips[4 + i]
		corner:SetPoint(at[1], box, at[2], at[3], at[4])
		corner:SetSize(sx, sy)
	end
end

-- The whole halo in one colour: the fade is in the texture, so a vertex colour
-- per piece is all it takes.
local function PaintHalo(halo, r, g, b, alpha)
	for _, t in ipairs(halo.strips) do t:SetVertexColor(r, g, b, alpha) end
	for _, t in ipairs(halo.fills) do t:SetVertexColor(r, g, b, alpha) end
	halo.round:SetVertexColor(r, g, b, alpha)
end

local function unpackColor(c, fallback)
	c = c or fallback
	return c[1] or 1, c[2] or 1, c[3] or 1, c[4] == nil and 1 or c[4]
end

-- The rest of the light, drawn once by tools/make-glow.py as well: white, with
-- the shape in the alpha. A thin ring that spreads from the icon (round, and a
-- rounded square for a square icon) and the wave that bursts from the icon's
-- edge and crosses the panel when a buff lands.
local RING = "Interface\\AddOns\\Manners\\Textures\\Ring"
local RING_SQ = "Interface\\AddOns\\Manners\\Textures\\RingSq"
local SHOCK = "Interface\\AddOns\\Manners\\Textures\\Shock"
-- The two rules of light along the panel's edges, drawn out from the icon as
-- it comes up, the glint that runs them when a favour arrives, and the crack
-- that opens along the bottom band when a buff is refused.
local RULE = "Interface\\AddOns\\Manners\\Textures\\Rule"
local GLINT = "Interface\\AddOns\\Manners\\Textures\\Glint"
local CRACK = "Interface\\AddOns\\Manners\\Textures\\Crack"
-- Where the ring's middle sits, as a fraction of the file's half-width:
-- ring_thin_at in tools/make-glow.py, which must agree.
local RING_AT = 0.78

-- The built-in looks' material, by tools/make_panel_textures.py: the glass
-- pane (a grey the panel colour tints) and the light on its edges (white
-- with a cool line, and a dark line in shade; drawn BLEND), the metal bezel round the icon (grey, vertex-tinted; square, and a
-- round twin) and the framed look's rim (grey, a nine-slice).
local GLASS_PANE = "Interface\\AddOns\\Manners\\Textures\\GlassPane"
local GLASS_LIGHT = "Interface\\AddOns\\Manners\\Textures\\GlassLight"
local BEZEL = "Interface\\AddOns\\Manners\\Textures\\IconBezel"
local BEZEL_ROUND = "Interface\\AddOns\\Manners\\Textures\\IconBezelRound"
local TOOLTIP_RIM = "Interface\\AddOns\\Manners\\Textures\\TooltipRim"
-- How much of the bezel file the icon fills (the middle 96 of 128 texels), so
-- the bezel is drawn at iconSize / BEZEL_FRAME: ICON_FRAME in
-- tools/make_panel_textures.py, which must agree.
local BEZEL_FRAME = 0.75
-- The bezel's dark lip, as fractions of the file's width from its middle:
-- where its inner edge turns the corner, on the diagonal, and the middle of
-- its band along a side. tools/make_panel_textures.py draws the hole 48
-- texels from the middle of 128 with a one-texel corner, the seam and the rim
-- (SEAM 3, RIM 8) outside it, then the lip (LIP 3): the lip's inner edge runs
-- 12 texels round the hole's corner, and its band from 59 to 62 texels out
-- along a side (which must agree; tests/scenarios/bezel-corner.lua reads them
-- there). Panel.lua carries the halos round that corner.
local BEZEL_LIP_CORNER, BEZEL_LIP_SIDE = (47 + 12 / math.sqrt(2)) / 128, 60.5 / 128

-- A colour taken towards white (t 0..1), or towards black (negative t): the
-- lighter and darker tints the light is drawn in, worked out from the reason
-- colour so the five colours and the colour-blind set stay exactly as they
-- are. For t from -1 to 1 a colour inside the range stays inside it.
local function Tint(r, g, b, t)
	if t >= 0 then return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t end
	local k = 1 + t
	return r * k, g * k, b * k
end

-- The warm white the second tone of a light is drawn in: the reason's colour
-- and this, together, read as a lit rim rather than a stained one.
local WARM_WHITE = { 1.00, 0.94, 0.80 }

lib.WHITE, lib.OUTCOME_SECONDS = WHITE, OUTCOME_SECONDS
lib.REASON_KEY, lib.ReasonColor, lib.RemainingText = REASON_KEY, ReasonColor, RemainingText
lib.Gradient, lib.Solid, lib.Try, lib.unpackColor = Gradient, Solid, Try, unpackColor
lib.Halo, lib.PlaceHalo, lib.PaintHalo = Halo, PlaceHalo, PaintHalo
lib.RING, lib.RING_SQ, lib.RING_AT, lib.SHOCK = RING, RING_SQ, RING_AT, SHOCK
lib.RULE, lib.GLINT, lib.CRACK = RULE, GLINT, CRACK
lib.GLASS_PANE, lib.GLASS_LIGHT, lib.BEZEL, lib.BEZEL_ROUND = GLASS_PANE, GLASS_LIGHT, BEZEL, BEZEL_ROUND
lib.TOOLTIP_RIM, lib.BEZEL_FRAME = TOOLTIP_RIM, BEZEL_FRAME
lib.BEZEL_LIP_CORNER, lib.BEZEL_LIP_SIDE = BEZEL_LIP_CORNER, BEZEL_LIP_SIDE
lib.Tint, lib.WARM_WHITE = Tint, WARM_WHITE
lib.GLOW_RING_AT = GLOW_RING_AT
-- How many frame levels above art the text sits: over every frame of light
-- (the rings, the halo, the band that crosses the panel, which are at art's
-- level plus one), so none of it is drawn over a letter. A look that moves
-- textLayer puts it back here (kit.TEXT_LEVEL).
lib.TEXT_LEVEL = 6
