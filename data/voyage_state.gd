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
var relics: Array[String] = []
var repair_stock: int = 0
var ration_stock: int = 0
var ration_burst_actions: int = 0
var bosses_defeated: int = 0
var reef_position: Vector2i = Vector2i(5, 5) # Compatibility alias for the first reef.
var wind_direction: Vector2i = Vector2i.RIGHT # Display-only environmental condition; never restricts course.
var extraction_gold_reward: int = 0
var last_action_message: String = ""
var event_feed: Array[String] = []
var crew: Array[String] = []
var sea_events: Array[Dictionary] = []
var pending_event_index: int = -1
var fog_actions: int = 0

func start_new_voyage(p_tier: int, p_seed: int, p_ship_id: String = "wooden_sloop", p_background: String = "merchant", p_equipment: Dictionary = {}, p_ammunition: int = 0, p_relics: Array = [], p_repairs: int = 0, p_rations: int = 0, p_crew: Array = []) -> void:
	is_active = true
	tier = clampi(p_tier, 1, 4)
	seed_value = p_seed
	ship_id = p_ship_id
	captain_background = p_background
	equipment_levels = p_equipment.duplicate(true)
	relics.clear()
	for relic in p_relics:
		if not relics.has(str(relic)): relics.append(str(relic))
	repair_stock = maxi(0, p_repairs)
	ration_stock = maxi(0, p_rations)
	ration_burst_actions = 0
	bosses_defeated = 0
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
	event_feed.clear()
	crew.clear()
	for crew_id in p_crew:
		if not crew.has(str(crew_id)): crew.append(str(crew_id))
	sea_events.clear()
	pending_event_index = -1
	fog_actions = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(p_seed)
	var winds: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	wind_direction = winds[rng.randi_range(0, winds.size() - 1)]
	_generate_hazards(rng)
	_generate_sites(rng)
	_generate_enemies(rng)
	for i in range(int(Constants.SEA_EVENT_COUNTS_BY_TIER.get(tier, 2))):
		sea_events.append({"type":["merchant_distress","tailwind_current","fog_squall"][i % 3],"position":_vector_to_array(_random_open_position(rng)),"resolved":false})
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
	var tier_rewards: Dictionary = Constants.SITE_REWARDS_BY_TIER.get(tier, Constants.SITE_REWARDS_BY_TIER[1])
	exploration_sites = [
		{"id": "island_cove", "type": "island", "position": _vector_to_array(island_position), "required_ticks": int(Constants.SITE_WORK_TICKS.island), "work_ticks": 0, "reward_item": str(tier_rewards.island_item), "reward_qty": int(tier_rewards.island_qty), "reward_gold": 0, "completed": false},
		{"id": "shipwreck", "type": "shipwreck", "position": _vector_to_array(wreck_position), "required_ticks": int(Constants.SITE_WORK_TICKS.shipwreck), "work_ticks": 0, "reward_item": str(tier_rewards.wreck_item), "reward_qty": int(tier_rewards.wreck_qty), "reward_gold": 0, "completed": false}
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
	return maxi(1, int(Constants.SHIPS.get(ship_id, {}).get("movement_range", 1)) + background_bonus + int(equipment_levels.get("sails", 0)) + (1 if relics.has("storm_compass") else 0) + (1 if ration_burst_actions > 0 else 0))

func max_hull_hp() -> int:
	return int(Constants.SHIPS.get(ship_id, {}).get("max_hp", 100)) + 50 * int(equipment_levels.get("hull", 0)) + (25 if relics.has("sea_serpent_scale") else 0)

func cannon_damage() -> int:
	return int(Constants.CANNON_BASE_DAMAGE) + 15 * int(equipment_levels.get("cannons", 0)) + (5 if relics.has("dreadnought_insignia") else 0) + (6 if crew.has("master_gunner") else 0)

func _generate_enemies(rng: RandomNumberGenerator) -> void:
	var count: int = int(Constants.ENEMY_COUNTS_BY_TIER.get(tier, 1)) + (1 if tier >= 3 else 0)
	for index in range(count):
		var position := _random_open_position(rng)
		var kind: String = "pirate_sloop" if tier < 3 or index % 2 == 0 else "pirate_galleon"
		var boss: bool = tier >= 3 and index == count - 1
		var boss_type: String = "sea_monster" if tier == 3 else "dreadnought_captain"
		var hull: int = int(Constants.BOSS_HULL_BY_TIER[tier]) if boss else int(Constants.ENEMY_HULL_BY_TIER.get(tier, 60))
		var damage: int = int(Constants.BOSS_DAMAGE_BY_TIER[tier]) if boss else int(Constants.ENEMY_DAMAGE_BY_TIER.get(tier, 12))
		var loot: int = int(Constants.BOSS_LOOT_BY_TIER[tier]) if boss else int(Constants.ENEMY_LOOT_BY_TIER.get(tier, 150))
		enemies.append({"id": "boss_%d" % tier if boss else "enemy_%d" % index, "type": boss_type if boss else kind, "boss": boss, "position": _vector_to_array(position), "hull": hull, "max_hull": hull, "damage": damage, "loot_gold": loot, "relic_id": "sea_serpent_scale" if boss and tier == 3 else ("dreadnought_insignia" if boss else ""), "alive": true})

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
		if bool(enemy.get("boss", false)):
			bosses_defeated += 1
			var relic_id: String = str(enemy.get("relic_id", ""))
			if not relic_id.is_empty():
				ship_cargo.append({"item_id": relic_id, "qty": 1})
				message += " Unique relic recovered: %s!" % str(Constants.ITEMS.get(relic_id, {}).get("name", relic_id))
	var retaliation: int = _enemy_attacks()
	if retaliation > 0:
		message += " Enemy return fire deals %d hull damage." % retaliation
	var sunk: bool = current_hull_hp <= 0
	if sunk:
		ship_cargo.clear()
		is_active = false
		message += " The ship sank; unbanked cargo was lost."
	_record_event(message)
	last_action_message = message
	return {"success": true, "message": message, "sunk": sunk, "extracted": false, "hull_damage": retaliation, "enemy_defeated": not bool(enemy.alive), "ammunition": ammunition}

func use_field_repair() -> Dictionary:
	if not is_active: return _action_result(false, "No active voyage.")
	if repair_stock <= 0: return _action_result(false, "No repair planks remain.")
	if current_hull_hp >= max_hull_hp(): return _action_result(false, "Hull is already at maximum durability.")
	repair_stock -= 1
	var restored: int = mini(Constants.FIELD_REPAIR_HP + (15 if crew.has("bosun") else 0), max_hull_hp() - current_hull_hp)
	current_hull_hp += restored
	step_count += 1
	var retaliation: int = _enemy_attacks()
	var drift_damage: int = _drift_hazards()
	var sunk: bool = current_hull_hp <= 0
	if sunk: ship_cargo.clear(); is_active = false
	var message: String = "Field repairs restore %d hull HP (%d repair plank(s) left)." % [restored, repair_stock]
	if retaliation + drift_damage > 0: message += " Hazards/enemies deal %d damage during repairs." % (retaliation + drift_damage)
	if sunk: message += " The ship sank; unbanked cargo was lost."
	_record_event(message)
	last_action_message = message
	return {"success": true, "message": message, "sunk": sunk, "hull_damage": retaliation + drift_damage, "hull_restored": restored}

func use_emergency_ration() -> Dictionary:
	if not is_active: return _action_result(false, "No active voyage.")
	if ration_stock <= 0: return _action_result(false, "No emergency rations remain.")
	ration_stock -= 1
	ration_burst_actions = Constants.RATION_BURST_TURNS
	step_count += 1
	var retaliation: int = _enemy_attacks()
	var drift_damage: int = _drift_hazards()
	var sunk: bool = current_hull_hp <= 0
	if sunk: ship_cargo.clear(); is_active = false
	var message: String = "Emergency ration consumed; next move gains +1 tile range (%d ration(s) left)." % ration_stock
	if retaliation + drift_damage > 0: message += " Hazards/enemies deal %d damage." % (retaliation + drift_damage)
	if sunk: message += " The ship sank; unbanked cargo was lost."
	_record_event(message)
	last_action_message = message
	return {"success": true, "message": message, "sunk": sunk, "hull_damage": retaliation + drift_damage}

func consume_movement_burst() -> void:
	if ration_burst_actions > 0: ration_burst_actions -= 1

func _enemy_attacks() -> int:
	if fog_actions > 0:
		fog_actions -= 1
		return 0
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
	if pending_event_index >= 0: return _action_result(false, "Resolve the event first.")
	if not can_move_to(destination):
		return _action_result(false, "Choose a highlighted tile within your ship's movement range.")
	ship_position = destination
	step_count += 1
	var event_id: int = event_at(destination)
	if event_id >= 0: pending_event_index = event_id
	var message: String = "Sailed to (%d, %d)." % [destination.x, destination.y]
	var damage: int = _resolve_hazard_at_ship()
	if damage > 0:
		message += " Hazard strike: hull lost %d HP." % damage
	if destination == salvage_position and not salvage_collected:
		salvage_collected = true
		ship_cargo.append({"item_id": "copper_ore", "qty": 3 + (1 if crew.has("quartermaster") else 0)})
		message += " Salvaged 3 Copper Ore."
	var drift_damage: int = _drift_hazards()
	damage += drift_damage
	consume_movement_burst()
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
	_record_event(message)
	last_action_message = message
	return {"success": true, "message": message, "position": ship_position, "step_count": step_count, "hull_damage": damage, "sunk": sunk, "extracted": extracted, "loot_found": destination == salvage_position and salvage_collected, "event_pending": pending_event_index >= 0}

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
	_record_event(message)
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

func event_at(position: Vector2i) -> int:
	for index in range(sea_events.size()):
		var event: Dictionary = sea_events[index]
		if not bool(event.get("resolved", false)) and _array_to_vector(event.get("position", []), Vector2i(-1, -1)) == position:
			return index
	return -1
func current_sea_event() -> Dictionary:
	return sea_events[pending_event_index] if pending_event_index >= 0 and pending_event_index < sea_events.size() else {}
func resolve_sea_event(choice: String) -> Dictionary:
	var event: Dictionary = current_sea_event()
	if event.is_empty(): return _action_result(false, "No event is awaiting a choice.")
	var kind: String = str(event.get("type", ""))
	var message: String = ""
	match kind:
		"merchant_distress":
			if choice == "rescue":
				ship_cargo.append({"item_id":"gold_coin", "qty":150 * tier})
				message = "Rescued the merchant; secured %d Gold in voyage cargo." % (150 * tier)
			elif choice == "salvage":
				ship_cargo.append({"item_id":"copper_ore", "qty":tier + 1})
				message = "Salvaged %d Copper Ore from the distress site." % (tier + 1)
			elif choice == "pass": message = "Passed the merchant distress signal."
			else: return _action_result(false, "Choose rescue, salvage, or pass.")
		"tailwind_current":
			if choice != "ride": return _action_result(false, "Choose to ride the current.")
			ration_burst_actions = 1
			message = "Caught a tailwind; your next movement gains +1 tile."
		"fog_squall":
			if choice != "shelter": return _action_result(false, "Choose shelter in the fog.")
			fog_actions = int(Constants.FOG_STEALTH_ACTIONS_BY_TIER.get(tier, 2))
			message = "Sheltered in the fog; enemies lose aggression for %d actions." % fog_actions
		_:
			return _action_result(false, "Unknown sea event.")
	event["resolved"] = true
	pending_event_index = -1
	step_count += 1
	_record_event(message)
	last_action_message = message
	return {"success":true, "message":message}

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

func _record_event(message: String) -> void:
	var normalized: String = message.strip_edges()
	if normalized.is_empty():
		return
	event_feed.append(normalized)
	while event_feed.size() > 6:
		event_feed.pop_front()

func _vector_to_array(value: Vector2i) -> Array[int]:
	return [value.x, value.y]

func _array_to_vector(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(clampi(int(value[0]), 0, chart_size - 1), clampi(int(value[1]), 0, chart_size - 1))
	return fallback

func to_dict() -> Dictionary:
	return {"is_active": is_active, "tier": tier, "seed_value": seed_value, "current_hull_hp": current_hull_hp, "ship_id": ship_id, "captain_background": captain_background, "ship_cargo": ship_cargo.duplicate(true), "chart_size": chart_size, "ship_position": _vector_to_array(ship_position), "extraction_position": _vector_to_array(extraction_position), "salvage_position": _vector_to_array(salvage_position), "salvage_collected": salvage_collected, "step_count": step_count, "hazards": hazards.duplicate(true), "exploration_sites": exploration_sites.duplicate(true), "reef_position": _vector_to_array(reef_position), "wind_direction": _vector_to_array(wind_direction), "extraction_gold_reward": extraction_gold_reward, "last_action_message": last_action_message, "event_feed": event_feed.duplicate(), "enemies": enemies.duplicate(true), "ammunition": ammunition, "equipment_levels": equipment_levels.duplicate(true), "relics": relics.duplicate(), "repair_stock": repair_stock, "ration_stock": ration_stock, "ration_burst_actions": ration_burst_actions, "bosses_defeated": bosses_defeated, "crew": crew.duplicate(), "sea_events": sea_events.duplicate(true), "pending_event_index": pending_event_index, "fog_actions": fog_actions}

func from_dict(data: Dictionary) -> void:
	is_active = bool(data.get("is_active", false))
	tier = clampi(int(data.get("tier", 1)), 1, 4)
	seed_value = int(data.get("seed_value", 0))
	ship_id = str(data.get("ship_id", "wooden_sloop"))
	if not Constants.SHIPS.has(ship_id): ship_id = "wooden_sloop"
	captain_background = str(data.get("captain_background", "merchant"))
	if not ["merchant", "navigator", "shipwright"].has(captain_background): captain_background = "merchant"
	current_hull_hp = maxi(0, int(data.get("current_hull_hp", 100)))
	ship_cargo.clear()
	var saved_cargo: Variant = data.get("ship_cargo", [])
	if saved_cargo is Array:
		for item in saved_cargo:
			var item_id: String = str(item.get("item_id", "")) if item is Dictionary else ""
			if Constants.ITEMS.has(item_id):
				ship_cargo.append({"item_id": item_id, "qty": clampi(int(item.get("qty", 1)), 1, 1000000)})
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
			if hazard is Dictionary and hazard.has("position") and str(hazard.get("type", "")) in ["reef", "mine", "obstacle"]:
				hazards.append({"id": str(hazard.get("id", "legacy_hazard")), "type": str(hazard.type), "position": _vector_to_array(_array_to_vector(hazard.position, Vector2i.ZERO)), "damage": clampi(int(hazard.get("damage", LEGACY_REEF_DAMAGE)), 1, 500)})
	if not data.has("hazards") and data.has("reef_position"):
		hazards.append({"id": "hazard_0", "type": "reef", "position": data.get("reef_position", [5, 5]), "damage": LEGACY_REEF_DAMAGE})
	reef_position = _array_to_vector(data.get("reef_position", null), _first_hazard_position("reef"))
	exploration_sites.clear()
	var saved_sites: Variant = data.get("exploration_sites", [])
	if saved_sites is Array:
		for site in saved_sites:
			if site is Dictionary and site.has("position") and str(site.get("type", "")) in ["island", "shipwreck"] and Constants.ITEMS.has(str(site.get("reward_item", ""))):
				var required_ticks: int = clampi(int(site.get("required_ticks", Constants.SITE_WORK_TICKS.get(str(site.type), 1))), 1, 10)
				exploration_sites.append({"id": str(site.get("id", "legacy_site")), "type": str(site.type), "position": _vector_to_array(_array_to_vector(site.position, Vector2i.ZERO)), "required_ticks": required_ticks, "work_ticks": clampi(int(site.get("work_ticks", 0)), 0, required_ticks), "reward_item": str(site.reward_item), "reward_qty": clampi(int(site.get("reward_qty", 1)), 1, 100000), "reward_gold": maxi(0, int(site.get("reward_gold", 0))), "completed": bool(site.get("completed", false))})
	wind_direction = _array_to_vector(data.get("wind_direction", null), Vector2i.RIGHT)
	extraction_gold_reward = maxi(_calculate_extraction_reward(tier), maxi(0, int(data.get("extraction_gold_reward", 0))))
	last_action_message = str(data.get("last_action_message", ""))
	event_feed.clear()
	var saved_feed: Variant = data.get("event_feed", [])
	if saved_feed is Array:
		for event_text in saved_feed:
			event_feed.append(str(event_text))
	while event_feed.size() > 6:
		event_feed.pop_front()
	ammunition = maxi(0, int(data.get("ammunition", 0)))
	var saved_equipment: Variant = data.get("equipment_levels", {})
	for slot in ["cannons", "sails", "hull"]:
		equipment_levels[slot] = clampi(int(saved_equipment.get(slot, 0)), 0, Constants.EQUIPMENT_MAX_LEVEL) if saved_equipment is Dictionary else 0
	enemies.clear()
	var saved_enemies: Variant = data.get("enemies", [])
	if saved_enemies is Array:
		for enemy in saved_enemies:
			if enemy is Dictionary and enemy.has("position") and str(enemy.get("type", "")) in ["pirate_sloop", "pirate_galleon", "sea_monster", "dreadnought_captain"]:
				var max_enemy_hull: int = clampi(int(enemy.get("max_hull", enemy.get("hull", 1))), 1, 1000000)
				enemies.append({"id": str(enemy.get("id", "legacy_enemy")), "type": str(enemy.type), "boss": bool(enemy.get("boss", false)), "position": _vector_to_array(_array_to_vector(enemy.position, Vector2i.ZERO)), "hull": clampi(int(enemy.get("hull", max_enemy_hull)), 0, max_enemy_hull), "max_hull": max_enemy_hull, "damage": clampi(int(enemy.get("damage", 0)), 0, 10000), "loot_gold": maxi(0, int(enemy.get("loot_gold", 0))), "relic_id": str(enemy.get("relic_id", "")) if str(enemy.get("relic_id", "")) in ["sea_serpent_scale", "dreadnought_insignia"] else "", "alive": bool(enemy.get("alive", false))})
	relics.clear()
	var saved_relics: Variant = data.get("relics", [])
	if saved_relics is Array:
		for relic in saved_relics:
			if str(relic) in ["sea_serpent_scale", "dreadnought_insignia"] and not relics.has(str(relic)): relics.append(str(relic))
	repair_stock = maxi(0, int(data.get("repair_stock", 0)))
	ration_stock = maxi(0, int(data.get("ration_stock", 0)))
	ration_burst_actions = clampi(int(data.get("ration_burst_actions", 0)), 0, 1)
	bosses_defeated = maxi(0, int(data.get("bosses_defeated", 0)))
	crew.clear()
	var saved_crew: Variant = data.get("crew", [])
	if saved_crew is Array:
		for crew_id in saved_crew:
			if Constants.CREW_SPECIALISTS.has(str(crew_id)) and not crew.has(str(crew_id)): crew.append(str(crew_id))
	sea_events.clear()
	var saved_events: Variant = data.get("sea_events", [])
	if saved_events is Array:
		for sea_event in saved_events:
			if sea_event is Dictionary and str(sea_event.get("type", "")) in ["merchant_distress", "tailwind_current", "fog_squall"]:
				sea_events.append({"type": str(sea_event.type), "position": _vector_to_array(_array_to_vector(sea_event.get("position", []), Vector2i.ZERO)), "resolved": bool(sea_event.get("resolved", false))})
	pending_event_index = clampi(int(data.get("pending_event_index", -1)), -1, sea_events.size() - 1)
	fog_actions = maxi(0, int(data.get("fog_actions", 0)))
	current_hull_hp = mini(current_hull_hp, max_hull_hp())
