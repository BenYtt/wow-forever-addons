---@type string, SkillUpNamespace
local _, ns = ...

-- The addon's lists draw what they hold the way the game draws its own items: a full-size icon in its
-- stock border, the item's name beside it in the item-name font and the supporting facts on the line
-- under it. A heading is a stock font line and a message is the list's own hint or empty state. The list
-- is the game's scroll box list, which pools the rows and keeps only the ones on screen, laid out by the
-- templates in UI/Shopping.xml.

local ICON_SIZE = 37
local ROW_HEIGHT = 46
local HEADING_HEIGHT = 26
local MESSAGE_MIN_HEIGHT = 20
-- Room kept on the right for the scroll bar, so the rows line up with or without it.
local SCROLL_BAR_WIDTH = 18
-- Padding inside a message frame, left and right, so the text wraps where the frame does.
local MESSAGE_PADDING = 12

local ROW_TEMPLATE = "SkillUpForeverListRowTemplate"
local HEADING_TEMPLATE = "SkillUpForeverListHeadingTemplate"
local MESSAGE_TEMPLATE = "SkillUpForeverListMessageTemplate"

-- Item data that arrives after a hover makes the game rebuild the item's tooltip, which drops the lines a row
-- added under it. The tooltip asks its owner for a fresh one first (`owner:UpdateTooltip()`), so a hovered
-- row draws its own again once new data has come. Shift does the same: it changes what an item's tooltip
-- shows, and the redraw that follows is of the item alone. A read of where a vendor, quest or trainer is
-- arrives late the same way, so the sources change marks the tooltip stale too.
local staleTooltip = false
local function Stale()
	staleTooltip = true
end
ns.WhenEvent("TOOLTIP_DATA_UPDATE", Stale)
ns.WhenEvent("MODIFIER_STATE_CHANGED", Stale)
ns.WhenStale("tooltip", Stale)

---@param row SkillUpListRow
local function ShowTooltip(row)
	staleTooltip = false
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	row.tooltip(GameTooltip)
	GameTooltip:Show()
end

---@param row SkillUpListRow
local function OnEnter(row)
	if row.tooltip then
		ShowTooltip(row)
	end
end

-- Called by the tooltip this row owns, a few times a second.
---@param row SkillUpListRow
local function UpdateTooltip(row)
	if staleTooltip and row.tooltip then
		ShowTooltip(row)
	end
end

-- The parts a frame draws once, whichever element it later holds. The view pools the frames, so the
-- initializers draw a frame's parts only the first time they see it; a pooled frame is redrawn from the
-- element it is given. A weak key lets a released frame be collected.
local built = setmetatable({}, { __mode = "k" })

-- The parts a row draws once, whatever entry it later holds.
---@param row SkillUpListRow
local function BuildRow(row)
	row.kind = "row"
	-- art-ok: the quest log's highlight bar, stretched over the row as a bar is
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row.UpdateTooltip = UpdateTooltip
	row:SetScript("OnEnter", OnEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	-- A right-click opens the row's menu when it has one; any other click is the row's own.
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if row.menu then
				GameTooltip_Hide()
				MenuUtil.CreateContextMenu(row, row.menu)
			end
		elseif row.click then
			row.click(row)
		end
	end)
	row.Icon = row:CreateTexture(nil, "ARTWORK")
	row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.Icon:SetPoint("LEFT", 6, 0)
	row.IconBorder = row:CreateTexture(nil, "OVERLAY")
	row.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame") -- art-ok: a square border in the ICON_SIZE square
	row.IconBorder:SetSize(ICON_SIZE, ICON_SIZE)
	row.IconBorder:SetPoint("LEFT", row.Icon, "LEFT", 0, 0)
	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.Text:SetJustifyH("LEFT")
	row.Text:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
	row.Text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Detail:SetJustifyH("LEFT")
	row.Detail:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -2)
	row.Detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
end

