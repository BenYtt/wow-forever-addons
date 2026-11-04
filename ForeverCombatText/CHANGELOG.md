# Changelog

## 0.13.0

- Replace the smaller/larger text buttons with a saved text-size slider from 12 to 60 (default 22). Existing saved text sizes are preserved.
- Add a font dropdown for Game default, Friz Quadrata, Arial Narrow, Morpheus, and Skurri. No font files are bundled; Game default continues to use the client's `STANDARD_TEXT_FONT`.
- Add a **Customize damage colors...** panel for per-school colors and the fallback damage color, with a reset-to-defaults button. Existing fallback damage color choices are preserved, and mixed-school hits blend the selected school colors.
- Reduce the critical grow pulse to 20% above its settled size and cap it at 144 UI units, so increasing the base slider does not increase the previous maximum critical peak.
- Fix large-text clipping by measuring each label and sizing its text region to fit, including room for the critical pulse.

## 0.12.0

- Outcome text (miss, dodge, parry, block, resist, evade, immune, absorb) is now localized. By default it follows the game language using the client's own combat-text strings, so a French client shows the French words instead of English. Previously these words were always English.
- New **Outcome text language** dropdown under the outcome text option: Game language (default), English, Deutsch, Français, Español, Português, Italiano, Nederlands, Czech, Svenska, Norsk (BiS). The choice applies immediately, survives `/reload`, and is restored to Game language by **Reset settings**. `/fct status` shows the active language.
- Russian, Korean and Chinese are covered by Game language on those clients but are not offered as overrides, because the font used on Western clients has no Cyrillic or CJK characters. Polish is not offered either: its letters such as ł, ę and ś show as squares in that font.
- The French wording comes from a player request, and the Norwegian wording was reviewed by a native speaker. The other override translations have not been reviewed by native speakers; corrections are welcome.
- Existing settings are kept; the new option defaults to Game language.
- Checked in-game on the beta client: the dropdown, live switching and the override languages display correctly.

## 0.11.0

- Add "Disable friendly nameplates in cities" (default off). While resting in capitals, towns, and inns, all friendly nameplates (players, NPCs, minions) are turned off; your previous settings are restored when you leave, when the option is turned off, on reset, or on logout.
- City detection uses the rest state because the client exposes no capital-city list, so taverns outside cities count as cities. Re-entering a zone or leaving combat re-applies the city state; a manual re-enable while hidden lasts until the next such event. Hiding all plates also engages the existing Blizzard-healing fallback while in cities.
- This feature is not yet verified in-game.

## 0.10.3

- Fixed the pulse scaling intended to be in 0.10.2

## 0.10.2

- Critical hit animation made more impactful: text size scales to double size with a brief grow‑shrink pulse before fading, matching the visual style of the default UI.

## 0.10.1

