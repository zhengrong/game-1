extends Node2D
var game: Node2D
## A separate material keeps procedural fire out of the beam and HUD passes.
const FIRE_SHADER = preload("res://combat/fire_volume.gdshader")
const QUAD = preload("res://combat/flare_texture.tres")

func _ready() -> void:
	var fire_material := ShaderMaterial.new()
	fire_material.shader = FIRE_SHADER
	material = fire_material

func _draw() -> void:
	if game.state == game.GameState.TITLE:
		return
	for particle in game.particles:
		if particle["kind"] in ["blast_ring", "energy_ring"]:
			var progress: float = clampf(1.0 - particle["life"] / particle["max_life"], 0.0, 1.0)
			var radius: float = particle["size"] * (0.28 + sqrt(progress) * 1.35)
			var size := Vector2.ONE * radius * 2.5
			draw_texture_rect(QUAD, Rect2(particle["pos"] - size * 0.5, size), false, Color(progress, particle.get("palette", 0.0), 2.0, 0.25 if game.paused else 1.0))
		if particle["kind"] == "ember":
			var trail: PackedVector2Array = particle["trail"]
			var energy: float = game.FireVisual.heat(particle) * (0.25 if game.paused else 1.0)
			if energy <= 0.0:
				continue
			var age: float = particle["max_life"] - particle["life"]
			for i in range(trail.size()):
				var freshness := float(i + 1) / maxf(1.0, trail.size())
				var size: Vector2 = Vector2.ONE * particle["size"] * (1.3 + freshness * 4.2)
				var tangent := particle["vel"] as Vector2
				if i + 1 < trail.size():
					tangent = trail[i + 1] - trail[i]
				var curl: Vector2 = tangent.normalized().orthogonal() * sin(age * 14.0 - i * 0.9) * particle["size"] * (1.0 - freshness) * 1.2
				draw_texture_rect(QUAD, Rect2(trail[i] + curl - size * 0.5, size), false, Color(age, i * 0.17, 1.0, energy * freshness * 0.6))
			var head_size: Vector2 = Vector2.ONE * particle["size"] * 5.0
			draw_texture_rect(QUAD, Rect2(particle["pos"] - head_size * 0.5, head_size), false, Color(age, 0.0, 1.0, energy))
		if particle["kind"] != "fire":
			continue
		var opacity: float = game.FireVisual.heat(particle) * (0.25 if game.paused else 1.0)
		if opacity <= 0.0:
			continue
		var age: float = particle["max_life"] - particle["life"]
		var burst: bool = particle.get("burst", false)
		var radius: float = particle["size"]
		var expansion := lerpf(0.65, 1.0, smoothstep(0.0, 0.10, age)) if burst else 1.0
		var size := Vector2(6.0, 5.6) * radius * expansion if burst else Vector2(6.2, 7.6) * radius
		var center: Vector2 = particle["pos"] + Vector2(0.0, 0.0 if burst else -radius * 0.75)
		var lean := 0.0 if burst else 0.32 + sin(age * 3.0 + particle.get("seed", 0.0)) * 0.10
		draw_set_transform(center, lean)
		draw_texture_rect(QUAD, Rect2(-size * 0.5, size), false, Color(age, particle.get("seed", 0.0), 1.0 if burst else 0.0, opacity))
		draw_set_transform(Vector2.ZERO)
