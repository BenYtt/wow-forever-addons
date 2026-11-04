---@class SPFNamespace
local ns = select(2, ...)

-- Destination pin: the game's own waypoint pin, held on screen over the journey's final
-- destination so it can be seen all the way there rather than only on the map.
--
-- The pin is placed by the bearing to the destination and the way you are facing: straight
-- ahead sits it above the middle of the screen, over your shoulder pulls it to the side, and
-- a destination behind you drops it below, fading as it goes. It only draws while a journey
-- runs and only in the zone you are in; on another map the tracker and the map carry it.
--
-- It stands down while Waypoint UI is tracking a navigation of its own: that addon's pin owns
-- the world then, and two pins on one destination is the fight #271 was about.
--
-- Under the distance it carries one short line of the current step's wording (#323), so the pin
-- says what the step is and not only how far it is; the full text of every step stays in the
-- map pin's tooltip, and the line is reread only when the step changes.

-- Pixels from the middle of the screen with the destination dead ahead.
local REACH = 150
-- How much further out a destination behind you sits, as a factor of REACH.
local BEHIND = 2
-- Alpha ahead and behind; the pin is dimmest at your back so it never competes with the fight.
local ALPHA_AHEAD, ALPHA_BEHIND = 1, 0.4
-- Seconds between updates: the arrow rides the same interval, and the pin needs nothing faster.
local POLL = 0.1
local PIN_ATLAS, PIN_WIDTH, PIN_HEIGHT = "Waypoint-MapPin-Tracked", 28, 36

---@class SPFDestinationPinFrame : Frame
---@field Pin Texture
---@field Distance FontString
---@field Step FontString
---@field step string? the wording the step line shows, so it is only reset when it changes
---@field elapsed number
---@type SPFDestinationPinFrame?
local frame
local polling

-- Where the pin belongs, in pixels from the middle of the screen, and how strong it is.
-- bearing and facing are counter-clockwise from north, like GetPlayerFacing and the arrow.
---@param bearing number? angle to the destination
---@param facing number? the player's facing
---@param distance number? yards to the destination
---@return number? x, number? y, number? alpha
function ns.PinPlace(bearing, facing, distance)
	if type(bearing) ~= "number" or type(facing) ~= "number" or type(distance) ~= "number" then
		return nil
	end
	local angle = (bearing - facing + math.pi) % (2 * math.pi) - math.pi
	local front = math.cos(angle)
	local reach = REACH * (1 + (1 - front) * (BEHIND - 1) / 2)
	local alpha = ALPHA_BEHIND + (ALPHA_AHEAD - ALPHA_BEHIND) * (front + 1) / 2
	return math.sin(angle) * reach, -front * reach, alpha
end

---@return SPFDestinationPinFrame
local function Create()
	local pin = CreateFrame("Frame", "ShortestPathForeverDestinationPin", UIParent) --[[@as SPFDestinationPinFrame]]
	pin:SetSize(PIN_WIDTH, PIN_HEIGHT + 28)
	pin:SetFrameStrata("MEDIUM")
	pin:SetAlpha(1)
	pin.Pin = pin:CreateTexture(nil, "ARTWORK")
	pin.Pin:SetPoint("TOP", pin, "TOP", 0, 0)
	ns.Art.Fit(pin.Pin, PIN_ATLAS, PIN_WIDTH, PIN_HEIGHT)
	pin.Distance = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	pin.Distance:SetPoint("TOP", pin, "TOP", 0, -PIN_HEIGHT + 4)
	pin.Distance:SetJustifyH("CENTER")
	pin.Step = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pin.Step:SetPoint("TOP", pin.Distance, "BOTTOM", 0, -2)
	pin.Step:SetJustifyH("CENTER")
	pin.Step:SetWordWrap(false)
	pin.Step:SetMaxLines(1)
	pin.elapsed = 0
	pin:Hide()
	frame = pin
	return pin
end

local function Hide()
	if frame then
		frame:Hide()
	end
end

