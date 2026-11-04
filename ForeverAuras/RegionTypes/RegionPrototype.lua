-- Modified for ForeverAuras, 2026-10-07.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("RegionRegionPrototype")
---@class WeakAuras
local WeakAuras = WeakAuras;
local L = WeakAuras.L;
local GetAtlasInfo = C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo

Private.regionPrototype = {};

-- Alpha
function Private.regionPrototype.AddAlphaToDefault(default)
  default.alpha = 1.0;
end

function Private.SetBorderPixelPerfect(frame, enabled)
  enabled = enabled == true
  local scale = enabled and PixelUtil.GetPixelToUIUnitFactor() or 1
  frame:ForEachPiece(function(_, piece)
    piece:SetSnapToPixelGrid(not enabled)
    if enabled and piece:GetTexelSnappingBias() ~= 0 then
      piece.originalSnappingBias = piece:GetTexelSnappingBias()
      piece:SetTexelSnappingBias(0)
    elseif not enabled and piece.originalSnappingBias then
      piece:SetTexelSnappingBias(piece.originalSnappingBias)
      piece.originalSnappingBias = nil
    end
  end)
  frame:SetIgnoreParentScale(enabled)
  frame:SetScale(scale)
end

function Private.BorderUnits(frame, relative)
  return relative:GetEffectiveScale() / frame:GetEffectiveScale()
end

-- Progress Sources
function Private.regionPrototype.AddProgressSourceToDefault(default)
  default.progressSource = {-1, ""}
  default.useAdjustededMax = false
  default.useAdjustededMin = false
end

local screenWidth, screenHeight = math.ceil(GetScreenWidth() / 20) * 20, math.ceil(GetScreenHeight() / 20) * 20;

function Private.GetAnchorsForData(data, filter)
  local result = {}
  if not data.controlledChildren then
    if not Private.regionOptions[data.regionType] then
      return
    end

    local anchors
    if Private.regionOptions[data.regionType].getAnchors then
      anchors = Private.regionOptions[data.regionType].getAnchors(data)
    else
      anchors = Private.default_types_for_anchor
    end

    for anchorId, anchorData in pairs(anchors) do
      if anchorData.type == filter then
        result[anchorId] = anchorData.display
      end
    end

    local subElementTypeCounter = {}
    for i, subRegion in ipairs(data.subRegions) do
      subElementTypeCounter[subRegion.type] = (subElementTypeCounter[subRegion.type] or 0) + 1
      local getAnchors = Private.subRegionOptions[subRegion.type].getAnchors
      if getAnchors then
        local subRegionTypeData = Private.subRegionTypes[subRegion.type]

        local anchors = getAnchors(subRegion)
        for key, anchorData in pairs(anchors) do
          if anchorData.type == filter then
            local subElementName = subRegionTypeData.displayName .. " " .. subElementTypeCounter[subRegion.type]
            local anchorId = "sub." .. i .. "." ..  key
            result[anchorId] = {subElementName, anchorData.display}
          end
        end
      end
    end

  end
  return result
end

