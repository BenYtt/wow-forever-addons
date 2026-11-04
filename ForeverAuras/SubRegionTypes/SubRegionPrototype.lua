-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class WeakAuras
local WeakAuras = WeakAuras;
local L = WeakAuras.L;

Private.subRegionPrototype = {}; -- todo add this file to toc

-- Alpha
function Private.subRegionPrototype.AddAlphaToDefault(default, type)
  local prefix = type and (type .. "_") or ""
  default[prefix .. "alpha"] = 1.0;
end

function Private.subRegionPrototype.AddAlphaProperties(properties, type)
  local prefix = type and (type .. "_") or ""
  properties[prefix .. "alpha"] = {
    display = L["Alpha"],
    setter = "SetAlpha",
    type = "number",
    min = 0,
    max = 1,
    bigStep = 0.01,
    isPercent = true
  }
  properties[prefix .. "alphaFromBoolean"] = {
    display = L["Alpha"] .. " (Boolean)",
    setter = "SetAlpha",
    type = "bool",
    valueFromBoolean = true,
    baseProperty =  prefix .. "alpha",
    valueLabel = L["Alpha"],
    default = {
      checks = {
        {
          trigger = -1,
          variable = "alwaystrue",
          value = 1,
          when = true,
        },
      },
    },
  }
end

function Private.subRegionPrototype.AddColorFromBooleanProperty(properties, type, baseColorProperty)
  local baseColorPropertyData = properties[baseColorProperty]
  local prefix = type and (type .. "_") or ""
  properties[prefix .. "colorFromBoolean"] = {
    display = L["Color"] .. " (Boolean)",
    setter = baseColorPropertyData.setter,
    type = "color",
    colorFromBoolean = true,
    baseProperty = baseColorProperty,
    valueLabel = L["Color"],
    default = {
      checks = {
        {
          trigger = -1,
          variable = "alwaystrue",
          value = {1, 1, 1, 1},
          when = true,
        },
      },
    },
  }
end
