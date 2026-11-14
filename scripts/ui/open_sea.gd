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
var _explore_button: Button
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
	bg.color = Color("#101820")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "OPEN SEA  /  TIER %d" % PlayerData.voyage.tier
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_position_label = _label("Position: —", 18)
	header.add_child(_position_label)
	layout.add_child(header)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	layout.add_child(content)
	var chart_panel := PanelContainer.new()
	chart_panel.custom_minimum_size = Vector2(510, 0)
	content.add_child(chart_panel)
	var chart_box := VBoxContainer.new()
	chart_box.add_theme_constant_override("separation", 7)
	chart_panel.add_child(chart_box)
	chart_box.add_child(_label("CHART  ·  tap any highlighted destination", 16))
	_grid = GridContainer.new()
	_grid.columns = VoyageState.CHART_SIZE
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	chart_box.add_child(_grid)
	chart_box.add_child(_label("S Ship  ! Reef  M Mine  O Obstacle  C Salvage  I Island  W Wreck  X Extraction", 14))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 11)
	content.add_child(details)
	_movement_label = _label("Movement range: —", 19)
	details.add_child(_movement_label)
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
	_site_label = _label("No exploration site under the ship.", 16)
	_site_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_site_label)
	_explore_button = Button.new()
	_explore_button.custom_minimum_size = Vector2(0, 58)
	_explore_button.pressed.connect(_on_explore_pressed)
	details.add_child(_explore_button)
	var rules := _label("Hazards shift toward you every few action ticks; higher voyage tiers add more hazards and increase drift frequency. Anchor on islands for 2 ticks or shipwrecks for 3 ticks to claim their guaranteed cargo. Extract at X to bank cargo and receive a Gold payout covering provisions plus a 25% margin.", 16)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(rules)
	_status_label = _label("", 16)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_status_label)

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
	var max_hp: int = maxi(1, int(ship_specs.get("max_hp", 100)))
	_position_label.text = "Position: (%d, %d)   Actions %d" % [voyage.ship_position.x, voyage.ship_position.y, voyage.step_count]
	var perk_name: String = str(voyage.captain_background).capitalize()
	_movement_label.text = "Movement range: %d tiles per action  ·  %s  ·  %s background" % [voyage.movement_range(), str(ship_specs.get("name", voyage.ship_id)), perk_name]
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
	_status_label.text = _message
	_render_chart()
	SettingsManager.apply_to_tree(self)

func _render_chart() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var voyage: VoyageState = PlayerData.voyage
	for y in range(voyage.chart_size):
		for x in range(voyage.chart_size):
			var tile := Vector2i(x, y)
			var button := Button.new()
			button.name = "Cell_%d_%d" % [x, y]
			button.custom_minimum_size = Vector2(46, 43)
			button.add_theme_font_size_override("font_size", 16)
			var in_range: bool = voyage.can_move_to(tile)
			var is_current: bool = tile == voyage.ship_position
			button.text = _tile_marker(tile, is_current)
			button.tooltip_text = "Tile (%d, %d)%s" % [x, y, " · movement available" if in_range else ""]
			button.disabled = not in_range or GameClock.is_clock_paused()
			if is_current:
				button.modulate = Color("#f3d48b")
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
			_grid.add_child(button)

func _tile_marker(tile: Vector2i, is_current: bool) -> String:
	var voyage: VoyageState = PlayerData.voyage
	if is_current:
		return "S"
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

func _on_tile_pressed(destination: Vector2i) -> void:
	if GameClock.is_clock_paused() or not PlayerData.voyage.is_active:
		return
	var result: Dictionary = PlayerData.move_open_sea_to(destination)
	_message = str(result.get("message", ""))
	if bool(result.get("sunk", false)) or bool(result.get("extracted", false)):
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
