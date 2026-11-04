-- Manners -- the prompt's hysteresis.
--
-- The scan rebuilds the queue 2.5 times a second, and in a crowd its top
-- churns. Three floors -- who is on it, whether it is shown, the sound -- each
-- refuse a change for a short time and then allow it. The first two are here;
-- the sound's is Refresh.lua's.

local _, ns = ...
local Prompt = ns.Prompt
local S, lib = Prompt.state, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- How long a freshly painted candidate is protected from one of equal or lower
-- priority. Somebody strictly better takes the panel at once.
local HOLD_SECONDS = 1.5

-- How long an empty queue is given to refill before the prompt comes down.
-- Shorter than the hold: "there is nobody" should be believed quickly.
local EMPTY_FUSE_SECONDS = 0.75

-- How long the cursor on the panel keeps somebody the queue no longer has,
-- from the last scan that had them (heldAt). Reaching the panel and reading it
-- takes a second or two, and a passer-by the cursor found is kept by the
-- queue itself for ten seconds after it leaves them (Queue.lua), so this only
-- has to cover the last stretch. Past it the cursor is resting on the panel,
-- not reaching for it, and whoever the panel names has been gone as long.
local HOVER_SECONDS = 10

-- Everything the hysteresis holds, dropped whenever the prompt goes down for a
-- reason of its own (switched off, unlocked, nothing learned), so coming back
-- up is a fresh start. The cursor with it: a panel that comes back up under a
-- cursor that has not moved is held again only once OnEnter says so, which
-- errs towards the ordinary hysteresis rather than a hold nothing ends.
local function ClearHold()
	S.heldEntry, S.heldAt, S.emptyAt = nil, nil, nil
	S.hovering, S.heldTurnedDown = nil, nil
end

-- Lights the fuse on an empty queue, once, and asks for a repaint when it has
-- burnt out rather than waiting for the next scan.
local function LightFuse(now)
	if S.emptyAt then return end
	S.emptyAt = now
	if C_Timer and C_Timer.After then
		C_Timer.After(EMPTY_FUSE_SECONDS + 0.05, function()
			ns.Guard("fuse repaint", Prompt.Refresh, Prompt)
		end)
	end
end

-- On the never-offer list with no favour to return, asked as BuildQueue asks
-- it, so the hold and the fuse drop a name listed by any route.
local function ListedWithoutDebt(name, now)
	if not (name and ns.IsNeverOffered and ns.IsNeverOffered(name)) then return false end
	local db = ns.db and ns.db.profile
	local debt = ns.owed and ns.owed[name]
	local owed = db and db.sources and db.sources.owed and debt
		and ns.DebtExpiry(debt) > now
	return not owed
end

-- Whether this entry was deliberately retired: blocked (the retry cooldown a
-- click wrote, or a right-press refusal), on the never-offer list with
-- nothing owed, or held back for PvP -- flagged since the paint, or in a
-- party a group cast or a shout would land on (Queue.lua, HeldForPvP). The
-- repaint and the press both ask this and must agree: a press on an empty
-- queue otherwise casts at whoever the panel still names.
local function Retired(entry, now)
	if ns.HeldForPvP(entry) then return true end
	return entry ~= nil and entry.name ~= nil
		and (ns.IsBlocked(entry.name, entry.buff and entry.buff.key, now)
			or ListedWithoutDebt(entry.name, now))
end

-- Called with BuildQueue's second return by every pass that builds a queue to
-- pick from, before it picks: true when the scan refused the whole queue for
-- your own state (mounted with "Hide the prompt while I'm mounted", dead, on a
-- taxi), otherwise [name] = true for everybody it turned down (found dead,
-- covered, out of range, held back while you save mana, let go from memory).
-- A verdict on whoever the panel holds -- the entry last painted, which is
-- the one armed -- ends the cursor's hold on them. A stubbed queue hands back
-- nothing, which is no verdict.
local function NoteVerdicts(verdicts)
	local entry = S.heldEntry or S.current
	local name = entry and entry.name
	if not (name and verdicts) then return end
	if verdicts == true or (type(verdicts) == "table" and verdicts[name] == true) then
		S.heldTurnedDown = name
	end
end

-- The cursor's hold (see hovering), which lets the ordinary hold and the fuse
-- run past their time. It forgives a token lost -- the cursor leaving the
-- person it found, a target cleared -- for HOVER_SECONDS, and nothing else:
-- somebody a scan found dead must not stay on the panel, and the press cast at
-- them, because the cursor happened to be resting on it (see NoteVerdicts).
local function CursorHolds(entry, now)
	if not (S.hovering and entry and entry.name and S.heldAt) then return false end
	if S.heldTurnedDown == entry.name then return false end
	return now - S.heldAt < HOVER_SECONDS
end

-- The one repaint PLAYER_REGEN_DISABLED makes before the lockdown: whatever it
-- arms is frozen for every press of the fight, so the hold and the fuse, which
-- only smooth flicker, must not keep somebody the queue has dropped.
local function ArmingForFight()
	return Prompt.armedForFight == true and not InCombatLockdown()
end

-- Whether the last candidate painted is still entitled to the panel. It
-- expires, it never holds off somebody strictly better (PickTop checks that),
-- and it never holds somebody deliberately retired (see Retired) -- not even
-- inside HOLD_SECONDS, which a press may land in.
local function HoldStillStands(now)
	if not (S.heldEntry and S.heldAt) then return false end
	-- Longer while the cursor is on the panel (see CursorHolds).
	if now - S.heldAt >= HOLD_SECONDS and not CursorHolds(S.heldEntry, now) then return false end
	if ListedWithoutDebt(S.heldEntry.name, now) then return false end
	if ns.HeldForPvP(S.heldEntry) then return false end
	return not ns.IsBlocked(S.heldEntry.name, S.heldEntry.buff and S.heldEntry.buff.key, now)
end

-- Whoever is offered stays offered: the current pick wins ties, and the last
-- painted one is held briefly after leaving the queue against anything no
-- better.
function Prompt:PickTop(queue, fallback)
	local top = fallback
	if S.current and top then
		for _, candidate in ipairs(queue) do
			if candidate.name == S.current.name then
				if candidate.priority <= top.priority then return candidate end
				break
			end
		end
	end

	-- An empty queue is the fuse's question, in Refresh; holding here too would
	-- stack the two.
	if not top then return nil end
	if not HoldStillStands(GetTime()) then return top end
	-- Not on the pull's own pass (see ArmingForFight). `top` already prefers
	-- the current pick while it is still in the queue.
	if ArmingForFight() then return top end
	if top.name == S.heldEntry.name then return top end
	-- Judged by what this scan says of them, not by the copy painted: that
	-- one keeps the priority they had then, so somebody retargeted away from,
	-- or whose favour lapsed, still outranked everybody on it -- and, being in
	-- the queue, renewed the hold on every paint (see RefreshPanel).
	local held = S.heldEntry
	for _, candidate in ipairs(queue) do
		if candidate.name == S.heldEntry.name then held = candidate break end
	end
	-- Lower is better: a strict improvement (a favour owed over a passer-by) is
	-- never held off.
	if top.priority < held.priority then return top end
	return held
end

lib.ClearHold, lib.LightFuse, lib.Retired, lib.NoteVerdicts = ClearHold, LightFuse, Retired, NoteVerdicts
lib.CursorHolds, lib.ArmingForFight, lib.EMPTY_FUSE_SECONDS = CursorHolds, ArmingForFight, EMPTY_FUSE_SECONDS
