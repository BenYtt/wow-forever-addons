-- Manners -- what became of a press: the click parked until the game says
-- whether a cast went out, what that settles or rewinds, the global cooldown,
-- and the /click macro the options page offers.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Queue.lua's, which load first.
local plain, safecall, caps, SpellNameFor = ns.plain, ns.safecall, ns.caps, ns.SpellNameFor
local owed, LiveExpiry, SaveDebts = ns.owed, ns.DebtExpiry, ns.SaveDebts
local TellLedger, ListedAs = ns.TellLedger, ns.ListedAs

---------------------------------------------------------------------------
-- the pending click and its settle
---------------------------------------------------------------------------

-- The game reports on casts directly. UNIT_SPELLCAST_SENT firing at all means
-- the macro resolved a target and tried; its absence means no clause matched.
-- UI_ERROR_MESSAGE carries a reason for something, not necessarily for ours.
-- A click parks its debt in ns.pendingClick, and one of four outcomes resolves
-- it: a cast event settles it, an error rewinds what it wrote, a second press
-- abandons it as unknown, and the clock running out says nothing was cast.

-- How long a parked click waits for the game to answer: latency plus a wide
-- margin. One number, so the settle, the abandon and the sweep agree on when
-- a record is dead.
local SETTLE_SECONDS = 2

-- How late a cast event can still be this press's own answer: an accepted
-- cast reports in the same frame, a queued one within the spell-queue window
-- (0.4 s by default, the floor here; a player who set it wider gets that
-- window plus a margin, in SettlePendingClick). Anything later is a hand on
-- the action bar, and on this client that event names nobody.
-- SETTLE_SECONDS still decides when a record is dead.
local SENT_SECONDS = 0.5

-- Said the same way wherever a click comes to nothing: "still owed" only of
-- somebody who is, "was not buffed" only where something says so. `unknown`
-- (a format string handed the name) is the line for somebody not owed when
-- nothing does -- a press abandoned before the game answered, whose cast may
-- yet land -- and `unknownSelf` that line for a press on yourself.
local function SayStillOwed(name, why, unknown, unknownSelf)
	local db = addon.db and addon.db.profile
	if not (db and db.verbose) then return end
	local debt = owed[name]
	if debt and LiveExpiry(debt) > GetTime() then
		addon:Print(L["|cffff8080%s is still owed|r -- %s."]:format(name, why))
	elseif ns.IsPlayerName(name) then
		-- A press on yourself: your name in the third person reads as somebody
		-- else who shares it. Asked before `unknown`, which names the person.
		addon:Print(unknown and unknownSelf or L["|cffff8080you were not buffed|r -- %s."]:format(why))
	elseif unknown then
		addon:Print(unknown:format(name))
	else
		addon:Print(L["|cffff8080%s was not buffed|r -- %s."]:format(name, why))
	end
end

-- The outcome of a click on the panel as well as in chat. Three honest kinds:
-- "cast" is the game naming the person we aimed at, "sent" is our spell going
-- out with the client not saying who got it, and "failed" is reason to believe
-- nothing reached them. Guarded: cosmetic, and must not take the settle with it.
local function ShowOutcome(kind, name, detail)
	if not (ns.Prompt and ns.Prompt.ShowOutcome and name) then return end
	ns.Guard("prompt outcome", ns.Prompt.ShowOutcome, ns.Prompt, kind, name, detail)
end

-- Did the id the game reported belong to the buff we armed? Every rank and the
-- raid-wide version count. nil (the client would not say) settles: one secret
-- value must not make every favour permanent.
local function SpellIsOurs(spellId, buffKey)
	if spellId == nil or not buffKey then return true end
	-- One of your class's own (Buffs.lua, VANILLA_OWN): its ranks, or any
	-- spell by the name the macro cast, since that is what the game picked
	-- the rank by -- a rank the table lacks is still the press's own cast.
	local own = ns.FindOwnSpell(buffKey)
	-- A mage's scroll by the spell its use casts, which two scrolls can share
	-- (Buffs.lua, Spellbreak), so neither the lookup nor the name will do.
	if own and own.item then return own.ranks[1] == spellId end
	if own then
		return ns.OWN_BY_ID[spellId] == own or SpellNameFor(spellId) == ns.BuffName(own)
	end
	local buff = ns.FindBuff(caps.class, buffKey)
	if not buff then return true end
	return ns.BUFF_BY_ID[spellId] == buff
end

-- A spell id as somebody reads it; the number where the client will not name it.
local function SpellLabel(spellId)
	return SpellNameFor(spellId) or tostring(spellId)
end

-- Nothing reached them, so what the click optimistically wrote is cut back:
-- the whole-person block to two seconds (so the prompt does not march down
-- their list), the per-buff cooldown to the same, and the rotation pointer
-- put back. One owner for all three, or a refused cast walks somebody off
-- their own buff list.
local function RewindClick(pending)
	-- Extends only, so a right-press skip written moments earlier outlives it.
	ns.BlockPerson(pending.name, 2, true)
	-- Not extend-only: cutting back what this click wrote is the point.
	ns.MarkAttempted(pending.name, pending.buffKey, 2)
	-- The rotation pointer as the click found it (nil for a first one), behind
	-- the gate the click went through.
	if ns.RotatesBuffs() then ns.lastGave[pending.name] = pending.gave end
	-- A group cast blocked everybody it covered; none of them got it either.
	if pending.group then
		for _, name in ipairs(pending.group.members) do
			ns.MarkAttempted(name, pending.buffKey, 2)
		end
	end
end

-- The first-name fallback is gone on purpose (STATUS.md). It switched a
-- macro to `/target <first name>` after failed casts, but the full name was
-- confirmed to resolve in game, and its failure mode is the worst on offer: a
-- cast and a spoken line aimed at another player sharing a first name. A cast
-- that does not land is now reported instead. CHANGELOG 1.3.0 asks for both
-- spellings; do not rebuild it from there.

-- Retiring a record whose window has run out, wherever that is noticed. One
-- owner, so a record is never discarded without rewinding what the click
-- wrote. What the user is told is the caller's (`why`): the settle path holds
-- a late cast event, proof a spell went out, just not this press's. Only
-- SweepPendingClick, watching the window run out, writes the panel.
local function ExpirePendingClick(pending, why)
	ns.pendingClick = nil
	-- An error inside the window already rewound this record and said so;
	-- RewindClick writes from now, so running it twice doubles the block.
	if pending.answered then return end
	RewindClick(pending)
	-- Nothing reached them, so a spoken line the macro carried (and ran
	-- anyway) is held; a silent press holds nothing, or the press that lands
	-- once they are back would go out silent too. No back-off, since nothing
	-- here says the game refused them.
	ns.NoteRefusal(pending.name, nil, true, pending.spoke)
	SayStillOwed(pending.name, why or L["the game answered that press with nothing at all"])
end

-- A second press while the first is still waiting for the game. There is one
-- slot, and the next cast event would be judged against the newest record, so
-- the first is abandoned: what it did is unknown, not failed, so what it wrote
-- is put back and the debt stays. Wrong that way costs one extra offer; wrong
-- the other way loses the favour.
local function AbandonPendingClick()
	local pending = ns.pendingClick
	if not pending then return end
	-- Answered already, by an error that rewound it and said so.
	if pending.answered then
		ns.pendingClick = nil
		return
	end
	-- Past its window the outcome is known, and only the tick has not come
	-- round yet; the slot is about to be reused, so it is retired now.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending)
		return
	end
	ns.pendingClick = nil
	SayStillOwed(pending.name, L["another press arrived before the game answered that one"],
		L["no answer yet for the press on |cffffffff%s|r -- another press arrived first."],
		L["no answer yet for the press on yourself -- another press arrived first."])
	RewindClick(pending)
end
ns.AbandonPendingClick = AbandonPendingClick

-- An error the game raised just after a click: evidence something failed,
-- none about what (full bags and all the rest), so it takes back what the
-- click wrote and no more. The record stays parked: a cast going out after
-- all still settles it. Returns the name it rewound, for the panel; nothing
-- without a live click parked, or for a second error.
local function FailPendingClick(message)
	local pending = ns.pendingClick
	if not pending then return nil end
	-- Past its window this error cannot be about that click, but the record
	-- still needs retiring; the panel gets nothing.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending)
		return nil
	end
	if pending.answered then return nil end
	pending.answered = true
	-- The game's sentence brings its own full stop, and this line adds one.
	SayStillOwed(pending.name, type(message) == "string"
		and L["the game said: %s"]:format((message:gsub("%.$", ""))) or L["the game refused it"])
	RewindClick(pending)
	ns.NoteRefusal(pending.name, message, nil, pending.spoke)
	return pending.name
end

-- The clock running out on a parked click: a record that sat the whole window
-- saw no cast event, the one proof that nothing went out. Swept on the tick,
-- because in this case there is no next event.
local function SweepPendingClick(now)
	local pending = ns.pendingClick
	if not pending then return end
	if now - pending.at <= SETTLE_SECONDS then return end
	ExpirePendingClick(pending)
	-- An error answered this press inside its window, and the panel flashed
	-- the game's own words then.
	if pending.answered then return end
	-- The panel only from here: this is the one path that notices the window
	-- running out as it happens. The other callers find the record long dead,
	-- with the panel moved on (or mid-arming, inside PostClick).
	ShowOutcome("failed", pending.name, L["nothing was cast"])
end
ns.SweepPendingClick = SweepPendingClick

