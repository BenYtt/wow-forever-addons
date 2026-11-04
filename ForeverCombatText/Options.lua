-- Copyright (c) 2026 Morpster. All rights reserved. See LICENSE.txt.
local addonName, addon = ...
local panel
local damageColorPopup

local function addonVersion()
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		return C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
	end
	return GetAddOnMetadata(addonName, "Version") or "?"
end

local function label(parent, text, x, y, width)
	local region = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	region:SetPoint("TOPLEFT", x, y)
	region:SetWidth(width or 380)
	region:SetJustifyH("LEFT")
	region:SetText(text)
	return region
end

local function button(parent, text, x, y, callback)
	local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	control:SetSize(180, 26)
	control:SetPoint("TOPLEFT", x, y)
	control:SetText(text)
	control:SetScript("OnClick", callback)
	return control
end

local function checkbox(parent, text, key, y)
	local control = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	control:SetPoint("TOPLEFT", 20, y)
	label(parent, text, 56, y - 8)
	control:SetScript("OnShow", function(self)
		self:SetChecked(addon.db[key])
	end)
	control:SetScript("OnClick", function(self)
		addon.db[key] = self:GetChecked() and true or false
		addon:Clear()
		addon:UpdateBlizzardDamage()
		addon:UpdateBlizzardHealing()
		addon:RefreshNameplates()
	end)
end

local function visibilityCheckbox(parent, text, key, y)
	local control = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	control:SetPoint("TOPLEFT", 20, y)
	label(parent, text, 56, y - 8)
	control:SetScript("OnShow", function(self)
		self:SetChecked(addon.db[key])
	end)
	control:SetScript("OnClick", function(self)
		addon.db[key] = self:GetChecked() and true or false
		addon:ApplyFriendlyVisibility()
		addon:UpdateCityPlates()
		addon:UpdateBlizzardHealing()
	end)
end

local function chooseColor(read, write, refresh)
	local original = read()
	local r, g, b = original[1], original[2], original[3]
	local function setColor(red, green, blue)
		write({ red, green, blue })
		if refresh then
			refresh()
		end
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = r,
		g = g,
		b = b,
		hasOpacity = false,
		swatchFunc = function()
			local red, green, blue = ColorPickerFrame:GetColorRGB()
			setColor(red, green, blue)
		end,
		cancelFunc = function()
			setColor(r, g, b)
		end,
	})
end

local function chooseSettingColor(key)
	chooseColor(function()
		return addon.db[key]
	end, function(color)
		addon.db[key] = color
	end)
end

local function colorButton(parent, text, x, y, read, write)
	local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	control:SetSize(176, 24)
	control:SetPoint("TOPLEFT", x, y)
	control:SetText(text)
	local swatch = control:CreateTexture(nil, "ARTWORK")
	swatch:SetSize(14, 14)
	swatch:SetPoint("RIGHT", control, "RIGHT", -7, 0)
	local textRegion = control:GetFontString()
	textRegion:ClearAllPoints()
	textRegion:SetPoint("LEFT", control, "LEFT", 8, 0)
	textRegion:SetPoint("RIGHT", swatch, "LEFT", -5, 0)
	textRegion:SetJustifyH("LEFT")
	local function refresh()
		local color = read()
		swatch:SetColorTexture(color[1], color[2], color[3])
	end
	control:SetScript("OnClick", function()
		chooseColor(read, write, refresh)
	end)
	refresh()
	return control, refresh
end

