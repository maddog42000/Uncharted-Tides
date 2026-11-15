extends Control

const Constants = preload("res://data/mvp_constants.gd")

var _grid: GridContainer
var _position_label: Label
var _movement_label: Label
var _hull_label: Label
var _hull_bar: ProgressBar
var _cargo_label: Label
var _hazard_label: Label
var _site_label: Label
var _status_label: Label
var _tactical_badges_label: Label
var _resource_badges_label: Label
var _event_feed_label: Label
var _explore_button: Button
var _combat_button: Button
var _repair_button: Button
var _ration_button: Button
var _event_box: VBoxContainer
var _supply_label: Label
var _details_panel: PanelContainer
var _inspect_panel: PanelContainer
var _inspect_icon: TextureRect
var _inspect_label: Label
var _long_press_timer: Timer
var _pressed_tile: Vector2i = Vector2i(-1, -1)
var _long_press_consumed: bool = false
var _combat_mode: bool = false
var _message: String = ""
var _transitioning: bool = false

func _ready() -> void:
	_build_screen()
	PlayerData.state_changed.connect(_on_state_changed)
	GameClock.clock_paused.connect(_on_clock_paused)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	if not PlayerData.voyage.is_active:
		_message = "No active voyage. Returning to Home Port."
		call_deferred("_return_to_port", _message)
	else:
		_message = "Highlighted tiles are within your ship's movement range. Wind never blocks a course."
	_render_state()

