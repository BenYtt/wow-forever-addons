-- Copyright (c) 2026 Morpster. All rights reserved. See LICENSE.txt.
local addonName, addon = ...
local PULSE_GROW, PULSE_SETTLE = 0.1, 0.2
local CRITICAL_PULSE_SCALE = 0.2
local MIN_FONT_SIZE, MAX_FONT_SIZE = 12, 60
local MAX_CRITICAL_TEXT_HEIGHT = 144
local REMOVAL_GRACE = 0.6
local PENDING_TIMEOUT = 3
local PENDING_BUFFER_MAX = 25

local defaults = {
	enabled = true,
	addonNumbers = true,
	damage = true,
	healing = true,
	eliteIcons = false,
	blizzardInstanceHealing = true,
	blizzardHealingWhenPlatesOff = true,
	npcPlates = true,
	minionPlates = true,
	hideFriendlyInCities = false,
	scope = "combat",
	schoolColors = true,
	damageSchoolColors = {
		physical = { 1, 0.9, 0.6 },
		holy = { 1, 0.9, 0.5 },
		fire = { 1, 0.4, 0.1 },
		nature = { 0.3, 1, 0.3 },
		frost = { 0.4, 0.85, 1 },
		shadow = { 0.65, 0.4, 1 },
		arcane = { 1, 0.45, 0.9 },
	},
	hideBlizzardDamage = true,
	blizzardWhenPlatesOff = true,
	damagePlateOffset = -30,
	healingPlateOffset = -30,
	fontSize = 22,
	fontFace = "default",
	duration = 1.2,
	showOutcomes = false,
	outcomeLocale = "client",
	outcomeColor = { 0.65, 0.65, 0.65 },
	damageColor = { 1, 0.82, 0.1 },
	healingColor = { 0.2, 1, 0.35 },
}

local plates = {}
local pending = {}
local pendingEntries = {}
local spareListeners = {}
local spareEntries = {}
local heldAnchors = {}
local pool = {}
local active = {}
local previewQueue = {}
local nextPreview = 0
local stats = {
	events = 0,
	damage = 0,
	healing = 0,
	outcomes = 0,
	secretTypes = 0,
	absorbed = 0,
	noPlate = 0,
	displayed = 0,
	previewed = 0,
	latePlates = 0,
	graceHits = 0,
	cachedHostility = 0,
	targetFallback = 0,
	reuseDrops = 0,
	bufferedHits = 0,
	friendlyToggles = 0,
	friendlyOn = 0,
	friendlyOff = 0,
}
-- Friendly-plate visibility CVars (keybinds and the interface options feed
-- these). Forever renames some of them (e.g. nameplateShowFriendlyNpcs), so
-- each category probes candidate spellings at login and keeps the first one
-- that reads back a value. /fct report lists which name won. Minions have no
-- CVar of their own on this client: they follow Show Friendly, so an
-- unresolved minions entry falls back to the friends state.
local friendlyPlateCandidates = {
	friends = { "nameplateShowFriends", "nameplateShowFriendlyPlayers" },
	npcs = { "nameplateShowFriendlyNpcs", "nameplateShowFriendlyNPCs" },
	minions = { "nameplateShowFriendlyPlayerMinions", "nameplateShowFriendlyMinions", "nameplateShowMinions" },
}
local friendlyWatch = {} -- lowered candidate -> { category, canonical }
for category, names in pairs(friendlyPlateCandidates) do
	for _, candidate in ipairs(names) do
		friendlyWatch[candidate:lower()] = { category = category, canonical = candidate }
	end
end
local friendlyResolved = {} -- category -> canonical name that read back
local lastFriendly = {} -- canonical name -> last seen value
addon.friendlyResolved = friendlyResolved
local driver = CreateFrame("Frame")
local outcomeTypes = { "MISS", "DODGE", "PARRY", "BLOCK", "RESIST", "EVADE", "IMMUNE", "ABSORB" }
-- "client" follows the running client's own localized combat text, so every
-- locale Blizzard ships is covered without a table here. The explicit entries
-- are overrides for players who want different wording than their client,
-- e.g. French on an English client. Override strings (and their menu names)
-- must stay within Latin-1: STANDARD_TEXT_FONT on Western clients renders
-- squares for Latin Extended-A letters such as Polish ł/ę/ś (confirmed in
-- game), and it has no Cyrillic or CJK glyphs either. Players on those
-- clients get native text from "client". Missing Blizzard globals fall back
-- to English. A saved locale that is no longer listed falls back to "client".
local outcomeLocaleData = {
	client = {
		name = "Game language",
		MISS = COMBAT_TEXT_MISS or "Miss",
		DODGE = COMBAT_TEXT_DODGE or "Dodge",
		PARRY = COMBAT_TEXT_PARRY or "Parry",
		BLOCK = COMBAT_TEXT_BLOCK or "Block",
		RESIST = COMBAT_TEXT_RESIST or "Resist",
		EVADE = COMBAT_TEXT_EVADE or "Evade",
		IMMUNE = COMBAT_TEXT_IMMUNE or "Immune",
		ABSORB = COMBAT_TEXT_ABSORB or "Absorb",
	},
	enUS = {
		name = "English",
		MISS = "Miss",
		DODGE = "Dodge",
		PARRY = "Parry",
		BLOCK = "Block",
		RESIST = "Resist",
		EVADE = "Evade",
		IMMUNE = "Immune",
		ABSORB = "Absorb",
	},
	deDE = {
		name = "Deutsch",
		MISS = "Verfehlt",
		DODGE = "Ausgewichen",
		PARRY = "Pariert",
		BLOCK = "Geblockt",
		RESIST = "Widerstanden",
		EVADE = "Entkommen",
		IMMUNE = "Immun",
		ABSORB = "Absorbiert",
	},
	frFR = {
		name = "Français",
		MISS = "Raté",
		DODGE = "Esquive",
		PARRY = "Parade",
		BLOCK = "Blocage",
		RESIST = "Résisté",
		EVADE = "Évité",
		IMMUNE = "Insensible",
		ABSORB = "Absorbé",
	},
	esES = {
		name = "Español",
		MISS = "Fallo",
		DODGE = "Esquiva",
		PARRY = "Parada",
		BLOCK = "Bloqueo",
		RESIST = "Resistido",
		EVADE = "Evadido",
		IMMUNE = "Inmune",
		ABSORB = "Absorbido",
	},
	ptBR = {
		name = "Português",
		MISS = "Errou",
		DODGE = "Esquivou",
		PARRY = "Aparou",
		BLOCK = "Bloqueou",
		RESIST = "Resistiu",
		EVADE = "Evadiu",
		IMMUNE = "Imune",
		ABSORB = "Absorveu",
	},
	itIT = {
		name = "Italiano",
		MISS = "Mancato",
		DODGE = "Schivato",
		PARRY = "Parato",
		BLOCK = "Bloccato",
		RESIST = "Resistito",
		EVADE = "Evitato",
		IMMUNE = "Immune",
		ABSORB = "Assorbito",
	},
	nlNL = {
		name = "Nederlands",
		MISS = "Mis",
		DODGE = "Ontweken",
		PARRY = "Gepareerd",
		BLOCK = "Geblokkeerd",
		RESIST = "Weerstaan",
		EVADE = "Ontsnapt",
		IMMUNE = "Immuun",
		ABSORB = "Geabsorbeerd",
	},
	csCZ = {
		name = "Czech (Cestina)",
		MISS = "Minutí",
		DODGE = "Úhyb",
		PARRY = "Vykrytí",
		BLOCK = "Blok",
		RESIST = "Odolání",
		EVADE = "Únik",
		IMMUNE = "Imunita",
		ABSORB = "Pohlcení",
	},
	svSE = {
		name = "Svenska",
		MISS = "Bom",
		DODGE = "Undvek",
		PARRY = "Parerade",
		BLOCK = "Blockerade",
		RESIST = "Motstod",
		EVADE = "Undkom",
		IMMUNE = "Immun",
		ABSORB = "Absorberad",
	},
	nbNO = {
		name = "Norsk (BiS)",
		MISS = "Bom",
		DODGE = "Unnvek",
		PARRY = "Parerte",
		BLOCK = "Blokkerte",
		RESIST = "Motsto",
		EVADE = "Unnslapp",
		IMMUNE = "Immun",
		ABSORB = "Absorbert",
	},
}
local outcomeLocaleOrder = {
	"client",
	"enUS",
	"deDE",
	"frFR",
	"esES",
	"ptBR",
	"itIT",
	"nlNL",
	"csCZ",
	"svSE",
	"nbNO",
}
addon.outcomeLocaleData = outcomeLocaleData
addon.outcomeLocaleOrder = outcomeLocaleOrder
addon.outcomeTypes = outcomeTypes
local currentOutcomeLocale, currentOutcomeLabels

