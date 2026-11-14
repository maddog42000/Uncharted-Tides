extends RefCounted
class_name VoyageState

const Constants = preload("res://data/mvp_constants.gd")
const CHART_SIZE: int = 10
const LEGACY_REEF_DAMAGE: int = 25

var is_active: bool = false
var tier: int = 1
var seed_value: int = 0
var current_hull_hp: int = 100
var ship_id: String = "wooden_sloop"
var captain_background: String = "merchant"
var ship_cargo: Array[Dictionary] = []
var chart_size: int = CHART_SIZE
var ship_position: Vector2i = Vector2i.ZERO
var extraction_position: Vector2i = Vector2i(CHART_SIZE - 1, CHART_SIZE - 1)
var salvage_position: Vector2i = Vector2i(1, 0)
var salvage_collected: bool = false
var step_count: int = 0
var hazards: Array[Dictionary] = []
var exploration_sites: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var ammunition: int = 0
var equipment_levels: Dictionary = {"cannons": 0, "sails": 0, "hull": 0}
var reef_position: Vector2i = Vector2i(5, 5) # Compatibility alias for the first reef.
var wind_direction: Vector2i = Vector2i.RIGHT # Display-only environmental condition; never restricts course.
var extraction_gold_reward: int = 0
var last_action_message: String = ""

func start_new_voyage(p_tier: int, p_seed: int, p_ship_id: String = "wooden_sloop", p_background: String = "merchant", p_equipment: Dictionary = {}, p_ammunition: int = 0) -> void:
	is_active = true
	tier = clampi(p_tier, 1, 4)
	seed_value = p_seed
	ship_id = p_ship_id
	captain_background = p_background
	equipment_levels = p_equipment.duplicate(true)
	current_hull_hp = max_hull_hp()
	ammunition = maxi(0, p_ammunition)
	ship_cargo.clear()
	chart_size = int(Constants.CHART_SIZE_BY_TIER.get(tier, CHART_SIZE))
	ship_position = Vector2i.ZERO
	extraction_position = Vector2i(chart_size - 1, chart_size - 1)
	salvage_position = Vector2i(1, 0)
	salvage_collected = false
	step_count = 0
	hazards.clear()
	exploration_sites.clear()
	enemies.clear()
	last_action_message = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(p_seed)
	var winds: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	wind_direction = winds[rng.randi_range(0, winds.size() - 1)]
	_generate_hazards(rng)
	_generate_sites(rng)
	_generate_enemies(rng)
	reef_position = _first_hazard_position("reef")
	extraction_gold_reward = _calculate_extraction_reward(tier)

func _calculate_extraction_reward(voyage_tier: int) -> int:
	var provisions: Dictionary = Constants.VOYAGE_PROVISIONS.get(voyage_tier, {})
	var cost: int = 0
	for item_id in provisions:
		var offer: Dictionary = Constants.MARKET_ITEMS.get(item_id, {})
		cost += int(provisions[item_id]) * int(offer.get("price_gold", 0))
	return int(ceil(float(cost) * (1.0 + Constants.VOYAGE_EXTRACTION_MARGIN)))

func _generate_hazards(rng: RandomNumberGenerator) -> void:
	var hazard_types: Array[String] = ["reef", "mine", "obstacle", "reef"]
	var desired: int = int(Constants.HAZARD_COUNTS_BY_TIER.get(tier, tier))
	for index in range(desired):
		var position := _random_open_position(rng)
		var kind: String = hazard_types[index % hazard_types.size()]
		var damage: int = 25 if kind == "reef" else (35 if kind == "mine" else 15)
		hazards.append({"id": "hazard_%d" % index, "type": kind, "position": _vector_to_array(position), "damage": damage})
	if hazards.is_empty():
		hazards.append({"id": "hazard_0", "type": "reef", "position": [5, 5], "damage": LEGACY_REEF_DAMAGE})