func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#0b1720")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "OPEN SEA  ·  TIER %d" % PlayerData.voyage.tier
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_position_label = _label("Position: —", 16)
	header.add_child(_position_label)
	var details_button := Button.new()
	details_button.text = "Voyage Info"
	details_button.custom_minimum_size = Vector2(122, 48)
	details_button.pressed.connect(_toggle_details)
	header.add_child(details_button)
	layout.add_child(header)
	_status_label = _label("", 15)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.y = 32
	layout.add_child(_status_label)
	var chart_panel := PanelContainer.new()
	chart_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_panel.add_theme_stylebox_override("panel", _panel_style(Color("#142632"), Color("#39515e")))
	layout.add_child(chart_panel)
	var chart_box := VBoxContainer.new()
	chart_box.add_theme_constant_override("separation", 4)
	chart_panel.add_child(chart_box)
	var chart_title := _label("CHART  ·  tap a reachable tile to sail  ·  hold a tile for details", 15)
	chart_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chart_box.add_child(chart_title)
	var board_center := CenterContainer.new()
	board_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_box.add_child(board_center)
	_grid = GridContainer.new()
	_grid.columns = PlayerData.voyage.chart_size
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	board_center.add_child(_grid)
	var legend := _label("S Ship  ·  ! Reef  ·  M Mine  ·  O Obstacle  ·  C Salvage  ·  I Island  ·  W Wreck  ·  X Harbor  ·  E Event", 13)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chart_box.add_child(legend)
	var commands := HBoxContainer.new()
	commands.add_theme_constant_override("separation", 7)
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(commands)
	_explore_button = Button.new()
	_explore_button.custom_minimum_size = Vector2(0, 54)
	_explore_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_explore_button.pressed.connect(_on_explore_pressed)
	commands.add_child(_explore_button)
	_combat_button = Button.new()
	_combat_button.custom_minimum_size = Vector2(0, 54)
	_combat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_button.pressed.connect(_on_combat_mode_pressed)
	commands.add_child(_combat_button)
	_repair_button = Button.new()
	_repair_button.custom_minimum_size = Vector2(0, 54)
	_repair_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_repair_button.pressed.connect(_on_field_repair_pressed)
	commands.add_child(_repair_button)
	_ration_button = Button.new()
	_ration_button.custom_minimum_size = Vector2(0, 54)
	_ration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ration_button.pressed.connect(_on_ration_pressed)
	commands.add_child(_ration_button)
	_details_panel = PanelContainer.new()
	_details_panel.name = "VoyageDetailsOverlay"
	_details_panel.set_anchors_preset(Control.PRESET_CENTER)
	var viewport_size: Vector2 = get_viewport_rect().size
	_details_panel.custom_minimum_size = Vector2(minf(760.0, viewport_size.x - 28.0), minf(620.0, viewport_size.y - 28.0))
	_details_panel.position = -_details_panel.custom_minimum_size * 0.5
	_details_panel.visible = false
	_details_panel.z_index = 10
	_details_panel.add_theme_stylebox_override("panel", _panel_style(Color("#12232d"), Color("#7d9aa5")))
	add_child(_details_panel)
	var details_root := VBoxContainer.new()
	details_root.add_theme_constant_override("separation", 8)
	_details_panel.add_child(details_root)
	var details_header := HBoxContainer.new()
	var details_title := _label("VOYAGE STATUS & LOG", 20)
	details_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_header.add_child(details_title)
	var close_details := Button.new()
	close_details.text = "Close"
	close_details.custom_minimum_size = Vector2(100, 48)
	close_details.pressed.connect(_toggle_details)
	details_header.add_child(close_details)
	details_root.add_child(details_header)
	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_root.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)
	_movement_label = _label("Movement range: —", 19)
	details.add_child(_movement_label)
	_tactical_badges_label = _label("Captain perk: — · Relics: —", 15)
	_tactical_badges_label.name = "TacticalBadges"
	_tactical_badges_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_tactical_badges_label)
	_resource_badges_label = _label("Actions · Ammo · Repairs · Rations", 15)
	_resource_badges_label.name = "VoyageResources"
	details.add_child(_resource_badges_label)
	_hull_label = _label("Hull: —", 19)
	details.add_child(_hull_label)
	_hull_bar = ProgressBar.new()
	_hull_bar.custom_minimum_size = Vector2(0, 27)
	_hull_bar.show_percentage = false
	details.add_child(_hull_bar)
	_cargo_label = _label("Ship cargo: —", 16)
	details.add_child(_cargo_label)
	_hazard_label = _label("Hazards: —", 16)
	_hazard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_hazard_label)
	_event_feed_label = _label("VOYAGE LOG\nNo recent events.", 14)
	_event_feed_label.name = "VoyageEventFeed"
	_event_feed_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_feed_label.custom_minimum_size.y = 110
	details.add_child(_event_feed_label)
	_site_label = _label("No exploration site under the ship.", 16)
	_site_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_site_label)
	_supply_label = _label("Field stores: —", 15)
	details.add_child(_supply_label)
	var rules := _label("Tier 3 Sea Monster and Tier 4 Dreadnought Captain bosses drop unique relics. Repair planks restore up to 40 hull; each ration gives +1 range for your next move. Supply actions cost a turn. Safe extraction covers all launch provisions plus 25%.", 15)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(rules)
	_event_box = VBoxContainer.new()
	_event_box.name = "SeaEventChoices"
	details.add_child(_event_box)
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = 0.55
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	_inspect_panel = PanelContainer.new()
	_inspect_panel.name = "TileInspectionPopup"
	_inspect_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_inspect_panel.position = Vector2(-190, 60)
	_inspect_panel.custom_minimum_size = Vector2(380, 170)
	_inspect_panel.visible = false
	_inspect_panel.z_index = 20
	_inspect_panel.add_theme_stylebox_override("panel", _panel_style(Color("#12232d"), Color("#d7bf83")))
	add_child(_inspect_panel)
	var inspect_row := HBoxContainer.new()
	inspect_row.add_theme_constant_override("separation", 12)
	_inspect_panel.add_child(inspect_row)
	_inspect_icon = TextureRect.new()
	_inspect_icon.name = "TileInspectionIcon"
	_inspect_icon.custom_minimum_size = Vector2(88, 88)
	_inspect_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inspect_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspect_row.add_child(_inspect_icon)
	var inspect_column := VBoxContainer.new()
	inspect_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspect_row.add_child(inspect_column)
	_inspect_label = _label("", 16)
	_inspect_label.name = "TileInspectionText"
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_column.add_child(_inspect_label)
	var close_inspect := Button.new()
	close_inspect.text = "Dismiss"
	close_inspect.custom_minimum_size = Vector2(0, 44)
	close_inspect.pressed.connect(func(): _inspect_panel.visible = false)
	inspect_column.add_child(close_inspect)

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _toggle_details() -> void:
	_details_panel.visible = not _details_panel.visible
	_inspect_panel.visible = false

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _render_state() -> void:
	if not is_instance_valid(_grid) or not PlayerData.voyage.is_active:
		return
	var voyage: VoyageState = PlayerData.voyage
	var ship_specs: Dictionary = Constants.SHIPS.get(voyage.ship_id, {})
	var max_hp: int = voyage.max_hull_hp()
	_position_label.text = "Position: (%d, %d)   Actions %d" % [voyage.ship_position.x, voyage.ship_position.y, voyage.step_count]
	var perk_name: String = str(voyage.captain_background).capitalize()
	_movement_label.text = "Movement %d  ·  Cannons %d damage  ·  %s" % [voyage.movement_range(), voyage.cannon_damage(), str(ship_specs.get("name", voyage.ship_id))]
	var perk_text: String = "+10% extraction Gold" if voyage.captain_background == "merchant" else ("+1 base move range" if voyage.captain_background == "navigator" else "20% less hazard damage")
	var relic_names: Array[String] = []
	for relic_id in voyage.relics:
		relic_names.append(str(Constants.ITEMS.get(relic_id, {}).get("name", relic_id)))
	_tactical_badges_label.text = "Captain perk: %s · %s\nEquipped relics: %s" % [perk_name, perk_text, ", ".join(PackedStringArray(relic_names)) if not relic_names.is_empty() else "None"]
	_resource_badges_label.text = "Actions %d  ·  Ammo %d  ·  Repairs %d  ·  Rations %d" % [voyage.step_count, voyage.ammunition, voyage.repair_stock, voyage.ration_stock]
	var recent_events: Array[String] = []
	for event_index in range(maxi(0, voyage.event_feed.size() - 4), voyage.event_feed.size()):
		recent_events.append("• " + voyage.event_feed[event_index])
	_event_feed_label.text = "VOYAGE LOG\n" + ("\n".join(PackedStringArray(recent_events)) if not recent_events.is_empty() else "No recent events.")
	_hull_label.text = "Hull: %d / %d HP" % [voyage.current_hull_hp, max_hp]
	_hull_bar.max_value = max_hp
	_hull_bar.value = voyage.current_hull_hp
	_cargo_label.text = "Ship cargo: %d / %d slots%s" % [voyage.ship_cargo.size(), int(ship_specs.get("cargo_slots", 8)), "  ·  " + _cargo_summary() if not voyage.ship_cargo.is_empty() else ""]
	var hazard_counts: Dictionary = {}
	for hazard in voyage.hazards:
		var kind: String = str(hazard.get("type", "hazard"))
		hazard_counts[kind] = int(hazard_counts.get(kind, 0)) + 1
	_hazard_label.text = "Tier %d risk: %d hazards · %s drift every %d action(s)." % [voyage.tier, voyage.hazards.size(), _dictionary_summary(hazard_counts), int(Constants.HAZARD_DRIFT_EVERY_TURNS.get(voyage.tier, 5))]
	var site: Dictionary = voyage.current_site()
	if site.is_empty():
		_site_label.text = "No exploration site under the ship."
		_explore_button.text = "Anchor at an island or wreck"
		_explore_button.disabled = true
	else:
		var required: int = int(site.get("required_ticks", 1))
		var work: int = int(site.get("work_ticks", 0))
		var label: String = "Island cove" if str(site.get("type", "")) == "island" else "Shipwreck"
		_site_label.text = "%s · exploration %d/%d action ticks%s" % [label, work, required, " · scavenged" if bool(site.get("completed", false)) else ""]
		_explore_button.text = "Site scavenged" if bool(site.get("completed", false)) else "Work 1 anchored tick  (%d remaining)" % (required - work)
		_explore_button.disabled = bool(site.get("completed", false)) or GameClock.is_clock_paused()
	_combat_button.text = "Target enemy: ON · tap highlighted enemy" if _combat_mode else "Target enemy: OFF · cannon range %d" % Constants.COMBAT_RANGE
	_combat_button.disabled = voyage.ammunition <= 0 or GameClock.is_clock_paused()
	_supply_label.text = "Field stores: %d repair plank(s) · %d emergency ration(s)" % [voyage.repair_stock, voyage.ration_stock]
	_repair_button.text = "Field repair (+%d hull)" % Constants.FIELD_REPAIR_HP
	_repair_button.disabled = voyage.repair_stock <= 0 or voyage.current_hull_hp >= max_hp or GameClock.is_clock_paused()
	_ration_button.text = "Emergency ration (+1 tile next move)"
	_ration_button.disabled = voyage.ration_stock <= 0 or voyage.ration_burst_actions > 0 or GameClock.is_clock_paused()
	_status_label.text = _message
	_render_event_choices()
	if voyage.pending_event_index >= 0:
		_details_panel.visible = true
	_render_chart()
	SettingsManager.apply_to_tree(self)

