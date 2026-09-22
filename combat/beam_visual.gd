extends RefCounted
## Deterministic electrical lance; all phases share the gameplay clock.

static func envelope(age: float, remaining: float) -> Dictionary:
	if remaining <= 0.0:
		return {"phase": "recovery", "core": 0.0, "wings": 0.0, "residual": 0.0, "fan": 0.0}
	var attack := clampf(age / 0.025, 0.0, 1.0)
	var core := attack * clampf((remaining - 0.025) / 0.05, 0.0, 1.0)
	var wings := attack * clampf((remaining - 0.045) / 0.045, 0.0, 1.0)
	var residual := attack * clampf(remaining / 0.06, 0.0, 1.0)
	var phase := "attack" if age < 0.05 else ("release" if remaining < 0.09 else "sustain")
	return {"phase": phase, "core": core, "wings": wings, "residual": residual,
		"fan": (0.24 + 0.76 * pow(1.0 - clampf(age / 0.09, 0.0, 1.0), 2.0)) * core}

static func center_at(muzzle: Vector2, target: Vector2, t: float, age: float) -> Vector2:
	var bend := sin(t * 14.0 - age * 32.0) * 2.6 + sin(t * 31.0 + age * 47.0) * 1.1
	return muzzle.lerp(target, t) + Vector2(bend * sin(t * PI), 0.0)

static func draw_beam(game, canvas) -> void:
	var muzzle: Vector2 = game.player_pos + game.PLAYER_NOSE_OFFSET
	var target := Vector2(muzzle.x, game.beam_end.y)
	if target.y >= muzzle.y - 4.0 or game.beam_visible_timer <= 0.0:
		return
	var age: float = game.beam_age
	var e := envelope(age, game.beam_visible_timer)
	var length := muzzle.distance_to(target)
	var width := 4.1 if game.beam_overcharged else 3.0
	var shaft := PackedVector2Array()
	for i in range(65):
		shaft.append(center_at(muzzle, target, float(i) / 64.0, age))
	canvas.draw_polyline(shaft, Color(0.025, 0.18, 1.2, e.residual * 0.13), width * 9.0, true)
	canvas.draw_polyline(shaft, Color(0.04, 0.48, 1.7, e.residual * 0.65), maxf(0.5, width * 2.1 * e.residual), true)
	# Open, upward-swept feathers, as in the sampled lance. Their roots remain
	# attached; unequal spacing and asymmetric bending avoid repeated glyphs.
	var count := maxi(2, int(length / 52.0))
	for i in range(count):
		var distance := fposmod(i * 52.0 + sin(i * 2.39) * 11.0 + age * 260.0, length)
		var t := distance / length
		var edge := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.9, 1.0, t))
		for side in [-1.0, 1.0]:
			var opening: float = (13.0 + 5.0 * sin(i * 1.73 + age * 39.0 + side)) * e.wings * edge
			var lobe := PackedVector2Array()
			for j in range(11):
				var u := float(j) / 10.0
				var axial := clampf((distance + u * (30.0 + sin(i * 2.7 + side) * 9.0)) / length, 0.0, 1.0)
				var point := center_at(muzzle, target, axial, age)
				point.x += side * opening * pow(u, 0.85)
				lobe.append(point)
			canvas.draw_polyline(lobe, Color(0.03, 0.28, 1.3, e.wings * 0.12), 7.0, true)
			canvas.draw_polyline(lobe, Color(0.12, 0.95, 2.3, e.wings * 0.78), 1.9, true)
			canvas.draw_polyline(lobe, Color(1.1, 1.8, 2.4, e.wings * 0.65), 0.65, true)
	canvas.draw_polyline(shaft, Color(0.35, 1.5, 2.7, e.core), maxf(0.4, width * e.core), true)
	canvas.draw_polyline(shaft, Color(2.0, 2.5, 2.8, e.core), maxf(0.3, width * 0.4 * e.core), true)
	# The attack fan is directional; an optical cross belongs to explosions.
	for i in range(13):
		var angle: float = -PI * 0.5 + (i - 6) * (0.045 + e.fan * 0.085)
		var reach: float = (58.0 + e.fan * 65.0) * (0.8 + sin(i * 2.1) * 0.2)
		var ray := Vector2.from_angle(angle) * reach
		var side: Vector2 = ray.normalized().orthogonal() * (0.6 + e.fan * 1.2)
		canvas.draw_colored_polygon(PackedVector2Array([muzzle - side, muzzle + ray, muzzle + side]), Color(0.7, 1.7, 2.6, e.fan * 0.65))
	canvas.light(muzzle, Vector2(74, 92), Color(0.08, 0.55, 1.6, e.core * 0.55))
	canvas.light(muzzle, Vector2(17, 32), Color(1.6, 2.1, 2.5, e.core))
	if game.beam_contact:
		contact(canvas, target, age, e.core, game.beam_overcharged)

static func contact(canvas, target: Vector2, age: float, strength: float, overcharged: bool) -> void:
	var scale := 1.25 if overcharged else 1.0
	canvas.light(target, Vector2(150, 120) * scale, Color(0.04, 0.48, 1.8, strength * 0.68))
	canvas.light(target, Vector2(65, 52) * scale, Color(0.35, 1.2, 2.3, strength))
	canvas.light(target, Vector2(42, 34) * scale, Color(2.2, 2.6, 2.8, strength))
	for i in range(11):
		var angle := i * 2.39996 + sin(age * 34.0 + i) * 0.2
		var direction := Vector2.from_angle(angle)
		var reach := (17.0 + 19.0 * (0.5 + sin(i * 3.1 + age * 65.0) * 0.5)) * scale
		var normal := direction.orthogonal() * 1.2
		canvas.draw_colored_polygon(PackedVector2Array([target - normal, target + direction * reach, target + normal]), Color(0.4, 1.1, 2.5, strength * 0.8))
