extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var player: Node = root.get_node("PlayerData")
	var saves: Node = root.get_node("SaveManager")
	var assets: Node = root.get_node("AssetManager")
	saves.wipe_save()
	var old_briefing_seen: bool = root.get_node("SettingsManager").briefing_seen

	_check(player.xp_for_level[2] == 83 and player.xp_for_level[99] == 13034431, "OSRS XP table boundaries")
	_check(assets.has_asset("oak_plank") and assets.get_asset_url("oak_plank").ends_with("1794561097075.jpg"), "AssetManager item mapping")
	_check(assets.get_asset_url("mithril_bar").ends_with("1794565378876.jpg"), "Mithril Bar asset mapping")
	_check(assets.get_asset_url("loading_screen").ends_with("1794565997504.jpg"), "Loading screen asset mapping")
	_check(assets.get_asset_url("main_menu").ends_with("1794566539395.jpg"), "Main menu asset mapping")
	_check(assets.get_asset_url("missing_id").is_empty(), "Unknown asset returns empty URL")

	player.add_to_backpack("copper_ore", 5)
	var deposit_result: Dictionary = player.deposit("copper_ore", 3)
	_check(deposit_result.success and deposit_result.quantity == 3 and int(player.bank.get("copper_ore", 0)) == 3 and player.backpack.size() == 2, "Partial deposit")
	var withdraw_result: Dictionary = player.withdraw("copper_ore", 2)
	_check(withdraw_result.success and int(player.bank.get("copper_ore", 0)) == 1 and player.backpack.size() == 4, "Partial withdrawal")
	player.add_to_backpack("filler", 24)
	var blocked_withdraw: Dictionary = player.withdraw("copper_ore", 1)
	_check(not blocked_withdraw.success and int(player.bank.get("copper_ore", 0)) == 1, "Full backpack rejects withdrawal without mutation")

	player.backpack.clear()
	player.skill_xp["Sailing"] = player.xp_for_level[30]
	player.gold = 10000
	player.bank["oak_plank"] = 20
	player.bank["iron_bar"] = 10
	var upgrade_result: Dictionary = player.upgrade_ship("oak_brigantine")
	_check(upgrade_result.success and player.active_ship_id == "oak_brigantine" and player.gold == 7000, "Valid Stage 8 Brigantine upgrade spends 3,000 Gold")
	_check(player.bank.get("oak_plank", 0) == 0 and player.bank.get("iron_bar", 0) == 0, "Upgrade consumes singular-ID materials")

	player.deserialize({
		"version": 1, "active_ship_id": "unknown_ship", "gold": 1234, "captain_background": "unknown_perk",
		"skill_xp": {"Sailing": player.xp_for_level[25], "Unknown Skill": 999999},
		"career_stats": {"voyages_started": 2, "gold_earned": -50},
		"captain_relics": ["sea_serpent_scale", "unknown_relic"],
		"hired_crew": ["bosun", "not_a_specialist"], "active_crew": ["bosun", "not_a_specialist"],
		"fleet_prestige": -3, "sailing_milestones_claimed": [10, 77], "bounty_cycle": 0,
		"bank": {"oak_plank": 7, "not_an_item": 5},
		"bounty_contracts": [{"id": "fleet_hunt", "progress": 1, "completed": false}, {"id": "site_survey", "progress": 0, "completed": false}, {"id": "unknown", "progress": 99999, "completed": true}],
		"voyage": {"is_active": true, "tier": 2, "ship_id": "invalid_ship", "captain_background": "invalid",
			"current_hull_hp": 9000, "chart_size": 10, "ship_position": [99, -8], "ship_cargo": [{"item_id": "unknown_item", "qty": 4}, {"item_id": "oak_plank", "qty": 2}],
			"hazards": [{"type": "reef", "position": [2, 2], "damage": 25}, {"type": "script", "position": [3, 3], "damage": 99999}],
			"relics": ["dreadnought_insignia", "bogus"], "crew": ["quartermaster", "bogus"],
			"sea_events": [{"type": "fog_squall", "position": [2, 2]}, {"type": "unknown", "position": [3, 3]}]}
	})
	_check(player.active_ship_id == "wooden_sloop" and player.captain_background == "merchant" and player.get_level("Sailing") == 25, "Legacy migration defaults unknown ship/perk and retains valid Sailing XP")
	_check(player.captain_relics == ["sea_serpent_scale"] and player.hired_crew == ["bosun"] and player.active_crew == ["bosun"] and player.fleet_prestige == 0 and player.sailing_milestones_claimed == [10], "Crew, Relics, Prestige, and milestones migrate with allowlisted values")
	_check(player.career_stats.voyages_started == 2 and player.career_stats.gold_earned == 0 and player.bank == {"oak_plank": 7}, "Journal and Bank migration fills missing fields and discards invalid values")
	_check(player.voyage.ship_id == "wooden_sloop" and player.voyage.ship_position == Vector2i(9, 0) and player.voyage.ship_cargo.size() == 1 and player.voyage.hazards.size() == 1 and player.voyage.sea_events.size() == 1, "Malformed active voyage keeps valid fields and clamps coordinates while filtering unknown values")
	_check(player.bounty_contracts.size() == 3 and player.bounty_contracts[0].progress == 1 and not player.bounty_contracts[0].completed, "Bounty migration preserves partial progress and fills unknown/missing contracts")
	player.reset_to_defaults()

	player.active_ship_id = "wooden_sloop"
	player.skill_xp["Sailing"] = player.xp_for_level[25]
	player.bank["repair_plank"] = 4
	player.bank["cannonball"] = 20
	player.bank["raw_sea_bass"] = 5
	var locked_tier: Dictionary = player.launch_voyage(2, 122)
	_check(not locked_tier.success and locked_tier.message.contains("ship tier"), "Higher voyage tier requires matching ship progression")
	player.active_ship_id = "oak_brigantine"
	player.bank["repair_plank"] = 2
	player.bank["cannonball"] = 10
	player.bank["raw_sea_bass"] = 3
	var launch_result: Dictionary = player.launch_voyage(1, 12345)
	_check(launch_result.success and player.voyage.is_active and player.voyage.tier == 1, "Tier 1 launches from contract table")
	_check(int(player.career_stats.voyages_started) == 1, "Launching a voyage increments the lifetime journal")
	var locked_background: Dictionary = player.select_captain_background("navigator")
	_check(not locked_background.success and player.captain_background == "merchant", "Captain background cannot change while at sea")
	var gold_before: int = player.gold
	var locked_upgrade: Dictionary = player.upgrade_ship("mahogany_galleon")
	_check(not locked_upgrade.success and player.gold == gold_before and player.active_ship_id == "oak_brigantine", "Active voyage blocks ship upgrade without spending")
	_check(player.bank.get("repair_plank", 0) == 0 and player.bank.get("cannonball", 0) == 0 and player.bank.get("raw_sea_bass", 0) == 0, "Tier 1 provisions deducted")

	root.get_node("SettingsManager").set_briefing_seen(not old_briefing_seen)
	var reset_settings_value: bool = root.get_node("SettingsManager").briefing_seen
	_check(saves.wipe_save() and root.get_node("SettingsManager").briefing_seen == reset_settings_value, "Save reset succeeds without deleting independent Settings preferences")
	root.get_node("SettingsManager").set_briefing_seen(old_briefing_seen)
	if _failures == 0:
		print("Stage 8 contract smoke tests passed.")
		quit(0)
	else:
		push_error("%d Stage 8 contract smoke test(s) failed." % _failures)
		quit(1)
