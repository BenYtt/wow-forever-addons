local _, FLT = ...

FLT.TRADE_HUBS = {
  Alliance = {name="Azeroth Commerce Authority", zone="Redridge Mountains", place="Three Corners", x=10.5, y=72.7, handin="Marcy Baker", handinX=9.6, handinY=70.9},
  Horde = {name="Durotar Supply & Logistics", zone="The Barrens", place="West of the Crossroads", x=42.0, y=34.0, handin="Dokimi", handinX=50.0, handinY=29.0},
}

FLT.PROFESSION_VENDORS = {
  {profession="Alchemy", alliance="Nina Surefire", ax=10.8, ay=72.4, horde="Apothecary Durelle", hx=49.8, hy=29.4},
  {profession="Blacksmithing", alliance="Stondry Darkhammer", ax=10.2, ay=74.2, horde="Gor'mak", hx=49.8, hy=29.6},
  {profession="Tailoring", alliance="Mivin Shadowweave", ax=10.0, ay=72.8, horde="Jim'bek", hx=49.6, hy=29.4},
  {profession="Leatherworking", alliance="Daniel Stitchsong", ax=10.0, ay=72.4, horde="Pawani", hx=49.6, hy=29.6},
  {profession="Engineering", alliance="Fritz Fizzle", ax=10.4, ay=74.2, horde="Fizzlefuse", hx=49.8, hy=29.6},
  {profession="Enchanting", alliance="Alynsia", ax=11.2, ay=71.6, horde="Beneris", hx=49.8, hy=29.4},
  {profession="Cooking", alliance="Kalsey Sanden", ax=10.8, ay=72.4, horde="Aza'bek", hx=49.6, hy=29.2},
}

-- Current beta reports. Values can change; only the first four observed tiers are shown.
FLT.FAVOR_GUIDE = {
  {tier="First delivery quest", level="10+", reward="50 Favor", note="One-time introductory reward reported by testers."},
  {tier="Apprentice (white)", level="10+", reward="5 Favor", note="Sealed Apprentice Crate."},
  {tier="Apprentice (green)", level="10+", reward="10 Favor + 5 SP", note="Higher-quality Apprentice crate."},
  {tier="Journeyman (white)", level="10+", reward="10 Favor + 5 SP", note="Sealed Journeyman Crate."},
  {tier="Journeyman (green)", level="10+", reward="20 Favor + 10 SP", note="Higher-quality Journeyman crate."},
  {tier="Expert", level="20+", reward="Varies", note="Reward values are still being verified in beta."},
  {tier="Artisan", level="35+", reward="Varies", note="Reward values are still being verified in beta."},
}

-- Library Book reward quests (Wowhead Forever, 2 October 2026).
-- Each tier is a separate quest at the librarian; the book count for the
-- third tier is not confirmed yet.
FLT.BOOK_REWARD_TIERS = {
  {books="10 books", quest="Friend of the Library", questID=78150, req=1,
   items={{277203,"Scholarly Pendant",2,"Neck - +3 Stamina, +2 Spirit"},{277204,"Erudite's Amulet",2,"Neck - +2 Agility, +3 Stamina"}}},
  {books="20 books", quest="Greater Friend of the Library", questID=79536, req=20,
   items={{281634,"Field Researcher's Loop",3,"Ring - +7 Agility, +7 Stamina"},{281635,"Philanthropist's Ring",3,"Ring - +5 Intellect, up to +9 spell power"}}},
  {books="30 books (?)", quest="Greater Friend of the Library", questID=82208, req=30,
   items={{277254,"Truthseeker's Bow",3,"Bow - +7 Agility, +3 Stamina"},{277258,"Crest of Elucidation",3,"Shield - +12 Spirit, healing"},{277260,"Researcher's Night Light",3,"Off-hand - +12 Stamina, fire damage"}}},
}

FLT.CRATE_STEPS = {
  "Loot a Waylaid Crate while questing (system starts around level 10).",
  "Right-click it to reveal the shipment type and its acceptable material bundles.",
  "Fill ONE complete bundle from the list; you do not need every listed option.",
  "Turn the sealed crate in at your faction's supply representative.",
  "Spend Merchant's Favor at the profession quartermasters on new recipes.",
}


