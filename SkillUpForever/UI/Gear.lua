---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- The crafted gear page: a character sheet of its own. One item slot per equipment slot the sheet
-- has, down both sides and along the bottom, each showing the newest item this character could craft
-- for it, and a pane in the middle for the selected slot's pick. The listing rule is Core/Gear.lua's;
-- this draws it the way the game draws its own slots and items. The page's own title is the inset's
-- heading, under the window's title bar and clear of its portrait.

-- The game's stock item icon size and the paper doll's own gap between slots.
local ICON = 37
local SLOT_GAP = 6
local ROW_HEIGHT = 40

-- The character sheet's slot names, one per Core/Gear.lua's slot group in order: the left column, the
-- right column and the weapon row. C_PaperDollInfo.GetInventorySlotInfo gives each one's empty art.
local SLOT_NAMES = {
	"HeadSlot",
	"NeckSlot",
	"ShoulderSlot",
	"BackSlot",
	"ChestSlot",
	"WristSlot",
	"HandsSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"Finger0Slot",
	"Trinket0Slot",
	"MainHandSlot",
	"SecondaryHandSlot",
	"RangedSlot",
}
local LEFT = { 1, 2, 3, 4, 5, 6 }
local RIGHT = { 7, 8, 9, 10, 11, 12 }
local BOTTOM = { 13, 14, 15 }

---@type SkillUpGearPage
local page
---@type SkillUpSideTab
local tab
local selectedSlot -- the group index the pane shows
local selectedItemID -- the item in the pane, nil for the slot's pick
local slots = {} -- the last render, by slot group
local professions = {} -- the character's own, by skill line
local RenderDetail
local Render

---@param itemID integer
---@return ColorMixin?
local function QualityColor(itemID)
	local quality = C_Item.GetItemQualityByID(itemID)
	if not quality then
		return nil
	end
	local red, green, blue = C_Item.GetItemQualityColor(quality)
	return CreateColor(red, green, blue)
end

-- What the character can do with the recipe in plain words. A recipe whose requirement the data does
-- not know is not called learnable, and says its source is unknown instead.
---@param item SkillUpGearItem
---@return string
local function Status(item)
	if item.state == "known" then
		return L["You know it"]
	elseif item.state == "trainable" then
		return L["Can learn it"]
	elseif item.state == "needs" then
		return string.format(L["Needs %s %d"], item.profession, item.skill)
	elseif item.skill == nil then
		return L["Source unknown"]
	end
	return L["Another crafter"]
end

-- The profession and the skill its recipe is learned at, or that the data does not know the skill.
---@param item SkillUpGearItem
---@return string
local function LearnedAt(item)
	if item.skill then
		return string.format(L["%s, %d"], item.profession, item.skill)
	end
	return string.format(L["%s, source unknown"], item.profession)
end

-- The item's required level and type, as the client's own item data names them.
---@param item SkillUpGearItem
---@return string
local function Requirement(item)
	-- multi-value: the item's type and subtype sit after its name, link, quality and level.
	local _, _, _, _, _, itemType, subType = C_Item.GetItemInfo(item.itemID)
	local kind = subType or itemType
	if item.level <= 0 then
		return kind or ""
	end
	if kind then
		return string.format(L["Level %d %s"], item.level, kind)
	end
	return string.format(L["Level %d"], item.level)
end

-- Where a trainable recipe is learned, else nil: the trainer or the scroll's source, read the way
-- the route page reads them.
---@param item SkillUpGearItem
---@return integer?
local function RecipeNPC(item)
	local profession = professions[item.skillLine]
	return profession and ns.RecipeNPC(profession, item.recipeID) or nil
end

