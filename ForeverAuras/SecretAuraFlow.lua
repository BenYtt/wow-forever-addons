-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Modern Aura Group: a normal Group whose Aura (Modern) children grow together.
--
-- Nothing in Lua can know in combat which of these displays has an aura, so
-- the group cannot move its children like a Dynamic Group. Instead each child
-- draws from a "start" frame anchored to the end of the previous child's
-- content, and Blizzard's own frame sizes decide where that end is:
--   Aura(s) Found: the child's aura container, one icon (and spacing) wide per
--     aura shown, one pixel when empty.
--   Aura(s) Missing: a second, invisible container that is one icon wide when
--     the aura is present; it is anchored backwards, so the end moves back.
--   Always, and Total Duration = / >= lists: a fixed icon.
-- The group applies the chain at safe time; Blizzard keeps it in step in combat.
-- Grouped by unit frame or nameplate, each display's aura area for a unit is
-- attached to the previous display's area for the same unit instead
-- (RelinkFlowUnits). The group also sets sort order and limit.
--
-- Centered growth: nothing can halve a secret size, so every part above also
-- gets an invisible "shadow" copy at half its size, with the same filters and
-- unit. The shadows are chained backwards from the centre point; their far
-- end is where the visible row starts, so the row stays centred.
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("SecretAuraFlow")
local Display = Private.BlizzardAuraDisplay
-- ForeverAuras: the rechain queue and the load-scan hold (see QueueRechain,
-- Display.BeginFlowLoad), declared here so the preview arrangement above
-- them can honour the hold as the rechain does (issue #136).
local afterCombat, queued, loadScan = {}, {}, 0
local function Locked(frame) return Display.Locked ~= nil and Display.Locked(frame) end
local function Busy(frame)
  if Locked(frame) then return true end
  return InCombatLockdown() and frame.IsProtected ~= nil and frame:IsProtected()
end
local function Place(frame, ...)
  if Busy(frame) then return false end
  return pcall(frame.SetPoint, frame, ...)
end
local function SetShown(frame, shown)
  if not frame or Busy(frame) or frame:IsShown() == shown then return end
  if shown then frame:Show() else frame:Hide() end
end

-- A display's own X/Y Offset (Display settings) inside a Modern Aura Group:
-- added to that display's place in the row only. The next display keeps the
-- place the row gives it, so a nudged display does not drag the rest along.
local function OwnOffset(data)
  if type(data) ~= "table" then return 0, 0 end
  local x, y = tonumber(data.xOffset) or 0, tonumber(data.yOffset) or 0
  return x, y
end
-- A chained flow's own offset, none for the row's first flow (its region's
-- place, which already carries the offset, is where the row starts) or nil.
-- Only Aura (Modern) displays take it: an ordinary display in the row keeps
-- the placement it always had (its preview does not apply offsets either).
-- Relative to the first flow's own offset: the row already starts offset by
-- that much, so a later display with the same offset (members that all
-- anchor to one frame with one offset, say) adds nothing, and only the
-- difference between its offset and the first's moves it.
-- An ordinary display's own offset counts only as the row's first offset
-- (its region's place carries it like any first display's); chained, it
-- takes none (RowOffset).
local function FlowOwnOffset(flow)
  if not flow then return 0, 0 end
  if flow.normal then return OwnOffset(flow.normal.data) end
  local data = flow.region and flow.region.blizzardAuraDisplay and flow.region.blizzardAuraDisplay.data
  return OwnOffset(data)
end
local function RowOffset(flow, first)
  if not flow or flow == first or flow.normal then return 0, 0 end
  -- A row-start helper (the end of a centred row's shadows) is not a
  -- display and carries no offset of its own.
  if not flow.region then return 0, 0 end
  local x, y = FlowOwnOffset(flow)
  local fx, fy = FlowOwnOffset(first)
  return x - fx, y - fy
end

-- A chain frame (a display's start, or its shadow start) is anchored to
-- Blizzard's aura frames, and the client can make such a frame forbidden to
-- addon code once its position depends on their secret layout. After that
-- it can be neither re-anchored nor hidden (ClearAllPoints raised "Attempt
-- to access forbidden object"), so it is left where it is, drawing nothing,
-- and a fresh frame takes its place in the chain. Its size is kept on the
-- flow (sizeKey), since a forbidden frame cannot be measured either.
-- A start frame is where a display draws from. On a scaled group a step along
-- the row is a fraction of a pixel, so the engine rounds each start to the
-- pixel grid: every icon and its pixel-perfect border then land on whole
-- pixels, and the gaps vary by a pixel instead, as in a Dynamic Group.
local function OnPixels(frame)
  if frame.SetRoundLayoutToNearestPixel then frame:SetRoundLayoutToNearestPixel(true) end
  return frame
end

local function FreshFrame(flow, key, sizeKey, region)
  local frame = flow[key]
  if not frame or not Locked(frame) then return frame end
  frame = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
  frame:EnableMouse(false)
  if key == "start" then OnPixels(frame) end
  local size = flow[sizeKey]
  frame:SetSize(size and size[1] or 1, size and size[2] or 1)
  if flow.endFrame == flow[key] then flow.endFrame = frame end
  flow[key] = frame
  return frame
end

Display.flowGrowths = {RIGHT = L["Right"], LEFT = L["Left"], DOWN = L["Down"], UP = L["Up"],
  CENTER_HORIZONTAL = L["Centered Horizontal"], CENTER_VERTICAL = L["Centered Vertical"]}

-- Per growth: the corner a child's content starts from, the corner of an
-- Aura(s) Found container where the next child starts (with the pixel an
-- empty container keeps), and the axis.
local GROWTH = {
  RIGHT = {start = "TOPLEFT", listEnd = "TOPRIGHT", pixel = {-1, 0}, far = "TOPRIGHT", sign = {1, 0}},
  LEFT = {start = "TOPRIGHT", listEnd = "TOPLEFT", pixel = {1, 0}, far = "TOPLEFT", sign = {-1, 0}},
  DOWN = {start = "TOPLEFT", listEnd = "BOTTOMLEFT", pixel = {0, 1}, far = "BOTTOMLEFT", sign = {0, -1}},
  UP = {start = "BOTTOMLEFT", listEnd = "TOPLEFT", pixel = {0, -1}, far = "TOPLEFT", sign = {0, 1}},
}
-- Centered: the visible row grows right (or down); its shadows grow the other
-- way from the centre point on the first display (top middle, or left middle).
local function Centered(visible, shadow, centerPoint)
  local result = CopyTable(GROWTH[visible])
  result.visible, result.shadow, result.centerPoint = visible, GROWTH[shadow], centerPoint
  return result
end
GROWTH.CENTER_HORIZONTAL = Centered("RIGHT", "LEFT", "TOP")
GROWTH.CENTER_VERTICAL = Centered("DOWN", "UP", "LEFT")

-- The direction a display's own aura area grows in.
function Display.VisibleGrowth(growth)
  return GROWTH[growth] and GROWTH[growth].visible or growth
end

-- The Modern Aura Group this display belongs to, or nil.
function Display.FlowGroup(data)
  local parent = data and data.parent and WeakAuras.GetData(data.parent)
  if parent and parent.regionType == "group" and parent.blizzardFlow then return parent end
end

local function GrowthKey(group)
  local growth = GROWTH[group.blizzardFlowGrowth] and group.blizzardFlowGrowth or "RIGHT"
  local mode = group.blizzardFlowFrames
  if mode ~= "UNITFRAME" and mode ~= "NAMEPLATE" then return growth end
  local selfPoint = group.selfPoint or "CENTER"
  if growth == "CENTER_HORIZONTAL" then
    if selfPoint:find("LEFT") then return "RIGHT" end
    if selfPoint:find("RIGHT") then return "LEFT" end
  elseif growth == "CENTER_VERTICAL" then
    if selfPoint:find("TOP") then return "DOWN" end
    if selfPoint:find("BOTTOM") then return "UP" end
  end
  return growth
end
Display.FlowGrowthKey = GrowthKey

-- Screen pixels per UI unit where a region is drawn, or nil when unknown.
local function PixelsPerUnit(region)
  local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
  local scale = region and region.GetEffectiveScale and region:GetEffectiveScale()
  if type(factor) ~= "number" or factor <= 0 or type(scale) ~= "number" or issecretvalue(scale) or scale <= 0 then return nil end
  return scale / factor
end

-- The spacing the row uses after a display of the given size along it: the
-- group's spacing, made a whole number of screen pixels on top of a whole
-- pixel icon (the icon boxes round to pixels). On a scaled group a step of
-- 37 units is 44.4 pixels, which would round to 44 or 45 depending on where
-- the row sits; this way every gap comes out the same, as in a Dynamic Group.
function Display.FlowSpacing(group, region, size)
  local spacing = tonumber(group.blizzardFlowSpacing) or 2
  local px = PixelsPerUnit(region)
  if not px or type(size) ~= "number" then return spacing end
  local icon = math.floor(size * px + 0.5)
  local gap = math.floor(spacing * px + 0.5)
  return (icon + gap) / px - size
end

-- Half a step, in whole pixels where the scale is known.
function Display.FlowHalf(region, step)
  local px = PixelsPerUnit(region)
  if not px then return math.floor(step / 2) end
  return math.floor(step * px / 2 + 0.0001) / px
end

-- The offset that puts a frame's start corner on a whole screen pixel. The
-- row's origin is a display's own frame, whose place is readable; every step
-- after it is a whole number of pixels, so this one nudge grids the whole row.
local function SnapOffset(frame, point)
  local px = PixelsPerUnit(frame)
  if not px or not frame or not frame.GetLeft then return 0, 0 end
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  -- Each checked by name: a frame not laid out yet returns nil, and a nil
  -- ends ipairs before the values after it are seen.
  for _, value in pairs({left = left, right = right, top = top, bottom = bottom}) do
    if type(value) ~= "number" or issecretvalue(value) then return 0, 0 end
  end
  if left == nil or right == nil or top == nil or bottom == nil then return 0, 0 end
  point = point or "TOPLEFT"
  local x = point:find("LEFT") and left or point:find("RIGHT") and right or (left + right) / 2
  local y = point:find("TOP") and top or point:find("BOTTOM") and bottom or (top + bottom) / 2
  x, y = x * px, y * px
  return (math.floor(x + 0.5) - x) / px, (math.floor(y + 0.5) - y) / px
end

function Display.FlowGrowth(data)
  local group = Display.FlowGroup(data)
  if not group then return end
  local g = GROWTH[GrowthKey(group)]
  local width, height = Display.Dimensions(data)
  local entry = Private.regions[data.id]
  local region = entry and entry.region
  return GrowthKey(group), Display.FlowSpacing(group, region, (g.sign[1] ~= 0) and width or height)
end

Display.flowFrameModes = {SCREEN = L["Screen"], UNITFRAME = L["Unit Frames"], NAMEPLATE = L["Nameplates"]}

-- "UNITFRAME" or "NAMEPLATE" when the group places its displays on each
-- unit's frame, else nil.
function Display.FlowFrameMode(data)
  local group = Display.FlowGroup(data)
  local mode = group and group.blizzardFlowFrames
  if mode == "UNITFRAME" or mode == "NAMEPLATE" then return mode end
end

Display.flowSortModes = {
  none = "None", ascending = "Ascending", descending = "Descending",
  expiration = "Remaining time (Blizzard priority)", name = L["Name"], namePriority = "Name (Blizzard priority)",
  blizzard = "Blizzard default", important = "Importance only", bigDefensive = "Big defensives", applied = "Order applied",
}
Display.flowSortOrder = {"ascending", "descending", "expiration", "name", "namePriority", "blizzard", "important", "bigDefensive", "applied", "none"}
local sortModeMethods = {
  none = "Default", ascending = "ExpirationOnly", descending = "ExpirationOnly", expiration = "Expiration",
  name = "NameOnly", namePriority = "Name", blizzard = "Default", important = "ImportantOnly",
  bigDefensive = "BigDefensive", applied = "AuraInstanceIDOnly",
}
local legacySortModes = {
  Expiration = "expiration", Name = "namePriority", NameOnly = "name", ImportantOnly = "important",
  BigDefensive = "bigDefensive", AuraInstanceIDOnly = "applied",
}

function Display.FlowSortMode(group)
  if not group then return "none" end
  if Display.flowSortModes[group.blizzardFlowSortMode] then return group.blizzardFlowSortMode end
  local legacy = group.blizzardFlowSort
  if legacy == "ExpirationOnly" then return group.blizzardFlowReverse and "descending" or "ascending" end
  return legacySortModes[legacy] or "none"
end

-- The group's sort order for every display in it, else the trigger's own.
function Display.SortOrder(data, trigger)
  local group = Display.FlowGroup(data)
  local method, reverse
  if group then
    local mode = Display.FlowSortMode(group)
    method = sortModeMethods[mode]
    reverse = mode == "descending"
  else
    method, reverse = trigger.sortMethod, trigger.sortReverse
  end
  -- Blizzard classification is not applied, so its sort has no meaning here.
  if not Display.sortMethods[method or "Default"] or method == "UnitFrameDebuff" then method = "Default" end
  return AuraContainerSortMethod[method or "Default"],
    reverse and AuraContainerSortDirection.Reverse or AuraContainerSortDirection.Normal
end

-- The anchor type that decides where a display's auras go: its Modern Aura
-- Group's mode when it is in one (the group is authoritative), else its own.
function Display.FrameAnchorType(data)
  if Display.FlowGroup(data) then return Display.FlowFrameMode(data) or "SCREEN" end
  return data.anchorFrameType
end

-- The group's limit of auras per display (20 without a limit), or nil.
function Display.FlowLimit(data)
  local group = Display.FlowGroup(data)
  if not group then return end
  if not group.blizzardFlowUseLimit then return 20 end
  return math.max(1, math.floor(tonumber(group.blizzardFlowLimit) or 5))
end

-- Why this display cannot join its Modern Aura Group's growth, or nil.
function Display.FlowProblem(data, trigger)
  if not Display.FlowGroup(data) then return end
  if not Display.missingTypes[data.regionType] then return L["In a Modern Aura Group, use an Icon, Progress Bar, Progress Texture, Texture or Text display."] end
  if Display.RemainingWindow(trigger) and Display.FlowGrid(Display.FlowGroup(data)) then return L["In a Grid, Remaining Time is not available."] end
  local mode = Display.FlowFrameMode(data)
  if mode then
    if Display.IsSingle(trigger) and not Display.NeedsMissing(trigger) then return L["Grouped by unit frame or nameplate, use Show On: Aura(s) Found."] end
    if mode == "NAMEPLATE" and trigger.unit ~= "nameplate" then return L["Grouped by nameplate, choose the Nameplate unit."] end
    if mode == "UNITFRAME" and trigger.unit == "nameplate" then return L["Grouped by unit frame, choose a unit other than Nameplate."] end
  end
end

-- Aura containers in a Modern Aura Group depend on other displays' secret sizes,
-- so they also opt out of untrusted layout scripts, like every frame anchored
-- to an aura container must. Returns the container and whether it opted out.
-- Every native container made here remembers the last value passed to its
-- SetEnabled (faEnabled; nil until the first call). Enabling a container makes
-- Blizzard evaluate and lay out all of its auras again on the client side, so
-- RefreshUnits (BlizzardAuraDisplay.lua) skips an enable, and the refresh that
-- follows it, when nothing about the container changed. The counts feed the
-- /fa phitch report.
local function TrackEnabled(container)
  local setEnabled = container.SetEnabled
  container.SetEnabled = function(self, enabled)
    enabled = enabled and true or false
    self.faEnabled = enabled
    if Private.HitchCount then Private.HitchCount(enabled and "container enable" or "container disable") end
    return setEnabled(self, enabled)
  end
  return container
end

function Display.CreateAuraContainer(parent, data, optOut)
  if optOut or Display.FlowGroup(data) then
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent,
      "CustomAuraContainerTemplate, DisableUntrustedLayoutScriptsTemplate")
    if ok and container then return TrackEnabled(container), true end
  end
  return TrackEnabled(CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")), false
end

-- Anchors a container to a Modern Aura Group start frame; falls back to the
-- region when Blizzard refuses the anchor.
function Display.AnchorToContent(container, point, region, relativePoint, x, y)
  local anchor = Display.ContentAnchor(region)
  if anchor ~= region and Place(container, point, anchor, relativePoint, x or 0, y or 0) then return true end
  if Busy(container) then return false end
  container:ClearAllPoints()
  container:SetPoint(point, region, relativePoint, x or 0, y or 0)
  return anchor == region
end

-- ForeverAuras: row layout ("Use old row layout", Modern Aura Group Settings). A group-owned row
-- ("group") starts at the group's own anchor point, as a Dynamic Group's
-- children start at the group; a member's own X/Y Offset moves that
-- member's content only (its content frame, FlowContent), never the row.
-- In both modes the ordinary displays that cannot be copied (bars and the
-- like) lead the row: a frame placed from a secret-length container must opt
-- out of untrusted layout scripts, which a display's own frames do not, and
-- a Centered row starts a secret distance back. The legacy row (nil) starts
-- at the first display's own anchor and takes offsets relative to the first
-- display. Imported groups keep the legacy row; new Modern Aura Groups get
-- the group-owned one.
function Display.FlowGroupOwned(group)
  return group ~= nil and group.blizzardFlowOrigin == "group"
end

-- The frame and point a group-owned row starts from: the group's region at
-- its own anchor point (its selfPoint corner sits on the anchor; the frame's
-- size changes around it, as a Dynamic Group's does).
local function RowOrigin(group)
  local entry = Private.regions[group.id]
  return entry and entry.region, group.selfPoint or "CENTER"
end

-- A member's content frame in a group-owned row: the same rectangle as its
-- start frame, moved by the member's own X/Y Offset. Containers, the Missing
-- look, samples and stand copies hang from it (ContentAnchor), so the offset
-- moves the content and the chain, which runs through the start frames, does
-- not see it. Made on demand; a locked one is replaced (FreshFrame).
function Display.FlowContent(flow, region)
  if not flow.content then
    flow.content = OnPixels(CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate"))
    flow.content:EnableMouse(false)
  end
  FreshFrame(flow, "content", "startSize", region)
  return flow.content
end

local function PlaceContent(flow, ox, oy)
  local content = flow.content
  if not content or Busy(content) then return end
  -- A child of the start frame, so it shows and hides with it (the editor
  -- hides a stand's start frame while its preview stands in).
  if content:GetParent() ~= flow.start and not InCombatLockdown() then content:SetParent(flow.start) end
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", flow.start, "TOPLEFT", ox or 0, oy or 0)
  content:SetPoint("BOTTOMRIGHT", flow.start, "BOTTOMRIGHT", ox or 0, oy or 0)
end

-- Where this display's content is drawn from: its content frame in a
-- group-owned row, its start frame in a legacy row, else the region itself.
function Display.ContentAnchor(region)
  local native = region.blizzardAuraDisplay
  local flow = native and native.flow
  return flow and (flow.content or flow.start) or region
end

-- Called by Apply before anything is laid out.
function Display.EnsureFlowStart(region, data)
  local native = region.blizzardAuraDisplay
  if not Display.FlowGroup(data) then
    if native.flow then SetShown(native.flow.start, false); native.flow = nil end
    return
  end
  Display.WatchFlowVisibility(region)
  local flow = native.flow or {}
  native.flow = flow
  if not flow.start then
    -- Anchored to other displays' aura containers, whose size is secret.
    flow.start = OnPixels(CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate"))
    flow.start:EnableMouse(false)
  end
  local width, height = Display.Dimensions(data)
  flow.startSize = {width, height}
  FreshFrame(flow, "start", "startSize", region)
  flow.start:SetSize(width, height)
  SetShown(flow.start, true)
  local growth = Display.FlowGrowth(data)
  flow.growth = GROWTH[growth]
  -- Until the chain is built, start where the region is.
  flow.start:ClearAllPoints()
  flow.start:SetPoint(flow.growth.start, region, flow.growth.start)
  -- ForeverAuras: group-owned row: the content frame carries the display's
  -- own offset (FlowContent); a legacy row draws from the start frame.
  local hadContent = flow.content ~= nil
  if Display.FlowGroupOwned(Display.FlowGroup(data)) then
    Display.FlowContent(flow, region)
    PlaceContent(flow, OwnOffset(data))
    flow.contentOn = flow.start
  elseif flow.content then
    SetShown(flow.content, false)
    flow.content = nil
  end
  -- The content anchor changed with the row mode: the containers must be
  -- anchored again (RefreshUnits re-anchors an instance marked unanchored;
  -- its anchor record names the region either way, so it would not notice).
  if hadContent ~= (flow.content ~= nil) then
    for _, instance in ipairs(native.instances or {}) do instance.anchored = false end
  end
end

-- Called by Apply once the display's parts exist: records where the next
-- child starts. presence: the Aura(s) Missing end container, when there is one.
function Display.SetFlowEnd(region, data, presence)
  local native = region.blizzardAuraDisplay
  local flow = native and native.flow
  if not flow then return end
  local g = flow.growth
  local trigger = Display.GetTrigger(data)
  local _, spacing = Display.FlowGrowth(data)
  local width, height = Display.Dimensions(data)
  local showOn = Display.ShowOn(trigger)
  -- ForeverAuras: group-owned row: only the aura containers hang from the
  -- content frame (AnchorToContent) and so carry the display's own offset;
  -- the Remaining Time text and the Missing presence container are measured
  -- from the start frame and carry none. The chain takes the offset back off
  -- only where it is (RechainFlow); taken off a presence end, a Missing
  -- display's offset moved every member after it the other way.
  flow.endInContent = false
  if flow.remain then
    -- The measured pixels back from the text's end (MeasureText), in the
    -- next display's units.
    local px = PixelsPerUnit(flow.start) or 1
    local back = (flow.remainBack or 1) / px
    flow.endFrame, flow.endPoint, flow.x, flow.y = flow.remain, g.far, -g.sign[1] * back, -g.sign[2] * back
  elseif showOn == "showOnMissing" and presence then
    flow.endFrame, flow.endPoint, flow.x, flow.y = presence, g.start, 0, 0
  -- A gate (Total Duration or Stack Count) keeps the candidates on one spot.
  elseif showOn == "showOnActive" and not Display.UsesGate(data) and native.instances[1] then
    -- Several units are chained one after another; the last one ends the display.
    flow.endFrame, flow.endPoint = native.instances[#native.instances].container, g.listEnd
    flow.x, flow.y = g.pixel[1], g.pixel[2]
    flow.endInContent = true
  else
    -- A fixed icon: Always, or a Total Duration list whose candidates overlap.
    flow.endFrame, flow.endPoint = flow.start, g.start
    flow.x, flow.y = g.sign[1] * (width + spacing), g.sign[2] * (height + spacing)
  end
end

-- The Aura(s) Missing end container: one icon plus spacing along the growth
-- axis per present aura.
function Display.FlowPresenceSize(data)
  local growth, spacing = Display.FlowGrowth(data)
  local width, height = Display.Dimensions(data)
  local along = GROWTH[growth].sign[1] ~= 0
  local size = (along and width or height) + spacing + 1
  return along and {elementWidth = size, elementHeight = height} or {elementWidth = width, elementHeight = size}
end

-- Anchors a presence container (one element of size along the growth axis)
-- so its start edge moves back by that size when the aura is present: empty,
-- it is one pixel, so what follows starts size - 1 further on. Only after its
-- aura group exists: Blizzard refuses the anchor before that.
local OPPOSITE = {TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "TOPLEFT"}
local function AnchorBackwards(container, g, startFrame, size, region)
  local along = g.sign[1] ~= 0
  local point = along and OPPOSITE[g.start] or (g.start == "TOPLEFT" and "BOTTOMLEFT" or "TOPLEFT")
  container:ClearAllPoints()
  local ok = Place(container, point, startFrame, g.start, g.sign[1] * size, g.sign[2] * size)
  if not ok then
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", region, "TOPLEFT")
  end
  return ok
end

-- Returns false when Blizzard refuses it.
function Display.AnchorFlowPresence(region, data, container)
  local flow = region.blizzardAuraDisplay and region.blizzardAuraDisplay.flow
  if not flow then return false end
  local layout = Display.FlowPresenceSize(data)
  local along = flow.growth.sign[1] ~= 0
  -- The empty container is one unit wide (measured), so anchoring its far
  -- edge icon + spacing + 1 on puts its near edge, where the next display
  -- starts, at exactly icon + spacing.
  return AnchorBackwards(container, flow.growth, flow.start, along and layout.elementWidth or layout.elementHeight, region)
end

---------------------------------------------------------------------------- centered growth
-- An invisible container with the display's filters that measures presence:
-- maxCount elements of the given size, laid out towards g.
local SHADOW_GROUP = "FAShadow"
local function MeasureContainer(existing, region, data, g, layout, maxCount, filter, candidates)
  local container = existing
  if not container then
    container = Display.CreateAuraContainer(region, data)
    container:SetEnabled(false)
    container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    -- Placed on the region first, like every aura container; chained later.
    container:SetPoint("TOPLEFT", region, "TOPLEFT")
    local ok = pcall(container.AddAuraGroup, container, SHADOW_GROUP, filter, {
      candidateFilters = candidates, maxFrameCount = maxCount, layout = layout,
      initializeFrame = function(button)
        -- Draws nothing; only the container's size is used.
        button:SetSize(layout.elementWidth, layout.elementHeight)
        button:SetAlpha(0)
        button:EnableMouse(false)
      end,
    })
    if not ok then container:Hide(); Display.RetireFrame(container); return nil end
  else
    container:SetAuraGroupFilterString(SHADOW_GROUP, filter)
    container:SetAuraGroupCandidateFilters(SHADOW_GROUP, candidates)
    container:SetAuraGroupLayout(SHADOW_GROUP, layout)
    container:SetAuraGroupMaxFrameCount(SHADOW_GROUP, maxCount)
    container:SetAuraGroupEnabled(SHADOW_GROUP, true)
  end
  local vertical = g.sign[2] ~= 0
  container:SetFlowLayoutAxis(vertical and AnchorUtil.FlowLayoutAxis.Vertical or AnchorUtil.FlowLayoutAxis.Horizontal)
  container:SetFlowLayoutAnchorPoint(g.start)
  container:SetFlowLayoutGrowthDirection(g.sign[1] < 0 and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right,
    g.sign[2] > 0 and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
  return container
end

---------------------------------------------------------------------------- sort across displays
function Display.MergesAcross(group)
  return group and group.blizzardFlow and Display.FlowSortMode(group) ~= "none" and not Display.FlowGrid(group) or false
end

local function Serialize(value)
  if type(value) ~= "table" then return tostring(value) end
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. Serialize(value[key]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Merged displays are drawn by one host, so only identical looks may merge.
local notAppearance = {id = true, uid = true, parent = true, triggers = true, trigger = true, load = true, xOffset = true, yOffset = true,
  anchorPoint = true, anchorFrameType = true, anchorFrameFrame = true, selfPoint = true, information = true,
  authorOptions = true, config = true, actions = true, internalVersion = true, tocversion = true, semver = true,
  url = true, desc = true, version = true, preferToUpdate = true, sortHybridTable = true, controlledChildren = true,
  frameStrata = true, frameLevel = true, anchorFrameParent = true, anchorFramePoint = true, anchorFrameOffset = true,
  anchorPerUnit = true, useAnchorPerUnit = true, animation = true, source = true, wagoID = true,
  ignoreWagoUpdate = true, skipWagoUpdate = true}
local appearanceKeys = setmetatable({}, {__mode = "k"})

-- Data can change in place without the options (imports, other addons): Apply forgets its key.
function Display.ForgetAppearanceKey(data)
  if data then appearanceKeys[data] = nil end
end

local function AppearanceKey(data)
  -- Options edit data in place: no keys are kept while they are open.
  local editing = WeakAuras.IsOptionsOpen()
  if editing then wipe(appearanceKeys) elseif appearanceKeys[data] then return appearanceKeys[data] end
  local parts = {}
  for key, value in pairs(data) do
    if not notAppearance[key] and not (key == "displayIcon" and data.iconSource ~= 0) then
      parts[#parts + 1] = tostring(key) .. "=" .. Serialize(value)
    end
  end
  table.sort(parts)
  local key = table.concat(parts, ",")
  if not editing then appearanceKeys[data] = key end
  return key
end

function Display.MergeKey(data)
  local trigger = Display.GetTrigger(data)
  if type(trigger) ~= "table" or Display.ShowOn(trigger) ~= "showOnActive" or Display.IsSingle(trigger, data)
    or Display.UsesGate(data) or Display.UsesApproximate(trigger)
    or not (Display.UsesSpellIDs(trigger) or Display.UsesRankSpellIDs(trigger)) then return end
  local filters = CopyTable(Display.RawCandidateFilters(data))
  filters.includeSpellIDs = nil
  local op, x = Display.RemainingWindow(trigger)
  -- Which units a display watches is part of the key: displays with
  -- different unit filters (names, roles, class, self, dead, offline, range,
  -- hostility) must not merge, or the first one's units would govern both.
  -- An enabled filter with nothing selected matches no unit: distinct from off.
  local units = Serialize({
    names = trigger.useUnitNames and (trigger.unitNames or {}) or false,
    roles = trigger.useUnitRoles and (trigger.unitRoles or {}) or false,
    class = trigger.useUnitClass and (trigger.unitClass or {}) or false,
    self = trigger.ignoreSelf or false, dead = trigger.ignoreDead or false,
    offline = trigger.ignoreDisconnected or false, range = trigger.ignoreInvisible or false,
    hostility = Display.UsesHostility(trigger) and (trigger.hostility or "hostile") or false,
  })
  return table.concat({tostring(trigger.unit), tostring((Display.SpecificUnit(trigger))), tostring((Display.IncludesPets(trigger))),
    units, Display.FilterString(trigger), Serialize(filters), tostring(op), tostring(x), AppearanceKey(data)}, "|")
end

local merged = setmetatable({}, {__mode = "k"})

local function MergedFor(data)
  local entry = data and Private.regions[data.id]
  local info = entry and entry.region and merged[entry.region]
  -- A display that left its merging group draws with its own filters again.
  if info and not Display.MergesAcross(Display.FlowGroup(data)) then
    merged[entry.region] = nil
    return
  end
  return info
end

function Display.MergedCandidateFilters(data)
  local info = MergedFor(data)
  return info and info.filters
end

function Display.MergedMaxAuras(data)
  local info = MergedFor(data)
  return info and info.max
end

local function PushFilters(region, data, filters, max)
  local native = region.blizzardAuraDisplay
  local ok = true
  for _, instance in ipairs(native and native.instances or {}) do
    ok = pcall(instance.container.SetAuraGroupCandidateFilters, instance.container, "Auras", filters) and ok
    ok = pcall(instance.container.SetAuraGroupMaxFrameCount, instance.container, "Auras", max) and ok
    if instance.flowShadowActive and instance.flowShadow then
      ok = pcall(instance.flowShadow.SetAuraGroupCandidateFilters, instance.flowShadow, SHADOW_GROUP, filters) and ok
      ok = pcall(instance.flowShadow.SetAuraGroupMaxFrameCount, instance.flowShadow, SHADOW_GROUP, max) and ok
    end
  end
  return ok
end

function Display.RefreshFlowMerge(group)
  local sets, order = {}, {}
  if Display.MergesAcross(group) then
    for _, childID in ipairs(group.controlledChildren or {}) do
      local entry = Private.regions[childID]
      local region = entry and entry.region
      local native = region and region.blizzardAuraDisplay
      if native and native.active and native.data and region:IsShown() then
        local key = Display.MergeKey(native.data)
        if key then
          if not sets[key] then sets[key] = {}; order[#order + 1] = key end
          table.insert(sets[key], region)
        end
      end
    end
  end
  local wanted = {}
  local limit = group.blizzardFlowUseLimit and math.max(1, math.floor(tonumber(group.blizzardFlowLimit) or 5)) or nil
  for _, key in ipairs(order) do
    local set = sets[key]
    if #set > 1 then
      local host = set[1]
      local filters = CopyTable(Display.RawCandidateFilters(host.blizzardAuraDisplay.data))
      local union, total = {}, 0
      for _, region in ipairs(set) do
        local data = region.blizzardAuraDisplay.data
        for id in pairs(Display.RawCandidateFilters(data).includeSpellIDs or {}) do union[id] = true end
        total = total + Display.RawMaxAuras(data)
      end
      filters.includeSpellIDs = union
      wanted[host] = {filters = filters, max = limit or math.min(total, 40)}
      for index = 2, #set do
        local own = CopyTable(Display.RawCandidateFilters(set[index].blizzardAuraDisplay.data))
        own.includeSpellIDs = {}
        wanted[set[index]] = {filters = own, max = 1}
      end
    end
  end
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    local native = region and region.blizzardAuraDisplay
    if native and native.data then
      local info, old = wanted[region], merged[region]
      local signature = info and Serialize(info) or nil
      if signature ~= (old and old.signature) then
        if info then
          info.signature = signature
          if PushFilters(region, native.data, info.filters, info.max) then merged[region] = info end
        elseif PushFilters(region, native.data, Display.RawCandidateFilters(native.data), Display.RawMaxAuras(native.data)) then
          merged[region] = nil
        end
      end
    end
  end
end

local function HideShadow(holder, key)
  local container = holder and holder[key]
  if container and not Busy(container) then
    holder[key .. "Active"] = false
    container:SetEnabled(false)
    container:Hide()
  end
end

-- Called by Apply after the display's parts exist: builds or retires the
-- half-size shadows of a centred Modern Aura Group.
function Display.EnsureFlowShadows(region, data)
  local native = region.blizzardAuraDisplay
  local flow = native and native.flow
  local sh = flow and flow.growth.shadow
  local missing = native and native.instances[1] and native.instances[1].single and native.instances[1].single.missing
  for _, instance in ipairs(native and native.instances or {}) do
    if not sh then HideShadow(instance, "flowShadow") end
  end
  if not sh then
    HideShadow(missing, "flowShadow")
    if flow then SetShown(flow.shadowStart, false) end
    return
  end
  if not flow.shadowStart then
    flow.shadowStart = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
    flow.shadowStart:EnableMouse(false)
    flow.shadowStart:SetSize(1, 1)
  end
  SetShown(flow.shadowStart, true)
  local trigger = Display.GetTrigger(data)
  local _, spacing = Display.FlowGrowth(data)
  local width, height = Display.Dimensions(data)
  local along = sh.sign[1] ~= 0
  -- Whole units only: a half-unit shadow puts every icon after it between
  -- two pixels, where 1 px borders draw 2 px wide. The row may sit up to half
  -- a unit per display off centre instead, which nothing can see.
  flow.half = Display.FlowHalf(region, (along and width or height) + spacing)
  local size = flow.half + 1
  local layout = along and {elementWidth = size, elementHeight = height, elementSpacing = -1}
    or {elementWidth = width, elementHeight = size, elementSpacing = -1}
  local filter, candidates = Display.FilterString(trigger), Display.CandidateFilters(data)
  local showOn = Display.ShowOn(trigger)
  flow.shadowKind, flow.shadowList = "fixed", nil
  -- Gated lists (Total Duration, Stack Count) keep a fixed spot.
  if showOn == "showOnActive" and not Display.UsesGate(data) then
    flow.shadowList = {}
    for _, instance in ipairs(native.instances) do
      instance.flowShadow = MeasureContainer(instance.flowShadow, region, data, sh, layout, Display.MaxAuras(data), filter, candidates)
      instance.flowShadowActive = instance.flowShadow ~= nil
      if instance.flowShadow then flow.shadowList[#flow.shadowList + 1] = instance.flowShadow end
    end
    if #flow.shadowList > 0 then flow.shadowKind = "list" end
  else
    for _, instance in ipairs(native.instances) do HideShadow(instance, "flowShadow") end
  end
  if showOn == "showOnMissing" and missing and missing.active and not missing.slot then
    local single = {elementWidth = along and size or width, elementHeight = along and height or size}
    missing.flowShadow = MeasureContainer(missing.flowShadow, region, data, sh, single, 1, filter, candidates)
    missing.flowShadowActive = missing.flowShadow ~= nil
      and AnchorBackwards(missing.flowShadow, sh, flow.shadowStart, size, region)
    missing.flowShadowBoundUnit = nil
    if missing.flowShadowActive then flow.shadowKind = "missing" end
  else
    HideShadow(missing, "flowShadow")
  end
end

-- Remaining Time: a hidden countdown text on its own aura slot is one display
-- (plus spacing) long inside the time window and empty outside it, or when
-- the aura is gone, so the next display follows the window.
local FLOW_REMAIN, FLOW_REMAIN_SHADOW = "FAFlowRemain", "FAFlowRemainShadow"
local measureCurve

local function MeasureText(instance, key, data, trigger, g, startFrame, length, lower, upper, property)
  local container, store = instance.container, instance.flowRemainSlots
  local entry = store[key]
  if not entry then
    entry = {}
    local ok = pcall(container.AddAuraSlot, container, key, Display.FilterString(trigger), {
      candidateFilters = Display.CandidateFilters(data),
      initializeFrame = function(button)
        entry.button = button
        button:EnableMouse(false)
        button:SetAlpha(0)
        button:SetSize(1, 1)
      end,
    })
    if not ok or not entry.button then return end
    -- The text sits in a frame scaled so that one of its units is one screen
    -- pixel: the fill is then a whole number of pixels, and the one unit the
    -- text adds around it is exactly one pixel, so the next display's start
    -- needs no rounding (see SetFlowEnd).
    entry.holder = CreateFrame("Frame", nil, entry.button, "DisableUntrustedLayoutScriptsTemplate")
    entry.holder:EnableMouse(false)
    entry.holder:SetSize(1, 1)
    -- The fill is a plain texture that the text colour cannot hide; the holder
    -- is invisible (its size still measures), as the slot button is.
    entry.holder:SetAlpha(0)
    entry.text = entry.holder:CreateFontString(nil, "ARTWORK")
    -- A plain copy of the text, to measure how wide the fill really renders.
    entry.probe = entry.holder:CreateFontString(nil, "ARTWORK")
    entry.probe:SetAlpha(0)
    store[key] = entry
  end
  container:SetAuraSlotEnabled(key, false)
  container:SetAuraSlotFilterString(key, Display.FilterString(trigger))
  container:SetAuraSlotCandidateFilters(key, Display.CandidateFilters(data))
  container:SetAuraSlotSortMethod(key, Display.SortOrder(data, trigger))
  entry.button:ClearAllPoints()
  Place(entry.button, g.start, startFrame, g.start)
  local holder, text = entry.holder, entry.text
  -- One holder unit is one screen pixel where the scale is known; the fill is
  -- the step in whole pixels. Unknown scale: units, as the row's own frames.
  local px = PixelsPerUnit(entry.button)
  holder:SetScale(px and 1 / px or 1)
  holder:ClearAllPoints()
  if not Place(holder, g.start, startFrame, g.start) then return end
  text:SetFont(STANDARD_TEXT_FONT, 12, "")
  text:SetWordWrap(false)
  text:SetJustifyH(g.sign[1] < 0 and "RIGHT" or "LEFT")
  -- Invisible: the fill texture ignores the text colour (seen as a dark line).
  text:SetAlpha(0)
  text:ClearAllPoints()
  -- Anchors see the text as exactly its fill, and as nothing when empty
  -- (GetRight reports a one-pixel minimum that anchors do not use), so the
  -- fill is the step in whole pixels and the text starts at the display.
  text:SetPoint(g.start, holder, g.start)
  local along = g.sign[1] ~= 0
  -- A texture in a text does not render at its stated size (a 44 pixel fill
  -- measured 43.27 on a scaled group), and an empty text is one pixel long.
  -- So the fill is chosen by measuring: the size whose rendered length is
  -- closest to the step plus one pixel; the next display then starts one
  -- pixel back from the text's end, filled or empty (SetFlowEnd), and any
  -- remainder of the match is folded into that offset.
  local target = math.max(1, math.floor(length * (px or 1) + 0.5)) + 1
  local probe = entry.probe
  probe:SetFont(STANDARD_TEXT_FONT, 12, "")
  probe:SetWordWrap(false)
  probe:ClearAllPoints()
  probe:SetPoint(g.start, holder, g.start)
  local function Markup(n) return ("|TInterface\\Buttons\\WHITE8X8:%d:%d|t"):format(along and 1 or n, along and n or 1) end
  local best, bestLength
  for n = math.max(1, target - 3), target + 3 do
    probe:SetText(Markup(n))
    local rendered = along and probe:GetStringWidth() or probe:GetStringHeight()
    if type(rendered) == "number" and not issecretvalue(rendered) and rendered > 0
      and (not best or math.abs(rendered - target) < math.abs(bestLength - target)) then
      best, bestLength = n, rendered
    end
  end
  probe:SetText("")
  if not best then best, bestLength = target, target end
  -- Pixels back from the text's end to the next display: one for the empty
  -- text, plus whatever the fill renders over the target.
  entry.back = 1 + (bestLength - target)
  local fill = Markup(best)
  local formatter = Display.GateFormatter(lower, upper, fill)
  if not formatter then return end
  if not measureCurve then
    measureCurve = C_CurveUtil.CreateColorCurve()
    measureCurve:SetType(Enum.LuaCurveType.Step)
    measureCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
  end
  pcall(entry.button.ClearDurationText, entry.button)
  pcall(entry.button.ClearApplicationCount, entry.button)
  if property == "stacks" then
    -- Stack Count: Blizzard writes the count through the formatter, also 0.
    text:SetTextColor(0, 0, 0, 0)
    if not pcall(entry.button.SetApplicationCount, entry.button, text, {formatter = formatter}) then return end
  else
    property = Enum.DurationTextBindingProperty[property or "RemainingDuration"]
    if not pcall(entry.button.SetDurationText, entry.button, text, {
      textFormat = {formatString = "{}", components = {{property = property, formatter = formatter}}},
      textColor = {curve = measureCurve, property = property},
    }) then return end
  end
  text:Show()
  container:SetAuraSlotEnabled(key, true)
  return entry
end

local function DisableMeasure(instance, key)
  local entry = instance and instance.flowRemainSlots and instance.flowRemainSlots[key]
  if entry then pcall(instance.container.SetAuraSlotEnabled, instance.container, key, false) end
end

-- Called by Apply after the flow shadows, before the display's end is recorded.
function Display.EnsureFlowRemaining(region, data)
  local native = region.blizzardAuraDisplay
  local flow = native and native.flow
  local instance = native and native.instances[1]
  local trigger = Display.GetTrigger(data)
  local lower, upper
  local property
  if flow and instance and trigger and not Display.FlowFrameMode(data) and not Display.FlowGrid(Display.FlowGroup(data)) then
    lower, upper = Display.RemainingRange(trigger)
    -- Gated displays take space only while their gate is open.
    if not lower then
      local kind, n = Display.StackGate(data, trigger)
      if kind == "exactly" then lower, upper, property = n, n, "stacks"
      elseif kind == "atLeast" then lower, property = n, "stacks"
      elseif kind == "atMost" then lower, upper, property = 0, n, "stacks" end
    end
    if not lower then
      lower, upper = Display.DurationGate(data, trigger)
      if lower then property = "TotalDuration" end
    end
  end
  if flow then flow.remain, flow.shadowRemain = nil, nil end
  if not lower then
    DisableMeasure(instance, FLOW_REMAIN)
    DisableMeasure(instance, FLOW_REMAIN_SHADOW)
    return
  end
  instance.flowRemainSlots = instance.flowRemainSlots or {}
  local _, spacing = Display.FlowGrowth(data)
  local width, height = Display.Dimensions(data)
  local g = flow.growth
  local size = ((g.sign[1] ~= 0) and width or height) + spacing
  local main = MeasureText(instance, FLOW_REMAIN, data, trigger, g, flow.start, size, lower, upper, property)
  flow.remain = main and main.text
  flow.remainBack = main and main.back
  local shadow = main and g.shadow and flow.shadowStart
    and MeasureText(instance, FLOW_REMAIN_SHADOW, data, trigger, g.shadow, flow.shadowStart, Display.FlowHalf(region, size), lower, upper, property)
  if shadow then
    HideShadow(instance, "flowShadow")
    flow.shadowKind, flow.shadowList, flow.shadowRemain = "remain", nil, shadow.text
    flow.shadowRemainBack = shadow.back
  else
    DisableMeasure(instance, FLOW_REMAIN_SHADOW)
  end
end

-- Keeps a display's list shadow on the same unit as its aura area.
-- force: see Display.RefreshSingle.
function Display.RefreshFlowShadow(instance, unit, shown, force)
  local container = instance.flowShadowActive and instance.flowShadow
  if not container or Busy(container) then return end
  if unit and instance.flowShadowUnit ~= unit then
    container:SetEnabled(false)
    container:SetUnit(unit)
    instance.flowShadowUnit = unit
  end
  -- Enabled and refreshed only when its state changes (faEnabled, TrackEnabled).
  if container:IsShown() ~= shown then container:SetShown(shown) end
  if container.faEnabled ~= shown or (shown and force) then
    container:SetEnabled(shown)
    if shown then container:UpdateAllAuras() end
  end
end

-- Chains one display's shadows from its shadow start; returns where the next
-- display's shadows start.
local function ChainShadows(flow)
  local sh = flow.growth.shadow
  if flow.shadowKind == "list" then
    for index, container in ipairs(flow.shadowList) do
      if not InCombatLockdown() then container:ClearAllPoints() end
      local ok
      if index == 1 then
        ok = Place(container, sh.start, flow.shadowStart, sh.start)
      else
        ok = Place(container, sh.start, flow.shadowList[index - 1], sh.listEnd, sh.pixel[1], sh.pixel[2])
      end
      if not ok and not InCombatLockdown() then
        container:ClearAllPoints()
        container:SetPoint(sh.start, flow.region, sh.start)
      end
    end
    return {flow.shadowList[#flow.shadowList], sh.listEnd, sh.pixel[1], sh.pixel[2]}
  elseif flow.shadowKind == "remain" then
    -- The shadow measure's own pixels back (see SetFlowEnd).
    local px = PixelsPerUnit(flow.shadowStart) or 1
    local back = (flow.shadowRemainBack or 1) / px
    return {flow.shadowRemain, sh.far, -sh.sign[1] * back, -sh.sign[2] * back}
  elseif flow.shadowKind == "missing" then
    local single = flow.region.blizzardAuraDisplay.instances[1].single.missing
    return {single.flowShadow, sh.start, 0, 0}
  end
  return {flow.shadowStart, sh.start, sh.sign[1] * flow.half, sh.sign[2] * flow.half}
end

-- Grouped by frame: for every unit, its aura area in the first display sits
-- on the unit's frame, and each later display's area follows the previous one.
-- Called after any display in the group rebinds its units, also in combat,
-- like the aura list's own unit anchoring.
-- The group's own frame: on the screen, the row starts (or centres) at its
-- anchor point, like a Dynamic Group's children. nil before it exists.
-- The editor's nameplate stand-in (the Personal Resource Display frame),
-- shown while the options are open, as for a Dynamic Group grouped by
-- nameplate. Released when the group no longer uses it.
local function NameplatePreview(group)
  if not (Private.ensurePRDFrame and WeakAuras.IsOptionsOpen()) then return end
  Private.ensurePRDFrame()
  local frame = Private.personalRessourceDisplayFrame
  if frame and frame.anchorFrame then frame:anchorFrame(group.id, "NAMEPLATE") end
  return frame
end

-- Grouped by frame, the editor's box for a display (the frame the mover and
-- selection outline use) is moved onto its preview icons, as a Dynamic Group
-- moves its children onto the nameplate stand-in. The display's own anchor is
-- kept and put back when the preview ends or the group stops using frames.
local function MovePreviewRegion(region, button)
  if not (region.SetAnchor and region.SetOffset) then return end
  -- Anchored anywhere else, the anchor is the display's own (set again by
  -- the editor after a change), so it is the one to keep.
  -- Only an anchor that is not one of the preview samples is the display's own.
  if region.relativeTo ~= button and not (type(region.relativeTo) == "table" and region.relativeTo.bindings) then
    region.flowPreviewSaved = {region.anchorPoint, region.relativeTo, region.relativePoint,
      region.GetXOffset and region:GetXOffset() or 0, region.GetYOffset and region:GetYOffset() or 0}
  end
  region:SetAnchor("TOPLEFT", button, "TOPLEFT")
  region:SetOffset(0, 0)
end

function Display.RestorePreviewRegion(region)
  local saved = region and region.flowPreviewSaved
  if not saved then return end
  region.flowPreviewSaved = nil
  if saved[1] and saved[2] then region:SetAnchor(saved[1], saved[2], saved[3]) end
  region:SetOffset(saved[4], saved[5])
end

-- The group's own editor box: its frame is placed by the addon on the frame
-- the preview uses (Private.AnchorFrame, FlowPreviewFrame), and its bounds
-- are set to cover the first unit's preview row, which starts at the group's
-- anchor. Put back when the group no longer previews on a frame.
local function SetGroupPreviewBounds(group, g, length, cross, ox, oy)
  local entry = Private.regions[group.id]
  local region = entry and entry.region
  if not region then return end
  local blx, bly, trx, try
  if g.sign[1] > 0 then blx, trx, try, bly = 0, length, 0, -cross
  elseif g.sign[1] < 0 then blx, trx, try, bly = -length, 0, 0, -cross
  elseif g.sign[2] < 0 then blx, trx, try, bly = 0, cross, 0, -length
  else blx, trx, bly, try = 0, cross, 0, length end
  blx, trx, bly, try = blx + ox, trx + ox, bly + oy, try + oy
  if region.GetBoundingRect ~= region.flowPreviewBoundsFn then
    region.flowPreviewBoundsSaved = region.GetBoundingRect
  end
  region.flowPreviewBoundsFn = function(self)
    self.blx, self.bly, self.trx, self.try = blx, bly, trx, try
    return blx, bly, trx, try
  end
  region.GetBoundingRect = region.flowPreviewBoundsFn
  region:GetBoundingRect()
end

function Display.RestoreGroupPreview(group)
  local entry = group and Private.regions[group.id]
  local region = entry and entry.region
  if not region then return end
  if region.flowPreviewBoundsSaved then
    if region.GetBoundingRect == region.flowPreviewBoundsFn then region.GetBoundingRect = region.flowPreviewBoundsSaved end
    region.flowPreviewBoundsSaved, region.flowPreviewBoundsFn = nil, nil
    region.boundingRect = false
    region:GetBoundingRect()
  end
end

function Display.ReleaseNameplatePreview(group)
  local frame = Private.personalRessourceDisplayFrame
  if group and frame and frame.anchorFrame then frame:anchorFrame(group.id, nil) end
end

-- Grouped by frame, the group's Position and Size settings (To Frame's point
-- and offsets) place the first aura on each frame.
local function FramePosition(group)
  return group.anchorPoint or "CENTER", tonumber(group.xOffset) or 0, tonumber(group.yOffset) or 0
end

-- Grouped by frame, the group's Anchor point places the row on the To
-- Frame's point across its growth direction (icon size, known here): top,
-- middle or bottom of a horizontal row; left, middle or right of a vertical
-- one. Along the growth, Centered growth centres it; the others start there.
local function CrossOffset(group, g, cross)
  local selfPoint = group.selfPoint or "CENTER"
  if g.sign[1] ~= 0 then
    if selfPoint:find("TOP") then return 0, 0 end
    if selfPoint:find("BOTTOM") then return 0, cross end
    return 0, cross / 2
  end
  if selfPoint:find("LEFT") then return 0, 0 end
  if selfPoint:find("RIGHT") then return -cross, 0 end
  return -cross / 2, 0
end

local function AlignedPoints(group, g)
  local selfPoint = group.selfPoint or "CENTER"
  local horizontal = g.sign[1] ~= 0
  local cross
  if horizontal then
    cross = selfPoint:find("TOP") and "TOP" or selfPoint:find("BOTTOM") and "BOTTOM" or ""
  else
    cross = selfPoint:find("LEFT") and "LEFT" or selfPoint:find("RIGHT") and "RIGHT" or ""
  end
  local function Align(point)
    if horizontal then return cross .. (point:find("LEFT") and "LEFT" or "RIGHT") end
    return (point:find("TOP") and "TOP" or "BOTTOM") .. cross
  end
  return Align(g.start), Align(g.listEnd), Align(g.far)
end

-- ForeverAuras: the plate's visible bar (WeakAuras.GetUnitNameplate: the
-- nameplate addon's health bar, or the client's unit frame inside the
-- plate), as a Dynamic Group grouped by nameplate uses. The NamePlate frame
-- itself is wider than the bar drawn in it, so a row anchored to its edge
-- sat well clear of the plate.
-- The client's own plates on this client keep their bar in an unnamed frame
-- (no UnitFrame field for the lookup to find), so the first status bar
-- inside the plate is taken as the bar; the plate itself when there is none.
local barOf = setmetatable({}, {__mode = "k"})
local function FirstStatusBar(frame, depth)
  for _, child in ipairs({frame:GetChildren()}) do
    if child:GetObjectType() == "StatusBar" then return child end
    if depth > 1 then
      local found = FirstStatusBar(child, depth - 1)
      if found then return found end
    end
  end
end
local function NameplateAnchor(unit)
  local frame = WeakAuras.GetUnitNameplate and WeakAuras.GetUnitNameplate(unit)
  if frame and frame.IsForbidden and not frame:IsForbidden() then return frame end
  local plate = C_NamePlate.GetNamePlateForUnit(unit)
  if not plate or plate:IsForbidden() then return plate end
  local unitFrame = plate.UnitFrame
  local bar = unitFrame and (unitFrame.healthBar or (unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar))
  if not bar then
    bar = barOf[plate]
    if bar == nil then
      bar = FirstStatusBar(plate, 3) or false
      barOf[plate] = bar
    end
  end
  if bar and bar.IsForbidden and not bar:IsForbidden() then return bar end
  return plate
end
Display.NameplateAnchor = NameplateAnchor

local function UnitAnchor(mode, unit)
  local frame = mode == "UNITFRAME" and WeakAuras.GetUnitFrame(unit) or (mode == "NAMEPLATE" and NameplateAnchor(unit))
  if frame and not frame:IsForbidden() then return frame end
end

-- While an event refreshes many displays, each group is re-anchored once at
-- the end (EndFlowBatch) instead of once per display.
local batch, gridBatch
function Display.BeginFlowBatch() batch, gridBatch = batch or {}, gridBatch or {} end
function Display.EndFlowBatch()
  local groups, grids = batch, gridBatch
  batch, gridBatch = nil, nil
  for group in pairs(groups or {}) do Display.RelinkFlowUnits(group) end
  for group in pairs(grids or {}) do Display.RefreshGrid(group) end
end

-- During a batch, each grid is refreshed once at its end.
function Display.DeferGridRefresh(group)
  if not gridBatch then return false end
  gridBatch[group] = true
  return true
end

function Display.FlowUnitStart(group)
  return (AlignedPoints(group, GROWTH[GrowthKey(group)]))
end

function Display.RelinkFlowUnits(group)
  local mode = group and group.blizzardFlowFrames
  if mode ~= "UNITFRAME" and mode ~= "NAMEPLATE" then return end
  if batch then batch[group] = true; return end
  local g = GROWTH[GrowthKey(group)]
  -- The group's own Position and Size settings, relative to each frame.
  local point, frameX, frameY = FramePosition(group)
  local start, listEnd, far = AlignedPoints(group, g)
  local spacing = tonumber(group.blizzardFlowSpacing) or 2
  local halfSpacing = math.floor(spacing / 2)
  -- Centred: per unit, the shadows run backwards from the frame point first.
  local lastShadow = {}
  local sh = g.shadow
  local shStart, shEnd
  if sh then shStart, shEnd = AlignedPoints(group, sh) end
  if sh then
    for _, childID in ipairs(group.controlledChildren or {}) do
      local entry = Private.regions[childID]
      local native = entry and entry.region and entry.region.blizzardAuraDisplay
      if native and native.active then
        for _, instance in ipairs(native.instances) do
          local unit = instance.visible and instance.boundUnit
          local shadow = unit and instance.flowShadowActive and instance.flowShadow
          if shadow and not Busy(shadow) then
            shadow:ClearAllPoints()
            local linked = lastShadow[unit] and Place(shadow, shStart, lastShadow[unit], shEnd, sh.pixel[1], sh.pixel[2])
            local frame = not linked and UnitAnchor(mode, unit)
            if frame then shadow:SetPoint(shStart, frame, point, frameX, frameY) end
            lastShadow[unit] = shadow
          end
        end
      end
    end
  end
  local last = {}
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local native = entry and entry.region and entry.region.blizzardAuraDisplay
    if native and native.active then
      local missingOnly = Display.ShowOn(Display.GetTrigger(native.data) or {}) == "showOnMissing"
      local width, height = Display.Dimensions(native.data)
      local along = g.sign[1] ~= 0
      local spacing = Display.FlowSpacing(group, entry.region, along and width or height)
      halfSpacing = Display.FlowHalf(entry.region, spacing)
      -- The display's own X/Y Offset moves its part of each unit's row only
      -- (OwnOffset): the next display's anchor takes it back off.
      local ox, oy = OwnOffset(native.data)
      for _, instance in ipairs(native.instances) do
        local unit = instance.visible and instance.boundUnit
        if unit and not Busy(instance.container) then
          local container = instance.container
          container:ClearAllPoints()
          local previous = last[unit]
          local linked = previous and Place(container, start, previous[1], previous[2], previous[3] + ox, previous[4] + oy)
          if not linked and lastShadow[unit] then
            -- Centred: start where the shadows end, half a spacing on.
            linked = Place(container, start, lastShadow[unit], shEnd,
              sh.pixel[1] + g.sign[1] * halfSpacing + ox, sh.pixel[2] + g.sign[2] * halfSpacing + oy)
          end
          if not linked then
            local frame = UnitAnchor(mode, unit)
            if frame then
              -- Centred without a list shadow on this unit (Show On: Missing,
              -- or a gated list): nothing ran backwards from the frame point,
              -- so the row would start there and sit half a display to the
              -- side. Start half a step back instead: half the display's
              -- step less half a spacing, each a whole number of pixels, the
              -- sum the options preview uses (ArrangeFlowPreview, Offset), so
              -- the live row lands on the preview's pixel.
              local back = 0
              if sh then
                back = Display.FlowHalf(entry.region, (along and width or height) + spacing)
                  - Display.FlowHalf(entry.region, Display.FlowSpacing(group, entry.region, 0))
              end
              container:ClearAllPoints()
              container:SetPoint(start, frame, point, frameX - g.sign[1] * back + ox, frameY - g.sign[2] * back + oy)
            end
          end
          last[unit] = {container, listEnd, g.pixel[1] - ox, g.pixel[2] - oy}
          local missing = instance.single and instance.single.missing
          local slot = missing and missing.active and missing.slot
          if slot then
            local size = (along and width or height) + spacing
            last[unit] = {slot, listEnd, g.sign[1] * spacing - ox, g.sign[2] * spacing - oy}
            local presence = missingOnly and missing.presenceActive and missing.presence
            if presence then
              presence:ClearAllPoints()
              if Place(presence, far, slot, start, g.sign[1] * (size + 1), g.sign[2] * (size + 1)) then
                last[unit] = {presence, start, -ox, -oy}
              end
            end
          end
        end
      end
    end
  end
end

-- Options preview: the samples are plain frames of known size, so they are
-- simply lined up in the group's order, on a nameplate or unit frame when the
-- group is grouped by frame (the first display's preview unit), else starting
-- at the first display.
-- The units a display previews on, grouped by unit frame: those of its unit
-- setting that exist and have a frame (Smart Group: you and your party),
-- like a Dynamic Group's preview clones. {false} otherwise: one row.
local MAX_PREVIEW_UNITS = 5
function Display.FlowPreviewUnits(data)
  if Display.FlowFrameMode(data) ~= "UNITFRAME" then return {false} end
  local units = {}
  for _, unit in ipairs(Display.UnitTokens(Display.GetTrigger(data) or {})) do
    if UnitExists(unit) and WeakAuras.GetUnitFrame(unit) then
      units[#units + 1] = unit
      if #units >= MAX_PREVIEW_UNITS then break end
    end
  end
  if #units == 0 then units[1] = "player" end
  return units
end

-- The frame a unit's preview row sits on: the editor's nameplate stand-in, or
-- the unit's frame.
local function PreviewFrame(group, unit)
  local frame
  if group.blizzardFlowFrames == "NAMEPLATE" then
    frame = NameplatePreview(group)
  elseif unit then
    frame = WeakAuras.GetUnitFrame(unit)
  end
  if frame and not frame:IsForbidden() then return frame end
end

-- The frame the group itself is anchored to in the editor, so its box and
-- Position and Size settings work on the frame, as for a Dynamic Group grouped
-- by frame. nil when the group is not grouped by frame or the options are closed.
function Display.FlowPreviewFrame(group)
  local mode = group and group.blizzardFlow and group.blizzardFlowFrames
  if (mode ~= "UNITFRAME" and mode ~= "NAMEPLATE") or not WeakAuras.IsOptionsOpen() then return end
  local unit
  for _, childID in ipairs(group.controlledChildren or {}) do
    local child = WeakAuras.GetData(childID)
    if child and Display.Enabled(child) then
      unit = Display.FlowPreviewUnits(child)[1]
      break
    end
  end
  return PreviewFrame(group, unit or "player")
end

function Display.FlowNormalProblem(data)
  local group = Display.FlowGroup(data)
  if not group or Display.Enabled(data) or Display.FlowNormal(data) then return end
  for _, entry in ipairs(data.triggers or {}) do
    if type(entry) == "table" and type(entry.trigger) == "table" and entry.trigger.type == "secretAura" then return end
  end
  if data.regionType == "group" or data.regionType == "dynamicgroup" then
    return L["Groups inside a Modern Aura Group keep their own position."]
  end
  if group.blizzardFlowFrames ~= nil or Display.FlowGrid(group) then
    return L["With Grid or Group by Frame, only Aura (Modern) displays line up. This display keeps its own position."]
  end
  return L["Anchored to a unit frame, nameplate, the mouse or a custom anchor, this display keeps its own position."]
end

local function NormalSize(region, data)
  local width, height = region.width, region.height
  if type(width) ~= "number" or issecretvalue(width) then width = tonumber(data.width) or 1 end
  if type(height) ~= "number" or issecretvalue(height) then height = tonumber(data.height) or 1 end
  return width * math.abs(region.scalex or 1), height * math.abs(region.scaley or 1)
end

-- Options preview: the samples are plain frames of known size, so they are
-- lined up in the group's order: per unit on its frame (or on the nameplate
-- stand-in) when grouped by frame, else starting at the first display.
local PlaceNormalRegion
local previewOrigins = {}
local ArrangeFlowPreviewNow
function Display.ArrangeFlowPreview(group)
  if not group then return end
  -- During a load scan or the editor's batched pick of a large group the
  -- arrangement waits for Display.EndFlowLoad, like the rechain: every
  -- display's refresh arranged the whole pack's samples again, which grew
  -- with the square of the pack's size over the pick (issue #136).
  if loadScan > 0 then queued[group] = true; return end
  -- Timed here, so every caller is counted (/fa pprint).
  Private.StartProfileSystem("aura (modern) - group layout: preview")
  ArrangeFlowPreviewNow(group)
  Private.StopProfileSystem("aura (modern) - group layout: preview")
end
function ArrangeFlowPreviewNow(group)
  if Display.FlowGrid(group) then
    Display.ReleaseNameplatePreview(group)
    Display.ArrangeGridPreview(group)
    return
  end
  local mode = group.blizzardFlowFrames
  local framed = mode == "UNITFRAME" or mode == "NAMEPLATE"
  if mode ~= "NAMEPLATE" then Display.ReleaseNameplatePreview(group) end
  local g = GROWTH[GrowthKey(group)]
  local spacing = tonumber(group.blizzardFlowSpacing) or 2
  local along = g.sign[1] ~= 0
  -- The gap after a display of a size, in whole pixels as the live row has it
  -- (Display.FlowSpacing), so the preview is spaced like the live row.
  local groupEntry = Private.regions[group.id]
  local function Spaced(size) return Display.FlowSpacing(group, groupEntry and groupEntry.region, size) end
  local point, frameX, frameY = FramePosition(group)
  -- ForeverAuras: group-owned row (FlowGroupOwned): the samples and ordinary
  -- displays are lined up from the group's anchor in the group's order, each
  -- member's own offset on that member only, as the live chain places them.
  local owned = not framed and Display.FlowGroupOwned(group)
  local originFrame, originPoint
  if owned then originFrame, originPoint = RowOrigin(group) end
  if owned and not originFrame then owned = false end
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    local normal = region and region.flowNormal
    if normal and normal.active and normal.stand then PlaceNormalRegion(region, normal) end
  end
  local function Key(sample) return framed and mode == "UNITFRAME" and sample.previewUnit or "" end
  -- Each row's length and depth, known here; centred rows start half back.
  local length, cross, firstKey, sampleStep, iconStep, anyStep = {}, {}, nil, nil, nil, nil
  local leadSteps = {}
  -- The last display's spacing is not part of the row; the row's lengths
  -- were summed with the pixel gaps, so the gap taken off is the same kind.
  local lastSpacing = {}
  -- Centred: the live row's shadows run back half a step per display, each
  -- half a whole number of pixels (Display.FlowHalf); summed here the same way.
  local halves = {}
  local groupRegionForHalf = Private.regions[group.id] and Private.regions[group.id].region
  local function Half(step) return Display.FlowHalf(groupRegionForHalf, step) end
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    if region and region.secretAuraSamplesActive and region:IsShown() then
      for _, sample in ipairs(region.secretAuraSamples or {}) do
        local button = sample.button
        if button:IsShown() then
          local key = Key(sample)
          firstKey = firstKey or key
          local width, height = button:GetWidth() or 0, button:GetHeight() or 0
          sampleStep = sampleStep or (along and width or height) + Spaced(along and width or height)
          length[key] = (length[key] or 0) + (along and width or height) + Spaced(along and width or height)
          lastSpacing[key] = Spaced(along and width or height)
          halves[key] = (halves[key] or 0) + Half((along and width or height) + Spaced(along and width or height))
          cross[key] = math.max(cross[key] or 0, along and height or width)
        end
      end
    elseif region and region.flowNormal and region.flowNormal.active and region:IsShown()
      and (not g.shadow or region.flowNormal.stand) then
      local width, height = NormalSize(region, region.flowNormal.data)
      local step = (along and width or height) + Spaced(along and width or height)
      anyStep = anyStep or step
      if region.flowNormal.stand and region.flowNormal.data.regionType == "icon" then iconStep = iconStep or step end
      if not region.flowNormal.stand then leadSteps[#leadSteps + 1] = step end
      length[""] = (length[""] or 0) + (along and width or height) + Spaced(along and width or height)
      lastSpacing[""] = Spaced(along and width or height)
      halves[""] = (halves[""] or 0) + Half(step)
      cross[""] = math.max(cross[""] or 0, along and height or width)
    end
  end
  local limit = not framed and group.blizzardFlowUseLimit and math.max(1, math.floor(tonumber(group.blizzardFlowLimit) or 5))
  local firstStep = sampleStep or iconStep or anyStep
  local rowStart
  -- How far back the row starts: the shadows' halves less half a spacing (the
  -- last display's gap is not part of the row; the live row steps forward by
  -- that half, RechainFlow), no further than half the limit's window, exactly
  -- as the live row is placed (see the shadow chain and CapRowStart), so the
  -- preview sits on the same pixel. Added instead, the preview sat a whole
  -- spacing behind the live row and the row jumped when the options closed.
  local function Offset(key)
    if not g.shadow then return 0, 0 end
    local half = (halves[key] or 0) - Half(Display.FlowSpacing(group, groupRegionForHalf, 0))
    if limit and firstStep then
      local window = (limit * firstStep - (lastSpacing[key] or spacing)) / 2
      local px = PixelsPerUnit(groupRegionForHalf)
      -- Half a pixel comes out a hair under it in floating point (109.49999
      -- for 109.5); the small addition rounds it up like the live cap.
      if px then window = math.floor(window * px + 0.5 + 0.001) / px end
      half = math.min(half, window)
    end
    half = math.max(0, half)
    return -g.sign[1] * half, -g.sign[2] * half
  end
  local previous = {}
  -- The previous sample's own display offset per row key, taken back off (OwnOffset).
  local previousOwn = {}
  -- The first display's own offset per row key, off a frame (see PlaceSamples).
  local firstOwn = {}
  local onFrame = false
  -- A centred row starts half its length back, which can fall between two
  -- pixels; nothing here is secret, so the start is put on a whole pixel.
  local function WholePixel(object, frame, anchor, ox, oy)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    if not factor or factor <= 0 or not object.GetEffectiveScale then return ox, oy end
    local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
    if not ok or type(left) ~= "number" or issecretvalue(left) or issecretvalue(bottom)
      or issecretvalue(width) or issecretvalue(height) then return ox, oy end
    local frameScale, objectScale = frame:GetEffectiveScale(), object:GetEffectiveScale()
    local x = anchor:find("LEFT") and left or anchor:find("RIGHT") and left + width or left + width / 2
    local y = anchor:find("TOP") and bottom + height or anchor:find("BOTTOM") and bottom or bottom + height / 2
    local function Round(position, offset)
      local pixels = (position * frameScale + offset * objectScale) / factor
      return offset + (math.floor(pixels + 0.5) - pixels) * factor / objectScale
    end
    return Round(x, ox), Round(y, oy)
  end
  -- Where the first display's box is, so its sample can start there while the
  -- box itself moves onto the sample.
  local function Origin(region)
    local origin = previewOrigins[group.id] or CreateFrame("Frame", nil, UIParent)
    previewOrigins[group.id] = origin
    origin:ClearAllPoints()
    if region.anchorPoint and region.relativeTo then
      origin:SetPoint(region.anchorPoint, region.relativeTo, region.relativePoint,
        region.GetXOffset and region:GetXOffset() or 0, region.GetYOffset and region:GetYOffset() or 0)
    else
      origin:SetPoint("CENTER", region, "CENTER")
    end
    local width, height = region:GetWidth(), region:GetHeight()
    if issecretvalue(width) or issecretvalue(height) then width, height = region.width or 1, region.height or 1 end
    -- The origin lives under UIParent, so it takes the display's scale (a
    -- scaled group) to be the display's size: sized in UIParent units it was
    -- smaller, and its corners, where the row starts, sat inside the display.
    local scale, parentScale = region:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if type(scale) == "number" and type(parentScale) == "number" and not issecretvalue(scale)
      and not issecretvalue(parentScale) and parentScale > 0 then
      origin:SetScale(scale / parentScale)
    else
      origin:SetScale(1)
    end
    origin:SetSize(width, height)
    return origin
  end
  local function PlaceNormal(region)
    local normal = region.flowNormal
    local inRow = not g.shadow or normal.stand ~= nil
    -- Group-owned row: the display's own offset moves it alone, so it is put
    -- on and remembered for the next member to take back off.
    local ownX, ownY = 0, 0
    if owned then ownX, ownY = OwnOffset(normal.data) end
    if inRow and previous[""] then
      region:SetAnchor(g.start, previous[""], g.far)
      local gap = Spaced(along and previous[""]:GetWidth() or previous[""]:GetHeight())
      -- A preceding Modern sample's own offset is taken back off (OwnOffset),
      -- as the live row does; an ordinary display carries none itself.
      local back = previousOwn[""] or {0, 0}
      region:SetOffset(g.sign[1] * gap + ownX - back[1], g.sign[2] * gap + ownY - back[2])
      previousOwn[""] = owned and {ownX, ownY} or nil
    elseif inRow and owned then
      -- First member: on the group's anchor.
      local ox, oy = Offset("")
      ox, oy = WholePixel(region, originFrame, originPoint, ox, oy)
      region:SetAnchor(g.start, originFrame, originPoint)
      region:SetOffset(ox + ownX, oy + ownY)
      previousOwn[""] = {ownX, ownY}
    elseif inRow and g.shadow then
      local ox, oy = Offset("")
      ox, oy = WholePixel(region, normal.home, g.centerPoint, ox, oy)
      region:SetAnchor(g.start, normal.home, g.centerPoint)
      region:SetOffset(ox, oy)
    else
      region:SetAnchor(g.start, normal.home, g.start)
      region:SetOffset(0, 0)
    end
    if inRow and not previous[""] then
      rowStart = region
      -- An ordinary first display's offset is the row's first offset too
      -- (FlowOwnOffset), so a Modern sample after it adds the difference only.
      firstOwn[""] = {OwnOffset(normal.data)}
    end
    if inRow then previous[""] = region end
  end
  local function PlaceSamples(region)
    if not framed then Display.RestorePreviewRegion(region) end
    local moved = false
    local native = region.blizzardAuraDisplay
    local ownX, ownY = OwnOffset(native and native.data)
    for _, sample in ipairs(region.secretAuraSamples or {}) do
      local button = sample.button
      if button:IsShown() then
        local key = Key(sample)
        local frame = framed and PreviewFrame(group, sample.previewUnit or nil)
        local ox, oy = Offset(key)
        -- Off a frame, offsets are relative to the first display's, as in the
        -- live row (RowOffset): its place already carries its own offset, so
        -- it adds none, and a later display moves by the difference from the
        -- first's offset only, not by its whole offset again. The same
        -- relative offset is what the next display (a Modern sample or an
        -- ordinary display, PlaceNormal) takes back off.
        local addX, addY = ownX, ownY
        if not framed and not owned then
          if not previous[key] then firstOwn[key] = {ownX, ownY} end
          local first = firstOwn[key] or {0, 0}
          addX, addY = ownX - first[1], ownY - first[2]
        end
        ox, oy = ox + addX, oy + addY
        -- The group's anchor point only places the row on a frame; on the
        -- screen the row sits on the first display's box, as the live auras do.
        local start, far = g.start, g.far
        if framed then
          local alignedStart, _, alignedFar = AlignedPoints(group, g)
          start, far = alignedStart, alignedFar
        end
        button:ClearAllPoints()
        if previous[key] then
          local gap = Spaced(along and previous[key]:GetWidth() or previous[key]:GetHeight())
          local back = previousOwn[key] or {0, 0}
          button:SetPoint(start, previous[key], far, g.sign[1] * gap + addX - back[1], g.sign[2] * gap + addY - back[2])
        elseif owned then
          -- Group-owned row: the first sample sits on the group's anchor, a
          -- centred row half its length back from it.
          ox, oy = WholePixel(button, originFrame, originPoint, ox, oy)
          button:SetPoint(g.start, originFrame, originPoint, ox, oy)
        elseif frame then
          button:SetPoint(start, frame, point, frameX + ox, frameY + oy)
        elseif g.shadow then
          -- Group by Frame with no frame found for this sample: the display's
          -- box may still sit on a sample from the last arrangement, and the
          -- origin follows the box, so anchoring the sample to it would be a
          -- cycle ("Cannot anchor to a region dependent on it"). Put the box
          -- back on its own anchor first; it is not moved again below.
          if framed then Display.RestorePreviewRegion(region) end
          local origin = Origin(region)
          ox, oy = WholePixel(button, origin, g.centerPoint, ox, oy)
          button:SetPoint(g.start, origin, g.centerPoint, ox, oy)
        else
          -- As above.
          if framed then Display.RestorePreviewRegion(region) end
          button:SetPoint(g.start, Origin(region), g.start)
        end
        -- The display's own box follows its first icon.
        if (frame or not framed) and not moved then
          MovePreviewRegion(region, button)
          moved = true
        end
        onFrame = onFrame or frame ~= nil and frame ~= false
        if not framed and not previous[key] then rowStart = button end
        previous[key] = button
        previousOwn[key] = {addX, addY}
      end
    end
    if not moved then Display.RestorePreviewRegion(region) end
  end
  -- Ordinary displays that are not copied lead the row (in both row modes:
  -- they cannot hang from a secret-length container), then samples and
  -- stands in the group's order.
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    if region and not region.secretAuraSamplesActive and region.flowNormal and region.flowNormal.active
      and not region.flowNormal.stand and region:IsShown() then
      PlaceNormal(region)
    end
  end
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    if region and region.secretAuraSamplesActive and region:IsShown() then
      PlaceSamples(region)
    elseif region and region.flowNormal and region.flowNormal.active and region.flowNormal.stand and region:IsShown() then
      PlaceNormal(region)
    end
  end
  -- Group-owned row: the cut starts at the group's anchor (a centred row
  -- half the limit's window back, like the live cap), not at the first
  -- sample, whose own offset moves the sample alone (see UpdateFlowClip).
  local clipOrigin
  if owned and rowStart and limit then
    local ox, oy = 0, 0
    if g.shadow and firstStep then
      local window = (limit * firstStep - (lastSpacing[""] or spacing)) / 2
      local px = PixelsPerUnit(groupRegionForHalf)
      if px then window = math.floor(window * px + 0.5 + 0.001) / px end
      ox, oy = -g.sign[1] * window, -g.sign[2] * window
    end
    ox, oy = WholePixel(rowStart, originFrame, originPoint, ox, oy)
    clipOrigin = {originFrame, originPoint, ox, oy}
  end
  if limit and Display.PreviewFlowClip then Display.PreviewFlowClip(group, g, rowStart, leadSteps, firstStep, clipOrigin) end
  if onFrame and firstKey then
    local ox, oy = Offset(firstKey)
    local cx, cy = CrossOffset(group, g, cross[firstKey] or 0)
    ox, oy = ox + cx, oy + cy
    SetGroupPreviewBounds(group, g, math.max(0, (length[firstKey] or 0) - (lastSpacing[firstKey] or spacing)), cross[firstKey] or 0, ox, oy)
  else
    Display.RestoreGroupPreview(group)
  end
end


-- Limit: nothing can count the shown auras in combat, so the row is cut off
-- by a clipping frame between the group and its displays. A centred row is
-- also kept from starting further back than the limit allows: a frame
-- stretched from that cap to the row start collapses onto the cap when the
-- row is longer, so its far edge is whichever is further on.
local clips, caps = {}, {}
local CLIP_MARGIN = 600

-- How to stretch a frame between the cap and the row start so that one of its
-- edges is whichever of the two is further along the row. Learned once from
-- plain frames, out of combat; nil when no way works.
local stretchRules = {}
Display.flowStretchRules = stretchRules
local EDGE_POINT = {LEFT = "TOPLEFT", RIGHT = "TOPRIGHT", TOP = "TOPLEFT", BOTTOM = "BOTTOMLEFT"}
local function StretchRule(vertical)
  if stretchRules[vertical] ~= nil then return stretchRules[vertical] or nil end
  if InCombatLockdown() then return end
  local edges = vertical and {"TOP", "BOTTOM"} or {"LEFT", "RIGHT"}
  local cap = CreateFrame("Frame", nil, UIParent)
  local start = CreateFrame("Frame", nil, UIParent)
  local probe = CreateFrame("Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
  cap:SetSize(1, 1); start:SetSize(1, 1); probe:SetSize(1, 1)
  cap:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local function Read(frame, edge)
    if edge == "LEFT" then return frame:GetLeft() elseif edge == "RIGHT" then return frame:GetRight()
    elseif edge == "TOP" then return frame:GetTop() else return frame:GetBottom() end
  end
  local found = false
  for _, capEdge in ipairs(edges) do
    local startEdge = capEdge == edges[1] and edges[2] or edges[1]
    for _, capFirst in ipairs({true, false}) do
      for _, readEdge in ipairs(edges) do
        local good = true
        -- Further along the row: right, or down.
        for _, distance in ipairs({20, -20}) do
          start:ClearAllPoints()
          start:SetPoint("CENTER", cap, "CENTER", vertical and 0 or distance, vertical and -distance or 0)
          probe:ClearAllPoints()
          local function ToCap() probe:SetPoint(EDGE_POINT[capEdge], cap, "CENTER") end
          local function ToStart() probe:SetPoint(EDGE_POINT[startEdge], start, "CENTER") end
          if capFirst then ToCap(); ToStart() else ToStart(); ToCap() end
          local capX, capY = cap:GetCenter()
          local startX, startY = start:GetCenter()
          local value = Read(probe, readEdge)
          local wanted = vertical and math.min(capY, startY) or math.max(capX, startX)
          if not value or math.abs(value - wanted) > 1 then good = false break end
        end
        if good then
          found = {capPoint = EDGE_POINT[capEdge], startPoint = EDGE_POINT[startEdge], readPoint = EDGE_POINT[readEdge], capFirst = capFirst}
          break
        end
      end
      if found then break end
    end
    if found then break end
  end
  for _, frame in ipairs({cap, start, probe}) do frame:ClearAllPoints(); frame:Hide() end
  stretchRules[vertical] = found
  return found or nil
end

local function ClipWanted(group)
  if not group or not group.blizzardFlowUseLimit then return false end
  if Display.FlowGrid(group) or group.blizzardFlowFrames ~= nil then return false end
  local key = GrowthKey(group)
  if key == "CENTER_HORIZONTAL" or key == "CENTER_VERTICAL" then return StretchRule(key == "CENTER_VERTICAL") ~= nil end
  return true
end

local function GroupRegion(group)
  local entry = Private.regions[group.id]
  return entry and entry.region
end

-- Displays anchored to a chosen frame and parented to it keep that parent.
local function KeepsParent(data)
  return data and data.anchorFrameType == "SELECTFRAME" and data.anchorFrameParent ~= false
end

-- Keeps the display's own strata and level.
local function Reparent(region, parent)
  local strata = region:GetFrameStrata()
  -- Counted for /fa phitch: reparenting a display walks all of its frames.
  if Private.HitchCount then Private.HitchCount("display SetParent") end
  region:SetParent(parent)
  region:SetFrameStrata(strata)
  if Private.ApplyFrameLevel and region.id then Private.ApplyFrameLevel(region) end
end

-- A clip draws its children on its own strata, so it takes the lowest strata
-- its displays are set to; each display keeps its own strata and level.
local strataRank = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}

local function MatchClipStrata(clip, groupRegion)
  local lowest
  for _, child in ipairs({clip:GetChildren()}) do
    local data = child.id and WeakAuras.GetData and WeakAuras.GetData(child.id)
    if data then
      local strata = Private.frame_strata_types and Private.frame_strata_types[data.frameStrata or 1]
      if not strataRank[strata] then strata = groupRegion:GetFrameStrata() end
      if strataRank[strata] and (not lowest or strataRank[strata] < strataRank[lowest]) then lowest = strata end
    end
  end
  lowest = lowest or groupRegion:GetFrameStrata()
  if clip:GetFrameStrata() == lowest then return end
  local children = {clip:GetChildren()}
  local strata = {}
  for index, child in ipairs(children) do strata[index] = child:GetFrameStrata() end
  clip:SetFrameStrata(lowest)
  for index, child in ipairs(children) do
    child:SetFrameStrata(strata[index])
    if Private.ApplyFrameLevel and child.id then Private.ApplyFrameLevel(child) end
  end
end

local function EnsureClip(group)
  local groupRegion = GroupRegion(group)
  if not groupRegion then return end
  local clip = clips[group.id]
  if not clip then
    clip = CreateFrame("Frame", nil, groupRegion)
    clip:EnableMouse(false)
    clip:SetAllPoints(groupRegion)
    clips[group.id] = clip
  end
  if not Busy(clip) then
    if clip:GetParent() ~= groupRegion then clip:SetParent(groupRegion) end
    Display.ClipChildren(clip)
    clip:Show()
  end
  return clip
end

-- The frame a display of the group is parented to, or nil for the group itself.
function Display.FlowClipParent(data)
  local group = Display.FlowGroup(data)
  if not ClipWanted(group) or KeepsParent(data) then return end
  -- With Centered growth only icons and texts join a legacy row; the rest keep
  -- their own place. A group-owned row takes every display (FlowGroupOwned).
  local inRow = Display.Enabled(data) or Display.FlowNormal(data)
    and (Display.FlowGroupOwned(group) or not GROWTH[GrowthKey(group)].shadow or Display.UsesStand ~= nil and Display.UsesStand(data))
  if inRow then return EnsureClip(group) end
end

local function FlowData(flow)
  return flow.normal and flow.normal.data or flow.region.blizzardAuraDisplay and flow.region.blizzardAuraDisplay.data
end

-- One icon and its spacing along the row: from the first Aura (Modern)
-- display, else the first copied icon, else the first display.
local function RowStep(group, g, flows)
  local pick
  for _, flow in ipairs(flows) do
    if not flow.normal then pick = flow break end
  end
  if not pick then
    for _, flow in ipairs(flows) do
      if flow.stand and flow.normal.data.regionType == "icon" then pick = flow break end
    end
  end
  pick = pick or flows[1]
  local width, height
  if pick.normal then
    width, height = NormalSize(pick.region, pick.normal.data)
  else
    width, height = Display.Dimensions(pick.region.blizzardAuraDisplay.data)
  end
  local spacing = Display.FlowSpacing(group, pick.region, (g.sign[1] ~= 0) and width or height)
  return ((g.sign[1] ~= 0) and width or height) + spacing, spacing, width, height
end

local function Limit(group)
  return math.max(1, math.floor(tonumber(group.blizzardFlowLimit) or 5))
end

-- How far the first `limit` displays reach: displays that lead the row count
-- with their own length, the rest with one icon each.
local function WindowLength(limit, leadSteps, step, spacing)
  local length, count = 0, 0
  for _, lead in ipairs(leadSteps) do
    if count >= limit then break end
    length, count = length + lead, count + 1
  end
  return length + (limit - count) * step - spacing
end

local function LeadSteps(flows)
  local steps = {}
  for _, flow in ipairs(flows) do
    if flow.home and not flow.stand then steps[#steps + 1] = math.abs(flow.x) + math.abs(flow.y) end
  end
  return steps
end

-- Centred: where the visible row starts, no further back than the limit.
-- originFrame/originPoint: a group-owned row's start (RowOrigin); nil for the
-- legacy row, which starts at the first display.
local function CapRowStart(group, g, flows, previous, combat, snapX, snapY, originFrame, originPoint)
  if not previous or not ClipWanted(group) then return previous end
  local vertical = g.sign[1] == 0
  local rule = StretchRule(vertical)
  if not rule then return previous end
  local parent = GroupRegion(group) or UIParent
  local cap = caps[group.id]
  if not cap then
    cap = {left = CreateFrame("Frame", nil, parent),
      joint = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")}
    cap.left:SetSize(1, 1)
    cap.left:EnableMouse(false)
    cap.joint:SetSize(1, 1)
    cap.joint:EnableMouse(false)
    caps[group.id] = cap
  end
  if not combat then
    for _, frame in ipairs({cap.left, cap.joint}) do
      if frame:GetParent() ~= parent then frame:SetParent(parent) end
    end
  end
  local step, spacing = RowStep(group, g, flows)
  local origin = originFrame or flows[1].home or flows[1].region
  local centerPoint = originFrame and originPoint or g.centerPoint
  local back = WindowLength(Limit(group), {}, step, spacing) / 2
  -- A whole number of pixels, so the cap does not depend on engine rounding
  -- (the options preview caps its row the same way).
  local px = PixelsPerUnit(origin)
  if px then back = math.floor(back * px + 0.5 + 0.001) / px end
  if not combat then cap.left:ClearAllPoints() end
  -- From the same whole-pixel centre the shadows start from (snapX, snapY),
  -- so a capped row starts on the pixel the options preview puts it on.
  Place(cap.left, "TOPLEFT", origin, centerPoint, (vertical and 0 or -back) + (snapX or 0), (vertical and back or 0) + (snapY or 0))
  if not combat then cap.joint:ClearAllPoints() end
  local function ToCap() return Place(cap.joint, rule.capPoint, cap.left, "TOPLEFT") end
  local function ToStart() return Place(cap.joint, rule.startPoint, previous.endFrame, previous.endPoint, previous.x, previous.y) end
  local ok
  if rule.capFirst then ok = ToCap() and ToStart() else ok = ToStart() and ToCap() end
  if not ok then return previous end
  return {endFrame = cap.joint, endPoint = rule.readPoint, x = 0, y = 0}
end

-- The cut: from well before the row start (glows and texts of the first icon)
-- to the end of the last display within the limit plus its spacing.
-- How far to move the cut so its corner lands on a whole screen pixel: a cut
-- between pixels redraws what it holds blurred. 0 when the anchor's place is unknown.
local function PixelNudge(clip, anchor, point, offsetX, offsetY)
  local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
  if not factor or factor <= 0 then return 0, 0 end
  -- ForeverAuras: the anchor's point may be a centre (a group-owned row
  -- starts at the group's CENTER), read as such.
  local ok, x, y = pcall(function()
    local cx, cy = anchor:GetCenter()
    return point:find("LEFT") and anchor:GetLeft() or point:find("RIGHT") and anchor:GetRight() or cx,
      point:find("TOP") and anchor:GetTop() or point:find("BOTTOM") and anchor:GetBottom() or cy
  end)
  if not ok or type(x) ~= "number" or type(y) ~= "number" or issecretvalue(x) or issecretvalue(y) then return 0, 0 end
  local anchorScale, clipScale = anchor:GetEffectiveScale(), clip:GetEffectiveScale()
  local function Nudge(value, offset)
    local pixels = (value * anchorScale + offset * clipScale) / factor
    return (math.floor(pixels + 0.5) - pixels) * factor / clipScale
  end
  return Nudge(x, offsetX), Nudge(y, offsetY)
end

-- relativePoint, ox, oy: where on the anchor the row starts, when not the
-- clip's own corner (a group-owned row starts at the group's anchor point).
local function SetWindow(clip, g, point, anchor, length, width, height, spacing, relativePoint, ox, oy)
  relativePoint, ox, oy = relativePoint or point, ox or 0, oy or 0
  -- The cut ends at the last display's far edge, not after its spacing: a cut
  -- that reaches the next display shows that display's first pixel column
  -- (its border) when the edge falls between pixels. The length is rounded to
  -- whole pixels so the edge is a pixel boundary (the start corner is nudged
  -- onto one below), also in the options preview, whose spacing is unrounded.
  local after = length + CLIP_MARGIN
  local px = PixelsPerUnit(clip)
  if px then after = math.floor(after * px + 0.5) / px end
  local horizontal = point:find("LEFT") and -1 or 1
  local vertical = point:find("TOP") and 1 or -1
  local nudgeX, nudgeY = PixelNudge(clip, anchor, relativePoint, horizontal * CLIP_MARGIN + ox, vertical * CLIP_MARGIN + oy)
  clip:ClearAllPoints()
  clip:SetPoint(point, anchor, relativePoint, horizontal * CLIP_MARGIN + ox + nudgeX, vertical * CLIP_MARGIN + oy + nudgeY)
  if g.sign[1] ~= 0 then
    clip:SetSize(after, height + 2 * CLIP_MARGIN)
  else
    clip:SetSize(width + 2 * CLIP_MARGIN, after)
  end
end

-- Options preview: the samples are placed in Lua, so the cut starts at the
-- first one. origin: a group-owned row's start (frame, point, x, y; see
-- ArrangeFlowPreviewNow), where the live cut starts too: the first sample's
-- own offset moves the sample, not the cut.
function Display.PreviewFlowClip(group, g, rowStart, leadSteps, step, origin)
  local clip = clips[group.id]
  if not clip or not ClipWanted(group) or not rowStart or not step or Busy(clip) then return end
  -- The same whole-pixel gap the samples are spaced by.
  local spacing = Display.FlowSpacing(group, rowStart, (g.sign[1] ~= 0) and rowStart:GetWidth() or rowStart:GetHeight())
  local length = WindowLength(Limit(group), leadSteps, step, spacing)
  if origin then
    SetWindow(clip, g, g.start, origin[1], length, rowStart:GetWidth() or 0, rowStart:GetHeight() or 0, spacing,
      origin[2], origin[3], origin[4])
  else
    SetWindow(clip, g, g.start, rowStart, length, rowStart:GetWidth() or 0, rowStart:GetHeight() or 0, spacing)
  end
end

function Display.UpdateFlowClip(group, flows, g)
  if not group then return end
  local wanted = ClipWanted(group)
  local clip = wanted and EnsureClip(group) or clips[group.id]
  if not clip or Busy(clip) then return end
  local groupRegion = GroupRegion(group)
  if not wanted or not groupRegion then
    if not InCombatLockdown() then
      for _, child in ipairs({clip:GetChildren()}) do Reparent(child, groupRegion or clip:GetParent()) end
    end
    -- In combat the displays may still be inside it; they leave after combat.
    if not InCombatLockdown() then
      clip:SetClipsChildren(false)
      clip:Hide()
    end
    return
  end
  if not InCombatLockdown() then
    local inRow = {}
    for _, flow in ipairs(flows or {}) do
      inRow[flow.region] = true
      if flow.region:GetParent() ~= clip and not KeepsParent(FlowData(flow)) then Reparent(flow.region, clip) end
    end
    -- A centred row's display that could not be copied keeps its own place.
    if g.shadow then
      for _, child in ipairs({clip:GetChildren()}) do
        local normal = child.flowNormal
        if not inRow[child] and normal and normal.active and not (normal.stand and normal.stand.active) and child:IsShown() then
          Reparent(child, groupRegion)
        end
      end
    end
    MatchClipStrata(clip, groupRegion)
  end
  local first = flows and flows[1]
  -- The options preview places its own cut.
  if not first or WeakAuras.IsOptionsOpen() then return end
  local step, spacing, width, height = RowStep(group, g, flows)
  local owned = Display.FlowGroupOwned(group)
  local length = WindowLength(Limit(group), g.shadow and {} or LeadSteps(flows), step, spacing)
  local cap = caps[group.id]
  local origin, point = first.home or first.region, g.start
  if g.shadow and cap then origin, point = cap.left, "TOPLEFT" end
  if owned and not (g.shadow and cap) then
    -- ForeverAuras: a group-owned row starts at the group's anchor point
    -- (RowOrigin), where the cut starts too. The cut is an ordinary frame, so
    -- it cannot be anchored to a member's start frame, which follows
    -- secret-length containers (the same client rule as for bars); the group
    -- region is a plain frame.
    local originFrame, originPoint = RowOrigin(group)
    if originFrame then
      local snapX, snapY = SnapOffset(originFrame, originPoint)
      SetWindow(clip, g, g.start, originFrame, length, width, height, spacing, originPoint, snapX, snapY)
      return
    end
  end
  SetWindow(clip, g, point, origin, length, width, height, spacing)
end

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function()
  local groups = afterCombat
  afterCombat = {}
  for group in pairs(groups) do Display.RechainFlow(group) end
end)

local flushing = false
-- When each group was last chained (GetTime is constant within a frame).
local lastFlush = setmetatable({}, {__mode = "k"})
local function FlushQueued()
  -- ForeverAuras: during a load scan (and the editor's batched pick of a
  -- large group, OptionsFrame) the queue is kept for Display.EndFlowLoad:
  -- the per-frame timer below chained every queued group once a frame
  -- regardless of the hold, which made the hold worthless (issue #136).
  if flushing or loadScan > 0 then return end
  flushing = true
  local groups = queued
  queued = {}
  local now = GetTime()
  for group in pairs(groups) do
    lastFlush[group] = now
    Private.StartProfileSystem("aura (modern) - group layout: rechains")
    -- ForeverAuras: one group's failing layout is reported and the others
    -- still chain; an error here used to leave the flag below set, so no
    -- later rechain (visibility, timers, load batches) did anything.
    xpcall(Display.RechainFlow, geterrorhandler(), group)
    Private.StopProfileSystem("aura (modern) - group layout: rechains")
    if WeakAuras.IsOptionsOpen() then xpcall(Display.ArrangeFlowPreview, geterrorhandler(), group) end
  end
  flushing = false
  -- Work queued by the rechain itself (a member it showed or hidden) waits
  -- for the timer QueueRechain set, so a rechain can never loop on itself.
end

local function QueueRechain(region)
  local native = region.blizzardAuraDisplay
  local normal = region.flowNormal
  local data = native and native.active and native.data or normal and normal.active and normal.data
  local group = data and Display.FlowGroup(data)
  if not group then return end
  if not next(queued) then C_Timer.After(0, FlushQueued) end
  queued[group] = true
  -- The row is chained again at once: a display shown or hidden now would
  -- otherwise draw for one frame where the row last put it, a visible jump
  -- sideways as it came in. During a load scan that happens once, at its end
  -- (Display.EndFlowLoad); the timer above catches a queue made while a
  -- rechain was already running.
  -- In the editor only, once per frame per group: selecting a pack shows
  -- every display in one frame, and a full rechain for each of them grew with
  -- the square of the pack's size and stalled the click; the first one chains
  -- the row at once and the rest wait for the timer, which chains it once more
  -- next frame. Live, every change still chains at once: a deferred chain
  -- could fall into combat, where a row with clickable copies cannot be moved,
  -- and leave a display where the row last put it until combat ends.
  if loadScan == 0 and not (WeakAuras.IsOptionsOpen() and lastFlush[group] == GetTime()) then FlushQueued() end
end

function Display.BeginFlowLoad()
  loadScan = loadScan + 1
end

function Display.EndFlowLoad()
  loadScan = math.max(0, loadScan - 1)
  if loadScan == 0 and next(queued) then FlushQueued() end
end

function Display.WatchFlowVisibility(region)
  if region.flowVisibilityHooked then return end
  region.flowVisibilityHooked = true
  TimedHookScript(region, "OnShow", QueueRechain)
  TimedHookScript(region, "OnHide", QueueRechain)
  TimedHookScript(region, "OnSizeChanged", function(self)
    -- Only a normal display's size moves the row (texts resize as they change).
    local normal = self.flowNormal
    if not (normal and normal.active and normal.flow and normal.flow.growth) then return end
    local width, height = NormalSize(self, normal.data)
    if normal.homeWidth and math.abs(width - normal.homeWidth) < 0.5 and math.abs(height - normal.homeHeight) < 0.5 then return end
    QueueRechain(self)
  end)
end

function Display.FlowNormal(data)
  if not data or data.regionType == "group" or data.regionType == "dynamicgroup" or Display.Enabled(data) then return end
  for _, entry in ipairs(data.triggers or {}) do
    if type(entry) == "table" and type(entry.trigger) == "table" and entry.trigger.type == "secretAura" then return end
  end
  local anchor = data.anchorFrameType
  if anchor == "UNITFRAME" or anchor == "NAMEPLATE" or anchor == "CUSTOM" or anchor == "MOUSE" then return end
  local group = Display.FlowGroup(data)
  if group and group.blizzardFlowFrames == nil and not Display.FlowGrid(group) then return group end
end

local function SizeFlowNormal(region, normal, g, group)
  local flow = normal.flow
  local width, height = NormalSize(region, normal.data)
  local along = g.sign[1] ~= 0
  local spacing = Display.FlowSpacing(group, region, along and width or height)
  local size = (along and width or height) + spacing
  flow.growth, flow.endFrame, flow.endPoint = g, flow.start, g.start
  flow.x, flow.y = g.sign[1] * size, g.sign[2] * size
  -- The home and stand frames are plain frames; only a stand carrying secure
  -- content is off limits in combat. A member that first loads in combat (an
  -- "In Combat" load condition) must be sized now, or its centred shadow is
  -- measured from a 1x1 frame and the row centres wrongly until the next fight.
  if (normal.homeWidth ~= width or normal.homeHeight ~= height) and not Display.StandLocked(normal) then
    normal.home:SetSize(width, height)
    if normal.stand then flow.start:SetSize(width, height); flow.startSize = {width, height} end
    normal.homeWidth, normal.homeHeight = width, height
  end
  if g.shadow then
    if not flow.shadowStart then
      flow.shadowStart = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
      flow.shadowStart:EnableMouse(false)
      flow.shadowStart:SetSize(1, 1)
    end
    SetShown(flow.shadowStart, true)
    flow.shadowKind, flow.shadowList, flow.half = "fixed", nil, Display.FlowHalf(region, size)
  else
    SetShown(flow.shadowStart, false)
    flow.shadowKind = nil
  end
end

local function NormalWarning(normal, message)
  local uid = normal.data and normal.data.uid
  if uid then Private.AuraWarnings.UpdateWarning(uid, "flow_normal", message and "warning" or nil, message) end
end

-- ForeverAuras: originPoint names the point of the origin frame the region's
-- start corner goes on (a group-owned row chains an ordinary display to the
-- previous member's end, which can be any corner); a legacy row uses g.start.
function PlaceNormalRegion(region, normal, origin, x, y, originPoint)
  local g = normal.flow.growth
  if not g then return end
  if Busy(region) then return end
  if WeakAuras.IsOptionsOpen() then
    if normal.stand and not Display.StandLocked(normal) then
      SetShown(normal.flow.start, false)
      if region.relativeTo == UIParent then
        region:SetAnchor(g.start, normal.home, g.start)
        region:SetOffset(0, 0)
      end
    end
    return
  end
  if normal.stand and normal.stand.active then
    if not Display.StandLocked(normal) then SetShown(normal.flow.start, true) end
    region:SetOffset(0, 0)
    region:SetAnchor("BOTTOMRIGHT", UIParent, "TOPLEFT")
    return
  end
  region:SetOffset(x or 0, y or 0)
  region:SetAnchor(g.start, origin or normal.home, originPoint or g.start)
end

function Display.AnchorFlowNormal(data, region, anchorParent, anchorPoint)
  local normal = region.flowNormal
  local group = Display.FlowNormal(data)
  if not group then
    if normal and normal.active then
      normal.active = false
      NormalWarning(normal, nil)
      SetShown(normal.flow.shadowStart, false)
      if normal.stand then Display.ReleaseStand(normal); normal.stand = nil; SetShown(normal.flow.start, false) end
      local old = Display.FlowGroup(normal.data) or normal.group
      normal.group = nil
      if old then Display.RechainFlow(old) end
    end
    return false
  end
  if not normal then
    normal = {}
    normal.home = CreateFrame("Frame", nil, UIParent)
    normal.home:EnableMouse(false)
    normal.flow = {start = OnPixels(CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")), startSize = {1, 1}}
    normal.flow.start:EnableMouse(false)
    normal.flow.start:SetSize(1, 1)
    region.flowNormal = normal
  end
  normal.data, normal.group, normal.active = data, group, true
  if not InCombatLockdown() then
    local parent = region:GetParent() or UIParent
    if normal.home:GetParent() ~= parent then normal.home:SetParent(parent) end
    normal.home:ClearAllPoints()
  end
  Place(normal.home, data.selfPoint or "CENTER", anchorParent, anchorPoint or "CENTER", data.xOffset or 0, data.yOffset or 0)
  local g = GROWTH[group.blizzardFlowGrowth] or GROWTH.RIGHT
  -- ForeverAuras: group-owned row: the content frame carries the display's
  -- own offset, and a stand's copies draw in it (SecretAuraStand.lua), so it
  -- exists, or is gone, before the stand is linked below.
  if Display.FlowGroupOwned(group) then
    Display.FlowContent(normal.flow, region)
    PlaceContent(normal.flow, OwnOffset(data))
    normal.flow.contentOn = normal.flow.start
  elseif normal.flow.content then
    SetShown(normal.flow.content, false)
    normal.flow.content = nil
  end
  if Display.UsesStand and Display.UsesStand(data) then
    if not xpcall(function() Display.EnsureStand(region, normal) end, geterrorhandler()) then
      Display.ReleaseStand(normal)
      normal.stand = nil
    end
    normal.homeWidth = nil
  elseif normal.stand then
    Display.ReleaseStand(normal)
    normal.stand = nil
  end
  SizeFlowNormal(region, normal, g, group)
  Display.WatchFlowVisibility(region)
  if WeakAuras.IsOptionsOpen() then
    SetShown(normal.flow.start, false)
    region:SetAnchor(g.start, normal.home, g.start)
    region:SetOffset(0, 0)
    Display.ArrangeFlowPreview(group)
  else
    if not normal.flow.start:GetPoint() then normal.flow.start:SetPoint(g.start, normal.home, g.start) end
    if not region.relativeTo then PlaceNormalRegion(region, normal) end
  end
  QueueRechain(region)
  return true
end

local staleRebuilds = {}
local function StaleGrowth(group, childID)
  local entry = Private.regions[childID]
  local native = entry and entry.region and entry.region.blizzardAuraDisplay
  return native and native.active and native.flow and native.flow.growth
    and native.flow.growth ~= GROWTH[GrowthKey(group)] or false
end

-- Re-anchors every child of a Modern Aura Group in the group's child order.
function Display.RechainFlow(group)
  if not group then return end
  if loadScan > 0 then queued[group] = true; return end
  -- Profiling breakdown of a rechain (no cost unless profiling runs).
  Private.StartProfileSystem("aura (modern) - group layout: merge")
  Display.RefreshFlowMerge(group)
  Private.StopProfileSystem("aura (modern) - group layout: merge")
  Private.StartProfileSystem("aura (modern) - group layout: grid")
  Display.RebuildGrid(group)
  Private.StopProfileSystem("aura (modern) - group layout: grid")
  if Display.FlowGrid(group) then Display.UpdateFlowClip(group) return end
  if group.blizzardFlowFrames == "UNITFRAME" or group.blizzardFlowFrames == "NAMEPLATE" then
    Display.UpdateFlowClip(group)
    if not InCombatLockdown() then
      for _, childID in ipairs(group.controlledChildren or {}) do
        if StaleGrowth(group, childID) and not staleRebuilds[childID] then
          staleRebuilds[childID] = true
          C_Timer.After(0, function()
            staleRebuilds[childID] = nil
            local child = WeakAuras.GetData(childID)
            if child and not InCombatLockdown() and StaleGrowth(group, childID) then WeakAuras.Add(child) end
          end)
        end
      end
    end
    Display.RelinkFlowUnits(group)
    return
  end
  local combat = InCombatLockdown()
  if combat then afterCombat[group] = true end
  local flows, modernFlows = {}, {}
  local g = GROWTH[group.blizzardFlowGrowth] or GROWTH.RIGHT
  -- ForeverAuras: a group-owned row (FlowGroupOwned) starts at the group's
  -- own anchor and chains every member in the group's order; ordinary
  -- displays join the chain like the rest (also with Centered growth), and
  -- the chain reads no member's own offset (their content frames carry it).
  local owned = Display.FlowGroupOwned(group)
  local originFrame, originPoint
  if owned then originFrame, originPoint = RowOrigin(group) end
  if owned and not originFrame then owned = false end
  -- Each child's own region, then its clones (multi-state triggers) in a stable order.
  local members = {}
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    if entry and entry.region then members[#members + 1] = entry.region end
    local cloneIDs = {}
    for cloneId in pairs(Private.clones and Private.clones[childID] or {}) do cloneIDs[#cloneIDs + 1] = cloneId end
    table.sort(cloneIDs, function(a, b) return tostring(a) < tostring(b) end)
    for _, cloneId in ipairs(cloneIDs) do members[#members + 1] = Private.clones[childID][cloneId] end
  end
  for _, region in ipairs(members) do
    local native = region.blizzardAuraDisplay
    local normal = region and region.flowNormal
    local flow = native and native.active and native.flow
    if not flow and normal and normal.active and Display.FlowNormal(normal.data) == group then
      SizeFlowNormal(region, normal, g, group)
      flow = normal.flow
      flow.home = normal.home
    end
    -- A display not yet rebuilt for the group's current growth joins the
    -- chain when its own rebuild runs.
    if flow and flow.endFrame and flow.growth == g and region:IsShown() then
      flow.region = region
      flow.stand = flow.home and normal.stand and normal.stand.active or nil
      if flow.stand then flow.normal = normal end
      -- Both row modes: ordinary displays that cannot be copied lead the row
      -- (see FlowGroupOwned), then every other member in the group's order.
      -- A Centered row starts a secret distance back (the shadows), where no
      -- ordinary display can be placed: such a display keeps its own position.
      if not flow.home or flow.stand then
        modernFlows[#modernFlows + 1] = flow
        if flow.stand then NormalWarning(normal, nil); Display.SyncStandSecure(region, normal); PlaceNormalRegion(region, normal) end
      elseif g.shadow then
        NormalWarning(normal, L["With Centered growth this display keeps its own position: only icons and texts join a centred row (with the old row layout off, also textures, bars and progress textures)."])
        PlaceNormalRegion(region, normal)
      else
        NormalWarning(normal, nil)
        flow.normal = normal
        flows[#flows + 1] = flow
      end
    end
  end
  for _, flow in ipairs(modernFlows) do flows[#flows + 1] = flow end
  -- Centred: the shadows run backwards from the first display's centre point,
  -- and the visible row starts where they end, half a spacing on.
  local previous, shadowEnd
  -- The row's centre (Centered growth) or start corner: the group's anchor
  -- for a group-owned row, else the first display's own frame.
  local rowFrame = owned and originFrame or flows[1] and (flows[1].home or flows[1].region)
  local rowPoint = owned and originPoint or (g.shadow and g.centerPoint or g.start)
  local snapX, snapY = SnapOffset(rowFrame, rowPoint)
  if g.shadow and flows[1] then
    local firstRegion = flows[1].region
    local spacing = Display.FlowSpacing(group, firstRegion, 0) - 0
    local halfSpacing = Display.FlowHalf(firstRegion, spacing)
    for _, flow in ipairs(flows) do
      if flow.shadowStart and flow.shadowKind then
        if not combat then FreshFrame(flow, "shadowStart", "shadowSize", flow.region) end
        local start = flow.shadowStart
        if combat then
          if shadowEnd then Place(start, g.shadow.start, shadowEnd[1], shadowEnd[2], shadowEnd[3], shadowEnd[4])
          else Place(start, g.shadow.start, rowFrame, rowPoint, snapX, snapY) end
          local ok, chained = pcall(ChainShadows, flow)
          if ok then shadowEnd = chained end
        else
          start:ClearAllPoints()
          if not (shadowEnd and Place(start, g.shadow.start, shadowEnd[1], shadowEnd[2], shadowEnd[3], shadowEnd[4])) then
            start:ClearAllPoints()
            start:SetPoint(g.shadow.start, rowFrame, rowPoint, snapX, snapY)
          end
          shadowEnd = ChainShadows(flow)
        end
      end
    end
    if shadowEnd then
      -- Whole units only (see the shadow sizes): the row starts a whole number
      -- of units after the shadows, so every icon lands on the pixel grid.
      previous = {endFrame = shadowEnd[1], endPoint = shadowEnd[2],
        x = shadowEnd[3] + g.sign[1] * halfSpacing, y = shadowEnd[4] + g.sign[2] * halfSpacing}
      previous = CapRowStart(group, g, flows, previous, combat, snapX, snapY, owned and originFrame or nil, owned and originPoint or nil)
    end
  end
  local origin, lead = nil, 0
  for _, flow in ipairs(flows) do
    local region = flow.region
    if not combat then
      local before = flow.start
      FreshFrame(flow, "start", "startSize", region)
      -- ForeverAuras: group-owned row: the content frame follows the start
      -- frame (replaced with it, or replaced itself when locked) and carries
      -- the member's own offset; a replaced one is noted so what hung from
      -- the old frame is made again below, like a replaced start frame.
      if owned and flow.content then
        local contentBefore = flow.content
        FreshFrame(flow, "content", "startSize", region)
        if flow.content ~= contentBefore or flow.start ~= flow.contentOn then
          PlaceContent(flow, OwnOffset(FlowData(flow)))
          flow.contentOn = flow.start
          if flow.content ~= contentBefore then flow.contentReplaced = true end
        end
      end
      -- ForeverAuras: a stand's copies are children of the chain frame; with
      -- the frame replaced they stayed on the abandoned one while the row
      -- placed the new, empty frame. The stand is rebuilt on the new frame.
      if (flow.start ~= before or flow.contentReplaced) and flow.stand and flow.normal and Display.RefreshStand then
        flow.contentReplaced = nil
        Display.RefreshStand(region)
      elseif (flow.start ~= before or flow.contentReplaced) and not flow.home then
        flow.contentReplaced = nil
        -- ForeverAuras: a Modern display's containers, Missing look and
        -- samples hang from its start frame, and its anchor record names the
        -- region, not the frame, so a replaced frame was never noticed: the
        -- content stayed on the abandoned frame while the row placed the new,
        -- empty one. The display is built again on the new frame, next frame
        -- (not inside this chain), out of combat (the replacement only runs
        -- then).
        local native = region.blizzardAuraDisplay
        if native and native.active and native.data and Display.Apply and not native.rebuildQueued then
          native.rebuildQueued = true
          C_Timer.After(0, function()
            native.rebuildQueued = nil
            -- Combat begun since: Apply itself defers a display that already
            -- has instances until restrictions end (its pending set), so the
            -- rebuild is kept rather than dropped; the frame stays replaced
            -- and no later chain would ask again.
            if native.active and region.blizzardAuraDisplay == native then
              Display.Apply(region, native.data)
            end
          end)
        end
      end
    end
    if owned then
      -- ForeverAuras: group-owned row. A leading ordinary display's start
      -- frame and region go on the group's anchor, a running lead along;
      -- every other member's start frame goes on the previous member's end.
      -- No member offset moves the chain: an ordinary display's offset is on
      -- its region only, and a Modern display's or stand's on its content
      -- frame (PlaceContent), whose offset is taken back off when the next
      -- member hangs from an end that lives in that content (the last aura
      -- container, SetFlowEnd; not the Missing presence or the Remaining
      -- Time text, which are measured from the start frame).
      local locked = combat and flow.stand and Display.StandLocked(flow.normal)
      if flow.home and not flow.stand then
        local x, y = g.sign[1] * lead, g.sign[2] * lead
        if not combat then flow.start:ClearAllPoints() end
        Place(flow.start, g.start, originFrame, originPoint, x + snapX, y + snapY)
        local ox, oy = OwnOffset(flow.normal.data)
        PlaceNormalRegion(region, flow.normal, originFrame, x + snapX + ox, y + snapY + oy, originPoint)
        lead = lead + math.abs(flow.x) + math.abs(flow.y)
        previous = flow
      elseif not locked then
        if not combat then flow.start:ClearAllPoints() end
        local px, py = 0, 0
        if previous and previous.region and previous.content and previous.endInContent then
          px, py = OwnOffset(FlowData(previous))
        end
        local chained = previous and Place(flow.start, g.start, previous.endFrame, previous.endPoint, previous.x - px, previous.y - py)
        if not chained then
          if not combat then flow.start:ClearAllPoints() end
          Place(flow.start, g.start, originFrame, originPoint, snapX, snapY)
        end
        previous = flow
      else
        previous = flow
      end
    elseif flow.home and not flow.stand then
      origin = origin or flow.home
      local x, y = g.sign[1] * lead, g.sign[2] * lead
      if not combat then flow.start:ClearAllPoints() end
      Place(flow.start, g.start, origin, g.start, x + snapX, y + snapY)
      PlaceNormalRegion(region, flow.normal, origin, x + snapX, y + snapY)
      lead = lead + math.abs(flow.x) + math.abs(flow.y)
      previous = flow
    elseif combat and flow.stand and Display.StandLocked(flow.normal) then
      previous = flow
    elseif combat then
      -- The display's own offset (OwnOffset) moves only this display; the
      -- previous one's is taken back off its end anchor. The first display's
      -- offset is already in its region's place, where the row starts.
      local ox, oy = RowOffset(flow, flows[1])
      local px, py = RowOffset(previous, flows[1])
      if previous then
        Place(flow.start, flow.growth.start, previous.endFrame, previous.endPoint, previous.x + ox - px, previous.y + oy - py)
      else
        Place(flow.start, flow.growth.start, flow.home or region, flow.growth.start, snapX + ox, snapY + oy)
      end
      previous = flow
    else
      flow.start:ClearAllPoints()
      -- As in combat above: this display's own offset on, the previous one's off.
      local ox, oy = RowOffset(flow, flows[1])
      local px, py = RowOffset(previous, flows[1])
      local chained = previous and Place(flow.start, flow.growth.start,
        previous.endFrame, previous.endPoint, previous.x + ox - px, previous.y + oy - py)
      if not chained then
        -- First display, or Blizzard refused the anchor: start at the region.
        flow.start:ClearAllPoints()
        flow.start:SetPoint(flow.growth.start, flow.home or region, flow.growth.start, snapX + ox, snapY + oy)
      end
      previous = flow
    end
  end
  Display.UpdateFlowClip(group, flows, g)
end

Display.RechainFlow = Private.Profiled("aura (modern) - group layout", Display.RechainFlow)
