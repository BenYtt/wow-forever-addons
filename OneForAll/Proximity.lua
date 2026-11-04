local _, FLT = ...

-- Coordinate-based nearby alerts.
-- We prefer world-coordinate distance when the client exposes it. This makes the
-- configured radius behave roughly like yards even though the stored book data
-- is expressed as map percentages. A normalized-map fallback is kept for older
-- Forever clients that do not expose C_Map.GetWorldPosFromMapPos.
local WORLD_RADIUS_YARDS = 120
local MAP_RADIUS_FALLBACK = 0.025 -- 2.5% of the zone map
local CHECK_INTERVAL = 1.0
local ALERT_DURATION = 20.0

local monitor
local elapsed = 0
local alertFrame
local activeNearby = {}
local alertSerial = 0
local hideSecureTarget -- defined further down; used by the alert frame

local function vecXY(v)
  if not v then return nil end
  if v.GetXY then
    local ok, x, y = pcall(v.GetXY, v)
    if ok then return x, y end
  end
  if v.x and v.y then return v.x, v.y end
  return nil
end

local function isMapWithin(currentMapID, zoneMapID)
  if not currentMapID or not zoneMapID or not C_Map or not C_Map.GetMapInfo then return currentMapID == zoneMapID end
  local id = currentMapID
  for _ = 1, 8 do
    if id == zoneMapID then return true end
    local info = C_Map.GetMapInfo(id)
    if not info or not info.parentMapID or info.parentMapID == 0 or info.parentMapID == id then break end
    id = info.parentMapID
  end
  return false
end

local function getPlayerPosition(mapID)
  if not C_Map or not C_Map.GetPlayerMapPosition then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not ok or not pos then return nil end
  local x, y = vecXY(pos)
  if not x or not y or (x == 0 and y == 0) then return nil end
  return x, y, pos
end

local function worldDistance(mapID, playerPos, bookX, bookY)
  if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end

  local ok1, playerContinent, playerWorld = pcall(C_Map.GetWorldPosFromMapPos, mapID, playerPos)
  local ok2, bookContinent, bookWorld = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(bookX / 100, bookY / 100))
  if not ok1 or not ok2 or not playerWorld or not bookWorld then return nil end
  if playerContinent and bookContinent and playerContinent ~= bookContinent then return nil end

  local px, py = vecXY(playerWorld)
  local bx, by = vecXY(bookWorld)
  if not px or not py or not bx or not by then return nil end
  local dx, dy = px - bx, py - by
  return math.sqrt(dx * dx + dy * dy)
end

local function makeBackdrop(frame)
  -- same panel and frame as the other OneForAll popups (both frame styles)
  local UI = FLT.UI
  if UI and UI.FramedPanel and UI.OrnateFrame then
    UI.FramedPanel(frame)
    for _, t in ipairs(UI.OrnateFrame(frame, frame, 16, 3, "OVERLAY", 4)) do t:SetVertexColor(FLT.SkinC(1, 1, 1, 1)) end
    return
  end
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(FLT.SkinC(0.035, 0.028, 0.018, 0.97))

  local top = frame:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT", 1, -1); top:SetPoint("TOPRIGHT", -1, -1); top:SetHeight(2)
  top:SetColorTexture(FLT.SkinC(0.90, 0.62, 0.14, 0.95))
  local bottom = frame:CreateTexture(nil, "BORDER")
  bottom:SetPoint("BOTTOMLEFT", 1, 1); bottom:SetPoint("BOTTOMRIGHT", -1, 1); bottom:SetHeight(2)
  bottom:SetColorTexture(FLT.SkinC(0.55, 0.36, 0.08, 0.90))
  local left = frame:CreateTexture(nil, "BORDER")
  left:SetPoint("TOPLEFT", 1, -1); left:SetPoint("BOTTOMLEFT", 1, 1); left:SetWidth(2)
  left:SetColorTexture(FLT.SkinC(0.65, 0.43, 0.10, 0.90))
  local right = frame:CreateTexture(nil, "BORDER")
  right:SetPoint("TOPRIGHT", -1, -1); right:SetPoint("BOTTOMRIGHT", -1, 1); right:SetWidth(2)
  right:SetColorTexture(FLT.SkinC(0.65, 0.43, 0.10, 0.90))
