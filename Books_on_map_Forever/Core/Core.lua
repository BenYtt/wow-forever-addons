-- Books on map (Forever): constants, saved state, collection API, startup
local ADDON, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

ns.ICON = "Interface\\Icons\\INV_Misc_Book_09"
ns.ADDON_ICON = "Interface\\AddOns\\Books_on_map_Forever\\adds\\icon"
ns.PREFIX = "|cff33ff99Books on map|r: "

-- library reward goals (books): necklace, ring, bow/crest/light
ns.GOALS = { 10, 20, 25 }
ns.GOAL_LABELS = { [10] = "Necklace unlocked", [20] = "Ring unlocked", [25] = "Bow, crest or light unlocked" }

-- books the other faction can't loot (e.g. Rumi for the Horde): removed from the list (once, at load)
local function removeOtherFactionBooks()
  local faction = UnitFactionGroup("player")
  for i = #BOOKS, 1, -1 do
    local f = BOOKS[i].faction
    if f and faction and f ~= faction then table.remove(BOOKS, i) end
  end
end

-- display names/places in the chosen language (once, at load)
local function localizeBooks()
  if not ns.IS_FRENCH then return end
  for _, b in ipairs(BOOKS) do
    b.name = b.frName or b.name
    for _, loc in ipairs(b.locs) do loc[4] = loc[5] or loc[4] end
  end
end

-- World positions --------------------------------------------------------
-- continent/instance ID and position in yards of a map position (0-1)
function ns.WorldPos(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
  local cont, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
  if cont and pos then return cont, pos.x, pos.y end
end

function ns.PlayerWorldPos()
  local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local p = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
  if p then return ns.WorldPos(mapID, p.x, p.y) end
end

-- Collection state -------------------------------------------------------
function ns.IsDone(b) return ns.db.collected[b.key] end

function ns.CountDone()
  local n = 0
  for _, b in ipairs(BOOKS) do if ns.IsDone(b) then n = n + 1 end end
  return n
end

function ns.Refresh()
  if not ns.db then return end
  ns.RefreshMap()
  ns.RefreshMinimapPins()
  ns.RefreshOptions()
  ns.RefreshRoute()
  ns.RefreshBroker()
end

function ns.SetDone(b, value, silent)
  if (ns.db.collected[b.key] or false) == value then return end
  ns.db.collected[b.key] = value or nil
  if not silent then
    print(ns.PREFIX .. ("%s %s (%d/%d)"):format(b.name,
      value and L["|cff00ff00collected|r"] or L["|cffff5555shown on map again|r"], ns.CountDone(), #BOOKS))
    if value then ns.NotifyCollected(b) end
  end
  ns.Refresh()
  ns.SendGroupState()
end

function ns.SetAll(collected)
  for _, b in ipairs(BOOKS) do ns.db.collected[b.key] = collected or nil end
  ns.Refresh()
  ns.SendGroupState()
end

-- Startup ----------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    BooksOnMapForeverDB = BooksOnMapForeverDB or {}
    ns.db = BooksOnMapForeverDB
    BooksOnMapForeverGlobal = BooksOnMapForeverGlobal or {} -- account-wide (welcome page)
    ns.global = BooksOnMapForeverGlobal
    ns.db.collected = ns.db.collected or {}
    removeOtherFactionBooks()
    ns.ApplyLanguage(ns.db.lang)
    localizeBooks()
  elseif event == "PLAYER_LOGIN" then
    ns.InitMap()
    ns.InitBroker()
    ns.InitMinimapButton() -- (after the broker: it's the button's data object)
    ns.InitMinimapPins()
    ns.InitDetection()
    ns.InitRoute()
    ns.InitGroup()
    ns.InitWelcome()
  end
end)
