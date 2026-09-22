extends RefCounted
## Deterministic additive rims: deployment, hit flash, weakening, and collapse.
const Config = preload("res://shields/shield_config.gd")
static func draw(canvas: Node2D, system, energy: float, capacity: float, rays: Array[Dictionary]) -> void:
	if system.config.personal_enabled and (system.charge > 0.0 or system.protected()):
		var alpha: float = 1.0 if system.personal > 0.0 else (system.fade / maxf(0.001, system.config.personal_fade) if system.fade > 0.0 else 0.25)
		var radius: float = system.config.personal_radius
		var activation: float = clampf((system.config.personal_duration - system.personal) / 0.22, 0.0, 1.0) if system.personal > 0.0 else 1.0
		surface(canvas, system.position, radius, PI, Color(0.22, 0.85, 1.8), alpha, system.visual_time, activation, system.fade > 0.0)
		if system.charge > 0.0:
			var fill: float = clampf(system.charge / maxf(0.001, system.config.personal_charge + system.penalty), 0.0, 1.0)
			canvas.draw_arc(system.position, radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 64, Color(1.0, 1.6, 2.0, 0.8), 3.0, true)
	for field in system.fields:
		var mobile: bool = field["kind"] == Config.Aura.PHALANX
		var center: Vector2 = system.position if mobile else field["center"]
		var fraction: float = maxf(0.0, field["strength"] / field["maximum"])
		var alpha: float = clampf(field["fade"] / maxf(0.001, system.config.phalanx_fade if mobile else system.config.barrier_fade), 0.0, 1.0) if field["fading"] else 1.0
		var color := Color(0.65, 0.25, 1.5) if fraction >= 0.5 else (Color(1.5, 0.18, 0.7) if fraction >= 1.0 / 6.0 else Color(1.8, 0.08, 0.12))
		var half: float = deg_to_rad(system.config.phalanx_half_angle) if mobile else PI
		var radius: float = field["radius"]
		var activation: float = clampf(float(field.get("age", 0.0)) / 0.25, 0.0, 1.0)
		surface(canvas, center, radius, half, color, alpha, system.visual_time, activation, field["fading"])
	if system.config.aura == Config.Aura.PHALANX:
		var charges: int = system.config.phalanx_charges
		for i in range(charges):
			var point: Vector2 = system.position + Vector2((i - (charges - 1) * 0.5) * 25.0, 50.0)
			var lit := energy / maxf(0.001, capacity) * charges >= i + 1
			canvas.draw_arc(point, 8, 0, TAU, 6, Color(1.0, 0.3, 1.4, 0.85 if lit else 0.15), 2.0, true)
	for flash in system.flashes:
		var t: float = clampf(1.0 - flash["life"] / 0.32, 0.0, 1.0)
		var point: Vector2 = system.position + flash["offset"] if flash.get("mobile", false) else flash["pos"]
		var glow := Color(0.5, 1.2, 2.0, (1.0 - t) * 0.6)
		canvas.draw_arc(point, 4.0 + t * 28.0, 0, TAU, 32, glow, 3.0 * (1.0 - t) + 0.5, true)
		canvas.draw_arc(point, 2.0 + t * 17.0, 0, TAU, 24, Color(0.9, 1.5, 2.0, (1.0 - t) * 0.5), 1.0, true)
		canvas.draw_circle(point, 6.0 * (1.0 - t), Color(1.8, 1.7, 2.0, (1.0 - t) * (1.0 - t)))
	for ray in rays:
		canvas.draw_line(ray["start"], ray["end"], Color(0.2, 0.6, 1.8, 0.25), 10.0, true)
		canvas.draw_line(ray["start"], ray["end"], Color(1.1, 1.6, 2.4), 2.0, true)


## Layered curved membrane; the outer boundary always stays at the collision radius.
## No RNG or gameplay mutation in rendering.
static func surface(canvas: Node2D, center: Vector2, radius: float, half: float, tint: Color, alpha: float, time: float, activation: float, breaking: bool) -> void:
	var segments := 64 if half > 2.0 else 28
	var start := -PI * 0.5 - half
	var step := half * 2.0 / segments
	var mobile_arc := half < 2.0
	# Translucent cells give the field volume without hiding bullets or the ship.
	var rings := 4
	var inner := 0.55 if mobile_arc else 0.15
	for ring in range(rings):
		var r0 := radius * lerpf(inner, 1.0, float(ring) / rings)
		var r1 := radius * lerpf(inner, 1.0, float(ring + 1) / rings)
		for i in range(segments):
			var angle := start + i * step
			var pulse := 0.5 + 0.5 * sin(angle * 7.0 + ring * 1.8 - time * 2.8)
			var opacity := alpha * (0.018 + 0.038 * pulse + 0.035 * float(ring) / rings)
			var points := PackedVector2Array([
				center + Vector2.from_angle(angle) * r0,
				center + Vector2.from_angle(angle + step) * r0,
				center + Vector2.from_angle(angle + step) * r1,
				center + Vector2.from_angle(angle) * r1])
			canvas.draw_colored_polygon(points, Color(tint, opacity))
			if i % 4 == ring:
				canvas.draw_line(points[0], points[3], Color(tint, alpha * 0.12), 0.7, true)
	# Broad edge glow and a finely undulating inner filament.
	canvas.draw_arc(center, radius, start, start + half * 2.0, segments + 1, Color(tint, alpha * 0.08), 16.0, true)
	canvas.draw_arc(center, radius, start, start + half * 2.0, segments + 1, Color(tint, alpha * 0.22), 6.0, true)
	for i in range(segments):
		var angle := start + i * step
		var brightness := 0.55 + 0.25 * sin(angle * 5.0 - time * 3.0)
		if breaking and i % 3 == 0:
			continue
		var a := center + Vector2.from_angle(angle) * radius
		var b := center + Vector2.from_angle(angle + step) * radius
		canvas.draw_line(a, b, Color(tint.lightened(0.45), alpha * brightness), 1.5, true)
		var inset := 3.0 + sin(angle * 12.0 + time * 5.0) * 1.4
		canvas.draw_line(center + Vector2.from_angle(angle) * (radius - inset),
			center + Vector2.from_angle(angle + step) * (radius - inset), Color(tint, alpha * 0.4), 1.0, true)
		if breaking and i % 3 == 1:
			var outward := Vector2.from_angle(angle)
			var drift := (1.0 - alpha) * 24.0
			canvas.draw_line(a + outward * drift, a + outward * (drift + 5.0), Color(tint, alpha), 2.0, true)
	# A luminous front travels across the membrane as it deploys.
	if activation < 1.0:
		canvas.draw_arc(center, maxf(1.0, radius * activation), start, start + half * 2.0,
			segments + 1, Color(tint.lightened(0.65), alpha * (1.0 - activation) * 0.8), 3.0, true)
	if mobile_arc:
		for angle in [start, start + half * 2.0]:
			var tip := center + Vector2.from_angle(angle) * radius
			canvas.draw_circle(tip, 3.0, Color(tint.lightened(0.6), alpha * 0.9))
