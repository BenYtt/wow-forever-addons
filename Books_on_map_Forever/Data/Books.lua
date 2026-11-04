-- Books on map (Forever): book data
-- Sources: https://foreverchanges.pro/library-books, https://www.zockify.com/forever/library-books/, Wowhead
local _, ns = ...

-- Classic uiMapIDs
local ELWYNN, IRONFORGE, WESTFALL, DUSKWOOD, LOCHMODAN, WETLANDS = 1429, 1455, 1436, 1431, 1432, 1437
local SILVERPINE, TIRISFAL, DARKSHORE, BARRENS, STONETALON, ORGRIMMAR = 1421, 1420, 1439, 1413, 1442, 1454
local STV, NEEDLES, ALTERAC, DUSTWALLOW, BADLANDS, SEARING = 1434, 1441, 1416, 1445, 1418, 1427
local ARATHI, DESOLACE, SWAMP, TANARIS, AZSHARA, BURNING = 1417, 1443, 1435, 1446, 1447, 1428
local HINTERLANDS, BLASTED, FELWOOD, WPL, EPL, WINTERSPRING = 1425, 1419, 1448, 1422, 1423, 1452
ns.CONTINENTS = { [1414] = true, [1415] = true } -- Kalimdor, Eastern Kingdoms

-- key = stable id; set = quest set (1 = starting set, 35/45/60 = level); icon = item icon (Interface\Icons); name / frName = English / French item name (used to detect pickup)
-- item = itemID (optional, detects pickup in any language); quest = questID of the library turn-in (optional, detects books already handed in)
-- faction = "Alliance" / "Horde" (optional): book only lootable by that faction, removed for the other one
-- locs = { {mapID, x, y, place, frPlace}, ... }
ns.BOOKS = {
  -- First set
  { key = "theocritus", item = 203755, quest = 79092, set = 1, icon = "inv_misc_book_12", name = "Archmage Theocritus' Research Journal", frName = "Journal de recherche de l'archimage Théocritus", locs = { { ELWYNN, 65.4, 70.1, "Tower of Azora, Elwynn Forest", "Tour d'Azora, forêt d'Elwynn" } } },
  { key = "antonidas", item = 203754, quest = 79091, set = 1, icon = "inv_misc_book_12", name = "Archmage Antonidas: The Unabridged Autobiography", frName = "Archimage Antonidas : L'autobiographie intégrale", locs = { { IRONFORGE, 75.7, 10.5, "Ironforge", "Forgefer" } } },
  { key = "envoutements", item = 209845, quest = 78142, set = 1, icon = "inv_misc_book_01", name = "Bewitchments and Glamours", frName = "Envoûtements et glamours", locs = { { WESTFALL, 45.4, 70.4, "Moonbrook, Westfall", "Ruisselune, Marche de l'Ouest" } } },
  { key = "rumi", item = 208860, quest = 79093, faction = "Alliance", set = 1, icon = "inv_misc_book_12", name = "Rumi of Gnomeregan: The Collected Works", frName = "Rumi de Gnomeregan : Le recueil d'œuvres", locs = {
      { WESTFALL, 52.7, 53.8, "Sentinel Hill, Westfall", "Colline des sentinelles, Marche de l'Ouest" },
      { LOCHMODAN, 35.6, 48.9, "Thelsamar, Loch Modan (same book)", "Thelsamar, Loch Modan (même livre)" } } },
  { key = "anatomie", item = 209849, quest = 78147, set = 1, icon = "inv_misc_book_06", name = "Crimes Against Anatomy", frName = "Crimes contre l'anatomie", locs = { { DUSKWOOD, 16.6, 28.5, "The Darkened Bank, Duskwood", "La rive Sombre, bois de la Pénombre" } } },
  { key = "runes", item = 209850, quest = 78148, set = 1, icon = "inv_scroll_02", name = "Runes of the Sorcerer-Kings", frName = "Runes des rois-sorciers", locs = { { LOCHMODAN, 77.4, 14.0, "Mo'grosh Stronghold, Loch Modan", "Bastion des Mo'grosh, Loch Modan" } } },
  { key = "goaz", item = 209848, quest = 78146, set = 1, icon = "inv_scroll_15", name = "Goaz Scrolls", frName = "Parchemins de Goaz", locs = { { WETLANDS, 33.6, 47.9, "Whelgar's Excavation Site, Wetlands", "Excavations de Whelgar, les Paluns" } } },
  { key = "dalaran", item = 209844, quest = 78127, set = 1, icon = "inv_relics_libramoftruth", name = "The Dalaran Digest, Vol. 23", frName = "Abrégé de Dalaran vol. 23", locs = { { SILVERPINE, 63.5, 63.1, "Ambermill, Silverpine Forest", "Moulin-de-l'Ambre, forêt des Pins-Argentés" } } },
  { key = "ataeric", item = 210177, quest = 79096, set = 1, icon = "inv_misc_book_12", name = "Ataeric: On Arcane Curiosities", frName = "Ataeric : Sur les curiosités arcaniques", locs = { { SILVERPINE, 43.4, 41.2, "The Sepulcher, inside the tomb near Sebastian Meloche, Silverpine Forest", "Le Sépulcre, dans la crypte près de Sebastian Meloche, forêt des Pins-Argentés" } } },
  { key = "abecedaire", item = 208185, quest = 79095, set = 1, icon = "inv_misc_book_05", name = "The Apothecary's Metaphysical Primer", frName = "L'abécédaire métaphysique de l'apothicaire", locs = { { TIRISFAL, 59.4, 52.3, "Brill, Tirisfal Glades", "Brill, clairières de Tirisfal" } } },
  { key = "narthalas", item = 209843, quest = 78124, set = 1, icon = "inv_scroll_12", name = "Nar'thalas Almanac, Vol. 74", frName = "Almanach de Nar'thalas vol. 74", locs = { { DARKSHORE, 59.6, 22.2, "Ruins of Mathystra, Darkshore", "Ruines de Mathystra, Sombrivage" } } },
  { key = "arcaniques", item = 209847, quest = 78145, set = 1, icon = "inv_misc_toy_05", name = "Arcanic Systems Manual", frName = "Manuel des systèmes arcaniques", locs = { { BARRENS, 56.3, 8.8, "The Sludge Fen, The Barrens", "La Videfange, les Tarides" } } },
  { key = "baxtan", item = 208800, quest = 79097, set = 1, icon = "inv_misc_book_12", name = "Baxtan: On Destructive Magics", frName = "Baxtan : Sur les magies destructrices", locs = { { BARRENS, 62.7, 36.3, "Ratchet, The Barrens", "Cabestan, les Tarides" } } },
  { key = "reveurs", item = 209846, quest = 78143, set = 1, icon = "inv_scroll_09", name = "Secrets of the Dreamers", frName = "Secrets des Rêveurs", locs = { { BARRENS, 46.0, 36.5, "Cave entrance, then Cavern of Mists (52.8, 54.7 on cave map)", "Entrée de la grotte, puis Caverne des brumes (52.8, 54.7 sur la carte de la grotte)" } } },
  { key = "fureur", item = 209851, quest = 78149, set = 1, icon = "inv_holiday_tow_spicebandage", name = "Fury of the Land", frName = "Fureur de la terre", locs = { { STONETALON, 74.4, 85.7, "Grimtotem Post, Stonetalon Mountains", "Poste Totem sinistre, les Serres-Rocheuses" } } },
  { key = "tazo", item = 207972, quest = 79094, faction = "Horde", set = 1, icon = "inv_scroll_02", name = "The Lessons of Ta'zo", frName = "Les leçons de Ta'zo", locs = { { ORGRIMMAR, 38.7, 78.4, "Ta'zo Mural, Orgrimmar", "Fresque de Ta'zo, Orgrimmar" } } },

  -- Level 35 set
  { key = "basilics", item = 213165, quest = 79535, set = 35, icon = "inv_inscription_scroll", name = "Basilisks: Should Petrification be Feared?", frName = "Les basilics : faut-il avoir peur de se faire pétrifier ?", locs = { { STV, 41.4, 50.9, "Crystalvein Mine, Stranglethorn Vale", "Mine aux cristaux, vallée de Strangleronce" } } },
  { key = "geomancie", item = 215683, quest = 79947, set = 35, icon = "inv_misc_book_08", name = "Geomancy: The Stone-Cold Truth", frName = "Géomancie : une montagne de puissance", locs = { { NEEDLES, 34.4, 40.1, "Darkcloud Pinnacle, Thousand Needles", "Cime de Noir-nuage, Mille pointes" } } },
  { key = "defensive", item = 215815, quest = 79948, set = 35, icon = "inv_misc_book_04", name = "Defensive Magics 101", frName = "Les bases de la magie défensive", locs = { { ALTERAC, 48.4, 57.6, "Gallows' Corner, Alterac Mountains", "Fourche du gibet, montagnes d'Alterac" } } },
  { key = "rwl", item = 215822, quest = 79952, set = 35, icon = "inv_misc_book_08", name = "RwlRwlRwlRwl!", frName = "RwlRwlRwlRwl !", locs = { { DUSTWALLOW, 57.2, 20.8, "Witch Hill, Dustwallow Marsh", "Colline des sorcières, marécage d'Âprefange" } } },
  { key = "weblies", item = 215816, quest = 79949, set = 35, icon = "inv_misc_note_05", name = "A Web of Lies: Debunking Myths and Legends", frName = "Un tissage de mensonges : mythes et légendes démystifiés", locs = { { ARATHI, 73.6, 65.2, "Witherbark Village, Arathi Highlands", "Fanécorce, hautes-terres d'Arathi" } } },
  { key = "demons", item = 215817, quest = 79950, set = 35, icon = "inv_misc_book_01", name = "Demons and You", frName = "Les démons et vous", locs = { { DESOLACE, 55.1, 26.2, "Thunder Axe Fortress, Desolace", "Forteresse de Hache-Tonnerre, Désolace" } } },
  { key = "mummies", item = 215820, quest = 79951, set = 35, icon = "inv_scroll_01", name = "Mummies: A Guide to the Unsavory Undead", frName = "Les Momies : le guide des morts-vivants répugnants", locs = { { BADLANDS, 56.7, 39.9, "Badlands", "Terres ingrates" } } },
  { key = "luddite", item = 215824, quest = 79953, set = 35, icon = "inv_misc_book_10", name = "A Ludite's Guide to Caring for Your Demonic Pet", frName = "Le soin des familiers démoniaques pour les pas doués", locs = { { SWAMP, 61.4, 22.4, "Fallow Sanctuary, Swamp of Sorrows", "Sanctuaire des friches, marais des Chagrins" } } },

  -- Level 45 set
  { key = "sanguine", item = 220345, quest = 81947, set = 45, icon = "inv_misc_book_06", name = "Sanguine Sorcery", frName = "Sorcellerie sanguine", locs = { { SWAMP, 70.0, 51.0, "Top of the Sunken Temple, Swamp of Sorrows", "Sommet du Temple englouti, marais des Chagrins" } } },
  { key = "tidesages", item = 220346, quest = 81949, set = 45, icon = "inv_scroll_05", name = "Legends of the Tidesages", frName = "Légendes des Eaugures", locs = { { TANARIS, 72.7, 47.8, "Lost Rigger Cove, Tanaris", "Crique des Gréements, Tanaris" } } },
  { key = "etiquette", item = 220348, quest = 81952, set = 45, icon = "inv_misc_book_08", name = "Everyday Etiquette", frName = "Étiquette quotidienne", locs = { { AZSHARA, 20.7, 62.0, "Haldarr Encampment, Azshara", "Campement des Haldarr, Azshara" } } },
  { key = "stonewrought", item = 220349, quest = 81953, set = 45, icon = "inv_misc_book_11", name = "Stonewrought Design", frName = "Plan de Formepierre", locs = { { BURNING, 29.0, 28.9, "Blackrock Mountain tomb altar, Burning Steppes", "Autel du tombeau, mont Rochenoire, steppes Ardentes" } } },
  { key = "venomous", item = 220350, quest = 81954, set = 45, icon = "inv_scroll_06", name = "Venomous Journeys", frName = "Voyages venimeux", locs = { { HINTERLANDS, 36.0, 72.8, "Shadra'Alor, The Hinterlands", "Shadra'Alor, les Hinterlands" } } },
  { key = "mindmetal", item = 220352, quest = 81955, set = 45, icon = "inv_misc_book_11", name = "A Mind of Metal", frName = "Un esprit métallique", locs = { { SEARING, 37.8, 49.3, "The Cauldron, Searing Gorge", "Le Chaudron, gorge des Vents brûlants" } } },
  { key = "conjurer", item = 220353, quest = 81956, set = 45, icon = "inv_misc_book_04", name = "Conjurer's Codex", frName = "Codex d'adjurateur", locs = { { BLASTED, 55.4, 32.2, "Blasted Lands", "Terres foudroyées" } } },

  -- Level 60 set
  { key = "magma", item = 228133, quest = 84396, set = 60, icon = "inv_misc_book_10", name = "Magma or Lava?", frName = "Magma ou lave ?", locs = { { BURNING, 29.6, 28.2, "Inside Blackrock Mountain, platform before the Blackrock Depths entrance (48.4, 63.6 on the mountain map)", "Dans le mont Rochenoire, plateforme avant l'entrée des Profondeurs (48.4, 63.6 sur la carte du mont)" } } },
  { key = "kalimdor", item = 228134, quest = 84397, set = 60, icon = "inv_misc_book_03", name = "Northern Kalimdor - A Comprehensive Guide", frName = "Le guide complet du nord de Kalimdor", locs = { { FELWOOD, 65.2, 3.3, "Timbermaw Hold tunnel, Felwood", "Tunnel du Repaire des Grumegueules, Gangrebois" } } },
  { key = "undeadpotatoes", item = 228132, quest = 84395, set = 60, icon = "inv_misc_book_09", name = "Undead Potatoes", frName = "Pommes de terre mortes-vivantes", locs = { { WPL, 38.3, 54.6, "Felstone Field, Western Plaguelands", "Champ de Gangrepierre, Maleterres de l'ouest" } } },
  { key = "knightlady", item = 228138, quest = 84400, set = 60, icon = "inv_misc_book_04", name = "The Knight and the Lady", frName = "La Dame et le Chevalier", locs = { { EPL, 47.3, 42.3, "Eastern Plaguelands", "Maleterres de l'est" } } },
  { key = "scourge", item = 228140, quest = 84401, set = 60, icon = "inv_misc_book_01", name = "Scourge: Undead Menace or Misunderstood?", frName = "Le Fléau : menace morte-vivante ou phénomène incompris ?", locs = { { EPL, 31.3, 21.0, "Eastern Plaguelands", "Maleterres de l'est" } } },
  { key = "studylight", item = 228135, quest = 84398, set = 60, icon = "inv_misc_book_13", name = "A Study of the Light", frName = "Étude de la Lumière", locs = { { EPL, 71.8, 48.2, "Light's Hope Chapel, Eastern Plaguelands", "Chapelle de l'Espoir de Lumière, Maleterres de l'est" } } },
  { key = "kaboom", item = 228136, quest = 84399, set = 60, icon = "inv_misc_book_11", name = "Ka-Boom!", frName = "Badaboum !", locs = { { WINTERSPRING, 60.7, 37.7, "Everlook, Winterspring", "Long-Guet, Berceau-de-l'Hiver" } } },
  { key = "necromancy", item = 228141, quest = 84402, set = 60, icon = "inv_misc_book_06", name = "Necromancy 101", frName = "La nécromancie pour les nuls", locs = { { WPL, 69.4, 72.8, "Caer Darrow keep, Western Plaguelands", "Donjon de Caer Darrow, Maleterres de l'ouest" } } },
}
