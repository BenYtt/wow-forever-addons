local _, FLT = ...

-- Quality of Life > World Map > Remove Fog ("mapFog", user 22.10.): the world map also shows the parts of a
-- zone you have not explored yet. The game draws the explored parts (MapExplorationPin); after it did, the
-- missing ones are drawn on the same pin from Data/MapOverlays.lua (own data from the Forever client
-- database), as visible as the slider says (mapFogAlpha, 0-100 %). Nothing runs while the option is off or the map is closed.

local pin, textures, used = nil, {}, 0
local parsed = {} -- UiMapArtID -> overlays (the data string is read only when a map is opened)
local explored = {} -- reused

local function overlaysOf(artID)
  local list = parsed[artID]
  if list then return list end
  list = {}
  for part in ((FLT.MAP_OVERLAYS or {})[artID] or ""):gmatch("[^;]+") do
    local w, h, x, y, files = part:match("^(%d+),(%d+),(%-?%d+),(%-?%d+),([%d:]+)$")
    if w then
      local ids = {}
      for id in files:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
      list[#list + 1] = { w = tonumber(w), h = tonumber(h), x = tonumber(x), y = tonumber(y), ids = ids }
    end
  end
  parsed[artID] = list
  return list
end

local function texture()
  used = used + 1
  local t = textures[used]
  if not t then t = pin:CreateTexture(nil, "ARTWORK"); textures[used] = t end
  return t
end

local function fileSize(px) local s = 16; while s < px do s = s * 2 end; return s end

local function draw()
  for i = 1, used do textures[i]:Hide() end
  used = 0
  if not (pin and FLT.QoL and FLT.QoL.Get("mapFog")) then return end
  local map = pin.GetMap and pin:GetMap()
  local mapID = map and map.GetMapID and map:GetMapID()
  local artID = mapID and C_Map and C_Map.GetMapArtID and C_Map.GetMapArtID(mapID)
  local list = artID and overlaysOf(artID)
  if not list or #list == 0 then return end
  local alpha = (tonumber(FLT.QoL.Get("mapFogAlpha")) or 100) / 100 -- slider 0-100 % (user 01.11.)
  local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
  local idx = map.GetCanvasContainer and map:GetCanvasContainer() and map:GetCanvasContainer():GetCurrentLayerIndex() or 1
  local layer = layers and (layers[idx] or layers[1])
  local TW, TH = layer and layer.tileWidth or 256, layer and layer.tileHeight or 256
  wipe(explored)
  local got = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures and C_MapExplorationInfo.GetExploredMapTextures(mapID)
  for _, e in ipairs(got or {}) do explored[e.offsetX .. "," .. e.offsetY] = true end
  for _, o in ipairs(list) do
    if not explored[o.x .. "," .. o.y] then
      -- the same tiling as the game uses for explored parts
      local wide, tall = math.ceil(o.w / TW), math.ceil(o.h / TH)
      for j = 1, tall do
        local ph, fh = TH, TH
        if j == tall then ph = o.h % TH; if ph == 0 then ph = TH end; fh = fileSize(ph) end
        for k = 1, wide do
          local pw, fw = TW, TW
          if k == wide then pw = o.w % TW; if pw == 0 then pw = TW end; fw = fileSize(pw) end
          local id = o.ids[(j - 1) * wide + k]
          if id then
            local t = texture()
            t:SetSize(pw, ph); t:SetTexCoord(0, pw / fw, 0, ph / fh)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", pin, "TOPLEFT", o.x + TW * (k - 1), -(o.y + TH * (j - 1)))
            t:SetTexture(id, nil, nil, "TRILINEAR")
            t:SetAlpha(alpha); t:Show()
          end
        end
      end
    end
  end
end

-- find the game's exploration pin once and draw after it each time it draws
local function attach()
  if pin or type(WorldMapFrame) ~= "table" then return pin ~= nil end
  for dp in pairs(WorldMapFrame.dataProviders or {}) do
    local p = type(dp) == "table" and dp.pin
    if type(p) == "table" and p.RefreshOverlays and p.CreateTexture then
      pin = p
      hooksecurefunc(p, "RefreshOverlays", function() FLT.SafeCall("MapFog", draw) end)
      return true
    end
  end
  return false
end

function FLT.RefreshMapFog()
  if not (type(WorldMapFrame) == "table" and WorldMapFrame:IsShown()) then return end
  if attach() then FLT.SafeCall("MapFog", draw) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if type(WorldMapFrame) == "table" then WorldMapFrame:HookScript("OnShow", FLT.RefreshMapFog) end
end)
