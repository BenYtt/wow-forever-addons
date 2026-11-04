-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Shared Display settings rendered by Blizzard's native aura widgets.
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript, C_Timer = Private.TimedAPI("SecretAuraAppearance")
local Display = Private.BlizzardAuraDisplay
local Media = LibStub("LibSharedMedia-3.0")

-- Match ordinary icon zoom/offset/aspect calculations using configured sizes.
-- No geometry or aura data is read from protected children. The same helper is
-- used by preview, native initialization and supported zoom condition changes.
-- Returns left, right, top, bottom so inline icon markup can reuse the crop.
function Display.IconTexCoords(data, zoom)
  zoom = zoom or data.zoom or 0
  if data.regionType ~= "icon" then
    -- Aura bar icons retain their existing crop behavior.
    local crop = math.min(0.45, math.max(0, zoom / 2))
    return crop, 1 - crop, crop, 1 - crop
  end
  local width, height = Display.Dimensions(data)
  local aspect = data.keepAspectRatio and width > 0 and height > 0 and width / height or 1
  local span = 1 - 0.5 * zoom
  local xSpan = span * (aspect < 1 and aspect or 1)
  local ySpan = span * (aspect > 1 and 1 / aspect or 1)
  local x, y = data.texXOffset or 0, data.texYOffset or 0
  return 0.5 - xSpan / 2 - x, 0.5 + xSpan / 2 - x, 0.5 - ySpan / 2 + y, 0.5 + ySpan / 2 + y
end

function Display.StyleIconTexCoords(native, data, zoom)
  local skin = data.regionType == "icon" and native.masqueCoords
  if not skin then
    native.icon:SetTexCoord(Display.IconTexCoords(data, zoom))
    return
  end
  -- A Masque skin sets its own crop; zoom, aspect and offsets apply on top of
  -- it, as on ordinary Icons.
  local left, right, top, bottom = Display.IconTexCoords(data, zoom)
  local xSpan, ySpan, xMid, yMid = right - left, bottom - top, (left + right) / 2, (top + bottom) / 2
  native.icon:SetTexCoord(
    (skin[1] - 0.5) * xSpan + xMid, (skin[2] - 0.5) * ySpan + yMid,
    (skin[3] - 0.5) * xSpan + xMid, (skin[4] - 0.5) * ySpan + yMid,
    (skin[5] - 0.5) * xSpan + xMid, (skin[6] - 0.5) * ySpan + yMid,
    (skin[7] - 0.5) * xSpan + xMid, (skin[8] - 0.5) * ySpan + yMid)
end

---------------------------------------------------------------------------- masque
-- Masque skins an Icon's shared base frame, which holds the icon and swipe like
-- a button does. It lives inside the Total Duration clip, so the skin's border
-- follows the gate. Buttons join the same Masque group as the display's own
-- Icon region; the skin's swipe colour replaces Swipe Color while it is on.
local MSQ = LibStub("Masque", true)
local masqueMembers = setmetatable({}, {__mode = "k"})

-- Re-reads the skin's crop and applies the display's own on top.
local function ApplyMasqueCrop(native, group)
  local base = native.elementFrames.sharedBase
  if group.db and not group.db.Disabled then
    native.masqueCoords = native.masqueCoords or {}
    local c = native.masqueCoords
    c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8] = native.icon:GetTexCoord()
    -- A crop that cannot be read is not combined with the display's own.
    for index = 1, 8 do
      if issecretvalue(c[index]) then native.masqueCoords = nil; break end
    end
  else
    -- A disabled group leaves the icon as the display draws it.
    native.masqueCoords = nil
    native.icon:ClearAllPoints(); native.icon:SetAllPoints(base)
  end
  Display.StyleIconTexCoords(native, native.masqueData)
end

-- Masque changes (skin, enable, disable) re-apply the crop once it has reskinned.
local function MasqueChanged(group)
  C_Timer.After(0, function()
    for native in pairs(masqueMembers[group] or {}) do
      -- Like the restyle, a failure leaves the icon as it is.
      if native.masqueGroup == group then pcall(ApplyMasqueCrop, native, group) end
    end
  end)
end

local function ReleaseMasque(native)
  local group = native.masqueGroup
  if not group then return end
  group:RemoveButton(native.elementFrames.sharedBase)
  if masqueMembers[group] then masqueMembers[group][native] = nil end
  native.masqueGroup, native.masqueCoords, native.masqueData = nil, nil, nil
end

local function SkinWithMasque(native, data, base)
  local group = MSQ:Group("ForeverAuras", data.id:lower():gsub(" ", "_"), data.uid)
  if native.masqueGroup ~= group then
    ReleaseMasque(native)
    group:SetName(data.id)
    group:AddButton(base, {Icon = native.icon, Cooldown = native.cooldown}, "WA_Aura", true)
    native.masqueGroup = group
    if not masqueMembers[group] then
      masqueMembers[group] = setmetatable({}, {__mode = "k"})
      group:RegisterCallback(MasqueChanged)
    end
    masqueMembers[group][native] = true
  end
  native.masqueData = data
  -- Frames placed by Blizzard's containers can report secret sizes; Masque
  -- takes the configured size instead.
  local width, height = Display.Dimensions(data)
  if group.SetFrameSize then group:SetFrameSize(width, height, base) end
  group:ReSkin(base)
  ApplyMasqueCrop(native, group)
