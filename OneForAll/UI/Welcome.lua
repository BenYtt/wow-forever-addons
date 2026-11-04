local _, FLT = ...
local UI = FLT.UI

-- Welcome setup (5.7.3, user 27.10.): shown once (WELCOME_ID) - a small setup over a few pages to switch on Quality of
-- Life helpers right away. It can be skipped (everything is in the Quality of Life tab); "Recommended settings" ticks
-- what OneForAll has on by default. /ofa setup and Settings > Window open it again. Built only when shown.

local WELCOME_ID = "6.0.0" -- shown once to everyone with 6.0.0, also to those who saw a 5.7.3 beta (user 27.10.)
-- Blizzard's own "World of Warcraft Forever" logo from the game client (not shipped with the addon)
local FOREVER_LOGO = 8205333 -- interface/glues/common/glues-wow-foreverlogo.blp

local Q = FLT.QoL
local function db() return type(OneForAllDB) == "table" and OneForAllDB or {} end
local function qset(k) return function(v) Q.Set(k, v) end end
local function qget(k) return function() return Q.Get(k) and true or false end end
local function cvar(k) return function() return Q.GetCVarSwitch(k) end, function(v) Q.SetCVarSwitch(k, v) end end

-- one row = { label, short text, key (QoL) or get + set, rec = recommended (ticked by "Recommended settings"),
-- sub = indented under the row before, kind = "logo" / "font" for the two special rows }
local PAGES = {
  { "Interface", {
    { "Farther camera zoom", "Lets you zoom the camera out further.", "cameraZoom", rec = true },
    { "Move Blizzard windows", "Drag windows like the character window anywhere.", "moveWindows", rec = true },
    { "Resize Blizzard windows", "Drag a window with the right mouse button to change its size.", "resizeWindows" }, -- user 01.11.
    { "Chat font size", "The same font size for every chat window.", kind = "font" },
    { "Logo color", "The color of the OneForAll minimap button.", kind = "logo" },
    { "Collect minimap buttons", "Puts the minimap buttons of other addons into one bar.", "mmCollect", rec = true },
    { "Square minimap", "A square minimap with a thin black frame.", "mmSquare" },
    { "Short green stats", "Long \"Equip:\" lines in tooltips as short stats, e.g. \"+1% Hit\".", "shortStats" }, -- user 01.11.
  } },
  { "Loot & Vendors", {
    { "Quicker loot", "Takes everything at once when the game auto loots.", "quickLoot", rec = true },
    { "Auto repair", "Repairs all gear at merchants that can repair.", "autoRepair" },
    { "Sell junk", "Sells all grey items when you open a merchant.", "sellJunk" },
    { "Bags full helper", "When loot does not fit, offers to destroy the cheapest item.", "bagsFull", rec = true },
    { "Show loot feed", "Looted items and money float up next to your character.", "lootFeed", rec = true },
    { "Sparkle on herbs & ore", "Only for Herbalism and Mining: the herb or ore vein near you sparkles.", "nodeGlow" },
  } },
  { "Quests & Social", {
    { "Accept quests automatically", "Hold Shift to do it by hand.", "autoAccept" },
    { "Turn in quests automatically", "You still pick rewards yourself.", "autoTurnIn" },
    { "Quest XP on the experience bar", "Shows the XP of your finished quests.", "questXP", rec = true },
    { "Quest loot sparkles", "Quest items in the world sparkle again.", "questSparkles", rec = true },
    { "Thank players who buff you", "Sends a /thank to players outside your group who buff you.", "thanksBuff", rec = true },
    { "Quest marks on nameplates", "A sword or a bag with your progress on mobs you need for a quest.", "questMarks" }, -- 6.0.2 (user 01.11.)
  } },
  { "World Map", {
    { "Map Landmarks", "Dungeon entrances, flight masters, ships and more on the map.", "mapLandmarks", rec = true },
    { "Dungeon & raid entrances", "Click to open the dungeon in OneForAll.", "lmDungeons", sub = true, rec = true },
    { "Flight masters", "Shows where they fly to.", "lmFlight", sub = true, rec = true },
    { "Zeppelins, ships & tram", "Shows where they go.", "lmTransport", sub = true, rec = true },
    { "Library Books", "A book icon where each book you still need lies.", "mapBooks", sub = true, rec = true },
    { "Remove Fog", "Shows the parts of a zone you have not explored yet.", "mapFog", rec = true },
    { "Dungeon map on M", "Inside a dungeon, M opens OneForAll's dungeon map.", rec = true,
      get = function() return db().dungeonMapKey ~= false end,
      set = function(v) if type(OneForAllDB) == "table" then OneForAllDB.dungeonMapKey = v and true or false end
        if FLT.ApplyDungeonMapKey then FLT.ApplyDungeonMapKey() end end },
  } },
  { "Unit Frames & Spells", {
    { "Class colors", "Health bars of players in their class color.", "classColors", rec = true },
    { "Class colors: raid frames", "The game's own setting.", cvar = "raidClassColor" },
    { "Power bars: raid frames", "Mana, rage and energy bars in the raid frames.", cvar = "raidPowerBars" },
    { "Check low spell ranks", "Offers the highest rank for spells on your bars.", "lowRank", rec = true },
    { "Trainer button in the spellbook", "Opens the trainer window: spells and weapon skills.", "spellbookTrainer", rec = true },
  } },
  { "Popups & Alerts", {
    { "Durability warning", "Warns when your gear drops to 20% durability.", "durability", rec = true },
    { "Nearby Library Book alerts", "Popup when you are close to a missing library book.", rec = true,
      get = function() return FLT.IsNearbyAlertsEnabled and FLT:IsNearbyAlertsEnabled() and true or false end,
      set = function(v) if FLT.SetNearbyAlertsEnabled then FLT:SetNearbyAlertsEnabled(v) end end },
    { "Pet ability alerts", "Popup when a beast nearby teaches a higher rank your pets can learn.", rec = true, hunter = true,
      get = function() return FLT.IsPetTeachAlertsEnabled and FLT:IsPetTeachAlertsEnabled() and true or false end,
      set = function(v) if FLT.SetPetTeachAlertsEnabled then FLT:SetPetTeachAlertsEnabled(v) end end },
    { "Quest share popup in dungeons", "When a group member can still accept one of your dungeon quests.", rec = true,
      get = function() local s = db().questShare; return not (type(s) == "table" and s.popup == false) end,
      set = function(v) if type(OneForAllDB) == "table" then OneForAllDB.questShare = OneForAllDB.questShare or {}
        OneForAllDB.questShare.popup = v and true or false end end },
  } },
}
-- get / set for every switch row
for _, p in ipairs(PAGES) do
  for _, it in ipairs(p[2]) do
    if it.cvar then it.get, it.set = cvar(it.cvar)
    elseif it[3] then it.get, it.set = qget(it[3]), qset(it[3]) end
  end
