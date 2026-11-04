local addonName = ...
---@class ForeverReportNamespace
---@field L table<string, string>
---@field Art table
---@field ReportTitle string
---@field CutText fun(text: string, limit: integer): string
---@field CaughtErrors fun(): table
---@field SafeCall fun(label: string, callback: function, ...: any): boolean, any
---@field ReportLines fun(): string[]
local ns = select(2, ...)

-- Vendored from Forever Core. `/report` shows one block of text,
-- already selected, for the player to copy into a bug report. The text opens with what every Forever addon reports
-- (versions, build, locale, character, place), then the addon's own lines, the errors ns.SafeCall caught, and the
-- other addons loaded, cut to fit one message. This file knows nothing else about the addon: it copies across the
-- Forever addons with phrase keys supplied through the namespace. The field labels stay English in every locale; the
-- names and the addon's own lines are the client's.

local L, Art = ns.L, ns.Art
-- One Discord or forum message; a GitHub issue field takes it whole.
local LIMIT = 2000
-- The addon's own lines and the caught errors each stop here, leaving room for the header and the addon list.
local LINES_LIMIT, ERRORS_LIMIT = 1000, 600
local ICON = "Interface\\AddOns\\" .. addonName .. "\\media\\Icon"
local WIDTH, HEIGHT = 460, 380

---@class ForeverReportModule
---@field Text fun(lines: string[]): string the whole report around the addon's `lines`, at most 2000 characters
---@field Show fun(text: string) show `text` in the report window, selected for copying
---@field Percent fun(value?: number): string a map coordinate as the map shows it
---@field Encode fun(value: string): string percent-encode a URL component
---@field Repo fun(): string the owner/repo from X-Website, or an empty string
---@field Issue fun(kind: string, title: string, details: string, lines: string[]): string the new-issue URL
---@field Body fun(kind: string, title: string, details: string, lines: string[]): string the markdown issue body
---@field Compose fun(kind?: string) show the bug or feature request composer
---@field Command fun(command: string, argument?: string): boolean handle shared slash commands
local Report = {}
ns.Report = Report

-- PortraitFrameTemplate's own members this file uses (Mainline/SharedUIPanelTemplates.xml).
---@class ForeverReportWindow : Frame
---@field SetTitle fun(self: ForeverReportWindow, title: string)
---@field GetPortrait fun(self: ForeverReportWindow): Texture

---@type ForeverReportWindow?
local window
---@type EditBox
local editBox
---@type string
local shown = ""

-- A map coordinate (0-1) as the map shows it, to one decimal; "-" when there is none.
---@param value? number
---@return string
local function Percent(value)
	return value and ("%.1f"):format(value * 100) or "-"
end
Report.Percent = Percent

-- The lines every Forever addon starts with.
---@return string[]
local function Header()
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "-"
	local gameVersion, build, _, interface = GetBuildInfo()
	local lines = {
		("%s %s | WoW %s (%s) %s | %s"):format(
			addonName,
			version,
			gameVersion,
			build,
			tostring(interface),
			GetLocale()
		),
	}
	local _, class = UnitClass("player")
	local _, race = UnitRace("player")
	lines[#lines + 1] = ("Character: level %d %s %s, %s"):format(
		UnitLevel("player") or 0,
		race or "-",
		class or "-",
		UnitFactionGroup("player") or "-"
	)
	local map = C_Map.GetBestMapForUnit("player")
	local point = map and C_Map.GetPlayerMapPosition(map, "player")
	local x, y
	if point then
		x, y = point:GetXY()
	end
	local info = map and C_Map.GetMapInfo(map)
	lines[#lines + 1] = ("Place: map %s (%s) %s, %s"):format(
		tostring(map or "-"),
		info and info.name or "-",
		Percent(x),
		Percent(y)
	)
	return lines
end