-- Crafted-result details used to enrich recipe tooltips.
-- The recipe scroll itself only says that it teaches the craft; these entries
-- describe the item created by the recipe so the tooltip is useful even when
-- the output item is not yet cached by the client.
FLT.CRAFTED_RESULT_INFO = {
  ["Elixir of Lesser Spirit"] = {level=25, effect="Drink to increase your Spirit by 6 for 30 min.", reagents="2 Wild Steelbloom, 1 Mageroyal, 1 Empty Vial"},
  ["Lesser Mageblood Elixir"] = {level=25, effect="Drink to restore 6 mana every 5 sec for 30 min.", reagents="3 Kingsblood, 1 Empty Vial"},
  ["Elixir of Lesser Intellect"] = {level=25, effect="Drink to increase your Intellect by 6 for 30 min.", reagents="3 Kingsblood, 1 Leaded Vial"},
  ["Lesser Cleric's Elixir"] = {level=25, effect="Drink to increase healing from spells and effects by 20 for 30 min.", reagents="2 Kingsblood, 2 Liferoot, 1 Leaded Vial"},
  ["Lesser Arcane Elixir"] = {level=25, effect="Drink to increase spell damage by 15 for 30 min.", reagents="4 Kingsblood, 1 Leaded Vial"},
  ["Mender's Potion"] = {level=25, effect="Use: Increases healing by 28 for 30 sec. Shares the potion cooldown.", reagents="2 Wintersbite, 2 Firebloom, 1 Leaded Vial"},
  ["Spellblasting Potion"] = {level=25, effect="Use: Increases spell damage by 14 for 30 sec. Shares the potion cooldown.", reagents="1 Wild Steelbloom, 1 Grave Moss, 1 Empty Vial"},
  ["Frenzy Potion"] = {level=25, effect="Use: Increases attack power by 14 for 30 sec. Shares the potion cooldown.", reagents="2 Grave Moss, 2 Briarthorn, 1 Leaded Vial"},
  ["Elixir of Greater Spirit"] = {level=55, effect="Drink to increase your Spirit by 18 for 30 min.", reagents="3 Arthas' Tears, 2 Purple Lotus, 1 Crystal Vial"},
  ["Greater Mageblood Elixir"] = {level=55, effect="Drink to restore 20 mana every 5 sec for 30 min.", reagents="3 Blindweed, 2 Arthas' Tears, 1 Crystal Vial"},
  ["Disorienting Smog Potion"] = {level=45, effect="Use: Throw a cloud that lasts 8 sec; enemies inside have 15% reduced chance to hit. 2 min cooldown.", reagents="3 Ghost Mushroom, 2 Grave Moss, 1 Crystal Vial"},
  ["Greater Cleric's Elixir"] = {level=55, effect="Drink to increase healing from spells and effects by 40 for 30 min.", reagents="3 Arthas' Tears, 1 Purple Lotus, 1 Crystal Vial"},
  ["Elixir of Greater Fortitude"] = {level=55, effect="Drink to increase maximum health by 400 for 30 min.", reagents="4 Sungrass, 1 Crystal Vial"},
  ["Dragonfire Potion"] = {level=35, effect="Use: Breathe dragonfire in a narrow cone, dealing 450 Fire damage immediately and 125 every 2 sec for 8 sec. 2 min cooldown.", reagents="2 Mountain Silversage, 2 Firebloom, 1 Crystal Vial"},
  ["Elixir of the Phalanx"] = {level=55, effect="Drink to gain 400 maximum health and 500 armor for 30 min.", reagents="2 Golden Sansam, 4 Sungrass, 1 Crystal Vial"},
  ["Caustic Smog Potion"] = {level=45, effect="Use: Throw a caustic cloud lasting 12 sec; enemies inside take 285-315 Nature damage each second. 2 min cooldown.", reagents="2 Ghost Mushroom, 2 Grave Moss, 1 Crystal Vial"},
  ["Elixir of Cunning"] = {level=55, effect="Drink to increase Agility by 25 and Intellect by 25 for 30 min.", reagents="3 Dreamfoil, 2 Gromsblood, 1 Crystal Vial"},
  ["Elixir of Ferocity"] = {level=55, effect="Drink to increase Strength by 18 and Agility by 18 for 30 min.", reagents="3 Gromsblood, 1 Ghost Mushroom, 1 Crystal Vial"},
  ["Elixir of Sages"] = {level=55, effect="Drink to increase Spirit by 25 and chance to critically hit by 2% for 30 min.", reagents="4 Dreamfoil, 2 Golden Sansam, 1 Imbued Vial"},
  ["Elixir of the Whale"] = {level=55, effect="Drink to increase your Spirit by 25 and chance to critically hit by 2% for 30 min.", reagents="3 Dreamfoil, 1 Gromsblood, 1 Crystal Vial"},
  ["Potion of Venomous Blood"] = {level=30, effect="Use: Gain 10 charges of Venomous Blood for 20 sec. When you take bleed damage, a charge jumps to an enemy within 8 yd and deals 325 Nature damage when it expires. 2 min cooldown.", reagents="3 Gromsblood, 2 Plaguebloom, 1 Crystal Vial"},
  ["Elixir of the Owl"] = {level=55, effect="Drink to increase Intellect by 25 and chance to critically hit by 2% for 30 min.", reagents="4 Dreamfoil, 2 Mountain Silversage, 1 Imbued Vial"},
  ["Major Mender's Potion"] = {level=55, effect="Use: Increases healing by 75 for 30 sec. Shares the potion cooldown.", reagents="3 Dreamfoil, 1 Sungrass, 1 Imbued Vial"},
  ["Potion of Elemental Siphoning"] = {level=40, effect="Use: Increases spell damage by 265 against elementals for 2 min. 2 min cooldown.", reagents="2 Firebloom, 2 Wintersbite, 1 Crystal Vial"},
  ["Elixir of Nature Power"] = {level=55, effect="Drink to increase Nature spell damage by 40 for 30 min.", reagents="4 Golden Sansam, 2 Sungrass, 1 Crystal Vial"},
  ["Elixir of Wicked Regeneration"] = {level=55, effect="Drink to restore 9 health and 10 mana every 5 sec for 30 min.", reagents="3 Golden Sansam, 2 Dreamfoil, 1 Crystal Vial"},
  ["Major Spellblasting Potion"] = {level=55, effect="Use: Increases spell damage by 40 for 30 sec. Shares the potion cooldown.", reagents="2 Dreamfoil, 1 Mountain Silversage, 1 Imbued Vial"},
  ["Major Frenzy Potion"] = {level=55, effect="Use: Increases attack power by 40 for 30 sec. Shares the potion cooldown.", reagents="3 Plaguebloom, 2 Blindweed, 1 Imbued Vial"},
  ["Elixir of the Grizzly"] = {level=55, effect="Drink to increase Strength by 25 and chance to critically hit by 2% for 30 min.", reagents="3 Gromsblood, 1 Blindweed, 1 Crystal Vial"},
}



