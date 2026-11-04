local ADDON, FLT = ...
FLT = FLT or {}
_G[ADDON] = FLT

-- Keep the visible product name separate from the addon folder/internal name.
-- A future rename only needs to change DISPLAY_NAME / TOC / folder name; asset
-- paths derive from ADDON automatically. SavedVariables intentionally keep the
-- legacy names so existing user progress survives that migration.
FLT.INTERNAL_ADDON_NAME = ADDON
FLT.DISPLAY_NAME = FLT.DISPLAY_NAME or "OneForAll"
FLT.ASSET_ROOT = FLT.ASSET_ROOT or ("Interface\\AddOns\\" .. ADDON .. "\\Assets\\")
FLT.LEGACY_SAVED_VARIABLES = { "OneForAllDB", "ForeverLibraryTrackerDB" }

FLT.SETS = {
  starter = "Set 1 - Level 20",
  l35 = "Set 2 - Level 35",
  l45 = "Set 3 - Level 45",
  l60 = "Set 4 - Level 60",
}

-- Classic UiMapIDs. Explicit IDs make the Map button deterministic even when another map is already open.
FLT.MAP_IDS = {
  ["Redridge Mountains"] = 1433,
  ["Elwynn Forest"] = 1429,
  ["Ironforge"] = 1455,
  ["Westfall"] = 1436,
  ["Loch Modan"] = 1432,
  ["Duskwood"] = 1431,
  ["Wetlands"] = 1437,
  ["Silverpine Forest"] = 1421,
  ["Tirisfal Glades"] = 1420,
  ["Darkshore"] = 1439,
  ["The Barrens"] = 1413,
  ["Stonetalon Mountains"] = 1442,
  ["Orgrimmar"] = 1454,
  ["Stranglethorn Vale"] = 1434,
  ["Alterac Mountains"] = 1416,
  ["Arathi Highlands"] = 1417,
  ["Badlands"] = 1418,
  ["Swamp of Sorrows"] = 1435,
  ["Thousand Needles"] = 1441,
  ["Desolace"] = 1443,
  ["Dustwallow Marsh"] = 1445,
  ["Burning Steppes"] = 1428,
  ["The Hinterlands"] = 1425,
  ["Searing Gorge"] = 1427,
  ["Blasted Lands"] = 1419,
  ["Tanaris"] = 1446,
  ["Azshara"] = 1447,
  ["Feralas"] = 1444,
  ["Western Plaguelands"] = 1422,
  ["Eastern Plaguelands"] = 1423,
  ["Felwood"] = 1448,
  ["Winterspring"] = 1452,
  -- Zones used by dungeon entrances, quest starts and trade hubs. Explicit IDs
  -- matter on non-English clients, where the name-based fallback lookup in
  -- Map.lua cannot match English zone names (e.g. "Ashenvale" vs "Eschental").
  ["Ashenvale"] = 1440,
  ["Dun Morogh"] = 1426,
  ["Durotar"] = 1411,
  ["Mulgore"] = 1412,
  ["Teldrassil"] = 1438,
  ["Stormwind City"] = 1453,
  ["Undercity"] = 1458,
  ["Thunder Bluff"] = 1456,
  ["Darnassus"] = 1457,
  ["Hillsbrad Foothills"] = 1424,
  ["Un'Goro Crater"] = 1449,
  ["Moonglade"] = 1450,
}

-- This describes the zone's normal Classic territory, not a faction restriction on the book itself.
FLT.TERRITORY_BY_ZONE = {
  ["Redridge Mountains"] = "Alliance",
  ["Elwynn Forest"] = "Alliance",
  ["Ironforge"] = "Alliance",
  ["Westfall"] = "Alliance",
  ["Loch Modan"] = "Alliance",
  ["Duskwood"] = "Alliance",
  ["Wetlands"] = "Alliance",
  ["Darkshore"] = "Alliance",

  ["Silverpine Forest"] = "Horde",
  ["Tirisfal Glades"] = "Horde",
  ["The Barrens"] = "Horde",
  ["Orgrimmar"] = "Horde",
}

