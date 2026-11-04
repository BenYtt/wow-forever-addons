---@type string, SkillUpNamespace
local _, ns = ...

-- Distinct own-character recipe observations, independent of recipes currently known. A profession drop never
-- erases these observations. No old learned flag is treated as a newly observed learning event.
---@class SkillUpStats
local Stats = {}
ns.Stats = Stats

local METRIC = "recipes_observed_learned"
local cached, count, pending = nil, 0, false

local function Character()
	return ns.db and ns.CharacterKey()
end

local function Record()
	local key = Character()
	if not key then
		return nil
	end
	local record = ns.db.observedRecipes[key]
	if type(record) ~= "table" or type(record.ids) ~= "table" then
		record = { ids = {}, eventUnix = 0 }
		ns.db.observedRecipes[key] = record
	end
	if cached ~= record then
		count = 0
		for id, seen in pairs(record.ids) do
			if type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0 and seen == true then
				count = count + 1
			else
				record.ids[id] = nil
			end
		end
		local stamp = record.eventUnix
		if type(stamp) ~= "number" or stamp < 1 or stamp % 1 ~= 0 or stamp > GetServerTime() + 300 then
			record.eventUnix = 0
		end
		cached = record
	end
	return record
end

local function Enabled()
	return ns.db ~= nil and ns.db.statsShare ~= false
end

local peer = ns.PeerStats.New({
	addon = "skillup",
	enabled = Enabled,
	db = function()
		local key = Character()
		if key then
			if type(ns.db.peerStats[key]) ~= "table" then
				ns.db.peerStats[key] = {}
			end
			return ns.db.peerStats[key]
		end
	end,
	snapshot = function()
		local record = Record()
		return record
				and count > 0
				and record.eventUnix > 0
				and { { metric = METRIC, subject = "all", value = count, eventUnix = record.eventUnix } }
			or {}
	end,
	metrics = { [METRIC] = { subject = "all" } },
})

-- Each scan can observe hundreds of recipes; offer its final total once on the next frame.
local function Schedule()
	if pending then
		return
	end
	pending = true
	C_Timer.After(0, function()
		pending = false
		peer:Sync()
	end)
end

---@param recipeID integer
---@return boolean
function Stats.Observe(recipeID)
	if type(recipeID) ~= "number" or recipeID <= 0 or recipeID >= math.huge or recipeID % 1 ~= 0 then
		return false
	end
	local record = Record()
	if not record or record.ids[recipeID] then
		return false
	end
	record.ids[recipeID] = true
	record.eventUnix = GetServerTime()
	count = count + 1
	Schedule()
	return true
end

function Stats.SetEnabled(enabled)
	peer:SetEnabled(enabled == true)
end

function Stats.Board()
	local record = Record()
	return peer:Board(METRIC, "all", record and count or 0, record and record.eventUnix)
end

function Stats.Print()
	local L = ns.L
	ns.Print(L["Distinct recipes observed learned on this character"])
	ns.Print(L["Guild and group totals are player-reported, not verified."])
	local board = Stats.Board()
	for _, row in ipairs(board) do
		if row.rank <= 10 or row.self then
			ns.Print((row.self and L["%d. %s (you): %d"] or L["%d. %s: %d"]):format(row.rank, row.name, row.value))
		end
	end
	if Enabled() then
		if #board == 1 then
			ns.Print(L["No guild or group member has reported yet."])
		end
		ns.Print(L["Sharing is on. Use /su share off to stop sharing."])
	else
		ns.Print(L["Sharing is off. Other players are hidden; your own history is kept."])
	end
end

ns.WhenEvent("PLAYER_LOGIN", Schedule)
