extends GutTest
const Runner = preload("res://missions/mission_runner.gd")
const Mission = preload("res://missions/mission_definition.gd")
const Stage = preload("res://missions/stage_definition.gd")
const Group = preload("res://missions/spawn_group.gd")
const Factory = preload("res://missions/enemy_factory.gd")
const SCOUT = preload("res://missions/enemies/scout.tres")
const HEAVY = preload("res://missions/enemies/heavy.tres")

func fixture() -> Resource:
	var mission := Mission.new()
	mission.initial_delay = 0.0
	var stage := Stage.new()
	var first := Group.new()
	first.enemies = [SCOUT, HEAVY]
	first.count = 2
	first.start_time = 0.0
	first.interval = 0.5
	first.formation = PackedFloat32Array([0.2, 0.8])
	var late := Group.new()
	late.enemies = [SCOUT]
	late.start_time = 3.0
	stage.groups = [first, late]
	mission.stages = [stage]
	return mission

func test_delayed_mixed_groups_do_not_finish_during_gaps() -> void:
	var runner := Runner.new()
	var events: Array = []
	runner.spawn_requested.connect(func(enemy, x, token): events.append([enemy.kind, x, token]))
	runner.reset(fixture())
	runner.advance(0.0)
	runner.advance(0.0)
	assert_eq(events[0][0], "scout")
	assert_almost_eq(events[0][1], 0.2, 0.0001)
	runner.enemy_removed(events[0][2], true)
	runner.check_completion()
	assert_false(runner.finished, "A gap before scheduled reinforcements cannot end a stage")
	runner.advance(0.5)
	assert_eq(events[1][0], "heavy")
	runner.enemy_removed(events[1][2], true)
	runner.check_completion()
	assert_false(runner.finished)
	runner.advance(2.5)
	assert_eq(events.size(), 3)
	runner.check_completion()
	assert_false(runner.finished, "Living enemies block completion after all spawns")
	runner.enemy_removed(events[2][2], true)
	runner.check_completion()
	assert_true(runner.finished)
	runner.advance(10.0)
	assert_eq(events.size(), 3, "Completed missions cannot spawn again")

func test_stage_transition_and_strict_escape_rule() -> void:
	var mission = fixture()
	mission.stages[0].transition_delay = 0.25
	var final := Stage.new()
	final.completion = Stage.Completion.DEFEAT_ALL
	var group := Group.new()
	group.enemies = [SCOUT]
	group.start_time = 0.0
	final.groups = [group]
	mission.stages.append(final)
	var runner := Runner.new()
	var failures := [0]
	runner.failed.connect(func(): failures[0] += 1)
	runner.reset(mission)
	runner.advance(0.0)
	runner.advance(4.0)
	for token in runner.active.keys():
		runner.enemy_removed(token, false)
	runner.check_completion()
	assert_true(runner.transitioning, "Clear-field stages allow enemies to leave")
	runner.advance(0.1)
	assert_eq(runner.stage_index, 0)
	runner.advance(0.2)
	assert_eq(runner.stage_index, 1)
	runner.advance(0.0)
	runner.enemy_removed(runner.active.keys()[0], false)
	assert_true(runner.finished)
	assert_eq(failures[0], 1, "Required enemies escaping fail the mission")
	runner.check_completion()

func test_restart_ignores_stale_enemy_tokens() -> void:
	var runner := Runner.new()
	runner.reset(fixture())
	runner.advance(0.0)
	runner.advance(0.0)
	var stale: int = runner.active.keys()[0]
	runner.reset(fixture())
	runner.advance(0.0)
	runner.advance(0.0)
	runner.enemy_removed(stale, true)
	assert_eq(runner.active.size(), 1)

func test_archetypes_create_independent_enemy_state() -> void:
	var rng := RandomNumberGenerator.new()
	var first := Factory.create(HEAVY, 100.0, rng)
	var second := Factory.create(HEAVY, 200.0, rng)
	first["hp"] = 1.0
	first["turrets"][0]["hp"] = 0.0
	assert_eq(second["hp"], HEAVY.health)
	assert_eq(second["turrets"][0]["hp"], 85.0)
	assert_eq(HEAVY.health, 340.0)

func test_empty_mission_and_empty_stage_finish() -> void:
	var runner := Runner.new()
	var mission := Mission.new()
	mission.initial_delay = 0.0
	runner.reset(mission)
	runner.advance(0.0)
	assert_true(runner.finished)
	mission.stages = [Stage.new()]
	runner.reset(mission)
	runner.advance(0.0)
	runner.check_completion()
	assert_true(runner.finished)

func test_overlapping_groups_preserve_order_after_a_hitch() -> void:
	var definition = fixture()
	definition.stages[0].groups[1].start_time = 0.25
	var results: Array = []
	for steps in [[1.0], [0.0, 0.25, 0.25, 0.5]]:
		var runner := Runner.new()
		var events: Array = []
		runner.spawn_requested.connect(func(enemy, _x, _token): events.append(enemy.kind))
		runner.reset(definition)
		runner.advance(0.0)
		for delta in steps:
			runner.advance(delta)
		results.append(events)
	assert_eq(results[0], ["scout", "scout", "heavy"])
	assert_eq(results[0], results[1])

func test_movement_and_weapons_can_be_composed_independently() -> void:
	var movement = preload("res://combat/enemy_movement.gd")
	var weapons = preload("res://combat/enemy_weapons.gd").new()
	var rng := RandomNumberGenerator.new()
	var enemy := Factory.create(preload("res://missions/enemies/fan_scout.tres"), 200.0, rng)
	var shots: Array = []
	weapons.fan.connect(func(origin, count, spread, speed, _color, radius): shots.append([origin, count, spread, speed, radius]))
	enemy["fire"] = 0.0
	var previous: Vector2 = enemy["pos"]
	assert_true(movement.advance(enemy, enemy["movement"], 0.5, 720.0))
	assert_eq(enemy["pos"], previous + enemy["vel"] * 0.5, "Straight flight does not use the scout strafe")
	weapons.fire(enemy, enemy["weapon"], rng)
	assert_eq(enemy["kind"], "scout", "The hull identity remains independent")
	assert_eq(shots.size(), 1)
	assert_eq(shots[0][1], 7)
	assert_eq(enemy["fire"], 1.5)
	weapons.fire(enemy, enemy["weapon"], rng)
	assert_eq(shots.size(), 1, "Cooldown prevents duplicate emissions")

func test_standalone_radial_and_missile_profiles() -> void:
	var weapons = preload("res://combat/enemy_weapons.gd").new()
	var rng := RandomNumberGenerator.new()
	var enemy := Factory.create(SCOUT, 200.0, rng)
	var events := [0, 0]
	weapons.radial.connect(func(_origin, count, _speed, _rotation, _color, _radius): events[0] += count)
	weapons.missile.connect(func(_origin): events[1] += 1)
	enemy["fire"] = 0.0
	weapons.fire(enemy, preload("res://missions/weapons/radial.tres"), rng)
	assert_eq(events[0], 12)
	enemy["fire"] = 0.0
	weapons.fire(enemy, preload("res://missions/weapons/missile.tres"), rng)
	assert_eq(events[1], 1)
	assert_eq(enemy["fire"], 2.0)
