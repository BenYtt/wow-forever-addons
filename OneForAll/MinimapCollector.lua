local _, FLT = ...
local UI = FLT.UI
local unpack = unpack or table.unpack

-- Quality of Life "Collect minimap buttons": the minimap buttons of other addons
-- move into one bar that opens from a free floating "1" button. The button is
-- not tied to the minimap and can be dragged anywhere. Switching it off puts
-- every button back where it was. Blizzard's own minimap elements (tracking,
-- mail, calendar, zoom ...) and map pins are left alone.
-- Setting: QoL "mmCollect"; position: OneForAllDB.qol.mmCollectPos.

local collector, bar
local collected = {}   -- frame -> saved state while it sits in the bar
local hooked = {}      -- frames that already have our OnShow/OnHide hooks
local PER_ROW = 8
local SLOT = 34
local PAD = 6      -- left / right
local PADY = 4     -- top / bottom: one row is exactly as high as the 42 px button
local SCALE = 0.9  -- button and bar 10 % smaller than designed (user 16.10.)

-- the real methods, taken from a plain frame (collected buttons get no-op
-- SetPoint/ClearAllPoints so their own addon cannot pull them back)
local probe = CreateFrame("Frame")
local realSetPoint, realClearAllPoints = probe.SetPoint, probe.ClearAllPoints
local function noop() end

-- names of Blizzard minimap parts and of map pins, never collected
local SKIP_PREFIX = {
  "MiniMap", "Minimap", "GameTimeFrame", "TimeManager", "QueueStatus", "GarrisonLandingPage",
  "ExpansionLandingPage", "LFGMinimap", "BattlefieldMinimap", "AddonCompartment", "HelpOpenWeb",
  "FeedbackUIButton", "OneForAll",
}
local SKIP_WORD = { "Pin", "Questie", "HandyNotes", "GatherMate", "TomTom", "Arrow", "Ping", "Blip", "Node", "Icon%d+$" }

local function qol() return FLT.QoL end
local function enabled() return qol() and qol().Get("mmCollect") and true or false end
local function db()
  if type(OneForAllDB) ~= "table" then return nil end
  OneForAllDB.qol = OneForAllDB.qol or {}
  return OneForAllDB.qol
end

