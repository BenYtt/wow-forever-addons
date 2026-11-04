-- Books on map (Forever): waypoints through Shortest Path Forever (preferred) or TomTom
local ADDON, ns = ...
local L = ns.L

-- Shortest Path Forever's public API (docs/api.md in its repository), or nil
-- when it isn't loaded or speaks another major version
local function spf()
  local addon = ShortestPathForever
  local api = type(addon) == "table" and addon.API
  if type(api) == "table" and api.version == 1 then return api end
end

local function has(api, name) return api and type(api[name]) == "function" end

-- Shortest Path's API when it can take a whole route, or nil
local function routeApi()
  local api = spf()
  if has(api, "NavigateRoute") then return api end
end

-- the real TomTom addon (Shortest Path defines a TomTom global of its own when TomTom is absent,
-- which keeps a single waypoint at a time)
local function realTomTom()
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  return TomTom and loaded and loaded("TomTom")
end

-- loc = {uiMapID, x, y, place} with 0-100 coordinates
local function addTomTom(loc, title)
  TomTom:AddWaypoint(loc[1], loc[2] / 100, loc[3] / 100, { title = title })
end

-- our last journey in Shortest Path was the whole route, not one book
local guidingRoute = false

-- name of the addon that will receive a single waypoint, or nil when none is installed
function ns.WaypointProvider()
  if has(spf(), "Navigate") then return "Shortest Path" end
  if TomTom then return "TomTom" end -- the real one or Shortest Path's stand-in
end

-- name of the addon that will receive the whole route, or nil when none can
function ns.RouteWaypointProvider()
  if routeApi() then return "Shortest Path" end
  if realTomTom() then return "TomTom" end
end

-- tooltip line for the right-click action, or nil when it does nothing
function ns.WaypointHint()
  local provider = ns.WaypointProvider()
  if provider then return L["Right-click: %s waypoint"]:format(provider) end
end

local function notStarted()
  print(ns.PREFIX .. L["Shortest Path could not start guiding (in combat, or its journeys are turned off)."])
end

-- guides to one book location; true when sent
function ns.Waypoint(loc, title)
  if not loc then return false end
  local api = spf()
  if has(api, "Navigate") then
    if api.Navigate(ADDON, loc[1], loc[2] / 100, loc[3] / 100, title, "pickup") then
      guidingRoute = false
      return true
    end
    if not realTomTom() then notStarted() return false end
  end
  if TomTom then addTomTom(loc, title) return true end
  return false
end

local MAX_STOPS = 64 -- Shortest Path's limit for one route

local function routeStops(route)
  local stops = {}
  for i, s in ipairs(route) do
    if i > MAX_STOPS then break end
    stops[i] = {
      map = s.loc[1], x = s.loc[2] / 100, y = s.loc[3] / 100,
      title = s.book.name, tooltip = s.loc[4], kind = "pickup",
    }
  end
  return stops
end

-- true when Shortest Path took the route
local function startRoute(api, route)
  if api and api.NavigateRoute(ADDON, routeStops(route)) then
    guidingRoute = true
    return true
  end
  return false
end

-- sends the whole route ({ {book, loc}, ... }) to Shortest Path, else TomTom (always TomTom with forceTomTom)
function ns.SendRouteWaypoints(route, forceTomTom)
  if #route == 0 then print(ns.PREFIX .. L["Route finished!"]) return end
  local api = not forceTomTom and routeApi()
  if api then
    if startRoute(api, route) then
      print(ns.PREFIX .. L["%d stops sent to Shortest Path."]:format(math.min(#route, MAX_STOPS)))
      return
    end
    -- refused: TomTom takes it instead, when it is there
    if not realTomTom() then notStarted() return end
  end
  if not realTomTom() then print(ns.PREFIX .. L["TomTom is not installed."]) return end
  for i, s in ipairs(route) do addTomTom(s.loc, ("%d. %s"):format(i, s.book.name)) end
  print(ns.PREFIX .. L["%d waypoints sent to TomTom."]:format(#route))
end

-- true while Shortest Path is guiding through a route this addon sent
function ns.RouteGuided()
  local api = routeApi()
  return guidingRoute and has(api, "CurrentStop") and api.CurrentStop(ADDON) ~= nil
end

-- stops Shortest Path's guidance, if it is our route
function ns.CancelRouteWaypoints()
  local api = spf()
  if guidingRoute and has(api, "Cancel") then api.Cancel(ADDON) end
  guidingRoute = false
end

-- A send Shortest Path refused in combat is owed until combat ends: "sync" while our old journey still runs
-- (a refusal keeps it), "resume" for the journey a /reload or logout ended
local owed
local events = CreateFrame("Frame")

local function sendOrOwe(route, kind)
  if startRoute(routeApi(), route) then
    owed = nil
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
  elseif InCombatLockdown() then
    owed = kind
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
end

-- keeps Shortest Path's journey in step with the route after it changed, without chat output;
-- an empty route ends the journey
function ns.SyncRouteWaypoints(route)
  if not ns.RouteGuided() then return end
  if #route == 0 then ns.CancelRouteWaypoints() return end
  sendOrOwe(route, "sync")
end

-- Shortest Path doesn't keep an addon's journey through a /reload or logout: the owner starts it again,
-- ahead of the player's own kept journey (2 s after the loading screen)
local function resume()
  local route = ns.db.routeOn and ns.GetRoute() or {}
  if #route > 0 then sendOrOwe(route, "resume") end
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGOUT" then
    ns.db.resumeRoute = ns.RouteGuided() or nil
  elseif event == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent(event) -- only the loading screen that ends a login or reload
    if ns.db.resumeRoute then
      ns.db.resumeRoute = nil
      C_Timer.After(1, resume)
    end
  else -- PLAYER_REGEN_ENABLED
    self:UnregisterEvent(event)
    local kind = owed
    owed = nil
    if kind == "sync" then ns.SyncRouteWaypoints(ns.GetRoute())
    elseif kind == "resume" then resume() end
  end
end)