func _render_event_choices() -> void:
	for child in _event_box.get_children(): child.queue_free()
	var event: Dictionary = PlayerData.voyage.current_sea_event()
	if event.is_empty(): return
	var kind: String = str(event.type)
	var options: Array[String] = []
	if kind == "merchant_distress":
		options.append_array(["rescue", "salvage", "pass"])
	elif kind == "tailwind_current":
		options.append("ride")
	else:
		options.append("shelter")
	for option in options:
		var button := Button.new()
		button.text = option.capitalize()
		button.custom_minimum_size.y = 58
		button.pressed.connect(func(): _message = str(PlayerData.resolve_sea_event(option).get("message", "")); _render_state())
		_event_box.add_child(button)

func _render_chart() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var voyage: VoyageState = PlayerData.voyage
	_grid.columns = voyage.chart_size
	var viewport_size: Vector2 = get_viewport_rect().size
	var cell_px: int = clampi(floori(minf((viewport_size.x - 36.0) / float(voyage.chart_size), (viewport_size.y - 184.0) / float(voyage.chart_size))), 20, 64)
	for y in range(voyage.chart_size):
		for x in range(voyage.chart_size):
			var tile := Vector2i(x, y)
			var button := Button.new()
			button.name = "Cell_%d_%d" % [x, y]
			button.custom_minimum_size = Vector2(cell_px, cell_px)
			button.add_theme_font_size_override("font_size", clampi(cell_px / 3, 11, 21))
			var enemy: Dictionary = voyage.enemy_at(tile)
			var in_range: bool = voyage.can_move_to(tile)
			var targetable: bool = voyage.can_fire_at(tile)
			var is_current: bool = tile == voyage.ship_position
			button.text = _tile_marker(tile, is_current)
			if voyage.event_at(tile) >= 0: button.text = "E"
			if not enemy.is_empty():
				button.text = "B" if bool(enemy.get("boss", false)) else ("P" if str(enemy.get("type", "")).contains("sloop") else "G")
			button.tooltip_text = "Tile (%d, %d)%s" % [x, y, " · movement available" if in_range else ""]
			button.disabled = GameClock.is_clock_paused()
			if is_current:
				button.modulate = Color("#f3d48b")
			elif not enemy.is_empty():
				button.modulate = Color("#ff6961") if targetable else Color("#8f6262")
			elif _combat_mode and targetable:
				button.modulate = Color("#ffb347")
			elif voyage.event_at(tile) >= 0:
				button.modulate = Color("#55d6be")
			elif tile == voyage.extraction_position:
				button.modulate = Color("#96d6ad")
			elif not voyage.hazard_at(tile).is_empty():
				button.modulate = Color("#ff8c73")
			elif _site_at(tile):
				button.modulate = Color("#c5a6e8")
			elif tile == voyage.salvage_position and not voyage.salvage_collected:
				button.modulate = Color("#84c4ee")
			elif in_range:
				button.modulate = Color("#b8d88f")
			button.pressed.connect(_on_tile_pressed.bind(tile))
			button.button_down.connect(_on_tile_hold_started.bind(tile))
			button.button_up.connect(_on_tile_hold_released)
			_grid.add_child(button)

