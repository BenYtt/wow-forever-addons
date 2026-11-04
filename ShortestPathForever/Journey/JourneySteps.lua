---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

-- How a journey step reads. The tracker and the public API's EstimateDetail share these words, so a step names
-- the same place in SPF's list and in another addon's travel line.
local SCHEDULED = { boat = true, zeppelin = true, lift = true, tram = true }
local STEP = {
	walk = L["Walk to %s"],
	flight = L["Fly to %s"],
	boat = L["Boat to %s"],
	zeppelin = L["Zeppelin to %s"],
	lift = L["Lift to %s"],
	tram = L["Tram to %s"],
	portal = L["Portal to %s"],
	passage = L["Go through to %s"],
	teleport = L["Teleport to %s"],
}
-- Why a walk has no path, keyed by Path's failure reason; the journey and the corpse run word it the same way.
ns.WalkFailure = {
	unreachable = L["no walking path"],
	offmesh = L["no walking path"],
	outside = L["no walking path"],
	nodata = L["walking map unavailable"],
	error = L["walking search failed"],
}

-- A flight point by the name its flight map last gave it, or the shipped English one until a flight map has.
---@param id number
---@return string
function ns.TaxiName(id)
	local names = ns.charDB.taxiNames
	return names and names[id] or ns.TaxiNodes[id].name
end

-- A place with no kind is the destination point as clicked or picked from a quest.
---@param node SPFPoint|SPFPlace
---@param mode? SPFMode
---@return string
function ns.PlaceLabel(node, mode)
	if node.kind == "start" then
		return L["your position"]
	elseif node.kind == "dock" then
		return (mode == "boat" or mode == "zeppelin") and ns.DockLabel(node.id) or ns.DockTitle(node.id)
	elseif node.kind == "taxi" then
		return ns.TaxiName(node.id)
	elseif node.kind == "portal" then
		return node.label
	elseif node.kind == "teleport" or node.kind == "goal" or node.kind == nil then
		local location = not node.label and ns.Locate(node)
		return node.label or location and location.zone or UNKNOWN
	end
	error("unknown journey node kind " .. tostring(node.kind))
end

-- The place a leg ends.
---@param leg SPFLeg
---@return string
function ns.LegLabel(leg)
	return ns.PlaceLabel(leg.to, leg.mode)
end

-- What to do on a leg: "Boat to Menethil Harbor".
---@param leg SPFLeg
---@return string
function ns.LegStep(leg)
	return string.format(STEP[leg.mode], ns.LegLabel(leg))
end

-- Whole seconds as a countdown shows them, so totals add up to the times on screen.
local function Seconds(ms)
	return math.max(0, math.ceil(ms / 1000))
end

-- A leg's remaining milliseconds: the observed progress along a flight being flown, else the planned span.
-- Counting an air leg down from the path rather than the clock keeps its time steady on a slow or fast ride.
---@param leg SPFLeg
---@return number
function ns.LegSpan(leg)
	local observed = ns.TaxiTimes and ns.TaxiTimes.Remaining(leg)
	return observed or (leg.arrive - leg.depart)
end

-- Only a timed transport's departure and a teleport's cooldown make a step wait; a flight leaves at once. A
-- transport nobody has timed yet waits half its round trip on average; "about" marks that guess.
---@param leg SPFLeg
---@return string
function ns.LegTime(leg)
	local text = ns.FormatCountdown(ns.LegSpan(leg))
	if leg.wait and leg.wait > 0 then
		local lead = leg.mode == "teleport" and L["ready in %s"]
			or leg.estimated and SCHEDULED[leg.mode] and L["leaves in about %s"]
			or L["leaves in %s"]
		text = string.format(L["%s · %s"], string.format(lead, ns.FormatCountdown(leg.wait)), text)
	end
	return text
end

-- The steps from index on, waits included, in the milliseconds of the whole seconds each step shows. The header
-- adds up the steps rather than counting down to the planned arrival, which would run on while you stand still
-- until the next retime put it back.
---@param legs SPFLeg[]
---@param index integer
---@return integer
function ns.JourneyTime(legs, index)
	local seconds = 0
	for legIndex = index, #legs do
		local leg = legs[legIndex]
		seconds = seconds + Seconds(ns.LegSpan(leg)) + Seconds(leg.wait or 0)
	end
	return seconds * 1000
end

-- Advance legs that can be completed from the player's current position. Keeping this
-- state machine beside the step vocabulary keeps the journey driver focused on refreshes.
function ns.AdvanceJourneyProgress(legs, progress, goal, riding, flying, near, guide)
	while progress.index <= #legs do
		local leg = legs[progress.index]
		local nextLeg = legs[progress.index + 1]
		if
			leg.mode == "walk"
			and nextLeg
			and ((nextLeg.route and riding == nextLeg.route) or (nextLeg.mode == "flight" and flying))
		then
			progress.index = progress.index + 1
			leg = nextLeg
		end
		local aboard = leg.aboard
			or leg.mode == "teleport"
			or (leg.route and riding == leg.route)
			or (leg.mode == "flight" and flying)
		if leg.mode ~= "walk" and not progress.departed then
			if aboard or near(leg.from) then
				progress.departed = true
			else
				guide.To(leg.from, nil, goal)
				return true
			end
		end
		if leg.mode == "teleport" and not near(leg.to) then
			guide.Cast(leg)
			return true
		end
		if not near(leg.to) or (leg.mode == "flight" and flying) then
			guide.To(leg.to, leg.walkPoints, goal)
			return true
		end
		if goal.hold and leg.mode == "walk" and not nextLeg then
			guide.To(leg.to, leg.walkPoints, goal)
			return true
		end
		progress.index, progress.departed = progress.index + 1, false
	end
	return goal.hold
end
