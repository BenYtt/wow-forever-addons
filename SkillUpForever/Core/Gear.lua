---@type string, SkillUpNamespace
local _, ns = ...
local L = ns.L

-- The crafted gear view's listing rule: for each equipment slot, the newest items this character
-- can equip, ready for UI/Gear.lua to draw. Newness is the item's required level, nothing else,
-- so there are no stat weights and no best-in-slot claim.

-- Equipment slots the view lists, in the character sheet's order: the left column down one side,
-- the right column down the other and the weapon slots along the bottom. The sheet's two ring and
-- two trinket slots share one list each, and a two-handed weapon shares the main-hand list with a
-- one-hander, because an item's inventory type names the slot it goes in, not which of the pair. The
-- shirt, tabard and ammo slots are left out: no crafted gear goes in them.
---@type { name: string, types: integer[] }[]
local GROUPS = {
	{ name = L["Head"], types = { 1 } },
	{ name = L["Neck"], types = { 2 } },
	{ name = L["Shoulder"], types = { 3 } },
	{ name = L["Back"], types = { 16 } },
	{ name = L["Chest"], types = { 5, 20 } },
	{ name = L["Wrist"], types = { 9 } },
	{ name = L["Hands"], types = { 10 } },
	{ name = L["Waist"], types = { 6 } },
	{ name = L["Legs"], types = { 7 } },
	{ name = L["Feet"], types = { 8 } },
	{ name = L["Finger"], types = { 11 } },
	{ name = L["Trinket"], types = { 12 } },
	{ name = L["Main hand"], types = { 13, 17, 21 } },
	{ name = L["Off hand"], types = { 14, 22, 23 } },
	{ name = L["Ranged"], types = { 15, 25, 26, 28 } },
}

---@type table<integer, integer>
local GROUP_OF = {}
for index, group in ipairs(GROUPS) do
	for _, inventoryType in ipairs(group.types) do
		GROUP_OF[inventoryType] = index
	end
end

-- What each class can wear, and from which level, as the client's SkillRaceClassInfo expresses it
-- (wago.tools/db2/SkillRaceClassInfo and SkillLine, wow_classic_beta 1.60.1.70205): a row names one
-- skill line (a type), the class mask it covers and the level it starts at. Armour subclasses are 1
-- cloth, 2 leather, 3 mail, 4 plate and 6 shield; weapon subclasses are 0 one-hand axe, 1 two-hand
-- axe, 2 bow, 3 gun, 4 one-hand mace, 5 two-hand mace, 6 polearm, 7 one-hand sword, 8 two-hand sword,
-- 10 staff, 13 fist weapon, 15 dagger, 16 thrown, 18 crossbow and 19 wand.
-- The number is the level that type needs; a type absent for a class is one it can never use.
---@type table<integer, table<integer, integer>>
local ARMOUR = {
	[1] = { [1] = 0, [2] = 0, [3] = 0, [4] = 40, [6] = 0 }, -- Warrior
	[2] = { [1] = 0, [2] = 0, [3] = 0, [4] = 40, [6] = 0 }, -- Paladin
	[3] = { [1] = 0, [2] = 0, [3] = 40 }, -- Hunter
	[4] = { [1] = 0, [2] = 0 }, -- Rogue
	[5] = { [1] = 0 }, -- Priest
	[7] = { [1] = 0, [2] = 0, [3] = 40, [6] = 0 }, -- Shaman
	[8] = { [1] = 0 }, -- Mage
	[9] = { [1] = 0 }, -- Warlock
	[11] = { [1] = 0, [2] = 0 }, -- Druid
}

-- What each class wields from creation, the same client rows: a weapon type is here only when a row
-- with Availability 1 covers the class and a playable race. Any other weapon type needs training
-- from a weapon master, so Gear.List asks the character's own skill lines for it instead.
---@type table<integer, table<integer, integer>>
local WEAPON = {
	[1] = { [0] = 0, [1] = 0, [4] = 0, [5] = 0, [7] = 0, [8] = 0, [15] = 0, [16] = 0 }, -- Warrior
	[2] = { [4] = 0, [5] = 0 }, -- Paladin
	[3] = { [0] = 0, [2] = 0, [3] = 0, [15] = 0 }, -- Hunter
	[4] = { [0] = 0, [15] = 0, [16] = 0 }, -- Rogue
	[5] = { [4] = 0, [19] = 0 }, -- Priest
	[7] = { [4] = 0, [10] = 0 }, -- Shaman
	[8] = { [10] = 0, [19] = 0 }, -- Mage
	[9] = { [15] = 0, [19] = 0 }, -- Warlock
	[11] = { [4] = 0, [10] = 0, [15] = 0 }, -- Druid
}
---@type table<integer, table<integer, table<integer, integer>>>
local PROFICIENCY = { [2] = WEAPON, [4] = ARMOUR }

