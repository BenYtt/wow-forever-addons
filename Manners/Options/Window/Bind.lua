-- Manners -- options window: the binding between a placed control and its
-- definition in ns.optionsTable.
--
-- The definitions stay AceConfig-shaped (Options/*.lua), and this file reads
-- them the way AceConfigDialog does, so a control behaves the same in the
-- window as it did on the old page: the same info table, inherited members,
-- handler method strings, confirm, validate, values and sorting. A control is
-- addressed as "tab.key", never by its bare key: `enabled` and
-- `combatNotice` are each defined twice.

local ADDON, ns = ...

local B = {}
ns.WindowBind = B

-- Members AceConfigDialog looks up the tree for: the option's own, else its
-- tab's, else the root's.
local INHERITED = { get = true, set = true, func = true, confirm = true, validate = true,
	disabled = true, hidden = true }

-- Members where a string is the value itself rather than a method's name.
local LITERAL = { name = true, desc = true, usage = true, confirmText = true }

local function Root() return ns.optionsTable end

-- The info table AceConfigDialog hands every get, set and function: the path
-- (so info[#info] is the key the shared get/set closures read), the option,
-- the whole table and the handler AceDBOptions' methods are called on.
local function NewInfo(path1, path2, option, handler)
	local info = { path1, path2, options = Root(), option = option, handler = handler,
		arg = option.arg, type = option.type, appName = ADDON, uiType = "dialog", uiName = ADDON }
	info[0] = ADDON
	return info
end

-- The tab group's own info, for its `hidden` and `disabled`: the path stops at
-- the tab, as AceConfigDialog's does when it draws the tab itself.
local groupInfo = setmetatable({}, { __mode = "k" })
local function GroupInfo(item)
	local info = groupInfo[item.group]
	if not info then
		local root = Root()
		info = { item.tab, options = root, option = item.group, handler = item.group.handler or root.handler,
			type = "group", appName = ADDON, uiType = "dialog", uiName = ADDON }
		info[0] = ADDON
		groupInfo[item.group] = info
	end
	return info
end

-- The item for "tab.key", or nil when the model has no such control (one this
-- class's model does not build, AceDBOptions' controls on a client without
-- them).
function B.Item(path, layoutEntry, ctx)
	if type(path) ~= "string" then return nil end
	local tab, key = path:match("^([^.]+)%.(.+)$")
	local root = Root()
	local group = tab and root and type(root.args) == "table" and root.args[tab]
	local def = type(group) == "table" and type(group.args) == "table" and group.args[key] or nil
	if type(def) ~= "table" then return nil end
	local handler = group.handler or root.handler
	return {
		path = path, tab = tab, key = key, def = def, group = group,
		info = NewInfo(tab, key, def, handler), layout = layoutEntry or {}, ctx = ctx,
	}
end

-- The member as AceConfigDialog finds it: the option's own, or for an
-- inherited one the nearest group's.
local function Member(item, name)
	local value = item.def[name]
	if value == nil and INHERITED[name] then
		value = item.group[name]
		if value == nil then
			local root = Root()
			value = root and root[name]
		end
	end
	return value
end

-- A member's value: called with the info table when it is a function, as a
-- method of the handler when it is a string naming one, else as it stands.
local function Ask(item, member, name, ...)
	if type(member) == "function" then return member(item.info, ...) end
	if type(member) == "string" and not LITERAL[name] then
		local handler = item.info.handler
		local method = handler and handler[member]
		if type(method) ~= "function" then
			error(("Method %s doesn't exist in handler for %s"):format(member, name), 0)
		end
		return method(handler, item.info, ...)
	end
	return member
end

-- The tab group's own `hidden` or `disabled`, asked with the tab's own info.
local function GroupSays(item, name)
	local member = item.group[name]
	if member == nil then return false end
	if type(member) == "function" then return member(GroupInfo(item)) and true or false end
	if type(member) == "string" then
		local handler = item.group.handler
		local method = handler and handler[member]
		if type(method) ~= "function" then return false end
		return method(handler, GroupInfo(item)) and true or false
	end
	return member and true or false
end

-- The control's value. `get = false` (AceDBOptions' New and Copy From) is a
-- box that shows nothing.
function B.Value(item, ...)
	local get = Member(item, "get")
	if get == false or get == nil then return nil end
	return Ask(item, get, "get", ...)
end

-- name, desc, confirmText or usage, evaluated; nil when there is none.
function B.Text(item, field)
	local value = item.def[field]
	if type(value) == "function" then value = value(item.info) end
	if type(value) == "number" then value = tostring(value) end
	if type(value) ~= "string" then return nil end
	return value
end

-- Sorts the way AceConfig's dropdown does without a `sorting`: by the label.
-- Colour codes are left in; they open every label they are in alike.
local function ByLabel(a, b)
	local la, lb = tostring(a[2]):lower(), tostring(b[2]):lower()
	if la ~= lb then return la < lb end
	return tostring(a[1]) < tostring(b[1])
end

-- A multiselect lists its keys in key order, numbers as numbers.
local function ByKey(a, b)
	local na, nb = tonumber(a[1]), tonumber(b[1])
	if na and nb then return na < nb end
	return tostring(a[1]) < tostring(b[1])
end

-- The choices in display order, as { key, label } pairs.
function B.Values(item)
	local values = Ask(item, item.def.values, "values")
	if type(values) ~= "table" then return {} end
	local out = {}
	local sorting = item.def.type == "select" and Ask(item, item.def.sorting, "sorting") or nil
	if type(sorting) == "table" then
		for _, key in ipairs(sorting) do
			if values[key] ~= nil then out[#out + 1] = { key, values[key] } end
		end
		return out
	end
	for key, label in pairs(values) do out[#out + 1] = { key, label } end
	table.sort(out, item.def.type == "multiselect" and ByKey or ByLabel)
	return out
end

-- Hidden by its own rule, or by its tab's: a tab hidden on the old page took
-- every control on it away, wherever the window now places them.
function B.Hidden(item)
	local def = item.def
	local fixed = def.dialogHidden
	if fixed == nil then fixed = def.guiHidden end
	if fixed ~= nil then return fixed and true or false end
	if def.hidden ~= nil and Ask(item, def.hidden, "hidden") then return true end
	return GroupSays(item, "hidden")
end

-- Hidden by its own rule alone, for a control the window places away from
-- its tab: the footer's reset, whose tab (Advanced) is not a page of the
-- window, and is hidden for a class with no prompt that still has What I say.
function B.OwnHidden(item)
	local def = item.def
	if def.hidden == nil then return false end
	return Ask(item, def.hidden, "hidden") and true or false
end

-- The same two ways for greyed out.
function B.Disabled(item)
	local def = item.def
	local fixed = def.dialogDisabled
	if fixed == nil then fixed = def.guiDisabled end
	if fixed ~= nil then return fixed and true or false end
	if def.disabled ~= nil and Ask(item, def.disabled, "disabled") then return true end
	return GroupSays(item, "disabled")
end

---------------------------------------------------------------------------
-- committing a change
---------------------------------------------------------------------------

-- Plain text for a message box: AceConfigDialog shows "name: usage".
local function Refused(item, said)
	if type(said) == "string" then return said end
	local usage = B.Text(item, "usage")
	if usage then return usage end
	return B.Text(item, "name") or ""
end

-- What validate says: true, or false and the sentence to show in red. A
-- validate that throws refuses the value, as it does on the old page, and is
-- named in /manners errors.
local function Validate(item, ...)
	local def = item.def
	if def.type == "input" and type(def.pattern) == "string" then
		local text = ...
		if not tostring(text or ""):match(def.pattern) then return false, Refused(item) end
	end
	local validate = Member(item, "validate")
	if validate == nil or def.type == "execute" then return true end
	local ok, said = pcall(Ask, item, validate, "validate", ...)
	if not ok then
		ns.Guard("options validate " .. item.path, error, said, 0)
		return false, Refused(item)
	end
	if said == true then return true end
	if said == false or said == nil or type(said) == "string" then return false, Refused(item, said) end
	return true
end

-- The confirm text, or nil when no confirm is wanted. `confirm` is true with
-- confirmText, or a function (or handler method) returning the text or false.
local function ConfirmText(item, ...)
	local confirm = Member(item, "confirm")
	local text = B.Text(item, "confirmText")
	if type(confirm) == "function" or type(confirm) == "string" then
		local ok, said = pcall(Ask, item, confirm, "confirm", ...)
		if not ok then
			ns.Guard("options confirm " .. item.path, error, said, 0)
			return nil
		end
		if type(said) == "string" then return said end
		confirm = said
	end
	if confirm ~= true then return nil end
	if text then return text end
	text = B.Text(item, "name") or ""
	local desc = B.Text(item, "desc")
	if desc then text = text .. " - " .. desc end
	return text
end

-- The set, or the func of a button, called the way AceConfigDialog calls it,
-- then the window told. A throw is named once in /manners errors and the
-- window carries on.
local function Apply(item, n, ...)
	local member = Member(item, item.def.type == "execute" and "func" or "set")
	local args = { ... }
	ns.Guard("options " .. item.path, function()
		Ask(item, member, item.def.type == "execute" and "func" or "set", unpack(args, 1, n))
	end)
	local ctx = item.ctx
	if ctx and ctx.OnChange then ctx.OnChange(item) end
end

-- validate, then confirm in the window's own box, then set (or func). Returns
-- false and the sentence to show when the value is refused, true otherwise:
-- a confirmed change happens when YES is pressed.
function B.Commit(item, ...)
	local ok, said = Validate(item, ...)
	if not ok then return false, said end
	local n, args = select("#", ...), { ... }
	local text = ConfirmText(item, ...)
	if not text then
		Apply(item, n, ...)
		return true
	end
	local W, ctx = ns.WindowWidgets, item.ctx
	W.Modal(ctx and ctx.Window, text, function()
		Apply(item, n, unpack(args, 1, n))
	end, function()
		-- NO: the control goes back to what the setting still says.
		if ctx and ctx.Repaint then ctx.Repaint(item) end
	end)
	return true
end

-- A button's func, through the same confirm.
function B.Run(item)
	return B.Commit(item)
end
