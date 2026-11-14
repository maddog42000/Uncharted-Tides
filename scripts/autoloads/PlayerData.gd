extends Node

const Constants = preload("res://data/mvp_constants.gd")
const VoyageStateScript = preload("res://data/voyage_state.gd")

signal xp_gained(skill_name: String, amount: int, new_total: int)
signal level_up(skill_name: String, new_level: int)
signal inventory_updated
signal state_changed

var xp_for_level: Array[int] = [] # Indexed by level; indices 1..99 are valid.
var skill_xp: Dictionary = {}
var backpack: Array[Dictionary] = [] # One item per slot for the Stage 1 contract.
var bank: Dictionary = {} # item_id -> stacked quantity
var gold: int = 1000 # Stage 2 testing starting balance.
var doubloons: int = 0
var active_ship_id: String = "wooden_sloop"
var captain_background: String = "merchant"
var career_stats: Dictionary = {"voyages_started": 0, "extractions": 0, "gold_earned": 0, "cargo_salvaged": 0}
var equipment_levels: Dictionary = {"cannons": 0, "sails": 0, "hull": 0}
var captain_relics: Array[String] = []
var voyage: VoyageState = VoyageStateScript.new()

func _ready() -> void:
	_build_xp_table()
	reset_to_defaults()

func _build_xp_table() -> void:
	xp_for_level.resize(Constants.MAX_SKILL_LEVEL + 1)
	xp_for_level.fill(0)
	var points: float = 0.0
	for level in range(1, Constants.MAX_SKILL_LEVEL):
		points += floorf(float(level) + 300.0 * pow(2.0, float(level) / 7.0))
		xp_for_level[level + 1] = int(floorf(points / 4.0))

func reset_to_defaults() -> void:
	skill_xp.clear()
	for skill in Constants.SKILLS:
		skill_xp[skill] = 0
	backpack.clear()
	bank.clear()
	gold = 1000
	doubloons = 0
	active_ship_id = "wooden_sloop"
	captain_background = "merchant"
	career_stats = {"voyages_started": 0, "extractions": 0, "gold_earned": 0, "cargo_salvaged": 0}
	equipment_levels = {"cannons": 0, "sails": 0, "hull": 0}
	captain_relics.clear()
	voyage = VoyageStateScript.new()
	inventory_updated.emit()
	state_changed.emit()

func get_level(skill_name: String) -> int:
	var current_xp: int = int(skill_xp.get(skill_name, 0))
	for level in range(Constants.MAX_SKILL_LEVEL, 0, -1):
		if current_xp >= xp_for_level[level]:
			return level
	return 1

func select_captain_background(background_id: String) -> Dictionary:
	if voyage.is_active:
		return {"success": false, "message": "Captain background cannot be changed at sea."}
	if not ["merchant", "navigator", "shipwright"].has(background_id):
		return {"success": false, "message": "Unknown Captain background."}
	captain_background = background_id
	state_changed.emit()
	return {"success": true, "message": "Captain background set to %s." % background_id.capitalize()}

func add_xp(skill_name: String, amount: int) -> void:
	if not skill_xp.has(skill_name) or amount <= 0:
		return
	var old_level: int = get_level(skill_name)
	skill_xp[skill_name] = int(skill_xp[skill_name]) + amount
	var new_level: int = get_level(skill_name)
	xp_gained.emit(skill_name, amount, int(skill_xp[skill_name]))
	if new_level > old_level:
		level_up.emit(skill_name, new_level)
	state_changed.emit()

func add_to_backpack(item_id: String, qty: int = 1) -> int:
	if item_id.is_empty() or qty <= 0:
		return 0
	var added: int = mini(qty, Constants.MAX_BACKPACK_SLOTS - backpack.size())
	for _i in range(added):
		backpack.append({"item_id": item_id, "qty": 1})
	if added > 0:
		inventory_updated.emit()
		state_changed.emit()
	return added

