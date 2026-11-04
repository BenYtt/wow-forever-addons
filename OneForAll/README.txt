OneForAll
=========

Standalone WoW Forever companion addon: dungeons (bosses, loot, quests),
armory (item sets, reputation rewards), Library Books tracker, Merchant's Favor recipes, camping buffs, hunter pets
and an in-addon talent planner. No other addons are required.

Commands
--------
/oneforall or /ofa       Open/close the addon
/oneforall debug         Show unverified Library Book quest flags
/oneforall bank          Explain bank scanning
/oneforall profdata      Show embedded profession-data status
/oneforall portraits     Show which source each boss portrait came from
/oneforall craft         Open/close the Crafting List
/oneforall setup         Open the welcome setup again
/oneforall where         Print the current map and coordinates (to report wrong map pins)
/oneforall reset         Reset manual Library Book marks
/oneforall tabs reset    Show the default tabs again for this character
/oneforall share test    Preview the quest share popup without a group
/oneforall share         Open the quest share popup (inside a dungeon, in a group)
/oneforall channel      State of the recipe channel with other OneForAll users
/oneforall bug          Show the link for bug reports and ideas
/oneforall rolltest     Show the loot roll window with an example item
/oneforall questtest    Open the quest log at a quest with a gear reward
/oneforall cheapest     Show the cheapest item in your bags
/oneforall buttons      List the minimap buttons the button collector holds
/oneforall trainer      Show what the last class trainer visit read
/oneforall errors       Show errors OneForAll caught (for bug reports); "errors clear" empties the list
/oneforall mem          Show how much memory OneForAll uses right now
/oneforall thanks       Show the last buffs seen by "Thanks for buffs"
/oneforall talentdump    Save all talent IDs to the SavedVariables (for the addon author)
/oneforall scale [n]     Set the window size (60-140 or 0.6-1.4); without a value: reset to 100 %

License
-------
Copyright (C) 2026 Smoergi

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.txt for details.

Third-party data attribution is in THIRD_PARTY_LICENSES.txt.
Dungeon data sources are listed in DUNGEON_DATA_SOURCES.txt.


Code layout
-----------
Data files       Data.lua, ExtraData.lua, ProfessionData.lua, DungeonData.lua
Dungeons         Data/Dungeons/<Name>.lua - one file per dungeon (quests, bosses, loot);
                 Data/DungeonQuestChains.lua - prerequisite chains (optional = true marks
                 lead-ins that do not block); DungeonData.lua - entrance, territory,
                 level sorting. New dungeon: add a file, list it in OneForAll.toc,
                 add its META entry in DungeonData.lua and its art in UI/Dungeons.lua.
Logic            Core.lua (events, bags/bank, slash commands), ProfessionRuntime.lua,
                 Map.lua (world-map pin), Proximity.lua (nearby book alerts), Minimap.lua
UI/Widgets.lua   Shared buttons/textures/banners + panel registry
UI/MainFrame.lua Main window and tab bar
UI/<Tab>.lua     One file per tab: General, Dungeons (+ DungeonHelpers, DungeonPortraits),
                 Books, Professions
Talents          TalentData.lua (layouts of all 9 classes), TalentSpellIDs.lua (spell ID ->
                 talent name; regenerate from /ofa talentdump after a talent patch), TalentPlanner.lua (the tab), TalentLayoutFallback.lua
                 (only used if the client talents cannot be matched to TalentData.lua)
New tab: create a file, call FLT.UI.RegisterPanel{key=, label=, order=, tabWidth=, create=}
and add the file to OneForAll.toc before UI\MainFrame.lua.


Changelog (newest first)
========================

6.1.0 - Recipe search, launch talents, wishlist tools
======================================================
Ready for the WoW Forever launch: a recipe search that stays fast with many
players, the talent trees of the launch patch and handy wishlist tools.
Recipes of other OneForAll users
- New "Search" button in Professions > All recipes: asks the other OneForAll
  users who know the recipe (a new hidden channel). Only a few of them answer,
  so the channel stays quiet and fast however many players use OneForAll.
  Players in your zone are found first. Shows "Searching", the players with
  level, class and zone, and "Search again" (after 30 seconds, with a countdown).
- Players found before show up at once while they are online (blue check in the
  list). Recipe lists are no longer sent to the channel; the online status is
  sent less often when many players are online. Guild sharing stays as it was,
  and a guild list now replaces the stored one only when it arrived complete.
- "Share recipes with other OneForAll users" moved from Settings to Quality of
  Life > Social. /ofa channel shows more numbers.
- Note: 6.0 and 6.1 users no longer see each other's recipes - please update.
Talents
- Talent trees of the launch patch (talentsforever.com, 03.11.): Rogue, Warrior,
  Shaman (e.g. Call of Thunder instead of Lava Burst), Paladin, Druid, Mage,
  Priest and Hunter. Trainer and quest data refreshed. Old Paladin and Warrior
  build links no longer fit and are refused.
Gear Planner
- Item tooltips show "OFA (star) Wishlist" for items on your wishlist.
- Wishlist: "Clear wishlist" with "Clear all" and "Clear smart" (only items that
  are no upgrade any more), both ask first; "All slots" shows the whole wishlist.
Quality of Life
- Buff reminder: weapon items are suggested from 2 letters on, also when none is
  in your bags (sharpening stones, weightstones, oils; poisons for rogues); a
  note that any buff name can be added; "sec" next to the seconds. Blessing of
  Light and Salvation removed from the Paladin presets.
- Sell junk checks each item again right before it is sold.
- Option tooltips open below the option and only over its name and text;
  drop-down menus grow with their longest entry.
Other
- The main window banner fades out softly on the left, without a line under it.
- Fixes: special bags in the bag helper, hunter options in the welcome setup,
  item quality in the Crafting List, wand check in the enchant score.

6.0.3 - Buff reminder update and quest fixes
==============================================
A bigger buff reminder, quest marks for loot quests and many small fixes.
Buff reminder
- Size slider and a Test button (shows the reminder for 10 seconds to place it).
- "Show icon only": the icon with the time left and a bar as wide as the icon.
- No frame around the cards any more.
- Works in combat too (the icon can only be clicked out of combat); a buff you
  cast again in combat removes its card at once.
- Weapon oils, sharpening stones and poisons: type the item's name and pick
  "(main hand)" or "(off hand)"; time left and charges, a click uses the item.
- Suggestions for items in your bags; flasks: use the buff's name.
Quests
- Quest marks on nameplates also show mobs that drop quest items (bag mark).
- New option (on): a gold coin on the quest reward with the best sell price.
- Gear Planner and class quests use quest data with all QuestieDB corrections
  for WoW Forever (right faction for some druid quests, fixed pre-quests).
World map
- Icons that sit on a dungeon entrance (like a Library Book) move next to it.
- Flight masters use the game's own icon.
- The OneForAll map marker (e.g. from Library Books) can be removed by a click.
Quality of Life
- Preview pictures for 14 more options; tooltips in one fixed column.
- Move Blizzard windows: also the AddOns, Options, Customer Support and Game
  Menu windows.

6.0.2 - Quests on the world map
=================================
Quest icons, level ranges and zone transitions on the world map, quick quest
sharing in dungeons and a smarter Gear Planner.
World map
- Quest icons (on by default, Quality of Life > World Map > Quests): a yellow !
  at quest givers with quests for your level, a ? where you turn in finished
  quests. The tooltip lists the quests with their level and the levels in which
  they still give experience, e.g. "[8] Practical Prey (5-13)". Walking quest
  givers show their route. Hidden while Questie is loaded.
- The zone's level range at the top right of the map and behind the zone name
  when you hover a zone on the continent map (on by default).
- Map Landmarks: zone transitions - a signpost where a road leads into the next
  zone; the tooltip names it, a click shows it (places from Carbonite, GPL).
  Calmer icon sizes; dungeon and raid entrances always on top.
- A OneForAll button at the top left of the map (below other addons' buttons
  like RareScanner) with all World Map switches in a small list.
