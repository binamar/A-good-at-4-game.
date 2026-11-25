extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 12

var _streams: Dictionary = {}
var _players: Array = []
var _cursor := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_procedural_sfx()

func _build_procedural_sfx() -> void:
	_streams["rifle"] = _make_noise_shot(0.14, 175.0, 26.0, 0.85)
	_streams["pistol"] = _make_noise_shot(0.11, 260.0, 34.0, 0.72)
	_streams["smg"] = _make_noise_shot(0.09, 290.0, 38.0, 0.65)
	_streams["knife"] = _make_noise_shot(0.08, 620.0, 42.0, 0.45)
	_streams["throw"] = _make_noise_shot(0.10, 340.0, 28.0, 0.45)
	_streams["hit"] = _make_tone(0.055, 1180.0, 880.0, 0.55)
	_streams["headshot"] = _make_tone(0.12, 2280.0, 1620.0, 0.90)
	_streams["reload"] = _make_tone(0.12, 420.0, 620.0, 0.45)
	_streams["beep"] = _make_tone(0.085, 2400.0, 2400.0, 0.50)
	_streams["plant"] = _make_tone(0.22, 920.0, 1480.0, 0.65)
	_streams["explode"] = _make_noise_shot(0.75, 58.0, 4.5, 0.96)
	_streams["win"] = _make_tone(0.32, 523.25, 783.99, 0.55)
	_streams["multikill"] = _make_tone(0.26, 660.0, 1320.0, 0.70)

func play_sfx(key: String, volume_db: float = -4.0, pitch_jitter: float = 0.05) -> void:
	if not _streams.has(key):
		return
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % POOL_SIZE
	p.stream = _streams[key]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()

func _make_noise_shot(duration: float, thump_freq: float, decay: float, amp: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * decay)
		var noise := randf_range(-1.0, 1.0) * 0.65
		var thump := sin(TAU * thump_freq * t * exp(-t * 10.0)) * 0.55
		var sample := clampf((noise + thump) * env * amp, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	return wav

func _make_tone(duration: float, freq_start: float, freq_end: float, amp: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(SAMPLE_RATE)
		var k := float(i) / float(max(1, count - 1))
		var freq := lerpf(freq_start, freq_end, k)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env := (1.0 - k) * minf(1.0, t * 80.0)
		var sample := clampf(sin(phase) * env * amp, -1.0, 1.0)
		var s16 := int(sample * 32767.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = data
	return wav
