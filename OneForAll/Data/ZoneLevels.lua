local _, FLT = ...

-- Level range of each zone for the world map (6.0.2, user 01.11.): uiMapID = { min, max }. The game gives no numbers
-- in Forever (C_Map.GetMapLevels is empty), so our own list: the long-known Classic ranges, and for the new Forever
-- zones what Blizzard / the guides name (Zephras Isle 1-12, Riverglades 35-45, Mount Hyjal 60). Shen'dralas: not known
-- yet. Cities and battlegrounds have none.
FLT.ZONE_LEVELS = {
  -- Kalimdor
  [1411] = { 1, 10 }, [1412] = { 1, 10 }, [1438] = { 1, 10 }, -- Durotar, Mulgore, Teldrassil
  [1439] = { 10, 20 }, [1413] = { 10, 25 }, [1442] = { 15, 27 }, -- Darkshore, The Barrens, Stonetalon Mountains
  [1440] = { 18, 30 }, [1441] = { 25, 35 }, [1443] = { 30, 40 }, -- Ashenvale, Thousand Needles, Desolace
  [1445] = { 35, 45 }, [1444] = { 40, 50 }, [1446] = { 40, 50 }, -- Dustwallow Marsh, Feralas, Tanaris
  [1447] = { 45, 55 }, [1448] = { 48, 55 }, [1449] = { 48, 55 }, -- Azshara, Felwood, Un'Goro Crater
  [1451] = { 55, 60 }, [1452] = { 55, 60 }, -- Silithus, Winterspring
  -- Eastern Kingdoms
  [1429] = { 1, 10 }, [1426] = { 1, 10 }, [1420] = { 1, 10 }, -- Elwynn Forest, Dun Morogh, Tirisfal Glades
  [1436] = { 10, 20 }, [1432] = { 10, 20 }, [1421] = { 10, 20 }, -- Westfall, Loch Modan, Silverpine Forest
  [1433] = { 15, 25 }, [1431] = { 18, 30 }, [1437] = { 20, 30 }, -- Redridge Mountains, Duskwood, Wetlands
  [1424] = { 20, 30 }, [1416] = { 30, 40 }, [1417] = { 30, 40 }, -- Hillsbrad Foothills, Alterac Mountains, Arathi Highlands
  [1434] = { 30, 45 }, [1418] = { 35, 45 }, [1435] = { 35, 45 }, -- Stranglethorn Vale, Badlands, Swamp of Sorrows
  [1425] = { 40, 50 }, [1427] = { 43, 50 }, [1419] = { 45, 55 }, -- The Hinterlands, Searing Gorge, Blasted Lands
  [1428] = { 50, 58 }, [1422] = { 51, 58 }, [1423] = { 53, 60 }, -- Burning Steppes, Western / Eastern Plaguelands
  [1430] = { 55, 60 }, -- Deadwind Pass
  -- WoW Forever
  [2521] = { 1, 12 }, [2665] = { 1, 12 }, -- Zephras Isle (two map IDs in the client)
  [2548] = { 35, 45 }, -- Riverglades
  [2482] = { 60, 60 }, -- Mount Hyjal
}
