# Forever Combat Text

**WoW Forever beta 1.60.1 · Interface 16001**

A combat-text addon for WoW Forever beta, adding a little more flexibility than the built-in display: floating numbers on visible nameplates, damage-school colors, and a few useful options.

The goal is to keep combat text easy to use and configure. Damage is the main focus, with optional healing text on friendly nameplates.

## Features

- Damage on all visible enemy nameplates, with an optional current-target-only mode.
- Includes opening hits and any periodic damage events delivered by the client.
- Larger, pulsing critical damage and healing numbers.
- Customizable school colors: Fire orange, Frost cyan, Nature green, Shadow purple, Arcane pink, Holy gold, and Physical pale yellow by default. Multi-school damage blends colors.
- Healing text on accessible friendly player, NPC, pet, and healable minion nameplates; all healers' events are combined.
- Friendly NPCs and minions automatically follow Blizzard's **Only Show Names** setting, keeping reaction name colors while bars stay hidden.
- The Show Friendly toggle (keybind included) also drives Friendly NPC plates, which Blizzard otherwise leaves independent.
- Addon options to show or hide friendly NPC and minion nameplates individually; a category shows only when the master Show Friendly toggle is on and its own option is on.
- Optional automatic hiding of all friendly nameplates while resting in cities (capitals, towns, inns), with your previous settings restored on leaving.
- Blizzard healing numbers take over automatically when all friendly plates are off (damage already worked this way).
- Optional elite/boss, rare-elite, and rare icons on enemy nameplates.
- Optional Blizzard outgoing-healing display in dungeons and raids.
- Configurable damage-school and fallback colors, built-in client font choice, text size, healing color, label duration, and separate nameplate damage and healing offsets.
- Optional suppression of Blizzard's outgoing damage text to avoid duplicate numbers.
- Automatic Blizzard damage-text fallback when the enemy-nameplate setting is off.
- Scrollable options under **Settings → AddOns → Forever Combat Text**, with preview, diagnostics, and reset.

Healing received by your character stays with Blizzard. The optional instance setting controls only Blizzard's native outgoing-healing numbers.

Numbers stay on screen until they fade, even when the mob they belong to dies or leaves the area. They finish rising and fading in place, as in the default game UI, rather than disappearing with the nameplate. The exception is when the game immediately reuses that nameplate for another mob: the number is then removed early, so it never appears above the wrong enemy.

**Show miss, dodge, parry and block text** is off by default. When enabled, the addon shows `Miss`, `Dodge`, `Parry`, `Block`, `Resist`, `Evade`, `Immune` and `Absorb` in a neutral gray, on the same nameplates and under the same damage-scope rules as damage numbers. These fire often, so the option is opt-in; the color is adjustable with **Outcome text color**.

Outcome words follow your game language by default, using the client's own combat-text strings (for example French words on a French client). **Outcome text language** overrides this with English, Deutsch, Français, Español, Português, Italiano, Nederlands, Czech, Svenska or Norsk (BiS), so you can pick different wording than your client uses. The override changes only these outcome words, not the rest of the addon. Players on Russian, Korean or Chinese clients get native text through **Game language**; those languages, and Polish, are not offered as overrides because Western clients' combat-text font lacks some of their letters.

A hit that reports zero damage is displayed as `Absorb` (in the chosen language) when outcome text is enabled, or skipped when outcome text is disabled rather than shown as a bare `0`.

Addon damage and healing are both driven by nameplates, so the corresponding nameplate categories must be enabled for either to appear. Damage uses enemy nameplates; healing uses accessible, assistable friendly nameplates other than your character's.

## Controls

| Command | Action |
| --- | --- |
| `/fct` or `/forevertext` | Open addon options |
| `/fct preview` | Sample all seven damage schools, a critical, healing, and miss/absorb outcomes at a visible nameplate |
| `/fct status` | Client version, nameplate/event counts, skipped-event counts, NPC styling counts, friendly-plate toggles, and Blizzard damage-text setting |
| `/fct report` | Compact copy-paste session report: styling counts, friendly-plate states and toggles, and combat totals |
| `/fct watch [secs]` | Log CVar changes for 30s (default) so a keybind press reveals exactly which CVar it flips |
| `/fct on` / `/fct off` | Enable or disable all floating combat text |
| `/fct help` | Show commands |

**Reset settings** restores defaults, including colors, font size, label duration, both offsets, and damage scope.