-- Sound / Chat Message / Custom Code
function Private.regionPrototype.AddProperties(properties, defaultsForRegion)
  properties["sound"] = {
    display = L["Sound"],
    action = "SoundPlay",
    type = "sound",
  };
  properties["chat"] = {
    display = L["Chat Message"],
    action = "SendChat",
    type = "chat",
  };
  properties["customcode"] = {
    display = L["Run Custom Code"],
    action = "RunCode",
    type = "customcode"
  }
  properties["xOffsetRelative"] = {
    display = L["Relative X-Offset"],
    setter = "SetXOffsetRelative",
    type = "number",
    softMin = -screenWidth,
    softMax = screenWidth,
    bigStep = 1
  }
  properties["yOffsetRelative"] = {
    display = L["Relative Y-Offset"],
    setter = "SetYOffsetRelative",
    type = "number",
    softMin = -screenHeight,
    softMax = screenHeight,
    bigStep = 1
  }
  properties["glowexternal"] = {
    display = L["Glow External Element"],
    action = "GlowExternal",
    type = "glowexternal"
  }

  if (defaultsForRegion and defaultsForRegion.alpha) then
    properties["alpha"] = {
      display = L["Alpha"],
      setter = "SetRegionAlpha",
      type = "number",
      min = 0,
      max = 1,
      bigStep = 0.01,
      isPercent = true
    }
    properties["alphaFromBoolean"] = {
      display = L["Alpha"] .. " (Boolean)",
      setter = "SetRegionAlpha",
      type = "bool",
      valueFromBoolean = true,
      baseProperty = "alpha",
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

  if defaultsForRegion and defaultsForRegion.progressSource then
    properties["progressSource"] = {
      display = L["Progress Source"],
      setter = "SetProgressSource",
      type = "progressSource",
      values = {},
    }

    properties["adjustedMin"] = {
      display = L["Minimum Progress"],
      setter = "SetAdjustedMin",
      type = "string",
      validate = WeakAuras.ValidateNumericOrPercent,
    }

    properties["adjustedMax"] = {
      display = L["Maximum Progress"],
      setter = "SetAdjustedMax",
      type = "string",
      validate = WeakAuras.ValidateNumericOrPercent,
    }
  end
end

local function SoundRepeatStop(self)
  Private.StartProfileSystem("sound");
  if (self.soundRepeatTimer) then
    WeakAuras.timer:CancelTimer(self.soundRepeatTimer);
    self.soundRepeatTimer = nil;
  end
  Private.StopProfileSystem("sound");
end

local function SoundStop(self, fadeoutTime)
  Private.StartProfileSystem("sound");
  if (self.soundHandle) then
    StopSound(self.soundHandle, fadeoutTime);
  end
  Private.StopProfileSystem("sound");
end

local function SoundPlayHelper(self)
  Private.StartProfileSystem("sound");
  local options = self.soundOptions;
  self.soundHandle = nil;
  if (not options or options.sound_type == "Stop") then
    Private.StopProfileSystem("sound");
    return;
  end

  if (WeakAuras.IsOptionsOpen() or Private.SquelchingActions() or WeakAuras.InLoadingScreen()) then
    Private.StopProfileSystem("sound");
    return;
  end

  if options.sound == " Fojji" then
    local file, message = Private.ResolveFojjiRecordedSound(options.sound_fojji or "")
    local data = WeakAuras.GetData(self.id)
    if data then Private.AuraWarnings.UpdateWarning(data.uid, "fojji_recorded_sound", message and "warning" or nil, message) end
    if file then
      local ok, _, handle = pcall(PlaySoundFile, file, options.sound_channel or "Master")
      if ok then self.soundHandle = handle end
    end
  elseif (options.sound == " custom") then
    local ok, _, handle = pcall(PlaySoundFile, options.sound_path, options.sound_channel or "Master")
    if ok then
      self.soundHandle = handle
    end
  elseif (options.sound == " KitID") then
    local ok, _, handle = pcall(PlaySound,options.sound_kit_id, options.sound_channel or "Master")
    if ok then
      self.soundHandle = handle
    end
  else
    local ok, _, handle = pcall(PlaySoundFile, options.sound, options.sound_channel or "Master")
    if ok then
      self.soundHandle = handle
    end
  end
  Private.StopProfileSystem("sound");
end

local function hasSound(options)
  if options.sound_type == "Stop" then
    return true
  end
  if options.sound == " Fojji" then
    return true
  elseif (options.sound == " custom") then
    if (options.sound_path and options.sound_path ~= "") then
      return true
    end
  elseif (options.sound == " KitID") then
    if (options.sound_kit_id and options.sound_kit_id ~= "") then
      return true
    end
  else
    if options.sound and options.sound ~= "" then
      return true
    end
  end
  return false
end

local function SoundPlay(self, options)
  if (not options or WeakAuras.IsOptionsOpen()) then
    return
  end
  Private.StartProfileSystem("sound");
  if not hasSound(options) then
    Private.StopProfileSystem("sound")
    return
  end

  local fadeoutTime = options.sound_type == "Stop" and options.sound_fade and options.sound_fade * 1000 or 0
  self:SoundStop(fadeoutTime);
  self:SoundRepeatStop();

  self.soundOptions = options;
  SoundPlayHelper(self);

  local loop = options.do_loop or options.sound_type == "Loop";
  if (loop and options.sound_repeat and options.sound_repeat < Private.maxTimerDuration) then
    self.soundRepeatTimer = WeakAuras.timer:ScheduleRepeatingTimer(SoundPlayHelper, options.sound_repeat, self);
  end
  Private.StopProfileSystem("sound");
end

local function SendChat(self, options)
  if (not options or WeakAuras.IsOptionsOpen()) then
    return
  end
  Private.HandleChatAction(options.message_type, options.message, options.message_dest, options.message_dest_isunit, options.message_channel, options.r, options.g, options.b, self, {customFunc = options.message_custom}, nil, options.message_formaters);
end

local function RunCode(self, func)
  if func and not WeakAuras.IsOptionsOpen() then
    Private.ActivateAuraEnvironment(self.id, self.cloneId, self.state, self.states);
    xpcall(func, Private.GetErrorHandlerId(self.id, L["Custom Condition Code"]));
    Private.ActivateAuraEnvironment(nil);
  end
end

local function GlowExternal(self, options)
  if (not options or WeakAuras.IsOptionsOpen()) then
    return
  end
  Private.HandleGlowAction(options, self)
end

local function UpdatePosition(self)
  if (not self.anchorPoint or not self.relativeTo or not self.relativePoint) then
    return;
  end

  local xOffset = self.xOffset + (self.xOffsetAnim or 0) + (self.xOffsetRelative or 0)
  local yOffset = self.yOffset + (self.yOffsetAnim or 0) + (self.yOffsetRelative or 0)
  self:RealClearAllPoints();

  xpcall(self.SetPoint, Private.GetErrorHandlerId(self.id, L["Update Position"]), self, self.anchorPoint, self.relativeTo, self.relativePoint, xOffset, yOffset);
end

local function ResetPosition(self)
  self.anchorPoint = nil;
  self.relativeTo = nil;
  self.relativePoint = nil;
end

local function SetAnchor(self, anchorPoint, relativeTo, relativePoint)
  if self.anchorPoint == anchorPoint and self.relativeTo == relativeTo and self.relativePoint == relativePoint then
    return
  end

  self.anchorPoint = anchorPoint;
  self.relativeTo = relativeTo;
  self.relativePoint = relativePoint;

  UpdatePosition(self);
end

local function SetOffset(self, xOffset, yOffset)
  if (self.xOffset == xOffset and self.yOffset == yOffset) then
    return;
  end
  self.xOffset = xOffset;
  self.yOffset = yOffset;
  UpdatePosition(self);
end

local function SetXOffset(self, xOffset)
  self:SetOffset(xOffset, self:GetYOffset());
end

local function SetYOffset(self, yOffset)
  self:SetOffset(self:GetXOffset(), yOffset);
end

local function GetXOffset(self)
  return self.xOffset;
end

local function GetYOffset(self)
  return self.yOffset;
end

local function SetOffsetRelative(self, xOffsetRelative, yOffsetRelative)
  if (self.xOffsetRelative == xOffsetRelative and self.yOffsetRelative == yOffsetRelative) then
    return
  end
  self.xOffsetRelative = xOffsetRelative
  self.yOffsetRelative = yOffsetRelative
  UpdatePosition(self)
end

local function SetXOffsetRelative(self, xOffsetRelative)
  self:SetOffsetRelative(xOffsetRelative, self:GetYOffsetRelative())
end

local function SetYOffsetRelative(self, yOffsetRelative)
  self:SetOffsetRelative(self:GetXOffsetRelative(), yOffsetRelative)
end

local function GetXOffsetRelative(self)
  return self.xOffsetRelative
end

local function GetYOffsetRelative(self)
  return self.yOffsetRelative
end

local function SetOffsetAnim(self, xOffset, yOffset)
  if (self.xOffsetAnim == xOffset and self.yOffsetAnim == yOffset) then
    return;
  end
  self.xOffsetAnim = xOffset;
  self.yOffsetAnim = yOffset;
  UpdatePosition(self);
end

-- gate = {read = function() return <secret boolean: aura shown> end, mode =
-- "active"|"missing"}, or nil to return the display's alpha to its own hands.
-- Displays whose alpha follows a secret cooldown's time left. The curve
-- evaluation is a value, not a binding, so it is applied again a few times a
-- second while any such display is shown (a handful at most).
local secretRemaining = setmetatable({}, {__mode = "k"})
local secretRemainingTicker
local remainingCurves = {}
local function RemainingCurve(window, wanted)
  local key = tostring(window.op) .. "|" .. tostring(window.value) .. "|" .. tostring(wanted)
  local curve = remainingCurves[key]
  if curve then return curve end
  if not (C_CurveUtil and C_CurveUtil.CreateCurve) then return end
  curve = C_CurveUtil.CreateCurve()
  curve:SetType(Enum.LuaCurveType.Step)
  local value, op = window.value, window.op
  local eps = 0.001
  -- Open where the comparison on the time left holds; a ready spell is 0.
  if op == "<" then curve:AddPoint(0, wanted); curve:AddPoint(value, 0)
  elseif op == "<=" then curve:AddPoint(0, wanted); curve:AddPoint(value + eps, 0)
  elseif op == ">" then curve:AddPoint(0, 0); curve:AddPoint(value + eps, wanted)
  elseif op == ">=" then curve:AddPoint(0, 0); curve:AddPoint(value, wanted)
  elseif op == "==" then curve:AddPoint(0, 0); curve:AddPoint(value - 0.05, wanted); curve:AddPoint(value + 0.05, 0)
  else curve:AddPoint(0, wanted); curve:AddPoint(value - 0.05, 0); curve:AddPoint(value + 0.05, wanted) end
  remainingCurves[key] = curve
  return curve
end
local function SecretRemainingTick()
  local any = false
  for region in pairs(secretRemaining) do
    any = true
    if region.secretRemainingWindow and region.RealSetAlpha then
      region:SetAlpha(region.requestedAlpha or region.animAlpha or region.alpha or 1)
    else
      secretRemaining[region] = nil
    end
  end
  if not any and secretRemainingTicker then secretRemainingTicker:Cancel(); secretRemainingTicker = nil end
end
function Private.SetRegionSecretRemaining(region, window)
  if region.secretRemainingWindow == window then return end
  region.secretRemainingWindow = window
  if window then
    secretRemaining[region] = true
    if not secretRemainingTicker and C_Timer.NewTicker then secretRemainingTicker = C_Timer.NewTicker(0.1, SecretRemainingTick) end
  else
    secretRemaining[region] = nil
  end
  if region.RealSetAlpha then region:SetAlpha(region.requestedAlpha or region.animAlpha or region.alpha or 1) end
end

function Private.SetRegionNativeShow(region, gate)
  if region.nativeShowGate == gate then return end
  region.nativeShowGate = gate
  if region.RealSetAlpha then region:SetAlpha(region.requestedAlpha or region.animAlpha or region.alpha or 1) end
end

function Private.SetRegionUnitGone(region, gone)
  gone = gone or nil
  if region.unitGone == gone then return end
  region.unitGone = gone
  if region.RealSetAlpha then region:SetAlpha(region.requestedAlpha or region.animAlpha or region.alpha or 1) end
end

local function SetRegionAlpha(self, alpha)
  if not hasanysecretvalues(self.alpha, alpha) and (self.alpha == alpha) then
    return;
  end

  self.alpha = alpha;
  self:SetAlpha(self.animAlpha or self.alpha or 1);
  self.subRegionEvents:Notify("AlphaChanged")
end

local function GetRegionAlpha(self)
  return self.animAlpha or self.alpha or 1;
end

local function SetProgressSource(self, progressSource)
  self.progressSource = progressSource
  self:UpdateProgress()
end

local function SetAdjustedMin(self, adjustedMin)
  local index = adjustedMin:find("%% *$")
  if index then
    local percent = adjustedMin:sub(1, index-1)
    self.adjustedMinRelPercent = tonumber(percent) / 100
    self.adjustedMin = nil
  else
    self.adjustedMin = tonumber(adjustedMin)
    self.adjustedMinRelPercent = nil
  end
  self:UpdateProgress()
end

local function SetAdjustedMax(self, adjustedMax)
  local index = adjustedMax:find("%% *$")
  if index then
    local percent = adjustedMax:sub(1, index-1)
    self.adjustedMaxRelPercent = tonumber(percent) / 100
  else
    self.adjustedMax = tonumber(adjustedMax)
  end
  self:UpdateProgress()
end

local function GetProgressSource(self)
  return self.progressSource
end

local function GetMinMaxProgress(self)
  return self.minProgress or 0, self.maxProgress or 0
end

local function UpdateProgressFromState(self, minMaxConfig, state, progressSource)
  -- Use the selected progress source, which can differ from the active trigger.
  self.cdmProgressState = state
  local progressType = progressSource[2]
  local property = progressSource[3]
  local totalProperty = progressSource[4]
  local modRateProperty = progressSource[5]
  local inverseProperty = progressSource[6]
  local pausedProperty = progressSource[7]
  local remainingProperty = progressSource[8]
  local useAdditionalProgress = progressSource[9]

  if state and progressType == "timer" and property == "expirationTime"
     and state.progressType == "durationObject" and WeakAuras.IsDurationObject(state.durationObject) then
    progressType = "durationObject"
  end
  if progressType ~= "durationObject" then
    self.durationObject = nil
  end
  -- A Remaining Time filter on a secret cooldown (the spell Cooldown
  -- trigger, secretRemainingWindow): the display's alpha follows the
  -- cooldown's duration object through a step curve the client evaluates,
  -- 1 inside the window and 0 outside (Private.SetRegionSecretRemaining).
  Private.SetRegionSecretRemaining(self, progressType == "durationObject" and state and state.secretRemainingWindow or nil)

  if not state then
    self.minProgress, self.maxProgress = nil, nil
    self.progressType = "timed"
    self.duration = 0
    self.expirationTime = math.huge
    self.modRate = nil
    self.inverse = false
    self.paused = true
    self.remaining = math.huge
    if self.UpdateTime then
      self:UpdateTime()
    end
    if self.SetAdditionalProgress then
      self:SetAdditionalProgress(nil)
    end
  elseif progressType == "durationObject" then
    local inverse = inverseProperty and state[inverseProperty]
    self.durationObject = state.durationObject
    self.inverse = inverse
    -- The Remaining Time window reads this duration object (above).
    if self.secretRemainingWindow and self.RealSetAlpha then self:SetAlpha(self.requestedAlpha or self.animAlpha or self.alpha or 1) end
    -- A readable cooldown shown from its duration object (see the spell
    -- cooldown trigger) also carries timed values: animations and sub elements
    -- that only know timed progress keep working from them, with the adjusted
    -- minimum and maximum applied as the timed form applies them. A restricted
    -- timer leaves them as they were, as before.
    local mirrored = false
    -- The automatic source names no timed fields; the trigger's own are used.
    local timedPaused = state[pausedProperty or "paused"]
    local timedRemaining = timedPaused and state[remainingProperty or "remaining"]
    local timedExpiration = timedPaused and (type(timedRemaining) == "number" and GetTime() + timedRemaining or nil)
      or state[property or "expirationTime"]
    local timedDuration = state[totalProperty or "duration"]
    if type(timedExpiration) == "number" and type(timedDuration) == "number"
    and not hasanysecretvalues(timedExpiration, timedDuration) then
      local timedMin
      if minMaxConfig.adjustedMin then
        timedMin = minMaxConfig.adjustedMin
      elseif minMaxConfig.adjustedMinRelPercent then
        timedMin = minMaxConfig.adjustedMinRelPercent * timedDuration
      else
        timedMin = 0
      end
      local timedMax
      if timedDuration == 0 then
        timedMax = 0
      elseif minMaxConfig.adjustedMax then
        timedMax = minMaxConfig.adjustedMax
      elseif minMaxConfig.adjustedMaxRelPercent then
        timedMax = minMaxConfig.adjustedMaxRelPercent * timedDuration
      else
        timedMax = timedDuration
      end
      self.progressType = "timed"
      self.duration = timedMax - timedMin
      self.expirationTime = timedExpiration - timedMin
      self.modRate = state[modRateProperty or "modRate"]
      self.paused = timedPaused
      self.remaining = timedRemaining
      mirrored = true
    end
    -- dont use secret values to allow using ticks
    local adjustMin, max
    if minMaxConfig.adjustedMin then
      adjustMin = minMaxConfig.adjustedMin
    elseif minMaxConfig.adjustedMinRelPercent then
      adjustMin = minMaxConfig.adjustedMinRelPercent * 1
    else
      adjustMin = 0
    end
    if minMaxConfig.adjustedMax then
      max = minMaxConfig.adjustedMax
    elseif minMaxConfig.adjustedMaxRelPercent then
      max = minMaxConfig.adjustedMaxRelPercent * 1
    else
      max = 1
    end
    self.minProgress, self.maxProgress = adjustMin, max
    -- Only icons draw a readable cooldown from its duration object (their
    -- swipe then keeps one form in and out of combat); bars, progress
    -- textures and stop motions draw the mirrored timed values as before.
    if mirrored and self.regionType ~= "icon" and self.UpdateTime then
      self:UpdateTime()
    elseif self.UpdateDuration then
      self:UpdateDuration()
    end
    if self.SetAdditionalProgress then
      if useAdditionalProgress then
        self:SetAdditionalProgress(state.additionalProgress, 0, 1, false)
      else
        self:SetAdditionalProgress(nil)
      end
    end
  elseif progressType == "number" then
    local value = state[property]
    if type(value) ~= "number" then value = 0 end
    local total = totalProperty and state[totalProperty]
    if type(total) ~= "number" then total = 0 end
    -- We don't care about inverse, modRate or paused
    local adjustMin, max
    if minMaxConfig.adjustedMin then
      adjustMin = minMaxConfig.adjustedMin
    elseif minMaxConfig.adjustedMinRelPercent and not issecretvalue(total) then
      adjustMin = minMaxConfig.adjustedMinRelPercent * total
    else
      adjustMin = 0
    end
    if minMaxConfig.adjustedMax then
      max = minMaxConfig.adjustedMax
    elseif minMaxConfig.adjustedMaxRelPercent and not issecretvalue(total) then
      max = minMaxConfig.adjustedMaxRelPercent * total
    else
      max = total
    end

    -- The output of UpdateProgress is setting various values on self
    -- and calling UpdateTime/UpdateValue. Not an ideal interface, but
    -- the animation code/sub elements needs those values in some convenient place
    self.minProgress, self.maxProgress = adjustMin, max
    self.progressType = "static"
    if hasanysecretvalues(value, total) then
      self.total = max
      self.value = value
    else
      self.total = max - adjustMin
      self.value = value - adjustMin
    end

    if self.UpdateValue then
      self:UpdateValue()
    end
    if self.SetAdditionalProgress then
      if useAdditionalProgress then
        self:SetAdditionalProgress(state.additionalProgress, adjustMin, max, false)
      else
        self:SetAdditionalProgress(nil)
      end
    end
  elseif progressType == "timer" then
    local expirationTime
    local paused = pausedProperty and state[pausedProperty]
    local inverse = inverseProperty and state[inverseProperty]
    local remaining
    if paused then
      remaining = remainingProperty and state[remainingProperty]
      expirationTime = GetTime() + (type(remaining) == "number" and remaining or 0)
    else
      expirationTime = state[property]
      if type(expirationTime) ~= "number" or issecretvalue(expirationTime) then
        expirationTime = math.huge
      end
    end

    local duration = totalProperty and state[totalProperty] or 0
    if type(duration) ~= "number" or issecretvalue(duration) then
      duration = 0
    end
    local modRate = modRateProperty and state[modRateProperty] or nil
    local adjustMin
    if minMaxConfig.adjustedMin then
      adjustMin = minMaxConfig.adjustedMin
    elseif minMaxConfig.adjustedMinRelPercent then
      adjustMin = minMaxConfig.adjustedMinRelPercent * duration
    else
      adjustMin = 0
    end

    local max
    if duration == 0 then
      max = 0
    elseif minMaxConfig.adjustedMax then
      max = minMaxConfig.adjustedMax
    elseif minMaxConfig.adjustedMaxRelPercent then
      max = minMaxConfig.adjustedMaxRelPercent * duration
    else
      max = duration
    end
    self.minProgress, self.maxProgress = adjustMin, max
    self.progressType = "timed"
    self.duration = max - adjustMin
    self.expirationTime = expirationTime - adjustMin
    self.remaining = remaining
    self.modRate = modRate
    self.inverse = inverse
    self.paused = paused
    if self.UpdateTime then
      self:UpdateTime()
    end
    if self.SetAdditionalProgress then
      if useAdditionalProgress then
        self:SetAdditionalProgress(state.additionalProgress, adjustMin, max, inverse)
      else
        self:SetAdditionalProgress(nil)
      end
    end
  elseif progressType == "elapsedTimer" then
    local startTime = state[property] or math.huge
    local duration = totalProperty and state[totalProperty] or 0
    local adjustMin
    if minMaxConfig.adjustedMin then
      adjustMin = minMaxConfig.adjustedMin
    elseif minMaxConfig.adjustedMinRelPercent then
      adjustMin = minMaxConfig.adjustedMinRelPercent * duration
    else
      adjustMin = 0
    end

    local max
    if minMaxConfig.adjustedMax then
      max = minMaxConfig.adjustedMax
    elseif minMaxConfig.adjustedMaxRelPercent then
      max = minMaxConfig.adjustedMaxRelPercent * duration
    else
      max = duration
    end

    self.minProgress, self.maxProgress = adjustMin, max
    self.progressType = "timed"
    self.duration = max - adjustMin
    self.expirationTime = startTime + adjustMin + self.duration
    self.modRate = nil
    self.inverse = true
    self.paused = false
    self.remaining = nil
    if self.UpdateTime then
      self:UpdateTime()
    end
    if self.SetAdditionalProgress then
      if useAdditionalProgress then
        self:SetAdditionalProgress(state.additionalProgress, adjustMin, max, false)
      else
        self:SetAdditionalProgress(nil)
      end
    end
  end
end

local autoTimedProgressSource = {-1, "timer", "expirationTime", "duration", "modRate", "inverse", "paused", "remaining", true}
local autoStaticProgressSource = {-1, "number", "value", "total", nil, nil, nil, nil, true}
local autoDurationObjectProgressSource = {-1, "durationObject", nil, nil, nil, "inverse", nil, nil, true}
local function UpdateProgressFromAuto(self, minMaxConfig, state)
  self.cdmProgressState = state
  if state.progressType == "timed"  then
    UpdateProgressFromState(self, minMaxConfig, state, autoTimedProgressSource)
  elseif state.progressType == "static" then
    UpdateProgressFromState(self, minMaxConfig, state, autoStaticProgressSource)
  elseif state.progressType == "durationObject" and WeakAuras.IsDurationObject(state.durationObject) then
    UpdateProgressFromState(self, minMaxConfig, state, autoDurationObjectProgressSource)
  else
    self.minProgress, self.maxProgress = nil, nil
    self.progressType = "timed"
    self.duration = 0
    self.expirationTime = math.huge
    self.modRate = nil
    self.inverse = false
    self.paused = true
    self.remaining = math.huge
    if self.UpdateTime then
      self:UpdateTime()
    end
    if self.SetAdditionalProgress then
      self:SetAdditionalProgress(nil)
    end
  end
end

local function UpdateProgressFromManual(self, minMaxConfig, state, value, total)
  self.cdmProgressState = nil
  value = type(value) == "number" and value or 0
  total = type(total) == "number" and total or 0
  local adjustMin
  if minMaxConfig.adjustedMin then
    adjustMin = minMaxConfig.adjustedMin
  elseif minMaxConfig.adjustedMinRelPercent then
    adjustMin = minMaxConfig.adjustedMinRelPercent * total
  else
    adjustMin = 0
  end
  local max
  if minMaxConfig.adjustedMax then
    max = minMaxConfig.adjustedMax
  elseif minMaxConfig.adjustedMaxRelPercent then
    max = minMaxConfig.adjustedMaxRelPercent * total
  else
    max = total
  end
  self.minProgress, self.maxProgress = adjustMin, max
  self.progressType = "static"
  self.value = value - adjustMin
  self.total = max - adjustMin
  if self.UpdateValue then
    self:UpdateValue()
  end
  if self.SetAdditionalProgress then
    self:SetAdditionalProgress(nil)
  end
end

local function UpdateProgressFrom(self, progressSource, minMaxConfig, state, states, parent)
  -- ForeverAuras.PurgeSecrets(state)

  local trigger = progressSource and progressSource[1] or -1

  if trigger == -2 then
    -- sub element'a auto uses the whatever progress the main region has
    UpdateProgressFromAuto(self, minMaxConfig, parent)
  elseif trigger == -1 then
    -- auto for regions uses the state
    UpdateProgressFromAuto(self, minMaxConfig, state)
  elseif trigger == 0 then
    UpdateProgressFromManual(self, minMaxConfig, state, progressSource[3], progressSource[4])
  else
    UpdateProgressFromState(self, minMaxConfig, states and states[trigger] or {}, progressSource)
  end
end

-- For regions
local function UpdateProgress(self)
  if (self.regionType == "icon" or self.regionType == "aurabar" or self.regionType == "progresstexture") and Private.CDMAuraProgress then Private.CDMAuraProgress.Update(self) end
  UpdateProgressFrom(self, self.progressSource, self, self.state, self.states)
  self.subRegionEvents:Notify("UpdateProgress", self.state, self.states)
end

Private.UpdateProgressFrom = UpdateProgressFrom

local function SetAnimAlpha(self, alpha)
  if alpha then
    if alpha > 1 then
      alpha = 1
    elseif alpha < 0 then
      alpha = 0
    end
  end
  if (self.animAlpha == alpha) then
    return;
  end
  self.animAlpha = alpha;
  local errorHandler = Private.GetErrorHandlerId(self.id, L["Custom Fade Animation"])
  if (WeakAuras.IsOptionsOpen()) then
    xpcall(self.SetAlpha, errorHandler, self, max(self.animAlpha or self.alpha or 1, 0.5))
  else
    xpcall(self.SetAlpha, errorHandler, self, self.animAlpha or self.alpha or 1)
  end
  self.subRegionEvents:Notify("AlphaChanged")
end

local function UpdateTick(self)
  if self.subRegionEvents:HasSubscribers("FrameTick") and self.toShow then
    Private.FrameTick:AddSubscriber("Tick", self)
  else
    Private.FrameTick:RemoveSubscriber("Tick", self)
  end
end

local function Tick(self)
  Private.StartProfileAura(self.id)
  self.values.customTextUpdated = false
  self.subRegionEvents:Notify("FrameTick")
  Private.StopProfileAura(self.id)
end

local function ForwardAnchorToSubRegion(self, subRegion, anchorType, anchorPoint, selfPoint, anchorXOffset, anchorYOffset)
  local nextdot = anchorPoint:find(".", 5, true)
  local index = tonumber(anchorPoint:sub(5, nextdot - 1))
  local subElement = index and self.subRegions[index] or nil
  if subElement then
    local key = anchorPoint:sub(nextdot + 1)
    if subElement.AnchorSubRegion then
      subElement:AnchorSubRegion(subRegion, anchorType, key, selfPoint, anchorXOffset, anchorYOffset)
    end
  end
end

local function AnchorSubRegion(self, subRegion, anchorType, anchorPoint, selfPoint, anchorXOffset, anchorYOffset)
  if anchorPoint and anchorPoint:sub(1, 4) == "sub." then
    self:ForwardAnchorToSubRegion(subRegion, anchorType, anchorPoint, selfPoint, anchorXOffset, anchorYOffset)
    return
  end
  if anchorType == "point" then
    subRegion:ClearAllPoints()
    local xOffset = anchorXOffset or 0
    local yOffset = anchorYOffset or 0
    subRegion:SetPoint(Private.point_types[selfPoint] and selfPoint or "CENTER",
                       self, Private.point_types[anchorPoint] and anchorPoint or "CENTER",
                       xOffset, yOffset)
  else
    subRegion:ClearAllPoints()
    anchorXOffset = anchorXOffset or 0
    anchorYOffset = anchorYOffset or 0
    subRegion:SetPoint("bottomleft", self, "bottomleft", -anchorXOffset, -anchorYOffset)
    subRegion:SetPoint("topright", self, "topright", anchorXOffset,  anchorYOffset)
  end
end

Private.regionPrototype.AnchorSubRegion = AnchorSubRegion

function Private.regionPrototype.create(region)
  local defaultsForRegion = Private.regionTypes[region.regionType] and Private.regionTypes[region.regionType].default;
  region.SoundPlay = SoundPlay;
  region.SoundStop = SoundStop;
  region.SoundRepeatStop = SoundRepeatStop;
  region.SendChat = SendChat;
  region.RunCode = RunCode;
  region.GlowExternal = GlowExternal;

  region.ReAnchor = UpdatePosition;
  region.SetAnchor = SetAnchor;
  region.SetOffset = SetOffset;
  region.SetXOffset = SetXOffset;
  region.SetYOffset = SetYOffset;
  region.GetXOffset = GetXOffset;
  region.GetYOffset = GetYOffset;
  region.SetOffsetRelative = SetOffsetRelative
  region.SetXOffsetRelative = SetXOffsetRelative
  region.SetYOffsetRelative = SetYOffsetRelative
  region.GetXOffsetRelative = GetXOffsetRelative
  region.GetYOffsetRelative = GetYOffsetRelative
  region.SetOffsetAnim = SetOffsetAnim;
  region.ResetPosition = ResetPosition;
  region.RealClearAllPoints = region.ClearAllPoints;
  region.ClearAllPoints = function()
    region:RealClearAllPoints();
    region:ResetPosition();
  end
  if (defaultsForRegion and defaultsForRegion.alpha) then
    region.SetRegionAlpha = SetRegionAlpha;
    region.GetRegionAlpha = GetRegionAlpha;
  end
  -- An Aura (Modern) display whose unit (target, focus, pet...) does not exist
  -- stays shown and keeps its native containers enabled, and is faded out
  -- instead (Private.SetRegionUnitGone): hiding and showing a dozen such
  -- displays on every target change made the client enable and lay out all
  -- of their containers again. The fade multiplies whatever alpha the
  -- display's settings, conditions and animations ask for.
  if not region.RealSetAlpha then
    region.RealSetAlpha, region.RealGetAlpha = region.SetAlpha, region.GetAlpha
    region.SetAlpha = function(self, alpha)
      self.requestedAlpha = alpha
      local wanted = self.unitGone and 0 or alpha
      -- A CDM Buff display whose aura is secret (Private.SetRegionNativeShow):
      -- the engine decides between the asked-for alpha and 0 from the native
      -- aura slot's visibility, a secret boolean Lua never tests.
      local gate = self.nativeShowGate
      -- A Modern Aura Group's stand-in draws this display: its frame takes
      -- the same gate (its copies mirror plain alphas, not secret ones).
      local normal = self.flowNormal
      local stand = normal and normal.stand
      local standFrame = stand and stand.active and stand.frame or nil
      -- A secret cooldown's Remaining Time window (SetRegionSecretRemaining).
      local window = self.secretRemainingWindow
      local duration = window and self.durationObject
      if duration and not duration.EvaluateRemainingDuration then duration = nil end
      if standFrame then
        -- ForeverAuras: one owner for each part. The display's own frame
        -- carries the asked-for alpha (the stand frame is its child, so the
        -- copies inherit it), and the stand frame carries only the gate, as a
        -- factor of 0 or 1. Written to both, a 50% display drew at 25% (0.5 x
        -- 0.5), and a gate applied on the boolean path was never recorded, so
        -- removing the gate left the stand frame at 0 while the display went
        -- back to its alpha.
        local applied = false
        if gate and gate.hide then
          pcall(standFrame.SetAlpha, standFrame, 0)
          applied = true
        elseif duration then
          local ok, factor = pcall(duration.EvaluateRemainingDuration, duration, RemainingCurve(window, 1))
          if ok and factor ~= nil then
            pcall(standFrame.SetAlpha, standFrame, factor)
            applied = true
          end
        end
        if not applied and gate and standFrame.SetAlphaFromBoolean then
          local ok, shown = pcall(gate.read)
          if ok and shown ~= nil then
            local present, absent = 1, 0
            if gate.mode == "missing" then present, absent = 0, 1 end
            applied = pcall(standFrame.SetAlphaFromBoolean, standFrame, shown, present, absent)
          end
        end
        if applied then
          standFrame.cdmGateApplied = true
        elseif standFrame.cdmGateApplied then
          standFrame.cdmGateApplied = nil
          pcall(standFrame.SetAlpha, standFrame, 1)
        end
        return self:RealSetAlpha(wanted)
      end
      -- A gate that hides the display outright (Aura(s) Found with a secret
      -- aura: the slot's copy of the display stands for it, CDMAuraProgress).
      if gate and gate.hide then
        return self:RealSetAlpha(0)
      end
      if duration then
        local curve = RemainingCurve(window, wanted)
        local ok, alpha = pcall(duration.EvaluateRemainingDuration, duration, curve)
        if ok and alpha ~= nil then
          return self:RealSetAlpha(alpha)
        end
      end
      if gate and self.SetAlphaFromBoolean then
        local ok, shown = pcall(gate.read)
        if ok and shown ~= nil then
          local present, absent = wanted, 0
          if gate.mode == "missing" then present, absent = 0, wanted end
          if pcall(self.SetAlphaFromBoolean, self, shown, present, absent) then return end
        end
      end
      return self:RealSetAlpha(wanted)
    end
    -- Animations read the alpha they start from: the asked-for one, not the fade.
    region.GetAlpha = function(self)
      if (self.unitGone or (self.nativeShowGate and self.nativeShowGate.hide) or self.secretRemainingWindow) and self.requestedAlpha then return self.requestedAlpha end
      return self:RealGetAlpha()
    end
  end
  if defaultsForRegion and defaultsForRegion.progressSource then
    region.SetProgressSource = SetProgressSource
    region.GetProgressSource = GetProgressSource
    region.SetAdjustedMin = SetAdjustedMin
    region.SetAdjustedMax = SetAdjustedMax
  end
  region.UpdateProgress = UpdateProgress
  region.GetMinMaxProgress = GetMinMaxProgress
  region.SetAnimAlpha = SetAnimAlpha;

  region.UpdateTick = UpdateTick
  region.Tick = Tick


  region.subRegionEvents = Private.CreateSubscribableObject()
  region.AnchorSubRegion = AnchorSubRegion
  region.ForwardAnchorToSubRegion = ForwardAnchorToSubRegion
  region.values = {} -- For SubText

  region:SetPoint("CENTER", UIParent, "CENTER")
end

function Private.regionPrototype.AddMinMaxProgressSource(hasProgressSource, region, parentData, data)
  local hasAdjustedMin = hasProgressSource and data.useAdjustededMin and data.adjustedMin
  local hasAdjustedMax = hasProgressSource and data.useAdjustededMax and data.adjustedMax

  region.progressSource = nil
  region.adjustedMin = nil
  region.adjustedMinRelPercent = nil
  region.adjustedMax = nil
  region.adjustedMaxRelPercent = nil

  if hasProgressSource then
    region.progressSource = Private.AddProgressSourceMetaData(parentData, data.progressSource)
  end

  if (hasAdjustedMin) then
    local percent = string.match(data.adjustedMin, "(%d+)%%")
    if percent then
      region.adjustedMinRelPercent = tonumber(percent) / 100
    else
      region.adjustedMin = tonumber(data.adjustedMin);
    end
  end
  if (hasAdjustedMax) then
    local percent = string.match(data.adjustedMax, "(%d+)%%")
    if percent then
      region.adjustedMaxRelPercent = tonumber(percent) / 100
    else
      region.adjustedMax = tonumber(data.adjustedMax)
    end
  end
end

function Private.regionPrototype.modify(parent, region, data)
  region.state = nil
  region.states = nil
  region.subRegionEvents:ClearSubscribers()
  region.subRegionEvents:ClearCallbacks()
  Private.FrameTick:RemoveSubscriber("Tick", region)

  local defaultsForRegion = Private.regionTypes[data.regionType] and Private.regionTypes[data.regionType].default;

  if region.SetRegionAlpha then
    region:SetRegionAlpha(data.alpha)
  end

  local hasProgressSource = defaultsForRegion and defaultsForRegion.progressSource

  Private.regionPrototype.AddMinMaxProgressSource(hasProgressSource, region, data, data)

  region:SetOffset(data.xOffset or 0, data.yOffset or 0);
  region:SetOffsetRelative(0, 0)
  region:SetOffsetAnim(0, 0);

  if data.anchorFrameType == "CUSTOM" and data.customAnchor then
    region.customAnchorFunc = WeakAuras.LoadFunction("return " .. data.customAnchor, data.id)
  else
    region.customAnchorFunc = nil
  end

  if not parent or parent.regionType ~= "dynamicgroup" then
    if
      -- Don't anchor single Auras that with custom anchoring,
      -- these will be anchored in expand
      not (
        data.anchorFrameType == "CUSTOM"
        or data.anchorFrameType == "UNITFRAME"
        or data.anchorFrameType == "NAMEPLATE"
      )
      -- Group Auras that will never be expanded, so those need
      -- to be always anchored here
      or data.regionType == "dynamicgroup"
      or data.regionType == "group"
    then
      Private.AnchorFrame(data, region, parent);
    end
  end

  region.startFormatters = Private.CreateFormatters(data.actions.start.message, function(key, default)
    local fullKey = "message_format_" .. key
    if data.actions.start[fullKey] == nil then
      data.actions.start[fullKey] = default
    end
    return data.actions.start[fullKey]
  end, true, data)

  region.finishFormatters = Private.CreateFormatters(data.actions.finish.message, function(key, default)
    local fullKey = "message_format_" .. key
    if data.actions.finish[fullKey] == nil then
      data.actions.finish[fullKey] = default
    end
    return data.actions.finish[fullKey]
  end, true, data)
end

function Private.regionPrototype.modifyFinish(parent, region, data)
  -- Sync subRegions
  if region.subRegions then
    for index, subRegion in pairs(region.subRegions) do
      Private.subRegionTypes[subRegion.type].release(subRegion)
    end

    wipe(region.subRegions)
  end

  if data.subRegions then
    region.subRegions = region.subRegions or {}
    local subRegionTypes = {}
    for index, subRegionData in pairs(data.subRegions) do
      if Private.subRegionTypes[subRegionData.type] then
        local subRegion = Private.subRegionTypes[subRegionData.type].acquire()
        subRegion.type = subRegionData.type
        subRegion.secretAuraDetached = Private.BlizzardAuraDisplay.IsDetachedElement(data, subRegionData)

        if subRegion then
          Private.subRegionTypes[subRegionData.type].modify(region, subRegion, data, subRegionData, not subRegionTypes[subRegionData.type])
          subRegionTypes[subRegionData.type] = true
        end

        tinsert(region.subRegions, subRegion)
      end
    end

    for index, subRegion in pairs(region.subRegions) do
      if subRegion.Anchor then
        subRegion:Anchor()
      end
    end

  end

  region.subRegionEvents:SetOnSubscriptionStatusChanged("FrameTick", function()
    region:UpdateTick()
  end)
  region:UpdateTick()

  Private.ApplyFrameLevel(region)
  Private.BlizzardAuraDisplay.RefreshStand(region)
  -- "Not in combat" displays hide at combat start through the client's secure driver (see above).
  Private.UpdateCombatHideDriver(region, data)
end

local frameForFrameTick = CreateFrame("Frame");
Private.frames["Frame Tick Frame"] = frameForFrameTick

Private.FrameTick = Private.CreateSubscribableObject()
local TEXT_TICK = 1 / 30
local nextTextTick = 0
function Private.ThrottledTextTick(func)
  return function(...)
    if Private.FrameTick.textDue then return func(...) end
  end
end
Private.FrameTick.OnUpdateHandler = function()
  Private.StartProfileSystem("frame tick")
  local now = GetTime()
  Private.FrameTick.textDue = now >= nextTextTick
  if Private.FrameTick.textDue then nextTextTick = now + TEXT_TICK end
  Private.FrameTick:Notify("Tick")
  Private.StopProfileSystem("frame tick")
end

Private.FrameTick:SetOnSubscriptionStatusChanged("Tick", function()
  if Private.FrameTick:HasSubscribers("Tick") then
    frameForFrameTick:SetScript("OnUpdate", Private.FrameTick.OnUpdateHandler);
  else
    frameForFrameTick:SetScript("OnUpdate", nil)
  end
end)

function Private.regionPrototype.AddSetDurationInfo(region, uid)
  if (region.UpdateValue and region.UpdateTime) then
    -- ForeverAuras no longer calls SetDurationInfo, but some people do that
    region.SetDurationInfo = function(self, duration, expirationTime, customValue, inverse)
      -- For now don't warn against SetDurationInfo
      -- Private.AuraWarnings.UpdateWarning(uid, "SetDurationInfo", "warning", L["Aura is using deprecated SetDurationInfo"])
      if customValue then
        local adjustMin = region.adjustedMin or 0;
        local max = self.adjustedMax or expirationTime
        region.progressType = "static"
        region.value = duration - adjustMin
        region.total = max - adjustMin
        region:UpdateValue()
      else
        local adjustMin = self.adjustedMin or 0;
        self.progressType = "timed"
        self.duration = (duration ~= 0 and self.adjustedMax or duration) - adjustMin
        self.expirationTime = expirationTime - adjustMin
        self.modRate = nil
        self.inverse = inverse
        self.paused = false
        self.remaining = nil
        self:UpdateTime()
      end
    end
  end
end

-- Regions whose show or hide waits for the end of combat (secure Modern Aura Group rows).
local deferredVisibility = {}
local deferredFrame
function Private.DeferProtectedVisibility(region)
  if not deferredFrame then
    deferredFrame = CreateFrame("Frame")
    deferredFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    deferredFrame:SetScript("OnEvent", function()
      -- toShow is the region's wanted state after everything that happened in combat.
      for pending in pairs(deferredVisibility) do
        deferredVisibility[pending] = nil
        if pending.toShow then pending:Show() else pending:Hide() end
      end
    end)
  end
  deferredVisibility[region] = true
end

-- ForeverAuras: a display loaded with "Not in combat" can be one the client
-- refuses to let addon code hide once combat has started: a display with a
-- secure click button parented or anchored to it, or a member of a Modern Aura
-- Group whose row holds clickable copies. Unloading then only queues the hide
-- for after combat (DeferProtectedVisibility), and the reminder stays on screen
-- through the fight. The client's own secure state driver may hide protected
-- frames in combat, so such displays get a "[combat] hide" driver. The blank
-- out-of-combat branch leaves showing and hiding to the ordinary load and
-- trigger logic, so nothing changes outside combat. In a Modern Aura Group the
-- row copy is a child of the region (SecretAuraFlow.lua), so hiding the region
-- hides the copy and its secure buttons with it. Drivers are attribute changes
-- and are not applied in combat; those wait for the end of combat.
local combatHidePending = {}
local combatHideFrame
local function ApplyCombatHideDriver(region)
  combatHidePending[region] = nil
  if region.faCombatHideWanted then
    if not region.faCombatHideDriver then
      RegisterStateDriver(region, "visibility", "[combat] hide; ")
      region.faCombatHideDriver = true
    end
  elseif region.faCombatHideDriver then
    UnregisterStateDriver(region, "visibility")
    region.faCombatHideDriver = nil
  end
end
-- Called with the display's data after modify, after a Load-tab edit
-- (WeakAuras.UpdateLoadConditions), and without data when the region is retired
-- (deleted, or a clone returned to a pool), which removes the driver.
function Private.UpdateCombatHideDriver(region, data)
  if not region then return end
  -- Only displays themselves: a group frame hiding would take every member with it.
  local wanted = data and data.regionType ~= "group" and data.regionType ~= "dynamicgroup"
    and data.load and data.load.use_combat == false or nil
  region.faCombatHideWanted = wanted
  if InCombatLockdown() then
    if not combatHideFrame then
      combatHideFrame = CreateFrame("Frame")
      combatHideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      combatHideFrame:SetScript("OnEvent", function()
        for pending in pairs(combatHidePending) do
          ApplyCombatHideDriver(pending)
        end
      end)
    end
    combatHidePending[region] = true
    return
  end
  ApplyCombatHideDriver(region)
end

-- Expand/Collapse function
function Private.regionPrototype.AddExpandFunction(data, region, cloneId, parent, parentRegionType)
  local uid = data.uid
  local id = data.id
  local inDynamicGroup = parentRegionType == "dynamicgroup";
  local inGroup = parentRegionType == "group";
  local inModernGroup = inGroup and Private.BlizzardAuraDisplay.FlowGroup(data) ~= nil

  local startMainAnimation = function()
    Private.Animate("display", uid, "main", data.animation.main, region, false, nil, true, cloneId);
  end

  function region:OptionsClosed()
    region:EnableMouse(false)
    region:SetScript("OnMouseDown", nil)
  end

  function region:ClickToPick()
    region:EnableMouse(true)
    region:SetScript("OnMouseDown", function()
      WeakAuras.PickDisplay(region.id, nil, true)
    end)
    if region.GetFrameStrata and region:GetFrameStrata() == "TOOLTIP" then
      region:SetFrameStrata("HIGH")
    end
  end

  local hideRegion;
  if(inDynamicGroup) then
    hideRegion = function()
      if region.PreHide then
        region:PreHide()
      end

      Private.RunConditions(region, uid, true)
      region.subRegionEvents:Notify("PreHide")
      if region:IsProtected() then
        if InCombatLockdown() and inModernGroup then
          -- A Modern Aura Group row is secure while it holds clickable copies: show or hide after combat.
          Private.DeferProtectedVisibility(region)
        elseif InCombatLockdown() then
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame_error", "error",
          L["Cannot change secure frame in combat lockdown. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"],
            true)
        else
          -- In a Modern Aura Group, clickable displays make the whole row secure; that is expected.
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame", not inModernGroup and "warning" or nil,
            not inModernGroup and L["Secure frame detected. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"] or nil)
          region:Hide()
        end
      else
        Private.AuraWarnings.UpdateWarning(uid, "protected_frame")
        region:Hide()
      end
      region.states = nil
      region.state = nil
      if (cloneId) then
        Private.ReleaseClone(region.id, cloneId, data.regionType);
        parent:RemoveChild(id, cloneId)
      else
        parent:DeactivateChild(id, cloneId);
      end
    end
  else
    hideRegion = function()
      if region.PreHide then
        region:PreHide()
      end
      Private.RunConditions(region, uid, true)
      region.subRegionEvents:Notify("PreHide")

      if region:IsProtected() then
        if InCombatLockdown() and inModernGroup then
          -- A Modern Aura Group row is secure while it holds clickable copies: show or hide after combat.
          Private.DeferProtectedVisibility(region)
        elseif InCombatLockdown() then
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame_error", "error",
          L["Cannot change secure frame in combat lockdown. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"],
            true)
        else
          -- In a Modern Aura Group, clickable displays make the whole row secure; that is expected.
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame", not inModernGroup and "warning" or nil,
            not inModernGroup and L["Secure frame detected. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"] or nil)
          region:Hide()
        end
      else
        Private.AuraWarnings.UpdateWarning(uid, "protected_frame")
        region:Hide()
      end

      region.states = nil
      region.state = nil
      if (cloneId) then
        Private.ReleaseClone(region.id, cloneId, data.regionType);
      end
    end
  end

  if(inDynamicGroup) then
    function region:Collapse()
      if (not region.toShow) then
        return;
      end
      region.toShow = false;

      Private.PerformActions(data, "finish", region);
      if (not Private.Animate("display", data.uid, "finish", data.animation.finish, region, false, hideRegion, nil, cloneId)) then
        hideRegion();
      end

      if (region.SoundRepeatStop) then
        region:SoundRepeatStop();
      end

      region:UpdateTick()
    end
    function region:Expand()
      if (region.toShow) then
        return;
      end
      region.toShow = true;
      if(region.PreShow) then
        region:PreShow();
      end

      region.subRegionEvents:Notify("PreShow")

      Private.ApplyFrameLevel(region)
      if region:IsProtected() then
        if InCombatLockdown() and inModernGroup then
          -- A Modern Aura Group row is secure while it holds clickable copies: show or hide after combat.
          Private.DeferProtectedVisibility(region)
        elseif InCombatLockdown() then
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame_error", "error",
            L["Cannot change secure frame in combat lockdown. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"],
            true)
        else
          -- In a Modern Aura Group, clickable displays make the whole row secure; that is expected.
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame", not inModernGroup and "warning" or nil,
            not inModernGroup and L["Secure frame detected. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"] or nil)
          region:Show()
        end
      else
        Private.AuraWarnings.UpdateWarning(uid, "protected_frame")
        region:Show()
      end

      Private.PerformActions(data, "start", region);
      if not(Private.Animate("display", data.uid, "start", data.animation.start, region, true, startMainAnimation, nil, cloneId)) then
        startMainAnimation();
      end
      parent:ActivateChild(data.id, cloneId);

      region:UpdateTick()
    end
  elseif not(data.controlledChildren) then
    function region:Collapse()
      if (not region.toShow) then
        return;
      end
      region.toShow = false;

      Private.PerformActions(data, "finish", region);
      if (not Private.Animate("display", data.uid, "finish", data.animation.finish, region, false, hideRegion, nil, cloneId)) then
        hideRegion();
      end

      if inGroup then
        parent:UpdateBorder(region);
      end

      if (region.SoundRepeatStop) then
        region:SoundRepeatStop();
      end

      region:UpdateTick()
    end
    function region:Expand()
      if data.anchorFrameType == "SELECTFRAME"
      or data.anchorFrameType == "CUSTOM"
      or data.anchorFrameType == "UNITFRAME"
      or data.anchorFrameType == "NAMEPLATE"
      then
        Private.AnchorFrame(data, region, parent);
      end

      if (region.toShow) then
        return;
      end
      region.toShow = true

      if(region.PreShow) then
        region:PreShow();
      end

      region.subRegionEvents:Notify("PreShow")
      Private.ApplyFrameLevel(region)

      if region:IsProtected() then
        if InCombatLockdown() and inModernGroup then
          -- A Modern Aura Group row is secure while it holds clickable copies: show or hide after combat.
          Private.DeferProtectedVisibility(region)
        elseif InCombatLockdown() then
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame_error", "error",
            L["Cannot change secure frame in combat lockdown. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"],
            true)
        else
          -- In a Modern Aura Group, clickable displays make the whole row secure; that is expected.
          Private.AuraWarnings.UpdateWarning(uid, "protected_frame", not inModernGroup and "warning" or nil,
            not inModernGroup and L["Secure frame detected. Find more information:\nhttps://github.com/WeakAuras/WeakAuras2/wiki/Protected-Frames"] or nil)
          region:Show()
        end
      else
        Private.AuraWarnings.UpdateWarning(uid, "protected_frame")
        region:Show()
      end

      Private.PerformActions(data, "start", region);
      if not(Private.Animate("display", data.uid, "start", data.animation.start, region, true, startMainAnimation, nil, cloneId)) then
        startMainAnimation();
      end

      if inGroup then
        parent:UpdateBorder(region);
      end

      region:UpdateTick()
    end
  end
  -- Stubs that allow for polymorphism
  if not region.Collapse then
    function region:Collapse() end
  end
  if not region.Expand then
    function region:Expand() end
  end
