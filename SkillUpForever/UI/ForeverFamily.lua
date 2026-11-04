---@type string, ForeverFamilyNamespace
local _, ns = ...

-- The Forever addons, and the quiet hints one shows for another the player doesn't have. This file is
-- byte-identical in all five addons (tests/forever_family_spec.lua pins it): the first copy to load sets the
-- `ForeverFamily` global and later copies use it, unless a later copy is newer (a higher VERSION), which takes over
-- so an addon updated first never runs on an older copy. It holds no addon's own code: each addon passes in its
-- saved variables (`db`) and its own folder, and `ns.Family` is a view bound to the addon's own L (VERSION 4), so
-- its page and window read in its translations and nowhere else's. Nothing here is protected, hooks Blizzard code,
-- runs in combat or reaches the network: a hint is a grey line, a menu entry or a settings row that shows a link.

---@class ForeverFamilyNamespace
---@field L? ForeverFamilyL
---@field FamilyL? ForeverFamilyL an English-keyed L for this file, for an addon whose own L uses other keys
---@field Family? ForeverFamilyAPI

---@class ForeverFamilyDB
---@field suggestFamily? boolean false when the player turned the hints off; on by default
---@field familyDismissed? table<string, boolean> hints the player chose never to see again, by key

---@class ForeverFamilyAddon
---@field name string
---@field folder string
---@field url string
---@field line string what it does, in one line, in English: also its key in each addon's L

---@alias ForeverFamilyState "on"|"off"|"missing"
---@alias ForeverFamilyL table<string, string>
---@alias ForeverFamilySaved ForeverFamilyDB|fun(): ForeverFamilyDB?

---@class ForeverFamilyPanel : Frame
---@field Refresh fun(self: ForeverFamilyPanel)
---@field OnRefresh fun(self: ForeverFamilyPanel)
---@field OnDefault fun(self: ForeverFamilyPanel)

-- PortraitFrameTemplate's own members this file uses (Mainline/SharedUIPanelTemplates.xml).
---@class ForeverFamilyLinkWindow : Frame
---@field SetTitle fun(self: ForeverFamilyLinkWindow, title: string)
---@field GetPortrait fun(self: ForeverFamilyLinkWindow): Texture

local VERSION = 4
if ForeverFamily and (tonumber(ForeverFamily.VERSION) or 0) >= VERSION then
	ns.Family = type(ForeverFamily.For) == "function" and ForeverFamily.For(ns.FamilyL or ns.L) or ForeverFamily
	return
end

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
-- One window name for every copy and version, so Escape always knows it.
local LINK_NAME = "ForeverFamilyLink"
local NO_STRINGS = {}
-- The copy this one takes over, if an older version loaded first: its window is put away when this one opens.
local previous = ForeverFamily

---@class ForeverFamilyAPI
---@field VERSION integer raised with every change to this file
---@field ADDONS ForeverFamilyAddon[] the five addons, in order
---@field window? ForeverFamilyLinkWindow the link window once built, for a newer copy to put away
local Family = { VERSION = VERSION }

-- The copy now in charge when a newer version has taken over the global since this one loaded: an addon still
-- holding this copy's view is then served by the newer one, so there is only ever one window and one record.
---@return ForeverFamilyAPI?
local function Newer()
	local current = ForeverFamily
	if current ~= Family and type(current) == "table" and (tonumber(current.VERSION) or 0) > VERSION then
		return current
	end
end

-- Every addon's L takes English phrases as keys. A phrase reads from one L only, the calling addon's (or, for a
-- caller that names none, the L of the addon whose copy is in use), and as itself where that L has no string for
-- it, so a line is never half in one language and half in another. A phrase counts only as the L's own entry
-- (rawget), never through its metatable. One lookup table per L, rebuilt if the collector takes it.
local strings = setmetatable({}, { __mode = "kv" })
---@param locale? ForeverFamilyL
---@return ForeverFamilyL
local function Strings(locale)
	local own = ns.FamilyL or ns.L
	local source = type(locale) == "table" and locale or type(own) == "table" and own or NO_STRINGS
	local found = strings[source]
	if not found then
		found = setmetatable({}, {
			__index = function(_, phrase)
				local text = rawget(source, phrase)
				return type(text) == "string" and text or phrase
			end,
		})
		strings[source] = found
	end
	return found
end

---@param name string
---@param folder string
---@param slug string the CurseForge project's address
---@param line string
---@return ForeverFamilyAddon
local function Addon(name, folder, slug, line)
	return { name = name, folder = folder, url = "https://www.curseforge.com/wow/addons/" .. slug, line = line }
