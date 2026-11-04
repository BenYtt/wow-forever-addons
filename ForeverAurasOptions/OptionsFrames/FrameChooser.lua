-- Modified for ForeverAuras, 2026-09-18.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- Lua APIs
local pairs = pairs

-- WoW APIs
local CreateFrame, IsMouseButtonDown, SetCursor, ResetCursor
  = CreateFrame, IsMouseButtonDown, SetCursor, ResetCursor

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local frameChooserFrame
local frameChooserBox

local oldFocus
local oldFocusName

-- if frame doesn't have a name, try to use the key from it's parent
local function recurseGetName(frame)
  local name = frame.GetName and frame:GetName() or nil
  if name then
     return name
  end
  local parent = frame.GetParent and frame:GetParent()
  if parent then
     for key, child in pairs(parent) do
        if child == frame then
           return (recurseGetName(parent) or "") .. "." .. key
        end
     end
  end
end

function OptionsPrivate.StartFrameChooser(data, path)
  local frame = OptionsPrivate.Private.OptionsFrame();
  if not(frameChooserFrame) then
    frameChooserFrame = CreateFrame("Frame");
    frameChooserBox = CreateFrame("Frame", nil, frameChooserFrame, "BackdropTemplateWeakAuras");
    frameChooserBox:SetFrameStrata("TOOLTIP");
    frameChooserBox:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = {left = 0, right = 0, top = 0, bottom = 0}
    });
    frameChooserBox:SetBackdropBorderColor(0, 1, 0);
    frameChooserBox:Hide();
  end
  local givenValue = OptionsPrivate.Private.ValueFromPath(data, path);
  -- A new pick must never confirm the previous session's hovered target.
  oldFocus, oldFocusName = nil, nil;
  -- Glow pickers need frames; only position-only aura anchors allow other regions.
  local requireFrame = path[1] ~= "anchorFrameFrame" or data.anchorFrameParent ~= false

  frameChooserFrame:SetScript("OnUpdate", function()
    if(IsMouseButtonDown("RightButton")) then
      OptionsPrivate.Private.ValueToPath(data, path, givenValue);
      OptionsPrivate.StopFrameChooser(data);
      WeakAuras.FillOptions()
    else
      SetCursor("CAST_CURSOR");

      local focus
      if GetMouseFoci then
        local foci = GetMouseFoci()
        focus = foci[1] or nil
      end
      local focusName;

      -- Exclude the options UI and forbidden ancestry before inspecting names.
      local ancestor = focus
      while ancestor do
        if ancestor == frame or (ancestor.IsForbidden and ancestor:IsForbidden()) then
          focus = nil
          break
        end
        ancestor = ancestor.GetParent and ancestor:GetParent()
      end

      if(focus) then
        focusName = recurseGetName(focus)
        if(focusName == "WorldFrame" or not focusName) then
          focusName = nil;
          local focusIsGroup = false;
          for id, regionData in pairs(OptionsPrivate.Private.regions) do
            if(regionData.region and regionData.region:IsVisible() and regionData.region:IsMouseOver()) then
              local isGroup = regionData.regionType == "group" or regionData.regionType == "dynamicgroup";
              if (not focusName or (not isGroup and focusIsGroup)) then
                focus = regionData.region;
                focusName = "WeakAuras:"..id;
                focusIsGroup = focusIsGroup;
              end
            end
          end
        end

        -- Keep only names that resolve back to the hovered object at runtime.
        if focusName and not OptionsPrivate.Private.AuraFrameTarget(focusName)
          and OptionsPrivate.Private.GetSanitizedFrame(focusName, requireFrame) ~= focus then
          focusName = nil
        end

        if(focusName and (focus ~= oldFocus or focusName ~= oldFocusName)) then
          if(focusName) then
            frameChooserBox:ClearAllPoints();
            frameChooserBox:SetPoint("bottomleft", focus, "bottomleft", -4, -4);
            frameChooserBox:SetPoint("topright", focus, "topright", 4, 4);
            frameChooserBox:Show();
          end

          if(focusName ~= oldFocusName) then
            OptionsPrivate.Private.ValueToPath(data, path, focusName);
            oldFocusName = focusName;
            WeakAuras.FillOptions()
          end
          oldFocus = focus;
        end
      end

      -- Confirm the current valid hover, not a stale target from an earlier frame.
      if not(focusName) then
        oldFocus, oldFocusName = nil, nil;
        frameChooserBox:Hide();
      elseif IsMouseButtonDown("LeftButton") then
        OptionsPrivate.StopFrameChooser(data);
      end
    end
  end);
end

function OptionsPrivate.StopFrameChooser(data)
  if(frameChooserFrame) then
    frameChooserFrame:SetScript("OnUpdate", nil);
    frameChooserBox:Hide();
  end
  ResetCursor();
  WeakAuras.Add(data);
end
