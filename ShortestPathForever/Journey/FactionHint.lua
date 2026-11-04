---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- With "Other Faction's Routes" off, the journey's goal pin says how much faster the journey would be through the
-- other faction's boats and zeppelins: one line of time, never a word on safety. It shows only for a saving of two
-- minutes or more over the plan being followed. The other plan is made as Estimate does (baked walks, no endpoint
-- searches, average waits for boats not yet seen), which can be out by about that much, and one death and graveyard
-- run costs more than that anyway. Nothing is said on a ride or a flight, or during a corpse run.

local THRESHOLD = 120000
-- A comparison stands this long (ms) for the same goal and much the same place.
local KEEP, MOVED = 30000, 50
local FACTIONS = { Horde = L["Horde"], Alliance = L["Alliance"] }

-- The other policy's own topology: the planner mutates its cache between calls. Dropped with the journey.
local cache = {}
---@type {goal: SPFPoint, at: number, x: number, y: number, map: number, text: string|false}?
local last

-- The other faction's transport a plan rides, if any.
---@param plan SPFPlan
---@param faction string
---@return string?
local function OtherFaction(plan, faction)
	for _, leg in ipairs(plan.legs) do
		local route = leg.route and ns.Routes[leg.route]
		if route and route.faction and route.faction ~= faction then
			return route.faction
		end
	end
end

---@param from SPFPoint
---@param goal SPFPoint
---@param own SPFPlan? the plan being followed; nil when the journey found no way
---@return string|false
local function Compare(from, goal, own)
	local options = ns.PlanContext.Options(from, goal)
	local faction = options.faction
	if not (faction and FACTIONS[faction]) then
		return false
	end
	options.cache, options.otherFaction = cache, true
	options.waterWalking, options.withoutHearth = ns.JourneyWaterWalking(), ns.JourneyWithoutHearth()
	local other = ns.Planner.Plan(options)
	local through = other and OtherFaction(other, faction)
	if not (other and through) then
		return false
	end
	if not own then
		return string.format(L["Through %s transport, there is a way"], FACTIONS[through])
	end
	local saving = own.arrive - other.arrive
	if saving < THRESHOLD then
		return false
	end
	return string.format(
		L["Through %s transport: about %d min faster"],
		FACTIONS[through],
		math.floor(saving / 60000 + 0.5)
	)
end

-- The goal pin's line, or nil: only with the setting off, out of combat, on foot, for the journey under way once its
-- search has settled.
---@return string?
function ns.OtherFactionHint()
	local goal = ns.JourneyGoal()
	if not goal or ns.db.otherFaction then
		cache, last = {}, nil
		return nil
	end
	if InCombatLockdown() or (ns.Corpse and ns.Corpse.Info()) then
		return nil
	end
	if ns.CurrentRide() or ns.IsObservingRide() or UnitOnTaxi("player") then
		return nil
	end
	local title, _, own, _, loading = ns.JourneyInfo()
	if not title or loading then
		return nil
	end
	local x, y, _, map = ns.JourneyPosition()
	if not (x and y and map) then
		return nil
	end
	local now = ns.NowMs()
	local kept = last
	if
		not kept
		or kept.goal ~= goal
		or kept.map ~= map
		or now - kept.at > KEEP
		or (kept.x - x) ^ 2 + (kept.y - y) ^ 2 > MOVED ^ 2
	then
		kept =
			{ goal = goal, at = now, x = x, y = y, map = map, text = Compare({ map = map, x = x, y = y }, goal, own) }
		last = kept
	end
	return kept.text or nil
end
