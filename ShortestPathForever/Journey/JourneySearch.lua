---@class SPFNamespace
local ns = select(2, ...)

-- The search for a journey's fastest way: one bounded FindMany from where you stand and one back from the goal,
-- short A* probes for the candidate's own walks, the plan they settle, that plan's walking geometry (JourneyWalks.lua)
-- and whether it replaces the route you are following. A feasible route can be followed while the proof continues.
-- Journey.lua starts, steps and cancels the search and follows what it publishes.
local PROBE_BUDGET = 60 -- ms before switching from candidate costs to shared endpoint searches
local REFRESH_EVERY = 60
-- Timed replans replace the followed route only for a worthwhile gain; endpoint costs stay unchanged between
-- the infrequent batches, except for Remaining() along the walk you are following.
local SWITCH_GAIN, SWITCH_SHARE = 30000, 0.1

local Context = ns.PlanContext
---@class SPFJourneySearch
local Search = {}
ns.JourneySearch = Search
-- JourneyWalks.lua fills this in; nothing outside the search uses it.
---@class SPFJourneyWalks
local Walks = {}
Search.Walks = Walks

---@alias SPFSearchNews
---| "searching" a first search began: nothing to follow yet
---| "route" this route replaces the followed one (nil: no way there)
---| "walks" the followed route was retimed and its walks redrawn
---| "times" the followed route was retimed

-- The journey being searched for, as Start received it. followed is the route Journey is on: the one Start passed
-- or the last one published as "route". progress is Journey's own record, read here and never written.
local goal, followed
---@type {index: integer, departed?: boolean}
local progress
---@type fun(route: SPFPlan?, news: SPFSearchNews)
local publish
-- One search from its first batch to its single publication: the private candidate and how it may be committed.
local search
local FinishSearch
-- The mode this journey's walks were searched in, and the hazards they keep away from (Hazards.lua).
local waterMode
---@type SPFHazards?
local hazards
local lastRunSpeed = 7
local plannerCache = {}
local probeJobs, pathVersion = {}, 0
local startBatch, goalBatch, startAt
local refreshedAt = 0
local startCosts, goalCosts = {}, {}
local pendingCosts, settleRound = 0, 0
local costError
local costsWaiting

local function SamePlace(a, b)
	return a.map == b.map and a.x == b.x and a.y == b.y and a.z == b.z
end
Search.SamePlace = SamePlace

local function Here()
	local x, y, _, map = ns.JourneyPosition()
	return x and { map = map, x = x, y = y }
end

-- Cancelled searches leave both batches paused with their settled costs.
local function CancelPaths()
	pathVersion = pathVersion + 1
	for job in pairs(probeJobs) do
		ns.Path.Cancel(job)
	end
	Walks.Cancel()
	for _, batch in pairs({ start = startBatch, goal = goalBatch }) do
		if batch.job then
			ns.Path.Pause(batch.job)
		end
	end
	pendingCosts = 0
	probeJobs = {}
end

-- How much of the chosen walk is still ahead of here, from 0 to 1, or nil when here is off it.
local function RemainingShare(leg, here)
	local found, _, after, total = ns.OnWalk(leg.walkPoints, here)
	if found and total > 0 then
		return after / total
	end
end

-- The rest of the chosen walk in its own running yards, so water keeps its search weight.
local function Remaining(leg, here)
	local share = RemainingShare(leg, here)
	return share and (leg.walkCost or leg.yards) * share
end

