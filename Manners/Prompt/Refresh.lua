-- Manners -- the prompt's repaint, which every scan ends in, and the preview.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local HideQueue, Substitute, SetLine, ShowChip = lib.HideQueue, lib.Substitute, lib.SetLine, lib.ShowChip
local ClearHold, LightFuse, NoteVerdicts, Retired = lib.ClearHold, lib.LightFuse, lib.NoteVerdicts, lib.Retired
local CursorHolds, ArmingForFight, EMPTY_FUSE_SECONDS = lib.CursorHolds, lib.ArmingForFight, lib.EMPTY_FUSE_SECONDS
local FullEffects, OutroAlpha, EntryIcon = lib.FullEffects, lib.OutroAlpha, lib.EntryIcon

-- Who was last painted on the panel, by name, and why they were on it.
local lastTop, lastTopReason
-- The newest favour stamp a repaint has seen, and how old a favour can be and
-- still count as just done; one first seen late is not news.
local seenDebtAt
local ARRIVAL_SECONDS = 3

-- The floor between two sounds. Without it the sound is tied to the name
-- changing, and the name changing is exactly what churns.
local SOUND_FLOOR_SECONDS = 3
local lastSoundAt

local function TestEntry()
	return {
		name = "Preview",
		short = "|cffffd100" .. L["PREVIEW"] .. "|r",
		class = "PRIEST",
		reason = "owed",
		buff = ns.ResolveBuff(true),
		known = false,
	}
end

local TEST_SECONDS = 20

-- `line` is the whole chat line for a preview that ended on its own, written
-- where the reason is known so each reason is one sentence to translate.
-- `quiet` ends it without one, for a caller that says what happened itself:
-- unlocking, where "Drag to move" replaces the mock-up on the panel.
function Prompt:ExitTest(line, quiet)
	if not S.testMode then return end
	S.testMode, S.testExpiry = false, nil
	self:ApplyTarget(nil)
	if not quiet then ns.addon:Print(line or L["preview off."]) end
	-- Every way a preview ends comes through here, so this tells an open
	-- options page that its button reads "Preview" again.
	if ns.RepaintOptions then ns.RepaintOptions() end
end

-- Read by the options page to label its button.
function Prompt:InTest()
	return S.testMode == true
end

function Prompt:ToggleTest()
	if S.testMode then
		self:ExitTest()
		self:Refresh()
		return
	end
	-- Time-limited, because a preview left on looks like a working prompt; the
	-- clock stops while the options window is open. Not in a fight: the panel
	-- cannot be put up, and an armed macro would still cast under "PREVIEW".
	if InCombatLockdown() then
		ns.addon:Print(L["|cffff8080not during a fight|r -- the preview can be shown once it ends."])
		return
	end
	-- Refresh stands a mock-up aside when somebody real is waiting, so ask
	-- first, with Refresh's own test word for word, rather than start a preview
	-- that would end on its first pass. The options window holds one up anyway.
	local db = ns.db and ns.db.profile
	-- Except while snoozed: nobody real is on a snoozed prompt, so a preview
	-- there stands in front of nobody. Refresh makes the same exception.
	if db and db.enabled and db.prompt.locked and not InCombatLockdown()
		and not ns.SnoozeLeft() and not (ns.OptionsOpen and ns.OptionsOpen())
		and #ns.BuildQueue() > 0 then
		ns.addon:Print(L["somebody real is on the prompt, so there is nothing to preview -- open |cffffd100/manners|r to style it; a preview holds while that window is open."])
		return
	end
	S.testMode = true
	S.testExpiry = GetTime() + TEST_SECONDS
	self:ApplyTarget(nil)
	self:Refresh()
	-- Should Refresh stand it aside after all, it has said so itself, and
	-- repainted on the way out.
	if not S.testMode then return end
	-- The options page's button now has to read "Stop preview"; see ExitTest.
	if ns.RepaintOptions then ns.RepaintOptions() end
	ns.addon:Print(L["preview on -- it stays while the options window is open, then %ds longer, or |cffffd100/manners test|r to stop."]
		:format(TEST_SECONDS))
end