func _tile_marker(tile: Vector2i, is_current: bool) -> String:
	var voyage: VoyageState = PlayerData.voyage
	if is_current:
		return "S"
	var enemy: Dictionary = voyage.enemy_at(tile)
	if not enemy.is_empty(): return "B" if bool(enemy.get("boss", false)) else ("P" if str(enemy.get("type", "")).contains("sloop") else "G")
	if tile == voyage.extraction_position:
		return "X"
	if tile == voyage.salvage_position and not voyage.salvage_collected:
		return "C"
	for site in voyage.exploration_sites:
		if _site_position(site) == tile:
			return "I" if str(site.get("type", "")) == "island" else "W"
	var hazard: Dictionary = voyage.hazard_at(tile)
	if not hazard.is_empty():
		match str(hazard.get("type", "")):
			"reef": return "!"
			"mine": return "M"
			_: return "O"
	return "·"

func _site_at(tile: Vector2i) -> bool:
	for site in PlayerData.voyage.exploration_sites:
		if _site_position(site) == tile:
			return true
	return false

func _site_position(site: Dictionary) -> Vector2i:
	var coordinates: Array = site.get("position", [0, 0])
	return Vector2i(int(coordinates[0]), int(coordinates[1]))

func _on_tile_hold_started(tile: Vector2i) -> void:
	_pressed_tile = tile
	_long_press_consumed = false
	_long_press_timer.start()

