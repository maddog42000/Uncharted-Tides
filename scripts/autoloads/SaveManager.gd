extends Node

signal save_completed(success: bool, message: String)

const SAVE_PATH: String = "user://save_data.json"
const TEMP_PATH: String = "user://save_data.tmp"
const BACKUP_PATH: String = "user://save_data.bak"
var _loading: bool = false
var _wiping: bool = false

func _ready() -> void:
	PlayerData.state_changed.connect(_on_player_state_changed)
	load_game()

func _notification(what: int) -> void:
	# Pause before saving. Background/resume notifications may arrive in pairs; repeated saves are safe.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameClock.set_paused(true)
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		GameClock.set_paused(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameClock.set_paused(true)
		save_game()

func _on_player_state_changed() -> void:
	if not _loading and not _wiping:
		save_game()

func _path_is_valid_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary

func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func save_game() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		save_completed.emit(false, "Could not open temporary save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(PlayerData.serialize(), "\t"))
	file.flush()
	file.close()
	if not _path_is_valid_json(TEMP_PATH):
		save_completed.emit(false, "Temporary save failed JSON verification; existing save was preserved.")
		return false

	# Recovery-safe replacement: keep the prior save as .bak until the new save is in place.
	# On startup, load_game() can recover from .bak if the process dies during this sequence.
	var had_live_save: bool = FileAccess.file_exists(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		var remove_backup_error: Error = DirAccess.remove_absolute(_absolute(BACKUP_PATH))
		if remove_backup_error != OK:
			save_completed.emit(false, "Could not clear previous backup: %s" % error_string(remove_backup_error))
			return false
	if had_live_save:
		var backup_error: Error = DirAccess.rename_absolute(_absolute(SAVE_PATH), _absolute(BACKUP_PATH))
		if backup_error != OK:
			save_completed.emit(false, "Could not preserve prior save: %s" % error_string(backup_error))
			return false

	var commit_error: Error = DirAccess.rename_absolute(_absolute(TEMP_PATH), _absolute(SAVE_PATH))
	if commit_error != OK:
		if had_live_save and FileAccess.file_exists(BACKUP_PATH) and not FileAccess.file_exists(SAVE_PATH):
			DirAccess.rename_absolute(_absolute(BACKUP_PATH), _absolute(SAVE_PATH))
		save_completed.emit(false, "Save commit failed; prior save recovery was attempted: %s" % error_string(commit_error))
		return false

	# The new live file has been committed and verified. Backup removal is best-effort.
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(_absolute(BACKUP_PATH))
	save_completed.emit(true, "Saved successfully at tick %d." % GameClock.tick_count)
	return true

func load_game() -> bool:
	_loading = true
	var chosen_path: String = ""
	for candidate in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if _path_is_valid_json(candidate):
			chosen_path = candidate
			break
	if chosen_path.is_empty():
		_loading = false
		save_completed.emit(false, "No valid save found; using a new game.")
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(chosen_path))
	PlayerData.deserialize(parsed)
	_loading = false
	save_completed.emit(true, "Loaded save from %s (tick %d)." % [chosen_path, GameClock.tick_count])
	return true

func wipe_save() -> bool:
	_wiping = true
	for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			var remove_error: Error = DirAccess.remove_absolute(_absolute(path))
			if remove_error != OK:
				_wiping = false
				save_completed.emit(false, "Could not remove save file %s: %s" % [path, error_string(remove_error)])
				return false
	GameClock.reset_clock()
	PlayerData.reset_to_defaults()
	_wiping = false
	save_completed.emit(true, "Save files removed and state reset.")
	return true
