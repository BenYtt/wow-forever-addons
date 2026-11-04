-----------------------------------------------------------------------
-- Upvalued Lua API.
-----------------------------------------------------------------------
local _G = getfenv(0)
local select = _G.select
local string = _G.string
local format = string.format

-- WoW
local function C_Map_GetAreaInfo(id)
	local d = C_Map.GetAreaInfo(id)
	return d or "GetAreaInfo"..id
end

-- ----------------------------------------------------------------------------
-- AddOn namespace.
-- ----------------------------------------------------------------------------
local addonname = ...
local AtlasLoot = _G.AtlasLoot
if AtlasLoot:GameVersion_LT(AtlasLoot.FOREVER_VERSION_NUM) then return end
local data = AtlasLoot.ItemDB:Add(addonname, 3, AtlasLoot.FOREVER_VERSION_NUM)

local AL = AtlasLoot.Locales
local ALIL = AtlasLoot.IngameLocales

local GetForVersion = AtlasLoot.ReturnForGameVersion

local NORMAL_DIFF = data:AddDifficulty("NORMAL", nil, nil, nil, true)

local NORMAL_ITTYPE = data:AddItemTableType("Item", "Item")

local PRICE_EXTRA_ITTYPE = data:AddExtraItemTableType("Price")

local DUNGEON_CONTENT = data:AddContentType(AL["Dungeons"], ATLASLOOT_DUNGEON_COLOR)
local RAID_CONTENT = data:AddContentType(AL["Raids"], ATLASLOOT_RAID20_COLOR)

-- Placeholder boss/loot entry used until real encounter and item data is known.
local function ComingSoon()
	return {
		name = AL["Coming Soon"],
		[NORMAL_DIFF] = {
			{ 1, "INV_Box_01", nil, AL["Loot data not yet available"] },
		}
	}
end

-- ##############################
-- Raids
-- ##############################

data["MountHyjal"] = {
	name = AL["Mount Hyjal"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = RAID_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["BarrowDeeps"] = {
	name = AL["Barrow Deeps"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = RAID_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["OnyxiasLair"] = {
	name = AL["Onyxia's Lair"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = RAID_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

-- ##############################
-- Dungeons
-- ##############################
-- Kept in level order: the loot browser lists content in registration order.
-- The "...Forever" entries are copies of the Vanilla dungeons in data.lua that
-- still exist on Forever. They need their own keys, which also stamps them with
-- Forever's game version so the loot browser lists them; the Classic originals
-- stay loaded for the item source tooltips. Forever doesn't include TBC or Wrath,
-- so the event bosses and drops those expansions added are left out.

local ATLAS_MODULE_NAME = "Atlas_ClassicWoW"

local GREEN = "|cff66cc33%s|r"
local PURP = "|cff9900ff%s|r"

local NAME_COLOR_BOSS = "|cffC0C0C0"
local NAME_BRD_RING_OF_LAW = NAME_COLOR_BOSS..AL["Ring of Law"]..":|r %s"

local KEYS = {	-- Keys
	name = AL["Keys"],
	TableType = NORMAL_ITTYPE,
	ExtraList = true,
	IgnoreAsSource = true,
	[NORMAL_DIFF] = {
		{ 1, "INV_Box_01", nil, AL["Key"], nil },
		{ 2, 16309,},
		{ 3, 12344,},
		{ 4, 17191,},
		{ 5, 7146, },
		{ 6, 12382,},
		{ 7, 6893, },
		{ 8, 11000,},
		{ 9, 11140,},
		{ 10, 18249, },
		{ 11, 13704, },
		{ 12, 11197, },
		{ 13, 18266, },
		{ 14, 18268, },
		{ 15, 13873, },
		{ 16, "INV_Box_01", nil, AL["Misc"], nil },
		{ 17, 19931 },
		{ 18, 18250 },
		{ 19, 9240 },
		{ 20, 17333 },
		{ 21, 22754 },
		{ 22, 13523 },
		{ 23, 18746 },
		{ 24, 18663 },
		{ 25, 19974 },
		{ 26, 7733 },
		{ 27, 10818 },
		{ 29, 22057 },
		{ 30, 21986 },
	},
}

local DM_BOOKS = { -- DMBooks
	name = AL["Books"],
	ExtraList = true,
	IgnoreAsSource = true,
	[NORMAL_DIFF] = {
		{ 1,  18401 }, -- Foror's Compendium of Dragon Slaying
		{ 3,  18362 }, -- Holy Bologna: What the Light Won't Tell You
		{ 4,  18358 }, -- The Arcanist's Cookbook
		{ 5,  18360 }, -- Harnessing Shadows
		{ 6,  18356 }, -- Garona: A Study on Stealth and Treachery
		{ 7,  18364 }, -- The Emerald Dream
		{ 8,  18361 }, -- The Greatest Race of Hunters
		{ 9,  18363 }, -- Frost Shock and You
		{ 10, 18359 }, -- The Light and How to Swing It
		{ 11, 18357 }, -- Codex of Defense
		--{ 16, 18348 }, -- Quel'Serrar
		{ 18, 18333 }, -- Libram of Focus
		{ 19, 18334 }, -- Libram of Protection
		{ 20, 18332 }, -- Libram of Rapidity
		{ 22, 11733 }, -- Libram of Constitution
		{ 23, 11736 }, -- Libram of Resilience
		{ 24, 11732 }, -- Libram of Rumination
		{ 25, 11734 }, -- Libram of Tenacity
		{ 26, 11737 }, -- Libram of Voracity
	},
}

data["RagefireForever"] = {
	MapID = 2437,
	InstanceID = 389,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Ragefire",
	AtlasMapFile = "RagefireChasm",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({10, 13, 18}, {8, 13, 16}),
	items = {
		{ -- RFCOggleflint
			name = AL["Oggleflint"],
			npcID = 11517,
			Level = 16,
			DisplayIDs = {{11611}},
			[NORMAL_DIFF] = {
				{ 1,  272999 }, -- Barbaric Crossbow
				{ 2,  272996 }, -- Trogg Scepter
				{ 3,  272998 }, -- Bone Knuckles
				{ 16, 252781 }, -- Pattern: Stormrider's Leather Gloves
				{ 17, 252782 }, -- Pattern: Wisdom's Leather Gloves
			},
		},
		{ -- RFCTaragaman
			name = AL["Taragaman the Hungerer"],
			npcID = 11520,
			Level = 16,
			DisplayIDs = {{7970}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  14149 }, -- Subterranean Cape
				{ 2,  14148 }, -- Crystalline Cuffs
				{ 3,  14145 }, -- Cursed Felblade
				{ 16, 251361 }, -- Plans: Guard's Gloves
				{ 17, 251362 }, -- Plans: Protector's Gloves
				{ 18, 251363 }, -- Plans: Acolyte's Gloves
				{ 19, 252782 }, -- Pattern: Wisdom's Leather Gloves
			},
		},
		{ -- RFCJergosh
			name = AL["Jergosh the Invoker"],
			npcID = 11518,
			Level = 16,
			DisplayIDs = {{11429}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  14150 }, -- Robe of Evocation
				{ 2,  14147 }, -- Cavedweller Bracers
				{ 3,  14151 }, -- Chanting Blade
				{ 16, 251360 }, -- Plans: Veteran's Gloves
				{ 17, 253906 }, -- Pattern: Filigreed Flame Gown
			},
		},
		{ -- RFCBazzalan
			name = AL["Bazzalan"],
			npcID = 11519,
			Level = 16,
			DisplayIDs = {{2007}},
			[NORMAL_DIFF] = {
				{ 1,  273003 }, -- Searing Dagger
				{ 2,  273007 }, -- Chasm Walkers
				{ 3,  273005 }, -- Satyrskin Cloak
				{ 16, 252780 }, -- Pattern: Totemic Leather Gloves
				{ 17, 252782 }, -- Pattern: Wisdom's Leather Gloves
				{ 18, 253908 }, -- Pattern: Filigreed Shadow Gown
				{ 19, 253910 }, -- Pattern: Filigreed Pearly Gown
			},
		},
	},
}

data["TheHallOfThanes"] = {
	name = AL["The Hall of Thanes"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {13, 13, 18},
	items = {
		{ -- HoTFaldrimAnvilmar
			name = AL["Faldrim Anvilmar"],
			npcID = 261306,
			Level = 16,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 270227 }, -- Ephemeral Choker
				{ 2, 271096 }, -- Aetherwisp Bracers
				{ 3, 271097 }, -- Spiritwraith Drape
			},
		},
		{ -- HoTMagmatus
			name = AL["Magmatus"],
			Level = 16,
			-- TODO: npcID, DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 270230 }, -- Kindlegem Girdle
				{ 2, 270231 }, -- Flamefist Grips
				{ 3, 271095 }, -- Fang of Magmatus
			},
		},
		{ -- HoTPlunder
			name = AL["Plunder"],
			npcID = 261311,
			Level = 16,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 270228 }, -- Golemheart Stave
				{ 2, 270229 }, -- Treads of the Protector Golem
				{ 3, 271098 }, -- Golemguard Chest
			},
		},
		{ -- HoTDurgenDirgehammer
			name = AL["Durgen Dirgehammer"],
			npcID = 261319,
			Level = 16,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 270256 }, -- Durgen's Crescent Axe
				{ 2, 270260 }, -- Direhammer Leggings
				{ 3, 270261 }, -- Robes of the Disgraced Thane
				{ 16, 274286 }, -- Durgen Dirgehammer's Head
			},
		},
	}
}

data["RuinsOfLordaeron"] = {
	name = AL["Ruins of Lordaeron"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {15, 15, 20},
	items = {
		{ -- RoLWitherfang
			name = AL["Witherfang"],
			Level = 17,
			npcID = 250483,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 271202 }, -- Witherbite Bracers
				{ 2, 271201 }, -- Atrophic Girdle
				{ 3, 271203 }, -- Segmented Spider Leg
			},
		},
		{ -- RoLTheBaron
			name = AL["The Baron"],
			Level = 17,
			npcID = 250660,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 271206 }, -- Leftover Abomination Skin
				{ 2, 271205 }, -- Abomination Bones
				{ 3, 271204 }, -- Meathook Slicer
			},
		},
		{ -- RoLViktorTheVile
			name = AL["Viktor the Vile"],
			Level = 19,
			npcID = 256035,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 271212 }, -- Bloodied Chestwraps
				{ 2, 271211 }, -- Vilewalkers
				{ 3, 271218 }, -- Vileblood Scimitar
			},
		},
		{ -- RoLTheAbandoned
			name = AL["The Abandoned"],
			Level = 18,
			npcID = 250631,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 271207 }, -- Rotmender's Leggings
				{ 2, 271208 }, -- Grip of Fear
				{ 3, 271216 }, -- Scepter of the Abandoned
			},
		},
		{ -- RoLBjork
			name = AL["Bjork"],
			Level = 19,
			npcID = 256097,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 271210 }, -- Tuskwrap Belt
				{ 2, 271209 }, -- Bonerust Leggings
				{ 3, 271217 }, -- Corpse Chopper
			},
		},
		{ -- RoLRathmael
			name = AL["Rath'mael"],
			Level = 20,
			npcID = 250657,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 271214 }, -- Rotmender's Treads
				{ 2, 271213 }, -- Mirror of Rath'mael
				{ 3, 271215 }, -- Coldspire Staff
				{ 16, 273085 }, -- Blueprint: Fermenter
				{ 17, 273103 }, -- Blueprint: Arcane Salvager
			},
		},
		{ -- RoLLordaeronCaptain
			-- Rare spawn, only spawns once the other six bosses are dead. Friendly to Alliance; only Horde can kill it.
			name = AL["Lordaeron Captain"],
			Level = 19,
			specialType = "rare",
			-- TODO: npcID, DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 6642 }, -- Phantom Armor
				{ 2, 6641 }, -- Haunting Blade
			},
		},
		{ -- Trash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1, 286981 }, -- Death Bindings
				{ 2, 286977 }, -- Sword of the Fallen
				{ 3, 286978 }, -- Rotmender's Garb
				{ 4, 286980 }, -- Rotmender's Sash
				{ 5, 286979 }, -- Rotmender's Gloves
			},
		},
	}
}

data["WailingCavernsForever"] = {
	MapID = 718,
	InstanceID = 43,
	SubAreaIDs = { 15285, 15301, 15294, 15300, 15292, 17731 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "WailingCaverns",
	AtlasMapFile = {"CL_WailingCaverns", "CL_WailingCavernsEnt"},
	AtlasMapFile_AL = {"WailingCaverns", "WailingCavernsEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({10, 17, 24}, {10, 17, 21}),
	items = {
		{ -- WCLordCobrahn
			name = AL["Lord Cobrahn"],
			npcID = 3669,
			Level = 20,
			SubAreaID = 15300,
			DisplayIDs = {{4213}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  6460 }, -- Cobrahn's Grasp
				{ 2,  10410 }, -- Leggings of the Fang
				{ 4,  6465 }, -- Robe of the Moccasin
			},
		},
		{ -- WCLadyAnacondra
			name = AL["Lady Anacondra"],
			npcID = 3671,
			Level = 20,
			DisplayIDs = {{4313}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  10412 }, -- Belt of the Fang
				{ 3,  5404 }, -- Serpent's Shoulders
				{ 4,  6446 }, -- Snakeskin Bag
				{ 5,  273088 }, -- Snake Eye Kaleidoscope
			},
		},
		{ -- WCKresh
			name = AL["Kresh"],
			npcID = 3653,
			Level = 20,
			DisplayIDs = {{5126}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  13245 }, -- Kresh's Back
				{ 3,  6447 }, -- Worn Turtle Shell Shield
				{ 4,  273084 }, -- Cloak of Hermitic Bliss
			},
		},
		{ -- WCLordPythas
			name = AL["Lord Pythas"],
			npcID = 3670,
			Level = GetForVersion(21, 20),
			SubAreaID = 17731,
			DisplayIDs = {{4214}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  6472 }, -- Stinging Viper
				{ 3,  6473 }, -- Armor of the Fang
				{ 4,  273089 }, -- Slither Cord
			},
		},
		{ -- WCSkum
			name = AL["Skum"],
			npcID = 3674,
			Level = GetForVersion(21, 20),
			DisplayIDs = {{4203}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  6449 }, -- Glowing Lizardscale Cloak
				{ 3,  6448 }, -- Tail Spike
				{ 4,  273137 }, -- Skum's Bucket
			},
		},
		{ -- WCLordSerpentis
			name = AL["Lord Serpentis"],
			npcID = 3673,
			Level = GetForVersion(21, 20),
			DisplayIDs = {{4215}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  6469 }, -- Venomstrike
				{ 3,  5970 }, -- Serpent Gloves
				{ 4,  10411 }, -- Footpads of the Fang
				{ 5,  6459 }, -- Savage Trodders
			},
		},
		{ -- WCVerdan
			name = AL["Verdan the Everliving"],
			npcID = 5775,
			Level = GetForVersion(21, 20),
			DisplayIDs = {{4256}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  6630 }, -- Seedcloud Buckler
				{ 2,  6631 }, -- Living Root
				{ 4,  6629 }, -- Sporid Cape
			},
		},
		{ -- WCMutanus
			name = AL["Mutanus the Devourer"],
			npcID = 3654,
			Level = GetForVersion(22, 20),
			SubAreaID = 15294,
			DisplayIDs = {{4088}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  6461 }, -- Slime-encrusted Pads
				{ 2,  6627 }, -- Mutant Scale Breastplate
				{ 3,  6463 }, -- Deep Fathom Ring
				{ 16,  10441 }, -- Glowing Shard
			},
		},
		{ -- WCDeviateFaerieDragon
			name = AL["Deviate Faerie Dragon"],
			npcID = 5912,
			Level = GetForVersion(19, 20),
			DisplayIDs = {{1267}},
			AtlasMapBossID = 10,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  5243 }, -- Firebelcher
				{ 3,  6632 }, -- Feyscale Cloak
				{ 16, 252781 }, -- Pattern: Stormrider's Leather Gloves
			},
		},
		{ -- WCTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  10413 }, -- Gloves of the Fang
			},
		},
	},
}

data["TheDeadminesForever"] = {
	MapID = 1581,
	InstanceID = 36,
	SubAreaIDs = { 19444, 19529, 19502, 26104 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "TheDeadmines",
	AtlasMapFile_AL = {"TheDeadmines", "TheDeadminesEnt"},
	AtlasMapFile = {"CL_TheDeadmines", "CL_TheDeadminesEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({10, 17, 26}, {10, 18, 22}),
	items = {
		{	--DMRhahkZor
			name = AL["Rhahk'Zor"],
			npcID = 644,
			Level = 19,
			DisplayIDs = {{14403}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1, 872 },	-- Rockslicer
				{ 3, 5187 },	-- Rhahk'Zor's Hammer
				{ 4, 273289 },	-- Ogre Loincloth
				{ 16, 251362 },	-- Plans: Protector's Gloves
				{ 17, 251364 },	-- Plans: Crusader's Gloves
				{ 18, 253906 },	-- Pattern: Filigreed Flame Gown
			},
		},
		{	--DMMinerJohnson
			name = AL["Miner Johnson"],
			npcID = 3586,
			Level = 19,
			DisplayIDs = {{556}},
			specialType = "rare",
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1, 5443 },	-- Gold-plated Buckler
				{ 3, 5444 },	-- Miner's Cape
			},
		},
		{	--DMSneed
			name = AL["Sneed"],
			npcID = 643,
			Level = 20,
			SubAreaID = 19529,
			DisplayIDs = {{7125}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1, 5194 },	-- Taskmaster Axe
				{ 3, 5195 },	-- Gold-flecked Gloves
				{ 4, 273293 },	-- Bandsaw Wristbands
				{ 16, 273092 },	-- Blueprint: Repair Bot
				{ 17, 251360 },	-- Plans: Veteran's Gloves
				{ 18, 251364 },	-- Plans: Crusader's Gloves
				{ 19, 253902 },	-- Pattern: Filigreed Pristine Gown
			},
		},
		{	--DMSneedsShredder
			name = AL["Sneed's Shredder"],
			npcID = 642,
			Level = 20,
			DisplayIDs = {{1269}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1, 1937 },	-- Buzz Saw
				{ 3, 2169 },	-- Buzzer Blade
				{ 4, 285292 },	-- Dull Sawblade
			},
		},
		{	--DMGilnid
			name = AL["Gilnid"],
			npcID = 1763,
			Level = 20,
			SubAreaID = 19502,
			DisplayIDs = {{7124}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1, 1156 },	-- Lavishly Jeweled Ring
				{ 3, 5199 },	-- Smelting Pants
				{ 4, 273297 },	-- Goblin Hammer
				{ 16, 252777 },	-- Pattern: Brawler's Leather Gloves
				{ 17, 252778 },	-- Pattern: Trapper's Leather Gloves
				{ 18, 252780 },	-- Pattern: Totemic Leather Gloves
				{ 19, 252782 },	-- Pattern: Wisdom's Leather Gloves
				{ 20, 253904 },	-- Pattern: Filigreed Silky Gown
				{ 21, 253906 },	-- Pattern: Filigreed Flame Gown
				{ 22, 273086 },	-- Blueprint: Anvil
			},
		},
		{	--DMMrSmite
			name = AL["Mr. Smite"],
			npcID = 646,
			Level = 20,
			SubAreaID = 26104,
			DisplayIDs = {{2026}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1, 7230 },	-- Smite's Mighty Hammer
				{ 3, 5192 },	-- Thief's Blade
				{ 4, 5196 },	-- Smite's Reaver
				{ 5, 284715 },	-- First Mate Band
				{ 16, 251362 },	-- Plans: Protector's Gloves
				{ 17, 252779 },	-- Pattern: Defender's Leather Gloves
				{ 18, 252780 },	-- Pattern: Totemic Leather Gloves
				{ 19, 252781 },	-- Pattern: Stormrider's Leather Gloves
				{ 20, 252782 },	-- Pattern: Wisdom's Leather Gloves
			},
		},
		{	--DMCaptainGreenskin
			name = AL["Captain Greenskin"],
			npcID = 647,
			Level = 20,
			DisplayIDs = {{7113},{2349},{2347},{5207}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1, 5201 },	-- Emberstone Staff
				{ 3, 10403 },	-- Blackened Defias Belt
				{ 4, 5200 },	-- Impaling Harpoon
			},
		},
		{	--DMVanCleef
			name = AL["Edwin VanCleef"],
			npcID = 639,
			Level = GetForVersion(21,20),
			DisplayIDs = {{2029}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1, 5193 },	-- Cape of the Brotherhood
				{ 2, 5202 },	-- Corsair's Overshirt
				{ 3, 10399 },	-- Blackened Defias Armor
				{ 4, 5191 },	-- Cruel Barb
				{ 6, 2874 },	-- An Unsent Letter
				{ 16, 252799 },	-- Pattern: Trapper's Leather Hood
				{ 17, 252800 },	-- Pattern: Defender's Leather Hood
				{ 18, 252801 },	-- Pattern: Totemic Leather Hood
				{ 19, 252803 },	-- Pattern: Wisdom's Leather Hood
				{ 20, 253938 },	-- Pattern: Filigreed Pristine Leggings
				{ 21, 253948 },	-- Pattern: Filigreed Shining Leggings
			},
		},
		{	--DMCookie
			name = AL["Cookie"],
			npcID = 645,
			Level = 20,
			DisplayIDs = {{1305}},
			specialType = "elite",
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1, 5198 },	-- Cookie's Stirring Rod
				{ 3, 5197 },	-- Cookie's Tenderizer
				{ 4, 273298 },	-- Lookie's Spyglass
				{ 16, 8490 },	-- Cat Carrier (Siamese)
				{ 17, 251360 },	-- Plans: Veteran's Gloves
				{ 18, 252778 },	-- Pattern: Trapper's Leather Gloves
				{ 19, 252779 },	-- Pattern: Defender's Leather Gloves
				{ 20, 253910 },	-- Pattern: Filigreed Pearly Gown
				{ 21, 253912 },	-- Pattern: Filigreed Shining Gown
				{ 22, 273102 },	-- Blueprint: Cookie's Feast
			},
		},
		{	--DMDefiasGunpowder
			name = AL["Defias Gunpowder"],
			ExtraList = true,
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1, 5397 },	-- Defias Gunpowder
			},
		},
		{	--DMTrash
			name = AL["Trash Mobs"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1, 10402 },	-- Blackened Defias Boots
				{ 2, 10401 },	-- Blackened Defias Gloves
				{ 3, 10400 },	-- Blackened Defias Leggings
				{ 4, 1951 },	-- Blackwater Cutlass
				{ 5, 1929 },	-- Silk-threaded Trousers
				{ 6, 1934 },	-- Stonemason Trousers
				{ 7, 1936 },	-- Goblin Screwdriver
				{ 16, 8492 },	-- Parrot Cage (Green Wing Macaw)
			},
		},
		KEYS,
	}
}

