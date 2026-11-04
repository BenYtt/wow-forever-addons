-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- Stand-ins for displays that are not Aura (Modern) in a Modern Aura Group.
-- Only frames created with DisableUntrustedLayoutScriptsTemplate may follow an
-- aura container, so such a display is drawn by copies made inside its chain
-- frame (flow.start). Every change to the display's own icon, cooldown, texts
-- and border is forwarded to its copy; the display itself is moved off screen.
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraStand")
local Display = Private.BlizzardAuraDisplay
local L = WeakAuras.L

local standTypes = {icon = true, text = true}
-- ForeverAuras: display types copied in a group-owned row only (the row layout,
-- SecretAuraFlow.lua). In a legacy row these keep leading the row, as they
-- always have, so imported groups do not change shape.
local ownedStandTypes = {texture = true, aurabar = true, progresstexture = true}
-- ForeverAuras: display types copied only while a saved flag is set (a
-- switch for an experiment: /run ForeverAurasSaved.<flag> = true, then
-- /reload). None at present; the bar and progress texture copies were
-- developed behind one (1.1.0).
local experimentalStandTypes = {}
-- Glow elements are mirrored by building the glow on the copy (MirrorGlow).
-- A Texture element's own texture is linked like a Text element's string.
local mirrorTypes = {subtext = true, subborder = true, subglow = true, subtexture = true,
  -- ForeverAuras: a bar's Tick element (a frame of textures placed on the
  -- bar in Lua); copied only with the bar itself (the aurabar branch).
  subtick = true}

