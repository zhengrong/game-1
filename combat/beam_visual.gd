extends RefCounted
## Connected electrical shaft. Rendering reads the weapon's gameplay timers.
static func draw_beam(game) -> void:
	var muzzle: Vector2 = game.player_pos + game.PLAYER_NOSE_OFFSET
	var target := Vector2(muzzle.x, game.beam_end.y)
	if target.y >= muzzle.y - 4.0:
		return
	var age: float = game.beam_age
	var remaining: float = game.beam_visible_timer
	var attack := clampf(age / 0.035, 0.0, 1.0)
	var release := clampf(remaining / 0.075, 0.0, 1.0)
	var core_strength := attack * clampf((remaining - 0.018) / 0.045, 0.0, 1.0)
	var feather_strength := attack * clampf((remaining - 0.035) / 0.04, 0.0, 1.0)
	var length := muzzle.distance_to(target)
	var width := 4.8 if game.beam_overcharged else 3.3
	var shaft := PackedVector2Array()
	for i in range(41):
		var t := float(i) / 40.0
		var bend := sin(t * 17.0 - age * 30.0) * 2.4 + sin(t * 39.0 + age * 43.0) * 1.2
		shaft.append(muzzle.lerp(target, t) + Vector2(bend * sin(t * PI), 0.0))
	# The blue shaft outlives the white core at release.
	game.draw_polyline(shaft, Color(0.03, 0.35, 2.0, 0.12 * attack * release), width * 6.0 * release, true)
	game.draw_polyline(shaft, Color(0.05, 0.65, 2.3, attack * release * 0.8), maxf(0.6, width * 2.0 * release), true)
	if core_strength > 0.0:
		game.draw_polyline(shaft, Color(0.3, 1.4, 3.0, core_strength), maxf(0.5, width * core_strength), true)
		game.draw_polyline(shaft, Color(3.0, 3.7, 4.0, core_strength), maxf(0.4, width * 0.36 * core_strength), true)
	# Each wing shares the continuous core, with varying spacing and opening.
	for i in range(1, 40):
		var t := float(i) / 40.0
		var phase := t * length * 0.06 - age * 38.0
		var opening := (5.0 + (sin(phase) * 0.5 + 0.5) * 13.0) * feather_strength * sin(t * PI)
		if opening < 0.3:
			continue
		for side in [-1.0, 1.0]:
			var root: Vector2 = shaft[i]
			var wing := root + Vector2(side * opening, 8.0 + sin(phase * 0.7) * 4.0)
			var tip: Vector2 = shaft[maxi(0, i - 1)]
			game.draw_polyline(PackedVector2Array([root, wing, tip]), Color(0.16, 1.0, 2.5, feather_strength * 0.65), 1.5, true)
	var fan := (1.0 - clampf(age / 0.075, 0.0, 1.0)) * 0.8 + 0.2
	for i in range(9):
		var angle := -PI * 0.5 + (i - 4) * 0.14 * fan
		var ray := Vector2.from_angle(angle) * (25.0 + fan * 32.0) * release
		game.draw_line(muzzle, muzzle + ray, Color(0.5, 1.5, 3.0, attack * release * 0.65), 1.6, true)
	game.draw_circle(muzzle, (4.0 + fan * 7.0) * release, Color(2.5, 3.2, 4.0, attack * release))
	if game.beam_contact:
		game.draw_circle(target, 22.0 * release, Color(0.1, 0.65, 2.0, 0.15 * attack))
		game.draw_circle(target, 8.0 * core_strength, Color(0.4, 1.6, 3.0, 0.8))
		game.draw_circle(target, 3.5 * core_strength, Color(3.2, 3.8, 4.0))
		for i in range(7):
			var direction := Vector2.from_angle(TAU * i / 7.0 + age * 6.0)
			game.draw_line(target + direction * 5.0, target + direction * (12.0 + sin(age * 33.0 + i) * 4.0) * release, Color(0.3, 1.3, 2.8, attack * release), 1.2, true)
