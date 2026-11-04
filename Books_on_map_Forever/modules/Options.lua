-- Books on map (Forever): options window (book list grouped by set)
local ADDON, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS
local S = ns.Skin

local WIDTH, HEIGHT = 470, 760
local ROW_H, HEADER_H = 36, 26
local GOAL_NECKLACE, GOAL_RING, GOAL_25 = unpack(ns.GOALS)

local SETS = {
  { id = 1, label = "Starting set" },
  { id = 35, label = "Level 35 set" },
  { id = 45, label = "Level 45 set" },
  { id = 60, label = "Level 60 set" },
}

local frame
local layoutList

-- our popups go above the welcome page (FULLSCREEN_DIALOG); the shared popup frame is put back after
local function raisePopup(self) self:SetFrameStrata("FULLSCREEN_DIALOG"); self:Raise() end
local function lowerPopup(self) self:SetFrameStrata("DIALOG") end

-- Language (reloads the UI: names are localized at load); also used by the welcome page
StaticPopupDialogs.BOOKSONMAPFOREVER_RELOAD = {
  text = L["The interface will be reloaded to apply the language."],
  button1 = OKAY, button2 = CANCEL,
  OnAccept = function(_, lang) ns.db.lang = lang; ReloadUI() end,
  OnShow = raisePopup, OnHide = lowerPopup,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Report a bug: the game can't open links, so the Discord invite is shown selected, ready to copy
ns.DISCORD = "https://discord.com/invite/2WXxyC84NJ"
StaticPopupDialogs.BOOKSONMAPFOREVER_BUG = {
  text = L["Report a bug on Discord: press Ctrl+C to copy the link."],
  button1 = CLOSE,
  hasEditBox = true, editBoxWidth = 260,
  OnShow = function(self)
    raisePopup(self)
    local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
    box:SetText(ns.DISCORD)
    box:HighlightText()
    box:SetFocus()
    -- typing can't change the link
    box:SetScript("OnTextChanged", function(b) if b:GetText() ~= ns.DISCORD then b:SetText(ns.DISCORD); b:HighlightText() end end)
  end,
  OnHide = function(self)
    lowerPopup(self)
    local box = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
    box:SetScript("OnTextChanged", nil)
  end,
  EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

function ns.ReportBug() StaticPopup_Show("BOOKSONMAPFOREVER_BUG") end

-- small title-bar button that opens the bug report popup
function ns.BugButton(parent)
  local b = S.Button(parent, "Bug", 34, 20, ns.ReportBug) -- narrow: the version text sits left of it
  b:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Report a bug"], 1, 1, 1)
    GameTooltip:AddLine(L["Copy the link of the Discord server"], 0.5, 1, 0.5)
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- Auto / EN / FR pills; picking another language asks to reload
function ns.LanguageSelector(parent)
  return S.Segmented(parent, {
    { "auto", L["Auto"], L["Automatic (game language)"] },
    { "enUS", "EN", "English" },
    { "frFR", "FR", "Français" },
  }, 38, function() return ns.db.lang or "auto" end, function(value)
    if (ns.db.lang or "auto") ~= value then
      local d = StaticPopup_Show("BOOKSONMAPFOREVER_RELOAD")
      if d then d.data = value end
    end
  end)
end

local function iconPath(b)
  return "Interface\\Icons\\" .. (b.icon or "INV_Misc_Book_09")
end

-- list layout: filtered rows are hidden, the rest stacked in their set's body, which is
-- squeezed by its fold animation (h.foldShown: 1 open, 0 folded)
layoutList = function()
  local level = UnitLevel("player")
  local y = 0
  for _, h in ipairs(frame.headers) do
    local visible = not ns.db.myLevelOnly or h.set <= level
    h:SetShown(visible)
    h.body:SetShown(visible)
    if visible then
      h:SetPoint("TOPLEFT", 0, -y)
      y = y + HEADER_H + 2
      local inner = 0
      for _, row in ipairs(h.rows) do
        local show = not (ns.db.hideCollected and ns.IsDone(row.book))
        row:SetShown(show)
        if show then
          row:SetPoint("TOPLEFT", 0, -inner)
          inner = inner + ROW_H
        end
      end
      local p = h.foldShown()
      h.body:SetPoint("TOPLEFT", 0, -y)
      h.body:SetHeight(math.max(0.01, inner * p))
      h.body:SetAlpha(p)
      if p < 0.01 then h.body:Hide() end
      y = y + inner * p + 8
    end
  end
  frame.content:SetHeight(math.max(y, 1))
end

function ns.RefreshOptions()
  if not frame or not frame:IsShown() then return end
  local done = ns.CountDone()

  frame.bar:SetValue(math.min(done, GOAL_25))
  frame.barText:SetText(L["%d / %d books"]:format(done, #BOOKS))
  for _, t in ipairs({ { frame.necklace, GOAL_NECKLACE }, { frame.ring, GOAL_RING }, { frame.goal25, GOAL_25 } }) do
    t[1]:SetTextColor(S.Color(done >= t[2] and S.C.good or S.C.muted))
  end

  frame.showAll:SetChecked(not ns.db.hidden)
  frame.size:SetValue(ns.db.pinSize or ns.DEFAULT_PIN_SIZE)
  frame.showMinimap:SetChecked(not ns.db.hideMinimapPins)
  frame.showButton:SetChecked(not ns.db.hideMinimap)
  frame.toasts:SetChecked(not ns.db.noToasts)
  frame.minimapSize:SetValue(ns.db.minimapPinSize or ns.DEFAULT_MINIMAP_PIN_SIZE)
  frame.lang.Refresh()

  for _, h in ipairs(frame.headers) do
    local n, total = 0, 0
    for _, b in ipairs(BOOKS) do
      if b.set == h.set then
        total = total + 1
        if ns.IsDone(b) then n = n + 1 end
      end
    end
    h.count:SetText(("%d / %d"):format(n, total))
  end

  frame.hideDone:SetChecked(ns.db.hideCollected)
  frame.myLevel:SetChecked(ns.db.myLevelOnly)
  frame.groupBooks:SetChecked(not ns.db.hideGroupBooks)

  layoutList()

  for _, row in ipairs(frame.rows) do
    local isDone = ns.IsDone(row.book)
    row.check:SetChecked(isDone)
    row.icon:SetDesaturated(isDone)
    row.icon:SetAlpha(isDone and 0.5 or 1)
    row.name:SetTextColor(S.Color(isDone and S.C.muted or S.C.text))
  end
  ns.RefreshRewards()
  ns.RefreshGroupPanel()
end

-- Rows -------------------------------------------------------------------
local function rowTooltip(self)
  local b = self.book
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(b.name, 1, 0.82, 0)
  for _, loc in ipairs(b.locs) do
    GameTooltip:AddLine(("%s (%.1f, %.1f)"):format(loc[4], loc[2], loc[3]), 1, 1, 1, true)
  end
  ns.AddGroupTooltip(b)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Click: open the map there"], 0.5, 1, 0.5)
  local hint = b.locs[1] and ns.WaypointHint()
  if hint then GameTooltip:AddLine(hint, 0.5, 1, 0.5) end
  GameTooltip:Show()
end

local function createRow(parent, b, y, width)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, ROW_H)
  row:SetPoint("TOPLEFT", 0, -y)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.book = b

  local icon = S.Icon(row, 26)
  icon:SetPoint("LEFT", 8, 0)
  icon.tex:SetTexture(iconPath(b))
  row.icon = icon.tex

  row.check = S.Check(row, nil, 16)
  row.check:SetPoint("RIGHT", -10, 0)
  row.check:SetScript("OnClick", function(self) ns.SetDone(b, self:GetChecked(), true) end)
  row.check:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Collected (hidden from the map)"])
    GameTooltip:Show()
  end)
  row.check:HookScript("OnLeave", function() GameTooltip:Hide() end)

  row.name = S.Text(row, 13)
  row.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, 0)
  row.name:SetPoint("RIGHT", row.check, "LEFT", -8, 0)
  row.name:SetWordWrap(false)
  row.name:SetText(b.name)

  local l = b.locs[1]
  row.where = S.Text(row, 11, "muted")
  row.where:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 9, 0)
  row.where:SetPoint("RIGHT", row.check, "LEFT", -8, 0)
  row.where:SetWordWrap(false)
  row.where:SetText(l and ("%s  |cff56647d%.1f, %.1f|r"):format(l[4], l[2], l[3]) or L["location unknown"])

  row:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      ns.Waypoint(l, b.name)
    elseif l then
      if not WorldMapFrame:IsShown() then ToggleWorldMap() end
      WorldMapFrame:SetMapID(l[1])
    end
  end)
  row:SetScript("OnEnter", rowTooltip)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  S.RowHighlight(row)
  return row
