-- Manners -- the favour ledger.
--
-- A record of what the addon has done for you: who buffed you, with what and
-- when, whether you returned it and with what, and who you buffed unasked. The
-- recent entries are listed in a small window (/manners ledger), under the
-- lifetime counts, which the minimap tooltip and the General tab repeat.
--
-- It is a record and never a decision. Core tells it what happened at the four
-- moments a favour changes hands -- noticed, repaid, refused after all, let go
-- -- and nothing reads it to decide what to offer: the debt table in Queue.lua
-- is the one opinion about who is owed. So the ledger can only be wrong by
-- missing something, and one that throws takes nothing with it (Guard).
--
-- The window is plain UI with no secure frame, so it works in a fight.

local _, ns = ...
local L = ns.L

local Ledger = {}
ns.Ledger = Ledger

local GetTime = _G.GetTime
-- Read once at load, like Core's own copy, and asked directly: a name kept
-- here goes to disk, and a secret must never get that far.
local issecretvalue = _G.issecretvalue

---------------------------------------------------------------------------
-- text
--
-- Every sentence a player reads, in one place and each one whole, because a
-- sentence assembled from pieces cannot be translated. Format strings carry the
-- numbers and names; each is looked up in L once, at load, which is after the
-- locale files have filled it.
---------------------------------------------------------------------------

local TEXT = {
	TITLE = L["Favour ledger"],
	-- A glyph drawn as the close button, not a word, so it is the same in
	-- every language and there is nothing to hand a translator.
	CLOSE = "x",
	CLOSE_TIP = L["Close (Escape works too)"],

	-- The headline over the list, repeated by the minimap tooltip and the options
	-- page. "Today" is this computer's calendar day. It counts only favours
	-- something you cast could have returned: a warrior's shout to a mage scored
	-- as not returned would be a failure the player can do nothing about.
	-- "Recorded" rather than "nobody buffed you": the ledger hears nothing while
	-- the addon is off or has nothing to cast, or after Clear.
	TODAY_NONE = L["No favours recorded today."],
	TODAY_ONLY_USELESS = L["Nothing you cast could return today's favours."],
	TODAY_ONE = L["Returned %d of 1 favour today."],
	TODAY_MANY = L["Returned %d of %d favours today."],
	OWED_ONE = L["1 favour still owed."],
	OWED_MANY = L["%d favours still owed."],
	-- Casts, not people: topping up the same five players three times is
	-- fifteen buffs and still five players.
	GAVE_ONE = L["You gave 1 buff unprompted today."],
	GAVE_MANY = L["You gave %d buffs unprompted today."],
	LIFETIME = L["All time -- received: %d, returned: %d, given to your group: %d, to strangers: %d"],

	-- The same four numbers as tiles across the window, each with its label
	-- underneath, and the caption over them.
	ALL_TIME = L["All time"],
	STAT_RECEIVED = L["received"],
	STAT_RETURNED = L["returned"],
	STAT_GROUP = L["to your group"],
	STAT_STRANGERS = L["to strangers"],
	-- Where the rows on screen sit in the list: "1-8 of 42".
	SHOWING = L["%d-%d of %d"],

	TAB_ALL = L["Everything"],
	TAB_FAVOURS = L["Favours"],
	TAB_GIVEN = L["Buffs you gave"],

	EMPTY_ALL = L["Nothing recorded. When somebody buffs you it is listed here, and so is what you give back and who you buff unprompted."],
	EMPTY_FAVOURS = L["No favours recorded. When somebody buffs you, they are listed here."],
	EMPTY_GIVEN = L["No buffs given unprompted. When the prompt buffs somebody who did not buff you first, it is listed here."],
	-- In place of the lines above while nothing new can arrive, because "when
	-- somebody buffs you it is listed here" is then a promise the addon is not
	-- keeping. The owed toggle stops favours only; buffs given still arrive.
	EMPTY_OFF = L["Nothing is recorded while Manners is switched off."],
	EMPTY_NOTHING = L["Nothing is recorded while the prompt has nothing to cast on this character."],
	EMPTY_OWED_OFF = L["Favours are not recorded while \"People who buff me\" is off, on the Who to buff tab."],

	CLEAR = L["Clear"],
	CLEAR_ARMED = L["Click again to clear"],
	CLEAR_TIP = L["Empties the list, and today's count with it. Favours you still owe stay, and the all-time totals are kept."],

	-- A row's second line reads "badge  detail": a coloured status word, two
	-- spaces, then one of the details below, which finishes the badge's phrase
	-- without repeating it. The badge is its own key because it takes its own
	-- colour and can stand alone (a returned favour with no spell to name). A
	-- detail whose words need another order has them all in its own key.
	--
	-- Badges: a favour owed to the row's player; one returned; one let go
	-- unreturned; and a buff you gave them unprompted, when nobody owed it.
	STATE_OWED = L["Still owed"],
	STATE_RETURNED = L["Returned"],
	STATE_LETGO = L["Let go"],
	STATE_GAVE = L["Gave"],
	-- After "Returned": %s is the spell you returned the favour with.
	RETURNED_WITH = L["with %s"],
	-- After "Let go": why it was let go.
	LETGO_EXPIRED = L["the time to return it ran out"],
	LETGO_USELESS = L["nothing you cast is any use to them"],
	LETGO_NOTKEPT = L["forgotten at a logout or reload"],
	-- A favour the player let go on purpose, by putting its giver on the
	-- never-offer list.
	LETGO_NEVER = L["you put them on your never-offer list"],
	-- After "Gave": %s is the spell you gave the row's player.
	GAVE_GROUP = L["%s, in your group"],
	GAVE_STRANGER = L["%s, to a stranger"],
	-- A group cast: %s is the spell, %d how many the queue had lined up for it,
	-- which is not everybody in the party, only those who needed it.
	GAVE_COVERED = L["%s, to %d who needed it"],
	-- In place of a spell name the client could not give.
	UNKNOWN_SPELL = L["a buff"],

	-- The row tooltip, which is where the whole story goes.
	TIP_BUFFED = L["Buffed you with %s, %s."],
	TIP_TIMES = L["They buffed you %d times; one buff back repays all of it."],
	TIP_OWED = L["Still owed. The prompt offers them until you return it or the time runs out."],
	-- A warrior's shout and the like reach the caster's party and nobody else,
	-- so a favour from outside it waits for them to be in it. Said so it is
	-- true whether or not they are in it now.
	TIP_OWED_PARTY = L["Still owed. What you cast reaches only your own party, so the prompt offers them only while they are in it."],
	TIP_OWED_SUBGROUP = L["Still owed. What you cast reaches only your own party -- in a raid, your own subgroup -- so the prompt offers them only while they are in it."],
	-- A paladin's Salvation, which reaches the whole raid but nobody outside it.
	TIP_OWED_GROUP = L["Still owed. What you cast reaches only your own party or raid, so the prompt offers them only while they are in it."],
	TIP_RETURNED = L["You returned it %s later."],
	TIP_RETURNED_WITH = L["You returned it %s later, with %s."],
	TIP_LETGO_EXPIRED = L["Let go: the time to return it ran out before you did."],
	TIP_LETGO_USELESS = L["Let go: nothing you can cast is any use to them."],
	-- The setting's own name and place, through the options page's keys, so a
	-- translation names what the player will find there; a scenario holds it to.
	-- Keep favours through a /reload is on When to offer, under Favours.
	TIP_LETGO_NOTKEPT = L["Let go: \"%s\" (%s tab, under %s) is off, so it was forgotten when you logged out or reloaded."]
		:format(L["Keep favours through a /reload"], L["When to offer"], L["Favours"]),
	TIP_LETGO_NEVER = L["Let go: you put them on your never-offer list."],
	-- In place of TIP_OWED while the prompt cannot offer them, the rule Quiet()
	-- below keeps for the empty list: the window never promises what cannot
	-- come. The toggle is quoted by the name it has on the Who to buff tab, and
	-- %s is the time the snooze ends, on the player's clock.
	TIP_OWED_OFF = L["Still owed, but Manners is switched off, so the prompt will not offer them."],
	TIP_OWED_SOURCE_OFF = L["Still owed, but the prompt is not offering favours while \"People who buff me\" is off."],
	TIP_OWED_NOTHING = L["Still owed, but there is nothing on this character the prompt can cast."],
	-- Flagged for PvP when last read, while "Skip players flagged for PvP"
	-- holds them back (Queue.lua, "flagged for PvP"). Worded as the snooze
	-- line is: a flag often outlasts the favour.
	TIP_OWED_PVP = L["Still owed. They are flagged for PvP, and buffing them would flag you, so the prompt offers them only if their flag drops before the time to return it runs out."],
	TIP_OWED_SNOOZED = L["Still owed. The prompt is snoozed until %s, so it offers them only if the snooze ends before the time to return it runs out."],
	TIP_OWED_MOUNTED = L["Still owed. The prompt stays away while you are mounted, and offers them once you get off, until the time to return it runs out."],
	-- The same two for a favour only your party can return: the snooze or the
	-- ride ending is not enough while they are outside your party.
	TIP_OWED_SNOOZED_PARTY = L["Still owed. What you cast reaches only your own party, so the prompt offers them only while they are in it, and it is snoozed until %s, so only if time is left then."],
	TIP_OWED_SNOOZED_SUBGROUP = L["Still owed. What you cast reaches only your own party -- in a raid, your own subgroup -- so the prompt offers them only while they are in it, and it is snoozed until %s, so only if time is left then."],
	TIP_OWED_MOUNTED_PARTY = L["Still owed. What you cast reaches only your own party, so the prompt offers them only while they are in it, once you are no longer mounted, until the time runs out."],
	TIP_OWED_MOUNTED_SUBGROUP = L["Still owed. What you cast reaches only your own party -- in a raid, your own subgroup -- so the prompt offers them only while they are in it, once you are no longer mounted, until the time runs out."],
	TIP_OWED_SNOOZED_GROUP = L["Still owed. What you cast reaches only your own party or raid, so the prompt offers them only while they are in it, and it is snoozed until %s, so only if time is left then."],
	TIP_OWED_MOUNTED_GROUP = L["Still owed. What you cast reaches only your own party or raid, so the prompt offers them only while they are in it, once you are no longer mounted, until the time runs out."],
	TIP_GAVE = L["You buffed them with %s, %s."],
	TIP_GAVE_GROUP = L["They were in your group and had not buffed you."],
	TIP_GAVE_STRANGER = L["They were not in your group and had not buffed you."],
	-- Under either of those for a buff somebody asked for, which is listed
	-- with the rest but not counted as given unprompted.
	TIP_GAVE_ASKED = L["They asked for it in chat."],
	-- Under TIP_GAVE_GROUP for a group cast, which is counted as one buff. The
	-- group is not named: a party's, a class's or (on Forever) a whole raid's.
	TIP_GAVE_COVERED = L["One cast gave it to %d who needed it, and counts as one buff given."],

	JUST_NOW = L["just now"],
	MINUTES_AGO = L["%d min ago"],
	HOURS_AGO = L["%d hr ago"],
	DAY_AGO = L["a day ago"],
	DAYS_AGO = L["%d days ago"],
	SECONDS = L["%d sec"],
	MINUTES = L["%d min"],
	HOURS = L["%d hr"],

	OPTIONS_EMPTY = L["Nothing has been recorded on this character yet."],

	-- The title the favours you have returned earn (TITLES below): at the top of
	-- the window, the title on the left and the way to the next on the right,
	-- "37 of 50 to Courteous".
	UNTITLED = L["Untitled, for now"],
	RANK_PROGRESS = L["%d of %d to %s"],
	RANK_TOP = L["every title earned"],
	-- Hovering it: what the title is for, and where the next one is.
	RANK_TIP_NEXT = L["Titles come from the favours you return. The next, %s, comes at %d."],
	RANK_TIP_TOP = L["Every title there is, and all of them earned. Nobody has better manners."],
	-- The same in the minimap tooltip, one line each.
	BROKER_TITLED = L["Title: %s -- %d of %d to %s"],
	BROKER_TOP = L["Title: %s -- every title earned"],
	BROKER_FIRST = L["%d of %d favours returned to your first title, %s"],
	-- The one chat line a new title gets: its name, then its line of flavour.
	EARNED = L["A new title for your manners: |cffffd100%s|r. %s"],
}
Ledger.TEXT = TEXT

