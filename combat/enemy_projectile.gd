extends RefCounted
## Projectile motion is independent of its renderer and firing turret.
static func create(origin: Vector2, velocity: Vector2, radius: float, color: Color, style: String, curve: float = 0.0) -> Dictionary:
	return {"pos": origin, "origin": origin, "vel": velocity, "initial_velocity": velocity,
		"radius": radius, "color": color, "style": style, "curve": curve,
		"age": 0.0, "grazed": false}

static func advance(bullet: Dictionary, delta: float) -> void:
	bullet["age"] += delta
	var style: String = bullet.get("style", "capsule")
	if style not in ["shuriken", "boomerang"]:
		bullet["pos"] += bullet["vel"] * delta
		return
	if not bullet.has("origin"):
		bullet["origin"] = bullet["pos"]
		bullet["initial_velocity"] = bullet["vel"]
	var age: float = bullet["age"]
	var velocity: Vector2 = bullet["initial_velocity"]
	if style == "shuriken":
		# Fast muzzle exit settles into a slower drifting cloud.
		var distance := 0.28 * age + 0.72 * (1.0 - exp(-age * 3.0)) / 3.0
		bullet["pos"] = bullet["origin"] + velocity * distance
		bullet["vel"] = velocity * (0.28 + 0.72 * exp(-age * 3.0))
	else:
		# Split launchers curve their two lanes apart; straight launchers set zero.
		var curve: float = bullet.get("curve", 0.0)
		var time := minf(age, 0.85)
		var angle := curve * time
		var offset := Vector2(time, 0.0) if absf(curve) < 0.001 else Vector2(sin(angle), 1.0 - cos(angle)) / curve
		offset += Vector2.from_angle(angle) * maxf(0.0, age - time)
		bullet["pos"] = bullet["origin"] + offset.rotated(velocity.angle()) * velocity.length()
		bullet["vel"] = velocity.rotated(angle)
