-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- ForeverAuras colour palette, 2026-09-18. The native picker owns preview, opacity and cancellation.
if not WeakAuras.IsLibsOK() then return end
local _, OptionsPrivate = ...
local panel, session
-- Alpha is opacity: expose percentages without changing the stored 0..1 value.
local function RefreshAlpha(force)
  if not panel or not session or not session.hasOpacity then return end
  if force or not panel.alpha:HasFocus() then
    local percent = (ColorPickerFrame:GetColorAlpha() or 1) * 100
    panel.alpha:SetText((string.format("%.4f", percent):gsub("0+$", ""):gsub("%.$", "")))
    panel.alpha:SetTextColor(1, 1, 1)
  end
end

local function ReadAlpha(text)
  local value = text:match("^%s*(.-)%s*%%?%s*$")
  local percent = value and value:match("^%d*%.?%d+$") and tonumber(value)
  if percent and percent >= 0 and percent <= 100 then return percent / 100 end
end
local function Database()
  ForeverAurasOptionsSaved.colorPalette = ForeverAurasOptionsSaved.colorPalette or {favorites = {}, recent = {}}
  return ForeverAurasOptionsSaved.colorPalette
end

local function Hex(color)
  return string.format("%02X%02X%02X", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

local function Remember(list, color, limit)
  local key = Hex(color)
  for i = #list, 1, -1 do if Hex(list[i]) == key then table.remove(list, i) end end
  table.insert(list, 1, {color[1], color[2], color[3]})
  while #list > limit do table.remove(list) end
end

function OptionsPrivate.UseColorPalette(options)
  if options.type == "color" and not options.control and not options.dialogControl then options.control = "WeakAurasColorPicker" end
  for _, child in pairs(options.args or {}) do OptionsPrivate.UseColorPalette(child) end
end

function OptionsPrivate.PrepareColorPalette(info)
  session = {cancelled = false, hasOpacity = info.hasOpacity == true}
  local current = session
  local cancel = info.cancelFunc
  info.cancelFunc = function(...)
    current.cancelled = true
    if cancel then cancel(...) end
  end
  -- Keep the numeric field synchronized with native slider/color changes while
  -- retaining the widget's normal preview and cancellation callbacks.
  local opacity = info.opacityFunc
  info.opacityFunc = function(...)
    if opacity then opacity(...) end
    if session == current then RefreshAlpha() end
  end
end

local function SelectColor(color)
  ColorPickerFrame.Content.ColorPicker:SetColorRGB(color[1], color[2], color[3])
end

local function Refresh()
  local db = Database()
  for _, name in ipairs({"favorites", "recent"}) do
    for i, button in ipairs(panel[name]) do
      button.color = db[name][i]
      if button.color then button.texture:SetColorTexture(unpack(button.color)); button:Show() else button:Hide() end
    end
  end
  panel.hex:SetText(Hex({ColorPickerFrame:GetColorRGB()}))
  RefreshAlpha()
end

local function CreatePalette()
  panel = CreateFrame("Frame", nil, ColorPickerFrame, "BackdropTemplate")
  panel:SetSize(236, 270)
  panel:SetPoint("TOPLEFT", ColorPickerFrame, "TOPRIGHT", 6, 0)
  panel:SetClampedToScreen(true)
  panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
  panel:SetBackdropColor(0.055, 0.055, 0.065, 0.98)
  panel:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
  local function Label(text, y)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 12, y); label:SetText(text)
  end
  local function Swatch(index, y, list)
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(22, 22)
    button:SetPoint("TOPLEFT", 12 + ((index - 1) % 8) * 26, y - math.floor((index - 1) / 8) * 26)
    button.texture = button:CreateTexture(nil, "ARTWORK"); button.texture:SetAllPoints()
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(_, mouse)
      if mouse == "RightButton" and list == "favorites" then
        table.remove(Database().favorites, index); Refresh()
      elseif mouse == "RightButton" and list == "recent" then
        Remember(Database().favorites, button.color, 16); Refresh()
      else SelectColor(button.color); Refresh() end
    end)
    button:SetScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_TOP")
      GameTooltip:SetText((button.title or "#" .. Hex(button.color)) .. (list == "favorites" and "\nRight-click to remove" or list == "recent" and "\nRight-click to favourite" or ""))
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
  end
  Label("Class colours", -12)
  local classes = {}
  for class in pairs(RAID_CLASS_COLORS) do classes[#classes + 1] = class end
  table.sort(classes)
  for i, class in ipairs(classes) do
    local color = RAID_CLASS_COLORS[class]
    local button = Swatch(i, -32)
    button.color = {color.r, color.g, color.b}; button.title = LOCALIZED_CLASS_NAMES_MALE[class] or class
    button.texture:SetColorTexture(unpack(button.color))
  end
  Label("Favourites", -88)
  Label("Recent colours", -162)
  panel.favorites, panel.recent = {}, {}
  for i = 1, 16 do panel.favorites[i] = Swatch(i, -108, "favorites") end
  for i = 1, 8 do panel.recent[i] = Swatch(i, -182, "recent") end
  local favorite = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  favorite:SetSize(116, 24); favorite:SetPoint("BOTTOMRIGHT", -10, 12); favorite:SetText("Save favourite")
  favorite:SetScript("OnClick", function() Remember(Database().favorites, {ColorPickerFrame:GetColorRGB()}, 16); Refresh() end)
  panel.hex = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  panel.hex:SetSize(84, 24); panel.hex:SetPoint("BOTTOMLEFT", 18, 12); panel.hex:SetAutoFocus(false); panel.hex:SetMaxLetters(7)
  panel.hex:SetScript("OnEnterPressed", function(self)
    local value = self:GetText():gsub("#", "")
    if #value == 6 and value:match("^%x+$") then
      SelectColor({tonumber(value:sub(1,2),16)/255, tonumber(value:sub(3,4),16)/255, tonumber(value:sub(5,6),16)/255})
    end
    self:ClearFocus(); Refresh()
  end)
  panel.hex:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Refresh() end)
  -- Keep opacity beside the native colour controls, directly above their hex box.
  -- Parent to the picker content so placement is independent of the palette panel.
  local content = ColorPickerFrame.Content
  panel.alpha = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
  panel.alpha:SetHeight(20)
  panel.alpha:SetPoint("BOTTOMLEFT", content.HexBox, "TOPLEFT", 0, 8)
  panel.alpha:SetPoint("BOTTOMRIGHT", content.HexBox, "TOPRIGHT", 0, 8)
  panel.alphaLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.alphaLabel:SetPoint("BOTTOMLEFT", panel.alpha, "TOPLEFT", 0, 2)
  panel.alphaLabel:SetText("Alpha (%)")
  panel.alpha:SetAutoFocus(false); panel.alpha:SetMaxLetters(12)
  panel.alpha:SetScript("OnTextChanged", function(self, userInput)
    if not userInput or not session or session.cancelled or not session.hasOpacity then return end
    local alpha = ReadAlpha(self:GetText())
    self:SetTextColor(1, alpha and 1 or 0.3, alpha and 1 or 0.3)
    if alpha then
      -- The native setter updates the slider and invokes its ordinary callbacks;
      -- never write saved settings directly or replace the original cancel value.
      ColorPickerFrame.Content.ColorPicker:SetColorAlpha(alpha)
    end
  end)
  panel.alpha:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RefreshAlpha(true) end)
  panel.alpha:SetScript("OnEscapePressed", function(self) self:ClearFocus(); RefreshAlpha(true) end)
  panel.alpha:SetScript("OnEditFocusLost", function() RefreshAlpha(true) end)
  ColorPickerFrame:HookScript("OnHide", function()
    local current = session
    session = nil; panel:Hide()
    -- The shared native picker may next be opened by another addon.
    panel.alpha:Hide(); panel.alphaLabel:Hide()
    if current then
      local color = {ColorPickerFrame:GetColorRGB()}
      -- Cancellation may run after OnHide; capture this session before another picker opens.
      C_Timer.After(0, function() if not current.cancelled then Remember(Database().recent, color, 8) end end)
    end
  end)
end

function OptionsPrivate.ShowColorPalette()
  if not panel then CreatePalette() end
  -- RGB-only settings must not gain an opacity value through the shared picker.
  local hasOpacity = session and session.hasOpacity or false
  panel.alpha:SetShown(hasOpacity); panel.alphaLabel:SetShown(hasOpacity)
  panel.alpha:ClearFocus()
  Refresh(); panel:Show()
end
