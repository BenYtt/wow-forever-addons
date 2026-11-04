---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- A thin ribbon of the game's own parchment ticks across the top of the screen: no panel, no border, the
-- ticks and their letters fading out towards its ends, the destination drawn as the game's own waypoint pin.
local WIDTH, HEIGHT, POLL_EVERY = 360, 60, 0.1
local TURN, EASE, SETTLED = 2 * math.pi, 18, 0.001
local OVERLAP = 6
-- Pixels over which a tick fades from full strength to nothing at the ribbon's end.
local FADE = 80
---@class SPFCompassFrame : Frame
---@field ticks SPFCompassTick[]
---@field markers SPFCompassMarker[]
---@field Goal SPFCompassMarker
---@field Stop SPFCompassMarker
---@field Next SPFCompassMarker
---@field Bend SPFCompassMarker
---@field Center Texture
---@field Distance FontString
---@field Time FontString
---@field timeAt? number
---@field timeText? string
---@field updating? boolean
---@field facing? number
---@field rawFacing? number
---@field x? number
---@field y? number
---@field map? number
---@field metres? boolean
---@field distance? number
---@field distanceOwner? SPFCompassMarker
---@field dirty? boolean
---@field idle number
---@field ticker? FunctionContainer
---@field Backdrop Texture
---@field Mover Texture
---@field MoverHint FontString
---@type SPFCompassFrame
local frame
local OnUpdate
-- Being placed (Settings: Move the compass): shown without a journey and taking the mouse it otherwise ignores.
local moving = false
local TRANSPORTS = { boat = true, zeppelin = true, lift = true, tram = true, portal = true }
local taxiIcons = { Alliance = "taxinode_alliance", Horde = "taxinode_horde", Neutral = "taxinode_neutral" }

local function Difference(angle, facing)
	return (angle - facing + math.pi) % TURN - math.pi
end

-- Facing and bearings both increase westward; east belongs on the right of the strip.
local function Offset(angle, facing)
	return -Difference(angle, facing) * WIDTH / math.pi
end

-- The icon is a transport kind (drawn as the map draws it) or an atlas name.
local function SetIcon(marker, icon)
	if marker.icon == icon then
		return false
	end
	marker.icon = icon
	if TRANSPORTS[icon] then
		ns.SetTransportIcon(marker, icon, marker.size)
	else
		ns.Art.Fit(marker, icon, marker.size, marker.size)
	end
	return true
end

local function StopIcon(stop)
	if stop and stop.kind == "dock" then
		local kind = ns.DockKind(stop.id)
		return TRANSPORTS[kind] and kind or "Waypoint-MapPin-Tracked", true
	elseif stop and stop.kind == "taxi" then
		local taxi = ns.TaxiNodes[stop.id]
		return stop.undiscovered and "taxinode_undiscovered" or taxiIcons[taxi and taxi.faction] or taxiIcons.Neutral,
			true
	end
	return "Waypoint-MapPin-Tracked", false
end