func _on_tile_hold_released() -> void:
	_long_press_timer.stop()

func _on_long_press_timeout() -> void:
	if _pressed_tile.x < 0:
		return
	_long_press_consumed = true
	_show_tile_inspection(_pressed_tile)

func _show_tile_inspection(tile: Vector2i) -> void:
	_inspect_label.text = _tile_inspection_text(tile)
	_inspect_icon.texture = _local_tile_icon(tile)
	_inspect_panel.visible = true

func _tile_inspection_text(tile: Vector2i) -> String:
	var voyage: VoyageState = PlayerData.voyage
	var intro: String = "Tile (%d, %d)\n" % [tile.x, tile.y]
	if tile == voyage.ship_position:
		return intro + "Your %s is here. Hull: %d/%d HP." % [str(Constants.SHIPS.get(voyage.ship_id, {}).get("name", voyage.ship_id)), voyage.current_hull_hp, voyage.max_hull_hp()]
	var enemy: Dictionary = voyage.enemy_at(tile)
	if not enemy.is_empty():
		var enemy_name: String = str(enemy.get("type", "enemy")).replace("_", " ").capitalize()
		var text: String = "%s\nHull %d/%d · cannon range %d\nDefeat reward: %d Gold" % [enemy_name, int(enemy.get("hull", 0)), int(enemy.get("max_hull", 0)), Constants.COMBAT_RANGE, int(enemy.get("loot_gold", 0))]
		if bool(enemy.get("boss", false)):
			text += "\nBoss reward: unique Captain Relic"
		return intro + text
	var hazard: Dictionary = voyage.hazard_at(tile)
	if not hazard.is_empty():
		var kind: String = str(hazard.get("type", "obstacle")).capitalize()
		var damage: int = int(hazard.get("damage", 0))
		return intro + "%s hazard\nCollision damage: %d hull HP%s\nHazards drift every %d actions." % [kind, damage, " (Shipwright reduces this by 20%)" if voyage.captain_background == "shipwright" else "", int(Constants.HAZARD_DRIFT_EVERY_TURNS.get(voyage.tier, 5))]
	for site in voyage.exploration_sites:
		if _site_position(site) == tile:
			var item_id: String = str(site.get("reward_item", ""))
			var qty: int = int(site.get("reward_qty", 0))
			var site_name: String = "Island cove" if str(site.get("type", "")) == "island" else "Shipwreck"
			var value: int = int(Constants.ITEM_SELL_PRICES.get(item_id, 0)) * qty
			var state_text: String = "Already scavenged" if bool(site.get("completed", false)) else "Anchor for %d action ticks" % int(site.get("required_ticks", 1))
			return intro + "%s\n%s\nReward: %d %s · estimated sale value %d Gold." % [site_name, state_text, qty, str(Constants.ITEMS.get(item_id, {}).get("name", item_id)), value]
	if tile == voyage.salvage_position and not voyage.salvage_collected:
		var qty: int = 3 + (1 if voyage.crew.has("quartermaster") else 0)
		return intro + "Floating salvage\nRecover %d Copper Ore · estimated sale value %d Gold." % [qty, qty * int(Constants.ITEM_SELL_PRICES.get("copper_ore", 0))]
	if tile == voyage.extraction_position:
		return intro + "Safe harbor\nReach this tile to extract and bank your cargo. Guaranteed payout: %d Gold, plus cargo and any bonuses." % voyage.extraction_gold_reward
	var event_index: int = voyage.event_at(tile)
	if event_index >= 0:
		var sea_event: Dictionary = voyage.sea_events[event_index]
		match str(sea_event.get("type", "")):
			"merchant_distress":
				return intro + "Merchant distress signal\nRescue for %d Gold, salvage for %d Copper Ore, or pass." % [150 * voyage.tier, voyage.tier + 1]
			"tailwind_current":
				return intro + "Tailwind current\nRide it to gain +1 tile of movement on your next move."
			"fog_squall":
				return intro + "Fog squall\nShelter here to reduce enemy aggression for several actions."
	return intro + ("Reachable open water · movement available." if voyage.can_move_to(tile) else "Open water · outside current movement range.")

