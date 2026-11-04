---@type string, ForeverTrackerNamespace
local _, ns = ...

---@class ForeverTrackerModule : Frame
---@field uiOrder? number
---@field parentContainer? Frame
---@field SetContainer fun(self: ForeverTrackerModule, container: Frame)
---@field IsTruncated fun(self: ForeverTrackerModule): boolean

---@class ForeverTrackerHostAPI
---@field Attach fun(module: Frame)
---@field IsAttached fun(module: Frame?): boolean
---@field Debug fun(): string the tracker stack's anchors, heights and in-combat state, for /agf tracker

---@class ForeverNativeTrackerHeader : Frame
---@field Text FontString
---@field MinimizeButton Button

---@class ForeverNativeTrackerFrame : Frame
---@field Header ForeverNativeTrackerHeader
---@field NineSlice Frame?
---@field isCollapsed? boolean

-- Sharing the native tracker collection also shares its Edit Mode execution path.
-- Keep our sections and their frame pools entirely outside that collection.
if not ObjectiveTrackerFrame then
	return
end

if ForeverTrackerHost then
	ns.TrackerHost = ForeverTrackerHost
	return
end

local host = CreateFrame("Frame", "ForeverTrackerCompanion", UIParent)
---@class ForeverTrackerHostAPI
local api = {}
local MIN_SCALE, MAX_SCALE = 0.5, 2
local fallbackSettings = { attached = true, scale = 1 }
local ready = false
local function Coordinate(value)
	if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return value
	end
end
---@return ForeverTrackerSettings
local function Settings()
	local settings = ns.TrackerHostSettings and ns.TrackerHostSettings() or fallbackSettings
	if type(settings.attached) ~= "boolean" then
		settings.attached = true
	end
	settings.locked = settings.locked == true
	local scale = settings.scale
	if type(scale) ~= "number" or scale ~= scale then
		settings.scale = 1
	else
		settings.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
	end
	settings.x, settings.y = Coordinate(settings.x), Coordinate(settings.y)
	return settings
end
local attached
local dragging = false
local attachmentCallbacks = {}
-- Preserve Blizzard's edit-mode placement for the combined column. The
-- private host takes the native frame's original slot; the native frame is
-- placed below it after the private content has laid out. This keeps every
-- section in one column without registering our frames with Blizzard's
-- secure module collection.
local nativeAnchor
local appliedNativeAnchor
-- The saved slot ReleaseNative last wrote, so the probe does not reflow for our own handback.
local releasedNativeAnchor
-- The handback is ignored only once: a later move back onto that slot is someone else's move and reflows.
local releasedNativeProbe = false
-- The column's height and header room when the native frame was last stacked below it: in combat the native frame
-- cannot move, so the sections redraw within this.
local stackedHeight, stackedReserve = 1, 0
-- Whether the native frame was clamped to the screen before we stacked it below our column.
local nativeClamped

-- Hands the native frame's screen clamp back whenever it stops being stacked under our column.
local function RestoreNativeClamp()
	if nativeClamped then
		ObjectiveTrackerFrame:SetClampedToScreen(true)
	end
	nativeClamped = nil
end
local function SameAnchor(anchor, point, relativeTo, relativePoint, x, y)
	return anchor
		and anchor.point == point
		and anchor.relativeTo == relativeTo
		and anchor.relativePoint == relativePoint
		and math.abs(anchor.x - (x or 0)) <= 0.5
		and math.abs(anchor.y - (y or 0)) <= 0.5
end
local function IsAppliedNativeAnchor(point, relativeTo, relativePoint, x, y)
	return SameAnchor(appliedNativeAnchor, point, relativeTo, relativePoint, x, y)
end
local function StackPoints(point)
	if point == "CENTER" or point == "TOP" or point == "BOTTOM" then
		return "TOP", "BOTTOM"
	end
	local horizontal = point:find("RIGHT", 1, true) and "RIGHT" or "LEFT"
	return "TOP" .. horizontal, "BOTTOM" .. horizontal
end
-- Whether the native frame is still where our last restack put it (or on a legacy anchor to the host), rather than
-- somewhere Blizzard, Edit Mode or a UI addon has moved it since.
local function NativeStillOurs(point, relativeTo, relativePoint, x, y)
	return nativeAnchor ~= nil and (relativeTo == host or IsAppliedNativeAnchor(point, relativeTo, relativePoint, x, y))
