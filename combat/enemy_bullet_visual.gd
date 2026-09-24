extends RefCounted
## Read-only projectile rendering on the foreground threat layer.
const Missile = preload("res://combat/missile.gd")

static func draw(canvas: Node2D, bullet: Dictionary) -> void:
	var style: String = bullet.get("style", "capsule")
	if style == "missile":
		Missile.draw_missile(canvas, bullet)
		return
	var pos: Vector2 = bullet["pos"]
	var direction: Vector2 = bullet["vel"].normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var side := direction.orthogonal()
	var radius: float = bullet["radius"]
	var tint: Color = bullet["color"]
	var age: float = bullet["age"]
	match style:
		"shuriken":
			var points := PackedVector2Array()
			for i in range(12):
				var r := radius * (1.25 if i % 3 == 0 else 0.5)
				points.append(pos + Vector2.from_angle(age * 8.0 + i * TAU / 12.0) * r)
			canvas.draw_colored_polygon(points, tint)
			canvas.draw_circle(pos, radius * 0.35, tint.lightened(0.7), true, -1, true)
		"boomerang":
			var points := PackedVector2Array([pos - direction * radius + side * radius,
				pos + direction * radius, pos - direction * radius - side * radius])
			canvas.draw_polyline(points, Color(0.15, 0.01, 0.02), radius * 0.8, true)
			canvas.draw_polyline(points, tint, radius * 0.5, true)
			canvas.draw_circle(pos + direction * radius * 0.65, radius * 0.25, tint.lightened(0.7), true, -1, true)
		"orb", "pellet":
			canvas.draw_circle(pos, radius * 1.55, Color(tint, 0.12), true, -1, true)
			canvas.draw_circle(pos, radius * 1.08, Color(0.08, 0.015, 0.03), true, -1, true)
			canvas.draw_circle(pos, radius * 0.9, tint, true, -1, true)
			canvas.draw_circle(pos - Vector2(radius * 0.18, radius * 0.22), radius * 0.48, tint.lightened(0.55), true, -1, true)
			canvas.draw_arc(pos, radius * 1.3, age * 3.0, age * 3.0 + PI * 1.35, 20, Color(tint.lightened(0.35), 0.8), 1.1, true)
		"dart", "lance":
			var lance := style == "lance"
			var length := radius * (2.3 if lance else 1.7)
			var width := radius * (0.65 if lance else 0.95)
			var tail_length := minf(age * bullet["vel"].length(), radius * (7.0 if lance else 3.5))
			# Short, tapered velocity-aligned wake; no per-bullet particle allocation.
			var wake_start := pos - direction * length
			var wake := PackedVector2Array([wake_start + side * width * 0.5,
				wake_start - side * width * 0.5, wake_start - direction * maxf(0.1, tail_length)])
			canvas.draw_polygon(wake, PackedColorArray([Color(tint, 0.35), Color(tint, 0.35), Color(tint, 0.0)]))
			var shape := PackedVector2Array([pos + direction * length, pos + side * width,
				pos - direction * length, pos - side * width])
			canvas.draw_colored_polygon(shape, Color(0.12, 0.01, 0.035))
			var shell := PackedVector2Array([pos + direction * length * 0.9, pos + side * width * 0.72,
				pos - direction * length * 0.82, pos - side * width * 0.72])
			canvas.draw_colored_polygon(shell, tint)
			canvas.draw_line(pos - direction * length * 0.45, pos + direction * length * 0.6, tint.lightened(0.7), 1.6, true)
			if not lance:
				for sign_value in [-1.0, 1.0]:
					canvas.draw_line(pos - direction * radius * 0.5, pos - direction * radius + side * width * sign_value, tint, 1.5, true)
		_:
			_capsule(canvas, bullet, tint)

static func _capsule(canvas: Node2D, bullet: Dictionary, tint: Color) -> void:
	# Phoenix-style hostile shots are glossy directional capsules, not comet trails.
	var pos: Vector2 = bullet["pos"]
	var direction: Vector2 = bullet["vel"].normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var normal := Vector2(-direction.y, direction.x)
	var radius: float = bullet["radius"] * 0.72
	var half_segment := radius * 0.74
	var back := pos - direction * half_segment
	var front := pos + direction * half_segment

	# Restrained soft aura: enough separation from the background without merging patterns.
	var glow_radius := radius * 1.48
	var glow_color := Color(tint, 0.065)
	canvas.draw_line(back, front, glow_color, glow_radius * 2.0, true)
	canvas.draw_circle(back, glow_radius, glow_color, true, -1.0, true)
	canvas.draw_circle(front, glow_radius, glow_color, true, -1.0, true)

	# Dark rim, saturated red glass shell, then a narrow orange-hot interior.
	var rim_radius := radius * 1.04
	var rim_color := Color(tint * 0.25, 0.96)
	canvas.draw_line(back, front, rim_color, rim_radius * 2.0, true)
	canvas.draw_circle(back, rim_radius, rim_color, true, -1.0, true)
	canvas.draw_circle(front, rim_radius, rim_color, true, -1.0, true)

	var shell_radius := radius * 0.83
	var shell_color := Color(tint, 0.98)
	canvas.draw_line(back, front, shell_color, shell_radius * 2.0, true)
	canvas.draw_circle(back, shell_radius, shell_color, true, -1.0, true)
	canvas.draw_circle(front, shell_radius, shell_color, true, -1.0, true)

	var inner_back := pos - direction * half_segment * 0.38
	var inner_front := pos + direction * half_segment * 0.46
	var inner_radius := radius * 0.47
	var inner_color := Color(tint.lerp(Color(1.0, 0.7, 0.1), 0.35), 0.98)
	canvas.draw_line(inner_back, inner_front, inner_color, inner_radius * 2.0, true)
	canvas.draw_circle(inner_back, inner_radius, inner_color, true, -1.0, true)
	canvas.draw_circle(inner_front, inner_radius, inner_color, true, -1.0, true)

	var highlight_pos := front - direction * radius * 0.32 - normal * radius * 0.18
	canvas.draw_circle(highlight_pos, radius * 0.24, Color(2.0, 1.15, 0.34, 0.98), true, -1.0, true)
