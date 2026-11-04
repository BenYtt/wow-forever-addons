-- Copyright (c) 2026 Morpster. All rights reserved. See LICENSE.txt.
local _, addon = ...
local tracked = {}
local hooked = {}
local nameHooked = false

-- Session counters for /fct status and /fct report. Plain numbers only.
local styleStats = {
	styled = 0,
	tinted = 0,
	hidden = 0,
	deferred = 0,
	restored = 0,
	skippedForbidden = 0,
	skippedSecret = 0,
}
addon.styleStats = styleStats

local function readable(value)
	return not issecretvalue or not issecretvalue(value)
end

local function usable(frame)
	return frame and not frame:IsForbidden() and not (frame:IsProtected() and InCombatLockdown())
end

local function reactionColored(frame)
	local options = frame.optionTable
	return type(options) == "table" and options.colorNameBySelection and true or false
end

-- Blizzard's show-only-name layout is friendly-players only, and forcing it
-- onto NPC plates from the addon taints the nameplate: Blizzard's own
-- UpdateAnchors then fails on restricted measurement, and every later health
-- update on the tainted plate fails on secret values. The bar/health objects
-- and every layout method are therefore never touched or called here.
-- Hiding is limited to Hide()/Show() on the container/indicator frames
-- (experimental: if Blizzard errors return, this hiding is the part to
-- revert). Only the name FontString is ever tinted.
local function hiddenRegions(frame)
	return {
		frame.HealthBarsContainer,
		frame.CastBarsContainer,
		frame.AurasFrame,
		frame.ClassificationFrame,
		frame.LevelFrame,
		frame.PlayerLevelDiffFrame,
	}
end

local function hideContainers(frame)
	for _, region in ipairs(hiddenRegions(frame)) do
		if region and not region:IsForbidden() then
			region:Hide()
		end
	end
end

local function showContainers(frame)
	for _, region in ipairs(hiddenRegions(frame)) do
		if region and not region:IsForbidden() then
			region:Show()
		end
	end
end
local function paintName(frame, entry)
	local name = frame.name
	if not name or name:IsForbidden() then
		return
	end
	if reactionColored(frame) then
		return -- Blizzard already colors by reaction; leave it alone.
	end
	local dead = UnitIsDead(entry.unit)
	local tapDenied = UnitIsTapDenied(entry.unit)
	if (readable(dead) and dead) or (readable(tapDenied) and tapDenied) then
		name:SetVertexColor(0.5, 0.5, 0.5)
		return
	end
	if not readable(entry.unit) then
		return
	end
	local r, g, b = UnitSelectionColor(entry.unit)
	if readable(r) and readable(g) and readable(b) then
		name:SetVertexColor(r, g, b)
	end
end

local function resetName(frame)
	local name = frame.name
	if not name or name:IsForbidden() then
		return
	end
	if reactionColored(frame) then
		return
	end
	name:SetVertexColor(1.0, 1.0, 1.0)
end

local function updateIcon(entry)
	local frame = entry.frame
	if not frame or frame:IsForbidden() then
		if entry.iconHolder then
			entry.iconHolder:Hide()
		end
		return
	end
	local hostile = UnitCanAttack("player", entry.unit)
	local atlas
	if addon.db and addon.db.eliteIcons and readable(hostile) and hostile then
		local classification = UnitClassification(entry.unit)
		if readable(classification) then
			if classification == "elite" or classification == "worldboss" then
				atlas = "nameplates-icon-elite-gold"
			elseif classification == "rareelite" then
				atlas = "nameplates-icon-elite-silver"
			elseif classification == "rare" then
				atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star"
			end
		end
	end
	if not atlas then
		if entry.iconHolder then
			entry.iconHolder:Hide()
		end
		return
	end
	-- The icon lives on an addon-owned frame so the Blizzard plate is never
	-- touched. Anchoring (a SetPoint write) is the same class of operation as
	-- the addon's combat-text anchors; no measurement is performed here.
	if not entry.iconHolder then
		entry.iconHolder = CreateFrame("Frame", nil, UIParent)
		entry.iconHolder:SetSize(18, 18)
		entry.icon = entry.iconHolder:CreateTexture(nil, "OVERLAY")
		entry.icon:SetAllPoints()
	end
	entry.iconHolder:ClearAllPoints()
	entry.iconHolder:SetPoint("LEFT", frame.PlayerLevelDiffFrame, "RIGHT", 5, 0)
	entry.icon:SetAtlas(atlas)
	entry.iconHolder:Show()