end
local function CaptureNativeAnchor()
	local point, relativeTo, relativePoint, x, y = ObjectiveTrackerFrame:GetPoint()
	if NativeStillOurs(point, relativeTo, relativePoint, x, y) then
		return
	end
	point, y = point or "TOPRIGHT", y or 0
	local saved = { point = point, relativeTo = relativeTo or UIParent, relativePoint = relativePoint or "TOPRIGHT" }
	saved.x, saved.y = x or 0, y
	-- The column stacks downward from this anchor, so it must be the tracker's top edge. A tracker Edit Mode placed
	-- by its centre or bottom edge would otherwise start the column at that point and push everything off below it.
	if not point:find("TOP", 1, true) then
		local height = ObjectiveTrackerFrame:GetHeight() or 0
		y = y + (point:find("BOTTOM", 1, true) and height or height / 2)
		point = StackPoints(point)
	end
	nativeAnchor = {
		point = point,
		relativeTo = relativeTo or UIParent,
		relativePoint = relativePoint or "TOPRIGHT",
		x = x or 0,
		y = y,
		saved = saved,
	}
end
host:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
local function MatchNativeScale()
	local parentScale = UIParent:GetEffectiveScale()
	local nativeScale = ObjectiveTrackerFrame:GetEffectiveScale()
	if parentScale and nativeScale and parentScale > 0 then
		-- Saved variables, and with them the user's scale, are not ready while the files load.
		local userScale = ready and Settings().scale or 1
		host:SetScale(nativeScale / parentScale * userScale)
	end
end
MatchNativeScale()
-- The native tracker's saved offsets are in its own scale. The private host carries the user's tracker
-- scale on top of that, so convert them to keep the same screen placement and only scale the content.
local function NativeRatio()
	local nativeScale = ObjectiveTrackerFrame:GetEffectiveScale()
	local hostScale = host:GetEffectiveScale()
	if nativeScale and hostScale and hostScale > 0 then
		return nativeScale / hostScale
	end
	return 1
end
host:SetWidth(ObjectiveTrackerFrame:GetWidth())
host:SetHeight(1)
host:SetMovable(true)
host:SetClampedToScreen(true)
-- The grip and the Lock switch that suppresses its drag live in their own file (UI/TrackerLock.lua), which the TOC
-- loads before this one. It hands back the label redraw for a Lock change and the show switch for the attachment.
local Grip = ns.TrackerLock.Grip(host, api)
local function IsLocked()
	return Settings().locked
end
local modules, queued = {}, false
local pools = CreateFramePoolCollection()

local function NotifyAttachment(value)
	for _, callback in ipairs(attachmentCallbacks) do
		callback(value)
	end
end

local function Acquire(parent, template)
	local info = C_XMLUtil.GetTemplateInfo(template)
	local pool = pools:GetOrCreatePool(info and info.type or "Frame", parent, template)
	---@class ForeverTrackerPooledFrame : Frame
	---@field GetLine? function
	---@field FreeLine? function
	---@field OnAnimFinished? function
	local frame, isNew = pool:Acquire(template)
	frame.template = template
	return frame, isNew
end

local function GetLine(block, key, template)
	template = template or block.parentModule.lineTemplate
	local line = block:GetExistingLine(key)
	if line and line.template ~= template then
		block:FreeLine(line)
		line = nil
	end
	if not line then
		line = Acquire(block, template)
		line:SetParent(block)
		line:Show()
	end
	block.usedLines[key] = line
	line.objectiveKey, line.parentBlock, line.used = key, block, true
	return line
end

local function FreeLine(block, line)
	block.usedLines[line.objectiveKey] = nil
	pools:Release(line)
	line:Hide()
	if line.OnFree then
		line:OnFree(block)
	end
end

local function FreeResources(resources, onFree)
	for key, frame in pairs(resources or {}) do
		if not frame.used then
			resources[key] = nil
			if onFree and frame.OnFree then
				frame:OnFree()
			end
			pools:Release(frame)
		end
	end
end

-- Our blocks have no native reward toasts; their animations stay in the private cache.
local function OnAnimFinished(block)
	if block.activeAnim ~= block.AddAnim then
		block.parentModule:RemoveBlockFromCache(block)
		block.parentModule:MarkDirty()
		block:SetAlpha(0)
	end
	block.activeAnim = nil
	if block.pendingAnim then
		local anim = block.pendingAnim
		block.pendingAnim = nil
		block:TryPlayAnim(anim)
	end
end

local Module = {}
function Module:SetContainer(container)
	self.parentContainer = container
	self:SetParent(container)
end
function Module:AcquireFrame(template)
	local frame, isNew = Acquire(self, template)
	frame:SetParent(self.ContentsFrame)
	if frame.GetLine then
		frame.GetLine, frame.FreeLine = GetLine, FreeLine
		if frame.OnAnimFinished then
			frame.OnAnimFinished = OnAnimFinished
		end
	end
	return frame, isNew
end
function Module:FreeBlock(block)
	self:RemoveBlockFromCache(block, true)
	block:Free()
	self.usedBlocks[block.template][block.id] = nil
	pools:Release(block)
	self:OnFreeBlock(block)