local function createDamageColorPopup(anchor)
	local popup = CreateFrame("Frame", nil, UIParent, "UIPanelDialogTemplate")
	popup:SetSize(390, 250)
	popup:SetFrameStrata("DIALOG")
	popup:SetClampedToScreen(true)
	popup:EnableMouse(true)
	popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
	label(popup, "Customize damage colors", 16, -32, 350)

	local refreshers = {}
	for index, school in ipairs(addon.damageSchoolOptions) do
		local key, schoolLabel = school.key, school.label
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local _, refresh = colorButton(popup, schoolLabel, 12 + column * 184, -58 - row * 28, function()
			return addon:GetDamageColor(key)
		end, function(color)
			addon:SetDamageColor(key, color)
		end)
		refreshers[#refreshers + 1] = refresh
	end

	local _, refreshFallback = colorButton(popup, "Fallback", 12, -174, function()
		return addon:GetDamageColor("fallback")
	end, function(color)
		addon:SetDamageColor("fallback", color)
	end)
	refreshers[#refreshers + 1] = refreshFallback

	local reset = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	reset:SetSize(176, 24)
	reset:SetPoint("TOPLEFT", 12, -210)
	reset:SetText("Reset damage colors")
	reset:SetScript("OnClick", function()
		addon:ResetDamageColors()
		for _, refresh in ipairs(refreshers) do
			refresh()
		end
	end)
	local close = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	close:SetSize(176, 24)
	close:SetPoint("TOPLEFT", 196, -210)
	close:SetText("Close")
	close:SetScript("OnClick", function()
		popup:Hide()
	end)
	popup:Hide()
	return popup
end

local function sliderRow(parent, text, y, read, write, minValue, maxValue, step, format)
	local rowLabel = label(parent, "", 24, y)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 24, y - 24)
	slider:SetSize(380, 16)
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	local function refresh()
		rowLabel:SetText(text .. ": " .. (format or tostring)(read()))
	end
	slider:SetScript("OnValueChanged", function(_, value)
		write(value)
		refresh()
	end)
	slider:SetScript("OnShow", function(self)
		self:SetValue(read())
		refresh()
	end)
	return slider
end

local function offsetSlider(parent, text, key, y)
	sliderRow(parent, text, y, function()
		return addon:GetDisplayedOffset(key)
	end, function(value)
		addon:SetDisplayedOffset(key, math.floor(value + 0.5))
	end, -30, 70, 1)
end

local function durationSlider(parent, text, y)
	sliderRow(
		parent,
		text,
		y,
		function()
			return addon.db.duration
		end,
		function(value)
			addon.db.duration = value
		end,
		0.6,
		3,
		0.1,
		function(value)
			return string.format("%.1fs", value)
		end
	)
end

local function createPanel()
	panel = CreateFrame("Frame", "ForeverCombatTextOptions", UIParent)
	panel:SetSize(460, 580)
	local categoryPanel = panel
	local scroll = CreateFrame("ScrollFrame", nil, categoryPanel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", -30, 8)
	scroll:SetClipsChildren(true)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(460, 1400)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(self, width)
		if width > 0 then
			content:SetWidth(width)
		end
	end)
	label(content, "Forever Combat Text — " .. addonVersion(), 24, -22, 410)
	checkbox(content, "Enable floating combat text", "enabled", -54)
	checkbox(content, "Enable Forever Combat Text numbers", "addonNumbers", -90)
	checkbox(content, "Show damage on enemy nameplates", "damage", -126)
	checkbox(content, "Show healing on friendly nameplates (all sources)", "healing", -162)
	checkbox(content, "Color damage by school (Fire, Frost, etc.)", "schoolColors", -198)
	checkbox(content, "Hide Blizzard outgoing damage numbers", "hideBlizzardDamage", -234)
	checkbox(content, "Show Blizzard damage when enemy plates are off", "blizzardWhenPlatesOff", -270)
	checkbox(content, "Show miss, dodge, parry and block text", "showOutcomes", -306)

	label(content, "Outcome text language", 24, -348)
	label(content, "Only used for miss, dodge, parry, block and the other outcome words.", 24, -368)
	local outcomeLocaleDropdown =
		CreateFrame("Frame", "ForeverCombatTextOutcomeLocale", content, "UIDropDownMenuTemplate")
	outcomeLocaleDropdown:SetPoint("TOPLEFT", 24, -392)
	-- the open list lives in its own frame, so it needs to outrank the Settings
	-- canvas panel or it renders behind the options window
	UIDropDownMenu_SetFrameStrata(outcomeLocaleDropdown, "HIGH")
	UIDropDownMenu_SetWidth(outcomeLocaleDropdown, 240)
	local function refreshOutcomeLocale()
		local key = addon.db.outcomeLocale or "client"
		local data = addon.outcomeLocaleData[key] or addon.outcomeLocaleData.client
		UIDropDownMenu_SetText(outcomeLocaleDropdown, data.name)
	end
	local function selectOutcomeLocale(_, key)
		addon.db.outcomeLocale = key
		refreshOutcomeLocale()
		CloseDropDownMenus()
	end
	UIDropDownMenu_Initialize(outcomeLocaleDropdown, function()
		local current = addon.db.outcomeLocale or "client"
		for _, key in ipairs(addon.outcomeLocaleOrder) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = addon.outcomeLocaleData[key].name
			info.value = key
			info.arg1 = key
			info.func = selectOutcomeLocale
			info.checked = key == current
			UIDropDownMenu_AddButton(info)
		end
	end)
	outcomeLocaleDropdown:SetScript("OnShow", refreshOutcomeLocale)

	local scope
	scope = button(content, "", 24, -426, function()
		addon.db.scope = addon.db.scope == "target" and "combat" or "target"
		scope:SetText(addon.db.scope == "target" and "Damage: current target" or "Damage: all enemy plates")
		addon:Clear()
	end)
	scope:SetScript("OnShow", function(self)
		self:SetText(addon.db.scope == "target" and "Damage: current target" or "Damage: all enemy plates")
	end)
	button(content, "Reset settings", 232, -426, function()
		addon:ResetSettings()
		if damageColorPopup then
			damageColorPopup:Hide()
		end
		content:Hide()
		content:Show()
	end)
	label(content, "Sources: Everyone (combined)", 24, -463)
	local customizeDamageColors = button(content, "Customize damage colors...", 24, -494, function()
		if damageColorPopup:IsShown() then
			damageColorPopup:Hide()
		else
			damageColorPopup:Show()
		end
	end)
	damageColorPopup = createDamageColorPopup(customizeDamageColors)
	button(content, "Healing color", 232, -494, function()
		chooseSettingColor("healingColor")
	end)
	button(content, "Outcome text color", 24, -526, function()
		chooseSettingColor("outcomeColor")
	end)
	sliderRow(content, "Text size", -562, function()
		local size = tonumber(addon.db.fontSize) or 22
		return math.max(12, math.min(60, size))
	end, function(value)
		addon.db.fontSize = math.max(12, math.min(60, math.floor(value + 0.5)))
	end, 12, 60, 1)
	label(content, "Text font", 24, -622)
	local fontDropdown = CreateFrame("Frame", "ForeverCombatTextFont", content, "UIDropDownMenuTemplate")
	fontDropdown:SetPoint("TOPLEFT", 18, -636)
	UIDropDownMenu_SetFrameStrata(fontDropdown, "HIGH")
	UIDropDownMenu_SetWidth(fontDropdown, 240)
	local function refreshFont()
		local current = addon.db.fontFace or "default"
		local selected = addon.fontOptions[1]
		for _, choice in ipairs(addon.fontOptions) do
			if choice.key == current then
				selected = choice
				break
			end
		end
		UIDropDownMenu_SetText(fontDropdown, selected.label)
	end
	local function selectFont(_, key)
		addon.db.fontFace = key
		refreshFont()
		CloseDropDownMenus()
	end
	UIDropDownMenu_Initialize(fontDropdown, function()
		local current = addon.db.fontFace or "default"
		for _, choice in ipairs(addon.fontOptions) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = choice.label
			info.value = choice.key
			info.arg1 = choice.key
			info.func = selectFont
			info.checked = choice.key == current
			UIDropDownMenu_AddButton(info)
		end
	end)
	fontDropdown:SetScript("OnShow", refreshFont)
	content:SetScript("OnShow", function()
		refreshOutcomeLocale()
		refreshFont()
	end)
	button(content, "Preview nameplate", 24, -682, function()
		addon:Preview()
	end)
	button(content, "Event status", 232, -682, function()
		addon:Status()
	end)
	offsetSlider(content, "Nameplate damage offset", "damagePlateOffset", -718)
	offsetSlider(content, "Nameplate healing offset", "healingPlateOffset", -778)
	durationSlider(content, "Label duration", -838)
	checkbox(content, "Show elite/rare icons on enemy nameplates", "eliteIcons", -896)
	checkbox(content, "Enable Blizzard outgoing healing in instances", "blizzardInstanceHealing", -932)
	checkbox(content, "Show Blizzard healing when friendly plates are off", "blizzardHealingWhenPlatesOff", -968)
	visibilityCheckbox(content, "Show friendly NPC nameplates", "npcPlates", -1004)
	visibilityCheckbox(content, "Show friendly minion nameplates", "minionPlates", -1040)
	visibilityCheckbox(content, "Disable friendly nameplates in cities", "hideFriendlyInCities", -1076)
	local note = label(
		content,
		"Addon healing includes all healers and requires an accessible friendly nameplate. Healing received by you stays with Blizzard. Friendly NPCs and minions automatically follow Blizzard's Only Show Names setting: their names keep reaction colors while bars, cast bars, auras and level indicators are hidden (experimental — turn off Blizzard's setting to restore full plates). The clickable bar region is unchanged. NPC and minion plates also follow the master Show Friendly toggle, and can be switched off individually above. When all friendly plates are off, Blizzard healing numbers take over if enabled. The cities option turns all friendly nameplates off while you are resting (capitals, towns, inns) and restores your previous settings when you leave. Forbidden plates cannot be styled. Native instance healing enables Blizzard's outgoing numbers in dungeons/raids and restores your previous setting afterwards; beta coverage needs in-game testing.",
		24,
		-1126,
		410
	)
	note:SetFontObject("GameFontHighlightSmall")
	note:SetSpacing(3)
	panel:SetScript("OnHide", function()
		if damageColorPopup then
			damageColorPopup:Hide()
		end
	end)
	categoryPanel:Hide()
	addon.category = Settings.RegisterCanvasLayoutCategory(categoryPanel, "Forever Combat Text")
	Settings.RegisterAddOnCategory(addon.category)
end

function addon:InitializeOptions()
	if not panel then
		createPanel()
	end
end

SLASH_FOREVERCOMBATTEXT1 = "/fct"
SLASH_FOREVERCOMBATTEXT2 = "/forevertext"
SlashCmdList.FOREVERCOMBATTEXT = function(message)
	local command = message:lower():match("^%s*(%S+)")
	if command == "preview" then
		addon:Preview()
	elseif command == "status" then
		addon:Status()
	elseif command == "report" then
		addon:Report()
	elseif command == "watch" then
		local seconds = tonumber(message:match("(%d+)")) or 30
		addon.watchUntil = GetTime() + seconds
		addon.watchCount = 0
		addon:Print(
			"Watching CVar changes for "
				.. seconds
				.. "s: press your nameplate keybind a few times, then run /fct report."
		)
	elseif command == "on" or command == "off" then
		addon.db.enabled = command == "on"
		addon:Clear()
		addon:UpdateBlizzardDamage()
		addon:UpdateBlizzardHealing()
		addon:RefreshNameplates()
		addon:Print(addon.db.enabled and "Floating text enabled." or "Floating text disabled.")
	elseif command == "help" then
		addon:Print(
			"/fct — options; /fct preview — sample numbers; /fct status — diagnostics; /fct report — session report; /fct watch [secs] — log CVar changes; /fct on or off."
		)
	else
		if not panel then
			createPanel()
		end
		Settings.OpenToCategory(addon.category:GetID())
	end
end