data["ShadowfangKeepForever"] = {
	MapID = 209,
	InstanceID = 33,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "ShadowfangKeep",
	AtlasMapFile = "CL_ShadowfangKeep",
	AtlasMapFile_AL = "ShadowfangKeep",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({11, 22, 30}, {14, 18, 21}),
	items = {
		{ -- SFKRethilgore
			name = AL["Rethilgore"],
			npcID = 3914,
			Level = 20,
			DisplayIDs = {{524}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  5254 }, -- Rugged Spaulders
				{ 2,  273457 }, -- Sorcerer Collar
				{ 3,  273456 }, -- Cell Keeper's Claws
			},
		},
		{ -- SFKFelSteed
			name = AL["Fel Steed / Shadow Charger"],
			npcID = {3865, 3864},
			Level = GetForVersion({19, 20}, {18,19}),
			DisplayIDs = {{1952},{1951}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  6341 }, -- Eerie Stable Lantern
				{ 3,  932 }, -- Fel Steed Saddlebags
				{ 16, 251341 }, -- Plans: Guard's Chain Shirt
				{ 17, 251362 }, -- Plans: Protector's Gloves
				{ 18, 251363 }, -- Plans: Acolyte's Gloves
				{ 19, 251364 }, -- Plans: Crusader's Gloves
				{ 20, 251381 }, -- Plans: Guard's Silvered Chain Helm
				{ 21, 251382 }, -- Plans: Protector's Silvered Chain Helm
				{ 22, 252781 }, -- Pattern: Stormrider's Leather Gloves
				{ 23, 252782 }, -- Pattern: Wisdom's Leather Gloves
				{ 24, 252799 }, -- Pattern: Trapper's Leather Hood
				{ 25, 252801 }, -- Pattern: Totemic Leather Hood
				{ 26, 252803 }, -- Pattern: Wisdom's Leather Hood
				{ 27, 253902 }, -- Pattern: Filigreed Pristine Gown
				{ 28, 253904 }, -- Pattern: Filigreed Silky Gown
				{ 29, 253906 }, -- Pattern: Filigreed Flame Gown
				{ 30, 253908 }, -- Pattern: Filigreed Shadow Gown
				{ 101, 253910 }, -- Pattern: Filigreed Pearly Gown
				{ 102, 253912 }, -- Pattern: Filigreed Shining Gown
				{ 103, 253940 }, -- Pattern: Filigreed Silky Leggings
				{ 104, 253946 }, -- Pattern: Filigreed Pearly Leggings
				{ 105, 253948 }, -- Pattern: Filigreed Shining Leggings
			},
		},
		{ -- SFKRazorclawtheButcher
			name = AL["Razorclaw the Butcher"],
			npcID = 3886,
			Level = GetForVersion(22,20),
			DisplayIDs = {{524}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  1292 }, -- Butcher's Cleaver
				{ 3,  6226 }, -- Bloody Apron
				{ 4,  6633 }, -- Butcher's Slicer
			},
		},
		{ -- SFKSilverlaine
			name = AL["Baron Silverlaine"],
			npcID = 3887,
			Level = GetForVersion(24,20),
			DisplayIDs = {{3222}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  6321 }, -- Silverlaine's Family Seal
				{ 3,  6323 }, -- Baron's Scepter
				{ 4,  273637 }, -- Blade of Silverlaine
			},
		},
		{ -- SFKSpringvale
			name = AL["Commander Springvale"],
			npcID = 4278,
			Level = GetForVersion(24,20),
			DisplayIDs = {{3223}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  6320 }, -- Commander's Crest
				{ 2,  6341 }, -- Eerie Stable Lantern
				{ 3,  3191 }, -- Arced War Axe
				{ 4,  273643 }, -- Worgenbane Talisman
				{ 16, 273105 }, -- Blueprint: Toxin Study
			},
		},
		{ -- SFKOdotheBlindwatcher
			name = AL["Odo the Blindwatcher"],
			npcID = 4279,
			Level = GetForVersion(24,21),
			DisplayIDs = {{522}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  6318 }, -- Odo's Ley Staff
				{ 3,  6319 }, -- Girdle of the Blindwatcher
				{ 4,  273645 }, -- Blindwatcher's Sight
			},
		},
		{ -- SFKDeathswornCaptain
			name = AL["Deathsworn Captain"],
			npcID = 3872,
			Level = GetForVersion(25,21),
			DisplayIDs = {{3224}},
			specialType = "rare",
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  6642 }, -- Phantom Armor
				{ 3,  6641 }, -- Haunting Blade
			},
		},
		{ -- SFKArugalsVoidwalker
			name = AL["Arugal's Voidwalker"],
			npcID = 4627,
			Level = GetForVersion({24, 25}, 20),
			DisplayIDs = {{1131}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  5943 }, -- Rift Bracers
			},
		},
		{ -- SFKFenrustheDevourer
			name = AL["Fenrus the Devourer"],
			npcID = 4274,
			Level = GetForVersion(25,21),
			DisplayIDs = {{2352}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  6340 }, -- Fenrus' Hide
				{ 2,  3230 }, -- Black Wolf Bracers
				{ 3,  273646 }, -- Half-Eaten Boots
				{ 16, 251380 }, -- Plans: Veteran's Silvered Chain Helm
			},
		},
		{ -- SFKWolfMasterNandos
			name = AL["Wolf Master Nandos"],
			npcID = 3927,
			Level = GetForVersion(25,21),
			DisplayIDs = {{11179}},
			AtlasMapBossID = 11,
			[NORMAL_DIFF] = {
				{ 1,  3748 }, -- Feline Mantle
				{ 2,  273647 }, -- Worgpelt Leggings
				{ 3,  6314 }, -- Wolfmaster Cape
			},
		},
		{ -- SFKArchmageArugal
			name = AL["Archmage Arugal"],
			npcID = 4275,
			Level = GetForVersion(25,21),
			DisplayIDs = {{2353}},
			AtlasMapBossID = 12,
			[NORMAL_DIFF] = {
				{ 1,  6324 }, -- Robes of Arugal
				{ 2,  6392 }, -- Belt of Arugal
				{ 3,  6220 }, -- Meteor Shard
			},
		},
		{ -- SFKTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  2292 }, -- Necrology Robes
				{ 2,  1489 }, -- Gloomshroud Armor
				{ 3,  1974 }, -- Mindthrust Bracers
				{ 4,  2807 }, -- Guillotine Axe
				{ 5,  1482 }, -- Shadowfang
				{ 6,  1935 }, -- Assassin's Blade
				{ 7,  1483 }, -- Face Smasher
				{ 8,  1318 }, -- Night Reaver
				{ 9,  3194 }, -- Black Malice
				{ 10, 2205 }, -- Duskbringer
				{ 11, 1484 }, -- Witching Stave
			},
		},
		{ -- SFKSever
			name = AL["Sever"],
			npcID = 14682,
			DisplayIDs = {{1061}},
			AtlasMapBossID = 7,
			ContentPhase = 6,
			specialType = "scourgeInvasion",
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  23173 }, -- Abomination Skin Leggings
			},
		},
		{ -- SFKJordansHammer
			name = AL["Jordan's Smithing Hammer"],
			ExtraList = true,
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  6895 }, -- Jordan's Smithing Hammer
			},
		},
		{ -- SFKBookofUr
			name = AL["The Book of Ur"],
			ExtraList = true,
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  6283 }, -- The Book of Ur
			},
		},
	},
}

data["ExcavationSiteWetlands"] = {
	name = AL["Excavation Site: Wetlands"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {26, 26, 31},
	items = {
		{ -- ESWSaltspine
			name = AL["Saltspine"],
			npcID = 260322,
			Level = 28,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273024 }, -- Glinteye Slippers
				{ 2, 273022 }, -- Supple Bellyskin Leggings
				{ 3, 273023 }, -- Saltscale Girdle
			},
		},
		{ -- ESWShadetooth
			name = AL["Shadetooth"],
			npcID = 260325,
			Level = 29,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273025 }, -- Raptorclaw Greaves
				{ 2, 273027 }, -- Raptor's Gaze
				{ 3, 273026 }, -- Garb of Florid Feathers
				{ 16, 273106 }, -- Blueprint: Greenhouse
			},
		},
		{ -- ESWRelicGuardian
			name = AL["Relic Guardian"],
			npcID = 260326,
			Level = 31,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273028 }, -- Reliquary Mantle
				{ 2, 273029 }, -- Golemsight Long Gun
				{ 3, 273030 }, -- Ring of Power Regulation
				{ 16, 270866 }, -- Titan Relic
				{ 17, 273097 }, -- Blueprint: Rock Garden
			},
		},
	}
}

data["BlackfathomDeepsForever"] = {
	MapID = 719,
	InstanceID = 48,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "BlackfathomDeeps",
	AtlasMapFile = {"CL_BlackfathomDeepsA", "CL_BlackfathomDeepsEnt"},
	AtlasMapFile_AL = {"BlackfathomDeeps", "BlackfathomDeepsEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({15, 24, 32}, {19, 22, 24}),
	items = {
		{ -- BFDGhamoora
			name = AL["Ghamoo-ra"],
			npcID = 4887,
			Level = GetForVersion(25,23),
			DisplayIDs = {{5027}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  6907 }, -- Tortoise Armor
				{ 3,  6908 }, -- Ghamoo-ra's Bind
				{ 4,  273839 }, -- Spiked Shell Band
				{ 16, 251382 }, -- Plans: Protector's Silvered Chain Helm
				{ 17, 252801 }, -- Pattern: Totemic Leather Hood
				{ 18, 253940 }, -- Pattern: Filigreed Silky Leggings
				{ 19, 253942 }, -- Pattern: Filigreed Flame Leggings
			},
		},
		{ -- BFDLadySarevess
			name = AL["Lady Sarevess"],
			npcID = 4831,
			Level = GetForVersion(25,23),
			DisplayIDs = {{4979}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  888 }, -- Naga Battle Gloves
				{ 3,  3078 }, -- Naga Heartpiercer
				{ 4,  11121 }, -- Darkwater Talwar
				{ 16, 252798 }, -- Pattern: Brawler's Leather Hood
				{ 17, 251382 }, -- Plans: Protector's Silvered Chain Helm
				{ 18, 251383 }, -- Plans: Acolyte's Silvered Chain Helm
				{ 19, 253944 }, -- Pattern: Filigreed Shadow Leggings
			},
		},
		{ -- BFDGelihast
			name = AL["Gelihast"],
			npcID = 6243,
			Level = GetForVersion(26,24),
			DisplayIDs = {{1773}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  6906 }, -- Algae Fists
				{ 2,  273840 }, -- Cursed Murloc Eye
				{ 3,  6905 }, -- Reef Axe
				{ 5,  1470 }, -- Murloc Skin Bag
				{ 6,  252512 }, -- Brawler's Leather Helm
				{ 7,  252513 }, -- Trapper's Leather Helm
				{ 8,  252456 }, -- Totemic Leather Helm
				{ 9,  252514 }, -- Stormrider's Leather Helm
				{ 10, 252515 }, -- Wisdom's Leather Helm
				{ 16, 251375 }, -- Plans: Veteran's Silvered Chain Leggings
				{ 17, 251377 }, -- Plans: Protector's Silvered Chain Leggings
				{ 18, 252820 }, -- Pattern: Brawler's Leather Legguards
				{ 19, 252821 }, -- Pattern: Trapper's Leather Legguards
				{ 20, 252825 }, -- Pattern: Wisdom's Leather Leggings
				{ 21, 253978 }, -- Pattern: Filigreed Silky Circlet
				{ 22, 253980 }, -- Pattern: Filigreed Flame Circlet
				{ 23, 273141 }, -- Blueprint: Fishing Rack
			},
		},
		{ -- BFDLorgusJett
			name = AL["Lorgus Jett"],
			npcID = 12902,
			Level = 26,
			DisplayIDs = {{12822}},
			[NORMAL_DIFF] = {
				{ 1,  273843 }, -- Fallenroot Longbow
				{ 2,  273841 }, -- Twilight Maul
				{ 3,  273842 }, -- Treacherous Treads
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252513 }, -- Trapper's Leather Helm
				{ 6,  252455 }, -- Defender's Leather Helm
				{ 16, 253978 }, -- Pattern: Filigreed Silky Circlet
				{ 17, 253982 }, -- Pattern: Filigreed Shadow Circlet
				{ 18, 251377 }, -- Plans: Protector's Silvered Chain Leggings
			},
		},
		{ -- BFDTwilightLordKelris
			name = AL["Twilight Lord Kelris"],
			npcID = 4832,
			Level = GetForVersion(27,24),
			DisplayIDs = {{4939}},
			AtlasMapFile = {"CL_BlackfathomDeepsB", "CL_BlackfathomDeepsEnt"},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  1155 }, -- Rod of the Sleepwalker
				{ 3,  6903 }, -- Gaze Dreamer Pants
				{ 4,  273846 }, -- Twilight Lord Girdle
				{ 5,  252513 }, -- Trapper's Leather Helm
				{ 6,  252455 }, -- Defender's Leather Helm
				{ 7,  252456 }, -- Totemic Leather Helm
				{ 8,  252515 }, -- Wisdom's Leather Helm
				{ 16, 252820 }, -- Pattern: Brawler's Leather Legguards
				{ 17, 252821 }, -- Pattern: Trapper's Leather Legguards
				{ 18, 252822 }, -- Pattern: Defender's Leather Kilt
				{ 19, 252823 }, -- Pattern: Totemic Leather Leggings
				{ 20, 252825 }, -- Pattern: Wisdom's Leather Leggings
				{ 21, 253982 }, -- Pattern: Filigreed Shadow Circlet
			},
		},
		{ -- BFDOldSerrakis
			name = AL["Old Serra'kis"],
			npcID = 4830,
			Level = GetForVersion(26,24),
			DisplayIDs = {{1816}},
			AtlasMapFile = {"CL_BlackfathomDeepsC", "CL_BlackfathomDeepsEnt"},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  6901 }, -- Glowing Thresher Cape
				{ 2,  6904 }, -- Bite of Serra'kis
				{ 4,  6902 }, -- Bands of Serra'kis
				{ 5,  252455 }, -- Defender's Leather Helm
				{ 6,  252456 }, -- Totemic Leather Helm
				{ 16, 251375 }, -- Plans: Veteran's Silvered Chain Leggings
				{ 17, 252825 }, -- Pattern: Wisdom's Leather Leggings
				{ 18, 253978 }, -- Pattern: Filigreed Silky Circlet
				{ 19, 253982 }, -- Pattern: Filigreed Shadow Circlet
			},
		},
		{ -- BFDAkumai
			name = AL["Aku'mai"],
			npcID = 4829,
			Level = GetForVersion(28,24),
			DisplayIDs = {{2837}},
			AtlasMapBossID = 10,
			AtlasMapFile = {"CL_BlackfathomDeepsB", "CL_BlackfathomDeepsEnt"},
			[NORMAL_DIFF] = {
				{ 1,  6911 }, -- Moss Cinch
				{ 2,  6910 }, -- Leech Pants
				{ 3,  6909 }, -- Strike of the Hydra
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252455 }, -- Defender's Leather Helm
				{ 6,  252456 }, -- Totemic Leather Helm
				{ 7,  252514 }, -- Stormrider's Leather Helm
				{ 8,  252515 }, -- Wisdom's Leather Helm
				{ 16, 251376 }, -- Plans: Guard's Silvered Chain Leggings
				{ 17, 251377 }, -- Plans: Protector's Silvered Chain Leggings
				{ 18, 251378 }, -- Plans: Acolyte's Silvered Chain Leggings
				{ 19, 252821 }, -- Pattern: Trapper's Leather Legguards
				{ 20, 252824 }, -- Pattern: Stormrider's Leather Kilt
				{ 21, 253980 }, -- Pattern: Filigreed Flame Circlet
				{ 22, 253984 }, -- Pattern: Filigreed Pearly Circlet
			},
		},
		{ -- BFDTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  1486 }, -- Tree Bark Jacket
				{ 2,  3416 }, -- Martyr's Chain
				{ 3,  1491 }, -- Ring of Precision
				{ 4,  3414 }, -- Crested Scepter
				{ 5,  1454 }, -- Axe of the Enforcer
				{ 6,  1481 }, -- Grimclaw
				{ 7,  2567 }, -- Evocator's Blade
				{ 8,  3413 }, -- Doomspike
				{ 9,  3417 }, -- Onyx Claymore
				{ 10, 3415 }, -- Staff of the Friar
				{ 11, 2271 }, -- Staff of the Blessed Seer
				{ 12, 2034 }, -- Scholarly Robes
			},
		},
	},
}

data["TheStockadeForever"] = {
	MapID = 717,
	InstanceID = 34,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "TheStockade",
	AtlasMapFile = "CL_TheStockade",
	AtlasMapFile_AL = "TheStockade",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({15, 24, 32}, {15, 23, 29}),
	items = {
		{ -- SWStTargorr
			name = AL["Targorr the Dread"],
			npcID = 1696,
			Level = 24,
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  273805 }, -- Blackrock Harness
				{ 2,  273804 }, -- Executioner Mantle
				{ 3,  273806 }, -- Dark Horde Band
				{ 16, 251380 }, -- Plans: Veteran's Silvered Chain Helm
				{ 17, 251382 }, -- Plans: Protector's Silvered Chain Helm
				{ 18, 253942 }, -- Pattern: Filigreed Flame Leggings
			},
		},
		{ -- SWStKamDeepfury
			name = AL["Kam Deepfury"],
			npcID = 1666,
			Level = GetForVersion(27, 25),
			DisplayIDs = {{825}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  2280 }, -- Kam's Walking Stick
				{ 2,  273808 }, -- Bridgebreaker Bindings
				{ 3,  273807 }, -- Demolition Girdle
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252513 }, -- Trapper's Leather Helm
				{ 6,  252455 }, -- Defender's Leather Helm
				{ 7,  252515 }, -- Wisdom's Leather Helm
				{ 16, 251379 }, -- Plans: Crusader's Silvered Chain Leggings
				{ 17, 252825 }, -- Pattern: Wisdom's Leather Leggings
			},
		},
		{ -- SWStHamhock
			name = AL["Hamhock"],
			npcID = 1717,
			Level = 28,
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  273809 }, -- Hamhock's Cleaver
				{ 2,  273810 }, -- Ogre Grips
				{ 3,  273811 }, -- Repurposed Rack
				{ 4,  252513 }, -- Trapper's Leather Helm
				{ 16, 251377 }, -- Plans: Protector's Silvered Chain Leggings
			},
		},
		{ -- SWStBazilThredd
			name = AL["Bazil Thredd"],
			npcID = 1716,
			Level = 29,
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  273827 }, -- Debt Collector
				{ 2,  273824 }, -- Defias Jailbreakers
				{ 3,  273825 }, -- Red Wool Cloak
				{ 4,  273829 }, -- Concealed Hand Crossbow
				{ 5,  252455 }, -- Defender's Leather Helm
				{ 6,  252456 }, -- Totemic Leather Helm
				{ 7,  252515 }, -- Wisdom's Leather Helm
				{ 16, 252824 }, -- Pattern: Stormrider's Leather Kilt
				{ 17, 253976 }, -- Pattern: Filigreed Pristine Circlet
				{ 18, 253986 }, -- Pattern: Filigreed Shining Circlet
			},
		},
		{ -- SWStDextrenWard
			name = AL["Dextren Ward"],
			npcID = 1663,
			Level = 26,
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  273820 }, -- Nightskulker Ring
				{ 2,  273817 }, -- Graverobber's Shovel
				{ 3,  273819 }, -- Boneslicer
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252456 }, -- Totemic Leather Helm
				{ 6,  252514 }, -- Stormrider's Leather Helm
				{ 7,  252515 }, -- Wisdom's Leather Helm
				{ 16, 251375 }, -- Plans: Veteran's Silvered Chain Leggings
				{ 17, 251376 }, -- Plans: Guard's Silvered Chain Leggings
				{ 18, 252820 }, -- Pattern: Brawler's Leather Legguards
				{ 19, 252821 }, -- Pattern: Trapper's Leather Legguards
			},
		},
		{ -- SWStBruegalIronknuckle
			name = AL["Bruegal Ironknuckle"],
			npcID = 1720,
			Level = GetForVersion(26, 25),
			DisplayIDs = {{2142}},
			AtlasMapBossID = 6,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  3228 }, -- Jimmied Handcuffs
				{ 2,  2941 }, -- Prison Shank
				{ 3,  2942 }, -- Iron Knuckles
			},
		},
		{ -- SWStTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  1076 }, -- Defias Renegade Ring
				{ 2,  274092 }, -- Sharpened Cutlery
			},
		},
	},
}

data["ScarletMonasteryGraveyardForever"] = {
	MapID = 796,
	InstanceID = 189,
	SubAreaIDs = { 21379, 24000, 23805 },
	name = C_Map_GetAreaInfo(796) .." - ".. AL["Graveyard"],
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "ScarletMonastery",
	AtlasMapFile = {"CL_SMGraveyard", "CL_ScarletMonasteryEnt"},
	AtlasMapFile_AL = {"SMGraveyard", "SMEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({20, 26, 36},{20, 30, 32}),
	items = {
		-- Graveyard
		{ -- SMVishas
			name = AL["Interrogator Vishas"],
			npcID = 3983,
			Level = 32,
			DisplayIDs = {{2044}},
			SubAreaID = 21379,
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  7682 }, -- Torturing Poker
				{ 3,  7683 }, -- Bloody Brass Knuckles
				{ 4,  274290 }, -- Painwalker Buckler
				{ 5,  252513 }, -- Trapper's Leather Helm
				{ 6,  252455 }, -- Defender's Leather Helm
			},
		},
		{ -- SMAzshir
			name = AL["Azshir the Sleepless"],
			npcID = 6490,
			Level = GetForVersion(33,32),
			DisplayIDs = {{5534}},
			SubAreaID = 24000,
			AtlasMapBossID = "1'",
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  7709 }, -- Blighted Leggings
				{ 2,  7708 }, -- Necrotic Wand
				{ 3,  7731 }, -- Ghostshard Talisman
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252456 }, -- Totemic Leather Helm
			},
		},
		{ -- SMFallenChampion
			name = AL["Fallen Champion"],
			npcID = 6488,
			Level = GetForVersion(33,32),
			DisplayIDs = {{5230}},
			specialType = "rare",
			AtlasMapBossID = "1'",
			[NORMAL_DIFF] = {
				{ 1,  7691 }, -- Embalmed Shroud
				{ 2,  7690 }, -- Ebon Vise
				{ 3,  7689 }, -- Morbid Dawn
				{ 4,  252513 }, -- Trapper's Leather Helm
			},
		},
		{ -- SMIronspine
			name = AL["Ironspine"],
			npcID = 6489,
			Level = GetForVersion(33,32),
			DisplayIDs = {{5231}},
			AtlasMapBossID = "1'",
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  7688 }, -- Ironspine's Ribcage
				{ 2,  7687 }, -- Ironspine's Fist
				{ 3,  7686 }, -- Ironspine's Eye
			},
		},
		{ -- SMBloodmageThalnos
			name = AL["Bloodmage Thalnos"],
			npcID = 4543,
			Level = GetForVersion(33,32),
			SubAreaID = 23805,
			DisplayIDs = {{11396}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  7685 }, -- Orb of the Forgotten Seer
				{ 3,  7684 }, -- Bloodmage Mantle
				{ 4,  274291 }, -- Polished Skullcap
				{ 5,  252513 }, -- Trapper's Leather Helm
				{ 6,  252455 }, -- Defender's Leather Helm
				{ 16, 252822 }, -- Pattern: Defender's Leather Kilt
			},
		},
		{ -- SMGTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  5819 }, -- Sunblaze Coif
				{ 2,  7727 }, -- Watchman Pauldrons
				{ 3,  7728 }, -- Beguiler Robes
				{ 4,  7754 }, -- Harbinger Boots
				{ 5,  2262 }, -- Mark of Kern
				{ 6,  7787 }, -- Resplendent Guardian
				{ 7,  7729 }, -- Chesterfall Musket
				{ 8,  7761 }, -- Steelclaw Reaver
				{ 9,  7752 }, -- Dreamslayer
				{ 10, 8226 }, -- The Butcher
				{ 11, 7786 }, -- Headsplitter
				{ 12, 7753 }, -- Bloodspiller
				{ 13, 7730 }, -- Cobalt Crusher
				{ 16, 10328 }, -- Scarlet Chestpiece
				{ 17, 10329 }, -- Scarlet Belt
				{ 18, 10330 }, -- Scarlet Leggings
				{ 19, 10331 }, -- Scarlet Gauntlets
				{ 20, 10333 }, -- Scarlet Wristguards
				{ 21, 10332 }, -- Scarlet Boots
			},
		},
		{ -- SMScorn
			name = AL["Scorn"],
			npcID = 14693,
			DisplayIDs = {{16197}},
			AtlasMapBossID = 1,
			ContentPhase = 6,
			specialType = "scourgeInvasion",
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1, 23169 }, -- Scorn's Icy Choker
			},
		},
		KEYS,
	},
}

