-- Finds leyline / convergence blips on the minimap without the mouse. The minimap's soft cursor
-- (made for controllers) can be pointed at any spot and asked for the tooltip it would show there.
-- A coarse grid finds blips, then a fine grid over each one puts its centre within a few yards.
-- Approach described to us by the author of Skyborne Compass.
--
-- With a controller the game drives that soft cursor itself, so instead of scanning we watch whatever
-- points at the minimap (the mouse, or the controller's SoftCursor) and record a blip it passes over.

local ADDON, ns = ...

local NAMES = { "Leyline", "Ley Line", "Elemental Convergence" } -- minimap tooltip text; English only.
-- "Leyline" since 2026-10-18 (was "Ley Line")
local CHECK_SECONDS = 2    -- how often to decide whether to scan
local MOVE_YARDS = 30      -- scan after moving this far
local IDLE_SECONDS = 60    -- or after this long standing still: a node can come up next to you
local COARSE_STEP = 8      -- minimap units between coarse points; a blip is wider than this
local FINE_STEP = 2
local PER_FRAME = 60       -- coarse points per frame, so the scan doesn't stutter
local FINE_PER_FRAME = 150 -- fine points per frame
local HOVER_SECONDS = 0.1  -- controller / fallback: how often to look at the pointer
local MAX_SAMPLE_YARDS = 60 -- a hover reading spread wider than this (moved, tooltip lingered) is dropped

local frame = CreateFrame("Frame")
frame:Hide()
local scan -- the scan in progress: { mapID, points, i, hits, blips, b }
local last -- where and when the last scan ran: { mapID, x, y, zoom, at }

local function Supported()
  return Minimap.SetUsingSoftCursor and Minimap.UpdateMouseoverAtPoint and C_TooltipInfo
    and C_TooltipInfo.GetMinimapMouseover and C_Minimap and C_Minimap.GetViewRadius
end

local function Strip(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

local function IsNodeText(text)
  if type(text) ~= "string" then return end
  text = Strip(text)
  for _, name in ipairs(NAMES) do
    if text:find(name, 1, true) then return true end
  end
end

-- Does this tooltip data name a node? One tooltip can list several dots.
local function HasNode(data)
  for _, line in ipairs(data and data.lines or {}) do
    if IsNodeText(line.leftText) then return true end
  end
end

-- Is there a node blip at this point (minimap units from its bottom left)?
local function NodeAt(lx, ly)
  local s = Minimap:GetEffectiveScale()
  Minimap:UpdateMouseoverAtPoint((Minimap:GetLeft() + lx) * s, (Minimap:GetBottom() + ly) * s)
  local data = C_TooltipInfo.GetMinimapMouseover()
  if scan and scan.texts then -- /sllcm scan: every tooltip line the scan saw
    for _, line in ipairs(data and data.lines or {}) do
      if type(line.leftText) == "string" then scan.texts[Strip(line.leftText)] = true end
    end
  end
  return HasNode(data)
end

-- Runs fn with the soft cursor on, and always turns it back off
local function WithSoftCursor(fn)
  Minimap:SetUsingSoftCursor(true)
  local ok, err = pcall(fn)
  Minimap:SetUsingSoftCursor(false)
  if not ok and scan then scan.err = err end
  return ok
end

local function PlayerPos()
  local mapID = C_Map.GetBestMapForUnit("player")
  local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if pos then return mapID, pos.x, pos.y end
end

-- A minimap point to zone coordinates, from the player's position now
local function ToZone(lx, ly)
  local mapID, px, py = PlayerPos()
  local zw, zh
  if mapID then zw, zh = ns.ZoneSizeYards(mapID) end
  if not zw then return end
  local w, h = Minimap:GetSize()
  local ypp = C_Minimap.GetViewRadius() / (w / 2)
  local dx, dy = (lx - w / 2) * ypp, (ly - h / 2) * ypp -- yards; +x east, +y north
  if GetCVar("rotateMinimap") == "1" then
    local f = GetPlayerFacing() or 0
    dx, dy = dx * math.cos(f) - dy * math.sin(f), dx * math.sin(f) + dy * math.cos(f)
  end
  local x, y = px + dx / zw, py - dy / zh
  if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return mapID, x, y end
end

-- A controller is in use: it owns the minimap's soft cursor, so we must not switch it on and off. Not the
-- GamePadEnable CVar: it can be on for players who have never touched a controller.
local function Controller()
  return (InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled())
    or (SoftCursor and SoftCursor:IsShown())
end

-- Scan, or (controller, or a client without the APIs) watch the pointer instead
local function Scanning()
  return Supported() and not Controller()
end

-- For LeyLineTest: true while this addon reads the minimap itself, so its own hover recording stands down
function SLLCM_MinimapDetection()
  return ns.ScanEnabled() and true or false
end

-- why: set when a scan is cut short; reported by /sllcm scan
local function Stop(why)
  local s = scan
  scan = nil
  frame:Hide()
  if not (s and s.verbose) then return end
  local texts = {}
  for t in pairs(s.texts) do texts[#texts + 1] = t end
  ns.Print("scan %s: %d of %d points done, %d hit(s), %d blip(s)", why or "finished", math.min(s.i - 1, #s.points),
    #s.points, #s.hits, #s.blips)
  if s.err then ns.Print("error: %s", tostring(s.err)) end
  ns.Print("tooltip text seen: %s", #texts > 0 and table.concat(texts, " / ") or "none")
end

local function Blocked()
  return InCombatLockdown() or not Minimap:IsVisible() or Minimap:IsMouseOver()
end

-- Touching coarse hits (diagonals too) are one blip: its tooltip area is wider than the coarse step, by how
-- much depends on the minimap's size and scale. Each blip gets a fine grid over its hits' box, widened by a
-- coarse step each way (the area ends somewhere before the next coarse point out).
local function Blips(hits)
  local at, blips = {}, {}
  for _, h in ipairs(hits) do at[h.i .. ":" .. h.j] = h end
  for _, h in ipairs(hits) do
    if not h.seen then
      local x0, x1, y0, y1 = h[1], h[1], h[2], h[2]
      local stack = { h }
      h.seen = true
      while #stack > 0 do
        local c = table.remove(stack)
        x0, x1, y0, y1 = math.min(x0, c[1]), math.max(x1, c[1]), math.min(y0, c[2]), math.max(y1, c[2])
        for di = -1, 1 do
          for dj = -1, 1 do
            local nb = at[(c.i + di) .. ":" .. (c.j + dj)]
            if nb and not nb.seen then
              nb.seen = true
              stack[#stack + 1] = nb
            end
          end
        end
      end
      local points = {}
      for x = x0 - COARSE_STEP, x1 + COARSE_STEP, FINE_STEP do
        for y = y0 - COARSE_STEP, y1 + COARSE_STEP, FINE_STEP do points[#points + 1] = { x, y } end
      end
      blips[#blips + 1] = { points = points, i = 1, sx = 0, sy = 0, n = 0 }
    end
  end
  return blips
end

frame:SetScript("OnUpdate", function()
  if not scan then return Stop() end
  -- the player's own mouse on the minimap wins; a zone change makes the hits meaningless
  if Blocked() then return Stop("stopped (combat, minimap hidden or mouse on it)") end
  if C_Map.GetBestMapForUnit("player") ~= scan.mapID then return Stop("stopped (zone changed)") end

  if scan.i <= #scan.points then
    -- coarse pass
    local ok = WithSoftCursor(function()
      for i = scan.i, math.min(scan.i + PER_FRAME - 1, #scan.points) do
        local p = scan.points[i]
        if NodeAt(p[1], p[2]) then scan.hits[#scan.hits + 1] = p end
      end
    end)
    if not ok then return Stop("failed") end
    scan.i = scan.i + PER_FRAME
    if scan.i > #scan.points then scan.blips = Blips(scan.hits) end
    return
  end

  -- fine pass: the blip's centre is the centre of the points that show its tooltip
  local blip = scan.blips[scan.b]
  if not blip then return Stop() end
  local ok = WithSoftCursor(function()
    for i = blip.i, math.min(blip.i + FINE_PER_FRAME - 1, #blip.points) do
      local p = blip.points[i]
      if NodeAt(p[1], p[2]) then blip.sx, blip.sy, blip.n = blip.sx + p[1], blip.sy + p[2], blip.n + 1 end
    end
  end)
  if not ok then return Stop("failed") end
  blip.i = blip.i + FINE_PER_FRAME
  if blip.i <= #blip.points then return end
  scan.b = scan.b + 1
  local n, sx, sy = blip.n, blip.sx, blip.sy
  if n > 0 then
    local mapID, x, y = ToZone(sx / n, sy / n)
    if scan.verbose then
      -- where we stood and how far off the blip was, to check the yards-per-unit scale against a known node
      local _, px, py = PlayerPos()
      local w, h = Minimap:GetSize()
      local ypp = C_Minimap.GetViewRadius() / (w / 2)
      local ox, oy = (sx / n - w / 2) * ypp, (sy / n - h / 2) * ypp
      ns.Print("blip at minimap %.1f, %.1f (%d points, %.0f yd E, %.0f yd N of you, %.0f yd away; you at %.2f, %.2f) -> %s",
        sx / n, sy / n, n, ox, oy, math.sqrt(ox * ox + oy * oy), (px or 0) * 100, (py or 0) * 100,
        mapID and format("map %d %.2f, %.2f", mapID, x * 100, y * 100) or "off the zone map")
    end
    if mapID then ns.OnMinimapNode(mapID, x, y) end
  end
end)

-- Coarse grid centred on the minimap, clipped to its round shape unless an addon made it square. i, j
-- are grid indexes, so Blips can find neighbours.
local function CoarsePoints()
  local w, h = Minimap:GetSize()
  local cx, cy, r = w / 2, h / 2, math.min(w, h) / 2
  local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
  local points, n = {}, math.floor(r / COARSE_STEP)
  for i = -n, n do
    for j = -n, n do
      local ox, oy = i * COARSE_STEP, j * COARSE_STEP
      if square or ox * ox + oy * oy <= r * r then points[#points + 1] = { cx + ox, cy + oy, i = i, j = j } end
    end
  end
  return points
end

local function MaybeScan()
  if scan or not Supported() or not ns.ScanEnabled() or Blocked() then return end
  if IsInInstance() or not Scanning() then return end
  local mapID, x, y = PlayerPos()
  local zw, zh
  if mapID then zw, zh = ns.ZoneSizeYards(mapID) end
  if not zw then return end
  local zoom, now = Minimap:GetZoom(), GetTime()
  if last and last.mapID == mapID and last.zoom == zoom and now - last.at < IDLE_SECONDS
      and math.sqrt(((last.x - x) * zw) ^ 2 + ((last.y - y) * zh) ^ 2) < MOVE_YARDS then
    return
  end
  last = { mapID = mapID, x = x, y = y, zoom = zoom, at = now }
  scan = { mapID = mapID, points = CoarsePoints(), i = 1, hits = {}, blips = {}, b = 1 }
  frame:Show()
end

C_Timer.NewTicker(CHECK_SECONDS, MaybeScan)

-- /sllcm scan (dev): why scanning would or wouldn't run, then one scan now that reports what it saw
function ns.ScanCommand()
  local function yn(v) return v and "yes" or "no" end
  local db = ns.GetDB()
  ns.Print("APIs: SetUsingSoftCursor %s, UpdateMouseoverAtPoint %s, GetMinimapMouseover %s, GetViewRadius %s",
    yn(Minimap.SetUsingSoftCursor), yn(Minimap.UpdateMouseoverAtPoint),
    yn(C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover), yn(C_Minimap and C_Minimap.GetViewRadius))
  ns.Print("setting %s, Skyborne %s, gamepad UI %s, controller cursor %s, combat %s, instance %s, mouse on minimap %s",
    yn(db and db.minimapScan), yn(select(2, UnitRace("player")) == "Skyborne"),
    yn(InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()),
    yn(SoftCursor and SoftCursor:IsShown()), yn(InCombatLockdown()),
    yn(IsInInstance()), yn(Minimap:IsMouseOver()))
  local w, h = Minimap:GetSize()
  ns.Print("minimap %.0fx%.0f at %.0f, %.0f, scale %.2f, shape %s, view radius %s yd, zoom %s, rotate %s",
    w, h, Minimap:GetLeft() or -1, Minimap:GetBottom() or -1, Minimap:GetEffectiveScale(),
    tostring(GetMinimapShape and GetMinimapShape() or "none"),
    tostring(C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()), tostring(Minimap:GetZoom()),
    GetCVar("rotateMinimap"))
  if not Scanning() then
    ns.Print("not scanning: %s", Supported() and "controller mode (pointer watching instead)" or "APIs missing")
    return
  end
  local mapID = PlayerPos()
  if scan or not mapID or Blocked() then
    ns.Print("can't scan right now (%s)", scan and "one already running" or not mapID and "no map position"
      or "combat, minimap hidden or mouse on it")
    return
  end
  last = nil
  MaybeScan()
  if scan then scan.verbose, scan.texts = true, {} else ns.Print("scan didn't start (setting off or not Skyborne?)") end
end

---------------------------------------------------------------------------
-- Pointer watching (controller, or no scan APIs). The tooltip appears as the pointer reaches the blip's
-- edge, so readings are kept while it stays up and the centre of their box is recorded when it goes.
---------------------------------------------------------------------------

local sample

-- Where the pointer is on the minimap (minimap units from its bottom left): the mouse, or the
-- controller's SoftCursor
local function PointerOnMinimap()
  local s, left, bottom = Minimap:GetEffectiveScale(), Minimap:GetLeft(), Minimap:GetBottom()
  if not left then return end
  if Minimap:IsMouseOver() then
    local cx, cy = GetCursorPosition()
    return cx / s - left, cy / s - bottom
  end
  local cursor = SoftCursor
  if cursor and cursor:IsShown() then
    local cx, cy = cursor:GetCenter()
    if not cx then return end
    local f = cursor:GetEffectiveScale() / s
    local lx, ly = cx * f - left, cy * f - bottom
    local w, h = Minimap:GetSize()
    if lx >= 0 and ly >= 0 and lx <= w and ly <= h then return lx, ly end
  end
end

-- The minimap's own tooltip data, or failing that GameTooltip's lines (the pointer is on the minimap)
local function HoverShowsNode()
  local data = C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover and C_TooltipInfo.GetMinimapMouseover()
  if data and data.lines and #data.lines > 0 then return HasNode(data) end
  if not GameTooltip:IsShown() then return end
  for i = 1, GameTooltip:NumLines() do
    local line = _G["GameTooltipTextLeft" .. i]
    if line and IsNodeText(line:GetText()) then return true end
  end
end

local function FinishSample()
  if not sample then return end
  local s = sample
  sample = nil
  local zw, zh = ns.ZoneSizeYards(s.mapID)
  if not zw or (s.x1 - s.x0) * zw > MAX_SAMPLE_YARDS or (s.y1 - s.y0) * zh > MAX_SAMPLE_YARDS then return end
  ns.OnMinimapNode(s.mapID, (s.x0 + s.x1) / 2, (s.y0 + s.y1) / 2)
end

local function Watch()
  if Scanning() or not ns.ScanEnabled() then return FinishSample() end
  local lx, ly = PointerOnMinimap()
  local ok, node = pcall(HoverShowsNode) -- tooltip text can be secret in combat
  if not (lx and ok and node) then return FinishSample() end
  local mapID, x, y = ToZone(lx, ly)
  if not mapID then return end
  if sample and sample.mapID ~= mapID then FinishSample() end
  if not sample then
    sample = { mapID = mapID, x0 = x, x1 = x, y0 = y, y1 = y }
  else
    sample.x0, sample.x1 = math.min(sample.x0, x), math.max(sample.x1, x)
    sample.y0, sample.y1 = math.min(sample.y0, y), math.max(sample.y1, y)
  end
end

C_Timer.NewTicker(HOVER_SECONDS, Watch)