end

-- The addons in order. Written through an L that answers each phrase with itself, so the lines stay English keys
-- and tools/phrases.py in each addon lists them for translators.
---@param L ForeverFamilyL
---@return ForeverFamilyAddon[]
local function List(L)
	return {
		Addon(
			"Shortest Path Forever",
			"ShortestPathForever",
			"shortest-path-forever",
			L["Plans the quickest way anywhere and guides you there, with live boat and zeppelin times."]
		),
		Addon(
			"Adventure Guide Forever",
			"AdventureGuideForever",
			"adventure-guide-forever",
			L["Picks quests for your level and plans them into one journey."]
		),
		Addon(
			"SkillUp Forever",
			"SkillUpForever",
			"skillup-forever",
			L["Plans the cheapest route to your next profession rank."]
		),
		Addon(
			"Legacy Forever",
			"LegacyForever",
			"legacy-forever",
			L["Shows the Legacy challenges you can advance in each zone."]
		),
		Addon(
			"Tweaks Forever",
			"TweaksForever",
			"tweaks-forever",
			L["Quest automation, rare alerts and merchant handling for the default UI."]
		),
	}
end
Family.ADDONS = List(Strings(NO_STRINGS))

-- An installed addon's own icon; files load from a folder whether or not its addon is switched on.
---@param folder string
---@param state ForeverFamilyState
---@return string
local function Icon(folder, state)
	return state == "missing" and QUESTION or ("Interface\\AddOns\\" .. folder .. "\\media\\Icon")
end

---@param folder string
---@return ForeverFamilyAddon?
local function Find(folder)
	for _, addon in ipairs(Family.ADDONS) do
		if addon.folder == folder then
			return addon
		end
	end
end

-- A button as wide as its label, so a translated one fits.
---@param button Button
---@param minimum number
local function Fit(button, minimum)
	local label = button:GetFontString()
	button:SetWidth(math.max(minimum, label and label:GetStringWidth() + 24 or 0))
end

-- The client may answer with a secret value in a restricted state; testing one raises, so the test happens
-- inside the pcall and a failed read means "don't know".
---@param question fun(): boolean
---@return boolean?
local function Ask(question)
	local ok, answer = pcall(question)
	if ok then
		return answer
	end
end

-- "off" covers every installed copy that isn't running: switched off, out of date or failed to load. An answer
-- the client won't give also reads as "off", so no hint shows for an addon the player may have.
---@param folder string
---@return ForeverFamilyState
function Family.State(folder)
	local api = C_AddOns
	if type(api) ~= "table" then
		return "off"
	end
	local loaded = Ask(function()
		return api.IsAddOnLoaded(folder) and true or false
	end)
	if loaded ~= false then
		return loaded and "on" or "off"
	end
	local exists = Ask(function()
		if api.DoesAddOnExist then
			return api.DoesAddOnExist(folder) and true or false
		end
		local _, _, _, _, reason = api.GetAddOnInfo(folder)
		return reason ~= "MISSING"
	end)
	return exists == false and "missing" or "off"
end

-- Whether the hint `key` for `folder` may show: hints are on, the addon isn't installed at all (one the player
-- switched off was their choice), and they haven't dismissed this hint. Passive places ask on every show.
---@param db? ForeverFamilyDB
---@param key string
---@param folder string
---@return boolean
function Family.Hint(db, key, folder)
	if type(db) ~= "table" or db.suggestFamily == false then
		return false
	end
	local dismissed = db.familyDismissed
	if type(dismissed) == "table" and dismissed[key] then
		return false
	end
	return Family.State(folder) == "missing"
end

local claimed = {}
-- True the first time `key` asks this session, for the places that draw attention (the tracker footer). Keys are
-- shared by every Forever addon, so each starts with its own addon's name.
---@param key string
---@return boolean
function Family.Once(key)
	local newer = Newer()
	if newer and type(newer.Once) == "function" then
		return newer.Once(key)
	end
	if claimed[key] then
		return false
	end
	claimed[key] = true
	return true
end

---@type ForeverFamilyLinkWindow?
local window
local parts = {}
local shownURL = ""
---@type { db?: ForeverFamilyDB, key?: string, onDismiss?: fun() }
local showing = {}

---@param edit EditBox
local function Select(edit)
	edit:SetFocus()
	edit:HighlightText()
end