-- Show and Hide are protected, and in combat the client refuses both silently.
-- `false` means the panel stayed where the fight found it.
local function SetPanelShown(want)
	if InCombatLockdown() then return false end
	if want then R.button:Show() else R.button:Hide() end
	return true
end

-- The outro belongs to one branch (an outcome over an empty queue); every
-- other repaint cancels it and brings the panel back from where it had got.
function Prompt:Refresh()
	if not R.button or not ns.db then return end
	self.outroWanted = nil
	local fadedTo = OutroAlpha()
	self:RefreshPanel()
	if not self.outroWanted then self:ComeBack(fadedTo) end
	-- Last, over everything the repaint changed: the bar macro follows the
	-- panel's words and whether it is up, not only the button (Clicks.lua,
	-- click macro). Nothing is asked of the client while nothing changed.
	ns.SyncMacroBody()
end

-- Listing somebody repaints the prompt at once, whatever the route, so the
-- macro is not left armed at them until the next scan. Core loads first.
do
	local putOnNeverList = ns.PutOnNeverList
	if putOnNeverList then
		ns.PutOnNeverList = function(name, typed)
			local listed = putOnNeverList(name, typed)
			if listed then ns.Guard("never repaint", Prompt.Refresh, Prompt) end
			return listed
		end
	end
end

