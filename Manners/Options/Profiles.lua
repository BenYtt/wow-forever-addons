-- Manners -- options: the Profiles tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage

local AceDBOptions = LibStub("AceDBOptions-3.0")

-- A table of our own holding the same members, so what is written into it
-- (a hidden, a width) stays ours.
local function Copy(from)
	local out = {}
	for k, v in pairs(from) do out[k] = v end
	return out
end

-- AceDBOptions' own controls, with a line on what a profile is above them
-- and the share boxes added under them. The library's strings and orders are
-- its own; the intro sits at 0.5, above its `desc` (order 1), and the share
-- boxes start at 100.
--
-- In a group of our own: the library hands every addon that asks the same
-- table of controls, so hiding its paragraph or adding the share boxes there
-- would do it on every other addon's Profiles tab too, the paste box
-- importing into Manners; and a newer copy of the library loading later puts
-- a fresh table in its own groups, which would take the share boxes off ours.
-- Its handler is kept: the library upgrades that one in place.
function Page.BuildProfilesTab()
	local lib = AceDBOptions:GetOptionsTable(ns.db)
	local t = Copy(lib)
	t.order = 90
	t.args = {}
	for key, option in pairs(type(lib.args) == "table" and lib.args or {}) do
		t.args[key] = type(option) == "table" and Copy(option) or option
	end
	-- The library's own opening paragraph says what profilesIntro says, so the
	-- tab would open with the same thing twice.
	if type(t.args.desc) == "table" then t.args.desc.hidden = true end
	for key, option in pairs({
		-- What a profile is for, in the player's words, in place of the
		-- library's own paragraph: most players never need a second one.
		-- Share as text is a section of the same page, so nothing points
		-- at it.
		profilesIntro = {
			type = "description",
			order = 0.5,
			fontSize = "medium",
			name = L["Every character uses the Default profile unless you pick another here; make one per character for different settings."]
				.. "\n",
		},
		-- Two boxes rather than one that does both: a box that shows
		-- your settings and also applies whatever is typed into it
		-- is one stray keypress from replacing them.
		shareHeader = { type = "header", name = L["Share as text"], order = 100 },
		shareNote = {
			type = "description",
			order = 101,
			fontSize = "medium",
			name = L["Copy your settings as text to share, or paste text someone gave you. Pasting keeps your own on/off, lock, position, minimap button and chat options, and never turns on Say a line."],
		},
		shareCopy = {
			type = "execute",
			name = function()
				return Page.shareOpen and L["Hide the text"] or L["Show my settings as text"]
			end,
			desc = L["Shows your settings as text below, ready to copy; %s does the same."]
				:format("|cffffd100/manners export|r"),
			order = 102,
			func = function()
				Page.shareOpen = not Page.shareOpen
				ns.RefreshOptionsDisplay()
			end,
		},
		shareText = {
			type = "input",
			-- On the page rather than in a tooltip: the game has no way
			-- to put text on the clipboard for the player.
			name = L["Click in the box, press Ctrl+A to select it all, then Ctrl+C to copy (Cmd on a Mac)."],
			order = 103,
			multiline = 3,
			width = "full",
			hidden = function() return not Page.shareOpen end,
			get = function() return ns.ExportSettings() or "" end,
			-- Read-only the way the bug report is: anything typed in
			-- is discarded, and the box repaints from the profile.
			set = function() end,
		},
		sharePaste = {
			type = "input",
			name = L["Paste settings here, then press Accept"],
			desc = L["Replaces this profile's settings; %s puts yours back."]
				:format("|cffffd100/manners import undo|r"),
			order = 104,
			multiline = 3,
			width = "full",
			get = function() return "" end,
			-- Refused here with the reason, before anything changes.
			-- The dialog shows the sentence and keeps what was pasted,
			-- so it can be fixed rather than pasted again.
			validate = function(_, value)
				local parsed, err = ns.ParseSettings(value)
				if not parsed then return err end
				return true
			end,
			set = function(_, value)
				local _, message = ns.ImportSettings(value)
				ns.addon:Print(message)
			end,
		},
	}) do
		t.args[key] = option
	end
	return t
end