# Deposit up to qty matching backpack units into the stacked bank. A smaller owned amount
# is deposited as a partial transfer; invalid IDs/qty or no matching items fail cleanly.
func deposit(item_id: String, qty: int) -> Dictionary:
	if item_id.is_empty() or qty <= 0:
		return _transaction_result(false, 0, "Item ID and quantity must be valid.")
	var available: int = 0
	for slot in backpack:
		if str(slot.get("item_id", "")) == item_id:
			available += maxi(1, int(slot.get("qty", 1)))
	if available == 0:
		return _transaction_result(false, 0, "No %s in backpack." % item_id)
	var transfer_qty: int = mini(qty, available)
	var remaining_to_remove: int = transfer_qty
	var new_backpack: Array[Dictionary] = []
	for slot in backpack:
		var slot_id: String = str(slot.get("item_id", ""))
		var slot_qty: int = maxi(1, int(slot.get("qty", 1)))
		if slot_id == item_id and remaining_to_remove > 0:
			var removed: int = mini(slot_qty, remaining_to_remove)
			remaining_to_remove -= removed
			slot_qty -= removed
			if slot_qty > 0:
				new_backpack.append({"item_id": slot_id, "qty": slot_qty})
		else:
			new_backpack.append({"item_id": slot_id, "qty": slot_qty})
	backpack = new_backpack
	bank[item_id] = int(bank.get(item_id, 0)) + transfer_qty
	inventory_updated.emit()
	state_changed.emit()
	return _transaction_result(true, transfer_qty, "Deposited %d %s." % [transfer_qty, item_id])

# Withdraw is atomic for the requested quantity: if stock is insufficient or all requested
# units cannot fit, no state is changed. Repeated calls support partial withdrawals.
func withdraw(item_id: String, qty: int) -> Dictionary:
	if item_id.is_empty() or qty <= 0:
		return _transaction_result(false, 0, "Item ID and quantity must be valid.")
	var available: int = int(bank.get(item_id, 0))
	if available < qty:
		return _transaction_result(false, 0, "Bank has only %d %s." % [available, item_id])
	var free_slots: int = Constants.MAX_BACKPACK_SLOTS - backpack.size()
	if qty > free_slots:
		return _transaction_result(false, 0, "Backpack has room for only %d more item(s)." % free_slots)
	bank[item_id] = available - qty
	if int(bank[item_id]) <= 0:
		bank.erase(item_id)
	for _i in range(qty):
		backpack.append({"item_id": item_id, "qty": 1})
	inventory_updated.emit()
	state_changed.emit()
	return _transaction_result(true, qty, "Withdrew %d %s." % [qty, item_id])

func _transaction_result(success: bool, quantity: int, message: String) -> Dictionary:
	return {"success": success, "quantity": quantity, "message": message}

func buy_market_item(item_id: String, qty: int = 1) -> Dictionary:
	var offer: Dictionary = Constants.MARKET_ITEMS.get(item_id, {})
	if offer.is_empty() or qty <= 0:
		return _transaction_result(false, 0, "Item is not sold at this Market.")
	var total_cost: int = int(offer.get("price_gold", 0)) * qty
	if gold < total_cost:
		return _transaction_result(false, 0, "Need %d more Gold." % (total_cost - gold))
	gold -= total_cost
	bank[item_id] = int(bank.get(item_id, 0)) + qty
	inventory_updated.emit()
	state_changed.emit()
	return _transaction_result(true, qty, "Bought %d %s for %d Gold." % [qty, item_id, total_cost])

func sell_market_item(item_id: String, qty: int = 1) -> Dictionary:
	if voyage.is_active:
		return _transaction_result(false, 0, "Return to a safe harbor before selling cargo.")
	var unit_price: int = int(Constants.ITEM_SELL_PRICES.get(item_id, 0))
	var available: int = int(bank.get(item_id, 0))
	if unit_price <= 0 or qty <= 0 or available <= 0:
		return _transaction_result(false, 0, "No eligible banked stock to sell.")
	var sold: int = mini(qty, available)
	bank[item_id] = available - sold
	if int(bank[item_id]) <= 0:
		bank.erase(item_id)
	var proceeds: int = sold * unit_price
	gold += proceeds
	career_stats["gold_earned"] = int(career_stats.get("gold_earned", 0)) + proceeds
	inventory_updated.emit()
	state_changed.emit()
	return {"success": true, "quantity": sold, "proceeds": proceeds, "message": "Sold %d %s for %d Gold." % [sold, item_id, proceeds]}

