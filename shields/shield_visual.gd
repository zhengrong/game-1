extends RefCounted
## Deterministic additive rims: deployment, hit flash, weakening, and collapse.
const Config = preload("res://shields/shield_config.gd")
static func draw(canvas: Node2D, system, energy: float, capacity: float, rays: Array[Dictionary]) -> void:
	if system.config.personal_enabled and (system.charge > 0.0 or system.protected()):
		var alpha: float = 1.0 if system.personal > 0.0 else (system.fade / maxf(0.001, system.config.personal_fade) if system.fade > 0.0 else 0.25)
		var radius: float = system.config.personal_radius
		canvas.draw_circle(system.position, radius, Color(0.08, 0.22, 0.8, alpha * 0.09))
		canvas.draw_arc(system.position, radius, 0.0, TAU, 80, Color(0.25, 0.65, 1.7, alpha * 0.35), 9.0, true)
		canvas.draw_arc(system.position, radius, 0.0, TAU, 80, Color(0.65, 1.35, 2.0, alpha), 2.0, true)
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
		canvas.draw_arc(center, radius, -PI * 0.5 - half, -PI * 0.5 + half, 80, Color(color, alpha * 0.20), 14.0, true)
		canvas.draw_arc(center, radius, -PI * 0.5 - half, -PI * 0.5 + half, 80, Color(color, alpha * 0.9), 3.0, true)
		canvas.draw_arc(center, radius - 3.0, -PI * 0.5 - half, -PI * 0.5 + half, 80, Color(1.4, 0.85, 1.6, alpha * 0.5), 1.0, true)
		for i in range(20):
			var angle: float = -PI * 0.5 - half + i / 19.0 * half * 2.0
			var point := center + Vector2.from_angle(angle) * radius
			canvas.draw_line(point, center + Vector2.from_angle(angle) * (radius - 8), Color(color, alpha * 0.35), 1.0, true)
	if system.config.aura == Config.Aura.PHALANX:
		var charges: int = system.config.phalanx_charges
		for i in range(charges):
			var point: Vector2 = system.position + Vector2((i - (charges - 1) * 0.5) * 25.0, 50.0)
			var lit := energy / maxf(0.001, capacity) * charges >= i + 1
			canvas.draw_arc(point, 8, 0, TAU, 6, Color(1.0, 0.3, 1.4, 0.85 if lit else 0.15), 2.0, true)
	for flash in system.flashes:
		canvas.draw_circle(flash["pos"], 7.0, Color(1.8, 1.1, 2.0, flash["life"] / 0.12))
	for ray in rays:
		canvas.draw_line(ray["start"], ray["end"], Color(0.2, 0.6, 1.8, 0.25), 10.0, true)
		canvas.draw_line(ray["start"], ray["end"], Color(1.1, 1.6, 2.4), 2.0, true)
