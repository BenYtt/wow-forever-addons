-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Native widgets consume restricted progress without exposing it to Lua geometry.
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("ProgressTextureNative")
local Native = {}
Private.ProgressTextureNative = Native
local white = "Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite"

local function Warning(region, message)
  if region.nativeProgressUID and Private.AuraWarnings then
    Private.AuraWarnings.UpdateWarning(region.nativeProgressUID, "native_progress_texture", message and "warning" or nil, message)
  end
end

function Native.IsCircular(orientation)
  return orientation == "CLOCKWISE" or orientation == "ANTICLOCKWISE"
end

function Native.Create(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetAllPoints(parent)
  local texture = bar:CreateTexture(nil, "ARTWORK")
  local mask = bar:CreateMaskTexture()
  mask:SetTexture(white, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  bar:SetStatusBarTexture(white)
  local result = {
    bar = bar,
    texture = texture,
    mask = mask,
    coord = Private.TextureCoords.create(texture),
    linearTexture = bar:GetStatusBarTexture(),
  }
  bar:Hide()
  return result
end

function Native.SupportsRadial(native)
  return Enum.StatusBarRenderMode and native.bar.SetRenderMode and native.texture.SetRadialProgressBarPercent
end

-- Keep texture transforms public; only the native bar receives progress values.
function Native.Style(native, settings, inverse)
  local bar, texture = native.bar, native.texture
  local circular = Native.IsCircular(settings.orientation)
  if circular and not Native.SupportsRadial(native) then bar:Hide(); return false end
  native.circular = circular
  texture:RemoveMaskTexture(native.mask)
  texture:ClearAllPoints()
  texture:SetAllPoints(bar)
  Private.SetTextureOrAtlas(texture, settings.currentTexture, settings.textureWrapMode, settings.textureWrapMode)
  texture:SetBlendMode(settings.blendMode or "BLEND")
  texture:SetDesaturated(settings.desaturateForeground == true)
  -- ForeverAuras: the client's radial bar always fills from its own zero at
  -- the bottom of the texture (measured in game; the start and end offsets
  -- only cut an arc out of the circle). The display fills from its Start
  -- Angle (Clockwise) or End Angle (Anticlockwise), the top by default. So
  -- the texture itself is turned until the client's zero sits on that angle
  -- (the radial mask turns with it), and the texture coordinates are turned
  -- back by the same amount, so the picture stays upright. The default
  -- (zero at the top) is a half turn, which loses nothing of the picture;
  -- other start angles crop the corners as the display's own Rotation does.
  local anchor = 0
  if circular then
    anchor = 180 + ((settings.orientation == "ANTICLOCKWISE" and settings.endAngle or settings.startAngle) or 0)
  end
  texture:SetRotation(math.rad((settings.auraRotation or 0) + anchor))
  native.coord:SetFull()
  native.coord:Transform(settings.crop_x or 1, settings.crop_y or 1, (settings.effectiveTexRotation or settings.texRotation or 0) - anchor,
    not settings.mirror ~= not settings.mirror_h, settings.mirror_v, circular and 0 or settings.user_x, circular and 0 or settings.user_y)
  native.coord:Apply()
  texture:SetVertexColor(settings.color_anim_r or settings.color_r or 1, settings.color_anim_g or settings.color_g or 1,
    settings.color_anim_b or settings.color_b or 1, settings.color_anim_a or settings.color_a or 1)
  if circular then
    bar:SetRenderMode(Enum.StatusBarRenderMode.Radial)
    bar:SetStatusBarTexture(texture)
    bar:SetReverseFill(false)
    bar:SetStatusBarColor(settings.color_anim_r or settings.color_r or 1, settings.color_anim_g or settings.color_g or 1,
      settings.color_anim_b or settings.color_b or 1, settings.color_anim_a or settings.color_a or 1)
    native.linearTexture:Hide()
    -- With the client's zero turned onto the fill's start (above), the arc
    -- runs from zero for the display's span, and the rest of the circle is
    -- cut out. The fill runs from zero clockwise in the client's forward
    -- mode and anticlockwise reversed (seen in game: the forward fill ran
    -- the wrong way for Clockwise when it was taken for the reversed one).
    -- A whole circle leaves nothing cut out (equal offsets).
    local startAngle, endAngle = settings.startAngle or 0, settings.endAngle or 360
    local span = (endAngle - startAngle) % 360
    if span == 0 then span = 360 end
    local startOffset, endOffset = span / 360, 1
    if span >= 360 then startOffset, endOffset = 0, 0 end
    if not pcall(texture.SetRadialProgressBarStartOffset, texture, startOffset) then texture:SetRadialProgressBarStartOffset(0) end
    if not pcall(texture.SetRadialProgressBarEndOffset, texture, endOffset) then texture:SetRadialProgressBarEndOffset(0.9999) end
    -- Measured in game: with an arc cut out (unequal offsets) the client's
    -- bar sweeps the opposite way from the whole-circle case, so the reverse
    -- flag is inverted for a partial arc to keep Clockwise clockwise.
    local anticlockwise = settings.orientation == "ANTICLOCKWISE"
    if span < 360 then anticlockwise = not anticlockwise end
    texture:SetRadialProgressBarReverse(anticlockwise)
    texture:SetRadialProgressBarFeather(0)
  else
    if bar.SetRenderMode and Enum.StatusBarRenderMode then bar:SetRenderMode(Enum.StatusBarRenderMode.Linear) end
    if texture.ClearRadialProgressBar then texture:ClearRadialProgressBar() end
    bar:SetStatusBarTexture(native.linearTexture)
    bar:SetStatusBarColor(1, 1, 1, 0)
    local vertical = settings.orientation == "VERTICAL" or settings.orientation == "VERTICAL_INVERSE"
    local reverse = settings.orientation == "HORIZONTAL_INVERSE" or settings.orientation == "VERTICAL_INVERSE"
    bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    bar:SetReverseFill(not reverse ~= not inverse)
    local mask, fill = native.mask, native.linearTexture
    mask:ClearAllPoints()
    if not inverse then
      mask:SetPoint("TOPLEFT", fill, "TOPLEFT", -0.01, 0.01)
      mask:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    elseif vertical then
      mask:SetPoint("TOPLEFT", reverse and bar or fill, reverse and "TOPLEFT" or "BOTTOMLEFT", -0.01, 0.01)
      mask:SetPoint("BOTTOMRIGHT", reverse and fill or bar, reverse and "TOPRIGHT" or "BOTTOMRIGHT")
    else
      mask:SetPoint("TOPLEFT", reverse and fill or bar, reverse and "TOPRIGHT" or "TOPLEFT", -0.01, 0.01)
      mask:SetPoint("BOTTOMRIGHT", reverse and bar or fill, reverse and "BOTTOMRIGHT" or "BOTTOMLEFT")
    end
    if settings.compress then
      texture:ClearAllPoints()
      texture:SetAllPoints(mask)
    else
      texture:AddMaskTexture(mask)
    end
  end
  texture:Show()
  return true
end

local function HideForeground(region)
  region.foreground:Hide()
  region.foregroundSpinner:Hide()
  for _, texture in ipairs(region.extraTextures) do texture:Hide() end
  for _, spinner in ipairs(region.extraSpinners) do spinner:Hide() end
end

function Native.Stop(region)
  if not region.nativeProgressActive then return end
  region.nativeProgressActive = nil
  region.nativeProgressKind = nil
  region.nativeProgress.bar:Hide()
  Warning(region)
  if region.circular then region.foregroundSpinner:Show() else region.foreground:Show() end
end

local function Start(region, kind)
  region.nativeProgress = region.nativeProgress or Native.Create(region)
  if not region.nativeProgressActive or region.nativeProgressKind ~= kind then
    region.nativeProgressDirty = true
    region.smoothProgress:ResetSmoothedValue()
  end
  region.nativeProgressActive = true
  region.nativeProgressKind = kind
  if region.FrameTick then
    region.FrameTick = nil
    region.subRegionEvents:RemoveSubscriber("FrameTick", region)
  end
  HideForeground(region)
  return region.nativeProgress
end

local function StyleRegion(region, native, inverse)
  if not region.nativeProgressDirty then return native.available end
  region.nativeProgressDirty = nil
  native.available = Native.Style(native, region, inverse)
  Warning(region, not native.available and "This client does not support circular Progress Textures with restricted values." or nil)
  return native.available
end

-- Health and Power already provide missing values. Use those for inverse rings,
-- rather than subtracting restricted values. Custom ranges cannot use this identity.
local function InverseValue(region)
  local state = region.cdmProgressState or region.state
  local source = region.progressSource
  local property = source and source[1] > 0 and source[3] or "value"
  if not state or region.adjustedMin or region.adjustedMax or region.adjustedMinRelPercent or region.adjustedMaxRelPercent then return end
  if type(state.health) ~= "number" and type(state.power) ~= "number" then return end
  if property == "value" or property == "health" or property == "power" then return state.deficit end
  if property == "deficit" then return state.value end
end

function Native.UpdateValue(region)
  local native = Start(region, "value")
  local inverse = region.inverseDirection == true
  if not StyleRegion(region, native, inverse and not region.circular) then return end
  local value = region.value
  if inverse and region.circular then
    value = InverseValue(region)
    -- Leave unsupported inverse custom sources empty, never display a stale value.
    if type(value) ~= "number" then
      native.bar:Hide()
      Warning(region, "Inverse circular progress needs Health or Power with the full range when values are restricted.")
      return
    end
  end
  native.bar:SetMinMaxValues(region.minProgress or 0, region.maxProgress or region.total)
  native.bar:SetValue(value, region.useSmoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate)
  Warning(region)
  native.bar:Show()
end

function Native.UpdateDuration(region)
  local native = Start(region, "duration")
  if not StyleRegion(region, native, false) then return end
  if not WeakAuras.IsDurationObject(region.durationObject) then native.bar:Hide(); return end
  local inverse = not region.inverse ~= not region.inverseDirection
  native.bar:SetTimerDuration(region.durationObject, Enum.StatusBarInterpolation.Immediate,
    inverse and Enum.StatusBarTimerDirection.ElapsedTime or Enum.StatusBarTimerDirection.RemainingTime)
  native.bar:Show()
end

function Native.Refresh(region)
  if not region.nativeProgressActive then return end
  region.nativeProgressDirty = true
  if region.nativeProgressKind == "duration" then Native.UpdateDuration(region) else Native.UpdateValue(region) end
end

-- AuraContainer owns the bound bar after styling; live updates stay in Blizzard.
function Native.StyleAura(native, data, parent)
  if native.progressBackground then native.progressBackground:Hide() end
  native.progressTexture = native.progressTexture or Native.Create(parent)
  local progress = native.progressTexture
  local settings = {
    orientation = data.orientation,
    currentTexture = data.foregroundTexture,
    textureWrapMode = data.textureWrapMode,
    blendMode = data.blendMode,
    desaturateForeground = data.desaturateForeground,
    auraRotation = data.auraRotation,
    crop_x = 1 + (data.crop_x or 0),
    crop_y = 1 + (data.crop_y or 0),
    texRotation = data.rotation,
    mirror = data.mirror,
    user_x = -(data.user_x or 0),
    user_y = data.user_y or 0,
    compress = data.compress,
    startAngle = data.startAngle,
    endAngle = data.endAngle,
    color_r = data.foregroundColor[1],
    color_g = data.foregroundColor[2],
    color_b = data.foregroundColor[3],
    color_a = data.foregroundColor[4],
  }
  if not Native.Style(progress, settings, false) then return end
  native.progressBackgrounds = native.progressBackgrounds or {}
  local circular = Native.IsCircular(data.orientation)
  local key = circular and "circular" or "linear"
  local background = native.progressBackgrounds[key]
  local backgroundBase = circular and Private.CircularProgressTextureBase or Private.LinearProgressTextureBase
  if not background then
    background = backgroundBase.create(parent, "BACKGROUND", 0)
    native.progressBackgrounds[key] = background
  end
  native.progressBackground = background
  -- Shown first: a hidden base texture skips its coordinate update, so the
  -- crop, mirror and rotation set below were never applied to the background.
  background:Show()
  backgroundBase.modify(background, {
    crop_x = settings.crop_x,
    crop_y = settings.crop_y,
    mirror = data.mirror,
    texRotation = data.rotation or 0,
    texture = data.sameTexture and data.foregroundTexture or data.backgroundTexture,
    blendMode = data.blendMode,
    desaturated = data.desaturateBackground,
    auraRotation = math.rad(data.auraRotation or 0),
    width = data.width,
    height = data.height,
    offset = data.backgroundOffset or 0,
    user_x = settings.user_x,
    user_y = settings.user_y,
    textureWrapMode = data.textureWrapMode,
  })
  local startAngle = (data.startAngle or 0) % 360
  local endAngle = (data.endAngle or 360) % 360
  if endAngle <= startAngle then endAngle = endAngle + 360 end
  if circular then
    background:SetProgress(startAngle, endAngle)
  else
    background:SetOrientation(data.orientation)
    background:SetValue(0, 1)
  end
  background:SetColor(unpack(data.backgroundColor))
  native.bar = progress.bar
  -- ForeverAuras: "Static (always full)" (Display tab) leaves the bar unbound
  -- and full, so the shape shows whole for as long as the aura is up; the
  -- default binds it to Blizzard's timer.
  if data.blizzardAuraDisplay and data.blizzardAuraDisplay.staticProgress then
    if native.button.ClearDurationBar then native.button:ClearDurationBar() end
    progress.bar:SetMinMaxValues(0, 1)
    progress.bar:SetValue(1)
  else
    native.button:SetDurationBar(progress.bar, {direction = data.inverse and Enum.StatusBarTimerDirection.ElapsedTime or Enum.StatusBarTimerDirection.RemainingTime})
  end
  progress.bar:Show()
end