func upgrade_ship(target_ship_id: String) -> Dictionary:
	if voyage.is_active:
		return {"success": false, "message": "Ship upgrades are unavailable during an active voyage."}
	var ship_specs: Dictionary = Constants.SHIPS.get(target_ship_id, {})
	if ship_specs.is_empty():
		return {"success": false, "message": "Unknown ship class."}
	if target_ship_id == active_ship_id:
		return {"success": false, "message": "This ship is already active."}
	if str(ship_specs.get("previous_ship_id", "")) != active_ship_id:
		return {"success": false, "message": "Ships must be upgraded in fleet progression order."}
	var required_level: int = int(ship_specs.get("req_sailing", 1))
	if get_level("Sailing") < required_level:
		return {"success": false, "message": "Requires Sailing Level %d." % required_level}
	var cost_gold: int = int(ship_specs.get("cost_gold", 0))
	if gold < cost_gold:
		return {"success": false, "message": "Not enough Gold."}
	var cost_materials: Dictionary = ship_specs.get("cost_materials", {})
	for material_id in cost_materials:
		var required_qty: int = int(cost_materials[material_id])
		if int(bank.get(material_id, 0)) < required_qty:
			return {"success": false, "message": "Missing %d %s in Bank." % [required_qty, material_id]}
	# All validation precedes deductions, so failure never partially spends resources.
	gold -= cost_gold
	for material_id in cost_materials:
		bank[material_id] = int(bank[material_id]) - int(cost_materials[material_id])
		if int(bank[material_id]) <= 0:
			bank.erase(material_id)
	active_ship_id = target_ship_id
	inventory_updated.emit()
	state_changed.emit()
	return {"success": true, "message": "Upgraded to %s." % str(ship_specs.get("name", target_ship_id))}

func upgrade_equipment(slot: String) -> Dictionary:
	if voyage.is_active:
		return {"success": false, "message": "Equipment upgrades are locked during a voyage."}
	var recipe: Dictionary = Constants.EQUIPMENT.get(slot, {})
	if recipe.is_empty():
		return {"success": false, "message": "Unknown ship equipment."}
	var next_level: int = int(equipment_levels.get(slot, 0))
	if next_level >= Constants.EQUIPMENT_MAX_LEVEL:
		return {"success": false, "message": "This equipment is fully upgraded."}
	var primary: String = str(recipe.item)
	var secondary: String = str(recipe.plank)
	var primary_qty: int = int(recipe.qty[next_level])
	var secondary_qty: int = int(recipe.plank_qty[next_level])
	var cost_gold: int = int(recipe.gold[next_level])
	var cost_doubloons: int = int(recipe.doubloons[next_level])
	if int(bank.get(primary, 0)) < primary_qty or int(bank.get(secondary, 0)) < secondary_qty or gold < cost_gold or doubloons < cost_doubloons:
		return {"success": false, "message": "Need %d %s, %d %s, %d Gold and %d Doubloon(s)." % [primary_qty, primary, secondary_qty, secondary, cost_gold, cost_doubloons]}
	bank[primary] = int(bank[primary]) - primary_qty
	bank[secondary] = int(bank[secondary]) - secondary_qty
	if int(bank[primary]) <= 0: bank.erase(primary)
	if int(bank[secondary]) <= 0: bank.erase(secondary)
	gold -= cost_gold
	doubloons -= cost_doubloons
	equipment_levels[slot] = next_level + 1
	inventory_updated.emit()
	state_changed.emit()
	return {"success": true, "message": "%s upgraded to Level %d." % [str(recipe.name), next_level + 1]}

func use_field_repair() -> Dictionary:
	if GameClock.is_clock_paused(): return {"success": false, "message": "Voyage paused while the app is suspended."}
	if not voyage.is_active: return {"success": false, "message": "No active voyage."}
	var result: Dictionary = voyage.use_field_repair()
	return _settle_voyage_result(result) if bool(result.get("success", false)) else result

func use_emergency_ration() -> Dictionary:
	if GameClock.is_clock_paused(): return {"success": false, "message": "Voyage paused while the app is suspended."}
	if not voyage.is_active: return {"success": false, "message": "No active voyage."}
	var result: Dictionary = voyage.use_emergency_ration()
	return _settle_voyage_result(result) if bool(result.get("success", false)) else result

func fire_cannons_at(position: Vector2i) -> Dictionary:
	if GameClock.is_clock_paused():
		return {"success": false, "message": "Voyage paused while the app is suspended."}
	if not voyage.is_active:
		return {"success": false, "message": "No active voyage."}
	var result: Dictionary = voyage.fire_at(position)
	if bool(result.get("success", false)):
		return _settle_voyage_result(result)
	return result

