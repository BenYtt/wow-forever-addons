<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/media/icon-400.png" width="96" alt=""></p>

<h1 align="center">SkillUp Forever</h1>

<p align="center">
Classic profession-levelling numbers inside WoW: Forever's Professions window.<br>
<a href="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/skillup-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/skillup-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/skillup-forever" alt="Latest release"></a>
<a href="https://ko-fi.com/cjber59408"><img src="https://img.shields.io/badge/Ko--fi-tip-ff5e5b?logo=ko-fi&logoColor=white" alt="Ko-fi"></a>
</p>

SkillUp Forever shows skill-up chances, recipe costs and colour thresholds in the Professions window. Its side panel has levelling routes, shopping lists and crafted gear.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/demo.gif" width="640" alt="Leatherworking levelling from 48 to 60 in the Professions window"></p>

From 48 to 60 the rows re-sort by cost per skill-up, and Handstitched Leather Bracers turns green at 55.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/window.png" width="640" alt="The Leatherworking window with skill-up chance and cost per skill-up on each recipe row, and a tooltip showing reagent prices and cost per skill-up"></p>

Each row shows its chance and cost; the tooltip beside the window prices each reagent. This character skins, so Light Leather is free.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tooltip.png" width="640" alt="A recipe tooltip with the orange, yellow, green and grey thresholds on a bar, your skill marked, and each reagent's price and cost per skill-up"></p>

The recipe tooltip draws the thresholds on the game's own bar with your skill marked, then each reagent's price and the cost per skill-up.

## Features

