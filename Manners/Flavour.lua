-- Manners -- which client this is.
--
-- The live clients disagree about things no API will answer: whether a macro
-- conditional can name a player, whether UnitName's second return is a realm
-- or a surname, whether the combat log exists at all. So the client's identity
-- is worked out once, here, loaded first in the toc, and every later file asks
-- this one rather than re-deriving it.
--
-- The five, as of September 2026, and the toc each loads:
--
--   retail "Midnight" 12.1   interface 120100+   Manners_Mainline.toc
--   WoW Forever 1.60.1       interface 16001     Manners_Camelot.toc
--   Mists of Pandaria        interface 50504     Manners_Mists.toc
--   BC Classic Anniversary   interface 20506     Manners_TBC.toc
--   Classic Era 1.15.9       interface 11509     Manners_Vanilla.toc
--
-- All five ship: Classic Era since 1.6.7, the other three since 1.7.0.

local _, ns = ...
local L = ns.L

-- issecretvalue is absent on clients that never had secret values. Local, not
-- global: writing _G.issecretvalue would hand every other addon our idea of
-- what is secret.
local issecretvalue = _G.issecretvalue or function() return false end

-- Anything the client hands back may be a secret value, which throws on
-- comparison, so everything branched on here passes through this first. A
-- deliberate copy of Core.lua's plain(), because this file loads before Core.
local function plain(v)
	if issecretvalue(v) then return nil end
	return v
end

---------------------------------------------------------------------------
-- the interface number
---------------------------------------------------------------------------

-- The bands, in the order they are tried, and the order is load-bearing.
-- Forever's 16001 and Classic Era's 11509 are both five digits starting with a
-- 1, so matching on a leading digit or a digit count calls Forever vanilla --
-- invisibly, since Forever runs vanilla content. Camelot is tried first, and
-- every band states both ends rather than a prefix.
--
-- "family" is what the rest of the addon branches on: "classic" means the
-- combat log exists, "modern" means it is gone and secret values apply.
local BANDS = {
	{ flavour = "camelot", family = "modern", min = 16000, max = 16999 },
	-- Retail went six-digit at 100000 and has stayed there; nothing else is.
	{ flavour = "mainline", family = "modern", min = 100000, max = 999999 },
	{ flavour = "mists", family = "classic", min = 50000, max = 59999 },
	{ flavour = "tbc", family = "classic", min = 20000, max = 29999 },
	{ flavour = "vanilla", family = "classic", min = 11000, max = 11999 },
}

local function BandFor(interface)
	for _, band in ipairs(BANDS) do
		if interface >= band.min and interface <= band.max then return band end
	end
end

---------------------------------------------------------------------------
-- the project id, as a cross-check only
---------------------------------------------------------------------------

-- WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC is true wherever both names
-- are nil, so a client without the constants would pass every such test at
-- once. Both sides must be numbers before the comparison means anything, and
-- the project id is never trusted on its own. The constant is looked up by
-- name so a typo reads as "this client does not have it".
local function ProjectIs(name)
	local id = plain(_G.WOW_PROJECT_ID)
	local want = plain(_G[name])
	if type(id) ~= "number" or type(want) ~= "number" then return false end
	return id == want
end

