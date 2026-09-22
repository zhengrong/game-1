extends RefCounted
## Owns weapon phase state. Consumers decide how to apply damage and effects.
signal damage_requested
signal beam_started
signal twin_requested(delay: float)
var config = preload("res://combat/weapon_config.gd").new()
var twin_shots := false
var twin_timer := 0.0
var shot_timer := 0.0
var shot_sequence := 0
var beam_overcharged := false
var beam_visible_timer := 0.0
var beam_pause_timer := 0.0
var beam_age := 0.0
var beam_contact := false

func advance(delta: float) -> void:
	if twin_shots:
		var remaining := delta
		while remaining > 0.000001:
			var step := minf(remaining, twin_timer)
			twin_timer -= step
			remaining -= step
			if twin_timer <= 0.000001:
				twin_requested.emit(delta - remaining)
				twin_timer = config.twin_interval
		return
	# Consume the elapsed interval across shot and phase boundaries. Damage rate
	# stays consistent at 30/60/120 FPS, including frames spanning recovery.
	var remaining := delta
	while remaining > 0.000001:
		if beam_visible_timer <= 0.000001:
			var pause_step := minf(remaining, beam_pause_timer)
			beam_pause_timer -= pause_step
			remaining -= pause_step
			if beam_pause_timer <= 0.000001:
				start_beam()
		else:
			var step := minf(remaining, minf(beam_visible_timer, shot_timer))
			beam_visible_timer -= step
			beam_age += step
			shot_timer -= step
			remaining -= step
			if beam_visible_timer <= 0.000001:
				beam_visible_timer = 0.0
				beam_contact = false
				beam_pause_timer = config.beam_pause
			elif shot_timer <= 0.000001:
				damage_requested.emit()
				shot_timer = config.damage_interval


func start_beam() -> void:
	shot_sequence += 1
	beam_overcharged = shot_sequence % 4 == 0
	beam_visible_timer = config.beam_duration
	beam_pause_timer = 0.0
	beam_age = 0.0
	shot_timer = config.damage_interval
	damage_requested.emit()
	beam_started.emit()
