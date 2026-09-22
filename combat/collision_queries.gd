extends RefCounted
## Pure targeting queries. They never damage enemies or trigger presentation.
const Hit = preload("res://combat/hit_result.gd")
const HeavyEnemy = preload("res://combat/heavy_enemy.gd")

static func beam(enemies: Array[Dictionary], muzzle: Vector2, overcharged: bool) -> Hit:
	var result := Hit.new()
	var beam_radius := 8.5 if overcharged else 6.5
	for i in range(enemies.size()):
		var enemy := enemies[i]
		var surfaces: Array[Dictionary] = []
		if enemy.has("turrets"):
			surfaces = HeavyEnemy.surfaces(enemy)
		else:
			surfaces.append({"pos": enemy["pos"], "radius": enemy["radius"] * 0.72, "part": -1})
		for surface in surfaces:
			var center: Vector2 = surface["pos"]
			var radius: float = surface["radius"]
			var dx := absf(center.x - muzzle.x)
			if dx > radius + beam_radius or center.y >= muzzle.y:
				continue
			var end_y := minf(muzzle.y - 1.0, center.y + sqrt(maxf(0.0, radius * radius - minf(dx, radius) * minf(dx, radius))))
			if end_y > result.end_y:
				result.index = i
				result.end_y = end_y
				result.part = surface["part"]
	return result


static func sweep(enemies: Array[Dictionary], previous: Vector2, end: Vector2, bullet_radius: float) -> Hit:
	var result := Hit.new()
	for j in range(enemies.size()):
		var enemy := enemies[j]
		var surfaces: Array[Dictionary] = []
		if enemy.has("turrets"):
			surfaces = HeavyEnemy.surfaces(enemy)
		else:
			surfaces.append({"pos": enemy["pos"], "radius": enemy["radius"] * 0.72, "part": -1})
		for surface in surfaces:
			var radius: float = bullet_radius + surface["radius"]
			var t := 0.0 if previous.distance_squared_to(surface["pos"]) <= radius * radius else Geometry2D.segment_intersects_circle(previous, end, surface["pos"], radius)
			if t >= 0.0 and t < result.fraction:
				result.fraction = t
				result.index = j
				result.part = surface["part"]
	return result
