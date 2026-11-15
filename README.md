# Uncharted Tides — v1.0.0

A Godot 4.7.2 mobile-landscape project containing the Main Menu, Home Port, and playable Tier 1–4 Open Sea loop. The v1.0.0 baseline includes first-voyage onboarding, safe save management and migration, responsive modal layouts, and the Stage 8 progression/economy pass. The user-tested Stage 8 build was verified on an Android phone in Godot. The Android APK workflow remains manual-only, and no APK compilation was triggered for this release baseline.

## Open and run

Open the folder containing `project.godot` in Godot 4.7.2 or the Android Godot editor, let imports finish, and press Play. Startup is `scenes/main_menu.tscn`. The viewport and orientation are landscape; the project uses the Compatibility renderer (`gl_compatibility`).

The former QA harness remains available at `scenes/main_debug.tscn`; run it as the current scene to inspect the base clock and save/data actions.

## Implemented flows

- The Main Menu uses the supplied artwork and transparent hitboxes for **Settings**, **Select Character**, **Journal**, **Navigate**, and **Start Voyage**. The embedded bottom strip is cropped away; no “Begin Your Odyssey” control exists.
- **Settings** persist Text Size (Small, Standard, Large), Reduced Motion, Master/SFX volumes, and whether the Captain's Briefing has been dismissed. Text sizing applies throughout the UI; Reduced Motion skips decorative scene fades.
- New profiles see a dismissible **Captain's Briefing** covering highlighted movement, provisions and repairs, island/wreck ticks, and extraction profit. Returning profiles are not interrupted; Settings can replay the briefing.
- **Reset Save Data** uses a separate confirmation step, deletes the live save and recovery copies, and preserves display, audio, and briefing preferences.
- **Select Character** persists one Captain background, changeable while in port: Merchant earns 10% additional Gold on successful extraction; Navigator gains one movement tile per action; Shipwright reduces hazard hull damage by 20%. Background changes are locked during an active voyage.
- **Captain's Journal** tracks lifetime voyages started, successful extractions, Gold earned, and cargo brought home. The counters survive save/reload.
- **Captain Relics** recovered from Tier 3–4 bosses appear in the Journal and persist across saves. The Sea Serpent Scale adds 25 maximum hull; the Dreadnought Insignia adds 5 cannon damage and 10% extraction Gold.
- Main Menu ↔ Home Port transitions use the bundled Loading Screen fallback. Home Port uses a reusable scrollable content panel, the user-provided harbor-art crop as a wide hero banner, a live current-ship card, and a tier/map/profit summary with a working Plan Voyage shortcut. Blue-and-gold framed controls, a locally cropped Captain portrait, persistent resource badges, and four large primary tabs (Bank, Shipyard, Market, Chart Table) give the port the supplied visual direction; Bounty Board and Crew Roster remain secondary tabs. The Shipyard presents tier comparisons, costs, requirements, and the selected Captain perk. Bank supports partial deposits and atomic withdrawals; Market supports purchases and sales; ship upgrades and market sales are locked at sea.
- Chart Table provisions Tier 1–4 voyages subject to both Sailing and ship-class gates. Charts expand from 10×10 through 16×16, with more dangerous hazards, larger enemy fleets, and increased rewards at higher tiers. Successful extraction banks all cargo and awards Gold equal to the provision-cost baseline plus a 25% margin, with Merchant's bonus applied once. A sink loses unbanked cargo but preserves the permanent ship tier.

## Open Sea mechanics

