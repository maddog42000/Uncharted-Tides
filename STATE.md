# Repository State — Uncharted Tides

## Current milestone

Stage 4 implementation branch: `feature/stage4-combat-and-progression`. The baseline includes the merged and device-tested Stage 3 core loop (`b93f238`). Stage 4 adds tier-scaled procedural charts, pirate combat, cannon ammunition and salvage, and craftable ship equipment. Android verification of Stage 4 is pending.

## Scenes

- `scenes/main_menu.tscn` — Main Menu, persisted Settings, Captain selection, and Journal.
- `scenes/home_port.tscn` — Bank, Shipyard, Market, Chart Table, equipment crafting, and voyage selection.
- `scenes/open_sea.tscn` — adaptive grid, movement/exploration, enemy targeting and cannon combat, extraction.
- `scenes/main_debug.tscn` — legacy development harness.

## Autoloads (`project.godot`)

- `PlayerData` (`scripts/autoloads/PlayerData.gd`) — inventory, progression, currencies, ship/equipment levels, voyage actions and settlement.
- `SaveManager` (`scripts/autoloads/SaveManager.gd`) — persistent save/recovery and state-change writes.
- `SettingsManager` (`scripts/autoloads/SettingsManager.gd`) — persisted accessibility settings.
- `GameClock` (`scripts/autoloads/GameClock.gd`) — fixed-step simulation and suspension pause.
- `AssetManager` (`scripts/autoloads/AssetManager.gd`) — public asset mapping, cache, and bundled fallbacks.

## Core data

- `data/mvp_constants.gd` centralizes ships, items, provision bundles, tier gates, chart sizes, enemy balancing, and equipment recipes.
- `data/voyage_state.gd` owns seeded chart generation, movement, hazards/sites, enemies, combat, and voyage serialization.
- `scripts/tests/stage2_*_smoke.gd` are the contract, mechanics, and UI headless smoke suites (names retained from earlier stages).

## Completed milestones

- Stage 1: foundational data contracts and save/economy systems.
- Stage 2: Main Menu, Home Port, Bank, Shipyard, Market, and Chart Table flows.
- Stage 3: Open Sea loop, procedural hazards and exploration, safe extraction, settings, Captain perks, and Journal.
- Stage 4: implemented on this branch; headless Godot 4.7.2 parse plus contract, mechanics, and UI smoke suites pass. Android-device verification remains pending.