end

-- Called after an Icon is styled. Only buttons that show an icon are skinned;
-- Remaining Time list buttons, bars and texts keep no skin. A Masque error
-- leaves the button unskinned rather than interrupting the restyle.
function Display.StyleMasque(native, data)
  if not MSQ then return end
  local base = native.elementFrames and native.elementFrames.sharedBase
  -- Whether the icon is drawn comes from the settings: the shown state of a
  -- texture on a Blizzard aura button can be secret and cannot be tested.
  local drawsIcon = data.regionType == "icon" and not native.remainingHidesIcon
  if base and drawsIcon and pcall(SkinWithMasque, native, data, base) then return end
  if base then
    pcall(ReleaseMasque, native)
    native.masqueGroup, native.masqueCoords, native.masqueData = nil, nil, nil
    Display.StyleIconTexCoords(native, data)
  end
end

Display.supportedElements = {subbackground = true, subforeground = true, subtext = true, subborder = true, subglow = true, subtexture = true, subcdmdispel = true, subcdmdispelborder = true}

function Display.IsDetachedElement(data, element)
  return Display.Enabled(data) and element and element.secretAuraDetached == true
    and (element.type == "subtext" or element.type == "subtexture")
end

function Display.IsDetachedProperty(data, property)
  local index = property:match("^sub%.(%d+)%.")
  return index and Display.IsDetachedElement(data, data.subRegions and data.subRegions[tonumber(index)]) or false
end

function Display.CanAddElement(data, kind)
  if kind == "subcdmdispel" or kind == "subcdmdispelborder" then return Display.Enabled(data) or Private.CDMAuraProgress.IsConfigured(data) end
  if not Display.Enabled(data) then return true end
  if not Display.supportedElements[kind] then return false end
  -- Any number of Border elements: each draws its own frame (StyleBorder), so
  -- an outer and an inner border, or two colours, can be stacked.
  return true
end

local function TextDefault(regionType)
  local definition = Private.subRegionTypes.subtext.default
  local result = type(definition) == "function" and definition(regionType) or CopyTable(definition)
  result.type = "subtext"
  return result
end