-- Data: Forever book data collected for the initial release of this addon.
-- For cave/interior books, the outdoor X points to a useful entrance when appropriate.
FLT.BOOKS = {
  {set="starter",name="Archmage Theocritus' Research Journal",questId=79092,itemId=203755,zone="Elwynn Forest",subzone="Tower of Azora",x=65.4,y=70.1,container="Library Book",status="wowhead",note="On a table partway up the tower."},
  {set="starter",name="Archmage Antonidas: The Unabridged Autobiography",questId=79091,itemId=203754,zone="Ironforge",subzone="Hall of Explorers",x=75.7,y=10.5,container="Library Book",status="wowhead",note="On a table in the middle of the hall."},
  {set="starter",name="Bewitchments and Glamours",questId=78142,itemId=209845,zone="Westfall",subzone="Moonbrook",x=45.4,y=70.4,container="Spellbook",status="wowhead",note="Inside a house in Moonbrook."},
  {set="starter",name="Rumi of Gnomeregan: The Collected Works",questId=79093,itemId=208860,zone="Loch Modan",subzone="Thelsamar",x=35.6,y=48.9,container="Gnomish Tome",status="wowhead",note="Inside the Thelsamar inn. Alternative location: Westfall, Sentinel Hill 52.7, 53.8."},
  {set="starter",name="Crimes Against Anatomy",questId=78147,itemId=209849,zone="Duskwood",subzone="Dawning Wood Catacombs, Raven Hill",x=16.6,y=28.5,container="Spellbook",status="wowhead",note="Position from the Forever database; not yet fully confirmed during beta."},
  {set="starter",name="Runes of the Sorcerer-Kings",questId=78148,itemId=209850,zone="Loch Modan",subzone="Mo'grosh Stronghold",x=77.4,y=14.0,container="Scrolls",status="wowhead",note="At the ogre camp in the northeast."},
  {set="starter",name="Goaz Scrolls",questId=78146,itemId=209848,zone="Wetlands",subzone="Whelgar's Excavation Site",x=33.6,y=47.9,container="Scrolls",status="wowhead"},
  {set="starter",name="The Dalaran Digest, Vol. 23",questId=78127,itemId=209844,zone="Silverpine Forest",subzone="Ambermill",x=63.5,y=63.1,container="Dalaran Digest",status="wowhead",note="Inside the town hall."},
  {set="starter",name="The Apothecary's Metaphysical Primer",questId=79095,itemId=208185,zone="Tirisfal Glades",subzone="Brill",x=59.4,y=52.3,container="Apothecary Society Primer",status="wowhead",note="On a shelf next to Apothecary Johaan."},
  {set="starter",name="Ataeric: On Arcane Curiosities",questId=79096,itemId=210177,zone="Silverpine Forest",subzone="The Sepulcher",x=43.4,y=41.2,container="Arcane Secrets",status="unknown",note="Not confirmed yet; players did not find the book at the database position during earlier testing."},
  {set="starter",name="Nar'thalas Almanac, Vol. 74",questId=78124,itemId=209843,zone="Darkshore",subzone="Ruins of Mathystra",x=59.6,y=22.2,container="Scrolls",status="wowhead"},
  {set="starter",name="Arcanic Systems Manual",questId=78145,itemId=209847,zone="The Barrens",subzone="The Sludge Fen",x=56.3,y=8.8,container="Manual",status="wowhead",note="Inside the oil platform control room."},
  {set="starter",name="Baxtan: On Destructive Magics",questId=79097,itemId=208800,zone="The Barrens",subzone="Ratchet",x=62.7,y=36.3,container="Goblin Tome",status="wowhead",note="Next to Gazlowe."},
  {set="starter",name="Secrets of the Dreamers",questId=78143,itemId=209846,zone="The Barrens",subzone="Cavern of Mists / Wailing Caverns cave",x=46.0,y=36.5,container="Scrolls",status="confirmed",note="The map X marks the cave entrance. Inside, near the Wailing Caverns portal: 52.8, 54.7 on the cave map."},
  {set="starter",name="Fury of the Land",questId=78149,itemId=209851,zone="Stonetalon Mountains",subzone="Camp Aparaje",x=74.4,y=85.7,container="Scrolls",status="wowhead"},
  {set="starter",name="The Lessons of Ta'zo",questId=79094,itemId=207972,zone="Orgrimmar",subzone="Valley of Spirits",x=38.7,y=78.4,container="Mural of Ta'zo",status="confirmed",note="Large tablet in front of the Darkbriar Lodge; click it to obtain the transcription."},

  {set="l35",name="Basilisks: Should Petrification be Feared?",questId=79535,itemId=213165,zone="Stranglethorn Vale",subzone="Crystalvein Mine",x=41.4,y=50.9,container="Research Notes",status="wowhead",note="Outside the mine on a platform."},
  {set="l35",name="Defensive Magics 101",questId=79948,itemId=215815,zone="Alterac Mountains",subzone="Ruins of Alterac",x=48.4,y=57.6,container="Manual",status="wowhead",note="Inside a tower in the ogre ruins."},
  {set="l35",name="A Web of Lies: Debunking Myths and Legends",questId=79949,itemId=215816,zone="Arathi Highlands",subzone="Witherbark Village",x=73.6,y=65.2,container="Scrolls",status="wowhead"},
  {set="l35",name="Mummies: A Guide to the Unsavory Undead",questId=79951,itemId=215820,zone="Badlands",x=56.7,y=39.9,container="Scrolls",status="wowhead",note="Inside the crypt on the south side; approach is roughly around 56.0, 45.0."},
  {set="l35",name="A Luddite's Guide to Caring for Your Demonic Pet",questId=79953,itemId=215824,zone="Swamp of Sorrows",subzone="Fallow Sanctuary",x=61.4,y=22.4,container="Book",status="wowhead",note="In Season of Discovery this was in a locked cage; Forever behavior was not yet confirmed."},
  {set="l35",name="Geomancy: The Stone-Cold Truth",questId=79947,itemId=215683,zone="Thousand Needles",subzone="Darkcloud Pinnacle",x=34.4,y=40.1,container="Scrolls",status="wowhead",note="Inside a hut; the climb starts roughly around 31.0, 37.0."},
  {set="l35",name="Demons and You",questId=79950,itemId=215817,zone="Desolace",subzone="Thunder Axe Fortress",x=55.1,y=26.2,container="Mysterious Book",status="wowhead",note="On a bench inside the large building."},
  {set="l35",name="RwlRwlRwlRwl!",questId=79952,itemId=215822,zone="Dustwallow Marsh",subzone="Witch Hill",x=57.2,y=20.8,container="Waterlogged Book",status="wowhead",note="On the ground on the eastern edge of the murloc camp."},

  {set="l45",name="Sanguine Sorcery",questId=81947,itemId=220345,zone="Swamp of Sorrows",subzone="Temple of Atal'Hakkar",x=70.0,y=51.0,container="Unknown",status="reported",note="On top of the temple, outside the instance; player-reported location."},
  {set="l45",name="Stonewrought Design",questId=81953,itemId=220349,zone="Burning Steppes",subzone="Blackrock Mountain - Forgewright's Tomb",x=29.0,y=28.9,container="Unknown",status="reported",note="On the altar inside the tomb; no dungeon entry required. Coordinates use the Burning Steppes map."},
  {set="l45",name="Venomous Journeys",questId=81954,itemId=220350,zone="The Hinterlands",subzone="Shadra'Alor",x=36.0,y=72.8,container="Book",status="wowhead"},
  {set="l45",name="A Mind of Metal",questId=81955,itemId=220352,zone="Searing Gorge",subzone="The Cauldron",x=37.8,y=49.3,container="Book",status="wowhead"},
  {set="l45",name="Conjurer's Codex",questId=81956,itemId=220353,zone="Blasted Lands",x=55.4,y=32.2,container="Book",status="wowhead"},
  {set="l45",name="Legends of the Tidesages",questId=81949,itemId=220346,zone="Tanaris",subzone="Lost Rigger Cove",x=72.7,y=47.8,container="Book",status="wowhead",note="On a bookshelf inside a pirate building."},
  {set="l45",name="Everyday Etiquette",questId=81952,itemId=220348,zone="Azshara",subzone="Haldarr Encampment",x=20.7,y=62.0,container="Book",status="wowhead",note="On a crate next to a hut."},
  {set="l45",name="The Liminal and the Arcane",questId=81951,itemId=220347,zone="Feralas",subzone="south of Jademir Lake",x=50.6,y=15.7,container="Book",status="not-in-forever",note="In Season of Discovery this was only reachable through a Nightmare Incursion; currently reported as unavailable in Forever."},

  {set="l60",name="Undead Potatoes",questId=84395,itemId=228132,zone="Western Plaguelands",subzone="Felstone Field",x=38.2,y=54.6,container="Book",status="wowhead",note="Inside the farmhouse."},
  {set="l60",name="Necromancy 101",questId=84402,itemId=228141,zone="Western Plaguelands",subzone="Caer Darrow",x=69.2,y=72.3,container="Book",status="wowhead",note="On a table in the ruined building above Scholomance."},
  {set="l60",name="A Study of the Light",questId=84398,itemId=228135,zone="Eastern Plaguelands",subzone="Light's Hope Chapel",x=71.8,y=48.3,container="Book",status="wowhead",note="Database pins have conflicted; 71.8, 48.3 was also supported by player reports."},
  {set="l60",name="The Knight and the Lady",questId=84400,itemId=228138,zone="Eastern Plaguelands",subzone="Blackwood Lake",x=54.4,y=51.1,container="Book",status="wowhead"},
  {set="l60",name="Scourge: Undead Menace or Misunderstood?",questId=84401,itemId=228140,zone="Eastern Plaguelands",subzone="Stratholme entrance",x=31.2,y=21.0,container="Book",status="wowhead"},
  {set="l60",name="Magma or Lava?",questId=84396,itemId=228133,zone="Burning Steppes",subzone="Blackrock Mountain - near BRD entrance",container="Unknown",status="unknown",note="No confirmed Forever position yet; in Season of Discovery it was near the Blackrock Depths entrance."},
  {set="l60",name="Northern Kalimdor - A Comprehensive Guide",questId=84397,itemId=228134,zone="Felwood",subzone="Timbermaw Hold",x=65.2,y=3.3,container="Book",status="confirmed",note="Inside the Timbermaw tunnel between Felwood and Winterspring."},
  {set="l60",name="Ka-Boom!",questId=84399,itemId=228136,zone="Winterspring",subzone="Everlook",x=60.7,y=37.7,container="Book",status="wowhead",note="On a shelf behind the alchemy vendor."},
}

function FLT:GetTerritory(zone)
  return self.TERRITORY_BY_ZONE[zone] or "Contested"
end
