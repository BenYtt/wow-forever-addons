-- Manners -- what the prompt's button casts, and at whom: the macro built for
-- the person on the panel, and the plain-English account of it the tooltip
-- gives.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown

-- Every button but the left gets a type the secure handler does not recognise,
-- so it does nothing; otherwise the unsuffixed type/macrotext (the form that
-- works on this client) fires for every button, a right-press included.
-- The client looks an attribute up as prefix..name..suffix, "*"..name..suffix,
-- ... and the bare name last (warcraft.wiki.gg, API_Frame_GetAttribute), the
-- prefix being "shift-", "ctrl-", "alt-" or their mix while those keys are down
-- (SecureButton_GetModifierPrefix). A plain "type2" is the unmodified right
-- button alone: shift-right-click skips it and falls to the bare type, the
-- macro. "*type<N>" is any modifier, as Blizzard's own SecureUnitButton_OnLoad
-- sets "*type2"; N runs to 31, the last button the template names
-- (BUTTON_LOOKUP_TABLE), and "AnyDown" answers every one. No "*type1": the left
-- button with a modifier held, or from a key binding, is meant to cast.
local function SilenceOtherButtons(R)
	for index = 2, 31 do
		if index <= 5 then R.button:SetAttribute("type" .. index, "none") end
		R.button:SetAttribute("*type" .. index, "none")
	end
end

-- Which targeting command to write. Not /targetexact, though it would stop
-- "/target Mort" finding Mortimer: the name is built from UnitName's two
-- returns, whose second is undocumented here for other realms, and one
-- character out finds nobody. caps.targetExact (/manners debug) is the probe
-- for switching.
local function TargetCommand()
	return "/target"
end
-- Published so the options page can name the command the macro really uses
-- rather than a second, hand-maintained opinion about it.
ns.TargetCommand = TargetCommand

-- Whether the client says plainly that nothing is targeted: no GUID for the
-- target token, which is nil without a unit. A secret answer is not a no.
local function NoTarget()
	local guid = _G.UnitGUID
	if type(guid) ~= "function" then return false end
	local raw = guid("target")
	local secret = _G.issecretvalue
	if type(secret) == "function" and secret(raw) then return false end
	return raw == nil
end

-- The line that gives the player's target back. With nothing targeted when the
-- macro is armed there is nothing to hand back, and /targetlasttarget would
-- bring back whatever was targeted before that (a mob cleared minutes ago), so
-- the target is cleared instead. The macro armed for a fight keeps
-- /targetlasttarget: it runs at every press of the fight, whatever is targeted
-- by then, and a cleared target would take the one the player has picked.
local function HandBack()
	if Prompt.armedForFight ~= true and NoTarget() then return "/cleartarget" end
	return "/targetlasttarget"
end

-- The shape of the macro for this person. There is deliberately one targeting
-- strategy: /cast [@Name] works only for group members, cannot be tested here
-- and fails silently (a retail 12.0 restriction), and [@nameplateN] resolves
-- nowhere. Targeting reaches ungrouped strangers everywhere.
local function StrategyFor(entry)
	if entry.reason == "self" then
		if entry.buff and entry.buff.item then return "scroll" end
		return "self"
	end
	if entry.buff and entry.buff.selfCast then return "selfcast" end
	return "target"
end

-- Each returns the lines, whether the hand-back (HandBack) goes on the end, and a
-- record the settle path judges the press by:
--
--   targeted  the macro carries a targeting line of ours, aimed at this person
--   selfCast  the spell lands on the caster and reaches the party from there
--   onSelf    the spell is for the caster alone: your own buff
--   aimedAt   the exact spelling that went onto the targeting line
local STRATEGIES = {}

-- Whether this entry was reached through the target token and is still the
-- player's target at this moment -- or is your own buff, with yourself
-- targeted. The strategy and the macro's key ask it the same way, so a change
-- of target rebuilds the macro.
local function StillTargeted(entry)
	return (entry.unit == "target" or entry.reason == "self") and entry.name ~= nil
		and ns.UnitFullName ~= nil and ns.UnitFullName("target") == entry.name
end

-- No targeting line: the spell lands on you and reaches the party from there.
-- The record says so, which is what lets the settle path judge the press.
STRATEGIES.selfcast = function(entry, spell)
	return { "/cast " .. spell }, false,
		{ targeted = false, selfCast = true, aimedAt = nil }