-- Extra crafted-result descriptions for professions where the recipe itself
-- does not describe the useful effect.  Runtime item/spell data is preferred
-- when the client can resolve it; these are safe fallbacks for known Forever
-- effects.
FLT.PROFESSION_RESULT_INFO = {
  ["Enchant Weapon - Recovery"] = {label="Enchant effect", effect="Permanently enchants a melee weapon. When you are parried or dodged, heals you for 5% of your maximum health. Cannot occur more than once every 10 sec."},
  ["Enchant Weapon - Insight"] = {label="Enchant effect", effect="Permanently enchants a weapon with a chance while casting to grant Insight, increasing Spirit by 100% for 10 sec."},
  ["Enchant Weapon - Revelation"] = {label="Enchant effect", effect="Permanently enchants a weapon with Revelation. After a direct spell fails to critically strike, Revelation can make your next spell much more likely to critically strike."},
  ["Gnomish Poultryizer"] = {label="Crafted item", effect="Trinket. Use: Turns the target into a chicken for 15 sec (5 min cooldown; the polarity can sometimes be reversed)."},
}

FLT.RECIPE_PREFIX = {
  Alchemy="Recipe: ", Blacksmithing="Plans: ", Enchanting="Formula: ",
  Engineering="Schematic: ", Leatherworking="Pattern: ", Tailoring="Pattern: ", Cooking="Recipe: ",
}

