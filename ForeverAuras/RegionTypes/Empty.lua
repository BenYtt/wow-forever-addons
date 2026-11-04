-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("RegionEmpty")
local L = WeakAuras.L

local default = {
  width = 200,
  height = 200,
  selfPoint = "CENTER",
  anchorPoint = "CENTER",
  anchorFrameType = "SCREEN",
  xOffset = 0,
  yOffset = 0,
  frameStrata = 1
}

Private.regionPrototype.AddAlphaToDefault(default)

local properties = {
}


Private.regionPrototype.AddProperties(properties, default);

local function create(parent)
  local region = CreateFrame("Frame", nil, UIParent)
  region.regionType = "empty"
  region:SetMovable(true)
  region:SetResizable(true)
  region:SetResizeBounds(1, 1)

  region.Update = function()
    region:UpdateProgress()
  end

  Private.regionPrototype.create(region)
  return region
end

local function modify(parent, region, data)
  Private.regionPrototype.modify(parent, region, data)
  region:SetWidth(data.width)
  region:SetHeight(data.height)
  region.width = data.width
  region.height = data.height
  region.scalex = 1
  region.scaley = 1
  Private.regionPrototype.modifyFinish(parent, region, data)
end

Private.RegisterRegionType("empty", create, modify, default, properties)