---@return ForeverFamilyLinkWindow
local function Window()
	if window then
		return window
	end
	-- The copy this one took over keeps its window on its own table; this one takes the name, and Escape with it.
	local older = type(previous) == "table" and previous.window
	if type(older) == "table" and type(older.Hide) == "function" then
		older:Hide()
	end
	local frame = CreateFrame("Frame", LINK_NAME, UIParent, "PortraitFrameTemplate") --[[@as ForeverFamilyLinkWindow]]
	if not tContains(UISpecialFrames, LINK_NAME) then
		-- Escape closes it like any panel (an addon-owned frame).
		table.insert(UISpecialFrames, LINK_NAME)
	end
	frame:SetSize(400, 186)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	local line = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	line:SetPoint("TOPLEFT", 70, -32)
	line:SetPoint("RIGHT", -16, 0)
	line:SetJustifyH("LEFT")

	local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
	edit:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 6, -12)
	edit:SetPoint("RIGHT", -20, 0)
	edit:SetHeight(24)
	edit:SetAutoFocus(false)
	-- Read-only: typing puts the address back, still selected, so a stray key never changes what is copied.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(shownURL)
			Select(self)
		end
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	edit:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	hint:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -6, -6)
	hint:SetPoint("RIGHT", -16, 0)
	hint:SetJustifyH("LEFT")

	local close = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	close:SetHeight(22)
	close:SetPoint("BOTTOMRIGHT", -14, 14)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local never = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	never:SetHeight(22)
	never:SetPoint("RIGHT", close, "LEFT", -8, 0)
	never:SetScript("OnClick", function()
		local db, key, onDismiss = showing.db, showing.key, showing.onDismiss
		if db and key then
			db.familyDismissed = type(db.familyDismissed) == "table" and db.familyDismissed or {}
			db.familyDismissed[key] = true
		end
		frame:Hide()
		if onDismiss then
			onDismiss()
		end
	end)

	parts.line, parts.edit, parts.hint, parts.close, parts.never = line, edit, hint, close, never
	window = frame
	Family.window = frame
	return frame
end

