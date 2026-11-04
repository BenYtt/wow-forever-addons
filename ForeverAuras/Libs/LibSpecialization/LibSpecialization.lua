-- Modified for ForeverAuras, 2026-09-19.
--@curseforge-project-slug: libspecialization@
local LS, oldminor = LibStub:NewLibrary("LibSpecialization-ForeverAuras", 28)
if not LS then return end -- No upgrade needed

LS.callbackMapGroup = LS.callbackMapGroup or {}
LS.callbackMapGuild = LS.callbackMapGuild or {}
LS.callbackMapPlayerSpecChange = LS.callbackMapPlayerSpecChange or {}
LS.frame = LS.frame or CreateFrame("Frame")

local callbackMapGroup = LS.callbackMapGroup
local callbackMapGuild = LS.callbackMapGuild

local type, error, format = type, error, string.format
local geterrorhandler, GetTime = geterrorhandler, GetTime

do
	local result = C_ChatInfo.RegisterAddonMessagePrefix("LibSpec")
	-- 0=success, 1=duplicate, 2=invalid, 3=toomany
	if type(result) == "number" and result > 1 then
		error("LibSpecialization: Failed to register the addon prefix.")
	end
end

-- Handle groups (comms are automatic)
function LS.RegisterGroup(addon, func)
	if type(addon) ~= "table" or addon == LS then
		error("LibSpecialization: The function lib.RegisterGroup expects your own addon object as the first arg.")
	end

	local t = type(func)
	if t == "function" then
		callbackMapGroup[addon] = func
	else
		error("LibSpecialization: The function lib.RegisterGroup expects your own function as the second arg.")
	end
end

function LS.UnregisterGroup(addon)
	if type(addon) ~= "table" or addon == LS then
		error("LibSpecialization: The function lib.UnregisterGroup expects your own addon object.")
	end
	callbackMapGroup[addon] = nil
end

-- Handle guilds (comms are on manual request)
function LS.RegisterGuild(addon, func)
	if type(addon) ~= "table" or addon == LS then
		error("LibSpecialization: The function lib.RegisterGuild expects your own addon object as the first arg.")
	end

	local t = type(func)
	if t == "function" then
		callbackMapGuild[addon] = func
	else
		error("LibSpecialization: The function lib.RegisterGuild expects your own function as the second arg.")
	end
end

function LS.UnregisterGuild(addon)
	if type(addon) ~= "table" or addon == LS then
		error("LibSpecialization: The function lib.UnregisterGuild expects your own addon object.")
	end
	callbackMapGuild[addon] = nil
end

function LS.RegisterPlayerSpecChange(addon, func)
	if type(addon) ~= "table" or addon == LS then
		error("LibSpecialization: The function lib.RegisterPlayerSpecChange expects your own addon object as the first arg.")
	end

	local t = type(func)
	if t == "function" then
		LS.callbackMapPlayerSpecChange[addon] = func
	else
		error("LibSpecialization: The function lib.RegisterPlayerSpecChange expects your own function as the second arg.")
	end
end

function LS.UnregisterPlayerSpecChange(addon)
	if type(addon) ~= "table" or addon == LS then
		error("LibSpecialization: The function lib.UnregisterPlayerSpecChange expects your own addon object.")
	end
	LS.callbackMapPlayerSpecChange[addon] = nil
end

-- Forever's specializations are supplied by the client, not a fixed ID list.
local function GetForeverSpecRole(specId)
  if type(specId) ~= "number" or specId <= 0 then return end
  local api = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID) or GetSpecializationInfoByID
  if api then
    local ok, _, _, _, _, role = pcall(api, specId)
    if not ok or (issecretvalue and issecretvalue(role)) then return end
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
      return role
    end
  end
end

local GetInfo
do
  -- The last readable answer. The client can hand back nothing, or a secret
  -- value, for the player's own specialization (seen in groups and in
  -- combat); then every "Player Class" load condition failed and the auras
  -- unloaded until some later event re-read it. A secret value is also not
  -- comparable, so it is tested before any arithmetic on it.
  local lastSpecId, lastRole
  local function Readable(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value)) and value > 0
  end
  function GetInfo()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not getSpec or not getInfo then return lastSpecId, lastRole, nil end
    local ok, spec = pcall(getSpec)
    if not ok or not Readable(spec) then return lastSpecId, lastRole, nil end
    local okInfo, specId, _, _, _, role = pcall(getInfo, spec)
    if not okInfo or not Readable(specId) then return lastSpecId, lastRole, nil end
    if issecretvalue and issecretvalue(role) then role = nil end
    role = GetForeverSpecRole(specId) or role
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then role = nil end
    lastSpecId, lastRole = specId, role
    -- No guessed melee/ranged position or talent export for Forever IDs.
    return specId, role, nil
  end
