extends SceneTree

const SettingsManagerScript = preload("res://scripts/autoloads/SettingsManager.gd")

var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: " + label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _find_button(node: Node, target_text: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == target_text:
			return button
	return null

func _find_cell(node: Node, x: int, y: int) -> Button:
	return node.find_child("Cell_%d_%d" % [x, y], true, false) as Button

func _run() -> void:
	var saves: Node = root.get_node("SaveManager")
	var player: Node = root.get_node("PlayerData")
	var game_clock: Node = root.get_node("GameClock")
	var settings_manager: Node = root.get_node("SettingsManager")
	var old_briefing_seen: bool = settings_manager.briefing_seen
	saves.wipe_save()
	settings_manager.set_briefing_seen(false)
	var scene_error: Error = change_scene_to_file("res://scenes/main_menu.tscn")
	_check(scene_error == OK, "Main Menu scene opens")
	await process_frame
	await process_frame
	var menu: Node = current_scene
	_check(menu != null and menu.scene_file_path == "res://scenes/main_menu.tscn", "Main Menu is current scene")
	if menu == null:
		quit(1)
		return
	for hotspot_name in ["SettingsHotspot", "SelectCharacterHotspot", "JournalHotspot", "NavigateHotspot", "StartVoyageHotspot"]:
		_check(menu.find_child(hotspot_name, true, false) is Button, "Menu hotspot exists: " + hotspot_name)
	var briefing_panel := menu.find_child("MenuModal", true, false) as Control
	var viewport_bounds := Rect2(Vector2.ZERO, menu.get_viewport_rect().size)
	_check(briefing_panel != null and viewport_bounds.encloses(briefing_panel.get_global_rect()), "Briefing modal stays inside landscape viewport bounds")
	var briefing_copy: String = ""
	if briefing_panel != null:
		for label_node in briefing_panel.find_children("*", "Label", true, false):
			briefing_copy += " " + str((label_node as Label).text)
	_check(briefing_copy.contains("Movement") and briefing_copy.contains("Provisions") and briefing_copy.contains("island") and briefing_copy.contains("Guaranteed Gold"), "New profiles see an explanatory Captain's Briefing before navigating")
	var briefing_scroll := menu.find_child("ModalContentScroll", true, false) as ScrollContainer
	_check(briefing_scroll != null and briefing_scroll.get_parent() != null, "Briefing content is placed in the adaptive scrollable modal")
	var briefing_close := _find_button(menu, "Close")
	if briefing_close != null:
		briefing_close.pressed.emit()
	await process_frame
	_check(settings_manager.briefing_seen, "Dismissing first-run briefing records it as seen")
	_check(menu.find_child("BeginYourOdysseyHotspot", true, false) == null, "No prohibited Begin Your Odyssey control exists")
	var menu_art: TextureRect = menu.find_child("MenuArtwork", true, false) as TextureRect
	_check(menu_art != null and menu_art.texture is AtlasTexture and (menu_art.texture as AtlasTexture).region.size.y == 640.0, "Menu artwork crop excludes bottom strip")
	var start_button := menu.find_child("StartVoyageHotspot", true, false) as Button
	var old_text_size: int = settings_manager.text_size_index
	var old_reduced_motion: bool = settings_manager.reduced_motion
	var old_master_volume: float = settings_manager.master_volume
	var old_sfx_volume: float = settings_manager.sfx_volume
	var test_text_size: int = (old_text_size + 1) % 3
	var settings_button := menu.find_child("SettingsHotspot", true, false) as Button
	if settings_button != null:
		settings_button.pressed.emit()
	await process_frame
	var text_size_option := menu.find_child("TextSizeOption", true, false) as OptionButton
	var reduced_motion_toggle := menu.find_child("ReducedMotionToggle", true, false) as CheckButton
	_check(text_size_option != null and reduced_motion_toggle != null, "Settings panel provides Text Size and Reduced Motion controls")
	if text_size_option != null:
		text_size_option.select(test_text_size)
		text_size_option.item_selected.emit(test_text_size)
	if reduced_motion_toggle != null:
		reduced_motion_toggle.button_pressed = not old_reduced_motion
		reduced_motion_toggle.toggled.emit(not old_reduced_motion)
	_check(settings_manager.text_size_index == test_text_size and settings_manager.reduced_motion != old_reduced_motion, "Settings controls update saved accessibility preferences")
	var master_slider := menu.find_child("MastervolumeSlider", true, false) as HSlider
	var sfx_slider := menu.find_child("SFXvolumeSlider", true, false) as HSlider
	_check(master_slider != null and sfx_slider != null, "Settings panel provides Master and SFX volume sliders")
	if master_slider != null:
		master_slider.value = 0.37
		master_slider.value_changed.emit(0.37)
	if sfx_slider != null:
		sfx_slider.value = 0.61
		sfx_slider.value_changed.emit(0.61)
	var volume_reload := SettingsManagerScript.new()
	volume_reload._load_settings()
	_check(is_equal_approx(volume_reload.master_volume, 0.37) and is_equal_approx(volume_reload.sfx_volume, 0.61), "Master and SFX sliders persist volume preferences")
	volume_reload.free()
	settings_manager.set_text_size(old_text_size)
	settings_manager.set_reduced_motion(old_reduced_motion)
	settings_manager.set_master_volume(old_master_volume)
	settings_manager.set_sfx_volume(old_sfx_volume)
	var replay_button := _find_button(menu, "Replay Captain's Briefing")
	if replay_button != null:
		replay_button.pressed.emit()
	await process_frame
	_check(menu.find_child("CaptainBriefingContent", true, false) is VBoxContainer, "Settings replay action reopens the briefing")
	var close_modal := _find_button(menu, "Close")
	if close_modal != null:
		close_modal.pressed.emit()
	await process_frame
	_check(settings_manager.briefing_seen, "Replayed briefing is dismissible and remains marked seen")
	close_modal = _find_button(menu, "Close")
	if close_modal != null:
		close_modal.pressed.emit()
	await process_frame
	var character_button := menu.find_child("SelectCharacterHotspot", true, false) as Button
	if character_button != null:
		character_button.pressed.emit()
	await process_frame
	var choose_captain := _find_button(menu, "Choose")
	if choose_captain != null:
		choose_captain.pressed.emit()
	await process_frame
	_check(player.captain_background == "navigator", "Select Character persists the Navigator background choice")
	close_modal = _find_button(menu, "Close")
	if close_modal != null:
		close_modal.pressed.emit()
	var journal_button := menu.find_child("JournalHotspot", true, false) as Button
	if journal_button != null:
		journal_button.pressed.emit()
	await process_frame
	var journal_panel: Node = menu.find_child("MenuModal", true, false)
	var journal_text_found: bool = false
	if journal_panel != null:
		for label_node in journal_panel.find_children("*", "Label", true, false):
			if str((label_node as Label).text).contains("Voyages started"):
				journal_text_found = true
	_check(journal_text_found, "Captain's Journal shows lifetime voyage statistics")
	close_modal = _find_button(menu, "Close")
	if close_modal != null:
		close_modal.pressed.emit()
	if start_button != null:
		start_button.pressed.emit()
	await create_timer(0.45).timeout
	await process_frame
	var home: Node = current_scene
	_check(home != null and home.scene_file_path == "res://scenes/home_port.tscn", "Start Voyage transitions to Home Port")
	if home == null:
		quit(1)
		return
	_check(str(home.get("_selected_tab")) == "Chart Table", "Start Voyage opens Chart Table tab")
	for tab_text in ["Bank", "Shipyard", "Market", "Chart Table", "Bounty Board", "Crew Roster"]:
		_check(_find_button(home, tab_text) != null, "Home Port tab exists: " + tab_text)
	var bounty_button := _find_button(home, "Bounty Board")
	if bounty_button != null:
		bounty_button.pressed.emit()
	await process_frame
	var bounty_content := home.find_child("BountyBoardContent", true, false) as Control
	_check(bounty_content != null and bounty_content.get_child_count() >= 3, "Bounty Board renders three active contracts")
	var market_button := _find_button(home, "Market")
	if market_button != null:
		market_button.pressed.emit()
	await process_frame
	_check(str(home.get("_selected_tab")) == "Market", "Market tab selection works")
	_check(_find_button(home, "Buy 1") != null and _find_button(home, "Buy 5") != null, "Market purchase buttons render")
	var buy_one := _find_button(home, "Buy 1")
	if buy_one != null:
		buy_one.pressed.emit()
	await process_frame
	_check(player.bank.get("repair_plank", 0) == 1 and player.gold == 950, "Market UI purchase credits Bank and spends Gold")
	player.buy_market_item("repair_plank", 1)
	player.buy_market_item("cannonball", 10)
	var provision_result: Dictionary = player.buy_market_item("raw_sea_bass", 3)
	_check(provision_result.success, "Provision stock can be purchased through the contract")
	var chart_button := _find_button(home, "Chart Table")
	if chart_button != null:
		chart_button.pressed.emit()
	await process_frame
	var sail_button := _find_button(home, "Set Sail — Tier 1")
	_check(sail_button != null, "Tier 1 Set Sail action renders")
	if sail_button != null:
		sail_button.pressed.emit()
	await process_frame
	var sea: Node = current_scene
	_check(sea != null and sea.scene_file_path == "res://scenes/open_sea.tscn", "Set Sail transitions to Open Sea")
	_check(player.voyage.is_active and player.voyage.tier == 1, "Set Sail initializes Tier 1 voyage")
	var distress_index: int = -1
	for event_index in range(player.voyage.sea_events.size()):
		if str(player.voyage.sea_events[event_index].get("type", "")) == "merchant_distress":
			distress_index = event_index
			break
	if distress_index >= 0 and sea != null:
		player.voyage.pending_event_index = distress_index
		sea.call("_render_state")
	var event_choices := sea.find_child("SeaEventChoices", true, false) as VBoxContainer if sea != null else null
	_check(event_choices != null and event_choices.get_child_count() == 3, "Merchant distress choices render from a typed list without Array assignment errors")
	if distress_index >= 0 and sea != null:
		player.voyage.pending_event_index = -1
		sea.call("_render_state")
	var tactical_badges := sea.find_child("TacticalBadges", true, false) as Label if sea != null else null
	var voyage_resources := sea.find_child("VoyageResources", true, false) as Label if sea != null else null
	_check(tactical_badges != null and tactical_badges.text.contains("Captain perk") and tactical_badges.text.contains("Equipped relics"), "Open Sea HUD displays Captain perk and Relic badges")
	_check(voyage_resources != null and voyage_resources.text.contains("Actions") and voyage_resources.text.contains("Repairs"), "Open Sea HUD displays action and repair resources")
	_check(player.bank.get("repair_plank", 0) == 0 and player.bank.get("cannonball", 0) == 0 and player.bank.get("raw_sea_bass", 0) == 0, "Set Sail deducts tier provisions")
	if sea == null:
		quit(1)
		return
	_check(_find_cell(sea, 1, 0) != null and not _find_cell(sea, 1, 0).disabled, "Chart exposes adjacent tile as tappable")
	_check(_find_cell(sea, 1, 0).custom_minimum_size.x >= 48.0, "Tier 1 chart tiles are enlarged for mobile readability")
	sea.call("_show_tile_inspection", Vector2i(1, 0))
	var inspection_text := sea.find_child("TileInspectionText", true, false) as Label
	_check(inspection_text != null and inspection_text.text.contains("Floating salvage") and inspection_text.text.contains("Copper Ore"), "Tile inspection explains salvage contents and estimated value")
	var icon := sea.find_child("TileInspectionIcon", true, false) as TextureRect
	_check(icon != null and icon.texture != null, "Tile inspection reuses the supplied Copper Ore image")
	sea.find_child("TileInspectionPopup", true, false).visible = false
	game_clock.set_paused(true)
	await process_frame
	var paused_position: Vector2i = player.voyage.ship_position
	var paused_move: Dictionary = player.move_open_sea_one_tile(Vector2i.RIGHT)
	_check(not paused_move.success and player.voyage.ship_position == paused_position, "Suspension pause rejects movement without changing position")
	_check(_find_cell(sea, 1, 0).disabled, "Suspension pause disables chart input")
	game_clock.set_paused(false)
	await process_frame
	var salvage_cell := _find_cell(sea, 1, 0)
	if salvage_cell != null:
		salvage_cell.pressed.emit()
	await process_frame
	_check(player.voyage.ship_position == Vector2i(1, 0), "One chart input advances exactly one tile")
	_check(player.voyage.salvage_collected and player.voyage.ship_cargo.size() == 1 and player.voyage.ship_cargo[0].item_id == "copper_ore" and player.voyage.ship_cargo[0].qty == 3, "Salvage tile grants 3 Copper Ore to ship cargo")
	var event_feed := sea.find_child("VoyageEventFeed", true, false) as Label
	_check(event_feed != null and event_feed.text.contains("Salvage"), "Voyage event feed shows recent loot pickup")
	var voyage_snapshot: Dictionary = player.serialize()
	player.deserialize(voyage_snapshot)
	_check(player.voyage.is_active and player.voyage.ship_position == Vector2i(1, 0) and player.voyage.hazards == voyage_snapshot.voyage.hazards and player.voyage.exploration_sites == voyage_snapshot.voyage.exploration_sites and player.voyage.ship_cargo.size() == 1 and player.voyage.ship_cargo[0].qty == 3, "Active position, hazards, sites, and cargo round-trip through PlayerData save/reload")
	# Clear hazards after verifying their save contract so the extraction-route assertion is deterministic.
	player.voyage.hazards.clear()
	var gold_before_extraction: int = player.gold
	for x in range(2, 10):
		var cell := _find_cell(sea, x, 0)
		if cell != null:
			cell.pressed.emit()
		await process_frame
	for y in range(1, 10):
		var cell := _find_cell(sea, 9, y)
		if cell != null:
			cell.pressed.emit()
		await process_frame
	await create_timer(0.45).timeout
	await process_frame
	var returned_home: Node = current_scene
	_check(returned_home != null and returned_home.scene_file_path == "res://scenes/home_port.tscn", "Safe extraction returns to Home Port")
	_check(not player.voyage.is_active and player.bank.get("copper_ore", 0) == 3, "Safe extraction banks all 3 Copper Ore")
	_check(player.gold > gold_before_extraction, "Safe extraction awards guaranteed recovery-plus-profit Gold")
	if returned_home != null:
		var status_label := returned_home.get("_status") as Label
		_check(status_label != null and status_label.text.contains("Extraction banked"), "Home Port displays extraction outcome")
	# A direct reef collision validates sinking without any wind-direction dependency.
	var retained_ship_id: String = player.active_ship_id
	player.voyage.start_new_voyage(1, 7, retained_ship_id)
	player.voyage.current_hull_hp = 25
	player.voyage.hazards.clear()
	player.voyage.hazards.append({"id": "test_reef", "type": "reef", "position": [1, 0], "damage": 25})
	player.voyage.ship_cargo.append({"item_id": "iron_bar", "qty": 2})
	var sink_result: Dictionary = player.move_open_sea_one_tile(Vector2i.RIGHT)
	_check(sink_result.success and sink_result.sunk and sink_result.hull_damage == 25, "Reef collision deals fixed 25 hull damage and sinks at zero HP")
	_check(not player.voyage.is_active and player.voyage.ship_cargo.is_empty() and player.active_ship_id == retained_ship_id, "Sinking loses cargo while retaining the ship tier")
	var menu_button := _find_button(returned_home, "Main Menu") if returned_home != null else null
	if menu_button != null:
		menu_button.pressed.emit()
	await create_timer(0.35).timeout
	await process_frame
	var returned_menu: Node = current_scene
	_check(returned_menu != null and returned_menu.scene_file_path == "res://scenes/main_menu.tscn", "Home Port returns to Main Menu")
	var navigate_button := returned_menu.find_child("NavigateHotspot", true, false) as Button if returned_menu != null else null
	if navigate_button != null:
		navigate_button.pressed.emit()
	await create_timer(0.35).timeout
	await process_frame
	var bank_scene: Node = current_scene
	_check(bank_scene != null and str(bank_scene.get("_selected_tab")) == "Bank", "Navigate opens Home Port Bank")
	player.add_to_backpack("copper_ore", 2)
	var deposit_button := _find_button(bank_scene, "Deposit 1")
	if deposit_button != null:
		deposit_button.pressed.emit()
	await process_frame
	_check(player.bank.get("copper_ore", 0) == 4 and player.backpack.size() == 1, "Bank UI deposits one item alongside extracted loot")
	var withdraw_button := _find_button(bank_scene, "Withdraw 1")
	if withdraw_button != null:
		withdraw_button.pressed.emit()
	await process_frame
	_check(int(player.bank.get("copper_ore", 0)) == 3 and player.backpack.size() == 2, "Bank UI withdraws one banked item")
	var back_to_menu := _find_button(bank_scene, "Main Menu")
	if back_to_menu != null:
		back_to_menu.pressed.emit()
	await create_timer(0.35).timeout
	await process_frame
	var reset_menu: Node = current_scene
	var reset_settings := reset_menu.find_child("SettingsHotspot", true, false) as Button if reset_menu != null else null
	if reset_settings != null:
		reset_settings.pressed.emit()
	await process_frame
	var reset_button := _find_button(reset_menu, "Reset Save Data…")
	if reset_button != null:
		reset_button.pressed.emit()
	await process_frame
	_check(reset_menu.find_child("ConfirmResetSaveButton", true, false) is Button, "Reset Save Data opens a separate confirmation step")
	var gold_before_cancel: int = player.gold
	var cancel_reset := _find_button(reset_menu, "Cancel")
	if cancel_reset != null:
		cancel_reset.pressed.emit()
	await process_frame
	_check(player.gold == gold_before_cancel and settings_manager.briefing_seen, "Cancel leaves save progress and Settings untouched")
	reset_settings = reset_menu.find_child("SettingsHotspot", true, false) as Button
	if reset_settings != null:
		reset_settings.pressed.emit()
	await process_frame
	reset_button = _find_button(reset_menu, "Reset Save Data…")
	if reset_button != null:
		reset_button.pressed.emit()
	await process_frame
	var confirm_reset := reset_menu.find_child("ConfirmResetSaveButton", true, false) as Button
	if confirm_reset != null:
		confirm_reset.pressed.emit()
	await process_frame
	_check(player.gold == 1000 and player.career_stats.voyages_started == 0 and not player.voyage.is_active, "Confirmed reset clears voyage, currency, and Journal save data")
	_check(settings_manager.briefing_seen, "Confirmed save reset preserves briefing and other separate Settings preferences")
	settings_manager.set_briefing_seen(old_briefing_seen)
	saves.wipe_save()
	if _failures == 0:
		print("Stage 8 UI smoke tests passed.")
		quit(0)
	else:
		push_error("%d Stage 8 UI smoke test(s) failed." % _failures)
		quit(1)