func _generate_sites(rng: RandomNumberGenerator) -> void:
	var island_position := _random_open_position(rng)
	var wreck_position := _random_open_position(rng)
	exploration_sites = [
		{"id": "island_cove", "type": "island", "position": _vector_to_array(island_position), "required_ticks": int(Constants.SITE_WORK_TICKS.island), "work_ticks": 0, "reward_item": "mahogany_plank", "reward_qty": 2, "reward_gold": 0, "completed": false},
		{"id": "shipwreck", "type": "shipwreck", "position": _vector_to_array(wreck_position), "required_ticks": int(Constants.SITE_WORK_TICKS.shipwreck), "work_ticks": 0, "reward_item": "mithril_bar", "reward_qty": 1, "reward_gold": 0, "completed": false}
	]

func _random_open_position(rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in range(100):
		var candidate := Vector2i(rng.randi_range(2, chart_size - 3), rng.randi_range(1, chart_size - 2))
		if candidate == ship_position or candidate == extraction_position or candidate == salvage_position:
			continue
		var occupied: bool = false
		for hazard in hazards:
			if _array_to_vector(hazard.get("position", []), Vector2i(-1, -1)) == candidate:
				occupied = true
				break
		for site in exploration_sites:
			if _array_to_vector(site.get("position", []), Vector2i(-1, -1)) == candidate:
				occupied = true
				break
		if not occupied:
			return candidate
	return Vector2i(4 + hazards.size() % 2, 4 + exploration_sites.size())

func movement_range() -> int:
	var background_bonus: int = 1 if captain_background == "navigator" else 0
	return maxi(1, int(Constants.SHIPS.get(ship_id, {}).get("movement_range", 1)) + background_bonus + int(equipment_levels.get("sails", 0)))

func max_hull_hp() -> int:
	return int(Constants.SHIPS.get(ship_id, {}).get("max_hp", 100)) + 50 * int(equipment_levels.get("hull", 0))

func cannon_damage() -> int:
	return int(Constants.CANNON_BASE_DAMAGE) + 15 * int(equipment_levels.get("cannons", 0))

func _generate_enemies(rng: RandomNumberGenerator) -> void:
	var count: int = int(Constants.ENEMY_COUNTS_BY_TIER.get(tier, 1))
	for index in range(count):
		var position := _random_open_position(rng)
		var kind: String = "pirate_sloop" if tier < 3 or index % 2 == 0 else "pirate_galleon"
		enemies.append({"id": "enemy_%d" % index, "type": kind, "position": _vector_to_array(position), "hull": int(Constants.ENEMY_HULL_BY_TIER.get(tier, 60)), "max_hull": int(Constants.ENEMY_HULL_BY_TIER.get(tier, 60)), "damage": int(Constants.ENEMY_DAMAGE_BY_TIER.get(tier, 12)), "loot_gold": int(Constants.ENEMY_LOOT_BY_TIER.get(tier, 150)), "alive": true})

func enemy_at(position: Vector2i) -> Dictionary:
	for enemy in enemies:
		if bool(enemy.get("alive", false)) and _array_to_vector(enemy.get("position", []), Vector2i(-1, -1)) == position:
			return enemy
	return {}

func can_fire_at(position: Vector2i) -> bool:
	return is_active and ammunition > 0 and not enemy_at(position).is_empty() and absi(position.x - ship_position.x) + absi(position.y - ship_position.y) <= Constants.COMBAT_RANGE

func fire_at(position: Vector2i) -> Dictionary:
	if not is_active:
		return _action_result(false, "No active voyage.")
	if ammunition <= 0:
		return _action_result(false, "No cannonballs remain.")
	if not can_fire_at(position):
		return _action_result(false, "Select a living enemy within cannon range.")
	var enemy: Dictionary = enemy_at(position)
	ammunition -= 1
	step_count += 1
	var damage: int = cannon_damage()
	enemy["hull"] = maxi(0, int(enemy.get("hull", 0)) - damage)
	var message: String = "Broadside hits %s for %d damage (%d/%d hull)." % [str(enemy.get("type", "enemy")).replace("_", " ").capitalize(), damage, int(enemy.hull), int(enemy.max_hull)]
	if int(enemy.hull) <= 0:
		enemy["alive"] = false
		ship_cargo.append({"item_id": "gold_coin", "qty": int(enemy.get("loot_gold", 0))})
		message += " Enemy defeated; %d Gold recovered as salvage." % int(enemy.loot_gold)
	var retaliation: int = _enemy_attacks()
	if retaliation > 0:
		message += " Enemy return fire deals %d hull damage." % retaliation
	var sunk: bool = current_hull_hp <= 0
	if sunk:
		ship_cargo.clear()
		is_active = false
		message += " The ship sank; unbanked cargo was lost."
	last_action_message = message
	return {"success": true, "message": message, "sunk": sunk, "extracted": false, "hull_damage": retaliation, "enemy_defeated": not bool(enemy.alive), "ammunition": ammunition}

func _enemy_attacks() -> int:
	var total: int = 0
	for enemy in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var position: Vector2i = _array_to_vector(enemy.get("position", []), Vector2i(-1, -1))
		if absi(position.x - ship_position.x) + absi(position.y - ship_position.y) <= 3:
			var damage: int = int(enemy.get("damage", 0))
			if captain_background == "shipwright":
				damage = maxi(1, int(ceil(float(damage) * 0.8)))
			current_hull_hp = maxi(0, current_hull_hp - damage)
			total += damage
	return total

func _mitigate_hazard_damage(raw_damage: int) -> int:
	if captain_background == "shipwright" and raw_damage > 0:
		return maxi(1, int(ceil(float(raw_damage) * 0.8)))
	return raw_damage

func can_move_to(destination: Vector2i) -> bool:
	if not is_active or destination == ship_position:
		return false
	if destination.x < 0 or destination.y < 0 or destination.x >= chart_size or destination.y >= chart_size:
		return false
	return absi(destination.x - ship_position.x) + absi(destination.y - ship_position.y) <= movement_range()

func move_to(destination: Vector2i) -> Dictionary:
	if not is_active:
		return _action_result(false, "No active voyage.")
	if not can_move_to(destination):
		return _action_result(false, "Choose a highlighted tile within your ship's movement range.")
	ship_position = destination
	step_count += 1
	var message: String = "Sailed to (%d, %d)." % [destination.x, destination.y]
	var damage: int = _resolve_hazard_at_ship()
	if damage > 0:
		message += " Hazard strike: hull lost %d HP." % damage
	if destination == salvage_position and not salvage_collected:
		salvage_collected = true
		ship_cargo.append({"item_id": "copper_ore", "qty": 3})
		message += " Salvaged 3 Copper Ore."
	var drift_damage: int = _drift_hazards()
	damage += drift_damage
	if drift_damage > 0:
		message += " A drifting hazard struck for %d hull damage." % drift_damage
	var sunk: bool = current_hull_hp <= 0
	if sunk:
		ship_cargo.clear()
		is_active = false
		message += " The ship sank; unbanked cargo was lost."
	var extracted: bool = is_active and ship_position == extraction_position
	if extracted:
		message += " Extraction ready; guaranteed reward is %d Gold." % extraction_gold_reward
	last_action_message = message
	return {"success": true, "message": message, "position": ship_position, "step_count": step_count, "hull_damage": damage, "sunk": sunk, "extracted": extracted, "loot_found": destination == salvage_position and salvage_collected}

func advance_exploration_tick() -> Dictionary:
	if not is_active:
		return _action_result(false, "No active voyage.")
	var site_index: int = _site_index_at(ship_position)
	if site_index < 0:
		return _action_result(false, "Anchor on an island or shipwreck to explore.")
	var site: Dictionary = exploration_sites[site_index]
	if bool(site.get("completed", false)):
		return _action_result(false, "This site has already been scavenged.")
	site["work_ticks"] = int(site.get("work_ticks", 0)) + 1
	step_count += 1
	var message: String = "Anchored safely: exploration %d/%d ticks." % [int(site.work_ticks), int(site.required_ticks)]
	var damage: int = _drift_hazards()
	if damage > 0:
		message += " A drifting hazard struck for %d hull damage." % damage
	var sunk: bool = current_hull_hp <= 0
	var reward: Dictionary = {}
	if sunk:
		ship_cargo.clear()
		is_active = false
		message += " The ship sank; unbanked cargo was lost."
	elif int(site.work_ticks) >= int(site.required_ticks):
		site["completed"] = true
		reward = {"item_id": str(site.reward_item), "qty": int(site.reward_qty)}
		ship_cargo.append(reward.duplicate())
		message += " Recovered %d %s." % [int(site.reward_qty), str(Constants.ITEMS.get(site.reward_item, {}).get("name", site.reward_item))]
	last_action_message = message
	return {"success": true, "message": message, "sunk": sunk, "extracted": false, "hull_damage": damage, "reward": reward, "step_count": step_count}

func _drift_hazards() -> int:
	var interval: int = int(Constants.HAZARD_DRIFT_EVERY_TURNS.get(tier, 5))
	if step_count <= 0 or step_count % interval != 0:
		return 0
	var total_damage: int = 0
	for hazard in hazards:
		var old_position: Vector2i = _array_to_vector(hazard.get("position", []), Vector2i.ZERO)
		var next_position := old_position
		var dx: int = ship_position.x - old_position.x
		var dy: int = ship_position.y - old_position.y
		if absi(dx) + absi(dy) > 0:
			if absi(dx) > absi(dy):
				next_position.x += signi(dx)
			else:
				next_position.y += signi(dy)
			hazard["position"] = _vector_to_array(next_position)
			if next_position == ship_position:
				var damage: int = _mitigate_hazard_damage(int(hazard.get("damage", LEGACY_REEF_DAMAGE)))
				current_hull_hp = maxi(0, current_hull_hp - damage)
				total_damage += damage
	reef_position = _first_hazard_position("reef")
	return total_damage

func _resolve_hazard_at_ship() -> int:
	var damage: int = 0
	for hazard in hazards:
		if _array_to_vector(hazard.get("position", []), Vector2i(-1, -1)) == ship_position:
			damage += _mitigate_hazard_damage(int(hazard.get("damage", LEGACY_REEF_DAMAGE)))
			# Hazard relocates after impact so the same object cannot repeatedly strike from one tile.
			hazard["position"] = _vector_to_array(_nearest_safe_position(ship_position))
	current_hull_hp = maxi(0, current_hull_hp - damage)
	reef_position = _first_hazard_position("reef")
	return damage

func _nearest_safe_position(from: Vector2i) -> Vector2i:
	for radius in range(1, chart_size):
		for y in range(chart_size):
			for x in range(chart_size):
				var candidate := Vector2i(x, y)
				if absi(x - from.x) + absi(y - from.y) != radius:
					continue
				if candidate == ship_position or candidate == extraction_position or candidate == salvage_position:
					continue
				var used: bool = false
				for hazard in hazards:
					if _array_to_vector(hazard.get("position", []), Vector2i(-1, -1)) == candidate:
						used = true
						break
				if not used:
					return candidate
	return from

func _site_index_at(position: Vector2i) -> int:
	for index in range(exploration_sites.size()):
		if _array_to_vector(exploration_sites[index].get("position", []), Vector2i(-1, -1)) == position:
			return index
	return -1

func current_site() -> Dictionary:
	var index: int = _site_index_at(ship_position)
	return exploration_sites[index] if index >= 0 else {}

func hazard_at(position: Vector2i) -> Dictionary:
	for hazard in hazards:
		if _array_to_vector(hazard.get("position", []), Vector2i(-1, -1)) == position:
			return hazard
	return {}

func _first_hazard_position(kind: String) -> Vector2i:
	for hazard in hazards:
		if str(hazard.get("type", "")) == kind:
			return _array_to_vector(hazard.get("position", []), Vector2i(5, 5))
	return Vector2i(5, 5)

func extraction_guarantee_covers_cost() -> bool:
	return extraction_gold_reward >= _calculate_extraction_reward(tier) and extraction_gold_reward > 0

func _action_result(success: bool, message: String) -> Dictionary:
	return {"success": success, "message": message, "position": ship_position, "step_count": step_count, "hull_damage": 0, "sunk": false, "extracted": false}

func _vector_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]