data["CityOfDalaran"] = {
	name = AL["City of Dalaran"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {28, 28, 33},
	items = {
		{ -- CoDAtrexis
			name = AL["Atrexis the Grave Knight"],
			npcID = 247126,
			Level = 29,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273036 }, -- Graveweave Bindings
				{ 2, 273032 }, -- Bonebinder's Signet
				{ 3, 273033 }, -- Gravespike Repeater
			},
		},
		{ -- CoDArcaneAnomaly
			name = AL["Arcane Anomaly"],
			npcID = 245999,
			Level = 30,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273034 }, -- Ephemeral Grips
				{ 2, 273035 }, -- Mana-Warped Chain Shirt
				{ 3, 273031 }, -- Runemender's Seal
			},
		},
		{ -- CoDFelAncient
			name = AL["Fel Ancient"],
			npcID = 246003,
			Level = 32,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273039 }, -- Blightleaf Rope
				{ 2, 273038 }, -- Garb of Fallen Felbark
				{ 3, 273037 }, -- Felbough Arm
			},
		},
		{ -- CoDUnstableSentinel
			name = AL["Unstable Sentinel"],
			npcID = 246017,
			Level = 31,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273047 }, -- Unstable Crystalline Shoulderpads
				{ 2, 273048 }, -- Refractory Scaleguards
				{ 3, 273046 }, -- Guardian's Dualblade
				{ 16, 273099 }, -- Blueprint: Spinning Wheel
			},
		},
		{ -- CoDManaDevourer
			name = AL["Mana Devourer"],
			npcID = 246008,
			Level = 31,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273041 }, -- Slitherwrap Girdle
				{ 2, 273042 }, -- Manascale Treads
				{ 3, 273040 }, -- Spine of the Devourer
			},
		},
		{ -- CoDArcanicEnigma
			name = AL["Arcanic Enigma"],
			npcID = 246016,
			Level = 30,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273044 }, -- Violet Sorcerer's Robes
				{ 2, 273045 }, -- Drape of Shifting Energy
				{ 3, 273043 }, -- Wand of Mana Concentration
			},
		},
		{ -- CoDLynTheIgnored
			name = AL["Lyn the Ignored"],
			npcID = 247032,
			specialType = "rare",
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273054 }, -- Cartilage Shapers
				{ 2, 273053 }, -- Tendonscraper Dagger
				{ 3, 273055 }, -- Bonepile Gaze
			},
		},
		{ -- CoDShadeOfTheArchmage
			name = AL["Shade of the Archmage"],
			npcID = 246020,
			Level = 33,
			-- TODO: DisplayIDs, AtlasMapBossID once known
			[NORMAL_DIFF] = {
				{ 1, 273051 }, -- Violet Sorcerer's Mantle
				{ 2, 273049 }, -- Archmagister's Faceted Pendant
				{ 3, 273052 }, -- Ponderous Orb
				{ 16, 273103 }, -- Blueprint: Arcane Salvager
			},
		},
	}
}

data["RazorfenKraulForever"] = {
	MapID = 491,
	InstanceID = 47,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "RazorfenKraul",
	AtlasMapFile = "CL_RazorfenKraul",
	AtlasMapFile_AL = "RazorfenKraul",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({25, 29, 38},{17, 24, 27}),
	items = {
		{ -- RFKRoogug
			name = AL["Roogug"],
			npcID = 6168,
			Level = 28,
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  274155 }, -- Geomancer Headdress
				{ 2,  274152 }, -- Roogug's Severed Head
				{ 3,  274149 }, -- Thornweaver Drape
				{ 4,  252512 }, -- Brawler's Leather Helm
			},
		},
		{ -- RFKAggem
			name = AL["Aggem Thorncurse"],
			npcID = 4424,
			Level = GetForVersion(30,26),
			DisplayIDs = {{6097}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  6681 }, -- Thornspike
				{ 2,  274158 }, -- Death Prophet Spine
				{ 3,  274159 }, -- Thorncursed Grips
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252455 }, -- Defender's Leather Helm
				{ 16, 252820 }, -- Pattern: Brawler's Leather Legguards
			},
		},
		{ -- RFKDeathSpeakerJargba
			name = AL["Death Speaker Jargba"],
			npcID = 4428,
			Level = GetForVersion(30,27),
			DisplayIDs = {{4644}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  2816 }, -- Death Speaker Scepter
				{ 3,  6685 }, -- Death Speaker Mantle
				{ 4,  6682 }, -- Death Speaker Robes
				{ 5,  252512 }, -- Brawler's Leather Helm
				{ 6,  252515 }, -- Wisdom's Leather Helm
			},
		},
		{ -- RFKOverlordRamtusk
			name = AL["Overlord Ramtusk"],
			npcID = 4420,
			Level = GetForVersion(32,27),
			DisplayIDs = {{4652}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  6687 }, -- Corpsemaker
				{ 3,  6686 }, -- Tusken Helm
				{ 4,  274161 }, -- Quillord Mail Leggings
				{ 5,  252512 }, -- Brawler's Leather Helm
				{ 6,  252513 }, -- Trapper's Leather Helm
				{ 7,  252515 }, -- Wisdom's Leather Helm
				{ 16, 251379 }, -- Plans: Crusader's Silvered Chain Leggings
				{ 17, 252821 }, -- Pattern: Trapper's Leather Legguards
			},
		},
		{ -- RFKRazorfenSpearhide
			name = AL["Razorfen Spearhide"],
			npcID = 4438,
			Level = GetForVersion({29, 30},27),
			DisplayIDs = {{6078}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  6679 }, -- Armor Piercer
			},
		},
		{ -- RFKAgathelos
			name = AL["Agathelos the Raging"],
			npcID = 4422,
			Level = GetForVersion(33,27),
			DisplayIDs = {{2450}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  6691 }, -- Swinetusk Shank
				{ 3,  6690 }, -- Ferine Leggings
				{ 4,  274160 }, -- Quilrager Throwing Axe
				{ 5,  252512 }, -- Brawler's Leather Helm
				{ 6,  252513 }, -- Trapper's Leather Helm
				{ 7,  252455 }, -- Defender's Leather Helm
				{ 16, 251378 }, -- Plans: Acolyte's Silvered Chain Leggings
			},
		},
		{ -- RFKBlindHunter
			name = AL["Blind Hunter"],
			npcID = 4425,
			Level = GetForVersion(32,27),
			DisplayIDs = {{4735}},
			AtlasMapBossID = 6,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  6695 }, -- Stygian Bone Amulet
				{ 2,  6697 }, -- Batwing Mantle
				{ 3,  6696 }, -- Nightstalker Bow
			},
		},
		{ -- RFKCharlgaRazorflank
			name = AL["Charlga Razorflank"],
			npcID = 4421,
			Level = GetForVersion(33,27),
			DisplayIDs = {{4642}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  6693 }, -- Agamaggan's Clutch
				{ 2,  6694 }, -- Heart of Agamaggan
				{ 3,  6692 }, -- Pronged Reaver
				{ 4,  252512 }, -- Brawler's Leather Helm
				{ 5,  252455 }, -- Defender's Leather Helm
				{ 6,  252456 }, -- Totemic Leather Helm
				{ 7,  252515 }, -- Wisdom's Leather Helm
				{ 16,  17008 }, -- Small Scroll
				{ 17, 273103 }, -- Blueprint: Arcane Salvager
			},
		},
		{ -- RFKEarthcallerHalmgar
			name = AL["Earthcaller Halmgar"],
			npcID = 4842,
			Level = GetForVersion(32,27),
			DisplayIDs = {{6102}},
			AtlasMapBossID = 9,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  6689 }, -- Wind Spirit Staff
				{ 3,  6688 }, -- Whisperwind Headdress
				{ 4,  252455 }, -- Defender's Leather Helm
				{ 5,  252514 }, -- Stormrider's Leather Helm
			},
		},
		{ -- RFKTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  2264 }, -- Mantle of Thieves
				{ 2,  1488 }, -- Avenger's Armor
				{ 3,  4438 }, -- Pugilist Bracers
				{ 4,  1978 }, -- Wolfclaw Gloves
				{ 5,  2039 }, -- Plains Ring
				{ 6,  1727 }, -- Sword of Decay
				{ 7,  776 }, -- Vendetta
				{ 8,  1976 }, -- Slaghammer
				{ 9,  1975 }, -- Pysan's Old Greatsword
				{ 10, 2549 }, -- Staff of the Shade
			},
		},
	},
}

data["GnomereganForever"] = {
	MapID = 721,
	InstanceID = 90,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Gnomeregan",
	AtlasMapFile = {"CL_Gnomeregan", "CL_GnomereganEnt"},
	AtlasMapFile_AL = {"Gnomeregan", "GnomereganEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({19, 29, 38},{15, 25, 28}),
	items = {
		{ -- GnTechbot
			name = AL["Techbot"],
			npcID = 6231,
			Level = 26,
			DisplayIDs = {{7288}},
			[NORMAL_DIFF] = {
				{ 1,  9444 }, -- Techbot CPU Shell
			},
		},
		{ -- GnGrubbis
			name = AL["Grubbis"],
			npcID = 7361,
			Level = GetForVersion(32,28),
			DisplayIDs = {{6533}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  9445 }, -- Grubbis Paws
				{ 2,  274042 }, -- Skullduggery Belt
				{ 3,  274043 }, -- Irradiated Shield
			},
		},
		{ -- GnViscousFallout
			name = AL["Viscous Fallout"],
			npcID = 7079,
			Level = GetForVersion(30,28),
			DisplayIDs = {{5497}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  9454 }, -- Acidic Walkers
				{ 2,  9453 }, -- Toxic Revenger
				{ 3,  9452 }, -- Hydrocane
			},
		},
		{ -- GnElectrocutioner6000
			name = AL["Electrocutioner 6000"],
			npcID = 6235,
			Level = GetForVersion(32,28),
			DisplayIDs = {{6915}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  9447 }, -- Electrocutioner Lagnut
				{ 2,  9446 }, -- Electrocutioner Leg
				{ 4,  9448 }, -- Spidertank Oilrag
				{ 6,  6893 }, -- Workshop Key
			},
		},
		{ -- GnCrowdPummeler960
			name = AL["Crowd Pummeler 9-60"],
			npcID = 6229,
			Level = GetForVersion(32,28),
			DisplayIDs = {{6774}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  9449 }, -- Manual Crowd Pummeler
				{ 3,  9450 }, -- Gnomebot Operating Boots
				{ 4,  274068 }, -- Thermaplugg Medal of Honor
				{ 16, 274049 }, -- Schematic: 9-60 Battery Pack
			},
		},
		{ -- GnDIAmbassador
			name = AL["Dark Iron Ambassador"],
			npcID = 6228,
			Level = GetForVersion(33,28),
			DisplayIDs = {{6669}},
			AtlasMapBossID = 7,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  9455 }, -- Emissary Cuffs
				{ 2,  9456 }, -- Glass Shooter
				{ 3,  9457 }, -- Royal Diplomatic Scepter
			},
		},
		{ -- GnMekgineerThermaplugg
			name = AL["Mekgineer Thermaplugg"],
			npcID = 7800,
			Level = GetForVersion(34,28),
			DisplayIDs = {{6980}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  9492 }, -- Electromagnetic Gigaflux Reactivator
				{ 2,  9461 }, -- Charged Gear
				{ 3,  9458 }, -- Thermaplugg's Central Core
				{ 4,  9459 }, -- Thermaplugg's Left Arm
				{ 16, 4415 }, -- Schematic: Craftsman's Monocle
				--{ 17, 4393 }, -- Craftsman's Monocle
				{ 17, 4413 }, -- Schematic: Discombobulator Ray
				--{ 20, 4388 }, -- Discombobulator Ray
				{ 18, 4411 }, -- Schematic: Flame Deflector
				--{ 23, 4376 }, -- Flame Deflector
				{ 19, 7742 }, -- Schematic: Gnomish Cloaking Device
				--{ 26, 4397 }, -- Gnomish Cloaking Device
			},
		},
		{ -- GnTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  9508 }, -- Mechbuilder's Overalls
				{ 2,  9491 }, -- Hotshot Pilot's Gloves
				{ 3,  9509 }, -- Petrolspill Leggings
				{ 4,  9510 }, -- Caverndeep Trudgers
				{ 5,  9487 }, -- Hi-tech Supergun
				{ 6,  9485 }, -- Vibroblade
				{ 7,  9488 }, -- Oscillating Power Hammer
				{ 8,  9486 }, -- Supercharger Battle Axe
				{ 9,  9490 }, -- Gizmotron Megachopper
				{ 11, 9489 }, -- Gyromatic Icemaker
				{ 16, 9327 }, -- Security DELTA Data Access Card
				{ 18, 7191 }, -- Fused Wiring
				{ 19, 9308 }, -- Grime-Encrusted Object
				{ 20, 9326 }, -- Grime-Encrusted Ring
				{ 22, 9279 }, -- White Punch Card
			},
		},

	},
}

data["ScarletMonasteryLibraryForever"] = {
	MapID = 796,
	InstanceID = 189,
	SubAreaIDs = { 21426, 21444, 21420 },
	name = C_Map_GetAreaInfo(796) .." - ".. AL["Library"],
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "ScarletMonastery",
	AtlasMapFile = {"CL_SMLibrary", "CL_ScarletMonasteryEnt"},
	AtlasMapFile_AL = {"SMLibrary", "SMEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({20, 29, 39},{20, 33, 35}),
	items = {
		-- Library
		{ -- SMHoundmasterLoksey
			name = AL["Houndmaster Loksey"],
			npcID = 3974,
			Level = 34,
			SubAreaID = 21444,
			DisplayIDs = {{2040}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  7710 }, -- Loksey's Training Stick
				{ 3,  7756 }, -- Dog Training Gloves
				{ 4,  3456 }, -- Dog Whistle
			},
		},
		{ -- SMDoan
			name = AL["Arcanist Doan"],
			npcID = 6487,
			Level = GetForVersion(37,34),
			SubAreaID = 21420,
			DisplayIDs = {{5266}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  7714 }, -- Hypnotic Blade
				{ 2,  7713 }, -- Illusionary Rod
				{ 4,  7712 }, -- Mantle of Doan
				{ 5,  7711 }, -- Robe of Doan
				{ 7,  274293 }, -- Spellsever Crossbow
				{ 8,  274294 }, -- Library Walkers
			},
		},
		{ -- SMLTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  5819 }, -- Sunblaze Coif
				{ 2,  7755 }, -- Flintrock Shoulders
				{ 3,  7727 }, -- Watchman Pauldrons
				{ 4,  7728 }, -- Beguiler Robes
				{ 5,  7759 }, -- Archon Chestpiece
				{ 6,  7760 }, -- Warchief Kilt
				{ 7,  7754 }, -- Harbinger Boots
				{ 8,  10332 }, -- Scarlet Boots
				{ 9,  1992 }, -- Swampchill Fetish
				{ 10, 2262 }, -- Mark of Kern
				{ 11, 7787 }, -- Resplendent Guardian
				{ 12, 7729 }, -- Chesterfall Musket
				{ 13, 7761 }, -- Steelclaw Reaver
				{ 14, 7752 }, -- Dreamslayer
				{ 15, 8226 }, -- The Butcher
				{ 16, 7786 }, -- Headsplitter
				{ 17, 5756 }, -- Sliverblade
				{ 18, 7736 }, -- Fight Club
				{ 19, 8225 }, -- Tainted Pierce
				{ 20, 7753 }, -- Bloodspiller
				{ 21, 7730 }, -- Cobalt Crusher
				{ 23, 7757 }, -- Windweaver Staff
			},
		},
		{
			name = AL["Doan's Strongbox"],
			ExtraList = true,
			AtlasMapBossID = "1'",
			[NORMAL_DIFF] = {
				{ 1,  7146 }, -- The Scarlet Key
			},
		},
		KEYS,
	},
}

data["ScarletMonasteryArmoryForever"] = {
	MapID = 796,
	InstanceID = 189,
	SubAreaIDs = { 21460, 21455, 21448, 21457 },
	name = C_Map_GetAreaInfo(796) .." - ".. AL["Armory"],
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "ScarletMonastery",
	AtlasMapFile = {"CL_SMArmory", "CL_ScarletMonasteryEnt"},
	AtlasMapFile_AL = {"SMArmory", "SMEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({20, 32, 42},{20, 35, 37}),
	items = {
		-- Armory
		{ -- SMHerod
			name = AL["Herod"],
			npcID = 3975,
			Level = GetForVersion(40,37),
			SubAreaID = 21448,
			DisplayIDs = {{2041}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  7719 }, -- Raging Berserker's Helm
				{ 2,  7718 }, -- Herod's Shoulder
				{ 3,  10330 }, -- Scarlet Leggings
				{ 4,  7717 }, -- Ravager
			},
		},
		{ -- SMATrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  5819 }, -- Sunblaze Coif
				{ 2,  7755 }, -- Flintrock Shoulders
				{ 3,  7727 }, -- Watchman Pauldrons
				{ 4,  7728 }, -- Beguiler Robes
				{ 5,  7759 }, -- Archon Chestpiece
				{ 6,  7754 }, -- Harbinger Boots
				{ 7,  10332 }, -- Scarlet Boots
				{ 8,  1992 }, -- Swampchill Fetish
				{ 9,  2262 }, -- Mark of Kern
				{ 10, 7787 }, -- Resplendent Guardian
				{ 11, 7729 }, -- Chesterfall Musket
				{ 12, 7761 }, -- Steelclaw Reaver
				{ 13, 7752 }, -- Dreamslayer
				{ 14, 8226 }, -- The Butcher
				{ 15, 7786 }, -- Headsplitter
				{ 16, 5756 }, -- Sliverblade
				{ 17, 7736 }, -- Fight Club
				{ 18, 8225 }, -- Tainted Pierce
				{ 19, 7753 }, -- Bloodspiller
				{ 20, 7730 }, -- Cobalt Crusher
				{ 21, 7757 }, -- Windweaver Staff
				{ 23, 10333 }, -- Scarlet Wristguards
				{ 24, 10329 }, -- Scarlet Belt
				{ 26, 23192 }, -- Tabard of the Scarlet Crusade
			},
		},
		KEYS,
	},
}

data["TheDrownedCity"] = {
	name = AL["The Drowned City"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {35, 35, 40},
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["ScarletMonasteryCathedralForever"] = {
	MapID = 796,
	InstanceID = 189,
	SubAreaIDs = { 21401, 21410 },
	name = C_Map_GetAreaInfo(796) .." - ".. AL["Cathedral"],
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "ScarletMonastery",
	AtlasMapFile = {"CL_SMCathedral", "CL_ScarletMonasteryEnt"},
	AtlasMapFile_AL = {"SMCathedral", "SMEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({20, 35, 45},{20, 36, 40}),
	items = {
		-- Cathedral
		{ -- SMFairbanks
			name = AL["High Inquisitor Fairbanks"],
			npcID = 4542,
			Level = 40,
			DisplayIDs = {{2605}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  19507 }, -- Inquisitor's Shawl
				{ 2,  19508 }, -- Branded Leather Bracers
				{ 3,  19509 }, -- Dusty Mail Boots
			},
		},
		{ -- SMMograine
			name = AL["Scarlet Commander Mograine"],
			npcID = 3976,
			Level = GetForVersion(42,40),
			DisplayIDs = {{2042}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  7724 }, -- Gauntlets of Divinity
				{ 2,  10330 }, -- Scarlet Leggings
				{ 3,  7726 }, -- Aegis of the Scarlet Commander
				{ 4,  7723 }, -- Mograine's Might
			},
		},
		{ -- SMWhitemane
			name = AL["High Inquisitor Whitemane"],
			npcID = 3977,
			Level = GetForVersion(42,40),
			DisplayIDs = {{2043}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  7720 }, -- Whitemane's Chapeau
				{ 2,  7722 }, -- Triune Amulet
				{ 3,  7721 }, -- Hand of Righteousness
			},
		},
		{ -- SMCTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  5819 }, -- Sunblaze Coif
				{ 2,  7755 }, -- Flintrock Shoulders
				{ 3,  7727 }, -- Watchman Pauldrons
				{ 4,  7728 }, -- Beguiler Robes
				{ 5,  7759 }, -- Archon Chestpiece
				{ 6,  7760 }, -- Warchief Kilt
				{ 7,  7754 }, -- Harbinger Boots
				{ 8,  10332 }, -- Scarlet Boots
				{ 9,  1992 }, -- Swampchill Fetish
				{ 10, 2262 }, -- Mark of Kern
				{ 11, 7787 }, -- Resplendent Guardian
				{ 12, 7729 }, -- Chesterfall Musket
				{ 13, 7761 }, -- Steelclaw Reaver
				{ 14, 7752 }, -- Dreamslayer
				{ 15, 8226 }, -- The Butcher
				{ 16, 7786 }, -- Headsplitter
				{ 17, 5756 }, -- Sliverblade
				{ 18, 7736 }, -- Fight Club
				{ 19, 8225 }, -- Tainted Pierce
				{ 20, 7753 }, -- Bloodspiller
				{ 21, 7730 }, -- Cobalt Crusher
				{ 23, 7757 }, -- Windweaver Staff
				{ 25, 10328 }, -- Scarlet Chestpiece
				{ 26, 10331 }, -- Scarlet Gauntlets
				{ 27, 10329 }, -- Scarlet Belt
			},
		},
		KEYS,
	},
}

data["RazorfenDownsForever"] = {
	MapID = 722,
	InstanceID = 129,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "RazorfenDowns",
	AtlasMapFile = "CL_RazorfenDowns",
	AtlasMapFile_AL = "RazorfenDowns",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({35, 37, 46},{25, 34, 37}),
	items = {
		{ -- RFDTutenkash
			name = AL["Tuten'kash"],
			npcID = 7355,
			Level = GetForVersion(40,37),
			DisplayIDs = {{7845}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  10776 }, -- Silky Spider Cape
				{ 2,  10775 }, -- Carapace of Tuten'kash
				{ 3,  10777 }, -- Arachnid Gloves
			},
		},
		{ -- RFDMordreshFireEye
			name = AL["Mordresh Fire Eye"],
			npcID = 7357,
			Level = GetForVersion(39,37),
			DisplayIDs = {{8055}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  10769 }, -- Glowing Eye of Mordresh
				{ 2,  10771 }, -- Deathmage Sash
				{ 3,  10770 }, -- Mordresh's Lifeless Skull
			},
		},
		{ -- RFDGlutton
			name = AL["Glutton"],
			npcID = 8567,
			Level = GetForVersion(40,37),
			DisplayIDs = {{7864}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  10774 }, -- Fleshhide Shoulders
				{ 3,  10772 }, -- Glutton's Cleaver
			},
		},
		{ -- RFDRagglesnout
			name = AL["Ragglesnout"],
			npcID = 7354,
			Level = GetForVersion(40,37),
			DisplayIDs = {{11382}},
			AtlasMapBossID = 5,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  10768 }, -- Boar Champion's Belt
				{ 2,  10767 }, -- Savage Boar's Guard
				{ 3,  10758 }, -- X'caliboar
			},
		},
		{ -- RFDAmnennar
			name = AL["Amnennar the Coldbringer"],
			npcID = 7358,
			Level = GetForVersion(41,37),
			DisplayIDs = {{7971}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  10763 }, -- Icemetal Barbute
				{ 2,  10762 }, -- Robes of the Lich
				{ 3,  10764 }, -- Deathchill Armor
				{ 4,  10761 }, -- Coldrage Dagger
				{ 6,  10765 }, -- Bonefingers
			},
		},
		{ -- RFDPlaguemaw
			name = AL["Plaguemaw the Rotting"],
			npcID = 7356,
			Level = GetForVersion(40,37),
			DisplayIDs = {{6124}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  10766 }, -- Plaguerot Sprig
				{ 3,  10760 }, -- Swine Fists
			},
		},

		{ -- RFDTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  10574 }, -- Corpseshroud
				{ 2,  10581 }, -- Death's Head Vestment
				{ 3,  10583 }, -- Quillward Harness
				{ 4,  10584 }, -- Stormgale Fists
				{ 5,  10578 }, -- Thoughtcast Boots
				{ 6,  10582 }, -- Briar Tredders
				{ 7,  10572 }, -- Freezing Shard
				{ 8,  10567 }, -- Quillshooter
				{ 9,  10571 }, -- Ebony Boneclub
				{ 10, 10570 }, -- Manslayer
				{ 11, 10573 }, -- Boneslasher
			},
		},
		{ -- RFDLadyF
			name = AL["Lady Falther'ess"],
			npcID = 14686,
			DisplayIDs = {{10698}},
			AtlasMapBossID = 2,
			ContentPhase = 6,
			specialType = "scourgeInvasion",
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  23178 }, -- Mantle of Lady Falther'ess
				{ 2,  23177 }, -- Lady Falther'ess' Finger
			},
		},
		{ -- RFDHenryStern
			name = AL["Henry Stern"],
			npcID = 8696,
			DisplayIDs = {{8029}},
			AtlasMapBossID = 2,
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  3826 }, -- Mighty Troll's Blood Potion
				{ 2,  10841 }, -- Goldthorn Tea
			},
		},
	},
}

