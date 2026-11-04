-- Manners -- group buffs: one cast for a whole party in place of the single
-- casts the queue lined up for its members.
--
-- From level 48 to 60 a buffer learns a version of the buff that covers the
-- target's whole party (Prayer of Fortitude, Arcane Brilliance, Gift of the
-- Wild) -- on Forever the caster's whole party and raid (ns.GROUP_IS_RAID) --
-- or for a paladin everybody of the target's class in the raid or party (the
-- Greater Blessings), each for a reagent. When the player knows it, carries
-- the reagent (or, on Forever, has the perk that waives it: ReagentWaived),
-- and enough of one party (or raid, or class) are waiting for the single
-- buff, BuildQueue gets one entry for the group cast instead of theirs.
--
-- The entry is aimed at one of them, the anchor, so the macro, the settle and
-- the ledger see a person as they always have. What it adds is `groupCast`:
-- the spell, the reagent, and everybody else the cast covers, which PostClick,
-- the settle and the ledger read. Everybody it covered drops off the prompt
-- the way anybody buffed does: their auras read the buff once it lands.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

-- Core.lua's, which loads first.
local plain, safecall = ns.plain, ns.safecall

---------------------------------------------------------------------------
-- the reagent
---------------------------------------------------------------------------

-- How many of an item the player carries, or nil where the client will not
-- say. Both generations of the call, as SpellNameFor asks for a spell's name.
local function ReagentCount(item)
	local count = safecall(C_Item and C_Item.GetItemCount, item)
	if type(count) ~= "number" then count = safecall(_G.GetItemCount, item) end
	if type(count) ~= "number" or count < 0 then return nil end
	return count
end
ns.ReagentCount = ReagentCount

-- The reagent's name for the tooltip and the note, or nil while the client
-- has not loaded the item yet (it answers nil until then, not an error).
local function ReagentName(item)
	local name = safecall(C_Item and C_Item.GetItemNameByID, item)
	if type(name) ~= "string" then name = safecall(_G.GetItemInfo, item) end
	if type(name) ~= "string" or name == "" then return nil end
	return name
end
ns.ReagentName = ReagentName

-- The client's own word on whether the spell can be cast: it says no without
-- the reagent, which checks the pairing in Buffs.lua against the game. A no
-- for want of mana counts too: the group spell costs far more than the single
-- one, and a player who can afford only the single one is better offered it
-- than a group cast that fails on every press. A client that will not say is
-- taken at the table's word.
local function UsableAnswer(spellId)
	local check = C_Spell and C_Spell.IsSpellUsable
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	return safecall(check, spellId)
end

local function Usable(spellId)
	local usable = UsableAnswer(spellId)
	return usable ~= false
end

