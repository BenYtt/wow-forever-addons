-- Manners -- what each class can put on somebody else.
--
-- The clients do not agree about a single spell, so the tables are per
-- flavour, chosen at the bottom of this file from ns.Flavour (Flavour.lua is
-- named before this file in every toc).
--
-- The fields, which mean the same thing in every set:
--
--   ranks     the castable spells, highest first. The macro casts by name, so
--             the game picks the best rank you know; the list is for aura
--             matching and for "do you know this at all". Only the vanilla
--             and Burning Crusade sets have more than one (ranks were removed
--             game-wide in 4.0.1).
--   group     every other id that counts as this buff already being there:
--             the raid-wide version on vanilla, or the thirteen per-class
--             auras Blessing of the Bronze applies on retail. Matched exactly
--             as the ranks are, through buff.auraIds.
--   alike     another class's buffs that do the same and do not stack with
--             this one (Mists' raid-buff kinds: Kings, Mark of the Wild and
--             Legacy of the Emperor are all 5% stats): somebody wearing one is
--             covered, by somebody else, and a cast of ours would change
--             nothing. Matched through buff.auraIds after the ranks and the
--             group, never filed under this buff (BUFF_BY_ID): a favour of
--             one is still that class's buff.
--   blockers  the auras another source puts on somebody that the game compares
--             with this buff's own: a flat stat. Arcane Intellect, Power Word:
--             Fortitude and Divine Spirit are each a MOD_STAT aura (29) on one
--             stat (Intellect 3, Stamina 2, Spirit 4 in EffectMiscValue), and so
--             are the Scrolls of Intellect, Stamina and Spirit; only the greater
--             of two such auras stays on somebody, and a cast of the lesser is
--             refused ("A more powerful spell is already active"). Listed are
--             the spells the scrolls cast; what they give, and what every rank
--             of the buff gives, is the set's `statValue`. UnitHasBuff
--             (Core.lua) reads them when the buff itself is not worn: one worth
--             at least what the rank your cast would land on them gives covers
--             them, a lesser one is cast over. Only where the buff's ranks are
--             such an aura: the sets whose stat buffs are percentages (Mists,
--             retail) have none, and no table.
--   manaOnly  only worth giving somebody with a mana bar.
--   partyOnly reaches your party and nobody else.
--   groupOnly reaches anybody in your party or raid (a raid member in another
--             subgroup too), and nobody outside it: Blessing of Salvation.
--   selfCast  cast on yourself, not on them, so the macro takes no target.
--   neverAuto offerable, but never what "Automatic" reaches for.
--   strongest the buff of an exclusive class's list (a paladin's Kings) that
--             "Blessing of Kings first" puts at the head of the walk: offered to
--             everybody before the rest, which stay in their order behind it
--             and are what somebody gets who cannot be given it or already
--             wears it from another paladin (Core.lua, CastableBuffs). Set only
--             where the list does not already begin with it: Mists' does.
--   notSelf   the game will not let you cast it on yourself, so "Myself"
--             (Queue.lua) never offers it to you.
--   neverSelf castable on yourself, but never offered to you by "Myself": a
--             buff you want only for a reason the prompt cannot see (Unending
--             Breath, under water), which would come back every time it ran
--             out, all evening. Offers to others are untouched.
--   alone     lands on its target alone, on a set whose casts on somebody in
--             your party or raid land on every one of them (wideCasts).
--   talent    learned from a talent, so not everybody of the class knows it:
--             "Skip my own class" never skips it (Queue.lua, SelfServed).
--             ns.AskedFor still turns away every ask from your own class,
--             talent or not.
--   groupCast the version one cast puts on a whole party (or, for a paladin,
--             on everybody of one class), as { id, reagent } per rank, highest
--             first. Only the rank the player knows best is ever used, because
--             the macro casts by name and the game picks that rank. Offered in
--             place of single casts by GroupBuffs.lua.
--
-- How long each lasts is no field of a buff: it is a table of ids per client, below
-- ("how long each lasts"), which a top-up's lead is worked out from (Core.lua).
--
-- Only buffs worth giving a passer-by are listed: emergency spells (Blessing
-- of Freedom, Protection) and anything that moves somebody (Slow Fall,
-- Levitate, Water Walking) are deliberately absent.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- vanilla content: Classic Era and WoW Forever (Burning Crusade's set, below,
-- builds on it)
---------------------------------------------------------------------------

-- This data must not move: these are the tables confirmed working in game on
-- Forever, the one client anybody here can test.

-- The reagents the group versions eat, one per cast. The item ids and names
-- were checked against QuestieDB_Camelot (the Forever client's own item data:
-- 17020 Arcane Powder, 17021 Wild Berries, 17026 Wild Thornroot, 17029 Sacred
-- Candle, 21177 Symbol of Kings), Forever's ItemSparse (17028 Holy Candle) and
-- Questie's list of what reagent vendors sell to each class. Which rank eats
-- which is Forever's own SpellReagents (build 1.60.1.70532), the same as
-- Classic Era's: two first ranks take the cheaper reagent, Prayer of
-- Fortitude's (learned at 48) a Holy Candle and Gift of the Wild's (50) Wild
-- Berries; every other rank takes the one paired below. GroupBuffs.lua also
-- asks the client whether the spell is usable, which is false without its
-- reagent, so a wrong pairing costs an offer, not a cast. On Forever the
-- account's Legacy perk Reagent Economy (1225503) waives the reagent of every
-- one of these (its class auras 1262636/38/47/50 list them all), and then the
-- client calls the spell usable with none in the bags: GroupBuffs.lua,
-- ReagentWaived.
local ARCANE_POWDER, WILD_BERRIES, WILD_THORNROOT = 17020, 17021, 17026
local SACRED_CANDLE, HOLY_CANDLE, SYMBOL_OF_KINGS = 17029, 17028, 21177

-- A paladin's Greater Blessing, highest rank first: every one of them takes a
-- Symbol of Kings.
local function Greater(...)
	local out = {}
	for i = 1, select("#", ...) do
		out[i] = { id = (select(i, ...)), reagent = SYMBOL_OF_KINGS }
	end
	return out
end

local VANILLA = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 10157, 10156, 1461, 1460, 1459 },
			group = { 23028 },
			manaOnly = true,
			-- Scroll of Intellect I to IV (items 955, 2290, 4419, 10308).
			blockers = { 8096, 8097, 8098, 12176 },
			-- Arcane Brilliance.
			groupCast = { { id = 23028, reagent = ARCANE_POWDER } },
		},
	},

	PRIEST = {
		{
			key = "fortitude",
			ranks = { 10938, 10937, 2791, 1245, 1244, 1243 },
			group = { 21564, 21562 },
			-- Scroll of Stamina I to IV (items 1180, 1711, 4422, 10307).
			blockers = { 8099, 8100, 8101, 12178 },
			-- Prayer of Fortitude: rank 1 a Holy Candle, rank 2 a Sacred one.
			groupCast = { { id = 21564, reagent = SACRED_CANDLE }, { id = 21562, reagent = HOLY_CANDLE } },
		},
		{
			key = "spirit",
			ranks = { 27841, 14819, 14818, 14752 },
			group = { 27681 },
			manaOnly = true,
			talent = true,
			-- Scroll of Spirit I to IV (items 1181, 1712, 4424, 10306).
			blockers = { 8112, 8113, 8114, 12177 },
			-- Prayer of Spirit.
			groupCast = { { id = 27681, reagent = SACRED_CANDLE } },
		},
		{
			key = "shadow",
			ranks = { 10958, 10957, 976 },
			group = { 27683 },
			-- Prayer of Shadow Protection.
			groupCast = { { id = 27683, reagent = SACRED_CANDLE } },
		},
	},

	DRUID = {
		{
			key = "motw",
			ranks = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
			group = { 21850, 21849 },
			-- Gift of the Wild: each rank its own reagent.
			groupCast = { { id = 21850, reagent = WILD_THORNROOT }, { id = 21849, reagent = WILD_BERRIES } },
		},
		{
			key = "thorns",
			ranks = { 9910, 9756, 8914, 1075, 782, 467 },
		},
	},

	PALADIN = {
		{
			key = "wisdom",
			ranks = { 25290, 19854, 19853, 19852, 19850, 19742 },
			group = { 25918, 25894 },
			manaOnly = true,
			groupCast = Greater(25918, 25894),
		},
		{
			key = "might",
			ranks = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
			group = { 25916, 25782 },
			groupCast = Greater(25916, 25782),
		},
		{
			key = "kings",
			ranks = { 20217 },
			group = { 25898 },
			talent = true,
			groupCast = Greater(25898),
			strongest = true,
		},
		{
			key = "salvation",
			ranks = { 1038 },
			group = { 25895 },
			-- "Places a Blessing on the party member": the game refuses it on
			-- anybody outside your party or raid (target 57 in the spell data,
			-- Forever's and Classic Era's alike), where the other blessings
			-- take any friendly target.
			groupOnly = true,
			groupCast = Greater(25895),
		},
		{
			key = "light",
			ranks = { 19979, 19978, 19977 },
			group = { 25890 },
			groupCast = Greater(25890),
		},
		{
			key = "sanctuary",
			ranks = { 20914, 20913, 20912, 20911 },
			group = { 25899 },
			talent = true,
			groupCast = Greater(25899),
		},
	},

	WARLOCK = {
		{
			key = "breath",
			ranks = { 5697 },
			-- A shaman's Water Breathing is the same aura (82, ten minutes):
			-- somebody wearing it needs no Unending Breath, and it on you is
			-- a favour like any other.
			group = { 131 },
			-- Water breathing is nothing to be reminded of on dry land, and a
			-- ten-minute buff on yourself would come back all evening, ahead
			-- of your Demon Skin or Armor.
			neverSelf = true,
		},
	},

	-- Battle Shout is cast on yourself and reaches the party, so it has no
	-- target. Still the courteous thing a warrior can offer back.
	WARRIOR = {
		{
			key = "battleshout",
			ranks = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 },
			selfCast = true,
			partyOnly = true,
		},
	},
}

---------------------------------------------------------------------------
-- weapon enhancements: poisons, stones, oils and lures
---------------------------------------------------------------------------

