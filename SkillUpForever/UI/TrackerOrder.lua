---@type string, ForeverTrackerNamespace
local _, ns = ...

-- Section order for the shared objective-tracker column. A section with a uiOrder keeps that order; a companion addon's
-- section without one (SkillUp's profession reagents) follows them, and ties or unordered neighbours keep the order the
-- sections were first attached in, so the comparator is a strict weak ordering and never compares nil to a number.
local ranks = setmetatable({}, { __mode = "k" })
local attached = 0

local TrackerOrder = {}

---Orders `modules` in place for the layout pass.
---@param modules ForeverTrackerModule[]
function TrackerOrder.Sort(modules)
	for _, module in ipairs(modules) do
		if not ranks[module] then
			attached = attached + 1
			ranks[module] = attached
		end
	end
	table.sort(modules, function(a, b)
		local left, right = tonumber(a.uiOrder), tonumber(b.uiOrder)
		if left and right and left ~= right then
			return left < right
		end
		if (left == nil) ~= (right == nil) then
			return left ~= nil
		end
		return (ranks[a] or 0) < (ranks[b] or 0)
	end)
end

ns.TrackerOrder = TrackerOrder --[[@as ForeverTrackerOrderAPI]]
