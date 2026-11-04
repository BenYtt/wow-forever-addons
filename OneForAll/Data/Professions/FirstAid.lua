local _, FLT = ...

-- All First Aid recipes, extracted from the WoW Forever client database (build
-- 1.60.1.70205, via wago.tools DB2 exports). Recipe sources (vendors, drops,
-- quests) from QuestieDB and Wowhead Forever. Season of Discovery leftovers in the
-- client data are excluded. Fields: s=spell, i=crafted item, c=count, n=name,
-- cat=category, req=skill to learn (nil = unknown), y/g/gr=yellow/green/grey,
-- r=reagents, ri=recipe item, rn=recipe name, fav=Merchant's Favor, start=known from start.
FLT.PROFESSION_RECIPES = FLT.PROFESSION_RECIPES or {}
FLT.PROFESSION_RECIPES["First Aid"] = {
  {s=1230117, i=279968, n="First Aid Kit", q=1, cat="Camping", y=0, g=0, gr=0, r={{1251,3,"Linen Bandage"}, {159,1,"Refreshing Spring Water"}}},
  {s=3275, i=1251, n="Linen Bandage", q=1, cat="Bandages", req=1, y=30, g=45, gr=60, r={{2589,1,"Linen Cloth"}}, start=true},
  {s=3276, i=2581, n="Heavy Linen Bandage", q=1, cat="Bandages", y=50, g=75, gr=100, r={{2589,2,"Linen Cloth"}}},
  {s=1244431, i=118, n="Minor Healing Potion", q=1, cat="Healing Potions", y=55, g=75, gr=95, r={{3371,1,"Empty Vial"}, {2678,1,"Mild Spices"}, {2447,1,"Peacebloom"}}},
  {s=7934, i=6452, n="Anti-Venom", c=3, q=1, cat="Curatives", y=80, g=115, gr=150, r={{1475,1,"Small Venom Sac"}}},
  {s=3277, i=3530, n="Wool Bandage", q=1, cat="Bandages", y=80, g=115, gr=150, r={{2592,1,"Wool Cloth"}}},
  {s=1244432, i=858, n="Lesser Healing Potion", q=1, lv=3, cat="Healing Potions", y=85, g=105, gr=125, r={{3371,1,"Empty Vial"}, {2678,2,"Mild Spices"}, {2450,1,"Briarthorn"}}},
  {s=1259342, i=255716, n="Simple Poultice", c=3, q=1, cat="Curatives", y=90, g=125, gr=160, r={{3174,1,"Spider Ichor"}, {2678,1,"Mild Spices"}, {2723,1,"Bottle of Dalaran Noir"}}},
  {s=3278, i=3531, n="Heavy Wool Bandage", q=1, cat="Bandages", y=115, g=150, gr=185, r={{2592,2,"Wool Cloth"}}},
  {s=1259347, i=255720, n="Woolen Tourniquet", q=1, cat="Curatives", y=120, g=155, gr=190, r={{2592,2,"Wool Cloth"}, {2321,2,"Fine Thread"}}},
  {s=1244433, i=929, n="Healing Potion", q=1, lv=12, cat="Healing Potions", y=135, g=155, gr=175, r={{3372,1,"Leaded Vial"}, {2692,1,"Hot Spices"}, {2453,1,"Bruiseweed"}}},
  {s=7928, i=6450, n="Silk Bandage", q=1, cat="Bandages", y=150, g=180, gr=210, r={{4306,1,"Silk Cloth"}}},
  {s=10841, i=8545, n="Heavy Mageweave Bandage", q=1, cat="Bandages", y=240, g=270, gr=300, r={{4338,2,"Mageweave Cloth"}}},
  {s=18629, i=14529, n="Runecloth Bandage", q=1, cat="Bandages", y=260, g=290, gr=320, r={{14047,1,"Runecloth"}}},
  {s=18630, i=14530, n="Heavy Runecloth Bandage", q=1, cat="Bandages", y=290, g=320, gr=350, r={{14047,2,"Runecloth"}}},
  {s=30021, i=23684, n="Crystal Infused Bandage", c=4, q=1, cat="Bandages", y=300, g=330, gr=360, r={{23567,1,"DEPRECATED ITEM"}, {14047,10,"Runecloth"}}},
  {s=7935, i=6453, n="Strong Anti-Venom", c=3, q=1, cat="Curatives", req=130, y=130, g=165, gr=200, r={{1288,1,"Large Venom Sac"}}, ri=6454, rn="Manual: Strong Anti-Venom", src={d={{3, "Flesh Eater", "Duskwood", 1431, 25.1, 38.2}, {48, "Skeletal Warrior", "Duskwood", 1431, 77.4, 73.8}, {202, "Skeletal Horror", "Duskwood", 1431, 79.7, 61.9}, {203, "Skeletal Mage", "Duskwood", 1431, 78.2, 75.6}, {205, "Nightbane Dark Runner", "Duskwood", 1431, 65.4, 67.8}}, dn=420}},
  {s=1262996, i=279940, n="Toxin Study", q=1, cat="Camping", req=140, y=0, g=0, gr=0, r={{6452,1,"Anti-Venom"}, {8544,2,"Mageweave Bandage"}, {4470,2,"Simple Wood"}}, ri=273105, rn="Blueprint: Toxin Study", src={d={{4278, "Commander Springvale", "Shadowfang Keep"}}, dn=1}},
  {s=1259343, i=255717, n="Clever Poultice", c=3, q=1, cat="Curatives", req=140, y=160, g=190, gr=220, r={{1468,1,"Murloc Fin"}, {3713,1,"Soothing Spices"}, {2686,1,"Thunder Ale"}}, ri=255724, rn="Manual: Clever Poultice", src={d={{910, "Defias Enchanter", "Duskwood", 1431, 48.8, 77.5}}, dn=1}},
  {s=1244434, i=1710, n="Greater Healing Potion", q=1, lv=21, cat="Healing Potions", req=155, y=175, g=195, gr=215, r={{3372,1,"Leaded Vial"}, {2692,3,"Hot Spices"}, {3357,1,"Liferoot"}}, ri=255723, rn="Manual: Greater Healing Potion", src={d={{2589, "Syndicate Mercenary", "Arathi Highlands", 1417, 30.9, 26.2}}, dn=1}},
  {s=7929, i=6451, n="Heavy Silk Bandage", q=1, cat="Bandages", req=180, y=180, g=210, gr=240, r={{4306,2,"Silk Cloth"}}, ri=16112, rn="Manual: Heavy Silk Bandage", src={v={{2805, "Deneb Walker", "Arathi Highlands", 1417, 27.0, 58.8, fac="A"}, {13476, "Balai Lok'Wein',2059,2059,43,43,0,{[15]={{36.49,30.36}}},nil,15,nil,nil,29,\"H\",\"Potions, Scrolls and Reagents\",4"}}}},
  {s=1259348, i=255721, n="Leather Tourniquet", q=1, cat="Curatives", req=200, y=220, g=250, gr=280, r={{4304,2,"Thick Leather"}, {4291,2,"Silken Thread"}}, ri=255726, rn="Manual: Leather Tourniquet"},
  {s=10840, i=8544, n="Mageweave Bandage", q=1, cat="Bandages", req=210, y=210, g=240, gr=270, r={{4338,1,"Mageweave Cloth"}}, ri=16113, rn="Manual: Mageweave Bandage", src={v={{2805, "Deneb Walker", "Arathi Highlands", 1417, 27.0, 58.8, fac="A"}, {13476, "Balai Lok'Wein',2059,2059,43,43,0,{[15]={{36.49,30.36}}},nil,15,nil,nil,29,\"H\",\"Potions, Scrolls and Reagents\",4"}}}},
  {s=1259344, i=255718, n="Superior Poultice", c=3, q=1, cat="Curatives", req=210, y=225, g=255, gr=285, r={{7070,1,"Elemental Water"}, {2692,1,"Hot Spices"}, {2596,1,"Skin of Dwarven Stout"}}, ri=255727, rn="Manual: Superior Poultice"},
  {s=1259341, i=255715, n="Potent Anti-Venom", c=3, q=1, cat="Curatives", req=215, y=230, g=260, gr=290, r={{255645,1,"Swollen Venom Sac"}}, ri=255728, rn="Manual: Potent Anti-Venom", src={d={{760, "Lost One Muckdweller", "Swamp of Sorrows", 1435, 58.4, 28.5}}, dn=1}},
  {s=1244435, i=3928, n="Superior Healing Potion", q=1, lv=35, cat="Healing Potions", req=215, y=230, g=250, gr=270, r={{8925,1,"Crystal Vial"}, {3713,1,"Soothing Spices"}, {8838,1,"Sungrass"}}, ri=255725, rn="Manual: Superior Healing Potion"},
  {s=1259349, i=255722, n="Surgical Tourniquet", q=1, cat="Curatives", req=265, y=280, g=310, gr=340, r={{8170,2,"Rugged Leather"}, {14047,2,"Runecloth"}, {8343,2,"Heavy Silken Thread"}}, ri=255730, rn="Manual: Surgical Tourniquet"},
  {s=1244436, i=13446, n="Major Healing Potion", q=1, lv=45, cat="Healing Potions", req=275, y=290, g=310, gr=330, r={{8925,1,"Crystal Vial"}, {3713,3,"Soothing Spices"}, {13464,1,"Golden Sansam"}}, ri=255729, rn="Manual: Major Healing Potion", src={v={{266901, "Pexmit", "Mount Hyjal"}}}},
  {s=1259345, i=255719, n="Powerful Poultice", c=3, q=1, cat="Curatives", req=280, y=295, g=325, gr=355, r={{7080,1,"Essence of Water"}, {2692,1,"Hot Spices"}, {2594,1,"Flagon of Dwarven Honeymead"}}, ri=255731, rn="Manual: Powerful Poultice"},
  {s=1263001, i=279951, n="Plague Doctor's Laboratory", q=1, cat="Camping", req=300, y=0, g=0, gr=0, r={{4470,2,"Simple Wood"}, {6453,2,"Strong Anti-Venom"}, {14530,5,"Heavy Runecloth Bandage"}}, ri=273118, rn="Blueprint: Plague Doctor's Laboratory"},
  {s=23787, i=19440, n="Powerful Anti-Venom", c=3, q=1, cat="Curatives", req=300, y=300, g=330, gr=360, r={{19441,1,"Huge Venom Sac"}}, ri=19442, rn="Formula: Powerful Anti-Venom", src={v={{10856, "Argent Quartermaster Hasana", "Tirisfal Glades", 1420, 83.3, 68.1, fac="AH"}, {10857, "Argent Quartermaster Lightspark", "Western Plaguelands", 1422, 42.8, 83.7, fac="AH"}, {11536, "Quartermaster Miranda Breechlock", "Eastern Plaguelands", 1423, 71.8, 50.2, fac="AH"}}}},
}