-- Whether the reagent is not needed at all. On Forever the Legacy perk
-- Reagent Economy (spell 1225503: "Your class abilities no longer require
-- reagents purchaseable from vendors") puts a hidden aura on the player, one
-- a class (1262650 priest, 1262638 mage, 1262636 druid, 1262647 paladin),
-- that takes the reagent off every group spell in Buffs.lua. Whoever has it
-- carries none and casts all the same, so the client calling the spell usable
-- with none in the bags is the sign. Only an outright yes counts (a client
-- that will not say is no reason to offer a cast with nothing in the bags),
-- and only on Forever: no other client has the perk. `have` is ReagentCount's.
local function ReagentWaived(info, have)
	if have ~= 0 or not (info and info.groupRank) then return false end
	if (ns.Flavour and ns.Flavour.flavour) ~= "camelot" then return false end
	return UsableAnswer(info.groupRank) == true
end
ns.ReagentWaived = ReagentWaived

-- Reagents seen in the bags this session, the count last seen of each, and
-- which notes have been said. Each note once a session: news the first time,
-- nagging after.
local stocked, told, lastSeen, warnedLow = {}, {}, {}, {}

-- Running low: said once the count drops to this many, while a vendor can
-- still be reached before the next pull.
local LOW_STOCK = 5

-- A heads-up when a cast takes the count down to a handful, and the gentle
-- note the moment the last reagent goes: without the second the prompt
-- quietly goes back to one person at a time and looks broken.
local function NoteStock(info, count, db)
	local item = info.groupReagent
	local before = lastSeen[item]
	lastSeen[item] = count
	if count and count > 0 then
		stocked[item] = true
		-- Only on a drop, so logging in with a few in the bags says nothing:
		-- it is the cast that just spent one that makes it news.
		if count <= LOW_STOCK and before and count < before and not warnedLow[item] then
			local what = ReagentName(item)
			if db.verbose and what then
				warnedLow[item] = true
				addon:Print(L["%d %s left -- the prompt goes back to one person at a time when they run out."]
					:format(count, what))
			end
		end
		return
	end
	if count ~= 0 or not stocked[item] or told[item] then return end
	if not db.verbose then return end
	told[item] = true
	local single = ns.BuffName(info.buff)
	local what = ReagentName(item)
	if what then
		addon:Print(L["you are out of %s, so the prompt offers %s one person at a time again until you buy more."]
			:format(what, single))
	else
		addon:Print(L["you are out of the reagent %s needs, so the prompt offers %s one person at a time again until you buy more."]
			:format(info.groupName or single, single))
	end
end

---------------------------------------------------------------------------
-- who a cast reaches
---------------------------------------------------------------------------

local TOKENS = { raid = {}, party = {} }
for i = 1, 40 do
	TOKENS.raid[i] = "raid" .. i
	TOKENS.party[i] = "party" .. i
end

-- One reading of the group per GroupCasts call: every bucket at the threshold
-- asks FlaggedAmong about the whole raid, and five group casts in a raid were
-- two hundred roster reads a scan. Nothing changes inside one call, so the
-- first bucket's answers serve the rest, by token. Wiped at the start of every
-- call; the prompt's hold and its press hand in none and read afresh.
local groupMemo = { subgroup = {}, class = {}, flag = {} }

-- nil kept as an answer of its own, so "cannot tell" is not asked again.
local NOTHING = {}

local function Asked(memo, kind, unit, read)
	if not memo then return read(unit) end
	local kept = memo[kind]
	local value = kept[unit]
	if value == nil then
		value = read(unit)
		if value == nil then value = NOTHING end
		kept[unit] = value
	end
	if value == NOTHING then return nil end
	return value
end

local CoreRaidSubgroup = ns.RaidSubgroup
local function RaidSubgroup(unit, memo)
	return Asked(memo, "subgroup", unit, CoreRaidSubgroup)
end

-- A unit's class file name ("WARRIOR"), and its PvP flag (Queue.lua's
-- reading, looked up when asked), for Asked.
local function ClassFile(unit)
	return plain(select(2, UnitClass(unit)))
end
local function Flag(unit)
	return ns.PvPFlag(unit)
end

-- Whether `unit` carries a blessing of ours other than `key`, or cannot be
-- read: either way a Greater Blessing of `key` may take one of ours off them.
-- `mine` is the player's own blessings.
local function CarriesAnother(unit, key, mine)
	local guid = plain(UnitGUID(unit))
	for _, buff in ipairs(mine) do
		if buff.key ~= key then
			local has, _, ours = ns.UnitHasBuff(unit, buff, guid)
			if has == nil or (has == true and ours ~= false) then return true end
		end
	end
	return false
end

-- Whether a Greater Blessing for everybody of `class` takes nothing of ours
-- away. Blessings from one paladin replace one another, and the Greater one
-- lands on the whole class, the people the queue never offered included --
-- so one of them carrying another of ours, or unreadable, says no. `offered`
-- is who the queue did offer; their blessing was read already.
local function ClassSafe(class, key, offered, inRaid)
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	local tokens = inRaid and TOKENS.raid or TOKENS.party
	local count = math.min(inRaid and n or (n - 1), 40)
	local mine = ns.GetClassBuffs(ns.PlayerClass()) or {}
	for i = 1, count do
		local unit = tokens[i]
		if plain(UnitExists(unit)) and plain(UnitIsUnit(unit, "player")) ~= true
			and plain(select(2, UnitClass(unit))) == class then
			local name = ns.UnitFullName(unit)
			if not (name and offered[name]) and CarriesAnother(unit, key, mine) then return false end
		end
	end
	-- You, when it is your own class: the Greater Blessing lands on the
	-- caster as on anybody of the class, and the walk above never reads you
	-- (a party's tokens never hold you, and a raid's is skipped). Wearing
	-- another of your own blessings keeps your own entry off the queue
	-- (Queue.lua, SelfEntry), so nothing else would; an entry of yours, when
	-- there is one, was read already.
	if class == ns.PlayerClass() then
		local name = ns.UnitFullName("player")
		if not (name and offered[name]) and CarriesAnother("player", key, mine) then return false end
	end
	return true
