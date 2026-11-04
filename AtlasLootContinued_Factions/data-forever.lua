-----------------------------------------------------------------------
-- Upvalued Lua API.
-----------------------------------------------------------------------
local _G = getfenv(0)

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local addonname = ...
local AtlasLoot = _G.AtlasLoot
if AtlasLoot:GameVersion_LT(AtlasLoot.FOREVER_VERSION_NUM) then return end

-- Not yet claiming the Forever version tag via ItemDB:Add() here on purpose: doing so with no content
-- registered under it makes GetAviableGameVersion() return the Forever tag for this module even though
-- nothing is tagged with it, which hides every Classic-tagged faction below instead of falling back to
-- them. Add the ItemDB:Add() call back once real content is added here.
local AL = AtlasLoot.Locales
local ALIL = AtlasLoot.IngameLocales

-- TODO: World of Warcraft: Forever - add faction/reputation reward content here once known.