end

-- Icons are set again on every state update (region:Update -> UpdateIcon), and
-- setting a texture the client already shows still costs an atlas lookup and a
-- texture resolve for each of them. The last public path set here is kept on
-- the texture and skipped while the texture still shows what that set produced
-- (checked through GetTexture/GetAtlas, so a change made elsewhere is noticed).
-- Secret paths and wrap modes are never cached.
local function ShowsTexture(texture, path)
  if texture.faSetPath ~= path then return false end
  local current = texture.faSetAtlas and texture:GetAtlas() or texture:GetTexture()
  return not issecretvalue(current) and current ~= nil and current == texture.faSetResult
end

local function RememberTexture(texture, path, atlas)
  local current = atlas and texture:GetAtlas() or texture:GetTexture()
  if issecretvalue(current) or current == nil then
    texture.faSetPath, texture.faSetResult, texture.faSetAtlas = nil, nil, nil
  else
    texture.faSetPath, texture.faSetResult, texture.faSetAtlas = path, current, atlas or nil
  end
end

function Private.SetTextureOrAtlas(texture, path, wrapModeH, wrapModeV)
  if issecretvalue(path) then
    texture.faSetPath = nil
    if type(path) == "number" then
      return texture:SetTexture(path, wrapModeH, wrapModeV);
    else
      texture:SetTexture("");
      return false
    end
  end
  local cacheable = wrapModeH == nil and wrapModeV == nil
  if cacheable and ShowsTexture(texture, path) then return true end
  texture.faSetPath = nil
  texture.IsAtlas = type(path) == "string" and GetAtlasInfo(path) ~= nil
  local result
  if texture.IsAtlas then
    result = texture:SetAtlas(path);
  else
    result = texture:SetTexture(path, wrapModeH, wrapModeV);
  end
  Private.HitchCount("SetTexture")
  if cacheable then RememberTexture(texture, path, texture.IsAtlas) end
  return result
