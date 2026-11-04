local _, FLT = ...

-- Hunter pet reference for WoW Forever.
-- Families, abilities, ranks and teaching beasts follow wow-petopia.com/forever
-- (recommended for more detail); spawn positions from QuestieDB (Forever data).
-- Forever changed the pet system compared with Classic: new family abilities
-- (e.g. Dismember, Savage Rend, Web), new trainer passives (Faster/Slower
-- Attack), Owls became Birds of Prey, and Core Hounds/Foxes were added.

FLT.PET_FAMILIES = {
  {name="Bat", icon="ability_hunter_pet_bat", role="Offense", diet={"Fruit", "Fungus"}, abilities={"Bite", "Cower", "Dive"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.00", damage="1.07"},
    note="Role: Offense.",
    tames={
      {name="Greater Duskbat", level="6-7", zone="Tirisfal Glades", npcID=1553, mapID=1420, x=51.4, y=49.5},
      {name="Kraul Bat", level="30-31", zone="Razorfen Kraul", npcID=4538},
      {name="Shrike Bat", level="38-39", zone="Uldaman", npcID=4861},
      {name="Plaguebat", level="53-55", zone="Eastern Plaguelands", npcID=8600, mapID=1423, x=30.0, y=64.2},
    }},
  {name="Bear", icon="ability_hunter_pet_bear", role="Defense", diet={"Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat"}, abilities={"Bite", "Claw", "Cower", "Dash", "Swipe"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.08", armor="1.05", damage="0.91"},
    note="Role: Defense. Only family with Swipe.",
    tames={
      {name="Ice Claw Bear", level="7-8", zone="Dun Morogh", npcID=1196, mapID=1426, x=38.5, y=43.5},
      {name="Young Forest Bear", level="8-9", zone="Elwynn Forest", npcID=822, mapID=1429, x=63.3, y=77.0},
      {name="Thistle Bear", level="11-12", zone="Darkshore", npcID=2163, mapID=1439, x=43.4, y=34.7},
      {name="Ironfur Bear", level="41-42", zone="Feralas", npcID=5268, mapID=1444, x=78.0, y=45.4},
    }},
  {name="Bird of Prey", icon="ability_hunter_pet_owl", role="Offense", diet={"Meat"}, abilities={"Claw", "Cower", "Dive", "Mine!"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.00", damage="1.07"},
    note="Role: Offense. Only family with Mine!.",
    tames={
      {name="Strigid Owl", level="5-6", zone="Teldrassil", npcID=1995, mapID=1438, x=58.7, y=56.2},
      {name="Strigid Hunter", level="8-9", zone="Teldrassil", npcID=1997, mapID=1438, x=38.1, y=39.5},
      {name="Ironbeak Owl", level="48-49", zone="Felwood", npcID=7097, mapID=1448, x=49.0, y=81.5},
      {name="Winterspring Owl", level="54-56", zone="Winterspring", npcID=7455, mapID=1452, x=59.2, y=35.5},
    }},
  {name="Boar", icon="ability_hunter_pet_boar", role="Defense", diet={"Bread", "Cheese", "Fish", "Fruit", "Fungus", "Meat"}, abilities={"Bite", "Charge", "Cower", "Dash"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.04", armor="1.09", damage="0.90"},
    note="Role: Defense. Only family with Charge.",
    tames={
      {name="Mottled Boar", level="1-2", zone="Durotar", npcID=3098, mapID=1411, x=44.5, y=65.1},
      {name="Stonetusk Boar", level="7-8", zone="Elwynn Forest", npcID=113, mapID=1429, x=38.6, y=86.2},
      {name="Goretusk", level="14-15", zone="Westfall", npcID=157, mapID=1436, x=45.6, y=55.4},
      {name="Ashmane Boar", level="48-49", zone="Blasted Lands", npcID=5992, mapID=1419, x=58.2, y=30.4},
    }},
  {name="Carrion Bird", icon="ability_hunter_pet_vulture", role="General", diet={"Fish", "Meat"}, abilities={"Bite", "Claw", "Cower", "Demoralizing Screech", "Dive"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.05", damage="1.00"},
    note="Role: General. Only family with Demoralizing Screech.",
    tames={
      {name="Greater Fleshripper", level="16-17", zone="Westfall", npcID=154, mapID=1436, x=59.4, y=52.3},
      {name="Mesa Buzzard", level="34-35", zone="Arathi Highlands", npcID=2579, mapID=1417, x=34.1, y=61.9},
      {name="Roc", level="42-43", zone="Tanaris", npcID=5428, mapID=1446, x=49.9, y=31.2},
      {name="Carrion Vulture", level="50-52", zone="Western Plaguelands", npcID=1809, mapID=1422, x=29.9, y=54.7},
    }},
  {name="Cat", icon="ability_hunter_pet_cat", role="Offense", diet={"Fish", "Meat"}, abilities={"Bite", "Claw", "Cower", "Dash", "Prowl"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="0.98", armor="1.00", damage="1.10"},
    note="Role: Offense. Only family with Prowl.",
    tames={
      {name="Nightsaber", level="5-6", zone="Teldrassil", npcID=2042, mapID=1438, x=58.7, y=58.3},
      {name="Durotar Tiger", level="7-8", zone="Durotar", npcID=3121, mapID=1411, x=64.6, y=85.0},
      {name="Stranglethorn Tiger", level="32-33", zone="Stranglethorn Vale", npcID=682, mapID=1434, x=42.9, y=15.2},
      {name="Frostsaber Stalker", level="59-60", zone="Winterspring", npcID=7432, mapID=1452, x=52.1, y=15.2},
    }},
  {name="Core Hound", icon="ability_hunter_pet_corehound", role="Offense", diet={"Meat"}, abilities={"Bite", "Cower", "Lava Breath"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    note="Role: Offense. Only family with Lava Breath. Tameable beasts not confirmed yet in Forever.",
    tames={
    }},
  {name="Crab", icon="ability_hunter_pet_crab", role="Defense", diet={"Bread", "Fish", "Fruit", "Fungus"}, abilities={"Claw", "Cower", "Dash", "Pinch"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="0.96", armor="1.13", damage="0.95"},
    note="Role: Defense. Only family with Pinch.",
    tames={
      {name="Pygmy Surf Crawler", level="5-6", zone="Durotar", npcID=3106, mapID=1411, x=61.3, y=61.8},
      {name="Shore Crawler", level="17-18", zone="Westfall", npcID=1216, mapID=1436, x=28.8, y=77.8},
      {name="Silt Crawler", level="40-41", zone="Swamp of Sorrows", npcID=922, mapID=1435, x=90.2, y=23.8},
    }},
  {name="Crocolisk", icon="ability_hunter_pet_crocolisk", role="Defense", diet={"Fish", "Meat"}, abilities={"Bite", "Cower", "Dash", "Dismember"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="0.95", armor="1.10", damage="1.00"},
    note="Role: Defense. Only family with Dismember.",
    tames={
      {name="Dreadmaw Crocolisk", level="9-11", zone="Durotar", npcID=3110, mapID=1411, x=34.5, y=44.3},
      {name="Loch Crocolisk", level="14-15", zone="Loch Modan", npcID=1693, mapID=1432, x=54.5, y=41.7},
      {name="Giant Wetlands Crocolisk", level="25-26", zone="Wetlands", npcID=2089, mapID=1437, x=20.6, y=24.2},
      {name="Drywallow Crocolisk", level="35-36", zone="Dustwallow Marsh", npcID=4341, mapID=1445, x=41.2, y=26.9},
    }},
  {name="Fox", icon="ability_hunter_aspectofthefox", role="General", diet={"Meat"}, abilities={"Bite", "Cower", "Dash", "Trickster's Dance"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    note="Role: General. Only family with Trickster's Dance. Tameable beasts not confirmed yet in Forever.",
    tames={
    }},
  {name="Gorilla", icon="ability_hunter_pet_gorilla", role="Defense", diet={"Fruit", "Fungus"}, abilities={"Bite", "Cower", "Dash", "Thunderstomp"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.04", armor="1.00", damage="1.02"},
    note="Role: Defense. Only family with Thunderstomp.",
    tames={
      {name="Mistvale Gorilla", level="32-33", zone="Stranglethorn Vale", npcID=1108, mapID=1434, x=38.0, y=17.6},
      {name="Elder Mistvale Gorilla", level="40-41", zone="Stranglethorn Vale", npcID=1557, mapID=1434, x=33.0, y=64.8},
      {name="Groddoc Ape", level="42-43", zone="Feralas", npcID=5260, mapID=1444, x=58.5, y=58.7},
      {name="Un'Goro Thunderer", level="52-53", zone="Un'Goro Crater", npcID=6516, mapID=1449, x=65.8, y=15.6},
    }},
  {name="Hyena", icon="ability_hunter_pet_hyena", role="General", diet={"Fruit", "Meat"}, abilities={"Bite", "Cower", "Dash", "Tendon Rip"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.05", damage="1.00"},
    note="Role: General. Only family with Tendon Rip.",
    tames={
      {name="Bonepaw Hyena", level="33-35", zone="Desolace", npcID=4688, mapID=1443, x=53.8, y=39.0},
      {name="Starving Blisterpaw", level="41-42", zone="Tanaris", npcID=5425, mapID=1446, x=49.2, y=28.3},
      {name="Blisterpaw Hyena", level="44-45", zone="Tanaris", npcID=5426, mapID=1446, x=52.3, y=48.7},
    }},
  {name="Raptor", icon="ability_hunter_pet_raptor", role="Offense", diet={"Meat"}, abilities={"Bite", "Claw", "Cower", "Dash", "Savage Rend"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="0.95", armor="1.03", damage="1.10"},
    note="Role: Offense. Only family with Savage Rend.",
    tames={
      {name="Bloodtalon Scythemaw", level="8-10", zone="Durotar", npcID=3123, mapID=1411, x=42.1, y=21.3},
      {name="Sunscale Lashtail", level="11-13", zone="The Barrens", npcID=3254, mapID=1413, x=51.3, y=22.6},
      {name="Mottled Raptor", level="22-23", zone="Wetlands", npcID=1020, mapID=1437, x=25.2, y=49.8},
      {name="Bloodfen Raptor", level="35-36", zone="Dustwallow Marsh", npcID=4351, mapID=1445, x=49.5, y=18.4},
      {name="Jungle Stalker", level="40-41", zone="Stranglethorn Vale", npcID=687, mapID=1434, x=28.8, y=45.6},
    }},
  {name="Scorpid", icon="ability_hunter_pet_scorpid", role="Defense", diet={"Meat"}, abilities={"Claw", "Cower", "Dash", "Scorpid Poison"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.10", damage="0.94"},
    note="Role: Defense. Only family with Scorpid Poison.",
    tames={
      {name="Scorpid Worker", level="3", zone="Durotar", npcID=3124, mapID=1411, x=41.4, y=63.4},
      {name="Venomtail Scorpid", level="9-10", zone="Durotar", npcID=3127, mapID=1411, x=36.8, y=27.0},
      {name="Scorpashi Snapper", level="30-31", zone="Desolace", npcID=4696, mapID=1443, x=65.5, y=27.9},
      {name="Scorpid Hunter", level="40-41", zone="Tanaris", npcID=5422, mapID=1446, x=54.6, y=29.9},
    }},
  {name="Spider", icon="ability_hunter_pet_spider", role="Offense", diet={"Meat"}, abilities={"Bite", "Cower", "Dash", "Web"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.00", damage="1.07"},
    note="Role: Offense. Only family with Web.",
    tames={
      {name="Night Web Spider", level="3-4", zone="Tirisfal Glades", npcID=1505, mapID=1420, x=24.8, y=59.7},
      {name="Forest Spider", level="5-6", zone="Elwynn Forest", npcID=30, mapID=1429, x=38.0, y=70.0},
      {name="Webwood Venomfang", level="7-8", zone="Teldrassil", npcID=1999, mapID=1438, x=45.4, y=70.2},
      {name="Tarantula", level="15-16", zone="Redridge Mountains", npcID=442, mapID=1433, x=9.0, y=75.7},
    }},
  {name="Tallstrider", icon="ability_hunter_pet_tallstrider", role="Defense", diet={"Cheese", "Fruit", "Fungus"}, abilities={"Bite", "Cower", "Dash", "Dust Cloud"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.05", armor="1.00", damage="1.00"},
    note="Role: Defense. Only family with Dust Cloud.",
    tames={
      {name="Plainstrider", level="1-2", zone="Mulgore", npcID=2955, mapID=1412, x=47.2, y=81.5},
      {name="Adult Plainstrider", level="6-7", zone="Mulgore", npcID=2956, mapID=1412, x=42.9, y=59.1},
      {name="Elder Plainstrider", level="8-9", zone="Mulgore", npcID=2957, mapID=1412, x=50.0, y=36.4},
      {name="Fleeting Plainstrider", level="12-13", zone="The Barrens", npcID=3246, mapID=1413, x=55.7, y=29.6},
    }},
  {name="Turtle", icon="ability_hunter_pet_turtle", role="Defense", diet={"Fish", "Fruit", "Fungus", "Raw Fish"}, abilities={"Bite", "Cower", "Dash", "Shell Shield"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.13", damage="0.90"},
    note="Role: Defense. Only family with Shell Shield.",
    tames={
      {name="Oasis Snapjaw", level="15-16", zone="The Barrens", npcID=3461, mapID=1413, x=48.1, y=40.6},
      {name="Snapjaw", level="30-31", zone="Hillsbrad Foothills", npcID=2408, mapID=1424, x=66.1, y=38.2},
      {name="Sparkleshell Snapper", level="34-35", zone="Thousand Needles", npcID=4143, mapID=1441, x=79.9, y=66.3},
      {name="Saltwater Snapjaw", level="49-50", zone="The Hinterlands", npcID=2505, mapID=1425, x=80.0, y=58.0},
    }},
  {name="Wind Serpent", icon="ability_hunter_pet_windserpent", role="Offense", diet={"Bread", "Cheese", "Fish"}, abilities={"Bite", "Cower", "Dive", "Lightning Breath"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.00", damage="1.07"},
    note="Role: Offense. Only family with Lightning Breath.",
    tames={
      {name="Thunderhawk Hatchling", level="18-20", zone="The Barrens", npcID=3247, mapID=1413, x=46.8, y=51.0},
      {name="Cloud Serpent", level="25-26", zone="Thousand Needles", npcID=4117, mapID=1441, x=40.5, y=50.2},
      {name="Vale Screecher", level="41-43", zone="Feralas", npcID=5307, mapID=1444, x=58.2, y=57.8},
    }},
  {name="Wolf", icon="ability_hunter_pet_wolf", role="General", diet={"Meat"}, abilities={"Bite", "Cower", "Dash", "Furious Howl"}, trainer={"Growl", "Arcane Resistance", "Faster Attack", "Fire Resistance", "Frost Resistance", "Great Stamina", "Natural Armor", "Nature Resistance", "Shadow Resistance", "Slower Attack"},
    modifiers={health="1.00", armor="1.05", damage="1.00"},
    note="Role: General. Only family with Furious Howl.",
    tames={
      {name="Prairie Wolf", level="5-6", zone="Mulgore", npcID=2958, mapID=1412, x=41.7, y=67.9},
      {name="Gray Forest Wolf", level="7-8", zone="Elwynn Forest", npcID=1922, mapID=1429, x=65.1, y=64.4},
      {name="Worg", level="10-11", zone="Silverpine Forest", npcID=1765, mapID=1421, x=63.8, y=11.1},
      {name="Crag Coyote", level="35-36", zone="Badlands", npcID=2727, mapID=1418, x=51.0, y=38.1},
    }},
}

FLT.PET_ABILITIES = {
  {name="Arcane Resistance", icon="spell_nature_starfall", source="trainer", families={"All families"},
    effect="Increases Arcane Resistance.",
    ranks={
      {rank=1, level=20, tp=5, desc="Increases Arcane Resistance by 30.", learnFrom={
      }},
      {rank=2, level=30, tp=15, desc="Increases Arcane Resistance by 60.", learnFrom={
      }},
      {rank=3, level=40, tp=45, desc="Increases Arcane Resistance by 90.", learnFrom={
      }},
      {rank=4, level=50, tp=90, desc="Increases Arcane Resistance by 120.", learnFrom={
      }},
    }},
  {name="Bite", icon="ability_druid_ferociousbite", source="wild", families={"Bat", "Bear", "Boar", "Carrion Bird", "Cat", "Core Hound", "Crocolisk", "Fox", "Gorilla", "Hyena", "Raptor", "Spider", "Tallstrider", "Turtle", "Wind Serpent", "Wolf"},
    effect="Bite the enemy, causing damage.",
    ranks={
      {rank=1, level=1, tp=1, desc="Bite the enemy, causing 7 to 9 damage.", learnFrom={
        {name="Ragged Scavenger", level="2-3", zone="Tirisfal Glades", npcID=1509, mapID=1420, x=36.6, y=60.8, family="Wolf"},
        {name="Night Web Spider", level="3-4", zone="Tirisfal Glades", npcID=1505, mapID=1420, x=24.8, y=59.7, family="Spider"},
        {name="Forest Spider", level="5-6", zone="Elwynn Forest", npcID=30, mapID=1429, x=38.0, y=70.0, family="Spider"},
        {name="Night Web Matriarch", level="5", zone="Tirisfal Glades", npcID=1688, mapID=1420, x=24.0, y=58.2, family="Spider"},
        {name="Githyiss the Vile", level="5", zone="Teldrassil", npcID=1994, mapID=1438, x=56.6, y=26.3, family="Spider"},
        {name="Prairie Wolf", level="5-6", zone="Mulgore", npcID=2958, mapID=1412, x=41.7, y=67.9, family="Wolf"},
        {name="Snow Tracker Wolf", level="6-7", zone="Dun Morogh", npcID=1138, mapID=1426, x=46.0, y=46.2, family="Wolf"},
        {name="Gray Forest Wolf", level="7-8", zone="Elwynn Forest", npcID=1922, mapID=1429, x=65.1, y=64.4, family="Wolf"},
        {name="Webwood Venomfang", level="7-8", zone="Teldrassil", npcID=1999, mapID=1438, x=45.4, y=70.2, family="Spider"},
        {name="Prairie Stalker", level="7-8", zone="Mulgore", npcID=2959, mapID=1412, x=48.2, y=52.5, family="Wolf"},
        {name="Winter Wolf", level="7-8", zone="Dun Morogh", npcID=1131, mapID=1426, x=45.1, y=43.3, family="Wolf"},
        {name="Dreadmaw Crocolisk", level="9-11", zone="Durotar", npcID=3110, mapID=1411, x=34.5, y=44.3, family="Crocolisk"},
      }},
      {rank=2, level=8, tp=4, desc="Bite the enemy, causing 16 to 18 damage.", learnFrom={
        {name="Webwood Silkspinner", level="8-9", zone="Teldrassil", npcID=2000, mapID=1438, x=45.1, y=35.1, family="Spider"},
        {name="Starving Winter Wolf", level="8-9", zone="Dun Morogh", npcID=1133, mapID=1426, x=34.2, y=41.9, family="Wolf"},
        {name="Prowler", level="9-10", zone="Elwynn Forest", npcID=118, mapID=1429, x=78.4, y=62.7, family="Wolf"},
        {name="Prairie Wolf Alpha", level="9-10", zone="Mulgore", npcID=2960, mapID=1412, x=52.2, y=41.5, family="Wolf"},
        {name="Vicious Night Web Spider", level="9-10", zone="Tirisfal Glades", npcID=1555, mapID=1420, x=86.0, y=52.5, family="Spider"},
        {name="Giant Webwood Spider", level="10-11", zone="Teldrassil", npcID=2001, mapID=1438, x=41.2, y=28.9, family="Spider"},
        {name="Worg", level="10-11", zone="Silverpine Forest", npcID=1765, mapID=1421, x=63.8, y=11.1, family="Wolf"},
        {name="Timber", level="10", zone="Dun Morogh", npcID=1132, mapID=1426, x=34.1, y=42.6, family="Wolf"},
        {name="Coyote", level="10-11", zone="Westfall", npcID=834, mapID=1436, x=50.7, y=29.2, family="Wolf"},
        {name="Forest Lurker", level="10-11", zone="Loch Modan", npcID=1195, mapID=1432, x=31.1, y=41.6, family="Spider"},
        {name="Coyote Packleader", level="11-12", zone="Westfall", npcID=833, mapID=1436, x=41.7, y=26.7, family="Wolf"},
        {name="Lady Sathrah", level="12", zone="Teldrassil", npcID=7319, mapID=1438, x=47.5, y=26.0, family="Spider"},
        {name="Loch Crocolisk", level="14-15", zone="Loch Modan", npcID=1693, mapID=1432, x=54.5, y=41.7, family="Crocolisk"},
        {name="Tarantula", level="15-16", zone="Redridge Mountains", npcID=442, mapID=1433, x=9.0, y=75.7, family="Spider"},
        {name="Oasis Snapjaw", level="15-16", zone="The Barrens", npcID=3461, mapID=1413, x=48.1, y=40.6, family="Turtle"},
      }},
      {rank=3, level=16, tp=7, desc="Bite the enemy, causing 24 to 28 damage.", learnFrom={
        {name="Deepmoss Creeper", level="16-17", zone="Stonetalon Mountains", npcID=4005, mapID=1442, x=59.2, y=78.1, family="Spider"},
        {name="Bloodsnout Worg", level="16-17", zone="Silverpine Forest", npcID=1923, mapID=1421, x=49.8, y=77.7, family="Wolf"},
        {name="Wood Lurker", level="17-18", zone="Loch Modan", npcID=1185, mapID=1432, x=75.6, y=35.9, family="Spider"},
        {name="Deviate Crocolisk", level="18-19", zone="Wailing Caverns (Dungeon)", npcID=5053, family="Crocolisk"},
        {name="Shanda the Spinner", level="19", zone="Loch Modan", npcID=14266, mapID=1432, x=78.1, y=52.4, family="Spider"},
        {name="Ghostpaw Runner", level="19-20", zone="Ashenvale", npcID=3823, mapID=1440, x=31.3, y=49.8, family="Wolf"},
        {name="Deepmoss Webspinner", level="19-20", zone="Stonetalon Mountains", npcID=4006, mapID=1442, x=70.2, y=46.1, family="Spider"},
        {name="Greater Tarantula", level="19-20", zone="Redridge Mountains", npcID=505, mapID=1433, x=48.7, y=43.6, family="Spider"},
        {name="Forest Moss Creeper", level="20-21", zone="Hillsbrad Foothills", npcID=2350, mapID=1424, x=56.5, y=30.1, family="Spider"},
        {name="Kresh", level="20", zone="Wailing Caverns (Dungeon)", npcID=3653, family="Turtle"},
        {name="Besseleth", level="21", zone="Stonetalon Mountains", npcID=11921, mapID=1442, x=52.5, y=71.7, family="Spider"},
        {name="Green Recluse", level="21-22", zone="Duskwood", npcID=569, mapID=1431, x=50.8, y=20.3, family="Spider"},
        {name="Large Loch Crocolisk", level="22", zone="Loch Modan", npcID=2476, mapID=1432, x=58.9, y=31.1, family="Crocolisk"},
        {name="Chatter", level="23", zone="Redridge Mountains", npcID=616, mapID=1433, x=47.4, y=43.1, family="Spider"},
        {name="Lupos", level="23", zone="Duskwood", npcID=521, mapID=1431, x=38.3, y=25.3, family="Wolf"},
        {name="Aku'mai Fisher", level="23-24", zone="Blackfathom Deeps (Dungeon)", npcID=4824, family="Turtle"},
        {name="Creepthess", level="24", zone="Hillsbrad Foothills", npcID=14279, mapID=1424, x=38.6, y=58.4, family="Spider"},
      }},
      {rank=4, level=24, tp=10, desc="Bite the enemy, causing 31 to 37 damage.", learnFrom={
        {name="Giant Moss Creeper", level="24-25", zone="Hillsbrad Foothills", npcID=2349, mapID=1424, x=60.9, y=47.8, family="Spider"},
        {name="Black Ravager", level="24-25", zone="Duskwood", npcID=628, mapID=1431, x=70.0, y=35.4, family="Wolf"},
        {name="Leech Widow", level="24", zone="Wetlands", npcID=1112, mapID=1437, x=47.3, y=59.2, family="Spider"},
        {name="Ghamoo-ra", level="25", zone="Blackfathom Deeps (Dungeon)", npcID=4887, family="Turtle"},
        {name="Giant Wetlands Crocolisk", level="25-26", zone="Wetlands", npcID=2089, mapID=1437, x=20.6, y=24.2, family="Crocolisk"},
        {name="Black Ravager Mastiff", level="25-26", zone="Duskwood", npcID=1258, mapID=1431, x=67.2, y=35.1, family="Wolf"},
        {name="Aku'mai Snapjaw", level="26-27", zone="Blackfathom Deeps (Dungeon)", npcID=4825, family="Turtle"},
        {name="Elder Moss Creeper", level="26-27", zone="Hillsbrad Foothills", npcID=2348, mapID=1424, x=63.9, y=66.4, family="Spider"},
        {name="Ghostpaw Alpha", level="27-28", zone="Ashenvale", npcID=3825, mapID=1440, x=71.9, y=58.0, family="Wolf"},
        {name="Naraxis", level="27", zone="Duskwood", npcID=574, mapID=1431, x=86.4, y=47.6, family="Spider"},
        {name="Wildthorn Lurker", level="28-29", zone="Ashenvale", npcID=3821, mapID=1440, x=91.0, y=55.4, family="Spider"},
        {name="Snapjaw", level="30-31", zone="Hillsbrad Foothills", npcID=2408, mapID=1424, x=66.1, y=38.2, family="Turtle"},
        {name="Cranky Benj", level="32", zone="Alterac Mountains", npcID=14223, mapID=1416, x=37.3, y=19.8, family="Turtle"},
      }},
      {rank=5, level=32, tp=13, desc="Bite the enemy, causing 40 to 48 damage.", learnFrom={
        {name="Plains Creeper", level="32-33", zone="Arathi Highlands", npcID=2563, mapID=1417, x=48.7, y=50.8, family="Spider"},
        {name="Sparkleshell Snapper", level="34-35", zone="Thousand Needles", npcID=4143, mapID=1441, x=79.9, y=66.3, family="Turtle"},
        {name="Crag Coyote", level="35-36", zone="Badlands", npcID=2727, mapID=1418, x=51.0, y=38.1, family="Wolf"},
        {name="Darkfang Spider", level="35-36", zone="Dustwallow Marsh", npcID=4413, family="Spider"},
        {name="Giant Plains Creeper", level="35-36", zone="Arathi Highlands", npcID=2565, mapID=1417, x=54.4, y=54.9, family="Spider"},
        {name="Drywallow Crocolisk", level="35-36", zone="Dustwallow Marsh", npcID=4341, mapID=1445, x=41.2, y=26.9, family="Crocolisk"},
        {name="Darkfang Lurker", level="36-37", zone="Dustwallow Marsh", npcID=4411, family="Spider"},
        {name="Mudrock Tortoise", level="36-37", zone="Dustwallow Marsh", npcID=4396, family="Turtle"},
        {name="Darkfang Creeper", level="38-39", zone="Dustwallow Marsh", npcID=4412, mapID=1445, x=40.8, y=48.3, family="Spider"},
        {name="Mottled Drywallow Crocolisk", level="38-39", zone="Dustwallow Marsh", npcID=4344, mapID=1445, x=39.6, y=53.1, family="Crocolisk"},
      }},
      {rank=6, level=40, tp=17, desc="Bite the enemy, causing 49 to 59 damage.", learnFrom={
        {name="Barnabus", level="38", zone="Badlands", npcID=2753, mapID=1418, x=46.2, y=74.3, family="Wolf"},
        {name="Ripscale", level="39", zone="Dustwallow Marsh", npcID=14233, family="Crocolisk"},
        {name="Drywallow Daggermaw", level="40-41", zone="Dustwallow Marsh", npcID=4345, mapID=1445, x=48.4, y=68.7, family="Crocolisk"},
        {name="Longtooth Runner", level="40-41", zone="Feralas", npcID=5286, mapID=1444, x=64.5, y=48.6, family="Wolf"},
        {name="Deathstrike Tarantula", level="40-41", zone="Swamp of Sorrows", npcID=769, mapID=1435, x=65.3, y=69.9, family="Spider"},
        {name="Mudrock Snapjaw", level="41-42", zone="Dustwallow Marsh", npcID=4400, family="Turtle"},
        {name="Sawtooth Snapper", level="41-42", zone="Swamp of Sorrows", npcID=1087, mapID=1435, x=83.4, y=36.3, family="Crocolisk"},
        {name="Snarler", level="42", zone="Feralas", npcID=5356, mapID=1444, x=80.2, y=39.6, family="Wolf"},
        {name="Old Cliff Jumper", level="42", zone="The Hinterlands", npcID=8211, mapID=1425, x=11.9, y=53.7, family="Wolf"},
        {name="Deadmire", level="45", zone="Dustwallow Marsh", npcID=4841, mapID=1445, x=48.8, y=56.8, family="Crocolisk"},
        {name="Felpaw Wolf", level="47-48", zone="Felwood", npcID=8959, mapID=1448, x=49.1, y=83.2, family="Wolf"},
        {name="Timberweb Recluse", level="47-48", zone="Azshara", npcID=8762, mapID=1447, x=37.0, y=42.0, family="Spider"},
        {name="Death Howl", level="49", zone="Felwood", npcID=14339, mapID=1448, x=50.0, y=77.1, family="Wolf"},
      }},
      {rank=7, level=48, tp=21, desc="Bite the enemy, causing 66 to 80 damage.", learnFrom={
        {name="Rekk'tilac", level="48", zone="Searing Gorge", npcID=8277, mapID=1427, x=53.0, y=70.9, family="Spider"},
        {name="Saltwater Snapjaw", level="49-50", zone="The Hinterlands", npcID=2505, mapID=1425, x=80.0, y=58.0, family="Turtle"},
        {name="Cave Creeper", level="50-52", zone="Blackrock Depths (Dungeon)", npcID=8933, family="Spider"},
        {name="Sewer Beast", level="50", zone="Stormwind City", npcID=3581, mapID=1453, x=71.1, y=68.0, family="Crocolisk"},
        {name="Vilebranch Raiding Wolf", level="50-51", zone="The Hinterlands", npcID=2681, mapID=1425, x=60.0, y=76.0, family="Wolf"},
        {name="Ironback", level="51", zone="The Hinterlands", npcID=8213, mapID=1425, x=81.5, y=49.2, family="Turtle"},
        {name="Felpaw Ravager", level="51-52", zone="Felwood", npcID=8961, mapID=1448, x=56.6, y=19.4, family="Wolf"},
        {name="Uhk'loc", level="52", zone="Un'Goro Crater", npcID=6585, mapID=1449, x=68.5, y=12.7, family="Gorilla"},
        {name="Diseased Wolf", level="53-54", zone="Western Plaguelands", npcID=1817, mapID=1422, x=46.5, y=44.9, family="Wolf"},
        {name="Plague Lurker", level="54-55", zone="Western Plaguelands", npcID=1824, mapID=1422, x=60.5, y=52.0, family="Spider"},
      }},
      {rank=8, level=56, tp=25, desc="Bite the enemy, causing 81 to 99 damage.", learnFrom={
        {name="Bloodaxe Worg", level="56-57", zone="Blackrock Spire (Dungeon)", npcID=9696, family="Wolf"},
      }},
    }},
  {name="Charge", icon="ability_hunter_pet_boar", source="wild", families={"Boar"},
    effect="Charges an enemy, immobilizes it for 1 sec, and adds melee attack power to the boar's next attack.",
    ranks={
      {rank=1, level=1, tp=5, desc="Charges an enemy, immobilizes it for 1 sec, and adds 66 melee attack power to the boar's next attack.", learnFrom={
        {name="Mottled Boar", level="1-2", zone="Durotar", npcID=3098, mapID=1411, x=44.5, y=65.1, family="Boar"},
        {name="Young Thistle Boar", level="1-2", zone="Teldrassil", npcID=1984, mapID=1438, x=59.1, y=43.3, family="Boar"},
        {name="Thistle Boar", level="2-3", zone="Teldrassil", npcID=1985, mapID=1438, x=59.6, y=36.9, family="Boar"},
        {name="Small Crag Boar", level="3", zone="Dun Morogh", npcID=708, mapID=1426, x=22.7, y=72.4, family="Boar"},
        {name="Battleboar", level="3-4", zone="Mulgore", npcID=2966, mapID=1412, x=53.9, y=83.5, family="Boar"},
        {name="Bristleback Battleboar", level="4-5", zone="Mulgore", npcID=2954, mapID=1412, x=59.0, y=79.3, family="Boar"},
        {name="Crag Boar", level="5-6", zone="Dun Morogh", npcID=1125, mapID=1426, x=44.2, y=59.4, family="Boar"},
        {name="Large Crag Boar", level="6-7", zone="Dun Morogh", npcID=1126, mapID=1426, x=48.1, y=47.2, family="Boar"},
        {name="Dire Mottled Boar", level="6-7", zone="Durotar", npcID=3099, mapID=1411, x=48.3, y=45.9, family="Boar"},
        {name="Elder Crag Boar", level="7-8", zone="Dun Morogh", npcID=1127, mapID=1426, x=45.3, y=42.6, family="Boar"},
        {name="Rockhide Boar", level="7-8", zone="Elwynn Forest", npcID=524, mapID=1429, x=58.0, y=80.8, family="Boar"},
        {name="Stonetusk Boar", level="7-8", zone="Elwynn Forest", npcID=113, mapID=1429, x=38.6, y=86.2, family="Boar"},
        {name="Porcine Entourage", level="7", zone="Elwynn Forest", npcID=390, mapID=1429, x=69.6, y=79.2, family="Boar"},
        {name="Elder Mottled Boar", level="8-9", zone="Durotar", npcID=3100, mapID=1411, x=44.6, y=27.0, family="Boar"},
        {name="Princess", level="9", zone="Elwynn Forest", npcID=330, mapID=1429, x=69.7, y=79.2, family="Boar"},
        {name="Scarred Crag Boar", level="9-10", zone="Dun Morogh", npcID=1689, mapID=1426, x=78.9, y=49.5, family="Boar"},
        {name="Longsnout", level="10-11", zone="Elwynn Forest", npcID=119, mapID=1429, x=25.0, y=84.8, family="Boar"},
        {name="Corrupted Mottled Boar", level="10-11", zone="Durotar", npcID=3225, mapID=1411, x=43.7, y=15.5, family="Boar"},
        {name="Mountain Boar", level="10-11", zone="Loch Modan", npcID=1190, mapID=1432, x=33.9, y=31.8, family="Boar"},
      }},
      {rank=2, level=12, tp=9, desc="Charges an enemy, immobilizes it for 1 sec, and adds 130 melee attack power to the boar's next attack.", learnFrom={
        {name="Young Goretusk", level="12-13", zone="Westfall", npcID=454, mapID=1436, x=50.4, y=29.4, family="Boar"},
        {name="Goretusk", level="14-15", zone="Westfall", npcID=157, mapID=1436, x=45.6, y=55.4, family="Boar"},
        {name="Mangy Mountain Boar", level="14-15", zone="Loch Modan", npcID=1191, mapID=1432, x=58.5, y=61.3, family="Boar"},
        {name="Great Goretusk", level="16-17", zone="Redridge Mountains; Westfall", npcID=547, mapID=1433, x=20.3, y=60.5, family="Boar"},
        {name="Elder Mountain Boar", level="16-17", zone="Loch Modan", npcID=1192, mapID=1432, x=66.3, y=40.1, family="Boar"},
      }},
      {rank=3, level=24, tp=13, desc="Charges an enemy, immobilizes it for 1 sec, and adds 204 melee attack power to the boar's next attack.", learnFrom={
        {name="Agam'ar", level="24-25", zone="Razorfen Kraul (Dungeon)", npcID=4511, family="Boar"},
        {name="Bellygrub", level="24", zone="Redridge Mountains", npcID=345, mapID=1433, x=10.6, y=49.3, family="Boar"},
        {name="Raging Agam'ar", level="25-26", zone="Razorfen Kraul (Dungeon)", npcID=4514, family="Boar"},
        {name="Rotting Agam'ar", level="28", zone="Razorfen Kraul (Dungeon)", npcID=4512, family="Boar"},
      }},
      {rank=4, level=36, tp=17, desc="Charges an enemy, immobilizes it for 1 sec, and adds 294 melee attack power to the boar's next attack.", noSource=true, learnFrom={
      }},
      {rank=5, level=48, tp=21, desc="Charges an enemy, immobilizes it for 1 sec, and adds 430 melee attack power to the boar's next attack.", learnFrom={
        {name="Ashmane Boar", level="48-49", zone="Blasted Lands", npcID=5992, mapID=1419, x=58.2, y=30.4, family="Boar"},
        {name="Grunter", level="50", zone="Blasted Lands", npcID=8303, mapID=1419, x=56.8, y=28.6, family="Boar"},
      }},
      {rank=6, level=60, tp=25, desc="Charges an enemy, immobilizes it for 1 sec, and adds 520 melee attack power to the boar's next attack.", learnFrom={
        {name="Plagued Swine", level="60", zone="Eastern Plaguelands", npcID=16117, mapID=1423, x=12.3, y=26.1, family="Boar"},
      }},
    }},
  {name="Claw", icon="ability_druid_rake", source="wild", families={"Bear", "Bird of Prey", "Carrion Bird", "Cat", "Crab", "Raptor", "Scorpid"},
    effect="Claw the enemy, causing damage.",
    ranks={
      {rank=1, level=1, tp=1, desc="Claw the enemy, causing 4 to 6 damage.", learnFrom={
        {name="Scorpid Worker", level="3", zone="Durotar", npcID=3124, mapID=1411, x=41.4, y=63.4, family="Scorpid"},
        {name="Sarkoth", level="4", zone="Durotar", npcID=3281, mapID=1411, x=40.5, y=66.8, family="Scorpid"},
        {name="Pygmy Surf Crawler", level="5-6", zone="Durotar", npcID=3106, mapID=1411, x=61.3, y=61.8, family="Crab"},
        {name="Strigid Owl", level="5-6", zone="Teldrassil", npcID=1995, mapID=1438, x=58.7, y=56.2, family="Bird of Prey"},
        {name="Ice Claw Bear", level="7-8", zone="Dun Morogh", npcID=1196, mapID=1426, x=38.5, y=43.5, family="Bear"},
      }},
      {rank=2, level=8, tp=4, desc="Claw the enemy, causing 8 to 12 damage.", learnFrom={
        {name="Strigid Hunter", level="8-9", zone="Teldrassil", npcID=1997, mapID=1438, x=38.1, y=39.5, family="Bird of Prey"},
        {name="Young Forest Bear", level="8-9", zone="Elwynn Forest", npcID=822, mapID=1429, x=63.3, y=77.0, family="Bear"},
        {name="Encrusted Surf Crawler", level="9-10", zone="Durotar", npcID=3108, mapID=1411, x=57.2, y=12.3, family="Crab"},
        {name="Venomtail Scorpid", level="9-10", zone="Durotar", npcID=3127, mapID=1411, x=36.8, y=27.0, family="Scorpid"},
        {name="Death Flayer", level="11", zone="Durotar", npcID=5823, mapID=1411, x=36.5, y=49.7, family="Scorpid"},
        {name="Mangeclaw", level="11", zone="Dun Morogh", npcID=1961, mapID=1426, x=78.3, y=37.8, family="Bear"},
        {name="Thistle Bear", level="11-12", zone="Darkshore", npcID=2163, mapID=1439, x=43.4, y=34.7, family="Bear"},
        {name="Ferocious Grizzled Bear", level="11-12", zone="Silverpine Forest", npcID=1778, mapID=1421, x=48.8, y=32.9, family="Bear"},
        {name="Bjarn", level="12", zone="Dun Morogh", npcID=1130, mapID=1426, x=59.5, y=58.4, family="Bear"},
        {name="Tide Crawler", level="12-14", zone="Darkshore", npcID=2232, mapID=1439, x=41.6, y=30.1, family="Crab"},
      }},
      {rank=3, level=16, tp=7, desc="Claw the enemy, causing 12 to 16 damage.", learnFrom={
        {name="Black Bear Patriarch", level="16-17", zone="Loch Modan", npcID=1189, mapID=1432, x=68.5, y=36.4, family="Bear"},
        {name="Shore Crawler", level="17-18", zone="Westfall", npcID=1216, mapID=1436, x=28.8, y=77.8, family="Crab"},
        {name="Den Mother", level="18-19", zone="Darkshore", npcID=6788, mapID=1439, x=51.5, y=38.3, family="Bear"},
        {name="Ghost Saber", level="19-20", zone="Darkshore", npcID=3619, family="Cat"},
        {name="Clattering Crawler", level="19-20", zone="Ashenvale", npcID=3812, mapID=1440, x=12.4, y=22.9, family="Crab"},
        {name="Ol' Sooty", level="20", zone="Loch Modan", npcID=1225, mapID=1432, x=37.9, y=63.4, family="Bear"},
        {name="Gray Bear", level="21-22", zone="Hillsbrad Foothills", npcID=2351, mapID=1424, x=57.0, y=29.0, family="Bear"},
        {name="Ashenvale Bear", level="21-22", zone="Ashenvale", npcID=3809, mapID=1440, x=45.9, y=59.6, family="Bear"},
        {name="Skittering Crustacean", level="22-23", zone="Blackfathom Deeps (Dungeon)", npcID=4821, family="Crab"},
        {name="Snapping Crustacean", level="23-24", zone="Blackfathom Deeps (Dungeon)", npcID=4822, family="Crab"},
      }},
      {rank=4, level=24, tp=10, desc="Claw the enemy, causing 16 to 22 damage.", learnFrom={
        {name="Elder Ashenvale Bear", level="25-26", zone="Ashenvale", npcID=3810, mapID=1440, x=69.6, y=56.6, family="Bear"},
        {name="Barbed Crustacean", level="25-26", zone="Blackfathom Deeps (Dungeon)", npcID=4823, family="Crab"},
        {name="Scorpashi Snapper", level="30-31", zone="Desolace", npcID=4696, mapID=1443, x=65.5, y=27.9, family="Scorpid"},
        {name="Scorpid Reaver", level="31-32", zone="Thousand Needles", npcID=4140, mapID=1441, x=73.9, y=61.0, family="Scorpid"},
      }},
      {rank=5, level=32, tp=13, desc="Claw the enemy, causing 21 to 29 damage.", learnFrom={
        {name="Scorpashi Lasher", level="34-35", zone="Desolace", npcID=4697, mapID=1443, x=58.9, y=54.7, family="Scorpid"},
        {name="Vile Sting", level="35", zone="Thousand Needles", npcID=5937, mapID=1441, x=70.5, y=72.9, family="Scorpid"},
        {name="Drywallow Snapper", level="37-38", zone="Dustwallow Marsh", npcID=4343, mapID=1445, x=40.1, y=38.3, family="Crocolisk"},
        {name="Venomlash Scorpid", level="39-40", zone="Uldaman (Dungeon)", npcID=7022, family="Scorpid"},
      }},
      {rank=6, level=40, tp=17, desc="Claw the enemy, causing 26 to 36 damage.", learnFrom={
        {name="Silt Crawler", level="40-41", zone="Swamp of Sorrows", npcID=922, mapID=1435, x=90.2, y=23.8, family="Crab"},
        {name="Scorpid Hunter", level="40-41", zone="Tanaris", npcID=5422, mapID=1446, x=54.6, y=29.9, family="Scorpid"},
        {name="Ironfur Bear", level="41-42", zone="Feralas", npcID=5268, mapID=1444, x=78.0, y=45.4, family="Bear"},
        {name="King Bangalash", level="43", zone="Stranglethorn Vale", npcID=731, mapID=1434, x=38.2, y=35.6, family="Cat"},
        {name="Old Grizzlegut", level="43", zone="Feralas", npcID=5352, mapID=1444, x=59.5, y=59.4, family="Bear"},
        {name="Monstrous Crawler", level="43-44", zone="Swamp of Sorrows", npcID=1088, mapID=1435, x=96.0, y=46.3, family="Crab"},
      }},
      {rank=7, level=48, tp=21, desc="Claw the enemy, causing 35 to 49 damage.", learnFrom={
        {name="Ironfur Patriarch", level="48-49", zone="Feralas", npcID=5274, mapID=1444, x=45.9, y=24.2, family="Bear"},
        {name="Angerclaw Mauler", level="49-50", zone="Felwood", npcID=8958, mapID=1448, x=39.4, y=45.1, family="Bear"},
        {name="Mongress", level="50", zone="Felwood", npcID=14344, mapID=1448, x=43.3, y=76.6, family="Bear"},
        {name="Ironbeak Hunter", level="50-51", zone="Felwood", npcID=7099, mapID=1448, x=41.8, y=50.1, family="Bird of Prey"},
        {name="Olm the Wise", level="52", zone="Felwood", npcID=14343, mapID=1448, x=50.2, y=32.8, family="Bird of Prey"},
        {name="Shardtooth Bear", level="53-54", zone="Winterspring", npcID=7444, mapID=1452, x=44.6, y=38.0, family="Bear"},
        {name="Clack the Reaver", level="53", zone="Blasted Lands", npcID=8301, mapID=1419, x=54.0, y=35.7, family="Scorpid"},
        {name="Winterspring Owl", level="54-56", zone="Winterspring", npcID=7455, mapID=1452, x=59.2, y=35.5, family="Bird of Prey"},
        {name="Deathlash Scorpid", level="54-55", zone="Burning Steppes", npcID=9695, mapID=1428, x=71.0, y=45.2, family="Scorpid"},
        {name="Diseased Grizzly", level="55-56", zone="Western Plaguelands", npcID=1816, mapID=1422, x=60.5, y=52.0, family="Bear"},
      }},
      {rank=8, level=56, tp=25, desc="Claw the enemy, causing 43 to 59 damage.", learnFrom={
        {name="Elder Shardtooth", level="57-58", zone="Winterspring", npcID=7445, mapID=1452, x=59.3, y=23.7, family="Bear"},
        {name="Winterspring Screecher", level="57-59", zone="Winterspring", npcID=7456, mapID=1452, x=62.4, y=53.0, family="Bird of Prey"},
      }},
    }},
  {name="Cower", icon="ability_druid_cower", source="wild", families={"All families"},
    effect="Cower, causing no damage but lowering threat, making the enemy less likely to attack.",
    ranks={
      {rank=1, level=5, tp=8, desc="Cower, causing no damage but lowering threat, making the enemy less likely to attack.", learnFrom={
        {name="Juvenile Snow Leopard", level="5-6", zone="Dun Morogh", npcID=1199, mapID=1426, x=41.5, y=60.0, family="Cat"},
        {name="Nightsaber", level="5-6", zone="Teldrassil", npcID=2042, mapID=1438, x=58.7, y=58.3, family="Cat"},
        {name="Greater Duskbat", level="6-7", zone="Tirisfal Glades", npcID=1553, mapID=1420, x=51.4, y=49.5, family="Bat"},
        {name="Flatland Cougar", level="7-8", zone="Mulgore", npcID=3035, mapID=1412, x=47.1, y=49.2, family="Cat"},
        {name="Durotar Tiger", level="7-8", zone="Durotar", npcID=3121, mapID=1411, x=64.6, y=85.0, family="Cat"},
        {name="Elder Plainstrider", level="8-9", zone="Mulgore", npcID=2957, mapID=1412, x=50.0, y=36.4, family="Tallstrider"},
        {name="Mazzranache", level="9", zone="Mulgore", npcID=3068, mapID=1412, x=49.1, y=48.7, family="Tallstrider"},
        {name="Moonstalker Runt", level="10-11", zone="Darkshore", npcID=2070, mapID=1439, x=44.8, y=42.6, family="Cat"},
        {name="Foreststrider Fledgling", level="11-13", zone="Darkshore", npcID=2321, mapID=1439, x=41.9, y=46.0, family="Tallstrider"},
        {name="Fleeting Plainstrider", level="12-13", zone="The Barrens", npcID=3246, mapID=1413, x=55.7, y=29.6, family="Tallstrider"},
      }},
      {rank=2, level=15, tp=10, desc="Cower, causing no damage but lowering threat, making the enemy less likely to attack.", learnFrom={
        {name="Savannah Patriarch", level="15-16", zone="The Barrens", npcID=3241, mapID=1413, x=45.5, y=16.6, family="Cat"},
        {name="Ornery Plainstrider", level="16-17", zone="The Barrens", npcID=3245, mapID=1413, x=59.5, y=33.5, family="Tallstrider"},
        {name="Giant Foreststrider", level="17-19", zone="Darkshore", npcID=2323, mapID=1439, x=43.2, y=80.2, family="Tallstrider"},
        {name="Moonstalker Sire", level="17-18", zone="Darkshore", npcID=2237, mapID=1439, x=44.0, y=80.0, family="Cat"},
        {name="Twilight Runner", level="23-24", zone="Stonetalon Mountains", npcID=4067, mapID=1442, x=32.7, y=11.1, family="Cat"},
        {name="Starving Mountain Lion", level="23-24", zone="Hillsbrad Foothills", npcID=2384, mapID=1424, x=50.0, y=41.2, family="Cat"},
      }},
      {rank=3, level=25, tp=12, desc="Cower, causing no damage but lowering threat, making the enemy less likely to attack.", learnFrom={
        {name="Crag Stalker", level="25-26", zone="Thousand Needles", npcID=4126, mapID=1441, x=40.4, y=51.7, family="Cat"},
        {name="Feral Mountain Lion", level="27-28", zone="Hillsbrad Foothills", npcID=2385, mapID=1424, x=61.1, y=66.9, family="Cat"},
        {name="Kraul Bat", level="30-31", zone="Razorfen Kraul (Dungeon)", npcID=4538, family="Bat"},
        {name="Young Stranglethorn Tiger", level="30-31", zone="Stranglethorn Vale", npcID=681, mapID=1434, x=35.1, y=12.1, family="Cat"},
        {name="Young Panther", level="30-31", zone="Stranglethorn Vale", npcID=683, mapID=1434, x=40.5, y=11.4, family="Cat"},
        {name="Greater Kraul Bat", level="32", zone="Razorfen Kraul (Dungeon)", npcID=4539, family="Bat"},
        {name="Panther", level="32-33", zone="Stranglethorn Vale", npcID=736, mapID=1434, x=30.9, y=11.3, family="Cat"},
      }},
      {rank=4, level=35, tp=14, desc="Cower, causing no damage but lowering threat, making the enemy less likely to attack.", learnFrom={
        {name="Ridge Stalker", level="36-37", zone="Badlands", npcID=2731, mapID=1418, x=46.2, y=37.6, family="Cat"},
        {name="Ridge Huntress", level="38-39", zone="Badlands", npcID=2732, mapID=1418, x=41.6, y=59.9, family="Cat"},
        {name="Shrike Bat", level="38-39", zone="Uldaman (Dungeon)", npcID=4861, family="Bat"},
      }},
      {rank=5, level=45, tp=16, desc="Cower, causing no damage but lowering threat, making the enemy less likely to attack.", learnFrom={
        {name="Jaguero Stalker", level="50", zone="Stranglethorn Vale", npcID=2522, mapID=1434, x=37.5, y=82.8, family="Cat"},
        {name="Plaguebat", level="53-55", zone="Eastern Plaguelands", npcID=8600, mapID=1423, x=30.0, y=64.2, family="Bat"},
        {name="Noxious Plaguebat", level="54-56", zone="Eastern Plaguelands", npcID=8601, mapID=1423, x=53.1, y=51.1, family="Bat"},
      }},
      {rank=6, level=55, tp=18, desc="Cower, causing no damage but lowering threat, making the enemy less likely to attack.", learnFrom={
        {name="Frostsaber Cub", level="55-56", zone="Winterspring", npcID=7430, mapID=1452, x=51.6, y=11.3, family="Cat"},
        {name="Monstrous Plaguebat", level="56-58", zone="Eastern Plaguelands", npcID=8602, mapID=1423, x=41.8, y=28.2, family="Bat"},
      }},
    }},
  {name="Dash", icon="ability_druid_dash", source="wild", families={"Bear", "Boar", "Cat", "Crab", "Crocolisk", "Fox", "Gorilla", "Hyena", "Raptor", "Scorpid", "Spider", "Tallstrider", "Turtle", "Wolf"},
    effect="Increases movement speed for 15 seconds.",
    ranks={
      {rank=1, level=30, tp=15, desc="Increases movement speed by 40% for 15 seconds.", learnFrom={
        {name="Stranglethorn Tiger", level="32-33", zone="Stranglethorn Vale", npcID=682, mapID=1434, x=42.9, y=15.2, family="Cat"},
        {name="Kurzen War Tiger", level="32-33", zone="Stranglethorn Vale", npcID=976, mapID=1434, x=45.9, y=10.0, family="Cat"},
        {name="Bonepaw Hyena", level="33-35", zone="Desolace", npcID=4688, mapID=1443, x=53.8, y=39.0, family="Hyena"},
        {name="Scarlet Tracking Hound", level="33-34", zone="Scarlet Monastery (Dungeon)", npcID=4304, family="Hyena"},
        {name="Spot", level="35", zone="Dustwallow Marsh", npcID=4950, mapID=1445, x=68.0, y=46.8, family="Wolf"},
        {name="Crag Coyote", level="35-36", zone="Badlands", npcID=2727, mapID=1418, x=51.0, y=38.1, family="Wolf"},
        {name="Swamp Jaguar", level="36-37", zone="Swamp of Sorrows", npcID=767, mapID=1435, x=33.2, y=43.2, family="Cat"},
        {name="Broken Tooth", level="37", zone="Badlands", npcID=2850, mapID=1418, x=59.7, y=26.9, family="Cat"},
        {name="Magram Bonepaw", level="37-38", zone="Desolace", npcID=4662, mapID=1443, x=70.4, y=73.2, family="Hyena"},
        {name="Sin'Dall", level="37", zone="Stranglethorn Vale", npcID=729, mapID=1434, x=32.2, y=17.4, family="Cat"},
        {name="Feral Crag Coyote", level="37-38", zone="Badlands", npcID=2728, mapID=1418, x=56.7, y=61.0, family="Wolf"},
        {name="Elder Crag Coyote", level="39-40", zone="Badlands", npcID=2729, mapID=1418, x=27.4, y=62.2, family="Wolf"},
      }},
      {rank=2, level=40, tp=20, desc="Increases movement speed by 60% for 15 seconds.", learnFrom={
        {name="Bhag'thera", level="40", zone="Stranglethorn Vale", npcID=728, mapID=1434, x=49.6, y=24.0, family="Cat"},
        {name="Longtooth Runner", level="40-41", zone="Feralas", npcID=5286, mapID=1444, x=64.5, y=48.6, family="Wolf"},
        {name="Ridge Stalker Patriarch", level="40-41", zone="Badlands", npcID=2734, mapID=1418, x=20.3, y=62.0, family="Cat"},
        {name="Starving Blisterpaw", level="41-42", zone="Tanaris", npcID=5425, mapID=1446, x=49.2, y=28.3, family="Hyena"},
        {name="Rabid Crag Coyote", level="42-43", zone="Badlands", npcID=2730, mapID=1418, x=70.3, y=33.6, family="Wolf"},
        {name="Elder Shadowmaw Panther", level="42-43", zone="Stranglethorn Vale", npcID=1713, mapID=1434, x=35.6, y=57.8, family="Cat"},
        {name="Old Cliff Jumper", level="42", zone="The Hinterlands", npcID=8211, mapID=1425, x=11.9, y=53.7, family="Wolf"},
        {name="Murderous Blisterpaw", level="43", zone="Tanaris", npcID=8208, mapID=1446, x=52.3, y=33.3, family="Hyena"},
        {name="King Bangalash", level="43", zone="Stranglethorn Vale", npcID=731, mapID=1434, x=38.2, y=35.6, family="Cat"},
        {name="Blisterpaw Hyena", level="44-45", zone="Tanaris", npcID=5426, mapID=1446, x=52.3, y=48.7, family="Hyena"},
        {name="Silvermane Stalker", level="47-48", zone="The Hinterlands", npcID=2926, mapID=1425, x=65.4, y=53.3, family="Wolf"},
        {name="Rabid Blisterpaw", level="47-48", zone="Tanaris", npcID=5427, mapID=1446, x=40.2, y=63.9, family="Hyena"},
      }},
      {rank=3, level=50, tp=25, desc="Increases movement speed by 80% for 15 seconds.", learnFrom={
        {name="Grunter", level="50", zone="Blasted Lands", npcID=8303, mapID=1419, x=56.8, y=28.6, family="Boar"},
        {name="Vilebranch Raiding Wolf", level="50-51", zone="The Hinterlands", npcID=2681, mapID=1425, x=60.0, y=76.0, family="Wolf"},
        {name="Ravage", level="51", zone="Blasted Lands", npcID=8300, mapID=1419, x=50.2, y=36.9, family="Hyena"},
        {name="Scarshield Worg", level="53-54", zone="Blackrock Spire (Dungeon)", npcID=9416, family="Wolf"},
        {name="Blackrock Worg", level="54-55", zone="Burning Steppes", npcID=7055, mapID=1428, x=48.7, y=57.6, family="Wolf"},
        {name="Bloodaxe Worg", level="56-57", zone="Blackrock Spire (Dungeon)", npcID=9696, family="Wolf"},
        {name="Rak'Shiri", level="57", zone="Winterspring", npcID=10200, mapID=1452, x=51.1, y=10.8, family="Cat"},
        {name="Frostsaber Huntress", level="58-59", zone="Winterspring", npcID=7433, mapID=1452, x=52.0, y=12.1, family="Cat"},
        {name="Frostsaber Stalker", level="59-60", zone="Winterspring", npcID=7432, mapID=1452, x=52.1, y=15.2, family="Cat"},
        {name="Zulian Panther", level="60", zone="Zul'Gurub (Raid)", npcID=11365, family="Cat"},
      }},
    }},
  {name="Demoralizing Screech", icon="ability_hunter_pet_bat", source="wild", families={"Carrion Bird"},
    effect="Blasts a single enemy for damage and lowers the melee attack power of all enemies in melee range. Effect lasts 4 sec.",
    ranks={
      {rank=1, level=8, tp=10, desc="Blasts a single enemy for 7 to 9 damage and lowers the melee attack power of all enemies in melee range by 63. Effect lasts 4 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=15, desc="Blasts a single enemy for 9 to 13 damage and lowers the melee attack power of all enemies in melee range by 111. Effect lasts 4 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=48, tp=20, desc="Blasts a single enemy for 21 to 27 damage and lowers the melee attack power of all enemies in melee range by 164. Effect lasts 4 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=56, tp=25, desc="Blasts a single enemy for 24 to 42 damage and lowers the melee attack power of all enemies in melee range by 204. Effect lasts 4 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Dismember", icon="ability_hunter_pet_crocolisk", source="wild", families={"Crocolisk"},
    effect="Viciously bites enemy appendages for damage and reduces the effectiveness of any healing by 50% for 10 sec.",
    ranks={
      {rank=1, level=12, tp=0, desc="Viciously bites enemy appendages for 11 to 13 damage and reduces the effectiveness of any healing by 50% for 10 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Viciously bites enemy appendages for 18 to 20 damage and reduces the effectiveness of any healing by 50% for 10 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Viciously bites enemy appendages for 26 to 30 damage and reduces the effectiveness of any healing by 50% for 10 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Viciously bites enemy appendages for 39 to 45 damage and reduces the effectiveness of any healing by 50% for 10 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Viciously bites enemy appendages for 50 to 58 damage and reduces the effectiveness of any healing by 50% for 10 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Dive", icon="spell_shadow_burningspirit", source="wild", families={"Bat", "Bird of Prey", "Carrion Bird", "Wind Serpent"},
    effect="Increases movement speed for 15 seconds.",
    ranks={
      {rank=1, level=30, tp=15, desc="Increases movement speed by 40% for 15 seconds.", learnFrom={
        {name="Kraul Bat", level="30-31", zone="Razorfen Kraul (Dungeon)", npcID=4538, family="Bat"},
        {name="Young Mesa Buzzard", level="31-32", zone="Arathi Highlands", npcID=2578, mapID=1417, x=50.2, y=42.0, family="Carrion Bird"},
        {name="Greater Kraul Bat", level="32", zone="Razorfen Kraul (Dungeon)", npcID=4539, family="Bat"},
        {name="Mesa Buzzard", level="34-35", zone="Arathi Highlands", npcID=2579, mapID=1417, x=34.1, y=61.9, family="Carrion Bird"},
        {name="Wayward Buzzard", level="35-37", zone="Badlands", npcID=6013, family="Carrion Bird"},
        {name="Dread Flyer", level="36-37", zone="Desolace", npcID=4693, mapID=1443, x=53.6, y=49.3, family="Carrion Bird"},
        {name="Shrike Bat", level="38-39", zone="Uldaman (Dungeon)", npcID=4861, family="Bat"},
      }},
      {rank=2, level=40, tp=20, desc="Increases movement speed by 60% for 15 seconds.", learnFrom={
        {name="Vale Screecher", level="41-43", zone="Feralas", npcID=5307, mapID=1444, x=58.2, y=57.8, family="Wind Serpent"},
        {name="Roc", level="42-43", zone="Tanaris", npcID=5428, mapID=1446, x=49.9, y=31.2, family="Carrion Bird"},
        {name="Fire Roc", level="43-45", zone="Tanaris", npcID=5429, mapID=1446, x=48.3, y=44.2, family="Carrion Bird"},
        {name="Rogue Vale Screecher", level="44-46", zone="Feralas", npcID=5308, mapID=1444, x=46.5, y=47.6, family="Wind Serpent"},
        {name="Greater Firebird", level="46", zone="Tanaris", npcID=8207, mapID=1446, x=49.4, y=36.0, family="Carrion Bird"},
        {name="Searing Roc", level="47-49", zone="Tanaris", npcID=5430, mapID=1446, x=39.6, y=64.6, family="Carrion Bird"},
        {name="Ironbeak Owl", level="48-49", zone="Felwood", npcID=7097, mapID=1448, x=49.0, y=81.5, family="Bird of Prey"},
        {name="Arash-ethis", level="49", zone="Feralas", npcID=5349, mapID=1444, x=44.8, y=25.0, family="Wind Serpent"},
      }},
      {rank=3, level=50, tp=25, desc="Increases movement speed by 80% for 15 seconds.", learnFrom={
        {name="Ironbeak Hunter", level="50-51", zone="Felwood", npcID=7099, mapID=1448, x=41.8, y=50.1, family="Bird of Prey"},
        {name="Dark Screecher", level="50-52", zone="Blackrock Depths (Dungeon)", npcID=8927, family="Bat"},
        {name="Carrion Vulture", level="50-52", zone="Western Plaguelands", npcID=1809, mapID=1422, x=29.9, y=54.7, family="Carrion Bird"},
        {name="Spawn of Hakkar", level="51", zone="The Temple of Atal'Hakkar (Dungeon)", npcID=5708, family="Wind Serpent"},
        {name="Spiteflayer", level="52", zone="Blasted Lands", npcID=8299, mapID=1419, x=60.2, y=37.6, family="Carrion Bird"},
        {name="Ironbeak Screecher", level="52-53", zone="Felwood", npcID=7098, mapID=1448, x=56.4, y=21.4, family="Bird of Prey"},
        {name="Olm the Wise", level="52", zone="Felwood", npcID=14343, mapID=1448, x=50.2, y=32.8, family="Bird of Prey"},
        {name="Plaguebat", level="53-55", zone="Eastern Plaguelands", npcID=8600, mapID=1423, x=30.0, y=64.2, family="Bat"},
        {name="Winterspring Owl", level="54-56", zone="Winterspring", npcID=7455, mapID=1452, x=59.2, y=35.5, family="Bird of Prey"},
        {name="Zaricotl", level="55", zone="Badlands", npcID=2931, mapID=1418, x=35.4, y=66.5, family="Carrion Bird"},
        {name="Winterspring Screecher", level="57-59", zone="Winterspring", npcID=7456, mapID=1452, x=62.4, y=53.0, family="Bird of Prey"},
      }},
    }},
  {name="Dust Cloud", icon="spell_nature_sleep", source="wild", families={"Tallstrider"},
    effect="Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor for 30 sec.",
    ranks={
      {rank=1, level=12, tp=0, desc="Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor by 65 for 30 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor by 175 for 30 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor by 285 for 30 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor by 395 for 30 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Your tallstrider kicks up an abrasive cloud of dust, reducing the target's Armor by 505 for 30 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Faster Attack", icon="ability_eyeoftheowl", source="trainer", families={"All families"},
    effect="Increases attack speed.",
    ranks={
      {rank=1, level=1, tp=0, desc="Increases attack speed by 17%.", learnFrom={
      }},
      {rank=2, level=1, tp=0, desc="Increases attack speed by 25%.", learnFrom={
      }},
      {rank=3, level=1, tp=0, desc="Increases attack speed by 33%.", learnFrom={
      }},
      {rank=4, level=1, tp=0, desc="Increases attack speed by 43%.", learnFrom={
      }},
      {rank=5, level=1, tp=0, desc="Increases attack speed by 54%.", learnFrom={
      }},
      {rank=6, level=1, tp=0, desc="Increases attack speed by 67%.", learnFrom={
      }},
      {rank=7, level=1, tp=0, desc="Increases attack speed by 100%.", learnFrom={
      }},
    }},
  {name="Fire Resistance", icon="spell_fire_firearmor", source="trainer", families={"All families"},
    effect="Increases Fire Resistance.",
    ranks={
      {rank=1, level=20, tp=5, desc="Increases Fire Resistance by 30.", learnFrom={
      }},
      {rank=2, level=30, tp=15, desc="Increases Fire Resistance by 60.", learnFrom={
      }},
      {rank=3, level=40, tp=45, desc="Increases Fire Resistance by 90.", learnFrom={
      }},
      {rank=4, level=50, tp=90, desc="Increases Fire Resistance by 120.", learnFrom={
      }},
    }},
  {name="Frost Resistance", icon="spell_frost_frostward", source="trainer", families={"All families"},
    effect="Increases Frost Resistance.",
    ranks={
      {rank=1, level=20, tp=5, desc="Increases Frost Resistance by 30.", learnFrom={
      }},
      {rank=2, level=30, tp=15, desc="Increases Frost Resistance by 60.", learnFrom={
      }},
      {rank=3, level=40, tp=45, desc="Increases Frost Resistance by 90.", learnFrom={
      }},
      {rank=4, level=50, tp=90, desc="Increases Frost Resistance by 120.", learnFrom={
      }},
    }},
  {name="Furious Howl", icon="ability_hunter_pet_wolf", source="wild", families={"Wolf"},
    effect="The wolf howls, increasing the melee attack power of all party members within 15 yards.  Lasts 1 min.",
    ranks={
      {rank=1, level=10, tp=10, desc="The wolf howls, increasing the melee attack power of all party members within 15 yards by 139.  Lasts 1 min.", learnFrom={
        {name="Prairie Wolf Alpha", level="9-10", zone="Mulgore", npcID=2960, mapID=1412, x=52.2, y=41.5, family="Wolf"},
        {name="Worg", level="10-11", zone="Silverpine Forest", npcID=1765, mapID=1421, x=63.8, y=11.1, family="Wolf"},
        {name="Coyote Packleader", level="11-12", zone="Westfall", npcID=833, mapID=1436, x=41.7, y=26.7, family="Wolf"},
        {name="Mist Howler", level="22", zone="Ashenvale", npcID=10644, mapID=1440, x=26.8, y=18.4, family="Wolf"},
      }},
      {rank=2, level=24, tp=15, desc="The wolf howls, increasing the melee attack power of all party members within 15 yards by 51 to 62.  Lasts 1 min.", learnFrom={
        {name="Black Ravager Mastiff", level="25-26", zone="Duskwood", npcID=1258, mapID=1431, x=67.2, y=35.1, family="Wolf"},
        {name="Ghostpaw Alpha", level="27-28", zone="Ashenvale", npcID=3825, mapID=1440, x=71.9, y=58.0, family="Wolf"},
        {name="Elder Crag Coyote", level="39-40", zone="Badlands", npcID=2729, mapID=1418, x=27.4, y=62.2, family="Wolf"},
        {name="Longtooth Howler", level="43-44", zone="Feralas", npcID=5287, mapID=1444, x=62.0, y=51.1, family="Wolf"},
        {name="Silvermane Howler", level="45-46", zone="The Hinterlands", npcID=2925, mapID=1425, x=43.0, y=53.7, family="Wolf"},
      }},
      {rank=3, level=40, tp=20, desc="The wolf howls, increasing the melee attack power of all party members within 15 yards by 115.  Lasts 1 min.", learnFrom={
        {name="Longtooth Runner", level="40-41", zone="Feralas", npcID=5286, mapID=1444, x=64.5, y=48.6, family="Wolf"},
        {name="Snarler", level="42", zone="Feralas", npcID=5356, mapID=1444, x=80.2, y=39.6, family="Wolf"},
        {name="Silvermane Wolf", level="43-44", zone="The Hinterlands", npcID=2924, mapID=1425, x=32.1, y=55.3, family="Wolf"},
        {name="Felpaw Wolf", level="47-48", zone="Felwood", npcID=8959, mapID=1448, x=49.1, y=83.2, family="Wolf"},
        {name="Death Howl", level="49", zone="Felwood", npcID=14339, mapID=1448, x=50.0, y=77.1, family="Wolf"},
      }},
      {rank=4, level=56, tp=25, desc="The wolf howls, increasing the melee attack power of all party members within 15 yards by 45 to 57.  Lasts 1 min.", learnFrom={
        {name="Bloodaxe Worg", level="56-57", zone="Blackrock Spire (Dungeon)", npcID=9696, family="Wolf"},
      }},
    }},
  {name="Great Stamina", icon="spell_nature_unyeildingstamina", source="trainer", families={"All families"},
    effect="Stamina increased.",
    ranks={
      {rank=1, level=1, tp=5, desc="Stamina increased by 3.", learnFrom={
      }},
      {rank=2, level=12, tp=10, desc="Stamina increased by 5.", learnFrom={
      }},
      {rank=3, level=18, tp=15, desc="Stamina increased by 7.", learnFrom={
      }},
      {rank=4, level=24, tp=25, desc="Stamina increased by 10.", learnFrom={
      }},
      {rank=5, level=30, tp=50, desc="Stamina increased by 13.", learnFrom={
      }},
      {rank=6, level=36, tp=75, desc="Stamina increased by 17.", learnFrom={
      }},
      {rank=7, level=42, tp=100, desc="Stamina increased by 21.", learnFrom={
      }},
      {rank=8, level=48, tp=125, desc="Stamina increased by 26.", learnFrom={
      }},
      {rank=9, level=54, tp=150, desc="Stamina increased by 32.", learnFrom={
      }},
      {rank=10, level=60, tp=185, desc="Stamina increased by 40.", learnFrom={
      }},
    }},
  {name="Growl", icon="ability_physical_taunt", source="trainer", families={"All families"},
    effect="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.",
    ranks={
      {rank=1, level=1, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
      {rank=2, level=10, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
      {rank=3, level=20, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
      {rank=4, level=30, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
      {rank=5, level=40, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
      {rank=6, level=50, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
      {rank=7, level=60, tp=0, desc="Taunt the target, increasing the likelihood the creature will focus attacks on your pet.", learnFrom={
      }},
    }},
  {name="Lava Breath", icon="spell_fire_windsofwoe", source="wild", families={"Core Hound"},
    effect="Breathes molten lava at 2 nearby enemies, instantly dealing Fire damage and reducing the target's casting speed by 25% for 10 sec.",
    ranks={
      {rank=1, level=48, tp=0, desc="Breathes molten lava at 2 nearby enemies, instantly dealing 97 to 109 Fire damage and reducing the target's casting speed by 25% for 10 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=48, tp=0, desc="Breathes molten lava at 2 nearby enemies, instantly dealing 123 to 137 Fire damage and reducing the target's casting speed by 25% for 10 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Lightning Breath", icon="spell_nature_lightning", source="wild", families={"Wind Serpent"},
    effect="Breathes lightning, instantly dealing Nature damage to a single target.",
    ranks={
      {rank=1, level=1, tp=1, desc="Breathes lightning, instantly dealing 8 to 10 Nature damage to a single target.", noSource=true, learnFrom={
      }},
      {rank=2, level=12, tp=5, desc="Breathes lightning, instantly dealing 20 to 22 Nature damage to a single target.", learnFrom={
        {name="Deviate Coiler", level="15-16", zone="Wailing Caverns (Dungeon)", npcID=3630, mapID=1413, x=46.2, y=34.7, family="Wind Serpent"},
        {name="Deviate Stinglash", level="16-17", zone="Wailing Caverns (Dungeon)", npcID=3631, mapID=1413, x=48.2, y=34.4, family="Wind Serpent"},
        {name="Thunderhawk Hatchling", level="18-20", zone="The Barrens", npcID=3247, mapID=1413, x=46.8, y=51.0, family="Wind Serpent"},
        {name="Deviate Dreadfang", level="20-21", zone="Wailing Caverns (Dungeon)", npcID=5056, family="Wind Serpent"},
        {name="Deviate Venomwing", level="20-21", zone="Wailing Caverns (Dungeon)", npcID=5756, family="Wind Serpent"},
        {name="Thunderhawk Cloudscraper", level="20-22", zone="The Barrens", npcID=3424, mapID=1413, x=46.7, y=61.5, family="Wind Serpent"},
        {name="Greater Thunderhawk", level="23-24", zone="The Barrens", npcID=3249, mapID=1413, x=46.9, y=76.2, family="Wind Serpent"},
      }},
      {rank=3, level=24, tp=10, desc="Breathes lightning, instantly dealing 32 to 36 Nature damage to a single target.", learnFrom={
        {name="Washte Pawne", level="25", zone="The Barrens", npcID=3472, mapID=1413, x=44.8, y=78.9, family="Wind Serpent"},
        {name="Cloud Serpent", level="25-26", zone="Thousand Needles", npcID=4117, mapID=1441, x=40.5, y=50.2, family="Wind Serpent"},
        {name="Venomous Cloud Serpent", level="26-28", zone="Thousand Needles", npcID=4118, mapID=1441, x=28.0, y=42.2, family="Wind Serpent"},
        {name="Elder Cloud Serpent", level="27-29", zone="Thousand Needles", npcID=4119, mapID=1441, x=51.6, y=44.0, family="Wind Serpent"},
      }},
      {rank=4, level=36, tp=15, desc="Breathes lightning, instantly dealing 46 to 54 Nature damage to a single target.", learnFrom={
        {name="Vale Screecher", level="41-43", zone="Feralas", npcID=5307, mapID=1444, x=58.2, y=57.8, family="Wind Serpent"},
        {name="Rogue Vale Screecher", level="44-46", zone="Feralas", npcID=5308, mapID=1444, x=46.5, y=47.6, family="Wind Serpent"},
      }},
      {rank=5, level=48, tp=20, desc="Breathes lightning, instantly dealing 71 to 81 Nature damage to a single target.", learnFrom={
        {name="Hakkari Sapper", level="49-50", zone="The Temple of Atal'Hakkar (Dungeon)", npcID=8336, family="Wind Serpent"},
        {name="Hakkari Frostwing", level="49-50", zone="The Temple of Atal'Hakkar (Dungeon)", npcID=5291, family="Wind Serpent"},
        {name="Arash-ethis", level="49", zone="Feralas", npcID=5349, mapID=1444, x=44.8, y=25.0, family="Wind Serpent"},
        {name="Spawn of Hakkar", level="51", zone="The Temple of Atal'Hakkar (Dungeon)", npcID=5708, family="Wind Serpent"},
      }},
      {rank=6, level=60, tp=25, desc="Breathes lightning, instantly dealing 86 to 98 Nature damage to a single target.", learnFrom={
        {name="Son of Hakkar", level="60", zone="Zul'Gurub (Raid)", npcID=11357, family="Wind Serpent"},
      }},
    }},
  {name="Mine!", icon="spell_nature_natureswrath", source="wild", families={"Bird of Prey"},
    effect="Grabs an enemy's weapon with its talons, causing damage and disarming them for 4 sec.",
    ranks={
      {rank=1, level=10, tp=0, desc="Grabs an enemy's weapon with its talons, causing 10 to 12 damage and disarming them for 4 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=20, tp=0, desc="Grabs an enemy's weapon with its talons, causing 14 to 16 damage and disarming them for 4 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=30, tp=0, desc="Grabs an enemy's weapon with its talons, causing 20 to 24 damage and disarming them for 4 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=40, tp=0, desc="Grabs an enemy's weapon with its talons, causing 33 to 37 damage and disarming them for 4 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=50, tp=0, desc="Grabs an enemy's weapon with its talons, causing 41 to 47 damage and disarming them for 4 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Natural Armor", icon="spell_nature_spiritarmor", source="trainer", families={"All families"},
    effect="Armor increased.",
    ranks={
      {rank=1, level=1, tp=1, desc="Armor increased by 50.", learnFrom={
      }},
      {rank=2, level=12, tp=5, desc="Armor increased by 100.", learnFrom={
      }},
      {rank=3, level=18, tp=10, desc="Armor increased by 160.", learnFrom={
      }},
      {rank=4, level=24, tp=15, desc="Armor increased by 240.", learnFrom={
      }},
      {rank=5, level=30, tp=25, desc="Armor increased by 330.", learnFrom={
      }},
      {rank=6, level=36, tp=50, desc="Armor increased by 430.", learnFrom={
      }},
      {rank=7, level=42, tp=75, desc="Armor increased by 550.", learnFrom={
      }},
      {rank=8, level=48, tp=100, desc="Armor increased by 675.", learnFrom={
      }},
      {rank=9, level=54, tp=125, desc="Armor increased by 810.", learnFrom={
      }},
      {rank=10, level=60, tp=150, desc="Armor increased by 1000.", learnFrom={
      }},
    }},
  {name="Nature Resistance", icon="spell_nature_resistnature", source="trainer", families={"All families"},
    effect="Increases Nature Resistance.",
    ranks={
      {rank=1, level=20, tp=5, desc="Increases Nature Resistance by 30.", learnFrom={
      }},
      {rank=2, level=30, tp=15, desc="Increases Nature Resistance by 60.", learnFrom={
      }},
      {rank=3, level=40, tp=45, desc="Increases Nature Resistance by 90.", learnFrom={
      }},
      {rank=4, level=50, tp=90, desc="Increases Nature Resistance by 120.", learnFrom={
      }},
    }},
  {name="Pinch", icon="ability_hunter_pet_crab", source="wild", families={"Crab"},
    effect="Pinches an enemy's legs for damage and reduces movement speed by 50% for 9 sec.",
    ranks={
      {rank=1, level=12, tp=0, desc="Pinches an enemy's legs for 19 to 21 damage and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Pinches an enemy's legs for 32 to 36 damage and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Pinches an enemy's legs for 41 to 47 damage and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Pinches an enemy's legs for 68 to 78 damage and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Pinches an enemy's legs for 88 to 102 damage and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Prowl", icon="ability_druid_supriseattack", source="wild", families={"Cat"},
    effect="Puts your pet in stealth mode, but slows its movement speed. The first attack from stealth receives a bonus to damage. Lasts until cancelled.",
    ranks={
      {rank=1, level=30, tp=15, desc="Puts your pet in stealth mode, but slows its movement speed by 50%. The first attack from stealth receives a 20% bonus to damage. Lasts until cancelled.", learnFrom={
        {name="Mountain Lion", level="32-33", zone="Alterac Mountains", npcID=2406, mapID=1416, x=42.8, y=78.5, family="Cat"},
        {name="Ridge Stalker", level="36-37", zone="Badlands", npcID=2731, mapID=1418, x=46.2, y=37.6, family="Cat"},
        {name="Shadowmaw Panther", level="37-38", zone="Stranglethorn Vale", npcID=684, mapID=1434, x=40.3, y=31.7, family="Cat"},
        {name="Shadow Panther", level="39-40", zone="Swamp of Sorrows", npcID=768, mapID=1435, x=87.8, y=31.4, family="Cat"},
      }},
      {rank=2, level=40, tp=20, desc="Puts your pet in stealth mode, but slows its movement speed by 45%. The first attack from stealth receives a 35% bonus to damage. Lasts until cancelled.", learnFrom={
        {name="Ridge Stalker Patriarch", level="40-41", zone="Badlands", npcID=2734, mapID=1418, x=20.3, y=62.0, family="Cat"},
        {name="Elder Shadowmaw Panther", level="42-43", zone="Stranglethorn Vale", npcID=1713, mapID=1434, x=35.6, y=57.8, family="Cat"},
      }},
      {rank=3, level=50, tp=25, desc="Puts your pet in stealth mode, but slows its movement speed by 40%. The first attack from stealth receives a 50% bonus to damage. Lasts until cancelled.", learnFrom={
        {name="Jaguero Stalker", level="50", zone="Stranglethorn Vale", npcID=2522, mapID=1434, x=37.5, y=82.8, family="Cat"},
        {name="Frostsaber Stalker", level="59-60", zone="Winterspring", npcID=7432, mapID=1452, x=52.1, y=15.2, family="Cat"},
      }},
    }},
  {name="Savage Rend", icon="ability_hunter_pet_raptor", source="wild", families={"Raptor"},
    effect="Slash an enemy with razor talons, causing the target to Bleed for damage over 18 sec.",
    ranks={
      {rank=1, level=12, tp=0, desc="Slash an enemy with razor talons, causing the target to Bleed for 30 damage over 18 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Slash an enemy with razor talons, causing the target to Bleed for 54 damage over 18 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Slash an enemy with razor talons, causing the target to Bleed for 72 damage over 18 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Slash an enemy with razor talons, causing the target to Bleed for 120 damage over 18 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Slash an enemy with razor talons, causing the target to Bleed for 156 damage over 18 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Scorpid Poison", icon="ability_poisonsting", source="wild", families={"Scorpid"},
    effect="Inflicts Nature damage over 10 sec. Effect can stack up to 5 times on a single target.",
    ranks={
      {rank=1, level=8, tp=10, desc="Inflicts 5 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.", learnFrom={
        {name="Venomtail Scorpid", level="9-10", zone="Durotar", npcID=3127, mapID=1411, x=36.8, y=27.0, family="Scorpid"},
        {name="Corrupted Scorpid", level="10-11", zone="Durotar", npcID=3226, mapID=1411, x=36.6, y=29.3, family="Scorpid"},
        {name="Death Flayer", level="11", zone="Durotar", npcID=5823, mapID=1411, x=36.5, y=49.7, family="Scorpid"},
        {name="Silithid Creeper", level="20-21", zone="The Barrens", npcID=3250, mapID=1413, x=45.2, y=70.2, family="Scorpid"},
        {name="Silithid Swarmer", level="21-22", zone="The Barrens", npcID=3252, mapID=1413, x=44.9, y=69.7, family="Scorpid"},
      }},
      {rank=2, level=24, tp=15, desc="Inflicts 10 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.", learnFrom={
        {name="Scorpashi Snapper", level="30-31", zone="Desolace", npcID=4696, mapID=1443, x=65.5, y=27.9, family="Scorpid"},
        {name="Scorpid Reaver", level="31-32", zone="Thousand Needles", npcID=4140, mapID=1441, x=73.9, y=61.0, family="Scorpid"},
        {name="Scorpid Terror", level="33-34", zone="Thousand Needles", npcID=4139, mapID=1441, x=82.8, y=79.7, family="Scorpid"},
        {name="Cleft Scorpid", level="35-36", zone="Uldaman (Dungeon)", npcID=7078, family="Scorpid"},
        {name="Vile Sting", level="35", zone="Thousand Needles", npcID=5937, mapID=1441, x=70.5, y=72.9, family="Scorpid"},
        {name="Scorpashi Venomlash", level="38-39", zone="Desolace", npcID=4699, mapID=1443, x=55.3, y=83.2, family="Scorpid"},
      }},
      {rank=3, level=40, tp=20, desc="Inflicts 20 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.", learnFrom={
        {name="Scorpid Hunter", level="40-41", zone="Tanaris", npcID=5422, mapID=1446, x=54.6, y=29.9, family="Scorpid"},
        {name="Deadly Cleft Scorpid", level="42-43", zone="Uldaman (Dungeon)", npcID=7405, family="Scorpid"},
        {name="Scorpid Tail Lasher", level="43-44", zone="Tanaris", npcID=5423, mapID=1446, x=50.2, y=39.4, family="Scorpid"},
        {name="Scorpid Dunestalker", level="46-47", zone="Tanaris", npcID=5424, mapID=1446, x=43.7, y=57.6, family="Scorpid"},
        {name="Scorpid Duneburrower", level="46-47", zone="Tanaris", npcID=7803, family="Scorpid"},
        {name="Deep Stinger", level="50-52", zone="Blackrock Depths (Dungeon)", npcID=8926, family="Scorpid"},
        {name="Scorpok Stinger", level="50-51", zone="Blasted Lands", npcID=5988, mapID=1419, x=49.8, y=22.0, family="Scorpid"},
        {name="Venomtip Scorpid", level="52-53", zone="Burning Steppes", npcID=9691, mapID=1428, x=91.9, y=44.3, family="Scorpid"},
        {name="Deathlash Scorpid", level="54-55", zone="Burning Steppes", npcID=9695, mapID=1428, x=71.0, y=45.2, family="Scorpid"},
        {name="Stonelash Scorpid", level="54-55", zone="Silithus", npcID=11735, mapID=1451, x=56.1, y=30.2, family="Scorpid"},
      }},
      {rank=4, level=56, tp=25, desc="Inflicts 25 Nature damage over 10 sec. Effect can stack up to 5 times on a single target.", learnFrom={
        {name="Firetail Scorpid", level="56-57", zone="Burning Steppes", npcID=9698, mapID=1428, x=27.8, y=57.8, family="Scorpid"},
        {name="Krellack", level="56", zone="Silithus", npcID=14476, mapID=1451, x=63.2, y=16.7, family="Scorpid"},
        {name="Stonelash Pincer", level="56-57", zone="Silithus", npcID=11736, mapID=1451, x=40.4, y=54.0, family="Scorpid"},
        {name="Stonelash Flayer", level="58-59", zone="Silithus", npcID=11737, mapID=1451, x=40.9, y=80.1, family="Scorpid"},
      }},
    }},
  {name="Shadow Resistance", icon="spell_shadow_antishadow", source="trainer", families={"All families"},
    effect="Increases Shadow Resistance.",
    ranks={
      {rank=1, level=20, tp=5, desc="Increases Shadow Resistance by 30.", learnFrom={
      }},
      {rank=2, level=30, tp=15, desc="Increases Shadow Resistance by 60.", learnFrom={
      }},
      {rank=3, level=40, tp=45, desc="Increases Shadow Resistance by 90.", learnFrom={
      }},
      {rank=4, level=40, tp=90, desc="Increases Shadow Resistance by 120.", learnFrom={
      }},
    }},
  {name="Shell Shield", icon="ability_hunter_pet_turtle", source="wild", families={"Turtle"},
    effect="Reduces all damage your pet takes by 50% and increases the time between your pet's attacks by 60%, but deals more damage with each attack. Lasts 12 sec.",
    ranks={
      {rank=1, level=20, tp=15, desc="Reduces all damage your pet takes by 50% and increases the time between your pet's attacks by 60%, but deals more damage with each attack. Lasts 12 sec.", learnFrom={
        {name="Kresh", level="20", zone="Wailing Caverns (Dungeon)", npcID=3653, family="Turtle"},
        {name="Aku'mai Fisher", level="23-24", zone="Blackfathom Deeps (Dungeon)", npcID=4824, family="Turtle"},
        {name="Ghamoo-ra", level="25", zone="Blackfathom Deeps (Dungeon)", npcID=4887, family="Turtle"},
        {name="Aku'mai Snapjaw", level="26-27", zone="Blackfathom Deeps (Dungeon)", npcID=4825, family="Turtle"},
        {name="Snapjaw", level="30-31", zone="Hillsbrad Foothills", npcID=2408, mapID=1424, x=66.1, y=38.2, family="Turtle"},
        {name="Cranky Benj", level="32", zone="Alterac Mountains", npcID=14223, mapID=1416, x=37.3, y=19.8, family="Turtle"},
      }},
    }},
  {name="Slower Attack", icon="ability_eyeoftheowl", source="trainer", families={"All families"},
    effect="Decreases attack speed.",
    ranks={
      {rank=2, level=1, tp=0, desc="Decreases attack speed by 20%.", learnFrom={
      }},
      {rank=3, level=1, tp=0, desc="Decreases attack speed by 26%.", learnFrom={
      }},
    }},
  {name="Swipe", icon="inv_misc_monsterclaw_03", source="wild", families={"Bear"},
    effect="Swipe 3 nearby enemies, inflicting damage.",
    ranks={
      {rank=1, level=12, tp=0, desc="Swipe 3 nearby enemies, inflicting 4 damage.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Swipe 3 nearby enemies, inflicting 8 to 10 damage.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Swipe 3 nearby enemies, inflicting 11 to 13 damage.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Swipe 3 nearby enemies, inflicting 16 to 18 damage.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Swipe 3 nearby enemies, inflicting 20 to 22 damage.", noSource=true, learnFrom={
      }},
    }},
  {name="Tendon Rip", icon="ability_hunter_pet_hyena", source="wild", families={"Hyena"},
    effect="Tears at an enemy's legs for damage over 9 sec and reduces movement speed by 50% for 9 sec.",
    ranks={
      {rank=1, level=12, tp=0, desc="Tears at an enemy's legs for 12 damage over 9 sec and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Tears at an enemy's legs for 21 damage over 9 sec and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Tears at an enemy's legs for 27 damage over 9 sec and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Tears at an enemy's legs for 45 damage over 9 sec and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Tears at an enemy's legs for 60 damage over 9 sec and reduces movement speed by 50% for 9 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Thunderstomp", icon="ability_hunter_pet_gorilla", source="wild", families={"Gorilla"},
    effect="Shakes the ground with thundering force, doing Nature damage to all enemies within 8 yards.",
    ranks={
      {rank=1, level=30, tp=15, desc="Shakes the ground with thundering force, doing 53 to 61 Nature damage to all enemies within 8 yards.", learnFrom={
        {name="Mistvale Gorilla", level="32-33", zone="Stranglethorn Vale", npcID=1108, mapID=1434, x=38.0, y=17.6, family="Gorilla"},
        {name="Jungle Thunderer", level="37-38", zone="Stranglethorn Vale", npcID=1114, mapID=1434, x=44.1, y=32.3, family="Gorilla"},
      }},
      {rank=2, level=40, tp=20, desc="Shakes the ground with thundering force, doing 69 to 79 Nature damage to all enemies within 8 yards.", learnFrom={
        {name="Elder Mistvale Gorilla", level="40-41", zone="Stranglethorn Vale", npcID=1557, mapID=1434, x=33.0, y=64.8, family="Gorilla"},
        {name="Groddoc Thunderer", level="49-50", zone="Feralas", npcID=5262, mapID=1444, x=43.9, y=23.8, family="Gorilla"},
      }},
      {rank=3, level=50, tp=25, desc="Shakes the ground with thundering force, doing 92 to 106 Nature damage to all enemies within 8 yards.", learnFrom={
        {name="Un'Goro Thunderer", level="52-53", zone="Un'Goro Crater", npcID=6516, mapID=1449, x=65.8, y=15.6, family="Gorilla"},
        {name="U'cha", level="55", zone="Un'Goro Crater", npcID=9622, mapID=1449, x=68.1, y=12.6, family="Gorilla"},
      }},
      {rank=4, level=60, tp=0, desc="Shakes the ground with thundering force, doing 122 to 142 Nature damage to all enemies within 8 yards.", noSource=true, learnFrom={
      }},
    }},
  {name="Trickster's Dance", icon="ability_hunter_aspectofthefox", source="wild", families={"Fox"},
    effect="Increases your pet's chance to Dodge by 50% and decreases the time between your pet's attacks by 30%. Lasts 12 sec.",
    ranks={
      {rank=1, level=20, tp=0, desc="Increases your pet's chance to Dodge by 50% and decreases the time between your pet's attacks by 30%. Lasts 12 sec.", noSource=true, learnFrom={
      }},
    }},
  {name="Web", icon="spell_nature_web", source="wild", families={"Spider"},
    effect="Entangles an enemy in a corrosive web, immobilizing them and dealing Nature damage over 4 sec.",
    ranks={
      {rank=1, level=12, tp=0, desc="Entangles an enemy in a corrosive web, immobilizing them and dealing 12 Nature damage over 4 sec.", noSource=true, learnFrom={
      }},
      {rank=2, level=24, tp=0, desc="Entangles an enemy in a corrosive web, immobilizing them and dealing 20 Nature damage over 4 sec.", noSource=true, learnFrom={
      }},
      {rank=3, level=36, tp=0, desc="Entangles an enemy in a corrosive web, immobilizing them and dealing 28 Nature damage over 4 sec.", noSource=true, learnFrom={
      }},
      {rank=4, level=48, tp=0, desc="Entangles an enemy in a corrosive web, immobilizing them and dealing 40 Nature damage over 4 sec.", noSource=true, learnFrom={
      }},
      {rank=5, level=60, tp=0, desc="Entangles an enemy in a corrosive web, immobilizing them and dealing 52 Nature damage over 4 sec.", noSource=true, learnFrom={
      }},
    }},
}

FLT.PET_RARES = {
  {name="Echeyakee", level="16", zone="The Barrens", npcID=3475, family="Cat", why="White lion skin; marked as a spawned (not always present) mob.", speed=2.0},
  {name="Humar the Pridelord", level="23", zone="The Barrens", npcID=5828, mapID=1413, x=62.0, y=33.3, family="Cat", why="Rare spawn; only tameable black lion; fast 1.3 attack speed.", speed=1.3},
  {name="Ghost Saber", level="19-20", zone="Darkshore", npcID=3619, family="Cat", why="Translucent ghostly cat summoned from cat figurines at Ruins of Mathystra; keeps its look after taming; teaches Claw 3.", speed=2.0},
  {name="Duskstalker", level="9", zone="Teldrassil", npcID=14430, mapID=1438, x=58.1, y=76.7, family="Cat", why="Rare spawned nightsaber with spotted black skin.", speed=1.4},
  {name="Broken Tooth", level="37", zone="Badlands", npcID=2850, mapID=1418, x=59.7, y=26.9, family="Cat", why="Named cat; teaches Dash 1."},
  {name="Bhag'thera", level="40", zone="Stranglethorn Vale", npcID=728, mapID=1434, x=49.6, y=24.0, family="Cat", why="Named panther; teaches Dash 2."},
  {name="Sin'Dall", level="37", zone="Stranglethorn Vale", npcID=729, mapID=1434, x=32.2, y=17.4, family="Cat", why="Named panther; teaches Dash 1."},
  {name="King Bangalash", level="43 (elite)", zone="Stranglethorn Vale", npcID=731, mapID=1434, x=38.2, y=35.6, family="Cat", why="Elite striped white tiger; teaches Claw 6 and Dash 2.", speed=1.4},
  {name="Rak'Shiri", level="57", zone="Winterspring", npcID=10200, mapID=1452, x=51.1, y=10.8, family="Cat", why="Rare aqua-colored saber cat; teaches Dash 3.", speed=1.5},
  {name="Shy-Rotam", level="60 (elite)", zone="Winterspring", npcID=10737, family="Cat", why="Elite aqua saber cat.", speed=1.5},
  {name="Sian-Rotam", level="60 (elite)", zone="Winterspring", npcID=10741, family="Cat", why="Spawned elite white lion.", speed=2.0},
  {name="Frostsaber Pride Watcher", level="59-60", zone="Winterspring", npcID=7434, mapID=1452, x=50.7, y=8.8, family="Cat", why="Only tameable lavender saber cat.", speed=1.5},
  {name="Ishamuhale", level="19", zone="The Barrens", npcID=3257, family="Raptor", why="Red raptor summoned via a quest (spawned).", speed=2.0},
  {name="Mazzranache", level="9", zone="Mulgore", npcID=3068, mapID=1412, x=49.1, y=48.7, family="Tallstrider", why="Named tallstrider; teaches Cower 1."},
  {name="Lord Condar", level="15-16", zone="Loch Modan", npcID=14268, mapID=1432, x=74.6, y=70.8, family="Carrion Bird", why="Rare red vulture.", speed=2.0},
  {name="Greater Firebird", level="46", zone="Tanaris", npcID=8207, mapID=1446, x=49.4, y=36.0, family="Carrion Bird", why="Rare red carrion bird; teaches Dive 2.", speed=2.0},
  {name="Zaricotl", level="55 (elite)", zone="Badlands", npcID=2931, mapID=1418, x=35.4, y=66.5, family="Carrion Bird", why="Rare elite red carrion bird; teaches Dive 3.", speed=2.0},
  {name="Hayoc", level="41", zone="Dustwallow Marsh", npcID=14234, mapID=1445, x=52.0, y=62.9, family="Wind Serpent", why="Rare white wind serpent.", speed=2.0},
  {name="Arash-ethis", level="49", zone="Feralas", npcID=5349, mapID=1444, x=44.8, y=25.0, family="Wind Serpent", why="Rare white wind serpent; teaches Dive 2 and Lightning Breath 5.", speed=2.0},
  {name="Kurmokk", level="42", zone="Stranglethorn Vale", npcID=14491, mapID=1434, x=38.1, y=61.1, family="Gorilla", why="Rare red gorilla.", speed=2.0},
  {name="Uhk'loc", level="52", zone="Un'Goro Crater", npcID=6585, mapID=1449, x=68.5, y=12.7, family="Gorilla", why="Rare-listed white gorilla; teaches Bite 7.", speed=2.0},
  {name="U'cha", level="55", zone="Un'Goro Crater", npcID=9622, mapID=1449, x=68.1, y=12.6, family="Gorilla", why="Named red gorilla; teaches Thunderstomp 3.", speed=2.0},
  {name="Sewer Beast", level="50", zone="Stormwind City", npcID=3581, mapID=1453, x=71.2, y=48.8, family="Crocolisk", why="Rare white crocolisk found in the Stormwind canals; teaches Bite 7.", speed=2.0},
  {name="Deadmire", level="45", zone="Dustwallow Marsh", npcID=4841, mapID=1445, x=48.8, y=56.8, family="Crocolisk", why="Named white crocolisk; teaches Bite 6.", speed=2.0},
  {name="Lupos", level="23", zone="Duskwood", npcID=521, mapID=1431, x=38.3, y=25.3, family="Wolf", why="Named wolf; teaches Bite 3."},
  {name="Old Cliff Jumper", level="42", zone="The Hinterlands", npcID=8211, mapID=1425, x=11.9, y=53.7, family="Wolf", why="Named wolf; teaches Bite 6 and Dash 2."},
  {name="Death Howl", level="49", zone="Felwood", npcID=14339, mapID=1448, x=50.0, y=77.1, family="Wolf", why="Named wolf; teaches Bite 6 and Furious Howl 3."},
  {name="Mongress", level="50", zone="Felwood", npcID=14344, mapID=1448, x=43.3, y=76.6, family="Bear", why="Named bear; teaches Claw 7."},
  {name="Olm the Wise", level="52", zone="Felwood", npcID=14343, mapID=1448, x=50.2, y=32.8, family="Bird of Prey", why="Named bird of prey; teaches Claw 7 and Dive 3."},
  {name="Rekk'tilac", level="48", zone="Searing Gorge", npcID=8277, mapID=1427, x=53.0, y=70.9, family="Spider", why="Named spider; teaches Bite 7."},
  {name="Cranky Benj", level="32", zone="Alterac Mountains", npcID=14223, mapID=1416, x=37.3, y=19.8, family="Turtle", why="Named turtle; teaches Bite 4 and Shell Shield 1."},
}
