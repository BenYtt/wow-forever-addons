-----------------------------------------------------------------------
-- Client API compatibility.
--
-- Blizzard keeps moving the global API into C_* namespaces and retiring
-- the old globals, but not on every client at once: Classic Era,
-- Anniversary, Wrath and Forever each sit at a different point. Every
-- client API the addon calls that has moved is resolved here, once, by
-- preferring the C_* function and falling back to the legacy global.
--
-- Where a client has the C_* function, the entry below IS that function
-- (no wrapper, no behaviour change). Adapters only exist where the two
-- forms really differ: the argument order of GetAddOnEnableState and the
-- return shape of GetSpellInfo. Entries are named after their C_* name.
--
-- If an API exists in neither form the entry becomes a stub that returns
-- nothing, and its name is added to Compat.missing (inspect it in game
-- with /dump AtlasLoot.Compat.missing), so the addon degrades instead of
-- failing to load on a client this file doesn't know about yet.
--
-- Files use this through AtlasLoot.Compat rather than touching C_Item,
-- C_Spell or C_AddOns directly.
-----------------------------------------------------------------------
local _G = getfenv(0)
local select = _G.select

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local _, ALPrivate = ...

local Compat = { missing = {} }
ALPrivate.Compat = Compat

local function Stub() end

local function Resolve(name, modern, legacy)
	local func = modern or legacy
	if not func then
		Compat.missing[#Compat.missing + 1] = name
		func = Stub
	end
	Compat[name] = func
end

local C_AddOns = _G.C_AddOns or {}
local C_Item = _G.C_Item or {}
local C_Spell = _G.C_Spell or {}

-- ##############################
-- Secret values
-- ##############################
-- Newer clients hand back "secret" values (a unit's GUID, for one) that
-- tainted code may not concatenate, split or use as a table key. Older
-- clients have no such thing, so there nothing is ever secret.
Compat.issecretvalue = _G.issecretvalue or function() return false end

-- ##############################
-- AddOns
-- ##############################
Resolve("GetNumAddOns", C_AddOns.GetNumAddOns, _G.GetNumAddOns)
Resolve("GetAddOnInfo", C_AddOns.GetAddOnInfo, _G.GetAddOnInfo)
Resolve("GetAddOnMetadata", C_AddOns.GetAddOnMetadata, _G.GetAddOnMetadata)
Resolve("IsAddOnLoaded", C_AddOns.IsAddOnLoaded, _G.IsAddOnLoaded)
Resolve("LoadAddOn", C_AddOns.LoadAddOn, _G.LoadAddOn)

-- C_AddOns takes (addon, character) where the legacy global took (character, addon).
local LegacyGetAddOnEnableState = _G.GetAddOnEnableState
Resolve("GetAddOnEnableState", C_AddOns.GetAddOnEnableState, LegacyGetAddOnEnableState and function(addon, character)
	return LegacyGetAddOnEnableState(character, addon)
end)

-- ##############################
-- Items
-- ##############################
Resolve("GetItemInfo", C_Item.GetItemInfo, _G.GetItemInfo)
Resolve("GetItemInfoInstant", C_Item.GetItemInfoInstant, _G.GetItemInfoInstant)
Resolve("GetItemIconByID", C_Item.GetItemIconByID, _G.GetItemIcon)
Resolve("GetItemCount", C_Item.GetItemCount, _G.GetItemCount)
Resolve("IsEquippableItem", C_Item.IsEquippableItem, _G.IsEquippableItem)
Resolve("GetItemQualityColor", C_Item.GetItemQualityColor, _G.GetItemQualityColor)
Resolve("GetItemClassInfo", C_Item.GetItemClassInfo, _G.GetItemClassInfo)
Resolve("GetItemSubClassInfo", C_Item.GetItemSubClassInfo, _G.GetItemSubClassInfo)
Resolve("GetItemSetInfo", C_Item.GetItemSetInfo, _G.GetItemSetInfo)
Resolve("GetItemStats", C_Item.GetItemStats, _G.GetItemStats)

-- No legacy global for these two; derive them from the ones above.
Resolve("GetItemQualityByID", C_Item.GetItemQualityByID, Compat.GetItemInfo ~= Stub and function(item)
	return (select(3, Compat.GetItemInfo(item)))
end)
Resolve("DoesItemExistByID", C_Item.DoesItemExistByID, Compat.GetItemInfoInstant ~= Stub and function(item)
	return Compat.GetItemInfoInstant(item) ~= nil
end)

-- ##############################
-- Spells
-- ##############################
Resolve("GetSpellTexture", C_Spell.GetSpellTexture, _G.GetSpellTexture)
Resolve("GetSpellDescription", C_Spell.GetSpellDescription, _G.GetSpellDescription)

local LegacyGetSpellInfo = _G.GetSpellInfo
Resolve("GetSpellName", C_Spell.GetSpellName, LegacyGetSpellInfo and function(spell)
	return (LegacyGetSpellInfo(spell))
end)

-- C_Spell.GetSpellInfo returns a table where the legacy global returned several values.
Resolve("GetSpellInfo", C_Spell.GetSpellInfo, LegacyGetSpellInfo and function(spell)
	local name, _, icon, castTime, minRange, maxRange, spellID, originalIcon = LegacyGetSpellInfo(spell)
	if not name then return end
	return {
		name = name,
		iconID = icon,
		originalIconID = originalIcon or icon,
		castTime = castTime,
		minRange = minRange,
		maxRange = maxRange,
		spellID = spellID,
	}
end)