-- WOW_PROJECT_MAINLINE is 1 on retail, and Forever's early beta builds (a
-- fork of Midnight) answered it too, so it names a family and never a
-- flavour. Forever's own source sets WOW_PROJECT_ID to WOW_PROJECT_CAMELOT
-- (18 in Gethe's forever branch at 1.60.1.70532), which names that one client
-- and no other (`only`): it outranks an interface number outside Forever's
-- band, where a Forever moved to a 2.x number would read as Burning Crusade.
local BY_PROJECT = {
	{ constant = "WOW_PROJECT_CAMELOT", flavour = "camelot", family = "modern", only = true },
	{ constant = "WOW_PROJECT_MISTS_CLASSIC", flavour = "mists", family = "classic" },
	{ constant = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", flavour = "tbc", family = "classic" },
	{ constant = "WOW_PROJECT_CLASSIC", flavour = "vanilla", family = "classic" },
	{ constant = "WOW_PROJECT_MAINLINE", flavour = nil, family = "modern" },
}

local function ByProject()
	for _, entry in ipairs(BY_PROJECT) do
		if ProjectIs(entry.constant) then return entry end
	end
end

---------------------------------------------------------------------------
-- deciding
---------------------------------------------------------------------------

local function Decide()
	local out = {}

	local build, _, _, interface = GetBuildInfo()
	out.build = plain(build)
	out.interface = tonumber(plain(interface))
	out.project = tonumber(plain(_G.WOW_PROJECT_ID))

	local band = out.interface and BandFor(out.interface)
	local project = ByProject()
	-- A project id that names one client (see BY_PROJECT) wins where the
	-- interface number has no band or another client's.
	local overruled = project and project.only and not (band and band.flavour == project.flavour)
	if overruled then band = { flavour = project.flavour, family = project.family } end

	if band then
		out.flavour, out.family = band.flavour, band.family
		out.source = overruled and "project" or "interface"
		out.recognised = true

		-- Recorded, not acted on: the interface number wins, being the only
		-- one that tells Forever from retail, but a bug report is worth more
		-- with the disagreement printed on it.
		if project then
			out.agrees = (project.family == band.family)
				and (project.flavour == nil or project.flavour == band.flavour)
		end
	elseif project then
		-- An interface number nobody here has seen: classified by the
		-- project id's family, never rejected, since refusing to load is the
		-- worse answer.
		out.flavour = project.flavour or "unknown"
		out.family = project.family
		out.source = "project"
		out.recognised = false
	else
		out.flavour = "unknown"
		-- Modern is the safe guess with nothing to go on: assuming a combat
		-- log that is not there registers an event that throws, while
		-- assuming it gone only loses sightings the aura scan also covers.
		out.family = "modern"
		out.source = "nothing to go on"
		out.recognised = false
	end

	return out
end

-- Wrapped so a client without GetBuildInfo does not take the addon down. A
-- bare pcall, because ns.Guard lives in Core.lua, which has not loaded yet.
local ok, decided = pcall(Decide)
if not ok or type(decided) ~= "table" then
	decided = {
		flavour = "unknown",
		family = "modern",
		source = "GetBuildInfo failed",
		recognised = false,
		err = not ok and tostring(decided) or nil,
	}
end

ns.Flavour = decided

-- How each way of deciding reads in the summary below. `source` stays English
-- because it is compared as a value; only what is printed is translated. Each
-- note is one whole key, brackets included, since "by" reads differently
-- before a noun, an idiom and a failure. "(by project)" means by the
-- WOW_PROJECT_ID the summary prints just before it as project=.
local SOURCE_TEXT = {
	project = L["(by project)"],
	["nothing to go on"] = L["(by nothing to go on)"],
	["GetBuildInfo failed"] = L["(by GetBuildInfo failed)"],
}

-- One line, meant to be pasted into a bug report from a client nobody here can
-- test. The key=value part stays in English on purpose: it is field names for
-- whoever reads the report, not sentences.
function ns.FlavourSummary()
	local f = ns.Flavour or {}
	local out = ("%s/%s interface=%s build=%s project=%s"):format(
		tostring(f.flavour), tostring(f.family), tostring(f.interface),
		tostring(f.build), tostring(f.project))
	if f.source and f.source ~= "interface" then
		-- A source this file does not set cannot have a translation, so it is
		-- shown as it is.
		out = out .. " " .. (SOURCE_TEXT[f.source] or ("(by %s)"):format(tostring(f.source)))
	end
	if f.agrees == false then
		out = out .. " |cffff8080" .. L["interface and project id disagree"] .. "|r"
	end
	if f.err then
		out = out .. " |cffff8080" .. L["GetBuildInfo threw: %s"]:format(tostring(f.err)) .. "|r"
	end
	return out
end
