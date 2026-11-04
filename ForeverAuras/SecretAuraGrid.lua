-- Modified for ForeverAuras
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraGrid")
local Display = Private.BlizzardAuraDisplay

local GROWTH_LETTER = {RIGHT = "R", LEFT = "L", UP = "U", DOWN = "D", CENTER_HORIZONTAL = "H", CENTER_VERTICAL = "V"}
local VALID = {RU = true, UR = true, LU = true, UL = true, RD = true, DR = true, LD = true, DL = true, HD = true, HU = true,
  VR = true, VL = true, DH = true, UH = true, LV = true, RV = true, HV = true, VH = true}

local grids = {}

function Display.FlowGrid(group)
  return group and group.blizzardFlow and group.blizzardFlowGrid
    and group.blizzardFlowFrames ~= "UNITFRAME" and group.blizzardFlowFrames ~= "NAMEPLATE" or false
end

function Display.GridPerRow(group)
  return math.max(1, math.floor(tonumber(group.blizzardFlowPerRow) or 6))
end

-- Grid direction, as a Dynamic Group's: first letter along a row, second where new rows go.
function Display.GridType(group)
  if VALID[group.blizzardFlowGridType] then return group.blizzardFlowGridType end
  local first = GROWTH_LETTER[group.blizzardFlowGrowth or "RIGHT"] or "R"
  local vertical = first == "U" or first == "D" or first == "V"
  local rows = group.blizzardFlowRowGrowth
  if vertical then return first .. (rows == "LEFT" and "L" or "R") end
  return first .. (rows == "UP" and "U" or "D")
end

function Display.GridSpaces(group)
  local space = tonumber(group.blizzardFlowSpacing) or 2
  return tonumber(group.blizzardFlowRowSpace) or space, tonumber(group.blizzardFlowColumnSpace) or space
end

-- Returns the corner the flow starts from, the point that places the block,
-- the horizontal and vertical directions, and whether rows are columns.
function Display.GridLayout(gridType)
  local first, second = gridType:sub(1, 1), gridType:sub(2, 2)
  local vertical = first == "U" or first == "D" or first == "V"
  local horizontal, verticalDirection, centerX, centerY
  if vertical then
    verticalDirection = first == "U" and "UP" or "DOWN"
    horizontal = second == "L" and "LEFT" or "RIGHT"
    centerY, centerX = first == "V", second == "H"
  else
    horizontal = first == "L" and "LEFT" or "RIGHT"
    verticalDirection = second == "U" and "UP" or "DOWN"
    centerX, centerY = first == "H", second == "V"
  end
  local corner = (verticalDirection == "UP" and "BOTTOM" or "TOP") .. (horizontal == "LEFT" and "RIGHT" or "LEFT")
  local point = (centerY and "" or (verticalDirection == "UP" and "BOTTOM" or "TOP"))
    .. (centerX and "" or (horizontal == "LEFT" and "RIGHT" or "LEFT"))
  if point == "" then point = "CENTER" end
  return corner, point, horizontal, verticalDirection, vertical, centerX, centerY
end

local function ActiveNative(childID)
  local entry = Private.regions[childID]
  local region = entry and entry.region
  local native = region and region.blizzardAuraDisplay
  if native and native.active then return region, native end
end

function Display.GridProblem(data)
  local trigger = Display.GetTrigger(data)
  if not trigger then return end
  if Display.ShowOn(trigger) ~= "showOnActive" then return L["In a Grid layout, use Show On: Aura(s) Found. This aura is shown at its own position."] end
  if Display.RemainingWindow(trigger) or Display.UsesGate(data) then
    return L["In a Grid layout, Remaining Time, Total Duration and Stack Count filters are not available. This aura is shown at its own position."]
  end
  if not Display.IsSingleUnit(trigger) then return L["In a Grid layout, choose one unit (Player, Target, Focus, Pet...). This aura is shown at its own position."] end
end

