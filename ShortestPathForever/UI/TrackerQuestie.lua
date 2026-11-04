---@type string, ForeverTrackerNamespace
local _, ns = ...

-- Questie's tracker (Questie/Questie, Modules/Tracker/TrackerBaseFrame.lua) draws its quest list in Questie_BaseFrame:
-- a MEDIUM strata frame on UIParent with a backdrop, placed at ObjectiveTrackerFrame:GetPoint() until the player drags
-- it, and shown or hidden by Questie at any time, combat included. Questie also hides the native tracker, so its slot
-- looks empty while that list covers it. UI/TrackerHost.lua, loaded after this file, moves the shared column clear of
-- the list. The list is only read here, never moved or changed.
---@class ForeverTrackerQuestie
local TrackerQuestie = {}
ns.TrackerQuestie = TrackerQuestie

-- The room the column leaves between itself and the list, and from the screen's edges.
local GAP, MARGIN = 8, 24
local watched = false
local waits = 0

-- Another addon's globals, read with rawget: neither exists unless Questie is installed and its tracker is on.
---@return Frame?
local function BaseFrame()
	return rawget(_G, "Questie_BaseFrame")
end

-- The list's show, hide, size and drag-stop scripts call `onChange` when the list toggles, grows or is dragged, and
-- one addon-owned ticker notices the moves and resizes nothing of the list's own does: a profile load, or a UI addon
-- such as MoveAnything, sets the list's anchor with no event and no script of its own.
--
-- Nothing of ours is ever anchored to the list. A probe frame reaching from the screen's corner to the list's corner
-- put Questie_BaseFrame inside our layout's anchor family, and Questie's drag code reads the list's GetLeft and GetTop
-- just before it clears the list's points (Modules/Tracker/TrackerBaseFrame.lua, _UpdateTrackerPosition), so a layout
-- pass of ours landing in that window left it nothing to read: it errored, and left the list unanchored, invisible and
-- undraggable (Questie/Questie#8076, #188). Read here, never written: the ticker asks the list where it is.
local WATCH_INTERVAL = 0.25
local ticker, sinceTick, lastPlace

-- Where the list says it is, as one string, so a move or a resize shows up as a different one.
local function Place(frame)
	local point, relativeTo, relativePoint, x, y = frame:GetPoint()
	return table.concat({
		tostring(point),
		tostring(relativeTo),
		tostring(relativePoint),
		x or 0,
		y or 0,
		frame:GetWidth() or 0,
		frame:GetHeight() or 0,
	}, "|")
end

local function Watch(frame, onChange)
	watched = true
	frame:HookScript("OnShow", onChange)
	frame:HookScript("OnHide", onChange)
	frame:HookScript("OnDragStop", onChange)
	-- While the player drags or resizes the list Questie owns its geometry: the column holds its place, and one reflow
	-- follows the list to where the player let go of it.
	local function Moved()
		if frame.isMoving or frame.isSizing then
			return
		end
		onChange()
	end
	frame:HookScript("OnSizeChanged", Moved)
	ticker = ticker or CreateFrame("Frame")
	lastPlace = Place(frame)
	ticker:SetScript("OnUpdate", function(_, elapsed)
		sinceTick = (sinceTick or 0) + (elapsed or 0)
		if sinceTick < WATCH_INTERVAL or not frame:IsShown() or frame.isMoving or frame.isSizing then
			return
		end
		sinceTick = 0
		local place = Place(frame)
		if place ~= lastPlace then
			lastPlace = place
			onChange()
		end
	end)
end

-- Questie's list while it is on screen, or nil. A list anchored to `host` moves with it, so it can never be cleared:
-- that one is left alone.
---@param host Frame
---@param onChange function
---@return Frame?
function TrackerQuestie.List(host, onChange)
	local frame = BaseFrame()
	if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then
		return nil
	end
	if not watched then
		Watch(frame, onChange)
	end
	local _, relativeTo = frame:GetPoint()
	if not frame:IsShown() or relativeTo == host then
		return nil
	end
	if not (frame:GetLeft() and frame:GetRight() and frame:GetTop() and frame:GetBottom()) then
		return nil
	end
	return frame
end

-- Questie builds its tracker a few seconds after login, in stages. While Questie is loaded and the list is not there
-- yet, check once a second, at most 30 times, and call `onFound` as soon as it appears.
---@param onFound function
function TrackerQuestie.Await(onFound)
	if watched or waits >= 30 or not rawget(_G, "Questie") or BaseFrame() then
		return
	end
	waits = waits + 1
	C_Timer.After(1, function()
		if BaseFrame() then
			onFound()
		else
			TrackerQuestie.Await(onFound)
		end
	end)
end

-- The list's edges in `host`'s own scale, from the screen's bottom left corner: left, right, top, bottom.
local function Edges(list, host)
	local toHost = list:GetEffectiveScale() / host:GetEffectiveScale()
	return list:GetLeft() * toHost, list:GetRight() * toHost, list:GetTop() * toHost, list:GetBottom() * toHost
end

-- The height the sections may take: the room beside the list, the most any place gives. Below and above take them
-- only if they fit.
---@param list Frame
---@param host Frame
---@return number
function TrackerQuestie.Room(list, host)
	local _, _, top = Edges(list, host)
	return math.max(0, top - MARGIN)
end

-- Where `host`, as laid out, can go round the list, best first, each as { point on UIParent, x, y } in the host's
-- scale: below the list, then above it, each only when it fits on screen, then beside it at `besideX`, level with its
-- top, which always comes last. Below and above line up with the list's edge nearer the screen's side.
---@param list Frame
---@param host Frame
---@param besideX number
---@param screenWidth number
---@param screenHeight number
---@return { [1]: FramePoint, [2]: number, [3]: number }[]
function TrackerQuestie.Places(list, host, besideX, screenWidth, screenHeight)
	local left, right, top, bottom = Edges(list, host)
	local width, height = host:GetWidth(), host:GetHeight()
	local function onScreen(x)
		return math.max(0, math.min(x, math.max(0, screenWidth - width)))
	end
	local x = onScreen((left + right) / 2 <= screenWidth / 2 and left or right - width)
	local places = {}
	if bottom - GAP - height >= MARGIN then
		places[#places + 1] = { "TOPLEFT", x, bottom - GAP - screenHeight }
	end
	if top + GAP + height <= screenHeight - MARGIN then
		places[#places + 1] = { "BOTTOMLEFT", x, top + GAP }
	end
	places[#places + 1] = { "TOPLEFT", onScreen(besideX), top - screenHeight }
	return places
end
