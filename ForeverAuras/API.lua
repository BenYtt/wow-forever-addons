-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- The API other addons use to share auras, such as WagoUI's UI Packs:
-- https://github.com/methodgg/Wago-Creator-UI/blob/main/WagoUI_Libraries/LibAddonProfiles/ImplementationGuide.lua
if not WeakAuras.IsLibsOK() then return end
---@class Private
local Private = select(2, ...)

ForeverAurasAPI = {}

--- Every aura by id, with its group's id, the ids of the auras directly inside it, and its icon.
---@return table<string, {parent: string?, children: string[]?, icon: number|string|nil}>
function ForeverAurasAPI:GetAuras()
  local auras = {}
  for id, data in pairs(ForeverAurasSaved.displays) do
    auras[id] = {
      parent = data.parent,
      children = data.controlledChildren and CopyTable(data.controlledChildren),
      icon = data.groupIcon or data.displayIcon,
    }
  end
  return auras
end

--- The import string of an aura and everything inside it, as the export window shows it.
--- Auras in excludedIds are left out, along with everything inside them. The exported aura itself never is.
---@param id string
---@param excludedIds table<string, boolean>?
---@return string?
function ForeverAurasAPI:ExportAura(id, excludedIds)
  if not WeakAuras.GetData(id) then return nil end
  return Private.DisplayToString(id, true, excludedIds)
end

--- The table an import string holds, or nil when it is not an import string.
---@param importString string
---@return table?
function ForeverAurasAPI:DecodeAuraString(importString)
  if type(importString) ~= "string" then return nil end
  local decoded = Private.StringToTable(importString, true)
  return type(decoded) == "table" and decoded or nil
end

local pendingImport

local function finishImport(accepted, id)
  local callback = pendingImport and pendingImport.callback
  pendingImport = nil
  if callback then xpcall(callback, geterrorhandler(), accepted and true or false, id) end
end

--- Opens the import window for the string, where the player decides whether to import it.
--- callback(accepted, id) runs once: accepted with the aura's id when the import finishes, declined when the player
--- closes the import window or the options, or another import replaces it. It may never run if the player reloads
--- with the window open. Only one import is open at a time.
--- Returns true when the window opened, or false and why it could not.
---@param importString string
---@param callback fun(accepted: boolean, id: string?)?
---@return boolean opened
---@return string? reason
function ForeverAurasAPI:ImportAura(importString, callback)
  if InCombatLockdown() then return false, "in combat" end
  if pendingImport then return false, "another import is still open" end
  local decoded = self:DecodeAuraString(importString)
  if not decoded or decoded.m ~= "d" then return false, "not an aura import string" end
  local ok, refused, reason = xpcall(WeakAuras.Import, geterrorhandler(), decoded, nil, finishImport)
  if not ok then return false, "the import failed" end
  if refused == false or reason then return false, reason end
  if not WeakAuras.IsOptionsOpen() then return false, "the options could not open" end
  pendingImport = { callback = callback }
  return true
end

function ForeverAurasAPI:OpenConfig()
  if not WeakAuras.IsOptionsOpen() then WeakAuras.OpenOptions() end
end

function ForeverAurasAPI:CloseConfig()
  if WeakAuras.IsOptionsOpen() then WeakAuras.HideOptions() end
end

--- The options window, for placing other windows beside it. Nil until the options have opened once.
---@return Frame?
function ForeverAurasAPI:GetConfigFrame()
  return _G.ForeverAurasOptions
end
