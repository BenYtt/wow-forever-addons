-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, OptionsPrivate = ...
local function createOptions(parentData, data, index, subIndex)
  local points, areas = {}, {}
  for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
    Mixin(points, OptionsPrivate.Private.GetAnchorsForData(child, "point"))
    Mixin(areas, OptionsPrivate.Private.GetAnchorsForData(child, "area"))
  end
  local options = {
    __title = L["Dispel Type Icon %d"]:format(subIndex), __order = 1,
    dispelVisible = {type = "toggle", name = L["Show Icon"], order = 1, width = WeakAuras.normalWidth},
  }
  OptionsPrivate.commonOptions.PositionOptionsForSubElement(data, options, 10, areas, points)
  OptionsPrivate.AddUpDownDeleteDuplicate(options, parentData, index, "subcdmdispel")
  return options
end
WeakAuras.RegisterSubRegionOptions("subcdmdispel", createOptions, "Shows Blizzard's native dispel-type icon.")
