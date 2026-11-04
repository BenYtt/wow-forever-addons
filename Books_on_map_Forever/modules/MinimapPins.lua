-- Books on map (Forever): book icons on the minimap
local _, ns = ...
local L = ns.L
local BOOKS = ns.BOOKS

ns.DEFAULT_MINIMAP_PIN_SIZE = 14
local UPDATE_EVERY = 0.05 -- seconds

-- minimap diameter in yards for each zoom level
local MINIMAP_YARDS = {
  indoor = { [0] = 300, 240, 180, 120, 80, 50 },
  outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}

local pins = {}
local worldCache = {} -- loc -> { cont, x, y } or false (position unknown)

local function locWorld(loc)
  local w = worldCache[loc]
  if w == nil then
    local c, x, y = ns.WorldPos(loc[1], loc[2] / 100, loc[3] / 100)
    w = c and { cont = c, x = x, y = y } or false
    worldCache[loc] = w
  end
  return w
end

local function createPin()
  local p = CreateFrame("Button", nil, Minimap)
  p:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  p.tex = p:CreateTexture(nil, "OVERLAY")
  p.tex:SetAllPoints()
  p.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  p.num = p:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  p.num:SetPoint("BOTTOMRIGHT", 3, -2)
  p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  p:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.book.name, 1, 0.82, 0)
    GameTooltip:AddLine(("%s  (%.1f, %.1f)"):format(self.loc[4], self.loc[2], self.loc[3]), 1, 1, 1)
    if self.dist then GameTooltip:AddLine(L["%d yd"]:format(self.dist), 0.8, 0.8, 0.8) end
    if self.step then GameTooltip:AddLine(L["Route step %d"]:format(self.step), 0.4, 0.8, 1) end
    GameTooltip:AddLine(L["Books: %d/%d"]:format(ns.CountDone(), #BOOKS), 0.7, 0.7, 0.7)
    ns.AddGroupTooltip(self.book)
    GameTooltip:AddLine(L["Shift-click: mark as collected"], 0.5, 1, 0.5)
    local hint = ns.WaypointHint()
    if hint then GameTooltip:AddLine(hint, 0.5, 1, 0.5) end
    GameTooltip:Show()
  end)
  p:SetScript("OnLeave", function() GameTooltip:Hide() end)
  p:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      ns.Waypoint(self.loc, self.book.name)
    elseif IsShiftKeyDown() then
      GameTooltip:Hide()
      ns.SetDone(self.book, true)
    end
  end)
  return p
end

function ns.RefreshMinimapPins()
  if not ns.db then return end
  local n = 0
  local cont, px, py = ns.PlayerWorldPos()
  if cont and not ns.db.hideMinimapPins and Minimap:IsVisible() then
    local yards = MINIMAP_YARDS[IsIndoors() and "indoor" or "outdoor"][Minimap:GetZoom()] or 466
    local radius = yards / 2
    local halfW, halfH = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local facing = GetCVar("rotateMinimap") == "1" and GetPlayerFacing and GetPlayerFacing()
    local cos, sin = math.cos(facing or 0), math.sin(facing or 0)
    local size = ns.db.minimapPinSize or ns.DEFAULT_MINIMAP_PIN_SIZE
    local nextStep = ns.db.routeOn and ns.GetRoute and ns.GetRoute()[1]

    for _, b in ipairs(BOOKS) do
      local mine = not ns.IsDone(b)
      if mine or ns.GroupNeeds(b) then
        for _, loc in ipairs(b.locs) do
          local w = locWorld(loc)
          if w and w.cont == cont then
            -- offset in minimap radii (world x = north, world y = west)
            local ex, ny = (py - w.y) / radius, (w.x - px) / radius
            if facing then ex, ny = ex * cos + ny * sin, ny * cos - ex * sin end
            local d = square and math.max(math.abs(ex), math.abs(ny)) or math.sqrt(ex * ex + ny * ny)
            local isNext = nextStep and nextStep.book == b and nextStep.loc == loc
            if d <= 1 or isNext then
              n = n + 1
              local p = pins[n] or createPin()
              pins[n] = p
              p.book, p.loc = b, loc
              p.dist = math.floor(math.sqrt(ex * ex + ny * ny) * radius)
              -- the next route step stays visible on the edge
              if d > 1 then ex, ny = ex / d, ny / d end
              p.step = ns.RouteStep and ns.RouteStep(b, loc)
              p.num:SetText(p.step or "")
              p.tex:SetTexture(b.icon and ("Interface\\Icons\\" .. b.icon) or ns.ICON)
              p.tex:SetDesaturated(not mine) -- only needed by the group
              p:SetSize(size, size)
              p:SetAlpha((d > 1 or not mine) and 0.7 or 1)
              p:ClearAllPoints()
              p:SetPoint("CENTER", Minimap, "CENTER", ex * halfW, ny * halfH)
              p:Show()
            end
          end
        end
      end
    end
  end
  for i = n + 1, #pins do pins[i]:Hide() end
end

function ns.InitMinimapPins()
  local elapsed = 0
  local driver = CreateFrame("Frame")
  driver:SetScript("OnUpdate", function(_, e)
    elapsed = elapsed + e
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    ns.RefreshMinimapPins()
  end)
end
