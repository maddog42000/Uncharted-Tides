# Repository State — Uncharted Tides

## Current milestone

Stage 7 branch: `feature/stage7-crew-events-and-release`, based on user-tested Stage 6 commit fd43437 merged to main. Adds hireable crew, maritime chart events, Sailing mastery, Fleet Prestige, and landscape touch polish. Android APK builds are manual-only (`workflow_dispatch`) during active development. Android device verification of this branch remains pending.

## Scenes

- `scenes/main_menu.tscn` — Main Menu, persisted Settings, Captain selection, and Journal with collected Captain Relics and their passive effects.
- `scenes/home_port.tscn` — Bank, Shipyard, Market, Chart Table, persistent Bounty Board, Crew Roster, equipment crafting, and voyage selection.
- `scenes/open_sea.tscn` — adaptive grid, movement/exploration, enemy targeting, field repairs, emergency rations, boss encounters, tactical status badges, recent event feed, and extraction.
- `scenes/main_debug.tscn` — legacy development harness.

## Autoloads (`project.godot`)

- `GameClock` (`scripts/autoloads/GameClock.gd`) — fixed-step simulation and suspension pause.
- `PlayerData` (`scripts/autoloads/PlayerData.gd`) — inventory, progression, currencies, ship/equipment levels, persistent relics, voyage actions, and settlement.
- `SaveManager` (`scripts/autoloads/SaveManager.gd`) — persistent save/recovery and state-change writes.
- `AssetManager` (`scripts/autoloads/AssetManager.gd`) — public asset mapping, cache, and bundled fallbacks.
- `SettingsManager` (`scripts/autoloads/SettingsManager.gd`) — persisted accessibility preferences and Master/SFX volume levels.
- `AudioCue` (`scripts/autoloads/AudioCue.gd`) — synthesizes lightweight mono WAV samples in memory and plays six gameplay cues on the SFX bus; no external audio files are required.

## Core data and features

- `data/mvp_constants.gd` centralizes ships, items, provision bundles, tier gates, chart sizes, enemy and boss scaling, field-action values, extraction margin, and equipment recipes.
- `data/voyage_state.gd` owns seeded chart generation, movement, hazards/sites, enemies, combat, carried repair/ration stocks, boss drops, temporary movement bursts, and voyage serialization.
- Repair planks restore up to 40 hull HP each. An emergency ration grants +1 movement tile on the next move. Both are consumed from voyage provisions; using either costs an action, so enemies and hazards continue acting.
- Tier 3 spawns a 420-HP Sea Monster (28 damage) that drops a Sea Serpent Scale; Tier 4 spawns a 650-HP Dreadnought Captain (38 damage) that drops a Dreadnought Insignia. The Sea Serpent Scale grants +25 maximum hull. The Insignia grants +5 cannon damage and +10% extraction Gold. Unique relics persist in player saves, are tracked in the Journal, and are banked on extraction.
- Harbor Bounties offer three active contracts per cycle: defeat two enemy vessels, finish a site scavenging action, and safely extract from the cycle's assigned tier. Each pays bonus Gold, Doubloons, and a banked material. Progress, completion, and cycle state persist; cycles rotate after three launched voyages.
- Runtime cues cover cannon fire, hull impacts, repairs, emergency rations, salvage/relic pickups, and safe extraction. Master and SFX sliders update the audio buses immediately and persist in `user://settings.cfg`.
- The Open Sea HUD shows the selected Captain perk, owned/equipped Relics, remaining actions/ammunition/repairs/rations, and the six most recent voyage event messages including damage, loot, and Relic triggers.
- The extraction guarantee is based on the full market value of every consumed launch provision (repair planks, cannonballs, and food), plus the established 25% profit margin. Tier 1–4 safe extraction retains that invariant even when field supplies are used; optional combat salvage/relics add rewards rather than being required for the guarantee.
- `.github/workflows/android-build.yml` runs only through `workflow_dispatch`; when manually invoked it installs Godot 4.7.2, export templates, Java 17 and Android SDK components, then exports `build/UnchartedTides-debug.apk` as an artifact. No signing secrets or release keystore are required.
- `export_presets.cfg` defines the Android debug-test preset with package ID `com.maddog.unchartedtides` and arm64-v8a ABI.
- `scripts/tests/stage2_*_smoke.gd` are the contract, mechanics, and UI headless smoke suites (names retained from earlier stages).

- Stage 7 adds three hireable specialists with up to two active crew, chart events (distress, tailwind, fog), saved event/crew state, Sailing milestone configuration, and repeatable prestige costs/bonuses. Android workflow remains manual-only.


## Completed milestones

- Stage 1: foundational data contracts and save/economy systems.
- Stage 2: Main Menu, Home Port, Bank, Shipyard, Market, and Chart Table flows.
- Stage 3: Open Sea loop, procedural hazards and exploration, safe extraction, settings, Captain perks, and Journal.
- Stage 4: Tier-scaled charts, pirate combat and salvage, and craftable ship equipment.
- Stage 5: field repairs, emergency rations, Tier 3–4 bosses and collectible passive Captain Relics, and tier-by-tier extraction-profit checks.
- Stage 6: persistent three-contract Harbor Bounty cycles, procedural audio and saved volume sliders, and an in-voyage tactical HUD/event feed; Android APK workflow made manual-only.

## Final validation

Run the Godot 4.7.2 project parse and the contract, mechanics, and UI smoke suites once as a single final verification batch after Stage 7 changes are complete. Passing headless checks does not replace on-device layout, touch, install, or lifecycle testing.
