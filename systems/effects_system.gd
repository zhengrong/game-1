extends RefCounted
## Owns transient effects. No access to score, audio, input, or the scene tree.
const FireVisual = preload("res://combat/fire_visual.gd")
const TAU_F = TAU
var rng: RandomNumberGenerator
var particles: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []

func _spawn_sparks(origin: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var life := rng.randf_range(0.16, 0.44)
		particles.append({
			"kind": "spark",
			"pos": origin,
			"vel": Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(speed * 0.25, speed),
			"life": life,
			"max_life": life,
			"size": rng.randf_range(1.5, 4.2),
			"growth": -1.2,
			"drag": 0.08,
			"color": color,
		})


func _spawn_muzzle_flash(origin: Vector2) -> void:
	for i in range(6):
		var life := rng.randf_range(0.055, 0.14)
		particles.append({
			"kind": "plasma",
			"pos": origin + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-7.0, 3.0)),
			"vel": Vector2(rng.randf_range(-46.0, 46.0), rng.randf_range(-230.0, -95.0)),
			"life": life,
			"max_life": life,
			"size": rng.randf_range(3.0, 7.5),
			"growth": -28.0,
			"drag": 0.12,
			"color": Color(0.16, 0.82, 2.4),
		})
	_spawn_sparks(origin + Vector2(0.0, -4.0), Color(0.42, 1.25, 2.8), 3, 145.0)


func _spawn_player_impact(origin: Vector2, velocity: Vector2, overcharged: bool) -> void:
	var impact_color := Color(0.28, 0.86, 2.4)
	var spark_count := 9 if overcharged else 5
	_spawn_sparks(origin, impact_color, spark_count, 210.0 if overcharged else 145.0)
	var bloom_life := 0.18 if overcharged else 0.12
	particles.append({
		"kind": "plasma",
		"pos": origin,
		"vel": -velocity.normalized() * 26.0,
		"life": bloom_life,
		"max_life": bloom_life,
		"size": 11.0 if overcharged else 7.0,
		"growth": 24.0,
		"drag": 0.08,
		"color": Color(0.58, 1.35, 3.2),
	})
	shockwaves.append({
		"pos": origin,
		"radius": 2.0,
		"max": 25.0 if overcharged else 16.0,
		"life": 0.19 if overcharged else 0.13,
		"color": impact_color,
	})


func _spawn_thruster(origin: Vector2, color: Color, scale: float) -> void:
	var life := rng.randf_range(0.12, 0.21)
	particles.append({
		"kind": "plasma",
		"pos": origin + Vector2(rng.randf_range(-2.0, 2.0), 0.0),
		"vel": Vector2(rng.randf_range(-35.0, 35.0), rng.randf_range(150.0, 250.0)) * scale,
		"life": life,
		"max_life": life,
		"size": rng.randf_range(3.2, 6.0) * scale,
		"growth": rng.randf_range(3.0, 12.0) * scale,
		"drag": 0.32,
		"color": color,
	})
	if rng.randf() < 0.28:
		var ember_life := rng.randf_range(0.22, 0.45)
		particles.append({
			"kind": "spark",
			"pos": origin,
			"vel": Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(120.0, 290.0)) * scale,
			"life": ember_life,
			"max_life": ember_life,
			"size": rng.randf_range(0.8, 2.0) * scale,
			"growth": -0.5,
			"drag": 0.45,
			"color": Color(0.4, 1.7, 3.4),
		})


