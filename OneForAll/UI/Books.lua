local _, FLT = ...
local UI = FLT.UI
local makeTexture, makeButton = UI.makeTexture, UI.makeButton
local unpack = unpack or table.unpack

-- Re-positions the book sections; assigned in createBooksPanel and used by
-- the collapse buttons of the section headers.
local relayout

local STATE = {
  done={text="Turned in", color={0.45,0.85,0.45}},
  manual={text="Manual", color={0.72,0.58,0.90}},
  bag={text="Bag", color={0.92,0.78,0.35}},
  bank={text="Bank", color={0.45,0.68,0.92}},
  questflag={text="Quest flagged", color={0.92,0.58,0.28}},
  missing={text="Missing", color={0.55,0.53,0.50}},
}
local TERRITORY = {
  Alliance={text="Alliance", short="A", color={0.30,0.62,1.00}},
  Horde={text="Horde", short="H", color={1.00,0.28,0.23}},
  Contested={text="Contested", short="C", color={1.00,0.74,0.18}},
}


local function showBookTooltip(row, book)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(book.name, 1, 0.82, 0)
  GameTooltip:AddLine((book.zone or "?") .. (book.subzone and (" - " .. book.subzone) or ""), 0.84, 0.84, 0.84)

  local territory = FLT:GetTerritory(book.zone)
  local t = TERRITORY[territory] or TERRITORY.Contested
  GameTooltip:AddLine("Territory: " .. t.text, unpack(t.color))

  if book.x then GameTooltip:AddLine(string.format("Coordinates: %.1f, %.1f", book.x, book.y), 0.95, 0.88, 0.40) end
  GameTooltip:AddLine("Object: " .. (book.container or "Unknown"), 0.65, 0.85, 1)
  if book.note then GameTooltip:AddLine(book.note, 1, 0.82, 0, true) end

  if book.status == "unknown" then GameTooltip:AddLine("Location status: unconfirmed", 1, 0.35, 0.2)
  elseif book.status == "not-in-forever" then GameTooltip:AddLine("Location status: currently unavailable", 1, 0.35, 0.2)
  elseif book.status == "reported" then GameTooltip:AddLine("Location status: player report", 1, 0.75, 0.2)
  elseif book.status == "confirmed" then GameTooltip:AddLine("Location status: confirmed in Forever beta", 0.2, 1, 0.2)
  elseif book.status == "wowhead" then GameTooltip:AddLine("Location status: database location", 0.65, 0.85, 1) end

  GameTooltip:AddLine(" ")
  local apiDone = FLT:IsQuestDone(book.questId)
  GameTooltip:AddLine(string.format("Quest ID: %d   Item ID: %d", book.questId or 0, book.itemId or 0), 0.65, 0.65, 0.65)
  GameTooltip:AddLine("Server completion flag: " .. (apiDone and "true" or "false"), apiDone and 1 or 0.65, apiDone and 0.55 or 0.65, apiDone and 0.15 or 0.65)
  if apiDone and not OneForAllCharDB.confirmedDone[book.itemId] then
    GameTooltip:AddLine("Unverified: the server reports this quest completed, but this addon did not observe the turn-in.", 1, 0.55, 0.15, true)
  end
  GameTooltip:AddLine("Right-click: toggle a manual ownership/completion note", 0.7, 0.7, 0.7, true)
  GameTooltip:Show()
end