data["KroldokStronghold"] = {
	name = AL["Krol'dok Stronghold"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {40, 40, 45},
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["UldamanForever"] = {
	MapID = 1337, -- just no...
	InstanceID = 70,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Uldaman",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	AtlasMapFile = {"CL_Uldaman", "CL_UldamanEnt"},
	AtlasMapFile_AL = {"Uldaman", "UldamanEnt"},
	LevelRange = GetForVersion({30, 41, 51},{30, 36, 40}),
	items = {
		{ -- UldEric
			name = AL["Eric \"The Swift\""],
			npcID = 6907,
			Level = GetForVersion(40,39),
			DisplayIDs = {{5708}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  9394 }, -- Horned Viking Helmet
				{ 3,  9398 }, -- Worn Running Boots
				{ 5,  2459 }, -- Swiftness Potion
			},
		},
		{ -- UldBaelog
			name = AL["Baelog"],
			npcID = 6906,
			Level = GetForVersion(41,39),
			DisplayIDs = {{5710}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  9401 }, -- Nordic Longshank
				{ 3,  9399 }, -- Precision Arrow
				{ 5,  9400 }, -- Baelog's Shortbow
			},
		},
		{ -- UldOlaf
			name = AL["Olaf"],
			npcID = 6908,
			Level = GetForVersion(40,39),
			DisplayIDs = {{5709}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  9404 }, -- Olaf's All Purpose Shield
				{ 3,  9403 }, -- Battered Viking Shield
				{ 4,  1177 }, -- Oil of Olaf
			},
		},
		{ -- UldRevelosh
			name = AL["Revelosh"],
			npcID = 6910,
			Level = GetForVersion(40,39),
			DisplayIDs = {{5945}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  9389 }, -- Revelosh's Spaulders
				{ 2,  9388 }, -- Revelosh's Armguards
				{ 3,  9390 }, -- Revelosh's Gloves
				{ 4,  9387 }, -- Revelosh's Boots
				{ 6,  7741 }, -- The Shaft of Tsol
			},
		},
		{ -- UldIronaya
			name = AL["Ironaya"],
			npcID = 7228,
			Level = GetForVersion(40,39),
			DisplayIDs = {{6089}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  9409 }, -- Ironaya's Bracers
				{ 2,  9407 }, -- Stoneweaver Leggings
				{ 3,  9408 }, -- Ironshod Bludgeon
			},
		},
		{ -- UldObsidianSentinel
			name = AL["Obsidian Sentinel"],
			npcID = 7023,
			Level = GetForVersion(42,40),
			DisplayIDs = {{5285}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  8053 }, -- Obsidian Power Source
			},
		},
		{ -- UldAncientStoneKeeper
			name = AL["Ancient Stone Keeper"],
			npcID = 7206,
			Level = GetForVersion(44,40),
			DisplayIDs = {{10798}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  9410 }, -- Cragfists
				{ 3,  9411 }, -- Rockshard Pauldrons
			},
		},
		{ -- UldGalgannFirehammer
			name = AL["Galgann Firehammer"],
			npcID = 7291,
			Level = GetForVersion(45,40),
			DisplayIDs = {{6059}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  11310 }, -- Flameseer Mantle
				{ 2,  9412 }, -- Galgann's Fireblaster
				{ 4,  11311 }, -- Emberscale Cape
				{ 5,  9419 }, -- Galgann's Firehammer
			},
		},
		{ -- UldGrimlok
			name = AL["Grimlok"],
			npcID = 4854,
			Level = GetForVersion(45,40),
			DisplayIDs = {{11165}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  9415 }, -- Grimlok's Tribal Vestments
				{ 2,  9416 }, -- Grimlok's Charge
				{ 4,  9414 }, -- Oilskin Leggings
				{ 16, 7670 }, -- Shattered Necklace Sapphire
			},
		},
		{ -- UldArchaedas
			name = AL["Archaedas"],
			npcID = 2748,
			Level = GetForVersion(47,40),
			DisplayIDs = {{5988}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  11118 }, -- Archaedic Stone
				{ 2,  9413 }, -- The Rockpounder
				{ 3,  9418 }, -- Stoneslayer
			},
		},
		{ -- UldTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  9431 }, -- Papal Fez
				{ 2,  9429 }, -- Miner's Hat of the Deep
				{ 3,  9420 }, -- Adventurer's Pith Helmet
				{ 4,  9430 }, -- Spaulders of a Lost Age
				{ 5,  9397 }, -- Energy Cloak
				{ 6,  9406 }, -- Spirewind Fetter
				{ 7,  9428 }, -- Unearthed Bands
				{ 8,  9432 }, -- Skullplate Bracers
				{ 9,  9396 }, -- Legguards of the Vault
				{ 10, 9393 }, -- Beacon of Hope
				{ 12, 7666 }, -- Shattered Necklace
				--{ 13, 7673 }, -- Talvash's Enhancing Necklace
				{ 16, 9381 }, -- Earthen Rod
				{ 17, 9426 }, -- Monolithic Bow
				{ 18, 9422 }, -- Shadowforge Bushmaster
				{ 19, 9465 }, -- Digmaster 5000
				{ 20, 9384 }, -- Stonevault Shiv
				{ 21, 9386 }, -- Excavator's Brand
				{ 22, 9427 }, -- Stonevault Bonebreaker
				{ 23, 9392 }, -- Annealed Blade
				{ 24, 9424 }, -- Ginn-su Sword
				{ 25, 9383 }, -- Obsidian Cleaver
				{ 26, 9425 }, -- Pendulum of Doom
				{ 27, 9423 }, -- The Jackhammer
				{ 28, 9391 }, -- The Shoveler
			},
		},
		{ -- UldBaelogsChest
			name = AL["Baelog's Chest"],
			ExtraList = true,
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  7740 }, -- Gni'kiv Medallion
			},
		},
		{ -- UldConspicuousUrn
			name = AL["Conspicuous Urn"],
			ExtraList = true,
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  7671 }, -- Shattered Necklace Topaz
			},
		},
		{ -- UldShadowforgeCache
			name = AL["Shadowforge Cache"],
			ExtraList = true,
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  7669 }, -- Shattered Necklace Ruby
			},
		},
		{ -- UldTabletofWill
			name = AL["Tablet of Will"],
			ExtraList = true,
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  5824 }, -- Tablet of Will
			},
		},
	},
}

data["Zul'FarrakForever"] = {
	MapID = 1176,
	InstanceID = 209,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Zul'Farrak",
	AtlasMapFile = "CL_ZulFarrak",
	AtlasMapFile_AL = "ZulFarrak",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({39, 44, 54},{35, 42, 46}),
	items = {
		{ -- ZFAntusul
			name = AL["Antu'sul"],
			npcID = 8127,
			Level = GetForVersion(48,46),
			DisplayIDs = {{7353}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  9640 }, -- Vice Grips
				{ 2,  9641 }, -- Lifeblood Amulet
				{ 3,  9639 }, -- The Hand of Antu'sul
				{ 5,  9379 }, -- Sang'thraze the Deflector
			},
		},
		{ -- ZFThekatheMartyr
			name = AL["Theka the Martyr"],
			npcID = 7272,
			Level = GetForVersion({45, 46},46),
			DisplayIDs = {{6696}},
			AtlasMapBossID = 2,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  10660 }, -- First Mosh'aru Tablet
			},
		},
		{ -- ZFSandarrDunereaver
			name = AL["Sandarr Dunereaver"],
			npcID = 10080,
			Level = 45,
			DisplayIDs = {{9291}},
			IgnoreAsSource = true,
			--AtlasMapBossID = 2,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  9523, [ATLASLOOT_IT_AMOUNT1] = "2-4" }, -- First Mosh'aru Tablet
			},
		},
		{ -- ZFWitchDoctorZumrah
			name = AL["Witch Doctor Zum'rah"],
			npcID = 7271,
			Level = 46,
			DisplayIDs = {{6434}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  18083 }, -- Jumanza Grips
				{ 2,  18082 }, -- Zum'rah's Vexing Cane
			},
		},
		{ -- ZFNekrumGutchewer
			name = AL["Nekrum Gutchewer"],
			npcID = 7796,
			Level = GetForVersion({45, 46},45),
			DisplayIDs = {{6690}},
			AtlasMapBossID = 4,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  9471 }, -- Nekrum's Medallion
			},
		},
		{ -- ZFSezzziz
			name = AL["Shadowpriest Sezz'ziz"],
			npcID = 7275,
			Level = GetForVersion(47,46),
			DisplayIDs = {{6441}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  9470 }, -- Bad Mojo Mask
				{ 2,  9473 }, -- Jinxed Hoodoo Skin
				{ 3,  9474 }, -- Jinxed Hoodoo Kilt
				{ 4,  9475 }, -- Diabolic Skiver
			},
		},
		{ -- ZFDustwraith
			name = AL["Dustwraith"],
			npcID = 10081,
			Level = GetForVersion(47,46),
			DisplayIDs = {{9292}},
			AtlasMapBossID = 4,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  12471 }, -- Desertwalker Cane
			},
		},
		{ -- ZFSandfury
			name = AL["Sandfury Executioner"],
			npcID = 7274,
			Level = 46,
			DisplayIDs = {{6440}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  8444 }, -- Executioner's Key
			},
		},
		{ -- ZFSergeantBly
			name = AL["Sergeant Bly"],
			npcID = 7604,
			Level = 45,
			DisplayIDs = {{6433}},
			AtlasMapBossID = 5,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  8548 }, -- Divino-matic Rod
			},
		},
		{ -- ZFHydromancerVelratha
			name = AL["Hydromancer Velratha"],
			npcID = 7795,
			Level = 46,
			DisplayIDs = {{6685}},
			AtlasMapBossID = 6,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  9234 }, -- Tiara of the Deep
				{ 2,  10661 }, -- Second Mosh'aru Tablet
			},
		},
		{ -- ZFGahzrilla
			name = AL["Gahz'rilla"],
			npcID = 7273,
			Level = 46,
			DisplayIDs = {{7271}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  9469 }, -- Gahz'rilla Scale Armor
				{ 3,  9467 }, -- Gahz'rilla Fang
			},
		},
		{ -- ZFChiefUkorzSandscalp
			name = AL["Chief Ukorz Sandscalp"],
			npcID = 7267,
			Level = GetForVersion(48,46),
			DisplayIDs = {{6439}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  9479 }, -- Embrace of the Lycan
				{ 2,  9476 }, -- Big Bad Pauldrons
				{ 3,  9478 }, -- Ripsaw
				{ 4,  9477 }, -- The Chief's Enforcer
				{ 6,  11086 }, -- Jang'thraze the Protector
			},
		},
		{ -- ZFZerillis
			name = AL["Zerillis"],
			npcID = 10082,
			Level = 45,
			DisplayIDs = {{9293}},
			AtlasMapBossID = 8,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  12470 }, -- Sandstalker Ankleguards
			},
		},
		{ -- ZFTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  9512 }, -- Blackmetal Cape
				{ 2,  9484 }, -- Spellshock Leggings
				{ 3,  862 }, -- Runed Ring
				{ 4,  6440 }, -- Brainlash
				{ 5,  9483 }, -- Flaming Incinerator
				{ 6,  2040 }, -- Troll Protector
				{ 7,  5616 }, -- Gutwrencher
				{ 8,  9511 }, -- Bloodletter Scalpel
				{ 9,  9481 }, -- The Minotaur
				{ 10, 9480 }, -- Eyegouger
				{ 11, 9482 }, -- Witch Doctor's Cane
				{ 13, 9243 }, -- Shriveled Heart
			},
		},
	},
}

data["MaraudonForever"] = {
	MapID = 2100,
	InstanceID = 349,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Maraudon",
	AtlasMapFile = {"CL_Maraudon", "CL_MaraudonEnt"},
	AtlasMapFile_AL = {"Maraudon", "MaraudonEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({25, 46, 55},{30, 43, 48}),
	items = {
		{ -- MaraKhanVeng
			name = AL["Veng"],
			npcID = 13738,
			DisplayIDs = {{9418}},
			AtlasMapBossID = 1,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  17765 }, -- Gem of the Fifth Khan
			},
		},
		{ -- MaraNoxxion
			name = AL["Noxxion"],
			npcID = 13282,
			Level = GetForVersion(48,46),
			DisplayIDs = {{11172}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  17746 }, -- Noxxion's Shackles
				{ 2,  17744 }, -- Heart of Noxxion
				{ 3,  17745 }, -- Noxious Shooter
			},
		},
		{ -- MaraRazorlash
			name = AL["Razorlash"],
			npcID = 12258,
			Level = GetForVersion(48,46),
			DisplayIDs = {{12389}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  17749 }, -- Phytoskin Spaulders
				{ 2,  17748 }, -- Vinerot Sandals
				{ 4,  17750 }, -- Chloromesh Girdle
				{ 5,  17751 }, -- Brusslehide Leggings
			},
		},
		{ -- MaraKhanMaraudos
			name = AL["Maraudos"],
			npcID = 13739,
			DisplayIDs = {{9441}},
			AtlasMapBossID = 4,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  17764 }, -- Gem of the Fourth Khan
			},
		},
		{ -- MaraLordVyletongue
			name = AL["Lord Vyletongue"],
			npcID = 12236,
			Level = GetForVersion(47,44),
			DisplayIDs = {{12334}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  17755 }, -- Satyrmane Sash
				{ 2,  17754 }, -- Infernal Trickster Leggings
				{ 3,  17752 }, -- Satyr's Lash
			},
		},
		{ -- MaraMeshlok
			name = AL["Meshlok the Harvester"],
			npcID = 12237,
			Level = 48,
			DisplayIDs = {{9014}},
			AtlasMapBossID = 6,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  17767 }, -- Bloomsprout Headpiece
				{ 2,  17741 }, -- Nature's Embrace
				{ 3,  17742 }, -- Fungus Shroud Armor
			},
		},
		{ -- MaraCelebras
			name = AL["Celebras the Cursed"],
			npcID = 12225,
			Level = GetForVersion(49,46),
			DisplayIDs = {{12350}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  17740 }, -- Soothsayer's Headdress
				{ 2,  17739 }, -- Grovekeeper's Drape
				{ 3,  17738 }, -- Claw of Celebras
			},
		},
		{ -- MaraLandslide
			name = AL["Landslide"],
			npcID = 12203,
			Level = GetForVersion(50,48),
			DisplayIDs = {{12293}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  17734 }, -- Helm of the Mountain
				{ 2,  17736 }, -- Rockgrip Gauntlets
				{ 3,  17737 }, -- Cloud Stone
				{ 4,  17943 }, -- Fist of Stone
			},
		},
		{ -- MaraTinkererGizlock
			name = AL["Tinkerer Gizlock"],
			npcID = 13601,
			Level = GetForVersion(50,48),
			DisplayIDs = {{7125}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  17718 }, -- Gizlock's Hypertech Buckler
				{ 2,  17717 }, -- Megashot Rifle
				{ 3,  17719 }, -- Inventor's Focal Sword
			},
		},
		{ -- MaraRotgrip
			name = AL["Rotgrip"],
			npcID = 13596,
			Level = GetForVersion(50,48),
			DisplayIDs = {{13589}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  17732 }, -- Rotgrip Mantle
				{ 2,  17728 }, -- Albino Crocscale Boots
				{ 3,  17730 }, -- Gatorbite Axe
			},
		},
		{ -- MaraPrincessTheradras
			name = AL["Princess Theradras"],
			npcID = 12201,
			Level = GetForVersion(51,48),
			DisplayIDs = {{12292}},
			AtlasMapBossID = 11,
			[NORMAL_DIFF] = {
				{ 1,  17780 }, -- Blade of Eternal Darkness
				{ 3,  17715 }, -- Eye of Theradras
				{ 4,  17707 }, -- Gemshard Heart
				{ 5,  17714 }, -- Bracers of the Stone Princess
				{ 6,  17711 }, -- Elemental Rockridge Leggings
				{ 7,  17713 }, -- Blackstone Ring
				{ 8,  17710 }, -- Charstone Dirk
				{ 9,  17766 }, -- Princess Theradras' Scepter
			},
		},
		{ -- MaraNamelesProphet
			name = AL["The Nameless Prophet"],
			npcID = 13718,
			DisplayIDs = {{9426}},
			AtlasMapFile = "CL_MaraudonEnt",
			AtlasMapFile_AL = "MaraudonEnt",
			AtlasMapBossID = "*A",
			ExtraList = true,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  17757 }, -- Amulet of Spirits
			},
		},
		{ -- MaraKhanKolk
			name = AL["Kolk"],
			npcID = 13742,
			DisplayIDs = {{4860}},
			AtlasMapFile = "CL_MaraudonEnt",
			AtlasMapFile_AL = "MaraudonEnt",
			AtlasMapBossID = "*1",
			ExtraList = true,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  17761 }, -- Gem of the First Khan
			},
		},
		{ -- MaraKhanGelk
			name = AL["Gelk"],
			npcID = 13741,
			DisplayIDs = {{9427}},
			AtlasMapFile = "CL_MaraudonEnt",
			AtlasMapFile_AL = "MaraudonEnt",
			AtlasMapBossID = "*2",
			ExtraList = true,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  17762 }, -- Gem of the Second Khan
			},
		},
		{ -- MaraKhanMagra
			name = AL["Magra"],
			npcID = 13740,
			DisplayIDs = {{9433}},
			AtlasMapFile = "CL_MaraudonEnt",
			AtlasMapFile_AL = "MaraudonEnt",
			AtlasMapBossID = "*3",
			ExtraList = true,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  17763 }, -- Gem of the Third Khan
			},
		},
	},
}

data["AlcazPrison"] = {
	name = AL["Alcaz Prison"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {48, 48, 53},
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["TheTempleOfAtal'HakkarForever"] = {
	MapID = 1477,
	InstanceID = 109,
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "TheTempleOfAtal'Hakkar",
	AtlasMapFile = { "CL_TheSunkenTemple", "CL_TheSunkenTempleEnt" },
	AtlasMapFile_AL = { "TheSunkenTemple", "TheSunkenTempleEnt" },
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({45, 50, 60},{35, 47, 50}),
	items = {
		{ -- STBalconyMinibosses
			name = AL["Balcony Minibosses"],
			npcID = {5716, 5712, 5717, 5714, 5715, 5713},
			Level = GetForVersion({51, 52}, {459,50}),
			DisplayIDs = {{6701},{6699},{6707},{6700},{6702},{6698}},
			AtlasMapBossID = "C",
			[NORMAL_DIFF] = {
				{ 1,  10783 }, -- Atal'ai Spaulders
				{ 2,  10784 }, -- Atal'ai Breastplate
				{ 3,  10787 }, -- Atal'ai Gloves
				{ 5,  10788 }, -- Atal'ai Girdle
				{ 6,  10785 }, -- Atal'ai Leggings
				{ 7,  10786 }, -- Atal'ai Boots
				{ 9,  20606 }, -- Amber Voodoo Feather
				{ 10, 20607 }, -- Blue Voodoo Feather
				{ 11, 20608 }, -- Green Voodoo Feather
			},
		},
		{ -- STAtalalarion
			name = AL["Atal'alarion"],
			npcID = 8580,
			Level = GetForVersion(50,49),
			DisplayIDs = {{7873}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  10800 }, -- Darkwater Bracers
				{ 2,  10798 }, -- Atal'alarion's Tusk Ring
				{ 3,  10799 }, -- Headspike
			},
		},
		{ -- STSpawnOfHakkar
			name = AL["Spawn of Hakkar"],
			npcID = 5708,
			Level = GetForVersion(51,49),
			DisplayIDs = {{4065}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  10801 }, -- Slitherscale Boots
				{ 3,  10802 }, -- Wingveil Cloak
			},
		},
		{ -- STAvatarofHakkar
			name = AL["Avatar of Hakkar"],
			npcID = 8443,
			DisplayIDs = {{8053}},
			AtlasMapBossID = 3,
			Level = 48,
			[NORMAL_DIFF] = {
				{ 1,  12462 }, -- Embrace of the Wind Serpent
				{ 3,  10843 }, -- Featherskin Cape
				{ 4,  10845 }, -- Warrior's Embrace
				{ 5,  10842 }, -- Windscale Sarong
				{ 6,  10846 }, -- Bloodshot Greaves
				{ 7,  10838 }, -- Might of Hakkar
				{ 8,  10844 }, -- Spire of Hakkar
			},
		},
		{ -- STJammalan
			name = AL["Jammal'an the Prophet"],
			npcID = 5710,
			Level = GetForVersion(54,50),
			DisplayIDs = {{6708}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  10806 }, -- Vestments of the Atal'ai Prophet
				{ 2,  10808 }, -- Gloves of the Atal'ai Prophet
				{ 3,  10807 }, -- Kilt of the Atal'ai Prophet
			},
		},
		{ -- STOgom
			name = AL["Ogom the Wretched"],
			npcID = 5711,
			Level = GetForVersion(53,49),
			DisplayIDs = {{6709}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  10805 }, -- Eater of the Dead
				{ 2,  10803 }, -- Blade of the Wretched
				{ 3,  10804 }, -- Fist of the Damned
			},
		},
		{ -- STDreamscythe
			name = AL["Dreamscythe"],
			npcID = 5721,
			Level = GetForVersion(53,50),
			DisplayIDs = {{7553}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  12465 }, -- Nightfall Drape
				{ 2,  12466 }, -- Dawnspire Cord
				{ 3,  12464 }, -- Bloodfire Talons
				{ 4,  10797 }, -- Firebreather
				{ 5,  12463 }, -- Drakefang Butcher
				{ 6,  12243 }, -- Smoldering Claw
				{ 7,  10795 }, -- Drakeclaw Band
				{ 8,  10796 }, -- Drakestone
			},
		},
		{ -- STWeaver
			name = AL["Weaver"],
			npcID = 5720,
			Level = GetForVersion(51,50),
			DisplayIDs = {{6375}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  12465 }, -- Nightfall Drape
				{ 2,  12466 }, -- Dawnspire Cord
				{ 3,  12464 }, -- Bloodfire Talons
				{ 4,  10797 }, -- Firebreather
				{ 5,  12463 }, -- Drakefang Butcher
				{ 6,  12243 }, -- Smoldering Claw
				{ 7,  10795 }, -- Drakeclaw Band
				{ 8,  10796 }, -- Drakestone
			},
		},
		{ -- STHazzas
			name = AL["Hazzas"],
			npcID = 5722,
			Level = GetForVersion(53,50),
			DisplayIDs = {{9584}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  12465 }, -- Nightfall Drape
				{ 2,  12466 }, -- Dawnspire Cord
				{ 3,  12464 }, -- Bloodfire Talons
				{ 4,  10797 }, -- Firebreather
				{ 5,  12463 }, -- Drakefang Butcher
				{ 6,  12243 }, -- Smoldering Claw
				{ 7,  10795 }, -- Drakeclaw Band
				{ 8,  10796 }, -- Drakestone
			},
		},
		{ -- STMorphaz
			name = AL["Morphaz"],
			npcID = 5719,
			Level = GetForVersion(52,50),
			DisplayIDs = {{7975}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  12465 }, -- Nightfall Drape
				{ 2,  12466 }, -- Dawnspire Cord
				{ 3,  12464 }, -- Bloodfire Talons
				{ 4,  10797 }, -- Firebreather
				{ 5,  12463 }, -- Drakefang Butcher
				{ 6,  12243 }, -- Smoldering Claw
				{ 7,  10795 }, -- Drakeclaw Band
				{ 8,  10796 }, -- Drakestone
			},
		},
		{ -- STEranikus
			name = AL["Shade of Eranikus"],
			npcID = 5709,
			Level = GetForVersion(55,50),
			DisplayIDs = {{7806}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  10847 }, -- Dragon's Call
				{ 3,  10833 }, -- Horns of Eranikus
				{ 4,  10829 }, -- Dragon's Eye
				{ 5,  10836 }, -- Rod of Corrosion
				{ 6,  10835 }, -- Crest of Supremacy
				{ 7,  10837 }, -- Tooth of Eranikus
				{ 8,  10828 }, -- Dire Nail
				{ 10, 10454 }, -- Essence of Eranikus
			},
		},
		{ -- STTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  10630 }, -- Soulcatcher Halo
				{ 2,  10632 }, -- Slimescale Bracers
				{ 3,  10631 }, -- Murkwater Gauntlets
				{ 4,  10633 }, -- Silvershell Leggings
				{ 5,  10629 }, -- Mistwalker Boots
				{ 6,  10634 }, -- Mindseye Circle
				{ 7,  10624 }, -- Stinging Bow
				{ 8,  10623 }, -- Winter's Bite
				{ 9,  10625 }, -- Stealthblade
				{ 10, 10626 }, -- Ragehammer
				{ 11, 10628 }, -- Deathblow
				{ 12, 10627 }, -- Bludgeon of the Grinning Dog
				{ 16, 10782 }, -- Hakkari Shroud
				{ 17, 10781 }, -- Hakkari Breastplate
				{ 18, 10780 }, -- Mark of Hakkar
				{ 20, 16216 }, -- Formula: Enchant Cloak - Greater Resistance
				{ 21, 15733 }, -- Pattern: Green Dragonscale Leggings
			},
		},
	},
}