-- The measured walks from where the batch started, moved to here, and back from the goal, with the rest of the walk
-- you are on.
---@param here SPFPoint
---@return SPFWalkCost[]
local function MeasuredWalks(here)
	local walks = {}
	for _, walk in ipairs(goalCosts) do
		walks[#walks + 1] = walk
	end
	if startAt and startAt.map == here.map then
		for _, walk in ipairs(startCosts) do
			walks[#walks + 1] = { from = here, to = walk.to, cost = walk.cost, estimated = walk.estimated }
		end
	end
	local leg = followed and followed.legs[progress.index]
	local rest = leg
		and followed.waterMode == waterMode
		and followed.hazards == (hazards and hazards.key)
		and leg.mode == "walk"
		and leg.measured
		and Remaining(leg, here)
	if rest then
		walks[#walks + 1] = { from = here, to = leg.to, cost = rest }
	end
	return walks
end

-- A plan being followed draws from the leg you are on; any other starts at its first.
local function PrepareWalks(planned)
	Walks.Prepare(
		planned,
		followed and followed.legs,
		waterMode,
		FinishSearch,
		planned == followed and progress.index or 1
	)
end

-- A route committed before its proof ended: the optimum replaces it once, whatever the gain, unless it is the same
-- journey.
local function Provisional()
	return followed ~= nil and followed.provisional == true
end

-- The same journey replanned from a few yards on: every leg goes the same way to the same place.
local function SameJourney(a, b)
	if not (a and b) or a.waterMode ~= b.waterMode or #a.legs ~= #b.legs - progress.index + 1 then
		return false
	end
	for index, leg in ipairs(a.legs) do
		local other = b.legs[index + progress.index - 1]
		if
			leg.mode ~= other.mode
			or leg.route ~= other.route
			or not SamePlace(leg.to, other.to)
			or (index > 1 and not SamePlace(leg.from, other.from))
		then
			return false
		end
	end
	-- A walk you have strayed from is searched again from where you are.
	local walk = b.legs[progress.index]
	if walk and walk.walkError then
		local here = Here()
		return here and SamePlace(walk.from, here)
	end
	return not (walk and walk.mode == "walk" and walk.measured) or ns.OnWalk(walk.walkPoints, Here()) ~= nil
end

-- Only the timings move, so the drawn route, Guide and any walk still being searched carry on undisturbed.
local function Retime(planned)
	followed.now, followed.arrive = planned.now, planned.arrive
	for index, leg in ipairs(planned.legs) do
		local kept = followed.legs[index + progress.index - 1]
		kept.depart, kept.arrive, kept.wait, kept.estimated = leg.depart, leg.arrive, leg.wait, leg.estimated
		kept.aboard, kept.yards, kept.ready = leg.aboard, leg.yards, leg.ready
	end
end

-- Compare against this route's own measured legs, at the same departure time as the challenger.
-- Reusing an earlier arrival would make the first offered route unfairly hard to replace.
local function EstimateKept(now)
	if not followed then
		return nil
	end
	local here = Here()
	local estimate = { now = now, arrive = now, legs = {} }
	for index = progress.index, #followed.legs do
		local leg = followed.legs[index]
		if index == progress.index and leg.route and not progress.departed and leg.depart < now then
			return nil
		end
		local duration, wait = leg.arrive - leg.depart, leg.wait or 0
		local yards = leg.yards or duration / 1000 * lastRunSpeed
		if leg.walkError then
			return nil
		end
		if leg.mode == "walk" then
			local entry = Walks.Measured(leg)
			if entry and entry.reason then
				return nil
			end
			local basis = entry and entry.cost or leg.walkCost or yards
			if index == progress.index and leg.measured then
				-- A share of the basis, never divided by the walk's own cost, which a measured walk may put at 0.
				local share = RemainingShare(leg, here)
				if not share then
					return nil
				end
				yards = basis * share
			else
				yards = basis
			end
			duration, wait = yards / lastRunSpeed * 1000, 0
		elseif leg.route and not leg.aboard then
			wait = ns.Routes[leg.route].period / 2
			if leg.boarding then
				local _, _, departIn = ns.Timetable.Visit(leg.route, leg.boarding, estimate.arrive)
				wait = departIn or wait
			end
		elseif index == progress.index and leg.aboard then
			duration, wait = math.max(0, leg.arrive - now), 0
		elseif leg.ready then
			wait = math.max(0, leg.ready - estimate.arrive)
		end
		local depart = estimate.arrive + wait
		estimate.arrive = depart + duration
		estimate.legs[#estimate.legs + 1] = {
			depart = depart,
			arrive = estimate.arrive,
			wait = wait,
			yards = yards,
			estimated = leg.estimated,
			aboard = leg.aboard,
		}
	end
	return estimate
end

---@param planned SPFPlan?
local function Commit(planned)
	followed = planned
	return publish(planned, "route")
end

-- A proved journey keeps exact endpoint vectors and their lower bounds, never suspended search stacks.
local function ReleaseCosts()
	for _, batch in pairs({ start = startBatch, goal = goalBatch }) do
		if batch.job then
			ns.Path.ReleaseMany(batch.job)
		end
	end
end

-- The first usable route of a search: a plan of settled walks alone, shown once the walk to take first is drawn.
-- The proof goes on, and its optimum replaces this route once. Returns whether that walk is still being drawn.
---@return boolean
local function Offer()
	local offer = search and search.offer
	if not offer or followed or pendingCosts == 0 then
		return false
	end
	local first = offer.legs[1]
	if first.walkError or first.walkDeferred then
		Walks.Drop(offer)
		search.offer = nil
	elseif first.mode ~= "walk" or first.measured then
		offer.provisional = true
		Commit(offer)
	else
		return true
	end
	return false
end

FinishSearch = function()
	local drawing = search and search.offer ~= nil and not followed
	if drawing and not Offer() and search and search.resume then
		-- The first walk is drawn, or failed: the proof it held back goes on.
		local resume = search.resume
		search.resume = nil
		resume()
	end
	-- The proof is in: an offer still drawing its first walk would only delay the route that beats it.
	if search and search.offer and not followed and pendingCosts == 0 and search.offer ~= search.candidate then
		Walks.Drop(search.offer)
		search.offer, search.resume = nil, nil
	end
	if not search or pendingCosts > 0 or Walks.Pending() > 0 then
		return
	end
	local planned, forced = search.candidate, search.forced
	local estimate = EstimateKept(planned and planned.now or ns.NowMs())
	local same = SameJourney(planned, followed)
	local gain = estimate and planned and estimate.arrive - planned.arrive
	-- A ride the planner preferred to a long walk is later than that walk by design, so its gain cannot argue for it
	-- against the walk already shown.
	local overWalk = planned
		and planned.preferred
		and followed
		and #followed.legs == 1
		and followed.legs[1].mode == "walk"
	local better = estimate
		and planned
		and gain
		and (overWalk or gain >= SWITCH_GAIN and gain >= (estimate.arrive - planned.now) * SWITCH_SHARE)
	local valid = true
	for _, leg in ipairs(planned and planned.legs or {}) do
		if leg.walkError then
			valid = false
		end
	end
	-- A route shown before its proof ended gives way to the proved one, whatever it gained or whether its walks
	-- failed, as a first search's route would have been committed; only the same journey stays.
	local provisional = Provisional()
	-- A first search draws every walk anew; a route shown before its proof ended already drew its first.
	local refine = search.refine or search.initial and not provisional
	local keep = followed
		and planned
		and estimate
		and (
			provisional and not forced and same
			or not provisional and (not valid or (not forced and (same or not better)))
		)
	if not keep and planned and not planned.prepared then
		PrepareWalks(planned)
		if Walks.Pending() > 0 then
			return
		end
	end
	search = nil
	ReleaseCosts()
	if keep then
		followed.provisional = nil
		Retime(same and planned or estimate)
		local changedWater = followed.waterMode ~= waterMode
		followed.waterMode = waterMode
		if refine or changedWater then
			for _, leg in ipairs(followed.legs) do
				if leg.mode == "walk" then
					local entry = Walks.Measured(leg)
					if entry then
						if refine then
							leg.walkPoints = entry.points or {}
						end
						leg.walkError, leg.wet = entry.reason, entry.points and entry.points.wet
						leg.measured, leg.walkCost = entry.reason == nil, entry.cost or leg.walkCost
					end
				end
			end
			followed.prepared = true
		end
		return publish(followed, refine and "walks" or "times")
	end
	return Commit(planned)
end

local function Render(planned, forced)
	search = search or { initial = not followed }
	search.candidate, search.forced = planned, forced
	local resume = Walks.NeedsPrepare(followed, progress.index)
	search.refine = followed and (not followed.prepared or resume)
	if resume then
		PrepareWalks(followed)
	end
	if followed and followed.waterMode ~= waterMode then
		local kept = { legs = {}, preview = true }
		for index = progress.index, #followed.legs do
			local copy = {}
			for key, value in pairs(followed.legs[index]) do
				copy[key] = value
			end
			kept.legs[#kept.legs + 1] = copy
		end
		PrepareWalks(kept)
	end
	local estimate = not search.initial
		and not forced
		and not Provisional()
		and EstimateKept(planned and planned.now or ns.NowMs())
	if estimate and planned and Walks.Pending() == 0 and not search.refine then
		local gain = estimate.arrive - planned.arrive
		if gain < SWITCH_GAIN or gain < (estimate.arrive - planned.now) * SWITCH_SHARE then
			FinishSearch()
			return
		end
	end
	-- Reusing the followed walk needs no new geometry and preserves Guide's passed bends.
	if search.refine or not SameJourney(planned, followed) then
		PrepareWalks(planned)
	end
	FinishSearch()
end

-- Feasible plans use known walks; the incumbent bounds the exact search while preserving journey preferences.
---@param feasible boolean?
---@param incumbent SPFPlan?
---@return SPFPlan?
local function Plan(feasible, incumbent)
	local here = Here()
	if not (here and goal) then
		return nil
	end
	-- Taxi paths cannot be interrupted; retain their chosen destination until landing.
	if followed and UnitOnTaxi("player") then
		lastRunSpeed, followed.now = Context.RunSpeed(), ns.NowMs()
		return followed
	end
	local options = Context.Options(here, goal)
	-- This is a manual refusal for the active journey only. Keep it out of Context.Options so
	-- public estimates and nearby-service planning retain the normal Hearthstone policy.
	options.withoutHearth = ns.JourneyWithoutHearth and ns.JourneyWithoutHearth() or false
	local now = options.now
	lastRunSpeed = options.walkSpeed
	local walks = MeasuredWalks(here)
	for _, walk in ipairs(Walks.Landings(options.teleports, waterMode)) do
		walks[#walks + 1] = walk
	end
	options.cache, options.walks, options.waterWalking, options.hazards = plannerCache, walks, waterMode, hazards
	options.feasibleOnly = feasible
	options.incumbent, options.incumbentPlan = incumbent and incumbent.arrive, incumbent
	options.ride = Context.Ride(options)
	local planned = ns.Planner.Plan(options)
	if planned then
		planned.now, planned.preview, planned.waterMode = now, nil, waterMode
		planned.hazards = hazards and hazards.key
	end
	return planned
end

-- Reuse only the last two endpoint searches, with starts confirmed by the pathfinder as the same snapped node.
-- One search owns the callbacks' shared revision, preview and probe budget across resumes
local function RefreshCosts(includeGoal, forced)
	local here = Here()
	if not (here and goal) then
		return
	end
	CancelPaths()
	search = { initial = not followed, forced = forced }
	local version = pathVersion
	local teleports = ns.UsableTeleports(ns.NowMs())
	local places, faction = Context.Places(teleports)
	local function targets(point, withGoal)
		local list = {}
		local mass = Context.Landmass(point)
		for _, place in ipairs(places) do
			if place.map == point.map and Context.Landmass(place) == mass then
				list[#list + 1] = place
			end
		end
		if withGoal and goal.map == point.map and Context.Landmass(goal) == mass then
			list[#list + 1] = goal
		end
		return list
	end
	local hazardKey = hazards and hazards.key
	local function reuse(batch, point, reverse)
		if
			not batch
			or batch.water ~= waterMode
			or batch.faction ~= faction
			or batch.teleports ~= teleports
			or batch.hazards ~= hazardKey
		then
			return false
		end
		if not reverse and not SamePlace(batch.goal, goal) then
			return false
		end
		return SamePlace(batch.point, point) or (not reverse and ns.Path.ReuseMany(batch.job, point))
	end
	local function create(previous, point, reverse)
		if reuse(previous, point, reverse) then
			return previous
		end
		if previous and previous.job then
			ns.Path.Cancel(previous.job)
		end
		return {
			point = point,
			goal = goal,
			targets = targets(point, not reverse),
			reverse = reverse,
			water = waterMode,
			faction = faction,
			teleports = teleports,
			hazards = hazardKey,
			costs = {},
		}
	end
	startBatch = create(startBatch, here, false)
	if includeGoal then
		goalBatch = create(goalBatch, goal, true)
	end
	startAt, refreshedAt = here, GetTime()
	pendingCosts, costError = 2, nil
	if search.initial then
		publish(nil, "searching")
	end
	local slices, lastRevision, probeCPU = 0, -1, 0
	local function fixedPlace(batch)
		if batch.fixedChecked or not (batch.job and batch.job.valid) then
			return
		end
		batch.fixedChecked = true
		for _, place in ipairs(places) do
			if
				place.map == batch.point.map
				and math.abs(place.x - batch.point.x) < 0.00001
				and math.abs(place.y - batch.point.y) < 0.00001
				and ns.Path.ReuseMany(batch.job, place)
			then
				batch.fixedKey = place.kind .. place.id
				return
			end
		end
	end
	local function bakedBound(batch, target)
		local first = batch.fixedKey
		local last = target.kind and target.kind .. target.id or target == goal and goalBatch.fixedKey
		local baked = first and last and ns.Walks[batch.point.map]
		if not baked then
			return 0
		end
		if first == last then
			return 0
		end
		if batch.reverse then
			first, last = last, first
		end
		local pair = baked[first < last and first .. " " .. last or last .. " " .. first]
		local cost = pair and pair[(waterMode and 2 or 1) + (first > last and pair[3] ~= nil and 2 or 0)]
		-- Baked costs round to whole yards. They strengthen the bound but never stand in for exact endpoint costs.
		return cost and math.max(0, cost - 0.5) or 0
	end
	local function walks(batch)
		local list = {}
		if not ns.Path.HasData(batch.point.map) then
			return list
		end
		local radius = batch.job and batch.job.radius or 0
		for i, target in ipairs(batch.reason ~= "nodata" and batch.targets or {}) do
			local cost = batch.probes and batch.probes[i]
			if cost == nil then
				cost = batch.costs[i]
			end
			local estimated = cost == nil
			if estimated then
				local lower = ns.Path.LowerBound(batch.point.map, batch.point, target)
				cost = math.max(lower, radius, bakedBound(batch, target))
			end
			list[#list + 1] = {
				from = batch.reverse and target or batch.point,
				to = batch.reverse and batch.point or target,
				cost = cost,
				estimated = estimated,
			}
		end
		return list
	end
	local function active(batch, needed)
		if needed then
			ns.Path.Resume(batch.job)
		else
			ns.Path.Pause(batch.job)
		end
	end
	local preview
	if not followed then
		startCosts, goalCosts = walks(startBatch), walks(goalBatch)
		preview = Plan()
		if preview then
			preview.preview, search.candidate = true, preview
		end
	end
	local consider
	-- Bounded search callback; splitting adds calls and upvalues on every frontier update
	consider = function(final)
		if version ~= pathVersion or not goal then
			return
		end
		if not ns.JourneyPosition() then
			costsWaiting = true
			return
		end
		if
			(not startBatch.done and not (startBatch.job and startBatch.job.valid))
			or (not goalBatch.done and not (goalBatch.job and goalBatch.job.valid))
		then
			return
		end
		local hadFixed = startBatch.fixedKey or goalBatch.fixedKey
		fixedPlace(startBatch)
		fixedPlace(goalBatch)
		if not hadFixed and (startBatch.fixedKey or goalBatch.fixedKey) then
			preview = nil
		end
		slices = slices + 1
		local revision = (startBatch.job and startBatch.job.revision or 0)
			+ (goalBatch.job and goalBatch.job.revision or 0)
		if not final and revision == lastRevision and slices < 16 then
			return
		end
		slices, lastRevision = 0, revision
		startCosts, goalCosts = walks(startBatch), walks(goalBatch)
		local goalError = goalBatch.reason
		-- Why an endpoint has no walk at all, a failed search first. A missing map is not one: its walks are estimated.
		local startError = startBatch.reason ~= "nodata" and startBatch.reason or nil
		costError = (startError == "error" or goalError == "error") and "error"
			or startError
			or goalError ~= "nodata" and goalError
			or nil
		-- An invalid goal also rules out the direct start -> goal edge without searching toward it.
		if goalError and goalError ~= "nodata" then
			startCosts[#startCosts + 1] = { from = here, to = goal, cost = false }
		end
		-- What the settled walks alone give: the arrival every other route must beat, and a route to follow if the
		-- proof still has far to go.
		local feasible = Plan(true)
		local bound = feasible and feasible.arrive
		local function best()
			return Plan(false, feasible)
		end
		-- Reuse the bounded preview once for probes; commit only after planning with current exact costs.
		local previewed = preview
			and not startBatch.reason
			and not goalBatch.reason
			and not (bound and preview.arrive >= bound)
		local planned = previewed and preview or best()
		preview = nil
		if
			feasible
			and planned
			and planned ~= feasible
			and (planned.needsStart or planned.needsGoal)
			and search.initial
			and (not startBatch.done or not goalBatch.done)
			and not search.offer
			and #feasible.legs > 0
		then
			search.offer = feasible
			PrepareWalks(feasible)
		end
		-- Drawing the offer's first walk takes the frame budget until it lands, then the proof goes on.
		local offering = Offer()
		-- Publishing an offer can synchronously stop or replace this journey.
		if version ~= pathVersion then
			return
		end
		if offering and planned and (planned.needsStart or planned.needsGoal) then
			active(startBatch, false)
			active(goalBatch, false)
			search.resume = function()
				consider(true)
			end
			return
		end
		-- Short A* cost probes let easy routes prove themselves before expanding a wide frontier. Bound
		-- their total work, then let shared Dijkstras settle harder alternatives. Finish an active probe:
		-- abandoning it near completion would make the batch repeat its work.
		if probeCPU < PROBE_BUDGET then
			local probes = {}
			for _, leg in ipairs(planned and planned.pendingWalks or {}) do
				local batch = leg.from.kind == "start" and startBatch or goalBatch
				local target = batch.reverse and leg.from or leg.to
				for i, point in ipairs(batch.targets) do
					if
						SamePlace(point, target)
						and batch.costs[i] == nil
						and (not batch.probes or batch.probes[i] == nil)
					then
						probes[#probes + 1] = { batch = batch, index = i, leg = leg }
						break
					end
				end
			end
			if #probes > 0 then
				planned.preview, search.candidate = true, planned
				active(startBatch, false)
				active(goalBatch, false)
				local left = #probes
				for _, probe in ipairs(probes) do
					local leg, batch = probe.leg, probe.batch
					local job = ns.Path.FindCost(leg.from.map, leg.from, leg.to, function(cost, reason, finished)
						probeJobs[finished] = nil
						if version ~= pathVersion then
							return
						end
						if cost or reason == "unreachable" or reason == "offmesh" or reason == "outside" then
							batch.probes = batch.probes or {}
							batch.probes[probe.index] = cost or false
						end
						probeCPU = probeCPU + finished.cpu
						left = left - 1
						if left == 0 then
							consider(true)
						end
					end, waterMode, hazards)
					probeJobs[job] = true
				end
				return
			end
		end
		if previewed then
			planned = best()
		end
		local needStart = planned and planned.needsStart and ns.Path.HasData(here.map)
		local needGoal = planned and planned.needsGoal and ns.Path.HasData(goal.map)
		-- Missing-map estimates remain the existing terminal fallback, never an endless search.
		needStart = needStart and not startBatch.done
		needGoal = needGoal and not goalBatch.done
		active(startBatch, needStart)
		active(goalBatch, needGoal)
		-- A bind point's walks still being searched, for a teleport that could be faster: settle when they end.
		local landing = not needStart
			and not needGoal
			and Walks.LandingPending(
				teleports,
				waterMode,
				nil,
				select(2, ns.UsableTeleports(ns.NowMs())),
				planned and planned.arrive or math.huge
			)
		if not needStart and not needGoal and not landing then
			pendingCosts, settleRound = 0, settleRound + 1
			Render(planned, forced)
		else
			if planned and planned ~= followed then
				planned.preview = true
			end
			search.candidate = planned
		end
	end
	-- A finished batch's answer: its costs, why it found none, and false for each target it never reached.
	local function settle(batch, costs, reason, job)
		batch.costs, batch.reason, batch.job = costs or {}, reason, job
		if job.done then
			batch.done = true
			for i = 1, #batch.targets do
				if batch.costs[i] == nil then
					batch.costs[i] = false
				end
			end
		end
	end
	local function attach(batch)
		local function update(costs, reason, job)
			if version ~= pathVersion or not goal then
				return
			end
			settle(batch, costs, reason, job)
			consider(batch.done)
		end
		local job = batch.job
		if job then
			job.callback, job.progress = update, update
			-- Reused from the search this one replaces, which paused it (CancelPaths). One that finished meanwhile
			-- lost its queued answer to the pause, so it is taken from the job; one never yet valid runs again, or
			-- nothing would ever answer. A valid one waits for consider, which resumes it only if it is needed.
			if job.done and not batch.done then
				settle(batch, job.costs, job.reason, job)
			elseif not job.valid and not batch.done then
				ns.Path.Resume(job)
			end
		else
			batch.job = ns.Path.FindMany(
				batch.point.map,
				batch.point,
				batch.targets,
				update,
				waterMode,
				batch.reverse,
				update,
				hazards
			)
		end
	end
	attach(startBatch)
	attach(goalBatch)
	Walks.LandingPending(teleports, waterMode, function()
		consider(true)
	end)
	-- Existing settled costs can prove a repeated journey without advancing either frontier.
	if (startBatch.job.valid or startBatch.done) and (goalBatch.job.valid or goalBatch.done) then
		consider(true)
	end
end

-- Stops the work in flight and forgets the search; the walks, costs and batches stay for the journey to resume with.
function Search.Cancel()
	CancelPaths()
	search = nil
end

-- A goal is about to start: stops the work in flight and forgets the measured costs, keeping the batches a repeated
-- journey may reuse. Walks drawn for the same goal in the same water mode are kept too, and only then is the journey
-- a repeat whose route and progress carry on.
---@param same boolean? the new goal is the place the last one was
---@return boolean? repeated
function Search.Clear(same)
	local repeated = same and (ns.JourneyWaterWalking()) == waterMode
	CancelPaths()
	costsWaiting = nil
	settleRound, costError = 0, nil
	startCosts, goalCosts, startAt = {}, {}, nil
	if not repeated then
		Walks.Clear()
	end
	return repeated
end

-- The journey is over: nothing of its search is kept.
function Search.Reset()
	Search.Clear(false)
	for _, batch in pairs({ start = startBatch, goal = goalBatch }) do
		if batch.job then
			ns.Path.Cancel(batch.job)
		end
	end
	startBatch, goalBatch = nil, nil
	search = nil
	-- plannerCache is kept: Planner.Plan rebuilds the graph itself whenever an input it was built from differs (its
	-- CACHE_KEYS, waterWalking and hazards among them) and rewrites the two endpoints for the new journey, so a
	-- journey started after this one plans against a warm graph instead of paying the whole build on its first
	-- click. The decoded walking grids are still released here.
	ns.Path.ClearCaches()
	goal, followed = nil, nil
end

-- The hazards a journey keeps away from, exempting where it started (the first readable position) and its goal;
-- walks searched with others no longer apply. Only a level-up or a setting changes them while the goal stays.
local origin
local function Avoid()
	origin = origin or Here()
	local profile = origin and goal and ns.Hazards.Profile(origin, goal) or nil
	if (profile and profile.key) ~= (hazards and hazards.key) then
		hazards = profile
		Walks.SetHazards(profile)
		startCosts, goalCosts = {}, {}
	end
end

-- Searches for the fastest way to point from where you stand. route is what Journey follows meanwhile (a repeated
-- journey's, else nil) and state its progress along it. listener hears every change to what Journey should follow,
-- possibly before Start returns.
---@param point SPFPoint
---@param route SPFPlan?
---@param state {index: integer, departed?: boolean}
---@param listener fun(route: SPFPlan?, news: SPFSearchNews)
function Search.Start(point, route, state, listener)
	goal, followed, progress, publish = point, route, state, listener
	search = nil
	waterMode = (ns.JourneyWaterWalking())
	origin = nil
	Avoid()
	RefreshCosts(true, false)
end

-- Once per driver frame with a readable position: restarts a search whose inputs changed or whose callbacks waited
-- for a position.
---@param changed? boolean the travel policy changed since the last frame
function Search.Poll(changed)
	if changed then
		-- A setting or your level changed what to avoid, from where you stand now.
		Avoid()
		RefreshCosts(true, true)
	end
	-- No batch has started, or a callback waited for a readable position.
	local stale = not startAt or costsWaiting
	costsWaiting = nil
	-- A journey started where no position could be read takes its hazards from the first one that can.
	if not hazards then
		Avoid()
	end
	-- Search callbacks may finish while position is unavailable; resume from readable endpoints.
	if stale then
		RefreshCosts(true, true)
	end
end

-- The timed replan, also due when the ride or run speed changes: searches again where the old costs no longer
-- apply, and otherwise plans in the frame with the costs it has.
---@param riding number? the route you are aboard
---@param flying boolean? on a taxi
---@param changedRide boolean either changed since the last frame
function Search.Replan(riding, flying, changedRide)
	local mode = ns.JourneyWaterWalking()
	if mode ~= waterMode then
		-- Walks searched in another water mode no longer apply.
		waterMode = mode
		Walks.Clear()
		startCosts, goalCosts = {}, {}
		RefreshCosts(true, false)
	elseif goalBatch ~= nil and goalBatch.teleports ~= ns.UsableTeleports(ns.NowMs()) then
		-- A new bind point or teleport: measure the walks on from where it lands.
		RefreshCosts(true, false)
	elseif pendingCosts == 0 and Walks.Pending() == 0 then
		local here = Here()
		local leg = followed and followed.legs[progress.index]
		local off = here and leg and leg.mode == "walk" and leg.measured and not ns.OnWalk(leg.walkPoints, here)
		local moved = here and startAt and not SamePlace(startAt, here)
		local retry = here
			and startAt
			and moved
			and (not followed or (leg and leg.walkError) or here.map ~= startAt.map)
		if not flying and not riding and (off or retry or GetTime() - refreshedAt >= REFRESH_EVERY) then
			RefreshCosts(false, off or retry)
		else
			local planned = Plan()
			if
				planned
				and (
					(planned.needsStart and here and ns.Path.HasData(here.map))
					or (planned.needsGoal and ns.Path.HasData(goal.map))
				)
			then
				-- A timed replan can expose an alternative left bounded by the previous proof.
				-- Resume its costs before letting it replace the route with settled geometry.
				RefreshCosts(false, changedRide)
			else
				Render(planned, changedRide)
			end
		end
	end
end

-- The run speed the last plan assumed.
---@return number
function Search.Speed()
	return lastRunSpeed
end

-- loading: a first search is still running, with at most a measured route to follow.
---@return number pending, number round, string? error, boolean loading
function Search.Status()
	return pendingCosts + Walks.Pending(), settleRound, costError, search ~= nil and search.initial
end
