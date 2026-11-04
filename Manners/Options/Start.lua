-- Manners -- options: the Start here tab.

local ADDON, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local P, S, F, SP, PR = Page.P, Page.S, Page.F, Page.SP, Page.PR
local HasClassBuffs, HasPrompt, OffersSelf, TAB = Page.HasClassBuffs, Page.HasPrompt, Page.OffersSelf, Page.TAB
local Ref, HasMinimapButton, CompartmentShown, DragPanelUp = Page.Ref, Page.HasMinimapButton, Page.CompartmentShown, Page.DragPanelUp

local LDBIcon = LibStub("LibDBIcon-1.0", true)

---------------------------------------------------------------------------
-- Setup: the key, the macro and the game's key bindings window
---------------------------------------------------------------------------

local Setup = {}
ns.Setup = Setup

-- The binding Bindings.xml declares: a click on the prompt's secure button.
Setup.COMMAND = "CLICK MannersPrompt:LeftButton"

function Setup.CanBind()
	return type(GetBindingKey) == "function" and type(SetBinding) == "function"
		and type(SaveBindings) == "function"
end

-- Every key on the command, in the order the game lists them.
function Setup.Keys()
	if type(GetBindingKey) ~= "function" then return {} end
	local ok, keys = pcall(function() return { GetBindingKey(Setup.COMMAND) } end)
	if not ok or type(keys) ~= "table" then return {} end
	local out = {}
	for _, key in ipairs(keys) do
		if type(key) == "string" and key ~= "" then out[#out + 1] = key end
	end
	return out
end

-- The first key that buffs the prompted player, or nil.
function Setup.Key()
	return Setup.Keys()[1]
end

-- Put the command on one key, or on none for "" or nil. Key bindings are the
-- game's, saved with its binding set rather than in the profile, so this works
-- on every profile. SetBinding is refused in combat, so nothing happens there;
-- the control that calls this is greyed out in combat anyway.
function Setup.SetKey(key)
	if InCombatLockdown() or not Setup.CanBind() then return false end
	return ns.Guard("key binding", function()
		for _, old in ipairs(Setup.Keys()) do SetBinding(old) end
		if type(key) == "string" and key ~= "" then
			local was = type(GetBindingAction) == "function" and GetBindingAction(key) or ""
			if type(was) == "string" and was ~= "" and was ~= Setup.COMMAND then
				ns.addon:Print(L["%s was bound to %s; it now buffs the prompted player."]
					:format(key, tostring(_G["BINDING_NAME_" .. was] or was)))
			end
			SetBinding(key, Setup.COMMAND)
		end
		SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
		ns.RefreshOptionsDisplay()
	end)
end

-- Unverified on the Camelot client: whether Settings.KEYBINDINGS_CATEGORY_ID
-- exists there. Without either route the button hides itself, and the key
-- control on Start here still does the job.
function Setup.CanOpenBindings()
	if type(Settings) == "table" and type(Settings.OpenToCategory) == "function"
		and Settings.KEYBINDINGS_CATEGORY_ID ~= nil then
		return true
	end
	return type(KeyBindingFrame_LoadUI) == "function"
end

-- The game's key bindings, where Manners has a section of its own. The
-- standalone options window is shut first: it sits above the Settings window,
-- as it does above the ledger. Refused in combat. Answers whether it opened.
function Setup.OpenBindings()
	if InCombatLockdown() then return false end
	ns.CloseOptions()
	if type(Settings) == "table" and type(Settings.OpenToCategory) == "function"
		and Settings.KEYBINDINGS_CATEGORY_ID ~= nil
		and pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID) then
		return true
	end
	if type(KeyBindingFrame_LoadUI) == "function" then
		return (pcall(function()
			KeyBindingFrame_LoadUI()
			ShowUIPanel(KeyBindingFrame)
		end))
	end
	return false
end

-- Where the macro Put Manners on an action bar writes is, or nil.
local function MacroIndex()
	if type(GetMacroIndexByName) ~= "function" then return nil end
	local ok, index = pcall(GetMacroIndexByName, ns.CLICK_MACRO_NAME or "Manners")
	if ok and type(index) == "number" and index > 0 then return index end
end

-- Whether it is there.
function Setup.MacroMade()
	return MacroIndex() ~= nil
end

-- Whether the macro the button put on the cursor is still there to drop. The
-- flag is Clicks.lua's, set when the pick-up took; it goes once the cursor holds
-- something else, so the line saying where to drop it goes with it. Another
-- macro on the cursor (one picked up from the macro window) is something else.
function Setup.Carrying()
	if not ns.macroOnCursor then return false end
	if type(GetCursorInfo) == "function" then
		local kind, index = GetCursorInfo()
		if kind == "macro" and (type(index) ~= "number" or index == MacroIndex()) then return true end
	end
	ns.macroOnCursor = false
	return false
end

-- The game's macro window, so the macro just made is there to drag. Out of
-- combat only, and this window shut first, as for the key bindings.
function Setup.OpenMacros()
	if InCombatLockdown() or type(ShowMacroFrame) ~= "function" then return false end
	ns.CloseOptions()
	return (pcall(ShowMacroFrame))
end

-- How many other characters use the profile this one is on, from AceDB's own
-- record of who uses which. 0 where the database cannot say.
function Setup.SharedWith()
	local db = ns.db
	local sv, keys = db and db.sv, db and db.keys
	if type(sv) ~= "table" or type(sv.profileKeys) ~= "table" or type(keys) ~= "table"
		or type(db.GetCurrentProfile) ~= "function" then
		return 0
	end
	local current = db:GetCurrentProfile()
	local n = 0
	for char, profile in pairs(sv.profileKeys) do
		if profile == current and char ~= keys.char then n = n + 1 end
	end
	return n