end
local function setItem(it, v)
  it.set(v)
  if it[3] == "mmCollect" and v then Q.Set("mmHide", false) end -- the collector needs its button
end

local W, H = 600, 470
-- arrows on the page buttons (user 31.10.): the gold chevron of the "< Dungeons" button (GoldButton:SetArrow)
local frame, pages, page, refresh = nil, {}, 1, nil

local function recommended()
  for _, p in ipairs(PAGES) do for _, it in ipairs(p[2]) do if it.rec and it.set then setItem(it, true) end end end
end

-- a switch row on an option page
local function switchRow(parent, it, y)
  local x = it.sub and 44 or 20
  local cb = FLT.SkinBlizz(CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")); cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  local l = FLT.NewFS(parent, nil, "OVERLAY", "GameFontHighlight"); l:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, -1); l:SetText(it[1])
  local d = FLT.NewFS(parent, nil, "OVERLAY", "GameFontDisableSmall"); d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2); d:SetText(it[2])
  if it.rec then
    local r = FLT.NewFS(parent, nil, "OVERLAY", "GameFontNormalSmall"); r:SetPoint("LEFT", l, "RIGHT", 8, 0)
    r:SetText("Recommended"); r:SetTextColor(0.45, 0.85, 0.40)
  end
  cb:SetScript("OnClick", function(b) setItem(it, b:GetChecked() and true or false) end)
  return function() cb:SetChecked(it.get()) end
end

