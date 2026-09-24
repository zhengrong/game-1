extends RefCounted

static func create(origin: Vector2, target: Vector2) -> Dictionary:
	return {"pos": origin, "vel": origin.direction_to(target) * 145.0, "radius": 10.0,
		"color": Color(0.95, 0.1, 0.45), "grazed": false, "age": 0.0, "style": "missile"}

static func create_super(origin: Vector2, target: Vector2) -> Dictionary:
	var carrier := create(origin, target)
	carrier["payload"] = "super"
	carrier["radius"] = 16.0
	carrier["vel"] = origin.direction_to(target) * 110.0
	carrier["armed_after"] = 0.0
	carrier["trigger_radius"] = 320.0
	return carrier

static func children(carrier: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(6):
		var direction := Vector2.from_angle(TAU * i / 6.0)
		var child := create(carrier["pos"], carrier["pos"] + direction)
		child["armed_after"] = 0.0
		result.append(child)
	return result

static func ready_to_split(bullet: Dictionary, player: Vector2) -> bool:
	return bullet.get("style", "") == "missile" and bullet["age"] >= bullet.get("armed_after", 0.5) and (bullet["pos"].distance_to(player) < bullet.get("trigger_radius", 240.0) or bullet["age"] >= 3.0)

static func fragments(bullet: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(8):
		result.append({"pos": bullet["pos"], "vel": Vector2.from_angle(TAU * i / 8.0) * 180.0,
			"radius": 5.0, "color": Color(1.0, 0.1, 0.5), "grazed": false, "age": 0.0, "style": "orb"})
	return result

static func draw_missile(game, bullet: Dictionary) -> void:
	var pos: Vector2 = bullet["pos"]
	var direction: Vector2 = bullet["vel"].normalized()
	var normal := direction.orthogonal()
	game.draw_line(pos - direction * 14.0, pos - direction * 30.0, Color(1.0, 0.1, 0.4, 0.45), 5.0, true)
	game.draw_colored_polygon(PackedVector2Array([pos + direction * 15.0, pos + normal * 10.0, pos - direction * 10.0, pos - normal * 10.0]), Color(0.5, 0.025, 0.12))
	game.draw_arc(pos, 10.0, 0.0, TAU, 16, Color(1.8, 0.15, 0.5), 2.0, true)
	game.draw_circle(pos, 4.0, Color(2.0, 1.1, 1.3))
	if bullet.get("payload", "pellet") == "super":
		game.draw_arc(pos, 17, 0, TAU, 32, Color(1, 0.2, 0.55), 3, true)
		for i in range(6):
			var axis := Vector2.from_angle(TAU * i / 6 + bullet["age"] * 0.7)
			var side := axis.orthogonal()
			var tip := pos + axis * 20
			game.draw_polyline(PackedVector2Array([tip + axis * 6 + side * 4, tip, tip + axis * 6 - side * 4]), Color(1, 0.6, 0.75), 2, true)
	if bullet.get("payload", "pellet") == "laser":
		for i in range(bullet.get("count", 5)):
			var spoke := Vector2.from_angle(TAU * i / bullet.get("count", 5))
			game.draw_line(pos + spoke * 10, pos + spoke * 15, Color(1, 0.7, 0.85), 1.5, true)
	if bullet["age"] > 0.0:
		var charge := clampf(bullet["age"] / maxf(0.001, bullet.get("armed_after", 0.5)), 0.0, 1.0)
		game.draw_arc(pos, 17.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 28, Color(1.0, 0.3, 0.6, 0.8), 1.5, true)