-- What an inferred settle is inferring, read by both the chat line and the
-- panel so they make the same claim. `said` finishes "X counted as repaid --
-- " and is handed the spell's name; `sub` goes under the name on the prompt.
-- A confirmed settle (the client naming the person) has nothing to qualify.
local SETTLE_INFERENCE = {
	targeted = {
		said = L["our spell went out and the macro aimed at them, but this client would not say who received it"],
		sub = L["cast -- this client will not confirm who to"],
	},
	selfcast = {
		said = L["%s is cast on you, not on them, so whether it reached them depends on where they were standing"],
		sub = L["cast -- it has no target, so nothing says it reached them"],
	},
}

-- Settled casts still inside the window in which the server may refuse them,
-- oldest first. See UnsettleLateRefusal.
local settledRecent = {}

-- A refusal is matched to the cast it answers by the cast guid, and only by
-- it: UNIT_SPELLCAST_SENT carries it third, UNIT_SPELLCAST_FAILED second. A
-- spell id cannot tell a new attempt (a mashed press, the same buff from an
-- action bar) from the answer to one that landed, so no guid is no evidence,
-- and no evidence means no action. Whether this client fills the guid in is
-- untested (STATUS.md); if not, a real late refusal goes unnoticed and the
-- favour stays repaid -- quieter, never a false sentence.
local function PruneSettled(now)
	now = now or GetTime()
	for i = #settledRecent, 1, -1 do
		local record = settledRecent[i]
		if now - record.at > SETTLE_SECONDS then
			table.remove(settledRecent, i)
			-- Nothing refused it inside the window, so it landed, and whatever the
			-- game refused on this person before is over. Not at the settle
			-- itself: SENT is the client sending, and the refusal that repeats
			-- comes after it.
			if record.landed then ns.NoteLanded(record.name) end
		end
	end
end
ns.PruneSettled = PruneSettled

