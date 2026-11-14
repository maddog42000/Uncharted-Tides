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
	player.bank["oak_plank"] = 40
	player.bank["iron_bar"] = 20
	var upgrade_result: Dictionary = player.upgrade_ship("oak_brigantine")
	_check(upgrade_result.success and player.active_ship_id == "oak_brigantine" and player.gold == 5000, "Valid ship upgrade spends expected costs")
	_check(player.bank.get("oak_plank", 0) == 0 and player.bank.get("iron_bar", 0) == 0, "Upgrade consumes singular-ID materials")

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

	saves.wipe_save()
	if _failures == 0:
		print("Stage 3 contract smoke tests passed.")
		quit(0)
	else:
		push_error("%d Stage 3 contract smoke test(s) failed." % _failures)
		quit(1)