---@param row SkillUpListRow
---@param elementData SkillUpListElement
local function InitializeRow(row, elementData)
	if not built[row] then
		built[row] = true
		BuildRow(row)
	end
	local entry = elementData.entry --[[@as SkillUpListEntry]]
	row.entry = entry
	-- art-ok: a square file icon in the ICON_SIZE square; the texture never draws an atlas
	row.Icon:SetTexture(entry.icon)
	row.Icon:SetShown(entry.icon ~= nil)
	row.IconBorder:SetShown(entry.icon ~= nil)
	if entry.iconColor then
		row.IconBorder:SetVertexColor(entry.iconColor:GetRGB())
	else
		row.IconBorder:SetVertexColor(1, 1, 1)
	end
	row.Text:SetText(entry.text)
	row.Text:SetTextColor((entry.color or HIGHLIGHT_FONT_COLOR):GetRGB())
	row.Detail:SetText(entry.detail or "")
	row.Detail:SetShown(entry.detail ~= nil)
	row.Detail:SetTextColor((entry.detailColor or GRAY_FONT_COLOR):GetRGB())
	row.tooltip = entry.tooltip
	row.click = entry.click
	row.menu = entry.menu
	row:EnableMouse(entry.tooltip ~= nil or entry.click ~= nil or entry.menu ~= nil)
end

---@param heading SkillUpListHeading
---@param elementData SkillUpListElement
local function InitializeHeading(heading, elementData)
	if not built[heading] then
		built[heading] = true
		heading.kind = "heading"
		heading.Text = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading.Text:SetPoint("BOTTOMLEFT", heading, "BOTTOMLEFT", 6, 4)
	end
	heading.Text:SetText(elementData.text)
	heading.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
end

---@param message SkillUpListMessage
---@param elementData SkillUpListElement
local function InitializeMessage(message, elementData)
	if not built[message] then
		built[message] = true
		message.kind = "message"
		message.Text = message:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		message.Text:SetWordWrap(true)
		message.Text:SetJustifyH("LEFT")
		message.Text:SetPoint("TOPLEFT", message, "TOPLEFT", 6, -4)
		message.Text:SetPoint("RIGHT", message, "RIGHT", -6, 0)
	end
	message.Text:SetText(elementData.text)
	message.Text:SetTextColor((elementData.color or GRAY_FONT_COLOR):GetRGB())
end

-- A list in the game's own scroll box list: rows the game draws its items with, headings and messages. A
-- caller fills it between Begin and Finish; the game pools the frames and shows only the ones on screen.
---@param parent Frame
---@return SkillUpList
function ns.CreateList(parent)
	local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList") --[[@as SkillUpScrollBox]]
	scrollBox:SetPoint("TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 4)
	local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar") --[[@as SkillUpScrollBar]]
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
	scrollBar:SetHideIfUnscrollable(true)

	-- A message's height is its wrapped text's, so one line string measures every message at the width the
	-- list has now, and the scroll box lays the frames out from that.
	local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	measure:SetWordWrap(true)
	measure:Hide()

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtentCalculator(function(_, elementData)
		if elementData.kind == "row" then
			return ROW_HEIGHT
		elseif elementData.kind == "heading" then
			return HEADING_HEIGHT
		end
		local width = scrollBox:GetWidth() - MESSAGE_PADDING
		if width > 0 then
			measure:SetWidth(width)
		end
		measure:SetText(elementData.text)
		return math.max(MESSAGE_MIN_HEIGHT, measure:GetStringHeight() + 8)
	end)
	view:SetElementFactory(function(factory, elementData)
		if elementData.kind == "row" then
			factory(ROW_TEMPLATE, InitializeRow)
		elseif elementData.kind == "heading" then
			factory(HEADING_TEMPLATE, InitializeHeading)
		else
			factory(MESSAGE_TEMPLATE, InitializeMessage)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	---@class SkillUpList
	local list = { rows = {}, scrollBox = scrollBox }

	function list:Begin()
		self.rows = {}
	end

	---@param text string
	function list:Heading(text)
		self.rows[#self.rows + 1] = { kind = "heading", text = text }
	end

	---@param text string
	---@param color ColorMixin?
	function list:Message(text, color)
		self.rows[#self.rows + 1] = { kind = "message", text = text, color = color }
	end

	---@param entry SkillUpListEntry
	function list:Add(entry)
		self.rows[#self.rows + 1] = { kind = "row", entry = entry }
	end

	function list:Finish()
		self.scrollBox:SetDataProvider(CreateDataProvider(self.rows), ScrollBoxConstants.RetainScrollPosition)
	end
	return list
end
