-- Books on map (Forever): "Group" side tab (the books of each group member, as an icon grid)
local _, ns = ...
local L = ns.L
local S = ns.Skin
local BOOKS = ns.BOOKS

local PANEL_W, PANEL_H = 280, 520
local ICON, GAP = 24, 3
local HEADER_H = 22
local BLOCK_GAP = 10

local panel
local blocks = {}

local function classColor(unit)
  local _, class = UnitClass(unit)
  local c = class and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

-- Icons -------------------------------------------------------------------
local function iconTooltip(self)
  local b = self.book
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(b.name, 1, 0.82, 0)
  local l = b.locs[1]
  if l then GameTooltip:AddLine(("%s (%.1f, %.1f)"):format(l[4], l[2], l[3]), 1, 1, 1, true) end
  if self.has then
    GameTooltip:AddDoubleLine(self.owner, L["collected"], 1, 1, 1, 0.1, 1, 0.1)
  else
    GameTooltip:AddDoubleLine(self.owner, L["missing"], 1, 1, 1, 1, 0.3, 0.3)
  end
  if l then GameTooltip:AddLine(L["Click: open the map there"], 0.5, 1, 0.5) end
  GameTooltip:Show()
end

local function iconClick(self)
  local l = self.book.locs[1]
  if not l then return end
  if not WorldMapFrame:IsShown() then ToggleWorldMap() end
  WorldMapFrame:SetMapID(l[1])
end