end

local function createAlertFrame()
  if alertFrame then return alertFrame end

  local f = CreateFrame("Frame", "OneForAllNearbyAlert", UIParent)
  f:SetSize(470, 128)
  f:SetPoint("TOP", UIParent, "TOP", 0, -145)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  makeBackdrop(f)

  local icon = f:CreateTexture(nil, "ARTWORK")
  f.icon = icon
  FLT.SetTex(icon, "Interface\\Icons\\INV_Misc_Book_09")
  icon:SetSize(50, 50)
  icon:SetPoint("LEFT", 18, 10)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local eyebrow = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalSmall")
  eyebrow:SetPoint("TOPLEFT", 82, -15)
  eyebrow:SetText("LIBRARY BOOK NEARBY")
  f.eyebrow = eyebrow
  eyebrow:SetTextColor(FLT.SkinC(1.00, 0.76, 0.18))

  local title = FLT.NewFS(f, nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 82, -34)
  title:SetPoint("RIGHT", -45, 0)
  title:SetJustifyH("LEFT")
  title:SetTextColor(FLT.SkinC(1, 0.92, 0.68))
  f.title = title

  local where = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall")
  where:SetPoint("TOPLEFT", 82, -61)
  where:SetPoint("RIGHT", -18, 0)
  where:SetJustifyH("LEFT")
  where:SetTextColor(FLT.SkinC(0.83, 0.83, 0.78))
  f.where = where

  local map = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  map:SetSize(92, 25)
  map:SetPoint("BOTTOMLEFT", 82, 13)
  map:SetText("Open Map")
  if FLT.UI and FLT.UI.SkinBlizzButton then FLT.UI.SkinBlizzButton(map, 25) end
  f.mapButton = map

  local dismiss = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  dismiss:SetSize(78, 25)
  dismiss:SetPoint("LEFT", map, "RIGHT", 8, 0)
  dismiss:SetText("Dismiss")
  dismiss:SetScript("OnClick", function() f:Hide() end)
  if FLT.UI and FLT.UI.SkinBlizzButton then FLT.UI.SkinBlizzButton(dismiss, 25) end

  f.dismissButton = dismiss
  -- Free button row for generic alerts (opts.buttons).
  f.customButtons = {}
  for i = 1, 3 do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(100, 25)
    if i == 1 then b:SetPoint("BOTTOMLEFT", 82, 13) else b:SetPoint("LEFT", f.customButtons[i - 1], "RIGHT", 8, 0) end
    b:Hide()
    if FLT.UI and FLT.UI.SkinBlizzButton then FLT.UI.SkinBlizzButton(b, 25) end
    f.customButtons[i] = b
  end

  local close
  if FLT.UI and FLT.UI.CloseButton then close = FLT.UI.CloseButton(f); close:SetPoint("TOPRIGHT", -10, -10)
  else close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2) end

  f:HookScript("OnHide", function() hideSecureTarget() end)
  f:Hide()
  alertFrame = f
  return f
end

-- Secure "target" button. Targeting is protected, so it runs a /targetexact
-- macro through a SecureActionButton (only works when clicked by the player).
-- It is a separate top-level frame (not a child of the alert) so the alert
-- itself can still be hidden in combat; it cannot be set up during combat.
local secureTarget, secureHidePending
local function getSecureTarget()
  if secureTarget then return secureTarget end
  local b = CreateFrame("Button", "OneForAllAlertTargetButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  b:SetSize(84, 25); b:SetFrameStrata("FULLSCREEN_DIALOG"); b:SetFrameLevel(50)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  if FLT.UI and FLT.UI.SkinBlizzButton then FLT.UI.SkinBlizzButton(b, 25) end
  b:Hide()
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    if secureHidePending then secureHidePending = nil; b:Hide(); b:SetAlpha(1) end
  end)
  secureTarget = b
  return b
