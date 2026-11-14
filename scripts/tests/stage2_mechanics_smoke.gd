extends SceneTree

const Constants = preload("res://data/mvp_constants.gd")
const VoyageStateScript = preload("res://data/voyage_state.gd")
const SettingsManagerScript = preload("res://scripts/autoloads/SettingsManager.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var voyage = VoyageStateScript.new()
	voyage.start_new_voyage(1, 123, "wooden_sloop")
	_check(voyage.can_move_to(Vector2i(1, 0)) and not voyage.can_move_to(Vector2i(2, 0)), "Sloop range is one tile")
	voyage.ship_id = "oak_brigantine"
	_check(voyage.can_move_to(Vector2i(2, 0)) and not voyage.can_move_to(Vector2i(2, 1)), "Brigantine range is two Manhattan tiles; wind does not constrain course")
	voyage.ship_id = "mahogany_galleon"
	_check(voyage.can_move_to(Vector2i(3, 0)), "Galleon range is three tiles")
	voyage.ship_id = "dragonwood_man_owar"
	_check(voyage.can_move_to(Vector2i(4, 0)), "Man-o'-War range is four tiles")

	var low = VoyageStateScript.new()
	var high = VoyageStateScript.new()
	low.start_new_voyage(1, 404, "wooden_sloop")
	high.start_new_voyage(4, 404, "wooden_sloop")
	_check(low.hazards.size() == 1 and high.hazards.size() == 4, "Hazard density scales with voyage tier")
	_check(int(Constants.HAZARD_DRIFT_EVERY_TURNS[4]) < int(Constants.HAZARD_DRIFT_EVERY_TURNS[1]), "Higher tiers drift hazards more frequently")
	low.hazards.clear()
	low.hazards.append({"id":"test","type":"reef","position":[6,5],"damage":25})
	low.ship_position = Vector2i(5, 5)
	low.step_count = 5
	var before := low._array_to_vector(low.hazards[0].position, Vector2i.ZERO)
	low._drift_hazards()
	var after := low._array_to_vector(low.hazards[0].position, Vector2i.ZERO)
	_check(after != before and absi(after.x - low.ship_position.x) + absi(after.y - low.ship_position.y) < absi(before.x - low.ship_position.x) + absi(before.y - low.ship_position.y), "Hazards drift one tile closer on their tier interval")

	var exploring = VoyageStateScript.new()
	exploring.start_new_voyage(1, 555, "wooden_sloop")
	exploring.hazards.clear()	# isolate the anchored-work reward assertion
	var site: Dictionary = exploring.exploration_sites[0]
	var coordinates: Array = site.position
	exploring.ship_position = Vector2i(int(coordinates[0]), int(coordinates[1]))
	var required: int = int(site.required_ticks)
	for tick in range(required - 1):
		var partial: Dictionary = exploring.advance_exploration_tick()
		_check(bool(partial.success) and partial.reward.is_empty(), "Exploration work consumes an anchored tick without early reward")
	var finished: Dictionary = exploring.advance_exploration_tick()
	_check(bool(finished.success) and bool(site.completed) and not finished.reward.is_empty(), "Configured anchored ticks complete the island and grant cargo")
	_check(exploring.ship_position == Vector2i(int(coordinates[0]), int(coordinates[1])), "Exploration remains anchored in place")

	var payout = VoyageStateScript.new()
	payout.start_new_voyage(1, 77)
	var provision_cost := 0
	for item_id in Constants.VOYAGE_PROVISIONS[1]:
		provision_cost += int(Constants.VOYAGE_PROVISIONS[1][item_id]) * int(Constants.MARKET_ITEMS[item_id].price_gold)
	_check(payout.extraction_gold_reward > provision_cost and payout.extraction_guarantee_covers_cost(), "Successful extraction guarantee exceeds provision buy-cost baseline")
	for tier in range(1, 5):
		var tier_voyage = VoyageStateScript.new()
		tier_voyage.start_new_voyage(tier, 600 + tier)
		var tier_cost: int = 0
		for item_id in Constants.VOYAGE_PROVISIONS[tier]:
			tier_cost += int(Constants.VOYAGE_PROVISIONS[tier][item_id]) * int(Constants.MARKET_ITEMS[item_id].price_gold)
		_check(tier_voyage.extraction_gold_reward > tier_cost and tier_voyage.extraction_guarantee_covers_cost(), "Tier %d safe-extraction guarantee covers provision cost plus profit" % tier)
		if tier >= 3:
			var boss: Dictionary = {}
			for enemy in tier_voyage.enemies:
				if bool(enemy.get("boss", false)): boss = enemy
			_check(not boss.is_empty() and int(boss.max_hull) == int(Constants.BOSS_HULL_BY_TIER[tier]) and int(boss.damage) == int(Constants.BOSS_DAMAGE_BY_TIER[tier]), "Tier %d boss hull and damage use the tuned configuration" % tier)
			if tier == 3:
				tier_voyage.hazards.clear()
				tier_voyage.ammunition = 10
				for enemy in tier_voyage.enemies:
					if not bool(enemy.get("boss", false)): enemy["alive"] = false
				boss["position"] = [1, 0]
				boss["hull"] = 1
				var boss_shot: Dictionary = tier_voyage.fire_at(Vector2i(1, 0))
				var relic_dropped: bool = false
				for cargo_item in tier_voyage.ship_cargo:
					if str(cargo_item.get("item_id", "")) == "sea_serpent_scale": relic_dropped = true
				_check(boss_shot.success and relic_dropped and tier_voyage.event_feed.back().contains("Unique relic recovered"), "Defeating the Tier 3 boss drops its unique Captain Relic and records the trigger")
	var navigator = VoyageStateScript.new()
	navigator.start_new_voyage(1, 78, "wooden_sloop", "navigator")
	_check(navigator.movement_range() == 2, "Navigator gains one movement tile per action")
	var shipwright = VoyageStateScript.new()
	shipwright.start_new_voyage(1, 79, "wooden_sloop", "shipwright")
	shipwright.hazards.clear()
	shipwright.hazards.append({"id": "test_reef", "type": "reef", "position": [1, 0], "damage": 25})
	var mitigated: Dictionary = shipwright.move_to(Vector2i(1, 0))
	_check(mitigated.success and int(mitigated.hull_damage) == 20 and shipwright.current_hull_hp == 80, "Shipwright reduces collision hull damage by twenty percent")
	var field = VoyageStateScript.new()
	field.start_new_voyage(1, 912, "wooden_sloop", "merchant", {}, 10, [], 2, 2)
	field.hazards.clear()
	field.enemies.clear()
	field.current_hull_hp = field.max_hull_hp() - 55
	var repair: Dictionary = field.use_field_repair()
	_check(repair.success and int(repair.hull_restored) == Constants.FIELD_REPAIR_HP and field.repair_stock == 1 and field.current_hull_hp == field.max_hull_hp() - 15, "Field repair consumes one carried plank for capped hull recovery")
	var ration: Dictionary = field.use_emergency_ration()
	_check(ration.success and field.ration_stock == 1 and field.movement_range() == 2, "Emergency ration grants a temporary +1-tile movement burst")
	var field_copy = VoyageStateScript.new()
	field_copy.from_dict(field.to_dict())
	_check(field_copy.repair_stock == 1 and field_copy.ration_stock == 1 and field_copy.ration_burst_actions == 1 and field_copy.event_feed == field.event_feed, "Field supplies, ration burst, and recent event feed survive voyage serialization")
	var combat = VoyageStateScript.new()
	combat.start_new_voyage(2, 808, "oak_brigantine", "merchant", {"cannons": 1, "sails": 0, "hull": 1}, 4)
	_check(combat.chart_size == 12 and combat.enemies.size() == 2, "Tier 2 uses a larger chart and scaled enemy fleet")
	_check(combat.cannon_damage() == 40 and combat.max_hull_hp() == 300 and combat.movement_range() == 2, "Equipment directly increases cannon damage and maximum hull")
	var target: Vector2i = Vector2i(2, 0)
	combat.enemies[0]["position"] = [target.x, target.y]
	var shot: Dictionary = combat.fire_at(target)
	_check(shot.success and combat.ammunition == 3 and int(combat.enemies[0].hull) == 60 and combat.current_hull_hp < combat.max_hull_hp(), "Cannon fire consumes ammo, damages enemy hull, and triggers retaliation")
	var combat_copy = VoyageStateScript.new()
	combat_copy.from_dict(combat.to_dict())
	_check(combat_copy.enemies == combat.enemies and combat_copy.ammunition == combat.ammunition and combat_copy.equipment_levels == combat.equipment_levels, "Enemy hull, ammunition, and equipment survive voyage serialization")

	var round_trip = VoyageStateScript.new()
	round_trip.from_dict(exploring.to_dict())
	print("Serialization comparison: hazards=%s sites=%s" % [str(round_trip.hazards == exploring.hazards), str(round_trip.exploration_sites == exploring.exploration_sites)])
	_check(round_trip.exploration_sites == exploring.exploration_sites and round_trip.hazards == exploring.hazards, "Hazards and site progress survive voyage serialization")

	var player: Node = root.get_node("PlayerData")
	player.reset_to_defaults()
	player.select_captain_background("merchant")
	player.voyage.start_new_voyage(1, 120, player.active_ship_id, player.captain_background)
	player.voyage.ship_cargo.clear()
	player.voyage.ship_cargo.append({"item_id": "copper_ore", "qty": 2})
	player.voyage.ship_cargo.append({"item_id": "mahogany_plank", "qty": 1})
	player.voyage.ship_cargo.append({"item_id": "sea_serpent_scale", "qty": 1})
	var settlement: Dictionary = player._settle_voyage_result({"success": true, "sunk": false, "extracted": true, "message": "Extracted."})
	_check(settlement.success and settlement.gold_reward == int(ceil(float(payout.extraction_gold_reward) * 1.10)), "Merchant extraction bonus is applied once to the guaranteed payout")
	_check(player.bank.get("copper_ore", 0) == 2 and player.bank.get("mahogany_plank", 0) == 1 and player.bank.get("sea_serpent_scale", 0) == 1 and player.captain_relics.has("sea_serpent_scale") and player.career_stats.extractions == 1 and player.career_stats.gold_earned == settlement.gold_reward + 450 and player.career_stats.cargo_salvaged == 4, "Extraction banks cargo/relics, records the relic, and increments journal totals including the bounty payout")
	var career_snapshot: Dictionary = player.serialize()
	player.deserialize(career_snapshot)
	var relic_snapshot: Dictionary = player.serialize()
	player.deserialize(relic_snapshot)
	_check(player.captain_background == "merchant" and player.career_stats == relic_snapshot.career_stats and player.captain_relics.has("sea_serpent_scale"), "Captain Relics and career totals survive player serialization")
	var relic_voyage = VoyageStateScript.new()
	relic_voyage.start_new_voyage(3, 333, "wooden_sloop", "merchant", {}, 10, ["sea_serpent_scale", "dreadnought_insignia"])
	_check(relic_voyage.max_hull_hp() == 125 and relic_voyage.cannon_damage() == 30, "Owned Captain Relics grant passive hull and cannon bonuses")
	player.reset_to_defaults()
	var starting_contracts: Array[Dictionary] = player.get_bounty_contracts()
	_check(starting_contracts.size() == 3 and int(starting_contracts[2].get("tier", 0)) == 1, "New save receives three active contracts with a cycle-assigned Tier 1 extraction")
	var bounty_gold_before: int = player.gold
	var bounty_doubloons_before: int = player.doubloons
	player.voyage.start_new_voyage(1, 912, player.active_ship_id)
	player._settle_voyage_result({"enemy_defeated": true})
	var partial_bounty_snapshot: Dictionary = player.serialize()
	player.deserialize(partial_bounty_snapshot)
	_check(int(player.bounty_contracts[0].get("progress", 0)) == 1 and player.gold == bounty_gold_before, "Partial enemy-contract progress persists without prematurely paying its reward")
	player.voyage.start_new_voyage(1, 913, player.active_ship_id)
	player._settle_voyage_result({"enemy_defeated": true})
	player._settle_voyage_result({"reward": {"item_id": "mahogany_plank", "qty": 1}})
	var bounty_extraction: Dictionary = player._settle_voyage_result({"extracted": true, "message": "Safe extraction."})
	_check(player.gold - bounty_gold_before - int(bounty_extraction.get("gold_reward", 0)) == 1000 and player.doubloons - bounty_doubloons_before == 4 and player.bank.get("iron_bar", 0) == 1 and player.bank.get("mahogany_plank", 0) == 1 and player.bank.get("mithril_bar", 0) == 1, "Gameplay settlement hooks grant configured bounty Gold, Doubloons, and materials")
	var all_bounties_completed: bool = true
	for contract in player.get_bounty_contracts():
		if not bool(contract.get("completed", false)): all_bounties_completed = false
	_check(all_bounties_completed, "Enemy, site, and matching-tier extraction contracts all record completion")
	var bounty_snapshot: Dictionary = player.serialize()
	player.deserialize(bounty_snapshot)
	_check(player.bounty_contracts == bounty_snapshot.bounty_contracts and player.bank.get("mithril_bar", 0) == 1 and player.doubloons == 4, "Bounty progress and rewards survive player save restoration")
	player.career_stats["voyages_started"] = Constants.BOUNTY_VOYAGES_PER_CYCLE
	var next_cycle_contracts: Array[Dictionary] = player.get_bounty_contracts()
	_check(player.bounty_cycle == 1 and int(next_cycle_contracts[2].get("tier", 0)) == 2 and int(next_cycle_contracts[0].get("progress", -1)) == 0, "Bounty cycle rotates after three launched voyages and resets progress")
	var audio_cue: Node = root.get_node("AudioCue")
	var required_cues: Array[String] = ["cannon_fire", "hull_hit", "repair", "ration", "salvage", "extraction"]
	var audio_ready: bool = true
	for cue_id in required_cues:
		var audio_player: AudioStreamPlayer = audio_cue._players.get(cue_id) as AudioStreamPlayer
		if audio_player == null or not (audio_player.stream is AudioStreamWAV) or (audio_player.stream as AudioStreamWAV).data.is_empty(): audio_ready = false
	_check(audio_ready and AudioServer.get_bus_index("SFX") >= 0, "Procedural cue WAV streams and SFX bus initialize without external audio assets")
	player.deserialize({"gold": 100, "bank": {}, "backpack": [], "skill_xp": {}, "voyage": {}})
	_check(player.captain_background == "merchant" and int(player.career_stats.voyages_started) == 0, "Legacy saves migrate to default Captain and empty journal totals")
	var settings_manager: Node = root.get_node("SettingsManager")
	var previous_text_size: int = settings_manager.text_size_index
	var previous_motion: bool = settings_manager.reduced_motion
	var previous_master_volume: float = settings_manager.master_volume
	var previous_sfx_volume: float = settings_manager.sfx_volume
	settings_manager.set_text_size(2)
	settings_manager.set_reduced_motion(true)
	settings_manager.set_master_volume(0.37)
	settings_manager.set_sfx_volume(0.61)
	var reloaded_settings = SettingsManagerScript.new()
	reloaded_settings._load_settings()
	_check(reloaded_settings.text_size_index == 2 and reloaded_settings.reduced_motion and settings_manager.text_scale() == 1.15 and settings_manager.transition_duration(0.2) == 0.0, "Text size and reduced motion settings persist and affect presentation")
	_check(is_equal_approx(reloaded_settings.master_volume, 0.37) and is_equal_approx(reloaded_settings.sfx_volume, 0.61), "Master and SFX audio volumes persist through settings reload")
	reloaded_settings.free()
	settings_manager.set_text_size(previous_text_size)
	settings_manager.set_reduced_motion(previous_motion)
	settings_manager.set_master_volume(previous_master_volume)
	settings_manager.set_sfx_volume(previous_sfx_volume)
	player.reset_to_defaults()
	player.bank = Constants.VOYAGE_PROVISIONS[1].duplicate(true)
	var launch_result: Dictionary = player.launch_voyage(1, 515)
	_check(launch_result.success and player.voyage.repair_stock == 2 and player.voyage.ration_stock == 3 and player.voyage.ammunition == 10 and player.bank.is_empty(), "Launch consumes and carries Tier 1 repair, ration, and cannonball provisions")
	player.reset_to_defaults()
	player.bank["iron_bar"] = 4
	player.bank["oak_plank"] = 4
	var cannon_upgrade: Dictionary = player.upgrade_equipment("cannons")
	_check(cannon_upgrade.success and int(player.equipment_levels.cannons) == 1, "Shipyard crafting consumes materials and upgrades cannon level")
	var equipment_save: Dictionary = player.serialize()
	player.deserialize(equipment_save)
	_check(int(player.equipment_levels.cannons) == 1, "Ship equipment levels persist in player save")
	player.reset_to_defaults()
	player.bank["copper_ore"] = 3
	var sale: Dictionary = player.sell_market_item("copper_ore", 2)
	_check(bool(sale.success) and int(sale.proceeds) == 24 and player.gold == 1024 and int(player.bank.copper_ore) == 1, "Home Port market sale debits bank stock and credits Gold")
	player.reset_to_defaults()
	if failures == 0:
		print("Stage 6 mechanics smoke tests passed.")
		quit(0)
	else:
		push_error("%d Stage 6 mechanics smoke test(s) failed." % failures)
		quit(1)
