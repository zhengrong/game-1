extends RefCounted
## Fire has volume, a cooling lifetime, and actual fragment trails.
## Draw routines are deterministic and do not modify combat or particle state.
const SMOKE = preload("res://assets/effects/smoke.png")
const TRAIL_STEP := 0.025
const TRAIL_LIMIT := 12

static func heat(particle: Dictionary) -> float:
	var ratio: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
	return smoothstep(0.12, 0.8, ratio)

static func advance_fragment(particle: Dictionary) -> void:
	# Integrate a turning, exponentially slowing velocity analytically.
	# The trajectory depends on age, not the number of update calls.
	var age: float = particle["max_life"] - particle["life"]
	var decay := log(maxf(0.001, particle["drag"]))
	var turn: float = particle["turn_rate"]
	var denominator := decay * decay + turn * turn
	var factor := exp(decay * age)
	var offset := Vector2(age, 0.0)
	if denominator > 0.000001:
		offset = Vector2(
			factor * (decay * cos(turn * age) + turn * sin(turn * age)) - decay,
			factor * (decay * sin(turn * age) - turn * cos(turn * age)) + turn) / denominator
	var velocity: Vector2 = particle["initial_velocity"]
	particle["pos"] = particle["origin"] + offset.rotated(velocity.angle()) * velocity.length()
	particle["vel"] = velocity.rotated(turn * age) * factor

static func update_trail(particle: Dictionary, previous: Vector2, delta: float) -> void:
	var trail: PackedVector2Array = particle["trail"]
	var clock: float = particle["trail_clock"]
	var total := clock + delta
	var steps := int(floor((total + 0.000001) / TRAIL_STEP))
	# Keep sampling boundaries stable at 30/60/120 Hz; modulo on a nearly
	# exact boundary can otherwise duplicate points at some refresh rates.
	for sample_index in range(maxi(0, steps - TRAIL_LIMIT), steps):
		var sample_time := (sample_index + 1) * TRAIL_STEP - clock
		trail.append(previous.lerp(particle["pos"], clampf(sample_time / maxf(delta, 0.000001), 0.0, 1.0)))
		if trail.size() > TRAIL_LIMIT:
			trail.remove_at(0)
	particle["trail_clock"] = maxf(0.0, total - steps * TRAIL_STEP)
	particle["trail"] = trail

static func puff(canvas: Node2D, texture: Texture2D, center: Vector2, size: Vector2, tint: Color) -> void:
	canvas.draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, tint)

static func draw_smoke(canvas: Node2D, particle: Dictionary) -> void:
	var energy := heat(particle)
	var age: float = particle["max_life"] - particle["life"]
	var ratio: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
	age += particle.get("smoke_age", 0.0)
	var radius: float = particle["size"]
	if particle["kind"] in ["ember", "ember_wake"]:
		var trail: PackedVector2Array = particle["trail"]
		var wake: bool = particle["kind"] == "ember_wake"
		var cooling := ratio if wake else (1.0 - energy)
		if cooling <= 0.0:
			return
		for i in range(0, trail.size(), 3):
			var freshness := float(i + 1) / maxf(1.0, trail.size())
			var drift := Vector2(sin(i + age * 2.0) * age * 6.0, -age * 18.0)
			var spread := radius * (4.0 + age * 2.0 + (1.0 - freshness) * 3.0)
			puff(canvas, SMOKE, trail[i] + drift, Vector2(spread, spread * 1.3), Color(0.26, 0.23, 0.20, cooling * 0.32))
		return
	var opacity := (1.0 - energy) * minf(1.0, ratio * 5.0) * 0.45
	if opacity <= 0.0:
		return
	var center: Vector2 = particle["pos"] + Vector2(0, -age * 28.0)
	var size := radius * (3.4 + age * 3.0)
	for lobe in range(3):
		var phase := age * 2.2 + lobe * 2.1
		var offset := Vector2(sin(phase) * radius * 0.5, -lobe * radius * 0.65)
		puff(canvas, SMOKE, center + offset, Vector2(size, size * 1.15) * (1.0 - lobe * 0.12), Color(0.23, 0.20, 0.17, opacity * 0.5))