local function SamePlace(a, b)
	return a == b
		or (a.map == b.map and (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= 1 and not (a.z and b.z and math.abs(a.z - b.z) > 1))
end

local function Place(marker, x, y, map, facing, index)
	local point = marker.target
	if point and point.kind == "dock" then
		point = ns.DockPoint(point.id)
	end
	marker.point, marker.visible, marker.replacement = point, false, nil
	-- Coordinates on opposite sides of a loading screen have no shared bearing.
	if not point or point.map ~= map then
		marker:Hide()
		return
	end
	local offset = Offset(math.atan2(point.y - y, point.x - x), facing)
	marker.offset = math.max(-WIDTH / 2, math.min(WIDTH / 2, offset))
	for i = 1, index - 1 do
		local other = frame.markers[i]
		if other.visible and (SamePlace(point, other.point) or math.abs(marker.offset - other.offset) <= OVERLAP) then
			marker.replacement = other
			marker:Hide()
			return
		end
	end
	marker:SetPoint("CENTER", frame, "CENTER", marker.offset, -6)
	marker:Show()
	marker.visible = true
end

local function Render(x, y, map)
	for _, tick in ipairs(frame.ticks) do
		local offset = Offset(tick.angle, frame.facing)
		local visible = math.abs(offset) <= WIDTH / 2
		-- A smooth ramp rather than a cutoff: the ribbon has no edges of its own, so it dissolves into the world.
		local edge = math.max(0, math.min(1, (WIDTH / 2 - math.abs(offset)) / FADE))
		local alpha = edge * edge * (tick.major and 0.85 or 0.5)
		tick:SetShown(visible)
		if visible then
			tick:SetPoint("TOP", frame, "TOP", offset, -6)
			tick:SetAlpha(alpha)
		end
		if tick.label then
			tick.label:SetShown(visible)
			tick.label:SetAlpha(alpha)
		end
	end
	for i, marker in ipairs(frame.markers) do
		Place(marker, x, y, map, frame.facing, i)
	end
	local bend = frame.Bend
	local owner = bend.visible and bend or bend.replacement
	local point = bend.point
	if owner and point then
		local distance = math.floor(math.sqrt((point.x - x) ^ 2 + (point.y - y) ^ 2))
		if distance ~= frame.distance or frame.metres ~= ns.db.metres then
			frame.metres = ns.db.metres
			frame.distance = distance
			frame.Distance:SetText(ns.FormatDistance(distance))
		end
		-- A merged bend keeps its distance under the surviving destination or transport icon.
		if owner ~= frame.distanceOwner then
			frame.distanceOwner = owner
			frame.Distance:ClearAllPoints()
			frame.Distance:SetPoint("TOP", owner, "BOTTOM", 0, -2)
		end
		frame.Distance:Show()
	else
		frame.Distance:Hide()
	end
end

-- Beside the distance, with "Show the time left" on: the time left exactly as the tracker's header gives it (the corpse
-- run's while you run back, none while a plan is being worked out). Read once per second of GetTime, the header's own
-- tick, or when the journey changes; written only when it changes, so a turning compass costs nothing.
local function HideTime()
	frame.Time:Hide()
	frame.timeText, frame.timeAt = nil, nil
end

local function RenderTime(changed)
	if not (ns.db.compassTime and frame.Distance:IsShown()) then
		HideTime()
		return
	end
	local second = math.floor(GetTime())
	if not changed and second == frame.timeAt then
		return
	end
	frame.timeAt = second
	local text = ns.JourneyLeft()
	if text ~= frame.timeText then
		frame.timeText = text
		if text then
			frame.Time:SetText(text)
		end
	end
	frame.Time:SetShown(text ~= nil)
end

local function SetUpdating(running)
	if frame.updating ~= running then
		frame.updating = running
		frame:SetScript("OnUpdate", running and OnUpdate or nil)
	end
end

local function Update(elapsed)
	local bend, nextBend, stop, goal = ns.GuideTargets()
	if not (ns.db.compass and ns.db.journey and ns.IsJourneyGuided() and bend) then
		HideTime()
		frame:SetShown(moving)
		frame:SetAlpha(1)
		SetUpdating(false)
		return
	end
	local x, y, _, map = ns.JourneyPosition()
	local facing = GetPlayerFacing()
	if not (x and y and map and canaccessvalue(facing) and facing) then
		frame:SetAlpha(0)
		frame.facing = nil
		SetUpdating(false)
		return
	end
	frame:SetAlpha(1)
	local moved = x ~= frame.x or y ~= frame.y or map ~= frame.map or facing ~= frame.rawFacing
	local changed = frame.dirty
		or not frame.facing
		or bend ~= frame.Bend.target
		or nextBend ~= frame.Next.target
		or stop ~= frame.Stop.target
		or goal ~= frame.Goal.target
	local icon, specific = StopIcon(stop)
	changed = SetIcon(frame.Stop, icon) or changed
	frame.Goal.target, frame.Stop.target, frame.Bend.target, frame.Next.target = goal, stop, bend, nextBend
	-- A named transport is more useful than a generic pin; the final destination outranks walking bends.
	frame.markers[1], frame.markers[2] = specific and frame.Stop or frame.Goal, specific and frame.Goal or frame.Stop
	frame.x, frame.y, frame.map, frame.rawFacing = x, y, map, facing
	frame.facing = frame.facing or facing
	local delta = Difference(facing, frame.facing)
	local easing = math.abs(delta) > SETTLED
	if easing then
		-- Exponential decay is frame-rate independent and crosses north by the shortest arc.
		frame.facing = (frame.facing + delta * (1 - math.exp(-EASE * elapsed))) % TURN
	else
		frame.facing = facing
	end
	if moved or changed or delta ~= 0 then
		Render(x, y, map)
	end
	RenderTime(changed)
	frame.dirty = false
	frame.idle = moved and 0 or frame.idle + elapsed
	SetUpdating(easing or frame.idle < 0.15)
end

OnUpdate = function(_, elapsed)
	Update(elapsed)
end

local function Poll()
	-- Mouse turns and moving transports need not send a player movement event.
	if not frame.updating then
		Update(0)
	end
end

local function Wake()
	frame.idle = 0
	SetUpdating(true)
end

local function OnShow()
	frame.ticker = C_Timer.NewTicker(POLL_EVERY, Poll)
	frame:RegisterEvent("PLAYER_STARTED_MOVING")
	frame:RegisterEvent("PLAYER_STARTED_TURNING")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	Wake()
end

local function OnHide()
	SetUpdating(false)
	if frame.ticker then
		frame.ticker:Cancel()
		frame.ticker = nil
	end
	frame:UnregisterAllEvents()
	frame.facing = nil
	HideTime()
end

-- Where the player dragged it, else the stock place under the top of the screen. The client keeps a clamped frame
-- on screen, so a place saved at another resolution or scale cannot strand it. Saved points and the stock offset
-- are in screen pixels, so both are converted into the scaled frame's own units.
local function RelativeScale()
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return scale > 0 and scale or 1
end

local function Anchor()
	frame:ClearAllPoints()
	local scale = RelativeScale()
	local x, y = ns.db.compassX, ns.db.compassY
	if type(x) == "number" and type(y) == "number" then
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	else
		frame:SetPoint("TOP", UIParent, "TOP", 0, -42 / scale)
	end
end

local function ApplyScale()
	frame:SetScale((ns.db.compassScale or 100) / 100)
end

-- A dark band behind the marks for ground whose colours swallow them; none by default, so the compass floats.
local function ApplyBackground()
	local opacity = math.max(0, math.min(100, tonumber(ns.db.compassBackground) or 0))
	frame.Backdrop:SetColorTexture(0, 0, 0, opacity / 100)
	frame.Backdrop:SetShown(opacity > 0)
end

local function Create()
	local compass = CreateFrame("Frame", "ShortestPathForeverCompass", UIParent)
	---@cast compass SPFCompassFrame
	frame = compass
	frame:SetSize(WIDTH, HEIGHT)
	ApplyScale()
	frame:SetClampedToScreen(true)
	Anchor()
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(false)
	-- Drag to move, Shift-drag for fine placing (Mover.lua).
	ns.Mover.Attach(frame, function()
		local scale = RelativeScale()
		local x, y = frame:GetCenter()
		ns.db.compassX, ns.db.compassY = x * scale, y * scale
		Anchor()
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			ns.db.compassX, ns.db.compassY = nil, nil
			Anchor()
		end
	end)
	frame.Backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.Backdrop:SetAllPoints()
	ApplyBackground()
	frame.Mover = frame:CreateTexture(nil, "BACKGROUND")
	frame.Mover:SetAllPoints()
	frame.Mover:SetColorTexture(0, 0, 0, 0.5)
	frame.Mover:Hide()
	frame.MoverHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.MoverHint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 4)
	frame.MoverHint:SetText(L["Drag to move; Shift-drag or the arrow keys to nudge. Right-click to reset."])
	frame.MoverHint:Hide()
	frame.ticks = {}
	local directions = { L["N"], L["W"], L["S"], L["E"] }
	for index = 0, 23 do
		---@class SPFCompassTick : Texture
		---@field angle number
		---@field major boolean
		---@field label? FontString
		local tick = frame:CreateTexture(nil, "ARTWORK")
		tick.angle = index * TURN / 24
		tick.major = index % 6 == 0
		-- The parchment gold the map's own marks are drawn in, faint enough to read as a compass, not a UI.
		tick:SetColorTexture(0.72, 0.67, 0.55, 0.7)
		tick:SetSize(1, tick.major and 5 or 3)
		if tick.major then
			-- The game's own label font: the parchment gold of its map labels, with the shadow that keeps
			-- them legible over snow or sand, instead of a panel behind them (FontStyles.xml).
			tick.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			tick.label:SetText(directions[index / 6 + 1])
			tick.label:SetPoint("TOP", tick, "BOTTOM", 0, -1)
		end
		frame.ticks[#frame.ticks + 1] = tick
	end
	frame.Center = frame:CreateTexture(nil, "OVERLAY")
	-- Straight ahead of you, in the gold the game marks your own place in the world with.
	frame.Center:SetColorTexture(1, 0.82, 0, 0.85)
	frame.Center:SetSize(1, 6)
	frame.Center:SetPoint("TOP", frame, "TOP", 0, -3)
	for _, name in ipairs({ "Goal", "Stop", "Next", "Bend" }) do
		---@class SPFCompassMarker : Texture
		---@field size number
		---@field icon? string
		---@field target? SPFPoint|SPFPlace
		---@field point? SPFPoint
		---@field visible boolean
		---@field replacement? SPFCompassMarker
		---@field offset number
		local marker = frame:CreateTexture(nil, "OVERLAY")
		marker.size = name == "Next" and 12 or 18
		SetIcon(marker, name == "Goal" and "Waypoint-MapPin-Tracked" or "Navigation-Tracked-Icon")
		frame[name] = marker
	end
	-- The game's own pins and arrow at full strength; a turn still ahead of the stop is the only dim one.
	frame.Goal:SetAlpha(1)
	frame.Stop:SetAlpha(1)
	frame.Next:SetAlpha(0.5)
	frame.markers = { frame.Goal, frame.Stop, frame.Bend, frame.Next }
	frame.Distance = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Time = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	-- Beside the distance rather than under it, inside the compass's band and its clamp to the screen.
	frame.Time:SetPoint("LEFT", frame.Distance, "RIGHT", 6, 0)
	frame.Time:Hide()
	frame.idle = 0
	frame:SetScript("OnShow", OnShow)
	frame:SetScript("OnHide", OnHide)
	frame:SetScript("OnEvent", Wake)
	frame:Hide()
end

function ns.RefreshCompass()
	if moving or (ns.db.compass and ns.db.journey and ns.IsJourneyGuided() and ns.GuideTargets()) then
		if not frame then
			Create()
		end
		frame.dirty = true
		frame:Show()
		Update(0)
	elseif frame then
		frame:Hide()
	end
end

---@return boolean
function ns.CompassMoving()
	return moving
end

---@param value number
function ns.SetCompassScale(value)
	if type(value) == "number" then
		ns.db.compassScale = value
	end
	if frame then
		ApplyScale()
		Anchor()
	end
	ns.RefreshCompass()
end

---@param value number
function ns.SetCompassBackground(value)
	if type(value) == "number" then
		ns.db.compassBackground = value
	end
	if frame then
		ApplyBackground()
	end
end

---@param value boolean
function ns.MoveCompass(value)
	moving = value
	ns.RefreshCompass()
	if frame then
		frame:EnableMouse(moving)
		frame.Mover:SetShown(moving)
		frame.MoverHint:SetShown(moving)
	end
end
