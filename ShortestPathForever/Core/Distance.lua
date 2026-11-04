---@class SPFNamespace
local ns = select(2, ...)
local L = ns.L

---@param yards number
---@param compact? boolean
---@return string
function ns.FormatDistance(yards, compact)
	local distance = ns.db.metres and yards * 0.9144 or yards
	if compact and distance >= 999.5 then
		return string.format(ns.db.metres and L["%.1f km"] or L["%.1fk yd"], distance / 1000)
	end
	return string.format(ns.db.metres and L["%d m"] or L["%d yd"], math.floor(distance + 0.5))
end