func _spawn_damage_fire(origin: Vector2, scale: float, source: Dictionary = {}) -> void:
	var fire_life := rng.randf_range(0.48, 0.75)
	particles.append({
		"kind": "fire",
		"source": source,
		"source_pos": source.get("pos", origin),
		"seed": rng.randf_range(0.0, TAU),
		"pos": origin,
		"vel": Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-50.0, -22.0)) * scale,
		"life": fire_life,
		"max_life": fire_life,
		"size": rng.randf_range(11.0, 19.0) * scale,
		"growth": rng.randf_range(7.0, 18.0) * scale,
		"drag": 0.28,
		"color": Color(3.2, 0.68, 0.08),
	})
	if rng.randf() < 0.52:
		var smoke_life := rng.randf_range(0.75, 1.35)
		particles.append({
			"kind": "smoke",
			"pos": origin,
			"vel": Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-75.0, -25.0)) * scale,
			"life": smoke_life,
			"max_life": smoke_life,
			"size": rng.randf_range(9.0, 16.0) * scale,
			"growth": rng.randf_range(14.0, 25.0) * scale,
			"drag": 0.58,
			"color": Color(0.14, 0.12, 0.16),
		})
	_spawn_sparks(origin, Color(2.8, 0.7, 0.1), 1, 120.0 * scale)


func _spawn_hot_fragments(origin: Vector2, count: int, speed: float) -> void:
	for i in range(count):
		var life := rng.randf_range(0.65, 1.05)
		var velocity := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(speed * 0.5, speed)
		particles.append({
			"kind": "ember", "pos": origin, "vel": velocity,
			"origin": origin, "initial_velocity": velocity, "turn_rate": rng.randf_range(-1.6, 1.6),
			"trail": PackedVector2Array([origin]), "trail_clock": 0.0,
			"life": life, "max_life": life, "size": rng.randf_range(3.0, 6.0),
			"growth": -1.5, "drag": 0.6, "color": Color(2.6, 0.8, 0.12),
		})


func _spawn_energy_burst(origin: Vector2, tint: Color, scale: float) -> void:
	# Presentation only: no damage, bullet clearing, or random-number sampling.
	var pink := tint.r > tint.b
	var core_life := 1.4 if pink else 0.36
	var ring_life := 1.5 if pink else 0.55
	particles.append({"kind": "energy_burst", "pos": origin, "vel": Vector2.ZERO,
		"life": core_life, "max_life": core_life, "size": scale, "growth": 0.0,
		"drag": 1.0, "color": tint, "pink": pink})
	particles.append({"kind": "energy_ring", "pos": origin, "vel": Vector2.ZERO,
		"life": ring_life, "max_life": ring_life, "size": 72.0 * scale, "growth": 0.0,
		"drag": 1.0, "color": tint, "palette": 1.0 if pink else 2.0})


