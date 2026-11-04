---@class SPFNamespace
local ns = select(2, ...)

local Maps = {}
ns.CompanionMaps = Maps

---@class SPFCompanionPin : Frame
---@field isLeaMapsPin? boolean
---@field data? table
---@field u? number
---@field v? number
---@field look? table
---@field node? number
---@field kind? string

---@type {kind: string, x: number, y: number}[]
local pins = {}
local signature, nextScan = "", 0

local function Signature()
	local plan, current = ns.JourneyPlan()
	return signature .. ":" .. tostring(plan) .. ":" .. tostring(current)
end

-- Read visible pins, rather than private settings: coverage, faction and zoom rules belong to their producer.
---@param map SPFMapCanvas
---@return string
function Maps.Scan(map)
	local now = GetTime()
	if now < nextScan then
		return Signature()
	end
	nextScan = now + 0.25
	local canvas = map:GetCanvas()
	local width, height = canvas:GetWidth(), canvas:GetHeight()
	local left, top = canvas:GetLeft(), canvas:GetTop()
	local lea = C_AddOns.IsAddOnLoaded("Leatrix_Maps")
	local open = C_AddOns.IsAddOnLoaded("OpenMap") and ns.OpenMap.Stitched()
	local found, keys = {}, {}
	local function Visit(parent, recursive)
		for _, child in ipairs({ parent:GetChildren() }) do
			---@cast child SPFCompanionPin
			if child:IsVisible() then
				local kind
				if lea and child.isLeaMapsPin and child.data then
					local category = child.data[1]
					kind = type(category) == "string"
							and (category:match("^Flight") and "flight" or category:match("^Travel") and "travel" or category:match(
								"^Portal"
							) and "portal")
						or nil
				elseif open and child.u and child.v and child.look then
					kind = child.node and "flight"
						or (child.kind == "boat" or child.kind == "zeppelin") and child.kind
						or nil
				end
				if kind then
					local x, y = child:GetCenter()
					if x and left and top and width > 0 and height > 0 then
						local scale = child:GetEffectiveScale() / canvas:GetEffectiveScale()
						x, y = (x * scale - left) / width, (top - y * scale) / height
						found[#found + 1] = { kind = kind, x = x, y = y }
						keys[#keys + 1] = string.format("%s:%.5f:%.5f", kind, x, y)
					end
				elseif recursive then
					Visit(child, true)
				end
			end
		end
	end
	if lea then
		Visit(canvas, false)
	end
	if open then
		Visit(canvas:GetParent() or canvas, true)
	end
	table.sort(keys)
	pins, signature = found, table.concat(keys, ";")
	return Signature()
end

---@param kind string
---@param x number
---@param y number
---@param placeKind? SPFKind
---@param placeID? number
---@return boolean
function Maps.Suppresses(kind, x, y, placeKind, placeID)
	local plan, current = ns.JourneyPlan()
	if plan and placeID then
		for index = current, #plan.legs do
			local leg = plan.legs[index]
			if
				leg.from.kind == placeKind and leg.from.id == placeID
				or leg.to.kind == placeKind and leg.to.id == placeID
			then
				return false
			end
		end
	end
	for _, pin in ipairs(pins) do
		local matching = pin.kind == kind
			or pin.kind == "travel" and (kind == "boat" or kind == "zeppelin" or kind == "tram")
		if matching and math.abs(pin.x - x) < 0.008 and math.abs(pin.y - y) < 0.008 then
			return true
		end
	end
	return false
end
