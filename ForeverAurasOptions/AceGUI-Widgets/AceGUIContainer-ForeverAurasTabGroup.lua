-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local Type, Version = "WeakAurasTabGroup", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs, ipairs, assert, type, wipe = pairs, ipairs, assert, type, wipe
local PlaySound, CreateFrame, UIParent = PlaySound, CreateFrame, UIParent

local TAB_HEIGHT, SIDE_WIDTH, OVERLAP, ROW_STEP = 24, 20, 10, 20

local function Theme() return OptionsPrivate.Theme end

local function UpdateTabLook(tab)
  local colors = Theme().colors
  local text = tab.text
  if tab.disabled then
    text:SetTextColor(colors.muted[1], colors.muted[2], colors.muted[3], 0.5)
    tab.bg:SetVertexColor(0, 0, 0, 0)
    tab.underline:Hide()
  elseif tab.selected then
    text:SetTextColor(unpack(colors.text))
    tab.bg:SetVertexColor(unpack(colors.selected))
    tab.underline:Show()
  else
    text:SetTextColor(unpack(tab.hovered and colors.text or colors.muted))
    tab.bg:SetVertexColor(unpack(tab.hovered and colors.hover or {0, 0, 0, 0}))
    tab.underline:Hide()
  end
end

local function Tab_SetText(tab, text)
  tab.text:SetText(text or "")
end

local function Tab_SetSelected(tab, selected)
  tab.selected = selected
  UpdateTabLook(tab)
end

local function Tab_SetDisabled(tab, disabled)
  tab.disabled = disabled
  UpdateTabLook(tab)
end

local function BuildTabsOnUpdate(frame)
  frame.obj:BuildTabs()
  frame:SetScript("OnUpdate", nil)
end

local function Tab_OnClick(tab)
  if not (tab.selected or tab.disabled) then
    PlaySound(841)
    tab.obj:SelectTab(tab.value)
  end
end

local function Tab_OnEnter(tab)
  tab.hovered = true
  UpdateTabLook(tab)
  local self = tab.obj
  self:Fire("OnTabEnter", self.tabs[tab.id].value, tab)
end

local function Tab_OnLeave(tab)
  tab.hovered = false
  UpdateTabLook(tab)
  local self = tab.obj
  self:Fire("OnTabLeave", self.tabs[tab.id].value, tab)
end