end

-- Your own buff: you are targeted by name, the spell cast, and your target
-- handed back -- the shape every other press takes, because it is the one
-- shape known to work on WoW Forever. Not [@player]: conditional targeting
-- does not resolve on that client at all ([@unit], [@focus], [@mouseover] and
-- the secure unit attribute all fail -- the README's client notes), and
-- nobody has cast [@player] there. Not a bare /cast either: with a friendly
-- player targeted it lands on them. No spoken line: there is nobody to say it
-- to (ns.PickPhrase). The record stays one on yourself, which is how the press
-- is settled (Clicks.lua).
--
-- Your target is handed back whatever "Hand my target back" says: that switch
-- is about other people, and this press takes your target only because the
-- client can cast on you no other way -- a hunter's aspect dropped the mob
-- he had targeted. Not when you are your own target already, where
-- /targetlasttarget would switch away; in a fight it stays, as for anybody
-- (STRATEGIES.target).
STRATEGIES.self = function(entry, spell)
	local lines = STRATEGIES.target(entry, spell)
	local restore = not StillTargeted(entry) or Prompt.armedForFight == true
	return lines, restore,
		{ targeted = true, selfCast = false, onSelf = true, aimedAt = entry.targetName or entry.name }
end

-- A mage's scroll from the bags (Buffs.lua): used by its item id, with no
-- name to spell and nobody to target, so your target is never touched. A
-- familiar is summoned on you. An imbue is aimed at an item, as an oil or a
-- poison is (Targets 16 in the client's SpellTargetRestrictions): the use
-- alone left the cursor waiting for a weapon and cast nothing, and the next
-- use aimed the waiting imbue at the scroll ("That item is not a valid
-- target", 1.6.2 and 1.6.3). /use 16 hands it the main-hand weapon in the
-- same press. The record is one on yourself, settled by the spell the use
-- casts (Clicks.lua, SettleSelf).
--
-- A weapon enhancement (a poison, a stone, an oil, a lure) is the same press
-- for the hand its family is for: /use 16 for the main hand, /use 17 for the
-- off hand. The slot line goes in only for an item that is aimed at a weapon
-- (`enchant`): a bare /use of a slot would use the weapon's own on-use effect
-- when the first line left nothing waiting. Over an enhancement already on
-- the weapon the game asks whether to replace it: that question is the
-- player's to answer, and Manners never answers it.
STRATEGIES.scroll = function(entry)
	local lines = { "/use item:" .. tostring(entry.buff.item) }
	local family = entry.buff.family
	local slot = family and family.slot or 16
	if entry.buff.enchant then lines[2] = "/use " .. slot end
	return lines, false,
		{ targeted = false, selfCast = false, onSelf = true, aimedAt = nil }
end

-- Target them, cast, and optionally hand the player's own target back. One
-- targeting line with one spelling: with two, /targetlasttarget hands back
-- what the first found, not the player's target. The account is in Clicks.lua.
STRATEGIES.target = function(entry, spell)
	-- targetName is the spelling, entry.name the identity; they differ only for
	-- a cross-realm player off Camelot. The fallback covers made-up entries
	-- (the preview, the phrase roller).
	local who = entry.targetName or entry.name or ""
	-- No hand-back for somebody reached through the target token who is still
	-- your target: /targetlasttarget would switch away (often to a mob). The
	-- token alone is not enough: a held or fused entry keeps "target" after you
	-- have picked somebody else, who is then the one to hand back.
	-- In a fight the macro armed at the pull runs every press, so it keeps it.
	local restore = ns.db.profile.filters.restoreTarget == true
		and (not StillTargeted(entry) or Prompt.armedForFight == true)
	return {
		TargetCommand() .. " " .. who,
		"/cast " .. spell,
	}, restore,
		{ targeted = true, selfCast = false, aimedAt = who }
end

-- The cast half of the macro, as a list, so the room left for a spoken line can
-- be measured.
local function CastLines(entry)
	-- A group cast is the same /target and /cast, with the group spell.
	return STRATEGIES[StrategyFor(entry)](entry, ns.EntrySpellName(entry))
end

-- How many characters a spoken line has left for this person. Asked by the
-- cast path and the options preview, so the two cannot disagree.
function ns.PhraseBudget(entry)
	local lines, restore = CastLines(entry)
	-- The newline the spoken line itself would add, and the restore that
	-- follows it with a newline of its own.
	local used = #table.concat(lines, "\n") + 1
	if restore then used = used + #HandBack() + 1 end
	return ns.MACRO_LIMIT - used
end

-- What the button will do, said the way a person would say it, quoting the
-- settled spoken line (see phraseKey in ApplyTarget). Asked by the tooltip
-- (Button.lua).
function Prompt:ClickSummary(entry, slot)
	-- Whose settled roll it quotes: the prompt's, or a list row's slot, which
	-- holds none while it is at rest.
	local S = slot or S
	local out = {}
	if not (entry and entry.buff) then return out end
	local spell = ns.EntrySpellName(entry)
	-- No name at all is rare, and gets sentences of its own: "them" takes a
	-- different form in each position in plenty of languages.
	local who = entry.short or entry.name

	-- /manners try replaces the whole macro with whatever was typed, and none
	-- of the sentences below are true of it.
	if ns.tryMacro then
		-- Asked the same question the button was, so this cannot promise a run
		-- the button was left empty for.
		local text, unfilled = ns.ExpandTokens(ns.tryMacro, entry)
		if not text then
			out[#out + 1] = L["|cffffcc66Does nothing:|r %s."]:format(unfilled)
			return out
		end
		out[#out + 1] = who
			and L["Runs your |cffffd100/manners try|r macro against |cffffffff%s|r."]:format(who)
			or L["Runs your |cffffd100/manners try|r macro against |cffffffffthem|r."]
		return out
	end

	if entry.reason == "self" and entry.buff.item then
		-- A scroll: used from the bags, nobody targeted (STRATEGIES.scroll).
		out[#out + 1] = L["Uses |cffffffff%s|r from your bags."]:format(spell)
	elseif entry.reason == "self" then
		-- Nothing about targets: the macro hands your target back (see
		-- STRATEGIES.self), whatever the switch for other people says.
		out[#out + 1] = L["Casts |cffffffff%s|r on you."]:format(spell)
	elseif entry.buff.selfCast then
		out[#out + 1] = L["Casts |cffffffff%s|r on you; it reaches your party from there."]
			:format(spell)
	else
		-- The spelling the targeting line will carry, which differs from the
		-- filed or shortened name for a cross-realm player off Camelot.
		local target = entry.targetName or entry.name or who
		local group = entry.groupCast
		if group and target then
			-- Who the one cast reaches besides the person it is aimed at.
			out[#out + 1] = group.class
				and L["Targets |cffffffff%s|r, casts |cffffffff%s|r on %s in your party or raid."]:format(target, spell, group.label or "?")
				or L["Targets |cffffffff%s|r, casts |cffffffff%s|r on everybody in %s."]:format(target, spell, group.label or "?")
		else
			out[#out + 1] = target
				and L["Targets |cffffffff%s|r, casts |cffffffff%s|r."]:format(target, spell)
				or L["Targets |cffffffffthem|r, casts |cffffffff%s|r."]:format(spell)
		end
		-- What the strategy decided, not the setting it started from: the two
		-- differ for your own target, whose macro hands nothing back.
		local _, restore = CastLines(entry)
		if restore then
			out[#out + 1] = L["Hands your own target back afterwards."]
		elseif ns.db.profile.filters.restoreTarget then
			out[#out + 1] = L["They are already your target, so they stay targeted."]
		else
			out[#out + 1] = L["|cffffcc66Leaves them targeted|r -- your own target is not restored."]
		end
	end

	if S.phraseText and S.phraseArmed then
		-- Quoted without its slash command (or a whisper's name): the channel is
		-- a setting, and what it says is the part worth reading.
		out[#out + 1] = L["Says: |cffffffff%s|r"]:format(ns.SpokenText(S.phraseText))
	end
	return out
end

-- Who the spoken line is to: the entry, or for a group cast aimed at somebody
-- owed nothing, the first member it repays (GroupBuffs.lua, groupCast.owed),
-- as a copy of the cast's entry wearing that member's name, token and class
-- and the reason "owed". A ready check sweeps the party to one priority, and
-- whether a favour was thanked came down to whose name came first; with
-- "Only when I buff someone back" on, the cast repaid it in silence.
function ns.LineSpeaker(entry)
	local group = entry and entry.groupCast
	local member = group and entry.reason ~= "owed" and group.owed and group.owed[1]
	if not member then return entry end
	local speaker = {}
	for field, value in pairs(entry) do speaker[field] = value end
	speaker.name, speaker.short, speaker.unit = member.name, member.short, member.unit
	speaker.targetName, speaker.class = member.targetName, member.class
	speaker.reason = "owed"
	return speaker
end

-- One line per person per exchange: after a line has gone to somebody, the
-- next minute's buffs on them go out silent -- a priest's Fortitude, Spirit
-- and Shadow Protection said "Cheers" three times in six seconds. A
-- thank-you for a favour is never held back. Stamped by the press that
-- carried the line (Press.lua, OnPostClick); capped as ns.lastGave is.
local LINE_REST = 60
local spokeAt, spokeCount = {}, 0

function ns.NoteLineSaid(name, now)
	if type(name) ~= "string" then return end
	if not spokeAt[name] then
		spokeCount = spokeCount + 1
		if spokeCount > 400 then
			wipe(spokeAt)
			spokeCount = 1
		end
	end
	spokeAt[name] = now
end

function ns.LineRested(entry, now)
	if entry.reason == "owed" then return true end
	local at = spokeAt[entry.name]
	return not (at and now - at < LINE_REST)
end

-- Arms a button at `entry` and keeps what it was built from, `S`. The prompt's
-- own (Prompt:ApplyTarget) and a list row's (Prompt/Rows.lua) are armed by this
-- one routine, so the macro a click on a name casts is the macro a press on the
-- prompt would have cast, and nothing about it is written twice. `R` and `S`
-- here are not the file's: `R` holds the `button` to arm and `S` the fields the
-- press is judged by (current, appliedKey, armed, the spoken line) -- the
-- prompt's regions and state, or a row's slot, which is both at once, with
-- `isRow` set. They carry the file's names on purpose, so every line below
-- reads as it always did.
--
-- `silent` leaves the spoken line out whatever the entry says: PreClick's
-- last-moment judgement (HoldLine), or a repaint arming somebody the latest
-- scan no longer offers.
local function Arm(R, S, entry, silent)
	S.current = entry

	if not entry or not entry.buff or S.testMode then
		-- Unconditionally: PreClick nils appliedKey just before calling here,
		-- so a guard on it never ran on a click and left the last person's
		-- macro armed.
		for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
			"type", "macrotext", "spell", "unit",
			"type2", "type3", "type4", "type5" }) do
			R.button:SetAttribute(attribute, nil)
		end
		S.appliedKey = nil
		-- Nothing on the button, so nothing for a settle to be judged against.
		S.armed = nil
		-- Same reasoning for the spoken line: there is no macro, so there is no
		-- line, and the tooltip must not still be quoting the last one.
		S.phraseKey, S.phraseText, S.phraseArmed, S.phraseSource = nil, nil, nil, nil
		-- Nor anything for the bar macro to carry (Clicks.lua, click macro).
		S.barText = nil
		-- The macro's slot on an action bar shows nothing for nobody
		-- (Clicks.lua, SyncMacroSlot): a comparison of one string once it does.
		if not S.isRow then ns.SyncMacroSlot(nil) end
		return
	end

	-- The console expands {unit}/{name}/{spell} against whoever is offered;
	-- above the early return, because the unit can change while the macro does
	-- not.
	if not S.isRow then
		ns.lastTopEntry = entry
		ns.lastTopUnit = entry.unit
	end

	-- Whether a spoken line may go in. Only for somebody the scan measured in
	-- reach: the macro runs on past a /cast that fails, and the line went out
	-- over a buff that never landed (beta.8). A reading nobody could take --
	-- no token, a client that will not say, a secret -- is a no: "if I can't
	-- buff someone, I should not say anything". Nor for a reading the latest
	-- scan overruled: the repaint arms the hold's copy and the fuse's entry
	-- `silent` (Refresh.lua). The press judges it all again (Press.lua,
	-- HoldLine), and this keeps the tooltip from quoting a line the press
	-- would leave out. Nor for a while after the game refused a cast on them
	-- (ns.SpeechHeld), so pressing at somebody it will not let you reach does
	-- not keep talking. Nor in /party or /raid while you are in no party or
	-- raid, or to somebody outside it (ns.ChannelOpen, asked of the member the
	-- line thanks): the line would reach nobody, on every press, or nobody it
	-- was for. In
	-- the key below, so a group joined or left re-arms the macro on the next
	-- repaint. Nor in the macro armed for a fight: every press in it runs that
	-- one frozen text, so the line went out again on a press the cooldown
	-- turned away and after the favour was repaid. As /thank, never in a
	-- fight; the repaint after it puts the line back. Nor for a shout at
	-- somebody not surely inside its own radius (ns.ShoutSure): the scan's
	-- reach for a shout is looser on purpose, and the press asks the same. Nor
	-- for somebody a line went to in the last minute (ns.LineRested), unless
	-- it thanks them for a favour; `speak` is in the key, so the line comes
	-- back once the minute is up.
	local speaker = ns.LineSpeaker(entry)
	local speak = not silent and entry.ranged == true and not ns.SpeechHeld(entry.name)
		and ns.ChannelOpen(speaker)
		and Prompt.armedForFight ~= true
		and not (entry.buff.selfCast and ns.ShoutSure(entry.unit) ~= true)
		and ns.LineRested(speaker, GetTime())

	-- Everything the macro is built from, so it is not rebuilt at 2.5 Hz. Other
	-- inputs come through InvalidateMacro; the unit is here for try's {unit},
	-- armedForFight and who is targeted for the hand-back, and whether the line
	-- is armed so a change of range or a refusal re-arms it (out of combat).
	-- The group spell too: the same person moves between a single cast and
	-- their party's group cast as the others come and go. And the name the
	-- macro casts by, which the key alone does not pin down: the trainer that
	-- teaches Ice Armor renames the Frost Armor line (Core.lua, ProbeBuff)
	-- under an entry that has not moved, and a key without it kept "/cast
	-- Frost Armor" armed for as long as that entry stayed up.
	local key = table.concat({ entry.name, tostring(entry.unit), entry.buff.key,
		ns.EntrySpellName(entry),
		tostring(entry.groupCast and entry.groupCast.spell),
		tostring(entry.reason), tostring(ns.tryMacro), tostring(Prompt.armedForFight), tostring(NoTarget()),
		tostring(StillTargeted(entry)), tostring(speak) }, "\1")
	if key == S.appliedKey then return end

	-- /manners try: arbitrary macro text, expanded against the candidate, so
	-- testing on this client is one guess per click rather than per /reload.
	if ns.tryMacro then
		local text, unfilled = ns.ExpandTokens(ns.tryMacro, entry)
		if not text then
			-- A template asking for a unit token this person lacks: nothing
			-- goes on the button rather than a guess ("target" would cast at
			-- whoever is targeted). The key carries the unit, so a later
			-- repaint through a token arms it.
			for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
				"type", "macrotext", "spell", "unit" }) do
				R.button:SetAttribute(attribute, nil)
			end
			if not S.isRow then ns.lastMacro = "[try, not armed] " .. tostring(unfilled) end
			if not S.isRow then ns.SyncMacroSlot(nil) end
			S.appliedKey = key
			S.armed = nil
			-- The bar macro never carries a try macro.
			S.barText = nil
			return
		end
		R.button:SetAttribute("type1", "macro")
		R.button:SetAttribute("macrotext1", text)
		R.button:SetAttribute("type", "macro")
		R.button:SetAttribute("macrotext", text)
		SilenceOtherButtons(R)
		if not S.isRow then ns.lastMacro = "[try] " .. text end
		if not S.isRow then ns.SyncMacroSlot(nil) end
		S.appliedKey = key
		-- None of this text is a /target this addon wrote, so it is evidence
		-- about nobody's name and there is no record for the settle path.
		S.armed = nil
		S.barText = nil
		return
	end

	local lines, restore, record = CastLines(entry)
	-- How many of them are the cast's, for the bar macro's copy below.
	local castCount = #lines

	-- Rolled once per candidate (who, buff, why), so the tooltip quotes the
	-- line the press will cast; InvalidateMacro clears it, PreClick does not. A
	-- kept line that no longer fits the room is rolled again, or the client
	-- would cut the hand-back off the macro.
	-- The group spell too, as in the macro's key: the line names the spell, and
	-- one kept from a single cast would name the wrong one under a group cast.
	local phraseIdentity = table.concat({ entry.name, entry.buff.key, tostring(entry.reason),
		tostring(entry.groupCast and entry.groupCast.spell), tostring(ns.tryMacro), speaker.name }, "\1")
	local budget = ns.PhraseBudget(entry)
	-- Rolled only for an arming that can say it, and kept through an arming
	-- that leaves it out (out of reach for a moment, a press that cannot
	-- land), so the roll the tooltip quoted is the one said once the line is
	-- armed again. "In character" hands back the line as written too
	-- (phraseSource), and counts it as said lately only when a press carries
	-- it (Press.lua, OnPostClick).
	if speak and (S.phraseKey ~= phraseIdentity or (S.phraseText and #S.phraseText > budget)) then
		S.phraseKey, S.phraseText, S.phraseSource = phraseIdentity, ns.PickPhrase(speaker, budget)
	end
	local phrase = speak and S.phraseText or nil
	S.phraseArmed = phrase ~= nil
	if phrase then lines[#lines + 1] = phrase end

	-- Last, always: it is what hands your target back, and the client reads the
	-- macro top to bottom.
	if restore then lines[#lines + 1] = HandBack() end

	local macro = table.concat(lines, "\n")

	-- What the bar macro carries under its first line (Clicks.lua, click
	-- macro): the cast and the hand-back, never the spoken line. A bar press
	-- runs lines written before it, with no PreClick to judge the line at the
	-- last moment as the prompt's press does (Press.lua, HoldLine: a druid in
	-- a form that cannot cast, somebody dead or gone since the scan), and a
	-- line said over a cast that fails cannot be taken back. In a real macro's
	-- 255 characters, beside the bar line.
	if not S.isRow then
		local quiet = {}
		for i = 1, castCount do quiet[i] = lines[i] end
		if restore then quiet[#quiet + 1] = lines[#lines] end
		local barText = table.concat(quiet, "\n")
		if #ns.BAR_LINE + 1 + #barText > ns.MACRO_LIMIT then barText = nil end
		S.barText = barText
	end

	R.button:SetAttribute("type1", "macro")
	R.button:SetAttribute("macrotext1", macro)
	R.button:SetAttribute("type", "macro")
	R.button:SetAttribute("macrotext", macro)
	SilenceOtherButtons(R)

	if not S.isRow then ns.lastMacro = macro end
	-- What a press now casts is what the macro's bar slot shows, set only when
	-- it differs from what it showed (and never in a fight, where this is not
	-- reached: ApplyTarget returns first).
	if not S.isRow then ns.SyncMacroSlot(entry) end
	S.appliedKey = key
	-- Taken whole from the strategy that built the macro: one opinion about it.
	S.armed = record
end

-- A list row silences itself the same way when it is made (Rows.lua).
lib.SilenceOtherButtons = SilenceOtherButtons

-- The prompt's: armed or disarmed for the person it is on.
function Prompt:ApplyTarget(entry, silent)
	if InCombatLockdown() then
		-- Frozen until the fight ends. `current` may only be cleared: a disarm
		-- must take effect, and pointing it at somebody new would file
		-- bookkeeping under a name the macro does not hold. appliedKey stays:
		-- it says what is on the button, which the fight froze, and the
		-- unconditional clear path below disarms it after the fight. Who the
		-- macro names is kept (frozenEntry) for a repaint in this fight to put
		-- back once the prompt is live again.
		if not entry then
			S.frozenEntry = S.frozenEntry or S.current
			S.current = nil
		end
		return
	end

	-- Out of combat the button is armed or disarmed for real.
	S.frozenEntry = nil
	Arm(R, S, entry, silent)
	-- The bar macro follows the button (Clicks.lua, click macro).
	ns.SyncMacroBody(true)
end

-- A list row's: the same macro on its own button, out of combat only (the
-- caller's rule, Prompt/Rows.lua).
function Prompt:ArmRow(row, entry, silent)
	return Arm(row, row, entry, silent)
end

function Prompt:InvalidateMacro()
	S.appliedKey = nil
	-- The settled roll goes with the macro. PreClick clears appliedKey on its
	-- own instead, so a press re-resolves who without re-rolling what is said.
	S.phraseKey, S.phraseText, S.phraseSource = nil, nil, nil
end
