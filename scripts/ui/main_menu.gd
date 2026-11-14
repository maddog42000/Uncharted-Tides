extends Control

const Constants = preload("res://data/mvp_constants.gd")

const MENU_ART_SIZE := Vector2(1375.0, 768.0)
const MENU_VISIBLE_REGION := Rect2(0.0, 0.0, 1375.0, 640.0) # Excludes the embedded conflicting bottom strip.
const CAPTAIN_OPTIONS: Dictionary = {
	"merchant": {"name": "Merchant", "perk": "+10% Gold from successful extraction.", "style": "A practiced trader who knows the value of every recovered crate."},
	"navigator": {"name": "Navigator", "perk": "+1 movement tile per action.", "style": "A sure-handed chart reader who finds the quickest route through danger."},
	"shipwright": {"name": "Shipwright", "perk": "Hazard hull damage reduced by 20%.", "style": "A master of hulls and rigging, prepared to limit damage at sea."}
}
var _background: TextureRect
var _modal_layer: Control
var _hotspots: Array[Button] = []
var _transitioning: bool = false

func _ready() -> void:
	_build_screen()
	resized.connect(_layout_hotspots)
	call_deferred("_layout_hotspots")
	SettingsManager.settings_changed.connect(_apply_settings)
	AssetManager.request_texture("main_menu", _on_menu_art_loaded)
	_apply_settings()

func _build_screen() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color("#10151c")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	_background = TextureRect.new()
	_background.name = "MenuArtwork"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_add_hotspot("Settings", Rect2(96, 126, 314, 78), _show_settings)
	_add_hotspot("Select Character", Rect2(94, 204, 367, 78), _show_character)
	_add_hotspot("Journal", Rect2(982, 125, 309, 78), _show_journal)
	_add_hotspot("Navigate", Rect2(949, 202, 356, 78), _open_home_bank)
	_add_hotspot("Start Voyage", Rect2(499, 299, 376, 179), _open_chart_table)
	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_layer)

func _on_menu_art_loaded(texture: Texture2D) -> void:
	var art: Texture2D = texture
	if art == null:
		art = load("res://assets/screens/main_menu.jpg") as Texture2D
	if art == null:
		_show_message("Artwork unavailable", "The main-menu image could not be loaded. Check the local fallback or network connection.")
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = art
	atlas.region = MENU_VISIBLE_REGION
	_background.texture = atlas

func _add_hotspot(label: String, source_rect: Rect2, callback: Callable) -> void:
	var button := Button.new()
	button.name = label.replace(" ", "") + "Hotspot"
	button.tooltip_text = label
	button.accessibility_name = label
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	button.set_meta("source_rect", source_rect)
	_hotspots.append(button)
	add_child(button)
	_layout_hotspots()

func _layout_hotspots() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var ui_scale: float = minf(size.x / MENU_ART_SIZE.x, size.y / MENU_VISIBLE_REGION.size.y)
	var drawn_size := MENU_VISIBLE_REGION.size * ui_scale
	var offset := (size - drawn_size) * 0.5
	for button in _hotspots:
		if is_instance_valid(button):
			var source_rect: Rect2 = button.get_meta("source_rect")
			button.position = offset + source_rect.position * ui_scale
			button.size = source_rect.size * ui_scale

func _show_settings() -> void:
	var box := _begin_modal("Settings", "Display, accessibility, and audio preferences are saved on this device.", Vector2(600, 470))
	var size_row := HBoxContainer.new()
	var size_label := _modal_label("Text size", 19)
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(size_label)
	var size_picker := OptionButton.new()
	size_picker.name = "TextSizeOption"
	size_picker.custom_minimum_size = Vector2(180, 52)
	for option in SettingsManager.TEXT_SIZE_OPTIONS:
		size_picker.add_item(option)
	size_picker.select(SettingsManager.text_size_index)
	size_picker.item_selected.connect(SettingsManager.set_text_size)
	size_row.add_child(size_picker)
	box.add_child(size_row)
	box.add_child(_make_volume_control("Master volume", SettingsManager.master_volume, SettingsManager.set_master_volume))
	box.add_child(_make_volume_control("SFX volume", SettingsManager.sfx_volume, SettingsManager.set_sfx_volume))
	var motion := CheckButton.new()
	motion.name = "ReducedMotionToggle"
	motion.text = "Reduce screen transitions"
	motion.button_pressed = SettingsManager.reduced_motion
	motion.custom_minimum_size.y = 52
	motion.toggled.connect(SettingsManager.set_reduced_motion)
	box.add_child(motion)
	box.add_child(_modal_label("Reduced motion skips decorative scene fades. Volume sliders update immediately and persist between launches.", 15))
	_finish_modal(box)

