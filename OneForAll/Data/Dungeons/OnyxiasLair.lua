local ADDON, FLT = ...

-- Onyxia's Lair: quests and known drops from QuestieDB Forever, rewards from
-- wowforevertalents.com, item details from Wowhead (Forever). See DUNGEON_DATA_SOURCES.txt.
FLT.DUNGEON_REGISTRY["Onyxia's Lair"] = {
    level = "60",
    location = "Dustwallow Marsh",
    description = "The lair of the black dragon Onyxia, deep in the Wyrmbog of Dustwallow Marsh. A raid for 40 players, opening on 9 December 2026. You need the Drakefire Amulet to enter (see Attunement). The loot list holds the drops known so far; the full table follows once the raid is open.",
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
    quests = {
        {
            level = 60,
            id = 7495,
            liveXPFallback = 9950,
            name = "Victory for the Alliance",
            requires = 50,
            faction = "Alliance",
            pickup = "Head of Onyxia, dropped by Onyxia",
            objective = "Take the Head of Onyxia to Highlord Bolvar Fordragon in Stormwind.",
            turnin = "Highlord Bolvar Fordragon, Stormwind City (80.2, 38.4)",
            rewardItems = {},
        },
        {
            level = 60,
            id = 7490,
            liveXPFallback = 9950,
            name = "Victory for the Horde",
            requires = 60,
            faction = "Horde",
            pickup = "Head of Onyxia, dropped by Onyxia",
            objective = "Take the Head of Onyxia to Thrall in Orgrimmar.",
            turnin = "Thrall, Orgrimmar (31.7, 37.8)",
            rewardItems = {},
        },
        {
            level = 60,
            id = 7635,
            liveXPFallback = 9950,
            name = "A Proper String",
            requires = 60,
            class = "HUNTER",
            pickup = "Stoma the Ancient",
            objective = "Stoma the Ancient has asked that you bring him a Mature Black Dragon Sinew. Should you find this sinew, return it to Stoma in Felwood.",
            turnin = "Stoma the Ancient",
            rewardItems = {
                {18724, "Enchanted Black Dragon Sinew", 4},
            },
        },
    },
    bosses = {
        {
            name = "Onyxia",
            npcID = 10184,
            aliases = {"Onyxia"},
            loot = {
                {17064, "Shard of the Scale", "Trinket", 4},
                {17068, "Deathbringer", "One-Hand, Axe", 4},
                {17075, "Vis'kag the Bloodletter", "One-Hand, Sword", 4},
                {17966, "Onyxia Hide Backpack", "Miscellaneous", 2},
                {18423, "Head of Onyxia", "Miscellaneous", 4},
                {18705, "Mature Black Dragon Sinew", "Miscellaneous", 4},
                {21108, "Draconic for Dummies", "Miscellaneous", 4},
            },
        },
    },
}
