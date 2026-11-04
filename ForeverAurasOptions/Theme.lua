-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

local Theme = {}
OptionsPrivate.Theme = Theme

Theme.colors = {
  window   = {0.098, 0.102, 0.118, 0.95},
  titleBar = {0.118, 0.122, 0.141, 1},
  panel    = {0, 0, 0, 0.22},
  border   = {0.235, 0.243, 0.275, 1},
  accent   = {0.886, 0.714, 0.341, 0.65},
  hover    = {1, 1, 1, 0.04},
  pressed  = {1, 1, 1, 0.08},
  selected = {1, 1, 1, 0.06},
  text     = {0.918, 0.925, 0.945, 1},
  muted    = {0.600, 0.627, 0.678, 1},
}

Theme.WHITE = "Interface\\Buttons\\WHITE8X8"
Theme.mediaPath = "Interface\\AddOns\\ForeverAuras\\Media\\Textures\\UI\\"

local function SetOnePixel(region, axis)
  if PixelUtil and PixelUtil.SetHeight then
    if axis == "height" then PixelUtil.SetHeight(region, 1) else PixelUtil.SetWidth(region, 1) end
  elseif axis == "height" then
    region:SetHeight(1)
  else
    region:SetWidth(1)
  end
end

function Theme.Solid(parent, layer, color, sublevel)
  local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
  texture:SetTexture(Theme.WHITE)
  texture:SetVertexColor(unpack(color))
  return texture
end

