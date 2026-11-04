# Third-party notices

Manners bundles the libraries below. They are **not** covered by the addon's own
MIT licence — each keeps its own terms, reproduced or linked here.

The release workflow builds the package with the BigWigs packager, and
`.pkgmeta` has it pull these from their upstream repositories at build time
rather than redistributing copies from this project.

| Library | Author(s) | Licence |
|---|---|---|
| LibStub | Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke | Public domain |
| CallbackHandler-1.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceAddon-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceEvent-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceTimer-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceConsole-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceDB-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceDBOptions-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceGUI-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| AceConfig-3.0 | Ace3 Development Team | BSD-style (Ace3) |
| LibSharedMedia-3.0 | Elkano | **LGPL v2.1** |
| LibDataBroker-1.1 | tekkub | BSD |
| LibDBIcon-1.0 | Rabbit | BSD-style |
| LibRangeCheck-3.0 | mitch0, WoW UI Dev Community | MIT |

## LibSharedMedia-3.0 — LGPL v2.1

This is the one copyleft dependency. LGPL v2.1 permits distribution alongside a
differently-licensed addon provided the library itself remains under the LGPL
and its source is available. Both hold here: the library ships as readable Lua,
unmodified, and its upstream is linked in `.pkgmeta`. Do not modify the bundled
copy without also publishing those changes under the LGPL.

Full text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

## Ace3

Ace3 is distributed under a BSD-style licence permitting use, modification and
redistribution with attribution. Full text and source:
https://www.wowace.com/projects/ace3

## Game assets

Spell icons and other textures the addon shows from the game (the icon of the
buff on the prompt, for example) are Blizzard Entertainment's, used from the
client's own files through the public addon API. None are redistributed with
this package.

The Manners logo, `Textures\Manners64.tga`, is this project's own: it is drawn
by `tools/make-icon.py` and shipped under the addon's MIT licence. It is the
icon in the addon list and on the minimap button. The rest of `Textures\` is
this project's own too, drawn by its own scripts and shipped under the same
licence: the prompt's light (`Glow.tga`, `GlowRound.tga`, `Ring.tga`, `RingSq.tga`,
`Rule.tga`, `Glint.tga`, `Shock.tga`, `Crack.tga`, `tools/make-glow.py`), the
built-in looks' material (`GlassPane.tga`, `GlassLight.tga`, `IconBezel.tga`,
`IconBezelRound.tga`, `TooltipRim.tga`, `tools/make_panel_textures.py`)
the art of the Arcane, Luxe, Toast, Ribbon, Letter, Leather and Forge looks
(`Textures\Arcane`, `Luxe`, `Toast`, `Ribbon`, `Letter`, `Leather` and `Forge`,
`tools/make_arcane_textures.py`, `make_luxe_textures.py`,
`make_toast_textures.py`, `make_ribbon_textures.py`, `make_letter_textures.py`,
`make_leather_textures.py` and `make_forge_textures.py`), and the pictures on the
look cards (`Textures\Previews`, `tools/make_look_previews.py`).
