local _, FLT = ...

local SRC = FLT.DUNGEON_REGISTRY or {}

-- Level ranges: WoW Forever recommended ranges (Warcraft Tavern Forever dungeon
-- list; the new dungeons match the Wowhead Forever overview). They are stored
-- in the Data\Dungeons files; minLevel below only drives sorting/grouping.
-- Entrance coordinates: QuestieDB Forever (support/Forever/Zones/dungeons.lua).
-- coordsUnverified marks entrances that still need an in-game /ofa where check.
-- dataStatus: "forever" = Forever quests/loot recorded, "partial" = bosses only.
local META = {
  ["Hall of Thanes"] = {key="hall", short="Hall of Thanes", territory="Alliance", mapZone="Ironforge", mapX=27.63, mapY=47.83, betaNew=true, minLevel=13},
  ["Ragefire Chasm"] = {key="rfc", instanceID=389, territory="Horde", mapZone="Orgrimmar", mapX=52.6, mapY=49.0, minLevel=13},
  ["Ruins of Lordaeron"] = {key="lordaeron", territory="Horde", mapZone="Undercity", mapX=72.48, mapY=11.33, betaNew=true, minLevel=15, coordsUnverified=true},
  ["The Deadmines"] = {key="deadmines", instanceID=36, territory="Alliance", mapZone="Westfall", mapX=42.5, mapY=71.7, minLevel=15},
  ["Wailing Caverns"] = {key="wc", instanceID=43, territory="Horde", mapZone="The Barrens", mapX=46.0, mapY=36.5, minLevel=17},
  ["Shadowfang Keep"] = {key="sfk", instanceID=33, territory="Horde", mapZone="Silverpine Forest", mapX=44.8, mapY=67.8, minLevel=20},
  ["Blackfathom Deeps"] = {key="bfd", instanceID=48, territory="Contested", mapZone="Ashenvale", mapX=14.5, mapY=14.2, minLevel=22},
  ["Excavation Site: Wetlands"] = {key="excavation", short="Excavation Site", territory="Contested", mapZone="Wetlands", mapX=47.79, mapY=56.16, betaNew=true, minLevel=26, coordsUnverified=true},
  ["The Stockade"] = {key="stockade", instanceID=34, territory="Alliance", mapZone="Stormwind City", mapX=52.41, mapY=70.01, minLevel=25, coordsUnverified=true},
  ["City of Dalaran"] = {key="dalaran", territory="Contested", mapZone="Alterac Mountains", mapX=8.46, mapY=59.21, betaNew=true, minLevel=28, dataStatus="partial", coordsUnverified=true},
  ["Gnomeregan"] = {key="gnomeregan", instanceID=90, territory="Alliance", mapZone="Dun Morogh", mapX=24.3, mapY=39.8, minLevel=29, coordsUnverified=true, openToBoth=true},
  ["Razorfen Kraul"] = {key="rfk", instanceID=47, territory="Horde", mapZone="The Barrens", mapX=42.9, mapY=90.2, minLevel=29, coordsUnverified=true},
  ["Scarlet Monastery: Library"] = {key="smlib", instanceID=189, short="SM: Library", uiMaps={303}, territory="Horde", mapZone="Tirisfal Glades", mapX=82.6, mapY=33.8, minLevel=33, coordsUnverified=true},
  ["Scarlet Monastery: Graveyard"] = {key="smgy", instanceID=189, uiMaps={302}, short="SM: Graveyard", territory="Horde", mapZone="Tirisfal Glades", mapX=82.6, mapY=33.8, minLevel=30, coordsUnverified=true},
  ["The Drowned City"] = {key="drowned", short="Drowned City", territory="Contested", mapZone="Stranglethorn Vale", betaNew=true, minLevel=35, dataStatus="partial"},
  ["Scarlet Monastery: Armory"] = {key="smarm", instanceID=189, short="SM: Armory", uiMaps={304}, territory="Horde", mapZone="Tirisfal Glades", mapX=82.6, mapY=33.8, minLevel=36, coordsUnverified=true},
  ["Razorfen Downs"] = {key="rfd", instanceID=129, territory="Horde", mapZone="The Barrens", mapX=49.0, mapY=93.9, minLevel=37, coordsUnverified=true},
  ["Scarlet Monastery: Cathedral"] = {key="smcath", instanceID=189, short="SM: Cathedral", uiMaps={305}, territory="Horde", mapZone="Tirisfal Glades", mapX=82.6, mapY=33.8, minLevel=38, coordsUnverified=true},
  ["Krol'dok Stronghold"] = {key="kroldok", territory="Contested", mapZone="Riverglades", betaNew=true, minLevel=40, dataStatus="partial"},
  ["Uldaman"] = {key="uldaman", instanceID=70, territory="Contested", mapZone="Badlands", mapX=44.6, mapY=12.1, minLevel=41, coordsUnverified=true},
  ["Zul'Farrak"] = {key="zf", instanceID=209, territory="Contested", mapZone="Tanaris", mapX=38.7, mapY=20.1, minLevel=44, coordsUnverified=true},
  ["Maraudon"] = {key="maraudon", instanceID=349, territory="Contested", mapZone="Desolace", mapX=29.1, mapY=62.5, minLevel=46, coordsUnverified=true},
  ["Alcaz Prison"] = {key="alcaz", territory="Contested", mapZone="Dustwallow Marsh", betaNew=true, minLevel=48, dataStatus="partial"},
  ["The Temple of Atal'Hakkar"] = {key="st", instanceID=109, short="Sunken Temple", territory="Contested", mapZone="Swamp of Sorrows", mapX=69.9, mapY=53.5, minLevel=50, coordsUnverified=true},
  ["Blackrock Depths"] = {key="brd", instanceID=230, territory="Contested", mapZone="Searing Gorge", mapX=34.8, mapY=85.3, minLevel=52, coordsUnverified=true},
  ["Dire Maul: East"] = {key="dme", instanceID=429, short="DM: East", territory="Contested", mapZone="Feralas", mapX=59.2, mapY=45.1, minLevel=54, coordsUnverified=true},
  ["Lower Blackrock Spire"] = {key="lbrs", instanceID=229, short="LBRS", territory="Contested", mapZone="Searing Gorge", mapX=34.8, mapY=85.3, minLevel=55, coordsUnverified=true},
  ["Blackmaw Hold"] = {key="blackmaw", territory="Contested", mapZone="Azshara", betaNew=true, minLevel=55, dataStatus="partial"},
  ["Dire Maul: West"] = {key="dmw", instanceID=429, short="DM: West", territory="Contested", mapZone="Feralas", mapX=59.2, mapY=45.1, minLevel=56, coordsUnverified=true},
  ["Dire Maul: North"] = {key="dmn", instanceID=429, short="DM: North", territory="Contested", mapZone="Feralas", mapX=59.2, mapY=45.1, minLevel=56, coordsUnverified=true},
  ["Scholomance"] = {key="scholo", instanceID=289, territory="Contested", mapZone="Western Plaguelands", mapX=69.7, mapY=73.2, minLevel=58, coordsUnverified=true},
  ["Stratholme"] = {key="strat", instanceID=329, territory="Contested", mapZone="Eastern Plaguelands", mapX=26.5, mapY=10.4, minLevel=58, coordsUnverified=true},
  ["Shaper's Terrace"] = {key="shapers", territory="Contested", mapZone="Un'Goro Crater", betaNew=true, minLevel=58, dataStatus="partial"},
  ["Upper Blackrock Spire"] = {key="ubrs", instanceID=229, short="UBRS", territory="Contested", mapZone="Searing Gorge", mapX=34.8, mapY=85.3, minLevel=59, coordsUnverified=true},
  -- Raids (Raids view of the Dungeons tab): size = players, raidStatus as announced by Blizzard,
  -- attunement "unknown" = not known yet (Onyxia's comes from Data\RaidAttunements.lua)
  ["Barrow Deeps"] = {key="barrow", raid=true, size=10, raidStatus="New raid, opens 9 December 2026", territory="Contested", mapZone="Mount Hyjal", betaNew=true, minLevel=60, dataStatus="partial", attunement="unknown"},
  ["Hyjal Summit"] = {key="hyjal", raid=true, size=20, raidStatus="New raid, opens 9 December 2026", territory="Contested", mapZone="Mount Hyjal", betaNew=true, minLevel=60, dataStatus="partial", attunement="unknown"},
  ["Onyxia's Lair"] = {key="onyxia", instanceID=249, raid=true, size=40, raidStatus="Opens 9 December 2026", territory="Contested", mapZone="Dustwallow Marsh", mapX=52.6, mapY=76.8, minLevel=60, coordsUnverified=true},
}

-- Sorted by minimum level (then name). The browse list groups these into
-- collapsible level brackets.
local ORDER = {}
for name in pairs(META) do ORDER[#ORDER+1] = name end
table.sort(ORDER, function(a, b)
  local la, lb = META[a].minLevel or 0, META[b].minLevel or 0
  if la ~= lb then return la < lb end
  return a < b
end)

local function itemRec(tuple)
  if type(tuple) ~= "table" then return {name=tostring(tuple or "Unknown item")} end
  -- Dungeon loot tuples are {itemID, name, slot, quality}.
  -- Quest reward tuples are often {itemID, name, quality}.
  -- Treat a numeric third field as quality rather than a display slot/count.
  if type(tuple[3]) == "number" and tuple[4] == nil then
    return {id=tuple[1], name=tuple[2], quality=tuple[3]}
  end
  return {id=tuple[1], name=tuple[2], slot=tuple[3], quality=tuple[4]}
end

local function convertQuest(q)
  local rewards={}
  for _,it in ipairs(q.rewardItems or {}) do rewards[#rewards+1]=itemRec(it) end
  local noteRewards={}
  for _,it in ipairs(q.noteRewardItems or {}) do noteRewards[#noteRewards+1]=itemRec(it) end
  local class=q.class or q.classOnly
  if type(class)=="string" then class=class:upper() end
  return {
    id=q.id,
    name=q.name,
    level=q.level,
    required=q.requires or q.level,
    side=q.faction or "Both",
    class=class,
    starts=q.pickup,
    objective=q.objective,
    turnin=q.turnin,
    prereq=q.prerequisite or q.prereq,
    note=q.note,
    rewards=rewards,
    noteRewards=noteRewards,
    rewardChoice=q.rewardChoice,
    rewardSummary=q.rewardSummary or q.rewards,
    startItem=q.startItem and itemRec(q.startItem) or nil,
    noteItem=q.noteItem and itemRec(q.noteItem) or nil,
    liveXPFallback=q.liveXPFallback,
  }
end

local function convertBoss(b)
  local loot={}
  for _,it in ipairs(b.loot or {}) do loot[#loot+1]=itemRec(it) end
  return {
    name=b.name,
    npcID=b.npcID,
    rare=b.rare,
    description=b.description,
    icon=b.icon,
    customIcon=b.customIcon,
    customPortrait=b.customPortrait,
    displayID=b.displayID,
    worldDropsOnly=b.worldDropsOnly,
    aliases=b.aliases,
    loot=loot,
  }
end

FLT.DUNGEONS={}
FLT.DUNGEON_ITEM_DB=FLT.DUNGEON_ITEM_DB or {}
for _,name in ipairs(ORDER) do
  local s=SRC[name]
  local m=META[name] or {}
  if s then
    local d={
      key=m.key or name,
      name=name,
      short=m.short,
      level=s.level or "?",
      area=s.location or m.mapZone or "Unknown",
      territory=m.territory or "Contested",
      side=m.territory or "Contested", -- compatibility with existing UI helpers
      betaNew=m.betaNew,
      minLevel=m.minLevel,
      maxLevel=tonumber(tostring(s.level or ""):match("%-(%d+)")),
      coordsUnverified=m.coordsUnverified,
      openToBoth=m.openToBoth,
      instanceID=m.instanceID,
      uiMaps=m.uiMaps,
      dataStatus=m.dataStatus or "forever",
      mapZone=m.mapZone,
      mapX=m.mapX,
      mapY=m.mapY,
      raid=m.raid,
      size=m.size,
      raidStatus=m.raidStatus,
      attunement=m.attunement,
      description=s.description,
      icon=s.icon,
      bosses={},
      quests={},
      bossLoot={},
      trashLoot={},
    }
    for _,b in ipairs(s.bosses or {}) do
      local cb=convertBoss(b)
      d.bosses[#d.bosses+1]=cb
      d.bossLoot[cb.name]=cb.loot
      for _,it in ipairs(cb.loot) do
        if it.name and not FLT.DUNGEON_ITEM_DB[it.name] then FLT.DUNGEON_ITEM_DB[it.name]={id=it.id,quality=it.quality,summary=it.slot} end
      end
    end
    for _,it in ipairs(s.trashLoot or {}) do
      local rec=itemRec(it)
      d.trashLoot[#d.trashLoot+1]=rec
      if rec.name and not FLT.DUNGEON_ITEM_DB[rec.name] then FLT.DUNGEON_ITEM_DB[rec.name]={id=rec.id,quality=rec.quality,summary=rec.slot} end
    end
    for _,q in ipairs(s.quests or {}) do
      local cq=convertQuest(q)
      d.quests[#d.quests+1]=cq
      for _,it in ipairs(cq.rewards or {}) do
        if it.name and not FLT.DUNGEON_ITEM_DB[it.name] then FLT.DUNGEON_ITEM_DB[it.name]={id=it.id,quality=it.quality,summary=it.slot} end
      end
      for _,it in ipairs(cq.noteRewards or {}) do
        if it.name and not FLT.DUNGEON_ITEM_DB[it.name] then FLT.DUNGEON_ITEM_DB[it.name]={id=it.id,quality=it.quality,summary=it.slot} end
      end
    end
    FLT.DUNGEONS[#FLT.DUNGEONS+1]=d
  end
end

-- The raw registry tables are copied into FLT.DUNGEONS above; drop them so
-- the data is not kept twice in memory.
SRC = nil
FLT.DUNGEON_REGISTRY = nil

-- Boss levels (QuestieDB Forever data; Forever dungeons from foreverchanges.pro). Bosses
-- without an NPC ID are keyed by name. Missing ones (unreleased dungeons)
-- their level is learned in game when you target them (OneForAllDB.bossInfo).
FLT.BOSS_LEVELS = {
  -- Blackrock Depths
  [9025] = "51", -- Lord Roccor
  [9018] = "52", -- High Interrogator Gerstahn
  [9319] = "52", -- Houndmaster Grebmar
  [9031] = "54", -- Anub'shiah
  [9029] = "54", -- Eviscerator
  [9027] = "56", -- Gorosh the Dervish
  [9028] = "54", -- Grizzle
  [9032] = "53", -- Hedrum the Creeper
  [9030] = "53", -- Ok'thor the Breaker
  [9024] = "52", -- Pyromancer Loregrain
  [9017] = "55", -- Lord Incendius
  [9041] = "56", -- Warder Stilgiss
  [9042] = "55", -- Verek
  [9056] = "54", -- Fineous Darkvire
  [9016] = "54", -- Bael'Gar
  [9033] = "57", -- General Angerforge
  [8983] = "57", -- Golem Lord Argelmach
  [9537] = "55", -- Hurley Blackbreath
  [9502] = "55", -- Phalanx
  [9499] = "55", -- Plugger Spazzring
  [9156] = "57", -- Ambassador Flamelash
  [8923] = "57", -- Panzor the Invincible
  [9039] = "56", -- Doom'rel
  [9035] = "55", -- Anger'rel
  [9938] = "57", -- Magmus
  [8929] = "58", -- Princess Moira Bronzebeard
  [9019] = "59", -- Emperor Dagran Thaurissan
  -- Dire Maul: East
  [14354] = "57", -- Pusillin
  [11490] = "57", -- Zevrim Thornhoof
  [13280] = "57", -- Hydrospawn
  [14327] = "57", -- Lethtendris
  [11492] = "58", -- Alzzin the Wildshaper
  [16097] = "60", -- Isalien
  -- Dire Maul: North
  [14326] = "59", -- Guard Mol'dar
  [14322] = "59", -- Stomper Kreeg
  [14321] = "59", -- Guard Fengus
  [14323] = "59", -- Guard Slip'kik
  [14325] = "61", -- Captain Kromcrush
  [14324] = "60", -- Cho'Rush the Observer
  [11501] = "61-62", -- King Gordok
  [14353] = "60", -- Mizzle the Crafty
  -- Dire Maul: West
  [11489] = "60", -- Tendris Warpwood
  [11488] = "60", -- Illyanna Ravenoak
  [11487] = "60", -- Magister Kalendris
  [11467] = "59", -- Tsu'zee
  [11496] = "61", -- Immol'thar
  [11486] = "60-61", -- Prince Tortheldrin
  [14506] = "62", -- Lord Hel'nurath
  [14690] = "60", -- Revanchion
  -- Lower Blackrock Spire
  [9196] = "59", -- Highlord Omokk
  [9219] = "57", -- Spirestone Butcher
  [9218] = "58", -- Spirestone Battle Lord
  [9217] = "58", -- Spirestone Lord Magus
  [9236] = "58", -- Shadow Hunter Vosh'gajin
  [9237] = "58", -- War Master Voone
  [10596] = "59", -- Mother Smolderweb
  [10376] = "60", -- Crystal Fang
  [10584] = "60", -- Urok Doomhowl
  [9736] = "59", -- Quartermaster Zigris
  [10220] = "59", -- Halycon
  [10268] = "60", -- Gizrul the Slavener
  [9718] = "59", -- Ghok Bashguud
  [9596] = "59", -- Bannok Grimaxe
  [10263] = "56-57", -- Burning Felguard
  [9568] = "60", -- Overlord Wyrmthalak
  -- Scholomance
  [10506] = "60", -- Kirtonos the Herald
  [10503] = "61", -- Jandice Barov
  [11622] = "61", -- Rattlegore
  [10433] = "58", -- Marduk Blackpool
  [10432] = "60", -- Vectus
  [10508] = "62", -- Ras Frostwhisper
  [10505] = "60", -- Instructor Malicia
  [11261] = "60", -- Doctor Theolen Krastinov
  [10901] = "60", -- Lorekeeper Polkelt
  [10507] = "60", -- The Ravenian
  [10504] = "60", -- Lord Alexei Barov
  [10502] = "60", -- Lady Illucia Barov
  [14695] = "60", -- Lord Blackwood
  [16118] = "58-60", -- Kormok
  [14516] = "62", -- Death Knight Darkreaver
  [1853] = "61", -- Darkmaster Gandling
  -- Stratholme
  [10393] = "58", -- Skul
  [10558] = "57", -- Hearthsinger Forresten
  [11082] = "57", -- Stratholme Courier
  [10516] = "57", -- The Unforgiven
  [10808] = "58", -- Timmy the Cruel
  [11143] = "60", -- Postmaster Malown
  [10997] = "60", -- Cannon Master Willey
  [10811] = "60", -- Archivist Galford
  [10813] = "62", -- Balnazzar
  [10435] = "58", -- Magistrate Barthilas
  [10809] = "60", -- Stonespine
  [10436] = "59", -- Baroness Anastari
  [10437] = "60", -- Nerub'enkan
  [10438] = "61", -- Maleki the Pallid
  [10439] = "61", -- Ramstein the Gorger
  [10440] = "62", -- Baron Rivendare
  [14684] = "60", -- Balzaphon
  -- Upper Blackrock Spire
  [9816] = "60", -- Pyroguard Emberseer
  [10509] = "59", -- Jed Runewatcher
  [10264] = "60", -- Solakar Flamewreath
  [10899] = "61", -- Goraluk Anvilcrack
  [10339] = "62", -- Gyth
  [10429] = "62", -- Warchief Rend Blackhand
  [10430] = "62", -- The Beast
  [10363] = "62", -- General Drakkisath
  -- Maraudon
  [13282] = "48", -- Noxxion
  [12258] = "48", -- Razorlash
  [12236] = "47", -- Lord Vyletongue
  [12237] = "48", -- Meshlok the Harvester
  [12225] = "49", -- Celebras the Cursed
  [12203] = "50", -- Landslide
  [13601] = "50", -- Tinkerer Gizlock
  [13596] = "50", -- Rotgrip
  [12201] = "51", -- Princess Theradras
  [13738] = "47", -- Veng
  [13739] = "46", -- Maraudos
  -- Razorfen Downs
  [7355] = "40", -- Tuten'kash
  [7357] = "39", -- Mordresh Fire Eye
  [8567] = "40", -- Glutton
  [7354] = "40", -- Ragglesnout
  [7356] = "40", -- Plaguemaw the Rotting
  [7358] = "41", -- Amnennar the Coldbringer
  -- Scarlet Monastery: Armory
  [3975] = "40", -- Herod
  -- Scarlet Monastery: Cathedral
  [4542] = "40", -- High Inquisitor Fairbanks
  [3976] = "42", -- Scarlet Commander Mograine
  [3977] = "42", -- High Inquisitor Whitemane
  -- The Temple of Atal'Hakkar
  [8580] = "50", -- Atal'alarion
  [5712] = "51", -- Atal'ai Defenders
  [5708] = "51", -- Spawn of Hakkar
  [8443] = "49-50", -- Avatar of Hakkar
  [5710] = "54", -- Jammal'an the Prophet
  [5711] = "53", -- Ogom the Wretched
  [5721] = "53", -- Dreamscythe
  [5720] = "51", -- Weaver
  [5719] = "52", -- Morphaz
  [5722] = "53", -- Hazzas
  [5709] = "55", -- Shade of Eranikus
  -- Uldaman
  [6910] = "40", -- Revelosh
  [6906] = "41", -- Baelog
  [6907] = "40", -- Eric "The Swift"
  [6908] = "40", -- Olaf
  [7228] = "40", -- Ironaya
  [7023] = "42", -- Obsidian Sentinel
  [7206] = "44", -- Ancient Stone Keeper
  [7291] = "45", -- Galgann Firehammer
  [4854] = "45", -- Grimlok
  [2748] = "47", -- Archaedas
  -- Zul'Farrak
  [8127] = "48", -- Antu'sul
  [7272] = "46", -- Theka the Martyr
  [7271] = "46", -- Witch Doctor Zum'rah
  [7796] = "46", -- Nekrum Gutchewer
  [7275] = "47", -- Shadowpriest Sezz'ziz
  [7604] = "45", -- Sergeant Bly
  [7795] = "46", -- Hydromancer Velratha
  [7273] = "46", -- Gahz'rilla
  [7267] = "48", -- Chief Ukorz Sandscalp
  [7274] = "46", -- Sandfury Executioner
  [10082] = "45", -- Zerillis
  [10080] = "45", -- Sandarr Dunereaver
  [10081] = "45", -- Dustwraith
  -- Blackfathom Deeps
  [4829] = "28", -- Aku'mai
  [12876] = "28", -- Baron Aquanis
  [6243] = "26", -- Gelihast
  [4887] = "25", -- Ghamoo-ra
  [4831] = "25", -- Lady Sarevess
  [12902] = "26", -- Lorgus Jett
  [4830] = "26", -- Old Serra'kis
  [4832] = "27", -- Twilight Lord Kelris
  -- Gnomeregan
  [6229] = "32", -- Crowd Pummeler 9-60
  [6228] = "33", -- Dark Iron Ambassador
  [6235] = "32", -- Electrocutioner 6000
  [7361] = "32", -- Grubbis
  [7800] = "34", -- Mekgineer Thermaplugg
  [7079] = "30", -- Viscous Fallout
  -- Ragefire Chasm
  [11519] = "16", -- Bazzalan
  [11518] = "16", -- Jergosh the Invoker
  [11517] = "16", -- Oggleflint
  [11520] = "16", -- Taragaman the Hungerer
  -- Razorfen Kraul
  [6168] = "28", -- Roogug
  [4424] = "30", -- Aggem Thorncurse
  [4428] = "30", -- Death Speaker Jargba
  [4420] = "32", -- Overlord Ramtusk
  [4422] = "33", -- Agathelos the Raging
  [4425] = "32", -- Blind Hunter
  [4842] = "32", -- Earthcaller Halmgar
  [4421] = "33", -- Charlga Razorflank
  -- Scarlet Monastery: Library
  [3974] = "34", -- Houndmaster Loksey
  [6487] = "37", -- Arcanist Doan
  -- Scarlet Monastery: Graveyard
  [6490] = "33", -- Azshir the Sleepless
  [4543] = "34", -- Bloodmage Thalnos
  [6488] = "33", -- Fallen Champion
  [3983] = "32", -- Interrogator Vishas
  [6489] = "33", -- Ironspine
  [14693] = "34", -- Scorn
  -- Shadowfang Keep
  [4275] = "26", -- Archmage Arugal
  [4627] = "24-25", -- Arugal's Voidwalker
  [3887] = "24", -- Baron Silverlaine
  [4278] = "24", -- Commander Springvale
  [3872] = "25", -- Deathsworn Captain
  [3864] = "19-20", -- Fel Steed / Shadow Charger
  [4274] = "25", -- Fenrus the Devourer
  [4279] = "24", -- Odo the Blindwatcher
  [3886] = "22", -- Razorclaw the Butcher
  [3914] = "20", -- Rethilgore
  [14682] = "25", -- Sever
  [3927] = "25", -- Wolf Master Nandos
  -- The Deadmines
  [647] = "20", -- Captain Greenskin
  [645] = "20", -- Cookie
  [639] = "21", -- Edwin VanCleef
  [1763] = "20", -- Gilnid
  [3586] = "19", -- Miner Johnson
  [646] = "20", -- Mr. Smite
  [644] = "19", -- Rhahk'Zor
  [643] = "20", -- Sneed
  [642] = "20", -- Sneed's Shredder
  -- The Stockade
  [1716] = "29", -- Bazil Thredd
  [1720] = "26", -- Bruegal Ironknuckle
  [1663] = "26", -- Dextren Ward
  [1717] = "28", -- Hamhock
  [1666] = "27", -- Kam Deepfury
  [1696] = "24", -- Targorr the Dread
  -- Wailing Caverns
  [5912] = "20", -- Deviate Faerie Dragon
  [3653] = "20", -- Kresh
  [3671] = "20", -- Lady Anacondra
  [3669] = "20", -- Lord Cobrahn
  [3670] = "21", -- Lord Pythas
  [3673] = "21", -- Lord Serpentis
  [3654] = "22", -- Mutanus the Devourer
  [3674] = "21", -- Skum
  [5775] = "21", -- Verdan the Everliving
  -- Forever dungeons (foreverchanges.pro boss pages, 16.10.2026)
  -- Hall of Thanes (wowforeverguides.com / wow4ever.quest "level 16", 22.10.2026)
  [261306] = "16", -- Faldrim Anvilmar
  [261316] = "16", -- Magmatus
  [261311] = "16", -- Plunder
  [261319] = "16", -- Durgen Dirgehammer
  -- Ruins of Lordaeron
  [250660] = "17", -- The Baron
  [250483] = "17", -- Witherfang
  [250631] = "18", -- The Abandoned
  [256097] = "19", -- Bjork
  [250657] = "20", -- Rath'mael
  [256035] = "19", -- Viktor the Vile
  -- Excavation Site: Wetlands
  [260322] = "28", -- Saltspine
  [260325] = "29", -- Shadetooth
  [260808] = "28", -- Highland Horror (also Wowhead Forever)
  [260326] = "31", -- Relic Guardian
  -- City of Dalaran
  [247126] = "29", -- Atrexis the Grave Knight
  [247032] = "31", -- Lyn the Ignored
  [245999] = "30", -- Arcane Anomaly
  ["Arcanic Enigma"] = "30", -- no NPC ID in our data yet: by name
  [246017] = "31", -- Unstable Sentinel
  [246008] = "31", -- Mana Devourer
  [246003] = "32", -- Fel Ancient
  [246020] = "33", -- Shade of the Archmage
}
