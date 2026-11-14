extends Node

const Constants = preload("res://data/mvp_constants.gd")

signal tick_processed(tick_count: int)
signal clock_paused(is_paused: bool)

var tick_count: int = 0
var _accumulator: float = 0.0
var _is_paused: bool = false

func _physics_process(delta: float) -> void:
	if _is_paused:
		return
	# Cap unusually large frame deltas: missed wall-clock time is intentionally discarded,
	# preventing a burst of gameplay ticks when the app resumes after a stall.
	_accumulator += minf(delta, Constants.MAX_FRAME_DELTA)
	while _accumulator >= Constants.TICK_DURATION:
		_accumulator -= Constants.TICK_DURATION
		tick_count += 1
		tick_processed.emit(tick_count)

func set_paused(paused: bool) -> void:
	if _is_paused == paused:
		return
	_is_paused = paused
	# Discard partial tick progress across pause/resume; tick_count itself remains unchanged.
	if _is_paused:
		_accumulator = 0.0
	clock_paused.emit(_is_paused)

func is_clock_paused() -> bool:
	return _is_paused

func get_tick_progress() -> float:
	if _is_paused:
		return 0.0
	return clampf(_accumulator / Constants.TICK_DURATION, 0.0, 1.0)

func reset_clock() -> void:
	tick_count = 0
	_accumulator = 0.0
	tick_processed.emit(tick_count)