end

local function refresh(frame)
	local entry = tracked[frame]
	if not entry or not entry.unit then
		return
	end
	if not readable(frame.unit) or frame.unit ~= entry.unit then
		if not readable(frame.unit) then
			styleStats.skippedSecret = styleStats.skippedSecret + 1
		end
		return
	end
	local friend = UnitIsFriend("player", entry.unit)
	local player = UnitIsPlayer(entry.unit)
	local selfUnit = UnitIsUnit("player", entry.unit)
	local known = readable(friend) and readable(player) and readable(selfUnit)
	-- Note: deliberately not gated on addon.db.enabled. "Enable floating text"
	-- controls only the numbers; plate styling follows Blizzard's setting and
	-- its own toggles, so disabling the addon must not reshape nameplates.
	local wantsNamesOnly = addon.db
		and C_CVar.GetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits") == "1"
		and known
		and friend
		and not player
		and not selfUnit
	if wantsNamesOnly then
		if not entry.namesOnly then
			styleStats.styled = styleStats.styled + 1
		end
		entry.namesOnly = true
	else
		entry.namesOnly = nil
	end
	updateIcon(entry)
	if not usable(frame) then
		if wantsNamesOnly or entry.tinted or entry.hidden then
			styleStats.deferred = styleStats.deferred + 1
		end
		return -- Deferred: Core re-styles all plates on PLAYER_REGEN_ENABLED.
	end
	if wantsNamesOnly then
		paintName(frame, entry)
		if not entry.tinted then
			styleStats.tinted = styleStats.tinted + 1
			entry.tinted = true
		end
		hideContainers(frame)
		if not entry.hidden then
			styleStats.hidden = styleStats.hidden + 1
			entry.hidden = true
		end
	elseif entry.tinted or entry.hidden then
		if entry.tinted then
			resetName(frame)
			entry.tinted = nil
		end
		if entry.hidden then
			showContainers(frame)
			entry.hidden = nil
		end
		styleStats.restored = styleStats.restored + 1
	end
end

function addon:StylePlate(plate, unit)
	local frame = plate and plate.UnitFrame
	if not usable(frame) then
		if frame and frame:IsForbidden() then
			styleStats.skippedForbidden = styleStats.skippedForbidden + 1
		else
			styleStats.deferred = styleStats.deferred + 1
		end
		return
	end
	local entry = tracked[frame]
	if not entry then
		entry = { frame = frame }
		tracked[frame] = entry
	end
	entry.unit = unit
	if not nameHooked then
		nameHooked = true
		hooksecurefunc("CompactUnitFrame_UpdateName", function(updated)
			local watched = tracked[updated]
			if watched and watched.namesOnly and watched.unit and usable(updated) then
				paintName(updated, watched)
			end
		end)
	end
	if not hooked[frame] then
		hooked[frame] = true
		-- Only faction changes (recompute tint) and clears (release state).
		-- Layout methods are deliberately not hooked or called: re-entering
		-- Blizzard's UpdateAnchors from the addon caused the restricted
		-- FrameMeasurement errors.
		hooksecurefunc(frame, "OnUnitFactionChanged", refresh)
		hooksecurefunc(frame, "OnUnitCleared", function()
			addon:UnstylePlate({ UnitFrame = frame })
		end)
	end
	refresh(frame)
end

function addon:UnstylePlate(plate)
	local frame = plate and plate.UnitFrame
	local entry = frame and tracked[frame]
	if not entry then
		return
	end
	if entry.iconHolder then
		entry.iconHolder:Hide()
	end
	if usable(frame) then
		if entry.tinted then
			resetName(frame)
		end
		if entry.hidden then
			showContainers(frame)
		end
		if entry.tinted or entry.hidden then
			styleStats.restored = styleStats.restored + 1
		end
	end
	entry.namesOnly = nil
	entry.tinted = nil
	entry.hidden = nil
	entry.unit = nil
end

function addon:RefreshNameplates()
	for frame in pairs(tracked) do
		if tracked[frame].unit then
			refresh(frame)
		else
			self:UnstylePlate({ UnitFrame = frame })
		end
	end
end
