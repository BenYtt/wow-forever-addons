local ADDON, FLT = ...

FLT.mapNameToID = {}

-- Recorded quest-start locations for dungeon quests (verified against the
-- Wowhead Classic/Forever quest maps, 2026-09-29). Coordinates are percentages
-- on the Classic/Forever world-map canvas. Entries are intentionally limited to
-- starts that are known with enough confidence to place a marker.
FLT.QUEST_START_MAPS = {
  [92401] = { mapID=1421, x=44.50, y=43.00, label="Tabitha Heartweaver — Silverpine Forest" },
  [95216] = { mapID=1458, x=46.31, y=71.91, label="Theodore Griffs — Undercity" },

  [214]  = { mapID=1436, x=56.67, y=47.35, label="Scout Riell — Westfall" },
  [168]  = { mapID=1453, x=70.31, y=40.82, label="Wilder Thistlenettle — Stormwind City" },
  [167]  = { mapID=1453, x=70.31, y=40.82, label="Wilder Thistlenettle — Stormwind City" },
  [2040] = { mapID=1453, x=62.63, y=34.11, label="Shoni the Shilent — Stormwind City" },
  [166]  = { mapID=1436, x=56.33, y=47.52, label="Gryan Stoutmantle — Westfall" },
  [65]   = { mapID=1436, x=56.33, y=47.52, label="Gryan Stoutmantle — Westfall" },
  [135]  = { mapID=1436, x=56.33, y=47.52, label="Gryan Stoutmantle — Westfall" },
  [142]  = { mapID=1436, x=56.33, y=47.52, label="Gryan Stoutmantle — Westfall" },
  [155]  = { mapID=1436, x=55.68, y=47.50, label="The Defias Traitor — Westfall" },

  [5723] = { mapID=1456, x=70.14, y=29.52, label="Rahauro — Thunder Bluff" },
  [5722] = { mapID=1456, x=70.14, y=29.52, label="Rahauro — Thunder Bluff" },
  [5728] = { mapID=1454, x=31.73, y=37.82, label="Thrall — Orgrimmar" },
  [5726] = { mapID=1454, x=31.73, y=37.82, label="Thrall — Orgrimmar" },
  [5727] = { mapID=1454, x=31.73, y=37.82, label="Thrall — Orgrimmar" },
  [5761] = { mapID=1454, x=49.47, y=50.59, label="Neeru Fireblade — Orgrimmar" },
  [5725] = { mapID=1458, x=56.25, y=92.20, label="Varimathras — Undercity" },

  [971]  = { mapID=1455, x=50.83, y=5.62, label="Gerrig Bonegrip — Ironforge" },
  [1275] = { mapID=1439, x=38.33, y=43.04, label="Gershala Nightwhisper — Darkshore" },
  [1198] = { mapID=1457, x=55.36, y=25.03, label="Dawnwatcher Shaedlass — Darnassus" },
  [1199] = { mapID=1457, x=55.24, y=23.99, label="Argent Guard Manados — Darnassus" },
  [6563] = { mapID=1440, x=11.56, y=34.29, label="Je'neu Sancrea — Ashenvale" },
  [6562] = { mapID=1442, x=47.36, y=64.25, label="Tsunaman — Stonetalon Mountains" },
  [6565] = { mapID=1440, x=11.56, y=34.29, label="Je'neu Sancrea — Ashenvale" },
  [6921] = { mapID=1440, x=11.56, y=34.29, label="Je'neu Sancrea — Ashenvale" },

  [1486] = { mapID=1413, x=45.99, y=35.66, label="Nalpak — The Barrens" },
  [1487] = { mapID=1413, x=46.01, y=35.74, label="Ebru — The Barrens" },
  [962]  = { mapID=1456, x=22.81, y=20.89, label="Apothecary Zamah — Thunder Bluff" },
  [865]  = { mapID=1413, x=62.37, y=37.62, label="Mebok Mizzyrix — The Barrens" },
  [1491] = { mapID=1413, x=62.37, y=37.62, label="Mebok Mizzyrix — The Barrens" },
  [959]  = { mapID=1413, x=63.09, y=37.61, label="Crane Operator Bigglefuzz — The Barrens" },
  [914]  = { mapID=1456, x=75.65, y=31.61, label="Nara Wildmane — Thunder Bluff" },
  [6981] = { mapID=1413, x=62.98, y=37.22, label="Sputtervalve — The Barrens" },

  [1098] = { mapID=1421, x=43.42, y=40.86, label="High Executor Hadrec — Silverpine Forest" },
  [1740] = { mapID=1413, x=49.31, y=57.21, label="Doan Karhan — The Barrens" },
  [1013] = { mapID=1458, x=53.74, y=54.46, label="Keeper Bel'dugur — Undercity" },
  [1014] = { mapID=1421, x=44.20, y=39.81, label="Dalar Dawnweaver — Silverpine Forest" },

  -- Hall of Thanes
  [96403] = { mapID=1455, x=32.00, y=45.00, label="Thom Filch — Ironforge" },
  [96394] = { mapID=1455, x=33.90, y=48.10, label="Afadra Dunwall — Ironforge" },
  [96393] = { mapID=1426, x=64.80, y=58.50, label="Earthseer Farsen — Dun Morogh" },

  -- The Deadmines (Forever)

  -- The Stockade (Wowhead Forever quest pages)
  [386]  = { mapID=1433, x=21.17, y=46.58, label="Guard Berton — Redridge Mountains" },
  [377]  = { mapID=1431, x=71.92, y=47.79, label="Councilman Millstipe — Duskwood" },
  [378]  = { mapID=1437, x=49.67, y=18.23, label="Motley Garmason — Wetlands" },
  [303]  = { mapID=1437, x=49.67, y=18.23, label="Motley Garmason — Wetlands" },
  [387]  = { mapID=1453, x=51.49, y=69.38, label="Warden Thelwater — Stormwind City" },
  [391]  = { mapID=1453, x=51.49, y=69.38, label="Warden Thelwater — Stormwind City" },
  [388]  = { mapID=1453, x=73.78, y=54.65, label="Nikova Raskol — Stormwind City" },
  [389]  = { mapID=1453, x=57.74, y=47.86, label="Baros Alexston — Stormwind City" },

  -- Gnomeregan
  [2922] = { mapID=1455, x=69.55, y=50.33, label="Tinkmaster Overspark — Ironforge" },
  [2923] = { mapID=1453, x=51.05, y=48.39, label="Brother Sarno — Stormwind City" },
  [2924] = { mapID=1455, x=67.92, y=46.10, label="Klockmort Spannerspan — Ironforge" },
  [2925] = { mapID=1457, x=59.51, y=45.38, label="Mathiel — Darnassus" },
  [2926] = { mapID=1426, x=45.89, y=49.39, label="Ozzie Togglevolt — Dun Morogh" },
  [2962] = { mapID=1426, x=45.89, y=49.39, label="Ozzie Togglevolt — Dun Morogh" },
  [2927] = { mapID=1455, x=69.18, y=50.55, label="Gnoarn — Ironforge" },
  [2928] = { mapID=1453, x=62.63, y=34.11, label="Shoni the Shilent — Stormwind City" },
  [2929] = { mapID=1455, x=68.75, y=48.97, label="High Tinker Mekkatorque — Ironforge" },
  [2930] = { mapID=1455, x=69.83, y=48.10, label="Master Mechanic Castpipe — Ironforge" },
  [2931] = { mapID=1442, x=59.52, y=67.15, label="Gaxim Rustfizzle — Stonetalon Mountains" },
  [2841] = { mapID=1454, x=75.99, y=25.41, label="Nogg — Orgrimmar" },
  [2842] = { mapID=1454, x=75.49, y=25.36, label="Sovik — Orgrimmar" },
  [2843] = { mapID=1434, x=27.60, y=77.48, label="Scooty — Stranglethorn Vale" },

  -- Excavation Site: Wetlands
  [95647] = { mapID=1437, x=11.88, y=58.82, label="Caitlin Grassman — Wetlands" },
  [95772] = { mapID=1433, x=25.79, y=46.44, label="Dorin Songblade — Redridge Mountains" },
  [98815] = { mapID=1437, x=8.55, y=55.74, label="James Halloran — Wetlands" },
  [98824] = { mapID=1437, x=38.81, y=52.39, label="Prospector Whelgar — Wetlands" },

  -- Scarlet Monastery: Graveyard
  [1113] = { mapID=1458, x=48.82, y=69.28, label="Master Apothecary Faranell — Undercity" },
  [1109] = { mapID=1458, x=48.82, y=69.28, label="Master Apothecary Faranell — Undercity" },
  -- City of Dalaran / Forever additions (October 2026)
  [92456] = { mapID=1453, x=31.50, y=62.61, label="Shylamiir — Stormwind City" },
  [92489] = { mapID=1453, x=48.71, y=87.62, label="High Sorcerer Andromath — Stormwind City" },
  [96986] = { mapID=1424, x=62.63, y=20.65, label="Melisara — Hillsbrad Foothills" },
  [96988] = { mapID=1458, x=46.61, y=74.09, label="Doctor Martin Felben — Undercity" },
  [3369] = { mapID=1413, x=48.18, y=32.78, label="Falla Sagewind — The Barrens" },
  [3370] = { mapID=1413, x=48.18, y=32.78, label="Falla Sagewind — The Barrens" },
  [1654] = { mapID=1426, x=52.49, y=36.92, label="Jordan Stilwell — Dun Morogh" },
  -- Razorfen Kraul / Scarlet Monastery: Library (October 2026)
  [1221] = { mapID=1413, x=62.37, y=37.62, label="Mebok Mizzyrix — The Barrens" },
  [1101] = { mapID=1444, x=89.64, y=46.57, label="Falfindel Waywarder — Feralas" },
  [1102] = { mapID=1456, x=35.97, y=59.92, label="Auld Stonespire — Thunder Bluff" },
  [6521] = { mapID=1458, x=56.25, y=92.20, label="Varimathras — Undercity" },
  [1050] = { mapID=1455, x=74.97, y=12.48, label="Librarian Mae Paledust — Ironforge" },
  [1049] = { mapID=1456, x=34.40, y=46.87, label="Sage Truthseeker — Thunder Bluff" },
  [1160] = { mapID=1458, x=57.80, y=65.42, label="Parqual Fintallas — Undercity" },
  -- Armory to Sunken Temple (October 2026, QuestieDB Forever spawns)
  [1048] = { mapID=1458, x=56.20, y=92.20, label="Varimathras — Undercity" },
  [1053] = { mapID=1424, x=51.50, y=58.40, label="Raleigh the Devout — Hillsbrad Foothills" },
  [6626] = { mapID=1413, x=49.00, y=94.90, label="Myriam Moonsinger — The Barrens" },
  [3341] = { mapID=1458, x=74.00, y=33.30, label="Andrew Brownell — Undercity" },
  [3636] = { mapID=1453, x=50.30, y=45.50, label="Archbishop Benedictus — Stormwind City" },
  [1360] = { mapID=1455, x=74.20, y=9.40, label="Krom Stoutarm — Ironforge" },
  [2342] = { mapID=1458, x=62.30, y=48.60, label="Patrick Garrett — Undercity" },
  [2398] = { mapID=1455, x=74.60, y=11.70, label="Prospector Stormpike — Ironforge" },
  [17] = { mapID=1432, x=37.10, y=49.40, label="Ghak Healtouch — Loch Modan" },
  [2202] = { mapID=1418, x=2.40, y=46.10, label="Jarkal Mossmeld — Badlands" },
  [704] = { mapID=1432, x=65.90, y=65.60, label="Prospector Ironband — Loch Modan" },
  [1139] = { mapID=1455, x=77.30, y=9.70, label="Advisor Belgrum — Ironforge" },
  [2200] = { mapID=1455, x=36.40, y=3.60, label="Talvash del Kissel — Ironforge" },
  [2361] = { mapID=1455, x=36.40, y=3.60, label="Talvash del Kissel — Ironforge" },
  [2283] = { mapID=1454, x=59.50, y=36.60, label="Dran Droffers — Orgrimmar" },
  [2284] = { mapID=1454, x=59.50, y=36.60, label="Dran Droffers — Orgrimmar" },
  [2339] = { mapID=1418, x=2.40, y=46.10, label="Jarkal Mossmeld — Badlands" },
  [2418] = { mapID=1418, x=42.40, y=52.90, label="Rigglefuzz — Badlands" },
  [709] = { mapID=1418, x=51.40, y=76.90, label="Theldurin the Lost — Badlands" },
  [1956] = { mapID=1445, x=46.10, y=57.10, label="Tabetha — Dustwallow Marsh" },
  [2936] = { mapID=1411, x=56.00, y=74.70, label="Master Gadrin — Durotar" },
  [2991] = { mapID=1419, x=66.90, y=19.50, label="Thadius Grimshade — Blasted Lands" },
  [2768] = { mapID=1446, x=52.50, y=28.50, label="Chief Engineer Bilgewhizzle — Tanaris" },
  [2865] = { mapID=1446, x=51.60, y=26.80, label="Tran'rek — Tanaris" },
  [3042] = { mapID=1446, x=51.40, y=28.80, label="Trenton Lighthammer — Tanaris" },
  [2846] = { mapID=1445, x=46.10, y=57.10, label="Tabetha — Dustwallow Marsh" },
  [2770] = { mapID=1441, x=78.10, y=77.10, label="Wizzle Brassbolts — Thousand Needles" },
  [3527] = { mapID=1446, x=67.00, y=22.40, label="Yeh'kinya — Tanaris" },
  [7068] = { mapID=1454, x=39.20, y=86.30, label="Uthel'nay — Orgrimmar" },
  [7070] = { mapID=1445, x=66.40, y=49.30, label="Archmage Tervosh — Dustwallow Marsh" },
  [7029] = { mapID=1443, x=23.20, y=70.30, label="Vark Battlescar — Desolace" },
  [7041] = { mapID=1443, x=68.50, y=8.90, label="Talendria — Desolace" },
  [7028] = { mapID=1443, x=62.20, y=39.60, label="Willow — Desolace" },
  [7067] = { mapID=1443, x=50.40, y=86.70, label="Centaur Pariah — Desolace" },
  [7044] = { mapID=1443, x=32.10, y=64.00, label="Cavindra — Desolace" },
  [7064] = { mapID=1443, x=26.90, y=77.70, label="Selendra — Desolace" },
  [7065] = { mapID=1443, x=63.80, y=10.70, label="Keeper Marandis — Desolace" },
  [1445] = { mapID=1435, x=47.90, y=54.80, label="Fel'zerul — Swamp of Sorrows" },
  [1475] = { mapID=1453, x=69.50, y=40.40, label="Brohann Caskbelly — Stormwind City" },
  [1446] = { mapID=1425, x=33.80, y=75.20, label="Atal'ai Exile — The Hinterlands" },
  [3446] = { mapID=1446, x=52.70, y=45.90, label="Marvon Rivetseeker — Tanaris" },
  [3447] = { mapID=1446, x=52.70, y=45.90, label="Marvon Rivetseeker — Tanaris" },
  [3528] = { mapID=1446, x=67.00, y=22.40, label="Yeh'kinya — Tanaris" },
  [9053] = { mapID=1449, x=71.60, y=76.00, label="Torwa Pathfinder — Un'Goro Crater" },
  [8232] = { mapID=1447, x=42.40, y=42.60, label="Ogtinc — Azshara" },
  [8253] = { mapID=1447, x=29.20, y=40.20, label="Archmage Xylem — Azshara" },
  [8257] = { mapID=1447, x=42.40, y=42.60, label="Ogtinc — Azshara" },
  [8236] = { mapID=1447, x=29.20, y=40.20, label="Archmage Xylem — Azshara" },
  [8422] = { mapID=1448, x=41.40, y=45.00, label="Impsy — Felwood" },
  [8425] = { mapID=1435, x=34.30, y=66.10, label="Fallen Hero of the Horde — Swamp of Sorrows" },
  [96774] = { mapID=1412, x=32.40, y=20.40, label="Mazu'kon — Mulgore" },
  [261] = { mapID=1443, x=66.50, y=7.90, label="Brother Anton — Desolace" },
  [1052] = { mapID=1443, x=66.50, y=7.90, label="Brother Anton — Desolace" },
  [2500] = { mapID=1432, x=37.10, y=49.40, label="Ghak Healtouch — Loch Modan" },
  [2258] = { mapID=1418, x=2.40, y=46.10, label="Jarkal Mossmeld — Badlands" },
  [707] = { mapID=1455, x=74.60, y=11.70, label="Prospector Stormpike — Ironforge" },
  [738] = { mapID=1432, x=65.90, y=65.60, label="Prospector Ironband — Loch Modan" },
  [721] = { mapID=1418, x=53.40, y=43.40, label="Prospector Ryedol — Badlands" },
  [724] = { mapID=1418, x=53.40, y=43.40, label="Prospector Ryedol — Badlands" },
  [725] = { mapID=1455, x=77.50, y=11.80, label="Historian Karnik — Ironforge" },
  [726] = { mapID=1455, x=77.30, y=9.70, label="Advisor Belgrum — Ironforge" },
  [762] = { mapID=1455, x=77.50, y=11.80, label="Historian Karnik — Ironforge" },
  [2199] = { mapID=1455, x=36.40, y=3.60, label="Talvash del Kissel — Ironforge" },
  [2338] = { mapID=1418, x=2.40, y=46.10, label="Jarkal Mossmeld — Badlands" },
  [1953] = { mapID=1458, x=85.10, y=10.00, label="Anastasia Hartwell — Undercity" },
  [1954] = { mapID=1445, x=46.10, y=57.10, label="Tabetha — Dustwallow Marsh" },
  [1955] = { mapID=1445, x=46.10, y=57.10, label="Tabetha — Dustwallow Marsh" },
  [2934] = { mapID=1424, x=61.40, y=19.10, label="Apothecary Lydon — Hillsbrad Foothills" },
  [2935] = { mapID=1424, x=61.40, y=19.10, label="Apothecary Lydon — Hillsbrad Foothills" },
  [2988] = { mapID=1425, x=9.80, y=44.50, label="Gryphon Master Talonaxe — The Hinterlands" },
  [2989] = { mapID=1425, x=9.80, y=44.50, label="Gryphon Master Talonaxe — The Hinterlands" },
  [2990] = { mapID=1425, x=9.80, y=44.50, label="Gryphon Master Talonaxe — The Hinterlands" },
  [2864] = { mapID=1434, x=26.90, y=77.20, label="Krazek — Stranglethorn Vale" },
  [3520] = { mapID=1446, x=67.00, y=22.40, label="Yeh'kinya — Tanaris" },
  [1424] = { mapID=1435, x=47.90, y=54.80, label="Fel'zerul — Swamp of Sorrows" },
  [1429] = { mapID=1435, x=47.90, y=54.80, label="Fel'zerul — Swamp of Sorrows" },
  [1444] = { mapID=1425, x=33.80, y=75.20, label="Atal'ai Exile — The Hinterlands" },
  [1448] = { mapID=1453, x=69.50, y=40.40, label="Brohann Caskbelly — Stormwind City" },
  [1449] = { mapID=1453, x=69.50, y=40.40, label="Brohann Caskbelly — Stormwind City" },
  [1450] = { mapID=1425, x=11.80, y=46.80, label="Falstad Wildhammer — The Hinterlands" },
  [1451] = { mapID=1425, x=9.80, y=44.50, label="Gryphon Master Talonaxe — The Hinterlands" },
  [1452] = { mapID=1425, x=26.90, y=48.60, label="Rhapsody Shindigger — The Hinterlands" },
  [1469] = { mapID=1425, x=26.90, y=48.60, label="Rhapsody Shindigger — The Hinterlands" },
  [3380] = { mapID=1444, x=74.40, y=43.40, label="Witch Doctor Uzer'i — Feralas" },
  [3444] = { mapID=1446, x=52.70, y=45.90, label="Marvon Rivetseeker — Tanaris" },
  [4787] = { mapID=1446, x=67.00, y=22.40, label="Yeh'kinya — Tanaris" },
  [9063] = { mapID=1456, x=76.50, y=27.20, label="Turak Runetotem — Thunder Bluff" },
  [9052] = { mapID=1449, x=71.60, y=76.00, label="Torwa Pathfinder — Un'Goro Crater" },
  [9051] = { mapID=1449, x=71.60, y=76.00, label="Torwa Pathfinder — Un'Goro Crater" },
  [8151] = { mapID=1456, x=58.50, y=88.30, label="Kary Thunderhorn — Thunder Bluff" },
  [8153] = { mapID=1447, x=42.40, y=42.60, label="Ogtinc — Azshara" },
  [8231] = { mapID=1447, x=42.40, y=42.60, label="Ogtinc — Azshara" },
  [8250] = { mapID=1456, x=25.20, y=21.00, label="Thurston Xane — Thunder Bluff" },
  [8251] = { mapID=1447, x=29.20, y=40.20, label="Archmage Xylem — Azshara" },
  [8252] = { mapID=1447, x=29.20, y=40.20, label="Archmage Xylem — Azshara" },
  [8254] = { mapID=1453, x=49.50, y=44.60, label="High Priestess Laurena — Stormwind City" },
  [8255] = { mapID=1447, x=42.40, y=42.60, label="Ogtinc — Azshara" },
  [8256] = { mapID=1447, x=42.40, y=42.60, label="Ogtinc — Azshara" },
  [8233] = { mapID=1454, x=43.90, y=54.60, label="Ormok — Orgrimmar" },
  [8234] = { mapID=1416, x=86.00, y=78.90, label="Lord Jorach Ravenholdt — Alterac Mountains" },
  [8235] = { mapID=1447, x=29.20, y=40.20, label="Archmage Xylem — Azshara" },
  [8419] = { mapID=1453, x=39.20, y=85.00, label="Demisette Cloyce — Stormwind City" },
  [8421] = { mapID=1448, x=41.40, y=45.00, label="Impsy — Felwood" },
  [8423] = { mapID=1435, x=34.30, y=66.10, label="Fallen Hero of the Horde — Swamp of Sorrows" },
  [8424] = { mapID=1435, x=34.30, y=66.10, label="Fallen Hero of the Horde — Swamp of Sorrows" },
  -- Blackrock Depths to Stratholme (October 2026, QuestieDB Forever spawns)
  [4134] = { mapID=1418, x=2.90, y=47.80, label="Shadowmage Vivian Lagrave — Badlands" },
  [4063] = { mapID=1418, x=25.90, y=44.90, label="Lotwil Veriatus — Badlands" },
  [3906] = { mapID=1418, x=3.30, y=48.30, label="Thunderheart — Badlands" },
  [3907] = { mapID=1418, x=3.30, y=48.30, label="Thunderheart — Badlands" },
  [3981] = { mapID=1418, x=6.00, y=47.70, label="Galamav the Marksman — Badlands" },
  [7201] = { mapID=1418, x=2.90, y=47.80, label="Shadowmage Vivian Lagrave — Badlands" },
  [4132] = { mapID=1418, x=5.80, y=47.50, label="Warlord Goretooth — Badlands" },
  [4003] = { mapID=1454, x=31.70, y=37.80, label="Thrall — Orgrimmar" },
  [4262] = { mapID=1428, x=85.40, y=70.10, label="Jalinda Sprig — Burning Steppes" },
  [4263] = { mapID=1428, x=85.40, y=70.10, label="Jalinda Sprig — Burning Steppes" },
  [4286] = { mapID=1428, x=84.60, y=68.70, label="Oralius — Burning Steppes" },
  [4126] = { mapID=1426, x=46.80, y=52.40, label="Ragnar Thunderbrew — Dun Morogh" },
  [4341] = { mapID=1455, x=39.10, y=56.20, label="King Magni Bronzebeard — Ironforge" },
  [4362] = { mapID=1455, x=39.10, y=56.20, label="King Magni Bronzebeard — Ironforge" },
  [4241] = { mapID=1428, x=84.70, y=69.00, label="Marshal Maxwell — Burning Steppes" },
  [4136] = { mapID=1428, x=66.10, y=21.90, label="Yuka Screwspigot — Burning Steppes" },
  [4123] = { mapID=1428, x=65.20, y=23.90, label="Maxwort Uberglint — Burning Steppes" },
  [4024] = { mapID=1428, x=95.10, y=31.60, label="Cyrus Therepentous — Burning Steppes" },
  [4724] = { mapID=1418, x=6.00, y=47.70, label="Galamav the Marksman — Badlands" },
  [4981] = { mapID=1418, x=5.90, y=47.60, label="Lexlort — Badlands" },
  [4903] = { mapID=1418, x=5.80, y=47.50, label="Warlord Goretooth — Badlands" },
  [4701] = { mapID=1428, x=85.80, y=69.00, label="Helendis Riverhorn — Burning Steppes" },
  [4862] = { mapID=1428, x=65.90, y=21.90, label="Kibler — Burning Steppes" },
  [4729] = { mapID=1428, x=65.90, y=21.90, label="Kibler — Burning Steppes" },
  [4866] = { mapID=1428, x=65.00, y=23.80, label="Ragged John — Burning Steppes" },
  [4788] = { mapID=1446, x=66.90, y=24.00, label="Prospector Ironboot — Tanaris" },
  [5127] = { mapID=1452, x=63.80, y=73.80, label="Lorax — Winterspring" },
  [4734] = { mapID=1428, x=65.20, y=24.00, label="Tinkee Steamboil — Burning Steppes" },
  [4735] = { mapID=1428, x=65.20, y=24.00, label="Tinkee Steamboil — Burning Steppes" },
  [4768] = { mapID=1418, x=2.90, y=47.80, label="Shadowmage Vivian Lagrave — Badlands" },
  [4974] = { mapID=1454, x=31.70, y=37.80, label="Thrall — Orgrimmar" },
  [6569] = { mapID=1422, x=50.80, y=77.80, label="Myranda the Hag — Western Plaguelands" },
  [6602] = { mapID=1444, x=46.40, y=18.20, label="Rexxar — Feralas" },
  [5102] = { mapID=1428, x=84.70, y=69.00, label="Marshal Maxwell — Burning Steppes" },
  [6502] = { mapID=1452, x=54.50, y=51.20, label="Haleh — Winterspring" },
  [7489] = { mapID=1444, x=76.20, y=43.80, label="Talo Thornhoof — Feralas" },
  [7488] = { mapID=1444, x=30.40, y=46.20, label="Latronicus Moonspear — Feralas" },
  [7441] = { mapID=1444, x=76.90, y=37.40, label="Azj'Tordin — Feralas" },
  [5526] = { mapID=1450, x=51.70, y=45.10, label="Rabine Saturna — Moonglade" },
  [7481] = { mapID=1444, x=75.20, y=43.80, label="Sage Korolusk — Feralas" },
  [7482] = { mapID=1444, x=31.60, y=43.50, label="Scholar Runethorn — Feralas" },
  [5529] = { mapID=1423, x=71.70, y=49.90, label="Betina Bigglezink — Eastern Plaguelands" },
  [5341] = { mapID=1420, x=83.10, y=71.60, label="Alexi Barov — Tirisfal Glades" },
  [5343] = { mapID=1422, x=43.50, y=83.70, label="Weldon Barov — Western Plaguelands" },
  [5382] = { mapID=1422, x=70.20, y=73.70, label="Eva Sarkhoff — Western Plaguelands" },
  [5515] = { mapID=1422, x=70.20, y=73.70, label="Eva Sarkhoff — Western Plaguelands" },
  [5384] = { mapID=1422, x=70.20, y=73.70, label="Eva Sarkhoff — Western Plaguelands" },
  [5466] = { mapID=1422, x=70.60, y=74.10, label="Magistrate Marduke — Western Plaguelands" },
  [4771] = { mapID=1423, x=71.70, y=49.90, label="Betina Bigglezink — Eastern Plaguelands" },
  [5505] = { mapID=1422, x=42.70, y=83.80, label="Alchemist Arbington — Western Plaguelands" },
  [5511] = { mapID=1420, x=83.10, y=68.90, label="High Executor Derrington — Tirisfal Glades" },
  [7629] = { mapID=1428, x=12.40, y=31.60, label="Gorzeeki Wildeyes — Burning Steppes" },
  [7647] = { mapID=1453, x=48.40, y=50.20, label="Lord Grayson Shadowbreaker — Stormwind City" },
  [8258] = { mapID=1454, x=38.70, y=35.90, label="Sagorne Creststrider — Orgrimmar" },
  [5212] = { mapID=1423, x=71.70, y=49.90, label="Betina Bigglezink — Eastern Plaguelands" },
  [5213] = { mapID=1423, x=71.70, y=49.90, label="Betina Bigglezink — Eastern Plaguelands" },
  [5214] = { mapID=1423, x=70.90, y=48.40, label="Smokey LaRue — Eastern Plaguelands" },
  [5243] = { mapID=1423, x=71.90, y=48.30, label="Leonid Barthalomew the Revered — Eastern Plaguelands" },
  [5251] = { mapID=1423, x=71.60, y=50.10, label="Duke Nicholas Zverenhoff — Eastern Plaguelands" },
  [5263] = { mapID=1423, x=71.60, y=50.10, label="Duke Nicholas Zverenhoff — Eastern Plaguelands" },
  [5282] = { mapID=1423, x=11.40, y=26.60, label="Egan — Eastern Plaguelands" },
  [5463] = { mapID=1423, x=71.90, y=48.30, label="Leonid Barthalomew the Revered — Eastern Plaguelands" },
  [5848] = { mapID=1422, x=65.80, y=75.40, label="Artist Renfray — Western Plaguelands" },
  [6163] = { mapID=1423, x=22.20, y=63.50, label="Nathanos Blightcaller — Eastern Plaguelands" },
  [8945] = { mapID=1423, x=26.10, y=11.30, label="Anthion Harmon — Eastern Plaguelands" },
  [5305] = { mapID=1452, x=61.30, y=37.10, label="Lilith the Lithe — Winterspring" },
  [5307] = { mapID=1452, x=61.30, y=37.20, label="Seril Scourgebane — Winterspring" },
  [4133] = { mapID=1458, x=50.10, y=68.00, label="Apothecary Zinge — Undercity" },
  [4061] = { mapID=1418, x=3.00, y=47.80, label="Hierophant Theodora Mulvadania — Badlands" },
  [4062] = { mapID=1418, x=3.00, y=47.80, label="Hierophant Theodora Mulvadania — Badlands" },
  [4122] = { mapID=1418, x=5.90, y=47.60, label="Lexlort — Badlands" },
  [4121] = { mapID=1428, x=40.20, y=34.20, label="Grark Lorkrub — Burning Steppes" },
  [4002] = { mapID=1454, x=31.70, y=37.80, label="Thrall — Orgrimmar" },
  [4128] = { mapID=1419, x=63.60, y=20.60, label="Enohar Thunderbrew — Blasted Lands" },
  [3702] = { mapID=1455, x=38.40, y=55.30, label="Royal Historian Archesonus — Ironforge" },
  [3701] = { mapID=1455, x=38.40, y=55.30, label="Royal Historian Archesonus — Ironforge" },
  [4182] = { mapID=1428, x=85.80, y=69.00, label="Helendis Riverhorn — Burning Steppes" },
  [4183] = { mapID=1428, x=85.80, y=69.00, label="Helendis Riverhorn — Burning Steppes" },
  [4184] = { mapID=1433, x=24.90, y=44.50, label="Magistrate Solomon — Redridge Mountains" },
  [4185] = { mapID=1453, x=80.20, y=38.40, label="Highlord Bolvar Fordragon — Stormwind City" },
  [4186] = { mapID=1453, x=80.20, y=38.40, label="Highlord Bolvar Fordragon — Stormwind City" },
  [4223] = { mapID=1433, x=24.90, y=44.50, label="Magistrate Solomon — Redridge Mountains" },
  [4224] = { mapID=1428, x=84.70, y=69.00, label="Marshal Maxwell — Burning Steppes" },
  [4324] = { mapID=1446, x=67.00, y=24.00, label="Yorba Screwspigot — Tanaris" },
  [3441] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3442] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3443] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3452] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3453] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3454] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3462] = { mapID=1427, x=39.10, y=39.00, label="Kalaran Windblade — Searing Gorge" },
  [3463] = { mapID=1427, x=39.20, y=39.00, label="Squire Maltrake — Searing Gorge" },
  [4022] = { mapID=1428, x=95.10, y=31.60, label="Cyrus Therepentous — Burning Steppes" },
  [5065] = { mapID=1446, x=66.90, y=24.00, label="Prospector Ironboot — Tanaris" },
  [5126] = { mapID=1452, x=63.80, y=73.80, label="Lorax — Winterspring" },
  [4726] = { mapID=1428, x=65.20, y=24.00, label="Tinkee Steamboil — Burning Steppes" },
  [4808] = { mapID=1428, x=65.20, y=24.00, label="Tinkee Steamboil — Burning Steppes" },
  [4809] = { mapID=1452, x=61.60, y=38.60, label="Felnok Steelspring — Winterspring" },
  [4810] = { mapID=1452, x=61.60, y=38.60, label="Felnok Steelspring — Winterspring" },
  [4769] = { mapID=1458, x=50.10, y=68.00, label="Apothecary Zinge — Undercity" },
  [4941] = { mapID=1418, x=5.80, y=47.50, label="Warlord Goretooth — Badlands" },
  [6566] = { mapID=1454, x=31.70, y=37.80, label="Thrall — Orgrimmar" },
  [6567] = { mapID=1454, x=31.70, y=37.80, label="Thrall — Orgrimmar" },
  [6568] = { mapID=1444, x=46.40, y=18.20, label="Rexxar — Feralas" },
  [6570] = { mapID=1422, x=50.80, y=77.80, label="Myranda the Hag — Western Plaguelands" },
  [6582] = { mapID=1445, x=56.70, y=87.70, label="Emberstrife — Dustwallow Marsh" },
  [6583] = { mapID=1445, x=56.70, y=87.70, label="Emberstrife — Dustwallow Marsh" },
  [6584] = { mapID=1445, x=56.70, y=87.70, label="Emberstrife — Dustwallow Marsh" },
  [6585] = { mapID=1445, x=56.70, y=87.70, label="Emberstrife — Dustwallow Marsh" },
  [6601] = { mapID=1445, x=56.70, y=87.70, label="Emberstrife — Dustwallow Marsh" },
  [6402] = { mapID=1428, x=84.70, y=69.00, label="Marshal Maxwell — Burning Steppes" },
  [6501] = { mapID=1453, x=80.20, y=38.40, label="Highlord Bolvar Fordragon — Stormwind City" },
  [7492] = { mapID=1454, x=37.60, y=75.40, label="Warcaller Gorlach — Orgrimmar" },
  [7494] = { mapID=1453, x=56.40, y=74.10, label="Crier Goodman — Stormwind City" },
  [5527] = { mapID=1450, x=51.70, y=45.10, label="Rabine Saturna — Moonglade" },
  [5461] = { mapID=1422, x=70.60, y=74.10, label="Magistrate Marduke — Western Plaguelands" },
  [5462] = { mapID=1422, x=70.60, y=74.10, label="Magistrate Marduke — Western Plaguelands" },
  [5465] = { mapID=1423, x=71.90, y=48.30, label="Leonid Barthalomew the Revered — Eastern Plaguelands" },
  [5522] = { mapID=1428, x=65.20, y=24.00, label="Tinkee Steamboil — Burning Steppes" },
  [5531] = { mapID=1423, x=71.90, y=48.30, label="Leonid Barthalomew the Revered — Eastern Plaguelands" },
  [5066] = { mapID=1453, x=56.40, y=74.10, label="Crier Goodman — Stormwind City" },
  [5092] = { mapID=1422, x=42.70, y=84.00, label="Commander Ashlam Valorfist — Western Plaguelands" },
  [5097] = { mapID=1422, x=42.70, y=84.00, label="Commander Ashlam Valorfist — Western Plaguelands" },
  [5533] = { mapID=1422, x=42.70, y=84.00, label="Commander Ashlam Valorfist — Western Plaguelands" },
  [5537] = { mapID=1422, x=42.70, y=83.80, label="Alchemist Arbington — Western Plaguelands" },
  [5538] = { mapID=1422, x=42.70, y=83.80, label="Alchemist Arbington — Western Plaguelands" },
  [5801] = { mapID=1446, x=51.50, y=28.80, label="Krinkle Goodsteel — Tanaris" },
  [5803] = { mapID=1422, x=42.70, y=83.80, label="Alchemist Arbington — Western Plaguelands" },
  [5093] = { mapID=1454, x=37.60, y=75.40, label="Warcaller Gorlach — Orgrimmar" },
  [5096] = { mapID=1420, x=83.10, y=68.90, label="High Executor Derrington — Tirisfal Glades" },
  [5098] = { mapID=1420, x=83.10, y=68.90, label="High Executor Derrington — Tirisfal Glades" },
  [838] = { mapID=1420, x=83.10, y=68.90, label="High Executor Derrington — Tirisfal Glades" },
  [964] = { mapID=1420, x=83.30, y=69.20, label="Apothecary Dithers — Tirisfal Glades" },
  [5514] = { mapID=1420, x=83.30, y=69.20, label="Apothecary Dithers — Tirisfal Glades" },
  [5802] = { mapID=1446, x=51.50, y=28.80, label="Krinkle Goodsteel — Tanaris" },
  [5804] = { mapID=1420, x=83.30, y=69.20, label="Apothecary Dithers — Tirisfal Glades" },
  [7562] = { mapID=1453, x=39.50, y=84.50, label="Spackle Thornberry — Stormwind City" },
  [7563] = { mapID=1428, x=12.70, y=31.60, label="Mor'zul Bloodbringer — Burning Steppes" },
  [7564] = { mapID=1428, x=12.70, y=31.60, label="Mor'zul Bloodbringer — Burning Steppes" },
  [7623] = { mapID=1428, x=12.40, y=31.60, label="Gorzeeki Wildeyes — Burning Steppes" },
  [7624] = { mapID=1448, x=35.90, y=44.40, label="Lord Banehollow — Felwood" },
  [7625] = { mapID=1448, x=35.90, y=44.40, label="Lord Banehollow — Felwood" },
  [7638] = { mapID=1453, x=50.50, y=47.50, label="Duthorian Rall — Stormwind City" },
  [7637] = { mapID=1453, x=48.40, y=50.20, label="Lord Grayson Shadowbreaker — Stormwind City" },
  [7639] = { mapID=1455, x=24.70, y=8.20, label="High Priest Rohan — Ironforge" },
  [7640] = { mapID=1453, x=48.40, y=50.20, label="Lord Grayson Shadowbreaker — Stormwind City" },
  [7641] = { mapID=1453, x=48.40, y=50.20, label="Lord Grayson Shadowbreaker — Stormwind City" },
  [7642] = { mapID=1453, x=59.70, y=33.80, label="Grimand Elmore — Stormwind City" },
  [7643] = { mapID=1453, x=48.40, y=50.20, label="Lord Grayson Shadowbreaker — Stormwind City" },
  [7646] = { mapID=1453, x=48.40, y=50.20, label="Lord Grayson Shadowbreaker — Stormwind City" },
  [7667] = { mapID=1454, x=38.70, y=35.90, label="Sagorne Creststrider — Orgrimmar" },
  [5281] = { mapID=1423, x=69.90, y=53.70, label="Caretaker Alen — Eastern Plaguelands" },
  [5542] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [5543] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [5544] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [5742] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [5781] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [5845] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [5846] = { mapID=1423, x=5.20, y=35.60, label="Tirion Fordring — Eastern Plaguelands" },
  [6133] = { mapID=1423, x=22.20, y=63.50, label="Nathanos Blightcaller — Eastern Plaguelands" },
  [6135] = { mapID=1423, x=22.20, y=63.50, label="Nathanos Blightcaller — Eastern Plaguelands" },
  [8905] = { mapID=1455, x=43.50, y=52.60, label="Deliana — Ironforge" },
  [8922] = { mapID=1455, x=43.50, y=52.60, label="Deliana — Ironforge" },
  [8921] = { mapID=1446, x=52.50, y=27.20, label="Mux Manascrambler — Tanaris" },
  [8924] = { mapID=1446, x=52.50, y=27.20, label="Mux Manascrambler — Tanaris" },
  [8925] = { mapID=1446, x=52.50, y=27.20, label="Mux Manascrambler — Tanaris" },
  [8928] = { mapID=1446, x=52.50, y=27.20, label="Mux Manascrambler — Tanaris" },
  [8977] = { mapID=1446, x=52.50, y=27.20, label="Mux Manascrambler — Tanaris" },
  [8926] = { mapID=1455, x=43.50, y=52.60, label="Deliana — Ironforge" },
  [8929] = { mapID=1455, x=43.50, y=52.60, label="Deliana — Ironforge" },
}

