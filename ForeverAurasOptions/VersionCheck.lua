-- Modified for ForeverAuras, 2026-10-23.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

local L = WeakAuras.L

local optionsVersion = "1.1.0"


if optionsVersion ~= WeakAuras.versionString then
  local message = string.format(L["The ForeverAuras Options Addon version %s doesn't match the ForeverAuras version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling ForeverAuras"],
                    optionsVersion, WeakAuras.versionString)
  ---@diagnostic disable-next-line: duplicate-set-field
  WeakAuras.IsLibsOk = function() return false end
  ---@diagnostic disable-next-line: duplicate-set-field
  WeakAuras.ToggleOptions = function()
       WeakAuras.prettyPrint(message)
  end

end
