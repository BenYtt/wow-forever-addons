-- Modified for ForeverAuras, 2026-09-29.
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

-- Lua APIs
local tinsert, tremove, wipe = table.insert, table.remove, wipe
local pairs, type, error = pairs, type, error
local _G = _G

-- WoW APIs
local GetScreenWidth, GetScreenHeight, CreateFrame, UnitName
  = GetScreenWidth, GetScreenHeight, CreateFrame, UnitName

local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")

---@class WeakAuras
local WeakAuras = WeakAuras
local L = WeakAuras.L

local displayButtons = OptionsPrivate.displayButtons
local tempGroup = OptionsPrivate.tempGroup
local aceOptions = {}

local function CreateFrameSizer(frame, callback, position)
  callback = callback or (function() end)

  local left, right, top, bottom, xOffset1, yOffset1, xOffset2, yOffset2
  if position == "BOTTOMLEFT" then
    left, right, top, bottom = 1, 0, 0, 1
    xOffset1, yOffset1 = 1, 1
    xOffset2, yOffset2 = 0, 0
  elseif position == "BOTTOMRIGHT" then
    left, right, top, bottom = 0, 1, 0, 1
    xOffset1, yOffset1 = 0, 1
    xOffset2, yOffset2 = -1, 0
  elseif position == "TOPLEFT" then
    left, right, top, bottom = 1, 0, 1, 0
    xOffset1, yOffset1 = 1, 0
    xOffset2, yOffset2 = 0, -1
  elseif position == "TOPRIGHT" then
    left, right, top, bottom = 0, 1, 1, 0
    xOffset1, yOffset1 = 0, 0
    xOffset2, yOffset2 = -1, -1
  end

  local handle = CreateFrame("Button", nil, frame)
  handle:SetPoint(position, frame)
  handle:SetSize(25, 25)
  handle:EnableMouse()

  handle:SetScript("OnMouseDown", function()
    frame:StartSizing(position)
  end)

  handle:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    callback()
  end)

  local normal = handle:CreateTexture(nil, "OVERLAY")
  normal:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  normal:SetTexCoord(left, right, top, bottom)
  normal:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
  normal:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
  handle:SetNormalTexture(normal)

  local pushed = handle:CreateTexture(nil, "OVERLAY")
  pushed:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  pushed:SetTexCoord(left, right, top, bottom)
  pushed:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
  pushed:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
  handle:SetPushedTexture(pushed)

  local highlight = handle:CreateTexture(nil, "OVERLAY")
  highlight:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  highlight:SetTexCoord(left, right, top, bottom)
  highlight:SetPoint("BOTTOMLEFT", handle, xOffset1, yOffset1)
  highlight:SetPoint("TOPRIGHT", handle, xOffset2, yOffset2)
  handle:SetHighlightTexture(highlight)

  return handle
end

local defaultWidth = 830
local defaultHeight = 665
local minWidth = 750
local minHeight = 240

