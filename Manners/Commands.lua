-- Manners -- what the player types and reads: the first-run greeting, the
-- test console, snooze, sharing settings, and the slash commands with their
-- diagnostics.

local ns = select(2, ...)
local L = ns.L
local addon = ns.addon

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

-- Core.lua's and Queue.lua's, which load first.
local plain, caps, MANA = ns.plain, ns.caps, ns.MANA
local owed, LiveExpiry = ns.owed, ns.DebtExpiry

---------------------------------------------------------------------------
-- first run
--
-- A greeting, once: what the addon does, what it looks like and where, and the
-- one thing it cannot do for you -- otherwise nothing shows until a stranger
-- buffs you, which reads as an addon that does not work.
--
-- The flag lives in db.char, not the profile: every character starts on the
-- shared "Default" profile, so a profile flag would greet only the first
-- character. What it asks for (a macro, a key) is per character anyway.
---------------------------------------------------------------------------

-- What "Myself" is doing, for /manners debug and Diagnostics: what holds
-- everything on yourself back, if anything; your group buff when it is the one
-- on the prompt (Queue.lua, SelfEntry); then a line per family of your class's
-- own buffs, from the queue's own answers (Core.lua, OwnVerdict), so the two
-- cannot disagree. Nothing when "Myself" is off, and only the one line when
-- your own name is on the never-offer list. Whole sentences per case.
do
	local HELD = {
		fight = L["your own buffs: held back -- you are in a fight."],
		skipped = L["your own buffs: held back -- skipped for now."],
		noname = L["your own buffs: held back -- the game will not say your name."],
		listed = L["your own buffs: held back -- you are on your never-offer list."],
	}

	local function FamilyLine(family, ctx)
		local label = ns.OwnFamilyLabel(family)
		local spell, has, _, why, about = ns.OwnVerdict(family, ctx)
		local name = about and ns.BuffName(about)
		if spell and has then
			return L["%s: %s is running low -- a top-up is due."]:format(label, ns.BuffName(spell))
		elseif spell and spell.item then
			return L["%s: none up -- %s is the one to use."]:format(label, ns.BuffName(spell))
		elseif spell then
			return L["%s: none up -- %s is the one to cast."]:format(label, ns.BuffName(spell))
		elseif why == "off" then
			return L["%s: switched off (Don't remind me)."]:format(label)
		elseif why == "up" and not name and family.enhance then
			-- An enchant none of this family's items makes: the weapon is seen to.
			return L["%s: the weapon already carries a temporary enchant."]:format(label)
		elseif why == "up" and not name and family.imbue then
			-- An oil, or an enchant no scroll makes: the weapon is seen to.
			return L["%s: your main hand already carries a temporary enchant."]:format(label)
		elseif why == "up" or why == "covered" then
			-- "covered": somebody else's copy of it reaches you (a shared
			-- family, Core.lua OwnAutoPick), and a second would not stack.
			return L["%s: %s is up."]:format(label, name or "?")
		elseif why == "bags" then
			return L["%s: you have no %s in your bags."]:format(label, name or "?")
		elseif why == "level" then
			return L["%s: %s needs level %d."]:format(label, name or "?", about.level)
		elseif why == "noweapon" and family.enhance then
			-- The label names the hand.
			return L["%s: there is no weapon in that hand."]:format(label)
		elseif why == "noweapon" then
			return L["%s: there is no weapon in your main hand."]:format(label)
		elseif why == "weapon" and family.enhance then
			return L["%s: %s does not fit the weapon in that hand."]:format(label, name or "?")
		elseif why == "weapon" then
			return L["%s: %s does not fit the weapon in your main hand."]:format(label, name or "?")
		elseif why == "notank" then
			return L["%s: Automatic, and your group role is not tank, so it is not offered."]:format(label)
		elseif why == "tried" then
			return L["%s: %s was pressed or skipped a moment ago."]:format(label, name or "?")
		elseif why == "unusable" then
			return L["%s: the game says %s cannot be cast right now."]:format(label, name or "?")
		elseif why == "none" then
			return L["%s: Automatic has nothing it would pick."]:format(label)
		end
		return L["%s: the game will not say whether it is up, so it is not offered."]:format(label)
	end

	function ns.MyselfLines(now)
		local db = addon.db and addon.db.profile
		local out = {}
		if not db or db.sources.self ~= true then return out end
		local families = ns.KnownOwnFamilies()
		if #families == 0 and #ns.SelfBuffs() == 0 then return out end
		local held = ns.MyselfHeldBack(db, now)
		if held == "resting" then
			out[#out + 1] = L["your own buffs: held back -- you are in a city or an inn, and %s is off."]
				:format("|cffffd100" .. L["Also in cities and inns"] .. "|r")
		elseif held then
			out[#out + 1] = HELD[held]
		end
		-- On your own never-offer list nothing is offered to you, so no family
		-- below would be "the one to cast": the line above says why, and is all.
		if held == "listed" then return out end
		-- Your group buff is due: the lines below wait behind it.
		local first = #families > 0 and ns.SelfBuffFirst(db, now)
		if first then
			out[#out + 1] = L["your own %s comes first -- the buffs below wait until it has been cast."]
				:format(ns.BuffName(first))
		end
		local ctx = { name = ns.UnitFullName("player"), now = now,
			whenBuffed = db.filters.whenBuffed, refreshUnder = db.filters.refreshUnder }
		for _, family in ipairs(families) do out[#out + 1] = FamilyLine(family, ctx) end
		return out
	end
end

-- When a top-up is due for each of your class's buffs, for /manners debug and
-- Diagnostics: how long the buff lasts (the client's own table, Buffs.lua; the
-- aura's own word replaces it while one is on somebody) and the lead that gives
-- in the group, in a raid or dungeon and outside your group (Core.lua,
-- ns.TopUpLead), under the player's ceiling. Whole sentences per case; a
-- buff with no timer is said to be never topped up, and one nobody knows the
-- length of is topped up at the ceiling alone.
function ns.LeadLines()
	local db = addon.db and addon.db.profile
	local out = {}
	if not db then return out end
	local ceiling = db.filters.refreshUnder
	local KIND, Lead, Text = ns.LEAD_KIND, ns.TopUpLead, ns.TimeText
	for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
		local name = ns.BuffName(buff)
		local single, group = ns.BuffSeconds(buff)
		local seconds = single or group
		if seconds == 0 and not group then
			out[#out + 1] = L["%s: no timer -- never topped up."]:format(name)
		elseif not seconds or seconds == 0 then
			out[#out + 1] = L["%s: length unknown -- topped up at %s left, %s in a raid or dungeon."]
				:format(name, Text(Lead(nil, KIND.group, ceiling)), Text(Lead(nil, KIND.raid, ceiling)))
		else
			local lasts = Text(seconds)
			if single and group then lasts = lasts .. " " .. L["(%s as a group cast)"]:format(Text(group)) end
			out[#out + 1] = L["%s: lasts %s -- topped up at %s left, %s in a raid or dungeon, %s outside your group."]
				:format(name, lasts, Text(Lead(seconds, KIND.group, ceiling)),
					Text(Lead(seconds, KIND.raid, ceiling)), Text(Lead(seconds, KIND.stranger, ceiling)))
		end
	end
	-- Your own: more than one spell of a family can be learned, and each is its own length.
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if family.toggle then
			out[#out + 1] = L["%s: no timer -- never topped up."]:format(ns.OwnFamilyLabel(family))
		elseif not family.tracking then
			for _, spell in ipairs(family.spells) do
				if ns.OwnSpellKnown(spell) then
					local seconds = ns.OwnSeconds(spell)
					local name = ns.BuffName(spell)
					if seconds == 0 then
						out[#out + 1] = L["%s: no timer -- never topped up."]:format(name)
					elseif not seconds then
						out[#out + 1] = L["%s: length unknown -- topped up at %s left, %s in a raid or dungeon."]
							:format(name, Text(Lead(nil, KIND.own, ceiling)), Text(Lead(nil, KIND.ownraid, ceiling)))
					else
						out[#out + 1] = L["%s: lasts %s -- topped up at %s left, %s in a raid or dungeon."]
							:format(name, Text(seconds), Text(Lead(seconds, KIND.own, ceiling)),
								Text(Lead(seconds, KIND.ownraid, ceiling)))
					end
				end
			end
		end
	end
	return out
end

-- The heading over those lines, saying so when top-ups are off and none of it
-- is asked.
function ns.LeadHeading()
	local db = addon.db and addon.db.profile
	if db and db.filters.whenBuffed ~= "refresh" then
		return L["When a top-up is due (top-ups are off)"]
	end
	return L["When a top-up is due"]
end

-- /manners debug's block of them, indented under its heading; nothing when the
-- class has nothing of the kind.
local function PrintLeads(self)
	local lines = ns.LeadLines()
	if #lines == 0 then return end
	self:Print("  " .. ns.LeadHeading())
	for _, line in ipairs(lines) do self:Print("    " .. line) end
end

-- The sentence for a character that will never have anything to offer, shared
-- by /manners debug and the greeting. Translators: the greeting and the login
-- line carry their own copy inside a longer key, kept in step by hand.
ns.NO_CLASS_BUFFS = L["this class has no buffs to cast on other players."]

-- Returns true once it has said its piece, false while it is still waiting
-- (for a probe answer, or a fight to end). `force` is /manners welcome;
-- `offSaid` is the login line having just said the profile is switched off.
function ns.Welcome(force, offSaid)
	local store = addon.db and addon.db.char
	if type(store) ~= "table" then return false end
	if store.welcomed and not force then return true end

	-- The probe's verdict on this character. Indexed off caps.class, so a
	-- class not read (one secret value away on Forever and retail) is "not on
	-- the list" and meets the gate below with everything else that is no
	-- answer.
	local nothingToGive = caps.class ~= nil and ns.CLASSES_WITHOUT_BUFFS ~= nil
		and ns.CLASSES_WITHOUT_BUFFS[caps.class] == true
	-- ...and of those, a hunter or a shaman with a buff of his own learned,
	-- whose prompt reminds him of it: greeted with the prompt, not sent off.
	local ownOnly = nothingToGive and (caps.anyOwnKnown == true or ns.OwnItemsHeld())
	if ownOnly then nothingToGive = false end

	-- Not until the probe has an answer. hasClassBuffs is false for a rogue,
	-- for a class the client would not name, and for one an unrecognised
	-- client's guessed buff data does not know; greeting the last two with
	-- "no buffs" would state a guess as fact. Nothing is written down and the
	-- next login asks again; /manners debug says which case it is.
	if not (caps.hasClassBuffs or nothingToGive or ownOnly) then return false end

	-- Not in a fight: a protected frame cannot be shown during lockdown, and
	-- PLAYER_REGEN_ENABLED comes back for it. Except for the class with no
	-- picture: words work in a fight.
	if InCombatLockdown() and not nothingToGive then
		if force then
			addon:Print(L["|cffff8080not during a fight|r -- the prompt cannot be put on screen while one is on. Try again when it ends."])
		end
		return false
	end

	-- Written down before a word is printed: a line that throws then costs a
	-- short greeting once rather than on every login.
	store.welcomed = true

	if nothingToGive then
		-- No preview and no macro for a class that can never fill the prompt.
		addon:Print(L["|cffffd100Manners|r is installed, but this class has no buffs to cast on other players."])
		addon:Print(L["It is still worth keeping for an alt that does -- it will say hello again there."])
		return true
	end

	-- Spells learned, but nothing any prompt will offer (all switched off, or
	-- a pin on one not learned): name the setting instead of the tour. Not for
	-- a character with nothing learned yet, who will learn a spell soon; nor
	-- for one whose own buffs still put a prompt up, who gets the tour for it.
	local othersOff = caps.anyKnown and not ns.ResolveBuff(true)
	local ownLive = ns.OwnBuffsLive()
	if othersOff and not ownLive then
		addon:Print(L["|cffffd100Manners|r is installed, but nothing will be offered to anybody: %s."]
			:format(ns.NothingToCast()))
		addon:Print(L["|cffffd100/manners welcome|r brings the rest of this back once that changes."])
		return true
	end

	-- A hunter or shaman with Myself (or every one of his own buffs) switched
	-- off, perhaps by another character on the shared profile: no prompt will
	-- ever come, so no tour and no preview of one. The launcher says the same.
	if ownOnly and not ownLive then
		addon:Print(L["Nothing to do: your own buffs are switched off under %s."]:format(L["Myself"]))
		addon:Print(L["|cffffd100/manners welcome|r brings the rest of this back once that changes."])
		return true
	end

	-- A class whose buffs reach only the party has no passer-by to offer to,
	-- and one with nothing for anybody else has only itself.
	if ownOnly then
		addon:Print(L["|cffffd100Manners|r puts your own buffs on a small prompt when none of them is up -- your class has none for other players. Clicking the prompt casts it on you."])
	elseif othersOff then
		-- Your spells for others all switched off, and yours still offered.
		addon:Print(L["|cffffd100Manners|r puts your own buffs on a small prompt when none of them is up; nothing is offered to anybody else: %s. Clicking the prompt casts it on you."]
			:format(ns.NothingToCast()))
	elseif ns.OnlyReachesGroup() then
		local buff = ns.ResolveBuff(true)
		if buff then
			addon:Print(L["|cffffd100Manners|r puts anybody in your group who is missing your |cffffd100%s|r -- or who has just buffed you -- on a small prompt. Clicking the prompt casts it."]
				:format(ns.BuffName(buff)))
		else
			addon:Print(L["|cffffd100Manners|r puts anybody in your group who is missing your |cffffd100buff|r -- or who has just buffed you -- on a small prompt. Clicking the prompt casts it."])
		end
	else
		addon:Print(L["|cffffd100Manners|r puts anybody who buffs you -- and any stranger nearby who is missing one of yours -- on a small prompt. Clicking the prompt buffs them."])
	end
	addon:Print(L["The one thing that is not automatic: |cffffd100/manners macro|r or |cffffd100Put Manners on an action bar|r in the options puts a macro on your cursor for your bars, or bind a key under Options > Keybindings > Manners."])

	-- Switched off (perhaps by another character, on the shared profile): name
	-- the setting, unless the login line said so one line above.
	if addon.db.profile and not addon.db.profile.enabled and not offSaid then
		addon:Print(L["|cffff8080It is switched off on this profile|r, so no prompt will appear -- |cffffd100/manners on|r when you want it."])
	end

	-- Point at whichever panel will be on screen: somebody real already queued,
	-- or the preview. Only somebody who can really be on the panel counts:
	-- switched off, unlocked or snoozed, the queue fills but the button shows no
	-- one, and the preview runs in all three.
	local queued = 0
	local profile = addon.db.profile
	if profile and profile.enabled and profile.prompt.locked and not ns.SnoozeLeft() then
		local ok, list = pcall(ns.BuildQueue)
		if ok and type(list) == "table" then queued = #list end
	end

	if queued > 0 then
		addon:Print(L["The prompt is on screen now, with somebody real on it already. |cffffd100/manners welcome|r brings this back."])
	else
		-- The existing preview: the real panel in its real place. ToggleTest is
		-- a toggle, so only when none is running. The nil test is inside the
		-- guard: ns.Prompt is nil when Prompt/Prompt.lua did not load.
		ns.Guard("welcome preview", function()
			if ns.Prompt and not ns.Prompt:InTest() then ns.Prompt:ToggleTest() end
		end)
		addon:Print(L["That is the prompt, with a pretend name on it. |cffffd100/manners welcome|r brings this back."])
	end
	return true
end

---------------------------------------------------------------------------
-- test console
--
-- Iterating on this client otherwise means one guess per /reload. /manners
-- try arms arbitrary macro text on the prompt; /manners look dumps every API
-- answer for a unit, including which come back as secret values. Everything
-- printed also lands in SavedVariables, to be read off disk afterwards.
---------------------------------------------------------------------------

ns.console = {}

local function say(fmt, ...)
	local line = select("#", ...) > 0 and fmt:format(...) or fmt
	addon:Print(line)
	ns.console[#ns.console + 1] = line
	while #ns.console > 60 do table.remove(ns.console, 1) end
end
ns.Say = say

-- Reports the value, and separately whether the client refused to show it.
-- "false" and "withheld" look identical once plain() has run, and telling them
-- apart is most of the work on this client.
local function show(label, ok, value)
	if not ok then return ("%s=|cff808080n/a|r"):format(label) end
	if issecretvalue and issecretvalue(value) then
		return ("%s=|cffff8080SECRET|r"):format(label)
	end
	if value == nil then return ("%s=|cff808080nil|r"):format(label) end
	return ("%s=|cffffffff%s|r"):format(label, tostring(value))
end

local function raw(fn, ...)
	if type(fn) ~= "function" then return false end
	local results = { pcall(fn, ...) }
	if not results[1] then return false end
	return true, results[2], results[3]
end

function ns.InspectUnit(unit)
	unit = unit or (ns.lastTopUnit or "target")
	say("|cffffd100--- %s ---|r", unit)

	local okExists, exists = raw(UnitExists, unit)
	if not okExists or not plain(exists) then
		say("  %s", L["does not exist (or its existence is withheld)"])
		return
	end

	local _, n1, n2 = raw(UnitName, unit)
	local _, c1, c2 = raw(UnitClass, unit)
	say("  %s  %s", show("name", true, n1), show("second", true, n2))
	say("  %s  %s", show("class", true, c2), show("classLocalised", true, c1))
	say("  %s", show("guid", raw(UnitGUID, unit)))

	say("  %s  %s  %s",
		show("isPlayer", raw(UnitIsPlayer, unit)),
		show("canAssist", raw(UnitCanAssist, "player", unit)),
		show("dead", raw(UnitIsDeadOrGhost, unit)))
	say("  %s  %s  %s",
		show("connected", raw(UnitIsConnected, unit)),
		show("inParty", raw(UnitInParty, unit)),
		show("inRaid", raw(UnitInRaid, unit)))
	say("  %s  %s  %s",
		show("level", raw(UnitLevel, unit)),
		show("powerMax", raw(UnitPowerMax, unit, MANA)),
		show("power", raw(UnitPower, unit, MANA)))
	say("  %s  %s",
		show("pvp", raw(UnitIsPVP, unit)),
		show("pvpFreeForAll", raw(UnitIsPVPFreeForAll, unit)))

	if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret then
		say("  %s", show("identitySecret", raw(C_Secrets.ShouldUnitIdentityBeSecret, unit)))
	end

	local buff = ns.ResolveBuff(true)
	if buff then
		local info = ns.BuffInfo(buff)
		local id = info and info.topRank
		-- Taken before an `and` could collapse raw()'s two returns into one.
		local okById, byId
		if id then okById, byId = raw(C_Spell and C_Spell.IsSpellInRange, id, unit) end
		say("  %s  %s",
			show("inRangeById", okById, byId),
			show("inRangeByName", raw(C_Spell and C_Spell.IsSpellInRange, ns.BuffName(buff), unit)))
		if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
			-- Refusals kept apart from absence, the way UnitHasBuff keeps them.
			local found
			local withheld = {}
			local unreadable = info and info.readable == false
			for _, auraId in ipairs(buff.auraIds) do
				local ok, aura = raw(C_UnitAuras.GetUnitAuraBySpellID, unit, auraId)
				if ok and aura ~= nil and not (issecretvalue and issecretvalue(aura)) then
					found = auraId
					break
				elseif not ok or (issecretvalue and issecretvalue(aura))
					or (info and info.secrecy and info.secrecy[auraId] == true) then
					withheld[#withheld + 1] = tostring(auraId)
				end
			end
			if not found and (unreadable or #withheld > 0) then
				say("  %s  |cff808080%s|r", show("hasBuff", false), L["withheld: %s"]:format(
					#withheld > 0 and table.concat(withheld, ", ") or L["this buff is not readable here"]))
			else
				say("  %s", show("hasBuff", true, found or false))
			end
		end
	end

	say("  %s", show("isNameplate", true, ns.nameplateUnits[unit] and true or false))

	-- The verdict on this person, and which source took it and how often it
	-- answers.
	say("  %s", show("nearEnough", true, ns.NearEnough(unit, true)))
	say("  proximity: %s", tostring(ns.ProximitySummary()))
end

-- Tokens so a test can name the current candidate without typing its name.
-- "target" stands in only when there is no candidate at all. A {unit} that
-- cannot be filled is not guessed at: this returns nil and the reason, and
-- the prompt leaves the button empty and says why. `entry` is the person the
-- macro is for when it is not the prompt's: a name in the list is armed at that
-- name (Prompt/Macro.lua), and the prompt's own (ns.lastTopEntry) stays as it was.
function ns.ExpandTokens(text, entry)
	entry = entry or ns.lastTopEntry
	local buff = entry and entry.buff or ns.ResolveBuff(true)
	local info = buff and ns.BuffInfo(buff)

	if entry and not entry.unit and text:find("{unit}", 1, true) then
		return nil, L["%s has no unit token right now, so {unit} cannot be filled"]:format(
			tostring(entry.targetName or entry.name))
	end

	text = ns.Swap(text, "{unit}", (entry and entry.unit) or "target")
	text = ns.Swap(text, "{name}", (entry and entry.name) or "target")
	-- {aim} is the spelling a targeting line wants (off Camelot, without the
	-- realm); {name} stays the identity a debt is filed under.
	text = ns.Swap(text, "{aim}", (entry and (entry.targetName or entry.name)) or "target")
	-- FirstName answers nil for a one-word name, which is then the whole name.
	text = ns.Swap(text, "{first}", entry
		and (ns.FirstName(entry.name) or entry.targetName or entry.name) or "target")
	text = ns.Swap(text, "{spell}", buff and ns.BuffName(buff))
	text = ns.Swap(text, "{id}", tostring(info and info.topRank or ""))
	return text
end

---------------------------------------------------------------------------
-- snooze
--
-- Keeping the prompt away for a while without switching the addon off. Off is
-- saved in the profile for every alt; a snooze lives in this session only, and
-- a /reload ends it. Favours are still noticed meanwhile.
--
-- The prompt is a secure frame and cannot be taken down in a fight, so a
-- snooze started in one takes effect when the fight ends: Prompt:Refresh reads
-- it below its combat branch.
---------------------------------------------------------------------------

ns.SNOOZE_CHOICES = { 5, 15, 30 }
ns.SNOOZE_DEFAULT = 15
ns.SNOOZE_MAX = 240

-- On GetTime's clock, like every other expiry here; the wall clock only
-- where the player reads the answer.
local snoozeUntil

function ns.SnoozeLeft(now)
	if not snoozeUntil then return nil end
	local left = snoozeUntil - (now or GetTime())
	if left <= 0 then return nil end
	return left
end

-- Whether the player's clock is a 12-hour one, as the game clock by the
-- minimap reads it. A client that will not answer gets the 24-hour clock.
local function TwelveHourClock()
	local get = _G.GetCVar
	if type(get) ~= "function" then return false end
	local ok, value = pcall(get, "timeMgrUseMilitaryTime")
	return ok and plain(value) == "0"
end

-- A time on a 12-hour clock as the client writes it in its own language, from
-- TIME_TWELVEHOURAM and TIME_TWELVEHOURPM, the strings Blizzard's GameTime
-- code formats the game clock's tooltip with ("%d:%02d AM", but "오전 %d:%02d"
-- in Korean, "%d:%02d a.m." in Spanish). English where the client has none.
local function TwelveHourText(hour, minute)
	local twelve = hour % 12
	if twelve == 0 then twelve = 12 end
	local late = hour >= 12
	local text = _G[late and "TIME_TWELVEHOURPM" or "TIME_TWELVEHOURAM"]
	if type(text) == "string" then
		local ok, out = pcall(text.format, text, twelve, minute)
		if ok then return out end
	end
	return ("%d:%02d %s"):format(twelve, minute, late and "PM" or "AM")
end

-- When the snooze ends, on the clock on the player's screen.
function ns.SnoozeEndsAt()
	local left = ns.SnoozeLeft()
	if not left then return nil end
	-- The minimap clock shows realm time unless the player ticked Local Time.
	local get, realm = _G.GetCVar, _G.GetGameTime
	local ok, useLocal = false, nil
	if type(get) == "function" then ok, useLocal = pcall(get, "timeMgrUseLocalTime") end
	if ok and plain(useLocal) == "0" and type(realm) == "function" then
		local read, h, m = pcall(realm)
		h, m = plain(h), plain(m)
		if read and type(h) == "number" and type(m) == "number" then
			local total = (h * 60 + m + math.floor(left / 60 + 0.5)) % 1440
			local hour, minute = math.floor(total / 60), total % 60
			if TwelveHourClock() then return TwelveHourText(hour, minute) end
			return ("%02d:%02d"):format(hour, minute)
		end
	end
	local at = time() + math.floor(left + 0.5)
	if TwelveHourClock() then
		local when = date("*t", at)
		if type(when) == "table" and type(when.hour) == "number" and type(when.min) == "number" then
			return TwelveHourText(when.hour, when.min)
		end
	end
	return date("%H:%M", at)
end

-- Translators: "1 minute" is a whole string of its own, not an "s" glued on.
function ns.MinutesText(minutes)
	if minutes == 1 then return L["1 minute"] end
	return L["%d minutes"]:format(minutes)
end

-- What every route into a snooze says (slash command, minimap, options page).
local function SaySnoozeStarted(minutes)
	local db = addon.db.profile
	if not db.enabled then
		-- Started anyway, and said so: the snooze outlives a /manners on.
		addon:Print(L["snoozed for %s, until %s -- though Manners is switched off, so no prompt appears either way."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	elseif InCombatLockdown() then
		-- Not "it goes when the fight ends": a panel the fight found up stays.
		addon:Print(L["snoozed for %s, until %s. In a fight the prompt stays as the fight found it, and follows the snooze once this one ends. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	elseif not db.prompt.locked then
		-- An unlocked prompt stays up through a snooze as something to drag.
		addon:Print(L["snoozed for %s, until %s. The prompt is unlocked, so it stays up to be dragged and casts nothing; once you lock it, it stays away until the snooze ends. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	else
		addon:Print(L["snoozed for %s -- no prompt until %s. |cffffd100/manners snooze off|r ends it early."]
			:format(ns.MinutesText(minutes), ns.SnoozeEndsAt()))
	end
end

-- The line for a snooze that has ended, however it ended, saying what the
-- prompt does next.
local function SnoozeOverText()
	local db = addon.db.profile
	if not db.enabled then
		return L["the snooze is over, but Manners is switched off -- |cffffd100/manners on|r to see the prompt again."]
	elseif InCombatLockdown() then
		return L["the snooze is over -- the prompt can appear again once this fight ends."]
	end
	return L["the snooze is over -- the prompt can appear again."]
end

-- Units a length can be typed in, as minutes each: "15", "15m", "1h".
local SNOOZE_UNITS = {
	[""] = 1, m = 1, min = 1, mins = 1, minute = 1, minutes = 1,
	h = 60, hr = 60, hrs = 60, hour = 60, hours = 60,
}

-- Minutes from what was typed after /manners snooze, or nil when it is not a
-- length. Not checked against the range: the caller says what the range is.
function ns.SnoozeLength(text)
	local number, unit = tostring(text or ""):lower():match("^%s*(%d*%.?%d+)%s*(%a*)%s*$")
	local scale = unit and SNOOZE_UNITS[unit]
	if not scale then return nil end
	local minutes = tonumber(number)
	if not minutes then return nil end
	return math.floor(minutes * scale + 0.5)
end

-- Start a snooze of `minutes`, replacing any snooze already running rather
-- than adding to it: "snooze 5" means five minutes from now.
function ns.StartSnooze(minutes)
	minutes = math.floor(tonumber(minutes) or ns.SNOOZE_DEFAULT)
	minutes = math.max(1, math.min(ns.SNOOZE_MAX, minutes))
	snoozeUntil = GetTime() + minutes * 60
	-- Refresh decides for itself what it may do in a fight, and in one it
	-- leaves the panel exactly as the fight found it.
	ns.Guard("snooze", ns.Prompt.Refresh, ns.Prompt)
	SaySnoozeStarted(minutes)
	ns.RepaintOptions()
	return minutes
end

function ns.StopSnooze(quiet)
	local was = ns.SnoozeLeft() ~= nil
	snoozeUntil = nil
	if was then
		ns.Guard("snooze", ns.Prompt.Refresh, ns.Prompt)
		ns.RepaintOptions()
	end
	if not quiet then
		addon:Print(was and SnoozeOverText() or L["not snoozed -- the prompt is free to appear."])
	end
	return was
end

-- From the scan: a snooze that has run out ends here, and says so only if the
-- player asked to be told what the addon is doing.
function ns.EndSnoozeIfDue(now)
	if not snoozeUntil or snoozeUntil > (now or GetTime()) then return end
	snoozeUntil = nil
	if addon.db.profile.verbose then addon:Print(SnoozeOverText()) end
	ns.RepaintOptions()
end

---------------------------------------------------------------------------
-- sharing settings
--
-- /manners export hands over the current profile as one line of text, and
-- /manners import (or the box on the Profiles tab) reads one back. Only
-- differences from the defaults are written.
--
-- Plain text read with string functions, never loadstring: this is text a
-- stranger pasted into a forum. Every name is looked up in a list built from
-- the defaults, every value must have its default's type, anything else is
-- refused before a setting is touched, and what survives goes through
-- ClampSettings like a saved profile at login.
--
--   MNR1:prompt.width=260;prompt.fontColor=1,0.8,0,1;buff.skip=wisdom:5f3a9c
--
-- A buff order is CLASS=key:key:key, the classes joined by commas:
-- buff.order=PALADIN=kings:might:wisdom,PRIEST=spirit:fortitude. The colons
-- inside the body are no trouble to the checksum, which is whatever follows the
-- last one.
--
-- A version, the name=value pairs, and a checksum over both, so a string cut
-- short is refused rather than half applied.
---------------------------------------------------------------------------

ns.SHARE_PREFIX = "MNR1:"
local SHARE_VERSION = 1
-- A ceiling on the work a hostile string can ask for, set well above what a
-- real profile holds (a long phrase box included), so the player's own export
-- always reads back. /manners export warns past it.
local SHARE_MAX = 64000

-- Everything below is private to this block and reached through ns, for the
-- same Lua 5.1 local limit as the friends section's.
do
	-- Never shared: the on switch is a state, not a taste; the click logger is a
	-- diagnostic; the minimap button's place is about this screen; the chat
	-- lines are a personal noise preference, like the minimap button. The
	-- Profiles tab promises a paste keeps all four. The never-offer list is
	-- real players' names, each put there by hand: not for a line handed to
	-- somebody, and kept through a paste as the page's reset keeps it. Its
	-- default is empty, so the walk never found it; named here so that is a
	-- decision rather than an accident.
	local SHARE_SKIP = { enabled = true, debugClicks = true, never = true, minimap = true, verbose = true }

	-- The same further down. The lock is a state, and a string copied while the
	-- prompt was unlocked would unlock everybody's, and an unlocked prompt never
	-- casts. Where the prompt sits is about the screen.
	local SHARE_SKIP_NAMES = {
		["prompt.locked"] = true,
		["prompt.point"] = true,
		["prompt.relPoint"] = true,
		["prompt.x"] = true,
		["prompt.y"] = true,
	}

	-- Imported only when the player already has it on: a pasted string must never
	-- switch on speaking to other players, nor the /thank everybody near sees
	-- (off by default for that reason). Each names what the import then says.
	local SHARE_KEEP_MINE = { ["speech.enabled"] = "switch", ["prompt.thankEmote"] = "thank" }

	-- What is said and where, kept as the player has it whenever speaking is on,
	-- so a paste cannot start yelling a stranger's words. With speaking off they
	-- travel, changing nothing anybody hears.
	local SHARE_SPEECH = {
		["speech.channel"] = true,
		["speech.phrases"] = true,
		["speech.presetChoice"] = true,
		["speech.onlyWhenReturning"] = true,
	}

	-- Defaults that are not a constant: the phrase box is filled from the chosen
	-- set at load.
	local SHARE_DEFAULT = {
		["speech.phrases"] = function(profile)
			local speech = profile.speech or {}
			return ns.PhraseSetText(speech.presetChoice) or ns.PhraseSetText("roleplay")
		end,
	}

	local shareFields

	-- Every setting that can be shared, walked out of the defaults table, so a
	-- new setting is shareable as soon as it has a default.
	local function ShareFields()
		if shareFields then return shareFields end
		local fields = {}
		local function walk(defs, path, prefix)
			for key, value in pairs(defs) do
				if type(key) == "string" and not (prefix == "" and SHARE_SKIP[key])
					and not SHARE_SKIP_NAMES[prefix .. key] then
					local name = prefix .. key
					local kind
					if type(value) == "table" then
						if type(value[1]) == "number" then
							kind = "colour"
						elseif name == "buff.skip" then
							kind = "set"
						elseif name == "buff.order" then
							-- The buffs of each class in an order of the player's
							-- own, kept per class. Its default is empty, so the
							-- walk below found nothing in it and the order a
							-- player set never travelled.
							kind = "order"
						elseif name == "filters.skipRaidGroups" then
							-- A set too, of group numbers rather than names. Its
							-- default is empty, so the walk below found nothing in
							-- it and the groups switched off never travelled.
							kind = "groups"
						else
							local inner = {}
							for i = 1, #path do inner[i] = path[i] end
							inner[#inner + 1] = key
							walk(value, inner, name .. ".")
						end
					elseif type(value) == "boolean" or type(value) == "number"
						or type(value) == "string" then
						kind = type(value)
					end
					if kind then
						fields[#fields + 1] = { name = name, kind = kind, path = path, key = key,
							default = value }
					end
				end
			end
		end
		walk(ns.defaults.profile, {}, "")
		-- The phrase set's dropdown has no default (nil reads as Roleplay), so the
		-- walk cannot find it.
		fields[#fields + 1] = { name = "speech.presetChoice", kind = "string",
			path = { "speech" }, key = "presetChoice" }
		table.sort(fields, function(a, b) return a.name < b.name end)
		shareFields = fields
		return fields
	end

	local function Holder(profile, path, create)
		local t = profile
		for _, seg in ipairs(path) do
			if type(t[seg]) ~= "table" then
				if not create then return nil end
				t[seg] = {}
			end
			t = t[seg]
		end
		return t
	end

	local function Finite(n)
		return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
	end

	local function NumberText(n)
		return ("%.10g"):format(n)
	end

	-- Anything but letters, digits and a little punctuation is written as %XX, and
	-- a space as +: no separator (; = : ,) or chat escape (|) survives, and with
	-- no spaces a line break a text box inserts can be stripped on the way in.
	-- A line break goes as LF alone, and no other control character goes at all:
	-- DecodeText refuses them, and a CR in the phrase box (a saved file can hold
	-- one) made the player's own export a string nothing could read.
	local function EncodeText(s)
		s = s:gsub("\r\n?", "\n"):gsub("[%z\1-\8\11-\31\127]", "")
		return (s:gsub("[^%w_%.%-!%?'%(%){}/ ]", function(c)
			return ("%%%02X"):format(c:byte())
		end):gsub(" ", "+"))
	end

	local function DecodeText(s)
		-- Every % has to open a pair of hex digits; EncodeText never writes a lone one.
		if s:gsub("%%%x%x", ""):find("%", 1, true) then return nil end
		local text = s:gsub("%+", " "):gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)
		-- A CR is a line break too: up to 1.6.1 an export wrote the phrase box's
		-- CRs as they were, and that string is still the player's own.
		text = text:gsub("\r\n?", "\n")
		-- No control characters, except a line break (one phrase per line) and a
		-- tab, which a text box takes and ExportSettings therefore writes.
		for i = 1, #text do
			local b = text:byte(i)
			if (b < 32 and b ~= 10 and b ~= 9) or b == 127 then return nil end
		end
		return text
	end

	local function ReadNumber(s)
		if not s:match("^[%d%.%-%+eE]+$") then return nil end
		local n = tonumber(s)
		if not Finite(n) then return nil end
		return n
	end

	local function DefaultOf(field, profile)
		local fn = SHARE_DEFAULT[field.name]
		if fn then return fn(profile) end
		return field.default
	end

	-- A field's value as text, or nil when it is the default and need not travel.
	local function EncodeValue(field, value, profile)
		local kind = field.kind
		if kind == "boolean" then
			if type(value) ~= "boolean" or value == field.default then return nil end
			return value and "1" or "0"
		elseif kind == "number" then
			if not Finite(value) or value == field.default then return nil end
			return NumberText(value)
		elseif kind == "string" then
			if type(value) ~= "string" or value == DefaultOf(field, profile) then return nil end
			return EncodeText(value)
		elseif kind == "colour" then
			if type(value) ~= "table" then return nil end
			local parts, same = {}, true
			for i = 1, 4 do
				local c = value[i]
				if c == nil and i == 4 then break end
				if not Finite(c) then return nil end
				parts[i] = NumberText(c)
				if c ~= field.default[i] then same = false end
			end
			if same and #parts == #field.default then return nil end
			return table.concat(parts, ",")
		elseif kind == "set" then
			if type(value) ~= "table" then return nil end
			local keys = {}
			for key, on in pairs(value) do
				if on == true and type(key) == "string" and key:match("^[%w_]+$") then
					keys[#keys + 1] = key
				end
			end
			if #keys == 0 then return nil end
			table.sort(keys)
			return table.concat(keys, ",")
		elseif kind == "order" then
			-- CLASS=key:key:key, the classes joined by commas: PRIEST=spirit:fortitude.
			-- Only keys of the plain kind buff.skip allows, a class and a key at a time.
			if type(value) ~= "table" then return nil end
			local classes = {}
			for class, keys in pairs(value) do
				if type(class) == "string" and class:match("^%u+$") and type(keys) == "table" then
					local list = {}
					for _, key in ipairs(keys) do
						if type(key) == "string" and key:match("^[%w_]+$") then list[#list + 1] = key end
					end
					if #list > 0 then classes[#classes + 1] = class .. "=" .. table.concat(list, ":") end
				end
			end
			if #classes == 0 then return nil end
			table.sort(classes)
			return table.concat(classes, ",")
		elseif kind == "groups" then
			if type(value) ~= "table" then return nil end
			local groups = {}
			for group = 1, 8 do
				if value[group] == true then groups[#groups + 1] = tostring(group) end
			end
			if #groups == 0 then return nil end
			return table.concat(groups, ",")
		end
	end

	local function DecodeValue(field, raw)
		local kind = field.kind
		if kind == "boolean" then
			if raw == "1" then return true elseif raw == "0" then return false end
			return nil
		elseif kind == "number" then
			return ReadNumber(raw)
		elseif kind == "string" then
			return DecodeText(raw)
		elseif kind == "colour" then
			local out = {}
			for part in (raw .. ","):gmatch("([^,]*),") do
				local n = ReadNumber(part)
				if not n or #out >= 4 then return nil end
				out[#out + 1] = math.max(0, math.min(1, n))
			end
			if #out < 3 then return nil end
			return out
		elseif kind == "set" then
			local out, count = {}, 0
			for part in (raw .. ","):gmatch("([^,]*),") do
				if not part:match("^[%w_]+$") then return nil end
				count = count + 1
				if count > 64 then return nil end
				out[part] = true
			end
			return out
		elseif kind == "order" then
			-- Each class once, each key of the plain kind, and what this client
			-- knows of the class made sound the way a saved order is
			-- (ns.RepairedBuffOrder); a class nothing is left of is dropped. The
			-- login's repair goes over it again with the Kings-first switch the
			-- string brings.
			local out, count = {}, 0
			for part in (raw .. ","):gmatch("([^,]*),") do
				local class, list = part:match("^(%u+)=([%w_:]+)$")
				if not class or out[class] ~= nil then return nil end
				count = count + 1
				if count > 32 then return nil end
				local keys = {}
				for key in (list .. ":"):gmatch("([^:]*):") do
					if not key:match("^[%w_]+$") or #keys >= 64 then return nil end
					keys[#keys + 1] = key
				end
				out[class] = ns.RepairedBuffOrder(class, keys, false) or false
			end
			for class, keys in pairs(out) do
				if not keys then out[class] = nil end
			end
			return out
		elseif kind == "groups" then
			-- A raid has eight groups; anything else is not one.
			local out = {}
			for part in (raw .. ","):gmatch("([^,]*),") do
				if not part:match("^[1-8]$") then return nil end
				out[tonumber(part)] = true
			end
			return out
		end
	end

	local function Checksum(text)
		local h = 0
		for i = 1, #text do h = (h * 31 + text:byte(i)) % 16777213 end
		return ("%06x"):format(h)
	end

	function ns.ExportSettings()
		local profile = addon.db and addon.db.profile
		if not profile then return nil end
		local parts = {}
		for _, field in ipairs(ShareFields()) do
			local holder = Holder(profile, field.path)
			local text = holder and EncodeValue(field, holder[field.key], profile)
			if text then parts[#parts + 1] = field.name .. "=" .. text end
		end
		local signed = ns.SHARE_PREFIX .. table.concat(parts, ";")
		return signed .. ":" .. Checksum(signed)
	end

	-- Why a string was refused, one sentence each, each one something the player
	-- can act on.
	ns.SHARE_ERRORS = {
		empty = L["there is nothing to import -- paste a settings string that starts with MNR1:."],
		notOurs = L["that is not a Manners settings string -- one starts with MNR1:."],
		tooLong = L["that is far longer than any Manners settings string, so it was not read."],
		newer = L["that string was made by a newer version of Manners -- update the addon to read it."],
		incomplete = L["that string is incomplete or has been changed -- copy it again in one piece, and paste a long one into the box under Share as text on the Profiles tab of the options."],
		malformed = L["that string is damaged -- part of it is not a setting Manners can read. Copy it again in one piece."],
		badValue = L["that string gives %s a value it cannot have, so nothing was changed."],
	}

	-- Read a settings string without touching anything. Returns the values keyed
	-- by field name and how many names this version does not know, or nil and the
	-- sentence saying why not. `cap` is the longest string it will read.
	local function Parse(text, cap)
		if type(text) ~= "string" then return nil, ns.SHARE_ERRORS.empty end
		if #text > cap * 2 then return nil, ns.SHARE_ERRORS.tooLong end
		-- No setting's text holds whitespace (a space travels as +), so any here
		-- was added on the way: a wrapped line, or blanks around a paste.
		text = text:gsub("%s+", "")
		if text == "" then return nil, ns.SHARE_ERRORS.empty end
		if #text > cap then return nil, ns.SHARE_ERRORS.tooLong end

		local version, body, sum = text:match("^MNR(%d+):(.*):(%x+)$")
		if not version then
			if text:sub(1, 3) == "MNR" then return nil, ns.SHARE_ERRORS.incomplete end
			return nil, ns.SHARE_ERRORS.notOurs
		end
		if tonumber(version) ~= SHARE_VERSION then
			if (tonumber(version) or 0) > SHARE_VERSION then return nil, ns.SHARE_ERRORS.newer end
			return nil, ns.SHARE_ERRORS.notOurs
		end
		if Checksum("MNR" .. version .. ":" .. body) ~= sum:lower() then
			return nil, ns.SHARE_ERRORS.incomplete
		end

		local byName = {}
		for _, field in ipairs(ShareFields()) do byName[field.name] = field end
		local values, unknown, count = {}, 0, 0
		if body ~= "" then
			for pair in (body .. ";"):gmatch("([^;]*);") do
				local name, raw = pair:match("^([%w_%.]+)=(.*)$")
				if not name then return nil, ns.SHARE_ERRORS.malformed end
				local field = byName[name]
				if field then
					local value = DecodeValue(field, raw)
					if value == nil then return nil, ns.SHARE_ERRORS.badValue:format(name) end
					if values[name] == nil then count = count + 1 end
					values[name] = value
				elseif SHARE_SKIP[name:match("^[^%.]*")] or SHARE_SKIP_NAMES[name] then
					-- A setting this version knows and keeps out of a paste,
					-- dropped without a word: 1.4.0 wrote verbose=0 into its
					-- strings, and calling that a newer version's setting is
					-- a sentence the player can do nothing about.
				elseif (ns.OWN_FAMILY_ANY_CLIENT or {})[name:match("^ownBuffs%.pick%.([%w_]+)$") or ""] then
					-- Another game client's own buff (an Omen of Clarity pick
					-- read on Forever): the same version made it, so nothing
					-- newer exists to send the player looking for.
				else
					-- A setting a later version added: skipped, not refused.
					unknown = unknown + 1
				end
			end
		end
		return { values = values, unknown = unknown, count = count }
	end

	-- Anything pasted or typed is read under the ceiling.
	function ns.ParseSettings(text)
		return Parse(text, SHARE_MAX)
	end

	-- The settings the last import replaced, in the shape Parse returns, for this
	-- session, and the profile they came off: its table (AceDB hands back the same
	-- table on returning to a profile) and its name, for the line that says so.
	local lastImportUndo, undoProfile, undoProfileName

	local function ProfileName()
		local db = addon.db
		if not db or type(db.GetCurrentProfile) ~= "function" then return nil end
		local ok, name = pcall(db.GetCurrentProfile, db)
		if ok and type(name) == "string" then return name end
		return nil
	end

	function ns.ForgetImportUndo()
		lastImportUndo, undoProfile, undoProfileName = nil, nil, nil
	end

	-- What a change of profile does to the undo. A switch leaves it with the
	-- profile it was made on, waiting for the player to come back. A copy or reset
	-- of that profile, or deleting it, ends it, and so does arriving at its name
	-- with a different table: the profile made again from nothing.
	function ns.ProfileChangedForUndo(event, name)
		if not lastImportUndo then return end
		local here = addon.db and addon.db.profile
		if event == "OnProfileChanged" then
			if here ~= undoProfile and undoProfileName and ProfileName() == undoProfileName then
				ns.ForgetImportUndo()
			end
		elseif event == "OnProfileDeleted" then
			if name ~= nil and name == undoProfileName then ns.ForgetImportUndo() end
		elseif here == undoProfile then
			ns.ForgetImportUndo()
		end
	end

	local function CopyValue(v)
		if type(v) ~= "table" then return v end
		local out = {}
		for k, inner in pairs(v) do out[k] = inner end
		return out
	end

	local function SameValue(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then return a == b end
		for k, v in pairs(a) do if b[k] ~= v then return false end end
		for k, v in pairs(b) do if a[k] ~= v then return false end end
		return true
	end

	-- Write a parsed string over the current profile; everything it does not name
	-- goes back to its default. `own` is the undo, the player's own settings put
	-- back exactly; anything else keeps speaking and the /thank as the player
	-- has them. Returns what was kept back.
	local function ApplySettings(profile, parsed, own)
		local speaking = profile.speech and profile.speech.enabled == true
		local kept = { switch = false, thank = false, words = false }
		for _, field in ipairs(ShareFields()) do
			local holder = Holder(profile, field.path, true)
			local value = parsed.values[field.name]
			if value == nil then value = CopyValue(field.default) end
			if not own and SHARE_KEEP_MINE[field.name] then
				if value == true and holder[field.key] ~= true then kept[SHARE_KEEP_MINE[field.name]] = true end
			elseif not own and speaking and SHARE_SPEECH[field.name] then
				-- Only what the string actually names counts as kept back.
				if parsed.values[field.name] ~= nil
					and not SameValue(parsed.values[field.name], holder[field.key]) then
					kept.words = true
				end
			else
				holder[field.key] = value
			end
		end
		-- What a profile switch runs, since every setting changed at once. Safe in
		-- a fight: ApplyStyle waits for the fight to end. It also forgets the
		-- undo, which each caller then sets as it needs.
		addon:RefreshConfig()
		return kept
	end

	-- Returns whether it applied and the line to say.
	function ns.ImportSettings(text)
		local profile = addon.db and addon.db.profile
		if not profile then return false, ns.SHARE_ERRORS.empty end
		local parsed, err = ns.ParseSettings(text)
		if not parsed then return false, err end

		-- Copied off the profile, never written out as a string to be read back
		-- later: a string that would not read (a CR from a saved file did it)
		-- was found out only at the undo, after the import had written over
		-- everything. This is the player's settings exactly, whatever they hold.
		local undo = { values = {} }
		for _, field in ipairs(ShareFields()) do
			local holder = Holder(profile, field.path)
			if holder then undo.values[field.name] = CopyValue(holder[field.key]) end
		end
		local kept = ApplySettings(profile, parsed, false)
		lastImportUndo, undoProfile, undoProfileName = undo, profile, ProfileName()

		-- Translators: whole sentences for each count, not an "s" glued on.
		local lines = {}
		if parsed.count == 0 then
			lines[1] = L["settings imported -- every one of them is the default."]
		elseif parsed.count == 1 then
			lines[1] = L["settings imported -- 1 differs from the defaults."]
		else
			lines[1] = L["settings imported -- %d differ from the defaults."]:format(parsed.count)
		end
		if parsed.unknown == 1 then
			lines[#lines + 1] = L["1 setting from a newer version of Manners was left out."]
		elseif parsed.unknown > 1 then
			lines[#lines + 1] = L["%d settings from a newer version of Manners were left out."]
				:format(parsed.unknown)
		end
		if kept.switch then
			lines[#lines + 1] = L["The string had speaking a line when you buff switched on. That is left off, because it talks to other players: switch it on under What I say if you want it."]
		end
		if kept.thank then
			lines[#lines + 1] = L["The string had /thank people who buff me switched on. That is left off, because everybody near you sees it: switch it on under What I say if you want it."]
		end
		if kept.words then
			lines[#lines + 1] = L["What you say when you buff, and where, is kept as you had it, because you have speaking switched on."]
		end
		if InCombatLockdown() then
			lines[#lines + 1] = L["The prompt's look changes when this fight ends."]
		end
		lines[#lines + 1] = L["|cffffd100/manners import undo|r puts your old settings back."]
		return true, table.concat(lines, " ")
	end

	-- Put back the settings the last import replaced, this session. Once.
	function ns.UndoImport()
		local profile = addon.db and addon.db.profile
		if not lastImportUndo or not profile then
			return false, L["nothing to undo -- no settings have been imported on this profile this session."]
		end
		-- Made on another profile: kept for when the player goes back there.
		if profile ~= undoProfile then
			if undoProfileName then
				return false, L["nothing to undo on this profile -- the last import was made on profile %s. Switch back to it to undo it."]
					:format(undoProfileName)
			end
			return false, L["nothing to undo on this profile -- the last import was made on another one. Switch back to it to undo it."]
		end
		local undo = lastImportUndo
		lastImportUndo = nil
		ApplySettings(profile, undo, true)
		if InCombatLockdown() then
			return true, L["your settings from before the import are back. The prompt's look changes when this fight ends."]
		end
		return true, L["your settings from before the import are back."]
	end
end

---------------------------------------------------------------------------
-- slash
---------------------------------------------------------------------------

-- Every command, in the order the help prints them: one list that HandleSlash,
-- the help and the scenario walking it all read, so nothing is advertised
-- without existing.
ns.COMMAND_GROUPS = {
	{ key = "everyday", title = L["Everyday"] },
	{ key = "setup", title = L["Setting it up"] },
	{ key = "share", title = L["Sharing settings"] },
	{ key = "trouble", title = L["When something is wrong"] },
}

-- Translators: `word` and `args` stay in English. The word is what
-- HandleSlash matches, and the arguments mix placeholders with keywords it
-- matches too (off, undo).
ns.COMMANDS = {
	{ word = "options", group = "everyday", help = L["open the options window"] },
	{ word = "on", group = "everyday", help = L["turn the addon on"] },
	{ word = "off", group = "everyday", help = L["turn it off"] },
	{ word = "snooze", group = "everyday", args = " [minutes|off]",
		help = L["hide the prompt for a while -- 15 minutes unless you say"] },
	{ word = "test", group = "everyday", help = L["preview the prompt with a mock candidate"] },
	-- "ledger", not "log" (still taken), which reads like the click log.
	{ word = "ledger", group = "everyday",
		help = L["the favour ledger: who buffed you, what you gave back, and who you buffed"] },
	{ word = "welcome", group = "setup",
		help = L["what this addon does, and the one thing it needs from you"] },
	{ word = "macro", group = "setup", help = L["put the macro for your action bar on your cursor"] },
	{ word = "move", group = "setup",
		help = L["move the prompt -- unlock it, drag it, and it locks itself when you let go"] },
	{ word = "unlock", group = "setup", help = L["unlock the prompt so it can be dragged"] },
	{ word = "lock", group = "setup", help = L["lock it again -- an unlocked prompt never casts"] },
	-- Both of these flip a setting that starts on, so they say "switch".
	{ word = "never", group = "everyday", args = " [name]",
		help = L["list who is never offered anything, or put somebody on that list"] },
	{ word = "allow", group = "everyday", args = " <name>",
		help = L["take somebody off the never-offer list"] },
	{ word = "restore", group = "setup", help = L["switch handing your target back after buffing on or off"] },
	{ word = "verbose", group = "setup", help = L["switch the chat lines about who buffed you on or off"] },
	{ word = "export", group = "share", help = L["copy these settings as one line of text"] },
	{ word = "import", group = "share", args = " <text|undo>",
		help = L["use settings somebody exported, or undo the last import"] },
	{ word = "debug", group = "trouble", help = L["what your class and this build allow"] },
	{ word = "errors", group = "trouble", help = L["the last few things that broke"] },
	{ word = "selftest", group = "trouble", args = " [launch]",
		help = L["check Manners against your game, and get a report to paste"] },
	{ word = "dev", group = "trouble",
		help = L["tools for testing the addon on this client: the click log, try, look and forms"] },
}

-- The in-game diagnosis for clients and classes nobody here can play, listed by
-- /manners dev rather than the help. They keep working under their own words,
-- which bug reports quote.
ns.DEV_COMMANDS = {
	{ word = "clicks", help = L["log what the button does when clicked"] },
	{ word = "try", args = " <macro>", help = L["run any macro text from the prompt"] },
	{ word = "look", args = " [unit]", help = L["dump every API answer for a unit"] },
	{ word = "forms", help = L["example macros to try"] },
}

-- Other words that reach a command. The help itself is not in COMMANDS: it is
-- what an unknown word falls through to, which is how the scenario that walks
-- the list tells a missing branch.
ns.COMMAND_ALIASES = { config = "options", help = "help", ["?"] = "help", log = "ledger",
	check = "selftest" }

-- The whole list, one line per command under its group's heading. The first
-- line is the marker a scenario looks for.
local function PrintHelp()
	addon:Print("|cffffd100" .. L["Manners commands:"] .. "|r")
	for _, group in ipairs(ns.COMMAND_GROUPS) do
		addon:Print(("|cff909098%s|r"):format(group.title))
		for _, command in ipairs(ns.COMMANDS) do
			if command.group == group.key then
				addon:Print(("  |cffffd100/manners %s%s|r  %s"):format(
					command.word, command.args or "", command.help))
			end
		end
	end
	addon:Print(L["|cffffd100/mnr|r works in place of |cffffd100/manners|r in all of them."])
end

-- How many slips of a finger turn one word into the other: a letter missed,
-- added or changed, or two neighbours swapped ("tset" is one slip from "test").
local function EditDistance(a, b)
	if a == b then return 0 end
	local rows = {}
	for i = 0, #a do rows[i] = { [0] = i } end
	for j = 0, #b do rows[0][j] = j end
	for i = 1, #a do
		for j = 1, #b do
			local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
			local best = math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a:sub(i, i) == b:sub(j - 1, j - 1)
				and a:sub(i - 1, i - 1) == b:sub(j, j) then
				best = math.min(best, rows[i - 2][j - 2] + 1)
			end
			rows[i][j] = best
		end
	end
	return rows[#a][#b]
end

-- The command somebody most likely meant by a word that is not one, or nil:
-- one slip, two in a word of six letters or more, or the start of exactly
-- one command. Never the word itself: a command that reached the fallback has
-- no branch, and saying "did you mean" would hide that.
function ns.ClosestCommand(word)
	word = tostring(word or ""):lower()
	if word == "" then return nil end
	local words = {}
	for _, command in ipairs(ns.COMMANDS) do words[#words + 1] = command.word end
	for _, command in ipairs(ns.DEV_COMMANDS) do words[#words + 1] = command.word end
	for alias in pairs(ns.COMMAND_ALIASES) do
		if alias:match("^%a+$") then words[#words + 1] = alias end
	end
	for _, candidate in ipairs(words) do
		if candidate == word then return nil end
	end
	table.sort(words)

	if #word >= 3 then
		local starts
		for _, candidate in ipairs(words) do
			if candidate:sub(1, #word) == word then
				if starts then starts = false break end
				starts = candidate
			end
		end
		if starts then return starts end
	end

	local best, bestDistance
	local allowed = #word >= 6 and 2 or 1
	for _, candidate in ipairs(words) do
		local distance = EditDistance(word, candidate)
		if distance <= allowed and (not bestDistance or distance < bestDistance) then
			best, bestDistance = candidate, distance
		end
	end
	return best
end

-- Commands that write a setting the options page has a control for, so an
-- open page is redrawn. Commands that change nothing it draws are absent;
-- `test` and `welcome` too, because the preview repaints the page itself.
-- `snooze` is here for the launcher's text; `import` repaints through
-- RefreshConfig.
local REPAINT_AFTER = {
	on = true, off = true, verbose = true, clicks = true,
	restore = true, lock = true, unlock = true, move = true, snooze = true,
	-- The never-offer list is drawn on the Who to buff tab.
	never = true, allow = true,
	-- Not a setting, but Start here says whether the macro is made, and warns
	-- in the sidebar while there is neither a key nor a macro.
	macro = true,
}

-- /manners debug's lines about somebody buffing you being noticed: the walk of
-- your own buffs, and the /thank it ends in. Said for every class, since a
-- rogue thanks too and has nothing else here to show it never came.
local function PrintFavourWatch(self, db, now)
	local scan = ns.auraScan
	if scan.doubt then
		self:Print(("  " .. L["|cffff8080own buffs: last scan not believed (%s)|r -- %d read, baseline %d"])
			:format(scan.doubt, scan.read, scan.held))
	elseif not scan.primed then
		-- Believed, but the baseline waits for two scans that agree:
		-- silence here means "waiting", not "nobody has buffed you".
		self:Print(("  " .. L["|cffffd100own buffs: baseline not settled|r -- %d read, waiting for a second scan to agree"])
			:format(scan.read))
	else
		self:Print(("  " .. L["own buffs: %d read, baseline %d"]):format(scan.read, scan.held))
	end
	-- In a fight the changes only mark a walk due (Favours.lua, UNIT_AURA), so the
	-- first number runs ahead; only walks a change asked for are counted, so the
	-- second is never the larger.
	self:Print(("    " .. L["%d changes to your auras this session, read in %d walks"])
		:format(scan.events, scan.walks))
	-- The emote is untested in game (Favours.lua), so what it last did and
	-- what it last passed over, with why, is the only report there is.
	self:Print("  " .. (db.prompt.thankEmote and L["thank with an emote: |cff00ff00on|r"]
		or L["thank with an emote: |cffff0000off|r"]))
	local thanks = ns.thankLog or {}
	if thanks.thanked then
		self:Print(("    " .. L["last thanked: |cffffffff%s|r, %ds ago (the game answered %s)"]):format(
			thanks.thanked.name, math.floor(now - thanks.thanked.at), thanks.thanked.answer))
	end
	if thanks.skipped then
		self:Print(("    " .. L["last not thanked: |cffffffff%s|r, %ds ago (%s)"]):format(
			thanks.skipped.name, math.floor(now - thanks.skipped.at), thanks.skipped.why))
	end
end

-- Every command that changes what a press does says, in a fight, that it
-- "takes effect when this fight ends; until then a press runs the macro
-- already on the button": the macro is a secure attribute, frozen for the
-- fight. Translators: the clause is written into each whole sentence; keep
-- the copies in step.

function addon:HandleSlash(rawInput)
	rawInput = (rawInput or ""):match("^%s*(.-)%s*$")

	-- The command word is matched case-insensitively; the rest is kept
	-- verbatim, since macro text is case- and punctuation-sensitive.
	local word, rest = rawInput:match("^(%S+)%s*(.*)$")
	local input = (word or ""):lower()
	rest = rest or ""
	local db = self.db.profile

	if input == "try" then
		if rest == "" then
			ns.tryMacro = nil
			ns.Prompt:InvalidateMacro()
			if InCombatLockdown() then
				self:Print(L["try cleared -- the normal cast takes effect when this fight ends; until then a press runs the macro already on the button."])
			else
				self:Print(L["try cleared -- back to the normal cast."])
			end
		else
			ns.tryMacro = rest:gsub("\\n", "\n")
			ns.Prompt:InvalidateMacro()
			ns.Say(L["try armed: |cff80ff80%s|r"], (ns.tryMacro:gsub("\n", " | ")))
			local expanded, unfilled = ns.ExpandTokens(ns.tryMacro)
			-- The same answer the button gets.
			if not expanded then
				ns.Say("  " .. L["|cffff8080not armed for now:|r %s."], unfilled)
				expanded = ""
			else
				ns.Say("  " .. L["expands to: |cffffffff%s|r"], (expanded:gsub("\n", " | ")))
			end

			-- The client truncates a macro body over the limit without a word,
			-- so the expansion (for the candidate on the prompt now) is measured.
			-- Said, not refused: this console is the only way to probe the client.
			if #expanded > ns.MACRO_LIMIT then
				ns.Say("  |cffff4040" .. L["%d characters -- %d over the %d a macro body holds. The client will cut it, and what runs is not what is printed above."]
					.. "|r", #expanded, #expanded - ns.MACRO_LIMIT, ns.MACRO_LIMIT)
			end
			-- Attributes are frozen for the fight, so a press runs the old macro.
			if InCombatLockdown() then
				self:Print(L["It takes effect when this fight ends; until then a press runs the macro already on the button. |cffffd100/manners try|r with nothing clears it."])
			elseif unfilled then
				self:Print(L["The prompt arms it once they have one. |cffffd100/manners try|r with nothing clears it."])
			else
				self:Print(L["Click the prompt to run it. |cffffd100/manners try|r with nothing clears it."])
			end
		end
		return
	elseif input == "look" then
		ns.Guard("InspectUnit", ns.InspectUnit, rest ~= "" and rest or nil)
		-- Flushed to SavedVariables at once, to be read off disk afterwards.
		ns.Guard("WriteProbe", ns.WriteProbe)
		return
	elseif input == "forms" then
		self:Print("|cffffd100" .. L["Targeting forms, for /manners try:"] .. "|r")
		self:Print("  /manners try /cast [@{unit}] {spell}")
		self:Print("  /manners try /cast [@{name}] {spell}")
		-- {aim} on the targeting line, with the command the addon itself would
		-- write on this client.
		self:Print(("  /manners try %s {aim}\\n/cast {spell}"):format(
			(ns.TargetCommand and ns.TargetCommand()) or "/target"))
		-- Translators: the examples are macro text; only the note is words.
		self:Print(("  /manners try /cast {spell}                 %s"):format(L["(on yourself)"]))
		self:Print("  /manners try /cast [@party1] {spell}")
		self:Print(L["Tokens: |cffffd100{unit} {name} {aim} {first} {spell} {id}|r. {name} is what a debt is filed under, {aim} is what a targeting line wants. Use \\n for a new line."])
		return
	end


	if input == "" or input == "config" or input == "options" then
		ns.OpenOptions()
	elseif input == "welcome" then
		-- Forced, so it plays for somebody who has already seen it.
		ns.Guard("welcome", ns.Welcome, true)
	elseif input == "ledger" or input == "log" then
		-- Plain UI with nothing secure in it, so it opens in a fight too.
		if ns.Ledger then
			ns.Guard("ledger window", ns.Ledger.Toggle)
		else
			self:Print(L["the favour ledger did not load -- reinstalling Manners should bring it back."])
		end
	elseif input == "unlock" or input == "move" then
		-- A preview over the prompt would stand where "Drag to move" goes, and
		-- the options window's button, which this is for, starts from one.
		if ns.Prompt:InTest() then ns.Prompt:ExitTest(nil, true) end
		db.prompt.locked = false
		ns.Prompt:ApplyStyle()
		-- Unlocking while off puts nothing on screen (Refresh reads `enabled`
		-- first), and the command must not quietly switch the addon on. In a
		-- fight the secure prompt cannot be moved, and chat agrees with the
		-- panel about that.
		if db.enabled and InCombatLockdown() then
			-- A fight that began with nobody on the prompt froze no macro, so a
			-- press casts nothing, as the panel and the launcher say.
			local button = ns.Prompt and ns.Prompt.GetButton and ns.Prompt:GetButton()
			local armed = button and button:GetAttribute("macrotext1")
			if type(armed) == "string" and armed ~= "" then
				self:Print(L["unlocked -- it can be dragged once this fight ends; until then a press still casts what the fight froze. Then |cffffd100/manners lock|r."])
			else
				self:Print(L["unlocked -- it can be dragged once this fight ends; nothing is armed meanwhile. Then |cffffd100/manners lock|r."])
			end
		elseif db.enabled then
			self:Print(L["unlocked -- drag the prompt, then |cffffd100/manners lock|r."])
		else
			self:Print(L["unlocked, but the addon is |cffff8080off|r so there is no prompt to drag -- |cffffd100/manners on|r first."])
		end
	elseif input == "lock" then
		db.prompt.locked = true
		ns.Prompt:ApplyStyle()
		self:Print(L["locked."])
	elseif input == "test" then
		ns.Prompt:ToggleTest()
	elseif input == "macro" then
		ns.CreateClickMacro()
	elseif input == "restore" then
		db.filters.restoreTarget = not db.filters.restoreTarget
		ns.Prompt:InvalidateMacro()
		-- Translators: one whole line per state, the on and off inside it.
		if InCombatLockdown() then
			self:Print(db.filters.restoreTarget
				and L["hand your target back after buffing: |cff00ff00on|r -- takes effect when this fight ends; until then a press runs the macro already on the button."]
				or L["hand your target back after buffing: |cffff0000off|r -- takes effect when this fight ends; until then a press runs the macro already on the button."])
		else
			self:Print(db.filters.restoreTarget
				and L["hand your target back after buffing: |cff00ff00on|r"]
				or L["hand your target back after buffing: |cffff0000off|r"])
		end
	elseif input == "clicks" then
		db.debugClicks = not db.debugClicks
		self:Print(db.debugClicks and L["click logging: |cff00ff00on|r"] or L["click logging: |cffff0000off|r"])
	elseif input == "verbose" then
		db.verbose = not db.verbose
		-- It prints to your own chat frame only, and covers more than the favour
		-- line: failed clicks and people left owed above all.
		self:Print(db.verbose
			and L["verbose: |cff00ff00on|r -- a line in your own chat when somebody buffs you, when a favour is counted as repaid, and when a click fails, is skipped, or leaves somebody owed"]
			or L["verbose: |cffff0000off|r"])
	elseif input == "on" then
		db.enabled = true
		self:Print(L["enabled."])
	elseif input == "off" then
		db.enabled = false
		ns.Prompt:Refresh()
		-- In a fight the macro on the button cannot be cleared, so a press
		-- still casts at whoever the fight froze on it until the fight ends:
		-- the same line the launcher's tooltip says.
		local button = InCombatLockdown() and ns.Prompt:GetButton()
		local armed = button and button:GetAttribute("macrotext1")
		if type(armed) == "string" and armed ~= "" then
			self:Print(L["Switched off -- the prompt this fight froze stays up until it ends, and a press still casts it."])
		else
			self:Print(L["disabled."])
		end
	elseif input == "never" then
		-- The name is `rest`, kept as typed: a surname or a realm is part of it.
		if rest == "" then
			local names = ns.NeverList()
			if #names == 0 then
				self:Print(L["nobody is on your never-offer list. Shift-right-click the prompt to put whoever it is showing on it."])
			else
				self:Print(L["never offered anything unless they buff you: %s"]
					:format(table.concat(names, ", ")))
			end
		else
			-- Typed by hand: answers to the same name with a realm on it too.
			ns.PutOnNeverList(rest, true)
		end
	elseif input == "allow" then
		if rest == "" then
			self:Print(L["say who: |cffffd100/manners allow Name|r. |cffffd100/manners never|r lists everybody on the list."])
		else
			local name = ns.AllowAgain(rest)
			if name then
				self:Print(L["|cffffffff%s|r can be offered again."]:format(name))
			else
				self:Print(L["nobody called %s is on your never-offer list."]:format(rest))
			end
		end
	elseif input == "snooze" then
		local arg = rest:lower()
		if arg == "off" or arg == "stop" or arg == "end" then
			ns.StopSnooze()
		elseif arg == "" then
			ns.StartSnooze(ns.SNOOZE_DEFAULT)
		else
			local minutes = ns.SnoozeLength(arg)
			if minutes and minutes >= 1 and minutes <= ns.SNOOZE_MAX then
				ns.StartSnooze(minutes)
			else
				self:Print(L["snooze takes a number of minutes from 1 to %d, or off -- for example |cffffd100/manners snooze 15|r or |cffffd100/manners snooze 1h|r."]
					:format(ns.SNOOZE_MAX))
			end
		end
	elseif input == "export" then
		-- Into a box, since chat text cannot be copied; printed only when there
		-- is no box.
		if ns.ShowShareBox and ns.ShowShareBox("export") then
			self:Print(L["your settings are in the box under |cffffd100Share as text|r on the Profiles tab of the options -- click in it, select all and copy."])
		else
			self:Print(tostring(ns.ExportSettings()))
		end
		-- A string longer than an import will read is handed over all the same,
		-- with a warning.
		local export = ns.ExportSettings()
		if type(export) == "string" and #export:gsub("%s+", "") > SHARE_MAX then
			self:Print(L["this string is too long to be imported back -- a very long phrase box under What I say is the usual cause. Shorten it if you want to share these settings."])
		end
	elseif input == "import" then
		if rest == "" then
			if ns.ShowShareBox and ns.ShowShareBox("import") then
				self:Print(L["paste the settings string into the box under |cffffd100Share as text|r on the Profiles tab, or type |cffffd100/manners import|r followed by it."])
			else
				self:Print(L["type |cffffd100/manners import|r followed by a settings string."])
			end
		elseif rest:lower() == "undo" then
			local _, message = ns.UndoImport()
			self:Print(message)
		else
			local _, message = ns.ImportSettings(rest)
			self:Print(message)
		end
	elseif input == "selftest" or input == "check" then
		-- Selftest.lua: every check guarded on its own, nothing touched.
		if ns.Selftest then
			ns.Guard("selftest", ns.Selftest.Command, rest)
		else
			self:Print(L["the self-test did not load -- reinstalling Manners should bring it back."])
		end
	elseif input == "dev" then
		self:Print("|cffffd100" .. L["Tools for testing Manners on this client:"] .. "|r")
		for _, command in ipairs(ns.DEV_COMMANDS) do
			self:Print(("  |cffffd100/manners %s%s|r  %s"):format(
				command.word, command.args or "", command.help))
		end
	elseif input == "errors" then
		-- Guard says each failure out loud only once; this lists the rest.
		if #ns.errors == 0 then
			self:Print(L["nothing has broken this session."])
			return
		end
		-- `#ns.errors` is how many the ring still holds (at most thirty);
		-- `ns.errorCount` how many there have ever been, which tells a bug from
		-- a handler throwing on every frame.
		local kept = #ns.errors
		local total = ns.errorCount or kept
		local from = math.max(1, kept - 4)
		-- The ring's size only once it has started dropping things.
		if total > kept then
			self:Print(L["|cffffd100the last %d of %d|r |cff808080(%d kept)|r:"]:format(kept - from + 1, total, kept))
		else
			self:Print(L["|cffffd100the last %d of %d|r:"]:format(kept - from + 1, total))
		end
		for i = from, #ns.errors do
			local e = ns.errors[i]
			self:Print(("  |cff808080%s|r %s -- |cffff8080%s|r"):format(
				tostring(e.at), tostring(e.where), tostring(e.err)))
		end
	elseif input == "debug" then
		-- The client first, above the early return below: a report is only
		-- evidence if it says which client it came from. Guarded, since this
		-- line is most needed when Flavour.lua did not load at all.
		self:Print("client: |cffffffff"
			.. (ns.FlavourSummary and ns.FlavourSummary()
				or "|cffff4040" .. L["Flavour.lua did not load -- check the toc's file list"] .. "|r")
			.. "|r")
		self:Print(("  targeting: conditional=%s @unit=%s /targetexact=%s"):format(
			tostring(caps.conditionalTargeting), tostring(caps.unitConditionals),
			tostring(caps.targetExact)))
		self:Print(("  combat log=%s (probe %s) | secret restrictions=%s"
			.. " | UnitName 2nd=%s"):format(
			tostring(caps.combatLog), tostring(caps.combatLogProbe),
			tostring(caps.secretRestrictions),
			caps.unitNameIsSurname and "surname" or "realm"))
		-- Whether the second favour source is actually running (a refused
		-- registration leaves no red line). Absent where there is no log.
		if caps.combatLog then
			self:Print(("  combat log favours: armed=%s, %d seen, %d filed"):format(
				tostring(ns.logScan.armed), ns.logScan.applied, ns.logScan.noted))
		end
		self:Print(("  buff data: |cffffffff%s|r"):format(tostring(ns.BUFFS_SOURCE)))

		-- A buff table that never arrived says so first, or the lines below
		-- read as "this class has nothing".
		if ns.BUFFS_MISSING then
			self:Print("|cffff4040" .. ns.BUFFS_MISSING .. "|r")
		end

		self:Print("class: |cffffffff" .. tostring(caps.class) .. "|r")
		if not caps.hasClassBuffs then
			self:Print(ns.NO_CLASS_BUFFS)
			-- A hunter or a shaman still has a prompt, for his own buffs.
			if (caps.anyOwnKnown or ns.OwnItemsHeld()) and not db.sources.self then
				self:Print("  " .. L["your own buff: not offered -- %s is switched off."]
					:format("|cffffd100" .. L["Myself, when I'm missing my own buff"] .. "|r"))
			end
			for _, line in ipairs(ns.MyselfLines(GetTime())) do self:Print("  " .. line) end
			PrintLeads(self)
			-- Somebody buffing you is noticed for the /thank all the same.
			PrintFavourWatch(self, db, GetTime())
			-- The one state below that holds the /thank back too, said as the
			-- full report says it, or the thank reads "on" with nothing to show.
			if not db.enabled then
				self:Print("|cffff8080" .. L["switched OFF on this profile -- nothing is recorded or offered; /manners on"] .. "|r")
			end
			return
		end
		self:Print("C_Secrets: " .. tostring(caps.hasSecrets)
			.. " | auras secret now: " .. tostring(caps.aurasSecretNow)
			.. " | nameplates: " .. tostring(caps.namePlates))
		-- What is measuring nearness, and whether it is answering: a proximity
		-- filter that has silently stopped measuring looks like an ordinary
		-- evening from the prompt.
		self:Print("  proximity: " .. tostring(ns.ProximitySummary()))
		for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
			local info = caps.buffs[buff.key]
			self:Print(string.format("  %-14s %-22s known=%s readable=%s",
				buff.key,
				tostring(info and info.name),
				info and tostring(info.known) or "?",
				info and tostring(info.readable) or "?"))
			-- An id this client does not have is a buff silently never offered;
			-- this line is the only symptom.
			if info and info.unresolved and #info.unresolved > 0 then
				self:Print(("    " .. L["|cffff4040this client has never heard of %s|r -- Manners has the wrong spell ids for %s on %s. Please report this line."]):format(
					table.concat(info.unresolved, ", "), buff.key,
					tostring(ns.BUFFS_SOURCE)))
			end
		end
		PrintLeads(self)
		-- Tells a detection bug ("never saw the buff") from a targeting one.
		local now = GetTime()
		local pending = 0
		for name, entry in pairs(owed) do
			local expires = LiveExpiry(entry)
			if expires > now then
				pending = pending + 1
				self:Print(string.format("  " .. L["owes returning: |cffffffff%s|r (%ds left, buffed you %ds ago)"],
					name, math.floor(expires - now), math.floor(now - entry.at)))
			end
		end
		-- "Nobody has buffed you" only while something is looking.
		if pending == 0 then
			if not db.enabled then
				self:Print("  " .. L["not watching for favours -- Manners is switched off."])
			elseif not db.sources.owed then
				-- With the /thank on the walk still watches, for the thank alone
				-- (Favours.lua, watching), and the thank's own lines follow.
				self:Print("  " .. (db.prompt.thankEmote
					and L["Favours are not recorded while \"People who buff me\" is off, on the Who to buff tab."]
					or L["not watching for favours -- |cffffd100People who buff me|r is switched off."]))
			else
				self:Print("  " .. L["nobody has buffed you recently."])
			end
		end
		for _, line in ipairs(ns.RequestLines()) do self:Print("  " .. line) end
		-- And yourself, so a prompt that reads "You" is explained by a switch
		-- rather than taken for the addon mistaking you for somebody else.
		if not db.sources.self then
			-- The switch by its own key, so a translation names the label
			-- the window shows.
			self:Print("  " .. L["your own buff: not offered -- %s is switched off."]
				:format("|cffffd100" .. L["Myself, when I'm missing my own buff"] .. "|r"))
		elseif #ns.SelfBuffs() > 0 then
			self:Print("  " .. L["your own buff: offered to you when you are missing it."])
		elseif #ns.KnownOwnFamilies() == 0 then
			self:Print("  " .. L["your own buff: nothing you cast goes on yourself alone."])
		end
		-- (Your class's own buffs alone -- a warlock's armor -- are said by
		-- their own lines below.)
		-- Where you are held back, and each of your class's own buffs.
		for _, line in ipairs(ns.MyselfLines(now)) do self:Print("  " .. line) end
		-- Who the game keeps refusing, since they are missing from the prompt
		-- with nothing else on screen to say why.
		for _, line in ipairs(ns.RefusalLines(now)) do self:Print("  " .. line) end

		PrintFavourWatch(self, db, now)

		-- The states that keep the prompt off screen while the queue below
		-- still counts people (BuildQueue does not read them).
		if not db.enabled then
			self:Print("|cffff8080" .. L["switched OFF on this profile -- nothing is recorded or offered; /manners on"] .. "|r")
		end
		if not db.prompt.locked then
			self:Print("|cffff8080" .. L["prompt is UNLOCKED -- it will not buff anyone until you /manners lock"] .. "|r")
		end
		if ns.SnoozeLeft() then
			self:Print(L["|cffffd100snoozed until %s|r -- no prompt until then; /manners snooze off ends it"]
				:format(ns.SnoozeEndsAt()))
		end
		if ns.HiddenWhileMounted() then
			self:Print(L["|cffffd100mounted|r -- \"Hide the prompt while I'm mounted\" keeps it away until you get off"])
		end
		-- The queue below leaves out everybody nobody asked for while this
		-- holds, which looks like a broken queue unless it is said.
		local _, resume = ns.SavingMana()
		if resume then
			-- Your own buff is kept too (Queue.lua, SelfEntry), where "Myself"
			-- is on, and a line leaving it out would contradict the queue.
			self:Print((ns.OffersSelf()
				and L["|cffffd100saving mana|r -- until you are back to %d%% mana, only your own buff and people who buffed you or asked are offered"]
				or L["|cffffd100saving mana|r -- until you are back to %d%% mana, only people who buffed you or asked are offered"])
				:format(resume))
		end
		if ns.ReadyCheckRunning() then
			self:Print(L["|cffffd100ready check|r -- your party or raid comes first until the pull"])
		end
		-- Always, not only in a raid: groups unticked for last week's
		-- assignment are what leaves somebody out next week with no sign why,
		-- and this is where to check before the raid.
		local groups = ns.BuffedRaidGroups()
		if groups then
			self:Print(L["|cffffd100raid groups|r -- in a raid, only groups %s are offered unasked"]:format(groups))
		elseif groups == false then
			self:Print(L["|cffffd100raid groups|r -- every group is unticked, so in a raid nobody is offered unasked"])
		end
		self:Print(("  build |cffffffff%s|r"):format(tostring(ns.BUILD)))
		if ns.tryMacro then
			self:Print(("  " .. L["|cffff8080/manners try is armed:|r %s -- clear it with a bare /manners try"]):format(
				(ns.tryMacro:gsub("%s+", " "))))
		end
		self:Print((db.enabled and L["queue now: %d"] or L["queue if switched on: %d"]):format(#ns.BuildQueue()))
		-- Who that scan held back for PvP: missing from the prompt with
		-- nothing on screen to say why.
		for _, line in ipairs(ns.PvPLines()) do self:Print("  " .. line) end
		ns.Guard("WriteProbe", ns.WriteProbe)
	else
		-- A word that is nearly a command gets that command named. Anything
		-- else, help included, gets the whole list, whose header is the marker
		-- the scenario looks for.
		local closest = ns.COMMAND_ALIASES[input] == nil and ns.ClosestCommand(input)
		if closest then
			-- The help leaves the developer tools out, so a guess that is one
			-- of them points at the list that does have it.
			local line = L["there is no |cffffd100/manners %s|r -- did you mean |cffffd100/manners %s|r? |cffffd100/manners help|r lists them all."]
			for _, command in ipairs(ns.DEV_COMMANDS) do
				if command.word == closest then
					line = L["there is no |cffffd100/manners %s|r -- did you mean |cffffd100/manners %s|r? |cffffd100/manners dev|r lists the testing tools."]
				end
			end
			-- Doubled, so a typed | is shown, not read as a colour code.
			self:Print(line:format((input:gsub("|", "||")), closest))
		else
			PrintHelp()
		end
	end

	-- After the chain rather than inside each branch.
	if REPAINT_AFTER[input] then ns.RepaintOptions() end
end
