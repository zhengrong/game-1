extends RefCounted
## Charged area bomb or Super MIRV launcher; gameplay routing stays in the scene.
static func create(source: Dictionary, kind: String, warning: float, radius: float, count: int = 3) -> Dictionary:
	return {"source": source, "pos": source["pos"], "kind": kind, "warning": maxf(0.1, warning),
		"radius": radius, "count": count, "age": 0.0, "duration": 0.3, "fired": false, "just_fired": false}

static func advance(effect: Dictionary, delta: float) -> float:
	var previous: float = effect["age"]
	if not effect["fired"]:
		effect["pos"] = effect["source"]["pos"]
	effect["age"] += delta
	effect["just_fired"] = not effect["fired"] and effect["age"] >= effect["warning"]
	if effect["just_fired"]:
		effect["fired"] = true
	return maxf(0.0, minf(effect["age"], effect["warning"] + effect["duration"]) - maxf(previous, effect["warning"]))

static func draw(canvas: Node2D, effect: Dictionary) -> void:
	var center: Vector2 = effect["pos"]
	var radius: float = effect["radius"] if effect["kind"] == "bomb" else 45.0
	var charge: float = clampf(effect["age"] / effect["warning"], 0, 1)
	if not effect["fired"]:
		canvas.draw_circle(center, radius, Color(1, 0.015, 0.045, 0.025 + charge * 0.045))
		canvas.draw_arc(center, radius, 0, TAU, 96, Color(1, 0.05, 0.1, 0.7), 2, true)
		canvas.draw_arc(center, 23, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(1, 0.65, 0.6), 4, true)
		for i in range(12):
			var direction := Vector2.from_angle(TAU * i / 12)
			var tip := center + direction * radius
			canvas.draw_line(tip, tip - direction * 10, Color(1, 0.08, 0.15), 2, true)
		canvas.draw_circle(center, 6 + charge * 7, Color(1, 0.2 + charge * 0.5, 0.2, 0.9))
	else:
		var t: float = clampf((effect["age"] - effect["warning"]) / effect["duration"], 0, 1)
		canvas.draw_circle(center, radius, Color(1, 0.06, 0.1, (1 - t) * 0.12))
		canvas.draw_arc(center, radius, 0, TAU, 96, Color(1, 0.2, 0.15, 1 - t), 3, true)
		canvas.draw_arc(center, radius * sqrt(t), 0, TAU, 96, Color(1, 0.7, 0.45, 1 - t), 8 * (1 - t) + 1, true)