function Display.MigrateAppearance(data, legacy)
  local settings = data.blizzardAuraDisplay
  if data.regionType == "text" then data.automaticWidth = "Fixed" end
  if settings.sharedDisplay then return end
  if legacy then
    local elements = {{type = "subbackground"}}
    for _, key in ipairs(Display.Elements(legacy)) do
      local element
      if key == "duration" or key == "stack" or key == "label" or key:match("^text%d+$") then
        element = TextDefault(data.regionType)
        element.text_text = key == "duration" and "%p" or key == "stack" and "%s" or legacy[key] or ""
        if key ~= "duration" and key ~= "stack" then element.text_text = element.text_text:gsub("%%", "%%%%") end
        element.text_visible = (key ~= "duration" or legacy.duration ~= false) and (key ~= "stack" or legacy.stacks ~= false) and legacy[key .. "Visible"] ~= false
        local fields = {Font = "text_font", Size = "text_fontSize", Color = "text_color", Outline = "text_fontType", Justify = "text_justify",
          ShadowColor = "text_shadowColor", ShadowX = "text_shadowXOffset", ShadowY = "text_shadowYOffset", SelfPoint = "text_selfPoint",
          Anchor = "anchor_point", X = "anchorXOffset", Y = "anchorYOffset"}
        for suffix, field in pairs(fields) do
          local value = legacy[key .. suffix]
          if value ~= nil then element[field] = type(value) == "table" and CopyTable(value) or value end
        end
        local anchor = key == "stack" and "BOTTOMRIGHT" or key == "label" and "BOTTOM" or "CENTER"
        element.anchor_point = legacy[key .. "Anchor"] or anchor
        element.text_selfPoint = legacy[key .. "SelfPoint"] or anchor
        element.anchorXOffset = legacy[key .. "X"] or (key == "stack" and -3 or 0)
        element.anchorYOffset = legacy[key .. "Y"] or ((key == "stack" or key == "label") and 3 or 0)
        element.text_fontSize = legacy[key .. "Size"] or (key == "stack" and 14 or legacy.fontSize or 18)
        element.text_shadowColor = CopyTable(legacy[key .. "ShadowColor"] or {0, 0, 0, 0})
        if key == "duration" then
          element.text_text_format_p_format = "timed"
          element.text_text_format_p_time_format = legacy.durationFormat == "clock" and 0 or legacy.durationFormat == "seconds" and -2 or -1
          element.text_text_format_p_time_precision = legacy.durationPrecision or 1
          element.text_text_format_p_time_dynamic_threshold = legacy.durationDecimalThreshold or 3
          element.text_text_format_p_time_legacy_floor = legacy.durationRoundUp == false
        end
      elseif key == "glow" then
        element = {type = "subglow", glow = legacy.glow == true, glowType = legacy.glowType == "pulse" and "buttonOverlay" or "Proc",
          glowColor = CopyTable(legacy.glowColor or {1, 0.82, 0, 1}), useGlowColor = legacy.useGlowColor ~= false,
          glowScale = legacy.glowScale or 1, glowDuration = legacy.glowDuration or 1, glowXOffset = legacy.glowX or 0, glowYOffset = legacy.glowY or 0}
      elseif key == "background" then
        element = {type = "subtexture", textureVisible = true, textureTexture = "Interface\\Buttons\\WHITE8X8",
          textureColor = CopyTable(legacy.backgroundColor or {0, 0, 0, 0.5}), textureBlendMode = "BLEND", anchor_mode = "area", anchor_area = "ALL"}
      end
      if element then elements[#elements + 1] = element end
    end
    data.subRegions = elements
    data.inverse = legacy.reverse ~= false
  elseif data.regionType == "icon" then
    data.inverse = true
  end
  settings.sharedDisplay = true
end

function Display.Dimensions(data)
  if data.regionType == "text" then
    return math.max(4, data.fixedWidth or 200), math.max(4, data.blizzardAuraDisplay.textHeight or (data.fontSize or 18) * 1.2)
  end
  return math.max(4, data.width or 64), math.max(4, data.height or 64)
end

-- Native bindings each own one text field. Never inspect their resulting text.
function Display.TextKind(value)
  if value == "%p" then return "duration" end
  if value == "%s" then return "stack" end
  if value == "%n" then return "name" end
  -- %l: the label of the trigger's Spell List (Display.SpellList), fixed text.
  if value == "%l" then return "label" end
  if not (value or ""):gsub("%%%%", ""):find("%%") then return "literal" end
end

function Display.ValidateAppearance(data)
  local used = {}
  local function CheckText(value, visible)
    if visible == false then return end
    local kind = Display.TextKind(value)
    if not kind then return L["You can only use %p, %s, %n, %l or hardcoded text. Put each code in its own text element. Custom text (%c) is not supported."] end
    if kind ~= "literal" and used[kind] then return L["Secret auras support one text element for each of %p, %s and %n. Remove the duplicate or turn off Show Text."] end
    used[kind] = true
  end
  if data.regionType == "text" then
    local problem = CheckText(data.displayText)
    if problem then return problem end
  end
  for _, element in ipairs(data.subRegions or {}) do
    if element.type ~= "subborder" and not Display.supportedElements[element.type] then return L["This sub element is not supported by Secret Auras. Use Text, Texture or Glow."] end
    if Display.IsDetachedElement(data, element) then
      if element.type == "subtext" and Display.TextKind(element.text_text) ~= "literal" then
        return L["Detached Text uses hardcoded text. Use other triggers and Conditions to control when it appears."]
      end
    elseif element.type == "subtext" then
      local problem = CheckText(element.text_text, element.text_visible)
      if problem then return problem end
    elseif element.type == "subglow" and element.glow and not ({Proc = true, buttonOverlay = true, Pixel = true, ACShine = true})[element.glowType or "Proc"] then
      return L["Choose Action Button Glow, Pixel Glow, Autocast Shine or Proc Glow."]
    end
  end
end

local function TextSettings(element)
  return {textFont = element.text_font, textSize = element.text_fontSize, textColor = element.text_color, textOutline = element.text_fontType,
    textJustify = element.text_justify, textShadowColor = element.text_shadowColor, textShadowX = element.text_shadowXOffset,
    textShadowY = element.text_shadowYOffset, textSelfPoint = element.text_selfPoint, textAnchor = element.anchor_point,
    textX = element.text_anchorXOffset or element.anchorXOffset, textY = element.text_anchorYOffset or element.anchorYOffset}
end

-- window (optional) is the trigger's Remaining Time filter; it hides the
-- countdown outside that time range through the same native colour curve.
local function BindText(button, text, value, config, prefix, data, baseColor, property, window)
  local kind = Display.TextKind(value)
  -- The trigger's Remaining Time limits every countdown of the display.
  -- Icons only: other display types use the Remaining Time gate.
  if not window and kind == "duration" and data.regionType == "icon" and Display.RemainingWindow then
    local op, x = Display.RemainingWindow(Display.GetTrigger(data))
    if op then window = {op, x} end
  end
  if kind == "duration" then
    local format = config[prefix .. "p_time_format"]
    -- The options window's sample (SecretAuraPreview) formats its countdown
    -- with the element's own Time Format settings, through the same
    -- formatter a %p uses, so the preview shows what the live text shows.
    if button.bindings and Private.format_types and Private.format_types.timed then
      local okF, formatter = pcall(Private.format_types.timed.CreateFormatter, "p", function(key, default)
        local setting = config[prefix .. key]
        if setting == nil then return default end
        return setting
      end, true, data)
      if okF and type(formatter) == "function" then
        local sample = {progressType = "timed"}
        text.faPreviewFormat = function(remaining)
          local okT, result = pcall(formatter, remaining, sample, nil)
          return okT and type(result) == "string" and result or tostring(math.ceil(remaining))
        end
      end
    end
    local options
    if format ~= nil and format ~= -1 then
      options = {textFormatter = Private.GetDurationTextFormatter(config[prefix .. "p_time_legacy_floor"] and 0 or 99,
        config[prefix .. "p_time_dynamic_threshold"] or 3, config[prefix .. "p_time_precision"] or 1, format == -2, format)}
    end
    local color = Display.DurationColorCondition(data, baseColor, property, window)
    if color then
      options = options or {}
      options.textColor = color
      -- An older client may expose the enums before accepting the binding option.
      -- Preserve the countdown if it rejects color registration.
      if pcall(button.SetDurationText, button, text, options) then return end
      options.textColor = nil
    end
    -- A time-limited countdown without its curve would show outside the range:
    -- leave it unbound (empty) instead.
    if window then text:SetText(""); return end
    button:SetDurationText(text, options)
  elseif kind == "stack" then
    local formatter = Display.StackTextCondition(data, property)
    if formatter and pcall(button.SetApplicationCount, button, text, {formatter = formatter}) then return end
    button:SetApplicationCount(text)
  elseif kind == "name" then button:SetSpellName(text)
  elseif kind == "label" then
    local list = Display.SpellList(Display.GetTrigger(data))
    text:SetText(list and list.label or "")
  else
    local literal = (value or ""):gsub("%%%%", "%%")
    text:SetText(literal)
  end
end

Display.TextSettings = TextSettings

local function TextLayout(text, mode, width, wrap)
  text:SetWidth(mode == "Fixed" and (width or 200) or 0)
  text:SetWordWrap(wrap ~= "Elide")
  text:SetNonSpaceWrap(wrap ~= "Elide")
end

local function Area(native, data, name)
  if data.regionType == "aurabar" and name == "bar" then return native.bar, native.barWidth, native.barHeight end
  if data.regionType == "aurabar" and data.icon and name == "icon" then return native.icon, native.iconSize, native.iconSize end
  local width, height = Display.Dimensions(data)
  return native.button, width, height
end

-- BackdropTemplate installs resize scripts and reads frame geometry. Native aura
-- children instead use fixed texture slices sized from the public Display settings.
-- In a Modern Aura Group every part of the row snaps to whole pixels the same
-- way, so icons and borders line up and stay sharp wherever the row starts.
local defaultBias
function Display.SnapTexture(texture, snap)
  if not defaultBias then
    defaultBias = UIParent:CreateTexture():GetTexelSnappingBias()
  end
  texture:SetSnapToPixelGrid(snap)
  texture:SetTexelSnappingBias(snap and defaultBias or 0)
end

local function StyleBorder(entry, parent, target, width, height, element, snapRow)
  if not entry.border then
    entry.border = CreateFrame("Frame", nil, parent)
    entry.borderPieces = {}
    for _, name in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "LEFT", "RIGHT", "TOP", "BOTTOM"}) do
      entry.borderPieces[name] = entry.border:CreateTexture(nil, "ARTWORK")
      entry.borderPieces[name].originalSnappingBias = entry.borderPieces[name]:GetTexelSnappingBias()
    end
  end
  local frame, pieces = entry.border, entry.borderPieces
  local offset = element.border_offset or 0
  width, height = math.max(1, width + offset * 2), math.max(1, height + offset * 2)
  local size = math.min(math.max(0.1, element.border_size or 2), width / 2, height / 2)
  -- Anchor to native geometry without reading it. Ignoring inherited scale makes
  -- each border unit a physical pixel, including on scaled groups/unit frames.
  local pixelPerfect = element.border_ppscale == true
  frame:SetIgnoreParentScale(pixelPerfect)
  frame:SetScale(pixelPerfect and PixelUtil.GetPixelToUIUnitFactor() or 1)
  -- Rounded in the engine also in a Modern Aura Group: the start frames there
  -- are rounded the same way, so the border meets the icon on whole pixels.
  if frame.SetRoundLayoutToNearestPixel then frame:SetRoundLayoutToNearestPixel(pixelPerfect) end
  frame:ClearAllPoints()
  if pixelPerfect then
    size = math.max(1, math.floor((element.border_size or 2) + 0.5))
    offset = math.floor(offset + 0.5)
    frame:SetPoint("TOPLEFT", target, "TOPLEFT", -offset, offset)
    frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", offset, -offset)
  else
    frame:SetPoint("CENTER", target, "CENTER")
    frame:SetSize(width, height)
  end
  local file = Media:Fetch("border", element.border_edge or "Square Full White")
  for _, texture in pairs(pieces) do
    texture:ClearAllPoints()
    texture:SetTexture(file, "REPEAT", "REPEAT")
    texture:SetVertexColor(unpack(element.border_color or {1, 1, 1, 1}))
    -- Engine-side rounding follows protected anchor movement without Lua geometry reads.
    if snapRow and not pixelPerfect then
      Display.SnapTexture(texture, true)
      if texture.SetRoundLayoutToNearestPixel then texture:SetRoundLayoutToNearestPixel(false) end
    else
      texture:SetSnapToPixelGrid(not pixelPerfect)
      texture:SetTexelSnappingBias(pixelPerfect and 0 or texture.originalSnappingBias or 0)
      if texture.SetRoundLayoutToNearestPixel then texture:SetRoundLayoutToNearestPixel(pixelPerfect) end
    end
  end
  for index, point in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
    local texture = pieces[point]
    texture:SetPoint(point, frame, point)
    texture:SetSize(size, size)
    local left = 0.5078125 + (index - 1) * 0.125
    texture:SetTexCoord(left, left + 0.109375, 0.0625, 0.9375)
  end
  local repeatX = math.max(0, width / size - 2 - 0.0625)
  local repeatY = math.max(0, height / size - 2 - 0.0625)
  for _, side in ipairs({"LEFT", "RIGHT"}) do
    local texture = pieces[side]
    texture:SetWidth(size)
    texture:SetPoint("TOP" .. side, pieces["TOP" .. side], "BOTTOM" .. side)
    texture:SetPoint("BOTTOM" .. side, pieces["BOTTOM" .. side], "TOP" .. side)
    local left = side == "LEFT" and 0.0078125 or 0.1328125
    texture:SetTexCoord(left, left + 0.109375, 0.0625, repeatY)
  end
  for _, side in ipairs({"TOP", "BOTTOM"}) do
    local texture = pieces[side]
    texture:SetHeight(size)
    texture:SetPoint(side .. "LEFT", pieces[side .. "LEFT"], side .. "RIGHT")
    texture:SetPoint(side .. "RIGHT", pieces[side .. "RIGHT"], side .. "LEFT")
    local left = side == "TOP" and 0.2578125 or 0.3828125
    texture:SetTexCoord(left, repeatX, left + 0.109375, repeatX, left, 0.0625, left + 0.109375, 0.0625)
  end
  frame:SetAlpha(element.border_alpha or 1)
  frame:Show()
