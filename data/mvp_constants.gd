extends RefCounted
class_name MVPConstants

const TICK_DURATION: float = 0.6
# Deliberately discard unusually long frame time; this is a simulation clock, not wall time.
const MAX_FRAME_DELTA: float = 0.25
const MAX_BACKPACK_SLOTS: int = 28
const MAX_SKILL_LEVEL: int = 99
const SKILLS: Array[String] = [
	"Sailing", "Combat", "Mining", "Woodcutting",
	"Fishing", "Cooking", "Artisan", "Subterfuge"
]

# Item IDs are singular snake_case throughout inventory, bank, shop, and upgrade data.
const ITEMS: Dictionary = {
	"copper_ore": {"name": "Copper Ore", "category": "material"},
	"iron_bar": {"name": "Iron Bar", "category": "material"},
	"mithril_bar": {"name": "Mithril Bar", "category": "material"},
	"runite_bar": {"name": "Runite Bar", "category": "material"},
	"oak_plank": {"name": "Oak Plank", "category": "material"},
	"mahogany_plank": {"name": "Mahogany Plank", "category": "material"},
	"magic_plank": {"name": "Magic Plank", "category": "material"},
	"repair_plank": {"name": "Repair Plank", "category": "provision"},
	"cannonball": {"name": "Cannonball", "category": "provision"},
	"raw_sea_bass": {"name": "Raw Sea Bass", "category": "provision"},
	"gold_coin": {"name": "Gold Coin", "category": "currency"},
	"sea_serpent_scale": {"name": "Sea Serpent Scale", "category": "relic"},
	"dreadnought_insignia": {"name": "Dreadnought Insignia", "category": "relic"},
	"doubloon": {"name": "Doubloon", "category": "currency"}
}

const SHIPS: Dictionary = {
	"wooden_sloop": {
		"name": "Wooden Sloop", "req_sailing": 1, "max_hp": 100,
		"cargo_slots": 8, "cannons_per_side": 1, "movement_range": 1, "cost_gold": 0,
		"cost_materials": {}, "previous_ship_id": ""
	},
	"oak_brigantine": {
		"name": "Oak Brigantine", "req_sailing": 30, "max_hp": 250,
		"cargo_slots": 16, "cannons_per_side": 2, "movement_range": 2, "cost_gold": 5000,
		"cost_materials": {"oak_plank": 40, "iron_bar": 20}, "previous_ship_id": "wooden_sloop"
	},
	"mahogany_galleon": {
		"name": "Mahogany Galleon", "req_sailing": 60, "max_hp": 500,
		"cargo_slots": 28, "cannons_per_side": 4, "movement_range": 3, "cost_gold": 35000,
		"cost_materials": {"mahogany_plank": 80, "mithril_bar": 40}, "previous_ship_id": "oak_brigantine"
	},
	"dragonwood_man_owar": {
		"name": "Dragonwood Man-o'-War", "req_sailing": 85, "max_hp": 900,
		"cargo_slots": 40, "cannons_per_side": 6, "movement_range": 4, "cost_gold": 150000,
		"cost_materials": {"magic_plank": 120, "runite_bar": 60}, "previous_ship_id": "mahogany_galleon"
	}
}

# Market stock is credited to the permanent bank; prices are Stage 2 balancing defaults.
const MARKET_ITEMS: Dictionary = {
	"repair_plank": {"price_gold": 50},
	"cannonball": {"price_gold": 10},
	"raw_sea_bass": {"price_gold": 8}
}

# Permanent Bank sales use fixed values; buying remains limited to MARKET_ITEMS.
const ITEM_SELL_PRICES: Dictionary = {
	"copper_ore": 12, "iron_bar": 40, "mithril_bar": 110, "runite_bar": 220,
	"oak_plank": 18, "mahogany_plank": 42, "magic_plank": 75,
	"repair_plank": 25, "cannonball": 5, "raw_sea_bass": 4
}