local bookRewardsPopup
local function showBookRewardsPopup(frame)
  if not frame then return end
  if not bookRewardsPopup then
    local p = CreateFrame("Frame", "OneForAllLibraryInfoPopup", frame)
    bookRewardsPopup = p
    p:SetSize(640, 500)
    p:SetPoint("CENTER", frame, "CENTER", 0, 8)
    p:SetFrameStrata("DIALOG")
    p:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
    p:EnableMouse(true)
    -- movable like the other popups; same panel and frame as they have
    p:SetMovable(true); p:SetClampedToScreen(true); p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving); p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p._ofaNoBG = true -- keeps its background when the window opacity is turned down
    UI.FramedPanel(p)
    for _, t in ipairs(UI.OrnateFrame(p, p, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end

    local iconBG = CreateFrame("Frame", nil, p); iconBG:SetSize(48,48); iconBG:SetPoint("TOPLEFT",18,-16)
    local ibg=makeTexture(iconBG,"BACKGROUND",0.13,0.09,0.03,1); ibg:SetAllPoints()
    local icon=iconBG:CreateTexture(nil,"ARTWORK"); icon:SetPoint("TOPLEFT",4,-4); icon:SetPoint("BOTTOMRIGHT",-4,4); FLT.SetTex(icon, "Interface\\Icons\\INV_Misc_Book_09")
    local ib=iconBG:CreateTexture(nil,"OVERLAY"); ib:SetAllPoints(); FLT.SetTex(ib, "Interface\\Buttons\\UI-Quickslot2"); ib:SetVertexColor(FLT.SkinC(0.9,0.65,0.2,1))

    local title=FLT.NewFS(p, nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",78,-18); title:SetText("Library Books"); title:SetTextColor(FLT.SkinC(1,0.82,0.20))
    local sub=FLT.NewFS(p, nil,"OVERLAY","GameFontHighlightSmall"); sub:SetPoint("TOPLEFT",78,-43); sub:SetText("Turn-ins, rewards and librarian locations"); sub:SetTextColor(FLT.SkinC(0.78,0.76,0.70))
    local line=makeTexture(p,"ARTWORK",0.72,0.50,0.12,0.52); line:SetPoint("TOPLEFT",18,-78); line:SetPoint("TOPRIGHT",-18,-78); line:SetHeight(1)

    local body=FLT.NewFS(p, nil,"OVERLAY","GameFontHighlightSmall"); body:SetPoint("TOPLEFT",24,-90); body:SetPoint("TOPRIGHT",-24,-90); body:SetJustifyH("LEFT"); body:SetJustifyV("TOP"); body:SetSpacing(3)
    body:SetText(FLT.SkinHex("ffd35a") .. "Turn in:|r  Alliance: Garion Wendell, Stormwind Mage Quarter (37.6, 80.8)   |   Horde: Owen Thadd, Undercity Magic Quarter (73.4, 33.0)\nEvery different book is its own turn-in. Each reward tier is a separate quest at the librarian - pick one item per tier. Mages can also unlock Research Access / Study.")
    body:SetTextColor(FLT.SkinC(0.86,0.84,0.78))

    local H=FLT.UI.DungeonHelpers
    local y=-90-math.max(40,(body:GetStringHeight() or 40))-16
    for _,tier in ipairs(FLT.BOOK_REWARD_TIERS or {}) do
      local head=FLT.NewFS(p, nil,"OVERLAY","GameFontNormal"); head:SetPoint("TOPLEFT",24,y)
      head:SetText(string.format("%s  |cffbbbbbb- %s%s|r", tier.books, tier.quest, (tier.req and tier.req>1) and (", requires level "..tier.req) or ""))
      head:SetTextColor(FLT.SkinC(1,0.82,0.20))
      y=y-22
      local x=24
      for _,it in ipairs(tier.items) do
        local rec={id=it[1],name=it[2],quality=it[3]}
        local b=CreateFrame("Button",nil,p); b:SetSize(190,40); b:SetPoint("TOPLEFT",x,y); x=x+196
        local bg=makeTexture(b,"BACKGROUND",0.07,0.06,0.045,0.95); bg:SetAllPoints()
        local hi=makeTexture(b,"HIGHLIGHT",0.55,0.36,0.10,0.22); hi:SetAllPoints()
        local ic=b:CreateTexture(nil,"ARTWORK"); ic:SetSize(30,30); ic:SetPoint("LEFT",5,0)
        FLT.SetTex(ic, (H and H.dungeonItemIcon and H.dungeonItemIcon(rec)) or "Interface\\Icons\\INV_Misc_QuestionMark")
        local n=FLT.NewFS(b, nil,"OVERLAY","GameFontNormalSmall"); n:SetPoint("TOPLEFT",40,-5); n:SetWidth(146); n:SetJustifyH("LEFT"); n:SetText(it[2])
        if H and H.colorDungeonItemText then H.colorDungeonItemText(n,rec,0.12,1,0) end
        p.itemTexts=p.itemTexts or {}; p.itemTexts[#p.itemTexts+1]={n,rec}
        local d=FLT.NewFS(b, nil,"OVERLAY","GameFontDisableSmall"); d:SetPoint("TOPLEFT",40,-21); d:SetWidth(146); d:SetJustifyH("LEFT"); d:SetWordWrap(false); d:SetText(it[4] or "")
        b:SetScript("OnEnter",function(self)
          if H and H.colorDungeonItemText then H.colorDungeonItemText(n,rec,0.12,1,0) end
          if not (H and H.tryShowItemTooltip and H.tryShowItemTooltip(self,rec)) then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(it[2],0.25,0.55,1); GameTooltip:AddLine(it[4] or "",1,1,1); GameTooltip:Show()
          end
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b:SetScript("OnClick",function(_,button) if H and H.handleDungeonItemClick then H.handleDungeonItemClick(rec,button) end end)
      end
      y=y-52
    end
    local note=FLT.NewFS(p, nil,"OVERLAY","GameFontDisableSmall"); note:SetPoint("TOPLEFT",24,y-2); note:SetPoint("RIGHT",-24,0); note:SetJustifyH("LEFT")
    note:SetText("The book count for the third tier is not confirmed yet. WoW Forever is still in beta, so rewards may change. Ctrl-click an item to try it on.")

    local okay=UI.GoldButton(p,"Okay",120,26,nil,13); okay:SetPoint("BOTTOM",0,18); okay:SetScript("OnClick",function() p:Hide() end)
    local close=UI.CloseButton(p); close:SetPoint("TOPRIGHT",-10,-10)
    p:SetScript("OnHide",function() GameTooltip:Hide() end)
    p:Hide()
  end
  -- item quality may only be known now (client cache)
  local H=FLT.UI.DungeonHelpers
  for _,e in ipairs(bookRewardsPopup.itemTexts or {}) do if H and H.colorDungeonItemText then H.colorDungeonItemText(e[1],e[2],0.12,1,0) end end
  bookRewardsPopup:ClearAllPoints(); bookRewardsPopup:SetPoint("CENTER", frame, "CENTER", 0, 8)
  bookRewardsPopup:Show()
end


local function createBooksPanel(frame)
  local panel = CreateFrame("Frame", nil, frame)
  UI.PlacePanel(panel, frame)
  local W = UI.CONTENT_W - 174 -- ht8: right of the side list
  local Card = UI.Card
  local rows, sections, progress, nearbyCheck = {}, {}, nil, nil

  -- Title band with the library emblem and the tab's banner art.
  local band = UI.TitleBand(panel, {
    emblem = UI.ASSET_ROOT .. "emblem_books", art = UI.ASSET_ROOT .. "books_banner",
    title = "Library Books", subtitle = "Status from observed turn-ins, your bags and the last scanned bank. Right-click a book for a manual note.",
    fadeRight = 320,
  })
  progress = FLT.NewFS(band, nil, "OVERLAY", "GameFontNormal")
  progress:SetPoint("RIGHT", -18, 8); progress:SetJustifyH("RIGHT"); progress:SetTextColor(FLT.SkinC(1, 0.86, 0.40))
  local progress2 = FLT.NewFS(band, nil, "OVERLAY", "GameFontHighlightSmall")
  progress2:SetPoint("TOPRIGHT", progress, "BOTTOMRIGHT", 0, -4); progress2:SetJustifyH("RIGHT"); progress2:SetTextColor(FLT.SkinC(0.84, 0.81, 0.74))
  -- header test: the band is gone - both counts go into the action row, right of the rewards button (placed below)
  progress:SetParent(panel); progress2:SetParent(panel)

  -- Action row: rewards button, nearby alerts and a colour legend.
  -- ht8 (user 30.10.): the side list like every tab - the counts, "What can I do?", the sets to jump to, the legend
  local nav, ny = UI.SideNav(panel, -74, "emblem_books", "Library Books")
  progress:SetParent(nav); progress2:SetParent(nav)
  progress:ClearAllPoints(); progress:SetPoint("TOPLEFT", UI.NAV.entryX + 8, ny); progress:SetJustifyH("LEFT")
  do local font, _, flags = progress:GetFont(); if font then progress:SetFont(font, 12, flags) end end
  progress2:ClearAllPoints(); progress2:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -4); progress2:SetJustifyH("LEFT")
  ny = ny - 40
  local reward; reward, ny = UI.NavEntry(nav, ny, "What can I do?", "Interface\\Icons\\INV_Misc_Book_09")
  reward:SetScript("OnClick", function() showBookRewardsPopup(frame) end)
  reward:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("What can I do with the books?", 1, 0.82, 0); GameTooltip:Show() end)
  reward:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ny = UI.NavSeparator(nav, ny)
  local setJump = {} -- filled when the sets exist (below)
  local navY = ny

  -- the "Nearby book alerts" option lives in the Settings tab
  -- small gem: tinted stone inside a gold rim
  local function gem(parent, size)
    local f = parent:CreateTexture(nil, "ARTWORK", nil, 1); f:SetSize(size, size); FLT.SetTex(f, UI.ASSET_ROOT .. "gem_fill")
    local r = parent:CreateTexture(nil, "ARTWORK", nil, 2); r:SetAllPoints(f); FLT.SetTex(r, UI.ASSET_ROOT .. "gem_rim")
    return f
  end
  local legendKeys = { "done", "bag", "bank", "manual", "questflag", "missing" }
  local legendHolds = {} -- ht8: the legend at the bottom of the side list (placed once the sets are listed)
  for i = 1, #legendKeys do
    local st = STATE[legendKeys[i]]
    local hold = CreateFrame("Frame", nil, nav)
    local d = gem(hold, 12); d:SetPoint("LEFT", 0, 0); d:SetVertexColor(unpack(st.color))
    local t = FLT.NewFS(hold, nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", d, "RIGHT", 6, 0); t:SetText(st.text); t:SetTextColor(FLT.SkinC(0.84, 0.81, 0.74))
    hold:SetSize(140, 18)
    legendHolds[i] = hold
    if legendKeys[i] == "questflag" then
      hold:EnableMouse(true)
      hold:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Quest flagged", 1, 0.55, 0.15)
        GameTooltip:AddLine("The server says this book quest is completed, but this addon did not see the turn-in. Use /ofa debug for IDs.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      hold:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end

  -- Columns (x inside a row; rows sit BOX_PAD px inside their box).
  local SECTION_H, ROW_H, ROW_GAP, BOX_PAD = 32, 34, 0, 0
  local ROW_INNER = W - 2 * BOX_PAD
  local COL = { status = 14, name = 130, side = 440, zone = 510, actions = 712 }
  local COL_W = { status = 110, name = 300, side = 60, zone = 190, actions = 92 }
  local colHead = UI.ColumnHeader(panel, {
    { x = COL.status + BOX_PAD - 6, w = COL_W.status, text = "Status" },
    { x = COL.name + BOX_PAD - 4, w = COL_W.name, text = "Book Title" },
    { x = COL.side + BOX_PAD, w = COL_W.side, text = "Territory", justify = "CENTER" },
    { x = COL.zone + BOX_PAD, w = COL_W.zone, text = "Zone / Coordinates" },
    { x = COL.actions + BOX_PAD, w = COL_W.actions, text = "Actions", justify = "CENTER" },
  }, W, -74)
  colHead:ClearAllPoints(); colHead:SetPoint("TOPLEFT", 182, -74)

  local bookScroll = FLT.SkinBlizz(CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate"))
  bookScroll:SetPoint("TOPLEFT", 182, -104); bookScroll:SetPoint("BOTTOMRIGHT", -8, 4)
  UI.PlaceScrollBar(bookScroll)
  local content = CreateFrame("Frame", nil, bookScroll); content:SetSize(W, 1); bookScroll:SetScrollChild(content)

  OneForAllDB.collapsedSets = OneForAllDB.collapsedSets or {}
  local CREST_TC = { Alliance = {0, 0.25}, Horde = {0.25, 0.5}, Contested = {0.5, 0.75} }
  local ROW_BORDER, ROW_BORDER_HI = {0.28, 0.25, 0.20, 0.90}, {0.86, 0.66, 0.26, 1}

  local lastSet, current
  for _, book in ipairs(FLT.BOOKS) do
    if lastSet ~= book.set then
      local setId = book.set
      current = UI.SectionBand(content, FLT.SETS[book.set] or book.set, #sections, W, function()
        OneForAllDB.collapsedSets[setId] = not OneForAllDB.collapsedSets[setId] or nil
        if relayout then relayout() end
      end)
      current.id = setId; current.rows = {}
      sections[#sections + 1] = current
      lastSet = book.set
    end

    local row = CreateFrame("Button", nil, content)
    row:SetSize(ROW_INNER, ROW_H)
    row.book = book
    local card = UI.QuietRow(row) -- ht8: no frame, a fine line under the row
    row.card = card

    local dot = gem(row, 13); dot:SetPoint("LEFT", COL.status - 1, 0)
    row.statusDot = dot
    local status = FLT.NewFS(row, nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("LEFT", COL.status + 18, 0); status:SetWidth(COL_W.status - 20); status:SetJustifyH("LEFT")
    row.statusText = status

    local name = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", COL.name, 0); name:SetWidth(COL_W.name); name:SetJustifyH("LEFT"); name:SetText(book.name)
    if name.SetWordWrap then name:SetWordWrap(false) end
    name:SetTextColor(FLT.SkinC(0.95, 0.93, 0.88))

    local crest = row:CreateTexture(nil, "ARTWORK"); crest:SetSize(24, 24); crest:SetPoint("CENTER", row, "LEFT", COL.side + COL_W.side / 2, 0)
    FLT.SetTex(crest, UI.ASSET_ROOT .. "faction_crests")
    row.crest = crest

    local zone = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlightSmall")
    zone:SetPoint("LEFT", COL.zone + 10, 0); zone:SetWidth(COL_W.zone - 10); zone:SetJustifyH("LEFT")
    zone:SetText(book.x and string.format("%s  |cff9d9480%.1f, %.1f|r", book.zone, book.x, book.y) or (book.zone .. "  |cff9d9480?|r"))
    zone:SetTextColor(FLT.SkinC(0.90, 0.88, 0.84))

    local map = UI.GoldButton(row, "Map", 74, 22, UI.ASSET_ROOT .. "icon_map", 12)
    map:SetPoint("CENTER", row, "LEFT", COL.actions + COL_W.actions / 2, 0)
    if book.x then
      map:SetScript("OnClick", function() FLT:ShowOnMap(book) end)
    else
      map:Disable(); map:SetLook(false)
    end

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(_, button)
      if button == "RightButton" then
        OneForAllCharDB.manualDone[book.itemId] = not OneForAllCharDB.manualDone[book.itemId] or nil
        FLT:Refresh()
      end
    end)
    row:SetScript("OnEnter", function() card:SetBorder(unpack(ROW_BORDER_HI)); showBookTooltip(row, book) end)
    row:SetScript("OnLeave", function() card:SetBorder(unpack(ROW_BORDER)); GameTooltip:Hide() end)
    rows[#rows + 1] = row
    current.rows[#current.rows + 1] = row
  end

  -- the sets in the side list (jump to them), then the legend under them
  for i, section in ipairs(sections) do
    local b; b, navY = UI.NavEntry(nav, navY, FLT.SETS[section.id] or section.id)
    b.count = FLT.NewFS(b, nil, "OVERLAY", "GameFontDisableSmall"); b.count:SetPoint("RIGHT", -5, 0)
    do local font, _, flags = b.count:GetFont(); if font then b.count:SetFont(font, 10, flags) end end
    b._label:SetPoint("RIGHT", b.count, "LEFT", -4, 0); b._label:SetWordWrap(false)
    b:SetScript("OnClick", function()
      if OneForAllDB.collapsedSets[section.id] then OneForAllDB.collapsedSets[section.id] = nil; relayout() end
      if section.y then
        local range = bookScroll:GetVerticalScrollRange() or 0
        bookScroll:SetVerticalScroll(math.max(0, math.min(range, -section.y - 4)))
      end
    end)
    setJump[i] = b; section.nav = b
  end
  navY = UI.NavSeparator(nav, navY)
  for i, hold in ipairs(legendHolds) do hold:SetPoint("TOPLEFT", nav, "TOPLEFT", UI.NAV.entryX + 8, navY - 4 - (i - 1) * 20) end

  relayout = function()
    local y = -4
    for i, section in ipairs(sections) do
      if i > 1 then y = y - 10 end
      section.header:ClearAllPoints(); section.header:SetPoint("TOPLEFT", 0, y); section.header:Show(); section.y = y
      y = y - SECTION_H - 3
      local collapsed = OneForAllDB.collapsedSets and OneForAllDB.collapsedSets[section.id]
      section:SetCollapsed(collapsed)
      if collapsed then
        section.box:Hide()
        for _, row in ipairs(section.rows) do row:Hide() end
      else
        local n = #section.rows
        local h = BOX_PAD * 2 + n * ROW_H + (n - 1) * ROW_GAP
        section.box:ClearAllPoints(); section.box:SetPoint("TOPLEFT", 0, y); section.box:SetHeight(h); section.box:Show()
        local ry = y - BOX_PAD
        for _, row in ipairs(section.rows) do
          row:ClearAllPoints(); row:SetPoint("TOPLEFT", BOX_PAD, ry); row:Show()
          ry = ry - ROW_H - ROW_GAP
        end
        y = y - h
      end
    end
    content:SetHeight(math.max(1, -y + 10))
  end

  function panel:Refresh()
    local done, owned = FLT:GetCounts()
    progress:SetText(string.format("Turned in  %d / %d", done, #FLT.BOOKS))
    progress2:SetText(string.format("Owned or turned in  %d / %d", owned, #FLT.BOOKS))
    local perSet = {}
    for _, row in ipairs(rows) do
      local st = FLT:GetBookState(row.book)
      local s = STATE[st] or STATE.missing
      row.statusText:SetText(s.text); row.statusText:SetTextColor(unpack(s.color))
      row.statusDot:SetVertexColor(unpack(s.color))
      local territory = FLT:GetTerritory(row.book.zone)
      local tc = CREST_TC[territory] or CREST_TC.Contested
      row.crest:SetTexCoord(tc[1], tc[2], 0, 1)
      local c = perSet[row.book.set] or { done = 0, n = 0 }; perSet[row.book.set] = c
      c.n = c.n + 1; if st == "done" then c.done = c.done + 1 end
    end
    for _, section in ipairs(sections) do
      local c = perSet[section.id] or { done = 0, n = #section.rows }
      section.info:SetText(string.format("%d / %d turned in", c.done, c.n))
      if section.nav then section.nav.count:SetText(c.done .. "/" .. c.n) end
    end
  end

  -- from the world map (MapLandmarks.lua, 5.7.3): open the book's set, scroll to it and light it up for a moment
  UI.ShowBook = function(book)
    for _, row in ipairs(rows) do
      if row.book == book then
        if OneForAllDB.collapsedSets[book.set] then OneForAllDB.collapsedSets[book.set] = nil; relayout() end
        C_Timer.After(0, function() -- positions are known one frame later
          local top, rt = content:GetTop(), row:GetTop()
          if top and rt then
            local range = bookScroll:GetVerticalScrollRange() or 0
            bookScroll:SetVerticalScroll(math.max(0, math.min(range, top - rt - 40)))
          end
          row.card:SetBorder(unpack(ROW_BORDER_HI))
          C_Timer.After(2, function() if not row:IsMouseOver() then row.card:SetBorder(unpack(ROW_BORDER)) end end)
        end)
        return
      end
    end
  end

  relayout()
  panel:Hide()
  return panel
end

UI.RegisterPanel({ key="books", label="Library Books", order=6, tabWidth=132, create=createBooksPanel })