end
-- Shared with the Remaining Time display (SecretAuraSingle.lua), so its
-- border is drawn exactly as a native button's.
Display.StyleBorderFrame = StyleBorder

function Display.StyleAppearance(native, data, ElementFrame, StyleText, StyleGlow)
  local button = native.button
  local width, height = Display.Dimensions(data)
  -- Whole pixels for the box only in a Modern Aura Group (see BuildButton in
  -- BlizzardAuraDisplay.lua); a display of its own, or one in a Dynamic
  -- Group, keeps the exact size its neighbours have.
  if button.SetRoundLayoutToNearestPixel then pcall(button.SetRoundLayoutToNearestPixel, button, Display.FlowGroup(data) ~= nil) end
  button:SetSize(width, height)
  native.inner:SetSize(width * 0.8, height * 0.8)
  native.outer:SetSize(width * 1.1, height * 1.1)
  button:ClearDurationText()
  button:ClearApplicationCount()
  button:ClearSpellName()
  -- ForeverAuras: clearing a binding leaves the text's last string (and its
  -- last colour) in the font string. A restyle that binds it differently, or
  -- leaves it unbound, would otherwise show a stale countdown.
  for _, entry in pairs(native.sharedElements or {}) do
    if entry.text then entry.text:SetText("") end
  end
  if native.mainText then native.mainText:SetText("") end
  button:ClearDurationBar()
  button:ClearDurationCooldown()
  -- ForeverAuras: the cooldown's own countdown numbers keep their last value
  -- as well once its binding is cleared, and the numbers mode set by
  -- HandOffCountdown (SecretAuraSingle.lua) stays on the frame. The live
  -- button's cooldown is reset here so a restyle that no longer hands the
  -- countdown to it leaves no stale number; what still applies is set again
  -- below. Samples keep their swipe (their OnUpdate renews it).
  if not native.preview then
    local cooldown = native.cooldown
    cooldown:Clear()
    cooldown:SetHideCountdownNumbers(true)
    if cooldown.SetUseAuraDisplayTime then cooldown:SetUseAuraDisplayTime(false) end
    if cooldown.SetMinimumCountdownDuration then cooldown:SetMinimumCountdownDuration(0) end
    if cooldown.SetCountdownFormatter then cooldown:SetCountdownFormatter(nil) end
    local numbers = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if numbers then numbers:SetText("") end
  end
  button:ClearIcon()
  -- Rebuild native dispel bindings with the other appearance bindings. Re-registering
  -- an existing texture otherwise aborts Apply and can interrupt region initialization.
  if not native.preview then button:ClearDispelTypeTextures() end
  for _, frame in pairs(native.elementFrames or {}) do frame:Hide() end
  native.border:Hide()
  native.icon:Hide(); native.cooldown:Hide()
  -- A Total Duration or Remaining Time gate may have moved the numbers' cooldown.
  native.cooldown:ClearAllPoints(); native.cooldown:SetAllPoints(native.icon)
  if native.bar then native.bar:Hide() end
  if native.progressBackground then native.progressBackground:Hide() end
  if native.plainTexture then native.plainTexture.texture:Hide() end
  if native.mainText then native.mainText:Hide() end
  for _, entry in pairs(native.sharedElements or {}) do
    if entry.glow then StyleGlow(entry, {blizzardAuraDisplay = {glow = false}}) end
    -- Glow elements (SecretAuraGlow.lua) are rebuilt below when still configured.
    Display.ClearElementGlow(entry)
  end
  -- The timed glow's clip and its gate text binding are rebuilt below when still configured.
  if native.lateGlow then native.lateGlow.clip:Hide(); native.lateGlow.exact = nil end
  -- Pandemic glows are registered again below when still configured.
  Display.ResetPandemicGlows(native)
  native.sharedElements = native.sharedElements or {}
  local base = ElementFrame(native, "sharedBase")
  -- Masque measures the frame it skins whenever it can read its size.
  base:SetSize(width, height)
  base:SetFrameLevel(button:GetFrameLevel() + 1); base:Show()
  native.icon:ClearAllPoints(); native.icon:SetAllPoints(button)
  native.icon:SetDesaturated(data.desaturate == true)
  Display.StyleIconTexCoords(native, data)
  native.icon:SetVertexColor(unpack(data.regionType == "aurabar" and data.icon_color or data.color or {1, 1, 1, 1}))
  if data.regionType == "icon" or (data.regionType == "aurabar" and data.icon) then
    if data.iconSource == 0 and data.displayIcon and data.displayIcon ~= "" then native.icon:SetTexture(data.displayIcon) else button:SetIcon(native.icon) end
    Display.SnapTexture(native.icon, Display.FlowGroup(data) ~= nil)
    native.icon:Show()
  end
  if data.regionType == "icon" and data.cooldown ~= false then
    native.cooldown:SetFrameLevel(base:GetFrameLevel() + 1)
    native.cooldown:SetDrawSwipe(data.cooldownSwipe ~= false)
    native.cooldown:SetDrawEdge(data.cooldownEdge == true)
    native.cooldown:SetReverse(data.inverse == true)
    native.cooldown:SetHideCountdownNumbers(data.cooldownTextDisabled ~= false)
    native.cooldown:SetSwipeColor(unpack(data.blizzardAuraDisplay.swipeColor or {0, 0, 0, 0.8}))
    button:SetDurationCooldown(native.cooldown)
  elseif data.regionType == "progresstexture" then
    Private.ProgressTextureNative.StyleAura(native, data, base)
  elseif data.regionType == "texture" then
    -- ForeverAuras: a Texture display is its texture, drawn by the same
    -- wrapper the display itself uses (TextureBase: rotation, mirroring,
    -- wrap mode), over the whole button; Blizzard shows and hides the button
    -- with the aura. Its colour follows the colour conditions (ApplyProperty).
    if not native.plainTexture then native.plainTexture = Private.TextureBase.create(base) end
    local plain = native.plainTexture
    plain.texture:ClearAllPoints()
    plain.texture:SetAllPoints(button)
    Private.TextureBase.modify(plain, {
      canRotate = data.rotate,
      desaturate = data.desaturate == true,
      blendMode = data.blendMode or "BLEND",
      mirror = data.mirror == true,
      rotation = data.rotation or 0,
      textureWrapMode = data.textureWrapMode or "CLAMPTOBLACKADDITIVE",
    })
    plain:SetTexture(data.texture)
    plain.texture:SetVertexColor(unpack(data.color or {1, 1, 1, 1}))
    plain.texture:Show()
  elseif data.regionType == "aurabar" then
    if not native.bar or (native.progressTexture and native.bar == native.progressTexture.bar) then native.bar = CreateFrame("StatusBar", nil, base) end
    local bar = native.bar
    bar:ClearAllPoints(); bar:SetAllPoints(button)
    bar:SetStatusBarTexture(data.textureSource == "LSM" and Media:Fetch("statusbar", data.texture or "Blizzard") or data.textureInput or "Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(unpack(data.barColor or {1, 0, 0, 1}))
    local vertical = (data.orientation or "HORIZONTAL"):find("VERTICAL", 1, true) ~= nil
    native.barWidth = math.max(4, width - (data.icon and not vertical and height or 0))
    native.barHeight = math.max(4, height - (data.icon and vertical and width or 0))
    native.iconSize = vertical and width or height
    bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    bar:SetReverseFill((data.orientation or ""):find("INVERSE", 1, true) ~= nil)
    if not native.barBackground then native.barBackground = base:CreateTexture(nil, "BACKGROUND") end
    native.barBackground:SetAllPoints(bar)
    native.barBackground:SetColorTexture(unpack(data.backgroundColor or {0, 0, 0, 0.5}))
    native.barBackground:Show()
    if data.icon then
      local first = data.icon_side == "LEFT"
      local side = vertical and (first and "BOTTOM" or "TOP") or (first and "LEFT" or "RIGHT")
      local size = vertical and width or height
      native.icon:ClearAllPoints(); native.icon:SetSize(size, size); native.icon:SetPoint(side, button, side)
      bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", button, "TOPLEFT", side == "LEFT" and size or 0, side == "TOP" and -size or 0)
      bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", side == "RIGHT" and -size or 0, side == "BOTTOM" and size or 0)
    end
    button:SetDurationBar(bar, {direction = data.inverse and Enum.StatusBarTimerDirection.ElapsedTime or Enum.StatusBarTimerDirection.RemainingTime})
    bar:Show()
  end
  if data.regionType ~= "aurabar" and native.barBackground then native.barBackground:Hide() end
  if data.regionType == "text" then
    native.mainText = native.mainText or base:CreateFontString(nil, "OVERLAY")
    StyleText(native.mainText, native, {textFont = data.font, textSize = data.fontSize, textColor = data.color, textOutline = data.outline,
      textJustify = data.justify, textShadowColor = data.shadowColor, textShadowX = data.shadowXOffset, textShadowY = data.shadowYOffset}, "text", 18, "CENTER", 0, 0)
    native.mainText:Show()
    TextLayout(native.mainText, data.automaticWidth, data.fixedWidth, data.wordWrap)
    BindText(button, native.mainText, data.displayText, data, "displayText_format_", data, data.color, "color")
  end
  for index, element in ipairs(data.subRegions or {}) do
    if not Display.IsDetachedElement(data, element) then
      local frame = ElementFrame(native, "shared" .. index)
      frame:SetFrameLevel(button:GetFrameLevel() + index * 3 + 3); frame:SetAlpha(1); frame:Show()
      local entry = native.sharedElements[index]
      if not entry then entry = {button = button, elementFrames = {glow = frame}}; native.sharedElements[index] = entry end
      if entry.text then entry.text:Hide() end
      if entry.border then entry.border:Hide() end
      if entry.texture then entry.texture:Hide() end
      if entry.dispelBorder then entry.dispelBorder:Hide() end
      if entry.dispelEdges then Private.DispelTypeDisplay.Hide(entry.dispelEdges) end
      if element.type == "subbackground" then
        base:SetFrameLevel(frame:GetFrameLevel())
        if native.bar then native.bar:SetFrameLevel(base:GetFrameLevel() + 1) end
        native.cooldown:SetFrameLevel(base:GetFrameLevel() + 1)
      elseif element.type == "subforeground" and native.bar then
        native.bar:SetFrameLevel(frame:GetFrameLevel())
      elseif element.type == "subtext" and element.text_visible ~= false then
        entry.text = entry.text or frame:CreateFontString(nil, "OVERLAY")
        StyleText(entry.text, native, TextSettings(element), "text", 18, "CENTER", 0, 0)
        entry.text:SetAlpha(element.text_alpha or 1)
        TextLayout(entry.text, element.text_automaticWidth, element.text_fixedWidth, element.text_wordWrap)
        entry.text:Show()
        BindText(button, entry.text, element.text_text, element, "text_text_format_", data, element.text_color, "sub." .. index .. ".text_color")
      elseif element.type == "subborder" then
        -- Every Border element is drawn (one frame per element), not only the first.
        if element.border_visible ~= false then
          local target, borderWidth, borderHeight = Area(native, data, element.anchor_area)
          StyleBorder(entry, frame, target, borderWidth, borderHeight, element, Display.FlowGroup(data) ~= nil)
        end
      elseif element.type == "subglow" then
        entry.glowAnchor, entry.glowWidth, entry.glowHeight = Area(native, data, element.anchor_area)
        -- All four glow types, played by Blizzard (SecretAuraGlow.lua).
        -- A glow tied to remaining time lives in a clip that Blizzard's timer
        -- opens (SecretAuraSingle.lua); false means its duration is not known yet.
        local holder = Display.TimedGlowHolder(native, data, index, frame)
        -- A glow an "In Pandemic Window" condition turns on lives in a frame
        -- Blizzard shows during the window (SecretAuraConditions.lua).
        if holder == nil then holder = Display.PandemicGlowHolder(native, data, index, frame) end
        if holder == nil then
          Display.StyleElementGlow(entry, button, frame, entry.glowAnchor, element, entry.glowWidth, entry.glowHeight)
        elseif holder then
          Display.StyleElementGlow(entry, button, holder, entry.glowAnchor,
            setmetatable({glow = true}, {__index = element}), entry.glowWidth, entry.glowHeight)
        end
      elseif element.type == "subcdmdispelborder" and element.dispelVisible ~= false then
        -- Geometry follows a normal frame; Blizzard owns the four textures' type tint.
        entry.dispelAnchor = entry.dispelAnchor or CreateFrame("Frame", nil, frame)
        local anchor = entry.dispelAnchor
        anchor:ClearAllPoints(); anchor:Show()
        if element.anchor_mode == "point" then
          local point, target = element.anchor_point or "CENTER", button
          if point:sub(1, 6) == "INNER_" then target = native.inner; point = point:sub(7)
          elseif point:sub(1, 6) == "OUTER_" then target = native.outer; point = point:sub(7) end
          anchor:SetSize(element.width or 32, element.height or 32)
          anchor:SetPoint(element.self_point or "CENTER", target, point, element.xOffset or 0, element.yOffset or 0)
        else
          local target = Area(native, data, element.anchor_area)
          anchor:SetPoint("TOPLEFT", target, "TOPLEFT", -(element.xOffset or 0) / 2, (element.yOffset or 0) / 2)
          anchor:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", (element.xOffset or 0) / 2, -(element.yOffset or 0) / 2)
        end
        entry.dispelEdges = entry.dispelEdges or Private.DispelTypeDisplay.CreateEdges(frame)
        Private.DispelTypeDisplay.Layout(entry.dispelEdges, anchor, element)
        Private.DispelTypeDisplay.Bind(button, entry.dispelEdges)
      elseif element.type == "subcdmdispel" and element.dispelVisible ~= false then
        -- The dispel icon has its own point/area geometry and native artwork.
        do
          entry.texture = entry.texture or frame:CreateTexture(nil, "OVERLAY", nil, 1)
          local texture = entry.texture
          texture:ClearAllPoints()
          if element.anchor_mode == "area" then
            local target = Area(native, data, element.anchor_area)
            texture:SetPoint("TOPLEFT", target, "TOPLEFT", -(element.xOffset or 0) / 2, (element.yOffset or 0) / 2)
            texture:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", (element.xOffset or 0) / 2, -(element.yOffset or 0) / 2)
          else
            local point = element.anchor_point or "TOPLEFT"
            local target = button
            if point:sub(1, 6) == "INNER_" then target = native.inner; point = point:sub(7)
            elseif point:sub(1, 6) == "OUTER_" then target = native.outer; point = point:sub(7) end
            texture:SetSize(element.width or 16, element.height or 16)
            texture:SetPoint(element.self_point or "TOPLEFT", target, point, element.xOffset or 0, element.yOffset or 0)
          end
          button:AddDispelTypeTexture(texture, {showWhenHelpful = true, showWhenHarmful = true,
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.Icon})
        end
      elseif element.type == "subtexture" and element.textureVisible ~= false then
        entry.texture = entry.texture or frame:CreateTexture(nil, "ARTWORK")
        local texture = entry.texture
        texture:ClearAllPoints()
        if element.anchor_mode == "point" then
          local point = element.anchor_point or "CENTER"
          local target = button
          if point:sub(1, 6) == "INNER_" then target = native.inner; point = point:sub(7)
          elseif point:sub(1, 6) == "OUTER_" then target = native.outer; point = point:sub(7) end
          texture:SetSize(element.width or 32, element.height or 32)
          texture:SetPoint(element.self_point or "CENTER", target, point, element.xOffset or 0, element.yOffset or 0)
        else
          local target = Area(native, data, element.anchor_area)
          texture:SetPoint("TOPLEFT", target, "TOPLEFT", -(element.xOffset or 0) / 2, (element.yOffset or 0) / 2)
          texture:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", (element.xOffset or 0) / 2, -(element.yOffset or 0) / 2)
        end
        texture:SetTexture(element.textureTexture)
        texture:SetVertexColor(unpack(element.textureColor or {1, 1, 1, 1}))
        texture:SetDesaturated(element.textureDesaturate == true)
        texture:SetBlendMode(element.textureBlendMode or "BLEND")
        texture:SetTexCoord(element.textureMirror and 1 or 0, element.textureMirror and 0 or 1, 0, 1)
        texture:SetRotation(math.rad(element.textureRotation or 0))
        texture:SetAlpha(element.texture_alpha or 1)
        texture:Show()
      end
    end
  end
  -- Preview frames evaluate public samples; live frames register native rules.
  Display.StyleNativeConditionIndicators(native, data)
  -- Remaining Time keeps only the countdown and glows on live list buttons.
  if Display.StyleRemainingList then Display.StyleRemainingList(native, data) end
  -- Masque, once the icon's final visibility is known.
  Display.StyleMasque(native, data)
  -- Total Duration gate (SecretAuraSingle.lua).
  if Display.StyleDurationGate then Display.StyleDurationGate(native, data) end
end