-- What goes on a weapon from the bags and wears off: a rogue's poisons, a
-- sharpening stone or a weightstone, a wizard or mana oil, a fishing lure on a
-- pole. On the clients that have them as items (Classic Era, Burning Crusade,
-- Mists and Forever) each is one of your own buffs of a kind apart from the
-- spells: an item, as a mage's scroll is, used with /use item:<id> and aimed at
-- the hand with /use 16 or /use 17 in the same press (Prompt/Macro.lua), and
-- "up" when that hand carries an enchant (Core.lua, ReadImbue). Classic Era,
-- Burning Crusade and Mists give one temporary enchant to a hand, whichever
-- made it, so any one counts and no other kind is asked for over it. WoW
-- Forever's client lists every enchant on a hand with its kind
-- (Enum.ItemEnchantType) and keeps one of each kind on a hand at once: a
-- shaman's Rockbiter Weapon is an Imbue and a wizard oil a Temporary
-- enchant, and both stay on. So there a family is up only when its hand
-- carries an enchant of its own kind (`enchantKind`, below). Mists and retail
-- give a rogue's poisons as spells instead (MISTS_OWN and MAINLINE_SET,
-- below).
--
-- A family is one kind of enhancement for one hand: Poison for the main hand
-- and again for the off hand, each with a pick of its own, since a rogue keeps
-- one poison on each. Beside the fields of the scroll families (below), with
-- `scroll` set because its spells are items:
--
--   enhance   a weapon enhancement: read per hand, never from an aura
--   kind      poison, stone, oil or lure
--   slot      the hand it is for, as an inventory slot: 16 main, 17 off
--   only      the one class it is offered to (a rogue's poisons); every
--             class carrying one of its items otherwise
--   enchantKind  what the family's enchants are listed as, where the spells
--             below do not say otherwise (the field of the same name)
--
-- and per spell, one for each item, best first (the order Automatic tries
-- them in before you have used one; a stone made for any weapon first, then
-- by rank):
--
--   item      the item id
--   level     the level it asks to be used at (ItemSparse RequiredLevel)
--   enchant   the enchant it makes (SpellItemEnchantment), which says which
--             of them is on the weapon, and so what a top-up would be
--   ranks     { the spell its use casts }, which settles the press
--   fits      the weapons it fits, as the use spell's SpellEquippedItems
--             subclass mask: one bit per kind of weapon (Core.lua, Fits)
--   since     the first build of the client that has the item, where it is
--             newer than the build the other data was read from
--   enchantKind  Forever only, on the spell where it is not its family's: how
--             that client lists the enchant the item makes, "imbue" or
--             "temporary". It is the use spell's SpellEffect: 360 an imbue,
--             54 a temporary enchant (wago.tools, 1.60.1.70532, where the
--             `since` items exist; tools/audit_ids.py holds every one to it). Poisons are imbues, as are the mage's scrolls
--             and a shaman's Rockbiter, Flametongue, Frostbrand and Windfury
--             Weapon (the same effect, 360); stones, oils and lures are
--             temporary enchants. Season of Discovery's five poisons
--             (Atrophic, Numbing, Sebacious, Occult I and II) are the
--             exception, effect 54. Left out on every other client, which
--             read the one enchant a hand has (Core.lua, ReadImbue)
--
-- A wizard or mana oil's own data names inventory types (weapon, two-hand,
-- main hand, off hand) where the rest name kinds of weapon, which would take
-- a fishing pole as well; a pole has lures of its own, so an oil is held to
-- every melee weapon (MELEE). Left out: a shaman's imbues, a warlock's
-- firestones and spellstones, the items made for one use (Scourgebane,
-- Bloodboil Poison, Season of Discovery's cleaning cloth and repellent), the
-- coatings that go on a shield (Season of Discovery), the fishing hats, items
-- for the ranged slot, and the placeholders and tests the data still carries
-- (tools/audit_ids.py names every one of them with --notes). A wrong id costs
-- the reminder for that item and never a nag, as everywhere in this file: an
-- item is offered only when the bags hold one.
--
-- The ids are each client's own (ItemSparse, ItemEffect, SpellEffect,
-- SpellEquippedItems and SpellItemEnchantment from wago.tools: Classic Era
-- 1.15.9.70003, Burning Crusade 2.5.6.69795, Mists 5.5.4.70032, Forever
-- 1.60.1.70532), and tools/audit_ids.py holds every one to them. Forever
-- 1.60.1.70450 added three (287978-287980, a lower-level Rough Sharpening
-- Stone, Lesser Wizard Oil and Elemental Sharpening Stone that make the
-- enchants the older items do), marked `since`.
local ENHANCEMENTS, AddEnhancements = {}, nil
do
	-- SpellEquippedItems' subclass masks: one bit per weapon subclass (0 axe,
	-- 1 two-hand axe, 4 mace, 5 two-hand mace, 6 polearm, 7 sword, 8 two-hand
	-- sword, 10 staff, 13 fist weapon, 15 dagger, 17 spear, 20 fishing pole).
	local BLADED = 33219  -- axes, polearms, swords, daggers: a sharpening stone's
	local BLUNT = 9264    -- maces, staves, fist weapons: a weightstone's
	local EITHER = 42483  -- both of those: the elemental stone's
	local MELEE = 173555  -- every melee weapon: a poison's, and what an oil is held to
	local POLE = 1048576  -- a fishing pole: a lure's
	-- The kinds Forever lists an enchant as (`enchantKind`).
	local IMBUE, TEMPORARY = "imbue", "temporary"
	-- The Consecrated stone's own: every melee weapon but a spear, the druid's
	-- claws and a fishing pole besides (bits 11, 12 and 20).
	local CONSECRATED = 1097203
	-- Mists' elemental stone, which no mace or staff takes there.
	local ELEMENTAL_MISTS = 41411

	-- The kinds, in the order a class is reminded of them. A lure is for a pole,
	-- which is a main-hand weapon alone.
	local KINDS = {
		{ kind = "poison", label = L["Poison"], only = "ROGUE" },
		{ kind = "stone", label = L["Sharpening stone or weightstone"] },
		{ kind = "oil", label = L["Oil"] },
		{ kind = "lure", label = L["Fishing lure"], mainHand = true },
	}
	local HANDS = { { slot = 16, name = "main", suffix = "m" }, { slot = 17, name = "off", suffix = "o" } }

	-- One client's families from its rows: { kind = { { item, level, enchant,
	-- use spell, fits [, since] [, enchantKind = ...] }, ... } }, best first.
	-- `kinds` is { kind = enchantKind }, for a client that lists the kind of
	-- each enchant (Forever); a row names its own `enchantKind` where its item
	-- is not of its family's.
	local function Families(rows, kinds)
		local out = {}
		for _, kind in ipairs(KINDS) do
			for _, hand in ipairs(HANDS) do
				local list = rows[kind.kind]
				if list and not (kind.mainHand and hand.slot ~= 16) then
					local spells = {}
					for i, row in ipairs(list) do
						-- The key is unique across every client's tables (the pick
						-- and the memory of the one last used are filed by it).
						spells[i] = { key = "w" .. row[1] .. hand.suffix, item = row[1], level = row[2],
							enchant = row[3], ranks = { row[4] }, fits = row[5], since = row[6],
							enchantKind = kinds and (row.enchantKind or kinds[kind.kind]) or nil }
					end
					out[#out + 1] = {
						key = kind.kind .. (kind.mainHand and "" or hand.name),
						label = kind.label, kind = kind.kind, slot = hand.slot, only = kind.only,
						scroll = true, enhance = true, spells = spells,
						enchantKind = kinds and kinds[kind.kind] or nil,
					}
				end
			end
		end
		return out
	end

	-- The families for this class, ahead of tracking, which every list ends on.
	AddEnhancements = function(list, class, families)
		local at = #list + 1
		for i, family in ipairs(list) do
			if family.tracking then at = i break end
		end
		for _, family in ipairs(families) do
			if not family.only or family.only == class then
				table.insert(list, at, family)
				at = at + 1
			end
		end
	end

	-- Classic Era 1.15.9.70003: the vanilla items, and Season of Discovery's
	-- (the Blackfathom stone and mana oil, the poisons at 54 and 60), whose ids
	-- the client carries for every realm. A poison is a rogue's alone.
	local VANILLA_ROWS = {
		poison = {
			{ 8928, 60, 625, 11340, MELEE }, -- Instant Poison VI
			{ 8927, 52, 624, 11339, MELEE }, -- Instant Poison V
			{ 8926, 44, 623, 11338, MELEE }, -- Instant Poison IV
			{ 6950, 36, 325, 8688, MELEE }, -- Instant Poison III
			{ 6949, 28, 324, 8686, MELEE }, -- Instant Poison II
			{ 6947, 20, 323, 8679, MELEE }, -- Instant Poison
			{ 20844, 60, 2630, 25351, MELEE }, -- Deadly Poison V
			{ 8985, 54, 627, 11356, MELEE }, -- Deadly Poison IV
			{ 8984, 46, 626, 11355, MELEE }, -- Deadly Poison III
			{ 2893, 38, 8, 2824, MELEE }, -- Deadly Poison II
			{ 2892, 30, 7, 2823, MELEE }, -- Deadly Poison
			{ 10922, 56, 706, 13227, MELEE }, -- Wound Poison IV
			{ 10921, 48, 705, 13226, MELEE }, -- Wound Poison III
			{ 10920, 40, 704, 13225, MELEE }, -- Wound Poison II
			{ 10918, 32, 703, 13219, MELEE }, -- Wound Poison
			{ 3776, 50, 603, 11202, MELEE }, -- Crippling Poison II
			{ 3775, 20, 22, 3408, MELEE }, -- Crippling Poison
			{ 9186, 52, 643, 11399, MELEE }, -- Mind-numbing Poison III
			{ 6951, 38, 23, 8693, MELEE }, -- Mind-numbing Poison II
			{ 5237, 24, 35, 5761, MELEE }, -- Mind-numbing Poison
			{ 5654, 24, 42, 6650, MELEE }, -- Instant Toxin
			{ 234444, 60, 7651, 1214171, MELEE }, -- Occult Poison II
			{ 226374, 54, 7542, 458821, MELEE }, -- Occult Poison I
			{ 217347, 60, 7256, 439465, MELEE }, -- Atrophic Poison
			{ 217346, 60, 7255, 439464, MELEE }, -- Numbing Poison
			{ 217345, 60, 7254, 439462, MELEE }, -- Sebacious Poison
		},
		stone = {
			{ 18262, 50, 2506, 22756, EITHER }, -- Elemental Sharpening Stone
			{ 12404, 35, 1643, 16138, BLADED }, -- Dense Sharpening Stone
			{ 12643, 35, 1703, 16622, BLUNT }, -- Dense Weightstone
			{ 7964, 25, 483, 9900, BLADED }, -- Solid Sharpening Stone
			{ 7965, 25, 484, 9903, BLUNT }, -- Solid Weightstone
			{ 2871, 15, 14, 2830, BLADED }, -- Heavy Sharpening Stone
			{ 3241, 15, 21, 3114, BLUNT }, -- Heavy Weightstone
			{ 2863, 5, 13, 2829, BLADED }, -- Coarse Sharpening Stone
			{ 3240, 5, 20, 3113, BLUNT }, -- Coarse Weightstone
			{ 2862, 1, 40, 2828, BLADED }, -- Rough Sharpening Stone
			{ 3239, 1, 19, 3112, BLUNT }, -- Rough Weightstone
			{ 23122, 50, 2684, 28891, CONSECRATED }, -- Consecrated Sharpening Stone
			{ 211845, 0, 7098, 430392, EITHER }, -- Blackfathom Sharpening Stone
		},
		oil = {
			{ 20749, 45, 2628, 25122, MELEE }, -- Brilliant Wizard Oil
			{ 20748, 45, 2629, 25123, MELEE }, -- Brilliant Mana Oil
			{ 20750, 40, 2627, 25121, MELEE }, -- Wizard Oil
			{ 20747, 40, 2625, 25120, MELEE }, -- Lesser Mana Oil
			{ 20746, 30, 2626, 25119, MELEE }, -- Lesser Wizard Oil
			{ 20745, 20, 2624, 25118, MELEE }, -- Minor Mana Oil
			{ 211848, 25, 7099, 430585, EITHER }, -- Blackfathom Mana Oil
			{ 20744, 5, 2623, 25117, MELEE }, -- Minor Wizard Oil
			{ 23123, 50, 2685, 28898, MELEE }, -- Blessed Wizard Oil
			{ 3829, 30, 26, 3595, MELEE }, -- Frost Oil
			{ 3824, 24, 25, 3594, MELEE }, -- Shadow Oil
		},
		lure = {
			{ 6532, 0, 265, 8090, POLE }, -- Bright Baubles
			{ 6533, 0, 266, 8089, POLE }, -- Aquadynamic Fish Attractor
			{ 7307, 0, 265, 9092, POLE }, -- Flesh Eating Worm
			{ 6530, 0, 264, 8088, POLE }, -- Nightcrawlers
			{ 6811, 0, 264, 8532, POLE }, -- Aquadynamic Fish Lens
			{ 6529, 0, 263, 8087, POLE }, -- Shiny Bauble
		},
	}

	-- Burning Crusade 2.5.6.69795: the vanilla items with the ranks and the
	-- stones, oils and poisons it added (Adamantite and Fel, Superior, Anesthetic,
	-- the seventh Instant and Deadly Poison, the Blessed and Righteous Weapon
	-- Coatings at 70). No Season of Discovery items.
	local TBC_ROWS = {
		poison = {
			{ 21927, 68, 2641, 26891, MELEE }, -- Instant Poison VII
			{ 8928, 60, 625, 11340, MELEE }, -- Instant Poison VI
			{ 8927, 52, 624, 11339, MELEE }, -- Instant Poison V
			{ 8926, 44, 623, 11338, MELEE }, -- Instant Poison IV
			{ 6950, 36, 325, 8688, MELEE }, -- Instant Poison III
			{ 6949, 28, 324, 8686, MELEE }, -- Instant Poison II
			{ 6947, 20, 323, 8679, MELEE }, -- Instant Poison
			{ 22054, 70, 2643, 27186, MELEE }, -- Deadly Poison VII
			{ 22053, 62, 2642, 26967, MELEE }, -- Deadly Poison VI
			{ 20844, 60, 2630, 25351, MELEE }, -- Deadly Poison V
			{ 8985, 54, 627, 11356, MELEE }, -- Deadly Poison IV
			{ 8984, 46, 626, 11355, MELEE }, -- Deadly Poison III
			{ 2893, 38, 8, 2824, MELEE }, -- Deadly Poison II
			{ 2892, 30, 7, 2823, MELEE }, -- Deadly Poison
			{ 22055, 64, 2644, 27188, MELEE }, -- Wound Poison V
			{ 10922, 56, 706, 13227, MELEE }, -- Wound Poison IV
			{ 10921, 48, 705, 13226, MELEE }, -- Wound Poison III
			{ 10920, 40, 704, 13225, MELEE }, -- Wound Poison II
			{ 10918, 32, 703, 13219, MELEE }, -- Wound Poison
			{ 3776, 50, 603, 11202, MELEE }, -- Crippling Poison II
			{ 3775, 20, 22, 3408, MELEE }, -- Crippling Poison
			{ 9186, 52, 643, 11399, MELEE }, -- Mind-numbing Poison III
			{ 6951, 38, 23, 8693, MELEE }, -- Mind-numbing Poison II
			{ 5237, 24, 35, 5761, MELEE }, -- Mind-numbing Poison
			{ 21835, 68, 2640, 26785, MELEE }, -- Anesthetic Poison
			{ 5654, 24, 42, 6650, MELEE }, -- Instant Toxin
		},
		stone = {
			{ 23529, 60, 2713, 29453, BLADED }, -- Adamantite Sharpening Stone
			{ 28421, 60, 2955, 34340, BLUNT }, -- Adamantite Weightstone
			{ 18262, 50, 2506, 22756, EITHER }, -- Elemental Sharpening Stone
			{ 23528, 50, 2712, 29452, BLADED }, -- Fel Sharpening Stone
			{ 28420, 50, 2954, 34339, BLUNT }, -- Fel Weightstone
			{ 12404, 35, 1643, 16138, BLADED }, -- Dense Sharpening Stone
			{ 12643, 35, 1703, 16622, BLUNT }, -- Dense Weightstone
			{ 7964, 25, 483, 9900, BLADED }, -- Solid Sharpening Stone
			{ 7965, 25, 484, 9903, BLUNT }, -- Solid Weightstone
			{ 2871, 15, 14, 2830, BLADED }, -- Heavy Sharpening Stone
			{ 3241, 15, 21, 3114, BLUNT }, -- Heavy Weightstone
			{ 2863, 5, 13, 2829, BLADED }, -- Coarse Sharpening Stone
			{ 3240, 5, 20, 3113, BLUNT }, -- Coarse Weightstone
			{ 2862, 1, 40, 2828, BLADED }, -- Rough Sharpening Stone
			{ 3239, 1, 19, 3112, BLUNT }, -- Rough Weightstone
			{ 23122, 50, 2684, 28891, CONSECRATED }, -- Consecrated Sharpening Stone
		},
		oil = {
			{ 22522, 58, 2678, 28017, MELEE }, -- Superior Wizard Oil
			{ 22521, 52, 2677, 28013, MELEE }, -- Superior Mana Oil
			{ 20749, 45, 2628, 25122, MELEE }, -- Brilliant Wizard Oil
			{ 20748, 45, 2629, 25123, MELEE }, -- Brilliant Mana Oil
			{ 20750, 40, 2627, 25121, MELEE }, -- Wizard Oil
			{ 20747, 40, 2625, 25120, MELEE }, -- Lesser Mana Oil
			{ 20746, 30, 2626, 25119, MELEE }, -- Lesser Wizard Oil
			{ 20745, 20, 2624, 25118, MELEE }, -- Minor Mana Oil
			{ 20744, 5, 2623, 25117, MELEE }, -- Minor Wizard Oil
			{ 34538, 70, 3265, 45395, MELEE }, -- Blessed Weapon Coating
			{ 34539, 70, 3266, 45397, MELEE }, -- Righteous Weapon Coating
			{ 23123, 50, 2685, 28898, MELEE }, -- Blessed Wizard Oil
			{ 3829, 30, 26, 3595, MELEE }, -- Frost Oil
			{ 3824, 24, 25, 3594, MELEE }, -- Shadow Oil
		},
		lure = {
			{ 6532, 0, 265, 8090, POLE }, -- Bright Baubles
			{ 6533, 0, 266, 8089, POLE }, -- Aquadynamic Fish Attractor
			{ 7307, 0, 265, 9092, POLE }, -- Flesh Eating Worm
			{ 34861, 0, 266, 45731, POLE }, -- Sharpened Fish Hook
			{ 6530, 0, 264, 8088, POLE }, -- Nightcrawlers
			{ 6811, 0, 264, 8532, POLE }, -- Aquadynamic Fish Lens
			{ 6529, 0, 263, 8087, POLE }, -- Shiny Bauble
		},
	}

	-- WoW Forever 1.60.1.70532: Classic Era's items and its own, among them the
	-- three marked `since` that 1.60.1.70450 added. Its classic poisons use the
	-- spell effect the scrolls do (SpellEffect 360) where the rest use 54, so the
	-- client lists them as an Imbue and the rest as a Temporary enchant, and a
	-- hand holds one of each (CAMELOT_KINDS, and the row's own `enchantKind` for
	-- Season of Discovery's five poisons, which are 54 like the stones and oils:
	-- Core.lua, ReadImbue).
	local CAMELOT_KINDS = { poison = IMBUE, stone = TEMPORARY, oil = TEMPORARY, lure = TEMPORARY }
	local CAMELOT_ROWS = {
		poison = {
			{ 8928, 60, 625, 11340, MELEE }, -- Instant Poison VI
			{ 8927, 52, 624, 11339, MELEE }, -- Instant Poison V
			{ 8926, 44, 623, 11338, MELEE }, -- Instant Poison IV
			{ 6950, 36, 325, 8688, MELEE }, -- Instant Poison III
			{ 6949, 28, 324, 8686, MELEE }, -- Instant Poison II
			{ 6947, 20, 323, 8679, MELEE }, -- Instant Poison
			{ 20844, 60, 2630, 25351, MELEE }, -- Deadly Poison V
			{ 8985, 54, 627, 11356, MELEE }, -- Deadly Poison IV
			{ 8984, 46, 626, 11355, MELEE }, -- Deadly Poison III
			{ 2893, 38, 8, 2824, MELEE }, -- Deadly Poison II
			{ 2892, 30, 7, 2823, MELEE }, -- Deadly Poison
			{ 10922, 56, 706, 13227, MELEE }, -- Wound Poison IV
			{ 10921, 48, 705, 13226, MELEE }, -- Wound Poison III
			{ 10920, 40, 704, 13225, MELEE }, -- Wound Poison II
			{ 10918, 32, 703, 13219, MELEE }, -- Wound Poison
			{ 3776, 50, 603, 11202, MELEE }, -- Crippling Poison II
			{ 3775, 20, 22, 3408, MELEE }, -- Crippling Poison
			{ 9186, 52, 643, 11399, MELEE }, -- Mind-numbing Poison III
			{ 6951, 38, 23, 8693, MELEE }, -- Mind-numbing Poison II
			{ 5237, 24, 35, 5761, MELEE }, -- Mind-numbing Poison
			{ 5654, 24, 42, 6650, MELEE }, -- Instant Toxin
			{ 234444, 60, 7651, 1214171, MELEE, enchantKind = TEMPORARY }, -- Occult Poison II
			{ 226374, 54, 7542, 458821, MELEE, enchantKind = TEMPORARY }, -- Occult Poison I
			{ 217347, 60, 7256, 439465, MELEE, enchantKind = TEMPORARY }, -- Atrophic Poison
			{ 217346, 60, 7255, 439464, MELEE, enchantKind = TEMPORARY }, -- Numbing Poison
			{ 217345, 60, 7254, 439462, MELEE, enchantKind = TEMPORARY }, -- Sebacious Poison
		},
		stone = {
			{ 18262, 50, 2506, 22756, EITHER }, -- Elemental Sharpening Stone
			{ 287980, 1, 2506, 22756, EITHER, 70450 }, -- Elemental Sharpening Stone
			{ 12404, 35, 1643, 16138, BLADED }, -- Dense Sharpening Stone
			{ 12643, 35, 1703, 16622, BLUNT }, -- Dense Weightstone
			{ 7964, 25, 483, 9900, BLADED }, -- Solid Sharpening Stone
			{ 7965, 25, 484, 9903, BLUNT }, -- Solid Weightstone
			{ 2871, 15, 14, 2830, BLADED }, -- Heavy Sharpening Stone
			{ 3241, 15, 21, 3114, BLUNT }, -- Heavy Weightstone
			{ 2863, 5, 13, 2829, BLADED }, -- Coarse Sharpening Stone
			{ 3240, 5, 20, 3113, BLUNT }, -- Coarse Weightstone
			{ 2862, 1, 40, 2828, BLADED }, -- Rough Sharpening Stone
			{ 287978, 1, 40, 2828, BLADED, 70450 }, -- Rough Sharpening Stone
			{ 3239, 1, 19, 3112, BLUNT }, -- Rough Weightstone
			{ 23122, 50, 2684, 28891, CONSECRATED }, -- Consecrated Sharpening Stone
			{ 211845, 0, 7098, 430392, EITHER }, -- Blackfathom Sharpening Stone
		},
		oil = {
			{ 20749, 45, 2628, 25122, MELEE }, -- Brilliant Wizard Oil
			{ 20748, 45, 2629, 25123, MELEE }, -- Brilliant Mana Oil
			{ 20750, 40, 2627, 25121, MELEE }, -- Wizard Oil
			{ 20747, 40, 2625, 25120, MELEE }, -- Lesser Mana Oil
			{ 20746, 30, 2626, 25119, MELEE }, -- Lesser Wizard Oil
			{ 287979, 1, 2626, 25119, MELEE, 70450 }, -- Lesser Wizard Oil
			{ 20745, 20, 2624, 25118, MELEE }, -- Minor Mana Oil
			{ 20744, 5, 2623, 25117, MELEE }, -- Minor Wizard Oil
			{ 23123, 50, 2685, 28898, MELEE }, -- Blessed Wizard Oil
			{ 3829, 30, 26, 3595, MELEE }, -- Frost Oil
			{ 3824, 24, 25, 3594, MELEE }, -- Shadow Oil
		},
		lure = {
			{ 6532, 0, 265, 8090, POLE }, -- Bright Baubles
			{ 6533, 0, 266, 8089, POLE }, -- Aquadynamic Fish Attractor
			{ 7307, 0, 265, 9092, POLE }, -- Flesh Eating Worm
			{ 6530, 0, 264, 8088, POLE }, -- Nightcrawlers
			{ 6811, 0, 264, 8532, POLE }, -- Aquadynamic Fish Lens
			{ 6529, 0, 263, 8087, POLE }, -- Shiny Bauble
			{ 268880, 0, 263, 8087, POLE }, -- "Secret" Bait
		},
	}

	-- Mists of Pandaria Classic 5.5.4.70032: the stones, weightstones and oils
	-- the client still has as items (their data is each of the earlier clients',
	-- with Mists' own subclass and inventory masks), and the lures, of which
	-- there are more than before. Its poisons are spells (MISTS_OWN, below).
	local MISTS_ROWS = {
		stone = {
			{ 23529, 60, 2713, 29453, BLADED }, -- Adamantite Sharpening Stone
			{ 28421, 60, 2955, 34340, BLUNT }, -- Adamantite Weightstone
			{ 18262, 50, 2506, 22756, ELEMENTAL_MISTS }, -- Elemental Sharpening Stone
			{ 23528, 50, 2712, 29452, BLADED }, -- Fel Sharpening Stone
			{ 28420, 50, 2954, 34339, BLUNT }, -- Fel Weightstone
			{ 12404, 35, 1643, 16138, BLADED }, -- Dense Sharpening Stone
			{ 12643, 35, 1703, 16622, BLUNT }, -- Dense Weightstone
			{ 7964, 25, 483, 9900, BLADED }, -- Solid Sharpening Stone
			{ 7965, 25, 484, 9903, BLUNT }, -- Solid Weightstone
			{ 2871, 15, 14, 2830, BLADED }, -- Heavy Sharpening Stone
			{ 3241, 15, 21, 3114, BLUNT }, -- Heavy Weightstone
			{ 2863, 5, 13, 2829, BLADED }, -- Coarse Sharpening Stone
			{ 3240, 5, 20, 3113, BLUNT }, -- Coarse Weightstone
			{ 2862, 1, 40, 2828, BLADED }, -- Rough Sharpening Stone
			{ 3239, 1, 19, 3112, BLUNT }, -- Rough Weightstone
			{ 23122, 50, 3593, 28891, CONSECRATED }, -- Consecrated Sharpening Stone
		},
		oil = {
			{ 36899, 72, 3298, 47904, MELEE }, -- Exceptional Mana Oil
			{ 22522, 58, 2678, 28017, MELEE }, -- Superior Wizard Oil
			{ 22521, 52, 2677, 28013, MELEE }, -- Superior Mana Oil
			{ 20749, 45, 2628, 25122, MELEE }, -- Brilliant Wizard Oil
			{ 20748, 45, 2629, 25123, MELEE }, -- Brilliant Mana Oil
			{ 20750, 40, 2627, 25121, MELEE }, -- Wizard Oil
			{ 20747, 40, 2625, 25120, MELEE }, -- Lesser Mana Oil
			{ 20746, 30, 2626, 25119, MELEE }, -- Lesser Wizard Oil
			{ 20745, 20, 2624, 25118, MELEE }, -- Minor Mana Oil
			{ 20744, 5, 2623, 25117, MELEE }, -- Minor Wizard Oil
			{ 34538, 70, 3265, 45395, MELEE }, -- Blessed Weapon Coating
			{ 34539, 70, 3266, 45397, MELEE }, -- Righteous Weapon Coating
			{ 23123, 50, 3592, 28898, MELEE }, -- Blessed Wizard Oil
			{ 3829, 30, 26, 3595, MELEE }, -- Frost Oil
			{ 3824, 24, 25, 3594, MELEE }, -- Shadow Oil
		},
		lure = {
			{ 68049, 0, 4225, 95244, POLE }, -- Heat-Treated Spinning Lure
			{ 62673, 0, 266, 87646, POLE }, -- Feathered Lure
			{ 6532, 0, 265, 8090, POLE }, -- Bright Baubles
			{ 6533, 0, 266, 8089, POLE }, -- Aquadynamic Fish Attractor
			{ 7307, 0, 265, 9092, POLE }, -- Flesh Eating Worm
			{ 34861, 0, 266, 45731, POLE }, -- Sharpened Fish Hook
			{ 46006, 0, 3868, 64401, POLE }, -- Glow Worm
			{ 6530, 0, 264, 8088, POLE }, -- Nightcrawlers
			{ 6811, 0, 264, 8532, POLE }, -- Aquadynamic Fish Lens
			{ 6529, 0, 263, 8087, POLE }, -- Shiny Bauble
			{ 69907, 1, 263, 99315, POLE }, -- Corpse Worm
			{ 67404, 0, 4264, 98849, POLE }, -- Glass Fishing Bobber
		},
	}

	ENHANCEMENTS.vanilla = Families(VANILLA_ROWS)
	ENHANCEMENTS.tbc = Families(TBC_ROWS)
	ENHANCEMENTS.camelot = Families(CAMELOT_ROWS, CAMELOT_KINDS)
	ENHANCEMENTS.mists = Families(MISTS_ROWS)
end

---------------------------------------------------------------------------
-- vanilla: what each class puts on itself alone
---------------------------------------------------------------------------

-- The buffs a class can only cast on itself, which "Myself" (Queue.lua,
-- SelfEntry) reminds you of when none of a family is up. Kept apart from the
-- tables above, whose every entry is something to give somebody else: nothing
-- here is offered to anybody but the caster, walked by Automatic, asked for in
-- chat or counted as a favour, and the fields above mean nothing here.
--
-- Per class, a list of families, in the order they are offered (your own
-- group buff, from the tables above, always comes first). A family is the
-- buffs of which only one of yours can be up at once -- a mage's armors, a
-- paladin's auras, a hunter's aspects, a shaman's shields -- and a spell alone
-- is a family of one.
--
--   key       the family's name in the profile (ownBuffs.pick) and in the
--             character's memory of the one last up. Unique across every
--             class, because the profile is shared by every character.
--   label     what a family of several is called on the options page; a
--             family of one goes by its spell's name.
--   spells    each { key, ranks }: ranks highest first, as above, and the key
--             unique across both kinds of table. One spell line may change its
--             name between ranks (Frost Armor becomes Ice Armor at 30, Demon
--             Skin becomes Demon Armor at 20): the macro casts the best rank
--             known by that rank's own name (Core.lua, ProbeBuff).
--             neverAuto on a spell: never what Automatic picks or remembers.
--             talent on a spell: learned from a talent (data only).
--   toggle    stays up until switched off, with no timer (auras, aspects), so
--             never offered as a top-up.
--   dungeon   Automatic's first pick in a dungeon or raid before you have had
--             one up; elsewhere it is the first spell of the family you know.
--   tank      Automatic reminds you only while your group role is tank.
--   shared    a party aura somebody else of your class can put on you too
--             (a paladin's auras, a hunter's aspects and Trueshot), where two
--             of the same do not stack: Automatic passes over one that already
--             reaches you from them for the next you know, and offers nothing
--             when every one does. A pick is offered all the same.
--   charges   on a spell: how many charges a cast gives (a shaman's
--             Lightning Shield, Shadowguard, Inner Fire). With top-ups on,
--             one down to its last few is topped up like one running out.
--   anyCaster on a spell: one of it on you fills the family whoever cast it,
--             since the game allows one of the family on a target (another
--             shaman's Earth Shield, Burning Crusade). Somebody else's reads
--             as the family up, so nothing of yours is offered over it, and
--             is never topped up with yours.
--   castOnOthers on a spell: also cast on somebody else, at a target rather
--             than as an area aura (Earth Shield, on the tank above all). One
--             on you from another player is a favour like any shield, where
--             nothing else here ever is (ns.IsOwnAura).
--
-- Every id below was checked against Forever's own spell data (EnhanceQoL's
-- SpellRankData_Camelot, generated from build 1.60.1.69913) and Wowhead
-- Classic. Forever added ranks of its own to two spells (Aspect of the Beast
-- and Trueshot Aura, the 1299xxx ids), which no other vanilla client has; they
-- only ever fail to be known there. Water Shield, one rank and so not in that
-- data, was checked against Wowhead Classic and the Forever build of
-- EnhanceQoL's buff reminder, which puts it in the shaman's one shield family.
-- A spell is "known" by these ids alone, so a wrong id costs the reminder,
-- never a nag.
--
-- Vanilla content only: Burning Crusade gave most of these families a member
-- this table does not have (Molten and Fel Armor, Earth Shield, Aspect of the
-- Viper, Crusader Aura), so the tbc set below has a table of its own
-- (TBC_OWN).
--
-- The level each rank of the buffs above is learned at (vanilla trainers), for
-- "skip my own class when they can cast it too": somebody of your class at or
-- past the level of your best rank could give themselves the same, and one
-- below it gets yours, which is better. A buff marked `talent` and a shout
-- are never skipped that way, so their levels are never read; a rank missing
-- here counts as learned at level 1.
ns.RANK_LEVEL = {
	-- Arcane Intellect
	[1459] = 1, [1460] = 14, [1461] = 28, [10156] = 42, [10157] = 56,
	-- Power Word: Fortitude
	[1243] = 1, [1244] = 12, [1245] = 24, [2791] = 36, [10937] = 48, [10938] = 60,
	-- Shadow Protection
	[976] = 30, [10957] = 42, [10958] = 56,
	-- Mark of the Wild
	[1126] = 1, [5232] = 10, [6756] = 20, [5234] = 30, [8907] = 40, [9884] = 50, [9885] = 60,
	-- Thorns
	[467] = 6, [782] = 14, [1075] = 24, [8914] = 34, [9756] = 44, [9910] = 54,
	-- Blessing of Wisdom
	[19742] = 14, [19850] = 24, [19852] = 34, [19853] = 44, [19854] = 54, [25290] = 60,
	-- Blessing of Might
	[19740] = 4, [19834] = 12, [19835] = 22, [19836] = 32, [19837] = 42, [19838] = 52, [25291] = 60,
	-- Blessing of Salvation, Blessing of Light, Unending Breath
	[1038] = 26, [19977] = 40, [19978] = 50, [19979] = 60, [5697] = 16,
	-- Blessing of Kings and Divine Spirit: trained on Forever (its SpellLevels),
	-- talents on Classic Era, where `talent` returns before these are read.
	[20217] = 20, [14752] = 30, [14818] = 40, [14819] = 50, [27841] = 60,
	-- Blessing of Sanctuary, a talent whose ranks have levels all the same (its
	-- SpellLevels, Classic Era 1.15.9.70003): another paladin's weak rank worn
	-- by somebody your best rank lands on is read as the weaker it is.
	[20911] = 30, [20912] = 40, [20913] = 50, [20914] = 60,
}
function ns.RankLevel(id)
	return id and ns.RANK_LEVEL[id] or nil
end

local VANILLA_OWN = {
	MAGE = {
		{
			key = "armor",
			label = L["Armor"],
			spells = {
				-- Frost Armor 1-3, then Ice Armor 1-4 from level 30: one line.
				{ key = "frostarmor", ranks = { 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
				{ key = "magearmor", ranks = { 22783, 22782, 6117 } },
			},
			-- The mana back in a long fight; out in the world, and in a
			-- battleground, the armor.
			dungeon = "magearmor",
		},
	},

	PRIEST = {
		-- 20 charges on Forever ("Lasts 10 min or until 20 charges are used").
		{ key = "innerfire", spells = { { key = "innerfire", ranks = { 10952, 10951, 1006, 602, 7128, 588 }, charges = 20 } } },
		-- An undead priest's and a troll priest's racials in 1.12. Whether
		-- Forever keeps them racial, the guides disagree; it does not matter
		-- here, since each is shown and offered only to a priest who has
		-- learned it. On by default like the rest, as the approved design has
		-- it: a priest who trains a charge-spent shield wants it back after a
		-- fight, and one who does not is never asked. Kept apart rather than
		-- as one family: nothing says one replaces the other.
		{ key = "touchofweakness",
			spells = { { key = "touchofweakness", ranks = { 19266, 19265, 19264, 19262, 19261, 2652 } } } },
		{ key = "shadowguard",
			spells = { { key = "shadowguard", ranks = { 19312, 19311, 19310, 19309, 19308, 18137 }, charges = 3 } } },
	},

	WARLOCK = {
		{
			key = "demonarmor",
			spells = {
				-- Season of Discovery's Fel Armor, a rune the rune vendor sells
				-- (30 min, the client's own id for every realm). First, so that
				-- Automatic picks it over Demon Skin once it is known.
				{ key = "felarmor", ranks = { 403619 } },
				-- Demon Skin 1-2, then Demon Armor 1-5 from level 20: one line.
				{ key = "demonarmor", ranks = { 11735, 11734, 11733, 1086, 706, 696, 687 } },
			},
		},
	},

	PALADIN = {
		{
			key = "aura",
			label = L["Aura"],
			spells = {
				{ key = "devotionaura", ranks = { 10293, 10292, 1032, 10291, 643, 10290, 465 } },
				{ key = "retributionaura", ranks = { 10301, 10300, 10299, 10298, 7294 } },
				{ key = "concentrationaura", ranks = { 19746 } },
				{ key = "shadowresaura", ranks = { 19896, 19895, 19876 } },
				{ key = "frostresaura", ranks = { 19898, 19897, 19888 } },
				{ key = "fireresaura", ranks = { 19900, 19899, 19891 } },
				-- Classic Era's talent. Forever took it out of the game, so
				-- there it is never known, never shown and never offered.
				{ key = "sanctityaura", ranks = { 20218 }, talent = true },
			},
			toggle = true,
			-- "Players may only have one Aura on them per Paladin", and two
			-- of the same from two paladins do not stack.
			shared = true,
		},
		{
			key = "righteousfury",
			spells = { { key = "righteousfury", ranks = { 25780 } } },
			tank = true,
		},
	},

	HUNTER = {
		{
			key = "aspect",
			label = L["Aspect"],
			spells = {
				{ key = "aspecthawk", ranks = { 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
				{ key = "aspectmonkey", ranks = { 13163 } },
				{ key = "aspectwild", ranks = { 20190, 20043 } },
				-- The three 1299xxx ranks are Forever's own.
				{ key = "aspectbeast", ranks = { 1299447, 1299446, 1299445, 13161 } },
				-- Up counts as your choice, so neither is ever nagged over; but
				-- nobody wants to be reminded to run everywhere, so Automatic
				-- never picks or remembers them.
				{ key = "aspectcheetah", ranks = { 5118 }, neverAuto = true },
				{ key = "aspectpack", ranks = { 13159 }, neverAuto = true },
			},
			toggle = true,
			-- The Wild and the Pack reach the party.
			shared = true,
		},
		{
			key = "trueshot",
			-- The two 1299xxx ranks are Forever's own, below the talent's three.
			-- Every hunter has it from level 40 on Forever, and it reaches the
			-- party.
			spells = { { key = "trueshot", ranks = { 20906, 20905, 19506, 1299348, 1299346 }, talent = true } },
			shared = true,
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				{ key = "lightningshield", ranks = { 10432, 10431, 8134, 945, 905, 325, 324 }, charges = 3 },
				-- Forever's own: a Restoration talent (the Season of Discovery
				-- rune's id, as Forever's Lava Burst and Riptide are), and "only
				-- one Elemental Shield" may be up, so a healer wearing it has
				-- chosen and is never told to put Lightning Shield over it. Not
				-- in Forever's rank data (one rank); a wrong id only means it is
				-- never known here, and then never read as up either.
				-- Three charges, 10 minutes (SpellAuraOptions ProcCharges 3,
				-- build 1.60.1.70532), as the Burning Crusade ranks.
				{ key = "watershield", ranks = { 408510 }, talent = true, charges = 3 },
			},
		},
	},

	DRUID = {
		{ key = "omen", spells = { { key = "omen", ranks = { 16864 }, talent = true } } },
	},

	-- WARRIOR and ROGUE: no spell of their own that is a buff. What they put on
	-- a weapon (poisons, stones, oils) is an item from the bags, and comes below,
	-- with every class's (weapon enhancements, above). A shaman's weapon imbues
	-- are not offered.
}

-- Tracking, for every class: Find Herbs and Find Minerals come with a
-- profession, not a class, and drop when you die like a buff ("when I die I
-- often forget to put it on", a player on CurseForge). On this client it is
-- not an aura but the minimap's tracking list (Core.lua, TrackingList), as
-- EnhanceQoL's Forever build reads it; a spell missing from that list is never
-- known, so a wrong id here can only cost the reminder. The gathering ids are
-- EnhanceQoL's, each with the second id Forever also uses. One table shared by
-- every class's list, so the memory of the one you had on is one memory.
local TRACKING = {
	key = "tracking",
	label = L["Tracking"],
	tracking = true,
	toggle = true,
	spells = {
		{ key = "findherbs", ranks = { 2383, 8387 } },
		{ key = "findminerals", ranks = { 2580, 8388 } },
		{ key = "findtreasure", ranks = { 2481 } },
		{ key = "trackbeasts", ranks = { 1494 } },
		{ key = "trackhumanoids", ranks = { 19883, 5225 } },
		{ key = "trackundead", ranks = { 19884 } },
		{ key = "trackhidden", ranks = { 19885 } },
		{ key = "trackelementals", ranks = { 19880 } },
		{ key = "trackdemons", ranks = { 19878 } },
		{ key = "trackgiants", ranks = { 19882 } },
		{ key = "trackdragonkin", ranks = { 19879 } },
		{ key = "senseundead", ranks = { 5502 } },
		{ key = "sensedemons", ranks = { 5500 } },
	},
}
for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "WARRIOR", "ROGUE" }) do
	VANILLA_OWN[class] = VANILLA_OWN[class] or {}
	table.insert(VANILLA_OWN[class], TRACKING)
	-- A weapon's poison, stone, oil or lure, ahead of tracking.
	AddEnhancements(VANILLA_OWN[class], class, ENHANCEMENTS.vanilla)
end

-- What each rank of the three buffs with `blockers` gives, and each scroll in
-- them, as a number of the stat they put on (statValue; ns.STAT_VALUE for the
-- chosen set): what UnitHasBuff weighs a blocker against. Every row is the
-- client's own SpellEffect, the MOD_STAT effect (aura 29) of the spell and what
-- it gives: Classic Era's and Burning Crusade's tables hold EffectBasePoints
-- with a die of one side, so the value is that plus one; Forever's hold the
-- value as it is (EffectBasePointsF). tools/audit_ids.py holds every row to its
-- client. Only the single-target ranks, since only they are what a cast lands;
-- the group versions are not read.
--
--   Arcane Intellect    1459 +2, 1460 +7, 1461 +15, 10156 +22, 10157 +31
--   Scroll of Intellect 8096 +4, 8097 +8, 8098 +12, 12176 +16
--   Power Word: Fortitude  1243 1244 1245 2791 10937 10938: +3 +8 +20 +32 +43 +54
--                          here; Forever's are its own, +4 +10 +26 +42 +56 +70
--   Scroll of Stamina   8099 +4, 8100 +8, 8101 +12, 12178 +16
--   Divine Spirit       14752 +17, 14818 +23, 14819 +33, 27841 +40
--   Scroll of Spirit    8112 +3, 8113 +7, 8114 +11, 12177 +15
local VANILLA_STAT = {
	[1459] = 2, [1460] = 7, [1461] = 15, [10156] = 22, [10157] = 31,
	[8096] = 4, [8097] = 8, [8098] = 12, [12176] = 16,
	[1243] = 3, [1244] = 8, [1245] = 20, [2791] = 32, [10937] = 43, [10938] = 54,
	[8099] = 4, [8100] = 8, [8101] = 12, [12178] = 16,
	[14752] = 17, [14818] = 23, [14819] = 33, [27841] = 40,
	[8112] = 3, [8113] = 7, [8114] = 11, [12177] = 15,
}

local VANILLA_SET = {
	name = "vanilla",
	buffs = VANILLA,
	own = VANILLA_OWN,
	statValue = VANILLA_STAT,
	-- Classes whose buffs overwrite one another, so a target carries only one
	-- of yours and walking the list would replace a blessing they have.
	exclusive = { PALADIN = true },
	-- Which buff "auto" reaches for, where it depends on who is standing there.
	auto = { PALADIN = { mana = "wisdom", other = "might" } },
	-- Classes with nothing to give, so the options screen can say so plainly.
	without = {
		HUNTER = true,
		ROGUE = true,
		SHAMAN = true, -- totems are placed, not cast on a person
	},
	-- A partyOnly buff reaches the caster's own subgroup of a raid and nobody
	-- else in it. Classic Era's (and Burning Crusade's) Battle Shout is
	-- party-wide in a raid, not raid-wide; WoW Forever's moved to the whole raid
	-- at build 70450 and the later sets' shouts reach it, and leave this out.
	partyIsSubgroup = true,
	-- Classes whose groupCast reaches everybody of the target's class in the
	-- raid or party rather than the target's party: the Greater Blessings.
	groupByClass = { PALADIN = true },
	-- Class buffs others put on you that Manners never offers (an emergency
	-- spell, or one that moves you), counted as favours only: in ALL_BUFF_IDS,
	-- never in BUFF_BY_ID. Fear Ward; Water Walking; Detect Invisibility;
	-- Soulstone Resurrection, every rank. A shaman's Water Breathing comes in
	-- as Unending Breath's group id instead. Amplify and Dampen Magic are left
	-- out: each also works against its target, a raid tactic rather than a
	-- courtesy.
	favourOnly = { 6346, 546, 11743, 2970, 132, 20765, 20764, 20763, 20762, 20707 },
	-- A druid's party auras, which no family holds (they are a form's, never
	-- cast): Leader of the Pack (24932, a feral's in Cat or Bear Form) and
	-- Moonkin Aura (24907), each an "Apply Area Aura" on the party (Wowhead
	-- Classic). Each lands again every time you walk back into range or the
	-- druid shifts, so neither is anybody's favour, as a hunter's Trueshot Aura
	-- is not (VANILLA_OWN).
	notFavour = { [24932] = true, [24907] = true },
}

---------------------------------------------------------------------------
-- Burning Crusade Classic Anniversary
---------------------------------------------------------------------------

-- 2.5.6: the vanilla buffs with the ranks Burning Crusade added from 61 to
-- 70, and its new spells. Without a new rank in these lists, a level-70
-- wearing it reads as not having the buff at all. Every id, rank, level,
-- reagent and talent below is the client's own (SpellName, Spell,
-- SpellLevels, SpellReagents, SkillLineAbility, SpellEffect and Talent, build
-- 2.5.6.69795, from wago.tools); the vanilla ranks under the new ones are the
-- same ids at the same levels there.
--
-- What else differs from vanilla: Gift of the Wild's third rank eats Wild
-- Quillvine (ItemSparse 22148); Commanding Shout (469, learned at 68) is a
-- second shout, cast on yourself and reaching "all party members within 20
-- yards" like Battle Shout (target 20, radius 20); and Detect Invisibility is
-- one spell (132), the vanilla ranks above it gone. The reach is vanilla's:
-- a group version reaches the target's party (target 37), a Greater Blessing
-- everybody of the target's class (61), Salvation only your party or raid
-- (57). Kings, Sanctuary and Divine Spirit are still talents (Talent).
local WILD_QUILLVINE = 22148

-- One rank of a group version and the reagent it eats, as Greater does for
-- the Greater Blessings.
local function Rank(id, reagent)
	return { id = id, reagent = reagent }
end

local TBC = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 27126, 10157, 10156, 1461, 1460, 1459 },
			group = { 27127, 23028 },
			-- Scroll of Intellect I to V (the fifth is item 27499).
			blockers = { 8096, 8097, 8098, 12176, 33078 },
			manaOnly = true,
			-- Arcane Brilliance, both ranks an Arcane Powder.
			groupCast = { Rank(27127, ARCANE_POWDER), Rank(23028, ARCANE_POWDER) },
		},
	},

	PRIEST = {
		{
			key = "fortitude",
			ranks = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 },
			group = { 25392, 21564, 21562 },
			-- Scroll of Stamina I to V (the fifth is item 27502).
			blockers = { 8099, 8100, 8101, 12178, 33081 },
			-- Prayer of Fortitude: rank 1 a Holy Candle, ranks 2 and 3 a Sacred one.
			groupCast = { Rank(25392, SACRED_CANDLE), Rank(21564, SACRED_CANDLE), Rank(21562, HOLY_CANDLE) },
		},
		{
			key = "spirit",
			ranks = { 25312, 27841, 14819, 14818, 14752 },
			group = { 32999, 27681 },
			-- Scroll of Spirit I to V (the fifth is item 27501).
			blockers = { 8112, 8113, 8114, 12177, 33080 },
			manaOnly = true,
			talent = true,
			-- Prayer of Spirit.
			groupCast = { Rank(32999, SACRED_CANDLE), Rank(27681, SACRED_CANDLE) },
		},
		{
			key = "shadow",
			ranks = { 25433, 10958, 10957, 976 },
			group = { 39374, 27683 },
			-- Prayer of Shadow Protection.
			groupCast = { Rank(39374, SACRED_CANDLE), Rank(27683, SACRED_CANDLE) },
		},
	},

	DRUID = {
		{
			key = "motw",
			ranks = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 },
			group = { 26991, 21850, 21849 },
			-- Gift of the Wild: each rank its own reagent.
			groupCast = { Rank(26991, WILD_QUILLVINE), Rank(21850, WILD_THORNROOT), Rank(21849, WILD_BERRIES) },
		},
		{
			key = "thorns",
			ranks = { 26992, 9910, 9756, 8914, 1075, 782, 467 },
		},
	},

	PALADIN = {
		{
			key = "wisdom",
			ranks = { 27142, 25290, 19854, 19853, 19852, 19850, 19742 },
			group = { 27143, 25918, 25894 },
			manaOnly = true,
			groupCast = Greater(27143, 25918, 25894),
		},
		{
			key = "might",
			ranks = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 },
			group = { 27141, 25916, 25782 },
			groupCast = Greater(27141, 25916, 25782),
		},
		{
			key = "kings",
			ranks = { 20217 },
			talent = true,
			group = { 25898 },
			groupCast = Greater(25898),
			strongest = true,
		},
		{
			key = "salvation",
			ranks = { 1038 },
			group = { 25895 },
			groupCast = Greater(25895),
			-- Your party or raid only (target 57), as on vanilla.
			groupOnly = true,
		},
		{
			key = "light",
			ranks = { 27144, 19979, 19978, 19977 },
			group = { 27145, 25890 },
			groupCast = Greater(27145, 25890),
		},
		{
			key = "sanctuary",
			ranks = { 27168, 20914, 20913, 20912, 20911 },
			group = { 27169, 25899 },
			talent = true,
			groupCast = Greater(27169, 25899),
		},
	},

	WARLOCK = {
		{
			key = "breath",
			ranks = { 5697 },
			group = { 131 }, -- a shaman's Water Breathing, as on vanilla
			neverSelf = true,
		},
	},

	WARRIOR = {
		{
			key = "battleshout",
			ranks = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 },
			selfCast = true,
			partyOnly = true,
		},
		-- After Battle Shout, so Automatic gives that first. Nothing in the
		-- client's data makes the two exclusive: a party can wear both.
		{
			key = "commandingshout",
			ranks = { 469 },
			selfCast = true,
			partyOnly = true,
		},
	},
}