local function indexMap(id, depth)
  if not C_Map or not C_Map.GetMapInfo or depth > 5 then return end
  local info = C_Map.GetMapInfo(id)
  if info and info.name then FLT.mapNameToID[info.name:lower()] = id end
  if C_Map.GetMapChildrenInfo then
    local kids = C_Map.GetMapChildrenInfo(id, nil, true) or {}
    for _, k in ipairs(kids) do indexMap(k.mapID, depth + 1) end
  end
end

function FLT:BuildMapIndex()
  wipe(self.mapNameToID)
  for _, id in ipairs({947, 1414, 1415, 13, 12}) do pcall(indexMap, id, 0) end
end

local zoneMapCache = {} -- zone -> map ID or false (the book monitor asks every second)
function FLT:FindMapID(zone)
  if self.MAP_IDS and self.MAP_IDS[zone] then return self.MAP_IDS[zone] end
  if zone ~= nil and zoneMapCache[zone] ~= nil then return zoneMapCache[zone] or nil end
  if not next(self.mapNameToID) then self:BuildMapIndex() end
  local wanted = (zone or ""):lower()
  local found = self.mapNameToID[wanted]
  if not found then
    for name, id in pairs(self.mapNameToID) do
      if name == wanted or name:find(wanted, 1, true) or wanted:find(name, 1, true) then found = id; break end
    end
  end
  if zone ~= nil and next(self.mapNameToID) then zoneMapCache[zone] = found or false end
  return found