end
function Module:FreeUnusedTimerBars()
	FreeResources(self.usedTimerBars)
end
function Module:FreeUnusedProgressBars()
	FreeResources(self.usedProgressBars, true)
end
function Module:FreeUnusedRightEdgeFrames()
	FreeResources(self.usedRightEdgeFrames)
end
function Module.GetContextMenuParent(_)
	return host
end

local function OverlapsMinimap()
	local minimap = _G.Minimap
	if not minimap or not minimap:IsShown() then
		return false
	end
	local left, right, top, bottom = host:GetLeft(), host:GetRight(), host:GetTop(), host:GetBottom()
	local ml, mr, mt, mb = minimap:GetLeft(), minimap:GetRight(), minimap:GetTop(), minimap:GetBottom()
	local hostScale = host:GetEffectiveScale()
	local mapScale = minimap:GetEffectiveScale()
	local screen = UIParent:GetEffectiveScale()
	if not (left and right and top and bottom and ml and mr and mt and mb) then
		return false
	end
	left, right, top, bottom =
		left * hostScale / screen, right * hostScale / screen, top * hostScale / screen, bottom * hostScale / screen
	ml, mr, mt, mb = ml * mapScale / screen, mr * mapScale / screen, mt * mapScale / screen, mb * mapScale / screen
	return left < mr and right > ml and bottom < mt and top > mb
end

local function AvoidMinimap(point)
	if not OverlapsMinimap() then
		return
	end
	host:ClearAllPoints()
	-- Blizzard can temporarily leave the protected frame anchored to our host. Never
	-- anchor back to it in that state: use the saved Edit Mode slot to avoid a cycle.
	local _, relativeTo = ObjectiveTrackerFrame:GetPoint()
	if relativeTo == host and nativeAnchor then
		local direction = point:find("RIGHT", 1, true) and -1 or 1
		local ratio = NativeRatio()
		host:SetPoint(
			nativeAnchor.point,
			nativeAnchor.relativeTo,
			nativeAnchor.relativePoint,
			nativeAnchor.x * ratio + direction * (host:GetWidth() + 8),
			nativeAnchor.y * ratio
		)
	elseif point:find("LEFT", 1, true) then
		host:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)
	else
		host:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
	end
end

local function SidePoint(point)
	local left, right = ObjectiveTrackerFrame:GetLeft(), ObjectiveTrackerFrame:GetRight()
	local screen = UIParent:GetWidth()
	local nativeScale = ObjectiveTrackerFrame:GetEffectiveScale()
	local screenScale = UIParent:GetEffectiveScale()
	if left and right and screen and nativeScale > 0 and screenScale > 0 then
		local nativeCenter = (left + right) * nativeScale / (2 * screenScale)
		return nativeCenter <= screen / 2 and "LEFT" or "RIGHT"
	end
	return point:find("LEFT", 1, true) and "LEFT" or "RIGHT"
end

-- Where a detached column sits until the player drags it: beside the quest list (the native tracker, or Questie's)
-- and level with its top, so neither draws over the other. To its left when the column fits there, otherwise to its
-- right. Offsets are from UIParent's top left corner in the host's own scale; the caller keeps them on screen.
local function Beside(list, width, screenHeight)
	local left, right, top = list:GetLeft(), list:GetRight(), list:GetTop()
	if not (left and right and top) then
		return 0, -40
	end
	local toHost = list:GetEffectiveScale() / host:GetEffectiveScale()
	local x = left * toHost - 8 - width
	if x < 0 then
		x = right * toHost + 8
	end
	return x, top * toHost - screenHeight
end

-- UI/TrackerQuestie.lua, loaded first, finds Questie's quest list (a host loaded without it ignores Questie).
local TrackerQuestie = ns.TrackerQuestie or { List = function() end, Await = function() end }
-- Whether the last attached layout went round Questie's list, and the room it gave the sections.
local besideQuestie, questieRoom = false, 0

-- Blizzard's Edit Mode owns the native slot while its manager is on screen. The manager can also be hidden and locked
-- without exiting (CheckHideAndLockEditMode), which leaves editModeActive true with no EditMode.Exit: a hidden manager
-- is not editing, and its own show and hide reflow, or the column would stay hidden after the lock.
local managerHooked = false
local function HookEditMode()
	local manager = EditModeManagerFrame
	if managerHooked or not manager then
		return
	end
	managerHooked = true
	manager:HookScript("OnShow", host.MarkDirty)
	manager:HookScript("OnHide", host.MarkDirty)
end

local function Editing()
	local manager = EditModeManagerFrame
	return not not (manager and manager:IsEditModeActive() and manager:IsShown())
end

-- Native methods remain untouched so controller and combat paths retain their secure execution.
local nativeHeader = ObjectiveTrackerFrame.Header --[[@as ForeverNativeTrackerHeader?]]
local function NativeHeaderShown()
	if not nativeHeader or not ObjectiveTrackerFrame:IsShown() or not nativeHeader:IsShown() then
		return false
	end
	-- IsVisible also covers an ancestor the client or another addon has hidden, which IsShown on the header alone
	-- would miss. The harness frames model it the same way.
	return nativeHeader.IsVisible == nil or nativeHeader:IsVisible()
end

local function NativeCollapsed()
	return ObjectiveTrackerFrame.isCollapsed == true
end

-- Lays every section out from the host's top. Returns whether any section drew.
local function LayoutModules(width, available, reserve)
	ns.TrackerOrder.Sort(modules)
	local heights, total = {}, 0
	for index, module in ipairs(modules) do
		module:SetWidth(width)
		module:Update(math.max(0, available - total))
		local used = module:GetContentsHeight()
		heights[index] = used
		if used > 0 then
			total = total + used + 10
		end
	end
	local hasSections = total > 0
	local height = hasSections and reserve or 0
	for index, module in ipairs(modules) do
		module:ClearAllPoints()
		module:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -height)
		local used = heights[index]
		if used > 0 then
			height = height + used + 10
		end
	end
	host:SetHeight(math.max(1, height))
	return hasSections
