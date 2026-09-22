extends GutTest
## These tests intentionally do not instantiate the game scene.
const Effects = preload("res://systems/effects_system.gd")
const Cycle = preload("res://combat/weapon_cycle.gd")
const Queries = preload("res://combat/collision_queries.gd")

func test_effect_instances_own_separate_collections() -> void:
	var first := Effects.new()
	var second := Effects.new()
	first.rng = RandomNumberGenerator.new()
	second.rng = RandomNumberGenerator.new()
	first.rng.seed = 42
	second.rng.seed = 42
	first._spawn_explosion(Vector2(100, 200), Color.ORANGE, 12, 180.0)
	second._spawn_explosion(Vector2(100, 200), Color.ORANGE, 12, 180.0)
	assert_eq(first.particles, second.particles, "Seeded effects are reproducible outside a scene")
	first._update_particles(10.0, [])
	assert_true(first.particles.is_empty())
	assert_false(second.particles.is_empty(), "Instances must not share their effect storage")

func test_weapon_signals_preserve_cadence_without_a_game() -> void:
	var counts: Array[int] = []
	for fps in [30, 60, 120]:
		var cycle := Cycle.new()
		var events := [0]
		cycle.damage_requested.connect(func(): events[0] += 1)
		for frame in range(fps * 3):
			cycle.advance(1.0 / fps)
		counts.append(events[0])
	assert_gt(counts[0], 0)
	assert_eq(counts[0], counts[1])
	assert_eq(counts[1], counts[2])

func test_weapon_configuration_is_per_instance() -> void:
	var first := Cycle.new()
	var second := Cycle.new()
	first.config.beam_duration = 0.5
	first.start_beam()
	second.start_beam()
	assert_eq(first.beam_visible_timer, 0.5)
	assert_eq(second.beam_visible_timer, 0.27)

func test_queries_choose_nearest_target_without_mutating_enemies() -> void:
	var enemies: Array[Dictionary] = [
		{"pos": Vector2(100, 100), "radius": 20.0, "hp": 10.0},
		{"pos": Vector2(100, 200), "radius": 20.0, "hp": 10.0}]
	var before := enemies.duplicate(true)
	var beam := Queries.beam(enemies, Vector2(100, 300), false)
	var sweep := Queries.sweep(enemies, Vector2(100, 300), Vector2(100, 0), 4.0)
	assert_eq(beam.index, 1)
	assert_eq(sweep.index, 1)
	assert_between(sweep.fraction, 0.0, 1.0)
	assert_eq(enemies, before)
	assert_eq(Queries.beam([], Vector2.ZERO, false).index, -1)
	assert_eq(Queries.sweep([], Vector2.ZERO, Vector2.UP, 4.0).index, -1)

func test_heavy_damage_returns_outcomes_without_game_services() -> void:
	var heavy = preload("res://combat/heavy_enemy.gd")
	var enemy := {"pos": Vector2(100, 100), "hp": 200.0}
	heavy.equip(enemy)
	var shield = heavy.damage(enemy, 102.0, enemy["pos"], 1)
	assert_eq(shield.kind, heavy.DamageResult.Kind.SHIELD)
	assert_true(shield.destroyed)
	assert_eq(enemy["turrets"][1]["hp"], 85.0, "Shield absorbs the whole hit")
	var turret = heavy.damage(enemy, 85.0, enemy["pos"], 1)
	assert_true(turret.destroyed)
	assert_eq(turret.score, 250)
	var repeated = heavy.damage(enemy, 85.0, enemy["pos"], 1)
	assert_eq(repeated.kind, heavy.DamageResult.Kind.NONE)
	assert_eq(repeated.score, 0, "Destroyed mounts cannot award score twice")