func _local_tile_icon(tile: Vector2i) -> Texture2D:
	var voyage: VoyageState = PlayerData.voyage
	var asset_id: String = ""
	var enemy: Dictionary = voyage.enemy_at(tile)
	if not enemy.is_empty():
		var enemy_type: String = str(enemy.get("type", ""))
		if enemy_type.contains("sloop"):
			asset_id = "sloop_icon"
		elif enemy_type.contains("galleon"):
			asset_id = "galleon_icon"
		elif enemy_type.contains("dreadnought"):
			asset_id = "manowar_icon"
	else:
		for site in voyage.exploration_sites:
			if _site_position(site) == tile:
				asset_id = str(site.get("reward_item", ""))
				break
		if asset_id.is_empty() and tile == voyage.salvage_position and not voyage.salvage_collected:
			asset_id = "copper_ore"
			if asset_id.is_empty() and tile == voyage.extraction_position:
				asset_id = "icon_chart"
			if asset_id.is_empty() and tile == voyage.ship_position:
				asset_id = str({"wooden_sloop": "sloop_icon", "oak_brigantine": "brigantine_icon", "mahogany_galleon": "galleon_icon", "dragonwood_man_owar": "manowar_icon"}.get(voyage.ship_id, "sloop_icon"))
	var filename: String = str(AssetManager.ASSET_MAPPING.get(asset_id, ""))
	if filename.is_empty() or not ResourceLoader.exists("res://" + filename):
		return null
	return load("res://" + filename) as Texture2D