- **Recipe rows and tooltips** show skill-up chance, cost and colour thresholds.
- **Sorting** orders recipes by difficulty range start, chance or cheapest skill-ups. *Default* restores the game's categories and filters.
- **Levelling routes** list crafts, trainer visits, skill books and rank quests to your target skill, including fees, tools and stations. Steps allow for unlucky skill-ups. Cheaper crafted reagents become their own steps; a route that stops short names recipes that could extend it. Right-click a recipe to pin it for skill-ups or choose *Not this recipe* to plan without it. [Route details](docs/route.md#levelling-route).
- **Shopping lists** count reagents against your bags and bank. *Buy reagents* chooses whether materials your professions gather are free or bought. Track the list beside quests, buy vendor stock and keep an Auctionator list up to date. At the auction house, search a recipe's reagents for as many crafts as you choose. [Shopping details](docs/route.md#shopping-list).
- **Trainer annotations** show chance and cost, with a green arrow on the recipe that best extends or cheapens your route.
- **Reagent tooltips** show what tracked routes need. Hold Shift for every recipe that uses the item and still skills up.
- **Gathering nodes** show the Herbalism or Mining skill they need, coloured at yours, on English clients.
- **Crafted gear** shows the newest item you could craft for each slot, with its recipe, reagents and learning location. Enable its tab in settings. [Gear details](docs/gear.md).

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/route.png" width="640" alt="The SkillUp route tab: training and crafting steps from 48 to 73 with their costs, and the reagents they need"></p>

The route tab from 48 to 73: belts to 56, then train the pants, cure the hides they need and craft the rest of the way, with where each reagent comes from.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/shopping-list.png" width="640" alt="The standalone SkillUp shopping list with source groups, missing counts and prices"></p>

The shopping list groups what is missing by source, shows bag and alt holdings alongside current prices, and can start a vendor trip.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/gear.png" width="640" alt="The Crafted gear tab: item slots down both sides and along the bottom, each showing the newest crafted item, with one slot's recipe, reagents and status in the middle"></p>

The gear tab, turned on in settings: each slot shows the newest thing this character could craft for it.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/tracker.png" width="320" alt="The objective tracker with Leatherworking to 73, the next training step and the reagents still missing"></p>

Tracked, the same route sits beside your quests: the next trainer visit and what's still missing.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/trainer.png" width="320" alt="An Apprentice Leatherworking trainer's recipes, each with its skill-up chance and cost, and a green arrow on the vest"></p>

At the trainer, every recipe shows its chance and cost; a green arrow marks the one that best extends or cheapens your route.

<p align="center"><img src="https://raw.githubusercontent.com/cjber/skillup-forever/main/docs/screenshots/reagent.png" width="320" alt="Light Leather's tooltip with how much the tracked route needs"></p>

Hover a reagent to see how much your tracked routes need.

`/su leaderboard` (or `/su stats`) ranks distinct recipes SkillUp has observed as learned on your character against totals reported by guild and group members. Repeated scans and relearning the same recipe do not increase the total. Recipes in linked or guild profession views do not count.

![Chat output from the observed recipe leaderboard](docs/screenshots/leaderboard.png)

Sharing defaults on. Turn it off with `/su share off` or the checkbox in Settings > AddOns > SkillUp Forever. This stops sending and receiving totals and hides other players while keeping your local observations. `/su share on` resumes sharing. Reported totals are not verified.

## Install

Install it from [CurseForge](https://www.curseforge.com/wow/addons/skillup-forever) or [Wago Addons](https://addons.wago.io/addons/skillup-forever), or download the zip from [Releases](https://github.com/cjber/skillup-forever/releases). To install the zip by hand, extract it into the WoW: Forever client's `Interface/AddOns/` folder (`_forever_` on the live client, `_classic_beta_` on the beta).

## Usage

Open a profession and the numbers are already there.

| Command | What it does |
|---|---|
| `/su`, `/skillup` | Open the settings (also in Settings → AddOns, or from the addon compartment on the minimap) |
| `/su skipped` | List the recipes you said *Not this recipe* to on this character, with their IDs |
| `/su unskip <ID>`, `/su unskip all` | Show a skipped recipe, or every one, in the route again |
| `/su audit` | With a profession open, compare the bundled thresholds with the colours the game shows and print any mismatch |
| `/su report` | Show a report to copy into a bug report: versions, professions, routes, the audit and recent errors |
| `/su issue` | Open a ready-made GitHub issue link to report a bug or request a feature |
| `/su shopping`, `/su shop` | Open the shopping list for tracked professions, copy it, or plan a buy trip with Shortest Path Forever |
| `/su trainers` | List the trainer skill requirements SkillUp guessed, and which ones a trainer has confirmed or shown differently |

Settings cover rows and tooltips, what crafts count for, sort order, the route and crafted gear tabs, trainer annotations, reagent and gathering tooltips and Forever addon hints. Turn off **Show tracked professions** to hide the tracker, or **Attach to quest tracker** to drag the Forever column.

## Prices

Each reagent uses the cheapest known vendor or Auctionator price. Common vendor supplies have bundled prices; visiting a vendor records its prices and reputation discounts. Materials your professions gather count as free until you choose *Buy reagents*, or cost what they'd sell for with *Value gathered materials at what they'd sell for* on.

Auction prices are Auctionator's latest recorded price for reagents and crafted items. SkillUp never scans the auction house itself: scan with Auctionator to update prices. Missing prices stay unknown and leave affected recipes out of the route.

A craft's vendor sell value comes off its cost, or its auction value after the 5% cut if you choose. Profit shows a green `+` and cost a red `-`. Cost per skill-up is net craft cost divided by skill-up chance; *Money on recipe rows* shows net per craft instead, on recipes that no longer give skill too.

## How the numbers work

Each recipe has four thresholds: orange (start of its skill range), yellow, green and grey. Chance follows the Classic formula:

| Colour | Chance |
|---|---|
| Orange | 100% |
| Yellow, green | `(grey − skill) / (grey − yellow)` |
| Grey, or at your skill cap | 0% |

The colour always comes from the game, so the addon never disagrees. Thresholds and recipe data come from the Forever client's `SkillLineAbility` (via [wago.tools](https://wago.tools)). The grey threshold is the game's own live value where it reports one. Missing or contradictory ranges show `?`. Training requirements are separate from these difficulty bands.

**Found a wrong number?** Open that profession, run `/su report` and paste its text into a [Wrong number issue](https://github.com/cjber/skillup-forever/issues/new?template=wrong_number.yml).

## Works alongside

All optional: Auctionator supplies auction prices and takes the shopping list, TomTom draws waypoint arrows, and Syndicator shows your other characters' reagents. [Questie](https://www.curseforge.com/wow/addons/questie) names the vendors, quests and trainers the route points to, and [AtlasLoot Classic Forever](https://www.curseforge.com/wow/addons/atlasloot-forever) tells it which scroll teaches which recipe; without them the route still plans your crafts, and says in one line what to install for the rest.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does |
|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. |

<!-- forever-family:end -->

With [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever), clicking a trainer or vendor in the route plans the trip there, and SkillUp picks the nearest one by travel time. [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) shows each profession's next steps in its Professions tab. A tracked route shares one tracker column with the Shortest Path, Adventure Guide and Legacy Forever sections, above your quests.

## Development

Link the checkout into the game (`ln -s "$PWD" ".../Interface/AddOns/SkillUpForever"`) and run the gate under [Commands in AGENTS.md](AGENTS.md#commands) ([tools/README.md](tools/README.md) covers the data generators). CI runs the same gate plus actionlint, zizmor, gitleaks and the project rules; a daily job opens a pull request on a newer Forever build.

Run `luajit tests/bench.lua` to measure loading, route rebuilds, event bursts and cached lookups in the headless client. These are CPU timings, not in-game latency measurements.

**Releasing:** follow the [release skill](.agents/skills/release/SKILL.md) for data, copy and screenshot checks, main-branch CI, signed tags and store verification. The BigWigs packager publishes the version's changelog entry to GitHub, CurseForge and Wago.

**Translating:** translated into German, French, Spanish, Brazilian Portuguese, Russian, Korean and Chinese (machine translated; corrections welcome through the [translation form](https://github.com/cjber/skillup-forever/issues/new?template=translation.yml)).

**Contributing:** read [CONTRIBUTING.md](https://github.com/cjber/.github/blob/main/CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) first. Report security problems privately, as [SECURITY.md](https://github.com/cjber/.github/blob/main/SECURITY.md) describes.

## Support

The addon is free and stays GPL-3.0. If it saves you time, you can [buy me a coffee on Ko-fi](https://ko-fi.com/cjber59408); nothing is locked behind it and there is no paid version.

## Credits

Thresholds come from the game via [wago.tools](https://wago.tools), trainer fees, drop chances and gathered reagents from [CMaNGOS classic-db](https://github.com/cmangos/classic-db) (GPL-3.0), and vendor reagents from [LibPeriodicTable-3.1](https://github.com/doadin/libperiodictable-3-1) (LGPL-2.1). Some features were inspired by [Polestar](https://github.com/fitzforge/polestar) by Fitz, such as the skill colour on gathering nodes; no code was copied. Fitz is welcome to use our code. Thanks to Brainc3ll for French lines, kopuliak, chuujitsuna, berserkerlxl, syrberus, kurila11478, ballara, trias6657, deathmvp1 and everyone listed in [THIRD_PARTY.md](THIRD_PARTY.md).

## Licence

GPL-3.0-or-later. Vendors, quests, NPC places and scroll recipes are read in game from your own Questie and AtlasLoot, and none of their data is bundled. Every input and its licence: [THIRD_PARTY.md](THIRD_PARTY.md).

Made by Cillian Berragan · [cillian.dev](https://cillian.dev) · [GitHub](https://github.com/cjber) · [Twitter](https://twitter.com/cjberragan)

Built with AI assistance.
