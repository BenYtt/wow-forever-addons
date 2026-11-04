-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SubCDMDispel")
local function defaults()
  -- New indicators use a small Blizzard type symbol at the aura's top-left corner.
  return {dispelVisible = true, dispelStyle = "Icon", anchor_mode = "point", anchor_point = "TOPLEFT",
    self_point = "TOPLEFT", width = 16, height = 16, xOffset = -3, yOffset = 3, anchor_area = "ALL"}
end
local function create()
  local region = CreateFrame("Frame", nil, UIParent)
  -- A separate border sub-element owns border geometry.
  region.preview = region:CreateTexture(nil, "OVERLAY", nil, 1)
  region.preview:SetAllPoints(region)
  region.preview:Hide()
  function region:SetVisible(value)
    self.visible = value
    self:SetShown(value)
    if self.Update then self:Update() end
  end
  return region
end
local function modify(parent, region, parentData, data)
  region:SetParent(parent)
  region.parent = parent
  region.Anchor = function()
    region:ClearAllPoints()
    if data.anchor_mode == "point" then region:SetSize(data.width or 24, data.height or 24) end
    parent:AnchorSubRegion(region, data.anchor_mode or "point", data.anchor_mode == "area" and data.anchor_area or data.anchor_point,
      data.anchor_mode == "point" and data.self_point or nil, data.xOffset or 0, data.yOffset or 0)
  end
  region:Anchor()
  region.Update = function() Private.CDMAuraProgress.UpdateIndicator(parent, region, data) end
  region.UpdateProgress = region.Update
  parent.subRegionEvents:AddSubscriber("Update", region)
  parent.subRegionEvents:AddSubscriber("UpdateProgress", region)
  Private.CDMAuraProgress.ModifyIndicator(parent, region, parentData, data)
  region:SetVisible(data.dispelVisible ~= false)
end
local function release(region)
  if region.parent then
    region.parent.subRegionEvents:RemoveSubscriber("Update", region)
    region.parent.subRegionEvents:RemoveSubscriber("UpdateProgress", region)
  end
  Private.CDMAuraProgress.ReleaseIndicator(region, true)
  region:Hide()
end
local function supports(kind) return kind == "icon" or kind == "aurabar" or kind == "progresstexture" end
WeakAuras.RegisterSubRegionType("subcdmdispel", "Dispel Type Icon", supports, create, modify,
  function(region) region:Show() end, release, defaults, nil,
  {dispelVisible = {display = "Visibility", setter = "SetVisible", type = "bool", defaultProperty = true}})
