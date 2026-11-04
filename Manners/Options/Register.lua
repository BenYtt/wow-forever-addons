-- Manners -- options: the model put together from its tabs and registered
-- with AceConfig, the entry in the game's Settings window, and the calls the
-- rest of the addon opens, shuts and repaints the options window with.
--
-- The window itself is Options/Window/*.lua. AceConfigDialog stays as the
-- safety net: if the window ever fails to build or show, the old dialog opens
-- on the same definitions, so nobody is left without their settings.

local ADDON, ns = ...
local L = ns.L
local Page = ns.OptionsPage

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Asked for optionally. It ships inside AceConfig-3.0 and will be there, but
-- the only thing that depends on it is the fallback dialog repainting itself
-- -- and a missing library must not take the options screen with it.
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

-- The page is a setup flow: Start here takes a new player from nothing to a
-- prompt on a key, and every other tab is for fine-tuning, in the order a
-- player thinks about it. Profiles is added last by SetupOptions.
local function BuildOptions()
	return {
		type = "group",
		name = "Manners",
		childGroups = "tab",
		args = {
			general = Page.BuildStartTab(),
			who = Page.BuildWhoTab(),
			when = Page.BuildWhenTab(),
			click = Page.BuildSpeechTab(),
			appearance = Page.BuildLookTab(),
			advanced = Page.BuildAdvancedTab(),
			diagnostics = Page.BuildDiagnosticsTab(),
		},
	}
end

-- For the fallback dialog only; the window measures its own rows.
--
-- Buttons and dropdowns sized to their words. AceConfigDialog gives a control
-- 170 pixels unless told otherwise. AceGUI keeps 15 of them clear either side
-- of a button's label, so "Put these back to default" was cut to "Put these
-- back to de..."; a dropdown's text gets 36 fewer than the control, so "Above
-- the action bars (default)" showed as "Above the action bars (d...". The
-- German for most of these runs a third longer. Every button and dropdown
-- without a width of its own is measured when the options are built and again
-- each time they are opened -- a button against the label it shows then, a
-- dropdown against the longest of its choices -- in the font each draws with,
-- and widened in quarter steps, never below the default, so short controls
-- keep the rows' rhythm.
--
-- The width is written as a plain number. AceConfigDialog would read a
-- function there, but AceConfigRegistry's validator, which runs the first
-- time the page opens, accepts only a string or a number: 1.1.2 to 1.4.0 put
-- a function in and the options would not open at all ("width: expected a
-- string or number"). tests/scenarios/aceconfig.lua now runs that validator.
--
-- Sliders and key bindings are measured too, against their label. It is one
-- line across the top of the control, cut with an ellipsis at its edge: "Top
-- up when less than this is left (minutes)" lost its unit, which was then only
-- in the tooltip. A slider's label draws in GameFontNormal, a key binding's in
-- GameFontHighlight.
local CONTROL_UNIT = 170
local BUTTON_PAD = 30 + 6
local SELECT_PAD = 36 + 6
local measureText

-- How wide `label` is in `font`, or nil when the client will not say.
local function LabelWidth(label, font)
	if type(label) ~= "string" or label == "" then return nil end
	if not measureText then
		measureText = UIParent:CreateFontString(nil, "ARTWORK")
		if not measureText then return nil end
		measureText:Hide()
	end
	if measureText.SetFontObject and _G[font] then measureText:SetFontObject(_G[font]) end
	measureText:SetText(label)
	local measure = measureText.GetUnboundedStringWidth or measureText.GetStringWidth
	local ok, w = pcall(measure, measureText)
	w = ok and ns.plain(w) or nil
	return type(w) == "number" and w or nil
end

local function ControlWidth(w, pad)
	if not w then return nil end
	local units = math.ceil((w + pad) / CONTROL_UNIT * 4) / 4
	if units <= 1 then return nil end
	-- Past three it would not sit beside anything anyway.
	if units > 3 then return "full" end
	return units
end

-- AceConfigDialog asks for a width with the option in info.option; a label or
-- a list of choices that is a function is asked the same way the page asks it.
local function Asked(value, info)
	if type(value) ~= "function" then return value end
	local ok, answer = pcall(value, info)
	return ok and answer or nil
end

local function FitButton(info)
	local option = type(info) == "table" and info.option
	return ControlWidth(LabelWidth(option and Asked(option.name, info), "GameFontNormal"), BUTTON_PAD)
end

-- A slider's or a key binding's width, from its label in `font`. The label
-- spans the whole control, with a few pixels to spare either side.
local function FitLabel(font)
	return function(info)
		local option = type(info) == "table" and info.option
		return ControlWidth(LabelWidth(option and Asked(option.name, info), font), 6)
	end
end

local function FitSelect(info)
	local option = type(info) == "table" and info.option
	local values = option and Asked(option.values, info)
	if type(values) ~= "table" then return nil end
	local widest
	for _, label in pairs(values) do
		local w = LabelWidth(label, "GameFontHighlightSmall")
		if w and (not widest or w > widest) then widest = w end
	end
	return ControlWidth(widest, SELECT_PAD)
end

-- How each kind of control is measured. Radio lists and the media pickers (a
-- dialogControl) lay out otherwise and are left alone.
local FITTERS = {
	button = FitButton,
	select = FitSelect,
	range = FitLabel("GameFontNormal"),
	keybinding = FitLabel("GameFontHighlight"),
}

-- Which controls this file sizes, and how (a key of FITTERS; false for
-- one that names its own width), so measuring again finds the same ones once
-- their width holds a number of ours.
local fitted = setmetatable({}, { __mode = "k" })

local function FitControls(node, key)
	if type(node) ~= "table" then return end
	local kind = fitted[node]
	if kind == nil then
		kind = false
		if node.width == nil then
			if node.type == "execute" then
				kind = "button"
			elseif node.type == "select" and node.style ~= "radio" and not node.dialogControl then
				kind = "select"
			elseif node.type == "range" then
				kind = "range"
			elseif node.type == "keybinding" then
				kind = "keybinding"
			end
		end
		fitted[node] = kind
	end
	if kind then
		-- Asked the way AceConfigDialog asks: the option, and its key last.
		local info = { key, option = node }
		node.width = FITTERS[kind](info)
	end
	if type(node.args) == "table" then
		for childKey, child in pairs(node.args) do FitControls(child, childKey) end
	end
end

---------------------------------------------------------------------------
-- registration
---------------------------------------------------------------------------

-- The category ID the game's Settings window hands back for our entry: the
-- only thing Settings.OpenToCategory can find it by (the canvas frame's own
-- GetID answers 0, which is no category at all).
local blizCategoryID

-- Set once the window has failed to build or show: from then on the old
-- dialog opens instead, and the failure is not reported again.
local broken = false

-- Esc > Options > AddOns > Manners: the icon, the name, the one sentence that
-- says what the addon does (Start here's own string), and a button into the
-- window. The window cannot live inside Settings' panel, so the panel steps
-- aside for it.
local function OpenFromSettings()
	if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
	ns.OpenOptions()
end

local function BuildCanvas()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local canvas = CreateFrame("Frame", "MannersOptionsCanvas")
	local icon = canvas:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\AddOns\\Manners\\Textures\\Manners64")
	icon:SetSize(48, 48)
	icon:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
	local title = canvas:CreateFontString(nil, "ARTWORK")
	title:SetFontObject(GameFontNormalLarge)
	title:SetPoint("LEFT", icon, "RIGHT", 12, 0)
	title:SetText("Manners")
	local about = canvas:CreateFontString(nil, "ARTWORK")
	about:SetFontObject(GameFontHighlight)
	about:SetJustifyH("LEFT")
	about:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
	about:SetPoint("RIGHT", canvas, "RIGHT", -24, 0)
	about:SetText(L["Manners shows a small button, the prompt, with the next person to buff. Click it, or press your key, and it casts on them; the game does not let addons cast by themselves."])
	local open = ns.WindowWidgets.Button(canvas, L["Options"], function()
		ns.Guard("options from Settings", OpenFromSettings)
	end)
	open:SetSize(160, 24)
	open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
	canvas.about, canvas.open = about, open

	local category = Settings.RegisterCanvasLayoutCategory(canvas, "Manners")
	Settings.RegisterAddOnCategory(category)
	blizCategoryID = category and (category.GetID and category:GetID() or category.ID) or nil
end

function ns.SetupOptions()
	local options = BuildOptions()
	options.args.profiles = Page.BuildProfilesTab()
	-- Sized for the fallback dialog, so it is right should it ever be needed;
	-- the window ignores width hints. Last, so the profiles tab is too.
	FitControls(options)
	-- Kept so a control can be read back afterwards, and the model the
	-- window reads: ns.optionsTable.args[tab].args[key].
	ns.optionsTable = options

	-- Still registered, for the fallback dialog and its validator.
	AceConfig:RegisterOptionsTable(ADDON, options)
	ns.Guard("options in Settings", BuildCanvas)

	Page.RegisterLauncher()
end

-- Repaint whatever is on screen from the values as they stand now: the
-- window's open page, sidebar and strip, and the fallback dialog if that is
-- what is up. Optional at both ends, because failing to repaint must never
-- take down the handler it is called from.
function ns.RefreshOptionsDisplay()
	if AceConfigRegistry and AceConfigRegistry.NotifyChange then
		AceConfigRegistry:NotifyChange(ADDON)
	end
	local UI = ns.WindowUI
	if UI and not broken and UI.Shown() then UI.Refresh() end
end

-- Whether the window somebody would be styling the prompt from is on screen.
-- Asked rather than subscribed to, so a missed notification can never leave a
-- preview running; every answer defaults to "no", so the preview times out.
function ns.OptionsOpen()
	local window = ns.OptionsWindow
	if window and window:IsShown() then return true end
	-- The fallback dialog, which the library keeps in here while it is open.
	local frames = AceConfigDialog and AceConfigDialog.OpenFrames
	if type(frames) == "table" and frames[ADDON] ~= nil then return true end
	return false
end

-- Shut the window. Setup.OpenBindings and Setup.OpenMacros call this: the
-- game's key binding and macro windows open underneath ours.
function ns.CloseOptions()
	if ns.WindowUI and ns.WindowUI.frame then ns.WindowUI.Close() end
	if AceConfigDialog and AceConfigDialog.Close then
		pcall(AceConfigDialog.Close, AceConfigDialog, ADDON)
	end
end

-- The id of the page in view -- "general", "who", "skip" -- or nil before the
-- window has opened. Ledger.lua repaints when it is "general".
function ns.OptionsTab()
	local UI = ns.WindowUI
	if not broken and UI and UI.frame then return UI.page end
	if not (AceConfigDialog and AceConfigDialog.GetStatusTable) then return nil end
	local ok, status = pcall(AceConfigDialog.GetStatusTable, AceConfigDialog, ADDON)
	local groups = ok and type(status) == "table" and status.groups
	local selected = type(groups) == "table" and groups.selected
	return type(selected) == "string" and selected or nil
end

-- The window that failed, put away so nothing half-built stays on screen.
local function Discard()
	local UI = ns.WindowUI
	if UI and UI.frame then UI.frame:Hide() end
end

-- `quiet` opens it without the preview a first opening starts: /manners
-- selftest shows its report there and touches nothing on the prompt.
function ns.OpenOptions(pageId, quiet)
	-- The boxes start shut when the window opens, but are left alone when it
	-- is already up, where somebody may be copying out of one.
	if not ns.OptionsOpen() then Page.reportOpen = false end
	if not ns.OptionsOpen() then Page.shareOpen = false end

	if not broken then
		if ns.Guard("options window", function() ns.WindowUI.Open(pageId, quiet) end) then return end
		-- Named once, through the guard; the old dialog from now on.
		broken = true
		pcall(Discard)
	end

	-- Measured again with today's labels: a snooze button's, a list of buffs
	-- learned since login.
	if ns.optionsTable then ns.Guard("fit controls", FitControls, ns.optionsTable) end
	local ok = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON)
	if ok then return end

	-- A last resort, by the ID the Settings entry came back with.
	if Settings and Settings.OpenToCategory and blizCategoryID ~= nil then
		pcall(Settings.OpenToCategory, blizCategoryID)
	end
end

-- Whether the window has failed and the old dialog stands in for it.
function ns.OptionsFallback() return broken end

-- The window built hidden, as opening it builds it, for /manners selftest's
-- window.build. A build that throws ends as it does on /manners: named once,
-- through the guard, the half-built frame put away and the old dialog from
-- then on. Left to a bare pcall it kept UI.frame, which UI.Open then showed
-- half-built without a throw, so nothing ever fell back. Never built again
-- over a window that failed. Answers whether the window is built.
function ns.BuildOptionsWindow()
	local UI = ns.WindowUI
	if UI.built then return true end
	if broken then return false end
	if ns.Guard("options window", UI.Build) then return UI.built == true end
	broken = true
	pcall(Discard)
	return false
end

-- /manners selftest's report, in its box under Reporting a bug on
-- Diagnostics (Options/Diagnostics.lua, selftest). Answers whether the box
-- is in front of the player.
function ns.ShowSelftestBox(text)
	ns.OpenOptions("diagnostics", true)
	Page.selftestText = text
	if broken then
		if AceConfigDialog.SelectGroup then
			pcall(AceConfigDialog.SelectGroup, AceConfigDialog, ADDON, "diagnostics")
		end
		ns.RefreshOptionsDisplay()
		return ns.OptionsOpen()
	end
	ns.RefreshOptionsDisplay()
	local UI = ns.WindowUI
	if UI and UI.Shown() then
		ns.Guard("options window", UI.Reveal, "diagnostics.selftest")
		return true
	end
	return false
end

-- Open the window on Profiles, where the share boxes are, with the box of
-- this profile's settings showing when that is what was asked for. For
-- /manners export and a bare /manners import. Answers whether there is a page
-- to send them to at all.
function ns.ShowShareBox(which)
	ns.OpenOptions("profiles")
	if which == "export" then Page.shareOpen = true end
	if broken then
		if AceConfigDialog.SelectGroup then
			pcall(AceConfigDialog.SelectGroup, AceConfigDialog, ADDON, "profiles")
		end
		ns.RefreshOptionsDisplay()
		return true
	end
	ns.RefreshOptionsDisplay()
	local UI = ns.WindowUI
	if UI and UI.Shown() then
		ns.Guard("options window", UI.Reveal, which == "export" and "profiles.shareNote" or "profiles.sharePaste")
	end
	return true
end
