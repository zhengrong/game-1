extends RefCounted
## Heavy combat state, component targeting, and readable weapon presentation.
const SHIELD_RADIUS := 91.0
const TURRET_RADIUS := 19.0
const LASER_RADIUS := 8.0
const LASER_LENGTH := 1900.0

static func equip(enemy: Dictionary) -> void:
	enemy["shield"] = 102.0
	enemy["shield_max"] = 102.0
	enemy["shield_flash"] = 0.0
	enemy["shield_break"] = 0.0
	enemy["shield_hit"] = Vector2.DOWN
	enemy["turrets"] = []
	for side in [-1, 1]:
		enemy["turrets"].append({
			"offset": Vector2(side * 43.0, 25.0), "hp": 85.0,
			"kind": "dart" if side == -1 else "laser", "angle": PI * 0.5,
			"state": "cooldown", "timer": 0.65 if side == -1 else 1.6,
			"flash": 0.0, "burn": 0.0, "origin": Vector2.ZERO,
		})

static func surfaces(enemy: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if float(enemy.get("shield", 0.0)) > 0.0:
		result.append({"pos": enemy["pos"], "radius": SHIELD_RADIUS, "part": -2})
		return result
	result.append({"pos": enemy["pos"], "radius": 30.0, "part": -1})
	for i in range(enemy["turrets"].size()):
		var turret: Dictionary = enemy["turrets"][i]
		if turret["hp"] > 0.0:
			result.append({"pos": enemy["pos"] + turret["offset"], "radius": TURRET_RADIUS, "part": i})
	return result

static func damage(game, enemy: Dictionary, amount: float, point: Vector2, part: int = -1) -> void:
	if enemy["shield"] > 0.0:
		enemy["shield"] = maxf(0.0, enemy["shield"] - amount)
		enemy["shield_flash"] = 1.0
		enemy["shield_hit"] = (point - Vector2(enemy["pos"])).normalized()
		game._spawn_sparks(point, Color(0.25, 1.4, 2.6), 4, 110.0)
		if enemy["shield"] <= 0.0:
			game._spawn_energy_burst(enemy["pos"], Color(0.2, 0.85, 1.8), 0.75)
			enemy["shield_break"] = 0.65
			game.shockwaves.append({"pos": enemy["pos"], "radius": SHIELD_RADIUS, "max": 135.0, "life": 0.45, "color": Color(0.2, 0.8, 1.0)})
			game.play_sound("shield_break")
		return
	if part >= 0:
		var turret: Dictionary = enemy["turrets"][part]
		if turret["hp"] <= 0.0:
			return
		turret["hp"] = maxf(0.0, turret["hp"] - amount)
		turret["flash"] = 0.16
		game._spawn_sparks(point, Color(2.0, 0.8, 0.2), 5, 160.0)
		if turret["hp"] <= 0.0:
			turret["state"] = "destroyed"
			game._spawn_explosion(enemy["pos"] + turret["offset"], Color(1.0, 0.45, 0.12), 10, 105.0)
			game.play_sound("turret_down")
			game.score += 250
	else:
		enemy["hp"] -= amount
		enemy["hit_flash"] = 0.7
		game._spawn_sparks(point, Color(2.0, 0.65, 0.12), 3, 130.0)

static func update(game, enemy: Dictionary, delta: float) -> void:
	enemy["shield_flash"] = maxf(0.0, enemy["shield_flash"] - delta * 4.0)
	enemy["shield_break"] = maxf(0.0, enemy["shield_break"] - delta)
	for turret: Dictionary in enemy["turrets"]:
		turret["flash"] = maxf(0.0, turret["flash"] - delta)
		var mount: Vector2 = enemy["pos"] + turret["offset"]
		if turret["hp"] <= 0.0:
			turret["burn"] -= delta
			if turret["burn"] <= 0.0:
				game._spawn_damage_fire(mount, 0.55, enemy)
				turret["burn"] = 0.3
			continue
		# Do not attack from outside the viewport during the entrance.
		if enemy["pos"].y < 130.0:
			continue
		if turret["state"] == "cooldown" or turret["state"] == "tracking":
			var wanted: float = mount.direction_to(game.player_pos).angle()
			turret["angle"] = rotate_toward(turret["angle"], wanted, delta * 1.6)
		turret["timer"] -= delta
		# Only one transition per frame: even after a stall, show the locked warning
		# for its full interval before the laser can deal damage.
		if turret["timer"] <= 0.0:
			match turret["state"]:
				"cooldown":
					turret["state"] = "tracking"
					turret["timer"] = 0.9 if turret["kind"] == "laser" else 0.45
				"tracking":
					turret["state"] = "locked"
					turret["timer"] = 0.75 if turret["kind"] == "laser" else 0.25
					# Freeze both origin and angle so the final warning matches the hazard.
					turret["origin"] = mount + Vector2.from_angle(turret["angle"]) * 24.0
				"locked":
					turret["state"] = "firing"
					turret["timer"] = 0.65 if turret["kind"] == "laser" else 0.12
					turret["flash"] = 0.2
					game.play_sound("laser" if turret["kind"] == "laser" else "dart")
					if turret["kind"] == "dart":
						for spread in [-0.13, 0.0, 0.13]:
							game.enemy_bullets.append({"pos": turret["origin"], "vel": Vector2.from_angle(turret["angle"] + spread) * 300.0, "radius": 5.0, "color": Color(1.0, 0.35, 0.04), "grazed": false, "age": 0.0, "style": "dart"})
				"firing":
					turret["state"] = "cooldown"
					turret["timer"] = 1.8 if turret["kind"] == "laser" else 0.85
		if turret["state"] == "firing" and turret["kind"] == "laser":
			var start: Vector2 = turret["origin"]
			var end: Vector2 = start + Vector2.from_angle(turret["angle"]) * LASER_LENGTH
			var nearest := Geometry2D.get_closest_point_to_segment(game.player_pos, start, end)
			if nearest.distance_to(game.player_pos) < LASER_RADIUS + game.PLAYER_RADIUS:
				game._damage_player()

static func draw_hazards(game, enemy: Dictionary) -> void:
	for turret: Dictionary in enemy["turrets"]:
		if turret["hp"] <= 0.0 or turret["kind"] != "laser":
			continue
		var phase: String = turret["state"]
		if phase == "cooldown":
			continue
		var direction := Vector2.from_angle(turret["angle"])
		var origin: Vector2 = turret["origin"]
		if phase == "tracking":
			origin = enemy["pos"] + turret["offset"] + direction * 24.0
		var end := origin + direction * LASER_LENGTH
		if phase == "firing":
			game.draw_line(origin, end, Color(1.0, 0.035, 0.01, 0.16), 27.0, true)
			game.draw_line(origin, end, Color(2.0, 0.16, 0.025, 0.95), LASER_RADIUS * 2.0, true)
			game.draw_line(origin, end, Color(3.2, 1.6, 0.65), 3.0, true)
		else:
			var alpha := 0.28 if phase == "tracking" else 0.65
			game.draw_line(origin, end, Color(1.0, 0.35, 0.12, alpha * 0.18), LASER_RADIUS * 2.0, true)
			for side in [-1.0, 1.0]:
				var offset: Vector2 = direction.orthogonal() * LASER_RADIUS * side
				game.draw_dashed_line(origin + offset, end + offset, Color(1.0, 0.52, 0.2, alpha), 1.0, 12.0)

static func draw_components(game, enemy: Dictionary) -> void:
	for turret: Dictionary in enemy["turrets"]:
		var mount: Vector2 = enemy["pos"] + turret["offset"]
		game.draw_circle(mount, 23.0, Color(0.035, 0.04, 0.055))
		game.draw_arc(mount, 21.0, 0.0, TAU, 24, Color(0.45, 0.36, 0.25), 2.0, true)
		if turret["hp"] <= 0.0:
			game.draw_line(mount - Vector2(10, 8), mount + Vector2(8, 7), Color(0.8, 0.22, 0.03), 3.0)
			game.draw_circle(mount, 6.0, Color(0.6, 0.1, 0.015))
			continue
		var direction := Vector2.from_angle(turret["angle"])
		var muzzle: Vector2 = mount + direction * (27.0 - turret["flash"] * 18.0)
		var tint := Color(0.95, 0.45, 0.12) if turret["kind"] == "dart" else Color(1.0, 0.12, 0.06)
		game.draw_circle(mount, 16.0, Color(0.22, 0.25, 0.3))
		game.draw_line(mount, muzzle, Color(0.06, 0.075, 0.1), 15.0, true)
		game.draw_line(mount, muzzle, Color(0.6, 0.65, 0.72), 8.0, true)
		game.draw_line(mount + direction * 8.0, muzzle, tint, 2.0, true)
		game.draw_circle(mount, 5.0, tint * (1.8 if turret["state"] in ["locked", "firing"] else 0.65))
		if turret["state"] in ["tracking", "locked"]:
			game.draw_arc(mount, 18.0, -PI * 0.5, TAU - PI * 0.5, 24, tint, 2.0, true)
		if turret["flash"] > 0.0:
			game.draw_circle(muzzle, 9.0 * turret["flash"] / 0.2, Color(3.0, 1.4, 0.6))
		# Local component health; color differentiates it from the hull bar.
		game.draw_line(mount + Vector2(-15, -27), mount + Vector2(15, -27), Color(0.06, 0.07, 0.1), 3.0)
		game.draw_line(mount + Vector2(-15, -27), mount + Vector2(-15 + 30 * turret["hp"] / 85.0, -27), tint, 3.0)
	var shield: float = enemy["shield"]
	if shield > 0.0:
		game.draw_circle(enemy["pos"], SHIELD_RADIUS, Color(0.05, 0.5, 0.9, 0.035))
		game.draw_arc(enemy["pos"], SHIELD_RADIUS, 0.0, TAU, 72, Color(0.1, 0.85, 1.5, 0.25 + enemy["shield_flash"] * 0.45), 2.0, true)
		game.draw_arc(enemy["pos"], SHIELD_RADIUS + 4.0, -PI * 0.5, -PI * 0.5 + TAU * shield / enemy["shield_max"], 64, Color(0.1, 0.9, 1.4, 0.65), 2.0, true)
		if enemy["shield_flash"] > 0.0:
			var angle: float = Vector2(enemy["shield_hit"]).angle()
			game.draw_arc(enemy["pos"], SHIELD_RADIUS, angle - 0.42, angle + 0.42, 20, Color(1.2, 2.0, 3.0, enemy["shield_flash"]), 5.0, true)
	elif enemy["shield_break"] > 0.0:
		for i in range(12):
			var angle := TAU * i / 12.0
			var radius: float = SHIELD_RADIUS + (0.65 - enemy["shield_break"]) * 85.0
			game.draw_arc(enemy["pos"], radius, angle, angle + 0.22, 5, Color(0.2, 1.3, 2.0, enemy["shield_break"]), 2.0, true)