data["BlackrockDepthsForever"] = {
	MapID = 1584,
	InstanceID = 230,
	SubAreaIDs = { 26758, 26761, 26747, 26733, 26755, 26740, 26751, 26759, 26735, 26769, 26768, 26766, 26781, 26765, 26764, 26742, 26750, 26745, 26784, 26749 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "BlackrockDepths",
	AtlasMapFile = {"CL_BlackrockDepths", "CL_BlackrockMountainEnt"},
	AtlasMapFile_AL = {"BlackrockDepths", "BlackrockMountainEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({42, 52, 60},{40, 48, 56}),
	items = {
		{ -- BRDLordRoccor
			name = AL["Lord Roccor"],
			npcID = 9025,
			Level = 51,
			SubAreaID = 26735,
			DisplayIDs = {{5781}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  22234 }, -- Mantle of Lost Hope
				{ 2,  11632 }, -- Earthslag Shoulders
				{ 3,  11631 }, -- Stoneshell Guard
				{ 4,  22397 }, -- Idol of Ferocity
				{ 5,  11630 }, -- Rockshard Pellets
				{ 7,  11813 }, -- Formula: Smoking Heart of the Mountain
				--{ 8,  11811 }, -- Smoking Heart of the Mountain
			},
		},
		{ -- BRDHighInterrogatorGerstahn
			name = AL["High Interrogator Gerstahn "],
			npcID = 9018,
			Level = 52,
			SubAreaID = 26733,
			DisplayIDs = {{8761}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  11626 }, -- Blackveil Cape
				{ 2,  11624 }, -- Kentic Amice
				{ 3,  22240 }, -- Greaves of Withering Despair
				{ 4,  11625 }, -- Enthralled Sphere
				{ 16,  11140 }, -- Prison Cell Key
			},
		},
		{ -- BRDHoundmaster
			name = AL["Houndmaster Grebmar"],
			npcID = 9319,
			Level = 52,
			SubAreaID = 26735,
			DisplayIDs = {{9212}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11623 }, -- Spritecaster Cape
				{ 2,  11627 }, -- Fleetfoot Greaves
				{ 3,  11628 }, -- Houndmaster's Bow
				{ 4,  11629 }, -- Houndmaster's Rifle
			},
		},
		-- ## RING START
		{ -- BRDGorosh
			name = AL["Gorosh the Dervish"],
			nameFormat = NAME_BRD_RING_OF_LAW,
			npcID = 9027,
			Level = GetForVersion(56,52),
			SubAreaID = 26742,
			DisplayIDs = {{8760}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11726 }, -- Savage Gladiator Chain
				{ 2,  22271 }, -- Leggings of Frenzied Magic
				{ 3,  22257 }, -- Bloodclot Band
				{ 4,  22266 }, -- Flarethorn
			},
		},
		{ -- BRDGrizzle
			name = AL["Grizzle"],
			nameFormat = NAME_BRD_RING_OF_LAW,
			npcID = 9028,
			Level = GetForVersion(54,52),
			DisplayIDs = {{7873}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11722 }, -- Dregmetal Spaulders
				{ 2,  11703 }, -- Stonewall Girdle
				{ 3,  22270 }, -- Entrenching Boots
				{ 4,  11702 }, -- Grizzle's Skinner
				{ 6,  11610 }, -- Plans: Dark Iron Pulverizer
				--{ 2,  11608 }, -- Dark Iron Pulverizer
			},
		},
		{ -- BRDEviscerator
			name = AL["Eviscerator"],
			nameFormat = NAME_BRD_RING_OF_LAW,
			npcID = 9029,
			Level = GetForVersion(54,52),
			DisplayIDs = {{523}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11685 }, -- Splinthide Shoulders
				{ 2,  11679 }, -- Rubicund Armguards
				{ 4,  11686 }, -- Girdle of Beastial Fury
				{ 5,  11730 }, -- Savage Gladiator Grips
			},
		},
		{ -- BRDOkthor
			name = AL["Ok'thor the Breaker"],
			nameFormat = NAME_BRD_RING_OF_LAW,
			npcID = 9030,
			Level = GetForVersion(54,53),
			DisplayIDs = {{11538}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11665 }, -- Ogreseer Fists
				{ 2,  11662 }, -- Ban'thok Sash
				{ 3,  11728 }, -- Savage Gladiator Leggings
				{ 4,  11824 }, -- Cyclopean Band
			},
		},
		{ -- BRDAnubshiah
			name = AL["Anub'shiah"],
			nameFormat = NAME_BRD_RING_OF_LAW,
			npcID = 9031,
			Level = GetForVersion(54,52),
			DisplayIDs = {{3004}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11678 }, -- Carapace of Anub'shiah
				{ 2,  11677 }, -- Graverot Cape
				{ 3,  11675 }, -- Shadefiend Boots
				{ 4,  11731 }, -- Savage Gladiator Greaves
			},
		},
		{ -- BRDHedrum
			name = AL["Hedrum the Creeper"],
			nameFormat = NAME_BRD_RING_OF_LAW,
			npcID = 9032,
			Level = GetForVersion(53,52),
			DisplayIDs = {{8271}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  11633 }, -- Spiderfang Carapace
				{ 2,  11634 }, -- Silkweb Gloves
				{ 3,  11635 }, -- Hookfang Shanker
				{ 4,  11729 }, -- Savage Gladiator Helm
			},
		},
		-- ## RING END
		{ -- BRDPyromancerLoregrain
			name = AL["Pyromancer Loregrain"],
			npcID = 9024,
			Level = 52,
			SubAreaID = 26745,
			DisplayIDs = {{8762}},
			AtlasMapBossID = 7,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  11747 }, -- Flamestrider Robes
				{ 2,  11749 }, -- Searingscale Leggings
				{ 3,  11748 }, -- Pyric Caduceus
				{ 4,  11750 }, -- Kindling Stave
				{ 6,  11207 }, -- Formula: Enchant Weapon - Fiery Weapon
			},
		},
		{ -- BRDTheVault
			name = AL["Dark Coffer"],
			SubAreaID = 26758,
			npcID = {9438, 9442, 9443, 9439, 9437, 9441},
			DisplayIDs = {{8592},{8595},{8596},{8593},{8591},{8594}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1, "INV_Box_01", nil, AL["Dark Keeper"], nil },
				{ 2,  11197 }, -- Dark Keeper Key
				{ 5, "INV_Box_01", nil, AL["Secret Safe"], nil },
				{ 6,  22256 }, -- Mana Shaping Handwraps
				{ 7,  22205 }, -- Black Steel Bindings
				{ 8,  22255 }, -- Magma Forged Band
				{ 9,  22254 }, -- Wand of Eternal Light
				{ 10,  11923 }, -- The Hammer of Grace
				{ 16, "INV_Box_01", nil, AL["Relic Coffer"], nil },
				{ 17, 11945 }, -- Dark Iron Ring
				{ 18, 11946 }, -- Fire Opal Necklace
				{ 20, "INV_Box_01", nil, AL["Dark Coffer"], nil },
				{ 21, 11752 }, -- Black Blood of the Tormented
				{ 22, 11751 }, -- Burning Essence
				{ 23, 11753 }, -- Eye of Kajal
			},
		},
		{ -- BRDWarderStilgiss
			name = AL["Warder Stilgiss"],
			npcID = 9041,
			Level = GetForVersion(56,54),
			SubAreaID = 26758,
			DisplayIDs = {{9089}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  11782 }, -- Boreal Mantle
				{ 2,  22241 }, -- Dark Warder's Pauldrons
				{ 3,  11783 }, -- Chillsteel Girdle
				{ 4,  11784 }, -- Arbiter's Blade
			},
		},
		{ -- BRDVerek
			name = AL["Verek"],
			npcID = 9042,
			Level = GetForVersion(55,53),
			SubAreaID = 26758,
			DisplayIDs = {{9019}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  11755 }, -- Verek's Collar
				{ 2,  22242 }, -- Verek's Leash
			},
		},
		{ -- BRDWatchmanDoomgrip
			name = AL["Watchman Doomgrip"],
			npcID = 9476,
			Level = GetForVersion(55,54),
			SubAreaID = 26758,
			DisplayIDs = {{8655}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  22205 }, -- Black Steel Bindings
				{ 2,  22255 }, -- Magma Forged Band
				{ 3,  22256 }, -- Mana Shaping Handwraps
				{ 4,  22254 }, -- Wand of Eternal Light
			},
		},
		{ -- BRDFineousDarkvire
			name = AL["Fineous Darkvire"],
			npcID = 9056,
			Level = GetForVersion(54,53),
			SubAreaID = 26759,
			DisplayIDs = {{8704}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  11839 }, -- Chief Architect's Monocle
				{ 2,  22223 }, -- Foreman's Head Protector
				{ 3,  11842 }, -- Lead Surveyor's Mantle
				{ 4,  11841 }, -- Senior Designer's Pantaloons
				{ 6,  11840 }, -- Master Builder's Shirt
			},
		},
		{ -- BRDLordIncendius
			name = AL["Lord Incendius"],
			npcID = 9017,
			Level = GetForVersion(55,53),
			SubAreaID = 26750,
			DisplayIDs = {{1204}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  11766 }, -- Flameweave Cuffs
				{ 2,  11764 }, -- Cinderhide Armsplints
				{ 3,  11765 }, -- Pyremail Wristguards
				{ 4,  11767 }, -- Emberplate Armguards
				{ 6,  19268 }, -- Ace of Elementals
				{ 8,  11768 }, -- Incendic Bracers
			},
		},
		{ -- BRDBaelGar
			name = AL["Bael'Gar"],
			npcID = 9016,
			Level = GetForVersion(54,52),
			SubAreaID = 26747,
			DisplayIDs = {{12162}},
			AtlasMapBossID = 11,
			[NORMAL_DIFF] = {
				{ 1,  11807 }, -- Sash of the Burning Heart
				{ 2,  11802 }, -- Lavacrest Leggings
				{ 3,  11805 }, -- Rubidium Hammer
				{ 4,  11803 }, -- Force of Magma
			},
		},
		{ -- BRDGeneralAngerforge
			name = AL["General Angerforge"],
			npcID = 9033,
			Level = GetForVersion(57,55),
			SubAreaID = 26749,
			DisplayIDs = {{8756}},
			AtlasMapBossID = 13,
			[NORMAL_DIFF] = {
				{ 1,  11820 }, -- Royal Decorated Armor
				{ 2,  11821 }, -- Warstrife Leggings
				{ 3, 11810 }, -- Force of Will
				{ 4,  11817 }, -- Lord General's Sword
				{ 5,  11816 }, -- Angerforge's Battle Axe
				{ 6,  11841 }, -- Senior Designer's Pantaloons
			},
		},
		{ -- BRDGolemLordArgelmach
			name = AL["Golem Lord Argelmach"],
			npcID = 8983,
			Level = GetForVersion(57,55),
			SubAreaID = 26781,
			DisplayIDs = {{8759}},
			AtlasMapBossID = 14,
			[NORMAL_DIFF] = {
				{ 1,  11823 }, -- Luminary Kilt
				{ 2,  11822 }, -- Omnicast Boots
				{ 3,  11669 }, -- Naglering
				{ 4,  11819 }, -- Second Wind
			},
		},
		{ -- BRDGuzzler
			name = AL["Guzzler"],
			SubAreaID = 26751,
			npcID = {9537, 12944, 9543, 9499},
			Level = 55,
			DisplayIDs = {{8658},{14666},{8667},{8652}},
			AtlasMapBossID = 15,
			[NORMAL_DIFF] = {
				{ 1, "INV_Box_01", nil, AL["Hurley Blackbreath"], nil },
				{ 2,  11735 }, -- Ragefury Eyepatch
				{ 3,  18043 }, -- Coal Miner Boots
				{ 4,  22275 }, -- Firemoss Boots
				{ 5,  18044 }, -- Hurley's Tankard
				{ 7, "INV_Box_01", nil, AL["Lokhtos Darkbargainer"], nil },
				{ 8, 18592 }, -- Plans: Sulfuron Hammer
				{ 16, "INV_Box_01", nil, AL["Ribbly Screwspigot"], nil },
				{ 17, 11612 }, -- Plans: Dark Iron Plate
				{ 18, 2662 }, -- Ribbly's Quiver
				{ 19, 2663 }, -- Ribbly's Bandolier
				{ 20, 11742 }, -- Wayfarer's Knapsack
				{ 22, "INV_Box_01", nil, AL["Plugger Spazzring"], nil },
				{ 23, 12793 }, -- Mixologist's Tunic
				{ 24, 12791 }, -- Barman Shanker
				{ 25, 18653 }, -- Schematic: Goblin Jumper Cables XL
				{ 26, 13483 }, -- Recipe: Transmute Fire to Earth
				{ 27, 15759 }, -- Pattern: Black Dragonscale Breastplate
				{ 28, 11325 }, -- Dark Iron Ale Mug
				{ 29, 11602 }, -- Grim Guzzler Key
			},
		},
		{ -- Phalanx
			name = AL["Phalanx"],
			npcID = 9502,
			Level = 55,
			SubAreaID = 26751,
			DisplayIDs = {{8177}},
			AtlasMapBossID = 15,
			[NORMAL_DIFF] = {
				{ 1,  22212 }, -- Golem Fitted Pauldrons
				{ 2,  11745 }, -- Fists of Phalanx
				{ 3, 11744 }, -- Bloodfist
				{ 4, 11743 }, -- Rockfist
			},
		},
		{ -- BRDFlamelash
			name = AL["Ambassador Flamelash"],
			npcID = 9156,
			Level = GetForVersion(57,55),
			SubAreaID = 26761,
			DisplayIDs = {{8329}},
			AtlasMapBossID = 16,
			[NORMAL_DIFF] = {
				{ 1,  11808 }, -- Circle of Flame
				{ 3,  11812 }, -- Cape of the Fire Salamander
				{ 4,  11814 }, -- Molten Fists
				{ 5,  11832 }, -- Burst of Knowledge
				{ 6,  11809 }, -- Flame Wrath
				{ 8,  23320 }, -- Tablet of Flame Shock VI
			},
		},
		{ -- BRDPanzor
			name = AL["Panzor the Invincible"],
			npcID = 8923,
			Level = GetForVersion(57,56),
			SubAreaID = 26764,
			DisplayIDs = {{8270}},
			AtlasMapBossID = 17,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  22245 }, -- Soot Encrusted Footwear
				{ 2,  11787 }, -- Shalehusk Boots
				{ 3,  11785 }, -- Rock Golem Bulwark
				{ 4,  11786 }, -- Stone of the Earth
			},
		},
		{ -- BRDTomb
			name = AL["Chest of The Seven"],
			SubAreaID = 26784,
			npcID = {9034, 9035, 9036, 9037, 9038, 9039, 9040},
			ObjectID = 169243,
			Level = GetForVersion({55, 57},{55, 56}),
			DisplayIDs = {{8690},{8686},{8692},{8689},{8691},{8687},{8688}},
			AtlasMapBossID = 18,
			[NORMAL_DIFF] = {
				{ 1,  11925 }, -- Ghostshroud
				{ 2,  11926 }, -- Deathdealer Breastplate
				{ 3,  11929 }, -- Haunting Specter Leggings
				{ 4,  11927 }, -- Legplates of the Eternal Guardian
				{ 5,  11920 }, -- Wraith Scythe
				{ 6,  11923 }, -- The Hammer of Grace
				{ 7,  11922 }, -- Blood-etched Blade
				{ 8,  11921 }, -- Impervious Giant
			},
		},
		{ -- BRDMagmus
			name = AL["Magmus"],
			npcID = 9938,
			Level = GetForVersion(57,56),
			SubAreaID = 26768,
			DisplayIDs = {{12162}},
			AtlasMapBossID = 20,
			[NORMAL_DIFF] = {
				{ 1,  11746 }, -- Golem Skull Helm
				{ 2,  11935 }, -- Magmus Stone
				{ 3,  22395 }, -- Totem of Rage
				{ 4,  22400 }, -- Libram of Truth
				{ 5,  22208 }, -- Lavastone Hammer
			},
		},
		{ -- BRDPrincess
			name = AL["Princess Moira Bronzebeard "],
			npcID = 8929,
			Level = GetForVersion(58,55),
			SubAreaID = 26769,
			DisplayIDs = {{8705}},
			AtlasMapBossID = 21,
			[NORMAL_DIFF] = {
				{ 1,  12557 }, -- Ebonsteel Spaulders
				{ 2,  12554 }, -- Hands of the Exalted Herald
				{ 3,  12556 }, -- High Priestess Boots
				{ 4,  12553 }, -- Swiftwalker Boots
			},
		},
		{ -- BRDEmperorDagranThaurissan
			name = AL["Emperor Dagran Thaurissan"],
			npcID = 9019,
			Level = GetForVersion(59,56),
			SubAreaID = 26769,
			DisplayIDs = {{8807}},
			AtlasMapBossID = 21,
			[NORMAL_DIFF] = {
				{ 1,  11684 }, -- Ironfoe
				{ 3,  11933 }, -- Imperial Jewel
				{ 4,  11930 }, -- The Emperor's New Cape
				{ 5,  11924 }, -- Robes of the Royal Crown
				{ 6,  22204 }, -- Wristguards of Renown
				{ 7,  22207 }, -- Sash of the Grand Hunt
				{ 8,  11934 }, -- Emperor's Seal
				{ 9,  11815 }, -- Hand of Justice
				{ 10, 11928 }, -- Thaurissan's Royal Scepter
				{ 11, 11931 }, -- Dreadforge Retaliator
				{ 12, 11932 }, -- Guiding Stave of Wisdom
				{ 16, 12033 }, -- Thaurissan Family Jewels
			},
		},
		{ -- BRDTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  12549 }, -- Braincage
				{ 2,  12552 }, -- Blisterbane Wrap
				{ 3,  12551 }, -- Stoneshield Cloak
				{ 4,  12542 }, -- Funeral Pyre Vestment
				{ 5,  12546 }, -- Aristocratic Cuffs
				{ 6,  12550 }, -- Runed Golem Shackles
				{ 7,  12547 }, -- Mar Alom's Grip
				{ 8,  12555 }, -- Battlechaser's Greaves
				{ 9,  12527 }, -- Ribsplitter
				{ 10, 12531 }, -- Searing Needle
				{ 11, 12535 }, -- Doomforged Straightedge
				{ 12, 12528 }, -- The Judge's Gavel
				{ 13, 12532 }, -- Spire of the Stoneshaper
				{ 16, 15781 }, -- Pattern: Black Dragonscale Leggings
				{ 17, 15770 }, -- Pattern: Black Dragonscale Shoulders
				{ 19, 11611 }, -- Plans: Dark Iron Sunderer
				{ 20, 11614 }, -- Plans: Dark Iron Mail
				{ 21, 11615 }, -- Plans: Dark Iron Shoulders
				{ 23, 16048 }, -- Schematic: Dark Iron Rifle
				{ 24, 16053 }, -- Schematic: Master Engineer's Goggles
				{ 25, 16049 }, -- Schematic: Dark Iron Bomb
				{ 26, 18654 }, -- Schematic: Gnomish Alarm-O-Bot
				{ 27, 18661 }, -- Schematic: World Enlarger
			},
		},
		{ -- BRDBSPlans
			name = AL["Plans"],
			ExtraList = true,
			IgnoreAsSource = true,
			[NORMAL_DIFF] = {
				{ 1,  11614 }, -- Plans: Dark Iron Mail
				{ 2,  11615 }, -- Plans: Dark Iron Shoulders
			},
		},
		{ -- BRDTheldren
			name = AL["Theldren"].." - "..format(AL["Tier %s Sets"], "0.5"),
			npcID = 16059,
			DisplayIDs = {{15981}},
			AtlasMapBossID = 6,
			Level = 60,
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  22305 }, -- Ironweave Mantle
				{ 2,  22330 }, -- Shroud of Arcane Mastery
				{ 3,  22318 }, -- Malgen's Long Bow
				{ 4,  22317 }, -- Lefty's Brass Knuckle
			},
		},
	},
}