- Fix nameplate taint errors (`Frame:GetPoint ... Can't measure restricted regions` and secret-value comparisons in Blizzard health updates): the friendly-NPC styling no longer forces Blizzard's show-only-name layout (`UpdateAnchors`, hit-test areas, `SetShowOnlyName`) and no longer hooks its layout methods. Styling that is blocked while protected in combat still applies after combat.
- Fix white friendly/neutral NPC names: tinted with the client's own reaction colors (friendly green, neutral yellow) via `UnitSelectionColor`, reapplied after Blizzard repaints names and restored when the option is off. Bars, auras, and level indicators stay visible because hiding Blizzard plate regions from the addon re-taints the plate (behavior change from 0.10.0).
- Elite/rare icons now live on addon-owned frames instead of the Blizzard plate, so they no longer touch restricted regions.
- Experimental follow-up: hide bars, cast bars, auras, classification and level containers with Show/Hide only (no bar, layout, or hit-test calls) so styled plates read as names-only. Revert to tint-only if Blizzard measurement or secret-value errors return.
- Remove the separate NPC-styling toggle: friendly NPCs and minions now automatically follow Blizzard's **Only Show Names** setting. The old saved value is migrated away; turning off Blizzard's setting restores full plates.
- Add `/fct report`: a compact copy-paste session report with styling counts (styled, tinted, hidden, deferred, restored, skipped), current friendly-plate states and Shift-V toggle counts for players, NPCs and minions, plus combat totals. `/fct status` gains the same styling and toggle lines.
- Fix friendly-NPC plate tracking in `/fct report`: use Forever's exact `nameplateShowFriendlyNpcs` spelling (was `...NPCs`, which reads back as unknown). Player/minion visibility CVars are now auto-discovered from candidate spellings at login and the winning names are listed in the report, so further renames show up as data instead of `?`.
- Add `/fct watch [secs]`: logs CVar changes for 30 seconds so pressing a nameplate keybind reveals exactly which CVar (function) it flips, regardless of which key is bound. Toggle tracking already watches CVar outcomes, never keypresses.
- In-game finding: the friendly-nameplate keybind flips only `nameplateShowFriendlyPlayers` (minions follow the same setting). NPC visibility (`nameplateShowFriendlyNpcs`) has its own "Friendly NPC nameplates" Interface entry, counted the same way. The report falls back to the friends state for minions instead of showing `?`.
- Mirror the master Show Friendly toggle onto Friendly NPC plates: flipping it (keybind or options) now sets `nameplateShowFriendlyNpcs` to the same value, one-directional and only on real change, so no event loops. The NPC entry still works on its own between master flips. Minion tracking uses the true `nameplateShowFriendlyPlayerMinions` spelling found via `/fct watch`.
- Add "Show friendly NPC/minion nameplates" addon options (both default on). Effective visibility is master toggle AND its option: the master can only turn a category off, the option can only turn it off further. External Interface-option changes are adopted as the new preference while the master is on.
- Decouple plate styling from the master switch: "Enable floating text" now gates only the numbers. NPC/minion names-only styling and elite icons follow Blizzard's setting and their own toggles, so unticking the master no longer restores NPC health bars.
- Split floating-text control in two: "Enable floating combat text" (general switch for all floating numbers) and "Enable Forever Combat Text numbers" (addon numbers only). Plates-off damage/healing fallbacks now engage on the general switch alone, so turning off just the addon numbers falls back to Blizzard text instead of silence.
- Add "Show Blizzard healing when friendly plates are off" (default on): when players, NPC and minion plates are all off, native Blizzard healing numbers take over, mirroring the existing enemy-plates-off damage fallback. Restores the previous value when plates return, the option/addon is disabled, or on logout.
- This fix is not yet verified in-game.

## 0.10.0

- Expand addon healing to assistable friendly players, NPCs, pets, and healable minions with accessible nameplates. All healers' events remain combined. Exclude the player so Blizzard handles healing received by you.
- Add an opt-in extension of Blizzard's **Only Show Names** setting to accessible friendly NPC/minion nameplates, hiding bars, auras, classification and level indicators while retaining the healing anchor. Restore normal styling when disabled or plates are recycled. Protected styling changes defer until combat ends; forbidden plates are excluded.
- Add opt-in gold elite/boss, silver rare-elite, and rare-star icons on accessible enemy plates using Blizzard's installed artwork.
- Add a native outgoing-healing setting for dungeons and raids, enabled by default for new settings and Reset settings. Preserve existing saved choices and restore the previous `floatingCombatTextCombatHealing_v2` value on leaving instances, disabling the option/addon, reset, or logout; retry after combat. Incoming healing and shield settings are unchanged.
- Include the native healing setting in `/fct status` and extend the scrollable options panel with all three toggles. Name-only styling and elite icons are disabled by default.
- New nameplate styling, recipient event coverage, and native dungeon healing are not yet verified in-game. Enabling native healing does not establish the beta client's recipient/HoT/overheal coverage and may duplicate addon healing on accessible plates.

## 0.9.3

Verified in-game across solo, group, and target-only sessions with no Lua errors: event accounting exact, tracked nameplates returning to zero, and plate-reuse drops working. Pending-buffer recovery and secret-value paths saw no traffic during testing and remain unverified in live conditions. Healing in dungeons still needs testing; see Beta limitations in the README.