FLT.MERCHANT_RECIPES = {}
local function add(profession, name, skill, cost)
  FLT.MERCHANT_RECIPES[#FLT.MERCHANT_RECIPES+1] = {profession=profession, name=name, skill=skill, cost=cost}
end

-- Alchemy (29)
local alchemy = {
  {"Elixir of Lesser Spirit",65,45},{"Lesser Mageblood Elixir",75,45},{"Elixir of Lesser Intellect",95,45},{"Lesser Cleric's Elixir",95,45},
  {"Lesser Arcane Elixir",120,45},{"Mender's Potion",130,45},{"Spellblasting Potion",135,45},{"Frenzy Potion",140,45},
  {"Elixir of Greater Spirit",165,120},{"Greater Mageblood Elixir",175,120},{"Disorienting Smog Potion",180,120},{"Greater Cleric's Elixir",195,120},
  {"Elixir of Greater Fortitude",200,120},{"Dragonfire Potion",245,120},{"Elixir of the Phalanx",250,180},{"Caustic Smog Potion",265,180},
  {"Elixir of Cunning",275,180},{"Elixir of Ferocity",275,180},{"Elixir of Sages",275,180},{"Elixir of the Whale",275,180},
  {"Potion of Venomous Blood",275,180},{"Elixir of the Owl",280,180},{"Major Mender's Potion",280,180},{"Potion of Elemental Siphoning",280,180},
  {"Elixir of Nature Power",285,180},{"Elixir of Wicked Regeneration",285,180},{"Major Spellblasting Potion",285,180},{"Major Frenzy Potion",290,240},
  {"Elixir of the Grizzly",300,240},
}
for _,r in ipairs(alchemy) do add("Alchemy",r[1],r[2],r[3]) end

-- Blacksmithing (60)
local bsEarlyPrefixes={"Acolyte's","Crusader's","Guard's","Protector's","Veteran's"}
local bsEarlyPieces={{"Chain Belt",45},{"Gloves",80},{"Boots",85},{"Silvered Chain Helm",95},{"Silvered Chain Shirt",110},{"Silvered Chain Leggings",125}}
for _,p in ipairs(bsEarlyPrefixes) do for _,piece in ipairs(bsEarlyPieces) do add("Blacksmithing",p.." "..piece[1],piece[2],30) end end
local bsLatePrefixes={"Justicar's","Officer's","Prefect's","Sentinel's","Warder's"}
for _,p in ipairs(bsLatePrefixes) do add("Blacksmithing",p.." Gauntlet",175,60) end
for _,p in ipairs(bsLatePrefixes) do add("Blacksmithing",p.." Pauldrons",210,60) end
for _,p in ipairs(bsLatePrefixes) do add("Blacksmithing",p.." Wristguards",225,90) end
for _,p in ipairs(bsLatePrefixes) do add("Blacksmithing",p.." Sabatons",240,90) end
for _,p in ipairs({"Justicar's","Officer's","Sentinel's","Warder's"}) do add("Blacksmithing",p.." Waistguard",250,90) end
add("Blacksmithing","Thorium Cestus",250,90); add("Blacksmithing","Thorium Greatmace",250,90)
for _,n in ipairs({"Enriched Thorium Breastplate","Enriched Thorium Helm","Enriched Thorium Leggings","Legionite Glaive"}) do add("Blacksmithing",n,300,120) end

-- Enchanting (39)
local enchanting={
  {"Mystic Mushroom",130,45},{"Polished Driftwood Icon",130,45},{"Tenets of the Silver Hand",130,45},{"Enchant Weapon - Insight",140,45},
  {"Enchant Weapon - Recovery",140,45},{"Enchant Weapon - Revelation",140,45},{"Glimmering Staff",140,45},{"Orb of Mystic Insight",140,45},
  {"Orb of Souls",140,45},{"Soulstaff",140,45},{"Enchant Necklace - Agility",210,120},{"Enchant Necklace - Deflection",210,120},
  {"Enchant Necklace - Healing Power",210,120},{"Enchant Necklace - Spell Power",210,120},{"Enchant Necklace - Strength",210,120},{"Libram of Invocation",210,120},
  {"Talons of Wrath",210,120},{"Totem of Ancestral Protection",210,120},{"Dreamstaff",220,120},{"Enchant Chest - Absorption",220,120},
  {"Radiant Staff",220,120},{"Truesilver Conduit",220,120},{"Twisting Essence Jar",220,120},{"Brilliant Wand",275,180},
  {"Enchant 2H Weapon - Mighty Healing Power",300,240},{"Enchant 2H Weapon - Mighty Spell Power",300,240},{"Enchant 2H Weapon - Spellblasting",300,240},
  {"Enchant Bracer - Greater Spellpower",300,240},{"Enchant Bracer - Superior Deflection",300,240},{"Enchant Bracer - Superior Intellect",300,240},
  {"Enchant Cloak - Agility",300,240},{"Enchant Gloves - Arcane Power",300,240},{"Enchant Gloves - Holy Power",300,240},{"Enchant Gloves - Natural Power",300,240},
  {"Enchant Gloves - Superior Strength",300,240},{"Enchant Off-Hand - Wisdom",300,240},{"Idol of the Dream",300,240},{"Libram of Holy Alacrity",300,240},{"Totem of Thunder",300,240},
}
for _,r in ipairs(enchanting) do add("Enchanting",r[1],r[2],r[3]) end

-- Engineering (28)
local engineering={
  {"SAF-T Dynamite",25,45},{"SAF-T Tabs",25,45},{"SAF-T Copper Bomb",55,45},{"Satchel of Copper Bombs",85,45},{"EZ-Thro Wrap",100,45},
  {"EZ-Thro Copper Bomb XL",130,45},{"No Slip SAF-T Padding",145,45},{"Satchel of Bronze Bombs",165,180},{"Clanking Cord",175,180},
  {"Gizmo Girdle",175,180},{"SAF-T Bell",175,180},{"Whimsical Waistwrap",175,180},{"EZ-Thro Fireproof Fuse",190,180},
  {"Bent Goggles",200,180},{"Dented Goggles",200,180},{"Floppy Goggles",200,180},{"Stuckbutton Goggles",200,180},
  {"Compact Critter Carrier",225,270},{"Emergency Field Cloak",225,270},{"Satchel of Iron Bombs",230,270},{"Gnomish Army Knife",250,270},
  {"SAF-T Disposable Parachute",250,270},{"Loot-A-Rang",275,270},{"Satchel of Dark Iron Bombs",285,270},{"Gnomish Poultryizer",300,360},
  {"Stealthman 52",300,360},{"Ultralight Goblin Glider",300,360},{"Ultrasafe Rechargeable Battery",300,360},
}
for _,r in ipairs(engineering) do add("Engineering",r[1],r[2],r[3]) end

-- Leatherworking (81)
local lwPrefixes={"Brawler's","Defender's","Stormrider's","Totemic","Trapper's","Wisdom's"}
local lwPieces={
  {"Leather Belt",60},{"Leather Gloves",75},{"Leather Boots",85},{"Leather Hood",100},{"Leather Tunic",110}
}
for _,p in ipairs(lwPrefixes) do for _,piece in ipairs(lwPieces) do add("Leatherworking",p.." "..piece[1],piece[2],30) end end
local lwLegNames={"Brawler's Leather Legguards","Defender's Leather Kilt","Stormrider's Leather Kilt","Totemic Leather Leggings","Trapper's Leather Legguards","Wisdom's Leather Leggings"}
for _,n in ipairs(lwLegNames) do add("Leatherworking",n,125,30) end
for _,n in ipairs({"Mender's Leather Gloves","Prowler's Leather Gloves","Skirmisher's Leather Gloves","Skulker's Leather Gloves","Skycaller's Leather Gloves","Stalker's Leather Gloves","Warden's Leather Gloves"}) do add("Leatherworking",n,175,60) end
add("Leatherworking","Forceful Thick Armor Kit",185,60)
local lwShoulders={"Mender's Leather Shoulder","Mender's Mail Shoulder","Prowler's Leather Shoulder","Skirmisher's Mail Shoulder","Skulker's Leather Shoulder","Skycaller's Leather Shoulder","Skycaller's Mail Shoulder","Stalker's Mail Shoulder","Warden's Leather Shoulder"}
for _,n in ipairs(lwShoulders) do add("Leatherworking",n,210,60) end
local lwBracers={"Mender's Leather Bracers","Mender's Mail Bracers","Prowler's Leather Bracers","Skirmisher's Mail Bracers","Skulker's Leather Bracers","Skycaller's Leather Bracers","Skycaller's Mail Bracers","Stalker's Mail Bracers","Warden's Leather Bracers"}
for _,n in ipairs(lwBracers) do add("Leatherworking",n,225,90) end
local lwBoots={"Mender's Leather Boots","Mender's Mail Sabatons","Mystic Rugged Armor Kit","Prowler's Leather Boots","Skirmisher's Mail Sabatons","Skulker's Leather Boots","Skycaller's Leather Boots","Skycaller's Mail Sabatons","Stalker's Mail Sabatons","Warden's Leather Boots"}
for _,n in ipairs(lwBoots) do add("Leatherworking",n,235,90) end
local lwWaists={"Mender's Leather Waistguard","Mender's Mail Belt","Prowler's Leather Waistguard","Skirmisher's Mail Belt","Skulker's Leather Waistguard","Skycaller's Leather Waistguard","Skycaller's Mail Belt","Stalker's Mail Belt","Warden's Leather Waistguard"}
for _,n in ipairs(lwWaists) do add("Leatherworking",n,250,90) end

-- Tailoring (67)
local tailorPrefixes={"Flame","Pearly","Pristine","Shadow","Shining","Silky"}
for _,p in ipairs(tailorPrefixes) do
  add("Tailoring",p.." Boots",60,30); add("Tailoring",p.." Gloves",75,30); add("Tailoring",p.." Sash",85,30)
  add("Tailoring",p.." Circlet",100,30); add("Tailoring",p.." Gown",110,30); add("Tailoring",p.." Leggings",125,30)
end
for _,n in ipairs({"Black Handwraps","Fiery Handwraps","Frothing Handwraps","Golden Handwraps","Radiant Handwraps"}) do add("Tailoring",n,165,60) end
add("Tailoring","Mageweave Reagent Bag",190,60)
for _,p in ipairs({"Netherflame","Netherfroth","Nethergeld","Netherlight","Netherpearl","Nethershine"}) do add("Tailoring",p.." Shoulders",195,60) end
for _,p in ipairs({"Netherflame","Netherfroth","Nethergeld","Netherlight","Netherpearl","Nethershine"}) do add("Tailoring",p.." Cuffs",205,60) end
for _,n in ipairs({"Black Waistcord","Fiery Waistcord","Frothing Waistcord","Gilded Waistcord","Golden Waistcord","Radiant Waistcord"}) do add("Tailoring",n,215,60) end
add("Tailoring","Runecloth Reagent Bag",215,60)
for _,n in ipairs({"Black Sandals","Fiery Sandals","Frothing Sandals","Gilded Sandals","Golden Sandals","Radiant Sandals"}) do add("Tailoring",n,235,90) end

-- Cooking (6 additional Merchant's Favor recipes)
for _,r in ipairs({
  {"Venomous Smoothie",25,30},{"Slimy Smoothie",100,30},{"Mrrggl Smrrthle",125,30},
  {"Calcified Smoothie",180,60},{"Spicy Smoothie",200,60},{"Wicked Smoothie",250,90},
}) do add("Cooking",r[1],r[2],r[3]) end

FLT.PROFESSION_ORDER={"Alchemy","Blacksmithing","Enchanting","Engineering","Leatherworking","Tailoring","Cooking","First Aid"}


-- Camping profession objects. Values reflect the current Forever beta client
-- snapshot and are intentionally presented as beta data because effects may be
-- tuned before launch.
FLT.CAMPING_PROFESSIONS = {
  {profession="Alchemy", items={
    {name="Mana Well", id=279956, skill=20, effect="Mana regeneration for resting players; exclusive with Blessing of Wisdom.", reagents="Peacebloom x1, Empty Vial x1"},
    {name="Fermenter", id=279970, skill=140, effect="Creates certain reagents and includes the Mana Well benefit.", reagents="Leaded Vial x1, Kingsblood x1, Swiftthistle x1"},
    {name="Alchemy Laboratory", id=279990, skill=300, effect="Enables recipes requiring an Alchemy Laboratory and includes the Mana Well benefit.", reagents="Lich's Index Finger x1, Crystal Vial x1, Dreamfoil x2"},
  }},
  {profession="Blacksmithing", items={
    {name="Sharpening Wheel", id=279944, skill=20, effect="Strength buff for resting players; exclusive with Strength of Earth Totem.", reagents="Rough Stone x1, Copper Bar x1"},
    {name="Anvil", id=279988, skill=140, effect="Usable campsite anvil plus the Sharpening Wheel benefit.", reagents="Bronze Bar x5, Coarse Grinding Stone x2, Medium Leather x2"},
    {name="Master Forge", id=279955, skill=300, effect="Enables recipes requiring a Forge and includes the Sharpening Wheel benefit.", reagents="Golem Heart x1, Thorium Bar x5, Rugged Leather x2"},
  }},
  {profession="Enchanting", items={
    {name="Enchanted Lute", id=279976, skill=20, effect="Armor, all-stats and resistance style camping buff; exclusive with Mark of the Wild.", reagents="Simple Wood x1, Silverleaf x1"},
    {name="Arcane Salvager", id=279985, skill=140, effect="More efficient disenchanting utility plus the Enchanted Lute benefit.", reagents="Vision Dust x2, Lesser Nether Essence x1"},
    {name="Arcane Forge", id=279987, skill=300, effect="Enables recipes requiring an Arcane Forge plus the Enchanted Lute benefit.", reagents="Maker's Spark x1, Large Brilliant Shard x2, Greater Eternal Essence x4"},
  }},
  {profession="Engineering", items={
    {name="Reagent Bot", id=279950, skill=20, effect="Lets nearby players purchase common reagents.", reagents="Handful of Copper Bolts x1, Copper Tube x1"},
    {name="Repair Bot", id=279949, skill=140, effect="Reagent vendor and gear repairs; upgrades the Reagent Bot.", reagents="Whirring Bronze Gizmo x2, Bronze Tube x1, Heavy Leather x1"},
    {name="Anarchist's Workbench", id=279989, skill=300, effect="Enables recipes requiring an Anarchist's Workbench.", reagents="Essence of Anarchy x1, Thorium Widget x2"},
  }},
  {profession="Herbalism", items={
    {name="Incense Candle", id=279962, skill=20, effect="Intellect buff for resting players.", reagents="Current beta profession recipe"},
    {name="Greenhouse", id=279964, skill=140, effect="Grows herbs from planted seeds and includes the Incense Candle benefit.", reagents="Simple Wood x2, Arthas' Tears x1, Purple Lotus x1"},
    {name="Seed Hybridizer", id=279947, skill=300, effect="Multiplies/combines seeds into rarer tiers and includes the Intellect benefit.", reagents="Mountain Silversage x4, Crystal Vial x1, Runecloth x2"},
  }},
  {profession="Leatherworking", items={
    {name="Camp Tent", id=279978, skill=20, effect="Increases rested experience up to 5% of a level for resting players.", reagents="Light Leather x5"},
    {name="Tanning Rack", id=279941, skill=140, effect="Creates certain reagents and includes the Camp Tent benefit.", reagents="Medium Leather x5, Fine Thread x3, Simple Wood x2"},
    {name="Sewing Machine", id=279945, skill=300, effect="Enables recipes requiring a Sewing Machine and includes the Camp Tent benefit.", reagents="Undeath Engine x1, Rugged Leather x5, Rune Thread x1"},
  }},
  {profession="Mining", items={
    {name="Lodestone", id=279960, skill=20, effect="Melee Attack Power buff for resting players; exclusive with Blessing of Might.", reagents="Rough Stone x1, Copper Bar x1"},
    {name="Rock Garden", id=279948, skill=140, effect="Spawns a common mining node over time and includes the Lodestone benefit.", reagents="Heavy Stone x2, Iron Ore x1, Silver Bar x1"},
    {name="Molten Foundry", id=279952, skill=300, effect="Enables recipes requiring a Foundry and includes the Lodestone benefit.", reagents="Thorium Bar x5, Dense Stone x2, Truesilver Bar x1"},
  }},
  {profession="Skinning", items={
    {name="Camp Chair", id=279979, skill=20, effect="2% increased critical strike chance with attacks and spells; exclusive with Moonkin Aura.", reagents="Light Leather x3, Simple Wood x2"},
    {name="Field Guide", id=279969, skill=140, effect="Lets players gain Track Beasts and includes the Camp Chair crit benefit.", reagents="Medium Leather x3, Slimy Murloc Scale x2, Fine Thread x1"},
    {name="Trapper's Workbench", id=279938, skill=300, effect="Contains a trap and includes the Camp Chair crit benefit.", reagents="Simple Wood x2, Heavy Leather x4, Iron Bar x1"},
  }},
  {profession="Tailoring", items={
    {name="Faction Banner", id=279972, idA=279973, skill=20, effect="Spirit buff for same-faction resting players; exclusive with Divine Spirit. The exact amount scales by level in current beta tooltips.", reagents="Bolt of Linen Cloth x1, Coarse Thread x1"},
    {name="Spinning Wheel", id=279943, skill=140, effect="Creates certain reagents and includes the Faction Banner benefit.", reagents="Simple Wood x2, Bolt of Silk Cloth x5, Fine Thread x3"},
    {name="Loom", id=279959, skill=300, effect="Enables recipes requiring a Loom and includes the Faction Banner benefit.", reagents="Bottled Screams x1, Bolt of Runecloth x4, Simple Wood x4"},
  }},
  {profession="Cooking", items={
    {name="Basic Campfire", icon="Interface\\Icons\\Spell_Fire_Fire", skill=1, effect="Allows cooking and up to 3 additional camp features; nearby players gain camp benefits after resting/crafting for 1 minute.", reagents="Simple Wood x1"},
    {name="Journeyman Campfire", icon="Interface\\Icons\\Spell_Fire_Fire", skill=90, effect="Allows cooking and up to 5 additional camp features.", reagents="Star Wood x1"},
    {name="Cookie's Feast", id=279957, skill=140, effect="Provides Stamina-boosting food at the campsite.", reagents="Mystery Meat x2, Heavy Kodo Meat x1, Soothing Spices x1"},
    {name="Expert Campfire", icon="Interface\\Icons\\Spell_Fire_Fire", skill=200, effect="Allows cooking and up to 10 additional camp features.", reagents="Thick Logs x1"},
    {name="Iron Oven", id=279982, skill=300, effect="Required for the most advanced Cooking recipes.", reagents="Simple Flour x10, Refreshing Spring Water x5, Soothing Spices x4"},
  }},
  {profession="First Aid", items={
    {name="First Aid Kit", id=279968, skill=20, effect="Provides a Stamina-style camp buff.", reagents="Linen Bandage x3, Refreshing Spring Water x1"},
    {name="Toxin Study", id=279940, skill=140, effect="Camping utility for healing potions and antivenom; exact beta behavior is still being documented.", reagents="Anti-Venom x1, Mageweave Bandage x2, Simple Wood x2"},
    {name="Plague Doctor's Laboratory", id=279951, skill=300, effect="Advanced campsite healing/poultice utility; exact beta behavior is still being documented.", reagents="Simple Wood x2, Strong Anti-Venom x2, Heavy Runecloth Bandage x5"},
  }},
  {profession="Fishing", items={
    {name="Fish Bowl", id=279967, skill=20, effect="8% increased stats for resting players; exclusive with Blessing of Kings.", reagents="Raw Brilliant Smallfish x1, Empty Vial x1"},
    {name="Fishing Rack", id=279965, skill=140, effect="Catch uncommon fish for 1 hour, provides Fishing Skill lures, and includes the Fish Bowl benefit.", reagents="Simple Wood x2, Crystal Vial x1, Raw Mithril Head Trout x2"},
    {name="Fishing Hut", id=279966, skill=300, effect="Catch rare fish for 1 hour, provides Fishing Skill lures, and includes the Fish Bowl benefit.", reagents="Simple Wood x5, Bolt of Runecloth x2, Seasonal Fish Steaks x1"},
  }},
}