data["LowerBlackrockSpireForever"] = {
	name = AL["Lower Blackrock Spire"],
	MapID = 1583,
	InstanceID = 229,
	SubAreaIDs = { 26683, 26718, 26711, 26713, 26686, 32528, 26688 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "LowerBlackrockSpire",
	AtlasMapFile = {"CL_BlackrockSpireLower", "CL_BlackrockMountainEnt"},
	AtlasMapFile_AL = {"BlackrockSpireLower", "BlackrockMountainEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({48, 55, 60}, {45, 54, 60}),
	items = {
		{ -- LBRSFelguard
			name = AL["Burning Felguard"],
			npcID = 10263,
			Level = {56, 57},
			DisplayIDs = {{5047}},
			AtlasMapBossID = 1,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13181 }, -- Demonskin Gloves
				{ 2,  13182 }, -- Phase Blade
			},
		},
		{ -- LBRSSpirestoneButcher
			name = AL["Spirestone Butcher"],
			npcID = 9219,
			Level = 57,
			DisplayIDs = {{11574}},
			AtlasMapBossID = 4,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  12608 }, -- Butcher's Apron
				{ 2,  13286 }, -- Rivenspike
			},
		},
		{ -- LBRSOmokk
			name = AL["Highlord Omokk"],
			npcID = 9196,
			Level = GetForVersion(59,57),
			SubAreaID = 26713,
			DisplayIDs = {{11565}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  16670 }, -- Boots of Elements
				{ 3,  13166 }, -- Slamshot Shoulders
				{ 4,  13168 }, -- Plate of the Shaman King
				{ 5,  13170 }, -- Skyshroud Leggings
				{ 6,  13169 }, -- Tressermane Leggings
				{ 7,  13167 }, -- Fist of Omokk
				{ 8,  12336 }, -- Gemstone of Spirestone
				{ 16, 12534 }, -- Omokk's Head
			},
		},
		{ -- LBRSSpirestoneBattleLord
			name = AL["Spirestone Battle Lord"],
			npcID = 9218,
			Level = 58,
			DisplayIDs = {{11576}},
			AtlasMapBossID = 6,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13284 }, -- Swiftdart Battleboots
				{ 2,  13285 }, -- The Nicker
			},
		},
		{ -- LBRSSpirestoneLordMagus
			name = AL["Spirestone Lord Magus"],
			npcID = 9217,
			Level = {57, 58},
			DisplayIDs = {{11578}},
			AtlasMapBossID = 6,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13282 }, -- Ogreseer Tower Boots
				{ 2,  13283 }, -- Magus Ring
				{ 3,  13261 }, -- Globe of D'sak
			},
		},
		{ -- LBRSVosh
			name = AL["Shadow Hunter Vosh'gajin"],
			npcID = 9236,
			Level = 58,
			SubAreaID = 26688,
			DisplayIDs = {{9732}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  16712 }, -- Shadowcraft Gloves
				{ 3,  13257 }, -- Demonic Runed Spaulders
				{ 4,  12626 }, -- Funeral Cuffs
				{ 5,  13255 }, -- Trueaim Gauntlets
				{ 6,  12653 }, -- Riphook
				{ 7,  12651 }, -- Blackcrow
				{ 8,  12654 }, -- Doomshot
			},
		},
		{ -- LBRSVoone
			name = AL["War Master Voone"],
			npcID = 9237,
			Level = GetForVersion(59,58),
			SubAreaID = 26688,
			DisplayIDs = {{9733}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  16676 }, -- Beaststalker's Gloves
				{ 3,  13177 }, -- Talisman of Evasion
				{ 4,  13179 }, -- Brazecore Armguards
				{ 5,  22231 }, -- Kayser's Boots of Precision
				{ 6,  13173 }, -- Flightblade Throwing Axe
				{ 7,  12582 }, -- Keris of Zul'Serak
				{ 9,  12335 }, -- Gemstone of Smolderthorn
			},
		},
		{ -- LBRSGrimaxe
			name = AL["Bannok Grimaxe"],
			npcID = 9596,
			Level = 59,
			DisplayIDs = {{9668}},
			AtlasMapBossID = 12,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  12637 }, -- Backusarian Gauntlets
				{ 2,  12634 }, -- Chiselbrand Girdle
				{ 3,  12621 }, -- Demonfork
				{ 5,  12838 }, -- Plans: Arcanite Reaper
				--{ 6,  12784 }, -- Arcanite Reaper
			},
		},
		{ -- LBRSSmolderweb
			name = AL["Mother Smolderweb"],
			npcID = 10596,
			Level = 59,
			SubAreaID = 26686,
			DisplayIDs = {{9929}},
			AtlasMapBossID = 13,
			[NORMAL_DIFF] = {
				{ 1,  16715 }, -- Wildheart Boots
				{ 3,  13244 }, -- Gilded Gauntlets
				{ 4,  13213 }, -- Smolderweb's Eye
				{ 5,  13183 }, -- Venomspitter
			},
		},
		{ -- LBRSCrystalFang
			name = AL["Crystal Fang"],
			npcID = 10376,
			Level = 60,
			SubAreaID = 26686,
			DisplayIDs = {{9755}},
			AtlasMapBossID = 14,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13185 }, -- Sunderseer Mantle
				{ 2,  13184 }, -- Fallbrush Handgrips
				{ 3,  13218 }, -- Fang of the Crystal Spider
			},
		},
		{ -- LBRSDoomhowl
			name = AL["Urok Doomhowl"],
			npcID = 10584,
			Level = 60,
			DisplayIDs = {{11583}},
			AtlasMapBossID = 15,
			[NORMAL_DIFF] = {
				{ 1,  13258 }, -- Slaghide Gauntlets
				{ 2,  22232 }, -- Marksman's Girdle
				{ 3,  13259 }, -- Ribsteel Footguards
				{ 4,  13178 }, -- Rosewine Circle
				{ 16,  18784 }, -- Top Half of Advanced Armorsmithing: Volume III
			},
		},
		{ -- LBRSZigris
			name = AL["Quartermaster Zigris"],
			npcID = 9736,
			Level = 59,
			SubAreaID = 32528,
			DisplayIDs = {{9738}},
			AtlasMapBossID = 16,
			[NORMAL_DIFF] = {
				{ 1,  13247 }, -- Quartermaster Zigris' Footlocker
				{ 3,  13253 }, -- Hands of Power
				{ 4,  13252 }, -- Cloudrunner Girdle
				{ 6,  12835 }, -- Plans: Annihilator
				--{ 5,  12798 }, -- Annihilator
			},
		},
		{ -- LBRSHalycon
			name = AL["Halycon"],
			npcID = 10220,
			Level = 59,
			SubAreaID = 26711,
			DisplayIDs = {{9567}},
			AtlasMapBossID = 17,
			[NORMAL_DIFF] = {
				{ 1,  13212 }, -- Halycon's Spiked Collar
				{ 2,  22313 }, -- Ironweave Bracers
				{ 3,  13211 }, -- Slashclaw Bracers
				{ 4,  13210 }, -- Pads of the Dread Wolf
			},
		},
		{ -- LBRSSlavener
			name = AL["Gizrul the Slavener"],
			npcID = 10268,
			Level = 60,
			SubAreaID = 26711,
			DisplayIDs = {{9564}},
			AtlasMapBossID = 17,
			[NORMAL_DIFF] = {
				{ 1,  16718 }, -- Wildheart Spaulders
				{ 3,  13208 }, -- Bleak Howler Armguards
				{ 4,  13206 }, -- Wolfshear Leggings
				{ 5,  13205 }, -- Rhombeard Protector
			},
		},
		{ -- LBRSBashguud
			name = AL["Ghok Bashguud"],
			npcID = 9718,
			Level = 59,
			DisplayIDs = {{11809}},
			AtlasMapBossID = 18,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13203 }, -- Armswake Cloak
				{ 2,  13198 }, -- Hurd Smasher
				{ 3,  13204 }, -- Bashguuder
			},
		},
		{ -- LBRSWyrmthalak
			name = AL["Overlord Wyrmthalak"],
			npcID = 9568,
			Level = 60,
			SubAreaID = 26718,
			DisplayIDs = {{8711}},
			AtlasMapBossID = 19,
			[NORMAL_DIFF] = {
				{ 1,  13143 }, -- Mark of the Dragon Lord
				{ 3,  16679 }, -- Beaststalker's Mantle
				{ 5,  13162 }, -- Reiver Claws
				{ 6,  13164 }, -- Heart of the Scale
				{ 7,  22321 }, -- Heart of Wyrmthalak
				{ 8,  13163 }, -- Relentless Scythe
				{ 9,  13148 }, -- Chillpike
				{ 10, 13161 }, -- Trindlehaven Staff
				{ 12, 12337 }, -- Gemstone of Bloodaxe
				{ 16, 12780 }, -- General Drakkisath's Command
			},
		},

		{ -- LBRSTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  14513 }, -- Pattern: Robe of the Archmage
				--{ 2,  14152 }, -- Robe of the Archmage
				{ 3,  16696 }, -- Devout Belt
				{ 4,  16685 }, -- Magister's Belt
				{ 5,  16683 }, -- Magister's Bindings
				{ 6,  16703 }, -- Dreadmist Bracers
				{ 7,  16713 }, -- Shadowcraft Belt
				{ 8,  16716 }, -- Wildheart Belt
				{ 9, 16680 }, -- Beaststalker's Belt
				{ 10, 16673 }, -- Cord of Elements
				{ 11, 16736 }, -- Belt of Valor
				{ 12, 16735 }, -- Bracers of Valor
				{ 16, 15749 }, -- Pattern: Volcanic Breastplate
				{ 17, 15775 }, -- Pattern: Volcanic Shoulders
				{ 18, 13494 }, -- Recipe: Greater Fire Protection Potion
				{ 19, 16250 }, -- Formula: Enchant Weapon - Superior Striking
				{ 20, 16244 }, -- Formula: Enchant Gloves - Greater Strength
				{ 21, 9214 }, -- Grimoire of Inferno
				{ 23, 12219 }, -- Unadorned Seal of Ascension
				{ 24, 12586 }, -- Immature Venom Sac
			},
		},
		{ -- LBRSGrayhoof
			name = AL["Mor Grayhoof"].." - "..format(AL["Tier %s Sets"], "0.5"),
			npcID = 16080,
			DisplayIDs = {{15997}},
			ExtraList = true,
			ContentPhase = 5,
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  22306 }, -- Ironweave Belt
				{ 2,  22325 }, -- Belt of the Trickster
				{ 3,  22319 }, -- Tome of Divine Right
				{ 4,  22398 }, -- Idol of Rejuvenation
				{ 5,  22322 }, -- The Jaw Breaker
			},
		},
	},
}

data["BlackmawHold"] = {
	name = AL["Blackmaw Hold"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {55, 55, 60},
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["DireMaulEastForever"] = {
	name = AL["Dire Maul East"],
	MapID = 2557,
	--InstanceID = 429,
	SubAreaIDs = { 34776, 33730 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "DireMaul",
	AtlasMapFile = {"DireMaulEast", "DireMaulEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {31, 55, 60},
	items = {
		{ -- DMEPusillin
			name = AL["Pusillin"],
			npcID = 14354,
			Level = 57,
			DisplayIDs = {{7552}},
			AtlasMapBossID = "1-2",
			[NORMAL_DIFF] = {
				{ 1,  18267 }, -- Recipe: Runn Tum Tuber Surprise
				{ 3,  18249 }, -- Crescent Key
			},
		},
		{ -- DMEZevrimThornhoof
			name = AL["Zevrim Thornhoof"],
			npcID = 11490,
			Level = 57,
			DisplayIDs = {{11335}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  18319 }, -- Fervent Helm
				{ 2,  18313 }, -- Helm of Awareness
				{ 3,  18323 }, -- Satyr's Bow
				{ 5,  18308 }, -- Clever Hat
				{ 6,  18306 }, -- Gloves of Shadowy Mist
			},
		},
		{ -- DMEHydro
			name = AL["Hydrospawn"],
			npcID = 13280,
			Level = 57,
			DisplayIDs = {{5489}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  18317 }, -- Tempest Talisman
				{ 2,  18322 }, -- Waterspout Boots
				{ 3,  18324 }, -- Waveslicer
				{ 5,  19268 }, -- Ace of Elementals
				{ 7,  18305 }, -- Breakwater Legguards
				{ 8,  18307 }, -- Riptide Shoes
			},
		},
		{ -- DMELethtendris
			name = AL["Lethtendris"],
			npcID = 14327,
			Level = 57,
			DisplayIDs = {{14378}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  18325 }, -- Felhide Cap
				{ 2,  18311 }, -- Quel'dorai Channeling Rod
				{ 4,  18301 }, -- Lethtendris's Wand
				{ 5,  18302 }, -- Band of Vigor
			},
		},
		{ -- DMEAlzzin
			name = AL["Alzzin the Wildshaper"],
			npcID = 11492,
			Level = 58,
			DisplayIDs = {{14416}},
			AtlasMapBossID = 5,
			SubAreaID = 33730,
			[NORMAL_DIFF] = {
				{ 1,  18328 }, -- Shadewood Cloak
				{ 2,  18312 }, -- Energized Chestplate
				{ 3,  18309 }, -- Gloves of Restoration
				{ 4,  18326 }, -- Razor Gauntlets
				{ 5,  18327 }, -- Whipvine Cord
				{ 6,  18318 }, -- Merciful Greaves
				{ 7,  18321 }, -- Energetic Rod
				{ 8,  18310 }, -- Fiendish Machete
				{ 9,  18314 }, -- Ring of Demonic Guile
				{ 10, 18315 }, -- Ring of Demonic Potency
			},
		},
		{ -- DMETrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  18289 }, -- Barbed Thorn Necklace
				{ 2,  18296 }, -- Marksman Bands
				{ 3,  18298 }, -- Unbridled Leggings
				{ 4,  18295 }, -- Phasing Boots
				{ 6,  18333 }, -- Libram of Focus
				{ 7,  18334 }, -- Libram of Protection
				{ 8,  18332 }, -- Libram of Rapidity
				{ 10, 18255 }, -- Runn Tum Tuber
				{ 11, 18297 }, -- Thornling Seed
			},
		},
		{ -- DMEIsalien
			name = AL["Isalien"].." - "..format(AL["Tier %s Sets"], "0.5"),
			npcID = 16097,
			DisplayIDs = {{16000}},
			ExtraList = true,
			ContentPhase = 5,
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  22304 }, -- Ironweave Gloves
				{ 2,  22472 }, -- Boots of Ferocity
				{ 3,  22401 }, -- Libram of Hope
				{ 4,  22345 }, -- Totem of Rebirth
				{ 5,  22315 }, -- Hammer of Revitalization
				{ 6,  22314 }, -- Huntsman's Harpoon
			},
		},
		DM_BOOKS,
		KEYS,
	},
}

data["UpperBlackrockSpireForever"] = {
	name = AL["Upper Blackrock Spire"],
	MapID = 1583,
	InstanceID = 229,
	SubAreaIDs = { 26670, 26668, 26684, 26662, 26642, 26683, 15492, 26666, 26715 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "UpperBlackrockSpire",
	AtlasMapFile = {"CL_BlackrockSpireUpper", "CL_BlackrockMountainEnt"},
	AtlasMapFile_AL = {"BlackrockSpireUpper", "BlackrockMountainEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({48, 55, 60}, {45, 58, 60}),
	items = {
		{ -- UBRSEmberseer
			name = AL["Pyroguard Emberseer"],
			npcID = 9816,
			Level = 60,
			SubAreaID = 26662,
			DisplayIDs = {{2172}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  16672 }, -- Gauntlets of Elements
				{ 3,  12929 }, -- Emberfury Talisman
				{ 4,  12927 }, -- TruestrikeShoulders
				{ 5,  12905 }, -- Wildfire Cape
				{ 6,  12926 }, -- Flaming Band
				{ 8,  23320 }, -- Tablet of Flame Shock VI
			},
		},
		{ -- UBRSSolakar
			name = AL["Solakar Flamewreath"],
			npcID = 10264,
			Level = 60,
			SubAreaID = 26666,
			DisplayIDs = {{9581}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  16695 }, -- Devout Mantle
				{ 3,  12609 }, -- Polychromatic Visionwrap
				{ 4,  12603 }, -- Nightbrace Tunic
				{ 5,  12589 }, -- Dustfeather Sash
				{ 6,  12606 }, -- Crystallized Girdle
				{ 8,  18657 }, -- Schematic: Hyper-Radiant Flame Reflector
			},
		},
		{ -- UBRSRunewatcher
			name = AL["Jed Runewatcher"],
			npcID = 10509,
			Level = 59,
			SubAreaID = 26642,
			DisplayIDs = {{9686}},
			AtlasMapBossID = 4,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  12604 }, -- Starfire Tiara
				{ 2,  12930 }, -- Briarwood Reed
				{ 3,  12605 }, -- Serpentine Skuller
			},
		},
		{ -- UBRSAnvilcrack
			name = AL["Goraluk Anvilcrack "],
			npcID = 10899,
			Level = 61,
			SubAreaID = 26642,
			DisplayIDs = {{10222}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  13502 }, -- Handcrafted Mastersmith Girdle
				{ 2,  13498 }, -- Handcrafted Mastersmith Leggings
				{ 3,  18047 }, -- Flame Walkers
				{ 4,  18048 }, -- Mastersmith's Hammer
				{ 6,  12834 }, -- Plans: Arcanite Champion
				{ 7,  12837 }, -- Plans: Masterwork Stormhammer
				{ 9, 18779 }, -- Bottom Half of Advanced Armorsmithing: Volume I
				{ 16, "INV_Box_01", nil, AL["Unforged Rune Covered Breastplate"], nil },
				{ 17, 12806 }, -- Unforged Rune Covered Breastplate
				{ 18, 12696 }, -- Plans: Demon Forged Breastplate
			},
		},
		{ -- UBRSGyth
			name = AL["Gyth"],
			npcID = 10339,
			Level = 62,
			SubAreaID = 26670,
			DisplayIDs = {{9806}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  12871 }, -- Chromatic Carapace
				{ 3,  16669 }, -- Pauldrons of Elements
				{ 5,  22225 }, -- Dragonskin Cowl
				{ 6,  12960 }, -- Tribal War Feathers
				{ 7,  12953 }, -- Dragoneye Coif
				{ 8,  12952 }, -- Gyth's Skull
				{ 10, 13522 }, -- Recipe: Flask of Chromatic Resistance
			},
		},
		{ -- UBRSRend
			name = AL["Warchief Rend Blackhand"],
			npcID = 10429,
			Level = 62,
			SubAreaID = 26670,
			DisplayIDs = {{9778}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  12590 }, -- Felstriker
				{ 3,  16733 }, -- Spaulders of Valor
				{ 5,  12587 }, -- Eye of Rend
				{ 6,  12588 }, -- Bonespike Shoulder
				{ 7,  12936 }, -- Battleborn Armbraces
				{ 8,  18104 }, -- Feralsurge Girdle
				{ 9,  12935 }, -- Warmaster Legguards
				{ 10, 18102 }, -- Dragonrider Boots
				{ 11, 22247 }, -- Faith Healer's Boots
				{ 12, 18103 }, -- Band of Rumination
				{ 13, 12940 }, -- Dal'Rend's Sacred Charge
				{ 14, 12939 }, -- Dal'Rend's Tribal Guardian
				{ 15, 12583 }, -- Blackhand Doomsaw
			},
		},
		{ -- UBRSBeast
			name = AL["The Beast"],
			npcID = 10430,
			Level = 62,
			SubAreaID = 26684,
			DisplayIDs = {{10193}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  12731 }, -- Pristine Hide of the Beast
				{ 3,  16729 }, -- Lightforge Spaulders
				{ 5,  12967 }, -- Bloodmoon Cloak
				{ 6,  12968 }, -- Frostweaver Cape
				{ 7,  12966 }, -- Blackmist Armguards
				{ 8,  12965 }, -- Spiritshroud Leggings
				{ 9,  12963 }, -- Blademaster Leggings
				{ 10, 12964 }, -- Tristam Legguards
				{ 11, 22311 }, -- Ironweave Boots
				{ 12, 12709 }, -- Finkle's Skinner
				{ 13, 12969 }, -- Seeping Willow
				{ 15, 24101 }, -- Book of Ferocious Bite V
				{ 16, 19227 }, -- Ace of Beasts
			},
		},
		{ -- UBRSDrakkisath
			name = AL["General Drakkisath"],
			npcID = 10363,
			Level = 62,
			SubAreaID = 26715,
			DisplayIDs = {{10115}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  12592 }, -- Blackblade of Shahram
				{ 3,  22267 }, -- Spellweaver's Turban
				{ 4,  13141 }, -- Tooth of Gnarr
				{ 5,  22269 }, -- Shadow Prowler's Cloak
				{ 6,  13142 }, -- Brigam Girdle
				{ 7,  13098 }, -- Painweaver Band
				{ 8,  22268 }, -- Draconic Infused Emblem
				{ 9,  22253 }, -- Tome of the Lost
				{ 10, 12602 }, -- Draconian Deflector
				{ 12, 15730 }, -- Pattern: Red Dragonscale Breastplate
				{ 14, 13519 }, -- Recipe: Flask of the Titans
				{ 16, 16690 }, -- Devout Robe
				{ 17, 16688 }, -- Magister's Robes
				{ 18, 16700 }, -- Dreadmist Robe
				{ 19, 16721 }, -- Shadowcraft Tunic
				{ 20, 16706 }, -- Wildheart Vest
				{ 21, 16674 }, -- Beaststalker's Tunic
				{ 22, 16666 }, -- Vest of Elements
				{ 23, 16726 }, -- Lightforge Breastplate
				{ 24, 16730 }, -- Breastplate of Valor
			},
		},
		{ -- UBRSTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  24102 }, -- Manual of Eviscerate IX
				{ 2,  13260 }, -- Wind Dancer Boots
				{ 4,  16696 }, -- Devout Belt
				{ 5,  16683 }, -- Magister's Bindings
				{ 6,  16703 }, -- Dreadmist Bracers
				{ 7,  16713 }, -- Shadowcraft Belt
				{ 8,  16681 }, -- Beaststalker's Bindings
				{ 9,  16680 }, -- Beaststalker's Belt
				{ 10, 16673 }, -- Cord of Elements
				{ 11, 16735 }, -- Bracers of Valor
				{ 16, 16247 }, -- Formula: Enchant 2H Weapon - Superior Impact
			},
		},
		{
			name = AL["Darkstone Tablet"],
			ExtraList = true,
			AtlasMapBossID = 3,
			specialType = "quest",
			[NORMAL_DIFF] = {
				{ 1,  12358 }, -- Darkstone Tablet
			},
		},
		{ -- UBRSValthalak
			name = AL["Lord Valthalak"].." - "..format(AL["Tier %s Sets"], "0.5"),
			npcID = 16042,
			DisplayIDs = {{14308}},
			ExtraList = true,
			ContentPhase = 5,
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  22302 }, -- Ironweave Cowl
				{ 2,  22340 }, -- Pendant of Celerity
				{ 3,  22337 }, -- Shroud of Domination
				{ 4,  22343 }, -- Handguards of Savagery
				{ 5,  22342 }, -- Leggings of Torment
				{ 6,  22339 }, -- Rune Band of Wizardry
				{ 7,  22336 }, -- Draconian Aegis of the Legion
				{ 8,  22335 }, -- Lord Valthalak's Staff of Command
			},
		},
	},
}

data["ShapersTerrace"] = {
	name = AL["Shaper's Terrace"],
	-- TODO: MapID, InstanceID, AtlasMapID/AtlasMapFile once known
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {58, 58, 60},
	items = {
		ComingSoon(), -- TODO: replace with real bosses/loot once known
	}
}

data["DireMaulWestForever"] = {
	name = AL["Dire Maul West"],
	MapID = 2557,
	--InstanceID = 429,
	SubAreaIDs = { 33748, 33749, 33750, 33710 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "DireMaul",
	AtlasMapFile = {"DireMaulWest", "DireMaulEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {31, 58, 60},
	items = {
		{ -- DMWTendrisWarpwood
			name = AL["Tendris Warpwood"],
			npcID = 11489,
			Level = 60,
			DisplayIDs = {{14383}},
			AtlasMapBossID = 2,
			SubAreaID = 33748,
			[NORMAL_DIFF] = {
				{ 1,  18393 }, -- Warpwood Binding
				{ 2,  18390 }, -- Tanglemoss Leggings
				{ 4,  18352 }, -- Petrified Bark Shield
				{ 5,  18353 }, -- Stoneflower Staff
			},
		},
		{ -- DMWIllyannaRavenoak
			name = AL["Illyanna Ravenoak"],
			npcID = 11488,
			Level = 60,
			DisplayIDs = {{11270}},
			SubAreaID = 33749,
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  18383 }, -- Force Imbued Gauntlets
				{ 2,  18386 }, -- Padre's Trousers
				{ 4,  18349 }, -- Gauntlets of Accuracy
				{ 5,  18347 }, -- Well Balanced Axe
			},
		},
		{ -- DMWMagisterKalendris
			name = AL["Magister Kalendris"],
			npcID = 11487,
			Level = 60,
			DisplayIDs = {{14384}},
			AtlasMapBossID = 4,
			SubAreaID = 33749,
			[NORMAL_DIFF] = {
				{ 1,  18374 }, -- Flamescarred Shoulders
				{ 2,  18397 }, -- Elder Magus Pendant
				{ 3,  18371 }, -- Mindtap Talisman
				{ 5,  18350 }, -- Amplifying Cloak
				{ 6,  18351 }, -- Magically Sealed Bracers
				{ 8,  22309 }, -- Pattern: Big Bag of Enchantment
				--{ 9,  22249 }, -- Big Bag of Enchantment
			},
		},
		{ -- DMWTsuzee
			name = AL["Tsu'zee"],
			npcID = 11467,
			Level = 60,
			DisplayIDs = {{11250}},
			specialType = "rare",
			AtlasMapBossID = 5,
			SubAreaID = 33749,
			[NORMAL_DIFF] = {
				{ 1,  18387 }, -- Brightspark Gloves
				{ 3,  18346 }, -- Threadbare Trousers
				{ 4,  18345 }, -- Murmuring Ring
			},
		},
		{ -- DMWImmolthar
			name = AL["Immol'thar"],
			npcID = 11496,
			Level = 61,
			DisplayIDs = {{14173}},
			AtlasMapBossID = 6,
			SubAreaID = 33750,
			[NORMAL_DIFF] = {
				{ 1,  18381 }, -- Evil Eye Pendant
				{ 2,  18384 }, -- Bile-etched Spaulders
				{ 3,  18389 }, -- Cloak of the Cosmos
				{ 4,  18385 }, -- Robe of Everlasting Night
				{ 5,  18394 }, -- Demon Howl Wristguards
				{ 6,  18377 }, -- Quickdraw Gloves
				{ 7,  18391 }, -- Eyestalk Cord
				{ 8,  18379 }, -- Odious Greaves
				{ 9,  18370 }, -- Vigilance Charm
				{ 10, 18372 }, -- Blade of the New Moon
			},
		},
		{ -- DMWPrinceTortheldrin
			name = AL["Prince Tortheldrin"],
			npcID = 11486,
			Level = 61,
			DisplayIDs = {{11256}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  18382 }, -- Fluctuating Cloak
				{ 2,  18373 }, -- Chestplate of Tranquility
				{ 3,  18375 }, -- Bracers of the Eclipse
				{ 4,  18378 }, -- Silvermoon Leggings
				{ 5,  18380 }, -- Eldritch Reinforced Legplates
				{ 6,  18395 }, -- Emerald Flame Ring
				{ 7,  18388 }, -- Stoneshatter
				{ 8,  18396 }, -- Mind Carver
				{ 9,  18376 }, -- Timeworn Mace
				{ 10, 18392 }, -- Distracting Dagger
			},
		},
		{ -- DMWTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  18340 }, -- Eidolon Talisman
				{ 2,  18344 }, -- Stonebark Gauntlets
				{ 3,  18338 }, -- Wand of Arcane Potency
				{ 5,  18333 }, -- Libram of Focus
				{ 6,  18334 }, -- Libram of Protection
				{ 7,  18332 }, -- Libram of Rapidity
			},
		},
		{ -- DMWRevanchion
			name = AL["Revanchion"],
			npcID = 14690,
			DisplayIDs = {{14695}},
			AtlasMapBossID = 2,
			ContentPhase = 6,
			specialType = "scourgeInvasion",
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1, 23127 }, -- Cloak of Revanchion
				{ 2, 23129 }, -- Bracers of Mending
				{ 3, 23128 }, -- The Shadow's Grasp
			},
		},
		{ -- DMWShendralarProvisioner
			name = AL["Shen'dralar Provisioner"],
			npcID = 14371,
			DisplayIDs = {{14412}},
			ExtraList = true,
			AtlasMapBossID = "1'",
			IgnoreAsSource = true,
			[NORMAL_DIFF] = {
				{ 1,  18487, [PRICE_EXTRA_ITTYPE] = "money:40000" }, -- Pattern: Mooncloth Robe
				--{ 2,  18486 }, -- Mooncloth Robe
			},
		},
		{ -- DMWHelnurath
			name = AL["Lord Hel'nurath"],
			npcID = 14506,
			DisplayIDs = {{14556}},
			ExtraList = true,
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  18757 }, -- Diabolic Mantle
				{ 2,  18754 }, -- Fel Hardened Bracers
				{ 3,  18755 }, -- Xorothian Firestick
				{ 4,  18756 }, -- Dreadguard's Protector
			},
		},
		DM_BOOKS,
		KEYS,
	},
}