end

local function createHeader(parent, set, y, width)
  local h = CreateFrame("Frame", nil, parent)
  h:SetSize(width, HEADER_H)
  h:SetPoint("TOPLEFT", 0, -y)
  h.set = set.id
  local wash = h:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  S.Gradient(wash, { 0.30, 0.55, 0.88, 0.22 }, { 0.30, 0.55, 0.88, 0 }, true)
  local line = h:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
  S.Gradient(line, { 0.30, 0.55, 0.88, 0.8 }, { 0.30, 0.55, 0.88, 0 }, true)

  local accent = h:CreateTexture(nil, "ARTWORK")
  accent:SetPoint("TOPLEFT"); accent:SetPoint("BOTTOMLEFT"); accent:SetWidth(2)
  accent:SetColorTexture(S.Color(S.C.accent))

  h.label = S.Text(h, 13, "accent", "extrabold")
  h.label:SetPoint("LEFT", 10, 0)
  h.label:SetText(L[set.label])

  h.count = S.Text(h, 11, "muted")
  h.count:SetPoint("RIGHT", -10, 0)

  -- the set's books live in a clipped body that folds with the header
  h.body = CreateFrame("Frame", nil, parent)
  h.body:SetWidth(width)
  if h.body.SetClipsChildren then pcall(h.body.SetClipsChildren, h.body, true) end
  h.rows = {}
  ns.db.foldedSets = ns.db.foldedSets or {}
  S.Foldable(h, function() return not ns.db.foldedSets[set.id] end,
    function(open) ns.db.foldedSets[set.id] = not open or nil end,
    function() if frame and frame.headers then layoutList() end end, h.count)
  return h
