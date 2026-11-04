---@type string, SkillUpNamespace
local _, ns = ...

-- AtlasLoot, read at runtime through its public data modules: which scroll teaches a recipe and the skill
-- it needs, and a boss's drop chance where its dungeon data is loaded. Nothing of it is bundled.

---@class SkillUpAtlasLoot
local A = {}
ns.AtlasLoot = A

---@return SkillUpAtlasLootRecipes?
local function Recipes()
	local data = type(AtlasLoot) == "table" and AtlasLoot.Data
	local recipes = type(data) == "table" and data.Recipe
	if
		type(recipes) == "table"
		and type(recipes.GetRecipeForSpell) == "function"
		and type(recipes.GetRecipeData) == "function"
	then
		return recipes
	end
end

---@return boolean
function A.Ready()
	return Recipes() ~= nil
end

-- True when AtlasLoot is in the AddOns list but not running: switched off, or held back as out of date.
---@return boolean
function A.Idle()
	return Recipes() == nil and C_AddOns.DoesAddOnExist("AtlasLootClassic")
end

-- The skill a scroll needs and the recipe it teaches.
---@param itemID integer
---@return number? skill
---@return integer? spellID
function A.Scroll(itemID)
	local recipes = Recipes()
	local row = recipes and recipes.GetRecipeData(itemID)
	if type(row) == "table" and type(row[3]) == "number" and row[3] > 0 then
		return tonumber(row[2]), row[3]
	end
end

-- The scroll AtlasLoot names for a recipe. It keeps one a recipe, so a second scroll is not found here.
---@param spellID integer
---@return integer?
function A.ScrollFor(spellID)
	local recipes = Recipes()
	local itemID = recipes and recipes.GetRecipeForSpell(spellID)
	if type(itemID) == "number" and select(2, A.Scroll(itemID)) == spellID then
		return itemID
	end
end

-- A drop chance in percent, when AtlasLoot's dungeon data is loaded and has it.
---@param npcID integer
---@param itemID integer
---@return number?
function A.DropChance(npcID, itemID)
	local data = type(AtlasLoot) == "table" and AtlasLoot.Data
	local rates = type(data) == "table" and data.Droprate
	local chance = type(rates) == "table" and type(rates.GetData) == "function" and rates:GetData(npcID, itemID)
	return type(chance) == "number" and chance > 0 and chance or nil
end