-- the five logo colors as pictures (user 27.10.)
local LOGOS = { { "teal", "Turquoise" }, { "red", "Red" }, { "blue", "Blue" }, { "green", "Green" }, { "violet", "Violet" }, { "bronze", "Bronze" } }
local function logoRow(parent, it, y)
  local l = FLT.NewFS(parent, nil, "OVERLAY", "GameFontHighlight"); l:SetPoint("TOPLEFT", 48, y - 1); l:SetText(it[1])
  local d = FLT.NewFS(parent, nil, "OVERLAY", "GameFontDisableSmall"); d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2); d:SetText(it[2])
  local marks = {}
  for i, c in ipairs(LOGOS) do
    local b = CreateFrame("Button", nil, parent); b:SetSize(30, 30); b:SetPoint("TOPLEFT", 330 + (i - 1) * 40, y + 2)
    local t = b:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(UI.ASSET_ROOT .. "logo_round_" .. (c[1] == "bronze" and "teal" or c[1]))
    if FLT.TintLogo then FLT.TintLogo(t, c[1]) end
    local sel = b:CreateTexture(nil, "OVERLAY"); sel:SetPoint("TOPLEFT", -4, 4); sel:SetPoint("BOTTOMRIGHT", 4, -4)
    sel:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"); sel:SetBlendMode("ADD")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    b:SetScript("OnClick", function() Q.Set("logoColor", c[1]); refresh() end)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(c[2]); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    marks[c[1]] = sel
  end
  return function() local cur = Q.Get("logoColor") for k, s in pairs(marks) do s:SetShown(k == cur) end end
end

-- chat font size: - 14 + (below 10 = the game's own setting)
local function fontRow(parent, it, y)
  local l = FLT.NewFS(parent, nil, "OVERLAY", "GameFontHighlight"); l:SetPoint("TOPLEFT", 48, y - 1); l:SetText(it[1])
  local d = FLT.NewFS(parent, nil, "OVERLAY", "GameFontDisableSmall"); d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2); d:SetText(it[2])
  local val = FLT.NewFS(parent, nil, "OVERLAY", "GameFontNormal"); val:SetPoint("TOPLEFT", 386, y - 4); val:SetWidth(70); val:SetJustifyH("CENTER")
  local function step(dv)
    local v = tonumber(Q.Get("chatFont"))
    if not v then v = 14 else v = v + dv end
    if v < 10 then v = nil elseif v > 24 then v = 24 end
    Q.Set("chatFont", v); refresh()
  end
  local minus = UI.GoldButton(parent, "-", 26, 22, nil, 13); minus:SetPoint("TOPLEFT", 356, y); minus:SetScript("OnClick", function() step(-1) end)
  local plus = UI.GoldButton(parent, "+", 26, 22, nil, 13); plus:SetPoint("TOPLEFT", 460, y); plus:SetScript("OnClick", function() step(1) end)
  return function() local v = tonumber(Q.Get("chatFont")); val:SetText(v and tostring(v) or "|cff9d9d9dgame|r") end
end