end

local marker
local function ensureMarker()
  if marker or not WorldMapFrame then return marker end
  local parent = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child or WorldMapFrame
  marker = CreateFrame("Button", "OneForAllMapPin", parent)
  marker:SetSize(46, 46)
  marker:SetFrameStrata("TOOLTIP")
  marker:SetFrameLevel(1000)

  local icon = marker:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints()
  icon:SetTexCoord(0, 1, 0, 1)
  icon:SetBlendMode("BLEND")
  icon:SetTexture((FLT.ASSET_ROOT or ("Interface\\AddOns\\" .. ADDON .. "\\Assets\\")) .. "map_pin")
  marker.icon = icon

  -- The pin lives on the map canvas, so it must only be visible while the map
  -- that it was placed on is displayed (else it stayed at the same canvas spot in another zone). Checked when the
  -- map changes (6.0.3: was an OnUpdate every 0.1 s).
  local function sync()
    local current = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    marker:SetAlpha((current == marker.mapID) and 1 or 0)
    marker:EnableMouse(current == marker.mapID)
  end
  marker.sync = sync
  if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() if marker:IsShown() then sync() end end) end
  -- a click removes it again (user 01.11.: there was no way to get rid of it)
  marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  marker:SetScript("OnClick", function(self) self:Hide(); GameTooltip:Hide() end)
  marker:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("OneForAll marker", 1, 0.82, 0)
    if self.label then GameTooltip:AddLine(self.label, 1, 1, 1, true) end
    GameTooltip:AddLine("Click: remove the marker", 0.4, 0.8, 1); GameTooltip:Show()
  end)
  marker:SetScript("OnLeave", function() GameTooltip:Hide() end)
  marker:Hide()
  return marker
