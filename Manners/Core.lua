-- Manners -- core: the addon object, secret-safe access, failure handling,
-- defaults and their repair, the capability probe, which buff for which
-- person, unit inspection, names, and the lifecycle with its events.
--
-- Blizzard will not let an addon cast a spell on its own: CastSpellByName and
-- friends are protected and only run from a hardware event. So this addon does
-- every part of the job except the keypress -- it decides who deserves a buff
-- and parks that decision on a secure button. Prompt/ owns that button; this
-- file and the eight after it in Manners.toc work out what goes on it:
--
--   Range.lua      how near a passer-by has to be
--   Speech.lua     the phrase sets and the line said with a click
--   Queue.lua      debts, refusals, the never-offer list, friends, BuildQueue
--   GroupBuffs.lua one cast for a whole party in place of single casts
--   Requests.lua   people who ask for a buff in chat
--   Favours.lua    noticing that somebody buffed you
--   Clicks.lua     what became of a press, the global cooldown, the macro
--   Commands.lua   first run, test console, snooze, sharing, slash commands
--
-- A local one of them needs from another goes on ns where it is defined: a
-- later file copies it into a local at load, an earlier one (this, for the
-- lifecycle) reads it off ns at call time. "Core" in another file means this
-- file and those eight.

local ns = select(2, ...)
local L = ns.L

local addon = LibStub("AceAddon-3.0"):NewAddon((...), "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ns.addon = addon

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
ns.MANA = MANA

-- The label for Bindings.xml's entry under Options > Keybindings (this client's
-- game menu has no Key Bindings entry). A CLICK binding's name is not a Lua
-- identifier, so the label is set through _G.
_G["BINDING_NAME_CLICK MannersPrompt:LeftButton"] = L["Buff the prompted player"]

---------------------------------------------------------------------------
-- secret-safe access
--
-- The protection policy. On Forever and retail most API calls hand back a
-- secret rather than throw, so a result is made safe with plain(), which
-- turns a secret into nil ("cannot tell"), and the call itself is not
-- wrapped. A function that may be missing gets a type() check on the global,
-- read at call time.
--
-- pcall is only for calls that can throw:
--   - the aura reads the client restricts per spell. These keep a bare inline
--     pcall per read, never safecall, behind the aura cache;
--   - third-party library code (LibRangeCheck);
--   - calls handed a value that may be secret, such as a GUID;
--   - APIs whose signature differs between client generations;
--   - macro and settings setup.
--
-- Everything else on a busy path (per unit, per event, per repaint) calls the
-- client directly: type check, call, then plain() on each return it uses.
-- safecall costs about 310 ns a call against about 45 ns for the direct form,
-- so it is for once-per-scan and UI-rate calls, where it costs nothing
-- measurable.
--
-- ns.Guard stays at event, timer and module boundaries: one pcall per event,
-- about 80 ns. One fault is then named in /manners errors and never stops the
-- scanner. A throw inside the scan is caught there, not read as "cannot tell".
--
-- tests/scenarios/perf-budget.lua holds the scan to this on every client: a
-- budget of pcalls, calls to the client and memory per scan for each place
-- (a city is about 10 pcalls, a raid 14).
---------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Secrets throw on comparison and arithmetic, so anything branched on comes
-- through here: nil when we may not look.
local function plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end
ns.plain = plain

-- For the once-per-scan and UI-rate places the policy above allows: nil when
-- the call is missing or throws, else its first three returns made plain.
local function safecall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then return nil end
	if issecretvalue then
		if issecretvalue(a) then a = nil end
		if issecretvalue(b) then b = nil end
		if issecretvalue(c) then c = nil end
	end
	return a, b, c
end
ns.safecall = safecall

-- One token swapped for one piece of text, never read as a pattern: in a gsub
-- template "%" is an escape, and players type the reason lines and phrases
-- ("10% left"); a function replacement is returned verbatim.
--
-- A repaint asks this about seventeen times, mostly for a token its line does
-- not hold, so a plain find answers that first; every token is a literal
-- "{word}", which a plain find and gsub read alike. One file-level function
-- hands back the value, not a closure per call.
do
	local swapValue
	local function SwapValue() return swapValue end
	function ns.Swap(text, token, value)
		text = text or ""
		if not text:find(token, 1, true) then return text end
		swapValue = value or ""
		return (text:gsub(token, SwapValue))
	end
end

---------------------------------------------------------------------------
-- failure handling
--
-- Script errors are invisible unless the player turned them on, and a repeating
-- timer whose function throws simply stops. Anything that can fail goes through
-- here so the failure is named instead.
---------------------------------------------------------------------------

-- The last thirty failures (Guard wraps the tick, so one can repeat 2.5 times a
-- second), the count of all of them ever, and which labels have been announced.
ns.errors = {}
ns.errorCount = 0
ns.shouted = {}

function ns.Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return true end

	-- This function is the thing that stops a failure being silent, so it must
	-- never be the thing that throws.
	label = tostring(label)
	err = tostring(err)
	ns.errorCount = (ns.errorCount or 0) + 1
	ns.errors[#ns.errors + 1] = { at = date("%H:%M:%S"), where = label, err = err }
	while #ns.errors > 30 do table.remove(ns.errors, 1) end

	if not ns.shouted[label] then
		ns.shouted[label] = true
		-- Handed on to the game's error handler as well, once per label, so an
		-- error addon (or the game's own Lua error window, if the player turned
		-- it on) sees what broke as it sees any addon's failure. Protected: the
		-- handler is somebody else's code.
		local getHandler = _G.geterrorhandler
		local handler = type(getHandler) == "function" and getHandler()
		if type(handler) == "function" then pcall(handler, "Manners: " .. label .. ": " .. err) end
		if ns.addon and ns.addon.Print then
			-- The label is the code's own name for the handler and the command
			-- is typed as it stands, so neither is the translator's to change.
			ns.addon:Print(L["|cffff4040something broke in %s|r -- %s |cff808080(%s for the rest)|r"]
				:format(label, err, "/manners errors"))
		end
		-- Repaint Diagnostics once per new failure, but not for a failure of
		-- the repaint itself, which would only fail again.
		if ns.RepaintOptions and label ~= "options repaint" and label ~= "broker text" then
			ns.RepaintOptions()
		end
	end
	return false
end

---------------------------------------------------------------------------
-- telling the settings UI that something changed under it
--
-- AceConfig reads a control's value, name and `hidden` only while drawing, and
-- the broker text is assigned once, so anything that changes a setting outside
-- its own control (slash commands, the minimap right-click, a fight starting
-- or ending) calls this. Both halves are optional and guarded: Options/ may
-- not have loaded, and a failed repaint must not take down the caller.
---------------------------------------------------------------------------

function ns.RepaintOptions()
	if ns.RefreshOptionsDisplay then
		ns.Guard("options repaint", ns.RefreshOptionsDisplay)
	end
	if ns.RefreshBrokerText then
		ns.Guard("broker text", ns.RefreshBrokerText)
	end
end

---------------------------------------------------------------------------
-- defaults
---------------------------------------------------------------------------

-- LibSharedMedia ships only "None", so Prompt/Prompt.lua registers our own.
-- A file id rather than a path, because Register rejects paths under Sound\.
ns.SOUND_KEY = "Manners alert"
ns.SOUND_FILE = 567458

local defaults = {
	profile = {
		enabled = true,
		verbose = true, -- "X buffed you", and why a cast failed
		debugClicks = false, -- raw attribute dump on every click; on via /manners clicks

		buff = {
			choice = "auto",
			-- The class's spells switched off, as a sparse set (absent = on).
			-- Keys are class-unique, so a shared profile cannot cross classes.
			skip = {},
			-- A paladin who knows Blessing of Kings offers it to everybody ahead of
			-- the rest (Buffs.lua, `strongest`; CastableBuffs). On: the strongest
			-- blessing first is what was asked for, and somebody already carrying
			-- one of yours, or Kings from another paladin, is handled as ever.
			kingsFirst = true,
			-- The order a class's buffs are tried in, set by hand (Who to buff, Buff
			-- order): order[CLASS] = { key, key, ... }, every buff of that class the
			-- client that wrote it has. Absent is Automatic -- the list as the buff
			-- set gives it, Kings ahead of it while kingsFirst is on -- and one that
			-- is there wins over kingsFirst. Per class, since the profile is shared by
			-- every character; a key this client lacks is kept for the client that
			-- has it (ns.ClampSettings, ns.WalkBuffs).
			order = {},
		},

		sources = {
			owed = true, -- people who buffed us
			group = true, -- party/raid missing it
			strangers = true, -- nearby non-group players
			owedClassBuffsOnly = true, -- ignore stray HoTs and procs
			-- People who ask for your buff in chat. Off, because reading chat is
			-- guesswork, so the player should choose it.
			asked = false,
			-- Yourself, missing your own buff. On: it costs nobody anything and reads
			-- your own auras, which the game does not hide.
			self = true,
		},

		-- The rest of "Myself": the buffs only your class puts on itself
		-- (Buffs.lua, VANILLA_OWN), and where you are reminded of any of it.
		ownBuffs = {
			-- Off: nobody needs Inner Fire at the auction house, and a prompt
			-- that nags in town teaches you to ignore it. One rule for
			-- everything on yourself, your group buff included (SelfEntry):
			-- two rules for one "You" on the prompt would be a puzzle.
			inCities = false,
			-- Per family, by its key: "auto" (Automatic, or ticked for a family of one),
			-- a spell's key (always that one), or "off" (Don't remind me). Filled below.
			pick = {},
		},

		-- The order of the queue, not who is on it.
		priority = {
			target = true, -- a deliberate target outranks a favour owed
			-- Friends and guildmates ahead of the rest of their kind. On,
			-- because it only reorders people who were offered anyway.
			friends = true,
			-- Group members missing your buff go first while a ready check runs, and so
			-- does somebody just back from the dead. On, for the same reason as friends.
			readyCheck = true,
			revived = true,
		},

		-- One cast for a whole party (GroupBuffs.lua). On: only somebody who has
		-- learned the group version and carries its reagent gets it -- nobody does
		-- but to use it -- and it saves the mana and presses of one by one.
		groupBuffs = {
			use = true,
			-- How many of one party (or, for a Greater Blessing, one class)
			-- must be missing the buff. Three: fewer is as quick one by one,
			-- and not worth a reagent.
			atLeast = 3,
		},

		-- People never to offer anything to, as a set of filed names. Somebody
		-- on it who buffs you is still offered the favour back (STATUS.md).
		never = {},

		filters = {
			relevantOnly = true, -- skip people the buff does nothing for
			requireInRange = true,
			-- How near a passer-by has to be: cast | near | beside. Not "cast",
			-- because thirty yards of a city square is twenty-odd nameplates.
			proximity = "near",
			-- Passers-by only where the game calls you resting. Off, because
			-- it takes away offers somebody gets today.
			restingOnly = false,
			reachableOnly = true, -- hide people we cannot actually reach
			restoreTarget = true, -- hand your target back after buffing
			whenBuffed = "skip", -- skip | refresh | always
			-- The most minutes before a buff ends that a top-up is ever offered
			-- (the ceiling of its lead, worked out from how long the buff lasts:
			-- see "how early a top-up is offered").
			refreshUnder = 5,
			-- In a raid or a dungeon the lead is this many times longer: a fight
			-- and the drinking after it take minutes.
			refreshRaid = 2,
			-- Your own buffs, and the ones you put on yourself, are topped up
			-- before they run out whatever whenBuffed says for other people
			-- (ns.SelfWhenBuffed), and selfLead minutes ahead when set (0: the
			-- moment worked out from the buff's length, ns.LeadFor).
			selfTopUp = true,
			selfLead = 0,
			-- Off: somebody whose buffs the client will not show is offered,
			-- "unverified" (but not in the first seconds after a fight:
			-- UNVERIFIED_SECONDS). On, never: a player asked for it.
			verifiedOnly = false,
			minLevel = 1,
			-- Off, because a press on a mount dismounts you, which somebody
			-- buffing from the saddle may want. Dead, taxi and vehicle need no
			-- switch: nothing can be cast there, so BuildQueue offers nobody.
			hideMounted = false,
			-- Nobody flagged for PvP, while you are not flagged yourself
			-- (Queue.lua, "flagged for PvP"). On: a buff on them flags you
			-- too, for minutes, which nobody asked for by buffing back.
			skipPvP = true,
			-- Off: an option a player asked for (see SelfServed in Queue.lua).
			skipSameClass = false,
			-- The share of your mana (0-90) kept for yourself: below it, only
			-- a favour owed or a request from chat is offered. 0 is off.
			manaFloor = 0,
			-- The raid groups (1-8) switched off, as a sparse set (absent = on): in a
			-- raid, those groups are offered nothing unasked.
			skipRaidGroups = {},
		},

		timing = {
			reciprocateWindow = 120,
			retryCooldown = 12,
			scanInterval = 0.4,
			graceSeconds = 45,
			keepDebts = true,
		},

		prompt = {
			locked = true,
			-- Just above the action bars rather than over the play area, where
			-- it would swallow clicks. The bottom edge keeps that distance at
			-- any resolution, which a CENTER offset does not.
			point = "BOTTOM",
			relPoint = "BOTTOM",
			x = 0,
			y = 300,
			width = 220,
			height = 44,
			scale = 1,
			alpha = 1,
			-- Only suppresses the click-outcome flash in a fight: Hide() on a
			-- protected frame is refused in combat. The key keeps its old name
			-- because renaming it would silently reset everyone's setting.
			hideInCombat = false,
			-- The built-in looks (Glass, Framed, Minimal) draw the prompt at about
			-- half strength in a fight when this is on, so it reads as held. Off by
			-- default: a dim that stacks with a low Opacity made it vanish.
			dimInCombat = false,

			-- Glass again from 1.5.1: 1.5.0 made Luxe the default, and in the game its
			-- reason tag read white on white for a passer-by -- the preview renderer draws
			-- light layers far gentler than the client does. AceDB never saves a value
			-- equal to its default, so everybody who never picked a look is back on
			-- Glass; a look somebody picked, Luxe included, is kept.
			style = "glass",
			accentByReason = true,
			-- standard | colourblind: which reason colours (Prompt/Prompt.lua).
			reasonPalette = "standard",
			accentMode = "icon", -- icon | stripe | both | off
			flashStyle = "pulse", -- pulse | once | off
			-- /thank somebody who buffs you (Favours.lua). Off: an emote is
			-- seen by everybody nearby, so the player chooses to make one.
			thankEmote = false,
			-- full | calm: calm is the prompt without the animations.
			effects = "full",
			-- The global cooldown swept over the spell icon.
			showCooldown = true,

			showIcon = true,
			iconSize = 30,
			roundIcon = false,
			showCount = true,
			showQueue = false,
			queueRows = 3,
			-- A left click on a name in that list buffs them (Prompt/Rows.lua).
			-- Off: the list is only to read.
			clickRows = true,

			-- What hovering the prompt or a name in the list shows
			-- (Prompt/Button.lua): full | short | shift | off. Short is the name,
			-- why and a hint that Shift gives the rest; shift shows nothing until
			-- Shift is held; off none (the drag tooltip of an unlocked prompt
			-- stays, it explains the drag).
			tooltip = "short",
			-- Where it goes: beside (above or below the prompt and its list,
			-- whichever side has more room) | game (where the client puts its own
			-- tooltips).
			tooltipPosition = "beside",

			-- LibSharedMedia's own default font for this client's language: "Friz
			-- Quadrata TT" on most, but koKR, zhCN and zhTW register no such name,
			-- and a profile holding it read "(not loaded)" on its own Look page
			-- though nothing was wrong. AceDB writes no value equal to the default
			-- into the saved file, so an untouched profile follows the language of
			-- whichever client opens it, and only a font the player picked is kept.
			font = (function()
				local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
				local media = lsm and type(lsm.DefaultMedia) == "table" and lsm.DefaultMedia.font
				return type(media) == "string" and media ~= "" and media or "Friz Quadrata TT"
			end)(),
			fontSize = 13,
			fontColor = { 1, 1, 1, 1 },
			bgColor = { 0.04, 0.04, 0.06, 0.88 },
			accentColor = { 0.45, 0.4, 0.9, 1 },

			format = "{name}",
			showSub = true,
			-- Short to fit the 220px default width. They start in the player's
			-- language; AceDB stores a line only once somebody types their own.
			-- Each reason has its own words, so colour is never the only cue.
			reasonTarget = L["your target"],
			reasonOwed = L["buffed you"],
			reasonGroup = L["in your group"],
			reasonNearby = L["needs {buff}"],
			reasonAsked = L["asked for it"],
			-- Under "You" on the first line: which of your own buffs is off.
			reasonSelf = L["your own {buff}"],
			-- A top-up gets its own line rather than qualifying the player's
			-- text. {time} is what their current aura has left.
			reasonRefresh = L["expires in {time}"],
			reasonUnknown = L["unverified"],
			classColor = true,
		},

		speech = {
			enabled = false,
			channel = "SAY",
			-- Off from 1.5.1: with this on by default, a player ticked "Say a line when I
			-- buff someone", buffed a passer-by and heard nothing. The thank-you quick
			-- choices on Start here still switch it on for themselves.
			onlyWhenReturning = false,
			-- Filled in at load from the Roleplay set.
			phrases = "",
		},

		-- owedOnly, to match the flash, which only pulses for a favour owed.
		sound = { enabled = false, file = ns.SOUND_KEY, owedOnly = true },
		-- A place of our own on the minimap's rim: LibDBIcon puts every addon at 225
		-- degrees, where the button sat on Questie's, and a player saw Questie's "!"
		-- and got Manners' tooltip (1.5.1). A dragged button keeps its place.
		minimap = { hide = false, minimapPos = 195 },
	},
}
ns.defaults = defaults
-- Every family of every class Automatic, so a profile shared by a mage and a
-- priest holds both, and no family's default is missing for the repair, the
-- reset or a settings string. Buffs.lua loads first.
for _, families in pairs(ns.OWN_BUFFS or {}) do
	for _, family in ipairs(families) do defaults.profile.ownBuffs.pick[family.key] = "auto" end
end

-- Whether the prompt's first line says anything at all; shared by the repair at
-- load and the box's setter so they agree on what an empty line is.
function ns.UsableFormat(text)
	return type(text) == "string" and text:find("%S") ~= nil
end

---------------------------------------------------------------------------
-- capability probe
---------------------------------------------------------------------------

local caps = { buffs = {} }
ns.caps = caps

local playerClass
-- For the files after this one, read at call time: each probe sets it again.
function ns.PlayerClass() return playerClass end

-- nil when this client does not have the id. Both generations are tried.
local function SpellNameFor(id)
	return safecall(C_Spell and C_Spell.GetSpellName, id)
		or safecall(_G.GetSpellInfo, id)
end
ns.SpellNameFor = SpellNameFor

-- Whether UnitName's second return is a surname here rather than a realm. Reads
-- ns.Flavour, settled at load, because callers can run before the first probe;
-- caps.unitNameIsSurname is set from this so the two cannot disagree.
local function SurnameClient()
	return (ns.Flavour and ns.Flavour.flavour) == "camelot"
end