-- The titles, earned by favours returned: the lifetime count, which Clear keeps,
-- so a title once earned stays. Returned rather than received, because a title
-- for being buffed a lot would be a title for standing in Stormwind. Each has a
-- line of flavour, said once in chat when it is earned and again on hovering it.
local TITLES = {
	{ at = 10, name = L["Well Brought Up"], flavour = L["Somebody raised you right."] },
	{ at = 25, name = L["Well Mannered"], flavour = L["You would hold the door, if dungeons had doors."] },
	{ at = 50, name = L["Courteous"], flavour = L["Innkeepers have started to nod when you come in."] },
	{ at = 100, name = L["Gracious"], flavour = L["You bow a little when you cast now. People have noticed."] },
	{ at = 250, name = L["Magnanimous"], flavour = L["Strangers argue over who gets to buff you first."] },
	{ at = 500, name = L["Paragon of Etiquette"], flavour = L["Somewhere, a butler weeps with pride."] },
	{ at = 1000, name = L["The Very Soul of Courtesy"], flavour = L["Azeroth has never been buffed so politely."] },
}
Ledger.TITLES = TITLES
-- A title's colour wherever one is named: a paler gold than the headline's, so
-- the two do not read as one line in the window.
local RANK_INK = { 0.96, 0.84, 0.52 }

---------------------------------------------------------------------------
-- bounds
---------------------------------------------------------------------------

-- The list kept on disk. Two hundred rows is weeks of ordinary play and a few
-- kilobytes in the saved file; the lifetime counts are kept separately and are
-- never trimmed.
local MAX_ENTRIES = 200
-- Of which buffs given unprompted may take at most half, so a mage buffing a
-- city's strangers cannot push every favour off the end of the list.
local MAX_GIVEN = 100
-- The spells one favour remembers. A priest lands three buffs at once, and that
-- is one favour with three names on it rather than three rows.
local MAX_SPELLS = 3
-- A second buff from the same person inside this many seconds is the same
-- favour. Wider than one landing needs, narrower than any recast.
local FOLD_SECONDS = 10
-- How long a settle is kept for a refusal to undo it. Core keeps its own record
-- for its SETTLE_SECONDS and only ever calls back inside that; this is a
-- generous bound on a list that would otherwise grow for the session.
local UNDO_SECONDS = 30
-- How long a new title waits before it is said: Core's SETTLE_SECONDS, in
-- which a refusal can still take back the favour that earned it, and a second
-- over for the refusal's event to arrive.
local PROMOTE_SECONDS = 3
Ledger.PROMOTE_SECONDS = PROMOTE_SECONDS