data["DireMaulNorthForever"] = {
	name = AL["Dire Maul North"],
	MapID = 2557,
	--InstanceID = 429,
	SubAreaIDs = { 33774, 33775 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "DireMaulNorth",
	AtlasMapFile = {"DireMaulNorth", "DireMaulEnt"},
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {31, 58, 60},
	items = {
		{ -- DMNGuardMoldar
			name = AL["Guard Mol'dar"],
			npcID = 14326,
			Level = 59,
			DisplayIDs = {{11561}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  18494 }, -- Denwatcher's Shoulders
				{ 2,  18493 }, -- Bulky Iron Spaulders
				{ 3,  18496 }, -- Heliotrope Cloak
				{ 4,  18497 }, -- Sublime Wristguards
				{ 5,  18498 }, -- Hedgecutter
				{ 7,  18450 }, -- Robe of Combustion
				{ 8,  18458 }, -- Modest Armguards
				{ 9,  18459 }, -- Gallant's Wristguards
				{ 10, 18451 }, -- Hyena Hide Belt
				{ 11, 18462 }, -- Jagged Bone Fist
				{ 12, 18463 }, -- Ogre Pocket Knife
				{ 13, 18464 }, -- Gordok Nose Ring
				{ 14, 18460 }, -- Unsophisticated Hand Cannon
				{ 16, 18250 }, -- Gordok Shackle Key
				{ 17, 18268 }, -- Gordok Inner Door Key
			},
		},
		{ -- DMNStomperKreeg
			name = AL["Stomper Kreeg"],
			npcID = 14322,
			Level = 59,
			DisplayIDs = {{11545}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  18425 }, -- Kreeg's Mug
				{ 16, "INV_Box_01", nil, AL["Sells:"], nil },
				{ 17, 18269, [PRICE_EXTRA_ITTYPE] = "money:1500" }, -- Gordok Green Grog
				{ 18, 18284, [PRICE_EXTRA_ITTYPE] = "money:1500" }, -- Kreeg's Stout Beatdown
				{ 19, 18287, [PRICE_EXTRA_ITTYPE] = "money:200" }, -- Evermurky
				{ 20, 18288, [PRICE_EXTRA_ITTYPE] = "money:1500" }, -- Molasses Firewater
				{ 21, 9260, [PRICE_EXTRA_ITTYPE] = "money:1600" }, -- Volatile Rum
			},
		},
		{ -- DMNGuardFengus
			name = AL["Guard Fengus"],
			npcID = 14321,
			Level = 59,
			DisplayIDs = {{11561}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  18450 }, -- Robe of Combustion
				{ 2,  18458 }, -- Modest Armguards
				{ 3,  18459 }, -- Gallant's Wristguards
				{ 4,  18451 }, -- Hyena Hide Belt
				{ 5,  18462 }, -- Jagged Bone Fist
				{ 6,  18463 }, -- Ogre Pocket Knife
				{ 7,  18464 }, -- Gordok Nose Ring
				{ 8,  18460 }, -- Unsophisticated Hand Cannon
				{ 10, 18250 }, -- Gordok Shackle Key
				{ 16, "INV_Box_01", nil, AL["Fengus's Chest"], nil },
				{ 17, 18266 }, -- Gordok Courtyard Key
			},
		},
		{ -- DMNGuardSlipkik
			name = AL["Guard Slip'kik"],
			npcID = 14323,
			Level = 59,
			DisplayIDs = {{11561}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  18494 }, -- Denwatcher's Shoulders
				{ 2,  18493 }, -- Bulky Iron Spaulders
				{ 3,  18496 }, -- Heliotrope Cloak
				{ 4,  18497 }, -- Sublime Wristguards
				{ 5,  18498 }, -- Hedgecutter
				{ 7,  18450 }, -- Robe of Combustion
				{ 8,  18458 }, -- Modest Armguards
				{ 9,  18459 }, -- Gallant's Wristguards
				{ 10, 18451 }, -- Hyena Hide Belt
				{ 11, 18462 }, -- Jagged Bone Fist
				{ 12, 18463 }, -- Ogre Pocket Knife
				{ 13, 18464 }, -- Gordok Nose Ring
				{ 14, 18460 }, -- Unsophisticated Hand Cannon
				{ 16, 18250 }, -- Gordok Shackle Key
			},
		},
		{ -- DMNThimblejack
			name = AL["Knot Thimblejack's Cache"],
			AtlasMapBossID = 4,
			npcID = 14338,
			ObjectID = 179501,
			[NORMAL_DIFF] = {
				{ 1,  18414 }, -- Pattern: Belt of the Archmage
				{ 16,  18517 }, -- Pattern: Chromatic Cloak
				{ 17,  18518 }, -- Pattern: Hide of the Wild
				{ 18,  18519 }, -- Pattern: Shifting Cloak
				{ 5,  18415 }, -- Pattern: Felcloth Gloves
				{ 6,  18416 }, -- Pattern: Inferno Gloves
				{ 7,  18417 }, -- Pattern: Mooncloth Gloves
				{ 8,  18418 }, -- Pattern: Cloak of Warding
				{ 20, 18514 }, -- Pattern: Girdle of Insight
				{ 21, 18515 }, -- Pattern: Mongoose Boots
				{ 22, 18516 }, -- Pattern: Swift Flight Bracers
				{ 10, 18258 }, -- Gordok Ogre Suit
				{ 11, 18240 }, -- Ogre Tannin
			},
		},
		{ -- DMNCaptainKromcrush
			name = AL["Captain Kromcrush"],
			npcID = 14325,
			Level = 61,
			DisplayIDs = {{11564}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  18503 }, -- Kromcrush's Chestplate
				{ 2,  18505 }, -- Mugger's Belt
				{ 3,  18507 }, -- Boots of the Full Moon
				{ 4,  18502 }, -- Monstrous Glaive
			},
		},
		{ -- DMNChoRush
			name = AL["Cho'Rush the Observer"],
			npcID = 14324,
			Level = 60,
			DisplayIDs = {{11537}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  18490 }, -- Insightful Hood
				{ 2,  18483 }, -- Mana Channeling Wand
				{ 3,  18485 }, -- Observer's Shield
				{ 4,  18484 }, -- Cho'Rush's Blade
			},
		},
		{ -- DMNKingGordok
			name = AL["King Gordok"],
			npcID = 11501,
			Level = 62,
			DisplayIDs = {{11583}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  18526 }, -- Crown of the Ogre King
				{ 2,  18525 }, -- Bracers of Prosperity
				{ 3,  18527 }, -- Harmonious Gauntlets
				{ 4,  18524 }, -- Leggings of Destruction
				{ 5,  18521 }, -- Grimy Metal Boots
				{ 6,  18522 }, -- Band of the Ogre King
				{ 7,  18523 }, -- Brightly Glowing Stone
				{ 8,  18520 }, -- Barbarous Blade
				{ 16, 19258 }, -- Ace of Warlords
				{ 18, 18780 }, -- Top Half of Advanced Armorsmithing: Volume I
			},
		},
		{ -- DMNTRIBUTERUN
			name = AL["Tribute"],
			ExtraList = true,
			npcID = 14324,
			ObjectID = 179564,
			[NORMAL_DIFF] = {
				{ 1,  18538 }, -- Treant's Bane
				{ 3,  18528 }, -- Cyclone Spaulders
				{ 4,  18495 }, -- Redoubt Cloak
				{ 5,  18532 }, -- Mindsurge Robe
				{ 6,  18530 }, -- Ogre Forged Hauberk
				{ 7,  18533 }, -- Gordok Bracers of Power
				{ 8,  18529 }, -- Elemental Plate Girdle
				{ 9,  18500 }, -- Tarnished Elven Ring
				{ 10, 18537 }, -- Counterattack Lodestone
				{ 11, 18499 }, -- Barrier Shield
				{ 12, 18531 }, -- Unyielding Maul
				{ 13, 18534 }, -- Rod of the Ogre Magi
				{ 16, 18479 }, -- Carrion Scorpid Helm
				{ 17, 18480 }, -- Scarab Plate Helm
				{ 18, 18478 }, -- Hyena Hide Jerkin
				{ 19, 18475 }, -- Oddly Magical Belt
				{ 20, 18477 }, -- Shaggy Leggings
				{ 21, 18476 }, -- Mud Stained Boots
				{ 22, 18482 }, -- Ogre Toothpick Shooter
				{ 23, 18481 }, -- Skullcracking Mace
				{ 25, 18655 }, -- Schematic: Major Recombobulator
			},
		},
		{ -- DMNTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  18250 }, -- Gordok Shackle Key
				{ 3,  18333 }, -- Libram of Focus
				{ 4,  18334 }, -- Libram of Protection
				{ 5,  18332 }, -- Libram of Rapidity
				{ 7,  18640 }, -- Happy Fun Rock
			},
		},
		DM_BOOKS,
		KEYS,
	},
}

data["ScholomanceForever"] = {
	MapID = 2057,
	InstanceID = 289,
	SubAreaIDs = { 32549, 32574, 32567, 32577, 32566, 32565, 32581, 32579, 32573, 32568, 32576, 32569 },
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Scholomance",
	AtlasMapFile = "CL_Scholomance",
	AtlasMapFile_AL = "Scholomance",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = {45, 58, 60},
	items = {
		{ -- SCHOLOBlood
			name = AL["Blood Steward of Kirtonos"],
			npcID = 14861,
			Level = 61,
			SubAreaID = 32573,
			DisplayIDs = {{10925}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  13523 }, -- Blood of Innocents
			},
		},
		{ -- SCHOLOKirtonostheHerald
			name = AL["Kirtonos the Herald"],
			npcID = 10506,
			Level = 60,
			SubAreaID = 32574,
			DisplayIDs = {{7534}},
			AtlasMapBossID = 2,
			[NORMAL_DIFF] = {
				{ 1,  16734 }, -- Boots of Valor
				{ 3,  13960 }, -- Heart of the Fiend
				{ 4,  13955 }, -- Stoneform Shoulders
				{ 5,  13969 }, -- Loomguard Armbraces
				{ 6,  13957 }, -- Gargoyle Slashers
				{ 7,  13956 }, -- Clutch of Andros
				{ 8,  13967 }, -- Windreaver Greaves
				{ 9,  14024 }, -- Frightalon
				{ 10, 13983 }, -- Gravestone War Axe
			},
		},
		{ -- SCHOLOJandiceBarov
			name = AL["Jandice Barov"],
			npcID = 10503,
			Level = 61,
			DisplayIDs = {{11073}},
			AtlasMapBossID = 3,
			[NORMAL_DIFF] = {
				{ 1,  16701 }, -- Dreadmist Mantle
				{ 3,  14548 }, -- Royal Cap Spaulders
				{ 4,  18689 }, -- Phantasmal Cloak
				{ 5,  14543 }, -- Darkshade Gloves
				{ 6,  14545 }, -- Ghostloom Leggings
				{ 7,  18690 }, -- Wraithplate Leggings
				{ 8,  14541 }, -- Barovian Family Sword
				{ 9,  22394 }, -- Staff of Metanoia
				{ 12, 13523 }, -- Blood of Innocents
			},
		},
		{ -- SCHOLORattlegore
			name = AL["Rattlegore"],
			npcID = 11622,
			Level = 61,
			SubAreaID = 32577,
			DisplayIDs = {{12073}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  16711 }, -- Shadowcraft Boots
				{ 3,  14539 }, -- Bone Ring Helm
				{ 4,  14538 }, -- Deadwalker Mantle
				{ 5,  18686 }, -- Bone Golem Shoulders
				{ 6,  14537 }, -- Corpselight Greaves
				{ 7,  14528 }, -- Rattlecage Buckler
				{ 8,  14531 }, -- Frightskull Shaft
				{ 10, 18782 }, -- Top Half of Advanced Armorsmithing: Volume II
				{ 12, 13873 }, -- Viewing Room Key
			},
		},
		{ -- SCHOLODeathKnight
			name = AL["Death Knight Darkreaver"],
			npcID = 14516,
			Level = 61,
			SubAreaID = 32577,
			DisplayIDs = {{14591}},
			AtlasMapBossID = 5,
			[NORMAL_DIFF] = {
				{ 1,  18760 }, -- Necromantic Band
				{ 2,  18761 }, -- Oblivion's Touch
				{ 3,  18758 }, -- Specter's Blade
				{ 4,  18759 }, -- Malicious Axe
			},
		},
		{ -- SCHOLOMarduk
			name = AL["Marduk Blackpool"],
			npcID = 10433,
			Level = 58,
			SubAreaID = 32576,
			DisplayIDs = {{10248}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  18692 }, -- Death Knight Sabatons
				{ 2,  14576 }, -- Ebon Hilt of Marduk
			},
		},
		{ -- SCHOLOVectus
			name = AL["Vectus"],
			npcID = 10432,
			Level = 60,
			SubAreaID = 32576,
			DisplayIDs = {{2606}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  18691 }, -- Dark Advisor's Pendant
				{ 2,  14577 }, -- Skullsmoke Pants
			},
		},
		{ -- SCHOLORasFrostwhisper
			name = AL["Ras Frostwhisper"],
			npcID = 10508,
			Level = 62,
			SubAreaID = 32579,
			DisplayIDs = {{7919}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  13314 }, -- Alanna's Embrace
				{ 3,  16689 }, -- Magister's Mantle
				{ 5,  14503 }, -- Death's Clutch
				{ 6,  14340 }, -- Freezing Lich Robes
				{ 7,  18693 }, -- Shivery Handwraps
				{ 8,  14525 }, -- Boneclenched Gauntlets
				{ 9,  14502 }, -- Frostbite Girdle
				{ 10, 14522 }, -- Maelstrom Leggings
				{ 11, 18694 }, -- Shadowy Mail Greaves
				{ 12, 18695 }, -- Spellbound Tome
				{ 13, 18696 }, -- Intricately Runed Shield
				{ 14, 13952 }, -- Iceblade Hacker
				{ 15, 14487 }, -- Bonechill Hammer
				{ 16, 13521 }, -- Recipe: Flask of Supreme Power
			},
		},
		{ -- SCHOLOInstructorMalicia
			name = AL["Instructor Malicia"],
			npcID = 10505,
			Level = 60,
			SubAreaID = 32567,
			DisplayIDs = {{11069}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  16710 }, -- Shadowcraft Bracers
				{ 4,  18681 }, -- Burial Shawl
				{ 5,  14633 }, -- Necropile Mantle
				{ 6,  14626 }, -- Necropile Robe
				{ 7,  14637 }, -- Cadaverous Armor
				{ 8,  14611 }, -- Bloodmail Hauberk
				{ 9,  14624 }, -- Deathbone Chestplate
				{ 10, 14629 }, -- Necropile Cuffs
				{ 11, 14640 }, -- Cadaverous Gloves
				{ 12, 14615 }, -- Bloodmail Gauntlets
				{ 13, 14622 }, -- Deathbone Gauntlets
				{ 14, 14636 }, -- Cadaverous Belt
				{ 15, 14614 }, -- Bloodmail Belt
				{ 16, 14620 }, -- Deathbone Girdle
				{ 17, 14632 }, -- Necropile Leggings
				{ 18, 14638 }, -- Cadaverous Leggings
				{ 19, 18682 }, -- Ghoul Skin Leggings
				{ 20, 14612 }, -- Bloodmail Legguards
				{ 21, 14623 }, -- Deathbone Legguards
				{ 22, 14631 }, -- Necropile Boots
				{ 23, 14641 }, -- Cadaverous Walkers
				{ 24, 14616 }, -- Bloodmail Boots
				{ 25, 14621 }, -- Deathbone Sabatons
				{ 26, 18684 }, -- Dimly Opalescent Ring
				{ 27, 23201 }, -- Libram of Divinity
				{ 28, 23200 }, -- Totem of Sustaining
				{ 29, 18680 }, -- Ancient Bone Bow
				{ 30, 18683 }, -- Hammer of the Vesper
			},
		},
		{ -- SCHOLODoctorTheolenKrastinov
			name = AL["Doctor Theolen Krastinov"],
			npcID = 11261,
			Level = 60,
			SubAreaID = 32565,
			DisplayIDs = {{10901}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  16684 }, -- Magister's Gloves
				{ 2,  14617 }, -- Sawbones Shirt
				{ 4,  18681 }, -- Burial Shawl
				{ 5,  14633 }, -- Necropile Mantle
				{ 6,  14626 }, -- Necropile Robe
				{ 7,  14637 }, -- Cadaverous Armor
				{ 8,  14611 }, -- Bloodmail Hauberk
				{ 9,  14624 }, -- Deathbone Chestplate
				{ 10, 14629 }, -- Necropile Cuffs
				{ 11, 14640 }, -- Cadaverous Gloves
				{ 12, 14615 }, -- Bloodmail Gauntlets
				{ 13, 14622 }, -- Deathbone Gauntlets
				{ 14, 14636 }, -- Cadaverous Belt
				{ 15, 14614 }, -- Bloodmail Belt
				{ 16, 14620 }, -- Deathbone Girdle
				{ 17, 14632 }, -- Necropile Leggings
				{ 18, 14638 }, -- Cadaverous Leggings
				{ 19, 18682 }, -- Ghoul Skin Leggings
				{ 20, 14612 }, -- Bloodmail Legguards
				{ 21, 14623 }, -- Deathbone Legguards
				{ 22, 14631 }, -- Necropile Boots
				{ 23, 14641 }, -- Cadaverous Walkers
				{ 24, 14616 }, -- Bloodmail Boots
				{ 25, 14621 }, -- Deathbone Sabatons
				{ 26, 18684 }, -- Dimly Opalescent Ring
				{ 27, 23201 }, -- Libram of Divinity
				{ 28, 23200 }, -- Totem of Sustaining
				{ 29, 18680 }, -- Ancient Bone Bow
				{ 30, 18683 }, -- Hammer of the Vesper
			},
		},
		{ -- SCHOLOLorekeeperPolkelt
			name = AL["Lorekeeper Polkelt"],
			npcID = 10901,
			Level = 60,
			SubAreaID = 32566,
			DisplayIDs = {{11492}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  16705 }, -- Dreadmist Wraps
				{ 4,  18681 }, -- Burial Shawl
				{ 5,  14633 }, -- Necropile Mantle
				{ 6,  14626 }, -- Necropile Robe
				{ 7,  14637 }, -- Cadaverous Armor
				{ 8,  14611 }, -- Bloodmail Hauberk
				{ 9,  14624 }, -- Deathbone Chestplate
				{ 10, 14629 }, -- Necropile Cuffs
				{ 11, 14640 }, -- Cadaverous Gloves
				{ 12, 14615 }, -- Bloodmail Gauntlets
				{ 13, 14622 }, -- Deathbone Gauntlets
				{ 14, 14636 }, -- Cadaverous Belt
				{ 15, 14614 }, -- Bloodmail Belt
				{ 16, 14620 }, -- Deathbone Girdle
				{ 17, 14632 }, -- Necropile Leggings
				{ 18, 14638 }, -- Cadaverous Leggings
				{ 19, 18682 }, -- Ghoul Skin Leggings
				{ 20, 14612 }, -- Bloodmail Legguards
				{ 21, 14623 }, -- Deathbone Legguards
				{ 22, 14631 }, -- Necropile Boots
				{ 23, 14641 }, -- Cadaverous Walkers
				{ 24, 14616 }, -- Bloodmail Boots
				{ 25, 14621 }, -- Deathbone Sabatons
				{ 26, 18684 }, -- Dimly Opalescent Ring
				{ 27, 23201 }, -- Libram of Divinity
				{ 28, 23200 }, -- Totem of Sustaining
				{ 29, 18680 }, -- Ancient Bone Bow
				{ 30, 18683 }, -- Hammer of the Vesper
			},
		},
		{ -- SCHOLOTheRavenian
			name = AL["The Ravenian"],
			npcID = 10507,
			Level = 60,
			SubAreaID = 32569,
			DisplayIDs = {{10433}},
			AtlasMapBossID = 11,
			[NORMAL_DIFF] = {
				{ 1,  16716 }, -- Wildheart Belt
				{ 4,  18681 }, -- Burial Shawl
				{ 5,  14633 }, -- Necropile Mantle
				{ 6,  14626 }, -- Necropile Robe
				{ 7,  14637 }, -- Cadaverous Armor
				{ 8,  14611 }, -- Bloodmail Hauberk
				{ 9,  14624 }, -- Deathbone Chestplate
				{ 10, 14629 }, -- Necropile Cuffs
				{ 11, 14640 }, -- Cadaverous Gloves
				{ 12, 14615 }, -- Bloodmail Gauntlets
				{ 13, 14622 }, -- Deathbone Gauntlets
				{ 14, 14636 }, -- Cadaverous Belt
				{ 15, 14614 }, -- Bloodmail Belt
				{ 16, 14620 }, -- Deathbone Girdle
				{ 17, 14632 }, -- Necropile Leggings
				{ 18, 14638 }, -- Cadaverous Leggings
				{ 19, 18682 }, -- Ghoul Skin Leggings
				{ 20, 14612 }, -- Bloodmail Legguards
				{ 21, 14623 }, -- Deathbone Legguards
				{ 22, 14631 }, -- Necropile Boots
				{ 23, 14641 }, -- Cadaverous Walkers
				{ 24, 14616 }, -- Bloodmail Boots
				{ 25, 14621 }, -- Deathbone Sabatons
				{ 26, 18684 }, -- Dimly Opalescent Ring
				{ 27, 23201 }, -- Libram of Divinity
				{ 28, 23200 }, -- Totem of Sustaining
				{ 29, 18680 }, -- Ancient Bone Bow
				{ 30, 18683 }, -- Hammer of the Vesper
			},
		},
		{ -- SCHOLOLordAlexeiBarov
			name = AL["Lord Alexei Barov"],
			npcID = 10504,
			Level = 60,
			SubAreaID = 32549,
			DisplayIDs = {{11072}},
			AtlasMapBossID = 12,
			[NORMAL_DIFF] = {
				{ 1,  16722 }, -- Lightforge Bracers
				{ 4,  18681 }, -- Burial Shawl
				{ 5,  14633 }, -- Necropile Mantle
				{ 6,  14626 }, -- Necropile Robe
				{ 7,  14637 }, -- Cadaverous Armor
				{ 8,  14611 }, -- Bloodmail Hauberk
				{ 9,  14624 }, -- Deathbone Chestplate
				{ 10, 14629 }, -- Necropile Cuffs
				{ 11, 14640 }, -- Cadaverous Gloves
				{ 12, 14615 }, -- Bloodmail Gauntlets
				{ 13, 14622 }, -- Deathbone Gauntlets
				{ 14, 14636 }, -- Cadaverous Belt
				{ 15, 14614 }, -- Bloodmail Belt
				{ 16, 14620 }, -- Deathbone Girdle
				{ 17, 14632 }, -- Necropile Leggings
				{ 18, 14638 }, -- Cadaverous Leggings
				{ 19, 18682 }, -- Ghoul Skin Leggings
				{ 20, 14612 }, -- Bloodmail Legguards
				{ 21, 14623 }, -- Deathbone Legguards
				{ 22, 14631 }, -- Necropile Boots
				{ 23, 14641 }, -- Cadaverous Walkers
				{ 24, 14616 }, -- Bloodmail Boots
				{ 25, 14621 }, -- Deathbone Sabatons
				{ 26, 18684 }, -- Dimly Opalescent Ring
				{ 27, 23201 }, -- Libram of Divinity
				{ 28, 23200 }, -- Totem of Sustaining
				{ 29, 18680 }, -- Ancient Bone Bow
				{ 30, 18683 }, -- Hammer of the Vesper
			},
		},
		{ -- SCHOLOLadyIlluciaBarov
			name = AL["Lady Illucia Barov"],
			npcID = 10502,
			Level = 60,
			SubAreaID = 32568,
			DisplayIDs = {{11835}},
			AtlasMapBossID = 13,
			[NORMAL_DIFF] = {
				{ 4,  18681 }, -- Burial Shawl
				{ 5,  14633 }, -- Necropile Mantle
				{ 6,  14626 }, -- Necropile Robe
				{ 7,  14637 }, -- Cadaverous Armor
				{ 8,  14611 }, -- Bloodmail Hauberk
				{ 9,  14624 }, -- Deathbone Chestplate
				{ 10, 14629 }, -- Necropile Cuffs
				{ 11, 14640 }, -- Cadaverous Gloves
				{ 12, 14615 }, -- Bloodmail Gauntlets
				{ 13, 14622 }, -- Deathbone Gauntlets
				{ 14, 14636 }, -- Cadaverous Belt
				{ 15, 14614 }, -- Bloodmail Belt
				{ 16, 14620 }, -- Deathbone Girdle
				{ 17, 14632 }, -- Necropile Leggings
				{ 18, 14638 }, -- Cadaverous Leggings
				{ 19, 18682 }, -- Ghoul Skin Leggings
				{ 20, 14612 }, -- Bloodmail Legguards
				{ 21, 14623 }, -- Deathbone Legguards
				{ 22, 14631 }, -- Necropile Boots
				{ 23, 14641 }, -- Cadaverous Walkers
				{ 24, 14616 }, -- Bloodmail Boots
				{ 25, 14621 }, -- Deathbone Sabatons
				{ 26, 18684 }, -- Dimly Opalescent Ring
				{ 27, 23201 }, -- Libram of Divinity
				{ 28, 23200 }, -- Totem of Sustaining
				{ 29, 18680 }, -- Ancient Bone Bow
				{ 30, 18683 }, -- Hammer of the Vesper
			},
		},
		{ -- SCHOLODarkmasterGandling
			name = AL["Darkmaster Gandling"],
			npcID = 1853,
			Level = 61,
			SubAreaID = 32581,
			DisplayIDs = {{11070}},
			AtlasMapBossID = 14,
			[NORMAL_DIFF] = {
				{ 1,  13937 }, -- Headmaster's Charge
				{ 2,  14514 }, -- Pattern: Robe of the Void
				{ 4,  16693 }, -- Devout Crown
				{ 5,  16686 }, -- Magister's Crown
				{ 6,  16698 }, -- Dreadmist Mask
				{ 7,  16707 }, -- Shadowcraft Cap
				{ 8,  16720 }, -- Wildheart Cowl
				{ 9, 16677 }, -- Beaststalker's Cap
				{ 10, 16667 }, -- Coif of Elements
				{ 11, 16727 }, -- Lightforge Helm
				{ 12, 16731 }, -- Helm of Valor
				{ 16, 13944 }, -- Tombstone Breastplate
				{ 17, 13951 }, -- Vigorsteel Vambraces
				{ 18, 13950 }, -- Detention Strap
				{ 19, 13398 }, -- Boots of the Shrieker
				{ 20, 22433 }, -- Don Mauricio's Band of Domination
				{ 21, 13938 }, -- Bonecreeper Stylus
				{ 22, 13953 }, -- Silent Fang
				{ 23, 13964 }, -- Witchblade
				{ 25, 19276 }, -- Ace of Portals
				{ 27, 13501 }, -- Recipe: Major Mana Potion
			},
		},
		{ -- SCHOLOTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  16685 }, -- Magister's Belt
				{ 2,  16702 }, -- Dreadmist Belt
				{ 3,  16710 }, -- Shadowcraft Bracers
				{ 4,  16714 }, -- Wildheart Bracers
				{ 5,  16716 }, -- Wildheart Belt
				{ 6,  16671 }, -- Bindings of Elements
				{ 7,  16722 }, -- Lightforge Bracers
				{ 9,  12843 }, -- Corruptor's Scourgestone
				{ 10, 12841 }, -- Invader's Scourgestone
				{ 11, 12840 }, -- Minion's Scourgestone
				{ 13, 20520 }, -- Dark Rune
				{ 14, 12753 }, -- Skin of Shadow
				{ 16, 18698 }, -- Tattered Leather Hood
				{ 17, 18699 }, -- Icy Tomb Spaulders
				{ 18, 14536 }, -- Bonebrace Hauberk
				{ 19, 18700 }, -- Malefic Bracers
				{ 20, 18702 }, -- Belt of the Ordained
				{ 21, 18697 }, -- Coldstone Slippers
				{ 22, 18701 }, -- Innervating Band
				{ 24, 16254 }, -- Formula: Enchant Weapon - Lifestealing
				{ 25, 16255 }, -- Formula: Enchant 2H Weapon - Major Spirit
				{ 26, 15773 }, -- Pattern: Wicked Leather Armor
				{ 27, 15776 }, -- Pattern: Runic Leather Armor
				{ 29, 13920 }, -- Healthy Dragon Scale
			},
		},
		{ -- SCHOLOLordB
			name = AL["Lord Blackwood"],
			npcID = 14695,
			DisplayIDs = {{14699}},
			AtlasMapBossID = 2,
			ContentPhase = 6,
			specialType = "scourgeInvasion",
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  23132 }, -- Lord Blackwood's Blade
				{ 2,  23156 }, -- Blackwood's Thigh
				{ 3,  23139 }, -- Lord Blackwood's Buckler
			},
		},
		{ -- SCHOLOKormok
			name = AL["Kormok"].." - "..format(AL["Tier %s Sets"], "0.5"),
			npcID = 16118,
			DisplayIDs = {{16020}},
			ExtraList = true,
			ContentPhase = 5,
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1,  22303 }, -- Ironweave Pants
				{ 2,  22326 }, -- Amalgam's Band
				{ 3,  22331 }, -- Band of the Steadfast Hero
				{ 4,  22332 }, -- Blade of Necromancy
				{ 5,  22333 }, -- Hammer of Divine Might
			},
		},
		KEYS,
	},
}

