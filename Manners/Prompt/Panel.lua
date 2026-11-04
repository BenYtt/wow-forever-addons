-- Manners -- the prompt's panel: its regions built once, and styled for the
-- player's settings -- the three looks drawn here (glass, framed, minimal), or
-- handed to a look from Looks/.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local LSM, WHITE, OUTCOME_SECONDS = lib.LSM, lib.WHITE, lib.OUTCOME_SECONDS
local Gradient, Solid, Try, unpackColor = lib.Gradient, lib.Solid, lib.Try, lib.unpackColor
local Halo, PlaceHalo, PaintHalo, ReasonColor = lib.Halo, lib.PlaceHalo, lib.PaintHalo, lib.ReasonColor
local ink, fit, GREYS, EDGE_ROOM, TEXT_CONTRAST = lib.ink, lib.fit, lib.GREYS, lib.EDGE_ROOM, lib.TEXT_CONTRAST
local Legible, TextWidth, SetLine, FitLine = lib.Legible, lib.TextWidth, lib.SetLine, lib.FitLine
local StyleText, FullEffects, BUTTON_SCRIPTS = lib.StyleText, lib.FullEffects, lib.BUTTON_SCRIPTS
local RING, RING_SQ, SHOCK = lib.RING, lib.RING_SQ, lib.SHOCK
local RULE, GLINT, CRACK = lib.RULE, lib.GLINT, lib.CRACK
local GLASS_PANE, GLASS_LIGHT, BEZEL, BEZEL_ROUND = lib.GLASS_PANE, lib.GLASS_LIGHT, lib.BEZEL, lib.BEZEL_ROUND
local TOOLTIP_RIM, BEZEL_FRAME = lib.TOOLTIP_RIM, lib.BEZEL_FRAME
local Tint, WARM_WHITE = lib.Tint, lib.WARM_WHITE
-- The client's own round mask: the shape of a round icon, its sweep and the
-- icon's echo.
local PORTRAIT_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
-- The glass pane, its light and the framed look's rim are nine-slices whose
-- corners are the outer quarter of the file (32 of GlassPane's and
-- GlassLight's 128 texels, 16 of TooltipRim's 64: tools/make_panel_textures.py,
-- which must agree), drawn at most this many units square: 8 for the pane's
-- files, 4 for the rim's, four texels to the unit.
local SLICE_CUT, PANE_CORNER, RIM_CORNER = 0.25, 8, 4
-- The light on the glass, at this much of the panel's own opacity.
local LIGHT_ALPHA = 0.9
-- The bezel's metal when the reason colour is not on it, and how far its own
-- colour lifts toward white under the cursor (a mix with gold read the same
-- as the amber of somebody owed, whose luma it shares).
local NEUTRAL_METAL = { 0.42, 0.42, 0.46 }
local HOVER_LIFT = 0.45
-- The framed look's rim: pale metal on a dark panel, dark on a pale one, each
-- mixed a fifth toward the panel colour so the rim belongs to its panel.
local RIM_PALE, RIM_DARK, RIM_MIX = { 0.92, 0.92, 0.98 }, { 0.38, 0.38, 0.44 }, 0.20
-- Where the icon sits and how far the text starts from it, in units.
local ICON_X, ICON_GAP = 10, 10
-- The two rules of light along the top and bottom edges: how far inside each
-- edge they lie, how short of the right edge they stop, where they start with
-- no icon to start from, and how long the glint that runs them is, in units.
local RULE_INSET, RULE_END, RULE_X0, GLINT_LENGTH = 1.5, 2, 6, 14
-- The wave that crosses the panel when a buff lands: how far right of the
-- icon's edge it starts, and how wide it is held, in units (a share of the
-- panel's width between).
local SHINE_GAP, SHINE_MIN, SHINE_MAX, SHINE_SHARE = 2, 20, 64, 0.22
-- The crack under the words when a buff is refused: how far above the bottom
-- edge it lies, how much of the width it leaves at the right, and how tall it
-- is held (a seventh of the height between), in units. Never over 7, so its
-- top stays under the reason line, which sits 8 units up (Text.lua).
local CRACK_INSET, CRACK_END, CRACK_MIN, CRACK_MAX = 1.0, 0.3, 2, 7
-- The four edges of the panel, hung corner to corner: the lines the framed
-- look wore before its rim, kept hidden for one release.
local EDGE_LINES = {
	{ "TOPLEFT", "TOPRIGHT", height = 1 },
	{ "BOTTOMLEFT", "BOTTOMRIGHT", height = 1 },
	{ "TOPLEFT", "BOTTOMLEFT", width = 1 },
	{ "TOPRIGHT", "BOTTOMRIGHT", width = 1 },
}

-- Nine textures cut from one file, as the looks' own slices are: the corners
-- are the outer quarter of the file, the edges the middle strips.
local function Slice(parent, layer, sublevel, file)
	local s = {}
	local cuts = { 0, SLICE_CUT, 1 - SLICE_CUT, 1 }
	for row = 1, 3 do
		for col = 1, 3 do
			local t = parent:CreateTexture(nil, layer, nil, sublevel)
			t:SetTexture(file)
			t:SetTexCoord(cuts[col], cuts[col + 1], cuts[row], cuts[row + 1])
			s[#s + 1] = t
		end
	end
	return s
end

-- The nine pieces laid over `box` with corners `c` units square: the top row
-- is pieces 1-3, the middle 4-6, the bottom 7-9.
local function PlaceSlice(s, box, c)
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetSize(c, c)
	s[2]:SetPoint("TOPLEFT", box, "TOPLEFT", c, 0)
	s[2]:SetPoint("TOPRIGHT", box, "TOPRIGHT", -c, 0)
	s[2]:SetHeight(c)
	s[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[3]:SetSize(c, c)
	s[4]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -c)
	s[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, c)
	s[4]:SetWidth(c)
	s[5]:SetPoint("TOPLEFT", box, "TOPLEFT", c, -c)
	s[5]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -c, c)
	s[6]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -c)
	s[6]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, c)
	s[6]:SetWidth(c)
	s[7]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[7]:SetSize(c, c)
	s[8]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", c, 0)
	s[8]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -c, 0)
	s[8]:SetHeight(c)
	s[9]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[9]:SetSize(c, c)
end

-- The drop shadow: steps of falloff from a crisp dark rim out to almost
-- nothing, each a little lower, so the light reads as coming from above.
local SHADOW_STEPS = {
	-- spread, alpha, drop
	{ 1, 0.50, 0 },
	{ 3, 0.16, 1 },
	{ 6, 0.09, 2 },
	{ 10, 0.05, 3 },
}

-- The panel opacity the steps above were drawn for: the default's.
local SHADOW_AT = 0.88

-- Below the panel normally, above it when the prompt sits in the bottom third
-- of the screen. Every call is guarded (an unplaced frame has no centre), and
-- the centre is converted from the prompt's scaled units to UIParent's.
local function QueueGoesAbove()
	local okCentre, _, y = pcall(R.button.GetCenter, R.button)
	if not okCentre or type(y) ~= "number" then return false end
	local okHeight, screenHeight = pcall(UIParent.GetHeight, UIParent)
	if not okHeight or type(screenHeight) ~= "number" or screenHeight <= 0 then return false end
	local ratio = ns.db.profile.prompt.scale
	local okOwn, own = pcall(R.button.GetEffectiveScale, R.button)
	local okParent, parent = pcall(UIParent.GetEffectiveScale, UIParent)
	if okOwn and okParent and type(own) == "number" and type(parent) == "number"
		and parent > 0 then
		ratio = own / parent
	end
	if type(ratio) ~= "number" or ratio <= 0 then ratio = 1 end
	return y * ratio < screenHeight / 3
