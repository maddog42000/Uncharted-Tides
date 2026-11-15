extends Node

const MIX_RATE: int = 22050
const CUE_SPECS: Dictionary = {
	"cannon_fire": {"start_hz": 110.0, "end_hz": 45.0, "duration": 0.22, "noise": 0.28},
	"hull_hit": {"start_hz": 180.0, "end_hz": 55.0, "duration": 0.14, "noise": 0.48},
	"repair": {"start_hz": 330.0, "end_hz": 740.0, "duration": 0.24, "noise": 0.0},
	"ration": {"start_hz": 420.0, "end_hz": 920.0, "duration": 0.18, "noise": 0.0},
	"salvage": {"start_hz": 520.0, "end_hz": 1120.0, "duration": 0.27, "noise": 0.0},
	"extraction": {"start_hz": 390.0, "end_hz": 780.0, "duration": 0.42, "noise": 0.0}
}

var _players: Dictionary = {}

func _ready() -> void:
	_ensure_sfx_bus()
	for cue_id in CUE_SPECS:
		var player := AudioStreamPlayer.new()
		player.name = "Cue_" + str(cue_id)
		player.bus = "SFX"
		player.stream = _synthesize(str(cue_id), CUE_SPECS[cue_id])
		add_child(player)
		_players[cue_id] = player
	SettingsManager.apply_audio_volumes()

func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	var bus_index: int = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, "SFX")
	AudioServer.set_bus_send(bus_index, "Master")

func _synthesize(cue_id: String, spec: Dictionary) -> AudioStreamWAV:
	var sample_count: int = maxi(1, roundi(float(spec.duration) * MIX_RATE))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase: float = 0.0
	var initial_hz: float = float(spec.start_hz)
	var final_hz: float = float(spec.end_hz)
	var noise_amount: float = float(spec.noise)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cue_id)
	for sample_index in range(sample_count):
		var position: float = float(sample_index) / float(sample_count)
		var frequency: float = lerpf(initial_hz, final_hz, position)
		phase += TAU * frequency / float(MIX_RATE)
		var envelope: float = minf(1.0, float(sample_index) / 180.0) * pow(1.0 - position, 1.8)
		var tone: float = sin(phase) * 0.78 + sin(phase * 2.01) * 0.22
		var sample_value: int = clampi(roundi((tone + rng.randf_range(-1.0, 1.0) * noise_amount) * envelope * 23500.0), -32768, 32767)
		var byte_offset: int = sample_index * 2
		pcm[byte_offset] = sample_value & 0xff
		pcm[byte_offset + 1] = (sample_value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

func play_cue(cue_id: String) -> void:
	if not _players.has(cue_id):
		return
	var player: AudioStreamPlayer = _players[cue_id]
	player.stop()
	player.play()
