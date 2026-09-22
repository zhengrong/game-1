extends RefCounted
const Profile = preload("res://missions/movement_definition.gd")
## Returns whether arrival permits the hull weapon to fire this frame.
static func advance(enemy: Dictionary, profile: Profile, delta: float, screen_width: float) -> bool:
	match profile.mode:
		Profile.Mode.BOSS_ORBIT:
			if enemy["pos"].y < profile.settle_y:
				enemy["pos"].y += enemy["vel"].y * delta
				return false
			enemy["pos"].x = screen_width * 0.5 + sin(enemy["age"] * profile.frequency) * screen_width * profile.amplitude
		Profile.Mode.STRAIGHT:
			enemy["pos"] += enemy["vel"] * delta
		_:
			var locked := false
			if profile.pause_for_laser and enemy.has("turrets"):
				for turret: Dictionary in enemy["turrets"]:
					if turret["kind"] == "laser" and turret["state"] in ["locked", "firing"]:
						locked = true
			if not locked:
				enemy["pos"].y += enemy["vel"].y * delta
				var target: float = enemy["anchor_x"] + sin(enemy["age"] * profile.frequency + enemy["phase"]) * profile.amplitude
				enemy["pos"].x = move_toward(enemy["pos"].x, target, delta * profile.lateral_speed) if profile.mode == Profile.Mode.ANCHORED else target
			if enemy["pos"].y > profile.settle_y:
				enemy["vel"].y = move_toward(enemy["vel"].y, profile.cruise_speed, delta * profile.deceleration)
	return true
