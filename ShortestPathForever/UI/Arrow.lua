---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- Guide follows the map's walking path bend by bend. Journey places Blizzard's native navigation marker at
-- this target; our screen arrow is the fallback when that marker is unavailable or the player owns tracking.
-- Camelot omits the navigation setting, but its native super-tracked marker does work while its CVar is on.

-- Polled this often while still; every frame while you move or turn, and while the arrow eases round.
local POLL_EVERY = 0.1
-- How fast the arrow swings to a new bearing, as the compass eases its heading (Compass.lua), and when it has settled.
local TURN, EASE, SETTLED = 2 * math.pi, 18, 0.001
-- The native marker's arrow sits this far from its icon.
local RADIUS = 36
-- A bend this close counts as passed, and the arrow turns to the next one.
local PASSED = 25
-- The stock place, under the top of the screen; the cast prompt stands there too.
local TOP = -120
---@class SPFArrowFrame : Frame
---@field Icon Texture
---@field Arrow Texture
---@field Distance FontString
---@field Progress FontString
---@field Mover Texture
---@field MoverHint FontString
---@field metres? boolean
---@field yards? number
---@field angle? number the bearing drawn, easing towards the true one
---@field ticker? FunctionContainer
---@field updating? boolean
---@field idle number
---@field x? number
---@field y? number
---@field map? number
---@field facing? number
---@type SPFArrowFrame
local frame
local source, path, index, target, placeTarget, native
local stepEnd, destination
local revision = 0
local moving = false
local OnUpdate
---@type SPFCastPromptFrame?
local castPrompt

-- Counter-clockwise from north, like GetPlayerFacing: UnitPosition's first value grows north, its second west.
local function Bearing(x, y)
	return math.atan2(target.y - y, target.x - x)
end

-- The shorter way round from a to b, between -pi and pi.
local function Difference(b, a)
	return (b - a + math.pi) % TURN - math.pi
end

-- Whether the game draws its marker. With showInGameNavigation off, which Camelot gives no setting for, the client
-- still has a navigation frame but keeps the marker at no alpha, so the arrow has to lead.
local function NativeMarkerShown()
	return C_Navigation.GetFrame() ~= nil and GetCVarBool("showInGameNavigation")
end

local function Draw(angle)
	frame.Arrow:SetRotation(angle)
	frame.Arrow:SetPoint("CENTER", frame.Icon, "CENTER", -math.sin(angle) * RADIUS, math.cos(angle) * RADIUS)
end

local function SetUpdating(running)
	if frame.updating ~= running then
		frame.updating = running
		frame:SetScript("OnUpdate", running and OnUpdate or nil)
	end
end

-- Every frame while you move or turn and while the arrow eases; once still for a moment, only the slow poll runs.
local function Settle(elapsed, easing, moved)
	frame.idle = moved and 0 or frame.idle + elapsed
	SetUpdating(easing or frame.idle < 0.15)
end

---@param elapsed number seconds since the last update
local function Update(elapsed)
	-- The client may already have queued this tick when another callback stopped guidance.
	if not path or not target then
		SetUpdating(false)
		return
	end
	local updating = revision
	local x, y, _, map = ns.JourneyPosition()
	local facing = GetPlayerFacing()
	if not x or not canaccessvalue(facing) then
		-- No position to point from (an instance): nothing drawn, only the slow poll runs.
		frame:SetAlpha(moving and 1 or 0)
		frame.angle = nil
		SetUpdating(false)
		return
	end
	local moved = x ~= frame.x or y ~= frame.y or map ~= frame.map or facing ~= frame.facing
	frame.x, frame.y, frame.map, frame.facing = x, y, map, facing
	while index < #path and map == target.map and (target.x - x) ^ 2 + (target.y - y) ^ 2 <= PASSED ^ 2 do
		index = index + 1
		target = path[index]
	end
	local placed = placeTarget and placeTarget(target, false)
	-- Waypoint callbacks can stop or replace guidance synchronously.
	if revision ~= updating then
		return
	end
	native = placed
	if not (facing and map == target.map) or (native and NativeMarkerShown()) then
		-- The native marker leads; nothing to draw, so only the slow poll runs, moving or not.
		frame:SetAlpha(moving and 1 or 0)
		frame.angle = nil
		SetUpdating(false)
		return
	end
	frame:SetAlpha(1)
	local angle = Bearing(x, y) - facing
	-- Exponential decay is frame-rate independent and swings by the shortest arc.
	local delta = frame.angle and Difference(angle, frame.angle) or 0
	local easing = math.abs(delta) > SETTLED
	frame.angle = easing and (frame.angle + delta * (1 - math.exp(-EASE * elapsed))) % TURN or angle
	Draw(frame.angle)
	-- The distance still to walk: to this bend, then along the rest of the path.
	local distance = math.sqrt((target.x - x) ^ 2 + (target.y - y) ^ 2)
	for i = index + 1, #path do
		distance = distance + math.sqrt((path[i].x - path[i - 1].x) ^ 2 + (path[i].y - path[i - 1].y) ^ 2)
	end
	local yards = math.floor(distance)
	if yards ~= frame.yards or frame.metres ~= ns.db.metres then
		frame.metres = ns.db.metres
		frame.yards = yards
		frame.Distance:SetText(ns.FormatDistance(yards))
	end
	Settle(elapsed, easing, moved)
