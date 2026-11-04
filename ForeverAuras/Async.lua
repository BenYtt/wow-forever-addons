-- Modified for ForeverAuras, 2026-09-19.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
local GlobalAddonName = ...

---@class AddonDB
local AddonDB = select(2, ...)
-- Frames and hooks from this file are timed by the profiler (see AddonDB.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = AddonDB.TimedAPI("Async")

local CopyTable = CopyTable
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local SafePack = SafePack
local SafeUnpack = SafeUnpack
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local debugprofilestop = debugprofilestop
local debugstack = debugstack
local geterrorhandler = geterrorhandler
local ipairs = ipairs
local ipairs_reverse = ipairs_reverse
local max = math.max
local next = next
local setmetatable = setmetatable
local tinsert = tinsert
local tDeleteItem = tDeleteItem
local type = type
local xpcall = xpcall
local IsEncounterInProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress or IsEncounterInProgress

-- Each stream runs in FIFO order; streams share the frame budget.

--- @class AsyncConfig
--- @field maxTime number
--- @field maxTimeCombat number
--- @field errorHandler fun(msg: string, stacktrace?: string)
--- @field singleton boolean?
--- @field debug boolean? Enable debug info collection
--- @field name string? Optional name for easier identification

---@class AsyncThreadData
---@field type "AsyncThreadData"
---@field co thread
---@field debugStack string
---@field args any[]?
---@field paused boolean?
---@field parentData AsyncThreadData?
---@field executionTime number
---@field totalYields number?
---@field startTime number
---@field Kill fun(self: AsyncThreadData)
---@field OnSuccess fun(self: AsyncThreadData, func: function) -- fires before finally
---@field Catch fun(self: AsyncThreadData, err: string)
---@field Finally fun(self: AsyncThreadData, func: function)
---@field ForceRun fun(self: AsyncThreadData, maxDuration?: number)

local SLEEP = {}

--- @type AsyncConfig
local defaultConfig = {
	maxTime = 16, -- use 2 for background processing, 16 for low priority, 50 if process needs to be done asap
	maxTimeCombat = 2,
	errorHandler = geterrorhandler(),
}

local currentThreadData = nil ---@type AsyncThreadData?
AddonDB.AsyncEnvironment = setmetatable({}, {
	__index = function(_, k)
		if not currentThreadData then
			return nil
		end
		if k == "EXECUTION_TIME" then
			return currentThreadData.executionTime
		elseif k == "TOTAL_TIME" then
			return debugprofilestop() - currentThreadData.startTime
		elseif k == "TOTAL_YIELDS" then
			return currentThreadData.totalYields or 0
		end
	end,
})

function AddonDB:IsThread(val)
	return type(val) == "table" and val.type == "AsyncThreadData"
end

local function runThread(threadData, config, finalTime, globalStart)
  while debugprofilestop() < finalTime do
    local co = threadData.co
    if co and coroutine_status(co) ~= "dead" then
      local previousThreadData = currentThreadData
      currentThreadData = threadData
      local ok, msg, msg2
      local s = debugprofilestop()
      if threadData.args then
        ok, msg, msg2 = coroutine_resume(co, SafeUnpack(threadData.args))
        threadData.args = nil
      else
        ok, msg, msg2 = coroutine_resume(co)
      end
      currentThreadData = previousThreadData

      -- tracking execution time takes about 20% of the whole overhead
      local elapsed = debugprofilestop() - s
      threadData.executionTime = threadData.executionTime + elapsed
      threadData.totalYields = (threadData.totalYields or 0) + 1
      if config.debug then -- debug
        local stack = debugstack(co, 1, 1, 1)
        if not stack or stack == "" then
          stack = "<no stack>"
        end
        threadData.yieldDebugsByTime = threadData.yieldDebugsByTime or {}
        tinsert(threadData.yieldDebugsByTime, {
          time = elapsed,
          stack = stack,
          msg1 = msg,
          msg2 = msg2,
        })
        threadData.yieldDebugsByStack = threadData.yieldDebugsByStack or {}
        threadData.yieldDebugsByStack[stack] = (threadData.yieldDebugsByStack[stack] or 0) + elapsed
      end

      -- A rejected resume need not leave a dead coroutine. Do not retry it in
      -- this budget loop (or indefinitely from ForceRun).
      if not ok or coroutine_status(co) == "dead" then
        if config.debug then
          sort(threadData.yieldDebugsByTime or {}, function(a, b) return a.time > b.time end)
        end
        if threadData.parentData then
          threadData.parentData.args = { ok, msg }
          threadData.parentData.paused = false
        end
        if ok and threadData._onSuccess then
          for _, func in ipairs(threadData._onSuccess) do
            xpcall(func, geterrorhandler(), msg)
          end
        elseif not ok then
          msg = tostring(msg or "Async coroutine could not be resumed")
          local stack = (debugstack(co) or "") .. (threadData.debugStack or "")
          if threadData._onError then
            for _, func in ipairs(threadData._onError) do
              xpcall(func, geterrorhandler(), msg .. "\n" .. stack)
            end
          end
          if config.errorHandler == geterrorhandler() then -- combine full stack if default error handler
            xpcall(config.errorHandler, geterrorhandler(), msg .. "\n" .. stack)
          else
            xpcall(config.errorHandler, geterrorhandler(), msg, stack)
          end
        end
        threadData:Kill()
        return false, true -- we need a break to restart ipairs loop
      elseif ok and type(msg) == "table" and msg.type == "AsyncThreadData" then
        --[[
        nested coroutines are supported as replacement for yield inside pcall
        in case we did
        local ok, res|err = coroutine.yield(AddonDB:Async(config, func, ...))
        then we need to pause the thread
        so we can continue it after the yielded thread is finished
        just returning is not supported so we don't do that if coroutine is dead
        ]]
        threadData.paused = true
        msg.parentData = threadData
        break
      elseif ok and msg == SLEEP then
        threadData.sleep = debugprofilestop() + (msg2 or 0)
        return false, true
      end
    elseif threadData.co == nil then
      -- coroutine killed itself
      return false, true
    else
      threadData:Kill() -- shouldn't ever get there?
      error(GlobalAddonName .. ": Async threadData has dead coroutine, this should never happen\n\nThread stack:\n" .. threadData.debugStack)
      return false, true -- we need a break to restart ipairs loop
    end

    if globalStart and ((InCombatLockdown() or IsInInstance()) and (debugprofilestop() - globalStart > 100)) then
      return true
    end
  end
end

local AsyncFrame = CreateFrame("Frame")
local streams = {} ---@type table<AsyncConfig, AsyncThreadData[]>
local threadToConfig = {} ---@type table<AsyncThreadData, AsyncConfig>
AsyncFrame:SetScript("OnUpdate", function(self, elapsed)
	local globalStart = debugprofilestop()
	local hasData = false
	for config, queue in next, streams do
		for i, threadData in ipairs(queue) do
			hasData = true
			if not threadData.paused then
				if threadData.sleep and threadData.sleep > debugprofilestop() then
					break -- we dont want to run this stream while there is sleeping coroutine
				end

				local maxExecutionTime = ((InCombatLockdown() and IsInInstance()) or IsEncounterInProgress()) and config.maxTimeCombat or config.maxTime
				local finalTime = debugprofilestop() + maxExecutionTime
				local shouldReturn, shouldBreak = runThread(threadData, config, finalTime, globalStart)
        if shouldReturn then
          return
        end
        if shouldBreak then
          break
        end
			end
		end
	end
	if not hasData then
		self:Hide()
	end
end)


local function Kill(self)
	local config = threadToConfig[self]
	threadToConfig[self] = nil
	self.co = nil

	if config and streams[config] then
		if self._finally then
			for _, func in ipairs(self._finally) do
				xpcall(func, geterrorhandler(), self)
			end
			self._finally = nil
		end

		tDeleteItem(streams[config], self)
		if #streams[config] == 0 then
			streams[config] = nil
		end
	end
end

local function OnSuccess(self, func)
	if type(func) ~= "function" then
		error(GlobalAddonName .. ": Async OnSuccess func must be a function, got " .. type(func))
	end
	self._onSuccess = self._onSuccess or {}
	tinsert(self._onSuccess, func)
	return self
end

local function Catch(self, func)
	if type(func) ~= "function" then
		error(GlobalAddonName .. ": Async Catch func must be a function, got " .. type(func))
	end
	self._onError = self._onError or {}
	tinsert(self._onError, func)
	return self
end

local function Finally(self, func)
	if type(func) ~= "function" then
		error(GlobalAddonName .. ": Async Finally func must be a function, got " .. type(func))
	end
	self._finally = self._finally or {}
	tinsert(self._finally, func)
	return self
end

local function ForceRun(self, maxDuration)
  local config = threadToConfig[self]
  if not config then
    return
  end
  local finalTime = debugprofilestop() + (maxDuration or math.huge)
  runThread(self, config, finalTime)
end

--- @param config AsyncConfig
--- @param func function
--- @param ... any Optional arguments to pass to the function
--- @return AsyncThreadData
--- @overload fun(self: AddonDB, func: function, ...): AsyncThreadData
function AddonDB:Async(config, func, ...)
	local tconfig, f, overload = type(config), func
	if tconfig == "function" then
		-- if config is a function, treat it as the func and use default config
		f = config
		config = CopyTable(defaultConfig)
		overload = true
	elseif tconfig ~= "table" then
		config = CopyTable(defaultConfig)
	end

	if type(f) ~= "function" then
		error(GlobalAddonName .. ": Async function must be a function, got " .. type(f))
	end
	if type(config) ~= "table" then
		error(GlobalAddonName .. ": Async config must be a table, got " .. type(config))
	end

	if type(config.maxTime) ~= "number" or config.maxTime < 0 then
		config.maxTime = 16
	end

	if type(config.maxTimeCombat) ~= "number" then -- or config.maxTimeCombat < 0
		config.maxTimeCombat = 5
	end

	if type(config.errorHandler) ~= "function" then
		config.errorHandler = geterrorhandler()
	end

	local co = coroutine_create(f)

	--- @type AsyncThreadData
	local data = {
		type = "AsyncThreadData",
		co = co,
		debugStack = "Async start:\n"..(debugstack(2) or ""),
		args = overload and SafePack(func, ...) or SafePack(...),
		executionTime = 0,
		startTime = debugprofilestop(),
		Kill = Kill,
		OnSuccess = OnSuccess,
		Catch = Catch,
		Finally = Finally,
    ForceRun = ForceRun,
	}
	threadToConfig[data] = config

	if not streams[config] then
		streams[config] = {}
	end

	if config.singleton then
		for i, threadData in ipairs_reverse(streams[config]) do
			threadData:Kill() -- kill all previous threads in the singleton stream
		end
	end

	tinsert(streams[config], data)
	AsyncFrame:Show()
  if config.debug then
    if DevTool and DevTool.AddData then
      DevTool:AddData(data, "AsyncThreadData")
    end
  end
	return data
end

local function wrapper(config, func)
	return function(...)
		return AddonDB:Async(config, func, ...)
	end
end


---@generic T: function
---@param config table|T
---@param func T?
---@return T AsyncFunction callable async function
function AddonDB:WrapAsync(config, func)
	local tconfig, f = type(config), func
	if tconfig == "function" then
		-- if config is a function, treat it as the func and use default config
		f = config
		config = CopyTable(defaultConfig)
	elseif tconfig ~= "table" then
		config = CopyTable(defaultConfig)
	end
	return wrapper(config, f)
end

local function wrapperSingleton(config, func)
	local threadData = nil

	return function(...)
		if threadData then
			threadData:Kill()
		end
		threadData = AddonDB:Async(config, func, ...)
		return threadData
	end
end

---@generic T: function
---@param config table|T
---@param func T?
---@return T AsyncFunction callable async function than cancels previous thread when new one is started
function AddonDB:WrapAsyncSingleton(config, func)
	local tconfig, f = type(config), func
	if tconfig == "function" then
		-- if config is a function, treat it as the func and use default config
		f = config
		config = CopyTable(defaultConfig)
	elseif tconfig ~= "table" then
		config = CopyTable(defaultConfig)
	end
	return wrapperSingleton(config, f)
end

function AddonDB:Sleep(ms)
	coroutine_yield(SLEEP, ms)
end