data["StratholmeForever"] = {
	MapID = 2017,
	InstanceID = 329,
	SubAreaIDs = {
		-- Living
		32319, 32320, 32367, 32331, 32357, 32281, 32285, 32277,
		-- Undead
		32342, 32322, 32303, 32301, 32352,
		-- Ziggurats
		32344, 32345, 32349,
	},
	AtlasModule = ATLAS_MODULE_NAME,
	AtlasMapID = "Stratholme",
	AtlasMapFile = "CL_Stratholme",
	AtlasMapFile_AL = "Stratholme",
	ContentType = DUNGEON_CONTENT,
	LoadDifficulty = NORMAL_DIFF,
	LevelRange = GetForVersion({37, 58, 60}, {45, 58, 60}),
	items = {
		{ -- STRATSkull
			name = AL["Skul"],
			NameColor = GREEN,
			npcID = 10393,
			Level = 58,
			DisplayIDs = {{2606}},
			AtlasMapBossID = 1,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13395 }, -- Skul's Fingerbone Claws
				{ 2,  13394 }, -- Skul's Cold Embrace
				{ 3,  13396 }, -- Skul's Ghastly Touch
			},
		},
		{ -- STRATStratholmeCourier
			name = AL["Stratholme Courier"],
			NameColor = GREEN,
			npcID = 11082,
			Level = 57,
			DisplayIDs = {{10547}},
			AtlasMapBossID = 1,
			[NORMAL_DIFF] = {
				{ 1,  13303 }, -- Crusaders' Square Postbox Key
				{ 2,  13305 }, -- Elders' Square Postbox Key
				{ 3,  13304 }, -- Festival Lane Postbox Key
				{ 4,  13307 }, -- Fras Siabi's Postbox Key
				{ 5,  13306 }, -- King's Square Postbox Key
				{ 6,  13302 }, -- Market Row Postbox Key
			},
		},
		{ -- STRATHearthsingerForresten
			name = AL["Hearthsinger Forresten"],
			NameColor = GREEN,
			npcID = 10558,
			Level = 57,
			SubAreaID = 32277,
			DisplayIDs = {{10482}},
			AtlasMapBossID = 3,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  16682 }, -- Magister's Boots
				{ 3,  13378 }, -- Songbird Blouse
				{ 4,  13384 }, -- Rainbow Girdle
				{ 5,  13383 }, -- Woollies of the Prancing Minstrel
				{ 6,  13379 }, -- Piccolo of the Flaming Fire
			},
		},
		{ -- STRATTheUnforgiven
			name = AL["The Unforgiven"],
			NameColor = GREEN,
			npcID = 10516,
			Level = 57,
			SubAreaID = 32281,
			DisplayIDs = {{10771}},
			AtlasMapBossID = 4,
			[NORMAL_DIFF] = {
				{ 1,  16717 }, -- Wildheart Gloves
				{ 3,  13404 }, -- Mask of the Unforgiven
				{ 4,  13405 }, -- Wailing Nightbane Pauldrons
				{ 5,  13409 }, -- Tearfall Bracers
				{ 6,  13408 }, -- Soul Breaker
			},
		},
		{ -- STRATPostmaster
			name = AL["Postmaster Malown"],
			NameColor = GREEN,
			npcID = 11143,
			Level = 60,
			DisplayIDs = {{10669}},
			AtlasMapBossID = "6'",
			[NORMAL_DIFF] = {
				{ 1,  13390 }, -- The Postmaster's Band
				{ 2,  13388 }, -- The Postmaster's Tunic
				{ 3,  13389 }, -- The Postmaster's Trousers
				{ 4,  13391 }, -- The Postmaster's Treads
				{ 5,  13392 }, -- The Postmaster's Seal
				{ 6,  13393 }, -- Malown's Slam
			},
		},
		{ -- STRATTimmytheCruel
			name = AL["Timmy the Cruel"],
			NameColor = GREEN,
			npcID = 10808,
			Level = 58,
			SubAreaID = 32319,
			DisplayIDs = {{571}},
			AtlasMapBossID = 6,
			[NORMAL_DIFF] = {
				{ 1,  16724 }, -- Lightforge Gauntlets
				{ 3,  13400 }, -- Vambraces of the Sadist
				{ 4,  13403 }, -- Grimgore Noose
				{ 5,  13402 }, -- Timmy's Galoshes
				{ 6,  13401 }, -- The Cruel Hand of Timmy
			},
		},
		{ -- STRATMalorsStrongbox
			name = AL["Malor the Zealous"],
			NameColor = GREEN,
			npcID = 11032,
			ObjectID = 176112,
			Level = 60,
			SubAreaID = 32319,
			DisplayIDs = {{10458}},
			AtlasMapBossID = 7,
			[NORMAL_DIFF] = {
				{ 1, "INV_Box_01", nil, AL["Malors Strongbox"], nil },
				{ 2,  12845 }, -- Medallion of Faith
			},
		},
		{ -- STRATCrimsonHammersmith
			name = AL["Crimson Hammersmith"],
			NameColor = GREEN,
			npcID = 11120,
			Level = 60,
			SubAreaID = 32357,
			DisplayIDs = {{10637}},
			AtlasMapBossID = 8,
			[NORMAL_DIFF] = {
				{ 1,  18781 }, -- Bottom Half of Advanced Armorsmithing: Volume II
				--{ 3,  12824 }, -- Plans: Enchanted Battlehammer
			},
		},
		{ -- STRATCannonMasterWilley
			name = AL["Cannon Master Willey"],
			NameColor = GREEN,
			npcID = 10997,
			Level = 60,
			SubAreaID = 32357,
			DisplayIDs = {{10674}},
			AtlasMapBossID = 9,
			[NORMAL_DIFF] = {
				{ 1,  16708 }, -- Shadowcraft Spaulders
				{ 3,  22407 }, -- Helm of the New Moon
				{ 4,  22403 }, -- Diana's Pearl Necklace
				{ 5,  22405 }, -- Mantle of the Scarlet Crusade
				{ 6,  18721 }, -- Barrage Girdle
				{ 7,  13381 }, -- Master Cannoneer Boots
				{ 8,  13382 }, -- Cannonball Runner
				{ 9,  13380 }, -- Willey's Portable Howitzer
				{ 10, 13377 }, -- Miniature Cannon Balls
				{ 11, 22404 }, -- Willey's Back Scratcher
				{ 12, 22406 }, -- Redemption
				{ 16, 12839 }, -- Plans: Heartseeker
			},
		},
		{ -- STRATArchivistGalford
			name = AL["Archivist Galford"],
			NameColor = GREEN,
			npcID = 10811,
			Level = 60,
			SubAreaID = 32331,
			DisplayIDs = {{10544}},
			AtlasMapBossID = 10,
			[NORMAL_DIFF] = {
				{ 1,  16692 }, -- Devout Gloves
				{ 3,  13386 }, -- Archivist Cape
				{ 4,  13387 }, -- Foresight Girdle
				{ 5,  18716 }, -- Ash Covered Boots
				{ 6,  13385 }, -- Tome of Knowledge
				{ 8,  12811 }, -- Righteous Orb
				{ 10, 22897 }, -- Tome of Conjure Food VII
			},
		},
		{ -- STRATBalnazzar
			name = AL["Balnazzar"],
			NameColor = GREEN,
			npcID = {10812, 10813},
			Level = 999,
			SubAreaID = 32367,
			DisplayIDs = {{10545}, {10691}},
			AtlasMapBossID = 11,
			[NORMAL_DIFF] = {
				{ 1,  13353 }, -- Book of the Dead
				{ 2,  14512 }, -- Pattern: Truefaith Vestments
				{ 4,  16725 }, -- Lightforge Boots
				{ 6,  13359 }, -- Crown of Tyranny
				{ 7,  18718 }, -- Grand Crusader's Helm
				{ 8,  12103 }, -- Star of Mystaria
				{ 9, 18720 }, -- Shroud of the Nathrezim
				{ 10, 13358 }, -- Wyrmtongue Shoulders
				{ 11, 13369 }, -- Fire Striders
				{ 12, 13360 }, -- Gift of the Elven Magi
				{ 13, 18717 }, -- Hammer of the Grand Crusader
				{ 14,  22334 }, -- Band of Mending
				{ 15, 13348 }, -- Demonshear
				{ 16, 13520 }, -- Recipe: Flask of Distilled Wisdom
				{ 18, 13250 }, -- Head of Balnazzar
			},
		},
		{ -- STRATMagistrateBarthilas
			name = AL["Magistrate Barthilas"],
			NameColor = PURP,
			npcID = 10435,
			Level = 58,
			SubAreaID = 32342,
			DisplayIDs = {{10433}},
			AtlasMapBossID = 12,
			[NORMAL_DIFF] = {
				{ 1,  18727 }, -- Crimson Felt Hat
				{ 2,  13376 }, -- Royal Tribunal Cloak
				{ 3,  18726 }, -- Magistrate's Cuffs
				{ 4,  18722 }, -- Death Grips
				{ 5,  23198 }, -- Idol of Brutality
				{ 6,  18725 }, -- Peacemaker
				{ 8,  12382 }, -- Key to the City
			},
		},
		{ -- STRATStonespine
			name = AL["Stonespine"],
			NameColor = PURP,
			npcID = 10809,
			Level = 60,
			SubAreaID = 32303,
			DisplayIDs = {{7856}},
			AtlasMapBossID = 14,
			specialType = "rare",
			[NORMAL_DIFF] = {
				{ 1,  13397 }, -- Stoneskin Gargoyle Cape
				{ 2,  13954 }, -- Verdant Footpads
				{ 3,  13399 }, -- Gargoyle Shredder Talons
			},
		},
		{ -- STRATBaronessAnastari
			name = AL["Baroness Anastari"],
			NameColor = PURP,
			npcID = 10436,
			Level = 59,
			SubAreaID = 32344,
			DisplayIDs = {{10698}},
			AtlasMapBossID = 15,
			[NORMAL_DIFF] = {
				{ 1,  16704 }, -- Dreadmist Sandals
				{ 3,  18728 }, -- Anastari Heirloom
				{ 4,  18730 }, -- Shadowy Laced Handwraps
				{ 5,  18729 }, -- Screeching Bow
				{ 6,  13534 }, -- Banshee Finger
				{ 8,  13538 }, -- Windshrieker Pauldrons
				{ 9,  13535 }, -- Coldtouch Phantom Wraps
				{ 10, 13537 }, -- Chillhide Bracers
				{ 11, 13539 }, -- Banshee's Touch
				{ 12, 13514 }, -- Wail of the Banshee
			},
		},
		{ -- STRATBlackGuardSwordsmith
			name = AL["Black Guard Swordsmith"],
			NameColor = PURP,
			npcID = 11121,
			Level = {61, 62},
			SubAreaID = 32345,
			DisplayIDs = {{775}},
			AtlasMapBossID = 15,
			[NORMAL_DIFF] = {
				{ 1,  18783 }, -- Bottom Half of Advanced Armorsmithing: Volume III
				--{ 2,  12725 }, -- Plans: Enchanted Thorium Helm
				--{ 3,  12620 }, -- Enchanted Thorium Helm
				--{ 3,  12825 }, -- Plans: Blazing Rapier
				--{ 6,  12777 }, -- Blazing Rapier
			},
		},
		{ -- STRATNerubenkan
			name = AL["Nerub'enkan"],
			NameColor = PURP,
			npcID = 10437,
			Level = 60,
			SubAreaID = 32345,
			DisplayIDs = {{9793}},
			AtlasMapBossID = 16,
			[NORMAL_DIFF] = {
				{ 1,  16675 }, -- Beaststalker's Boots
				{ 3,  18740 }, -- Thuzadin Sash
				{ 4,  18739 }, -- Chitinous Plate Legguards
				{ 5,  18738 }, -- Carapace Spine Crossbow
				{ 6,  13529 }, -- Husk of Nerub'enkan
				{ 8,  13533 }, -- Acid-etched Pauldrons
				{ 9,  13532 }, -- Darkspinner Claws
				{ 10, 13531 }, -- Crypt Stalker Leggings
				{ 11, 13530 }, -- Fangdrip Runners
				{ 12, 13508 }, -- Eye of Arachnida
			},
		},
		{ -- STRATMalekithePallid
			name = AL["Maleki the Pallid"],
			NameColor = PURP,
			npcID = 10438,
			Level = 61,
			SubAreaID = 32349,
			DisplayIDs = {{10546}},
			AtlasMapBossID = 17,
			[NORMAL_DIFF] = {
				{ 1,  16691 }, -- Devout Sandals
				{ 3,  18734 }, -- Pale Moon Cloak
				{ 4,  18735 }, -- Maleki's Footwraps
				{ 5,  13524 }, -- Skull of Burning Shadows
				{ 6,  18737 }, -- Bone Slicing Hatchet
				{ 8,  13528 }, -- Twilight Void Bracers
				{ 9,  13525 }, -- Darkbind Fingers
				{ 10, 13526 }, -- Flamescarred Girdle
				{ 11, 13527 }, -- Lavawalker Greaves
				{ 12, 13509 }, -- Clutch of Foresight
				{ 16, 12833 }, -- Plans: Hammer of the Titans
			},
		},
		{ -- STRATRamsteintheGorger
			name = AL["Ramstein the Gorger"],
			NameColor = PURP,
			npcID = 10439,
			Level = 61,
			SubAreaID = 32301,
			DisplayIDs = {{12818}},
			AtlasMapBossID = 18,
			[NORMAL_DIFF] = {
				{ 1,  16737 }, -- Gauntlets of Valor
				{ 3,  18723 }, -- Animated Chain Necklace
				{ 4,  13374 }, -- Soulstealer Mantle
				{ 5,  13373 }, -- Band of Flesh
				{ 6,  13515 }, -- Ramstein's Lightning Bolts
				{ 7,  13375 }, -- Crest of Retribution
				{ 8,  13372 }, -- Slavedriver's Cane
			},
		},
		{ -- STRATBaronRivendare
			name = AL["Baron Rivendare"],
			NameColor = PURP,
			npcID = 10440,
			Level = 62,
			SubAreaID = 32352,
			DisplayIDs = {{10729}},
			AtlasMapBossID = 19,
			[NORMAL_DIFF] = {
				{ 1,  13335 }, -- Deathcharger's Reins
				{ 2,  13505 }, -- Runeblade of Baron Rivendare
				{ 4,  22411 }, -- Helm of the Executioner
				{ 5,  22412 }, -- Thuzadin Mantle
				{ 6,  13340 }, -- Cape of the Black Baron
				{ 7,  13346 }, -- Robes of the Exalted
				{ 8,  22409 }, -- Tunic of the Crescent Moon
				{ 9,  13344 }, -- Dracorian Gauntlets
				{ 10, 22410 }, -- Gauntlets of Deftness
				{ 11, 13345 }, -- Seal of Rivendare
				{ 12, 22408 }, -- Ritssyn's Wand of Bad Mojo
				{ 13, 13349 }, -- Scepter of the Unholy
				{ 14, 13368 }, -- Bonescraper
				{ 15, 13361 }, -- Skullforge Reaver
				{ 16, 16694 }, -- Devout Skirt
				{ 17, 16687 }, -- Magister's Leggings
				{ 18, 16699 }, -- Dreadmist Leggings
				{ 19, 16709 }, -- Shadowcraft Pants
				{ 20, 16719 }, -- Wildheart Kilt
				{ 21, 16678 }, -- Beaststalker's Pants
				{ 22, 16668 }, -- Kilt of Elements
				{ 23, 16728 }, -- Lightforge Legplates
				{ 24, 16732 }, -- Legplates of Valor
			},
		},
		{ -- STRATTrash
			name = AL["Trash"],
			ExtraList = true,
			[NORMAL_DIFF] = {
				{ 1,  16697 }, -- Devout Bracers
				{ 2,  16685 }, -- Magister's Belt
				{ 3,  16702 }, -- Dreadmist Belt
				{ 4,  16710 }, -- Shadowcraft Bracers
				{ 5,  16714 }, -- Wildheart Bracers
				{ 6,  16681 }, -- Beaststalker's Bindings
				{ 7,  16671 }, -- Bindings of Elements
				{ 8,  16723 }, -- Lightforge Belt
				{ 9,  16736 }, -- Belt of Valor
				{ 11, 12811 }, -- Righteous Orb
				{ 12, 12735 }, -- Frayed Abomination Stitching
				{ 13, 12843 }, -- Corruptor's Scourgestone
				{ 14, 12841 }, -- Invader's Scourgestone
				{ 15, 12840 }, -- Minion's Scourgestone
				{ 16, 18742 }, -- Stratholme Militia Shoulderguard
				{ 17, 18743 }, -- Gracious Cape
				{ 18, 17061 }, -- Juno's Shadow
				{ 19, 18741 }, -- Morlune's Bracer
				{ 20, 18744 }, -- Plaguebat Fur Gloves
				{ 21, 18745 }, -- Sacred Cloth Leggings
				{ 22, 18736 }, -- Plaguehound Leggings
				{ 24, 16249 }, -- Formula: Enchant 2H Weapon - Major Intellect
				{ 25, 16248 }, -- Formula: Enchant Weapon - Unholy
				{ 26, 14495 }, -- Pattern: Ghostweave Pants
				{ 27, 15777 }, -- Pattern: Runic Leather Shoulders
				{ 28, 15768 }, -- Pattern: Wicked Leather Belt
				{ 29, 18658 }, -- Schematic: Ultra-Flash Shadow Reflector
				{ 30, 16052 }, -- Schematic: Voice Amplification Modulator
			},
		},
		{ -- STRATBSPlansSerenity / STRATBSPlansCorruption
			name = AL["Plans"],
			ExtraList = true,
			IgnoreAsSource = true,
			[NORMAL_DIFF] = {
				{ 1,  12827 }, -- Plans: Serenity
				{ 16,  12830 }, -- Plans: Corruption
			},
		},
		{ -- STRATAtiesh
			name = AL["Atiesh"],
			NameColor = GREEN,
			ExtraList = true,
			AtlasMapBossID = 2,
			ContentPhase = 6,
			[NORMAL_DIFF] = {
				{ 1,  22736 }, -- Andonisus, Reaper of Souls
			},
		},
		{ -- STRATBalzaphon
			name = AL["Balzaphon"],
			NameColor = GREEN,
			ExtraList = true,
			specialType = "scourgeInvasion",
			npcID = 14684,
			DisplayIDs = {{7919}},
			AtlasMapBossID = 2,
			ContentPhase = 6,
			[NORMAL_DIFF] = {
				{ 1,  23126 }, -- Waistband of Balzaphon
				{ 2,  23125 }, -- Chains of the Lich
				{ 3,  23124 }, -- Staff of Balzaphon
			},
		},
		{ -- STRATSothosJarien
			name = AL["Sothos and Jarien's Heirlooms"].." - "..format(AL["Tier %s Sets"], "0.5"),
			NameColor = GREEN,
			ExtraList = true,
			ContentPhase = 5,
			AtlasMapBossID = 11,
			[NORMAL_DIFF] = {
				{ 1,  22327 }, -- Amulet of the Redeemed
				{ 2,  22301 }, -- Ironweave Robe
				{ 3,  22328 }, -- Legplates of Vigilance
				{ 4,  22334 }, -- Band of Mending
				{ 5,  22329 }, -- Scepter of Interminable Focus
			},
		},
		KEYS,
	},
}
