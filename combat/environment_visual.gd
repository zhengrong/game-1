extends RefCounted
## Peripheral industrial geometry; the center remains clear for combat.
static func draw_layers(game) -> void:
	var size: Vector2 = game.screen_size
	var time: float = game.elapsed
	for layer in range(2):
		var spacing := 370.0 if layer == 0 else 610.0
		var speed := 22.0 if layer == 0 else 62.0
		var depth := 34.0 if layer == 0 else 69.0
		var scroll := fmod(time * speed, spacing)
		for row in range(-1, int(size.y / spacing) + 2):
			var y := row * spacing + scroll
			for side in [-1.0, 1.0]:
				var x: float = 0.0 if side < 0.0 else size.x
				var inward: float = -side
				var shape := PackedVector2Array([Vector2(x, y - 130), Vector2(x + inward * depth * 0.6, y - 95), Vector2(x + inward * depth, y - 25), Vector2(x + inward * depth, y + 70), Vector2(x + inward * depth * 0.35, y + 118), Vector2(x, y + 145)])
				game.draw_colored_polygon(shape, Color(0.022, 0.035, 0.044, 0.72 if layer == 0 else 0.94))
				game.draw_polyline(shape, Color(0.16, 0.23, 0.25, 0.45), 2.0, true)
				game.draw_line(Vector2(x + inward * depth, y - 20), Vector2(x + inward * depth, y + 45), Color(0.25, 0.68, 0.73, 0.35), 2.0, true)
				for light in range(3):
					game.draw_circle(Vector2(x + inward * depth * 0.55, y + light * 13.0), 2.0, Color(1.2, 0.6, 0.12, 0.65))
