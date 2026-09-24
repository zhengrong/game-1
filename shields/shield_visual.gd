extends RefCounted
## Deterministic additive rims: deployment, hit flash, weakening, and collapse.
const Config = preload("res://shields/shield_config.gd")
static func draw(canvas: Node2D, system, energy: float, capacity: float, rays: Array[Dictionary]) -> void:
	if system.config.personal_enabled and (system.charge > 0.0 or system.protected()):
		var radius: float = system.config.personal_radius
		if system.charge > 0.0:
			var fill: float = clampf(system.charge / maxf(0.001, system.config.personal_charge + system.penalty), 0.0, 1.0)
			canvas.draw_arc(system.position, radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 64, Color(1.0, 1.6, 2.0, 0.8), 3.0, true)
	if system.config.aura == Config.Aura.PHALANX:
		var charges: int = system.config.phalanx_charges
		for i in range(charges):
			var rows := ceili(charges / 2.0)
			var column := i / rows
			var row := i % rows
			var point: Vector2 = system.position + Vector2(-110.0 if column == 0 else 110.0, 100.0 - row * 70.0)
			var fill := clampf(energy / maxf(0.001, capacity) * charges - i, 0.0, 1.0)
			var lit := fill >= 1.0
			var tint := Color(0.8, 0.3, 1.5, 0.85 if lit else 0.22)
			canvas.draw_arc(point, 21, -PI * 0.5, TAU - PI * 0.5, 6, tint, 1.5, true)
			canvas.draw_arc(point, 16, 0, TAU, 32, tint, 1.0, true)
			if fill > 0.0:
				canvas.draw_arc(point, 16, -PI * 0.5, -PI * 0.5 + TAU * fill, 32, Color(1.1, 0.4, 1.7, 0.6), 2.0, true)
			if lit:
				canvas.draw_texture_rect(preload("res://combat/flare_texture.tres"), Rect2(point - Vector2.ONE * 48, Vector2.ONE * 96), false, Color(0.65, 0.12, 1.5, 0.65))
				canvas.draw_circle(point, 10, Color(1.3, 0.55, 1.8, 0.7))
				canvas.draw_arc(point, 8, system.visual_time, TAU + system.visual_time, 6, Color(1.8, 1.2, 2.0, 0.8), 1.5, true)
				canvas.draw_line(point - Vector2(46, 0), point + Vector2(46, 0), Color(0.8, 0.25, 1.4, 0.25), 1, true)
				var pulse: float = system.charge_pulses.get(i, 0.0) / 0.45
				if pulse > 0.0:
					canvas.draw_arc(point, 22 + (1.0 - pulse) * 26, 0, TAU, 48, Color(1.1, 0.4, 1.8, pulse * 0.7), 3 * pulse, true)

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
