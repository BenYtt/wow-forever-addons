---@type string, SkillUpNamespace
local addonName, ns = ...
local L = ns.L
local ICON = "Interface\\AddOns\\" .. addonName .. "\\media\\Icon"
local frame, body, scroll, copyWindow, copyEdit, shown, footer, summary

local function Name(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		C_Item.RequestLoadItemDataByID(itemID)
		return string.format(L["item %d"], itemID)
	end
	return name
end

local function Copy(text)
	if not copyWindow then
		copyWindow = CreateFrame("Frame", addonName .. "ShoppingCopy", UIParent, "PortraitFrameTemplate")
		table.insert(UISpecialFrames, addonName .. "ShoppingCopy")
		copyWindow:SetSize(460, 380)
		copyWindow:SetPoint("CENTER")
		copyWindow:SetFrameStrata("DIALOG")
		copyWindow:SetToplevel(true)
		copyWindow:SetClampedToScreen(true)
		copyWindow:SetMovable(true)
		copyWindow:EnableMouse(true)
		copyWindow:RegisterForDrag("LeftButton")
		copyWindow:SetScript("OnDragStart", copyWindow.StartMoving)
		copyWindow:SetScript("OnDragStop", copyWindow.StopMovingOrSizing)
		copyWindow:SetTitle(L["Shopping list"])
		ns.Art.Icon(copyWindow:GetPortrait(), ICON, 62)
		local hint = copyWindow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		hint:SetPoint("TOPLEFT", 70, -32)
		hint:SetPoint("RIGHT", -16, 0)
		hint:SetJustifyH("LEFT")
		hint:SetText(L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it."])
		local inset = CreateFrame("Frame", nil, copyWindow, "InsetFrameTemplate")
		inset:SetPoint("TOPLEFT", 10, -64)
		inset:SetPoint("BOTTOMRIGHT", -10, 10)
		local sf = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 8, -8)
		sf:SetPoint("BOTTOMRIGHT", -28, 8)
		copyEdit = CreateFrame("EditBox", nil, sf)
		copyEdit:SetMultiLine(true)
		copyEdit:SetAutoFocus(false)
		copyEdit:SetFontObject("ChatFontNormal")
		copyEdit:SetWidth(390)
		copyEdit:SetMaxLetters(0)
		copyEdit:SetScript("OnTextChanged", function(self, userInput)
			if userInput then
				self:SetText(shown)
				self:SetFocus()
				self:HighlightText()
			end
		end)
		copyEdit:SetScript("OnEditFocusGained", copyEdit.HighlightText)
		copyEdit:SetScript("OnEscapePressed", function()
			copyWindow:Hide()
		end)
		sf:SetScrollChild(copyEdit)
	end
	shown = text
	copyEdit:SetText(text)
	copyWindow:Show()
	copyEdit:SetFocus()
	copyEdit:HighlightText()
end

local function Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	for _, child in ipairs({ body:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	local lists = ns.ShoppingList()
	-- The window groups by source, not profession, so the header names every plan it is buying for.
	local plans = {}
	for _, list in ipairs(lists) do
		plans[#plans + 1] = string.format(L["%s to %d"], list.profession, list.target)
	end
	summary:SetText(#plans > 0 and string.format(L["Buying for %s"], table.concat(plans, ", ")) or "")
	local top, any, total, unpriced = -10, false, 0, 0
	local headings =
		{ gather = L["Gather"], vendor = L["Vendor"], auction = L["Auction house"], unknown = L["Unknown"] }
	for _, source in ipairs(ns.Model.SHOPPING_SOURCES) do
		local rows = {}
		for _, list in ipairs(lists) do
			for _, row in ipairs(list.items) do
				if row.source == source and row.missing > 0 then
					rows[#rows + 1] = { list = list, row = row }
				end
			end
		end
		if #rows > 0 then
			any = true
			local heading = body:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			heading:SetPoint("TOPLEFT", 8, top)
			heading:SetText(headings[source])
			top = top - 28
			for _, entry in ipairs(rows) do
				local row = entry.row
				local item = CreateFrame("Frame", nil, body)
				item:SetPoint("TOPLEFT", 8, top)
				item:SetSize(520, 48)
				local icon = item:CreateTexture(nil, "ARTWORK")
				icon:SetSize(32, 32)
				icon:SetPoint("LEFT", 0, 0)
				local texture = C_Item.GetItemIconByID(row.itemID)
				if texture then
					icon:SetTexture(texture) -- art-ok: square item icons keep their native aspect.
				end
				local name = item:CreateFontString(nil, "ARTWORK", "GameFontNormal")
				name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
				name:SetWidth(460)
				name:SetText(
					string.format(L["%s (%s to %d)"], Name(row.itemID), entry.list.profession, entry.list.target)
				)
				local alt = row.alt[1] and string.format(L["on %s"], row.alt[1].name) or ""
				local unit = row.price and ns.FormatNet(ns.Model.RoundMoney(row.price), false) or L["price unknown"]
				local cost = row.cost and ns.FormatNet(ns.Model.RoundMoney(row.cost), false) or "-"
				local detail = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
				detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 0)
				detail:SetWidth(460)
				detail:SetHeight(28)
				detail:SetWordWrap(true)
				detail:SetText(
					string.format(
						L["Need %d, have %d, missing %d  %s  %s each  %s"],
						row.need,
						row.have,
						row.missing,
						alt,
						unit,
						cost
					)
				)
				if row.cost then
					total = total + row.cost
				elseif row.missing > 0 then
					unpriced = unpriced + 1
				end
				top = top - 50
			end
		end
	end
	if not any then
		local empty = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		empty:SetPoint("CENTER")
		empty:SetText(#lists == 0 and L["No tracked profession"] or L["Nothing to buy"])
	end
	body:SetHeight(math.max(1, -top + 20))
	footer:SetText(
		L["Total for priced items: "]
			.. ns.FormatNet(ns.Model.RoundMoney(total), false)
			.. (unpriced > 0 and string.format(L["  %d items have no price yet"], unpriced) or "")
	)
end

local function Create()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", addonName .. "ShoppingList", UIParent, "PortraitFrameTemplate")
	table.insert(UISpecialFrames, addonName .. "ShoppingList")
	frame:SetSize(620, 500)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Shopping list"])
	ns.Art.Icon(frame:GetPortrait(), ICON, 62)
	-- Clear of the portrait, which overhangs the top-left corner, and above the list.
	summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", 82, -36)
	summary:SetPoint("RIGHT", -16, 0)
	summary:SetJustifyH("LEFT")
	summary:SetHeight(28)
	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -70)
	inset:SetPoint("BOTTOMRIGHT", -10, 48)
	scroll = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	body = CreateFrame("Frame", nil, scroll)
	body:SetWidth(550)
	scroll:SetScrollChild(body)
	footer = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	footer:SetPoint("BOTTOMRIGHT", -16, 18)
	footer:SetJustifyH("RIGHT")
	footer:SetWidth(330)
	footer:SetHeight(30)
	footer:SetWordWrap(true)
	local copy = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	copy:SetSize(110, 24)
	copy:SetPoint("BOTTOMLEFT", 16, 14)
	copy:SetText(L["Copy list"])
	copy:SetScript("OnClick", function()
		Copy(ns.ShoppingText())
	end)
	local trip = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	trip:SetSize(130, 24)
	trip:SetPoint("LEFT", copy, "RIGHT", 8, 0)
	trip:SetText(L["Plan buy trip"])
	local api = ShortestPathForever and ShortestPathForever.API
	trip:SetEnabled(api and type(api.NavigateRoute) == "function")
	trip:SetScript("OnClick", function()
		ns.ShoppingTrip()
	end)
	trip:SetScript("OnEnter", function(self)
		if not self:IsEnabled() then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip_SetTitle(GameTooltip, L["A buy trip needs Shortest Path Forever."])
			GameTooltip:Show()
		end
	end)
	trip:SetScript("OnLeave", GameTooltip_Hide)
	frame:SetScript("OnShow", Refresh)
	frame:Hide()
	return frame
end

local ready, enteredWorld, variablesLoaded, pendingOpen = false, false, false, false
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("VARIABLES_LOADED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		enteredWorld = true
	else
		variablesLoaded = true
	end
	if not (enteredWorld and variablesLoaded) or ready then
		return
	end
	ready = true
	C_Timer.After(0, function()
		Create()
		if pendingOpen then
			frame:Show()
			Refresh()
			pendingOpen = false
		end
	end)
end)

function ns.OpenShoppingList()
	if not ready then
		pendingOpen = true
		return
	end
	Create():Show()
	Refresh()
end
ns.WhenStale("shoppingList", Refresh)