end
hideSecureTarget = function()
  if not secureTarget or not secureTarget:IsShown() then return end
  if InCombatLockdown and InCombatLockdown() then
    secureTarget:SetAlpha(0); secureHidePending = true
  else
    secureTarget:Hide()
  end
end

-- Generic alert in the same style, used e.g. by the Hunter Pets tab.
-- opts = { eyebrow, icon, title, where, map = {mapID, x, y, zone, name} }
function FLT:ShowAlert(opts)
  local f = createAlertFrame()
  f.book = nil
  f.eyebrow:SetText(opts.eyebrow or "ONEFORALL")
  FLT.SetTex(f.icon, opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.title:SetText(opts.title or "")
  f.where:SetText(opts.where or "")
  hideSecureTarget()
  if opts.buttons then
    -- Custom button row replaces "Open Map" / "Dismiss" (close with the X).
    f.mapButton:Hide(); f.dismissButton:Hide()
    local total = 82
    for i, b in ipairs(f.customButtons) do
      local spec = opts.buttons[i]
      if spec then
        b:SetText(spec.text or "")
        local fs = b:GetFontString()
        b:SetWidth(math.max(84, (fs and fs:GetStringWidth() or 70) + 24))
        b:SetScript("OnClick", function() if spec.onClick then spec.onClick() end; if not spec.keepOpen then f:Hide() end end)
        b:Enable(); b:SetAlpha(1)
        b:Show()
        if spec.secureMacro then
          -- The visible button is only a placeholder; the secure button sits on top.
          if InCombatLockdown and InCombatLockdown() then
            b:Disable()
            b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Not available in combat", 1, 0.3, 0.3); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
          else
            b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
            local sb = getSecureTarget()
            sb:SetAttribute("macrotext", spec.secureMacro)
            sb:SetText(spec.text or "")
            sb:ClearAllPoints(); sb:SetAllPoints(b); sb:SetAlpha(1); sb:Show()
            secureHidePending = nil
            b:SetAlpha(0)
          end
        else
          b:SetScript("OnEnter", nil); b:SetScript("OnLeave", nil)
        end
        total = total + b:GetWidth() + 8
      else
        b:Hide()
      end
    end
    f:SetWidth(math.max(470, total + 12))
  else
    f:SetWidth(470)
    for _, b in ipairs(f.customButtons) do b:Hide() end
    f.dismissButton:Show()
    if opts.map then
      f.mapButton:Show()
      f.mapButton:SetScript("OnClick", function() FLT:ShowOnMap(opts.map) end)
    else
      f.mapButton:Hide()
    end
  end
  alertSerial = alertSerial + 1
  local mySerial = alertSerial
  f:Show()
  if C_Timer and C_Timer.After then
    C_Timer.After(ALERT_DURATION, function()
      if alertFrame and alertFrame:IsShown() and alertSerial == mySerial then alertFrame:Hide() end
    end)
  end
end

function FLT:ShowNearbyBookAlert(book, distance)
  if not book then return end
  local f = createAlertFrame()
  f.eyebrow:SetText("LIBRARY BOOK NEARBY")
  FLT.SetTex(f.icon, "Interface\\Icons\\INV_Misc_Book_09")
  f:SetWidth(470)
  f.mapButton:Show()
  f.dismissButton:Show()
  for _, b in ipairs(f.customButtons) do b:Hide() end
  f.book = book
  f.title:SetText(book.name)

  local distanceText = ""
  if distance then distanceText = string.format("  |  about %.0f yd away", distance) end
  f.where:SetText(string.format("%s  %.1f, %.1f%s", book.zone or "Unknown zone", book.x or 0, book.y or 0, distanceText))
  f.mapButton:SetScript("OnClick", function() FLT:ShowOnMap(book) end)

  alertSerial = alertSerial + 1
  local mySerial = alertSerial
  f:Show()

  if C_Timer and C_Timer.After then
    C_Timer.After(ALERT_DURATION, function()
      if alertFrame and alertFrame:IsShown() and alertSerial == mySerial then alertFrame:Hide() end
    end)
  end
end

function FLT:SetNearbyAlertsEnabled(enabled)
  OneForAllDB.nearbyAlertsEnabled = enabled and true or false
  if not enabled then
    wipe(activeNearby)
    if alertFrame then alertFrame:Hide() end
  end
  if self.UIRefresh then self:UIRefresh() end
end

function FLT:IsNearbyAlertsEnabled()
  return OneForAllDB and OneForAllDB.nearbyAlertsEnabled ~= false
end

-- The check runs once a second, so it avoids creating new tables where it
-- can: the parent maps of the current map are only looked up when the map
-- changes, the book positions are converted to world coordinates once, and
-- the player position is read once per map and tick.
local ancestorsOf, ancestorsFor = {}, nil
local bookWorldCache = {}
local function ancestors(mapID)
  if ancestorsFor == mapID then return ancestorsOf end
  ancestorsOf = {}; ancestorsFor = mapID
  local id = mapID
  for _ = 1, 8 do
    ancestorsOf[id] = true
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    if not info or not info.parentMapID or info.parentMapID == 0 or info.parentMapID == id then break end
    id = info.parentMapID
  end
  return ancestorsOf
end
local function bookWorld(book, mapID)
  local c = bookWorldCache[book.itemId]
  if c == nil then
    c = false
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
      local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(book.x / 100, book.y / 100))
      if ok and pos then
        local x, y = vecXY(pos)
        if x and y then c = { cont = cont, x = x, y = y } end
      end
    end
    bookWorldCache[book.itemId] = c
  end
  return c or nil