-- BugGrabber exposes its error database when installed; keep just current-session messages and stack frames.
---@class ReportExternalError
---@field message string
---@field count integer
---@field stack string?
---@field rawMessage string
-- Its `GetDB` API is also what BugSack displays. The built-in ScriptErrors frame has no readable history API.
---@return ReportExternalError[]?
local function BugGrabberErrors()
	local grabber = _G["BugGrabber"]
	if type(grabber) ~= "table" or type(grabber.GetDB) ~= "function" then
		return nil
	end
	local ok, lines = pcall(function()
		local database = grabber:GetDB()
		if type(database) ~= "table" then
			return {}
		end
		local session = type(grabber.GetSessionId) == "function" and grabber:GetSessionId() or nil
		---@type ReportExternalError[]
		local result = {}
		for index = #database, 1, -1 do
			local entry = database[index]
			if
				type(entry) == "table"
				and type(entry.message) == "string"
				and (session == nil or session == -1 or entry.session == session)
			then
				local stack = {}
				for line in (type(entry.stack) == "string" and entry.stack or ""):gmatch("[^\n]+") do
					stack[#stack + 1] = ns.CutText(line, 100)
					if #stack == 1 then
						break
					end
				end
				result[#result + 1] = {
					message = ns.CutText(entry.message, 140),
					rawMessage = entry.message,
					count = type(entry.counter) == "number" and entry.counter or 1,
					stack = stack[1],
				}
				if #result == 2 then
					break
				end
			end
		end
		return result
	end)
	return ok and lines or nil
end

-- The errors ns.SafeCall caught this session, newest first, plus recent runtime errors from BugGrabber when present.
---@return string[]
local function Errors()
	local caught = ns.CaughtErrors()
	local bugGrabber = BugGrabberErrors()
	local lines = {}
	if bugGrabber and bugGrabber[1] then
		local caughtMessages = {}
		for _, entry in ipairs(caught) do
			caughtMessages[entry.rawMessage or entry.message] = true
		end
		local added = false
		for _, entry in ipairs(bugGrabber) do
			if not caughtMessages[entry.rawMessage or entry.message] then
				if not added then
					lines[#lines + 1] = "Recent Lua errors (BugGrabber):"
					added = true
				end
				lines[#lines + 1] = ("- x%d %s"):format(entry.count, entry.message)
				if entry.stack then
					lines[#lines + 1] = "    " .. entry.stack
				end
			end
		end
	end
	if caught[1] then
		lines[#lines + 1] = ("Errors (%d):"):format(#caught)
		for index = #caught, 1, -1 do
			local entry = caught[index]
			lines[#lines + 1] = ("- [%s] x%d %s"):format(entry.label, entry.count, entry.message)
			for line in entry.stack:gmatch("[^\n]+") do
				lines[#lines + 1] = "    " .. line
			end
		end
	end
	if #lines == 0 then
		return {
			bugGrabber == nil and "Errors: none caught; BugGrabber is not loaded" or "Errors: none caught this session",
		}
	end
	return lines
end

-- The other loaded addons with their versions, as many as fit in `room` characters.
---@param room integer
---@return string
local function Addons(room)
	local names = {}
	for index = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(index)
		if name and name ~= addonName and C_AddOns.IsAddOnLoaded(index) then
			local version = C_AddOns.GetAddOnMetadata(name, "Version")
			names[#names + 1] = version and version ~= "" and (name .. " " .. version) or name
		end
	end
	table.sort(names)
	local text = ("Other addons (%d): "):format(#names)
	if not names[1] then
		return text .. "none"
	end
	for index, name in ipairs(names) do
		local more = index < #names and (" and %d more"):format(#names - index) or ""
		local piece = (index > 1 and ", " or "") .. name
		if #text + #piece + #more > room and index > 1 then
			return text .. (" and %d more"):format(#names - index + 1)
		end
		text = text .. piece
	end
	return text
end

-- The whole report: the header, the addon's `lines` (at most LINES_LIMIT characters), the caught errors (at most
-- ERRORS_LIMIT), then the other addons in what room is left. Each section has its own cap, so long addon lines never
-- push the errors out.
---@param lines string[]
---@return string
function Report.Text(lines)
	local text = table.concat({
		table.concat(Header(), "\n"),
		ns.CutText(table.concat(lines, "\n"), LINES_LIMIT),
		ns.CutText(table.concat(Errors(), "\n"), ERRORS_LIMIT),
	}, "\n")
	text = text .. "\n" .. Addons(math.max(LIMIT - #text - 1, 0))
	return ns.CutText(text, LIMIT)
end

---@param edit EditBox
local function Select(edit)
	edit:SetFocus()
	edit:HighlightText()
end

---@return ForeverReportWindow
local function Window()
	if window then
		return window
	end
	local name = addonName .. "Report"
	local frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate") --[[@as ForeverReportWindow]]
	-- Escape closes it like any panel, with or without the edit box's focus (an addon-owned frame).
	table.insert(UISpecialFrames, name)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(ns.ReportTitle)
	Art.Icon(frame:GetPortrait(), ICON, 62)

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	hint:SetPoint("TOPLEFT", 70, -32)
	hint:SetPoint("RIGHT", -16, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText(
		L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."]
	)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -64)
	inset:SetPoint("BOTTOMRIGHT", -10, 10)

	local scroll = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject("ChatFontNormal")
	edit:SetWidth(WIDTH - 66)
	edit:SetMaxLetters(0)
	-- Read-only: typing puts the report back, still selected, so a stray key never changes what is copied.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(shown)
			Select(self)
		end
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	edit:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(edit)
	editBox, window = edit, frame
	return frame
end

-- Show `text` in the window, all of it selected for Ctrl+C.
---@param text string
function Report.Show(text)
	local frame = Window()
	shown = text
	editBox:SetText(text)
	frame:Show()
	Select(editBox)
end

-- Encode a value for a GitHub issue URL. The client is asked to open the link in a browser.
---@param value string
---@return string
function Report.Encode(value)
	return (value:gsub("([^%w%-_%.~])", function(character)
		return ("%%%02X"):format(character:byte())
	end))
end

-- Read the repo from addon metadata so this report file can move between Forever addons.
---@return string
function Report.Repo()
	local website = C_AddOns.GetAddOnMetadata(addonName, "X-Website") or ""
	return (website:gsub("^https://github.com/", ""):gsub("/+$", ""))
end

-- The issue body contains the player's words first, then the existing system report.
---@param kind string
---@param title string
---@param details string
---@param lines string[]
---@return string
function Report.Body(kind, title, details, lines)
	local _ = kind .. title -- The signature keeps the composed fields explicit at call sites.
	local detailText = ns.CutText(details, 1000)
	if detailText == "" then
		detailText = "-"
	end
	local system = ns.CutText(Report.Text(lines), 1200)
	return "### What happened, or what you would like\n\n" .. detailText .. "\n\n### System information\n\n" .. system
end

-- Build the ready-made new-issue URL, keeping player details ahead of system information.
---@param kind string
---@param title string
---@param details string
---@param lines string[]
---@return string
function Report.Issue(kind, title, details, lines)
	local repo = Report.Repo()
	if repo == "" then
		return ""
	end
	local label = kind == "feature" and "enhancement" or "bug"
	local safeTitle = ns.CutText(title, 300)
	local detailText = ns.CutText(details, 1000)
	local body = Report.Body(kind, safeTitle, detailText, lines)
	local url = ("https://github.com/%s/issues/new?template=report.md&title=%s&body=%s&labels=%s"):format(
		repo,
		Report.Encode(safeTitle),
		Report.Encode(body),
		label
	)
	if #url > 7000 then
		body = "### What happened, or what you would like\n\n" .. detailText
		if detailText == "" then
			body = "### What happened, or what you would like\n\n-"
		end
		body = body .. "\n\nSystem information: copy it from Copy report."
		url = ("https://github.com/%s/issues/new?template=report.md&title=%s&body=%s&labels=%s"):format(
			repo,
			Report.Encode(safeTitle),
			Report.Encode(body),
			label
		)
		if #url > 7000 then
			safeTitle = ns.CutText(safeTitle, 120)
			detailText = ns.CutText(detailText, 350)
			body = "### What happened, or what you would like\n\n"
				.. (detailText ~= "" and detailText or "-")
				.. "\n\nSystem information: copy it from Copy report."
			url = ("https://github.com/%s/issues/new?template=report.md&title=%s&body=%s&labels=%s"):format(
				repo,
				Report.Encode(safeTitle),
				Report.Encode(body),
				label
			)
		end
	end
	return url
end

-- Keep the composer usable if the addon's own report lines fail in the state being reported.
---@return string[]
local function IssueLines()
	local ok, lines = ns.SafeCall("report lines", ns.ReportLines)
	return ok and lines or { "Report lines failed: " .. tostring(lines) }
end

---@class ForeverIssueWindow : ForeverReportWindow
---@field titleBox EditBox
---@field detailsBox EditBox
---@field outputBox EditBox
---@field hint FontString
---@field kind string
---@field bugButton Button
---@field featureButton Button
---@field copyLinkButton Button
---@field copyReportButton Button

---@type ForeverIssueWindow?
local issueWindow
---@type EditBox
local issueTitle, issueDetails, issueOutput
---@type string
local issueShown = ""
---@type string
local issueKind = "bug"

---@param parent Frame
---@param text string
---@param point string
---@param relative Frame|string
---@param relativePoint string
---@param x number
---@param y number
---@return FontString
local function Label(parent, text, point, relative, relativePoint, x, y)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint(point, relative, relativePoint, x, y)
	label:SetJustifyH("LEFT")
	label:SetText(text)
	return label
end

---@param edit EditBox
---@param text string
local function SetSelected(edit, text)
	issueShown = text
	edit:SetText(text)
	Select(edit)
end

---@param kind string
---@param lines string[]
local function RefreshIssue(kind, lines)
	issueKind = kind
	if issueWindow then
		issueWindow.kind = kind
		issueWindow.bugButton:SetButtonState(kind == "feature" and "NORMAL" or "PUSHED", true)
		issueWindow.featureButton:SetButtonState(kind == "feature" and "PUSHED" or "NORMAL", true)
	end
	local title = issueTitle:GetText() or ""
	issueShown = Report.Issue(kind, title, issueDetails:GetText() or "", lines)
	issueOutput:SetText(issueShown)
end

---@param kind string
local function SetIssueKind(kind)
	local prefix = kind == "feature" and L["Feature request: "] or L["Bug: "]
	local current = issueTitle:GetText() or ""
	local oldPrefix = issueKind == "feature" and L["Feature request: "] or L["Bug: "]
	local plain = current:sub(1, #oldPrefix) == oldPrefix and current:sub(#oldPrefix + 1) or current
	issueTitle:SetText(prefix .. plain)
	RefreshIssue(kind, IssueLines())
end

---@return ForeverIssueWindow
local function IssueWindow()
	if issueWindow then
		return issueWindow
	end
	local name = addonName .. "Issue"
	local frame = CreateFrame("Frame", name, UIParent, "PortraitFrameTemplate") --[[@as ForeverIssueWindow]]
	table.insert(UISpecialFrames, name)
	frame:SetSize(520, 500)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle(L["Report a bug or request a feature"])
	Art.Icon(frame:GetPortrait(), ICON, 62)

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	hint:SetPoint("TOPLEFT", 70, -30)
	hint:SetPoint("RIGHT", -16, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText(
		L["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."]
	)

	local bug = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	bug:SetSize(110, 24)
	bug:SetPoint("TOPLEFT", 18, -66)
	bug:SetText(L["Bug"])
	local feature = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	feature:SetSize(150, 24)
	feature:SetPoint("LEFT", bug, "RIGHT", 8, 0)
	feature:SetText(L["Feature request"])
	Label(frame, L["Title"], "TOPLEFT", frame, "TOPLEFT", 18, -102)
	local title = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
	title:SetAutoFocus(false)
	title:SetSize(478, 24)
	title:SetPoint("TOPLEFT", 20, -122)
	title:SetMaxLetters(300)
	title:SetText(L["Bug: "])
	Label(frame, L["What happened, or what you would like"], "TOPLEFT", frame, "TOPLEFT", 18, -158)
	local details = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
	details:SetMultiLine(true)
	details:SetAutoFocus(false)
	details:SetFontObject("ChatFontNormal")
	details:SetSize(470, 72)
	details:SetPoint("TOPLEFT", 22, -178)
	details:SetMaxLetters(1000)

	local copyLink = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	copyLink:SetSize(150, 24)
	copyLink:SetPoint("TOPLEFT", 18, -260)
	copyLink:SetText(L["Copy issue link"])
	local copyReport = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate") --[[@as Button]]
	copyReport:SetSize(140, 24)
	copyReport:SetPoint("LEFT", copyLink, "RIGHT", 8, 0)
	copyReport:SetText(L["Copy report"])
	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 10, -294)
	inset:SetPoint("BOTTOMRIGHT", -10, 10)
	local scroll = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -28, 8)
	local output = CreateFrame("EditBox", nil, scroll)
	output:SetMultiLine(true)
	output:SetAutoFocus(false)
	output:SetFontObject("ChatFontNormal")
	output:SetWidth(520 - 66)
	output:SetMaxLetters(0)
	output:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(issueShown)
			Select(self)
		end
	end)
	output:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	output:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	bug:SetScript("OnClick", function()
		SetIssueKind("bug")
	end)
	feature:SetScript("OnClick", function()
		SetIssueKind("feature")
	end)
	copyLink:SetScript("OnClick", function()
		hint:SetText(
			L["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."]
		)
		RefreshIssue(issueKind, IssueLines())
		Select(output)
	end)
	copyReport:SetScript("OnClick", function()
		hint:SetText(
			L["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."]
		)
		SetSelected(output, Report.Body(issueKind, title:GetText() or "", details:GetText() or "", IssueLines()))
	end)
	title:SetScript("OnTextChanged", function()
		RefreshIssue(issueKind, IssueLines())
	end)
	details:SetScript("OnTextChanged", function()
		RefreshIssue(issueKind, IssueLines())
	end)
	scroll:SetScrollChild(output)
	frame.titleBox, frame.detailsBox, frame.outputBox, frame.hint, frame.kind = title, details, output, hint, "bug"
	frame.bugButton, frame.featureButton = bug, feature
	frame.copyLinkButton, frame.copyReportButton = copyLink, copyReport
	issueTitle, issueDetails, issueOutput, issueWindow = title, details, output, frame
	return frame
end

-- Show the issue composer, retaining title and details when its frame is reused.
---@param kind? string
function Report.Compose(kind)
	local frame = IssueWindow()
	kind = kind or "bug"
	if kind ~= issueKind then
		SetIssueKind(kind)
	else
		RefreshIssue(kind, IssueLines())
	end
	frame:Show()
	Select(issueOutput)
end

-- Handle the shared report and issue commands before an addon's own slash commands.
---@param command string
---@param argument? string
---@return boolean handled
function Report.Command(command, argument)
	if command == "report" then
		local ok, lines = ns.SafeCall("report lines", ns.ReportLines)
		Report.Show(Report.Text(ok and lines or { "Report lines failed: " .. tostring(lines) }))
		return true
	end
	if command == "issue" or command == "bug" or command == "feature" then
		Report.Compose((command == "feature" or argument == "feature") and "feature" or "bug")
		return true
	end
	return false
end