end

function Prompt:Create()
	if R.button then return end

	R.button = CreateFrame("Button", "MannersPrompt", UIParent, "SecureActionButtonTemplate")
	R.button:SetFrameStrata("MEDIUM")
	-- Copied from the secure buttons that work on this client (MountActions,
	-- GroupTools): "AnyDown" with pressAndHoldAction. Registering down without
	-- pressAndHoldAction delivers the click and casts nothing.
	-- Kept on R as well: the client has no call that reads it back, and
	-- /manners selftest reports what the button was registered for.
	R.clicks = "AnyDown"
	R.button:RegisterForClicks(R.clicks)
	R.button:SetAttribute("pressAndHoldAction", true)
	R.button:SetMovable(true)
	R.button:SetClampedToScreen(true)
	R.button:RegisterForDrag("LeftButton")

	-- What the bar macro's first line clicks (Clicks.lua, click macro): a plain
	-- button, no secure template and no macro, so a macro may click it. Never
	-- drawn (no size, no texture). Registered for both phases, though /click
	-- sends one click per press.
	R.bar = CreateFrame("Button", "MannersBar", UIParent)
	R.bar:RegisterForClicks("AnyUp", "AnyDown")
	R.bar.mannersBar = Prompt.bar
	R.bar:SetScript("OnClick", lib.OnBarClick)

	R.art = CreateFrame("Frame", nil, R.button)
	R.art:SetAllPoints()

	-- Stacked black rectangles stand in for a soft drop shadow: four steps of
	-- falloff, each a pixel lower, with a crisp dark rim innermost to keep the
	-- edge clean over a bright floor.
	R.shadows = {}
	for i, step in ipairs(SHADOW_STEPS) do
		local spread, alpha, drop = step[1], step[2], step[3]
		-- Outermost first, so it sits underneath; sublevels -8 to -7 are all
		-- the layer has below the panel, and two share one where they must.
		local t = Solid(R.art, "BACKGROUND", i <= 2 and -7 or -8)
		t:SetPoint("TOPLEFT", -spread, spread - drop)
		t:SetPoint("BOTTOMRIGHT", spread, -spread - drop)
		t:SetVertexColor(0, 0, 0, alpha)
		R.shadows[i] = t
	end

	-- The framed look's flat panel. The glass has a pane of its own instead.
	R.panel = Solid(R.art, "BACKGROUND", -6)
	R.panel:SetAllPoints()

	-- The glass: a pane of thick enchanted glass, nine pieces of GlassPane.tga
	-- (a grey, brighter in the middle, with a cut edge) that the panel colour
	-- tints, in the panel's own place.
	R.pane = Slice(R.art, "BACKGROUND", -6, GLASS_PANE)
	for _, t in ipairs(R.pane) do t:Hide() end

	-- The light on the glass, over the pane and the stripe: the pane as a
	-- thick slab of cut glass struck from the upper left, all of it at the
	-- edges. The polished cut, pooled on the corner that faces the key light;
	-- a refraction line a unit wide inside it, cool-tinted along the top and
	-- left, a darker line in its place along the bottom and right (black
	-- texels, which darken the pane drawn BLEND and add nothing in the
	-- landing's additive copy); a faint glow just under the top line, in the
	-- top row of pieces only. The middle piece is empty. Drawn BLEND at the
	-- panel's own opacity, never additive at rest.
	R.glassLight = Slice(R.art, "BORDER", 2, GLASS_LIGHT)
	for _, t in ipairs(R.glassLight) do
		t:SetBlendMode("BLEND")
		t:Hide()
	end

	-- The framed look's rim: the classic tooltip's rail, a half-round of lit
	-- metal all the way round, nine pieces of TooltipRim.tga. Above the stripe,
	-- which runs inside it.
	R.tooltipRim = Slice(R.art, "BORDER", 3, TOOLTIP_RIM)
	for _, t in ipairs(R.tooltipRim) do t:Hide() end

	-- The four lines the framed look wore before its rim. Kept hidden for one
	-- release (ApplyStyle never shows them), then removed.
	R.edges = {}
	for _, at in ipairs(EDGE_LINES) do
		local edge = Solid(R.art, "BORDER", 3)
		if at.height then edge:SetHeight(at.height) else edge:SetWidth(at.width) end
		edge:SetPoint(at[1])
		edge:SetPoint(at[2])
		edge:Hide()
		R.edges[#R.edges + 1] = edge
	end

	-- The accent stripe is two textures so it can fade out towards both ends
	-- instead of stopping dead. A gradient only has two stops.
	R.accentTop = Solid(R.art, "BORDER", 2)
	R.accentTop:SetWidth(3)
	R.accentTop:SetPoint("TOPLEFT")
	R.accentBottom = Solid(R.art, "BORDER", 2)
	R.accentBottom:SetWidth(3)
	R.accentBottom:SetPoint("BOTTOMLEFT")

	-- Only frames can own an animation group, so anything that moves or fades
	-- on its own gets a frame of its own to be animated through.

	-- The wash of colour over the whole panel for the half-second after a
	-- click, on a frame of its own so it fades rather than cuts. Made FIRST
	-- among the art's child frames: every frame of light sits at the same
	-- level, one above the art, and equal levels draw in the order they were
	-- made (in the client as in the test double and the renderer), so the wash
	-- lies under the rings, the wave and the rules -- light on the panel, never
	-- a film over the light -- and still under textLayer, a frame levels above.
	R.washFrame = CreateFrame("Frame", nil, R.art)
	R.washFrame:SetAllPoints()
	R.resultFill = Solid(R.washFrame, "ARTWORK", 2)
	R.resultFill:SetAllPoints(R.art)
	R.resultFill:Hide()

	R.sweepFrame = CreateFrame("Frame", nil, R.art)
	R.sweepFrame:SetWidth(3)
	R.sweepFrame:SetHeight(14)
	R.sweepFrame:SetPoint("TOPLEFT")
	R.sweepFrame:SetAlpha(0)
	R.sweep = Solid(R.sweepFrame, "ARTWORK", 3)
	R.sweep:SetAllPoints()
	R.sweep:SetBlendMode("ADD")

	-- A halo round the icon, starting at the ring so the icon stays readable at
	-- every point of the pulse, on a frame of its own: a child frame draws over
	-- its parent. Sized to the icon itself; the halo is drawn outside it.
	R.glowFrame = CreateFrame("Frame", nil, R.art)
	R.glowFrame:SetAlpha(0)
	R.glowHalo = Halo(R.glowFrame, "BACKGROUND", -3)

	-- And a tight rim of warm white hugging the ring, on its own frame so it
	-- breathes with the glow: the reason's colour outside, light inside.
	R.rimFrame = CreateFrame("Frame", nil, R.art)
	R.rimFrame:SetAlpha(0)
	R.rimHalo = Halo(R.rimFrame, "BACKGROUND", -2)

	-- Doubles as the icon's frame and the reason signal: a chamfered metal
	-- bezel round the icon (IconBezel.tga, grey, the reason colour or a
	-- neutral metal on it), with a round twin for a rounded icon. Above the
	-- pane's hairline and the framed look's rim, so neither draws across it,
	-- and under the icon, which fills its hole.
	R.bezel = R.art:CreateTexture(nil, "BORDER", nil, 4)
	R.bezel:SetTexture(BEZEL)
	-- The same bezel lifted lighter, faded up under the cursor and let go: a
	-- texture of its own so the bezel keeps its colour while the lift comes
	-- and goes.
	R.bezelHover = R.art:CreateTexture(nil, "BORDER", nil, 5)
	R.bezelHover:SetTexture(BEZEL)
	R.bezelHover:SetBlendMode("BLEND")
	R.bezelHover:SetAlpha(0)

	R.icon = R.art:CreateTexture(nil, "ARTWORK")
	R.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	R.iconShade = Solid(R.art, "ARTWORK", 1)

	-- The global cooldown swept over the icon. A Cooldown frame is not
	-- protected and animates itself; made in a pcall, as the template is not
	-- ours.
	local okCooldown, made = pcall(CreateFrame, "Cooldown", nil, R.art, "CooldownFrameTemplate")
	if okCooldown and made then
		R.cooldown = made
		-- A thin line of light on the sweep's leading edge, where the client
		-- draws one (the colour of it is the newest clients' to set).
		Try(R.cooldown, "SetDrawEdge", true)
		Try(R.cooldown, "SetDrawBling", false)
		Try(R.cooldown, "SetHideCountdownNumbers", true)
		Try(R.cooldown, "SetSwipeColor", 0, 0, 0, 0.62)
		if R.cooldown.SetEdgeColor then R.cooldown:SetEdgeColor(1, 0.95, 0.80, 0.95) end
		R.cooldown:Hide()
	end

	-- The halo that flares when a favour arrives, a buff lands or one is
	-- refused. Its own frame so it can grow; drawn from the same strips as the
	-- glow, bright at the inside edge.
	R.burstFrame = CreateFrame("Frame", nil, R.art)
	R.burstFrame:SetAlpha(0)
	R.burstHalo = Halo(R.burstFrame, "OVERLAY", 2)

	-- The rings that spread from the icon when a buff lands, the one that
	-- snaps in when a refusal comes, and the icon's echo as a favour arrives
	-- (Prompt/Effects.lua; the looks make their own from the same builder).
	R.fx = lib.NewFX(R.art)

	-- The wave of light that bursts from the icon's right edge and runs the
	-- panel once when a buff lands: a hot core over a wider skirt, the full
	-- height of the panel, from Textures/Shock.tga.
	R.shineFrame = CreateFrame("Frame", nil, R.art)
	R.shineFrame:SetAlpha(0)
	R.shineBand = R.shineFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	R.shineBand:SetTexture(SHOCK)
	R.shineBand:SetBlendMode("ADD")
	R.shineBand:SetAllPoints(R.shineFrame)

	-- The panel's edge answering an outcome: the material itself lit, so the
	-- frame flashes in the reason's colour as a buff lands and in red as one
	-- is refused. A copy of the glass's light (the pane's cut edge and its
	-- refraction line; the dark line adds nothing) and one of the framed look's rim,
	-- nine pieces each, drawn ADD on a frame of their own: a level over the
	-- pane's light, the rim and the bezel, under the text. Parked at nothing;
	-- ApplyStyle lays them as the material is laid, shows the look's own with
	-- the middle piece left dark (nothing lights under the words), and hides
	-- the frame on Minimal, which has no edge to light.
	R.edgeLightFrame = CreateFrame("Frame", nil, R.art)
	R.edgeLightFrame:SetAllPoints()
	R.edgeLightFrame:SetAlpha(0)
	R.edgeLightFrame.glass = Slice(R.edgeLightFrame, "OVERLAY", 1, GLASS_LIGHT)
	R.edgeLightFrame.rim = Slice(R.edgeLightFrame, "OVERLAY", 1, TOOLTIP_RIM)
	for _, pieces in ipairs({ R.edgeLightFrame.glass, R.edgeLightFrame.rim }) do
		for _, t in ipairs(pieces) do
			t:SetBlendMode("ADD")
			t:Hide()
		end
	end
	-- The pieces the look in use lights with (ApplyStyle picks).
	R.edgeLightFrame.pieces = R.edgeLightFrame.glass

	-- The ground breaking under the words when a buff is refused: a crack of
	-- light along the bottom band, from the icon's edge toward the right, from
	-- Textures/Crack.tga. Its alpha alone is animated, never its shape.
	R.crackFrame = CreateFrame("Frame", nil, R.art)
	R.crackFrame:SetAlpha(0)
	R.crackFrame.band = R.crackFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	R.crackFrame.band:SetTexture(CRACK)
	R.crackFrame.band:SetBlendMode("ADD")
	R.crackFrame.band:SetAllPoints(R.crackFrame)

	-- Two rules of light along the panel's top and bottom edges, drawn out from
	-- the icon as the panel comes up (the level-up banner's two lines), on
	-- frames of their own, parked at nothing between. A level above art, like
	-- every frame of light, and so under the text.
	for _, which in ipairs({ "ruleTop", "ruleBottom" }) do
		local rule = CreateFrame("Frame", nil, R.art)
		rule:SetAlpha(0)
		rule.band = rule:CreateTexture(nil, "OVERLAY", nil, 1)
		rule.band:SetTexture(RULE)
		rule.band:SetBlendMode("ADD")
		rule.band:SetAllPoints(rule)
		R[which] = rule
	end
	-- And the glint that runs each rule when a favour arrives: a child of the
	-- art rather than of its rule, so its alpha is its own and it is seen while
	-- the rule it runs rests at nothing; a level over the rules; hung from its
	-- rule's left end (a plain frame on a plain frame).
	for _, which in ipairs({ "glintTop", "glintBottom" }) do
		local glint = CreateFrame("Frame", nil, R.art)
		glint:SetFrameLevel(R.art:GetFrameLevel() + 2)
		glint:SetAlpha(0)
		glint.band = glint:CreateTexture(nil, "OVERLAY", nil, 1)
		glint.band:SetTexture(GLINT)
		glint.band:SetBlendMode("ADD")
		glint.band:SetAllPoints(glint)
		R[which] = glint
	end
	R.glintTop:SetPoint("LEFT", R.ruleTop, "LEFT", 0, 0)
	R.glintBottom:SetPoint("LEFT", R.ruleBottom, "LEFT", 0, 0)

	-- Text sits on its own frame so a target change can cross-fade all of it
	-- at once rather than swapping strings mid-read.
	R.textLayer = CreateFrame("Frame", nil, R.art)
	R.textLayer:SetAllPoints()
	-- Over every frame of light, by level and not by the order they were made
	-- in: the rings, the halo and the band across the panel pass under the
	-- letters.
	R.textLayer:SetFrameLevel(R.art:GetFrameLevel() + lib.TEXT_LEVEL)

	R.nameText = R.textLayer:CreateFontString(nil, "OVERLAY")
	R.nameText:SetJustifyH("LEFT")
	R.nameText:SetWordWrap(false)
	R.nameText:SetShadowColor(0, 0, 0, 0.9)
	R.nameText:SetShadowOffset(1, -1)

	R.subText = R.textLayer:CreateFontString(nil, "OVERLAY")
	R.subText:SetJustifyH("LEFT")
	R.subText:SetWordWrap(false)
	R.subText:SetShadowColor(0, 0, 0, 0.8)
	R.subText:SetShadowOffset(1, -1)

	R.countChip = Solid(R.art, "ARTWORK", 1)
	R.countText = R.textLayer:CreateFontString(nil, "OVERLAY")
	R.countText:SetJustifyH("CENTER")

	-- The highlight layer only reacts to the mouse on a Button, so it belongs
	-- to the button itself rather than to the art frame.
	-- Faint: the bezel's lift says the cursor is there.
	R.button:SetHighlightTexture(WHITE, "ADD")
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.03) end

	-- The list of who is next hangs outside the panel, so it gets a background
	-- of its own -- the panel's at a lower alpha, divided by a hairline -- or
	-- the rows are text lying on the world.
	R.queueBack = Solid(R.art, "BACKGROUND", -6)
	R.queueBack:Hide()
	R.queueHair = Solid(R.art, "BORDER", 1)
	R.queueHair:Hide()

	R.queueRows = {}
	R.queueBars = {}
	R.queueIcons = {}
	for i = 1, 5 do
		local fs = R.art:CreateFontString(nil, "OVERLAY")
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetShadowColor(0, 0, 0, 0.9)
		fs:SetShadowOffset(1, -1)
		R.queueRows[i] = fs
		-- Three pixels of the reason colour before each row: priority is the
		-- one thing about the list worth knowing at a glance.
		local bar = Solid(R.art, "ARTWORK", 1)
		bar:Hide()
		R.queueBars[i] = bar
		-- The icon of the buff the row offers, between the bar and the name.
		local icon = R.art:CreateTexture(nil, "ARTWORK")
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:Hide()
		R.queueIcons[i] = icon
	end
	-- And each name as a button of its own, to press (Rows.lua).
	self:CreateRows()

	self:BuildAnimations()

	-- Everything only the three looks drawn here use, which a look from
	-- Looks/ hides (ApplyLook) and ApplyStyle puts back.
	local parts = { R.panel, R.accentTop, R.accentBottom, R.sweepFrame,
		R.glowFrame, R.rimFrame, R.bezel, R.bezelHover, R.iconShade, R.burstFrame, R.shineFrame, R.countChip,
		R.resultFill, R.queueBack, R.queueHair, R.ruleTop, R.ruleBottom, R.glintTop, R.glintBottom,
		R.edgeLightFrame, R.crackFrame, R.washFrame }
	for _, list in ipairs({ R.shadows, R.edges, R.queueBars, R.queueIcons, R.pane, R.glassLight, R.tooltipRim,
		R.fx.frames }) do
		for _, part in ipairs(list) do parts[#parts + 1] = part end
	end
	self.builtinParts = parts

	for _, script in ipairs(BUTTON_SCRIPTS) do
		R.button:SetScript(script[1], script[2])
	end

	R.button:Hide()
end

function Prompt:AccentColor(reason)
	local p = ns.db.profile.prompt
	if not p.accentByReason then return unpackColor(p.accentColor, { 0.45, 0.4, 0.9, 1 }) end
	local c = ReasonColor(reason)
	return c[1], c[2], c[3], 1
end

function Prompt:ApplyStyle()
	if not R.button then return end
	-- The fight's dim is art's alpha, which a fight allows: a change to "Dim
	-- the prompt in combat" shows at once rather than at the next fight.
	self:ReapplyCombatDim()
	if InCombatLockdown() then
		self.pendingStyle = true
		return
	end
	self.pendingStyle = nil

	local p = ns.db.profile.prompt
	local style = p.style or "glass"
	local glass = style == "glass"
	-- A look from Looks/, or nil for the three drawn here. The one it replaces
	-- takes down everything it drew and gives back what it borrowed.
	local look = ns.Looks.Get(style)
	if S.activeLook and S.activeLook ~= look then S.activeLook:Hide() end
	S.activeLook = look

	R.button:SetSize(p.width, p.height)
	R.button:SetScale(p.scale)
	R.button:SetAlpha(p.alpha)
	R.button:ClearAllPoints()
	-- Stored offsets are in UIParent's units and SetPoint reads the frame's own
	-- scaled ones, so they are divided by the scale. FinishDrag converts back.
	R.button:SetPoint(p.point, UIParent, p.relPoint, p.x / p.scale, p.y / p.scale)
	if look then return self:ApplyLook(p, look) end

	-- Put back what a look of its own hid: the three frames of light, and the
	-- button's square highlight, which it draws rounded itself.
	R.glowFrame:Show()
	R.rimFrame:Show()
	R.burstFrame:Show()
	R.shineFrame:Show()
	R.ruleTop:Show()
	R.ruleBottom:Show()
	R.glintTop:Show()
	R.glintBottom:Show()
	R.crackFrame:Show()
	R.washFrame:Show()
	-- The edge's light needs an edge: Minimal has none.
	R.edgeLightFrame:SetShown(style ~= "minimal")
	R.fx:SetShown(true)
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.03) end

	local br, bg, bb, ba = unpackColor(p.bgColor, { 0.04, 0.04, 0.06, 0.88 })
	local framed = style == "framed"
	-- The nine-slices' corners: as drawn, or what half the height leaves.
	local corner = math.min(PANE_CORNER, math.floor(p.height / 2) - 1)
	local rimCorner = math.min(RIM_CORNER, math.floor(p.height / 2) - 1)

	-- panel
	if style == "minimal" then
		R.panel:Hide()
		for _, t in ipairs(R.shadows) do t:Hide() end
		for _, t in ipairs(R.pane) do t:Hide() end
		for _, t in ipairs(R.glassLight) do t:Hide() end
	else
		-- The framed look keeps its flat panel and its rim, and gets only
		-- the dark rim of the shadow under it: the rest is the glass's depth.
		-- The steps are whole rectangles, so they darken the panel's own
		-- footprint as well as the margin: drawn for the default opacity, they
		-- fade with the panel's, or one made see-through stayed a dark box.
		local shadowK = math.min(1, ba / SHADOW_AT)
		for i, t in ipairs(R.shadows) do
			t:SetShown(glass or i == 1)
			t:SetVertexColor(0, 0, 0, SHADOW_STEPS[i][2] * shadowK)
		end
		-- Vertical gradients run bottom-to-top, so the darker stop goes first.
		R.panel:SetShown(framed)
		Gradient(R.panel, "VERTICAL", br * 0.62, bg * 0.62, bb * 0.72, ba, br, bg, bb, ba)
		-- The glass: the same gradient written on the pane's nine pieces, each
		-- given the two colours at the ends of its own rows (the top row is
		-- the top `corner` units, the middle the rest, the bottom row the
		-- bottom `corner`), so the nine read as one pane. Nine Gradient calls,
		-- here at ApplyStyle only.
		local function paneRows(f0, f1)
			local k0, k1 = 0.62 + 0.38 * f0, 0.62 + 0.38 * f1
			local kb0, kb1 = 0.72 + 0.28 * f0, 0.72 + 0.28 * f1
			return br * k0, bg * k0, bb * kb0, ba, br * k1, bg * k1, bb * kb1, ba
		end
		local split = corner / p.height
		PlaceSlice(R.pane, R.art, corner)
		for i, t in ipairs(R.pane) do
			t:SetShown(glass)
			if i <= 3 then
				Gradient(t, "VERTICAL", paneRows(1 - split, 1))
			elseif i <= 6 then
				Gradient(t, "VERTICAL", paneRows(split, 1 - split))
			else
				Gradient(t, "VERTICAL", paneRows(0, split))
			end
		end
		-- The light on the glass, at the panel's own opacity, so a panel the
		-- player has made mostly see-through does not keep a bright edge
		-- floating on its own.
		PlaceSlice(R.glassLight, R.art, corner)
		for _, t in ipairs(R.glassLight) do
			t:SetShown(glass)
			t:SetVertexColor(1, 1, 1, LIGHT_ALPHA * ba)
		end
	end

	-- The rim, on the framed look only; its colour is set once the ink has
	-- read the panel, below. The four lines it replaced stay hidden.
	PlaceSlice(R.tooltipRim, R.art, rimCorner)
	for _, t in ipairs(R.tooltipRim) do t:SetShown(framed) end
	for _, edge in ipairs(R.edges) do edge:Hide() end

	-- The edge's light: the look's own material laid as the material is, so
	-- the flash lands on the cut edge or the rail exactly. The middle piece
	-- carries no edge (the glass's is empty, as is the rim's inside) and stays
	-- dark, so nothing lights under the words.
	local lit = R.edgeLightFrame
	PlaceSlice(lit.glass, lit, corner)
	PlaceSlice(lit.rim, lit, rimCorner)
	for i, t in ipairs(lit.glass) do t:SetShown(glass and i ~= 5) end
	for i, t in ipairs(lit.rim) do t:SetShown(framed and i ~= 5) end
	lit.pieces = framed and lit.rim or lit.glass

	local mode = p.accentMode or "icon"
	-- On every built-in look: on the framed look it is an inlay inside the
	-- rim, three units in (the two-unit rail and a unit of panel).
	local showAccent = (mode == "stripe" or mode == "both")
	local inlay = framed and 3 or 0
	R.accentTop:ClearAllPoints()
	R.accentTop:SetPoint("TOPLEFT", inlay, 0)
	R.accentBottom:ClearAllPoints()
	R.accentBottom:SetPoint("BOTTOMLEFT", inlay, 0)
	R.sweepFrame:ClearAllPoints()
	R.sweepFrame:SetPoint("TOPLEFT", inlay, 0)
	R.accentTop:SetShown(showAccent)
	R.accentBottom:SetShown(showAccent)
	R.accentTop:SetHeight(p.height / 2)
	R.accentBottom:SetHeight(p.height / 2)
	R.sweepFrame:SetShown(showAccent)

	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT

	-- icon
	local textX = 10
	R.icon:ClearAllPoints()
	R.bezel:ClearAllPoints()
	R.bezelHover:ClearAllPoints()
	R.glowFrame:ClearAllPoints()
	R.rimFrame:ClearAllPoints()
	if p.showIcon then
		R.icon:SetSize(p.iconSize, p.iconSize)
		R.icon:SetPoint("LEFT", ICON_X, 0)
		R.icon:Show()

		-- Where the halos start: the ring the bezel replaced was two units
		-- with the reason colour on it, one without, and a unit of dark, so
		-- the light keeps the room it had and breathes on the bezel's edge.
		local ring = (p.accentMode == "icon" or p.accentMode == "both") and 2 or 1
		local outer = ring + 1
		-- The bezel, centred on the icon, which fills its hole: iconSize /
		-- BEZEL_FRAME across, a sixth of the icon beyond it each side (5 units
		-- at 30). Never taller than the panel: when that cap bites, the hole
		-- shrinks under the icon, which draws over it.
		local bezelSize = math.min(p.iconSize / BEZEL_FRAME, p.height - 1)
		for _, t in ipairs({ R.bezel, R.bezelHover }) do
			t:SetPoint("CENTER", R.icon, "CENTER", 0, 0)
			t:SetSize(bezelSize, bezelSize)
			t:Show()
		end
		-- Darkest at the bottom edge and gone by the middle: the icon reads as
		-- set into the panel rather than printed on it.
		R.iconShade:ClearAllPoints()
		R.iconShade:SetPoint("BOTTOMLEFT", R.icon, "BOTTOMLEFT")
		R.iconShade:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		R.iconShade:SetHeight(math.max(2, math.floor(p.iconSize * 0.55)))
		Gradient(R.iconShade, "VERTICAL", 0, 0, 0, 0.38, 0, 0, 0, 0)
		R.iconShade:Show()

		if R.cooldown then
			R.cooldown:ClearAllPoints()
			R.cooldown:SetAllPoints(R.icon)
		end

		-- A circular icon is available where masks are, but it reads as a
		-- portrait rather than a spell, so it stays opt-in.
		local round = false
		if p.roundIcon and R.art.CreateMaskTexture and R.icon.AddMaskTexture then
			if not R.iconMask then
				local ok, mask = pcall(R.art.CreateMaskTexture, R.art)
				if ok and mask then
					mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
						"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
					R.iconMask = mask
					pcall(R.icon.AddMaskTexture, R.icon, mask)
				end
			end
			if R.iconMask then
				R.iconMask:ClearAllPoints()
				R.iconMask:SetAllPoints(R.icon)
				R.iconMask:Show()
				-- A square shade over a round icon would poke out at its
				-- corners.
				R.iconShade:Hide()
				-- The mask art doubles as the swipe texture, as the client's
				-- own round buttons do.
				if R.cooldown then
					Try(R.cooldown, "SetSwipeTexture", "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
				end
				round = true
			end
		else
			if R.iconMask then R.iconMask:Hide() end
			if R.cooldown then Try(R.cooldown, "SetSwipeTexture", WHITE) end
		end
		-- The bezel in the icon's shape: the round twin round a round icon.
		R.bezel:SetTexture(round and BEZEL_ROUND or BEZEL)
		R.bezelHover:SetTexture(round and BEZEL_ROUND or BEZEL)

		-- The halo starts where the ring stops and ends at the panel's edge
		-- (past it, light read as bars stuck to the prompt), reaching further
		-- sideways where there is more room. A round icon wears the ring
		-- instead.
		-- Where the room runs out, so does the light: the distance from the
		-- icon's middle to the text (less a margin), to the panel's left edge
		-- and to its top and bottom edges (less a margin) is what the rings,
		-- the echo and the halo that flares are held inside (Effects.lua).
		local half = p.iconSize / 2
		local limitH = half + math.min(ICON_GAP - lib.TEXT_MARGIN, ICON_X - lib.EDGE_MARGIN)
		local limitV = p.height / 2 - lib.EDGE_MARGIN
		local limit = math.min(limitH, limitV)
		local sy = math.max(0, math.min(8, math.floor((p.height - p.iconSize) / 2) - outer))
		local sx = math.max(2, math.min(8, 10 - outer))
		local roundSize = round and p.iconSize or nil
		-- The bezel's lip is round at its corners and the halos' inner edge
		-- is square, so a lip the light lies on along the sides turns its
		-- corner inside the gap, out of the light: a dark notch at each corner
		-- of an owed bezel. Where the lip along the sides is in the light, the
		-- light is carried in at each corner as far as the lip comes, and the
		-- bezel reads as one lit frame (none where the lip is out of the
		-- light all round, or round a round icon).
		local lipCorner = bezelSize * lib.BEZEL_LIP_CORNER
		local fill = half + outer < bezelSize * lib.BEZEL_LIP_SIDE
			and math.max(0, half + outer - lipCorner) or 0
		R.glowFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.glowFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		PlaceHalo(R.glowHalo, R.glowFrame, sx, sy, outer, roundSize, fill)
		R.burstFrame:ClearAllPoints()
		R.burstFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.burstFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		local deep = self:FitBurst(limit, half, outer, round and p.iconSize / lib.GLOW_RING_AT / 2 or nil)
		PlaceHalo(R.burstHalo, R.burstFrame, deep, deep, outer, roundSize, fill)
		-- The rim of warm white hugs the ring, a few units deep.
		R.rimFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.rimFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		local rim = math.max(0, math.min(3, limit - half - outer))
		PlaceHalo(R.rimHalo, R.rimFrame, rim, rim, outer, roundSize, fill)
		PaintHalo(R.rimHalo, WARM_WHITE[1], WARM_WHITE[2], WARM_WHITE[3], 1)
		-- The rings spread from just outside the ring, in the shape of the
		-- icon, and the icon's echo wears the same shape.
		R.fx:Place(R.icon, R.fx.ThinPad(p.iconSize, outer + 1), p.iconSize)
		R.fx:Shape(round, RING, RING_SQ, round and PORTRAIT_MASK or nil)
		R.fx:Fit(limitH, limitV, lib.SHAKE_LEFT)
		-- A round sweep keeps its leading edge round.
		if R.cooldown and R.cooldown.SetUseCircularEdge then R.cooldown:SetUseCircularEdge(round) end

		textX = ICON_X + p.iconSize + ICON_GAP
	else
		R.icon:Hide()
		R.bezel:Hide()
		R.bezelHover:Hide()
		R.iconShade:Hide()
		if R.iconMask then R.iconMask:Hide() end
	end
	-- Whether there is an icon to sweep, and a cooldown running to sweep it
	-- with, is SyncCooldown's to decide; the settings behind both just changed.
	self:SyncCooldown()

	-- The wave bursts from just right of the icon (a plain frame may hang from
	-- a texture) and runs to two units short of the panel's end: about a fifth
	-- of the panel wide, as tall as the panel, so the distance it travels is
	-- what is left of the width past the icon, less its own. With no icon it
	-- starts where the rules do.
	local shineX = p.showIcon and (ICON_X + p.iconSize + SHINE_GAP) or RULE_X0
	local shineWidth = math.max(SHINE_MIN, math.min(SHINE_MAX, math.floor(p.width * SHINE_SHARE)))
	R.shineFrame:ClearAllPoints()
	if p.showIcon then
		R.shineFrame:SetPoint("LEFT", R.icon, "RIGHT", SHINE_GAP, 0)
	else
		R.shineFrame:SetPoint("LEFT", R.art, "LEFT", RULE_X0, 0)
	end
	R.shineFrame:SetSize(shineWidth, p.height)
	if R.shineFrame.anim then R.shineFrame.anim.move:SetOffset(p.width - shineX - shineWidth - RULE_END, 0) end

	-- The crack lies along the bottom band under the words, from the wave's
	-- start to a third short of the right edge, a unit up from the bottom and
	-- a seventh of the height tall (two units at the smallest panel, six at the
	-- default): under the reason line's bottom at every height.
	R.crackFrame:ClearAllPoints()
	R.crackFrame:SetPoint("BOTTOMLEFT", R.art, "BOTTOMLEFT", shineX, CRACK_INSET)
	R.crackFrame:SetPoint("BOTTOMRIGHT", R.art, "BOTTOMRIGHT", -math.floor(p.width * CRACK_END), CRACK_INSET)
	R.crackFrame:SetHeight(math.max(CRACK_MIN, math.min(CRACK_MAX, math.floor(p.height / 7))))

	-- The two rules of light: as thick as the height allows (a unit at 20, two
	-- at the default 44, three from 66), a unit and a half inside the top and
	-- the bottom, from the icon's middle to two units short of the right edge;
	-- and the glint that runs each, as tall as its rule, with the distance it
	-- has to run written into its slide. Minimal has no panel for them to lie
	-- on, so it draws them at a little over half strength.
	local ruleHeight = math.max(1, math.min(3, math.floor(p.height / 22)))
	local ruleX = p.showIcon and (ICON_X + p.iconSize / 2) or RULE_X0
	R.ruleTop:ClearAllPoints()
	R.ruleTop:SetPoint("TOPLEFT", R.art, "TOPLEFT", ruleX, -RULE_INSET)
	R.ruleTop:SetPoint("TOPRIGHT", R.art, "TOPRIGHT", -RULE_END, -RULE_INSET)
	R.ruleTop:SetHeight(ruleHeight)
	R.ruleBottom:ClearAllPoints()
	R.ruleBottom:SetPoint("BOTTOMLEFT", R.art, "BOTTOMLEFT", ruleX, RULE_INSET)
	R.ruleBottom:SetPoint("BOTTOMRIGHT", R.art, "BOTTOMRIGHT", -RULE_END, RULE_INSET)
	R.ruleBottom:SetHeight(ruleHeight)
	local glintRun = (p.width - RULE_END - ruleX) - GLINT_LENGTH
	for _, glint in ipairs({ R.glintTop, R.glintBottom }) do
		glint:SetSize(GLINT_LENGTH, ruleHeight)
		if glint.run then glint.run.move:SetOffset(glintRun, 0) end
	end
	S.ruleStrength = style == "minimal" and 0.6 or 1.0

	-- count chip: sized from the font, so large fonts do not spill out of it;
	-- at the default 13 it is the old 20 by 14, with 28 reserved.
	local countSize = math.max(8, p.fontSize - 3)
	-- A digit is about half the font's size across: room for four.
	local chipWidth = countSize * 2
	-- Kept inside the panel at the top of the slider, where a chip grown from
	-- the font would otherwise stand taller than the prompt it is drawn on.
	local chipHeight = math.min(countSize + 4, math.max(8, p.height - 6))
	R.countChip:ClearAllPoints()
	R.countChip:SetPoint("RIGHT", -7, 0)
	R.countChip:SetSize(chipWidth, chipHeight)
	R.countChip:SetShown(false)
	Gradient(R.countChip, "VERTICAL", 1, 1, 1, 0.03, 1, 1, 1, 0.09)

	-- What the lines keep clear while the chip is up: the chip, its 7px inset
	-- and a point of gap.
	local chipRoom = p.showCount and (chipWidth + 8) or EDGE_ROOM

	-- text
	-- Two lines need both fonts plus the insets: see ns.TwoLineHeight.
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize)

	R.countText:ClearAllPoints()
	R.countText:SetPoint("CENTER", R.countChip, "CENTER", 0, 0)
	-- Fonts, colours, shadows and the lines' anchors, from the panel colour.
	-- The count's font is the size the chip was just sized from.
	StyleText(p, style, fontPath, textX, chipRoom, twoLine, countSize)
	-- The grey just written over the reason line's tint, and the bezel and the
	-- stripe may have changed shape: the next PaintAccent paints in full.
	S.accentPainted = nil

	-- The framed look's rim, now the ink has read the panel: pale metal on a
	-- dark panel, dark metal on a pale one (StyleText's ink.light says which),
	-- mixed a fifth toward the panel colour and a little more opaque than it,
	-- so a white panel keeps a frame.
	local metal = RIM_DARK
	if ink.light then metal = RIM_PALE end
	for _, t in ipairs(R.tooltipRim) do
		t:SetVertexColor(metal[1] + (br - metal[1]) * RIM_MIX, metal[2] + (bg - metal[2]) * RIM_MIX,
			metal[3] + (bb - metal[3]) * RIM_MIX, math.min(1, ba + 0.10))
	end

	-- Rows get one anchor and an explicit width: TOPLEFT and RIGHT together
	-- fight over the vertical centre. Which way the list hangs is settled here.
	S.queueAbove = QueueGoesAbove()
	-- With the spell icon on, each row wears the icon of its own buff, sized
	-- from the row's font, in the margin left of its text, under the prompt's
	-- own icon: the text keeps the whole width it had, which a long name and
	-- its reason need (pushed right by the icon, one was drawn cut).
	local iconW = p.showIcon and (math.max(7, p.fontSize - 3) + 2) or 0
	-- No wider than that margin holds with the bar beside it (a small prompt
	-- icon under a large font), and none where too little is left.
	if iconW > textX - 12 then iconW = textX - 12 end
	if iconW < 7 then iconW = 0 end
	local rowX = textX
	-- Kept for PaintQueue, which re-places the rows when the list hangs above
	-- and therefore needs the same inset this loop uses.
	S.queueTextX = rowX
	local rowHeight = p.fontSize + 4
	local rowCount = math.max(1, p.queueRows or 1)
	for i, fs in ipairs(R.queueRows) do
		fs:ClearAllPoints()
		if S.queueAbove then
			-- Counted down from the top of the block, so the list reads top to
			-- bottom.
			fs:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", rowX, 4 + (rowCount - i) * rowHeight)
		else
			fs:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", rowX, -4 - (i - 1) * rowHeight)
		end
		-- The font and the colour are StyleText's; the width is the room
		-- FitLine shrinks a long row into.
		local width = math.max(20, p.width - rowX - 8)
		fs:SetWidth(width)
		fit.room[fs] = width

		-- Anchored to its own row, so the icon and the bar follow the list
		-- whichever way it hangs and whatever the font size is.
		local icon = R.queueIcons[i]
		icon:ClearAllPoints()
		if iconW > 0 then
			icon:SetSize(iconW, iconW)
			icon:SetPoint("RIGHT", fs, "LEFT", -3, 0)
		end
		local bar = R.queueBars[i]
		bar:ClearAllPoints()
		bar:SetSize(3, math.max(6, p.fontSize - 2))
		bar:SetPoint("RIGHT", iconW > 0 and icon or fs, "LEFT", -4, 0)
	end
	-- The click area of each name, from the bar to the end of its text.
	self:PlaceRows(p, nil, 7 + (iconW > 0 and iconW + 3 or 0) + 1)

	-- The background behind the list; PaintQueue sets its depth from the rows
	-- filled.
	R.queueBack:ClearAllPoints()
	R.queueHair:ClearAllPoints()
	R.queueHair:SetHeight(1)
	if S.queueAbove then
		R.queueBack:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", 0, 0)
		R.queueBack:SetPoint("BOTTOMRIGHT", R.art, "TOPRIGHT", 0, 0)
		R.queueHair:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", 0, 0)
		R.queueHair:SetPoint("BOTTOMRIGHT", R.art, "TOPRIGHT", 0, 0)
	else
		R.queueBack:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", 0, 0)
		R.queueBack:SetPoint("TOPRIGHT", R.art, "BOTTOMRIGHT", 0, 0)
		R.queueHair:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", 0, 0)
		R.queueHair:SetPoint("TOPRIGHT", R.art, "BOTTOMRIGHT", 0, 0)
	end
	-- A shade darker than the panel and slightly more transparent, with a
	-- hairline of light so the two rectangles do not read as one. Only a shade
	-- on a light panel, where halving went to a mud neither text colour reads
	-- on.
	local shade = ink.light and 0.55 or 0.90
	R.queueBack:SetVertexColor(br * shade, bg * shade, bb * (ink.light and 0.66 or 0.92),
		math.min(1, ba * 0.9))
	R.queueHair:SetVertexColor(1, 1, 1, 0.07)

	self:Refresh()
end

-- ApplyStyle for a look from Looks/: the regions only the three looks here
-- use hidden, the shared ones handed over, the text styled as for any panel.
-- Out of ApplyStyle, for its upvalues.
function Prompt:ApplyLook(p, look)
	if not look.kit then look:Build(self:LookKit()) end
	-- The built-in looks' animations stopped, not only hidden: a pulse left
	-- looping on a hidden frame still loops, Calm or not.
	for _, f in ipairs({ R.glowFrame, R.rimFrame, R.sweepFrame, R.shineFrame, R.burstFrame, R.bezelHover }) do
		if f.pulse then f.pulse:Stop() end
		if f.anim then f.anim:Stop() end
		if f.arrive then f.arrive:Stop() end
		if f.reject then f.reject:Stop() end
		if f.enter then f.enter:Stop() end
		if f.leave then f.leave:Stop() end
	end
	R.fx:Stop()
	-- The entrance's rules and the glint that runs them, and the words'
	-- reveal, which is textLayer's: stopped, and the words put at full. Safe
	-- here, out of combat and only as a look from Looks/ takes the panel; its
	-- own fight dim owns textLayer's alpha from this point on.
	for _, g in ipairs({ R.ruleTop.draw, R.ruleBottom.draw, R.glintTop.run, R.glintBottom.run,
		R.textLayer.reveal, R.ruleTop.flare, R.ruleBottom.flare, R.ruleTop.flicker, R.edgeLightFrame.land,
		R.edgeLightFrame.reject, R.crackFrame.split, R.washFrame.fade }) do
		if g and g:IsPlaying() then g:Stop() end
	end
	R.textLayer:SetAlpha(1)
	S.glintPlaying = nil
	-- And the icon in colour: a refusal's grey is the three looks' own, and a
	-- look from Looks/ greys the icon itself when it wants to.
	self:UngreyIcon()
	-- The lift under the cursor let go at once: a texture of the looks drawn
	-- here, parked at nothing while a look of its own is up, and forgetting
	-- where the cursor had it so the next arrival lifts it again.
	R.bezelHover:SetAlpha(0)
	R.bezelHover.level, R.bezelHover.goal, R.bezelHover.start = 0, nil, nil
	for _, part in ipairs(self.builtinParts) do part:Hide() end
	if R.iconMask then R.iconMask:Hide() end
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0) end
	local above = QueueGoesAbove()
	S.queueAbove = above
	local textX, chipRoom = look:Apply(p, above)
	-- The look lays the rows out itself (PaintQueue); each name's click area
	-- hangs off the row's own text.
	self:PlaceRows(p, look)
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize, p.style)
	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
	StyleText(p, p.style, fontPath, textX, chipRoom or EDGE_ROOM, twoLine, math.max(7, p.fontSize - 3))
	if look.Styled then look:Styled(p, twoLine) end
	S.accentPainted = nil
	self:SyncCooldown()
	self:Refresh()
end

-- What a look is handed to draw with: see Looks/Looks.lua.
function Prompt:LookKit()
	if not self.kit then
		self.kit = {
			button = R.button, art = R.art, textLayer = R.textLayer, icon = R.icon, cooldown = R.cooldown,
			name = R.nameText, sub = R.subText, count = R.countText, rows = R.queueRows,
			fit = fit, ink = ink,
			Gradient = Gradient, Legible = Legible, TextWidth = TextWidth,
			SetLine = SetLine, FitLine = FitLine, FullEffects = FullEffects,
			ReasonColor = ReasonColor, OUTCOME_SECONDS = OUTCOME_SECONDS,
			-- The rings and the glows' tints, which a look draws in its own art.
			FX = lib.NewFX, Tint = Tint, WARM_WHITE = WARM_WHITE,
			-- How far they may spread (Prompt/Effects.lua): the files a look
			-- draws its rings in, the scale at which a texture reaches a
			-- limit, the margins kept from the text and the panel's edges,
			-- how far a refusal's shake swings the text, and the level of
			-- textLayer above art, over every frame of light.
			RingArt = lib.RingArt, CapScale = lib.CapScale, CapLock = lib.CapLock, TEXT_MARGIN = lib.TEXT_MARGIN,
			EDGE_MARGIN = lib.EDGE_MARGIN, SHAKE_LEFT = lib.SHAKE_LEFT, TEXT_LEVEL = lib.TEXT_LEVEL,
		}
	end
	return self.kit
end

function Prompt:PaintAccent(reason)
	local p = ns.db.profile.prompt
	local mode = p.accentMode or "icon"
	local r, g, b = self:AccentColor(reason)

	-- Runs on every repaint and the colour rarely changes, so the same colour
	-- again is nothing to do. ApplyStyle and a refusal's red ring forget the
	-- key when they write over these textures.
	local key = ("%s:%.3f:%.3f:%.3f:%s"):format(mode, r, g, b, tostring(S.tintSub))
	if key == S.accentPainted then return end
	S.accentPainted = key
	if S.activeLook then return S.activeLook:PaintReason(r, g, b, reason, mode) end

	-- Brightest at the middle, fading towards both ends.
	Gradient(R.accentTop, "VERTICAL", r, g, b, 1, r, g, b, 0.15)
	Gradient(R.accentBottom, "VERTICAL", r, g, b, 0.15, r, g, b, 1)
	R.sweep:SetVertexColor(r, g, b, 1)
	PaintHalo(R.glowHalo, r, g, b, 1)

	-- The bezel: the reason colour on its metal where the marker asks for it,
	-- a neutral metal otherwise (the light and the shade are in the file), and
	-- the same metal lifted toward white under the cursor.
	local mr, mg, mb = NEUTRAL_METAL[1], NEUTRAL_METAL[2], NEUTRAL_METAL[3]
	if mode == "icon" or mode == "both" then mr, mg, mb = r, g, b end
	R.bezel:SetVertexColor(mr, mg, mb, 1)
	local hr, hg, hb = Tint(mr, mg, mb, HOVER_LIFT)
	R.bezelHover:SetVertexColor(hr, hg, hb, 1)

	-- The reason line, warmed a little towards the same colour so the two agree
	-- at a glance -- but not with accents off, nor on a light panel where the
	-- tint costs contrast. The tinted grey is held to the plain one's contrast.
	local mix = (S.tintSub and mode ~= "off") and 0.35 or 0
	local base = ink.sub or GREYS.panel.sub
	local sr, sg, sb = Legible(base[1] + (r - base[1]) * mix, base[2] + (g - base[2]) * mix,
		base[3] + (b - base[3]) * mix, TEXT_CONTRAST)
	R.subText:SetTextColor(sr, sg, sb, 1)
end

-- The pieces of the panel, handed out so tests can read back what the prompt
-- wrote: many failures here have no symptom but how they look.
function Prompt:Regions()
	return {
		art = R.art,
		name = R.nameText,
		sub = R.subText,
		count = R.countText,
		-- The chip beside its number: both are sized from one font, and a chip
		-- smaller than its digits throws nothing.
		chip = R.countChip,
		fill = R.resultFill,
		-- The four lines the framed look wore before its rim: kept, never
		-- shown, gone next release.
		edges = R.edges,
		-- The glass's pane and the light on it, the framed look's rim: nine
		-- pieces each.
		pane = R.pane,
		glassLight = R.glassLight,
		tooltipRim = R.tooltipRim,
		-- The two carriers of the reason colour: the bezel round the icon
		-- (switched off by hiding the icon), the stripe. And the bezel's lighter
		-- twin, faded up under the cursor.
		bezel = R.bezel,
		bezelHover = R.bezelHover,
		accentTop = R.accentTop,
		-- What "When someone buffs you" animates: whether one played is the
		-- only evidence the setting does anything.
		sweep = R.sweepFrame,
		glow = R.glowFrame,
		glowStrips = R.glowHalo and R.glowHalo.strips,
		glowRound = R.glowHalo and R.glowHalo.round,
		burstStrips = R.burstHalo and R.burstHalo.strips,
		burstRound = R.burstHalo and R.burstHalo.round,
		-- The look's effects, for the same reason. The cooldown is nil on a
		-- client without the template.
		cooldown = R.cooldown,
		burst = R.burstFrame,
		shine = R.shineFrame,
		-- The band's own texture, whose vertex colour carries its strength.
		shineBand = R.shineBand,
		-- The warm white rim that breathes with the glow, the rings and the
		-- icon's echo, the settle and Calm's entrance.
		rim = R.rimFrame,
		rimStrips = R.rimHalo and R.rimHalo.strips,
		fx = R.fx,
		settle = R.art and R.art.settle,
		introCalm = R.art and R.art.introCalm,
		-- The two rules of light the entrance draws along the panel's edges
		-- (each frame's `draw` group and its `band` texture), the glints that
		-- run them when a favour arrives (`run`, `band`), and the words'
		-- reveal, held back a beat behind the rules.
		rules = { R.ruleTop, R.ruleBottom },
		glints = { R.glintTop, R.glintBottom },
		reveal = R.textLayer and R.textLayer.reveal,
		-- The panel's edge lit for an outcome (its `pieces`, the look's own
		-- of its `glass` and `rim` slices, `land` and `reject`), the crack
		-- under the words (`band`, `split`) and the outcome's wash (the frame
		-- `fill` is drawn on, and its `fade`).
		edgeLight = R.edgeLightFrame,
		crack = R.crackFrame,
		wash = R.washFrame,
		shake = R.textLayer and R.textLayer.shake,
		intro = R.art and R.art.intro,
		outro = R.art and R.art.outro,
		comeback = R.art and R.art.comeback,
		shadows = R.shadows,
		iconShade = R.iconShade,
		icon = R.icon,
		queueBack = R.queueBack,
		queueHair = R.queueHair,
		rows = R.queueRows,
		bars = R.queueBars,
		-- The icon at each row's left (the three looks drawn here), and each
		-- name's button: both for tests to read what was drawn and what can be
		-- pressed.
		rowIcons = R.queueIcons,
		rowButtons = R.rowButtons,
		-- The rest of what only the three looks here draw, and the look from
		-- Looks/ in use (nil for those three), whose own regions are its `own`.
		panel = R.panel,
		accentBottom = R.accentBottom,
		builtin = Prompt.builtinParts,
		look = S.activeLook,
		textLayer = R.textLayer,
	}
end