function OptionsPrivate.CreateFrame()
  LibDD:Create_UIDropDownMenu("WeakAuras_DropDownMenu", nil)
  local frame
  local db = OptionsPrivate.savedVars.db
  local odb = OptionsPrivate.savedVars.odb

  frame = CreateFrame("Frame", "ForeverAurasOptions", UIParent, "PortraitFrameTemplate")
  local Theme = OptionsPrivate.Theme
  local modern = Theme.IsModern()
  if not modern then
    local color = CreateColorFromHexString("ff191a1e")
    local cr, cg, cb = color:GetRGB()
    frame.Bg:SetColorTexture(cr, cg, cb, 0.94)
    frame.Bg.colorTexture = {cr, cg, cb, 0.94}
  else
  local r, g, b, a = unpack(Theme.colors.window)
  frame.Bg:ClearAllPoints()
  frame.Bg:SetAllPoints(frame)
  frame.Bg:SetColorTexture(r, g, b, a)
  frame.Bg.colorTexture = {r, g, b, a}
  for i = 1, select("#", frame:GetRegions()) do
    local region = select(i, frame:GetRegions())
    if region:IsObjectType("Texture") and region ~= frame.Bg then
      region:SetAlpha(0)
    end
  end
  for _, key in ipairs({"NineSlice", "PortraitContainer", "TopTileStreaks", "TitleBg"}) do
    if frame[key] and frame[key].SetAlpha then frame[key]:SetAlpha(0) end
  end
  Theme.Flat(frame, {0, 0, 0, 0}, Theme.colors.border)
  frame.faTitleBar = CreateFrame("Frame", nil, frame)
  frame.faTitleBar:SetPoint("TOPLEFT", 1, -1)
  frame.faTitleBar:SetPoint("TOPRIGHT", -1, -1)
  frame.faTitleBar:SetHeight(30)
  Theme.Solid(frame.faTitleBar, "BACKGROUND", Theme.colors.titleBar):SetAllPoints()
  local titleLine = Theme.Solid(frame.faTitleBar, "BORDER", Theme.colors.border)
  titleLine:SetPoint("BOTTOMLEFT")
  titleLine:SetPoint("BOTTOMRIGHT")
  titleLine:SetHeight(1)
  local titleAccent = Theme.Solid(frame.faTitleBar, "ARTWORK", Theme.colors.accent)
  titleAccent:SetPoint("BOTTOMLEFT", 48, 0)
  titleAccent:SetSize(56, 1)
  local badge = CreateFrame("Frame", nil, frame)
  badge:SetSize(66, 66)
  badge:SetPoint("TOPLEFT", frame, "TOPLEFT", -16, 17)
  badge:SetFrameLevel(frame.faTitleBar:GetFrameLevel() + 5)
  local titleLogo = badge:CreateTexture(nil, "ARTWORK")
  titleLogo:SetTexture([[Interface\AddOns\ForeverAuras\Media\Textures\UI\badge.tga]])
  titleLogo:SetAllPoints()
  frame.faTitleLogo = titleLogo
  end

  function OptionsPrivate.SetTitle(title)
    -- The semantic version already includes the BETA prerelease label.
    local text = WeakAuras.displayName .. " " .. WeakAuras.versionString
    if title and title ~= "" then
      text = ("%s - %s"):format(text, title)
    end
    ForeverAurasOptionsTitleText:SetText(text)
  end

  tinsert(UISpecialFrames, frame:GetName())
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetResizeBounds(minWidth, minHeight)
  frame:SetFrameStrata("DIALOG")
  -- Workaround classic issue
  ForeverAurasOptionsPortrait:SetTexture([[Interface\AddOns\ForeverAuras\Media\Textures\foreverauras_logo_128.tga]])

  frame.window = "default"

  local xOffset, yOffset

  if db.frame then
    -- Convert from old settings to new
    odb.frame = db.frame
    if odb.frame.xOffset and odb.frame.yOffset then
      odb.frame.xOffset = odb.frame.xOffset + GetScreenWidth() - (odb.frame.width or defaultWidth) / 2
      odb.frame.yOffset = odb.frame.yOffset + GetScreenHeight()
    end
    db.frame = nil
  end

  if odb.frame then
    xOffset, yOffset = odb.frame.xOffset, odb.frame.yOffset
  end

  if not (xOffset and yOffset) then
    xOffset = GetScreenWidth() / 2
    yOffset = GetScreenHeight() - defaultHeight / 2
  end

  frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", xOffset, yOffset)
  frame:Hide()

  frame:SetScript("OnHide", function()
    -- Tell auras that drive load flags the editor has closed before their
    -- displays are reloaded, so a preview can be withdrawn without first
    -- flashing its content on screen. The frame is already hidden here, so
    -- WeakAuras.IsOptionsOpen() reports false inside the handlers.
    OptionsPrivate.Private.ScanEvents("FA_OPTIONS_CLOSED")

    -- A picked group's children still being previewed in batches (issue #136).
    if frame.StopPickChildren then frame.StopPickChildren() end

    local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()

    OptionsPrivate.Private.ClearFakeStates()

    for id, data in pairs(OptionsPrivate.Private.regions) do
      if data.region then
        data.region:Collapse()
        data.region:OptionsClosed()
        if OptionsPrivate.Private.clones[id] then
          for _, cloneRegion in pairs(OptionsPrivate.Private.clones[id]) do
            cloneRegion:Collapse()
            cloneRegion:OptionsClosed()
          end
        end
      end
    end

    OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
    OptionsPrivate.Private.Resume()

    if OptionsPrivate.Private.mouseFrame then
      OptionsPrivate.Private.mouseFrame:OptionsClosed()
    end

    if OptionsPrivate.Private.personalRessourceDisplayFrame then
      OptionsPrivate.Private.personalRessourceDisplayFrame:OptionsClosed()
    end

    if frame.dynamicTextCodesFrame  then
      frame.dynamicTextCodesFrame:Hide()
    end

    if frame.moversizer then
      frame.moversizer:OptionsClosed()
    end

    -- Closing the options declines an import whose caller waits for an answer. Combat only hides them until it
    -- ends, and a running import has already taken its answer.
    local updateFrame = OptionsPrivate.UpdateFrame(frame, true)
    if updateFrame and updateFrame.callbackFunc and not OptionsPrivate.hidingForCombat then
      updateFrame:Close(false)
    end
  end)

  local width, height

  if odb.frame then
    width, height = odb.frame.width, odb.frame.height
  end

  if not (width and height) then
    width, height = defaultWidth, defaultHeight
  end

  width = max(width, minWidth)
  height = max(height, minHeight)
  frame:SetWidth(width)
  frame:SetHeight(height)

  OptionsPrivate.SetTitle()

  local function commitWindowChanges()
    if not frame.minimized then
      local xOffset = frame:GetRight()-(frame:GetWidth()/2)
      local yOffset = frame:GetTop()
      odb.frame = odb.frame or {}
      odb.frame.xOffset = xOffset
      odb.frame.yOffset = yOffset
      odb.frame.width = frame:GetWidth()
      odb.frame.height = frame:GetHeight()
    end
  end

  if not frame.TitleContainer then
    frame.TitleContainer = CreateFrame("Frame", nil, frame)
    if not modern then frame.TitleContainer:SetAllPoints(frame.TitleBg) end
  end
  if modern then
    frame.TitleContainer:ClearAllPoints()
    frame.TitleContainer:SetAllPoints(frame.faTitleBar)
    frame.TitleContainer:SetFrameLevel(frame.faTitleBar:GetFrameLevel() + 1)
    ForeverAurasOptionsTitleText:ClearAllPoints()
    ForeverAurasOptionsTitleText:SetPoint("LEFT", frame.faTitleBar, "LEFT", 50, 0)
    ForeverAurasOptionsTitleText:SetPoint("RIGHT", frame.faTitleBar, "RIGHT", -160, 0)
    ForeverAurasOptionsTitleText:SetJustifyH("LEFT")
    ForeverAurasOptionsTitleText:SetFont(STANDARD_TEXT_FONT, 13, "")
    ForeverAurasOptionsTitleText:SetTextColor(unpack(Theme.colors.text))
  end

  frame.TitleContainer:SetScript("OnMouseDown", function()
    frame:StartMoving()
  end)
  frame.TitleContainer:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    commitWindowChanges()
  end)

  frame.bottomRightResizer = CreateFrameSizer(frame, commitWindowChanges, "BOTTOMRIGHT")

  frame.UpdateFrameVisible = function(self)
    self.tipPopup:Hide()
    if self.minimized then
      ForeverAurasOptionsTitleText:Hide()
      self.buttonsContainer.frame:Hide()
      for _, fn in ipairs({"TexturePicker", "IconPicker", "ModelPicker", "ImportExport", "TextEditor", "CodeReview", "UpdateFrame", "DebugLog"}) do
        local obj = OptionsPrivate[fn](self, true)
        if obj then
          obj.frame:Hide()
        end
      end
      if self.newView then
        self.newView.frame:Hide()
      end
      self.container.frame:Hide()

      self.loadProgress:Hide()
      self.toolbarContainer:Hide()
      self.filterInput:Hide();
      self.tipFrame:Hide()
      self:HideTip()
      self.bottomRightResizer:Hide()
      self.dynamicTextCodesFrame:Hide()
    else
      ForeverAurasOptionsTitleText:Show()
      self.bottomRightResizer:Show()
      if self.window == "default" then
        OptionsPrivate.SetTitle()
        self.buttonsContainer.frame:Show()
        self.container.frame:Show()
        self:ShowTip()
      else
        self.buttonsContainer.frame:Hide()
        self.container.frame:Hide()
        self.dynamicTextCodesFrame:Hide()
        self:HideTip()
      end
      local widgets = {
        { window = "texture",      title = L["Texture Picker"],       fn = "TexturePicker" },
        { window = "icon",         title = L["Icon Picker"],          fn = "IconPicker" },
        { window = "model",        title = L["Model Picker"],         fn = "ModelPicker" },
        { window = "importexport", title = L["Import / Export"],      fn = "ImportExport" },
        { window = "texteditor",   title = L["Code Editor"],          fn = "TextEditor" },
        { window = "codereview",   title = L["Custom Code Viewer"],   fn = "CodeReview" },
        { window = "debuglog",     title = L["Debug Log"],            fn = "DebugLog" },
        { window = "update",       title = L["Update"],               fn = "UpdateFrame" },
      }

      for _, widget in ipairs(widgets) do
        local obj = OptionsPrivate[widget.fn](self, true)
        if self.window == widget.window then
          OptionsPrivate.SetTitle(widget.title)
          if obj then
            obj.frame:Show()
          end
        else
          if obj then
            obj.frame:Hide()
          end
        end
      end

      if self.window == "newView" then
        OptionsPrivate.SetTitle(L["New Template"])
        self.newView.frame:Show()
      else
        if self.newView then
          self.newView.frame:Hide()
        end
      end
      if self.window == "default" then
        if self.loadProgessVisible then
          self.loadProgress:Show()
          self.toolbarContainer:Hide()
          self.filterInput:Hide();
        else
          self.loadProgress:Hide()
          self.toolbarContainer:Show()
          self.filterInput:Show();
          --self.filterInputClear:Show();
        end
      else
        self.loadProgress:Hide()
        self.toolbarContainer:Hide()
        self.filterInput:Hide();
      end
    end
  end

  if modern then
    frame.CloseButton:ClearAllPoints()
    frame.CloseButton:SetPoint("RIGHT", frame.faTitleBar, "RIGHT", -4, 0)
    frame.CloseButton:SetSize(22, 22)
    frame.CloseButton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
    Theme.SkinGlyphButton(frame.CloseButton, "close", {1, 0.42, 0.42, 1})
  end

  frame.faTopGap = modern and 8 or 0

  local minimizebutton = CreateFrame("Button", nil, frame, "MaximizeMinimizeButtonFrameTemplate")
  minimizebutton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
  minimizebutton:SetPoint("RIGHT", frame.CloseButton, "LEFT", 0, 0)
  if modern then
    minimizebutton:SetSize(22, 22)
    for key, glyph in pairs({MinimizeButton = "minimize", MaximizeButton = "maximize"}) do
      local button = minimizebutton[key]
      if button then
        button:ClearAllPoints()
        button:SetAllPoints(minimizebutton)
        Theme.SkinGlyphButton(button, glyph)
      end
    end
  end

  local fontButton = Theme.TextButton(frame, "Font")
  fontButton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
  fontButton:SetPoint("RIGHT", minimizebutton, "LEFT", -4, 0)
  fontButton:SetScript("OnClick", function(self) Theme.ShowFontMenu(self) end)
  frame.fontButton = fontButton
  local layoutButton = Theme.TextButton(frame, "Layout")
  layoutButton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
  layoutButton:SetPoint("RIGHT", fontButton, "LEFT", -2, 0)
  layoutButton:SetScript("OnClick", function(self) Theme.ShowLayoutMenu(self) end)
  frame.layoutButton = layoutButton
  minimizebutton:SetOnMaximizedCallback(function()
    frame.minimized = false
    local right, top = frame:GetRight(), frame:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
    frame:SetHeight(odb.frame and odb.frame.height or defaultHeight)
    frame:SetWidth(odb.frame and odb.frame.width or defaultWidth)
    frame.buttonsScroll:DoLayout()
    frame:UpdateFrameVisible()
  end)
  minimizebutton:SetOnMinimizedCallback(function()
    commitWindowChanges()
    frame.minimized = true
    local right, top = frame:GetRight(), frame:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
    -- Keep the portrait frame corners from overlapping and inverting the side edges.
    local minimizedHeight = 100
    local border = frame.NineSlice
    if border then
      for _, side in ipairs({"Left", "Right"}) do
        local topCorner, bottomCorner = border["Top" .. side .. "Corner"], border["Bottom" .. side .. "Corner"]
        if topCorner and bottomCorner then
          minimizedHeight = max(minimizedHeight, topCorner:GetHeight() + bottomCorner:GetHeight() - 19 + 1)
        end
      end
    end
    frame:SetHeight(minimizedHeight)
    frame:SetWidth(160)
    frame:UpdateFrameVisible()
  end)

  local tipFrame = CreateFrame("Frame", nil, frame)
  tipFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 17, 30)
  tipFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 10)
  tipFrame:Hide()
  frame.tipFrame = tipFrame

  local tipPopup = CreateFrame("Frame", nil, frame, "BackdropTemplateWeakAuras")
  tipPopup:SetFrameStrata("FULLSCREEN")
  tipPopup:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  tipPopup:SetBackdropColor(0, 0, 0, 0.8)
  --tipPopup:SetHeight(100)
  tipPopup:Hide()
  frame.tipPopup = tipPopup

  local tipPopupTitle = tipPopup:CreateFontString(nil, "BACKGROUND", "GameFontNormalLarge")
  tipPopupTitle:SetPoint("TOPLEFT", tipPopup, "TOPLEFT", 10, -10)
  tipPopupTitle:SetPoint("TOPRIGHT", tipPopup, "TOPRIGHT", -10, -10)
  tipPopupTitle:SetJustifyH("LEFT")
  tipPopupTitle:SetJustifyV("TOP")

  local tipPopupLabel = tipPopup:CreateFontString(nil, "BACKGROUND", "GameFontWhite")
  local fontPath = SharedMedia:Fetch("font", "Fira Sans Medium")
  if (fontPath) then
    tipPopupLabel:SetFont(fontPath, 12)
  end
  tipPopupLabel:SetPoint("TOPLEFT", tipPopupTitle, "BOTTOMLEFT", 0, -6)
  tipPopupLabel:SetPoint("TOPRIGHT", tipPopupTitle, "BOTTOMRIGHT", 0, -6)
  tipPopupLabel:SetJustifyH("LEFT")
  tipPopupLabel:SetJustifyV("TOP")

  local tipPopupLabelCJ = tipPopup:CreateFontString(nil, "BACKGROUND", "GameFontWhite")
  tipPopupLabelCJ:SetFont("Fonts\\ARKai_T.ttf", 12)
  tipPopupLabelCJ:SetPoint("TOPLEFT", tipPopupLabel, "BOTTOMLEFT", 0, 0)
  tipPopupLabelCJ:SetPoint("TOPRIGHT", tipPopupLabel, "BOTTOMRIGHT", 0, 0)
  tipPopupLabelCJ:SetJustifyH("LEFT")
  tipPopupLabelCJ:SetJustifyV("TOP")

  local tipPopupLabelK = tipPopup:CreateFontString(nil, "BACKGROUND", "GameFontWhite")
  tipPopupLabelK:SetFont("Fonts\\K_Pagetext.TTF", 12)
  tipPopupLabelK:SetPoint("TOPLEFT", tipPopupLabelCJ, "BOTTOMLEFT", 0, 0)
  tipPopupLabelK:SetPoint("TOPRIGHT", tipPopupLabelCJ, "BOTTOMRIGHT", 0, 0)
  tipPopupLabelK:SetJustifyH("LEFT")
  tipPopupLabelK:SetJustifyV("TOP")

  local urlWidget = CreateFrame("EditBox", nil, tipPopup, "InputBoxTemplate")
  urlWidget:SetFont(STANDARD_TEXT_FONT, 12, "")
  urlWidget:SetPoint("TOPLEFT", tipPopupLabelK, "BOTTOMLEFT", 6, 0)
  urlWidget:SetPoint("TOPRIGHT", tipPopupLabelK, "BOTTOMRIGHT", 0, 0)
  urlWidget:SetScript("OnChar", function() urlWidget:SetText(urlWidget.text); urlWidget:HighlightText(); end);
  urlWidget:SetScript("OnMouseUp", function() urlWidget:HighlightText(); end);
  urlWidget:SetScript("OnEscapePressed", function() tipPopup:Hide() end)
  urlWidget:SetHeight(34)

  local tipPopupCtrlC = tipPopup:CreateFontString(nil, "BACKGROUND", "GameFontWhite")
  tipPopupCtrlC:SetPoint("TOPLEFT", urlWidget, "BOTTOMLEFT", -6, 0)
  tipPopupCtrlC:SetPoint("TOPRIGHT", urlWidget, "BOTTOMRIGHT", 0, 0)
  tipPopupCtrlC:SetJustifyH("LEFT")
  tipPopupCtrlC:SetJustifyV("TOP")
  tipPopupCtrlC:SetText(L["Press Ctrl+C to copy the URL"])

  --- @type fun(referenceWidget: frame, title: string, texture: string, url: string, description: string, descriptionCJ: string?, descriptionK: string?, rightAligned: boolean?, width: number?)
  local function ToggleTip(referenceWidget, url, title, description, descriptionCJ, descriptionK, rightAligned, width)
    width = width or 400
    if tipPopup:IsVisible() and urlWidget.text == url then
      tipPopup:Hide()
      return
    end
    urlWidget.text = url
    urlWidget:SetText(url)
    tipPopupTitle:SetText(title)
    tipPopupLabel:SetText(description)
    tipPopupLabelCJ:SetText(descriptionCJ)
    tipPopupLabelK:SetText(descriptionK)
    urlWidget:HighlightText()

    tipPopup:ClearAllPoints();
    if rightAligned then
      tipPopup:SetPoint("BOTTOMRIGHT", referenceWidget, "TOPRIGHT", 6, 4)
    else
      tipPopup:SetPoint("BOTTOMLEFT", referenceWidget, "TOPLEFT", -6, 4)
    end

    tipPopup:SetWidth(width)
    tipPopup:Show()
    tipPopup:SetHeight(26 + tipPopupTitle:GetHeight() + tipPopupLabel:GetHeight() + tipPopupLabelCJ:GetHeight() + tipPopupLabelK:GetHeight()
                       + urlWidget:GetHeight() + tipPopupCtrlC:GetHeight())
    -- Refresh text bounds for the first tooltip layout after login.
    tipPopupLabel:GetRect()
    tipPopupLabelCJ:GetRect()
    tipPopupLabelK:GetRect()
  end

  OptionsPrivate.ToggleTip = ToggleTip

  --- @type fun(title: string, texture: string, url: string, description: string, descriptionCJ: string?, descriptionK: string?, rightAligned: boolean?, width: number?)
  local addFooter = function(title, texture, url, description, descriptionCJ, descriptionK, rightAligned, width)
    local button = AceGUI:Create("WeakAurasToolbarButton")
    button:SetSmallFont(true)
    button:SetText(title)
    button:SetTexture(texture)
    button:SetCallback("OnClick", function()
      ToggleTip(button.frame, url, title, description, descriptionCJ, descriptionK, rightAligned, width)
    end)
    button.frame:Show()
    return button.frame
  end

  if OptionsPrivate.changelog then
    local changelog
    if OptionsPrivate.changelog.highlightText then
      changelog = L["Highlights"] .. "\n" .. OptionsPrivate.changelog.highlightText
    else
      changelog = OptionsPrivate.changelog.commitText
    end

    local changelogButton = addFooter(L["Changelog"], "", OptionsPrivate.changelog.fullChangeLogUrl,
                                      changelog, nil, nil, false, 800)
    changelogButton:SetParent(tipFrame)
    changelogButton:SetPoint("LEFT", tipFrame, "LEFT")
  end

  local wagoButton = addFooter(L["Find Auras"], [[Interface\AddOns\ForeverAuras\Media\Textures\wago.tga]], "https://wago.io",
            L["Browse Wago, the largest collection of auras."], nil, nil, true)
  wagoButton:SetParent(tipFrame)
  wagoButton:SetPoint("RIGHT", tipFrame, "RIGHT")

  -- Restore the community footer link using the existing selectable-URL popup.
  -- This keeps link copying consistent with Find Auras and the original editor.
  local discordButton = addFooter("Discord", [[Interface\AddOns\ForeverAuras\Media\Textures\discord.tga]],
    "https://discord.gg/UUMfEWD4Cy", "Join the ForeverAuras Discord community.", nil, nil, true)
  discordButton:SetParent(tipFrame)
  discordButton:SetPoint("RIGHT", wagoButton, "LEFT", -12, 0)

  frame.ShowTip = function(self)
    self.tipFrame:Show()
    self.buttonsContainer.frame:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 17, 30)
    self.container.frame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -17, 28)
  end

  frame.HideTip = function(self)
    self.tipFrame:Hide()
    self.buttonsContainer.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 12)
    self.container.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 10)
  end

  -- Right Side Container
  local container = AceGUI:Create("InlineGroup")
  container.frame:SetParent(frame)
  container.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 10)
  container.frame:SetPoint("TOPLEFT", frame, "TOPRIGHT", -63 - WeakAuras.normalWidth * 340, -frame.faTopGap)
  container.frame:Show()
  container.frame:SetClipsChildren(true)
  container.titletext:Hide()
  -- Hide the border
  container.content:GetParent():SetBackdrop(nil)
  container.content:SetPoint("TOPLEFT", 0, -28)
  container.content:SetPoint("BOTTOMRIGHT", 0, 0)
  frame.container = container
  frame.moversizer, frame.mover = OptionsPrivate.MoverSizer(frame)

  -- filter line
  local filterInput = CreateFrame("EditBox", "WeakAurasFilterInput", frame, "SearchBoxTemplate")
  filterInput:SetScript("OnTextChanged", function(self)
    SearchBoxTemplate_OnTextChanged(self)
    OptionsPrivate.SortDisplayButtons(filterInput:GetText())
  end)
  filterInput:SetHeight(15)
  filterInput:SetPoint("TOP", frame, "TOP", 0, -65 - frame.faTopGap)
  filterInput:SetPoint("LEFT", frame, "LEFT", 24, 0)
  filterInput:SetPoint("RIGHT", container.frame, "LEFT", -2, 0)
  filterInput:SetFont(STANDARD_TEXT_FONT, 10, "")
  frame.filterInput = filterInput
  filterInput:Hide()

  -- Left Side Container
  local buttonsContainer = AceGUI:Create("InlineGroup")
  buttonsContainer:SetWidth(170)
  if modern then
    buttonsContainer.content:GetParent():SetBackdrop(nil)
    Theme.Flat(buttonsContainer.content:GetParent(), Theme.colors.panel, Theme.colors.border)
  end
  buttonsContainer.frame:SetParent(frame)
  buttonsContainer.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 12)
  buttonsContainer.frame:SetPoint("TOP", frame, "TOP", 0, -67 - frame.faTopGap)
  buttonsContainer.frame:SetPoint("RIGHT", container.frame, "LEFT", -17)
  buttonsContainer.frame:Show()
  frame.buttonsContainer = buttonsContainer

  -- Toolbar
  local toolbarContainer = CreateFrame("Frame", nil, buttonsContainer.frame)
  toolbarContainer:SetParent(buttonsContainer.frame)
  -- toolbarContainer:Hide()
  toolbarContainer:SetPoint("TOPLEFT", buttonsContainer.frame, "TOPLEFT", 30, 30)
  toolbarContainer:SetPoint("BOTTOMRIGHT", buttonsContainer.frame, "TOPRIGHT", 0, 0)

  local undo = AceGUI:Create("WeakAurasToolbarButton")
  undo:SetText(L["Undo"])
  undo:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\upleft")
  undo:SetCallback("OnClick", function()
    OptionsPrivate.Private.TimeMachine:StepBackward()
    frame:FillOptions()
  end)
  undo.frame:SetParent(toolbarContainer)
  undo.frame:SetShown(OptionsPrivate.Private.Features:Enabled("undo"))
  undo:SetPoint("LEFT")
  undo.frame:SetCollapsesLayout(true)

  local redo = AceGUI:Create("WeakAurasToolbarButton")
  redo:SetText(L["Redo"])
  redo:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\upright")
  redo:SetCallback("OnClick", function()
    OptionsPrivate.Private.TimeMachine:StepForward()
    frame:FillOptions()
  end)
  redo.frame:SetParent(toolbarContainer)
  redo.frame:SetShown(OptionsPrivate.Private.Features:Enabled("undo"))
  redo:SetPoint("LEFT", undo.frame, "RIGHT", 10, 0)
  redo.frame:SetEnabled(OptionsPrivate.Private.TimeMachine:DescribeNext() ~= nil)
  redo.frame:SetCollapsesLayout(true)
  OptionsPrivate.Private.Features:Subscribe("undo",
    function()
      undo.frame:Show()
      redo.frame:Show()
    end,
    function()
      undo.frame:Hide()
      redo.frame:Hide()
    end
  )

  local tmControls = {
    undo = undo,
    redo = redo,
  }

  function tmControls:Step()
    -- slightly annoying workaround
    -- Buttons behave in a strange way if they are disabled inside of the OnClick handler
    -- where the pushed texture refuses to vanish until the button is enabled & user clicks it again
    -- so, just disable the button after next frame draw, so it's imperceptible to the user but we're not in the OnClick handler
    C_Timer.After(0, function()
      self.undo:SetDisabled(OptionsPrivate.Private.TimeMachine:DescribePrevious() == nil)
      self.redo:SetDisabled(OptionsPrivate.Private.TimeMachine:DescribeNext() == nil)
    end)
  end
  tmControls:Step()
  OptionsPrivate.Private.TimeMachine.sub:AddSubscriber("Step", tmControls)

  local newButton = AceGUI:Create("WeakAurasToolbarButton")
  newButton:SetText(L["New Aura"])
  newButton:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\newaura")
  newButton.frame:SetParent(toolbarContainer)
  newButton.frame:Show()
  newButton:SetPoint("LEFT", redo.frame, "RIGHT", 10, 0)
  frame.toolbarContainer = toolbarContainer

  newButton:SetCallback("OnClick", function()
    frame:NewAura()
  end)

  local importButton = AceGUI:Create("WeakAurasToolbarButton")
  importButton:SetText(L["Import"])
  importButton:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\importsmall")
  importButton:SetCallback("OnClick", OptionsPrivate.ImportFromString)
  importButton.frame:SetParent(toolbarContainer)
  importButton.frame:Show()
  importButton:SetPoint("LEFT", newButton.frame, "RIGHT", 10, 0)

  local lockButton = AceGUI:Create("WeakAurasToolbarButton")
  lockButton:SetText(L["Lock Positions"])
  lockButton:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\lockPosition")
  lockButton:SetCallback("OnClick", function(self)
    if ForeverAurasOptionsSaved.lockPositions then
      lockButton:SetStrongHighlight(false)
      lockButton:UnlockHighlight()
      ForeverAurasOptionsSaved.lockPositions = false
    else
      lockButton:SetStrongHighlight(true)
      lockButton:LockHighlight()
      ForeverAurasOptionsSaved.lockPositions = true
    end
  end)
  if ForeverAurasOptionsSaved.lockPositions then
    lockButton:LockHighlight()
  end
  lockButton.frame:SetParent(toolbarContainer)
  lockButton.frame:Show()
  lockButton:SetPoint("LEFT", importButton.frame, "RIGHT", 10, 0)

  local magnetButton = AceGUI:Create("WeakAurasToolbarButton")
  magnetButton:SetText(L["Magnetically Align"])
  magnetButton:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\magnetic")
  magnetButton:SetCallback("OnClick", function(self)
    if ForeverAurasOptionsSaved.magnetAlign then
      magnetButton:SetStrongHighlight(false)
      magnetButton:UnlockHighlight()
      ForeverAurasOptionsSaved.magnetAlign = false
    else
      magnetButton:SetStrongHighlight(true)
      magnetButton:LockHighlight()
      ForeverAurasOptionsSaved.magnetAlign = true
    end
  end)

  if ForeverAurasOptionsSaved.magnetAlign then
    magnetButton:LockHighlight()
  end
  magnetButton.frame:SetParent(toolbarContainer)
  magnetButton.frame:Show()
  magnetButton:SetPoint("LEFT", lockButton.frame, "RIGHT", 10, 0)

  if C_CooldownViewer then
    local hideCDM = AceGUI:Create("CheckBox")
    hideCDM:SetLabel("Hide Blizzard's CDM")
    hideCDM:SetWidth(150)
    hideCDM:SetValue(OptionsPrivate.Private.db.cdmHideBlizzard == true)
    hideCDM:SetCallback("OnValueChanged", function(_, _, value)
      OptionsPrivate.Private.db.cdmHideBlizzard = value
      OptionsPrivate.Private.ApplyCDMBackground()
    end)
    hideCDM:SetCallback("OnEnter", function(widget)
      GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
      GameTooltip:SetText("Hide Blizzard's CDM")
      -- These native settings must be changed through Blizzard's own UI.
      GameTooltip:AddLine("Keeps Blizzard's cooldown manager enabled for tracking while hiding its four viewers. Set each viewer's Visibility to Always in Blizzard's Edit Mode, and turn Show Tooltips off there if needed. Turning this off restores their previous opacity and leaves tracking enabled. Changes apply out of combat.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    hideCDM:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    hideCDM.frame:SetParent(toolbarContainer)
    hideCDM.frame:HookScript("OnShow", function() hideCDM:SetValue(OptionsPrivate.Private.db.cdmHideBlizzard == true) end)
    hideCDM.frame:SetPoint("LEFT", magnetButton.frame, "RIGHT", 10, 0)
    hideCDM.frame:Show()

    -- Runs the class-pack CDM setup (/fa cdmsetup) from the toolbar: every
    -- catalog buff tracked, hidden spell cooldowns restored, viewers always
    -- visible, Blizzard's CDM hidden, then a reload. It asks before changing
    -- anything, out of combat only.
    local setupCDM = AceGUI:Create("WeakAurasToolbarButton")
    setupCDM:SetText(L["Set Up CDM"])
    setupCDM:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\gear")
    setupCDM:SetCallback("OnClick", function()
      if InCombatLockdown() then
        WeakAuras.prettyPrint(L["CDM setup runs out of combat."])
        return
      end
      StaticPopup_Show("FOREVERAURAS_CDM_SETUP_CONFIRM")
    end)
    setupCDM:SetCallback("OnEnter", function(widget)
      GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
      GameTooltip:SetText(L["Set Up CDM"])
      GameTooltip:AddLine(L["Sets up Blizzard's Cooldown Manager for ForeverAuras: tracks every buff and spell cooldown it lists, sets the viewers to Always visible, hides Blizzard's own display and reloads. Your current CDM and Edit Mode settings are backed up. Same as /fa cdmsetup."], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    setupCDM:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    setupCDM.frame:SetParent(toolbarContainer)
    setupCDM.frame:SetPoint("LEFT", hideCDM.frame, "RIGHT", 0, 0)
    setupCDM.frame:Show()
  end

  local loadProgress = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  loadProgress:SetPoint("TOP", buttonsContainer.frame, "TOP", 0, -4)
  loadProgress:SetText(L["Creating options: "].."0/0")
  frame.loadProgress = loadProgress

  frame.SetLoadProgressVisible = function(self, visible)
    self.loadProgessVisible = visible
    self:UpdateFrameVisible()
  end

  local buttonsScroll = AceGUI:Create("ScrollFrame")
  buttonsScroll:SetLayout("ButtonsScrollLayout")
  buttonsScroll.width = "fill"
  buttonsScroll.height = "fill"
  buttonsContainer:SetLayout("fill")
  buttonsContainer:AddChild(buttonsScroll)
  buttonsScroll.DeleteChild = function(self, delete)
    for index, widget in ipairs(buttonsScroll.children) do
      if widget == delete then
        tremove(buttonsScroll.children, index)
      end
    end
    delete:OnRelease()
    buttonsScroll:DoLayout()
  end
  frame.buttonsScroll = buttonsScroll

  function buttonsScroll:GetScrollPos()
    local status = self.status or self.localstatus
    return status.offset, status.offset + self.scrollframe:GetHeight()
  end

  -- override SetScroll to make children visible as needed
  local oldSetScroll = buttonsScroll.SetScroll
  buttonsScroll.SetScroll = function(self, value)
    oldSetScroll(self, value)
    self.LayoutFunc(self.content, self.children, true)
  end

  function buttonsScroll:SetScrollPos(top, bottom)
    local status = self.status or self.localstatus
    local viewheight = self.scrollframe:GetHeight()
    local height = self.content:GetHeight()
    local move

    local viewtop = -1 * status.offset
    local viewbottom = -1 * (status.offset + viewheight)
    if top > viewtop then
      move = top - viewtop
    elseif bottom < viewbottom then
      move = bottom - viewbottom
    else
      move = 0
    end

    status.offset = status.offset - move

    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", 0, status.offset)
    self.content:SetPoint("TOPRIGHT", 0, status.offset)

    status.scrollvalue = status.offset / ((height - viewheight) / 1000.0)
  end

  -- Ready to Install section
  local pendingInstallButton = AceGUI:Create("WeakAurasLoadedHeaderButton")
  pendingInstallButton:SetText(L["Ready for Install"])
  pendingInstallButton:Disable()
  pendingInstallButton:EnableExpand()
  pendingInstallButton.frame.view:Hide()
  if odb.pendingImportCollapse then
    pendingInstallButton:Collapse()
  else
    pendingInstallButton:Expand()
  end
  pendingInstallButton:SetOnExpandCollapse(function()
    if pendingInstallButton:GetExpanded() then
      odb.pendingImportCollapse = nil
    else
      odb.pendingImportCollapse = true
    end
    OptionsPrivate.SortDisplayButtons()
  end)
  pendingInstallButton:SetExpandDescription(L["Expand all pending Import"])
  pendingInstallButton:SetCollapseDescription(L["Collapse all pending Import"])
  frame.pendingInstallButton = pendingInstallButton

  -- Ready for update section
  local pendingUpdateButton = AceGUI:Create("WeakAurasLoadedHeaderButton")
  pendingUpdateButton:SetText(L["Ready for Update"])
  pendingUpdateButton:Disable()
  pendingUpdateButton:EnableExpand()
  pendingUpdateButton.frame.view:Hide()
  if odb.pendingUpdateCollapse then
    pendingUpdateButton:Collapse()
  else
    pendingUpdateButton:Expand()
  end
  pendingUpdateButton:SetOnExpandCollapse(function()
    if pendingUpdateButton:GetExpanded() then
      odb.pendingUpdateCollapse = nil
    else
      odb.pendingUpdateCollapse = true
    end
    OptionsPrivate.SortDisplayButtons()
  end)
  pendingUpdateButton:SetExpandDescription(L["Expand all pending Import"])
  pendingUpdateButton:SetCollapseDescription(L["Collapse all pending Import"])
  frame.pendingUpdateButton = pendingUpdateButton

  -- Loaded section
  local loadedButton = AceGUI:Create("WeakAurasLoadedHeaderButton")
  loadedButton:SetText(L["Loaded/Standby"])
  loadedButton:Disable()
  loadedButton:EnableExpand()
  if odb.loadedCollapse then
    loadedButton:Collapse()
  else
    loadedButton:Expand()
  end
  loadedButton:SetOnExpandCollapse(function()
    if loadedButton:GetExpanded() then
      odb.loadedCollapse = nil
    else
      odb.loadedCollapse = true
    end
    OptionsPrivate.SortDisplayButtons()
  end)
  loadedButton:SetExpandDescription(L["Expand all loaded displays"])
  loadedButton:SetCollapseDescription(L["Collapse all loaded displays"])
  loadedButton:SetViewClick(function()
    local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()

    if loadedButton.view.visibility == 2 then
      for _, child in ipairs(loadedButton.childButtons) do
        if child:IsLoaded() then
          child:PriorityHide(2)
        end
      end
      loadedButton:PriorityHide(2)
    else
      for _, child in ipairs(loadedButton.childButtons) do
        if child:IsLoaded() then
          child:PriorityShow(2)
        end
      end
      loadedButton:PriorityShow(2)
    end
    OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
  end)
  loadedButton.RecheckVisibility = function(self)
    local none, all = true, true
    for _, child in ipairs(loadedButton.childButtons) do
      if child:GetVisibility() ~= 2 then
        all = false
      end
      if child:GetVisibility() ~= 0 then
        none = false
      end
    end
    local newVisibility
    if all then
      newVisibility = 2
    elseif none then
      newVisibility = 0
    else
      newVisibility = 1
    end
    if newVisibility ~= self.view.visibility then
      self.view.visibility = newVisibility
      self:UpdateViewTexture()
    end
  end
  loadedButton:SetViewDescription(L["Toggle the visibility of all loaded displays"])
  loadedButton.childButtons = {}
  frame.loadedButton = loadedButton

  -- Not Loaded section
  local unloadedButton = AceGUI:Create("WeakAurasLoadedHeaderButton")
  unloadedButton:SetText(L["Not Loaded"])
  unloadedButton:Disable()
  unloadedButton:EnableExpand()
  if odb.unloadedCollapse then
    unloadedButton:Collapse()
  else
    unloadedButton:Expand()
  end
  unloadedButton:SetOnExpandCollapse(function()
    if unloadedButton:GetExpanded() then
      odb.unloadedCollapse = nil
    else
      odb.unloadedCollapse = true
    end
    OptionsPrivate.SortDisplayButtons()
  end)
  unloadedButton:SetExpandDescription(L["Expand all non-loaded displays"])
  unloadedButton:SetCollapseDescription(L["Collapse all non-loaded displays"])
  unloadedButton:SetViewClick(function()
    local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()
    if unloadedButton.view.visibility == 2 then
      for _, child in ipairs(unloadedButton.childButtons) do
        child:PriorityHide(2)
      end
      unloadedButton:PriorityHide(2)
    else
      for _, child in ipairs(unloadedButton.childButtons) do
        child:PriorityShow(2)
      end
      unloadedButton:PriorityShow(2)
    end
    OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
  end)
  unloadedButton.RecheckVisibility = function(self)
    local none, all = true, true
    for _, child in ipairs(unloadedButton.childButtons) do
      if child:GetVisibility() ~= 2 then
        all = false
      end
      if child:GetVisibility() ~= 0 then
        none = false
      end
    end
    local newVisibility
    if all then
      newVisibility = 2
    elseif none then
      newVisibility = 0
    else
      newVisibility = 1
    end
    if newVisibility ~= self.view.visibility then
      self.view.visibility = newVisibility
      self:UpdateViewTexture()
    end
  end
  unloadedButton:SetViewDescription(L["Toggle the visibility of all non-loaded displays"])
  unloadedButton.childButtons = {}
  frame.unloadedButton = unloadedButton

  -- Sidebar used for Dynamic Text Replacements
  local sidegroup = AceGUI:Create("WeakAurasInlineGroup")
  sidegroup.frame:SetParent(frame)
  sidegroup.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -63);
  sidegroup.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 46);
  sidegroup.frame:Show()
  sidegroup:SetLayout("flow")

  local dynamicTextCodesFrame = CreateFrame("Frame", "WeakAurasTextReplacements", sidegroup.frame, "PortraitFrameTemplate")
  dynamicTextCodesFrame.Bg:SetColorTexture(unpack(frame.Bg.colorTexture))
  ButtonFrameTemplate_HidePortrait(dynamicTextCodesFrame)
  dynamicTextCodesFrame:SetPoint("TOPLEFT", sidegroup.frame, "TOPRIGHT", 20, 0)
  dynamicTextCodesFrame:SetPoint("BOTTOMLEFT", sidegroup.frame, "BOTTOMRIGHT", 20, 0)
  dynamicTextCodesFrame:SetWidth(250)
  dynamicTextCodesFrame:SetScript("OnHide", function()
    OptionsPrivate.currentDynamicTextInput = nil
  end)
  frame.dynamicTextCodesFrame = dynamicTextCodesFrame

  local dynamicTextCodesFrameTitle
  if dynamicTextCodesFrame.TitleContainer and dynamicTextCodesFrame.TitleContainer.TitleText then
    dynamicTextCodesFrameTitle = dynamicTextCodesFrame.TitleContainer.TitleText
  elseif dynamicTextCodesFrame.TitleText then
    dynamicTextCodesFrameTitle = dynamicTextCodesFrame.TitleText
  end
  if dynamicTextCodesFrameTitle then
    dynamicTextCodesFrameTitle:SetText("Dynamic Text Replacements")
    dynamicTextCodesFrameTitle:SetJustifyH("CENTER")
    dynamicTextCodesFrameTitle:SetPoint("LEFT", dynamicTextCodesFrame, "TOPLEFT")
    dynamicTextCodesFrameTitle:SetPoint("RIGHT", dynamicTextCodesFrame, "TOPRIGHT", -10, 0)
  end

  local dynamicTextCodesLabel = AceGUI:Create("Label")
  dynamicTextCodesLabel:SetText(L["Insert text replacement codes to make text dynamic."])
  dynamicTextCodesLabel:SetFontObject(GameFontNormal)
  dynamicTextCodesLabel:SetPoint("TOP", dynamicTextCodesFrame, "TOP", 0, -35)
  dynamicTextCodesLabel:SetFontObject(GameFontNormalSmall2)
  dynamicTextCodesLabel.frame:SetParent(dynamicTextCodesFrame)
  dynamicTextCodesLabel.frame:Show()

  local dynamicTextCodesScrollContainer = AceGUI:Create("SimpleGroup")
  dynamicTextCodesScrollContainer.frame:SetParent(dynamicTextCodesFrame)
  dynamicTextCodesScrollContainer.frame:SetPoint("TOP", dynamicTextCodesLabel.frame, "BOTTOM", 0, -15)
  dynamicTextCodesScrollContainer.frame:SetPoint("LEFT", dynamicTextCodesFrame, "LEFT", 15, 0)
  dynamicTextCodesScrollContainer.frame:SetPoint("BOTTOMRIGHT", dynamicTextCodesFrame, "BOTTOMRIGHT", -15, 5)
  dynamicTextCodesScrollContainer:SetFullWidth(true)
  dynamicTextCodesScrollContainer:SetFullHeight(true)
  dynamicTextCodesScrollContainer:SetLayout("Fill")

  local dynamicTextCodesScrollList = AceGUI:Create("ScrollFrame")
  dynamicTextCodesScrollList:SetLayout("List")
  dynamicTextCodesScrollList:SetPoint("TOPLEFT", dynamicTextCodesScrollContainer.frame, "TOPLEFT")
  dynamicTextCodesScrollList:SetPoint("BOTTOMRIGHT", dynamicTextCodesScrollContainer.frame, "BOTTOMRIGHT")
  dynamicTextCodesScrollList.frame:SetParent(dynamicTextCodesFrame)
  dynamicTextCodesScrollList:FixScroll()
  dynamicTextCodesScrollList.scrollframe:SetScript(
    "OnScrollRangeChanged",
    function(frame)
      frame.obj:DoLayout()
    end
  )

  dynamicTextCodesScrollList.scrollframe:SetScript(
    "OnSizeChanged",
    function(frame)
      if frame.obj.scrollBarShown then
        frame.obj.content.width = frame.obj.content.original_width - 10
        frame.obj.scrollframe:SetPoint("BOTTOMRIGHT", -10, 0)
      end
    end
  )

  dynamicTextCodesFrame.scrollList = dynamicTextCodesScrollList
  dynamicTextCodesFrame.label = dynamicTextCodesLabel
  dynamicTextCodesFrame:Hide()

  function OptionsPrivate.ToggleTextReplacements(data, widget, event)
    -- If the text edit has focus when the user clicks on the button, we'll get two events:
    -- a) The OnEditFocusLost
    -- b) The ToggleButton OnClick event
    -- Since we want to hide the text replacement window in that case,
    -- ignore the ToggleButton if it is directly after the  OnEditFocusLost
    local currentTime = GetTime()
    if event == "ToggleButton"
      and dynamicTextCodesFrame.lastCaller
      and dynamicTextCodesFrame.lastCaller.event == "OnEditFocusLost"
      and currentTime - dynamicTextCodesFrame.lastCaller.time < 0.2
    then
      return
    end

    dynamicTextCodesFrame.lastCaller = {
      event = event,
      time = currentTime,
    }

    if event == "OnEnterPressed" then
      dynamicTextCodesFrame:Hide()
    elseif event == "OnEditFocusGained" or not dynamicTextCodesFrame:IsShown() then
      dynamicTextCodesFrame:Show()
      if OptionsPrivate.currentDynamicTextInput ~= widget then
        OptionsPrivate.UpdateTextReplacements(dynamicTextCodesFrame, data)
      end
      OptionsPrivate.currentDynamicTextInput = widget
    elseif not dynamicTextCodesFrame:IsMouseOver() then -- Prevents hiding when clicking inside the frame
      dynamicTextCodesFrame:Hide()
    end
  end

  frame.ClearOptions = function(self, id)
    aceOptions[id] = nil
    OptionsPrivate.commonOptionsCache:Clear()
    if type(id) == "string" then
      local data = WeakAuras.GetData(id)
      if data and data.parent then
        frame:ClearOptions(data.parent)
      end
      for child in OptionsPrivate.Private.TraverseAllChildren(tempGroup) do
        if (id == child.id) then
          frame:ClearOptions(tempGroup.id)
        end
      end
    end
  end

  frame.ReloadOptions = function(self)
    if self.pickedDisplay then
      self:ClearAndUpdateOptions(self.pickedDisplay, true)
      self:FillOptions()
    end
  end

  frame.ClearAndUpdateOptions = function(self, id, clearChildren)
    frame:ClearOptions(id)

    if clearChildren then
      local data
      if type(id) == "string" then
        data = WeakAuras.GetData(id)
      elseif self.pickedDisplay then
        data = tempGroup
      end

      for child in OptionsPrivate.Private.TraverseAllChildren(data) do
        frame:ClearOptions(child.id)
      end
    end
    if (type(self.pickedDisplay) == "string" and self.pickedDisplay == id)
       or (type(self.pickedDisplay) == "table" and id == tempGroup.id)
    then
      frame:UpdateOptions()
    end
  end

  frame.UpdateOptions = function(self)
    if not self.pickedDisplay then
      return
    end
    OptionsPrivate.commonOptionsCache:Clear()
    self.selectedTab = self.selectedTab or "region"
    local data
    if type(self.pickedDisplay) == "string" then
      data = WeakAuras.GetData(frame.pickedDisplay)
    elseif self.pickedDisplay then
      data = tempGroup
    end

    if not data.controlledChildren or data == tempGroup then
      if self.selectedTab == "group" then
        self.selectedTab = "region"
      end
    end

    if self.selectedTab == "auraDisplay" then
      self.selectedTab = "region"
    end
    local optionTable = self:EnsureOptions(data, self.selectedTab)
    if optionTable then
      OptionsPrivate.UseColorPalette(optionTable)
      AceConfigRegistry:RegisterOptionsTable("ForeverAuras", optionTable, true)
    end
  end

  frame.EnsureOptions = function(self, data, tab)
    local id = data.id
    aceOptions[id] = aceOptions[id] or {}
    if not aceOptions[id][tab] then
      local optionsGenerator =
      {
        group = OptionsPrivate.GetGroupOptions,
        region =  OptionsPrivate.GetDisplayOptions,
        trigger = OptionsPrivate.GetTriggerOptions,
        conditions = OptionsPrivate.GetConditionOptions,
        load = OptionsPrivate.GetLoadOptions,
        action = OptionsPrivate.GetActionOptions,
        animation = OptionsPrivate.GetAnimationOptions,
        authorOptions = OptionsPrivate.GetAuthorOptions,
        information = OptionsPrivate.GetInformationOptions,
      }
      if optionsGenerator[tab] then
        aceOptions[id][tab] = optionsGenerator[tab](data)
      end
    end
    return aceOptions[id][tab]
  end

  -- This function refills the options pane
  -- This is ONLY necessary if AceOptions doesn't know that it should do
  -- that automatically. That is any change that goes through the AceOptions
  -- doesn't need to call this
  -- Any changes to the options that go around that, e.g. drag/drop, group,
  -- texture pick, etc should call this
  frame.FillOptions = function(self)
    if not self.pickedDisplay then
      return
    end

    OptionsPrivate.commonOptionsCache:Clear()

    frame:UpdateOptions()

    local data
    if type(self.pickedDisplay) == "string" then
      data = WeakAuras.GetData(frame.pickedDisplay)
    elseif self.pickedDisplay then
      data = tempGroup
    end

    local tabsWidget

    container.frame:SetPoint("TOPLEFT", frame, "TOPRIGHT", -63 - WeakAuras.normalWidth * 340, -10 - frame.faTopGap)
    container:ReleaseChildren()
    container:SetLayout("Fill")
    tabsWidget = AceGUI:Create(Theme.IsModern() and "WeakAurasTabGroup" or "TabGroup")

    local tabs = {
      { value = "region", text = L["Display"]},
      { value = "trigger", text = L["Trigger"]},
      { value = "conditions", text = L["Conditions"]},
      { value = "action", text = L["Actions"]},
      { value = "animation", text = L["Animations"]},
      { value = "authorOptions", text = L["Custom Options"]},
      { value = "information", text = L["Information"]},
      { value = "load", text = L["Load"]},
    }
    -- Check if group and not the temp group
    if data.controlledChildren and type(data.id) == "string" then
      tinsert(tabs, 1, { value = "group", text = L["Group"]})
    end

    tabsWidget:SetTabs(tabs)
    tabsWidget:SelectTab(self.selectedTab)
    tabsWidget:SetLayout("Fill")
    container:AddChild(tabsWidget)

    local group = AceGUI:Create("WeakAurasInlineGroup")
    tabsWidget:AddChild(group)

    tabsWidget:SetCallback("OnGroupSelected", function(self, event, tab)
        frame.selectedTab = tab
        frame:FillOptions()
      end)

    AceConfigDialog:Open("ForeverAuras", group)
    tabsWidget:SetTitle("")

    if data.controlledChildren and #data.controlledChildren == 0 then
      ForeverAurasOptions:NewAura()
    end

    if frame.dynamicTextCodesFrame then
      frame.dynamicTextCodesFrame:Hide()
    end
  end

  frame.ClearPick = function(self, id)
    local index = nil
    for i, childId in pairs(tempGroup.controlledChildren) do
      if childId == id then
        index = i
        break
      end
    end

    tremove(tempGroup.controlledChildren, index)
    displayButtons[id]:ClearPick()

    -- Clear trigger expand state
    OptionsPrivate.ClearTriggerExpandState()

    self:ClearOptions(tempGroup.id)
    self:FillOptions()
  end

  frame.OnRename = function(self, uid, oldid, newid)
    if type(frame.pickedDisplay) == "string" and frame.pickedDisplay == oldid then
      frame.pickedDisplay = newid
    else
      for i, childId in pairs(tempGroup.controlledChildren) do
        if (childId == newid) then
          tempGroup.controlledChildren[i] = newid
        end
      end
    end
  end

  -- ForeverAuras: a picked group's children are previewed in batches over
  -- several frames (issue #136): each child's preview builds its region
  -- (and, for an Aura (Modern) display, its native containers), and a group
  -- of a few hundred children did all of that in one frame, past the
  -- client's script time limit. The first batch is shown at once, so the
  -- pick still feels immediate; the dynamic groups stay suspended until
  -- the last child is shown. A new pick, clearing the picks, or closing
  -- the options window stops a batch still running.
  local pickChildren = {frame = CreateFrame("Frame")}
  pickChildren.frame:Hide()
  -- The dynamic groups a batch keeps suspended are held as the regions
  -- themselves, not their names: a group renamed (or deleted and later
  -- reused) while the batch runs is still resumed, so none is left with
  -- its suspend count raised.
  -- A Modern Aura Group's rows are chained once, when the batch ends,
  -- instead of once per frame while its members come in (a chain of a
  -- few hundred members costs well over a frame on its own, and it grew
  -- with the square of the pack's size over the batch).
  local function SuspendGroupsForBatch()
    local regions = {}
    local modern = OptionsPrivate.Private.BlizzardAuraDisplay
    if modern and modern.BeginFlowLoad then modern.BeginFlowLoad(); regions.flowHeld = true end
    for _, entry in pairs(OptionsPrivate.Private.regions) do
      local region = entry.region
      if region and region.Suspend then
        region:Suspend()
        regions[#regions + 1] = region
      end
    end
    return regions
  end
  local function ResumeGroupsForBatch(regions)
    for _, region in ipairs(regions) do
      if region.Resume then region:Resume() end
    end
    local modern = OptionsPrivate.Private.BlizzardAuraDisplay
    if regions.flowHeld and modern and modern.EndFlowLoad then regions.flowHeld = nil; modern.EndFlowLoad() end
  end
  local function StopPickChildren()
    local job = pickChildren.job
    if not job then return end
    pickChildren.job = nil
    pickChildren.frame:Hide()
    ResumeGroupsForBatch(job.suspended)
  end
  frame.StopPickChildren = StopPickChildren
  -- Shows the children from `index` on, within `budget` milliseconds.
  -- A child whose preview the user toggled with the eye since the batch
  -- began (explicitVisibility, the display button) is left as the user
  -- set it. Returns true when all are shown.
  local function ShowPickChildren(job, budget)
    local finish = debugprofilestop() + budget
    while job.index <= #job.children do
      local child = job.children[job.index]
      job.index = job.index + 1
      local button = displayButtons[child.id]
      if button and (button.explicitVisibility or 0) == (job.explicit[child.id] or 0) then button:PriorityShow(1) end
      if debugprofilestop() > finish then break end
    end
    return job.index > #job.children
  end
  -- While the batch runs, the pack is laid out every quarter second rather
  -- than only at the end: the hold is released for a moment, which chains
  -- and arranges the groups queued so far, and taken again. Icons then
  -- flow into place in steps instead of piling up at the origin until the
  -- last one is shown, at the cost of a few layouts per pick.
  local function LayoutPickChildren(job)
    local modern = OptionsPrivate.Private.BlizzardAuraDisplay
    if not (job.suspended.flowHeld and modern and modern.EndFlowLoad and modern.BeginFlowLoad) then return end
    modern.EndFlowLoad()
    modern.BeginFlowLoad()
    job.lastLayout = GetTime()
  end
  pickChildren.frame:SetScript("OnUpdate", function()
    local job = pickChildren.job
    if not job or not WeakAuras.IsOptionsOpen() then StopPickChildren(); return end
    -- An error in one child's preview is reported and the batch goes on
    -- (the index has moved past that child); the hold is released as usual.
    local ok, done = xpcall(ShowPickChildren, geterrorhandler(), job, 20)
    if not ok then done = job.index > #job.children end
    if done then
      local button = displayButtons[job.id]
      StopPickChildren()
      if button then button:RecheckParentVisibility() end
    elseif GetTime() - (job.lastLayout or 0) >= 0.25 then
      LayoutPickChildren(job)
    end
  end)

  frame.ClearPicks = function(self, noHide)
    StopPickChildren()
    local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()
    for id, button in pairs(displayButtons) do
      button:ClearPick(true)
      if not noHide then
        button:PriorityHide(1)
      end
    end
    if not noHide then
      for id, button in pairs(displayButtons) do
        if button.data.controlledChildren then
          button:RecheckVisibility()
        end
      end
    end

    frame.pickedDisplay = nil
    frame.pickedOption = nil
    wipe(tempGroup.controlledChildren)
    loadedButton:ClearPick(noHide)
    unloadedButton:ClearPick(noHide)
    container:ReleaseChildren()
    self.moversizer:Hide()

    OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)

    -- Clear trigger expand state
    OptionsPrivate.ClearTriggerExpandState()
  end

  frame.GetTargetAura = function(self)
    if self.pickedDisplay then
      if type(self.pickedDisplay) == "table" and tempGroup.controlledChildren and tempGroup.controlledChildren[1] then
        return tempGroup.controlledChildren[1]
      elseif type(self.pickedDisplay) == "string" then
        return self.pickedDisplay
      end
    end
    return nil
  end

  frame.NewAura = function(self)
    local targetId
    local targetIsDynamicGroup

    if self.pickedDisplay then
      if type(self.pickedDisplay) == "table" and tempGroup.controlledChildren and tempGroup.controlledChildren[1] then
        targetId = tempGroup.controlledChildren[1]
        WeakAuras.PickDisplay(targetId)
      elseif type(self.pickedDisplay) == "string" then
        targetId = self.pickedDisplay
      else
        self:ClearPicks()
      end
    end

    if targetId then
      local pickedButton = OptionsPrivate.GetDisplayButton(targetId)
      if pickedButton.data.controlledChildren then
        targetIsDynamicGroup = pickedButton.data.regionType == "dynamicgroup"
      else
        local parent = pickedButton.data.parent
        local parentData = parent and WeakAuras.GetData(parent)
        targetIsDynamicGroup = parentData and parentData.regionType == "dynamicgroup"
      end
    end
    self.dynamicTextCodesFrame:Hide()
    self.moversizer:Hide()
    self.pickedOption = "New"

    container:ReleaseChildren()
    container.frame:SetPoint("TOPLEFT", frame, "TOPRIGHT", -63 - WeakAuras.normalWidth * 340, -frame.faTopGap)
    container:SetLayout("fill")
    local border = AceGUI:Create("InlineGroup")
    border:SetLayout("Fill")
    container:AddChild(border)

    local containerScroll = AceGUI:Create("ScrollFrame")
    containerScroll:SetLayout("flow")
    border:AddChild(containerScroll)

    if C_AddOns.GetAddOnEnableState("ForeverAurasTemplates") ~= Enum.AddOnEnableState.None then
      local simpleLabel = AceGUI:Create("Label")
      simpleLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
      simpleLabel:SetColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
      simpleLabel:SetText(L["Simple"])
      simpleLabel:SetFullWidth(true)
      containerScroll:AddChild(simpleLabel)

      local button = AceGUI:Create("WeakAurasNewButton")
      button:SetTitle(L["Premade Auras"])
      button:SetDescription(L["Offer a guided way to create auras for your character"])
      button:SetIcon("Interface\\Icons\\Inv_misc_book_09")
      button:SetClick(function()
        OptionsPrivate.OpenTriggerTemplate(nil, self:GetTargetAura())
      end)
      containerScroll:AddChild(button)

      local spacer1Label = AceGUI:Create("Label")
      spacer1Label:SetText("")
      containerScroll:AddChild(spacer1Label)

      local advancedLabel = AceGUI:Create("Label")
      advancedLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
      advancedLabel:SetColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
      advancedLabel:SetText(L["Advanced"])
      advancedLabel:SetFullWidth(true)
      containerScroll:AddChild(advancedLabel)
    end

    local regionTypesSorted = {}
    for regionType, regionData in pairs(OptionsPrivate.Private.regionOptions) do
      tinsert(regionTypesSorted, regionType)
    end

    -- Sort group + dynamic group first, then the others alphabetically
    table.sort(regionTypesSorted, function(a, b)
      if (a == "group") then
        return true
      end

      if (b == "group") then
        return false
      end

      if (a == "dynamicgroup") then
        return true
      end
      if (b == "dynamicgroup") then
        return false
      end

      return OptionsPrivate.Private.regionOptions[a].displayName < OptionsPrivate.Private.regionOptions[b].displayName
    end)

    -- Modern Aura Group: a Group whose Aura (Modern) displays grow together
    -- (SecretAuraFlow.lua), listed first.
    if not targetIsDynamicGroup then
      local flowButton = AceGUI:Create("WeakAurasNewButton")
      flowButton:SetTitle("Modern Aura Group")
      -- Its own icon frame: a frame shown on one button cannot be shared.
      frame.modernGroupIcon = frame.modernGroupIcon or OptionsPrivate.CreateModernGroupIcon()
      flowButton:SetIcon(frame.modernGroupIcon)
      flowButton:SetDescription("A group whose Aura (Modern) displays grow together, also in combat")
      flowButton:SetClick(function()
        WeakAuras.NewAura({blizzardFlow = true, blizzardFlowGrowth = "RIGHT", blizzardFlowSpacing = 2, blizzardFlowOrigin = "group"}, "group", self:GetTargetAura())
      end)
      containerScroll:AddChild(flowButton)
    end

    for index, regionType in ipairs(regionTypesSorted) do
      if (targetIsDynamicGroup and (regionType == "group" or regionType == "dynamicgroup")) then
        -- Dynamic groups can't contain group/dynamic groups
      else
        local regionData = OptionsPrivate.Private.regionOptions[regionType]
        local button = AceGUI:Create("WeakAurasNewButton")
        button:SetTitle(regionData.displayName)
        if(type(regionData.icon) == "string" or type(regionData.icon) == "table") then
          button:SetIcon(regionData.icon)
        end
        button:SetDescription(regionData.description)
        button:SetClick(function()
          WeakAuras.NewAura(nil, regionType, self:GetTargetAura())
        end)
        containerScroll:AddChild(button)
      end
    end

    local spacer2Label = AceGUI:Create("Label")
    spacer2Label:SetText("")
    containerScroll:AddChild(spacer2Label)

    local externalLabel = AceGUI:Create("Label")
    externalLabel:SetFont(STANDARD_TEXT_FONT, 14, "")
    externalLabel:SetColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    externalLabel:SetText(L["External"])
    externalLabel:SetFullWidth(true)
    containerScroll:AddChild(externalLabel)

    local spacer3Label = AceGUI:Create("Label")
    spacer3Label:SetText("")
    containerScroll:AddChild(spacer3Label)

    -- Import
    local importButton = AceGUI:Create("WeakAurasNewButton")
    importButton:SetTitle(L["Import"])

    local data = {
      outline = false,
      color = {1, 1, 1, 1},
      justify = "CENTER",
      font = "Friz Quadrata TT",
      fontSize = 8,
      displayText = [[
        b4vmErLxtfM
        xu5fDEn1CEn
        vmUmJyZ4hyY
        DtnEnvBEnfz
        EnfzErLxtjx
        zNL2BUrvEWv
        MxtfwDYfMyH
        jNxtLgzEnLt
        LDNx051u25L
        tXmdmY4fDE5
      ]]
    }

    if not frame.importThumbnail then
      local thumbnail = OptionsPrivate.Private.regionOptions["text"].createThumbnail(UIParent)
      OptionsPrivate.Private.regionOptions["text"].modifyThumbnail(UIParent, thumbnail, data)
      thumbnail.mask:SetPoint("BOTTOMLEFT", thumbnail, "BOTTOMLEFT", 3, 3)
      thumbnail.mask:SetPoint("TOPRIGHT", thumbnail, "TOPRIGHT", -3, -3)
      frame.importThumbnail = thumbnail
    end

    importButton:SetIcon(frame.importThumbnail)
    importButton:SetDescription(L["Import a display from an encoded string"])
    importButton:SetClick(OptionsPrivate.ImportFromString)
    containerScroll:AddChild(importButton)
  end

  local function ExpandParents(data)
    if data.parent then
      if not displayButtons[data.parent]:GetExpanded() then
        displayButtons[data.parent]:Expand()
      end
      local parentData = WeakAuras.GetData(data.parent)
      ExpandParents(parentData)
    end
  end

  frame.PickDisplay = function(self, id, tab, noHide)
    local data = WeakAuras.GetData(id)

    -- Always expand even if already picked
    ExpandParents(data)

    if OptionsPrivate.Private.loaded[id] ~= nil then
      -- Under loaded
      if not loadedButton:GetExpanded() then
        loadedButton:Expand()
      end
    else
      -- Under Unloaded
      if not unloadedButton:GetExpanded() then
        unloadedButton:Expand()
      end
    end

    if self.pickedDisplay == id and (self.pickedDisplay == tab or tab == nil) then
      return
    end

    local suspended = OptionsPrivate.Private.PauseAllDynamicGroups()

    self:ClearPicks(noHide)

    displayButtons[id]:Pick()
    self.pickedDisplay = id

    if tab then
      self.selectedTab = tab
    end
    self:FillOptions()
    WeakAuras.SetMoverSizer(id)

    local _, _, _, _, yOffset = displayButtons[id].frame:GetPoint(1)
    if not yOffset then
      yOffset = displayButtons[id].frame.yOffset
    end
    if yOffset then
      self.buttonsScroll:SetScrollPos(yOffset, yOffset - 32)
    end

    -- The children, in batches when there are many (see pickChildren).
    local children = {}
    for child in OptionsPrivate.Private.TraverseAllChildren(data) do children[#children + 1] = child end
    if #children <= 40 then
      for _, child in ipairs(children) do
        displayButtons[child.id]:PriorityShow(1)
      end
      displayButtons[data.id]:RecheckParentVisibility()
      OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
      return
    end
    -- The batch holds its own suspension (by region, see above); the pick's
    -- own one, by name, ends with this call as before.
    local explicit = {}
    for _, child in ipairs(children) do
      local button = displayButtons[child.id]
      explicit[child.id] = button and button.explicitVisibility or 0
    end
    local job = {id = data.id, children = children, index = 1, explicit = explicit, suspended = SuspendGroupsForBatch()}
    -- The first batch runs before the job is registered for cleanup: an
    -- error in it must still release the layout hold and the suspended
    -- groups, or later layouts (live ones too) would wait forever.
    local ok, done = xpcall(ShowPickChildren, geterrorhandler(), job, 20)
    if not ok or done then
      ResumeGroupsForBatch(job.suspended)
      OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
      if ok then displayButtons[data.id]:RecheckParentVisibility() end
      return
    end
    job.lastLayout = GetTime()
    pickChildren.job = job
    pickChildren.frame:Show()
    OptionsPrivate.Private.ResumeAllDynamicGroups(suspended)
  end

  frame.CenterOnPicked = function(self)
    if self.pickedDisplay then
      local centerId = type(self.pickedDisplay) == "string" and self.pickedDisplay or self.pickedDisplay.controlledChildren[1]

      if displayButtons[centerId] then
        local _, _, _, _, yOffset = displayButtons[centerId].frame:GetPoint(1)
        if not yOffset then
          yOffset = displayButtons[centerId].frame.yOffset
        end
        if yOffset then
          self.buttonsScroll:SetScrollPos(yOffset, yOffset - 32)
        end
      end
    end
  end

  frame.PickDisplayMultiple = function(self, id)
    if not self.pickedDisplay then
      self:PickDisplay(id)
    else
      local wasGroup = false
      if type(self.pickedDisplay) == "string" then
        if WeakAuras.GetData(self.pickedDisplay).controlledChildren or WeakAuras.GetData(id).controlledChildren then
          wasGroup = true
        elseif not OptionsPrivate.IsDisplayPicked(id) then
          tinsert(tempGroup.controlledChildren, self.pickedDisplay)
        end
      end
      if wasGroup then
        self:PickDisplay(id)
      elseif not OptionsPrivate.IsDisplayPicked(id) then
        self.pickedDisplay = tempGroup
        displayButtons[id]:Pick()
        tinsert(tempGroup.controlledChildren, id)
        OptionsPrivate.ClearOptions(tempGroup.id)
        self:FillOptions()
      end
    end
  end

  frame.PickDisplayBatch = function(self, batchSelection)
    local alreadySelected = {}
    for child in OptionsPrivate.Private.TraverseAllChildren(tempGroup) do
      alreadySelected[child.id] = true
    end

    for _, id in ipairs(batchSelection) do
      if not alreadySelected[id] then
        displayButtons[id]:Pick()
        tinsert(tempGroup.controlledChildren, id)
      end
    end
    frame:ClearOptions(tempGroup.id)
    self.pickedDisplay = tempGroup
    self:FillOptions()
  end

  frame.GetPickedDisplay = function(self)
    if type(self.pickedDisplay) == "string" then
      return WeakAuras.GetData(self.pickedDisplay)
    end
    return self.pickedDisplay
  end

  frame:SetClampedToScreen(true)
  local w, h = frame:GetSize()
  local left, right, top, bottom = w/2,-w/2, 0, h-25
  frame:SetClampRectInsets(left, right, top, bottom)

  frame:HookScript("OnShow", function() Theme.ApplyFont(frame) end)
  frame:HookScript("OnHide", function()
    if _G.L_UIDROPDOWNMENU_OPEN_MENU == WeakAuras_DropDownMenu then LibDD:CloseDropDownMenus() end
  end)
  hooksecurefunc(OptionsPrivate, "SortDisplayButtons", function()
    if not frame:IsShown() then return end
    for _, child in ipairs(frame.buttonsScroll.children or {}) do
      Theme.ApplyFontOnce(child.frame)
    end
  end)

  return frame
end
