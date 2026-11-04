---@type string, SkillUpNamespace
local _, ns = ...
---@class SkillUpModel
local Model = {}
ns.Model = Model

-- A value the client hands over as secret (Forever's restricted reads, as in combat) errors on a truth
-- test, a comparison or arithmetic, and stays secret wherever it is kept. nil for one, so the caller treats
-- it as unknown; any other value unchanged.
---@generic T
---@param value T
---@return T?
function ns.Readable(value)
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

-- Whether a tooltip may be read and drawn on: false for nil and for one the client marks forbidden (a secure
-- tooltip), which raises on any method call. Every tooltip hook starts with it (tools/lint_secret.py).
---@param frame? Frame
---@return boolean
function ns.Usable(frame)
	if not frame then
		return false
	end
	return not (frame.IsForbidden and frame:IsForbidden())
end

-- Classic's gathering bands: a node is orange from its required skill, then yellow, green and grey this far past.
local GATHER_BANDS = { 0, 25, 50, 100 }
-- Classic asks a skinner (or a herbalist or miner on a corpse) for 1 up to level 10, ten points a level to 20 and
-- five times the level above that. Nobody has checked Forever kept it, so until someone does a corpse shows "?"
-- (#122). Once it is confirmed in game, set this to true.
local CORPSE_RULE_CONFIRMED = false

-- A gathering requirement as recipe thresholds, so it colours like a recipe.
---@param required number
---@return number[]
function Model.GatherThresholds(required)
	local t = {}
	for i, past in ipairs(GATHER_BANDS) do
		t[i] = required + past
	end
	return t
end

-- Classic's rule: the skill gathering from a corpse of this level asks; nil for an unknown level.
---@param level number?
---@return number?
function Model.ClassicCorpseSkill(level)
	if not level or level < 1 then
		return nil
	elseif level <= 10 then
		return 1
	elseif level <= 20 then
		return (level - 10) * 10
	end
	return level * 5
end

-- What the tooltip uses: nothing while the rule is unconfirmed.
---@param level number?
---@return number?
function Model.CorpseSkill(level)
	return CORPSE_RULE_CONFIRMED and Model.ClassicCorpseSkill(level) or nil
end

---@param recipeID integer
---@return number[]?
function Model.Get(recipeID)
	-- The client's live grey replaces the bundled one; its yellow and green do not exist, so the
	-- bundled pair stays under the live grey.
	local live = ns.LiveRecipes and ns.LiveRecipes[recipeID]
	local thresholds = live and live.thresholds or (ns.Thresholds and ns.Thresholds[recipeID])
	if
		thresholds
		and thresholds[1] <= thresholds[2]
		and thresholds[2] <= thresholds[3]
		and thresholds[3] < thresholds[4]
	then
		return thresholds
	end
	return nil
end

---@param t number[]?
---@param skill number
---@return string?
function Model.Color(t, skill)
	if not t then
		return nil
	end
	if skill < t[1] then
		return "red"
	end
	if skill < t[2] then
		return "orange"
	end
	if skill < t[3] then
		return "yellow"
	end
	if skill < t[4] then
		return "green"
	end
	return "grey"
end

---@param t number[]?
---@param skill number
---@return number?
function Model.Chance(t, skill)
	if not t or t[4] <= t[2] or skill < t[1] then
		return nil
	end
	if skill < t[2] then
		return 1
	end
	if skill >= t[4] then
		return 0
	end
	return (t[4] - skill) / (t[4] - t[2])
end

-- Expected spend per skill point: one craft costs `cost` and succeeds with `chance`.
---@param cost number?
---@param chance number?
---@return number?
function Model.CostPerSkillUp(cost, chance)
	if not cost or not chance or chance <= 0 then
		return nil
	end
	return cost / chance
end

-- The chance a run of crafts has to reach its skill goal, so a route is planned to cover an
-- unlucky run rather than the average one.
Model.CONFIDENCE = 0.9

-- The crafts that reach `to` from `from` with Model.CONFIDENCE certainty: the fewest crafts whose
-- odds of every needed skill point are at least that, worked out point by point because the
-- chance changes as skill rises. A craft can grant `skillUps` points at once, which the client's
-- own recipe info gives for an orange recipe.
---@param thresholds number[]
---@param from number
---@param to number
---@param skillUps integer?
---@return number
function Model.CoveredCrafts(thresholds, from, to, skillUps)
	local needed = to - from
	if needed <= 0 then
		return 0
	end
	local ups = math.max(skillUps or 1, 1)
	-- One point, as every recipe is ranked at each skill: the odds that it is in hand and that it is still to
	-- come, which the count below keeps in tables, worked out in the same order.
	if needed == 1 then
		local chance = Model.Chance(thresholds, from)
		if chance and chance > 0 then
			local inHand, toCome, crafts = 0, 1, 0
			while inHand < Model.CONFIDENCE do
				crafts = crafts + 1
				inHand, toCome = inHand + toCome * chance, toCome * (1 - chance)
			end
			return crafts
		end
	end
	-- A point's chance, and what a craft there gains, are the same for every craft counted: false where a
	-- craft gains nothing.
	local chances, gains = {}, {}
	for points = 0, needed - 1 do
		local chance = Model.Chance(thresholds, from + points)
		if chance and chance > 0 then
			chances[points] = chance
			-- A craft never grants more points than the recipe has left before grey.
			gains[points] = math.min(ups, needed - points, math.max(thresholds[4] - (from + points), 1))
		else
			chances[points] = false
		end
	end
	-- odds[points]: the chance that many points are in hand after the crafts counted so far. Two tables
	-- take turns, so a long run of crafts leaves no garbage.
	local odds, next_ = { [0] = 1 }, {}
	local crafts = 0
	while (odds[needed] or 0) < Model.CONFIDENCE do
		crafts = crafts + 1
		for points in pairs(next_) do
			next_[points] = nil
		end
		next_[needed] = odds[needed] or 0
		for points = 0, needed - 1 do
			local inHand = odds[points]
			if inHand then
				local chance = chances[points]
				if chance then
					local gained = gains[points]
					next_[points] = (next_[points] or 0) + inHand * (1 - chance)
					next_[points + gained] = (next_[points + gained] or 0) + inHand * chance
				else
					next_[points] = (next_[points] or 0) + inHand
				end
			end
		end
		odds, next_ = next_, odds
	end
	return crafts
end

-- The skill points one craft grants at `skill`, at most `room` of them: the client's live count,
-- capped by what the recipe has left before grey and by what the target still wants.
---@param thresholds number[]
---@param skill number
---@param skillUps integer?
---@param room number
---@return integer
function Model.Gain(thresholds, skill, skillUps, room)
	local left = thresholds[4] - skill
	if left <= 0 or room <= 0 then
		return 0
	end
	return math.max(1, math.min(skillUps or 1, left, room))
end

-- Net cost of one skill point at Model.CONFIDENCE: a low chance carries the crafts it needs, and a
-- craft that grants several points is worth that many.
---@param cost number?
---@param thresholds number[]
---@param skill number
---@param skillUps integer?
---@return number?
function Model.CostPerPoint(cost, thresholds, skill, skillUps)
	local ups = math.max(skillUps or 1, 1)
	if not cost or (Model.Chance(thresholds, skill) or 0) <= 0 then
		return nil
	end
	return cost * Model.CoveredCrafts(thresholds, skill, skill + ups, ups) / ups
end

-- A recipe's place in a route's order at a skill: what a point there costs, nil when a craft there gains none,
-- and the chance that breaks a tie. A profit ranks as free: a falling chance would otherwise favour near-grey
-- crafts that take many times the crafts per point.
---@param recipe SkillUpCandidate
---@param skill number
---@return number?
---@return number?
local function Rank(recipe, skill)
	local key = Model.CostPerPoint(math.max(recipe.netCost, 0), recipe.thresholds, skill, recipe.skillUps)
	return key, Model.Chance(recipe.thresholds, skill)
end

-- Among recipes that can gain skill, the most recent pin wins; otherwise a cheaper point, then a better
-- chance, then the lower recipe ID. A tie keeps the best so far.
---@param recipe SkillUpCandidate
---@param key number?
---@param chance number?
---@param best SkillUpCandidate|false|nil
---@param bestKey number?
---@param bestChance number?
---@return boolean
local function Beats(recipe, key, chance, best, bestKey, bestChance)
	if key == nil then
		return false
	end
	if not best then
		return true
	end
	local preference, bestPreference = recipe.preference or 0, best.preference or 0
	return preference > bestPreference
		or (
			preference == bestPreference
			and (
				key < bestKey
				or (key == bestKey and chance > bestChance)
				or (key == bestKey and chance == bestChance and recipe.recipeID < best.recipeID)
			)
		)
end

-- What a route is planned from: a snapshot's recipes, and the ones a training search adds to the end of
-- them. Training re-plans once per candidate, so what each re-plan would work out again is kept: a recipe's
-- rank at a skill, the crafts a step takes, and the list's best recipe at each skill, which a recipe joining
-- the end updates. A route over the list plus one more recipe on its end then picks, at each skill, the list's
-- best or that recipe, whichever goes first: what ranking the whole longer list picks, as a tie keeps the
-- earlier. Nothing is kept past the search that made it, so a threshold changed later is never read from it.
---@param snapshot SkillUpSnapshot
---@return SkillUpPlanner
local function Planner(snapshot)
	local from, target = snapshot.skill, snapshot.target
	local priced, thresholds, costOf = {}, {}, {}
	local excluded = { unpriced = 0, recipes = {} }
	-- [recipe][skill]: its rank there, the key false where it gains nothing.
	local keys, chances = {}, {}
	-- [skill]: the list's best recipe there, false for none, and its rank.
	local bests, bestKeys, bestChances = {}, {}, {}
	-- [thresholds][from][to][skillUps]: Model.CoveredCrafts.
	local covered = {}

	---@param recipe SkillUpCandidate
	---@param skill number
	---@return number?
	---@return number?
	local function RankAt(recipe, skill)
		local byKey, byChance = keys[recipe], chances[recipe]
		if not byKey then
			byKey, byChance = {}, {}
			keys[recipe], chances[recipe] = byKey, byChance
		end
		local key = byKey[skill]
		if key == nil then
			local chance
			key, chance = Rank(recipe, skill)
			byKey[skill], byChance[skill] = key or false, chance
			return key, chance
		end
		return key or nil, byChance[skill]
	end

	---@param skill number
	---@return SkillUpCandidate|false
	---@return number?
	---@return number?
	local function BestAt(skill)
		local best = bests[skill]
		if best == nil then
			local bestKey, bestChance
			best = false
			for _, recipe in ipairs(priced) do
				local key, chance = RankAt(recipe, skill)
				if Beats(recipe, key, chance, best, bestKey, bestChance) then
					best, bestKey, bestChance = recipe, key, chance
				end
			end
			bests[skill], bestKeys[skill], bestChances[skill] = best, bestKey, bestChance
		end
		return best, bestKeys[skill], bestChances[skill]
	end

	---@param t number[]
	---@param fromSkill number
	---@param toSkill number
	---@param skillUps integer?
	---@return number
	local function Covered(t, fromSkill, toSkill, skillUps)
		local ups = math.max(skillUps or 1, 1)
		covered[t] = covered[t] or {}
		local byFrom = covered[t]
		byFrom[fromSkill] = byFrom[fromSkill] or {}
		local byTo = byFrom[fromSkill]
		byTo[toSkill] = byTo[toSkill] or {}
		local byUps = byTo[toSkill]
		byUps[ups] = byUps[ups] or Model.CoveredCrafts(t, fromSkill, toSkill, ups)
		return byUps[ups]
	end

	-- A recipe joins the end of the list.
	---@param recipe SkillUpCandidate
	local function Add(recipe)
		if recipe.netCost == nil then
			-- A grey recipe could not help even with a price, so it keeps nothing out.
			if recipe.thresholds[4] > from then
				excluded.unpriced = excluded.unpriced + 1
				excluded.recipes[excluded.unpriced] = recipe.recipeID
			end
			return
		end
		priced[#priced + 1] = recipe
		thresholds[recipe.recipeID] = recipe.thresholds
		costOf[recipe.recipeID] = recipe.netCost
		for skill, best in pairs(bests) do
			local key, chance = RankAt(recipe, skill)
			if Beats(recipe, key, chance, best, bestKeys[skill], bestChances[skill]) then
				bests[skill], bestKeys[skill], bestChances[skill] = recipe, key, chance
			end
		end
	end

	-- The route the list takes, or with `extra` on its end: Model.PlanRoute's, with what the list leaves out.
	-- Then each skill it picked a recipe at, in order.
	---@param extra SkillUpCandidate?
	---@return SkillUpRoute
	---@return number[]
	local function Route(extra)
		if extra and extra.netCost == nil then
			extra = nil
		end
		local route = { segments = {}, expectedCost = 0, reachedSkill = from, excluded = excluded }
		local picked = {}
		while route.reachedSkill < target do
			local skill = route.reachedSkill
			picked[#picked + 1] = skill
			local best, bestKey, bestChance = BestAt(skill)
			if extra then
				local key, chance = RankAt(extra, skill)
				if Beats(extra, key, chance, best, bestKey, bestChance) then
					best = extra
				end
			end
			if not best then
				route.stopReason = "no_recipe"
				break
			end
			local gain = Model.Gain(best.thresholds, skill, best.skillUps, target - skill)
			if gain <= 0 then
				route.stopReason = "no_recipe"
				break
			end
			local segment = route.segments[#route.segments]
			if not segment or segment.recipeID ~= best.recipeID then
				segment = { recipeID = best.recipeID, fromSkill = skill, toSkill = skill, skillUps = best.skillUps }
				route.segments[#route.segments + 1] = segment
			end
			segment.toSkill = skill + gain
			route.reachedSkill = skill + gain
		end
		-- Each step carries the crafts and cost that reach its target in nine runs of ten, from the last
		-- recipe in the list with its ID.
		for _, segment in ipairs(route.segments) do
			local recipeID = segment.recipeID
			local t, cost = thresholds[recipeID], costOf[recipeID]
			if extra and extra.recipeID == recipeID then
				t, cost = extra.thresholds, extra.netCost
			end
			segment.crafts = Covered(t, segment.fromSkill, segment.toSkill, segment.skillUps)
			route.expectedCost = route.expectedCost + cost * segment.crafts
		end
		return route, picked
	end

	-- Whether `extra` on the end of the list changes the route the list takes, which picked at the skills in
	-- `picked`: only by going first at one of them, or by an ID the list already has, whose crafts are then
	-- counted from it. A recipe with no price is never picked.
	---@param extra SkillUpCandidate
	---@param picked number[]
	---@return boolean
	local function Changes(extra, picked)
		if extra.netCost == nil then
			return false
		elseif costOf[extra.recipeID] ~= nil then
			return true
		end
		for _, skill in ipairs(picked) do
			local best, bestKey, bestChance = BestAt(skill)
			local key, chance = RankAt(extra, skill)
			if Beats(extra, key, chance, best, bestKey, bestChance) then
				return true
			end
		end
		return false
	end

	for _, recipe in ipairs(snapshot.recipes) do
		Add(recipe)
	end
	return { Add = Add, Route = Route, Changes = Changes }
end

-- Inputs are already filtered to learned recipes of one profession, with prices
-- frozen by the caller. Inventory affects shopping, never recipe selection.
---@param snapshot SkillUpSnapshot
---@return SkillUpRoute
function Model.PlanRoute(snapshot)
	return (Planner(snapshot).Route())
end

-- Reach comes first, then a pin the resulting route uses, then savings for equal endpoints.
-- Each candidate is a separate purchase, charged exactly once.
---@param planner SkillUpPlanner
---@param services SkillUpService[]
---@return {recipeID: integer, savings: number, reachedSkill: number}?
local function Recommend(planner, services)
	local baseline, picked = planner.Route()
	local best, bestPreference
	for _, service in ipairs(services) do
		local route = planner.Changes(service, picked) and planner.Route(service) or baseline
		local preference = 0
		for _, segment in ipairs(route.segments) do
			if segment.recipeID == service.recipeID then
				preference = service.preference or 0
				break
			end
		end
		local savings = baseline.expectedCost - (route.expectedCost + service.fee)
		local helps = route.reachedSkill > baseline.reachedSkill
			or (route.reachedSkill == baseline.reachedSkill and (savings > 0 or preference > 0))
		if
			helps
			and (
				not best
				or route.reachedSkill > best.reachedSkill
				or (
					route.reachedSkill == best.reachedSkill
					and (
						preference > bestPreference
						or (
							preference == bestPreference
							and (
								savings > best.savings
								or (savings == best.savings and service.recipeID < best.recipeID)
							)
						)
					)
				)
			)
		then
			best = { recipeID = service.recipeID, savings = savings, reachedSkill = route.reachedSkill }
			bestPreference = preference
		end
	end
	return best
end

-- The one service worth training next on the learned route.
---@param snapshot SkillUpSnapshot
---@param services SkillUpService[]
---@return {recipeID: integer, savings: number, reachedSkill: number}?
function Model.RecommendTraining(snapshot, services)
	return Recommend(Planner(snapshot), services)
end

-- The learned route plus whatever training pays for itself: keep adding the
-- service RecommendTraining picks (reach first, then pin priority, then savings net of its fee),
-- then drop any a later addition made unnecessary. Greedy, so not guaranteed
-- optimal, but each fee is charged once and only for recipes the route uses.
---@param snapshot SkillUpSnapshot
---@param services SkillUpService[]
---@return SkillUpTrainedRoute
function Model.PlanWithTraining(snapshot, services)
	local remaining = {}
	for index, service in ipairs(services) do
		remaining[index] = service
	end
	local planner = Planner(snapshot)
	local chosen = {}
	while true do
		local best = Recommend(planner, remaining)
		if not best then
			break
		end
		for index, service in ipairs(remaining) do
			if service.recipeID == best.recipeID then
				planner.Add(service)
				chosen[service.recipeID] = service
				table.remove(remaining, index)
				break
			end
		end
	end
	local route = planner.Route()
	---@cast route SkillUpTrainedRoute
	local firstUse = {}
	for _, segment in ipairs(route.segments) do
		firstUse[segment.recipeID] = firstUse[segment.recipeID] or segment.fromSkill
	end
	-- An unused recipe never changes a greedy pick, so dropping it keeps the route.
	route.training, route.trainingCost = {}, 0
	for recipeID, service in pairs(chosen) do
		if firstUse[recipeID] then
			route.training[#route.training + 1] =
				{ recipeID = recipeID, fee = service.fee, atSkill = firstUse[recipeID] }
			route.trainingCost = route.trainingCost + service.fee
		end
	end
	table.sort(route.training, function(a, b)
		return a.atSkill < b.atSkill or (a.atSkill == b.atSkill and a.recipeID < b.recipeID)
	end)
	return route
end

-- The shopping list's buckets, in the order it lists them, and the price source that fills each;
-- a reagent with no price goes in "unknown". Everything that walks the list walks this.
---@type SkillUpShoppingSource[]
Model.SHOPPING_SOURCES = { "gather", "vendor", "auction", "unknown" }
---@type table<SkillUpPriceSource, SkillUpShoppingSource>
local BUCKET = { gather = "gather", vendor = "vendor", auctionator = "auction" }

-- The shopping list's bucket for a price source: what every item in the list carries as its source.
---@param source SkillUpPriceSource?
---@return SkillUpShoppingSource
function Model.ShoppingSource(source)
	return source and BUCKET[source] or "unknown"
end

---@param needed table<integer, number>
---@param sourceOf fun(itemID: integer): SkillUpPriceSource?
---@return table<string, SkillUpShoppingItem[]>
function Model.BucketNeeded(needed, sourceOf)
	local list = {}
	for _, source in ipairs(Model.SHOPPING_SOURCES) do
		list[source] = {}
	end
	for itemID, count in pairs(needed) do
		if count > 0 then
			local bucket = list[Model.ShoppingSource(sourceOf(itemID))]
			bucket[#bucket + 1] = { itemID = itemID, count = count }
		end
	end
	for _, bucket in pairs(list) do
		table.sort(bucket, function(a, b)
			return a.itemID < b.itemID
		end)
	end
	return list
end

-- Raw items, already totalled, into the shopping list's buckets.
---@param items {itemID: integer, count: number}[]
---@param sourceOf fun(itemID: integer): SkillUpPriceSource?
---@return table<string, SkillUpShoppingItem[]>
function Model.BucketItems(items, sourceOf)
	local needed = {}
	for _, item in ipairs(items) do
		if item.itemID then
			needed[item.itemID] = (needed[item.itemID] or 0) + item.count
		end
	end
	return Model.BucketNeeded(needed, sourceOf)
end

---@param recipeData table<integer, SkillUpRecipe>
---@return table<integer, integer[]>
function Model.BuildReagentIndex(recipeData)
	local index = {}
	for recipeID, recipe in pairs(recipeData) do
		local seen = {}
		for _, reagent in ipairs(recipe.reagents) do
			local itemID = reagent.itemID
			if not seen[itemID] then
				index[itemID] = index[itemID] or {}
				local recipes = index[itemID]
				recipes[#recipes + 1] = recipeID
				seen[itemID] = true
			end
		end
	end
	for _, recipes in pairs(index) do
		table.sort(recipes)
	end
	return index
end

-- Rounds so a row stays short: whole gold from 100g (123g), else whole silver from
-- 1s (1g 23s, 45s), else copper (80c).
---@param copper number
---@return number
function Model.RoundMoney(copper)
	if copper == 0 then
		return 0
	end
	local unit = copper >= 1000000 and 10000 or copper >= 100 and 100 or 1
	return math.max(math.floor(copper / unit + 0.5), 1) * unit
end