end

-- Whether a group spell or shout can land on `unit` at all: not one the
-- client says is out of sight (beyond any group spell's 100 yards, as
-- BuildQueue reads it), nor one lying dead. A hunter's Feign Death is no
-- death, and the spell lands on them. An unclear answer counts as reached.
-- Called directly, as Queue.lua calls them: a group token never throws.
local function Reached(unit)
	if plain(UnitIsVisible and UnitIsVisible(unit)) == false then return false end
	if plain(UnitIsDeadOrGhost(unit)) == true then
		local feigning = _G.UnitIsFeignDeath
		if type(feigning) ~= "function" then return true end
		return plain(feigning(unit)) ~= false
	end
	return true
end

-- Who of everybody a party-wide spell lands on reads as flagged for PvP: the
-- first one's name in token order, "?" when the game will not name them, or
-- nil. `where` is a bucket's (a class, a raid subgroup, "party") or "raid" for
-- the whole raid, and everybody in it counts, not only those queued: somebody
-- flagged was never queued at all. Somebody whose class, subgroup or flag
-- cannot be read is no reason to (cannot tell); you are never counted, and
-- nor is somebody the spell cannot reach (Reached), asked only of the flagged
-- so a raid with nobody flagged pays nothing for it. `memo` is GroupCasts',
-- nil for a question asked afresh.
local function FlaggedAmong(where, byClass, inRaid, memo)
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	local tokens = inRaid and TOKENS.raid or TOKENS.party
	-- The party's other four, or the whole raid, whose tokens hold you too.
	local last = math.min(inRaid and n or (n - 1), 40)
	for i = 1, last do
		local unit = tokens[i]
		if plain(UnitExists(unit)) and plain(UnitIsUnit(unit, "player")) ~= true then
			local inside = true
			if byClass then
				inside = Asked(memo, "class", unit, ClassFile) == where
			elseif inRaid and where ~= "raid" then
				inside = RaidSubgroup(unit, memo) == where
			end
			if inside and Asked(memo, "flag", unit, Flag) == true and Reached(unit) then
				return ns.UnitFullName(unit) or "?"
			end
		end
	end
	return nil
end