-- The game's item tooltip for the pick, under it what the addon knows of its recipe and what a click
-- does or why it cannot.
---@param item SkillUpGearItem
---@return fun(tooltip: GameTooltip)
local function ItemTooltip(item)
	return function(tooltip)
		tooltip:SetItemByID(item.itemID)
		GameTooltip_AddBlankLineToTooltip(tooltip)
		if item.state ~= "needs" then
			GameTooltip_AddNormalLine(tooltip, LearnedAt(item))
		end
		GameTooltip_AddNormalLine(tooltip, Status(item))
		local profession = professions[item.skillLine]
		if item.state == "known" then
			GameTooltip_AddInstructionLine(tooltip, L["Click to open the recipe."])
		elseif item.state == "trainable" and profession then
			if ns.TrainingFor(profession, item.recipeID) then
				ns.AddNearest(tooltip, L["Nearest trainer"], RecipeNPC(item))
			else
				local source = ns.Catalogue.Recipe(item.recipeID)
				if source then
					ns.AddSourceLines(tooltip, source)
				end
				local npcID = RecipeNPC(item)
				if npcID then
					ns.AddNearest(tooltip, L["Source"], npcID, true)
				end
			end
		end
	end
end

-- The pane's one button: open a known recipe, set a waypoint to where a trainable one is taught, or
-- nothing with the reason why.
---@param item SkillUpGearItem
---@return string text
---@return boolean enabled
---@return fun()? click
---@return string? reason
local function Action(item)
	if item.state == "known" then
		return L["Open recipe"], true, function()
			C_TradeSkillUI.OpenRecipe(item.recipeID)
		end
	end
	if item.state == "trainable" then
		local npcID = RecipeNPC(item)
		if npcID then
			return L["Set waypoint"], true, function()
				ns.SetWaypoint(npcID)
			end
		end
		return L["Set waypoint"], false, nil, L["The place this recipe is taught isn't known yet."]
	end
	if item.skill == nil then
		return L["Set waypoint"], false, nil, L["The source of this recipe isn't known."]
	end
	if item.state == "needs" then
		return L["Set waypoint"], false, nil, string.format(L["Needs %s %d"], item.profession, item.skill)
	end
	return L["Set waypoint"], false, nil, L["Another craft makes this recipe, not yours."]
end

---@param row SkillUpGearRow
local function ShowRowTooltip(row)
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	row.tooltip(GameTooltip)
	GameTooltip:Show()
end

-- A full-size item row: the game's icon in its quality border, a name and a line under it.
---@param parent Frame
---@return SkillUpGearRow
local function CreateRow(parent)
	local row = CreateFrame("Button", nil, parent) --[[@as SkillUpGearRow]]
	row:SetHeight(ROW_HEIGHT)
	-- art-ok: the quest log's highlight bar, stretched over the row as a bar is
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row.Icon = row:CreateTexture(nil, "BORDER")
	row.Icon:SetSize(ICON, ICON)
	row.Icon:SetPoint("LEFT", 0, 0)
	row.Border = row:CreateTexture(nil, "OVERLAY")
	row.Border:SetTexture("Interface\\Common\\WhiteIconFrame") -- art-ok: a square border in the ICON square
	row.Border:SetSize(ICON, ICON)
	row.Border:SetPoint("LEFT", row.Icon, "LEFT", 0, 0)
	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.Text:SetJustifyH("LEFT")
	row.Text:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, -2)
	row.Text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.Detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Detail:SetJustifyH("LEFT")
	row.Detail:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -2)
	row.Detail:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row:SetScript("OnEnter", function(self)
		if self.tooltip then
			ShowRowTooltip(self)
		end
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnClick", function(self)
		if self.click then
			self.click()
		end
	end)
	return row
end

---@param row SkillUpGearRow
---@param icon fileID?
---@param color ColorMixin?
---@param text string
---@param textColor ColorMixin?
---@param detail string?
---@param detailColor ColorMixin?
---@param tooltip (fun(tooltip: GameTooltip))?
---@param click (fun())?
local function FillRow(row, icon, color, text, textColor, detail, detailColor, tooltip, click)
	row.Icon:SetTexture(icon) -- art-ok: a square file icon in the ICON square; the texture never draws an atlas
	row.Icon:SetShown(icon ~= nil)
	row.Border:SetShown(icon ~= nil)
	if color then
		row.Border:SetVertexColor(color:GetRGB())
	else
		row.Border:SetVertexColor(1, 1, 1)
	end
	row.Text:SetText(text)
	row.Text:SetTextColor((textColor or HIGHLIGHT_FONT_COLOR):GetRGB())
	row.Detail:SetText(detail or "")
	row.Detail:SetShown(detail ~= nil)
	row.Detail:SetTextColor((detailColor or GRAY_FONT_COLOR):GetRGB())
	row.tooltip = tooltip
	row.click = click
	row:EnableMouse(tooltip ~= nil or click ~= nil)
	row:Show()
