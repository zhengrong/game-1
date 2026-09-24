extends RefCounted
## Reference-guided twin bolts. Geometry uses shot age and its fixed launch point.
const LIGHT = preload("res://combat/flare_texture.tres")

static func light(canvas: Node2D, center: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_texture_rect(LIGHT, Rect2(center - size * 0.5, size), false, color)

static func draw(canvas: Node2D, shot: Dictionary) -> void:
	if shot.get("delay", 0.0) > 0.0:
		return
	var head: Vector2 = shot["pos"]
	var velocity: Vector2 = shot["vel"]
	var age: float = shot["age"]
	var origin: Vector2 = shot.get("origin", head - velocity * age)
	var distance := minf(480.0, head.distance_to(origin))
	# Local +Y points back along the flight path, never toward a moving player.
	canvas.draw_set_transform(head, velocity.angle() + PI * 0.5)
	var fade := 1.0 - smoothstep(0.16, 0.36, age)
	for strand in [-1.0, 0.0, 1.0]:
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for i in range(25):
			var t := float(i) / 24.0
			var width := 2.0 + sin(t * PI) * 4.0
			var x: float = strand * width + sin(t * 21.0 - age * 30.0 + strand) * 1.8 * sin(t * PI)
			points.append(Vector2(x, t * distance))
			colors.append(Color(0.25, 0.75, 1.8, (0.16 + 0.25 * fade) * (1.0 - t * 0.7)))
		canvas.draw_polyline_colors(points, colors, 1.0, true)
	# Ribbed wake at the launch end, fading independently of the projectile head.
	if fade > 0.0:
		for i in range(8):
			var y := distance - i * 4.0
			if y < 0:
				break
			var width := 9.0 - i * 0.7
			canvas.draw_polyline(PackedVector2Array([Vector2(-width, y - 2), Vector2(0, y), Vector2(width, y - 2)]), Color(0.35, 1.1, 1.8, fade * (1.0 - i / 9.0) * 0.5), 1.0, true)
	light(canvas, Vector2(0, 3), Vector2(72, 155), Color(0.10, 0.48, 1.8, 0.58))
	light(canvas, Vector2(0, -14), Vector2(29, 85), Color(0.5, 1.25, 2.2, 0.6))
	# Three curved lobes retain blue interior gaps instead of a solid diamond.
	for lobe in [-1.0, 0.0, 1.0]:
		var outline := PackedVector2Array()
		var fills := PackedColorArray()
		var edges := PackedColorArray()
		for side in [-1.0, 1.0]:
			for i in range(17):
				var t := float(i if side < 0 else 16 - i) / 16.0
				var width := pow(sin(PI * t), 0.85) * (5.2 if lobe == 0 else 4.0)
				var bow: float = lobe * sin(PI * t) * 9.0 + sin(age * 30 + t * 13 + lobe) * t * 0.9
				outline.append(Vector2(bow + side * width, lerpf(-48, 66, t) + absf(lobe) * 11))
				fills.append(Color(0.8, 1.5, 2.2, 0.72 * (1.0 - smoothstep(0.35, 0.85, t))))
				edges.append(Color(0.9, 1.65, 2.4, 0.85 - t * 0.4))
		canvas.draw_polygon(outline, fills)
		outline.append(outline[0])
		edges.append(edges[0])
		canvas.draw_polyline_colors(outline, edges, 1.4, true)
	light(canvas, Vector2(0, -30), Vector2(13, 40), Color(1.8, 2.2, 2.5, 0.85))
	canvas.draw_line(Vector2(0, -42), Vector2(0, 25), Color(1.1, 1.7, 2.2, 0.75), 1.2, true)
	canvas.draw_set_transform(Vector2.ZERO)
