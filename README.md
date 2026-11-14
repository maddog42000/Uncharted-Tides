# Uncharted Tides — Stage 4 Naval Combat & Progression

A Godot 4.7.2 mobile-landscape project containing the foundation systems, Main Menu, four-tab Home Port, and playable Open Sea loop. Stage 4 extends the Stage 3 playable loop with cannon encounters, ship equipment progression, and larger tier-scaled procedural charts. Stage 4 Android-device verification remains pending.

## Open and run

Open the folder containing `project.godot` in Godot 4.7.2 or the Android Godot editor, let imports finish, and press Play. Startup is `scenes/main_menu.tscn`. The viewport and orientation are landscape; the project uses the Compatibility renderer (`gl_compatibility`).

The former QA harness remains available at `scenes/main_debug.tscn`; run it as the current scene to inspect the base clock and save/data actions.

## Implemented flows

- The Main Menu uses the supplied artwork and transparent hitboxes for **Settings**, **Select Character**, **Journal**, **Navigate**, and **Start Voyage**. The embedded bottom strip is cropped away; no “Begin Your Odyssey” control exists.
- **Settings** persist Text Size (Small, Standard, Large) and Reduced Motion on the device. Text sizing applies throughout the menu, Home Port, and Open Sea. Reduced Motion skips decorative scene fades.
- **Select Character** persists one Captain background, changeable while in port: Merchant earns 10% additional Gold on successful extraction; Navigator gains one movement tile per action; Shipwright reduces hazard hull damage by 20%. Background changes are locked during an active voyage.
- **Captain's Journal** tracks lifetime voyages started, successful extractions, Gold earned, and cargo brought home. The counters survive save/reload.
- Main Menu ↔ Home Port transitions use the bundled Loading Screen fallback. Home Port includes Bank, Shipyard, Market, and Chart Table tabs. The Shipyard presents tier comparisons, costs, requirements, and the selected Captain perk. Bank supports partial deposits and atomic withdrawals; Market supports purchases and sales; ship upgrades and market sales are locked at sea.
- Chart Table provisions Tier 1–4 voyages subject to both Sailing and ship-class gates. Charts expand from 10×10 through 16×16, with more dangerous hazards, larger enemy fleets, and increased rewards at higher tiers. Successful extraction banks all cargo and awards Gold equal to the provision-cost baseline plus a 25% margin, with Merchant's bonus applied once. A sink loses unbanked cargo but preserves the permanent ship tier.

## Open Sea mechanics