end

---@param pool SkillUpGearRow[]
---@param parent Frame
---@param index integer
---@return SkillUpGearRow
local function Pooled(pool, parent, index)
	local row = pool[index]
	if not row then
		row = CreateRow(parent)
		pool[index] = row
	end
	return row
end

---@param pool SkillUpGearRow[]
---@param used integer
local function HideFrom(pool, used)
	for index = used + 1, #pool do
		pool[index]:Hide()
	end
end

-- The slot's pick, or the row the pane has selected.
---@param slot SkillUpGearSlot?
---@return SkillUpGearItem?
local function SelectedItem(slot)
	if not slot then
		return nil
	end
	for _, item in ipairs(slot.items) do
		if item.itemID == selectedItemID then
			return item
		end
	end
	return slot.items[1]
end

---@param item SkillUpGearItem
---@return string
local function ItemName(item)
	if item.name then
		return item.name
	end
	-- ITEM_DATA_LOAD_RESULT redraws once the name arrives.
	C_Item.RequestLoadItemDataByID(item.itemID)
	return string.format(L["item %d"], item.itemID)
end

---@param detail Frame
---@param item SkillUpGearItem
local function RenderReagents(detail, item)
	local reagents = ns.Reagents(item.recipeID) or {}
	page.Detail.Reagents:SetShown(#reagents > 0)
	-- Two columns, so a recipe with many reagents still fits the pane.
	---@type Region[]
	local anchor = { page.Detail.Reagents, page.Detail.Reagents }
	for index, reagent in ipairs(reagents) do
		local column = (index - 1) % 2
		local row = Pooled(page.Detail.ReagentRows, detail, index)
		local have = ns.Have(reagent.itemID)
		local need = reagent.quantity
		local name = C_Item.GetItemNameByID(reagent.itemID)
		if not name then
			C_Item.RequestLoadItemDataByID(reagent.itemID)
			name = string.format(L["item %d"], reagent.itemID)
		end
		row:ClearAllPoints()
		if column == 0 then
			row:SetPoint("TOPLEFT", anchor[1], "BOTTOMLEFT", 0, -2)
			row:SetPoint("RIGHT", detail, "CENTER", -4, 0)
		else
			row:SetPoint("TOP", anchor[2], "BOTTOM", 0, -2)
			row:SetPoint("LEFT", detail, "CENTER", 4, 0)
			row:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
		end
		anchor[column + 1] = row
		FillRow(
			row,
			C_Item.GetItemIconByID(reagent.itemID),
			QualityColor(reagent.itemID),
			name,
			HIGHLIGHT_FONT_COLOR,
			string.format("%d/%d", math.min(have, need), need),
			have >= need and ns.COLORS.green or GRAY_FONT_COLOR,
			function(tooltip)
				tooltip:SetItemByID(reagent.itemID)
			end
		)
	end
	HideFrom(page.Detail.ReagentRows, #reagents)
	return #reagents > 0 and page.Detail.ReagentRows[#reagents] or page.Detail.Reagents
end

---@param detail Frame
---@param item SkillUpGearItem
---@param above Region
local function RenderOthers(detail, item, above)
	local others = {}
	for _, candidate in ipairs(slots[selectedSlot] and slots[selectedSlot].items or {}) do
		if candidate.itemID ~= item.itemID then
			others[#others + 1] = candidate
		end
	end
	page.Detail.Also:SetShown(#others > 0)
	if #others > 0 then
		page.Detail.Also:ClearAllPoints()
		page.Detail.Also:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -10)
		above = page.Detail.Also
	end
	for index, other in ipairs(others) do
		local row = Pooled(page.Detail.OtherRows, detail, index)
		row:ClearAllPoints()
		if index == 1 then
			row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
		else
			row:SetPoint("TOPLEFT", page.Detail.OtherRows[index - 1], "BOTTOMLEFT", 0, 0)
		end
		row:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
		FillRow(
			row,
			C_Item.GetItemIconByID(other.itemID),
			QualityColor(other.itemID),
			ItemName(other),
			QualityColor(other.itemID) or HIGHLIGHT_FONT_COLOR,
			Status(other),
			other.state == "known" and ns.COLORS.green or GRAY_FONT_COLOR,
			ItemTooltip(other),
			function()
				selectedItemID = other.itemID
				RenderDetail()
			end
		)
	end
	HideFrom(page.Detail.OtherRows, #others)
	return #others > 0 and page.Detail.OtherRows[#others] or above
end

-- The pane for the selected slot: the pick's icon, name and facts, its reagents, one action and the
-- slot's other items. With nothing selected the pane says so and points at the switch.
function RenderDetail()
	local slot = slots[selectedSlot]
	local item = SelectedItem(slot)
	local detail = page.Detail
	detail.Empty:SetShown(item == nil)
	detail.Body:SetShown(item ~= nil)
	if not item then
		detail.Empty:SetText(
			ns.ShowAllGear() and L["No crafted gear for your level and class yet."]
				or L["No crafted gear you can make yet. Tick the box above to see gear you cannot make."]
		)
		return
	end
	local color = QualityColor(item.itemID)
	-- art-ok: a square item icon in its 47 square; the texture never draws an atlas
	detail.Icon:SetTexture(C_Item.GetItemIconByID(item.itemID))
	if color then
		detail.Border:SetVertexColor(color:GetRGB())
	else
		detail.Border:SetVertexColor(1, 1, 1)
	end
	detail.Name:SetText(ItemName(item))
	detail.Name:SetTextColor((color or HIGHLIGHT_FONT_COLOR):GetRGB())
	detail.Requirement:SetText(Requirement(item))
	detail.Learn:SetText(LearnedAt(item))
	detail.State:SetText(Status(item))
	local stateColor = (item.state == "known" or item.state == "trainable") and ns.COLORS.green or GRAY_FONT_COLOR
	detail.State:SetTextColor(stateColor:GetRGB())
	local above = RenderReagents(detail.Body, item)
	detail.Action:ClearAllPoints()
	detail.Action:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -10)
	local text, enabled, click, reason = Action(item)
	detail.Action:SetText(text)
	-- As wide as its label, so a translated one fits.
	detail.Action:SetWidth(math.max(130, detail.Action:GetTextWidth() + 32))
	detail.Action:SetEnabled(enabled)
	detail.Action.click = click
	detail.Action.reason = reason
	RenderOthers(detail.Body, item, detail.Action)
end

---@param button SkillUpGearSlotButton
---@param item SkillUpGearItem?
---@param checked boolean
local function SetSlot(button, item, checked)
	button:SetChecked(checked)
	button.select:SetShown(checked)
	button.item = item
	if not item then
		local _, textureName = C_PaperDollInfo.GetInventorySlotInfo(SLOT_NAMES[button.slot])
		button.icon:SetTexture(textureName) -- art-ok: the square empty-slot art in the ICON square
		button.icon:SetDesaturated(true)
		button.border:Hide()
		button.mark:Hide()
		return
	end
	-- art-ok: a square item icon in the ICON square; the texture never draws an atlas
	button.icon:SetTexture(C_Item.GetItemIconByID(item.itemID))
	button.icon:SetDesaturated(item.state ~= "known" and item.state ~= "trainable")
	local color = QualityColor(item.itemID)
	button.border:Show()
	if color then
		button.border:SetVertexColor(color:GetRGB())
	else
		button.border:SetVertexColor(1, 1, 1)
	end
	button.mark:SetShown(item.state == "known")
end

---@param index integer
local function SelectSlot(index)
	selectedSlot = index
	selectedItemID = nil
	Render()
end

local function RenderSlots()
	local bySlot = {}
	for _, slot in ipairs(slots) do
		bySlot[slot.slot] = slot
	end
	for index, button in ipairs(page.Slots) do
		local slot = bySlot[index]
		local item = slot and slot.items[1] or nil
		SetSlot(button, item, index == selectedSlot)
	end
end

-- The first slot whose pick the character knows or can learn, else the first with anything listed.
---@return integer?
local function DefaultSlot()
	for _, slot in ipairs(slots) do
		local item = slot.items[1]
		if item and (item.state == "known" or item.state == "trainable") then
			return slot.slot
		end
	end
	for _, slot in ipairs(slots) do
		if #slot.items > 0 then
			return slot.slot
		end
	end
end

function Render()
	local _, _, classID = UnitClass("player")
	slots = {}
	for _, slot in ipairs(ns.CraftedGear(UnitLevel("player"), classID)) do
		slots[slot.slot] = slot
	end
	professions = ns.PlayerProfessions()
	page.ShowAll:SetChecked(ns.ShowAllGear())
	if not slots[selectedSlot] then
		selectedSlot = DefaultSlot()
		selectedItemID = nil
	end
	RenderSlots()
	RenderDetail()
end

local SyncChecks

local function SelectPage()
	ns.HideRoute()
	-- Show the native page first so another custom page's CraftingPage hook can hand off cleanly.
	ProfessionsFrame.CraftingPage:Show()
	ProfessionsFrame.CraftingPage:Hide()
	ProfessionsFrame.BookPage:Hide()
	page:Show()
	SyncChecks()
end

-- Blizzard's own tabs show their page explicitly, which hands the window back.
local function Deselect()
	page:Hide()
	tab:SetChecked(false)
end
ns.HideGear = Deselect

-- Blizzard reselects its profession tab on skill updates; keep ours checked while our page shows.
function SyncChecks()
	local shown = page:IsShown()
	tab:SetChecked(shown)
	if shown then
		ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			professionTab:SetChecked(false)
		end
		if ns.RouteTab then
			ns.RouteTab:SetChecked(false)
		end
	end
end

-- Directly under the route tab, or under the last profession tab when that is off.
local function PlaceTab()
	local above = ProfessionsFrame.ProfessionsOverviewTab
	if ns.RouteTab and ns.RouteTab:IsShown() then
		above = ns.RouteTab
	else
		for _, professionTab in ipairs(ProfessionsFrame.rightProfessionTabs or {}) do
			if professionTab:IsShown() then
				above = professionTab
			end
		end
	end
	tab:ClearAllPoints()
	tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
end

-- The tab can be turned off in settings; an open page goes back to crafting.
local function RefreshTab()
	tab:SetShown(ns.db.showGearTab)
	PlaceTab()
	if not ns.db.showGearTab and page:IsShown() then
		Deselect()
		ProfessionsFrame.CraftingPage:Show()
	end
end

local function Refresh()
	RefreshTab()
	if page:IsShown() then
		Render()
	end
end

-- Shows the rows a character cannot make yet; off, the list holds what it can make now.
---@return CheckButton
local function CreateShowAll()
	local showAll = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate") --[[@as CheckButton]]
	showAll:SetScript("OnClick", function(self)
		ns.SetShowAllGear(self:GetChecked())
		Render()
	end)
	local label = showAll:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("RIGHT", showAll, "LEFT", -4, 0)
	label:SetText(L["Show gear I cannot make yet"])
	page.ShowAllLabel = label
	return showAll
end

---@param inset Frame
---@return SkillUpGearSlotButton
local function CreateSlotButton(inset, index)
	local button = CreateFrame("CheckButton", nil, inset) --[[@as SkillUpGearSlotButton]]
	button:SetSize(ICON, ICON)
	button.slot = index
	button.icon = button:CreateTexture(nil, "BORDER")
	button.icon:SetSize(ICON, ICON)
	button.icon:SetPoint("CENTER")
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetTexture("Interface\\Common\\WhiteIconFrame") -- art-ok: a square border in the ICON square
	button.border:SetSize(ICON, ICON)
	button.border:SetPoint("CENTER")
	-- The game's own check mark, as the professions window marks what it has.
	button.mark = button:CreateTexture(nil, "OVERLAY")
	button.mark:SetAtlas("checkmark-minimal", true)
	button.mark:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
	-- art-ok: the square button highlight over a square ICON button
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	-- The stock checked highlight, blended so the icon under it stays readable.
	button.select = button:CreateTexture(nil, "OVERLAY")
	button.select:SetTexture("Interface\\Buttons\\CheckButtonHilight") -- art-ok: square art over a square ICON button
	button.select:SetBlendMode("ADD")
	button.select:SetAllPoints()
	button:SetScript("OnClick", function()
		SelectSlot(index)
	end)
	button:SetScript("OnEnter", function(self)
		if self.item then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			ItemTooltip(self.item)(GameTooltip)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	return button
end

---@param inset Frame
local function CreateDoll(inset)
	page.Slots = {}
	for index = 1, #SLOT_NAMES do
		page.Slots[index] = CreateSlotButton(inset, index)
	end
	for position, index in ipairs(LEFT) do
		local button = page.Slots[index]
		if position == 1 then
			button:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
		else
			button:SetPoint("TOPLEFT", page.Slots[LEFT[position - 1]], "BOTTOMLEFT", 0, -SLOT_GAP)
		end
	end
	for position, index in ipairs(RIGHT) do
		local button = page.Slots[index]
		if position == 1 then
			button:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -10)
		else
			button:SetPoint("TOPRIGHT", page.Slots[RIGHT[position - 1]], "BOTTOMRIGHT", 0, -SLOT_GAP)
		end
	end
	for position, index in ipairs(BOTTOM) do
		local offset = (position - 2) * (ICON + SLOT_GAP)
		page.Slots[index]:SetPoint("BOTTOM", inset, "BOTTOM", offset, 12)
	end
end

---@param inset Frame
local function CreateDetail(inset)
	local detail = CreateFrame("Frame", nil, inset) --[[@as SkillUpGearDetail]]
	detail:SetPoint("TOPLEFT", inset, "TOPLEFT", 56, -10)
	detail:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -56, 59)
	page.Detail = detail

	local body = CreateFrame("Frame", nil, detail) --[[@as Frame]]
	body:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
	body:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
	detail.Body = body

	detail.Icon = body:CreateTexture(nil, "BORDER")
	detail.Icon:SetSize(47, 47)
	detail.Icon:SetPoint("TOPLEFT", 0, 0)
	detail.Border = body:CreateTexture(nil, "OVERLAY")
	detail.Border:SetTexture("Interface\\Common\\WhiteIconFrame") -- art-ok: a square border in the 47 square
	detail.Border:SetSize(47, 47)
	detail.Border:SetPoint("TOPLEFT", detail.Icon, "TOPLEFT", 0, 0)

	detail.Name = body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	detail.Name:SetJustifyH("LEFT")
	detail.Name:SetPoint("TOPLEFT", detail.Icon, "TOPRIGHT", 10, -2)
	detail.Name:SetPoint("RIGHT", body, "RIGHT", -8, 0)

	detail.Requirement = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Requirement:SetJustifyH("LEFT")
	detail.Requirement:SetPoint("TOPLEFT", detail.Name, "BOTTOMLEFT", 0, -2)
	detail.Requirement:SetPoint("RIGHT", body, "RIGHT", -8, 0)

	detail.Learn = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Learn:SetJustifyH("LEFT")
	detail.Learn:SetPoint("TOPLEFT", detail.Requirement, "BOTTOMLEFT", 0, -2)
	detail.Learn:SetPoint("RIGHT", body, "RIGHT", -8, 0)

	detail.State = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	detail.State:SetJustifyH("LEFT")
	detail.State:SetPoint("TOPLEFT", detail.Learn, "BOTTOMLEFT", 0, -2)
	detail.State:SetPoint("RIGHT", body, "RIGHT", -8, 0)

	detail.Reagents = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Reagents:SetJustifyH("LEFT")
	detail.Reagents:SetPoint("TOPLEFT", detail.State, "BOTTOMLEFT", 0, -12)
	detail.Reagents:SetText(L["Reagents"])
	detail.ReagentRows = {}

	detail.Action = CreateFrame("Button", nil, body, "SharedButtonSmallTemplate") --[[@as SkillUpGearAction]]
	detail.Action:SetSize(130, 22)
	detail.Action:SetScript("OnClick", function(self)
		if self.click then
			self.click()
		end
	end)
	detail.Action:SetMotionScriptsWhileDisabled(true)
	detail.Action:SetScript("OnEnter", function(self)
		if self.reason then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip_SetTitle(GameTooltip, self.reason)
			GameTooltip:Show()
		end
	end)
	detail.Action:SetScript("OnLeave", GameTooltip_Hide)

	detail.Also = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Also:SetJustifyH("LEFT")
	detail.Also:SetText(L["Also for this slot"])
	detail.OtherRows = {}

	detail.Empty = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	detail.Empty:SetJustifyH("LEFT")
	detail.Empty:SetWordWrap(true)
	detail.Empty:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
	detail.Empty:SetPoint("RIGHT", detail, "RIGHT", 0, 0)
	return detail
end

local function CreatePage()
	page = CreateFrame("Frame", nil, ProfessionsFrame) --[[@as SkillUpGearPage]]
	page:SetAllPoints(ProfessionsFrame.CraftingPage)
	page:SetFrameLevel(ProfessionsFrame.CraftingPage:GetFrameLevel())
	-- What's Training? paints its own page at the portrait container's level, over CraftingPage's, and never
	-- hides it when another tab is chosen. HIGH sits above that page and below dialogs, so this one keeps the
	-- clicks while both are open.
	page:SetFrameStrata("HIGH")
	page:Hide()
	-- The inset's own heading is the page title, so it sits under the window's title bar and portrait.
	local inset = CreateFrame("Frame", nil, page, "InsetFrameTemplate") --[[@as Frame]]
	local title = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 4, 4)
	title:SetText(L["Crafted gear"])
	inset:SetPoint("TOPLEFT", 16, -88)
	inset:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 44)
	page.ShowAll = CreateShowAll()
	page.ShowAll:SetPoint("BOTTOMRIGHT", inset, "TOPRIGHT", 0, 8)
	CreateDoll(inset)
	CreateDetail(inset)
	page:SetScript("OnShow", Render)
end

local function CreateTab()
	tab = CreateFrame("Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate") --[[@as SkillUpSideTab]]
	-- art-ok: a square icon in the square LargeSideTabButtonTemplate sizes for it
	tab.Icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_05")
	tab:SetFillToInterior(true)
	tab.tooltipText = L["Crafted gear"]
	tab:EnableMouse(true)
	tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
		if button == "LeftButton" and upInside then
			SelectPage()
		end
	end)
	PlaceTab()
	RefreshTab()
	ns.GearTab = tab
	ns.PlaceGearTab = PlaceTab
	ProfessionsFrame:HookScript("OnShow", PlaceTab)
	page:HookScript("OnShow", SyncChecks)
end

function ns.AttachGear()
	CreatePage()
	CreateTab()
	ProfessionsFrame.CraftingPage:HookScript("OnShow", Deselect)
	ProfessionsFrame.BookPage:HookScript("OnShow", Deselect)
	-- A reopened window starts on the crafting page, as Blizzard expects.
	ProfessionsFrame:HookScript("OnHide", function()
		if page:IsShown() then
			Deselect()
			ProfessionsFrame.CraftingPage:Show()
		end
	end)
	ns.WhenStale("gear", Refresh)
end