func _make_volume_control(title_text: String, volume: float, setter: Callable) -> VBoxContainer:
	var container := VBoxContainer.new()
	var row := HBoxContainer.new()
	var title := _modal_label(title_text, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var amount := _modal_label("%d%%" % roundi(volume * 100.0), 17)
	amount.custom_minimum_size.x = 56
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	container.add_child(row)
	var slider := HSlider.new()
	slider.name = title_text.replace(" ", "") + "Slider"
	slider.accessibility_name = title_text
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = volume
	slider.custom_minimum_size.y = 30
	slider.value_changed.connect(func(value: float):
		amount.text = "%d%%" % roundi(value * 100.0)
		setter.call(value)
	)
	container.add_child(slider)
	return container

func _show_character() -> void:
	var box := _begin_modal("Choose Your Captain", "Select one permanent background perk. You can change it safely in port.", Vector2(720, 480))
	for background_id in ["merchant", "navigator", "shipwright"]:
		var option: Dictionary = CAPTAIN_OPTIONS[background_id]
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 78
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var description := VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.add_child(_modal_label(str(option.name) + "  ·  " + str(option.perk), 18))
		description.add_child(_modal_label(str(option.style), 14))
		row.add_child(description)
		var choose := Button.new()
		choose.text = "Selected" if PlayerData.captain_background == background_id else "Choose"
		choose.disabled = PlayerData.captain_background == background_id or PlayerData.voyage.is_active
		choose.custom_minimum_size = Vector2(120, 54)
		var captured_id: String = background_id
		choose.pressed.connect(func():
			PlayerData.select_captain_background(captured_id)
			_show_character()
		)
		row.add_child(choose)
		box.add_child(card)
	if PlayerData.voyage.is_active:
		box.add_child(_modal_label("Captain backgrounds cannot be changed during an active voyage.", 15))
	_finish_modal(box)

func _show_journal() -> void:
	var box := _begin_modal("Captain's Journal", "Career record · totals persist with your voyage save.", Vector2(600, 500))
	var stats: Dictionary = PlayerData.career_stats
	for entry in [
		["Voyages started", "voyages_started"],
		["Successful extractions", "extractions"],
		["Gold earned", "gold_earned"],
		["Cargo brought home", "cargo_salvaged"]
	]:
		var row := PanelContainer.new()
		var line := HBoxContainer.new()
		var key := _modal_label(str(entry[0]), 19)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(key)
		var value := _modal_label("%s" % int(stats.get(str(entry[1]), 0)), 20)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		row.add_child(line)
		box.add_child(row)
	box.add_child(_modal_label("Sailing Mastery: Level %d / 99" % PlayerData.get_level("Sailing"), 18))
	for milestone in Constants.SAILING_MASTERY_MILESTONES:
		var milestone_level: int = int(milestone.get("level", 0))
		var claimed: bool = PlayerData.sailing_milestones_claimed.has(milestone_level)
		var claim := Button.new()
		claim.text = "Sailing %d · %d Gold · %s" % [milestone_level, int(milestone.get("reward", 0)), "Claimed" if claimed else "Claim"]
		claim.custom_minimum_size.y = 54
		claim.disabled = claimed or PlayerData.get_level("Sailing") < milestone_level or PlayerData.voyage.is_active
		claim.pressed.connect(func(): PlayerData.claim_sailing_milestone(milestone_level); _show_journal())
		box.add_child(claim)
	var cost: Dictionary = PlayerData.prestige_cost()
	box.add_child(_modal_label("Fleet Prestige %d · permanent +%d%% extraction Gold" % [PlayerData.fleet_prestige, PlayerData.fleet_prestige * 2], 16))
	var prestige := Button.new()
	prestige.text = "Prestige · %d Gold + %d Doubloons" % [int(cost.gold), int(cost.doubloons)]
	prestige.custom_minimum_size.y = 58
	prestige.disabled = PlayerData.voyage.is_active or PlayerData.get_level("Sailing") < 99 or PlayerData.gold < int(cost.gold) or PlayerData.doubloons < int(cost.doubloons)
	prestige.pressed.connect(func(): PlayerData.perform_fleet_prestige(); _show_journal())
	box.add_child(prestige)
	var relic_names: Array[String] = []
	for relic_id in PlayerData.captain_relics:
		relic_names.append(str(Constants.ITEMS.get(relic_id, {}).get("name", relic_id)))
	var relic_text: String = "Captain Relics: " + (", ".join(PackedStringArray(relic_names)) if not relic_names.is_empty() else "None recovered yet")
	box.add_child(_modal_label(relic_text, 18))
	box.add_child(_modal_label("Sea Serpent Scale: +25 maximum hull. Dreadnought Insignia: +5 cannon damage and +10% extraction Gold.", 14))
	_finish_modal(box)

func _show_message(title_text: String, body_text: String) -> void:
	var box := _begin_modal(title_text, body_text, Vector2(500, 260))
	_finish_modal(box)

func _begin_modal(title_text: String, body_text: String, panel_size: Vector2) -> VBoxContainer:
	for child in _modal_layer.get_children():
		child.queue_free()
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "MenuModal"
	panel.custom_minimum_size = panel_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -panel_size * 0.5
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := _modal_label(title_text, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := _modal_label(body_text, 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	panel.set_meta("modal_box", box)
	_modal_layer.add_child(panel)
	return box

func _finish_modal(box: VBoxContainer) -> void:
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 52)
	close.pressed.connect(_close_modal)
	box.add_child(close)
	_apply_settings()

func _modal_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _close_modal() -> void:
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _modal_layer.get_children():
		child.queue_free()

func _apply_settings() -> void:
	SettingsManager.apply_to_tree(self)

func _open_home_bank() -> void:
	_open_home_port("bank")

func _open_chart_table() -> void:
	_open_home_port("chart")

func _open_home_port(tab_name: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var destination: String = "res://scenes/open_sea.tscn" if PlayerData.voyage.is_active else "res://scenes/home_port.tscn"
	if not PlayerData.voyage.is_active:
		get_tree().root.set_meta("home_port_open_tab", tab_name)
	AssetManager.request_texture("loading_screen", _fade_to_scene.bind(destination))

func _fade_to_scene(texture: Texture2D, destination: String) -> void:
	var duration: float = SettingsManager.transition_duration(0.22)
	if duration <= 0.0:
		get_tree().change_scene_to_file(destination)
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
	tween.finished.connect(func(): get_tree().change_scene_to_file(destination))
