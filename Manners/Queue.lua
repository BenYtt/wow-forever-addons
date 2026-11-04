-- Manners -- the candidate queue: who is owed a favour, what the game keeps
-- refusing, the never-offer list, friends and guildmates, and BuildQueue,
-- which puts everybody the prompt could offer in order.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Range.lua's, which load first.
local plain, safecall, caps, MANA = ns.plain, ns.safecall, ns.caps, ns.MANA
local ShortName, SafeForMacro = ns.ShortName, ns.SafeForMacro
local UnitHasBuff, UnitHasMana, MANA_CLASSES = ns.UnitHasBuff, ns.UnitHasMana, ns.MANA_CLASSES
local IsBuffableUnit, InRange, ShoutReach, SameParty = ns.IsBuffableUnit, ns.InRange, ns.ShoutReach, ns.SameParty
local prox, Resting = ns.proximity, ns.Resting

---------------------------------------------------------------------------
-- candidate queue
---------------------------------------------------------------------------

-- People who buffed us: [name] = { expires, at, guid?, class?, pvp? }. `at` is
-- when the favour was noticed, which the grace window and LiveExpiry count
-- from; `pvp` the PvP flag last read off them (see "flagged for PvP").
local owed = {}

-- [name .. "\0" .. buffKey] = expiry for a buff we just tried on them, so
-- casting Fortitude does not stop the walk reaching Divine Spirit; and
-- [name .. "\0*"] = expiry for the whole person (a right-press skip, or a press
-- that reached nobody), so somebody behind a pillar does not walk the list.
local tried = {}

-- [name] = what the game has been refusing on this person (NoteRefusal). In
-- memory only, on purpose: whatever the server held against them (a phase, a
-- duel, a rule nobody names) rarely outlives a /reload or a new login.
local refusals = {}

ns.lastGave = {} -- [name] = buffKey, for rotating when auras cannot be read

ns.owed, ns.tried, ns.refusals = owed, tried, refusals

-- When a debt really runs out: the stamp it was filed with, or its age against
-- the window as it stands now, whichever comes first -- so lowering "Remember a
-- buff for" applies to debts already owed. Every reader asks this.
local function LiveExpiry(entry)
	local db = addon.db and addon.db.profile
	local window = db and db.timing and db.timing.reciprocateWindow
	if type(entry.at) ~= "number" or type(window) ~= "number" then return entry.expires end
	return math.min(entry.expires, entry.at + window)
end
ns.DebtExpiry = LiveExpiry

-- GetTime() is time since boot, so it restarts after a reboot and differs per
-- machine: debts go out on the wall clock and are rebased on the way back in,
-- `at` included. db.char, not the profile: a debt is owed to a character.
local function SaveDebts()
	local store = addon.db and addon.db.char
	local wall = plain(time and time())
	if not store or type(wall) ~= "number" then return end

	-- Switched off means the file is cleared, not merely not written.
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now, out = GetTime(), nil
	for name, entry in pairs(owed) do
		local expires = LiveExpiry(entry)
		if expires > now then
			out = out or {}
			-- The class and the PvP flag are all the tokenless fallback judges by. The
			-- guid is not kept: nothing reads it back.
			out[name] = {
				expires = wall + (expires - now),
				at = wall - (now - entry.at),
				class = entry.class,
				pvp = entry.pvp == true or nil,
			}
		end
	end
	store.debts = out -- nil when empty, so AceDB prunes the section on logout
end
ns.SaveDebts = SaveDebts

local function RestoreDebts()
	local store = addon.db and addon.db.char
	local saved = store and store.debts
	local wall = plain(time and time())
	if type(saved) ~= "table" or type(wall) ~= "number" then return end

	-- Honoured on the way in too: a file can outlive the setting (a profile
	-- switched between logins, or changed on another character).
	if addon.db.profile and addon.db.profile.timing.keepDebts == false then
		store.debts = nil
		return
	end

	local now = GetTime()
	local window = (addon.db and addon.db.profile.timing.reciprocateWindow) or 120
	for name, entry in pairs(saved) do
		if type(entry) == "table" and type(entry.expires) == "number"
			and type(entry.at) == "number" and SafeForMacro(name) then
			-- Clamped to the window as it stands now, counted from the favour
			-- as LiveExpiry does. A stamp from the future (the clock set back
			-- since it was written) counts as now, or the skew would be added
			-- to the window.
			local at = math.min(entry.at, wall)
			local left = math.min(entry.expires, at + window) - wall
			if left > 0 then
				-- `at` goes negative just after a reboot, correctly: now - at
				-- is still the real age of the debt.
				owed[name] = {
					expires = now + left,
					at = now - (wall - at),
					class = type(entry.class) == "string" and entry.class or nil,
					pvp = entry.pvp == true or nil,
				}
			end
		end
	end
end
ns.RestoreDebts = RestoreDebts

-- AceDB fires this from its PLAYER_LOGOUT handler, before it strips the
-- defaults, so writing here is safe.
function addon:SaveDebts()
	ns.Guard("SaveDebts", SaveDebts)
end

-- The only writers and reader of the two key shapes in `tried`, in a block of
-- their own for the main chunk's 200 locals.
do
	-- One writer under both shapes. keepLonger extends a block and never
	-- shortens it, so the two-second rewind of a press that went nowhere cannot
	-- cancel a right-press skip at the full retry cooldown.
	local function Block(key, seconds, keepLonger)
		if not seconds then
			local db = addon.db and addon.db.profile
			seconds = (db and db.timing.retryCooldown) or 12
		end
		local expiry = GetTime() + seconds
		local standing = tried[key]
		if keepLonger and standing and standing > expiry then return end
		tried[key] = expiry
	end

	function ns.MarkAttempted(name, buffKey, seconds, keepLonger)
		if not name or not buffKey then return end
		Block(name .. "\0" .. buffKey, seconds, keepLonger)
	end

	function ns.BlockPerson(name, seconds, keepLonger)
		if not name then return end
		Block(name .. "\0*", seconds, keepLonger)
	end

	-- The keys one person's blocks are filed under, built once per person and
	-- kept, since IsBlocked is asked for everybody on every scan. The
	-- whole-person key sits under a table key no buff can have.
	local blockKeys, blockKeyCount = {}, 0
	local WHOLE_PERSON = {}

	local function BlockKeys(name)
		local keys = blockKeys[name]
		if keys then return keys end
		-- Bounded: a city puts hundreds of people through the scan in a session.
		if blockKeyCount >= 500 then
			wipe(blockKeys)
			blockKeyCount = 0
		end
		keys = { [WHOLE_PERSON] = name .. "\0*" }
		blockKeys[name] = keys
		blockKeyCount = blockKeyCount + 1
		return keys
	end

	-- The whole-person key is always consulted, and so is a back-off after
	-- refusals in a row, a block on the whole person too.
	function ns.IsBlocked(name, buffKey, now)
		if not name then return false end
		now = now or GetTime()
		local refused = refusals[name]
		if refused and refused.blockUntil > now then return true end
		if next(tried) == nil then return false end
		local keys = BlockKeys(name)
		local person = tried[keys[WHOLE_PERSON]]
		if person and person > now then return true end
		if not buffKey then return false end
		local key = keys[buffKey]
		if not key then
			key = name .. "\0" .. buffKey
			keys[buffKey] = key
		end
		local one = tried[key]
		return one ~= nil and one > now
	end
end