end

OnUpdate = function(_, elapsed)
	Update(elapsed)
end

local function Poll()
	-- Mouse turns and moving transports need not send a player movement event.
	if not frame.updating then
		Update(POLL_EVERY)
	end
end

local function Wake()
	frame.idle = 0
	SetUpdating(true)
end

-- Where it was dragged (screen pixels from the bottom left), else the stock place under the top of the screen.
---@param placed Frame
local function Anchor(placed)
	local scale = placed:GetEffectiveScale() / UIParent:GetEffectiveScale()
	scale = scale > 0 and scale or 1
	placed:ClearAllPoints()
	local x, y = ns.db.arrowX, ns.db.arrowY
	if type(x) == "number" and type(y) == "number" then
		placed:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	else
		placed:SetPoint("TOP", UIParent, "TOP", 0, TOP / scale)
	end
end

local function Create()
	local arrow = CreateFrame("Frame", nil, UIParent)
	---@cast arrow SPFArrowFrame
	frame = arrow
	frame.idle = 0
	frame:SetSize(100, 100)
	frame:SetScale((ns.db.arrowScale or 100) / 100)
	frame:SetClampedToScreen(true)
	Anchor(frame)
	frame:SetFrameStrata("BACKGROUND")
	frame:EnableMouse(false)
	-- Drag to move, Shift-drag for fine placing (Mover.lua); right-click puts it back.
	ns.Mover.Attach(frame, function()
		local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local x, y = frame:GetCenter()
		ns.db.arrowX, ns.db.arrowY = x * scale, y * scale
		Anchor(frame)
	end)
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			ns.db.arrowX, ns.db.arrowY = nil, nil
			Anchor(frame)
		end
	end)
	frame.Mover = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.Mover:SetAllPoints()
	frame.Mover:SetColorTexture(0, 0, 0, 0.5)
	frame.Mover:Hide()
	frame.MoverHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.MoverHint:SetPoint("TOP", frame, "BOTTOM", 0, -2)
	frame.MoverHint:SetText(L["Drag to move; Shift-drag or the arrow keys to nudge. Right-click to reset."])
	frame.MoverHint:Hide()
	frame.Icon = frame:CreateTexture(nil, "BACKGROUND")
	frame.Icon:SetAtlas("Waypoint-MapPin-Tracked", true)
	frame.Icon:SetPoint("CENTER")
	frame.Arrow = frame:CreateTexture(nil, "BACKGROUND")
	frame.Arrow:SetAtlas("Navigation-Tracked-Arrow", true)
	Draw(0)
	frame.Distance = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	frame.Distance:SetPoint("TOP", frame.Icon, "BOTTOM", 0, -8)
	frame.Progress = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	frame.Progress:SetPoint("TOP", frame.Distance, "BOTTOM", 0, -4)
	frame:SetScript("OnShow", function()
		frame.ticker = C_Timer.NewTicker(POLL_EVERY, Poll)
		frame:RegisterEvent("PLAYER_STARTED_MOVING")
		frame:RegisterEvent("PLAYER_STARTED_TURNING")
		Wake()
	end)
	frame:SetScript("OnHide", function()
		SetUpdating(false)
		if frame.ticker then
			frame.ticker:Cancel()
			frame.ticker = nil
		end
		frame:UnregisterAllEvents()
		frame.angle = nil
	end)
	frame:SetScript("OnEvent", Wake)
	-- Made hidden, so the first Show starts the poll and the movement events.
	frame:Hide()
end

