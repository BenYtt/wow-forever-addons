---@class SPFNamespace
local ns = select(2, ...)

-- Render-only corner cutting: keep flight endpoints and loading boundaries, with no spline overshoot.
-- The source points stay intact for timing and navigation. Geometry is reused at every map zoom.
---@type table<SPFDrawPath, SPFPoint[]>
local smoothed = setmetatable({}, { __mode = "k" })

---@param path SPFDrawPath
---@return SPFPoint[]
function ns.FlightLinePoints(path)
	if path.mode ~= "flight" or path.preview then
		return path.points
	end
	if smoothed[path] then
		return smoothed[path]
	end
	local points = path.points
	for _ = 1, 3 do
		local rounded = {}
		for index, point in ipairs(points) do
			local before, after = points[index - 1], points[index + 1]
			if
				before
				and after
				and before.map == point.map
				and after.map == point.map
				and not before.jump
				and not point.jump
			then
				for _, near in ipairs({ before, after }) do
					rounded[#rounded + 1] = {
						map = point.map,
						x = point.x * 0.75 + near.x * 0.25,
						y = point.y * 0.75 + near.y * 0.25,
					}
				end
			else
				rounded[#rounded + 1] = point
			end
		end
		points = rounded
	end
	smoothed[path] = points
	return points
end
