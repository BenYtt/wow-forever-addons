-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Glow elements on Aura (Modern) displays: Action Button Glow, Pixel Glow,
-- Autocast Shine and Proc Glow, using the Glow element's settings.
--
-- Nothing inside a shown aura button can be moved by addon code, so these
-- glows have no OnUpdate. Each is built at safe time from textures and
-- AnimationGroups (FlipBook, Translation, Alpha) registered with
-- AddAuraShownAnimation, and Blizzard plays them while the aura is shown.
-- Editor samples and the Missing icon use the same code.
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraGlow")
local Display = Private.BlizzardAuraDisplay

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ANTS = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local ALERT = "Interface\\SpellActivationOverlay\\IconAlert"
local ALERT_TC = {0.00781250, 0.50781250, 0.27734375, 0.52734375}
local SPARKLE = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
local SPARKLE_TC = {0.3984375, 0.4453125, 0.40234375, 0.44921875}
-- Default Pixel Glow colour.
local PIXEL_COLOR = {0.95, 0.95, 0.32, 1}

local function Number(value, fallback, low, high)
  value = tonumber(value)
  if not value or value ~= value then return fallback end
  return math.max(low, math.min(high, value))
end

-- Stops, unregisters and hides the current glow. The build is kept on the
-- entry so an unchanged glow is shown again without creating anything.
function Display.ClearElementGlow(entry)
  local glow = entry and entry.nativeGlow
  if not glow then return end
  for _, group in ipairs(glow.groups) do
    if glow.button and glow.button.RemoveAuraShownAnimation then pcall(glow.button.RemoveAuraShownAnimation, glow.button, group) end
    group:Stop()
  end
  for _, texture in ipairs(glow.textures) do texture:Hide() end
  for _, frame in ipairs(glow.frames) do frame:Hide() end
  if glow.holder then glow.holder:Hide() end
  entry.nativeGlow = nil
  entry.keptGlow = glow
end

-- Textures, edge frames and animation groups cannot be destroyed, so a build
-- that is replaced hands its pieces to per-element pools (one list per parent
-- frame, since nothing is re-parented) and the next build takes from there.
-- Without this every edit of a glow setting created a new set, and dragging a
-- slider on a Pixel Glow piled up thousands of live animations.
local function Recycle(entry, glow)
  entry.freeTextures = entry.freeTextures or {}
  entry.freeFrames = entry.freeFrames or {}
  for _, texture in ipairs(glow.textures) do
    local parent = texture:GetParent()
    entry.freeTextures[parent] = entry.freeTextures[parent] or {}
    table.insert(entry.freeTextures[parent], texture)
  end
  for _, frame in ipairs(glow.frames) do
    local parent = frame:GetParent()
    entry.freeFrames[parent] = entry.freeFrames[parent] or {}
    table.insert(entry.freeFrames[parent], frame)
  end
end

local function ResetTexture(texture, layer)
  texture:Hide()
  texture:ClearAllPoints()
  texture:SetDrawLayer(layer or "OVERLAY")
  texture:SetBlendMode("BLEND")
  texture:SetDesaturated(false)
  texture:SetVertexColor(1, 1, 1, 1)
  texture:SetRotation(0)
  texture:SetTexCoord(0, 1, 0, 1)
  texture:SetAlpha(1)
  for _, group in pairs(texture.faGroups or {}) do group:Stop() end
end

