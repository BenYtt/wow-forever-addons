local ADDON, FLT = ...

-- OneForAll button on the world map (6.0.2, user 01.11.; the idea from RareScanner's map button): the round logo at
-- the top left of the map opens a list with every switch of Quality of Life > World Map (Map Landmarks and its parts,
-- Remove Fog, Dungeon map on M). The list stays open for more clicks; the map redraws at once.
-- Switch qol.mapButton. Placed below other addons' buttons in that corner (RareScanner ...), built on the first
-- map open. Nothing runs while the map is closed.

local btn -- FLT.UI is read when used: Widgets.lua loads after this file (beta12 error "upvalue UI nil")

local function Q() return FLT.QoL end

-- the rows: key = QoL key (or a function pair for the Dungeon map on M, which is not in qol)
local ROWS = {
  { key = "mapLandmarks", label = "Map Landmarks" },
  { key = "lmDungeons", label = "   Dungeon & raid entrances", sub = true },
  { key = "lmFlight", label = "   Flight masters", sub = true },
  { key = "lmTransport", label = "   Zeppelins, ships & tram", sub = true },
  { key = "lmTransitions", label = "   Zone transitions", sub = true },
  { key = "mapBooks", label = "   Library Books", sub = true },
  { key = "lmSkyborne", label = "   Skyborne: Ley Lines & Convergences", sub = true },
  { key = "mapQuests", label = "Quest icons (! and ?)" },
  { key = "mapFog", label = "Remove Fog" },
  { key = "mapZoneLevel", label = "Zone level range" },
  { key = "dungeonMapKey", label = "Dungeon map on M",
    get = function() return type(OneForAllDB) == "table" and OneForAllDB.dungeonMapKey ~= false end,
    set = function(v)
      if type(OneForAllDB) == "table" then OneForAllDB.dungeonMapKey = v and true or false end
      if FLT.ApplyDungeonMapKey then FLT.ApplyDungeonMapKey() end
    end },
}

local function value(r) if r.get then return r.get() end return Q().Get(r.key) and true or false end

local function redraw()
  if WorldMapFrame and WorldMapFrame.RefreshAllDataProviders then pcall(WorldMapFrame.RefreshAllDataProviders, WorldMapFrame) end
  if FLT.MapLandmarks then FLT.MapLandmarks.Apply() end
  if FLT.RefreshMapFog then FLT.RefreshMapFog() end
end

-- The list (user 01.11.: calmer, like RareScanner's): its own small menu that opens to the RIGHT of the button (the
-- map's left edge is near the screen edge), white text with tick boxes, the parts of Map Landmarks indented, a line
-- before Remove Fog. Stays open for more clicks; a click outside or Escape closes it. Built on first use.
local menu
local ROW_H = 21 -- slim (user 01.11.: covered too much of the map)
local function paintMenu()
  local landmarks = Q().Get("mapLandmarks")
  for _, row in ipairs(menu.rows) do
    row.check:SetShown(value(row.r))
    local dim = row.r.sub and not landmarks -- the parts only work with Map Landmarks on
    row.text:SetTextColor(dim and 0.5 or 0.92, dim and 0.5 or 0.90, dim and 0.5 or 0.84)
  end
  local fogOn = Q().Get("mapFog") and true or false
  local v = Q().Get("mapFogAlpha") or 100
  menu.fog:SetValue(v); menu.fogVal:SetText(v .. " %")
  menu.fog:SetAlpha(fogOn and 1 or 0.4); menu.fog:EnableMouse(fogOn); menu.fog:EnableMouseWheel(fogOn)
end
local function buildMenu()
  menu = CreateFrame("Frame", "OneForAllWorldMapMenu", UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:EnableMouse(true); menu:Hide()
  FLT.UI.FramedPanel(menu); menu:SetAlpha(0.9) -- a little see-through (user 01.11.)
  local catcher = CreateFrame("Button", nil, UIParent); catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG"); catcher:SetFrameLevel(1); catcher:RegisterForClicks("AnyUp"); catcher:Hide()
  catcher:SetScript("OnClick", function() menu:Hide() end)
  menu:SetFrameLevel(20)
  menu:SetScript("OnShow", function() catcher:Show() end)
  menu:SetScript("OnHide", function() catcher:Hide() end)
  if UISpecialFrames then table.insert(UISpecialFrames, "OneForAllWorldMapMenu") end
  menu.rows = {}
  local y, w = -6, 0
  for i, r in ipairs(ROWS) do
    if r.key == "mapQuests" then -- a fine line before the other map switches
      local ln = menu:CreateTexture(nil, "ARTWORK"); ln:SetColorTexture(0.50, 0.42, 0.30, 0.6); ln:SetHeight(1)
      ln:SetPoint("TOPLEFT", 10, y - 4); ln:SetPoint("TOPRIGHT", -10, y - 4); y = y - 9
    end
    local row = CreateFrame("Button", nil, menu); row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 4, y); row:SetPoint("TOPRIGHT", -4, y); y = y - ROW_H
    local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(0.90, 0.66, 0.22, 0.10)
    local x = r.sub and 20 or 6
    local box = row:CreateTexture(nil, "ARTWORK"); box:SetSize(15, 15); box:SetPoint("LEFT", x, 0)
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    row.check = row:CreateTexture(nil, "OVERLAY"); row.check:SetSize(15, 15); row.check:SetPoint("CENTER", box)
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.text = FLT.NewFS(row, nil, "OVERLAY", "GameFontHighlight")
    if r.sub then local font, _, flags = row.text:GetFont(); if font then row.text:SetFont(font, 11, flags) end end -- beta16 small font was too small (user 01.11.)
    row.text:SetPoint("LEFT", box, "RIGHT", 4, 0); row.text:SetText((r.label:gsub("^%s+", "")))
    w = math.max(w, x + 18 + (row.text:GetStringWidth() or 150) + 14)
    row.r = r
    row:SetScript("OnClick", function()
      if r.set then r.set(not value(r)) else Q().Set(r.key, not value(r)) end
      redraw(); paintMenu()
    end)
    menu.rows[i] = row
    if r.key == "mapFog" then -- how visible the unexplored parts are, 0-100 % (user 01.11.: also in this menu)
      local sl = FLT.UI.Slider(menu, 100, 0, 100, 5, function(v)
        menu.fogVal:SetText(v .. " %")
        if Q().Get("mapFogAlpha") ~= v then Q().Set("mapFogAlpha", v) end
      end)
      sl:SetPoint("TOPLEFT", 26, y - 1); y = y - ROW_H - 2
      menu.fogVal = FLT.NewFS(menu, nil, "OVERLAY", "GameFontHighlight"); menu.fogVal:SetPoint("LEFT", sl, "RIGHT", 8, 0)
      sl:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("Unexplored areas", 1, 0.82, 0)
        GameTooltip:AddLine("How visible the parts you have not explored yet are: 0 % hidden, 100 % fully shown.", 1, 1, 1, true); GameTooltip:Show()
      end)
      sl:SetScript("OnLeave", function() GameTooltip:Hide() end)
      menu.fog = sl
    end
  end
  menu:SetSize(math.max(170, w), -y + 6)
end
local function openList(self)
  if not menu then buildMenu() end
  if menu:IsShown() then menu:Hide(); return end
  menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", self, "TOPRIGHT", 6, 0) -- always to the right
  paintMenu(); menu:Show()
end

-- other addons' buttons in the top left corner of the map (RareScanner ...): ours sits right under the lowest one,
-- centred under it and a bit smaller than its frame (the logo fills its square, their art has a margin). Looked
-- for among the map's overlay frames and the children of the map and its canvas, by position (user 01.11.: ours
-- covered RareScanner's). Placed on every map open and once more a moment later (they may come later).
local function cornerButton()
  local canvas = WorldMapFrame.ScrollContainer or WorldMapFrame
  local cl, ct = canvas:GetLeft(), canvas:GetTop()
  if not (cl and ct) then return end
  local best
  local function check(f)
    if f == btn or type(f) ~= "table" or not (f.IsShown and f:IsShown() and f.GetLeft) then return end
    local l, t, wd, ht = f:GetLeft(), f:GetTop(), f:GetWidth() or 0, f:GetHeight() or 0
    if not (l and t) or wd < 12 or wd > 60 or ht < 12 or ht > 60 then return end
    if math.abs(l - cl) < 50 and ct - t > -12 and ct - t < 220 then
      if not best or f:GetBottom() < best:GetBottom() then best = f end
    end
  end
  for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do check(f) end
  for _, f in ipairs({ WorldMapFrame:GetChildren() }) do check(f) end
  if canvas ~= WorldMapFrame then for _, f in ipairs({ canvas:GetChildren() }) do check(f) end end
  return best
end
local function place()
  local canvas = WorldMapFrame.ScrollContainer or WorldMapFrame
  local above = cornerButton()
  btn:ClearAllPoints()
  if above then
    -- 0.9 and 2 px to the right: their round art sits a little right of their frame's centre (user 01.11., beta14
    -- looked a few pixels too small and too far left)
    local size = math.floor(math.min(above:GetWidth(), above:GetHeight()) * 0.9 + 0.5)
    btn:SetSize(size, size)
    btn:SetPoint("TOP", above, "BOTTOM", 2, -3)
  else
    btn:SetSize(24, 24)
    btn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 8, -8)
  end
