---@type string, SkillUpNamespace
local addonName, ns = ...
local L = ns.L
ns.ReportTitle = L["SkillUp report"]

---@type SkillUpDefaults
local DEFAULTS = {
	showRowText = true,
	showSkill = false,
	showTooltip = true,
	recipeTooltip = "window", -- where the recipe tooltip goes: beside the Professions window, at the cursor, by the row
	detailsBar = true, -- the recipe tooltip's skill bar under the selected recipe, on the crafting page itself
	showCost = true,
	rowCost = "skillup", -- what a recipe row's money is: "skillup" (cost per skill-up) or "craft" (net per craft)
	craftValue = "vendor",
	valueGathered = false, -- a reagent you gather costs what it would sell for, not nothing
	sortMode = "blizzard",
	showTrainer = true,
	showRouteTab = true,
	showTracker = true,
	showGearTab = false,
	merchantButton = true, -- the merchant window's "Buy tracked reagents" button
	auctionSearch = true, -- the Professions window's reagent search while the auction house is open
	reagentTooltip = "route",
	gatherTooltip = true, -- a herb or ore node's and a skinnable corpse's required skill, coloured at yours
	collectModes = {}, -- ["Name-Realm"] = "gather" | "auction": where a reagent you could gather comes from
	showAllGear = {}, -- ["Name-Realm"] = true: the crafted gear view shows gear this character cannot make yet
	pinnedRecipes = {}, -- ["Name-Realm"] = { [recipeID] = priority }: most recently pinned wins
	skippedRecipes = {}, -- ["Name-Realm"] = { [recipeID] = true }: "Not this recipe", left out of every route
	whatsNew = true,
	suggestFamily = true, -- the quiet lines about my other Forever addons, where one would help (UI/ForeverFamily.lua)
	lastVersion = "", -- the version that last ran; "" before the first
	vendor = {}, -- [itemID] = copper per unit, observed at merchants
	-- [npcID] = { name, side, map, x, y, build, items = { [itemID] = true } }: vendors seen selling a reagent or scroll
	sellers = {},
	-- The client builds this install has run with, oldest first: a vendor stops being named two builds
	-- after the one it was seen on.
	builds = {},
	routeTargets = {}, -- [profession skill line] = target base skill
	learned = {}, -- ["Name-Realm"] = { [recipeID] = true }
	statsShare = true,
	observedRecipes = {}, -- ["Name-Realm"] = { ids = { [recipeID] = true }, eventUnix = latest observation }
	peerStats = {}, -- ["Name-Realm"] = peer rows for this character's guild and groups
	professionIDs = {}, -- [localized profession name] = skill line, seen with the profession open
	trackedProfessions = {}, -- [profession skill line] = true tracked, false stopped by hand, nil undecided
	trainer = {}, -- [skill line] = { [recipeID] = { fee, required base skill } }, recorded at trainers
	trainerRanks = {}, -- [skill line] = { [cap] = fee }: what a trainer charges for the rank ending at that cap
}

