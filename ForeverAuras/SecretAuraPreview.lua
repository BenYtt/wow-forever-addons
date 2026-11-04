-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Editor-only sample frames reuse native appearance styling without binding live auras.
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraPreview")
local Display = Private.BlizzardAuraDisplay

-- Builds a plain frame with the native button's binding methods. Previews add a
-- timer on top; Show On: Aura Missing reuses it unanimated for its Missing look,
-- which must be created in place inside its clip frame (parent).
function Display.CreateSampleNative(parent)
  local button = CreateFrame("Frame", nil, parent)
  button:EnableMouse(false)
  -- Whole pixels for the icon's box as well as its place (see the start
  -- frames in SecretAuraFlow.lua): a scaled group makes its size fractional.
  if button.SetRoundLayoutToNearestPixel then button:SetRoundLayoutToNearestPixel(true) end
  button.bindings = {}
  -- These adapters belong only to ordinary preview frames, never AuraContainer children.
  -- Appearance code can therefore bind the same icon, timer, name and stack widgets.
  for _, kind in ipairs({"Icon", "DurationText", "ApplicationCount", "SpellName", "DurationBar", "DurationCooldown"}) do
    button["Clear" .. kind] = function(self) self.bindings[kind] = {} end
    button["Set" .. kind] = function(self, widget, options)
      self.bindings[kind] = self.bindings[kind] or {}
      self.bindings[kind][#self.bindings[kind] + 1] = {widget = widget, options = options}
    end
  end
  -- ForeverAuras: the animations a sample plays are remembered, so hiding
  -- the sample stops them (HideSample). An animation group keeps running on
  -- a hidden frame, and the glows of a big pack's previews (hundreds of
  -- looping groups) kept costing the client every frame after the editor
  -- was closed (issue #136).
  button.faAnimations = {}
  -- Hidden with its parent (a collapsed display, the editor closing) the
  -- sample gets no HideSample call: its animations stop from OnHide too, and
  -- play again when it is shown.
  button:SetScript("OnHide", function(self)
    for animation in pairs(self.faAnimations) do animation:Stop() end
  end)
  button:SetScript("OnShow", function(self)
    for animation in pairs(self.faAnimations) do animation:Play() end
  end)
  function button:AddAuraShownAnimation(animation) self.faAnimations[animation] = true; animation:Play() end
  function button:RemoveAuraShownAnimation(animation) self.faAnimations[animation] = nil; animation:Stop() end
  -- Samples play a Start animation once, as a newly assigned aura would.
  function button:AddAuraAssignedAnimation(animation) self.faAnimations[animation] = true; animation:Play() end
  function button:RemoveAuraAssignedAnimation(animation) self.faAnimations[animation] = nil; animation:Stop() end
  -- Preview the same Blizzard assets as the native bindings, using a public sample type.
  function button:AddDispelTypeTexture(texture, options)
    if options.style == Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset then
      -- Match live solid-edge tinting without replacing the rectangular artwork.
      AuraUtil.SetAuraBorderColor(texture, "Magic")
      texture:Show()
      return
    elseif options.style == Enum.CustomAuraButtonDispelTypeTextureStyle.Border then
      AuraUtil.SetAuraBorderAtlas(texture, "Magic", false)
    else
      AuraUtil.SetAuraDispelTypeIcon(texture, "Magic")
    end
    texture:SetVertexColor(1, 1, 1, 1)
    texture:Show()
  end
  local native = {button = button, preview = true}
  for _, area in ipairs({"inner", "outer"}) do
    native[area] = CreateFrame("Frame", nil, button)
    native[area]:SetPoint("CENTER", button, "CENTER")
  end
  native.border = button:CreateTexture(nil, "BACKGROUND")
  native.border:SetAllPoints(button)
  local base = CreateFrame("Frame", nil, button)
  base:SetAllPoints(button)
  native.elementFrames = {sharedBase = base}
  native.icon = base:CreateTexture(nil, "ARTWORK")
  -- Placed like the icons of other displays (not rounded to whole pixels), so rows line up.
  native.icon:SetSnapToPixelGrid(false)
  native.icon:SetTexelSnappingBias(0)
  native.cooldown = CreateFrame("Cooldown", nil, base, "CooldownFrameTemplate")
  native.cooldown:SetAllPoints(native.icon)
  native.cooldown:SetDrawBling(false)
  native.overlay = CreateFrame("Frame", nil, button)
  native.overlay:SetAllPoints(button)
  return native
end

-- Fills recorded bindings with static public values. timed = false leaves the
-- countdown, stack and swipe empty, as for an aura that is not present.
function Display.FillSampleBindings(button, iconID, name, data, timed)
  for kind, entries in pairs(button.bindings) do
    for _, entry in ipairs(entries) do
      local widget = entry.widget
      if kind == "Icon" then widget:SetTexture(iconID)
      elseif kind == "SpellName" then widget:SetText(name)
      elseif kind == "ApplicationCount" then widget:SetText(timed and "3" or "")
      elseif kind == "DurationText" then widget:SetText(timed and (widget.faPreviewFormat and widget.faPreviewFormat(6) or "6") or "")
      elseif kind == "DurationBar" then
        widget:SetMinMaxValues(0, 6)
        widget:SetValue(timed and (data.inverse and 0 or 6) or 0)
      elseif kind == "DurationCooldown" then
        if timed then
          widget:SetCooldown(GetTime(), 6)
          widget:Show()
        else
          widget:Clear()
          widget:Hide()
        end
      end
    end
  end
end

-- Samples whose hide waits for combat to end (HideSample below).
local protectedHides = {}
local function CreateSample(region)
  local native = Display.CreateSampleNative(region)
  local button = native.button
  -- Loop sample progress just as the framework renews expired OPTIONS timers.
  -- Only shown samples receive OnUpdate; keep text and bars in step with the swipe.
  button:SetScript("OnUpdate", function(self, elapsed)
    if not WeakAuras.IsOptionsOpen() then
      -- ForeverAuras: a sample whose hide had to wait for combat (HideSample,
      -- protectedHides) stays shown at alpha 0 until combat ends; asking
      -- again every frame re-ran the whole preview teardown for the fight.
      if protectedHides[self] then return end
      Display.HidePreview(region)
      if Display.FlushInstanceQueue then Display.FlushInstanceQueue(region) end
      return
    end
    -- A Missing sample stands for an absent aura and has no countdown.
    if self.staticSample then return end
    local now = GetTime()
    if not self.expires or self.expires <= now then
      self.expires = now + 6
      for _, entry in ipairs(self.bindings.DurationCooldown or {}) do entry.widget:SetCooldown(now, 6) end
    end
    local remaining = math.max(0, self.expires - now)
    -- ForeverAuras: bars (a radial progress texture's sweep among them) are
    -- moved every frame, as the client moves a live one; at twenty steps a
    -- second the preview's sweep visibly juddered. Texts and highlights
    -- keep the twenty-a-second pace below.
    for _, entry in ipairs(self.bindings.DurationBar or {}) do
      entry.widget:SetValue(self.inverse and 6 - remaining or remaining)
    end
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.05 then return end
    self.elapsed = 0
    -- Highlights follow the same six-second sample cycle as the countdown.
    if native.conditionData then Display.UpdateConditionPreview(native, native.conditionData, remaining) end
    -- Each countdown in the element's own Time Format (faPreviewFormat,
    -- SecretAuraAppearance BindText); the plain rounding otherwise.
    for _, entry in ipairs(self.bindings.DurationText or {}) do
      local format = entry.widget.faPreviewFormat
      entry.widget:SetText(format and format(remaining) or (remaining < 3 and string.format("%.1f", remaining) or tostring(math.ceil(remaining))))
    end
  end)
  return native
end

-- A sample inside a region whose anchor is a protected frame (a display
-- parented to a secure button, say) is protected itself, and hiding it during
-- combat is blocked (ADDON_ACTION_BLOCKED: a display unloading on death). Such
-- a sample goes invisible at once and hides when combat ends.
local protectedHideFrame
local function HideSample(button)
  -- Animations are not protected: they stop even when the hide must wait.
  for animation in pairs(button.faAnimations or {}) do animation:Stop() end
  if InCombatLockdown() and button:IsProtected() then
    button:SetAlpha(0)
    protectedHides[button] = true
    if not protectedHideFrame then
      protectedHideFrame = CreateFrame("Frame")
      protectedHideFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
      protectedHideFrame:SetScript("OnEvent", function()
        for pending in pairs(protectedHides) do
          pending:Hide()
          pending:SetAlpha(1)
        end
        wipe(protectedHides)
      end)
    end
    return
  end
  protectedHides[button] = nil
  button:Hide()
end

function Display.HidePreview(region)
  region.secretAuraSamplesActive = false
  for _, sample in ipairs(region.secretAuraSamples or {}) do HideSample(sample.button) end
end

-- ForeverAuras: one sample at its place in the display's own preview (not a
-- group's row or grid): the index-th of count, on the display's box. Shared
-- with the grid preview, which puts a member it leaves out back here
-- (ArrangeGridPreview, SecretAuraGrid.lua).
function Display.PlaceOwnSample(region, data, button, index, count)
  local settings = data.blizzardAuraDisplay
  local width, height = Display.Dimensions(data)
  local growth, spacing = Display.Growth(data), settings.spacing or 6
  local vertical = growth == "UP" or growth == "DOWN" or growth == "CENTER_VERTICAL"
  local centered = growth == "CENTER_HORIZONTAL" or growth == "CENTER_VERTICAL"
  local anchor = growth == "LEFT" and "TOPRIGHT" or growth == "UP" and "BOTTOMLEFT" or "TOPLEFT"
  button:ClearAllPoints()
  local perRow = Display.IconsPerRow(data)
  if perRow then
    local corner, point, horizontal, verticalDirection = Display.WrapLayout(growth, settings.rowGrowth)
    local column, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
    local hSign, vSign = horizontal == "LEFT" and -1 or 1, verticalDirection == "UP" and 1 or -1
    local line = math.min(count, perRow)
    local x, y = 0, 0
    if growth == "CENTER_HORIZONTAL" then x = -(line * (width + spacing) - spacing) / 2
    elseif growth == "CENTER_VERTICAL" then y = (line * (height + spacing) - spacing) / 2 end
    if vertical then
      x, y = x + hSign * row * (width + spacing), y + vSign * column * (height + spacing)
    else
      x, y = x + hSign * column * (width + spacing), y + vSign * row * (height + spacing)
    end
    button:SetPoint(corner, region, point, x, y)
  else
    local offset = (index - 1 - (centered and (count - 1) / 2 or 0)) * ((vertical and height or width) + spacing)
    local x = not vertical and (growth == "LEFT" and -offset or offset) or 0
    local y = vertical and (growth == "UP" and offset or -offset) or 0
    button:SetPoint(centered and "CENTER" or anchor, region, centered and "CENTER" or anchor, x, y)
  end
end

function Display.ShowPreview(region, data, StyleSample)
  local ids = Display.GetSpellIDs(Display.GetTrigger(data), false)
  if #ids == 0 then ids[1] = false end
  -- The single-aura settings preview one aura in the region's own rectangle.
  local count = math.min(#ids, Display.MaxAuras(data))
  local missingLook = Display.PreviewShowsMissing(data)
  region.secretAuraSamples = region.secretAuraSamples or {}
  -- In a Modern Aura Group on unit frames the editor box follows its first
  -- sample; put it back first, as the samples are anchored to the box below
  -- (ArrangeFlowPreview moves it again afterwards).
  Display.RestorePreviewRegion(region)
  Display.HidePreview(region)
  region.secretAuraSamplesActive = true
  -- In a Modern Aura Group grouped by unit frame, one row per unit that has a
  -- frame, like a Dynamic Group's clones (the group lines them up).
  local previewUnits = Display.FlowPreviewUnits and Display.FlowPreviewUnits(data) or {false}
  for slot = 1, count * #previewUnits do
    local index = (slot - 1) % count + 1
    local sample = region.secretAuraSamples[slot] or CreateSample(region)
    region.secretAuraSamples[slot] = sample
    sample.previewUnit = previewUnits[math.floor((slot - 1) / count) + 1]
    local button = sample.button
    button.expires, button.inverse = GetTime() + 6, data.inverse == true
    -- Only the first sample animates its Glow elements (SecretAuraGlow.lua);
    -- a display with many spells had a full set of glow animations per sample.
    button.faStaticGlow = slot > 1
    local info = ids[index] and C_Spell.GetSpellInfo(ids[index])
    -- Use the configured entry once, not every expanded rank of that entry.
    sample.name, sample.iconID = info and info.name or "Aura", info and info.iconID or 134400
    StyleSample(sample, data)
    Display.PlaceOwnSample(region, data, button, index, count)
    -- Like ordinary OPTIONS states, each sample has a six-second duration.
    -- Show On: Aura Missing previews the static look drawn while the aura is absent.
    button.staticSample = missingLook
    Display.FillSampleBindings(button, missingLook and Display.SingleIcon(data) or sample.iconID, sample.name, data, not missingLook)
    if missingLook then Display.StyleMissingIcon(sample, data) end
    -- Shown again after a deferred combat hide (HideSample).
    protectedHides[button] = nil
    button:SetAlpha(1)
    button:Show()
  end
end