local STATES = { owed = true, returned = true, letgo = true }
-- Why a favour was let go: its time ran out, nothing you cast is any use to
-- them, it was forgotten at a reload, or you put them on the never-offer list.
local WHY = { expired = true, useless = true, notkept = true, never = true }
local FILTERS = { all = true, favours = true, given = true }
local TOTALS = { "received", "returned", "letGo", "group", "strangers" }
-- Today's counts of favours, kept beside today's count of gifts.
local TODAY = { "received", "returned", "useless" }
local POINTS = {
	CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

---------------------------------------------------------------------------
-- reading values the client hands over
---------------------------------------------------------------------------

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- A name that may be kept, or nil: the debt table's rules, restated because
-- this too goes to disk and the window prints it. A secret, anything longer
-- than a name and a surname (twelve characters each of up to four bytes, and
-- a space), and anything with a chat escape or macro punctuation are refused.
local function CleanName(name)
	if Secret(name) or type(name) ~= "string" then return nil end
	if name == "" or #name > 97 then return nil end
	if name:find("[%[%]\n\r;|]") then return nil end
	return name
end

-- The client's class token, MAGE or PRIEST: capitals and nothing else, so it
-- can index the colour table and can never carry anything into the text.
local function CleanClass(class)
	if Secret(class) or type(class) ~= "string" or #class > 20 then return nil end
	if not class:find("^%u+$") then return nil end
	return class
end

local function CleanSpell(id)
	if Secret(id) or type(id) ~= "number" then return nil end
	if id <= 0 or id ~= math.floor(id) or id > 10000000 then return nil end
	return id
end

local function CleanTime(t)
	if Secret(t) or type(t) ~= "number" then return nil end
	if t ~= t or t <= 0 or t == math.huge then return nil end
	return t
end

local function Count(v)
	if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then return 0 end
	return math.floor(v)
end

local function Whole(v)
	return type(v) == "number" and v >= 0 and v == math.floor(v) and v ~= math.huge
end

-- Which of TITLES this many favours returned earns, 0 for none yet. Seven
-- comparisons, asked only when a favour is returned or something is drawn.
local function TitleLevel(returned)
	local level = 0
	for i, t in ipairs(TITLES) do
		if Count(returned) >= t.at then level = i end
	end
	return level
end

-- The wall clock. Everything stored is on it, for the reason Core's debts are:
-- GetTime() starts again near zero after a reboot and means nothing on disk.
local function Wall()
	local ok, t = pcall(_G.time)
	if not ok then return nil end
	return CleanTime(t)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, value = pcall(fn, ...)
	if not ok or Secret(value) then return nil end
	return value
end

local function SpellName(id)
	if not id then return nil end
	local name = Call(C_Spell and C_Spell.GetSpellName, id) or Call(_G.GetSpellInfo, id)
	return type(name) == "string" and name or nil
end

-- The question mark every spell book falls back to.
local QUESTION_MARK = 134400

local function SpellIcon(id)
	if not id then return QUESTION_MARK end
	return Call(C_Spell and C_Spell.GetSpellTexture, id) or Call(_G.GetSpellTexture, id)
		or QUESTION_MARK
end

local function Coloured(name, class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and type(c.colorStr) == "string" then
		return ("|c%s%s|r"):format(c.colorStr, name)
	end
	return name
end

---------------------------------------------------------------------------
-- time as a player reads it
---------------------------------------------------------------------------

function Ledger.Ago(seconds)
	seconds = math.max(0, seconds or 0)
	if seconds < 45 then return TEXT.JUST_NOW end
	if seconds < 3600 then return TEXT.MINUTES_AGO:format(math.min(59, math.max(1, math.floor(seconds / 60 + 0.5)))) end
	if seconds < 86400 then return TEXT.HOURS_AGO:format(math.min(23, math.max(1, math.floor(seconds / 3600 + 0.5)))) end
	local days = math.floor(seconds / 86400)
	if days == 1 then return TEXT.DAY_AGO end
	return TEXT.DAYS_AGO:format(days)
end

local function Duration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	if seconds < 60 then return TEXT.SECONDS:format(seconds) end
	if seconds < 3600 then return TEXT.MINUTES:format(math.min(59, math.floor(seconds / 60 + 0.5))) end
	return TEXT.HOURS:format(math.floor(seconds / 3600 + 0.5))
end

-- Local midnight, on this computer's clock. Made from today's date by time(),
-- which applies daylight saving: counting back the hours on the clock is an
-- hour out on the day the clocks change, and "today" would then move at the
-- change. An answer that does not read back as midnight today (a time() that
-- ignores the table) is not trusted, and the count back is used, stepped on to
-- today where the clocks skip midnight; should date() not answer with a table,
-- "today" is the last day's worth of seconds.
local function StartOfToday(now)
	local ok, t = pcall(_G.date, "*t", now)
	if not (ok and type(t) == "table") then return now - 86400 end
	local okTime, midnight = pcall(_G.time,
		{ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 })
	if okTime and type(midnight) == "number" and midnight <= now then
		local okBack, back = pcall(_G.date, "*t", midnight)
		if okBack and type(back) == "table" and back.hour == 0
			and back.day == t.day and back.month == t.month then
			return midnight
		end
	end
	if type(t.hour) == "number" and type(t.min) == "number" and type(t.sec) == "number" then
		local c = now - ((t.hour * 60 + t.min) * 60 + t.sec)
		-- Where the clocks skip midnight (00:00 -> 01:00) there is no midnight to
		-- read back, and the count back lands an hour into yesterday: step on to
		-- the first moment that is today.
		for _ = 1, 4 do
			local okC, ct = pcall(_G.date, "*t", c)
			if not (okC and type(ct) == "table" and (ct.day ~= t.day or ct.month ~= t.month)) then break end
			c = c + 1800
		end
		return c
	end
	return now - 86400
end

---------------------------------------------------------------------------
-- the store
--
-- db.char, like the debts: a favour is done to a character, and profiles are
-- shared between characters. AceDB keeps it inside the one saved file.
--
--   ledger.entries  oldest first; each one either
--     { kind = "received", name, class, spells = { id, ... }, at, times,
--       state = owed | returned | letgo, why, doneAt, gave, partyOnly }
--     { kind = "given", name, class, spell, at, to = group | stranger, asked }
--   ledger.totals   lifetime counts, never trimmed and kept by Clear
--   ledger.title    the highest of TITLES announced in chat, so none is twice
--   ledger.today    { day = local midnight, given, received, returned, useless }:
--                   today's counts, which the trim cannot touch and Clear resets
--   ledger.filter   the window's tab
--   ledger.window   where the window was dragged to
---------------------------------------------------------------------------

local store

-- `now` is the wall clock, nil when it cannot be read. A stamp past it was
-- written while the clock ran fast and has since been put right: it counts as
-- now, as a remembered favour's does (Queue.lua, RestoreDebts), or the row
-- counts as today's on every day until real time catches it up.
local function CleanEntry(e, now)
	if type(e) ~= "table" then return nil end
	local name, at = CleanName(e.name), CleanTime(e.at)
	if not name or not at then return nil end
	if now and at > now then at = now end
	local class = CleanClass(e.class)

	if e.kind == "given" then
		local out = { kind = "given", name = name, class = class, at = at,
			spell = CleanSpell(e.spell), to = e.to == "group" and "group" or "stranger",
			asked = e.asked == true or nil }
		-- How many one group cast reached, never more than a raid holds;
		-- nothing for a single cast.
		local covered = math.min(Count(e.covered), 40)
		if covered > 1 then out.covered = covered end
		return out
	elseif e.kind == "received" then
		local spells = {}
		if type(e.spells) == "table" then
			for i = 1, MAX_SPELLS do
				local id = CleanSpell(e.spells[i])
				if id then spells[#spells + 1] = id end
			end
		end
		-- A missing state is read as over: called owed, the row would promise
		-- an offer for somebody the prompt has never heard of.
		local state = STATES[e.state] and e.state or "letgo"
		local out = { kind = "received", name = name, class = class, at = at,
			spells = spells, times = math.max(1, Count(e.times)), state = state }
		if state == "owed" and e.partyOnly == true then out.partyOnly = true end
		if state ~= "owed" then
			-- Never settled before it happened, nor after now.
			local doneAt = CleanTime(e.doneAt)
			if doneAt and now and doneAt > now then doneAt = now end
			if doneAt and doneAt < at then doneAt = at end
			out.doneAt = doneAt
		end
		if state == "returned" then out.gave = CleanSpell(e.gave) end
		if state == "letgo" then out.why = WHY[e.why] and e.why or nil end
		return out
	end
	return nil
end

-- Oldest out first, but never a favour still owed: a settle that finds no row
-- makes one and counts the favour twice. Owed rows are bounded anyway, by how
-- many people can owe you at once.
local function Trim(s)
	local entries = s.entries
	local given = 0
	for i = 1, #entries do
		if entries[i].kind == "given" then given = given + 1 end
	end
	local i = 1
	while given > MAX_GIVEN and i <= #entries do
		if entries[i].kind == "given" then
			table.remove(entries, i)
			given = given - 1
		else
			i = i + 1
		end
	end
	i = 1
	while #entries > MAX_ENTRIES and i <= #entries do
		if entries[i].state == "owed" then
			i = i + 1
		else
			table.remove(entries, i)
		end
	end
end

-- Whatever is on disk, made into something every reader below can trust: an
-- old profile has nothing here, and a hand-edited or half-written file can
-- have anything. Rebuilt rather than patched, so no unknown key survives.
local function Repair(char)
	local s = char.ledger
	if type(s) ~= "table" then
		s = {}
		char.ledger = s
	end

	local kept, now = {}, Wall()
	if type(s.entries) == "table" then
		for i = 1, #s.entries do
			local e = CleanEntry(s.entries[i], now)
			if e then kept[#kept + 1] = e end
		end
	end
	-- Oldest first is what everything below assumes, and a damaged file need
	-- not be in any order. The index breaks ties so equal times keep theirs.
	for i, e in ipairs(kept) do e.order = i end
	table.sort(kept, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.order < b.order
	end)
	for _, e in ipairs(kept) do e.order = nil end
	s.entries = kept

	-- The counts never read lower than the list in front of them. A file that
	-- lost its totals but kept its rows would otherwise say "all time: 0" over
	-- a list of forty favours.
	local seen = { received = 0, returned = 0, letGo = 0, group = 0, strangers = 0 }
	for _, e in ipairs(kept) do
		if e.kind == "received" then
			seen.received = seen.received + 1
			if e.state == "returned" then seen.returned = seen.returned + 1 end
			if e.state == "letgo" then seen.letGo = seen.letGo + 1 end
		elseif e.to == "group" then
			seen.group = seen.group + 1
		else
			seen.strangers = seen.strangers + 1
		end
	end
	local old = type(s.totals) == "table" and s.totals or {}
	local totals = {}
	for _, key in ipairs(TOTALS) do
		totals[key] = math.max(Count(old[key]), seen[key])
	end
	s.totals = totals

	-- A ledger from before titles, or one whose mark is damaged, takes the
	-- title its count already earns without a word: a player with three hundred
	-- favours behind them is not greeted by five announcements at once. A mark
	-- above what the count earns is kept -- a late refusal can take back the
	-- favour that earned a title -- so no title is ever announced twice.
	local title = s.title
	if Whole(title) then
		s.title = math.min(title, #TITLES)
	else
		s.title = TitleLevel(totals.returned)
	end

	s.filter = FILTERS[s.filter] and s.filter or "all"

	-- Today's counts, kept apart from the list: see Summary. Kept only with a
	-- day that is a time and a count of gifts that is whole; any other count
	-- that is not a whole number reads as none.
	local today = s.today
	if type(today) == "table" and CleanTime(today.day) and Whole(today.given) then
		s.today = { day = today.day, given = today.given }
		for _, key in ipairs(TODAY) do
			s.today[key] = Whole(today[key]) and today[key] or 0
		end
	else
		s.today = nil
	end

	local w = s.window
	if type(w) == "table" and POINTS[w.point] and POINTS[w.relPoint]
		and type(w.x) == "number" and w.x == w.x and math.abs(w.x) < 10000
		and type(w.y) == "number" and w.y == w.y and math.abs(w.y) < 10000 then
		s.window = { point = w.point, relPoint = w.relPoint, x = w.x, y = w.y }
	else
		s.window = nil
	end

	Trim(s)
	store = s
	return s
end

local function Store()
	local char = ns.db and ns.db.char
	if type(char) ~= "table" then return nil end
	if store == nil or char.ledger ~= store then return Repair(char) end
	return store
end

local function Bump(s, key, by)
	s.totals[key] = math.max(0, (s.totals[key] or 0) + (by or 1))
end

-- A title the count has reached, and none before it has, gets its one line in
-- chat. Said whether or not chat lines are on, because it happens a handful of
-- times in a character's life.
local function Announce(s)
	local level = TitleLevel(s.totals.returned)
	if level <= (s.title or 0) then return end
	s.title = level
	local t = TITLES[level]
	if ns.addon and ns.addon.Print then ns.addon:Print(TEXT.EARNED:format(t.name, t.flavour)) end
end

-- When the latest favour that could earn a title was settled, while its
-- announcement waits; nil when none waits.
local promoteAt

-- The wait is over unless a later favour has moved it on, in which case that
-- favour gets its own full wait.
local function PromoteDue()
	local left = promoteAt and promoteAt + PROMOTE_SECONDS - GetTime()
	if left and left > 0 then
		C_Timer.After(left, function() ns.Guard("ledger title", PromoteDue) end)
		return
	end
	promoteAt = nil
	local s = Store()
	if s then Announce(s) end
end

-- After a favour returned. Core settles when the cast is sent and the server
-- can refuse it a moment later: a title said at once would stand in chat while
-- the window took it away. So the title waits out the refusal and is said
-- only if the count still holds it; with no timer to wait on, at once.
local function Promote(s)
	if TitleLevel(s.totals.returned) <= (s.title or 0) then return end
	if not (C_Timer and C_Timer.After) then return Announce(s) end
	local waiting = promoteAt ~= nil
	promoteAt = GetTime()
	if not waiting then
		C_Timer.After(PROMOTE_SECONDS, function() ns.Guard("ledger title", PromoteDue) end)
	end
end

-- Today's counts, counted apart from the list, which keeps only MAX_ENTRIES
-- rows and so cannot count a busy day to its end. Started afresh on a new day.
local function Today(s, now)
	local day = StartOfToday(now)
	if not (s.today and s.today.day == day) then
		s.today = { day = day, given = 0, received = 0, returned = 0, useless = 0 }
	end
	return s.today
end

-- One off today's `key` for a row dated `at`, while today is still the day it
-- was counted on: after midnight, or after Clear, it is not in the count.
local function Untoday(s, key, at)
	if s.today and s.today.day == StartOfToday(at) then
		s.today[key] = math.max(0, (s.today[key] or 0) - 1)
	end
end

local function Append(s, e)
	s.entries[#s.entries + 1] = e
	Trim(s)
end

local function Holds(s, e)
	for i = #s.entries, 1, -1 do
		if s.entries[i] == e then return true end
	end
	return false
end

local function Remove(s, e)
	for i = #s.entries, 1, -1 do
		if s.entries[i] == e then
			table.remove(s.entries, i)
			return true
		end
	end
	return false
end

-- The favour this person is still owed for, newest first. There is at most one
-- in practice: a second buff from somebody already owed is folded into it,
-- because the debt table keeps one debt per person and one buff back repays it.
local function FindOpen(s, name)
	for i = #s.entries, 1, -1 do
		local e = s.entries[i]
		if e.kind == "received" and e.state == "owed" and e.name == name then return e end
	end
	return nil
end

local function AddSpell(e, id)
	if not id then return end
	for _, have in ipairs(e.spells) do
		if have == id then return end
	end
	if #e.spells < MAX_SPELLS then e.spells[#e.spells + 1] = id end
end

---------------------------------------------------------------------------
-- repainting
---------------------------------------------------------------------------

local Render -- the window's, defined with it below

local function Changed()
	if Render then Render() end
	-- The General tab prints the same numbers, and AceConfig only asks for
	-- them while it is drawing. Repainted only while that tab is on screen,
	-- because a repaint rebuilds the whole page, controls the player may be
	-- using included. A tab nobody can name (a library without the status
	-- table) is always repainted.
	if ns.OptionsOpen and ns.OptionsOpen() and ns.RefreshOptionsDisplay then
		local tab = ns.OptionsTab and ns.OptionsTab()
		if tab == nil or tab == "general" then
			ns.Guard("options repaint", ns.RefreshOptionsDisplay)
		end
	end
end

---------------------------------------------------------------------------
-- what Core tells it
---------------------------------------------------------------------------

-- At login, after Core has put back the debts it kept. An owed row with no
-- debt behind it any more ran out while you were away, or was not kept (the
-- setting is off), and is let go so the row agrees with the prompt.
function Ledger.Load()
	local s = Store()
	local now = Wall()
	if not s or not now then return end
	local owed = ns.owed or {}
	local profile = ns.db and ns.db.profile
	local timing = profile and profile.timing
	local window = timing and type(timing.reciprocateWindow) == "number"
		and timing.reciprocateWindow or 120
	local notKept = timing and timing.keepDebts == false
	for _, e in ipairs(s.entries) do
		if e.kind == "received" and e.state == "owed" and not owed[e.name] then
			e.state = "letgo"
			e.why = notKept and "notkept" or "expired"
			e.doneAt = math.min(now, e.at + window)
			Bump(s, "letGo")
		end
	end
	Changed()
end

-- Somebody buffed you. `seen` is the record NoteFavour files: name, class and
-- the spell id under `key`. `useless` is a favour nothing this character casts
-- could return: recorded, and let go the moment it arrives. `partyOnly` is a
-- favour only a party-wide buff could return, which the row's tooltip says.
function Ledger.Received(seen, useless, partyOnly)
	local s, now = Store(), Wall()
	if not s or not now or type(seen) ~= "table" then return end
	local name = CleanName(seen.name)
	if not name then return end
	local spell = CleanSpell(seen.key)

	-- One favour per person while it is open, however many buffs it arrives
	-- as. A useless one folds only into another useless one from the same
	-- landing: it has no debt to be part of.
	local into
	if useless then
		local last = s.entries[#s.entries]
		if last and last.kind == "received" and last.name == name and last.why == "useless"
			and now - last.at <= FOLD_SECONDS then
			into = last
		end
	else
		into = FindOpen(s, name)
	end
	-- The newest buff's reading of partyOnly wins: it was read with the most
	-- to go on.
	partyOnly = (not useless and partyOnly == true) or nil
	if into then
		into.times = into.times + 1
		AddSpell(into, spell)
		into.class = into.class or CleanClass(seen.class)
		if not useless then into.partyOnly = partyOnly end
	else
		local e = { kind = "received", name = name, class = CleanClass(seen.class),
			spells = {}, at = now, times = 1, state = "owed", partyOnly = partyOnly }
		AddSpell(e, spell)
		if useless then
			e.state, e.why, e.doneAt = "letgo", "useless", now
			Bump(s, "letGo")
		end
		Append(s, e)
		Bump(s, "received")
		local today = Today(s, now)
		local key = useless and "useless" or "received"
		today[key] = today[key] + 1
	end
	Changed()
end

-- The spell that went out: the id the game reported where it would say, and
-- otherwise the rank this character knows of the buff that was armed.
local function GaveSpell(pending, spellId)
	local id = CleanSpell(spellId)
	if id then return id end
	-- A group cast went out as its own spell, whatever the client reported.
	local group = type(pending) == "table" and type(pending.group) == "table" and pending.group
	id = group and CleanSpell(group.spell)
	if id then return id end
	local key = type(pending) == "table" and pending.buffKey
	local class = ns.caps and ns.caps.class
	local buff = key and ns.FindBuff and ns.FindBuff(class, key)
	if not buff then return nil end
	local info = ns.BuffInfo and ns.BuffInfo(buff)
	return CleanSpell(info and info.topRank) or CleanSpell(buff.ranks and buff.ranks[1])
end

-- Settles kept for a refusal to take back. Session only: a refusal arrives a
-- moment after its settle or not at all.
local recent = {}

-- A press went out and Core settled it. `wasOwed` is the debt that stood before
-- the settle cleared it, nil for somebody who was simply missing the buff.
-- Stamped with GetTime(), which is the stamp Core's own record carries, so the
-- refusal can name this settle and no other.
function Ledger.Settled(name, wasOwed, pending, spellId)
	local s, now = Store(), Wall()
	name = CleanName(name)
	if not s or not now or not name then return end
	local clock = GetTime()
	for i = #recent, 1, -1 do
		if clock - recent[i].clock > UNDO_SECONDS then table.remove(recent, i) end
	end

	local gave = GaveSpell(pending, spellId)
	local undo = { name = name, clock = clock }
	local today = Today(s, now)
	if wasOwed then
		local e = FindOpen(s, name)
		if not e then
			-- A debt the ledger never saw (kept from before the ledger
			-- existed): a favour received all the same, dated from the debt.
			local at = now
			if type(wasOwed) == "table" and type(wasOwed.at) == "number" then
				at = now - math.max(0, clock - wasOwed.at)
			end
			e = { kind = "received", name = name, spells = {}, at = at, times = 1, state = "owed",
				class = CleanClass(type(wasOwed) == "table" and wasOwed.class or nil) }
			Append(s, e)
			Bump(s, "received")
			if StartOfToday(at) == today.day then today.received = today.received + 1 end
			undo.created = true
		end
		e.state, e.doneAt, e.gave = "returned", now, gave
		Bump(s, "returned")
		Promote(s)
		-- Today's headline scores the favours received today, so a return
		-- counts for today only when the favour does.
		if StartOfToday(e.at) == today.day then today.returned = today.returned + 1 end
		undo.entry = e
	else
		local to = type(pending) == "table" and pending.inGroup == true and "group" or "stranger"
		local group = type(pending) == "table" and type(pending.group) == "table" and pending.group
		-- A buff somebody asked for in chat is listed, but it was not given
		-- unprompted, which is what today's count of gifts says. A group cast
		-- only when everybody it covered asked (GroupBuffs.lua): aimed at an
		-- asker, it still reached the rest of the party unprompted.
		local asked = type(pending) == "table" and pending.reason == "asked"
			and (not group or group.asked == true)
		local e = { kind = "given", name = name, at = now, spell = gave, to = to, asked = asked or nil,
			class = CleanClass(type(pending) == "table" and pending.class or nil) }
		-- One cast that covered a party is one buff given, counted once like
		-- any cast, and the row says how many it reached.
		if group and type(group.members) == "table" and #group.members > 0 then
			e.covered = #group.members + 1
		end
		Append(s, e)
		Bump(s, to == "group" and "group" or "strangers")
		if not asked then today.given = today.given + 1 end
		undo.entry, undo.to = e, to
	end
	recent[#recent + 1] = undo
	Changed()
end

-- The server refused, after the fact, the cast a settle above was about. Core
-- has put the debt back; this puts the row back the way it was. `clock` is the
-- stamp on Core's record of the settle, which is the stamp on this one.
function Ledger.Refused(name, clock)
	local s = Store()
	if not s then return end
	local undo
	for i = #recent, 1, -1 do
		if recent[i].name == name and recent[i].clock == clock then
			undo = table.remove(recent, i)
			break
		end
	end
	if not undo then return end
	-- The row the settle wrote may be gone: Clear can be pressed between a
	-- settle and its refusal. The counts, which Clear keeps, are taken back all
	-- the same, and a favour Core has just put back gets its owed row back, or
	-- the next return would make a row and count the favour twice.
	local e = undo.entry
	if undo.to then
		Remove(s, e)
		Bump(s, undo.to == "group" and "group" or "strangers", -1)
		-- Today's count too, which never had a buff somebody asked for.
		if not e.asked then Untoday(s, "given", e.at) end
	else
		Bump(s, "returned", -1)
		Untoday(s, "returned", e.at)
		if undo.created then
			Remove(s, e)
			Bump(s, "received", -1)
			Untoday(s, "received", e.at)
		else
			-- Somebody who buffed you again before the refusal arrived already
			-- has an owed row, and Core keeps one debt per person, so the two
			-- are folded into one favour, counted once. Today's count gives
			-- back the later of the two, which it holds even when the other
			-- was yesterday's.
			local open = FindOpen(s, e.name)
			if open and open ~= e then
				Untoday(s, "received", math.max(open.at, e.at))
				open.times = open.times + e.times
				for _, id in ipairs(e.spells) do AddSpell(open, id) end
				open.at = math.min(open.at, e.at)
				open.class = open.class or e.class
				Remove(s, e)
				Bump(s, "received", -1)
			else
				e.state, e.doneAt, e.gave = "owed", nil, nil
				if not Holds(s, e) then Append(s, e) end
			end
		end
	end
	Changed()
end

-- The debt was let go before it was returned. `why` is one of WHY; "never" is
-- the never-offer list, which must not read as time running out. No reason is
-- the expiry sweep's case, the time ran out.
function Ledger.LetGo(name, why)
	local s, now = Store(), Wall()
	name = CleanName(name)
	if not s or not now or not name then return end
	local e = FindOpen(s, name)
	if not e then return end
	why = WHY[why] and why or "expired"
	e.state, e.why, e.doneAt = "letgo", why, now
	Bump(s, "letGo")
	Changed()
end

-- Everything but the favours still owed, and today's count of buffs given with
-- the list, as the button's tooltip says. Those favours stay because each debt
-- is still live on the prompt, and a settle that found no row would count the
-- favour twice. The settles kept for a refusal stay too: a refusal can still
-- arrive for a row that is gone, and Refused copes with that.
function Ledger.Clear()
	local s = Store()
	if not s then return end
	local kept = {}
	for _, e in ipairs(s.entries) do
		if e.kind == "received" and e.state == "owed" then kept[#kept + 1] = e end
	end
	s.entries = kept
	s.today = nil
	Changed()
end

-- Whether Clear would take anything, on any tab: a row other than a favour
-- still owed, or a count of buffs given today. The window hides Clear when not.
function Ledger.Clearable()
	local s = Store()
	if not s then return false end
	for _, e in ipairs(s.entries) do
		if not (e.kind == "received" and e.state == "owed") then return true end
	end
	return s.today ~= nil and (s.today.given or 0) > 0
end

---------------------------------------------------------------------------
-- reading it back
---------------------------------------------------------------------------

-- Newest first, for one of the window's tabs.
function Ledger.Entries(filter)
	local s = Store()
	local out = {}
	if not s then return out end
	for i = #s.entries, 1, -1 do
		local e = s.entries[i]
		if filter == "favours" then
			if e.kind == "received" then out[#out + 1] = e end
		elseif filter == "given" then
			if e.kind == "given" then out[#out + 1] = e end
		else
			out[#out + 1] = e
		end
	end
	return out
end

-- Why nothing new can reach the list now, or nil: "off" (addon switched off),
-- "nothing" (nothing to cast), "owedoff" (favours not watched for). The same
-- gates NoteFavour and the prompt pass, so the window never promises a row
-- that cannot come; asked, never stored, since each can change under it.
local function Quiet()
	local p = ns.db and ns.db.profile
	if type(p) ~= "table" then return nil end
	if not p.enabled then return "off" end
	local ok, nothing = pcall(function()
		if #ns.CastableBuffs() == 0 then return true end
		local pinned = ns.PinnedBuff()
		return pinned ~= nil and not ns.IsBuffKnown(pinned)
	end)
	if ok and nothing then return "nothing" end
	if type(p.sources) == "table" and not p.sources.owed then return "owedoff" end
	return nil
end

-- Today's numbers from the list and today's counts, the lifetime ones from the
-- totals. A favour nothing you cast could return is counted apart from the
-- rest, `useless`, and left out of `received`, which is what the headline
-- scores you against. A buff somebody asked for is not in `given`.
function Ledger.Summary()
	local s, now = Store(), Wall()
	local out = { received = 0, returned = 0, useless = 0, given = 0, owed = 0,
		totals = { received = 0, returned = 0, letGo = 0, group = 0, strangers = 0 } }
	if not s or not now then return out end
	local today = StartOfToday(now)
	for _, e in ipairs(s.entries) do
		if e.kind == "received" and e.state == "owed" then out.owed = out.owed + 1 end
		if e.at >= today then
			if e.kind == "received" and e.why == "useless" then
				out.useless = out.useless + 1
			elseif e.kind == "received" then
				out.received = out.received + 1
				if e.state == "returned" then out.returned = out.returned + 1 end
			elseif not e.asked then
				out.given = out.given + 1
			end
		end
	end
	-- The list keeps only so many rows, so on a busy day the counts kept apart
	-- from it are the right ones. The larger of the two, because a list saved
	-- before those counts existed has rows they never saw.
	if s.today and s.today.day == today then
		out.given = math.max(out.given, s.today.given)
		for _, key in ipairs(TODAY) do out[key] = math.max(out[key], s.today[key] or 0) end
	end
	for _, key in ipairs(TOTALS) do out.totals[key] = s.totals[key] or 0 end
	return out
end

function Ledger.Headline(sum)
	sum = sum or Ledger.Summary()
	if sum.received == 0 then
		return (sum.useless or 0) > 0 and TEXT.TODAY_ONLY_USELESS or TEXT.TODAY_NONE
	end
	if sum.received == 1 then return TEXT.TODAY_ONE:format(sum.returned) end
	return TEXT.TODAY_MANY:format(sum.returned, sum.received)
end

function Ledger.Lifetime(sum)
	local t = (sum or Ledger.Summary()).totals
	return TEXT.LIFETIME:format(t.received, t.returned, t.group, t.strangers)
end

-- Where the favours returned stand among TITLES, worked out from the count and
-- nothing else: the title held (nil for none yet), the next (nil past the
-- last), the count, and the count the title held began at.
function Ledger.Rank(sum)
	local returned = Count((sum or Ledger.Summary()).totals.returned)
	local level = TitleLevel(returned)
	return { level = level, title = TITLES[level], next = TITLES[level + 1], returned = returned,
		from = level > 0 and TITLES[level].at or 0 }
end

-- The minimap tooltip's line: the title and the way to the next, one sentence.
function Ledger.RankText(sum)
	local rank = Ledger.Rank(sum)
	if not rank.title then
		return TEXT.BROKER_FIRST:format(rank.returned, rank.next.at, rank.next.name)
	elseif not rank.next then
		return TEXT.BROKER_TOP:format(rank.title.name)
	end
	return TEXT.BROKER_TITLED:format(rank.title.name, rank.returned, rank.next.at, rank.next.name)
end

-- The line under the headline: what is still owed and what was given today,
-- each its own sentence, or nothing.
local function Subline(sum)
	local owed = sum.owed == 1 and TEXT.OWED_ONE
		or sum.owed > 1 and TEXT.OWED_MANY:format(sum.owed) or nil
	local gave = sum.given == 1 and TEXT.GAVE_ONE
		or sum.given > 1 and TEXT.GAVE_MANY:format(sum.given) or nil
	if owed and gave then return owed .. "  " .. gave end
	return owed or gave or ""
end

-- For the General tab: the headline and the lifetime counts, or one line saying
-- there is nothing yet.
function Ledger.OptionsText()
	local sum = Ledger.Summary()
	local t = sum.totals
	if t.received == 0 and t.group == 0 and t.strangers == 0 and #Ledger.Entries("all") == 0 then
		return TEXT.OPTIONS_EMPTY
	end
	return Ledger.Headline(sum) .. "\n" .. Ledger.Lifetime(sum)
end

-- For the minimap button's tooltip. AddLine only: every broker display offers
-- that, and not every one offers anything else. Left out on a character that
-- is recording nothing and never has (a rogue gets no line of zeros); kept for
-- one with a history, switched off or not, because those numbers are theirs.
function Ledger.AddTooltip(tooltip)
	if not (tooltip and tooltip.AddLine) or not Store() then return end
	local sum = Ledger.Summary()
	local quiet = Quiet()
	if (quiet == "off" or quiet == "nothing") and #Ledger.Entries("all") == 0 then
		local t = sum.totals
		if t.received == 0 and t.group == 0 and t.strangers == 0 then return end
	end
	tooltip:AddLine(Ledger.Headline(sum), 1, 0.82, 0)
	tooltip:AddLine(Ledger.Lifetime(sum), 0.62, 0.62, 0.62, true)
	tooltip:AddLine(Ledger.RankText(sum), RANK_INK[1], RANK_INK[2], RANK_INK[3], true)
end

---------------------------------------------------------------------------
-- the window
--
-- Drawn from the same single white texture the prompt is, for the same reason:
-- an atlas or art file this client lacks renders as a green square, and a solid
-- texture cannot fail. The look follows the prompt's glass panel -- a two-step
-- shadow, a dark translucent body, a hairline of light -- with its accent
-- colour under the title, so the two read as one addon.
---------------------------------------------------------------------------

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LOGO = "Interface\\AddOns\\Manners\\Textures\\Manners64"

-- Top to bottom: the title band, the title your manners have earned over a bar
-- of the way to the next, today's headline and up to two lines under it, the
-- all-time numbers as four tiles, the tabs, seven rows, and a footer with the
-- position in the list and Clear. Seven rows so the window fits a small UI
-- scale, where the screen is under eight hundred units tall.
--
-- Every string here is hung by two points on the same edge -- TOPLEFT and
-- TOPRIGHT, never TOPLEFT and RIGHT: whether this client sizes such a string
-- from its text or from the points is unverified, and two points on one edge
-- place it the same either way. tests/scenarios/ledgerui.lua keeps it so, and
-- tools/render_ledger.py draws the other reading so a lapse shows.
local WIDTH, HEIGHT = 360, 480
local PAD = 12
local ROWS = 7
local ROW_HEIGHT = 34
local RANK_TOP = -37
local RANK_HEIGHT = 20
local HEADLINE_TOP = -66
local SUBLINE_TOP = -86
local STATS_TOP = -132
local STAT_HEIGHT = 32
local TABS_TOP = -174
local TAB_HEIGHT = 22
local LIST_TOP = -204
-- The widest the way to the next title grows, so a long translation of it
-- leaves the title itself room.
local RANK_PROGRESS_MAX = 200
local FOOTER = 34
-- Where the text of a row starts, clear of its stripe and icon.
local ROW_TEXT_X = 40
-- The widest a state badge's plate grows: a long translation of its word is cut
-- inside it rather than leaving no room for what follows.
local BADGE_MAX = 120
local DEFAULT_POINT, DEFAULT_X, DEFAULT_Y = "LEFT", 40, 40
local CLEAR_SECONDS = 3
-- How often an open window redraws for "5 min ago" to become "6 min ago".
local TICK_SECONDS = 15

-- Each state's colour, taken from the prompt so a colour means the same thing
-- in both places: amber for a favour owed, group blue, and a stranger's slate
-- a step lighter so it reads on the dark rows. Returned is green, which the
-- prompt never uses; let go is grey on a dimmed row, apart from the slate.
local COLOUR = {
	owed = { 1.00, 0.78, 0.30 },
	returned = { 0.40, 0.86, 0.50 },
	letgo = { 0.56, 0.56, 0.58 },
	group = { 0.34, 0.60, 0.96 },
	stranger = { 0.64, 0.68, 0.82 },
}
-- The text colours the window uses over and over: the body, the quieter
-- second voice, and the quietest, for captions.
local INK = { 0.92, 0.92, 0.94 }
local INK_SOFT = { 0.70, 0.70, 0.73 }
local INK_FAINT = { 0.55, 0.55, 0.58 }
-- Clear, armed: the one colour on the window that means "careful".
local DANGER = { 1.00, 0.45, 0.35 }

local window, rows, offset, filter, lastTop, tickAt, clearArmedUntil

local function Font()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	local p = ns.db and ns.db.profile and ns.db.profile.prompt
	local path = LSM and p and LSM:Fetch("font", p.font, true)
	return path or STANDARD_TEXT_FONT
end

-- A font file the client cannot load leaves the string with no font, and the
-- first SetText on it throws; the game's own font always loads.
local function SafeFont(fs, path, size, flags)
	if not fs:SetFont(path, size, flags) or (fs.GetFont and not fs:GetFont()) then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

local function Solid(parent, layer, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(WHITE)
	return t
end

-- One line, cut with an ellipsis where it meets the edge it is hung to, in a
-- colour said out loud: a font string made without a template has whatever
-- colour the client defaults to, and the window should not depend on that.
local function Text(parent, size, colour, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	SafeFont(fs, Font(), size, "")
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	fs:SetShadowColor(0, 0, 0, 0.9)
	fs:SetShadowOffset(1, -1)
	colour = colour or INK
	fs:SetTextColor(colour[1], colour[2], colour[3])
	fs.size = size
	return fs
end

-- Up to `lines` lines, wrapped at the width the string is hung to.
local function Wrap(fs, lines)
	fs:SetWordWrap(true)
	if fs.SetMaxLines then fs:SetMaxLines(lines) end
end

-- How wide a string's text is. The unbounded width where the client has it,
-- because GetStringWidth answers no wider than a width the string was given;
-- with neither (the test client), half an em a byte, which errs wide for any
-- language.
local function TextWidth(fs)
	local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
	if measure then
		local ok, w = pcall(measure, fs)
		if ok and type(w) == "number" and not Secret(w) and w == w then return w end
	end
	local text = tostring(fs.GetText and fs:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return #text * (fs.size or 12) * 0.5
end

local function Accent()
	local c = ns.db and ns.db.profile and ns.db.profile.prompt and ns.db.profile.prompt.accentColor
	if type(c) == "table" and type(c[1]) == "number" then return c end
	return { 0.45, 0.4, 0.9, 1 }
end

local function FlatEnter(self)
	self.plate:SetVertexColor(1, 1, 1, self.selected and 0.2 or self.rest + 0.07)
	if self.tip then
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(self.tip, 1, 1, 1, true)
		GameTooltip:Show()
	end
end

local function FlatLeave(self)
	self.plate:SetVertexColor(1, 1, 1, self.selected and 0.16 or self.rest)
	if self.tip then GameTooltip:Hide() end
end

-- A flat button: a faint plate that brightens under the mouse, and a label
-- hung across its whole width, inset, so a long translation is cut with an
-- ellipsis inside the button rather than spilling out of it.
local function FlatButton(parent, label, width, height, rest)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, height)
	b.rest = rest or 0.06
	b.plate = Solid(b, "BACKGROUND")
	b.plate:SetAllPoints()
	b.plate:SetVertexColor(1, 1, 1, b.rest)
	b.label = Text(b, 11, INK)
	b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.label:SetJustifyH("CENTER")
	b.label:SetText(label)
	b:SetScript("OnEnter", FlatEnter)
	b:SetScript("OnLeave", FlatLeave)
	return b
end

-- The width a button needs for the longest of its labels, between a floor
-- that keeps short words from making a button a sliver and a ceiling that
-- keeps a long translation from pushing its neighbours off the window.
local function FitWidth(fs, texts, floor, ceiling)
	local was, widest = fs:GetText(), 0
	for _, text in ipairs(texts) do
		fs:SetText(text)
		widest = math.max(widest, TextWidth(fs))
	end
	fs:SetText(was)
	return math.min(ceiling, math.max(floor, math.ceil(widest) + 20))
end

local function SavePosition()
	local s = Store()
	if not (s and window) then return end
	local point, _, relPoint, x, y = window:GetPoint()
	if POINTS[point] and POINTS[relPoint] and type(x) == "number" and type(y) == "number" then
		s.window = { point = point, relPoint = relPoint, x = x, y = y }
	end
end

local function Place()
	local s = Store()
	local w = s and s.window
	window:ClearAllPoints()
	if w then
		window:SetPoint(w.point, UIParent, w.relPoint, w.x, w.y)
	else
		-- Off to the left rather than centred: at a small UI scale a centred
		-- window this tall covers the prompt's default spot at the bottom
		-- centre, in a higher strata, taking its clicks.
		window:SetPoint(DEFAULT_POINT, UIParent, DEFAULT_POINT, DEFAULT_X, DEFAULT_Y)
	end
end

-- A row's badge, the words after it, and its colour. The badge is drawn as a
-- tinted plate of its own, so the two are handed back apart.
local function Detail(e)
	if e.kind == "given" then
		local spell = SpellName(e.spell) or TEXT.UNKNOWN_SPELL
		local colour = e.to == "group" and COLOUR.group or COLOUR.stranger
		local rest = (e.to == "group" and TEXT.GAVE_GROUP or TEXT.GAVE_STRANGER):format(spell)
		if e.covered then rest = TEXT.GAVE_COVERED:format(spell, e.covered) end
		return TEXT.STATE_GAVE, rest, colour
	end
	local theirs = {}
	for _, id in ipairs(e.spells) do theirs[#theirs + 1] = SpellName(id) or TEXT.UNKNOWN_SPELL end
	local spells = #theirs > 0 and table.concat(theirs, ", ") or TEXT.UNKNOWN_SPELL
	if e.state == "owed" then
		return TEXT.STATE_OWED, spells, COLOUR.owed
	elseif e.state == "returned" then
		local gave = SpellName(e.gave)
		return TEXT.STATE_RETURNED, gave and TEXT.RETURNED_WITH:format(gave) or "", COLOUR.returned
	end
	local why = e.why == "useless" and TEXT.LETGO_USELESS
		or e.why == "notkept" and TEXT.LETGO_NOTKEPT
		or e.why == "never" and TEXT.LETGO_NEVER or TEXT.LETGO_EXPIRED
	return TEXT.STATE_LETGO, why, COLOUR.letgo
end

-- Which "only your group" a party-only favour's lines name, by what this
-- character casts now: SUBGROUP for a vanilla shout in a raid
-- (ns.GroupMeansSubgroup, as the favour's chat line and Who to buff ask it),
-- GROUP for Salvation, which reaches the whole raid, else PARTY.
local function OnlyGroup()
	if ns.GroupMeansSubgroup() then return "SUBGROUP" end
	for _, buff in ipairs(ns.CastableBuffs()) do
		if buff.groupOnly and not buff.partyOnly then return "GROUP" end
	end
	return "PARTY"
end

-- What an owed row says in place of "the prompt offers them" while the prompt
-- cannot, or nil. Asked when hovered, like Quiet(), each check through pcall
-- so a throw costs the caveat and not the tooltip. A snooze or a mount holds
-- the offer back for a while; a party-only favour also waits on the giver
-- being in your party, and its lines say both. A PvP flag comes first, as in
-- the favour's chat line: it is the one that most often outlasts the favour.
local function OwedHeldBack(e)
	local ok, quiet = pcall(Quiet)
	quiet = ok and quiet or nil
	if quiet == "off" then return TEXT.TIP_OWED_OFF end
	if quiet == "owedoff" then return TEXT.TIP_OWED_SOURCE_OFF end
	if quiet == "nothing" then return TEXT.TIP_OWED_NOTHING end
	-- The flag last read, kept on the debt, as the owed fallback reads it.
	local okPvP, flagged = pcall(function()
		local debt = ns.owed and ns.owed[e.name]
		return debt ~= nil and ns.PvPHoldsBack(debt.pvp)
	end)
	if okPvP and flagged == true then return TEXT.TIP_OWED_PVP end
	local snoozeLine, mountLine = TEXT.TIP_OWED_SNOOZED, TEXT.TIP_OWED_MOUNTED
	if e.partyOnly then
		local reach = OnlyGroup()
		snoozeLine, mountLine = TEXT["TIP_OWED_SNOOZED_" .. reach], TEXT["TIP_OWED_MOUNTED_" .. reach]
	end
	local snoozed, ends = pcall(function()
		return ns.SnoozeLeft and ns.SnoozeLeft() and ns.SnoozeEndsAt()
	end)
	if snoozed and type(ends) == "string" then return snoozeLine:format(ends) end
	local okMounted, mounted = pcall(function()
		return ns.HiddenWhileMounted and ns.HiddenWhileMounted()
	end)
	if okMounted and mounted == true then return mountLine end
	return nil
end

local function RowTooltip(row)
	local e = row.entry
	if not e then return end
	local now = Wall() or e.at
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Coloured(e.name, e.class))
	if e.kind == "given" then
		GameTooltip:AddLine(TEXT.TIP_GAVE:format(SpellName(e.spell) or TEXT.UNKNOWN_SPELL,
			Ledger.Ago(now - e.at)), 1, 1, 1, true)
		GameTooltip:AddLine(e.to == "group" and TEXT.TIP_GAVE_GROUP or TEXT.TIP_GAVE_STRANGER,
			0.7, 0.7, 0.7, true)
		if e.asked then GameTooltip:AddLine(TEXT.TIP_GAVE_ASKED, 0.7, 0.7, 0.7, true) end
		if e.covered then GameTooltip:AddLine(TEXT.TIP_GAVE_COVERED:format(e.covered), 0.7, 0.7, 0.7, true) end
	else
		local theirs = {}
		for _, id in ipairs(e.spells) do theirs[#theirs + 1] = SpellName(id) or TEXT.UNKNOWN_SPELL end
		GameTooltip:AddLine(TEXT.TIP_BUFFED:format(#theirs > 0 and table.concat(theirs, ", ")
			or TEXT.UNKNOWN_SPELL, Ledger.Ago(now - e.at)), 1, 1, 1, true)
		if e.times > 1 then GameTooltip:AddLine(TEXT.TIP_TIMES:format(e.times), 0.7, 0.7, 0.7, true) end
		local c = COLOUR[e.state] or COLOUR.letgo
		if e.state == "owed" then
			local line = OwedHeldBack(e)
				or not e.partyOnly and TEXT.TIP_OWED
				or TEXT["TIP_OWED_" .. OnlyGroup()]
			GameTooltip:AddLine(line, c[1], c[2], c[3], true)
		elseif e.state == "returned" then
			local took = Duration((e.doneAt or e.at) - e.at)
			local gave = SpellName(e.gave)
			GameTooltip:AddLine(gave and TEXT.TIP_RETURNED_WITH:format(took, gave)
				or TEXT.TIP_RETURNED:format(took), c[1], c[2], c[3], true)
		else
			GameTooltip:AddLine(e.why == "useless" and TEXT.TIP_LETGO_USELESS
				or e.why == "notkept" and TEXT.TIP_LETGO_NOTKEPT
				or e.why == "never" and TEXT.TIP_LETGO_NEVER or TEXT.TIP_LETGO_EXPIRED,
				c[1], c[2], c[3], true)
		end
	end
	GameTooltip:Show()
end

local function BuildRow(i)
	local row = CreateFrame("Button", nil, window)
	local y = LIST_TOP - (i - 1) * ROW_HEIGHT
	row:SetHeight(ROW_HEIGHT - 2)
	row:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
	row:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD - 8, y)

	-- Alternate rows a shade apart, so the eye can follow one across.
	row.back = Solid(row, "BACKGROUND")
	row.back:SetAllPoints()
	row.back:SetVertexColor(1, 1, 1, i % 2 == 1 and 0.035 or 0.015)

	row.stripe = Solid(row, "BORDER")
	row.stripe:SetWidth(2)
	row.stripe:SetPoint("TOPLEFT")
	row.stripe:SetPoint("BOTTOMLEFT")

	row.iconBack = Solid(row, "BORDER")
	row.iconBack:SetSize(26, 26)
	row.iconBack:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.iconBack:SetVertexColor(0, 0, 0, 0.85)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(24, 24)
	row.icon:SetPoint("CENTER", row.iconBack, "CENTER")
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.when = Text(row, 10, INK_FAINT)
	row.when:SetJustifyH("RIGHT")
	row.when:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)

	row.name = Text(row, 12)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_TEXT_X, -3)
	row.name:SetPoint("TOPRIGHT", row.when, "TOPLEFT", -8, 1)

	row.badgePlate = Solid(row, "BORDER", 1)
	row.badgePlate:SetHeight(13)
	row.badgePlate:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", ROW_TEXT_X, 3)
	row.badge = Text(row, 10)
	row.badge:SetPoint("CENTER", row.badgePlate, "CENTER", 0, 0)
	row.badge:SetJustifyH("CENTER")

	row.detail = Text(row, 11, INK_SOFT)
	row.detail:SetPoint("BOTTOMLEFT", row.badgePlate, "BOTTOMRIGHT", 6, 1)
	row.detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 4)

	-- A wash of the row's colour when something new arrives at the top, so the
	-- entry that just happened is the one the eye lands on.
	row.flash = Solid(row, "ARTWORK", 1)
	row.flash:SetAllPoints()
	row.flash:SetBlendMode("ADD")
	row.flash:SetAlpha(0)
	row.flashAnim = row.flash:CreateAnimationGroup()
	local fade = row.flashAnim:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.35)
	fade:SetToAlpha(0)
	fade:SetDuration(1.2)
	fade:SetSmoothing("OUT")

	row:SetHighlightTexture(WHITE, "ADD")
	local hl = row:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.05) end
	row:SetScript("OnEnter", RowTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- The wheel over a row scrolls the list. Asked for on the row itself, not
	-- left to reach the window, so it works over the rows and not only in the
	-- seams between them.
	row:EnableMouseWheel(true)
	row:SetScript("OnMouseWheel", function(_, delta) Ledger.Scroll(-(delta or 0)) end)
	row:Hide()
	return row
end

local function Paint(row, e, now)
	row.entry = e
	-- Not `a and b or c`: a gift's `spell` can be nil, and the `or` would then
	-- read a favour's spell list on a row that has none.
	local id
	if e.kind == "given" then id = e.spell else id = e.spells[1] end
	row.icon:SetTexture(SpellIcon(id))
	row.name:SetText(Coloured(e.name, e.class))
	row.when:SetText(Ledger.Ago(now - e.at))
	local badge, detail, colour = Detail(e)
	row.badge:SetText(badge)
	row.badge:SetTextColor(colour[1], colour[2], colour[3])
	local plate = math.min(BADGE_MAX, math.ceil(TextWidth(row.badge)) + 10)
	row.badgePlate:SetWidth(plate)
	row.badge:SetWidth(plate - 6)
	row.badgePlate:SetVertexColor(colour[1], colour[2], colour[3], 0.16)
	row.detail:SetText(detail)
	row.stripe:SetVertexColor(colour[1], colour[2], colour[3], 0.9)
	row.flash:SetVertexColor(colour[1], colour[2], colour[3], 1)
	-- Let go is over and done with: dimmed, so what still needs doing and what
	-- went well stand out from it.
	row:SetAlpha(e.kind == "received" and e.state == "letgo" and 0.62 or 1)
	row:Show()
end

local function SetFilter(key)
	filter = FILTERS[key] and key or "all"
	local s = Store()
	if s then s.filter = filter end
	-- A different tab has a different entry on top, and that is not something
	-- having just happened.
	offset, lastTop = 0, nil
	for _, tab in ipairs(window.tabs) do
		tab.selected = tab.key == filter
		tab.plate:SetVertexColor(1, 1, 1, tab.selected and 0.16 or tab.rest)
		tab.underline:SetShown(tab.selected)
		local c = tab.selected and INK or INK_SOFT
		tab.label:SetTextColor(c[1], c[2], c[3])
	end
end

local function DisarmClear()
	clearArmedUntil = nil
	if window then
		window.clear.label:SetText(TEXT.CLEAR)
		window.clear.label:SetTextColor(INK[1], INK[2], INK[3])
	end
end

-- The first press of Clear arms it (the label asks again, in the colour that
-- means careful); a second press within a few seconds empties the list. Two
-- presses rather than a dialog, which is more ceremony than the loss deserves.
local function ClearClicked(self)
	if clearArmedUntil and GetTime() <= clearArmedUntil then
		DisarmClear()
		Ledger.Clear()
	else
		clearArmedUntil = GetTime() + CLEAR_SECONDS
		self.label:SetText(TEXT.CLEAR_ARMED)
		self.label:SetTextColor(DANGER[1], DANGER[2], DANGER[3])
	end
end

-- What an empty tab says: how a row would come to be there, or, while none can,
-- why not. The owed toggle stops favours and nothing else, so the tab of buffs
-- given keeps its ordinary line under it.
local function EmptyText(key)
	local quiet = Quiet()
	if quiet == "off" then return TEXT.EMPTY_OFF end
	if quiet == "nothing" then return TEXT.EMPTY_NOTHING end
	if key == "given" then return TEXT.EMPTY_GIVEN end
	if quiet == "owedoff" then return TEXT.EMPTY_OWED_OFF end
	return key == "favours" and TEXT.EMPTY_FAVOURS or TEXT.EMPTY_ALL
end

local function PaintRank(sum)
	local rank = Ledger.Rank(sum)
	local r = window.rank
	r.name:SetText(rank.title and rank.title.name or TEXT.UNTITLED)
	local c = rank.title and RANK_INK or INK_FAINT
	r.name:SetTextColor(c[1], c[2], c[3])
	r.progress:SetText(rank.next and TEXT.RANK_PROGRESS:format(rank.returned, rank.next.at, rank.next.name)
		or TEXT.RANK_TOP)
	r.progress:SetWidth(math.min(RANK_PROGRESS_MAX, math.ceil(TextWidth(r.progress)) + 2))
	local share = 1
	if rank.next then
		share = (rank.returned - rank.from) / (rank.next.at - rank.from)
	end
	share = math.min(1, math.max(0, share))
	-- A texture cannot be drawn no wide, so an empty bar is a hidden one.
	r.fill:SetShown(share > 0)
	r.fill:SetWidth(math.max(1, (WIDTH - 2 * PAD) * share))
	r.standing = rank
end

function Render()
	if not (window and window:IsShown()) then return end
	local now = Wall()
	if not now then return end
	local list = Ledger.Entries(filter)
	local sum = Ledger.Summary()

	PaintRank(sum)
	window.headline:SetText(Ledger.Headline(sum))
	window.subline:SetText(Subline(sum))
	for _, stat in ipairs(window.stats) do
		stat.value:SetText(tostring(sum.totals[stat.key] or 0))
	end

	local maxOffset = math.max(0, #list - ROWS)
	offset = math.min(math.max(0, offset or 0), maxOffset)
	window.showing:SetShown(#list > 0)
	window.showing:SetText(TEXT.SHOWING:format(offset + 1, math.min(#list, offset + ROWS), #list))
	for i = 1, ROWS do
		local e = list[offset + i]
		if e then Paint(rows[i], e, now) else
			rows[i].entry = nil
			rows[i]:Hide()
		end
	end

	-- The empty list: the addon's mark, faded, over what would put a row here,
	-- or -- in a warmer colour, because it is something the player can change
	-- -- why nothing can.
	window.empty:SetShown(#list == 0)
	window.emptyIcon:SetShown(#list == 0)
	local text = EmptyText(filter)
	window.empty:SetText(text)
	local ordinary = text == TEXT.EMPTY_ALL or text == TEXT.EMPTY_FAVOURS or text == TEXT.EMPTY_GIVEN
	local c = ordinary and INK_SOFT or COLOUR.owed
	window.empty:SetTextColor(c[1], c[2], c[3])

	-- Clear only while there is something for it to take, and put back to its
	-- first press when it goes, so it never comes back already armed.
	local clearable = Ledger.Clearable()
	if not clearable and clearArmedUntil then DisarmClear() end
	window.clear:SetShown(clearable)

	local scrolls = #list > ROWS
	window.track:SetShown(scrolls)
	window.thumb:SetShown(scrolls)
	if scrolls then
		local trackHeight = ROWS * ROW_HEIGHT - 2
		local thumbHeight = math.max(18, trackHeight * ROWS / #list)
		local y = (trackHeight - thumbHeight) * offset / maxOffset
		window.thumb:SetHeight(thumbHeight)
		window.thumb:ClearAllPoints()
		window.thumb:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD + 2, LIST_TOP - y)
	end

	local top = list[1]
	if top and lastTop ~= nil and top ~= lastTop and offset == 0 then
		rows[1].flashAnim:Stop()
		rows[1].flashAnim:Play()
	end
	lastTop = top or false
end

-- Rows, not pixels: one notch of the wheel moves the list by one entry.
function Ledger.Scroll(delta)
	offset = (offset or 0) + (delta or 0)
	Render()
end

-- The pieces of the window, each built by a file-level function of its own:
-- Lua 5.1 lets one function capture at most sixty upvalues, closures inside it
-- included, and Build doing all of this itself would come close.

local function CloseClicked()
	if window then window:Hide() end
end

local function TabClicked(self)
	SetFilter(self.key)
	Render()
end

-- The title band's contents, and today's summary under it: the headline in
-- the prompt's gold, and the line of what is owed and given, allowed a second
-- line because in German and Russian its two sentences do not share one.
local function BuildHeader()
	local logo = window:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(LOGO)
	logo:SetSize(18, 18)
	logo:SetPoint("TOPLEFT", window, "TOPLEFT", PAD - 2, -6)

	local close = FlatButton(window, TEXT.CLOSE, 22, 20, 0)
	close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -5)
	close.label:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
	close.tip = TEXT.CLOSE_TIP
	close:SetScript("OnClick", CloseClicked)
	window.close = close

	local title = Text(window, 12, INK)
	title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
	title:SetPoint("RIGHT", close, "LEFT", -6, 0)
	title:SetText(TEXT.TITLE)
	window.title = title

	window.headline = Text(window, 15, { 1, 0.82, 0 })
	window.headline:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, HEADLINE_TOP)
	window.headline:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, HEADLINE_TOP)
	window.subline = Text(window, 11, INK_SOFT)
	window.subline:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, SUBLINE_TOP)
	window.subline:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, SUBLINE_TOP)
	Wrap(window.subline, 2)
end

-- Hovering the title: its line of flavour, and what titles are and where the
-- next one is, which the window has no room to say.
local function RankTooltip(self)
	local rank = self.standing
	if not rank then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	if rank.title then
		GameTooltip:AddLine(rank.title.name, RANK_INK[1], RANK_INK[2], RANK_INK[3])
		GameTooltip:AddLine(rank.title.flavour, 1, 1, 1, true)
	else
		GameTooltip:AddLine(TEXT.UNTITLED, INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
	end
	GameTooltip:AddLine(rank.next and TEXT.RANK_TIP_NEXT:format(rank.next.name, rank.next.at)
		or TEXT.RANK_TIP_TOP, 0.7, 0.7, 0.7, true)
	GameTooltip:Show()
end

-- The title, under the title band: a frame of its own so it can be hovered,
-- the name on the left cut where it meets the way to the next on the right,
-- and a hairline bar along the bottom in the colour of favours returned, which
-- is what fills it.
local function BuildRank()
	local r = CreateFrame("Button", nil, window)
	r:SetHeight(RANK_HEIGHT)
	r:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, RANK_TOP)
	r:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, RANK_TOP)

	r.progress = Text(r, 10, INK_SOFT)
	r.progress:SetJustifyH("RIGHT")
	r.progress:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -2)
	r.name = Text(r, 12, RANK_INK)
	r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	r.name:SetPoint("TOPRIGHT", r.progress, "TOPLEFT", -8, 2)

	r.track = Solid(r, "BORDER")
	r.track:SetHeight(2)
	r.track:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	r.track:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
	r.track:SetVertexColor(1, 1, 1, 0.07)
	r.fill = Solid(r, "ARTWORK")
	r.fill:SetHeight(2)
	r.fill:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	r.fill:SetVertexColor(COLOUR.returned[1], COLOUR.returned[2], COLOUR.returned[3], 0.85)

	r:SetScript("OnEnter", RankTooltip)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	window.rank = r
end

-- The all-time numbers, as four tiles rather than a sentence that stops
-- fitting once the numbers grow. Each number takes its rows' colour, and each
-- label is hung across its tile so a long translation is cut inside it.
local function BuildStats()
	local caption = Text(window, 9, INK_FAINT)
	caption:SetPoint("BOTTOMLEFT", window, "TOPLEFT", PAD, STATS_TOP + 3)
	caption:SetText(TEXT.ALL_TIME)
	window.stats = {}
	local gap = 4
	local tileWidth = (WIDTH - 2 * PAD - 3 * gap) / 4
	for i, def in ipairs({
		{ key = "received", label = TEXT.STAT_RECEIVED, colour = COLOUR.owed },
		{ key = "returned", label = TEXT.STAT_RETURNED, colour = COLOUR.returned },
		{ key = "group", label = TEXT.STAT_GROUP, colour = COLOUR.group },
		{ key = "strangers", label = TEXT.STAT_STRANGERS, colour = COLOUR.stranger },
	}) do
		local x = PAD + (i - 1) * (tileWidth + gap)
		local plate = Solid(window, "BORDER")
		plate:SetSize(tileWidth, STAT_HEIGHT)
		plate:SetPoint("TOPLEFT", window, "TOPLEFT", x, STATS_TOP)
		plate:SetVertexColor(1, 1, 1, 0.04)
		local tick = Solid(window, "BORDER", 1)
		tick:SetSize(tileWidth, 1)
		tick:SetPoint("TOPLEFT", plate, "TOPLEFT")
		tick:SetVertexColor(def.colour[1], def.colour[2], def.colour[3], 0.7)
		local value = Text(window, 15, def.colour)
		value:SetPoint("TOPLEFT", plate, "TOPLEFT", 3, -3)
		value:SetPoint("TOPRIGHT", plate, "TOPRIGHT", -3, -3)
		value:SetJustifyH("CENTER")
		local label = Text(window, 9, INK_SOFT)
		label:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", 3, 3)
		label:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", -3, 3)
		label:SetJustifyH("CENTER")
		label:SetText(def.label)
		window.stats[i] = { key = def.key, value = value, label = label, plate = plate }
	end
end

-- The tabs, each as wide as its label and a little more, so "Buffs you gave"
-- and a word of four letters are not given the same box. Should the three not
-- fit across the window in some language, all three are narrowed alike and
-- their labels cut inside them.
local function BuildTabs()
	window.tabs = {}
	local widths, total, gap = {}, 0, 4
	for i, def in ipairs({
		{ key = "all", label = TEXT.TAB_ALL },
		{ key = "favours", label = TEXT.TAB_FAVOURS },
		{ key = "given", label = TEXT.TAB_GIVEN },
	}) do
		local tab = FlatButton(window, def.label, 80, TAB_HEIGHT)
		tab.key = def.key
		tab.underline = Solid(tab, "BORDER", 2)
		tab.underline:SetPoint("BOTTOMLEFT")
		tab.underline:SetPoint("BOTTOMRIGHT")
		tab.underline:SetHeight(2)
		tab:SetScript("OnClick", TabClicked)
		widths[i] = FitWidth(tab.label, { def.label }, 70, 160)
		total = total + widths[i]
		window.tabs[i] = tab
	end
	local room = WIDTH - 2 * PAD - gap * (#widths - 1)
	local shrink = total > room and room / total or 1
	local x = PAD
	for i, tab in ipairs(window.tabs) do
		local w = math.floor(widths[i] * shrink)
		tab:SetWidth(w)
		tab:SetPoint("TOPLEFT", window, "TOPLEFT", x, TABS_TOP)
		x = x + w + gap
	end
end

local function BuildEmpty()
	local icon = window:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(LOGO)
	icon:SetSize(32, 32)
	icon:SetPoint("TOP", window, "TOP", 0, LIST_TOP - 40)
	if icon.SetDesaturated then icon:SetDesaturated(true) end
	icon:SetAlpha(0.35)
	window.emptyIcon = icon
	window.empty = Text(window, 12, INK_SOFT)
	window.empty:SetPoint("TOP", icon, "BOTTOM", 0, -12)
	window.empty:SetWidth(WIDTH - 2 * PAD - 48)
	window.empty:SetJustifyH("CENTER")
	Wrap(window.empty, 6)
end

local function BuildFooter()
	local rule = Solid(window, "BORDER")
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, FOOTER)
	rule:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, FOOTER)
	rule:SetVertexColor(1, 1, 1, 0.07)

	local clear = FlatButton(window, TEXT.CLEAR, 100, 20)
	clear:SetWidth(FitWidth(clear.label, { TEXT.CLEAR, TEXT.CLEAR_ARMED }, 90, 180))
	clear:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 8)
	clear.tip = TEXT.CLEAR_TIP
	clear:SetScript("OnClick", ClearClicked)
	window.clear = clear

	window.showing = Text(window, 10, INK_FAINT)
	window.showing:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 13)
	window.showing:SetPoint("BOTTOMRIGHT", clear, "BOTTOMLEFT", -8, 5)
end

local function Build()
	window = CreateFrame("Frame", "MannersLedger", UIParent)
	window:SetSize(WIDTH, HEIGHT)
	window:SetFrameStrata("HIGH")
	-- Comes to the front of its strata when clicked, and Show raises it, so a
	-- window opened first in the same strata does not keep it underneath.
	if window.SetToplevel then window:SetToplevel(true) end
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:EnableMouseWheel(true)
	window:RegisterForDrag("LeftButton")
	window:Hide()
	Place()
	-- Escape closes it, as it does every other window of this kind.
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "MannersLedger")
	end

	local shadowOuter = Solid(window, "BACKGROUND", -8)
	shadowOuter:SetPoint("TOPLEFT", -6, 6)
	shadowOuter:SetPoint("BOTTOMRIGHT", 6, -6)
	shadowOuter:SetVertexColor(0, 0, 0, 0.18)
	local shadowInner = Solid(window, "BACKGROUND", -7)
	shadowInner:SetPoint("TOPLEFT", -2, 2)
	shadowInner:SetPoint("BOTTOMRIGHT", 2, -2)
	shadowInner:SetVertexColor(0, 0, 0, 0.32)
	local body = Solid(window, "BACKGROUND", -6)
	body:SetAllPoints()
	body:SetVertexColor(0.04, 0.04, 0.06, 0.94)

	local band = Solid(window, "BACKGROUND", -5)
	band:SetPoint("TOPLEFT")
	band:SetPoint("TOPRIGHT")
	band:SetHeight(30)
	band:SetVertexColor(1, 1, 1, 0.045)
	local hair = Solid(window, "BORDER", 1)
	hair:SetPoint("TOPLEFT")
	hair:SetPoint("TOPRIGHT")
	hair:SetHeight(1)
	hair:SetVertexColor(1, 1, 1, 0.12)
	window.accent = Solid(window, "BORDER", 2)
	window.accent:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -30)
	window.accent:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -30)
	window.accent:SetHeight(1)

	BuildHeader()
	BuildRank()
	BuildStats()
	BuildTabs()

	rows = {}
	for i = 1, ROWS do rows[i] = BuildRow(i) end
	window.rows = rows

	BuildEmpty()

	window.track = Solid(window, "BORDER")
	window.track:SetWidth(3)
	window.track:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD + 2, LIST_TOP)
	window.track:SetHeight(ROWS * ROW_HEIGHT - 2)
	window.track:SetVertexColor(1, 1, 1, 0.06)
	window.thumb = Solid(window, "ARTWORK")
	window.thumb:SetWidth(3)

	BuildFooter()

	window:SetScript("OnDragStart", function(self) self:StartMoving() end)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- The position is kept in the ledger only; left user-placed, the
		-- client's layout cache would keep a second copy that can disagree.
		self:SetUserPlaced(false)
		SavePosition()
	end)
	window:SetScript("OnMouseWheel", function(_, delta) Ledger.Scroll(-(delta or 0)) end)
	window:SetScript("OnHide", function()
		DisarmClear()
		GameTooltip:Hide()
	end)
	-- Only while it is open: a shown frame is the only kind OnUpdate runs on.
	window:SetScript("OnUpdate", function(_, elapsed)
		tickAt = (tickAt or 0) + (elapsed or 0)
		if clearArmedUntil and GetTime() > clearArmedUntil then DisarmClear() end
		if tickAt >= TICK_SECONDS then
			tickAt = 0
			Render()
		end
	end)

	window.fadeIn = window:CreateAnimationGroup()
	local fade = window.fadeIn:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.15)
	fade:SetSmoothing("OUT")

	local s = Store()
	filter = s and s.filter or "all"
	SetFilter(filter)
end

function Ledger.Show()
	if not window then Build() end
	local c = Accent()
	window.accent:SetVertexColor(c[1], c[2], c[3], 0.9)
	window.thumb:SetVertexColor(c[1], c[2], c[3], 0.8)
	for _, tab in ipairs(window.tabs) do tab.underline:SetVertexColor(c[1], c[2], c[3], 1) end
	offset, lastTop, tickAt = 0, nil, 0
	window:Show()
	if window.Raise then window:Raise() end
	window.fadeIn:Stop()
	window.fadeIn:Play()
	Render()
end

function Ledger.Hide()
	if window then window:Hide() end
end

function Ledger.Toggle()
	if window and window:IsShown() then Ledger.Hide() else Ledger.Show() end
end

-- For the scenarios, which have to read what is on screen.
function Ledger.Window()
	return window
end