end

-- Whether the profile named after this character is already in the saved
-- file with something in it: made here once and left for a shared one since,
-- or picked on the Profiles tab. AceDB's CopyProfile empties the profile it
-- copies into before it copies, so going back to this one must never copy.
-- An empty one counts as none: AceDB strips the defaults from a profile it
-- leaves, so one nobody changed is empty, and copying into it loses nothing.
-- Empty, that is, but for what the repair at load (ClampSettings, Core.lua)
-- writes into every profile it meets, which AceDB keeps because none of it is
-- a default: its two stamps, the first run it starts as, and the Roleplay
-- lines it fills an empty phrase box with. A profile picked on the Profiles
-- tab and left without a change holds those and nothing else.
local function OnlyVisited(own)
	for key, value in pairs(own) do
		if key == "prompt" and type(value) == "table" then
			for k, v in pairs(value) do
				if not ((k == "anchorCarried" or k == "offsetsUnscaled") and v == true) then return false end
			end
		elseif key == "speech" and type(value) == "table" then
			for k, v in pairs(value) do
				if k ~= "phrases" or not (v == ns.PhraseSetText("roleplay")
					or ns.EnglishPhraseSet(v) == "roleplay") then
					return false
				end
			end
		elseif not (key == "firstRun" and (value == "pending" or value == "existing")) then
			return false
		end
	end
	return true
end

function Setup.OwnProfileExists()
	local db = ns.db
	local sv, keys = db and db.sv, db and db.keys
	if type(sv) ~= "table" or type(sv.profiles) ~= "table" or type(keys) ~= "table"
		or keys.char == nil then
		return false
	end
	local own = sv.profiles[keys.char]
	return type(own) == "table" and not OnlyVisited(own)
end

-- Whether the button below has anything to do: somebody else is on this
-- profile, and it is not the one named after this character. On that one it
-- is the others who came here, and leaving is theirs to do on the Profiles tab.
function Setup.CanOwnProfile()
	local db = ns.db
	return Setup.SharedWith() > 0 and db:GetCurrentProfile() ~= db.keys.char
end

-- A profile of this character's own, named after it, starting as a copy of
-- the shared one -- or, when it already has one, back to that one as it was
-- left. A profile switch moves the prompt and rewrites its macro, so it waits
-- for the fight to end, as the minimap menu's switch does.
function Setup.OwnProfile()
	local db = ns.db
	if InCombatLockdown() or not (db.SetProfile and db.CopyProfile and db.GetCurrentProfile
		and type(db.keys) == "table" and db.keys.char) then
		return false
	end
	return ns.Guard("own profile", function()
		local shared, mine = db:GetCurrentProfile(), db.keys.char
		if shared == mine then
			-- Already on it: nothing to make, and a press that did nothing
			-- without a word would read as broken. The button is hidden here,
			-- so this is one left on a page drawn before a switch elsewhere,
			-- and the redraw takes it away.
			if Setup.SharedWith() > 0 then
				ns.addon:Print(L["Your other characters are using this character's settings (profile: %s); they can pick their own on the Profiles tab."]:format(mine))
			else
				ns.addon:Print(L["This character now has its own settings (profile: %s)."]:format(mine))
			end
			ns.RefreshOptionsDisplay()
			return
		end
		-- Asked before the switch, which makes the profile if it is not there.
		local kept = Setup.OwnProfileExists()
		db:SetProfile(mine)
		if kept then
			ns.addon:Print(L["This character is back on its own settings (profile: %s)."]:format(mine))
		else
			db:CopyProfile(shared)
			ns.addon:Print(L["This character now has its own settings (profile: %s)."]:format(mine))
		end
		ns.RefreshOptionsDisplay()
	end)
end

---------------------------------------------------------------------------
-- Quick: the presets on Start here
--
-- Each preset writes plain profile fields, the same ones the controls on the
-- other tabs write, then runs the hooks their setters run. InvalidateMacro and
-- ApplyStyle already hold off in combat and catch up when the fight ends, so a
-- preset picked in combat never touches the secure button.
---------------------------------------------------------------------------

local Quick = {}
ns.QuickSetup = Quick

-- A field by its path from the profile, "sources.owed" style.
function Quick.Get(path)
	local node = ns.db.profile
	for part in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then return nil end
		node = node[part]
	end
	return node
end