end

local function forceMap(mapID)
  -- C_Map.OpenWorldMap is the most reliable route on modern Classic clients.
  if C_Map and C_Map.OpenWorldMap then
    local ok = pcall(C_Map.OpenWorldMap, mapID)
    if ok then return true end
  end

  if OpenWorldMap then
    local ok = pcall(OpenWorldMap, mapID)
    if ok then return true end
  end

  if WorldMapFrame then
    if not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    if WorldMapFrame.SetMapID then
      pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
      return true
    end
  end
  return false
end

local function positionMarker(book, mapID)
  if not WorldMapFrame then return end

  -- Some clients only accept SetMapID after the frame has become visible.
  if WorldMapFrame.SetMapID then
    local current = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    if current ~= mapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
  end

  local current = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if current and current ~= mapID then
    FLT.Msg("Could not switch the world map to " .. tostring(book.zone or book.label or "the recorded location") .. ". Try clicking Map again outside combat.")
    return
  end

  local m = ensureMarker()
  if not m then return end
  local parent = m:GetParent()
  local w, h = parent:GetWidth(), parent:GetHeight()
  if w and h and w > 0 and h > 0 then
    m:ClearAllPoints()
    m:SetPoint("BOTTOM", parent, "TOPLEFT", (book.x / 100) * w, -(book.y / 100) * h + 3)
    m.mapID = mapID
    m.label = book.label or book.name
    m:Show(); m.sync()
  end
end

function FLT:ShowOnMap(book)
  if not book.x or not book.y then
    self.Msg("No reliable map position is known for this book yet.")
    return
  end

  local mapID = book.mapID or self:FindMapID(book.zone)
  if not mapID then
    self.Msg("Could not determine the map ID for '" .. tostring(book.zone or book.label or "this location") .. "'.")
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.Msg("The world map cannot be switched by the addon during combat.")
    return
  end

  local m = ensureMarker()
  if m then m:Hide() end

  if not forceMap(mapID) then
    self.Msg("The world map could not be opened.")
    return
  end

  -- Run twice: the first pass handles clients that initialize the map asynchronously.
  C_Timer.After(0.05, function() positionMarker(book, mapID) end)
  C_Timer.After(0.25, function() positionMarker(book, mapID) end)
end

function FLT:ShowQuestStartOnMap(quest)
  if not quest or not quest.id then
    self.Msg("No recorded quest-start location is available.")
    return
  end
  local loc = self.QUEST_START_MAPS and self.QUEST_START_MAPS[quest.id]
  if not loc then
    self.Msg("No reliable map position is recorded for this quest start yet.")
    return
  end
  self:ShowOnMap(loc)
end