const VOYAGE_EXTRACTION_MARGIN: float = 0.25
const HAZARD_COUNTS_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4}
const HAZARD_DRIFT_EVERY_TURNS: Dictionary = {1: 5, 2: 4, 3: 3, 4: 2}
const CHART_SIZE_BY_TIER: Dictionary = {1: 10, 2: 12, 3: 14, 4: 16}
const ENEMY_COUNTS_BY_TIER: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4}
const ENEMY_HULL_BY_TIER: Dictionary = {1: 60, 2: 100, 3: 160, 4: 240}
const ENEMY_DAMAGE_BY_TIER: Dictionary = {1: 12, 2: 18, 3: 25, 4: 32}
const ENEMY_LOOT_BY_TIER: Dictionary = {1: 150, 2: 300, 3: 600, 4: 1000}
const BOSS_HULL_BY_TIER: Dictionary = {3: 420, 4: 650}
const BOSS_DAMAGE_BY_TIER: Dictionary = {3: 28, 4: 38}
const BOSS_LOOT_BY_TIER: Dictionary = {3: 2500, 4: 5000}
const FIELD_REPAIR_HP: int = 40
const RATION_BURST_TURNS: int = 1
const BOUNTY_VOYAGES_PER_CYCLE: int = 3
const BOUNTY_TEMPLATES: Array[Dictionary] = [
	{"id": "fleet_hunt", "kind": "defeat_enemies", "title": "Fleet Hunt", "description": "Defeat 2 enemy vessels across your voyages.", "goal": 2, "gold": 250, "doubloons": 1, "item": "iron_bar", "quantity": 1},
	{"id": "site_survey", "kind": "scavenge_site", "title": "Wreck & Island Survey", "description": "Finish scavenging 1 island or shipwreck site.", "goal": 1, "gold": 300, "doubloons": 1, "item": "mahogany_plank", "quantity": 1},
	{"id": "tier_extraction", "kind": "extract_tier", "title": "Charted Extraction", "description": "Safely extract from the assigned voyage tier.", "goal": 1, "gold": 450, "doubloons": 2, "item": "mithril_bar", "quantity": 1}
]
const TIER_PROVISION_COSTS: Dictionary = {1: 224, 2: 440, 3: 664, 4: 1096}
const TIER_BASE_GUARANTEE: Dictionary = {1: 280, 2: 550, 3: 830, 4: 1370}
const COMBAT_RANGE: int = 3
const CANNON_BASE_DAMAGE: int = 25
const EQUIPMENT_MAX_LEVEL: int = 3
const EQUIPMENT: Dictionary = {
	"cannons": {"name": "Broadside Cannons", "item": "iron_bar", "qty": [4, 8, 12], "plank": "oak_plank", "plank_qty": [4, 8, 12], "gold": [500, 1500, 4000], "doubloons": [0, 1, 2]},
	"sails": {"name": "Reinforced Sails", "item": "mahogany_plank", "qty": [4, 8, 12], "plank": "oak_plank", "plank_qty": [6, 12, 18], "gold": [500, 1500, 4000], "doubloons": [0, 1, 2]},
	"hull": {"name": "Hull Reinforcement", "item": "copper_ore", "qty": [8, 16, 24], "plank": "mahogany_plank", "plank_qty": [4, 8, 12], "gold": [500, 1500, 4000], "doubloons": [0, 1, 2]}
}
const SITE_WORK_TICKS: Dictionary = {"island": 2, "shipwreck": 3}

const CREW_SPECIALISTS: Dictionary = {
	"master_gunner": {"name":"Master Gunner", "gold":2500, "doubloons":2, "bonus":"+6 cannon damage"},
	"quartermaster": {"name":"Quartermaster", "gold":2200, "doubloons":2, "bonus":"+1 Copper Ore salvage"},
	"bosun": {"name":"Bosun", "gold":2000, "doubloons":1, "bonus":"+15 hull repair"}
}
const MAX_ACTIVE_CREW: int = 2
const SAILING_MASTERY_MILESTONES: Array[Dictionary] = [{"level":10,"reward":250},{"level":25,"reward":750},{"level":50,"reward":2000},{"level":75,"reward":5000},{"level":99,"reward":12000}]
const PRESTIGE_BASE_GOLD: int = 25000
const PRESTIGE_BASE_DOUBLOONS: int = 10
const SEA_EVENT_COUNTS_BY_TIER: Dictionary = {1:2,2:3,3:4,4:5}
const FOG_STEALTH_ACTIONS_BY_TIER: Dictionary = {1:2,2:3,3:3,4:4}

# Voyage provisions are paid from the permanent bank when a voyage launches.
# Quantities are intentionally modest, increasing by tier; rebalance through playtesting.
const VOYAGE_PROVISIONS: Dictionary = {
	1: {"repair_plank": 2, "cannonball": 10, "raw_sea_bass": 3},
	2: {"repair_plank": 4, "cannonball": 20, "raw_sea_bass": 5},
	3: {"repair_plank": 6, "cannonball": 30, "raw_sea_bass": 8},
	4: {"repair_plank": 10, "cannonball": 50, "raw_sea_bass": 12}
}

const VOYAGE_TIER_REQUIREMENTS: Dictionary = {
	1: {"req_sailing": 1, "ship_tier": 1},
	2: {"req_sailing": 25, "ship_tier": 2},
	3: {"req_sailing": 50, "ship_tier": 3},
	4: {"req_sailing": 75, "ship_tier": 4}
}
