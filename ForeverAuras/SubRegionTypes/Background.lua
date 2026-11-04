-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)
local L = WeakAuras.L;

do
  local function subSupports(regionType)
    return regionType ~= "group" and regionType ~= "dynamicgroup"
  end

  local function noop()
  end

  local function subSetFrameLevel(self, level)
    self.parent:SetFrameLevel(level)
  end

  -- The level this element sets, so Private.ApplyFrameLevel can leave an
  -- unchanged one alone (the client re-sorts the subtree on every set).
  local function subGetFrameLevel(self)
    return self.parent:GetFrameLevel()
  end

  local function subCreate()
    return { Update = noop, SetFrameLevel = subSetFrameLevel, GetFrameLevel = subGetFrameLevel}
  end

  local function subModify(parent, region)
    region.parent = parent
  end

  WeakAuras.RegisterSubRegionType("subbackground", L["Background"], subSupports, subCreate, subModify,
                                  noop, noop, {}, nil, {}, false)
end

-- Foreground for aurabar

do
  local function subSupports(regionType)
    return regionType == "aurabar"
  end

  local function noop()
  end

  local function subSetFrameLevel(self, level)
    if self.parent.bar then
      self.parent.bar:SetFrameLevel(level)
    end
    if self.parent.iconFrame then
      self.parent.iconFrame:SetFrameLevel(level)
    end
  end

  -- See the Background element above. Both frames get the same level; the
  -- bar's is reported, or nil when neither frame exists (always set then).
  local function subGetFrameLevel(self)
    local frame = self.parent.bar or self.parent.iconFrame
    return frame and frame:GetFrameLevel()
  end

  local function subCreate()
    return { Update = noop, SetFrameLevel = subSetFrameLevel, GetFrameLevel = subGetFrameLevel}
  end

  local function subModify(parent, region)
    region.parent = parent
  end

  WeakAuras.RegisterSubRegionType("subforeground", L["Foreground"], subSupports, subCreate, subModify,
                                  noop, noop, {}, nil, {}, false)
end