end

local function create()
  btn = CreateFrame("Button", "OneForAllWorldMapButton", WorldMapFrame.ScrollContainer or WorldMapFrame)
  btn:SetSize(24, 24); btn:SetFrameStrata("HIGH"); btn:SetFrameLevel(510)
  btn.icon = btn:CreateTexture(nil, "ARTWORK"); btn.icon:SetAllPoints()
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
  btn:SetScript("OnClick", openList)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("OneForAll", 1, 0.82, 0)
    GameTooltip:AddLine("Click: map icons, quest icons, Remove Fog and the dungeon map.", 1, 1, 1, true); GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function refresh()
  if not WorldMapFrame then return end
  local on = Q() and Q().Get("mapButton")
  if not on then if btn then btn:Hide() end; return end
  if not btn then create() end
  btn.icon:SetTexture(FLT.LogoTexture and FLT.LogoTexture("round") or (FLT.UI.ASSET_ROOT .. "logo_round_teal"))
  if FLT.TintLogo then FLT.TintLogo(btn.icon) end
  place(); btn:Show()
  C_Timer.After(0.2, function() if btn:IsShown() then place() end end) -- other addons may add their button later
end
FLT.RefreshMapButton = refresh

-- the level range of the shown zone at the top right of the map, and behind the zone name when you hover a zone on
-- the continent map (user 01.11., switch qol.mapZoneLevel, on by default). The game's numbers when it has some
-- (C_Map.GetMapLevels, empty in Forever), else Data/ZoneLevels.lua.
local function levels(id)
  local lo, hi
  if C_Map and C_Map.GetMapLevels then lo, hi = C_Map.GetMapLevels(id) end
  if not (lo and hi and lo > 0 and hi > 0) then
    local z = FLT.ZONE_LEVELS and FLT.ZONE_LEVELS[id]
    if not z then return end
    lo, hi = z[1], z[2]
  end
  return lo, hi
