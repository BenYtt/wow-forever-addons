-- Books on map (Forever): welcome page, shown once per account (/bom welcome or /bom bvn to see it again)
local ADDON, ns = ...
local L = ns.L
local S = ns.Skin

local WIDTH, HEIGHT = 520, 580
local PAD = 18
local CARD_H, GAP = 74, 12 -- room for a title and 3 lines of description
local CARD_W = (WIDTH - 2 * PAD - GAP) / 2

local FEATURES = {
  { "INV_Misc_Map_01", "Map and minimap", "Every library book on the world map and the minimap, with its exact place." },
  { "INV_Misc_Bag_08", "Automatic detection", "Books in your bags and books handed in to the library are checked off by themselves." },
  { "Ability_Tracking", "Optimized route", "Your missing books in the best order, with an arrow and Shortest Path or TomTom." },
  { "Ability_Warrior_BattleShout", "Group mode", "See which books your group members still need and help them." },
  { "INV_Jewelry_Ring_03", "Rewards", "Track the necklace (10), the ring (20) and the bow, crest or light (25)." },
  { "INV_Misc_Note_01", "New in this version", "Collection alerts, item tooltips, nearest book (/bom next) and /bom share." },
}

local COMMANDS = {
  { "/bom", "open the book list" },
  { "/bom next", "nearest book" },
  { "/bom route", "optimized route" },
  { "/bom share", "share in chat" },
  { "/bom welcome", "this page" },
}

local frame

local function version()
  local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  return getMeta(ADDON, "Version") or "?"
end

local function createCard(parent, feature, x, y)
  local card = CreateFrame("Frame", nil, parent)
  card:SetSize(CARD_W, CARD_H)
  card:SetPoint("TOPLEFT", x, y)
  S.Box(card, { 0, 0, 0, 0.35 }, S.C.rule)
  card:EnableMouse(true)
  S.RowHighlight(card)

  local icon = S.Icon(card, 32)
  icon:SetPoint("TOPLEFT", 10, -10)
  icon.tex:SetTexture("Interface\\Icons\\" .. feature[1])

  local title = S.Text(card, 13, "accent")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
  title:SetWidth(CARD_W - 60)
  title:SetWordWrap(false)
  title:SetText(L[feature[2]])

  local desc = S.Text(card, 11, "muted")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
  desc:SetSize(CARD_W - 60, CARD_H - 30)
  desc:SetJustifyV("TOP")
  desc:SetText(L[feature[3]])
  return card
end

local function create()
  local f = S.Window("BooksOnMapForeverWelcome", UIParent, WIDTH, HEIGHT, L["Welcome"])
  f:SetPoint("CENTER")
  -- above the options window (DIALOG): same strata would interleave their child frames
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  S.Draggable(f, f.titleBar)
  tinsert(UISpecialFrames, f:GetName()) -- close with Escape

  f.lang = ns.LanguageSelector(f.titleBar)
  f.lang:SetPoint("RIGHT", f.close, "LEFT", -8, 0)

  -- Header: big icon, name, version, tagline
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(64, 64)
  logo:SetPoint("TOPLEFT", PAD, -52)
  logo:SetTexture(ns.ADDON_ICON)
  local halo = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  halo:SetTexture(S.MEDIA .. "Glow")
  halo:SetBlendMode("ADD")
  halo:SetSize(120, 120)
  halo:SetPoint("CENTER", logo)
  halo:SetVertexColor(0.3, 0.7, 1, 0.45)

  local name = S.Text(f, 20, "text")
  name:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -4)
  name:SetText("Books on map |cff5cc8ffForever|r")

  local ver = S.Text(f, 11, "muted")
  ver:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 8, 2)
  ver:SetText("v" .. version())

  local tagline = S.Text(f, 12, "dim")
  tagline:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
  tagline:SetWidth(WIDTH - 2 * PAD - 78)
  tagline:SetText(L["Every WoW Forever library book on your map. Collect them all and earn the library rewards."])

  -- Features
  local features = S.Section(f, L["Features"])
  features:SetPoint("TOPLEFT", PAD, -132)
  features:SetPoint("TOPRIGHT", -PAD, -132)

  local grid = CreateFrame("Frame", nil, f)
  grid:SetPoint("TOPLEFT", features, "BOTTOMLEFT", 0, -10)
  grid:SetSize(WIDTH - 2 * PAD, 3 * CARD_H + 2 * GAP)
  for i, feature in ipairs(FEATURES) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    createCard(grid, feature, col * (CARD_W + GAP), -row * (CARD_H + GAP))
  end

  -- Commands
  local commands = S.Section(f, L["Commands"])
  commands:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -14)
  commands:SetPoint("TOPRIGHT", grid, "BOTTOMRIGHT", 0, -14)
  for i, c in ipairs(COMMANDS) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local line = S.Text(f, 12, "muted")
    line:SetPoint("TOPLEFT", commands, "BOTTOMLEFT", col * (CARD_W + GAP), -10 - row * 20)
    line:SetWidth(CARD_W)
    line:SetWordWrap(false)
    line:SetText(("|cff5cc8ff%s|r  %s"):format(c[1], L[c[2]]))
  end

  -- Footer
  local start = S.Button(f, L["Let's go!"], 140, 28, function() S.Close(f) end)
  start:SetPoint("BOTTOMRIGHT", -PAD, 16)
  local open = S.Button(f, L["Open the book list"], 190, 28, function()
    S.Close(f)
    ns.ToggleOptions()
  end, true)
  open:SetPoint("RIGHT", start, "LEFT", -8, 0)
  local bug = S.Button(f, L["Report a bug"], 130, 28, ns.ReportBug)
  bug:SetPoint("BOTTOMLEFT", PAD, 16)

  f:HookScript("OnShow", function() f.lang.Refresh() end)
  f:Hide()
  return f
end

function ns.ShowWelcome()
  frame = frame or create()
  ns.global.welcomeSeen = version()
  if not frame:IsShown() then frame:Show() end
end

-- first time on this account: after the loading screen
function ns.InitWelcome()
  if ns.global.welcomeSeen then return end
  C_Timer.After(3, ns.ShowWelcome)
end
