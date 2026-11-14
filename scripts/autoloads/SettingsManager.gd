extends Node

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const TEXT_SIZE_OPTIONS: Array[String] = ["Small", "Standard", "Large"]

var text_size_index: int = 1
var reduced_motion: bool = false
var master_volume: float = 0.8
var sfx_volume: float = 0.8

func _ready() -> void:
	_load_settings()

func set_text_size(index: int) -> void:
	var normalized: int = clampi(index, 0, TEXT_SIZE_OPTIONS.size() - 1)
	if text_size_index == normalized:
		return
	text_size_index = normalized
	_save_settings()
	settings_changed.emit()

func set_reduced_motion(enabled: bool) -> void:
	if reduced_motion == enabled:
		return
	reduced_motion = enabled
	_save_settings()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_save_settings()
	apply_audio_volumes()
	settings_changed.emit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save_settings()
	apply_audio_volumes()
	settings_changed.emit()

func apply_audio_volumes() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)

func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized: float = clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.0001)))

func text_scale() -> float:
	match text_size_index:
		0: return 0.90
		2: return 1.15
		_: return 1.0

func transition_duration(default_duration: float) -> float:
	return 0.0 if reduced_motion else default_duration

func apply_to_tree(root_node: Node) -> void:
	_apply_to_node(root_node)

func _apply_to_node(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if not control.has_meta("settings_base_font_size"):
			control.set_meta("settings_base_font_size", control.get_theme_font_size("font_size"))
		var base_size: int = int(control.get_meta("settings_base_font_size"))
		control.add_theme_font_size_override("font_size", maxi(1, roundi(float(base_size) * text_scale())))
	for child in node.get_children():
		_apply_to_node(child)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	text_size_index = clampi(int(config.get_value("display", "text_size_index", 1)), 0, TEXT_SIZE_OPTIONS.size() - 1)
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 0.8)), 0.0, 1.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "text_size_index", text_size_index)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)
