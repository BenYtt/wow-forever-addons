-- Manners -- options: the What I say tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local P, SP, spGet = Page.P, Page.SP, Page.spGet
local spSet, HasClassBuffs, TAB = Page.spSet, Page.HasClassBuffs, Page.TAB

-- The controls a class with nothing to give keeps: the /thank answers being
-- buffed, which happens to a rogue too, and the header it sits under. Every
-- other control on the tab is about the line said with a cast.
local THANKS_ONLY = { speechHeader = true, thankEmote = true }

-- What I say: the social replies to a buff, the /thank and the line that goes
-- out with a cast. The options window leads the page with Start here's voice
-- choice (general.quickVoice), so the page needs no intro pointing at it.
function Page.BuildSpeechTab()
	-- The dropdown's own names for two sets, where the set's label alone does
	-- not say what it is. Every other set keeps the label ns.PHRASE_SETS gives.
	local SET_LABEL = {
		roleplay = L["Azeroth (general)"],
		-- The same words as Start here's quick choice for it.
		incharacter = L["In character (fits your race and class)"],
	}
	-- Loading a set: what picking it in the dropdown does, and what Go back to
	-- In character does without asking.
	local function loadSet(value)
		SP().presetChoice = value
		SP().phrases = ns.PhraseSetText(value) or SP().phrases
		ns.Prompt:InvalidateMacro()
		ns.addon:Print(L["loaded the %s lines."]:format(
			ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label or value))
	end
	local function speechOff() return not SP().enabled end
	local function inCharacter() return ns.InCharacter and ns.InCharacter.Active(SP()) end
	-- Shown to every class: a hunter or a rogue has the /thank alone on it
	-- (THANKS_ONLY, below).
	local tab = {
		type = "group",
		name = TAB.click,
		order = 4,
		args = {
			-- Everything on this tab is a line in the macro, a secure
			-- attribute the fight has frozen: the macro is rebuilt when the
			-- fight ends, and until then a press runs the old one.
			combatNotice = {
				type = "description",
				order = 0.5,
				fontSize = "medium",
				hidden = function() return not InCombatLockdown() end,
				name = "|cffffd100" .. L["In combat: changes here apply once the fight ends."] .. "|r\n",
			},

			speechHeader = { type = "header", name = L["Thanks and speech"], order = 10 },
			-- The other answer to a favour arriving. Its own get and set:
			-- pSet restyles the prompt, and this changes nothing on it. Live
			-- with People who buff me off: either switch has the favour noticed.
			thankEmote = {
				type = "toggle",
				name = L["/thank people who buff me"],
				desc = L["Everyone near you sees it; never in combat or instances, and at most once per person every five minutes."],
				order = 11,
				width = "full",
				get = function() return P().thankEmote end,
				set = function(_, v) P().thankEmote = v end,
			},
			enabled = {
				type = "toggle",
				name = L["Say a line when I buff someone"],
				order = 12,
				width = "full",
				get = spGet,
				set = spSet,
			},
			channel = {
				type = "select",
				name = L["Where to say it"],
				desc = L["Whisper them sends it only to the person you buff."],
				order = 13,
				disabled = speechOff,
				values = {
					SAY = L["Say"],
					WHISPER = L["Whisper them"],
					EMOTE = L["Emote"],
					PARTY = L["Party"],
					RAID = L["Raid"],
					YELL = L["Yell"],
				},
				sorting = { "SAY", "WHISPER", "EMOTE", "PARTY", "RAID", "YELL" },
				get = spGet,
				set = spSet,
			},
			onlyWhenReturning = {
				type = "toggle",
				name = L["Only when I buff someone back"],
				desc = L["Off, you also speak when you buff someone first."],
				order = 14,
				width = "full",
				disabled = speechOff,
				get = spGet,
				set = spSet,
			},

			-- A line goes out only to somebody a token names (Press.lua,
			-- HoldLine), and with the game's friendly nameplates off most
			-- passers-by have none, so their lines are held back unseen. Said
			-- only while that is so, and not in /party or /raid, where no line
			-- goes to a passer-by at all (ns.ChannelOpen, asked of somebody
			-- outside your group); the setting changes only on a click.
			platesNote = {
				type = "description",
				order = 14.5,
				hidden = function() return speechOff() or not ns.FriendlyPlatesOff() or not ns.ChannelOpen({}) end,
				name = "|cff888888" .. L["Turn on friendly nameplates so Manners can tell when strangers are in range to hear you."] .. "|r",
			},
			showPlates = {
				type = "execute",
				name = L["Show friendly nameplates"],
				desc = L["The game's own setting, under Nameplates in its options, where you can turn it off again."],
				order = 14.6,
				hidden = function() return speechOff() or not ns.FriendlyPlatesOff() or not ns.ChannelOpen({}) end,
				-- The client refuses the setting in a fight.
				disabled = function() return InCombatLockdown() end,
				func = function()
					if ns.ShowFriendlyPlates() then ns.RefreshOptionsDisplay() end
				end,
			},

			-- In place of the Lines section while nothing is said.
			linesOff = {
				type = "description",
				order = 19.5,
				hidden = function() return not speechOff() end,
				name = "\n|cff888888" .. L["Tick Say a line to choose what you say."] .. "|r\n",
			},
			phrasesHeader = { type = "header", name = L["Lines"], order = 20, hidden = speechOff },
			preset = {
				type = "select",
				name = L["Line set"],
				desc = L["Replaces the lines below."],
				order = 21,
				hidden = speechOff,
				-- It overwrites hand-written lines with no undo.
				confirm = function(_, value)
					return L["Replace everything in the box below with the %s lines?"]:format(
						(ns.PHRASE_SETS[value] and ns.PHRASE_SETS[value].label)
							or tostring(value))
				end,
				values = function()
					local out = {}
					for _, key in ipairs(ns.PHRASE_SET_ORDER) do
						out[key] = SET_LABEL[key] or ns.PHRASE_SETS[key].label
					end
					return out
				end,
				sorting = function() return ns.PHRASE_SET_ORDER end,
				-- Blank once the box has been edited. AceGUI's dropdown only
				-- fires when the item clicked becomes checked, so a set shown
				-- as chosen could not be picked again to reload it.
				get = function()
					local choice = SP().presetChoice or "roleplay"
					if SP().phrases == ns.PhraseSetText(choice) then return choice end
					-- In character is untouched on every character sharing the
					-- profile, though each one's examples differ.
					if ns.InCharacter and ns.InCharacter.Active(SP()) then return choice end
					return nil
				end,
				set = function(_, value) loadSet(value) end,
			},
			phrasesHelp = {
				type = "description",
				order = 22,
				hidden = speechOff,
				name = L["One line is picked at random. Placeholders: {name} their name, {buff} the spell."]
					.. "\n|cff888888"
					.. L["A line too long for a macro is skipped; Try a few shows what would go out."]
					.. "|r",
			},
			inCharacterNote = {
				type = "description",
				order = 22.5,
				hidden = function() return speechOff() or not inCharacter() end,
				name = function()
					-- The count first: the box holds a handful of examples, and a
					-- player took them for the whole set.
					return "\n|cffffd100" .. L["In character picks one of its %d lines when you click, to fit your race, faction, class and the moment. The box below shows only a few examples; editing it turns In character off."]
						:format(ns.InCharacter.Count()) .. "|r\n"
				end,
			},
			phrases = {
				type = "input",
				name = L["Your lines (one per line)"],
				order = 23,
				-- Tall enough for In character's examples, about 25 lines, to
				-- read without scrolling: at 10 rows a player saw a handful and
				-- took them for the whole set.
				multiline = 26,
				width = "full",
				hidden = speechOff,
				-- Typing over In character's examples makes them your own
				-- lines, and In character stops picking.
				confirm = function()
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						return L["Editing these turns In character off and uses only your lines. Continue?"]
					end
					return false
				end,
				-- In character shows the examples of whoever is logged in,
				-- whichever character's the shared profile was saved with.
				get = function(info)
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						return ns.PhraseSetText("incharacter")
					end
					return spGet(info)
				end,
				-- An empty box snaps back to the set the dropdown names, the
				-- way the First line does, since the load-time repair would
				-- refill it anyway: what the box shows is what is kept.
				set = function(info, value)
					if type(value) ~= "string" or value:match("^%s*$") then
						value = ns.PhraseSetText(SP().presetChoice) or ns.PhraseSetText("roleplay")
					end
					spSet(info, value)
				end,
			},
			-- The way back from edited lines to In character, which the
			-- dropdown cannot give: it shows the set still chosen as blank.
			backToInCharacter = {
				type = "execute",
				name = L["Go back to In character"],
				order = 23.5,
				hidden = function()
					return speechOff() or SP().presetChoice ~= "incharacter" or inCharacter()
				end,
				func = function() loadSet("incharacter") end,
			},
			roll = {
				type = "execute",
				name = L["Try a few lines"],
				desc = L["Prints sample lines in your chat; only you see them."],
				order = 24,
				hidden = speechOff,
				func = function()
					-- In character speaks differently for each reason, so
					-- it rolls one line per reason.
					if ns.InCharacter and ns.InCharacter.Active(SP()) then
						ns.InCharacter.Roll(L["Somebody"])
						return
					end
					-- reason "owed" so the sample survives the
					-- only-when-returning filter either way. The
					-- stand-in name is read in the lines printed, so it
					-- is in the player's language like the lines are.
					local somebody = L["Somebody"]
					local fake = {
						short = somebody,
						name = somebody,
						reason = "owed",
						buff = ns.ResolveBuff(true),
					}
					for _ = 1, 3 do
						-- The same budget the cast path measures, for a
						-- representative name.
						ns.addon:Print(ns.PickPhrase(fake, ns.PhraseBudget(fake))
							or "|cffff8080" .. L["(nothing -- speech off, or no usable lines)"] .. "|r")
					end
				end,
			},
			limits = {
				type = "description",
				order = 25,
				hidden = speechOff,
				name = "\n|cff888888"
					.. L["A line goes out only with a buff that can land: in range, ready to cast, and with the mana for it. When Manners cannot tell, the buff goes out without it. Line of sight cannot be checked."]
					.. "|r",
			},
		},
	}
	-- With nothing to give there is no cast for a line to go out with: every
	-- control but THANKS_ONLY's is hidden on top of its own rule, the fight
	-- notice too, since nothing left on the page waits for the fight to end.
	for key, control in pairs(tab.args) do
		if not THANKS_ONLY[key] then
			local own = control.hidden
			control.hidden = function(info)
				if not HasClassBuffs() then return true end
				if type(own) == "function" then return own(info) end
				return own
			end
		end
	end
	return tab
end
