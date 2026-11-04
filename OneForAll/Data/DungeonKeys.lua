local _, FLT = ...

-- Dungeon keys: what a dungeon needs to be entered (required) or which
-- optional shortcut keys it has. Quest steps and NPC positions from QuestieDB
-- Forever; item IDs from the Forever item data. Checked October 2026.
FLT.DUNGEON_KEYS = {
  ["Scarlet Monastery: Armory"] = {
    {
      item = 7146,
      name = "The Scarlet Key",
      required = true,
      summary = "Opens the doors of the Armory and the Cathedral. Anyone in the group who has it can open them.",
      steps = {
        { name = "Clear the Library", pickup = "Scarlet Monastery: Library, Tirisfal Glades", objective = "Fight through Scarlet Monastery: Library to Arcanist Doan." },
        { name = "Open Doan's Strongbox", pickup = "Behind Arcanist Doan, inside the Library", objective = "Loot The Scarlet Key from the strongbox behind Arcanist Doan. It stays in your keyring." },
      },
    },
  },
  ["Scarlet Monastery: Cathedral"] = {
    {
      item = 7146,
      name = "The Scarlet Key",
      required = true,
      summary = "Opens the doors of the Armory and the Cathedral. Anyone in the group who has it can open them.",
      steps = {
        { name = "Clear the Library", pickup = "Scarlet Monastery: Library, Tirisfal Glades", objective = "Fight through Scarlet Monastery: Library to Arcanist Doan." },
        { name = "Open Doan's Strongbox", pickup = "Behind Arcanist Doan, inside the Library", objective = "Loot The Scarlet Key from the strongbox behind Arcanist Doan. It stays in your keyring." },
      },
    },
  },
  ["Scholomance"] = {
    {
      item = 13704,
      name = "Skeleton Key",
      required = true,
      summary = "Opens the gate of Scholomance in Caer Darrow. Made by Krinkle Goodsteel in Gadgetzan from Imbued Skeletal Fragments; the last step is a quest for your faction.",
      steps = {
        { quest = 5066, name = "A Call to Arms: The Plaguelands!", level = 50, requires = 50, faction = "Alliance", pickup = "Crier Goodman, Stormwind City (56.4, 74.1)", objective = "Seek out Commander Ashlam Valorfist. His base camp is located at Chillwind Camp, north of the Alterac Mountains.", turnin = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", map = {mapID=1453, x=56.4, y=74.1} },
        { quest = 5092, name = "Clear the Way", level = 52, requires = 50, faction = "Alliance", pickup = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", objective = "Kill 10 Skeletal Flayers and 10 Slavering Ghouls in Sorrow Hill.  Return to Commander Ashlam Valorfist at Chillwind Camp, Western Plaguelands.", turnin = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", map = {mapID=1422, x=42.7, y=84.0} },
        { quest = 5097, name = "All Along the Watchtowers", level = 56, requires = 50, faction = "Alliance", pickup = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", objective = "Using the Beacon Torch, mark each tower in Andorhal; you will need to stand in the doorway of the tower to successfully mark it.  Once all four towers are marked, return the Beacon Torch to Commander Ashlam Valorfist in Chillwind Camp, Western Plaguelands.", turnin = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", map = {mapID=1422, x=42.7, y=84.0} },
        { quest = 5533, name = "Scholomance", level = 55, requires = 55, faction = "Alliance", pickup = "Commander Ashlam Valorfist, Western Plaguelands (42.7, 84.0)", objective = "Speak with Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=84.0} },
        { quest = 5537, name = "Skeletal Fragments", level = 57, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", objective = "Bring 15 Skeletal Fragments to Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5538, name = "Mold Rhymes With...", level = 57, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", objective = "Bring the Imbued Skeletal Fragments and 15 gold coins to Krinkle Goodsteel in Gadgetzan.", turnin = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5801, name = "Fire Plume Forged", level = 57, requires = 55, faction = "Alliance", pickup = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", objective = "Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater. Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key.  Bring the Unfinished Skeleton Key to Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1446, x=51.5, y=28.8} },
        { quest = 5803, name = "Araj's Scarab", level = 60, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", objective = "Destroy Araj the Summoner and bring Araj's Scarab to Alchemist Arbington at Chillwind Point, Western Plaguelands.", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5505, name = "The Key to Scholomance", level = 60, requires = 55, faction = "Alliance", pickup = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", turnin = "Alchemist Arbington, Western Plaguelands (42.7, 83.8)", map = {mapID=1422, x=42.7, y=83.8} },
        { quest = 5093, name = "A Call to Arms: The Plaguelands!", level = 50, requires = 50, faction = "Horde", pickup = "Warcaller Gorlach, Orgrimmar (37.6, 75.4)", objective = "Seek out High Executor Derrington. His base camp is located at the Bulwark, east of Tirisfal Glade and the Undercity.", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1454, x=37.6, y=75.4} },
        { quest = 5096, name = "Scarlet Diversions", level = 53, requires = 50, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", objective = "Proceed to the Scarlet Crusade's base camp between Felstone Field and Dalson's Tears and destroy their command tent.  Place the Scourge banner at the camp, and then return to High Executor Derrington at the Bulwark, Western Plaguelands.", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1420, x=83.1, y=68.9} },
        { quest = 5098, name = "All Along the Watchtowers", level = 56, requires = 50, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", objective = "Using the Beacon Torch, mark each tower in Andorhal; you will need to stand in the doorway of the tower to successfully mark it.  Once all four towers are marked, return the Beacon Torch to High Executor Derrington at the Bulwark, Western Plaguelands.", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1420, x=83.1, y=68.9} },
        { quest = 838, name = "Scholomance", level = 55, requires = 55, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", objective = "Speak with Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1420, x=83.1, y=68.9} },
        { quest = 964, name = "Skeletal Fragments", level = 57, requires = 55, faction = "Horde", pickup = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", objective = "Bring 15 Skeletal Fragments to Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1420, x=83.3, y=69.2} },
        { quest = 5514, name = "Mold Rhymes With...", level = 57, requires = 55, faction = "Horde", pickup = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", objective = "Bring the Imbued Skeletal Fragments and 15 gold coins to Krinkle Goodsteel in Gadgetzan.", turnin = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", map = {mapID=1420, x=83.3, y=69.2} },
        { quest = 5802, name = "Fire Plume Forged", level = 57, requires = 55, faction = "Horde", pickup = "Krinkle Goodsteel, Tanaris (51.5, 28.8)", objective = "Take the Skeleton Key Mold and 2 Thorium Bars to the top of Fire Plume Ridge in Un'Goro Crater. Use the Skeleton Key Mold by the lava lake to forge the Unfinished Skeleton Key.  Bring the Unfinished Skeleton Key to Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1446, x=51.5, y=28.8} },
        { quest = 5804, name = "Araj's Scarab", level = 60, requires = 55, faction = "Horde", pickup = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", objective = "Destroy Araj the Summoner and bring Araj's Scarab to Apothecary Dithers at the Bulwark, Western Plaguelands.", turnin = "Apothecary Dithers, Tirisfal Glades (83.3, 69.2)", map = {mapID=1420, x=83.3, y=69.2} },
        { quest = 5511, name = "The Key to Scholomance", level = 60, requires = 55, faction = "Horde", pickup = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", turnin = "High Executor Derrington, Tirisfal Glades (83.1, 68.9)", map = {mapID=1420, x=83.1, y=68.9} },
      },
    },
  },
  ["Upper Blackrock Spire"] = {
    {
      item = 12344,
      name = "Seal of Ascension",
      required = true,
      summary = "Opens the door to Upper Blackrock Spire. Collect the Unadorned Seal and three gemstones in Lower Blackrock Spire, then forge the seal at the dragon in Dustwallow Marsh.",
      steps = {
        { quest = 4742, name = "Seal of Ascension", level = 60, requires = 57, pickup = "Vaelan, inside Lower Blackrock Spire", objective = "Find the three gemstones of command: The Gemstone of Smolderthorn, Gemstone of Spirestone, and Gemstone of Bloodaxe. Return them, along with the Unadorned Seal of Ascension, to Vaelan.  The Generals, as told to you by Vaelan, are: War Master Voone of the Smolderthorn; Highlord Omokk of the Spirestone; and Overlord Wyrmthalak of the Bloodaxe.", turnin = "Vaelan, inside Lower Blackrock Spire" },
        { quest = 4743, name = "Seal of Ascension", level = 60, requires = 57, pickup = "Vaelan, inside Lower Blackrock Spire", objective = "Travel to the Wyrmbog in Dustwallow Marsh. Find the ancient drake, Emberstrife and beat him without mercy until his will is broken.  It is at that moment which you must place the Unforged Seal of Ascension before the great beast. You must then be quick to use the Orb of Draconic Energy on his weakened form and claim dominion over his mental faculties. Control the beast and force the Flames of the Black Dragonflight upon the Unforged Seal of Ascension!", turnin = "Vaelan, inside Lower Blackrock Spire" },
      },
    },
  },
  ["Dire Maul: West"] = {
    {
      item = 18249,
      name = "Crescent Key",
      required = true,
      summary = "Opens the doors of Dire Maul West and North (also the Gordok side door). One key holder in the group is enough.",
      steps = {
        { name = "Go to Dire Maul East", pickup = "Dire Maul, Feralas (59.2, 45.1)", objective = "Enter Dire Maul East through the Broken Commons; Pusillin waits near the entrance.", map = {mapID=1444, x=59.2, y=45.1} },
        { name = "Chase Pusillin", pickup = "Inside Dire Maul East", objective = "Talk to Pusillin and chase the imp through Warpwood Quarter until he fights; he drops the Crescent Key." },
      },
    },
  },
  ["Dire Maul: North"] = {
    {
      item = 18249,
      name = "Crescent Key",
      required = true,
      summary = "Opens the doors of Dire Maul West and North (also the Gordok side door). One key holder in the group is enough.",
      steps = {
        { name = "Go to Dire Maul East", pickup = "Dire Maul, Feralas (59.2, 45.1)", objective = "Enter Dire Maul East through the Broken Commons; Pusillin waits near the entrance.", map = {mapID=1444, x=59.2, y=45.1} },
        { name = "Chase Pusillin", pickup = "Inside Dire Maul East", objective = "Talk to Pusillin and chase the imp through Warpwood Quarter until he fights; he drops the Crescent Key." },
      },
    },
  },
  ["Blackrock Depths"] = {
    {
      item = 11000,
      name = "Shadowforge Key",
      required = false,
      summary = "Opens the Shadowforge gates in Blackrock Depths (a shortcut; without it the doors need a rogue or Seeping Flames).",
      steps = {
        { quest = 3801, name = "Dark Iron Legacy", level = 52, requires = 48, pickup = "Franclorn Forgewright, Blackrock Mountain (his ghost is only visible while you are dead)", objective = "Speak with Franclorn Forgewright if you are interested in obtaining a key to the city major.", turnin = "Franclorn Forgewright, inside Blackrock Depths" },
        { quest = 3802, name = "Dark Iron Legacy", level = 52, requires = 48, pickup = "Franclorn Forgewright, Blackrock Mountain (as a ghost)", objective = "Slay Fineous Darkvire and recover the great hammer, Ironfel. Take Ironfel to the Shrine of Thaurissan and place it on the statue of Franclorn Forgewright.", turnin = "Monument of Franclorn Forgewright, inside Blackrock Depths" },
      },
    },
    {
      item = 11140,
      name = "Prison Cell Key",
      required = false,
      summary = "Opens the prison cells in the Detention Block (Jail Break!).",
      steps = {
        { name = "High Interrogator Gerstahn", pickup = "Inside Blackrock Depths", objective = "Drops from High Interrogator Gerstahn in the Detention Block." },
      },
    },
  },
  ["Stratholme"] = {
    {
      item = 12382,
      name = "Key to the City",
      required = false,
      summary = "Opens the gates between the two halves of Stratholme. Both gates can be entered without it.",
      steps = {
        { name = "Magistrate Barthilas", pickup = "Inside Stratholme", objective = "Drops from Magistrate Barthilas behind the service gate." },
      },
    },
  },
  ["Gnomeregan"] = {
    {
      item = 6893,
      name = "Workshop Key",
      required = false,
      summary = "Opens the Workshop side entrance and doors inside Gnomeregan.",
      steps = {
        { name = "Electrocutioner 6000", pickup = "Inside Gnomeregan", objective = "Drops from Electrocutioner 6000." },
      },
    },
  },
  ["Maraudon"] = {
    {
      item = 17191,
      name = "Scepter of Celebras",
      required = false,
      summary = "Opens the portal from the Maraudon entrance straight to Princess Theradras' falls.",
      steps = {
        { quest = 7044, name = "Legends of Maraudon", level = 49, requires = 41, pickup = "Cavindra, Desolace (32.1, 64.0)", objective = "Recover the two parts of the Scepter of Celebras: the Celebrian Rod and the Celebrian Diamond.  Find a way to speak with Celebras.", turnin = "Celebras the Redeemed, inside Maraudon", map = {mapID=1443, x=32.1, y=64.0} },
        { quest = 7046, name = "The Scepter of Celebras", level = 49, requires = 41, pickup = "Celebras the Redeemed, inside Maraudon", objective = "Assist Celebras the Redeemed while he creates the Scepter of Celebras.  Speak with him when the ritual is complete.", turnin = "Celebras the Redeemed, inside Maraudon" },
      },
    },
  },
}
