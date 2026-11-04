local _, ns = ...

-- Caught errors for the report window. ns.SafeCall runs a callback as pcall does, keeps the last few errors with a
-- short stack, and still hands each one to the game's error handler, so BugSack and the default error frame see
-- exactly what they saw before. Nothing here knows about the rest of the addon.

local MAX_ERRORS = 5
local MAX_MESSAGE = 300
local STACK_LINES = 4

---@class ForeverCaughtError
---@field label string where it was caught, e.g. "route listener"
---@field message string the error, cut to 300 characters
---@field rawMessage string the full error, for exact deduplication
---@field stack string up to four stack lines, outermost last
---@field count integer how many times this label and message were caught this session

-- Oldest first; a repeat moves to the end with its count raised.
---@type ForeverCaughtError[]
local caught = {}

---@param text string
---@param limit integer
---@return string
local function Cut(text, limit)
	if #text <= limit then
		return text
	end
	local stop = limit - 3
	-- Back off a UTF-8 continuation byte, so a character is never split.
	while stop > 0 and text:byte(stop + 1) and text:byte(stop + 1) >= 0x80 and text:byte(stop + 1) < 0xC0 do
		stop = stop - 1
	end
	return text:sub(1, stop) .. "..."
end
ns.CutText = Cut

-- Keep `message` from `label`, with `stack` (a traceback) cut to its first lines that name a file.
---@param label string
---@param message any
---@param stack? string
function ns.RecordError(label, message, stack)
	local rawMessage = tostring(message)
	message = Cut(rawMessage, MAX_MESSAGE)
	local lines = {}
	for line in (stack or ""):gmatch("[^\n]+") do
		line = strtrim(line)
		-- LuaJIT writes "file.lua:12:", the client '[string "@Interface/AddOns/.../file.lua"]:12:'.
		if #lines < STACK_LINES and line:find("%.lua%S-:%d+") then
			lines[#lines + 1] = line
		end
	end
	local entry
	for index, old in ipairs(caught) do
		if old.label == label and old.rawMessage == rawMessage then
			entry = table.remove(caught, index)
			break
		end
	end
	entry = entry or { label = label, message = message, rawMessage = rawMessage, count = 0 }
	entry.stack, entry.count = table.concat(lines, "\n"), entry.count + 1
	caught[#caught + 1] = entry
	if #caught > MAX_ERRORS then
		table.remove(caught, 1)
	end
end

-- The errors caught this session, oldest first, as copies.
---@return ForeverCaughtError[]
function ns.CaughtErrors()
	local copies = {}
	for index, entry in ipairs(caught) do
		copies[index] = {
			label = entry.label,
			message = entry.message,
			rawMessage = entry.rawMessage,
			stack = entry.stack,
			count = entry.count,
		}
	end
	return copies
end

-- The labels of the SafeCalls under way, innermost last: the message handler names the call it runs in.
---@type string[]
local labels = {}

-- xpcall's message handler, at the error, before the stack unwinds: keep it for the report, then hand it to the
-- game's error handler here, so BugSack and the error frame capture the stack and locals where it happened.
local function Trace(message)
	ns.RecordError(labels[#labels] or "?", message, debugstack and debugstack(2) or debug.traceback())
	pcall(geterrorhandler(), message)
	return message
end

local function Finish(...)
	labels[#labels] = nil
	return ... -- multi-value: xpcall's answers, as pcall gives them
end

-- Run fn(...) as pcall would: true and its results, or false and the error. A failure is kept for the report and
-- passed on to the game's error handler, never swallowed.
---@param label string where this call is made from, as the report names it
---@param fn function
---@return boolean ok, any ...
function ns.SafeCall(label, fn, ...)
	labels[#labels + 1] = label
	return Finish(xpcall(fn, Trace, ...))
end