local function Members(group)
  local members, unit = {}, nil
  for _, childID in ipairs(group.controlledChildren or {}) do
    local region, native = ActiveNative(childID)
    if region then
      local data = native.data
      local problem = Display.GridProblem(data)
      -- ForeverAuras: the resolved unit token (party1, party2), not the unit
      -- category: two Specific Unit auras are both "member", and the grid
      -- binds one container to the first member's unit, so a party2 aura
      -- in a grid bound to party1 showed party1's auras.
      local childUnit = not problem and Display.UnitTokens(Display.GetTrigger(data))[1]
      if childUnit and unit and childUnit ~= unit then
        problem = L["In a Grid layout, every aura watches the same unit as the first one. This aura is shown at its own position."]
      end
      if not problem then
        unit = unit or childUnit
        members[#members + 1] = {region = region, native = native, data = data, key = "FAGrid" .. tostring(data.uid)}
      end
      Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_grid", problem and "warning" or nil, problem)
    end
  end
  return members
end

local function ClearMembership(group, keep)
  for _, childID in ipairs(group and group.controlledChildren or {}) do
    local region, native = ActiveNative(childID)
    if native and not (keep and keep[region]) then
      if native.gridMember then
        native.gridMember = nil
        Display.RefreshUnits(region)
      end
      if not keep then Private.AuraWarnings.UpdateWarning(native.data.uid, "blizzard_aura_grid", nil) end
    end
  end
end

local function AddButtons(grid, key, region)
  local native = region.blizzardAuraDisplay
  local list = native.instances[1] and native.instances[1].buttons
  if not list then return end
  for _, button in ipairs(grid.buttons[key] or {}) do
    if button.gridList ~= list then
      button.gridList = list
      list[#list + 1] = button
      Display.StyleNative(button, native.data, region)
    end
  end
end

local function Layout(group)
  local grid = grids[group.id]
  local first = grid.members[1]
  local width, height = Display.Dimensions(first.data)
  local rowSpace, columnSpace = Display.GridSpaces(group)
  local corner, point, horizontal, verticalDirection, vertical = Display.GridLayout(Display.GridType(group))
  local along, across = columnSpace, rowSpace
  if vertical then along, across = rowSpace, columnSpace end
  Display.ApplyFlowWrap(grid.container, corner, horizontal, verticalDirection, vertical, Display.GridPerRow(group), width, height, along)
  grid.container:ClearAllPoints()
  grid.container:SetPoint(point, first.region, point)
  return along, across
end

function Display.RebuildGrid(group)
  local grid = grids[group.id]
  if not Display.FlowGrid(group) then
    if grid then
      grid.container:SetEnabled(false)
      grid.container:Hide()
      grid.members = {}
    end
    ClearMembership(group)
    return
  end
  if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return end
  local entry = Private.regions[group.id]
  local groupRegion = entry and entry.region
  local members = Members(group)
  if not groupRegion or #members == 0 then
    if grid then grid.container:SetEnabled(false); grid.container:Hide(); grid.members = {} end
    ClearMembership(group)
    return
  end
  if not grid then
    local container = CreateFrame("AuraContainer", nil, groupRegion, "CustomAuraContainerTemplate")
    container:SetEnabled(false)
    container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    grid = {container = container, buttons = {}, keys = {}, regions = {}, members = {}}
    grids[group.id] = grid
  end
  local container = grid.container
  if container:GetParent() ~= groupRegion then container:SetParent(groupRegion) end
  container:SetEnabled(false)
  grid.members = members
  local along, across = Layout(group)
  local wanted, keep = {}, {}
  for index, member in ipairs(members) do
    local key, data = member.key, member.data
    local trigger = Display.GetTrigger(data)
    local width, height = Display.Dimensions(data)
    local layout = {elementWidth = width, elementHeight = height, elementSpacing = along, lineSpacing = across, layoutIndex = index}
    grid.regions[key] = member.region
    if not grid.keys[key] then
      local ok = pcall(container.AddAuraGroup, container, key, Display.FilterString(trigger), {
        maxFrameCount = Display.MaxAuras(data),
        candidateFilters = Display.CandidateFilters(data),
        layout = layout,
        initializeFrame = function(button)
          local native = Display.BuildNativeButton(container, button)
          grid.buttons[key] = grid.buttons[key] or {}
          table.insert(grid.buttons[key], native)
          local region = grid.regions[key]
          if region and region.blizzardAuraDisplay then AddButtons(grid, key, region) end
        end,
      })
      grid.keys[key] = ok
    else
      container:SetAuraGroupFilterString(key, Display.FilterString(trigger))
      container:SetAuraGroupCandidateFilters(key, Display.CandidateFilters(data))
      container:SetAuraGroupLayout(key, layout)
      container:SetAuraGroupMaxFrameCount(key, Display.MaxAuras(data))
    end
    if grid.keys[key] then
      container:SetAuraGroupSortMethod(key, Display.SortOrder(data, trigger))
      wanted[key] = true
      keep[member.region] = true
      AddButtons(grid, key, member.region)
      if not member.native.gridMember then
        member.native.gridMember = group.id
        Display.RefreshUnits(member.region)
      end
    end
  end
  for key in pairs(grid.keys) do
    if grid.keys[key] and not wanted[key] then container:SetAuraGroupEnabled(key, false) end
  end
  ClearMembership(group, keep)
  grid.unit = nil
  Display.RefreshGrid(group)
end

-- ForeverAuras: Ignore Dead / Ignore Disconnected for a grid member. The
-- ordinary layout hides the member's own container (ApplyUnitStatus,
-- BlizzardAuraDisplay.lua), which a grid member does not draw with; its aura
-- group in the grid container is switched off instead.
-- Each member is judged on its own trigger: status (dead, offline) and
-- eligibility (hostility, class, self; Display.UnitEligible), so one member's
-- filter switches off that member's aura group only, never the grid.
local function MemberHidden(member, unit)
  local trigger = Display.GetSavedTrigger(member.data)
  if Display.UnitIgnored(trigger, unit) then return true end
  if Display.UnitEligible and not Display.UnitEligible(trigger, unit) then return true end
  return nil
end

function Display.RefreshGrid(group)
  local grid = group and grids[group.id]
  if not grid then return end
  local first = grid.members[1]
  local entry = Private.regions[group.id]
  local groupRegion = entry and entry.region
  local preview = WeakAuras.IsOptionsOpen() and not InCombatLockdown()
  local unit = first and Display.UnitTokens(Display.GetTrigger(first.data))[1]
  -- The unit the grid watches, kept whether or not anything shows now: a
  -- grid built while every member's unit was dead or offline has no bound
  -- unit yet, and the status events must still find it (RefreshGridStatus).
  grid.watchUnit = unit
  grid.byRegion = {}
  local any = false
  for _, member in ipairs(grid.members) do
    grid.byRegion[member.region] = member
    member.statusHidden = MemberHidden(member, unit)
    local enabled = not preview and member.native.active and member.region:IsShown() and member.native.gridMember == group.id
      and not member.statusHidden
    pcall(grid.container.SetAuraGroupEnabled, grid.container, member.key, enabled and true or false)
    any = any or enabled
  end
  local shown = any and unit ~= nil and groupRegion ~= nil
  if shown and grid.unit ~= unit then
    grid.container:SetEnabled(false)
    grid.container:SetUnit(unit)
    grid.unit = unit
  end
  grid.container:SetShown(shown)
  grid.container:SetEnabled(shown)
  if shown then grid.container:UpdateAllAuras() end
end

-- Called by the status events (BlizzardAuraDisplay.lua) for a grid member:
-- the grid is refreshed only when the member's dead or offline state changed.
function Display.RefreshGridStatus(region, unit)
  local native = region.blizzardAuraDisplay
  local id = native and native.gridMember
  local grid = id and grids[id]
  local watched = grid and grid.watchUnit
  if not watched then return end
  if watched ~= unit and not Private.ExecEnv.UnitIsUnit(watched, unit) then return end
  local member = grid.byRegion and grid.byRegion[region]
  if member and MemberHidden(member, watched) ~= member.statusHidden then Display.RefreshGridFor(region) end
end

function Display.RefreshGridFor(region)
  local native = region and region.blizzardAuraDisplay
  local id = native and native.gridMember
  local group = id and WeakAuras.GetData(id)
  if group and not Display.DeferGridRefresh(group) then Display.RefreshGrid(group) end
end

-- Options preview: the samples are plain frames, laid out like the live grid.
function Display.ArrangeGridPreview(group)
  local samples = {}
  local firstRegion
  -- ForeverAuras: the same eligibility as the live grid (Members): a member
  -- watching a different unit than the first eligible one is left at its
  -- own position, as the live grid leaves it. The preview checked only the
  -- per-display rules, so a Target display previewed inside a Player grid.
  local unit
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    local data = WeakAuras.GetData(childID)
    local eligible = region and region.secretAuraSamplesActive and data and Display.Enabled(data) and not Display.GridProblem(data)
    if eligible then
      local childUnit = Display.UnitTokens(Display.GetTrigger(data))[1]
      if childUnit and unit and childUnit ~= unit then
        eligible = false
        -- Its box and its samples go back to its own layout: the samples
        -- were anchored to the grid's first box the last time it was in the
        -- grid, and stayed there (PlaceOwnSample, SecretAuraPreview.lua).
        if Display.RestorePreviewRegion then Display.RestorePreviewRegion(region) end
        if Display.PlaceOwnSample then
          local shown = {}
          for _, sample in ipairs(region.secretAuraSamples or {}) do
            if sample.button:IsShown() then shown[#shown + 1] = sample.button end
          end
          for index, button in ipairs(shown) do Display.PlaceOwnSample(region, data, button, index, #shown) end
        end
      else
        unit = unit or childUnit
      end
    end
    if eligible then
      -- ForeverAuras: the row preview moves a display's own box onto its
      -- first sample (MovePreviewRegion, SecretAuraFlow.lua). Switched to a
      -- Grid with the editor open, the box was still on the sample, and
      -- anchoring the samples to the first box below made a cycle ("Cannot
      -- anchor to a region dependent on it"). The box goes back on its own
      -- anchor first.
      if Display.RestorePreviewRegion then Display.RestorePreviewRegion(region) end
      for _, sample in ipairs(region.secretAuraSamples or {}) do
        if sample.button:IsShown() then
          firstRegion = firstRegion or region
          samples[#samples + 1] = sample.button
        end
      end
    end
  end
  if not firstRegion then return end
  local perRow = Display.GridPerRow(group)
  local rowSpace, columnSpace = Display.GridSpaces(group)
  local corner, point, horizontal, verticalDirection, vertical, centerX, centerY = Display.GridLayout(Display.GridType(group))
  local width, height = samples[1]:GetWidth() or 0, samples[1]:GetHeight() or 0
  local hSign = horizontal == "LEFT" and -1 or 1
  local vSign = verticalDirection == "UP" and 1 or -1
  local line, lines = math.min(#samples, perRow), math.ceil(#samples / perRow)
  local columns, rows = line, lines
  if vertical then columns, rows = lines, line end
  local blockWidth = columns * width + (columns - 1) * columnSpace
  local blockHeight = rows * height + (rows - 1) * rowSpace
  local ox = centerX and -hSign * blockWidth / 2 or 0
  local oy = centerY and -vSign * blockHeight / 2 or 0
  for index, button in ipairs(samples) do
    local along, across = (index - 1) % perRow, math.floor((index - 1) / perRow)
    local column, row = along, across
    if vertical then column, row = across, along end
    button:ClearAllPoints()
    button:SetPoint(corner, firstRegion, point, ox + hSign * column * (width + columnSpace), oy + vSign * row * (height + rowSpace))
  end
  return true
end