end
LS.MySpecialization = GetInfo

local throttleTimer = 3 -- Seconds
local pName = UnitNameUnmodified("player")
local SendAddonMessage = C_ChatInfo.SendAddonMessage
local IsInGroup = IsInGroup
local CTimerNewTimer = C_Timer.NewTimer
local next, securecallfunction = next, securecallfunction
local RequestGroupSpecialization
do
	local prev = 0
	local timer = nil
	local InChatMessagingLockdown = C_ChatInfo.InChatMessagingLockdown or function() end
	function RequestGroupSpecialization()
		local specId, role, position, talentString = GetInfo()
		if specId then
			for _,func in next, callbackMapGroup do
				securecallfunction(func, specId, role, position, pName, talentString) -- This allows us to show our own spec info when not grouped
			end
		end

		if IsInGroup() then
			if InChatMessagingLockdown() then
				LS.frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
				return
			end

			local t = GetTime()
			if t-prev > throttleTimer then
				if timer then
					timer:Cancel()
					timer = nil
				end
				prev = t
				if IsInGroup(2) then
					SendAddonMessage("LibSpec", "R", "INSTANCE_CHAT")
				end
				if IsInGroup(1) then
					SendAddonMessage("LibSpec", "R", "RAID")
				end
			elseif not timer then
				timer = CTimerNewTimer((throttleTimer+0.1)-(t-prev), RequestGroupSpecialization)
			end
		end
	end
end