end

function FLT:CheckNearbyBooks()
  if not self:IsNearbyAlertsEnabled() then return end
  if not C_Map or not C_Map.GetBestMapForUnit then return end
  if IsInInstance and IsInInstance() then return end

  local currentMapID = C_Map.GetBestMapForUnit("player")
  if not currentMapID then return end
  local within = ancestors(currentMapID)
  local playerAt = {}   -- mapID -> {x, y, wx, wy, cont} for this tick

  for _, book in ipairs(self.BOOKS) do
    local nearby = false
    local distance
    if book.x and book.y and self:GetBookState(book) == "missing" then
      local mapID = self:FindMapID(book.zone)
      if mapID and within[mapID] then
        local p = playerAt[mapID]
        if p == nil then
          p = false
          local px, py, pos = getPlayerPosition(mapID)
          if px and py then
            p = { x = px, y = py }
            local ok, cont, wpos = pcall(C_Map.GetWorldPosFromMapPos, mapID, pos)
            if ok and wpos then local wx, wy = vecXY(wpos); p.wx, p.wy, p.cont = wx, wy, cont end
          end
          playerAt[mapID] = p
        end
        if p then
          local bw = p.wx and bookWorld(book, mapID)
          if bw and (not p.cont or not bw.cont or p.cont == bw.cont) then
            local dx, dy = p.wx - bw.x, p.wy - bw.y
            distance = math.sqrt(dx * dx + dy * dy)
            nearby = distance <= WORLD_RADIUS_YARDS
          else
            local dx = p.x - (book.x / 100)
            local dy = p.y - (book.y / 100)
            nearby = math.sqrt(dx * dx + dy * dy) <= MAP_RADIUS_FALLBACK
          end
        end
      end
    end
    if nearby then
      if not activeNearby[book.itemId] then
        activeNearby[book.itemId] = true
        self:ShowNearbyBookAlert(book, distance)
      end
    else
      activeNearby[book.itemId] = nil
    end
  end
end

function FLT:StartNearbyMonitor()
  if monitor then return end
  monitor = CreateFrame("Frame")
  monitor:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= CHECK_INTERVAL then
      elapsed = 0
      FLT:CheckNearbyBooks()
    end
  end)
end
