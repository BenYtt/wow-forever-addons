-- Manners -- the prompt button's scripts other than the press (Press.lua): the
-- drag, the cursor coming onto the panel and leaving it, and the tooltip.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local RemainingText = lib.RemainingText
local OnPreClick, OnPostClick = lib.OnPreClick, lib.OnPostClick
local OnRowPreClick, OnRowPostClick = lib.OnRowPreClick, lib.OnRowPostClick

-- Whether a drag actually started. The client delivers OnDragStop for every
-- drag gesture, including the ones OnDragStart refused (locked, in combat).
local dragging

-- Ends a move under way: the frame let go, where it landed saved, and the
-- prompt locked. Shared by the release and by a fight arriving mid-drag, which
-- must leave the prompt in the same place.
local function FinishDrag()
	dragging = nil
	R.button:StopMovingOrSizing()
	local point, _, relPoint, x, y = R.button:GetPoint()
	local p = ns.db.profile.prompt
	-- The client returns the offsets in the frame's scaled units; the profile
	-- keeps UIParent's. The frame's own scale is the one it was moved at, not
	-- p.scale, which can be ahead of the frame: a Scale slider moved in a fight
	-- waits for the fight to end before ApplyStyle applies it.
	local okScale, s = pcall(R.button.GetScale, R.button)
	if not okScale or type(s) ~= "number" or s <= 0 then s = p.scale end
	p.point, p.relPoint = point, relPoint
	p.x, p.y = math.floor(x * s + 0.5), math.floor(y * s + 0.5)

	-- Lock straight after a drag: an unlocked prompt cannot cast, and looks
	-- just like a working one with nobody to offer.
	p.locked = true
	Prompt:ApplyStyle()
	-- The options page is usually open for this; repaint it so its Locked box
	-- and position controls match.
	ns.RepaintOptions()
	ns.addon:Print(L["moved and locked."])
end

-- The tooltip's lines about one person: why they are offered, and what the
-- game would say about the buff on them.
local function PersonTooltipLines(entry, brief)
	-- A top-up reads as one, and "missing it" only where it was read as
	-- missing; "Always offer" and unreadable auras get the plain reason.
	local left = RemainingText(entry.remaining)
	local why
	if entry.reason == "owed" then
		why = L["Buffed you -- return the favour."]
	elseif entry.reason == "self" then
		-- Offered to you only on a reading (Queue.lua): missing, or low.
		why = left and L["Your own buff, and yours is running out."]
			or L["Your own buff, and you are missing it."]
	elseif entry.reason == "asked" then
		why = L["Asked you for it in chat."]
	elseif left then
		why = entry.reason == "group" and L["In your group, and theirs is running out."]
			or entry.reason == "target" and L["Your target, and theirs is running out."]
			or L["Nearby, and theirs is running out."]
	elseif entry.known == false then
		why = entry.reason == "group" and L["In your group and missing it."]
			or entry.reason == "target" and L["Your target, and missing it."]
			or L["Nearby and missing it."]
	else
		why = entry.reason == "group" and L["In your group."]
			or entry.reason == "target" and L["Your target."]
			or L["Nearby."]
	end
	GameTooltip:AddLine(why, 0.7, 0.7, 0.7, true)
	-- The short tooltip says why and no more.
	if brief then return end
	-- Why they are ahead of the others like them, where Who comes first
	-- put them there. Only ever set for a group member or a passer-by.
	if entry.close == "friend" then
		GameTooltip:AddLine(L["On your friends list."], 0.7, 0.7, 0.7, true)
	elseif entry.close == "guild" then
		GameTooltip:AddLine(L["In your guild."], 0.7, 0.7, 0.7, true)
	end
	-- Why they are ahead of everybody but your target.
	if entry.sweep == "readycheck" then
		GameTooltip:AddLine(L["A ready check was called, so your party or raid comes first until the pull."], 0.7, 0.7, 0.7, true)
	elseif entry.sweep == "revived" then
		GameTooltip:AddLine(L["Just came back from the dead, which costs every buff."], 0.7, 0.7, 0.7, true)
	end
	if left then
		GameTooltip:AddLine(entry.reason == "self" and L["Yours expires in %s."]:format(left)
			or L["Theirs expires in %s."]:format(left), 0.7, 0.7, 0.7, true)
		-- How long it lasts and why now rather than sooner or later: only a top-up
		-- has a lead (Queue.lua), and only where the length is known.
		if entry.duration and entry.lead then
			GameTooltip:AddLine(L["It lasts %s and is topped up when %s are left."]
				:format(ns.TimeText(entry.duration), ns.TimeText(entry.lead)), 0.7, 0.7, 0.7, true)
			local kind = ns.LEAD_KINDS[entry.leadKind]
			local why = kind == "raid" and L["In a raid or dungeon, so earlier than usual."]
				or kind == "own" and L["Your own buff, so earlier than usual."]
				or kind == "ownraid" and L["Your own buff in a raid or dungeon, so earlier still."]
				or kind == "stranger" and L["Not in your group, so only at the last moment."]
			if why then GameTooltip:AddLine(why, 0.7, 0.7, 0.7, true) end
		end
	end
	-- And why the rest of the group is missing from the queue, when it is.
	local kept, resume = ns.SavingMana()
	if kept then
		-- Your own buff among what is kept, where "Myself" is on: this line
		-- may be under your own entry.
		GameTooltip:AddLine((ns.OffersSelf()
			and L["Saving mana: until you are back to %d%% mana, only your own buff and people who buffed you or asked are offered."]
			or L["Saving mana: until you are back to %d%% mana, only people who buffed you or asked are offered."])
			:format(resume), 1, 0.82, 0, true)
	end
	if entry.checked and entry.known == nil then
		GameTooltip:AddLine(L["Buff state unreadable on this build -- they may already have it."],
			1, 0.5, 0.5, true)
	elseif not entry.checked then
		GameTooltip:AddLine(L["Not checking whether they have it -- set by your options."],
			0.7, 0.7, 0.7, true)
	end