-- The levels of the ranks above that vanilla's RANK_LEVEL does not have
-- (SpellLevels, same build). No other set names these ids, so adding them
-- where every set looks changes nothing anywhere else. The shouts have none,
-- as on vanilla.
for id, level in pairs({
	[27126] = 70, [25389] = 70, [25433] = 68, [26990] = 70, [26992] = 64,
	[27142] = 65, [27140] = 70, [27144] = 69, [25312] = 70,
	[27168] = 70,
}) do
	ns.RANK_LEVEL[id] = level
end

-- What each class puts on itself alone, as VANILLA_OWN, with every family's
-- Burning Crusade ranks and members: Molten Armor, Fel Armor, Crusader Aura,
-- Aspect of the Viper, Water Shield (trained at 62 here, no talent) and Earth
-- Shield. Without them one of those up would read as none of the family up,
-- and "Myself" would offer a spell that replaces it.
local TBC_OWN = {
	MAGE = {
		{
			key = "armor",
			label = L["Armor"],
			spells = {
				-- Frost Armor 1-3, then Ice Armor 1-5 from level 30: one line.
				{ key = "frostarmor", ranks = { 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
				{ key = "magearmor", ranks = { 27125, 22783, 22782, 6117 } },
				{ key = "moltenarmor", ranks = { 30482 } },
			},
			dungeon = "magearmor", -- the mana back in a long fight
		},
	},

	PRIEST = {
		{ key = "innerfire",
			spells = { { key = "innerfire", ranks = { 25431, 10952, 10951, 1006, 602, 7128, 588 }, charges = 20 } } },
		-- Racials, each with a seventh rank: Touch of Weakness the undead's and
		-- now the blood elf's, Shadowguard the troll's (SkillLineAbility's
		-- race masks).
		{ key = "touchofweakness",
			spells = { { key = "touchofweakness", ranks = { 25461, 19266, 19265, 19264, 19262, 19261, 2652 } } } },
		{ key = "shadowguard",
			spells = { { key = "shadowguard", ranks = { 25477, 19312, 19311, 19310, 19309, 19308, 18137 }, charges = 3 } } },
	},

	WARLOCK = {
		{
			-- The family keeps vanilla's key, so a pick made there still reads.
			key = "demonarmor",
			label = L["Armor"],
			spells = {
				-- Demon Skin 1-2, then Demon Armor 1-6 from level 20: one line.
				{ key = "demonarmor", ranks = { 27260, 11735, 11734, 11733, 1086, 706, 696, 687 } },
				{ key = "felarmor", ranks = { 28189, 28176 } },
			},
			-- "Only one type of Armor spell can be active on the Warlock": the
			-- spell power for a dungeon, the armor out in the world.
			dungeon = "felarmor",
		},
	},

	PALADIN = {
		{
			key = "aura",
			label = L["Aura"],
			spells = {
				{ key = "devotionaura", ranks = { 27149, 10293, 10292, 1032, 10291, 643, 10290, 465 } },
				{ key = "retributionaura", ranks = { 27150, 10301, 10300, 10299, 10298, 7294 } },
				{ key = "concentrationaura", ranks = { 19746 } },
				{ key = "shadowresaura", ranks = { 27151, 19896, 19895, 19876 } },
				{ key = "frostresaura", ranks = { 27152, 19898, 19897, 19888 } },
				{ key = "fireresaura", ranks = { 27153, 19900, 19899, 19891 } },
				{ key = "sanctityaura", ranks = { 20218 }, talent = true },
				-- Mounted speed: up counts as your choice, but nobody wants to be
				-- reminded to ride faster, so Automatic never picks it.
				{ key = "crusaderaura", ranks = { 32223 }, neverAuto = true },
			},
			toggle = true,
			shared = true,
		},
		{
			key = "righteousfury",
			spells = { { key = "righteousfury", ranks = { 25780 } } },
			tank = true, -- Automatic reminds you only while you tank
		},
	},

	HUNTER = {
		{
			key = "aspect",
			label = L["Aspect"],
			spells = {
				{ key = "aspecthawk", ranks = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 } },
				{ key = "aspectmonkey", ranks = { 13163 } },
				{ key = "aspectwild", ranks = { 27045, 20190, 20043 } },
				{ key = "aspectbeast", ranks = { 13161 } },
				{ key = "aspectviper", ranks = { 34074 } },
				-- Up counts as your choice; Automatic never runs you everywhere.
				{ key = "aspectcheetah", neverAuto = true, ranks = { 5118 } },
				{ key = "aspectpack", neverAuto = true, ranks = { 13159 } },
			},
			toggle = true,
			shared = true,
		},
		{
			key = "trueshot",
			spells = { { key = "trueshot", ranks = { 27066, 20906, 20905, 19506 }, talent = true } },
			shared = true,
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				{ key = "lightningshield", ranks = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, charges = 3 },
				{ key = "watershield", ranks = { 33736, 24398 }, charges = 3 },
				-- A Restoration talent, and "only one Elemental Shield can be
				-- active on a target" (Spell 974, 32593, 32594): a shaman wearing
				-- his own has chosen it, and one wearing another shaman's has had
				-- it chosen for him, so either way the family is up (anyCaster),
				-- talent or not. Never Automatic's pick, being the one for the tank;
				-- and so, on you from another shaman, a favour (castOnOthers).
				{ key = "earthshield", ranks = { 32594, 32593, 974 }, castOnOthers = true,
					talent = true, neverAuto = true, charges = 6,
					anyCaster = true },
			},
		},
	},

	DRUID = {
		{
			key = "omen",
			spells = { { key = "omen", ranks = { 16864 }, talent = true } },
		},
	},
}

