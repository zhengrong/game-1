extends RefCounted
## Emits projectile requests; never accesses the game scene or advances movement.
const Profile = preload("res://missions/enemy_weapon_definition.gd")
signal aimed(origin: Vector2, speed: float, color: Color, radius: float)
signal fan(origin: Vector2, count: int, spread: float, speed: float, color: Color, radius: float)
signal radial(origin: Vector2, count: int, speed: float, rotation: float, color: Color, radius: float)
signal missile(origin: Vector2)

func fire(enemy: Dictionary, profile: Profile, rng: RandomNumberGenerator) -> void:
	if enemy["fire"] > 0.0 or profile.pattern == Profile.Pattern.NONE:
		return
	var origin: Vector2 = enemy["pos"]
	match profile.pattern:
		Profile.Pattern.AIMED:
			aimed.emit(origin, profile.speed, profile.color, profile.radius)
			enemy["fire"] = rng.randf_range(profile.cooldown, profile.cooldown_max)
		Profile.Pattern.SPINNER_CYCLE:
			if int(enemy["age"] / 1.65) % 3 == 0:
				missile.emit(origin)
			else:
				radial.emit(origin, 9, 180.0, enemy["age"] * 0.75, Color(1.0, 0.075, 0.018), 6.5)
			enemy["fire"] = 1.65
		Profile.Pattern.BOSS_CYCLE:
			_fire_boss(enemy)
		Profile.Pattern.FAN:
			fan.emit(origin, profile.count, profile.spread, profile.speed, profile.color, profile.radius)
			enemy["fire"] = profile.cooldown
		Profile.Pattern.RADIAL:
			radial.emit(origin, profile.count, profile.speed, enemy["age"] * 0.75, profile.color, profile.radius)
			enemy["fire"] = profile.cooldown
		Profile.Pattern.MISSILE:
			missile.emit(origin)
			enemy["fire"] = profile.cooldown

func _fire_boss(enemy: Dictionary) -> void:
	var health_ratio: float = enemy["hp"] / enemy["max_hp"]
	var cycle := int(enemy["age"] * 0.75) % 3
	if cycle == 0:
		radial.emit(enemy["pos"] + Vector2(0.0, 42.0), 18 if health_ratio > 0.45 else 24, 205.0, enemy["age"] * 0.42, Color(1.0, 0.065, 0.015), 7.0)
		enemy["fire"] = 0.82 if health_ratio > 0.45 else 0.58
	elif cycle == 1:
		fan.emit(enemy["pos"] + Vector2(-52.0, 34.0), 7, 0.13, 285.0, Color(1.0, 0.1, 0.02), 7.0)
		fan.emit(enemy["pos"] + Vector2(52.0, 34.0), 7, 0.13, 285.0, Color(1.0, 0.1, 0.02), 7.0)
		enemy["fire"] = 1.02
	else:
		for offset in [-58.0, 0.0, 58.0]:
			aimed.emit(enemy["pos"] + Vector2(offset, 38.0), 340.0, Color(1.0, 0.16, 0.025), 8.0)
		enemy["fire"] = 0.48