- Listen for `UNIT_COMBAT` while a reported nameplate is still pending and replay buffered hits once its plate attaches, so opening hits during the pending window are no longer lost. `/fct status` reports hits recovered from pending buffers. If the client rejects the early listener, the addon falls back to retrying until the plate attaches.
- Drop events with unreadable damage or healing amounts instead of comparing or displaying them, and validate healing amounts the same way as damage.
- Guard group-membership checks (`UnitInRaid`, `UnitInParty`) against unreadable answers.
- Re-check tracked nameplates when a removal arrives without a readable unit token, so stale plates and their listeners cannot linger and fire for recycled unit tokens.
- Refresh remembered target state on grace-held nameplates when the target changes, so target-only scope stays correct for killing blows.
- Clear pending nameplate listeners when labels are cleared or when zoning, instead of retrying stale unit tokens.
- Fall back to default offsets, colors, duration, and text size when saved settings are missing or corrupt, instead of erroring.
- Ignore `CVAR_UPDATE` payloads that are not readable strings.
- Report hits recovered from pending buffers in `/fct status`.

## 0.9.2

- Immediately listen for `UNIT_COMBAT` when a nameplate unit is reported, even if its visual plate frame is delayed or forbidden, buffering events until the plate attaches so opening hits and early ticks are not lost.
- Refine the current-target hostility fallback: check for friendly or group indicators (`UnitCanAssist`, `UnitIsFriend`, `UnitIsPlayer`, party/raid membership) before falling back to hostile, preventing damage taken by friendly targets from showing when hostility is hidden.
- Display "Absorb" outcome text for zero-damage wounds when outcome text is enabled, rather than silently dropping them.
- Include an "Absorb" sample in the nameplate preview.

## 0.9.1

- Show damage and outcome text on your current target when the client hides its hostility, instead of dropping it. This targets opening hits that were missed because hostility was secret at the start of combat and had never been readable for that nameplate. Trade-off: if you target a friendly unit whose hostility is hidden at that moment, its damage taken may be shown. Untargeted units still require readable hostility.
- Report hits shown through this target fallback in `/fct status`.

## 0.9.0

Feature-complete and usable, but not yet stable. Combat text is tied to nameplates, so hits outside a short window around a visible nameplate can still be missed; see Beta limitations in the README.

