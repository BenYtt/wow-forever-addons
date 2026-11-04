-- Modified for ForeverAuras, 2026-10-25.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local L = WeakAuras.L;

-- Calculate bounding box
local function getRect(data)
  -- Temp variables
  local blx, bly, trx, try;
  blx, bly = data.xOffset or 0, data.yOffset or 0;

  if (data.width == nil or data.height == nil or data.regionType == "text") then
    return blx, bly, blx, bly;
  end

  -- Calc bounding box
  if(data.selfPoint:find("LEFT")) then
    trx = blx + data.width;
  elseif(data.selfPoint:find("RIGHT")) then
    trx = blx;
    blx = blx - data.width;
  else
    blx = blx - (data.width/2);
    trx = blx + data.width;
  end
  if(data.selfPoint:find("BOTTOM")) then
    try = bly + data.height;
  elseif(data.selfPoint:find("TOP")) then
    try = bly;
    bly = bly - data.height;
  else
    bly = bly - (data.height/2);
    try = bly + data.height;
  end

  -- Return data
  return blx, bly, trx, try;
end

local function getHeight(data, region)
  if data.regionType == "text" then
    return region.height
  else
    return data.height
  end
end


local function getWidth(data, region)
  if data.regionType == "text" then
    return region.width
  else
    return data.width
  end
end

