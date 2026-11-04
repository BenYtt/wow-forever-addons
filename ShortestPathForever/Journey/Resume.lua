---@class SPFNamespace
local ns = select(2, ...)

-- With "Keep journeys after a reload" on, a journey you planned yourself (a map or minimap click, /way, a quest,
-- Nearby services) survives a /reload or logging back in: its goal is kept in charDB.journey and started again once
-- the world is up and combat is over. Addons that own their journeys (Adventure Guide, TomTom's arrow, RestedXP,
-- Polestar through the API) start theirs again themselves and go first: any journey started by then wins and the
-- kept one is dropped. Kept for half an hour after the reload or logout.

local KEEP = 30 * 60
-- Seconds after the loading screen, so owners and TomTom's restored arrow can start theirs first.
local SETTLE = 2
-- Nearby services starts its journeys through the API under this addon's own name: those are the player's too.
local OWN = "Shortest Path Forever"

---@param value any
---@return number?
local function Finite(value)
	value = tonumber(value)
	return value and value == value and math.abs(value) < math.huge and value or nil
end

-- The journey kept from before the reload, taken at its loading screen. It waits for the owners, then for combat to
-- end, and is dropped as soon as any other journey starts or ends.
---@type SPFKeptJourney?
local kept
local entered, settled = false, false

---@param point SPFPoint?
local function Keep(point)
	-- Anything that changes guidance after the loading screen overrides what was kept from before it.
	if entered then
		kept = nil
	end
	if not (ns.db and ns.charDB) then
		return
	end
	local owner = ns.JourneyOwner()
	if not (point and ns.db.resumeJourney and (owner == nil or owner == OWN)) then
		ns.charDB.journey = nil
		return
	end
	local label = point.label
	ns.charDB.journey = {
		map = point.map,
		x = point.x,
		y = point.y,
		z = point.z,
		label = canaccessvalue(label) and type(label) == "string" and label or nil,
		questID = point.questID,
		pinBadge = point.pinBadge or nil,
		at = GetServerTime(),
	}
end

hooksecurefunc(ns, "JourneyChanged", Keep) -- taint-ok: ns is this addon's own namespace table.

-- Settings.lua: the setting changed; turned on, the journey under way is kept straight away.
function ns.KeepJourneyChanged()
	Keep(ns.db.resumeJourney and ns.JourneyGoal() or nil)
end

local frame

-- The one attempt is over: only the logout stamp is left to listen for.
local function Done()
	frame:UnregisterAllEvents()
	frame:RegisterEvent("PLAYER_LOGOUT")
end

-- Starts the kept journey, or forgets it when it is too old, turned off, or another journey is under way.
local function Resume()
	local resume = kept
	if not (resume and settled) or InCombatLockdown() then
		return
	end
	kept = nil
	Done()
	if ns.charDB.journey == resume then
		ns.charDB.journey = nil
	end
	local age = GetServerTime() - (Finite(resume.at) or 0)
	if not (ns.db.resumeJourney and ns.db.journey) or ns.JourneyGoal() or age < 0 or age > KEEP then
		return
	end
	local map, x, y = Finite(resume.map), Finite(resume.x), Finite(resume.y)
	if not (map and x and y) then
		return
	end
	-- Behind a corpse run, StartJourney queues it for when you are alive again.
	ns.StartJourney({
		map = map,
		x = x,
		y = y,
		z = Finite(resume.z),
		label = type(resume.label) == "string" and resume.label or nil,
		questID = Finite(resume.questID),
		pinBadge = resume.pinBadge == true or nil,
	})
end

ns.Init(function()
	frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LOGOUT")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGOUT" then
			-- Half an hour from leaving, not from planning: a long journey survives its reload.
			local journey = ns.charDB and ns.charDB.journey
			if type(journey) == "table" then
				journey.at = GetServerTime()
			end
		elseif event == "PLAYER_REGEN_ENABLED" then
			Resume()
		elseif not entered then
			-- Only the loading screen that ends a login or reload: later ones keep the journey running anyway.
			entered = true
			local journey = ns.charDB.journey
			kept = type(journey) == "table" and journey or nil
			if not kept then
				Done()
				return
			end
			frame:RegisterEvent("PLAYER_REGEN_ENABLED")
			C_Timer.After(SETTLE, function()
				settled = true
				Resume()
			end)
		end
	end)
end)
