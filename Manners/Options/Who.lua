-- Manners -- options: the Who to buff tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local restyleAndMacro, S, F, B = Page.restyleAndMacro, Page.S, Page.F, Page.B
local sGet, sSet, fGet, fSet = Page.sGet, Page.sSet, Page.fGet, Page.fSet
local bSet, prGet, prSet, HasClassBuffs = Page.bSet, Page.prGet, Page.prSet, Page.HasClassBuffs
local OnlyReachesGroup, HasPrompt, TAB = Page.OnlyReachesGroup, Page.HasPrompt, Page.TAB

local function BuffChoices()
	local values = { auto = L["Automatic (whatever they are missing)"] }
	for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		local label = (info and info.name) or buff.key
		if not (info and info.known) then label = L["%s |cff808080(not learned)|r"]:format(label) end
		values[buff.key] = label
	end
	return values
end

-- The named distances, read off the list Range.lua measures with, so the
-- dropdown cannot offer a setting nothing implements. Each with its rough
-- yardage, since what somebody picks is a feeling but they will want to know
-- roughly what they just asked for.
local function ProximityChoices()
	local values = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		values[tier.key] = tier.about and ("%s (%s)"):format(tier.name, tier.about) or tier.name
	end
	return values
end

-- AceConfig sorts a select's values by their labels unless it is given an
-- order, and a translation would scramble loosest-to-tightest.
local function ProximityOrder()
	local keys = {}
	for _, tier in ipairs(ns.PROXIMITY) do
		keys[#keys + 1] = tier.key
	end
	return keys
end

-- The spell's name, with the one thing about it that changes who it is offered
-- to. "Mana users only" only while "Skip players it does nothing for" is
-- on, since that filter is what holds a mana-only spell back.
local function BuffLabel(buff)
	local label = ns.BuffName(buff)
	if buff.manaOnly and F().relevantOnly then
		label = L["%s |cff808080(mana users only)|r"]:format(label)
	end
	if buff.partyOnly or buff.groupOnly then label = L["%s |cff808080(your group only)|r"]:format(label) end
	return label
end

-- What "Automatic" will actually do, for this character, as it is configured
-- right now: the list in the order it is walked, taken from the same function
-- the scan uses so the two cannot drift.
local function AutoExplanation()
	local castable = ns.CastableBuffs()
	if #castable == 0 then
		-- Each way to have nothing to offer gets its own answer, so nobody is
		-- sent looking at switches that are already on.
		if not HasClassBuffs() then
			return L["This character has nothing it can cast on another player."]
		end
		local anyKnown = false
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if ns.IsBuffKnown(buff) then anyKnown = true end
		end
		if not anyKnown then
			return "|cffff8080"
				.. L["You have not learned any of these yet, so nobody will be offered anything."]
				.. "|r"
		end
		-- The only thing learned is one Automatic never reaches for -- a Mists
		-- warlock with Unending Breath and no Dark Intent yet.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if buff.neverAuto and ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080"
					.. L["Automatic never offers %s -- nobody standing in a city wants it -- so nobody will be offered anything."]
						:format(ns.BuffName(buff))
					.. "|r\n\n"
					.. L["Pick it in Buff to offer if you want it given out anyway."]
			end
		end
		-- Everything learned is switched off, but a spell not learned yet is
		-- still ticked, and learning it brings the prompt back. A neverAuto
		-- spell is left out: learning it would bring nothing back.
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if not buff.neverAuto and not ns.IsBuffKnown(buff) and not B().skip[buff.key] then
				return "|cffff8080"
					.. L["Every spell you have learned is switched off, so nothing is offered until you switch one back on or learn one of the others."]
					.. "|r"
			end
		end
		return "|cffff8080" .. L["Every spell below is switched off, so the prompt will never appear."]
			.. "|r"
	end

	local names = {}
	for _, buff in ipairs(castable) do
		names[#names + 1] = "|cffffffff" .. BuffLabel(buff) .. "|r"
	end
	local list = table.concat(names, ", ")

	-- Blessings overwrite one another, so for these classes Automatic gives one
	-- and stops. "Left alone" rests on reading what they carry: "Always offer"
	-- chooses not to look and a client that hides a blessing's aura cannot, and
	-- either way the first blessing that suits them can replace one of yours
	-- (deliberately, see PickBuffFor).
	--
	-- Whole sentences rather than one with a clause bolted on, so that a
	-- translation can put the exception wherever its own grammar wants it.
	if ns.EXCLUSIVE_BUFFS[ns.caps.class] then
		local hidden = false
		for _, buff in ipairs(castable) do
			local info = ns.BuffInfo(buff)
			if not (info and info.readable) then hidden = true end
		end
		if F().whenBuffed == "always" then
			return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. |cffffd100Always offer|r does not check what they carry, so it can replace one of yours."]
				:format(list)
		elseif hidden then
			return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. Where the game hides which blessing somebody carries, it can replace one of yours."]
				:format(list)
		end
		return L["Your blessings replace one another, so Automatic gives only the first of %s that suits them. Anybody already carrying one of yours is left alone."]
			:format(list)
	end

	local text = L["Automatic may offer, in this order: %s. Each person gets the first one they are missing."]
		:format(list)
	if ns.RotatesBuffs() then
		text = text .. "\n|cff888888"
			.. L["When the game hides what someone has, it tries the next one each time."]
			.. "|r"
	end
	return text
end

-- What pinning one spell means, and the one case where pinning is a silent
-- switch-off: a pinned buff you have not learned is offered to nobody. The pin
-- is deliberately not reset for you (a failed spell probe must not rewrite a
-- setting), which is why it has to be said out loud here.
local function PinExplanation()
	local choice = B().choice
	local buff = ns.FindBuff(ns.caps.class, choice)
	local name = buff and ns.BuffName(buff) or tostring(choice)

	if buff and ns.IsBuffKnown(buff) then
		return L["Only |cffffffff%s|r is offered, to everybody, whatever else they are missing. The per-spell switches come back with Automatic."]
			:format(name)
	end

	return "|cffff8080"
		.. L["You picked %s in Buff to offer, but have not learned it, so nothing is offered."]:format(name)
		.. "|r\n\n"
		.. L["Learn it or set Buff to offer back to Automatic."]
end

-- One toggle per spell the class can put on somebody else, built once with the
-- page (only whether each is learned changes, and the label asks that live).
-- Switched on is the *absence* of a key, so an untouched profile stores nothing.
local function AddBuffToggles(args)
	local buffs = ns.GetClassBuffs(ns.caps.class) or {}
	-- One spell is not a choice. The walk has nothing to walk, and a lone
	-- toggle under "Automatic" reads as a second way to switch the addon off.
	if #buffs < 2 then return end

	for index, buff in ipairs(buffs) do
		args["offer_" .. buff.key] = {
			type = "toggle",
			name = function()
				local label = BuffLabel(buff)
				if not ns.IsBuffKnown(buff) then
					label = L["%s |cff808080(not learned)|r"]:format(label)
				end
				return label
			end,
			desc = L["Untick to never offer this buff."],
			-- Sub-one steps so the whole block sits between the buff dropdown
			-- and "Skip players it does nothing for" (4.9) whatever the class
			-- has, and in the order the buff set lists them (which is the walk's,
			-- but for a paladin's Kings first: Automatic's note says that one).
			order = 4 + index / 10,
			width = "full",
			-- A pinned spell is the only one considered, so these would be
			-- switches over something that is not consulted. Only a pin of this
			-- class's counts: another class's is Automatic here.
			hidden = function() return ns.PinnedBuff() ~= nil end,
			disabled = function() return not ns.IsBuffKnown(buff) end,
			get = function() return not B().skip[buff.key] end,
			set = function(_, value)
				-- nil rather than false: AceDB stores the difference from the
				-- defaults, and an empty table is stored as nothing.
				B().skip[buff.key] = (not value) or nil
				restyleAndMacro()
			end,
		}
	end
end

-- Whether nothing this character can offer goes on themselves -- a warrior,
-- whose shout already covers him and who has no buff of his own -- which
-- leaves "Myself" with nothing behind it. Follows the per-spell switches, as
-- the scan does (ns.SelfBuffs), and counts every family of the class's own
-- buffs you know, switched off or not: their switches live under it.
local function NothingForSelf()
	return #ns.SelfBuffs() == 0 and #ns.KnownOwnFamilies() == 0
end

-- The family dropdown's Automatic, saying what it would pick right now, in
-- plain words, from the same answer the scan uses (ns.OwnAutoPick).
local function OwnAutoLabel(family)
	local spell, why = ns.OwnAutoPick(family)
	if why == "tank" or why == "notank" then return L["Automatic (only while I'm the tank)"] end
	-- Passing over one somebody else of your class has on you: no one spell
	-- to name for long, since theirs comes and goes.
	if why == "covered" then return L["Automatic"] end
	local name = spell and ns.BuffName(spell)
	if not name then return L["Automatic"] end
	if why == "last" then return L["Automatic (%s, the one you had up last)"]:format(name) end
	if why == "dungeon" then return L["Automatic (%s, in a dungeon or raid)"]:format(name) end
	if why == "world" then return L["Automatic (%s, outside dungeons and raids)"]:format(name) end
	if why == "best" then return L["Automatic (%s, the best you can use now)"]:format(name) end
	return L["Automatic (%s, until you have put one up)"]:format(name)
end

-- The choices a family's dropdown lists: the spells you know, or for a
-- mage's scrolls every one of them, so a pick stays on the list while you
-- have none of it left. A weapon enhancement has dozens to a family, so its
-- list is the ones your bags hold and the one picked, which stays while the
-- bags are empty of it.
local function OwnChoice(family, spell)
	if family.enhance then
		local picks = ns.db.profile.ownBuffs.pick
		return ns.OwnSpellKnown(spell) or (type(picks) == "table" and picks[family.key] == spell.key)
	end
	return family.scroll or ns.OwnSpellKnown(spell)
end

-- One control per family of your class's own buffs, under "Myself" on Who to
-- buff: a dropdown where there is a choice (Automatic, each spell you know,
-- Don't remind me), a checkbox for a spell alone. Made for every family of
-- every class on this client and hidden but for your class's and the ones you
-- know, so learning an aspect mid-session shows it without a reload.
local function AddOwnControls(args)
	local order = 15.2
	local classes = {}
	for class in pairs(ns.OWN_BUFFS or {}) do classes[#classes + 1] = class end
	table.sort(classes)
	for _, class in ipairs(classes) do
		for _, family in ipairs(ns.OWN_BUFFS[class]) do
			-- A family of several classes (tracking, a stone) is made once for each,
			-- and the last stands; a thousandth apiece keeps every one of them
			-- inside 15.2x, ahead of Also in cities and inns at 15.9.
			order = order + 0.001
			local pick = function() return (ns.OwnPick(family)) end
			local write = function(_, value)
				ns.db.profile.ownBuffs.pick[family.key] = value
				-- The prompt follows at once rather than at the next scan.
				ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
			end
			local control = {
				order = order,
				width = "full",
				hidden = function()
					for _, known in ipairs(ns.KnownOwnFamilies()) do
						if known == family then return false end
					end
					return true
				end,
				disabled = function() return not S().self end,
			}
			if #family.spells > 1 or family.tank then
				control.type = "select"
				control.name = function() return ns.OwnFamilyLabel(family) end
				control.desc = function()
					if family.tank then
						return L["Automatic reminds you only while your group role is tank; Always reminds you whenever it is not up."]
					end
					if family.enhance then
						return L["Reminds you when nothing is on the weapon in your %s and one of these in your bags fits it. Automatic takes the one you used last, else the best you can use."]
							:format(ns.HandName(family.slot))
					end
					if family.imbue then
						return L["Reminds you when nothing is on the weapon in your main hand and a scroll in your bags fits it. Automatic takes the one you used last, else the best you can use."]
					elseif family.scroll then
						return L["Reminds you when no familiar is with you and a scroll for one is in your bags. Automatic takes the one you used last, else the best your level allows."]
					end
					local text = L["Reminds you when none of these is up. Automatic takes the one you had up last."]
					-- A mage before any armor has been up: where Automatic
					-- goes, both ways, while that is what it is doing.
					local dungeon = family.dungeon and ns.FindOwnSpell(family.dungeon)
					local _, why = ns.OwnAutoPick(family)
					if dungeon and ns.OwnSpellKnown(dungeon) and (why == "dungeon" or why == "world") then
						for _, spell in ipairs(family.spells) do
							if spell ~= dungeon and ns.OwnSpellKnown(spell) and not spell.neverAuto then
								return text .. " " .. L["Until you have had one up: %s in a dungeon or raid, %s elsewhere."]
									:format(ns.BuffName(dungeon), ns.BuffName(spell))
							end
						end
					end
					return text
				end
				control.values = function()
					local values = { auto = OwnAutoLabel(family), off = L["Don't remind me"] }
					for _, spell in ipairs(family.spells) do
						if OwnChoice(family, spell) then
							values[spell.key] = family.tank and L["Always"] or ns.BuffName(spell)
						end
					end
					return values
				end
				-- Automatic, the spells in the table's order, Don't remind me:
				-- AceConfig would sort them by their translated names.
				control.sorting = function()
					local sorted = { "auto" }
					for _, spell in ipairs(family.spells) do
						if OwnChoice(family, spell) then sorted[#sorted + 1] = spell.key end
					end
					sorted[#sorted + 1] = "off"
					return sorted
				end
				control.get = pick
				control.set = write
			else
				control.type = "toggle"
				control.name = function() return ns.OwnFamilyLabel(family) end
				control.desc = L["Reminds you when it is not up."]
				control.get = function() return pick() ~= "off" end
				control.set = function(info, value) write(info, value and "auto" or "off") end
			end
			args["own_" .. family.key] = control
		end
	end
end

-- Everything on Who to buff but "Myself", hidden from a class with nothing
-- for anybody else (a hunter, a shaman): their tab is their own buffs alone.
-- Each control keeps its own rule on top.
local function ForOthersOnly(args)
	for key, arg in pairs(args) do
		if not (key == "myselfHeader" or key == "self" or key == "ownCities" or key:find("^own_")) then
			local was = arg.hidden
			arg.hidden = function(...)
				if not HasClassBuffs() then return true end
				if type(was) == "function" then return was(...) end
				return was
			end
		end
	end
end

-- Who is picked in the never-offer dropdown, waiting for Remove from list; a
-- state of the window, like Page.reportOpen.
local neverPicked

-- The never-offer list as dropdown choices, built fresh each time, because a
-- shift-right-click or /manners never can add to it while the page is open.
local function NeverChoices()
	local values = {}
	for _, name in ipairs(ns.NeverList()) do values[name] = name end
	return values
end

-- The eight raid groups as checkbox labels, keyed by group number, which is
-- what the profile stores.
local function RaidGroupChoices()
	local values = {}
	for group = 1, 8 do values[group] = L["Group %d"]:format(group) end
	return values
end

-- A passer-by is seen mostly through a nameplate token, and with the game's
-- friendly nameplates off almost nobody outside your group has one, so the
-- note and the button under the passers-by switch say so (they hold only
-- while it is so, and What I say has the same pair for spoken lines). Away
-- with passers-by off or meaningless for this class, and unless the client
-- plainly says the nameplates are off (Speech.lua).
local function PlatesHidden()
	return not S().strangers or OnlyReachesGroup() or not ns.FriendlyPlatesOff()
end

-- The buff order (Core.lua, ns.WalkBuffs): a list of the class's buffs in the
-- order they are tried, each one moved up or down a place, and the way back to
-- Automatic. For a class with a choice to make -- two buffs or more on this
-- client -- and not while one spell is pinned, which is all that is considered
-- then (as the Kings switch's rule is).
local function OrderHidden()
	return ns.PinnedBuff() ~= nil or #(ns.GetClassBuffs(ns.caps.class) or {}) < 2
end

-- Who is picked in the list, for the buttons that move one: a state of the
-- window, like the never-offer list's.
local orderPicked

-- The class's buffs as the walk tries them: their keys, and a key's place (0
-- for none).
local function OrderKeys()
	local keys = {}
	for _, buff in ipairs(ns.BuffWalkOrder()) do
		keys[#keys + 1] = buff.key
	end
	return keys
end

local function OrderRank(key)
	for rank, k in ipairs(OrderKeys()) do
		if k == key then return rank end
	end
	return 0
end

-- The name as the switches above show it: the spell, what narrows who it goes
-- to, and that it is not learned.
local function OrderLabel(buff)
	local label = BuffLabel(buff)
	if not ns.IsBuffKnown(buff) then label = L["%s |cff808080(not learned)|r"]:format(label) end
	return label
end

local function OrderChoices()
	local values = {}
	for _, buff in ipairs(ns.BuffWalkOrder()) do
		values[buff.key] = OrderLabel(buff)
	end
	return values
end

-- The one picked, or the first when nothing is (or what was picked is gone).
local function OrderPick()
	if orderPicked and OrderRank(orderPicked) > 0 then return orderPicked end
	return OrderKeys()[1]
end

-- What the list is: how the walk goes about it, then whose order it is. Two
-- sentences for the two kinds of class, since a blessing and a Fortitude do not
-- cover somebody alike.
local function OrderNote()
	local text = ns.EXCLUSIVE_BUFFS[ns.caps.class]
		and L["Manners offers each person the first of these they can use, and leaves alone anybody who already wears one of yours."]
		or L["Manners offers each person the first of these they are missing."]
	local state
	if ns.HasBuffOrder() then
		state = L["Your own order is in use."]
	else
		local first = B().kingsFirst == true and ns.StrongestBuff()
		state = first and L["Following Automatic's order, with %s first."]:format(ns.BuffName(first))
			or L["Following Automatic's order."]
	end
	return text .. "\n|cffe6c45e" .. state .. "|r"
end

-- One step of the picked buff; the picked one stays picked, so a buff goes up
-- three places in three presses.
local function MoveOrder(step)
	local key = OrderPick()
	if key and ns.MoveBuff(key, step) then
		orderPicked = key
		restyleAndMacro()
		ns.RefreshOptionsDisplay()
	end
end

-- Four questions, top to bottom: what to cast, who it goes to (with the group
-- and raid settings under their own heading), who comes first, and who is
-- skipped or never offered.
function Page.BuildWhoTab()
	-- The dropdown in the order the per-spell switches are drawn, Automatic
	-- first: AceConfig would otherwise sort it by the translated names.
	local function BuffOrder()
		local keys = { "auto" }
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			keys[#keys + 1] = buff.key
		end
		return keys
	end

	-- A class with one spell to give has nothing to choose between, the rule
	-- AddBuffToggles already follows. Except where Automatic never reaches for
	-- that one spell: the dropdown is then the only way to offer it at all.
	local function OneBuff()
		local buffs = ns.GetClassBuffs(ns.caps.class) or {}
		return #buffs == 1 and not buffs[1].neverAuto
	end

	-- The class's own spells that "Skip players it does nothing for" holds
	-- back, by name, so the tooltip names what the switch acts on here.
	local function ManaOnlyNames()
		local names = {}
		for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
			if buff.manaOnly then names[#names + 1] = ns.BuffName(buff) end
		end
		return names
	end

	local function NoGroupBuffs()
		return not (ns.ClassHasGroupBuffs and ns.ClassHasGroupBuffs())
	end

	-- One line per reagent the group spells this character would cast eat, as
	-- the bags hold it now: a group buff that is never offered is most often a
	-- bag with no candles in it, and nothing else on the page says so.
	local function ReagentLines()
		local lines, seen = {}, {}
		for _, buff in ipairs(ns.CastableBuffs()) do
			local info = ns.BuffInfo(buff)
			local item = info and info.groupReagent
			if item and not seen[item] then
				seen[item] = true
				local name = (ns.ReagentName and ns.ReagentName(item)) or tostring(item)
				local count = ns.ReagentCount and ns.ReagentCount(item)
				if count == nil then
					lines[#lines + 1] = "|cff888888"
						.. L["%s: the game does not say how many you carry."]:format(name) .. "|r"
				elseif count > 0 then
					lines[#lines + 1] = L["%s: %d in your bags"]:format(name, count)
				elseif ns.ReagentWaived and ns.ReagentWaived(info, count) then
					-- Forever's Reagent Economy (GroupBuffs.lua).
					lines[#lines + 1] = L["%s: none needed -- the game lets you cast without it."]:format(name)
				else
					lines[#lines + 1] = "|cffff8080"
						.. L["%s: none in your bags, so group buffs are not offered."]:format(name)
						.. "|r"
				end
			end
		end
		if #lines == 0 then
			return "|cff888888" .. L["You have not learned a group version of your buffs yet."] .. "|r"
		end
		return table.concat(lines, "\n")
	end

	local who = {
		type = "group",
		name = TAB.who,
		order = 2,
		-- A hunter has "Myself" here and nothing else (ForOthersOnly).
		hidden = function() return not HasPrompt() end,
		args = {
			-------------------------------------------------- what to cast
			buffsHeader = { type = "header", name = L["What to cast"], order = 1 },
			choice = {
				type = "select",
				name = L["Buff to offer"],
				order = 2,
				values = BuffChoices,
				sorting = BuffOrder,
				-- Shown again for a pin, so there is a way back to Automatic.
				hidden = function() return OneBuff() and ns.PinnedBuff() == nil end,
				-- What the walk is honouring, rather than what is stored. The
				-- profile is shared, so a pin can be another class's, and read
				-- raw the dropdown was blank over a walk that was Automatic.
				get = function()
					local pin = ns.PinnedBuff()
					return pin and pin.key or "auto"
				end,
				set = bSet,
			},
			autoNote = {
				type = "description",
				order = 3,
				hidden = function() return ns.PinnedBuff() ~= nil end,
				-- One spell and it is castable: just which one. Anything else
				-- (not learned, switched off) keeps Automatic's warning.
				name = function()
					local castable = ns.CastableBuffs()
					if OneBuff() and #castable == 1 then
						return "|cff888888" .. L["You offer %s."]:format("|cffffffff" .. BuffLabel(castable[1]) .. "|r") .. "|r"
					end
					return AutoExplanation()
				end,
			},
			-- After the per-spell switches (4.1, 4.2, ...) and ahead of the mana
			-- switch: all of them decide what is cast. Only for a class whose list
			-- has a strongest buff to put first (a paladin's Kings on Classic Era,
			-- Burning Crusade and Forever), and not while one spell is pinned, which
			-- is all that is considered then, nor once the player has put the buffs
			-- in an order of their own (Buff order below): that is what it means then.
			kingsFirst = {
				type = "toggle",
				name = function()
					local buff = ns.StrongestBuff()
					return buff and L["%s first"]:format(ns.BuffName(buff)) or ""
				end,
				desc = function()
					local buff = ns.StrongestBuff()
					return buff and L["Offer %s to everybody before any other blessing. Somebody who already carries it from another paladin, or who cannot be given it, gets the blessing Automatic would have chosen instead; anybody carrying one of yours is left alone."]
						:format(ns.BuffName(buff)) or ""
				end,
				order = 4.8,
				width = "full",
				hidden = function() return ns.PinnedBuff() ~= nil or ns.StrongestBuff() == nil or ns.HasBuffOrder() end,
				get = function() return B().kingsFirst == true end,
				set = bSet,
			},
			-- The per-spell switches (AddBuffToggles) sit at 4.1, 4.2, ... and
			-- this one after them: all three decide what is cast. Only for a
			-- class with a mana-only spell, which is all it holds back.
			relevantOnly = {
				type = "toggle",
				name = L["Skip players it does nothing for"],
				desc = function()
					local names = ManaOnlyNames()
					if #names == 1 then
						return L["%s is not offered to players without mana, such as warriors and rogues."]:format(names[1])
					end
					return L["%s are not offered to players without mana, such as warriors and rogues."]
						:format(table.concat(names, ", "))
				end,
				order = 4.9,
				width = "full",
				hidden = function() return #ManaOnlyNames() == 0 end,
				get = fGet,
				set = fSet,
			},
			-- Below the per-spell switches, because when it is red the thing it
			-- is about is the dropdown at the top rather than the switches.
			pinNote = {
				type = "description",
				order = 5,
				fontSize = "medium",
				hidden = function() return ns.PinnedBuff() == nil end,
				name = function() return PinExplanation() end,
			},

			-------------------------------------------------- buff order
			-- A list of the class's buffs in the order they are tried, each with
			-- an arrow up and one down (the window draws these five as one piece,
			-- Window/WidgetsOrder.lua; the old dialog gets a dropdown and buttons).
			orderHeader = { type = "header", name = L["Buff order"], order = 6, hidden = OrderHidden },
			orderNote = {
				type = "description",
				order = 6.1,
				hidden = OrderHidden,
				name = OrderNote,
			},
			orderPick = {
				type = "select",
				name = L["Buff order"],
				order = 6.2,
				values = OrderChoices,
				sorting = OrderKeys,
				hidden = OrderHidden,
				get = OrderPick,
				set = function(_, value) orderPicked = value end,
			},
			orderUp = {
				type = "execute",
				name = L["Move up"],
				order = 6.3,
				hidden = OrderHidden,
				disabled = function() return OrderRank(OrderPick()) <= 1 end,
				func = function() MoveOrder(-1) end,
			},
			orderDown = {
				type = "execute",
				name = L["Move down"],
				order = 6.4,
				hidden = OrderHidden,
				disabled = function()
					local rank = OrderRank(OrderPick())
					return rank == 0 or rank >= #OrderKeys()
				end,
				func = function() MoveOrder(1) end,
			},
			-- Only once something has been moved: Automatic needs no way back.
			orderReset = {
				type = "execute",
				name = L["Back to Automatic"],
				order = 6.5,
				hidden = function() return OrderHidden() or not ns.HasBuffOrder() end,
				func = function()
					if ns.ClearBuffOrder() then
						restyleAndMacro()
						ns.RefreshOptionsDisplay()
					end
				end,
			},

			-------------------------------------------------- who it goes to
			sourcesHeader = { type = "header", name = L["Offer my buff to"], order = 10 },
			-- Every source off, and the only symptom is a prompt that never
			-- appears -- which is what a broken addon looks like.
			emptyWarning = {
				type = "description",
				order = 10.5,
				-- The same answer the page's red dot reads (Shared.lua).
				hidden = function() return not Page.NoSources() end,
				name = "|cffff8080"
					.. L["Nothing is ticked here, so the prompt will never appear."] .. "|r",
			},
			owed = {
				type = "toggle",
				name = L["People who buff me"],
				-- A function: a warrior's shout reaches only his group (his own
				-- subgroup in a raid on the older flavours), so a stranger who
				-- buffed him is turned down until they join.
				desc = function()
					if OnlyReachesGroup() then
						if ns.GroupMeansSubgroup() then
							return L["Offer a buff back to anyone who buffs you. Yours reaches only your own party (in a raid, your subgroup), so someone outside it is offered once they join."]
						end
						return L["Offer a buff back to anyone who buffs you. Yours reaches only your group, so someone outside it is offered once they join."]
					end
					return L["Offer a buff back to anyone who buffs you, in your group or not."]
				end,
				order = 11,
				width = "full",
				get = sGet,
				set = sSet,
			},
			group = {
				type = "toggle",
				name = L["My party and raid"],
				order = 12,
				width = "full",
				get = sGet,
				set = sSet,
			},
			strangers = {
				type = "toggle",
				name = L["Passers-by (players near me, not in my group)"],
				-- IterateUnits asks target, mouseover and focus before it
				-- touches a single nameplate.
				desc = L["Seen through nameplates, your target, focus and mouseover."],
				order = 13,
				width = "full",
				-- Hidden, not disabled: nothing on this page could ever make a
				-- shout reach a stranger.
				hidden = OnlyReachesGroup,
				get = sGet,
				set = sSet,
			},
			strangersPlatesNote = {
				type = "description",
				order = 13.05,
				hidden = PlatesHidden,
				name = "|cff888888"
					.. L["Turn on friendly nameplates so Manners can see passers-by: without them it sees almost nobody outside your group."]
					.. "|r",
			},
			strangersShowPlates = {
				type = "execute",
				name = L["Show friendly nameplates"],
				desc = L["The game's own setting, under Nameplates in its options, where you can turn it off again."],
				order = 13.06,
				hidden = PlatesHidden,
				-- The client refuses the setting in a fight.
				disabled = function() return InCombatLockdown() end,
				func = function()
					if ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end
				end,
			},
			strangersNote = {
				type = "description",
				order = 13.1,
				hidden = function() return not OnlyReachesGroup() end,
				name = "|cff888888"
					.. L["Everything you can offer is cast on yourself and reaches only your party, so there is nothing for passers-by."]
					.. "|r",
			},
			-- The two passer-by settings, right under the switch they narrow
			-- and greyed while it is off. Which signal is measuring, and how
			-- well, is on Diagnostics.
			proximity = {
				type = "select",
				name = L["Passers-by within"],
				desc = L["Only passers-by are measured, and only roughly: the game gives no exact distance."],
				order = 13.2,
				width = "full",
				values = ProximityChoices,
				sorting = ProximityOrder,
				hidden = OnlyReachesGroup,
				disabled = function() return not S().strangers end,
				get = fGet,
				set = fSet,
			},
			restingOnly = {
				type = "toggle",
				name = L["Only in cities and inns"],
				desc = L["Out in the world, passers-by are left alone; your group and people who buff you are offered anywhere."],
				order = 13.3,
				width = "full",
				hidden = OnlyReachesGroup,
				disabled = function() return not S().strangers end,
				get = fGet,
				set = fSet,
			},
			-- The source that reads chat. The full rule for what counts as
			-- asking lives in Requests.lua, which is the rule in code.
			asked = {
				type = "toggle",
				name = L["People who ask me in chat"],
				desc = L["For a minute, offer your buff to someone who asks for it (\"fort pls\"); off by default because chat is guesswork."],
				order = 14,
				width = "full",
				get = sGet,
				set = sSet,
			},
			-------------------------------------------------- myself
			-- You, last, as the queue ranks you: behind favours and requests,
			-- ahead of your group. Its own heading, with everything about you
			-- under the one switch: your group buff, then only your class's
			-- own buffs you know (AddOwnControls), then where. Hidden, not
			-- disabled, like the passer-by switch: nothing on this page makes
			-- a shout go on you alone.
			myselfHeader = { type = "header", name = L["Myself"], order = 15, hidden = NothingForSelf },
			self = {
				type = "toggle",
				name = L["Myself, when I'm missing my own buff"],
				desc = function()
					-- A hunter gives nobody anything, so his are the ones
					-- below alone.
					if #ns.KnownOwnFamilies() > 0 and #ns.SelfBuffs() == 0 then
						return L["Offer your own buffs to you when one is not up: the ones below. They are cast on you, your target is handed back, and nothing is said."]
					elseif #ns.KnownOwnFamilies() > 0 then
						return L["Offer your own buffs to you too, when one is not up: the ones below, and the buff you give others. They are cast on you, your target is handed back, and nothing is said."]
					end
					return L["Offer your own buff to you too, when you are missing it or, with top-ups on, it is running low. It is cast on you, your target is handed back, and nothing is said."]
				end,
				order = 15.1,
				width = "full",
				hidden = NothingForSelf,
				get = sGet,
				set = sSet,
			},
			-- The families sit at 15.2x (AddOwnControls), and this under them.
			ownCities = {
				type = "toggle",
				name = L["Also in cities and inns"],
				desc = L["Off: nothing is offered to you while the game calls you resting, in a city or an inn."],
				order = 15.9,
				width = "full",
				hidden = NothingForSelf,
				disabled = function() return not S().self end,
				get = function() return ns.db.profile.ownBuffs.inCities == true end,
				set = function(_, value)
					ns.db.profile.ownBuffs.inCities = value
					ns.Guard("own buff repaint", ns.Prompt.Refresh, ns.Prompt)
				end,
			},

			-------------------------------------------------- group and raid
			-- Group buffs (GroupBuffs.lua) only ever replace offers to your
			-- party, so they follow My party and raid. Shown to the classes that
			-- have a group version at all, learned yet or not.
			groupHeader = { type = "header", name = L["My group and raid"], order = 20 },
			groupBuffsUse = {
				type = "toggle",
				name = L["Use group buffs"],
				-- Worded for this class and the group spells it has learned.
				desc = function() return (ns.GroupBuffDescriptions()) end,
				order = 21,
				width = "full",
				hidden = NoGroupBuffs,
				disabled = function() return not S().group end,
				get = function() return ns.db.profile.groupBuffs.use end,
				-- The next scan (a fraction of a second) folds or unfolds the
				-- party, and the macro follows it.
				set = function(_, v) ns.db.profile.groupBuffs.use = v end,
			},
			groupBuffsAtLeast = {
				type = "range",
				name = L["When this many need it"],
				desc = function() return select(2, ns.GroupBuffDescriptions()) end,
				order = 22,
				min = 2,
				max = 5,
				step = 1,
				hidden = NoGroupBuffs,
				disabled = function() return not (S().group and ns.db.profile.groupBuffs.use) end,
				get = function() return ns.db.profile.groupBuffs.atLeast end,
				set = function(_, v) ns.db.profile.groupBuffs.atLeast = math.floor(v) end,
			},
			reagentNote = {
				type = "description",
				order = 22.5,
				hidden = function()
					return NoGroupBuffs() or not (S().group and ns.db.profile.groupBuffs.use)
				end,
				-- Guarded: a `name` is read by AceConfig with nothing around
				-- it, and an item API that throws must not take the page down.
				name = function()
					local ok, text = pcall(ReagentLines)
					return ok and text or ""
				end,
			},
			skipRaidGroups = {
				type = "multiselect",
				name = L["Raid groups I buff"],
				-- Somebody told "groups 1 to 4" should be able to untick the
				-- rest and forget about it.
				desc = L["In a raid, only these groups are offered your buff; people who buff you or ask are offered anyway."],
				order = 23,
				values = RaidGroupChoices,
				disabled = function() return not S().group end,
				-- Stored as the groups switched off, so a new profile buffs all
				-- eight and the box shows them ticked.
				get = function(_, group) return F().skipRaidGroups[group] ~= true end,
				set = function(_, group, on)
					F().skipRaidGroups[group] = (not on) or nil
				end,
			},

			-------------------------------------------------- who comes first
			-- Not a source: everybody here is already on the list by one of the
			-- sources above. This decides who reaches the top of it.
			firstHeader = { type = "header", name = L["Who comes first"], order = 30 },
			target = {
				type = "toggle",
				name = L["My target first"],
				-- Always offer (When to offer) reads nobody's buffs, so there is
				-- never a reading to promote a target on. The switch greys out
				-- then, and says why only while it is grey.
				desc = function()
					local text = L["Your target goes ahead of everyone when the game can see they lack the buff."]
					if F().whenBuffed == "always" then
						text = text .. "\n\n"
							.. L["Greyed out while |cffffd100Always offer|r is chosen on %s: nothing is read then."]:format(TAB.when)
					end
					return text
				end,
				order = 31,
				width = "full",
				disabled = function() return F().whenBuffed == "always" end,
				get = prGet,
				set = prSet,
			},
			friends = {
				type = "toggle",
				name = L["Friends and guildmates first"],
				-- Inside a kind of offer and never across one, which is what the
				-- sort does; see BuildQueue.
				desc = L["Only changes the order; nobody is added or left out."],
				order = 32,
				width = "full",
				get = prGet,
				set = prSet,
			},
			readyCheck = {
				type = "toggle",
				name = L["My group first at a ready check"],
				desc = L["From a ready check until the pull, group members missing your buff go first."],
				order = 33,
				width = "full",
				get = prGet,
				set = prSet,
			},
			revived = {
				type = "toggle",
				name = L["Group members just revived first"],
				desc = L["For two minutes after someone is brought back, they go first if they lack your buff."],
				order = 34,
				width = "full",
				get = prGet,
				set = prSet,
			},

			-------------------------------------------------- who to skip
			skipHeader = { type = "header", name = L["Who to skip"], order = 40 },
			minLevel = {
				type = "range",
				name = L["Skip players below level"],
				desc = L["Someone known only by name is offered anyway."],
				order = 41,
				min = 1,
				-- This client's level cap, as the repair has it (Core.lua):
				-- 70 on Burning Crusade, 90 on Mists and retail. A number
				-- when the tab is built, which AceConfig requires.
				max = ns.MaxPlayerLevel(),
				step = 1,
				get = fGet,
				set = fSet,
			},
			requireInRange = {
				-- The label is the promise: only a known out-of-range is hidden.
				type = "toggle",
				name = L["Skip players out of range"],
				desc = L["If the game cannot tell the range they are still offered."],
				order = 42,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- For everybody, a favour owed included: see "flagged for PvP" in
			-- Queue.lua. The exception, and the countdown that is no
			-- exception, are what a player would ask about, so they are in
			-- the tooltip.
			skipPvP = {
				type = "toggle",
				name = L["Skip players flagged for PvP"],
				desc = L["Buffing somebody flagged for PvP flags you too. Ignored while you are flagged yourself, as in a battleground, but not while your own flag is running out."],
				order = 43,
				width = "full",
				get = fGet,
				set = fSet,
			},
			-- Asked for by a player: see SelfServed in Queue.lua.
			skipSameClass = {
				type = "toggle",
				name = L["Skip my own class when they can cast it too"],
				desc = L["Somebody of your class can give themselves your buff, so they are left out -- unless they are too low a level for the rank you cast, and then they still get yours. People who buffed you, asked or you targeted are always offered."],
				order = 43.5,
				width = "full",
				get = fGet,
				set = fSet,
			},

			-------------------------------------------------- never offer
			neverHeader = { type = "header", name = L["Never offer"], order = 50 },
			neverNote = {
				type = "description",
				order = 51,
				fontSize = "medium",
				name = function()
					local count = #ns.NeverList()
					if count == 0 then
						return L["Nobody is on the list. Shift-right-click the prompt to add the person it shows, or type a name below."]
					end
					-- The favour exception (STATUS.md) is said every time the list
					-- is, rather than in a tooltip nobody hovers.
					local text = count == 1
						and L["One person is on the list. They are never offered anything as a passer-by or as a member of your group."]
						or L["%d people are on the list. They are never offered anything as passers-by or as members of your group."]:format(count)
					return text .. "\n\n"
						.. L["Somebody on it who buffs you is still offered the favour back. Shift-right-click them on the prompt to let that favour go."]
				end,
			},
			neverAdd = {
				type = "input",
				name = L["Add a name"],
				desc = L["Type it as the prompt shows it and press Enter."],
				order = 52,
				width = "full",
				-- Always empty: it is a box to type into, not a setting with a
				-- value to show back.
				get = function() return "" end,
				set = function(_, value) ns.PutOnNeverList(value, true) end,
			},
			neverPick = {
				type = "select",
				name = L["Pick a name"],
				order = 53,
				values = NeverChoices,
				disabled = function() return #ns.NeverList() == 0 end,
				-- Only somebody still on the list: the pick outlives a removal
				-- made from chat.
				get = function()
					if neverPicked and ns.IsNeverOffered(neverPicked) then return neverPicked end
					return nil
				end,
				set = function(_, value) neverPicked = value end,
			},
			neverRemove = {
				type = "execute",
				name = L["Remove from list"],
				order = 54,
				disabled = function()
					return not (neverPicked and ns.IsNeverOffered(neverPicked))
				end,
				func = function()
					local name = neverPicked and ns.AllowAgain(neverPicked)
					neverPicked = nil
					if name then
						ns.addon:Print(L["|cffffffff%s|r can be offered again."]:format(name))
					end
				end,
			},
			neverClear = {
				type = "execute",
				name = L["Clear the list"],
				order = 55,
				disabled = function() return #ns.NeverList() == 0 end,
				confirm = true,
				confirmText = L["Take everybody off the never-offer list?"],
				func = function()
					ns.ClearNeverList()
					neverPicked = nil
				end,
			},
		},
	}
	AddBuffToggles(who.args)
	AddOwnControls(who.args)
	-- Last, over everything above and the per-spell switches alike.
	ForOthersOnly(who.args)
	return who
end