end
-- Hands the native frame back to the slot Blizzard, Edit Mode or a UI addon gave it, clamp included, when it is still
-- where our last restack left it. One moved since is already in someone else's hands and stays where it is. Out of
-- combat only: the native frame is protected.
local function ReleaseNative()
	if NativeStillOurs(ObjectiveTrackerFrame:GetPoint()) then
		ObjectiveTrackerFrame:ClearAllPoints()
		local saved = nativeAnchor.saved
		ObjectiveTrackerFrame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, saved.x, saved.y)
		releasedNativeAnchor, releasedNativeProbe = saved, true
	end
	appliedNativeAnchor = nil
	RestoreNativeClamp()
end
-- Switches the host between attached and detached when the settings or combat state allow, and returns the settings
-- that chose the mode.
local function ApplyAttachment()
	local settings = Settings()
	local desired = settings.attached ~= false
	if attached == nil then
		attached = desired
	elseif not InCombatLockdown() and desired ~= attached then
		if not desired then
			ReleaseNative()
		end
		attached = desired
	end
	return settings
end

-- Detached: the private column sits wherever the player dragged it, independent of the native tracker.
local function LayoutDetached(settings)
	host:Show()
	MatchNativeScale()
	local scale = host:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local screenWidth, screenHeight = UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
	local width = math.min(ObjectiveTrackerFrame:GetWidth(), screenWidth)
	host:SetWidth(width)
	if dragging then
		return
	end
	local x, y
	if settings.x and settings.y then
		x, y = settings.x / scale, settings.y / scale
	else
		local questie = TrackerQuestie.List(host, host.MarkDirty)
		x, y = Beside(questie or ObjectiveTrackerFrame, width, screenHeight)
	end
	x = math.max(0, math.min(x, math.max(0, screenWidth - width)))
	y = math.min(0, math.max(y, 24 - screenHeight))
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
	-- With no section to show, the column hides entirely, its title too; the next layout with content shows it again.
	if not LayoutModules(width, math.max(24, screenHeight + y - 24), 24) then
		host:Hide()
		return
	end
	y = math.min(0, math.max(y, math.min(host:GetHeight(), screenHeight) - screenHeight))
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

