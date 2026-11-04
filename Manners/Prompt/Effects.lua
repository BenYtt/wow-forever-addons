-- Manners -- the prompt's animations: the entrance, the text's cross-fade and
-- shake, the favour's glow and sweep, a landed buff's rings and light, the fade
-- out after the last buff, the cooldown sweep and the dim for a fight.
--
-- Every gesture means one thing and moves one way:
--   * the panel COMING UP unfurls (the three looks drawn here): it rises as
--     two rules of light draw out from the icon along its top and bottom
--     edges, and the words arrive a beat behind them (under 0.5 s);
--   * a favour ARRIVING converges: the icon's echo drops onto it and a bloom
--     of the reason's light gathers round its ring, and a glint runs the two
--     rules from the icon to the panel's end (under 0.5 s);
--   * a buff LANDING strikes and radiates: rings spread from the icon, the
--     panel's edge lights in the reason's colour, a wave of the same light
--     bursts from the icon's edge across the panel, the glow flares, the panel
--     settles and the outcome's wash fades rather than cuts (under 0.7 s);
--   * a REFUSAL breaks the ward: a red-amber ring snaps in on the icon, the
--     edge flashes red, the ground cracks along the bottom band under the
--     words, the top rule sputters, the icon greys for the outcome and the
--     text shakes its head, the shakes dying away (under 0.5 s);
--   * somebody OWED breathes: the reason's light and a warm white rim, a slow
--     2.4 s breath, never a flash.
-- All of it plays on frames of the art, which is not protected: nothing here
-- touches the secure button or the rows, in a fight or out of one. Nothing is
-- polled; every group is started by an event (an arrival, an outcome, a
-- cooldown) and parks what it lit at nothing when it ends or is stopped.
-- "Calm" is fades only: no scale, no shake, no rings, no light across.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local OUTCOME_SECONDS, Gradient, Try, PaintHalo = lib.OUTCOME_SECONDS, lib.Gradient, lib.Try, lib.PaintHalo
local RING, RING_SQ, RING_AT, Tint, WARM_WHITE = lib.RING, lib.RING_SQ, lib.RING_AT, lib.Tint, lib.WARM_WHITE

-- Whether the panel is dimmed for combat, so the alpha is written once per
-- transition.
local combatHeld

---------------------------------------------------------------------------
-- building blocks
---------------------------------------------------------------------------

-- Each adds one animation to `group` and hands it back. A method this client
-- lacks leaves that detail out, never the group: all five clients have them.
local function Alpha(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Both axes alike, about the middle, unless the trailing arguments say
-- otherwise: `fromY` and `toY` give the vertical scale its own ends (a rule
-- drawn out along one axis keeps its thickness: 1, 1), and `origin` the point
-- it grows about ("LEFT": out from its left end).
local function Grow(group, from, to, duration, order, delay, smoothing, fromY, toY, origin)
	local a = group:CreateAnimation("Scale")
	if a.SetScaleFrom then a:SetScaleFrom(from, fromY or from) end
	if a.SetScaleTo then a:SetScaleTo(to, toY or to) end
	if a.SetOrigin then a:SetOrigin(origin or "CENTER", 0, 0) end
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- A scale animation's ends changed after it was made (a method this client
-- lacks leaves it as drawn, as in Grow).
local function Rescale(a, from, to)
	if from and a.SetScaleFrom then a:SetScaleFrom(from, from) end
	if to and a.SetScaleTo then a:SetScaleTo(to, to) end
end

-- A look's lock-on ring (scaled from wider down onto its place by `onto`, then
-- settled by `settle`, which a ring that only closes has none of) held to `cap`, the scale CapScale gave: wider only as
-- far as the room goes, and never past where it rests.
local function CapLock(onto, settle, from, mid, cap)
	Rescale(onto, math.min(from, cap), math.min(mid, cap))
	if settle then Rescale(settle, math.min(mid, cap), math.min(1, cap)) end
end

