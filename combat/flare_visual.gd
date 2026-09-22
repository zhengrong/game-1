extends Node2D
## Additive light only: reads combat state and never advances timers or RNG.
const LIGHT = preload("res://combat/flare_texture.tres")
var game: Node2D

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	if game.state == game.GameState.TITLE:
		return
	# Pause keeps the underlying flash frozen but lets the pause UI dominate.
	modulate.a = 0.25 if game.paused else 1.0
	if game.state == game.GameState.PLAYING and game.player_hp > 0:
		var engine := 0.7 + sin(game.elapsed * 42.0) * 0.08
		for side in [-1.0, 1.0]:
			var port: Vector2 = game.player_pos + Vector2(side * game.PLAYER_ENGINE_SPREAD, game.PLAYER_ENGINE_Y)
			light(port + Vector2(0, 12), Vector2(21, 66), Color(0.08, 0.55, 1.6, engine))
			light(port, Vector2(12, 20), Color(1.2, 1.8, 2.0, engine))
		game._draw_player_beam(self)
	for shot in game.player_bullets:
		if shot.get("style", "") != "twin" or shot.get("delay", 0.0) > 0.0:
			continue
		var head: Vector2 = shot["pos"]
		var tail_length: float = minf(220.0, shot["age"] * 2100.0)
		var tail := PackedVector2Array()
		for i in range(13):
			var t := float(i) / 12.0
			tail.append(head + Vector2(sin(t * 22.0 - shot["age"] * 24.0) * 5.0 * t, t * tail_length))
		for i in range(1, tail.size()):
			var fade := pow(1.0 - float(i) / tail.size(), 2.0)
			draw_line(tail[i - 1], tail[i], Color(0.08, 0.25, 1.8, fade * 0.12), 6.0, true)
			draw_line(tail[i - 1], tail[i], Color(0.3, 0.85, 2.0, fade * 0.55), 1.2, true)
		light(head, Vector2(58, 160), Color(0.12, 0.65, 2.3, 0.75))
		light(head, Vector2(24, 110), Color(1.6, 2.1, 2.8, 1.0))
		var blade := PackedVector2Array([head + Vector2(0, -48), head + Vector2(9, -13), head + Vector2(5, 28), head + Vector2(0, 46), head + Vector2(-5, 28), head + Vector2(-9, -13)])
		draw_colored_polygon(blade, Color(1.6, 2.0, 2.5, 0.9))
	for particle in game.particles:
		if particle["kind"] == "energy_burst":
			var age: float = particle["max_life"] - particle["life"]
			var pink: bool = particle["pink"]
			var sustain := 1.0 - smoothstep(0.9 if pink else 0.04, particle["max_life"], age)
			var size: float = particle["size"]
			if pink:
				size *= lerpf(0.30, 1.30, smoothstep(0.0, 0.75, age))
			var tint: Color = particle["color"]
			var center: Vector2 = particle["pos"]
			light(center, Vector2.ONE * 290.0 * size, Color(tint, sustain * 0.32))
			light(center, Vector2.ONE * (190.0 if pink else 110.0) * size, Color(tint * 1.8, sustain))
			light(center, Vector2.ONE * (200.0 if pink else 65.0) * size, Color(3.0, 2.8, 3.1, sustain))
			for ray in range(18):
				var angle := ray * TAU / 18.0 + sin(ray * 3.7) * 0.10
				var direction := Vector2.from_angle(angle)
				var length := size * (48.0 + sin(ray * 5.1) * 18.0 + age * 45.0)
				draw_line(center + direction * size * 17.0, center + direction * length, Color(tint.lightened(0.6), sustain * 0.42), 1.1, true)
		if particle["kind"] == "ignition":
			var remaining: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
			var size: float = particle["size"]
			light(particle["pos"], Vector2(120, 185) * size, Color(2.0, 2.1, 2.3, remaining * 0.9))
			light(particle["pos"], Vector2(250, 280) * size, Color(0.7, 0.65, 0.38, remaining * 0.18))
		if particle["kind"] == "flare":
			var remaining: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
			# Fast ignition, expanding halo, then a steep falloff before smoke.
			var size: float = particle["size"] * (1.0 + (1.0 - remaining) * 0.7)
			flare(particle["pos"], size, particle["color"], remaining * remaining)

func light(center: Vector2, size: Vector2, tint: Color) -> void:
	draw_texture_rect(LIGHT, Rect2(center - size * 0.5, size), false, tint)

func flare(center: Vector2, size: float, tint: Color, strength: float) -> void:
	# Smooth lobes, a long optical streak, and a compact white-hot source.
	light(center, Vector2(190, 140) * size, Color(tint, strength * 0.4))
	light(center, Vector2(360, 4) * size, Color(tint, strength * 0.4))
	light(center, Vector2(140, 12) * size, Color(tint, strength * 0.65))
	light(center, Vector2(10, 78) * size, Color(tint, strength * 0.48))
	light(center, Vector2(34, 34) * size, Color(tint, strength * 0.85))
	light(center, Vector2(26, 23) * size, Color(2.3, 2.6, 2.8, strength))
