-- Books on map (Forever): optimized collection route (nearest neighbor + 2-opt, from the player's position)
local _, ns = ...
local L = ns.L
local S = ns.Skin
local BOOKS = ns.BOOKS

local CONTINENT_PENALTY = 20000 -- yards added for every boat/zeppelin trip between continents
local route = {}                -- { {book = b, loc = loc, cont = id, x = wx, y = wy}, ... }
local skipped = {}              -- book keys skipped for this session
local tracker

local worldPos, playerPos = ns.WorldPos, ns.PlayerWorldPos

local function cost(a, b)
  local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
  if a.cont ~= b.cont then d = d + CONTINENT_PENALTY end
  return d
end

local function eligible(b)
  return not ns.IsDone(b) and not skipped[b.key]
end

-- optimized path (nearest neighbor + 2-opt) through the books of one set, from start
local function planSet(set, start)
  local cands = {}
  for _, b in ipairs(BOOKS) do
    if b.set == set and eligible(b) then
      -- every location of the book; a book is done once any of its locations is visited
      for _, loc in ipairs(b.locs) do
        local c, x, y = worldPos(loc[1], loc[2] / 100, loc[3] / 100)
        if c then cands[#cands + 1] = { book = b, loc = loc, cont = c, x = x, y = y } end
      end
    end
  end

  local path, used, cur = {}, {}, start
  while true do
    local best, bestD
    for _, c in ipairs(cands) do
      if not used[c.book] then
        local d = cost(cur, c)
        if not bestD or d < bestD then best, bestD = c, d end
      end
    end
    if not best then break end
    used[best.book] = true
    path[#path + 1] = best
    cur = best
  end

  -- 2-opt (open path)
  local n, improved, guard = #path, true, 0
  local function at(i) return i == 0 and start or path[i] end
  while improved and guard < 50 do
    improved, guard = false, guard + 1
    for i = 1, n - 1 do
      for j = i + 1, n do
        local a, b, c, d = at(i - 1), path[i], path[j], path[j + 1]
        local before = cost(a, b) + (d and cost(c, d) or 0)
        local after = cost(a, c) + (d and cost(b, d) or 0)
        if after < before - 0.5 then
          for k = 0, math.floor((j - i) / 2) do
            path[i + k], path[j - k] = path[j - k], path[i + k]
          end
          improved = true
        end
      end
    end
  end
  return path
end

-- Builds the route from the player's position: every book, lowest set first,
-- each set optimized and starting where the previous one ends
function ns.BuildRoute()
  wipe(route)
  local cont, px, py = playerPos()
  local cur = { cont = cont or -1, x = px or 0, y = py or 0 }
  for _, set in ipairs({ 1, 35, 45, 60 }) do
    for _, step in ipairs(planSet(set, cur)) do
      route[#route + 1] = step
      cur = step
    end
  end
  return route
end

function ns.GetRoute() return route end

-- nearest missing book from the player: book, location, distance (yards), same continent
function ns.NearestBook()
  local cont, px, py = playerPos()
  if not cont then return end
  local here = { cont = cont, x = px, y = py }
  local best, bestLoc, bestD, bestCont
  for _, b in ipairs(BOOKS) do
    if eligible(b) then
      for _, loc in ipairs(b.locs) do
        local c, x, y = worldPos(loc[1], loc[2] / 100, loc[3] / 100)
        if c then
          local d = cost(here, { cont = c, x = x, y = y })
          if not bestD or d < bestD then best, bestLoc, bestD, bestCont = b, loc, d, c end
        end
      end
    end
  end
  if best then return best, bestLoc, bestD, bestCont == cont end
end

-- "Nearest: name - 340 yd" for the broker / minimap tooltip
function ns.NearestText()
  local b, _, d, same = ns.NearestBook()
  if not b then return end
  return ("%s - %s"):format(b.name, same and L["%d yd"]:format(math.floor(d)) or L["other continent"])
end

-- /bom next: prints the nearest book, waypoint (Shortest Path or TomTom, else opens the map there)
function ns.GoToNearest()
  local b, loc, d, same = ns.NearestBook()
  if not b then print(ns.PREFIX .. L["Every book has been collected."]) return end
  print(ns.PREFIX .. L["nearest book: %s - %s (%.1f, %.1f), %s"]:format(b.name, loc[4], loc[2], loc[3],
    same and L["%d yd"]:format(math.floor(d)) or L["other continent"]))
  if not ns.Waypoint(loc, b.name) then
    if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    WorldMapFrame:SetMapID(loc[1])
  end
end

-- step number of a book location in the route (for the map pins)
function ns.RouteStep(b, loc)
  if not ns.db.routeOn then return end
  for i, s in ipairs(route) do
    if s.book == b and s.loc == loc then return i end
  end
end

-- route button: "Guide" when Shortest Path takes the route, "TomTom" otherwise
local function waypointButtonText()
  return ns.RouteWaypointProvider() == "Shortest Path" and L["Guide"] or "TomTom"
end

-- drops the books collected since the route was built, keeping the order; true when any was dropped
local function pruneDone()
  local n = #route
  for i = n, 1, -1 do
    if ns.IsDone(route[i].book) then table.remove(route, i) end
  end
  return #route ~= n
end

-- Tracker (next book, distance, arrow) -----------------------------------
local function updateTracker()
  local s = route[1]
  if not s then
    tracker.name:SetText(L["Route finished!"])
    tracker.where:SetText(L["Every book has been collected."])
    tracker.dist:SetText("")
    tracker.arrow:Hide()
    return
  end
  tracker.name:SetText(("|cff5cc8ff%d/%d|r  %s"):format(1, #route, s.book.name))
  tracker.where:SetText(("%s  |cff808080(%.1f, %.1f)|r"):format(s.loc[4], s.loc[2], s.loc[3]))
  local cont, px, py = playerPos()
  if cont and cont == s.cont then
    local dx, dy = s.x - px, s.y - py
    tracker.dist:SetText(L["%d yd"]:format(math.floor(math.sqrt(dx * dx + dy * dy))))
    local facing = GetPlayerFacing and GetPlayerFacing()
    if facing then
      tracker.arrow:SetRotation(math.atan2(dy, dx) - facing)
      tracker.arrow:Show()
    else
      tracker.arrow:Hide()
    end
  else
    tracker.dist:SetText(L["other continent"])
    tracker.arrow:Hide()
  end
end

local function smallButton(parent, text, onClick)
  return S.Button(parent, text, 66, 20, onClick)
end

local function createTracker()
  local f = CreateFrame("Frame", "BooksOnMapForeverRoute", UIParent)
  f:SetSize(290, 96)
  S.Shadow(f, 12, 0.5, { 0.12, 0.4, 0.95 })
  S.Rounded(f, 12)
  S.EdgeGlow(f, 48, 0.15)
  f:SetClampedToScreen(true)
  S.Draggable(f, f, function(self)
    local p, _, rp, x, y = self:GetPoint()
    ns.db.routePos = { p, rp, x, y }
  end)
  local pos = ns.db.routePos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("TOP", 0, -120) end

  -- accent strip on the left edge
  local strip = f:CreateTexture(nil, "ARTWORK")
  strip:SetPoint("TOPLEFT", 1, -12)
  strip:SetPoint("BOTTOMLEFT", 1, 12)
  strip:SetWidth(2)
  strip:SetColorTexture(S.Color(S.C.accent))

  local icon = S.Icon(f, 34)
  icon:SetPoint("TOPLEFT", 14, -12)
  f.icon = icon.tex

  f.arrow = f:CreateTexture(nil, "ARTWORK")
  f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.arrow:SetSize(30, 30)
  f.arrow:SetPoint("TOPRIGHT", -14, -8)

  f.name = S.Text(f, 13)
  f.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -1)
  f.name:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
  f.name:SetWordWrap(false)

  f.where = S.Text(f, 11, "muted")
  f.where:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
  f.where:SetPoint("RIGHT", f.arrow, "LEFT", -4, 0)
  f.where:SetWordWrap(false)

  f.dist = S.Text(f, 11, "accent")
  f.dist:SetPoint("TOPRIGHT", f.arrow, "BOTTOMRIGHT", 0, -2)
  f.dist:SetJustifyH("RIGHT")

  local skip = smallButton(f, L["Skip"], function()
    if route[1] then skipped[route[1].book.key] = true end
    ns.RefreshRoute(true)
  end)
  skip:SetPoint("BOTTOMLEFT", 14, 12)
  local recalc = smallButton(f, L["Recalc"], function() wipe(skipped); ns.RefreshRoute(true) end)
  recalc:SetPoint("LEFT", skip, "RIGHT", 4, 0)
  local tt = smallButton(f, waypointButtonText(), function() ns.SendRouteWaypoints(route) end)
  tt:SetPoint("LEFT", recalc, "RIGHT", 4, 0)
  f.waypoints = tt
  local close = S.CloseButton(f, function() ns.ToggleRoute(false) end)
  close:SetPoint("BOTTOMRIGHT", -10, 11)

  local elapsed = 0
  f:SetScript("OnUpdate", function(_, e)
    elapsed = elapsed + e
    if elapsed < 0.1 then return end
    elapsed = 0
    updateTracker()
  end)
  return f
end

-- rebuild = recompute the order from the current position
function ns.RefreshRoute(rebuild)
  if not ns.db or not ns.db.routeOn then return end
  tracker = tracker or createTracker()
  local changed = true
  if rebuild or not route[1] or ns.IsDone(route[1].book) then
    ns.BuildRoute()
  else
    changed = pruneDone() -- a book further along was collected first
  end
  -- keep Shortest Path's guidance in step with the new order
  if changed then ns.SyncRouteWaypoints(route) end
  local s = route[1]
  tracker.icon:SetTexture(s and s.book.icon and ("Interface\\Icons\\" .. s.book.icon) or ns.ICON)
  tracker.waypoints:SetText(waypointButtonText())
  tracker:Show()
  updateTracker()
  ns.RefreshMap()
end

function ns.ToggleRoute(on)
  if on == nil then on = not ns.db.routeOn end
  ns.db.routeOn = on or nil
  if on then
    ns.RefreshRoute(true)
    print(ns.PREFIX .. L["route: %d books, lowest level first."]:format(#route))
  else
    wipe(route)
    ns.CancelRouteWaypoints()
    if tracker then tracker:Hide() end
    ns.RefreshMap()
  end
end

function ns.PrintRoute()
  if not ns.db.routeOn then ns.ToggleRoute(true) end
  for i, s in ipairs(route) do
    print(("|cffffd100%2d.|r %s - %s (%.1f, %.1f)"):format(i, s.book.name, s.loc[4], s.loc[2], s.loc[3]))
  end
end

-- /bom route guide|tomtom: sends the route (turned on first if needed); forceTomTom = skip Shortest Path
function ns.GuideRoute(forceTomTom)
  if not ns.db.routeOn then ns.ToggleRoute(true) end
  ns.SendRouteWaypoints(route, forceTomTom)
end

function ns.InitRoute()
  if ns.db.routeOn then ns.RefreshRoute(true) end
end