-- The weapon skill line each weapon type belongs to (SkillLine IDs on the pinned build). An item's
-- own subclass names the line the character's skill list reports once the type is known.
---@type table<integer, integer>
local WEAPON_SKILL = {
	[0] = 44, -- One-Handed Axes
	[1] = 172, -- Two-Handed Axes
	[2] = 45, -- Bows
	[3] = 46, -- Guns
	[4] = 54, -- One-Handed Maces
	[5] = 160, -- Two-Handed Maces
	[6] = 229, -- Polearms
	[7] = 43, -- One-Handed Swords
	[8] = 55, -- Two-Handed Swords
	[10] = 136, -- Staves
	[13] = 473, -- Fist Weapons
	[15] = 173, -- Daggers
	[16] = 176, -- Thrown
	[18] = 226, -- Crossbows
	[19] = 228, -- Wands
}
---@type table<integer, true>
local WEAPON_LINE = {}
for _, skillLine in pairs(WEAPON_SKILL) do
	WEAPON_LINE[skillLine] = true
end

-- The subclasses gated by PROFICIENCY. Every other type, such as a ring, trinket or fishing pole,
-- is open to every class; its own AllowableClass still has the last word.
---@type table<integer, table<integer, true>>
local GATED = {
	[2] = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[7] = true,
		[8] = true,
		[10] = true,
		[13] = true,
		[15] = true,
		[16] = true,
		[18] = true,
		[19] = true,
	},
	[4] = { [1] = true, [2] = true, [3] = true, [4] = true, [6] = true },
}

-- The fields of an ns.ItemGear row.
local LEVEL, ITEM_CLASS, SUBCLASS, SLOT, CLASSES, REQUIRED_SKILL, REQUIRED_RANK, CONSUMED = 1, 2, 3, 4, 5, 6, 7, 8
local WEAPONS = 2

-- The layout fits a few rows a slot without turning the view into a wall of names.
local MAX_PER_SLOT = 3

-- How ready a row is, best first: a known recipe, then one the skill already reaches, then one it
-- has still to reach, then one of another crafter's. Ties break on the skill the recipe needs.
---@type table<string, integer>
local STATE_RANK = { known = 1, trainable = 2, needs = 3, other = 4 }

---@class SkillUpGear
local Gear = {}
ns.Gear = Gear

-- The weapon skill lines this character knows now, by line, from the client's own skill list, or nil
-- when the client cannot answer yet. The class table is only the creation fallback; a trained type
-- shows here, which is what makes a sword a warrior's and not a mage's.
---@return table<integer, number>?
function Gear.WeaponSkills()
	if not C_SkillInfo then
		return nil
	end
	local lines = C_SkillInfo.GetNumSkillLines()
	if lines == 0 then
		return nil
	end
	local known = {}
	for index = 1, lines do
		local info = C_SkillInfo.GetSkillLineInfo(index)
		if info and not info.isHeader and WEAPON_LINE[info.skillID] then
			known[info.skillID] = info.rank
		end
	end
	return known
end

-- One profession's name, from the bundled ones; the character's own name wins in List.
---@param skillLine integer
---@return string
function Gear.ProfessionName(skillLine)
	for name, id in pairs(ns.ProfessionSkillLines or {}) do
		if id == skillLine then
			return name
		end
	end
	return string.format(L["profession %d"], skillLine)
end

-- Whether the character can use the item now: the class mask allows it, the item's own skill
-- requirement is met, and its armour or weapon type is one the character can wear or has trained.
---@param facts number[]
---@param level number
---@param classID integer
---@param query SkillUpGearQuery
---@return boolean
local function Usable(facts, level, classID, query)
	if bit.band(facts[CLASSES], bit.lshift(1, classID - 1)) == 0 then
		return false
	end
	local required, rank = facts[REQUIRED_SKILL], facts[REQUIRED_RANK]
	if required ~= 0 then
		local profession = query.professions[required]
		if not profession or profession.skill < rank then
			return false
		end
	end
	local itemClass = facts[ITEM_CLASS]
	local gated = GATED[itemClass]
	if not gated or not gated[facts[SUBCLASS]] then
		return true
	end
	if itemClass == WEAPONS and query.weaponSkills then
		local skillLine = WEAPON_SKILL[facts[SUBCLASS]]
		return skillLine ~= nil and query.weaponSkills[skillLine] ~= nil
	end
	local byClass = PROFICIENCY[itemClass][classID]
	local from = byClass and byClass[facts[SUBCLASS]]
	return from ~= nil and level >= from