func _array_to_vector(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func to_dict() -> Dictionary:
	return {"is_active": is_active, "tier": tier, "seed_value": seed_value, "current_hull_hp": current_hull_hp, "ship_id": ship_id, "captain_background": captain_background, "ship_cargo": ship_cargo.duplicate(true), "chart_size": chart_size, "ship_position": _vector_to_array(ship_position), "extraction_position": _vector_to_array(extraction_position), "salvage_position": _vector_to_array(salvage_position), "salvage_collected": salvage_collected, "step_count": step_count, "hazards": hazards.duplicate(true), "exploration_sites": exploration_sites.duplicate(true), "reef_position": _vector_to_array(reef_position), "wind_direction": _vector_to_array(wind_direction), "extraction_gold_reward": extraction_gold_reward, "last_action_message": last_action_message, "enemies": enemies.duplicate(true), "ammunition": ammunition, "equipment_levels": equipment_levels.duplicate(true)}

func from_dict(data: Dictionary) -> void:
	is_active = bool(data.get("is_active", false))
	tier = clampi(int(data.get("tier", 1)), 1, 4)
	seed_value = int(data.get("seed_value", 0))
	ship_id = str(data.get("ship_id", "wooden_sloop"))
	captain_background = str(data.get("captain_background", "merchant"))
	current_hull_hp = maxi(0, int(data.get("current_hull_hp", 100)))
	ship_cargo.clear()
	var saved_cargo: Variant = data.get("ship_cargo", [])
	if saved_cargo is Array:
		for item in saved_cargo:
			if item is Dictionary and item.has("item_id"):
				ship_cargo.append({"item_id": str(item.get("item_id", "")), "qty": maxi(1, int(item.get("qty", 1)))})
	chart_size = clampi(int(data.get("chart_size", CHART_SIZE)), 5, 20)
	ship_position = _array_to_vector(data.get("ship_position", null), Vector2i.ZERO)
	extraction_position = _array_to_vector(data.get("extraction_position", null), Vector2i(chart_size - 1, chart_size - 1))
	salvage_position = _array_to_vector(data.get("salvage_position", null), Vector2i(1, 0))
	salvage_collected = bool(data.get("salvage_collected", false))
	step_count = maxi(0, int(data.get("step_count", 0)))
	hazards.clear()
	var saved_hazards: Variant = data.get("hazards", [])
	if saved_hazards is Array:
		for hazard in saved_hazards:
			if hazard is Dictionary and hazard.has("position"):
				hazards.append(hazard.duplicate(true))
	if not data.has("hazards") and data.has("reef_position"):
		hazards.append({"id": "hazard_0", "type": "reef", "position": data.get("reef_position", [5, 5]), "damage": LEGACY_REEF_DAMAGE})
	reef_position = _array_to_vector(data.get("reef_position", null), _first_hazard_position("reef"))
	exploration_sites.clear()
	var saved_sites: Variant = data.get("exploration_sites", [])
	if saved_sites is Array:
		for site in saved_sites:
			if site is Dictionary and site.has("position"):
				exploration_sites.append(site.duplicate(true))
	wind_direction = _array_to_vector(data.get("wind_direction", null), Vector2i.RIGHT)
	extraction_gold_reward = int(data.get("extraction_gold_reward", _calculate_extraction_reward(tier)))
	last_action_message = str(data.get("last_action_message", ""))
	ammunition = maxi(0, int(data.get("ammunition", 0)))
	var saved_equipment: Variant = data.get("equipment_levels", {})
	for slot in ["cannons", "sails", "hull"]:
		equipment_levels[slot] = clampi(int(saved_equipment.get(slot, 0)), 0, Constants.EQUIPMENT_MAX_LEVEL) if saved_equipment is Dictionary else 0
	enemies.clear()
	var saved_enemies: Variant = data.get("enemies", [])
	if saved_enemies is Array:
		for enemy in saved_enemies:
			if enemy is Dictionary and enemy.has("position"):
				enemies.append(enemy.duplicate(true))
