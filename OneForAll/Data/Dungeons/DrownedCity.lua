local _, FLT = ...

-- The Drowned City: quests (wowforevertalents.com beta quest cache), boss names and NPC IDs (Wowhead Forever database via foreverchanges.pro); October 2026.
FLT.DUNGEON_REGISTRY["The Drowned City"] = {
    level = "35-40",
    location = "Gillijim's Isle, off the coast of Stranglethorn Vale",
    description = "New Forever dungeon: I'lalai, a lost troll city that has risen from the sea. Naga, risen trolls and stranded pirates fight over its ruins. Not open on the beta yet; bosses and loot can still change.",
    icon = "Interface\\Icons\\INV_Misc_Idol_03",
    quests = {
        {
            id = 95775,
            liveXPFallback = 3150,
            name = "The Drowned City",
            level = 40,
            requires = 30,
            faction = "Horde",
            pickup = "Quest giver not known yet (Horde)",
            objective = "Use the hide and charcoal to create rubbings of the tablets found in the Drowned City.",
            note = "Make rubbings of the four Tablets of I'lalai inside the city.",
        },
        {
            id = 95776,
            liveXPFallback = 3550,
            name = "The Only Good Brinescale...",
            level = 38,
            requires = 30,
            faction = "Horde",
            pickup = "Quest giver not known yet (Horde)",
            objective = "Slay Var'Taka in the Drowned City.",
            rewardItems = {{279888, "Tidesoaked Leggings", 2}, {279889, "Naga Priestess's Mantle", 2}},
            rewardChoice = true,
            rewardSummary = "1g 30s",
            note = "The quest text mentions Kin'weelay, the troll scholar at Grom'gol Base Camp.",
        },
        {
            id = 96774,
            liveXPFallback = 3900,
            name = "Ancient Gurubashi Idol",
            level = 40,
            requires = 30,
            faction = "Horde",
            pickup = "Mazu'kon, Mulgore (32.4, 20.4)",
            objective = "Recover an Ancient Gurubashi Idol from the Drowned City.",
            turnin = "Mazu'kon, Mulgore",
            rewardSummary = "1g",
            note = "The idol is carried by the strongest priest in the city.",
        },
    },
    bosses = {
        {
            name = "Zul'Alai",
            npcID = 270882,
            loot = {},
        },
        {
            name = "Var'Taka",
            npcID = 270883,
            loot = {},
        },
        {
            name = "Captain Dreadrise",
            npcID = 270884,
            loot = {},
        },
        {
            name = "Deathless Marrow",
            npcID = 270885,
            description = "Fought together with a Primeval Elemental.",
            loot = {},
        },
        {
            name = "Gill",
            npcID = 270888,
            loot = {},
        },
        {
            name = "Min'loth the Serpent",
            npcID = 270886,
            loot = {},
        },
        {
            name = "Zin'aka",
            description = "Seen at the BlizzCon demo; not in the game files yet.",
            loot = {},
        },
    },
}
