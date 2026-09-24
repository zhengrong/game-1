extends RefCounted
## Emits projectile requests; never accesses the game scene or advances movement.
const Profile = preload("res://missions/enemy_weapon_definition.gd")
signal aimed(origin: Vector2, speed: float, color: Color, radius: float, style: String)
signal fan(origin: Vector2, count: int, spread: float, speed: float, color: Color, radius: float, style: String)
signal radial(origin: Vector2, count: int, speed: float, rotation: float, color: Color, radius: float, style: String)
signal missile(origin: Vector2)
signal projectile(bullet: Dictionary)
signal laser(ray: Dictionary)
signal doomsday(effect: Dictionary)
const Doomsday = preload("res://combat/doomsday_effect.gd")
const Laser = preload("res://combat/enemy_laser.gd")
const Missile = preload("res://combat/missile.gd")
const Projectile = preload("res://combat/enemy_projectile.gd")

func fire(enemy: Dictionary, profile: Profile, rng: RandomNumberGenerator, target: Vector2 = Vector2.ZERO, delta: float = 0.0) -> void:
	if profile.pattern == Profile.Pattern.BURST:
		_fire_burst(enemy, profile, target, delta)
		return
	if enemy["fire"] > 0.0 or profile.pattern == Profile.Pattern.NONE:
		return
	var origin: Vector2 = enemy["pos"]
	match profile.pattern:
		Profile.Pattern.DOOM_BOMB, Profile.Pattern.SUPER_MIRV:
			var kind := "bomb" if profile.pattern == Profile.Pattern.DOOM_BOMB else "super"
			doomsday.emit(Doomsday.create(enemy, kind, profile.charge_time, profile.bomb_radius, profile.count))
			enemy["fire"] = maxf(profile.cooldown, profile.charge_time + 0.3)
		Profile.Pattern.LASER:
			var angle: float = profile.fixed_angle if profile.aiming == Profile.Aim.FIXED else origin.direction_to(target).angle()
			var ray := Laser.create(origin, angle, profile.laser_warning, profile.laser_duration, profile.laser_width)
			ray["source"] = enemy
			laser.emit(ray)
			enemy["fire"] = maxf(profile.cooldown, profile.laser_warning + profile.laser_duration)
		Profile.Pattern.LASER_MIRV:
			var carrier := Missile.create(origin, target)
			carrier["payload"] = "laser"
			carrier["count"] = 5 if profile.tier == 1 else 9
			projectile.emit(carrier)
			enemy["fire"] = profile.cooldown
		Profile.Pattern.AIMED:
			aimed.emit(origin, profile.speed, profile.color, profile.radius, profile.projectile_style)
			enemy["fire"] = rng.randf_range(profile.cooldown, profile.cooldown_max)
		Profile.Pattern.SPINNER_CYCLE:
			if int(enemy["age"] / 1.65) % 3 == 0:
				missile.emit(origin)
			else:
				radial.emit(origin, 9, 180.0, enemy["age"] * 0.75, Color(1.0, 0.16, 0.04), 6.5, "orb")
			enemy["fire"] = 1.65
		Profile.Pattern.BOSS_CYCLE:
			_fire_boss(enemy)
		Profile.Pattern.FAN:
			fan.emit(origin, profile.count, profile.spread, profile.speed, profile.color, profile.radius, profile.projectile_style)
			enemy["fire"] = profile.cooldown
		Profile.Pattern.RADIAL:
			radial.emit(origin, profile.count, profile.speed, enemy["age"] * 0.75, profile.color, profile.radius, profile.projectile_style)
			enemy["fire"] = profile.cooldown
		Profile.Pattern.MISSILE:
			missile.emit(origin)
			enemy["fire"] = profile.cooldown

func _fire_boss(enemy: Dictionary) -> void:
	var health_ratio: float = enemy["hp"] / enemy["max_hp"]
	if health_ratio < 0.45 and enemy["age"] >= enemy.get("next_doom", 4.0):
		var phase: int = enemy.get("doom_phase", 0)
		if phase == 0:
			var doom = preload("res://missions/weapons/doomsday_laser.tres")
			var ray := Laser.create(enemy["pos"], PI * 0.5, doom.laser_warning, doom.laser_duration, doom.laser_width)
			ray["source"] = enemy
			laser.emit(ray)
		else:
			var profile = preload("res://missions/weapons/doomsday_bomb.tres") if phase == 1 else preload("res://missions/weapons/super_mirv.tres")
			doomsday.emit(Doomsday.create(enemy, "bomb" if phase == 1 else "super", profile.charge_time, profile.bomb_radius, profile.count))
		enemy["doom_phase"] = (phase + 1) % 3
		enemy["next_doom"] = enemy["age"] + 5.0
	var cycle := int(enemy["age"] * 0.75) % 3
	if cycle == 0:
		radial.emit(enemy["pos"] + Vector2(0.0, 42.0), 18 if health_ratio > 0.45 else 24, 205.0, enemy["age"] * 0.42, Color(1.0, 0.16, 0.04), 7.0, "orb")
		enemy["fire"] = 0.82 if health_ratio > 0.45 else 0.58
	elif cycle == 1:
		fan.emit(enemy["pos"] + Vector2(-52.0, 34.0), 7, 0.13, 285.0, Color(1.0, 0.45, 0.04), 7.0, "dart")
		fan.emit(enemy["pos"] + Vector2(52.0, 34.0), 7, 0.13, 285.0, Color(1.0, 0.45, 0.04), 7.0, "dart")
		enemy["fire"] = 1.02
	else:
		for offset in [-58.0, 0.0, 58.0]:
			aimed.emit(enemy["pos"] + Vector2(offset, 38.0), 340.0, Color(1.0, 0.06, 0.35), 8.0, "lance")
		enemy["fire"] = 0.48

func _fire_burst(enemy: Dictionary, profile: Profile, target: Vector2, delta: float) -> void:
	var wanted: float = enemy["pos"].direction_to(target).angle()
	var angle: float = enemy.get("weapon_angle", profile.fixed_angle)
	match profile.aiming:
		Profile.Aim.FIXED:
			angle = profile.fixed_angle
		Profile.Aim.SPINNING:
			angle += profile.turn_speed * delta
		_:
			if profile.aiming == Profile.Aim.TRACKING or enemy.get("burst_left", 0) == 0:
				angle = rotate_toward(angle, wanted, profile.turn_speed * delta)
	enemy["weapon_angle"] = angle
	if enemy["fire"] > 0.0:
		return
	var emitted := 0
	while enemy["fire"] <= 0.0 and emitted < 32:
		emitted += 1
		if enemy.get("burst_left", 0) == 0:
			enemy["burst_left"] = maxi(1, profile.burst_count)
			enemy["locked_angle"] = angle
		var fire_angle: float = enemy["locked_angle"] if profile.aiming == Profile.Aim.LOCKED else angle
		var lanes := clampi(profile.tier, 1, 4)
		for lane in range(lanes):
			var offset := (lane - (lanes - 1) * 0.5) * profile.spread
			var curvature := signf(offset) * profile.curve if lanes > 1 else 0.0
			projectile.emit(Projectile.create(enemy["pos"], Vector2.from_angle(fire_angle + offset) * profile.speed,
				profile.radius, profile.color, profile.projectile_style, curvature))
		enemy["burst_left"] -= 1
		enemy["fire"] += maxf(0.01, profile.burst_interval if enemy["burst_left"] > 0 else profile.cooldown)