-- The same for a group cast already made (the prompt's hold and its press
-- ask, Queue.lua's HeldForPvP), read again now.
function ns.GroupCastFlagged(entry)
	local group = entry and entry.groupCast
	if not (group and group.where) then return nil end
	return FlaggedAmong(group.where, group.class ~= nil, plain(IsInRaid and IsInRaid()) == true)
end

-- And for a shout, which lands where SameParty (Core.lua) says it reaches:
-- your own party, and in a raid the whole raid where the client's shouts are
-- raid-wide (ns.PARTY_IS_SUBGROUP false: the Mists and retail sets), else
-- your own subgroup -- nobody when that cannot be read, since cannot tell
-- offers. Asked of your subgroup alone on a raid-wide client, a raider
-- flagged in another one was left out while the shout was offered to all.
function ns.ShoutFlagged(inRaid)
	if inRaid == nil then inRaid = plain(IsInRaid and IsInRaid()) == true end
	if not inRaid then return FlaggedAmong("party", false, false) end
	if not ns.PARTY_IS_SUBGROUP then return FlaggedAmong("raid", false, true) end
	local own = RaidSubgroup("player")
	if not own then return nil end
	return FlaggedAmong(own, false, true)
end

-- Core's, so "every Warrior" and {class} on the prompt spell it alike.
local ClassName = ns.ClassName

---------------------------------------------------------------------------
-- the group cast in the queue
---------------------------------------------------------------------------

-- Who counts towards the threshold: read as missing the buff, or as running
-- out of it (a top-up), told apart so the panel can say which. A reading
-- nobody could make is neither -- a reagent spent on people who may be
-- covered is wasted -- though the cast covers them.
local function Missing(entry)
	return entry.known == false
end

local function RunningLow(entry)
	return entry.known == true and entry.remaining ~= nil
end

-- Which of a party the macro aims at: the one the queue ranks highest, then
-- somebody measured in range, then somebody owed a favour (a ready check or
-- a death sweeps the whole party to one priority, the owed member too, and
-- the cast went to whoever came first by name), then by name so the choice
-- holds still. Aimed elsewhere, the line still thanks the one it repays
-- (Prompt/Macro.lua, ns.LineSpeaker).
local function Better(a, b)
	-- Never you while anybody else is in reach. You count towards the
	-- threshold and the cast covers you, but it is aimed at one of the others,
	-- so the macro, the spoken line and the ledger are about a person as they
	-- always were, and nothing a press on yourself leaves out (Clicks.lua,
	-- SettleSelf) is left out of a group cast.
	if (a.reason == "self") ~= (b.reason == "self") then return b.reason == "self" end
	if a.priority ~= b.priority then return a.priority < b.priority end
	if (a.ranged == true) ~= (b.ranged == true) then return a.ranged == true end
	if (a.reason == "owed") ~= (b.reason == "owed") then return a.reason == "owed" end
	return (a.name or "") < (b.name or "")
end

-- Who the cast is for, the way players say it: the panel's title ("Your
-- party", "Group 3", "Your raid", "Every Warrior") and the same inside a
-- sentence. The party is always yours outside a raid; in one, people call the
-- subgroups by number, and yours is "your group"; a cast that reaches the
-- whole raid is for "your raid".
local function Names(bucket, byClass, inRaid, ownSubgroup)
	if byClass then
		local class = ClassName(bucket.where)
		return L["Every %s"]:format(class), L["every %s"]:format(class)
	elseif inRaid and bucket.where == "raid" then
		return L["Your raid"], L["your raid"]
	elseif not inRaid or type(bucket.where) ~= "number" then
		-- Outside a raid, or a raid group nothing numbered: the party.
		return L["Your party"], L["your party"]
	elseif bucket.where == ownSubgroup then
		return L["Your group"], L["your group"]
	end
	return L["Group %d"]:format(bucket.where), L["group %d"]:format(bucket.where)
end

-- The one entry for a bucket that has reached the threshold, or nil. Built on
-- a copy of the anchor's own entry, so everything that reads an entry reads
-- this one the same way. `pvp` is Queue.lua's record of the scan while the
-- PvP rule stands, nil while it does not; `memo` is GroupCasts' reading of
-- the group, shared by every bucket.
local function Build(bucket, byClass, inRaid, ownSubgroup, pvp, memo)
	local anchor
	for _, entry in ipairs(bucket.entries) do
		-- Somebody measured out of reach cannot be the target; the cast still
		-- covers them if the game says it does.
		if entry.ranged ~= false and (not anchor or Better(entry, anchor)) then anchor = entry end
	end
	if not anchor then return nil end
	-- Only you in reach (see Better): a reagent spent on yourself alone,
	-- which the single buff does for nothing.
	if anchor.reason == "self" then return nil end

	-- Flagged for PvP: the spell lands on every one of them, so one flagged
	-- member keeps it back while you are not flagged, said in /manners debug.
	-- Those who are not flagged are still offered one at a time: nothing
	-- here takes their single casts out of the queue.
	if pvp then
		local flagged = FlaggedAmong(bucket.where, byClass, inRaid, memo)
		if flagged then
			local _, label = Names(bucket, byClass, inRaid, ownSubgroup)
			pvp.groups[#pvp.groups + 1] = { name = flagged, label = label,
				spell = bucket.ready.info.groupName or ns.BuffName(bucket.buff) }
			return nil
		end
	end

	if byClass then
		local offered = {}
		for _, entry in ipairs(bucket.entries) do
			-- Unread, they may carry another blessing of ours that this replaces.
			if entry.known == nil then return nil end
			offered[entry.name] = true
		end
		if not ClassSafe(bucket.where, bucket.buff.key, offered, inRaid) then return nil end
	end

	-- The anchor is the best of those in reach (Better asks priority first),
	-- so a favour owed in the party puts the cast where that favour would
	-- stand. One measured out of reach does not lift it: nothing says the
	-- cast gets to them.
	local members = {}
	-- Whether every one of them asked for it in chat. An asker outranks the
	-- party, so the anchor is the asker whenever anybody asked, and its reason
	-- alone would file the whole cast as asked for -- out of the day's gifts --
	-- when it reached everybody else unprompted.
	local asked = true
	-- Everybody else it repays, nobody measured out of reach: the spoken line
	-- thanks one of them when the anchor is owed nothing (Prompt/Macro.lua).
	local owed
	for _, entry in ipairs(bucket.entries) do
		if entry ~= anchor then members[#members + 1] = entry.name end
		if entry.reason ~= "asked" then asked = false end
		if entry ~= anchor and entry.reason == "owed" and entry.ranged ~= false then
			owed = owed or {}
			owed[#owed + 1] = entry
		end
	end

	local info = bucket.ready.info
	local group = {}
	for field, value in pairs(anchor) do group[field] = value end
	local display, label = Names(bucket, byClass, inRaid, ownSubgroup)
	group.groupCast = {
		spell = info.groupRank,
		spellName = info.groupName or ns.BuffName(bucket.buff),
		icon = info.groupIcon,
		reagent = info.groupReagent,
		reagents = bucket.ready.have,
		-- Reagent Economy: nothing is used, and the tooltip says so.
		reagentWaived = bucket.ready.waived or nil,
		-- Apart, so the panel says "4 missing" after a wipe and "4 running
		-- out" before a pull; the threshold is on the two together.
		missing = bucket.missing,
		low = bucket.low,
		-- Everybody else the queue had lined up that this covers, by name.
		members = members,
		class = byClass and bucket.where or nil,
		-- The party, subgroup or class it lands on, asked again for PvP flags
		-- while the prompt holds it (GroupCastFlagged).
		where = bucket.where,
		-- Who it is for, inside a sentence ("your party", "group 3").
		label = label,
		asked = asked or nil,
		-- The members' own entries, for the line (see above).
		owed = owed,
	}
	-- What the panel's first line says in place of the anchor's name.
	group.display = display
	return group
end

-- The queue with the single casts a group cast replaces taken out and the
-- group cast put in. `candidates` is CastableBuffs' answer for this scan.
-- Nothing changes unless the setting is on, "My party and raid" is on (the
-- cast lands on the whole party, so it is for players offering their party),
-- and a buff has its group version learned, stocked and usable.
function ns.GroupCasts(queue, db, candidates, inRaid)
	-- This call's reading of the group, empty whatever the last call left
	-- (and left alone when it already is, as it is for anybody with no group
	-- version to cast).
	local memo = groupMemo
	if next(memo.subgroup) then wipe(memo.subgroup) end
	if next(memo.class) then wipe(memo.class) end
	if next(memo.flag) then wipe(memo.flag) end

	local settings = db.groupBuffs
	if not (settings and settings.use == true and db.sources.group) then return queue end
	local atLeast = tonumber(settings.atLeast) or 3

	local ready
	for _, buff in ipairs(candidates) do
		local info = ns.BuffInfo(buff)
		if info and info.groupRank and info.groupReagent then
			local have = ReagentCount(info.groupReagent)
			-- Waived, the bags have nothing to run out of, and the client has
			-- just said the spell is usable.
			local waived = ReagentWaived(info, have)
			if not waived then NoteStock(info, have, db) end
			if waived or (have and have > 0 and Usable(info.groupRank)) then
				ready = ready or {}
				ready[buff.key] = { info = info, have = have, waived = waived }
			end
		end
	end
	if not ready then return queue end

	local byClass = ns.GROUP_BY_CLASS[ns.PlayerClass()] == true
	local buckets, order = {}, {}
	for _, entry in ipairs(queue) do
		local buff = entry.buff
		local r = buff and ready[buff.key]
		-- Only people read through a unit token in the group: the tokenless
		-- favours have no party anybody can name. You among them, when you are
		-- missing it too: your own entry (Queue.lua) holds the "player" token,
		-- which the party's tokens never do, and the group version lands on
		-- the caster as on the rest of the party (or class).
		if r and entry.unit and entry.inGroup then
			local where
			if byClass then
				where = entry.class
			elseif inRaid then
				-- Forever's reach the whole raid, Classic Era's the subgroup.
				where = ns.GROUP_IS_RAID and "raid" or RaidSubgroup(entry.unit, memo)
			else
				where = "party"
			end
			if where then
				local key = buff.key .. "\0" .. tostring(where)
				local bucket = buckets[key]
				if not bucket then
					bucket = { entries = {}, missing = 0, low = 0, ready = r, buff = buff, where = where }
					buckets[key] = bucket
					order[#order + 1] = bucket
				end
				bucket.entries[#bucket.entries + 1] = entry
				if Missing(entry) then
					bucket.missing = bucket.missing + 1
				elseif RunningLow(entry) then
					bucket.low = bucket.low + 1
				end
			end
		end
	end

	-- The scan's PvP record while the rule stands in it (Queue.lua), which
	-- a group cast held back for a flagged member is written into.
	local pvp = ns.PvPRecord()
	-- The player's own subgroup, so theirs is "your group" and not a number.
	local ownSubgroup = inRaid and not byClass and not ns.GROUP_IS_RAID and RaidSubgroup("player", memo) or nil
	local absorbed, made
	for _, bucket in ipairs(order) do
		if bucket.missing + bucket.low >= atLeast then
			local group = Build(bucket, byClass, inRaid, ownSubgroup, pvp, memo)
			if group then
				absorbed = absorbed or {}
				made = made or {}
				for _, entry in ipairs(bucket.entries) do absorbed[entry] = true end
				made[#made + 1] = group
			end
		end
	end
	if not made then return queue end

	local out = {}
	for _, entry in ipairs(queue) do
		if not absorbed[entry] then out[#out + 1] = entry end
	end
	for _, group in ipairs(made) do out[#out + 1] = group end
	return out
end

-- The spell an entry's macro casts: the group version's own name for a group
-- cast. Everything that names the spell about to go out asks this.
function ns.EntrySpellName(entry)
	if entry and entry.groupCast and entry.groupCast.spellName then return entry.groupCast.spellName end
	-- BuffName's own answer otherwise, "?" for no buff at all included.
	return ns.BuffName(entry and entry.buff)
end

-- "Not now" on a group cast is about the whole party: the anchor is blocked by
-- whoever skipped, and this puts everybody else it covered on the same retry
-- cooldown for that buff, or the next scan re-forms the cast around the next
-- of them (or, under the threshold, offers them one by one). Only that buff:
-- the skip was of this cast, and a priest's Divine Spirit for them stands.
-- keepLonger, so a longer block already standing is never cut short.
function ns.SkipGroupCast(entry)
	local group = entry and entry.groupCast
	if not (group and entry.buff) then return end
	for _, name in ipairs(group.members) do
		ns.MarkAttempted(name, entry.buff.key, nil, true)
	end
end

-- The options page's two descriptions, for this character's class: a
-- paladin's Greater Blessings go by class across the whole group, everybody
-- else's by party (in a raid, raid group; on Forever the whole raid), and the
-- spells named are the ones this character has learned. Read each time the
-- page is drawn.
function ns.GroupBuffDescriptions()
	if ns.GROUP_BY_CLASS[ns.PlayerClass()] == true then
		return L["Cast one Greater Blessing for a whole class when enough of that class need it and you carry the reagent."],
			L["How many of one class in your party or raid must be missing it first."]
	end
	local names = {}
	for _, buff in ipairs(ns.GetClassBuffs(ns.PlayerClass()) or {}) do
		local info = buff.groupCast and ns.BuffInfo(buff)
		if info and info.groupName then names[#names + 1] = info.groupName end
	end
	if ns.GROUP_IS_RAID then
		local slider = L["How many in your party or raid must be missing it first."]
		if #names == 0 then
			return L["Cast your class's group version, once learned, when enough of your party or raid need it and you carry the reagent."],
				slider
		end
		return L["Cast one %s when enough of your party or raid need it and you carry the reagent."]
			:format(table.concat(names, " / ")), slider
	end
	-- "One party" is a raid group in a raid, which is what the fold counts.
	local slider = L["How many in one party must be missing it first."]
	if #names == 0 then
		return L["Cast your class's group version, once learned, when enough of one party need it and you carry the reagent."],
			slider
	end
	return L["Cast one %s when enough of one party need it and you carry the reagent."]
		:format(table.concat(names, " / ")), slider
end

-- Whether this character has a group version of any of its buffs in the
-- data at all, learned or not, so the options page shows the setting only
-- to classes it means something to.
function ns.ClassHasGroupBuffs()
	for _, buff in ipairs(ns.GetClassBuffs(ns.PlayerClass()) or {}) do
		if buff.groupCast then return true end
	end
	return false
end