-- A small window with `folder`'s name, line and store address, selected for Ctrl+C. With a hint `key` it also
-- offers "Don't suggest this again", which dismisses that hint in `db` and then calls `onDismiss`. Never opens in
-- combat; returns whether it opened. Its text reads from `locale` (an addon's view passes its own L).
---@param db? ForeverFamilyDB
---@param key? string
---@param folder string
---@param onDismiss? fun()
---@param locale? ForeverFamilyL
---@return boolean
function Family.ShowLink(db, key, folder, onDismiss, locale)
	local newer = Newer()
	if newer and type(newer.ShowLink) == "function" then
		return newer.ShowLink(db, key, folder, onDismiss, locale)
	end
	local addon = Find(folder)
	if not addon or InCombatLockdown() then
		return false
	end
	local frame = Window()
	local L = Strings(locale)
	showing.db, showing.key, showing.onDismiss = db, key, onDismiss
	shownURL = addon.url
	frame:SetTitle(addon.name)
	-- art-ok: a square icon in the template's round portrait
	frame:GetPortrait():SetTexture(Icon(folder, Family.State(folder)))
	parts.line:SetText(L[addon.line])
	parts.hint:SetText(L["Copy the address, then open it in your browser."])
	parts.close:SetText(L["Close"])
	parts.never:SetText(L["Don't suggest this again"])
	local dismissable = db ~= nil and key ~= nil
	Fit(parts.close, 96)
	Fit(parts.never, 140)
	parts.never:SetShown(dismissable)
	-- The window grows for a long translation rather than letting a button leave it or the line run over the box:
	-- the title band, the line, the box, the hint and the buttons, each with its gap.
	local buttons = parts.close:GetWidth() + (dismissable and parts.never:GetWidth() + 8 or 0)
	frame:SetWidth(math.max(400, buttons + 102))
	local text = (parts.line:GetStringHeight() or 0) + (parts.hint:GetStringHeight() or 0)
	frame:SetHeight(math.max(186, text + 124))
	parts.edit:SetText(addon.url)
	frame:Show()
	Select(parts.edit)
	return true
end

local ROW_HEIGHT = 52

-- The "Forever addons" settings page: the hint setting, then a row per addon with its icon, line, state and a
-- Copy link button. `db` is the addon's saved variables, or a function that returns them once they load;
-- `current` is the addon's own folder, whose row says "This addon". The rows are built the first time it shows
-- and their states read again each time. Defaults turns the hints back on, dismissed ones included. Its text reads
-- from `locale` (an addon's view passes its own L).
---@param parent? Frame
---@param db ForeverFamilySaved
---@param current? string
---@param locale? ForeverFamilyL
---@return ForeverFamilyPanel
function Family.CreatePanel(parent, db, current, locale)
	local panel = CreateFrame("Frame", nil, parent) --[[@as ForeverFamilyPanel]]
	-- Hidden until the settings panel shows it, so its OnShow always fires.
	panel:Hide()
	local L = Strings(locale)
	local states = { on = L["On"], off = L["Installed, turned off"], missing = L["Not installed"] }
	---@return ForeverFamilyDB?
	local function Saved()
		if type(db) == "function" then
			return db()
		end
		return db
	end
	local check
	local rows = {}

	local function Build()
		local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 16, -16)
		title:SetText(L["Forever addons"])

		check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate") --[[@as CheckButton]]
		check:SetPoint("TOPLEFT", 12, -44)
		check:SetScript("OnClick", function(self)
			local saved = Saved()
			if saved then
				saved.suggestFamily = self:GetChecked() and true or false
			else
				self:SetChecked(true)
			end
		end)
		local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		label:SetPoint("LEFT", check, "RIGHT", 4, 0)
		label:SetText(L["Suggest my other Forever addons"])
		local about = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		about:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 2)
		about:SetPoint("RIGHT", -16, 0)
		about:SetJustifyH("LEFT")
		about:SetText(
			L["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."]
		)

		for index, addon in ipairs(Family.ADDONS) do
			local top = -100 - (index - 1) * ROW_HEIGHT
			local icon = panel:CreateTexture(nil, "ARTWORK")
			icon:SetSize(32, 32)
			icon:SetPoint("TOPLEFT", 16, top)
			local button = CreateFrame("Button", nil, panel, "SharedButtonSmallTemplate") --[[@as Button]]
			button:SetHeight(22)
			button:SetPoint("TOPRIGHT", -16, top - 5)
			button:SetText(L["Copy link"])
			Fit(button, 110)
			button:SetScript("OnClick", function()
				Family.ShowLink(nil, nil, addon.folder, nil, locale)
			end)
			local state = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			state:SetPoint("RIGHT", button, "LEFT", -10, 0)
			state:SetWidth(140)
			state:SetJustifyH("RIGHT")
			local name = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
			name:SetText(addon.name)
			local line = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			line:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
			line:SetPoint("RIGHT", state, "LEFT", -10, 0)
			line:SetJustifyH("LEFT")
			line:SetText(L[addon.line])
			rows[index] = { addon = addon, icon = icon, state = state, button = button }
		end
	end

	local function Refresh()
		if not check then
			Build()
		end
		local saved = Saved()
		check:SetChecked(not (saved and saved.suggestFamily == false))
		for _, row in ipairs(rows) do
			local folder = row.addon.folder
			local state = Family.State(folder)
			local own = folder == current
			-- art-ok: square icons at 32x32
			row.icon:SetTexture(Icon(folder, state))
			row.state:SetText(own and L["This addon"] or states[state])
			row.button:SetShown(not own)
		end
	end
	panel.Refresh, panel.OnRefresh = Refresh, Refresh
	function panel.OnDefault()
		local saved = Saved()
		if saved then
			saved.suggestFamily, saved.familyDismissed = true, nil
		end
		Refresh()
	end
	panel:SetScript("OnShow", Refresh)
	return panel
end

-- The API bound to one addon's L: ShowLink and CreatePanel read in that L unless a call names another. Each addon's
-- copy sets `ns.Family` to its own view (of `ns.FamilyL`, else `ns.L`), so no call site can leave it out. The same
-- view comes back for the same L while one is held.
local views = setmetatable({}, { __mode = "kv" })
---@param locale? ForeverFamilyL
---@return ForeverFamilyAPI
function Family.For(locale)
	if type(locale) ~= "table" then
		return Family
	end
	local view = views[locale]
	if not view then
		view = setmetatable({
			ShowLink = function(db, key, folder, onDismiss, other)
				return Family.ShowLink(db, key, folder, onDismiss, other or locale)
			end,
			CreatePanel = function(parent, db, current, other)
				return Family.CreatePanel(parent, db, current, other or locale)
			end,
		}, { __index = Family })
		views[locale] = view
	end
	return view --[[@as ForeverFamilyAPI]]
end

ForeverFamily = Family -- taint-ok: addon-owned registry shared by the Forever addons
ns.Family = Family.For(ns.FamilyL or ns.L)
