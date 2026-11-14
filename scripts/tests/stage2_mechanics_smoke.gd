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
	var navigator = VoyageStateScript.new()
	navigator.start_new_voyage(1, 78, "wooden_sloop", "navigator")
	_check(navigator.movement_range() == 2, "Navigator gains one movement tile per action")
	var shipwright = VoyageStateScript.new()
	shipwright.start_new_voyage(1, 79, "wooden_sloop", "shipwright")
	shipwright.hazards.clear()
	shipwright.hazards.append({"id": "test_reef", "type": "reef", "position": [1, 0], "damage": 25})
	var mitigated: Dictionary = shipwright.move_to(Vector2i(1, 0))
	_check(mitigated.success and int(mitigated.hull_damage) == 20 and shipwright.current_hull_hp == 80, "Shipwright reduces collision hull damage by twenty percent")
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
	var settlement: Dictionary = player._settle_voyage_result({"success": true, "sunk": false, "extracted": true, "message": "Extracted."})
	_check(settlement.success and settlement.gold_reward == int(ceil(float(payout.extraction_gold_reward) * 1.10)), "Merchant extraction bonus is applied once to the guaranteed payout")
	_check(player.bank.get("copper_ore", 0) == 2 and player.bank.get("mahogany_plank", 0) == 1 and player.career_stats.extractions == 1 and player.career_stats.gold_earned == settlement.gold_reward and player.career_stats.cargo_salvaged == 3, "Extraction banks cargo and increments journal totals once per voyage")
	var career_snapshot: Dictionary = player.serialize()
	player.deserialize(career_snapshot)
	_check(player.captain_background == "merchant" and player.career_stats == career_snapshot.career_stats, "Captain choice and lifetime journal totals survive player serialization")
	player.deserialize({"gold": 100, "bank": {}, "backpack": [], "skill_xp": {}, "voyage": {}})
	_check(player.captain_background == "merchant" and int(player.career_stats.voyages_started) == 0, "Legacy saves migrate to default Captain and empty journal totals")
	var settings_manager: Node = root.get_node("SettingsManager")
	var previous_text_size: int = settings_manager.text_size_index
	var previous_motion: bool = settings_manager.reduced_motion
	settings_manager.set_text_size(2)
	settings_manager.set_reduced_motion(true)
	var reloaded_settings = SettingsManagerScript.new()
	reloaded_settings._load_settings()
	_check(reloaded_settings.text_size_index == 2 and reloaded_settings.reduced_motion and settings_manager.text_scale() == 1.15 and settings_manager.transition_duration(0.2) == 0.0, "Text size and reduced motion settings persist and affect presentation")
	reloaded_settings.free()
	settings_manager.set_text_size(previous_text_size)
	settings_manager.set_reduced_motion(previous_motion)
	player.reset_to_defaults()
	player.bank["copper_ore"] = 3
	var sale: Dictionary = player.sell_market_item("copper_ore", 2)
	_check(bool(sale.success) and int(sale.proceeds) == 24 and player.gold == 1024 and int(player.bank.copper_ore) == 1, "Home Port market sale debits bank stock and credits Gold")
	player.reset_to_defaults()
	if failures == 0:
		print("Stage 3 mechanics smoke tests passed.")
		quit(0)
	else:
		push_error("%d mechanics smoke test(s) failed." % failures)
		quit(1)
