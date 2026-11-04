-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- ForeverAuras.AuraOverlay: a native aura slot drawn over any frame, for
-- custom code (aura init scripts, custom triggers, other addons). Blizzard
-- fills the slot while one of the given spell IDs is on the unit, in combat
-- and instances too, and drives the swipe and countdown from the aura's own
-- timer; nothing here reads aura data, so secret values never reach Lua.
--
--   local overlay = ForeverAuras.AuraOverlay(frame, {
--     spellIDs = {12345, 23456},  -- auras to look for (required)
--     debuffSpellIDs = {34567},   -- harmful auras on the unit to look for as well
--     unit = "player",            -- default "player"
--     filter = "HELPFUL",         -- Blizzard filter string, default "HELPFUL"
--     icon = false,               -- draw the aura's icon over the frame
--     texture = nil,              -- a fixed texture covering the frame while the aura is up
--     textureCoords = nil,        -- its tex coords, e.g. {0.08, 0.92, 0.08, 0.92}
--     swipe = true,               -- a cooldown driven by the remaining time
--     swipeVisible = true,        -- draw its swipe (false: numbers only)
--     countdown = true,           -- countdown numbers; countdownFont, countdownSize,
--                                 -- countdownFlags, countdownPoint, countdownX,
--                                 -- countdownY and countdownColor style them
--     border = {1, 0.85, 0, 1},   -- border colour, or false for none
--     borderSize = 2,             -- border thickness in pixels
--     levelOffset = 5,            -- frame level above the frame
--     enabled = true,
--   })
--   overlay:SetSpellIDs({...}, {debuffs...}); overlay:SetUnit("target"); overlay:SetEnabled(false)
--   overlay:SetBorderColor(r, g, b, a); overlay:SetTexture(texture, coords); overlay:Release()
--
-- Returns nil and a message when the client refuses the slot.
if not WeakAuras.IsLibsOK() then return end

local SLOT = "Overlay"
-- Debuffs need their own slot: a slot has one Blizzard filter.
local SLOT_HARMFUL = "OverlayHarmful"
-- A map matching no aura, for a slot that currently has nothing to look for.
local NONE = {[1] = true}
local Overlay = {}
Overlay.__index = Overlay

local function SpellIDMap(list)
  local map, any = {}, false
  for _, id in ipairs(list or {}) do
    id = tonumber(id)
    if id then map[id], any = true, true end
  end
  return any and map or NONE
end

local function Colour(texture, colour)
  texture:SetColorTexture(colour[1] or 1, colour[2] or 1, colour[3] or 1, colour[4] or 1)
end

-- Builds a slot frame's look once; Blizzard shows and hides the frame. The
-- target is the overlay for the buff slot and overlay.harmful for the debuff
-- slot, so each keeps its own textures.
local function Build(overlay, button, options)
  overlay.button = button
  button:SetAllPoints(overlay.container or overlay.owner.container)
  button:EnableMouse(false)
  -- A fixed texture under everything else, so the overlay can cover what the
  -- frame below draws (a greyed icon, its own swipe and text) while the aura
  -- is up; textureCoords match the frame's zoom.
  if options.texture then
    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(button)
    texture:SetTexture(options.texture)
    if type(options.textureCoords) == "table" then texture:SetTexCoord(unpack(options.textureCoords)) end
    overlay.texture = texture
  end
  if options.icon then
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetIcon(icon)
    overlay.icon = icon
  end
  if options.swipe ~= false then
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawSwipe(options.swipeVisible ~= false)
    cooldown:SetHideCountdownNumbers(options.countdown == false)
    cooldown:SetReverse(options.reverse == true)
    -- The aura's own timer drives it; nothing is read back.
    cooldown:SetUseAuraDisplayTime(true)
    button:SetDurationCooldown(cooldown)
    overlay.cooldown = cooldown
    -- The countdown numbers take the caller's font and place; Blizzard
    -- writes the time into them.
    local numbers = options.countdown ~= false and cooldown:GetCountdownFontString()
    if numbers then
      numbers:SetFont(options.countdownFont or STANDARD_TEXT_FONT, tonumber(options.countdownSize) or 12, options.countdownFlags or "OUTLINE")
      numbers:ClearAllPoints()
      numbers:SetPoint(options.countdownPoint or "CENTER", button, options.countdownPoint or "CENTER",
        tonumber(options.countdownX) or 0, tonumber(options.countdownY) or 0)
      local colour = options.countdownColor
      if type(colour) == "table" then numbers:SetTextColor(colour[1] or 1, colour[2] or 1, colour[3] or 1, colour[4] or 1) end
      overlay.numbers = numbers
    end
  end
  if options.border ~= false then
    local size = tonumber(options.borderSize) or 2
    local colour = type(options.border) == "table" and options.border or {1, 0.85, 0, 1}
    overlay.edges = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
      local edge = button:CreateTexture(nil, "OVERLAY")
      Colour(edge, colour)
      if side == "TOP" or side == "BOTTOM" then
        edge:SetPoint(side .. "LEFT", button, side .. "LEFT")
        edge:SetPoint(side .. "RIGHT", button, side .. "RIGHT")
        edge:SetHeight(size)
      else
        edge:SetPoint("TOP" .. side, button, "TOP" .. side)
        edge:SetPoint("BOTTOM" .. side, button, "BOTTOM" .. side)
        edge:SetWidth(size)
      end
      overlay.edges[#overlay.edges + 1] = edge
    end
  end
  if options.stacks then
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, tonumber(options.stacksSize) or 12, "OUTLINE")
    text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button:SetApplicationCount(text)
    overlay.stacks = text
  end