func launch_voyage(tier: int, seed_value: int) -> Dictionary:
	if voyage.is_active:
		return {"success": false, "message": "A voyage is already active."}
	var provisions: Dictionary = Constants.VOYAGE_PROVISIONS.get(tier, {})
	if provisions.is_empty():
		return {"success": false, "message": "Unknown voyage tier."}
	var tier_requirements: Dictionary = Constants.VOYAGE_TIER_REQUIREMENTS.get(tier, {})
	var required_sailing: int = int(tier_requirements.get("req_sailing", 1))
	if get_level("Sailing") < required_sailing:
		return {"success": false, "message": "Requires Sailing Level %d." % required_sailing}
	var required_ship_tier: int = int(tier_requirements.get("ship_tier", 1))
	var current_ship_tier: int = 1
	for ship_key in Constants.SHIPS:
		if str(ship_key) == active_ship_id: break
		current_ship_tier += 1
	if current_ship_tier < required_ship_tier:
		return {"success": false, "message": "Requires ship tier %d." % required_ship_tier}
	for item_id in provisions:
		var needed: int = int(provisions[item_id])
		if int(bank.get(item_id, 0)) < needed:
			return {"success": false, "message": "Need %d %s in Bank." % [needed, item_id]}
	# All requirements are prechecked; consume atomically, then initialize voyage state.
	for item_id in provisions:
		bank[item_id] = int(bank[item_id]) - int(provisions[item_id])
		if int(bank[item_id]) <= 0:
			bank.erase(item_id)
	voyage.start_new_voyage(tier, seed_value, active_ship_id, captain_background, equipment_levels, int(provisions.get("cannonball", 0)), captain_relics, int(provisions.get("repair_plank", 0)), int(provisions.get("raw_sea_bass", 0)))
	career_stats["voyages_started"] = int(career_stats.get("voyages_started", 0)) + 1
	inventory_updated.emit()
	state_changed.emit()
	return {"success": true, "message": "Tier %d voyage provisioned and initialized." % tier}

func set_sail_trim(trim: String) -> Dictionary:
	if GameClock.is_clock_paused():
		return {"success": false, "message": "The voyage is paused while the app is suspended."}
	if not voyage.is_active:
		return {"success": false, "message": "No active voyage."}
	if not voyage.set_sail_trim(trim):
		return {"success": false, "message": "Invalid sail trim."}
	state_changed.emit()
	return {"success": true, "message": "Sail trim set to %s." % trim.capitalize()}

func move_open_sea_one_tile(direction: Vector2i) -> Dictionary:
	return move_open_sea_to(voyage.ship_position + direction)

func move_open_sea_to(destination: Vector2i) -> Dictionary:
	if GameClock.is_clock_paused():
		return {"success": false, "message": "Voyage paused while the app is suspended."}
	if not voyage.is_active:
		return {"success": false, "message": "No active voyage."}
	var result: Dictionary = voyage.move_to(destination)
	if not bool(result.get("success", false)):
		return result
	return _settle_voyage_result(result)

func advance_exploration_tick() -> Dictionary:
	if GameClock.is_clock_paused():
		return {"success": false, "message": "Voyage paused while the app is suspended."}
	if not voyage.is_active:
		return {"success": false, "message": "No active voyage."}
	var result: Dictionary = voyage.advance_exploration_tick()
	if not bool(result.get("success", false)):
		return result
	return _settle_voyage_result(result)

func _settle_voyage_result(result: Dictionary) -> Dictionary:
	if bool(result.get("sunk", false)):
		# Permanent ship tier is separate from the disposable voyage and its cargo.
		voyage = VoyageStateScript.new()
		result["message"] = str(result.get("message", "")) + " You returned to port with your ship tier intact."
		state_changed.emit()
		return result
	if bool(result.get("extracted", false)):
		var banked: int = 0
		for cargo_item in voyage.ship_cargo:
			var item_id: String = str(cargo_item.get("item_id", ""))
			var quantity: int = maxi(1, int(cargo_item.get("qty", 1)))
			if item_id == "gold_coin":
				gold += quantity
				career_stats["gold_earned"] = int(career_stats.get("gold_earned", 0)) + quantity
			elif item_id in ["sea_serpent_scale", "dreadnought_insignia"]:
				if not captain_relics.has(item_id): captain_relics.append(item_id)
				bank[item_id] = int(bank.get(item_id, 0)) + quantity
				banked += quantity
			elif not item_id.is_empty():
				bank[item_id] = int(bank.get(item_id, 0)) + quantity
				banked += quantity
		var guarantee: int = voyage.extraction_gold_reward
		if captain_relics.has("dreadnought_insignia"):
			guarantee = int(ceil(float(guarantee) * 1.10))
		if captain_background == "merchant":
			guarantee = int(ceil(float(guarantee) * 1.10))
		gold += guarantee
		career_stats["gold_earned"] = int(career_stats.get("gold_earned", 0)) + guarantee
		career_stats["extractions"] = int(career_stats.get("extractions", 0)) + 1
		career_stats["cargo_salvaged"] = int(career_stats.get("cargo_salvaged", 0)) + banked
		voyage.ship_cargo.clear()
		voyage.is_active = false
		result["banked_items"] = banked
		result["gold_reward"] = guarantee
		result["message"] = str(result.get("message", "")) + " Extraction banked %d item(s) and paid the guaranteed %d Gold recovery + profit reward." % [banked, guarantee]
		inventory_updated.emit()
	state_changed.emit()
	return result