local function Slide(group, dx, dy, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- An animation leaves the frame at its final value, so what it lit is parked
-- back at invisible when it finishes and when it is stopped.
local function Park(group, frame)
	local function park() frame:SetAlpha(0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Playing(group)
	return group and group:IsPlaying()
end

---------------------------------------------------------------------------
-- the gestures every look shares: rings, the icon's echo
--
-- Built on frames anchored to the icon, so a look draws them over its own
-- icon wherever it puts it, in its own ring art. Looks/Looks.lua hands the
-- builder over as kit.FX.
---------------------------------------------------------------------------

-- The echo and the rings, in seconds.
local ECHO_IN, ECHO_OUT = 0.16, 0.20
local RING_SECONDS = { 0.52, 0.46 }
local RING_DELAY = { 0, 0.08 }
-- How far each ring spreads where the room allows it, as a multiple of where
-- it starts, and its brightness at the start. The room the layout leaves is
-- smaller than the 1.55 these were drawn for (see FXMethods:Fit), which caps
-- the reach; the second ring keeps its share of the first's travel.
local RING_REACH = { 1.55, 1.38 }
local RING_SHARE = { 1, (1.38 - 1) / (1.55 - 1) }
local RING_PEAK = { 0.95, 0.60 }
local REJECT_SECONDS = 0.30
-- Where a ring starts, in units inside the icon's edge: its brightest line
-- begins on the icon's face and spreads out through the edge, so there is
-- something to spread in a small room.
local RING_START_IN = 3

-- What the arrival's echo grows to at most, and the settle after it.
local ECHO_FROM, ECHO_SETTLE = 1.45, 1.10
-- How far a refusal's shake moves the text to the left at most (Panel's shake
-- below: -3 to begin with), which the ring that contracts on the icon leaves
-- room for.
local SHAKE_LEFT = 3
-- The margin kept between an effect's outer edge and the text, and and the
-- panel's top and bottom edges, in units.
local TEXT_MARGIN, EDGE_MARGIN = 2, 1

-- What each ring file draws, as fractions of its half-width: where its
-- brightest line is (`peak`) and how far out anything of it is seen at all
-- (`edge`, where its alpha falls under 2%), rounded up a little. Measured from
-- the files by the scenario that holds these to them (hunt37-effects); a look
-- registers the files it draws its rings in (kit.RingArt).
local RING_ART = {}
local function RingArt(file, peak, edge)
	RING_ART[file] = { peak = peak, edge = edge }
end
RingArt(RING, 0.773, 0.93)
RingArt(RING_SQ, 0.773, 0.93)
local function RingArtOf(file) return RING_ART[file] end
-- A file nobody described is taken to fill its frame and have its line there.
local UNKNOWN_ART = { peak = 1, edge = 1 }

-- The scale at which a texture of half-width `half` whose art is seen out to
-- `edge` of it reaches `limit` units from the icon's middle; a look uses it for
-- the lock-on rings it scales itself.
local function CapScale(limit, half, edge)
	if not (limit and half and half > 0) then return 1e9 end
	return limit / ((edge or 1) * half)
end

local FXMethods = {}
FXMethods.__index = FXMethods

-- `noEcho`: the look keeps its icon clean, so there is no echo to drop on it.
local function NewFX(parent, level, noEcho)
	local fx = setmetatable({ rings = {} }, FXMethods)
	local function frame()
		local f = CreateFrame("Frame", nil, parent)
		f:SetAlpha(0)
		if level then f:SetFrameLevel(level) end
		return f
	end

	-- Two rings, the second a beat behind and shorter, so a landing reads as
	-- a pulse rather than a single hoop. The first also snaps in when a
	-- refusal contracts onto the icon.
	for i = 1, 2 do
		local ring = { frame = frame() }
		ring.tex = ring.frame:CreateTexture(nil, "OVERLAY", nil, 3)
		ring.tex:SetTexture(RING_SQ)
		ring.tex:SetBlendMode("ADD")
		ring.tex:SetAllPoints(ring.frame)
		local land = ring.frame:CreateAnimationGroup()
		ring.landGrow = Grow(land, 1, RING_REACH[i], RING_SECONDS[i], 1, RING_DELAY[i], "OUT")
		Alpha(land, RING_PEAK[i], 0, RING_SECONDS[i], 1, RING_DELAY[i], "IN")
		Park(land, ring.frame)
		ring.land = land
		if i == 1 then
			local reject = ring.frame:CreateAnimationGroup()
			ring.rejectGrow = Grow(reject, 1.55, 0.97, REJECT_SECONDS, 1, 0, "OUT")
			Alpha(reject, 0, 0.95, 0.07, 1, 0, "OUT")
			Alpha(reject, 0.95, 0, REJECT_SECONDS - 0.07, 1, 0.07, "IN")
			Park(reject, ring.frame)
			ring.reject = reject
		end
		fx.rings[i] = ring
	end

	fx.frames = { fx.rings[1].frame, fx.rings[2].frame }
	if noEcho then return fx end

	-- The icon's echo: a copy of the spell, added over the icon, dropping onto
	-- it from larger and settling out again. Its own frame holds its own
	-- mask, so the two scale together.
	local echo = { frame = frame() }
	echo.tex = echo.frame:CreateTexture(nil, "OVERLAY", nil, 4)
	echo.tex:SetBlendMode("ADD")
	echo.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	echo.tex:SetAllPoints(echo.frame)
	if echo.frame.CreateMaskTexture and echo.tex.AddMaskTexture then
		echo.mask = echo.frame:CreateMaskTexture()
		echo.mask:SetAllPoints(echo.frame)
	end
	local drop = echo.frame:CreateAnimationGroup()
	echo.dropIn = Grow(drop, ECHO_FROM, 1, ECHO_IN, 1, 0, "OUT")
	Alpha(drop, 0, 0.62, ECHO_IN * 0.7, 1, 0, "OUT")
	echo.dropOut = Grow(drop, 1, ECHO_SETTLE, ECHO_OUT, 2, 0, "IN_OUT")
	Alpha(drop, 0.62, 0, ECHO_OUT, 2, 0, "IN")
	Park(drop, echo.frame)
	echo.drop = drop
	fx.echo = echo
	fx.frames[3] = echo.frame
	return fx
end

-- Placed round `icon`, which is `size` units across: the rings' frames `pad`
-- outside it (their texture fills them, so pad says where the ring sits), the
-- echo's frame on it. Fit says how far they may spread from there.
function FXMethods:Place(icon, pad, size)
	self.iconHalf = size / 2
	for _, ring in ipairs(self.rings) do
		ring.frame:ClearAllPoints()
		ring.frame:SetPoint("TOPLEFT", icon, "TOPLEFT", -pad, pad)
		ring.frame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", pad, -pad)
		ring.half = size / 2 + pad
	end
	local echo = self.echo
	if not echo then return end
	echo.frame:ClearAllPoints()
	echo.frame:SetAllPoints(icon)
end

-- The pad that puts the thin ring's middle `gap` units outside an icon of
-- `size` units: the file keeps its ring at RING_AT of its half-width.
function FXMethods.ThinPad(size, gap)
	return (size / 2 + gap) / RING_AT - size / 2
end

-- The ring's art, round or square, and the echo's shape (a mask file, or nil
-- for a square icon). Called whenever the icon's shape may have changed.
function FXMethods:Shape(round, roundFile, squareFile, maskFile)
	for i = 1, #self.rings do self:SetArt(i, round and roundFile or squareFile) end
	local echo = self.echo
	if not (echo and echo.mask) then return end
	if maskFile then
		echo.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		echo.mask:Show()
		if not echo.masked then
			echo.tex:AddMaskTexture(echo.mask)
			echo.masked = true
		end
	elseif echo.masked then
		echo.tex:RemoveMaskTexture(echo.mask)
		echo.mask:Hide()
		echo.masked = nil
	end
end

-- One ring drawn in another file (a look's second ring in art of its own),
-- whose reach Fit then reads.
function FXMethods:SetArt(i, file)
	local ring = self.rings[i]
	ring.tex:SetTexture(file)
	ring.art = RING_ART[file]
end

function FXMethods:SetShown(on)
	for _, f in ipairs(self.frames) do f:SetShown(on) end
end

-- How far the rings and the echo may spread, from the room the layout leaves:
-- `limitH` and `limitV` are the distances from the icon's middle to where the
-- text starts (less the margin) and to the panel's top and bottom edges (less
-- the margin), the nearer on each axis; `shake` how far the text swings
-- towards the icon in a refusal. A ring is seen out to its art's `edge` of its
-- half-width, so its scale is held where that edge reaches the limit, and it
-- spreads from where its brightest line sits just inside the icon's edge out to
-- there: where the room is small it spreads little, and where there is none
-- it flashes in place. Called whenever the layout is: not per frame.
function FXMethods:Fit(limitH, limitV, shake)
	local half = self.iconHalf
	if not half then return end
	local limit = math.max(half, math.min(limitH, limitV))
	local refuseLimit = math.max(half, math.min(limitH - (shake or 0), limitV))
	for i, ring in ipairs(self.rings) do
		local art = ring.art or UNKNOWN_ART
		local full = art.edge * ring.half
		local from = math.min(1, math.max(half * 0.6, half - RING_START_IN) / (art.peak * ring.half), limit / full)
		local to = from + (math.min(RING_REACH[i], limit / full) - from) * RING_SHARE[i]
		Rescale(ring.landGrow, from, to)
		if ring.rejectGrow then
			local out = math.max(from, math.min(RING_REACH[1], refuseLimit / full))
			local back = math.min(from, refuseLimit / full)
			Rescale(ring.rejectGrow, out, back)
		end
	end
	local echo = self.echo
	if not echo then return end
	local room = limit / half
	Rescale(echo.dropIn, math.min(ECHO_FROM, room))
	Rescale(echo.dropOut, nil, math.min(ECHO_SETTLE, room))
end

-- A buff landed: two rings spread from the icon in the colour, the second
-- paler. `strength` (default 1) is how much of the art's light a look that
-- wants restraint lets through.
function FXMethods:Land(r, g, b, strength)
	self:Stop()
	local k = strength or 1
	local r2, g2, b2 = Tint(r, g, b, 0.45)
	self.rings[1].tex:SetVertexColor(r, g, b, k)
	self.rings[2].tex:SetVertexColor(r2, g2, b2, k)
	for _, ring in ipairs(self.rings) do ring.land:Play() end
end

-- A refusal: one ring snaps in onto the icon.
function FXMethods:Refuse(r, g, b, strength)
	self:Stop()
	self.rings[1].tex:SetVertexColor(r, g, b, strength or 1)
	self.rings[1].reject:Play()
end

-- A favour arrived: the icon's echo, the spell `file`, in the colour taken
-- towards white, drops onto the icon.
function FXMethods:Arrive(file, r, g, b)
	local echo = self.echo
	if not (echo and file) then return end
	echo.drop:Stop()
	echo.tex:SetTexture(file)
	echo.tex:SetVertexColor(r, g, b, 1)
	echo.drop:Play()
end

function FXMethods:Stop()
	for _, ring in ipairs(self.rings) do
		ring.land:Stop()
		if ring.reject then ring.reject:Stop() end
	end
	if self.echo then self.echo.drop:Stop() end
end

function FXMethods:IsPlaying()
	for _, ring in ipairs(self.rings) do
		if Playing(ring.land) or Playing(ring.reject) then return true end
	end
	return self.echo ~= nil and Playing(self.echo.drop)
end

lib.NewFX, lib.RingArt, lib.CapScale, lib.Rescale, lib.CapLock, lib.RingArtOf = NewFX, RingArt, CapScale, Rescale, CapLock, RingArtOf
lib.TEXT_MARGIN, lib.EDGE_MARGIN, lib.SHAKE_LEFT = TEXT_MARGIN, EDGE_MARGIN, SHAKE_LEFT

---------------------------------------------------------------------------
-- the three looks drawn here
---------------------------------------------------------------------------

-- The panel's edge lit as a buff lands: its peak. Held to 0.40 of the light,
-- because a lit edge any brighter reads as a border drawn on, not a flash.
local EDGE_PEAK = 0.40
-- The outcome's wash: the alpha it rises to and the rest it falls to and holds
-- until the outcome runs out, per outcome (lightest for a cast nobody
-- confirmed).
local WASH_PEAK = { cast = 0.28, sent = 0.18, failed = 0.30 }
local WASH_REST = { cast = 0.10, sent = 0.08, failed = 0.12 }
-- The red-amber a refusal breaks in: the halo's and the ring's, on the edge,
-- the crack and the sputtering rule as well.
local BREAK = { 1.00, 0.42, 0.20 }

-- The edge's light in one colour: the pieces of the look in use.
local function PaintEdge(r, g, b)
	for _, t in ipairs(R.edgeLightFrame.pieces) do t:SetVertexColor(r, g, b, 1) end
end

function Prompt:BuildAnimations()
	-- Entrance: rise into place, fade in and settle. A translation (and a scale)
	-- is undone when its group ends, so the drop comes first, instantly, and
	-- the rise ends exactly where the panel belongs, with no hop at the end.
	-- The panel grows a little past its size and comes back, so it lands
	-- rather than slides: 0.33 s in all.
	local intro = R.art:CreateAnimationGroup()
	Alpha(intro, 0, 0, 0.01, 1)
	Slide(intro, 0, -8, 0.01, 1)
	Grow(intro, 0.95, 0.95, 0.01, 1)
	Alpha(intro, 0, 1, 0.22, 2, 0, "OUT")
	Slide(intro, 0, 8, 0.22, 2, 0, "OUT")
	Grow(intro, 0.95, 1.025, 0.22, 2, 0, "OUT")
	Grow(intro, 1.025, 1, 0.11, 3, 0, "IN_OUT")
	R.art.intro = intro

	-- The same on Calm: a fade, nothing that moves or grows.
	local introCalm = R.art:CreateAnimationGroup()
	Alpha(introCalm, 0, 1, 0.20, 1, 0, "OUT")
	R.art.introCalm = introCalm

	-- The panel settling as a buff lands: a small swell and back, after the
	-- light has started across it.
	local settle = R.art:CreateAnimationGroup()
	Grow(settle, 1, 1.035, 0.08, 1, 0.06, "OUT")
	Grow(settle, 1.035, 1, 0.22, 2, 0, "IN_OUT")
	R.art.settle = settle

	-- Target change: dip the text rather than swapping it under the eye.
	local swap = R.textLayer:CreateAnimationGroup()
	Alpha(swap, 1, 0.15, 0.07, 1)
	Alpha(swap, 0.15, 1, 0.13, 2, 0, "OUT")
	R.textLayer.swap = swap

	-- Favour arrival: the stripe catches the light.
	local sweepAnim = R.sweepFrame:CreateAnimationGroup()
	Alpha(sweepAnim, 0, 0.85, 0.08, 1)
	local sMove = Slide(sweepAnim, 0, 0, 0.40, 2, 0, "IN_OUT")
	Alpha(sweepAnim, 0.85, 0, 0.40, 2)
	sweepAnim.move = sMove
	-- An animation leaves the frame at its final value, so park it back at
	-- invisible or the stripe keeps a bright block stuck to it.
	Park(sweepAnim, R.sweepFrame)
	R.sweepFrame.anim = sweepAnim

	-- The arrival's bloom: the reason's light gathers round the ring, in and
	-- out within half a second.
	local arrive = R.burstFrame:CreateAnimationGroup()
	Alpha(arrive, 0, 0.90, 0.09, 1, 0, "OUT")
	Alpha(arrive, 0.90, 0, 0.38, 1, 0.09, "OUT")
	arrive.grow = Grow(arrive, 0.94, 1.10, 0.47, 1, 0, "OUT")
	Park(arrive, R.burstFrame)
	R.burstFrame.arrive = arrive

	-- A buff that landed: the halo flares and fades as the rings go out.
	local burst = R.burstFrame:CreateAnimationGroup()
	Alpha(burst, 0, 0.85, 0.07, 1, 0, "OUT")
	Alpha(burst, 0.85, 0, 0.38, 1, 0.07, "OUT")
	burst.grow = Grow(burst, 1, 1.10, 0.45, 1, 0, "OUT")
	Park(burst, R.burstFrame)
	R.burstFrame.anim = burst

	-- A refusal: the same halo, a short hot flare in red and amber.
	local reject = R.burstFrame:CreateAnimationGroup()
	Alpha(reject, 0, 0.80, 0.05, 1, 0, "OUT")
	Alpha(reject, 0.80, 0, 0.25, 1, 0.05, "IN")
	Park(reject, R.burstFrame)
	R.burstFrame.reject = reject

	-- The once-only flash, for "Flash once": the halo and the rim lit and let go.
	local glowAnim = R.glowFrame:CreateAnimationGroup()
	Alpha(glowAnim, 0, 0.70, 0.10, 1)
	Alpha(glowAnim, 0.70, 0, 0.45, 2, 0, "OUT")
	Park(glowAnim, R.glowFrame)
	R.glowFrame.anim = glowAnim
	local rimAnim = R.rimFrame:CreateAnimationGroup()
	Alpha(rimAnim, 0, 0.60, 0.10, 1)
	Alpha(rimAnim, 0.60, 0, 0.45, 2, 0, "OUT")
	Park(rimAnim, R.rimFrame)
	R.rimFrame.anim = rimAnim

	-- Keeps breathing for as long as somebody is still owed, so it is not
	-- missed: the reason's light and, a little inside it, a warm white rim, on
	-- the same slow breath (2.4 s in and out, 1.2 s each way).
	local pulse = R.glowFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	Alpha(pulse, 0.14, 0.62, 1.2, 1, 0, "IN_OUT")
	pulse:SetScript("OnStop", function() R.glowFrame:SetAlpha(0) end)
	R.glowFrame.pulse = pulse
	local rimPulse = R.rimFrame:CreateAnimationGroup()
	rimPulse:SetLooping("BOUNCE")
	Alpha(rimPulse, 0.04, 0.42, 1.2, 1, 0, "IN_OUT")
	rimPulse:SetScript("OnStop", function() R.rimFrame:SetAlpha(0) end)
	R.rimFrame.pulse = rimPulse

	-- The wave that bursts from the icon's edge and runs the panel once as a
	-- buff lands: in at once, across fast and slowing, gone as it arrives. The
	-- distance is the width past the icon, which ApplyStyle knows and sets.
	-- 0.34 s in all.
	local shine = R.shineFrame:CreateAnimationGroup()
	Alpha(shine, 0, 1, 0.04, 1)
	local shMove = Slide(shine, 0, 0, 0.30, 2, 0, "OUT")
	Alpha(shine, 1, 0, 0.30, 2, 0, "IN")
	shine.move = shMove
	Park(shine, R.shineFrame)
	R.shineFrame.anim = shine

	-- The entrance's two rules of light, each drawing itself out from the icon
	-- to the panel's right edge while the panel rises (the level-up banner): a
	-- quick lift, then the rule grows along its length only, about its left
	-- end, and dies as the words arrive. 0.46 s in all, parked at nothing.
	for _, rule in ipairs({ R.ruleTop, R.ruleBottom }) do
		local draw = rule:CreateAnimationGroup()
		Alpha(draw, 0, 0.95, 0.04, 1)
		Grow(draw, 0.04, 1, 0.26, 2, 0, "OUT", 1, 1, "LEFT")
		Alpha(draw, 0.95, 0.95, 0.26, 2)
		Alpha(draw, 0.95, 0, 0.16, 3, 0, "IN")
		Park(draw, rule)
		rule.draw = draw
	end

	-- The words, held back a beat while the rules draw and then brought in:
	-- full at 0.24 s, a shade after the panel has landed. Ends at full, so
	-- nothing parks it; the stops that cut it short put the words at full.
	local reveal = R.textLayer:CreateAnimationGroup()
	Alpha(reveal, 0, 0, 0.08, 1)
	Alpha(reveal, 0, 1, 0.16, 2, 0, "OUT")
	R.textLayer.reveal = reveal

	-- A favour arriving: a glint runs each rule from the icon to the panel's
	-- end, fading over the second half of its run. 0.38 s. The two share one
	-- flag, S.glintPlaying, read by the scan: raised as either starts, dropped
	-- when neither is left running.
	local function glintDone()
		if not (Playing(R.glintTop.run) or Playing(R.glintBottom.run)) then S.glintPlaying = nil end
	end
	for _, glint in ipairs({ R.glintTop, R.glintBottom }) do
		local run = glint:CreateAnimationGroup()
		Alpha(run, 0, 1, 0.04, 1)
		run.move = Slide(run, 0, 0, 0.34, 2, 0, "OUT")
		Alpha(run, 1, 0, 0.20, 2, 0.14, "IN")
		run:SetScript("OnPlay", function() S.glintPlaying = true end)
		run:SetScript("OnFinished", function() glint:SetAlpha(0) glintDone() end)
		run:SetScript("OnStop", function() glint:SetAlpha(0) glintDone() end)
		glint.run = run
	end

	-- The panel's edge answering an outcome: lit in the reason's colour as a
	-- buff lands (0.50 s, never over EDGE_PEAK) and a short hot flash in red as
	-- one is refused (0.30 s), both parked at nothing.
	local edgeLand = R.edgeLightFrame:CreateAnimationGroup()
	Alpha(edgeLand, 0, EDGE_PEAK, 0.08, 1, 0, "OUT")
	Alpha(edgeLand, EDGE_PEAK, 0, 0.42, 2, 0, "IN")
	Park(edgeLand, R.edgeLightFrame)
	R.edgeLightFrame.land = edgeLand
	local edgeReject = R.edgeLightFrame:CreateAnimationGroup()
	Alpha(edgeReject, 0, 0.35, 0.05, 1, 0, "OUT")
	Alpha(edgeReject, 0.35, 0, 0.25, 2, 0, "IN")
	Park(edgeReject, R.edgeLightFrame)
	R.edgeLightFrame.reject = edgeReject

	-- Minimal has no edge to light, so a landing lights its two rules instead:
	-- up at once, let go over the rest of the half-second (0.45 s).
	for _, rule in ipairs({ R.ruleTop, R.ruleBottom }) do
		local flare = rule:CreateAnimationGroup()
		Alpha(flare, 0, 0.55, 0.05, 1, 0, "OUT")
		Alpha(flare, 0.55, 0, 0.40, 1, 0.05, "OUT")
		Park(flare, rule)
		rule.flare = flare
	end

	-- A refusal: the top rule sputters -- lit, dimmed, lit, gone (0.30 s).
	local flicker = R.ruleTop:CreateAnimationGroup()
	Alpha(flicker, 0, 0.8, 0.03, 1)
	Alpha(flicker, 0.8, 0.25, 0.06, 2)
	Alpha(flicker, 0.25, 0.8, 0.05, 3)
	Alpha(flicker, 0.8, 0, 0.16, 4)
	Park(flicker, R.ruleTop)
	R.ruleTop.flicker = flicker

	-- And the ground cracks under the words: open at once, held, gone (0.40 s).
	-- The crack's alpha alone moves, never its shape; its colour is the break's.
	local split = R.crackFrame:CreateAnimationGroup()
	Alpha(split, 0, 0.85, 0.04, 1, 0, "OUT")
	Alpha(split, 0.85, 0.85, 0.10, 2)
	Alpha(split, 0.85, 0, 0.26, 3, 0, "IN")
	Park(split, R.crackFrame)
	R.crackFrame.split = split
	R.crackFrame.band:SetVertexColor(BREAK[1], BREAK[2], BREAK[3], 1)

	-- The outcome's wash: a quick rise to its peak and a long fall to the rest
	-- it holds until the outcome runs out (0.56 s), where it used to cut in.
	-- The ends are the outcome's and set per play (PlayWash, which keeps the
	-- rest on the group); it is not parked at nothing but left at its rest when
	-- it ends, since the client does not keep an animation's last alpha for it,
	-- and the outcome's expiry hides what it washes.
	local fade = R.washFrame:CreateAnimationGroup()
	fade.rise = Alpha(fade, 0, WASH_PEAK.cast, 0.04, 1, 0, "OUT")
	fade.fall = Alpha(fade, WASH_PEAK.cast, WASH_REST.cast, 0.52, 2, 0, "OUT")
	fade.rest = WASH_REST.cast
	local function restWash() R.washFrame:SetAlpha(fade.rest) end
	fade:SetScript("OnFinished", restWash)
	fade:SetScript("OnStop", restWash)
	R.washFrame.fade = fade

	-- The cursor on the bezel: its lifted twin fades up in 0.12 s and lets go
	-- in 0.18 s, each from wherever the other left it (HoverBezel sets the
	-- start for each play). The enter holds at full for as long as the cursor
	-- stays (the client does not keep an animation's last alpha, so its end is
	-- put on the texture, as every other hover does); only the leaving parks
	-- it at nothing. `level` is where the twin rests or started its fade,
	-- `goal` where it is going, `start` and `span` when and for how long.
	local bezelEnter = R.bezelHover:CreateAnimationGroup()
	bezelEnter.fade = Alpha(bezelEnter, 0, 1, 0.12, 1, 0, "OUT")
	if bezelEnter.SetToFinalAlpha then bezelEnter:SetToFinalAlpha(true) end
	bezelEnter:SetScript("OnFinished", function()
		R.bezelHover:SetAlpha(1)
		R.bezelHover.level, R.bezelHover.start = 1, nil
	end)
	R.bezelHover.enter = bezelEnter
	local bezelLeave = R.bezelHover:CreateAnimationGroup()
	bezelLeave.fade = Alpha(bezelLeave, 1, 0, 0.18, 1, 0, "IN")
	Park(bezelLeave, R.bezelHover)
	local parked = bezelLeave:GetScript("OnFinished")
	bezelLeave:SetScript("OnFinished", function()
		parked()
		R.bezelHover.level, R.bezelHover.start = 0, nil
	end)
	R.bezelHover.leave = bezelLeave

	-- A refusal: the text shakes its head, struck -- seven steps, the first
	-- toward the icon, dying away (they sum to nothing, and the group's end
	-- puts it home; never further left than SHAKE_LEFT). 0.28 s.
	local shake = R.textLayer:CreateAnimationGroup()
	for i, dx in ipairs({ -3, 5, -4, 3, -2, 1.5, -0.5 }) do
		Slide(shake, dx, 0, 0.04, i)
	end
	R.textLayer.shake = shake

	-- Leaving after the last buff: the panel fades over the second half of the
	-- confirmation. The button is still hidden when the confirmation runs out;
	-- art is parked invisible until then, and the next Refresh restores the
	-- alpha.
	local outro = R.art:CreateAnimationGroup()
	Alpha(outro, 1, 0, OUTCOME_SECONDS * 0.5, 1, OUTCOME_SECONDS * 0.5, "IN")
	outro:SetScript("OnFinished", function()
		R.art.faded = true
		R.art:SetAlpha(0)
	end)
	R.art.outro = outro

	-- A fade cancelled part-way, brought back to rest rather than snapped: when
	-- somebody arrives while the panel is fading out, or a fight starts (the
	-- button cannot be hidden in combat). From and to are set for each play.
	local comeback = R.art:CreateAnimationGroup()
	local cFade = comeback:CreateAnimation("Alpha")
	cFade:SetDuration(0.18)
	if cFade.SetSmoothing then cFade:SetSmoothing("OUT") end
	comeback.fade = cFade
	R.art.comeback = comeback