do
	local currentSpecId, currentTalentString = 0, nil

	local PrepareForInstance
	do
		local timerInstance = nil
		local function SendToInstance()
			if timerInstance then
				timerInstance:Cancel()
				timerInstance = nil
			end
			if IsInGroup(2) then
				do
					local result = SendAddonMessage("LibSpec", format("%d,%s", currentSpecId, currentTalentString or ""), "INSTANCE_CHAT")
					if result == 3 or result == 8 or result == 9 then -- AddonMessageThrottle, ChannelThrottle, GeneralError
						timerInstance = CTimerNewTimer(throttleTimer, SendToInstance)
					end
				end
			end
		end
		local prev = 0
		function PrepareForInstance()
			local specId, role, _, talentString = GetInfo()
			if specId then
				currentSpecId = specId
				currentTalentString = talentString
				local t = GetTime()
				if t-prev > throttleTimer then
					prev = t
					SendToInstance()
				elseif not timerInstance then
					timerInstance = CTimerNewTimer((throttleTimer+0.1)-(t-prev), SendToInstance)
				end
			end
		end
	end

	local PrepareForGroup
	do
		local timerGroup = nil
		local function SendToGroup()
			if timerGroup then
				timerGroup:Cancel()
				timerGroup = nil
			end
			if IsInGroup(1) then
				do
					local result = SendAddonMessage("LibSpec", format("%d,%s", currentSpecId, currentTalentString or ""), "RAID") -- RAID auto downgrades to PARTY as needed
					if result == 3 or result == 8 or result == 9 then -- AddonMessageThrottle, ChannelThrottle, GeneralError
						timerGroup = CTimerNewTimer(throttleTimer, SendToGroup)
					end
				end
			end
		end
		local prev = 0
		function PrepareForGroup()
			local specId, role, _, talentString = GetInfo()
			if specId then
				currentSpecId = specId
				currentTalentString = talentString
				local t = GetTime()
				if t-prev > throttleTimer then
					prev = t
					SendToGroup()
				elseif not timerGroup then
					timerGroup = CTimerNewTimer((throttleTimer+0.1)-(t-prev), SendToGroup)
				end
			end
		end
	end

	local PrepareForGuild
	do
		local guildTimer = nil
		local function SendToGuild()
			if guildTimer then
				guildTimer:Cancel()
				guildTimer = nil
			end
			if IsInGuild() then
				do
					local result = SendAddonMessage("LibSpec", format("%d,%s", currentSpecId, currentTalentString or ""), "GUILD")
					if result == 3 or result == 8 or result == 9 then -- AddonMessageThrottle, ChannelThrottle, GeneralError
						guildTimer = CTimerNewTimer(throttleTimer, SendToGuild)
					end
				end
			end
		end
		local prev = 0
		function PrepareForGuild()
			local specId, role, _, talentString = GetInfo()
			if specId then
				currentSpecId = specId
				currentTalentString = talentString
				local t = GetTime()
				if t-prev > throttleTimer then
					prev = t
					SendToGuild()
				elseif not guildTimer then
					guildTimer = CTimerNewTimer((throttleTimer+0.1)-(t-prev), SendToGuild)
				end
			end
		end
	end

	local approved = {
		RAID = callbackMapGroup,
		PARTY = callbackMapGroup,
		INSTANCE_CHAT = callbackMapGroup,
		GUILD = callbackMapGuild,
	}
	local tonumber, strmatch = tonumber, string.match
	local Ambiguate = Ambiguate
	LS.frame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
		if event == "CHAT_MSG_ADDON" then
			if prefix == "LibSpec" and approved[channel] then -- Only approved channels
				if msg == "R" then
					if channel == "GUILD" then
						PrepareForGuild()
					elseif channel == "INSTANCE_CHAT" then
						PrepareForInstance()
					else -- RAID/PARTY
						PrepareForGroup()
					end
					return
				end

				local spec, talentString = strmatch(msg, "^(%d+),(.*)$")
				local specId = tonumber(spec)
				

				local role, position = GetForeverSpecRole(specId), nil
                if role then
					
					local playerName = Ambiguate(sender, "none")
					local talents = talentString and #talentString > 2 and talentString or nil
					for _,func in next, approved[channel] do
						securecallfunction(func, specId, role, position, playerName, talents)
					end
				end
			end
		elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
			for _,func in next, LS.callbackMapPlayerSpecChange do
				securecallfunction(func) -- Notify when the player has changed their spec
			end
			if IsInGroup() then
				if IsInGroup(2) then -- Instance group
					PrepareForInstance()
				end
				if IsInGroup(1) then -- Normal group
					PrepareForGroup()
				end
			else
				local specId, role, position, talentString = GetInfo()
				if specId then
					for _,func in next, callbackMapGroup do
						securecallfunction(func, specId, role, position, pName, talentString) -- This allows us to show our own spec info when not grouped
					end
				end
			end
		elseif event == "GROUP_FORMED" then -- Join new group
			RequestGroupSpecialization()
		elseif event == "PLAYER_LOGIN" then
			RequestGroupSpecialization()
			-- Calling this again will schedule a delayed request. We want to do this in case we logged into an active encounter, but InChatMessagingLockdown didn't signal this in the first check.
			RequestGroupSpecialization()
		elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
			if prefix == 5 and msg == 0 then -- [prefix=restrictionType] 5=Chat restriction, [msg=state] 0=Inactive
				self:UnregisterEvent(event)
				RequestGroupSpecialization()
				-- Calling this again will schedule a delayed request. We want to do this in case we requested group data a millisecond too early, and not everyone in the group was out of chat lockdown to hear our request.
				RequestGroupSpecialization()
			end
		end
	end)
	LS.frame:RegisterEvent("CHAT_MSG_ADDON")
	LS.frame:RegisterEvent("GROUP_FORMED")
	do
		LS.frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
	end
	LS.frame:RegisterEvent("PLAYER_LOGIN")
end

do
	function LS.RequestGroupSpecialization()
		-- DEPRECATED. This function was never supposed to be used as this library handles communication automatically.
		-- Explicit requests duplicate the automatic synchronization traffic.
	end
end

do
	local prev = 0
	local timer = nil
	function LS.RequestGuildSpecialization() -- Guild comms are manual, you will need to manually request data each time
		local specId, role, position, talentString = GetInfo()
		if specId then
			for _,func in next, callbackMapGuild do
				securecallfunction(func, specId, role, position, pName, talentString) -- This allows us to show our own spec info when not grouped
			end
		end

		if IsInGuild() then
			local t = GetTime()
			if t-prev > throttleTimer then
				if timer then
					timer:Cancel()
					timer = nil
				end
				prev = t
				SendAddonMessage("LibSpec", "R", "GUILD")
			elseif not timer then
				timer = CTimerNewTimer((throttleTimer+0.1)-(t-prev), LS.RequestGuildSpecialization)
			end
		end
	end
end

if IsLoggedIn() and not oldminor then -- Player is logged in and library isn't upgrading
	RequestGroupSpecialization()
end
