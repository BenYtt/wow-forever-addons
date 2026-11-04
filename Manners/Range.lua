-- Manners -- how near is near: the distance a passer-by has to be within to be
-- offered anything, and what measures it on this client. BuildQueue
-- (Queue.lua) asks it about every passer-by on every scan.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's, which loads first.
local plain, safecall = ns.plain, ns.safecall

---------------------------------------------------------------------------
-- how near is near
--
-- Spell range is not nearness: thirty yards of a city square is twenty-odd
-- nameplates. So passers-by, and only passers-by, get a tighter distance of
-- their own; the owed, the group and your target carry their own evidence.
--
-- Nothing in the client answers "how many yards away" directly, so each signal
-- below is an approximation, ordered best first, and the rung in use is named
-- in /manners debug: a filter that stopped measuring looks like a quiet evening.
---------------------------------------------------------------------------

-- The three named distances, loosest first, named for what a player perceives
-- rather than in yards.
local PROXIMITY = {
	{ key = "cast", yards = nil, name = L["Anywhere I can cast"], about = L["about 30 yards"] },
	{ key = "near", yards = 10, name = L["Nearby"], about = L["about 10 yards"] },
	{ key = "beside", yards = 5, name = L["Right beside me"], about = L["about 5 yards"] },
}
ns.PROXIMITY = PROXIMITY

-- What is doing the measuring, how well it is going, and why, for /manners
-- debug, /manners look and the options page.
local prox = {
	source = nil, -- the first rung asked, nil when nothing is measuring
	yards = nil, -- what that rung really tests, which is not always what was asked
	-- "within" for a rung that answers both ways, "beyond" for one looser than
	-- the step, which can rule people out and cannot rule anybody in
	mode = nil,
	backup = nil, -- the rung asked when the first cannot tell, if there is one
	asked = 0, -- people put to the ladder during the last scan
	answered = 0, -- how many of those some rung had an answer for
	note = nil, -- why a rung was dropped, while it is
}
ns.proximity = prox

-- Whether the game calls the player resting (a city or an inn): true, false, or
-- nil for could not tell. Not through safecall: the old API says "not resting"
-- with a plain nil, so only a missing function, a throw or a secret is
-- could-not-tell, which BuildQueue reads as resting so the queue never empties
-- on a question the client will not answer.
local function Resting()
	if type(_G.IsResting) ~= "function" then return nil end
	local ok, value = pcall(_G.IsResting)
	if not ok then return nil end
	if issecretvalue and issecretvalue(value) then return nil end
	return value == true or value == 1
end
ns.Resting = Resting

