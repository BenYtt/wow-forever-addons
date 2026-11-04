# Changelog

What changed in each release, in the terms someone finding their way would notice. Dates are UTC.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The entries are prose rather than bare
Added/Fixed lists.

Each version's entry is also its release notes on GitHub, CurseForge and Wago. Older entries are kept
verbatim rather than rewritten as the addon moves. API changes other addons' authors need go under an
optional `### For addon authors` subsection after a version's player bullets.

## [Unreleased]

## [1.22.26] - 2026-11-04

- **Picking a Nearby service no longer raises an error.** Choosing a service from the world map's filter menu, the minimap's tracking menu or `/spfnear` started the journey and then called a menu function the game does not have, so a Lua error followed every pick. The button now closes the menu the way the game's own buttons do. Our entries in those menus are also checked before they are added and report any error of their own instead of passing it into the game's menu code. If the world map filter menu still crashes the game when it opens, `/path menutest map`, `/path menutest nearby` or `/path menutest both` leaves our entries out after a `/reload`, and `/path menutest off` puts them back, so you can tell us which one it is (#161).

## [1.22.25] - 2026-11-04

- **Controller players no longer trip the client's gamepad block.** Under the gamepad interface, a context menu opened from the tracker header, a step line, a dock pin or a flight pin now says "This menu needs mouse and keyboard." instead of opening inside our own click handler, and the world map is no longer turned when it is already open. Both changes remove the synchronous path from this addon into the protected interact-target call that the client blocked, which also explains why other addons were being named alongside it.


- **Controller play no longer blocks the game's interact target.** With the gamepad interface on, the game takes every menu and window that opens into its controller focus straight away, and when Shortest Path opened one (a tracker or map pin menu, Nearby services, or turning an open map to a place) the game blocked `SetPreferredGamepadInteractTarget()` and blamed whichever addon touched it last. Under the gamepad interface those menus now say they need mouse and keyboard, and Show on map asks you to turn the map yourself. Nothing changes with mouse and keyboard. Thanks to TRDeadbeat, tallsmartman and the other CurseForge players for the reports.

## [1.22.24] - 2026-11-04

- **Water walking checks work reliably.** The check for a known water-walking spell used a compatibility function that only exists while the game's deprecation fallbacks are enabled. Without them, a journey raised a Lua error and never finished planning. It now asks the spellbook directly.

## [1.22.23] - 2026-11-04

- **Companion map layers avoid duplicate pins.** Visible OpenMap and Leatrix Maps pins replace matching background flight and transport pins. Active journey guidance stays visible, and layers without a companion equivalent remain available.

- **Travel data regenerated against the 1.60.1.70755 build.** The travel data set (taxi network, teleports, transports and zone adjacency) is rebuilt from the new Forever client build. The regenerated values match the previous build, so the routes and boat times you see do not move.

## [1.22.22] - 2026-11-04

- **Travel leaderboards keep your own row visible.** Guild and group totals are labelled player-reported, and approximate distance stays marked. New participation starts on, while saved recording and sharing opt-outs remain off. Disabling either cancels queued sends and hides cached peers while preserving personal history. Shared reports use the suite's bounded transport. Only travel records are cached.

- **Following TomTom shows one direction arrow.** While Shortest Path supplies directions, TomTom's arrow steps aside without stopping its waypoint queue. Its own settings take effect again when guidance pauses or ends.

### For addon authors

- `TravelStats().peers` retains its addon, player, metric and subject layout, but now contains only `spf` travel reports. Unused foreign-addon caches are removed.

## [1.22.21] - 2026-11-04

- **Screenshot art pins are recorded separately from map content.** The renderer keeps its UI art build independent of the generated map data build, and THIRD_PARTY.md names both pins.

## [1.22.20] - 2026-11-03

- **Alt-left-click plans journeys with TomTom installed.** TomTom keeps its right-click waypoint gesture, while Alt-left-click plans a journey over map icons. Saved TomTom settings no longer disable that gesture. Thanks to cjber for requesting the compatibility audit (#329).

## [1.22.19] - 2026-11-03

- **The destination pin says what the step is, not only how far.** The in-world pin now carries one short line of the current step's wording under the distance, taken from the journey's current row and falling back to the journey title when no row is current, cut at a word so it fits the pin. It is reread only when the goal or the stop index changes, so the per-poll cost is unchanged, and the map pin's tooltip still carries the full text of every step. Asked for on the pin that shipped in 1.22.18.

- **Alt-clicking the world map no longer plans a journey and drops a TomTom waypoint at once.** TomTom's click-to-
  waypoint is on by default and reads the same press. While that option is on the click is left to TomTom, and a
  journey is planned from the quest menu, a pin or Shift-click as before.

## [1.22.18] - 2026-11-03

- **Follow a party member and the route keeps up with them.** `/path follow` (or `/path follow party2`) plans a journey to where that player is and replans it as they move, so the arrow, compass, tracker and map stay on them instead of on where they stood when you set off. The client only reports another player's position as a fraction of a zone map, so a refresh is due once a second and only after a visible move; the replan is handed to the next frame no walking search is using, which a bench over real Ashenvale and Darkshore data shows keeps it out of the frame the search was already spending. It ends when you are within 40 yards of them or they leave the group. Asked for by a player whose wife could use the direction, in the CurseForge comments.
- **A pin on screen over the journey's destination.** Settings > Guidance gains `Show a pin over the destination`: the game's own waypoint pin, held over where the journey ends, turning with you as you face it and fading when it is behind you, with the distance under it. It is off until you ask for it, only draws in the zone you are in, and stands down while Waypoint UI is navigating so the two never draw a pin over each other. That was the other half of the CurseForge request that shipped its Waypoint UI half in 1.22.5.

## [1.22.17] - 2026-11-03

- **The first journey after a login or `/reload` no longer stalls.** The planner threw away its transport topology on every reset, so each journey's first plan rebuilt it inside the click: 476 ms on the first journey after a reload against 5 ms on the second. The topology now survives a reset and is rebuilt only when one of its inputs changes, so the cold build is paid once a session rather than once a journey. Reported by JohnChrin, who measured it around `API.NavigateRoute` on v1.22.16.

## [1.22.16] - 2026-11-02

- **Every line now reads in all nine shipped languages.** The locale check found lines still shown in English: the flight-master and transport strings, and the phrases the report and shopping-list work added. All nine locale files cover `Locales/phrases.txt`, so no window falls back to English. `tools/typecheck.sh` runs the locale check with `--release` from now on, so an English line added without its translations fails the change that adds it.
- **Riding the Great Lift names it once.** The chat line after a ride read "synced the The Great Lift schedule from your ride."; the lift is now called the Great Lift everywhere the addon names it, its map labels included.

## [1.22.15] - 2026-10-30

- **THIRD_PARTY.md credits more of the players behind the addon.** Its Ideas and contributors table gains rows for players whose reports, ideas or fixes shipped but were not yet credited there. Thanks to Mouchoir and z1ck for what they reported, asked for and fixed.

## [1.22.14] - 2026-10-30

- **Taxi, portal, teleport, transport and zone data re-pinned to client build 1.60.1.70707.** Regenerating against this build produces no change to the bundled routes, so nothing a player sees changes.

## [1.22.13] - 2026-10-28

- **Taxi, portal, teleport, transport and zone data re-pinned to client build 1.60.1.70685.** Regenerating against this build produces no change to the bundled routes, so nothing a player sees changes.

## [1.22.12] - 2026-10-28

- **Taxi, portal, teleport, transport and zone data re-pinned to client build 1.60.1.70658.** The generators now read and record the newer Forever build from wago.tools, so flight paths, boat and zeppelin timings and portal discovery stay keyed to the build the client ships. Regenerating against this build produces no change to the bundled routes, so nothing a player sees changes.

## [1.22.11] - 2026-10-27

- **Taxi, portal, teleport and zone data regenerated for client build 1.60.1.70630.** The generators now read the newest Forever build from wago.tools' `wowf` product as well as `wow_classic_beta`, because wago lists newer builds under `wowf` and the pin check had been reading only the older product, so the daily refresh reported itself already current and skipped regeneration. Flight paths change with this build; walking costs and nav data are unchanged.

## [1.22.10] - 2026-10-26

- **The note after updating now names the ferry marker art.** 1.22.9 shipped with the previous release's note, so the one line printed after an update did not match what that version changed. This release corrects the sentence. No gameplay change.

## [1.22.9] - 2026-10-26

- **Airship and boat route markers now use the client's native ferry atlas art.** Their map appearance matches the game markers and removes the custom bundled airship image.

## [1.22.8] - 2026-10-26

- **A zone name in `/way` no longer has to be typed with its accent.** `/way` folds the name with Forever Core's one shared fold (`Core/Text.lua`, `ns.Text.Fold`) before it drops the spaces and punctuation, so "dun garok" reads as "Dûn Garok" and "dunmorogh" still reads as "Dun Morogh". Forever Core's settings-page chrome (`UI/SettingsPage.lua`) is vendored byte for byte for the shared-code drift gate; the addon keeps its own settings page.

## [1.22.7] - 2026-10-24

- The report keeps the same error details, now captured by Forever Core alongside the other shared report code.

## [1.22.6] - 2026-10-24

- **Report and issue text selects when focused.** Ctrl+C now copies the full report or issue link from either text box.

## [1.22.5] - 2026-10-23

- **With Waypoint UI installed, the two addons stop clearing each other's pin.** Waypoint UI drives the same native user waypoint Shortest Path borrows to steer, so whichever addon refreshed second erased the other's marker. When Waypoint UI is tracking a navigation, Shortest Path now leaves that marker to it and hands its destination over through Waypoint UI's own API, while the arrow, compass, tracker and map drawing keep guiding as before (#271).

## [1.22.4] - 2026-10-23

- **The travel journal is off until you ask for it.** *Record travel stats* and *Share travel stats with guild and groups* now both start off, so a fresh install records no distance, counts no journeys and sends nothing over the addon channels. Tick either box under *Settings*, *Travel journal* to start, and nothing you already recorded is lost (#269).

- **Focusing the read-only report or issue box selects its text without a Lua error.** Opening the copy box put the client's own `isUserInput` flag into `HighlightText`'s start argument, so it raised *bad argument #2 to '?' (outside of expected range -2147483648 to 2147483647)* and left the text unselected. The report window, the issue composer and the Forever addons link box now select the whole text the way the game asks (#269).

## [1.22.3] - 2026-10-23

- **Report a bug or request a feature from the game.** `/path issue` (also `/path bug` and `/path feature`) opens a composer: write what went wrong, pick Bug or Feature request, and the window hands you a ready-made GitHub issue link, selected so Ctrl+C and a paste opens the new issue with your words and the addon's system report already filled in. Copy report still puts the same text in your hands for Discord.

## [1.22.2] - 2026-10-23

- **The tracker hands Blizzard's objective frame back cleanly when you enter Edit Mode.** The route column now detaches instead of holding the native anchor, so dragging the objective tracker in Edit Mode no longer fights the addon, and leaving Edit Mode puts everything back where it was.

## [1.22.1] - 2026-10-23

- **Data checked against Forever 1.60.1.70532.** Routes, transports, flight points, portals, teleports and zones are unchanged apart from the bundled data's build pin.

## [1.22.0] - 2026-10-22

- **Every character keeps a travel journal.** While you walk, the addon samples your position on the same map and adds the distance to a running total for the character you are on, next to the journeys it completed and the transports, flights and portals it used. When you pass a milestone a line in chat says so. Recording is on by default: *Settings*, *Travel journal*, *Record travel stats* turns it off, and `/path stats` prints the totals for this character at any time.

- **Travel stats can be shared with your guild and groups, and the journal stays local when they are not.** *Share travel stats with guild and groups* is on by default: the addon sends and receives travel snapshots over the guild, party, raid and instance addon channels, and `/path leaderboard routes`, `distance`, `transports`, `flights` or `portals` lists your own record beside the figures other players report. Shared records are player-reported and not verified. Turn the option off to keep every record on this character only; nothing you already recorded is lost.

## [1.21.10] - 2026-10-22

- **A quest item in your bags clicks normally while the tracker is loaded.** Our tracker sections used to be handed to the game's own tracker manager when they were registered, which marked the bag item click path insecure, so a click on an item in your bags could be turned into a blocked action while the Forever column was up. Each addon now parents its own sections and never calls the native manager, so the click path stays secure. This is the same fix SkillUp Forever shipped in 0.18.12, now in the shared tracker host.

## [1.21.9] - 2026-10-21

- **A new flight master is hard to miss.** When a journey needs you to discover one, the tracker names it and the step, a raid warning and taskbar flash announce the plan, and the warning repeats as you approach. Turn off *Remind me about new flight masters* to keep the tracker note without the banners. Thanks to cjber for the idea.

## [1.21.8] - 2026-10-21

- **The game's own All Objectives header stays where the game puts it.** The tracker column had been lifting that header out of the quest tracker and pinning it above the Forever rows, and the client re-anchors it on every tracker update, so the two fought: the header could stay on screen with nothing under it and leave a blank band above the first Forever row. Nothing of ours moves or shows that header any more: it keeps its own place inside the game's tracker, the column starts at the top of the slot with no reserved gap, and an empty column still hides itself. Thanks to team_Brigade on CurseForge.

## [1.21.7] - 2026-10-21

- **The tracker no longer errors out when another Forever addon adds its own section.** With SkillUp Forever loaded, the two addons' tracker sections are sorted together, and a section that carries no ordering of its own was compared against ones that do, so the layout pass died with `attempt to compare nil with number` on every refresh (297 times on the report). Sections that carry an order keep it, sections without one follow them in the order they were added, and the column draws every time. Thanks to Torpdotorgx and dryzee on CurseForge.

## [1.21.6] - 2026-10-21

- **The in-combat tracker keeps up with new objectives.** In combat the game's own tracker cannot be moved, so the Forever column fits itself into the height it was given when the fight began. A quest accepted or an objective completed mid-fight could then be cut off until combat ended, and a collapsed native header left an empty gap at the top of the column. The column now reserves header room only while the header is shown, grows to fit a section that gained lines, and keeps that taller height for the rest of the fight. Found in the suite's own review of the shared tracker host.

## [1.21.5] - 2026-10-20

- **Lock the tracker where you put it.** Detach the Forever column, drag it where you want it, then tick *Settings*, *Tracker*, *Lock the tracker*: the grip stops moving the column and hovering it says the tracker is locked instead of offering to move it. It is off by default, it only ever suppresses our own drag handler, so turning it on or off in combat cannot taint or move anything, and an existing character's settings gain the switch without losing their place. The grip and its lock also moved into their own file, which keeps the shared tracker host inside the project's file-size rule. Thanks to Alex21xx for the request.

## [1.21.4] - 2026-10-20

- **The guide's waypoint is set once.** While a RestedXP guide is followed, a rested-XP level-up could restart the journey on every guide update, re-setting the same waypoint and stuttering the game. The guide's target is now compared by map and position only, so jitter in its coordinates and a step renamed at the same spot no longer replan the journey: a renamed step updates its label in place. Thanks to Joster91 on CurseForge.

## [1.21.3] - 2026-10-20

- **Questie's quest tracker can be moved again.** With a Forever section in the tracker, Questie's quest list and the game's own quest tracker could no longer be dragged, and could vanish. A frame of ours sat between UIParent and Questie's list, and Questie's own drag code reads the list's corners and then clears its points mid-gesture, so a layout pass of ours landing in that window left it nothing to read. Nothing of ours is anchored to the list any more: it is watched through its own show, hide, drag-stop and size calls, the column holds its place while you drag or resize it, and it reflows once when you let go. Thanks to procque and Fareed on CurseForge, and to the Questie team for the report that named the cause in Questie/Questie#8076.

## [1.21.2] - 2026-10-19

- **The quest tracker is free to move when the journey section is hidden.** With Questie or Blizzard's tracker, an empty companion column releases its saved anchor and clears its old height. Thanks to Ragnarok11B for reporting the issue.

## [1.21.1] - 2026-10-19

- **Credit where it is due.** The OpenMap support in 1.21.0 came from a suggestion by user_uf9axk2x4gqtmfch on CurseForge, who also pointed at OpenMap's own API. Their name now carries the 1.21.0 note and the credits file.

## [1.21.0] - 2026-10-19

- **Works alongside OpenMap.** With OpenMap installed and its seamless world map on, Shortest Path's route now draws across the stitched world instead of stopping at the zone the map is on: the line and the stops carry on into the neighbouring zones as you pan and zoom, and the addon's pins are lifted above OpenMap's map art so they stay visible. Nothing changes without OpenMap, or on its dungeon and battleground maps. Thanks to user_uf9axk2x4gqtmfch on CurseForge for the idea, and for pointing at OpenMap's API.
## [1.20.1] - 2026-10-19

- **Alliance Skyborne can route through the Dalaran portal to Stormwind and back.** Horde Skyborne have no equivalent Dalaran portal. Thanks to saikoso for reporting the missing route.

## [1.20.0] - 2026-10-18

- **Hazards change the path, not the time.** Walks still go round places you'd rather avoid, but their times now show the travel time along that route. Short walks of 200 yards or less beside a dock or flight master stay direct.
- **Walks stay out of trouble.** A walk goes round zones whose lowest level is 4 or more above yours, and plans again when you level up (Ding! by Yendi gave me the idea). It also goes round the other faction's towns and capitals. The zones and towns you start and end in are never avoided. The tracker says when a walk goes round a zone, has to cross one, or passes a hostile town: *Hostile town: Crossroads*. *Avoid zones far above my level* in Guidance turns off the zone part. The towns idea came from Polestar.
- **Gamepad interface: the world map is only read.** Shortest Path's docks, portals, flight points, route and stops are now drawn on frames of its own over the map, so the game's map no longer holds any of the addon's pins or data. With the gamepad interface on, the map walks its own pins from secure code every frame, and an addon's pins in that walk are the likeliest cause of the blocked `SetPreferredGamepadInteractTarget()` error some controller players reported. Every pin works as before: tooltips, clicks, Shift-click to plan a journey, right-click to zoom out, the size settings, and a flight point you click on a zone map becomes the one you track. Under the gamepad interface, a pin under the map cursor shows its tooltip. Thanks to TRDeadbeat, tallsmartman and the CurseForge players who reported it, and to Polestar for the idea.
- **Works alongside Polestar.** With Polestar installed, Shortest Path's TomTom stand-in, `/way` and *Follow TomTom's arrow* always work, whichever addon loads first, and a waypoint is never planned by both. Polestar's own stand-in no longer counts as TomTom, so *Let guides set TomTom waypoints* can be turned on at any time, and turned off again gives Polestar's back if Polestar had it. When Polestar follows TomTom's arrow and hands its target to Shortest Path, that waypoint isn't followed a second time, and the copy of Polestar's own target it puts in TomTom (or in the stand-in) is left to Polestar.
- **More players credited.** THIRD_PARTY.md now thanks GenericP for asking to plan to a spot under a Questie icon (Alt-click, 1.14.0) and for TomTom waypoints to start journeys, and Sol_Deus for reporting the controller error with TomTom and Scrap. CurseForge players are now listed by the name CurseForge shows, such as team_Brigade and Testvonfarkle.

### For addon authors

- **`ForeverMapMarkers`.** The pins aren't the map's own any more, so `WorldMapFrame:EnumeratePinsByTemplate` no longer finds them. `ForeverMapMarkers.ShortestPathForever(WorldMapFrame)` returns the shown docks, portals, flight points and stops as `{x, y, kind}` map fractions on the map being viewed (docs/api.md).
- **`/way` is claimed as Shortest Path loads**, while TomTom isn't installed and no addon has it, rather than at login. An addon that claims `/way` at login while it's free finds it taken; TomTom, or an addon that takes `/way` without looking, still keeps it. The API meanings other addons rely on (`NavigateRoute` stops, `CurrentStop`, `Active`, `Ended`, `Cancel` and `Subscribe`) are now pinned by `tests/api_contract_spec.lua`.

## [1.19.2] - 2026-10-17

- **The tracker sections now move clear of Questie's quest list.** With Questie's tracker on, its list was drawn over the Journey and the other Forever sections. The shared column now sits below Questie's list, or above or beside it when there isn't room, and follows it when it moves, grows or hides; your quest tracker keeps its own place. A detached column you haven't moved yet starts beside Questie's list. Thanks to deathmvp1 for the report and berserkerlxl for finding the cause.

## [1.19.1] - 2026-10-17

- **Data checked against Forever 1.60.1.70450.** The travel data is unchanged apart from its build pin.

## [1.19.0] - 2026-10-16

- **In your language.** Shortest Path Forever is now in German, French, Spanish (Spain and Latin America), Brazilian Portuguese, Russian, Korean and Chinese (simplified and traditional): every language the WoW: Forever client offers besides English. It's machine translated, using the game's own words for flight masters, Hearthstones, the tracker and the rest, so corrections are welcome through the [translation issue form](https://github.com/cjber/shortest-path-forever/issues/new?template=translation.yml). Eight French lines are Brainc3ll's, from his Legacy Forever translation. Outside the Chinese clients, distances follow the game, which shows yards as metres; *Distances in metres* switches to real metres.
- **Reagent vendors in your language.** Nearby services finds reagent vendors whether QuestieDB names them in English or in your language.

## [1.18.0] - 2026-10-16

- **Adventure Guide's suggestions in the quest menus.** With Adventure Guide Forever on (its next release, which adds the suggestions to its API) and *Shift-click to plan journeys* on, right-click a quest in the tracker or the quest log: under *Plan journey*, *Adventure Guide suggests* lists up to three of its suggestions as `[level] title`. Choosing one starts it as Adventure Guide's own Start does. Nothing shows while it has none.
- **A Forever addons page in the settings.** *Forever addons*, under Shortest Path Forever in the AddOns settings, lists my five WoW: Forever addons with what each does and whether you have it: on, installed but turned off, or not installed. *Copy link* shows the addon's CurseForge address to copy into your browser.
- **A quiet word about my other addons, only where it helps.** With Adventure Guide Forever not installed, the quest menus show a grey *Suggest quests for my level: Adventure Guide Forever* under *Plan journey*, and once a session a journey you planned yourself that arrives with nothing more planned leaves a grey "What next?" line in the tracker for two minutes. With Legacy Forever not installed, hovering the pin of a journey that ends at a dungeon or raid door says in grey that Legacy Forever shows the challenges it counts toward. Clicking the menu entry or the tracker line shows the address to copy, with *Don't suggest this again*. Nothing shows for an addon you have, even switched off. Untick *Suggest my other Forever addons* on the Forever addons page (it's on by default) and none show.
- **Credits.** The README names the players who reported bugs or asked for features, and Polestar, which inspired some features; THIRD_PARTY.md has the full list.

### For addon authors

- **The shared `UI/ForeverFamily.lua` (VERSION 3)** is the same file in all five Forever addons. Each copy sets `ns.Family` to `ForeverFamily.For(ns.L)` (or `ns.FamilyL`, for an addon whose L isn't keyed by English phrases), a view whose `ShowLink` and `CreatePanel` read in that addon's own L, and in English where it has no entry. The link window has one global name, `ForeverFamilyLink`, kept on the module as `ForeverFamily.window`. A call that names no L reads in the L of the copy in use, and `ADDONS[i].line` is the English line and its key in each addon's L. From VERSION 3 on, a newer copy takes over the global, puts the older copy's window away, and serves `ShowLink` and `Once` for addons still holding the older copy's view.

## [1.17.0] - 2026-10-16

- **Data checked against Forever 1.60.1.70425.** Two Skyborne air routes changed course in this build. The Alliance skyship between Dalaran and Valanaar now takes about 5 seconds longer per round trip, and the Horde zeppelin between Thunder Bluff and Zephras Isle a fraction of a second less, so their departure times follow the new paths. Flight points, flight times, lifts, portals and teleports are unchanged.
- **Journeys to a dungeon go to its door.** A quest objective, a map click or a guide's stop inside a dungeon or raid used to have no way there, because there's no walking map inside. From outside, the journey now goes to the instance's entrance, called "Enter Deadmines" unless the stop has its own name. The stop counts as reached when you go in, and a guide's next stop inside starts from there. Inside the dungeon nothing changes.
- **Move the tracker from its own menu.** Right-click the tracker's "Journey to …" line and untick *Attach to quest tracker* to drag the shared Forever column anywhere, as the setting in Guidance does. Tick it again to put it back above your quests. The detached column and its "Forever tracker" heading still hide while nothing is tracked; the setting in Guidance brings it back then. The menu leaves the choice out in combat, when the column can't move.
- **Nudge the compass and arrow with the arrow keys.** While *Move the compass* or *Move the arrow* is on, rest the pointer on it and each arrow key moves it a little, or ten times as far with Shift. The arrow keys keep walking as normal when the pointer is anywhere else, and in combat.
- **Gamepad interface: the world map is left to the game.** Some controller players hit a blocked `SetPreferredGamepadInteractTarget()` error, or a freeze, with this addon, TomTom or Scrap loaded. The game's gamepad layer can blame whichever addon last opened a window, so with the gamepad interface on, Shortest Path no longer opens the world map itself. *Show on map*, a dock line in the tracker and a route end turn the map to the place if it's open, and otherwise ask you to open it. Nearby services points you to the map's own tracking menu. Moving the compass or arrow doesn't take the keyboard either. Nothing changes with mouse and keyboard. If you play with a controller and still see the error, please send `/path report`.
- **Walking lines no longer clip rock or buildings at their ends.** The line on the map and minimap is drawn from exactly where you stand and to exactly where you're going, but only the part between those ends was checked against the walking map. The first and last stretch could cut through a wall or a hillside for a few yards. Each end is now checked too. One that would cross bare ground bends through the nearest walkable spot instead. The time and the route are unchanged. Thanks to fitzforge for the report.
- **The quest tracker is let go when the Journey has nothing to show.** To fit the Forever sections above your quests, the shared column moves the game's quest tracker. It kept holding it there with no journey, no boat times and nothing from the other Forever addons, or with All Objectives collapsed. That fought EllesmereUI and other UI addons that place the tracker themselves. Now the tracker goes straight back to where the game, Edit Mode or your UI addon put it, and is moved again only once a section has something to show.
- **Collapsing All Objectives in combat hides the Forever sections at once.** During a fight they stayed on screen until combat ended. A Forever section from another addon that changes in combat now redraws in the space it already has, instead of keeping its old text. The game's quest tracker still isn't moved until combat ends.

## [1.16.0] - 2026-10-16

- **Keep journeys after a reload.** Turn on *Keep journeys after a reload* in Guidance and a journey you planned yourself (a map click, `/way`, a quest or Nearby services) starts again after a `/reload`, or when you log back in within 30 minutes. Guides and other addons start their own again, and one that does so first wins. It is off by default.
- **`/path report` gives you something to paste into a bug report.** It opens a small window with the text already selected: your addon and game versions, your character and where you are, your journey with each of its steps, your ride, the ride trace when `/path debug` is on, any errors caught this session, and your other addons. Press Ctrl+C and paste it. It fits in one message, and you don't need a /reload or a saved-variables file.
- **The arrow eases round and moves.** The direction arrow swings smoothly to each new bearing, as the compass does, instead of stepping, and rests when you stand still. *Move the arrow* and *Arrow scale* in Interface place and size it, and the cast prompt that stands in its place. Shift-drag the arrow or the compass while moving it to move it a quarter as far as the mouse, for placing it to the pixel.
- **The time left under the compass.** Turn on *Show the time left under the compass* in Interface and the journey's time left sits beside the distance to your next turn, as the tracker's header gives it. It is off by default.
- **A sound when you arrive.** Turn on *Play a sound when you reach the goal* in Alerts and the map's ping plays when a journey you planned yourself gets there, even with the game in the background. Clearing a journey stays quiet, and guides keep their own cues. It is off by default.
- **Flight point tooltips list their flights.** Hovering a flight master on the world map lists where you can fly from there and how long each flight takes. Your own timed flights come first, and flight points you haven't found yet are grey, as is every flight from one you haven't found.
- **The goal stays on the minimap's edge.** When the place you're heading for is off the minimap, its mark now waits on the rim in its direction, a little faded, instead of disappearing. Boat, zeppelin and flight marks are unchanged.
- **See what the other faction's boats would save.** With *Other Faction's Routes* off, hovering the pin you're heading for adds one line when the other faction's boats or zeppelins would get you there at least two minutes sooner, such as "Through Horde transport: about 4 min faster". It says nothing about how safe that is: turn the routes on if you want to take them.
- **More guides' waypoints work without TomTom.** The TomTom stand-in now answers the rest of the waypoint calls guides make: checking or clearing a waypoint, clearing them all, asking for the closest one and its distance, pointing the arrow at one, and adding one on the map you are on.
- **The Hearthstone works on a new install.** The bind point used to be learned only when you bound at an inn with the addon running. Casting Hearthstone or Astral Recall now records where it sets you down, so the next journey can use it without a rebind.
- **A journey started again to the same place no longer stalls.** If a guide such as Adventure Guide resent its route, or you clicked the same spot again, while the first walking search was still running, that search stayed paused or lost its answer. The journey stuck on "Finding the fastest way" and never reached its stop. The search now carries on, or uses the answer it already found.
- **Less work while you stand still.** The journey's line on the minimap stops redrawing every frame once nothing has changed for a second, and picks up again as you move, turn, zoom or ride. The direction arrow already rests the same way.

### For addon authors

- **`Subscribe` to journey changes.** `ShortestPathForever.API.Subscribe(callback)` calls `callback(changes)` once per burst of changes, on the next frame, with any of `started`, `changed`, `ended`, `stop` (what `CurrentStop` answers changed) and `active` (what `Active` answers changed) set, so callers no longer poll `Ended`. A failing callback cannot stop the others. The API stays version 1 and gains `minor = 1`; see `docs/api.md`.
- **The TomTom stand-in answers more calls.** While TomTom is absent, `IsValidWaypoint`, `WaypointExists`, `ClearWaypoint`, `ClearAllWaypoints`, `GetClosestWaypoint`, `SetClosestWaypoint`, `SetCrazyArrow`, `GetDistanceToWaypoint` and `AddWaypointToCurrentZone` work on its waypoint; see `docs/api.md`.

## [1.15.0] - 2026-10-15

- **Data checked against Forever 1.60.1.70374.** The travel data and flight times are unchanged apart from their source pins.

- **The quests stay below the Journey with EllesmereUI and other UI suites.** When the game, Edit Mode or a UI addon put the quest tracker back in its saved spot, the Forever sections waited for the next quest event to restack, so your quests sat over the Journey until then. The column now follows the quest tracker as soon as it moves, as 1.13 did, still without touching the game's own tracker code.
- **A background for the compass.** *Compass background* in Interface darkens the ground behind the compass, from 0% (none, the default) to 80%, so its marks stay readable over snow, sand or a bright zone.
- **Type `/way` to plan a journey.** `/way [zone] x y [title]` takes TomTom's line, map IDs, part of a zone's name and decimal commas included, and plans a journey to that spot, as a Shift-click on the map does. It is only taken while TomTom and other addons leave `/way` free; `/path way` always works.
- **Follow TomTom's arrow.** With TomTom installed, turn on *Follow TomTom's arrow* in Guidance and each waypoint its arrow takes, from its `/way`, a guide or your own choice, becomes a journey here, including the waypoint it points to after a `/reload`. Removing the waypoint in TomTom, or all of them at once, ends it. TomTom's corpse arrow is left to the corpse run, so dying keeps the journey you were on. It is off by default.
- **Guides' waypoints work with TomTom switched off.** A TomTom that is installed but turned off in the AddOns list no longer stops guides that set TomTom waypoints from planning journeys here.
- **The destination pin lists the steps.** Hovering the pin you are heading for on the world map shows the time and distance left and every step there, worded as in the tracker, including on a guide's numbered stop.
- **No "Division by zero" error on a walk measured at no cost.** Retiming the route you are following uses the share of the walk still ahead, so a walk the search measured as free no longer breaks the timed replan.
- **Position reads wait for a readable position everywhere.** The nearest dock, ride detection, compass, tracker distances and flight timing skip a frame whose position the client withholds, as the journey already did, instead of erroring.
- **Connecting flights only through flight points you know.** A route no longer offers a flight that passes through an undiscovered flight point, which the flight master would not let you take, such as a Horde flight out of Moonglade through an unvisited Everlook or Bloodvenom Post.
- **A detached tracker with nothing to show leaves the screen.** Its "Forever tracker" title hides with the empty column and comes back, where you left it, as soon as a section has something to show.

## [1.14.1] - 2026-10-13

- **Data checked against Forever 1.60.1.70338.** The travel data is unchanged apart from its build pin.

- **Tracker stays put when Edit Mode places it by its centre or bottom.** Attaching to the quest tracker no longer pushes it down the screen when it has been moved away from the default top-anchored spot.
- **Shift+click shares to chat again.** With a chat box open, Shift+clicking a map pin or the map itself now inserts the link as Blizzard intends instead of starting a journey. With no chat box open it still plans a journey.
- **How the Forever addons work together.** The README and store page list each of the other Forever addons and what it adds when installed alongside this one.

## [1.14.0] - 2026-10-09

- **Choose the guidance you see.** Hide the Journey steps or direction arrow independently while retaining the map route, display distances in metres, and optionally open settings from a button below the minimap.

- **Resize map icons separately.** Transport, flight master and minimap icons have sliders from 25% to 200%. Right-click a flight master to correct whether its flight path is known.

- **Plan directly over Questie icons.** Alt-click the world map to use the exact cursor position without replacing Questie's click actions. Guidance settings and the tracker menu can resume RestedXP after choosing another journey.

- **Complete journey steps manually.** Click the current step and choose *Complete this step*. Skipping a Hearthstone keeps it out of later plans for that journey; other plans continue from your actual position.

- **Refresh the tracker without changing Blizzard's layout methods.** Journey sections update from quest and player events and wait until combat ends to move.

- **Data checked against Forever 1.60.1.70291.** Transport, flight, portal and teleport data are unchanged.

## [1.13.0] - 2026-10-08

- **Shorter addon descriptions.** The README and store pages explain the features directly and keep the author and licence credits.

- **Quest text stays on screen when the Forever tracker is smaller.** The native quest column and its header keep their full width at the edge of the screen.

- **Resize the tracker and compass separately.** The Interface settings have scale sliders from 50% to 200%. Tracker scale applies to the shared Forever sections and waits until combat ends when attached to the quest tracker.

## [1.12.1] - 2026-10-07

- **Guide navigation no longer fails when a route ends during planning.** A cancelled search stops its callback before touching cleared walking batches.

- **Quest objectives stay below the Forever tracker after reload.** The shared tracker no longer resizes Blizzard's quest container, which could move it over the addon sections.

- **RestedXP journeys start automatically.** Follow the guide's current target when RestedXP is installed, with no setup needed. A saved choice to disable *Follow RestedXP guides* remains unchanged.

- **Keep RestedXP navigation when you choose its display.** Adventure Guide's display choice also controls whether Shortest Path replaces the RestedXP arrow. Your standalone navigation preference is preserved.

- **Shared Adventure Guide navigation.** When Adventure Guide displays RestedXP instructions, its existing journey handles travel and Stop. The direct RestedXP adapter defers to it instead of starting a competing route.

## [1.12.0] - 2026-10-07

- **Follow RestedXP guides with planned journeys.** Turn on *Follow RestedXP guides* in `/path` to use the guide's current target for walking, flights and transport. RestedXP's arrow hides while the journey is active and returns when you stop. No TomTom or RestedXP TomTom addon is needed.

## [1.11.2] - 2026-10-07

- **Data checked against Forever 1.60.1.70245.** The bundled game data is unchanged.

## [1.11.1] - 2026-10-06

- **Walk along the pier to your boat.** Boat journeys use a dry boarding point for the walking route instead of the boat's position at water level, fixing paths that cut across the water at Auberdine and other docks. The compass and dock pins use the same boarding point. Boat schedules keep their original positions.

## [1.11.0] - 2026-10-06

- **Continuous flight routes.** Flight lines retain connected segments at default world-map zoom, with finer detail when you zoom in.

- **Clear travel actions.** When your current step needs a Hearthstone or teleport, its icon and item or spell name appear on screen. The prompt clears when you continue walking or stop guidance.

- **Readable map badges.** Numbered route actions keep their original size and lower-right position. Shift-click destination tags remain tucked beside the original map icon.

## [1.10.0] - 2026-10-05

- **Quest progress stays current in the Journey tracker.** Updating a stop refreshes its walking-step text while keeping the measured route.

- **Shift-click a flight master to plan a journey there.** Map icons keep their own art, with the destination tag at the lower right.

- **Walking maps stay inside one addon.** Terrain is compressed and decoded only where a journey needs it, keeping the addon list clear of walking-map parts.
- **Journeys prepare the walk you need first.** Later walking legs wait until they are next, and the search can offer a measured route while checking for a faster one.
- **The minimap route button is gone, and what it did lives in the game's own menus.** Nearby services is in the minimap's tracking menu as well as the world map's, and a click on the tracker's Journey header starts and stops the route, so the addon adds no button of its own to the minimap.
- **A zeppelin's icon is always drawn whole.** A map pin, minimap pin, compass marker or stop badge that had last shown a boat, lift, portal or quest mark could show only a corner of the zeppelin icon.
- **The world map shows the game's own quest area.** While you stand in the area of a quest a guide's stop names, the world map draws that quest's real area in gold, as the minimap does, in place of a circle of ours. A stop can stand for several quests at once, and one that names no quest keeps its pin and line.

## [1.9.0] - 2026-10-05

- **Flight times come from your own rides.** A flight you take is timed from take-off to landing, and that time is used the next time a journey plans the same route. While you are in the air the tracker counts the leg down from how far along the drawn route you are, so a slow or fast ride no longer makes its arrival time drift.
- **A guide that sets a TomTom waypoint can plan the journey here.** With TomTom not installed, Questie and other guides that set a waypoint through it now start a Shortest Path journey instead, carrying the guide's title; *Let guides set TomTom waypoints* in `/path` turns it off.
- **A quest area you are standing in is drawn by the game itself.** A held objective stop can name the areas it stands for; while you are inside one, the minimap recolours the game's own quest area to gold instead of drawing a circle of ours, the world map keeps the route's yellow outline, and the stop's pin and line step aside. The client's own inside-area state decides inside where the area names one quest.
- **The tracker returns after Edit Mode is locked.** Hiding and locking Edit Mode without leaving it no longer keeps the Forever sections hidden.
- **The stop you are travelling to stands out on the map.** Its numbered button is lit the way the game lights the quest it tracks, and the later stops keep the plain button.
- **The journey list holds still.** A step whose countdown sat right at the edge of the tracker gained and lost a second line as the time ticked, which shook the whole column up and down each second. A step that has taken a second line now keeps it until the steps themselves change.
- **Stormwind's flight point matches the current game build.** The game moved Stormwind's flight point about fourteen yards, so journeys through Stormwind now lead to the new spot and flights out of Stormwind are drawn from it.
- **The tracker reads in game order.** The game's All Objectives header leads the shared column, the Forever sections follow it, and your quests stay below them. In combat the game keeps its quest list in its own slot, so the header and quests stay together and the Forever sections sit directly below them, keeping the tracker to one column.
- **The performance report includes every loaded walking-map part.** `/path perf` counts the small terrain addons as well as their base maps, so its memory total covers the data used by a journey.

- **Starting a journey loads only the ground it needs.** Walking maps load in small parts as the search reaches them. A fixed walk on another continent keeps its measured cost and waits to draw its detailed line until you arrive there.

## [1.8.2] - 2026-10-03

- **A detached tracker keeps clear of your quests.** With Attach to quest tracker off, the Forever column could open on top of the quest list. Until you drag it, it now sits beside the quest tracker, level with its top; once dragged, it stays where you put it.
- **The way to your corpse starts on every death.** Releasing your spirit sometimes left your journey on screen instead of the red path back to your body, until the setting was switched off and on. The path now appears as soon as the game knows where your corpse lies.
- **A map click on open sea tells you.** Shift-clicking the world map where no zone lies, such as the sea on a continent map or the gap between continents, now prints that no journey can be planned to that spot instead of starting a journey to nowhere.
- **Nearby services says what is wrong.** Without QuestieDB installed the menu now reads Nearby services need the QuestieDB addon, and when QuestieDB is installed but cannot be read it says so, instead of listing every service as unavailable here.
- **No empty trainer and vendor menus.** Where a zone has no trainers or vendors, Trainers by specialty and Vendors by specialty now read as unavailable here like the other services, instead of opening an empty list.
- **Flight points in your game's language.** Once you have opened a flight map, journey steps and map pins name its flight points as the game does, rather than always in English.

## [1.8.1] - 2026-10-03

- **A journey you cannot walk to says why.** When you stand somewhere the walking map cannot place, and no flight, boat or spell gets you there either, the tracker now reads no walking path instead of No way there from here.
- **A minimap click that goes nowhere tells you.** Shift-clicking a spot on the minimap that cannot be turned into a place, such as the corner of a square minimap, now prints that no journey can be planned to that spot, as the same click on the world map does.

## [1.8.0] - 2026-10-02

- **Long walks take the boat.** A journey that would be one walk of ten minutes or more now takes boats, trams or flights when they arrive nearly as soon, such as the Stormwind and Menethil boats from Ironforge to Tirisfal Glades.
- **Opening the map no longer breaks it in a fight.** After Show on map, a dock or portal pin, or the nearby services menu had opened the world map, every later look at the map in combat raised a blocked-action warning and lost its quest markers until a reload. The map now opens cleanly and keeps its markers in combat.
- **The Hearthstone slider shows its value.** Minimum Hearthstone saving now reads out the time it is set to, and its name is no longer cut short.
- **The guides stay put in a fight.** In combat the game stretches its quest tracker and nudges it back on screen, which shoved the Forever sections sideways across the screen until the fight ended. They now stay stacked above the quest list.
- **Move the compass.** Settings → Interface → Move the compass lets you drag it anywhere on screen; right-click it to put it back. The journey tracker already moves: turn off Attach to quest tracker and drag it.
- **Setting names fit the panel.** The settings are renamed with shorter names, so none is cut off in the settings panel. Each tooltip carries the detail the name leaves out.

## [1.7.0] - 2026-10-01

- **Follow your movement speed.** Mounted speeds, boosts and slows affect route choices and arrival times, including while standing still. A speed change updates the active journey promptly.

- **Keep guides clear of quests in combat.** Companion sections stay clear when the quest list grows during a fight. Detaching restores the quest tracker’s original Edit Mode position.

- **Remove the Powderfuse Port flight path.** It no longer appears as a flight master or a route stop; its client data lacks the ordinary flight-map flags.

- **Set a minimum Hearthstone saving.** Journeys still consider the Hearthstone by default, or you can require a chosen number of seconds saved over the fastest route without it; class teleports remain eligible.

## [1.6.1] - 2026-09-30

- **Move the shared tracker.** Turn off Attach to quest tracker in Settings to drag all Forever sections together. The position survives `/reload`.

- **Organise the source.** Group runtime modules into Core, Routing, Journey, Transport and UI folders. Update the manifest, developer tools and tests while preserving client load order and runtime behaviour.

## [1.6.0] - 2026-09-30

- **Avoid hostile transport landings by default.** New installs leave opposing-faction boat and zeppelin routes off. Journey planning and travel estimates respect that choice; players who opted in keep their setting.

- **Development disclosure.** This release was developed with AI assistance. Changes were reviewed and checked with automated tests, linting and type checks; live verification remains ongoing.

- **Find nearby services.** Middle-click the route button or use `/spfnear` to open the nearby-services submenu in the world-map tracking dropdown. Route to a friendly class trainer, profession trainer, repairer, reagent vendor, innkeeper, bank, auctioneer, flight master or stable master. Trainers and vendors can be selected by specialty. Locations come from installed QuestieDB; class trainers use Tweaks Forever’s current-class list.
- **Hide walking directions inside quest areas.** Adventure Guide can hold an objective stop while its arrow and Journey lines step aside. Directions return if you leave the area.
- **Keep the tracker legible in combat.** Companion sections stay in one column without moving protected quest-tracker frames.

## [1.5.0] - 2026-09-30

- **A route button on the minimap.** A round button in the game's own minimap button art starts and stops the
  route in one click, and turns gold while a route is on. Right-click opens `/path`; *Show a route button on the
  minimap* turns it off.
- **The compass looks like the game and starts on for new installs.** The dark box and its border are gone: the ribbon is
  the game's own parchment ticks and gold letters, fading out at each end, with the destination drawn as the
  game's own waypoint pin. Existing compass preferences are kept. *Show a compass while Guide is on* in `/path` still turns it off.
- **Settings, grouped.** `/path` opens a short index of Map marks, Transport, Guidance, Alerts and Interface
  instead of one long list, with each group on its own page. Every option is where it was.
- **A dock pin's tooltip survives a filter change.** A pin whose cluster still held a pier the filter had just
  hidden no longer reads an empty departure list and raises a Lua error.

## [1.4.7] - 2026-09-29

- **Keep quest destinations visible.** Adventure Guide can hold a stop until the quest interaction changes, without the normal arrival radius clearing its guidance.
- **Keep one tracker column.** Addon sections stack above the quest tracker regardless of which companion addon loads first.
- **Stop the arrow cleanly.** Cancelling or replacing guidance no longer lets a queued arrow update read a cleared path or revive the previous destination.

## [1.4.6] - 2026-09-28

- **Keep map pins safe and responsive in combat.** World-map and minimap pin refreshes now wait until combat ends,
  while static portal, flight and transport layers reuse unchanged results and recover cleanly if the map releases
  their pooled pins.

## [1.4.5] - 2026-09-28

- **Keep route stops legible.** Numbered stops use warm gold rings instead of dim blue, and later stops retain stronger contrast. Pickup and turn-in badges remain visible on shared stops.

## [1.4.4] - 2026-09-28

- **Separate addon tracking from Blizzard’s layout.** Addon sections now use their own frame pools and sit beside the quest tracker, avoiding the shared tracker registration implicated in Edit Mode aura errors.
- **Check the client integration in CI.** Regression checks run against pinned Forever tracker source and reject native tracker registration.

## [1.4.3] - 2026-09-27

- **Native UI methods stay untouched.** Tracker registration waits for the game to finish loading, and route waypoint pins refresh through map and tracking events.

- **Clearer route pins.** Route circles have a muted blue tint. Grouped stops keep their action icon instead of a `+N` count; the tooltip lists every stop.

- **Smoother flight lines.** Flight routes curve gently on the world map and minimap, retaining their endpoints and loading boundaries.

## [1.4.2] - 2026-09-27

- **The compass draws transport icons as the map does.** Lift and tram arrows sit smaller beside the ferry, as they
  do on the world map and minimap, and the boat icon in the minimap's tracking menu keeps its own shape.
- **The departure dot can be translated.** The "·" between a dock's status and its departure time is now part of a
  phrase a translation can change.

## [1.4.1] - 2026-09-27

- **The corpse run says why it has no path.** When the walk back to your body can't be found, the tracker now gives
  the same reason a journey would: no walking map for the zone, the search failing, or no walking path at all.
  Before, it always said there was no walking path.

## [1.4.0] - 2026-09-25

- **Ready for translation.** Every line the addon writes, from the settings to the tracker and the map's tooltips,
  now comes from one list of phrases, so the addon can be translated. Translations are welcome on GitHub; anything
  not yet translated stays in English, as before.
- **A line on what changed after an update.** The first time you log in on a new version, one line in chat says
  which version you are on and the main thing it changed. It stays quiet on a fresh install, and *Tell me what's new
  after an update* in `/path` turns it off.

## [1.3.0] - 2026-09-25

- **The flight map shows which flight to take.** At the flight master, your journey's route uses the game's own
  lines and lights up the final destination, including flights through several stops. Hover other flight points
  as usual; your route comes back when you move away. *Show the flight to take on the flight map* in `/path` turns it off.
- **Route stops look like the map's own quest buttons.** Each numbered stop on the world map is now the brown disc
  with the gold ring the game uses for quests, with the game's own yellow number in it and the same glow on hover,
  rather than a thinner ring of its own.
- **A route stop that says what stands there keeps its number.** When another addon marks a stop as a flight master,
  a quest giver, a boat and so on, the map shows the numbered step circle with that icon as a small badge on its
  lower right, rather than the icon with a loose number beside it. A single destination still shows the icon alone.
- **The dotted path stops short of each stop.** The dots end a little before every numbered circle, on the map at any
  zoom and on the minimap, instead of running under it.
- **A place you go back to shows one circle.** Stops at the same place, or close enough to overlap on the map, share
  one circle with the first stop's number and a small *+1*, *+2* on its lower right. Hovering it names each stop.
- **Portal and flight point tooltips close with the map.** Closing the world map while hovering one used to leave
  its tooltip on screen; the dock and stop pins already cleared theirs.
- **A route sent while you are a ghost no longer errors.** Another addon's route queued behind the way back to your
  corpse, before any journey that session (after a `/reload` while dead, say), raised a Lua error in the tracker.
  It now waits quietly until you are alive again.

## [1.2.0] - 2026-09-25

- **The way back to your corpse.** Release your spirit and a dotted path leads from the graveyard back to your body,
  in the red-orange of the corpse's own tombstone, on the world map and the minimap. It follows the walking paths
  round walls and hills, Guide steers along it, and the tracker reads *Return to your corpse* with the time and
  distance left. The journey you were on steps aside and comes back when you are alive again, whether at your
  corpse, at the spirit healer or raised by another player; a route another addon asks for while you are a ghost
  waits the same way. *Show the way back to your corpse* in `/path` turns it off.
- **A stop shows what is there.** When another addon says what stands at a stop, such as a quest to hand in, a
  quest giver, a trainer or a flight master, its map pin shows the game's own mark for it, the “?” or “!”, inside
  the stop's gold ring, rather than a pin that hides it. On the minimap the stop is circled, so the game's own icon
  there stays in sight.
- **Guide marks only where each step ends, from the start.** The game's waypoint marker now goes straight to the
  next boat, lift, flight master or your destination rather than to each turn of the walk. Turn off *Guide marks
  only where each step ends* in `/path` to have it lead you round every turn again.
- **Journeys can start with your hearthstone.** The Hearthstone, a mage's city teleports (with a Rune of
  Teleportation in your bags), a shaman's Astral Recall and a druid's Teleport: Moonglade are the first step when
  they save time: *1. Use Hearthstone*, after its own icon and named in your game's language. A cooldown counts as
  waiting time, so a hearth due in two minutes can still win. Your bind point is learned when you next set it at
  an innkeeper, and forgotten if you bind somewhere else without the addon, or on a `/reload` or relog while the
  client does not load addons' saved settings. Other addons' estimates from where you stand count them too.
  *Use your hearthstone and teleports* in `/path` turns this off.
- **Walking legs are round breadcrumb dots.** They are evenly spaced around every bend, instead of dashes, on the
  map and the minimap alike, and a little smaller on continent and world maps. Boats, zeppelins and flights keep
  their solid coloured lines.
- **Arrival alerts sound like the transport.** A boat rings the ship's bell it rings at the dock, a zeppelin
  sounds its horn and the tram plays its own arrival, instead of the raid-warning sound, which reads as a boss
  mechanic rather than your boat.
- **Other addons can offer Shortest Path guidance.** The version 1 public API estimates travel time and starts
  journeys through one or several stops in order. Numbered map pins, drawn as the Adventure Guide's gold-numbered
  rings that glow when you hover them, mark the remaining stops, and the way on to each is drawn as you will
  travel it: walks follow the paths round hills like the current leg, and boats, zeppelins and flights show in
  their colours, never a line across the sea. A dotted straight line stands in only until that stretch is worked
  out, a moment after the current leg's. Stops whose pins would overlap at the map's zoom share one, numbered like
  *4-7* or *2, 5*, and hovering it names each stop in order. The stop you are heading for keeps its pin at full
  strength, and later stops overlapping it join that pin rather than stack on it. Guidance advances on arrival
  and shows your progress. An addon can check the current stop and cancel only its own whole route, preserving a
  journey you start yourself. It can also show how a trip goes, such as the boat, the flight and a new flight
  path to pick up on the way, say why no time is shown (in combat, or no way there yet), and warn you before
  replacing a journey you are already on.
- **Transport shows on the minimap.** Docks, lifts, tram stations and portals appear there with the world map's
  icons, and hovering one gives the same departures tooltip. They vanish at the minimap's rim like the game's own
  tracking icons, and cost nothing away from them. *Transport* in the minimap's tracking menu, or the new setting
  in `/path`, turns them off.
- **An untimed crossing gives the average wait.** A journey step on a boat, lift or tram that nobody has timed yet
  no longer says “no sighting yet” beside a wait it cannot know. It reads *leaves in about 2:45* instead: half the
  loop. Timed crossings read *leaves in 2:28*, a teleport on cooldown *ready in 4:12*, and a flight step no longer
  shows a wait, since taxis leave the moment you pick where to go.
- **Tram journeys name where you are walking.** Journeys through the Deeprun Tram no longer tell you to walk to
  “Unknown”. A step towards a passage or portal names it, such as *Walk to Passage to Stormwind*, and a tram
  passage's map pin says where it leads.
- **Guide tidies up its map pin.** It keeps the pin hidden and removes it when a journey ends, tracking changes or
  you reload, while preserving your own pins and tracking choices.
- **Clicking a dock, station or portal opens the other end.** The world map moves to the far side of the crossing
  and pings where it comes in. A dock with boats or zeppelins to several places asks which one with a small menu.
  The tooltip says when a click will take you somewhere.
- **A search shows the Group Finder spinner.** New journeys show a destination pin and the familiar spinner while
  finding the fastest way, then reveal the route and steps together. Longer searches show their best route after
  three seconds and keep it unless another is at least 30 seconds and 10% faster, or the route no longer works.
  While the spinner turns, the route pulses gently on the world map and minimap, becoming steady when the search
  finishes. Later checks happen quietly without pulsing routes or changing “finding” messages. Journey searches
  retain less memory, clearing a journey frees its caches, and `/path perf` now collects unused memory before
  reporting what remains.
- **The Journey header's time is the sum of the steps below it.** It used to count down to the planned arrival, so
  standing still it slipped a few seconds below the steps and jumped back every five seconds.
- **Walks in Stormwind no longer loop round the city through the canals.** The game never reports your height,
  and the walk started from the lowest floor under you, often the canal bed below a street. A walk from somewhere
  with several levels, or to a map click or stop there, now starts from whichever one is quickest. Zeppelin walks
  end on the tower's platform, not the ground below it, at Grom'gol, Tirisfal and the tower to Zephras. A walk no
  longer runs out and back along the same street, as one from Stormwind's flight master to the Mage Quarter did
  past the Trade District.
- **The rotating minimap and the compass no longer raise Lua errors** when the game briefly hides your facing.

## [1.1.0] - 2026-09-23

- **Open the settings from the addon compartment** on the minimap, as with `/path`.
- **The Journey and Boats section keeps its place in the objective tracker** beside SkillUp Forever's shopping list: the two shared one slot, so their order could change; each now has its own, above your quests.
- **A new icon**, drawn to match the other WoW: Forever addons, now also on the three walking maps in the addon list.

## [1.0.0] - 2026-09-23

- **A route finder for WoW: Forever.** Pick a spot on the map or a quest and it plans the fastest way there and
  walks you to it.
- **Every boat and zeppelin has its dock marked on the world map**, including the new Forever crossings to
  Southshore, Riverglades and Zephras Isle: a ferry for boats and a zeppelin drawn to match it for zeppelins.
  Hovering a dock lists where each boat goes next, counts down to its arrival and departure, and lights up the
  docks it sails to. Docks that would overlap on a zoomed-out map share one icon, with each pier named in the
  tooltip. The map's filter menu can hide the icons, or just the other faction's routes. Near a dock, a Boats
  section above your quests shows the same countdowns.
- **One ride fixes a boat's schedule for hours.** Each route's loop time comes from the game's own path data.
  Ride once and it syncs, and the sighting is shared quietly with your guild, party and anyone at the dock, so
  other players' rides time your boats too. Sharing can be turned off in the settings (`/path`).
- **Lifts, the tram and portals are timed and marked too.** The lifts at the Great Lift, Freewind Post, Thunder
  Bluff and Undercity, and both Deeprun Tram trains, are timed the same way: countdowns on the map and in the
  tracker, synced from a ride and shared. The tram is marked at its city entrances, and portals are marked with
  where they lead.
- **Shift-click the world map or minimap to plan the fastest way to that spot.** It combines walking, the flight
  points you know, boats and zeppelins with their live waits, the lifts, the tram and portals, and a flight master
  you haven't found yet when walking to it pays off. **Plan journey** in a quest's right-click menu, or
  Shift-clicking its marker on the map, does the same for its objective, or its turn-in once it is complete.
- **The route is drawn on the world map and minimap** as a slim outlined line that reads on any map, walking legs
  dotted and the destination marked with the waypoint pin, and its steps sit in the objective tracker like a
  tracked quest. Flight masters are marked on the world map, known and undiscovered, and hovering a dock draws its
  boat and zeppelin routes. On the Azeroth map, crossings curve from dock to dock across the sea; closer maps keep
  the real sailing path to the map edge.
- **Guide moves the game's own waypoint marker along the route.** It is on from the start of every journey and
  toggled from the tracker header, goes turn by turn (or only to where each step ends, a setting), and gives your
  tracked quest back when you finish.
- **Walking legs follow the ground** round walls, cliffs and water on Eastern Kingdoms, Kalimdor and Zephras Isle,
  from walking maps that come in the same download. They take tunnels such as Dun Algaz and the Undercity's lower
  levels, ride a lift when the way round on foot is longer, and take the boat rather than a long swim. Walks keep
  out of water, unless you have Water Walking or Levitate, when the step asks you to cast it and the route
  crosses. Walks between docks, flight masters and portals are measured ahead of time and ship with the addon, so
  plans spend less time checking walks. Replanning on board keeps you on the boat.
- **Searches settle quickly and stay light.** While a journey's walks are being checked, the tracker says it is
  finding the fastest way and the route pulses softly on the map and minimap. Easy routes settle quickly, and
  longer searches stop once unchecked alternatives cannot beat the chosen route, without searching the whole
  continent. Drawn paths stay visible during refreshes. Route finding uses less memory and shares its work across
  frames to reduce hitches; the first walking-map load starts after the click. Repeated journeys to the same
  destination reuse their walking costs. Your position is checked again when you leave the path or once a minute;
  standing still or moving a few yards within the same walking-map cell reuses its costs. Once settled, the
  arrival countdown returns. Walk steps name the dock, pier, lift or flight master you are heading for.
- **An optional compass strip follows your facing.** It marks Guide's next two turns, the next stop and your
  destination, with yards to the next turn. It is off by default and can be turned on in `/path`. Its heading
  glides smoothly as you turn, with stock UI fonts, a soft frame and correctly proportioned markers. Marks for the
  same place or bearing combine into one, keeping the destination or transport icon and the distance to your next
  turn.
- **Guide and the route keep going when your coordinates drop out.** They survive temporarily unavailable player
  coordinates, and the drawn walking leg trims as you move without waiting for the next route search. On the
  minimap, the final 30 yards fade into the destination and the whole line fades as you approach within 40 yards.
  Guide's final marker uses a fading arrow nearby so its native waypoint does not cover the goal; the world-map
  route keeps its contrast.
- **On board, the tracker shows where the boat calls next** and when it gets there, once the ride has synced.
  Half a minute before a timed boat reaches the dock you are waiting at, and shortly before your own boat docks,
  a raid-warning banner, a sound and a flashing taskbar icon let you know, even with the game in the background.
  A `/reload` or logout mid-ride keeps the ride so far. Every map layer, the tracker, the alerts and their sound,
  the planner and sharing can each be switched off in the settings.
- **The Journey section in the objective tracker shows the time and yards remaining** across every leg,
  following measured walking paths and transport routes. The destination stays on its own line, and the totals
  update as you travel without rebuilding the tracker layout.
- **Background polling sleeps when you are standing still** away from travel activity. Docks and passive boat or
  lift rides still wake the countdowns and observation; unchanged tracker content is reused, and shared sightings
  don't rebuild unrelated map layers. Walking searches and tracker updates wait through combat. Less terrain
  bookkeeping is built at login, and `/path perf` shows the client's measured CPU cost and addon memory for
  checking performance in game.