local methods = {
  ["OnAcquire"] = function(self)
    self:SetTitle()
  end,

  ["OnRelease"] = function(self)
    self.status = nil
    for k in pairs(self.localstatus) do
      self.localstatus[k] = nil
    end
    self.tablist = nil
    for _, tab in pairs(self.tabs) do
      tab:Hide()
    end
  end,

  ["CreateTab"] = function(self, id)
    local colors = Theme().colors
    local tab = CreateFrame("Button", nil, self.frame)
    tab:SetHeight(TAB_HEIGHT)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetTexture(Theme().WHITE)
    tab.bg:SetPoint("TOPLEFT", OVERLAP / 2, -2)
    tab.bg:SetPoint("BOTTOMRIGHT", -OVERLAP / 2, 4)

    tab.underline = tab:CreateTexture(nil, "ARTWORK")
    tab.underline:SetTexture(Theme().WHITE)
    tab.underline:SetVertexColor(unpack(colors.accent))
    tab.underline:SetPoint("BOTTOMLEFT", tab.bg)
    tab.underline:SetPoint("BOTTOMRIGHT", tab.bg)
    tab.underline:SetHeight(2)

    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("LEFT", tab.bg, "LEFT", 4, 0)
    tab.text:SetPoint("RIGHT", tab.bg, "RIGHT", -4, 0)
    tab.text:SetJustifyH("CENTER")
    tab.text:SetWordWrap(false)

    tab.obj = self
    tab.id = id
    tab:SetScript("OnClick", Tab_OnClick)
    tab:SetScript("OnEnter", Tab_OnEnter)
    tab:SetScript("OnLeave", Tab_OnLeave)

    tab.SetText = Tab_SetText
    tab.SetSelected = Tab_SetSelected
    tab.SetDisabled = Tab_SetDisabled
    return tab
  end,

  ["SetTitle"] = function(self, text)
    self.titletext:SetText(text or "")
    if text and text ~= "" then
      self.alignoffset = 25
    else
      self.alignoffset = 18
    end
    self:BuildTabs()
  end,

  ["SetStatusTable"] = function(self, status)
    assert(type(status) == "table")
    self.status = status
  end,

  ["SelectTab"] = function(self, value)
    local status = self.status or self.localstatus
    local found
    for _, tab in ipairs(self.tabs) do
      if tab.value == value then
        tab:SetSelected(true)
        found = true
      else
        tab:SetSelected(false)
      end
    end
    status.selected = value
    if found then
      self:Fire("OnGroupSelected", value)
    end
  end,

  ["SetTabs"] = function(self, tabs)
    self.tablist = tabs
    self:BuildTabs()
  end,

  ["BuildTabs"] = function(self)
    local tablist = self.tablist
    if not tablist then return end
    local hastitle = (self.titletext:GetText() and self.titletext:GetText() ~= "")
    local tabs = self.tabs
    local width = self.frame.width or self.frame:GetWidth() or 0

    local textWidths, widths = {}, {}
    for i, v in ipairs(tablist) do
      local tab = tabs[i]
      if not tab then
        tab = self:CreateTab(i)
        tabs[i] = tab
      end
      tab:Show()
      Theme().ApplyFont(tab)
      tab:SetText(v.text)
      tab:SetDisabled(v.disabled)
      tab.value = v.value
      textWidths[i] = tab.text:GetStringWidth()
      local tabWidth = math.min(textWidths[i], width > 0 and width or textWidths[i]) + 2 * SIDE_WIDTH
      tab:SetWidth(tabWidth)
      widths[i] = tabWidth - 6
    end
    for i = #tablist + 1, #tabs do
      tabs[i]:Hide()
    end

    local rowwidths, rowends = {}, {}
    local numtabs, numrows, usedwidth = #tablist, 1, 0
    for i = 1, numtabs do
      if usedwidth ~= 0 and (width - usedwidth - widths[i]) < 0 then
        rowwidths[numrows] = usedwidth + 10
        rowends[numrows] = i - 1
        numrows = numrows + 1
        usedwidth = 0
      end
      usedwidth = usedwidth + widths[i]
    end
    rowwidths[numrows] = usedwidth + 10
    rowends[numrows] = numtabs

    if numrows > 1 and rowends[numrows - 1] == numtabs - 1 then
      if (numrows == 2 and rowends[numrows - 1] > 2) or (rowends[numrows] - rowends[numrows - 1] > 2) then
        if (rowwidths[numrows] + widths[numtabs - 1]) <= width then
          rowends[numrows - 1] = rowends[numrows - 1] - 1
          rowwidths[numrows] = rowwidths[numrows] + widths[numtabs - 1]
          rowwidths[numrows - 1] = rowwidths[numrows - 1] - widths[numtabs - 1]
        end
      end
    end

    local starttab = 1
    for row, endtab in ipairs(rowends) do
      for tabno = starttab, endtab do
        local tab = tabs[tabno]
        tab:ClearAllPoints()
        if tabno == starttab then
          tab:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(hastitle and 14 or 7) - (row - 1) * ROW_STEP)
        else
          tab:SetPoint("LEFT", tabs[tabno - 1], "RIGHT", -OVERLAP, 0)
        end
      end
      local padding = 0
      if not (numrows == 1 and rowwidths[1] < width * 0.75 - 18) then
        padding = (width - rowwidths[row]) / (endtab - starttab + 1)
      end
      for i = starttab, endtab do
        tabs[i]:SetWidth(textWidths[i] + padding + 4 + 2 * SIDE_WIDTH)
      end
      starttab = endtab + 1
    end

    self.borderoffset = (hastitle and 17 or 10) + numrows * ROW_STEP
    self.border:SetPoint("TOPLEFT", 1, -self.borderoffset)
  end,

  ["OnWidthSet"] = function(self, width)
    local content = self.content
    local contentwidth = width - 60
    if contentwidth < 0 then
      contentwidth = 0
    end
    content:SetWidth(contentwidth)
    content.width = contentwidth
    self:BuildTabs(self)
    self.frame:SetScript("OnUpdate", BuildTabsOnUpdate)
  end,

  ["OnHeightSet"] = function(self, height)
    local content = self.content
    local contentheight = height - (self.borderoffset + 23)
    if contentheight < 0 then
      contentheight = 0
    end
    content:SetHeight(contentheight)
    content.height = contentheight
  end,

  ["LayoutFinished"] = function(self, width, height)
    if self.noAutoHeight then return end
    self:SetHeight((height or 0) + (self.borderoffset + 23))
  end
}

local function Constructor()
  local num = AceGUI:GetNextWidgetNum(Type)
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetHeight(100)
  frame:SetWidth(100)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")

  local titletext = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titletext:SetPoint("TOPLEFT", 14, 0)
  titletext:SetPoint("TOPRIGHT", -14, 0)
  titletext:SetJustifyH("LEFT")
  titletext:SetHeight(18)
  titletext:SetText("")

  local border = CreateFrame("Frame", nil, frame)
  border:SetPoint("TOPLEFT", 1, -27)
  border:SetPoint("BOTTOMRIGHT", -1, 3)
  OptionsPrivate.Theme.Flat(border, OptionsPrivate.Theme.colors.panel, OptionsPrivate.Theme.colors.border)

  local content = CreateFrame("Frame", nil, border)
  content:SetPoint("TOPLEFT", 10, -7)
  content:SetPoint("BOTTOMRIGHT", -10, 7)

  local widget = {
    num          = num,
    frame        = frame,
    localstatus  = {},
    alignoffset  = 18,
    titletext    = titletext,
    border       = border,
    borderoffset = 27,
    tabs         = {},
    content      = content,
    type         = Type
  }
  for method, func in pairs(methods) do
    widget[method] = func
  end

  return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
