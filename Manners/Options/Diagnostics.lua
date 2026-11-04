-- Manners -- options: the Diagnostics tab.

local _, ns = ...
local L = ns.L
local Page = ns.OptionsPage
local B, HasClassBuffs, OnlyReachesGroup, TAB = Page.B, Page.HasClassBuffs, Page.OnlyReachesGroup, Page.TAB

-- Everything somebody would otherwise be asked for twice, in one block that can
-- be selected and pasted. No colour codes: this is written to be quoted
-- somewhere that is not a chat frame.
local function BugReport()
	local lines = { ("Manners %s"):format(tostring(ns.BUILD)) }

	-- Guarded: this is read from a `get`, which nothing wraps, and must not take
	-- the page down while somebody is reporting a bug.
	local ok, version, build, _, toc = pcall(GetBuildInfo)
	if ok and version then
		lines[#lines + 1] = ("client %s (%s), interface %s")
			:format(tostring(version), tostring(build), tostring(toc))
	end

	local caps = ns.caps
	lines[#lines + 1] = ("class %s | secrets %s | auras secret now %s | nameplates %s")
		:format(tostring(caps.class), tostring(caps.hasSecrets),
			tostring(caps.aurasSecretNow), tostring(caps.namePlates))
	-- Which spell tables this client was handed, so a spell never offered can be
	-- told from one that does not exist on the reporter's client.
	lines[#lines + 1] = ("buff data %s%s"):format(tostring(ns.BUFFS_SOURCE),
		ns.BUFFS_MISSING and (" -- " .. tostring(ns.BUFFS_MISSING)) or "")

	for _, buff in ipairs(ns.GetClassBuffs(caps.class) or {}) do
		local info = ns.BuffInfo(buff)
		lines[#lines + 1] = ("  %-12s known=%s readable=%s off=%s"):format(
			buff.key,
			tostring(info and info.known),
			tostring(info and info.readable),
			tostring(B().skip[buff.key] == true))
		if info and info.unresolved and #info.unresolved > 0 then
			lines[#lines + 1] = ("    no such spell on this client: %s"):format(
				table.concat(info.unresolved, ", "))
		end
		-- The group version the prompt would cast, and the reagent it would
		-- eat as the bags hold it now: "never offers the group buff" is most
		-- often answered here.
		if info and info.groupRank then
			local count = ns.ReagentCount and ns.ReagentCount(info.groupReagent)
			-- Forever's Reagent Economy, as GroupBuffs.lua reads it.
			local waived = ns.ReagentWaived and ns.ReagentWaived(info, count)
			lines[#lines + 1] = ("    group spell %s, reagent %s x%s%s"):format(
				tostring(info.groupRank), tostring(info.groupReagent), tostring(count),
				waived and " (waived: the client says it is usable without)" or "")
		end
	end

	-- The settings that change what it does, rather than how it looks. A report
	-- that leaves these out is a report about the defaults. The /thank is one:
	-- with it on, somebody buffing you is noticed even with owed off.
	local db = ns.db.profile
	lines[#lines + 1] = ("enabled=%s buff=%s sources owed/group/strangers/self=%s/%s/%s/%s"
		.. " whenBuffed=%s targetFirst=%s keepDebts=%s thank=%s"):format(
		tostring(db.enabled), tostring(db.buff.choice),
		tostring(db.sources.owed), tostring(db.sources.group), tostring(db.sources.strangers),
		tostring(db.sources.self),
		tostring(db.filters.whenBuffed), tostring(db.priority.target),
		tostring(db.timing.keepDebts), tostring(db.prompt.thankEmote))
	-- "Myself": where, and per family you know its pick and the one last up
	-- (key=pick/last), which is what Automatic reads.
	local picks = {}
	local memory = type(ns.db.char) == "table" and ns.db.char.ownLast
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		picks[#picks + 1] = ("%s=%s/%s"):format(family.key, tostring((ns.OwnPick(family))),
			tostring(type(memory) == "table" and memory[family.key] or nil))
	end
	lines[#lines + 1] = ("own inCities=%s %s"):format(tostring(db.ownBuffs.inCities),
		#picks > 0 and table.concat(picks, " ") or "none known")
	-- A mage's scrolls in the bags, each with whether it can be used now
	-- (Core.lua, ScrollReady): a scroll never offered is most often a level
	-- or a weapon it does not fit.
	local scrolls = {}
	for _, family in ipairs(ns.KnownOwnFamilies()) do
		for _, spell in ipairs(family.scroll and family.spells or {}) do
			local ready, why = ns.ScrollReady(spell)
			if why ~= "bags" then
				scrolls[#scrolls + 1] = ("%s=%s"):format(spell.key, ready and "ready" or tostring(why))
			end
		end
	end
	if #scrolls > 0 then lines[#lines + 1] = "scrolls " .. table.concat(scrolls, " ") end
	-- Who is ordered and who is held back: "my friend is never offered" is most
	-- often answered by the last number here.
	lines[#lines + 1] = ("friendsFirst=%s restingOnly=%s skipPvP=%s neverOffered=%d"):format(
		tostring(db.priority.friends), tostring(db.filters.restingOnly),
		tostring(db.filters.skipPvP), #ns.NeverList())
	lines[#lines + 1] = ("groupBuffs=%s atLeast=%s"):format(
		tostring(db.groupBuffs.use), tostring(db.groupBuffs.atLeast))
	-- The dungeon and raid settings, each of which leaves people out or moves
	-- them up: the raid groups as the ones switched off.
	local skipped = {}
	for group = 1, 8 do
		if db.filters.skipRaidGroups[group] then skipped[#skipped + 1] = tostring(group) end
	end
	lines[#lines + 1] = ("manaFloor=%s readyCheckFirst=%s revivedFirst=%s raidGroupsOff=%s"):format(
		tostring(db.filters.manaFloor), tostring(db.priority.readyCheck),
		tostring(db.priority.revived), #skipped > 0 and table.concat(skipped, ",") or "none")

	local scan = ns.auraScan
	lines[#lines + 1] = ("own buffs: %s read, baseline %s, primed=%s, doubt=%s"):format(
		tostring(scan.read), tostring(scan.held), tostring(scan.primed), tostring(scan.doubt))

	-- The second favour source, left out entirely on a client with no combat
	-- log rather than reported as zeroes.
	if caps.combatLog then
		local log = ns.logScan
		lines[#lines + 1] = ("combat log: armed=%s, %s seen, %s filed"):format(
			tostring(log.armed), tostring(log.applied), tostring(log.noted))
	end

	if #ns.errors == 0 then
		lines[#lines + 1] = "errors: none this session"
	else
		-- How many have happened, then how many are still here to read: the
		-- ring holds thirty, so its length is not the count.
		lines[#lines + 1] = ("errors: %d this session (%d kept), last five:")
			:format(ns.errorCount or #ns.errors, #ns.errors)
		for i = math.max(1, #ns.errors - 4), #ns.errors do
			local e = ns.errors[i]
			lines[#lines + 1] = ("  %s %s -- %s"):format(
				tostring(e.at), tostring(e.where), tostring(e.err))
		end
	end

	return table.concat(lines, "\n")
end

-- What this client allows, what has broken, and a bug report.
function Page.BuildDiagnosticsTab()
	return {
		type = "group",
		name = TAB.diagnostics,
		order = 7,
		args = {
			-- Lines printed to your own chat frame, never said aloud: the
			-- header says so, so it does not read as an addon that talks
			-- to other players. The everyday switch, Tell me in chat, is on
			-- Start here; this one is for working out a failed cast.
			chatHeader = { type = "header", name = L["Messages in chat"], order = 1 },
			debugClicks = {
				type = "toggle",
				name = L["Log every click (noisy)"],
				desc = L["Prints what the prompt held and what the game did, to work out why a cast failed."],
				order = 3,
				width = "full",
				get = function() return ns.db.profile.debugClicks end,
				set = function(_, v) ns.db.profile.debugClicks = v end,
			},

			capsHeader = { type = "header", name = L["What Manners can see"], order = 10 },
			diag = {
				type = "description",
				order = 11,
				fontSize = "medium",
				hidden = function() return not HasClassBuffs() end,
				name = function()
					-- The class is the client's own token, MAGE and the
					-- like; shown in the player's language where the
					-- client names it, and as the token where it does not.
					local class = ns.caps.class
					local names = _G.LOCALIZED_CLASS_NAMES_MALE
					local shown = (names and class and names[class]) or class
					local lines = { L["Class: |cffffffff%s|r"]:format(tostring(shown)) .. "\n" }
					for _, buff in ipairs(ns.GetClassBuffs(ns.caps.class) or {}) do
						local info = ns.BuffInfo(buff)
						-- Each field is one key with its label, so the
						-- translator sees what "yes" or "blocked" answers
						-- and can make the words agree.
						lines[#lines + 1] = ("|cffffffff%s|r  --  %s   %s"):format(
							(info and info.name) or buff.key,
							(info and info.known) and L["learned: |cff00ff00yes|r"]
								or L["learned: |cff808080no|r"],
							(info and info.readable) and L["can see who has it: |cff00ff00yes|r"]
								or L["can see who has it: |cffff8080no|r"])
						-- Manners being wrong about the game, rather than
						-- the game withholding something. "Never offer"
						-- only where no rank resolves: a missing group id
						-- (Arcane Brilliance) costs only the check of
						-- whether somebody is wearing it.
						if info and info.unresolved and #info.unresolved > 0 then
							local missing = {}
							for _, id in ipairs(info.unresolved) do missing[id] = true end
							local rankResolves = false
							for _, id in ipairs(buff.ranks) do
								if not missing[id] then rankResolves = true end
							end
							if not info.known and not rankResolves then
								lines[#lines + 1] = "|cffff4040    "
									.. L["this client has never heard of spell %s, so Manners will never offer this one. That is a mistake in Manners -- please report it."]
										:format(table.concat(info.unresolved, ", "))
									.. "|r"
							else
								lines[#lines + 1] = "|cffff4040    "
									.. L["this client doesn't know spell %s, so somebody already carrying that version may be offered this anyway. That is a mistake in Manners -- please report it."]
										:format(table.concat(info.unresolved, ", "))
									.. "|r"
							end
						end
					end
					lines[#lines + 1] = "\n|cff888888"
						.. L["Where Manners cannot see a buff, people are still offered, but some may already have it."]
						.. "|r"
					return table.concat(lines, "\n")
				end,
			},
			-- "Myself": what holds it back and each of your own buffs, in
			-- the words /manners debug uses (ns.MyselfLines), since "why am I
			-- not reminded" is asked here as often as there.
			ownDiag = {
				type = "description",
				order = 11.7,
				fontSize = "medium",
				hidden = function() return #ns.MyselfLines(GetTime()) == 0 end,
				name = function()
					return "|cffffffff" .. L["Myself"] .. "|r\n" .. table.concat(ns.MyselfLines(GetTime()), "\n")
				end,
			},
			-- How long each of your buffs lasts and when a top-up of it is due,
			-- in the words /manners debug uses (ns.LeadLines): the lead is
			-- worked out per buff, so "why did it come back now" or "why not
			-- yet" is answered here.
			leadDiag = {
				type = "description",
				order = 11.6,
				fontSize = "medium",
				hidden = function() return #ns.LeadLines() == 0 end,
				name = function()
					return "|cffffffff" .. ns.LeadHeading() .. "|r\n" .. table.concat(ns.LeadLines(), "\n")
				end,
			},
			-- Who "Skip players flagged for PvP" is holding back, in the
			-- words /manners debug uses (ns.PvPLines): somebody missing
			-- from the prompt for it has nothing else on screen to say why.
			-- A scan of its own, since the page is not repainted by one; one
			-- a paint, since in a battleground crowd a scan is a whole
			-- queue. `hidden` runs it -- whatever draws the line asks that
			-- first -- and the text reads what the scan left.
			pvpDiag = {
				type = "description",
				order = 11.8,
				fontSize = "medium",
				hidden = function() return #ns.PvPLines(true) == 0 end,
				name = function()
					return "|cffffffff" .. L["Flagged for PvP"] .. "|r\n" .. table.concat(ns.PvPLines(), "\n")
				end,
			},
			-- What is measuring how near a passer-by is, and how often it
			-- answers: a filter that has quietly stopped measuring looks
			-- the same as nobody being nearby. The only place it is shown.
			proximityDiag = {
				type = "description",
				order = 12,
				fontSize = "medium",
				hidden = OnlyReachesGroup,
				name = function()
					return "|cff888888"
						.. L["Passer-by distance: %s"]:format(tostring(ns.ProximitySummary()))
						.. "|r"
				end,
			},
			noDiag = {
				type = "description",
				order = 11.5,
				fontSize = "medium",
				hidden = HasClassBuffs,
				name = "|cffff8080"
					.. L["Nothing to report: this character has no buffs it can put on another player."]
					.. "|r",
			},

			-- What ns.Guard caught, on the page where somebody is looking
			-- when nothing works.
			errorsHeader = { type = "header", name = L["Errors this session"], order = 20 },
			errorList = {
				type = "description",
				order = 21,
				fontSize = "medium",
				hidden = function() return #ns.errors == 0 end,
				name = function()
					local lines = {}
					for i = math.max(1, #ns.errors - 4), #ns.errors do
						local e = ns.errors[i]
						lines[#lines + 1] = ("|cff808080%s|r %s -- |cffff8080%s|r"):format(
							tostring(e.at), tostring(e.where), tostring(e.err))
					end
					-- The count, not the ring's length: the ring holds thirty.
					if #ns.errors > 5 then
						-- Two whole sentences, and the command an argument:
						-- it is what the player types, in any language.
						local total = ns.errorCount or #ns.errors
						local text
						if total > #ns.errors then
							text = L["(%d in all this session, %d kept -- |cffffd100%s|r)"]
								:format(total, #ns.errors, "/manners errors")
						else
							text = L["(%d in all this session -- |cffffd100%s|r)"]
								:format(total, "/manners errors")
						end
						lines[#lines + 1] = "|cff888888" .. text .. "|r"
					end
					return table.concat(lines, "\n")
				end,
			},
			noErrors = {
				type = "description",
				order = 21.5,
				fontSize = "medium",
				hidden = function() return #ns.errors > 0 end,
				name = L["Nothing has gone wrong this session."],
			},

			reportHeader = { type = "header", name = L["Reporting a bug"], order = 30 },
			buildNote = {
				type = "description",
				order = 31,
				fontSize = "medium",
				-- The first question on every bug report.
				name = function()
					return ("Manners |cffffffff%s|r"):format(tostring(ns.BUILD))
				end,
			},
			copyReport = {
				type = "execute",
				name = function() return Page.reportOpen and L["Hide the report"] or L["Copy for a bug report"] end,
				desc = L["Opens a box with the build, what this client allows, the settings that matter and anything that has broken, ready to copy."],
				order = 32,
				func = function()
					Page.reportOpen = not Page.reportOpen
					ns.RefreshOptionsDisplay()
				end,
			},
			report = {
				type = "input",
				name = "",
				order = 33,
				multiline = 14,
				width = "full",
				hidden = function() return not Page.reportOpen end,
				get = function() return BugReport() end,
				-- Read-only in the only way AceConfig offers: anything
				-- typed in is discarded.
				set = function() end,
			},
			-- /manners selftest's report (Selftest.lua), shown by
			-- ns.ShowSelftestBox until the window shuts. Read-only, as above.
			selftest = {
				type = "input",
				name = "",
				order = 34,
				multiline = 14,
				width = "full",
				hidden = function() return Page.selftestText == nil end,
				get = function() return Page.selftestText or "" end,
				set = function() end,
			},
		},
	}
end
