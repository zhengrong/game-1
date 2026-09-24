extends RefCounted
## A locked warning is shown before a ray becomes harmful.
static func create(origin: Vector2, angle: float, warning: float, duration: float, width: float) -> Dictionary:
	return {"start": origin, "end": origin + Vector2.from_angle(angle) * 1800.0,
		"age": 0.0, "warning": warning, "duration": duration, "width": width}

static func active_time(ray: Dictionary, delta: float) -> float:
	var previous: float = ray["age"]
	ray["age"] += delta
	return maxf(0.0, minf(ray["age"], ray["warning"] + ray["duration"]) - maxf(previous, ray["warning"]))

static func draw(canvas: Node2D, ray: Dictionary) -> void:
	var start: Vector2 = ray["start"]
	var end: Vector2 = ray.get("blocked_end", ray["end"])
	if ray["age"] < ray["warning"]:
		canvas.draw_line(start, end, Color(1, 0.8, 0.8, 0.3), 1.0, true)
		canvas.draw_arc(start, 10, 0, TAU * ray["age"] / maxf(0.001, ray["warning"]), 24, Color(1, 0.4, 0.4), 2, true)
	else:
		var width: float = ray["width"]
		canvas.draw_line(start, end, Color(1, 0.03, 0.1, 0.18), width * 2.0, true)
		canvas.draw_line(start, end, Color(1, 0.02, 0.06), width, true)
		canvas.draw_line(start, end, Color(1, 0.85, 0.7), maxf(1, width * 0.25), true)
