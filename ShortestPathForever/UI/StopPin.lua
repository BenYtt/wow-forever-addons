---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

local GOAL_ATLAS, GOAL_SCALE = "Waypoint-MapPin-Tracked", 0.8
-- The map's own quest button (POIButtonTemplate): a 20-unit button whose 32-unit disc art overhangs it.
local STOP_SIZE = 20
-- The numbered quest button's numerals (QuestPOI_CalculateNumericTexCoords): an 8 by 8 grid whose lower half holds
-- the yellow numbers 1 to 25; later stops use the font.
local NUMERAL_CELL, NUMERAL_YELLOW, NUMERALS_PER_ROW, MAX_NUMERAL = 0.125, 0.5, 8, 25
-- The stop being travelled to wears the button of the quest the game tracks (POIButton.lua): the lit disc with the
-- dark numeral from the grid's upper half. Every other stop wears the plain button with the yellow numeral.
local STOP_ATLAS, CURRENT_ATLAS = "UI-QuestPoi-QuestNumber", "UI-QuestPoi-QuestNumber-SuperTracked"
local NUMBER_YELLOW, NUMBER_DARK = { 1, 0.82, 0.25 }, { 0.1, 0.05, 0 }
-- A lone stop's own mark stands alone at the size of the map's quest marks. A numbered one keeps its button and wears
-- the mark as a badge over the button's lower right, as Legacy Forever's entrance pins wear the Legacy shield; the
-- pin's hit rect reaches out over the badge.
local LOOK_SIZE, BADGE_SIZE, BADGE_OFFSET, TAG_SIZE = 22, 16, 4, 11
-- Later stops stay stronger than Strokes.lua's later lines so their numbers remain legible.
local LATER_STOP_ALPHA = 0.9
-- Route.lua groups stops by the button's size.
ns.GoalAtlas, ns.StopSize = GOAL_ATLAS, STOP_SIZE

---@class SPFGoalPin : SPFCanvasPin
---@field Texture Texture
---@field Icon Texture
---@field Disc Texture
---@field Button Texture
---@field Glow Texture
---@field Numeral Texture
---@field Number FontString
---@field stopTitles? string[]
---@field stopDetails? string[]
---@field current? boolean -- marks the stop being travelled to, whose steps the tooltip lists
local GoalPin = CreateFromMixins(ns.MapCanvas.PinMixin)
-- Route.lua's pool puts it on.
ns.GoalPinMixin = GoalPin

function GoalPin:OnLoad()
	-- The user waypoint's level (WaypointLocationDataProvider), above every quest POI, super-tracked ones included.
	self:UseFrameLevelType("PIN_FRAME_LEVEL_WAYPOINT_LOCATION")
	self:SetIgnoreGlobalPinScale(true)
	self:SetScalingLimits(1, 1, 1)
	self.takesMouse = true
	-- The disc's own silhouette, opaque under a faded button.
	self.Disc:SetVertexColor(0, 0, 0)
	self.Number = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	self.Number:SetPoint("CENTER")
	for _, texture in ipairs({ self.Button, self.Numeral }) do
		texture:SetDesaturated(false)
		texture:SetVertexColor(1, 0.9, 0.7)
	end
	self:SetScript("OnHide", self.OnMouseLeave)
end

