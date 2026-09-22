extends Node
## Voice pool and sound synthesis, independent of combat state.
const TAU_F = TAU
var rng: RandomNumberGenerator
var sound_pool: Array[AudioStreamPlayer] = []
var sound_cursor := 0
var sounds: Dictionary = {}

func _build_audio() -> void:
	sounds["shield_break"] = _make_tone(1200.0, 180.0, 0.3, 0.2, 2)
	sounds["turret_down"] = _make_tone(210.0, 60.0, 0.22, 0.2, 2)
	sounds["laser"] = _make_tone(170.0, 650.0, 0.5, 0.13, 1)
	sounds["dart"] = _make_tone(800.0, 280.0, 0.09, 0.10, 2)
	sounds["start"] = _make_tone(420.0, 720.0, 0.23, 0.24, 0)
	sounds["explode"] = _make_tone(150.0, 48.0, 0.18, 0.2, 2)
	sounds["hit"] = _make_tone(110.0, 34.0, 0.34, 0.32, 2)
	sounds["warning"] = _make_tone(240.0, 180.0, 0.52, 0.25, 1)
	sounds["nova"] = _make_tone(180.0, 860.0, 0.62, 0.34, 0)
	sounds["boss_down"] = _make_tone(360.0, 52.0, 0.9, 0.38, 2)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -5.0
		add_child(player)
		sound_pool.append(player)


func _make_tone(start_hz: float, end_hz: float, duration: float, volume: float, waveform: int) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(maxi(sample_count - 1, 1))
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU_F * hz / float(mix_rate)
		var sample := sin(phase)
		if waveform == 1:
			sample = 1.0 if sample >= 0.0 else -1.0
		elif waveform == 2:
			sample = sin(phase) * 0.62 + rng.randf_range(-1.0, 1.0) * 0.38
		var envelope := pow(1.0 - t, 2.2)
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func play_sound(sound_name: String) -> void:
	if not sounds.has(sound_name) or sound_pool.is_empty():
		return
	var player := sound_pool[sound_cursor]
	sound_cursor = (sound_cursor + 1) % sound_pool.size()
	player.stop()
	player.stream = sounds[sound_name]
	player.play()


