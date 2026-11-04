-- Manners -- options: the launcher. The minimap button, a broker display and
-- the addon compartment all show the same text, tooltip and right-click menu.

local ADDON, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local HasClassBuffs = Page.HasClassBuffs

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-- The logo tools/make-icon.py draws, and the same file the toc's IconTexture
-- names, so the minimap button and the addon list show one picture. No
-- extension: the client finds the .tga itself.
local ICON = "Interface\\AddOns\\Manners\\Textures\\Manners64"

-- Whether there is a minimap button at all: LibDataBroker makes the data
-- object and LibDBIcon puts it on the minimap, so it takes both.
local function HasMinimapButton()
	return LDB ~= nil and LDBIcon ~= nil
end

-- The launcher and the compartment's entry, once RegisterLauncher has made
-- them. At file scope so their text can be put back in step later: they are
-- made once and never again.
local broker
local compartment

-- Whether the compartment is a way in right now: Manners is registered there
-- and the compartment is on screen. BetterBlizzFrames and EnhanceQoL hide it.
local function CompartmentShown()
	local frame = _G.AddonCompartmentFrame
	if not compartment or type(frame) ~= "table" then return false end
	if type(frame.IsShown) ~= "function" then return true end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown and true or false
end

-- Asked with a net under it: the tooltip and the launcher text are read by
-- other addons' display frames, on their own schedule, and one of them asking
-- before AceDB has handed us a profile must not throw inside somebody else's
-- layout pass.
local function Enabled()
	return ns.db ~= nil and ns.db.profile ~= nil and ns.db.profile.enabled == true
end

-- Whether an unlocked prompt is up to be dragged. Prompt:RefreshPanel hides the
-- panel for a character with nothing it can cast and for /manners off before
-- it reads the lock, so the lock alone is not the answer.
local function DragPanelUp()
	return Enabled() and ns.db.profile.prompt.locked == false
		and ns.caps ~= nil and ns.CanCastAnything()
end

-- How many people who buffed you are still waiting for one back: the favours,
-- not the whole queue, since a city crowd would keep that number meaningless.
-- Counted by the debt's live expiry, and none at all while "People who buffed
-- me" is off, because the queue then ignores every debt still on file.
local function WaitingCount()
	local profile = ns.db and ns.db.profile
	if not (profile and profile.sources and profile.sources.owed) then return 0 end
	local owed, expiry = ns.owed, ns.DebtExpiry
	if type(owed) ~= "table" or type(expiry) ~= "function" then return 0 end
	local now, n = GetTime(), 0
	for _, debt in pairs(owed) do
		if type(debt) == "table" then
			local ok, ends = pcall(expiry, debt)
			if ok and type(ends) == "number" and ends > now then n = n + 1 end
		end
	end
	return n
end

-- What the launcher says it is: off and snoozed are worth carrying, because
-- from the outside a prompt that never appears looks like a broken addon.
--
-- Each state is one whole phrase with the addon's name passed in, so a
-- translation sees what the word describes and can put it, and its colour,
-- where its own grammar wants them. The name itself is never translated.
local function BrokerText()
	-- Off outranks a snooze, since a snooze ending brings nothing back while off.
	local ends = Enabled() and ns.SnoozeEndsAt and ns.SnoozeEndsAt()
	if ends then return L["%s |cffffd100snoozed until %s|r"]:format("Manners", ends) end
	if not Enabled() then return L["%s |cffff8080off|r"]:format("Manners") end
	-- Then the favours still to return; with none, just the name.
	local waiting = WaitingCount()
	if waiting == 1 then return L["%s |cff80e0801 waiting|r"]:format("Manners") end
	if waiting > 1 then return L["%s |cff80e080%d waiting|r"]:format("Manners", waiting) end
	return "Manners"
end

-- The colour the launcher's icon is drawn in: dimmed while snoozed, darker
-- still while switched off. The icon is the one part of the launcher always in
-- view on the minimap. Brightness only, never a hue: a tint turns the icon's
-- blue arrow olive and it reads as a different icon at minimap size.
local function IconTint()
	if not Enabled() then return 0.4, 0.4, 0.4 end
	if ns.SnoozeLeft and ns.SnoozeLeft() then return 0.7, 0.7, 0.7 end
	return 1, 1, 1
end

Page.HasMinimapButton, Page.CompartmentShown, Page.DragPanelUp =
	HasMinimapButton, CompartmentShown, DragPanelUp

-- The minimap button's right-click menu; the middle button throws the switch.
--
-- MenuUtil is the client's own context menu, and the addons known to work on
-- this client open theirs the same way. Asked for at the moment of the click:
-- a client without it keeps the old right-click, the switch on its own.
local function HasLauncherMenu()
	return type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function"
end

-- The lengths the menu offers. Its own list rather than the options page's:
-- an hour is the length a raid night wants, and a menu has room for a fourth
-- line where a row of buttons on the page does not.
local MENU_SNOOZE_MINUTES = { 5, 15, 30, 60 }

