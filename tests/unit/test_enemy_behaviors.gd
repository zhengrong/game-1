extends GutTest
const Projectile = preload("res://combat/enemy_projectile.gd")
const Weapons = preload("res://combat/enemy_weapons.gd")
const Profile = preload("res://missions/enemy_weapon_definition.gd")
const Laser = preload("res://combat/enemy_laser.gd")

func test_motion_is_time_step_independent() -> void:
	for style in ["shuriken", "boomerang"]:
		var reference := Projectile.create(Vector2(10, 20), Vector2(0, 400), 6, Color.RED, style, 0.8)
		Projectile.advance(reference, 2.0)
		for hz in [30, 60, 120]:
			var shot := Projectile.create(Vector2(10, 20), Vector2(0, 400), 6, Color.RED, style, 0.8)
			for step in range(hz * 2):
				Projectile.advance(shot, 1.0 / hz)
			assert_almost_eq(shot["pos"], reference["pos"], Vector2.ONE * 0.01)
		if style == "shuriken":
			assert_lt(reference["vel"].length(), 120.0)
		else:
			assert_lt(reference["pos"].x, 10.0)
	var straight := Projectile.create(Vector2.ZERO, Vector2.DOWN * 200, 6, Color.RED, "boomerang")
	Projectile.advance(straight, 1.0)
	assert_almost_eq(straight["pos"], Vector2(0, 200), Vector2.ONE * 0.001)
	var legacy := {"pos": Vector2.ZERO, "vel": Vector2.DOWN * 300, "age": 0.0, "style": "shuriken"}
	Projectile.advance(legacy, 0.1)
	assert_true(legacy.has("origin"))

func test_burst_aim_modes_tiers_and_cooldown() -> void:
	var weapons := Weapons.new()
	var shots: Array[Dictionary] = []
	weapons.projectile.connect(func(shot): shots.append(shot))
	var rng := RandomNumberGenerator.new()
	for aim in [Profile.Aim.FIXED, Profile.Aim.TRACKING, Profile.Aim.LOCKED, Profile.Aim.SPINNING]:
		shots.clear()
		var profile := Profile.new()
		profile.pattern = Profile.Pattern.BURST
		profile.aiming = aim
		profile.tier = 2
		profile.burst_count = 3
		profile.curve = 0.8
		var enemy := {"pos": Vector2.ZERO, "fire": 0.0}
		weapons.fire(enemy, profile, rng, Vector2(0, 500), 0.1)
		assert_eq(shots.size(), 2)
		assert_lt(shots[0]["curve"], 0.0)
		assert_gt(shots[1]["curve"], 0.0)
		var initial_angle: float = enemy["weapon_angle"]
		enemy["fire"] = 0.0
		weapons.fire(enemy, profile, rng, Vector2(500, 0), 0.1)
		if aim in [Profile.Aim.FIXED, Profile.Aim.LOCKED]:
			assert_eq(enemy["weapon_angle"], initial_angle)
		else:
			assert_ne(enemy["weapon_angle"], initial_angle)
		enemy["fire"] = 0.0
		weapons.fire(enemy, profile, rng, Vector2.DOWN, 0.1)
		assert_eq(enemy["burst_left"], 0)
		assert_eq(enemy["fire"], profile.cooldown)
		weapons.fire(enemy, profile, rng, Vector2.DOWN, 0.1)
		assert_eq(shots.size(), 6)
		# A stall catches up missed emissions with a finite per-call limit.
		enemy["fire"] = -1000.0
		weapons.fire(enemy, profile, rng, Vector2.DOWN, 1.0)
		assert_eq(shots.size(), 70)