func _spawn_explosion(origin: Vector2, color: Color, count: int, speed: float) -> void:
	var explosion_scale := clampf(speed / 180.0, 0.65, 1.8)
	particles.append({
		"kind": "blast_ring", "pos": origin, "vel": Vector2.ZERO,
		"life": 0.42, "max_life": 0.42, "size": 60.0 * explosion_scale,
		"growth": 0.0, "drag": 1.0, "color": Color.ORANGE,
	})
	_spawn_hot_fragments(origin, clampi(count / 3, 3, 10), speed * 1.2)
	particles.append({
		"kind": "ignition", "pos": origin, "vel": Vector2.ZERO,
		"life": 0.065, "max_life": 0.065, "size": explosion_scale,
		"growth": 0.0, "drag": 1.0, "color": Color.WHITE,
	})
	particles.append({
		"kind": "flare", "pos": origin, "vel": Vector2.ZERO,
		"life": 0.22, "max_life": 0.22, "size": explosion_scale * 1.45,
		"growth": 0.0, "drag": 1.0, "color": Color(1.8, 0.65, 0.12),
	})
	for i in range(count):
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU_F))
		if i % 6 == 0:
			var smoke_life := rng.randf_range(0.8, 1.65)
			particles.append({
				"kind": "smoke", "pos": origin + direction * rng.randf_range(0.0, 14.0),
				"vel": direction * rng.randf_range(speed * 0.04, speed * 0.19) + Vector2(0.0, -22.0),
				"life": smoke_life, "max_life": smoke_life, "size": rng.randf_range(11.0, 24.0) * explosion_scale,
				"growth": rng.randf_range(18.0, 34.0), "drag": 0.36, "color": Color(0.16, 0.12, 0.18),
			})
		elif i % 3 == 0:
			var fire_life := rng.randf_range(0.28, 0.72)
			particles.append({
				"kind": "fire", "burst": true, "seed": rng.randf_range(0.0, TAU), "pos": origin + direction * rng.randf_range(0.0, 10.0),
				"vel": direction * rng.randf_range(speed * 0.08, speed * 0.38),
				"life": fire_life, "max_life": fire_life, "size": rng.randf_range(10.0, 24.0) * explosion_scale,
				"growth": rng.randf_range(5.0, 18.0), "drag": 0.12, "color": Color(3.6, 0.58, 0.06),
			})
		else:
			var spark_life := rng.randf_range(0.35, 0.95)
			particles.append({
				"kind": "spark", "pos": origin + direction * rng.randf_range(0.0, 12.0),
				"vel": direction * rng.randf_range(speed * 0.18, speed),
				"life": spark_life, "max_life": spark_life, "size": rng.randf_range(0.8, 2.8) * sqrt(explosion_scale),
				"growth": -1.0, "drag": 0.08, "color": color.lightened(0.28),
			})
	# A compact white-hot ignition flash gives the explosion physical punch.
	for i in range(4):
		var core_life := rng.randf_range(0.12, 0.24)
		particles.append({
			"kind": "fire", "burst": true, "seed": rng.randf_range(0.0, TAU), "pos": origin + Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(0.0, 7.0),
			"vel": Vector2.ZERO, "life": core_life, "max_life": core_life,
			"size": rng.randf_range(16.0, 30.0) * explosion_scale, "growth": 34.0 * explosion_scale, "drag": 0.1, "color": Color(5.0, 2.2, 0.5),
		})


func _update_particles(delta: float, enemies: Array[Dictionary]) -> void:
	# Stable compaction preserves transparent draw order without shifting the
	# remaining array for every expired particle. This pass never spawns particles.
	var alive := 0
	for i in range(particles.size()):
		var particle := particles[i]
		var previous: Vector2 = particle["pos"]
		particle["life"] -= delta
		if particle["kind"] == "ember":
			FireVisual.advance_fragment(particle)
			FireVisual.update_trail(particle, previous, delta)
		else:
			var velocity: Vector2 = particle["vel"]
			if velocity != Vector2.ZERO:
				particle["pos"] += velocity * delta
				particle["vel"] = velocity * pow(particle["drag"], delta)
			var source: Dictionary = particle.get("source", {})
			if not source.is_empty():
				var age: float = particle["max_life"] - particle["life"]
				if age < 0.28 and enemies.has(source):
					particle["pos"] += source["pos"] - particle["source_pos"]
					particle["source_pos"] = source["pos"]
				else:
					particle["source"] = {}
		particle["size"] = maxf(0.1, particle["size"] + particle["growth"] * delta)
		if particle["life"] <= 0.0 and particle["kind"] == "ember":
			# Keep the sampled smoke path after the hot fragment has gone.
			# Include overshoot so a long update cannot resurrect expired effects.
			particle["kind"] = "ember_wake"
			particle["smoke_age"] = particle["max_life"]
			particle["life"] += 0.55
			particle["max_life"] = 0.55
			particle["vel"] = Vector2.ZERO
			particle["growth"] = 5.0
		if particle["life"] > 0.0:
			if alive != i:
				particles[alive] = particle
			alive += 1
	particles.resize(alive)


func _update_shockwaves(delta: float) -> void:
	for i in range(shockwaves.size() - 1, -1, -1):
		var ring := shockwaves[i]
		ring["life"] -= delta
		ring["radius"] = lerpf(ring["radius"], ring["max"], 1.0 - exp(-delta * 8.0))
		if ring["life"] <= 0.0:
			shockwaves.remove_at(i)