end

-- Window -----------------------------------------------------------------
local PAD = 16

local function create()
  local f = S.Window("BooksOnMapForeverOptions", UIParent, WIDTH, HEIGHT, "Books on map")
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  S.Draggable(f, f.titleBar)
  tinsert(UISpecialFrames, f:GetName()) -- close with Escape

  -- Title bar: addon icon, title, version, language
  local logo = f.titleBar:CreateTexture(nil, "ARTWORK")
  logo:SetSize(20, 20)
  logo:SetPoint("LEFT", 10, 0)
  logo:SetTexture(ns.ADDON_ICON)
  f.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)

  local forever = S.Text(f.titleBar, 15, "accent")
  forever:SetPoint("LEFT", f.title, "RIGHT", 5, 0)
  forever:SetText("Forever")

  local version = S.Text(f.titleBar, 11, "muted")
  version:SetPoint("BOTTOMLEFT", forever, "BOTTOMRIGHT", 6, 1)
  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  version:SetText("v" .. (getMeta(ADDON, "Version") or "?"))

  f.lang = ns.LanguageSelector(f.titleBar)
  f.lang:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
  local bug = ns.BugButton(f.titleBar)
  bug:SetPoint("RIGHT", f.lang, "LEFT", -6, 0)

  -- Progress (toward the 25-book reward)
  local progress = S.Section(f, L["Progress"])
  progress:SetPoint("TOPLEFT", PAD, -48)
  progress:SetPoint("TOPRIGHT", -PAD, -48)
  f.barText = progress.right

  f.bar = S.ProgressBar(f, 12)
  f.bar:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -10)
  f.bar:SetPoint("TOPRIGHT", progress, "BOTTOMRIGHT", 0, -10)
  f.bar:SetMinMaxValues(0, GOAL_25)
  -- markers at the necklace and ring goals
  for _, goal in ipairs({ GOAL_NECKLACE, GOAL_RING }) do
    local mark = f.bar:CreateTexture(nil, "OVERLAY")
    mark:SetSize(2, 12)
    mark:SetColorTexture(S.Color(S.C.bg))
    mark:SetPoint("LEFT", f.bar, "LEFT", (WIDTH - 2 * PAD) * goal / GOAL_25 - 1, 0)
  end

  f.necklace = S.Text(f, 11)
  f.necklace:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -6)
  f.necklace:SetText(L["10 books: necklace"])
  f.ring = S.Text(f, 11)
  f.ring:SetPoint("TOP", f.bar, "BOTTOM", 0, -6)
  f.ring:SetText(L["20 books: ring"])
  f.goal25 = S.Text(f, 11)
  f.goal25:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", 0, -6)
  f.goal25:SetJustifyH("RIGHT")
  f.goal25:SetText(L["25 books: bow, crest or light"])

  -- Settings: show icons + icon size (world map, then minimap)
  local settings = S.Section(f, L["Settings"])
  settings:SetPoint("TOPLEFT", PAD, -116)
  settings:SetPoint("TOPRIGHT", -PAD, -116)

  -- folding: each section body slides closed, the book list takes the room
  ns.db.folded = ns.db.folded or {}
  local function section(key, header, height)
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    S.Collapsible(header, body, height,
      function() return not ns.db.folded[key] end,
      function(open) ns.db.folded[key] = not open or nil end)
    return body
  end
  local settingsBody = section("settings", settings, 124)

  local function settingCheck(label, y, onClick)
    local c = S.Check(settingsBody, label)
    c:SetPoint("TOPLEFT", 0, y)
    c:SetScript("OnClick", onClick)
    return c
  end

  local function sizeSlider(y, min, max, label, key, default, refresh)
    local s = S.Slider(settingsBody, 170, min, max, L[label], function(value)
      if ns.db[key] ~= value then
        ns.db[key] = value
        refresh()
      end
    end)
    s:SetPoint("TOPRIGHT", 0, y)
    s.value:SetText(ns.db[key] or default)
    return s
  end

  f.showAll = settingCheck(L["Show on the map"], -14, function(self)
    ns.db.hidden = not self:GetChecked(); ns.Refresh()
  end)
  f.size = sizeSlider(-26, 10, 40, "Map icon size: %d", "pinSize", ns.DEFAULT_PIN_SIZE, ns.RefreshMap)

  f.showMinimap = settingCheck(L["Show books on the minimap"], -52, function(self)
    ns.db.hideMinimapPins = not self:GetChecked() or nil; ns.RefreshMinimapPins()
  end)
  f.minimapSize = sizeSlider(-64, 8, 30, "Minimap icon size: %d", "minimapPinSize", ns.DEFAULT_MINIMAP_PIN_SIZE, ns.RefreshMinimapPins)
  f.showButton = settingCheck(L["Show the minimap button"], -78, function(self)
    ns.db.hideMinimap = not self:GetChecked() or nil; ns.UpdateMinimapButton()
  end)
  f.toasts = settingCheck(L["Notify when a book is collected"], -102, function(self)
    ns.db.noToasts = not self:GetChecked() or nil
  end)

  -- Filters
  local filters = S.Section(f, L["Filters"])
  filters:SetPoint("TOPLEFT", settingsBody, "BOTTOMLEFT", 0, -8)
  filters:SetPoint("TOPRIGHT", settingsBody, "BOTTOMRIGHT", 0, -8)
  local filtersBody = section("filters", filters, 58)

  local function filterCheck(label, key, x, y)
    local c = S.Check(filtersBody, label)
    c:SetPoint("TOPLEFT", x, y)
    c:SetScript("OnClick", function(self) ns.db[key] = self:GetChecked() or nil; ns.RefreshOptions() end)
    return c
  end
  f.hideDone = filterCheck(L["Hide collected books"], "hideCollected", 0, -10)
  f.myLevel = filterCheck(L["Only sets for my level"], "myLevelOnly", WIDTH / 2 - PAD, -10)
  f.groupBooks = filterCheck(L["Also show the books my group is missing"], "hideGroupBooks", 0, -34)
  f.groupBooks:SetScript("OnClick", function(self)
    ns.db.hideGroupBooks = not self:GetChecked() or nil; ns.Refresh()
  end)

  -- Book list (scrollable), right under the filters: grows when sections are folded
  local listBg = CreateFrame("Frame", nil, f)
  listBg:SetPoint("TOPLEFT", filtersBody, "BOTTOMLEFT", 0, -8)
  listBg:SetPoint("BOTTOMRIGHT", -PAD, 54)
  S.Box(listBg, { 0, 0, 0, 0.35 }, S.C.rule)

  local scroll, content = S.Scroll(listBg)
  scroll:SetPoint("TOPLEFT", 1, -1)
  scroll:SetPoint("BOTTOMRIGHT", -12, 1)

  local contentWidth = WIDTH - 2 * PAD - 13
  content:SetWidth(contentWidth)
  f.content = content

  -- positions are set by RefreshOptions (filters)
  f.headers, f.rows = {}, {}
  for _, set in ipairs(SETS) do
    local h = createHeader(content, set, 0, contentWidth)
    f.headers[#f.headers + 1] = h
    for _, b in ipairs(BOOKS) do
      if b.set == set.id then
        local row = createRow(h.body, b, 0, contentWidth)
        f.rows[#f.rows + 1] = row
        h.rows[#h.rows + 1] = row
      end
    end
  end

  -- Footer
  local showBtn = S.Button(f, L["Show all"], 120, 26, function() ns.SetAll(false) end)
  showBtn:SetPoint("BOTTOMLEFT", PAD, 14)
  local hideBtn = S.Button(f, L["Hide all"], 120, 26, function() ns.SetAll(true) end)
  hideBtn:SetPoint("LEFT", showBtn, "RIGHT", 8, 0)
  local routeBtn = S.Button(f, L["Optimized route"], 150, 26, function() ns.ToggleRoute() end, true)
  routeBtn:SetPoint("BOTTOMRIGHT", -PAD, 14)

  ns.CreateRewardsTab(f)
  ns.CreateGroupTab(f)

  f:HookScript("OnShow", ns.RefreshOptions)
  f:Hide()
  return f
end

function ns.ToggleOptions()
  frame = frame or create()
  if frame:IsShown() then S.Close(frame) else frame:Show() end
end