-- Guide leads bend by bend, or straight to the walk's end when set to mark only where each step ends.
function ns.RefreshGuideStops()
	revision = revision + 1
	path = source and (ns.db.guideStops and { source[#source] } or source)
	index = 1
	local x, y, _, map = ns.JourneyPosition()
	local nearest
	-- Guide may be restarted halfway along a walk: it resumes at the nearest bend.
	for i = 2, #(path or {}) do
		local a, b = path[i - 1], path[i]
		local dx, dy = b.x - a.x, b.y - a.y
		local length = dx * dx + dy * dy
		if x and map == a.map and map == b.map then
			local t = length > 0 and math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / length)) or 0
			local off = (a.x + t * dx - x) ^ 2 + (a.y + t * dy - y) ^ 2
			if not nearest or off < nearest then
				index, nearest = i, off
			end
		end
	end
	target = path and path[index]
end

-- placeBend owns waypoint placement and returns whether native tracking is ours. Progress lives only here.
---@param points SPFWalkPoints?
---@param placeBend? fun(point: SPFPoint, fading: boolean): boolean?
---@param stop SPFPlace?
---@param goal SPFPoint?
function ns.PointGuideArrow(points, placeBend, stop, goal)
	ns.PointCastPrompt(nil)
	revision = revision + 1
	if points and #points == 0 then
		points = nil
	end
	if points ~= source then
		source = points
		ns.RefreshGuideStops()
	end
	placeTarget = placeBend
	stepEnd, destination = stop, goal
	local updating = revision
	if ns.RefreshCompass then
		ns.RefreshCompass()
	end
	if revision ~= updating then
		return
	end
	if not points or ns.db.arrow == false then
		native = nil
		if frame then
			frame:SetShown(moving)
		end
		return
	end
	if not frame then
		Create()
	end
	frame.Progress:SetText(goal and goal.routeTitle or "")
	frame:Show()
	Wake()
	Update(0)
end

---@return boolean
function ns.ArrowMoving()
	return moving
end

-- "Move the arrow": shows the arrow over a dark box to drag, journey or not.
---@param value boolean
function ns.MoveArrow(value)
	moving = value == true
	if not frame then
		Create()
	end
	frame:EnableMouse(moving)
	frame.Mover:SetShown(moving)
	frame.MoverHint:SetShown(moving)
	if moving then
		frame:SetAlpha(1)
		frame:Show()
	elseif not path or ns.db.arrow == false then
		frame:Hide()
	end
end

---@param value number percent
function ns.SetArrowScale(value)
	if type(value) == "number" then
		ns.db.arrowScale = value
	end
	if frame then
		frame:SetScale((ns.db.arrowScale or 100) / 100)
		Anchor(frame)
	end
	if castPrompt then
		castPrompt:SetScale((ns.db.arrowScale or 100) / 100)
	end
end

-- Read-only targets share Guide's passed bends, including its step-end-only setting.
function ns.GuideTargets()
	if path then
		return target, path[index + 1], stepEnd, destination
	end
end

---@class SPFCastPromptFrame : Frame
---@field Icon Texture
---@field Action FontString
---@type SPFTeleportPlace?
local castTarget

local function RenderCastPrompt()
	if not castPrompt or not castTarget then
		return
	end
	local action, icon = ns.TeleportAction(castTarget)
	castPrompt.Action:SetText(action)
	ns.Art.Icon(castPrompt.Icon, icon or 134400, 36)
end

-- Casting needs an action rather than a bearing, shown in the arrow's usual place.
---@param teleport? SPFTeleportPlace
function ns.PointCastPrompt(teleport)
	castTarget = teleport
	if not teleport then
		if castPrompt then
			castPrompt:UnregisterAllEvents()
			castPrompt:Hide()
		end
		return
	end
	if not castPrompt then
		-- The arrow's frame first: the prompt stands in its place.
		if not frame then
			Create()
		end
		local created = CreateFrame("Frame", nil, UIParent)
		---@cast created SPFCastPromptFrame
		castPrompt = created
		created:SetSize(320, 70)
		created:SetScale((ns.db.arrowScale or 100) / 100)
		-- In the arrow's place, wherever it was dragged, and kept on screen though it is wider.
		created:SetPoint("TOP", frame, "TOP")
		created:SetClampedToScreen(true)
		created:SetFrameStrata("MEDIUM")
		created.Icon = created:CreateTexture(nil, "ARTWORK")
		created.Icon:SetPoint("TOP", created, "TOP")
		created.Action = created:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		created.Action:SetPoint("TOP", created.Icon, "BOTTOM", 0, -6)
		created.Action:SetWidth(320)
		created:SetScript("OnEvent", RenderCastPrompt)
	end
	castPrompt:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	castPrompt:RegisterEvent("SPELLS_CHANGED")
	RenderCastPrompt()
	castPrompt:Show()
end