end
local function rangeText(lo, hi) return lo == hi and tostring(lo) or (lo .. " - " .. hi) end
-- red when you are below it, grey when above, gold inside
local function color(lo, hi)
  local me = UnitLevel and UnitLevel("player") or lo
  if me < lo then return 1, 0.35, 0.3 elseif me > hi then return 0.62, 0.62, 0.62 end
  return 1, 0.82, 0.2
end
local zoneText
local function zoneLevel()
  if not WorldMapFrame then return end
  local id = Q() and Q().Get("mapZoneLevel") and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local lo, hi
  if id then lo, hi = levels(id) end
  if not lo then if zoneText then zoneText:Hide() end; return end
  if not zoneText then
    local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
    local f = CreateFrame("Frame", nil, parent); f:SetSize(1, 1); f:SetFrameStrata("HIGH"); f:SetFrameLevel(510)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -10)
    zoneText = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge")
    zoneText:SetPoint("TOPRIGHT"); zoneText:SetShadowOffset(1, -1)
    do local font, size = zoneText:GetFont(); if font then zoneText:SetFont(font, size or 15, "OUTLINE") end end
  end
  zoneText:SetText("Level " .. rangeText(lo, hi))
  zoneText:SetTextColor(color(lo, hi))
  zoneText:Show()
end

-- continent map: the game's hover label ("The Barrens") gets the range behind the name. The label belongs to the map's
-- area label data provider; after it set its text we add ours (zone names in the client's language -> uiMapID, once).
local byName
local function nameIndex()
  byName = {}
  for id in pairs(FLT.ZONE_LEVELS or {}) do
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    if info and info.name then byName[info.name] = id end
  end
end
local function labelHook(label)
  local fs, extra = label.Name, label.ofaRange
  if extra then extra:Hide() end
  if not Q().Get("mapZoneLevel") then return end
  local text = fs and fs.GetText and fs:GetText()
  if type(text) ~= "string" or text == "" or not fs:IsShown() then return end
  if not byName then nameIndex() end
  local id = byName[text]
  local lo, hi
  if id then lo, hi = levels(id) end
  if not lo then return end
  -- own smaller font string right of the name (user 01.11.: as large as the name was too large)
  if not extra then
    extra = label:CreateFontString(nil, "OVERLAY")
    local font, size, flags = fs:GetFont()
    extra:SetFont(font, math.floor((size or 20) * 0.8 + 0.5), flags) -- 0.7 was a tick too small (user 01.11.)
    extra:SetShadowOffset(fs:GetShadowOffset()); extra:SetShadowColor(fs:GetShadowColor())
    extra:SetPoint("LEFT", fs, "RIGHT", 6, 1) -- centred on the name (the baseline sat too low)
    label.ofaRange = extra
  end
  extra:SetText("(" .. rangeText(lo, hi) .. ")")
  extra:SetTextColor(color(lo, hi))
  extra:Show()
end
local labelHooked
local function hookLabel()
  if labelHooked then return end
  for dp in pairs(WorldMapFrame.dataProviders or {}) do
    local label = type(dp) == "table" and dp.Label
    if type(label) == "table" and label.Name and label.EvaluateLabels then
      hooksecurefunc(label, "EvaluateLabels", function(self) pcall(labelHook, self) end)
      labelHooked = true
      return
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", refresh)
    WorldMapFrame:HookScript("OnShow", function() hookLabel(); zoneLevel() end)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", zoneLevel) end
    hookLabel()
    WorldMapFrame:HookScript("OnHide", function() if menu then menu:Hide() end end)
  end
  if Q() and Q().On then
    Q().On("mapButton", refresh)
    Q().On("mapZoneLevel", zoneLevel)
  end
end)
