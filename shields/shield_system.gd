extends RefCounted
const Config = preload("res://shields/shield_config.gd")
var config: Config = Config.new()
var fields: Array[Dictionary] = []
var visual_time: float = 0.0
var charge_pulses: Dictionary = {}
var personal: float = 0.0
var fade: float = 0.0
var charge: float = 0.0
var penalty: float = 0.0
var exhausted: bool = false
var position: Vector2 = Vector2.ZERO
var previous_position: Vector2 = Vector2.ZERO
var aura_held: bool = false
var flashes: Array[Dictionary] = []

func reset(settings: Config, origin: Vector2) -> void:
	visual_time = 0.0
	charge_pulses.clear()
	config = settings
	fields.clear()
	flashes.clear()
	personal = 0.0
	fade = 0.0
	charge = 0.0
	penalty = 0.0
	exhausted = false
	aura_held = false
	position = origin
	previous_position = origin

func advance(delta: float, origin: Vector2, zen_held: bool) -> void:
	visual_time += delta
	for index in charge_pulses.keys():
		charge_pulses[index] -= delta
		if charge_pulses[index] <= 0.0:
			charge_pulses.erase(index)
	previous_position = position
	position = origin
	fade = maxf(0.0, fade - delta)
	if config.personal_enabled:
		if personal > 0.0:
			var overshoot := maxf(0.0, delta - personal)
			personal = maxf(0.0, personal - delta)
			if not zen_held or personal <= 0.0:
				personal = 0.0
				fade = maxf(0.0, config.personal_fade - overshoot)
				exhausted = true
		elif zen_held and not exhausted:
			charge += delta
			if charge + 0.000001 >= config.personal_charge + penalty:
				var active_time := maxf(0.0, charge - config.personal_charge - penalty)
				personal = maxf(0.0, config.personal_duration - active_time)
				if personal <= 0.0:
					fade = maxf(0.0, config.personal_fade - (active_time - config.personal_duration))
					exhausted = true
				charge = 0.0
				penalty += config.personal_penalty
		if not zen_held:
			charge = 0.0
			exhausted = false
			penalty = maxf(0.0, penalty - delta * config.personal_penalty / maxf(0.001, config.personal_recovery))
	for i in range(fields.size() - 1, -1, -1):
		var field := fields[i]
		field["age"] = field.get("age", 0.0) + delta
		if field["fading"]:
			field["fade"] -= delta
			if field["fade"] <= 0.0:
				fields.remove_at(i)
		elif field["kind"] == Config.Aura.BARRIER:
			field["strength"] -= config.barrier_decay * delta
			_break_if_empty(field)
			if field["fading"] and config.barrier_decay > 0.0:
				field["fade"] -= -field["strength"] / config.barrier_decay
				if field["fade"] <= 0.0:
					fields.remove_at(i)
	for i in range(flashes.size() - 1, -1, -1):
		flashes[i]["life"] -= delta
		if flashes[i]["life"] <= 0.0:
			flashes.remove_at(i)

func deploy(energy: float, capacity: float) -> float:
	if config.aura == Config.Aura.PULSE:
		return 0.0
	var cost := capacity / maxf(1.0, config.phalanx_charges) if config.aura == Config.Aura.PHALANX else energy
	if energy < (cost if config.aura == Config.Aura.PHALANX else config.barrier_min_energy):
		return 0.0
	var phalanx := config.aura == Config.Aura.PHALANX
	if phalanx:
		# A replacement cannot stack another forward shield at the same ship.
		for i in range(fields.size() - 1, -1, -1):
			if fields[i]["kind"] == Config.Aura.PHALANX:
				fields.remove_at(i)
	var strength := config.phalanx_strength if phalanx else config.barrier_strength
	fields.append({"age": 0.0, "kind": config.aura, "center": position, "radius": config.phalanx_radius if phalanx else config.barrier_radius * clampf(energy / maxf(0.001, capacity), 0.1, 1.0), "strength": strength, "maximum": strength, "fading": false, "fade": config.phalanx_fade if phalanx else config.barrier_fade})
	return cost

func _break_if_empty(field: Dictionary) -> void:
	if field["strength"] <= 0.0:
		field["fading"] = true

func protected() -> bool:
	return personal > 0.0 or fade > 0.0

# First boundary intersection; bullets already inside a deployed barrier survive.
static func boundary(start: Vector2, end: Vector2, center: Vector2, radius: float, half_angle: float = PI) -> float:
	var offset := start - center
	var travel := end - start
	var a := travel.length_squared()
	if a < 0.000001:
		return -1.0
	var b := 2.0 * offset.dot(travel)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	for t in [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]:
		if t >= 0.0 and t <= 1.0:
			var direction := start.lerp(end, t) - center
			if absf(wrapf(direction.angle() + PI * 0.5, -PI, PI)) <= half_angle:
				return t
	return -1.0

func intercept(start: Vector2, end: Vector2, radius: float, laser: bool = false, delta: float = 0.0, missile: bool = false, overload: bool = false) -> Dictionary:
	var nearest := 2.0
	var chosen: Dictionary = {}
	var personal_hit := false
	if protected():
		var r := config.personal_radius + radius
		var relative_start := start if laser else start + position - previous_position
		var t := 0.0 if relative_start.distance_squared_to(position) <= r * r else boundary(relative_start, end, position, r)
		if t >= 0.0:
			nearest = t
			personal_hit = true
	for field in fields:
		# Deployed barriers stay in world space; Phalanx follows the ship.
		var mobile: bool = field["kind"] == Config.Aura.PHALANX
		var center: Vector2 = position if mobile else field["center"]
		var relative_start := start + position - previous_position if mobile and not laser else start
		var t := boundary(relative_start, end, center, field["radius"] + radius, deg_to_rad(config.phalanx_half_angle) if mobile else PI)
		if t >= 0.0 and t < nearest:
			nearest = t
			chosen = field
			personal_hit = false
	if nearest > 1.0:
		return {}
	var point := start.lerp(end, nearest)
	if not chosen.is_empty() and not chosen["fading"]:
		chosen["strength"] -= chosen["strength"] if overload else (config.laser_drain * delta if laser else (3.0 if missile else 1.0))
		_break_if_empty(chosen)
	# Keep effects bounded under sustained lasers; store local coordinates for mobile shields.
	if flashes.size() >= 48:
		flashes.pop_front()
	var mobile_hit: bool = personal_hit or chosen.get("kind", -1) == Config.Aura.PHALANX
	flashes.append({"pos": point, "offset": point - position, "mobile": mobile_hit, "life": 0.32})
	return {"point": point, "reflect": personal_hit and laser and config.reflect_lasers}

func energy_collected(before: float, after: float, capacity: float) -> void:
	if config.aura != Config.Aura.PHALANX:
		return
	var cost := capacity / maxf(1.0, config.phalanx_charges)
	for index in range(clampi(int(before / cost), 0, config.phalanx_charges), clampi(int(after / cost), 0, config.phalanx_charges)):
		charge_pulses[index] = 0.45