## Number appearance

The **Text size** slider ranges from 12 to 60, defaulting to 22. The **Text font** dropdown offers Game default, Friz Quadrata, Arial Narrow, Morpheus, and Skurri. Game default uses the client's locale-aware `STANDARD_TEXT_FONT`; the other choices reference fonts supplied by the game client, and the addon does not bundle font files. Font and size changes affect newly displayed numbers and are saved across `/reload`.

**Color damage by school** enables the school palette. **Customize damage colors...** opens color pickers for each school and the fallback color used when school colors are disabled or unavailable. Mixed-school damage averages the selected school colors. **Reset damage colors** restores the palette and fallback color without changing healing or outcome colors. These choices are saved across `/reload`.

- **Nameplate damage offset** moves damage text on both targeted and unselected enemies.
- **Nameplate healing offset** moves only addon healing text on friendly nameplates.
- **Label duration** controls how long a number stays on screen, from 0.6 to 3 seconds, defaulting to 1.2.

Both offset sliders display adjustments relative to a baseline 30 UI units below the nameplate anchor. Damage and healing both default to **0** (an actual offset of -30). The displayed range is -30 to 70. Lower values move that type of text down; higher values move it up. Each setting affects newly displayed numbers and is saved across `/reload`. Text rises slightly as it fades. **Preview nameplate** displays a sample for each of the seven damage schools, plus a critical, a healing, and gray `Miss` and `Absorb` samples, so the colors can be compared. The samples are ordinary floating text that rises and fades as live text does, released over about a second in a staggered burst with a slight random offset each, to resemble combat rather than appearing all at once on one spot.

Stacked numbers are spread horizontally and alternate slightly in height, so two hits landing at the same moment stay readable.

Saved positions are retained across updates rather than reset. **Reset settings** applies the defaults to both offsets and all other options.

## Critical numbers

Critical damage and healing start at up to twice the selected text size, then pulse up to 20% larger before settling and fading. The animated text height is capped at 144 UI units, including the pulse. Colors and damage/healing offsets still apply.

This is inspired by Blizzard's larger critical feedback and floating-text grow/shrink effect; it is not an exact reproduction of the game's outgoing world-space animation. `/fct preview` provides a synthetic critical sample so you can judge the appearance directly.

## Blizzard damage text

**Hide Blizzard outgoing damage numbers** is enabled by default. It uses `floatingCombatTextCombatDamage_v2`, with the legacy setting as a fallback. Disabling this option, the addon display, or the damage toggle restores the previous value. Logout and reload also attempt restoration.

**Show Blizzard damage when enemy plates are off** is enabled by default. While suppression is enabled, turning off enemy nameplates enables Blizzard damage text; turning nameplates back on hides it again. This follows the enemy-nameplate setting, not the visibility of an individual mob's nameplate.

The addon checks the setting after changing it and retries on world entry and after combat. `/fct status` reports its value: `0` is hidden and `1` is enabled.

## Friendly styling and elite icons

**Friendly NPCs and minions follow Only Show Names automatically.** When Blizzard's friendly-player **Only Show Names** setting is on, accessible friendly non-player plates keep Blizzard's standard reaction name colors (friendly green, neutral yellow) instead of falling back to white, and their bars, cast bars, auras, and level indicators are hidden. There is no separate addon toggle: turning off Blizzard's setting restores full plates. Plate styling is independent of both floating-text switches below. "Enable floating combat text" is the general switch for all floating numbers; "Enable Forever Combat Text numbers" controls only the addon's own numbers, leaving Blizzard text to the fallback rules. Unticking either stops the addon's text without reshaping nameplates. The hiding only uses Show/Hide on Blizzard's container frames and never touches bars, layout, or hit-test areas; it is experimental and may be reverted to tint-only if Blizzard errors return. Plates that are protected in combat are styled after combat; forbidden plates are excluded. The clickable bar region is unchanged. Toggling friendly nameplates (default Shift-V) is counted for `/fct report`, covering players, NPCs, and minions. The keybind itself flips only friendly-player plates (minions follow the same setting), so the addon mirrors the master toggle onto the "Friendly NPC nameplates" setting, which has no keybind of its own. The NPC entry still works independently between master flips.

**Show elite/rare icons on enemy nameplates** is off by default. It adds a gold icon for elites/bosses, a silver icon for rare elites, or a star for rares to the right of accessible enemy plates. It uses Blizzard's installed artwork and does not change the native level text.

