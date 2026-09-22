extends GutTest
const Shields = preload("res://shields/shield_system.gd")
const Config = preload("res://shields/shield_config.gd")

func make_system(aura: int = Config.Aura.BARRIER):
	var system := Shields.new()
	var settings := Config.new()
	settings.aura = aura
	system.reset(settings, Vector2.ZERO)
	return system

func test_barrier_is_stationary_and_only_intercepts_its_boundary() -> void:
	var system = make_system()
	assert_eq(system.deploy(100.0, 100.0), 100.0)
	system.advance(0.1, Vector2(100, 0), false)
	assert_eq(system.fields[0]["center"], Vector2.ZERO)
	assert_true(system.intercept(Vector2(0, -20), Vector2.ZERO, 0.0).is_empty(), "Existing bullets inside are not erased")
	var hit: Dictionary = system.intercept(Vector2(0, -400), Vector2(0, 400), 0.0)
	assert_false(hit.is_empty(), "Swept projectiles cannot tunnel through the rim")
	assert_almost_eq(hit["point"], Vector2(0, -250), Vector2.ONE * 0.001)
	assert_true(system.intercept(Vector2(400, 0), Vector2(400, 0), 0.0).is_empty())
	assert_true(system.intercept(Vector2(400, 0), Vector2(400, 100), 0.0).is_empty())

func test_phalanx_covers_front_and_follows_player_without_stacking() -> void:
	var system = make_system(Config.Aura.PHALANX)
	assert_eq(system.deploy(49.0, 100.0), 0.0)
	assert_eq(system.deploy(100.0, 100.0), 50.0)
	system.advance(0.1, Vector2(100, 100), false)
	assert_false(system.intercept(Vector2(100, -100), Vector2(100, 100), 0.0).is_empty())
	assert_true(system.intercept(Vector2(100, 200), Vector2(100, 100), 0.0, true).is_empty(), "Rear remains vulnerable")
	assert_true(system.intercept(Vector2(100, 80), Vector2(100, 100), 0.0, true).is_empty(), "Threats under the arc remain dangerous")
	system.deploy(50.0, 100.0)
	assert_eq(system.fields.size(), 1)
	assert_eq(system.fields[0]["strength"], 24.0)

func test_break_fade_then_removal_and_laser_drain() -> void:
	var system = make_system(Config.Aura.PHALANX)
	system.deploy(100.0, 100.0)
	for i in range(8):
		system.intercept(Vector2(0, -100), Vector2.ZERO, 0.0, false, 0.0, true)
	assert_true(system.fields[0]["fading"], "Eight MIRVs exhaust a level-one Phalanx")
	assert_false(system.intercept(Vector2(0, -100), Vector2.ZERO, 0.0).is_empty(), "Fade still clears bullets")
	system.advance(0.35, Vector2.ZERO, false)
	assert_true(system.fields.is_empty())
	assert_true(system.flashes.is_empty())
	system.deploy(100.0, 100.0)
	system.intercept(Vector2(0, -100), Vector2.ZERO, 0.0, true, 1.0)
	assert_almost_eq(system.fields[0]["strength"], 11.5, 0.001)

func test_personal_charge_release_fade_and_recharge_penalty() -> void:
	var system = make_system(Config.Aura.PULSE)
	system.config.personal_enabled = true
	system.config.reflect_lasers = true
	system.advance(0.3, Vector2.ZERO, true)
	assert_false(system.protected())
	system.advance(0.3, Vector2.ZERO, true)
	assert_true(system.protected())
	var hit: Dictionary = system.intercept(Vector2(0, -100), Vector2.ZERO, 0.0, true, 0.1)
	assert_true(hit["reflect"])
	assert_false(system.intercept(Vector2.ZERO, Vector2(1, 0), 0.0).is_empty())
	system.advance(0.01, Vector2.ZERO, false)
	assert_gt(system.fade, 0.0)
	system.advance(0.21, Vector2.ZERO, true)
	assert_false(system.protected(), "Early re-use must charge through its penalty")
	system.advance(10.0, Vector2.ZERO, false)
	assert_eq(system.penalty, 0.0)
	assert_eq(system.deploy(100.0, 100.0), 0.0)

func test_barrier_energy_scaling_decay_and_nearest_interception() -> void:
	var system = make_system()
	assert_eq(system.deploy(5.0, 100.0), 0.0)
	system.deploy(50.0, 100.0)
	assert_eq(system.fields[0]["radius"], 125.0)
	system.deploy(100.0, 100.0)
	system.intercept(Vector2(0, -400), Vector2.ZERO, 0.0)
	assert_eq(system.fields[0]["strength"], 50.0)
	assert_eq(system.fields[1]["strength"], 49.0)
	system.advance(10.0, Vector2.ZERO, false)
	assert_true(system.fields[0]["fading"])
	system.advance(0.4, Vector2.ZERO, false)
	assert_true(system.fields.is_empty())

func test_large_steps_do_not_resurrect_expired_shields() -> void:
	var system = make_system()
	system.config.personal_enabled = true
	system.advance(20.0, Vector2.ZERO, true)
	assert_false(system.protected())
	assert_true(system.exhausted)
	system.deploy(100.0, 100.0)
	system.advance(20.0, Vector2.ZERO, false)
	assert_true(system.fields.is_empty())
	for fps in [30, 60, 120]:
		system.reset(system.config, Vector2.ZERO)
		for frame in range(fps):
			system.advance(1.0 / fps, Vector2.ZERO, true)
		assert_almost_eq(system.personal, 2.1, 0.00001, "Charging overshoot must carry into shield duration")

func test_visual_hits_are_bounded_follow_mobile_shields_and_expire() -> void:
	var system = make_system(Config.Aura.PHALANX)
	system.deploy(100.0, 100.0)
	for i in range(100):
		system.intercept(Vector2(0, -100), Vector2.ZERO, 0.0, true, 0.0)
	assert_eq(system.flashes.size(), 48)
	assert_true(system.flashes[0]["mobile"])
	var offset: Vector2 = system.flashes[0]["offset"]
	system.advance(0.1, Vector2(20, 30), false)
	assert_eq(system.flashes[0]["offset"], offset)
	assert_almost_eq(system.visual_time, 0.1, 0.001)
	system.advance(0.3, Vector2(20, 30), false)
	assert_true(system.flashes.is_empty())
	system.reset(system.config, Vector2.ZERO)
	assert_eq(system.visual_time, 0.0)
