---@class SPFNamespace
local ns = select(2, ...)

-- The walks a journey's search has measured, kept behind JourneySearch.lua: the drawn path of each walking leg,
-- searched once and shared by every plan that walks it, and the walks on from a bind point.
local WALK_CACHE_LIMIT = 64

---@class SPFJourneyWalks
local Walks = ns.JourneySearch.Walks
local SamePlace = ns.JourneySearch.SamePlace
local Context = ns.PlanContext

-- A finished leg search: the path it found (or the one it failed to replace), why it failed, its running yards.
---@class SPFMeasuredWalk
---@field points? SPFWalkPoints
---@field reason? string
---@field cost? number
---@field notes? string[]

---@type table<string, SPFMeasuredWalk>
local walkCache = {}
local walkOrder, walkPending, walkJobs = {}, {}, {}
local pathJobs, pathVersion = {}, 0
local pendingWalks = 0
-- What every walk here is searched to keep away from (Hazards.lua), and the walks on from bind points.
---@type SPFHazards?
local hazards
local landings

local function WalkKey(from, to)
	return table.concat({ from.map, from.x, from.y, from.z or "", to.x, to.y, to.z or "" }, ":")
end

local function CacheWalk(key, entry)
	if not walkCache[key] then
		walkOrder[#walkOrder + 1] = key
		if #walkOrder > WALK_CACHE_LIMIT then
			walkCache[table.remove(walkOrder, 1)] = nil
		end
	end
	walkCache[key] = entry
end

local function FindWalk(planned, leg, key, water, done)
	local version, previous = pathVersion, leg.walkPoints
	leg.walkDrawn = previous ~= nil
	leg.walkPoints = previous or ns.Planner.WalkPoints(leg.from, leg.to)
	local function apply(points, cost)
		leg.walkError = not points and cost or nil
		leg.walkPoints = points or previous or {}
		if points then
			leg.measured, leg.walkDrawn, leg.wet, leg.walkCost = true, true, points.wet, cost
			leg.hazardNotes = hazards and ns.Hazards.Notes(hazards, leg, points) or nil
			if planned.preview then
				leg.yards = cost
			end
		end
	end
	if walkPending[key] then
		walkPending[key][#walkPending[key] + 1] = { plan = planned, apply = apply }
		return
	end
	local waiting = { { plan = planned, apply = apply } }
	walkPending[key] = waiting
	pendingWalks = pendingWalks + 1
	local job = ns.Path.Find(leg.from.map, leg.from, leg.to, function(points, cost, finished)
		pathJobs[finished] = nil
		if version ~= pathVersion or finished.cancelled then
			return
		end
		pendingWalks = pendingWalks - 1
		walkPending[key], walkJobs[key] = nil, nil
		for _, entry in ipairs(waiting) do
			entry.apply(points, cost)
		end
		CacheWalk(key, {
			points = points or previous,
			reason = not points and cost or nil,
			cost = points and cost,
			notes = points and leg.hazardNotes,
		})
		if ns.db.debug and ns.Planner.WalkContradicts(leg, points and cost) then
			ns.Print(string.format("walking cost mismatch: planned %.1f, found %s", leg.yards, tostring(cost)))
		end
		done()
	end, water, hazards)
	pathJobs[job], walkJobs[key] = true, job
end

-- A plan that will not be followed: the searches only it waited for stop.
---@param planned SPFPlan
function Walks.Drop(planned)
	for key, waiting in pairs(walkPending) do
		for at = #waiting, 1, -1 do
			if waiting[at].plan == planned then
				table.remove(waiting, at)
			end
		end
		if #waiting == 0 then
			local job = walkJobs[key]
			pathJobs[job], walkPending[key], walkJobs[key] = nil, nil, nil
			pendingWalks = pendingWalks - 1
			ns.Path.Cancel(job)
		end
	end
end

-- The walk to draw now: the first one at or after the leg being followed. Costs prove every other walk, and its
-- drawing waits until it is the next one on foot.
---@param planned SPFPlan
---@param index integer?
---@return integer?
local function ActiveWalk(planned, index)
	for at = index or 1, #planned.legs do
		if planned.legs[at].mode == "walk" then
			return at
		end
	end
end

-- Whether the walk to draw now was put off until you could reach it.
---@param planned SPFPlan?
---@param index integer? the leg being followed
---@return boolean
function Walks.NeedsPrepare(planned, index)
	local _, _, _, map = ns.JourneyPosition()
	local at = planned and ActiveWalk(planned, index)
	local leg = planned and at and planned.legs[at]
	return leg ~= nil and leg.walkDeferred == true and leg.from.map == map
end

-- Gives each of a plan's walking legs its path: the measured one, or the best drawing there is while a search for
-- it runs. Only the walk being followed (or next) is searched; a later walk with a known cost, like one on a
-- continent not yet loaded, is put off until it is that walk. drawn are the legs on show, whose paths stand in for
-- the walks that replace them. done runs after each search lands, once its legs are updated.
---@param planned SPFPlan?
---@param drawn SPFLeg[]?
---@param water boolean? whether walks may cross water
---@param done fun()
---@param index integer? the leg being followed
function Walks.Prepare(planned, drawn, water, done, index)
	if not planned or (planned.prepared and not Walks.NeedsPrepare(planned, index)) then
		return
	end
	local resume = planned.prepared
	planned.prepared = true
	local _, _, _, map = ns.JourneyPosition()
	local active = ActiveWalk(planned, index)
	for at, leg in ipairs(planned.legs) do
		if leg.mode == "walk" and (not resume or at == active and leg.walkDeferred and leg.from.map == map) then
			leg.walkDeferred = nil
			local key = WalkKey(leg.from, leg.to)
			local entry = walkCache[key]
			leg.measured, leg.walkError, leg.walkCost = false, nil, leg.yards
			if entry then
				leg.walkPoints, leg.measured = entry.points or {}, entry.reason == nil
				leg.walkDrawn = entry.points ~= nil
				leg.wet, leg.walkError = entry.points and entry.points.wet, entry.reason
				leg.hazardNotes = entry.notes
				if entry.cost then
					leg.walkCost = entry.cost
					if planned.preview then
						leg.yards = entry.cost
					end
				end
			elseif
				not leg.estimated
				and (at ~= active or map and leg.from.map ~= map and not ns.Path.IsLoaded(leg.from.map))
			then
				-- Exact costs already prove this leg; draw it once it is the walk to follow, or its continent loads.
				leg.walkDeferred = true
				leg.walkPoints, leg.walkDrawn = ns.Planner.WalkPoints(leg.from, leg.to), false
			elseif leg.from.map == leg.to.map and ns.Path.HasData(leg.from.map) then
				-- A replacement may itself still be pending while drawing an older result; preserve that too.
				for _, previous in ipairs(drawn or {}) do
					if previous.mode == "walk" and SamePlace(previous.to, leg.to) and previous.walkDrawn then
						leg.walkPoints = previous.walkPoints
						break
					end
				end
				FindWalk(planned, leg, key, water, done)
			else
				leg.walkPoints, leg.walkError = {}, "nodata"
			end
		end
	end
end

-- What the search for a leg's walk found, once it has landed.
---@param leg SPFLeg
---@return SPFMeasuredWalk?
function Walks.Measured(leg)
	return walkCache[WalkKey(leg.from, leg.to)]
end

-- Leg searches still running.
---@return number
function Walks.Pending()
	return pendingWalks
end

-- Stops the leg searches in flight; their legs keep what they drew.
function Walks.Cancel()
	pathVersion = pathVersion + 1
	for job in pairs(pathJobs) do
		ns.Path.Cancel(job)
	end
	pathJobs, walkPending, walkJobs, pendingWalks = {}, {}, {}, 0
end

-- Measured in another water mode, or for a journey that is over.
function Walks.Clear()
	walkCache, walkOrder = {}, {}
end

-- Walks from now on keep away from these hazards; walks and landings measured with others are forgotten.
---@param profile SPFHazards?
function Walks.SetHazards(profile)
	hazards = profile
	Walks.Clear()
	for _, entry in pairs(landings) do
		if entry.job then
			ns.Path.Cancel(entry.job)
		end
	end
	landings = {}
end

-- The bind point moves, so its walks on to the fixed places cannot be baked like a class teleport's: each is searched
-- once per bind point and water mode, alongside the journey's own endpoint searches.
landings = {}
---@param place SPFTeleportPlace
---@param water boolean?
---@return {targets: SPFPlace[], costs?: (number|false)[], waiting?: fun()[]}?
local function Landing(place, water)
	if not (place.bind and ns.Path.HasData(place.map)) then
		return nil
	end
	local key = string.format("%d:%.17g:%.17g:%s", place.map, place.x, place.y, tostring(water))
	local entry = landings[key]
	if not entry then
		local mass, targets = Context.Landmass(place), {}
		-- Without the teleports' own destinations: a landing walks on to docks, flight points and portals.
		for _, target in ipairs((Context.Places())) do
			if target.map == place.map and Context.Landmass(target) == mass then
				targets[#targets + 1] = target
			end
		end
		entry = { targets = targets, waiting = {} }
		landings[key] = entry
		entry.job = ns.Path.FindMany(place.map, place, targets, function(costs)
			local waiting = entry.waiting or {}
			entry.costs, entry.waiting = costs, nil
			for _, callback in ipairs(waiting) do
				callback()
			end
		end, water, nil, nil, hazards)
	end
	return entry
end

-- Whether a bind point's walks are still being searched; callback, when given, runs once each search ends. With
-- ready, only a teleport castable before `before` counts: one ready later cannot beat a route arriving then.
---@param teleports SPFTeleportPlace[]?
---@param water boolean?
---@param callback? fun()
---@param ready? table<number, number>
---@param before? number
---@return boolean
function Walks.LandingPending(teleports, water, callback, ready, before)
	local pending = false
	for index, place in ipairs(teleports or {}) do
		local entry = Landing(place, water)
		if entry and entry.waiting and (not ready or (ready[index] and ready[index] < before)) then
			pending = true
			if callback then
				entry.waiting[#entry.waiting + 1] = callback
			end
		end
	end
	return pending
end

-- The measured walks on from each usable bind point.
---@param teleports SPFTeleportPlace[]?
---@param water boolean?
---@return SPFWalkCost[]
function Walks.Landings(teleports, water)
	local walks = {}
	for _, place in ipairs(teleports or {}) do
		local entry = Landing(place, water)
		local costs = entry and entry.costs
		if entry and costs then
			for i, target in ipairs(entry.targets) do
				walks[#walks + 1] = { from = place, to = target, cost = costs[i] }
			end
		end
	end
	return walks
end
