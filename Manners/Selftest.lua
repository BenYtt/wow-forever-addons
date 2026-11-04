-- Manners -- /manners selftest (and /manners check): Manners held up against
-- the game it is running in, in a few seconds, with a report to paste.
--
-- Every bug that reached a player in the 1.6 releases was one the mock client
-- in tests/ could not show: a scroll's imbue that only C_Item reports, a
-- scroll that wants an item target, a window fade whose mouse release went
-- missing, surnames, a range nothing answers without nameplates. This asks the
-- real client the same questions, out of combat, and says what it saw.
--
-- It touches nothing: no cast, no chat, no setting, no protected call, no
-- attribute on the prompt. A reading of your own buffs writes the memory of
-- the one you had up last (Core.lua, ReadOwnFamily), so that memory is put
-- back as it was. Every check runs under its own pcall, since this is a
-- command typed once and not a busy path, and one that throws is a FAIL with
-- the error while the rest run on.
--
-- The report is English, for whoever reads the bug report; the labels go
-- through L. Each line is PASS, WARN or FAIL, the label, and what was seen.
--
-- /manners selftest launch adds the launch checks (SelftestLaunch.lua): the
-- parts of Manners that have only run on the mock, asked of the real client.
-- They are the one place this file's report is joined by a section that does
-- touch things -- briefly, and every one put back.

local _, ns = ...
local L = ns.L
local addon = ns.addon

local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown
local unpack = _G.unpack or table.unpack

local Selftest = {}
ns.Selftest = Selftest

local PASS, WARN, FAIL = "PASS", "WARN", "FAIL"
-- Bindings.xml's command and Clicks.lua's macro.
local COMMAND = "CLICK MannersPrompt:LeftButton"
-- The global cooldown's spell, asked of C_Spell.GetSpellCooldown.
local GCD_SPELL = 61304
-- A Hearthstone: an item every client knows, for the item calls' shape.
local ANY_ITEM = 6948
local MISSING = {}

---------------------------------------------------------------------------
-- reading values without tripping on them
---------------------------------------------------------------------------

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