ns.DEFAULTS = DEFAULTS
ns.SORT_OPTIONS = {
	{ "blizzard", DEFAULT },
	{ "skill", L["Skill range start"] },
	{ "chance", L["Skill-up chance"] },
	{ "cost", L["Cheapest skill-up"] },
}
ns.CRAFT_VALUE_OPTIONS = {
	{ "none", L["Don't count it"] },
	{ "vendor", L["Vendor sell price"] },
	{ "auction", L["Auction price if higher"] },
}
-- Beside the window by default: next to the recipe row, the tooltip covered the reagents (#163).
ns.RECIPE_TOOLTIP_OPTIONS = {
	{ "window", L["Beside the Professions window"] },
	{ "cursor", L["At the cursor"] },
	{ "row", L["Next to the recipe"] },
}
-- Per craft also prices recipes that no longer give skill, to show which are worth crafting anyway.
ns.ROW_COST_OPTIONS = {
	{ "skillup", L["Per skill-up"] },
	{ "craft", L["Per craft"] },
}
ns.REAGENT_TOOLTIP_OPTIONS = {
	{ "off", OFF },
	{ "route", L["Tracked routes (Shift for all)"] },
	{ "full", L["Every recipe that uses it"] },
}
ns.TITLE = "SkillUp Forever"
-- The chat line after an update: one sentence for the release being tagged, the bold lead of one of its
-- CHANGELOG.md bullets (tests/core_spec.lua holds it to the newest entry).
ns.WHATS_NEW = L["Shift-clicking a recipe in the route reliably links it in chat."]

-- Classic difficulty colours, matching the retail recipe list's own palette.
ns.COLORS = {
	red = RED_FONT_COLOR or CreateColor(1, 0.1, 0.1),
	orange = DIFFICULT_DIFFICULTY_COLOR or CreateColor(1, 0.5, 0.25),
	yellow = FAIR_DIFFICULTY_COLOR or CreateColor(1, 1, 0),
	green = EASY_DIFFICULTY_COLOR or CreateColor(0.25, 0.75, 0.25),
	grey = TRIVIAL_DIFFICULTY_COLOR or CreateColor(0.5, 0.5, 0.5),
	unknown = GRAY_FONT_COLOR or CreateColor(0.6, 0.6, 0.6),
}

local LIVE_COLOR = {
	[Enum.TradeskillRelativeDifficulty.Optimal] = "orange",
	[Enum.TradeskillRelativeDifficulty.Medium] = "yellow",
	[Enum.TradeskillRelativeDifficulty.Easy] = "green",
	[Enum.TradeskillRelativeDifficulty.Trivial] = "grey",
}

---@param msg string
function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. ns.TITLE .. "|r " .. msg)
end

-- Forever's SavedVariables often fail to load (forever-bugs#34), so defaults
-- are always the base and whatever did load is merged over them.
local function LoadDB()
	local loaded = type(SkillUpForeverDB) == "table" and SkillUpForeverDB or {}
	-- Reagent tooltips were on or off before they had a compact mode.
	if loaded.showReagentTooltip == false then
		loaded.reagentTooltip = "off"
	end
	loaded.showReagentTooltip = nil
	-- Auction prices come from Auctionator now; drop what SkillUp's own scanner saved.
	loaded.priceDays, loaded.latestPrice = nil, nil
	loaded.scanAuctions, loaded.tracked, loaded.auctions, loaded.gatherFree = nil, nil, nil, nil
	-- Suggest companion addons became the shared Suggest my other Forever addons: turned off, it stays off.
	if loaded.companionHints == false and loaded.suggestFamily == nil then
		loaded.suggestFamily = false
	end
	loaded.companionHints = nil
	for key, value in pairs(DEFAULTS) do
		if type(loaded[key]) ~= type(value) then
			loaded[key] = type(value) == "table" and {} or value
		end
	end
	-- A vendor saved before builds were recorded is stamped with the build that upgrades it, so it is
	-- used for two more builds and then stops being named.
	local build = ns.ClientBuild()
	for _, seller in pairs(loaded.sellers) do
		if type(seller) == "table" and seller.build == nil then
			seller.build = build
		end
	end
	-- A choice the menu no longer offers (or a typo) goes back to its default.
	for key, options in pairs({
		craftValue = ns.CRAFT_VALUE_OPTIONS,
		sortMode = ns.SORT_OPTIONS,
		reagentTooltip = ns.REAGENT_TOOLTIP_OPTIONS,
		recipeTooltip = ns.RECIPE_TOOLTIP_OPTIONS,
	}) do
		local valid = false
		for _, option in ipairs(options) do
			valid = valid or option[1] == loaded[key]
		end
		if not valid then
			loaded[key] = DEFAULTS[key]
		end
	end
	-- Earlier versions saved a trainer row that showed no skill requirement as needing 0, which planned
	-- learning it at once; the bundled requirement stands in for those. A shown requirement that is no
	-- skill is forgotten, so /su trainers never reports it.
	for skillLine, recipes in pairs(loaded.trainer) do
		if type(skillLine) ~= "number" or type(recipes) ~= "table" then
			loaded.trainer[skillLine] = nil
		else
			for recipeID, seen in pairs(recipes) do
				if type(recipeID) ~= "number" or type(seen) ~= "table" or type(seen[2]) ~= "number" or seen[2] <= 0 then
					recipes[recipeID] = nil
				elseif seen[3] ~= nil and (type(seen[3]) ~= "number" or seen[3] <= 0) then
					seen[3] = nil
				end
			end
		end
	end
	-- Only a recipe ID saved as skipped is kept.
	for key, recipes in pairs(loaded.skippedRecipes) do
		if type(recipes) ~= "table" then
			loaded.skippedRecipes[key] = nil
		else
			for recipeID, skipped in pairs(recipes) do
				if type(recipeID) ~= "number" or skipped ~= true then
					recipes[recipeID] = nil
				end
			end
		end
	end
	for key, recipes in pairs(loaded.pinnedRecipes) do
		if type(key) ~= "string" or type(recipes) ~= "table" then
			loaded.pinnedRecipes[key] = nil
		else
			for recipeID, priority in pairs(recipes) do
				if
					type(recipeID) ~= "number"
					or recipeID <= 0
					or recipeID % 1 ~= 0
					or type(priority) ~= "number"
					or priority <= 0
					or priority % 1 ~= 0
					or (loaded.skippedRecipes[key] and loaded.skippedRecipes[key][recipeID])
				then
					recipes[recipeID] = nil
				end
			end
		end
	end
	-- A mode no longer saved, or a typo, reads as the default gather.
	for key, mode in pairs(loaded.collectModes) do
		if mode ~= "gather" and mode ~= "auction" then
			loaded.collectModes[key] = nil
		end
	end
	SkillUpForeverDB = loaded
	ns.db = loaded