-- What the game keeps refusing, per person, and what follows. The spoken line
-- is held for a while after a refusal: a macro runs every line even when its
-- /cast fails, so a thank-you went out over a buff that never landed, once per
-- press (beta.8). And the person backs off further with each refusal in a row:
-- somebody the game will never let you buff came straight back after two
-- seconds, forever. A cast that lands forgets it all (PruneSettled).
do
	-- How long each refusal in a row keeps the person off the prompt. The first
	-- is the two seconds RewindClick has always written, so one stray refusal
	-- costs nothing new. Somebody who buffed you backs off more gently:
	-- returning the favour is the point, and the favour itself stays owed.
	local STEPS = { 2, 30, 300 }
	local OWED_STEPS = { 2, 20, 60 }
	-- The refusal in a row that says so in chat, once per run.
	local TELL_AT = 3
	-- How long the spoken line stays held after a press came to nothing, and
	-- past the end of any back-off.
	local QUIET_SECONDS = 30
	-- A run of refusals this long over is forgotten, and the sweep lets the
	-- person go: somebody never seen again must not be kept all session.
	local FORGET_SECONDS = 600
	local CAP = 200
	-- How close an error line and a refusal must be to be about the same cast.
	local ERROR_SECONDS = 1

	local lastError, lastErrorAt = nil, 0
	-- Who the newest refusal was about, for an error line arriving just after.
	local newest
	-- Whom the player last picked as their target on purpose: what
	-- PLAYER_TARGET_CHANGED last handed LiftBackoff, nil once they cleared it.
	-- Not whoever the prompt's own macro left targeted, which the event ignores.
	local pointedAt

	-- Errors about the caster rather than the person (out of mana, moving, the
	-- cooldown, still on a flying mount): they hold the spoken line, since
	-- nothing landed, but say nothing about whether the game will refuse this
	-- person next time. Named by the client's own global strings, since the
	-- text is localised.
	local CASTER_SIDE = { "ERR_OUT_OF_MANA", "SPELL_FAILED_MOVING", "SPELL_FAILED_NOT_READY",
		"ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "SPELL_FAILED_SPELL_IN_PROGRESS",
		"SPELL_FAILED_SILENCED", "SPELL_FAILED_STUNNED", "SPELL_FAILED_CASTER_DEAD",
		"SPELL_FAILED_INTERRUPTED", "SPELL_FAILED_NOT_MOUNTED" }

	-- Refusals the press asks about again before it lets a line go
	-- (Prompt/Press.lua, HoldLine): the range, the mana, a cooldown or a cast
	-- in progress, the target dead. A press that carried no line and was
	-- refused for one of these leaves nothing to hold: the next press says the
	-- line only if it finds that cleared.
	local RECHECKED = { "ERR_OUT_OF_RANGE", "SPELL_FAILED_OUT_OF_RANGE", "ERR_OUT_OF_MANA",
		"SPELL_FAILED_NOT_READY", "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN",
		"SPELL_FAILED_SPELL_IN_PROGRESS", "SPELL_FAILED_TARGETS_DEAD" }

	-- Whether the game's words are one of these global strings.
	local function OneOf(message, keys)
		if type(message) ~= "string" then return false end
		local bare = message:gsub("%.$", "")
		for _, key in ipairs(keys) do
			local text = plain(_G[key])
			if type(text) == "string" and text:gsub("%.$", "") == bare then return true end
		end
		return false
	end

	local function AboutTheCaster(message)
		return OneOf(message, CASTER_SIDE)
	end

	-- Said whether or not chat lines are on: it is the only thing that says
	-- why somebody vanished from the prompt.
	local function Tell(name, why)
		-- Your own buff (SelfEntry) by what it is: your name in the third
		-- person reads as somebody else who shares it. Targeting yourself
		-- lifts it, as targeting anybody does (LiftBackoff).
		if ns.IsPlayerName(name) then
			addon:Print(type(why) == "string"
				and L["|cffff8080the game keeps refusing your own buff|r (it said: %s) -- it will not be offered to you for a while; target yourself to try again."]
					:format((why:gsub("%.$", "")))
				or L["|cffff8080the game keeps refusing your own buff|r -- it will not be offered to you for a while; target yourself to try again."])
			return
		end
		if type(why) == "string" then
			addon:Print(L["|cffff8080the game keeps refusing buffs on %s|r (it said: %s) -- they will not be offered for a while; target them to try again."]
				:format(name, (why:gsub("%.$", ""))))
		else
			addon:Print(L["|cffff8080the game keeps refusing buffs on %s|r -- they will not be offered for a while; target them to try again."]
				:format(name))
		end
	end

	function ns.SweepRefusals(now)
		for name, r in pairs(refusals) do
			if r.blockUntil <= now and r.quietUntil <= now and now - r.last > FORGET_SECONDS then
				refusals[name] = nil
			end
		end
	end

	-- One person's record, room made for it first. Counted here, not tallied: a
	-- new record is rare, and a count cannot drift from the table.
	local function Record(name, now)
		local r = refusals[name]
		if r then return r end
		local held, oldest, at = 0, nil, nil
		for who, rec in pairs(refusals) do
			held = held + 1
			if not at or rec.last < at then oldest, at = who, rec.last end
		end
		-- Full even so: the person refused longest ago goes.
		if held >= CAP then refusals[oldest] = nil end
		r = { count = 0, last = now, blockUntil = 0, quietUntil = 0 }
		refusals[name] = r
		return r
	end

	-- Every error line the game raises. One arriving just after a refusal that
	-- had no reason of its own is taken as that reason.
	function ns.NoteGameError(message)
		if type(message) ~= "string" then return end
		local now = GetTime()
		lastError, lastErrorAt = message, now
		local r = newest and refusals[newest]
		if r and r.why == nil and now - r.last <= ERROR_SECONDS and not AboutTheCaster(message) then
			r.why = message
		end
	end

	-- A press on this person came to nothing: an error inside the press's
	-- window, or a refusal after it was sent. `why` is the game's own words
	-- where the caller has them. `quietOnly` holds the spoken line and no more,
	-- for a press the game never answered at all: nothing refused anybody
	-- there, so it is no evidence the game will refuse them next time.
	-- `spoke` is false for a press whose macro carried no line (PostClick
	-- records it): refused for something the next press asks again
	-- (RECHECKED), or not refused at all (quietOnly), that holds no line, or
	-- the press that lands once they are back in reach would go out silent
	-- too. The back-off stands either way.
	function ns.NoteRefusal(name, why, quietOnly, spoke)
		if not name then return end
		local now = GetTime()
		if why == nil and lastError and now - lastErrorAt <= ERROR_SECONDS then why = lastError end
		local r = Record(name, now)
		local hold = spoke ~= false or (not quietOnly and not OneOf(why, RECHECKED))
		-- Never shortened: a quiet note must not cut the longer hold a back-off
		-- below wrote.
		if hold and now + QUIET_SECONDS > r.quietUntil then r.quietUntil = now + QUIET_SECONDS end
		newest = name
		if quietOnly or AboutTheCaster(why) then
			r.last = now
			return
		end
		-- A run long over was swept (SweepRefusals), so this starts again at one.
		r.last = now
		r.count = r.count + 1
		r.why = type(why) == "string" and why or nil
		-- Somebody the player has picked out and still has selected is not backed
		-- off: the lift is a change of target (LiftBackoff), and selecting the
		-- person already selected sends none, so the prompt would turn from them
		-- for good. The refusal is counted, so the next one, once they are no
		-- longer the target, backs them off at the step it has reached. Only a
		-- target the player chose: the macro's own /target (a hand-back switched
		-- off, or nothing targeted before it) leaves its person targeted too, and
		-- they must still be let go. Nothing to say in chat either: they stay offered.
		if name == pointedAt and ns.UnitFullName("target") == name then return end
		local debt = owed[name]
		local steps = (debt and LiveExpiry(debt) > now) and OWED_STEPS or STEPS
		local seconds = steps[math.min(r.count, #steps)]
		if now + seconds > r.blockUntil then r.blockUntil = now + seconds end
		-- The line stays held past the back-off: somebody the game keeps refusing
		-- comes back when it runs out, and the first press then would thank them
		-- over yet another refused cast. A cast that lands clears it (NoteLanded).
		if hold and r.blockUntil + QUIET_SECONDS > r.quietUntil then r.quietUntil = r.blockUntil + QUIET_SECONDS end
		if r.count >= TELL_AT and not r.said then
			r.said = true
			if r.why or not (C_Timer and C_Timer.After) then
				Tell(name, r.why)
			else
				-- The error line can arrive a moment after the refusal it explains.
				C_Timer.After(0.3, function() ns.Guard("refusal line", Tell, name, r.why) end)
			end
		end
	end

	-- A cast on them landed: nothing the game refused before stands.
	function ns.NoteLanded(name)
		if name then refusals[name] = nil end
	end

	function ns.SpeechHeld(name, now)
		local r = name and refusals[name]
		return r ~= nil and r.quietUntil > (now or GetTime())
	end

	-- The player pointed at them on purpose (PLAYER_TARGET_CHANGED): the
	-- back-off lifts, the count stays, so another refusal backs off again. `name`
	-- is nil when the target was cleared, and the choice is remembered either way
	-- (see NoteRefusal).
	function ns.LiftBackoff(name)
		pointedAt = name
		local r = name and refusals[name]
		if r then r.blockUntil = 0 end
	end

	-- For /manners debug: who is backed off or kept quiet, and for how long.
	-- Seconds rather than a clock time: the minimap clock may be the realm's.
	function ns.RefusalLines(now)
		local out = {}
		for name, r in pairs(refusals) do
			if r.blockUntil > now then
				out[#out + 1] = L["backed off for %ds more: |cffffffff%s|r -- refused %d times in a row"]
					:format(math.ceil(r.blockUntil - now), name, r.count)
			elseif r.quietUntil > now then
				out[#out + 1] = L["no spoken line for %ds more: |cffffffff%s|r -- the game refused a cast on them"]
					:format(math.ceil(r.quietUntil - now), name)
			end
		end
		table.sort(out)
		return out
	end
end

-- The debt is paid. Written through, so a reload cannot raise it again.
function ns.SettleFavour(name)
	if not name then return end
	owed[name] = nil
	SaveDebts()
end

---------------------------------------------------------------------------
-- the never-offer list
--
-- People the player has said never to offer anything to, filed under the same
-- name debts are, in the profile. It reaches the queue at its next rebuild (in
-- a fight, the end of it); nothing here touches the button.
---------------------------------------------------------------------------

-- Defined with the favour ledger's other hook further down, and declared here
-- so the never-offer list below can tell the ledger about a favour it lets go.
local TellLedger

-- What a never-offer entry holds: true for a name the player typed (and for
-- every list saved before there was a marker), NEVER_FILED for one filed from a
-- name the game gave. Core's ClampSettings keeps both.
local NEVER_FILED = "filed"

local function NeverSet()
	local db = addon.db and addon.db.profile
	local never = db and db.never
	if type(never) ~= "table" then return nil end
	return never
end

local function CleanName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if name == "" then return nil end
	return name
end

-- Whether a listed name matches, regardless of case, since names are typed by
-- hand. Folded by the client's strcmputf8i where there is one (string.lower
-- leaves accented capitals alone); plain lower is the fallback, and all there
-- is to it for two names in A to Z. The scan asks this of every asker it
-- remembers against every request on every pass, so the pcall is kept for a
-- name that needs it.
local function SameName(a, b)
	if not b then return false end
	if a == b then return true end
	local fold = _G.strcmputf8i
	if type(fold) == "function" and (a:find("[\128-\255]") or b:find("[\128-\255]")) then
		local ok, cmp = pcall(fold, a, b)
		if ok and type(cmp) == "number" then return cmp == 0 end
	end
	return a:lower() == b:lower()
end
ns.SameName = SameName

-- Whether a sorts before b, case folded the same way SameName folds it, so a
-- name typed in small letters sorts among the capitalised ones in any script.
-- Not full collation (Ё still sorts apart from Е). Ties fall back to lower and
-- then to bytes, so the order is total, which table.sort needs.
local function NameBefore(a, b)
	local fold = _G.strcmputf8i
	if type(fold) == "function" then
		local ok, cmp = pcall(fold, a, b)
		if ok and type(cmp) == "number" and cmp ~= 0 then return cmp < 0 end
	end
	local la, lb = a:lower(), b:lower()
	if la ~= lb then return la < lb end
	return a < b
end

-- What the list walk has already answered, by name: the entry, or false. The
-- scan asks about everybody 2.5 times a second, two case-folded compares per
-- entry. Checked against a copy of the list rather than cleared by an editor,
-- because imports, profile switches and the scenarios write the table
-- directly; a different fold function throws the answers away too. `scan` is
-- the answers while BuildQueue walks the units.
local neverSeen = {
	list = nil, fold = nil, size = 0, copy = {}, verdict = {}, count = 0,
	max = 1000, scan = nil,
}

-- The answers, valid for the list as it stands now. nil when there is no list.
local function NeverVerdicts()
	local never = NeverSet()
	if not never then return nil end
	local copy, fold = neverSeen.copy, _G.strcmputf8i
	local fresh = neverSeen.list == never and neverSeen.fold == fold
	if fresh then
		local size = 0
		for key, flag in pairs(never) do
			if copy[key] ~= flag then fresh = false break end
			size = size + 1
		end
		if size ~= neverSeen.size then fresh = false end
	end
	if not fresh then
		wipe(copy)
		local size = 0
		for key, flag in pairs(never) do
			copy[key] = flag
			size = size + 1
		end
		neverSeen.list, neverSeen.fold, neverSeen.size = never, fold, size
		wipe(neverSeen.verdict)
		neverSeen.count = 0
	end
	return neverSeen.verdict
end

-- The entry on the list that names this person, or nil: exact, then regardless
-- of case, then -- for an entry the player typed -- with the realm taken off the
-- name (as the prompt shows it), never the other way round. An entry filed from
-- a name the game gave (the prompt, the ledger) is marked NEVER_FILED and
-- matches that name alone: a same-realm "Anna" on the list is not the Anna of
-- another realm, who is filed "Anna-Realm" and shows on the prompt as "Anna".
-- An exact entry always beats a realm-less one. `verdict` is NeverVerdicts'
-- table, passed only by the scan; anybody else walks the list.
local function ListedAs(name, verdict)
	local never = NeverSet()
	if not never or type(name) ~= "string" or next(never) == nil then return nil end
	local held = never[name]
	if held == true or held == NEVER_FILED then return name end
	if verdict then
		local known = verdict[name]
		if known ~= nil then return known or nil end
	end
	local short = ShortName(name)
	local found, typed
	for key, flag in pairs(never) do
		if type(key) == "string" then
			if SameName(key, name) then found = key break end
			if flag == true and not typed and SameName(key, short) then typed = key end
		end
	end
	found = found or typed
	if verdict then
		-- Bounded like the other per-person caches.
		if neverSeen.count >= neverSeen.max then
			wipe(verdict)
			neverSeen.count = 0
		end
		verdict[name] = found or false
		neverSeen.count = neverSeen.count + 1
	end
	return found
end
ns.ListedAs = ListedAs

-- The scan's answers while it walks; between scans the same answers, checked
-- against the list as it stands (NeverVerdicts, table lookups alone), so an
-- edit is honoured at once. The repaint and the options page ask about the
-- same few names over and over, and a list walk per ask was most of the cost.
function ns.IsNeverOffered(name)
	return ListedAs(name, neverSeen.scan or NeverVerdicts()) ~= nil
end

-- Whether somebody is on your /ignore list, the game's own "leave me alone":
-- by token (or name: IsIgnored takes either), else by GUID. Neither call
-- throws on a plain string, and each answers a plain yes or no, so nothing is
-- pcalled; false on a client without them. Unlike the never-offer list, a
-- favour is no exception: nobody you ignore is thanked or offered one back
-- (Favours.lua, Sight and the combat log), and no passer-by is offered at
-- all. A group member stays offered: buffing a teammate you ignore still
-- helps the group.
function ns.Ignored(unit, guid)
	local friends = _G.C_FriendList
	if type(friends) ~= "table" then return false end
	if type(unit) == "string" and type(friends.IsIgnored) == "function"
		and plain(friends.IsIgnored(unit)) == true then return true end
	if type(guid) == "string" and type(friends.IsIgnoredByGuid) == "function"
		and plain(friends.IsIgnoredByGuid(guid)) == true then return true end
	return false
end

-- Whether the ignore list has anybody on it, asked once a scan so an empty
-- one costs the walk nothing.
local function IgnoresAnybody()
	local friends = _G.C_FriendList
	local count = type(friends) == "table" and type(friends.GetNumIgnores) == "function"
		and plain(friends.GetNumIgnores()) or nil
	return type(count) == "number" and count > 0
end

-- Puts somebody on the list. Returns the spelling now on it, and whether they
-- were already there (whose spelling is kept, so nobody is listed twice). A
-- name the player typed (`typed`) also answers to the same person from another
-- realm ("Anna" for "Anna-Realm", as the prompt shows her); a name the game gave
-- is filed as NEVER_FILED and means that one person only.
function ns.NeverOffer(name, typed)
	name = CleanName(name)
	local never = NeverSet()
	if not name or not never then return nil end
	local already = ListedAs(name)
	if already then return already, true end
	never[name] = typed and true or NEVER_FILED
	return name, false
end

-- Takes somebody off. Returns the spelling that came off, or nil when nobody
-- on the list answers to that name.
function ns.AllowAgain(name)
	local listed = ListedAs(CleanName(name))
	if not listed then return nil end
	NeverSet()[listed] = nil
	return listed
end

-- Everybody on it, sorted the way a reader looks for a name.
function ns.NeverList()
	local names = {}
	for name, flag in pairs(NeverSet() or {}) do
		if flag == true or flag == NEVER_FILED then names[#names + 1] = name end
	end
	table.sort(names, NameBefore)
	return names
end

function ns.ClearNeverList()
	local never = NeverSet()
	if never then wipe(never) end
end

-- Puts somebody on the list as a deliberate act (a shift-right-click on the
-- prompt, /manners never, the options box) and always says so, since it is
-- where the way back is written. Returns the spelling on the list, or nil for
-- a name that was only space. A favour they are owed goes with them, even when
-- already listed: owed people are exempt from the list (STATUS.md), so they
-- would come straight back once the skip ran out.
function ns.PutOnNeverList(name, typed)
	local listed, already = ns.NeverOffer(name, typed)
	if not listed then return nil end

	local forgiven = false
	-- Matched against the one entry just listed, by ListedAs' rule, rather than
	-- walking the whole list once per favour: the name itself, and for an entry
	-- the player typed also the same name with the realm taken off the favour's
	-- key -- but only when no favour is filed under exactly the typed name, which
	-- is then the one meant.
	local byRealm = NeverSet()[listed] == true
	local viaRealm
	for key in pairs(owed) do
		if SameName(listed, key) then
			byRealm = false
			owed[key] = nil
			forgiven = true
			-- The ledger's row goes with the debt: its own sweep walks the
			-- debts and could never reach one let go here.
			TellLedger("LetGo", key, "never")
		elseif byRealm and SameName(listed, ShortName(key)) then
			viaRealm = viaRealm or {}
			viaRealm[#viaRealm + 1] = key
		end
	end
	if viaRealm and byRealm then
		for _, key in ipairs(viaRealm) do
			owed[key] = nil
			forgiven = true
			TellLedger("LetGo", key, "never")
		end
	end
	-- Repainted here too, since somebody already listed never reaches the end.
	if forgiven then
		SaveDebts()
		ns.RepaintOptions()
	end

	-- In a fight the secure button cannot be re-armed, so if the prompt names
	-- the person just listed, a press still casts at them until it ends, and
	-- the line has to say so. Guarded: the prompt may not have loaded.
	local onPromptInFight = false
	if InCombatLockdown() and ns.Prompt and ns.Prompt.Showing then
		ns.Guard("never-offer prompt check", function()
			local showing = ns.Prompt:Showing()
			onPromptInFight = type(showing) == "table" and type(showing.name) == "string"
				and ListedAs(showing.name) == listed
		end)
	end

	if already then
		if forgiven and onPromptInFight then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list, and the favour they did you is let go -- but the prompt cannot move off them in this fight, and a press still casts at them."]
				:format(listed))
		elseif onPromptInFight then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list -- but the prompt cannot move off them in this fight, and a press still casts at them."]
				:format(listed))
		elseif forgiven then
			addon:Print(L["|cffffffff%s|r is already on your never-offer list, and the favour they did you is let go."]
				:format(listed))
		else
			addon:Print(L["|cffffffff%s|r is already on your never-offer list."]:format(listed))
		end
		return listed
	end

	-- The way back goes in whole: it is typed exactly as shown in every language.
	local undo = "/manners allow " .. listed
	if forgiven and onPromptInFight then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you, and their favour is let go -- but in this fight a press still casts at them. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	elseif onPromptInFight then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you -- but the prompt cannot move off them in this fight, and a press still casts at them. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	elseif forgiven then
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you, and the favour they just did you is let go. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	else
		addon:Print(L["|cffffffff%s|r will not be offered anything again unless they buff you. |cffffd100%s|r takes them off the list."]
			:format(listed, undo))
	end
	ns.RepaintOptions()
	return listed
end

---------------------------------------------------------------------------
-- friends and guildmates
--
-- For "Who comes first": a preference about order, never a reason to offer or
-- drop anybody, so anything the client will not say reads as "not a friend".
---------------------------------------------------------------------------

-- The section's two entry points; the rest is private to the block below, for
-- the main chunk's 200 locals.
local SweepCloseness, Closeness
do
	-- How long an answer about one person is kept: a friends list changes over
	-- minutes, and the scan asks about everybody two and a half times a second.
	local CLOSE_SECONDS = 10
	local closeCache = {}
	local friendNames, friendGuids, friendsReadAt = {}, {}, nil

	-- The fallback for a client whose C_FriendList has no IsFriend: the list read
	-- by index, the way the addons known to work on this client read it.
	local function ReadFriendsList(now)
		if friendsReadAt and now - friendsReadAt < CLOSE_SECONDS then return end
		friendsReadAt = now
		wipe(friendNames)
		wipe(friendGuids)
		local list = _G.C_FriendList
		if type(list) ~= "table" then return end
		local count = safecall(list.GetNumFriends)
		if type(count) ~= "number" then return end
		-- The game caps a friends list well below this; the bound is there so a
		-- nonsense count cannot turn one scan into a very long one.
		for i = 1, math.min(count, 200) do
			local info = safecall(list.GetFriendInfoByIndex, i)
			if type(info) == "table" then
				local name, guid = plain(info.name), plain(info.guid)
				if type(name) == "string" then friendNames[name:lower()] = true end
				if type(guid) == "string" then friendGuids[guid] = true end
			end
		end
	end

	-- Old answers go, once per lifetime of an answer: Closeness checks an answer's
	-- age before trusting it, so one left standing a little longer is never used.
	local closeSweptAt

	function SweepCloseness(now)
		if closeSweptAt and now >= closeSweptAt and now - closeSweptAt < CLOSE_SECONDS then return end
		closeSweptAt = now
		for name, answer in pairs(closeCache) do
			if now - answer.at >= CLOSE_SECONDS then closeCache[name] = nil end
		end
	end

	-- GetGuildInfo's realm as something to compare: "" for your own realm, which
	-- it answers as nil, and nil (matching nothing) for a secret or nonsense.
	local function GuildRealm(realm)
		if issecretvalue and issecretvalue(realm) then return nil end
		if realm == nil then return "" end
		if type(realm) ~= "string" then return nil end
		return realm
	end

	-- "friend", "guild", or nil for neither and for could-not-tell alike; friend
	-- first, the more particular thing for the tooltip to say. The GUID goes to
	-- the client as handed over, and is never compared or read here: a secret
	-- throws on both.
	function Closeness(unit, full, now)
		local cached = closeCache[full]
		if cached and now - cached.at < CLOSE_SECONDS then return cached.kind or nil end

		local kind
		local rawGuid = UnitGUID(unit)
		local list, bnet = _G.C_FriendList, _G.C_BattleNet
		if type(list) == "table" and safecall(list.IsFriend, rawGuid) == true then
			kind = "friend"
		elseif type(bnet) == "table"
			and type(safecall(bnet.GetGameAccountInfoByGUID, rawGuid)) == "table" then
			-- Answers for Battle.net friends and nobody else; the Camelot social
			-- addon accepts group invites from friends on exactly this.
			kind = "friend"
		else
			ReadFriendsList(now)
			local guid = plain(rawGuid)
			-- By the name as filed, which is how the list spells a friend: "Anna"
			-- of your own realm, "Anna-Realm" of another. Not with the realm taken
			-- off (ns.TargetName), which made a stranger from another realm who
			-- shares a first name with a friend a friend herself.
			if (type(guid) == "string" and friendGuids[guid])
				or friendNames[full:lower()] then
				kind = "friend"
			end
		end

		if not kind then
			local inMine
			if type(_G.UnitIsInMyGuild) == "function" then
				local ok, answer = pcall(_G.UnitIsInMyGuild, unit)
				if ok then inMine = plain(answer) end
			end
			if inMine == true then
				kind = "guild"
			elseif inMine == nil then
				-- Only where UnitIsInMyGuild gave no answer (a plain no is one): the two guild
				-- names and their realms, a guild's name being unique only on its realm.
				-- pcall, not safecall: the realm is the fourth return.
				local okTheirs, theirs, _, _, theirRealm = pcall(_G.GetGuildInfo, unit)
				local okOurs, ours, _, _, ourRealm = pcall(_G.GetGuildInfo, "player")
				theirs, ours = plain(theirs), plain(ours)
				theirRealm, ourRealm = GuildRealm(theirRealm), GuildRealm(ourRealm)
				if okTheirs and okOurs and type(theirs) == "string" and theirs ~= ""
					and theirs == ours and theirRealm and theirRealm == ourRealm then
					kind = "guild"
				end
			end
		end

		closeCache[full] = { at = now, kind = kind or false }
		return kind
	end
end

-- Tell the favour ledger (Ledger.lua) what happened to a favour: one way only,
-- so it never changes who is offered what, and guarded. Assigns the local
-- declared above the never-offer list.
function TellLedger(event, ...)
	local ledger = ns.Ledger
	local fn = ledger and ledger[event]
	if type(fn) == "function" then ns.Guard("ledger " .. event, fn, ...) end
	-- "In character" counts the exchanges with each person this session from
	-- the same four moments, for its lines about meeting somebody again.
	local heard = ns.InCharacter and ns.InCharacter.Heard
	if type(heard) == "function" then ns.Guard("in character " .. event, heard, event, ...) end
	-- The launcher counts the favours waiting to be returned.
	if ns.RefreshBrokerText then ns.Guard("broker text", ns.RefreshBrokerText) end
end
ns.TellLedger = TellLedger

-- Somebody who asked comes after the people who buffed you and before your
-- group. One and a half rather than a renumbering, so the other numbers keep
-- meaning what they mean in the sort, the prompt's hold and bug reports.
local PRIORITY = { target = 0, owed = 1, asked = 1.5, group = 2, nearby = 3 }
-- A group member put first by a ready check or by coming back from the dead:
-- behind your deliberate target, ahead of everybody else.
PRIORITY.sweep = 0.5
-- Your own buff: behind everybody waiting on you for something -- your pick, a
-- ready check or a death, a favour, a request -- since they may walk off and
-- you will not; ahead of your group and passers-by, since what you carry is
-- what you fight with.
PRIORITY.self = 1.75

-- The group's unit tokens, spelled out once rather than joined on every scan.
local GROUP_TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	GROUP_TOKENS.raid[i] = "raid" .. i
	GROUP_TOKENS.party[i] = "party" .. i
end

-- fn(unit, pointed). `pointed` marks a unit the player deliberately picked out:
-- target and focus, which stand until the player changes them. Mouseover is
-- wherever the cursor happens to be, and counting it would flash distant
-- strangers onto the prompt. Focus comes before mouseover because one verdict
-- is reached per person per scan, on whichever token reaches them first.
local function IterateUnits(fn)
	fn("target", true)
	fn("focus", true)
	fn("mouseover")

	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if n > 0 then
		local inRaid = plain(IsInRaid and IsInRaid()) == true
		local prefix = inRaid and "raid" or "party"
		local tokens = GROUP_TOKENS[prefix]
		local count = inRaid and n or (n - 1)
		for i = 1, count do
			fn(tokens[i] or (prefix .. i))
		end
	end

	-- Our own list from NAME_PLATE_UNIT_ADDED (ns.nameplateUnits, Core.lua): a
	-- frame's token is a secret. The frames only when that list is empty.
	local plated = 0
	for token in pairs(ns.nameplateUnits) do
		if plain(UnitExists(token)) then
			plated = plated + 1
			fn(token)
		else
			ns.nameplateUnits[token] = nil
		end
	end

	if plated == 0 and caps.namePlates then
		local plates = safecall(C_NamePlate.GetNamePlates)
		if type(plates) == "table" then
			for _, plate in pairs(plates) do
				local token = plate and plain(plate.namePlateUnitToken)
				if token then fn(token) end
			end
		end
	end
end

-- The token that names this person at this moment, or nil. Asked by the
-- prompt's press (Prompt/Press.lua), which speaks only to somebody a token
-- still holds: a remembered passer-by and the tokenless favour have none, and
-- the token the scan found them by may name somebody else by now. Every token
-- the scan walks, compared by the name they are filed under (UnitFullName:
-- the surname on Forever, the realm elsewhere), so another "Weirbeard" is not
-- Weirbeard Jenkins. `hint`, the scan's token, is asked first. Once a press,
-- never on the scan.
function ns.UnitFor(name, hint)
	if type(name) ~= "string" then return nil end
	if hint and plain(UnitExists(hint)) and ns.UnitFullName(hint) == name then return hint end
	local found
	IterateUnits(function(unit)
		if not found and unit ~= hint and plain(UnitExists(unit)) and ns.UnitFullName(unit) == name then
			found = unit
		end
	end)
	return found
end

---------------------------------------------------------------------------
-- dungeons and raids
--
-- Two moments put a group member missing your buff at the front: a ready
-- check, which is when a buffer sweeps the group before a pull, and coming
-- back from the dead, which costs every buff. And two limits on offers nobody
-- asked for: the mana you keep for yourself, and the raid groups you were
-- given. A favour owed and a request from chat are never held back by either.
---------------------------------------------------------------------------

-- How long a ready check counts as running when the client names no time, or
-- a nonsense one: the game's own lasts 35 seconds.
local READY_CHECK_SECONDS = 35
-- How long the group stays first once everybody has answered: the check is
-- where the pre-pull sweep starts, not all of it, and everybody answers in a
-- few seconds. The pull ends it sooner.
local READY_CHECK_AFTER = 60
-- How long somebody back from the dead stays at the front: long enough to be
-- rezzed, to stand up and to be buffed, short enough to be about the death.
local REVIVED_SECONDS = 120
-- Once mana is being saved, how far past the floor it must climb before the
-- group comes back, so that one cast dipping under it and the regen climbing
-- back do not blink the group on and off the prompt between casts.
local MANA_MARGIN = 5

-- readyUntil: when the group stops coming first for a ready check, or nil.
-- down: [unit token] = the name read when it was seen dead (false when none
-- could be read). revived: [name] = GetTime() they were seen alive again.
-- prefix: which tokens `down` is about. saving: true while the mana floor is
-- holding offers back. One table for the main chunk's 200 locals.
local sweep = { readyUntil = nil, down = {}, revived = {}, prefix = nil, saving = nil }

-- Either end of a ready check repaints at once rather than at the next scan:
-- a ready check lasts seconds.
function addon:READY_CHECK(_, _, timeLeft)
	local seconds = plain(timeLeft)
	if type(seconds) ~= "number" or seconds <= 0 or seconds > 120 then seconds = READY_CHECK_SECONDS end
	sweep.readyUntil = GetTime() + seconds
	if ns.Prompt then ns.Guard("ready check", ns.Prompt.Refresh, ns.Prompt) end
end

-- Everybody has answered, which in an organised raid takes seconds: the buffing
-- before the pull has only started, so the group stays first a while longer.
-- An end heard with no check running (a reload in the middle of one) starts
-- nothing.
function addon:READY_CHECK_FINISHED()
	local now = GetTime()
	if ns.ReadyCheckRunning(now) then
		sweep.readyUntil = now + READY_CHECK_AFTER
	else
		sweep.readyUntil = nil
	end
	if ns.Prompt then ns.Guard("ready check over", ns.Prompt.Refresh, ns.Prompt) end
end

-- The pull is the real end of the sweep before it; called as the fight starts.
function ns.EndReadyCheck()
	sweep.readyUntil = nil
end

function ns.ReadyCheckRunning(now)
	local untilAt = sweep.readyUntil
	return untilAt ~= nil and untilAt > (now or GetTime())
end

-- Who in the group has just come back from the dead, walked on every tick
-- rather than on UNIT_HEALTH, which fires hundreds of times a second in a raid
-- fight: forty questions every 0.4 s is cheaper, and the tick runs in fights
-- and while you are dead. A secret answer changes nothing. The name is read
-- as somebody dies, on every tick they lie dead, and as they stand up: a
-- roster change can hand the token to somebody else, dead or alive, and one
-- found under a new name is a new arrival, asked about Feign Death as such.
function ns.WatchGroupDeaths(now)
	local db = addon.db and addon.db.profile
	local down, revived = sweep.down, sweep.revived
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if not (db and db.priority.revived == true) or n <= 0 then
		sweep.prefix = nil
		if next(down) then wipe(down) end
		if next(revived) then wipe(revived) end
		return
	end

	local inRaid = plain(IsInRaid and IsInRaid()) == true
	local prefix = inRaid and "raid" or "party"
	-- A party that became a raid renumbered everybody.
	if prefix ~= sweep.prefix then
		wipe(down)
		sweep.prefix = prefix
	end
	local tokens = GROUP_TOKENS[prefix]
	local count = math.min(inRaid and n or (n - 1), 40)
	-- Called directly, as UnitIsDeadOrGhost is: a group token never throws.
	local feigning = _G.UnitIsFeignDeath
	if type(feigning) ~= "function" then feigning = nil end
	for i = 1, count do
		local unit = tokens[i]
		local dead = plain(UnitIsDeadOrGhost(unit))
		if dead == true and down[unit] ~= nil then
			local name = ns.UnitFullName(unit)
			if name and name ~= down[unit] then down[unit] = nil end
		end
		-- A hunter's Feign Death reads as dead here, and standing up from it
		-- costs no buffs: taken as no answer, so nothing about them changes.
		-- Asked only of somebody not yet down: for one already down either
		-- answer leaves them so, and a wiped raid lying dead asked it of
		-- every one of them on every tick.
		if dead == true and down[unit] == nil and feigning and plain(feigning(unit)) == true then
			dead = nil
		end
		if dead == true then
			if down[unit] == nil then down[unit] = ns.UnitFullName(unit) or false end
		elseif dead == false and down[unit] ~= nil then
			local was = down[unit]
			down[unit] = nil
			if was and ns.UnitFullName(unit) == was then revived[was] = now end
		end
	end
	-- Tokens past the end of a group that shrank.
	for unit in pairs(down) do
		local index = tonumber(unit:match("(%d+)$"))
		if not index or index > count then down[unit] = nil end
	end
	for name, at in pairs(revived) do
		if now - at >= REVIVED_SECONDS then revived[name] = nil end
	end
end

-- Why this group member goes to the front now, or nil: "readycheck" or
-- "revived". `ready` is the scan's reading of the ready check.
local function SweepReason(name, now, ready, db)
	if ready then return "readycheck" end
	local at = db.priority.revived == true and sweep.revived[name]
	if at and now - at < REVIVED_SECONDS then return "revived" end
	return nil
end

-- The raid group (1-8) a unit is in, or nil when it cannot be told: Core's
-- one reading of the roster, which the group casts ask too.
local RaidGroupOf = ns.RaidSubgroup

-- The raid groups still ticked, as "1, 2, 3", for /manners debug: nil when all
-- eight are (the setting changes nothing), false when none are.
function ns.BuffedRaidGroups()
	local db = addon.db and addon.db.profile
	local skip = db and db.filters and db.filters.skipRaidGroups
	if type(skip) ~= "table" or next(skip) == nil then return nil end
	local ticked = {}
	for group = 1, 8 do
		if not skip[group] then ticked[#ticked + 1] = tostring(group) end
	end
	if #ticked == 0 then return false end
	return table.concat(ticked, ", ")
end

-- While the mana floor is holding back offers nobody asked for: the floor, and
-- the share of your mana at which the group comes back. nil when it is not
-- (off, a class with no mana bar, or a reading the client withheld, which
-- offers as before). Saving starts under the floor and lasts until
-- MANA_MARGIN past it.
function ns.SavingMana()
	local db = addon.db and addon.db.profile
	local floor = db and db.filters and db.filters.manaFloor
	if type(floor) ~= "number" or floor <= 0 then
		sweep.saving = nil
		return nil
	end
	local most = plain(UnitPowerMax("player", MANA))
	local mana = plain(UnitPower("player", MANA))
	if type(most) ~= "number" or most <= 0 or type(mana) ~= "number" then
		sweep.saving = nil
		return nil
	end
	local resume = math.min(floor + MANA_MARGIN, 100)
	local limit = sweep.saving and resume or floor
	sweep.saving = mana * 100 < limit * most or nil
	if sweep.saving then return floor, resume end
	return nil
end

-- Whether "Not while mounted" is keeping the prompt away right now: one answer
-- for the queue, a keypress on the empty prompt and /manners debug. A withheld
-- answer counts as not mounted, so the switch can hide the prompt but never
-- lose it.
function ns.HiddenWhileMounted()
	local db = addon.db and addon.db.profile
	if not (db and db.filters and db.filters.hideMounted == true) then return false end
	if type(IsMounted) ~= "function" then return false end
	return plain(safecall(IsMounted)) == true
end

-- Whether you are up in the air, where a cast fails ("You are mounted") rather
-- than taking you off the mount: warcraft.wiki.gg, Mount macros, "If you are
-- flying, you can no longer cast spells". Not with the client's Auto Dismount
-- in Flight on (autoDismountFlying, off by default), which drops you instead.
-- The queue still offers, as it does on the ground; the press asks this for
-- its spoken line alone (Prompt/Press.lua, HoldLine), and the refusal is
-- yours, not theirs (CASTER_SIDE). A withheld answer counts as on the ground.
function ns.FlyingCastFails()
	if plain(safecall(_G.IsFlying)) ~= true then return false end
	local value = plain(safecall(_G.GetCVar or (C_CVar and C_CVar.GetCVar), "autoDismountFlying"))
	return not (value == "1" or value == 1 or value == true)
end

---------------------------------------------------------------------------
-- flagged for PvP
--
-- A buff on somebody flagged for PvP flags you too, for minutes -- and so does
-- a group spell or a shout landing on one flagged member of your party, and on
-- Mists and retail any buff cast on one of you (LandsOnParty). So while "Skip
-- players flagged for PvP" is on and you are not flagged yourself, nobody who
-- reads as flagged is offered anything, whatever the reason. While
-- you are flagged -- a battleground, /pvp, an enemy town -- buffing them costs
-- nothing more and the rule stands aside; not while your own flag is running
-- out, though (YouAreFlagged), since a buff restarts that countdown. Your own
-- entry (SelfEntry) never passes through it, unless the buff lands on your
-- whole party (LandsOnParty); held back, your class's own take its place.
--
-- A flag the game will not show is "cannot tell", and the person is offered.
-- Somebody no token reaches -- a favour from a stranger, a passer-by
-- remembered -- is judged on the flag last read off them, kept on the debt and
-- on the memory. A favour owed to somebody flagged stays owed, and is offered
-- if the flag drops while it is still remembered: the lesser case (a flag lasts
-- five minutes, a favour two by default), so nothing promises it to the player.
--
-- War Mode: Forever has Retail's C_PvP war mode calls but no way to switch it
-- on, and where it is on, a player in it reads as flagged anyway. So nothing
-- asks about War Mode.
---------------------------------------------------------------------------

-- Whether a unit is flagged, the free-for-all flag included: true, false, or
-- nil when the game will not say. Called directly (the policy atop Core.lua):
-- the walk has already handed the same token to UnitExists and the rest.
-- Written out rather than as `f and plain(f(unit)) or nil`, which turns a
-- definite false into nil.
local function PvPFlag(unit)
	local isPvP, isFFA = _G.UnitIsPVP, _G.UnitIsPVPFreeForAll
	local pvp, ffa
	if type(isPvP) == "function" then pvp = plain(isPvP(unit)) end
	if type(isFFA) == "function" then ffa = plain(isFFA(unit)) end
	if pvp == true or ffa == true then return true end
	if pvp == false and ffa == false then return false end
	return nil
end
ns.PvPFlag = PvPFlag

-- Whether you are flagged, which stands the rule aside, and second whether it
-- stands only because your flag is running out. Your own flag withheld counts
-- as not flagged -- except in a battleground or arena -- because the mistakes
-- are unequal: one costs an offer, the other the very flag the setting spares
-- you. Flagged with the countdown running (after /pvp off, a flagged player
-- buffed, an enemy town left) counts as not flagged outside a battleground or
-- arena: every flagged player buffed restarts the five minutes (the owner's
-- own report). A countdown the game will not show is no countdown.
local function YouAreFlagged()
	local mine = PvPFlag("player")
	if mine == false then return false end
	local inside, kind = safecall(_G.IsInInstance)
	local battle = (inside == true or inside == 1) and (kind == "pvp" or kind == "arena")
	if mine == nil or battle then return battle end
	if safecall(_G.IsPVPTimerRunning) == true then return false, true end
	return true
end

local function PvPRuleStands(db)
	return db.filters.skipPvP == true and not YouAreFlagged()
end

-- Whether the rule would hold back somebody whose flag reads `flag`: for the
-- favour's chat line (Favours.lua), which is said before any scan.
function ns.PvPHoldsBack(flag)
	local db = addon.db and addon.db.profile
	return flag == true and db ~= nil and PvPRuleStands(db)
end

-- What the last scan made of it, for the prompt (HeldForPvP), /manners debug
-- and Diagnostics: `names` everybody held back, `groups` the group casts and
-- shouts held back ({ spell, label, name } each), `stands` whether the rule
-- stood, `you` whether it stood aside because you are flagged, `countdown`
-- whether it stood only because your flag is running out. Every scan starts
-- it again.
local pvpScan = { names = {}, groups = {} }

-- The record of the scan under way while the rule stands in it, nil while
-- it does not: GroupCasts writes the group casts it holds back into it.
function ns.PvPRecord()
	if pvpScan.stands then return pvpScan end
	return nil
end

-- Whether a press on this entry lands on the whole party, whoever it names: a
-- shout, or, on a set whose buffs cast on somebody in your party or raid land
-- on every one of them (ns.WIDE_CASTS: Mists, retail), a buff aimed at a group
-- member or at yourself in a group. A stranger outside the group takes it
-- alone, and so does anybody given a buff marked `alone` or one of your
-- class's own. On those sets a shout and such a buff both reach the whole
-- party and raid within 100 yards (Buffs.lua), which is where ShoutFlagged
-- looks.
local function LandsOnParty(entry)
	local buff = entry.buff
	if not buff then return false end
	if buff.selfCast then return true end
	return ns.WIDE_CASTS == true and entry.inGroup == true and not entry.groupCast
		and not buff.alone and not buff.own
end

-- Whether the prompt must let go of this entry for PvP: the last scan held
-- its person back -- which the prompt, having just scanned, is asking about
-- this moment -- or it is a group cast, a shout or a buff that lands on the
-- whole party (LandsOnParty), and somebody in it reads as flagged now. The
-- panel's hold and a press both ask, so neither outlasts a flag raised since
-- the paint.
function ns.HeldForPvP(entry)
	if not (entry and entry.name and pvpScan.stands) then return false end
	if pvpScan.names[entry.name] then return true end
	if entry.groupCast then return ns.GroupCastFlagged(entry) ~= nil end
	if LandsOnParty(entry) then return ns.ShoutFlagged() ~= nil end
	return false
end

-- For /manners debug and Diagnostics: who the rule is holding back, in the
-- words the rest of those lines use. `scan` scans first, for a page that is not
-- repainted by one.
function ns.PvPLines(scan)
	if scan then ns.Guard("PvP lines", ns.BuildQueue) end
	local out = {}
	if pvpScan.you then
		out[1] = L["|cffffd100you are flagged for PvP|r -- players flagged for PvP are offered until you are not"]
		return out
	end
	-- Flagged, and yet the rule stands: said, or the list below reads as
	-- the tooltip's "ignored while you are flagged" broken.
	if pvpScan.countdown then
		out[1] = L["|cffffd100your PvP flag is running out|r -- players flagged for PvP are not offered, since buffing one would start it again"]
	end
	local names = {}
	for name in pairs(pvpScan.names) do names[#names + 1] = name end
	table.sort(names)
	-- A handful by name, then a count: a battleground crowd is forty.
	for i, name in ipairs(names) do
		if i > 5 then
			out[#out + 1] = L["...and %d more flagged for PvP"]:format(#names - 5)
			break
		end
		out[#out + 1] = L["|cffffffff%s|r: flagged for PvP -- buffing them would flag you"]:format(name)
	end
	for _, held in ipairs(pvpScan.groups) do
		out[#out + 1] = L["no %s for %s: |cffffffff%s|r is flagged for PvP, and it would land on them too"]
			:format(held.spell, held.label, held.name)
	end
	return out
end

-- A shout lands on your whole party (in a raid your subgroup, or the whole
-- raid where shouts reach it: ShoutFlagged), whoever the prompt names, so
-- while the rule stands one flagged member holds back every shout, as for a
-- group cast, each a verdict. So does a buff that lands on the whole party
-- however it is aimed (LandsOnParty), yours included. The party is walked
-- only when one is queued. Returns what is kept, and the flagged member's
-- name when it held anything back.
local function HoldShoutsForPvP(queue, rejected, inRaid)
	local shout
	for _, entry in ipairs(queue) do
		if LandsOnParty(entry) then
			shout = entry.buff
			break
		end
	end
	local flagged = shout and ns.ShoutFlagged(inRaid)
	if not flagged then return queue end
	local label = not inRaid and L["your party"]
		or ns.PARTY_IS_SUBGROUP and L["your group"] or L["your raid"]
	pvpScan.groups[#pvpScan.groups + 1] = { spell = ns.BuffName(shout), label = label, name = flagged }
	local kept = {}
	for _, entry in ipairs(queue) do
		if LandsOnParty(entry) then
			rejected[entry.name] = true
		else
			kept[#kept + 1] = entry
		end
	end
	return kept, flagged
end

---------------------------------------------------------------------------
-- passers-by, remembered
--
-- Friendly nameplates are off by default, so for most players a stranger is
-- found by the cursor alone: "mouseover" is the one token that reaches them,
-- and it goes the moment the cursor leaves them for the prompt. The next scan
-- had nobody, the empty-queue fuse took the prompt down, and the offer
-- vanished on the way to being clicked, every time (a CurseForge report on
-- 1.1.0). With nameplates on, somebody pacing the edge of "Passers-by within"
-- blinked on and off the same way.
--
-- So a passer-by offered through a token nobody pointed at -- the cursor, a
-- nameplate -- is remembered by name, and for a few seconds after the last
-- token reached them is offered as the owed fallback offers a favour: no
-- token, the macro's /target line, range unknown. A cast on somebody who has
-- walked off is refused, and the back-off (NoteRefusal) lets them go. Only
-- plain data is kept, never a unit token, which may name somebody else by then.
--
-- Somebody who asked in chat is remembered the same way while the request
-- stands: a request names a person, not a unit. Somebody who buffed you longer
-- ago than "Let them go after" is offered by the owed fallback again for the
-- same few seconds after a token last reached them (`near` on the debt): being
-- found is evidence of reach as good as a fresh favour.
---------------------------------------------------------------------------

-- How long after the last token reached them. Reaching the prompt and reading
-- it takes a second or two; somebody running off at seven yards a second
-- leaves a buff's thirty yards in about three, somebody standing about far
-- later. Ten covers the trip, and a runner costs one refused cast; longer
-- would fill the queue with a crowd long gone.
local LINGER_SECONDS = 10
-- A city square puts dozens of people through the scan in ten seconds; the
-- ones seen longest ago make room.
local LINGER_CAP = 40

-- [name] = { seen, reason, within, buff, class, targetName, hasMana, known,
-- checked, expires, close, pvp }: `seen` is the last moment a token reached
-- them (near enough, for a passer-by), `reason` why they were offered then --
-- "nearby" or "asked" -- and `within` the "Passers-by within" step that
-- judged a passer-by near. The rest is what their queue entry said then,
-- `expires` being the top-up's remaining time as a moment on the clock, so it
-- counts down while they are unseen, `hasMana` what the walk read for "Only
-- buffs they can use", and `pvp` their PvP flag as last read (nil when the
-- setting is off, which reads none).
local passing = {}
ns.passersBy = passing

-- Written by the walk for every passer-by or asker it offers through a token
-- nobody pointed at, from the entry it just queued. Somebody new makes room
-- first.
local function RememberPasserBy(entry, now, within, hasMana, guid)
	local memo = passing[entry.name]
	if not memo then
		local held, oldest, at = 0, nil, nil
		for who, other in pairs(passing) do
			held = held + 1
			if not at or other.seen < at then oldest, at = who, other.seen end
		end
		if held >= LINGER_CAP then passing[oldest] = nil end
		memo = {}
		passing[entry.name] = memo
	end
	memo.seen, memo.reason, memo.within = now, entry.reason, within
	memo.buff, memo.class, memo.targetName = entry.buff, entry.class, entry.targetName
	memo.hasMana = hasMana
	-- For the /ignore list, asked of a name alone when the person is no longer in
	-- reach (OfferPassersBy).
	memo.guid = guid
	memo.pvp = entry.pvp
	-- The reading as well, so the panel keeps saying what it said while they
	-- had a token: "needs" does not turn into "unverified" as the cursor
	-- leaves them.
	memo.known, memo.checked, memo.close = entry.known, entry.checked, entry.close
	memo.withheld = entry.withheld
	memo.expires = entry.remaining and (now + entry.remaining) or nil
	memo.seconds, memo.lead, memo.leadKind = entry.duration, entry.lead, entry.leadKind
end

-- The fight is over (PLAYER_REGEN_ENABLED): a passer-by remembered on a
-- reading the client withheld is let go, since nothing can read them again
-- without a token and the fight refused everybody. A token reaching them
-- asks afresh. Somebody who asked stays: the request is the reason. So does a
-- refusal that no fight made (a buff this client never shows): letting it go
-- only took them off the prompt until the next scan.
function ns.ForgetUnreadPassersBy()
	for name, memo in pairs(passing) do
		if memo.reason == "nearby" and memo.withheld then passing[name] = nil end
	end
end

-- Whether the buff they were offered is still one the walk would offer them:
-- still switched on and learned (the scan's `candidates`), still the pin where
-- one is set, and, for a passer-by with "Only buffs they can use" on, still of
-- use to them (a request asks for what it asks for). Not re-picked when it is
-- not: without a token nothing says what else they lack, and the reading kept
-- is about this buff alone. `askOnly` is the scan's neverAuto spells a request
-- may name (ns.AskOnlyBuffs), still castable for somebody who asked for one.
local function StillCastable(memo, candidates, f, askOnly)
	local key = memo.buff.key
	local pinned = ns.PinnedBuff()
	if pinned and pinned.key ~= key then return false end
	for _, buff in ipairs(candidates) do
		if buff.key == key then
			return not (f.relevantOnly and memo.reason ~= "asked"
				and buff.manaOnly and memo.hasMana == false)
		end
	end
	if askOnly and memo.reason == "asked" then
		for _, buff in ipairs(askOnly) do
			if buff.key == key then return true end
		end
	end
	return false
end

-- The walk's second half for the remembered: everybody no token reached this
-- scan, offered by name until LINGER_SECONDS after one last did. In
-- `rejected` (the walk's), true is a verdict about the person -- covered,
-- dead, out of range, listed, outside a city -- and lets them go; "far" is
-- only the nearness check, which does not (see visit). `drop` turns every
-- passer-by down, but not somebody who asked: a request is a source of its
-- own. Somebody last read as flagged for PvP is let go while the rule stands,
-- and recorded.
--
-- Letting somebody go on a verdict writes it into `rejected` too, which
-- BuildQueue hands the prompt, so the cursor's hold cannot outlast it
-- (hovering, Prompt/Prompt.lua). Running out of time is no verdict. `verdict`
-- is the scan's never-offer answers (NeverVerdicts); `askOnly`
-- StillCastable's; `ignoring` that the /ignore list has anybody on it, whom
-- no memory offers either: a member of the group stays offered, and so is
-- remembered, and the group may be gone by the time the memory is read.
local function OfferPassersBy(queue, seen, rejected, now, db, candidates, askOnly, verdict, drop, ignoring)
	for name, memo in pairs(passing) do
		local debt = db.sources.owed and owed[name]
		local nearby = memo.reason == "nearby"
		-- Remembered while you were flagged yourself, and flagged when last
		-- read: held back like anybody a token finds flagged, and so let go,
		-- a verdict. A token reaching them again reads the flag afresh.
		local flagged = pvpScan.stands and memo.pvp == true
		if flagged then pvpScan.names[name] = true end
		-- Let go for good on any of these. Near by a "Passers-by within" step
		-- that no longer stands is not near, so narrowing it applies at once.
		-- One block test covers a right-press skip and a press that reached
		-- nobody (the whole person), the retry cooldown a press on this buff
		-- wrote, and the back-off after refusals. A request answered, lapsed
		-- or switched off is no reason left to offer them.
		if (nearby and (drop or memo.within ~= db.filters.proximity))
			or (not nearby and not ns.StillAsked(name, memo.buff.key, now))
			or (ns.zonedAt and memo.seen < ns.zonedAt)
			or rejected[name] == true
			or flagged
			or not StillCastable(memo, candidates, db.filters, askOnly)
			or ns.IsBlocked(name, memo.buff.key, now)
			or (db.filters.verifiedOnly and nearby and memo.checked and memo.known == nil)
			or ListedAs(name, verdict) ~= nil
			or (ignoring and ns.Ignored(name, memo.guid))
			or not SafeForMacro(name) then
			passing[name] = nil
			if not seen[name] then rejected[name] = true end
		elseif now - memo.seen >= LINGER_SECONDS then
			passing[name] = nil
		elseif rejected[name] == "unread" then
			-- A token reached them this scan and the client would not say
			-- (visit): what was read of them before says nothing more.
		elseif not seen[name] and not (debt and LiveExpiry(debt) > now) then
			-- Neither a token this scan nor a favour, whose paths offer them.
			queue[#queue + 1] = {
				name = name,
				short = ShortName(name),
				targetName = memo.targetName,
				class = memo.class,
				buff = memo.buff,
				reason = memo.reason,
				inGroup = false,
				priority = PRIORITY[memo.reason],
				-- ranged is left unwritten, as on the owed fallback: nothing
				-- measured them this scan.
				known = memo.known,
				remaining = memo.expires and (memo.expires - now) or nil,
				checked = memo.checked,
				close = memo.close,
				duration = memo.seconds,
				lead = memo.lead,
				leadKind = memo.leadKind,
			}
		end
	end
end

-- PickBuffFor's callbacks for the queue, at file level so that no person
-- costs a closure. The tokenless path has no aura to read, hence NoReading.
-- "Skip my own class when they can cast it too": somebody of your class,
-- offered unasked, whose level is at or past the one your best rank of this
-- buff is learned at (Buffs.lua, RANK_LEVEL), could give themselves the same.
-- One below it is still offered: yours is better than theirs. A talent buff,
-- which not everybody of the class has, and a shout, which reaches them
-- anyway, are never skipped this way. A level the client will not give is
-- taken as one that could cast it, and -1 (a skull) is above every rank.
-- Handed to PickBuffFor as opts.skip, apart from opts.blocked: a paladin's
-- walk reads a block as "just offered, wait", and the skip read that way left
-- another paladin with nothing.
local function SelfServed(candidate, opts)
	if not opts.sameClass or candidate.selfCast or candidate.talent then return false end
	local info = ns.BuffInfo(candidate)
	local need = ns.RankLevel(info and info.topRank) or 1
	local level = opts.level
	return level == nil or level < 0 or level >= need
end

local function QueueBlocked(candidate, opts)
	return ns.IsBlocked(opts.name, candidate.key, opts.now)
end

-- The walk's aura reading, off the unit, GUID and `checked` the walk writes
-- into opts. The client's answer, and nothing else: a policy (offer the owed
-- regardless) must never be written as a reading, or PickBuffFor takes it for
-- the client saying nothing landed. Choosing not to look answers nil, not
-- false, since the walk stops at the first definite gap.
local function ReadAura(buff, opts)
	if not opts.checked then return nil end
	return UnitHasBuff(opts.unit, buff, opts.guid)
end

local function NoReading()
	return nil
end
ns.NoReading = NoReading

-- Why nothing at all is offered to you right now, whatever you are missing,
-- or nil and your name. One answer for both kinds of your own buff -- your
-- group buff and your class's own -- so there is one rule for "You" on the
-- prompt, and /manners debug and the options page say it the same way:
--   "switch"   "Myself" is switched off
--   "fight"    in a fight: the pull's own repaint arms the macro every press
--              of the fight runs, and it must not be a buff on yourself
--   "resting"  in a city or an inn, with "Also in cities and inns" off
--   "skipped"  a right-press skip, the press just made, or the game refusing
--              you; asked once here rather than per buff, which the walk
--              would answer the same way, so a skipped you costs no aura read
--   "noname"   the game will not say your name
--   "listed"   your own name is on the never-offer list
-- Resting as the city rule for passers-by reads it: only a definite yes
-- holds back, and could-not-tell offers.
--
-- Two functions, because "listed" is the one answer that walks something. The
-- first is all but that: SelfEntry asks it, and asks the list itself at the
-- very end, through the scan's answers, so only an offer about to be made pays
-- for the walk. The second is for what only explains (SelfBuffFirst and
-- MyselfLines, for /manners debug and the options page), and asks the list
-- the way a repaint does, off its cached answers.
local function HeldBackExceptList(db, now)
	if db.sources.self ~= true then return "switch" end
	if InCombatLockdown() or safecall(_G.UnitAffectingCombat, "player") == true then return "fight" end
	if not (db.ownBuffs and db.ownBuffs.inCities == true) and Resting() == true then return "resting" end
	local full = ns.UnitFullName("player")
	if not full then return "noname" end
	if ns.IsBlocked(full, nil, now or GetTime()) then return "skipped" end
	return nil, full
end

function ns.MyselfHeldBack(db, now)
	local held, full = HeldBackExceptList(db, now)
	if held then return held end
	if ns.IsNeverOffered(full) then return "listed" end
	return nil, full
end

-- The first of your class's own families that comes up missing (Core.lua,
-- OwnVerdict), in the table's order, as your entry: the spell, the reading,
-- the time left for a top-up, the charges left for a charge shield's, and for
-- a top-up how long it lasts, its lead and the kind of lead. nil when none does.
local function OwnPick(db, full, now)
	local ctx = { name = full, now = now, whenBuffed = ns.SelfWhenBuffed(db.filters),
		refreshUnder = db.filters.refreshUnder }
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		local spell, has, remaining, _, _, charges, seconds, lead, kind = ns.OwnVerdict(family, ctx)
		if spell then return spell, has, remaining, charges, seconds, lead, kind end
	end
	return nil
end

-- The buffs Affordable left out of the scan in hand (filled by BuildQueue and
-- by SelfBuffFirst, each before it asks for anything): handed to PickBuffFor
-- as opts.unpaid, one table for the file so that no scan makes one.
local UNPAID = {}

-- Your own group buff, when you are missing it or (with top-ups on) it is
-- running low: the buff, the reading, the time left and for a top-up how long it
-- lasts, its lead and the kind of lead, or nil. `mine` is
-- what of the scan's candidates goes on yourself (ns.SelfBuffs).
local function SelfBuff(db, mine, full, now)
	local f = db.filters
	local guid = plain(UnitGUID("player"))
	-- Your auras are always read, whatever "When they already have it" says:
	-- Always offer is for people the game hides theirs on, and offering you
	-- one you are wearing would come back every retry cooldown all evening.
	-- The setting still asks for a top-up, which is all PickBuffFor reads it
	-- for.
	local function reading(buff)
		return UnitHasBuff("player", buff, guid)
	end
	-- The same walk everybody gets: the switches, the pin, a paladin's one
	-- blessing at a time, and the per-buff retry cooldown.
	local buff, has, remaining, seconds, lead, kind = ns.PickBuffFor(mine, {
		-- Yours: a top-up comes earlier than for anybody else's (Core.lua, ns.LeadFor).
		own = true,
		hasMana = UnitHasMana("player"),
		inGroup = (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0,
		-- The caster is always inside their own party.
		inParty = true,
		relevantOnly = f.relevantOnly,
		whenBuffed = ns.SelfWhenBuffed(f),
		refreshUnder = f.refreshUnder,
		name = full,
		blocked = QueueBlocked,
		unpaid = UNPAID,
		now = now,
	}, reading)
	-- A pin replaces the list the walk was handed, so a pinned shout still
	-- has to be turned away here.
	if not ns.CastsOnSelf(buff) then return nil end
	-- Only on a reading: missing, or running low for a top-up. A client that
	-- will not say is no reason to offer you what you may be wearing -- your
	-- own buff bar says it better.
	if not (has == false or remaining ~= nil) then return nil end
	return buff, has, remaining, seconds, lead, kind
end

-- CastableBuffs' answer less what the game says you cannot pay for now, once
-- per scan, for everything the scan offers from it. A mage at 150 mana was
-- offered an Intellect that costs more and every press failed -- the caster's
-- fault, so nothing backed off: the prompt went round everybody, thanking
-- each, and buffed nobody. Only a no for want of mana counts: a plain no can
-- be a form the macro may still get past, and a client that will not say
-- keeps the buff. The zero-mana stop in BuildQueue stays for a client without
-- the call; your own buffs and the group spell ask for themselves.
-- `unpaid`, when given, is emptied and filled with the buffs left out: they
-- are still yours on somebody, and a paladin's walk reads them for that alone
-- (PickBuffFor, opts.unpaid).
local function Affordable(candidates, unpaid)
	if unpaid then
		for i = #unpaid, 1, -1 do unpaid[i] = nil end
	end
	local check = C_Spell and C_Spell.IsSpellUsable
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	if type(check) ~= "function" then return candidates end
	local pinned = ns.PinnedBuff()
	local out = {}
	for _, buff in ipairs(candidates) do
		local info = ns.BuffInfo(buff)
		local usable, noMana = safecall(check, (info and info.topRank) or (buff.ranks and buff.ranks[1]))
		if not (usable == false and noMana == true) then
			out[#out + 1] = buff
		elseif pinned and pinned.key == buff.key then
			-- A pin is "only ever this one": PickBuffFor swaps whatever list
			-- it is handed for the pin, so one that is left would offer it.
			return {}
		elseif unpaid then
			unpaid[#unpaid + 1] = buff
		end
	end
	return out
end

-- The group buff SelfEntry would put you on the prompt for right now, ahead
-- of your class's own, or nil: for /manners debug and Diagnostics, whose line
-- per family would otherwise call a spell "the one to cast" while the prompt
-- is on your Intellect (Commands.lua, MyselfLines). Not one held back for a
-- flagged member of the party it lands on, which the prompt is not on. Nor
-- one while your own name is on the never-offer list (MyselfHeldBack says so):
-- SelfEntry offers you nothing then.
function ns.SelfBuffFirst(db, now)
	local held, full = ns.MyselfHeldBack(db, now)
	if held then return nil end
	-- The list BuildQueue hands SelfEntry: a group buff you cannot pay for is
	-- not the one the prompt is on.
	local mine = ns.SelfBuffs(Affordable(ns.CastableBuffs(), UNPAID))
	if #mine == 0 then return nil end
	local buff = SelfBuff(db, mine, full, now)
	local inGroup = (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0
	if buff and LandsOnParty({ buff = buff, inGroup = inGroup }) and PvPRuleStands(db)
		and ns.ShoutFlagged() ~= nil then
		return nil
	end
	return buff
end

-- Your own buff, missing or (with top-ups on) running low: the one entry
-- BuildQueue makes for you, after the walk, since IsBuffableUnit turns
-- "player" away everywhere else. Returns the entry, or nil.
--
-- One entry for you at a time, your group buff first: it is the one your group
-- sees you missing, and the class's own follow in Buffs.lua's order.
--
-- Not held back while saving mana, unlike the group: a buff on yourself is
-- what the floor keeps mana for. Nor by the raid groups, which are about whom
-- you buff. Your own name on the never-offer list is honoured, though "never"
-- on the prompt switches this source off instead (StopOfferingSelf).
-- `ownOnly` leaves your group buff out, for when it is held back for PvP
-- (BuildQueue): your class's own land on you alone.
local function SelfEntry(db, candidates, now, verdict, ownOnly)
	local held, full = HeldBackExceptList(db, now)
	if held then return nil end
	-- A shout already covers you, and a few spells refuse the caster.
	local mine = ownOnly and {} or ns.SelfBuffs(candidates)
	local buff, has, remaining, charges, seconds, lead, kind
	if #mine > 0 then buff, has, remaining, seconds, lead, kind = SelfBuff(db, mine, full, now) end
	if not buff then buff, has, remaining, charges, seconds, lead, kind = OwnPick(db, full, now) end
	if not buff then return nil end
	-- Last, so the list is walked only for an offer about to be made, and
	-- through the scan's answers, which a list edit alone sets walking again.
	-- MyselfHeldBack says the same to /manners debug ("listed").
	if ListedAs(full, verdict) then return nil end

	local entry = {
		name = full,
		short = ShortName(full),
		display = L["You"],
		-- The spelling the macro's /target line carries: you are targeted by
		-- name like anybody else (STRATEGIES.self in Prompt/Macro.lua says
		-- why).
		targetName = ns.TargetName(full),
		unit = "player",
		class = caps.class,
		buff = buff,
		reason = "self",
		-- In a party or raid a group cast counts you and covers you
		-- (GroupBuffs.lua), as it does anybody in it.
		inGroup = (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0,
		priority = PRIORITY.self,
		-- A spell on yourself is always within reach.
		ranged = true,
		known = has,
		remaining = remaining,
		-- A charge shield on its last charges (Core.lua, OwnVerdict): the
		-- reason line says so rather than the time it has left.
		charges = charges,
		checked = true,
	}
	-- A top-up says how long the buff lasts and when it was due (the tooltip).
	if remaining then entry.duration, entry.lead, entry.leadKind = seconds, lead, kind end
	return entry
end

-- "Never" for yourself, from a shift-right-press on the prompt or the
-- launcher's menu: the never-offer list is a list of other people, so this
-- source goes off instead, and the line says where it comes back. Said
-- whatever Tell me in chat is set to, as a listing is. The caller repaints.
function ns.StopOfferingSelf()
	local db = addon.db and addon.db.profile
	if not db then return end
	db.sources.self = false
	addon:Print(L["your own buff will not be offered to you any more -- tick %s on the %s tab to have it back."]
		:format("|cffffd100" .. L["Myself, when I'm missing my own buff"] .. "|r", L["Who to buff"]))
	ns.RepaintOptions()
end

-- The queue, sorted, and what the scan turned down: [name] = true for
-- everybody a token reached and found covered, dead, out of range or sight,
-- listed or held back for mana (and the remembered let go on a verdict), or
-- true for the whole queue refused for your own state. The prompt reads it to
-- tell a verdict from a token merely lost (hovering, Prompt/Prompt.lua).
-- `watch` says the prompt holds somebody the queue may not: a verdict about
-- the dead then costs a name read anyway.
function ns.BuildQueue(watch)
	local db = addon.db and addon.db.profile
	-- What this scan holds back for PvP, started again whichever way it ends.
	wipe(pvpScan.names)
	wipe(pvpScan.groups)
	pvpScan.stands, pvpScan.you, pvpScan.countdown = false, nil, nil
	if not db or not ns.CanCastAnything() then return {}, true end

	-- Nothing can be cast while dead, in a vehicle, or on a taxi, so offering
	-- somebody would just be a button that fails.
	if plain(UnitIsDeadOrGhost("player")) == true then return {}, true end
	if plain(UnitIsCharmed and UnitIsCharmed("player")) == true then return {}, true end
	if UnitInVehicle and plain(UnitInVehicle("player")) == true then return {}, true end
	if UnitOnTaxi and plain(UnitOnTaxi("player")) == true then return {}, true end
	-- A mount is different: the cast works and takes you off it. So it is
	-- the player's call, and only asked when they have made it.
	if ns.HiddenWhileMounted() then return {}, true end

	local now = GetTime()
	local seen, queue = {}, {}
	-- Anybody the main path looked at and turned down. The owed fallback below
	-- holds no unit token and cannot repeat those judgements, so it reads this.
	local rejected = {}
	local f = db.filters

	-- Per scan, so /manners debug and the options page report the crowd in
	-- front of the player now. The run-of-silence count that demotes a source
	-- is deliberately not reset: forty units over ten scans is the same
	-- evidence as forty in one.
	prox.asked, prox.answered = 0, 0

	-- Everything below until the walk is asked once per scan, not per person.
	-- Nothing you cannot pay for is offered to anybody (see Affordable); an
	-- empty list is the "nothing to give anybody else" below.
	local candidates = Affordable(ns.CastableBuffs(), UNPAID)
	-- What a request in chat may name beside them: a spell Automatic never
	-- walks to (Source of Magic) that somebody asked for. nil for none.
	local askOnly = ns.AskOnlyBuffs()
	if askOnly then askOnly = Affordable(askOnly) end
	-- A warrior's shout reaches the group and nobody else, so passers-by are
	-- dropped before the distance check rather than measured for nothing
	-- (which would fill the proximity counts with people never offered).
	local groupOnly = ns.OnlyReachesGroup(candidates)
	local inRaid = plain(IsInRaid and IsInRaid()) == true
	local neverVerdict = NeverVerdicts()

	-- Offers nobody asked for, held back while you keep your mana and, in a
	-- raid, for the groups you were not given; and whether a ready check has
	-- the group first. See "dungeons and raids". Once per scan.
	local savingMana = ns.SavingMana() ~= nil
	local skipGroups
	if inRaid and type(f.skipRaidGroups) == "table" and next(f.skipRaidGroups) ~= nil then
		skipGroups = f.skipRaidGroups
	end
	local readyCheck = db.priority.readyCheck == true and ns.ReadyCheckRunning(now)
	local ignoring = IgnoresAnybody()

	-- Flagged for PvP (see above). Flags are read only with the setting on,
	-- but then even while you are flagged yourself and the rule stands aside,
	-- so the flags kept on debts and memories are current the moment you are
	-- not. `pvpHeld` is where the walk writes who it holds back, and nil
	-- while the rule does not stand.
	local pvpRead = f.skipPvP == true
	local pvpHeld
	if pvpRead then
		local you, countdown = YouAreFlagged()
		pvpScan.you, pvpScan.countdown = you or nil, countdown or nil
		if not pvpScan.you then pvpHeld = pvpScan.names end
		pvpScan.stands = pvpHeld ~= nil
	end

	-- Passers-by left alone out in the world, when asked: only a definite "not
	-- resting" does it, and could-not-tell offers them.
	local notResting = f.restingOnly == true and Resting() == false
	-- Nobody is asked about friends when Who comes first is off, which is most
	-- of its cost.
	local friendsFirst = db.priority.friends == true
	if friendsFirst then SweepCloseness(now) end

	-- A buff that cannot be paid for is a button that fails -- but only classes
	-- with a mana bar can run out: a warrior's mana reads a permanent 0. Empty
	-- stops everything, your own buffs too, on any client; short of empty it
	-- is the game's word per spell (Affordable), where the game gives one.
	local myMax = plain(UnitPowerMax("player", MANA))
	if myMax and myMax > 0 then
		local myMana = plain(UnitPower("player", MANA))
		if myMana ~= nil and myMana <= 0 then return {}, true end
	end

	-- Nothing to give anybody else -- a hunter, whose own aspects are all
	-- there is, every spell of yours switched off, or none you can pay for
	-- right now -- leaves you alone to offer (an armor costs less than an
	-- Intellect), and no walk: every person it reached would be turned down.
	-- Except for somebody asking by name for a spell Automatic leaves alone
	-- (askOnly), whom only the walk reads.
	if #candidates == 0 and not (askOnly and #askOnly > 0 and ns.RequestStanding(now)) then
		local own = SelfEntry(db, candidates, now, neverVerdict)
		if own then return { own }, {} end
		return {}, true
	end

	-- What PickBuffFor is told about the person in hand, one table reused for
	-- everybody the walk reaches.
	local opts = { unpaid = UNPAID }

	-- `unasked` walks somebody as if they had made no request (see below).
	local function visit(unit, pointed, unasked)
		local ok, person = IsBuffableUnit(unit, f)
		if not ok then
			-- Somebody turned down here must not walk back in through the
			-- fallbacks, which cannot check any of this, nor be held on the
			-- panel by the cursor. The name costs a call, so only when a debt
			-- outstanding or a passer-by remembered could resurface, or the
			-- caller is watching (see above).
			if person and (watch or next(owed) or next(passing)) then
				local bad = ns.UnitFullName(unit)
				if bad then rejected[bad] = true end
			end
			return
		end

		local full = ns.UnitFullName(unit)
		if not full then return end
		-- One verdict per person per scan, whichever way it went: somebody in
		-- front of you is commonly both your target and a nameplate.
		if seen[full] or rejected[full] then return end

		-- The whole-person block: a right-press skip, or a press that reached
		-- nobody, so we do not march down the list failing at each buff.
		if ns.IsBlocked(full, nil, now) then return end

		local inGroup = plain(UnitInParty and UnitInParty(unit)) or plain(UnitInRaid and UnitInRaid(unit))
		local isOwed = db.sources.owed and owed[full] and LiveExpiry(owed[full]) > now

		-- The never-offer list, for everybody but a person owed a favour: that
		-- exception is a decision (STATUS.md), and the options page says so. Safe to
		-- write into `rejected`: the fallback asks the same two questions isOwed did.
		if not isOwed and ns.IsNeverOffered(full) then
			rejected[full] = true
			return
		end
		-- Your /ignore list, for everybody outside your group, a favour
		-- included (ns.Ignored).
		if ignoring and not inGroup and ns.Ignored(unit) then
			rejected[full] = true
			return
		end

		-- What they asked for in chat, of what this character casts; nil for
		-- nobody and for anybody owed, whose favour is the better reason.
		-- Below the never-offer list on purpose: asking is not the exception
		-- buffing you is.
		local asked = not isOwed and not unasked and ns.AskedFor(unit, full, now, candidates, askOnly) or nil

		-- Decide whether we would offer this person at all before reading any
		-- auras, which is the expensive part. A request is a source of its own:
		-- the group and passer-by switches, the nearness and city checks do
		-- not apply to it. Casting range still does, further down.
		local reason = isOwed and "owed" or (asked and "asked") or (inGroup and "group" or "nearby")
		-- The group switch off turns a member away for good, so it is a verdict:
		-- a stranger remembered as a passer-by who has joined the party since
		-- would otherwise be offered from that memory (OfferPassersBy) while it
		-- lasts. The passers-by switch below needs none, the memories being
		-- dropped whole for it (`drop`).
		if reason == "group" and not db.sources.group then
			rejected[full] = true
			return
		end
		if reason == "nearby" and not db.sources.strangers then return end
		if reason == "nearby" and groupOnly then return end

		-- Nobody asked for these, so they wait while you keep your mana. A
		-- favour owed or a request never reaches here as group or nearby.
		-- Written down as a verdict: your own mana, not a token lost.
		if savingMana and (reason == "group" or reason == "nearby") then
			rejected[full] = true
			return
		end
		-- In a raid, only the groups you buff. Whoever you picked out on
		-- purpose is exempt, as from the city rule below; a group that cannot
		-- be read is offered. A verdict, like the group switch above: somebody
		-- remembered as a passer-by who has joined a group switched off would
		-- otherwise be offered from that memory (OfferPassersBy).
		if skipGroups and reason == "group" and not pointed then
			local group = RaidGroupOf(unit)
			if group and skipGroups[group] then
				rejected[full] = true
				return
			end
		end
		-- A group member the game says is out of sight -- in town while the raid is
		-- inside, or far off in it -- is out of range for certain, which this client's
		-- range check often will not say. A range rule, so a favour and a request
		-- meet it too: a raider who buffed you and hearthed sat on the prompt, every
		-- press failing, for the whole favour. Their debt and request stay; `rejected`
		-- keeps the fallbacks off them until a scan sees them again. Only the group's
		-- tokens outlast sight.
		if inGroup and f.requireInRange
			and plain(UnitIsVisible and UnitIsVisible(unit)) == false then
			rejected[full] = true
			return
		end

		-- Passers-by only in a city or an inn, when that is asked for. A stranger
		-- you targeted or focused you picked on purpose, and is exempt.
		if reason == "nearby" and not pointed and notResting then
			rejected[full] = true
			return
		end

		-- Flagged for PvP, for every reason alike. Below the tests above, so /manners
		-- debug names only people the rule itself holds back; above those below, since
		-- two flags cost less than a distance or an aura read. A verdict, so the
		-- cursor's hold lets them go, where "far" would not. What was read goes on
		-- their debt for the owed fallback, which has no token to ask; the debt stays.
		-- Somebody owed meets only the whole-person and out-of-sight tests above,
		-- which the fallback honours too, so every token finding them offerable
		-- refreshes it.
		local flag
		if pvpRead then
			flag = PvPFlag(unit)
			if owed[full] then owed[full].pvp = flag end
			if pvpHeld and flag == true then
				rejected[full] = true
				pvpHeld[full] = true
				return
			end
		end

		-- A passer-by has to be near, not merely castable on. The other reasons
		-- carry their own evidence of nearness, and so does a pointed unit. Above
		-- the aura read on purpose: in a crowd, one distance check is much
		-- cheaper than a walk down somebody's auras.
		if reason == "nearby" and not pointed and ns.NearEnough(unit) == false then
			-- Marked "far" rather than true: a passer-by remembered (see
			-- OfferPassersBy) is not let go for it, only no longer renewed.
			-- Somebody pacing along the edge of the setting read near and far
			-- on alternate scans and blinked on and off the prompt, and past
			-- the edge the spell still reaches them three times as far out.
			rejected[full] = "far"
			return
		end

		local hasMana = UnitHasMana(unit)
		local guid = plain(UnitGUID(unit))
		local whenBuffed = f.whenBuffed or "skip"
		local checked = whenBuffed ~= "always"

		-- Every field written for every person; PickBuffFor keeps nothing.
		opts.unit, opts.guid, opts.checked = unit, guid, checked
		-- Somebody who asked gets only what they asked for, relevant to them or
		-- not (a warrior may want Intellect), but never when already covered.
		opts.hasMana = hasMana
		opts.inGroup = inGroup
		-- Who a shout reaches, which in a raid is not the group: see
		-- SameParty. inGroup stays the reason on the card.
		opts.inParty = SameParty(unit, inRaid)
		opts.relevantOnly = f.relevantOnly and not asked
		opts.asked = asked ~= nil
		opts.whenBuffed = whenBuffed
		opts.refreshUnder = f.refreshUnder
		opts.name = full
		-- Owing somebody means offering them even when covered: a decision about
		-- who gets an offer, saying nothing about what their auras read. Not a
		-- group member who wears your own cast with more than the top-up time
		-- left (PickBuffFor reads it, paidUp): a warrior's shout lapses between
		-- pulls and lands again as a new favour, and every one asked for a
		-- full-mana refresh of a Fortitude with forty minutes to run.
		opts.offerAnyway = isOwed
		opts.paidUp = isOwed and inGroup and checked or nil
		opts.blocked = QueueBlocked
		opts.now = now
		-- Your own class, offered unasked: see SelfServed. Never somebody who
		-- buffed you, asked, or you picked out on purpose.
		local same = f.skipSameClass == true and not pointed and (reason == "group" or reason == "nearby")
			and plain(select(2, UnitClass(unit))) == caps.class
		opts.sameClass = same
		opts.level = same and plain(UnitLevel(unit)) or nil
		opts.skip = SelfServed
		local buff, has, remaining, seconds, lead, leadKind = ns.PickBuffFor(asked or candidates, opts, ReadAura)

		if not buff then
			-- Covered for what they asked -- somebody else answered first -- is
			-- no reason to offer them nothing. They are walked again as if they
			-- had not asked, through every rule the request let them past: they
			-- lost the rest of what they were offered, as a group member or a
			-- passer-by, for the request's whole minute. Turned down there too,
			-- they are turned down for good, or the passer-by memory would
			-- offer the asker the buff they are wearing.
			if asked then
				visit(unit, pointed, true)
				if not seen[full] then rejected[full] = true end
				return
			end
			rejected[full] = true
			return
		end
		if not checked then has = nil end

		-- A reading the client refused, for somebody offered on it alone: never
		-- with "Only offer people whose buffs can be read" on, and not in the
		-- first seconds after a fight (Core.lua, UNVERIFIED_SECONDS) when the
		-- client may answer a moment on ("withheld"): a fight refuses every
		-- reading and the client may go on refusing for a moment after it, and
		-- the first scans after a pull offered people already wearing the buff.
		-- Nor a top-up off what was last read worn ("kept"), which only holds an
		-- offer back: their timer may have been renewed, or the buff lost, since.
		-- Not a verdict on them, "unread": the next scan asks again, and what is
		-- remembered of a passer-by is not offered on top (OfferPassersBy).
		-- Somebody owed or who asked is offered whatever the reading, and says
		-- so on the prompt.
		local src = checked and ns.ReadingSource(guid, buff.key) or nil
		if checked and reason ~= "owed" and reason ~= "asked"
			and ((has and src == "kept")
				or (has == nil and (f.verifiedOnly or (src == "withheld" and ns.JustAfterFight(now))))) then
			rejected[full] = "unread"
			return
		end

		local ranged = InRange(unit, buff)
		-- A shout has no range for InRange to measure, so whatever can say how
		-- far off they are is asked instead, and the answer rides on the entry
		-- to the press: a shout nothing measured repays nobody.
		if ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end
		if f.requireInRange and ranged == false then rejected[full] = true return end

		-- A deliberate target outranks a debt, but only once their auras were read
		-- and the buff found missing: a guess must not put somebody covered above a
		-- person who buffed you. The words come from the reason, so an owed or asking
		-- target keeps them. Switchable: some players target to inspect.
		local priority = PRIORITY[reason]
		if unit == "target" and db.priority.target
			and not isOwed and checked and has == false then
			if not asked then reason = "target" end
			priority = PRIORITY.target
		end

		-- A group member put first by a ready check or by coming back from the
		-- dead -- but, as for a target, only once their auras were read and the
		-- buff found missing or running out: a guess must not jump the queue.
		-- The reason stays, so somebody owed still says so.
		local swept
		if inGroup and checked and (has == false or remaining ~= nil) then
			swept = SweepReason(full, now, readyCheck, db)
			if swept and priority > PRIORITY.sweep then priority = PRIORITY.sweep end
		end

		-- Asked last, since the answer only orders the queue, and not for a
		-- favour owed or your target, who outrank everybody it could pass.
		local close
		if friendsFirst and (reason == "group" or reason == "nearby") then
			close = Closeness(unit, full, now)
		end

		seen[full] = true
		queue[#queue + 1] = {
			name = full,
			short = ShortName(full),
			-- The spelling the macro's /target line carries, which is not always
			-- the name they are filed under: off Camelot a cross-realm player is
			-- keyed "Mort-Ravencrest" and targeted as "Mort".
			targetName = ns.TargetName(full),
			unit = unit,
			class = plain(select(2, UnitClass(unit))),
			buff = buff,
			reason = reason,
			-- Whether they are in the group, which `reason` stops saying once
			-- they are owed or targeted; the ledger files by it.
			inGroup = not not inGroup,
			priority = priority,
			ranged = ranged,
			known = has,
			-- How long what they carry has left, set only for a top-up.
			remaining = remaining,
			-- false when we chose not to look, as opposed to looked and were
			-- refused. Only the second is the client's doing.
			checked = checked,
			-- "friend" or "guild" where Who comes first asked; the sort and the
			-- tooltip read it.
			close = close,
			-- "readycheck" or "revived" when that put them first; the reason
			-- line and the tooltip say so.
			sweep = swept,
			-- Their PvP flag as read this scan (nil with the setting off),
			-- which the memory of them keeps (RememberPasserBy).
			pvp = flag,
		}
		-- A refusal the client may lift a moment on (Core.lua, ReadingSource):
		-- the end of a fight lets go of a passer-by remembered on one
		-- (ForgetUnreadPassersBy). Set after the table is built, only when
		-- true: one more field in the constructor doubles the hash part of
		-- every entry of every scan.
		if has == nil and src == "withheld" then queue[#queue].withheld = true end
		-- A top-up: how long the buff lasts, the lead that made it due and its
		-- kind, for the tooltip. Written after the table is built, as above.
		if remaining then
			local made = queue[#queue]
			made.duration, made.lead, made.leadKind = seconds, lead, leadKind
		end
		-- Remembered for when the token goes, which for the cursor is the
		-- moment the player moves it to the prompt. Not somebody pointed at:
		-- a target or focus stands until the player changes it. A favour is
		-- remembered on the debt itself, which the owed fallback reads.
		if not pointed then
			if reason == "nearby" or reason == "asked" then
				RememberPasserBy(queue[#queue], now, f.proximity, hasMana, guid)
			elseif isOwed then
				owed[full].near = now
			end
		end
	end

	-- The never-offer list's answers stand for the length of the walk only:
	-- the list may be edited between two scans. So the walk is protected, the
	-- answers withdrawn whichever way it ends, and a failure goes on as before.
	neverSeen.scan = neverVerdict
	local walked, walkError = pcall(IterateUnits, visit)
	neverSeen.scan = nil
	if not walked then error(walkError, 0) end

	-- Somebody who buffed you and holds no token we can see is the ordinary
	-- case: a passing stranger rarely shows a nameplate. The macro's /target
	-- line still reaches them ([@Name] would not: it resolves only for group
	-- members), and buffing you proved they were in range, so they are offered
	-- for a short grace window and then let go.
	if db.sources.owed then
		local grace = db.timing.graceSeconds or 45
		-- One table for every favour below; only what differs between two
		-- people is written inside the loop.
		local tokenless = {
			-- No token, so no telling whether they are in the group; a
			-- party-only buff would be a button that fails.
			inGroup = false,
			inParty = false,
			relevantOnly = f.relevantOnly,
			-- No aura reading either, so never rotate past what they may
			-- already be carrying.
			whenBuffed = "skip",
			rotate = false,
		}
		for full, entry in pairs(owed) do
			-- A token nobody pointed at found them a moment ago (`near`, written
			-- by the walk): as good a sign they are about as a fresh favour, so
			-- the cursor leaving them for the prompt does not take an older one
			-- off it (see "passers-by, remembered"). A token turning them down
			-- since takes it back.
			if rejected[full] == true then entry.near = nil end
			local near = entry.near and now - entry.near < LINGER_SECONDS
				and not (ns.zonedAt and entry.near < ns.zonedAt)
			-- And only for a favour noticed since the last loading screen (see
			-- PLAYER_ENTERING_WORLD); the debt stays, for a token to find them.
			-- Both are "probably gone", so neither applies with that option off.
			local fresh = not db.filters.reachableOnly or near
				or ((not ns.zonedAt or entry.at >= ns.zonedAt) and (now - entry.at) <= grace)
			-- Nor anybody on your /ignore list, which the walk asks of a token:
			-- a debt filed before you ignored them is no reason to /target
			-- them by name. Never a group member here, who has a token.
			if LiveExpiry(entry) > now and fresh and not seen[full] and not rejected[full]
				and not (ignoring and ns.Ignored(full, entry.guid))
				and SafeForMacro(full) and not ns.IsBlocked(full, nil, now) then
				-- Flagged when last read, and the rule stands: held back, a
				-- verdict like the walk's, and still owed, to be returned if a
				-- token reads the flag gone (or you are flagged yourself)
				-- before the favour runs out.
				if pvpHeld and entry.pvp == true then
					rejected[full] = true
					pvpHeld[full] = true
				else
					-- Resolved per person, through the same filters as the
					-- main path. Class is all this path has; a tokenless entry
					-- can never be level- or death-checked.
					local hasMana
					if entry.class then hasMana = MANA_CLASSES[entry.class] == true end

					tokenless.hasMana = hasMana
					tokenless.name = full
					local buff = ns.PickBuffFor(candidates, tokenless, NoReading)

					-- One buff per favour: nothing here can verify the first landed. Not a shout:
					-- it is judged repaid on whether the press measured them in reach, and with no
					-- token they may be a zone away.
					if buff and not buff.selfCast and not ns.IsBlocked(full, buff.key, now) then
						queue[#queue + 1] = {
							name = full,
							short = ShortName(full),
							-- From the key, since this path has no unit to ask.
							targetName = ns.TargetName(full),
							class = entry.class,
							buff = buff,
							reason = "owed",
							priority = PRIORITY.owed,
							-- ranged and known are left unwritten: a constructor
							-- sizes the table for every field it names. No token
							-- means nothing read, the client's doing, so `checked`
							-- follows the setting.
							checked = (f.whenBuffed or "skip") ~= "always",
						}
					end
				end
			end
		end
	end

	-- Passers-by and askers no token reached this scan, for a few seconds
	-- after one last did. Everything that turns passers-by down as a kind
	-- turns the remembered ones down for good: the switch off, a shout, saving
	-- mana, a city-only rule out in the world.
	OfferPassersBy(queue, seen, rejected, now, db, candidates, askOnly, neverVerdict,
		not db.sources.strangers or groupOnly or savingMana or notResting, ignoring)

	-- And you, once everybody else is in: before the fold below, so a group
	-- cast counts you among your party.
	local mine = SelfEntry(db, candidates, now, neverVerdict)
	if mine then
		queue[#queue + 1] = mine
	elseif watch then
		-- Not offered to you, for whatever reason: a verdict on you, never a
		-- token lost, so a cursor resting on the prompt does not hold "You"
		-- there after you buffed yourself by hand (see hovering,
		-- Prompt/Prompt.lua).
		local me = ns.UnitFullName("player")
		if me then rejected[me] = true end
	end

	-- A shout lands on the whole party, flagged members and all, and on Mists
	-- and retail so does a buff on any of you, yourself included: after you
	-- are in. Your group buff held back, your class's own come in its place,
	-- as they would once it was cast: they land on you alone.
	if pvpHeld then
		local held
		queue, held = HoldShoutsForPvP(queue, rejected, inRaid)
		if held and mine and LandsOnParty(mine) then
			mine = SelfEntry(db, candidates, now, neverVerdict, true)
			if mine then
				queue[#queue + 1] = mine
				rejected[mine.name] = nil
			end
		end
	end

	-- A party's single casts folded into one group cast where the player has
	-- the group version and its reagent (GroupBuffs.lua), before the sort, so
	-- the group cast takes its place by the best of the people it covers.
	-- Guarded: a fault there costs the group cast, never the single ones.
	if ns.GroupCasts then
		ns.Guard("group buffs", function()
			queue = ns.GroupCasts(queue, db, candidates, inRaid)
		end)
	end

	table.sort(queue, function(a, b)
		if a.priority ~= b.priority then return a.priority < b.priority end
		local ar = a.ranged == true and 0 or (a.ranged == nil and 1 or 2)
		local br = b.ranged == true and 0 or (b.ranged == nil and 1 or 2)
		if ar ~= br then return ar < br end
		-- A group cast ahead of single casts of its kind: one press covers a
		-- party, so it clears the queue fastest.
		if (a.groupCast ~= nil) ~= (b.groupCast ~= nil) then return a.groupCast ~= nil end
		-- Friends first inside a kind of offer, never across one, and below the
		-- range key: a friend out of reach must not lead with a cast that fails
		-- (STATUS.md). With Who comes first off this is always a tie.
		if (a.close ~= nil) ~= (b.close ~= nil) then return a.close ~= nil end
		return (a.name or "") < (b.name or "")
	end)

	return queue, rejected
end