function addon:GetOutcomeLabels()
	local key = self.db.outcomeLocale or "client"
	local data = outcomeLocaleData[key] or outcomeLocaleData.client
	if currentOutcomeLocale ~= data then
		local labels = {}
		for _, outcomeType in ipairs(outcomeTypes) do
			labels[outcomeType] = data[outcomeType]
		end
		currentOutcomeLocale, currentOutcomeLabels = data, labels
	end
	return currentOutcomeLabels
end
local schoolPalette = {
	{ 1, "physical", "Physical" },
	{ 2, "holy", "Holy" },
	{ 4, "fire", "Fire" },
	{ 8, "nature", "Nature" },
	{ 16, "frost", "Frost" },
	{ 32, "shadow", "Shadow" },
	{ 64, "arcane", "Arcane" },
}

addon.damageSchoolOptions = {}
for _, school in ipairs(schoolPalette) do
	addon.damageSchoolOptions[#addon.damageSchoolOptions + 1] = { key = school[2], label = school[3] }
end

addon.fontOptions = {
	{ key = "default", label = "Game default" },
	{ key = "friz", label = "Friz Quadrata" },
	{ key = "arialn", label = "Arial Narrow" },
	{ key = "morpheus", label = "Morpheus" },
	{ key = "skurri", label = "Skurri" },
}

local fontPaths = {
	friz = "Fonts\\FRIZQT__.TTF",
	arialn = "Fonts\\ARIALN.TTF",
	morpheus = "Fonts\\MORPHEUS.ttf",
	skurri = "Fonts\\skurri.ttf",
}

local function accessible(value)
	return not issecretvalue or not issecretvalue(value)
end

function addon:GetDisplayedOffset(key)
	local stored = tonumber(self.db[key])
	if stored == nil then
		stored = defaults[key]
	end
	return stored + 30
end

function addon:SetDisplayedOffset(key, value)
	local displayed = tonumber(value)
	if displayed == nil then
		return
	end
	self.db[key] = displayed - 30
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, entry in pairs(value) do
		result[key] = copy(entry)
	end
	return result
end

function addon:Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff80dfffForever Combat Text:|r " .. message)
end

local function retireAnchor(entry)
	entry.graceUntil = nil
	entry.listener:UnregisterAllEvents()
	entry.listener:SetScript("OnEvent", nil)
	entry.anchor:Hide()
	spareEntries[#spareEntries + 1] = entry
end

local function sweepHeldAnchors()
	for index = #heldAnchors, 1, -1 do
		local entry = heldAnchors[index]
		local used = entry.graceUntil ~= nil and entry.graceUntil > GetTime()
		for active_ = 1, #active do
			if used then
				break
			end
			if active[active_].anchor == entry.anchor then
				used = true
				break
			end
		end
		if not used then
			table.remove(heldAnchors, index)
			retireAnchor(entry)
		end
	end
end

local function release(index)
	local item = active[index]
	item.frame:Hide()
	item.text:SetText("")
	item.anchor = nil
	pool[#pool + 1] = item
	table.remove(active, index)
	sweepHeldAnchors()
end

local function clearPending()
	for unit, pentry in pairs(pendingEntries) do
		pendingEntries[unit] = nil
		pentry.listener:UnregisterAllEvents()
		pentry.listener:SetScript("OnEvent", nil)
		pentry.buffered = {}
		spareListeners[#spareListeners + 1] = pentry.listener
	end
	pending = {}
end

function addon:Clear()
	for index = #active, 1, -1 do
		release(index)
	end
	previewQueue = {}
	nextPreview = 0
	clearPending()
	while #heldAnchors > 0 do
		retireAnchor(table.remove(heldAnchors))
	end
end

function addon:ResetSettings()
	self:RestoreBlizzardDamage()
	self:RestoreBlizzardHealing()
	local previous = self.db.previousBlizzardDamage
	local previousCVar = self.db.previousBlizzardDamageCVar
	local previousHealing = self.db.previousBlizzardHealing
	ForeverCombatTextDB = copy(defaults)
	self.db = ForeverCombatTextDB
	self.db.nameplateDefaultsUpdated = true
	self.db.previousBlizzardDamage = previous
	self.db.previousBlizzardDamageCVar = previousCVar
	self.db.previousBlizzardHealing = previousHealing
	self:Clear()
	self:UpdateBlizzardDamage()
	self:UpdateBlizzardHealing()
	self:ApplyFriendlyVisibility()
	self:UpdateCityPlates()
	self:RefreshNameplates()
	self:Print("Settings reset to defaults.")
end

local function blizzardDamageCVar()
	if C_CVar.GetCVar("floatingCombatTextCombatDamage_v2") ~= nil then
		return "floatingCombatTextCombatDamage_v2"
	end
	return "floatingCombatTextCombatDamage"
end

function addon:RestoreBlizzardDamage()
	if self.db.previousBlizzardDamage == nil then
		return
	end
	local cvar = self.db.previousBlizzardDamageCVar or "floatingCombatTextCombatDamage"
	local value = self.db.previousBlizzardDamage
	if C_CVar.GetCVar(cvar) == nil then
		self.db.previousBlizzardDamage = nil
		self.db.previousBlizzardDamageCVar = nil
		return
	end
	local ok = pcall(C_CVar.SetCVar, cvar, value)
	if ok and C_CVar.GetCVar(cvar) == value then
		self.db.previousBlizzardDamage = nil
		self.db.previousBlizzardDamageCVar = nil
	end
end

function addon:UpdateBlizzardDamage()
	local cvar = blizzardDamageCVar()
	if
		self.db.previousBlizzardDamage ~= nil
		and (self.db.previousBlizzardDamageCVar or "floatingCombatTextCombatDamage") ~= cvar
	then
		self:RestoreBlizzardDamage()
		if self.db.previousBlizzardDamage ~= nil then
			return
		end
	end
	if self.db.enabled and self.db.damage and self.db.hideBlizzardDamage then
		local current = C_CVar.GetCVar(cvar)
		if not current then
			self:Print("This client does not expose the Blizzard damage-text setting.")
			return
		end
		if self.db.previousBlizzardDamage == nil then
			self.db.previousBlizzardDamage = current
			self.db.previousBlizzardDamageCVar = cvar
		end
		-- Plates-off fallback engages on the general switch alone; suppression
		-- needs our numbers to replace the text being hidden.
		local enemiesOff = C_CVar.GetCVar("nameplateShowEnemies") == "0"
		local desired
		if self.db.blizzardWhenPlatesOff and enemiesOff then
			desired = "1"
		elseif self.db.addonNumbers then
			desired = "0"
		else
			desired = current
		end
		if current == desired then
			return
		end
		local ok = pcall(C_CVar.SetCVar, cvar, desired)
		if not ok or C_CVar.GetCVar(cvar) ~= desired then
			self:Print("Could not update Blizzard damage text using " .. cvar .. "; will retry after combat.")
		end
	else
		self:RestoreBlizzardDamage()
	end
end

local HEALING_CVAR = "floatingCombatTextCombatHealing_v2"

-- True only when every friendly plate category positively reads off.
-- Unknown (nil) reads count as on, so the Blizzard-healing fallback only
-- engages when plates are definitely gone.
local function friendlyPlatesOff()
	local friends = C_CVar.GetCVar(friendlyResolved["friends"] or "nameplateShowFriendlyPlayers")
	local npcs = C_CVar.GetCVar("nameplateShowFriendlyNpcs")
	local minionsName = friendlyResolved["minions"] or friendlyResolved["friends"] or "nameplateShowFriendlyPlayers"
	local minions = C_CVar.GetCVar(minionsName)
	return friends == "0" and npcs == "0" and minions == "0"
end

-- Enforces effective friendly visibility: each category shows only when the
-- master Show Friendly toggle is on AND its addon preference is on.
function addon:ApplyFriendlyVisibility()
	if not self.db then
		return
	end
	local masterName = friendlyResolved["friends"] or "nameplateShowFriendlyPlayers"
	local master = C_CVar.GetCVar(masterName)
	if master ~= "0" and master ~= "1" then
		return
	end
	local wantNPCs = (master == "1" and self.db.npcPlates) and "1" or "0"
	if C_CVar.GetCVar("nameplateShowFriendlyNpcs") ~= wantNPCs then
		C_CVar.SetCVar("nameplateShowFriendlyNpcs", wantNPCs)
	end
	local minionsName = friendlyResolved["minions"]
	if minionsName then
		local wantMinions = (master == "1" and self.db.minionPlates) and "1" or "0"
		if C_CVar.GetCVar(minionsName) ~= wantMinions then
			C_CVar.SetCVar(minionsName, wantMinions)
		end
	end
end

-- "Disable friendly nameplates in cities" uses the rest state as its city
-- signal: capitals, towns and inns all grant rest, and the client exposes
-- no capital-city list. Hiding applies one-shot on entering (pre-city CVar
-- values are remembered) and restores on leaving or when the option is
-- turned off. Re-entering a zone or leaving combat re-applies the current
-- city state, so a manual re-enable while hidden lasts until the next such
-- event. Not yet verified in-game.
function addon:IsInCity()
	if type(IsResting) ~= "function" then
		return false
	end
	local ok, resting = pcall(IsResting)
	if not ok or not accessible(resting) then
		return false
	end
	return resting and true or false
end

local function setFriendlyCVar(name, value)
	if not name then
		return
	end
	if C_CVar.GetCVar(name) == value then
		return
	end
	pcall(C_CVar.SetCVar, name, value)
end

local function cityCVarNames()
	return friendlyResolved["friends"] or "nameplateShowFriendlyPlayers",
		"nameplateShowFriendlyNpcs",
		friendlyResolved["minions"]
end

function addon:UpdateCityPlates()
	if not self.db then
		return
	end
	local wantHiding = self.db.hideFriendlyInCities and self:IsInCity()
	if wantHiding and not self.cityHiding then
		local friendsName, npcsName, minionsName = cityCVarNames()
		self.citySaved = {
			friends = C_CVar.GetCVar(friendsName),
			npcs = C_CVar.GetCVar(npcsName),
			minions = minionsName and C_CVar.GetCVar(minionsName) or nil,
		}
		self.cityHiding = true
	elseif not wantHiding and self.cityHiding then
		local saved = self.citySaved
		self.cityHiding = nil
		self.citySaved = nil
		if saved then
			local friendsName, npcsName, minionsName = cityCVarNames()
			if saved.friends == "0" or saved.friends == "1" then
				setFriendlyCVar(friendsName, saved.friends)
			end
			if saved.npcs == "0" or saved.npcs == "1" then
				setFriendlyCVar(npcsName, saved.npcs)
			end
			if saved.minions == "0" or saved.minions == "1" then
				setFriendlyCVar(minionsName, saved.minions)
			end
		end
		self:ApplyFriendlyVisibility()
		self:UpdateBlizzardHealing()
		return
	end
	if self.cityHiding then
		local friendsName, npcsName, minionsName = cityCVarNames()
		setFriendlyCVar(friendsName, "0")
		setFriendlyCVar(npcsName, "0")
		setFriendlyCVar(minionsName, "0")
	end
end

function addon:RestoreCityPlates()
	if not self.cityHiding then
		return
	end
	local saved = self.citySaved
	self.cityHiding = nil
	self.citySaved = nil
	if saved then
		local friendsName, npcsName, minionsName = cityCVarNames()
		if saved.friends == "0" or saved.friends == "1" then
			setFriendlyCVar(friendsName, saved.friends)
		end
		if saved.npcs == "0" or saved.npcs == "1" then
			setFriendlyCVar(npcsName, saved.npcs)
		end
		if saved.minions == "0" or saved.minions == "1" then
			setFriendlyCVar(minionsName, saved.minions)
		end
	end
end

function addon:RestoreBlizzardHealing()
	local previous = self.db.previousBlizzardHealing
	if previous == nil then
		return
	end
	if C_CVar.GetCVar(HEALING_CVAR) == nil then
		self.db.previousBlizzardHealing = nil
		return
	end
	local ok = pcall(C_CVar.SetCVar, HEALING_CVAR, previous)
	if ok and C_CVar.GetCVar(HEALING_CVAR) == previous then
		self.db.previousBlizzardHealing = nil
	end
end

function addon:UpdateBlizzardHealing()
	local inside, instanceType = IsInInstance()
	local instanceHealing = self.db.enabled
		and self.db.blizzardInstanceHealing
		and inside
		and (instanceType == "party" or instanceType == "raid")
	local platesOffHealing = self.db.enabled
		and self.db.healing
		and self.db.blizzardHealingWhenPlatesOff
		and friendlyPlatesOff()
	if instanceHealing or platesOffHealing then
		local current = C_CVar.GetCVar(HEALING_CVAR)
		if current == nil then
			self:Print("This client does not expose the Blizzard outgoing-healing setting.")
			return
		end
		if self.db.previousBlizzardHealing == nil then
			self.db.previousBlizzardHealing = current
		end
		if current ~= "1" then
			local ok = pcall(C_CVar.SetCVar, HEALING_CVAR, "1")
			if not ok or C_CVar.GetCVar(HEALING_CVAR) ~= "1" then
				self:Print("Could not enable Blizzard outgoing healing; will retry after combat.")
			end
		end
	else
		self:RestoreBlizzardHealing()
	end
end

local function asColor(value, fallback)
	if type(value) == "table" and tonumber(value[1]) and tonumber(value[2]) and tonumber(value[3]) then
		return value
	end
	return fallback
end

function addon:GetFontPath()
	return fontPaths[self.db.fontFace] or STANDARD_TEXT_FONT
end

function addon:GetDamageColor(key)
	if key == "fallback" then
		return asColor(self.db.damageColor, defaults.damageColor)
	end
	local configured = type(self.db.damageSchoolColors) == "table" and self.db.damageSchoolColors[key]
	return asColor(configured, defaults.damageSchoolColors[key] or defaults.damageColor)
end

function addon:SetDamageColor(key, color)
	if key == "fallback" then
		self.db.damageColor = color
		return
	end
	if type(self.db.damageSchoolColors) ~= "table" then
		self.db.damageSchoolColors = copy(defaults.damageSchoolColors)
	end
	self.db.damageSchoolColors[key] = color
end

function addon:ResetDamageColors()
	self.db.damageColor = copy(defaults.damageColor)
	self.db.damageSchoolColors = copy(defaults.damageSchoolColors)
end

local function damageColor(mask)
	local fallback = asColor(addon.db.damageColor, defaults.damageColor)
	if not addon.db.schoolColors or not accessible(mask) or type(mask) ~= "number" then
		return fallback
	end
	local red, green, blue, count = 0, 0, 0, 0
	for _, school in ipairs(schoolPalette) do
		if bit.band(mask, school[1]) ~= 0 then
			local colors = type(addon.db.damageSchoolColors) == "table" and addon.db.damageSchoolColors
			local color = asColor(colors and colors[school[2]], defaults.damageSchoolColors[school[2]])
			red, green, blue = red + color[1], green + color[2], blue + color[3]
			count = count + 1
		end
	end
	if count == 0 then
		return fallback
	end
	return { red / count, green / count, blue / count }
end

local function acquire()
	local item = table.remove(pool)
	if item then
		return item
	end
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(180, 40)
	frame:SetFrameStrata("HIGH")
	frame:SetClipsChildren(false)
	frame:EnableMouse(false)
	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetSize(2048, 256)
	text:SetPoint("CENTER", frame, "CENTER")
	text:SetJustifyH("CENTER")
	return { frame = frame, text = text }
end

function addon:Float(anchor, amount, kind, schoolMask, critical, xOverride, textOverride, isPreview)
	if #active >= 100 then
		release(1)
	end
	local item = acquire()
	item.anchor = anchor
	item.age = 0
	item.duration = tonumber(self.db.duration) or defaults.duration
	local baseOffset = tonumber(kind == "healing" and self.db.healingPlateOffset or self.db.damagePlateOffset)
		or (kind == "healing" and defaults.healingPlateOffset or defaults.damagePlateOffset)
	item.offset = baseOffset
	item.rise = kind == "healing" and 35 or 65
	if kind == "outcome" then
		item.rise = 20
	end
	item.critical = critical == true
	local baseSize = tonumber(self.db.fontSize) or defaults.fontSize
	baseSize = math.max(MIN_FONT_SIZE, math.min(MAX_FONT_SIZE, baseSize))
	item.fontSize = item.critical and math.min(baseSize * 2, MAX_CRITICAL_TEXT_HEIGHT) or baseSize
	item.maxPulseTextHeight = item.critical
			and math.min(item.fontSize * (1 + CRITICAL_PULSE_SCALE), MAX_CRITICAL_TEXT_HEIGHT)
		or item.fontSize
	self.sequence = (self.sequence or 0) + 1
	local spread = item.fontSize * 0.8
	item.x = xOverride or ((self.sequence % 5) - 2) * spread
	item.offset = item.offset - (self.sequence % 2) * (spread * 0.6)
	item.text:SetFont(self:GetFontPath(), item.fontSize, "OUTLINE")
	item.text:SetTextHeight(item.maxPulseTextHeight)
	item.text:SetSize(2048, 256)
	local color
	if kind == "healing" then
		color = asColor(self.db.healingColor, defaults.healingColor)
	elseif kind == "outcome" then
		color = asColor(self.db.outcomeColor, defaults.outcomeColor)
	else
		color = damageColor(schoolMask)
	end
	item.text:SetTextColor(color[1], color[2], color[3])
	if textOverride then
		item.text:SetText(textOverride)
	else
		item.text:SetFormattedText(kind == "healing" and "+%s" or "%s", amount)
	end
	local textWidth = math.ceil(item.text:GetStringWidth() + 16)
	local textHeight = math.ceil(item.maxPulseTextHeight + 16)
	item.text:SetSize(math.max(180, textWidth), math.max(40, textHeight))
	item.text:SetTextHeight(item.fontSize)
	item.frame:ClearAllPoints()
	item.frame:SetPoint("BOTTOM", anchor, "TOP", item.x, item.offset)
	item.frame:SetAlpha(1)
	item.frame:Show()
	active[#active + 1] = item
	if isPreview then
		stats.previewed = stats.previewed + 1
	else
		stats.displayed = stats.displayed + 1
	end
end

local function pumpPreview()
	local sample = table.remove(previewQueue, 1)
	if not sample then
		nextPreview = 0
		return
	end
	local x = ((addon.sequence or 0) % 5 - 2) * 18 + (math.random() * 2 - 1) * 14
	addon:Float(sample.anchor, sample.amount, sample.kind, sample.school, sample.critical, x, sample.text, true)
	nextPreview = (#previewQueue > 0) and (0.09 + math.random() * 0.07) or 0
end

driver:SetScript("OnUpdate", function(_, elapsed)
	if nextPreview > 0 then
		nextPreview = nextPreview - elapsed
		if nextPreview <= 0 then
			pumpPreview()
		end
	end
	if next(pending) then
		addon.RetryPending()
	end
	if #heldAnchors > 0 then
		sweepHeldAnchors()
	end
	for index = #active, 1, -1 do
		local item = active[index]
		item.age = item.age + elapsed
		if item.age >= item.duration then
			release(index)
		else
			local progress = item.age / item.duration
			if item.critical and item.age < PULSE_GROW + PULSE_SETTLE then
				local pulse
				if item.age < PULSE_GROW then
					pulse = item.age / PULSE_GROW
				else
					pulse = (PULSE_GROW + PULSE_SETTLE - item.age) / PULSE_SETTLE
				end
				item.text:SetTextHeight(
					math.min(item.fontSize * (1 + pulse * CRITICAL_PULSE_SCALE), MAX_CRITICAL_TEXT_HEIGHT)
				)
			end
			item.frame:ClearAllPoints()
			item.frame:SetPoint("BOTTOM", item.anchor, "TOP", item.x, item.offset + progress * item.rise)
			item.frame:SetAlpha(math.min(1, (1 - progress) * 3))
		end
	end
end)

local function isTarget(unit)
	local matches = UnitIsUnit(unit, "target")
	return accessible(matches) and matches
end

local function remembered(entry, key, live)
	if not entry.removed then
		local value = live(entry.unit)
		if accessible(value) then
			entry[key] = value and true or false
			return entry[key], false
		end
	end
	return entry[key], true
end

local function liveHostile(unit)
	return UnitCanAttack("player", unit)
end

local function liveFriendly(unit)
	local friendly = UnitCanAssist("player", unit)
	if accessible(friendly) and friendly then
		return true
	end
	if UnitIsFriend then
		local isFriend = UnitIsFriend("player", unit)
		if accessible(isFriend) and isFriend then
			return true
		end
	end
	if UnitInRaid then
		local inRaid = UnitInRaid(unit)
		if accessible(inRaid) and inRaid then
			return true
		end
	end
	if UnitInParty then
		local inParty = UnitInParty(unit)
		if accessible(inParty) and inParty then
			return true
		end
	end
	return false
end

local function liveHealingRecipient(unit)
	local friendly = UnitCanAssist("player", unit)
	local selfUnit = UnitIsUnit("player", unit)
	if not accessible(friendly) or not accessible(selfUnit) then
		return nil
	end
	return friendly and not selfUnit
end

local function handleCombat(entry, eventType, flagText, amount, schoolMask)
	local unit, anchor = entry.unit, entry.anchor
	stats.events = stats.events + 1
	if not accessible(eventType) then
		stats.secretTypes = stats.secretTypes + 1
		return
	end
	local kind, outcomeText
	local outcomeLabels = addon:GetOutcomeLabels()
	if eventType == "HEAL" then
		kind = "healing"
		stats.healing = stats.healing + 1
	elseif eventType == "WOUND" then
		if not accessible(amount) then
			return
		end
		if amount == 0 or amount == "0" then
			stats.absorbed = stats.absorbed + 1
			if addon.db.showOutcomes then
				kind = "outcome"
				outcomeText = outcomeLabels.ABSORB
				stats.outcomes = stats.outcomes + 1
			else
				return
			end
		else
			kind = "damage"
			stats.damage = stats.damage + 1
		end
	else
		outcomeText = accessible(eventType) and outcomeLabels[eventType] or nil
		if not outcomeText then
			return
		end
		kind = "outcome"
		stats.outcomes = stats.outcomes + 1
	end
	if not addon.db.enabled or not addon.db.addonNumbers then
		return
	end
	if kind == "outcome" then
		if not addon.db.showOutcomes then
			return
		end
	elseif not addon.db[kind] then
		return
	end
	if kind == "damage" or kind == "healing" then
		if not accessible(amount) then
			return
		end
		if type(amount) ~= "number" and type(amount) ~= "string" then
			return
		end
	end

	if kind == "damage" or kind == "outcome" then
		local hostile, fromCache = remembered(entry, "hostile", liveHostile)
		if hostile == nil then
			local targeted
			if entry.removed then
				targeted = entry.isTarget
			else
				targeted = isTarget(unit)
			end
			if not targeted or liveFriendly(unit) then
				stats.noPlate = stats.noPlate + 1
				return
			end
			hostile = true
			fromCache = false
			stats.targetFallback = stats.targetFallback + 1
		end
		if not hostile then
			return
		end
		if fromCache and not entry.removed then
			stats.cachedHostility = stats.cachedHostility + 1
		end
		if addon.db.scope == "target" then
			if entry.removed then
				if not entry.isTarget then
					return
				end
			elseif not isTarget(unit) then
				return
			end
		end
	else
		local friendlyRecipient = remembered(entry, "friendlyRecipient", liveHealingRecipient)
		if not friendlyRecipient then
			return
		end
	end
	if entry.removed then
		stats.graceHits = stats.graceHits + 1
	end
	local critical = accessible(flagText) and flagText == "CRITICAL"
	if kind == "outcome" then
		addon:Float(anchor, 0, "outcome", nil, false, nil, outcomeText)
	else
		addon:Float(anchor, amount, kind, schoolMask, critical)
	end
end

local function anchorIsUsed(anchor)
	for index = 1, #active do
		if active[index].anchor == anchor then
			return true
		end
	end
	return false
end

local function stopPending(unit)
	pending[unit] = nil
	local pentry = pendingEntries[unit]
	if pentry then
		pendingEntries[unit] = nil
		pentry.listener:UnregisterAllEvents()
		pentry.listener:SetScript("OnEvent", nil)
		spareListeners[#spareListeners + 1] = pentry.listener
	end
	return pentry
end

local function watchPending(unit)
	local pentry = pendingEntries[unit]
	if not pentry then
		local listener = table.remove(spareListeners)
		if not listener then
			listener = CreateFrame("Frame")
		end
		pentry = { listener = listener, buffered = {} }
		pendingEntries[unit] = pentry
	end
	pending[unit] = GetTime() + PENDING_TIMEOUT
	local listener = pentry.listener
	if pcall(listener.RegisterUnitEvent, listener, "UNIT_COMBAT", unit) then
		listener:SetScript("OnEvent", function(_, _, _, eventType, flagText, amount, schoolMask)
			if #pentry.buffered < PENDING_BUFFER_MAX then
				pentry.buffered[#pentry.buffered + 1] = {
					eventType = eventType,
					flagText = flagText,
					amount = amount,
					schoolMask = schoolMask,
				}
			end
		end)
	else
		stopPending(unit)
		pending[unit] = GetTime() + PENDING_TIMEOUT
	end
end

local function removePlate(unit, immediate)
	stopPending(unit)
	local entry = plates[unit]
	if not entry then
		return
	end
	plates[unit] = nil
	addon:UnstylePlate(entry.plate)
	entry.removed = true
	if immediate then
		entry.listener:UnregisterAllEvents()
		entry.listener:SetScript("OnEvent", nil)
	else
		entry.graceUntil = GetTime() + REMOVAL_GRACE
	end
	if immediate and not anchorIsUsed(entry.anchor) then
		retireAnchor(entry)
	else
		heldAnchors[#heldAnchors + 1] = entry
	end
end

local function sweepStalePlates()
	local stale
	for unit, entry in pairs(plates) do
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
		if ok and plate ~= entry.plate then
			stale = stale or {}
			stale[#stale + 1] = unit
		end
	end
	if stale then
		for _, unit in ipairs(stale) do
			removePlate(unit)
		end
	end
end

local function releaseReused(unit, plate)
	for index = #heldAnchors, 1, -1 do
		local entry = heldAnchors[index]
		if entry and entry.unit == unit and entry.graceUntil then
			entry.graceUntil = nil
			entry.listener:UnregisterAllEvents()
			entry.listener:SetScript("OnEvent", nil)
		end
		if entry and entry.plate == plate then
			for item = #active, 1, -1 do
				if active[item].anchor == entry.anchor then
					stats.reuseDrops = stats.reuseDrops + 1
					release(item)
				end
			end
			if heldAnchors[index] == entry then
				table.remove(heldAnchors, index)
				retireAnchor(entry)
			end
		end
	end
end

local function addPlate(unit, late)
	if not accessible(unit) or plates[unit] then
		return
	end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate or plate:IsForbidden() then
		if not pending[unit] or not pendingEntries[unit] then
			watchPending(unit)
		end
		return
	end
	local pentry = stopPending(unit)
	releaseReused(unit, plate)
	if late then
		stats.latePlates = stats.latePlates + 1
	end
	local entry = table.remove(spareEntries)
	if not entry then
		entry = { anchor = CreateFrame("Frame", nil, UIParent), listener = CreateFrame("Frame") }
		entry.anchor:SetSize(1, 1)
	end
	local anchor = entry.anchor
	entry.plate = plate
	entry.unit = unit
	entry.removed = nil
	entry.graceUntil = nil
	entry.hostile = nil
	entry.friendlyRecipient = nil
	remembered(entry, "hostile", liveHostile)
	remembered(entry, "friendlyRecipient", liveHealingRecipient)
	entry.isTarget = isTarget(unit) and true or false
	anchor:ClearAllPoints()
	anchor:SetPoint("BOTTOM", plate, "TOP", 0, 0)
	anchor:Show()
	local listener = entry.listener
	plates[unit] = entry
	addon:StylePlate(plate, unit)
	listener:RegisterUnitEvent("UNIT_COMBAT", unit)
	listener:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", unit)
	listener:RegisterUnitEvent("UNIT_FACTION", unit)
	listener:SetScript("OnEvent", function(_, event, _, eventType, flagText, amount, schoolMask)
		if event == "UNIT_COMBAT" then
			handleCombat(entry, eventType, flagText, amount, schoolMask)
		elseif not entry.removed then
			addon:StylePlate(entry.plate, entry.unit)
		end
	end)
	if pentry and #pentry.buffered > 0 then
		stats.bufferedHits = stats.bufferedHits + #pentry.buffered
		for _, buffered in ipairs(pentry.buffered) do
			handleCombat(entry, buffered.eventType, buffered.flagText, buffered.amount, buffered.schoolMask)
		end
	end
end

local function retryPending()
	local units
	local now = GetTime()
	for unit, expires in pairs(pending) do
		units = units or {}
		units[#units + 1] = unit
		if expires <= now then
			stopPending(unit)
		end
	end
	if not units then
		return
	end
	for _, unit in ipairs(units) do
		if pending[unit] then
			addPlate(unit, true)
		end
	end
end
addon.RetryPending = retryPending

function addon:Preview()
	local anchor
	for unit, entry in pairs(plates) do
		if isTarget(unit) then
			anchor = entry.anchor
			break
		end
	end
	if not anchor then
		local _, entry = next(plates)
		anchor = entry and entry.anchor
	end
	if not anchor then
		self:Print(
			"No accessible nameplate is visible. Enable nameplates and target a nearby unit, then try /fct preview again."
		)
		return
	end
	for index, school in ipairs(schoolPalette) do
		previewQueue[#previewQueue + 1] =
			{ anchor = anchor, amount = 100 + index * 17, kind = "damage", school = school[1] }
	end
	previewQueue[#previewQueue + 1] = { anchor = anchor, amount = 246, kind = "damage", school = 4, critical = true }
	previewQueue[#previewQueue + 1] = { anchor = anchor, amount = 85, kind = "healing" }
	previewQueue[#previewQueue + 1] =
		{ anchor = anchor, amount = 0, kind = "outcome", text = addon:GetOutcomeLabels().MISS }
	previewQueue[#previewQueue + 1] =
		{ anchor = anchor, amount = 0, kind = "outcome", text = addon:GetOutcomeLabels().ABSORB }
	pumpPreview()
	self:Print("Damage preview shown for all seven schools, plus critical, healing, miss and absorb samples.")
end

function addon:Status()
	local count = 0
	for _ in pairs(plates) do
		count = count + 1
	end
	local version, build = GetBuildInfo()
	self:Print("Client " .. version .. " (" .. build .. "); tracked nameplates: " .. count)
	local cvar = blizzardDamageCVar()
	self:Print("Damage scope: " .. self.db.scope .. "; " .. cvar .. ": " .. (C_CVar.GetCVar(cvar) or "unavailable"))
	self:Print(
		HEALING_CVAR
			.. ": "
			.. (C_CVar.GetCVar(HEALING_CVAR) or "unavailable")
			.. "; native instance healing: "
			.. (self.db.blizzardInstanceHealing and "on" or "off")
	)
	self:Print(
		string.format(
			"UNIT_COMBAT events: %d; damage: %d; heals: %d; numbers shown: %d",
			stats.events,
			stats.damage,
			stats.healing,
			stats.displayed
		)
	)
	self:Print(
		string.format(
			"Late nameplates: %d; hits after plate removal: %d; hits using remembered hostility: %d; target fallback: %d; hits from pending buffers: %d.",
			stats.latePlates,
			stats.graceHits,
			stats.cachedHostility,
			stats.targetFallback,
			stats.bufferedHits
		)
	)
	self:Print(string.format("Numbers dropped early because their nameplate was reused: %d.", stats.reuseDrops))
	self:Print(
		string.format(
			"Outcomes (miss/dodge/parry/block/resist): %d seen, showing: %s.",
			stats.outcomes,
			self.db.showOutcomes and "on" or "off"
		)
	)
	local localeData = outcomeLocaleData[self.db.outcomeLocale or "client"] or outcomeLocaleData.client
	self:Print(string.format("Outcome text language: %s.", localeData.name))
	self:Print(
		string.format(
			"Skipped: %d zero-damage wounds, %d unreadable hostility, %d secret event type.",
			stats.absorbed,
			stats.noPlate,
			stats.secretTypes
		)
	)
	self:Print("All sources are combined. UNIT_COMBAT does not identify the attacker/healer or DoT damage.")
	local styling = self.styleStats
	if styling then
		self:Print(
			string.format(
				"NPC styling: %d styled (%d tinted, %d hidden); %d deferred in combat; %d restored; skipped %d forbidden, %d secret.",
				styling.styled,
				styling.tinted,
				styling.hidden,
				styling.deferred,
				styling.restored,
				styling.skippedForbidden,
				styling.skippedSecret
			)
		)
	end
	self:Print(
		string.format(
			"Friendly plates toggled %dx (%dx on, %dx off) this session.",
			stats.friendlyToggles,
			stats.friendlyOn,
			stats.friendlyOff
		)
	)
end

function addon:Report()
	local elapsed = GetTime() - (self.sessionStart or GetTime())
	local minutes = math.floor(elapsed / 60 + 0.5)
	self:Print(string.format("Session report (%d min, copy everything below):", minutes))
	local styling = self.styleStats or {}
	self:Print(
		string.format(
			"styling styled=%d tinted=%d hidden=%d deferred=%d restored=%d skipForbidden=%d skipSecret=%d",
			styling.styled or 0,
			styling.tinted or 0,
			styling.hidden or 0,
			styling.deferred or 0,
			styling.restored or 0,
			styling.skippedForbidden or 0,
			styling.skippedSecret or 0
		)
	)
	local function friendlyState(category)
		local name = friendlyResolved[category]
		if name == nil and category == "minions" then
			name = friendlyResolved["friends"]
		end
		if name then
			return C_CVar.GetCVar(name) or "?"
		end
		return "?"
	end
	local function friendlyName(category)
		if friendlyResolved[category] then
			return friendlyResolved[category]
		end
		if category == "minions" then
			return "follows friends"
		end
		return "?"
	end
	self:Print(
		string.format(
			"friendly friends=%s npcs=%s minions=%s onlyNames=%s toggles=%d on=%d off=%d",
			friendlyState("friends"),
			friendlyState("npcs"),
			friendlyState("minions"),
			C_CVar.GetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits") or "?",
			stats.friendlyToggles,
			stats.friendlyOn,
			stats.friendlyOff
		)
	)
	self:Print(
		string.format(
			"cvars friends=%s npcs=%s minions=%s",
			friendlyName("friends"),
			friendlyName("npcs"),
			friendlyName("minions")
		)
	)
	self:Print(
		string.format(
			"healFallback enabled=%s addonNums=%s healingOpt=%s fallbackOpt=%s platesOff=%s healCVar=%s prev=%s",
			tostring(self.db.enabled),
			tostring(self.db.addonNumbers),
			tostring(self.db.healing),
			tostring(self.db.blizzardHealingWhenPlatesOff),
			tostring(friendlyPlatesOff()),
			C_CVar.GetCVar(HEALING_CVAR) or "?",
			self.db.previousBlizzardHealing or "-"
		)
	)
	self:Print(
		string.format(
			"combat events=%d damage=%d heals=%d shown=%d outcomes=%d drops: reuse=%d noPlate=%d absorbed=%d secret=%d",
			stats.events,
			stats.damage,
			stats.healing,
			stats.displayed,
			stats.outcomes,
			stats.reuseDrops,
			stats.noPlate,
			stats.absorbed,
			stats.secretTypes
		)
	)
	self:Print(
		string.format(
			"recovery late=%d grace=%d remembered=%d targetFallback=%d buffered=%d scope=%s",
			stats.latePlates,
			stats.graceHits,
			stats.cachedHostility,
			stats.targetFallback,
			stats.bufferedHits,
			self.db.scope
		)
	)
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_UPDATE_RESTING")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:RegisterEvent("CVAR_UPDATE")
driver:SetScript("OnEvent", function(_, event, unit)
	if event == "ADDON_LOADED" then
		if unit ~= addonName then
			return
		end
		if type(ForeverCombatTextDB) ~= "table" then
			ForeverCombatTextDB = {}
		end
		for key, value in pairs(defaults) do
			if ForeverCombatTextDB[key] == nil then
				ForeverCombatTextDB[key] = copy(value)
			end
		end
		addon.db = ForeverCombatTextDB
		addon.sessionStart = GetTime()
		for category, names in pairs(friendlyPlateCandidates) do
			for _, candidate in ipairs(names) do
				local value = C_CVar.GetCVar(candidate)
				if value ~= nil then
					friendlyResolved[category] = candidate
					lastFriendly[candidate] = value
					break
				end
			end
		end
		addon.db.screenHealing = nil
		addon.db.healingX = nil
		addon.db.healingY = nil
		addon.db.friendlyNamesOnly = nil -- Removed in 0.10.1: NPC styling is automatic.
		if not addon.db.nameplateDefaultsUpdated then
			addon.db.scope = "combat"
			addon.db.nameplateDefaultsUpdated = true
		end
		addon:UpdateBlizzardDamage()
		addon:UpdateBlizzardHealing()
		addon:ApplyFriendlyVisibility()
		addon:UpdateCityPlates()
		if addon.InitializeOptions then
			addon:InitializeOptions()
		end
	elseif addon.db then
		if event == "CVAR_UPDATE" then
			if addon.watchUntil and GetTime() < addon.watchUntil then
				addon.watchCount = (addon.watchCount or 0) + 1
				if addon.watchCount <= 40 and accessible(unit) and type(unit) == "string" then
					addon:Print("cvar " .. unit .. "=" .. (C_CVar.GetCVar(unit) or "nil"))
				end
			end
			if accessible(unit) and type(unit) == "string" and unit:lower() == "nameplateshowenemies" then
				addon:UpdateBlizzardDamage()
			end
			if
				accessible(unit)
				and type(unit) == "string"
				and unit:lower() == "nameplateshowonlynameforfriendlyplayerunits"
			then
				addon:RefreshNameplates()
			end
			if accessible(unit) and type(unit) == "string" then
				local watch = friendlyWatch[unit:lower()]
				if watch then
					local value = C_CVar.GetCVar(watch.canonical)
					if value == "0" or value == "1" then
						if friendlyResolved[watch.category] == nil then
							friendlyResolved[watch.category] = watch.canonical
						end
						if lastFriendly[watch.canonical] ~= nil and lastFriendly[watch.canonical] ~= value then
							stats.friendlyToggles = stats.friendlyToggles + 1
							if value == "1" then
								stats.friendlyOn = stats.friendlyOn + 1
							else
								stats.friendlyOff = stats.friendlyOff + 1
							end
						end
						lastFriendly[watch.canonical] = value
					end
				end
				-- Adopt external NPC/minion choices as addon prefs, but only
				-- while the master toggle is on. When it is off, CVar flips
				-- are our own enforcement echoes and must not overwrite the
				-- saved prefs. Afterwards re-enforce effective visibility and
				-- refresh the plates-off healing fallback.
				local masterName = friendlyResolved["friends"] or "nameplateShowFriendlyPlayers"
				local minionsName = friendlyResolved["minions"]
				local lowered = unit:lower()
				local relevant = lowered == masterName:lower() or lowered == "nameplateshowfriendlynpcs"
				if minionsName and lowered == minionsName:lower() then
					relevant = true
				end
				if relevant then
					if C_CVar.GetCVar(masterName) == "1" then
						if lowered == "nameplateshowfriendlynpcs" then
							local value = C_CVar.GetCVar("nameplateShowFriendlyNpcs")
							if value == "0" or value == "1" then
								addon.db.npcPlates = (value == "1")
							end
						elseif minionsName and lowered == minionsName:lower() then
							local value = C_CVar.GetCVar(minionsName)
							if value == "0" or value == "1" then
								addon.db.minionPlates = (value == "1")
							end
						end
					end
					addon:ApplyFriendlyVisibility()
					addon:UpdateBlizzardHealing()
				end
			end
		elseif event == "PLAYER_LOGOUT" then
			addon:RestoreBlizzardDamage()
			addon:RestoreBlizzardHealing()
			addon:RestoreCityPlates()
		elseif event == "PLAYER_REGEN_ENABLED" then
			addon:UpdateBlizzardDamage()
			addon:UpdateBlizzardHealing()
			addon:UpdateCityPlates()
			for token, entry in pairs(plates) do
				addon:StylePlate(entry.plate, token)
			end
			addon:RefreshNameplates()
		elseif event == "NAME_PLATE_UNIT_ADDED" then
			addPlate(unit)
		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			if accessible(unit) then
				removePlate(unit)
			else
				sweepStalePlates()
			end
		elseif event == "PLAYER_ENTERING_WORLD" then
			addon:UpdateBlizzardDamage()
			addon:UpdateBlizzardHealing()
			addon:UpdateCityPlates()
			addon:Clear()
			local oldUnits = {}
			for token in pairs(plates) do
				oldUnits[#oldUnits + 1] = token
			end
			for _, token in ipairs(oldUnits) do
				removePlate(token, true)
			end
			for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
				if not plate:IsForbidden() and accessible(plate.namePlateUnitToken) and plate.namePlateUnitToken then
					addPlate(plate.namePlateUnitToken)
				end
			end
			retryPending()
		elseif event == "PLAYER_UPDATE_RESTING" then
			addon:UpdateCityPlates()
		elseif event == "PLAYER_TARGET_CHANGED" then
			retryPending()
			for token, entry in pairs(plates) do
				entry.isTarget = isTarget(token) and true or false
			end
			for _, entry in ipairs(heldAnchors) do
				entry.isTarget = isTarget(entry.unit) and true or false
			end
		end
	end
end)