-- How many people the menu's Who's next lists, and how many of them the
-- tooltip names under the one on the prompt.
local MENU_QUEUE_ROWS = 8
local TOOLTIP_QUEUE_ROWS = 3

-- Picks the line for why somebody is being offered a buff.
--
-- The caller writes out all six lines, one whole sentence per reason, rather
-- than slotting a word for the reason into one sentence: "buffed you" slotted
-- into three different sentences is a word a translation has to make agree
-- with a subject it never sees.
local function ByReason(entry, owed, group, target, nearby, asked, own)
	local reason = entry and entry.reason
	if reason == "owed" then return owed end
	if reason == "group" then return group end
	if reason == "target" then return target end
	if reason == "asked" then return asked end
	if reason == "self" then return own end
	return nearby
end

-- As the prompt says it: a group cast is "Your party" and its group spell,
-- not the one person it is aimed at and the single buff.
local function WhoIs(entry)
	return tostring(entry.display or entry.short or entry.name)
end

local function WhatBuff(entry)
	return tostring(ns.EntrySpellName and ns.EntrySpellName(entry)
		or ns.BuffName and ns.BuffName(entry.buff) or "?")
end

-- Who the prompt is armed at and who comes after them, in that order, with
-- nobody twice; the second answer is nil when no prompt is up. Read, never
-- acted on. The one on the prompt comes from the prompt itself, because in a
-- fight it stays whoever the fight found there while the queue moves on.
local function WhoIsWaiting(limit)
	local showing = ns.Prompt and ns.Prompt.Showing and ns.Prompt:Showing() or nil
	local list, seen = {}, {}
	if showing and showing.name then
		list[1] = showing
		seen[showing.name] = true
	end
	local queue
	ns.Guard("launcher queue", function() queue = ns.BuildQueue() end)
	for _, entry in ipairs(type(queue) == "table" and queue or {}) do
		if #list >= limit then break end
		if entry.name and not seen[entry.name] then
			seen[entry.name] = true
			list[#list + 1] = entry
		end
	end
	return list, showing
end

-- The entry a fight holds on the prompt, if there is one.
local function HeldInFight()
	if not InCombatLockdown() then return nil end
	local ok, showing = pcall(function()
		return ns.Prompt and ns.Prompt.Showing and ns.Prompt:Showing() or nil
	end)
	return ok and showing or nil
end

-- Whether the button is still up with a macro on it, which after /manners off
-- in a fight is all that is left of the prompt: `current` is cleared, and the
-- macro and the panel cannot be until the fight ends. Both are readable there.
local function ArmedButtonLeft()
	local ok, armed = pcall(function()
		local button = ns.Prompt and ns.Prompt.GetButton and ns.Prompt:GetButton()
		return button ~= nil and button:IsShown() and button:GetAttribute("macrotext1") ~= nil
	end)
	return ok and armed == true
end

-- Whether a prompt can appear at all right now, and the line that says so:
-- watching, then the line with its colour and whether it wraps. "On" is not
-- enough to say "watching": a class with nothing to give, nothing learned yet
-- and a setting in the way are told apart as the greeting tells them apart.
-- One answer for the tooltip and the menu's Who's next, so they agree.
--
-- A seventh answer, `heldOnly`, is true while a fight holds a prompt that a
-- snooze or the lock will take down once it ends: the one on it is still armed
-- and still worth a Skip, and nobody after them is going to be offered.
--
-- An eighth, `kind`, names the branch the line came from -- off, unlocked,
-- snoozed, ownoff, mounted, ownwatch, noclass, nothing, blocked, unlearned,
-- watching -- so the options window's status strip can show only the states
-- that keep the prompt from doing what the player expects. The tooltip and
-- the menu ignore it.
local function LauncherState()
	local class = ns.caps and ns.caps.class
	local snoozeLeft = ns.SnoozeLeft and ns.SnoozeLeft()
	local held = HeldInFight()
	-- A hunter or a shaman with one of their own buffs learned.
	local ownOnly = ns.OwnBuffsOnly()
	if not Enabled() then
		-- Switched off in a fight leaves the panel the fight froze on screen,
		-- and a press on it still casts. "No prompt will appear" is false for
		-- as long as that lasts.
		if InCombatLockdown() and ArmedButtonLeft() then
			return false, L["Switched off -- the prompt this fight froze stays up until it ends, and a press still casts it."],
				1, 0.5, 0.5, true, nil, "off"
		end
		return false, L["Switched off -- no prompt will appear."], 1, 0.5, 0.5, nil, nil, "off"
	elseif DragPanelUp() then
		-- Ahead of the snooze, as the prompt reads them: an unlocked prompt is
		-- up to be dragged and casts nothing.
		--
		-- Except in a fight, where the macro on the button is frozen and a
		-- press still casts at whoever the fight found on it: while the prompt
		-- still names them they are listed with their Skip, and once the name
		-- is cleared only the macro is left, said as /manners off says it.
		if held then
			return true, L["Unlocked, but in this fight the prompt stays as the fight found it, and a press still casts it; it can be dragged once the fight ends."],
				1, 0.82, 0, true, true, "unlocked"
		elseif InCombatLockdown() and ArmedButtonLeft() then
			return false, L["Unlocked -- the prompt this fight froze stays up until it ends, and a press still casts it; then it can be dragged."],
				1, 0.82, 0, true, nil, "unlocked"
		end
		if snoozeLeft then
			return false, L["Unlocked, and snoozed until %s -- the prompt stays up to be dragged, casting nothing, until you lock it."]
				:format(ns.SnoozeEndsAt()), 1, 0.82, 0, true, nil, "unlocked"
		end
		return false, L["Unlocked -- the prompt is up to be dragged and casts nothing until you lock it (%s)."]
			:format("|cffffd100/manners lock|r"), 1, 0.82, 0, true, nil, "unlocked"
	elseif snoozeLeft and held then
		-- A snooze started in the fight: the panel stays as the fight found it,
		-- armed, and follows the snooze once it ends. Said as that, and with the
		-- held entry still listed, since a press still casts at them.
		return true, L["Snoozed until %s -- in this fight the prompt stays as the fight found it, and follows the snooze once the fight ends."]
			:format(ns.SnoozeEndsAt()), 1, 0.82, 0, true, true, "snoozed"
	elseif snoozeLeft then
		-- The clock time and the minutes both: the time is what the player
		-- compares with a raid timer, and the minutes are what they asked for.
		return false, L["Snoozed until %s, %s from now -- no prompt until then."]
			:format(ns.SnoozeEndsAt(), ns.MinutesText(math.ceil(snoozeLeft / 60))), 1, 0.82, 0, true, nil, "snoozed"
	elseif ownOnly and not ns.OffersSelf() then
		-- A hunter with "Myself" or every one of his own buffs switched off:
		-- the prompt has nothing left to be for.
		return false, L["Nothing to do: your own buffs are switched off under %s."]
			:format(L["Myself"]), 1, 0.82, 0, nil, nil, "ownoff"
	elseif ownOnly or (ns.OwnBuffsLive() and not ns.ResolveBuff(true)) then
		-- Nothing for anybody else, but a prompt for your own buffs: a hunter,
		-- a warlock before Unending Breath, a mage with her Intellect switched
		-- off. Past the lines below, which would say nothing is offered while
		-- the prompt is up on you; and watching, so the tooltip and the menu
		-- list "You" and its Skip.
		if not held and ns.HiddenWhileMounted and ns.HiddenWhileMounted() then
			return false, L["Kept away while you are mounted -- %s, on the %s tab."]
				:format(L["Hide the prompt while I'm mounted"], L["When to offer"]), 1, 0.82, 0, true, nil, "mounted"
		end
		if ownOnly then return true, L["Watching your own buffs."], 0.4, 0.9, 0.4, nil, nil, "ownwatch" end
		return true, L["Watching your own buffs; nothing is offered to anybody else: %s."]
			:format(ns.NothingToCast()), 0.4, 0.9, 0.4, true, nil, "ownwatch"
	elseif class and ns.CLASSES_WITHOUT_BUFFS and ns.CLASSES_WITHOUT_BUFFS[class] then
		return false, L["Nothing to do: %s"]:format(ns.NO_CLASS_BUFFS), 1, 0.82, 0, nil, nil, "noclass"
	elseif not HasClassBuffs() then
		return false, L["Nothing to cast on this character -- /manners debug says why."], 1, 0.82, 0,
			nil, nil, "nothing"
	elseif not ns.ResolveBuff(true) then
		if ns.caps.anyKnown then
			return false, L["Nothing will be offered: %s."]:format(ns.NothingToCast()), 1, 0.5, 0.5, true,
				nil, "blocked"
		end
		return false, L["Nothing learned to cast yet."], 1, 0.82, 0, nil, nil, "unlearned"
	elseif not held and ns.HiddenWhileMounted and ns.HiddenWhileMounted() then
		-- The queue offers nobody while this is true, so name the mount -- but
		-- not over a prompt a fight holds, which is still up and armed. The
		-- option and its tab go in by their own keys, so a translation names
		-- the labels the window shows.
		return false, L["Kept away while you are mounted -- %s, on the %s tab."]
			:format(L["Hide the prompt while I'm mounted"], L["When to offer"]), 1, 0.82, 0, true, nil, "mounted"
	end
	return true, L["Watching for people to buff."], 0.4, 0.9, 0.4, nil, nil, "watching"
end
-- The options window's status strip reads the same line.
ns.LauncherState = LauncherState

-- What the launcher's tooltip says, for the minimap button, a broker display
-- and the addon compartment alike.
local function FillLauncherTooltip(tooltip)
	tooltip:AddLine("Manners")
	-- The state, said here as well as in the text, because a broker display is
	-- free to show the icon on its own.
	local watching, line, r, g, b, wrap, heldOnly = LauncherState()
	tooltip:AddLine(line, r, g, b, wrap)

	-- Who is waiting, while there is a prompt to wait on.
	if watching then
		local list, showing = WhoIsWaiting(TOOLTIP_QUEUE_ROWS + 1)
		-- Snoozed in a fight: only the one the fight holds. Nobody after them
		-- is going to be offered until the snooze ends, so neither the rows
		-- under them nor the count of favours waiting is anything to read.
		if heldOnly then list = showing and { showing } or {} end

		-- In a fight the prompt keeps whoever it had when the fight began, so
		-- "watching" alone would promise a prompt that follows the queue. Only
		-- while there is a prompt up to be held.
		if showing and InCombatLockdown() then
			tooltip:AddLine(L["Held in combat -- the prompt moves on once the fight ends."], 1, 0.82, 0, true)
		end

		-- The favours first: they are what the launcher's own text counts, so a
		-- bar reading "2 waiting" is answered by the first line of the hover.
		local waiting = heldOnly and 0 or WaitingCount()
		if waiting == 1 then
			tooltip:AddLine(L["1 person who buffed you is waiting for one back."], 0.5, 0.88, 0.5, true)
		elseif waiting > 1 then
			tooltip:AddLine(L["%d people who buffed you are waiting for one back."]:format(waiting),
				0.5, 0.88, 0.5, true)
		end
		for i, entry in ipairs(list) do
			if entry == showing then
				tooltip:AddLine(ByReason(entry,
					L["On the prompt: |cffffffff%s|r -- %s, buffed you"],
					L["On the prompt: |cffffffff%s|r -- %s, in your group"],
					L["On the prompt: |cffffffff%s|r -- %s, your target"],
					L["On the prompt: |cffffffff%s|r -- %s, nearby"],
					L["On the prompt: |cffffffff%s|r -- %s, asked for it"],
					L["On the prompt: |cffffffff%s|r -- %s, your own buff"]
				):format(WhoIs(entry), WhatBuff(entry)), 1, 0.82, 0, true)
			elseif i <= TOOLTIP_QUEUE_ROWS + (showing and 1 or 0) then
				tooltip:AddLine(ByReason(entry,
					L["Next: |cffffffff%s|r -- %s, buffed you"],
					L["Next: |cffffffff%s|r -- %s, in your group"],
					L["Next: |cffffffff%s|r -- %s, your target"],
					L["Next: |cffffffff%s|r -- %s, nearby"],
					L["Next: |cffffffff%s|r -- %s, asked for it"],
					L["Next: |cffffffff%s|r -- %s, your own buff"]
				):format(WhoIs(entry), WhatBuff(entry)), 0.8, 0.8, 0.8, true)
			end
		end
	end

	-- Today's favours and the lifetime counts, from the ledger.
	-- Guarded like the rest of what this tooltip borrows: a count
	-- that throws must not take the lines above with it.
	if ns.Ledger then ns.Guard("ledger tooltip", ns.Ledger.AddTooltip, tooltip) end

	-- What each click will do, not what the button is for. Grey, under
	-- everything else: they are the part read once.
	tooltip:AddLine(L["Left click: options"], 0.6, 0.6, 0.6)
	if ns.Ledger then
		tooltip:AddLine(L["Shift-click: favour ledger"], 0.6, 0.6, 0.6)
	end
	-- Where there is no menu both buttons throw the switch, and one line says
	-- so rather than two saying the same thing.
	if HasLauncherMenu() then
		tooltip:AddLine(Enabled() and L["Middle click: switch it off"]
			or L["Middle click: switch it on"], 0.6, 0.6, 0.6)
		tooltip:AddLine(L["Right click: snooze, preview, who's next and more"], 0.6, 0.6, 0.6)
	else
		tooltip:AddLine(Enabled() and L["Middle or right click: switch it off"]
			or L["Middle or right click: switch it on"], 0.6, 0.6, 0.6)
	end
end

-- The switch, thrown in one press: the right-click where there is no menu,
-- and the middle button everywhere. Off is said with the way back in it,
-- because it lasts across logins and a stray wheel press can throw it.
local function ToggleEnabled(mouseButton)
	ns.db.profile.enabled = not ns.db.profile.enabled
	ns.Prompt:Refresh()
	if ns.db.profile.enabled then
		ns.addon:Print(L["enabled."])
	elseif mouseButton == "RightButton" then
		ns.addon:Print(L["switched off from the launcher -- right-click it again, or type |cffffd100/manners on|r, to switch it back."])
	else
		ns.addon:Print(L["switched off from the launcher -- middle-click it again, or type |cffffd100/manners on|r, to switch it back."])
	end
	-- In a fight the macro on the button cannot be cleared, so a press still
	-- casts at whoever the fight froze on it, as /manners off says.
	if not ns.db.profile.enabled and InCombatLockdown() and ArmedButtonLeft() then
		ns.addon:Print(L["Switched off -- the prompt this fight froze stays up until it ends, and a press still casts it."])
	end
	-- The Enable checkbox and the launcher's text do not re-read the profile
	-- on their own.
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- building the menu
--
-- Every entry goes through the same function its slash command or its control
-- on the options page does, so the menu cannot describe a state the others
-- disagree with, and says the same line in chat.
--
-- The client's menu calls these back from its own code, and whatever throws
-- there is lost -- so every callback runs under Guard, which names it.
---------------------------------------------------------------------------

local function Act(fn)
	return function() ns.Guard("minimap menu", fn) end
end

-- For the entries that move the prompt or change what it is armed with: the
-- lock, its position and the profile. The client refuses all of that on a
-- secure frame in a fight, so they are greyed out there -- and refused again
-- at the click, because a menu opened before the pull is still open after it.
local function ActOutOfCombat(fn)
	return function()
		if InCombatLockdown() then
			ns.addon:Print(L["that has to wait until after the fight -- the prompt cannot be moved or changed in combat."])
			return
		end
		ns.Guard("minimap menu", fn)
	end
end

-- The label an entry wears while a fight holds it, so the reason is on the
-- line itself rather than only in a tooltip nobody hovers for.
local function FightLabel(label, fight)
	if not fight then return label end
	return L["%s |cff808080-- after the fight|r"]:format(label)
end

local function HeldForFight(description)
	if type(description) ~= "table" then return end
	if description.SetEnabled then description:SetEnabled(false) end
	if description.SetTooltip then
		description:SetTooltip(function(tooltip)
			tooltip:AddLine(L["The prompt cannot be moved or changed during a fight. This comes back once it ends."],
				1, 0.82, 0, true)
		end)
	end
end

-- Answered under pcall: the menu asks while it draws, and a question that
-- throws there takes the whole menu with it.
local function Asked(get)
	return function()
		local ok, value = pcall(get)
		return ok and value == true
	end
end

-- A checkbox where the client's menu has them, and a plain button that does
-- the same thing where it does not.
local function Check(parent, text, get, set)
	if parent.CreateCheckbox then return parent:CreateCheckbox(text, Asked(get), set) end
	return parent:CreateButton(text, set)
end

local function Radio(parent, text, get, set)
	if parent.CreateRadio then return parent:CreateRadio(text, Asked(get), set) end
	return parent:CreateButton(text, set)
end

local function Divider(parent)
	if parent.CreateDivider then parent:CreateDivider() end
end

-- Not now, from the menu: the same block a right-press on the prompt writes,
-- and the same repaint after it, which moves the panel on only where the fight
-- allows. Said in chat every time, since skipping somebody further down the
-- list changes nothing on screen -- and for the one on the prompt in a fight,
-- that a press still casts at them.
local function SkipFromMenu(entry)
	ns.BlockPerson(entry.name)
	-- A group cast is skipped whole, as a right-press on it is.
	if ns.SkipGroupCast then ns.SkipGroupCast(entry) end
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	local onPrompt = showing and showing.name == entry.name
	if onPrompt then ns.Prompt:StopAttention() end
	-- Inside a sentence a group cast is "your party", not the panel's title.
	local who = entry.groupCast and entry.groupCast.label or WhoIs(entry)
	-- "You" is the panel's word, not a name to slot into a sentence. No word
	-- about a fight: a press held there casts your own buff on you, harmless.
	if entry.reason == "self" then
		ns.addon:Print(L["skipping your own buff for now."])
		ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
		return
	end
	if onPrompt and InCombatLockdown() then
		ns.addon:Print(L["skipping |cffffffff%s|r for now -- but the prompt cannot move off them in a fight, and a press still casts at them."]
			:format(who))
	else
		ns.addon:Print(L["skipping |cffffffff%s|r for now."]:format(who))
	end
	ns.Guard("skip repaint", ns.Prompt.Refresh, ns.Prompt)
end

-- Never, from the menu: the never-offer list, as a shift-right-press on the
-- prompt puts them there. With the same block first, as that press writes it:
-- the list alone reaches the panel only after the hold and the fuse have run,
-- and the block takes them off it at once.
local function NeverFromMenu(entry)
	ns.BlockPerson(entry.name)
	-- Only the one it is aimed at is listed; the rest of a group cast are
	-- skipped, as a shift-right-press on it does.
	if ns.SkipGroupCast then ns.SkipGroupCast(entry) end
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	if showing and showing.name == entry.name then ns.Prompt:StopAttention() end
	-- Never for yourself is the switch, as a shift-right-press makes it.
	if entry.reason == "self" then
		ns.StopOfferingSelf()
		ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
		return
	end
	-- Says the fight's warning itself and repaints the prompt, for every route
	-- onto the list alike, so nothing is said here as well.
	ns.PutOnNeverList(entry.name)
end

local function Nobody(parent, text)
	local none = parent:CreateButton(text)
	if none.SetEnabled then none:SetEnabled(false) end
end

-- The people the prompt would offer, and only while it would offer anybody:
-- the same test the tooltip makes. Except the one a fight holds on the prompt
-- after a snooze or an unlock in it: a press still casts at them until the
-- fight ends, so they are listed with their Skip, and nobody after them is.
local function FillWhoIsNext(parent)
	local watching, line, _, _, _, _, heldOnly = LauncherState()
	if not Enabled() then
		Nobody(parent, L["Nobody -- Manners is switched off"])
		return
	end
	-- The lock before the snooze, as LauncherState reads them, except over the
	-- one a fight still holds.
	if DragPanelUp() and not heldOnly then
		Nobody(parent, line)
		return
	end
	local ends = ns.SnoozeEndsAt and ns.SnoozeEndsAt()
	if ends and not heldOnly then
		Nobody(parent, L["Nobody -- snoozed until %s"]:format(ends))
		return
	end
	if not watching then
		Nobody(parent, line)
		return
	end
	local list, showing
	if heldOnly then
		showing = HeldInFight()
		list = showing and { showing } or {}
	else
		list, showing = WhoIsWaiting(MENU_QUEUE_ROWS)
	end
	if #list == 0 then
		-- Favours can be live while the queue offers none of them (skipped,
		-- dead, out of reach), and the launcher's text counts them.
		local waiting = WaitingCount()
		if waiting == 1 then
			Nobody(parent, L["Nobody can be offered right now -- 1 favour is waiting"])
		elseif waiting > 1 then
			Nobody(parent, L["Nobody can be offered right now -- %d favours are waiting"]:format(waiting))
		else
			Nobody(parent, L["Nobody is waiting"])
		end
		return
	end
	for _, entry in ipairs(list) do
		local label
		if entry == showing then
			label = ByReason(entry,
				L["%s -- %s (buffed you), on the prompt"],
				L["%s -- %s (in your group), on the prompt"],
				L["%s -- %s (your target), on the prompt"],
				L["%s -- %s (nearby), on the prompt"],
				L["%s -- %s (asked for it), on the prompt"],
				L["%s -- %s (your own buff), on the prompt"])
		else
			label = ByReason(entry,
				L["%s -- %s (buffed you)"],
				L["%s -- %s (in your group)"],
				L["%s -- %s (your target)"],
				L["%s -- %s (nearby)"],
				L["%s -- %s (asked for it)"],
				L["%s -- %s (your own buff)"])
		end
		local person = parent:CreateButton(label:format(WhoIs(entry), WhatBuff(entry)))
		person:CreateButton(L["Skip for now"], Act(function() SkipFromMenu(entry) end))
		-- Somebody already on the list is in the queue only because they are
		-- owed, and for them the same act lets the favour go. The one a fight
		-- holds on the prompt may owe nothing, so owed is asked as the queue
		-- asks it.
		local listed = ns.IsNeverOffered and ns.IsNeverOffered(entry.name)
		local ok, owedNow = pcall(function()
			local debt = ns.owed and ns.owed[entry.name]
			return ns.db.profile.sources.owed and debt ~= nil and ns.DebtExpiry(debt) > GetTime()
		end)
		owedNow = ok and owedNow == true
		if listed and not owedNow then
			Nobody(person, L["On your never-offer list"])
		else
			person:CreateButton(listed and L["Let this favour go"] or L["Never offer"],
				Act(function() NeverFromMenu(entry) end))
		end
	end
	-- Unlocked or snoozed in a fight: the one the fight holds, then a line
	-- saying why nobody comes after them -- the lock first, as it is read.
	if heldOnly and DragPanelUp() then
		Nobody(parent, L["Nobody else -- the prompt is unlocked"])
	elseif heldOnly and ends then
		Nobody(parent, L["Nobody else -- snoozed until %s"]:format(ends))
	end
end

local function FillPromptMenu(parent, fight)
	local lock = Check(parent, FightLabel(L["Locked"], fight), function() return ns.db.profile.prompt.locked end,
		ActOutOfCombat(function()
			ns.addon:HandleSlash(ns.db.profile.prompt.locked and "unlock" or "lock")
		end))
	local reset = parent:CreateButton(FightLabel(L["Reset position"], fight), ActOutOfCombat(function()
		-- The same four values the options page's Reset position puts back.
		local d, now = ns.defaults.profile.prompt, ns.db.profile.prompt
		now.point, now.relPoint, now.x, now.y = d.point, d.relPoint, d.x, d.y
		ns.Prompt:ApplyStyle()
		ns.addon:Print(L["the prompt is back where it started."])
		ns.RepaintOptions()
	end))
	if fight then
		HeldForFight(lock)
		HeldForFight(reset)
	end
	Divider(parent)
	-- These three are drawing and sound, never where the button is or what it
	-- casts: the style is put back after the fight by ApplyStyle itself, so
	-- they stay open in one.
	Check(parent, L["Keep the prompt still in combat"], function() return ns.db.profile.prompt.hideInCombat end,
		Act(function()
			local now = ns.db.profile.prompt
			now.hideInCombat = not now.hideInCombat
			ns.Prompt:ApplyStyle()
			ns.RepaintOptions()
		end))
	Check(parent, L["Play a sound"], function() return ns.db.profile.sound.enabled end,
		Act(function()
			local sound = ns.db.profile.sound
			sound.enabled = not sound.enabled
			ns.RepaintOptions()
		end))
	local effects = parent:CreateButton(L["Effects"])
	for _, choice in ipairs({
		{ key = "full", label = L["Full"] },
		{ key = "calm", label = L["Calm -- less movement"] },
	}) do
		Radio(effects, choice.label, function() return (ns.db.profile.prompt.effects or "full") == choice.key end,
			Act(function()
				ns.db.profile.prompt.effects = choice.key
				ns.Prompt:ApplyStyle()
				ns.RepaintOptions()
			end))
	end
end

-- Profile names in alphabetical order in any language: the client's
-- strcmputf8i folds every script's capitals, where string.lower folds only
-- A-Z.
local function NameBefore(a, b)
	local fold = _G.strcmputf8i
	if type(fold) == "function" then
		local ok, order = pcall(fold, a, b)
		if ok and type(order) == "number" and order ~= 0 then return order < 0 end
	end
	local la, lb = a:lower(), b:lower()
	if la ~= lb then return la < lb end
	return a < b
end

-- AceDB's profiles, when the database can list them and there is a second one
-- to switch to. Switching changes where the prompt sits and what it is armed
-- with, so it waits for the fight to end like the lock does.
local function AddProfiles(root, fight)
	local db = ns.db
	if not (db.GetProfiles and db.GetCurrentProfile and db.SetProfile) then return end
	local names = {}
	local ok = pcall(function()
		local list = db:GetProfiles()
		for _, name in pairs(list or {}) do
			if type(name) == "string" then names[#names + 1] = name end
		end
	end)
	table.sort(names, NameBefore)
	if not ok or #names < 2 then return end
	local parent = root:CreateButton(L["Profiles"])
	for _, name in ipairs(names) do
		local choice = Radio(parent, FightLabel(name, fight), function() return db:GetCurrentProfile() == name end,
			ActOutOfCombat(function()
				if db:GetCurrentProfile() ~= name then db:SetProfile(name) end
			end))
		if fight then HeldForFight(choice) end
	end
end

-- In four groups: the state (on, snoozed), the people (who is next, the
-- ledger), the prompt and how it talks, and the options window.
local function FillLauncherMenu(root)
	local fight = InCombatLockdown()
	if root.CreateTitle then root:CreateTitle("Manners") end
	Check(root, L["Enable"], Enabled, Act(function()
		ns.addon:HandleSlash(Enabled() and "off" or "on")
	end))

	-- The snooze, with its end on the entry itself while one is running.
	local ends = ns.SnoozeEndsAt()
	local snooze = root:CreateButton(ends and L["Snoozed until %s"]:format(ends) or L["Snooze"])
	for _, minutes in ipairs(MENU_SNOOZE_MINUTES) do
		snooze:CreateButton(L["For %s"]:format(ns.MinutesText(minutes)), Act(function()
			ns.StartSnooze(minutes)
		end))
	end
	if ends then
		Divider(snooze)
		snooze:CreateButton(L["Stop snoozing"], Act(function() ns.StopSnooze() end))
	end

	Divider(root)
	FillWhoIsNext(root:CreateButton(L["Who's next"]))
	if ns.Ledger then
		root:CreateButton(L["Open the ledger"], Act(function() ns.Ledger.Show() end))
	end

	Divider(root)
	-- Greyed out in a fight as it is on the options page: ToggleTest refuses to
	-- start one there. One already running can still be stopped.
	local inTest = ns.Prompt:InTest()
	-- Each entry does only what its label says: the menu is built once, and a
	-- preview can time out under it while /manners test is a toggle.
	local preview
	if inTest then
		preview = root:CreateButton(L["End the preview"], Act(function()
			if ns.Prompt:InTest() then
				ns.addon:HandleSlash("test")
			else
				ns.addon:Print(L["the preview has already ended."])
			end
		end))
	else
		preview = root:CreateButton(FightLabel(L["Preview the prompt"], fight), Act(function()
			if not ns.Prompt:InTest() then ns.addon:HandleSlash("test") end
		end))
	end
	if fight and not inTest then HeldForFight(preview) end
	FillPromptMenu(root:CreateButton(L["Prompt"]), fight)
	Check(root, L["Tell me in chat what Manners is doing"], function() return ns.db.profile.verbose end,
		Act(function() ns.addon:HandleSlash("verbose") end))
	AddProfiles(root, fight)

	Divider(root)
	root:CreateButton(L["Options"], Act(function() ns.OpenOptions() end))
end

-- Opens the menu and answers whether there was one to open. A menu that
-- throws while being built is caught and named like any other failure, and
-- still counts as opened: falling back to the switch then would turn the
-- addon off in answer to a click that asked for a menu.
--
-- `later` is for a click that arrives from inside another menu -- the addon
-- compartment's -- which closes every open menu once its click handler
-- returns, the one just opened included. Opened on the next frame instead, on
-- UIParent, since the compartment's line is gone by then.
local function OpenLauncherMenu(owner, later)
	if not HasLauncherMenu() then return false end
	local function open()
		ns.Guard("minimap menu", MenuUtil.CreateContextMenu, owner or UIParent, function(_, root)
			ns.Guard("minimap menu", FillLauncherMenu, root)
		end)
	end
	if later and C_Timer and C_Timer.After then
		C_Timer.After(0, open)
	else
		open()
	end
	return true
end

-- Every click on the launcher, from the minimap, a broker bar or the addon
-- compartment.
local function LauncherClick(owner, mouseButton, later)
	-- The middle button throws the switch: the one thing wanted in a hurry,
	-- with no menu in the way.
	if mouseButton == "MiddleButton" then
		ToggleEnabled(mouseButton)
		return
	end
	-- Shift with the left button opens the ledger; the plain click stays the
	-- options window.
	if mouseButton ~= "RightButton" and ns.Ledger
		and IsShiftKeyDown and IsShiftKeyDown() then
		ns.Guard("ledger window", ns.Ledger.Toggle)
		return
	end
	-- The menu where the client has one; the switch on its own
	-- where it does not, which is what a right-click always did.
	if mouseButton == "RightButton" and OpenLauncherMenu(owner, later) then return end
	if mouseButton == "RightButton" then
		ToggleEnabled(mouseButton)
	else
		ns.OpenOptions()
	end
end

-- The tooltip for the compartment's line, which is a menu entry rather than a
-- button of ours. The client's menu tooltip where it has one, anchored the way
-- the rest of that menu's are; GameTooltip where it does not.
local function ShowLauncherTooltip(owner)
	if type(MenuUtil) == "table" and type(MenuUtil.ShowTooltip) == "function" then
		MenuUtil.ShowTooltip(owner, FillLauncherTooltip)
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	FillLauncherTooltip(GameTooltip)
	GameTooltip:Show()
end

local function HideLauncherTooltip(owner)
	if type(MenuUtil) == "table" and type(MenuUtil.HideTooltip) == "function" then
		MenuUtil.HideTooltip(owner)
		return
	end
	GameTooltip:Hide()
end

-- The addon compartment: the drop-down under the minimap that lists every
-- addon, which this client has, and the one launcher that is always there.
--
-- Registered here rather than through the toc's AddonCompartmentFunc fields,
-- which name global functions, and directly rather than through LibDBIcon's
-- copy, which only adds a button it is also showing on the minimap.
local function RegisterCompartment()
	local frame = _G.AddonCompartmentFrame
	if compartment or type(frame) ~= "table" or type(frame.RegisterAddon) ~= "function" then
		return false
	end
	compartment = {
		text = BrokerText(),
		icon = ICON,
		notCheckable = true,
		registerForAnyClick = true,
		-- The client hands over which button, inside the input data. Anything
		-- else -- an older shape of the call -- is read as a left click, which
		-- opens the options and changes nothing.
		func = function(_, input)
			local which = type(input) == "table" and input.buttonName or nil
			ns.Guard("addon compartment", LauncherClick, nil, which or "LeftButton", true)
		end,
		funcOnEnter = function(owner) ns.Guard("addon compartment", ShowLauncherTooltip, owner) end,
		funcOnLeave = function(owner) ns.Guard("addon compartment", HideLauncherTooltip, owner) end,
	}
	frame:RegisterAddon(compartment)
	return true
end

-- The data object, the minimap button and the compartment's entry, made once
-- the page is registered (ns.SetupOptions).
function Page.RegisterLauncher()
	if LDB then
		local r, g, b = IconTint()
		broker = LDB:NewDataObject(ADDON, {
			type = "launcher",
			text = BrokerText(),
			icon = ICON,
			iconR = r, iconG = g, iconB = b,
			OnClick = function(owner, mouseButton) LauncherClick(owner, mouseButton) end,
			OnTooltipShow = FillLauncherTooltip,
		})
		if LDBIcon and broker then
			LDBIcon:Register(ADDON, broker, ns.db.profile.minimap)
		end
	end
	ns.Guard("addon compartment", RegisterCompartment)
end

-- Put the current state back into the launcher's text and its icon's colour.
-- LibDataBroker fires its own change callback when a field on a data object is
-- assigned, so every display showing this launcher repaints from here. Called
-- through ns.RepaintOptions, and by Core whenever the favour count changes.
function ns.RefreshBrokerText()
	local text = BrokerText()
	-- The compartment builds its menu from the registered tables each time it
	-- opens, so a plain assignment is all it takes.
	if compartment then compartment.text = text end
	if not broker then return end
	-- Only when it has actually changed: assigning wakes every display showing
	-- it, and this is reached at both ends of every fight.
	if broker.text ~= text then broker.text = text end
	-- The tint the same way, one channel at a time: LibDBIcon repaints the
	-- icon on each of the three.
	local r, g, b = IconTint()
	if broker.iconR ~= r then broker.iconR = r end
	if broker.iconG ~= g then broker.iconG = g end
	if broker.iconB ~= b then broker.iconB = b end
end

-- LibDBIcon keeps the table it was handed at Register, and AceDB hands out a
-- different one per profile -- so after a switch the checkbox and the button
-- read different tables, and a drag saves the position into the old one.
-- Refresh does the whole job: re-points the table, repositions from the new
-- minimapPos, and shows or hides to match the new hide.
function ns.RefreshMinimapButton()
	if not (LDBIcon and LDBIcon.Refresh and LDBIcon:IsRegistered(ADDON)) then return end
	LDBIcon:Refresh(ADDON, ns.db.profile.minimap)
end