function Quick.Set(path, value)
	local node = ns.db.profile
	local parts = {}
	for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
	for i = 1, #parts - 1 do
		if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
		node = node[parts[i]]
	end
	node[parts[#parts]] = value
end

-- Who to offer to. Never touches sources.asked (reading chat is its own
-- opt-in), the buff, the speech or the look -- nor the group buffs and the
-- ready-check and revived priorities, which are fine-tuning on Who to buff that
-- every choice leaves as it found them. "nearby" is a new profile's defaults,
-- so a fresh profile shows it; the entries are ordered so that exactly one can
-- match.
--
-- `applyOnly` fields are written when the choice is picked and then left to the
-- player: changing one is fine-tuning the choice, not leaving it, so the
-- dropdown does not turn to Custom over it.
--
-- "Myself" (sources.self) is one of them in every choice. "Only people who buff
-- me" switches it off, which is what its name says; the others switch it on,
-- so moving on from that one does not lose it. Never compared: a profile from
-- before 1.2 gains the switch on by default with nothing changed by hand, and
-- must not turn to "Custom (changed by hand)"; the summary under the dropdown
-- says whether you are offered.
Quick.WHO = {
	{ key = "favours", name = L["Only people who buff me"], set = {
		["sources.owed"] = true, ["sources.group"] = false, ["sources.strangers"] = false,
		["filters.whenBuffed"] = "skip", ["sources.self"] = false,
	}, applyOnly = { ["sources.self"] = true } },
	{ key = "group", name = L["People who buff me, and my group"], set = {
		["sources.owed"] = true, ["sources.group"] = true, ["sources.strangers"] = false,
		["filters.whenBuffed"] = "skip", ["sources.self"] = true,
	}, applyOnly = { ["sources.self"] = true } },
	-- How far "near" reaches is what the dropdown's tooltip invites tuning.
	{ key = "nearby", name = L["Everyone near me"], set = {
		["sources.owed"] = true, ["sources.group"] = true, ["sources.strangers"] = true,
		["filters.whenBuffed"] = "skip", ["filters.proximity"] = "near",
		["sources.self"] = true,
	}, applyOnly = { ["filters.proximity"] = true, ["sources.self"] = true } },
	{ key = "raid", name = L["My group, kept topped up (dungeons and raids)"], set = {
		["sources.owed"] = true, ["sources.group"] = true, ["sources.strangers"] = false,
		["sources.self"] = true,
		["filters.whenBuffed"] = "refresh",
	}, applyOnly = { ["sources.self"] = true } },
}

-- What to say. An entry with `lines` also loads that phrase set. Whether a
-- line also goes to people you buff first is the player's to tune, and the
-- summary says which it is.
Quick.VOICE = {
	{ key = "silent", name = L["Stay silent"], set = {
		["speech.enabled"] = false, ["prompt.thankEmote"] = false,
	} },
	{ key = "thank", name = L["Just /thank them"], set = {
		["speech.enabled"] = false, ["prompt.thankEmote"] = true,
	} },
	{ key = "polite", name = L["A polite line"], lines = "polite", set = {
		["speech.enabled"] = true, ["speech.channel"] = "SAY",
		["speech.onlyWhenReturning"] = true, ["prompt.thankEmote"] = false,
	}, applyOnly = { ["speech.onlyWhenReturning"] = true } },
	{ key = "whisper", name = L["Whisper them a thank-you"], lines = "polite", set = {
		["speech.enabled"] = true, ["speech.channel"] = "WHISPER",
		["speech.onlyWhenReturning"] = true, ["prompt.thankEmote"] = false,
	}, applyOnly = { ["speech.onlyWhenReturning"] = true } },
}
-- Phrases.lua loads before this file; without it there is no such set. Named
-- as What I say's Line set names it, so the two read as one set.
-- It speaks every time, unlike the two thank-you choices: the set has lines for
-- answering a request, offering to a stranger and buffing your group, and with
-- "only when I buff someone back" on none of them was ever heard -- a player
-- who picked it buffed a passer-by and their character said nothing.
if ns.InCharacter then
	table.insert(Quick.VOICE, 4, { key = "incharacter", name = L["In character (fits your race and class)"],
		lines = "incharacter", set = {
			["speech.enabled"] = true, ["speech.channel"] = "SAY",
			["speech.onlyWhenReturning"] = false, ["prompt.thankEmote"] = false,
		}, applyOnly = { ["speech.onlyWhenReturning"] = true } })
end

function Quick.Find(list, key)
	for _, entry in ipairs(list) do
		if entry.key == key then return entry end
	end
	return nil
end

-- Paths a class cannot use: a warrior's shout never reaches a passer-by, so the
-- passer-by switches are left out of the comparison (and of the choices).
function Quick.Ignored(list, path)
	return list == Quick.WHO and ns.OnlyReachesGroup()
		and (path == "sources.strangers" or path == "filters.proximity")
end

-- Whether every field the entry sets holds its value now, and for an entry
-- with lines, that the set is chosen and its lines are unedited. Its applyOnly
-- fields are not asked.
function Quick.Matches(list, entry)
	local loose = entry.applyOnly or {}
	for path, value in pairs(entry.set) do
		if not loose[path] and not Quick.Ignored(list, path) and Quick.Get(path) ~= value then return false end
	end
	if entry.lines then
		local sp = SP()
		if sp.presetChoice ~= entry.lines then return false end
		if entry.lines == "incharacter" then
			return ns.InCharacter ~= nil and ns.InCharacter.Active(sp) == true
		end
		return sp.phrases == ns.PhraseSetText(entry.lines)
	end
	return true
end

-- The key of the entry the profile matches, or "custom".
function Quick.Match(list)
	for _, entry in ipairs(list) do
		if Quick.Offered(list, entry) and Quick.Matches(list, entry) then return entry.key end
	end
	return "custom"
end

function Quick.Offered(list, entry)
	return not (list == Quick.WHO and entry.key == "nearby" and ns.OnlyReachesGroup())
end

-- The dropdown's choices: "Custom" only while nothing matches, so it can never
-- be picked, only shown.
function Quick.Values(list)
	local out = {}
	for _, entry in ipairs(list) do
		if Quick.Offered(list, entry) then out[entry.key] = entry.name end
	end
	if Quick.Match(list) == "custom" then out.custom = L["Custom (changed by hand)"] end
	return out
end

function Quick.Order(list)
	local values = Quick.Values(list)
	local keys = {}
	for _, entry in ipairs(list) do
		if values[entry.key] then keys[#keys + 1] = entry.key end
	end
	if values.custom then keys[#keys + 1] = "custom" end
	return keys
end

function Quick.Apply(list, key)
	return ns.Guard("quick setup", function()
		local entry = Quick.Find(list, key)
		if entry then
			for path, value in pairs(entry.set) do Quick.Set(path, value) end
			if entry.lines then
				local sp = SP()
				sp.presetChoice = entry.lines
				sp.phrases = ns.PhraseSetText(entry.lines) or sp.phrases
			end
			-- The hooks the individual setters run; both hold off in combat.
			ns.Prompt:InvalidateMacro()
			ns.Prompt:ApplyStyle()
			ns.addon:Print(L["Set up: %s."]:format(entry.name))
		end
		-- The broker text too: the favour count follows People who buff me.
		ns.RepaintOptions()
	end)
end

-- The confirm question for picking `key`, or false. Who: only over choices made
-- by hand. Voice: only when the box holds lines somebody wrote.
function Quick.Confirm(list, key)
	local entry = Quick.Find(list, key)
	if not entry then return false end
	if list == Quick.WHO then
		if Quick.Match(list) == "custom" then
			return L["This replaces your own choices on Who to buff and When to offer. Continue?"]
		end
		return false
	end
	if entry.lines then
		local sp = SP()
		local edited = sp.phrases ~= ns.PhraseSetText(sp.presetChoice or "roleplay")
		local inCharacter = ns.InCharacter and ns.InCharacter.Active(sp)
		if edited and not inCharacter then
			return L["This replaces the lines you wrote with the %s lines. Continue?"]:format(entry.name)
		end
	end
	return false
end

-- One live sentence about who is offered, from the values as they stand,
-- whatever the preset: on Custom it says what the custom mix is.
function Quick.WhoSummary()
	local s, f = S(), F()
	local who = {}
	if s.owed then who[#who + 1] = L["people who buff me"] end
	if s.group then who[#who + 1] = L["my group"] end
	if s.strangers and not ns.OnlyReachesGroup() then
		local about
		for _, tier in ipairs(ns.PROXIMITY) do
			if tier.key == f.proximity then about = tier.about end
		end
		who[#who + 1] = about and L["passers-by within %s"]:format(about) or L["passers-by"]
	end
	-- Last, as the queue ranks you behind every favour and request; and
	-- where, since nothing is offered to you in a city unless asked for.
	local own = OffersSelf()
	if own then
		who[#who + 1] = ns.db.profile.ownBuffs.inCities == true and L["myself"]
			or L["myself (outside cities and inns)"]
	end
	local list = #who > 0 and table.concat(who, ", ") or L["nobody"]
	local buffed = f.whenBuffed == "refresh" and L["topped up when low"]
		or f.whenBuffed == "always" and L["offered anyway"]
		or L["skipped"]
	local text
	if s.owed and not (s.group or s.asked or (s.strangers and not ns.OnlyReachesGroup())) then
		-- Favours only: BuildQueue offers a favour back whatever they carry,
		-- so "already buffed" has nobody to be about. Yourself included:
		-- yours is offered only once it is missing, which the list says.
		text = L["Offering to: %s."]:format(list)
	else
		text = L["Offering to: %s. Already buffed: %s."]:format(list, buffed)
		if s.owed then text = text .. " " .. L["People who buff me are always offered one back."] end
	end
	if s.asked then text = text .. " " .. L["People who ask in chat: on."] end
	if s.group then
		-- Guarded: the reagent count is an item API, and a summary is a
		-- `name` AceConfig reads with nothing around it.
		local ok, extra = pcall(Quick.GroupSummary)
		if ok and extra ~= "" then text = text .. " " .. extra end
	end
	return text
end

-- Step 1 for a class with nothing for anybody else (a hunter, a shaman): what
-- the prompt is for instead, from the answers the scan reads.
function Quick.OwnOnlySummary()
	if not S().self then
		return L["Your class has no buffs for other players, and %s is off, so the prompt never appears."]
			:format(Ref(L["Myself, when I'm missing my own buff"], TAB.who))
	end
	local names = {}
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		if ns.OwnPick(family) ~= "off" then names[#names + 1] = ns.OwnFamilyLabel(family) end
	end
	if #names == 0 then
		return L["Your class has no buffs for other players, and your own are all switched off on %s, so the prompt never appears."]
			:format(TAB.who)
	end
	local text = L["Your class has no buffs for other players, so the prompt reminds you of your own: %s."]
		:format(table.concat(names, ", "))
	if ns.db.profile.ownBuffs.inCities ~= true then
		text = text .. " " .. L["Not in cities and inns."]
	end
	return text
end

-- What My party and raid brings with it while it is on: the group buffs (for
-- a class that has learned one) and who goes first. Each only while its own
-- switch on Who to buff is on.
function Quick.GroupSummary()
	local parts = {}
	local gb = ns.db.profile.groupBuffs
	if gb.use and ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs() then
		for _, buff in ipairs(ns.CastableBuffs()) do
			local info = ns.BuffInfo(buff)
			-- GroupBuffs.lua casts one only with both a group rank and its reagent.
			if info and info.groupRank and info.groupReagent and #parts == 0 then
				local name = (ns.ReagentName and ns.ReagentName(info.groupReagent)) or tostring(info.groupReagent)
				local count = ns.ReagentCount and ns.ReagentCount(info.groupReagent)
				-- None needed with Forever's Reagent Economy (GroupBuffs.lua), so
				-- an empty bag is no news: said as when the count is unknown.
				if count == 0 and ns.ReagentWaived and ns.ReagentWaived(info, 0) then count = nil end
				-- On Forever a priest's, mage's or druid's counts the whole raid
				-- (GroupBuffs.lua); a Greater Blessing goes by class either way.
				local raidWide = ns.GROUP_IS_RAID and not ns.GROUP_BY_CLASS[ns.PlayerClass()]
				if count == 0 then
					parts[1] = L["%s: none in your bags, so group buffs are not offered."]:format(name)
				elseif count then
					parts[1] = (raidWide and L["Group buffs when %d of your party or raid need it (%s: %d in bags)."]
						or L["Group buffs when %d of a party need it (%s: %d in bags)."])
						:format(gb.atLeast, name, count)
				else
					parts[1] = (raidWide and L["Group buffs when %d of your party or raid need it."]
						or L["Group buffs when %d of a party need it."]):format(gb.atLeast)
				end
			end
		end
	end
	local pr = PR()
	if pr.readyCheck and pr.revived then
		parts[#parts + 1] = L["Ready checks and the just-revived go first."]
	elseif pr.readyCheck then
		parts[#parts + 1] = L["At a ready check, your group goes first."]
	elseif pr.revived then
		parts[#parts + 1] = L["The just-revived go first."]
	end
	return table.concat(parts, " ")
end

-- And one about what is said. A set is named by its own summary phrase ("a
-- polite line"), never by the dropdown's label dropped into a sentence.
function Quick.VoiceSummary()
	local sp = SP()
	local thanks = P().thankEmote
	-- The /thank answers somebody buffing you, whether People who buff me is
	-- on or not (Favours.lua, NoteFavour).
	local thankLine = thanks and L["Also /thanks people who buff you."]
	if not sp.enabled then
		return thanks and L["Only /thank."] or L["Silent."]
	end
	local set = ns.PHRASE_SETS[sp.presetChoice or "roleplay"]
	local phrase
	if ns.InCharacter and ns.InCharacter.Active(sp) then
		phrase = set and set.summary
	elseif set and sp.phrases == ns.PhraseSetText(sp.presetChoice or "roleplay") then
		phrase = set.summary
	end
	local where = sp.channel == "WHISPER" and L["a whisper"]
		or "/" .. tostring(ns.CHANNEL_COMMANDS[sp.channel] or "say")
	local text
	if phrase then
		text = sp.onlyWhenReturning
			and L["Says %s in %s when you buff someone back."]:format(phrase, where)
			or L["Says %s in %s when you buff someone."]:format(phrase, where)
	else
		text = sp.onlyWhenReturning
			and L["Says one of your own lines in %s when you buff someone back."]:format(where)
			or L["Says one of your own lines in %s when you buff someone."]:format(where)
	end
	if thankLine then text = text .. " " .. thankLine end
	return text
end

---------------------------------------------------------------------------
-- The first run: two questions on top of Start here
--
-- A profile that has never been set up (profile.firstRun, stamped by
-- ClampSettings: "pending" for a new one, "existing" for one from before)
-- opens the window on Start here with two of the presets above as plain
-- questions, a Done and a Skip. Picks wait in Quick.first until Done applies
-- them through Quick.Apply, as the dropdowns do; Skip leaves every setting as
-- it is. Either ends it for the profile, so it is never asked again.
---------------------------------------------------------------------------

-- The voice choices asked about: whispering is a fine-tune for later.
Quick.FIRST_VOICE = { silent = true, thank = true, polite = true, incharacter = true }
Quick.first = {}

function Quick.Pending()
	local profile = ns.db and ns.db.profile
	return type(profile) == "table" and profile.firstRun == "pending"
end

-- Shown only to a class with something to give: both questions are about it.
function Quick.Asking()
	return Quick.Pending() and HasClassBuffs() == true
end

local function FirstSlot(list) return list == Quick.WHO and "who" or "voice" end

function Quick.FirstValues(list)
	local out = {}
	for key, name in pairs(Quick.Values(list)) do
		if key ~= "custom" and (list ~= Quick.VOICE or Quick.FIRST_VOICE[key]) then out[key] = name end
	end
	return out
end

function Quick.FirstOrder(list)
	local values, keys = Quick.FirstValues(list), {}
	for _, key in ipairs(Quick.Order(list)) do
		if values[key] then keys[#keys + 1] = key end
	end
	return keys
end

-- The pick so far, else what the profile matches now, else the first choice.
function Quick.FirstPick(list)
	local values = Quick.FirstValues(list)
	local picked = Quick.first[FirstSlot(list)]
	if picked and values[picked] then return picked end
	local now = Quick.Match(list)
	if values[now] then return now end
	return Quick.FirstOrder(list)[1]
end

function Quick.SetFirstPick(list, key)
	if Quick.FirstValues(list)[key] then Quick.first[FirstSlot(list)] = key end
end

-- Done asks first only where a preset would: over choices made by hand, or
-- over lines somebody wrote.
function Quick.FirstConfirm()
	return Quick.Confirm(Quick.WHO, Quick.FirstPick(Quick.WHO))
		or Quick.Confirm(Quick.VOICE, Quick.FirstPick(Quick.VOICE))
end

-- Done (answered) or Skip. The state is written first, so the questions are
-- gone even if applying a preset fails.
function Quick.FinishFirstRun(answered)
	if not Quick.Pending() then return end
	local who, voice = Quick.FirstPick(Quick.WHO), Quick.FirstPick(Quick.VOICE)
	ns.db.profile.firstRun = answered and "answered" or "skipped"
	Quick.first = {}
	if answered then
		if who then Quick.Apply(Quick.WHO, who) end
		if voice then Quick.Apply(Quick.VOICE, voice) end
	end
	ns.RefreshOptionsDisplay()
end

-- The Start here group: switching Manners on, the numbered steps (who to buff,
-- a key, seeing the prompt, what to say), the snooze and the ledger. The
-- options window places them (Options/Window/Layout.lua): the switch, the
-- preview and the snooze in its header, the voice choice on What I say, the
-- profile lines on Profiles. Ledger.lua repaints this page by its id,
-- "general".
function Page.BuildStartTab()
	-- The steps and the snooze are about a prompt; a class with nothing to
	-- cast gets the noBuffs text instead.
	local function noClassBuffs() return not HasClassBuffs() end
	-- The steps about the prompt itself -- a key, seeing it, the snooze --
	-- are for a hunter with an aspect learned too, whose prompt is for his
	-- own buffs; the steps about other people are not.
	local function noPrompt() return not HasPrompt() end
	local function grey(text) return "|cff888888" .. text .. "|r" end
	local function notAsking() return not Quick.Asking() end

	return {
		type = "group",
		name = TAB.general,
		order = 1,
		args = {
			-- The first run's two questions, above everything while the
			-- profile has never been set up (Quick.Asking). The window draws
			-- them as the first section of the page.
			firstHeader = {
				type = "header", name = L["Quick setup"], order = 0.1,
				hidden = notAsking,
			},
			firstWho = {
				type = "select",
				name = L["Who do you want to buff?"],
				order = 0.2,
				width = "full",
				hidden = notAsking,
				values = function() return Quick.FirstValues(Quick.WHO) end,
				sorting = function() return Quick.FirstOrder(Quick.WHO) end,
				get = function() return Quick.FirstPick(Quick.WHO) end,
				set = function(_, v) Quick.SetFirstPick(Quick.WHO, v) end,
			},
			firstVoice = {
				type = "select",
				name = L["Should your character talk?"],
				order = 0.3,
				width = "full",
				hidden = notAsking,
				values = function() return Quick.FirstValues(Quick.VOICE) end,
				sorting = function() return Quick.FirstOrder(Quick.VOICE) end,
				get = function() return Quick.FirstPick(Quick.VOICE) end,
				set = function(_, v) Quick.SetFirstPick(Quick.VOICE, v) end,
			},
			firstDone = {
				type = "execute",
				name = L["Done"],
				order = 0.4,
				hidden = notAsking,
				confirm = function() return Quick.FirstConfirm() end,
				func = function() Quick.FinishFirstRun(true) end,
			},
			firstSkip = {
				type = "execute",
				name = L["Skip"],
				desc = L["Leaves every setting as it is. The same choices are below and on the other tabs."],
				order = 0.5,
				hidden = notAsking,
				func = function() Quick.FinishFirstRun(false) end,
			},
			enabled = {
				type = "toggle",
				name = L["Manners is on"],
				order = 1,
				width = "full",
				get = function() return ns.db.profile.enabled end,
				set = function(_, v)
					ns.db.profile.enabled = v
					ns.Prompt:Refresh()
					-- The launcher's text carries this switch too. Through
					-- the guarded shared call, because what runs on the far
					-- side is another addon's display frame.
					ns.RepaintOptions()
				end,
			},
			noBuffs = {
				type = "description",
				order = 2,
				fontSize = "medium",
				hidden = HasPrompt,
				-- "Your class has none" and "we could not work out what
				-- you can cast" look identical from hasClassBuffs alone;
				-- CLASSES_WITHOUT_BUFFS is what tells them apart. The /thank
				-- is named: it is the one thing such a class has here.
				name = function()
					if ns.caps.class and ns.CLASSES_WITHOUT_BUFFS[ns.caps.class] then
						return "\n|cffff8080"
							.. L["Your class has no buffs it can cast on another player."]
							.. "|r\n\n"
							.. L["Manners can still answer a buff with a /thank: %s. And it is worth keeping installed on an alt that has buffs."]
								:format(Ref(L["/thank people who buff me"], TAB.click))
							.. "\n"
					end
					-- The command is handed in rather than written into the
					-- sentence, so no translation can turn it into a word the
					-- slash handler does not know.
					return "\n|cffff8080" .. L["Manners could not work out what you can cast."]
						.. "|r\n\n"
						.. L["Either your class has nothing for other players, or the spell probe came back empty -- %s says which."]
							:format("|cffffd100/manners debug|r")
						.. "\n"
				end,
			},
			-- One definition of the word every other tab uses. Putting it on
			-- a key is step 2's job, not a paragraph's.
			howItWorks = {
				type = "description",
				order = 3,
				fontSize = "medium",
				hidden = noClassBuffs,
				name = L["Manners shows a small button, the prompt, with the next person to buff. Click it, or press your key, and it casts on them; the game does not let addons cast by themselves."]
					.. "\n",
			},
			-- ApplyStyle holds off in a fight and catches up when it ends, so
			-- this never touches the secure button in combat.
			lockNow = {
				type = "execute",
				name = L["Lock it"],
				order = 4.1,
				hidden = function() return P().locked or not HasPrompt() end,
				func = function()
					P().locked = true
					ns.Prompt:ApplyStyle()
					ns.RefreshOptionsDisplay()
				end,
			},

			-- Every character starts on the shared Default profile, so a
			-- setup made here reaches the alts too. Said where profiles are
			-- explained, and only while another character is actually on this
			-- profile. That can be this character's own, picked by an alt on
			-- the Profiles tab, and the line then says the others are on it.
			sharedNote = {
				type = "description",
				order = 8,
				hidden = function() return Setup.SharedWith() == 0 end,
				name = function()
					local db = ns.db
					local name = db.GetCurrentProfile and db:GetCurrentProfile() or "Default"
					local line = L["These settings are shared by your other characters (profile: %s)."]
					if type(db.keys) == "table" and name == db.keys.char then
						line = L["Your other characters are using this character's settings (profile: %s); they can pick their own on the Profiles tab."]
					end
					return grey(line:format(tostring(name)))
				end,
			},
			-- Offered only where it does something (Setup.CanOwnProfile). A
			-- character that already has a profile of its own is sent back to
			-- it, never given a fresh copy over it: the button says so.
			ownProfile = {
				type = "execute",
				name = function()
					if Setup.OwnProfileExists() then return L["Go back to this character's own settings"] end
					return L["Give this character its own settings"]
				end,
				desc = function()
					if Setup.OwnProfileExists() then
						return L["Switches back to the profile named after this character; nothing is copied or overwritten."]
					end
					return L["Copies these settings into a profile named after this character; changes made after that stay on this character."]
				end,
				order = 8.1,
				hidden = function() return not Setup.CanOwnProfile() end,
				disabled = function() return InCombatLockdown() end,
				func = function() Setup.OwnProfile() end,
			},

			-- Step 1. A preset, with the sentence that says what it came to;
			-- the switches themselves are on Who to buff.
			whoHeader = {
				type = "header", name = L["1. Who to buff"], order = 10,
				hidden = noPrompt,
			},
			quickWho = {
				type = "select",
				name = L["Offer my buff to"],
				desc = L["A starting point; fine-tune it on Who to buff."],
				order = 11,
				width = "full",
				hidden = noClassBuffs,
				values = function() return Quick.Values(Quick.WHO) end,
				sorting = function() return Quick.Order(Quick.WHO) end,
				get = function() return Quick.Match(Quick.WHO) end,
				set = function(_, v) Quick.Apply(Quick.WHO, v) end,
				confirm = function(_, v) return Quick.Confirm(Quick.WHO, v) end,
			},
			-- For a hunter, what the prompt is for, since the choice above
			-- is about other people and is not shown.
			quickWhoSummary = {
				type = "description",
				order = 12,
				hidden = noPrompt,
				name = function()
					if not HasClassBuffs() then return grey(Quick.OwnOnlySummary()) end
					return grey(Quick.WhoSummary())
				end,
			},

			-- Step 2. The binding is the game's, not the profile's: Setup
			-- saves it with the binding set, so it follows every profile.
			keyHeader = {
				type = "header", name = L["2. Put it on a key"], order = 20,
				hidden = noPrompt,
			},
			bindKey = {
				type = "keybinding",
				name = L["Key that buffs the prompted player"],
				desc = L["Saved with your game key bindings, so it works on every profile."],
				order = 21,
				hidden = function() return not HasPrompt() or not Setup.CanBind() end,
				-- SetBinding is refused in a fight.
				disabled = function() return InCombatLockdown() end,
				get = function() return Setup.Key() or "" end,
				set = function(_, v) Setup.SetKey(v) end,
			},
			openBindings = {
				type = "execute",
				name = L["Open key bindings"],
				desc = L["Opens Options > Keybindings > Manners, the game's own key bindings."],
				order = 22,
				hidden = function() return not HasPrompt() or not Setup.CanOpenBindings() end,
				disabled = function() return InCombatLockdown() end,
				func = function() Setup.OpenBindings() end,
			},
			makeMacro = {
				type = "execute",
				name = L["Put Manners on an action bar"],
				desc = L["Makes the Manners macro and puts it on your cursor: drop it on any action bar slot. The slot then shows the spell a press would cast."],
				order = 23,
				hidden = noPrompt,
				-- Not greyed in a fight: the press says why it does nothing.
				-- Repainted so the line under it says where to drop it; where
				-- the client would not carry it, the macro window is opened
				-- instead, so the macro is there to drag.
				func = function()
					if not ns.CreateClickMacro() and Setup.MacroMade() then Setup.OpenMacros() end
					ns.RefreshOptionsDisplay()
				end,
			},
			bindStatus = {
				type = "description",
				order = 24,
				fontSize = "medium",
				hidden = noPrompt,
				name = function()
					local key = Setup.Key()
					if Setup.Carrying() then
						return "|cffffd100" .. L["Drop it on any action bar slot."] .. "|r"
					elseif key then
						local shown = type(GetBindingText) == "function" and GetBindingText(key) or key
						return "|cff80e080" .. L["Ready: %s buffs whoever the prompt shows."]
							:format(tostring(shown)) .. "|r"
					elseif Setup.MacroMade() then
						return "|cffffd100" .. L["Your Manners macro is made: open the macro window (/macro) and drag it onto an action bar."] .. "|r"
					end
					return "|cffff8080" .. L["No key yet: pick one above, make the macro, or just click the prompt."] .. "|r"
				end,
			},

			-- Step 3. The preview, which the options window draws in its
			-- header so every page has it; where the prompt sits and its lock
			-- are on Look, once.
			tryHeader = {
				type = "header", name = L["3. See it"], order = 30,
				hidden = noPrompt,
			},
			previewStart = {
				type = "execute",
				name = function()
					return ns.Prompt:InTest() and L["Stop preview"] or L["Show me the prompt"]
				end,
				desc = L["Shows a sample prompt so you can see it and put it where you want."],
				order = 31,
				hidden = noPrompt,
				-- ToggleTest refuses to start one in a fight, and one already
				-- running can still be stopped.
				disabled = function()
					return not ns.Prompt:InTest() and InCombatLockdown()
				end,
				func = function() ns.Prompt:ToggleTest() end,
			},
			-- Beside it in the window's header too, so moving the prompt is
			-- one press from every page; Look leads with the same control
			-- (appearance.move).
			moveToggle = Page.MoveControl(32),

			-- Step 4. What is said, as a preset; the words are on What I say.
			voiceHeader = {
				type = "header", name = L["4. Say thanks (optional)"], order = 40,
				hidden = noClassBuffs,
			},
			quickVoice = {
				type = "select",
				-- No tooltip: it leads What I say, above the switches it sets.
				name = L["When I buff someone"],
				order = 41,
				width = "full",
				hidden = noClassBuffs,
				values = function() return Quick.Values(Quick.VOICE) end,
				sorting = function() return Quick.Order(Quick.VOICE) end,
				get = function() return Quick.Match(Quick.VOICE) end,
				set = function(_, v) Quick.Apply(Quick.VOICE, v) end,
				confirm = function(_, v) return Quick.Confirm(Quick.VOICE, v) end,
			},
			quickVoiceSummary = {
				type = "description",
				order = 42,
				hidden = noClassBuffs,
				name = function() return grey(Quick.VoiceSummary()) end,
			},

			-- The three lengths in ns.SNOOZE_CHOICES. The minimap menu
			-- keeps its own list, with an hour added; all of them go
			-- through ns.StartSnooze, as /manners snooze does, so every
			-- way in says the same thing in chat.
			snoozeHeader = {
				type = "header", name = L["Snooze"], order = 50,
				hidden = noPrompt,
			},
			snoozeNote = {
				type = "description",
				order = 50.5,
				fontSize = "medium",
				hidden = noPrompt,
				name = function()
					local ends = ns.SnoozeEndsAt()
					-- The page is repainted at both ends of a fight, so this
					-- is only shown while it is true. Worded for a snooze
					-- started in the fight and one started before it.
					if ends and InCombatLockdown() then
						return L["|cffffd100Snoozed until %s.|r In a fight the prompt stays as the fight found it, and follows the snooze once the fight ends."]
							:format(ends)
					elseif ends and DragPanelUp() then
						-- The lock is read before the snooze, so an unlocked
						-- prompt stays on screen for the whole snooze.
						return L["|cffffd100Snoozed until %s.|r The prompt is unlocked, so it stays up to be dragged, casting nothing, until you lock it."]
							:format(ends)
					elseif ends then
						-- Not "offered when it ends": a favour is remembered for
						-- as long as the When tab says, usually less than a snooze.
						return L["|cffffd100Snoozed until %s.|r No prompt until then, though who buffs you is still noticed."]
							:format(ends)
					end
					return L["Hide the prompt for a while without turning Manners off."]
				end,
			},
			snooze5 = {
				type = "execute",
				name = function() return L["Snooze %s"]:format(ns.MinutesText(ns.SNOOZE_CHOICES[1])) end,
				order = 51,
				hidden = noPrompt,
				func = function() ns.StartSnooze(ns.SNOOZE_CHOICES[1]) end,
			},
			snooze15 = {
				type = "execute",
				name = function() return L["Snooze %s"]:format(ns.MinutesText(ns.SNOOZE_CHOICES[2])) end,
				order = 52,
				hidden = noPrompt,
				func = function() ns.StartSnooze(ns.SNOOZE_CHOICES[2]) end,
			},
			snooze30 = {
				type = "execute",
				name = function() return L["Snooze %s"]:format(ns.MinutesText(ns.SNOOZE_CHOICES[3])) end,
				order = 53,
				hidden = noPrompt,
				func = function() ns.StartSnooze(ns.SNOOZE_CHOICES[3]) end,
			},
			snoozeStop = {
				type = "execute",
				name = L["Stop snoozing"],
				order = 54,
				-- With the other three: a snooze started from chat or the
				-- minimap menu does not give a rogue a Snooze button.
				hidden = function() return noPrompt() or not ns.SnoozeLeft() end,
				func = function() ns.StopSnooze() end,
			},

			-- What the addon has done, rather than a setting. Here
			-- because Start here is the page people land on, and the
			-- window is otherwise only a slash command away.
			ledgerHeader = {
				type = "header", name = L["Favour ledger"], order = 60,
				hidden = function() return not ns.Ledger end,
			},
			ledgerSummary = {
				type = "description",
				order = 61,
				fontSize = "medium",
				hidden = function() return not ns.Ledger end,
				name = function() return ns.Ledger and ns.Ledger.OptionsText() or "" end,
			},
			ledgerOpen = {
				type = "execute",
				name = L["Open the ledger"],
				desc = L["Who buffed you, whether you returned it, and who you buffed first."],
				order = 62,
				hidden = function() return not ns.Ledger end,
				-- The options stay open: both windows are HIGH and toplevel,
				-- and Show raises the ledger above this one.
				func = function() ns.Ledger.Show() end,
			},

			-- Last, under a header of its own: where the way back in lives,
			-- and the chat lines people reach for when they want quiet.
			minimapHeader = { type = "header", name = L["Minimap and chat"], order = 69 },
			minimap = {
				type = "toggle",
				name = L["Show minimap button"],
				order = 70,
				-- Said where the choice is made, because hiding the button
				-- loses nothing only while the compartment holds Manners
				-- and is itself on screen.
				desc = function()
					if CompartmentShown() then
						return L["Manners stays in the addon compartment under the minimap either way."]
					end
					return L["Without it, open these settings with %s or Options > AddOns."]
						:format("|cffffd100/manners|r")
				end,
				-- Gone entirely where the libraries are not: there is no
				-- button for a greyed-out control to be about.
				hidden = function() return not HasMinimapButton() end,
				get = function() return not ns.db.profile.minimap.hide end,
				set = function(_, v)
					ns.db.profile.minimap.hide = not v
					if LDBIcon then
						if v then LDBIcon:Show(ADDON) else LDBIcon:Hide(ADDON) end
					end
				end,
			},
			-- Lines printed to your own chat frame, never said aloud. On by
			-- default, and the switch people look for when the lines annoy
			-- them, so here rather than on Diagnostics.
			verbose = {
				type = "toggle",
				-- A cast that worked prints nothing unless it repaid a
				-- favour, so the label promises what it is doing, not a
				-- line per click.
				name = L["Tell me in chat what Manners is doing"],
				-- What it prints first: a cast that worked prints only
				-- "repaid", and somebody who switched it on to watch
				-- their casts took the silence for a broken switch.
				desc = L["A line when somebody buffs you, when a favour is counted as repaid, and when a click fails, is skipped, or leaves somebody owed."]
					.. "\n\n"
					.. L["Only you see these; they show whether a buff was missed or someone could not be reached."],
				order = 71,
				width = "full",
				get = function() return ns.db.profile.verbose end,
				set = function(_, v) ns.db.profile.verbose = v end,
			},
		},
	}
end
