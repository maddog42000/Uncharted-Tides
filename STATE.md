# Repository State — Uncharted Tides

## Current milestone

Unified v1.0.0 baseline on `main`, fast-forwarded from user-tested Stage 8 commit `0296d7a` (branch `feature/stage8-release-polish`). The current follow-up fixes Open Sea sea-event choice rendering, improves chart-first mobile navigation and touch inspection, and rebuilds the Home Port presentation with user-provided harbor art, live ship/voyage hero cards, blue-and-gold frames, and a shared tab panel. The user tested the v1.0.0 Stage 8 build on an Android phone in Godot and reported it working cleanly; these follow-up changes still need device verification. Android APK builds remain manual-only (`workflow_dispatch`); no APK build was triggered.

## Scenes

- `scenes/main_menu.tscn` — Main Menu, persisted Settings, Captain selection, Journal, first-voyage briefing, replay action, and two-step save reset.
- `scenes/home_port.tscn` — reusable, scrollable Bank, Shipyard, Market, Chart Table, Bounty Board, and Crew Roster panels; large primary navigation, persistent resource badges, a user-art harbor banner, live ship/voyage summary cards, and custom drawn harbor backdrop.
- `scenes/open_sea.tscn` — Chart-first responsive landscape view, tier-scaled cells, movement/exploration, enemy targeting, field repairs, emergency rations, boss encounters, tactical badges/event feed, long-press tile details, supplied local item/ship thumbnails, and extraction.
- `scenes/main_debug.tscn` — legacy development harness.

## Autoloads (`project.godot`)

- `GameClock` (`scripts/autoloads/GameClock.gd`) — fixed-step simulation and suspension pause.
- `PlayerData` (`scripts/autoloads/PlayerData.gd`) — inventory, progression, currencies, ship/equipment levels, crew, relics, bounties, voyage actions, and settlement.
- `SaveManager` (`scripts/autoloads/SaveManager.gd`) — persistent save/recovery, state-change writes, and checked reset of the live save and recovery files.
- `AssetManager` (`scripts/autoloads/AssetManager.gd`) — public asset mapping, cache, and bundled fallbacks.
- `SettingsManager` (`scripts/autoloads/SettingsManager.gd`) — persisted accessibility, audio, and briefing preferences in `user://settings.cfg`, separate from save data.
- `AudioCue` (`scripts/autoloads/AudioCue.gd`) — synthesizes lightweight mono WAV samples in memory and plays six gameplay cues on the SFX bus.

## Core data and features

- Save schema version 6; `PlayerData.deserialize()` fills legacy Stage 1–7 defaults, clamps progression and quantities, validates ships, captain perks, skills, crew, relics, milestones, bounties, and inventory IDs. `VoyageState.from_dict()` preserves valid legacy fields while validating chart positions, cargo, hazards, sites, enemies, events, crew, and relics. Legacy reef-position saves remain supported.
- Reset requires an explicit Settings action followed by a separate confirmation. `SaveManager.wipe_save()` removes `save_data.json`, `.tmp`, and `.bak`, then resets PlayerData and GameClock; device display/audio/onboarding preferences are intentionally untouched. Removal failures are reported without resetting in-memory progress.
- A new profile sees the dismissible Captain's Briefing once; profiles with voyage history are not interrupted. It explains highlighted movement, provisions and field repairs, island/wreck action ticks, and extraction payout; Settings can replay it at any time.
- All Main Menu modals are constrained to the landscape viewport and put their content in a vertical `ScrollContainer`. Labels wrap; close, cancel, and confirmation buttons retain touch-sized minimum heights.
- Brigantine requires Sailing 20, 3,000 Gold, 20 Oak Planks and 10 Iron Bars; Galleon requires Sailing 40, 18,000 Gold, 40 Mahogany Planks and 20 Mithril Bars; Man-o'-War requires Sailing 60, 75,000 Gold, 80 Magic Planks and 40 Runite Bars. Tier 2–4 voyage Sailing gates match 20/40/60 and still require the corresponding ship class.
- Every successful voyage action grants `400 × tier²` Sailing XP; safe extraction grants an additional `1,200 × tier`. Tier 1–4 island/wreck yields are 10 Oak Planks/5 Iron Bars, 12 Mahogany Planks/6 Mithril Bars, 16 Magic Planks/8 Runite Bars, and 20 Magic Planks/10 Runite Bars, respectively.
- Guaranteed extraction Gold covers full provision market value plus the existing 25% profit margin. Per-tier site material values and the Sailing/ship gates are included in the mechanics smoke checks. Bounties, crew rewards, and Fleet Prestige continue the long-term economy loop.
- Stage 3–7 features remain: open-sea hazards and exploration, safe extraction, combat and bosses, craftable upgrades, Harbor Bounties, audio cues, Crew Roster, maritime events, Sailing Mastery, and Fleet Prestige.
- `.github/workflows/android-build.yml` has only the `workflow_dispatch` trigger. Do not run an APK compilation workflow for Stage 8.
- `scripts/tests/stage2_*_smoke.gd` contain the contract, mechanics/progression, and UI smoke suites (legacy filenames retained).

## Completed milestones

- Stage 1: foundational data contracts and save/economy systems.
- Stage 2: Main Menu, Home Port, Bank, Shipyard, Market, and Chart Table flows.
- Stage 3: Open Sea loop, procedural hazards and exploration, safe extraction, Settings, Captain perks, and Journal.
- Stage 4: tier-scaled charts, pirate combat/salvage, and craftable ship equipment.
- Stage 5: field repairs, emergency rations, Tier 3–4 bosses and collectible passive Captain Relics, and extraction-profit checks.
- Stage 6: persistent Harbor Bounties, procedural audio and saved volume sliders, tactical HUD/event feed, and manual-only Android workflow.
- Stage 7: hireable crew, maritime events, Sailing mastery, Fleet Prestige, and touch polish.
- Stage 8: first-voyage onboarding/replay, confirmed save reset, Stage 1–7 migration hardening, landscape-responsive scrollable modals, and progression/economy balance pass.
- Open Sea UI follow-up: fixed explicitly typed sea-event choices; enlarged the centered chart to fit the viewport; added a scrollable voyage-information overlay and touch-and-hold risk/reward descriptions. Loot, site, and ship inspection panels use supplied local JPEGs where a fitting image exists; hazard tiles keep symbolic markers because no reef/mine/obstacle artwork is included.
- Home Port UI follow-up: established a consistent nautical blue-and-gold frame system, four large primary tab targets plus two secondary boards, persistent core resource counts, a current-ship status card, a live chart/profit summary with a Plan Voyage shortcut, a scenic crop from the user-provided harbor concept, a custom vector-drawn harbor scene, and a cropped Captain portrait. Original reference screenshots, notes, asset manifest, and design PDF are archived under `docs/ui-references/`.

## Final verification and release

Stage 8 final verification passed on commit `0296d7a`: Godot 4.7.2 headless editor parse plus the contract, mechanics, and UI smoke suites. The current Home Port/Open Sea follow-up also passed the Godot 4.7.2 editor import/parse and all three smoke suites; a 1280×720 rendered Home Port preview was inspected. User-reported Android phone testing covers Stage 8 only, so the follow-up still needs device verification. Keep the Android workflow manual-only; no APK compilation has been triggered.