end

function ForeverAuras.AuraOverlay(parent, options)
  options = options or {}
  if type(parent) ~= "table" or not parent.GetFrameLevel then return nil, "AuraOverlay needs a frame to draw over." end
  if not (CustomAuraContainerAuraProcessingPolicy and C_UnitAuras) then return nil, "This client has no native aura containers." end
  local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
  container:SetEnabled(false)
  container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
  container:SetAllPoints(parent)
  -- The overlay must never take clicks from the frame it covers.
  pcall(container.EnableMouse, container, false)
  container:SetFrameLevel(parent:GetFrameLevel() + (tonumber(options.levelOffset) or 5))
  local overlay = setmetatable({container = container, parent = parent, unit = options.unit or "player",
    filter = options.filter or "HELPFUL", enabled = options.enabled ~= false, options = options}, Overlay)
  local ok, err = pcall(container.AddAuraSlot, container, SLOT, overlay.filter, {
    candidateFilters = {includeSpellIDs = SpellIDMap(options.spellIDs)},
    initializeFrame = function(button) Build(overlay, button, options) end,
  })
  if not ok then
    container:Hide()
    return nil, "Blizzard refused the aura slot: " .. tostring(err)
  end
  if options.debuffSpellIDs and #options.debuffSpellIDs > 0 then
    local added, why = overlay:AddHarmfulSlot(options.debuffSpellIDs)
    if not added then
      container:Hide()
      return nil, "Blizzard refused the debuff slot: " .. tostring(why)
    end
  end
  container:SetUnit(overlay.unit)
  container:SetEnabled(overlay.enabled)
  return overlay
end

-- The debuff slot is a second frame with the same look, added when the
-- first debuff list arrives; the container is disabled while it is added.
function Overlay:AddHarmfulSlot(list)
  if self.released or self.harmful then return true end
  local container, options = self.container, self.options
  self.harmful = {owner = self}
  container:SetEnabled(false)
  local ok, err = pcall(container.AddAuraSlot, container, SLOT_HARMFUL, "HARMFUL", {
    candidateFilters = {includeSpellIDs = SpellIDMap(list)},
    initializeFrame = function(button) Build(self.harmful, button, options) end,
  })
  if not ok then self.harmful = nil end
  container:SetEnabled(self.enabled)
  return ok, err
end

function Overlay:SetSpellIDs(list, debuffList)
  if self.released then return end
  pcall(self.container.SetAuraSlotCandidateFilters, self.container, SLOT, {includeSpellIDs = SpellIDMap(list)})
  if debuffList and #debuffList > 0 and not self.harmful then self:AddHarmfulSlot(debuffList) end
  if self.harmful then
    pcall(self.container.SetAuraSlotCandidateFilters, self.container, SLOT_HARMFUL, {includeSpellIDs = SpellIDMap(debuffList)})
  end
end

function Overlay:SetUnit(unit)
  if self.released or self.unit == unit then return end
  self.unit = unit
  -- Disabling clears the slot before the unit changes, as the displays do.
  self.container:SetEnabled(false)
  self.container:SetUnit(unit)
  self.container:SetEnabled(self.enabled)
end

function Overlay:SetEnabled(enabled)
  if self.released then return end
  self.enabled = enabled ~= false
  self.container:SetEnabled(self.enabled)
end

function Overlay:SetBorderColor(r, g, b, a)
  for _, target in ipairs({self, self.harmful}) do
    for _, edge in ipairs(target.edges or {}) do edge:SetColorTexture(r, g, b, a or 1) end
  end
end

function Overlay:SetTexture(texture, coords)
  for _, target in ipairs({self, self.harmful}) do
    if target.texture then
      target.texture:SetTexture(texture)
      if type(coords) == "table" then target.texture:SetTexCoord(unpack(coords)) end
    end
  end
end

function Overlay:GetButton()
  return self.button
end

function Overlay:Release()
  if self.released then return end
  self.released = true
  self.container:SetEnabled(false)
  self.container:Hide()
  self.container:ClearAllPoints()
end