- Show all seven damage schools in the nameplate preview, alongside the critical and healing samples, so the school colors can be compared.
- Play the preview as a staggered burst over about a second, with a slight random horizontal offset per number, so it resembles real combat instead of every sample appearing at once on one spot.
- Scale the horizontal stagger of stacked numbers with the selected text size, so wider numbers no longer visually merge with their neighbours at large font sizes. At the default 22 the spacing is unchanged from 0.4.1.
- Keep numbers on screen when their nameplate disappears, matching the default game behaviour. A number that was on screen when a mob died, despawned, or left the area stays where it is and finishes rising and fading normally instead of being deleted. Its nameplate anchor is held until the number expires, so a newly added plate cannot pull it across the screen. Zone changes still clear everything.
- Skip wounds reported with a zero amount, rather than showing a bare `0`. These are absorbed or fully resisted hits, not named outcomes.
- Stop counting preview samples as combat text in `/fct status`. Previewing inflated the "numbers shown" figure, which made it useless for spotting genuinely missing hits.
- Report late nameplates in `/fct status`. A nameplate that is not yet available when the client reports it as added is the one window where an incoming hit can be missed, because no listener exists yet.
- Add an opt-in setting to show miss, dodge, parry, block, resist, evade and immune text on nameplates, in a neutral gray. Off by default, because these fire often and add a lot of visual noise. `UNIT_COMBAT` reports each of these as its own event name rather than as a zero-damage wound.
- Alternate the height of stacked numbers as well as their horizontal position, so two hits landing in the same instant stay readable instead of overlapping.
- Include a gray "Miss" sample in the nameplate preview, so the outcome text can be judged without enabling the option during combat.
- Always unregister a pooled nameplate listener before reusing it, so a recycled entry cannot keep firing events for a unit it no longer tracks.
- Drop a fading number when the client hands its nameplate frame to a different mob. Nameplate frames are pooled and reassigned, so a number could otherwise appear under an unrelated nameplate. Reuse is now detected when the new plate is added rather than by comparing unit tokens, which missed reuse when the new mob received the same `nameplateN` token.
- Show killing blows reported just after the nameplate is removed: a removed plate keeps listening for 0.6 seconds. The grace ends immediately if its unit token or plate frame is given to another mob, so the new mob's hits are not shown twice.
- Remember each nameplate's hostility, friendly-player state and target state while readable, and use those values when the live answer is secret at the start of combat or no longer valid after the mob dies. Previously such opening hits and killing blows were dropped.
- Retry nameplates that were not yet usable every frame for up to 3 seconds, instead of only on target change, so opening hits are not lost while a plate is pending.
- Report hits caught after plate removal, hits shown using remembered hostility, and numbers dropped early because their nameplate frame was reused in `/fct status`.
- Cancel an in-flight preview when labels are cleared, so queued samples cannot reappear afterwards.
- Confirm in-game that critical events are delivered and that healing appears on friendly player nameplates when nameplates are enabled, matching the damage path. The earlier unverified-coverage caveats are now verified and removed from the README.
- Read the options-panel version from the `.toc` metadata instead of a hardcoded string, so the displayed version can no longer drift from the released one.
- Retry nameplates that were reported as added before a usable plate was available, instead of dropping that unit for the rest of the session.
- Set the critical pulse text height only during the 0.3-second pulse window instead of on every frame, leaving the settled critical size untouched afterwards.
- Make the offset sliders move in whole UI units, matching the values they store.
- Remove the leftover `Healing.lua` from the experimental 2D healing stream. It was no longer listed in the `.toc` and had no effect.
- Make the label `duration` an editable setting with a slider, adjustable from 0.6 to 3 seconds and defaulting to 1.2, instead of a saved value with no way to reach it.
- Remove the README's per-version "Changes in" section; the changelog is the only version history.
- Exclude the `logo.svg` source artwork from the installable archive, where it had no effect.

## 0.4.1

- Set default starting positions to -30 UI units for both damage and healing; keep the existing upward movement.
- Add a separate saved nameplate damage-offset slider, independent of healing. Display offsets relative to a -30 UI-unit baseline: both default to 0, with a displayed range of -30 to 70.
- Clarify in the README that the nameplate healing-offset slider affects healing only, not damage.
- Preserve existing saved offsets; only their displayed values shift by +30. Upgrades from 0.4.0 introduce the new damage default because that version had no saved damage offset. New installations and Reset settings use the lower defaults.
- Emphasize readable critical damage/healing events with 50% larger text and a brief grow/shrink pulse. Unavailable or secret critical flags retain normal styling.
- Include a sample critical damage number in the nameplate preview.
- Reduce the addon icon to 256×256 pixels.

Critical-event coverage depends on the client's readable UNIT_COMBAT flags; the animation is inspired by Blizzard's UI, not an exact reproduction of its outgoing world-space text. Reliable live critical-event coverage has not been established.

## 0.4.0

- Display damage above all visible enemy nameplates, with optional target-only scope.
- Include opening-hit events without waiting for the enemy's combat flag.
- Color damage by school, with configurable fallback damage and healing colors.
- Suppress duplicate Blizzard outgoing damage text using the modern client setting.
- Optionally restore Blizzard damage text when enemy nameplates are disabled.
- Provide a clipped, scrollable addon settings page, preview, diagnostics, and reset.
- Lower nameplate healing text and add a configurable vertical offset.
- Remove the experimental 2D healing stream and its saved settings.
- Preserve Blizzard's healing text.

Known limitations: damage sources cannot be separated; periodic-event coverage and friendly nameplate healing depend on the Forever beta client. Reliable outgoing healing to other players has not been established.