-- one block per player: name, count, then every book as an icon
local function createBlock(parent, width)
  local blk = CreateFrame("Frame", nil, parent)
  blk:SetWidth(width)

  local bg = blk:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT")
  bg:SetPoint("TOPRIGHT")
  bg:SetHeight(HEADER_H)
  S.Gradient(bg, { 0.30, 0.55, 0.88, 0.22 }, { 0.30, 0.55, 0.88, 0 }, true)
  local accent = blk:CreateTexture(nil, "ARTWORK")
  accent:SetPoint("TOPLEFT")
  accent:SetSize(2, HEADER_H)
  accent:SetColorTexture(S.Color(S.C.accent))

  blk.name = S.Text(blk, 13)
  blk.name:SetPoint("TOPLEFT", 10, -5)
  blk.count = S.Text(blk, 11, "muted")
  blk.count:SetPoint("TOPRIGHT", -8, -6)
  blk.version = S.Text(blk, 11, "muted")
  blk.version:SetPoint("LEFT", blk.name, "RIGHT", 6, 0)

  local perRow = math.floor((width + GAP) / (ICON + GAP))
  blk.icons = {}
  for i, b in ipairs(BOOKS) do
    local btn = CreateFrame("Button", nil, blk)
    btn:SetSize(ICON, ICON)
    local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
    btn:SetPoint("TOPLEFT", col * (ICON + GAP), -(HEADER_H + 4 + row * (ICON + GAP)))
    btn.tex = btn:CreateTexture(nil, "ARTWORK")
    btn.tex:SetAllPoints()
    btn.tex:SetTexture("Interface\\Icons\\" .. (b.icon or "INV_Misc_Book_09"))
    btn.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(S.MEDIA .. "Glow")
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    glow:SetSize(ICON * 2, ICON * 2)
    glow:SetVertexColor(0.35, 0.78, 1, 0.8)
    btn.book = b
    btn:SetScript("OnEnter", iconTooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    S.HoverFade(btn, glow)
    btn:SetScript("OnClick", iconClick)
    blk.icons[i] = btn
  end
  blk:SetHeight(HEADER_H + 4 + math.ceil(#BOOKS / perRow) * (ICON + GAP))
  return blk
end

local function fillBlock(blk, owner, isMe)
  local n = 0
  for _, btn in ipairs(blk.icons) do
    local has
    if isMe then has = ns.IsDone(btn.book) else has = ns.GroupHas(owner, btn.book) end
    btn.has, btn.owner = has, owner
    btn.tex:SetDesaturated(not has)
    btn.tex:SetAlpha(has and 1 or 0.3)
    if has then n = n + 1 end
  end
  blk.name:SetText(isMe and L["%s (you)"]:format(owner) or owner)
  blk.name:SetTextColor(classColor(isMe and "player" or owner))
  blk.count:SetText(("%d / %d"):format(n, #BOOKS))
  local version = isMe and ns.ADDON_VERSION or ns.GroupVersion(owner)
  blk.version:SetText(version and "v" .. version or "")
end

-- Panel -------------------------------------------------------------------
-- -1, 0 or 1: version a older, equal or newer than version b ("1.0.7" style)
local function compareVersions(a, b)
  local pa, pb = {}, {}
  for n in a:gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in b:gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  return 0
end

-- status of a member who doesn't share their books: text, r, g, b
local function otherStatus(name)
  local version = ns.GroupOtherVersion(name)
  -- versions before 1.0.7 have no group mode: they send nothing, like no addon at all
  if not version then return L["no addon or < v1.0.7"], 0.6, 0.6, 0.6 end
  if version == "?" or not version:find("%d") then return L["different version"], 1, 0.6, 0.2 end
  local cmp = compareVersions(version, ns.ADDON_VERSION)
  if cmp < 0 then return L["older version (v%s)"]:format(version), 1, 0.6, 0.2 end
  if cmp > 0 then return L["newer version (v%s)"]:format(version), 1, 0.6, 0.2 end
  return L["different version (v%s)"]:format(version), 1, 0.6, 0.2
end

local otherLines = {}

local function otherLine(i)
  local line = otherLines[i]
  if not line then
    line = CreateFrame("Frame", nil, panel.content)
    line:SetSize(panel.content:GetWidth(), 18)
    line.name = S.Text(line, 12)
    line.name:SetPoint("LEFT", 6, 0)
    line.status = S.Text(line, 11)
    line.status:SetPoint("RIGHT", -6, 0)
    otherLines[i] = line
  end
  return line
end

function ns.RefreshGroupPanel()
  if not panel or not panel:IsShown() then return end
  local content = panel.content
  local names = ns.GroupNames()
  local y = 0

  local message
  if not IsInGroup() then message = L["You are not in a group."]
  elseif #names == 0 then message = L["Nobody in your group shares their books yet."] end
  panel.empty:SetShown(message ~= nil)
  if message then
    panel.empty:SetText(message)
    y = panel.empty:GetStringHeight() + 14
  end

  -- you first (to compare), then the members, only when someone shares their books
  local owners = {}
  if #names > 0 then
    owners[1] = ns.PlayerFullName()
    for _, name in ipairs(names) do owners[#owners + 1] = name end
  end
  for i, owner in ipairs(owners) do
    local blk = blocks[i] or createBlock(content, content:GetWidth())
    blocks[i] = blk
    blk:SetPoint("TOPLEFT", 0, -y)
    fillBlock(blk, owner, i == 1)
    blk:Show()
    y = y + blk:GetHeight() + BLOCK_GAP
  end
  for i = #owners + 1, #blocks do blocks[i]:Hide() end

  -- the other members: addon with another book list, or no addon detected
  local sharing, n, outdated = {}, 0, false
  for _, name in ipairs(names) do sharing[name] = true end
  if IsInGroup() then
    for _, name in ipairs(ns.GroupRoster()) do
      if not sharing[name] then
        n = n + 1
        if n == 1 then
          panel.othersHeader:SetPoint("TOPLEFT", 0, -y)
          y = y + panel.othersHeader:GetHeight() + 4
        end
        local line = otherLine(n)
        line:SetPoint("TOPLEFT", 0, -y)
        line.name:SetText(name)
        line.name:SetTextColor(classColor(name))
        local text, r, g, b = otherStatus(name)
        line.status:SetText(text)
        line.status:SetTextColor(r, g, b)
        line:Show()
        y = y + line:GetHeight()
        outdated = outdated or ns.GroupOtherVersion(name) ~= nil
      end
    end
  end
  panel.othersHeader:SetShown(n > 0)
  for i = n + 1, #otherLines do otherLines[i]:Hide() end
  panel.updateHint:SetShown(outdated)
  if outdated then
    panel.updateHint:SetPoint("TOPLEFT", 6, -(y + 6))
    y = y + panel.updateHint:GetStringHeight() + 10
  end

  content:SetHeight(math.max(y, 1))
end

function ns.CreateGroupTab(f)
  panel = ns.CreateSidePanel(f, L["Group"], PANEL_W)
  panel:SetHeight(PANEL_H)

  local legend = S.Text(panel, 11, "muted")
  legend:SetPoint("TOP", 0, -44)
  legend:SetJustifyH("CENTER")
  legend:SetText(L["Greyed out = missing  -  Click: map"])

  local scroll, content = S.Scroll(panel)
  scroll:SetPoint("TOPLEFT", 14, -64)
  scroll:SetPoint("BOTTOMRIGHT", -24, 14)
  content:SetWidth(PANEL_W - 14 - 24)
  panel.content = content

  panel.empty = S.Text(content, 13, "muted")
  panel.empty:SetPoint("TOPLEFT", 6, -6)
  panel.empty:SetWidth(content:GetWidth() - 12)

  -- members who don't share their books
  panel.othersHeader = S.Section(content, L["Other group members"])
  panel.othersHeader:SetWidth(content:GetWidth())

  panel.updateHint = S.Text(content, 11, "muted")
  panel.updateHint:SetWidth(content:GetWidth() - 12)
  panel.updateHint:SetText(L["Books are only shared with the same version of the addon: update it."])

  panel:HookScript("OnShow", ns.RefreshGroupPanel)
  ns.AddSideTab(f, "group", "Interface\\Icons\\INV_Misc_GroupNeedMore", -- people of a group
    L["Group"], L["The books of your group members"], panel)
end
