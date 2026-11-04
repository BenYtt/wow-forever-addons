---@type string, SkillUpNamespace
local _, ns = ...

-- What the client knows about a recipe that the bundle cannot: the live grey threshold, the skill
-- points one craft grants and the tool and station the recipe requires. A live read replaces only
-- the field it carries; the bundled yellow and green stay under the live grey, and a recipe the
-- bundle has no row for shows `?` rather than a guess.

---@type table<integer, SkillUpLiveRecipe>
ns.LiveRecipes = {}

local EMPTY = {}

-- The recipe's live requirements, as the client reports them: a Totem is a tool carried in the bags,
-- a SpellFocus is the station it is made at. Read fresh, because whether a tool is carried changes
-- with the bags and the scan would go stale.
---@param recipeID integer
---@return CraftingRecipeRequirement[]
function ns.RecipeRequirements(recipeID)
	if not C_TradeSkillUI.GetRecipeRequirements then
		return EMPTY
	end
	return C_TradeSkillUI.GetRecipeRequirements(recipeID) or EMPTY
end

---@param requirement CraftingRecipeRequirement
---@return boolean
local function IsTool(requirement)
	return Enum.RecipeRequirementType ~= nil and requirement.type == Enum.RecipeRequirementType.Totem
end

---@param requirement CraftingRecipeRequirement
---@return boolean
local function IsStation(requirement)
	return Enum.RecipeRequirementType ~= nil
		and (
			requirement.type == Enum.RecipeRequirementType.SpellFocus
			or requirement.type == Enum.RecipeRequirementType.Area
		)
end

-- The first tool this recipe needs that the player is not carrying; nil when it is carried or the
-- recipe needs none.
---@param recipeID integer
---@return CraftingRecipeRequirement?
function ns.MissingTool(recipeID)
	for _, requirement in ipairs(ns.RecipeRequirements(recipeID)) do
		if IsTool(requirement) and requirement.met == false then
			return requirement
		end
	end
end

-- Where the recipe has to be made, from its station requirements: "Anvil", "Forge", "Cooking Fire"
-- or the like, joined when it needs more than one. nil when it can be made anywhere.
---@param recipeID integer
---@return string?
function ns.RecipeStation(recipeID)
	local names = {}
	for _, requirement in ipairs(ns.RecipeRequirements(recipeID)) do
		if IsStation(requirement) and requirement.name and requirement.name ~= "" then
			names[#names + 1] = requirement.name
		end
	end
	if #names == 0 then
		return nil
	end
	return table.concat(names, ", ")
end

-- The item a tool's name belongs to, so a missing tool can join the shopping list; nil when the
-- client cannot name one.
---@param name string
---@return integer?
function ns.ToolItemID(name)
	if not (name and C_Item.GetItemInfoInstant) then
		return nil
	end
	local itemID = C_Item.GetItemInfoInstant(name)
	return type(itemID) == "number" and itemID or nil
end

-- The distinct carried tools the plan's crafts, sub-crafts included, need and the player is not
-- holding, one each, so a tool used by many steps is added to the shopping list once.
---@param plan SkillUpPlan
---@return integer[]
function ns.MissingToolItems(plan)
	local seen, items = {}, {}
	---@param recipeID integer
	local function Add(recipeID)
		local tool = ns.MissingTool(recipeID)
		if tool and tool.name and not seen[tool.name] then
			seen[tool.name] = true
			local itemID = ns.ToolItemID(tool.name)
			if itemID then
				items[#items + 1] = itemID
			end
		end
	end
	for _, craft in ipairs(plan.crafts or {}) do
		Add(craft.recipeID)
		for _, sub in ipairs(craft.subcrafts or {}) do
			Add(sub.recipeID)
		end
	end
	table.sort(items)
	return items
end

-- The skill points one craft of the recipe grants, from the client when it has been read.
---@param recipeID integer
---@return integer
function ns.RecipeSkillUps(recipeID)
	local live = ns.LiveRecipes[recipeID]
	return live and live.skillUps or 1
end

-- Recipe list changes arrive in bursts when a profession opens or a recipe is learned; one scan
-- covers the burst.
local scanning = false

-- The open profession's recipes, read once: what the client says about each recipe that the bundle
-- cannot, and which recipes the character knows. Returns true when something changed.
---@return boolean
local function Scan()
	scanning = false
	-- A linked or guild window shows someone else's recipes; its learned flags are not this
	-- character's and never overwrite what is known.
	if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
		return false
	end
	if not C_TradeSkillUI.GetAllRecipeIDs then
		return false
	end
	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
	-- A schematic the window's events came too early for: the client had it only a frame later.
	local changed = ns.LiveSchematicsArrived(recipeIDs)
	for _, recipeID in ipairs(recipeIDs) do
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if info then
			changed = ns.NoteLearnedRecipe(recipeID, info.learned) or changed
			local bundled = ns.Thresholds and ns.Thresholds[recipeID]
			local grey = info.maxTrivialLevel
			local skillUps = math.max(info.numSkillUps or 1, 1)
			local live = ns.LiveRecipes[recipeID] or {}
			local oldGrey = live.thresholds and live.thresholds[4]
			-- The live grey replaces the bundled one; without it the bundled bands stand alone.
			if bundled and grey and grey > 0 then
				local thresholds = live.thresholds or {}
				thresholds[1], thresholds[2], thresholds[3], thresholds[4] = bundled[1], bundled[2], bundled[3], grey
				live.thresholds = thresholds
			else
				live.thresholds = nil
			end
			-- Compared with the grey kept, not the client's: one the bundle can't use (a recipe it lacks, or a
			-- grey of 0) is kept as none on every scan, and so is no change.
			local newGrey = live.thresholds and live.thresholds[4]
			changed = changed or oldGrey ~= newGrey or live.skillUps ~= skillUps
			live.skillUps = skillUps
			ns.LiveRecipes[recipeID] = live
		end
	end
	return changed
end

local function ScheduleScan()
	if scanning then
		return
	end
	scanning = true
	C_Timer.After(0, function()
		if Scan() then
			-- The live grey can change a plan; drop the caches that were built without it.
			ns.Changed("recipes")
		end
	end)
end

function ns.InitLive()
	for _, event in ipairs({
		"TRADE_SKILL_SHOW",
		"TRADE_SKILL_LIST_UPDATE",
		"TRADE_SKILL_DATA_SOURCE_CHANGED",
		"NEW_RECIPE_LEARNED",
	}) do
		ns.WhenEvent(event, ScheduleScan)
	end
end