- Remove Fog: a slider for how visible the unexplored parts are (0-100 %).
Dungeons & quests
- Dungeons & Raids > Quests: "Share all Quests" shares, one after the other,
  the quests of that dungeon a group member is missing and can take - also
  outside the dungeon.
- Quality of Life > Quests: "Quest marks on nameplates" (off by default) - a
  sword on mobs you must kill, a bag on mobs that drop a quest item, with your
  progress (3/10); position left, top left, top, top right or right (default).
  Works in every game language; not inside dungeons yet.
Gear Planner
- Source filter right of "All", several sources at once, new source "Crafted";
  crafted Bind on Pickup items only for your own professions.
- Crafted items show their profession; a click opens the recipe.
- Quest rewards count from the level you can take the quest at; items without
  a required level are listed again; the list title shows the sources on mouseover.
Talent Trees
- Import: buttons for talentsforever.com and wowforevertalents.com put the link
  into the field, selected, so Ctrl+C copies it; the field empties afterwards.
More
- Tooltips: new option to hide the blue "You haven't collected this appearance"
  line (off by default).
- Quality of Life: the option rows are a little closer together.
- Welcome setup: resize Blizzard windows, short green stats and quest marks
  can be switched on there too.
- Noteworthy changes updated (/ofa news or Settings > Window).
- Resize Blizzard windows: the "%" display no longer stays on screen.

6.0.1 - A new look, profiles and buff reminders
================================================
A new look for the whole window and a set of new helpers.

New look
- A banner with the logo across the top, the tabs below it in a browser style;
  the Settings tab is a gear at the right end.
- Every tab has the same list on the left with its emblem on top; no more boxes
  around the parts of a page, fine lines between them instead. Switches instead
  of checkboxes, thin scroll bars, thinner lines; popups get the window's frame.
- Quality of Life, Dungeons & Raids and Hunter Pets have a head with a search.
  Dungeons: names, zones and bosses. Hunter Pets: one search over families,
  abilities and rare tames.
- Talent Trees: larger trees, the preset actions (save, reset, import, export)
  in the list on the left.
- Map buttons in lists are a small map symbol now; the dungeon / raid page keeps
  a real "Map" button.
- Quality of Life: Chat has its own entry in the list.
- Welcome setup: gold arrows on Back / Next. Lists you can remove entries from
  (watched buffs, kept low ranks) show a red cross.
- Logo color: new "Bronze", picked by clicking the logos. The card logo of the
  minimap button collector no longer has dark corners.

Profiles (Settings > Profiles)
- A profile holds the Settings and Quality of Life options and the shown tabs
  with their order; every character picks its own (new characters: Default).
  New, Copy, Rename, Delete, Export / Import as text, or Send to a player who
  has "Receive" switched on (off by default; they are asked first).
- After the update every character starts on "Default". The shown tabs were
  saved per character before and are part of the profile now.

Quality of Life
- Buff reminder (off by default): add your own buffs with a time in seconds;
  a small card shows when one runs low or out - click its icon to cast it
  again. Up to 4 cards, off in combat, "Sleep in cities" keeps it quiet in the
  capitals. Name suggestions while typing.
- Chat > Message history (on by default): arrow up / down in the chat box
  brings back your last 5 messages.
- Short green stats (off by default): long "Equip:" lines become "+1% Hit",
  "+9 Spell Healing" and so on.
- Hide error messages (off by default): no red "Out of range" messages; full
  bags, a full quest log and not enough money are still shown.
- Resize Blizzard windows (off by default): right mouse button + drag; also the
  Looking For Group window can now be moved and resized.
- Arrow color by armor type (off by default): a yellow arrow for upgrades in a
  lighter armor type than your class's best.
- Map Landmarks: Skyborne ley lines and elemental convergences on the world
  map (on for Skyborne, locations from "Skyborne Leyline & Convergence Marker"
  by tr0tsky, MIT).
- "Compare items only with Shift" is now "Disable automatic compare tooltip".

Professions & Armory
- Skill-up chance in % on yellow and green recipes; known recipes show how many
  you can make with the reagents in your bags, e.g. "Copper Rod (2)".
- Gear Planner: the picture of your race behind your character; your own gear
  no longer shows a comparison with itself.
- Dungeon / raid page: a real "Map" button next to Bosses & Loot.

Fixes
- The window could not be closed in combat after a recipe with a Craft button
  was shown.

6.0.0 - Ready for the launch of WoW Forever
==========================================
A fresh start: a welcome setup for everyone, a new logo, one look and many new
helpers. The yellow "!" marks are gone; new things start clean from here.

Welcome & look
- A welcome setup, shown once to everyone: a few pages to switch on Quality of
  Life helpers right away (or skip it). "Recommended settings" switches on what
  OneForAll suggests. /ofa setup or Settings > Window opens it again.
- New logo: the minimap button is a round gold "1", the minimap button
  collector a gold card. Quality of Life > Minimap > "Logo color" picks
  turquoise (default), red, blue, green or violet.
- One look for everyone: the skins are gone, OneForAll always uses the gold
  modern style (an old skin choice is simply ignored).
- New Discord button in the title bar (and in the bug report window). The
  window height grip sits on the bottom edge of the window.

Talent Trees
- Import builds from talentsforever.com and wowforevertalents.com links, or
  from an OneForAll build string; Export shows your build as a short text.
- The game's own tree pictures behind the talents, more room between the
  talents, and talents without a point turn grey when all 51 are spent.

Trainer window (spellbook tab)
- Opens from a tab in the spellbook, like the spellbook's own tabs.
- Weapon skills: what a class can learn and the weapon masters of your faction.
- Class quests: the important quests of your class (pets, totems, forms,
  stances, class items) with your progress, a Chain button and Map pins, for
  the quest givers of your home city.

Professions
- Crafting List: plan what to craft with "+ List"; its own window shows the
  materials against your bags, bank and your other characters, breaks down
  what you can craft yourself and lists what you still need. "Craft" buttons,
  tooltips ("Crafting List: N more needed"), /ofa craft.
- Recipes in framed boxes, a "Craft" button for recipes you can craft.
- Nearest trainers knows the trainers on Zephras Isle.

Gear Planner
- Your own stat weights ("Edit custom weights..." in the spec list).
- A source filter: Bind on Equip, quest rewards, dungeon or raid drops.

Quality of Life
- Own junk list: Alt+right-click an item in your bags; "Sell junk" sells it,
  and it gets a junk coin in the game's bags and in Baganator (also when
  another addon such as RestedXP is Baganator's junk source).
- Hide chat: a button at the chat (on), a key (Key Bindings > OneForAll) and
  "Hide chat after" a quiet time (Never by default).
- Sparkle on herbs & ore (off by default; adapted from Lueur by Armytille, MIT).
- Minimap: square minimap, move the minimap (Shift-drag), hide the OneForAll
  button; the collector also takes MapUtils / D4Lib buttons.
- Move Blizzard windows also moves the newer windows of WoW Forever (world map,
  professions, spellbook, Combined Backpack ...), by their title bar.
- The tooltip of an option shows next to its name.

World Map
- Map Landmarks: Library Books on the map, the Deeprun Tram, the new boats of
  WoW Forever and the airships from Valanaar, with new icons.

Dungeons & Raids
- Plain list headers for quests and keys / attunements, like the boss list.

Fixes
- No more "blocked action" errors in combat from the profession window or the
  craft buttons; many smaller fixes.

5.7.2 - Item compare fixes
------------------------------------------------------------
- Upgrade / downgrade arrows compare the items' own stats only: an enchant on
  the worn item no longer counts.
- Items for other classes only ("Classes: Warlock") no longer get an arrow.

5.7.1 - Remove Fog, AddOns list
------------------------------------------------------------
- Quality of Life > World Map: new option "Remove Fog" (on by default) shows
  the parts of a zone you have not explored yet.
- OneForAll is in the game's AddOns list at the minimap too (handy with ElvUI
  or a hidden minimap button).

5.7.0 - New Quality of Life layout, enchants in the gear planner, set buttons
------------------------------------------------------------
- Quality of Life: groups on the left like Armory and Professions, one group
  at a time with a short description under every option, and a search over
  all settings. "Popups & Alerts" moved here from Settings (with Durability
  warning), "Dungeon map on M" moved to World Map, Quest XP to Quests.