## Native healing in instances

**Enable Blizzard outgoing healing in instances** is on by default. It enables `floatingCombatTextCombatHealing_v2` in dungeons and raids and restores the previous value when you leave, disable the option/addon, reset settings, or log out. Failed restoration is retained for retry. Incoming healing and shield settings are unchanged. Existing saved choices are preserved.

These are Blizzard's native outgoing numbers, not a custom stream near your character or on portraits. The native display can operate independently of addon-accessible nameplates, but its dungeon recipient, periodic-heal and overhealing coverage still needs in-game confirmation in the beta. It may duplicate addon healing where friendly plates are accessible. `/fct status` reports the current native healing value.

## Installation and saved settings

Forever Combat Text targets WoW Forever beta 1.60.1, interface 16001. It displays numbers on accessible visible nameplates: enemy nameplate visibility controls damage coverage, and accessible assistable friendly nameplates are required for addon healing numbers.

Install by extracting the archive into your `Interface/AddOns/` directory. The archive contains a single `ForeverCombatText/` folder whose `.toc`, Lua files, and icon sit directly inside it. Updates replace the addon files while WoW's separately stored settings remain intact.

Settings are stored separately by WoW and preserved across updates. Obsolete experimental 2D healing settings from earlier versions are automatically removed.

## Beta limitations

Client API constraints and remaining beta coverage limitations:

- `UNIT_COMBAT` does not identify the attacker or healer. Damage from everyone is combined; there is no "Only me" source filter or separate other-player color.
- The event does not distinguish direct damage from DoT ticks. Periodic coverage depends on what the client delivers.
- All-enemy mode includes nearby enemies damaged by other players, not a proven list of enemies fighting you specifically.
- Friendly nameplates may be inaccessible in instances. Numbers require an accessible visible nameplate.
- Friendly-player healing has been observed in open-world play. Newly expanded NPC/pet/minion healing, NPC name colors, elite icons, and native dungeon healing still need in-game testing. No addon healing appeared during one earlier dungeon run; the exact plate/event restriction has not been diagnosed.
- A wound reported with a zero amount is treated as an absorb, showing as `Absorb` when outcome text is enabled or skipped when outcomes are disabled.
- Hostility is remembered from when the nameplate appeared, so an opening hit is still shown when the client withholds that answer in combat. If hostility was never readable, damage is still shown on your current target unless friendly or group indicators identify them as friendly; `/fct status` counts both cases.
- A hit is only seen around a tracked nameplate. A pending nameplate buffers combat events until attached, and a removed nameplate keeps listening for a fraction of a second so a killing blow reported just after the mob dies is still shown.
- Unknown or inaccessible damage schools use the fallback color. Inaccessible event types or filtering results are skipped.
- Availability and glyph coverage of the alternate built-in font paths have not yet been confirmed on the Forever beta client; Game default remains the locale-aware fallback.
- The addon uses supported unit events rather than restricted combat-log events. Beta API behavior may change.

## API references

- [Forever unit event documentation](https://github.com/Ketho/wow-ui-source-forever/blob/master/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Forever nameplate API](https://github.com/Ketho/wow-ui-source-forever/blob/master/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua)
- [Forever combat-log restrictions](https://github.com/Ketho/wow-ui-source-forever/blob/master/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua)
- [Forever critical combat feedback](https://github.com/Ketho/wow-ui-source-forever/blob/forever/Interface/AddOns/Blizzard_FrameXML/Mainline/CombatFeedback.lua)
- [Forever floating-text critical animation](https://github.com/Ketho/wow-ui-source-forever/blob/forever/Interface/AddOns/Blizzard_CombatText/Shared/CombatText.lua)

## Copyright and license

Copyright © 2026 Morpster. All rights reserved.

Forever Combat Text is free to download and use. Its Lua source is publicly accessible and unobfuscated. Redistribution, publication of modified versions, and reuse of the project's code or artwork require Morpster's permission, except where permitted by applicable law or the distribution permissions in `LICENSE.txt`.

The addon implementation and logo design were created for this project. No third-party addon libraries, font files, or extracted Blizzard artwork/audio are bundled. Blizzard's UI templates and game font are referenced through the installed client, not redistributed. API documentation links are references, not included source implementations.

World of Warcraft and Blizzard's assets belong to their respective owners. This is an independent community addon, not affiliated with or endorsed by Blizzard Entertainment.
