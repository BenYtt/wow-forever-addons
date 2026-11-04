local _, FLT = ...

-- Weapon masters for the trainer window (UI/TrainerSpells.lua, 5.7.3, user 25.10.). Positions: QuestieDB Forever
-- NPC data (GPL-3); what each one teaches: public Classic guides (warcrafttavern.com, blizzardwatch.com, checked
-- 25.10.2026 - no Forever changes known). skills = weapon item subclass IDs (0 1H axes, 1 2H axes, 2 bows, 3 guns,
-- 4 1H maces, 5 2H maces, 6 polearms, 7 1H swords, 8 2H swords, 10 staves, 13 fist weapons, 15 daggers,
-- 16 thrown, 18 crossbows). Polearms from level 20 for 1 gold, the rest 10 silver.
FLT.WEAPON_TRAINERS = {
  { npc = 11867, name = "Woo Ping", side = "A", map = 1453, x = 63.9, y = 69.1, city = "Stormwind City", skills = { 18, 15, 7, 6, 10, 8 } },
  { npc = 13084, name = "Bixi Wobblebonk", side = "A", map = 1455, x = 62.2, y = 89.6, city = "Ironforge", skills = { 18, 15, 16 } },
  { npc = 11865, name = "Buliwyf Stonehand", side = "A", map = 1455, x = 61.2, y = 89.5, city = "Ironforge", skills = { 13, 3, 0, 4, 1, 5 } },
  { npc = 11866, name = "Ilyenia Moonfire", side = "A", map = 1457, x = 57.6, y = 46.7, city = "Darnassus", skills = { 2, 15, 13, 10, 16 } },
  { npc = 11868, name = "Sayoc", side = "H", map = 1454, x = 81.7, y = 19.6, city = "Orgrimmar", skills = { 2, 15, 13, 0, 10, 16, 1 } },
  { npc = 2704, name = "Hanashi", side = "H", map = 1454, x = 81.5, y = 19.6, city = "Orgrimmar", skills = { 2, 0, 10, 16, 1 } },
  { npc = 11869, name = "Ansekhwa", side = "H", map = 1456, x = 40.9, y = 62.7, city = "Thunder Bluff", skills = { 3, 4, 10, 5 } },
  { npc = 11870, name = "Archibald", side = "H", map = 1458, x = 57.3, y = 32.8, city = "Undercity", skills = { 18, 15, 7, 6, 8 } },
}
-- weapon subclass -> the weapon skill spell (name, icon and "known" come from it)
FLT.WEAPON_SKILL_SPELL = { [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201,
  [8] = 202, [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009 }
FLT.WEAPON_SKILL_NAME = { [0] = "One-Handed Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns", [4] = "One-Handed Maces",
  [5] = "Two-Handed Maces", [6] = "Polearms", [7] = "One-Handed Swords", [8] = "Two-Handed Swords", [10] = "Staves",
  [13] = "Fist Weapons", [15] = "Daggers", [16] = "Thrown", [18] = "Crossbows", [19] = "Wands" }
-- icons per weapon type (the skill spells have none in every client)
FLT.WEAPON_SKILL_ICON = { [0] = "INV_Axe_01", [1] = "INV_Axe_09", [2] = "INV_Weapon_Bow_05", [3] = "INV_Weapon_Rifle_01",
  [4] = "INV_Mace_01", [5] = "INV_Hammer_05", [6] = "INV_Spear_06", [7] = "INV_Sword_04", [8] = "INV_Sword_06",
  [10] = "INV_Staff_08", [13] = "INV_Gauntlets_04", [15] = "INV_Weapon_ShortBlade_01", [16] = "INV_ThrowingKnife_02",
  [18] = "INV_Weapon_Crossbow_01", [19] = "INV_Wand_01" }
