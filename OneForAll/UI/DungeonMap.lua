local _, FLT = ...
local UI = FLT.UI

-- Dungeon maps: the game's own minimap pictures of the rooms, laid out with the
-- map data of Forever Simple World Map by Tarolg (MIT, see THIRD_PARTY_LICENSES.txt;
-- data in Data\DungeonMaps.lua). Shown in Dungeons & Raids ("Map") and, if the
-- player wants, on the world map key (M) inside a dungeon.

-- Texture corners for a right-angle turn (Texture:SetTexCoord with 8 values):
-- upper-left, lower-left, upper-right, lower-right.
local TURNS = {
  [0] = { 0, 0, 0, 1, 1, 0, 1, 1 },
  [1] = { 1, 0, 0, 0, 1, 1, 0, 1 },
  [2] = { 1, 1, 1, 0, 0, 1, 0, 0 },
  [3] = { 0, 1, 1, 1, 0, 0, 1, 0 },
}
local function quarterTurn(angle)
  local quarter = angle / (math.pi / 2)
  local nearest = math.floor(quarter + 0.5)
  if math.abs(quarter - nearest) * 90 > 0.5 then return nil end
  return nearest % 4
end

local MIN_ZOOM, MAX_ZOOM = 1, 6

-- Map widget: f:SetMap(map, dungeon, onBoss) draws a map from FLT.DUNGEON_MAPS;
-- onBoss(index) is called when a boss marker is clicked.
function UI.CreateDungeonMap(parent)
  local f = CreateFrame("Frame", nil, parent)
  UI.FramedPanel(f)
  local vp = CreateFrame("Frame", nil, f); vp:SetPoint("TOPLEFT", 8, -8); vp:SetPoint("BOTTOMRIGHT", -8, 30)
  if vp.SetClipsChildren then vp:SetClipsChildren(true) end
  vp:EnableMouse(true)
  if vp.EnableMouseWheel then vp:EnableMouseWheel(true) end
  local bg = vp:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.015, 0.015, 0.02, 1)
  local canvas = CreateFrame("Frame", nil, vp); canvas:SetAllPoints()
  local pinLayer = CreateFrame("Frame", nil, vp); pinLayer:SetAllPoints(); pinLayer:SetFrameLevel((canvas:GetFrameLevel() or 1) + 5)

  local hint = FLT.NewFS(f, nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 12, 10)
  hint:SetText("Mouse wheel: zoom  ·  drag: move  ·  click a boss to see its loot  ·  map layout: Forever Simple World Map by Tarolg")
  local fit = UI.GoldButton(f, "Fit", 54, 20, nil, 11); fit:SetPoint("BOTTOMRIGHT", -10, 6)
  local note = FLT.NewFS(f, nil, "OVERLAY", "GameFontHighlightSmall"); note:SetPoint("TOPLEFT", vp, "TOPLEFT", 10, -8)
  note:SetTextColor(0.75, 0.72, 0.66)

  local tex, pins = {}, {}
  local items = {} -- { texture, u, v, width, height, turn } for everything drawn on the canvas
  local mask
  local map, data, dungeon, onBoss
  local zoom, ox, oy = 1, 0, 0
  local TILE = 1600 / 3 -- size of an outdoor minimap square in yards

  local function baseK()
    local b = map.bounds
    local w, h = vp:GetWidth() or 1, vp:GetHeight() or 1
    if w < 10 or h < 10 then return 1 end
    return math.min(w / (b[3] - b[1]), h / (b[4] - b[2])) * 0.94
  end
  -- screen offset (from the viewport centre) of canvas point u, v
  local function toScreen(u, v, k)
    local b = map.bounds
    local cu, cv = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
    return (u - cu) * k + ox, -(v - cv) * k + oy
  end

  local function layout()
    if not map then return end
    local k = baseK() * zoom
    local w, h = vp:GetWidth() or 0, vp:GetHeight() or 0
    for _, it in ipairs(items) do
      local x = it[1]
      if it[6] and it[6] % 2 == 1 then x:SetSize(it[5] * k + 0.5, it[4] * k + 0.5) else x:SetSize(it[4] * k + 0.5, it[5] * k + 0.5) end
      local sx, sy = toScreen(it[2], it[3], k)
      x:ClearAllPoints(); x:SetPoint("CENTER", vp, "TOPLEFT", w / 2 + sx, -h / 2 + sy)
    end
    for _, p in ipairs(pins) do
      if p:IsShown() then
        local sx, sy = toScreen(p.u, p.v, k)
        p:ClearAllPoints(); p:SetPoint("CENTER", vp, "TOPLEFT", w / 2 + sx, -h / 2 + sy)
      end
    end
  end

  local nTex = 0
  local function nextTexture(image, layer, sub)
    nTex = nTex + 1
    local x = tex[nTex]
    if not x then x = canvas:CreateTexture(nil, layer); tex[nTex] = x end
    if x.RemoveMaskTexture and mask and x._ofaMasked then x:RemoveMaskTexture(mask); x._ofaMasked = nil end
    if type(image) == "string" then x:SetTexture(UI.ASSET_ROOT .. "Maps\\" .. image) else x:SetTexture(image) end
    x:SetDrawLayer(layer, sub or 0); x:SetVertexColor(1, 1, 1, 1)
    if x.SetRotation then x:SetRotation(0) end
    x:SetTexCoord(0, 1, 0, 1)
    x:Show()
    return x
  end
  local function useMask(x)
    if mask and x.AddMaskTexture then x:AddMaskTexture(mask); x._ofaMasked = true end
  end

  local function pin(i)
    local p = pins[i]; if p then return p end
    p = CreateFrame("Button", nil, pinLayer); p:SetSize(26, 26)
    local disc = p:CreateTexture(nil, "BACKGROUND"); disc:SetPoint("TOPLEFT", 3, -3); disc:SetPoint("BOTTOMRIGHT", -3, 3)
    disc:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"); disc:SetVertexColor(0.06, 0.05, 0.04, 0.92)
    local ring = p:CreateTexture(nil, "BORDER"); ring:SetAllPoints(); FLT.SetTex(ring, UI.ASSET_ROOT .. "ring_gold")
    p.disc, p.ring = disc, ring
    p.icon = p:CreateTexture(nil, "ARTWORK"); p.icon:SetSize(14, 14); p.icon:SetPoint("CENTER")
    p.num = FLT.NewFS(p, nil, "OVERLAY", "GameFontNormalSmall"); p.num:SetPoint("CENTER", 0, 0)
    -- boss portrait in the gold boss ring (same as Bosses & Loot), shown instead of the disc
    p.boss = UI.CreateBossFrame and UI.CreateBossFrame(p, 34, false, true)
    if p.boss then p.boss:SetPoint("CENTER"); p.boss:Hide() end
    p.label = FLT.NewFS(p, nil, "OVERLAY", "GameFontHighlightSmall"); p.label:SetPoint("TOP", p, "BOTTOM", 0, -3)
    p.label:SetShadowColor(0, 0, 0, 1); p.label:SetShadowOffset(1, -1)
    local hl = p:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetBlendMode("ADD")
    FLT.SetTex(hl, UI.ASSET_ROOT .. "ring_plain"); hl:SetVertexColor(FLT.SkinC(1, 0.85, 0.45, 0.8)) -- matches the plain boss ring
    p:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.title, 1, 0.82, 0)
      if self.tip then GameTooltip:AddLine(self.tip, 1, 1, 1, true) end
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = p
    return p
  end

  -- m = FLT.DUNGEON_MAPS[name] (what to show of which map), d = our dungeon
  function f:SetMap(m, d, bossCallback)
    map, dungeon, onBoss = m, d, bossCallback
    data = FLT.DUNGEON_MAP_DATA and FLT.DUNGEON_MAP_DATA[m.map] or {}
    zoom, ox, oy = 1, 0, 0
    for _, x in ipairs(tex) do x:Hide() end
    nTex, items = 0, {}
    local part = m.part
    local function inPart(u, v) return not part or (u >= part[1] and u <= part[3] and v >= part[2] and v <= part[4]) end
    -- the outdoor ground and extra pictures are seen through the map's soft-edged mask
    if data.mask then
      mask = mask or (canvas.CreateMaskTexture and canvas:CreateMaskTexture())
      if mask then
        mask:SetTexture(UI.ASSET_ROOT .. "Maps\\" .. m.map .. "_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        local r = data.mask
        items[#items + 1] = { mask, (r[1] + r[3]) / 2, (r[2] + r[4]) / 2, r[3] - r[1], r[4] - r[2] }
      end
    end
    local shade = (#(data.tiles or {}) > 0 and not data.ground) and 0.6 or 1
    if data.mask and mask then
      for cell, fid in pairs(data.terrain or {}) do
        local row, col = math.floor(cell / 64), cell % 64
        local x = nextTexture(fid, "BACKGROUND", 0); x:SetVertexColor(shade, shade, shade, 1); useMask(x)
        items[#items + 1] = { x, (col + 0.5) * TILE, (row + 0.5) * TILE, TILE, TILE }
      end
      for _, a in ipairs(data.art or {}) do
        local x = nextTexture(a[1], "BACKGROUND", 1); useMask(x)
        items[#items + 1] = { x, (a[2] + a[4]) / 2, (a[3] + a[5]) / 2, a[4] - a[2], a[5] - a[3] }
      end
    end
    for _, t in ipairs(data.tiles or {}) do
      if inPart(t[2], t[3]) then
        local x = nextTexture(t[1], "ARTWORK", t[7] or 0)
        local turn = quarterTurn(t[6])
        if turn then
          local c = TURNS[turn]
          x:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
        elseif x.SetRotation then
          x:SetRotation(t[6])
        end
        items[#items + 1] = { x, t[2], t[3], t[4], t[5], turn or 0 }
      end
    end
    for _, p in ipairs(pins) do p:Hide() end
    local n = 0
    -- our boss list decides the numbers (same order as Bosses & Loot)
    local order = {}
    for i, b in ipairs((d and d.bosses) or {}) do order[b.name or tostring(b)] = i end
    for i, b in ipairs(m.bosses or {}) do
      n = n + 1
      local p = pin(n); p:Show()
      local idx = order[b[1]] or i
      p.u, p.v, p.title = b[2], b[3], b[1]
      p.tip = "Click: show its loot in Bosses & Loot."
      p.icon:Hide(); p.label:SetText(b[1])
      local boss = d and d.bosses and d.bosses[idx]
      if p.boss and boss and UI.setBossPortrait then
        UI.setBossPortrait(p.boss.portrait, d, boss)
        p.boss:Show(); p.disc:Hide(); p.ring:Hide(); p.num:Hide(); p:SetSize(34, 34)
      else
        if p.boss then p.boss:Hide() end
        p.disc:Show(); p.ring:Show(); p.num:Show(); p.num:SetText(tostring(idx)); p:SetSize(26, 26)
      end
      p:SetScript("OnClick", function() if onBoss then onBoss(idx) end end)
    end
    if m.entrance then
      n = n + 1
      local p = pin(n); p:Show()
      p.u, p.v, p.title, p.tip = m.entrance[1], m.entrance[2], "Entrance", nil
      -- the dungeon / raid swirl of the world map (same as Map Landmarks, user 16.10.)
      p.num:Hide(); p.label:SetText(""); p.icon:Show(); p.icon:ClearAllPoints(); p.icon:SetAllPoints(p)
      if not (p.icon.SetAtlas and pcall(p.icon.SetAtlas, p.icon, (d and d.raid) and "raid" or "dungeon")) then
        p.icon:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"); p.icon:SetTexCoord(0, 1, 0, 1)
      end
      if p.boss then p.boss:Hide() end
      p.disc:Hide(); p.ring:Hide(); p:SetSize(42, 42)
      p:SetScript("OnClick", nil)
    end
    note:SetText(#(m.bosses or {}) == 0 and "Boss positions are not known yet for this dungeon." or "")
    layout()
  end
  f.Refresh = layout

  vp:SetScript("OnSizeChanged", layout)
  vp:SetScript("OnMouseWheel", function(self, delta)
    if not map then return end
    local old = zoom
    zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, zoom * (delta > 0 and 1.25 or 0.8)))
    -- keep the point under the cursor where it is
    local cx, cy = GetCursorPosition()
    local s = self:GetEffectiveScale()
    local left, top = self:GetLeft(), self:GetTop()
    if left and top and s and s > 0 then
      local mx = cx / s - left - (self:GetWidth() or 0) / 2
      local my = cy / s - top + (self:GetHeight() or 0) / 2
      ox = mx - (mx - ox) * zoom / old
      oy = my - (my - oy) * zoom / old
    end
    if zoom == MIN_ZOOM then ox, oy = 0, 0 end
    layout()
  end)
  -- dragging: OnUpdate runs only between mouse down and up (one reused table)
  local drag = {}
  local function dragUpdate()
    local cx, cy = GetCursorPosition()
    ox = drag.ox + (cx - drag.x) / drag.s
    oy = drag.oy + (cy - drag.y) / drag.s
    layout()
  end
  local function stopDrag(self) self:SetScript("OnUpdate", nil) end
  vp:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    drag.x, drag.y = GetCursorPosition()
    drag.ox, drag.oy, drag.s = ox, oy, self:GetEffectiveScale()
    self:SetScript("OnUpdate", dragUpdate)
  end)
  vp:SetScript("OnMouseUp", stopDrag)
  vp:SetScript("OnHide", stopDrag)
  fit:SetScript("OnClick", function() zoom, ox, oy = 1, 0, 0; layout() end)
  return f
end

-- World map key (M) inside a dungeon ------------------------------------------
-- On by default, can be turned off (Settings > Dungeons | Raids): override bindings on the keys of "Toggle World
-- Map", owned by one button, only while we are in a dungeon that has a map.
-- Bindings cannot change in combat, so a change waits for the combat to end.
-- The button needs a global name for SetOverrideBindingClick.
local keyButton = CreateFrame("Button", "OneForAllDungeonMapKey", UIParent)
keyButton:SetScript("OnClick", function() FLT.SafeCall("DungeonMapKey", function() if FLT.ToggleDungeonMap then FLT.ToggleDungeonMap() end end) end)
local applied = ""

local function currentMapDungeon()
  local d = FLT.FindCurrentDungeon and FLT.FindCurrentDungeon()
  if d and FLT.DUNGEON_MAPS and FLT.DUNGEON_MAPS[d.name] then return d end
end

function FLT.ApplyDungeonMapKey()
  if type(SetOverrideBindingClick) ~= "function" or type(ClearOverrideBindings) ~= "function" or type(GetBindingKey) ~= "function" then return end
  if InCombatLockdown and InCombatLockdown() then keyButton:RegisterEvent("PLAYER_REGEN_ENABLED"); return end
  keyButton:UnregisterEvent("PLAYER_REGEN_ENABLED")
  local on = type(OneForAllDB) == "table" and OneForAllDB.dungeonMapKey ~= false and currentMapDungeon() ~= nil
  local keys = {}
  if on then for _, k in ipairs({ GetBindingKey("TOGGLEWORLDMAP") }) do if type(k) == "string" then keys[#keys + 1] = k end end end
  local sig = table.concat(keys, "\1")
  -- (re)binding fires UPDATE_BINDINGS again: nothing to do when it is unchanged
  if sig == applied then return end
  applied = sig
  ClearOverrideBindings(keyButton)
  for _, k in ipairs(keys) do SetOverrideBindingClick(keyButton, false, k, "OneForAllDungeonMapKey") end
end

function FLT.ToggleDungeonMap()
  if UI.IsWindowShown and UI.IsWindowShown() then FLT:ToggleUI(); return end
  local d = currentMapDungeon()
  if not d then if ToggleWorldMap then ToggleWorldMap() end return end
  FLT:OpenPanel("dungeons")
  if UI.OpenDungeon then UI.OpenDungeon(d, nil, "map") end
end

keyButton:RegisterEvent("PLAYER_ENTERING_WORLD")
keyButton:RegisterEvent("ZONE_CHANGED_NEW_AREA")
keyButton:RegisterEvent("UPDATE_BINDINGS")
keyButton:SetScript("OnEvent", function() FLT.SafeCall("DungeonMapKey", FLT.ApplyDungeonMapKey) end)