- New option "Brighter colors" (Unit Frames, on): class-colored health bars
  use a plain bright bar instead of the game's dark art.
- Spellbook (P): a book button opens the trainer window (next spells and
  ranks for your class) next to it; it closes with the spellbook. Switch in
  Quality of Life > Spells (on).
- Gear Planner: a small field next to every item that can be enchanted or
  improved (enchants, armor kits, spurs, shield spikes, counterweights,
  scopes, arcanums, shoulder enchants) shows what is on it; a click lists what
  fits, best for your spec first, with where to get it, who knows the recipe,
  a button to the recipe in Professions and the wishlist star.
- Armory: Raid, Dungeon, PvP and Crafted Sets have buttons for their main sets
  and an "Other Sets" list for the rest; sets sorted with the highest level
  first.
- Professions: the Merchant's Favor button shows your Favor (the second box
  is gone); jumping to a recipe scrolls to it also the first time.
- Settings: "Window" moved to the right column.
- Quest sharing no longer posts an emote (option removed).
- New installs also start with Farther camera zoom and Move Blizzard windows.
- New "Noteworthy changes" popup; the "!" marks of 5.6 are gone, new ones
  show what is new in 5.7.

5.6.7 - Gear value fix, wishlist stars in the Armory, new client data
------------------------------------------------------------
- Gear Value: worn items with a random bonus ("of the Eagle" and the like)
  now count with their bonus stats, so items are no longer shown as huge
  upgrades over them. "(replaces ...)" is shown for upgrades only.
- Armory: item sets and reputation rewards have the wishlist star too (far
  right, like everywhere else).
- Armory, Professions and Talent Trees: the left side panel keeps its size in
  a taller window, and the talent points bar stays right under the trees.
- Trainer window: spell list from the new client build (new spells like
  Frost Blast and Arcane Wrath, new ranks, changed levels).
- Talent planner: Mage talents updated to the hotfix of October 20; spell IDs
  of the new talents, so non-English clients match them too.
- Hall of Thanes: boss levels (16).

5.6.6 - Upgrade arrows on quest rewards
------------------------------------------------------------
- Quest rewards: a green arrow on reward and choice items that are an
  upgrade, at the quest giver and in the quest log.
- /ofa questtest opens the quest log at one of your quests with a gear
  reward to check it.