-- A value as the report shows it: SECRET for one the client withholds,
-- strings quoted and cut short, a table as its first fields.
local function Show(v)
	if Secret(v) then return "SECRET" end
	local kind = type(v)
	if kind == "nil" then return "nil" end
	if kind == "string" then
		v = v:gsub("[\r\n]", " | ")
		if #v > 90 then v = v:sub(1, 87) .. "..." end
		return '"' .. v .. '"'
	end
	if kind ~= "table" then return tostring(v) end
	local keys = {}
	for k in pairs(v) do
		if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for i = 1, math.min(#keys, 8) do
		local x = v[keys[i]]
		local shown
		if Secret(x) then
			shown = "SECRET"
		elseif type(x) == "table" then
			shown = "table"
		else
			shown = tostring(x)
		end
		parts[#parts + 1] = tostring(keys[i]) .. "=" .. shown
	end
	if #keys > 8 then parts[#parts + 1] = "..." end
	return "{" .. table.concat(parts, " ") .. "}"
end

-- nil for a secret, so it can be compared.
local function Plain(v)
	if Secret(v) then return nil end
	return v
end

-- A client call: MISSING when there is no such function, else pcall's answer.
local function Ask(fn, ...)
	if type(fn) ~= "function" then return MISSING end
	return pcall(fn, ...)
end

-- Colour codes off, for a line that came from chat text.
local function Strip(text)
	return (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Field(tbl, key)
	if type(tbl) ~= "table" or Secret(tbl) then return nil end
	return tbl[key]
end

local function Class()
	return ns.caps and ns.caps.class
end

local function OwnFamily(test)
	for _, family in ipairs(ns.GetOwnFamilies(Class()) or {}) do
		if test(family) then return family end
	end
	return nil
end

-- The mage's scrolls, Forever's own: not the weapon enhancements (a poison, a
-- stone, an oil, a lure), which every client has as items of its own and which
-- hold no more of this report's checks than a count of what the bags hold.
local function HasScrolls() return OwnFamily(function(f) return f.scroll and not f.enhance end) ~= nil end
local function ImbueFamily() return OwnFamily(function(f) return f.imbue end) end
local function FamiliarFamily() return OwnFamily(function(f) return f.scroll and not f.imbue and not f.enhance end) end

-- Why a call about the main hand's enchants does not matter to this character,
-- or nil when it does. Only a family with an imbue (Forever's mage scrolls)
-- reads them, and Enum.ItemEnchantType and C_Item.GetWeaponEnchantInfo exist
-- on Forever alone (Ketho's BlizzardInterfaceResources), so on the other four
-- clients their absence is the ordinary state, not a fault.
local function NoImbueWhy()
	if ImbueFamily() then return nil end
	return tostring(Class()) .. " has no weapon imbue on this client"
end

-- A spell id to ask the spell calls about: your best rank of a buff you know,
-- or of any buff of your class, or Arcane Intellect.
local function SomeSpell()
	local buffs = ns.GetClassBuffs(Class()) or {}
	for _, buff in ipairs(buffs) do
		local info = ns.BuffInfo(buff)
		if info and info.known and info.topRank then return info.topRank end
	end
	for _, family in ipairs(ns.GetOwnFamilies(Class()) or {}) do
		for _, spell in ipairs(family.spells) do
			local info = ns.BuffInfo(spell)
			if not spell.item and info and info.known and info.topRank then return info.topRank end
		end
	end
	return buffs[1] and buffs[1].ranks[1] or 1459
end

-- What SelftestLaunch.lua reads and shows values with.
Selftest.tools = { Show = Show, Secret = Secret, Plain = Plain, Ask = Ask, Field = Field, Strip = Strip,
	SomeSpell = SomeSpell, MISSING = MISSING, ANY_ITEM = ANY_ITEM }

-- A reading of your own buffs remembers the one up (Core.lua, Remember):
-- put back as it was, so the test leaves no trace in the saved file.
local function KeepingMemory(fn, ...)
	local char = ns.db and ns.db.char
	local had = type(char) == "table" and char.ownLast or nil
	local before
	if type(had) == "table" then
		before = {}
		for k, v in pairs(had) do before[k] = v end
	end
	local out = { pcall(fn, ...) }
	if type(char) == "table" then
		if before then
			if char.ownLast ~= had then char.ownLast = had end
			for k in pairs(had) do had[k] = nil end
			for k, v in pairs(before) do had[k] = v end
		else
			char.ownLast = had
		end
	end
	if not out[1] then error(out[2], 0) end
	return unpack(out, 2, table.maxn(out))
end

---------------------------------------------------------------------------
-- the checks, in the order the report gives them
--
-- Each is { id, group, label, run }: run(add) reports one line or several
-- with add(status, value[, label]). The ids are for the scenarios.
---------------------------------------------------------------------------

local GROUPS = {
	{ key = "client", label = L["Client"] },
	{ key = "api", label = L["Client API"] },
	{ key = "beliefs", label = L["What Manners believes"] },
	{ key = "button", label = L["Prompt and secure button"] },
	{ key = "range", label = L["Range"] },
	{ key = "speech", label = L["Speech"] },
	{ key = "window", label = L["Options window"] },
	{ key = "errors", label = L["Errors"] },
}
Selftest.GROUPS = GROUPS

local CHECKS = {}
Selftest.CHECKS = CHECKS

local function Check(id, group, label, run)
	CHECKS[#CHECKS + 1] = { id = id, group = group, label = label, run = run }
end

-- One client function's existence and the shape of its answer. `missing` is
-- the status when there is no such function (FAIL or WARN), with why; `judge`
-- turns the answer into a status and a line, or nil for PASS with the values.
-- `unused`, when given, says why the call does not matter to this character
-- (or answers nil when it does): a call that is missing then passes with that.
local function ApiCheck(id, path, find, args, missing, why, judge, unused)
	Check(id, "api", path, function(add)
		local fn = find()
		if type(fn) ~= "function" then
			local idle = unused and unused()
			if idle then
				add(PASS, "missing -- not used: " .. idle)
			else
				add(type(missing) == "function" and missing() or missing, "missing -- " .. why)
			end
			return
		end
		local out = { pcall(fn, unpack(args())) }
		if not out[1] then
			add(FAIL, "threw: " .. tostring(out[2]))
			return
		end
		local status, line
		if judge then status, line = judge(unpack(out, 2, table.maxn(out))) end
		if not line then
			local shown = {}
			for i = 2, math.max(2, table.maxn(out)) do shown[#shown + 1] = Show(out[i]) end
			line = "returned " .. table.concat(shown, ", ")
		end
		add(status or PASS, line)
	end)
end

local function Table(...)
	local t = { ... }
	return function() return t end
end

-- An aura read answers a table, nothing, or a secret; anything else is a shape
-- this addon does not read.
local function AuraShape(aura)
	if aura == nil or Secret(aura) then return PASS end
	if type(aura) ~= "table" then return FAIL, "returned " .. Show(aura) .. ", not an aura table" end
	if not Secret(aura.spellId) and type(aura.spellId) ~= "number" then
		return WARN, "returned " .. Show(aura) .. " with no spellId"
	end
	return PASS
end

---------------------------------------------------------------------------
-- client
---------------------------------------------------------------------------

Check("client.build", "client", L["build"], function(add)
	local ok, version, build, _, toc = Ask(_G.GetBuildInfo)
	if ok == MISSING or not ok then
		add(FAIL, "GetBuildInfo " .. (ok == MISSING and "missing" or "threw: " .. tostring(version)))
		return
	end
	add(type(Plain(toc)) == "number" and PASS or WARN,
		("%s (%s), interface %s, Manners %s"):format(Show(version), Show(build), Show(toc), tostring(ns.BUILD)))
end)

-- The languages Locales/ translates; English needs none.
local TRANSLATED = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true,
	itIT = true, koKR = true, ptBR = true, zhCN = true, zhTW = true }

Check("client.locale", "client", L["locale"], function(add)
	local ok, locale = Ask(_G.GetLocale)
	if ok ~= true then
		add(WARN, "GetLocale " .. (ok == MISSING and "missing" or "threw") .. "; Manners read " .. tostring(ns.LOCALE))
		return
	end
	locale = Plain(locale)
	if locale ~= ns.LOCALE then
		add(WARN, ("the client says %s, Manners loaded %s"):format(Show(locale), tostring(ns.LOCALE)))
	elseif not TRANSLATED[locale] then
		add(WARN, tostring(locale) .. " -- no translation, so Manners speaks English")
	else
		add(PASS, tostring(locale))
	end
end)

Check("client.flavour", "client", L["flavour"], function(add)
	local f = ns.Flavour
	if type(f) ~= "table" then
		add(FAIL, "Flavour.lua did not load")
		return
	end
	local summary = Strip(ns.FlavourSummary and ns.FlavourSummary() or "")
	if f.err then
		add(FAIL, summary)
	elseif not f.recognised or f.agrees == false then
		add(WARN, summary)
	else
		add(PASS, summary)
	end
end)

Check("client.secrets", "client", L["secret values"], function(add)
	local secrets = _G.C_Secrets
	local restrictions = Field(secrets, "HasSecretRestrictions")
	local aurasNow = Field(secrets, "ShouldAurasBeSecret")
	local okR, r = Ask(restrictions)
	local okA, a = Ask(aurasNow)
	local line = ("issecretvalue=%s C_Secrets=%s restrictions=%s aurasSecretNow=%s"):format(
		type(_G.issecretvalue), type(secrets),
		okR == true and Show(r) or "n/a", okA == true and Show(a) or "n/a")
	-- Values that may be secret with nothing to test them by: every compare
	-- could throw.
	if type(secrets) == "table" and type(_G.issecretvalue) ~= "function" then
		add(FAIL, line .. " -- secrets exist and nothing can test for one")
	else
		add(PASS, line)
	end
end)

---------------------------------------------------------------------------
-- the client calls Manners depends on: there, and answering in the shape
-- read, with no side effects
---------------------------------------------------------------------------

local function Auras() return _G.C_UnitAuras end
local function Spells() return _G.C_Spell end
local function Items() return _G.C_Item end

ApiCheck("api.auraByIndex", "C_UnitAuras.GetAuraDataByIndex",
	function() return Field(Auras(), "GetAuraDataByIndex") end,
	Table("player", 1, "HELPFUL"), FAIL, "buffs others put on you cannot be noticed",
	AuraShape)

ApiCheck("api.auraBySpellID", "C_UnitAuras.GetUnitAuraBySpellID",
	function() return Field(Auras(), "GetUnitAuraBySpellID") end,
	function() return { "player", SomeSpell() } end, FAIL,
	"nobody's buffs can be read, so everybody is offered everything",
	AuraShape)

ApiCheck("api.auraBySpellName", "C_UnitAuras.GetAuraDataBySpellName",
	function() return Field(Auras(), "GetAuraDataBySpellName") end,
	function() return { "player", ns.SpellNameFor(SomeSpell()) or "", "HELPFUL" } end, WARN,
	"your own buffs are found by walking your auras instead",
	AuraShape)

ApiCheck("api.spellName", "C_Spell.GetSpellName",
	function() return Field(Spells(), "GetSpellName") end,
	function() return { SomeSpell() } end,
	function() return type(_G.GetSpellInfo) == "function" and WARN or FAIL end,
	"spell names come from GetSpellInfo, if at all",
	function(name)
		if type(Plain(name)) ~= "string" then return FAIL, "returned " .. Show(name) .. " for " .. SomeSpell() end
		return PASS, ("%d is %s"):format(SomeSpell(), Show(name))
	end)

ApiCheck("api.spellTexture", "C_Spell.GetSpellTexture",
	function() return Field(Spells(), "GetSpellTexture") end,
	function() return { SomeSpell() } end, WARN, "the prompt shows no spell icons")

ApiCheck("api.spellRange", "C_Spell.IsSpellInRange",
	function() return Field(Spells(), "IsSpellInRange") end,
	function() return { SomeSpell(), "player" } end,
	function() return type(_G.IsSpellInRange) == "function" and WARN or FAIL end,
	"range is asked of the old IsSpellInRange, if at all",
	function(r)
		r = Plain(r)
		if r ~= nil and type(r) ~= "boolean" and type(r) ~= "number" then return WARN, "returned " .. Show(r) end
		return PASS
	end)

ApiCheck("api.spellUsable", "C_Spell.IsSpellUsable",
	function() return Field(Spells(), "IsSpellUsable") end,
	function() return { SomeSpell() } end, WARN, "usable is asked of the old IsUsableSpell, if at all")

ApiCheck("api.spellCooldown", "C_Spell.GetSpellCooldown",
	function() return Field(Spells(), "GetSpellCooldown") end,
	Table(GCD_SPELL), WARN, "the global cooldown is guessed at a second and a half",
	function(cd)
		if cd ~= nil and not Secret(cd) and type(cd) ~= "table" then return WARN, "returned " .. Show(cd) end
		return PASS
	end)

ApiCheck("api.weaponEnchants", "C_Item.GetWeaponEnchantInfo",
	function() return Field(Items(), "GetWeaponEnchantInfo") end,
	function()
		local slots = _G.Enum and _G.Enum.WeaponSlot
		return { slots and slots.MainHand or 0 }
	end,
	FAIL, "a scroll's imbue on your weapon cannot be seen (the 1.6.3 bug)",
	function(list)
		if Secret(list) then return WARN, "returned SECRET for the main hand" end
		if type(list) ~= "table" then return FAIL, "returned " .. Show(list) .. ", not a list" end
		local shown = {}
		for i, entry in ipairs(list) do shown[i] = Show(entry) end
		return PASS, ("%d on the main hand%s"):format(#list,
			#shown > 0 and (": " .. table.concat(shown, ", ")) or "")
	end, NoImbueWhy)

Check("api.enums", "api", "Enum.WeaponSlot / Enum.ItemEnchantType", function(add)
	local enum = _G.Enum
	local slots = Field(enum, "WeaponSlot")
	local kinds = Field(enum, "ItemEnchantType")
	local line = ("MainHand=%s Permanent=%s Temporary=%s Imbue=%s"):format(
		Show(Field(slots, "MainHand")), Show(Field(kinds, "Permanent")),
		Show(Field(kinds, "Temporary")), Show(Field(kinds, "Imbue")))
	-- Core.lua falls back on 0, 2 and 3.
	if type(Field(slots, "MainHand")) ~= "number" or type(Field(kinds, "Temporary")) ~= "number"
		or type(Field(kinds, "Imbue")) ~= "number" then
		local idle = NoImbueWhy()
		if idle then
			add(PASS, line .. " -- not used: " .. idle)
		else
			add(WARN, line .. " -- Manners assumes MainHand=0 Temporary=2 Imbue=3")
		end
	elseif kinds.Imbue == kinds.Temporary then
		add(FAIL, line .. " -- Imbue and Temporary are the same number")
	else
		add(PASS, line)
	end
end)

ApiCheck("api.tempEnchant", "C_PaperDollInfo.GetTemporaryEnchantmentInfo",
	function() return Field(_G.C_PaperDollInfo, "GetTemporaryEnchantmentInfo") end,
	Table(16), WARN, "only matters where C_Item.GetWeaponEnchantInfo is missing", nil, NoImbueWhy)

local function ScrollItem()
	local family = OwnFamily(function(f) return f.scroll end)
	return family and family.spells[1] and family.spells[1].item or ANY_ITEM
end

ApiCheck("api.itemCount", "C_Item.GetItemCount",
	function() return Field(Items(), "GetItemCount") end,
	function() return { ScrollItem() } end,
	function() return HasScrolls() and FAIL or WARN end,
	"scrolls in your bags cannot be counted",
	function(n)
		if type(Plain(n)) ~= "number" then return FAIL, "returned " .. Show(n) .. " for item " .. ScrollItem() end
		return PASS, ("item %d: %d"):format(ScrollItem(), n)
	end)

local function MainHandItem()
	local ok, id = Ask(_G.GetInventoryItemID, "player", 16)
	if ok == true and type(Plain(id)) == "number" then return id end
	return ANY_ITEM
end

ApiCheck("api.itemInstant", "C_Item.GetItemInfoInstant",
	function() return Field(Items(), "GetItemInfoInstant") end,
	function() return { MainHandItem() } end,
	function() return HasScrolls() and FAIL or WARN end,
	"the weapon in your main hand cannot be told apart",
	function(id, _, _, _, _, class, subclass)
		if type(Plain(class)) ~= "number" then
			return WARN, ("item %d: class %s, subclass %s"):format(MainHandItem(), Show(class), Show(subclass))
		end
		return PASS, ("item %s: class %s, subclass %s"):format(Show(id), Show(class), Show(subclass))
	end)

Check("api.tracking", "api", "C_Minimap tracking", function(add)
	local api = _G.C_Minimap
	if type(Field(api, "GetNumTrackingTypes")) ~= "function" or type(Field(api, "GetTrackingInfo")) ~= "function" then
		add(WARN, "missing -- no tracking reminders")
		return
	end
	local okN, n = Ask(api.GetNumTrackingTypes)
	local okI, info = true, nil
	if okN and type(Plain(n)) == "number" and n > 0 then okI, info = Ask(api.GetTrackingInfo, 1) end
	if not okN or not okI then
		add(FAIL, "threw: " .. tostring(not okN and n or info))
	elseif type(Plain(n)) ~= "number" then
		add(WARN, "GetNumTrackingTypes returned " .. Show(n))
	elseif n > 0 and (type(info) ~= "table" or Field(info, "spellID") == nil) then
		add(WARN, ("%d types; the first is %s, with no spellID"):format(n, Show(info)))
	else
		add(PASS, ("%d types; the first %s"):format(n, Show(info)))
	end
end)

Check("api.menu", "api", "MenuUtil.CreateContextMenu", function(add)
	if type(Field(_G.MenuUtil, "CreateContextMenu")) == "function" then
		add(PASS, "present")
	else
		add(FAIL, "missing -- the options window's dropdowns cannot open")
	end
end)

Check("api.colorPicker", "api", "ColorPickerFrame:SetupColorPickerAndShow", function(add)
	if type(Field(_G.ColorPickerFrame, "SetupColorPickerAndShow")) == "function" then
		add(PASS, "present")
	else
		add(WARN, "missing -- the colour swatches on Look cannot open a picker")
	end
end)

Check("api.settings", "api", "Settings.RegisterCanvasLayoutCategory", function(add)
	local settings = _G.Settings
	if type(Field(settings, "RegisterCanvasLayoutCategory")) == "function"
		and type(Field(settings, "RegisterAddOnCategory")) == "function" then
		add(PASS, "present")
	else
		add(WARN, "missing -- no Manners entry under Options > AddOns")
	end
end)

-- Never called: it would emote.
Check("api.emote", "api", "C_ChatInfo.PerformEmote", function(add)
	if type(Field(_G.C_ChatInfo, "PerformEmote")) == "function" then
		add(PASS, "present (not called)")
	elseif type(_G.DoEmote) == "function" then
		add(WARN, "missing -- /thank goes through the old DoEmote")
	else
		add(FAIL, "missing, and DoEmote too -- /thank cannot go out")
	end
end)

-- Every rank of every buff of your class, asked both ways: C_SpellBook, which
-- the probe asks first, and the shims Forever keeps only while the
-- deprecation fallbacks are on.
Check("api.spellbook", "api", "IsSpellKnown / IsPlayerSpell / C_SpellBook", function(add)
	local book = _G.C_SpellBook
	local inBook, known = Field(book, "IsSpellInSpellBook"), Field(book, "IsSpellKnown")
	local enum = _G.Enum and _G.Enum.SpellBookSpellBank
	local bank = enum and enum.Player or 0
	local hasBook = type(inBook) == "function" or type(known) == "function"
	local hasShim = type(_G.IsSpellKnown) == "function" or type(_G.IsPlayerSpell) == "function"
	if not hasBook and not hasShim then
		add(FAIL, "neither is there -- every spell reads as not learned")
		return
	end
	local ids = {}
	for _, buff in ipairs(ns.GetClassBuffs(Class()) or {}) do
		for _, id in ipairs(buff.ranks) do ids[#ids + 1] = id end
	end
	for _, family in ipairs(ns.GetOwnFamilies(Class()) or {}) do
		for _, spell in ipairs(family.spells) do
			if not spell.item then
				for _, id in ipairs(spell.ranks) do ids[#ids + 1] = id end
			end
		end
	end
	local bookYes, shimYes, differ = 0, 0, {}
	for _, id in ipairs(ids) do
		local b, s
		if hasBook then
			local ok1, a1 = Ask(inBook, id, bank, false)
			local ok2, a2 = Ask(known, id, bank)
			b = (ok1 == true and Plain(a1) == true) or (ok2 == true and Plain(a2) == true)
		end
		if hasShim then
			local ok1, a1 = Ask(_G.IsSpellKnown, id)
			local ok2, a2 = Ask(_G.IsPlayerSpell, id)
			s = (ok1 == true and Plain(a1) == true) or (ok2 == true and Plain(a2) == true)
		end
		if b then bookYes = bookYes + 1 end
		if s then shimYes = shimYes + 1 end
		if hasBook and hasShim and b ~= s and #differ < 6 then differ[#differ + 1] = tostring(id) end
	end
	local line = ("%d ids: C_SpellBook knows %s, IsSpellKnown/IsPlayerSpell %s"):format(#ids,
		hasBook and tostring(bookYes) or "missing", hasShim and tostring(shimYes) or "missing")
	if #differ > 0 then
		add(WARN, line .. " -- they disagree on " .. table.concat(differ, ", "))
	elseif not hasBook then
		add(WARN, line .. " -- only the deprecated shims answer")
	else
		add(PASS, line)
	end
end)

Check("api.unitName", "api", "UnitName (surname)", function(add)
	local ok, first, second = Ask(_G.UnitName, "player")
	if ok ~= true then
		add(FAIL, "UnitName " .. (ok == MISSING and "missing" or "threw"))
		return
	end
	local surname = ns.caps and ns.caps.unitNameIsSurname
	local line = ("%s, second %s, read as %s, full name %s"):format(Show(first), Show(second),
		surname and "a surname" or "a realm", Show(ns.UnitFullName("player")))
	second = Plain(second)
	if surname and (type(second) ~= "string" or second == "") then
		add(WARN, line .. " -- this client's names have surnames and none came back")
	elseif not surname and type(second) == "string" and second ~= "" then
		add(WARN, line .. " -- a second name on your own character, read as a realm")
	else
		add(PASS, line)
	end
end)

-- What tells the options window a slider was let go of when its OnMouseUp
-- went missing (1.6.1: the window stayed faded).
Check("api.mouseButton", "api", "IsMouseButtonDown", function(add)
	local ok, down = Ask(_G.IsMouseButtonDown, "LeftButton")
	if ok == MISSING then
		add(FAIL, "missing -- a fade whose mouse release goes missing never ends")
	elseif not ok then
		add(FAIL, "threw: " .. tostring(down))
	elseif Plain(down) then
		add(WARN, "the left button reads as held -- " .. Show(down))
	else
		add(PASS, "the left button reads as up -- " .. Show(down))
	end
end)

local function CVar(name)
	local get = Field(_G.C_CVar, "GetCVar")
	if type(get) ~= "function" then get = _G.GetCVar end
	local ok, value = Ask(get, name)
	if ok ~= true then return nil, ok == MISSING and "missing" or "threw" end
	return Plain(value)
end

Check("api.nameplateCVar", "api", "friendly nameplates setting", function(add)
	local name, value = ns.FriendlyPlatesCVar()
	if not name then
		add(WARN, "GetCVar answered for none of " .. table.concat(ns.FRIENDLY_PLATES_CVARS, ", "))
	elseif tostring(value) == "1" then
		add(PASS, name .. " = 1 -- friendly nameplates are on")
	else
		add(WARN, name .. " = " .. Show(value) .. " -- friendly nameplates are off, so a passer-by's range is read only"
			.. " while targeted or under the cursor")
	end
end)

---------------------------------------------------------------------------
-- what Manners believes about this character
---------------------------------------------------------------------------

Check("beliefs.buffs", "beliefs", L["known buffs"], function(add)
	local buffs = ns.GetClassBuffs(Class())
	if not buffs then
		add(PASS, tostring(Class()) .. " has no buffs for others")
		return
	end
	local usable = Field(Spells(), "IsSpellUsable")
	if type(usable) ~= "function" then usable = _G.IsUsableSpell end
	for _, buff in ipairs(buffs) do
		local info = ns.BuffInfo(buff)
		local label = L["known buffs"] .. " " .. buff.key
		if not info then
			add(FAIL, "never probed", label)
		elseif info.unresolved and #info.unresolved > 0 then
			add(FAIL, ("the client has never heard of %s"):format(table.concat(info.unresolved, ", ")), label)
		elseif not info.known then
			add(PASS, ("%s: not learned"):format(Show(info.name)), label)
		else
			local ok, can = Ask(usable, info.topRank)
			local castable
			if ok == true then castable = Plain(can) end
			local line = ("%s rank %s, readable=%s, castable=%s%s"):format(Show(info.name),
				tostring(info.topRank), tostring(info.readable), Show(castable),
				info.groupRank and (", group " .. Show(info.groupName)) or "")
			add(castable == false and WARN or PASS, line, label)
		end
	end
end)

Check("beliefs.own", "beliefs", L["own buffs"], function(add)
	local families = ns.KnownOwnFamilies()
	if #families == 0 then
		add(PASS, "none learned")
		return
	end
	for _, family in ipairs(families) do
		local up, spell, left, charges = KeepingMemory(ns.ReadOwnFamily, family)
		local label = L["own buffs"] .. " " .. family.key
		local pick = ns.OwnPick(family)
		local line
		if up == nil then
			line = "the client would not say whether it is up"
		elseif up then
			line = ("up: %s%s%s"):format(spell and spell.key or "an enchant no scroll makes",
				left and (", " .. math.floor(left) .. "s left") or "",
				charges and (", " .. tostring(charges) .. " charges") or "")
		else
			line = "not up"
		end
		add(up == nil and WARN or PASS, ("pick %s, %s"):format(tostring(pick), line), label)
	end
end)

Check("beliefs.scrolls", "beliefs", L["scrolls in bags"], function(add)
	local any, held, unread = false, false, false
	local count = Field(Items(), "GetItemCount")
	for _, family in ipairs(ns.GetOwnFamilies(Class()) or {}) do
		for _, spell in ipairs(family.scroll and family.spells or {}) do
			any = true
			local ok, n = Ask(count, spell.item)
			n = ok == true and Plain(n) or nil
			if type(n) ~= "number" then unread = true end
			if type(n) == "number" and n > 0 then
				held = true
				local ready, why = ns.ScrollReady(spell)
				local label = L["scrolls in bags"] .. " " .. spell.key
				if why == "bags" then
					add(WARN, ("%d in the bags, and Manners counts none yet"):format(n), label)
				else
					add(PASS, ("%d, %s"):format(n, ready and "ready" or ("held: " .. tostring(why))), label)
				end
			end
		end
	end
	if not any then
		add(PASS, tostring(Class()) .. " has no scrolls")
	elseif type(count) ~= "function" then
		add(FAIL, "C_Item.GetItemCount is missing, so none can be counted")
	elseif not held then
		-- Said once, when nothing above was: a mage with no scrolls on them is
		-- the ordinary case, not "said nothing".
		add(unread and WARN or PASS, unread and "the client would not say how many are in the bags"
			or "none in the bags")
	end
end)

-- The main hand's enchants read through every call the client has, and what
-- Manners makes of them. C_Item.GetWeaponEnchantInfo is the only one that
-- lists a scroll's imbue (Enum.ItemEnchantType.Imbue); the other two never
-- do. A Manners reading of "nothing on" over a list with an imbue in it is
-- the 1.6.3 bug.
Check("beliefs.mainHand", "beliefs", L["main hand enchants"], function(add)
	local enum = _G.Enum
	local slots, kinds = Field(enum, "WeaponSlot"), Field(enum, "ItemEnchantType")
	local temporary, imbue = Field(kinds, "Temporary") or 2, Field(kinds, "Imbue") or 3
	local label = L["main hand enchants"]

	local okW, weapon = Ask(_G.GetInventoryItemID, "player", 16)
	add(PASS, "weapon " .. (okW == true and Show(weapon) or "unreadable"), label)

	local listed, listedOn, listedImbue
	local okL, list = Ask(Field(Items(), "GetWeaponEnchantInfo"), Field(slots, "MainHand") or 0)
	if okL == true and type(list) == "table" and not Secret(list) then
		listed, listedOn, listedImbue = {}, false, false
		for _, entry in ipairs(list) do
			local on, kind = Plain(Field(entry, "hasEnchant")), Plain(Field(entry, "enchantType"))
			if on == true and (kind == temporary or kind == imbue) then listedOn = true end
			if on == true and kind == imbue then listedImbue = true end
			listed[#listed + 1] = ("type=%s id=%s left=%s"):format(Show(kind),
				Show(Field(entry, "enchantID")), Show(Field(entry, "timeLeft")))
		end
		add(PASS, "C_Item.GetWeaponEnchantInfo: " .. (#listed > 0 and table.concat(listed, "; ") or "nothing"), label)
	else
		-- Missing is a warning only where the character reads it (Forever's
		-- scrolls); a class or client with no imbue has nothing to see.
		local idle = okL == MISSING and NoImbueWhy()
		add(okL == MISSING and (idle and PASS or WARN) or FAIL, "C_Item.GetWeaponEnchantInfo: "
			.. (okL == MISSING and ("missing" .. (idle and (" -- not used: " .. idle) or ""))
				or okL and ("returned " .. Show(list)) or ("threw: " .. tostring(list))), label)
	end

	local okP, paper = Ask(Field(_G.C_PaperDollInfo, "GetTemporaryEnchantmentInfo"), 16)
	local paperOn = okP == true and paper ~= nil
	add(PASS, "C_PaperDollInfo.GetTemporaryEnchantmentInfo: "
		.. (okP == MISSING and "missing" or okP and Show(paper) or ("threw: " .. tostring(paper))), label)

	local okO, has, expires, charges, id = Ask(_G.GetWeaponEnchantInfo)
	local oldOn = okO == true and Plain(has) and true or false
	add(PASS, "GetWeaponEnchantInfo: " .. (okO == MISSING and "missing"
		or okO and ("%s, %s, %s, %s"):format(Show(has), Show(expires), Show(charges), Show(id))
		or ("threw: " .. tostring(has))), label)

	local family = ImbueFamily()
	if not family then
		if listed and not listedOn and (paperOn or oldOn) then
			add(WARN, "the old calls see an enchant C_Item does not list", label)
		else
			add(PASS, tostring(Class()) .. " has no imbue reminder", label)
		end
		return
	end
	local up, spell = KeepingMemory(ns.ReadOwnFamily, family)
	local reads = ("Manners reads %s%s"):format(up == nil and "cannot tell" or up and "on" or "nothing on",
		spell and (" (" .. spell.key .. ")") or "")
	if not listed then
		add(FAIL, reads .. ", and the one call that lists a scroll's imbue gave nothing to read", label)
	elseif listedImbue and up == false then
		add(FAIL, reads .. ", but C_Item lists an imbue on", label)
	elseif not listedOn and up == true then
		add(FAIL, reads .. ", but C_Item lists nothing on", label)
	elseif up == nil then
		add(WARN, reads, label)
	elseif listedImbue and not paperOn then
		add(PASS, reads .. "; the imbue is seen only by C_Item, as expected", label)
	elseif listedOn and not listedImbue and up == false then
		-- A wizard oil on the staff: a Temporary enchant, which stays beside an
		-- imbue, so the imbue is still to be put on.
		add(PASS, reads .. "; C_Item lists a temporary enchant, which is no imbue", label)
	else
		add(PASS, reads, label)
	end
end)

-- The familiar's aura read directly, beside what Manners reads.
Check("beliefs.familiar", "beliefs", L["familiar"], function(add)
	local family = FamiliarFamily()
	if not family then
		add(PASS, tostring(Class()) .. " has no familiar")
		return
	end
	local byId = Field(Auras(), "GetUnitAuraBySpellID")
	local direct, refused
	for _, spell in ipairs(family.spells) do
		for _, id in ipairs(spell.auraIds or spell.ranks) do
			local ok, aura = Ask(byId, "player", id)
			if ok ~= true or Secret(aura) then
				refused = true
			elseif type(aura) == "table" then
				direct = direct or spell
			end
		end
	end
	local up, spell = KeepingMemory(ns.ReadOwnFamily, family)
	local line = ("the aura read by id: %s; Manners reads %s"):format(
		direct and direct.key or refused and "refused" or "none",
		up == nil and "cannot tell" or up and ("up (" .. (spell and spell.key or "?") .. ")") or "not up")
	if direct and up == false then
		add(FAIL, line, L["familiar"])
	elseif up == true and not direct and not refused then
		add(FAIL, line, L["familiar"])
	elseif up == nil then
		add(WARN, line, L["familiar"])
	else
		add(PASS, line, L["familiar"])
	end
end)

---------------------------------------------------------------------------
-- the prompt and its secure button
---------------------------------------------------------------------------

local function Button()
	local prompt = ns.Prompt
	return prompt and prompt.regions and prompt.regions.button
end

Check("button.exists", "button", L["secure button"], function(add)
	local b = Button()
	if not b then
		add(FAIL, "there is no prompt button")
		return
	end
	local okName, name = Ask(b.GetName, b)
	local okProt, protected = Ask(b.IsProtected, b)
	local line = ("%s, global %s, protected %s"):format(okName == true and Show(name) or "?",
		_G.MannersPrompt == b and "MannersPrompt" or "not MannersPrompt",
		okProt == true and Show(protected) or "n/a")
	if _G.MannersPrompt ~= b then
		add(FAIL, line .. " -- the key binding names MannersPrompt")
	elseif okProt == true and Plain(protected) == false then
		add(FAIL, line .. " -- not a secure button")
	else
		add(PASS, line)
	end
end)

Check("button.clicks", "button", L["clicks"], function(add)
	local b = Button()
	if not b then
		add(FAIL, "there is no prompt button")
		return
	end
	local clicks = ns.Prompt.regions.clicks
	local hold = b:GetAttribute("pressAndHoldAction")
	local keyDown = CVar("ActionButtonUseKeyDown")
	local line = ("registered for %s, pressAndHoldAction=%s, ActionButtonUseKeyDown=%s"):format(
		Show(clicks), Show(hold), Show(keyDown))
	-- Registering down without pressAndHoldAction delivers the click and
	-- casts nothing (Prompt/Panel.lua).
	if clicks ~= "AnyDown" or not hold then
		add(FAIL, line)
	else
		add(PASS, line)
	end
end)

Check("button.macro", "button", L["armed macro"], function(add)
	local b = Button()
	if not b then
		add(FAIL, "there is no prompt button")
		return
	end
	local kind, text = b:GetAttribute("type1"), b:GetAttribute("macrotext1")
	if type(text) ~= "string" or text == "" then
		add(PASS, "nothing armed (type1=" .. Show(kind) .. ")")
		return
	end
	local line = ("%d of %d characters, type1=%s: %s"):format(#text, ns.MACRO_LIMIT or 255, Show(kind),
		(text:gsub("\n", " | ")))
	if #text > (ns.MACRO_LIMIT or 255) then
		add(FAIL, line .. " -- the client cuts it short")
	elseif kind ~= "macro" then
		add(WARN, line .. " -- armed text, but the button is not a macro button")
	else
		add(PASS, line)
	end
end)

Check("button.binding", "button", L["binding"], function(add)
	local asked = { Ask(_G.GetBindingKey, COMMAND) }
	local keys = {}
	if asked[1] == true then
		for i = 2, table.maxn(asked) do
			if type(Plain(asked[i])) == "string" then keys[#keys + 1] = asked[i] end
		end
	end
	local okM, index = Ask(_G.GetMacroIndexByName, ns.CLICK_MACRO_NAME or "Manners")
	local macro = okM == true and type(Plain(index)) == "number" and index > 0
	-- And whose body the macro is (Clicks.lua, click macro): ours, foreign,
	-- none or unlooked.
	local line = ("key %s, /click macro %s (%s)"):format(#keys > 0 and table.concat(keys, ", ") or "none",
		macro and "made" or "none", ns.BarMacroState and ns.BarMacroState() or "?")
	if #keys == 0 and not macro then
		add(WARN, line .. " -- the prompt can only be clicked")
	else
		add(PASS, line)
	end
end)

---------------------------------------------------------------------------
-- range: can it be read here, for whom
---------------------------------------------------------------------------

local function Exists(unit)
	local ok, exists = Ask(_G.UnitExists, unit)
	return ok == true and Plain(exists) and true or false
end

-- One unit measured as the scan measures it, and as raw as the client gives it.
local function Measure(add, unit, label, absent)
	if not Exists(unit) then
		add(WARN, absent, label)
		return
	end
	local buff = ns.ResolveBuff(true)
	if not buff then
		add(WARN, "nothing to measure with: no buff learned or switched on", label)
		return
	end
	local info = ns.BuffInfo(buff)
	local okA, assist = Ask(_G.UnitCanAssist, "player", unit)
	local okR, raw = Ask(Field(Spells(), "IsSpellInRange"), info and info.topRank, unit)
	local reach = ns.ReachNow(unit, buff)
	local near = ns.NearEnough(unit, true)
	local line = ("%s: in reach of %s %s (C_Spell.IsSpellInRange %s), near enough %s, can assist %s"):format(
		Show(ns.UnitFullName(unit)), Show(ns.BuffName(buff)), Show(reach),
		okR == true and Show(raw) or "n/a", Show(near), okA == true and Show(assist) or "n/a")
	add(reach == nil and WARN or PASS, reach == nil and (line .. " -- cannot tell") or line, label)
end

Check("range.target", "range", L["target"], function(add)
	Measure(add, "target", L["target"], "no target -- target somebody friendly and run it again")
end)

Check("range.mouseover", "range", L["mouseover"], function(add)
	Measure(add, "mouseover", L["mouseover"], "nobody under the cursor")
end)

Check("range.nameplates", "range", L["nameplates"], function(add)
	local tracked, first = 0, nil
	local units = {}
	for unit in pairs(ns.nameplateUnits or {}) do units[#units + 1] = unit end
	table.sort(units)
	for _, unit in ipairs(units) do
		tracked = tracked + 1
		local ok, assist = Ask(_G.UnitCanAssist, "player", unit)
		if not first and ok == true and Plain(assist) then first = unit end
	end
	local okP, plates = Ask(Field(_G.C_NamePlate, "GetNamePlates"))
	local cvar, shown = ns.FriendlyPlatesCVar()
	local line = ("%d tracked, C_NamePlate.GetNamePlates %s, %s %s"):format(tracked,
		okP == true and type(plates) == "table" and tostring(#plates) or okP == MISSING and "missing" or "n/a",
		cvar or "friendly nameplates", Show(shown))
	if not first then
		add(WARN, line .. " -- no friendly nameplate to measure", L["nameplates"])
		return
	end
	add(PASS, line, L["nameplates"])
	Measure(add, first, L["nameplates"], "gone")
end)

Check("range.proximity", "range", L["proximity"], function(add)
	-- Graded by what Range.lua says it measures with, not by the words, which
	-- are translated: "keine Messung", "aucun signal".
	local summary, unmeasured = ns.ProximitySummary()
	add(unmeasured == true and WARN or PASS, Strip(summary))
end)

-- What the press would do with the thank-you line (Prompt/Press.lua,
-- HoldLine) if your target were the one on the prompt.
Check("range.lineRule", "range", L["line rule"], function(add)
	if type(ns.HoldLine) ~= "function" then
		add(FAIL, "Prompt/Press.lua did not hand over HoldLine")
		return
	end
	if not Exists("target") then
		add(WARN, "no target -- target somebody friendly and run it again")
		return
	end
	local buff = ns.ResolveBuff(true)
	if not buff then
		add(WARN, "nothing to say it over: no buff learned or switched on")
		return
	end
	local name = ns.UnitFullName("target")
	local okC, _, class = Ask(_G.UnitClass, "target")
	local entry = { name = name, short = name, unit = "target", buff = buff, reason = "nearby",
		class = okC == true and Plain(class) or nil }
	local held = ns.HoldLine(entry)
	add(PASS, ("for %s: %s"):format(Show(name), held and "the line is left out" or "the line is said"))
end)

---------------------------------------------------------------------------
-- speech
---------------------------------------------------------------------------

local function Speech()
	local db = ns.db and ns.db.profile
	return db and db.speech
end

Check("speech.channel", "speech", L["channel"], function(add)
	local speech = Speech()
	if not speech then
		add(FAIL, "no profile")
		return
	end
	if not speech.enabled then
		add(PASS, "speech is off")
		return
	end
	local current = ns.Prompt and ns.Prompt.state and ns.Prompt.state.current
	local open = ns.ChannelOpen(current)
	local line = ("%s, open %s%s"):format(tostring(speech.channel), Show(open),
		current and (" for " .. Show(current.name)) or "")
	add(open and PASS or WARN, open and line or (line .. " -- it reaches nobody right now"))
end)

Check("speech.line", "speech", L["line"], function(add)
	local S = ns.Prompt and ns.Prompt.state or {}
	local armed = ("armed now: %s%s"):format(S.phraseText and Show(S.phraseText) or "none",
		S.current and (" for " .. Show(S.current.name)) or "")
	-- A line rolled for a stand-in, through the same picker and budget the
	-- prompt uses; nothing is said, and nothing is remembered as said.
	local buff = ns.ResolveBuff(true)
	local sample = "nothing to roll: no buff"
	if buff then
		local entry = { name = "Somebody", short = "Somebody", reason = "owed", buff = buff }
		local line = ns.PickPhrase(entry, ns.PhraseBudget(entry))
		sample = "a thank-you rolled now: " .. (line and Show(line) or "none (speech off, or no usable lines)")
	end
	add(PASS, armed .. "; " .. sample)
end)

Check("speech.voice", "speech", L["voice"], function(add)
	local rp = ns.InCharacter
	if type(rp) ~= "table" then
		add(FAIL, "Phrases.lua did not load")
		return
	end
	local active = rp.Active(Speech())
	local family, faction, class = rp.Player()
	local pool = family and rp.RACE and rp.RACE[family]
	local lines = 0
	for _, list in pairs(type(pool) == "table" and pool or {}) do
		if type(list) == "table" then lines = lines + #list end
	end
	local okRace, _, race = Ask(_G.UnitRace, "player")
	local line = ("In character %s; race %s, people %s, %s, %s; %d lines of its own"):format(
		active and "speaks" or "is not the set", okRace == true and Show(race) or "n/a",
		tostring(family), tostring(faction), tostring(class), lines)
	if not family or lines == 0 then
		add(WARN, line .. " -- general and faction lines only")
	else
		add(PASS, line)
	end
end)

---------------------------------------------------------------------------
-- the options window
---------------------------------------------------------------------------

Check("window.build", "window", L["builds"], function(add)
	local UI = ns.WindowUI
	if type(UI) ~= "table" or type(UI.Build) ~= "function" then
		add(FAIL, "Options/Window did not load")
		return
	end
	if UI.built then
		add(PASS, "built earlier this session")
		return
	end
	if type(ns.BuildOptionsWindow) ~= "function" then
		add(FAIL, "Options/Register.lua did not load")
		return
	end
	-- Built hidden, as opening it would build it, and through the same guard
	-- (Options/Register.lua): a build that throws leaves the old dialog in
	-- the window's place, as /manners would, not a half-built frame for the
	-- next opening to show. A window that failed is not built again.
	local failed = ns.OptionsFallback()
	if ns.BuildOptionsWindow() then
		add(PASS, "built now, hidden")
	elseif failed then
		add(FAIL, "it failed earlier this session; the old dialog stands in (see Errors)")
	elseif ns.OptionsFallback() then
		local err = "see Errors"
		for _, e in ipairs(ns.errors or {}) do
			if e.where == "options window" then err = tostring(e.err) end
		end
		add(FAIL, "building it threw: " .. err)
	else
		add(FAIL, "building it left no window")
	end
end)

Check("window.pages", "window", L["pages"], function(add)
	local UI = ns.WindowUI
	local layout = UI and UI.Layout and UI.Layout()
	if type(layout) ~= "table" or type(layout.pages) ~= "table" then
		add(FAIL, "no layout")
		return
	end
	local ids = {}
	for id in pairs(layout.pages) do ids[#ids + 1] = id end
	table.sort(ids)
	local rows, broken = 0, {}
	for _, id in ipairs(ids) do
		local ok, model = pcall(UI.Model, id)
		if not ok then
			broken[#broken + 1] = id .. ": " .. tostring(model)
		else
			for _, sec in ipairs(model.sections or {}) do rows = rows + #(sec.entries or {}) end
		end
	end
	if #broken > 0 then
		add(FAIL, table.concat(broken, "; "))
	else
		add(PASS, ("%d pages, %d rows"):format(#ids, rows))
	end
end)

Check("window.fallback", "window", L["fallback"], function(add)
	if type(ns.OptionsFallback) ~= "function" then
		add(FAIL, "Options/Register.lua did not load")
	elseif ns.OptionsFallback() then
		add(FAIL, "the window failed this session; the old dialog stands in (see Errors)")
	else
		add(PASS, "not active")
	end
end)

Check("window.fade", "window", L["fade"], function(add)
	local UI = ns.WindowUI
	if type(UI) ~= "table" or type(UI.PeekTarget) ~= "function" then
		add(FAIL, "Options/Window did not load")
		return
	end
	local target = UI.PeekTarget()
	local alpha = UI.frame and UI.frame.GetAlpha and UI.frame:GetAlpha()
	local line = ("fades to %s with nothing held%s"):format(tostring(target),
		alpha and (", now " .. tostring(alpha)) or "")
	add(target == 1 and PASS or FAIL, target == 1 and line or (line .. " -- the window would stay see-through"))
end)

---------------------------------------------------------------------------
-- errors
---------------------------------------------------------------------------

Check("errors.session", "errors", L["this session"], function(add)
	local errors = ns.errors or {}
	if #errors == 0 then
		add(PASS, "none")
		return
	end
	add(FAIL, ("%d this session, %d kept"):format(ns.errorCount or #errors, #errors))
	for i = math.max(1, #errors - 4), #errors do
		local e = errors[i]
		add(FAIL, ("%s %s -- %s"):format(tostring(e.at), tostring(e.where), tostring(e.err)))
	end
end)

Check("errors.repairs", "errors", L["repairs"], function(add)
	local log = ns.repairLog
	if type(log) ~= "table" then
		add(WARN, "no repair log in this build")
	elseif #log == 0 then
		add(PASS, "nothing in the saved settings needed repairing")
	else
		add(WARN, ("%d put right: %s"):format(#log, table.concat(log, "; ")))
	end
end)

---------------------------------------------------------------------------
-- running them
---------------------------------------------------------------------------

-- Every check, each under its own pcall: a list of { id, group, status,
-- label, value }. A check that throws is a FAIL with the error, and one that
-- says nothing is a WARN, so every check has a line.
function Selftest.Run()
	local results = {}
	local current
	local function add(status, value, label)
		results[#results + 1] = { id = current.id, group = current.group, status = status,
			label = label or current.label, value = tostring(value) }
	end
	for _, check in ipairs(CHECKS) do
		current = check
		local before = #results
		local ok, err = pcall(check.run, add)
		if not ok then
			add(FAIL, "threw: " .. tostring(err))
		elseif #results == before then
			add(WARN, "said nothing")
		end
	end
	return results
end

-- The report as one block of text, and the counts. A check's status is its
-- worst line's.
function Selftest.Report(results, launch)
	local worst, order = {}, {}
	local rank = { [PASS] = 1, [WARN] = 2, [FAIL] = 3 }
	for _, r in ipairs(results) do
		if not worst[r.id] then order[#order + 1] = r.id end
		if not worst[r.id] or rank[r.status] > rank[worst[r.id]] then worst[r.id] = r.status end
	end
	local counts = { [PASS] = 0, [WARN] = 0, [FAIL] = 0 }
	for _, id in ipairs(order) do counts[worst[id]] = counts[worst[id]] + 1 end

	local okB, version, build, _, toc = pcall(_G.GetBuildInfo)
	local lines = {
		("Manners %s self-test, %s"):format(tostring(ns.BUILD), tostring(date("%Y-%m-%d %H:%M:%S"))),
		("client %s (%s), interface %s, %s, %s"):format(okB and Show(version) or "?", okB and Show(build) or "?",
			okB and Show(toc) or "?", tostring(ns.LOCALE), tostring(Class())),
	}
	-- The launch checks come first when they were asked for: their summary
	-- is the line a report is read for.
	if launch and Selftest.LaunchLines then
		for _, line in ipairs(Selftest.LaunchLines(launch)) do lines[#lines + 1] = line end
	end
	for _, group in ipairs(GROUPS) do
		local header = false
		for _, r in ipairs(results) do
			if r.group == group.key then
				if not header then
					lines[#lines + 1] = ""
					lines[#lines + 1] = "[" .. group.label .. "]"
					header = true
				end
				lines[#lines + 1] = ("%s  %s: %s"):format(r.status, r.label, r.value)
			end
		end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = ("%d checks: %d pass, %d warn, %d fail"):format(#order,
		counts[PASS], counts[WARN], counts[FAIL])
	return table.concat(lines, "\n"), counts[PASS], counts[WARN], counts[FAIL]
end

-- The report in its box with one line in chat, or all of it in chat when the
-- box would not open. `launchCounts` ({ pass, check, fail }) adds the launch
-- checks' own line. The last report is kept on Selftest.last.
function Selftest.Deliver(text, pass, warn, fail, launchCounts)
	Selftest.last = text
	if launchCounts then
		addon:Print(L["launch checks: %d passed, %d to check, %d failed -- the report starts with them."]
			:format(launchCounts[1], launchCounts[2], launchCounts[3]))
	end
	local okBox, shown = pcall(function() return ns.ShowSelftestBox and ns.ShowSelftestBox(text) end)
	if okBox and shown then
		addon:Print(L["self-test: %d passed, %d warnings, %d failed -- the report is in the box under Reporting a bug, ready to copy."]
			:format(pass, warn, fail))
		return
	end
	addon:Print(L["self-test: %d passed, %d warnings, %d failed -- the options window would not open, so the report follows here."]
		:format(pass, warn, fail))
	for line in text:gmatch("[^\n]+") do addon:Print(line) end
end

-- /manners selftest: out of combat, the checks, the report in its box and one
-- line in chat. /manners selftest launch adds the launch checks. The last
-- report is kept on Selftest.last.
function Selftest.Command(arg)
	if InCombatLockdown() then
		addon:Print(L["the self-test runs out of combat -- try it again when this fight ends."])
		return
	end
	if Selftest.StartLaunch and type(arg) == "string" and arg:lower():match("^%s*launch%s*$") then
		return Selftest.StartLaunch()
	end
	local text, pass, warn, fail = Selftest.Report(Selftest.Run())
	Selftest.Deliver(text, pass, warn, fail)
end