end

-- The tooltip's lines about a group cast (GroupBuffs.lua): who it is for, any
-- favour it returns on the way, and the reagent it eats, counted now.
local function GroupTooltipLines(entry, group, brief)
	local single = ns.BuffName(entry.buff)
	local missing, low = group.missing or 0, group.low or 0
	-- Missing and running out apart: "missing" after a wipe means something
	-- different from a top-up before a pull.
	-- One person is "is", not "are": a group cast is offered from two people
	-- who need it, so one can be missing it and one running out.
	local count
	if group.class then
		if missing == 1 then
			count = L["1 of that class in your party or raid is missing %s."]:format(single)
		elseif missing > 0 then
			count = L["%d of that class in your party or raid are missing %s."]:format(missing, single)
		elseif low == 1 then
			count = L["1 of that class in your party or raid is running out of %s."]:format(single)
		else
			count = L["%d of that class in your party or raid are running out of %s."]:format(low, single)
		end
	else
		local label = group.label or "?"
		if missing == 1 then
			count = L["1 in %s is missing %s."]:format(label, single)
		elseif missing > 0 then
			count = L["%d in %s are missing %s."]:format(missing, label, single)
		elseif low == 1 then
			count = L["1 in %s is running out of %s."]:format(label, single)
		else
			count = L["%d in %s are running out of %s."]:format(low, label, single)
		end
	end
	GameTooltip:AddLine(count, 0.7, 0.7, 0.7, true)
	if brief then return end
	if missing > 0 and low > 0 then
		GameTooltip:AddLine(low == 1 and L["1 more is running out."] or L["%d more are running out."]:format(low),
			0.7, 0.7, 0.7, true)
	end
	GameTooltip:AddLine(group.class
		and L["One cast gives it to %s in your party or raid."]:format(group.label or "?")
		or L["One cast gives it to everybody in %s."]:format(group.label or "?"), 0.7, 0.7, 0.7, true)
	-- Whoever of them buffed you: this cast returns their favour too.
	local now, owedNames = GetTime(), {}
	local function Note(name)
		local debt = name and ns.owed and ns.owed[name]
		if debt and ns.DebtExpiry(debt) > now then owedNames[#owedNames + 1] = ns.ShortName(name) end
	end
	Note(entry.name)
	for _, name in ipairs(group.members) do Note(name) end
	if #owedNames > 0 then
		GameTooltip:AddLine(L["It returns the favour to %s as well."]:format(table.concat(owedNames, ", ")),
			1, 0.78, 0.3, true)
	end
	-- Forever's Reagent Economy: the cast uses none (GroupBuffs.lua).
	if group.reagentWaived then
		GameTooltip:AddLine(L["No reagent needed."], 0.7, 0.7, 0.7, true)
		return
	end
	local have = ns.ReagentCount(group.reagent) or group.reagents
	local item = ns.ReagentName(group.reagent)
	if item then
		GameTooltip:AddLine(L["Uses one %s -- you have %d."]:format(item, have), 0.7, 0.7, 0.7, true)
	else
		GameTooltip:AddLine(L["Uses one reagent -- you have %d."]:format(have), 0.7, 0.7, 0.7, true)
	end
end

-- How much of the tooltip the player's setting gives right now: "full", "short"
-- or nil for none. Shift always opens the full one, and is all that opens it
-- under "only while holding Shift". Read at every hover and every change of
-- Shift, so a setting changed in the options is followed at the next one.
local function ShiftHeld()
	return IsShiftKeyDown ~= nil and ns.plain(IsShiftKeyDown()) == true
end

local function TooltipDepth()
	local mode = ns.db.profile.prompt.tooltip
	if mode == "off" then return nil end
	if mode == "full" or ShiftHeld() then return "full" end
	if mode == "shift" then return nil end
	return "short"
end

-- Where the tooltip goes. "Where the game shows tooltips" hands it to the
-- client's own default anchor. Otherwise it sits above or below the prompt's
-- whole block -- the button and the list hung on one side of it -- on the side
-- with more room on the screen, so it never covers either. It is anchored to
-- the button, whichever name in the list it is about, and nothing here touches
-- the secure frame. Without a measurable button (no screen yet) the old anchor.
local TIP_GAP = 6

local function PlaceTooltip(owner, fallback)
	if ns.db.profile.prompt.tooltipPosition == "game" and type(GameTooltip_SetDefaultAnchor) == "function" then
		GameTooltip_SetDefaultAnchor(GameTooltip, owner)
		return
	end
	local button = R.button
	local top, bottom = button and button:GetTop(), button and button:GetBottom()
	local screen = UIParent:GetHeight()
	if type(top) ~= "number" or type(bottom) ~= "number" or type(screen) ~= "number" then
		GameTooltip:SetOwner(owner, fallback)
		return
	end
	-- UIParent's units, which the room is counted in; the button's own, which
	-- the list's reach and the offset are in.
	local own, ui = button:GetEffectiveScale(), UIParent:GetEffectiveScale()
	local ratio = (type(own) == "number" and type(ui) == "number" and ui > 0) and own / ui or 1
	local depth = Prompt:ListDepth()
	local listAbove = S.queueAbove and true or false
	local roomAbove = screen - (top * ratio + (listAbove and depth * ratio or 0))
	local roomBelow = bottom * ratio - (listAbove and 0 or depth * ratio)
	local above = roomAbove >= roomBelow
	-- Offsets are read in the tooltip's own units, not the button's.
	local tipScale = GameTooltip:GetEffectiveScale()
	local toTip = (type(own) == "number" and type(tipScale) == "number" and tipScale > 0) and own / tipScale or 1
	local reach = TIP_GAP + (above == listAbove and depth or 0)
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	if above then
		GameTooltip:SetPoint("BOTTOM", button, "TOP", 0, reach * toTip)
	else
		GameTooltip:SetPoint("TOP", button, "BOTTOM", 0, -reach * toTip)
	end
end

-- Shift, watched while the cursor is on the prompt or a name in the list and
-- only then (MODIFIER_STATE_CHANGED registered on enter, dropped on leave), and
-- only under the two settings Shift changes anything for. A change runs the
-- hovered frame's own OnEnter again, which settles what to show.
local watcher, watched, watchedHeld

local function ShiftChanged()
	local owner = watched
	if not owner then return end
	local held = ShiftHeld()
	if held == watchedHeld then return end
	watchedHeld = held
	-- The hovered frame's own OnEnter holds back in a fight.
	local onEnter = owner:GetScript("OnEnter")
	if onEnter then onEnter(owner) end
end

local function WatchShift(owner)
	local mode = ns.db.profile.prompt.tooltip
	if mode == "full" or mode == "off" then
		-- Nothing Shift could change. Whatever was watched stays until leave.
		return
	end
	if not watcher then
		watcher = CreateFrame("Frame")
		watcher:SetScript("OnEvent", function() ns.Guard("tooltip shift", ShiftChanged) end)
	end
	if not watched then watcher:RegisterEvent("MODIFIER_STATE_CHANGED") end
	if watched ~= owner then watchedHeld = ShiftHeld() end
	watched = owner
end

local function UnwatchShift(owner)
	if not watched or (owner and watched ~= owner) then return end
	watched, watchedHeld = nil, nil
	watcher:UnregisterEvent("MODIFIER_STATE_CHANGED")
end

-- The button's other scripts, and the list Create() sets them from. A do
-- block, so their names cost the main chunk one local rather than five.
local BUTTON_SCRIPTS, ROW_SCRIPTS
do
	local function OnDragStart(self)
		if ns.db.profile.prompt.locked or InCombatLockdown() then return end
		self:StartMoving()
		dragging = true
	end

	-- Only a drag that started has anything to end: the release arrives for the
	-- refused ones too. A drag still held when a fight starts was ended then
	-- (FinishDragForFight), so one released in combat only forgets itself.
	local function OnDragStop()
		if not dragging then return end
		if InCombatLockdown() then
			dragging = nil
			return
		end
		FinishDrag()
	end

	-- The tooltip about the person `S.current` is: what the prompt says of whoever
	-- it is armed at, and what a name in the list says of the name it holds
	-- (OnRowEnter, which hands in a state of its own whose `current` is that
	-- entry). `slot` is whose settled spoken line it quotes (S, or the row's).
	local function FillTooltip(owner, fallback, S, slot, depth)
		local brief = depth == "short"
		PlaceTooltip(owner, fallback)
		if not brief then GameTooltip:AddLine("Manners") end
		GameTooltip:AddDoubleLine(S.current.display or S.current.short or S.current.name,
			ns.EntrySpellName(S.current), 1, 1, 1, 0.8, 0.8, 0.8)
		-- One cast for many says who it covers and what it costs; the one
		-- person's reading is not the story there.
		if S.current.groupCast then
			GroupTooltipLines(S.current, S.current.groupCast, brief)
		else
			PersonTooltipLines(S.current, brief)
		end
		-- The short one ends here, with what the rest takes.
		if brief then
			GameTooltip:AddLine(L["Hold Shift for more"], 0.5, 0.5, 0.5)
			GameTooltip:Show()
			return
		end
		GameTooltip:AddLine(" ")
		-- Plain English first; the raw macro only with /manners clicks, below.
		-- ClickSummary quotes the settled roll.
		for _, line in ipairs(Prompt:ClickSummary(S.current, slot)) do
			GameTooltip:AddLine(line, 0.62, 0.78, 0.62, true)
		end
		GameTooltip:AddLine(" ")
		-- The raw macro is a debugging tool and reads like one, so it goes
		-- where the other debugging tools are. /manners clicks turns it back
		-- on.
		if ns.db.profile.debugClicks and ns.lastMacro and not slot.isRow then
			GameTooltip:AddLine(L["Will run:"], 0.5, 0.5, 0.5)
			for line in ns.lastMacro:gmatch("[^\r\n]+") do
				GameTooltip:AddLine("  " .. line, 0.4, 0.8, 0.4)
			end
			GameTooltip:AddLine(" ")
		end
		-- The command goes in as an argument, as it does in PreClick's lines:
		-- it is typed in English whatever the client's language.
		GameTooltip:AddLine(L["Click to cast. %s for options."]:format("|cffffd100/manners|r"),
			0.5, 0.5, 0.5)
		-- A gesture nobody can discover is not a feature.
		-- A group cast is skipped whole, and "never" lists only the person it
		-- is aimed at (OnPostClick), which the lines say rather than leave to
		-- a guess.
		local group = S.current.groupCast
		GameTooltip:AddLine(group and L["Right-click to skip this group buff for now."]
			or L["Right-click to skip this one."], 0.5, 0.5, 0.5)
		-- Somebody already on the list is only here because they are owed, and
		-- for them the same press lets that favour go. You never are: your
		-- own name on the list takes your own buff off (Queue.lua).
		if ns.IsNeverOffered and ns.IsNeverOffered(S.current.name) then
			GameTooltip:AddLine(L["Shift-right-click to let this favour go."], 0.5, 0.5, 0.5)
		elseif group then
			GameTooltip:AddLine(L["Shift-right-click to put %s on your never-offer list."]
				:format(S.current.short or S.current.name or "?"), 0.5, 0.5, 0.5)
		elseif S.current.reason == "self" then
			-- The switch, since the list is of other people (StopOfferingSelf).
			GameTooltip:AddLine(L["Shift-right-click to stop offering you your own buff."], 0.5, 0.5, 0.5)
		else
			GameTooltip:AddLine(L["Shift-right-click to put them on your never-offer list."], 0.5, 0.5, 0.5)
		end
		GameTooltip:Show()
	end

	-- Whether the panel is up as something to drag, which is when RefreshPanel
	-- paints "Drag to move": on, unlocked, with something to cast, and no
	-- preview or fight over it. The one tooltip it has says what the panel's
	-- two short lines have no room for.
	local function DragPanelUp()
		local db = ns.db.profile
		return db.enabled and not db.prompt.locked and not S.testMode and not InCombatLockdown()
			and ns.CanCastAnything()
	end

	local function DragTooltip(owner)
		GameTooltip:SetOwner(owner, "ANCHOR_TOP")
		GameTooltip:AddLine("Manners")
		GameTooltip:AddLine(L["Drag to move"], 1, 0.82, 0)
		GameTooltip:AddLine(L["Let go and it locks itself"], 0.7, 0.7, 0.7, true)
		GameTooltip:AddLine(L["not buffing while unlocked"], 1, 0.5, 0.5, true)
		GameTooltip:Show()
	end

	-- Whether to show anything of the tooltip of `owner` (the prompt or a name
	-- in the list), and how much. Nothing hides the one this owner has up.
	local function ShowTip(owner, fallback, state, slot)
		local depth = TooltipDepth()
		if not depth then
			if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
			return
		end
		FillTooltip(owner, fallback, state, slot, depth)
	end

	local function OnEnter(self)
		-- First, whatever the tooltip does: the cursor is on the panel, and
		-- the hold and the fuse wait for it (see hovering). OnUpdate calls
		-- this again only while the tooltip is ours, so still hovering. On a
		-- look drawn by Prompt/Panel.lua the bezel lifts.
		if not S.activeLook then Prompt:HoverBezel(true) end
		S.hovering = true
		if S.activeLook then S.activeLook:Hover(true) end
		WatchShift(self)
		-- Nobody is armed while it is unlocked, so there is no person to
		-- describe: the tooltip is about the drag instead.
		if DragPanelUp() then
			DragTooltip(self)
			return
		end
		-- Nothing armed is nothing to describe, and a tooltip left from the
		-- last person goes with it.
		if not S.current or not S.current.buff then
			if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
			return
		end
		-- In combat the macro is frozen at whoever it held when the fight
		-- started, and a detailed tooltip about somebody stale is worse than
		-- none.
		if InCombatLockdown() then return end
		ShowTip(self, "ANCHOR_TOP", S, S)
	end

	local function OnLeave(self)
		UnwatchShift(self)
		GameTooltip:Hide()
		if S.activeLook then S.activeLook:Hover(false) end
		if not S.activeLook then Prompt:HoverBezel(false) end
		-- The hold and the fuse kept their clocks while the cursor was on the
		-- panel, so whatever ran out meanwhile is put right now rather than at
		-- the next scan. Next frame rather than here: the client sends this
		-- as a repaint hides the button, from inside that repaint.
		if not S.hovering then return end
		S.hovering = nil
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function() ns.Guard("leave repaint", Prompt.Refresh, Prompt) end)
		end
	end

	-- Keep the tooltip honest if the entry changes while it is open, checked a
	-- few times a second.
	local function OnUpdate(self, elapsed)
		self.sinceCheck = (self.sinceCheck or 0) + elapsed
		if self.sinceCheck < 0.2 then return end
		self.sinceCheck = 0
		if not GameTooltip:IsOwned(self) then return end
		-- The drag tooltip has nobody behind it and stays while the panel is
		-- still up to be dragged; once it is locked, the rest of this applies.
		if DragPanelUp() then return end
		if not (S.current and S.current.buff) then
			self.tooltipFor = nil
			GameTooltip:Hide()
			return
		end
		-- Keyed on everything the tooltip says, not the name alone: the same
		-- person can move to another buff, become owed, or get a re-rolled
		-- line.
		local shown = table.concat({ S.current.name, S.current.buff.key, tostring(S.current.reason),
			tostring(S.phraseText), tostring(S.appliedKey) }, "\1")
		-- And whether a ready check or a death put them first, and whether
		-- mana is being saved: both come and go while the same person stays
		-- on the panel, since the owed and the asked are never held back.
		shown = shown .. "\1" .. tostring(S.current.sweep) .. "\1" .. tostring((ns.SavingMana()))
		if self.tooltipFor ~= shown then
			self.tooltipFor = shown
			local onEnter = self:GetScript("OnEnter")
			if onEnter then onEnter(self) end
		end
	end

	-- A name in the list (Prompt/Rows.lua): the cursor lights it and says who it
	-- is, in the prompt's words. Nothing in a fight, where the list says nothing
	-- and a row does nothing (no existing line says the list waits for the
	-- fight to end, and none is made up for it).
	local function OnRowEnter(self)
		local row = self.mannersRow
		row.hovered = true
		WatchShift(self)
		if InCombatLockdown() then return end
		if row.wash then row.wash:Show() end
		local entry = row.entry
		if not (entry and entry.buff) then return end
		ShowTip(self, "ANCHOR_RIGHT", { current = entry }, row)
	end

	local function OnRowLeave(self)
		local row = self.mannersRow
		row.hovered = nil
		UnwatchShift(self)
		if row.wash then row.wash:Hide() end
		if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
	end

	-- In the order Create() always set them.
	BUTTON_SCRIPTS = {
		{ "OnDragStart", OnDragStart },
		{ "OnDragStop", OnDragStop },
		{ "PreClick", OnPreClick },
		{ "PostClick", OnPostClick },
		{ "OnEnter", OnEnter },
		{ "OnLeave", OnLeave },
		{ "OnUpdate", OnUpdate },
	}

	-- A list row's, set on each of them by Create (Rows.lua).
	ROW_SCRIPTS = {
		{ "PreClick", OnRowPreClick },
		{ "PostClick", OnRowPostClick },
		{ "OnEnter", OnRowEnter },
		{ "OnLeave", OnRowLeave },
	}
end

-- A drag still held when a fight starts is ended here, from
-- PLAYER_REGEN_DISABLED just before the lockdown: the release will come in the
-- fight, where the move can be neither stopped nor saved.
function Prompt:FinishDragForFight()
	if not dragging or not R.button or InCombatLockdown() then return end
	FinishDrag()
end

lib.BUTTON_SCRIPTS = BUTTON_SCRIPTS
lib.ROW_SCRIPTS = ROW_SCRIPTS
