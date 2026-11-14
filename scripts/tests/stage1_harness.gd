extends Control

const Constants = preload("res://data/mvp_constants.gd")
var _tick_label: Label
var _progress_bar: ProgressBar
var _stats_label: Label
var _log_label: RichTextLabel
var _pause_button: Button

func _ready() -> void:
	_build_ui()
	GameClock.tick_processed.connect(_on_tick)
	GameClock.clock_paused.connect(_on_clock_paused)
	PlayerData.xp_gained.connect(_on_xp_gained)
	PlayerData.level_up.connect(_on_level_up)
	PlayerData.inventory_updated.connect(_refresh_stats)
	SaveManager.save_completed.connect(_on_save_completed)
	_refresh_stats()
	_log("Stage 1 QA harness ready. Godot: " + Engine.get_version_info().string)

func _process(_delta: float) -> void:
	_progress_bar.value = GameClock.get_tick_progress() * 100.0

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "UNCHARTED TIDES — STAGE 1 QA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	_tick_label = Label.new()
	_tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tick_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_tick_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_stats_label)
	_pause_button = _add_button(vbox, "Pause Clock", _toggle_pause)
	_add_button(vbox, "+50 Sailing XP", func(): PlayerData.add_xp("Sailing", 50))
	_add_button(vbox, "Add 10 Copper Ore", _add_test_items)
	_add_button(vbox, "Transfer Backpack → Sloop Hold", _transfer)
	_add_button(vbox, "Extract Cargo → Bank", _extract)
	_add_button(vbox, "Force Save", func(): SaveManager.save_game())
	_add_button(vbox, "Wipe Save & Reset", func(): SaveManager.wipe_save())
	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(_log_label)

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _on_tick(count: int) -> void:
	_tick_label.text = "Tick: %d  (%.1f simulated seconds)" % [count, count * Constants.TICK_DURATION]

func _on_clock_paused(paused: bool) -> void:
	_pause_button.text = "Resume Clock" if paused else "Pause Clock"
	_log("Clock " + ("paused" if paused else "resumed"))

func _toggle_pause() -> void:
	GameClock.set_paused(not GameClock.is_clock_paused())

func _add_test_items() -> void:
	var added: int = PlayerData.add_to_backpack("copper_ore", 10)
	_log("Added %d Copper Ore to backpack." % added)

func _transfer() -> void:
	var result: Dictionary = PlayerData.transfer_backpack_to_cargo()
	_log("Moved %d. Hold %d/%d; backpack %d/28." % [result.transferred, result.cargo_used, result.cargo_max, result.remaining_in_backpack])

func _extract() -> void:
	_log("Banked %d item(s)." % PlayerData.extract_cargo_to_bank())

func _on_xp_gained(skill: String, amount: int, total: int) -> void:
	_log("+%d %s XP (total %d)." % [amount, skill, total])
	_refresh_stats()

func _on_level_up(skill: String, level: int) -> void:
	_log("LEVEL UP: %s is now level %d." % [skill, level])

func _on_save_completed(success: bool, message: String) -> void:
	_log(("[OK] " if success else "[INFO/ERROR] ") + message)
	_refresh_stats()

func _refresh_stats() -> void:
	if not is_instance_valid(_stats_label):
		return
	_tick_label.text = "Tick: %d  (%.1f simulated seconds)" % [GameClock.tick_count, GameClock.tick_count * Constants.TICK_DURATION]
	var sailing_xp: int = int(PlayerData.skill_xp.get("Sailing", 0))
	_stats_label.text = "Sailing %d (%d XP) | Backpack %d/28 | Hold %d/8 | Bank ore %d" % [PlayerData.get_level("Sailing"), sailing_xp, PlayerData.backpack.size(), PlayerData.voyage.ship_cargo.size(), int(PlayerData.bank.get("copper_ore", 0))]

func _log(message: String) -> void:
	if is_instance_valid(_log_label):
		_log_label.append_text("• " + message + "\n")
