-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- ForeverAuras: External Display Changes. Another aura or an addon scales or
-- overrides the sizes of a display that opted in ("Allow External Display
-- Changes" on its Display tab), through the public functions below.
--
-- The changes are session state written into the display's data, so every
-- consumer - the region, its sub elements, dynamic group layout, Modern and
-- CDM containers - builds from the changed numbers as if the author had typed
-- them. Nothing reaches the saved variables: the authored values are kept
-- aside and written back when the options window opens (the editor shows and
-- saves authored values), before an export, and at logout; the changes are
-- applied again when the options window closes. A request for a display that
-- does not exist yet is kept and applied when the display is added.
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

local ForeverAuras = WeakAuras

-- Requests by display id: {scale = factor, classes = {size = true, ...}, values = {path = value}}.
local requests = {}
-- The authored values of each changed display, by uid: {path = value}.
local originals = {}
-- Displays whose request is being applied, so their own Add does not reapply.
local applying = {}
local suspended = false
local pending = {}
local pendingQueued = false

-- The fields each class covers, on the display and on its sub elements.
-- Borders and glows are drawn at pixel sizes authors choose deliberately
-- (a 1 px border), so they only scale when asked for.
local classes = {
  size = {
    region = {width = true, height = true},
    sub = {subtexture = {width = true, height = true}},
  },
  offsets = {
    region = {xOffset = true, yOffset = true},
    sub = {
      subtext = {text_anchorXOffset = true, text_anchorYOffset = true},
      subtexture = {xOffset = true, yOffset = true},
    },
  },
  fonts = {
    region = {fontSize = true},
    sub = {subtext = {text_fontSize = true}},
  },
  borders = {
    region = {borderSize = true, borderOffset = true, borderInset = true},
    sub = {subborder = {border_size = true, border_offset = true}},
  },
  glows = {
    region = {},
    sub = {subglow = {glowThickness = true, glowLength = true, glowXOffset = true, glowYOffset = true}},
  },
}
local defaultClasses = {size = true, offsets = true, fonts = true}
-- Fields that must stay at least one pixel when scaled down.
local atLeastOne = {borderSize = true, border_size = true, glowThickness = true, text_fontSize = true, fontSize = true, width = true, height = true}

local function Round(value, key)
  local rounded = math.floor(value + 0.5)
  if atLeastOne[key] and rounded < 1 then rounded = 1 end
  return rounded
end

-- "width" on the display, "sub.3.text_fontSize" on its third sub element.
local function Resolve(data, path)
  local index, key = path:match("^sub%.(%d+)%.(.+)$")
  if index then
    local element = data.subRegions and data.subRegions[tonumber(index)]
    return element, key
  end
  return data, path
end

local function Remember(uid, data, path)
  local store = originals[uid]
  if not store then
    store = {}
    originals[uid] = store
  end
  if store[path] == nil then
    local holder, key = Resolve(data, path)
    if holder then store[path] = holder[key] == nil and false or holder[key] end
  end
end

-- Writes the authored values back into `data`; returns true when any were.
local function Restore(data)
  local store = data.uid and originals[data.uid]
  if not store then return false end
  for path, value in pairs(store) do
    local holder, key = Resolve(data, path)
    if holder then
      if value == false then holder[key] = nil else holder[key] = value end
    end
  end
  originals[data.uid] = nil
  return true
end

-- The leaf displays a request for `id` covers: the display, or a group's
-- children, those that opted in.
local function Targets(id)
  local data = WeakAuras.GetData(id)
  if not data then return {} end
  local list = {}
  if Private.IsGroupType(data) then
    for child in Private.TraverseLeafs(data) do
      if child.allowExternalDisplay then list[#list + 1] = child end
    end
  elseif data.allowExternalDisplay then
    list[1] = data
  end
  return list
end

local function Scale(data, factor, wanted)
  for name, fields in pairs(classes) do
    if wanted[name] then
      for key in pairs(fields.region) do
        local value = data[key]
        if type(value) == "number" then
          Remember(data.uid, data, key)
          data[key] = Round(value * factor, key)
        end
      end
      for index, element in ipairs(data.subRegions or {}) do
        local keys = fields.sub[element.type]
        if keys then
          for key in pairs(keys) do
            local value = element[key]
            if type(value) == "number" then
              Remember(data.uid, data, "sub." .. index .. "." .. key)
              element[key] = Round(value * factor, key)
            end
          end
        end
      end
    end
  end
end

local function Override(data, values)
  for path, value in pairs(values) do
    local holder, key = Resolve(data, path)
    if holder and type(path) == "string" then
      Remember(data.uid, data, path)
      holder[key] = value
    end
  end
end

-- Applies the request for `id` to its targets: authored values back first, so
-- a new factor replaces the old one rather than compounding, then the scale,
-- then exact values; each changed display is rebuilt and its parents laid out.
local function Apply(id)
  local request = requests[id]
  local parents = {}
  for _, data in ipairs(Targets(id)) do
    local changed = Restore(data)
    if request and not suspended then
      if request.scale and request.scale ~= 1 then
        Scale(data, request.scale, request.classes or defaultClasses)
        changed = true
      end
      if request.values then
        Override(data, request.values)
        changed = true
      end
    end
    if changed then
      applying[data.uid] = true
      WeakAuras.Add(data)
      applying[data.uid] = nil
      if data.parent then parents[data.parent] = true end
    end
  end
  for parent in pairs(parents) do
    local parentData = WeakAuras.GetData(parent)
    if parentData then
      WeakAuras.Add(parentData)
      Private.AddParents(parentData)
    end
  end
end

local function Queue(id)
  pending[id] = true
  if pendingQueued then return end
  pendingQueued = true
  C_Timer.After(0, function()
    pendingQueued = false
    local ids = pending
    pending = {}
    for queued in pairs(ids) do Apply(queued) end
  end)
end

local function ApplyAll()
  for id in pairs(requests) do Queue(id) end
end

-- Authored values back into every changed display; rebuilt unless `quiet`
-- (logout: the saved variables are written right after, nothing is shown).
local function RestoreAll(quiet)
  for uid in pairs(originals) do
    local id = Private.UIDtoID(uid)
    local data = id and WeakAuras.GetData(id)
    if data then
      Restore(data)
      if not quiet then
        applying[uid] = true
        WeakAuras.Add(data)
        applying[uid] = nil
      end
    else
      originals[uid] = nil
    end
  end
end

-- Multiplies the sizes of `id` (a display, or every opted-in child of a
-- group) by `factor`; 1 or nil clears. `classes` picks what scales:
-- {size = true, offsets = true, fonts = true} by default, plus borders and
-- glows when set true; any class set false is left alone.
function ForeverAuras.SetDisplayScale(id, factor, classes)
  if type(id) ~= "string" or id == "" then return end
  factor = tonumber(factor)
  if factor == nil or factor ~= factor or factor <= 0 or factor == math.huge then factor = 1 end
  local wanted
  if type(classes) == "table" then
    wanted = {}
    for name in pairs(defaultClasses) do wanted[name] = true end
    for name, on in pairs(classes) do
      if classes[name] ~= nil and Private.ExternalDisplayClasses[name] then wanted[name] = on and true or nil end
    end
  end
  local request = requests[id] or {}
  request.scale = factor ~= 1 and factor or nil
  request.classes = wanted
  if request.scale or request.values then requests[id] = request else requests[id] = nil end
  Queue(id)
end

-- Sets exact values on `id`: {width = 48, ["sub.2.text_fontSize"] = 14};
-- nil clears them. Applied after any scale.
function ForeverAuras.SetDisplayOverrides(id, values)
  if type(id) ~= "string" or id == "" then return end
  local request = requests[id] or {}
  if type(values) == "table" and next(values) then
    request.values = CopyTable(values)
  else
    request.values = nil
  end
  if request.scale or request.values then requests[id] = request else requests[id] = nil end
  Queue(id)
end

-- Removes every external change from `id`.
function ForeverAuras.ClearDisplayChanges(id)
  if type(id) ~= "string" then return end
  requests[id] = nil
  Queue(id)
end

Private.ExternalDisplayClasses = {size = true, offsets = true, fonts = true, borders = true, glows = true}

-- Exports carry authored values (Transmission.lua, CompressDisplay).
function Private.ExternalDisplayRestore(copiedData)
  local store = copiedData.uid and originals[copiedData.uid]
  if not store then return end
  for path, value in pairs(store) do
    local holder, key = Resolve(copiedData, path)
    if holder then
      if value == false then holder[key] = nil else holder[key] = value end
    end
  end
end

-- A display added while a request waits for it (an import, a reload of its
-- data) takes the request on the next frame; its own applying Add is skipped.
Private.callbacks:RegisterCallback("Add", function(_, uid, id, data, simpleChange)
  if simpleChange or applying[uid] or suspended then return end
  if requests[id] then
    Queue(id)
    return
  end
  if data.parent and requests[data.parent] then Queue(data.parent) end
end)

Private.callbacks:RegisterCallback("Rename", function(_, uid, oldid, newid)
  if requests[oldid] then
    requests[newid] = requests[oldid]
    requests[oldid] = nil
  end
end)

Private.callbacks:RegisterCallback("Delete", function(_, uid, id)
  requests[id] = nil
  originals[uid] = nil
end)

-- The editor shows and saves authored values: changes are withdrawn while it
-- is open and applied again when it closes.
function Private.ExternalDisplayOptionsOpened()
  if suspended then return end
  suspended = true
  RestoreAll(false)
end

function Private.ExternalDisplayOptionsClosed()
  if not suspended then return end
  suspended = false
  ApplyAll()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGOUT" then
    RestoreAll(true)
  elseif event == "ADDON_LOADED" and name == "ForeverAurasOptions" then
    if type(WeakAuras.ShowOptions) == "function" then
      hooksecurefunc(WeakAuras, "ShowOptions", function()
        Private.ExternalDisplayOptionsOpened()
        local optionsFrame = _G.ForeverAurasOptions
        if optionsFrame and not optionsFrame.faExternalDisplayHooked then
          optionsFrame.faExternalDisplayHooked = true
          optionsFrame:HookScript("OnHide", Private.ExternalDisplayOptionsClosed)
          optionsFrame:HookScript("OnShow", Private.ExternalDisplayOptionsOpened)
        end
      end)
    end
  end
end)