end

do
  local function move_condition_subregions(data, offset, afterPos)
    if data.conditions then
      for conditionIndex, condition in ipairs(data.conditions) do
        if type(condition.changes) == "table" then
          for changeIndex, change in ipairs(condition.changes) do
            if change.property then
              local subRegionIndex, property = change.property:match("^sub%.(%d+)%.(.*)")
              subRegionIndex = tonumber(subRegionIndex)
              if subRegionIndex and property then
                if (subRegionIndex >= afterPos) then
                  change.property = "sub." .. subRegionIndex + offset .. "." .. property
                end
              end
            end
          end
        end
      end
    end
  end

  function Private.EnforceSubregionExists(data, subregionType)
    data.subRegions = data.subRegions or {}
    -- search and save indexes of matching subregions
    local indexes = {}
    for index, subRegionData in ipairs(data.subRegions) do
      if subRegionData.type == subregionType then
        table.insert(indexes, index)
      end
    end
    -- add if missing
    if #indexes == 0 then
      tinsert(data.subRegions, 1, {
        ["type"] = subregionType
      })
      move_condition_subregions(data, 1, 1)
    -- delete duplicate
    elseif #indexes > 1 then
      for i = #indexes, 2, -1 do
        table.remove(data.subRegions, indexes[i])
        move_condition_subregions(data, -1, indexes[i])
      end
    end
  end
end