-- Tracking as on vanilla, every id there in this client too, and Find Fish
-- (43308, the Weather-Beaten Journal's): only one tracking is on at a time,
-- so with it missing here, Find Fish on would read as none and have another
-- offered over it.
do
	local spells = {}
	for _, spell in ipairs(TRACKING.spells) do spells[#spells + 1] = { key = spell.key, ranks = spell.ranks } end
	spells[#spells + 1] = { key = "findfish", ranks = { 43308 } }
	local tracking = { key = TRACKING.key, label = TRACKING.label, tracking = true, toggle = true, spells = spells }
	for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "WARRIOR", "ROGUE" }) do
		TBC_OWN[class] = TBC_OWN[class] or {}
		table.insert(TBC_OWN[class], tracking)
		-- This client's stones, oils, poisons and lures (above), ahead of it.
		AddEnhancements(TBC_OWN[class], class, ENHANCEMENTS.tbc)
	end
end

-- Burning Crusade's: Classic Era's, with the sixth Arcane Intellect (27126
-- +40), the seventh Fortitude (25389 +79), the fifth Divine Spirit (25312 +50)
-- and the three fifth scrolls (Intellect 33078 +20, Stamina 33081 +20, Spirit
-- 33080 +30). SpellEffect, build 2.5.6.69795.
local TBC_STAT = {}
for id, value in pairs(VANILLA_STAT) do TBC_STAT[id] = value end
for id, value in pairs({ [27126] = 40, [25389] = 79, [25312] = 50, [33078] = 20, [33081] = 20, [33080] = 30 }) do
	TBC_STAT[id] = value
end

local TBC_SET = setmetatable({
	name = "tbc",
	buffs = TBC,
	own = TBC_OWN,
	statValue = TBC_STAT,
	-- Vanilla's, less the two Detect Invisibility ranks this client deleted,
	-- with the sixth Soulstone (27239).
	favourOnly = { 6346, 546, 132, 27239, 20765, 20764, 20763, 20762, 20707 },
	-- Vanilla's druid auras, and the party auras Burning Crusade added (Wowhead
	-- TBC Classic, "Apply Area Aura" each): Tree of Life's (34123), and a
	-- draenei's Heroic Presence (6562) and Inspiring Presence (28878).
	notFavour = { [24932] = true, [24907] = true, [34123] = true, [6562] = true, [28878] = true },
}, { __index = VANILLA_SET })

