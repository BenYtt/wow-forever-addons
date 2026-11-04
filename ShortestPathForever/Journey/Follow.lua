---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- Following a player: a journey whose destination is a party or raid member, kept pointing
-- at where they are now so the arrow, compass, tracker and map stay on them.
--
-- The client reports a player's position only as a 0-1 fraction of a zone map, so it arrives
-- coarse and a little late; refreshing every frame would replan for jitter nobody can see.
-- A refresh is therefore due on a throttle and only once the member has moved a visible
-- distance, and the replan itself is handed to the next quiet frame (tests/follow_bench.lua
-- has the numbers behind both choices).
--
-- Following is opt-in: nothing follows until the player asks for it.

-- Seconds between refreshes: one replan a second, the interval the bench measures as the
-- cheapest one that still reads as following someone rather than trailing them.
local THROTTLE = 1
-- A member who has moved less than this since the last refresh is standing still for our
-- purposes: a map fraction is a few yards wide, and smaller steps are noise.
local MOVED = 10
-- Within this distance of the member, following is over: you are together.
local ARRIVE = 40

---@class SPFFollowState
---@field unit string
---@field throttle number seconds between refreshes
---@field point? SPFPoint where the member was when the journey was last planned
---@field waiting number seconds until the next refresh is considered
---@field arrived boolean

---@type SPFFollowState?
local following
-- The newest position a refresh wants, and whether one is already waiting on a quiet frame.
---@type SPFPoint?
local pending
local scheduled

-- The follow driver only runs a frame timer while a follow is under way: an idle addon that
-- ticks every frame is what the UI checks (and the client's frame budget) refuse.
---@type Frame?
local driver

local function Driver()
	if not driver then
		driver = CreateFrame("Frame", "ShortestPathForeverFollowDriver", UIParent)
		driver:SetScript("OnUpdate", function(_, elapsed)
			ns.FollowTick(elapsed)
		end)
	end
	return driver
end

-- The member's position as a journey point, or nil while the client cannot say: a member on
-- another map, one who has not loaded, or a position the client keeps back. The map fraction
-- is converted the way a map click is (JourneyInput.lua's WorldPoint), so the point is in the
-- frame the planner already uses.
---@param unit string
---@return SPFPoint?
function ns.FollowPoint(unit)
	local map = C_Map.GetBestMapForUnit(unit)
	if not map then
		return nil
	end
	local position = C_Map.GetPlayerMapPosition(map, unit)
	if not position then
		return nil
	end
	local x, y = position:GetXY()
	if not x or not y or (x == 0 and y == 0) then
		-- The client answers 0, 0 for a unit it cannot place on that map.
		return nil
	end
	return ns.WorldPoint(map, x, y)
end

-- The distance between two journey points, in yards, or nil when they are on different maps.
---@param a SPFPoint
---@param b SPFPoint
---@return number?
local function Distance(a, b)
	if a.map ~= b.map then
		return nil
	end
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Where the player stands, in the same frame as a follow point.
---@return SPFPoint?
local function Here()
	local x, y, _, map = ns.JourneyPosition()
	return x and { map = map, x = x, y = y }
end

-- A unit's name can be a secret the client keeps back (tools/lint_secret.py), so the target is
-- named for what it is: the tracker, the arrow and the pin all say "Party member".
local function Name()
	return L["Party member"]
end

-- Point the journey at the member now. Called from a quiet frame only.
local function Apply()
	scheduled = nil
	local point = pending
	pending = nil
	if not (point and following) then
		return
	end
	local label = Name()
	following.point = point
	point.label, point.routeTitle = label, label
	ns.StartJourney(point)
end

-- Queue a replan. A walking search is sliced across frames with its own budget, so a replan
-- must never share a frame with a search slice: the two together overshoot the frame, which
-- is what the bench measured before this deferral.
local function Request()
	if scheduled then
		return
	end
	scheduled = true
	ns.Path.after(function()
		if ns.Path.Busy() then
			-- Let the search slice finish this frame; the next follow tick queues again.
			scheduled = nil
			return
		end
		Apply()
	end)
end

---@param unit string
---@param throttle? number seconds between refreshes, defaulting to THROTTLE
---@return boolean started
function ns.StartFollowing(unit, throttle)
	if not (UnitExists(unit) and not UnitIsUnit(unit, "player")) then
		return false
	end
	local point = ns.FollowPoint(unit)
	if not point then
		ns.Print(L["That player is not on a map you can see."])
		return false
	end
	-- The journey was just planned to where they are, so the first refresh waits a full
	-- throttle rather than firing on the next frame.
	local seconds = throttle or THROTTLE
	following = { unit = unit, throttle = seconds, waiting = seconds, arrived = false, point = point }
	Driver()
	local label = Name()
	point.label, point.routeTitle = label, label
	ns.StartJourney(point)
	Driver()
	return true
end

function ns.StopFollowing()
	following, pending, scheduled = nil, nil, nil
	if driver then
		driver:SetScript("OnUpdate", nil)
	end
end

---@return boolean active
function ns.IsFollowing()
	return following ~= nil
end

-- One frame of following, called from the follow driver's OnUpdate. The throttle counts this
-- frame time down rather than a wall clock, so it follows the game's own clock and pauses
-- with it.
---@param elapsed number seconds since the last frame
function ns.FollowTick(elapsed)
	if not following then
		return
	end
	local unit = following.unit
	if not UnitExists(unit) then
		ns.StopFollowing()
		return
	end
	local here = Here()
	local point = ns.FollowPoint(unit)
	if not point then
		-- A member who steps into an instance or off the map keeps the journey where it was:
		-- ending it under the player's feet would be worse than one stale destination.
		return
	end
	following.waiting = following.waiting - elapsed
	local close = here and Distance(here, point)
	if close and close <= ARRIVE then
		if not following.arrived then
			following.arrived = true
			ns.Print(L["You have caught up with %s."]:format(Name()))
		end
		return
	end
	following.arrived = false
	if following.waiting > 0 then
		return
	end
	local moved = following.point and Distance(following.point, point)
	if moved and moved < MOVED then
		-- Nothing the player could see has changed since the last replan.
		following.waiting = 0
		return
	end
	following.waiting = following.throttle
	pending = point
	Request()
end