local function RememberSettled(record)
	PruneSettled(record.at)
	settledRecent[#settledRecent + 1] = record
end

-- A mage's scroll or a weapon enhancement (Buffs.lua) is the one press on
-- yourself with a cast time: every scroll's use takes three seconds
-- (SpellMisc's CastingTimeIndex 14), and so does a stone's, an oil's and a
-- poison's, a lure's five (index 6; two on Mists), where your other own buffs
-- are instant. SENT settles it as the cast starts, so a cast cut short --
-- moving, most often -- has used nothing up, and only INTERRUPTED (or a FAILED
-- after the settle's window) says so. The press is kept here until the cast
-- succeeds or stops, or for its length, pushback and latency at most: the item,
-- the settle's record, its cast, and the press it replaced (Core.lua,
-- NoteScrollPress). Six seconds for a scroll; eight for an enhancement, whose
-- longest use is the lure's five.
local SCROLL_SECONDS = 6
local ENHANCE_SECONDS = 8
local castingScroll

-- The scroll being cast, if this event is about it: by the cast guid where
-- both sides carry one, else by the spell its use casts (nil `spellId` asks
-- for the guid alone). One cast runs at a time, so an interrupt or a success
-- with the scroll's spell is its. A cast past its length is let go.
local function ScrollCast(castGUID, spellId)
	local cast = castingScroll
	if not cast then return nil end
	if GetTime() - cast.record.at > cast.seconds then
		castingScroll = nil
		return nil
	end
	if cast.castGUID ~= nil and castGUID ~= nil then
		if cast.castGUID ~= castGUID then return nil end
	elseif spellId == nil or spellId ~= cast.spellId then
		return nil
	end
	return cast
end

-- The scroll's cast cut short: the press is taken back as a refused one is
-- (RewindClick), and the scroll is offered again once that block is out.
-- Out of the settled list too, which would note it as landed. Returns the
-- name, for the panel.
local function ScrollCastStopped(castGUID, spellId, why)
	local cast = ScrollCast(castGUID, spellId)
	if not cast then return nil end
	castingScroll = nil
	for i, record in ipairs(settledRecent) do
		if record == cast.record then
			table.remove(settledRecent, i)
			break
		end
	end
	RewindClick(cast.record)
	ns.UndoScrollPress(cast.spell, cast.before)
	SayStillOwed(cast.record.name, why)
	return cast.record.name
end

-- Which record a refusal answers, or nil for "nothing here says". A record
-- that settled with no guid of its own never compares equal to one, so a guid
-- on the refusal side alone matches nothing either.
local function MatchSettled(castGUID)
	if castGUID == nil then return nil end
	for i, record in ipairs(settledRecent) do
		-- Both sides named the cast. That is an answer, not a guess, and a
		-- guid naming none of ours means the failure was not ours at all.
		if record.castGUID == castGUID then return i end
	end
	return nil
end

-- Everybody else one cast reached (`names`), on the same evidence as the
-- person it was aimed at: a favour any of them did you is returned by it, the
-- ledger filing each with `covered`, whatever they asked for is answered, and
-- they wait out the cooldown. Returns what a late refusal needs to undo it,
-- and the names repaid, for the line.
local function SettleMembers(names, pending, covered, spellId)
	local records, repaid = {}, {}
	for _, name in ipairs(names) do
		local debt = owed[name]
		ns.MarkAttempted(name, pending.buffKey)
		if debt then
			ns.SettleFavour(name)
			TellLedger("Settled", name, debt, covered, spellId)
			repaid[#repaid + 1] = ns.ShortName(name)
		end
		ns.ServeRequest(name, pending.buffKey)
		records[#records + 1] = { name = name, owed = debt,
			listedAtSettle = debt ~= nil and ListedAs(name) ~= nil }
	end
	return records, repaid
end

local function SayAlsoRepaid(spell, repaid)
	local db = addon.db and addon.db.profile
	if #repaid > 0 and db and db.verbose then
		addon:Print(L["|cffffd100%s|r returned the favour to %s as well."]:format(
			spell, table.concat(repaid, ", ")))
	end
end

-- Everybody else a group cast covered (SettleMembers). The favours go to the
-- ledger, and the cast itself once, as one buff given: under the anchor
-- normally, but where the anchor's own favour took that row (`anchorOwed`),
-- under the first it reached who was owed nothing -- or who was picked as the
-- anchor would decide whether a group cast counts. Returns what a late
-- refusal needs to undo it: the members, and whom the given row is under.
local function SettleGroup(pending, spellId, anchorOwed)
	local covered = { buffKey = pending.buffKey, group = pending.group, inGroup = true }
	local records, repaid = SettleMembers(pending.group.members, pending, covered, spellId)
	local givenAs
	if anchorOwed then
		for _, record in ipairs(records) do
			-- Never under your own name: the cast covered you too, but a buff
			-- on yourself is no gift to anybody (see SettleSelf).
			if not record.owed and not ns.IsPlayerName(record.name) then
				givenAs = record.name
				TellLedger("Settled", givenAs, nil, covered, spellId)
				break
			end
		end
	end
	SayAlsoRepaid(SpellLabel(pending.group.spell), repaid)
	return records, givenAs
end

-- Everybody else a shout reached: the party members the press's scan measured
-- inside its reach (Prompt/Press.lua). A shout lands on the whole party,
-- so it returns every favour in earshot -- left owed, they were offered a
-- second shout, then let go as run out. Each goes to the ledger as a plain
-- return; one shout is one cast, under the anchor. Returns what a late
-- refusal needs to undo it, as SettleGroup does. `names`, when given, is
-- everybody else a cast on one of them reached on Mists and retail
-- (pending.wideMembers), settled the same way.
local function SettleShout(pending, spellId, names)
	local records, repaid = SettleMembers(names or pending.shoutMembers, pending,
		{ buffKey = pending.buffKey, inGroup = true }, spellId)
	local buff = pending.buffKey and ns.FindBuff(caps.class, pending.buffKey)
	SayAlsoRepaid((spellId and SpellNameFor(spellId)) or (buff and ns.BuffName(buff)) or L["the spell"],
		repaid)
	return records
end

-- A late refusal of a group cast or a shout: the favours it returned are owed
-- again, as the anchor's is, and the ledger takes back each by the settle's
-- clock.
local function UnsettleGroup(settled)
	-- The cast's own given row, where it was filed under one of them.
	if settled.givenAs then TellLedger("Refused", settled.givenAs, settled.at) end
	for _, member in ipairs(settled.members or {}) do
		-- A shout's members were put on the retry cooldown by its settle, not
		-- by the press, so RewindClick (which knows a group cast's) misses them.
		if not settled.group then ns.MarkAttempted(member.name, settled.buffKey, 2) end
		if member.owed then
			TellLedger("Refused", member.name, settled.at)
			if not member.listedAtSettle and ListedAs(member.name) then
				-- Listed since: let go, as the anchor's is (see below).
				TellLedger("LetGo", member.name, "never")
			else
				local standing = owed[member.name]
				if not standing or LiveExpiry(standing) < LiveExpiry(member.owed) then
					owed[member.name] = member.owed
				end
			end
		end
	end
	SaveDebts()
end

-- A press on yourself ([@player]): nobody else can have been reached, so our
-- spell going out is the whole answer. A buff on yourself is no favour and no
-- gift, so the ledger (and with it the milestones and In character's memory),
-- the debts and the requests are not told; the retry cooldown and the rotation
-- pointer are. Kept for a late refusal like any settle, which backs you off as
-- it would anybody.
local function SettleSelf(pending, spellId, castGUID)
	ns.pendingClick = nil
	if not SpellIsOurs(spellId, pending.buffKey) then
		local why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
		SayStillOwed(pending.name, why)
		RewindClick(pending)
		ShowOutcome("failed", pending.name, (why:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
		return
	end
	ShowOutcome("cast", pending.name)
	ns.MarkAttempted(pending.name, pending.buffKey)
	-- Behind the same gate as everybody's: a paladin's walk never reads it.
	if ns.RotatesBuffs() and pending.buffKey then ns.lastGave[pending.name] = pending.buffKey end
	-- An error inside the window told chat you were not buffed
	-- (FailPendingClick); the cast went out after it, so that is taken back,
	-- as it is for anybody, or chat and the panel disagree. Only with
	-- verbose, where it was said.
	if pending.answered then
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			addon:Print(L["|cffffd100you were buffed after all|r -- the error before it was about something else."])
		end
	end
	local record = { name = pending.name, buffKey = pending.buffKey,
		gave = pending.gave, at = GetTime(), castGUID = castGUID,
		landed = true, onSelf = true }
	RememberSettled(record)
	-- A scroll: its cast has only begun (castingScroll), and which one it is
	-- tells two scrolls making the same imbue apart (Core.lua, ImbueScroll).
	local own = ns.FindOwnSpell(pending.buffKey)
	if own and own.item then
		castingScroll = { record = record, spell = own, castGUID = castGUID, spellId = spellId,
			before = ns.NoteScrollPress(own),
			seconds = own.family.enhance and ENHANCE_SECONDS or SCROLL_SECONDS }
	end
end

local function SettlePendingClick(landedOn, spellId, castGUID)
	local pending = ns.pendingClick
	if not pending then return end
	-- A cast with no unit to aim at (on Forever the mage's Arcane Brilliance, the
	-- priest's Prayers and the druid's Gift of the Wild: target 56, the caster's
	-- raid) has no name to report, and the event's target is a cstring that cannot
	-- be nil, so it reads "". That names nobody: it is "the client would not say",
	-- as a withheld name is, not a person the cast went to.
	if landedOn == "" then landedOn = nil end
	-- Past the window this cast belongs to something else (an accepted cast
	-- answers in the same frame), so the record is retired, not settled -- with
	-- its own sentence, since something was cast, just too late to be this.
	if GetTime() - pending.at > SETTLE_SECONDS then
		ExpirePendingClick(pending,
			L["the game never answered that press, and this cast came too late to be its answer"])
		return
	end

	-- Inside the window, but too late to be this press's answer (SENT_SECONDS,
	-- or the player's own queue window where that is wider -- a press queued
	-- that far out casts when the cooldown ends): no evidence either way, so
	-- the sweep still owns the record.
	local late = math.min(SETTLE_SECONDS, math.max(SENT_SECONDS, ns.SpellQueueWindow() + 0.1))
	if GetTime() - pending.at > late then return end

	if pending.onSelf then return SettleSelf(pending, spellId, castGUID) end

	local ours = SpellIsOurs(spellId, pending.buffKey)

	-- `why` is the reason this favour is still owed, nil if it is not.
	-- `inferred` is nil where the client itself named the person, otherwise
	-- which inference carries the settle: the panel and chat say which.
	local why, inferred
	-- Our shout went out, but nothing measured them inside its reach.
	local unheard = false
	if pending.selfCast then
		-- A selfCast buff's macro has no /target line: the spell lands on the
		-- caster and reaches the party from there, so whether our own spell
		-- went out is the only thing to check. (This is every repayment a
		-- warrior can make.)
		if not ours then
			why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
		else
			-- Inferred, never confirmed: nothing ties the shout to the person
			-- but where they were standing. Where no signal measured them within
			-- reach, the press counts but the favour is kept.
			inferred = "selfcast"
			unheard = not pending.withinShout
		end
	-- A /target for a name the game cannot resolve is a no-op, and the cast
	-- goes to whoever was already targeted. Four spellings are accepted as the
	-- person: the one the macro aimed at, the key, the bare first name and
	-- the name without a cross-realm suffix.
	elseif landedOn and landedOn ~= pending.aimedAt
		and landedOn ~= pending.name
		and landedOn ~= (ns.FirstName and ns.FirstName(pending.name))
		and landedOn ~= (ns.ShortName and ns.ShortName(pending.name)) then
		-- Somebody else got it: our /target did nothing.
		why = L["it went to |cffffffff%s|r"]:format(tostring(landedOn))
	elseif not ours then
		-- Right person, wrong spell: anything else on a bar can beat the
		-- macro's own /cast to the click.
		why = L["|cffffffff%s|r went out instead"]:format(SpellLabel(spellId))
	elseif landedOn then
		-- Our spell, and the client named the person we aimed at: the one
		-- confirmed settle, empty on purpose (`why` and `inferred` both nil).
	elseif pending.targeted then
		-- Our spell, and the client would not say who got it, which is the
		-- ordinary answer here. The macro's /target of ours at this person,
		-- recorded at press time, carries the inference; the verbose line
		-- says it is one.
		inferred = "targeted"
	else
		-- Our spell went out to nobody known, and the macro aimed at nobody (a
		-- /manners try template): nothing ties the press to the person.
		why = L["this client would not say who received it, and the macro aimed at nobody"]
	end

	if why then
		SayStillOwed(pending.name, why)
		RewindClick(pending)
		-- The macro's line thanked them for a buff that went elsewhere or never
		-- went, so it is held (a silent press held nothing); no back-off,
		-- since the game refused nobody.
		ns.NoteRefusal(pending.name, nil, true, pending.spoke)
		ns.pendingClick = nil
		-- The chat line's sentence, without colour codes: the sub-line is
		-- already tinted, and a nested one renders as literal text.
		ShowOutcome("failed", pending.name, (why:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
		return
	end

	-- Read before SettleFavour clears it: an undo puts back the entry that
	-- stood, including when the favour was done, which the grace window reads.
	local wasOwed = owed[pending.name]

	if unheard and wasOwed and pending.outOfShout then
		SayStillOwed(pending.name, L["the shout went out, but they were too far away to hear it"])
	elseif unheard and wasOwed then
		SayStillOwed(pending.name, L["the shout went out, but nothing could tell whether they were close enough to hear it"])
	elseif inferred and wasOwed then
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			local buff = pending.buffKey and ns.FindBuff(caps.class, pending.buffKey)
			addon:Print(L["|cffffd100%s counted as repaid|r -- %s."]:format(pending.name,
				SETTLE_INFERENCE[inferred].said:format(buff and ns.BuffName(buff) or L["the spell"])))
		end
	elseif pending.answered then
		-- An error inside the window said this person was not buffed; this cast went
		-- out after it, so that is taken back (with verbose, where it was said).
		local db = addon.db and addon.db.profile
		if db and db.verbose then
			local line = wasOwed and L["|cffffd100%s counted as repaid after all|r -- the error before it was about something else."]
				or inferred and L["|cffffd100the spell for %s went out after all|r -- the error before it was about something else."]
				or L["|cffffd100%s was buffed after all|r -- the error before it was about something else."]
			addon:Print(line:format(pending.name))
		end
	end

	-- "cast" only where the client named the person; "sent" for an inference.
	local how = inferred and SETTLE_INFERENCE[inferred]
	ShowOutcome(how and "sent" or "cast", pending.name, how and how.sub)

	-- Put back what PostClick wrote, which an error inside the window may have
	-- rewound; written unconditionally, as what a landed cast leaves behind.
	ns.MarkAttempted(pending.name, pending.buffKey)
	if pending.buffKey and ns.RotatesBuffs() then
		ns.lastGave[pending.name] = pending.buffKey
	end

	if not unheard then ns.SettleFavour(pending.name) end
	if not unheard then ns.ServeRequest(pending.name, pending.buffKey) end
	if not unheard then TellLedger("Settled", pending.name, wasOwed, pending, spellId) end
	-- A group cast settles everybody else it covered with the same evidence.
	-- A shout is never one, so `unheard` cannot be true here.
	local members, givenAs
	if pending.group then members, givenAs = SettleGroup(pending, spellId, wasOwed ~= nil) end
	-- A shout settles everybody else measured inside its reach, even with the
	-- one it was aimed at unheard: each was measured on their own. Our shout
	-- went out, or `why` above returned.
	if pending.selfCast and pending.shoutMembers then members = SettleShout(pending, spellId) end
	-- A cast that landed on the whole party and raid (Mists, retail) settles
	-- everybody else in it the press's scan offered it, as a shout does.
	if pending.wideMembers then members = SettleShout(pending, spellId, pending.wideMembers) end
	-- The client sent the cast; the server has not answered yet. Keep the
	-- record so a refusal arriving a moment from now has something to be about.
	-- Whether they were on the never-offer list already, which a favour owed
	-- ignores (STATUS.md); only a listing after the settle lets it go.
	RememberSettled({ name = pending.name, buffKey = pending.buffKey,
		gave = pending.gave, at = GetTime(), owed = wasOwed, castGUID = castGUID,
		listedAtSettle = ListedAs(pending.name) ~= nil, spoke = pending.spoke,
		-- A shout nothing measured them inside of is not a cast on them.
		landed = not unheard,
		group = pending.group, members = members, givenAs = givenAs })
	ns.pendingClick = nil
end

-- A refusal arriving after the settle let the record go: SENT is the client
-- sending, not the server taking it, and out of range or line of sight come
-- back a moment later, so the record is kept SETTLE_SECONDS. Driven by
-- UNIT_SPELLCAST_FAILED alone: UI_ERROR_MESSAGE carries no spell id. Returns
-- the name, for the panel.
local function UnsettleLateRefusal(castGUID)
	PruneSettled()
	-- No match is no evidence about a cast that settled, and does nothing.
	local index = MatchSettled(castGUID)
	if not index then return nil end

	-- Consumed before anything is undone with it: one refusal, one cast. A
	-- scroll's cast is over with it, and so is the press it noted.
	local settled = table.remove(settledRecent, index)
	if castingScroll and castingScroll.record == settled then
		ns.UndoScrollPress(castingScroll.spell, castingScroll.before)
		castingScroll = nil
	end

	-- Nothing for a switched-off addon. Only `enabled`: the owed source
	-- decides only whether there was a debt, and settled.owed says that.
	local db = addon.db and addon.db.profile
	if not db or not db.enabled then return nil end

	-- Everybody else a group cast covered, whichever way the anchor goes
	-- below; RewindClick puts back their cooldowns with the anchor's.
	if settled.members then UnsettleGroup(settled) end

	-- A shift-right-click since the settle let this favour go, and a refusal
	-- must not bring it back: owed people are exempt from the list. The row
	-- goes from returned back to let go, and nothing claims a debt still kept.
	local listed = settled.owed and not settled.listedAtSettle and ListedAs(settled.name)
	if listed then
		TellLedger("Refused", settled.name, settled.at)
		TellLedger("LetGo", settled.name, "never")
		RewindClick(settled)
		return settled.name
	end

	-- Written to disk, as SettleFavour's clearing was. A newer favour filed
	-- since is kept if it lasts longer: the refusal only means you still owe.
	if settled.owed then
		local standing = owed[settled.name]
		if not standing or LiveExpiry(standing) < LiveExpiry(settled.owed) then
			owed[settled.name] = settled.owed
		end
		SaveDebts()
	end
	TellLedger("Refused", settled.name, settled.at)
	RewindClick(settled)
	-- This is the refusal that repeats for somebody the game will never let
	-- you buff (beta.8): every press settles on SENT and comes back here.
	ns.NoteRefusal(settled.name, nil, nil, settled.spoke)
	SayStillOwed(settled.name, L["the game refused the cast after sending it"])
	return settled.name
end

-- The global cooldown, read where the client will say and tracked where not.
-- On the retail line Forever descends from, spell 61304 IS the global
-- cooldown for every class, and addons on Forever read it (EnhanceQoL's
-- GCD bar); Classic Era and Burning Crusade Classic have no such spell, and
-- GlobalCooldownReading reads one of our buffs instead. It may be withheld, in
-- a fight most of all, so the fallback tracks it: once a cast is sent, nothing
-- else casts for about 1.5 seconds.
local GCD_FALLBACK = 1.5
local GCD_SPELL = 61304
local castBlockedUntil = 0
-- When the tracked block began, for the prompt's sweep where the client
-- gives no figure.
local castBlockedFrom = 0
-- The spell whose cast began the tracked block, for SPELL_UPDATE_COOLDOWN to ask
-- whether it is on the global cooldown at all. nil once the client has said.
local castBlockedBy

local function NoteCastWentOut(spellId)
	local now = GetTime()
	local seconds = GCD_FALLBACK

	-- C_Spell.GetSpellCooldown answers with a table, whose duration for an
	-- instant buff IS the global cooldown -- used only when readable and sane,
	-- since a secret or a zero would unblock the button at once. Its isOnGCD is
	-- not read here: the client documents the field as not to be trusted outside
	-- SPELL_UPDATE_COOLDOWN, and a cast that has only been sent has not started
	-- its cooldown yet, so a false now says nothing (and out of a fight it would
	-- leave a press 0.3 s on to go straight into a running cooldown). Every cast
	-- arms the guess; DropGuessOffGcd takes it back once the client can say.
	local get = C_Spell and C_Spell.GetSpellCooldown
	if get and spellId then
		local ok, info = pcall(get, spellId)
		if ok and type(info) == "table" then
			local duration = plain(info.duration)
			if type(duration) == "number" and duration > 0 and duration <= 3 then
				seconds = duration
			end
		end
	end

	-- Extended, never shortened: a second cast event inside a running cooldown
	-- can report a smaller figure of its own.
	if now + seconds > castBlockedUntil then
		castBlockedUntil = now + seconds
		castBlockedFrom = now
		castBlockedBy = spellId
	end
end

-- The guess taken back for a cast the client says is off the global cooldown (a
-- healthstone, a potion, a trinket): SPELL_UPDATE_COOLDOWN is the one moment
-- its isOnGCD is to be trusted, and it is the only word on the matter where the
-- client's own figure is withheld (a fight on Forever: the start and length are
-- secret, the flag is not). A false drops the guess; a true keeps it, and the
-- client is not asked again; nil, the client saying nothing, keeps it and asks
-- at the next event. A spell with a cooldown of its own that is also on the
-- global one reads false as well once its own begins, and nothing can tell
-- that from a spell off it: the guess goes, as it did when SENT read a false.
local function DropGuessOffGcd(now)
	local spellId = castBlockedBy
	if not spellId then return end
	-- Run out already, nothing left to take back.
	if castBlockedUntil <= now then
		castBlockedBy = nil
		return
	end
	local get = C_Spell and C_Spell.GetSpellCooldown
	if not get then return end
	local ok, info = pcall(get, spellId)
	if not ok or type(info) ~= "table" then return end
	local onGcd = plain(info.isOnGCD)
	if onGcd == nil then return end
	castBlockedBy = nil
	if onGcd == false then
		castBlockedUntil, castBlockedFrom = 0, 0
	end
end

-- How long before the global cooldown ends the client will accept a /cast and
-- hold it, casting on its own when the cooldown runs out: a press in that
-- window lands. The client's own setting, since players tune it; 400 ms is
-- the default on the retail line Forever descends from.
function ns.SpellQueueWindow()
	local get = _G.GetCVar
	if type(get) == "function" then
		local ok, value = pcall(get, "SpellQueueWindow")
		value = ok and tonumber(plain(value)) or nil
		if value and value >= 0 and value <= 1000 then return value / 1000 end
	end
	return 0.4
end

-- A spell's cooldown by the client's own figure, as a start and a length, or
-- nil where it gives none. An idle spell reads a zero start and duration: a
-- readable 0.
local function CooldownReading(spell)
	local get = C_Spell and C_Spell.GetSpellCooldown
	if not get then return nil end
	local ok, info = pcall(get, spell)
	if not ok or type(info) ~= "table" then return nil end
	local start, duration = plain(info.startTime), plain(info.duration)
	if type(start) ~= "number" or type(duration) ~= "number" then return nil end
	return start, duration
end

-- What is left of a spell's cooldown by that figure, or nil where it gives none.
local function CooldownLeft(spell, now)
	local start, duration = CooldownReading(spell)
	if not start then return nil end
	local left = start + duration - now
	if left < 0 then left = 0 end
	return left
end

-- The global cooldown by the client's own figure, as a start and a length, or
-- nil where it gives none. Spell 61304 stands for it where the client has the
-- spell. Classic Era and Burning Crusade Classic have no row for it in their
-- spell data: there the global cooldown is a property of each spell, and the
-- client's own action bars draw it from the spell's own cooldown. So one of our
-- buffs stands in, the first the player knows with a reading no longer than a
-- global cooldown (3 s, as NoteCastWentOut bounds it): none of them has a
-- cooldown of its own, and a longer one, a spell's own, never passes for the
-- global one. Asked only where 61304 says nothing, so a client that answers for
-- it is read exactly as before.
local function GlobalCooldownReading()
	local start, duration = CooldownReading(GCD_SPELL)
	if start then return start, duration end
	local buffs = caps.buffs
	for _, buff in ipairs(caps.class and ns.GetClassBuffs(caps.class) or {}) do
		local info = buffs and buffs[buff.key]
		local id = info and info.known and info.topRank
		if id then
			start, duration = CooldownReading(id)
			if start and duration <= 3 then return start, duration end
			-- A client that gives no figure for one of them gives none for the
			-- rest (every figure withheld in a fight), and the sweep asks at every
			-- cooldown update: one more read is all it costs there.
			if not start then break end
		end
	end
	return nil
end

-- ...and what is left of the global cooldown.
local function GlobalCooldownLeft(now)
	local start, duration = GlobalCooldownReading()
	if not start then return nil end
	local left = start + duration - now
	if left < 0 then left = 0 end
	return left
end

-- The global cooldown as a start and a length, for the sweep the prompt draws
-- over its icon, or nil when none is running. The same sources as CastReady,
-- so the sweep and the "ready in" line agree about when the button is ready.
local function GcdSpan(now)
	local start, duration = GlobalCooldownReading()
	if start then
		if duration > 0 and start + duration > now then return start, duration end
		return nil
	end
	if castBlockedUntil > now and castBlockedUntil > castBlockedFrom then
		return castBlockedFrom, castBlockedUntil - castBlockedFrom
	end
	return nil
end

function ns.GlobalCooldownSpan(now)
	now = now or GetTime()
	local start, duration = GcdSpan(now)
	-- The player's own cast, read exactly as CastReady reads it.
	local casting = _G.UnitCastingInfo
	if type(casting) == "function" then
		local ok, _, _, _, startMS, endMS = pcall(casting, "player")
		if ok then startMS, endMS = plain(startMS), plain(endMS) else startMS, endMS = nil, nil end
		if type(endMS) == "number" and endMS / 1000 > now
			and (not start or endMS / 1000 > start + duration) then
			local from = start or (type(startMS) == "number" and startMS / 1000) or now
			return from, endMS / 1000 - from
		end
	end
	return start, duration
end

-- Whether a press right now could reach the server, and how long until it
-- could, so the prompt can say so. A spell with a cast time (a conjure, a
-- Hearthstone) blocks a /cast past the global cooldown, so the player's own
-- cast is read too. Channels are left out: a new cast interrupts one.
--
-- `spell`, an id, adds that spell's own cooldown: the press asks it only to
-- decide the spoken line (Prompt/Press.lua), since a /cast of a spell still
-- cooling down reaches the server and is refused there.
function ns.CastReady(spell)
	local now = GetTime()
	-- The client's figure where it gives one, in place of the tracked guess
	-- (which a cast off the global cooldown arms wrongly), not beside it.
	local left = GlobalCooldownLeft(now) or (castBlockedUntil - now)
	local casting = _G.UnitCastingInfo
	if type(casting) == "function" then
		local ok, _, _, _, _, endMS = pcall(casting, "player")
		if ok then endMS = plain(endMS) else endMS = nil end
		if type(endMS) == "number" and endMS / 1000 - now > left then
			left = endMS / 1000 - now
		end
	end
	if spell then
		local own = CooldownLeft(spell, now)
		if own and own > left then left = own end
	end
	if left <= 0 then return true, 0 end
	return false, left
end

function addon:UNIT_SPELLCAST_SENT(_, unit, target, castGUID, spellId)
	if unit ~= "player" then return end
	NoteCastWentOut(plain(spellId))
	-- The sweep over the prompt's icon starts with the cooldown this cast
	-- began, whichever button sent it.
	if ns.Prompt and ns.Prompt.SyncCooldown then
		ns.Guard("cooldown sweep", ns.Prompt.SyncCooldown, ns.Prompt)
	end
	SettlePendingClick(plain(target), plain(spellId), plain(castGUID))
	-- The bar macro holds back for the last moments of the cooldown this cast
	-- began (the click macro section, below).
	if ns.NoteBarCooldown then ns.Guard("bar macro cooldown", ns.NoteBarCooldown) end
	if not self.db.profile.debugClicks then return end
	self:Print(("|cff80ff80" .. L["CAST SENT %s -> %s"] .. "|r"):format(
		tostring(plain(spellId)), tostring(plain(target))))
end

function addon:UNIT_SPELLCAST_SUCCEEDED(_, unit, castGUID, spellId)
	if unit ~= "player" then return end
	-- A scroll's cast done: the scroll is used, and nothing can stop it now.
	local done = castingScroll and ScrollCast(plain(castGUID), plain(spellId))
	if done then
		castingScroll = nil
		ns.EndScrollPress(done.spell)
	end
	-- Again here, for a cast with a cast time: its global cooldown is running
	-- by now, and the client's figure for it is the one to draw.
	if ns.Prompt and ns.Prompt.SyncCooldown then
		ns.Guard("cooldown sweep", ns.Prompt.SyncCooldown, ns.Prompt)
	end
	if ns.NoteBarCooldown then ns.Guard("bar macro cooldown", ns.NoteBarCooldown) end
	if self.db.profile.debugClicks then
		self:Print(L["|cff00ff00CAST OK|r %s"]:format(tostring(plain(spellId))))
	end
end

-- The sweep read again, for the three moments the global cooldown or the
-- player's cast changes without a cast going out; and the bar macro's hold
-- with it (the click macro section, below).
local function SyncSweep()
	if ns.Prompt and ns.Prompt.SyncCooldown then
		ns.Guard("cooldown sweep", ns.Prompt.SyncCooldown, ns.Prompt)
	end
	if ns.NoteBarCooldown then ns.Guard("bar macro cooldown", ns.NoteBarCooldown) end
end

-- A cast with a cast time: UnitCastingInfo may not say anything yet at SENT,
-- so the sweep is read again once the cast has started.
function addon:UNIT_SPELLCAST_START(_, unit)
	if unit ~= "player" then return end
	SyncSweep()
end

-- A cast stopped part-way: whatever it held up is over. A scroll's cast
-- (castingScroll) used nothing up, so its press is taken back.
function addon:UNIT_SPELLCAST_INTERRUPTED(_, unit, castGUID, spellId)
	if unit ~= "player" then return end
	SyncSweep()
	if not castingScroll then return end
	local stopped = ScrollCastStopped(plain(castGUID), plain(spellId), L["the cast was interrupted"])
	if stopped then ShowOutcome("failed", stopped, L["the cast was interrupted"]) end
end

-- Pushback: being hit while casting moves the cast's end later, and only this
-- event says so.
function addon:UNIT_SPELLCAST_DELAYED(_, unit)
	if unit ~= "player" then return end
	SyncSweep()
end

-- The client's own word that the cooldowns changed: whether the cast that armed
-- the guess is on the global cooldown at all, and then the sweep, drawn from
-- what that leaves.
function addon:SPELL_UPDATE_COOLDOWN()
	DropGuessOffGcd(GetTime())
	SyncSweep()
end

function addon:UNIT_SPELLCAST_FAILED(_, unit, castGUID, spellId)
	if unit ~= "player" then return end
	-- First: a refusal after SENT has the client take back the global
	-- cooldown the sweep is drawn from.
	SyncSweep()
	spellId = plain(spellId)
	castGUID = plain(castGUID)
	-- The server refusing a cast the client already reported sending. Only
	-- with no record parked: a parked one is UI_ERROR_MESSAGE's to answer. This
	-- event names the cast, which is why only it may undo a settle.
	if not ns.pendingClick then
		local late = UnsettleLateRefusal(castGUID)
		if late then ShowOutcome("failed", late, L["the game refused the cast"]) end
	end
	-- A scroll's cast failing after the settle's window: nothing was used up
	-- either. By the guid alone, as a refusal is: the same scroll pressed
	-- again from a bar mid-cast fails with its spell id too.
	if castingScroll then
		local stopped = ScrollCastStopped(castGUID, nil, L["the game refused the cast"])
		if stopped then ShowOutcome("failed", stopped, L["the game refused the cast"]) end
	end
	-- Not the refusal of a bar press the cooldown held back (UI_ERROR_MESSAGE,
	-- below): nothing was filed for it, and the press before it may have landed.
	if self.db.profile.verbose and ns.lastClickTime and (GetTime() - ns.lastClickTime) <= 1
		and ns.barHeldAt ~= GetTime() then
		self:Print(L["|cffff8080could not cast|r %s"]:format(SpellLabel(spellId)))
	end
end

-- Only errors in the moment after our own click, and printed only when asked
-- for: this event carries everything the game raises.
function addon:UI_ERROR_MESSAGE(_, _, message)
	message = plain(message)
	-- A bar press the cooldown held back (Press.lua, OnBarClick) still sends
	-- its /cast, which the game refuses in the same frame. That refusal is
	-- about a press nothing was filed for: not a reason to doubt the press
	-- before it, not the reason for the next refusal, and not "after our cast".
	if ns.barHeldAt == GetTime() then return end
	-- A reason to doubt a click still parked, and nothing more: it carries no
	-- spell id, so it never undoes a settle (see UnsettleLateRefusal).
	local failed = FailPendingClick(message)
	-- After the line above, which hands its refusal the words itself; this is
	-- for a refusal that arrived first, with none (UNIT_SPELLCAST_FAILED).
	ns.NoteGameError(message)
	-- The game's own words go on the panel's sub-line: localised, and often
	-- the only thing that says why.
	if failed then
		ShowOutcome("failed", failed, type(message) == "string" and message or nil)
	end
	if not self.db.profile.debugClicks then return end
	if not ns.lastClickTime or (GetTime() - ns.lastClickTime) > 1 then return end
	if not message then return end
	self:Print(L["|cffff4040after our cast:|r %s"]:format(tostring(message)))
end

---------------------------------------------------------------------------
-- click macro
--
-- The macro named Manners, which Put Manners on an action bar (and /manners
-- macro) makes and puts on the cursor, so the prompt can sit on any bar and be
-- pressed there by mouse or by key. It never presses the prompt. The game will
-- not run a macro from inside another one: "All macros (both real and
-- "macrotext" based ones) are being additionally restricted to remove the
-- ability to chain macros. For example, this means that one macro cannot
-- "/click" a button that itself would execute another macro." (Blizzard,
-- WoWUIBugs #552, 26 June 2024). That reached retail with 11.0.2 and the
-- Classic clients after it; Classic Era 1.15.9 runs the same C_Macro module.
-- 1.10.3's macro, a /click of the prompt's down click, cast nothing there from
-- a bar: a druid alone, Thorns on herself, saw PreClick run and the game answer
-- with nothing at all, while a click on the prompt itself cast.
--
-- So the macro carries the cast. Its first line clicks MannersBar, a plain
-- button with no secure template and no macro (Prompt/Panel.lua), which a
-- macro may click: Prompt/Press.lua's OnBarClick files the press there, as
-- PostClick files one on the prompt. Under it Manners writes the lines the
-- prompt's button would cast (Prompt/Macro.lua, barText: its macro without the
-- spoken line), out of combat, whenever they change. Nothing presses the
-- prompt from a macro, so nothing can cast twice. With nothing to cast --
-- nobody to buff, the prompt off, unlocked, previewing or running /manners
-- try, the panel naming somebody else, the last moments of a cooldown, the
-- macro window open, a loading screen -- it holds its first line alone, and a
-- press says why.
--
-- CreateMacro and EditMacro are protected in combat, so in a fight the macro
-- keeps what it held at the pull, as the prompt's button keeps its attributes;
-- after a login or a /reload in one it holds what the session before left,
-- which is read (GetMacroBody is not protected) and said at a press, never
-- filed. Only the macro named Manners is written, and only while its body is
-- a shape Manners writes (Shaped, below); one changed by hand is the player's.
-- Only a press of that macro is filed: another macro with the same first line
-- runs its own lines (Press.lua, OnBarClick, GetRunningMacro).
---------------------------------------------------------------------------

local MACRO_NAME = "Manners"
-- The options page asks whether it has been made.
ns.CLICK_MACRO_NAME = MACRO_NAME
-- The first line of every body Manners writes, and the whole of it with nothing
-- to cast. /click with no button and no phase is an up click of the left
-- button, which MannersBar is registered for.
local BAR_LINE = "/click MannersBar"
ns.BAR_LINE = BAR_LINE
-- What earlier versions wrote, recognised only to be rewritten.
local LEGACY_BODIES = {
	["/click MannersPrompt"] = true,              -- 0.9.x: an up click
	["/click MannersPrompt LeftButton 1"] = true, -- 1.0 to 1.10.4: a macro the client will not run from a macro
}

-- Whether both macro lists are at their caps. CreateMacro raises an error on a
-- full list instead of answering with nothing (warcraft.wiki.gg API_CreateMacro),
-- so the counts are the only way to tell "full" from any other refusal. The
-- caps are Constants.MacroConsts on retail and Forever (120 account-wide, 30
-- per character) and the MAX_*_MACROS globals on the classic family, as
-- Blizzard_MacroUI reads them. A cap that cannot be read is not guessed.
local function MacroListsFull()
	local consts = type(_G.Constants) == "table" and _G.Constants.MacroConsts
	if type(consts) ~= "table" then consts = {} end
	local accountCap = consts.MAX_ACCOUNT_MACROS or _G.MAX_ACCOUNT_MACROS
	local characterCap = consts.MAX_CHARACTER_MACROS or _G.MAX_CHARACTER_MACROS
	local account, character = safecall(_G.GetNumMacros)
	return type(accountCap) == "number" and type(characterCap) == "number"
		and type(account) == "number" and type(character) == "number"
		and account >= accountCap and character >= characterCap
end

-- The macro made or refreshed; its index, and whether it was made just now.
-- nil with the reason already said (a fight, no free slot) otherwise.
local function EnsureMacro()
	if InCombatLockdown() then
		addon:Print("|cffff8080" .. L["cannot touch macros in combat."] .. "|r")
		return nil
	end

	-- The explicit request: a Manners macro of any body, one changed by hand
	-- included, goes back to the bar line and is Manners' again. The body
	-- block below hears nothing of these two calls (MacroWriting), so the
	-- UPDATE_MACROS they raise cannot write into the middle of them.
	local existing = safecall(_G.GetMacroIndexByName, MACRO_NAME)
	if existing and existing > 0 then
		ns.MacroWriting(true)
		local edited = _G.EditMacro and pcall(_G.EditMacro, existing, MACRO_NAME, nil, BAR_LINE)
		ns.MacroWriting(false)
		if edited then ns.AdoptMacroBody() end
		return existing, false
	end

	-- Slot limits differ between flavours, so rather than hardcode a number,
	-- try the account-wide slots and fall back to per-character ones.
	ns.MacroWriting(true)
	local ok = pcall(_G.CreateMacro, MACRO_NAME, "INV_MISC_NOTE_03", BAR_LINE, false)
	if not ok then
		ok = pcall(_G.CreateMacro, MACRO_NAME, "INV_MISC_NOTE_03", BAR_LINE, true)
	end
	ns.MacroWriting(false)
	local index = ok and safecall(_G.GetMacroIndexByName, MACRO_NAME)
	if ok and index == 0 then
		addon:Print(L["|cffff8080no free macro slots.|r Delete one and try again."])
	elseif ok then
		if type(index) == "number" and index > 0 then ns.AdoptMacroBody() end
		return index or 0, true
	elseif MacroListsFull() then
		-- Both calls raised because both lists are full, not for some other reason.
		addon:Print(L["|cffff8080no free macro slots.|r Delete one and try again."])
	else
		addon:Print("|cffff8080" .. L["could not create the macro."] .. "|r")
	end
	return nil
end

-- The macro's slot on an action bar shows what a press would cast: its spell
-- (SetMacroSpell) or, for a scroll or an enhancement from the bags, its item
-- (SetMacroItem), so the bar draws that icon, cooldown, range and usability
-- itself. The body is the next block's, and nothing here touches the secure
-- button. Both calls are made out of combat only, and only
-- when what the prompt's top entry would cast has changed: Prompt/Macro.lua
-- hands each arming of the prompt's own button to SyncMacroSlot, which
-- compares one string and returns when it is the one already shown. With
-- nobody to buff, both are cleared and the slot shows the macro's own icon.
-- The macro's own icon stays the note CreateMacro was given: an addon's
-- texture is not a file the macro icon list names (a macro takes a fileID or
-- a name under Interface\Icons), and the note is the one every client has.
do
	-- index: nil not looked up, 0 no such macro. want: what the prompt asks of
	-- the slot ("" for nobody; nil while nothing has been armed yet). shown:
	-- what was last handed to the client. set: which of the two calls the
	-- client may hold something from.
	local slot = { index = nil, want = nil, shown = nil, spell = true, item = true }

	local function Want(entry)
		if not (entry and entry.buff) then return "" end
		local item = entry.buff.item
		if item then return "item:" .. tostring(item) end
		local spell = ns.EntrySpellName(entry)
		if type(spell) ~= "string" or spell == "" then return "" end
		return "spell:" .. spell
	end

	-- A call at the player's own pace, not the scan's: the first of a login,
	-- then one per change of what the top of the prompt casts.
	local function Settle()
		if slot.want == nil or slot.want == slot.shown or InCombatLockdown() then return end
		if slot.index == nil then slot.index = safecall(_G.GetMacroIndexByName, MACRO_NAME) or 0 end
		if slot.index == 0 then return end
		local kind, value = slot.want:match("^(%a+):(.*)$")
		local setSpell, setItem = _G.SetMacroSpell, _G.SetMacroItem
		-- The kind that is not wanted is cleared when the client may hold it.
		if kind ~= "spell" and slot.spell and type(setSpell) == "function" then
			pcall(setSpell, slot.index, "")
			slot.spell = false
		end
		if kind ~= "item" and slot.item and type(setItem) == "function" then
			pcall(setItem, slot.index, "")
			slot.item = false
		end
		if kind == "spell" and type(setSpell) == "function" then
			slot.spell = pcall(setSpell, slot.index, value)
		elseif kind == "item" and type(setItem) == "function" then
			slot.item = pcall(setItem, slot.index, "item:" .. value)
		end
		slot.shown = slot.want
	end

	-- Called by every arming of the prompt's button that was not a no-op
	-- (Prompt/Macro.lua) and by every disarming, nil: what is asked is kept,
	-- and Settle returns at once when it is what the slot shows already.
	function ns.SyncMacroSlot(entry)
		slot.want = Want(entry)
		Settle()
	end

	-- The macro was made, refreshed or found changed: ask again whatever was
	-- told before. Also once a fight ends, for what it held back.
	function ns.ResyncMacroSlot(forget)
		if forget then slot.index, slot.shown, slot.spell, slot.item = nil, nil, true, true end
		Settle()
	end

	-- The body was written (the next block): what the slot shows is handed to
	-- the client once more, in case an edit lets it go. What was cleared stays
	-- cleared, so with nobody to buff this asks nothing.
	function ns.ReassertMacroSlot()
		slot.shown = nil
		Settle()
	end

	-- What the macro holds looked at afresh (the next block).
	local function LookAgain()
		ns.ForgetMacroBody()
		ns.SyncMacroBody()
	end

	-- A macro made, deleted or moved in the macro window: only when its
	-- place changed does the slot's spell go on again, so setting it, which
	-- the client may answer with this event, cannot start a loop.
	function addon:UPDATE_MACROS()
		local index = safecall(_G.GetMacroIndexByName, MACRO_NAME) or 0
		if index ~= slot.index then
			slot.index, slot.shown, slot.spell, slot.item = index, nil, true, true
			Settle()
		end
		-- And the body (the next block) looked at again: this event is how an
		-- edit in the macro window, a macro made or deleted by hand, or another
		-- addon's write shows itself. A write of Manners' own that the client
		-- answers with it reads back as what was written, and is left there.
		-- Guarded: the look makes client calls, and this is an event.
		if ns.SyncMacroBody then ns.Guard("bar macro", LookAgain) end
	end
end

-- What the macro holds under its first line, written from the prompt's button
-- (see the head of this section). Kept in a block of its own, out of the main
-- chunk's locals.
do
	-- state: nil not looked at since the macro list last changed, "ours",
	-- "foreign" (lines Manners did not write: the player's), "none" (no macro
	-- named Manners). written: the body last written, or found when it is
	-- Manners' own. prefix: the player's own "#" lines (#showtooltip), kept on
	-- top of every body written. writing: inside a write of Manners' own.
	-- pressingAt: the moment of a bar press, in which nothing is written.
	-- holding: the last moments of a cooldown, out of combat (NoteBarCooldown).
	-- parked: a loading screen or a logout. warned: whose name (or, for one
	-- that targets nobody, which body) the last warning about a macro changed
	-- by hand carried. mine: the body this session last wrote. stale: the
	-- body found is Manners' shape with a cast in it that no write of this
	-- session made (a session before this one left it, and in a fight it
	-- cannot be put right); staleLines: its lines under the bar line, to say;
	-- staleSaid: said once.
	local body = { state = nil, written = nil, prefix = "", waitBody = BAR_LINE, cacheText = nil, cacheBody = nil,
		writing = false, pressingAt = nil, holding = false, holdGen = 0, recheckAt = nil, parked = false,
		warned = nil, legacy = false, watching = false, mine = nil, stale = false, staleLines = nil, staleSaid = false }

	local function Trimmed(text) return text:match("^%s*(.-)%s*$") end
	-- A line's command, lower case, and what follows it.
	local function Command(line)
		local command, rest = (line or ""):match("^/(%S+)%s*(.-)$")
		return command and command:lower(), rest
	end

	-- Whether the lines under the bar line (rest[2] on) are a shape Manners
	-- writes: the prompt's macro without its spoken line (Prompt/Macro.lua,
	-- STRATEGIES and HandBack). In this order: at most one /target <name>; then
	-- one /cast <spell>, or (with no /target) one /use item:<id> with at most
	-- one /use 16 or 17 after it; then, after a /target, at most one hand-back.
	-- None at all is the bar line alone. Nothing Manners writes has a
	-- conditional in it. A line of any other kind, or these in any other
	-- order or number (a trinket's /use 13 added under the cast), is not.
	local function Shaped(rest)
		local i = 2
		if rest[i] == nil then return true end
		local command, arg = Command(rest[i])
		local targeted = false
		if command == "target" then
			if arg == "" or arg:find("[", 1, true) then return false end
			targeted, i = true, i + 1
			command, arg = Command(rest[i])
		end
		if command == "cast" then
			if arg == "" or arg:find("[", 1, true) then return false end
			i = i + 1
		elseif command == "use" and not targeted and arg:match("^item:%d+$") then
			i = i + 1
			command, arg = Command(rest[i])
			if command == "use" and (arg == "16" or arg == "17") then i = i + 1 end
		else
			return false
		end
		if targeted then
			command, arg = Command(rest[i])
			if (command == "targetlasttarget" or command == "cleartarget") and arg == "" then i = i + 1 end
		end
		return rest[i] == nil
	end
	local function Debug(text)
		if addon.db and addon.db.profile.debugClicks then addon:Print("|cffffd100BAR|r " .. text) end
	end

	local function SetPrefix(prefix)
		if prefix == body.prefix then return end
		body.prefix, body.waitBody, body.cacheText = prefix, prefix .. BAR_LINE, nil
	end

	-- Whose the text is: "legacy" (what an older version wrote, under any "#"
	-- lines), "ours" (the bar line first, then a shape Manners writes, "#"
	-- lines anywhere) or "foreign"; the "#" lines, to keep on top; and its
	-- other lines.
	local function Classify(text)
		local meta, rest = {}, {}
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			line = Trimmed(line)
			if line:sub(1, 1) == "#" then
				meta[#meta + 1] = line
			elseif line ~= "" then
				rest[#rest + 1] = line
			end
		end
		local prefix = #meta > 0 and (table.concat(meta, "\n") .. "\n") or ""
		if #rest == 1 and LEGACY_BODIES[rest[1]] then return "legacy", prefix end
		if rest[1] ~= BAR_LINE then return "foreign", prefix, rest end
		if not Shaped(rest) then return "foreign", prefix, rest end
		return "ours", prefix, rest
	end

	-- What a bar press is filed against (Prompt.bar, read by Press.lua): what
	-- the lines under the first were written from. Nothing for the bar line
	-- alone. Never a spoken line: the bar's copy carries none.
	local function Snapshot(want)
		local P = ns.Prompt
		if not P then return end
		local B, S = P.bar, P.state
		B.body = want
		if want == body.waitBody then
			B.current, B.armed, B.macro, B.pickedFrom = nil, nil, nil, nil
		else
			B.current, B.armed, B.macro, B.pickedFrom = S.current, S.armed, S.barText, S.pickedFrom
		end
		B.phraseArmed, B.phraseSource = false, nil
	end

	-- A macro changed by hand that still targets somebody runs that line at
	-- every press, in every session after: said once for each name it carries.
	-- One that targets nobody (a trinket's /use added under the cast) is said
	-- once for each body: Manners writes no cast into it from now on, and its
	-- presses are not followed.
	local function Warn(rest, text)
		local who
		for i = 2, #rest do
			who = who or rest[i]:match("^/[Tt][Aa][Rr][Gg][Ee][Tt]%s+(.+)$")
		end
		local key = who or text
		if body.warned == key then return end
		body.warned = key
		if who then
			addon:Print(L["your |cffffd100%s|r macro has lines Manners did not write, so it is left as you wrote it -- and it still targets |cffffffff%s|r on every press. %s hands it back to Manners."]
				:format(MACRO_NAME, who, "|cffffd100/manners macro|r"))
		else
			addon:Print(L["your |cffffd100%s|r macro has lines Manners did not write, so it is left as you wrote it, and Manners writes no cast into it. %s hands it back to Manners."]
				:format(MACRO_NAME, "|cffffd100/manners macro|r"))
		end
	end

	-- The macro named Manners read and judged. A body Manners wrote, in this
	-- session or one before it (a reload, a crash), is Manners' to write again
	-- at once; an older version's is too, and is said; anybody else's is left.
	-- Only reads: it is asked in a fight too (SyncMacroBody), where a body a
	-- session before this one left with a cast in it stays until the fight
	-- ends, and a press of it is said for what it is (ns.StaleBarPress).
	local function Look()
		local index = safecall(_G.GetMacroIndexByName, MACRO_NAME)
		if type(index) ~= "number" or index <= 0 then
			body.state, body.stale = "none", false
			if ns.Prompt then ns.Prompt.bar.body = nil end
			return
		end
		local text = safecall(_G.GetMacroBody, index)
		if type(text) ~= "string" then return end
		text = Trimmed(text)
		local kind, prefix, rest = Classify(text)
		if kind == "foreign" then
			body.state, body.stale = "foreign", false
			if ns.Prompt then ns.Prompt.bar.body = nil end
			if rest[1] == BAR_LINE then Warn(rest, text) end
			Debug("body=edited")
			return
		end
		body.state, body.written, body.legacy = "ours", text, kind == "legacy"
		SetPrefix(prefix)
		local stale = kind == "ours" and rest ~= nil and #rest > 1 and text ~= body.mine
		if stale and not body.stale then
			body.staleSaid = false
			body.staleLines = table.concat(rest, "; ", 2)
		end
		body.stale = stale
		-- The bar line alone: a press of it is a press with nothing to cast, which
		-- says why (Press.lua, OnBarClick), in a fight as out of one.
		if text == body.waitBody then Snapshot(text) end
	end

	local function WindowOpen()
		local frame = _G.MacroFrame
		return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() == true
	end

	-- What the macro should hold now. No client call and no allocation while
	-- nothing has changed: every repaint asks it.
	local function Wanted()
		local P = ns.Prompt
		if body.parked or not P then return body.waitBody end
		local S, R = P.state, P.regions
		local text, entry = S.barText, S.current
		if not (text and entry) or S.testMode then return body.waitBody end
		-- As PreClick asks it: a hidden prompt casts nothing.
		if not (R.button and R.button:IsShown()) then return body.waitBody end
		local db = addon.db and addon.db.profile
		if not (db and db.enabled and db.prompt.locked) then return body.waitBody end
		-- The macro made at the pull serves the whole fight, as the button does:
		-- a flash at that moment, or a cooldown, must not freeze it empty.
		if P.armedForFight ~= true then
			-- A press follows the words on the panel (Press.lua, PreClick).
			local named = P:PanelName()
			if named and named ~= entry.name then return body.waitBody end
			if body.holding then return body.waitBody end
		end
		if text ~= body.cacheText then
			body.cacheText = text
			local full = body.prefix .. BAR_LINE .. "\n" .. text
			-- A block of "#" lines that leaves the cast no room is left off this
			-- body rather than the cast.
			if #full > ns.MACRO_LIMIT then full = BAR_LINE .. "\n" .. text end
			body.cacheBody = full
		end
		return body.cacheBody
	end

	-- The last moments of a cooldown, out of combat: a /cast pressed then is
	-- queued by the client and goes out after the hand-back, at whoever is
	-- targeted by then. So for the spell queue window before it ends the macro
	-- holds its first line alone; a press earlier in the cooldown is refused by
	-- the game and filed as nothing (OnBarClick). One timer asks again when
	-- the hold starts or ends.
	local function HoldNow()
		local P = ns.Prompt
		local entry = P and P.state.current
		if not entry or InCombatLockdown() then return false end
		local ready, left = ns.CastReady(ns.PressSpell and ns.PressSpell(entry) or nil)
		if ready then
			body.recheckAt = nil
			return false
		end
		local window, now = ns.SpellQueueWindow(), GetTime()
		local hold = left <= window
		local at = hold and (now + left) or (now + left - window)
		if not (body.recheckAt and math.abs(body.recheckAt - at) < 0.01) then
			body.recheckAt = at
			body.holdGen = body.holdGen + 1
			local gen = body.holdGen
			C_Timer.After(at - now, function()
				if body.holdGen ~= gen then return end
				body.recheckAt = nil
				ns.Guard("bar macro cooldown", ns.NoteBarCooldown)
			end)
		end
		if hold and not body.holding then Debug(("held=cooldown left=%.1f"):format(left)) end
		return hold
	end

	local function Write(index, want)
		body.writing = true
		local ok = type(_G.EditMacro) == "function" and pcall(_G.EditMacro, index, MACRO_NAME, nil, want)
		body.writing = false
		if not ok then return false end
		body.state, body.written, body.mine, body.stale = "ours", want, want, false
		Snapshot(want)
		ns.ReassertMacroSlot()
		if body.legacy then
			body.legacy = false
			addon:Print(L["your |cffffd100%s|r macro was updated -- the one an older version made no longer pressed the prompt."]:format(MACRO_NAME))
			Debug("rewrote=old")
		end
		Debug("wrote=" .. (want:gsub("\n", " / ")))
		return true
	end

	-- `fresh`: asked by an arming of the prompt's button (Prompt:ApplyTarget),
	-- always out of combat.
	function ns.SyncMacroBody(fresh)
		local state = body.state
		if state == "foreign" or state == "none" or body.writing then return end
		local want = Wanted()
		if want == body.written and state == "ours" then
			-- The same lines for the same person: what a press is filed against
			-- follows the latest arming (its reading, its queue), for nothing.
			if fresh and want ~= body.waitBody and not body.pressingAt and ns.Prompt then
				local B, S = ns.Prompt.bar, ns.Prompt.state
				B.current, B.armed, B.pickedFrom = S.current, S.armed, S.pickedFrom
			end
			return
		end
		if InCombatLockdown() then
			-- Read, never written: GetMacroBody is not protected, and a login or
			-- a /reload in a fight must know whose lines a press runs before the
			-- fight ends (Look, ns.StaleBarPress).
			if state == nil then Look() end
			return
		end
		-- Never into a macro that may be running: the bar's own press asks
		-- again next frame (HoldMacroWrites).
		if body.pressingAt and body.pressingAt == GetTime() then
			Debug("deferred=press")
			return
		end
		-- Every write has the open macro window put the saved text back in its
		-- box, over whatever the player is typing: none until it shuts.
		if WindowOpen() then return end
		if state == nil then
			Look()
			if body.state ~= "ours" then return end
			want = Wanted()
		end
		local index = safecall(_G.GetMacroIndexByName, MACRO_NAME)
		if type(index) ~= "number" or index <= 0 then
			body.state = "none"
			ns.Prompt.bar.body = nil
			return
		end
		local now = safecall(_G.GetMacroBody, index)
		if type(now) ~= "string" then return end
		if Trimmed(now) ~= body.written then
			-- Changed since: Manners' own shape is still Manners' (a #showtooltip
			-- added on top stays), anything else is the player's.
			Look()
			if body.state ~= "ours" then return end
			want = Wanted()
		end
		if want ~= body.waitBody and ns.Prompt.armedForFight ~= true then
			body.holding = HoldNow()
			if body.holding then want = body.waitBody end
		end
		if want == body.written then
			-- Found as what the prompt casts now: Manners' own, whoever wrote it
			-- (the same lines typed by hand in the macro window, or left by a
			-- session before for the person the prompt arms now), and a press of
			-- it is filed, not taken for a session before's (ns.StaleBarPress).
			body.mine, body.stale = want, false
			Snapshot(want)
			return
		end
		Write(index, want)
	end

	function ns.NoteBarCooldown()
		if body.state == "foreign" or body.state == "none" then return end
		if InCombatLockdown() then
			body.holding = false
			return
		end
		local P = ns.Prompt
		local S, R = P and P.state, P and P.regions
		-- Nobody on a prompt on screen: nothing to hold back.
		if not (S and S.current and S.barText and R.button and R.button:IsShown()) then
			if body.holding then
				body.holding = false
				ns.SyncMacroBody()
			end
			return
		end
		body.holding = HoldNow()
		ns.SyncMacroBody()
	end

	-- A bar press: nothing is written in the frame it runs in.
	function ns.HoldMacroWrites()
		body.pressingAt = GetTime()
		C_Timer.After(0, function()
			body.pressingAt = nil
			ns.Guard("bar macro", ns.SyncMacroBody)
		end)
	end

	-- What the macro holds now, as the client reads it back, for a press to be
	-- filed only against lines Manners wrote.
	function ns.BarBodyNow()
		local index = safecall(_G.GetMacroIndexByName, MACRO_NAME)
		if type(index) ~= "number" or index <= 0 then return nil end
		local text = safecall(_G.GetMacroBody, index)
		return type(text) == "string" and Trimmed(text) or nil
	end

	-- Where the macro named Manners is, 0 for nowhere: a press is filed only
	-- when it is the macro running (Press.lua, OnBarClick).
	function ns.BarMacroIndex()
		local index = safecall(_G.GetMacroIndexByName, MACRO_NAME)
		return type(index) == "number" and index or 0
	end

	-- A press of a body Manners did not write this session, still there as it
	-- was found (Look): its lines run, at whoever they name, and nothing of it
	-- is filed. In a fight it cannot be put right until the fight ends, which
	-- is said once; out of one the next write puts it right. Answers whether
	-- the press was of such a body.
	function ns.StaleBarPress()
		if not body.stale or body.state ~= "ours" or ns.BarBodyNow() ~= body.written then return false end
		if InCombatLockdown() and not body.staleSaid then
			body.staleSaid = true
			addon:Print(L["your |cffffd100%s|r macro still holds the last session's lines (%s) until this fight ends: a press runs them, and nothing it does is recorded -- the game lets no addon change a macro in a fight."]
				:format(MACRO_NAME, "|cffffffff" .. tostring(body.staleLines) .. "|r"))
		end
		return true
	end

	-- Whether the macro window is up, which holds the macro at its first line
	-- (OnWindowShown, below): a press then says so.
	function ns.MacroWindowOpen() return WindowOpen() end

	-- Put Manners on an action bar (EnsureMacro) wrote the bar line: the macro
	-- is Manners' again, whatever it held.
	function ns.AdoptMacroBody()
		body.state, body.written, body.parked, body.warned = "ours", BAR_LINE, false, nil
		body.mine, body.stale = BAR_LINE, false
		SetPrefix("")
		Snapshot(BAR_LINE)
	end
	function ns.MacroWriting(on) body.writing = on and true or false end
	function ns.ForgetMacroBody() body.state = nil end

	-- A loading screen or a logout: what the macro holds is the first thing the
	-- next session can press, before Manners has looked at anything.
	function ns.ParkMacroBody()
		body.parked = true
		ns.SyncMacroBody()
	end
	function ns.UnparkMacroBody()
		body.parked = false
		ns.SyncMacroBody()
	end

	-- The macro window (Blizzard_MacroUI, loaded when first opened): shown, the
	-- macro goes to its first line before anybody types in it, and stays there
	-- (SyncMacroBody writes nothing while it is open); shut, what the window
	-- saved is looked at, and the macro follows the prompt again.
	local function OnWindowShown()
		if body.state == "foreign" or body.state == "none" or InCombatLockdown() then return end
		if body.state == nil then
			Look()
			if body.state ~= "ours" then return end
		end
		if body.written == body.waitBody then return end
		local index = safecall(_G.GetMacroIndexByName, MACRO_NAME)
		if type(index) == "number" and index > 0 then Write(index, body.waitBody) end
	end
	local function OnWindowHidden()
		body.state = nil
		ns.SyncMacroBody()
	end
	function ns.WatchMacroWindow()
		if body.watching then return end
		local frame = _G.MacroFrame
		if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then return end
		body.watching = true
		frame:HookScript("OnShow", function() ns.Guard("macro window", OnWindowShown) end)
		frame:HookScript("OnHide", function() ns.Guard("macro window", OnWindowHidden) end)
	end

	-- For /manners selftest.
	function ns.BarMacroState() return body.state or "unlooked" end
end

-- The macro made or refreshed and put on the cursor, to drop on any action
-- bar slot: the options button and /manners macro. Answers whether it is
-- there. Out of combat only: the macro calls are refused in a fight, and so
-- is putting anything on a bar.
function ns.CreateClickMacro()
	local index, created = EnsureMacro()
	if not index then return false end
	-- What the prompt would cast goes in under the bar line before it is
	-- carried to a bar.
	ns.SyncMacroBody()
	ns.ResyncMacroSlot(true)
	local pickup = _G.PickupMacro
	if index > 0 and type(pickup) == "function" then
		pcall(pickup, index)
		if type(_G.GetCursorInfo) ~= "function" or _G.GetCursorInfo() == "macro" then
			ns.macroOnCursor = true
			addon:Print(L["macro |cffffd100%s|r is on your cursor. Drop it on any action bar slot."]:format(MACRO_NAME))
			return true
		end
	end
	-- Not carried (the call is missing or the client refused): where to find it.
	if created then
		addon:Print(L["macro |cffffd100%s|r created. Drag it onto a bar from the macro window."]:format(MACRO_NAME))
	else
		addon:Print(L["macro |cffffd100%s|r updated. Drag it onto a bar."]:format(MACRO_NAME))
	end
	return false
end

-- Once a login, out of combat: EditMacro is protected in a fight. The macro is
-- looked at afresh (the body block above): an older version's body is rewritten
-- with a line saying so, a body a session before this one left goes back to
-- what the prompt casts now, and a macro somebody has edited is theirs. Only
-- the macro named Manners, and no macro is ever made here. Returns true once
-- it has had its look, false to be asked again after a fight.
function ns.RepairOldMacro()
	if InCombatLockdown() then return false end
	-- Blizzard_MacroUI loaded before Manners was (another addon opened it).
	ns.WatchMacroWindow()
	ns.ForgetMacroBody()
	ns.SyncMacroBody()
	return ns.BarMacroState() ~= "unlooked"
end

-- Asked at login and after every fight until it has had its one look. A
-- repair that throws is not asked again.
local macroSettled = false
function ns.SettleOldMacro()
	if macroSettled then return end
	if not ns.Guard("macro repair", function() macroSettled = ns.RepairOldMacro() end) then
		macroSettled = true
	end
end