end

-- The halo that flares round the icon (the three built-in looks): how deep it is
-- drawn beyond the icon's ring, and how far it may grow. `limit` is the
-- distance from the icon's middle to the nearest thing it must stay clear of
-- (the text, the panel's top and bottom edges: Fit's limits), `half` the icon's
-- half-size, `outer` the width of its ring, `haloHalf` the half-width of the
-- round halo's texture when the icon is round (it draws a ring in place of the
-- strips). Returns the depth for PlaceHalo.
function Prompt:FitBurst(limit, half, outer, haloHalf)
	local deep = math.max(0, math.min(4, limit - half - outer))
	local reach = haloHalf or (half + outer + deep)
	local cap = limit / reach
	local flare, arrive = R.burstFrame.anim, R.burstFrame.arrive
	if flare and flare.grow then lib.Rescale(flare.grow, math.min(1, cap), math.min(1.10, cap)) end
	if arrive and arrive.grow then lib.Rescale(arrive.grow, math.min(0.94, cap), math.min(1.10, cap)) end
	return deep
end

-- Whether the extra motion is wanted: the landing rings, the shine, the
-- shake, the settle, the echo, the scale of the entrance and the outro.
-- "Calm" drops all of it; what is left is fades (the entrance, the text's
-- cross-fade, the arrival's stripe and glow, the breath).
local function FullEffects()
	local p = ns.db and ns.db.profile.prompt
	return p ~= nil and p.effects ~= "calm"
end

-- The alpha art takes in a fight: a look's own, else half strength for the
-- built-in looks when "Dim the prompt in combat" is on, else full.
local function CombatRestAlpha()
	local look = S.activeLook
	if look and look.combatArtAlpha then return look.combatArtAlpha end
	local p = ns.db and ns.db.profile.prompt
	return p and p.dimInCombat and 0.55 or 1
end

-- The alpha art rests at: the fight's, when held, full otherwise. The outro
-- leaves art at zero, and every way back has to undo that.
local function RestArtAlpha()
	R.art.faded = nil
	R.art:SetAlpha(combatHeld and CombatRestAlpha() or 1)
end

-- The dim asked again mid-fight (a restyle: the setting changed, or the look).
-- Nothing to do out of one.
function Prompt:ReapplyCombatDim()
	if combatHeld then RestArtAlpha() end
end

-- The colour the entrance's rules are drawn in: the reason's, taken a third
-- of the way to white, or plain light with accents off.
local function RuleColour(self, p)
	if (p.accentMode or "icon") == "off" then return 1, 1, 1 end
	local r, g, b = self:AccentColor(S.current and S.current.reason or "owed")
	return Tint(r, g, b, 0.35)
end

-- The entrance: the full one lands, Calm's fades. Played where the panel
-- comes up. On the three looks drawn here the full one also holds the words
-- back a beat and draws the two rules of light out from the icon in the
-- reason's colour; a look from Looks/ gets the rise alone, as before.
function Prompt:PlayIntro()
	if not R.art.intro then return end
	if FullEffects() then
		R.art.introCalm:Stop()
		if not S.activeLook and R.ruleTop and R.ruleTop.draw then
			-- A panel coming back part-way through a settle or a fade: those
			-- are let go first, so the rise starts from rest.
			if R.art.settle:IsPlaying() then R.art.settle:Stop() end
			if R.art.outro:IsPlaying() then R.art.outro:Stop() end
			R.art.intro:Play()
			R.textLayer.reveal:Stop()
			R.textLayer.reveal:Play()
			local r, g, b = RuleColour(self, ns.db.profile.prompt)
			local k = S.ruleStrength or 1
			for _, rule in ipairs({ R.ruleTop, R.ruleBottom }) do
				rule.band:SetVertexColor(r, g, b, k)
				rule.draw:Stop()
				rule.draw:Play()
			end
			return
		end
		R.art.intro:Play()
	else
		R.art.intro:Stop()
		R.art.introCalm:Play()
	end
end

function Prompt:StopOutro()
	if R.art.outro and R.art.outro:IsPlaying() then R.art.outro:Stop() end
	if R.art.faded then RestArtAlpha() end
	R.art.outroFor = nil
end

-- How far the outro has taken art, worked out from when it started: what
-- GetAlpha answers mid-animation has not been seen to settle on this client.
-- Same shape as the fade: a wait, then an eased-in fall.
local function OutroAlpha()
	if R.art.faded then return 0 end
	if not (R.art.outro and R.art.outro:IsPlaying() and R.art.outroAt) then return nil end
	local wait = OUTCOME_SECONDS * 0.5
	local t = (GetTime() - R.art.outroAt - wait) / (OUTCOME_SECONDS * 0.5)
	if t <= 0 then return 1 end
	if t >= 1 then return 0 end
	return 1 - t * t
end

-- Restarted for each new outcome: a second one (a refusal just after a landed
-- buff) would otherwise paint onto a panel already faded, or be cut short.
function Prompt:PlayOutro(stamp)
	if R.art.outroFor == stamp then return end
	self:StopOutro()
	if R.art.comeback and R.art.comeback:IsPlaying() then R.art.comeback:Stop() end
	R.art.outroFor, R.art.outroAt = stamp, GetTime()
	R.art.outro:Play()
end

-- A fade a repaint just cancelled, taken back to rest over a moment; `from` is
-- nil when no fade was running.
function Prompt:ComeBack(from)
	self:StopOutro()
	local rest = combatHeld and CombatRestAlpha() or 1
	if from == nil or math.abs(from - rest) < 0.02 then return end
	if not (R.art.comeback and R.button:IsShown()) then return end
	R.art.comeback:Stop()
	R.art.comeback.fade:SetFromAlpha(from)
	R.art.comeback.fade:SetToAlpha(rest)
	R.art.comeback:Play()
end

-- The once-only effects, stopped: what a repaint about somebody else does to a
-- flash that belonged to the last thing on the panel.
function Prompt:StopFlourishes()
	for _, g in ipairs({ R.burstFrame.anim, R.burstFrame.arrive, R.burstFrame.reject, R.shineFrame.anim,
		R.textLayer.shake, R.art.settle, R.ruleTop.draw, R.ruleBottom.draw, R.ruleTop.flare, R.ruleBottom.flare,
		R.ruleTop.flicker, R.edgeLightFrame.land, R.edgeLightFrame.reject, R.crackFrame.split, R.washFrame.fade }) do
		if g and g:IsPlaying() then g:Stop() end
	end
	-- The words' reveal as well, and the words at full: on the three looks
	-- drawn here only. Under a look from Looks/ textLayer's alpha is the look's
	-- own (its fight dim), and a flourish must leave it where the look put it.
	if not S.activeLook then
		if R.textLayer.reveal and R.textLayer.reveal:IsPlaying() then R.textLayer.reveal:Stop() end
		R.textLayer:SetAlpha(1)
	end
	if R.fx then R.fx:Stop() end
	if S.activeLook then S.activeLook:StopFlourishes() end
end

-- The wave of light across the panel as a buff lands, at `strength` (0.30:
-- never full under the words). Not on the Minimal look: additive light with
-- no panel under it is a white column sweeping over the world.
function Prompt:PlayShine(r, g, b, strength)
	if not R.shineFrame.anim then return end
	if ns.db and ns.db.profile.prompt.style == "minimal" then return end
	R.shineBand:SetVertexColor(r, g, b, strength)
	R.shineFrame.anim:Stop()
	R.shineFrame.anim:Play()
end

-- The outcome's wash, risen and let fall to the rest for `kind`: once per
-- outcome (PaintOutcome keeps the stamp), on the three looks drawn here.
function Prompt:PlayWash(kind)
	local fade = R.washFrame and R.washFrame.fade
	if not fade then return end
	local peak, rest = WASH_PEAK[kind] or WASH_PEAK.cast, WASH_REST[kind] or WASH_REST.cast
	fade:Stop()
	fade.rise:SetToAlpha(peak)
	fade.fall:SetFromAlpha(peak)
	fade.fall:SetToAlpha(rest)
	fade.rest = rest
	fade:Play()
end

-- The icon greyed for a refusal (PaintOutcome) given its colour back. Run at
-- every place an outcome is cleared, which is nearly every scan, so it is one
-- flag test, and a client call only when the icon is grey.
function Prompt:UngreyIcon()
	if S.iconGreyed then
		S.iconGreyed = nil
		R.icon:SetDesaturated(false)
	end
end

-- How far the bezel's lifted twin has got, worked out from when its fade
-- started: what GetAlpha answers mid-animation has not been seen to settle on
-- this client. Linear, which the fade's easing is near enough to.
local function BezelLevel(t)
	local level = t.level or 0
	if not t.start then return level end
	local k = (GetTime() - t.start) / t.span
	if k >= 1 then return t.goal end
	return level + (t.goal - level) * math.max(k, 0)
end

-- The cursor on a look drawn here: the bezel's lifted twin faded up, and let
-- go when the cursor leaves, each from wherever the other fade had got to, so
-- a cursor that comes and goes never snaps. A cursor already lifting it, or
-- holding it lifted, is left to it: the tooltip and Shift ask again while the
-- cursor stays. A look from Looks/ gets Hover.
function Prompt:HoverBezel(on)
	local t = R.bezelHover
	if not (t and t.enter and t.leave) then return end
	local goal = on and 1 or 0
	if t.goal == goal or (goal == 0 and not t.goal) then return end
	local from = BezelLevel(t)
	t.enter:Stop()
	t.leave:Stop()
	t:SetAlpha(from)
	local g = on and t.enter or t.leave
	g.fade:SetFromAlpha(from)
	t.level, t.goal, t.start, t.span = from, goal, GetTime(), on and 0.12 or 0.18
	g:Play()
end

-- The cooldown sweep, brought up to date when a cast goes out and when the
-- panel comes up; the Cooldown frame animates itself in between.
function Prompt:SyncCooldown()
	if not R.cooldown then return end
	local p = ns.db and ns.db.profile.prompt
	-- Not in a fight with "Stay quiet in combat" on, which promises a still
	-- panel. The Cooldown frame is not protected, so hiding it in combat is
	-- allowed; SetCombatHold asks again as the fight starts and ends.
	local quiet = p and p.hideInCombat and InCombatLockdown()
	if not (p and p.showCooldown and p.showIcon) or quiet then
		Try(R.cooldown, "Clear")
		R.cooldown:Hide()
		return
	end
	local start, duration
	local span = ns.GlobalCooldownSpan
	if span then start, duration = span(GetTime()) end
	if start and duration and duration > 0 and Try(R.cooldown, "SetCooldown", start, duration) then
		R.cooldown:Show()
	else
		Try(R.cooldown, "Clear")
		R.cooldown:Hide()
	end
end

-- The glow round the icon and the rim's breath stopped. Alone, it is what a
-- panel with no icon asks for: they are drawn round the icon, but the glints
-- run the rules, which are there with or without one.
local function StopGlow()
	local glow, rim = R.glowFrame, R.rimFrame
	if glow.pulse and glow.pulse:IsPlaying() then glow.pulse:Stop() end
	glow:SetAlpha(0)
	-- The rim parks itself when its breath stops (OnStop), so only a breath
	-- that is running needs the call.
	if rim.pulse and rim.pulse:IsPlaying() then rim.pulse:Stop() end
end

-- Run by nearly every scan (nobody owed is the usual case), so it builds
-- nothing: no table, no closure.
function Prompt:StopAttention()
	StopGlow()
	-- The glints running the rules, by their one flag rather than two IsPlaying
	-- calls: the favour they ran for has left the panel.
	if S.glintPlaying then
		R.glintTop.run:Stop()
		R.glintBottom.run:Stop()
		S.glintPlaying = nil
	end
	if S.activeLook then S.activeLook:StopAttention() end
end

-- The reason's light and the warm white rim, in the arrival's colour.
local function ArrivalColour(self, p)
	if (p.accentMode or "icon") == "off" then return 1, 1, 1 end
	return self:AccentColor("owed")
end

-- `isNew`: somebody owed has just become the one on the panel (the flash and
-- the sweep). `arrived`: the favour itself was only just done (the light). See
-- Refresh.
function Prompt:StartAttention(isNew, arrived)
	local p = ns.db.profile.prompt
	local mode = p.flashStyle or "pulse"
	-- A look of its own answers all of it; the light only on a favour just
	-- done, never over an outcome.
	if S.activeLook then
		return S.activeLook:Attention(isNew, arrived and not self:OutcomeLive(), mode)
	end
	if mode == "off" then
		self:StopAttention()
		return
	end

	-- The stripe's sweep first, whatever the icon is doing: it has nothing to
	-- do with the icon. It slides, so Calm does without it.
	if isNew and FullEffects() and R.sweepFrame.anim and R.sweepFrame:IsShown() then
		R.sweepFrame.anim:Stop()
		R.sweepFrame.anim.move:SetOffset(0, -(p.height - 14))
		R.sweepFrame.anim:Play()
	end

	-- And a glint runs the two rules of light from the icon to the panel's
	-- end as the favour is done, in the reason colour (plain light with
	-- accents off). Never over an outcome, so a press's own confirmation is
	-- not cut off, and never over a run still going.
	if arrived and FullEffects() and not self:OutcomeLive() and not S.glintPlaying and R.glintTop.run then
		local r, g, b = ArrivalColour(self, p)
		r, g, b = Tint(r, g, b, 0.45)
		local k = 0.9 * (S.ruleStrength or 1)
		for _, glint in ipairs({ R.glintTop, R.glintBottom }) do
			glint.band:SetVertexColor(r, g, b, k)
			glint.run:Play()
		end
	end

	-- The glow is drawn around the icon, so it goes with it. Not the glints
	-- just started above, which run the rules and are there without an icon
	-- (StopAttention would cut them short, here and on every scan after).
	if not p.showIcon then
		StopGlow()
		return
	end

	-- The favour just landed on the panel: the icon's echo drops onto it and
	-- the reason's light gathers round its ring. Full only, and never over an
	-- outcome the panel is still showing.
	if isNew and FullEffects() and not self:OutcomeLive() and R.burstFrame.arrive then
		local r, g, b = ArrivalColour(self, p)
		if R.burstFrame.anim:IsPlaying() then R.burstFrame.anim:Stop() end
		PaintHalo(R.burstHalo, r, g, b, 1)
		R.burstFrame.arrive:Stop()
		R.burstFrame.arrive:Play()
		local file = S.current and lib.EntryIcon(S.current)
		R.fx:Arrive(file, Tint(r, g, b, 0.55))
	end

	if mode == "pulse" then
		if R.glowFrame.pulse and not R.glowFrame.pulse:IsPlaying() then
			if R.glowFrame.anim then R.glowFrame.anim:Stop() end
			if R.rimFrame.anim then R.rimFrame.anim:Stop() end
			R.glowFrame.pulse:Play()
			R.rimFrame.pulse:Play()
		end
	else
		-- Unconditionally, before anything else plays: the looping pulse is
		-- only stopped in the branch above, so switching away from Pulse left
		-- it running.
		if R.glowFrame.pulse then R.glowFrame.pulse:Stop() end
		if R.rimFrame.pulse then R.rimFrame.pulse:Stop() end
		if isNew and R.glowFrame.anim then
			R.glowFrame.anim:Stop()
			R.glowFrame.anim:Play()
			R.rimFrame.anim:Stop()
			R.rimFrame.anim:Play()
		end
	end
end

-- The motion for an outcome, once: rings and light for a confirmed buff, a
-- shake and a contracting ring for a refusal, nothing for an unconfirmed cast.
-- None when quiet in combat, on "Calm", or with the panel not shown.
function Prompt:PlayOutcomeFlourish(kind)
	local p = ns.db and ns.db.profile.prompt
	if not p or not FullEffects() then return end
	if InCombatLockdown() and p.hideInCombat then return end
	if not R.button:IsShown() then return end
	self:StopFlourishes()
	if S.activeLook then
		S.activeLook:Flourish(kind)
		if kind == "failed" and R.textLayer.shake then R.textLayer.shake:Play() end
		-- The panel settles as a buff lands, whatever it is drawn in.
		if kind == "cast" then R.art.settle:Play() end
		return
	end
	if kind == "cast" then
		-- Coloured here rather than by PaintAccent: the repaint that follows
		-- is usually about the next person, and the rings belong to this one.
		local r, g, b = 1, 1, 1
		if (p.accentMode or "icon") ~= "off" then
			r, g, b = self:AccentColor(S.current and S.current.reason or "owed")
		end
		if p.showIcon and R.burstFrame.anim then
			PaintHalo(R.burstHalo, r, g, b, 1)
			R.burstFrame.anim:Play()
			R.fx:Land(Tint(r, g, b, 0.20))
		end
		-- The material answers: the panel's edge lights in the colour (the two
		-- rules instead on Minimal, which has no edge), and a wave of the same
		-- light bursts from the icon's edge across the panel, under the words.
		local sr, sg, sb = Tint(r, g, b, 0.55)
		if p.style == "minimal" then
			for _, rule in ipairs({ R.ruleTop, R.ruleBottom }) do
				rule.band:SetVertexColor(sr, sg, sb, S.ruleStrength or 1)
				rule.flare:Play()
			end
		else
			PaintEdge(sr, sg, sb)
			R.edgeLightFrame.land:Play()
		end
		self:PlayShine(sr, sg, sb, 0.30)
		R.art.settle:Play()
	elseif kind == "failed" then
		if p.showIcon and R.burstFrame.reject then
			PaintHalo(R.burstHalo, 1.00, 0.42, 0.20, 1)
			R.burstFrame.reject:Play()
			R.fx:Refuse(1.00, 0.38, 0.22)
		end
		-- The ward breaks: the edge flashes red, the ground cracks under the
		-- words, the top rule sputters, and the words shake their head.
		if p.style ~= "minimal" then
			PaintEdge(BREAK[1], BREAK[2], BREAK[3])
			R.edgeLightFrame.reject:Play()
		end
		R.crackFrame.split:Play()
		R.ruleTop.band:SetVertexColor(BREAK[1], BREAK[2], BREAK[3], S.ruleStrength or 1)
		R.ruleTop.flicker:Play()
		if R.textLayer.shake then R.textLayer.shake:Play() end
	end
end

-- Dim the whole panel for combat, or undo it; remembers what it last did, so a
-- repaint costs nothing.
function Prompt:SetCombatHold(on)
	if combatHeld == on then return end
	combatHeld = on
	-- art, never the button: every visual of the prompt lives on art precisely
	-- so that combat -- which is when this runs -- cannot refuse it.
	RestArtAlpha()
	if S.activeLook then S.activeLook:Combat(on) end
	-- The sweep answers to the fight as well: see SyncCooldown.
	self:SyncCooldown()
end

lib.FullEffects, lib.OutroAlpha = FullEffects, OutroAlpha