function Prompt:RefreshPanel()
	local db = ns.db.profile
	if not db then return end
	local p = db.prompt

	local now = GetTime()

	-- The combat dim comes off here, above every early return: it means "the
	-- button cannot be pointed at anybody new", which is true exactly while the
	-- lockdown is.
	if not InCombatLockdown() then self:SetCombatHold(false) end

	-- Nothing to cast on anybody, yourself included: a hunter with an aspect
	-- learned has a prompt, for his own.
	if not ns.CanCastAnything() and not S.testMode then
		-- Disarmed like every branch that hides the panel: a probe that
		-- answered nothing for a moment (a client still loading spell data)
		-- left the last person's macro on the binding, and a fight froze it.
		-- Ahead of the off and snooze branches, so they never got to.
		self:ApplyTarget(nil)
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		-- SPELLS_CHANGED can land mid-fight, and the panel cannot come down
		-- then.
		if not SetPanelShown(false) then
			self:PaintHeldInert(
				L["nothing this character can cast -- a press still casts what the fight froze"],
				L["nothing this character can cast -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if S.testMode then
		-- While the options window is open the clock is pushed on and somebody
		-- real does not end it, so the prompt can be styled in a city.
		local styling = ns.OptionsOpen and ns.OptionsOpen()
		if styling then
			S.testExpiry = now + TEST_SECONDS
		elseif S.testExpiry and now > S.testExpiry then
			self:ExitTest(L["preview off -- timed out."])
		elseif db.enabled and p.locked and not InCombatLockdown() and not ns.SnoozeLeft(now)
			and #ns.BuildQueue() > 0 then
			-- Somebody real is waiting. Never let a mock-up stand in front of
			-- an actual person who just buffed you.
			self:ExitTest(L["preview off -- somebody real turned up."])
		end
	end

	if S.testMode then
		-- Preview is a disarm, asked again on every pass: one started in combat
		-- could only clear `current`, and the first pass after the fight must
		-- clear the macro for real.
		self:ApplyTarget(nil)
		-- A preview started in a fight paints on whatever the fight left: a
		-- hidden panel stays hidden until it ends. Everything below is art and
		-- runs anyway.
		if not R.button:IsShown() and SetPanelShown(true) then
			self:PlayIntro()
		end
		-- Mock rows with mock reasons, since the reason bar is being styled
		-- too. The count covers every row listed, as a real one does: each
		-- row below is somebody else waiting.
		local mock, reasons = {}, { "owed", "group", "nearby", "nearby", "nearby" }
		local test = TestEntry()
		-- Nobody real in a mock row, so none of it can be pressed (no entry);
		-- the icon is drawn as a real row's would be.
		local icon = p.showIcon and EntryIcon(test) or nil
		for i = 1, (p.showQueue and p.queueRows or 0) do
			mock[i] = { text = L["Someone %d"]:format(i), reason = reasons[i], icon = icon }
		end
		self:Paint(test, math.max(2, #mock))
		self:StartAttention(false)
		-- Not in a fight: the list's lines are what each name's button is
		-- anchored to (Rows.lua), and the client will not have a frame that a
		-- secure frame hangs from moved in combat.
		if not InCombatLockdown() then self:PaintQueue(mock) end
		return
	end

	-- Ahead of the unlocked branch: an unlocked prompt must obey /manners off.
	if not db.enabled then
		self:ApplyTarget(nil)
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		-- In a fight the macro under the name could not be cleared; say so.
		if not SetPanelShown(false) then
			self:PaintHeldInert(L["switched off -- a press still casts what the fight froze"],
				L["switched off -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if not p.locked then
		self:ApplyTarget(nil)
		self:StopAttention()
		HideQueue()
		ClearHold()
		if SetPanelShown(true) then
			SetLine(R.nameText, "|cffffd100" .. L["Drag to move"] .. "|r")
			S.outcomePainted = nil
			-- What happens next, in the look's own reason-line colour: the
			-- red warning this used to be said something was wrong, and
			-- nothing is. "not buffing while unlocked" is the tooltip's
			-- (Button.lua).
			if R.subText:IsShown() then SetLine(R.subText, L["Let go and it locks itself"]) end
			ShowChip(false)
			R.countText:SetText("")
			R.resultFill:Hide()
			self:UngreyIcon()
			if S.activeLook then S.activeLook:ClearOutcome() end
			self:PaintAccent("owed")
		else
			-- "Drag to move" is refused in a fight too (OnDragStart gives up on
			-- lockdown), so say what the panel is instead.
			self:PaintHeldInert(L["unlocked -- a press still casts what the fight froze"],
				L["unlocked -- nothing armed, and the panel cannot go"])
		end
		return
	end

	if InCombatLockdown() then
		-- The panel cannot leave the screen, and blanking the art (or a
		-- visibility driver) would leave an invisible button that still casts
		-- from its binding. So this branch says true things on art.

		-- Switched off and on (or unlocked and locked) inside the fight: the
		-- macro still names the person the fight froze, so the bookkeeping
		-- must too. Not pointing `current` at somebody new: it is the same one.
		if not S.current and S.frozenEntry and R.button:GetAttribute("macrotext1") then
			S.current = S.frozenEntry
		end

		-- The pulse claims somebody is still owed, and the debt can expire or
		-- be settled mid-fight.
		local debt = S.current and S.current.name and ns.owed[S.current.name]
		if not S.current or S.current.reason ~= "owed" or not debt or ns.DebtExpiry(debt) <= now then
			self:StopAttention()
		end

		-- The panel is frozen at whoever was on it when the fight started, so
		-- it must not look live: the dim, the blanked list and the line all say
		-- it is held.
		self:SetCombatHold(true)
		HideQueue()
		-- Asked for rather than assumed: a missing method would take the whole
		-- scan tick with it.
		if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(R.button) then
			GameTooltip:Hide()
		end
		-- A click still works in combat, so its outcome wins over the held
		-- line. Art only: a panel the fight found hidden stays hidden.
		if self:OutcomeLive() and not p.hideInCombat then
			self:PaintOutcome()
		else
			-- Repainted from `current`, the frozen macro's identity, so an
			-- expired outcome's headline does not stand over the next person's
			-- macro.
			if S.current then
				SetLine(R.nameText, self:RenderPrimary(S.current, 0))
				S.outcomePainted = nil
				-- The ring as well: a refusal turned it red, and the name
				-- line is not the only thing the flash wrote over.
				self:PaintAccent(S.current.reason)
				if R.subText:IsShown() then
					SetLine(R.subText, "|cffb0b0b0" .. L["held -- in combat"] .. "|r")
				end
				-- No count: it is a claim about the queue this branch just
				-- blanked.
				ShowChip(false)
				R.countText:SetText("")
			else
				-- The commonest way in: a click emptied the queue and a fight
				-- started with nobody on the panel, so the click's green
				-- headline would otherwise stand for the whole fight over an
				-- empty button.
				self:PaintHeldInert(L["held -- a press still casts what the fight froze"],
					L["held -- nothing armed, and the panel cannot go"])
			end
		end
		return
	end

	-- Snoozed, below the combat branch: a snooze started in a fight waits for
	-- it to end, when the panel can come down.
	if ns.SnoozeLeft(now) then
		self:ApplyTarget(nil)
		R.button:Hide()
		S.outcomePainted = nil
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		return
	end

	-- With the cursor on the panel, every verdict written down (see
	-- BuildQueue), so the cursor's hold can tell the dead from the unseen.
	local queue, verdicts = ns.BuildQueue(S.hovering)
	NoteVerdicts(verdicts)
	local top = self:PickTop(queue, queue[1])
	S.pickedFrom = queue

	if not top then
		-- An empty queue in a crowd is usually a gap, so the first empty scan
		-- lights a short fuse and a refill puts it out. Nobody retired gets
		-- one. Nothing is disarmed while it burns: a panel on screen must stay
		-- clickable for the person it names.
		local retired = Retired(S.current, now)

		if self:OutcomeLive() then
			-- The click is what empties the queue, so its confirmation nearly
			-- always lands here. Disarmed: PostClick files nothing without a
			-- current entry, so the button is inert for the half second it
			-- stays up.
			self:ApplyTarget(nil)
			R.button:Show()
			self:StopAttention()
			HideQueue()
			self:PaintOutcome()
			lastTop = nil
			ClearHold()
			-- Nobody left: fade over the second half of the confirmation. The
			-- hide is still the repaint the outcome's own timer asks for.
			if FullEffects() then
				self.outroWanted = true
				self:PlayOutro(S.outcomeAt)
			end
			return
		end

		-- No fuse on the pull's own pass (see ArmingForFight): it would freeze
		-- the dropped person's macro for the whole fight.
		if R.button:IsShown() and S.current and not retired and not ArmingForFight() then
			LightFuse(now)
			-- Kept on the panel, though the queue no longer holds them: the
			-- reading the spoken line was armed on went with it, so the macro
			-- is armed without the line and the tooltip quotes none. The press
			-- judges the line again (Press.lua, HoldLine). Undone at once below
			-- when the fuse has burnt out.
			self:ApplyTarget(S.current, true)
			-- Nor does it burn out under the cursor (see hovering): the
			-- player is on the way to clicking it. OnLeave repaints. Not
			-- when the queue emptied on a verdict, theirs or your own state
			-- (see CursorHolds).
			if CursorHolds(S.current, now) then return end
			if now - S.emptyAt < EMPTY_FUSE_SECONDS then return end
		end

		self:ApplyTarget(nil)
		R.button:Hide()
		S.outcomePainted = nil
		self:StopAttention()
		HideQueue()
		lastTop = nil
		ClearHold()
		return
	end
	S.emptyAt = nil

	-- Who else is waiting, which of them are listed, and whether the pick is in
	-- the queue: counted, not read off queue order, because the pick is not
	-- always queue[1] (ties keep the current one; a held one may be absent).
	local rows, others, inQueue = {}, 0, false
	local wanted = (p.showQueue and p.queueRows) or 0
	for _, entry in ipairs(queue) do
		if entry.name == top.name then
			-- The queue's own entry, not merely the name: a paint of the copy
			-- the hold kept is never a paint from the queue.
			inQueue = inQueue or entry == top
		else
			others = others + 1
			if #rows < wanted then
				-- The name and the words apart: PaintQueue colours the words
				-- for the look it is painting in.
				rows[#rows + 1] = {
					text = Substitute("{name}", entry, 0),
					detail = self:ReasonText(entry),
					reason = entry.reason,
					-- The entry itself: a click on the name presses it as it
					-- stands (Rows.lua), and the icon of what it offers is
					-- drawn at the row's left.
					entry = entry,
					icon = p.showIcon and EntryIcon(entry) or nil,
				}
			end
		end
	end

	-- Armed once the count above says whether the pick is the queue's own
	-- entry. A copy the hold kept carries the reading of a scan the latest one
	-- overruled, so it is armed without the spoken line, and the tooltip
	-- quotes none; the press judges the line again (Press.lua, HoldLine).
	self:ApplyTarget(top, not inQueue)

	local wasHidden = not R.button:IsShown()
	local isNew = top.name ~= lastTop
	-- The moment somebody becomes owed, which includes a passer-by already on
	-- the panel who then buffs you.
	local becameOwed = top.reason == "owed" and (isNew or lastTopReason ~= "owed")
	lastTop = top.name
	lastTopReason = top.reason
	-- Narrower again: the favour itself was only just done, keyed on the debt's
	-- own stamp. A favour first seen while somebody else was on the panel is
	-- not news when its giver reaches the top later.
	local newest = seenDebtAt
	for _, owed in pairs(ns.owed or {}) do
		if type(owed) == "table" and type(owed.at) == "number"
			and owed.at > (newest or -math.huge) then
			newest = owed.at
		end
	end
	local debt = top.reason == "owed" and ns.owed and ns.owed[top.name]
	local debtAt = type(debt) == "table" and type(debt.at) == "number" and debt.at or nil
	local arrived = debtAt ~= nil and debtAt > (seenDebtAt or -math.huge)
		and now - debtAt <= ARRIVAL_SECONDS
	seenDebtAt = newest

	-- Stamped where the panel is painted, not where the pick is made (PreClick
	-- picks too). Renewed by paints from the queue, never by a paint the hold
	-- itself produced, or somebody long gone would own the prompt. A paint
	-- from the queue is a fresh start for the cursor's hold as well: whoever
	-- a scan turned down is back (see heldTurnedDown).
	if inQueue or not S.heldEntry then S.heldAt, S.heldTurnedDown = now, nil end
	S.heldEntry = top

	self:Paint(top, others)
	R.button:Show()

	if wasHidden then
		self:PlayIntro()
		-- A panel coming up part-way through a global cooldown shows what is
		-- left of it; the cast that started it was sent while it was down.
		self:SyncCooldown()
	elseif isNew then
		self:SwapText()
	end

	-- A floor under the sound as well as the name: a swapped name can be
	-- ignored, a sound cannot. And the flash's filter: both exist to make you
	-- look, so they agree about who is worth it -- where anybody can be owed:
	-- a class with no buffs to give (a hunter's aspects) files no favour, and
	-- "Only for people who buff me", on out of the box, silenced it for good.
	-- With that filter on, the flash's own moment sounds too: a passer-by
	-- already on the panel who then buffs you is not a new name.
	if (isNew or (becameOwed and db.sound.owedOnly)) and db.sound.enabled
		and (not db.sound.owedOnly or top.reason == "owed"
			or not (ns.caps and ns.caps.hasClassBuffs == true and db.sources.owed ~= false))
		and not (lastSoundAt and (now - lastSoundAt) < SOUND_FLOOR_SECONDS) then
		lastSoundAt = now
		ns.Guard("prompt sound", ns.PlayPromptSound, db.sound.file)
	end

	if top.reason == "owed" then
		self:StartAttention(becameOwed, arrived)
	else
		self:StopAttention()
	end

	self:PaintQueue(rows)

	-- Last, over all of it: the outcome belongs to the press just made.
	if self:OutcomeLive() then
		self:PaintOutcome()
	else
		-- Nothing live, so nothing grey: the outcome ends only in OutcomeLive
		-- and MovedOn, and each gives the icon its colour back as it does.
		R.resultFill:Hide()
		if S.activeLook then S.activeLook:ClearOutcome() end
	end
end

-- Says on the panel that the pause is the game's, on the sub-line only: the
-- person is still the one being offered.
function Prompt:SayWaiting(left)
	if not R.button or not R.subText then return end
	if InCombatLockdown() then return end
	-- The colour rides in the string: set on the font string it would stay
	-- after the wait. Rounded up, so a refused press never reads "ready in
	-- 0.0s".
	ns.Guard("waiting line", function()
		SetLine(R.subText, "|cffb8b8c7" .. L["ready in %.1fs"]:format(
			math.max(0.1, math.ceil((left or 0) * 10) / 10)) .. "|r")
	end)
end

function Prompt:GetButton()
	return R.button
end

-- The entry the panel is armed at, or nil with no panel up or a preview
-- showing. Read by the launcher's tooltip and menu.
function Prompt:Showing()
	if not R.button or S.testMode or not R.button:IsShown() then return nil end
	return S.current
end