end

---@return ForeverTrackerSettings
function ns.TrackerHostSettings()
	if type(ns.db.trackerHost) ~= "table" then
		ns.db.trackerHost = { attached = true, locked = false }
	end
	-- Lock defaults off, and a trackerHost saved before it existed simply gains the key.
	if type(ns.db.trackerHost.locked) ~= "boolean" then
		ns.db.trackerHost.locked = false
	end
	return ns.db.trackerHost
end

-- One chat line after an update, never on a first install. A dev checkout's version is
-- the packager's unfilled keyword, so it is left alone.
function ns.AnnounceUpdate()
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	if not (ns.db and version) or version:match("^@.+@$") then
		return
	end
	local last = ns.db.lastVersion
	ns.db.lastVersion = version
	if ns.db.whatsNew and last ~= "" and last ~= version then
		ns.Print(string.format(L["updated to %s. %s"], version, ns.WHATS_NEW))
	end
end

local loginEvents = CreateFrame("Frame")
loginEvents:RegisterEvent("PLAYER_LOGIN")
loginEvents:SetScript("OnEvent", function()
	ns.AnnounceUpdate()
end)

local KNOWN_SKILL_LINES = {}
for _, skillLine in pairs(ns.ProfessionSkillLines or {}) do
	KNOWN_SKILL_LINES[skillLine] = true
end

-- The skill line recipe data uses for a profession. Forever's profession APIs
-- report other IDs (GetProfessionInfo gave 8167, 8175, ...), so the name is the
-- key: the bundled enUS names, or the pairing seen when the profession was open.
local warned = {}

---@param name string?
---@param reported integer?
---@return integer?
function ns.ProfessionSkillLine(name, reported)
	local skillLine = ns.ProfessionSkillLines[name] or ns.db.professionIDs[name]
	if skillLine then
		return skillLine
	end
	if KNOWN_SKILL_LINES[reported] then
		return reported
	end
	-- A blank name is the client's answer while no profession is open, not a profession to report.
	if name and name ~= "" and not warned[name] then
		warned[name] = true
		ns.Print(string.format(L["can't identify the profession %s (%s); please report it."], name, tostring(reported)))
	end
end