local function optionPage(parent, p)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local t = UI.SectionTitle(f, p[1], 16, -6)
  local class = UnitClass and select(2, UnitClass("player"))
  local y, upd = -40, {}
  for _, it in ipairs(p[2]) do
    if not (it.hunter and class ~= "HUNTER") then
      local fn = (it.kind == "logo" and logoRow) or (it.kind == "font" and fontRow) or switchRow
      upd[#upd + 1] = fn(f, it, y)
      y = y - 38
    end
  end
  f.update = function() for _, u in ipairs(upd) do u() end end
  return f
end

local function textPage(parent, first)
  local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()
  local y = -14
  if first then
    local logo = f:CreateTexture(nil, "ARTWORK"); logo:SetSize(280, 140); logo:SetPoint("TOP", 0, y)
    -- the client's own picture; without it (other client) only the text shows
    local ok, res = pcall(logo.SetTexture, logo, FOREVER_LOGO)
    if ok and res ~= false and logo:GetTexture() then y = y - 150 else logo:Hide() end
  end
  local h = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge"); h:SetPoint("TOP", 0, y); h:SetTextColor(FLT.SkinC(1, 0.82, 0.20))
  local b = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlight"); b:SetPoint("TOP", h, "BOTTOM", 0, -12); b:SetWidth(W - 120)
  b:SetJustifyH("CENTER"); b:SetSpacing(3)
  if first then
    h:SetText("Welcome to OneForAll")
    b:SetText("Set up a few Quality of Life helpers now - one page per topic.\n\n"
      .. "|cffd9a63aRecommended settings|r switches on what OneForAll suggests. "
      .. "You can also skip this: everything can be changed later in OneForAll > Quality of Life.")
  else
    -- the author's waving warrior (user 27.10.) on the left, the text on the right
    local pic = f:CreateTexture(nil, "ARTWORK"); pic:SetSize(272, 272); pic:SetPoint("BOTTOMLEFT", 6, -4)
    pic:SetTexture(UI.ASSET_ROOT .. "welcome_warrior")
    h:ClearAllPoints(); h:SetPoint("TOP", f, "TOPLEFT", 420, -40)
    b:SetWidth(270)
    h:SetText("All set!")
    b:SetText("Thank you for using OneForAll! Everything can be changed later in OneForAll > Quality of Life.\n\n"
      .. "Have fun in Azeroth!\n|cffd9a63a- Smoergi|r") -- greeting from the author (user 27.10.)
  end
  return f
end

local function create()
  local f = CreateFrame("Frame", "OneForAllWelcome", UIParent)
  f:SetSize(W, H); f:SetPoint("CENTER", 0, 40); f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllWelcome") end -- Esc closes it
  UI.FramedPanel(f)
  for _, t in ipairs(UI.OrnateFrame(f, f, 18, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
  local logo = f:CreateTexture(nil, "OVERLAY"); logo:SetSize(30, 30); logo:SetPoint("TOPLEFT", 14, -10)
  logo:SetTexture(FLT.LogoTexture and FLT.LogoTexture("round") or (UI.ASSET_ROOT .. "minimap_icon")); if FLT.TintLogo then FLT.TintLogo(logo) end
  local title = UI.SmallCaps(f, "OneForAll - Setup", 19, 15, { 1, 0.82, 0.20 }, "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 52, -14)
  -- the page number bottom right above "Next", from the first page on (user 27.10.: "1 / 7" shows there is more)
  local stepText = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall"); stepText:SetPoint("BOTTOMRIGHT", -20, 44)
  local close = UI.CloseButton(f); close:SetPoint("TOPRIGHT", -12, -12)

  local body = CreateFrame("Frame", nil, f); body:SetPoint("TOPLEFT", 10, -48); body:SetPoint("BOTTOMRIGHT", -10, 52)
  pages[1] = textPage(body, true)
  for _, p in ipairs(PAGES) do pages[#pages + 1] = optionPage(body, p) end
  pages[#pages + 1] = textPage(body, false)

  local back = UI.GoldButton(f, "Back", 160, 26, nil, 13); back:SetPoint("BOTTOMLEFT", 16, 14); back:SetArrow("prev")
  local skip = UI.GoldButton(f, "Skip", 160, 26, nil, 13); skip:SetPoint("BOTTOMLEFT", 16, 14)
  local rec = UI.GoldButton(f, "Recommended settings", 190, 26, nil, 13); rec:SetPoint("BOTTOM", 0, 14)
  local nextB = UI.GoldButton(f, "Next", 160, 26, nil, 13); nextB:SetPoint("BOTTOMRIGHT", -16, 14)
  local openQ = UI.GoldButton(f, "Open Quality of Life", 190, 26, nil, 13); openQ:SetPoint("BOTTOM", 0, 14)
  rec:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Recommended settings", 1, 0.82, 0)
    GameTooltip:AddLine("Switches on everything marked \"Recommended\". Nothing else is switched off.", 1, 1, 1, true); GameTooltip:Show()
  end)
  rec:SetScript("OnLeave", function() GameTooltip:Hide() end)

  refresh = function()
    for i, p in ipairs(pages) do p:SetShown(i == page); if i == page and p.update then p.update() end end
    local first, last = page == 1, page == #pages
    stepText:SetText(last and "" or string.format("%d / %d", page, #pages - 1))
    back:SetShown(not first and not last); skip:SetShown(first)
    rec:SetShown(not last); openQ:SetShown(last)
    nextB:SetLabel(first and "Choose myself" or (last and "Done" or "Next")); nextB:SetArrow(not last and "next" or nil)
  end
  back:SetScript("OnClick", function() page = math.max(1, page - 1); refresh() end)
  nextB:SetScript("OnClick", function() if page == #pages then f:Hide() else page = page + 1; refresh() end end)
  skip:SetScript("OnClick", function() f:Hide() end)
  rec:SetScript("OnClick", function()
    recommended()
    if page == 1 then page = #pages end -- straight to "All set"
    refresh()
  end)
  openQ:SetScript("OnClick", function() f:Hide(); if FLT.OpenPanel then FLT:OpenPanel("qol") end end)
  f:SetScript("OnShow", function() refresh() end)
  f:Hide()
  return f
end

function FLT.ShowWelcome()
  if not frame then frame = create() end
  page = 1
  if type(OneForAllDB) == "table" then OneForAllDB.welcomeSeen = WELCOME_ID end
  if frame:IsShown() then refresh() else frame:Show() end
end
-- the news popup waits a login while this one is due
function FLT.WelcomeDue() return type(OneForAllDB) == "table" and OneForAllDB.welcomeSeen ~= WELCOME_ID end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if not FLT.WelcomeDue() then return end
  if C_Timer and C_Timer.After then C_Timer.After(4, FLT.ShowWelcome) else FLT.ShowWelcome() end
end)
FLT._welcomePages = PAGES -- tests