local FRAME = {"ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "Show", "Hide", "SetShown", "SetAlpha"}
local TEXTURE = {"ClearAllPoints", "SetPoint", "SetAllPoints", "Show", "Hide", "SetShown", "SetAlpha", "SetTexture", "SetAtlas",
  "SetTexCoord", "SetDesaturated", "SetDesaturation", "SetVertexColor", "SetBlendMode", "SetRotation", "SetColorTexture"}
-- ForeverAuras: a bar's parts (see the aurabar branch of EnsureStand). Its
-- textures are sized, layered, graded and masked by the bar's own code, so
-- those setters are forwarded for them (and only for them: icon and text
-- copies keep the list above). The native bar takes the restricted value,
-- duration object, orientation and fill direction as the display's own
-- does, so the client animates the copy itself; a mask only has its place,
-- size and image.
local BARTEXTURE = {}
for _, method in ipairs(TEXTURE) do BARTEXTURE[#BARTEXTURE + 1] = method end
for _, method in ipairs({"SetGradient", "SetGradientAlpha", "SetDrawLayer", "AddMaskTexture", "RemoveMaskTexture", "SetSize", "SetWidth", "SetHeight"}) do
  BARTEXTURE[#BARTEXTURE + 1] = method
end
-- ForeverAuras: a Progress Texture's textures (the progresstexture branch
-- of EnsureStand): clipped by vertex offsets and coordinates, turned, and
-- in the native path masked or drawn as the client's radial bar.
local PROGRESSTEXTURE = {}
for _, method in ipairs(BARTEXTURE) do PROGRESSTEXTURE[#PROGRESSTEXTURE + 1] = method end
for _, method in ipairs({"SetVertexOffset", "SetRadialProgressBarStartOffset", "SetRadialProgressBarEndOffset",
  "SetRadialProgressBarReverse", "SetRadialProgressBarFeather", "SetRadialProgressBarPercent", "ClearRadialProgressBar"}) do
  PROGRESSTEXTURE[#PROGRESSTEXTURE + 1] = method
end
local STATUSBAR = {"ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "Show", "Hide", "SetShown",
  "SetAlpha", "SetMinMaxValues", "SetValue", "SetTimerDuration", "SetOrientation", "SetReverseFill", "SetFillStyle",
  "SetStatusBarTexture", "SetStatusBarColor", "SetColorFill", "SetRenderMode"}
local MASK = {"ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "Show", "Hide", "SetShown", "SetTexture"}
-- Methods whose first argument names another part (a mask, a texture): it
-- is mapped to that part's copy like an anchor's relative frame.
local PARTS = {AddMaskTexture = true, RemoveMaskTexture = true, SetStatusBarTexture = true}
local FONT = {"ClearAllPoints", "SetPoint", "SetAllPoints", "Show", "Hide", "SetShown", "SetAlpha", "SetText", "SetFormattedText",
  "SetTextColor", "SetFont", "SetFontObject", "SetShadowColor", "SetShadowOffset", "SetJustifyH", "SetJustifyV", "SetWordWrap",
  "SetNonSpaceWrap", "SetTextHeight", "SetWidth", "SetHeight", "SetSpacing"}
local COOLDOWN = {"ClearAllPoints", "SetPoint", "SetAllPoints", "Show", "Hide", "SetShown", "SetAlpha", "SetCooldown",
  "SetCooldownFromDurationObject", "SetCooldownDuration", "Clear", "Pause", "Resume", "SetReverse", "SetDrawSwipe", "SetDrawEdge",
  "SetDrawBling", "SetHideCountdownNumbers", "SetSwipeColor", "SetSwipeTexture", "SetEdgeTexture", "SetUseAuraDisplayTime",
  "SetCountdownFormatter", "SetMinimumCountdownDuration", "SetDrawSwipeOrg"}
local BORDER = {"SetBackdrop", "SetBackdropBorderColor", "SetBackdropColor"}
local SECURE = {"ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetAlpha", "SetAttribute", "RegisterForClicks"}
local ATTRIBUTES = {"type", "type1", "type2", "spell", "spell1", "spell2", "item", "item1", "item2", "macro", "macrotext", "macrotext1",
  "macrotext2", "action", "unit", "unit1", "unit2", "target-slot", "target-item", "target-bag", "useOnKeyDown", "checkselfcast", "checkfocuscast"}
local POINTS = {SetPoint = true, SetAllPoints = true}

function Display.UsesStand(data)
  if not data then return false end
  if standTypes[data.regionType] then return true end
  -- ForeverAuras: see ownedStandTypes and experimentalStandTypes.
  local switch = experimentalStandTypes[data.regionType]
  if switch and not (ForeverAurasSaved and ForeverAurasSaved[switch] == true) then return false end
  return (ownedStandTypes[data.regionType] == true or switch ~= nil) and Display.FlowGroupOwned ~= nil
    and Display.FlowGroupOwned(Display.FlowGroup(data)) == true
end

local function Map(stand, value)
  if type(value) ~= "table" then return value end
  if value == stand.region then return stand.frame end
  if stand.copies[value] then return stand.copies[value] end
  if value.GetParent and value:GetParent() == stand.region then return stand.frame end
  return value
end

local function Forward(source, method, ...)
  local link = source.faStand
  if link and link.owner and link.owner:GetParent() ~= link.stand.region then return end
  local copy = link and link.stand.active and link.stand.copies[source]
  -- Icons mask SetDrawSwipe and draw the swipe through the original setter.
  if method == "SetDrawSwipeOrg" then method = "SetDrawSwipe" end
  if not copy or not copy[method] then return end
  if link.stand.secure[source] and InCombatLockdown() then return end
  if POINTS[method] then
    local stand = link.stand
    local a, b, c, d, e = ...
    if type(a) == "table" then a = Map(stand, a) end
    if type(b) == "table" then b = Map(stand, b) end
    pcall(copy[method], copy, a, b, c, d, e)
  elseif PARTS[method] then
    -- ForeverAuras: a mask or status texture of the display stands for its
    -- copy; one the stand does not know is not given to the copy at all (the
    -- copy would then show the display's own mask, or none).
    local a, b, c = ...
    if type(a) == "table" then
      local mapped = Map(link.stand, a)
      if mapped == a then return end
      a = mapped
    end
    pcall(copy[method], copy, a, b, c)
  else
    pcall(copy[method], copy, ...)
  end
end

local function Hook(source, methods)
  source.faStandHooked = source.faStandHooked or {}
  for _, method in ipairs(methods) do
    if source[method] and not source.faStandHooked[method] then
      source.faStandHooked[method] = true
      hooksecurefunc(source, method, function(self, ...)
        if not self.faStand then return end
        Private.StartProfileSystem("aura (modern) - group copies")
        Forward(self, method, ...)
        Private.StopProfileSystem("aura (modern) - group copies")
      end)
    end
  end
end

-- ForeverAuras: 0 when the count is secret (a part whose rect depends on
-- a secret value, such as a text showing one): nothing can be read back
-- from such a part; the display issues its anchors again (stand.replays).
local function NumPoints(source)
  local ok, count = false, 0
  if source.GetNumPoints then ok, count = pcall(source.GetNumPoints, source) end
  return ok and type(count) == "number" and not issecretvalue(count) and count or 0
end

-- The copy takes the source's anchors, each relative frame mapped by `map`
-- (a frame it stands for, or nil for `fallback`); no anchors fill the fallback.
-- ForeverAuras: returns false when the source's anchors could not be read
-- (its rect depends on a secret value: the count or a point is refused).
-- leaveUnread: the copy is then left without anchors for the display to
-- place again (the stand's replays); otherwise it fills the fallback, as
-- before, for callers without a repair step (CDMAuraProgress.lua).
local function CopyPointsMapped(source, copy, map, fallback, leaveUnread)
  pcall(copy.ClearAllPoints, copy)
  local okCount, raw = false, 0
  if source.GetNumPoints then okCount, raw = pcall(source.GetNumPoints, source) end
  if not okCount or type(raw) ~= "number" or issecretvalue(raw) then
    if not leaveUnread then pcall(copy.SetAllPoints, copy, fallback) end
    return false
  end
  local complete = true
  for index = 1, raw do
    local ok, point, relative, relativePoint, x, y = pcall(source.GetPoint, source, index)
    if ok and point and not issecretvalue(x) and not issecretvalue(y) then
      pcall(copy.SetPoint, copy, point, map(relative) or fallback, relativePoint, x, y)
    else
      complete = false
    end
  end
  if raw == 0 then pcall(copy.SetAllPoints, copy, fallback) end
  return complete
end
local function CopyPoints(stand, source, copy)
  return CopyPointsMapped(source, copy, function(value) return Map(stand, value) end, stand.frame, true)
end

local function Try(target, method, ...)
  if target[method] then pcall(target[method], target, ...) end
end

local function Apply(copy, setter, ok, ...)
  if ok then Try(copy, setter, ...) end
end

local function Pass(copy, setter, source, getter)
  if copy[setter] and source[getter] then Apply(copy, setter, pcall(source[getter], source)) end
end

local function CopyTexture(source, copy)
  Pass(copy, "SetTexture", source, "GetTexture")
  Pass(copy, "SetTexCoord", source, "GetTexCoord")
  Pass(copy, "SetDesaturated", source, "IsDesaturated")
  Pass(copy, "SetVertexColor", source, "GetVertexColor")
  Pass(copy, "SetBlendMode", source, "GetBlendMode")
end

-- A pixel-perfect border keeps 1 px edges: same scale and snapping as its source.
local function MatchBorderScale(sub, copy)
  if not (copy.ForEachPiece and sub.IsIgnoringParentScale) then return end
  local ok, ignore = pcall(sub.IsIgnoringParentScale, sub)
  local pixelPerfect = ok and ignore == true
  local scale = pixelPerfect and sub:GetScale() or 1
  copy:SetIgnoreParentScale(pixelPerfect)
  copy:SetScale(scale)
  -- The pieces follow the frame's scale (scaling them again would shrink the
  -- edges); hiding and showing makes the new scale take effect.
  copy:ForEachPiece(function(_, piece)
    piece:SetIgnoreParentScale(false)
    piece:SetScale(1)
    piece:Hide()
    piece:Show()
    -- Drawn exactly like the Border element draws it.
    if pixelPerfect then
      piece:SetSnapToPixelGrid(false)
      piece:SetTexelSnappingBias(0)
    end
  end)
  -- ForeverAuras: a copy drawn inside a Blizzard aura slot (CDMAuraProgress)
  -- reports a secret shown state, which cannot be tested; its pieces were
  -- hidden and shown above, which is what the scale change needs.
  local shown = copy:IsShown()
  if issecretvalue(shown) then return end
  copy:Hide()
  if shown then copy:Show() end
end

-- The copy helpers, for copies made elsewhere (the CDM slot look in
-- CDMAuraProgress.lua draws a display inside its aura slot the same way).
Display.CopyElementPoints, Display.CopyTextureLook, Display.MatchBorderScale = CopyPointsMapped, CopyTexture, MatchBorderScale
local function CopyFont(source, copy)
  Pass(copy, "SetFont", source, "GetFont")
  Pass(copy, "SetJustifyH", source, "GetJustifyH")
  Pass(copy, "SetJustifyV", source, "GetJustifyV")
  Pass(copy, "SetWordWrap", source, "CanWordWrap")
  Pass(copy, "SetShadowColor", source, "GetShadowColor")
  Pass(copy, "SetShadowOffset", source, "GetShadowOffset")
  Pass(copy, "SetTextColor", source, "GetTextColor")
  Pass(copy, "SetText", source, "GetText")
end

Display.CopyFontLook = CopyFont

-- ForeverAuras: a text's width and wrapping are set by the display from its
-- settings (SubText.lua, Text.lua), before the copy exists on first load, so
-- they were not carried over: a fixed-width label's copy was 0 wide. They
-- are set from the same settings here (the hooks forward later changes).
-- A text with automatic width is left at 0, so it keeps sizing itself to its
-- text rather than being frozen at the width measured now.
local function CopyTextSizing(copy, fixed, width, wrap)
  if fixed then
    copy:SetWidth(width or 0)
    copy:SetWordWrap(wrap ~= false)
    copy:SetNonSpaceWrap(wrap ~= false)
  else
    copy:SetWidth(0)
    copy:SetWordWrap(true)
    copy:SetNonSpaceWrap(true)
  end
end
local function CopyCooldown(stand, source, copy, data)
  Try(copy, "SetDrawBling", false)
  Pass(copy, "SetReverse", source, "GetReverse")
  Pass(copy, "SetDrawSwipe", source, "GetDrawSwipe")
  Pass(copy, "SetDrawEdge", source, "GetDrawEdge")
  Try(copy, "SetHideCountdownNumbers", data and data.cooldownTextDisabled ~= false)
  local region = stand.region
  local durationObject = region.durationObject
  if durationObject and type(durationObject) == "table" and durationObject.EvaluateRemainingDuration then
    Try(copy, "SetCooldownFromDurationObject", durationObject, true)
  elseif source.GetCooldownTimes then
    local ok, start, duration = pcall(source.GetCooldownTimes, source)
    if ok and type(start) == "number" and type(duration) == "number" and not issecretvalue(start) and not issecretvalue(duration) then
      Try(copy, "SetCooldown", start / 1000, duration / 1000)
    end
  end
end

-- A Glow element's glow on its copy. The glow library re-parents pooled
-- frames, which the chain frame refuses (UntrustedLayoutScriptExecution), so
-- the glow is built in place from the element's settings by SecretAuraGlow.lua,
-- as on Aura (Modern) icons; the copy itself plays the animations.
local player = {
  AddAuraShownAnimation = function(_, animation) animation:Play() end,
  RemoveAuraShownAnimation = function(_, animation) animation:Stop() end,
  AddAuraAssignedAnimation = function(_, animation) animation:Play() end,
  RemoveAuraAssignedAnimation = function(_, animation) animation:Stop() end,
}
local function MirrorGlow(copy)
  local sub = copy.faGlowSource
  copy.faGlowEntry = copy.faGlowEntry or {}
  local width, height = copy:GetSize()
  -- ForeverAuras: a copy laid out by the aura container can report a secret
  -- size, which cannot be compared. The glow then takes the size of the
  -- element it mirrors, whose display is drawn off screen at its own size.
  if issecretvalue(width) or issecretvalue(height) then
    local okSize, sourceWidth, sourceHeight = pcall(sub and sub.GetSize or function() end, sub)
    width, height = nil, nil
    if okSize and type(sourceWidth) == "number" and type(sourceHeight) == "number"
      and not issecretvalue(sourceWidth) and not issecretvalue(sourceHeight) then
      width, height = sourceWidth, sourceHeight
    end
  end
  -- ForeverAuras: a copy nobody can see (its display hidden by its trigger,
  -- unloaded, or the copies hidden for the editor) carries no glow: the
  -- animations the copy plays itself would otherwise run on the hidden frame
  -- for as long as it stayed hidden. The stand frame's OnShow asks again.
  local visible = copy:IsVisible()
  if issecretvalue(visible) then visible = true end
  if not sub or not sub.glow or not visible or not (width and width >= 1 and height and height >= 1) then
    Display.ClearElementGlow(copy.faGlowEntry)
    return
  end
  Display.StyleElementGlow(copy.faGlowEntry, player, copy, copy, sub, width, height)
end

local function Link(stand, source, copy, methods, owner)
  stand.copies[source] = copy
  stand.sources[#stand.sources + 1] = source
  source.faStand = {stand = stand, owner = owner}
  Hook(source, methods)
end

local function Pooled(stand, key, make)
  local copy = stand.pool[key]
  if not copy then
    copy = make()
    stand.pool[key] = copy
  end
  return copy
end

local function Unlink(stand)
  local keep = InCombatLockdown()
  local kept = {}
  for _, source in ipairs(stand.sources) do
    if keep and stand.secure[source] then
      kept[#kept + 1] = source
    elseif source.faStand and source.faStand.stand == stand then
      source.faStand = nil
    end
  end
  wipe(stand.sources)
  for source in pairs(stand.copies) do
    if not (keep and stand.secure[source]) then stand.copies[source] = nil end
  end
  if not keep then wipe(stand.secure) end
  for _, source in ipairs(kept) do stand.sources[#stand.sources + 1] = source end
  for _, copy in pairs(stand.pool) do
    if not (keep and copy.faSecure) then copy:Hide() end
    -- A released glow copy stops glowing; the element draws its own glow
    -- again (its SetVisible sees no active copy, Glow.lua).
    if copy.faGlowSource then
      local source = copy.faGlowSource
      copy.faGlowSource = nil
      MirrorGlow(copy)
      -- Only when the stand is released (not relinked, which mirrors again).
      if not stand.active and source.glow and source.SetVisible and not (keep and stand.secure[source]) then source:SetVisible(true) end
    end
  end
end

local function SecureSource(child)
  local okType, kind = pcall(child.GetObjectType, child)
  if not okType or (kind ~= "Button" and kind ~= "CheckButton") then return false end
  local okProtected, protected = pcall(child.IsProtected, child)
  if okProtected and protected then return true end
  local okAttribute, value = pcall(child.GetAttribute, child, "type")
  return okAttribute and value ~= nil
end

local function LinkSecure(stand, region)
  if InCombatLockdown() or not region.GetChildren then return end
  local count = 0
  for _, child in ipairs({region:GetChildren()}) do
    if child ~= stand.frame and SecureSource(child) then
      count = count + 1
      local frame = stand.frame
      local copy = Pooled(stand, "secure" .. count, function()
        local button = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
        button.faSecure = true
        return button
      end)
      stand.secure[child] = copy
      Link(stand, child, copy, SECURE)
      Try(copy, "RegisterForClicks", "AnyUp", "AnyDown")
      for _, name in ipairs(ATTRIBUTES) do
        local ok, value = pcall(child.GetAttribute, child, name)
        if ok then Try(copy, "SetAttribute", name, value) end
      end
    end
  end
end

function Display.SyncStandSecure(region, normal)
  local stand = normal and normal.stand
  if not stand or not stand.active or InCombatLockdown() or not region.GetChildren then return end
  for _, child in ipairs({region:GetChildren()}) do
    if child ~= stand.frame and not stand.secure[child] and SecureSource(child) then
      xpcall(function() Display.EnsureStand(region, normal) end, geterrorhandler())
      return
    end
  end
end

function Display.StandLocked(normal)
  local stand = normal and normal.stand
  return InCombatLockdown() and stand ~= nil and next(stand.secure) ~= nil
end

-- Another aura anchored to a display drawn by a stand-in must follow the
-- stand, since the display itself is parked off screen. The chain frame
-- cannot be the anchor (it follows an aura container, which only frames made
-- from DisableUntrustedLayoutScriptsTemplate may do), so a proxy frame on
-- UIParent copies the stand's screen rectangle while the stand is active, the
-- way the Clickable auras place their buttons over a display. The rectangle
-- can be secret in combat; the proxy then keeps its last place.
local function PlaceProxy(proxy)
  local frame = proxy.standFrame
  local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
  if not ok or type(left) ~= "number" or type(bottom) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then return end
  if issecretvalue(left) or issecretvalue(bottom) or issecretvalue(width) or issecretvalue(height) then return end
  local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  if proxy.placedScale ~= scale then proxy:SetScale(scale); proxy.placedScale = scale end
  if proxy.placedLeft == left and proxy.placedBottom == bottom and proxy.placedWidth == width and proxy.placedHeight == height then return end
  proxy.placedLeft, proxy.placedBottom, proxy.placedWidth, proxy.placedHeight = left, bottom, width, height
  proxy:ClearAllPoints()
  proxy:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  proxy:SetSize(math.max(width, 1), math.max(height, 1))
end

-- ForeverAuras: the proxy stops following while the stand frame is not
-- visible (display hidden, unloaded, or its region discarded on conversion)
-- and follows again from the stand frame's OnShow; before, it ran on for the
-- session once its display had gone. It stays shown throughout: auras
-- anchored to the display are parented to it, and would vanish with it.
local function ProxyUpdate(self, elapsed)
  self.elapsed = (self.elapsed or 0) + elapsed
  if self.elapsed < 0.1 then return end
  self.elapsed = 0
  local shown = self.standFrame and self.standFrame:IsVisible()
  if not issecretvalue(shown) and not shown then self:SetScript("OnUpdate", nil); return end
  PlaceProxy(self)
end

local function EnsureProxy(stand)
  local proxy = stand.proxy
  if not proxy then
    proxy = CreateFrame("Frame", nil, UIParent)
    proxy:EnableMouse(false)
    proxy.standFrame = stand.frame
    proxy:SetScript("OnUpdate", ProxyUpdate)
    stand.proxy = proxy
  end
  proxy.standFrame = stand.frame
  proxy:SetScript("OnUpdate", ProxyUpdate)
  PlaceProxy(proxy)
  proxy:Show()
  return proxy
end

-- The frame other auras anchor to for this display: its stand's proxy while
-- the stand draws it, otherwise nil (the display's own region serves).
function Display.StandAnchor(region)
  local normal = region and region.flowNormal
  local stand = normal and normal.stand
  if stand and stand.active and stand.proxy then return stand.proxy end
  return nil
end

function Display.EnsureStand(region, normal)
  local stand = normal.stand
  if not stand then
    -- ForeverAuras: in a group-owned row the copies draw in the content
    -- frame, which carries the display's own offset (SecretAuraFlow.lua).
    stand = {frame = normal.flow.content or normal.flow.start, region = region, copies = {}, sources = {}, pool = {}, secure = {}}
    normal.stand = stand
  end
  -- ForeverAuras: the chain frame was replaced after the client forbade it
  -- (FreshFrame, SecretAuraFlow.lua). The copies on the old frame can neither
  -- be moved nor measured, and may refuse to be hidden: they are let go
  -- before the ordinary unlinking below (which hides copies outright), and
  -- made again on the new frame (the sources' hooks reach copies through
  -- stand.copies, so they follow the new ones).
  if stand.frame ~= (normal.flow.content or normal.flow.start) then
    for _, copy in pairs(stand.pool) do
      -- ForeverAuras: a copy's mirrored glow stops with it; the glow's
      -- frames are the copy's own, so they can still be reached.
      if copy.faGlowEntry then Display.ClearElementGlow(copy.faGlowEntry) end
      pcall(copy.Hide, copy)
    end
    for _, source in ipairs(stand.sources) do
      if source.faStand and source.faStand.stand == stand then source.faStand = nil end
    end
    wipe(stand.sources); wipe(stand.copies); wipe(stand.secure)
    stand.pool = {}
    stand.frame = normal.flow.content or normal.flow.start
  end
  Unlink(stand)
  stand.active = true
  EnsureProxy(stand)
  -- The copies are hidden in the editor and shown live (PlaceNormalRegion):
  -- the mirrored Glow elements draw their own glow while the copies are
  -- hidden and stop it when the copies show (SubRegionTypes/Glow.lua).
  if not stand.frame.faGlowToggleHooked then
    stand.frame.faGlowToggleHooked = true
    local function RefreshSourceGlows(frame)
      local current = frame.faStandForGlows
      if not current then return end
      for _, source in ipairs(current.sources) do
        if source.type == "subglow" and source.glow and source.SetVisible then source:SetVisible(true) end
      end
    end
    stand.frame:HookScript("OnShow", RefreshSourceGlows)
    stand.frame:HookScript("OnHide", RefreshSourceGlows)
    -- ForeverAuras: the positioning proxy follows the stand frame's
    -- visibility (see EnsureProxy); the copies' mirrored glows are cleared
    -- or restyled by RefreshSourceGlows above (MirrorGlow).
    stand.frame:HookScript("OnShow", function(frame)
      local current = frame.faStandForGlows
      if current and current.active and current.proxy then
        current.proxy:SetScript("OnUpdate", ProxyUpdate)
        PlaceProxy(current.proxy)
      end
    end)
    stand.frame:HookScript("OnHide", function(frame)
      local current = frame.faStandForGlows
      if current and current.proxy then current.proxy:SetScript("OnUpdate", nil) end
    end)
  end
  stand.frame.faStandForGlows = stand
  -- ForeverAuras: what the display is asked to issue again once the
  -- general copy of anchors and sizes below has run (see the bar branch).
  stand.replays = {}
  if Private.ReanchorAttachedTo then Private.ReanchorAttachedTo(region.id) end
  local frame = stand.frame
  if region.icon then
    local icon = Pooled(stand, "icon", function() return frame:CreateTexture(nil, "ARTWORK") end)
    Link(stand, region.icon, icon, TEXTURE)
    CopyTexture(region.icon, icon)
    -- Pixel snapping follows the region's own icon, which the Icon display
    -- leaves unsnapped (a snapped copy rounded a 34x32 icon to a pixel less
    -- at the bottom than its unsnapped neighbours in a dynamic group).
    if region.icon.GetSnapToPixelGrid then
      Pass(icon, "SetSnapToPixelGrid", region.icon, "GetSnapToPixelGrid")
      Pass(icon, "SetTexelSnappingBias", region.icon, "GetTexelSnappingBias")
    elseif Display.SnapTexture then
      Display.SnapTexture(icon, false)
    end
  end
  if region.cooldown then
    local cooldown = Pooled(stand, "cooldown", function() return CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate") end)
    Link(stand, region.cooldown, cooldown, COOLDOWN)
  end
  -- ForeverAuras: a Texture display (ownedStandTypes) draws through one
  -- TextureBase wrapper (region.texture) around a real texture
  -- (region.texture.texture), like a Texture element: rotation and
  -- mirroring are texture coordinates (DoTexCoord), the file or atlas goes
  -- through SetTexture/SetAtlas, and tiling through SetTexture's wrap modes,
  -- so every later change reaches the copy through the hooked setters. The
  -- current state is copied here so the copy is right at once: coordinates,
  -- colour, desaturation, blend mode, tiling and the base's pixel snapping.
  if region.regionType == "texture" and type(region.texture) == "table" and region.texture.texture then
    local source = region.texture.texture
    local copy = Pooled(stand, "texture", function() return frame:CreateTexture(nil, "ARTWORK") end)
    Link(stand, source, copy, TEXTURE)
    CopyTexture(source, copy)
    -- The wrap mode (Clamp to black, Repeat, Mirror) is not readable from a
    -- texture and CopyTexture sets the file without it; the display keeps it
    -- on its wrapper (TextureBase.modify), so a file texture is set again
    -- with it, and its coordinates after that (a rotated texture's
    -- coordinates reach past the image's edges, where the wrap mode shows).
    local wrap = region.texture.textureWrapMode
    if wrap and not source.IsAtlas then
      local ok, file = pcall(source.GetTexture, source)
      if ok and file ~= nil and not issecretvalue(file) then
        Try(copy, "SetTexture", file, wrap, wrap)
        Pass(copy, "SetTexCoord", source, "GetTexCoord")
      end
    end
    Pass(copy, "SetHorizTile", source, "GetHorizTile")
    Pass(copy, "SetVertTile", source, "GetVertTile")
    -- Pixel snapping as the base sets it (off, bias 0); the client's getter
    -- is IsSnappingToPixelGrid.
    if source.IsSnappingToPixelGrid then
      Pass(copy, "SetSnapToPixelGrid", source, "IsSnappingToPixelGrid")
      Pass(copy, "SetTexelSnappingBias", source, "GetTexelSnappingBias")
    elseif Display.SnapTexture then
      Display.SnapTexture(copy, false)
    end
  end
  -- ForeverAuras: a Progress Bar display (ownedStandTypes) is copied part
  -- by part, each part made here as the display's own is made (AuraBar.lua,
  -- create): the bar frame; a native status bar that takes the restricted
  -- value or duration object; the two masks that cut the foreground, one
  -- sized in Lua, one hung on the native bar's status texture; the
  -- background, foreground and spark textures; and the icon. The display's
  -- own code keeps running on its parts, and every setter reaches the copy
  -- (STATUSBAR, MASK, TEXTURE, PARTS). The copy runs no Lua of its own, so
  -- the client's switching-off of layout scripts in a chain frame (the bar
  -- redraws its fill from OnSizeChanged) does not matter to it: the mask
  -- sizes the display's own handler sets are forwarded. Not yet copied:
  -- the extra bars (overlays) and Tick elements; a display using them is
  -- warned (see below) and shows without them in the row.
  if region.regionType == "aurabar" and region.bar and region.secretBar then
    local bar, secretBar = region.bar, region.secretBar
    local twin = Pooled(stand, "barTwin", function()
      local t = {}
      t.bar = CreateFrame("Frame", nil, frame)
      t.bar:EnableMouse(false)
      t.secretBar = CreateFrame("StatusBar", nil, frame)
      t.secretBar:EnableMouse(false)
      t.secretBar:SetStatusBarTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite")
      t.secretBar:SetColorFill(1, 1, 1, 0)
      for _, key in ipairs({"fgMask", "fgMaskSecret"}) do
        local mask = t.bar:CreateMaskTexture()
        mask:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite",
          "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
        mask:SetTexelSnappingBias(0)
        mask:SetSnapToPixelGrid(false)
        t[key] = mask
      end
      -- The background draws at the Background element's level, the bar
      -- and icon at the Foreground element's (see the element loop below),
      -- as the display's own do (SubRegionTypes/Background.lua).
      t.bgFrame = CreateFrame("Frame", nil, frame)
      t.bgFrame:EnableMouse(false)
      t.bg = t.bgFrame:CreateTexture(nil, "ARTWORK")
      t.fg = t.bar:CreateTexture(nil, "ARTWORK")
      t.spark = t.bar:CreateTexture(nil, "ARTWORK")
      t.iconFrame = CreateFrame("Frame", nil, frame)
      t.iconFrame:EnableMouse(false)
      t.icon = t.iconFrame:CreateTexture(nil, "OVERLAY")
      for _, texture in ipairs({t.bg, t.fg, t.spark, t.icon}) do
        texture:SetTexelSnappingBias(0)
        texture:SetSnapToPixelGrid(false)
      end
      t.bg:SetDrawLayer("ARTWORK", -1)
      t.fg:SetDrawLayer("ARTWORK", 0)
      t.spark:SetDrawLayer("ARTWORK", 7)
      -- Hidden with the stand (Unlink hides every pooled copy): the parts
      -- are children of these two frames and the table itself is not a frame.
      t.Hide = function(self) self.bar:Hide(); self.secretBar:Hide(); self.iconFrame:Hide(); self.bgFrame:Hide() end
      t.Show = function(self) self.bar:Show(); self.secretBar:Show(); self.iconFrame:Show(); self.bgFrame:Show() end
      return t
    end)
    -- The display itself is parked off screen (PlaceNormalRegion) and keeps
    -- drawing there; the copy is what the row shows.
    Link(stand, bar, twin.bar, FRAME)
    Link(stand, secretBar, twin.secretBar, STATUSBAR)
    Link(stand, bar.fgMask, twin.fgMask, MASK)
    Link(stand, bar.fgMaskSecret, twin.fgMaskSecret, MASK)
    Link(stand, bar.bg, twin.bg, BARTEXTURE)
    Link(stand, bar.fg, twin.fg, BARTEXTURE)
    Link(stand, bar.spark, twin.spark, BARTEXTURE)
    if region.iconFrame then Link(stand, region.iconFrame, twin.iconFrame, FRAME) end
    if region.icon then Link(stand, region.icon, twin.icon, BARTEXTURE) end
    -- The native bar's status texture is what the secret mask hangs on
    -- (UpdateSecretMaskInverse): the display's stands for the copy's.
    local okStatus, status = pcall(secretBar.GetStatusBarTexture, secretBar)
    local okTwinStatus, twinStatus = pcall(twin.secretBar.GetStatusBarTexture, twin.secretBar)
    if okStatus and okTwinStatus and status and twinStatus then stand.copies[status] = twinStatus end
    twin:Show()
    twin.bgFrame:ClearAllPoints()
    twin.bgFrame:SetAllPoints(twin.bar)
    for _, pair in ipairs({{bar.bg, twin.bg}, {bar.fg, twin.fg}, {bar.spark, twin.spark}, {region.icon, twin.icon}}) do
      if pair[1] then
        CopyTexture(pair[1], pair[2])
        Pass(pair[2], "SetDrawLayer", pair[1], "GetDrawLayer")
      end
    end
    -- A gradient is not readable from a texture: the display sets its
    -- foreground colour again (UpdateForegroundColor), which reaches the
    -- copy as a gradient or a flat colour, whichever it uses.
    Try(region, "UpdateForegroundColor")
    -- The native bar's current state. The value may be a secret; it goes
    -- in as it comes out. A duration object is bound again with the same
    -- direction as SetProgressSecret binds it, so the client animates the
    -- copy from now on.
    Pass(twin.secretBar, "SetOrientation", secretBar, "GetOrientation")
    Pass(twin.secretBar, "SetReverseFill", secretBar, "GetReverseFill")
    Pass(twin.secretBar, "SetMinMaxValues", secretBar, "GetMinMaxValues")
    Pass(twin.secretBar, "SetValue", secretBar, "GetValue")
    if region.secretProgress == "duration" and WeakAuras.IsDurationObject and WeakAuras.IsDurationObject(region.durationObject) then
      local direction = not region.inverse and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil
      Try(twin.secretBar, "SetTimerDuration", region.durationObject, nil, direction)
    end
    -- The masks' sizes (the Lua-sized mask is the progress itself; both are
    -- anchored by two points, which the general size copy below skips).
    for _, pair in ipairs({{bar.fgMask, twin.fgMask}, {bar.fgMaskSecret, twin.fgMaskSecret}}) do
      local ok, width, height = pcall(pair[1].GetSize, pair[1])
      if ok and width ~= nil and height ~= nil then Try(pair[2], "SetSize", width, height) end
    end
    -- Which mask cuts the foreground now (UseNormalMask / UseSecretMask).
    Try(twin.fg, "RemoveMaskTexture", twin.fgMask)
    Try(twin.fg, "RemoveMaskTexture", twin.fgMaskSecret)
    Try(twin.fg, "AddMaskTexture", bar.activeMask == "secret" and twin.fgMaskSecret or twin.fgMask)
    -- The secret mask hangs on the native bar's status texture, whose rect
    -- is secret while the value is, so its anchors cannot be read back by
    -- the general copy below and the copy's mask had none (seen in game: a
    -- health bar copy drew its background and tick but no fill). After that
    -- copy, the display issues the mask's and the spark's anchors again
    -- (constant points and frames), which reach the copy with the frames
    -- mapped (stand.replays, run after the general copy).
    stand.replays[#stand.replays + 1] = function()
      Try(region, "UpdateSecretMaskInverse", true)
      Try(bar, "UpdateAnchors")
    end
    -- ForeverAuras: the extra bars (overlays): each is a native status bar
    -- spanning two helper bars' status textures, with a texture on the bar
    -- frame cut by a mask on the overlay (UpdateAdditionalBars, AuraBar.lua).
    -- The copy has the same parts, made under the copy's bar, and every
    -- relationship (anchors to status textures, the mask on the texture) is
    -- mapped to the copy's parts. Overlays are made when a trigger first
    -- provides them, so UpdateAdditionalBars is hooked once per bar to link
    -- new ones (and a helper bar made later) by refreshing the stand.
    local function LinkOverlay(index, abar)
      local overlay = Pooled(stand, "overlay" .. index, function()
        local o = {}
        o.bar = CreateFrame("StatusBar", nil, twin.bar)
        o.bar:SetStatusBarTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite")
        o.bar:SetColorFill(1, 1, 1, 0)
        o.texture = twin.bar:CreateTexture(nil, "ARTWORK")
        o.texture:SetTexelSnappingBias(0)
        o.texture:SetSnapToPixelGrid(false)
        o.textureMask = o.bar:CreateMaskTexture()
        o.textureMask:SetTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite",
          "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
        o.textureMask:SetTexelSnappingBias(0)
        o.textureMask:SetSnapToPixelGrid(false)
        for _, key in ipairs({"offsetBar1", "offsetBar2", "offsetBarAdditional"}) do
          o[key] = CreateFrame("StatusBar", nil, o.bar)
          o[key]:SetStatusBarTexture("Interface\\AddOns\\ForeverAuras\\Media\\Textures\\Square_FullWhite")
          o[key]:SetColorFill(1, 1, 1, 0)
        end
        o.Hide = function(self) self.bar:Hide(); self.texture:Hide() end
        o.Show = function(self) self.bar:Show() end
        return o
      end)
      local function Status(statusBar)
        local ok, texture = pcall(statusBar.GetStatusBarTexture, statusBar)
        return ok and texture or nil
      end
      local function LinkBar(source, copy)
        Link(stand, source, copy, STATUSBAR)
        local from, to = Status(source), Status(copy)
        if from and to then stand.copies[from] = to end
        Pass(copy, "SetOrientation", source, "GetOrientation")
        Pass(copy, "SetReverseFill", source, "GetReverseFill")
        Pass(copy, "SetMinMaxValues", source, "GetMinMaxValues")
        Pass(copy, "SetValue", source, "GetValue")
        local ok, width, height = pcall(source.GetSize, source)
        if ok and type(width) == "number" and type(height) == "number" then Try(copy, "SetSize", width, height) end
      end
      LinkBar(abar, overlay.bar)
      LinkBar(abar.offsetBar1, overlay.offsetBar1)
      LinkBar(abar.offsetBar2, overlay.offsetBar2)
      if abar.offsetBarAdditional then
        LinkBar(abar.offsetBarAdditional, overlay.offsetBarAdditional)
        overlay.hasAdditional = true
      else
        overlay.offsetBarAdditional:Hide()
      end
      Link(stand, abar.texture, overlay.texture, BARTEXTURE)
      CopyTexture(abar.texture, overlay.texture)
      Pass(overlay.texture, "SetDrawLayer", abar.texture, "GetDrawLayer")
      Link(stand, abar.textureMask, overlay.textureMask, MASK)
      Try(overlay.texture, "AddMaskTexture", overlay.textureMask)
      -- The overlay's texture and mask are anchored once, when the display
      -- makes the overlay (UpdateAdditionalBars does not anchor them again),
      -- and the mask hangs on a status texture with a secret rect, so the
      -- general copy cannot read it back (seen in game: no absorb overlay
      -- on a health bar copy). Both are placed on the copy here, after the
      -- general copy, with the same constant anchors the display uses.
      stand.replays[#stand.replays + 1] = function()
        overlay.texture:ClearAllPoints()
        overlay.texture:SetAllPoints(twin.bar)
        local status = Status(overlay.bar)
        if status then
          overlay.textureMask:ClearAllPoints()
          overlay.textureMask:SetPoint("TOPLEFT", status, "TOPLEFT", -0.01, 0.01)
          overlay.textureMask:SetPoint("BOTTOMRIGHT", status, "BOTTOMRIGHT", 0, 0)
        end
      end
      -- A duration object bound to the overlay is bound to the copy again,
      -- with the same direction (UpdateAdditionalBars).
      local extra = type(bar.additionalBars) == "table" and bar.additionalBars[index]
      if extra and WeakAuras.IsDurationObject and WeakAuras.IsDurationObject(extra.durationObject) then
        local direction = extra.durationObjectUseRemaining and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil
        Try(overlay.bar, "SetTimerDuration", extra.durationObject, nil, direction)
      end
      Pass(overlay.bar, "SetShown", abar, "IsShown")
      Pass(overlay.texture, "SetShown", abar.texture, "IsShown")
    end
    stand.overlayCount = 0
    for index, abar in ipairs(bar.secretExtraTextures or {}) do
      LinkOverlay(index, abar)
      stand.overlayCount = index
    end
    -- As for the secret mask above: the overlays hang on status textures
    -- with secret rects, so their anchors are issued again by the display.
    if stand.overlayCount > 0 then stand.replays[#stand.replays + 1] = function() Try(bar, "UpdateAdditionalBars") end end
    for index = stand.overlayCount + 1, 40 do
      local overlay = stand.pool["overlay" .. index]
      if not overlay then break end
      overlay:Hide()
    end
    -- As for the progress texture below: the hook is put back whenever the
    -- function is not the one hooked.
    if bar.faStandOverlayHooked ~= bar.UpdateAdditionalBars and type(bar.UpdateAdditionalBars) == "function" then
      hooksecurefunc(bar, "UpdateAdditionalBars", function(self)
        local link = self.faStand
        local current = link and link.stand
        if not current or not current.active or current.pool.barTwin == nil then return end
        local count = #(self.secretExtraTextures or {})
        local changed = count ~= (current.overlayCount or 0)
        if not changed then
          for index = 1, count do
            local overlay = current.pool["overlay" .. index]
            if self.secretExtraTextures[index].offsetBarAdditional and not (overlay and overlay.hasAdditional) then changed = true; break end
          end
        end
        if changed and not current.overlayRefreshQueued then
          current.overlayRefreshQueued = true
          C_Timer.After(0, function()
            current.overlayRefreshQueued = nil
            if current.active and Display.RefreshStand then Display.RefreshStand(current.region) end
          end)
        end
      end)
      bar.faStandOverlayHooked = bar.UpdateAdditionalBars
    end
  end
  -- ForeverAuras: a Progress Texture display (experimentalStandTypes) is
  -- copied part by part: its foreground and background textures (linear
  -- bases), the three textures of each spinner (circular bases), the extra
  -- textures and spinners of additional progress, and its native progress
  -- parts (ProgressTextureNative.Create: a status bar that takes the
  -- restricted value or duration object, its texture and its mask), each
  -- made as the display's own is made. The display's own code keeps running
  -- on its parts; vertex offsets, coordinates, rotation, masks and the
  -- client's radial bar settings reach the copy through PROGRESSTEXTURE and
  -- STATUSBAR. The native parts are made for the display now if it has none
  -- yet (as Native.Start would), so they are linked before first use; the
  -- native style and value are replayed once linked (Native.Refresh).
  -- Extra textures made later (ApplyAdditionalProgress) are linked by a
  -- stand refresh next frame.
  if region.regionType == "progresstexture" and region.foreground and region.background and Private.ProgressTextureNative then
    local Native = Private.ProgressTextureNative
    local twin = Pooled(stand, "progressTwin", function()
      local t = {spinners = {}, extras = {}, extraSpinners = {}}
      t.fg = frame:CreateTexture(nil, "ARTWORK")
      t.bg = frame:CreateTexture(nil, "BACKGROUND")
      for _, key in ipairs({"fgSpinner", "bgSpinner"}) do
        t.spinners[key] = {}
        for i = 1, 3 do t.spinners[key][i] = frame:CreateTexture(nil, key == "fgSpinner" and "ARTWORK" or "BACKGROUND") end
      end
      t.native = Native.Create(frame)
      t.Hide = function(self)
        self.fg:Hide(); self.bg:Hide(); self.native.bar:Hide(); self.native.texture:Hide()
        for _, set in pairs(self.spinners) do for _, texture in ipairs(set) do texture:Hide() end end
        for _, texture in ipairs(self.extras) do texture:Hide() end
        for _, set in ipairs(self.extraSpinners) do for _, texture in ipairs(set) do texture:Hide() end end
      end
      t.Show = function() end
      return t
    end)
    -- wrap: the wrap mode the display sets this texture with. The linear
    -- textures, the extras and the native texture take the display's
    -- setting; the spinners' pieces are always clamped to black
    -- (CircularProgressTextureBase, SetTextureOrAtlas).
    local function LinkTexture(source, copy, wrap)
      if not source or not copy then return end
      Link(stand, source, copy, PROGRESSTEXTURE)
      CopyTexture(source, copy)
      -- The wrap mode is not readable from a texture (see the Texture
      -- display above), so a file texture is set again with it, and its
      -- coordinates after that.
      if wrap and not source.IsAtlas then
        local ok, file = pcall(source.GetTexture, source)
        if ok and file ~= nil and not issecretvalue(file) then
          Try(copy, "SetTexture", file, wrap, wrap)
          Pass(copy, "SetTexCoord", source, "GetTexCoord")
        end
      end
      Pass(copy, "SetDrawLayer", source, "GetDrawLayer")
      Pass(copy, "SetRotation", source, "GetRotation")
      if source.IsSnappingToPixelGrid then
        Pass(copy, "SetSnapToPixelGrid", source, "IsSnappingToPixelGrid")
        Pass(copy, "SetTexelSnappingBias", source, "GetTexelSnappingBias")
      end
      -- The four vertex offsets (the clipping of a linear progress).
      if source.GetVertexOffset and copy.SetVertexOffset then
        for vertex = 1, 4 do
          local ok, x, y = pcall(source.GetVertexOffset, source, vertex)
          if ok and type(x) == "number" and type(y) == "number" then Try(copy, "SetVertexOffset", vertex, x, y) end
        end
      end
    end
    local wrap = region.textureWrapMode
    LinkTexture(region.foreground.texture, twin.fg, wrap)
    LinkTexture(region.background.texture, twin.bg, wrap)
    for _, pair in ipairs({{region.foregroundSpinner, "fgSpinner"}, {region.backgroundSpinner, "bgSpinner"}}) do
      for i = 1, 3 do LinkTexture(pair[1] and pair[1].textures and pair[1].textures[i], twin.spinners[pair[2]][i], "CLAMPTOBLACKADDITIVE") end
    end
    for i, extra in ipairs(region.extraTextures or {}) do
      twin.extras[i] = twin.extras[i] or frame:CreateTexture(nil, "OVERLAY")
      LinkTexture(extra.texture, twin.extras[i], wrap)
    end
    for i = #(region.extraTextures or {}) + 1, #twin.extras do twin.extras[i]:Hide() end
    for i, spinner in ipairs(region.extraSpinners or {}) do
      twin.extraSpinners[i] = twin.extraSpinners[i] or {}
      for j = 1, 3 do
        twin.extraSpinners[i][j] = twin.extraSpinners[i][j] or frame:CreateTexture(nil, "OVERLAY")
        LinkTexture(spinner.textures and spinner.textures[j], twin.extraSpinners[i][j], "CLAMPTOBLACKADDITIVE")
      end
    end
    for i = #(region.extraSpinners or {}) + 1, #twin.extraSpinners do
      for _, texture in ipairs(twin.extraSpinners[i]) do texture:Hide() end
    end
    stand.extraCount = #(region.extraTextures or {}) + #(region.extraSpinners or {})
    -- The native parts: made now if the display has none yet.
    region.nativeProgress = region.nativeProgress or Native.Create(region)
    local native = region.nativeProgress
    Link(stand, native.bar, twin.native.bar, STATUSBAR)
    LinkTexture(native.texture, twin.native.texture, wrap)
    Link(stand, native.mask, twin.native.mask, MASK)
    if native.linearTexture and twin.native.linearTexture then stand.copies[native.linearTexture] = twin.native.linearTexture end
    Pass(twin.native.bar, "SetOrientation", native.bar, "GetOrientation")
    Pass(twin.native.bar, "SetReverseFill", native.bar, "GetReverseFill")
    Pass(twin.native.bar, "SetMinMaxValues", native.bar, "GetMinMaxValues")
    Pass(twin.native.bar, "SetValue", native.bar, "GetValue")
    Pass(twin.native.bar, "SetShown", native.bar, "IsShown")
    -- The native style (render mode, radial offsets, mask placement) and the
    -- current value or duration object, replayed through the display's own
    -- code so the copy receives them in the same order the display did.
    -- (After the general copy: the native mask hangs on a status texture
    -- with a secret rect, see the bar above.)
    if region.nativeProgressActive then stand.replays[#stand.replays + 1] = function() Native.Refresh(region) end end
    -- Extra textures are made by ApplyAdditionalProgress, which the display
    -- swaps for its linear or circular form on every orientation change
    -- (SetOrientation), also from a condition, with no stand refresh; so its
    -- two callers are hooked instead (SetAdditionalProgress and
    -- ReapplyAdditionalProgress, set once on the display), and the count is
    -- compared after each call. The hooked functions are remembered so a
    -- replaced one (a re-created display) is hooked again.
    local function AfterAdditional(self)
      local normalNow = self.flowNormal
      local current = normalNow and normalNow.stand
      if not current or not current.active or current.pool.progressTwin == nil then return end
      local count = #(self.extraTextures or {}) + #(self.extraSpinners or {})
      if count ~= (current.extraCount or 0) and not current.extraRefreshQueued then
        current.extraRefreshQueued = true
        C_Timer.After(0, function()
          current.extraRefreshQueued = nil
          if current.active and Display.RefreshStand then Display.RefreshStand(current.region) end
        end)
      end
    end
    region.faStandExtraHooked = region.faStandExtraHooked or {}
    for _, name in ipairs({"SetAdditionalProgress", "ReapplyAdditionalProgress"}) do
      if type(region[name]) == "function" and region.faStandExtraHooked[name] ~= region[name] then
        hooksecurefunc(region, name, AfterAdditional)
        region.faStandExtraHooked[name] = region[name]
      end
    end
  end
  -- The icon's Inner and Outer anchor areas (80% and 110% of the icon), which
  -- texts and borders may anchor to. Linked before the elements, so their
  -- copies' points resolve to these copies; unmapped, an area fell back to
  -- the icon's own box, and an Outer text sat 10% of the icon too high.
  for _, area in ipairs({"inner", "outer"}) do
    if region[area] then
      local copy = Pooled(stand, area, function() return CreateFrame("Frame", nil, frame) end)
      copy:EnableMouse(false)
      Link(stand, region[area], copy, FRAME)
    end
  end
  if region.text then
    local text = Pooled(stand, "text", function() return frame:CreateFontString(nil, "OVERLAY") end)
    Link(stand, region.text, text, FONT)
    CopyFont(region.text, text)
    local data = normal.data
    CopyTextSizing(text, data.automaticWidth == "Fixed", data.fixedWidth, data.wordWrap == "WordWrap")
    -- ForeverAuras: a Text display showing a secret value has a secret rect,
    -- so its anchors cannot be read back (CopyPointsMapped); the display
    -- anchors its text at one point of itself (AnchorText, Text.lua), so the
    -- copy is anchored the same way on the chain frame.
    local source = region.text
    stand.replays[#stand.replays + 1] = function()
      if stand.unread[source] then
        local point = region.textAnchorPoint or "CENTER"
        text:ClearAllPoints()
        text:SetPoint(point, stand.frame, point)
      end
    end
  end
  -- ForeverAuras: the copies are levelled in sub element order, as
  -- Private.ApplyFrameLevel levels the display's own elements. Left at the
  -- chain frame's level plus one, every copy shared one level and a Glow
  -- (drawn in a child frame of its copy) sat above Borders listed after it.
  -- Two levels per element leave room for that child frame.
  local okLevel, baseLevel = pcall(frame.GetFrameLevel, frame)
  if not okLevel or type(baseLevel) ~= "number" or issecretvalue(baseLevel) then baseLevel = nil end
  for index, sub in ipairs(region.subRegions or {}) do
    -- ForeverAuras: a bar copy's frames take the levels of the display's
    -- Background and Foreground elements, so texts and borders listed
    -- before or after them draw behind or above the bar as configured.
    local twin = stand.pool.barTwin
    if twin and baseLevel and sub.type == "subbackground" then
      pcall(twin.bgFrame.SetFrameLevel, twin.bgFrame, baseLevel + 2 + index * 2)
    elseif twin and baseLevel and sub.type == "subforeground" then
      pcall(twin.bar.SetFrameLevel, twin.bar, baseLevel + 2 + index * 2)
      pcall(twin.iconFrame.SetFrameLevel, twin.iconFrame, baseLevel + 2 + index * 2)
      pcall(twin.secretBar.SetFrameLevel, twin.secretBar, baseLevel + 2 + index * 2)
    end
    if mirrorTypes[sub.type] then
      local copy = Pooled(stand, sub.type .. index, function()
        return CreateFrame("Frame", nil, frame, sub.type == "subborder" and "BackdropTemplateWeakAuras" or nil)
      end)
      if baseLevel then pcall(copy.SetFrameLevel, copy, baseLevel + 2 + index * 2) end
      local methods = FRAME
      if sub.type == "subborder" then
        methods = {}
        for _, method in ipairs(FRAME) do methods[#methods + 1] = method end
        for _, method in ipairs(BORDER) do methods[#methods + 1] = method end
      end
      Link(stand, sub, copy, methods, sub)
      -- The glow is started and stopped by SetVisible, a plain function on the
      -- element, so it is hooked once; the copy restarts its glow when resized
      -- (the lines of a Pixel Glow are laid out for a size).
      if sub.type == "subglow" then
        copy.faGlowSource = sub
        -- The element's own animated glow stops while the copy draws it
        -- (SubRegionTypes/Glow.lua, SetVisible), which the element decides
        -- from the stand frame's visibility: asked again once linked.
        if sub.glow and sub.SetVisible then sub:SetVisible(true) end
        if not sub.faStandGlowHooked then
          sub.faStandGlowHooked = true
          hooksecurefunc(sub, "SetVisible", function(self)
            local link = self.faStand
            local glowCopy = link and link.stand.active and link.stand.copies[self]
            if glowCopy and glowCopy.faGlowSource == self then MirrorGlow(glowCopy) end
          end)
        end
        if not copy.faGlowSizeHooked then
          copy.faGlowSizeHooked = true
          copy:SetScript("OnSizeChanged", function(self)
            local source = self.faGlowSource
            if source and source.faStand and source.faStand.stand.copies[source] == self then MirrorGlow(self) end
          end)
        end
      end
      if sub.text then
        local text = Pooled(stand, "subtextText" .. index, function() return copy:CreateFontString(nil, "OVERLAY") end)
        Link(stand, sub.text, text, FONT, sub)
        CopyFont(sub.text, text)
        local element = normal.data.subRegions and normal.data.subRegions[index]
        if element and element.type == "subtext" then
          CopyTextSizing(text, element.text_automaticWidth == "Fixed", element.text_fixedWidth, element.text_wordWrap == "WordWrap")
        end
        -- ForeverAuras: a text showing a secret value (a health or power
        -- text on a bar) has a secret rect, so its anchors cannot be read
        -- back by the general copy and the copy was left unplaced (seen in
        -- game: a health bar copy without its text). Once that copy has
        -- run, the element issues its anchors again (Anchor: constant
        -- points and frames), which reach the copy with the frames mapped.
        local source = sub.text
        stand.replays[#stand.replays + 1] = function()
          if stand.unread[source] and type(sub.Anchor) == "function" then Try(sub, "Anchor") end
        end
      end
      -- A Texture element draws through a TextureBase wrapper (sub.texture)
      -- around the real texture (sub.texture.texture): every change, including
      -- rotation and mirroring (texture coordinates), reaches that texture.
      if sub.type == "subtexture" and type(sub.texture) == "table" and sub.texture.texture then
        local texture = Pooled(stand, "subtextureTexture" .. index, function() return copy:CreateTexture(nil, "ARTWORK") end)
        Link(stand, sub.texture.texture, texture, TEXTURE, sub)
        CopyTexture(sub.texture.texture, texture)
      end
      -- ForeverAuras: a Tick element's textures are placed on the bar frame
      -- (UpdateTickPlacementOne, SubRegionTypes/Tick.lua), sized, coloured
      -- and textured by setters, so each is linked like a bar texture; the
      -- anchors to the bar map to the copy's bar. Ticks made later (an
      -- added placement) are linked by the next stand refresh.
      if sub.type == "subtick" and stand.pool.barTwin then
        for tickIndex, tick in ipairs(sub.ticks or {}) do
          local tickCopy = Pooled(stand, "subtick" .. index .. "tick" .. tickIndex, function() return copy:CreateTexture(nil, "ARTWORK") end)
          Link(stand, tick, tickCopy, BARTEXTURE, sub)
          -- A solid tick is a colour texture (SetColorTexture, which no
          -- getter reports): set from the element's saved colour. A textured
          -- tick is copied as a texture.
          if sub.use_texture then
            CopyTexture(tick, tickCopy)
          elseif type(sub.tick_color) == "table" then
            Try(tickCopy, "SetColorTexture", sub.tick_color[1] or 1, sub.tick_color[2] or 1, sub.tick_color[3] or 1, sub.tick_color[4] or 1)
            -- The element tints and desaturates a solid tick too.
            Pass(tickCopy, "SetVertexColor", tick, "GetVertexColor")
            Pass(tickCopy, "SetDesaturated", tick, "IsDesaturated")
            Pass(tickCopy, "SetBlendMode", tick, "GetBlendMode")
          end
          Pass(tickCopy, "SetDrawLayer", tick, "GetDrawLayer")
          Pass(tickCopy, "SetRotation", tick, "GetRotation")
          -- Pixel snapping as the element sets it (off, bias 0).
          if tick.IsSnappingToPixelGrid then
            Pass(tickCopy, "SetSnapToPixelGrid", tick, "IsSnappingToPixelGrid")
            Pass(tickCopy, "SetTexelSnappingBias", tick, "GetTexelSnappingBias")
          end
          local ok, width, height = pcall(tick.GetSize, tick)
          if ok and type(width) == "number" and type(height) == "number" then Try(tickCopy, "SetSize", width, height) end
        end
      end
      if sub.type == "subborder" and sub.GetBackdrop and copy.SetBackdrop then
        Pass(copy, "SetBackdrop", sub, "GetBackdrop")
        Pass(copy, "SetBackdropBorderColor", sub, "GetBackdropBorderColor")
        copy.faBorderSource = sub
        MatchBorderScale(sub, copy)
        if not copy.faBorderScaleHooked and copy.SetBackdrop then
          copy.faBorderScaleHooked = true
          hooksecurefunc(copy, "SetBackdrop", function(self)
            if self.faBorderSource then MatchBorderScale(self.faBorderSource, self) end
          end)
        end
      end
    end
  end
  LinkSecure(stand, region)
  local combat = InCombatLockdown()
  -- ForeverAuras: the sources whose anchors could not be read (see
  -- CopyPointsMapped); only those are placed again by the replays below, so
  -- a copy that took its anchors (custom code's text positioning, say)
  -- keeps them.
  stand.unread = {}
  for _, source in ipairs(stand.sources) do
    local copy = stand.copies[source]
    if not (combat and stand.secure[source]) then
      if not CopyPoints(stand, source, copy) then stand.unread[source] = true end
      local okType, kind = pcall(source.GetObjectType, source)
      -- Texts size themselves to their text; only an explicit width is forwarded.
      if source.GetSize and copy.SetSize and NumPoints(source) < 2 and not (okType and kind == "FontString") then
        local ok, width, height = pcall(source.GetSize, source)
        if ok and type(width) == "number" and type(height) == "number" and not issecretvalue(width) and not issecretvalue(height) then
          Try(copy, "SetSize", width, height)
        end
      end
      Pass(copy, "SetAlpha", source, "GetAlpha")
      Pass(copy, "SetShown", source, "IsShown")
    end
  end
  for _, replay in ipairs(stand.replays) do replay() end
  stand.replays = {}
  if region.cooldown then CopyCooldown(stand, region.cooldown, stand.copies[region.cooldown], normal.data) end
  -- Glows are replayed once the copies are placed and sized.
  for _, source in ipairs(stand.sources) do
    local copy = stand.copies[source]
    if copy and copy.faGlowSource == source then MirrorGlow(copy) end
  end
  -- ForeverAuras: the display's alpha is applied again now that the stand
  -- frame is the gate's owner (RegionPrototype.lua, SetAlpha): the frame
  -- takes the gate, the display its asked-for alpha.
  if region.requestedAlpha ~= nil and region.SetAlpha then pcall(region.SetAlpha, region, region.requestedAlpha) end
end

local pending = {}
local releaser = CreateFrame("Frame")
releaser:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for stand in pairs(pending) do
    if not stand.active then Unlink(stand) end
  end
  wipe(pending)
end)

function Display.ReleaseStand(normal)
  local stand = normal and normal.stand
  if not stand then return end
  stand.active = false
  Unlink(stand)
  -- ForeverAuras: the gate alpha the frame carried (RegionPrototype.lua,
  -- SetAlpha) is dropped, so a later stand on this frame starts clean, and
  -- the display takes its gate back itself.
  if stand.frame then pcall(stand.frame.SetAlpha, stand.frame, 1); stand.frame.cdmGateApplied = nil end
  if stand.region.requestedAlpha ~= nil and stand.region.SetAlpha then pcall(stand.region.SetAlpha, stand.region, stand.region.requestedAlpha) end
  -- Auras anchored to the display go back to its own region.
  if stand.proxy then stand.proxy:Hide() end
  if Private.ReanchorAttachedTo then Private.ReanchorAttachedTo(stand.region.id) end
  if next(stand.secure) then
    pending[stand] = true
    releaser:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
end

function Display.RefreshStand(region)
  local normal = region.flowNormal
  if normal and normal.active and normal.stand and normal.stand.active then xpcall(function() Display.EnsureStand(region, normal) end, geterrorhandler()) end
end