-- A lone destination wears the waypoint pin; a numbered stop wears the map's quest button with its number. Stops
-- whose buttons would overlap, a place visited twice among them, share one: it shows the first stop's number with the
-- action badge intact, and its tooltip names each.
-- A numbered stop whose caller said what stands there wears that mark as a badge on the button's lower right, so the
-- pin reads as step 3 at the quest giver or flight master; a lone one wears the mark alone, full size.
---@param numbers integer[]? the stops this pin marks, in order; nil for a lone destination
---@param titles string[]
---@param look? SPFAPIStopKind
---@param details? string[]
---@param pinBadge? boolean
function GoalPin:OnAcquired(x, y, numbers, titles, later, look, details, pinBadge)
	self:SetPosition(x, y)
	-- The disc's shadow stays opaque, so a faded button still hides the POI beneath it.
	local alpha = later and LATER_STOP_ALPHA or 1
	self.Button:SetAlpha(alpha)
	self.Icon:SetAlpha(alpha)
	self.Numeral:SetAlpha(alpha)
	self.Number:SetAlpha(alpha)
	self.stopTitles = titles[1] and titles or nil
	self.stopDetails = details and details[1] and details or nil
	self.current = not later
	local marked = look ~= nil and ns.SetStopLook(self.Icon, look, numbers and BADGE_SIZE or LOOK_SIZE)
	local badge = marked and numbers ~= nil
	self.Icon:SetShown(marked)
	self.Icon:ClearAllPoints()
	self.Icon:SetPoint(badge and "BOTTOMRIGHT" or "CENTER", badge and BADGE_OFFSET or 0, badge and -BADGE_OFFSET or 0)
	local corner = badge and -BADGE_OFFSET or 0
	self:SetHitRectInsets(0, corner, 0, corner)
	self.Texture:SetShown(not marked and numbers == nil)
	self.Disc:SetShown(numbers ~= nil)
	self.Button:SetShown(numbers ~= nil)
	local number = numbers and numbers[1]
	local numeral = number ~= nil and number <= MAX_NUMERAL
	self.Numeral:SetShown(numeral)
	self.Number:SetText(number and not numeral and tostring(number) or "")
	local current = numbers ~= nil and not later
	-- art-ok: both quest buttons are 32 by 32, in Map.xml's 32 by 32 box
	self.Button:SetAtlas(current and CURRENT_ATLAS or STOP_ATLAS)
	self.Number:SetTextColor(unpack(current and NUMBER_DARK or NUMBER_YELLOW))
	if numeral then
		local left = (number - 1) % NUMERALS_PER_ROW * NUMERAL_CELL
		local top = (current and 0 or NUMERAL_YELLOW) + math.floor((number - 1) / NUMERALS_PER_ROW) * NUMERAL_CELL
		self.Numeral:SetTexCoord(left, left + NUMERAL_CELL, top, top + NUMERAL_CELL)
	end
	if numbers then
		self:SetSize(STOP_SIZE, STOP_SIZE)
	elseif marked then
		self:SetSize(LOOK_SIZE, LOOK_SIZE)
	else
		-- The native waypoint pin (SuperTrackedFrame.lua:219) that Guide's marker wears, so map and marker agree.
		local atlas = C_Texture.GetAtlasInfo(GOAL_ATLAS)
		self:SetSize(atlas.width * GOAL_SCALE, atlas.height * GOAL_SCALE)
		self.Texture:SetAtlas(GOAL_ATLAS) -- art-ok: fills the pin, sized above from the atlas's own shape
	end
	self.Texture:ClearAllPoints()
	if pinBadge and not numbers and not marked then
		self:SetSize(LOOK_SIZE, LOOK_SIZE)
		ns.Art.Fit(self.Texture, GOAL_ATLAS, TAG_SIZE, TAG_SIZE)
		self.Texture:SetPoint("CENTER", self, "BOTTOMRIGHT", 0, 0)
		self:SetHitRectInsets(0, -TAG_SIZE / 2, 0, -TAG_SIZE / 2)
	else
		self.Texture:SetAllPoints()
	end
end

function GoalPin:OnMouseEnter()
	local title, rows = ns.JourneyInfo()
	if not title or not rows then
		return
	end
	self.Glow:SetShown(self.Disc:IsShown() or self.Icon:IsShown())
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	-- A shared button names every stop it marks, in order.
	local stopTitles = self.stopTitles or {}
	GameTooltip_SetTitle(GameTooltip, stopTitles[1] or title)
	for i = 2, #stopTitles do
		GameTooltip_AddColoredLine(GameTooltip, stopTitles[i], HIGHLIGHT_FONT_COLOR)
	end
	for _, detail in ipairs(self.stopDetails or {}) do
		GameTooltip_AddNormalLine(GameTooltip, detail)
	end
	-- The pin you are travelling to lists the steps there, as the tracker does, under the time and distance left.
	if self.current then
		local time, distance = ns.JourneyLeft()
		if time then
			GameTooltip_AddColoredLine(GameTooltip, string.format(L["%s · %s"], time, distance), HIGHLIGHT_FONT_COLOR)
		end
		local hint = ns.OtherFactionHint()
		if hint then
			GameTooltip_AddNormalLine(GameTooltip, hint)
		end
		for _, row in ipairs(rows) do
			local color = row.current and HIGHLIGHT_FONT_COLOR or row.grey and GRAY_FONT_COLOR or NORMAL_FONT_COLOR
			GameTooltip_AddColoredLine(GameTooltip, row.text, color)
		end
		ns.FamilyHints.AddEntranceLine(GameTooltip)
	end
	GameTooltip_AddNormalLine(GameTooltip, L["Right-click to clear"])
	GameTooltip:Show()
end

function GoalPin:OnMouseLeave()
	self.Glow:Hide()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

-- Pins pass right clicks to the canvas to zoom out (UI/MapCanvas.lua); this one clears instead.
function GoalPin.ShouldMouseButtonBePassthrough()
	return false
end

function GoalPin.OnMouseClickAction(_, button)
	if button == "RightButton" then
		ns.ClearJourney()
	end
end

function GoalPin:OnReleased()
	self:OnMouseLeave()
	self.stopTitles = nil
	self.stopDetails = nil
	self.current = nil
end