local function isCandidate(f)
  if not f or collected[f] or f == collector or f == bar then return false end
  if f.IsForbidden and f:IsForbidden() then return false end
  local name = f.GetName and f:GetName()
  if type(name) ~= "string" or name == "" then return false end
  if name:find("^LibDBIcon10_") then return true end
  -- D4Lib buttons (MapUtils, ImproveAny ... by D4KiR): "MinimapButton_D4Lib_LibDBIcon_<name>"; they start with
  -- "Minimap" and fell through SKIP_PREFIX (user 25.10.)
  if name:find("^MinimapButton_") and name:find("LibDBIcon", 1, true) then return true end
  for _, p in ipairs(SKIP_PREFIX) do if name:sub(1, #p) == p then return false end end
  for _, w in ipairs(SKIP_WORD) do if name:find(w) then return false end end
  local clickable = (f.IsObjectType and f:IsObjectType("Button"))
    or (f.HasScript and f:HasScript("OnMouseUp") and f:GetScript("OnMouseUp"))
  if not clickable then return false end
  local w, h = f:GetWidth() or 0, f:GetHeight() or 0
  if w < 18 or w > 48 or h < 18 or h > 48 or math.abs(w - h) > 10 then return false end
  return true
end

local function sortedFrames()
  local list = {}
  for f in pairs(collected) do list[#list + 1] = f end
  table.sort(list, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
  return list
end

local layout -- below

local function hookFrame(f)
  if hooked[f] or not f.HookScript then return end
  hooked[f] = true
  f:HookScript("OnShow", function() if collected[f] then layout() end end)
  f:HookScript("OnHide", function() if collected[f] then layout() end end)
  if f.HasScript and f:HasScript("OnDragStop") then
    f:HookScript("OnDragStop", function() if collected[f] then layout() end end)
  end
end

local function collect(f)
  local s = { parent = f:GetParent(), scale = f:GetScale(), strata = f:GetFrameStrata(), level = f:GetFrameLevel(), points = {} }
  -- many buttons (LibDBIcon) fix strata and level; unfix them while they sit in the bar
  if f.IsFrameStrataFixed and f.SetFixedFrameStrata then s.fixedStrata = f:IsFrameStrataFixed(); f:SetFixedFrameStrata(false) end
  if f.IsFrameLevelFixed and f.SetFixedFrameLevel then s.fixedLevel = f:IsFrameLevelFixed(); f:SetFixedFrameLevel(false) end
  for i = 1, (f:GetNumPoints() or 0) do s.points[i] = { f:GetPoint(i) } end
  collected[f] = s
  f.SetPoint, f.ClearAllPoints = noop, noop
  f:SetParent(bar)
  f:SetFrameStrata("MEDIUM"); f:SetFrameLevel(math.max(bar:GetFrameLevel() + 5, f:GetFrameLevel() or 0))
  if f.SetAlpha then f:SetAlpha(1) end
  local size = math.max(f:GetWidth() or 31, f:GetHeight() or 31)
  f:SetScale(size > 0 and math.min(1, 31 / size) or 1)
  hookFrame(f)
end

local function release(f)
  local s = collected[f]; if not s then return end
  collected[f] = nil
  f.SetPoint, f.ClearAllPoints = nil, nil
  f:SetParent(s.parent or Minimap)
  f:SetScale(s.scale or 1)
  if s.strata then f:SetFrameStrata(s.strata) end
  if s.level then f:SetFrameLevel(s.level) end
  if s.fixedStrata then f:SetFixedFrameStrata(true) end
  if s.fixedLevel then f:SetFixedFrameLevel(true) end
  f:ClearAllPoints()
  for _, p in ipairs(s.points) do pcall(f.SetPoint, f, unpack(p)) end
end

local function scan()
  if not enabled() or not bar then return end
  local found = false
  for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
    if type(parent) == "table" and parent.GetChildren then
      for _, f in ipairs({ parent:GetChildren() }) do
        if isCandidate(f) then collect(f); found = true end
      end
    end
  end
  if found then layout() end
end

layout = function()
  if not bar then return end
  local list = {}
  for _, f in ipairs(sortedFrames()) do if f:IsShown() then list[#list + 1] = f end end
  local n = #list
  local dir = qol() and qol().Get("mmDir") or "auto"
  local vertical = dir == "top" or dir == "bottom"
  -- opening up or down: one column, otherwise rows of PER_ROW
  local perLine = PER_ROW
  local cols = math.max(1, math.min(perLine, n))
  local rows = math.max(1, math.ceil(n / perLine))
  if vertical then cols, rows = rows, cols end
  bar:SetSize(cols * SLOT + PAD * 2, rows * SLOT + PADY * 2)
  bar.empty:SetShown(n == 0)
  if n == 0 then bar:SetSize(220, 42) end
  -- open towards the middle of the screen
  local cx, cy = collector:GetCenter()
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  local left = cx and sw and cx > sw / 2
  local down = cy and sh and cy > sh / 2
  realClearAllPoints(bar)
  if dir == "top" then realSetPoint(bar, "BOTTOM", collector, "TOP", 0, 4)
  elseif dir == "bottom" then realSetPoint(bar, "TOP", collector, "BOTTOM", 0, -4)
  else
    if dir == "left" then left = true elseif dir == "right" then left = false end
    local vp = rows == 1 and "" or (down and "TOP" or "BOTTOM")
    if left then realSetPoint(bar, vp .. "RIGHT", collector, vp .. "LEFT", -4, 0)
    else realSetPoint(bar, vp .. "LEFT", collector, vp .. "RIGHT", 4, 0) end
  end
  for i, f in ipairs(list) do
    local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
    if vertical then col, row = row, col end
    local sc = f:GetScale() or 1
    realClearAllPoints(f)
    realSetPoint(f, "CENTER", bar, "TOPLEFT", (PAD + col * SLOT + SLOT / 2) / sc, -(PADY + row * SLOT + SLOT / 2) / sc)
  end
end

local function savePos()
  local d = db(); if not d or not collector then return end
  local p, _, rp, x, y = collector:GetPoint(1)
  d.mmCollectPos = { p, rp, x, y, SCALE } -- offsets are in the button's scale
end

local function placeCollector()
  local d = db()
  local pos = d and d.mmCollectPos
  collector:ClearAllPoints()
  -- positions saved before 5.6.2 were taken at scale 1: same place on screen at the new scale
  local k = (pos and pos[5]) and 1 or (1 / SCALE)
  if pos and pos[1] then collector:SetPoint(pos[1], UIParent, pos[2] or pos[1], (pos[3] or 0) * k, (pos[4] or 0) * k)
  else collector:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -232, -36) end
end

local function toggleBar()
  if bar:IsShown() then bar:Hide(); return end
  scan(); layout(); bar:Show()
end

local function create()
  if collector then return end
  collector = CreateFrame("Button", "OneForAllMinimapCollector", UIParent)
  collector:SetSize(34, 42); collector:SetScale(SCALE) -- the card logo (5.7.3, user 26.10.)
  collector:SetFrameStrata("MEDIUM"); collector:SetFrameLevel(20)
  collector:SetMovable(true); collector:SetClampedToScreen(true)
  collector:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  collector:RegisterForDrag("LeftButton")
  -- soft round shadow around the gold ring
  -- the card logo in the chosen color (QoL "logoColor"); the picture sits in the middle 46 of 64 pixels
  local icon = collector:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints()
  icon:SetTexture(FLT.LogoTexture and FLT.LogoTexture("card") or (UI.ASSET_ROOT .. "logo_card_teal")); icon:SetTexCoord(9 / 64, 55 / 64, 0, 1)
  if FLT.TintLogo then FLT.TintLogo(icon) end
  FLT.collectorIcon = icon
  local hi = collector:CreateTexture(nil, "HIGHLIGHT"); hi:SetAllPoints()
  hi:SetTexture(icon:GetTexture() or (UI.ASSET_ROOT .. "logo_card_teal")); hi:SetTexCoord(9 / 64, 55 / 64, 0, 1); hi:SetBlendMode("ADD"); hi:SetAlpha(0.3)
  if FLT.TintLogo then FLT.TintLogo(hi) end
  FLT.collectorHi = hi

  bar = CreateFrame("Frame", "OneForAllMinimapCollectorBar", UIParent)
  -- MEDIUM like LibDBIcon buttons (their strata/level may be fixed), low level so they draw on top
  bar:SetFrameStrata("MEDIUM"); bar:SetFrameLevel(2); bar:SetClampedToScreen(true); bar:EnableMouse(true); bar:Hide()
  bar:SetScale(SCALE)
  -- smooth gold rim like the ring of the OneForAll button, dark inside
  if UI.RoundRect then
    UI.RoundRect(bar, bar, "BACKGROUND", 0, 10, 0, 0.95, 0.76, 0.32, 1)     -- thin gold rim
    UI.RoundRect(bar, bar, "BACKGROUND", 1, 9, 1.5, 0.06, 0.05, 0.04, 0.97) -- dark inside
  else
    UI.FramedPanel(bar)
  end
  bar.empty = FLT.NewFS(bar, nil, "OVERLAY", "GameFontDisableSmall"); bar.empty:SetPoint("CENTER")
  bar.empty:SetText("No minimap buttons of other addons found.")

  collector:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      if IsShiftKeyDown and IsShiftKeyDown() then if FLT.CraftList then FLT.CraftList.Toggle() end -- user 24.10.
      elseif FLT.ToggleUI then FLT:ToggleUI() end
      return
    end
    toggleBar()
  end)
  collector:SetScript("OnDragStart", function(self) if bar:IsShown() then bar:Hide() end; self:StartMoving() end)
  collector:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePos() end)
  collector:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(FLT.DISPLAY_NAME or "OneForAll", 1, 0.82, 0)
    GameTooltip:AddLine("Left-click: Minimap buttons", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Open / close OneForAll", 1, 1, 1)
    GameTooltip:AddLine("Shift-right-click: Crafting List", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move", 0.75, 0.75, 0.75)
    GameTooltip:Show()
  end)
  collector:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeCollector()
end

-- switch on / off (also called after login and when our own minimap button is made)
function FLT.MinimapCollectorRefresh()
  local own = FLT.minimapButton
  if enabled() then
    create()
    collector:Show()
    if own then own:Hide() end
    scan()
  else
    if bar then bar:Hide() end
    if collector then collector:Hide() end
    for _, f in ipairs(sortedFrames()) do release(f) end
    -- QoL "mmHide" (5.7.3, user 23.10., off by default): no button of ours at the minimap; OneForAll stays
    -- reachable from the game's AddOns list at the minimap and /ofa. With the collector on, its button stays.
    if own then own:SetShown(not (qol() and qol().Get("mmHide"))) end
  end
end

-- /ofa buttons: what the collector found (for bug reports)
function FLT.PrintMinimapCollector()
  local say = FLT.Msg or print
  if not bar then say("Minimap button collector is off."); return end
  say(("Collector bar: strata %s, level %d, shown %s"):format(bar:GetFrameStrata(), bar:GetFrameLevel(), tostring(bar:IsShown())))
  for _, f in ipairs(sortedFrames()) do
    local p, _, _, x, y = f:GetPoint(1)
    say(("  %s: shown %s, alpha %.2f, strata %s, level %d, scale %.2f, point %s %.0f %.0f, parent ok %s"):format(
      f:GetName() or "?", tostring(f:IsShown()), f:GetAlpha() or 0, f:GetFrameStrata() or "?", f:GetFrameLevel() or 0,
      f:GetScale() or 0, tostring(p), x or 0, y or 0, tostring(f:GetParent() == bar)))
  end
end

function FLT.ResetMinimapCollector()
  local d = db(); if d then d.mmCollectPos = nil end
  if collector then placeCollector(); if bar:IsShown() then layout() end end
end

-- buttons of other addons appear at different times after login: look again a few times
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
local pending = false
local function onEventSafe(_, event)
  if event == "PLAYER_LOGIN" then
    if C_Timer and C_Timer.After then
      C_Timer.After(1, FLT.MinimapCollectorRefresh)
      C_Timer.After(5, scan)
      C_Timer.After(15, scan)
    else
      FLT.MinimapCollectorRefresh()
    end
  elseif event == "ADDON_LOADED" and enabled() and collector and not pending and C_Timer and C_Timer.After then
    pending = true
    C_Timer.After(2, function() pending = false; scan() end)
  end
end
ev:SetScript("OnEvent", function(...) FLT.SafeCall("Collector", onEventSafe, ...) end)

if FLT.QoL and FLT.QoL.On then
  FLT.QoL.On("mmCollect", FLT.MinimapCollectorRefresh); FLT.QoL.On("mmHide", FLT.MinimapCollectorRefresh)
  FLT.QoL.On("mmDir", function() if bar and bar:IsShown() then layout() end end)
end