-- A pooled animation group on owner (a texture or frame) of one shape: "flip"
-- (one FlipBook) or "path<n>" (n Translations, FinishPaths). Its animations
-- are reconfigured by the caller; a group of the wrong shape is never reused.
local function GroupFor(glow, owner, shape, build)
  owner.faGroups = owner.faGroups or {}
  local group = owner.faGroups[shape]
  if not group then
    group = owner:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group.faAnimations = build(group)
    owner.faGroups[shape] = group
  end
  group:Stop()
  glow.groups[#glow.groups + 1] = group
  return group
end

-- Everything a build depends on; an equal key means the kept build fits.
local GLOW_KEYS = {"glowType", "glowLines", "glowFrequency", "glowLength", "glowThickness", "glowXOffset",
  "glowYOffset", "glowScale", "glowBorder", "glowDuration", "useGlowColor"}
local function GlowKey(button, parent, anchor, element, w, h)
  local parts = {tostring(button), tostring(parent), tostring(anchor), w, h, tostring(button.faStaticGlow == true)}
  for _, key in ipairs(GLOW_KEYS) do parts[#parts + 1] = tostring(element[key]) end
  if type(element.glowColor) == "table" then
    for index = 1, 4 do parts[#parts + 1] = tostring(element.glowColor[index]) end
  end
  return table.concat(parts, "|")
end

local function NewTexture(glow, parent, layer)
  local free = glow.entry.freeTextures and glow.entry.freeTextures[parent]
  -- ForeverAuras: taken from the front, so a rebuilt glow (a colour change,
  -- say) gets its textures back in the order it built them; a registered
  -- animation cannot be retargeted, and the old back-to-front order made
  -- FinishPaths build a fresh group on every colour edit.
  local texture = free and table.remove(free, 1)
  if texture then
    ResetTexture(texture, layer)
  else
    texture = parent:CreateTexture(nil, layer or "OVERLAY")
  end
  -- Plain blending, as the Glow element's library draws these same textures;
  -- additive blending washed the ants and border out to near white.
  texture:SetBlendMode("BLEND")
  texture:Show()
  glow.textures[#glow.textures + 1] = texture
  return texture
end

local function NewFrame(glow, parent)
  local free = glow.entry.freeFrames and glow.entry.freeFrames[parent]
  -- ForeverAuras: front first, as NewTexture (the edges keep their textures).
  local frame = free and table.remove(free, 1)
  if frame then
    frame:ClearAllPoints()
  else
    frame = CreateFrame("Frame", nil, parent)
  end
  frame:Show()
  glow.frames[#glow.frames + 1] = frame
  return frame
end

-- The glow colour when "Use Custom Color" is on; tinted artwork is desaturated
-- first, as the regular Glow element does.
local function Tint(texture, element, fallback)
  if element.useGlowColor and type(element.glowColor) == "table" then
    texture:SetDesaturated(true)
    texture:SetVertexColor(unpack(element.glowColor))
  elseif fallback then
    texture:SetVertexColor(unpack(fallback))
  else
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
  end
end

local function FlipBook(glow, texture, rows, columns, frames, duration, frameSize)
  local group = GroupFor(glow, texture, "flip", function(g) return {g:CreateAnimation("FlipBook")} end)
  local flip = group.faAnimations[1]
  flip:SetDuration(duration)
  flip:SetFlipBookRows(rows)
  flip:SetFlipBookColumns(columns)
  flip:SetFlipBookFrames(frames)
  flip:SetFlipBookFrameWidth(frameSize or 0)
  flip:SetFlipBookFrameHeight(frameSize or 0)
  return group
end

-- Moves texture once around the w x h rectangle of holder per duration,
-- starting at phase (0..1) of the perimeter. One Translation per straight
-- stretch between corners, each timed by its length, keeps the speed even.
-- The moves are only planned here: FinishPaths puts every texture of one
-- parent into a single animation group (one per glow, or per Pixel Glow
-- edge) instead of a group per texture, which was 32 groups and
-- registrations for a default glow; the editor built that for every sample.
-- A static glow (the editor's further samples) only places the texture.
local function Perimeter(glow, texture, holder, w, h, duration, phase, reverse)
  local perimeter = 2 * (w + h)
  local function Point(distance)
    distance = distance % perimeter
    if distance < h then return 0, distance end
    distance = distance - h
    if distance < w then return distance, h end
    distance = distance - w
    if distance < h then return w, h - distance end
    return w - (distance - h), 0
  end
  local start = phase * perimeter
  local x0, y0 = Point(start)
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", holder, "BOTTOMLEFT", x0, y0)
  if glow.static then return end
  local stops, seen = {perimeter}, {[perimeter] = true}
  for _, corner in ipairs({0, h, w + h, w + 2 * h}) do
    local distance = (reverse and (start - corner) or (corner - start)) % perimeter
    if distance > 1e-6 and distance < perimeter - 1e-6 and not seen[distance] then
      stops[#stops + 1] = distance
      seen[distance] = true
    end
  end
  table.sort(stops)
  local owner = texture:GetParent()
  glow.paths = glow.paths or {}
  glow.paths[owner] = glow.paths[owner] or {}
  local moves = glow.paths[owner]
  local previous, px, py = 0, x0, y0
  for order, distance in ipairs(stops) do
    local x, y = Point(start + (reverse and -distance or distance))
    if order == #stops then x, y = x0, y0 end
    moves[#moves + 1] = {texture = texture, delay = duration * previous / perimeter,
      duration = duration * (distance - previous) / perimeter, dx = x - px, dy = y - py}
    previous, px, py = distance, x, y
  end
end

-- Builds the planned moves (Perimeter): per parent frame one group whose
-- Translations each aim at their texture, all in one order and timed by
-- start delays, so every texture keeps its own pace while sharing the group.
local function FinishPaths(glow)
  for owner, moves in pairs(glow.paths or {}) do
    local shape = "path" .. #moves
    local function Build(g)
      local list = {}
      for index = 1, #moves do list[index] = g:CreateAnimation("Translation") end
      return list
    end
    -- ForeverAuras: once a group has been handed to a live aura button
    -- (AddAuraShownAnimation) the client forbids retargeting its animations.
    -- A rebuilt glow (a colour change, say) takes its textures from the pool
    -- in another order, so a reused group's moves would aim at other
    -- textures: a move whose target cannot be changed makes the glow build
    -- a fresh group with fresh animations instead (issue #119's sibling).
    local function Configure(group)
      for index, plan in ipairs(moves) do
        local move = group.faAnimations[index]
        local okTarget, target = pcall(move.GetTarget, move)
        if not (okTarget and target == plan.texture) and not pcall(move.SetTarget, move, plan.texture) then return false end
        move:SetOrder(1)
        move:SetStartDelay(plan.delay)
        move:SetDuration(plan.duration)
        move:SetOffset(plan.dx, plan.dy)
      end
      return true
    end
    local group = GroupFor(glow, owner, shape, Build)
    if not Configure(group) then
      for index = #glow.groups, 1, -1 do
        if glow.groups[index] == group then table.remove(glow.groups, index) end
      end
      owner.faGroups[shape] = nil
      Configure(GroupFor(glow, owner, shape, Build))
    end
  end
  glow.paths = nil
end

-- Builds element's glow inside parent, centred on anchor (w x h).
-- button: the aura button (or a sample frame) that plays the animations.
function Display.StyleElementGlow(entry, button, parent, anchor, element, w, h)
  Display.ClearElementGlow(entry)
  if not element.glow then return end
  local key = GlowKey(button, parent, anchor, element, w, h)
  local kept = entry.keptGlow
  if kept and kept.key == key then
    -- Unchanged settings: show and register the existing pieces again.
    entry.nativeGlow, entry.keptGlow = kept, nil
    if kept.holder then kept.holder:Show() end
    for _, frame in ipairs(kept.frames) do frame:Show() end
    for _, texture in ipairs(kept.textures) do texture:Show() end
    for _, group in ipairs(kept.groups) do button:AddAuraShownAnimation(group) end
    return
  end
  -- Changed settings: the old pieces go to the pools (Recycle) and are
  -- reused by this build where their parent frame matches.
  if kept then Recycle(entry, kept) end
  entry.keptGlow = nil
  -- The editor's further samples of a display draw the glow still.
  local glow = {button = button, entry = entry, groups = {}, textures = {}, frames = {}, key = key, static = button.faStaticGlow == true}
  entry.nativeGlow = glow
  local xOffset = Number(element.glowXOffset, 0, -200, 200)
  local yOffset = Number(element.glowYOffset, 0, -200, 200)
  entry.glowHolders = entry.glowHolders or {}
  local holder = entry.glowHolders[parent]
  if not holder then
    -- Created in place: nothing is re-parented into Blizzard's clip frames.
    holder = CreateFrame("Frame", nil, parent)
    entry.glowHolders[parent] = holder
  end
  glow.holder = holder
  holder:ClearAllPoints()
  holder:SetPoint("CENTER", anchor, "CENTER")
  -- Glow offsets grow (or shrink) the glowing rectangle.
  local gw, gh = math.max(2, w + xOffset * 2), math.max(2, h + yOffset * 2)
  holder:SetSize(gw, gh)
  holder:Show()
  local kind = element.glowType or "Proc"
  local frequency = Number(element.glowFrequency, 0.25, -10, 10)
  if kind == "Proc" then
    local scale = Number(element.glowScale, 1, 0.25, 4)
    local texture = NewTexture(glow, holder)
    texture:SetPoint("CENTER", holder, "CENTER")
    texture:SetSize(gw * 1.4 * scale, gh * 1.4 * scale)
    texture:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    Tint(texture, element)
    FlipBook(glow, texture, 6, 5, 30, Number(element.glowDuration, 1, 0.1, 10))
  elseif kind == "buttonOverlay" then
    -- Action Button Glow: the crawling ants over Blizzard's alert border.
    local outer = NewTexture(glow, holder)
    outer:SetPoint("CENTER", holder, "CENTER")
    outer:SetSize(gw * 1.4, gh * 1.4)
    outer:SetTexture(ALERT)
    outer:SetTexCoord(unpack(ALERT_TC))
    Tint(outer, element)
    local ants = NewTexture(glow, holder)
    ants:SetPoint("CENTER", holder, "CENTER")
    ants:SetSize(gw * 1.2, gh * 1.2)
    ants:SetTexture(ANTS)
    Tint(ants, element)
    -- 22 frames; at frequency 0.25 one lap takes about 0.2 s.
    FlipBook(glow, ants, 5, 5, 22, 0.055 / math.max(0.01, math.abs(frequency)), 48)
  else
    -- Pixel Glow and Autocast Shine: pieces travelling around the rectangle.
    local pixel = kind == "Pixel"
    local count = math.floor(Number(element.glowLines, pixel and 8 or 4, 1, 32))
    local duration = frequency == 0 and (pixel and 4 or 8) or math.max(0.1, math.abs(1 / frequency))
    local reverse = frequency < 0
    if pixel then
      -- A line that turns corners: a rotated square travelling the perimeter,
      -- seen only through four clip frames along the edges (thickness wide).
      local thickness = Number(element.glowThickness, 2, 0.5, 12)
      local length = Number(element.glowLength, 0, 0, math.min(gw, gh))
      if length == 0 then length = math.max(thickness, (gw + gh) * (2 / count - 0.1)) end
      local side = math.max(thickness, length) / math.sqrt(2)
      local edges = {}
      for index, point in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local edge = NewFrame(glow, holder)
        edge:SetClipsChildren(true)
        edge:SetPoint(point, holder, point)
        if index <= 2 then edge:SetSize(gw, thickness) else edge:SetSize(thickness, gh) end
        edges[index] = edge
        if element.glowBorder then
          local border = NewTexture(glow, edge, "BACKGROUND")
          border:SetAllPoints(edge)
          border:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        end
      end
      for line = 1, count do
        for _, edge in ipairs(edges) do
          local texture = NewTexture(glow, edge)
          texture:SetTexture(WHITE)
          texture:SetSize(side, side)
          texture:SetRotation(math.pi / 4)
          Tint(texture, element, PIXEL_COLOR)
          Perimeter(glow, texture, holder, gw, gh, duration, (line - 1) / count, reverse)
        end
      end
    else
      -- Autocast Shine as LibCustomGlow draws it: four rings of N sparkles,
      -- sizes 7, 6, 5 and 4 times the scale, ring k taking k laps' time per
      -- lap, all in the same direction and at constant alpha. The rings start
      -- in step and drift apart, which gives the layered, dense look.
      local scale = Number(element.glowScale, 1, 0.25, 4)
      for ring, base in ipairs({7, 6, 5, 4}) do
        local size = base * scale
        for sparkle = 1, count do
          local texture = NewTexture(glow, holder)
          texture:SetTexture(SPARKLE)
          texture:SetTexCoord(unpack(SPARKLE_TC))
          texture:SetSize(size, size)
          -- Additive, as Blizzard's AutoCastShine (and the library) draws
          -- these sparkles: overlapping rings brighten into the dense shine.
          texture:SetBlendMode("ADD")
          Tint(texture, element)
          Perimeter(glow, texture, holder, gw, gh, duration * ring, sparkle / count, reverse)
        end
      end
    end
  end
  FinishPaths(glow)
  for _, group in ipairs(glow.groups) do button:AddAuraShownAnimation(group) end
end
