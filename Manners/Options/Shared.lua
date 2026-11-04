-- Manners -- options: what several tabs of the page are built from.
--
-- The page is one file per tab, Options/<Tab>.lua, after this one and
-- Launcher.lua in the toc, and Register.lua last, which puts the tabs together
-- and registers them. They share this table: the setting accessors, the tab
-- names and the answers more than one tab asks. Each file copies what it uses
-- into locals of its own when it loads.

local _, ns = ...
local L = ns.L

local Page = {}
ns.OptionsPage = Page

---------------------------------------------------------------------------
-- get/set helpers
--
-- Each group binds to one table in the profile and uses the option's own key,
-- so adding an option is a one-liner rather than a pair of closures. A control
-- whose option key differs from its profile field (the sound controls) names
-- the field outright: moving a setting must never reset it.
---------------------------------------------------------------------------

local function bind(pathFn, after)
	local get = function(info) return pathFn()[info[#info]] end
	local set = function(info, value)
		pathFn()[info[#info]] = value
		if after then after() end
	end
	local getColor = function(info)
		local c = pathFn()[info[#info]] or { 1, 1, 1, 1 }
		return c[1], c[2], c[3], c[4] == nil and 1 or c[4]
	end
	local setColor = function(info, r, g, b, a)
		pathFn()[info[#info]] = { r, g, b, a }
		if after then after() end
	end
	return get, set, getColor, setColor
end

local function restyle() ns.Prompt:ApplyStyle() end
local function rescan() ns.addon:StartScanner() end
local function remacro() ns.Prompt:InvalidateMacro() end
local function restyleAndMacro()
	ns.Prompt:InvalidateMacro()
	ns.Prompt:ApplyStyle()
end

local function P() return ns.db.profile.prompt end
local function S() return ns.db.profile.sources end
local function F() return ns.db.profile.filters end
local function T() return ns.db.profile.timing end
local function SND() return ns.db.profile.sound end
local function SP() return ns.db.profile.speech end
local function B() return ns.db.profile.buff end
local function PR() return ns.db.profile.priority end

local pGet, pSet, pGetColor, pSetColor = bind(P, restyle)
-- The launcher's "N waiting" counts favours only while "People who buffed me"
-- is on, so throwing that switch changes the number on the bar.
local sGet, sSet = bind(S, function()
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end)
local fGet, fSet = bind(F)
-- The armed macro is only rebuilt when the candidate changes, so a filter that
-- alters what the macro says -- rather than who is on the prompt -- has to say
-- so. restoreTarget is the only one.
local fGetMacro, fSetMacro = bind(F, remacro)
local tGet, tSet = bind(T, rescan)
local spGet, spSet = bind(SP, remacro)
-- The buff dropdown reads the pin through its own get, so only the setter.
local bSet = select(2, bind(B, restyleAndMacro))
local prGet, prSet = bind(PR)

Page.restyle, Page.rescan, Page.restyleAndMacro = restyle, rescan, restyleAndMacro
Page.P, Page.S, Page.F, Page.SND, Page.SP, Page.B, Page.PR = P, S, F, SND, SP, B, PR
Page.pGet, Page.pSet, Page.pGetColor, Page.pSetColor = pGet, pSet, pGetColor, pSetColor
Page.sGet, Page.sSet, Page.fGet, Page.fSet = sGet, sSet, fGet, fSet
Page.fGetMacro, Page.fSetMacro, Page.tGet, Page.tSet = fGetMacro, fSetMacro, tGet, tSet
Page.spGet, Page.spSet, Page.bSet, Page.prGet, Page.prSet = spGet, spSet, bSet, prGet, prSet

---------------------------------------------------------------------------
-- what this character has to offer, asked by several tabs
---------------------------------------------------------------------------

local function HasClassBuffs()
	return ns.caps.hasClassBuffs == true
end

-- Whether everything this character could offer reaches its party and nobody
-- else -- a warrior's Battle Shout -- which leaves the strangers toggle with
-- nothing behind it. Core's answer, so the greeting and favour line agree.
local function OnlyReachesGroup()
	return ns.OnlyReachesGroup()
end

-- Whether there is a prompt on this character at all: a buff for somebody
-- else, or one of the class's own learned (a hunter's aspects). Start here's
-- key and preview steps and the Who to buff tab follow it.
local function HasPrompt()
	return ns.caps.hasClassBuffs == true or ns.OwnBuffsOnly()
end

-- Whether "Myself" is on and has something to offer: read by the warning that
-- nothing is ticked and by the summary on Start here, through the same answer
-- as the lines about saving mana (Core.lua), so they all agree.
local function OffersSelf()
	return ns.OffersSelf()
end

-- Whether every source on Who to buff is off, so the prompt never appears:
-- who.emptyWarning shows on it and the page's red dot reads it. A source this
-- class cannot use (passers-by, or yourself, for a warrior) does not count as
-- switched on: its toggle is hidden.
local function NoSources()
	local s = S()
	return not (s.owed or s.group or s.asked or (s.strangers and not OnlyReachesGroup())
		or OffersSelf())
end

Page.HasClassBuffs, Page.OnlyReachesGroup = HasClassBuffs, OnlyReachesGroup
Page.HasPrompt, Page.OffersSelf, Page.NoSources = HasPrompt, OffersSelf, NoSources

-- Move the prompt: the one switch for where the prompt sits, which people did
-- not find as a small checkbox on Look. A button that reads Move the prompt
-- while the prompt is locked and Lock it while it is not, going the way
-- /manners move and /manners lock do, through HandleSlash, so chat says the
-- same thing whichever way in (switched off, in a fight, snoozed). The window
-- draws it twice, in its header (general.moveToggle) and at the top of Look
-- (appearance.move), because its layout places a definition once; this makes
-- both, and the fallback dialog gets them as ordinary buttons.
--
-- Unlocking is a move of the secure prompt, which the client refuses in a
-- fight, so it is greyed out there with the minimap menu's words. Locking is a
-- flag the prompt reads (Press.lua), so Lock it still works in a fight, as the
-- status strip's does.
local function MoveControl(order)
	return {
		type = "execute",
		name = function() return P().locked and L["Move the prompt"] or L["Lock it"] end,
		desc = function()
			if not P().locked then
				return L["Locks the prompt where it is. An unlocked prompt does not buff anyone."]
			end
			local text = L["Unlocks the prompt so you can drag it where you want it; it locks itself when you let go."]
			if InCombatLockdown() then
				text = text .. "\n\n" .. L["The prompt cannot be moved or changed during a fight. This comes back once it ends."]
			end
			return text
		end,
		order = order,
		hidden = function() return not HasPrompt() end,
		disabled = function() return P().locked and InCombatLockdown() end,
		func = function()
			local profile = ns.db.profile
			if not profile.prompt.locked then
				ns.addon:HandleSlash("lock")
				return
			end
			if InCombatLockdown() then return end
			ns.addon:HandleSlash("unlock")
			-- The window sits over the spot the prompt starts at, and a prompt
			-- behind it cannot be dragged: out of the way, as for the game's
			-- key bindings, whenever there is a prompt up to drag. Switched
			-- off, the line in chat says why there is none, and the switch is
			-- in the header.
			if profile.enabled and not profile.prompt.locked then ns.CloseOptions() end
		end,
	}
end
Page.MoveControl = MoveControl

-- Whether the copy-for-a-bug-report box is open: a state of the window, not of
-- the profile, put back in OpenOptions and when the Settings page hides.
Page.reportOpen = false
-- And the box holding these settings as text, for the same reasons.
Page.shareOpen = false

-- Each page's name, used for its own title and wherever text on another page
-- points at it, so renaming a page cannot leave a sentence naming the old one.
-- The keys are the page ids, which never change: Ledger.lua repaints by
-- "general", and the tests and bug reports name pages by them. Who to skip is
-- a page of the window built from Who to buff's controls, not a group.
local TAB = {
	general = L["Start here"],
	who = L["Who to buff"],
	skip = L["Who to skip"],
	when = L["When to offer"],
	click = L["What I say"],
	appearance = L["Look"],
	diagnostics = L["Diagnostics"],
}

-- Text that points at a control on another page: the control's name in gold,
-- the page it is on in plain text. Where the dependency can be a `disabled` or
-- a `hidden` instead, it should be.
local function Ref(control, tab)
	return ("|cffffd100%s|r (%s)"):format(control, tab)
end

Page.TAB, Page.Ref = TAB, Ref

---------------------------------------------------------------------------
-- the sidebar's red dots
--
-- One predicate per page that can hold a warning, true while that page's
-- warning shows. Each asks the same answers the warning's own `hidden` asks,
-- never the note's text or colour, so the dot and the note cannot disagree.
-- Read at paint time, after every tab file has loaded.
---------------------------------------------------------------------------

-- A buff pinned in Buff to offer that this character has not learned: offered
-- to nobody (who.pinNote in red).
local function PinUnlearned()
	local pin = ns.PinnedBuff()
	return pin ~= nil and not ns.IsBuffKnown(pin)
end

-- Automatic with nothing it can cast (who.autoNote in red).
local function NothingCastable()
	return ns.PinnedBuff() == nil and #ns.CastableBuffs() == 0
end

Page.Warn = {
	-- No key and no macro: general.bindStatus in red.
	general = function()
		return HasPrompt() and not ns.Setup.Key() and not ns.Setup.MacroMade()
	end,
	who = function()
		return HasClassBuffs() and (NoSources() or PinUnlearned() or NothingCastable())
	end,
	-- when.alwaysNote.
	when = function()
		return HasClassBuffs() and F().whenBuffed == "always"
	end,
	-- appearance.noSound, appearance.accentDead.
	appearance = function()
		return (SND().enabled == true and SND().file == "None") or Page.AccentDead()
	end,
	-- diagnostics.errorList.
	diagnostics = function()
		return #ns.errors > 0
	end,
}