Voyages use seeded `Vector2i` charts sized 10×10, 12×12, 14×14, and 16×16 for Tiers 1–4 respectively. Movement range follows the ship class (Sloop 1, Brigantine 2, Galleon 3, Man-o'-War 4 Manhattan tiles) plus the Navigator perk. All reachable valid destinations are highlighted before a move; wind is informational and never restricts course.

Pirate sloops and galleons appear in growing fleets across tiers. Enable Target Enemy to highlight vessels within three tiles; firing consumes one provisioned cannonball, damages enemy hull, and surviving enemies retaliate. Defeated ships leave Gold salvage. Broadside cannon upgrades increase damage; sail upgrades increase movement range; hull upgrades increase maximum hull. Equipment recipes consume banked ores/bars/planks, Gold, and later Doubloons. Enemy state, ammo, and equipment levels persist.

Reefs, mines, and obstacles scale in number across Tiers 1–4 and drift toward the player periodically, with higher tiers increasing drift frequency. Hazards damage hull on collision; Shipwright reduces that damage. A salvage tile and interactive island and wreck sites provide cargo. Exploration consumes anchored action ticks (island 2, wreck 3), during which hazards continue to move. Extraction is at the far-corner harbor.

App suspension/focus loss pauses the simulation and saves voyage state. Movement and exploration are rejected while paused; the voyage resumes when the app regains focus.

## Data and persistence contracts

- **Inventory:** Backpack and ship cargo are slot-limited; bank quantities stack by singular `snake_case` IDs. `deposit(item_id, qty)` transfers up to the matching quantity. `withdraw(item_id, qty)` is all-or-nothing and leaves state unchanged if the bank lacks stock or backpack space.
- **Currencies and journal:** Gold, Doubloons, Captain background, and career counters serialize with player state. Successful extraction increments its reward and cargo totals once, irrespective of cargo stack count.
- **Ship upgrades:** Require the previous ship, Sailing level, Gold, and materials. All requirements are validated before deductions; upgrades are blocked while a voyage is active and signal state changes for saving.
- **Voyage provisions:** Sailing gates are Tier 1/2/3/4 = 1/25/50/75, and the matching ship tier is also required. Chart sizes scale 10/12/14/16. Enemy count, hull, damage, and Gold salvage scale by tier. Current provision defaults are Tier 1: 2 repair planks, 10 cannonballs, 3 raw sea bass; Tier 2: 4/20/5; Tier 3: 6/30/8; Tier 4: 10/50/12. Requirements are centralized in `data/mvp_constants.gd`.
- **Item IDs:** Canonical examples include `copper_ore`, `iron_bar`, `mithril_bar`, `oak_plank`, `mahogany_plank`, `magic_plank`, `runite_bar`, `repair_plank`, `cannonball`, and `raw_sea_bass`.
- **Save data:** Immediate writes use a verified temporary file and backup recovery. Startup checks the live save, backup, then valid temporary file. Active voyage position, hazard/site states, enemy hulls, ammunition, equipment effects, cargo, salvage status, extraction guarantee, Captain background, and career stats persist; legacy saves default to Merchant and zeroed journal counters. Android force-stop survival still depends on whether the OS allows the pause callback to finish.
- **Settings:** `SettingsManager` stores display and accessibility values in `user://settings.cfg`, separately from voyage/player saves.
- **Clock:** A 0.6-second fixed simulation step with physics-frame accumulation. Frame deltas are capped at 0.25 seconds and excess elapsed time is discarded. This is not a wall-clock timer.
- **Assets:** Numeric `.jpg` filenames map to public raw GitHub assets; Main Menu and Loading Screen JPEGs are bundled as offline fallbacks. Other icons are fetched/cached under `user://asset_cache`; uncached assets may be unavailable offline, while text controls remain usable.

## Key files

- `project.godot`: landscape settings and autoload registrations.
- `scripts/autoloads/PlayerData.gd`: player inventory, currencies, Captain choice, journal, market, upgrades, provisioning, and voyage settlement.
- `scripts/autoloads/SettingsManager.gd`: persisted display and accessibility preferences.
- `scripts/ui/main_menu.gd`: Main Menu controls, Settings, Captain selection, Journal, and transitions.
- `scripts/ui/home_port.gd`: Bank, Shipyard, Market, and Chart Table.
- `scripts/ui/open_sea.gd`, `data/voyage_state.gd`: adaptive chart, movement, hazards, exploration, cannon combat, and extraction.
- `scripts/autoloads/SaveManager.gd`: durable player/voyage save and recovery.
- `scripts/tests/`: contract, mechanics, and UI smoke suites.

## Automated checks

Run once per final verification pass from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script res://scripts/tests/stage2_contract_smoke.gd
godot --headless --path . --script res://scripts/tests/stage2_mechanics_smoke.gd
godot --headless --path . --script res://scripts/tests/stage2_ui_smoke.gd
```

The suites cover project data contracts, bank transactions, ship/equipment upgrades and tier gating; movement, tier chart/enemy scaling, combat, equipment effects and persistence, hazards, exploration, extraction ROI, Captain perks and settings; and Main Menu, Home Port, Open Sea, pause, salvage, extraction, sinking and banking flows. Headless checks do not replace Android touch, layout, network, or force-stop verification.
