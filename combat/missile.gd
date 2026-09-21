extends RefCounted

static func create(origin: Vector2, target: Vector2) -> Dictionary:
	return {"pos": origin, "vel": origin.direction_to(target) * 145.0, "radius": 10.0,
		"color": Color(0.95, 0.1, 0.45), "grazed": false, "age": 0.0, "style": "missile"}

static func ready_to_split(bullet: Dictionary, player: Vector2) -> bool:
	return bullet.get("style", "") == "missile" and bullet["age"] >= 1.3 and (bullet["pos"].distance_to(player) < 240.0 or bullet["age"] >= 3.0)

static func fragments(bullet: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(8):
		result.append({"pos": bullet["pos"], "vel": Vector2.from_angle(TAU * i / 8.0) * 180.0,
			"radius": 5.0, "color": Color(1.0, 0.1, 0.5), "grazed": false, "age": 0.0})
	return result

static func draw_missile(game, bullet: Dictionary) -> void:
	var pos: Vector2 = bullet["pos"]
	var direction: Vector2 = bullet["vel"].normalized()
	var normal := direction.orthogonal()
	game.draw_line(pos - direction * 14.0, pos - direction * 30.0, Color(1.0, 0.1, 0.4, 0.45), 5.0, true)
	game.draw_colored_polygon(PackedVector2Array([pos + direction * 15.0, pos + normal * 10.0, pos - direction * 10.0, pos - normal * 10.0]), Color(0.5, 0.025, 0.12))
	game.draw_arc(pos, 10.0, 0.0, TAU, 16, Color(1.8, 0.15, 0.5), 2.0, true)
	game.draw_circle(pos, 4.0, Color(2.0, 1.1, 1.3))
	if bullet["age"] > 0.7:
		var charge := clampf((bullet["age"] - 0.7) / 0.6, 0.0, 1.0)
		game.draw_arc(pos, 17.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 28, Color(1.0, 0.3, 0.6, 0.8), 1.5, true)