5.6.5 - Upgrade marks and spec choice
------------------------------------------------------------
- Loot roll window: a gold star on wishlist items, a green arrow on upgrades.
- Bags (the game's bags and Baganator): a green arrow on items that are an
  upgrade you can wear now.
- Gear Planner: pick the spec the upgrades are calculated for (default: your
  active spec); druids can also pick Feral (Bear).
- /ofa rolltest shows the loot roll window with an example item.

5.6.4 - Gear Value fixes
------------------------------------------------------------
- Gear Value: spell damage of one school (shadow, fire, frost ...) now
  counts for the specs that use it; staffs and daggers of casters no longer
  count their weapon damage like a wand.
- Rings, trinkets and dual-wield weapons: the tooltip names the worn item
  the upgrade replaces (the weaker of the two).
- Gear Planner: legendary and other quest items in their quality color,
  shorter "lvl 13", the map icon without a frame, "Reset" in the corner.
- Armory > Reputation: click a standing band to fold its rewards.
- Recipes of other OneForAll users: a zone in another client language is no
  longer shown for players inside a dungeon.

5.6.3 - Gear Planner
------------------------------------------------------------
- Armory: new Gear Planner as the first page (the Overview is gone). Your
  character on the left (mouse wheel zooms, drag turns it, right-click an
  item to try it on); click a slot to see upgrades for it from dungeon loot,
  quest rewards of all quests, set pieces, reputation gear and crafted
  items - only what your class and faction can use, in a level range you
  choose ("My lvl" / "All").
- Every item shows how much better it is than what you wear, in %, for
  your talent spec (stat weights from Sharpie's Gear Judge). Item tooltips
  show it too: "OFA" with a green arrow "Upgrade: 30%" or a red arrow
  "Downgrade: 12%" (Quality of Life > Tooltips > Gear Value).
- Wishlist: the star on items in the Gear Planner and in Dungeons & Raids
  (loot and quest rewards). Search over all items.
- Quest rewards are marked with a yellow "!"; the map button shows the quest
  giver, "Chain" opens the whole quest chain (green = done, yellow = in your
  quest log). The dungeon swirl opens the boss that drops an item.
- Recipes of other OneForAll users: players show up right after login and
  stay after a /reload, new players are asked for their recipes directly,
  the channel join and throttled messages are retried, and dropped
  professions disappear. The hidden channel moves to the end of your channel
  list, so /1 is General again. /ofa channel shows the state.
- Fixed: opening another player's profession from a chat link no longer
  marks those recipes as known by you.
- Dungeon maps: the entrance is shown as the dungeon (or raid) swirl.
- Map Landmarks: icons stay above other addons' map icons.
- "Thank players who buff you" thanks after 1 second instead of 3.

5.6.2 - Map Landmarks, talents of the October 15 patch
------------------------------------------------------------
- Fixed: OneForAll wiped the data of "Forever Companion: Discovery Journal"
  when both were installed (same saved variable names from OneForAll's old
  name). OneForAll now saves under its own names; your settings are moved
  over automatically.
- New Quality of Life option "Map Landmarks" (on): icons on the world map for
  dungeon and raid entrances, flight masters, zeppelins and ships with their
  destinations. Click an entrance to open that dungeon in OneForAll,
  Shift-click for a map pin. Each part can be switched off.
- Talent planner updated to the October 15 beta patch (Priest, Shaman, Mage,
  Warlock, Warrior, Druid). Renamed talents are still found.
- "Thank players who buff you" works again: the player who buffed you is
  found even if he is not your target. Only buffs longer than 2 minutes,
  3 seconds later, not in combat and not after a loading screen.
- New install: the most useful Quality of Life helpers start switched on.
  Existing settings are not changed.
- Boss levels and boss/entrance positions on the maps of Ruins of Lordaeron,
  Excavation Site (now level 26-31), City of Dalaran and Hall of Thanes.
- Bug report window: GitHub or CurseForge, with your version, class, level and
  the last errors ready to copy.
- Less work in the background (animations only while something moves, bag
  changes redraw only the open tab), unused graphics removed.
- The minimap button collector is 10 % smaller.
- Noteworthy changes now cover all 5.6 versions and only appear when you come
  from a version before 5.6. The yellow "!" for new options sits left of the
  checkbox and stays for all 5.6 versions.

5.6.1 - Modern skins and low spell ranks
------------------------------------------------------------
- Two new skins: Gold Modern and Dark Silver Modern, with plain frames,
  dividers, buttons and boss rings with rounded corners. The brush button in
  the title bar opens a list of all four skins (also in Settings > Skin).
  This version switches everyone once to Gold Modern - pick another skin any
  time.
- Modern skins: Window opacity in Settings > Window (70-100 %, starts at
  95 %). Only the backgrounds fade, text and pictures stay solid.
- Dark Silver is a little brighter.
- New Quality of Life option "Check low spell ranks" (on): finds spells on
  your action bars that use a lower rank than one you already know and puts
  the highest rank there with one click. After a trainer visit it waits
  until you close the trainer. "Keep" leaves a rank you use on purpose alone.
- Class trainer window: shows everything your class can still learn up to
  level 60. The level bars no longer show an arrow.
- All popups share one look with the addon's own close button; the library
  books popup can be moved.
- A small click sound when you switch tabs.

5.6.0 - Armory and dungeon maps
------------------------------------------------------------
- New Armory tab (replaces General): raid, dungeon, PvP, crafted and world
  sets with class filter, owned pieces (bags, bank, equipped), set bonuses,
  required level and where each piece drops ("Show" opens the boss in
  Dungeons & Raids). Sets that are not in WoW Forever yet are marked. PvP
  includes the rank 14 weapons.
- Reputation rewards of every faction grouped by standing, with your standing
  and the vendor on the map.
- Dungeon maps for all dungeons and raids: boss portraits (click for the
  loot), entrance, zoom and drag. Inside a dungeon the world map key (M) opens
  its map (Settings > Dungeons | Raids). Map layout from Forever Simple World
  Map by Tarolg.
- New tab order (Armory, Dungeons & Raids, Professions, Quality of Life,
  Talent Trees, Library Books, Hunter Pets); the window opens on the tab you
  used last.
- New banners for Armory and Talent Trees.

5.5.1 - combat errors fixed
------------------------------------------------------------
- Fixed Lua errors in combat when nameplates are shown ("secret" values in
  boss portraits and class colours). Class colours no longer touch nameplate
  health bars.
- Event handlers are protected: if something goes wrong, the error is caught
  instead of popping up again and again. /ofa errors lists the caught errors
  (with version and client language) for bug reports.

5.5.0 - raids, trainer spells, minimap buttons
------------------------------------------------------------
- Dungeons & Raids (tab renamed): new Raids view with Barrow Deeps, Hyjal
  Summit and Onyxia's Lair, grouped by size (10 / 20 / 40 players), with
  bosses, known loot, quests and the Onyxia attunement for both factions.
- Key / Attunement tab: switch between Alliance and Horde steps.
- Talent Trees: trainer button (top left) opens the class trainer window:
  spells and ranks you do not know yet for your level and the next levels,
  costs from your trainer visits, quest-taught spells marked, every other
  class selectable.
- Professions overview: Nearest trainers for every profession with a Map
  button; smaller tiles.
- Quality of Life: Collect minimap buttons (bar behind a movable OneForAll
  button, opening to any side, preview picture); the bags full helper's
  "never suggest" list can be edited; new options marked with a yellow "!".
- Thank players who buff you: tooltip explains that friendly nameplates help.
- The minimap button sits on the edge of the minimap again.
- Settings tab scrolls on small windows; scroll bars of Quality of Life and
  Settings sit inside the window; the window is placed on whole pixels.
- Noteworthy changes popup for 5.5.0. New commands: /ofa buttons, /ofa trainer.

5.4.4 - dungeon data from own sources
------------------------------------------------------------
- The first 14 dungeons (Hall of Thanes to Scarlet Monastery: Library) were
  rebuilt from the same sources as all other dungeons: boss and trash loot,
  quest rewards, XP and reputation, quest chains, map pins and entrances.
  Some loot tables are larger now; a few quest values (e.g. XP) follow the
  current Forever beta data.
- Follow-up rewards are shown again (e.g. Hidden Enemies, The Glowing Shard),
  quest items and bags are back in the boss loot.
- DUNGEON_DATA_SOURCES.txt rewritten.

5.4.3 - bug report button
------------------------------------------------------------
- New bug report button in the title bar (next to the skin switch) and
  /ofa bug: shows the link to the issue page on GitHub to copy, together with
  your addon version, class and level.
- Quality of Life tab has its own banner.
- Shorter tooltip for "Compare items only with Shift".

5.4.2 - tooltips, talents and dungeon texts
------------------------------------------------------------
- Quality of Life: new option "Compare items only with Shift" (Tooltips).
  It switches the game setting alwaysCompareItems (on = 0, off = 1).
- Boss loot: the item tooltip opens next to the item name instead of next
  to the drop chance and no longer jumps to the edge of the screen.
- Talents: the rank number (e.g. 2/3) stays readable on mouseover.
- Recipe sharing: when turned off, you do not see other users' recipes
  either; the setting text and the legend say so.
- Dungeons: the first 14 dungeons (Hall of Thanes to Scarlet Monastery:
  Library) got new descriptions, quest notes and boss notes. Quest givers,
  turn-ins and objectives come from the same data as all other dungeons.
  Quest start map pins of these dungeons updated.
- Boss portraits: simpler lookup. A portrait comes from the dungeon data or
  is learned when you target the boss once.
- OneForAll is now licensed under the GPL-3.0 (see LICENSE.txt).

5.4.1 - quest and boss details
------------------------------------------------------------
- Quest details redesigned: chips for level, faction, class and status;
  label rows (starts at with map button, turn in, dungeon, status); framed
  boxes for objective, quest chain, notes and rewards. Same layout in the
  Key tab.
- Boss header shows "Level | creature type | rank" (Elite, Rare, Summoned)
  instead of the loot count. Missing types are learned when you target the
  boss.
- Quality of Life: the right column is flush with the title band.

5.4.0 - all dungeons
------------------------------------------------------------
- Dungeons: all Classic dungeons up to Stratholme now have quests, quest
  chains, quest start map pins, boss loot and trash loot: Scarlet Monastery
  Armory and Cathedral, Razorfen Downs, Uldaman, Zul'Farrak, Maraudon, the
  Sunken Temple, Blackrock Depths, Lower and Upper Blackrock Spire, Dire Maul
  East / West / North, Scholomance and Stratholme.
- New Forever dungeons: The Drowned City (bosses and three Horde quests),
  Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and Shaper's Terrace
  (location and story; bosses, quests and loot follow once they are known).
- Pictures for all new dungeons; boss portraits work without seeing the
  boss first.
- Boss loot shows the Classic drop chance (Forever can differ).
- Dungeon keys: "Key" column in the dungeon list (green check / red cross)
  and a "Key" tab with every step, its status and a map button (Scarlet
  Monastery, Scholomance, Upper Blackrock Spire, Dire Maul; shortcut keys
  for Blackrock Depths, Stratholme, Gnomeregan and Maraudon).
- Item tooltips: items the beta server does not send yet show name, quality
  and slot instead of "Retrieving item information".
- Boss list without the picture behind the "Bosses" heading.
- Settings: tabs can be moved left / right (per character, "Reset order");
  Dungeon list section rearranged; new option "Highest levels first".
- Quality of Life: preview pictures for Quest loot sparkles, Bags full
  helper and Quest XP on the experience bar (spyglass button).
- Less memory: tabs are built when first opened, dungeon data is no longer
  kept twice, the nearby Library Book check and the quest XP bar create far
  less garbage. New command /ofa mem.
- Map: Hillsbrad Foothills, Un'Goro Crater and Moonglade added.

5.3.0 - bags full helper
------------------------------------------------------------
- New Quality of Life option: Bags full helper - when loot does not fit, it
  shows what you would destroy and what you get, side by side; one click
  destroys the cheapest item and loots (also for quest objects and herbs
  without a loot window). Browse the cheapest items, "never suggest" button,
  /ofa cheapest. Quest items, library books, recipes, set pieces, profession
  tools and items without value are never suggested; items better than grey
  need a second click; loot worth less than everything in your bags shows
  "Not worth picking up".
- New Quality of Life option: Quest loot sparkles.
- Social: own switches for group invites, keyword invites and duels; while
  off, OneForAll does nothing with them.
- Quality of Life tab in three columns (shorter page); the right column is
  no longer cut off.

5.2.0 - Quality of Life
------------------------------------------------------------
- New Quality of Life tab; every helper is off until you switch it on and
  Shift pauses the automations:
  - Loot & vendors: auto loot (game setting), quicker loot, auto repair,
    sell junk.
  - Loot feed: looted items and money float up next to your character
    (minimum quality, money on/off, movable, test button).
  - Quests: accept and turn in automatically (reward choices stay manual).
  - Social: group invites and keyword invites (no one / friends / guild /
    friends & guild / everyone), duel filter, thanks for buffs
    (/ofa thanks shows the last buffs).
  - Tooltips: boss drops, who knows a recipe (you, your other characters,
    guild), the target of players.
  - Interface: farther camera zoom, free bag slots on the backpack, quest XP
    on the experience bar, durability warning, movable Blizzard windows, chat
    font size, copy chat button.
  - Unit frames: class colours for players, raid frame class colours and
    power bars (game settings).
- Professions: favourite recipes (star) and a Favorites list.
- Hunter Pets: no ability popup when your active pet already has the ability.
- Scroll bars hide when there is nothing to scroll.
- Money is shown as gold / silver / copper.

5.1.3 - Dark Silver
------------------------------------------------------------
- The Silver skin is now called Dark Silver.

5.1.2 - silver polish
------------------------------------------------------------
- Silver skin is a bit darker; scroll bars, check boxes, the search box,
  the window title and the resize grip are silver too.
- Sun / moon button next to the close button switches the skin.
- Library Books keep their coloured status markers in the Silver skin.
- Quest rewards without a slot line are centred; shorter profession cards
  ("13 known").

5.1.1 - skin switch fix
------------------------------------------------------------
- Switching the skin no longer causes a "protected function" error; the
  Reload button now reloads the interface.
- General: module cards without the Open button (click the card).

5.1.0 - silver skin
------------------------------------------------------------
- New Silver skin (Settings > Skin): grey frames, buttons and highlights,
  slightly dimmed pictures. Switching reloads the interface.
- Hunter Pets: "Where to tame" shows the 4 beasts closest to your level;
  "Show all" lists every known beast of the family.
- Hunter Pets: no pet ability popups during the taming quest (Taming Rod in
  your bags) or before level 10.
- Dungeons: "-" instead of "0 / 0" when no quest applies to you.
- Mage Scrolls removed completely.

5.0.0 - new look
------------------------------------------------------------
- New design for every tab: ornate gold window frame, title bands with
  emblems and banner art, new buttons and tabs, framed panels, rounded rows
  with gold hover and selection, ornate dividers, small-caps headers.
- New panorama artwork for all 14 dungeons (thumbnails, detail header and
  boss backdrops) and new boss portrait frames.
- Dungeons: sortable list, level bracket bands, faction crests, boss level
  always shown ("?" until a Forever-only boss has been targeted once),
  recipe drops start collapsed.
- Library Books: set bands with per-set counter, gem status markers,
  rewards popup with correct item colours.
- Professions: faster recipe list, search with clear button, gem markers,
  rounded guild / player boxes, Merchant's Favor amount in the navigation.
- Talent Trees: two presets per class with Save and Reset (with
  confirmation), class crests, new talent buttons.
- Hunter Pets: new family page (portrait, diet, role, special trait,
  modifiers, abilities, where to tame) and new ability page.
- General and Settings redesigned; "Only dungeons for my level" and
  "Nearby book alerts" are in the Settings.
- The window stays above other addons' frames; popups show above it.
- Mage Scrolls tab removed for now.

4.19.0 - new dungeons and recipe drops
------------------------------------------------------------
- New dungeons: Razorfen Kraul and Scarlet Monastery: Library (bosses, loot,
  quests, quest chains and map buttons).
- Dungeon loot: bosses list the recipes they can drop, with the yellow / green
  / blue checks; click a recipe to open it in Professions (can be turned off
  in the Settings).
- All recipes: about 600 more recipes now show where they drop or who sells
  them.
- New version notice: a short yellow note in the chat when another OneForAll
  user has a newer version (can be turned off in the Settings).
- The two welcome lines at login are gone.

4.18.6 - zone language
------------------------------------------------------------
- All recipes: the zone of other OneForAll users is shown in your own client
  language (players need 4.18.6 or newer).

4.18.5 - required level
------------------------------------------------------------
- All recipes: the character level needed to use the crafted item is shown
  ("L51" in the list, "Requires level 51" in the details; red if too low).

4.18.4 - rarity bar
------------------------------------------------------------
- All recipes: a coloured bar on each row shows the rarity of the crafted item.

4.18.3 - player line
------------------------------------------------------------
- All recipes: players are shown as "Name, lvl 23 Priest - Zone".

4.18.2 - level and class
------------------------------------------------------------
- All recipes: level and class are shown next to guild members and other
  OneForAll users who know a recipe (other users need 4.18.2 or newer).

4.18.1 - fix known recipes
------------------------------------------------------------
- All recipes: recipes you have not learned yet were sometimes marked as known
  (yellow check). Only learned recipes count now; wrong entries are removed
  automatically. /ofa profscan shows more details.
- All recipes: the list no longer jumps back to the top while you scroll
  (e.g. after a skill-up).

4.18.0 - professions & more
------------------------------------------------------------
- Professions: "All recipes" for every profession (where to learn, skill
  levels, reagents, sources with map buttons), who knows a recipe (guild /
  other OneForAll users online, with zone and Whisper), new Overview and
  Merchant's Favor pages, camping object icons.
- Hunter Pets tab available for every class.
- Shift-click links items and recipes in chat.
- Redesigned Settings page with banner; "Noteworthy changes" popup.
- Many fixes and layout improvements (see the beta entries below).

4.18.0-beta27 - settings banner
------------------------------------------------------------
- Settings: new banner artwork, slightly more compact layout.

4.18.0-beta26 - settings layout
------------------------------------------------------------
- Settings page redesigned: tidy sections with icons and a short description
  under every option; new "Noteworthy changes" button.

4.18.0-beta25 - own character without guild
------------------------------------------------------------
- All recipes: your current character is no longer listed under other
  OneForAll users when it is not in a guild.

4.18.0-beta24 - Hunter Pets for everyone
------------------------------------------------------------
- The Hunter Pets tab is shown for every class (can still be hidden in the
  settings); the pet ability alert stays hunter-only.
- Noteworthy changes: "Open Hunter Pets" for every class.

4.18.0-beta23 - popup text
------------------------------------------------------------
- Noteworthy changes: shorter text.

4.18.0-beta22 - popup for all classes
------------------------------------------------------------
- Noteworthy changes: the Hunter Pets part is shown to every class (marked
  "Hunters only"); the Open button only for hunters.

4.18.0-beta21 - noteworthy changes popup
------------------------------------------------------------
- New "Noteworthy changes" popup after logging in with a new version (once per
  account); /ofa news shows it again.

4.18.0-beta20 - Merchant's Favor page
------------------------------------------------------------
- Professions: Merchant's Favor has its own page in the left menu (your
  Favor, Favor recipes per profession, how to earn Favor). Inside a profession
  the Merchant's Favor tab shows its recipes directly.

4.18.0-beta19 - characters with the same first name
------------------------------------------------------------
- All recipes: characters are told apart by their full name (first name and
  surname from the guild roster), so your own characters that share a first
  name show up with their own recipes (green check).

4.18.0-beta18 - alts fix
------------------------------------------------------------
- All recipes: recipes of your other characters in the guild show the green
  check again (guild names with a surname are matched correctly).

4.18.0-beta17 - not learned professions
------------------------------------------------------------
- All recipes: professions your character has not learned say so; the
  "open your profession window" hint only shows for learned professions.

4.18.0-beta16 - header tweak
------------------------------------------------------------
- All recipes: the "open your profession window" hint sits under the legend.

4.18.0-beta15 - all professions
------------------------------------------------------------
- All recipes now for every profession: Alchemy, Blacksmithing, Enchanting
  (incl. enchants), Engineering, Leatherworking, Tailoring, Cooking and
  First Aid (new in the menu).
- Profession icon next to the recipe list title.
- Overview: "Others" heading; left menu icons no longer overlap the text.

4.18.0-beta14 - professions overview
------------------------------------------------------------
- Professions: new Overview start page with your professions (skill and known
  recipes) and tiles for all professions, Camping Buffs and Merchant's Favor.
- Profession icons in the left menu; Camping Buffs moved to the bottom.
- Camping Buffs: item icons for every camping object (shift-click links it).

4.18.0-beta13 - blue check online only
------------------------------------------------------------
- All recipes: the blue check only shows while another OneForAll user who
  knows the recipe is online; the legend says so.

4.18.0-beta12 - online players
------------------------------------------------------------
- All recipes: other OneForAll users are only listed while they are online.
  "Show offline" only applies to guild members.

4.18.0-beta11 - legend
------------------------------------------------------------
- All recipes: small legend for the check colours; the lists of guild members
  and other players who know a recipe are highlighted.

4.18.0-beta10 - layout tweaks
------------------------------------------------------------
- All recipes: sorted by level from top to bottom; more space above the list
  of players who know a recipe.
- Professions: shorter header; the Merchant's Favor amount is shown in the
  Merchant's Favor tab.
- Settings: dungeon level brackets listed one per row.

4.18.0-beta9 - recipe checks, Favor tabs
------------------------------------------------------------
- All recipes: the yellow / green / blue checks are shown side by side.
- "Show offline" moved next to the list of players who know a recipe.
- Your own character is recognised more reliably (no longer listed).
- Professions: "Merchant's Favor" now holds two tabs, Recipes and Guide.

4.18.0-beta8 - show offline
------------------------------------------------------------
- All recipes: your own character is no longer listed under guild members.
- New "Show offline" option (off by default) to also list guild members and
  players who are offline.

4.18.0-beta7 - who knows a recipe
------------------------------------------------------------
- All recipes: checks show who knows a recipe - yellow = you, green = a guild
  member, blue = another OneForAll user. Recipes are shared over the guild
  channel and a hidden chat channel (can be turned off in the settings). Your
  own characters in the same guild count too. The recipe details list who
  knows it, with their current zone (and whether they are in a raid or
  dungeon) and a Whisper button.
- Removed the "Learnable now" filter.

4.18.0-beta5 - fixes
------------------------------------------------------------
- Fixed a Lua error when shift-clicking items into the chat.
- Item info (names, links, reagent counts) now also works with the newer item
  API of the client.
- All recipes only shows faction-specific recipes (e.g. Faction Banner) for
  your own faction.

4.18.0-beta4 - recipe detection, chat link fix
------------------------------------------------------------
- All recipes: known recipes and skill are now read from the new profession
  window and profession book. /ofa profscan shows what was found.
- Shift-click links now always use the game's own item link, so the message
  is actually sent.

4.18.0-beta3 - Tailoring, chat links
------------------------------------------------------------
- All recipes now also for Tailoring.
- Shift-click links items in chat: dungeon loot, quest rewards, book rewards,
  recipes and reagents.

4.18.0-beta2 - professions menu
------------------------------------------------------------
- Professions: left menu only has Camping Buffs and the professions. Inside a
  profession: "All recipes", "Merchant's Favor" and "Favor guide".
- The selected menu entry and sub-page are clearly highlighted.
- All recipes: reagent names shown; "Learned from" says Vendor (with faction),
  World drop / Drop, Quest reward or Merchant's Favor.

4.18.0-beta1 - all recipes (Alchemy)
------------------------------------------------------------
- Professions: new "All recipes (beta)" section, starting with Alchemy. Every
  recipe from the WoW Forever client data (not only Merchant's Favor): skill
  colors for your current skill, reagents with how many you have, where the
  recipe comes from (trainer, vendor, drop, quest, Favor) with Map buttons.
  Filters All / Missing / Learnable now and a search box. Known recipes are
  read when you open your profession window.

4.17.7 - fix
------------------------------------------------------------
- Fixed a Lua error when a pet ability alert appeared.

4.17.6 - target button
------------------------------------------------------------
- Pet ability alert: "Mark" (raid marking is protected on this client and caused
  an error) is replaced by "Target", which targets the beast. Not available
  while in combat.

4.17.5 - pet alert buttons
------------------------------------------------------------
- Pet ability alert: "Mark" puts a skull on the beast, "Snooze 15 min" pauses
  pet alerts, "Ignore <ability>" excludes the ability. No map/dismiss buttons
  (close with the X).
- Alerts stay open for 20 seconds before closing automatically.

4.17.4 - portrait frames
------------------------------------------------------------
- Boss portraits get a gold frame that runs into a point at the bottom right
  (like the player frame); the large portrait shows the boss level in a badge.
- Hunter Pets: round gold ring for families, action-bar style rounded icon frame for abilities.

4.17.3 - pet alert exceptions
------------------------------------------------------------
- Pet ability alerts: abilities can be excluded. Untick "Alert for this ability"
  in Hunter Pets > Abilities, or click "Ignore <ability>" on the alert itself.
  Cower is excluded by default. Excluded abilities show "(no alert)" in the list.

4.17.2 - round pet portraits
------------------------------------------------------------
- Hunter Pets: the large family and ability portraits are round, like the boss
  portraits.

4.17.1 - layout polish
------------------------------------------------------------
- Boss list: the level line lines up exactly under the boss name.
- Hunter Pets: families and abilities show a large portrait/icon with the name
  next to it.

4.17.0 - dungeon quality of life
------------------------------------------------------------
- Opening the window inside a dungeon jumps straight to that dungeon's bosses
  and loot.
- Boss level shown below the boss name and in the boss header. Levels of
  Forever-only bosses are learned when you target or mouse over them.
- Boss portraits that the game resolved once are saved, so they no longer
  disappear in later sessions.

4.16.4 - abilities list
------------------------------------------------------------
- Hunter Pets > Abilities only lists abilities learned from tameable beasts.
  Pet Trainer skills (Growl, resistances, Great Stamina, ...) are shown on
  each family instead.

4.16.3 - logo centered
------------------------------------------------------------
- Minimap logo: the "1" is now exactly centered.

4.16.2 - bolder logo
------------------------------------------------------------
- Minimap logo: thicker "1" that stays readable at minimap size.

4.16.1 - new logo, settings groups
------------------------------------------------------------
- New minimap button logo (golden "1"); also used as the icon in the addon list.
- Settings: popups and alerts have their own "Popups & alerts" group.

4.16.0 - pet ability alerts
------------------------------------------------------------
- Hunter: alert when a beast nearby (nameplate, target or mouseover) teaches a
  higher ability rank than you know, for an ability your active or stabled pet's
  family can learn. Same popup style as the library book alerts, with a Map
  button. Toggle: Settings > General > "Pet ability alerts (Hunter)".

4.15.0 - your pets
------------------------------------------------------------
- Hunter Pets: the family of your active pet is marked green ("Your pet") and
  selected when you open the tab; the detail view shows its name and level.
- Stabled pets are marked blue ("In stable"). The list is updated whenever you
  open the stable master window.

4.14.2 - pet ability scan fix
------------------------------------------------------------
- Hunter Pets: known ranks are read from the pet spellbook with the client's
  modern spellbook API, so your pet's abilities are marked green. Also scanned
  when you open the tab. /ofa petscan prints what was found.

4.14.1 - quest share fix
------------------------------------------------------------
- Fixed: the quest share window kept reopening in dungeons and ignored the
  "open automatically" setting. It now opens automatically at most once per
  dungeon visit (and again only when a new member joins), never when the option
  is off, and stays closed after you close it. /ofa share still opens it.
- Group members only send their quest status when it actually changes.

4.14.0 - known pet abilities
------------------------------------------------------------
- Hunter Pets: OneForAll reads your known pet ability ranks from the Beast
  Training window (open it once) and from your pet's spellbook. Learned ranks
  are green; knowing a higher rank also marks all lower ranks. The ability list
  shows e.g. "3/8 learned".
- Abilities: each rank is a row you can click to fold out the beasts that teach
  it, instead of one long list.

4.13.2 - fix
------------------------------------------------------------
- Fixed a Lua error when scaling the window with the corner grip.

4.13.1 - clickable section headers
------------------------------------------------------------
- Dungeons (level brackets) and Library Books (sets): click anywhere on the
  header bar to collapse or expand it, not only on the +/- button.

4.13.0 - adjustable window height
------------------------------------------------------------
- New grip in the middle of the bottom edge: drag it to make the window taller
  (lists and detail panes show more rows). The corner grip still scales the
  whole window. The height is saved; /ofa scale resets size, height and position.

4.12.7 - compact quest details
------------------------------------------------------------
- Quest details hide the "Prerequisite" and "Turn in" lines when there is no
  information (the quest chain already shows required steps).

4.12.6 - reward layout
------------------------------------------------------------
- Follow-up rewards and the XP/reputation line under quest rewards are
  left-aligned like the other rewards (they were centered).

4.12.5 - steady tooltip position
------------------------------------------------------------
- Item tooltips open right after the item name (or left of the row if there is
  no room), no matter where the mouse enters the row.

4.12.4 - comparison tooltips
------------------------------------------------------------
- The game's "Equipped" comparison tooltips stay on the same side as the loot
  tooltip (right of the mouse, or left if there is no room), so they no longer
  cover the loot list.

4.12.3 - tooltip position
------------------------------------------------------------
- Item tooltips (boss loot, trash, quest rewards) open next to the mouse instead
  of at the far right edge of the row.

4.12.2 - pet ability fixes
------------------------------------------------------------
- Hunter Pets: Forever-only abilities without a known teaching beast show one
  note instead of repeating it for every rank.
- Fixed missing closing bracket on dungeon beasts, e.g. "Scarlet Monastery (Dungeon)".

4.12.1 - quest chain progress
------------------------------------------------------------
- Dungeon quest list: a quest counts as "In log" while you are on an earlier
  step of its chain and shows the step, e.g. "Chain 1/3".
- Quest chain: the last row is labelled "Dungeon quest" instead of "Current".

4.12.0 - Forever loot, Dalaran quests and Forever pets
------------------------------------------------------------
- Dungeon loot updated from wowtbc.gg (Forever loot tables): The Stockade bosses
  now have their real Forever drops instead of "world drops only"; more drops for
  Excavation Site, Blackfathom Deeps, Shadowfang Keep and Gnomeregan; trash loot
  lists for Stockade, BFD, SFK, Deadmines, Gnomeregan and SM Graveyard; event
  bosses Sever (SFK) and Scorn (SM Graveyard).
- City of Dalaran: 5 quests (A Green Sample, Power Overwhelming, The Grave Knight,
  Source of Power, Opportunistic Education); "Mana Elemental" is Arcanic Enigma.
- New quests: Baron Aquanis (BFD, Horde), In Nightmares (WC, both factions),
  The Test of Righteousness (Paladin, DM/SFK/BFD).
- Class-only dungeon quests (e.g. The Orb of Soran'ruk) are only counted for
  that class.
- Hunter Pets: data switched to WoW Forever (wow-petopia.com/forever). New family
  abilities (e.g. Dismember, Savage Rend, Web, Swipe, Pinch), Demoralizing
  Screech replaces Screech, new trainer passives Faster/Slower Attack, Owls are
  now Birds of Prey, Core Hounds and Foxes added. Every rank shows its effect.
- Dungeons: quests in shared-name chains (e.g. Hidden Enemies) are matched by
  quest ID, so the wrong chain step no longer shows as "In log"; the quest chain
  marks the step you currently have.

4.11.0 - level-30 beta update
------------------------------------------------------------
- Excavation Site: 14 quests (Alliance and Horde, incl. chains and rewards) and
  the first recorded boss drops. Some quest givers are not on Wowhead yet.
- Library Books: the rewards window shows all three reward tiers with the real
  items and tooltips (10 books: necklace, 20: ring, new third tier: bow / shield /
  off-hand). Values updated to the current beta (weaker necklaces, ilvl 35 rings).
- Professions: Merchant's Favor overview redesigned - steps, trade hub and the
  crate reward table fit on one page without the small scroll box.

4.10.5 - talent update (beta build 70170)
------------------------------------------------------------
- Talent trees updated to beta build 1.60.1.70170:
  Druid Feral: new Shifting Power and Improved Shifting Power, King of the Jungle
  removed, Shredding Attacks and Predatory Instincts moved.
  Mage: Hot Streak renamed to Heating Up. Warlock: Soul Harvesting renamed to Soul Harvest.

4.10.4 - Hunter Pets banner
------------------------------------------------------------
- The Hunter Pets tab has its own banner.

4.10.3 - map pin
------------------------------------------------------------
- Map pin is now the plain gold variant and a bit smaller.

4.10.2 - title and map pin
------------------------------------------------------------
- Window title shows "made by Smoergi".
- New, simpler map pin (dark with gold rim) that matches the addon style.

4.10.1 - quest share test
------------------------------------------------------------
- /ofa share test opens the quest share popup with two made-up group members,
  outside a group too. Share only shows a local preview of the emote and fakes
  the replies; nothing is shared or posted.

4.10.0 - Settings tab
------------------------------------------------------------
- New Settings tab (gear icon, far left; the window still opens on General):
  shown tabs, dungeon level brackets to show/hide, welcome message, nearby book
  alerts, quest share popup and emote, window reset.
- Welcome message now also invites feedback on CurseForge; can be turned off.
- Tab checkboxes moved from the General tab to Settings.

4.9.0 - Hunter Pets tab
------------------------------------------------------------
- New tab "Hunter Pets" (shown by default on hunters):
  Families - diet, stat modifiers, learnable abilities and where to tame them;
  Abilities - every rank with pet level, training points and beasts that teach
  it (Map button); Rare Tames - notable rare/unique-looking pets.
- Data: Classic pet rules (no Forever pet changes known so far), compiled from
  wow-petopia.com/classic and Wowhead Classic, spawn points from QuestieDB.

4.8.0 - choose your tabs
------------------------------------------------------------
- Every module has a "Show tab" checkbox (now in the Settings tab). The choice is saved per
  character; hidden tabs disappear from the tab bar.
- Mage Scrolls is shown by default only on mages. /ofa tabs reset restores the
  defaults.

4.7.0 - quest sharing in dungeons
------------------------------------------------------------
- Inside a dungeon, a popup lists your shareable quests of that dungeon that a
  group member does not have yet and can take (level/faction checked). One click
  shares the quest and posts an emote, e.g.
  "Kaelin shares the quest "Crime and Punishment" with Anna (OneForAll addon)".
- The game's replies (accepted, already completed, not eligible, too far ...)
  are shown in the popup; players who completed a quest are not offered again.
- Group members with OneForAll exchange which dungeon quests they completed.
- /ofa share opens the popup manually; /ofa share off|on and
  /ofa share emote off|on change the settings (also as checkboxes in the popup).

4.6.3 - boss list width
------------------------------------------------------------
- Boss list now has the same width as the quest list, so switching between
  Bosses & Loot and Quests keeps the layout steady.

4.6.2 - dungeon art and boss list
------------------------------------------------------------
- Simpler thumbnails for Excavation Site, City of Dalaran, Gnomeregan and
  SM: Graveyard (closer to the style of the original dungeon images).
- Wider boss list in the dungeon view.

4.6.1 - talent tooltips
------------------------------------------------------------
- Talent tooltips show the description on the first hover: if the client has
  not loaded the talent's spell data yet, it is loaded and the tooltip redrawn.

4.6.0 - language-independent talent planner
------------------------------------------------------------
- Talent planner matches client talents by spell ID (new TalentSpellIDs.lua,
  read from build 70124 with /ofa talentdump) and only falls back to names.
  It now uses the fixed layouts on German, French, Spanish and other clients too.
- All 466 reference talents of the 9 classes were confirmed against the client.

4.5.1 - talent dump
------------------------------------------------------------
- New command /ofa talentdump: saves node, entry and spell IDs of all talents of
  all classes (preparation for a language-independent talent planner).

4.5.0 - scalable window
------------------------------------------------------------
- The main window can be resized with the grip in the bottom-right corner
  (60-140 %). Size and position are remembered; /ofa scale resets them,
  /ofa scale 80 sets a size directly.
- Four Forever enchanting recipes now require skill 300 (Classic cap).

4.4.1 - dungeon list polish
------------------------------------------------------------
- Zone column and dungeon header show only the zone; coordinates are left to
  the Map button.
- Boss loot tooltips refresh automatically once the client has loaded the item
  (no more stuck "Retrieving item information").
- Stockade bosses without own loot say so; Kam's Walking Stick added.
- City of Dalaran bosses use fixed model IDs for their portraits.

4.4.0 - dungeons up to level 38
------------------------------------------------------------
- New dungeons: The Stockade, Gnomeregan, Scarlet Monastery: Graveyard (Forever
  quests and boss loot from Wowhead Forever), Excavation Site: Wetlands and City of
  Dalaran (boss lists only - loot and quests are not published yet).
- Dungeon list is grouped into collapsible level brackets like Library Books,
  with an "Only dungeons for my level" filter and level colors for your character.
- Level ranges now use the WoW Forever recommended ranges for all dungeons.
- Quest chains: optional lead-in quests are shown as "Optional" and no longer
  block a quest. Fixed Researching the Corruption, Returning the Lost Satchel,
  Allegiance to the Old Gods and Destruction in Deadmines (which blocked itself).
- Gnomeregan Horde quests count for Horde characters.
- Dungeon data split into one file per dungeon.

4.3.1 - talent data, per-character books, map pin check
------------------------------------------------------------
- Talent planner: all 9 classes now use fixed layouts from talentsforever.com
  (build 1.60.1.70009) for tree, row, column and prerequisites instead of guessing
  them from client coordinates. The client still provides icons, tooltips and IDs.
  If client talents are missing from the data, the footer says so; if nothing
  matches (e.g. a localized client), the old estimated layout is used.
- Talent planner: same-row prerequisites are drawn correctly; trees that use only
  three columns are centered; connection lines are reused instead of recreated.
- Library Books: turn-ins, manual marks and the bank scan are now stored per
  character. Existing turn-ins/marks move to the first character that logs in;
  the bank status of each character is rebuilt on its next bank visit.
- Minimap button uses the standard LibDBIcon size, matching other buttons.
- Talent trees: equal horizontal and vertical spacing; class list moved down.
- Removed the caption text from all banners and the profession-data status line.
- Map pins: all dungeon quest starts re-checked against Wowhead (Wilder
  Thistlenettle and Shoni used retail coordinates, "The Glowing Shard" pointed to
  Thunder Bluff, several small corrections); added Destruction in Deadmines.
  Ruins of Lordaeron entrance now uses the Undercity map.
- New command /ofa where.

4.2.0 - UI split into modules
-----------------------------
- The 2,400-line UI.lua is split into one file per tab under UI/ plus shared
  widgets and the main window. No visible changes in game.
- Tabs register themselves; the tab bar is built from that registry.

4.1.2 - code cleanup / bug fixes
--------------------------------
- Fixed: Redridge Mountains was shown as "Contested" (territory table held a map ID).
- Fixed: the golden world-map pin stayed visible when browsing to another zone.
  It is now only shown on the map it was placed on.
- Fixed: the "Quests x / y" column in the dungeon list was only calculated once
  per session. It now updates whenever the list is shown; quest states in the
  dungeon detail view also refresh when the window is reopened.
- Fixed: Blackfathom Deeps "Map" button on non-English clients (added explicit
  map IDs for Ashenvale and other starting zones/cities instead of relying on
  English zone-name matching).
- Performance: UI rows are now created once and reused. Previously every click
  in Dungeons, Professions and Camping Buffs created a new set of frames that
  WoW can never free, so memory kept growing the longer the window was used.
- Performance: the window no longer refreshes itself on bag updates while closed.
- Talent planner: plans are now saved per class (SavedVariables) and survive
  /reload and logout. Removed a duplicate preview call per click.
- Removed dead code: merchant recipe scanning (all 310 recipes ship with
  embedded IDs), unused helper functions and variables.

3.2.0 - Talent Trees data note
------------------------------
Tree structure, row gating and prerequisite behavior are cross-checked against talentsforever.com, whose published JSON is sourced from the WoW Forever beta client. Live client APIs remain the primary runtime source for talent icons and tooltips.

3.1.3
-----
- Reworked Talent Tree buttons to use a Blizzard-style Quickslot frame with rounded/dark corners, inset icons and a subtle shadow/depth effect.
- Increased talent icon breathing room while preserving the four-column planner layout.
- Updated prerequisite connection placement for the new button geometry.
- Fixed the Hunter tree splitter to prefer client-provided tree/subtree membership instead of incorrectly treating local talent X coordinates as three specialization columns.
- Added safer fallback grouping when a class exposes more than three client tree groups.

3.1.2
-----
- Talent rows now unlock in 5-point steps and unavailable talents are visibly greyed out.
- Planner level now follows spent talent points: first point = level 10, up to level 60 at 51 points.
- Added visible prerequisite connection lines using the live client talent graph; linked talents require their prerequisite at full rank.
- Prevented point removal when it would invalidate a lower-row or dependent talent.
- Centered the per-tree point summary in the footer, moved the Left + / Right - hint to the right edge, and removed the redundant Total value.

3.1.1
-----
- Enlarged and rebuilt the golden world-map marker and removed the old glow layer that could render as a dark edge.
- Reworked Talent Trees into a compact four-column grid per specialization to reduce excess spacing.
- Added collision handling for malformed/duplicate client talent coordinates, including Hunter/Priest fallbacks.
- Fixed planner interaction so left-click adds ranks and right-click removes ranks without depending on the client accepting a synthetic preview loadout.
- Replaced the stretched Quickslot overlay with clean 1px borders and cropped talent textures to remove the inner dark rectangle effect.
- Kept the planner-only safety model: no real character talents are changed.

2.9.0 - visual preview
----------------------
- Bundled lightweight dungeon artwork thumbnails for the starter-dungeon list and detail headers.
- Decorative beta-content art strip on the General page.
- Profession icons in Camping Buffs headers.
All bundled artwork is stored locally in OneForAll/Assets; no external addon is required.

2.8.4 - dungeon quality pass
----------------------------
- Rebuilt the embedded dungeon boss/loot and quest/reward data.
- Boss loot and quest rewards now use explicit item IDs wherever provided by that data set.
- Dungeon overview now mirrors Library Books: Dungeon, Level, Territory, Zone / Coordinates, Quests, Actions.
- Quest list owns its own scroll position; selecting a quest no longer jumps the list to the top.
- Quest details now include objective, turn-in, notes, item rewards and follow-up reward items when present.

2.7.0
-----
Completed the starter-dungeon boss loot tables used by the Dungeon browser.

Highlights:
- Ragefire Chasm: completed Taragaman and Jergosh loot sets.
- The Deadmines: completed the main boss loot sets, split Sneed and Sneed's Shredder, and added Miner Johnson.
- Wailing Caverns: completed the listed boss and rare loot sets.
- Shadowfang Keep: completed the main boss loot sets and added Deathsworn Captain.
- Blackfathom Deeps: completed the listed boss loot sets and added Lorgus Jett.
- Boss detail pane now shows the number of known loot items for the selected boss.

Dungeon data is beta information and can change during WoW Forever testing.

Version 2.7.0 data/UI follow-up
-------------------------------
- Re-audited starter-dungeon boss loot against current Forever beta/community records.
- Corrected Wailing Caverns and Blackfathom Deeps loot counts where older rows were incomplete or over-inclusive.
- Dungeon quest rewards now use the actual item-quality color reported by the client instead of a hard-coded green label.
- Mage Comprehension scroll hover text now uses the native item tooltip where possible and appends requirements and deciphering guidance.
- Added a Camping Buffs page under Professions with profession-related camping objects, skill requirements, effects and reagents.
- The General page always shows the current addon version from the TOC metadata.


2.7.0 highlights:
- Dungeon overview now uses a compact Library Books-style table with Map buttons.
- Dungeon quests can be filtered by Alliance or Horde and use a boss-style master/detail layout.
- Expanded current-known boss loot and quest rewards.
- Mage scroll tooltips explain Comprehension and deciphering.
- Camping Buffs include gathering and secondary professions such as Fishing and First Aid.

2.5.1
-----
Added a Dungeons tab focused on the early Forever beta dungeon bracket.
Included: The Hall of Thanes, Ragefire Chasm, Ruins of Lordaeron, The Deadmines,
Wailing Caverns, Shadowfang Keep and Blackfathom Deeps.

Each dungeon has:
- level range and faction/area context
- boss list
- current-known / beta loot list
- quest list with required level, faction/class restrictions, pickup location,
  prerequisites and notable rewards where verified
- automatic highlight when a listed quest is currently in your quest log

Dungeon and loot data is beta information and may change during WoW Forever testing.

2.4.0
-----
- Library Books tracker with bag/bank state, confirmed turn-ins, map markers and nearby alerts.
- Mage Comprehension scroll overview.
- Merchant's Favor overview and profession recipe browser with embedded WoW Forever
  recipe IDs, craft spell IDs, crafted item IDs, reagent IDs and enchant metadata.