local function createDistributeAlignOptions(id, data)
  return {
    align_h = {
      type = "select",
      width = WeakAuras.normalWidth,
      name = L["Horizontal Align"],
      order = 10,
      values = OptionsPrivate.Private.align_types,
      get = function()
        if(#data.controlledChildren < 1) then
          return nil;
        end
        ---@type AnchorPoint?, AnchorPoint?, AnchorPoint?
        local alignedCenter, alignedRight, alignedLeft = "CENTER", "RIGHT", "LEFT";
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          if(childData) then
            local left, _, right = getRect(childData);
            local center = (left + right) / 2;
            if(math.abs(right) >= 0.01) then
              alignedRight = nil;
            end
            if(math.abs(left) >= 0.01) then
              alignedLeft = nil;
            end
            if(math.abs(center) >= 0.01) then
              alignedCenter = nil;
            end
          end
        end
        return (alignedCenter or alignedRight or alignedLeft);
      end,
      set = function(info, v)
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          local childRegion = WeakAuras.GetRegion(childId)
          if(childData and childRegion) then
            if(v == "CENTER") then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = 0 - (getWidth(childData, childRegion) / 2);
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = 0 + (getWidth(childData, childRegion) / 2);
              else
                childData.xOffset = 0;
              end
            elseif(v == "LEFT") then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = 0;
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = 0 + getWidth(childData, childRegion);
              else
                childData.xOffset = 0 + (getWidth(childData, childRegion) / 2);
              end
            elseif(v == "RIGHT") then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = 0 - getWidth(childData, childRegion);
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = 0;
              else
                childData.xOffset = 0 - (getWidth(childData, childRegion) / 2);
              end
            end
            WeakAuras.Add(childData);
          end
        end
        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    },
    align_v = {
      type = "select",
      width = WeakAuras.normalWidth,
      name = L["Vertical Align"],
      order = 15,
      values = OptionsPrivate.Private.rotated_align_types,
      get = function()
        if(#data.controlledChildren < 1) then
          return nil;
        end
        ---@type AnchorPoint?, AnchorPoint?, AnchorPoint?
        local alignedCenter, alignedBottom, alignedTop = "CENTER", "RIGHT", "LEFT";
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          if(childData) then
            local _, bottom, _, top = getRect(childData);
            local center = (bottom + top) / 2;
            if(math.abs(bottom) >= 0.01) then
              alignedBottom = nil;
            end
            if(math.abs(top) >= 0.01) then
              alignedTop = nil;
            end
            if(math.abs(center) >= 0.01) then
              alignedCenter = nil;
            end
          end
        end
        return alignedCenter or alignedBottom or alignedTop;
      end,
      set = function(info, v)
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          local childRegion = WeakAuras.GetRegion(childId)
          if(childData and childRegion) then
            if(v == "CENTER") then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = 0 - (getHeight(childData, childRegion) / 2);
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = 0 + (getHeight(childData, childRegion) / 2);
              else
                childData.yOffset = 0;
              end
            elseif(v == "RIGHT") then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = 0;
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = 0 + getHeight(childData, childRegion);
              else
                childData.yOffset = 0 + (getHeight(childData, childRegion) / 2);
              end
            elseif(v == "LEFT") then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = 0 - ( childData.height or childRegion.height);
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = 0;
              else
                childData.yOffset = 0 - (getHeight(childData, childRegion) / 2);
              end
            end
            WeakAuras.Add(childData);
          end
        end
        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    },
    distribute_h = {
      type = "range",
      control = "WeakAurasSpinBox",
      width = WeakAuras.normalWidth,
      name = L["Distribute Horizontally"],
      order = 20,
      softMin = -100,
      softMax = 100,
      bigStep = 1,
      get = function()
        if(#data.controlledChildren < 2) then
          return nil;
        end
        local spaced;
        local previousData;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          if(childData) then
            local left, _, right = getRect(childData);
            if not(previousData) then
              if not(math.abs(left) < 0.01 or math.abs(right) < 0.01) then
                return nil;
              end
              previousData = childData;
            else
              local pleft, _, pright = getRect(previousData);
              if(left - pleft > 0) then
                if not(spaced) then
                  spaced = left - pleft;
                else
                  if(math.abs(spaced - (left - pleft)) > 0.01) then
                    return nil;
                  end
                end
              elseif(right - pright < 0) then
                if not(spaced) then
                  spaced = right - pright;
                else
                  if(math.abs(spaced - (right - pright)) > 0.01) then
                    return nil;
                  end
                end
              else
                return nil;
              end
            end
            previousData = childData;
          end
        end
        return spaced;
      end,
      set = function(info, v)
        local xOffset = 0;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          local childRegion = WeakAuras.GetRegion(childId)
          if(childData and childRegion) then
            if(v > 0) then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = xOffset;
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = xOffset + getWidth(childData, childRegion);
              else
                childData.xOffset = xOffset + (getWidth(childData, childRegion) / 2);
              end
              xOffset = xOffset + v;
            elseif(v < 0) then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = xOffset - getWidth(childData, childRegion);
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = xOffset;
              else
                childData.xOffset = xOffset - (getWidth(childData, childRegion) / 2);
              end
              xOffset = xOffset + v;
            end
            WeakAuras.Add(childData);
          end
        end

        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    },
    distribute_v = {
      type = "range",
      control = "WeakAurasSpinBox",
      width = WeakAuras.normalWidth,
      name = L["Distribute Vertically"],
      order = 25,
      softMin = -100,
      softMax = 100,
      bigStep = 1,
      get = function()
        if(#data.controlledChildren < 2) then
          return nil;
        end
        local spaced;
        local previousData;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          if(childData) then
            local _, bottom, _, top = getRect(childData);
            if not(previousData) then
              if not(math.abs(bottom) < 0.01 or math.abs(top) < 0.01) then
                return nil;
              end
              previousData = childData;
            else
              local _, pbottom, _, ptop = getRect(previousData);
              if(bottom - pbottom > 0) then
                if not(spaced) then
                  spaced = bottom - pbottom;
                else
                  if(math.abs(spaced - (bottom - pbottom)) > 0.01) then
                    return nil;
                  end
                end
              elseif(top - ptop < 0) then
                if not(spaced) then
                  spaced = top - ptop;
                else
                  if(math.abs(spaced - (top - ptop)) > 0.01) then
                    return nil;
                  end
                end
              else
                return nil;
              end
            end
            previousData = childData;
          end
        end
        return spaced;
      end,
      set = function(info, v)
        local yOffset = 0;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          local childRegion = WeakAuras.GetRegion(childId)
          if(childData and childRegion) then
            if(v > 0) then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = yOffset;
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = yOffset + getHeight(childData, childRegion);
              else
                childData.yOffset = yOffset + (getHeight(childData, childRegion) / 2);
              end
              yOffset = yOffset + v;
            elseif(v < 0) then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = yOffset - getHeight(childData, childRegion);
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = yOffset;
              else
                childData.yOffset = yOffset - (getHeight(childData, childRegion) / 2);
              end
              yOffset = yOffset + v;
            end
            WeakAuras.Add(childData);
          end
        end

        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    },
    space_h = {
      type = "range",
      control = "WeakAurasSpinBox",
      width = WeakAuras.normalWidth,
      name = L["Space Horizontally"],
      order = 30,
      softMin = -100,
      softMax = 100,
      bigStep = 1,
      get = function()
        if(#data.controlledChildren < 2) then
          return nil;
        end
        local spaced;
        local previousData;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          if(childData) then
            local left, _, right = getRect(childData);
            if not(previousData) then
              if not(math.abs(left) < 0.01 or math.abs(right) < 0.01) then
                return nil;
              end
              previousData = childData;
            else
              local pleft, _, pright = getRect(previousData);
              if(left - pright > 0) then
                if not(spaced) then
                  spaced = left - pright;
                else
                  if(math.abs(spaced - (left - pright)) > 0.01) then
                    return nil;
                  end
                end
              elseif(right - pleft < 0) then
                if not(spaced) then
                  spaced = right - pleft;
                else
                  if(math.abs(spaced - (right - pleft)) > 0.01) then
                    return nil;
                  end
                end
              else
                return nil;
              end
            end
            previousData = childData;
          end
        end
        return spaced;
      end,
      set = function(info, v)
        local xOffset = 0;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          local childRegion = WeakAuras.GetRegion(childId)
          if(childData and childRegion) then
            if(v >= 0) then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = xOffset;
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = xOffset + getWidth(childData, childRegion);
              else
                childData.xOffset = xOffset + (getWidth(childData, childRegion) / 2);
              end
              xOffset = xOffset + v + getWidth(childData, childRegion);
            elseif(v < 0) then
              if(childData.selfPoint:find("LEFT")) then
                childData.xOffset = xOffset - getWidth(childData, childRegion);
              elseif(childData.selfPoint:find("RIGHT")) then
                childData.xOffset = xOffset;
              else
                childData.xOffset = xOffset - (getWidth(childData, childRegion) / 2);
              end
              xOffset = xOffset + v - getWidth(childData, childRegion);
            end
            WeakAuras.Add(childData);
          end
        end

        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    },
    space_v = {
      type = "range",
      control = "WeakAurasSpinBox",
      width = WeakAuras.normalWidth,
      name = L["Space Vertically"],
      order = 35,
      softMin = -100,
      softMax = 100,
      bigStep = 1,
      get = function()
        if(#data.controlledChildren < 2) then
          return nil;
        end
        local spaced;
        local previousData;
        for _, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          if(childData) then
            local _, bottom, _, top = getRect(childData);
            if not(previousData) then
              if not(math.abs(bottom) < 0.01 or math.abs(top) < 0.01) then
                return nil;
              end
              previousData = childData;
            else
              local _, pbottom, _, ptop = getRect(previousData);
              if(bottom - ptop > 0) then
                if not(spaced) then
                  spaced = bottom - ptop;
                else
                  if(math.abs(spaced - (bottom - ptop)) > 0.01) then
                    return nil;
                  end
                end
              elseif(top - pbottom < 0) then
                if not(spaced) then
                  spaced = top - pbottom;
                else
                  if(math.abs(spaced - (top - pbottom)) > 0.01) then
                    return nil;
                  end
                end
              else
                return nil;
              end
            end
            previousData = childData;
          end
        end
        return spaced;
      end,
      set = function(info, v)
        local yOffset = 0;
        for index, childId in pairs(data.controlledChildren) do
          local childData = WeakAuras.GetData(childId);
          local childRegion = WeakAuras.GetRegion(childId)
          if(childData and childRegion) then
            if(v >= 0) then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = yOffset;
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = yOffset + getHeight(childData, childRegion);
              else
                childData.yOffset = yOffset + (getHeight(childData, childRegion) / 2);
              end
              yOffset = yOffset + v + getHeight(childData, childRegion);
            elseif(v < 0) then
              if(childData.selfPoint:find("BOTTOM")) then
                childData.yOffset = yOffset - getHeight(childData, childRegion);
              elseif(childData.selfPoint:find("TOP")) then
                childData.yOffset = yOffset;
              else
                childData.yOffset = yOffset - (getHeight(childData, childRegion) / 2);
              end
              yOffset = yOffset + v - getHeight(childData, childRegion);
            end
            WeakAuras.Add(childData);
          end
        end

        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    }
  }
end

-- ForeverAuras: re-adds a Modern Aura Group's children a few at a time
-- (about 16 ms a frame) after a group setting changed, under the layout
-- hold, so the pack is chained and arranged once at the end. A new change
-- while a batch runs starts the batch over with the latest settings; the
-- batch goes on when the options window closes (the saved settings must
-- reach every child), and the hold is released whatever happens.
local readdFrame = CreateFrame("Frame")
readdFrame:Hide()
local readdJob
local function FinishReadd(job)
  readdJob = nil
  readdFrame:Hide()
  local modern = OptionsPrivate.Private.BlizzardAuraDisplay
  if job.held and modern and modern.EndFlowLoad then modern.EndFlowLoad() end
  if WeakAuras.IsOptionsOpen() then
    OptionsPrivate.ResetMoverSizer()
    WeakAuras.ClearAndUpdateOptions(job.data.id)
  end
end
local function RunReadd(job, budget)
  local finish = debugprofilestop() + budget
  while job.index <= #job.children do
    local childId = job.children[job.index]
    job.index = job.index + 1
    local childData = WeakAuras.GetData(childId)
    if childData then WeakAuras.Add(childData) end
    if debugprofilestop() > finish then break end
  end
  return job.index > #job.children
end
readdFrame:SetScript("OnUpdate", function()
  local job = readdJob
  if not job then readdFrame:Hide(); return end
  local ok, done = xpcall(RunReadd, geterrorhandler(), job, 16)
  if not ok then done = job.index > #job.children end
  if done then FinishReadd(job) end
end)
function OptionsPrivate.ReaddFlowChildren(data)
  local children = {}
  for _, childId in ipairs(data.controlledChildren or {}) do children[#children + 1] = childId end
  if readdJob then
    -- The running batch is restarted with the latest settings; its hold is
    -- kept (the same group, or released for the previous group below).
    if readdJob.data == data then readdJob.children, readdJob.index = children, 1; return end
    FinishReadd(readdJob)
  end
  local modern = OptionsPrivate.Private.BlizzardAuraDisplay
  local job = {data = data, children = children, index = 1, held = modern and modern.BeginFlowLoad and modern.EndFlowLoad and true or false}
  if job.held then modern.BeginFlowLoad() end
  local ok, done = xpcall(RunReadd, geterrorhandler(), job, 16)
  if not ok then done = job.index > #job.children end
  if done then FinishReadd(job); return end
  readdJob = job
  readdFrame:Show()
end

-- Create region options table
local function createOptions(id, data)
  -- Region options
  -- Modern Aura Group: Aura (Modern) children grow together (SecretAuraFlow.lua).
  local Display = OptionsPrivate.Private.BlizzardAuraDisplay
  -- The group and its displays are rebuilt once per frame at most, so a
  -- dragged slider does not rebuild every display on every step.
  local pendingFlowSave
  local function SaveFlow(key, value)
    data[key] = value
    if pendingFlowSave then return end
    pendingFlowSave = true
    C_Timer.After(0, function()
      pendingFlowSave = nil
      -- ForeverAuras: every child is re-added for the new setting. The
      -- group is re-added now; the children follow in batches over the next
      -- frames (OptionsPrivate.ReaddFlowChildren), with the group's row
      -- chained and its preview arranged once at the end: re-adding a few
      -- hundred displays in one frame froze the client for seconds, and
      -- each re-add chained the whole row again (issue #136).
      WeakAuras.Add(data)
      OptionsPrivate.ReaddFlowChildren(data)
    end)
  end
  local function FlowOff() return not data.blizzardFlow end
  local options = {
    __title = data.blizzardFlow and "Modern Aura Group Settings" or L["Group Settings"],
    __order = 1,
    -- Shown only for a Modern Aura Group (made from New or the group menu),
    -- laid out like the Dynamic Group settings.
    blizzardFlowGrowth = {
      type = "select", width = WeakAuras.doubleWidth, order = 0.61, name = L["Grow"], hidden = FlowOff,
      values = function()
        local values = CopyTable(Display.flowGrowths)
        if data.blizzardFlowFrames == nil then values.GRID = L["Grid"] end
        return values
      end,
      -- Grid is only offered without Group by Frame; a sorting entry with no
      -- value would show as a blank row in the dropdown, so the list follows.
      sorting = function()
        local order = {"RIGHT", "LEFT", "DOWN", "UP", "CENTER_HORIZONTAL", "CENTER_VERTICAL"}
        if data.blizzardFlowFrames == nil then order[#order + 1] = "GRID" end
        return order
      end,
      get = function() return Display.FlowGrid(data) and "GRID" or data.blizzardFlowGrowth or "RIGHT" end,
      set = function(_, v)
        if v == "GRID" then
          data.blizzardFlowGridType = Display.GridType(data)
          SaveFlow("blizzardFlowGrid", true)
        else
          data.blizzardFlowGrid = nil
          SaveFlow("blizzardFlowGrowth", v)
        end
      end,
    },
    -- ForeverAuras: the row layout (SecretAuraFlow.lua, FlowGroupOwned). New
    -- Modern Aura Groups start their row at the group's anchor; groups made
    -- before 1.1.0 keep the old layout (the first display anchors the row)
    -- until this box is unticked, so existing packs are not moved. Shown as
    -- one checkbox, ticked for the old layout, so a new group shows it
    -- unticked and can be left alone.
    blizzardFlowOrigin = {
      type = "toggle", width = WeakAuras.doubleWidth, order = 0.611, name = L["Use old row layout (before 1.1.0)"],
      desc = L["Leave this unticked: the row starts where you place the group, like a Dynamic Group.\n\nGroups made before 1.1.0 have it ticked so they keep looking the same. Untick it to move such a group to the new layout, then place the group where the row should start."],
      hidden = function() return FlowOff() or data.blizzardFlowFrames ~= nil or Display.FlowGrid(data) end,
      get = function() return data.blizzardFlowOrigin ~= "group" end,
      set = function(_, v) SaveFlow("blizzardFlowOrigin", (not v) and "group" or nil) end,
    },
    blizzardFlowGridType = {
      type = "select", width = WeakAuras.normalWidth, order = 0.631, name = L["Grid direction"],
      values = OptionsPrivate.Private.grid_types,
      desc = "Every aura needs Show On: Aura(s) Found and the same single unit. A centered last row lines up with the rows above.",
      hidden = function() return FlowOff() or not Display.FlowGrid(data) end,
      get = function() return Display.GridType(data) end,
      set = function(_, v) SaveFlow("blizzardFlowGridType", v) end,
    },
    blizzardFlowPerRow = {
      type = "range", control = "WeakAurasSpinBox", width = WeakAuras.normalWidth, order = 0.632,
      name = function() return Display.GridType(data):find("^[RLH]") and L["Row Width"] or L["Column Height"] end,
      min = 1, softMax = 20, step = 1,
      hidden = function() return FlowOff() or not Display.FlowGrid(data) end,
      get = function() return data.blizzardFlowPerRow or 6 end,
      set = function(_, v) SaveFlow("blizzardFlowPerRow", v) end,
    },
    blizzardFlowRowSpace = {
      type = "range", control = "WeakAurasSpinBox", width = WeakAuras.normalWidth, order = 0.633, name = L["Row Space"],
      softMin = 0, softMax = 300, step = 1,
      hidden = function() return FlowOff() or not Display.FlowGrid(data) end,
      get = function() return (Display.GridSpaces(data)) end,
      set = function(_, v) SaveFlow("blizzardFlowRowSpace", v) end,
    },
    blizzardFlowColumnSpace = {
      type = "range", control = "WeakAurasSpinBox", width = WeakAuras.normalWidth, order = 0.634, name = L["Column Space"],
      softMin = 0, softMax = 300, step = 1,
      hidden = function() return FlowOff() or not Display.FlowGrid(data) end,
      get = function() return select(2, Display.GridSpaces(data)) end,
      set = function(_, v) SaveFlow("blizzardFlowColumnSpace", v) end,
    },
    blizzardFlowUseFrames = {
      type = "toggle", width = WeakAuras.normalWidth, order = 0.62, name = L["Group by Frame"], hidden = FlowOff,
      desc = "Show the auras on each unit's frame or nameplate. The Position and Size settings place them on the frame.",
      get = function() return data.blizzardFlowFrames ~= nil end,
      set = function(_, v) SaveFlow("blizzardFlowFrames", v and "UNITFRAME" or nil) end,
    },
    blizzardFlowFrames = {
      type = "select", width = WeakAuras.normalWidth, order = 0.63, name = L["Group by Frame"], hidden = FlowOff,
      values = {UNITFRAME = "Unit Frames", NAMEPLATE = "Nameplates"}, sorting = {"UNITFRAME", "NAMEPLATE"},
      disabled = function() return data.blizzardFlowFrames == nil end,
      get = function() return data.blizzardFlowFrames end,
      set = function(_, v) SaveFlow("blizzardFlowFrames", v) end,
    },
    blizzardFlowSpacing = {
      type = "range", control = "WeakAurasSpinBox", width = WeakAuras.normalWidth, order = 0.64, name = L["Space"],
      min = -20, softMax = 50, step = 1, hidden = function() return FlowOff() or Display.FlowGrid(data) end,
      get = function() return data.blizzardFlowSpacing or 2 end,
      set = function(_, v) SaveFlow("blizzardFlowSpacing", v) end,
    },
    blizzardFlowSpacingSpace = {type = "description", name = "", order = 0.645, width = WeakAuras.normalWidth,
      hidden = function() return FlowOff() or Display.FlowGrid(data) end},
    blizzardFlowSortMode = {
      type = "select", width = WeakAuras.doubleWidth, order = 0.65, name = L["Sort"], hidden = FlowOff,
      values = Display.flowSortModes,
      sorting = Display.flowSortOrder,
      desc = L["Ascending and Descending sort by remaining time. Outside a Grid, Aura (Modern) displays with Show On: Aura(s) Found, spell IDs, and the same unit, filters and look share one sorted row; other displays keep their normal layout."],
      get = function() return Display.FlowSortMode(data) end,
      set = function(_, v)
        data.blizzardFlowSort, data.blizzardFlowReverse, data.blizzardFlowMerge = nil, nil, nil
        SaveFlow("blizzardFlowSortMode", v)
      end,
    },
    blizzardFlowSortNote = {
      type = "description", width = WeakAuras.doubleWidth, order = 0.66, fontSize = "medium",
      name = "|cffffd100" .. L["Auras sort together only when their displays have the same unit, filters and look."] .. "|r",
      hidden = function() return FlowOff() or Display.FlowGrid(data) or Display.FlowSortMode(data) == "none" end,
    },
    blizzardFlowUseLimit = {
      type = "toggle", width = WeakAuras.normalWidth, order = 0.67, name = L["Limit"], hidden = FlowOff,
      desc = function()
        if Display.FlowGrid(data) or data.blizzardFlowFrames ~= nil then
          return L["Most auras shown by each Aura (Modern) display, or each sorted row."]
        end
        return L["Most auras shown by each Aura (Modern) display, or each sorted row. The row is also cut off at the length of this many icons of the first display's size, so displays of other sizes can be partly cut."]
      end,
      get = function() return data.blizzardFlowUseLimit or false end,
      set = function(_, v) SaveFlow("blizzardFlowUseLimit", v or nil) end,
    },
    blizzardFlowLimit = {
      type = "range", control = "WeakAurasSpinBox", width = WeakAuras.normalWidth, order = 0.68, name = L["Limit"],
      min = 1, softMax = 40, step = 1, hidden = FlowOff,
      disabled = function() return not data.blizzardFlowUseLimit end,
      get = function() return data.blizzardFlowLimit or 5 end,
      set = function(_, v) SaveFlow("blizzardFlowLimit", v) end,
    },
    groupIcon = {
      type = "input",
      width = WeakAuras.doubleWidth - 0.15,
      name = L["Group Icon"],
      desc = L["Set Thumbnail Icon"],
      order = 0.50,
      get = function()
        return data.groupIcon and tostring(data.groupIcon) or ""
      end,
      set = function(info, v)
        data.groupIcon = v
        WeakAuras.Add(data)
        WeakAuras.UpdateThumbnail(data)
      end
    },
    chooseIcon = {
      type = "execute",
      width = 0.15,
      name = L["Choose"],
      order = 0.51,
      func = function()
         OptionsPrivate.OpenIconPicker(data, { [data.id] = {"groupIcon"} }, true)
       end,
       imageWidth = 24,
       imageHeight = 24,
       control = "WeakAurasIcon",
       image = "Interface\\AddOns\\ForeverAuras\\Media\\Textures\\browse",
    },
    -- Alignment/Distribute options are added below
    scale = {
      type = "range",
      control = "WeakAurasSpinBox",
      width = WeakAuras.normalWidth,
      name = L["Group Scale"],
      order = 45,
      min = 0.05,
      softMax = 2,
      max = 10,
      bigStep = 0.05,
      get = function()
        return data.scale or 1
      end,
      set = function(info, v)
        data.scale = data.scale or 1
        local change = 1 - (v/data.scale)
        data.xOffset = data.xOffset/(1-change)
        data.yOffset = data.yOffset/(1-change)
        data.scale = v
        WeakAuras.Add(data);
        OptionsPrivate.ResetMoverSizer();
      end
    },
    alpha = {
      type = "range",
      control = "WeakAurasSpinBox",
      width = WeakAuras.normalWidth,
      name = L["Group Alpha"],
      order = 46,
      min = 0,
      max = 1,
      bigStep = 0.01,
      isPercent = true
    },
    sharedFrameLevel = {
      type = "toggle",
      width = WeakAuras.normalWidth,
      name = L["Flat Framelevels"],
      desc = L["The group and all direct children will share the same base frame level."],
      order = 47,
      set = function(info, v)
        data.sharedFrameLevel = v
        WeakAuras.Add(data)
        for parent in OptionsPrivate.Private.TraverseParents(data) do
          WeakAuras.Add(parent)
        end
      end
    },
    endHeader = {
      type = "header",
      order = 100,
      name = "",
    },
  };

  local hasSubGroups = false
  local hasDynamicSubGroup = false
  for index, childId in pairs(data.controlledChildren) do
    local childData = WeakAuras.GetData(childId);
    if childData.controlledChildren then
      hasSubGroups = true
    end
    if childData.regionType == "dynamicgroup" then
      hasDynamicSubGroup = true
    end

    if hasSubGroups and hasDynamicSubGroup then
      break
    end
  end


  -- A Modern Aura Group places its displays itself, like a Dynamic Group.
  if not hasSubGroups and not data.blizzardFlow then
    for k, v in pairs(createDistributeAlignOptions(id, data)) do
      options[k] = v
    end
  end

  if not hasDynamicSubGroup then
    for k, v in pairs(OptionsPrivate.commonOptions.BorderOptions(id, data, nil, nil, 70)) do
      options[k] = v
    end
  end

  return {
    group = options,
    -- A Modern Aura Group grouped by frame can choose its Anchor point.
    position = OptionsPrivate.commonOptions.PositionOptions(id, data, nil, true,
      function() return not (data.blizzardFlow and data.blizzardFlowFrames) end, true),
  };
end

local function createThumbnail()
  -- frame
  local thumbnail = CreateFrame("Frame", nil, UIParent);
  thumbnail:SetWidth(32);
  thumbnail:SetHeight(32);

  -- border
  local border = thumbnail:CreateTexture(nil, "OVERLAY");
  border:SetAllPoints(thumbnail);
  border:SetTexture("Interface\\BUTTONS\\UI-Quickslot2.blp");
  border:SetTexCoord(0.2, 0.8, 0.2, 0.8);

  local icon = thumbnail:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints(thumbnail)
  thumbnail.icon = icon

  return thumbnail
end

local function createDefaultIcon(parent)
  -- default Icon
  local defaultIcon = CreateFrame("Frame", nil, parent);
  parent.defaultIcon = defaultIcon;

  local t1 = defaultIcon:CreateTexture(nil, "ARTWORK");
  t1:SetWidth(24);
  t1:SetHeight(8);
  t1:SetColorTexture(0.8, 0, 0, 0.5);
  t1:SetPoint("TOP", parent, "TOP", 0, -6);
  local t2 = defaultIcon:CreateTexture(nil, "ARTWORK");
  t2:SetWidth(20);
  t2:SetHeight(20);
  t2:SetColorTexture(0.2, 0.8, 0.2, 0.5);
  t2:SetPoint("TOP", t1, "BOTTOM", 0, 5);
  local t3 = defaultIcon:CreateTexture(nil, "ARTWORK");
  t3:SetWidth(20);
  t3:SetHeight(12);
  t3:SetColorTexture(0.1, 0.25, 1, 0.5);
  t3:SetPoint("TOP", t2, "BOTTOM", -5, 8);

  return defaultIcon
end

-- Modify preview thumbnail
local function modifyThumbnail(parent, frame, data)
  function frame:SetIcon()
    if data.groupIcon then
      local success = OptionsPrivate.Private.SetTextureOrAtlas(frame.icon, data.groupIcon)
      if success then
        if frame.defaultIcon then
          frame.defaultIcon:Hide()
        end
        frame.icon:Show()
        return
      end
    end

    if frame.icon then
      frame.icon:Hide()
    end
    if not frame.defaultIcon then
      frame.defaultIcon = createDefaultIcon(frame)
    end
    frame.defaultIcon:Show()
  end

  frame:SetIcon()
end

-- Create "new region" preview
local function createIcon()
  local thumbnail = createThumbnail()
  thumbnail.defaultIcon = createDefaultIcon(thumbnail)
  return thumbnail
end
-- The New list's Modern Aura Group icon: three aura tiles of rising brightness
-- on a dark panel, with a thin accent line below.
function OptionsPrivate.CreateModernGroupIcon()
  local icon = CreateFrame("Frame", nil, UIParent)
  icon:SetSize(32, 32)
  local background = icon:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(icon)
  background:SetColorTexture(0.07, 0.09, 0.13, 1)
  local colors = {{0.16, 0.55, 0.95}, {0.35, 0.75, 1}, {0.6, 0.95, 1}}
  for index, color in ipairs(colors) do
    local tile = icon:CreateTexture(nil, "ARTWORK")
    tile:SetColorTexture(color[1], color[2], color[3], 1)
    icon["tile" .. index] = tile
  end
  local accent = icon:CreateTexture(nil, "ARTWORK")
  accent:SetColorTexture(0.35, 0.75, 1, 0.9)
  -- Sizes follow the button the icon is placed on.
  local function Layout(self)
    local size = math.min(self:GetWidth() or 0, self:GetHeight() or 0)
    if size <= 0 then return end
    local tile, gap = size * 0.24, size * 0.06
    for index = 1, 3 do
      local t = self["tile" .. index]
      t:ClearAllPoints()
      t:SetSize(tile, tile)
      t:SetPoint("CENTER", self, "CENTER", (index - 2) * (tile + gap), size * 0.06)
    end
    accent:ClearAllPoints()
    accent:SetSize(size * 0.72, math.max(1, size * 0.05))
    accent:SetPoint("CENTER", self, "CENTER", 0, -size * 0.24)
  end
  icon:SetScript("OnSizeChanged", Layout)
  Layout(icon)
  return icon
end

-- Register new region type options with ForeverAuras
OptionsPrivate.registerRegions = OptionsPrivate.registerRegions or {}
table.insert(OptionsPrivate.registerRegions, function()
  OptionsPrivate.Private.RegisterRegionOptions("group", createOptions, createIcon, L["Group"], createThumbnail, modifyThumbnail,
                                              L["Controls the positioning and configuration of multiple displays at the same time"])
end)