function Theme.Flat(frame, background, border)
  local skin = frame.faSkin
  if not skin then
    skin = {edges = {}}
    skin.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    skin.bg:SetTexture(Theme.WHITE)
    skin.bg:SetAllPoints()
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
      local edge = frame:CreateTexture(nil, "BORDER", nil, -8)
      edge:SetTexture(Theme.WHITE)
      if side == "TOP" or side == "BOTTOM" then
        edge:SetPoint(side .. "LEFT")
        edge:SetPoint(side .. "RIGHT")
        SetOnePixel(edge, "height")
      else
        edge:SetPoint("TOP" .. side)
        edge:SetPoint("BOTTOM" .. side)
        SetOnePixel(edge, "width")
      end
      skin.edges[#skin.edges + 1] = edge
    end
    frame.faSkin = skin
  end
  skin.bg:SetVertexColor(unpack(background))
  for _, edge in ipairs(skin.edges) do
    edge:SetShown(border ~= nil)
    if border then edge:SetVertexColor(unpack(border)) end
  end
  return skin
end

function Theme.TextButton(parent, label)
  local button = CreateFrame("Button", nil, parent)
  button:SetHeight(20)
  local hover = Theme.Solid(button, "BACKGROUND", Theme.colors.hover)
  hover:SetAllPoints()
  hover:Hide()
  local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  text:SetText(label)
  text:SetTextColor(unpack(Theme.colors.muted))
  button.text = text
  button.faOnFontChanged = function() button:SetWidth(text:GetStringWidth() + 14) end
  button.faOnFontChanged()
  button:HookScript("OnEnter", function()
    hover:Show()
    text:SetTextColor(unpack(Theme.colors.text))
  end)
  button:HookScript("OnLeave", function()
    hover:Hide()
    text:SetTextColor(unpack(Theme.colors.muted))
  end)
  return button
end

function Theme.SkinGlyphButton(button, glyph, hoverColor)
  if not button then return end
  local path = Theme.mediaPath .. glyph
  for _, setter in ipairs({"SetNormalTexture", "SetPushedTexture", "SetDisabledTexture"}) do
    if button[setter] then button[setter](button, path) end
  end
  if button.SetHighlightTexture then button:SetHighlightTexture(Theme.WHITE) end
  local normal, pushed, highlight = button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
  for _, texture in ipairs({normal, pushed}) do
    if texture then
      texture:ClearAllPoints()
      texture:SetPoint("CENTER")
      texture:SetSize(14, 14)
      texture:SetTexCoord(0, 1, 0, 1)
    end
  end
  if normal then normal:SetVertexColor(unpack(Theme.colors.muted)) end
  if pushed then pushed:SetVertexColor(unpack(hoverColor or Theme.colors.text)) end
  if highlight then
    highlight:ClearAllPoints()
    highlight:SetAllPoints()
    highlight:SetTexCoord(0, 1, 0, 1)
    highlight:SetVertexColor(unpack(Theme.colors.hover))
  end
  if not button.faGlyphHooked then
    button.faGlyphHooked = true
    button:HookScript("OnEnter", function(self)
      local texture = self:GetNormalTexture()
      if texture then texture:SetVertexColor(unpack(hoverColor or Theme.colors.text)) end
    end)
    button:HookScript("OnLeave", function(self)
      local texture = self:GetNormalTexture()
      if texture then texture:SetVertexColor(unpack(Theme.colors.muted)) end
    end)
  end
end

Theme.GAME_DEFAULT = "Game Default"
local GAME_DEFAULT = Theme.GAME_DEFAULT

local function AutomaticKey()
  if ({koKR = true, zhCN = true, zhTW = true})[GetLocale()] then return GAME_DEFAULT end
  local face = GameFontNormal and GameFontNormal:GetFont()
  if type(face) == "string" and not face:lower():find("frizqt") then return GAME_DEFAULT end
  return "Inter Medium"
end
Theme.AutomaticKey = AutomaticKey

function Theme.GetFontKey()
  local saved = type(ForeverAurasOptionsSaved) == "table" and ForeverAurasOptionsSaved.interfaceFont
  if saved == GAME_DEFAULT or (saved and LSM:IsValid("font", saved)) then return saved end
  return AutomaticKey()
end

function Theme.IsModern()
  return type(ForeverAurasOptionsSaved) == "table" and ForeverAurasOptionsSaved.windowStyle == "modern"
end

function Theme.GetFontPath()
  local key = Theme.GetFontKey()
  if key == GAME_DEFAULT then return nil end
  return LSM:Fetch("font", key, true)
end

local clones, cloneSource, cloneCount = {}, {}, 0
local direct = setmetatable({}, {__mode = "k"})
local buttonFonts = setmetatable({}, {__mode = "k"})
local touched = setmetatable({}, {__mode = "k"})

local function CloneFor(object, path)
  local clone = clones[object]
  if not clone then
    local _, size, flags = object:GetFont()
    if not size then return end
    cloneCount = cloneCount + 1
    clone = CreateFont("WeakAurasInterfaceFont" .. cloneCount)
    clone:CopyFontObject(object)
    cloneSource[clone] = {object = object, size = size, flags = flags or ""}
    clones[object] = clone
  end
  local source = cloneSource[clone]
  clone:SetFont(path, source.size, source.flags)
  return clone
end

local function Normalize(path)
  return type(path) == "string" and path:lower():gsub("/", "\\") or nil
end
local defaultFaces = {}
for _, path in ipairs({STANDARD_TEXT_FONT, UNIT_NAME_FONT, "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"}) do
  if Normalize(path) then defaultFaces[Normalize(path)] = true end
end
for _, object in ipairs({GameFontNormal, GameFontHighlight, GameFontNormalSmall, ChatFontNormal, NumberFontNormal}) do
  local face = object and object.GetFont and object:GetFont()
  if Normalize(face) then defaultFaces[Normalize(face)] = true end
end

local function SwapFontObject(region, object)
  local r, g, b, a = region:GetTextColor()
  local justifyH = region.GetJustifyH and region:GetJustifyH()
  local justifyV = region.GetJustifyV and region:GetJustifyV()
  local sr, sg, sb, sa = region:GetShadowColor()
  local sx, sy = region:GetShadowOffset()
  region:SetFontObject(object)
  if r then region:SetTextColor(r, g, b, a) end
  if justifyH then region:SetJustifyH(justifyH) end
  if justifyV then region:SetJustifyV(justifyV) end
  if sr then region:SetShadowColor(sr, sg, sb, sa) end
  if sx then region:SetShadowOffset(sx, sy) end
end

local function ApplyText(region, path)
  local object = region:GetFontObject()
  if object and cloneSource[object] then return end
  local current, size, flags = region:GetFont()
  if not current or not size then return end
  local saved = direct[region]
  if saved and current == saved.applied then
    if current ~= path then region:SetFont(path, size, flags or "") end
    saved.applied = path
    return
  end
  if not defaultFaces[Normalize(current)] then return end
  if object then
    local objectPath, objectSize = object:GetFont()
    if objectPath == current and objectSize and math.abs(objectSize - size) < 0.5 then
      local clone = CloneFor(object, path)
      if clone then
        SwapFontObject(region, clone)
        return
      end
    end
  end
  direct[region] = {path = current, size = size, flags = flags or "", applied = path}
  region:SetFont(path, size, flags or "")
end

local function RevertText(region)
  local object = region:GetFontObject()
  local source = object and cloneSource[object]
  if source then
    SwapFontObject(region, source.object)
  end
  local saved = direct[region]
  if saved then
    if region:GetFont() == saved.applied then region:SetFont(saved.path, saved.size, saved.flags) end
    direct[region] = nil
  end
end

local buttonStates = {"Normal", "Highlight", "Disabled"}

local function ApplyButton(button, path)
  local saved = buttonFonts[button]
  for _, state in ipairs(buttonStates) do
    local getter = button["Get" .. state .. "FontObject"]
    local object = getter and getter(button)
    if object and not cloneSource[object] and defaultFaces[Normalize((object:GetFont()))] then
      local clone = CloneFor(object, path)
      if clone then
        saved = saved or {}
        saved[state] = object
        button["Set" .. state .. "FontObject"](button, clone)
      end
    end
  end
  buttonFonts[button] = saved
end

local function RevertButton(button)
  local saved = buttonFonts[button]
  if not saved then return end
  for state, object in pairs(saved) do
    local getter = button["Get" .. state .. "FontObject"]
    local current = getter and getter(button)
    if current and cloneSource[current] then button["Set" .. state .. "FontObject"](button, object) end
  end
  buttonFonts[button] = nil
end

local function Walk(frame, path, revert)
  if frame:IsForbidden() or (frame.faKeepFont and not revert) then return end
  if revert then
    touched[frame] = nil
  else
    touched[frame] = true
  end
  if frame:IsObjectType("Button") then
    if revert then RevertButton(frame) else ApplyButton(frame, path) end
  elseif frame:IsObjectType("EditBox") then
    if revert then RevertText(frame) else ApplyText(frame, path) end
  end
  local regions = {frame:GetRegions()}
  for i = 1, #regions do
    local region = regions[i]
    if region:IsObjectType("FontString") then
      if revert then RevertText(region) else ApplyText(region, path) end
    end
  end
  local children = {frame:GetChildren()}
  for i = 1, #children do
    Walk(children[i], path, revert)
  end
  if frame.faOnFontChanged then frame.faOnFontChanged() end
end

function Theme.ApplyFont(frame)
  local path = frame and Theme.GetFontPath()
  if path then Walk(frame, path, false) end
end

function Theme.RevertFont(frame)
  if frame then Walk(frame, nil, true) end
end

hooksecurefunc(AceGUI, "Release", function(_, widget)
  local frame = type(widget) == "table" and widget.frame
  if frame and touched[frame] then Walk(frame, nil, true) end
end)

hooksecurefunc(AceConfigDialog, "Open", function(_, appName, container)
  if appName == "ForeverAuras" and type(container) == "table" and container.frame then
    Theme.ApplyFont(container.frame)
  end
end)

function Theme.SetFontKey(key)
  ForeverAurasOptionsSaved = ForeverAurasOptionsSaved or {}
  ForeverAurasOptionsSaved.interfaceFont = key
  local frame = OptionsPrivate.Private and OptionsPrivate.Private.OptionsFrame and OptionsPrivate.Private.OptionsFrame()
  local path = Theme.GetFontPath()
  if path then
    for clone, source in pairs(cloneSource) do clone:SetFont(path, source.size, source.flags) end
    if frame then Theme.ApplyFont(frame) end
  elseif frame then
    Theme.RevertFont(frame)
  end
  if frame and frame:IsShown() and frame.FillOptions then frame:FillOptions() end
end

function Theme.ApplyFontOnce(frame)
  if frame and not touched[frame] then Theme.ApplyFont(frame) end
end

local CHUNK = 20

local menuAnchor
local function MenuOpen()
  return _G.L_UIDROPDOWNMENU_OPEN_MENU == WeakAuras_DropDownMenu and _G.L_DropDownList1 and L_DropDownList1:IsShown()
end
local dismiss = CreateFrame("Frame")
if pcall(dismiss.RegisterEvent, dismiss, "GLOBAL_MOUSE_DOWN") then
  dismiss:SetScript("OnEvent", function()
    if not MenuOpen() then return end
    for level = 1, (_G.L_UIDROPDOWNMENU_MAXLEVELS or 3) do
      local list = _G["L_DropDownList" .. level]
      if list and list:IsShown() and list:IsMouseOver() then return end
    end
    if menuAnchor and menuAnchor:IsMouseOver() then return end
    LibDD:CloseDropDownMenus()
  end)
end

local function ToggleMenu(menu, anchor)
  if MenuOpen() and menuAnchor == anchor then
    LibDD:CloseDropDownMenus()
    return
  end
  menuAnchor = anchor
  LibDD:EasyMenu(menu, WeakAuras_DropDownMenu, anchor, 0, 0, "MENU")
end

function Theme.ShowFontMenu(anchor)
  local saved = type(ForeverAurasOptionsSaved) == "table" and ForeverAurasOptionsSaved.interfaceFont or nil
  local function Entry(key, label)
    return {
      text = label or key,
      checked = function() return saved ~= nil and Theme.GetFontKey() == key end,
      func = function() Theme.SetFontKey(key); LibDD:CloseDropDownMenus() end,
    }
  end
  local menu = {
    {text = L["Font"], isTitle = true, notCheckable = true},
    {
      text = L["Automatic (%s)"]:format(AutomaticKey()),
      checked = function() return saved == nil end,
      func = function() Theme.SetFontKey(nil); LibDD:CloseDropDownMenus() end,
    },
    Entry(GAME_DEFAULT),
    Entry("Inter"),
    Entry("Inter Medium"),
    Entry("Inter SemiBold"),
  }
  local fonts = {}
  for _, key in ipairs(LSM:List("font")) do
    if key ~= "Inter" and key ~= "Inter Medium" and key ~= "Inter SemiBold" then fonts[#fonts + 1] = key end
  end
  for first = 1, #fonts, CHUNK do
    local last = math.min(first + CHUNK - 1, #fonts)
    local list = {}
    for i = first, last do list[#list + 1] = Entry(fonts[i]) end
    menu[#menu + 1] = {
      text = ("%s - %s"):format(fonts[first], fonts[last]),
      hasArrow = true, notCheckable = true, menuList = list,
    }
  end
  ToggleMenu(menu, anchor)
end

function Theme.ShowLayoutMenu(anchor)
  local function Style(value, label)
    return {
      text = label,
      checked = function() return (value == "modern") == Theme.IsModern() end,
      func = function()
        ForeverAurasOptionsSaved = ForeverAurasOptionsSaved or {}
        if (value == "modern") ~= Theme.IsModern() then
          ForeverAurasOptionsSaved.windowStyle = value
          WeakAuras.prettyPrint("The layout changes after /reload.")
        end
        LibDD:CloseDropDownMenus()
      end,
    }
  end
  ToggleMenu({
    {text = L["Layout"], isTitle = true, notCheckable = true},
    Style("classic", "Classic"),
    Style("modern", "Modern"),
  }, anchor)
end
