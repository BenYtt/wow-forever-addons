local _, ns = ...
-- luacheck: globals UIDropDownMenu_AddButton UIDropDownMenu_CreateInfo UIDropDownMenu_Initialize
-- luacheck: globals UIDropDownMenu_SetSelectedValue UIDropDownMenu_SetWidth

-- The settings page every Forever addon draws, and only the page. Field Guide and Hoard each hand-rolled the same
-- CheckButton (the template, a label font string, a tooltip) and the same RegisterCanvasLayoutCategory pair, and the
-- five older addons carry five hand-edited copies of it. This file is that chrome once: a panel with a title, rows that
-- stack down it, and the category registration. It holds no addon's options -- which rows exist, what they read and
-- write, and every phrase are the addon's, passed in here. Boundaries §5 keeps each addon's settings page its own; only
-- the drawing is shared.

local Page = {}
ns.SettingsPage = Page

-- A phrase through the addon's own table, English when it has no translation for it (an addon's L is either a
-- metatable that answers the key or a plain table, and both read the same way here).
---@param phrase string
---@return string
local function Text(phrase)
	local translated = ns.L and ns.L[phrase]
	return translated or phrase
end

-- How far down the panel the next row goes, and how much room each kind of row takes. A canvas has no layout engine, so
-- the page keeps one cursor and every row claims its height.
local TITLE = 16
local CHECK, SLIDER, DROPDOWN, BUTTON = 28, 56, 52, 36

---@param panel Frame
---@param height integer
---@return integer
local function Next(panel, height)
	-- The first row starts below the title; every row after it starts below the one before.
	local y = panel.settingsRowY or -(TITLE + 32)
	panel.settingsRowY = y - height
	return y
end

-- Register `build` as the addon's settings page under the category `name` (a phrase, read through ns.L).
-- `build` is called once with the panel and this table, and adds the addon's own rows through AddCheck and the rest.
-- Returns the category and the panel, or nil on a client with no Settings API, where the addon keeps its options off
-- the interface rather than erroring on load.
---@param name string
---@param build fun(panel: Frame, page: table)
---@return table?, Frame?
function Page.Register(name, build)
	if not Settings or not Settings.RegisterCanvasLayoutCategory then
		return nil
	end
	local panel = CreateFrame("Frame")
	panel.name = Text(name)
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontLarge")
	title:SetPoint("TOPLEFT", 16, -TITLE)
	title:SetText(Text(name))
	panel.title = title
	build(panel, Page)
	local category = Settings.RegisterCanvasLayoutCategory(panel, Text(name))
	Settings.RegisterAddOnCategory(category)
	panel.category = category
	return category, panel
end

-- A tick box that reads `get()` when it is drawn and writes `set(checked)` when the player changes it. The setter is
-- where an addon refreshes whatever the setting affects; this file never calls back into the addon.
---@param panel Frame
---@param label string a phrase, read through ns.L
---@param get fun(): boolean?
---@param set fun(checked: boolean)
---@param tooltip? string a phrase, read through ns.L
---@return CheckButton
function Page.AddCheck(panel, label, get, set, tooltip)
	local check = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
	check:SetPoint("TOPLEFT", 16, Next(panel, CHECK))
	check:SetChecked(get() == true)
	local text = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetText(Text(label))
	if tooltip then
		check.tooltipText = Text(tooltip)
	end
	check:SetScript("OnClick", function(self)
		set(self:GetChecked() == true)
	end)
	return check
end

-- A slider with its own label above it; `get()` is the saved value, `set(value)` writes it.
---@param panel Frame
---@param label string a phrase, read through ns.L
---@param get fun(): number?
---@param set fun(value: number)
---@param minimum number
---@param maximum number
---@param step? number
---@param tooltip? string a phrase, read through ns.L
---@return Slider
function Page.AddSlider(panel, label, get, set, minimum, maximum, step, tooltip)
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("TOPLEFT", 16, Next(panel, SLIDER))
	text:SetText(Text(label))
	local slider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -8)
	slider:SetWidth(240)
	slider:SetMinMaxValues(minimum, maximum)
	slider:SetValueStep(step or 1)
	slider:SetObeyStepOnDrag(true)
	slider:SetValue(get() or minimum)
	if tooltip then
		slider.tooltipText = Text(tooltip)
	end
	slider:SetScript("OnValueChanged", function(_, value)
		set(value)
	end)
	return slider
end

-- A dropdown of `choices`, each `{ value, phrase }`, in order. The phrase is read through ns.L; the value is what the
-- addon saves, so a translated label never changes a saved setting.
---@param panel Frame
---@param label string a phrase, read through ns.L
---@param get fun(): string?
---@param set fun(value: string)
---@param choices table[] { value, phrase } pairs
---@param tooltip? string a phrase, read through ns.L
---@return Frame
function Page.AddDropdown(panel, label, get, set, choices, tooltip)
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("TOPLEFT", 16, Next(panel, DROPDOWN))
	text:SetText(Text(label))
	local dropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
	dropdown:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -16, -4)
	UIDropDownMenu_SetWidth(dropdown, 180)
	UIDropDownMenu_SetSelectedValue(dropdown, get())
	UIDropDownMenu_Initialize(dropdown, function(_, level)
		for _, choice in ipairs(choices) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = Text(choice[2])
			info.value = choice[1]
			info.func = function()
				set(choice[1])
				UIDropDownMenu_SetSelectedValue(dropdown, choice[1])
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)
	if tooltip then
		dropdown.tooltipText = Text(tooltip)
	end
	return dropdown
end

-- A button that runs `callback`; the addon does whatever it does behind it.
---@param panel Frame
---@param label string a phrase, read through ns.L
---@param callback fun()
---@param tooltip? string a phrase, read through ns.L
---@return Button
function Page.AddButton(panel, label, callback, tooltip)
	local button = CreateFrame("Button", nil, panel, "SharedButtonSmallTemplate")
	button:SetSize(180, 24)
	button:SetPoint("TOPLEFT", 16, Next(panel, BUTTON))
	button:SetText(Text(label))
	button:SetScript("OnClick", callback)
	if tooltip then
		button.tooltipText = Text(tooltip)
	end
	return button --[[@as Button]]
end
