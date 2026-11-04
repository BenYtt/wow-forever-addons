
	----------------------------------------------------------------------
	-- Leatrix Maps Icons
	----------------------------------------------------------------------

	local void, Leatrix_Maps = ...
	local L = Leatrix_Maps.L

	-- LeaMapsLC.NewPatch
	local LeaMapsLC = {}
	local gameversion, gamebuild, gamedate, gametocversion = GetBuildInfo()
	if gametocversion and gametocversion > 16002 then -- 1.60.2
		LeaMapsLC.NewPatch = true
	end

	-- Dungeons
	local dnTex, rdTex = "Dungeon", "Raid"

	-- Flight points
	local tATex, tHTex, tNTex = "TaxiNode_Alliance", "TaxiNode_Horde", "TaxiNode_Neutral"

	-- Boat harbors, zeppelin towers and tram stations (these are just templates, they will be replaced)
	local fATex, fHTex, fNTex = "Vehicle-TempleofKotmogu-CyanBall", "Vehicle-TempleofKotmogu-CyanBall", "Vehicle-TempleofKotmogu-CyanBall"

	-- Spirit healers
	local spTex = "Vehicle-TempleofKotmogu-GreenBall"

	-- Zone crossings
	local arTex = "Garr_LevelUpgradeArrow"

	Leatrix_Maps["Icons"] = {

		----------------------------------------------------------------------
		--	World Of Warcraft: Eastern Kingdoms
		----------------------------------------------------------------------

		--[[Alterac Mountains]] [1416] = {
			{"TravelA", 12.8, 51.2, L["Boat to"] .. " " .. L["Zephras Isle"], nil, fATex, nil, nil, nil, nil, nil, 0, 2665},
			{"Arrow", 80.7, 34.2, L["Western Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 0, 1422},
			{"Arrow", 51.8, 68.8, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 3, 1424},
			{"Arrow", 81.7, 77.5, L["Hillsbrad Foothills"], L["Ravenholdt Manor"], arTex, nil, nil, nil, nil, nil, 2.2, 1424},
			{"PortalA", 12.0, 56.2, L["Portal to"] .. " " .. L["Stormwind"], nil, fATex, nil, nil, nil, nil, nil, 0, 1453},
			{"Dungeon", 8.5, 59.3, L["City of Dalaran"], L["Dungeon"], dnTex, 28, 33},
		},
		--[[Arathi Highlands]] [1417] = {
			{"FlightA", 45.8, 46.1, L["Refuge Pointe"] .. ", " .. L["Arathi"], nil, tATex, nil, nil},
			{"FlightH", 73.1, 32.6, L["Hammerfall"] .. ", " .. L["Arathi"], nil, tHTex, nil, nil},
			{"Spirit", 48.7, 55.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 45.4, 88.9, L["Wetlands"], L["Thandol Span"], arTex, nil, nil, nil, nil, nil, 3.2, 1437},
			{"Arrow", 20.9, 30.6, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 1, 1424},
			{"Arrow", 29.6, 67.5, L["Faldir's Cove"], L["Just follow the path west"], arTex, nil, nil, nil, nil, nil, 1.9, 1417},
		},
		--[[Badlands]] [1418] = {
			{"Dungeon", 44.6, 12.1, L["Uldaman"], L["Dungeon"], dnTex, 41, 51},
			{"FlightH", 4.1, 44.9, L["Kargath"] .. ", " .. L["Badlands"], nil, tHTex, nil, nil},
			{"Spirit", 8.2, 55.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.9, 24.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 51.1, 14.8, L["Loch Modan"], nil, arTex, nil, nil, nil, nil, nil, 0.8, 1432},
			{"Arrow", 5.3, 61.1, L["Searing Gorge"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1427},
		},
		--[[Blasted Lands]] [1419] = {
			{"FlightA", 65.5, 24.4, L["Nethergarde Keep"] .. ", " .. L["Blasted Lands"], nil, tATex, nil, nil},
			{"Spirit", 51.0, 12.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 52.2, 10.7, L["Swamp of Sorrows"], nil, arTex, nil, nil, nil, nil, nil, 0, 1435},
		},
		--[[Tirisfal Glades]] [1420] = {
			{"Dungeon", 82.6, 33.8, L["Scarlet Monastery"], L["Dungeon"], dnTex, 34, 45},
			{"TravelH", 61.9, 58.9, L["Zeppelin to"] .. " " .. L["Grom'gol"] .. ", " .. L["Stranglethorn"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1434},
			{"TravelH", 60.6, 58.9, L["Zeppelin to"] .. " " .. L["Orgrimmar"] .. ", " .. L["Durotar"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1411},
			{"Spirit", 31.2, 64.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.2, 49.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 79.0, 40.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 82.0, 69.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 83.4, 70.6, L["Western Plaguelands"], L["The Bulwark"], arTex, nil, nil, nil, nil, nil, 4.7, 1422},
			{"Arrow", 61.9, 65.0, L["Undercity"], nil, arTex, nil, nil, nil, nil, nil, 3, 1458},
			{"Arrow", 54.9, 72.7, L["Silverpine Forest"], nil, arTex, nil, nil, nil, nil, nil, 3, 1421},
		},
		--[[Silverpine Forest]] [1421] = {
			{"Dungeon", 44.8, 67.8, L["Shadowfang Keep"], L["Dungeon"], dnTex, 22, 30},
			{"FlightH", 45.6, 42.4, L["The Sepulcher"] .. ", " .. L["Silverpine Forest"], nil, tHTex, nil, nil},
			{"Spirit", 44.2, 41.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 66.3, 79.8, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 4.3, 1424},
			{"Arrow", 67.7, 5.0, L["Tirisfal Glades"], nil, arTex, nil, nil, nil, nil, nil, 5.7, 1420},
		},
		--[[Western Plaguelands]] [1422] = {
			{"Dungeon", 69.7, 73.2, L["Scholomance"], L["Dungeon"], dnTex, 58, 60},
			{"FlightA", 42.9, 85.0, L["Chillwind Camp"] .. ", " .. L["Western Plaguelands"], nil, tATex, nil, nil},
			{"Spirit", 45.5, 85.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 65.5, 74.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 44.1, 87.1, L["Alterac Mountains"], nil, arTex, nil, nil, nil, nil, nil, 3, 1416},
			{"Arrow", 28.6, 57.5, L["Tirisfal Glades"], L["The Bulwark"], arTex, nil, nil, nil, nil, nil, 1.6, 1420},
			{"Arrow", 69.7, 50.3, L["Eastern Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1423},
			{"Arrow", 65.3, 86.4, L["The Hinterlands"], nil, arTex, nil, nil, nil, nil, nil, 3, 1425},
		},
		--[[Eastern Plaguelands]] [1423] = {
			{"Dungeon", 27.8, 11.6, L["Stratholme (Main Gate)"], L["Dungeon"], dnTex, 58, 60}, {"Dungeon", 43.6, 19.5, L["Stratholme (Service Gate)"], L["Dungeon"], dnTex, 58, 60}, {"Raid", 33.7, 20.7, L["Naxxramas"], L["Raid"], rdTex, 60, 60},
			{"FlightA", 71.7, 49.6, L["Light's Hope Chapel"] .. ", " .. L["Eastern Plaguelands"], nil, tATex, nil, nil},
			{"FlightH", 70.4, 47.6, L["Light's Hope Chapel"] .. ", " .. L["Eastern Plaguelands"], nil, tHTex, nil, nil},
			-- {"Spirit", 39.0, 92.5, L["Spirit Healer"], nil, spTex},
			-- {"Spirit", 96.5, 91.5, L["Spirit Healer"], nil, spTex},
			{"Spirit", 38.2, 70.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 39.0, 92.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.2, 44.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.0, 64.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 96.5, 91.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 11.8, 61.5, L["Western Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1422},
		},
		--[[Hillsbrad Foothills]] [1424] = {
			{"FlightA", 49.4, 52.1, L["Southshore"] .. ", " .. L["Hillsbrad"], nil, tATex, nil, nil},
			{"FlightH", 60.2, 18.8, L["Tarren Mill"] .. ", " .. L["Hillsbrad"], nil, tHTex, nil, nil},
			{"Spirit", 51.6, 52.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 63.5, 19.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 84.6, 31.8, L["The Hinterlands"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1425},
			{"Arrow", 54.8, 11.3, L["Alterac Mountains"], nil, arTex, nil, nil, nil, nil, nil, 0, 1416},
			{"Arrow", 13.7, 46.2, L["Silverpine Forest"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1421},
			{"Arrow", 81.0, 56.1, L["Arathi Highlands"], nil, arTex, nil, nil, nil, nil, nil, 4.1, 1417},
			{"Arrow", 75.5, 24.6, L["Alterac Mountains"], L["Ravenholdt Manor"], arTex, nil, nil, nil, nil, nil, 0.0, 1416},
			{"TravelA", 50.7, 70.4, L["Boat to"] .. " " .. L["Auberdine"] .. ", " .. L["Darkshore"] .. " " .. L["and onto"] .. " " .. L["Menethil Harbor"] .. ", " .. L["Wetlands"], nil, fATex, nil, nil, nil, nil, nil, 0, 1439},
		},
		--[[The Hinterlands]] [1425] = {
			{"FlightA", 11.1, 46.1, L["Aerie Peak"] .. ", " .. L["The Hinterlands"], nil, tATex, nil, nil},
			{"FlightH", 81.7, 81.9, L["Revantusk Village"] .. ", " .. L["The Hinterlands"], nil, tHTex, nil, nil},
			{"Spirit", 16.8, 44.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 60.5, 38.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 62.0, 26.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 72.6, 68.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 24.1, 30.4, L["Western Plaguelands"], nil, arTex, nil, nil, nil, nil, nil, 0, 1422},
			{"Arrow", 6.4, 61.5, L["Hillsbrad Foothills"], nil, arTex, nil, nil, nil, nil, nil, 2.3, 1424},
			{"Arrow", 70.6, 63.7, L["The Overlook Cliffs"], L["Follow the westward path"], arTex, nil, nil, nil, nil, nil, 4.1, 1425},
			{"Arrow", 76.9, 61.0, L["The Hinterlands"], L["Follow the eastward path"], arTex, nil, nil, nil, nil, nil, 1.8, 1425},
		},
		--[[Dun Morogh]] [1426] = {
			{"Dungeon", 24.3, 39.8, L["Gnomeregan"], L["Dungeon"], dnTex, 29, 38},
			{"Spirit", 29.5, 69.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.0, 55.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.2, 39.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 84.3, 31.1, L["Loch Modan"], L["North Gate Pass"], arTex, nil, nil, nil, nil, nil, 0, 1432},
			{"Arrow", 82.2, 53.5, L["Loch Modan"], L["South Gate Pass"], arTex, nil, nil, nil, nil, nil, 5, 1432},
			{"Arrow", 30.5, 34.5, L["Wetlands"], L["You will die!"], arTex, nil, nil, nil, nil, nil, 6.2, 1437},
			{"Arrow", 53.3, 35.1, L["Ironforge"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1455},
		},
		--[[Searing Gorge]] [1427] = {
			{"Dunraid", 34.8, 85.3, L["Blackrock Mountain"], L["Blackrock Depths"] .. ", " .. L["Lower Blackrock Spire"] .. ", " .. L["Upper Blackrock Spire"] .. ", |n" .. L["Molten Core"] .. ", " .. L["Blackwing Lair"], dnTex, 52, 60},
			{"FlightA", 37.9, 30.4, L["Thorium Point"] .. ", " .. L["Searing Gorge"], nil, tATex, nil, nil},
			{"FlightH", 34.8, 30.6, L["Thorium Point"] .. ", " .. L["Searing Gorge"], nil, tHTex, nil, nil},
			{"Spirit", 35.5, 22.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 78.5, 17.4, L["Loch Modan"], L["Requires Key to Searing Gorge"], arTex, nil, nil, nil, nil, nil, 5.4, 1432},
			{"Arrow", 33.6, 79.0, L["Burning Steppes"], L["Blackrock Mountain"], arTex, nil, nil, nil, nil, nil, 3, 1428},
			{"Arrow", 68.8, 53.9, L["Badlands"], nil, arTex, nil, nil, nil, nil, nil, 4.5, 1418},
		},
		--[[Burning Steppes]] [1428] = {
			{"Dunraid", 29.4, 38.3, L["Blackrock Mountain"], L["Blackrock Depths"] .. ", " .. L["Lower Blackrock Spire"] .. ", " .. L["Upper Blackrock Spire"] .. ", |n" .. L["Molten Core"] .. ", " .. L["Blackwing Lair"], dnTex, 52, 60},
			{"FlightA", 84.4, 68.3, L["Morgan's Vigil"] .. ", " .. L["Burning Steppes"], nil, tATex, nil, nil},
			{"FlightH", 65.6, 24.2, L["Flame Crest"] .. ", " .. L["Burning Steppes"], nil, tHTex, nil, nil},
			{"Spirit", 63.2, 23.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 78.3, 77.8, L["Redridge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1433},
			{"Arrow", 31.9, 50.4, L["Searing Gorge"], L["Blackrock Mountain"], arTex, nil, nil, nil, nil, nil, 0.8, 1427},
		},
		--[[Elwynn Forest]] [1429] = {
			{"Spirit", 39.5, 60.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 49.5, 43.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 83.5, 69.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 21.0, 79.6, L["Westfall"], nil, arTex, nil, nil, nil, nil, nil, 2.2, 1436},
			{"Arrow", 93.2, 72.3, L["Redridge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1433},
			{"Arrow", 32.2, 49.7, L["Stormwind City"], nil, arTex, nil, nil, nil, nil, nil, 0.6, 1453},
		},
		--[[Deadwind Pass]] [1430] = {
			{"Spirit", 40.0, 75.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 32.0, 35.3, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1431},
			{"Arrow", 58.8, 42.2, L["Swamp of Sorrows"], nil, arTex, nil, nil, nil, nil, nil, 5.2, 1435},
		},
		--[[Duskwood]] [1431] = {
			{"FlightA", 77.6, 44.4, L["Darkshire"] .. ", " .. L["Duskwood"], nil, tATex, nil, nil},
			{"Spirit", 20.0, 49.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 44.8, 67.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.8, 45.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 75.0, 59.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 7.9, 63.8, L["Westfall"], nil, arTex, nil, nil, nil, nil, nil, 1.7, 1436},
			{"Arrow", 44.6, 87.9, L["Stranglethorn Vale"], nil, arTex, nil, nil, nil, nil, nil, 3, 1434},
			{"Arrow", 94.2, 10.3, L["Redridge Mountains"], nil, arTex, nil, nil, nil, nil, nil, 5.8, 1433},
			{"Arrow", 88.4, 40.9, L["Deadwind Pass"], nil, arTex, nil, nil, nil, nil, nil, 4.6, 1430},
		},
		--[[Loch Modan]] [1432] = {
			{"FlightA", 33.9, 50.8, L["Thelsamar"] .. ", " .. L["Loch Modan"], nil, tATex, nil, nil},
			{"Spirit", 32.5, 46.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 18.4, 83.0, L["Searing Gorge"], L["Requires Key to Searing Gorge"], arTex, nil, nil, nil, nil, nil, 2.6, 1427},
			{"Arrow", 20.4, 17.4, L["Dun Morogh"], L["North Gate Pass"], arTex, nil, nil, nil, nil, nil, 1.1, 1426},
			{"Arrow", 46.8, 76.9, L["Badlands"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1418},
			{"Arrow", 21.5, 66.2, L["Dun Morogh"], L["South Gate Pass"], arTex, nil, nil, nil, nil, nil, 0.5, 1426},
			{"Arrow", 25.4, 10.9, L["Wetlands"], L["Dun Algaz"], arTex, nil, nil, nil, nil, nil, 0.1, 1437},
		},
		--[[Redridge Mountains]] [1433] = {
			{"FlightA", 25.3, 59.0, L["Lakeshire"] .. ", " .. L["Redridge"], nil, tATex, nil, nil},
			--{"Arrow", 8.5, 88.1, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 2.2, 1431},
			--{"Arrow", 3.3, 73.1, L["Elwynn Forest"], nil, arTex, nil, nil, nil, nil, nil, 2.1, 1429},
			--{"Arrow", 47.3, 14.3, L["Burning Steppes"], nil, arTex, nil, nil, nil, nil, nil, 5.9, 1428},
			{"Spirit", 20.8, 56.5, L["Spirit Healer"], nil, spTex, nil, nil},
		},
		--[[Stranglethorn Vale]] [1434] = {
			{"Raid", 53.9, 17.6, L["Zul'Gurub"], L["Raid"], rdTex, 60, 60},
			{"FlightA", 27.5, 77.7, L["Booty Bay"] .. ", " .. L["Stranglethorn"], nil, tATex, nil, nil},
			{"FlightH", 26.8, 77.0, L["Booty Bay"] .. ", " .. L["Stranglethorn"], nil, tHTex, nil, nil},
			{"FlightH", 32.5, 29.3, L["Grom'gol"] .. ", " .. L["Stranglethorn"], nil, tHTex, nil, nil},
			{"TravelH", 31.2, 30.4, L["Zeppelin to"] .. " " .. L["Orgrimmar"] .. ", " .. L["Durotar"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1411},
			{"TravelH", 31.5, 29.1, L["Zeppelin to"] .. " " .. L["Undercity"] .. ", " .. L["Tirisfal"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1420},
			{"TravelN", 25.7, 73.1, L["Boat to"] .. " " .. L["Ratchet"] .. ", " .. L["The Barrens"], nil, fNTex, nil, nil, nil, nil, nil, 0, 1413},
			{"Spirit", 30.0, 73.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 38.4, 8.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 39.2, 6.5, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 0, 1431},
			{"Dungeon", 21.3, 27.8, L["The Drowned City"], L["Dungeon"], dnTex, 35, 40},

		},
		--[[Swamp of Sorrows]] [1435] = {
			{"Dungeon", 69.9, 53.6, L["Temple of Atal'Hakkar"], L["Dungeon"], dnTex, 50, 60},
			{"FlightH", 46.1, 54.7, L["Stonard"] .. ", " .. L["Swamp of Sorrows"], nil, tHTex, nil, nil},
			{"Spirit", 50.2, 62.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 3.7, 61.1, L["Deadwind Pass"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1430},
			{"Arrow", 33.4, 74.8, L["Blasted Lands"], nil, arTex, nil, nil, nil, nil, nil, 3.1, 1419},
		},
		--[[Westfall]] [1436] = {
			{"Dungeon", 42.5, 71.7, L["The Deadmines"], L["Dungeon"], dnTex, 17, 26},
			{"FlightA", 56.6, 52.7, L["Sentinel Hill"] .. ", " .. L["Westfall"], nil, tATex, nil, nil},
			{"Spirit", 51.6, 49.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 62.0, 17.9, L["Elwynn Forest"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1429},
			{"Arrow", 67.9, 62.8, L["Duskwood"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1431},
		},
		--[[Wetlands]] [1437] = {
			{"FlightA", 9.5, 59.7, L["Menethil Harbor"] .. ", " .. L["Wetlands"], nil, tATex, nil, nil},
			{"TravelA", 4.5, 56.7, L["Boat to"] .. " " .. L["Southshore"] .. ", " .. L["Hillsbrad"] .. " " .. L["and onto"] .. " " .. L["Auberdine"] .. ", " .. L["Darkshore"], nil, fATex, nil, nil, nil, nil, nil, 0, 1424},
			{"TravelA", 4.7, 63.8, L["Boat to"] .. " " .. L["Theramore"] .. ", " .. L["Dustwallow Marsh"], nil, fATex, nil, nil, nil, nil, nil, 0, 1445},
			{"Spirit", 11.5, 43.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 49.5, 41.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 51.3, 10.3, L["Arathi Highlands"], L["Thandol Span"], arTex, nil, nil, nil, nil, nil, 0, 1417},
			{"Arrow", 56.0, 70.3, L["Loch Modan"], L["Dun Algaz"], arTex, nil, nil, nil, nil, nil, 1.8, 1432},
			{"Dungeon", 47.8, 56.2, L["Excavation Site: Wetlands"], L["Dungeon"], dnTex, 24, 29},
		},
		--[[Stormwind City]] [1453] = {
			{"Dungeon", 52.4, 70.0, L["The Stockade"], L["Dungeon"], dnTex, 22, 30},
			{"FlightA", 71.6, 72.3, L["Stormwind"] .. ", " .. L["Elwynn"], nil, tATex, nil, nil},
			{"TravelA", 66.6, 34.7, L["Tram to"] .. " " .. L["Tinker Town"] .. ", " .. L["Ironforge"], nil, fATex, nil, nil, nil, nil, nil, 0, 1455},
			{"Arrow", 74.5, 92.3, L["Elwynn Forest"], nil, arTex, nil, nil, nil, nil, nil, 3.8, 1429},
			{"PortalA", 50.0, 86.9, L["Portal to"] .. " " .. L["Dalaran"] .. ", " .. L["Alterac Mountains"], nil, fATex, nil, nil, nil, nil, nil, 0, 1416},
			{"TravelA", 21.8, 56.9, L["Boat to"] .. " " .. L["Auberdine"] .. ", " .. L["Darkshore"], nil, fATex, nil, nil, nil, nil, nil, 0, 1439},
		},
		--[[Ironforge]] [1455] = {
			{"FlightA", 55.9, 47.9, L["Ironforge"] .. ", " .. L["Dun Morogh"], nil, tATex, nil, nil},
			{"TravelA", 73.0, 50.2, L["Tram to"] .. " " .. L["Dwarven District"] .. ", " .. L["Stormwind"], nil, fATex, nil, nil, nil, nil, nil, 0, 1453},
			{"Arrow", 21.9, 77.5, L["Dun Morogh"], nil, arTex, nil, nil, nil, nil, nil, 2.2, 1426},
			{"Dungeon", 27.7, 47.9, L["The Hall of Thanes"], L["Dungeon"], dnTex, 13, 18},
		},
		--[[Undercity]] [1458] = {
			{"FlightH", 63.1, 48.3, L["Undercity"] .. ", " .. L["Tirisfal"], nil, tHTex, nil, nil},
			{"Spirit", 67.7, 14.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 66.2, 5.2, L["Tirisfal Glades"], nil, arTex, nil, nil, nil, nil, nil, 0, 1420},
			{"Dungeon", 72.5, 11.4, L["The Ruins of Lordaeron"], L["Dungeon"], dnTex, 15, 20},

		},
		--[[Riverglades]] [2548] = {
			{"FlightA", 60.6, 81.6, L["Farholde Keep"] .. ", " .. L["Riverglades"], nil, tATex, nil, nil},
			{"FlightH", 59.6, 45.1, L["Rog'mar"] .. ", " .. L["Riverglades"], nil, tHTex, nil, nil},
			{"TravelH", 80.6, 54.6, L["Boat to"] .. " " .. L["Tanaris"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1446},
		},

		----------------------------------------------------------------------
		--	World Of Warcraft: Kalimdor
		----------------------------------------------------------------------

		--[[Durotar]] [1411] = {
			{"TravelH", 50.5, 12.7, L["Zeppelin to"] .. " " .. L["Grom'gol"] .. ", " .. L["Stranglethorn"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1434},
			{"TravelH", 51.0, 13.9, L["Zeppelin to"] .. " " .. L["Undercity"] .. ", " .. L["Tirisfal"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1420},
			{"Spirit", 44.2, 69.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.0, 17.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 53.5, 44.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 57.5, 73.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 35.1, 42.4, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1413},
			{"Arrow", 45.5, 12.3, L["Orgrimmar"], nil, arTex, nil, nil, nil, nil, nil, 0, 1454},
		},
		--[[Mulgore]] [1412] = {
			{"Spirit", 42.6, 78.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 46.5, 55.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 64.9, 64.0, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 4.8, 1413},
			{"Arrow", 38.4, 40.8, L["Thunder Bluff"], L["South"], arTex, nil, nil, nil, nil, nil, 0.7, 1456},
			{"Arrow", 39.5, 29.4, L["Thunder Bluff"], L["North"], arTex, nil, nil, nil, nil, nil, 3.7, 1456},
			{"Arrow", 42.3, 29.8, L["Thunder Bluff"], L["North"], arTex, nil, nil, nil, nil, nil, 2.8, 1456},
			{"Arrow", 35.5, 36.0, L["Thunder Bluff"], L["South"], arTex, nil, nil, nil, nil, nil, 4.3, 1456},
			{"TravelH", 34.3, 26.1, L["Zeppelin to"] .. " " .. L["Zephras Isle"], nil, fHTex, nil, nil, nil, nil, nil, 0, 2665},
		},
		--[[The Barrens]] [1413] = {
			{"Dungeon", 46.0, 36.4, L["Wailing Caverns"], L["Dungeon"], dnTex, 17, 24}, {"Dungeon", 42.9, 90.2, L["Razorfen Kraul"], L["Dungeon"], dnTex, 29, 38}, {"Dungeon", 49.0, 93.9, L["Razorfen Downs"], L["Dungeon"], dnTex, 37, 46},
			{"FlightH", 44.5, 59.1, L["Camp Taurajo"] .. ", " .. L["The Barrens"], nil, tHTex, nil, nil},
			{"FlightH", 51.5, 30.4, L["Crossroads"] .. ", " .. L["The Barrens"], nil, tHTex, nil, nil},
			{"FlightN", 63.1, 37.1, L["Ratchet"] .. ", " .. L["The Barrens"], nil, tNTex, nil, nil},
			{"TravelN", 63.8, 38.8, L["Boat to"] .. " " .. L["Booty Bay"] .. ", " .. L["Stranglethorn"], nil, fNTex, nil, nil, nil, nil, nil, 0, 1434},
			{"Spirit", 45.2, 61.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 50.7, 32.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 60.2, 39.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 41.2, 58.6, L["Mulgore"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1412},
			{"Arrow", 49.8, 78.4, L["Dustwallow Marsh"], nil, arTex, nil, nil, nil, nil, nil, 4.7, 1445},
			{"Arrow", 44.1, 91.5, L["Thousand Needles"], L["The Great Lift"], arTex, nil, nil, nil, nil, nil, 3, 1441},
			{"Arrow", 36.3, 27.5, L["Stonetalon Mountains"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1442},
			{"Arrow", 48.8, 7.1, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 0, 1440},
			{"Arrow", 62.6, 19.2, L["Durotar"], nil, arTex, nil, nil, nil, nil, nil, 4.6, 1411},
		},
		--[[Teldrassil]] [1438] = {
			{"FlightA", 58.4, 93.9, L["Rut'theran Village"] .. ", " .. L["Teldrassil"], nil, tATex, nil, nil},
			{"TravelA", 54.8, 97.2, L["Boat to"] .. " " .. L["Auberdine"] .. ", " .. L["Darkshore"], nil, fATex, nil, nil, nil, nil, nil, 0, 1439},
			{"Spirit", 56.2, 63.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 58.7, 42.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 55.9, 89.7, L["Darnassus"], "", arTex, nil, nil, nil, nil, nil, 0.3, 1457},
			{"Arrow", 36.2, 54.4, L["Darnassus"], nil, arTex, nil, nil, nil, nil, nil, 1.5, 1457},
		},
		--[[Darkshore]] [1439] = {
			{"FlightA", 36.4, 45.6, L["Auberdine"] .. ", " .. L["Darkshore"], nil, tATex, nil, nil},
			{"Spirit", 41.8, 36.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 43.5, 92.3, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 43.3, 94.0, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 4, 1440},
			{"Arrow", 37.5, 94.8, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 3.1, 1440},
			{"Arrow", 27.7, 92.9, L["Ashenvale"], L["The Zoram Strand"], arTex, nil, nil, nil, nil, nil, 2.5, 1440},
			{"TravelA", 32.3, 44.1, L["Boat to"] .. " " .. L["Menethil Harbor"] .. ", " .. L["Wetlands"] .. " " .. L["and onto"] .. " " .. L["Southshore"] .. ", " .. L["Hillsbrad"], nil, fATex, nil, nil, nil, nil, nil, 0, 1437},
			{"TravelA", 33.3, 39.8, L["Boat to"] .. " " .. L["Rut'theran Village"] .. ", " .. L["Teldrassil"], nil, fATex, nil, nil, nil, nil, nil, 0, 1438},
			{"TravelA", 30.5, 40.9, L["Boat to"] .. " " .. L["Stormwind City"], nil, fATex, nil, nil, nil, nil, nil, 0, 1453},
		},
		--[[Ashenvale]] [1440] = {
			{"Dungeon", 14.5, 14.2, L["Blackfathom Deeps"], L["Dungeon"], dnTex, 24, 32},
			{"FlightA", 34.5, 48.0, L["Astranaar"] .. ", " .. L["Ashenvale"], nil, tATex, nil, nil},
			{"FlightH", 73.3, 61.7, L["Splintertree Post"] .. ", " .. L["Ashenvale"], nil, tHTex, nil, nil},
			{"FlightH", 12.2, 33.8, L["Zoram'gar Outpost"] .. ", " .. L["Ashenvale"], nil, tHTex, nil, nil},
			{"Spirit", 17.8, 11.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 22.2, 28.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 40.2, 53.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 51.5, 63.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.6, 58.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 84.2, 56.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 93.2, 42.2, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 29.1, 14.8, L["Darkshore"], nil, arTex, nil, nil, nil, nil, nil, 0, 1439},
			{"Arrow", 42.3, 71.1, L["Stonetalon Mountains"], L["The Talondeep Path"], arTex, nil, nil, nil, nil, nil, 2.7, 1442},
			{"Arrow", 55.8, 30.2, L["Felwood"], nil, arTex, nil, nil, nil, nil, nil, 0, 1448},
			{"Arrow", 94.2, 47.3, L["Azshara"], nil, arTex, nil, nil, nil, nil, nil, 4.4, 1447},
			{"Arrow", 68.6, 86.8, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1413},
			{"Arrow", 20.6, 16.1, L["Darkshore"], nil, arTex, nil, nil, nil, nil, nil, 6.1, 1439},
			{"Arrow", 9.5, 10.7, L["Darkshore"], L["Twilight Shore"], arTex, nil, nil, nil, nil, nil, 5.3, 1439},
		},
		--[[Thousand Needles]] [1441] = {
			{"FlightH", 45.0, 49.1, L["Freewind Post"] .. ", " .. L["Thousand Needles"], nil, tHTex, nil, nil},
			{"Spirit", 30.5, 23.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 69.1, 53.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 74.9, 93.3, L["Tanaris"], nil, arTex, nil, nil, nil, nil, nil, 3.2, 1446},
			{"Arrow", 8.3, 11.9, L["Feralas"], nil, arTex, nil, nil, nil, nil, nil, 0.7, 1444},
			{"Arrow", 32.2, 23.9, L["The Barrens"], L["The Great Lift"], arTex, nil, nil, nil, nil, nil, 5.4, 1413},
		},
		--[[Stonetalon Mountains]] [1442] = {
			{"FlightA", 36.5, 7.2, L["Stonetalon Peak"] .. ", " .. L["Stonetalon Mountains"], nil, tATex, nil, nil},
			{"FlightH", 45.2, 59.9, L["Sun Rock Retreat"] .. ", " .. L["Stonetalon Mountains"], nil, tHTex, nil, nil},
			{"Spirit", 57.5, 62.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 80.2, 92.4, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 3.4, 1413},
			{"Arrow", 30.4, 75.4, L["Desolace"], nil, arTex, nil, nil, nil, nil, nil, 2.7, 1443},
			{"Arrow", 78.2, 42.8, L["Ashenvale"], L["The Talondeep Path"], arTex, nil, nil, nil, nil, nil, 6.1, 1440},
			{"Arrow", 37.9, 67.8, L["Sun Rock Retreat"], L["Mountain Pass (Horde Only)"], arTex, nil, nil, nil, nil, nil, 4.1, 1442},
		},
		--[[Desolace]] [1443] = {
			{"Dungeon", 29.1, 62.5, L["Maraudon"], L["Dungeon"], dnTex, 46, 55},
			{"FlightA", 64.7, 10.4, L["Nijel's Point"] .. ", " .. L["Desolace"], nil, tATex, nil, nil},
			{"FlightH", 21.6, 74.0, L["Shadowprey Village"] .. ", " .. L["Desolace"], nil, tHTex, nil, nil},
			{"Spirit", 50.2, 62.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 53.4, 5.9, L["Stonetalon Mountains"], nil, arTex, nil, nil, nil, nil, nil, 5.9, 1442},
			{"Arrow", 41.6, 94.4, L["Feralas"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1444},
		},
		--[[Feralas]] [1444] = {
			{"FlightA", 30.3, 43.3, L["Feathermoon"] .. ", " .. L["Feralas"], nil, tATex, nil, nil},
			{"FlightA", 89.5, 45.9, L["Thalanaar"] .. ", " .. L["Feralas"], nil, tATex, nil, nil},
			{"FlightH", 75.4, 44.3, L["Camp Mojache"] .. ", " .. L["Feralas"], nil, tHTex, nil, nil},
			{"Dungeon", 62.5, 24.9, L["Dire Maul (North)"], L["Dungeon"], dnTex, 56, 60},
			{"Dungeon", 60.3, 30.2, L["Dire Maul (West)"], L["Dungeon"], dnTex, 56, 60},
			{"Dungeon", 64.8, 30.2, L["Dire Maul (East)"], L["Dungeon"], dnTex, 56, 60},
			{"TravelA", 43.1, 42.8, L["Boat to"] .. " " .. L["Feathermoon"] .. ", " .. L["Feralas"], nil, fATex, nil, nil, nil, nil, nil, 0, 1444},
			{"TravelA", 31.0, 39.5, L["Boat to"] .. " " .. L["Feralas"], nil, fATex, nil, nil, nil, nil, nil, 0, 1444},
			{"Spirit", 31.5, 48.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 44.0, 7.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 50.4, 13.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.8, 47.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 73.0, 44.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 44.9, 7.7, L["Desolace"], nil, arTex, nil, nil, nil, nil, nil, 6, 1443},
			{"Arrow", 88.7, 41.1, L["Thousand Needles"], nil, arTex, nil, nil, nil, nil, nil, 4.5, 1441},
			-- {"Dungeon", 77.1, 36.9, L["Dire Maul (East)"], L["The Hidden Reach (requires Crescent Key)"], dnTex, 56, 60},
		},
		--[[Dustwallow Marsh]] [1445] = {
			{"Raid", 52.6, 76.8, L["Onyxia's Lair"], L["Raid"], rdTex, 60, 60},
			{"FlightA", 67.5, 51.2, L["Theramore"] .. ", " .. L["Dustwallow Marsh"], nil, tATex, nil, nil},
			{"FlightH", 35.6, 31.8, L["Brackenwall Village"] .. ", " .. L["Dustwallow Marsh"], nil, tHTex, nil, nil},
			{"TravelA", 71.7, 56.7, L["Boat to"] .. " " .. L["Menethil Harbor"] .. ", " .. L["Wetlands"], nil, fATex, nil, nil, nil, nil, nil, 0, 1437},
			{"Spirit", 39.6, 30.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 63.5, 43.0, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 30.0, 47.1, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 1.6, 1413},
		},
		--[[Tanaris]] [1446] = {
			{"Dungeon", 38.7, 20.0, L["Zul'Farrak"], L["Dungeon"], dnTex, 44, 54},
			{"FlightA", 51.0, 29.3, L["Gadgetzan"] .. ", " .. L["Tanaris"], nil, tATex, nil, nil},
			{"FlightH", 51.6, 25.5, L["Gadgetzan"] .. ", " .. L["Tanaris"], nil, tHTex, nil, nil},
			{"Spirit", 54.0, 28.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 50.6, 24.4, L["Thousand Needles"], nil, arTex, nil, nil, nil, nil, nil, 5.7, 1441},
			{"Arrow", 27.1, 57.7, L["Un'Goro Crater"], nil, arTex, nil, nil, nil, nil, nil, 0.5, 1449},
			{"TravelH", 68.6, 23.0, L["Boat to"] .. " " .. L["Riverglades"], nil, fHTex, nil, nil, nil, nil, nil, 0, 2548},
		},
		--[[Azshara]] [1447] = {
			{"FlightA", 11.9, 77.5, L["Talrendis Point"] .. ", " .. L["Azshara"], nil, tATex, nil, nil},
			{"FlightH", 22.0, 49.7, L["Valormok"] .. ", " .. L["Azshara"], nil, tHTex, nil, nil},
			{"Spirit", 14.5, 78.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 54.2, 71.4, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 70.4, 15.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 10.6, 75.3, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 0.9, 1440},
		},
		--[[Felwood]] [1448] = {
			{"FlightA", 62.5, 24.2, L["Talonbranch Glade"] .. ", " .. L["Felwood"], nil, tATex, nil, nil},
			{"FlightH", 34.4, 53.9, L["Bloodvenom Post"] .. ", " .. L["Felwood"], nil, tHTex, nil, nil},
			{"Spirit", 49.5, 30.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 56.2, 86.6, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 65.0, 8.3, L["Winterspring"], L["Timbermaw Hold"], arTex, nil, nil, nil, nil, nil, 5.9, 1452},
			{"Arrow", 54.5, 89.2, L["Ashenvale"], nil, arTex, nil, nil, nil, nil, nil, 3, 1440},
		},
		--[[Un'Goro Crater]] [1449] = {
			{"FlightN", 45.3, 6.0, L["Marshal's Refuge"] .. ", " .. L["Un'Goro Crater"], nil, tNTex, nil, nil},
			{"Spirit", 80.0, 49.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 70.5, 78.6, L["Tanaris"], nil, arTex, nil, nil, nil, nil, nil, 3.3, 1446},
			{"Arrow", 29.4, 22.3, L["Silithus"], nil, arTex, nil, nil, nil, nil, nil, 0.9, 1451},
		},
		--[[Moonglade]] [1450] =  {
			{"FlightA", 47.9, 67.1, L["Moonglade"], nil, tATex, nil, nil},
			{"FlightH", 32.2, 66.3, L["Moonglade"], nil, tHTex, nil, nil},
			{"Spirit", 62.0, 69.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 35.7, 72.4, L["Felwood"] .. ", " .. L["Winterspring"], L["Timbermaw Hold"], arTex, nil, nil, nil, nil, nil, 3, 1448},
		},
		--[[Silithus]] [1451] = {
			{"Raid", 28.6, 92.4, L["Ahn'Qiraj"], L["Ruins of Ahn'Qiraj"] .. ", " .. L["Temple of Ahn'Qiraj"], rdTex, 60, 60},
			{"FlightA", 50.7, 34.6, L["Cenarion Hold"] .. ", " .. L["Silithus"], nil, tATex, nil, nil},
			{"FlightH", 48.8, 36.7, L["Cenarion Hold"] .. ", " .. L["Silithus"], nil, tHTex, nil, nil},
			{"Spirit", 28.0, 87.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 47.0, 38.5, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Spirit", 80.6, 19.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 82.4, 16.0, L["Un'Goro Crater"], nil, arTex, nil, nil, nil, nil, nil, 5.4, 1449},
		},
		--[[Winterspring]] [1452] = {
			{"FlightA", 62.3, 36.6, L["Everlook"] .. ", " .. L["Winterspring"], nil, tATex, nil, nil},
			{"FlightH", 60.5, 36.3, L["Everlook"] .. ", " .. L["Winterspring"], nil, tHTex, nil, nil},
			{"Spirit", 61.2, 34.8, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 27.9, 34.5, L["Felwood"], L["Timbermaw Hold"], arTex, nil, nil, nil, nil, nil, 0.7, 1448},
		},
		--[[Orgrimmar]] [1454] =  {
			{"Dungeon", 52.6, 49.0, L["Ragefire Chasm"], L["Dungeon"], dnTex, 13, 18},
			{"FlightH", 45.3, 63.7, L["Orgrimmar"] .. ", " .. L["Durotar"], nil, tHTex, nil, nil},
			{"Arrow", 52.4, 83.7, L["Durotar"], nil, arTex, nil, nil, nil, nil, nil, 3, 1411},
			{"Arrow", 18.1, 60.6, L["The Barrens"], nil, arTex, nil, nil, nil, nil, nil, 2.1, 1413},
		},
		--[[Thunder Bluff]] [1456] = {
			{"FlightH", 46.7, 49.9, L["Thunder Bluff"] .. ", " .. L["Mulgore"], nil, tHTex, nil, nil},
			{"Spirit", 56.5, 17.9, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 35.7, 62.8, L["Mulgore"], L["South"], arTex, nil, nil, nil, nil, nil, 2.0, 1412},
			{"Arrow", 51.3, 31.3, L["Mulgore"], L["North"], arTex, nil, nil, nil, nil, nil, 5.7, 1412},
		},
		--[[Darnassus]] [1457] = {
			{"Spirit", 77.2, 26.7, L["Spirit Healer"], nil, spTex, nil, nil},
			{"Arrow", 30.3, 41.4, L["Teldrassil"], L["Rut'theran Village"], arTex, nil, nil, nil, nil, nil, 1.5, 1438},
			{"Arrow", 86.9, 35.8, L["Teldrassil"], nil, arTex, nil, nil, nil, nil, nil, 4.8, 1438},
		},
		--[[Shen'dralas]] [2652] = {
		},
		--[[Mount Hyjal]] [2482] = {
			{"FlightN", 68.6, 44.1, L["Summit of Eternity"] .. ", " .. L["Mount Hyjal"], nil, tNTex, nil, nil},
			{"FlightN", 55.1, 82.5, L["Tainted Foothills"] .. ", " .. L["Mount Hyjal"], nil, tNTex, nil, nil},
		},

		----------------------------------------------------------------------
		--	World Of Warcraft: Forever
		----------------------------------------------------------------------

		--[[Zephras Isle]] [2521] = {
			{"TravelA", 65.8, 83.8, L["Boat to"] .. " " .. L["Alterac Mountains"], nil, fATex, nil, nil, nil, nil, nil, 0, 1416},
			{"TravelH", 57.7, 81.0, L["Zeppelin to"] .. " " .. L["Thunder Bluff"] .. ", " .. L["Mulgore"], nil, fHTex, nil, nil, nil, nil, nil, 0, 1412},
		},

	}

	-- More Forever
	-- Blackmaw Hold (North Azshara, 55-60)
	-- Krol'dok Stronghold (Riverglades, 40-45)
	-- Alcaz Prison (Alcaz Island, Dustwallow Marsh, 48-53)
	-- The Shapers Terrace (Un'goro, 58-60)