func _on_tile_pressed(destination: Vector2i) -> void:
	if _long_press_consumed:
		_long_press_consumed = false
		_pressed_tile = Vector2i(-1, -1)
		return
	_long_press_timer.stop()
	_pressed_tile = Vector2i(-1, -1)
	if GameClock.is_clock_paused() or not PlayerData.voyage.is_active:
		return
	_inspect_panel.visible = false
	if _combat_mode and not PlayerData.voyage.can_fire_at(destination):
		_message = "Tap a highlighted enemy within cannon range, or turn targeting off."
		_render_state()
		return
	if not _combat_mode and not PlayerData.voyage.can_move_to(destination):
		_message = "Choose one of the highlighted tiles within movement range. Hold any tile for details."
		_render_state()
		return
	var result: Dictionary = PlayerData.fire_cannons_at(destination) if _combat_mode else PlayerData.move_open_sea_to(destination)
	if _combat_mode: _combat_mode = false
	_message = str(result.get("message", ""))
	if bool(result.get("sunk", false)) or bool(result.get("extracted", false)):
		_return_to_port(_message)
		return
	_render_state()

func _on_combat_mode_pressed() -> void:
	_combat_mode = not _combat_mode
	_message = "Tap a highlighted enemy vessel to fire one cannonball; surviving enemies retaliate." if _combat_mode else "Targeting cancelled."
	_render_state()

func _on_field_repair_pressed() -> void:
	var result: Dictionary = PlayerData.use_field_repair()
	_message = str(result.get("message", ""))
	if bool(result.get("sunk", false)):
		_return_to_port(_message)
		return
	_render_state()

func _on_ration_pressed() -> void:
	var result: Dictionary = PlayerData.use_emergency_ration()
	_message = str(result.get("message", ""))
	if bool(result.get("sunk", false)):
		_return_to_port(_message)
		return
	_render_state()

func _on_explore_pressed() -> void:
	if GameClock.is_clock_paused() or not PlayerData.voyage.is_active:
		return
	var result: Dictionary = PlayerData.advance_exploration_tick()
	_message = str(result.get("message", ""))
	if bool(result.get("sunk", false)):
		_return_to_port(_message)
		return
	_render_state()

func _dictionary_summary(counts: Dictionary) -> String:
	var pieces: Array[String] = []
	for key in counts:
		pieces.append("%s ×%d" % [str(key).capitalize(), int(counts[key])])
	return ", ".join(PackedStringArray(pieces)) if not pieces.is_empty() else "none"

func _cargo_summary() -> String:
	var counts: Dictionary = {}
	for item in PlayerData.voyage.ship_cargo:
		var item_id: String = str(item.get("item_id", ""))
		counts[item_id] = int(counts.get(item_id, 0)) + maxi(1, int(item.get("qty", 1)))
	var pieces: Array[String] = []
	for item_id in counts:
		pieces.append("%s ×%d" % [str(Constants.ITEMS.get(item_id, {}).get("name", item_id)), int(counts[item_id])])
	return ", ".join(PackedStringArray(pieces))

func _on_state_changed() -> void:
	if PlayerData.voyage.is_active:
		_render_state()

func _on_clock_paused(paused: bool) -> void:
	_message = "Voyage paused while the app is suspended." if paused else "Voyage resumed. Highlighted tiles are ready."
	_render_state()

func _on_settings_changed() -> void:
	SettingsManager.apply_to_tree(self)

func _return_to_port(message: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().root.set_meta("home_port_return_message", message)
	AssetManager.request_texture("loading_screen", _fade_to_port)

func _fade_to_port(texture: Texture2D) -> void:
	var duration: float = SettingsManager.transition_duration(0.22)
	if duration <= 0.0:
		get_tree().change_scene_to_file("res://scenes/home_port.tscn")
		return
	var transition := TextureRect.new()
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	transition.texture = texture if texture != null else load("res://assets/screens/loading_screen.jpg") as Texture2D
	transition.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(transition)
	var tween := create_tween()
	tween.tween_property(transition, "modulate:a", 1.0, duration)
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://scenes/home_port.tscn"))