-- Whether there is anything to draw, before any of the per-frame work: a journey, the pin
-- setting, a destination in the zone the player is in, and no other addon's pin in charge.
---@return boolean
function ns.DestinationPinWanted()
	if not (ns.db and ns.db.destinationPin) then
		return false
	end
	local goal = ns.JourneyGoal()
	local x, _, _, map = ns.JourneyPosition()
	if not goal or not x or goal.map ~= map then
		return false
	end
	if ns.WaypointUIPinOwned and ns.WaypointUIPinOwned() then
		return false
	end
	return true
end

-- Longest step wording the pin shows: one short line under the distance, since the map pin's
-- tooltip carries the full text of every step.
local STEP_MAX = 32
local stepText, stepKey

-- The current step's wording, as the tracker and the map pin's tooltip put it, cut to one line.
-- rows are JourneyInfo's, whose current row is the step being walked.
---@param title string?
---@param rows SPFRow[]?
---@return string?
function ns.PinStepText(title, rows)
	local wording
	for _, row in ipairs(rows or {}) do
		if row.current and row.text then
			wording = row.text
			break
		end
	end
	wording = wording or title
	if type(wording) ~= "string" or wording == "" then
		return nil
	end
	if #wording > STEP_MAX then
		wording = (wording:sub(1, STEP_MAX - 3):gsub("%s+%S*$", "")) .. "..."
	end
	return wording
end

-- The step wording costs a JourneyInfo build, so it is read only when the step changes: the goal
-- and the stop index the route is on. Between steps the pin reuses the line it already has.
---@param goal SPFPoint
---@return string?
local function StepText(goal)
	if not (ns.JourneyInfo and ns.JourneyStops) then
		return nil
	end
	local _, index = ns.JourneyStops()
	local key = tostring(goal) .. ":" .. tostring(index)
	if key ~= stepKey then
		stepKey = key
		local title, rows = ns.JourneyInfo()
		stepText = ns.PinStepText(title, rows)
	end
	return stepText
end

-- One update of the pin: where it goes, how strong it is and how far there is to go.
function ns.RefreshDestinationPin()
	if not ns.DestinationPinWanted() then
		Hide()
		return
	end
	local goal = ns.JourneyGoal()
	local x, y = ns.JourneyPosition()
	if not (goal and x and y) then
		Hide()
		return
	end
	local dx, dy = goal.x - x, goal.y - y
	local distance = math.sqrt(dx * dx + dy * dy)
	local offsetX, offsetY, alpha = ns.PinPlace(math.atan2(dy, dx), GetPlayerFacing() or 0, distance)
	if not (offsetX and offsetY and alpha) then
		Hide()
		return
	end
	local pin = frame or Create()
	pin:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
	pin:SetAlpha(alpha)
	pin.Distance:SetText(ns.FormatDistance(distance, true))
	local step = StepText(goal)
	if pin.step ~= step then
		pin.step = step
		pin.Step:SetText(step or "")
		pin.Step:SetShown(step ~= nil)
	end
	pin:Show()
end

-- The pin only works a frame timer while a journey is being followed, never while idle.
---@param on boolean
local function Poll(on)
	if on and not polling then
		polling = true
		local pin = frame or Create()
		pin:SetScript("OnUpdate", function(self, elapsed)
			self.elapsed = self.elapsed + elapsed
			if self.elapsed < POLL then
				return
			end
			self.elapsed = 0
			ns.RefreshDestinationPin()
		end)
	elseif not on and polling then
		polling = false
		if frame then
			frame:SetScript("OnUpdate", nil)
			frame:Hide()
		end
	end
end

-- Settings: turn the pin on and off from the panel, without a reload.
function ns.DestinationPinChanged()
	if ns.DestinationPinWanted() then
		Poll(true)
		ns.RefreshDestinationPin()
	else
		Poll(false)
	end
end

ns.Init(function()
	-- Only a player who turned the pin on pays for a timer; with the setting off there is no
	-- frame callback at all.
	if ns.db and ns.db.destinationPin then
		Poll(true)
	end
end)