-- The ladder's private state and helpers, in a block of their own for the main
-- chunk's 200 locals (Lua 5.1).
do
	local PROXIMITY_BY_KEY = {}
	for _, tier in ipairs(PROXIMITY) do PROXIMITY_BY_KEY[tier.key] = tier end

	-- The duel prompt, CheckInteractDistance index 3: eight yards, six for a tauren
	-- and seven for the undead (LibRangeCheck's figures, the only measurement of
	-- it). Older clients put it nearer ten, which is why the page says "about".
	-- Indexes 1 and 4 (about 28 yards) are no tighter than a spell. Index 2 (the
	-- trade prompt, about nine) is not used because LibRangeCheck dropped it and
	-- kept 3 on a modern client, the only evidence of which prompts still answer.
	local INTERACT_DUEL = 3
	local INTERACT_DUEL_RACE = { Tauren = 6, Scourge = 7 }

	-- Keyed on UnitRace's second return, the untranslated file name the library
	-- keys on too ("Scourge", not "Undead").
	local function InteractDuelYards()
		local _, race = safecall(_G.UnitRace, "player")
		return INTERACT_DUEL_RACE[race] or 8
	end

	-- A rung silent for this many people in a row answers for nobody, so it is
	-- dropped for a while to save the calls (anybody it cannot tell about goes to
	-- the rung below anyway). Generous, so a quiet corner drops nothing.
	local PROX_BLIND_LIMIT = 40

	-- How long a dropped rung stays dropped. Not reset by the capability probe,
	-- which runs on every SPELLS_CHANGED and cannot make a withheld GUID readable.
	local PROX_DEAD_RETRY = 60

	-- How often the ladder is resolved again: LibStub misses cost a pcall each,
	-- and an edge can move when the library finishes its lists or a spell is learned.
	local PROX_RETRY = 5

	-- Rungs dropped for answering nobody, by name, and when.
	local proxDead = {}
	-- People in a row each rung has had nothing to say about, by name; kept apart
	-- from the ladder so a rebuild cannot wipe the evidence.
	local proxBlind = {}

	-- The ladder resolved for one distance, and when.
	local proxState = { want = nil, ladder = {}, at = -1 }

	-- Above this, a step is loose enough that a much tighter bucket standing in
	-- for it would visibly drop people; at or below it, a melee bucket is the answer.
	local PROX_LOOSE_FROM = 6

	-- Asks the client call a LibRangeCheck edge stands for, directly. The library's
	-- checkers flatten a refusal (`and true or false`, `or nil`) and GetRange reads
	-- nil as "further out", so a client withholding answers put everybody at 28-40
	-- yards. Asked here, a refusal stays a refusal, in one call rather than five.
	-- nil for an edge backed by a spell, where GetRange is all there is.
	-- Both are client calls handed a number and a unit token, which answer or
	-- withhold a secret and never throw, so they are called directly.
	local function DirectCheck(lib, edge)
		local list = lib.friendRC
		if type(list) ~= "table" then return nil end
		for _, rc in ipairs(list) do
			if type(rc) == "table" and rc.range == edge then
				local info = tostring(rc.info or "")
				local index = tonumber(info:match("^interact:(%d+)$"))
				if index then
					return function(unit)
						-- Read at call time: the client can lack it, and the rung
						-- outlives the moment it was built.
						local check = _G.CheckInteractDistance
						if type(check) ~= "function" then return nil end
						local r = plain(check(unit, index))
						if r == nil then return nil end
						return r == true or r == 1
					end
				end
				local item = tonumber(info:match("^item:(%d+)$"))
				local inRange = (C_Item and C_Item.IsItemInRange) or _G.IsItemInRange
				if item and type(inRange) == "function" then
					return function(unit)
						local r = plain(inRange(item, unit))
						if r == nil then return nil end
						return r == true or r == 1
					end
				end
				return nil
			end
		end
		return nil
	end
	-- Also asked by ns.ShoutSure (Core.lua), which loads before this file.
	ns.DirectRangeCheck = DirectCheck

	-- The ladder, best first. Each build returns a function answering "is this unit
	-- within `want` yards" (true, false, or nil for cannot tell) and whether the
	-- client call answered at all, plus the distance it really tests and its mode;
	-- nil means the rung is not available here.
	local PROX_SOURCES = {
		{
			name = "LibRangeCheck-3.0",
			build = function(want)
				-- Optional, fetched with the silent flag. Through GetLibrary: LibStub
				-- is a table made callable by a metatable, which safecall refuses.
				local stub = _G.LibStub
				local lib = type(stub) == "table" and type(stub.GetLibrary) == "function"
					and safecall(stub.GetLibrary, stub, "LibRangeCheck-3.0", true) or nil
				if type(lib) ~= "table" then return nil end
				if type(lib.GetRange) ~= "function" then return nil end
				if type(lib.GetFriendMaxChecker) ~= "function" then return nil end

				-- The library builds its checker lists on its own events; asking
				-- again costs nothing if it already has.
				safecall(lib.init, lib)

				-- The library answers in buckets whose edges are this class's
				-- range checkers, so "within ten" means "inside the largest edge at
				-- or below ten". An edge far tighter than a loose step would drop
				-- most of the square, so that rung is refused; below two yards
				-- (melee) nothing is a distance. The tightest step asks for melee,
				-- so a two-yard bucket is that step working.
				local checker, edge = safecall(lib.GetFriendMaxChecker, lib, want)
				if type(checker) ~= "function" or type(edge) ~= "number" then return nil end
				if edge < 2 then return nil end
				if want > PROX_LOOSE_FROM and edge * 2 < want then return nil end

				local direct = DirectCheck(lib, edge)
				if direct then
					return function(unit)
						local near = direct(unit)
						return near, near ~= nil
					end, edge, "within"
				end

				return function(unit)
					-- Only "at most maxRange away" can say yes: a bucket straddling
					-- the line (8-28 against a wanted 10) holds both a person beside
					-- you and one across the square. Tighter than the label, never looser.
					local minRange, maxRange = safecall(lib.GetRange, lib, unit)
					if type(minRange) ~= "number" then return nil, false end
					return type(maxRange) == "number" and maxRange <= want, true
				end, edge, "within"
			end,
		},
		{
			name = "CheckInteractDistance",
			build = function(want)
				-- Restricted for non-party units on some modern clients, where it
				-- answers nothing. No probe for that, so the rung is built whenever
				-- the function exists and dropped by its own silence.
				if type(want) ~= "number" then return nil end
				if type(_G.CheckInteractDistance) ~= "function" then return nil end
				-- Called directly, as DirectCheck does, and read at call time for
				-- the same reason: the client can take it away after this is built.
				local function read(unit)
					local check = _G.CheckInteractDistance
					if type(check) ~= "function" then return nil end
					local r = plain(check(unit, INTERACT_DUEL))
					if r == nil then return nil end
					return r == true or r == 1
				end

				local yards = InteractDuelYards()
				if yards <= want then
					return function(unit)
						local near = read(unit)
						return near, near ~= nil
					end, yards, "within"
				end

				-- A step tighter than the prompt: it cannot say anybody is inside
				-- five yards, but anybody past the prompt is past five too, so it
				-- answers its "no" and passes on its "yes". Mode "beyond" makes the
				-- summary say so.
				return function(unit)
					local near = read(unit)
					if near == nil then return nil, false end
					if near then return nil, true end
					return false, true
				end, yards, "beyond"
			end,
		},
	}

	local function DroppedNote()
		local names = {}
		for _, source in ipairs(PROX_SOURCES) do
			if proxDead[source.name] then names[#names + 1] = source.name end
		end
		if #names == 0 then return nil end
		if #names == 1 then return L["%s answered for nobody, so it was dropped"]:format(names[1]) end
		-- Two is every rung there is today, so the pair gets a whole sentence for
		-- translators rather than a bare " and ".
		if #names == 2 then return L["%s and %s answered for nobody, so they were dropped"]:format(names[1], names[2]) end
		return L["%s answered for nobody, so they were dropped"]:format(table.concat(names, ", "))
	end

	-- Every rung that can measure `want`, best first, resolved at most every
	-- PROX_RETRY seconds. It also sets what the summaries describe, so asking for
	-- the ladder brings a summary up to date with the selected step.
	local function ProxLadder(want)
		local now = GetTime()
		if proxState.want == want and now < proxState.at + PROX_RETRY then
			return proxState.ladder
		end

		-- A count taken for one step is not a count for another.
		if proxState.want ~= want then prox.asked, prox.answered = 0, 0 end
		proxState.want, proxState.at = want, now

		local ladder = {}
		for _, source in ipairs(PROX_SOURCES) do
			local droppedAt = proxDead[source.name]
			if droppedAt and now - droppedAt >= PROX_DEAD_RETRY then
				proxDead[source.name], proxBlind[source.name] = nil, 0
				droppedAt = nil
			end
			if not droppedAt then
				local ask, yards, mode = safecall(source.build, want)
				if type(ask) == "function" then
					ladder[#ladder + 1] = { name = source.name, ask = ask, yards = yards, mode = mode }
				end
			end
		end
		proxState.ladder = ladder

		local first, second = ladder[1], ladder[2]
		prox.source, prox.yards = first and first.name, first and first.yards
		prox.mode, prox.backup = first and first.mode, second and second.name
		prox.note = DroppedNote()
		return ladder
	end

	-- Forget what was resolved, from the capability probe (SPELLS_CHANGED rebuilds
	-- LibRangeCheck's lists). Dropped rungs stay dropped: see PROX_DEAD_RETRY.
	function ns.ForgetProximity()
		proxState.want, proxState.ladder, proxState.at = nil, {}, -1
		prox.source, prox.yards, prox.mode, prox.backup = nil, nil, nil, nil
		prox.asked, prox.answered = 0, 0
	end

	-- true, false, or nil for "cannot tell", which is offered rather than dropping
	-- somebody probably standing next to you (as InRange does). Walked per person:
	-- a rung that cannot tell hands them to the next rung down. `quiet` asks
	-- without counting, for /manners look, which is not part of a scan.
	function ns.NearEnough(unit, quiet)
		local db = addon.db and addon.db.profile
		local tier = db and db.filters and PROXIMITY_BY_KEY[db.filters.proximity]
		-- No tier, or the loosest one: nothing to measure.
		if not tier or not tier.yards then return nil end

		-- Nobody is measured in a fight: the interact prompts refuse for a friendly
		-- unit and LibRangeCheck's in-combat buckets are wider than any setting, and
		-- the prompt cannot rearm in a fight anyway.
		if InCombatLockdown() then return nil end

		local ladder = ProxLadder(tier.yards)
		if #ladder == 0 then return nil end

		if not quiet then prox.asked = prox.asked + 1 end
		local verdict, heard = nil, false
		-- Each rung is asked directly: the one third-party call among them,
		-- LibRangeCheck's GetRange, is protected inside its own rung, and the
		-- client calls in the rest cannot throw (see DirectCheck).
		for _, rung in ipairs(ladder) do
			local near, answered = rung.ask(unit)
			if answered == true then
				heard = true
				if not quiet then proxBlind[rung.name] = 0 end
			elseif not quiet then
				local silent = (proxBlind[rung.name] or 0) + 1
				proxBlind[rung.name] = silent
				if silent > PROX_BLIND_LIMIT then
					-- Here and saying nothing, so it sits out for a while.
					proxDead[rung.name], proxBlind[rung.name] = GetTime(), 0
					prox.note = DroppedNote()
					proxState.at = -1
				end
			end
			if near ~= nil then
				verdict = near
				break
			end
		end
		if heard and not quiet then prox.answered = prox.answered + 1 end
		return verdict
	end

	-- One line saying what is measuring nearness and how it is getting on, shared
	-- by /manners debug and the options page. About the step selected now, since
	-- AceConfig redraws straight after the dropdown's setter, before any scan.
	function ns.ProximitySummary()
		local db = addon.db and addon.db.profile
		local tier = db and db.filters and PROXIMITY_BY_KEY[db.filters.proximity]
		-- For translators: a state, "no distance has been chosen", not the verb. It
		-- stands alone after "proximity:" in /manners debug and on the options page.
		if not tier then return L["unset"] end
		if not tier.yards then return L["%s -- nothing is measured"]:format(tier.name) end

		local out = ("%s (%s)"):format(tier.name, tier.about)

		-- The setting is about passers-by alone, so say when none are measured:
		-- switched off, a class whose buffs reach only its group, or resting-only
		-- out in the world (a definite "not resting", as BuildQueue asks).
		if db.sources and db.sources.strangers == false then
			return L["%s -- passers-by are switched off, so nobody is measured"]:format(out)
		end
		if ns.OnlyReachesGroup() then
			return L["%s -- your buffs reach only your group, so nobody is measured"]:format(out)
		end
		if db.filters.restingOnly == true and Resting() == false then
			return L["%s -- you are out in the world and passers-by are only offered in cities and inns, so nobody is measured"]
				:format(out)
		end

		-- Nothing is measured during a fight, which overrides everything below.
		if InCombatLockdown() then
			return L["%s |cffffd100-- stood down while in combat, so distance is not being measured|r"]:format(out)
		end

		ProxLadder(tier.yards)
		if prox.source then
			-- Floored: "really 8.0yd" reads as a calculation, not a bucket. One
			-- whole sentence per shape, so translators never get a clause to bolt on.
			local yards = math.floor(prox.yards or 0)
			if prox.mode == "beyond" then
				if prox.backup then
					out = L["%s via %s, which only rules out people past %dyd, then %s"]:format(
						out, prox.source, yards, prox.backup)
				else
					out = L["%s via %s, which only rules out people past %dyd"]:format(
						out, prox.source, yards)
				end
			elseif prox.backup then
				out = L["%s via %s, really %dyd, then %s"]:format(out, prox.source, yards, prox.backup)
			else
				out = L["%s via %s, really %dyd"]:format(out, prox.source, yards)
			end
			-- The number that says whether it is working at all.
			if prox.asked > 0 then
				out = L["%s -- answered for %d of %d last scan"]:format(out, prox.answered, prox.asked)
			else
				out = L["%s -- nobody measured yet"]:format(out)
			end
		else
			out = L["%s -- |cffff8080no signal, so everybody in casting range is offered|r"]:format(out)
		end
		if prox.note then out = out .. " |cff808080(" .. prox.note .. ")|r" end
		-- And whether nothing can measure, for /manners selftest's WARN, which
		-- cannot read it off a line that is translated.
		return out, prox.source == nil
	end
end