func test_laser_warning_active_overlap_and_mirv_tiers() -> void:
	var ray := Laser.create(Vector2.ZERO, 0, 0.5, 0.2, 8)
	assert_eq(Laser.active_time(ray, 0.4), 0.0)
	assert_almost_eq(Laser.active_time(ray, 0.2), 0.1, 0.001)
	assert_almost_eq(Laser.active_time(ray, 2.0), 0.1, 0.001)
	var weapons := Weapons.new()
	var rays: Array = []
	var shots: Array = []
	weapons.laser.connect(func(value): rays.append(value))
	weapons.projectile.connect(func(value): shots.append(value))
	var profile := Profile.new()
	var enemy := {"pos": Vector2.ZERO, "fire": 0.0}
	var rng := RandomNumberGenerator.new()
	profile.pattern = Profile.Pattern.LASER
	for aim in [Profile.Aim.FIXED, Profile.Aim.TRACKING]:
		profile.aiming = aim
		enemy["fire"] = 0.0
		weapons.fire(enemy, profile, rng, Vector2.RIGHT)
	assert_eq(rays.size(), 2)
	assert_gt(rays[0]["end"].y, 1000)
	assert_gt(rays[1]["end"].x, 1000)
	profile.pattern = Profile.Pattern.LASER_MIRV
	for tier in [1, 2]:
		profile.tier = tier
		enemy["fire"] = 0.0
		weapons.fire(enemy, profile, rng, Vector2.DOWN)
	assert_eq(shots[0]["count"], 5)
	assert_eq(shots[1]["count"], 9)

func test_doomsday_charge_crossing_and_weapon_profiles() -> void:
	var Doom = preload("res://combat/doomsday_effect.gd")
	var enemy := {"pos": Vector2(100, 200), "fire": 0.0}
	var effect: Dictionary = Doom.create(enemy, "bomb", 1.5, 300)
	assert_eq(Doom.advance(effect, 1.0), 0.0)
	assert_false(effect["fired"])
	enemy["pos"] = Vector2(150, 250)
	assert_almost_eq(Doom.advance(effect, 0.6), 0.1, 0.001)
	assert_eq(effect["pos"], enemy["pos"])
	assert_true(effect["just_fired"])
	enemy["pos"] = Vector2.ZERO
	assert_almost_eq(Doom.advance(effect, 2.0), 0.2, 0.001)
	assert_false(effect["just_fired"])
	assert_eq(effect["pos"], Vector2(150, 250), "Detonation position stays fixed")
	var weapons := Weapons.new()
	var emitted: Array = []
	weapons.doomsday.connect(func(value): emitted.append(value))
	for path in ["res://missions/weapons/doomsday_bomb.tres", "res://missions/weapons/super_mirv.tres"]:
		enemy["fire"] = 0.0
		weapons.fire(enemy, load(path), RandomNumberGenerator.new())
	assert_eq(emitted[0]["kind"], "bomb")
	assert_eq(emitted[1]["kind"], "super")
	assert_eq(enemy["fire"], 5.0)

func test_super_mirv_payload_is_finite_and_children_are_immediately_armed() -> void:
	var Missile = preload("res://combat/missile.gd")
	var carrier: Dictionary = Missile.create_super(Vector2.ZERO, Vector2.DOWN)
	assert_true(Missile.ready_to_split(carrier, Vector2(0, 300)))
	assert_false(Missile.ready_to_split(carrier, Vector2(0, 400)))
	assert_almost_eq(carrier["vel"].length(), 110.0, 0.01)
	var children: Array[Dictionary] = Missile.children(carrier)
	assert_eq(children.size(), 6)
	for child in children:
		assert_true(Missile.ready_to_split(child, Vector2(0, 100)))
		assert_ne(child.get("payload", "pellet"), "super", "No recursive Super MIRVs")
		assert_eq(Missile.fragments(child).size(), 8)
	var ordinary: Dictionary = Missile.create(Vector2.ZERO, Vector2.DOWN)
	assert_false(Missile.ready_to_split(ordinary, Vector2.DOWN))
	ordinary["age"] = 0.5
	assert_true(Missile.ready_to_split(ordinary, Vector2.DOWN))