Voyages use seeded `Vector2i` charts sized 10×10, 12×12, 14×14, and 16×16 for Tiers 1–4 respectively. Movement range follows the ship class (Sloop 1, Brigantine 2, Galleon 3, Man-o'-War 4 Manhattan tiles) plus the Navigator perk. All reachable valid destinations are highlighted before a move; wind is informational and never restricts course.

The Open Sea uses a chart-first landscape layout; tile size scales to the available phone viewport and voyage tier. Touch and hold any tile briefly to see its contents, hazard damage, enemy hull/reward, site action cost and estimated material value, or extraction payout. The inspector reuses the repository's supplied Copper Ore, material, and ship JPEGs. Reef, mine, and obstacle art is not present in the supplied assets, so those remain clearly color-coded symbol markers with written risk details rather than misleading substitute images. Voyage Info opens the scrollable status, cargo, risk, and event log.

Pirate sloops and galleons appear in growing fleets across tiers. Tier 3 adds a Sea Monster (420 hull, 28 return-fire damage); Tier 4 adds a Dreadnought Captain (650 hull, 38 return-fire damage). Bosses drop their unique relic and high-value Gold salvage. Enable Target Enemy to highlight vessels within three tiles; firing consumes one provisioned cannonball, damages enemy hull, and surviving enemies retaliate. Defeated ships leave Gold salvage. Broadside cannon upgrades increase damage; sail upgrades increase movement range; hull upgrades increase maximum hull. Equipment recipes consume banked ores/bars/planks, Gold, and later Doubloons. Enemy state, ammo, equipment levels, relics, and in-voyage supply stocks persist.

Repair planks carried from launch can be spent at sea to restore up to 40 hull HP each. Raw Sea Bass provisions become emergency rations; each ration costs an action and gives +1 tile to the next movement. Both actions consume a turn, so nearby enemies and drifting hazards can still retaliate. The Open Sea controls show remaining supply counts and disable actions that cannot be used.

Reefs, mines, and obstacles scale in number across Tiers 1–4 and drift toward the player periodically, with higher tiers increasing drift frequency. Hazards damage hull on collision; Shipwright reduces that damage. A salvage tile and interactive island and wreck sites provide cargo. Exploration consumes anchored action ticks (island 2, wreck 3), during which hazards continue to move. Extraction is at the far-corner harbor.

App suspension/focus loss pauses the simulation and saves voyage state. Movement and exploration are rejected while paused; the voyage resumes when the app regains focus.

## Data and persistence contracts

- **Inventory:** Backpack and ship cargo are slot-limited; bank quantities stack by singular `snake_case` IDs. `deposit(item_id, qty)` transfers up to the matching quantity. `withdraw(item_id, qty)` is all-or-nothing and leaves state unchanged if the bank lacks stock or backpack space.
- **Currencies and journal:** Gold, Doubloons, Captain background, and career counters serialize with player state. Successful extraction increments its reward and cargo totals once, irrespective of cargo stack count.
- **Ship upgrades:** Require the previous ship, Sailing level, Gold, and materials. All requirements are validated before deductions; upgrades are blocked while a voyage is active and signal state changes for saving.
- **Voyage provisions and profitability:** Sailing gates are Tier 1/2/3/4 = 1/20/40/60, and the matching ship tier is also required. Ship progression: Brigantine 20 Sailing/3,000 Gold/20 Oak Planks/10 Iron Bars; Galleon 40/18,000/40 Mahogany Planks/20 Mithril Bars; Man-o'-War 60/75,000/80 Magic Planks/40 Runite Bars. Current provision defaults are Tier 1: 2 repair planks, 10 cannonballs, 3 raw sea bass; Tier 2: 4/20/5; Tier 3: 6/30/8; Tier 4: 10/50/12. Each successful action grants `400 × tier²` Sailing XP and safe extraction grants another `1,200 × tier`. Extraction Gold remains the full provision-market cost plus 25%; exploration materials and bounty rewards are additional upside.
- Island and wreck exploration rewards scale by tier: Oak Planks/Iron Bars, Mahogany Planks/Mithril Bars, Magic Planks/Runite Bars, and increased Tier 4 quantities. Mechanics checks compare their configured sale value and each extraction guarantee with provision costs.
- **Item IDs:** Canonical examples include `copper_ore`, `iron_bar`, `mithril_bar`, `oak_plank`, `mahogany_plank`, `magic_plank`, `runite_bar`, `repair_plank`, `cannonball`, and `raw_sea_bass`.
- **Save data:** Immediate writes use a verified temporary file and backup recovery. Stage 1–7 fields are migrated and validated on load, including Crew, Relics, Bounties, Prestige, Journal, inventory, and active voyage data. Reset removes all save/recovery copies but never removes Settings. Android force-stop survival still depends on whether the OS allows the pause callback to finish.
- **Settings:** `SettingsManager` stores display, accessibility, audio, and onboarding values in `user://settings.cfg`, separately from voyage/player saves.
- **Clock:** A 0.6-second fixed simulation step with physics-frame accumulation. Frame deltas are capped at 0.25 seconds and excess elapsed time is discarded. This is not a wall-clock timer.
- **Assets:** Numeric `.jpg` filenames map to public raw GitHub assets; Main Menu and Loading Screen JPEGs are bundled as offline fallbacks. Other icons are fetched/cached under `user://asset_cache`; uncached assets may be unavailable offline, while text controls remain usable.

## Key files

- `project.godot`: landscape settings and autoload registrations.
- `scripts/autoloads/PlayerData.gd`: player inventory, currencies, Captain choice, journal, market, upgrades, provisioning, and voyage settlement.
- `scripts/autoloads/SettingsManager.gd`: persisted display and accessibility preferences.
- `scripts/ui/main_menu.gd`: Main Menu controls, Settings, Captain selection, Journal, and transitions.
- `scripts/ui/home_port.gd`, `scripts/ui/harbor_backdrop.gd`: shared Home Port tab framework, Bank, Shipyard, Market, Chart Table, Bounty Board, Crew Roster, and its original drawn harbor background.
- `scripts/ui/open_sea.gd`, `data/voyage_state.gd`: adaptive chart, movement, hazards, exploration, field supplies, boss combat, relic rewards, and extraction.
- `assets/ui/captain_portrait_reference.png` and `assets/ui/harbor_scene_strip.png`: small portrait and panoramic harbor-art crops derived from the user-provided Home Port concept. The unmodified supplied reference screenshots, implementation notes, asset manifest, and design PDF are preserved in `docs/ui-references/`.
- `export_presets.cfg` and `.github/workflows/android-build.yml`: arm64 Android debug export; the workflow is manual-only (`workflow_dispatch`) and must not be triggered during active development.
- `scripts/autoloads/SaveManager.gd`: durable player/voyage save and recovery.
- `scripts/tests/`: contract, mechanics, and UI smoke suites.

## Automated checks

Run once per final verification pass from the project root with Godot 4.7.2:

```sh
godot --headless --path . --script res://scripts/tests/stage2_contract_smoke.gd
godot --headless --path . --script res://scripts/tests/stage2_mechanics_smoke.gd
godot --headless --path . --script res://scripts/tests/stage2_ui_smoke.gd
```

The suites cover project data contracts, bank transactions, ship/equipment upgrades and tier gating, malformed/legacy migration and reset isolation; movement, tier chart/enemy/site scaling, combat, equipment effects and persistence, hazards, exploration, extraction ROI, Sailing XP pacing, Captain perks and Settings; and Main Menu, first-run briefing/replay, responsive modals, Home Port tab hierarchy, live ship/voyage hero, resource badges, reference-art presence and Plan Voyage shortcut, Open Sea, pause, salvage, extraction, sinking and banking flows. Headless checks do not replace Android touch, layout, network, or force-stop verification.
