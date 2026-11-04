-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SubCDMDispelBorder")
local function defaults(parentType)
  -- Borders fit the parent rectangle by default; icons retain their square corner size.
  return {dispelVisible = true, anchor_mode = "area", anchor_area = parentType == "aurabar" and "bar" or "ALL",
    anchor_point = "CENTER", self_point = "CENTER", width = 32, height = 32,
    xOffset = 0, yOffset = 0, dispelBorderSize = 2, dispelBorderOffset = 0}
end
local function create()
  local region = CreateFrame("Frame", nil, UIParent)
  region.dispelEdges = Private.DispelTypeDisplay.CreateEdges(region)
  function region:SetVisible(value)
    self.visible = value; self:SetShown(value)
    if self.Update then self:Update() end
  end
  return region
end
local function modify(parent, region, parentData, data)
  region:SetParent(parent); region.parent = parent
  region.Anchor = function()
    region:ClearAllPoints()
    local mode = data.anchor_mode or "area"
    if mode == "point" then region:SetSize(data.width or 32, data.height or 32) end
    -- Area offsets follow the same total-width/height convention as other sub-elements.
    local factor = mode == "area" and 0.5 or 1
    parent:AnchorSubRegion(region, mode, mode == "area" and data.anchor_area or data.anchor_point,
      mode == "point" and data.self_point or nil, (data.xOffset or 0) * factor, (data.yOffset or 0) * factor)
    Private.DispelTypeDisplay.Layout(region.dispelEdges, region, data)
  end
  region:Anchor()
  region.Update = function() Private.CDMAuraProgress.UpdateIndicator(parent, region, data) end
  region.UpdateProgress = region.Update
  parent.subRegionEvents:AddSubscriber("Update", region)
  parent.subRegionEvents:AddSubscriber("UpdateProgress", region)
  region:SetVisible(data.dispelVisible ~= false)
end
local function release(region)
  if region.parent then
    region.parent.subRegionEvents:RemoveSubscriber("Update", region)
    region.parent.subRegionEvents:RemoveSubscriber("UpdateProgress", region)
  end
  Private.DispelTypeDisplay.Hide(region.dispelEdges)
  region:Hide()
end
local function supports(kind) return kind == "icon" or kind == "aurabar" or kind == "progresstexture" end
WeakAuras.RegisterSubRegionType("subcdmdispelborder", "Dispel Type Border", supports, create, modify,
  function(region) region:Show() end, release, defaults, nil,
  {dispelVisible = {display = "Visibility", setter = "SetVisible", type = "bool", defaultProperty = true}})