-- Effective skill for difficulty purposes includes racial bonuses; the cap is
-- on base skill, and at the cap nothing can skill up whatever its colour.
---@return SkillUpContext?
function ns.SkillContext()
	local info = Professions and Professions.GetProfessionInfo()
	if not info or not info.skillLevel then
		return nil
	end
	local modifier = info.skillModifier or 0
	local base = C_TradeSkillUI.GetBaseProfessionInfo()
	return {
		skillLine = base and ns.ProfessionSkillLine(base.professionName, base.professionID),
		skill = info.skillLevel + modifier,
		base = info.skillLevel,
		modifier = modifier,
		max = info.maxSkillLevel,
		name = info.displayName,
		capped = info.maxSkillLevel and info.maxSkillLevel > 0 and info.skillLevel >= info.maxSkillLevel,
	}
end

-- The player's professions by skill line, secondary ones included. GetProfessions
-- leaves nil gaps for empty slots, so walk its full return count.
---@param professions table<integer, SkillUpProfession>
local function AddProfessions(professions, ...)
	for i = 1, select("#", ...) do
		local index = select(i, ...)
		if index then
			local name, icon, rank, maxRank, _, _, reported, modifier = GetProfessionInfo(index)
			local skillLine = ns.ProfessionSkillLine(name, reported)
			if skillLine then
				modifier = modifier or 0
				professions[skillLine] = {
					skillLine = skillLine,
					professionID = reported,
					name = name,
					icon = icon,
					base = rank,
					max = maxRank,
					modifier = modifier,
					skill = rank + modifier,
					capped = maxRank > 0 and rank >= maxRank,
				}
			end
		end
	end
end

---@return table<integer, SkillUpProfession>
function ns.PlayerProfessions()
	local professions = {}
	AddProfessions(professions, GetProfessions())
	return professions
end

-- This character's realm in the client's normalized form (no spaces or hyphens). GetNormalizedRealmName returns nil
-- early in loading, so it falls back to GetRealmName stripped the same way; nil when the client has neither yet.
---@return string?
function ns.NormalizedRealm()
	local realm = GetNormalizedRealmName()
	if not realm or realm == "" then
		realm = ((GetRealmName() or ""):gsub("[%s%-]", ""))
	end
	return realm ~= "" and realm or nil
end

-- This character's key in the account-wide saved variables, "Name-Realm". Nil while the client has no name or realm
-- for it yet: callers then read the defaults and save nothing.
---@return string?
function ns.CharacterKey()
	local name, realm = UnitName("player"), ns.NormalizedRealm()
	if not name or name == "" or not realm then
		return nil
	end
	return name .. "-" .. realm
end

-- The client's own build number, nil when it doesn't report one.
---@return string?
function ns.ClientBuild()
	local _, build = GetBuildInfo()
	return build and build ~= "" and build or nil
end

-- How many builds the client's history keeps. Two back is all a remembered vendor needs.
local BUILD_HISTORY = 4