---------------------------------------------------------------------------
-- WoW Forever: a mage's scrolls
---------------------------------------------------------------------------

-- Forever's own: scrolls a mage finds -- in a Bundle of Scrolls from Study,
-- or by deciphering an untranslated scroll with Comprehend Scroll (both
-- Comprehension spells) -- and reads from the bags, a familiar and a weapon
-- imbue. "For mages, it would be handy to
-- include the mage-specific scroll buffs as reminders", a player on
-- CurseForge. Items, not spells, so Core.lua reads them apart (the scrolls):
-- offered only with one in the bags, at the level it asks for and, for an
-- imbue, on the weapon it fits, and used with /use item:<id> (Prompt/Macro.lua).
-- Every id is the client's own (ItemSparse, ItemXItemEffect, ItemEffect,
-- SpellEffect, SpellEquippedItems and SpellItemEnchantment, build
-- 1.60.1.70532); Rat Familiar, Chillknife and Lesser Flame were also read off
-- a level-12 mage's bags in game.
--
-- Each family is a family as above, with:
--   scroll    its spells are scrolls: { key, item (the item id), level (the
--             level it asks for), ranks = { the spell its use casts } }, best
--             first, which is the order Automatic tries them in before you
--             have used one. The scroll's name is that spell's, as the client
--             names it; nameFromItem takes the item's instead, and is the
--             name until the client has loaded the item.
--   imbue     up is the main hand carrying an enchant of the Imbue kind, a
--             scroll's or any other (never a wizard oil, which is a Temporary
--             one and stays beside it, nor a permanent enchant), rather than
--             an aura (Core.lua, ReadImbue); each scroll names its `enchant`
--             and the `weapon` it fits (the weapon's item subclass).
--   enchantKind  the kind the family's enchants are listed as, as for the
--             weapon enhancements (above). Every scroll's use is SpellEffect
--             360, an imbue (wago.tools, 1.60.1.70532).
local CAMELOT_OWN = {}
do
	local STAFF, DAGGER, SWORD = 10, 15, 7
	-- The use casts the familiar's own aura (Intellect, an hour).
	local FAMILIAR = {
		key = "familiar",
		label = L["Familiar"],
		scroll = true,
		spells = {
			{ key = "catfamiliar", item = 277493, level = 25, ranks = { 1302303 } },
			{ key = "frogfamiliar", item = 277483, level = 16, ranks = { 1302285 } },
			{ key = "ratfamiliar", item = 275069, level = 5, ranks = { 1296202 } },
		},
	}
	-- The use is aimed at an item (Targets 16), as an oil's is: the macro hands
	-- it the main-hand weapon with /use 16 (Prompt/Macro.lua). It lasts an hour.
	local IMBUE = {
		key = "imbue",
		label = L["Weapon imbue"],
		scroll = true,
		imbue = true,
		enchantKind = "imbue",
		spells = {
			{ key = "imbuegreaterflame", item = 277500, level = 46, ranks = { 1302311 }, enchant = 8716, weapon = STAFF },
			{ key = "imbuegreaterfrost", item = 277501, level = 46, ranks = { 1302312 }, enchant = 8717, weapon = STAFF },
			{ key = "imbueprecision", item = 277502, level = 46, ranks = { 1302310 }, enchant = 8718, weapon = STAFF },
			{ key = "imbueaccuracy", item = 277494, level = 25, ranks = { 1302306 }, enchant = 8711, weapon = STAFF },
			{ key = "imbuequickening", item = 277495, level = 25, ranks = { 1302307 }, enchant = 8712, weapon = STAFF },
			{ key = "imbuebalefrost", item = 277496, level = 25, ranks = { 1302305 }, enchant = 8714, weapon = STAFF },
			{ key = "imbueflame", item = 277497, level = 25, ranks = { 1302304 }, enchant = 8713, weapon = STAFF },
			{ key = "imbuemanablade", item = 277498, level = 25, ranks = { 1302308 }, enchant = 8715, weapon = DAGGER },
			{ key = "imbuefrost", item = 277485, level = 16, ranks = { 1302283 }, enchant = 8709, weapon = STAFF },
			{ key = "imbuestriking", item = 277486, level = 16, ranks = { 1302217 }, enchant = 8708, weapon = STAFF },
			{ key = "imbuebaleflame", item = 277487, level = 16, ranks = { 1302219 }, enchant = 8706, weapon = STAFF },
			{ key = "imbueiceknife", item = 277488, level = 16, ranks = { 1302284 }, enchant = 8710, weapon = DAGGER },
			{ key = "imbuespark", item = 277489, level = 16, ranks = { 1302227 }, enchant = 8707, weapon = SWORD },
			-- The client's data points this one at Lesser Flame's spell and
			-- enchant, so the spell's name would be Lesser Flame's: named by
			-- the item, and by this until the client has loaded the item.
			-- Ranked with the level-5 scrolls, just above Lesser Flame, since
			-- what it puts on is Lesser Flame's +4 Fire (SpellItemEnchantment
			-- 8700; Wowhead Forever's tooltip for 277503 says as much): fourth
			-- in the list, Automatic used it over Flame's +12 at 46. Recheck
			-- when a build gives 277503's ItemEffect a spell of its own. Before
			-- Lesser Flame, the twin order ImbueScroll and the top-up rely on.
			{ key = "imbuespellbreak", item = 277503, level = 46, ranks = { 1295720 }, enchant = 8700, weapon = STAFF,
				nameFromItem = L["Imbue Spellbreak"] },
			{ key = "imbuelesserflame", item = 274947, level = 5, ranks = { 1295720 }, enchant = 8700, weapon = STAFF },
			{ key = "imbuechillknife", item = 275067, level = 5, ranks = { 1296225 }, enchant = 8698, weapon = DAGGER },
		},
	}
	-- Vanilla's lists, with the mage's two after the armor. Forever made Omen
	-- of Clarity a passive every druid has from 20 (16864: Attributes_0 0x40,
	-- no duration): nothing to cast, so a druid there has tracking alone. Not
	-- Classic Era's stones, oils and poisons either: Forever's own (above), from
	-- its own item data, go in their place.
	for class, families in pairs(VANILLA_OWN) do
		local list = {}
		for _, family in ipairs(families) do
			if family.key ~= "omen" and not family.enhance then list[#list + 1] = family end
		end
		AddEnhancements(list, class, ENHANCEMENTS.camelot)
		CAMELOT_OWN[class] = list
	end
	table.insert(CAMELOT_OWN.MAGE, 2, FAMILIAR)
	table.insert(CAMELOT_OWN.MAGE, 3, IMBUE)
end

-- Forever's own: the vanilla tables less what its client deleted or moved,
-- copied entry by entry, since Classic Era still needs them as they are and
-- BuildBuffLookups writes class, order and auraIds onto the chosen set's.
-- Blessing of Sanctuary (20911-20914, Greater 25899) has no SpellName there;
-- Kings and Divine Spirit are trained there (SpellLevels 20, and 30 to 60),
-- in neither talent tree. A real table rather than an __index, because the
-- lookups walk ns.BUFFS with pairs.
local CAMELOT = {}
do
	local GONE = { sanctuary = true }
	local TRAINED = { kings = true, spirit = true }
	for class, list in pairs(VANILLA) do
		local copy = {}
		for _, buff in ipairs(list) do
			if not GONE[buff.key] then
				local entry = {}
				for field, value in pairs(buff) do entry[field] = value end
				if TRAINED[entry.key] then entry.talent = nil end
				copy[#copy + 1] = entry
			end
		end
		CAMELOT[class] = copy
	end
end

-- Forever: those buffs, and its own with the mage's scrolls. The name stays
-- "vanilla", which is the set everything else comes from. Its group versions
-- of a priest's, mage's and druid's buff reach the caster's whole party and
-- raid within 100 yards and need no target (target 56 in Forever's spell
-- data, where Classic Era's reach the target's party): groupIsRaid. The
-- Greater Blessings keep their by-class rule. Battle Shout, in every rank, has
-- the caster's raid for its target too (56) since build 1.60.1.70450, where
-- 1.60.1.70178 still had the caster's party (20), the radius unchanged (20
-- yards): so a raid member in another subgroup is reached, and the vanilla
-- subgroup rule (partyIsSubgroup) is left off here, as for the later clients.
local CAMELOT_STAT = {}
for id, value in pairs(VANILLA_STAT) do CAMELOT_STAT[id] = value end
-- Forever's Power Word: Fortitude is worth more at every rank than Classic
-- Era's (SpellEffect, build 1.60.1.70532: +4 +10 +26 +42 +56 +70); every other
-- row is Classic Era's.
for id, value in pairs({ [1243] = 4, [1244] = 10, [1245] = 26, [2791] = 42, [10937] = 56, [10938] = 70 }) do
	CAMELOT_STAT[id] = value
end

local CAMELOT_SET = setmetatable({ buffs = CAMELOT, own = CAMELOT_OWN, groupIsRaid = true,
	partyIsSubgroup = false }, { __index = VANILLA_SET })
CAMELOT_SET.statValue = CAMELOT_STAT

---------------------------------------------------------------------------
-- Mists of Pandaria Classic
---------------------------------------------------------------------------

-- 5.0.4 folded the raid-wide versions into the single-target spells and
-- deleted the duplicates within a class, so every list here is one id long.
--
-- Every id below is the Mists client's own (wago.tools DB2 for build
-- 5.5.4.70032: SpellName, SkillLineAbility, SpellLevels, SpellEffect,
-- SpecializationSpells) and Wowhead MoP Classic's. Each buff for others is
-- cast at target 118 there, the target alone or, when the target is in your
-- party or raid, the whole party and raid ("If target is in your party or
-- raid, all party and raid members will be affected"): a stranger can be
-- given one, so none is partyOnly. The shouts are target 56, the caster's
-- whole party and raid within 100 yards, so they need no target and reach
-- past your own subgroup (partyIsSubgroup is left off).
--
-- 5.x sorts these buffs into kinds, and two of one kind do not stack, whoever
-- cast them: Legacy of the Emperor "does not stack with similar spells such
-- as ... Blessing of Kings, or Mark of the Wild", White Tiger not with Arcane
-- Brilliance, and "Trueshot Aura does not stack with Horn of Winter or Battle
-- Shout" (warcraft.wiki.gg). So each buff that is one kind and nothing else
-- lists the other classes' of its kind as `alike` (the effects are Wowhead
-- MoP Classic's): somebody wearing one is not offered it. Arcane Brilliance
-- (spell power and crit) and Dark Intent (spell power and, since 5.2,
-- stamina) are covered only by two others together, which a list of ids
-- cannot say, so they have none.
local MISTS = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 }, -- Arcane Brilliance
			-- Dalaran Brilliance is the same buff learned from a different
			-- book; a target carrying it does not want ours on top.
			group = { 61316 },
			-- Not manaOnly here: 10% spell power and 5% critical strike, and
			-- the crit (SpellEffect 1459, effect 1: aura 290, 5) is the same
			-- aura Legacy of the White Tiger gives, worth as much to a warrior,
			-- a rogue, a death knight or a hunter (Focus on this client, so no
			-- mana bar either) as to a caster.
		},
	},

	PRIEST = {
		-- 10% stamina, as Dark Intent gives since 5.2 and Commanding Shout.
		{ key = "fortitude", ranks = { 21562 }, alike = { 109773, 469 } },
	},

	DRUID = {
		-- 5% stats, as Kings and Legacy of the Emperor (the auras it lands as).
		{ key = "motw", ranks = { 1126 }, alike = { 20217, 117666, 117667 } },
	},

	-- The cast id is the aura id for these two: the Greater Blessings that used
	-- to carry their own ids are gone, so there is no group version to match.
	PALADIN = {
		-- 5% stats, as Mark of the Wild and Legacy of the Emperor: somebody
		-- wearing either is walked on to Might. First in the list, so not
		-- `strongest`: the walk already offers it ahead of Might.
		{ key = "kings", ranks = { 20217 }, alike = { 1126, 117666, 117667 } },
		{ key = "might", ranks = { 19740 } },
	},

	-- The two Legacies are different buff categories (5% stats, 5% crit), so
	-- a monk gives both, and MONK is deliberately absent from `exclusive`.
	MONK = {
		{
			key = "emperor",
			ranks = { 115921 }, -- Legacy of the Emperor
			-- The cast is a dummy (SpellEffect: effect 3, no aura) that lands as
			-- one of two auras of its own: 117666 on your party and raid when
			-- the target is in it, 117667 on a target outside it. Without them
			-- somebody wearing a monk's Legacy reads as missing it, and a
			-- stranger's Legacy on you is nobody's favour.
			group = { 117666, 117667 },
			-- 5% stats, as Kings and Mark of the Wild.
			alike = { 20217, 1126 },
		},
		{
			key = "whitetiger",
			ranks = { 116781 }, -- Legacy of the White Tiger
			-- Windwalker's alone (SpecializationSpells, spec 269), so not every
			-- monk knows it.
			talent = true,
			-- 5% crit, as Arcane Brilliance carries (either book) and a feral
			-- druid's Leader of the Pack.
			alike = { 1459, 61316, 24932 },
		},
	},

	WARLOCK = {
		{ key = "darkintent", ranks = { 109773 } },
		-- Kept because somebody might want it, and kept away from Automatic
		-- because nobody standing in a city wants to be handed water breathing.
		-- A shaman's Water Breathing (131), its group id on vanilla, is gone
		-- from this client. Its effects have no radius (Wowhead MoP Classic):
		-- the one buff here that lands on its target alone.
		{ key = "breath", ranks = { 5697 }, neverAuto = true, neverSelf = true, alone = true },
	},

	WARRIOR = {
		-- 10% attack power, as Horn of Winter and a hunter's Trueshot Aura.
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true, alike = { 57330, 19506 } },
		-- The warrior's other shout: 10% stamina for the party and raid within
		-- 100 yards, five minutes (SpellEffect aura 137, target 56, radius 12;
		-- SkillLineAbility class mask 1; SpellLevels 68), as Power Word:
		-- Fortitude and Dark Intent give. After Battle Shout, so Automatic
		-- gives that first.
		{ key = "commandingshout", ranks = { 469 }, selfCast = true, partyOnly = true, alike = { 21562, 109773 } },
	},

	-- Horn of Winter is the death knight's Battle Shout: no target, the party
	-- and raid within 100 yards (Death Knight skill line, level 65).
	DEATHKNIGHT = {
		-- 10% attack power, as Battle Shout and a hunter's Trueshot Aura.
		{ key = "hornofwinter", ranks = { 57330 }, selfCast = true, partyOnly = true, alike = { 6673, 19506 } },
	},
}

