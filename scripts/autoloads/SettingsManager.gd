extends Node

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const TEXT_SIZE_OPTIONS: Array[String] = ["Small", "Standard", "Large"]

var text_size_index: int = 1
var reduced_motion: bool = false

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

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "text_size_index", text_size_index)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.save(SETTINGS_PATH)