func transfer_backpack_to_cargo() -> Dictionary:
	var max_cargo: int = int(Constants.SHIPS.get(active_ship_id, {}).get("cargo_slots", 8))
	var transferred: int = 0
	while not backpack.is_empty() and voyage.ship_cargo.size() < max_cargo:
		voyage.ship_cargo.append(backpack.pop_front())
		transferred += 1
	var result := {
		"transferred": transferred,
		"remaining_in_backpack": backpack.size(),
		"cargo_used": voyage.ship_cargo.size(),
		"cargo_max": max_cargo
	}
	if transferred > 0:
		inventory_updated.emit()
		state_changed.emit()
	return result

func extract_cargo_to_bank() -> int:
	var banked_count: int = 0
	for item in voyage.ship_cargo:
		var item_id: String = str(item.get("item_id", ""))
		var qty: int = maxi(1, int(item.get("qty", 1)))
		if not item_id.is_empty():
			bank[item_id] = int(bank.get(item_id, 0)) + qty
			banked_count += qty
	voyage.ship_cargo.clear()
	voyage.is_active = false
	inventory_updated.emit()
	state_changed.emit()
	return banked_count

func serialize() -> Dictionary:
	return {
		"version": 3,
		"tick_count": GameClock.tick_count,
		"active_ship_id": active_ship_id,
		"gold": gold,
		"doubloons": doubloons,
		"captain_background": captain_background,
		"career_stats": career_stats.duplicate(true),
		"equipment_levels": equipment_levels.duplicate(true),
		"captain_relics": captain_relics.duplicate(),
		"skill_xp": skill_xp.duplicate(true),
		"backpack": backpack.duplicate(true),
		"bank": bank.duplicate(true),
		"voyage": voyage.to_dict()
	}

func deserialize(data: Dictionary) -> void:
	GameClock.tick_count = maxi(0, int(data.get("tick_count", 0)))
	active_ship_id = str(data.get("active_ship_id", "wooden_sloop"))
	gold = maxi(0, int(data.get("gold", 1000)))
	doubloons = maxi(0, int(data.get("doubloons", 0)))
	captain_background = str(data.get("captain_background", "merchant"))
	if not ["merchant", "navigator", "shipwright"].has(captain_background):
		captain_background = "merchant"
	var loaded_stats: Variant = data.get("career_stats", {})
	career_stats = {"voyages_started": 0, "extractions": 0, "gold_earned": 0, "cargo_salvaged": 0}
	if loaded_stats is Dictionary:
		for stat_id in career_stats:
			career_stats[stat_id] = maxi(0, int(loaded_stats.get(stat_id, 0)))
	var saved_equipment: Variant = data.get("equipment_levels", {})
	equipment_levels = {"cannons": 0, "sails": 0, "hull": 0}
	if saved_equipment is Dictionary:
		for slot in equipment_levels:
			equipment_levels[slot] = clampi(int(saved_equipment.get(slot, 0)), 0, Constants.EQUIPMENT_MAX_LEVEL)
	captain_relics.clear()
	var saved_relics: Variant = data.get("captain_relics", [])
	if saved_relics is Array:
		for relic in saved_relics:
			if str(relic) in ["sea_serpent_scale", "dreadnought_insignia"] and not captain_relics.has(str(relic)):
				captain_relics.append(str(relic))
	var loaded_xp: Variant = data.get("skill_xp", {})
	for skill in Constants.SKILLS:
		skill_xp[skill] = maxi(0, int(loaded_xp.get(skill, 0))) if loaded_xp is Dictionary else 0
	backpack.clear()
	var loaded_backpack: Variant = data.get("backpack", [])
	if loaded_backpack is Array:
		for item in loaded_backpack:
			if item is Dictionary and item.has("item_id") and backpack.size() < Constants.MAX_BACKPACK_SLOTS:
				backpack.append({"item_id": str(item.get("item_id", "")), "qty": maxi(1, int(item.get("qty", 1)))})
	bank.clear()
	var loaded_bank: Variant = data.get("bank", {})
	if loaded_bank is Dictionary:
		for item_id in loaded_bank:
			bank[str(item_id)] = maxi(0, int(loaded_bank[item_id]))
	var loaded_voyage: Variant = data.get("voyage", {})
	voyage.from_dict(loaded_voyage if loaded_voyage is Dictionary else {})
	inventory_updated.emit()
	state_changed.emit()