end

-- The newest craftable items for the character's level and class, one list a slot, newest first.
-- The item's slot and type come from `facts`, its recipe and profession from `recipes`, and the
-- skill it needs from `query.skill`. With `query.showAll` off, only rows the character can make now
-- are kept: a known recipe, or one the character's own skill already reaches.
---@param recipes table<integer, SkillUpRecipe>
---@param facts table<integer, number[]>
---@param query SkillUpGearQuery
---@return SkillUpGearSlot[]
function Gear.List(recipes, facts, query)
	local found = {}
	for recipeID, recipe in pairs(recipes) do
		local output = recipe.output
		local itemID = output and output.itemID or nil
		local info = itemID and facts[itemID] or nil
		local group = info and GROUP_OF[info[SLOT]] or nil
		if
			itemID
			and info
			and group
			and info[CONSUMED] == 0
			and info[LEVEL] <= query.level
			and Usable(info, query.level, query.classID, query)
		then
			local learned = query.learned(recipeID) == true
			local profession = query.professions[recipe.skillLine]
			local skill = query.skill(recipeID)
			local state
			if learned then
				state = "known"
			elseif not profession or not skill then
				-- Without a requirement the recipe cannot be called craftable, so it counts as another's.
				state = "other"
			elseif profession.skill >= skill then
				state = "trainable"
			else
				state = "needs"
			end
			if query.showAll or state == "known" or state == "trainable" then
				local bucket = found[group]
				if not bucket then
					bucket = {}
					found[group] = bucket
				end
				local held = bucket[itemID]
				if
					not held
					or STATE_RANK[state] < STATE_RANK[held.state]
					or (STATE_RANK[state] == STATE_RANK[held.state] and (skill or -1) < (held.skill or -1))
				then
					bucket[itemID] = {
						recipeID = recipeID,
						itemID = itemID,
						name = query.name(itemID),
						skillLine = recipe.skillLine,
						skill = skill,
						level = info[LEVEL],
						profession = profession and profession.name or query.professionName(recipe.skillLine),
						learned = learned,
						state = state,
					}
				end
			end
		end
	end
	-- Every slot is returned, empty or not, so the page can draw the character sheet's own slots.
	local slots = {}
	for index, group in ipairs(GROUPS) do
		local items = {}
		for _, item in pairs(found[index] or {}) do
			items[#items + 1] = item
		end
		table.sort(items, function(a, b)
			if a.level ~= b.level then
				return a.level > b.level
			end
			if (a.skill or -1) ~= (b.skill or -1) then
				return (a.skill or -1) > (b.skill or -1)
			end
			return (a.name or tostring(a.itemID)) < (b.name or tostring(b.itemID))
		end)
		while #items > MAX_PER_SLOT do
			items[#items] = nil
		end
		slots[#slots + 1] = { slot = index, name = group.name, items = items }
	end
	return slots
end

-- The crafted gear for the character now, from the bundled data and the character's own skills.
---@param level number
---@param classID integer
---@return SkillUpGearSlot[]
function ns.CraftedGear(level, classID)
	local professions = ns.PlayerProfessions()
	-- The profession to ask for where a recipe is learned; a profession the character lacks still
	-- names its recipe's requirement, without a racial bonus to add.
	local function LearnSkill(recipeID)
		local recipe = ns.RecipeData[recipeID]
		local profession = recipe and (professions[recipe.skillLine] or { skillLine = recipe.skillLine, modifier = 0 })
		local skill = profession and ns.LearnSkill(profession, recipeID) or 0
		return skill > 0 and skill or nil
	end
	return Gear.List(ns.RecipeData, ns.ItemGear, {
		level = level,
		classID = classID,
		showAll = ns.ShowAllGear(),
		learned = ns.IsLearned,
		professions = professions,
		weaponSkills = Gear.WeaponSkills(),
		name = function(itemID)
			return C_Item.GetItemNameByID(itemID)
		end,
		skill = LearnSkill,
		professionName = Gear.ProfessionName,
	})
end