-- The probe's helpers, in a block of their own for the main chunk's 200 locals.
do
	-- Whether you know spell `id`. The client's own calls first: Forever
	-- 1.60.1 keeps IsSpellKnown and IsPlayerSpell only as shims, in
	-- Blizzard_DeprecatedSpellBook, behind the loadDeprecationFallbacks
	-- setting; with that off both are gone and every class read as knowing
	-- nothing. These are the two calls the shims make. Only the probe asks,
	-- never a busy path.
	local function SpellKnown(id)
		local book = C_SpellBook
		if type(book) == "table" then
			local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
			if safecall(book.IsSpellInSpellBook, id, bank, false) == true
				or safecall(book.IsSpellKnown, id, bank) == true then
				return true
			end
		end
		return safecall(_G.IsSpellKnown, id) == true or safecall(_G.IsPlayerSpell, id) == true
	end

	-- Whether the client declares an aura secret: true, false, or nil when it
	-- will not say.
	local function AuraSecrecy(id)
		local secret
		if C_Secrets and type(C_Secrets.ShouldSpellAuraBeSecret) == "function" then
			secret = safecall(C_Secrets.ShouldSpellAuraBeSecret, id)
		end
		if secret == nil and C_Secrets and type(C_Secrets.GetSpellAuraSecrecy) == "function" then
			local level = safecall(C_Secrets.GetSpellAuraSecrecy, id)
			if level ~= nil and Enum and Enum.SecrecyLevel then
				secret = (level ~= Enum.SecrecyLevel.NeverSecret)
			end
		end
		return secret
	end

	local function ProbeBuff(buff)
		local info = { key = buff.key, buff = buff }

		for _, id in ipairs(buff.ranks) do
			if SpellKnown(id) then
				info.known = true
				info.topRank = info.topRank or id
				-- For your own buffs, every name a rank you know goes by: the
				-- reading on yourself matches by them too (ReadOwnFamily), so
				-- a rank missing from the table cannot read as never up.
				if buff.own then
					local name = SpellNameFor(id)
					if name then
						info.names = info.names or {}
						info.names[name] = true
					end
				end
			end
		end
		for _, id in ipairs(buff.group or {}) do
			if SpellKnown(id) then
				info.knownGroup = true
			end
		end
		-- The one-cast-for-the-party version: the best rank known, since the
		-- macro casts by name and the game picks that one, and so its reagent.
		for _, rank in ipairs(buff.groupCast or {}) do
			if SpellKnown(rank.id) then
				info.groupRank, info.groupReagent = rank.id, rank.reagent
				info.groupName = SpellNameFor(rank.id)
				info.groupIcon = safecall(C_Spell and C_Spell.GetSpellTexture, rank.id)
				break
			end
		end

		-- The macro casts by name and the game picks the best rank of it, so the name
		-- is the best rank's you know: a spell line can change its name on the way up
		-- (Frost Armor is Ice Armor from 30), and "/cast Frost Armor" would cast rank
		-- 3 forever. With nothing known, the top rank's.
		local named = info.topRank or buff.ranks[1]
		info.name = SpellNameFor(named)
		info.icon = safecall(C_Spell and C_Spell.GetSpellTexture, named)

		-- Ids this client has never heard of. A wrong id has no symptom but silence,
		-- so every one, aura ids included (a dead group id breaks the "already has
		-- it" check), is named in /manners debug and on Diagnostics. A line, not a
		-- popup: a client still loading spell data answers nil for everything (the
		-- probe re-runs on SPELLS_CHANGED).
		info.unresolved = {}
		for _, id in ipairs(buff.auraIds) do
			if not SpellNameFor(id) then
				info.unresolved[#info.unresolved + 1] = id
			end
		end
		-- The blockers' too (Buffs.lua): a scroll's id this client lacks would
		-- hold nothing off, and say nothing.
		for _, id in ipairs(buff.blockerIds or {}) do
			if not SpellNameFor(id) then
				info.unresolved[#info.unresolved + 1] = id
			end
		end

		-- Secrecy is decided per spell. Long-duration class buffs are the most
		-- likely to stay readable, which is what the "who is missing it" feature
		-- rests on, so record every id rather than sampling one.
		info.secrecy = {}
		local readable, declared = 0, 0
		for _, id in ipairs(buff.auraIds) do
			local secret = AuraSecrecy(id)
			info.secrecy[id] = secret
			if secret == false then readable = readable + 1 end
			if secret == true then declared = declared + 1 end
		end
		-- The blockers' (Buffs.lua), recorded and not counted: what a scroll
		-- reads as says nothing of whether the buff itself can be read.
		for _, id in ipairs(buff.blockerIds or {}) do
			info.secrecy[id] = AuraSecrecy(id)
		end
		info.readable = caps.getUnitAuraBySpellID and readable > 0
		-- Unreadable only because the probe was made while the client withheld
		-- (caps.probedInFight) and so declared its ids secret: the client reads
		-- them again once it stops, and until the next probe UnitHasBuff still
		-- keeps the account of what it refused (withheld, what was last read
		-- worn). Not so for a buff that can never be read.
		info.probeHidden = caps.probedInFight == true and caps.getUnitAuraBySpellID == true and declared > 0

		return info
	end

	-- A hand by the client's own word for it ("Main Hand", "Off Hand").
	function ns.HandName(slot)
		if slot == 17 then return _G.INVTYPE_WEAPONOFFHAND or "Off Hand" end
		return _G.INVTYPE_WEAPONMAINHAND or "Main Hand"
	end

	-- A scroll (Buffs.lua, the mage's scrolls): its name is the one the client
	-- gives the spell its use casts, already in the player's language, or the
	-- item's where nameFromItem says the spell's is another scroll's; its icon
	-- is the item's. Never `known`: whether there is one to use is the bags'
	-- answer, asked when it is needed (ScrollReady).
	--
	-- A weapon enhancement (Buffs.lua, a poison, stone, oil or lure) is named by
	-- its item as well, since the spell its use casts is "Crippling Poison" to
	-- two ranks and "Wound Poison" to three, and the hand it is for follows the
	-- name, so the prompt says which weapon is meant. Until the client has
	-- loaded the item, the spell's name stands in.
	local function ProbeScroll(spell)
		local info = { key = spell.key, buff = spell, topRank = spell.ranks[1], unresolved = {}, secrecy = {} }
		local items = C_Item
		local itemName = safecall(items and items.GetItemNameByID, spell.item)
		if type(itemName) ~= "string" or itemName == "" then itemName = nil end
		local enhance = spell.family and spell.family.enhance
		if enhance then info.hand = " (" .. ns.HandName(spell.family.slot) .. ")" end
		if enhance and not spell.nameFromItem then
			local called = itemName or SpellNameFor(spell.ranks[1])
			info.name = called and (called .. info.hand) or nil
			if not itemName then
				info.itemPending = spell.item
				local load = items and items.RequestLoadItemDataByID
				safecall(load, spell.item)
			end
		elseif spell.nameFromItem then
			-- Never the spell's, which is another scroll's: the client knows an
			-- item's name only once it has loaded it, and a mage who has never
			-- carried one has not. Its own name stands in, the item is asked
			-- for, and BuffName takes the item's once the client has it.
			info.name = itemName or spell.nameFromItem
			if not itemName then
				info.itemPending = spell.item
				safecall(items and items.RequestLoadItemDataByID, spell.item)
			end
		else
			info.name = SpellNameFor(spell.ranks[1]) or itemName
		end
		info.icon = safecall(items and items.GetItemIconByID, spell.item)
		if info.icon == nil and items and type(items.GetItemInfoInstant) == "function" then
			info.icon = plain((select(5, items.GetItemInfoInstant(spell.item))))
		end
		return info
	end

	-- The item's name for a scroll the probe had to name without it, once the
	-- client has loaded the item (BuffName asks, only while it has not).
	function ns.ResolveItemName(info)
		local name = safecall(C_Item and C_Item.GetItemNameByID, info.itemPending)
		if type(name) == "string" and name ~= "" then info.name, info.itemPending = name .. (info.hand or ""), nil end
	end

	-- A weapon enhancement's probe, made when it is first asked for rather than
	-- with every spell at login: every class has dozens of them, and only those
	-- in the bags are ever named or shown (ns.BuffInfo).
	function ns.ProbeOwnItem(spell)
		local info = ProbeScroll(spell)
		if caps.own then caps.own[spell.key] = info end
		return info
	end

	-- Does this client still hand addons the combat log? Where it is gone,
	-- registration throws, so one pcall'd RegisterEvent answers it, on a frame of
	-- our own made once (Ace's registry would keep the subscription).
	local probeFrame
	local function ProbeCombatLog()
		if type(_G.CreateFrame) ~= "function" then return nil end
		if not probeFrame then
			local made, frame = pcall(_G.CreateFrame, "Frame")
			if not made then return nil end
			probeFrame = frame
		end
		if type(probeFrame) ~= "table" or type(probeFrame.RegisterEvent) ~= "function" then
			return nil
		end

		local ok = pcall(probeFrame.RegisterEvent, probeFrame, "COMBAT_LOG_EVENT_UNFILTERED")
		if ok then
			pcall(probeFrame.UnregisterEvent, probeFrame, "COMBAT_LOG_EVENT_UNFILTERED")
		end
		return ok
	end

	function ns.ProbeCapabilities()
		wipe(caps)
		caps.buffs = {}

		-- What measures nearness depends on the spellbook, bags and libraries, and
		-- this runs whenever those may have changed (SPELLS_CHANGED).
		ns.ForgetProximity()
		-- What was read under the last probe (ns.ForgetAuraCache).
		if ns.ForgetAuraCache then ns.ForgetAuraCache() end

		playerClass = plain(select(2, UnitClass("player")))
		caps.class = playerClass

		caps.getUnitAuraBySpellID = type(C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) == "function"
		caps.hasSecrets = type(C_Secrets) == "table"
		caps.namePlates = type(C_NamePlate and C_NamePlate.GetNamePlates) == "function"

		if C_Secrets and type(C_Secrets.ShouldAurasBeSecret) == "function" then
			caps.aurasSecretNow = safecall(C_Secrets.ShouldAurasBeSecret)
		end
		-- Made while the client withholds (SPELLS_CHANGED can fire in a fight),
		-- the probe may take a buff readable out of a fight for a secret one,
		-- and every reading of it is then refused before it is asked, until the
		-- next probe: PLAYER_REGEN_ENABLED probes again.
		caps.probedInFight = InCombatLockdown() == true or caps.aurasSecretNow == true

		---------------------------------------------------------------------
		-- what this client is, and what follows from that
		---------------------------------------------------------------------

		-- Flavour.lua decided all of this at load; copied so one table answers
		-- "what am I allowed to do here" for /manners debug and the saved probe.
		local flavour = ns.Flavour or {}
		caps.flavour = flavour.flavour
		caps.family = flavour.family
		caps.interface = flavour.interface
		caps.recognised = flavour.recognised == true

		-- Whether secrets are enforced right now. C_Secrets exists on clients
		-- where nothing is restricted, so caps.hasSecrets is not this answer.
		caps.secretRestrictions = safecall(C_Secrets and C_Secrets.HasSecretRestrictions)

		-- The combat log: the family answers it for a named client, and the probe
		-- only for one nobody here has seen. The probe can prove the log gone (a
		-- throw), never present. Never probed on a known modern client, where
		-- registering may raise ADDON_ACTION_FORBIDDEN, a popup with our name on it.
		if caps.recognised and caps.family == "modern" then
			caps.combatLogProbe = nil
		else
			caps.combatLogProbe = ProbeCombatLog()
		end
		if flavour.recognised then
			caps.combatLog = caps.family == "classic"
		else
			caps.combatLog = caps.combatLogProbe == true
		end

		-- Whether the client parses macro conditionals like [@party1,help] at all.
		-- It says nothing about whether a name resolves inside one.
		caps.unitConditionals = type(_G.SecureCmdOptionParse) == "function"

		-- ASSUMPTION: whether /cast [@Name] can replace /target, cast, target back.
		-- No API answers it, and [@Name] resolves only for group members, so
		-- Camelot keeps the /target route, the only one verified in game. Only
		-- reported, by /manners debug and the probe kept in SavedVariables
		-- (ns.WriteProbe): no macro is built from it.
		caps.conditionalTargeting = flavour.flavour ~= "camelot"

		-- /targetexact matches the whole name where /target matches a prefix
		-- ("/target Mort" can find Mortimer). A client command, so probed.
		local secureCommands = _G.SecureCmdList
		caps.targetExact = (type(secureCommands) == "table"
				and type(secureCommands.TARGET_EXACT) == "function")
			or type(_G.SLASH_TARGET_EXACT1) == "string"

		-- UnitName's second return is a surname on Camelot (joined with a space)
		-- and a realm elsewhere (a dash, or dropped). Nothing in the value says
		-- which, so this is a flavour branch.
		caps.unitNameIsSurname = SurnameClient()

		caps.anyKnown = false
		caps.anyReadable = false
		caps.unresolvedBuffs = 0
		for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
			local info = ProbeBuff(buff)
			caps.buffs[buff.key] = info
			if info.known then caps.anyKnown = true end
			if info.readable then caps.anyReadable = true end
			if #info.unresolved > 0 then caps.unresolvedBuffs = caps.unresolvedBuffs + 1 end
		end

		caps.hasClassBuffs = ns.GetClassBuffs(playerClass) ~= nil

		-- The class's own buffs (Buffs.lua, VANILLA_OWN), probed the same way but kept
		-- apart: caps.buffs stays the list of what you can give. Known only by a rank
		-- the client says you know AND a name it can give that rank: the macro casts
		-- by that name. A scroll is never known here (ProbeScroll).
		caps.own = {}
		caps.anyOwnKnown = false
		for _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do
			-- A weapon enhancement is probed when first asked for (ProbeOwnItem).
			for _, spell in ipairs(family.enhance and {} or family.spells) do
				local info = spell.item and ProbeScroll(spell) or ProbeBuff(spell)
				info.known = info.known == true and info.name ~= nil
				caps.own[spell.key] = info
				if info.known then caps.anyOwnKnown = true end
			end
		end

		return caps
	end
end

-- Whether this character has anything the prompt could cast, for somebody
-- else or itself: the one test for "is there a prompt at all", so a hunter
-- still has one for his aspects.
function ns.CanCastAnything()
	-- A rogue or a warrior with a poison or a stone in the bags has something to
	-- put on a weapon, whatever he has learned (ns.OwnItemsHeld).
	if ns.OwnItemsHeld() then return true end
	return caps.anyKnown == true or caps.anyOwnKnown == true
end

-- A class with nothing for anybody else and something of its own learned: a
-- hunter with an aspect, a shaman with Lightning Shield, a rogue with poisons
-- or a stone in the bags. Everything about other people is left off the
-- options page for it, and "Myself" is shown.
function ns.OwnBuffsOnly()
	return not caps.hasClassBuffs and (caps.anyOwnKnown == true or ns.OwnItemsHeld())
end

-- Your own buffs' answers sit apart (caps.own); every key is unique across
-- both tables (Buffs.lua), so one lookup serves the name, icon and macro of
-- either kind.
function ns.BuffInfo(buff)
	if not buff then return nil end
	if buff.own then
		local info = caps.own and caps.own[buff.key]
		-- A weapon enhancement is probed when first asked for (ProbeOwnItem).
		if not info and caps.own and buff.item and buff.family and buff.family.enhance then
			info = ns.ProbeOwnItem(buff)
		end
		return info
	end
	return caps.buffs[buff.key]
end

function ns.BuffName(buff)
	local info = ns.BuffInfo(buff)
	-- A scroll named before the client had loaded its item (ProbeScroll).
	if info and info.itemPending then ns.ResolveItemName(info) end
	return (info and info.name) or buff and buff.key or "?"
end

function ns.IsBuffKnown(buff)
	local info = ns.BuffInfo(buff)
	return info and info.known == true
end

---------------------------------------------------------------------------
-- which buff for which person
---------------------------------------------------------------------------

-- The spell Automatic would name: reached only in Automatic (ResolveBuff answers
-- pins), so neverAuto is skipped outright. Honours the per-spell switches like
-- CastableBuffs, so the login line and previews never name a switched-off spell.
local function FirstKnownBuff()
	local db = addon.db and addon.db.profile
	local skip = db and db.buff and db.buff.skip
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if ns.IsBuffKnown(buff) and not buff.neverAuto
			and not (skip and skip[buff.key]) then
			return buff
		end
	end
end

---------------------------------------------------------------------------
-- the buff order
--
-- A class's buffs tried in an order of the player's own (Who to buff, Buff
-- order), saved per class: db.buff.order[CLASS] = { key, key, ... }. Absent is
-- Automatic, the list as the buff set gives it with Blessing of Kings ahead of
-- it while db.buff.kingsFirst is on; one that is there wins over that switch,
-- whose meaning the order is then. It is only ever the order the walk tries the
-- buffs in (CastableBuffs): who is covered, and by what, is decided by
-- PickBuffFor as ever, and reads the whole list before it offers anything.
---------------------------------------------------------------------------

-- In a block of its own for the main chunk's 200 locals.
do
	-- The list the walk reads, made for one order and kept until the order, the
	-- class or its buff list differs: compared key by key on every call (a
	-- handful of strings, no allocation), so an order edited in place, switched
	-- with the profile or put back by the page's reset is read at the next scan
	-- with nothing to tell this function.
	local cache = { class = false, base = false, count = 0, keys = {}, list = {} }

	-- `base` (the class's buffs in the buff set's order) in `order`'s order: the
	-- keys this client has, once each, then the ones the order lacks in the
	-- set's order. A key this client lacks is skipped, not removed.
	local function Ordered(class, base, order)
		local count = #order
		local fresh = cache.class == class and cache.base == base and cache.count == count
		if fresh then
			local keys = cache.keys
			for i = 1, count do
				if keys[i] ~= order[i] then
					fresh = false
					break
				end
			end
		end
		if fresh then return cache.list end

		local byKey, list, seen = {}, {}, {}
		for _, buff in ipairs(base) do byKey[buff.key] = buff end
		for i = 1, count do
			local key = order[i]
			local buff = type(key) == "string" and byKey[key]
			if buff and not seen[key] then
				seen[key] = true
				list[#list + 1] = buff
			end
		end
		for _, buff in ipairs(base) do
			if not seen[buff.key] then list[#list + 1] = buff end
		end
		cache.class, cache.base, cache.count, cache.list = class, base, count, list
		local keys = cache.keys
		for i = 1, count do keys[i] = order[i] end
		for i = count + 1, #keys do keys[i] = nil end
		return list
	end

	-- The class's buffs the way Automatic walks them: the set's order, the
	-- strongest first when asked. A new table, for the options page and the repair.
	local function Automatic(class, kingsFirst)
		local list, out = ns.GetClassBuffs(class) or {}, {}
		if kingsFirst then
			for _, buff in ipairs(list) do
				if buff.strongest then out[#out + 1] = buff end
			end
		end
		for _, buff in ipairs(list) do
			if not (kingsFirst and buff.strongest) then out[#out + 1] = buff end
		end
		return out
	end

	-- The saved order of this character's class, or nil for Automatic.
	function ns.BuffOrder()
		local db = addon.db and addon.db.profile
		local all = db and db.buff and db.buff.order
		local order = type(all) == "table" and all[playerClass] or nil
		if type(order) == "table" and order[1] ~= nil then return order end
		return nil
	end

	-- Whether the player has set an order for this class: what turns the
	-- Kings-first switch off the page and puts "Back to Automatic" on it.
	function ns.HasBuffOrder()
		return ns.BuffOrder() ~= nil
	end

	-- This class's buffs in the order the walk tries them -- every one of them,
	-- learned or not, switched on or off -- and whether that order is the
	-- player's own. Not a copy: read it, never write it. Called on every scan,
	-- so nothing is made unless the order has just changed.
	function ns.WalkBuffs()
		local base = ns.GetClassBuffs(playerClass) or {}
		local order = ns.BuffOrder()
		if order then return Ordered(playerClass, base, order), true end
		return base, false
	end

	-- What the options page lists: the walk's order as a new table, whoever's
	-- order it is (Automatic's with Kings first while that switch is on).
	function ns.BuffWalkOrder()
		local db = addon.db and addon.db.profile
		local list, custom = ns.WalkBuffs()
		if not custom then return Automatic(playerClass, db ~= nil and db.buff.kingsFirst == true) end
		local out = {}
		for i, buff in ipairs(list) do out[i] = buff end
		return out
	end

	-- One class's saved order made sound, or nil when nothing of it is left to
	-- keep: a key that is not a string or that no client has for this class goes,
	-- and a key twice is kept once. A key this client lacks stays (a profile is
	-- shared by every client the account plays), and the buffs this client has
	-- that the order lacks follow, in Automatic's order.
	function ns.RepairedBuffOrder(class, keys, kingsFirst)
		local known = ns.BUFF_KEY_ANY_CLIENT and ns.BUFF_KEY_ANY_CLIENT[class]
		if not (known and type(keys) == "table") then return nil end
		local out, seen = {}, {}
		for _, key in ipairs(keys) do
			if type(key) == "string" and known[key] and not seen[key] then
				seen[key] = true
				out[#out + 1] = key
			end
		end
		if #out == 0 then return nil end
		for _, buff in ipairs(Automatic(class, kingsFirst)) do
			if not seen[buff.key] then out[#out + 1] = buff.key end
		end
		return out
	end

	-- One step of `key` up the order (step -1) or down it (step 1), among the
	-- buffs this client has: the first cannot go up nor the last down, and then
	-- nothing changes (false). An order that comes out as Automatic's is not
	-- kept, so Back to Automatic goes with it and the switch comes back.
	function ns.MoveBuff(key, step)
		local db = addon.db and addon.db.profile
		local base = ns.GetClassBuffs(playerClass)
		if not (db and base) then return false end
		local kingsFirst = db.buff.kingsFirst == true
		local auto = {}
		for i, buff in ipairs(Automatic(playerClass, kingsFirst)) do auto[i] = buff.key end
		local saved = ns.BuffOrder()
		local keys = saved and ns.RepairedBuffOrder(playerClass, saved, kingsFirst) or nil
		if not keys then keys = { unpack(auto) } end

		-- Where each of this client's buffs sits in the saved list, in its order.
		local has, here = {}, {}
		for _, buff in ipairs(base) do has[buff.key] = true end
		for i, k in ipairs(keys) do
			if has[k] then here[#here + 1] = i end
		end
		local rank
		for r, i in ipairs(here) do
			if keys[i] == key then rank = r end
		end
		local to = rank and here[rank + step]
		if not to then return false end
		keys[here[rank]], keys[to] = keys[to], keys[here[rank]]

		if type(db.buff.order) ~= "table" then db.buff.order = {} end
		local same = #keys == #auto
		for i = 1, same and #keys or 0 do
			if keys[i] ~= auto[i] then same = false end
		end
		db.buff.order[playerClass] = (not same) and keys or nil
		return true
	end

	-- Back to Automatic: the order of this class goes. False when there was none.
	function ns.ClearBuffOrder()
		local db = addon.db and addon.db.profile
		if not (db and ns.BuffOrder()) then return false end
		db.buff.order[playerClass] = nil
		return true
	end
end

-- Everything of this class the player can actually cast, in list order (the
-- player's own, when one is set: ns.WalkBuffs), once per scan. A neverAuto buff
-- (Unending Breath) and a switched-off one are left out unless pinned: a pin is
-- a deliberate ask, and the options page hides the switches while a spell is
-- pinned.
function ns.CastableBuffs()
	local db = addon.db and addon.db.profile
	local pinned = db and db.buff.choice
	-- "Blessing of Kings first" (Buffs.lua, `strongest`): the strongest buff at
	-- the head of the list, the rest behind it in their own order, so that what
	-- the walk falls back to for somebody Kings does nothing for is what it would
	-- have picked without the switch. Nothing else about the walk changes, which
	-- is what keeps it stable: PickBuffFor's exclusive branch reads the whole list
	-- before it offers anything, so somebody wearing any blessing of yours is
	-- covered however the list is ordered -- never walked onto Kings, and Kings of
	-- yours never walked onto Might or Wisdom -- and somebody wearing Kings from
	-- another paladin is read as theirs and walked on to the next. Kings goes to
	-- somebody wearing none of yours, and nobody flips between the two.
	local strongestFirst = db ~= nil and db.buff.kingsFirst == true
	-- An order of the player's own is the walk as it stands, Kings wherever it
	-- put it: it is what that switch means once there is one.
	local walk, custom = ns.WalkBuffs()
	if custom then strongestFirst = false end
	local out = {}
	for _, buff in ipairs(walk) do
		if ns.IsBuffKnown(buff)
			and (pinned == buff.key or not (db and db.buff.skip and db.buff.skip[buff.key]))
			and (not buff.neverAuto or pinned == buff.key) then
			if strongestFirst and buff.strongest then
				table.insert(out, 1, buff)
			else
				out[#out + 1] = buff
			end
		end
	end
	return out
end

-- The buff of this class that "Blessing of Kings first" puts at the head of the
-- walk (Buffs.lua, `strongest`), learned or not, or nil for a class or a client
-- with none: a paladin's Kings on Classic Era, Burning Crusade and Forever, and
-- nothing on Mists, where it is first in the list already. The options page
-- shows the switch only where there is one.
function ns.StrongestBuff()
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if buff.strongest then return buff end
	end
	return nil
end

-- The neverAuto spells CastableBuffs leaves out, learned and switched on, or
-- nil for none: what a request in chat may still name (Requests.lua,
-- AskedFor). Automatic never walks on to Source of Magic ("Limit 1"), but
-- whoever asks for it by name has asked for it. None under a pin, which is
-- all there is then. No class's buff for others is neverAuto on Forever or
-- Classic Era.
function ns.AskOnlyBuffs()
	local db = addon.db and addon.db.profile
	if not db or ns.PinnedBuff() then return nil end
	local skip = db.buff and db.buff.skip
	local out
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		if buff.neverAuto and ns.IsBuffKnown(buff) and not (skip and skip[buff.key]) then
			out = out or {}
			out[#out + 1] = buff
		end
	end
	return out
end

-- Whether everything this character could offer reaches only its party (a
-- warrior's Battle Shout), so "passers-by" means nothing for them. From the
-- switches and pin rather than listed by class, and shared so the options
-- page, the greeting and the favour line agree. `castable` is CastableBuffs'
-- answer when the caller already has it.
function ns.OnlyReachesGroup(castable)
	castable = castable or ns.CastableBuffs()
	if #castable == 0 then return false end
	for _, buff in ipairs(castable) do
		if not (buff.partyOnly or buff.groupOnly) then return false end
	end
	return true
end

-- Whether "your group", in a sentence about what reaches only your group,
-- is your own subgroup in a raid: a vanilla shout's is (ns.PARTY_IS_SUBGROUP),
-- but Salvation (groupOnly) reaches anybody in the raid.
function ns.GroupMeansSubgroup(castable)
	if not ns.PARTY_IS_SUBGROUP then return false end
	for _, buff in ipairs(castable or ns.CastableBuffs()) do
		if buff.groupOnly and not buff.partyOnly then return false end
	end
	return true
end

-- Whether "Myself" may put a buff on the caster. A shout (selfCast) already
-- covers you, so alone it would nag a solo warrior every time it ran out;
-- notSelf is a spell the game will not put on you, neverSelf one nobody wants
-- on dry land (Buffs.lua: Unending Breath).
function ns.CastsOnSelf(buff)
	return buff ~= nil and not buff.selfCast and not buff.notSelf and not buff.neverSelf
end

-- The buffs "Myself" can offer, out of CastableBuffs' answer (asked here when
-- the caller does not have it): shared by the scan and the options page, which
-- hides the switch from a class that has none.
function ns.SelfBuffs(castable)
	castable = castable or ns.CastableBuffs()
	local out = {}
	for _, buff in ipairs(castable) do
		if ns.CastsOnSelf(buff) then out[#out + 1] = buff end
	end
	return out
end

-- Whether "Myself" is on and has something behind it: one answer for every
-- sentence about who is still offered (the options page, the lines about
-- saving mana), so none leaves you out while the queue keeps you in.
function ns.OffersSelf()
	local db = addon.db and addon.db.profile
	return db ~= nil and db.sources.self == true
		and (#ns.SelfBuffs() > 0 or ns.OwnFamiliesOn() > 0)
end

-- Whether "Myself" has one of your class's own buffs to remind you of. That
-- alone keeps a prompt on a character with nothing for anybody else -- a
-- hunter, a warlock before Unending Breath -- so every line that would say
-- "nothing will be offered" asks this first.
function ns.OwnBuffsLive()
	local db = addon.db and addon.db.profile
	return db ~= nil and db.sources.self == true and ns.OwnFamiliesOn() > 0
end

-- The spell pinned for this character, or nil for Automatic (and for another
-- class's pin). Shared by the walk and the options page so they agree.
function ns.PinnedBuff()
	local db = addon.db and addon.db.profile
	local choice = db and db.buff and db.buff.choice
	if not choice or choice == "auto" then return nil end
	return ns.FindBuff(playerClass, choice)
end

-- A length of time the way a player reads one: "1h", "1h 30m", "5m", "4m 30s",
-- "30s". Seconds are dropped from an hour and more.
function ns.TimeText(seconds)
	local total = math.floor((tonumber(seconds) or 0) + 0.5)
	local hours, minutes, rest = math.floor(total / 3600), math.floor(total % 3600 / 60), total % 60
	if hours > 0 then
		local text = L["%dh"]:format(hours)
		if minutes > 0 then text = text .. " " .. L["%dm"]:format(minutes) end
		return text
	end
	if minutes > 0 then
		local text = L["%dm"]:format(minutes)
		if rest > 0 then text = text .. " " .. L["%ds"]:format(rest) end
		return text
	end
	return L["%ds"]:format(rest)
end

---------------------------------------------------------------------------
-- how early a top-up is offered
--
-- Not one number for every buff: ten minutes of Thorns and an hour of
-- Fortitude are not topped up at the same moment, and nor is the same buff in
-- a raid, where a fight and the drinking after it take minutes, and on a
-- stranger, who will be gone. The lead -- the time left at which a top-up is
-- offered -- is worked out from how long the buff lasts (Buffs.lua, "how long
-- each lasts"; the aura's own `duration` where the client says it):
--
--   lead = clamp(length x 10%, 15 s, 5 min), the five minutes growing by two
--          per hour past the first (7 min for two hours, 10 at the most)
--   then never above the player's ceiling (`refreshUnder`, "Top up at most this
--   long before it ends"), so a profile that said 3 minutes keeps 3 at most,
--   then by who it is for:
--     your group          as it is
--     a raid or a dungeon times `refreshRaid` (two), where you are in one
--     your own buffs      one and a half times (you are not in reach of the
--                         fix once the fight is on), and again the raid's
--     somebody not in your group   half a minute, never more
--   and never more than half of the buff's length, or a top-up would be due
--   the moment it was cast (a three-minute shout, a five-minute blessing).
-- A length nobody knows (no row, or a table of 0 on an aura that has a timer)
-- is the ceiling alone, as every buff was before.
--
-- Worked out per (kind, length) and kept: the memo is dropped when the ceiling
-- or the raid multiplier changes, which is the only time it could differ, so a
-- scan allocates nothing for it after the first of each length.
---------------------------------------------------------------------------
do
	local SHARE, FLOOR, CAP, CAP_PER_HOUR, CAP_MAX = 0.10, 15, 300, 120, 600
	local STRANGER, OWN_SHARE = 30, 1.5
	local STRANGER_KIND, GROUP_KIND, RAID_KIND, OWN_KIND, OWN_RAID_KIND = 1, 2, 3, 4, 5
	ns.LEAD_KINDS = { "stranger", "group", "raid", "own", "ownraid" }
	ns.LEAD_KIND = {}
	for index, name in ipairs(ns.LEAD_KINDS) do ns.LEAD_KIND[name] = index end
	local memo = { {}, {}, {}, {}, {} }
	local memoCeiling, memoRaid

	local function Compute(seconds, kind, ceiling, raid)
		local lead = ceiling
		if seconds then
			lead = seconds * SHARE
			local cap = CAP
			if seconds > 3600 then cap = math.min(CAP_MAX, CAP + CAP_PER_HOUR * (seconds - 3600) / 3600) end
			if lead > cap then lead = cap end
			if lead < FLOOR then lead = FLOOR end
			if lead > ceiling then lead = ceiling end
		end
		if kind == STRANGER_KIND then
			if lead > STRANGER then lead = STRANGER end
		else
			if kind == OWN_KIND or kind == OWN_RAID_KIND then lead = lead * OWN_SHARE end
			if kind == RAID_KIND or kind == OWN_RAID_KIND then lead = lead * raid end
		end
		if seconds and lead > seconds / 2 then lead = seconds / 2 end
		return lead
	end

	-- The lead in seconds for a buff `seconds` long (nil for unknown), of that
	-- kind (one of the five above), under a ceiling of `minutes`.
	function ns.TopUpLead(seconds, kind, minutes)
		local db = addon.db and addon.db.profile
		local f = db and db.filters
		local raid = f and f.refreshRaid
		if type(raid) ~= "number" or raid < 1 then raid = 2 end
		if type(minutes) ~= "number" or minutes < 1 then minutes = 5 end
		if memoCeiling ~= minutes or memoRaid ~= raid then
			for _, perKind in ipairs(memo) do wipe(perKind) end
			memoCeiling, memoRaid = minutes, raid
		end
		if type(seconds) ~= "number" or not (seconds >= 1) then
			seconds = nil
		else
			-- Whole seconds, so a length read as 1799.9 is not a memo entry of its own.
			seconds = math.floor(seconds + 0.5)
		end
		local perKind = memo[kind]
		local key = seconds or 0
		local lead = perKind[key]
		if not lead then
			lead = Compute(seconds, kind, minutes * 60, raid)
			perKind[key] = lead
		end
		return lead
	end

	-- Whether this scan is in a raid or a dungeon: the group's longer lead. At
	-- most one answer per moment (`now`: a scan is one moment), since every
	-- person with a top-up due would ask. A client that will not say is no.
	local raidAt, raidNow = nil, false
	local function Raidish(now)
		if now ~= nil and raidAt == now then return raidNow end
		local yes = plain(IsInRaid and IsInRaid()) == true
		if not yes and type(_G.IsInInstance) == "function" then
			-- Guarded as every other reader of it is: asked once a scan at most
			-- (your own top-ups are worked out on every one), and a client
			-- where it throws is not in one.
			local inside, kind = ns.safecall(_G.IsInInstance)
			inside, kind = plain(inside), plain(kind)
			yes = (inside == true or inside == 1) and (kind == "party" or kind == "raid")
		end
		raidAt, raidNow = now, yes
		return yes
	end

	-- "Top up my own buffs this long before they end" (filters.selfLead,
	-- minutes; 0 is the moment worked out above): an earlier moment for yours
	-- alone, never a later one, and never more than half the buff's length, or
	-- a top-up would be due the moment it was cast.
	local function SelfEarlier(lead, seconds)
		local db = addon.db and addon.db.profile
		local minutes = db and db.filters and db.filters.selfLead
		if type(minutes) ~= "number" or not (minutes >= 1) then return lead end
		local want = minutes * 60
		if seconds and seconds >= 1 and want > seconds / 2 then want = seconds / 2 end
		if want > lead then return want end
		return lead
	end

	-- What "If they already have it" means for your own buffs and the ones you
	-- put on yourself: with "Top up my own buffs before they run out" on, a
	-- top-up whatever it says for other people.
	function ns.SelfWhenBuffed(filters)
		if filters.selfTopUp ~= false then return "refresh" end
		return filters.whenBuffed
	end

	-- The same for one of your own buffs (OwnVerdict), whose ctx has the scan's
	-- `now` and the ceiling.
	function ns.OwnLead(ctx, seconds)
		local kind = Raidish(ctx.now) and OWN_RAID_KIND or OWN_KIND
		return SelfEarlier(ns.TopUpLead(seconds, kind, ctx.refreshUnder), seconds), kind
	end

	-- The lead for one person's buff, from the walk's opts: `own` (yourself),
	-- `inGroup` (in your party or raid), `now` and the ceiling `refreshUnder`.
	-- Also says which kind it was, for the tooltip.
	function ns.LeadFor(opts, seconds)
		local kind
		if opts.own then
			kind = Raidish(opts.now) and OWN_RAID_KIND or OWN_KIND
		elseif not opts.inGroup then
			kind = STRANGER_KIND
		else
			kind = Raidish(opts.now) and RAID_KIND or GROUP_KIND
		end
		local lead = ns.TopUpLead(seconds, kind, opts.refreshUnder)
		if opts.own then lead = SelfEarlier(lead, seconds) end
		return lead, kind
	end
end

-- In a block of its own for the main chunk's 200 locals.
do
	-- Split in two because the exclusive branch needs the halves apart: "wrong
	-- spell for this person" holds for the scan, "tried a moment ago" is a
	-- cooldown. inParty, not inGroup: a shout reaches only the caster's
	-- subgroup (see SameParty).
	local function Castable(opts, buff)
		if opts.relevantOnly and buff.manaOnly and opts.hasMana == false then return false end
		if buff.partyOnly and not opts.inParty then return false end
		-- Salvation: the game refuses it on anybody outside your party or raid.
		if buff.groupOnly and not (opts.inGroup or opts.inParty) then return false end
		return true
	end

	-- opts.blocked is handed opts, so the caller's answer can be a file-level
	-- function rather than a closure made per person.
	local function Blocked(opts, buff)
		if not opts.blocked then return false end
		return opts.blocked(buff, opts) == true
	end

	-- opts.skip, handed opts the same way: "Skip my own class" (Queue.lua,
	-- SelfServed), they could give themselves this one. Wrong spell for this
	-- person, never a cooldown: read as one, every blessing a paladin of 26 or
	-- more could give himself said "offered a moment ago, wait" and he was
	-- offered nothing at all, Kings included.
	local function Skipped(opts, buff)
		return opts.skip ~= nil and opts.skip(buff, opts) == true
	end

	local function Eligible(opts, buff)
		return Castable(opts, buff) and not Skipped(opts, buff) and not Blocked(opts, buff)
	end

	-- How long the buff lasts, for its lead: the aura's own word (UnitHasBuff
	-- hands it on), else the table's for the buff's own cast. nil for unknown.
	local function Length(buff, seconds)
		if type(seconds) == "number" and seconds > 0 then return seconds end
		return (ns.BuffSeconds(buff))
	end

	-- Our own cast on them, read as ours, with more left than a top-up waits
	-- for: a debt (opts.paidUp) is not repaid by refreshing it.
	local function Fresh(opts, mine, remaining, buff, seconds)
		return opts.paidUp ~= nil and mine == true and type(remaining) == "number"
			and remaining > (ns.LeadFor(opts, Length(buff, seconds)))
	end

	-- The candidate list a pin reduces the walk to, reused for every call.
	local PINNED_ONLY = {}

	-- Which of their buffs this person should be offered, or nil for none. Every
	-- castable buff is walked, so holding the first one never hides somebody.
	--
	-- `candidates` comes from CastableBuffs. `has(buff, opts)` answers only the
	-- aura question: has, remaining, mine (their copy is our cast; nil
	-- unknown) and over (a rank above what ours would land, which the game
	-- will not let ours replace). It is handed opts too, like opts.blocked, so
	-- the caller's answer can be a file-level function rather than a closure
	-- per person.
	--   offerAnyway  offer even when they are covered: we owe them a favour, and
	--                a refresh takes nothing away. Never over a stronger rank
	--                (over), which is no refresh: the game refuses it.
	--   paidUp       ...except with what they carry from us with more than the
	--                top-up time left (Fresh): a group member's favour that
	--                has nothing to repay.
	--   rotate       false where there is nothing to walk along: the tokenless
	--                owed path has one buff per favour and cannot verify it.
	--
	-- Returns the buff, whether they hold it (true, false, or nil for "nobody
	-- could tell", which callers keep apart from false), and for a top-up how
	-- long theirs has left, how long it lasts (nil when nobody knows), the
	-- lead that made it due and which kind of lead that was (ns.LEAD_KINDS).
	-- `has` hands back a fifth value after the others, how long the aura
	-- lasts, where the client says.
	function ns.PickBuffFor(candidates, opts, has)
		local db = addon.db and addon.db.profile
		if not db or #candidates == 0 then return nil end

		-- A pin means "only ever this one", no walk. A pin of another class's
		-- (a profile shared with a priest alt) reads as Automatic.
		local pinned = ns.PinnedBuff()
		if pinned then
			if not ns.IsBuffKnown(pinned) then return nil end
			PINNED_ONLY[1] = pinned
			candidates = PINNED_ONLY
		end

		-- Blessings overwrite each other, so holding any one of yours counts as
		-- covered and walking would replace it. Another paladin's blessing
		-- covers nothing of ours (they stack) but is not ours to give; one that
		-- names nobody we can read counts as ours, or ours would be walked over.
		-- Never rotated: see ns.RotatesBuffs.
		if ns.EXCLUSIVE_BUFFS[playerClass] then
			local pick, allRead, onCooldown = nil, true, false
			-- The first blessing they carry from another paladin, kept for a debt
			-- with nothing else left to give: see the end of this branch.
			local theirs
			for _, buff in ipairs(candidates) do
				-- Castable rather than Eligible: the blessing we tried moments ago
				-- is the one they most likely carry, so it must still be read.
				-- A Salvation we cannot cast on them (no longer in our group) is
				-- read too: ours still on them covers them, and the walk would
				-- otherwise offer a blessing that replaces it.
				local castable = Castable(opts, buff)
				if castable or buff.groupOnly then
					-- One they could give themselves is still read: ours on them
					-- covers them like any other, but it is never what they get.
					local skipped = Skipped(opts, buff)
					local held, remaining, mine, over, seconds = has(buff, opts)
					if held == true and mine == false then
						-- Another paladin's: ours of the same kind would only
						-- replace it, so move on to a kind they lack -- unless we
						-- offered this one moments ago, which still means "wait".
						-- One they could give themselves is neither, and nor is
						-- one we cannot cast on them, or one at a rank ours
						-- cannot replace.
						if castable and not skipped then
							if Blocked(opts, buff) then
								onCooldown = true
							elseif not theirs and not over then
								theirs = buff
							end
						end
					elseif held == true then
						-- Covered, and for this class that is the end of it. First
						-- the cooldown: offered one moments ago means wait. One
						-- they could give themselves is covered and no more, and
						-- so is one we cannot cast on them, or one worn at a rank
						-- above ours: nothing to top up.
						if skipped or not castable or Blocked(opts, buff) then return nil, true end
						if over then return nil, true end

						-- The top-up, safest on this class: recasting a blessing
						-- replaces it with itself. Ahead of the debt, as on the
						-- ordinary path, since only `remaining` puts the top-up
						-- wording on the prompt.
						if opts.whenBuffed == "refresh" and remaining then
							seconds = Length(buff, seconds)
							local lead, kind = ns.LeadFor(opts, seconds)
							if remaining <= lead then return buff, true, remaining, seconds, lead, kind end
						end

						-- A debt is repaid with the blessing they already hold
						-- from us (or from nobody we can name), which refreshes it.
						if not opts.offerAnyway or Fresh(opts, mine, remaining, buff, seconds) then return nil, true end
						return buff, true
					elseif castable and not skipped then
						-- "None of mine" only once every one has read back a
						-- definite no: BuildQueue promotes over a debt on has ==
						-- false, and the prompt drops the unverified wording.
						-- Of the ones they could be offered: a kind they give
						-- themselves is passed over, as the ordinary walk does.
						if held ~= false then allRead = false end
						if Blocked(opts, buff) then
							onCooldown = true
						elseif not pick then
							pick = buff
						end
					end
				end
			end
			-- A blessing of yours that is switched off on Who to buff is not in the
			-- list, and is still yours on them: a paladin who gives Salvation by hand
			-- and has it off would otherwise be offered the blessing that a press puts
			-- over it. Read for that alone, never offered: they are covered, and a
			-- debt waits for a blessing that may be given. Not under a pin, which is
			-- "only ever this one" and replaces what they wear as it always did, and
			-- not for somebody who asked for the blessing by name (opts.asked), who
			-- has said what they want on them.
			local skip = db.buff and db.buff.skip
			if not pinned and not opts.asked and skip and next(skip) ~= nil then
				for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
					if skip[buff.key] and ns.IsBuffKnown(buff) then
						local held, _, mine = has(buff, opts)
						if held == true and mine ~= false then return nil, true end
					end
				end
			end
			-- The same for one the game says you cannot pay for at this moment
			-- (Queue.lua, Affordable, which leaves it out of the list): a
			-- paladin short of mana for Kings, with his Kings on somebody, would
			-- otherwise be offered Might for them, and a press puts it over the
			-- Kings. The same exceptions: a pin, and a request by name.
			local unpaid = opts.unpaid
			if not pinned and not opts.asked and unpaid then
				for i = 1, #unpaid do
					local held, _, mine = has(unpaid[i], opts)
					if held == true and mine ~= false then return nil, true end
				end
			end
			-- A blessing on cooldown means this person was just offered one: leave
			-- them alone until it lifts, readable or not. The aura cache is three
			-- seconds deep, so a "none of yours" here is usually the reading from
			-- before the cast, and acting on it would replace the blessing just given.
			if onCooldown then return nil, nil end
			-- A debt, and every blessing we could give is already on them from
			-- another paladin: offer anyway, as the debt policy does for every class.
			if not pick and opts.offerAnyway and theirs then return theirs, true end
			-- Spelled out: `allRead and false or nil` is always nil.
			if allRead then return pick, false end
			return pick, nil
		end

		-- Three answers per candidate: they have it, they definitely do not, and
		-- the client would not say. Something lacked outright wins, in list order.
		local expiring, expiringRemaining, expiringSeconds, expiringLead, expiringKind
		-- Where the rotation below starts, and what it falls back to, gathered on
		-- the way past rather than as a list (this runs 2.5 times a second).
		local last = ns.lastGave and ns.lastGave[opts.name]
		local firstUnknown, afterLast, seenLast
		-- The first thing they are known to carry, for a debt: the offer that
		-- takes nothing away.
		local firstHeld
		for _, buff in ipairs(candidates) do
			if Eligible(opts, buff) then
				local held, remaining, mine, over, seconds = has(buff, opts)
				if held == false then return buff, false end
				if held ~= true then
					if not firstUnknown then firstUnknown = buff end
					if seenLast and not afterLast then afterLast = buff end
				elseif not over then
					-- (Worn at a rank above ours, it is neither: covered, and
					-- ours on top is refused.)
					if not firstHeld and not Fresh(opts, mine, remaining, buff, seconds) then firstHeld = buff end
					if opts.whenBuffed == "refresh" and remaining and not expiring then
						seconds = Length(buff, seconds)
						local lead, kind = ns.LeadFor(opts, seconds)
						if remaining <= lead then
							expiring, expiringRemaining = buff, remaining
							expiringSeconds, expiringLead, expiringKind = seconds, lead, kind
						end
					end
				end
			end
			-- Past `last` whether or not it is eligible: a press blocks it for the
			-- retry cooldown, so it is usually the one that is not.
			if buff.key == last then seenLast = true end
		end

		-- Nothing definitely missing, but something nobody could read: with no
		-- truth to go on, rotate past whatever was given last rather than offering
		-- the top of the list forever. The tokenless owed path (rotate == false)
		-- asks for the first thing it could cast.
		if firstUnknown then
			if opts.rotate == false then return firstUnknown, nil end
			return afterLast or firstUnknown, nil
		end

		if expiring then return expiring, true, expiringRemaining, expiringSeconds, expiringLead, expiringKind end

		-- Nothing missing, nothing running out, and a favour outstanding: offer
		-- what they already hold, with `true` saying they are covered.
		if opts.offerAnyway and firstHeld then return firstHeld, true end

		return nil, true
	end
end

---------------------------------------------------------------------------
-- your own buffs
--
-- The buffs only your class puts on itself (Buffs.lua, VANILLA_OWN), a family
-- at a time: which you know, which to remind you of (your pick, or Automatic:
-- the one you had up last), and whether any is on you now. SelfEntry
-- (Queue.lua), /manners debug and the options page all ask here, so none of
-- them can say something the queue does not do.
---------------------------------------------------------------------------

-- In a block of its own for the main chunk's 200 locals.
do
	-- Tracking (Buffs.lua, TRACKING) is no aura here: the minimap's tracking
	-- list says what is on, by spell id, as EnhanceQoL's Forever build reads
	-- it. Kept a second, or until the client says it changed; nil while the
	-- client has not filled it in, or on a client without the list.
	local trackingAt, trackingList
	local function TrackingList()
		local now = GetTime()
		if trackingList and now - trackingAt < 1 then return trackingList end
		local api = _G.C_Minimap
		if not (api and type(api.GetNumTrackingTypes) == "function"
			and type(api.GetTrackingInfo) == "function") then return nil end
		local count = plain(api.GetNumTrackingTypes())
		if type(count) ~= "number" then return nil end
		local list = {}
		for index = 1, count do
			local info = api.GetTrackingInfo(index)
			-- Not a table: not filled in yet, or an older shape of the call.
			if type(info) ~= "table" then return nil end
			local id = plain(info.spellID)
			if type(id) == "number" then list[id] = plain(info.active) == true end
		end
		trackingList, trackingAt = list, now
		return list
	end
	function ns.ForgetTrackingList() trackingList = nil end

	-- The mage's scrolls and every class's weapon enhancements (Buffs.lua) are
	-- items, not spells. How many of each the bags hold, read for every item of
	-- your class at once and kept until BAG_UPDATE_DELAYED says the bags
	-- changed, with the first of each family held and whether any is; and the
	-- weapon type in each hand (its item subclass, false for none), kept until
	-- PLAYER_EQUIPMENT_CHANGED. nil is "read it when next asked". No bag walk:
	-- GetItemCount on the items' own ids alone, once each however many families
	-- list it (a poison is in the main hand's and the off hand's).
	local scrollCounts, hands, heldFirst, anyHeld
	function ns.ForgetScrolls() scrollCounts = nil end
	function ns.ForgetHands() hands = nil end

	local function ScrollCount(spell)
		if not scrollCounts then
			scrollCounts, heldFirst, anyHeld = {}, {}, false
			local count = C_Item and C_Item.GetItemCount
			if type(count) == "function" then
				for _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do
					for _, scroll in ipairs(family.scroll and family.spells or {}) do
						local n = scrollCounts[scroll.item] or plain(count(scroll.item))
						scrollCounts[scroll.item] = type(n) == "number" and n or 0
						if scrollCounts[scroll.item] > 0 then
							heldFirst[family] = heldFirst[family] or scroll
							anyHeld = true
						end
					end
				end
			end
		end
		return scrollCounts[spell.item] or 0
	end

	-- Whether the bags hold any item of your class's own buffs at all: what lets
	-- a rogue with a poison and nothing learned have a prompt (CanCastAnything).
	-- Asks for a count to have the bags read where they have not been.
	local NO_ITEM = { item = 0 }
	function ns.OwnItemsHeld()
		ScrollCount(NO_ITEM)
		return anyHeld == true
	end

	-- The item subclass of the weapon in a hand (its inventory slot, 16 or 17),
	-- false for none. Class 2 is a weapon; a shield, or a book or an orb held in
	-- the off hand, is not one, and takes nothing.
	local function HandWeapon(slot)
		hands = hands or {}
		local held = hands[slot]
		if held == nil then
			held = false
			local id = type(_G.GetInventoryItemID) == "function" and plain(_G.GetInventoryItemID("player", slot)) or nil
			local instant = C_Item and C_Item.GetItemInfoInstant
			if type(id) == "number" and type(instant) == "function" then
				local _, _, _, _, _, class, subclass = instant(id)
				class, subclass = plain(class), plain(subclass)
				if class == 2 and type(subclass) == "number" then held = subclass end
			end
			hands[slot] = held
		end
		return held
	end

	-- Whether a weapon of that subclass is one a mask of subclasses names
	-- (Buffs.lua, `fits`: bit n for subclass n). Plain arithmetic: the mask
	-- reaches bit 20.
	local function Fits(mask, subclass)
		return type(subclass) == "number" and math.floor(mask / 2 ^ subclass) % 2 == 1
	end

	-- Whether a scroll or an enhancement can be used now, or why not: "bags"
	-- (none in them), "noweapon" (one for a weapon, and no weapon in that hand:
	-- the main hand for an imbue, the hand of its family for an enhancement),
	-- "level" (yours is short of it) or "weapon" (one for another kind of weapon
	-- than the one in that hand). No weapon before the level: it holds back
	-- every imbue, and the line about the family said a scroll did not fit a
	-- weapon that was not there.
	local function ScrollReady(spell)
		if ScrollCount(spell) <= 0 then return false, "bags" end
		local hand = (spell.weapon or spell.fits) and HandWeapon(spell.family and spell.family.slot or 16)
		if hand == false then return false, "noweapon" end
		local level = plain(UnitLevel("player"))
		if type(level) ~= "number" or level < spell.level then return false, "level" end
		if spell.weapon and hand ~= spell.weapon then return false, "weapon" end
		if spell.fits and not Fits(spell.fits, hand) then return false, "weapon" end
		return true
	end

	-- For the bug report (Options/Diagnostics.lua): the answer the queue reads.
	ns.ScrollReady = ScrollReady

	local function Known(spell)
		-- A scroll counts while there is one in the bags: its family is shown
		-- and read; whether it can be used is ScrollReady's.
		if spell.item then return ScrollCount(spell) > 0 end
		local info = caps.own and caps.own[spell.key]
		if not (info ~= nil and info.known == true) then return false end
		-- A tracking spell counts only when the minimap lists it: the list is
		-- what says whether it is on, so one it does not list could never read
		-- as on and would be offered for ever.
		if spell.family and spell.family.tracking then
			local list = TrackingList()
			if not list then return false end
			for _, id in ipairs(spell.ranks) do
				if list[id] ~= nil then return true end
			end
			return false
		end
		return true
	end
	ns.OwnSpellKnown = Known

	-- The first spell of the family you know, in table order; `auto` passes
	-- over the ones Automatic never picks.
	local function FirstKnown(family, auto)
		-- A weapon enhancement family: the first of its items the bags hold, as
		-- they were last read, which is all of this family that is ever asked.
		if family.enhance then
			ScrollCount(family.spells[1])
			return heldFirst[family]
		end
		for _, spell in ipairs(family.spells) do
			if Known(spell) and not (auto and spell.neverAuto) then return spell end
		end
		return nil
	end

	-- Nothing outside these is read, offered or shown on the options page.
	function ns.KnownOwnFamilies()
		local out = {}
		for _, family in ipairs(ns.GetOwnFamilies(playerClass) or {}) do
			if FirstKnown(family) then out[#out + 1] = family end
		end
		return out
	end

	-- What a family is called on the page and in chat: its own word for a
	-- family of several ("Armor"), the spell's name for one alone.
	function ns.OwnFamilyLabel(family)
		-- An enhancement for a hand says which: "Poison (Main Hand)".
		if family.enhance then return family.label .. " (" .. ns.HandName(family.slot) .. ")" end
		if family.label then return family.label end
		return ns.BuffName(FirstKnown(family) or family.spells[1])
	end

	-- The pick for a family: "off", "auto", or the key of a spell you know,
	-- with the spell second. A spell you do not know -- the profile is shared
	-- with an alt who does -- reads as Automatic, as another class's pin does
	-- for the buffs you give. A scroll stays the pick with none in the bags:
	-- the dropdown lists every scroll, and the pick is offered once there is
	-- one to use (OwnVerdict says why not until then). One above your level
	-- reads as Automatic while Automatic has one of the family to use (an alt
	-- on the main's profile, carrying Rats under the main's Cat), and takes
	-- over again at its level; the dropdown keeps showing it.
	function ns.OwnPick(family)
		local db = addon.db and addon.db.profile
		local picks = db and db.ownBuffs and db.ownBuffs.pick
		local pick = type(picks) == "table" and picks[family.key] or nil
		if pick == "off" then return "off" end
		local spell = ns.FindOwnSpell(pick)
		if spell and spell.family == family and (spell.item or Known(spell)) then return spell.key, spell end
		return "auto"
	end

	function ns.OwnFamiliesOn()
		local count = 0
		for _, family in ipairs(ns.KnownOwnFamilies()) do
			if ns.OwnPick(family) ~= "off" then count = count + 1 end
		end
		return count
	end

	-- The one you had up last, per character (db.char): what one character
	-- runs says nothing about an alt sharing the profile. A scroll only while
	-- you can use one now: in the bags, your level, your weapon.
	local function Remembered(family)
		local char = addon.db and addon.db.char
		local memory = type(char) == "table" and char.ownLast
		local spell = type(memory) == "table" and ns.FindOwnSpell(memory[family.key]) or nil
		if spell and spell.family == family and not spell.neverAuto and Known(spell)
			and not (spell.item and not ScrollReady(spell)) then return spell end
		return nil
	end

	-- Written only from a reading of your own auras (ReadOwnFamily), never
	-- from a guess or a press: a press the game refuses has put nothing up.
	local function Remember(family, spell)
		if spell.neverAuto then return end
		local char = addon.db and addon.db.char
		if type(char) ~= "table" then return end
		if type(char.ownLast) ~= "table" then char.ownLast = {} end
		char.ownLast[family.key] = spell.key
	end

	-- Whether you are the tank: only a role the game names, in a group. Solo,
	-- or with no role set, nobody is.
	local function Tanking()
		if (plain(GetNumGroupMembers and GetNumGroupMembers()) or 0) <= 0 then return false end
		return safecall(_G.UnitGroupRolesAssigned, "player") == "TANK"
	end

	-- In a dungeon or a raid, by the game's word. A battleground is not one.
	local function InDungeon()
		local ok, inside, kind = pcall(_G.IsInInstance)
		if not ok then return false end
		inside, kind = plain(inside), plain(kind)
		return (inside == true or inside == 1) and (kind == "party" or kind == "raid")
	end

	-- What Automatic reminds you of in this family right now, and why:
	--   "tank"     a family for the tank, and your group role is tank
	--   "notank"   it is not, so nothing (the spell is nil)
	--   "last"     the one you had up last
	--   "dungeon"  the family's pick for a dungeon or raid, before you have
	--              had one up; "world" its first other spell outside one
	--   "first"    the first you know, before you have had one up
	--   "best"     a scroll: the first you can use now in the table's order,
	--              which is best first, before you have used one
	--   "covered"  a shared family (Buffs.lua): the one it would pick reaches
	--              you already from somebody else of your class, so the next
	--              you know that does not; nil, and the one covered, for none
	-- nil and nil for a family you know nothing of. Scrolls in the bags none
	-- of which you can use now answer nil, why not ("noweapon", "level" or
	-- "weapon"), and the best of them, so the line about it can say which.
	--
	-- The dungeon pick splits the answer in two only once it is learned: a
	-- mage below 34 gets the same armor inside and out, and is told so as
	-- "first" in both places, never as a choice between two that is not one.
	local OthersOnYou
	local function AutoAnswer(family)
		local last = Remembered(family)
		if last then return last, "last" end
		if family.scroll then
			local held, heldWhy
			for _, spell in ipairs(family.spells) do
				local ready, why = ScrollReady(spell)
				if ready then return spell, "best" end
				if why ~= "bags" and not held then held, heldWhy = spell, why end
			end
			if held then return nil, heldWhy, held end
			return nil, nil
		end
		local preferred = family.dungeon and ns.FindOwnSpell(family.dungeon)
		if preferred and Known(preferred) then
			if InDungeon() then return preferred, "dungeon" end
			for _, spell in ipairs(family.spells) do
				if spell ~= preferred and Known(spell) and not spell.neverAuto then return spell, "world" end
			end
		end
		local first = FirstKnown(family, true)
		return first, first and "first" or nil
	end

	function ns.OwnAutoPick(family)
		if family.tank then
			if not Tanking() then return nil, "notank" end
			return FirstKnown(family, true), "tank"
		end
		local spell, why, held = AutoAnswer(family)
		-- Another paladin's Devotion Aura, another hunter's Trueshot Aura on
		-- you: a second copy of yours would not stack. Asked first of the
		-- answer Automatic has, and of the rest only when that one is theirs.
		if spell and family.shared and OthersOnYou(spell) then
			for _, other in ipairs(family.spells) do
				if other ~= spell and Known(other) and not other.neverAuto and not OthersOnYou(other) then
					return other, "covered"
				end
			end
			return nil, "covered", spell
		end
		return spell, why, held
	end

	-- The spell of the active shapeshift form. A paladin's auras are forms on
	-- this client, and the form is yours whatever another paladin's aura on
	-- you says. pcall rather than safecall, which keeps three returns: the
	-- spell is the fourth.
	local function ActiveForm()
		local count = safecall(_G.GetNumShapeshiftForms)
		if type(count) ~= "number" or type(_G.GetShapeshiftFormInfo) ~= "function" then return nil end
		for i = 1, math.min(count, 10) do
			local ok, _, active, _, spellId = pcall(_G.GetShapeshiftFormInfo, i)
			if ok and plain(active) then return plain(spellId) end
		end
		return nil
	end

	-- Whether an aura on you is yours: false only for somebody else's --
	-- another paladin's aura, another hunter's Aspect of the Pack -- which
	-- says nothing about your own; nil for one naming nobody we can read,
	-- which counts as yours, since reading it as missing could only nag.
	local function FromYou(aura)
		local source = plain(aura.sourceUnit)
		if type(source) ~= "string" then return nil end
		local same = safecall(UnitIsUnit, source, "player")
		if same == nil then return nil end
		return same == true
	end

	-- A value the client will not let us look at: a refusal, never absence.
	local function Withheld(value)
		return issecretvalue ~= nil and issecretvalue(value) == true
	end

	-- Whether somebody else's copy of a spell is on you (FromYou false): a
	-- party aura from another of your class. Read by id directly, since a
	-- spell id never throws; a refusal is no answer, so not theirs.
	OthersOnYou = function(spell)
		local api = C_UnitAuras
		local byId = api and api.GetUnitAuraBySpellID
		if type(byId) ~= "function" then return false end
		for _, id in ipairs(spell.auraIds) do
			local aura = byId("player", id)
			if not Withheld(aura) and type(aura) == "table" and FromYou(aura) == false then return true end
		end
		return false
	end

	-- Whether an aura read that came back empty may only be hiding it. The
	-- reads by id and by name hand back nothing at all for an aura the client
	-- keeps secret just now (a battleground match, say), so a buff you are
	-- wearing read as missing and every press cast it again. Asked of the
	-- client at read time, not the probe's note: the restriction can start
	-- after the probe ran. Only for an empty read, so a buff that reads as up
	-- costs nothing; called directly, since a spell id never throws.
	local function HiddenAura(id)
		local secrets = C_Secrets
		local ask = secrets and secrets.ShouldSpellAuraBeSecret
		return type(ask) == "function" and plain(ask(id)) == true
	end

	-- How long the aura just read lasts in all, where the client says: what
	-- OwnVerdict works a top-up's lead from before it falls back on the table
	-- (Buffs.lua). Written by Left, cleared when a reading starts.
	local ownSeconds

	-- Seconds left, nil for no timer: a toggle, or one the game hides.
	local function Left(aura, now)
		local expires = plain(aura.expirationTime)
		local length = plain(aura.duration)
		ownSeconds = type(length) == "number" and length > 0 and length or nil
		if type(expires) == "number" and expires > 0 then return expires - now end
		return nil
	end

	-- The family by the names of the ranks you know (ProbeBuff), for a rank
	-- the table lacks: the client's own lookup by name where it has one, else
	-- your aura list walked, both filtered to auras you cast, so another
	-- paladin's Devotion Aura read first never hides yours. The spell and its
	-- time left (and its charges, as the client counts them), or nil, nil and
	-- whether the client refused to say.
	local function ByName(family, now)
		local api = C_UnitAuras
		local lookup = api and api.GetAuraDataBySpellName
		local walk = api and api.GetAuraDataByIndex
		local refused = false
		for _, spell in ipairs(family.spells) do
			local info = caps.own and caps.own[spell.key]
			for name in pairs(Known(spell) and info.names or {}) do
				if type(lookup) == "function" then
					local ok, aura = pcall(lookup, "player", name, "HELPFUL|PLAYER")
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" and FromYou(aura) ~= false then
						return spell, Left(aura, now), plain(aura.applications)
					end
				elseif type(walk) == "function" then
					for i = 1, 40 do
						local ok, aura = pcall(walk, "player", i, "HELPFUL|PLAYER")
						if not ok or Withheld(aura) then
							refused = true
							break
						end
						if type(aura) ~= "table" then break end
						if plain(aura.name) == name and FromYou(aura) ~= false then
							return spell, Left(aura, now), plain(aura.applications)
						end
					end
				else
					refused = true
				end
			end
		end
		return nil, nil, nil, refused
	end

	-- The scroll last used from the prompt, per family, this session: the one
	-- word on which of two scrolls making the same enchant (Buffs.lua,
	-- Spellbreak and Lesser Flame) is on the weapon. Noted when the press
	-- settles (Clicks.lua, SettleSelf), which is handed the one it replaced,
	-- and put back to that if the cast is cut short.
	--
	-- A hand an enhancement was just put on is busy until the cast is over (the
	-- longest is a lure's five seconds): the weapon carries nothing yet, and
	-- another family of the same hand -- an oil after a stone -- would be offered
	-- over the one going on. Let go at the cast's end, or when it is cut short.
	local pressedScroll, busyUntil = {}, {}
	local HAND_BUSY = 8
	function ns.NoteScrollPress(spell)
		local before = pressedScroll[spell.family.key]
		pressedScroll[spell.family.key] = spell
		if spell.family.enhance then busyUntil[spell.family.slot] = GetTime() + HAND_BUSY end
		return before
	end
	function ns.UndoScrollPress(spell, before)
		if pressedScroll[spell.family.key] == spell then pressedScroll[spell.family.key] = before end
		if spell.family.enhance then busyUntil[spell.family.slot] = nil end
	end
	-- The cast went through: the enchant is on the weapon, so the hand is free
	-- at once (the eight seconds are for a cast that never reports its end).
	-- The press itself stays noted: ImbueScroll names the scroll by it.
	function ns.EndScrollPress(spell)
		if spell.family.enhance then busyUntil[spell.family.slot] = nil end
	end
	-- Whether an enhancement was put on this hand a moment ago (OwnVerdict).
	function ns.HandBusy(slot, now)
		local endsAt = busyUntil[slot]
		return endsAt ~= nil and now < endsAt
	end

	-- The scroll whose enchant `enchant` is; nil for an enchant no scroll
	-- makes, a wizard oil say. Two scrolls can make the same one, so: the one
	-- just used from the prompt; else the one you had on last, at your level;
	-- else the first you can use now; else the first your level allows.
	local function ImbueScroll(family, enchant)
		if type(enchant) ~= "number" then return nil end
		local pressed = pressedScroll[family.key]
		if pressed and pressed.enchant == enchant then return pressed end
		local level = plain(UnitLevel("player"))
		if type(level) ~= "number" then level = math.huge end
		local char = addon.db and addon.db.char
		local memory = type(char) == "table" and type(char.ownLast) == "table"
			and ns.FindOwnSpell(char.ownLast[family.key]) or nil
		if memory and memory.family == family and memory.enchant == enchant and memory.level <= level then
			return memory
		end
		local reached, first
		for _, spell in ipairs(family.spells) do
			if spell.enchant == enchant then
				if ScrollReady(spell) then return spell end
				if not reached and spell.level <= level then reached = spell end
				first = first or spell
			end
		end
		return reached or first
	end

	-- A weapon imbue (Buffs.lua) is no aura: up is your main hand carrying an
	-- enchant of the Imbue kind, a scroll's or another; a permanent enchant
	-- never counts. The scrolls' enchant is of that kind, which
	-- C_PaperDollInfo.GetTemporaryEnchantmentInfo and the GetWeaponEnchantInfo
	-- shim over it never report: read with those, an imbue on was nothing on
	-- and the reminder asked again. So the list the client's own buff bar
	-- reads, C_Item.GetWeaponEnchantInfo, every kind of enchant on the weapon;
	-- the old calls only where it is missing. A secret is the client not
	-- saying. None throws (the slot is a plain number), so no pcall. Time left
	-- in seconds; the client gives milliseconds.
	--
	-- A weapon enhancement (Buffs.lua) is read the same way for its own hand,
	-- the family's `slot`: the main hand, or the off hand, whose enchants are
	-- the list for Enum.WeaponSlot.OffHand, the temporary enchant of slot 17,
	-- and the second four values of GetWeaponEnchantInfo.
	--
	-- On the list, which is Forever's alone, a hand carries an Imbue enchant (a
	-- shaman's Rockbiter Weapon, a poison, a scroll) and a Temporary one (a
	-- stone, an oil, a lure) at once, so a family is up only for an enchant of
	-- its own kind, which Buffs.lua says (`enchantKind`, of the family, or of
	-- the spell the enchant is one of the family's). Of its own kind means
	-- listed as that kind: an oil on the hand is no scroll's imbue, and
	-- Rockbiter is no oil. Two exceptions, both about what the client says:
	-- an enchant one of the family's own items makes is up whatever kind it is
	-- listed as, and one listed as other than the data says is the client's
	-- word, kept for the family for the rest of the session (`learnedKind`),
	-- so a datum that was misjudged does not keep a reminder wrong. And an
	-- enchant of the other kind whose id is hidden might be one of those: no
	-- answer, never a reason to offer. A family with no kind in its data takes
	-- any temporary or imbue enchant, as the clients that list no kind do.
	local learnedKind = {}
	local function WeaponSlot(family, slots)
		if family.slot == 17 then return slots and slots.OffHand or 1 end
		return slots and slots.MainHand or 0
	end

	-- Whether an enchant on the family's hand, listed as `listed` ("imbue" or
	-- "temporary"), counts for the family, by `scroll`, the family's spell
	-- that makes it (nil for none): true, false, or nil for not telling (the
	-- enchant's id is hidden). ReadImbue asks it of each enchant on the hand.
	local function CountsFor(family, scroll, id, listed)
		local own = learnedKind[family.key] or family.enchantKind
		if scroll then
			local data = learnedKind[family.key] or scroll.enchantKind or own
			if data and listed ~= data then learnedKind[family.key] = listed end
			return true
		end
		if own == nil or listed == own then return true end
		if id == nil then return nil end
		return false
	end

	local function ReadImbue(family)
		local has, expires, enchant
		local list = C_Item and C_Item.GetWeaponEnchantInfo
		local api = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
		if type(list) == "function" then
			local slots, kinds = Enum and Enum.WeaponSlot, Enum and Enum.ItemEnchantType
			local temporary, imbue = kinds and kinds.Temporary or 2, kinds and kinds.Imbue or 3
			local entries = plain(list(WeaponSlot(family, slots)))
			if type(entries) ~= "table" then return nil end
			local unknown, named = false, false
			for _, info in ipairs(entries) do
				local on, kind
				if type(info) == "table" and not Withheld(info) then
					on, kind = plain(info.hasEnchant), plain(info.enchantType)
				end
				if on == nil or (on == true and kind == nil) then
					unknown = true
				elseif on == true and (kind == temporary or kind == imbue) then
					-- One of the family's own kind counts; a scroll's, with
					-- another enchant of the same kind beside it, is the one named,
					-- remembered and topped up.
					local id = plain(info.enchantID)
					local scroll = ImbueScroll(family, id)
					local made = scroll ~= nil
					local counts = CountsFor(family, scroll, id, kind == imbue and "imbue" or "temporary")
					if counts == nil then unknown = true end
					if counts and (not has or (made and not named)) then
						has, enchant, expires, named = true, id, plain(info.timeLeft), made
					end
				end
			end
			if not has then
				if unknown then return nil end
				return false
			end
		elseif type(api) == "function" then
			-- INVSLOT_MAINHAND, or INVSLOT_OFFHAND for the off hand's family.
			local info = api(family.slot or 16)
			if Withheld(info) then return nil end
			if info == nil then return false end
			if type(info) ~= "table" then return nil end
			has, enchant = true, plain(info.enchantID)
			if plain(info.hasExpirationTime) ~= false then expires = plain(info.remainingTimeMs) end
		else
			local read = _G.GetWeaponEnchantInfo
			if type(read) ~= "function" then return nil end
			local _
			if family.slot == 17 then
				-- Four values to a hand, the main hand's first, the off hand's next.
				has, expires, _, enchant = select(5, read())
			else
				has, expires, _, enchant = read()
			end
			if Withheld(has) then return nil end
			if not has then return false end
			expires, enchant = plain(expires), plain(enchant)
		end
		local scroll = ImbueScroll(family, enchant)
		if scroll then Remember(family, scroll) end
		local left
		if type(expires) == "number" and expires > 0 then left = expires / 1000 end
		return true, scroll, left
	end

	-- A familiar (Buffs.lua) is its aura on you, from you. Read the one you had
	-- up last first, whatever your level says now, then the rest your level
	-- allows (a scroll asks for its level, and nothing else puts the aura on):
	-- one aura read on a scan where it is up, where reading all three best
	-- first was three, and a level-12 mage reads the Rat's alone.
	local function ReadFamiliar(family, byId, now)
		local char = addon.db and addon.db.char
		local last = type(char) == "table" and type(char.ownLast) == "table"
			and ns.FindOwnSpell(char.ownLast[family.key]) or nil
		if not (last and last.family == family) then last = nil end
		local level = plain(UnitLevel("player"))
		if type(level) ~= "number" then level = math.huge end
		local refused = false
		for i = 0, #family.spells do
			local spell = family.spells[i]
			if i == 0 then
				spell = last
			elseif spell == last or spell.level > level then
				spell = nil
			end
			if spell then
				for _, id in ipairs(spell.auraIds) do
					local ok, aura = pcall(byId, "player", id)
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" and FromYou(aura) ~= false then
						Remember(family, spell)
						return true, spell, Left(aura, now)
					elseif aura == nil and not refused and HiddenAura(id) then
						refused = true
					end
				end
			end
		end
		if refused then return nil end
		return false
	end

	-- Whether any of the family is up on you, and yours: true with the spell,
	-- its time left and the charges it has left (the aura's applications, for
	-- a charge shield), false for definitely none, nil for the client would not say
	-- (never a reason to offer). By the ids AND by the names of the ranks you
	-- know. The one found up is remembered for Automatic: the only place that is
	-- written.
	function ns.ReadOwnFamily(family)
		ownSeconds = nil
		if family.tracking then
			local list = TrackingList()
			if not list then return nil end
			for _, spell in ipairs(family.spells) do
				if Known(spell) then
					for _, id in ipairs(spell.ranks) do
						if list[id] == true then
							Remember(family, spell)
							return true, spell, nil
						end
					end
				end
			end
			return false
		end
		if family.imbue then return ReadImbue(family) end
		-- A stone, a poison, an oil or a lure: its hand carries an enchant or not.
		if family.enhance then return ReadImbue(family) end
		local now = GetTime()
		local api = C_UnitAuras
		local byId = api and api.GetUnitAuraBySpellID
		-- Every familiar, whether or not another of its scroll is in the bags:
		-- the one summoned is up all the same. No form read: it is no form.
		if family.scroll then
			if type(byId) ~= "function" then return nil end
			return ReadFamiliar(family, byId, now)
		end
		local form = ActiveForm()
		local formSpell = form and ns.OWN_BY_ID[form]
		if formSpell and formSpell.family == family then
			Remember(family, formSpell)
			return true, formSpell, nil
		end
		if type(byId) ~= "function" then return nil end
		local refused = false
		for _, spell in ipairs(family.spells) do
			if Known(spell) then
				for _, id in ipairs(spell.auraIds) do
					local ok, aura = pcall(byId, "player", id)
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" and FromYou(aura) ~= false then
						Remember(family, spell)
						return true, spell, Left(aura, now), plain(aura.applications)
					elseif aura == nil and not refused and HiddenAura(id) then
						refused = true
					end
				end
			end
		end
		local named, left, applications, nameRefused = ByName(family, now)
		if named then
			Remember(family, named)
			return true, named, left, applications
		end
		-- Somebody else's of a spell that fills the family whoever cast it
		-- (Buffs.lua, anyCaster): another shaman's Earth Shield, which any
		-- shield of yours would replace. Up whether or not you know the spell;
		-- never remembered, and no time left, so nothing tops it up either.
		for _, spell in ipairs(family.spells) do
			if spell.anyCaster then
				for _, id in ipairs(spell.auraIds) do
					local ok, aura = pcall(byId, "player", id)
					if not ok or Withheld(aura) then
						refused = true
					elseif type(aura) == "table" then
						return true, spell
					elseif aura == nil and not refused and HiddenAura(id) then
						refused = true
					end
				end
			end
		end
		if refused or nameRefused then return nil end
		return false
	end

	-- The client's word on whether it can be cast now: a druid in cat form,
	-- a priest in Shadowform or a mage out of mana is not reminded of a press
	-- that would fail. A client that will not say is taken at its word.
	local function Usable(spell)
		local info = caps.own and caps.own[spell.key]
		local check = C_Spell and C_Spell.IsSpellUsable
		if type(check) ~= "function" then check = _G.IsUsableSpell end
		return safecall(check, info and info.topRank or spell.ranks[1]) ~= false
	end

	-- One family's answer, for the queue and for everything that explains it:
	-- the spell to offer (nil for none), the reading (true, false or nil),
	-- the time left for a top-up, and why nothing is offered, with the spell
	-- concerned where there is one:
	--   "off"       Don't remind me
	--   "unread"    the client would not say whether any of it is up
	--   "notank"    Automatic, for a tank's family, and you are not one
	--   "none"      Automatic has nothing it would pick
	--   "up"        one of it is up (and is no top-up)
	--   "tried"     pressed or skipped a moment ago
	--   "unusable"  the game says it cannot be cast now
	--   "bags"      a scroll: none of it in your bags
	--   "noweapon"  an imbue: there is no weapon in your main hand
	--   "level"     a scroll: your level is short of it
	--   "weapon"    an imbue: not for the weapon in your main hand
	-- Reminded only when none of the family is up; a timed buff (never a
	-- toggle) also when it runs low with top-ups on, as for anybody, and a
	-- charge shield (Buffs.lua, charges) down to its last few charges, which
	-- the first hits of the next pull would take: then the sixth return is
	-- the charges it has left. A top-up goes on with how long the buff lasts
	-- (nil when nobody knows), the lead that made it due and its kind, as
	-- the seventh to ninth returns (ns.LeadFor). `ctx` is the scan's: name,
	-- now, whenBuffed, refreshUnder.
	function ns.OwnVerdict(family, ctx)
		local pick, spell = ns.OwnPick(family)
		if pick == "off" then return nil, nil, nil, "off" end
		-- A scroll picked above your level steps aside for Automatic while it
		-- has a scroll of the family you can use (see ns.OwnPick).
		if spell and spell.item then
			local level = plain(UnitLevel("player"))
			if type(level) == "number" and level < spell.level and ns.OwnAutoPick(family) then spell = nil end
		end
		local up, upSpell, left, charges = ns.ReadOwnFamily(family)
		if up == nil then return nil, nil, nil, "unread" end
		local seconds, lead, kind
		-- Scrolls Automatic found in the bags and none usable: why not, and which.
		local held, heldWhy
		if not spell then
			local why
			spell, why, held = ns.OwnAutoPick(family)
			if why == "notank" then return nil, up, nil, "notank" end
			heldWhy = why
		end
		if up then
			-- Down to its last charge (Lightning Shield, Shadowguard), or a
			-- quarter of them (Inner Fire's 20): only on a plain count.
			local spent = upSpell and upSpell.charges and type(charges) == "number" and charges >= 1
				and charges <= math.max(1, math.floor(upSpell.charges / 4))
			if not spent then charges = nil end
			-- How long it lasts and when a top-up is due: yours, so earlier than
			-- somebody else's (ns.OwnLead).
			if ctx.whenBuffed == "refresh" and left then
				seconds = ownSeconds or ns.OwnSeconds(upSpell)
				lead, kind = ns.OwnLead(ctx, seconds)
			end
			if family.toggle or ctx.whenBuffed ~= "refresh"
				or (not spent and (not left or left > lead)) then
				return nil, true, left, "up", upSpell
			end
			-- An oil, or an enchant no scroll makes, running low: nothing of
			-- yours tops it up, and the weapon is seen to until it runs out.
			if not upSpell then return nil, true, left, "up" end
			-- The top-up is of the one you are wearing, whatever the pick.
			spell = upSpell
			-- Of the enchant you are wearing, that is: a scroll that makes the
			-- same one (Spellbreak and Lesser Flame, Buffs.lua) tops it up when
			-- the one named has run out. The last Spellbreak used, and nothing
			-- was offered until the enchant wore off, with five Lesser Flames
			-- in the bags.
			if spell.item and spell.enchant and not ScrollReady(spell) then
				for _, twin in ipairs(family.spells) do
					if twin ~= spell and twin.enchant == spell.enchant and ScrollReady(twin) then
						spell = twin
						break
					end
				end
			end
		end
		-- Only spells Automatic never picks are known (a hunter with nothing
		-- but the Cheetah): nothing to remind you of.
		if not spell then
			if held and not up then return nil, up, nil, heldWhy, held end
			return nil, up, nil, "none"
		end
		if ns.IsBlocked(ctx.name, spell.key, ctx.now) then return nil, up, left, "tried", spell end
		-- The hand an enhancement was just put on is busy until the cast is over
		-- (NoteScrollPress): nothing else is offered for it in the meantime.
		if spell.family.enhance and ns.HandBusy(spell.family.slot, ctx.now) then
			return nil, up, left, "tried", spell
		end
		-- A scroll is used, not cast: the bags, your level and your weapon
		-- answer for it rather than the spellbook.
		if spell.item then
			local ready, why = ScrollReady(spell)
			if not ready then return nil, up, left, why, spell end
		elseif not Usable(spell) then
			return nil, up, left, "unusable", spell
		end
		return spell, up, up and left or nil, nil, nil, up and charges or nil, seconds, lead, kind
	end

	-- "The one you had up last", kept current whatever the queue is doing. The
	-- queue reads your families only when it could offer you one, so a fight, a
	-- city or an earlier family missing would leave Automatic on the aura of an
	-- hour ago: the paladin who switched to Concentration mid-fight and died
	-- would be reminded of Devotion. UNIT_AURA on you (Favours.lua) asks for one
	-- reading of each family on the next tick, which writes the memory
	-- (ReadOwnFamily); a refused reading writes nothing. Asked once at load too.
	ns.ownAurasChanged = true
	function ns.RememberOwnBuffs()
		ns.ownAurasChanged = false
		for _, family in ipairs(ns.KnownOwnFamilies()) do ns.ReadOwnFamily(family) end
	end
end

-- The one spell named as "the spell you are about to cast" (login line,
-- preview, Roll a few, {spell}, /manners look), so it must be one the queue
-- would really offer, or nil. hasMana is passed in so the caller can reuse it.
function ns.ResolveBuff(hasMana)
	local db = addon.db and addon.db.profile
	if not db then return nil end

	-- A pin is the only spell the walk considers, learned or not, so an
	-- unlearned pin names nothing rather than falling through to Automatic.
	local pinned = ns.PinnedBuff()
	if pinned then return ns.IsBuffKnown(pinned) and pinned or nil end

	-- The player's own order: the first of it the walk would offer, under the
	-- same switches (learned, switched on, not never-auto) and, as Automatic
	-- does, a spell only a mana user wants left to somebody who has mana.
	local walk, custom = ns.WalkBuffs()
	if custom then
		local skip = db.buff.skip
		for _, buff in ipairs(walk) do
			if ns.IsBuffKnown(buff) and not buff.neverAuto and not (skip and skip[buff.key])
				and not (buff.manaOnly and not hasMana) then
				return buff
			end
		end
	end

	-- Kings first: what the walk offers ahead of the rest is the spell named,
	-- under the same switches as the walk (learned, switched on, not never-auto).
	if db.buff.kingsFirst == true then
		local strongest = ns.StrongestBuff()
		if strongest and ns.IsBuffKnown(strongest) and not strongest.neverAuto
			and not (db.buff.skip and db.buff.skip[strongest.key]) then
			return strongest
		end
	end

	-- The switches and the never-automatic rule apply here as in the walk.
	local auto = ns.CLASS_AUTO[playerClass]
	if auto then
		local key = hasMana and auto.mana or auto.other
		local buff = ns.FindBuff(playerClass, key)
		if buff and ns.IsBuffKnown(buff) and not buff.neverAuto
			and not (db.buff.skip and db.buff.skip[key]) then
			return buff
		end
	end

	return FirstKnownBuff()
end

-- Why ResolveBuff has nothing to name, said as the setting that decides it, so
-- a priest with every spell switched off is not sent to a trainer.
function ns.NothingToCast()
	local pinned = ns.PinnedBuff()
	if pinned and not ns.IsBuffKnown(pinned) then
		return L["%s is pinned and not learned on this character"]:format(ns.BuffName(pinned))
	end
	if not caps.anyKnown then return L["no buff learned"] end
	local db = addon.db and addon.db.profile
	local skip = db and db.buff and db.buff.skip
	for _, buff in ipairs(ns.GetClassBuffs(playerClass) or {}) do
		-- Learned, switched on and still not chosen: a spell Automatic never
		-- reaches for, which is not a switch anybody can find turned off.
		if ns.IsBuffKnown(buff) and not (skip and skip[buff.key]) then
			return L["Automatic never offers %s"]:format(ns.BuffName(buff))
		end
	end
	return L["every spell you know is switched off under Who to buff"]
end

-- Whether the buff walk reads ns.lastGave back for this character. Not for a
-- paladin, deliberately: blessings overwrite each other, so rotating takes away
-- what the last click gave. Nothing may write ns.lastGave for them either.
function ns.RotatesBuffs()
	return not ns.EXCLUSIVE_BUFFS[playerClass]
end

---------------------------------------------------------------------------
-- shared state
---------------------------------------------------------------------------

-- Nameplate tokens come from NAME_PLATE_UNIT_ADDED rather than off the frames,
-- because namePlateUnitToken read from a frame is a secret value here.
ns.nameplateUnits = {}

---------------------------------------------------------------------------
-- unit inspection
---------------------------------------------------------------------------

-- auraCache[guid][buffKey] = { at, has, expires, mine, over, src, trustedTo }, swept
-- periodically
-- because a city puts hundreds of players through here. Keyed by player so
-- UNIT_AURA, the hot path, forgets a whole player in one assignment; the count
-- is of players.
local auraCache = {}
local auraCacheCount = 0

local function ForgetUnitAuras(guid)
	if not guid or not auraCache[guid] then return end
	auraCache[guid] = nil
	auraCacheCount = auraCacheCount - 1
end
ns.ForgetUnitAuras = ForgetUnitAuras

-- Every answer held, when a probe (ProbeCapabilities) runs: which ids are
-- secret may change with it, and an answer read under the last probe would
-- stand for up to three seconds under the next. A buff the probe made in a
-- fight took for secret (probeHidden) is still read through the cache, so a
-- reading from before the probe would pass for a verdict on somebody nobody
-- can read now.
function ns.ForgetAuraCache()
	wipe(auraCache)
	auraCacheCount = 0
end

-- How long a reading is trusted before the client is asked again. A refusal
-- in the first seconds after a fight is kept a third as long: the client stops
-- withholding a few moments after a fight, and somebody covered was offered as
-- "unverified" for the three seconds a refusal from the fight's last scan lived
-- on. Any other refusal is kept as long as a reading: one that never changes (an
-- id declared secret) was asked three times as often for nothing. Fixed as the
-- answer is written (trustedTo, in UnitHasBuff), not as it is read: an answer
-- written in those seconds is not trusted past them (UNVERIFIED_SECONDS).
local READING_SECONDS = 3
local REFUSAL_SECONDS = 1

-- The seconds after a fight the client may go on withholding: a refusal then is
-- asked again sooner (REFUSAL_SECONDS), what was last read worn still answers it
-- (lastWorn), and nobody is offered on it (Queue.lua).
ns.UNVERIFIED_SECONDS = 5

local function JustAfterFight(now)
	local ended = ns.fightEndedAt
	return ended ~= nil and now - ended < ns.UNVERIFIED_SECONDS
end
ns.JustAfterFight = JustAfterFight

-- lastWorn[guid][buffKey] = { id, expires, mine, over }: the last time somebody's
-- buff was read on them with its timer, and which of its ids, outliving the cache
-- and UNIT_AURA. In a fight and the few seconds after it (JustAfterFight), a
-- refusal of that very id answers what that reading said, the time left counting
-- down (UnitHasBuff): a fight refuses every reading, and the passer-by read with
-- forty minutes of Intellect was offered it again, "unverified", on the first
-- scan after. It only holds an offer back, never makes one (Queue.lua). Any other
-- answer -- not worn, worn with no timer to trust, that id read and not found
-- while another is refused -- drops it, and so does seeing them dead (their
-- buffs went with them).
local lastWorn = {}
local lastWornCount = 0
local lastWornSweep = 0

local function ForgetWorn(guid, key)
	local perUnit = lastWorn[guid]
	if not (perUnit and perUnit[key]) then return end
	perUnit[key] = nil
	if next(perUnit) == nil then
		lastWorn[guid] = nil
		lastWornCount = lastWornCount - 1
	end
end

-- Everything last read worn on somebody (IsBuffableUnit, on seeing them dead).
local function ForgetAllWorn(guid)
	if not (guid and lastWorn[guid]) then return end
	lastWorn[guid] = nil
	lastWornCount = lastWornCount - 1
end

local lastSweep = 0

local function SweepAuraCache(now)
	-- What was last read worn and has run out since goes, every half minute at
	-- most, in a city or not.
	if lastWornCount > 0 and (now - lastWornSweep) >= 30 then
		lastWornSweep = now
		for guid, perUnit in pairs(lastWorn) do
			for key, worn in pairs(perUnit) do
				if worn.expires <= now then ForgetWorn(guid, key) end
			end
		end
	end

	if auraCacheCount < 400 then return end
	-- A big table stays big in a city, so the sweep is also rate-limited.
	if (now - lastSweep) < 10 then return end
	lastSweep = now

	for guid, perUnit in pairs(auraCache) do
		local newest
		for _, entry in pairs(perUnit) do
			if not newest or entry.at > newest then newest = entry.at end
		end
		if not newest or (now - newest) > 10 then ForgetUnitAuras(guid) end
	end
end

-- The reads UnitHasBuff may ask of one unit, taken together: a buff has up to
-- eight ids and a stranger usually wears none, so one protected call apiece was
-- most of the scan's pcalls. The answers wait in auraReads by position in the
-- id list, the first auraTaken positions of it; the loop there takes them, and
-- asks any position past that on the spot, protected, as every id once was. It
-- stops where the loop does (the first aura it can read), and a read that
-- throws leaves the positions before it taken and the rest to the loop, which
-- reads the one that threw as a refusal without asking it again (it would
-- throw again, at a cost of a failure each). A position the loop's own
-- secrecy test skips is never read here or there. A buff with blockers
-- (Buffs.lua) has them after its own ids in the list handed in (readIds): the
-- loop stops at its own, and what comes after is read in UnitHasBuff.
local auraReads, auraTaken = {}, 0
local function PrefetchAuras(unit, ids, secrecy)
	auraTaken = 0
	local read = C_UnitAuras.GetUnitAuraBySpellID
	for index, id in ipairs(ids) do
		if secrecy[id] ~= true then
			local aura = read(unit, id)
			auraReads[index] = aura
			auraTaken = index
			if not (issecretvalue and issecretvalue(aura)) and type(aura) == "table" then return end
		end
	end
end

-- The fight is over: what it refused says nothing about now. Refusals are
-- dropped from the cache, so the next scan asks the client again at once
-- rather than up to three seconds on; so is the last reading standing in for
-- one ("kept"), a refusal all the same. The moment is kept for the wait before
-- an unverified offer (UNVERIFIED_SECONDS, JustAfterFight).
function ns.ForgetRefusals()
	ns.fightEndedAt = GetTime()
	for guid, perUnit in pairs(auraCache) do
		for key, entry in pairs(perUnit) do
			if entry.has == nil or entry.src == "kept" then perUnit[key] = nil end
		end
		if next(perUnit) == nil then ForgetUnitAuras(guid) end
	end
end

-- The best rank of `buff` you know that your cast lands on somebody of `level`
-- (the game lands the best rank you know up to ten levels above theirs): its
-- id, or nil when none is known or none is within reach. The test UnitHasBuff
-- makes of a rank worn, below, asks the same of the same ranks.
local function LandingRank(buff, info, level)
	local best = ns.RankLevel(info.topRank)
	if not best then return nil end
	local reach, landing, landed = math.min(best, level + 10), nil, nil
	for _, rank in ipairs(buff.ranks) do
		local at = ns.RankLevel(rank)
		if at and at <= reach and (not landing or at > landing) then landing, landed = at, rank end
	end
	return landed
end

-- Returns has, secondsRemaining, mine, over, seconds. `has` is nil when the client
-- refuses any one of the buff's ids (the hidden one may be the one they wear);
-- `secondsRemaining` is nil when the timer is unreadable, not "about to expire";
-- `mine` is nil when the aura names nobody we can read; `over` is true when
-- they wear a rank above the one your cast would land, which the game refuses
-- to put over it, or a scroll that gives as much of the same stat (Buffs.lua,
-- `blockers`: then `has` is true with no timer, `mine` false); `seconds` is how
-- long that aura lasts in all, the aura's own `duration` where the client says
-- it, else the table's for the id found (Buffs.lua), nil when neither does:
-- what a top-up's lead is worked out from.
local function UnitHasBuff(unit, buff, guid)
	local info = ns.BuffInfo(buff)
	-- A buff nothing can read gives no answer. One a probe made in a fight took
	-- for secret (probeHidden) goes on to the account below: the ids it refuses
	-- are withheld, and what was last read worn answers them.
	if not info or not (info.readable or info.probeHidden) then return nil, nil end

	local now = GetTime()
	local perUnit = guid and auraCache[guid]
	local cached = perUnit and perUnit[buff.key]
	if cached and now < cached.trustedTo then
		return cached.has, cached.expires and (cached.expires - now) or nil, cached.mine, cached.over, cached.duration
	end

	-- Refusals (an id declared secret, a read that throws or comes back secret,
	-- an empty read of an id the client hides just now) are counted, not read as
	-- absence: BuildQueue promotes a target over a debt on a definite no, and the
	-- prompt drops its unverified wording. `withheld` when the client may answer
	-- a moment on: a read refused as it was made, an empty read of an id it hides
	-- just now, or an id declared secret by a probe made while it withheld
	-- (probedInFight). `keptRefused` when the id last read worn (lastWorn) is
	-- among the refused.
	local wornBy = guid and lastWorn[guid]
	local kept = wornBy and wornBy[buff.key]
	local has, expires, mine, over, refused = false, nil, nil, nil, false
	local withheld, keptRefused, found = false, false, nil
	local duration
	local threw = not pcall(PrefetchAuras, unit, buff.readIds or buff.auraIds, info.secrecy)
	for index, id in ipairs(buff.auraIds) do
		if info.secrecy[id] == true then
			refused = true
		else
			local ok, aura = true, auraReads[index]
			if index > auraTaken then
				if threw then
					-- The read the prefetch threw at, the first not taken: a
					-- refusal, and not asked again.
					threw, ok, aura = false, false, nil
				else
					ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, id)
				end
			end
			if not ok or (issecretvalue and issecretvalue(aura)) then
				refused = true
				withheld = true
				if kept and kept.id == id then keptRefused = true end
			elseif aura == nil then
				-- An aura the client keeps secret just now reads as nothing, and
				-- the probe's note predates a match or key that began since:
				-- asked at read time, as the own-buff families do (HiddenAura).
				local secrets = C_Secrets
				local ask = secrets and secrets.ShouldSpellAuraBeSecret
				if type(ask) == "function" and plain(ask(id)) == true then
					refused = true
					withheld = true
					if kept and kept.id == id then keptRefused = true end
				end
			elseif type(aura) == "table" then
				has = true
				found = id
				local expiration = plain(aura.expirationTime)
				if type(expiration) == "number" and expiration > 0 then expires = expiration end
				local length = plain(aura.duration)
				if type(length) == "number" and length > 0 then duration = length end
				-- Whose it is, for a paladin's blessings. isFromPlayerOrPlayerPet
				-- is true for any player's aura, so only a readable token answers.
				local source = plain(aura.sourceUnit)
				if type(source) == "string" then
					-- Direct: a client-written token, which UnitIsUnit never throws on.
					local same = plain(UnitIsUnit(source, "player"))
					if same ~= nil then mine = same == true end
				end
				-- Another class's of the same kind (Buffs.lua, alike) is never
				-- our cast, whoever the client names or does not: a paladin
				-- walks on to Might, not stopping at Kings as if it were his.
				if buff.alikeIds and buff.alikeIds[id] then mine = false end
				-- A rank below the one your cast would land on them covers
				-- nothing: a level-60 wearing a low player's +10 Stamina for an
				-- hour, never offered the +70. The game lands the best rank you
				-- know up to ten levels above theirs. Ranks only, never a group
				-- version; a level that cannot be read tests nothing. A rank
				-- above it covers them and is more: yours on top is refused ("A
				-- more powerful spell is already active"), so it is no refresh
				-- for a debt or a top-up to offer. Only one their level allows:
				-- a rank past their reach is a reading no cast makes, and
				-- tests nothing.
				local worn = ns.RankLevel(id)
				local level = worn and plain(UnitLevel(unit))
				local best = level and ns.RankLevel(info.topRank)
				if type(level) == "number" and level > 0 and best then
					local reach, landing = math.min(best, level + 10), nil
					local isRank = false
					for _, rank in ipairs(buff.ranks) do
						if rank == id then isRank = true end
						local at = ns.RankLevel(rank)
						if at and at <= reach and (not landing or at > landing) then landing = at end
					end
					if isRank and landing and worn < landing then has, expires, mine = false, nil, nil end
					if isRank and landing and worn > landing and worn <= level + 10 then over = true end
				end
				break
			end
		end
	end

	-- Not worn, and something else may be worn that the game compares with it
	-- (Buffs.lua, `blockers`): a Scroll of Intellect on somebody lacking Arcane
	-- Intellect. Yours is refused over one worth as much as the rank it would
	-- land on them (the same landing as the rank test above), so they are
	-- covered, and the cast is no favour's repayment ("over"); one worth less
	-- is cast over as ever. The blockers follow the buff's own ids in the one
	-- batched read (buff.readIds), strongest first and stopping at the first
	-- found, so a buff that is worn never reads them and one that is not pays
	-- reads and no call of its own; and what they read says nothing until one is
	-- found or withheld, when the level of the target (and so the rank that
	-- lands) is asked for the first time. One worth less than what lands, and
	-- every one after it, is not weighed. A blocker the client will not let us
	-- read, worth that much, leaves the answer open as one of the buff's own
	-- ids does; a level it will not give tests nothing.
	local blockerIds = buff.blockerIds
	if blockerIds and not has and not refused then
		local first, landing = #buff.auraIds, false
		for index, id in ipairs(blockerIds) do
			local at = first + index
			local seen, aura = false, nil
			if info.secrecy[id] == true then
				seen = true
			elseif at > auraTaken then
				-- The read that threw, not asked again; any other position
				-- past the ones taken is after a find, or never reached.
				if threw then seen, threw = true, false end
			else
				aura = auraReads[at]
				seen = (issecretvalue and issecretvalue(aura)) or (type(aura) == "table")
			end
			if seen then
				if landing == false then
					local level = plain(UnitLevel(unit))
					local landed = type(level) == "number" and level > 0 and LandingRank(buff, info, level)
					landing = landed and ns.STAT_VALUE[landed] or nil
				end
				local value = ns.STAT_VALUE[id]
				if not (landing and value and value >= landing) then break end
				if not (issecretvalue and issecretvalue(aura)) and type(aura) == "table" then
					has, over, mine = true, true, false
					break
				end
				refused = true
				if info.secrecy[id] ~= true then withheld = true end
			end
			if at > auraTaken and not seen then break end
		end
	end
	if not has and refused then has = nil end
	-- What does not cover them has no length either (the rank test above).
	if not has then duration = nil end
	-- A length the client did not say is the table's, for the id found.
	if has and expires and not duration then
		local listed = ns.SPELL_SECONDS[found]
		if listed and listed > 0 then duration = listed end
	end
	-- An id declared secret: withheld when the probe that said so was made while
	-- the client withheld, and the id last read worn may be one.
	if refused and caps.probedInFight then withheld = true end
	if kept and info.secrecy[kept.id] == true then keptRefused = true end

	-- What was last read worn, kept past the cache (see lastWorn): written on
	-- a reading with a timer, read on a refusal of that same id while that timer
	-- runs, in a fight or just after it. `src` says so to the walk.
	local src = withheld and has == nil and "withheld" or nil
	if guid then
		if has and expires then
			if not wornBy then
				wornBy = {}
				lastWorn[guid] = wornBy
				lastWornCount = lastWornCount + 1
			end
			if kept then
				kept.id, kept.expires, kept.mine, kept.over = found, expires, mine, over
			else
				wornBy[buff.key] = { id = found, expires = expires, mine = mine, over = over }
			end
		elseif kept then
			if has == nil and keptRefused and kept.expires > now then
				-- Out of a fight the refusal stands, and the reading waits for the next.
				if InCombatLockdown() or JustAfterFight(now) then
					has, expires, mine, over = true, kept.expires, kept.mine, kept.over
					local listed = ns.SPELL_SECONDS[kept.id]
					duration = listed and listed > 0 and listed or nil
					src = "kept"
				end
			else
				ForgetWorn(guid, buff.key)
			end
		end
	end

	-- Negative answers are cached too (a refusal as nil), or the walk re-reads
	-- every buff for every person on every tick.
	if guid then
		if not perUnit then
			perUnit = {}
			auraCache[guid] = perUnit
			auraCacheCount = auraCacheCount + 1
		end
		-- When it stops being trusted, fixed now (READING_SECONDS): a refusal
		-- written in the first seconds after a fight, REFUSAL_SECONDS, and
		-- nothing written in them past them, or a refusal or a reading kept
		-- from the fight would stand a moment into the time the client answers
		-- for itself. In a fight, as ever, three seconds.
		local trustedTo = now + READING_SECONDS
		if JustAfterFight(now) and not InCombatLockdown() then
			if has == nil then trustedTo = now + REFUSAL_SECONDS end
			local windowEnds = ns.fightEndedAt + ns.UNVERIFIED_SECONDS
			if trustedTo > windowEnds then trustedTo = windowEnds end
		end
		-- A stale reading is rewritten in place: nothing else holds one, and a
		-- crowd turns them all over every three seconds.
		if cached then
			cached.at, cached.has, cached.expires, cached.mine = now, has, expires, mine
			cached.over = over
			cached.duration = duration
			cached.src = src
			cached.trustedTo = trustedTo
		else
			perUnit[buff.key] = { at = now, has = has, expires = expires, mine = mine, over = over, src = src,
				trustedTo = trustedTo, duration = duration }
		end
	end
	return has, expires and (expires - now) or nil, mine, over, duration
end
ns.UnitHasBuff = UnitHasBuff

-- What the last answer about somebody's buff rests on, for the walk (Queue.lua):
-- "kept" when what was last read worn stood in for a refusal (lastWorn),
-- "withheld" when the client refused a reading it may give a moment on, nil for
-- anything else, a reading or a refusal that will not change.
function ns.ReadingSource(guid, key)
	local perUnit = guid and auraCache[guid]
	local entry = perUnit and perUnit[key]
	if not entry or GetTime() >= entry.trustedTo then return nil end
	return entry.src
end

-- Classes that have a mana bar, for when the client will not tell us a unit's
-- power (always, on the tokenless owed path). Monk and evoker have one; death
-- knight and demon hunter do not.
local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true,
	DRUID = true, PALADIN = true, HUNTER = true, SHAMAN = true,
	MONK = true, EVOKER = true,
}
-- Retail hunters have Focus and no mana bar (ChrClasses.DisplayPower 2, build
-- 12.1.0.69933), where a vanilla hunter has mana. A monk stays, though his
-- class's DisplayPower is Energy (3): a Mistweaver is an Intellect healer with
-- mana (ChrSpecialization 270), and the class cannot say which spec passes by.
if (ns.Flavour and ns.Flavour.flavour) == "mainline" then MANA_CLASSES.HUNTER = nil end
ns.MANA_CLASSES = MANA_CLASSES

-- Returns true, false, or nil for "cannot tell". UnitPowerMax is a secret value
-- for players outside your group here; class is not, so it answers instead.
local function UnitHasMana(unit)
	local maxMana = plain(UnitPowerMax(unit, MANA))
	if maxMana ~= nil then return maxMana > 0 end

	local class = plain(select(2, UnitClass(unit)))
	if class then return MANA_CLASSES[class] == true end

	return nil
end
ns.UnitHasMana = UnitHasMana

-- Returns ok and, when ok is false, whether the rejection was about the person
-- rather than the token: dead, hostile, offline or too low is a judgement the
-- tokenless owed fallback has to honour too, while "no such unit" or "that is
-- you" says nothing about anybody. Only the first return may be tested for
-- truth; the second is advisory.
local function IsBuffableUnit(unit, f)
	if not unit or not plain(UnitExists(unit)) then return false end
	if plain(UnitIsUnit(unit, "player")) then return false end
	if plain(UnitIsPlayer(unit)) ~= true then return false end
	if plain(UnitIsDeadOrGhost(unit)) == true then
		-- Their buffs went with them: what was last read worn says nothing now.
		ForgetAllWorn(plain(UnitGUID(unit)))
		return false, true
	end
	-- Only a definite refusal is a judgement about the person: a withheld
	-- answer is nil, and the tokenless fallback exists to reach exactly those.
	local canAssist = plain(UnitCanAssist("player", unit))
	if canAssist ~= true then return false, canAssist == false end
	if plain(UnitIsConnected(unit)) == false then return false, true end

	if f.minLevel and f.minLevel > 1 then
		local lvl = plain(UnitLevel(unit))
		if lvl and lvl > 0 and lvl < f.minLevel then return false, true end
	end

	return true
end
ns.IsBuffableUnit = IsBuffableUnit

-- nil means "could not tell", which we treat as worth offering rather than
-- silently dropping somebody who is probably standing right next to you.
local function InRange(unit, buff)
	local info = ns.BuffInfo(buff)
	local name = ns.BuffName(buff)

	-- By id first: a name must be resolved against the spellbook, which this
	-- client is unreliable about. Direct calls, each handed only the types it
	-- takes, so neither throws; asked of every person on every scan.
	local spells = C_Spell
	local byId = type(spells) == "table" and spells.IsSpellInRange or nil
	if type(byId) ~= "function" then byId = nil end
	local byName = _G.IsSpellInRange
	if type(byName) ~= "function" then byName = nil end
	local r
	if byId and info and type(info.topRank) == "number" then
		r = plain(byId(info.topRank, unit))
	end
	if type(name) == "string" then
		if r == nil and byId then r = plain(byId(name, unit)) end
		if r == nil and byName then r = plain(byName(name, unit)) end
	end
	if r == nil then return nil end
	return (r == true or r == 1)
end
ns.InRange = InRange

-- The raid subgroup (1-8) a unit is in, or nil where nothing says. A raid
-- token's number is its place on the roster; any other token asks UnitInRaid.
-- A party-wide spell reaches the target's own subgroup of a raid and nobody
-- else in it, and "Raid groups I buff" goes by it too. The roster is handed a
-- plain number, so it is called directly. On ns alone (Queue.lua and
-- GroupBuffs.lua take it from there) to spare a main-chunk local.
function ns.RaidSubgroup(unit)
	local index = tonumber(unit:match("^raid(%d+)$"))
	if not index then
		-- UnitInRaid answers with the 1-based GetRaidRosterInfo index.
		local r = plain(UnitInRaid and UnitInRaid(unit))
		index = type(r) == "number" and r or nil
	end
	if type(index) ~= "number" then return nil end
	local roster = _G.GetRaidRosterInfo
	if type(roster) ~= "function" then return nil end
	local _, _, subgroup = roster(index)
	subgroup = plain(subgroup)
	if type(subgroup) ~= "number" then return nil end
	return subgroup
end

-- Whether a partyOnly buff the player casts reaches this unit. In a raid a
-- vanilla shout reaches only the caster's subgroup (ns.PARTY_IS_SUBGROUP; later
-- flavours made it raid-wide): UnitInSubgroup where the client has it, as the
-- Camelot class-buff reminder uses, else the raid roster. `inRaid` is the
-- scan's reading of IsInRaid; nil asks here.
local function SameParty(unit, inRaid)
	if not unit then return false end
	if inRaid == nil then inRaid = plain(IsInRaid and IsInRaid()) == true end
	if not inRaid then
		return plain(UnitInParty and UnitInParty(unit)) == true
	end
	if not ns.PARTY_IS_SUBGROUP then
		return type(plain(UnitInRaid and UnitInRaid(unit))) == "number"
	end
	if type(_G.UnitInSubgroup) == "function" then
		return plain(_G.UnitInSubgroup(unit)) == true
	end
	local theirs, ours = ns.RaidSubgroup(unit), ns.RaidSubgroup("player")
	return theirs ~= nil and theirs == ours
end
ns.SameParty = SameParty

-- Whether a shout would reach this unit: true, false, or nil for nothing could
-- tell. InRange cannot answer it: a self-cast spell has no range to anybody.
--
-- The follow prompt (CheckInteractDistance 4, about 28 yards) first, where a
-- refusal stays a refusal; LibRangeCheck after it, and only to say yes within
-- 30 yards, since its "far" can be a refusal in disguise (DirectCheck). Both
-- are looser than a shout on purpose: they stop the sixty-yard or other-zone
-- case. Never the follow prompt in a fight: the game blocks it for a friendly
-- unit and names the addon, which no pcall catches. LibRangeCheck switches to
-- its in-combat checkers by itself.
--
-- The follow prompt is called directly, and LibStub's silent lookup returns
-- nil rather than throwing; LibRangeCheck is third-party, so it keeps safecall.
--
-- On Mists and retail a shout reaches the party and raid within 100 yards
-- (Buffs.lua, shoutYards), past both tests above: their "no" at 28 or 30
-- yards is no answer there. The client's own sight answers first instead,
-- read as BuildQueue and GroupBuffs.lua read it for any group spell's 100
-- yards; then the follow prompt's yes, then LibRangeCheck within the reach.
-- Called directly, as they call it: a group token never throws.
local function ShoutReach(unit)
	local wide = ns.SHOUT_YARDS
	if wide and type(_G.UnitIsVisible) == "function" then
		local visible = plain(_G.UnitIsVisible(unit))
		if visible ~= nil then return visible == true end
	end

	if not InCombatLockdown() and type(_G.CheckInteractDistance) == "function" then
		local follow = plain(_G.CheckInteractDistance(unit, 4))
		if follow == true or follow == 1 then return true end
		if follow ~= nil and not wide then return false end
	end

	local stub = _G.LibStub
	local lib = type(stub) == "table" and type(stub.GetLibrary) == "function"
		and stub:GetLibrary("LibRangeCheck-3.0", true) or nil
	if type(lib) == "table" and type(lib.GetRange) == "function" then
		local _, maxRange = safecall(lib.GetRange, lib, unit)
		if type(maxRange) == "number" and maxRange <= (wide or 30) then return true end
	end
	return nil
end
ns.ShoutReach = ShoutReach

-- Whether a shout surely reaches this unit, for the spoken line alone: true
-- only where something says within 20 yards, the radius of every Battle Shout
-- rank in Forever's spell data (and the tightest any client gives a shout);
-- further, unknown or in a fight is false. ShoutReach stays looser on purpose
-- for offering and settling, but a thank-you over a shout that never reached
-- them cannot be taken back. Out of a fight the trade prompt
-- (CheckInteractDistance 2, about ten yards) first, called directly; then
-- LibRangeCheck within 20, through safecall as in ShoutReach. Without the
-- library a warrior's line goes out only within the trade prompt's reach. On
-- ns rather than a main-chunk local, for Lua 5.1's 200: asked only by the
-- press (Prompt/Press.lua, HoldLine) and the macro's arming (Macro.lua).
function ns.ShoutSure(unit)
	if not unit then return false end
	if not InCombatLockdown() and type(_G.CheckInteractDistance) == "function" then
		local trade = plain(_G.CheckInteractDistance(unit, 2))
		if trade == true or trade == 1 then return true end
	end
	local stub = _G.LibStub
	local lib = type(stub) == "table" and type(stub.GetLibrary) == "function"
		and stub:GetLibrary("LibRangeCheck-3.0", true) or nil
	if type(lib) == "table" and type(lib.GetRange) == "function" then
		local _, maxRange = safecall(lib.GetRange, lib, unit)
		-- An edge backed by a prompt the client may withhold is asked again
		-- directly (DirectCheck, Range.lua): the library flattens an answer
		-- it cannot read, so only a yes heard here is sure.
		local direct = type(maxRange) == "number" and maxRange <= 20 and ns.DirectRangeCheck
			and ns.DirectRangeCheck(lib, maxRange)
		if direct and direct(unit) ~= true then maxRange = nil end
		if type(maxRange) == "number" and maxRange <= 20 then return true end
	end
	return false
end

-- Whether the buff reaches this unit right now, asked the way the scan asks it
-- for entry.ranged. The prompt's press asks again just before its macro runs:
-- the scan can be a tick old, and somebody who walked off since would still be
-- spoken to over a /cast that fails.
function ns.ReachNow(unit, buff)
	if not (unit and buff) then return nil end
	local ranged = InRange(unit, buff)
	if ranged == nil and buff.selfCast then ranged = ShoutReach(unit) end
	return ranged
end

---------------------------------------------------------------------------
-- names
---------------------------------------------------------------------------

-- Strips a cross-realm suffix, keeping any surname: "Petra Stonewell-Realm" gives
-- "Petra Stonewell". This is the display name.
local function ShortName(name)
	if type(name) ~= "string" then return nil end
	return name:match("^([^%-]+)") or name
end
ns.ShortName = ShortName

-- Just the first word: "Petra" out of "Petra Stonewell", nil for a name that is
-- one word already. Never on a /target line (the first-name fallback was
-- removed deliberately: see ExpirePendingClick); it feeds {first} in /manners
-- try and the settle path, since the game may report either spelling.
local function FirstName(name)
	if type(name) ~= "string" then return nil end
	local first = name:match("^([^%s%-]+)")
	if first and first ~= name then return first end
	return nil
end
ns.FirstName = FirstName

-- Names go into macro text, so anything that could break out of the [@target]
-- clause is rejected outright. The length cap fits the longest key there is: a
-- name and a surname of 12 letters each, 4 bytes a letter at most, and a space.
local function SafeForMacro(name)
	if type(name) ~= "string" or name == "" then return false end
	if #name > 97 then return false end
	if name:find("[%[%]\n\r;|]") then return false end
	return true
end
ns.SafeForMacro = SafeForMacro

-- The name somebody is filed under, from UnitName's two halves: the key for
-- debts (on disk), the tried table and the rotation pointer (the /target
-- spelling is ns.TargetName). On Camelot the second half is a surname, joined
-- with a space (verified in game); elsewhere a realm, joined with a dash as
-- the game does. nil for a name withheld or unsafe for macro text. The aura
-- scan and the combat log both file through here.
--
-- nil too for the client's stand-in for a name it has not loaded yet
-- (UNKNOWNOBJECT, "Unknown" in English): that is nobody. Filed, it was owed,
-- offered for ten seconds as a passer-by, and armed as "/target Unknown",
-- which finds nobody and leaves the /cast to whoever is targeted. The name
-- arrives a moment later, and they are somebody then.
local function JoinName(name, second)
	if not name then return nil end
	if name == (plain(_G.UNKNOWNOBJECT) or "Unknown") then return nil end

	local full = name
	if second and second ~= "" then
		full = name .. (SurnameClient() and " " or "-") .. second
	end
	if not SafeForMacro(full) then return nil end
	return full
end
ns.JoinName = JoinName

-- plain() collapses to a single value, so both of UnitName's returns have to be
-- taken before either is inspected or the second is silently lost.
function ns.UnitFullName(unit)
	local rawName, rawSecond = UnitName(unit)
	return JoinName(plain(rawName), plain(rawSecond))
end

-- Whether a filed name is the player's own. The offer of your own buff
-- (Queue.lua) is filed under it, and a group cast that covers you lists it
-- among the people it reached, where the ledger must not file a gift to you.
function ns.IsPlayerName(name)
	return name ~= nil and name == ns.UnitFullName("player")
end

-- The spelling that goes on the /target line, from the filed name (the
-- tokenless fallback has nothing else). On Camelot the key unchanged: its join
-- is the only form verified there. Elsewhere the realm comes off, on the
-- reasoning (untested live) that /target searches names of units drawn in and
-- a realm is not part of what it searches.
function ns.TargetName(name)
	if type(name) ~= "string" then return nil end
	if SurnameClient() then return name end
	return ShortName(name)
end

-- A class as the player reads it: "Priester" for PRIEST on a German client,
-- the token where the client has no table of names. Everything that shows a
-- class in words asks here; colours and the mana test keep the token.
function ns.ClassName(class)
	if type(class) ~= "string" or class == "" then return nil end
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	local name = type(names) == "table" and plain(names[class]) or nil
	if type(name) == "string" then return name end
	return class:sub(1, 1) .. class:sub(2):lower()
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

-- A profile can be hand-edited, or carried over from a version with other
-- limits; out of range, it means a prompt sized zero or a scan every frame.
local VALID_ANCHORS = {
	TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

-- Somewhere to put the prompt without the unlock, drag, lock dance. Each is
-- anchored to its own screen edge so it stays put at any resolution. A list,
-- because the dropdown needs an order.
ns.POSITION_PRESETS = {
	{ key = "bars", name = L["Above the action bars"],
		point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 300 },
	{ key = "minimap", name = L["Under the minimap"],
		point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -20, y = -220 },
	{ key = "centre", name = L["Middle of the screen"],
		point = "CENTER", relPoint = "CENTER", x = 0, y = -140 },
}

-- Which preset the prompt is sitting on, or nil once dragged elsewhere: asked
-- rather than remembered, so it cannot go stale.
function ns.CurrentPositionPreset()
	local p = addon.db and addon.db.profile.prompt
	if not p then return nil end
	for _, preset in ipairs(ns.POSITION_PRESETS) do
		if preset.point == p.point and preset.relPoint == p.relPoint
			and preset.x == p.x and preset.y == p.y then
			return preset.key
		end
	end
	return nil
end

function ns.ApplyPositionPreset(key)
	local p = addon.db and addon.db.profile.prompt
	if not p then return false end
	for _, preset in ipairs(ns.POSITION_PRESETS) do
		if preset.key == key then
			p.point, p.relPoint, p.x, p.y = preset.point, preset.relPoint, preset.x, preset.y
			-- Never touches `locked`: an unlocked prompt cannot cast.
			ns.Prompt:ApplyStyle()
			return true
		end
	end
	return false
end

-- The highest level a player reaches on this client, for "Skip players below
-- level" (the slider's end and the repair below): the client's own answer,
-- never under its flavour's cap -- Burning Crusade's 70, Mists' and
-- Midnight's 90, vanilla's 60 everywhere else -- so a client that cannot say
-- does not cut a setting back. On ns, not a main-chunk local, for Lua 5.1's
-- 200.
function ns.MaxPlayerLevel()
	local flavour = ns.Flavour and ns.Flavour.flavour
	local cap = (flavour == "tbc" and 70) or ((flavour == "mists" or flavour == "mainline") and 90) or 60
	local ask = _G.GetMaxPlayerLevel
	local level = type(ask) == "function" and plain(ask()) or nil
	if type(level) == "number" and level > cap then cap = level end
	return cap
end

-- A limit's bounds are numbers, or a function asked each time (a client's
-- level cap).
local LIMITS = {
	{ "timing", "scanInterval", 0.1, 2 },
	{ "timing", "reciprocateWindow", 15, 600 },
	{ "timing", "retryCooldown", 3, 60 },
	{ "timing", "graceSeconds", 10, 180 },
	{ "filters", "minLevel", 1, ns.MaxPlayerLevel },
	{ "filters", "refreshUnder", 1, 60 },
	{ "filters", "refreshRaid", 1, 4 },
	{ "filters", "manaFloor", 0, 90 },
	{ "prompt", "width", 80, 500 },
	{ "prompt", "height", 20, 120 },
	{ "prompt", "scale", 0.5, 3 },
	{ "prompt", "alpha", 0.1, 1 },
	{ "prompt", "fontSize", 6, 32 },
	{ "prompt", "iconSize", 12, 64 },
	{ "prompt", "queueRows", 1, 5 },
	{ "filters", "selfLead", 0, 10 },
	-- Two is the least a group cast can beat, five a whole party.
	{ "groupBuffs", "atLeast", 2, 5 },
}

-- The largest icon a prompt of this size can hold: eight pixels shorter than
-- the panel and sixty narrower, never under the slider's floor. Asked by the
-- clamp below and by the notice on the options page.
function ns.IconCeiling(p)
	local d = ns.defaults.profile.prompt
	local height = type(p.height) == "number" and p.height or d.height
	local width = type(p.width) == "number" and p.width or d.width
	return math.max(12, math.min(height - 8, width - 60))
end

-- What the repair below put right this session, for /manners selftest: a
-- value a damaged or hand-edited file held. On ns, not a main-chunk local,
-- for Lua 5.1's 200; capped, since it runs on every profile change.
ns.repairLog = {}

-- Every yes/no, number and text among the defaults, the top level and one
-- section down, as { section or false, key, type, default }: made once, for
-- ClampSettings' repair by type.
function ns.SettingLeaves()
	local leaves = ns.settingLeaves
	if leaves then return leaves end
	leaves = {}
	for key, default in pairs(ns.defaults.profile) do
		if type(default) == "table" then
			for k, v in pairs(default) do
				local kind = type(v)
				if type(k) == "string" and (kind == "boolean" or kind == "number" or kind == "string") then
					leaves[#leaves + 1] = { key, k, kind, v }
				end
			end
		elseif type(default) == "boolean" or type(default) == "number" or type(default) == "string" then
			leaves[#leaves + 1] = { false, key, type(default), default }
		end
	end
	ns.settingLeaves = leaves
	return leaves
end

function ns.ClampSettings()
	local profile = addon.db and addon.db.profile
	if not profile then return end
	local function fixed(what, was)
		local log = ns.repairLog
		if #log < 20 then log[#log + 1] = ("%s (was %s)"):format(what, tostring(was)) end
	end
	-- AceDB fills defaults only into a table, and a damaged or hand-edited
	-- file can hold anything, so a section that is not one is replaced whole
	-- (with a copy: AceDB strips values equal to the default table itself).
	local function copy(t)
		local out = {}
		for k, v in pairs(t) do out[k] = type(v) == "table" and copy(v) or v end
		return out
	end
	for key, default in pairs(ns.defaults.profile) do
		if type(default) == "table" and type(profile[key]) ~= "table" then
			fixed(key, profile[key])
			profile[key] = copy(default)
		end
	end
	for _, limit in ipairs(LIMITS) do
		local group, key, low, high = limit[1], limit[2], limit[3], limit[4]
		if type(high) == "function" then high = high() end
		local value = profile[group] and profile[group][key]
		-- NaN (a hand-edited 0/0) is below and above nothing, so it passes
		-- here untouched and the repair by type below puts it back.
		local number = type(value) == "number"
		if not number or value < low or value > high then fixed(group .. "." .. key, value) end
		if not number then
			profile[group][key] = ns.defaults.profile[group][key]
		elseif value < low then
			profile[group][key] = low
		elseif value > high then
			profile[group][key] = high
		end
	end

	local p = profile.prompt
	-- Every wording that goes through the substitution must be a string, or
	-- the swap throws on every repaint; the reason lines are put right by type
	-- with every other leaf (ns.SettingLeaves, below). Only the first line has
	-- to say something; an empty reason line is a wish (no second line).
	if not ns.UsableFormat(p.format) then p.format = ns.defaults.profile.prompt.format end

	-- skipIfBuffed became a three-way choice. Here rather than OnInitialize
	-- so every profile is carried over when it becomes active, not only the
	-- one active at login.
	local filters = profile.filters
	if filters and filters.skipIfBuffed ~= nil then
		if filters.skipIfBuffed == false then filters.whenBuffed = "always" end
		filters.skipIfBuffed = nil
	end

	-- The icon is bound to the panel by both dimensions, or it overhangs it
	-- and pushes the name off; clamped here as well as in the slider, since a
	-- profile written under a taller prompt survives the height being lowered.
	local iconMax = ns.IconCeiling(p)
	if p.iconSize > iconMax then p.iconSize = iconMax end
	if not ns.CHANNEL_COMMANDS[profile.speech.channel] then profile.speech.channel = "SAY" end


	-- An empty phrase box refilled from the set the dropdown names, so the two
	-- agree (nil for a set that no longer exists). Here, not OnInitialize: a
	-- new, copied or reset profile only comes back through RefreshConfig.
	local speech = profile.speech
	if type(speech.phrases) ~= "string" or speech.phrases:match("^%s*$") then
		speech.phrases = ns.PhraseSetText(speech.presetChoice) or ns.PhraseSetText("roleplay")
	end
	-- A set's English text is what an English-only build wrote into the box, not
	-- something the player typed, so it follows the client's language; a set's
	-- text from before it was rewritten (Fantasy, now Azeroth) becomes the set
	-- as it reads now.
	local englishSet = ns.EnglishPhraseSet(speech.phrases)
	local translatedSet = englishSet and ns.PhraseSetText(englishSet)
	if translatedSet and translatedSet ~= speech.phrases then speech.phrases = translatedSet end
	-- The same for "In character", whose examples differ per character, so
	-- Phrases.lua recognises its own.
	if ns.InCharacter then ns.InCharacter.Repair(speech) end

	-- Everything with a fixed set of values, checked against that set: an
	-- unrecognised value falls through every branch that handles it.
	local function oneOf(tbl, key, allowed, fallback)
		if not allowed[tbl[key]] then
			fixed(key, tbl[key])
			tbl[key] = fallback
		end
	end

	-- Every yes or no among the defaults, repaired by type from here (a string
	-- there is truthy forever, and a checkbox cannot show it): before the reads
	-- below that take a switch for a plain true (skipPvP, kingsFirst: anything
	-- else a damaged file holds would switch it off unseen). The numbers and
	-- texts are repaired last. See ns.SettingLeaves.
	local leaves = ns.SettingLeaves()
	local function repair(booleans)
		for i = 1, #leaves do
			local leaf = leaves[i]
			if (leaf[3] == "boolean") == booleans then
				local holder = leaf[1] and profile[leaf[1]] or profile
				local value = holder[leaf[2]]
				-- NaN is no number, as above.
				if type(value) ~= leaf[3] or value ~= value then
					fixed((leaf[1] and leaf[1] .. "." or "") .. leaf[2], value)
					holder[leaf[2]] = leaf[4]
				end
			end
		end
	end
	repair(true)

	oneOf(profile.filters, "whenBuffed", { skip = true, refresh = true, always = true }, "skip")
	-- Built from the tier list, so a new distance is never rejected here.
	local proximities = {}
	for _, tier in ipairs(ns.PROXIMITY) do proximities[tier.key] = true end
	oneOf(profile.filters, "proximity", proximities, "near")
	-- A count of people, so a whole one: a hand-edited 2.5 is a number the
	-- slider cannot show, and the page would say something the scan does not do.
	profile.groupBuffs.atLeast = math.floor(profile.groupBuffs.atLeast)
	-- Rows, so whole ones too: a 2.5 listed two in the preview, three on the
	-- prompt, and hung a list above it half a row off.
	profile.prompt.queueRows = math.floor(profile.prompt.queueRows)
	-- Whole minutes, as the slider gives them.
	profile.filters.selfLead = math.floor(profile.filters.selfLead)

	-- A family's pick is "auto", "off" or a spell of that family; anything else
	-- -- a hand-edited file, a spell moved to another family -- is Automatic, and
	-- a family this client has no data for goes. Written, not cleared: AceDB puts
	-- a default back only at the next load.
	local own = profile.ownBuffs
	if type(own.pick) ~= "table" then own.pick = {} end
	for key, value in pairs(own.pick) do
		local family = ns.FindOwnFamily(key)
		local spell = ns.FindOwnSpell(value)
		if not family then
			own.pick[key] = nil
		elseif value ~= "auto" and value ~= "off" and not (spell and spell.family == family) then
			own.pick[key] = "auto"
		end
	end
	for key in pairs(ns.defaults.profile.ownBuffs.pick) do
		if own.pick[key] == nil then own.pick[key] = "auto" end
	end

	-- The raid groups switched off, read on every scan in a raid. Anything but
	-- a group number set to true is dropped: there is no telling what it meant.
	local skipGroups = profile.filters.skipRaidGroups
	if type(skipGroups) ~= "table" then
		skipGroups = {}
		profile.filters.skipRaidGroups = skipGroups
	end
	for group, flag in pairs(skipGroups) do
		if type(group) ~= "number" or group < 1 or group > 8 or group % 1 ~= 0 or flag ~= true then
			skipGroups[group] = nil
		end
	end

	-- An entry that is not a name set to true (typed) or "filed" (a name the game
	-- gave, Queue.lua NEVER_FILED) is dropped: there is no telling who it was
	-- meant to be.
	for name, flag in pairs(profile.never) do
		if type(name) ~= "string" or not name:find("%S") or (flag ~= true and flag ~= "filed") then
			profile.never[name] = nil
		end
	end

	-- The set of switched-off spells, indexed on every scan by CastableBuffs.
	if type(profile.buff.skip) ~= "table" then profile.buff.skip = {} end
	-- The buff order, read on every scan (ns.WalkBuffs), repaired for every class
	-- in the profile whichever client wrote it: a key no client has for that
	-- class, a key twice and an entry that is not a list of keys go; a key only
	-- another client has stays (ns.RepairedBuffOrder), and the buffs this client
	-- has that the order lacks are added after it, in Automatic's order.
	local order = profile.buff.order
	if type(order) ~= "table" then
		fixed("buff.order", order)
		order = {}
		profile.buff.order = order
	end
	for class, keys in pairs(order) do
		local repaired = type(class) == "string" and ns.RepairedBuffOrder(class, keys, profile.buff.kingsFirst == true)
		if not repaired then
			fixed("buff.order." .. tostring(class), keys)
			order[class] = nil
		else
			local same = type(keys) == "table" and #keys == #repaired
			for i = 1, same and #repaired or 0 do
				if keys[i] ~= repaired[i] then same = false end
			end
			if not same then
				fixed("buff.order." .. class, keys)
				order[class] = repaired
			end
		end
	end
	-- The look once called "blizzard" is "framed" now; carried across rather
	-- than reset to the default by the oneOf below.
	if p.style == "blizzard" then p.style = "framed" end
	-- Every look Looks/ registered, the three Prompt/Panel.lua draws among
	-- them.
	oneOf(p, "style", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)
	oneOf(p, "accentMode", { icon = true, stripe = true, both = true, off = true }, "icon")
	oneOf(p, "reasonPalette", { standard = true, colourblind = true }, "standard")
	oneOf(p, "flashStyle", { pulse = true, once = true, off = true }, "pulse")
	oneOf(p, "effects", { full = true, calm = true }, "full")
	oneOf(p, "tooltip", { full = true, short = true, shift = true, off = true }, "short")
	oneOf(p, "tooltipPosition", { beside = true, game = true }, "beside")

	-- The two questions Start here asks a new profile (Options/Start.lua,
	-- Quick.Asking). A profile this clamp has been through before carries the
	-- anchor stamp below, so it was set up long ago and is never asked; one
	-- without it is new (or reset). Stamped, like the stamp, in a key with no
	-- default. Read before that stamp is written.
	if profile.firstRun == nil then
		profile.firstRun = p.anchorCarried == true and "existing" or "pending"
	end
	oneOf(profile, "firstRun", { pending = true, answered = true, skipped = true, existing = true }, "existing")

	-- Beta.1 moved the default anchor from the middle of the screen to the
	-- bottom edge; AceDB strips values equal to their default, so a 0.9.x
	-- prompt on the middle kept only its offsets, and a negative one lands off
	-- screen. It is carried back to the middle. A beta.1-3 Y slider setting
	-- looks the same on disk, so the player is told how to undo it. Once per
	-- profile, stamped in a key with no default so AceDB never strips it.
	if p.anchorCarried ~= true then
		if p.point == "BOTTOM" and p.relPoint == "BOTTOM"
			and type(p.y) == "number" and p.y < 0 then
			p.point, p.relPoint = "CENTER", "CENTER"
			ns.anchorCarriedNote = true
		end
		p.anchorCarried = true
	end

	-- Up to beta.4 offsets were in scaled units; they are UIParent's now
	-- (ApplyStyle, FinishDrag), so a prompt dragged at any scale but 1 has its
	-- offsets multiplied by that scale once. One on a preset is left there.
	-- Stamped like the carry-over above.
	if p.offsetsUnscaled ~= true then
		if p.scale ~= 1 and not ns.CurrentPositionPreset()
			and type(p.x) == "number" and type(p.y) == "number" then
			p.x, p.y = math.floor(p.x * p.scale + 0.5), math.floor(p.y * p.scale + 0.5)
		end
		p.offsetsUnscaled = true
	end
	oneOf(p, "point", VALID_ANCHORS, "CENTER")
	oneOf(p, "relPoint", VALID_ANCHORS, "CENTER")
	-- An offset no screen has, which only a hand-edited file can write and
	-- SetPoint takes without complaint, leaving the prompt nowhere. The whole
	-- position goes back to the default, since half of one is meaningless.
	local function offset(v)
		return type(v) == "number" and v == v and v <= 10000 and v >= -10000
	end
	if not offset(p.x) or not offset(p.y) then
		local d = ns.defaults.profile.prompt
		p.point, p.relPoint, p.x, p.y = d.point, d.relPoint, d.x, d.y
	end

	-- Only a sound key that is not a string is repaired: a sound pack loading
	-- after this addon has not registered its sounds yet. PlayPromptSound
	-- falls back to ours when the key is missing at play time.
	local snd = profile.sound
	if type(snd.file) ~= "string" then snd.file = ns.SOUND_KEY end

	-- A pin nobody's class has goes. Another class's pin stays, since the
	-- profile is shared by every character; PickBuffFor reads it as Automatic.
	local choice = profile.buff.choice
	if choice ~= "auto" and not ns.AnyClassHasBuff(choice) then
		profile.buff.choice = "auto"
	end

	-- Colours are read as four numbers unchecked; repaired with a copy, as above.
	-- The alpha too, which may be absent (opaque) but nothing else: every look
	-- does arithmetic on it. A channel past 0..1 is put back inside, as an
	-- imported colour is.
	local function channel(v)
		return type(v) == "number" and v == v
	end
	for _, key in ipairs({ "fontColor", "bgColor", "accentColor" }) do
		local c = p[key]
		if type(c) ~= "table" or not channel(c[1]) or not channel(c[2]) or not channel(c[3])
			or (c[4] ~= nil and not channel(c[4])) then
			local d = ns.defaults.profile.prompt[key]
			p[key] = { d[1], d[2], d[3], d[4] }
		else
			for i = 1, 4 do
				if c[i] ~= nil then c[i] = math.min(math.max(c[i], 0), 1) end
			end
		end
	end

	-- Last, the numbers and texts among the defaults of the wrong type: back to
	-- their default, whatever the repairs above did not reach. Types only: a
	-- valid value, off its default or not, is left as it is.
	repair(false)
end

-- The line for a prompt the anchor carry-over has just moved. Not said by the
-- clamp, which runs at load before the chat frame exists: at login it waits
-- for the build line, on a profile switch it follows the clamp. Once.
function ns.SayAnchorCarried()
	if not ns.anchorCarriedNote then return end
	ns.anchorCarriedNote = nil
	addon:Print(L["the prompt was moved onto its new anchor, the middle of the screen. If you had put it at the bottom edge on purpose, drag it back or pick a place under |cffffd100Where it sits|r on the options page."])
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("MannersDB", defaults, true)
	ns.db = self.db


	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	-- Deleting a profile only ends an import's undo made on the deleted one.
	self.db.RegisterCallback(self, "OnProfileDeleted", "ProfileDeleted")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "SaveDebts")

	-- Probe first: ClampSettings validates the pinned buff against caps.class.
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
	-- Guarded: a repair that fails must not take the debts, the ledger, the
	-- options and the slash commands with it.
	ns.Guard("ClampSettings", ns.ClampSettings)
	-- After the clamp, so debts meet a validated window. Once per session, not
	-- on PLAYER_ENTERING_WORLD, which would resurrect debts already settled.
	ns.Guard("RestoreDebts", ns.RestoreDebts)
	-- After the debts are back, so the ledger can check its owed rows.
	ns.TellLedger("Load")
	ns.Guard("SetupOptions", ns.SetupOptions)
	ns.Guard("Prompt:Create", function() ns.Prompt:Create() end)

	self:RegisterChatCommand("manners", "HandleSlash")
	self:RegisterChatCommand("mnr", "HandleSlash")
end

function addon:OnEnable()
	-- Registering an event the client does not have throws; each is guarded
	-- so one cannot abort the rest, the scanner with it.
	for _, event in ipairs({
		"UNIT_AURA",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_REGEN_ENABLED",
		-- The prompt freezes when a fight starts and must show it at once.
		"PLAYER_REGEN_DISABLED",
		"SPELLS_CHANGED",
		-- Tracking switched on or off (Find Herbs and the like).
		"MINIMAP_UPDATE_TRACKING",
		-- A mage's scrolls: the bags and the weapon in the main hand.
		"BAG_UPDATE_DELAYED",
		"PLAYER_EQUIPMENT_CHANGED",
		-- A stone, a poison, an oil or a lure on a weapon going on or wearing
		-- off.
		"WEAPON_ENCHANT_CHANGED",
		"NAME_PLATE_UNIT_ADDED",
		"NAME_PLATE_UNIT_REMOVED",
		-- Cooldowns the client takes back; the casts are below.
		"SPELL_UPDATE_COOLDOWN",
		"UI_ERROR_MESSAGE",
		-- A back-off lifts when the player targets that person themselves.
		"PLAYER_TARGET_CHANGED",
		"PLAYER_UNGHOST",
		"PLAYER_ALIVE",
		"PLAYER_DEAD",
		-- People asking for a buff. Registered whether that source is on or
		-- not: the handler asks the switch first.
		"CHAT_MSG_SAY",
		"CHAT_MSG_YELL",
		"CHAT_MSG_PARTY",
		"CHAT_MSG_PARTY_LEADER",
		"CHAT_MSG_RAID",
		"CHAT_MSG_RAID_LEADER",
		"CHAT_MSG_INSTANCE_CHAT",
		"CHAT_MSG_INSTANCE_CHAT_LEADER",
		"CHAT_MSG_WHISPER",
		-- A ready check puts the group first while it runs (Queue.lua).
		-- The events the Camelot group frames listen to for it.
		"READY_CHECK",
		"READY_CHECK_FINISHED",
		-- The Manners macro made, deleted or moved in the macro window: its
		-- slot on an action bar is set again (Clicks.lua).
		"UPDATE_MACROS",
		-- A loading screen or a logout: the bar macro goes back to its first
		-- line (Clicks.lua). And the macro window loading, which the bar macro
		-- writes nothing under while it is open.
		"PLAYER_LEAVING_WORLD",
		"ADDON_LOADED",
		-- The screen's size or the UI's scale changed (a new resolution, the UI
		-- scale slider, a window moved to another monitor): the prompt is styled
		-- again, since the side the list hangs on and what else the style reads of
		-- the screen were worked out for the old one.
		"UI_SCALE_CHANGED",
		"DISPLAY_SIZE_CHANGED",
	}) do
		ns.Guard("RegisterEvent " .. event, function() self:RegisterEvent(event) end)
	end

	-- A restriction beginning or ending (a fight, an encounter, a key, a match),
	-- on the clients that have restrictions: the probe's notes of which auras
	-- are hidden depend on it (addon:ADDON_RESTRICTION_STATE_CHANGED). The
	-- classic family has no such event, and asking for it would throw.
	if caps.family == "modern" then
		ns.Guard("RegisterEvent ADDON_RESTRICTION_STATE_CHANGED", function()
			self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
		end)
	end

	-- The player's own casts, on a frame of our own that asks the client for the
	-- player's alone: through AceEvent every cast in sight was dispatched (320-490
	-- ns each) to a handler that threw it away -- in a raid fight, about as much
	-- as the whole tick. The handlers keep their unit checks for a client without
	-- RegisterUnitEvent. The frame is made once, whatever calls OnEnable again.
	for _, event in ipairs({
		"UNIT_SPELLCAST_SENT",
		"UNIT_SPELLCAST_SUCCEEDED",
		"UNIT_SPELLCAST_FAILED",
		-- The sweep over the prompt's icon follows casts starting, pushed back
		-- and stopped early.
		"UNIT_SPELLCAST_START",
		"UNIT_SPELLCAST_DELAYED",
		"UNIT_SPELLCAST_INTERRUPTED",
	}) do
		ns.Guard("RegisterEvent " .. event, function()
			local casts = ns.castEvents
			if not casts then
				casts = CreateFrame("Frame")
				casts:SetScript("OnEvent", function(_, event, ...) addon[event](addon, event, ...) end)
				ns.castEvents = casts
			end
			if type(casts.RegisterUnitEvent) == "function" then
				casts:RegisterUnitEvent(event, "player")
			else
				casts:RegisterEvent(event)
			end
		end)
	end

	-- The combat log only where the client is believed to have one: Forever
	-- and retail 12.0+ forbid the registration, and asking there would print
	-- a red line on every login. Armed only once the call went through, and
	-- everything that cares reads the flag, not caps.combatLog.
	if caps.combatLog then
		ns.Guard("RegisterEvent COMBAT_LOG_EVENT_UNFILTERED", function()
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			ns.combatLogArmed = true
			ns.logScan.armed = true
		end)
	end

	ns.Guard("StartScanner", function() self:StartScanner() end)
	ns.Guard("ApplyStyle", function() ns.Prompt:ApplyStyle() end)

	-- Say so out loud: silence is indistinguishable from failure.
	C_Timer.After(2, function()
		local buff = ns.ResolveBuff(true)
		-- A class with nothing to cast gets the greeting's sentence, not "no
		-- buff learned".
		local nothingToGive = caps.class ~= nil and ns.CLASSES_WITHOUT_BUFFS ~= nil
			and ns.CLASSES_WITHOUT_BUFFS[caps.class] == true
		-- The profile is shared, so off on one character is off on every alt.
		local off = not self.db.profile.enabled
		-- Nothing for anybody else and one of your own buffs to remind you of: a
		-- hunter or a shaman, a warlock before Unending Breath, or every spell
		-- switched off. Still a prompt, for yourself.
		local ownLive = not buff and ns.OwnBuffsLive()
		if not buff and nothingToGive and not ownLive then
			self:Print(L["build |cffffd100%s|r -- this class has no buffs to cast on other players."]:format(tostring(ns.BUILD)))
		elseif off then
			self:Print(L["build |cffffd100%s|r -- |cffff8080switched off on this profile|r; |cffffd100/manners on|r to start."]
				:format(tostring(ns.BUILD)))
		elseif buff then
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100%s|r."]:format(
				tostring(ns.BUILD), ns.BuffName(buff)))
		elseif ownLive and nothingToGive then
			self:Print(L["build |cffffd100%s|r -- this class has no buffs for other players, so Manners reminds you of your own."]
				:format(tostring(ns.BUILD)))
		elseif ownLive then
			-- Translators: its own sentence, like the one below it.
			self:Print(L["build |cffffd100%s|r watching your own buffs; nothing is offered to anybody else: %s."]
				:format(tostring(ns.BUILD), ns.NothingToCast()))
		else
			-- Translators: its own sentence, since the slot above takes a
			-- spell's name and a reason does not fit there in every language.
			self:Print(L["build |cffffd100%s|r watching for buffs. Ready to cast |cffffd100nothing -- %s|r."]:format(
				tostring(ns.BUILD), ns.NothingToCast()))
		end
		ns.SayAnchorCarried()
		-- The macro an older version made, while nothing else is going on.
		ns.SettleOldMacro()
		-- On this character's first login, what the thing is for, on the same delay
		-- (nothing printed before the chat frame exists is seen); guarded, and told
		-- whether the line above said the profile is off.
		ns.Guard("Welcome", ns.Welcome, false, off)
	end)
end

function addon:StartScanner()
	if self.scanTimer then self:CancelTimer(self.scanTimer) end
	self.scanTimer = self:ScheduleRepeatingTimer("Tick", self.db.profile.timing.scanInterval or 0.4)
end

function addon:Tick()
	ns.Guard("Tick", addon.TickBody, self)
end

function addon:TickBody()
	local now = GetTime()
	-- All but the aura cache live in files that load after this one
	-- (Queue.lua, Clicks.lua), so they are read here and not at load.
	local owed, tried, LiveExpiry, TellLedger = ns.owed, ns.tried, ns.DebtExpiry, ns.TellLedger
	local SweepPendingClick, PruneSettled = ns.SweepPendingClick, ns.PruneSettled
	SweepAuraCache(now)
	-- On the tick, because the case it decides has no event: a /target that
	-- resolves nobody leaves the /cast with no aim, and the game says nothing.
	SweepPendingClick(now)
	-- Casts that went out and were not refused in their window have landed,
	-- which is what forgets a person's refusals.
	PruneSettled(now)
	ns.SweepRefusals(now)
	for name, entry in pairs(owed) do
		if LiveExpiry(entry) <= now then
			owed[name] = nil
			TellLedger("LetGo", name)
		end
	end
	for key, expiry in pairs(tried) do
		if expiry <= now then tried[key] = nil end
	end
	-- Every tick, fights included, since that is where people die; guarded so
	-- a failure there cannot stop the repaint below.
	ns.Guard("death watch", ns.WatchGroupDeaths, now)
	-- The walk of your own buffs a fight's aura events left due (Favours.lua,
	-- UNIT_AURA): one a tick however many came, and a favour filed first.
	ns.FlushOwnScan()
	-- Your own auras changed since the last tick: what Automatic remembers,
	-- in a fight and in town too (see RememberOwnBuffs), ahead of the repaint.
	if ns.ownAurasChanged then ns.Guard("remember own buffs", ns.RememberOwnBuffs) end
	-- Before the repaint, which then puts the prompt back.
	ns.EndSnoozeIfDue(now)
	ns.Prompt:Refresh()
end

function addon:ProfileDeleted(event, _, name)
	ns.ProfileChangedForUndo(event, name)
end

-- `event` is AceDB's, and nil when an import or its undo calls this itself.
function addon:RefreshConfig(event)
	ns.Guard("ClampSettings", ns.ClampSettings)
	-- A profile switched to may just have been carried over; chat exists now.
	ns.SayAnchorCarried()
	-- Guarded like the login's: a profile the clamp could not mend must not
	-- take the scanner below with it.
	ns.Guard("ApplyStyle on profile change", ns.Prompt.ApplyStyle, ns.Prompt)
	ns.Prompt:InvalidateMacro()
	-- Guarded: nil if Options/Launcher.lua failed to load, and a throw here
	-- would take StartScanner with it.
	ns.Guard("RefreshMinimapButton", ns.RefreshMinimapButton)
	-- An import's undo belongs to the profile it was made on:
	-- ProfileChangedForUndo decides what a switch, copy or reset does to it,
	-- and an import or its undo calling this ends it (an import sets it again).
	if event == nil then
		ns.ForgetImportUndo()
	else
		ns.ProfileChangedForUndo(event)
	end
	self:StartScanner()
	-- Every setting changed at once, the on switch among them, and the
	-- launcher's text is only put back from here.
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- events
--
-- The client's events that are no one section's own: the spellbook changing,
-- your target, dying and coming back, and a fight starting and ending.
---------------------------------------------------------------------------

local lastProbe = 0

-- SPELLS_CHANGED fires often, so the probe is rate-limited -- with a trailing
-- edge, so a buff learned in the middle of a burst (a trainer visit) is still
-- noticed.
local probeQueued = false
-- Tracking changed: the next scan reads the minimap's list afresh, and the
-- one you switched on is remembered for Automatic.
function addon:MINIMAP_UPDATE_TRACKING()
	ns.ForgetTrackingList()
	ns.ownAurasChanged = true
end

-- A mage's scrolls and every class's weapon enhancements (Core.lua's own
-- buffs): the bags changed, so their counts are read again when next asked; the
-- same for the weapon in each hand. Nothing else is read here, and nothing for
-- a class with none.
function addon:BAG_UPDATE_DELAYED() ns.ForgetScrolls() end
function addon:PLAYER_EQUIPMENT_CHANGED() ns.ForgetHands() end

-- A temporary enchant went on a weapon or came off: your own buffs are read
-- again on the next tick, which writes the one on the weapon down for
-- Automatic, rather than at the next change of anything else. Nothing is read
-- here; the event fires for each weapon and for each change of its time.
function addon:WEAPON_ENCHANT_CHANGED() ns.ownAurasChanged = true end

-- Putting an enhancement over the one a weapon carries makes the game ask
-- whether to replace it (REPLACE_ENCHANT, a StaticPopup of the same name
-- whose YES calls C_Item.ReplaceEnchant), a top-up of one running low
-- included. That question is the player's to answer, and Manners never
-- answers it: it does not listen for the event, call that function or hide the
-- popup. Nothing shows that a call from an event handler is allowed, and a
-- Blizzard popup hidden from addon code risks taint.

function addon:SPELLS_CHANGED()
	local now = GetTime()
	if now - lastProbe < 5 then
		if not probeQueued and C_Timer and C_Timer.After then
			probeQueued = true
			C_Timer.After(5 - (now - lastProbe), function()
				probeQueued = false
				lastProbe = GetTime()
				ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
			end)
		end
		return
	end
	lastProbe = now
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
end

-- The probe notes, per aura id, whether the client calls it secret at that
-- moment, and the restrictions in force decide that. One taken inside a
-- restriction (a /reload mid-fight, a key under way) notes every buff as
-- hidden, and UnitHasBuff then answers "cannot tell" for everybody until the
-- next loading screen or spellbook change, long after the client reads the
-- auras again. So the probe is taken again when a restriction ends -- the
-- client's word of it, or the fight ending -- if it noted anything hidden and
-- the client no longer hides auras. Only then: the other way round (a
-- restriction beginning after the probe) is asked at read time, in UnitHasBuff.
function addon:ADDON_RESTRICTION_STATE_CHANGED()
	local hidden = false
	for _, info in pairs(caps.buffs) do
		for _, secret in pairs(info.secrecy) do
			if secret == true then hidden = true end
		end
	end
	if not hidden then return end
	local ask = C_Secrets and C_Secrets.ShouldAurasBeSecret
	if type(ask) == "function" and plain(ask()) == true then return end
	ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
end

-- A deliberate choice of somebody backed off (see NoteRefusal) tries them
-- again: the back-off must never keep the player from somebody they point at.
-- The prompt's own macro targets and hands back inside a press, and those are
-- not choices, so a change this close to a press is ignored.
function addon:PLAYER_TARGET_CHANGED()
	local at = ns.pressAt
	if at and GetTime() - at < 0.5 then return end
	ns.LiftBackoff(ns.UnitFullName("target"))
	-- Whether the macro hands your target back or clears it depends on whether
	-- you have one (Prompt/Macro.lua, HandBack): armed again now rather than at
	-- the next scan, for the bar macro that carries it (Clicks.lua).
	local P = ns.Prompt
	if P and P.state.current and not InCombatLockdown() then
		ns.Guard("hand-back", P.ApplyTarget, P, P.state.current, P.state.phraseArmed ~= true)
	end
end

-- A loading screen or a logout (Clicks.lua, click macro); the next
-- PLAYER_ENTERING_WORLD (Favours.lua) lets it go.
function addon:PLAYER_LEAVING_WORLD()
	if ns.ParkMacroBody then ns.Guard("bar macro", ns.ParkMacroBody) end
end

-- Blizzard_MacroUI loads when the macro window is first opened.
function addon:ADDON_LOADED(_, name)
	if name == "Blizzard_MacroUI" and ns.WatchMacroWindow then ns.Guard("macro window", ns.WatchMacroWindow) end
end

-- Not per scan: the client fires these when the display changes, and once for
-- each such change. The style is applied out of combat at once; in a fight
-- ApplyStyle keeps it for the fight's end (pendingStyle, flushed by
-- PLAYER_REGEN_ENABLED), as it does for every other restyle.
function addon:UI_SCALE_CHANGED()
	if ns.Prompt then ns.Guard("restyle for the display", ns.Prompt.ApplyStyle, ns.Prompt) end
end
addon.DISPLAY_SIZE_CHANGED = addon.UI_SCALE_CHANGED

function addon:PLAYER_DEAD() if ns.Prompt then ns.Prompt:Refresh() end end
function addon:PLAYER_ALIVE() if ns.Prompt then ns.Prompt:Refresh() end end
function addon:PLAYER_UNGHOST() if ns.Prompt then ns.Prompt:Refresh() end end

-- Combat freezes the secure attributes: until the fight ends the button runs
-- whatever macro it had when the fight started, and the panel must show that
-- hold. The client fires this just before lockdown begins (InCombatLockdown()
-- is still false; other addons call protected methods from it), so a Refresh
-- now re-aims the macro while it still can, and a second one next frame,
-- under lockdown, paints the hold.
function addon:PLAYER_REGEN_DISABLED()
	-- First, while the button can still be touched: a drag held into the pull
	-- is let go of and its position kept, rather than released in the fight.
	if ns.Prompt then ns.Guard("drag at fight start", ns.Prompt.FinishDragForFight, ns.Prompt) end
	-- A list row holds a macro only for the length of a press, so this finds
	-- nothing unless a press was cut short; but the fight freezes whatever it
	-- finds, and a row must never be left aimed at somebody.
	if ns.Prompt then ns.Guard("rows at fight start", ns.Prompt.DisarmRows, ns.Prompt) end
	-- Somebody who asked for a buff is not let go while you cannot offer it.
	ns.Guard("requests at fight start", ns.HoldRequestsForFight)
	-- The pull ends the sweep a ready check started; before the repaint below.
	ns.Guard("ready check at fight start", ns.EndReadyCheck)
	-- The macro armed now serves every press in the fight whatever the player
	-- targets meanwhile, so it hands the target back even for somebody who is
	-- the target now. See STRATEGIES.target.
	if ns.Prompt then ns.Prompt.armedForFight = true end
	if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
	C_Timer.After(0, function()
		if ns.Prompt then ns.Guard("combat hold", ns.Prompt.Refresh, ns.Prompt) end
	end)
	-- The Prompt tab's controls cannot act in a fight and the tab says so while
	-- drawn, so it is redrawn at both ends of the fight.
	ns.RepaintOptions()
end

function addon:PLAYER_REGEN_ENABLED()
	-- First, so everything below reads the buffs as the probe now has them.
	ns.Guard("restriction ended", self.ADDON_RESTRICTION_STATE_CHANGED, self)
	-- What the fight withheld is asked again on the next scan rather than three
	-- seconds on, and a probe made in the fight is made again (see
	-- caps.probedInFight), once more a few seconds on should the client still
	-- be withholding: before the repaint below, so it reads afresh.
	if caps.probedInFight then
		ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
		if caps.probedInFight and C_Timer and C_Timer.After then
			C_Timer.After(3, function()
				if caps.probedInFight and not InCombatLockdown() then
					ns.Guard("ProbeCapabilities", ns.ProbeCapabilities)
				end
			end)
		end
	end
	ns.ForgetRefusals()
	if ns.ForgetUnreadPassersBy then ns.ForgetUnreadPassersBy() end
	-- A buff that landed after the fight's last tick, walked now so its favour
	-- is filed before the repaint below offers anybody.
	ns.FlushOwnScan()
	-- Secure frames cannot be restyled or retargeted in combat, so what was
	-- deferred is flushed here. ApplyStyle ends in a Refresh; with nothing
	-- deferred, a Refresh alone takes the hold off now rather than at the next
	-- scan. The macro stops being built for a fight first, so that Refresh
	-- drops the hand-back for somebody already the target.
	if ns.Prompt then ns.Prompt.armedForFight = false end
	-- Requests held through the fight get their minute from now, before the
	-- Refresh below so it can offer them.
	ns.Guard("requests after the fight", ns.RequestsAfterFight)
	if ns.Prompt and ns.Prompt.pendingStyle then
		ns.Prompt:ApplyStyle()
	elseif ns.Prompt then
		ns.Guard("combat release", ns.Prompt.Refresh, ns.Prompt)
	end

	ns.RepaintOptions()
	-- The bar macro's hold for a cooldown still running as the fight ends
	-- (Clicks.lua).
	if ns.NoteBarCooldown then ns.Guard("bar macro cooldown", ns.NoteBarCooldown) end

	-- A first greeting stood down by a fight gets another go; on every other
	-- fight the flag is read first and this returns at once.
	ns.Guard("Welcome", ns.Welcome)
	-- And the old macro, for the same reason: it cannot be edited in a fight.
	if ns.SettleOldMacro then ns.SettleOldMacro() end
	-- And the macro's slot on an action bar, for what the fight held back
	-- (Clicks.lua): the prompt's own Refresh above arms what is owed now.
	if ns.ResyncMacroSlot then ns.Guard("macro slot", ns.ResyncMacroSlot) end
end

-- Kept in SavedVariables so the probe -- and whatever the console has printed
-- since -- can be read off disk without logging in or transcribing chat.
function ns.WriteProbe()
	MannersDB = MannersDB or {}
	MannersDB.console = ns.console
	local dump = {
		at = date("%Y-%m-%d %H:%M:%S"),
		version = (GetBuildInfo()),
		toc = select(4, GetBuildInfo()),
		flavour = caps.flavour,
		family = caps.family,
		-- Which spell tables the flavour was given: flavours share sets, and an
		-- unrecognised client gets one by guess.
		buffData = ns.BUFFS_SOURCE,
		buffDataMissing = ns.BUFFS_MISSING,
		combatLog = caps.combatLog,
		combatLogProbe = caps.combatLogProbe,
		-- What the second source actually did, beside what the client was
		-- thought to allow: armed and silent is a different bug from never armed.
		combatLogArmed = ns.logScan.armed,
		combatLogSeen = ns.logScan.applied,
		combatLogFiled = ns.logScan.noted,
		secretRestrictions = caps.secretRestrictions,
		conditionalTargeting = caps.conditionalTargeting,
		unitConditionals = caps.unitConditionals,
		targetExact = caps.targetExact,
		unitNameIsSurname = caps.unitNameIsSurname,
		class = caps.class,
		getUnitAuraBySpellID = caps.getUnitAuraBySpellID,
		hasSecrets = caps.hasSecrets,
		aurasSecretNow = caps.aurasSecretNow,
		namePlates = caps.namePlates,
		anyKnown = caps.anyKnown,
		anyReadable = caps.anyReadable,
		buffs = {},
	}
	for key, info in pairs(caps.buffs) do
		dump.buffs[key] = {
			name = info.name,
			known = info.known,
			knownGroup = info.knownGroup,
			groupRank = info.groupRank,
			groupReagent = info.groupReagent,
			topRank = info.topRank,
			readable = info.readable,
			secrecy = info.secrecy,
			-- The ids this client does not have, listed: fixing it means editing
			-- exactly those.
			unresolved = info.unresolved,
		}
	end
	MannersDB.probe = dump
end