-- In combat: the native tracker is protected, so the private column lives around it rather than restacking it.
local function LayoutInCombat()
	-- The native tracker is protected: in combat it cannot be restacked below our column. The header is not
	-- protected and nothing protected anchors to it, so it stays at the top of our column. Only Blizzard moving
	-- the native frame itself sends us to the one-column fallback below its content.
	if appliedNativeAnchor and IsAppliedNativeAnchor(ObjectiveTrackerFrame:GetPoint()) then
		-- Still stacked: the sections follow their content within the height the stack gave them (less the last
		-- section's 10px gap, which LayoutModules adds back), and the next out-of-combat reflow sizes them again.
		-- A hidden header leaves no gap; a section that gains content grows the stack instead of waiting.
		local reserve = NativeHeaderShown() and stackedReserve or 0
		local room = math.max(0, stackedHeight - reserve - 10)
		local truncated = false
		local drew = not NativeCollapsed() and LayoutModules(host:GetWidth(), room, reserve)
		for _, module in ipairs(modules) do
			truncated = truncated or (module.IsTruncated ~= nil and module:IsTruncated())
		end
		if drew and truncated then
			-- Measure the new content uncapped, then keep the taller stack for the rest of the fight.
			LayoutModules(host:GetWidth(), math.max(room, (host:GetTop() or UIParent:GetHeight()) - 24), reserve)
			stackedHeight = math.max(stackedHeight, host:GetHeight() or 1)
			drew = LayoutModules(host:GetWidth(), math.max(0, stackedHeight - reserve - 10), reserve)
		end
		if drew then
			host:Show()
		else
			host:Hide()
		end
		return
	end
	-- An empty column hid the host out of combat; a section that gains content in combat shows it again (it is
	-- addon-owned, so showing it in combat is allowed). A collapsed All Objectives keeps the sections hidden.
	host:SetShown(not NativeCollapsed())
	CaptureNativeAnchor()
	host:SetWidth(ObjectiveTrackerFrame:GetWidth())
	host:ClearAllPoints()
	-- Once Blizzard has restored the protected frame to its saved slot, anchor our private
	-- column to the native frame's actual top edge. This follows CENTER/BOTTOM anchors,
	-- offsets and UI scale without writing the protected frame. During the brief window
	-- before that restore, the native frame still points at us; use the saved slot instead
	-- to avoid creating an anchor cycle.
	local point, nativeRelativeTo = ObjectiveTrackerFrame:GetPoint()
	if nativeRelativeTo == host then
		-- Preserve the saved slot if a legacy host-relative anchor is restored.
		-- Moving relative to that protected child would create an anchor cycle.
		if nativeAnchor then
			local ratio = NativeRatio()
			host:SetPoint(
				nativeAnchor.point,
				nativeAnchor.relativeTo,
				nativeAnchor.relativePoint,
				nativeAnchor.x * ratio,
				nativeAnchor.y * ratio
			)
		end
	elseif point then
		local nativePoint, hostPoint = StackPoints(point)
		local ratio = NativeRatio()
		-- First choice: one column. The header goes back to the native frame and our sections sit directly below
		-- the native tracker's visible content, measured from its own content region, so the column reads the
		-- header, the game's modules, then the Forever sections. The protected frame stays where Blizzard put it.
		local nineSlice = ObjectiveTrackerFrame.NineSlice
		local nativeBottom = ObjectiveTrackerFrame:GetBottom()
		local contentBottom = nineSlice and ObjectiveTrackerFrame:IsShown() and nineSlice:GetBottom() or nativeBottom
		local contentGap = (nativeBottom and contentBottom) and (contentBottom - nativeBottom) or 0
		host:SetPoint("TOP", ObjectiveTrackerFrame, "BOTTOM", 0, contentGap * ratio)
		local layoutScale = host:GetEffectiveScale()
		local layoutScreenScale = UIParent:GetEffectiveScale()
		local layoutMargin = 24 * layoutScreenScale / layoutScale
		contentBottom = (contentBottom or 0) * ratio
		LayoutModules(host:GetWidth(), math.max(0, contentBottom - layoutMargin), 0)
		if contentBottom - (host:GetHeight() or 0) >= layoutMargin then
			return
		end
		-- The one-column placement would run off the bottom of the screen. If there is no room above the restored
		-- tracker, use the side away from its anchored edge. This keeps the private column visible without moving
		-- or overlapping the protected frame.
		host:ClearAllPoints()
		local nativeTop = ObjectiveTrackerFrame:GetTop() or 0
		local screenTop = UIParent:GetHeight() or nativeTop
		local hostScale = host:GetEffectiveScale()
		local screenScale = UIParent:GetEffectiveScale()
		local nativeScale = ObjectiveTrackerFrame:GetEffectiveScale()
		local room = screenTop * screenScale - nativeTop * nativeScale
		if room >= math.max(host:GetHeight() or 0, 1) * hostScale then
			host:SetPoint(hostPoint, ObjectiveTrackerFrame, nativePoint, 0, 0)
		elseif SidePoint(point) == "LEFT" then
			host:SetPoint("TOPLEFT", ObjectiveTrackerFrame, "TOPRIGHT", 0, 0)
		else
			host:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
		end
		AvoidMinimap(point)
	elseif nativeAnchor then
		local _, hostPoint = StackPoints(nativeAnchor.point)
		local ratio = NativeRatio()
		host:SetPoint(
			hostPoint,
			nativeAnchor.relativeTo,
			nativeAnchor.relativePoint,
			nativeAnchor.x * ratio,
			nativeAnchor.y * ratio
		)
	end
	AvoidMinimap(nativeAnchor and nativeAnchor.point or "TOPRIGHT")
end

-- Attached: the private column shares the native tracker's slot and stacks below its content.
local function LayoutAttached()
	-- Read the global each time, not once at load: Blizzard_EditMode is load-on-demand, so it may appear later. A
	-- manager hidden while still active is a locked Edit Mode, which owns nothing on screen, so the column shows.
	HookEditMode()
	if Editing() then
		return
	end
	host:Show()
	-- The native frame may only receive its final Edit Mode anchor after the
	-- player and saved variables are ready. Capture it before our first reflow.
	CaptureNativeAnchor()
	local width = ObjectiveTrackerFrame:GetWidth()
	MatchNativeScale()
	local ratio = NativeRatio()
	host:ClearAllPoints()
	host:SetPoint(
		nativeAnchor.point,
		nativeAnchor.relativeTo,
		nativeAnchor.relativePoint,
		nativeAnchor.x * ratio,
		nativeAnchor.y * ratio
	)
	local layoutScale = host:GetEffectiveScale()
	local layoutScreenScale = UIParent:GetEffectiveScale()
	-- The user's scale enlarges the column; keep it on screen the way the detached column already is.
	width = math.min(width, UIParent:GetWidth() * layoutScreenScale / layoutScale)
	local layoutMargin = 40 * layoutScreenScale / layoutScale
	local available = math.max(0, (host:GetTop() or UIParent:GetHeight()) - layoutMargin)
	host:SetWidth(width)
	-- The native header stays in its frame, so the private column reserves no header room.
	local collapsed = NativeCollapsed()
	local headerReserve = 0
	if collapsed or not LayoutModules(width, available, 0) then
		-- Nothing to stack: release the native tracker and hide the empty host.
		ReleaseNative()
		host:SetHeight(1)
		host:Hide()
		return
	end
	-- If the combined column would run below the screen, move the whole
	-- column upward from its saved edit-mode slot.  The offset is calculated
	-- from the original point each pass, so repeated refreshes never drift.
	local shift = 0
	host:ClearAllPoints()
	host:SetPoint(
		nativeAnchor.point,
		nativeAnchor.relativeTo,
		nativeAnchor.relativePoint,
		nativeAnchor.x * ratio,
		nativeAnchor.y * ratio
	)
	local screenHeight = UIParent:GetHeight()
	local top = host:GetTop()
	local scale = host:GetEffectiveScale()
	local screenScale = UIParent:GetEffectiveScale()
	local margin = 24 * screenScale / scale
	local screen = screenHeight and screenHeight * screenScale / scale
	if screen and top and top - host:GetHeight() < margin then
		shift = margin - (top - host:GetHeight())
		shift = math.min(shift, math.max(0, screen - margin - top))
	end
	host:ClearAllPoints()
	host:SetPoint(
		nativeAnchor.point,
		nativeAnchor.relativeTo,
		nativeAnchor.relativePoint,
		nativeAnchor.x * ratio,
		nativeAnchor.y * ratio + shift
	)
	local nativeScale = ObjectiveTrackerFrame:GetEffectiveScale()
	local hostScale = host:GetEffectiveScale()
	local hostLeft = (host:GetLeft() or 0) * hostScale / screenScale
	-- Keep the native frame directly below the host; its header remains inside the native frame.
	local nativeY = (host:GetBottom() or 0) * hostScale / screenScale - UIParent:GetHeight()
	-- The native container owns its height. Screen clamping would pull it up over the
	-- companion column, so preserve its size and let its scrolling content extend below us.
	if nativeClamped == nil then
		nativeClamped = ObjectiveTrackerFrame:IsClampedToScreen() and true or false
	end
	ObjectiveTrackerFrame:SetClampedToScreen(false)
	ObjectiveTrackerFrame:ClearAllPoints()
	local nativeWidth = ObjectiveTrackerFrame:GetWidth() * nativeScale / screenScale
	-- A smaller private column must not push the full-width native quests beyond the screen edge.
	hostLeft = math.max(0, math.min(hostLeft, UIParent:GetWidth() - nativeWidth))
	local nativeX = hostLeft * screenScale / nativeScale
	local nativeOffsetY = nativeY * screenScale / nativeScale
	-- Read our height before moving the protected frame: its layout can reflow us inside SetPoint.
	local stackHeight = host:GetHeight() or 1
	ObjectiveTrackerFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", nativeX, nativeOffsetY)
	releasedNativeAnchor, releasedNativeProbe = nil, false
	stackedHeight, stackedReserve = stackHeight, headerReserve
	appliedNativeAnchor = {
		point = "TOPLEFT",
		relativeTo = UIParent,
		relativePoint = "TOPLEFT",
		x = nativeX,
		y = nativeOffsetY,
	}
	-- Resizing the managed container schedules a native layout that restores its Edit Mode
	-- anchor. Leave its height alone so the host and native tracker can settle in one pass.
end

-- Attached while Questie's list covers the native slot: the column goes below, above or beside it and the native
-- tracker keeps its slot. Only our frames move, so this runs in combat too; with `questie` nil (Questie hid its list in
-- combat) the column holds its place until combat ends.
---@param questie Frame?
local function LayoutBesideQuestie(questie)
	if Editing() then
		return
	end
	besideQuestie = true
	if not InCombatLockdown() then
		ReleaseNative()
	end
	if not questie then
		host:SetShown(LayoutModules(host:GetWidth(), questieRoom, 0))
		return
	end
	host:Show()
	MatchNativeScale()
	local scale = host:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local screenWidth, screenHeight = UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
	local width = math.min(ObjectiveTrackerFrame:GetWidth(), screenWidth)
	host:SetWidth(width)
	questieRoom = TrackerQuestie.Room(questie, host)
	if not LayoutModules(width, questieRoom, 0) then
		host:Hide()
		return
	end
	local besideX = Beside(questie, width, screenHeight)
	local places = TrackerQuestie.Places(questie, host, besideX, screenWidth, screenHeight)
	for index, place in ipairs(places) do
		host:ClearAllPoints()
		host:SetPoint(place[1], UIParent, place[1], place[2], place[3])
		if index == #places or not OverlapsMinimap() then
			return
		end
	end
end

local function Layout()
	queued = false
	if Editing() then
		return
	end
	local settings = ApplyAttachment()
	Grip.Show(not attached)
	if not attached then
		besideQuestie = false
		LayoutDetached(settings)
		return
	end
	local questie = TrackerQuestie.List(host, host.MarkDirty)
	if questie or (besideQuestie and InCombatLockdown()) then
		LayoutBesideQuestie(questie)
		return
	end
	besideQuestie = false
	if InCombatLockdown() then
		LayoutInCombat()
		return
	end
	LayoutAttached()
end

function host.MarkDirty(_)
	if ready and not queued then
		queued = true
		C_Timer.After(0, Layout)
	end
end
-- Questie hides the native tracker and its header, so a collapsed All Objectives no longer hides the sections.
function host.IsCollapsed(_)
	return attached == true and not besideQuestie and NativeCollapsed()
end
function host:ForceExpand()
	self:MarkDirty()
end

function api.GetSettings()
	return Settings()
end
---@return number
function api.GetScale()
	return Settings().scale or 1
end
-- The attached host must not restack the protected native tracker during combat, so a scale change waits for
-- the reflow on PLAYER_REGEN_ENABLED. Detached, the host owns its frames and scales straight away.
---@param value number
function api.SetScale(value)
	if type(value) ~= "number" or value ~= value then
		return
	end
	local settings = Settings()
	local scale = math.max(MIN_SCALE, math.min(MAX_SCALE, value))
	if settings.scale == scale then
		return
	end
	settings.scale = scale
	host:MarkDirty()
end
---@return boolean
function api.IsLocked()
	return IsLocked()
end
---@param value boolean
function api.SetLocked(value)
	Settings().locked = not not value
	Grip.SetLabel(value)
end
function api.IsAttachedToQuestTracker()
	return Settings().attached ~= false
end
function api.SetAttached(value)
	value = not not value
	local settings = Settings()
	if settings.attached == value then
		return
	end
	settings.attached = value
	NotifyAttachment(value)
	host:MarkDirty()
end
function api.OnAttachmentChanged(callback)
	attachmentCallbacks[#attachmentCallbacks + 1] = callback
end
function api.SavePosition(x, y)
	if attached or type(x) ~= "number" or type(y) ~= "number" then
		return
	end
	local settings = Settings()
	settings.x, settings.y = x, y
	host:MarkDirty()
end
function api.Attach(module)
	---@cast module ForeverTrackerModule
	if module.parentContainer == host then
		return
	end
	Mixin(module, Module)
	modules[#modules + 1] = module
	module:SetContainer(host)
	host:MarkDirty()
end
function api.IsAttached(module)
	---@cast module ForeverTrackerModule?
	return module ~= nil and module.parentContainer == host
end
host:RegisterEvent("PLAYER_REGEN_ENABLED")
host:RegisterEvent("PLAYER_REGEN_DISABLED")
host:RegisterEvent("DISPLAY_SIZE_CHANGED")
host:RegisterEvent("UI_SCALE_CHANGED")
-- Native objective changes and managed-frame transitions can restore the tracker anchor.
-- Observe their events; wrapping its methods taints controller and secure layout paths.
for _, event in ipairs({
	"QUEST_LOG_UPDATE",
	"QUEST_WATCH_UPDATE",
	"QUEST_WATCH_LIST_CHANGED",
	"PLAYER_ALIVE",
	"PLAYER_DEAD",
	"PLAYER_UNGHOST",
	"ZONE_CHANGED_NEW_AREA",
}) do
	host:RegisterEvent(event)
end
host:SetScript("OnEvent", function()
	host:MarkDirty()
end)
ObjectiveTrackerFrame:HookScript("OnSizeChanged", function()
	host:MarkDirty()
end)
-- The game's managed frame layout, Edit Mode and UI addons such as EllesmereUI put the native frame back in its saved
-- slot with no event of their own, which left the quests drawn over the Forever sections until the next quest event.
-- An addon-owned probe spans from the screen's bottom left corner to the native frame's top left corner, so any move
-- of the native frame resizes the probe and its OnSizeChanged reflows the column. Our own restack is skipped.
local probe = CreateFrame("Frame", nil, UIParent)
local probeEnabled = false
local function SetProbeEnabled(enabled)
	if probeEnabled == enabled then
		return
	end
	probeEnabled = enabled
	probe:ClearAllPoints()
	if enabled then
		probe:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
		probe:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPLEFT", 0, 0)
	end
end
probe:SetScript("OnSizeChanged", function()
	if not probeEnabled then
		return
	end
	local point, relativeTo, relativePoint, x, y = ObjectiveTrackerFrame:GetPoint()
	local released = attached and SameAnchor(releasedNativeAnchor, point, relativeTo, relativePoint, x, y)
	if released and releasedNativeProbe then
		releasedNativeProbe = false
	elseif not IsAppliedNativeAnchor(point, relativeTo, relativePoint, x, y) and not released then
		host:MarkDirty()
	end
end)
SetProbeEnabled(not Editing())
-- Collapsing "All Objectives" hides the shared sections too. Mark the host dirty on the click that flips it; the
-- native collapse method itself stays unhooked and untouched, and the native header keeps its parent so its button
-- resolves the native container normally.
if nativeHeader and nativeHeader.MinimizeButton then
	nativeHeader.MinimizeButton:HookScript("OnClick", function()
		host:MarkDirty()
	end)
end
-- Edit Mode restores Blizzard's saved anchor through its public callbacks. Reflow
-- on those events instead of polling the native frame every frame.
local function OnEditModeChanged()
	HookEditMode()
	local editing = Editing()
	SetProbeEnabled(not editing)
	if editing and attached then
		-- Hand the native anchor and screen clamp back before Edit Mode moves the tracker.
		if not InCombatLockdown() then
			ReleaseNative()
		end
		host:Hide()
		-- Hidden frames still participate in anchor dependencies; detach our column too.
		host:ClearAllPoints()
		host:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
	else
		host:Show()
	end
	host:MarkDirty()
end
EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeChanged, host)
EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeChanged, host)
EventRegistry:RegisterCallback("EditMode.SavedLayouts", OnEditModeChanged, host)
-- A developer diagnostic for the tracker stack (/agf tracker). The combat overlap is otherwise invisible headlessly: it
-- prints both frames' anchors, heights and who each is anchored to.
---@return string
function api.Debug()
	-- Raw literals on purpose: this host is shared with the companion addons, whose ns.L has no AGF keys, and
	-- lint_copy only rejects literals passed straight to Print/SetText (this returns a string instead).
	local function point(frame)
		local p = { frame:GetPoint() }
		local relative = p[2] == host and "host" or tostring(p[2])
		return ("%s rel %s %s %.1f,%.1f"):format(
			tostring(p[1]),
			relative,
			tostring(p[3]),
			tonumber(p[4]) or 0,
			tonumber(p[5]) or 0
		)
	end
	local function geometry(frame)
		return ("%.1f,%.1f-%.1f,%.1f s%.2f"):format(
			frame:GetLeft() or -1,
			frame:GetTop() or -1,
			frame:GetRight() or -1,
			frame:GetBottom() or -1,
			frame:GetEffectiveScale()
		)
	end
	local form = "combat=%s shown=%s hostH=%.1f host[%s] g[%s] nativeH=%.1f native[%s] g[%s] uiS%.2f"
	return (form .. " stacked=%s clamped=%s questie=%s"):format(
		tostring(InCombatLockdown()),
		tostring(host:IsShown()),
		host:GetHeight() or -1,
		point(host),
		geometry(host),
		ObjectiveTrackerFrame:GetHeight() or -1,
		point(ObjectiveTrackerFrame),
		geometry(ObjectiveTrackerFrame),
		UIParent:GetEffectiveScale(),
		tostring(IsAppliedNativeAnchor(ObjectiveTrackerFrame:GetPoint()) and true or false),
		tostring(ObjectiveTrackerFrame:IsClampedToScreen()),
		tostring(besideQuestie)
	)
end

ForeverTrackerHost = api -- taint-ok: addon-owned companion tracker registry
ns.TrackerHost = api

EventUtil.ContinueAfterAllEvents(function()
	ready = true
	host:MarkDirty()
	TrackerQuestie.Await(host.MarkDirty)
end, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