-- The level each buff above is learned at on this client (SpellLevels), for
-- "skip my own class when they can cast it too". Vanilla's table has the
-- same ids at a rank's level -- 1459 and 1126 at 1, Blessing of Might at 4 --
-- so read there a level-40 mage was taken for one who could cast Arcane
-- Brilliance (58) and skipped. Legacy of the White Tiger is a talent and the
-- shouts are cast on yourself, so their levels are never read.
local MISTS_RANK_LEVEL = {
	[1459] = 58, [21562] = 22, [1126] = 62, [20217] = 30, [19740] = 81,
	[115921] = 22, [109773] = 82, [5697] = 24,
}

---------------------------------------------------------------------------
-- Mists: what each class puts on itself alone
---------------------------------------------------------------------------

-- As VANILLA_OWN. The armors, Inner Fire and Inner Will, Righteous Fury and
-- the aspects last until they are cancelled or you die (SpellDuration -1),
-- so those families are toggles: none is ever a top-up. A shaman's shields
-- are timed (an hour, Earth Shield ten minutes). Each family's members are the
-- ones its client text says only one of may be up: "A Mage can only have one
-- Armor spell active at a time", "You can only have Inner Will or Inner Fire
-- active at a time", "Only one Aspect can be active at a time", "Only one of
-- your Elemental Shields can be active on you at once" (Lightning, Water and
-- Earth Shield all say it).
--
-- Left out, from the same data: Fel Armor (a passive here), Trueshot Aura
-- and Omen of Clarity (passives), a paladin's seals and auras (Devotion Aura
-- is a cooldown in 5.x; the resistance auras are gone), a death knight's
-- presences and a monk's or warrior's stances (stances), and tracking: the
-- minimap's menu here is checkboxes (Blizzard_Minimap's
-- MinimapTracking_Dropdown, loaded off vanilla), several on at once, so one
-- on says nothing about the rest being wanted.
local MISTS_OWN = {
	MAGE = {
		{
			key = "armor",
			label = L["Armor"],
			spells = {
				-- Learned at 34, 54 and 80, so the first a mage knows is Molten.
				{ key = "moltenarmor", ranks = { 30482 } },
				{ key = "frostarmor", ranks = { 7302 } },
				{ key = "magearmor", ranks = { 6117 } },
			},
			toggle = true,
		},
	},

	PRIEST = {
		{
			-- Vanilla's family key, which the options window already places
			-- (Options/Window/Layout.lua). No word of its own: named by the one
			-- you know first, Inner Fire (9) before Inner Will (80).
			key = "innerfire",
			spells = {
				{ key = "innerfire", ranks = { 588 } },
				{ key = "innerwill", ranks = { 73413 } },
			},
			toggle = true,
		},
	},

	PALADIN = {
		{ key = "righteousfury", tank = true, spells = { { key = "righteousfury", ranks = { 25780 } } } },
	},

	HUNTER = {
		{
			key = "aspect",
			label = L["Aspect"],
			spells = {
				-- The talent that replaces Aspect of the Hawk, first so a hunter
				-- who took it is reminded of it rather than of the Hawk.
				{ key = "aspectironhawk", ranks = { 109260 }, talent = true },
				{ key = "aspecthawk", ranks = { 13165 } },
				-- Up counts as your choice, so none of these is ever nagged over;
				-- but nobody wants to be reminded to run everywhere or to be
				-- untrackable (a glyph's), so Automatic never picks them.
				{ key = "aspectcheetah", neverAuto = true, ranks = { 5118 } },
				{ key = "aspectpack", neverAuto = true, ranks = { 13159 } },
				{ key = "aspectbeast", neverAuto = true, ranks = { 61648 } },
			},
			toggle = true,
		},
	},

	SHAMAN = {
		{
			key = "shield",
			label = L["Shield"],
			spells = {
				-- An hour each, with no charges to spend in 5.x.
				{ key = "lightningshield", ranks = { 324 } },
				{ key = "watershield", ranks = { 52127 } },
				-- Restoration's alone (SpecializationSpells, spec 264), and
				-- mostly the tank's; but it can go on yourself, and then it is
				-- your one Elemental Shield ("only one of your Elemental
				-- Shields can be active on you at once"): up, it is your
				-- choice, and Lightning or Water Shield would replace it.
				-- Never what Automatic picks or remembers, so a healer who put
				-- it on herself once is not told to again in a group. Ten
				-- minutes, nine charges (SpellAuraOptions ProcCharges 9). Cast
				-- on the tank, it is that player's favour (castOnOthers).
				{ key = "earthshield", ranks = { 974 }, neverAuto = true, talent = true, charges = 9,
					castOnOthers = true },
			},
		},
	},

	-- WARLOCK, DRUID, WARRIOR, DEATHKNIGHT and MONK: nothing of their own that is
	-- a buff here, as above. A rogue's poisons are two families, below.
}

-- A rogue's poisons here are spells, not items: each puts an aura of its own id
-- on you for an hour (SpellEffect: an aura on the caster, SpellMisc's
-- 3,600,000 ms), and one lethal and one non-lethal poison may be up at once, so
-- a family is up when any one of it is. Deadly Poison is learned at 10,
-- Crippling at 20, Mind-numbing at 28 and Wound Poison at 30 (SpellLevels);
-- Leeching and Paralytic Poison are talents. The stones, oils and lures the
-- client still has as items go on every class's list, as on the others.
do
	local LETHAL = {
		key = "lethal",
		label = L["Lethal poison"],
		spells = {
			{ key = "deadlypoison", ranks = { 2823 } },
			{ key = "woundpoison", ranks = { 8679 } },
		},
	}
	local NONLETHAL = {
		key = "nonlethal",
		label = L["Non-lethal poison"],
		spells = {
			{ key = "cripplingpoison", ranks = { 3408 } },
			{ key = "mindnumbingpoison", ranks = { 5761 } },
			{ key = "leechingpoison", ranks = { 108211 }, talent = true },
			{ key = "paralyticpoison", ranks = { 108215 }, talent = true },
		},
	}
	MISTS_OWN.ROGUE = { LETHAL, NONLETHAL }
	for _, class in ipairs({ "MAGE", "PRIEST", "WARLOCK", "PALADIN", "HUNTER", "SHAMAN", "DRUID", "ROGUE",
		"WARRIOR", "DEATHKNIGHT", "MONK" }) do
		MISTS_OWN[class] = MISTS_OWN[class] or {}
		AddEnhancements(MISTS_OWN[class], class, ENHANCEMENTS.mists)
	end
end

local MISTS_SET = {
	name = "mists",
	buffs = MISTS,
	own = MISTS_OWN,
	rankLevel = MISTS_RANK_LEVEL,
	-- How far a shout reaches (target 56, radius 100: Battle Shout and Horn of
	-- Winter alike). The older sets leave it out: their 20 yards are what
	-- Core.lua's ShoutReach was written for.
	shoutYards = 100,
	-- A buff cast on somebody in your party or raid lands on every one of
	-- them (target 118, radius 100: Arcane Brilliance, Dark Intent, the
	-- Legacies), so the press on one returns the others' favours too
	-- (Prompt/Press.lua, PostClick). A buff marked `alone` is the exception.
	wideCasts = true,
	-- Still one blessing per paladin in 5.5, so the walk would take away what
	-- the last click gave.
	exclusive = { PALADIN = true },
	-- Nothing depends on who is standing there (Wisdom is gone, Kings suits
	-- everybody). An empty table, so ns.CLASS_AUTO is a table on every client.
	auto = {},
	without = {
		HUNTER = true,
		ROGUE = true,
		SHAMAN = true, -- the 5.x shaman buffs are auras, not casts on a person
	},
	-- As vanilla's: class buffs Manners never offers, counted as favours only.
	-- Fear Ward (Priest, 54), Water Walking (Shaman, 24) and Soulstone
	-- (Warlock, 18), each the client's own id here.
	favourOnly = { 6346, 546, 20707 },
	-- The passives that reach the party and raid within 100 yards as their own
	-- auras (Wowhead MoP Classic: "Apply Area Aura", every one), and land again
	-- each time you walk back into range: nobody's favour, as retail's paladin
	-- auras. No family holds them, the hunter's Trueshot Aura included (left
	-- out of MISTS_OWN as a passive). Trueshot Aura (19506), Leader of the Pack
	-- (24932), Moonkin Aura (24907), Unholy Aura (55610), a shaman's Grace of
	-- Air (116956), Unleashed Rage (30809), Elemental Oath (51470) and Burning
	-- Wrath (77747), and a rogue's Swiftblade's Cunning (113742).
	notFavour = {
		[19506] = true, [24932] = true, [24907] = true, [55610] = true, [116956] = true,
		[30809] = true, [51470] = true, [77747] = true, [113742] = true,
	},
}

---------------------------------------------------------------------------
-- retail: Midnight 12.1
---------------------------------------------------------------------------

-- Five class buffs are left, one per class, each an hour long and castable on
-- somebody outside your group. Paladins and death knights have nothing left,
-- and are named in `without` so the options page can say so.
--
-- Every id below was checked against retail's own spell data, build
-- 12.1.0.69933 (wago.tools: SpellName, Spell, SpellEffect, SpellMisc,
-- SpellLevels, SkillLineAbility, TraitDefinition), and the tooltips on Wowhead.
-- Arcane Intellect, Fortitude, Mark of the Wild and Skyfury apply their own id
-- to the target (aura effect, ImplicitTarget 118: "if the target is in your
-- party or raid, all party and raid members will be affected"), so a stranger
-- takes them and the one id is the aura. Battle Shout's targets are 56, the
-- caster's raid within 100 yards: no target, and the whole raid rather than
-- one subgroup, which is why this set leaves partyIsSubgroup out. Each of the
-- six also triggers an eight-second "Highlight" on its caster (1271904 to
-- 1271912), which is nothing anybody else wears and is left out.
local MAINLINE = {
	MAGE = {
		{
			key = "intellect",
			ranks = { 1459 },
			-- "Increasing their Intellect by 3%": nothing to a warrior, a rogue,
			-- a hunter, a death knight or a demon hunter, none of whom has a
			-- mana bar (ChrClasses.DisplayPower). It is the Mists reasoning: a
			-- buff only a caster benefits from, which manaOnly is how this
			-- addon says, and what "Skip players it does nothing for" (on by
			-- default) promises.
			manaOnly = true,
		},
	},

	PRIEST = {
		{ key = "fortitude", ranks = { 21562 } },
	},

	DRUID = {
		{ key = "motw", ranks = { 1126 } },
	},

	-- New in 11.0, all specs, learned at 16 (Wowhead retail; retail SpellLevels 16).
	-- Trained (SkillLineAbility), in no talent tree (no TraitDefinition row).
	SHAMAN = {
		{ key = "skyfury", ranks = { 462854 } },
	},

	EVOKER = {
		{
			key = "bronze",
			ranks = { 364342 },
			-- The thirteen auras the cast applies (its SpellEffect rows 0 to
			-- 12 trigger exactly these), one per class, none sharing the
			-- cast's id: without them a buffed target reads as missing it.
			-- Five more spells are named Blessing of the Bronze (432652,
			-- 432655, 432658, 432674, 442744); nothing in the client's spell
			-- data applies them, so they are not what an evoker's cast puts on
			-- anybody.
			group = {
				381732, 381741, 381746, 381748, 381749, 381750, 381751,
				381752, 381753, 381754, 381756, 381757, 381758,
			},
		},
		{
			-- Talent-gated (TraitDefinition), so gated on `known` like every
			-- spell here: an evoker without it never offers it.
			key = "sourceofmagic",
			ranks = { 369459 },
			manaOnly = true,
			talent = true,
			-- It goes to another player, never the evoker casting it.
			notSelf = true,
			-- "Limit 1": one ally carries it, and casting it on another takes
			-- it off the first. Every other mana user is always missing it, so
			-- Automatic walking on to it would move it from one passer-by to
			-- the next, off the healer it was meant for. Offered when it is
			-- pinned, and to whoever asks for it by name (ns.AskOnlyBuffs).
			neverAuto = true,
			-- And so it reaches nobody but its target, in a group or out.
			alone = true,
		},
	},

	WARRIOR = {
		{ key = "battleshout", ranks = { 6673 }, selfCast = true, partyOnly = true },
	},
}

-- A rogue's poisons, the one thing a retail class casts on itself alone that
-- fits a family: each is a spell that puts an aura of its own id on you for an
-- hour (retail SpellEffect: an aura on the caster, SpellMisc's 3,600,000 ms),
-- the lethal ones and the non-lethal ones each a family of their own. A
-- talent lets a rogue wear two of each (Dragon-Tempered Blades), and one lethal
-- and one non-lethal is all that is asked for, so a family is up when any one of
-- it is. Not every rogue knows every one (Deadly, Numbing, Amplifying and
-- Atrophic Poison are talents here, TraitDefinition); a spell not known is
-- never offered, so a rogue is asked for what hers can cast. Build
-- 12.1.0.69933.
local MAINLINE_OWN = {
	ROGUE = {
		{
			key = "lethal",
			label = L["Lethal poison"],
			spells = {
				{ key = "deadlypoison", ranks = { 2823 }, talent = true },
				{ key = "instantpoison", ranks = { 315584 } },
				{ key = "woundpoison", ranks = { 8679 } },
				{ key = "amplifyingpoison", ranks = { 381664 }, talent = true },
			},
		},
		{
			key = "nonlethal",
			label = L["Non-lethal poison"],
			spells = {
				{ key = "cripplingpoison", ranks = { 3408 } },
				{ key = "numbingpoison", ranks = { 5761 }, talent = true },
				{ key = "atrophicpoison", ranks = { 381637 }, talent = true },
			},
		},
	},
}

local MAINLINE_SET = {
	name = "mainline",
	buffs = MAINLINE,
	-- A rogue's poisons alone (above). What else a retail class casts on itself
	-- is either a toggle with no end (the paladin's auras: duration -1 in
	-- SpellMisc), or a shield whose one-at-a-time rule a talent lifts (Elemental
	-- Orbit, 383010, lets a shaman wear two of Lightning, Water and Earth
	-- Shield), which a family of "only one of these up" would get wrong.
	-- "Myself" offers your own group buff.
	own = MAINLINE_OWN,
	-- Battle Shout's reach, and the casts that land on your whole party and
	-- raid (target 118), as on Mists.
	shoutYards = 100,
	wideCasts = true,
	-- Nothing overwrites anything, and nothing depends on who is there.
	exclusive = {},
	auto = {},
	without = {
		PALADIN = true,      -- Kings, Might and Wisdom died in 7.0.3, Blessing of the Seasons in 12.0.0
		DEATHKNIGHT = true,  -- Horn of Winter removed in 11.2.0
		MONK = true,
		DEMONHUNTER = true,
		HUNTER = true,
		ROGUE = true,
		WARLOCK = true,      -- Unending Breath is not a courtesy
	},
	-- Class buffs others put on you that Manners never offers, counted as
	-- favours only, as the vanilla set counts them: Soulstone (20707, its
	-- "Soul stored by" aura on the target), a shaman's Water Walking (546) and
	-- a warlock's Unending Breath (5697). Fear Ward and Detect Invisibility are
	-- gone from retail's SpellName.
	favourOnly = { 20707, 546, 5697 },
	-- A paladin's auras reach the party and raid as their own ids (SpellEffect
	-- 65, an area aura on everybody within 40 yards) and land again each time
	-- you walk back into range: nobody's favour, as on vanilla, where the own
	-- table above is what says so. Here no family holds them, since they
	-- outlast death (SpellMisc Attributes_3 0x100000) and there is nothing to
	-- remind a paladin of. Devotion (465), Concentration (317920), Crusader
	-- (32223) and Retribution Aura (183435): retail SpellName and SpellEffect,
	-- and Wowhead ("Requires Paladin").
	notFavour = { [465] = true, [317920] = true, [32223] = true, [183435] = true },
	-- The level each buff above is learned at on retail (SpellLevels, build
	-- 12.1.0.69933; Wowhead "Requires level"), for "Skip my own class": the
	-- vanilla trainers' table (ns.RANK_LEVEL) puts Arcane Intellect and Mark
	-- of the Wild at 1. Source of Magic is a talent and Battle Shout a shout,
	-- neither read.
	rankLevel = { [1459] = 8, [21562] = 6, [1126] = 9, [462854] = 16, [364342] = 30 },
}

---------------------------------------------------------------------------
-- how long each lasts
---------------------------------------------------------------------------

-- The length of every buff Manners offers or watches, in seconds, per client:
-- what a top-up's lead is worked out from (Core.lua, ns.TopUpLead). One row is
-- { seconds, id, id, ... }, the ids being spell ids as the rest of this file
-- holds them (every rank, every group version, `alike` ids, an own buff's ranks;
-- for a weapon enhancement or a scroll the spell its use casts). 0 is "no
-- timer"; an id missing from a client's table has no length in that client's
-- data (or is not in that client at all), and is topped up by the player's
-- ceiling alone (the minutes slider), never guessed at.
--
-- Where each number comes from, per client, for the build named above its table:
--   SpellMisc.DurationIndex -> SpellDuration.Duration (milliseconds; -1 and 0
--   are no timer), of the spell that puts the aura on. A cast that only triggers
--   the aura (a Blessing of the Bronze, Mists' Legacy of the Emperor) is the
--   aura's. Forever's group versions and retail's are an hour like the single
--   spells; Classic Era's are twice as long, and its Blessings five minutes and
--   its Greater Blessings fifteen (Burning Crusade's ten and thirty, Forever's
--   an hour); a shout is two minutes on Classic Era, three on Forever, five on
--   Mists and an hour on retail.
--   A weapon enhancement or scroll: the use spell's own duration where it has
--   one (Mists' Corpse Worm), else SpellItemEnchantment.Duration (Forever's),
--   else the number in the use spell's own tooltip ("for 30 minutes": the
--   Classic builds' SpellItemEnchantment has no duration column, and the use
--   spell of an oil or a poison has none either).
-- tools/audit_ids.py holds every row to those tables, and goes red on a number
-- that is not what the client's data says, or an id missing one. Ranks of one
-- spell never differ in any of the five (the audit checks that too), so the
-- table is per id and not per buff; the aura's own `duration` beats it at
-- runtime wherever the client will say.
local function Seconds(rows)
	local out = {}
	for _, row in ipairs(rows) do
		for i = 2, #row do out[row[i]] = row[1] end
	end
	return out
end

local SECONDS_FOR = {}
do
	-- Classic Era 1.15.9.70003. No row for 430585 (Blackfathom Mana Oil, whose tooltip
	-- gives its length as a token the table does not resolve) nor for Forever's two
	-- own Trueshot Aura ranks (1299346 and 1299348), which this client lacks: unknown.
	SECONDS_FOR[VANILLA_SET] = Seconds({
		{ 1800, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, -- Mark of the Wild (30 min)
		{ 3600, 21850, 21849 }, -- Gift of the Wild (1 h)
		{ 600, 9910, 9756, 8914, 1075, 782, 467 }, -- Thorns (10 min)
		{ 1800, 10157, 10156, 1461, 1460, 1459 }, -- Arcane Intellect (30 min)
		{ 3600, 23028 }, -- Arcane Brilliance (1 h)
		{ 300, 25290, 19854, 19853, 19852, 19850, 19742 }, -- Blessing of Wisdom (5 min)
		{ 900, 25918, 25894 }, -- Greater Blessing of Wisdom (15 min)
		{ 300, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, -- Blessing of Might (5 min)
		{ 900, 25916, 25782 }, -- Greater Blessing of Might (15 min)
		{ 300, 20217 }, -- Blessing of Kings (5 min)
		{ 900, 25898 }, -- Greater Blessing of Kings (15 min)
		{ 300, 1038 }, -- Blessing of Salvation (5 min)
		{ 900, 25895 }, -- Greater Blessing of Salvation (15 min)
		{ 300, 19979, 19978, 19977 }, -- Blessing of Light (5 min)
		{ 900, 25890 }, -- Greater Blessing of Light (15 min)
		{ 300, 20914, 20913, 20912, 20911 }, -- Blessing of Sanctuary (5 min)
		{ 900, 25899 }, -- Greater Blessing of Sanctuary (15 min)
		{ 1800, 10938, 10937, 2791, 1245, 1244, 1243 }, -- Power Word: Fortitude (30 min)
		{ 3600, 21564, 21562 }, -- Prayer of Fortitude (1 h)
		{ 1800, 27841, 14819, 14818, 14752 }, -- Divine Spirit (30 min)
		{ 3600, 27681 }, -- Prayer of Spirit (1 h)
		{ 600, 10958, 10957, 976 }, -- Shadow Protection (10 min)
		{ 1200, 27683 }, -- Prayer of Shadow Protection (20 min)
		{ 600, 5697 }, -- Unending Breath (10 min)
		{ 600, 131 }, -- Water Breathing (10 min)
		{ 120, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, -- Battle Shout (2 min)
		{ 600, 16864 }, -- Omen of Clarity (10 min)
		{ 1800, 22756, 16138, 16622, 9900, 9903, 2830, 3114, 2829, 3113, 2828, 3112, 430392 }, -- sharpening stones and weightstones (30 min)
		{ 3600, 28891 }, -- sharpening stones and weightstones: Consecrated Weapon (1 h)
		{ 1800, 25122, 25123, 25121, 25120, 25119, 25118, 25117, 3595, 3594 }, -- oils and coatings (30 min)
		{ 3600, 28898 }, -- oils and coatings: Blessed Wizard Oil (1 h)
		{ 600, 8090, 9092, 8088, 8532, 8087 }, -- fishing lures (10 min)
		{ 300, 8089 }, -- fishing lures: Aquadynamic Fish Attractor (5 min)
		{ 1800, 20906, 20905, 19506 }, -- Trueshot Aura (30 min)
		{ 1800, 10220, 10219, 7320, 7302, 7301, 7300, 168 }, -- Ice Armor / Frost Armor (30 min)
		{ 1800, 22783, 22782, 6117 }, -- Mage Armor (30 min)
		{ 1800, 25780 }, -- Righteous Fury (30 min)
		{ 600, 10952, 10951, 1006, 602, 7128, 588 }, -- Inner Fire (10 min)
		{ 600, 19266, 19265, 19264, 19262, 19261, 2652 }, -- Touch of Weakness (10 min)
		{ 600, 19312, 19311, 19310, 19309, 19308, 18137 }, -- Shadowguard (10 min)
		{ 1800, 11340, 11339, 11338, 8688, 8686, 8679, 25351, 11356, 11355, 2824, 2823, 13227, 13226, 13225,
			13219, 11202, 3408, 11399, 8693, 5761, 6650, 1214171, 458821, 439465, 439464, 439462 }, -- poisons (30 min)
		{ 600, 10432, 10431, 8134, 945, 905, 325, 324 }, -- Lightning Shield (10 min)
		{ 600, 408510 }, -- Water Shield (10 min)
		{ 1800, 11735, 11734, 11733, 1086, 706, 696, 687 }, -- Demon Armor / Demon Skin (30 min)
		{ 1800, 403619 }, -- Fel Armor, Season of Discovery's rune (30 min)
	})

	-- Burning Crusade Classic Anniversary 2.5.6.69795.
	SECONDS_FOR[TBC_SET] = Seconds({
		{ 1800, 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, -- Mark of the Wild (30 min)
		{ 3600, 26991, 21850, 21849 }, -- Gift of the Wild (1 h)
		{ 600, 26992, 9910, 9756, 8914, 1075, 782, 467 }, -- Thorns (10 min)
		{ 1800, 27126, 10157, 10156, 1461, 1460, 1459 }, -- Arcane Intellect (30 min)
		{ 3600, 27127, 23028 }, -- Arcane Brilliance (1 h)
		{ 600, 27142, 25290, 19854, 19853, 19852, 19850, 19742 }, -- Blessing of Wisdom (10 min)
		{ 1800, 27143, 25918, 25894 }, -- Greater Blessing of Wisdom (30 min)
		{ 600, 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, -- Blessing of Might (10 min)
		{ 1800, 27141, 25916, 25782 }, -- Greater Blessing of Might (30 min)
		{ 600, 20217 }, -- Blessing of Kings (10 min)
		{ 1800, 25898 }, -- Greater Blessing of Kings (30 min)
		{ 600, 1038 }, -- Blessing of Salvation (10 min)
		{ 1800, 25895 }, -- Greater Blessing of Salvation (30 min)
		{ 600, 27144, 19979, 19978, 19977 }, -- Blessing of Light (10 min)
		{ 1800, 27145, 25890 }, -- Greater Blessing of Light (30 min)
		{ 600, 27168, 20914, 20913, 20912, 20911 }, -- Blessing of Sanctuary (10 min)
		{ 1800, 27169, 25899 }, -- Greater Blessing of Sanctuary (30 min)
		{ 1800, 25389, 10938, 10937, 2791, 1245, 1244, 1243 }, -- Power Word: Fortitude (30 min)
		{ 3600, 25392, 21564, 21562 }, -- Prayer of Fortitude (1 h)
		{ 1800, 25312, 27841, 14819, 14818, 14752 }, -- Divine Spirit (30 min)
		{ 3600, 32999, 27681 }, -- Prayer of Spirit (1 h)
		{ 600, 25433, 10958, 10957, 976 }, -- Shadow Protection (10 min)
		{ 1200, 39374, 27683 }, -- Prayer of Shadow Protection (20 min)
		{ 600, 5697 }, -- Unending Breath (10 min)
		{ 600, 131 }, -- Water Breathing (10 min)
		{ 120, 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, -- Battle Shout (2 min)
		{ 120, 469 }, -- Commanding Shout (2 min)
		{ 1800, 16864 }, -- Omen of Clarity (30 min)
		{ 3600, 29453, 34340, 22756, 29452, 34339, 16138, 16622, 9900, 9903, 2830, 3114, 2829, 3113, 2828,
			3112, 28891 }, -- sharpening stones and weightstones (1 h)
		{ 3600, 28017, 28013, 25122, 25123, 25121, 25120, 25119, 25118, 25117, 45395, 45397, 28898 }, -- oils and coatings (1 h)
		{ 1800, 3595, 3594 }, -- oils and coatings: Frost Oil, Shadow Oil (30 min)
		{ 600, 8090, 8089, 9092, 45731, 8088, 8532, 8087 }, -- fishing lures (10 min)
		{ 0, 27066, 20906, 20905, 19506 }, -- Trueshot Aura (no timer)
		{ 1800, 27124, 10220, 10219, 7320, 7302, 7301, 7300, 168 }, -- Ice Armor / Frost Armor (30 min)
		{ 1800, 27125, 22783, 22782, 6117 }, -- Mage Armor (30 min)
		{ 1800, 30482 }, -- Molten Armor (30 min)
		{ 1800, 25780 }, -- Righteous Fury (30 min)
		{ 600, 25431, 10952, 10951, 1006, 602, 7128, 588 }, -- Inner Fire (10 min)
		{ 600, 25461, 19266, 19265, 19264, 19262, 19261, 2652 }, -- Touch of Weakness (10 min)
		{ 600, 25477, 19312, 19311, 19310, 19309, 19308, 18137 }, -- Shadowguard (10 min)
		{ 3600, 26891, 11340, 11339, 11338, 8688, 8686, 8679, 27186, 26967, 25351, 11356, 11355, 2824, 2823,
			27188, 13227, 13226, 13225, 13219, 11202, 3408, 11399, 8693, 5761, 26785 }, -- poisons (1 h)
		{ 1800, 6650 }, -- poisons: Instant Toxin (30 min)
		{ 600, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }, -- Lightning Shield (10 min)
		{ 600, 33736, 24398 }, -- Water Shield (10 min)
		{ 600, 32594, 32593, 974 }, -- Earth Shield (10 min)
		{ 1800, 27260, 11735, 11734, 11733, 1086, 706, 696, 687 }, -- Demon Armor / Demon Skin (30 min)
		{ 1800, 28189, 28176 }, -- Fel Armor (30 min)
	})

	-- WoW Forever 1.60.1.70178.
	SECONDS_FOR[CAMELOT_SET] = Seconds({
		{ 3600, 9885, 9884, 8907, 5234, 6756, 5232, 1126 }, -- Mark of the Wild (1 h)
		{ 3600, 21850, 21849 }, -- Gift of the Wild (1 h)
		{ 600, 9910, 9756, 8914, 1075, 782, 467 }, -- Thorns (10 min)
		{ 3600, 10157, 10156, 1461, 1460, 1459 }, -- Arcane Intellect (1 h)
		{ 3600, 23028 }, -- Arcane Brilliance (1 h)
		{ 3600, 25290, 19854, 19853, 19852, 19850, 19742 }, -- Blessing of Wisdom (1 h)
		{ 3600, 25918, 25894 }, -- Greater Blessing of Wisdom (1 h)
		{ 3600, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }, -- Blessing of Might (1 h)
		{ 3600, 25916, 25782 }, -- Greater Blessing of Might (1 h)
		{ 3600, 20217 }, -- Blessing of Kings (1 h)
		{ 3600, 25898 }, -- Greater Blessing of Kings (1 h)
		{ 3600, 1038 }, -- Blessing of Salvation (1 h)
		{ 3600, 25895 }, -- Greater Blessing of Salvation (1 h)
		{ 3600, 19979, 19978, 19977 }, -- Blessing of Light (1 h)
		{ 3600, 25890 }, -- Greater Blessing of Light (1 h)
		{ 3600, 10938, 10937, 2791, 1245, 1244, 1243 }, -- Power Word: Fortitude (1 h)
		{ 3600, 21564, 21562 }, -- Prayer of Fortitude (1 h)
		{ 3600, 27841, 14819, 14818, 14752 }, -- Divine Spirit (1 h)
		{ 3600, 27681 }, -- Prayer of Spirit (1 h)
		{ 600, 10958, 10957, 976 }, -- Shadow Protection (10 min)
		{ 1200, 27683 }, -- Prayer of Shadow Protection (20 min)
		{ 600, 5697 }, -- Unending Breath (10 min)
		{ 600, 131 }, -- Water Breathing (10 min)
		{ 180, 25289, 11551, 11550, 11549, 6192, 5242, 6673 }, -- Battle Shout (3 min)
		{ 1800, 22756, 16138, 16622, 9900, 9903, 2830, 3114, 2829, 3113, 2828, 3112, 430392 }, -- sharpening stones and weightstones (30 min)
		{ 3600, 28891 }, -- sharpening stones and weightstones: Consecrated Weapon (1 h)
		{ 1800, 25122, 25123, 25121, 25120, 25119, 25118, 25117, 3595, 3594 }, -- oils and coatings (30 min)
		{ 3600, 28898 }, -- oils and coatings: Blessed Wizard Oil (1 h)
		{ 600, 8090, 9092, 8088, 8532, 8087 }, -- fishing lures (10 min)
		{ 300, 8089 }, -- fishing lures: Aquadynamic Fish Attractor (5 min)
		{ 1800, 20906, 20905, 19506, 1299348, 1299346 }, -- Trueshot Aura (30 min)
		{ 1800, 10220, 10219, 7320, 7302, 7301, 7300, 168 }, -- Ice Armor / Frost Armor (30 min)
		{ 1800, 22783, 22782, 6117 }, -- Mage Armor (30 min)
		{ 3600, 1302303, 1302285, 1296202 }, -- familiar scrolls: Cat Familiar, Frog Familiar, Rat Familiar (1 h)
		{ 3600, 1302311, 1302312, 1302310, 1302306, 1302307, 1302305, 1302304, 1302308, 1302283, 1302217,
			1302219, 1302284, 1302227, 1295720, 1296225 }, -- weapon imbue scrolls (1 h)
		{ 1800, 25780 }, -- Righteous Fury (30 min)
		{ 600, 10952, 10951, 1006, 602, 7128, 588 }, -- Inner Fire (10 min)
		{ 600, 19266, 19265, 19264, 19262, 19261, 2652 }, -- Touch of Weakness (10 min)
		{ 600, 19312, 19311, 19310, 19309, 19308, 18137 }, -- Shadowguard (10 min)
		{ 1800, 11340, 11339, 11338, 8688, 8686, 8679, 25351, 11356, 11355, 2824, 2823, 13227, 13226, 13225,
			13219, 11202, 3408, 11399, 8693, 5761, 6650, 1214171, 458821, 439465, 439464, 439462 }, -- poisons (30 min)
		{ 600, 10432, 10431, 8134, 945, 905, 325, 324 }, -- Lightning Shield (10 min)
		{ 600, 408510 }, -- Water Shield (10 min)
		{ 1800, 11735, 11734, 11733, 1086, 706, 696, 687 }, -- Demon Armor / Demon Skin (30 min)
		{ 1800, 403619 }, -- Fel Armor, the Season of Discovery rune's id (30 min, build 1.60.1.70532)
	})

	-- Mists of Pandaria Classic 5.5.4.70032.
	SECONDS_FOR[MISTS_SET] = Seconds({
		{ 300, 57330 }, -- Horn of Winter (5 min)
		{ 300, 6673 }, -- Battle Shout (5 min)
		{ 0, 19506 }, -- Trueshot Aura (no timer)
		{ 3600, 1126 }, -- Mark of the Wild (1 h)
		{ 3600, 20217, 117666, 117667 }, -- Blessing of Kings / Legacy of the Emperor (1 h)
		{ 3600, 1459 }, -- Arcane Brilliance (1 h)
		{ 3600, 61316 }, -- Dalaran Brilliance (1 h)
		{ 0, 115921 }, -- Legacy of the Emperor (the cast: no timer of its own; its auras are 117666 and 117667, an hour)
		{ 3600, 116781 }, -- Legacy of the White Tiger (1 h)
		{ 0, 24932 }, -- Leader of the Pack (no timer)
		{ 3600, 19740 }, -- Blessing of Might (1 h)
		{ 3600, 21562 }, -- Power Word: Fortitude (1 h)
		{ 3600, 109773 }, -- Dark Intent (1 h)
		{ 300, 469 }, -- Commanding Shout (5 min)
		{ 600, 5697 }, -- Unending Breath (10 min)
		{ 3600, 29453, 34340, 22756, 29452, 34339, 16138, 16622, 9900, 9903, 2830, 3114, 2829, 3113, 2828,
			3112, 28891 }, -- sharpening stones and weightstones (1 h)
		{ 3600, 47904, 28017, 28013, 25122, 25123, 25121, 25120, 25119, 25118, 25117, 45395, 45397, 28898 }, -- oils and coatings (1 h)
		{ 1800, 3595, 3594 }, -- oils and coatings: Frost Oil, Shadow Oil (30 min)
		{ 900, 95244 }, -- fishing lures: Heat-Treated Spinning Lure (15 min)
		{ 600, 87646, 8090, 8089, 9092, 45731, 8088, 8532, 8087, 99315, 98849 }, -- fishing lures (10 min)
		{ 3600, 64401 }, -- fishing lures: Glow Worm (1 h)
		{ 0, 25780 }, -- Righteous Fury (no timer)
		{ 3600, 2823 }, -- Deadly Poison (1 h)
		{ 3600, 8679 }, -- Wound Poison (1 h)
		{ 3600, 3408 }, -- Crippling Poison (1 h)
		{ 3600, 5761 }, -- Mind-numbing Poison (1 h)
		{ 3600, 108211 }, -- Leeching Poison (1 h)
		{ 3600, 108215 }, -- Paralytic Poison (1 h)
		{ 3600, 324 }, -- Lightning Shield (1 h)
		{ 3600, 52127 }, -- Water Shield (1 h)
		{ 600, 974 }, -- Earth Shield (10 min)
	})

	-- retail 12.1.0.69933.
	SECONDS_FOR[MAINLINE_SET] = Seconds({
		{ 3600, 1126 }, -- Mark of the Wild (1 h)
		{ 3600, 364342 }, -- Blessing of the Bronze (1 h)
		{ 3600, 381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756,
			381757, 381758 }, -- Blessing of the Bronze (1 h)
		{ 3600, 369459 }, -- Source of Magic (1 h)
		{ 3600, 1459 }, -- Arcane Intellect (1 h)
		{ 3600, 21562 }, -- Power Word: Fortitude (1 h)
		{ 3600, 462854 }, -- Skyfury (1 h)
		{ 3600, 6673 }, -- Battle Shout (1 h)
		{ 3600, 2823 }, -- Deadly Poison (1 h)
		{ 3600, 315584 }, -- Instant Poison (1 h)
		{ 3600, 8679 }, -- Wound Poison (1 h)
		{ 3600, 381664 }, -- Amplifying Poison (1 h)
		{ 3600, 3408 }, -- Crippling Poison (1 h)
		{ 3600, 5761 }, -- Numbing Poison (1 h)
		{ 3600, 381637 }, -- Atrophic Poison (1 h)
	})
end

---------------------------------------------------------------------------
-- which set this client gets
---------------------------------------------------------------------------

local SETS = {
	vanilla = VANILLA_SET,
	tbc = TBC_SET,
	-- Forever runs vanilla content, and the vanilla tables are the ones
	-- verified there in game, less what its client changed; its own buffs
	-- add the mage's scrolls.
	camelot = CAMELOT_SET,
	mists = MISTS_SET,
	mainline = MAINLINE_SET,
}

-- A client whose interface number matched no band gets the set for the family
-- Flavour.lua classified it into. It is a guess, and ns.BUFFS_SOURCE says so
-- in /manners debug.
local BY_FAMILY = { classic = VANILLA_SET, modern = MAINLINE_SET }

local function ChooseSet()
	local flavour = ns.Flavour
	if type(flavour) ~= "table" then
		-- Unreachable from a release (validate.py checks the toc), but not
		-- from a hand-assembled addon folder.
		return nil, L["Flavour.lua did not load, so there is nothing to choose from"]
	end

	-- The set's name stays as it is in every language: it is the data set's
	-- identifier, and the scenarios find it in this string.
	local set = SETS[flavour.flavour]
	if set then return set, set.name end

	set = BY_FAMILY[flavour.family]
	if set then
		return set, L["%s, guessed from the %s family"]:format(set.name, tostring(flavour.family))
	end

	return nil, L["no set for %s/%s"]:format(tostring(flavour.flavour), tostring(flavour.family))
end

local chosen, source = ChooseSet()
ns.BUFFS_SOURCE = source

if chosen then
	ns.BUFFS = chosen.buffs
	ns.EXCLUSIVE_BUFFS = chosen.exclusive
	ns.CLASS_AUTO = chosen.auto
	ns.CLASSES_WITHOUT_BUFFS = chosen.without
	ns.PARTY_IS_SUBGROUP = chosen.partyIsSubgroup == true
	ns.GROUP_IS_RAID = chosen.groupIsRaid == true
	ns.SHOUT_YARDS = chosen.shoutYards
	ns.WIDE_CASTS = chosen.wideCasts == true
	ns.GROUP_BY_CLASS = chosen.groupByClass
	ns.OWN_BUFFS = chosen.own
	ns.FAVOUR_ONLY_IDS = chosen.favourOnly
	-- Party auras that are nobody's favour though no family holds them
	-- (a druid's forms, Mists' passives, retail's paladin auras).
	ns.NOT_FAVOUR_IDS = chosen.notFavour
	-- A set whose buffs are learned at other levels than vanilla's ranks
	-- brings its own (Mists, retail); the others read vanilla's.
	if chosen.rankLevel then ns.RANK_LEVEL = chosen.rankLevel end
end

-- What each rank and each blocker of a buff gives (see `blockers`, and
-- VANILLA_STAT). The sets whose stat buffs are percentages (Mists, retail) have
-- none, and so no buff of theirs lists a blocker.
ns.STAT_VALUE = chosen and chosen.statValue or {}

-- How long each id lasts on this client (see "how long each lasts"): seconds,
-- 0 for no timer, nothing for unknown. A client with no set has none.
ns.SPELL_SECONDS = chosen and SECONDS_FOR[chosen] or {}

-- The length of a buff for others: its single cast's, and the group version's
-- when that is another length (Classic Era's Prayer of Fortitude is an hour
-- where Power Word: Fortitude is half of one), else nil. Both nil where the
-- client's data has no length.
function ns.BuffSeconds(buff)
	local single = buff and buff.ranks and ns.SPELL_SECONDS[buff.ranks[1]]
	local group = buff and buff.group and ns.SPELL_SECONDS[buff.group[1]]
	if group == single then group = nil end
	return single, group
end

-- The length of one of your own spells (a family's `spells` entry): a toggle
-- (an aura, an aspect, a stance) and a tracking skill have no timer, and so
-- read 0 whatever the table says. A scroll or an enhancement is keyed by the
-- spell its use casts, which is its first rank.
function ns.OwnSeconds(spell)
	local family = spell and spell.family
	if family and (family.toggle or family.tracking) then return 0 end
	return spell and spell.ranks and ns.SPELL_SECONDS[spell.ranks[1]] or nil
end

-- The key of every own-buff family on any client, not only this one's. A
-- settings string names the families of the client it was made on
-- (ownBuffs.pick.<key>), and an import here tells another client's from a
-- setting a later version added with this (Commands.lua).
ns.OWN_FAMILY_ANY_CLIENT = {}
for _, set in pairs(SETS) do
	for _, families in pairs(set.own or {}) do
		for _, family in ipairs(families) do ns.OWN_FAMILY_ANY_CLIENT[family.key] = true end
	end
end

-- The key of every buff for others, by class, on any client and not only this
-- one: ns.BUFF_KEY_ANY_CLIENT[class][key]. A saved buff order names the keys of
-- the client it was made on (db.buff.order[CLASS], Core.lua), and one shared by
-- two clients holds keys this one lacks: Core.lua's repair keeps those and drops
-- what no client has.
ns.BUFF_KEY_ANY_CLIENT = {}
for _, set in pairs(SETS) do
	for class, list in pairs(set.buffs or {}) do
		local keys = ns.BUFF_KEY_ANY_CLIENT[class] or {}
		ns.BUFF_KEY_ANY_CLIENT[class] = keys
		for _, buff in ipairs(list) do keys[buff.key] = true end
	end
end

---------------------------------------------------------------------------
-- derived lookups
---------------------------------------------------------------------------

-- Every id any class can apply, used to tell a real class buff from a stray
-- heal-over-time or proc when deciding whether we owe somebody a favour: the
-- buffs above, and the set's favourOnly ones Manners never offers.
ns.ALL_BUFF_IDS = {}
ns.BUFF_BY_ID = {}
-- The same for the class's own buffs, apart: none of them is anybody's favour
-- (ALL_BUFF_IDS decides that), and none of them is walked by Automatic.
ns.OWN_BY_ID = {}
ns.OWN_SPELL_BY_KEY = {}
ns.OWN_FAMILY_BY_KEY = {}

-- The own-buff lookups, a family and a spell knowing each other: a spell's
-- `family` is what a press on it and the options page read back, and its
-- auraIds are what the reading matches, as for the tables above.
local function BuildOwnLookups()
	wipe(ns.OWN_BY_ID)
	wipe(ns.OWN_SPELL_BY_KEY)
	wipe(ns.OWN_FAMILY_BY_KEY)
	if type(ns.OWN_BUFFS) ~= "table" then ns.OWN_BUFFS = {} end
	for class, families in pairs(ns.OWN_BUFFS) do
		for index, family in ipairs(families) do
			family.class, family.order = class, index
			ns.OWN_FAMILY_BY_KEY[family.key] = family
			for _, spell in ipairs(family.spells) do
				spell.class, spell.family, spell.own = class, family, true
				spell.auraIds = {}
				for _, id in ipairs(spell.ranks) do
					spell.auraIds[#spell.auraIds + 1] = id
					ns.OWN_BY_ID[id] = spell
				end
				ns.OWN_SPELL_BY_KEY[spell.key] = spell
			end
		end
	end
end

-- Whether `id` is a class's own aura or aspect, which reaching you is nobody's
-- favour (Favours.lua): it lands again every time you walk back into its
-- range. Not an own spell the class casts on somebody else too (castOnOthers),
-- which on you is a favour like any shield.
function ns.IsOwnAura(id)
	local spell = ns.OWN_BY_ID[id]
	return spell ~= nil and not spell.castOnOthers
end

-- A function rather than a bare loop, so a client with no table to walk (no
-- flavour and no family matched) is reported rather than thrown on: a file
-- that throws while loading leaves no addon at all, silently. The three tables
-- beside ns.BUFFS are defaulted for the same reason, since Core.lua, the
-- files after it and the options page index them without asking.
function ns.BuildBuffLookups()
	wipe(ns.ALL_BUFF_IDS)
	wipe(ns.BUFF_BY_ID)

	if type(ns.EXCLUSIVE_BUFFS) ~= "table" then ns.EXCLUSIVE_BUFFS = {} end
	if type(ns.CLASS_AUTO) ~= "table" then ns.CLASS_AUTO = {} end
	if type(ns.CLASSES_WITHOUT_BUFFS) ~= "table" then ns.CLASSES_WITHOUT_BUFFS = {} end
	if type(ns.GROUP_BY_CLASS) ~= "table" then ns.GROUP_BY_CLASS = {} end
	if type(ns.NOT_FAVOUR_IDS) ~= "table" then ns.NOT_FAVOUR_IDS = {} end
	-- Ahead of the early return below: a client with no buffs for others
	-- still has an (empty) table of its own buffs to index.
	BuildOwnLookups()

	if type(ns.BUFFS) ~= "table" then
		ns.BUFFS = {}
		ns.BUFFS_MISSING = L["no buff data for this client -- %s"]:format(
			(ns.FlavourSummary and ns.FlavourSummary()) or L["flavour unknown"])
		-- Printed here too: this runs during load, before the addon has a
		-- Print of its own, and not every user opens /manners debug.
		if type(print) == "function" then
			print("|cffff4040Manners:|r " .. L["%s -- nobody will be offered a buff. Please report this, with the output of /manners debug."]:format(ns.BUFFS_MISSING))
		end
		return
	end
	ns.BUFFS_MISSING = nil

	for class, list in pairs(ns.BUFFS) do
		for index, buff in ipairs(list) do
			buff.class = class
			buff.order = index

			buff.auraIds = {}
			for _, id in ipairs(buff.ranks) do
				buff.auraIds[#buff.auraIds + 1] = id
			end
			for _, id in ipairs(buff.group or {}) do
				buff.auraIds[#buff.auraIds + 1] = id
			end

			for _, id in ipairs(buff.auraIds) do
				ns.ALL_BUFF_IDS[id] = true
				ns.BUFF_BY_ID[id] = buff
			end

			-- Another class's of the same kind: read as this one held, by
			-- somebody else (Core.lua, UnitHasBuff), and filed under its own.
			buff.alikeIds = nil
			if buff.alike then
				buff.alikeIds = {}
				for _, id in ipairs(buff.alike) do
					buff.auraIds[#buff.auraIds + 1] = id
					buff.alikeIds[id] = true
				end
			end

			-- The auras that hold it off (`blockers`), strongest first, kept
			-- apart from auraIds: wearing one is not wearing the buff, nor
			-- anybody's favour, so none is matched, filed or counted as it. A
			-- row the table has no number for is never worth anything, and
			-- sorts last. readIds is what UnitHasBuff asks the client for, in
			-- one batch: the buff's own ids, then these, so the first found is
			-- the strongest one worn.
			buff.blockerIds, buff.readIds = nil, nil
			if buff.blockers then
				local stat = ns.STAT_VALUE
				local list = {}
				for _, id in ipairs(buff.blockers) do list[#list + 1] = id end
				table.sort(list, function(a, b)
					local va, vb = stat[a] or 0, stat[b] or 0
					if va ~= vb then return va > vb end
					return a < b
				end)
				buff.blockerIds = list
				buff.readIds = {}
				for _, id in ipairs(buff.auraIds) do buff.readIds[#buff.readIds + 1] = id end
				for _, id in ipairs(list) do buff.readIds[#buff.readIds + 1] = id end
			end
		end
	end
	-- A favour, and nothing else: no buff of anybody's is filed under them.
	for _, id in ipairs(type(ns.FAVOUR_ONLY_IDS) == "table" and ns.FAVOUR_ONLY_IDS or {}) do
		ns.ALL_BUFF_IDS[id] = true
	end
end

ns.BuildBuffLookups()

function ns.GetClassBuffs(class)
	return ns.BUFFS[class or select(2, UnitClass("player"))]
end

function ns.FindBuff(class, key)
	for _, buff in ipairs(ns.BUFFS[class] or {}) do
		if buff.key == key then return buff end
	end
end

-- The class's own-buff families (see VANILLA_OWN), or nil for a class with
-- none on this client.
function ns.GetOwnFamilies(class)
	local families = ns.OWN_BUFFS[class or select(2, UnitClass("player"))]
	if families and #families > 0 then return families end
	return nil
end

function ns.FindOwnSpell(key)
	return key and ns.OWN_SPELL_BY_KEY[key] or nil
end

function ns.FindOwnFamily(key)
	return key and ns.OWN_FAMILY_BY_KEY[key] or nil
end

-- Whether any class on this client has a buff by that key. A pin lives in the
-- profile every character shares, so one this character cannot cast is still
-- somebody's -- and only a key nobody has is nonsense.
function ns.AnyClassHasBuff(key)
	for class in pairs(ns.BUFFS) do
		if ns.FindBuff(class, key) then return true end
	end
	return false
end