-- The builds this install has run with, in order. A build is remembered once, and older ones fall off
-- the end. Called once at login.
function ns.NoteBuild()
	local build = ns.ClientBuild()
	if not build then
		return
	end
	local builds = ns.db.builds
	if builds[#builds] ~= build then
		builds[#builds + 1] = build
		while #builds > BUILD_HISTORY do
			table.remove(builds, 1)
		end
	end
end

-- Whether a vendor seen at its window is recent enough to name. It stays in use for the build it was
-- seen on and the next one, and is not used once two builds have gone by without seeing it.
---@param seller SkillUpSeller
---@return boolean
function ns.SellerFresh(seller)
	local current = ns.ClientBuild()
	local build = seller.build or current
	if not current or not build or build == current then
		return true
	end
	local builds = ns.db.builds
	for index = #builds, 1, -1 do
		if builds[index] == build then
			return #builds - index < 2
		end
	end
	return false
end

-- Where the routes take a reagent this character could gather or buy: "gather" prices it free,
-- "auction" buys it at a vendor or the auction house like any other.
---@return SkillUpCollectMode
function ns.CollectMode()
	local key = ns.CharacterKey()
	local mode = key and ns.db.collectModes[key]
	return mode == "auction" and "auction" or "gather"
end

---@param mode SkillUpCollectMode
function ns.SetCollectMode(mode)
	local key = ns.CharacterKey()
	if not key then
		return
	end
	ns.db.collectModes[key] = mode
	ns.Changed("settings")
end

-- Whether the crafted gear view lists gear this character cannot make yet. Off by default and kept
-- per character, like the collect mode.
---@return boolean
function ns.ShowAllGear()
	local key = ns.CharacterKey()
	return key ~= nil and ns.db.showAllGear[key] == true
end

---@param show boolean
function ns.SetShowAllGear(show)
	local key = ns.CharacterKey()
	if not key then
		return
	end
	ns.db.showAllGear[key] = show and true or nil
	ns.Changed("settings")
end

-- "Not this recipe": a recipe this character never wants suggested. The planner leaves it out of every route,
-- training and sub-craft, and Show again brings it back. Kept per character, like the collect mode.
---@param recipeID integer
---@return boolean
function ns.IsSkipped(recipeID)
	local key = ns.CharacterKey()
	local skipped = ns.db and key and ns.db.skippedRecipes[key]
	return skipped ~= nil and skipped[recipeID] == true
end

---@param recipeID integer
---@param skip boolean
function ns.SetSkipped(recipeID, skip)
	local key = ns.CharacterKey()
	if not key then
		return
	end
	local skipped = ns.db.skippedRecipes[key] or {}
	skipped[recipeID] = skip and true or nil
	ns.db.skippedRecipes[key] = next(skipped) and skipped or nil
	if skip and ns.db.pinnedRecipes[key] then
		ns.db.pinnedRecipes[key][recipeID] = nil
	end
	ns.Changed("settings")
end

---@param recipeID integer
---@return integer
function ns.PinPreference(recipeID)
	local key = ns.CharacterKey()
	return key and ns.db.pinnedRecipes[key] and ns.db.pinnedRecipes[key][recipeID] or 0
end

---@param skillLine integer?
---@return {recipeID: integer, name: string}[]
function ns.PinnedRecipes(skillLine)
	local list = {}
	local key = ns.CharacterKey()
	for recipeID in pairs(key and ns.db.pinnedRecipes[key] or {}) do
		local recipe = ns.RecipeData[recipeID]
		if not skillLine or (recipe and recipe.skillLine == skillLine) then
			list[#list + 1] = {
				recipeID = recipeID,
				name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID),
			}
		end
	end
	table.sort(list, function(a, b)
		local ap, bp = ns.PinPreference(a.recipeID), ns.PinPreference(b.recipeID)
		return ap > bp or (ap == bp and a.recipeID < b.recipeID)
	end)
	return list
end

---@param recipeID integer
---@param pin boolean
function ns.SetPinned(recipeID, pin)
	local key = ns.CharacterKey()
	if not key then
		return
	end
	local pins = ns.db.pinnedRecipes[key] or {}
	pins[recipeID] = nil
	if pin then
		-- Compact saved priorities before appending so they cannot overflow after repeated choices.
		local ids = {}
		for id in pairs(pins) do
			ids[#ids + 1] = id
		end
		table.sort(ids, function(a, b)
			return pins[a] < pins[b] or (pins[a] == pins[b] and a < b)
		end)
		for priority, id in ipairs(ids) do
			pins[id] = priority
		end
		pins[recipeID] = #ids + 1
		if ns.db.skippedRecipes[key] then
			ns.db.skippedRecipes[key][recipeID] = nil
		end
	end
	ns.db.pinnedRecipes[key] = next(pins) and pins or nil
	ns.Changed("settings")
end

-- This character's skipped recipes, of one profession when `skillLine` is given, by name.
---@param skillLine integer?
---@return {recipeID: integer, name: string}[]
function ns.SkippedRecipes(skillLine)
	local list = {}
	local key = ns.CharacterKey()
	for recipeID in pairs(key and ns.db.skippedRecipes[key] or {}) do
		local recipe = ns.RecipeData[recipeID]
		if not skillLine or (recipe and recipe.skillLine == skillLine) then
			local name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
			list[#list + 1] = { recipeID = recipeID, name = name }
		end
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.recipeID < b.recipeID
	end)
	return list
end

-- Recipes this character has been seen to know in the Professions window, for
-- places (trainer, item tooltips) that can't ask it. C_SpellBook.IsSpellKnown covers
-- professions not opened yet, and every session while SavedVariables fail to load.
local function LearnedRecipes()
	local key = ns.CharacterKey()
	if not key then
		return {}
	end
	ns.db.learned[key] = ns.db.learned[key] or {}
	return ns.db.learned[key]
end

-- A live read of one recipe's learned flag, from Core/Live.lua's one scan of the recipe list.
---@param recipeID integer
---@param learned boolean?
---@return boolean changed
function ns.NoteLearnedRecipe(recipeID, learned)
	local learnedRecipes = LearnedRecipes()
	local flag = learned or nil
	local changed = learnedRecipes[recipeID] ~= flag
	learnedRecipes[recipeID] = flag
	if learned == true then
		ns.Stats.Observe(recipeID)
	end
	return changed
end

-- A non-English client has no bundled profession name; learn it when its window is open.
local function NoteProfessionName()
	if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
		return
	end
	local base = C_TradeSkillUI.GetBaseProfessionInfo()
	if base and base.professionName and KNOWN_SKILL_LINES[base.professionID] then
		ns.db.professionIDs[base.professionName] = base.professionID
	end
end

-- An unlearned profession takes its recipes with it.
local function ForgetDroppedProfessions()
	local professions = ns.PlayerProfessions()
	-- Skill lines can arrive empty at login; that is not every profession dropped.
	if not next(professions) then
		return
	end
	local learned = LearnedRecipes()
	for recipeID in pairs(learned) do
		local recipe = ns.RecipeData[recipeID]
		if recipe and not professions[recipe.skillLine] then
			learned[recipeID] = nil
		end
	end
end

---@param recipeID integer
---@return boolean
function ns.IsLearned(recipeID)
	return LearnedRecipes()[recipeID] or C_SpellBook.IsSpellKnown(recipeID)
end

-- Everything a row or tooltip renders for one recipe at the current skill.
---@param recipeInfo TradeSkillRecipeInfo|SkillUpRecipeInfo
---@param ctx SkillUpContext?
---@return SkillUpDescription
function ns.Describe(recipeInfo, ctx)
	local thresholds = ns.Model.Get(recipeInfo.recipeID)
	local liveColor = LIVE_COLOR[recipeInfo.relativeDifficulty]
	local cost, value, net = ns.CraftCost(recipeInfo.recipeID)
	if not thresholds or not ctx then
		return { thresholds = nil, color = liveColor or "unknown", cost = cost, value = value, net = net }
	end
	local chance = ns.Model.Chance(thresholds, ctx.skill)
	if chance and (ctx.capped or (recipeInfo.learned and recipeInfo.canSkillUp == false)) then
		chance = 0
	end
	return {
		thresholds = thresholds,
		color = liveColor or ns.Model.Color(thresholds, ctx.skill),
		chance = chance,
		cost = cost,
		value = value,
		net = net,
		perSkillUp = ns.Model.CostPerSkillUp(net, chance),
	}
end

-- The compact "skill · chance · cost" text of a recipe row or trainer service.
---@param d SkillUpDescription
---@return string
function ns.FormatRow(d)
	if not d.thresholds then
		return "?"
	end
	-- Before the difficulty range starts, show its first skill value.
	if not d.chance then
		return tostring(d.thresholds[1])
	end
	local parts = {}
	if ns.db.showSkill then
		parts[#parts + 1] = tostring(d.thresholds[1])
	end
	parts[#parts + 1] = string.format("%d%%", math.floor(d.chance * 100 + 0.5))
	-- A negative amount is a profit, a positive one a cost.
	local amount = ns.db.rowCost == "craft" and d.net or d.perSkillUp
	if ns.db.showCost and amount then
		parts[#parts + 1] = ns.FormatSigned(ns.Model.RoundMoney(math.abs(amount)), amount < 0)
	end
	return table.concat(parts, " · ")
end

---@param d SkillUpDescription
---@return ColorMixin
function ns.RowColor(d)
	return ns.COLORS[d.chance and d.color or (d.thresholds and "red" or "unknown")]
end

-- /su audit's lines: with a profession open, the bundled thresholds against the colours the game shows, as a
-- summary line then each mismatch; nil with none open. English throughout: it is a data check for bug reports.
---@return string[]?
function ns.AuditLines()
	local ctx = ProfessionsFrame and ProfessionsFrame:IsShown() and ns.SkillContext()
	if not ctx then
		return nil
	end
	local skill = ctx.skill
	local checked, missing, mismatches = 0, 0, {}
	for _, recipeID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		local live = info and info.learned and LIVE_COLOR[info.relativeDifficulty]
		if info and live then
			local t = ns.Model.Get(recipeID)
			if not t then
				missing = missing + 1
			else
				checked = checked + 1
				local predicted = ns.Model.Color(t, skill)
				local grey = info.maxTrivialLevel
				if predicted ~= live or (grey and grey > 0 and grey ~= t[4]) then
					mismatches[#mismatches + 1] = string.format(
						"%s (%d): table %d/%d/%d/%d says %s, game says %s, maxTrivialLevel %s",
						info.name,
						recipeID,
						t[1],
						t[2],
						t[3],
						t[4],
						predicted,
						live,
						tostring(grey)
					)
				end
			end
		end
	end
	local lines = {
		string.format(
			"%s at %d: %d checked, %d mismatched, %d without data.",
			ctx.name or "?",
			skill,
			checked,
			#mismatches,
			missing
		),
	}
	for _, line in ipairs(mismatches) do
		lines[#lines + 1] = line
	end
	return lines
end

local function Audit()
	local lines = ns.AuditLines()
	if not lines then
		ns.Print(L["open a profession first."])
		return
	end
	for _, line in ipairs(lines) do
		ns.Print(line)
	end
end

-- /su skipped: this character's skipped recipes, each with its ID for /su unskip.
local function ListSkipped()
	local skipped = ns.SkippedRecipes()
	if #skipped == 0 then
		ns.Print(L["no skipped recipes: right-click a step on the route page and choose Not this recipe."])
		return
	end
	ns.Print(string.format(L["Skipped (%d):"], #skipped))
	for _, recipe in ipairs(skipped) do
		ns.Print(string.format("%s (%d)", recipe.name, recipe.recipeID))
	end
	ns.Print(L["/su unskip <recipe ID> shows one again, /su unskip all every one."])
end

-- /su unskip <recipe ID> or /su unskip all: Show again, from chat.
---@param argument string
local function Unskip(argument)
	if argument == "all" then
		for _, recipe in ipairs(ns.SkippedRecipes()) do
			ns.SetSkipped(recipe.recipeID, false)
		end
		ns.Print(L["every skipped recipe is back in the route."])
		return
	end
	local recipeID = tonumber(argument)
	if not (recipeID and ns.IsSkipped(recipeID)) then
		ns.Print(L["/su skipped lists the recipes you skipped, with their IDs."])
		return
	end
	ns.SetSkipped(recipeID, false)
	local name = C_Spell.GetSpellName(recipeID) or string.format(L["recipe %d"], recipeID)
	ns.Print(string.format(L["Show again: %s"], name))
end

-- /su export trainers (#124): the requirements this character's trainers actually showed, as a table for
-- tools/gen_trainer.py's SEEN_REQUIREMENTS, so a value no bundled rule guessed right can be fixed for everyone.
-- Trainers are the only export, so /su export does the same as /su export trainers. The copy window when it can
-- open, the same lines in chat when it cannot: nothing is written, nothing prints on login, nothing waits on an
-- event, and there is no protected call in it.
local function Export()
	local lines = ns.TrainerExport()
	if not lines[1] then
		ns.Print(L["no trainer requirement seen yet: open a profession trainer, then try again."])
		return
	end
	local text = table.concat(lines, "\n")
	local shown = ns.Report and ns.Report.Show and ns.SafeCall and ns.SafeCall("export window", ns.Report.Show, text)
	if not shown then
		for _, line in ipairs(lines) do
			ns.Print(line)
		end
	end
end

SLASH_SKILLUPFOREVER1 = "/skillup"
SLASH_SKILLUPFOREVER2 = "/su"
local function Slash(msg)
	local command, argument = strtrim(msg):lower():match("^(%S*)%s*(.-)$")
	if ns.Report and ns.Report.Command and ns.Report.Command(command, argument) then
		return
	elseif command == "help" then
		ns.Print(L["/su report - show a report to copy into a bug report"])
		ns.Print(L["/su issue - report a bug or request a feature with a ready-made GitHub issue link"])
		ns.Print(L["/su export - show the trainer requirements this character has seen, to paste into a report"])
		ns.Print(L["/su leaderboard - rank distinct recipes observed learned; also /su stats"])
		ns.Print(L["/su share on|off - control sharing with guild and group"])
	elseif command == "leaderboard" or command == "stats" then
		if ns.Stats and ns.db then
			ns.Stats.Print()
		end
	elseif command == "share" and (argument == "on" or argument == "off") then
		if ns.Stats and ns.db then
			Settings.SetValue("SkillUpForever_statsShare", argument == "on")
			ns.Stats.Print()
		end
	elseif command == "shopping" or command == "shop" then
		ns.OpenShoppingList()
	elseif command == "audit" then
		Audit()
	elseif command == "trainers" then
		for _, line in ipairs(ns.TrainerReport()) do
			ns.Print(line)
		end
	elseif command == "export" then
		Export()
	elseif command == "skipped" then
		ListSkipped()
	elseif command == "unskip" then
		Unskip(argument)
	else
		ns.OpenSettings()
	end
end
SlashCmdList.SKILLUPFOREVER = function(msg)
	-- Without Core/SafeCall.lua (a /reload after an update that added it) the command runs as it is.
	if ns.SafeCall then
		ns.SafeCall("slash command", Slash, msg)
	else
		Slash(msg)
	end
end

function SkillUpForever_OnAddonCompartmentClick()
	ns.OpenSettings()
end

-- Blizzard_Professions may already be loaded (another addon opened it), in which
-- case the continuation runs at once, so register it only after our own files
-- and SavedVariables are in place.
EventUtil.ContinueOnAddOnLoaded(addonName, function()
	-- /reload doesn't re-read the .toc, so files added by an update stay unloaded.
	if
		not (
			ns.RecipeData
			and ns.ItemGear
			and ns.ProfessionSkillLines
			and ns.TrainerFees
			and ns.TrainerRanks
			and ns.Catalogue
			and ns.PlanRoute
			and ns.CraftedGear
			and ns.Changed
			and ns.SafeCall
			and ns.Report
			and ns.ReportLines
			and ns.Family
			and ns.Stats
		)
	then
		ns.Print("|cffff4040" .. L["files are missing: restart the game (not /reload) after updating."] .. "|r")
		return
	end
	LoadDB()
	ns.NoteBuild()
	ns.InitCatalogue()
	ns.WhenEvent("TRADE_SKILL_LIST_UPDATE", NoteProfessionName)
	ns.WhenEvent("SKILL_LINES_CHANGED", ForgetDroppedProfessions)
	ns.InitLive()
	ns.InitPrices()
	ns.RegisterSettings()
	ns.AttachItemTooltips()
	ns.InitShopping()
	EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", ns.AttachRecipeList)
	EventUtil.ContinueOnAddOnLoaded("Blizzard_TrainerUI", ns.AttachTrainer)
end)
