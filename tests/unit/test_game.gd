extends GutTest

var game

func before_each() -> void:
	game = load("res://main.tscn").instantiate()
	game.ship_definition = load("res://ships/interceptor.tres")
	add_child_autofree(game)
	game.set_process(false)
	game.twin_shots = false # Most legacy tests explicitly exercise the beam profile.
	game.rng.seed = 12345

func after_each() -> void:
	for player: AudioStreamPlayer in game.sound_pool:
		player.stop()
	await get_tree().process_frame

func test_beam_phase_order_and_surface_alignment() -> void:
	var visual = game.BeamVisual
	assert_eq(visual.envelope(0.01, 0.26).phase, "attack")
	assert_eq(visual.envelope(0.1, 0.17).phase, "sustain")
	assert_eq(visual.envelope(0.2, 0.07).phase, "release")
	var release: Dictionary = visual.envelope(0.23, 0.04)
	assert_eq(release.wings, 0.0, "Feathers collapse before the core")
	assert_gt(release.core, 0.0)
	var residual: Dictionary = visual.envelope(0.255, 0.015)
	assert_eq(residual.core, 0.0, "White light disappears before the blue residual")
	assert_gt(residual.residual, 0.0)
	var recovery: Dictionary = visual.envelope(0.27, 0.0)
	assert_eq(recovery.phase, "recovery")
	for name in ["core", "wings", "residual", "fan"]:
		assert_eq(recovery[name], 0.0, "Recovery contains no weapon light")
	var muzzle := Vector2(280, 850)
	var contact := Vector2(280, 260)
	for age in [0.01, 0.08, 0.19, 0.26]:
		assert_almost_eq(visual.center_at(muzzle, contact, 0.0, age), muzzle, Vector2.ONE * 0.001)
		assert_almost_eq(visual.center_at(muzzle, contact, 1.0, age), contact, Vector2.ONE * 0.001)
	assert_ne(visual.center_at(muzzle, contact, 0.4, 0.06), visual.center_at(muzzle, contact, 0.4, 0.1), "The shaft deforms between frames")
	assert_lt(game.get_node("Backdrop").z_index, game.get_node("Flares").z_index)
	assert_lt(game.get_node("World").z_index, game.get_node("Flares").z_index, "Surface impacts remain visible above hulls")
	assert_lt(game.get_node("Flares").z_index, game.z_index, "Light cannot cover hostile bullets or the HUD")

func test_weapon_cadence_is_independent_of_refresh_rate() -> void:
	var counts: Array[int] = []
	for fps in [30, 60, 120]:
		game.start_game()
		for frame in range(fps * 10):
			game._update_player_weapon_cycle(1.0 / fps)
		counts.append(game.beam_damage_sequence)
	assert_eq(counts[0], counts[1])
	assert_eq(counts[1], counts[2])
	game.start_game()
	game._update_player_weapon_cycle(game.PLAYER_BEAM_FIRE_TIME + 0.001)
	assert_eq(game.beam_visible_timer, 0.0)
	assert_gt(game.beam_pause_timer, 0.1, "A real empty interval separates shots")

func test_fire_cools_and_fragment_history_is_bounded() -> void:
	game.particles.clear()
	game._spawn_hot_fragments(Vector2(100, 100), 1, 240.0)
	var fragment: Dictionary = game.particles[0]
	var previous_heat: float = game.FireVisual.heat(fragment)
	for i in range(30):
		game._update_particles(1.0 / 60.0)
		var energy: float = game.FireVisual.heat(fragment)
		assert_lte(energy, previous_heat, "Fragments cool rather than brighten as they age")
		previous_heat = energy
		assert_lte(fragment["trail"].size(), game.FireVisual.TRAIL_LIMIT)
	assert_gt(fragment["trail"].size(), 1, "Motion leaves a persistent path")
	assert_gt(fragment["trail"][0].distance_to(fragment["trail"][-1]), 5.0)
	game._update_particles(2.0)
	assert_true(game.particles.is_empty(), "Fragments and their trails cannot leak after expiry")
	assert_eq(game.FireVisual.heat(fragment), 0.0)
	assert_lte(fragment["trail"].size(), game.FireVisual.TRAIL_LIMIT, "A stalled frame cannot allocate an unbounded trail")

func test_fragment_trail_sampling_agrees_across_refresh_rates() -> void:
	var histories: Array = []
	for fps in [30, 60, 120]:
		var p := {"pos": Vector2.ZERO, "trail": PackedVector2Array([Vector2.ZERO]), "trail_clock": 0.0}
		for i in range(fps / 2):
			var previous: Vector2 = p.pos
			p.pos = Vector2((i + 1) * 180.0 / fps, 0.0)
			game.FireVisual.update_trail(p, previous, 1.0 / fps)
		histories.append(p.trail)
	for i in range(game.FireVisual.TRAIL_LIMIT):
		assert_almost_eq(histories[0][i], histories[1][i], Vector2.ONE * 0.01)
		assert_almost_eq(histories[1][i], histories[2][i], Vector2.ONE * 0.01)

func test_hull_fire_follows_source_then_releases() -> void:
	game.start_game()
	var enemy: Dictionary = enemy_at("heavy", Vector2(250, 300))
	game._spawn_damage_fire(enemy["pos"], 1.0, enemy)
	var flame: Dictionary = game.particles[0]
	flame["vel"] = Vector2.ZERO
	enemy["pos"] += Vector2(35, 12)
	game._update_particles(0.1)
	assert_almost_eq(flame["pos"], enemy["pos"], Vector2.ONE * 0.001)
	game._update_particles(0.2)
	assert_true(flame["source"].is_empty(), "Older flame billows detach from the hull")
	var released: Vector2 = flame["pos"]
	enemy["pos"] += Vector2(100, 0)
	game._update_particles(0.01)
	assert_eq(flame["pos"], released)
	game.particles.clear()
	game._spawn_damage_fire(enemy["pos"], 1.0, enemy)
	flame = game.particles[0]
	game.enemies.clear()
	game._update_particles(0.01)
	assert_true(flame["source"].is_empty(), "Destroyed source cannot retain a flame attachment")

func test_curved_fragments_are_independent_of_frame_rate() -> void:
	var endpoints: Array[Vector2] = []
	for fps in [30, 60, 120]:
		game.particles.clear()
		game.rng.seed = 77
		game._spawn_hot_fragments(Vector2.ZERO, 1, 200.0)
		var fragment: Dictionary = game.particles[0]
		fragment["initial_velocity"] = Vector2(200, 0)
		fragment["turn_rate"] = 1.2
		for i in range(fps / 2):
			game._update_particles(1.0 / fps)
		endpoints.append(fragment["pos"])
		assert_gt(fragment["pos"].y, 20.0, "Burning fragments should visibly curve")
	assert_almost_eq(endpoints[0], endpoints[1], Vector2.ONE * 0.001)
	assert_almost_eq(endpoints[1], endpoints[2], Vector2.ONE * 0.001)
	var straight := {"max_life": 1.0, "life": 0.5, "drag": 1.0, "turn_rate": 0.0,
		"initial_velocity": Vector2(200, 0), "origin": Vector2.ZERO}
	game.FireVisual.advance_fragment(straight)
	assert_eq(straight["pos"], Vector2(100, 0), "Zero turning/drag must stay finite")

func test_fragment_smoke_survives_head_and_expires_after_stall() -> void:
	game.particles.clear()
	game._spawn_hot_fragments(Vector2(100, 100), 1, 200.0)
	var fragment: Dictionary = game.particles[0]
	while fragment["life"] > 0.03:
		game._update_particles(0.025)
	game._update_particles(0.04)
	assert_eq(fragment["kind"], "ember_wake")
	assert_gt(fragment["life"], 0.0)
	assert_gt(fragment["trail"].size(), 1)
	assert_gt(fragment["smoke_age"], 0.0, "Smoke retains its age across the transition")
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var trail: PackedVector2Array = fragment["trail"].duplicate()
	game._update_particles(0.15)
	assert_eq(fragment["trail"], trail, "Cooling smoke retains the fragment path")
	game._update_particles(0.6)
	assert_true(game.particles.is_empty())
	game._spawn_hot_fragments(Vector2.ZERO, 1, 200.0)
	game._update_particles(3.0)
	assert_true(game.particles.is_empty(), "A stalled frame cannot resurrect smoke")

func test_energy_bursts_overlap_without_changing_combat() -> void:
	game.start_game()
	var hp: int = game.player_hp
	var rng_state: int = game.rng.state
	game._spawn_energy_burst(Vector2(200, 300), Color(0.2, 0.85, 1.8), 0.75)
	game._spawn_energy_burst(Vector2(240, 340), Color(1.5, 0.18, 0.9), 1.0)
	assert_eq(game.particles.size(), 4)
	assert_eq(game.rng.state, rng_state)
	var snapshot: Array = game.particles.duplicate(true)
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.particles, snapshot)
	assert_eq(game.player_hp, hp)
	game._update_particles(0.4)
	assert_eq(game.particles.size(), 3, "The blue core ends while the growing pink burst continues")
	game._update_particles(1.05)
	assert_eq(game.particles.size(), 1, "The pink shell briefly outlasts its core")
	game._update_particles(0.1)
	assert_true(game.particles.is_empty())

func test_twin_projectiles_sweep_nearest_shield_and_switch_modes() -> void:
	game.start_game()
	var enemy: Dictionary = enemy_at("heavy", Vector2(300, 300))
	var original_hp: float = enemy["hp"]
	game.player_pos = Vector2(300, 650)
	game._spawn_twin_shots()
	game._update_player_bullets(0.25)
	assert_lt(enemy["shield"], enemy["shield_max"], "Swept bolts hit the shield even across a large step")
	assert_eq(enemy["hp"], original_hp, "Shielded hull must not take bolt damage")
	assert_true(game.player_bullets.is_empty())
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_V
	game._unhandled_input(key)
	assert_true(game.twin_shots)
	game._update_player_weapon_cycle(0.1)
	assert_eq(game.player_bullets.size(), 2)
	game._update_player_bullets(0.05)
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	game._unhandled_input(key)
	assert_false(game.twin_shots)
	assert_eq(game.beam_visible_timer, 0.0)
	assert_gt(game.get_node("ThreatLayer").layer, game.get_node("WorldEnvironment").environment.background_canvas_max_layer)
	assert_gt(game.get_node("InterfaceLayer").layer, game.get_node("ThreatLayer").layer, "Menus stay above protected projectiles")

func test_twin_shot_cadence_at_different_frame_rates() -> void:
	var counts: Array[int] = []
	for fps in [30, 60, 120]:
		game.start_game()
		game.twin_shots = true
		for i in range(fps):
			game._update_player_weapon_cycle(1.0 / fps)
		counts.append(game.player_bullets.size())
	assert_eq(counts[0], 8)
	assert_eq(counts[0], counts[1])
	assert_eq(counts[1], counts[2])
	game.twin_shots = false

func test_campaign_can_be_completed() -> void:
	game.start_game()
	for i in range(120 * 120):
		game.player_invulnerable = 100.0
		if not game.enemies.is_empty():
			game.player_pos.x = game.enemies[0]["pos"].x
		game._process(1.0 / 120.0)
		if game.state == game.GameState.VICTORY:
			break
	assert_eq(game.state, game.GameState.VICTORY, "All four waves can be completed")
	assert_gt(game.score, 25000)
	assert_true(game.enemies.is_empty())

func test_shield_and_turret_damage_routing() -> void:
	game.start_encounter_preview()
	var enemy: Dictionary = game.enemies[0]
	var hp: float = enemy["hp"]
	game._damage_heavy(enemy, 102.0, enemy["pos"], 1)
	assert_eq(enemy["shield"], 0.0)
	assert_eq(enemy["hp"], hp)
	assert_eq(enemy["turrets"][1]["hp"], 85.0)
	game.player_pos.x = enemy["pos"].x + 43.0
	assert_eq(game._query_beam_hit(false)["part"], 1)
	game._damage_heavy(enemy, 85.0, enemy["pos"], 1)
	assert_eq(enemy["turrets"][1]["state"], "destroyed")
	assert_eq(enemy["hp"], hp)

func test_render_game_states() -> void:
	# Real CanvasItem draw notifications, not calls to _draw outside its context.
	for state in [game.GameState.TITLE, game.GameState.PLAYING, game.GameState.GAME_OVER, game.GameState.VICTORY]:
		game.start_encounter_preview()
		game.state = state
		game.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(game.state, state)

func bullet(pos: Vector2, velocity := Vector2.ZERO) -> Dictionary:
	return {"pos": pos, "vel": velocity, "radius": 6.0, "age": 0.0, "grazed": false, "color": Color.RED}

func enemy_at(kind: String, pos: Vector2) -> Dictionary:
	if kind == "boss":
		game._spawn_boss()
	else:
		game.wave = {"scout": 1, "spinner": 2, "heavy": 3}[kind]
		game.wave_spawned = 1 if kind == "spinner" else 0
		game._spawn_wave_enemy()
	var enemy: Dictionary = game.enemies.back()
	enemy["pos"] = pos
	enemy["anchor_x"] = pos.x
	return enemy

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	game._unhandled_input(event)

func mouse(pos: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = pressed
	game._unhandled_input(event)

func touch(index: int, pos: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	game._unhandled_input(event)

func pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	game._unhandled_input(event)

func test_launch_pause_resume_and_trial_retry() -> void:
	key(KEY_ENTER)
	assert_eq(game.state, game.GameState.PLAYING)
	key(KEY_ESCAPE)
	var elapsed: float = game.elapsed
	game._process(1.0)
	assert_true(game.paused)
	assert_eq(game.elapsed, elapsed)
	key(KEY_A)
	assert_false(game.paused)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	assert_false(game.paused)
	key(KEY_F2)
	assert_true(game.encounter_preview)
	game.state = game.GameState.GAME_OVER
	key(KEY_SPACE)
	assert_true(game.encounter_preview)
	assert_eq(game.player_hp, 3)
	key(KEY_F1)
	assert_eq(game.state, game.GameState.TITLE)
	assert_true(game.enemies.is_empty())
	pad(JOY_BUTTON_A)
	assert_eq(game.state, game.GameState.PLAYING)
	pad(JOY_BUTTON_START)
	assert_true(game.paused)
	pad(JOY_BUTTON_START)
	assert_false(game.paused)

func test_mouse_input_abilities_and_pause() -> void:
	mouse(Vector2(360, 500))
	assert_eq(game.state, game.GameState.PLAYING)
	mouse(Vector2(100, 500))
	assert_eq(game.player_target, game.player_pos, "New pointer position does not teleport")
	var movement := InputEventMouseMotion.new()
	movement.relative = Vector2(-50, -20)
	game._unhandled_input(movement)
	var old_pos: Vector2 = game.player_pos
	game._update_player(0.03)
	assert_lt(game.player_pos.x, old_pos.x)
	mouse(Vector2.ZERO, false)
	assert_false(game.pointer_active)
	mouse(game._aura_button_rect().get_center())
	game._update_player(0.01)
	assert_true(game.aura_active)
	mouse(Vector2.ZERO, false)
	assert_false(game.mouse_aura)
	game.nova_energy = game.MAX_NOVA
	mouse(game._nova_button_rect().get_center())
	assert_eq(game.nova_energy, 0.0)
	mouse(game._pause_button_rect().get_center())
	assert_true(game.paused)
	mouse(Vector2(200, 400))
	assert_false(game.paused)
	key(KEY_F1)
	mouse(Vector2(360, game.screen_size.y * 0.9))
	assert_true(game.encounter_preview)

func test_touch_finger_ownership_abilities_and_resume() -> void:
	touch(0, Vector2(360, 500))
	assert_eq(game.state, game.GameState.PLAYING)
	touch(2, Vector2(200, 400))
	assert_eq(game.pointer_index, 2)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.relative = Vector2(25, 30)
	var target: Vector2 = game.player_target
	game._unhandled_input(drag)
	assert_eq(game.player_target, target + drag.relative)
	touch(3, game._aura_button_rect().get_center())
	game._update_player(0.01)
	assert_true(game.aura_active)
	touch(3, Vector2.ZERO, false)
	assert_eq(game.aura_pointer_index, -1)
	assert_eq(game.pointer_index, 2, "Releasing the ability finger must preserve movement ownership")
	touch(2, Vector2.ZERO, false)
	assert_eq(game.pointer_index, -1)
	assert_false(game.pointer_active)
	game.nova_energy = game.MAX_NOVA
	touch(4, game._nova_button_rect().get_center())
	assert_eq(game.nova_energy, 0.0)
	touch(4, Vector2.ZERO, false)
	touch(0, game._pause_button_rect().get_center())
	assert_true(game.paused)
	touch(0, Vector2(100, 300))
	assert_false(game.paused)
	key(KEY_F1)
	touch(0, Vector2(360, game.screen_size.y * 0.9))
	assert_true(game.encounter_preview)

func test_polled_keyboard_movement_and_nova() -> void:
	game.start_game()
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	await get_tree().process_frame
	var x: float = game.player_pos.x
	game._update_player(0.1)
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	assert_gt(game.player_pos.x, x)
	event.keycode = KEY_E
	event.pressed = true
	game.nova_energy = game.MAX_NOVA
	Input.parse_input_event(event.duplicate())
	await get_tree().process_frame
	game._update_player(0.01)
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	assert_eq(game.nova_energy, 0.0)

func test_damage_clears_bullets_invulnerability_and_death() -> void:
	game.start_game()
	game.player_invulnerable = 0.0
	game.enemy_bullets.assign([bullet(game.player_pos + Vector2(100, 0)), bullet(game.player_pos)])
	game._update_enemy_bullets(0.01)
	assert_eq(game.player_hp, 2)
	assert_true(game.enemy_bullets.is_empty())
	game._damage_player()
	assert_eq(game.player_hp, 2, "Invulnerability prevents repeated hits")
	game.player_hp = 1
	game.player_invulnerable = 0.0
	game._damage_player()
	assert_eq(game.state, game.GameState.GAME_OVER)
	assert_false(game.aura_active)
	assert_false(game.pointer_active)
	var elapsed: float = game.elapsed
	game._process(0.2)
	assert_eq(game.elapsed, elapsed, "Death freezes mission timer")
	game._damage_player()
	assert_eq(game.player_hp, 0)

func test_swept_bullet_collision_and_graze_once() -> void:
	game.start_game()
	game.player_invulnerable = 0.0
	game.enemy_bullets.append(bullet(game.player_pos - Vector2(0, 100), Vector2(0, 2000)))
	game._update_enemy_bullets(0.1)
	assert_eq(game.player_hp, 2, "Bullet cannot tunnel through core")
	game.enemy_bullets.append(bullet(game.player_pos + Vector2(30, 0)))
	game._update_enemy_bullets(0.01)
	game._update_enemy_bullets(0.01)
	assert_eq(game.graze_count, 1)
	assert_gt(game.nova_energy, 18.0)

func test_pulse_absorption_exhaustion_and_recharge() -> void:
	game.start_game()
	game.mouse_aura = true
	game.enemy_bullets.assign([bullet(game.player_pos), bullet(game.player_pos + Vector2(200, 0))])
	game.aura_energy = 0.01
	game._update_player(0.01)
	assert_eq(game.enemy_bullets.size(), 1)
	assert_true(game.aura_exhausted)
	for i in range(120):
		game._update_player(1.0 / 120.0)
	assert_false(game.aura_active)
	game.aura_energy = 25.0
	game._update_player(0.01)
	assert_false(game.aura_exhausted)
	assert_true(game.aura_active)

func test_nova_shield_then_components_and_boss() -> void:
	game.start_encounter_preview()
	var heavy: Dictionary = game.enemies[0]
	var original_hp: float = heavy["hp"]
	game.nova_energy = 0.0
	game._try_nova()
	assert_eq(heavy["shield"], 102.0)
	game.nova_energy = game.MAX_NOVA
	game._try_nova()
	assert_eq(heavy["shield"], 0.0)
	assert_eq(heavy["hp"], original_hp)
	game.nova_energy = game.MAX_NOVA
	game._try_nova()
	assert_eq(heavy["hp"], original_hp - 240.0)
	assert_eq(heavy["turrets"][0]["state"], "destroyed")
	assert_eq(heavy["turrets"][1]["state"], "destroyed")
	var scout: Dictionary = enemy_at("scout", Vector2(200, 200))
	var boss: Dictionary = enemy_at("boss", Vector2(360, 200))
	var boss_hp: float = boss["hp"]
	game.nova_energy = game.MAX_NOVA
	game._try_nova()
	assert_false(game.enemies.has(scout))
	assert_eq(boss["hp"], boss_hp - 180.0)

func test_pickup_collection_attraction_and_expiration() -> void:
	game.start_game()
	game.aura_energy = 99.0
	game.nova_energy = 99.0
	game.pickups.assign([
		{"pos": game.player_pos, "vel": Vector2.ZERO, "life": 3.0},
		{"pos": game.player_pos + Vector2(100, 0), "vel": Vector2.ZERO, "life": 3.0},
		{"pos": Vector2(0, 100), "vel": Vector2.ZERO, "life": 0.01}])
	game._update_pickups(0.02)
	assert_eq(game.pickups.size(), 1)
	assert_lt(game.pickups[0]["vel"].x, 0.0)
	assert_eq(game.score, 180)
	assert_eq(game.aura_energy, 100.0)
	assert_eq(game.nova_energy, 100.0)

func test_legacy_projectiles_hit_expire_and_miss() -> void:
	game.start_game()
	var enemy: Dictionary = enemy_at("scout", Vector2(300, 300))
	for pos in [Vector2(300, 300), Vector2(50, -50), Vector2(50, 500)]:
		game.player_bullets.append({"pos": pos, "vel": Vector2.ZERO, "life": 1.0, "radius": 4.0, "damage": 100.0, "overcharged": true})
	game._update_player_bullets(0.1)
	assert_false(game.enemies.has(enemy))
	assert_eq(game.player_bullets.size(), 1)
	game._update_player_bullets(1.0)
	assert_true(game.player_bullets.is_empty())

func test_laser_warning_lock_damage_and_cancel() -> void:
	game.start_encounter_preview()
	var enemy: Dictionary = game.enemies[0]
	var laser: Dictionary = enemy["turrets"][1]
	laser["timer"] = 0.0
	game.HeavyEnemy.update(game, enemy, 0.01)
	assert_eq(laser["state"], "tracking")
	game.HeavyEnemy.update(game, enemy, 0.91)
	assert_eq(laser["state"], "locked")
	var origin: Vector2 = laser["origin"]
	var angle: float = laser["angle"]
	game.player_pos += Vector2(100, 0)
	game.HeavyEnemy.update(game, enemy, 0.2)
	assert_eq(laser["origin"], origin)
	assert_eq(laser["angle"], angle)
	game.HeavyEnemy.update(game, enemy, 0.56)
	assert_eq(laser["state"], "firing")
	game.player_pos = origin + Vector2.from_angle(angle) * 200.0
	game.player_invulnerable = 0.0
	game.HeavyEnemy.update(game, enemy, 0.01)
	assert_eq(game.player_hp, 2)
	enemy["shield"] = 0.0
	game._damage_heavy(enemy, 85.0, origin, 1)
	game._damage_heavy(enemy, 85.0, origin, 1)
	game.player_invulnerable = 0.0
	game.HeavyEnemy.update(game, enemy, 0.1)
	assert_eq(game.player_hp, 2)
	assert_eq(laser["state"], "destroyed")
	assert_gt(game.particles.size(), 0)

func test_dart_turret_cycle_has_three_projectiles_and_recovers() -> void:
	game.start_encounter_preview()
	var enemy: Dictionary = game.enemies[0]
	var dart: Dictionary = enemy["turrets"][0]
	dart["timer"] = 0.0
	for delta in [0.01, 0.46, 0.26]:
		game.HeavyEnemy.update(game, enemy, delta)
	assert_eq(dart["state"], "firing")
	assert_eq(game.enemy_bullets.size(), 3)
	for shot: Dictionary in game.enemy_bullets:
		assert_eq(shot["style"], "dart")
		assert_almost_eq(shot["vel"].length(), 300.0, 0.01)
	game.HeavyEnemy.update(game, enemy, 0.13)
	assert_eq(dart["state"], "cooldown")

func test_wave_break_rewards_and_completion() -> void:
	game.start_game()
	game._update_spawner(0.6)
	assert_eq(game.wave, 1)
	assert_eq(game.wave_goal, 10)
	game._update_spawner(10.0)
	for enemy in game.enemies:
		game.mission.enemy_removed(enemy["mission_token"], true)
	game.enemies.clear()
	game.enemy_bullets.append(bullet(Vector2(20, 20)))
	game.aura_energy = 0.0
	game.nova_energy = 0.0
	game._check_wave_complete()
	assert_eq(game.wave_break, 1.8)
	assert_eq(game.aura_energy, 28.0)
	assert_eq(game.nova_energy, 18.0)
	assert_true(game.enemy_bullets.is_empty())
	game.start_encounter_preview()
	game.enemies.clear()
	game._process(0.01)
	assert_eq(game.state, game.GameState.VICTORY)
	game._process(0.2)
	assert_almost_eq(game.mission_complete_timer, 0.2, 0.001)

func test_enemy_departure_and_slowing() -> void:
	game.start_game()
	for kind in ["scout", "spinner", "heavy"]:
		var enemy: Dictionary = enemy_at(kind, Vector2(200, 350))
		var initial_speed: float = enemy["vel"].y
		game._update_enemies(0.1)
		assert_lt(enemy["vel"].y, initial_speed)
		enemy["pos"].y = game.screen_size.y + 200.0
		game._update_enemies(0.01)
		assert_false(game.enemies.has(enemy))

func test_audio_samples_score_format_and_invalid_requests() -> void:
	for waveform in [0, 1, 2]:
		var stream: AudioStreamWAV = game._make_tone(440, 220, 0.1, 0.25, waveform)
		assert_eq(stream.data.size(), 4410)
		assert_eq(stream.mix_rate, 22050)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(game._format_score(-5), "0")
	assert_eq(game._format_score(1234567), "1,234,567")
	game.play_sound("missing")
	game._destroy_enemy(-1)
	assert_true(game.enemies.is_empty())
	assert_eq(game._enemy_color("unknown"), Color.WHITE)

func test_render_combat_effects_does_not_mutate_combat_state() -> void:
	game.start_game()
	assert_not_null(game.get_node("Fire").get_script(), "The fire canvas must load successfully")
	assert_true(game.get_node("Fire").material is ShaderMaterial, "Fire must use the procedural shader")
	assert_lt(game.get_node("Fire").z_index, game.z_index, "Fire stays behind hostile projectiles")
	var heavy: Dictionary = enemy_at("heavy", Vector2(360, 230))
	var scout: Dictionary = enemy_at("scout", Vector2(140, 200))
	var spinner: Dictionary = enemy_at("spinner", Vector2(560, 220))
	scout["hp"] = 20.0
	spinner["hp"] = 40.0
	game.player_pos = Vector2(360, 900)
	game.enemy_bullets.assign([bullet(Vector2(200, 500)), bullet(Vector2(240, 500), Vector2.DOWN)])
	var dart := bullet(Vector2(280, 500), Vector2.DOWN)
	dart["style"] = "dart"
	game.enemy_bullets.append(dart)
	var missile: Dictionary = game.Missile.create(Vector2(320, 500), game.player_pos)
	missile["age"] = 1.1
	game.enemy_bullets.append(missile)
	game._spawn_explosion(Vector2(500, 400), Color.ORANGE, 24, 220.0)
	game._spawn_thruster(Vector2(360, 930), Color.CYAN, 1.0)
	game._spawn_damage_fire(Vector2(500, 400), 0.8)
	game.pickups.append({"pos": Vector2(200, 700), "vel": Vector2.ZERO, "life": 2.0})
	game.shockwaves.append({"pos": Vector2(500, 400), "radius": 40.0, "max": 100.0, "life": 0.3, "color": Color.CYAN})
	game.shake = 2.0
	game.flash = 0.1
	game.aura_active = true
	game.aura_exhausted = true
	game.muzzle_flash = 0.05
	game.wave_banner = 1.0
	game.beam_contact = true
	game.beam_end = Vector2(360, 300)
	var laser: Dictionary = heavy["turrets"][1]
	laser["origin"] = heavy["pos"] + laser["offset"]
	var draws := [0]
	game.draw.connect(func(): draws[0] += 1)
	for phase in ["tracking", "locked", "firing", "cooldown", "destroyed"]:
		laser["state"] = phase
		laser["flash"] = 0.1
		if phase == "destroyed":
			laser["hp"] = 0.0
		heavy["shield_flash"] = 0.8
		game.beam_visible_timer = 0.12
		game.beam_age = 0.08
		var snapshot: Array = game.enemies.duplicate(true)
		game.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(game.enemies, snapshot, "Drawing must not change enemy state")
	assert_gte(draws[0], 5, "Real CanvasItem draw callbacks must run")
	heavy["shield"] = 0.0
	heavy["shield_break"] = 0.3
	for remaining in [0.21, 0.1, 0.04, 0.014, 0.0]:
		game.beam_visible_timer = remaining
		game.beam_age = 0.22 - remaining
		game.beam_overcharged = true
		game.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
	assert_eq(game.player_hp, 3, "Presentation alone cannot cause damage")
	# A target behind the muzzle must produce no invalid beam geometry.
	game.beam_visible_timer = 0.1
	game.beam_end.y = game.player_pos.y
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.player_hp, 3)

func test_explosion_flare_is_read_only_and_expires() -> void:
	game.start_game()
	game.particles.clear()
	game._spawn_explosion(Vector2(180, 470), Color.ORANGE, 24, 220.0)
	var flares: Array = game.particles.filter(func(p): return p["kind"] == "flare")
	assert_eq(flares.size(), 1, "One bounded ignition flash per explosion")
	var snapshot: Array = game.particles.duplicate(true)
	var rng_state: int = game.rng.state
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.particles, snapshot, "Drawing must not advance effect lifetimes")
	assert_eq(game.rng.state, rng_state, "Flare drawing must not consume gameplay randomness")
	game._update_particles(0.07)
	assert_eq(game.particles.filter(func(p): return p["kind"] == "ignition").size(), 0, "The white impact ends before the warm flare")
	assert_eq(game.particles.filter(func(p): return p["kind"] == "blast_ring").size(), 1, "The expanding shell outlasts ignition")
	game._update_particles(0.16)
	assert_eq(game.particles.filter(func(p): return p["kind"] == "flare").size(), 0, "Ignition fades before the smoke")
	game._update_particles(0.2)
	assert_eq(game.particles.filter(func(p): return p["kind"] == "blast_ring").size(), 0, "The impact shell cannot persist indefinitely")

func test_render_boss_pause_and_dead_player() -> void:
	game.start_game()
	game.wave = 4
	game.wave_banner = 1.0
	enemy_at("boss", Vector2(360, 230))
	game.paused = true
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(game.paused)
	assert_eq(game.enemies.size(), 1)
	game.player_hp = 0
	game.state = game.GameState.GAME_OVER
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.player_hp, 0)

func test_particle_compaction_preserves_order_and_motion() -> void:
	game.particles.clear()
	var survivors: Array[Dictionary] = []
	for i in range(100):
		var particle := {"kind": "fire", "pos": Vector2(i, 10),
			"vel": Vector2(12, -6) if i % 2 == 0 else Vector2.ZERO,
			"life": 0.01 if i % 3 == 0 else 1.0, "max_life": 1.0,
			"size": 20.0, "growth": 5.0, "drag": 0.1, "id": i}
		game.particles.append(particle)
		if i % 3 != 0:
			survivors.append(particle)
	game._update_particles(0.1)
	assert_eq(game.particles.size(), survivors.size())
	for i in range(survivors.size()):
		var particle: Dictionary = game.particles[i]
		var identifier: int = survivors[i]["id"]
		assert_eq(particle["id"], identifier, "Expiry must preserve compositing order")
		var velocity := Vector2(12, -6) if identifier % 2 == 0 else Vector2.ZERO
		assert_almost_eq(particle["pos"], Vector2(identifier, 10) + velocity * 0.1, Vector2.ONE * 0.0001)
		assert_almost_eq(particle["vel"], velocity * pow(0.1, 0.1), Vector2.ONE * 0.0001)
		assert_almost_eq(particle["life"], 0.9, 0.0001, "Every survivor advances exactly once")
	game._update_particles(2.0)
	assert_true(game.particles.is_empty())
	game._update_particles(0.1)
	assert_true(game.particles.is_empty(), "An empty particle pass is safe")

func test_custom_mission_boss_is_not_automatic_victory() -> void:
	var definition = preload("res://missions/mission_definition.gd").new()
	definition.initial_delay = 0.0
	for kind in ["boss", "scout"]:
		var stage = preload("res://missions/stage_definition.gd").new()
		stage.transition_delay = 0.0
		var group = preload("res://missions/spawn_group.gd").new()
		group.enemies.append(load("res://missions/enemies/%s.tres" % kind))
		group.start_time = 0.0
		stage.groups.append(group)
		definition.stages.append(stage)
	game.mission_definition = definition
	game.start_game()
	game._update_spawner(0.0)
	game._update_spawner(0.0)
	assert_eq(game.enemies[0]["kind"], "boss")
	game._destroy_enemy(0)
	assert_eq(game.state, game.GameState.PLAYING, "Intermediate bosses cannot end the mission")
	game._check_wave_complete()
	game._update_spawner(0.0)
	game._update_spawner(0.0)
	assert_eq(game.wave, 2)
	assert_eq(game.enemies[0]["kind"], "scout")
	game._destroy_enemy(0)
	game._check_wave_complete()
	assert_eq(game.state, game.GameState.VICTORY)
	game.start_encounter_preview()
	assert_eq(game.enemies[0]["kind"], "heavy", "Preview does not depend on mission stage count")

func test_select_ship_applies_loadout_and_clears_old_combat() -> void:
	var bulwark = preload("res://ships/bulwark.tres")
	game.start_game()
	game._spawn_twin_shots()
	game._start_player_beam()
	game.select_ship(bulwark)
	assert_eq(game.player_hp, 5)
	assert_eq(game.MAX_AURA, 140.0)
	assert_eq(game.MAX_NOVA, 120.0)
	assert_eq(game.PLAYER_RADIUS, 14.0)
	assert_eq(game.PLAYER_SPEED, 520.0)
	assert_true(game.twin_shots)
	assert_true(game.player_bullets.is_empty())
	assert_eq(game.beam_visible_timer, 0.0)
	game._spawn_twin_shots()
	assert_eq(game.player_bullets[0]["damage"], 32.0)
	assert_eq(game.player_bullets[0]["vel"], Vector2(0, -1800))
	assert_eq(game.player_bullets[0]["pos"], game.player_pos + Vector2(-26, -80))
	game.player_invulnerable = 0.0
	game._damage_player()
	assert_eq(game.player_hp, 4)
	game.start_game()
	assert_eq(game.player_hp, 5)
	assert_eq(bulwark.health, 5)

func test_configured_beam_damage_and_offset_are_used() -> void:
	var definition = preload("res://ships/ship_definition.gd").new()
	definition.muzzle = Vector2(40, -80)
	definition.weapon.beam_damage = 5.0
	game.select_ship(definition)
	game.player_pos = Vector2(300, 800)
	game._spawn_boss()
	var target: Dictionary = game.enemies[0]
	target["pos"] = Vector2(340, 300)
	target["radius"] = 15.0
	var health: float = target["hp"]
	game._fire_player_weapon()
	assert_eq(target["hp"], health - 5.0)

func test_shield_loadout_controls_projectiles_and_laser_reflection() -> void:
	game.select_ship(preload("res://ships/guardian.tres"))
	game.player_pos = Vector2(360, 850)
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.mouse_aura = true
	game._update_player(0.01)
	assert_eq(game.shields.fields.size(), 1)
	assert_almost_eq(game.aura_energy, game.shields.config.aura_regen_rate * 0.01, 0.00001)
	game._update_player(0.01)
	assert_eq(game.shields.fields.size(), 1, "Holding an aura button cannot repeatedly deploy")
	game.enemy_bullets.append(bullet(Vector2(360, 400), Vector2(0, 2000)))
	game._update_enemy_bullets(0.3)
	assert_true(game.enemy_bullets.is_empty(), "Shield stops a swept projectile before hull damage")
	game.shields.fields.clear()
	game.zen_button = true
	game.mouse_aura = false
	game._update_player(0.6)
	assert_true(game.shields.protected())
	game._spawn_boss()
	var target: Dictionary = game.enemies[0]
	var hp: float = target["hp"]
	var end: Vector2 = game._intercept_laser(Vector2(360, 100), Vector2(360, 1500), 0.1)
	assert_lt(end.y, game.player_pos.y)
	assert_eq(target["hp"], hp, "Reflection applies after enemy iteration")
	game._apply_shield_reflections()
	assert_almost_eq(target["hp"], hp - 2.0, 0.001)
	assert_eq(game.reflected_rays.size(), 1)
	game.player_invulnerable = 0.0
	game._damage_player()
	assert_eq(game.player_hp, 3)
	game._try_nova()
	assert_eq(game.nova_energy, 18.0, "Personal Shield never consumes nova energy")
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	game.shields.advance(0.1, game.player_pos, false)
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame

func test_shield_touch_selection_release_and_pause() -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.index = 0
	event.position = Vector2(game.screen_size.x * 0.75, game.screen_size.y * 0.96)
	game._unhandled_input(event)
	assert_eq(game.ship_definition.display_name, "Phalanx")
	event.position = game.player_pos
	game._unhandled_input(event)
	event.pressed = false
	game._unhandled_input(event)
	assert_true(game.zen_released)
	game._update_player(0.3)
	assert_gt(game.shields.charge, 0.0)
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	event.pressed = true
	game._unhandled_input(event)
	game._update_player(0.01)
	assert_eq(game.shields.charge, 0.0)
	event.index = 1
	event.position = game._nova_button_rect().get_center()
	game._unhandled_input(event)
	assert_false(game.zen_button, "Second finger deploys Aura even over the optional Zen button")
	assert_eq(game.shields.fields.size(), 1)
	event.pressed = false
	game._unhandled_input(event)
	assert_false(game.zen_button)
	game.shields.deploy(100.0, 100.0)
	for strength in [24.0, 10.0, 2.0, 0.0]:
		game.shields.fields[0]["strength"] = strength
		game.shields.fields[0]["fading"] = strength == 0.0
		game.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
	game.paused = true
	var age: float = game.shields.fields[0]["fade"]
	game._process(1.0)
	assert_eq(game.shields.fields[0]["fade"], age)
	game.start_game()
	assert_true(game.shields.fields.is_empty())

func test_barrier_rendering_and_personal_timeout() -> void:
	game.select_ship(preload("res://ships/guardian.tres"))
	game.shields.deploy(100.0, 100.0)
	game.shields.intercept(game.player_pos - Vector2(0, 400), game.player_pos, 4.0)
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	game.shields.advance(0.6, game.player_pos, true)
	game.shields.advance(2.5, game.player_pos, true)
	assert_gt(game.shields.fade, 0.0)
	game.shields.advance(0.3, game.player_pos, true)
	assert_false(game.shields.protected())
	assert_true(game.shields.exhausted)

func test_zen_holds_position_and_stops_main_weapon() -> void:
	game.select_ship(preload("res://ships/guardian.tres"))
	game._start_player_beam()
	game.pointer_active = true
	game.player_target = game.player_pos + Vector2(100, -100)
	game.zen_button = true
	var origin: Vector2 = game.player_pos
	game._update_player(0.1)
	assert_eq(game.player_pos, origin)
	assert_eq(game.beam_visible_timer, 0.0)
	game.zen_button = false
	game._update_player(0.1)
	assert_ne(game.player_pos, origin)
	assert_gt(game.player_bullets.size(), 0, "Default shield ship resumes twin shots")

func test_kill_energy_arrives_only_on_collection_and_does_not_charge_zen() -> void:
	game.select_ship(load("res://ships/guardian.tres"))
	game.aura_energy = 0.0
	var original_nova: float = game.nova_energy
	enemy_at("scout", game.player_pos - Vector2(0, 500))
	game._destroy_enemy(game.enemies.size() - 1)
	assert_eq(game.aura_energy, 0.0, "Death must not credit remote energy")
	assert_eq(game.pickups.size(), 1)
	game._on_stage_cleared()
	assert_eq(game.aura_energy, 0.0, "Stage completion must not bypass collection")
	game._update_pickups(0.1)
	assert_eq(game.aura_energy, 0.0, "Energy must visibly travel before collection")
	for step in range(240):
		game._update_pickups(1.0 / 60.0)
	assert_eq(game.pickups.size(), 0, "Energy homes from beyond the old attraction radius")
	assert_almost_eq(game.aura_energy, 12.0, 0.001)
	assert_eq(game.nova_energy, original_nova, "Collected energy does not charge Zen")
	game._update_pickups(1.0)
	assert_almost_eq(game.aura_energy, 12.0, 0.001, "A pickup credits energy exactly once")

func test_heavy_drop_budget_swept_collection_and_victory() -> void:
	game.start_game()
	game.aura_energy = 0.0
	game.nova_energy = 0.0
	enemy_at("heavy", Vector2(300, 300))
	game._destroy_enemy(game.enemies.size() - 1)
	assert_eq(game.aura_energy, 0.0)
	assert_eq(game.nova_energy, 0.0)
	assert_eq(game.pickups.size(), 3)
	for pickup in game.pickups:
		pickup["pos"] = game.player_pos
	game._update_pickups(0.01)
	assert_almost_eq(game.aura_energy, 20.0, 0.001)
	assert_almost_eq(game.nova_energy, 16.5, 0.001)
	game.pickups.append({"pos": game.player_pos - Vector2(100, 0),
		"vel": Vector2(2000, 0), "life": 3.0, "aura": 5.0})
	game.state = game.GameState.VICTORY
	game._process(0.1)
	assert_eq(game.pickups.size(), 0, "Fast energy cannot tunnel through the ship, even after victory")
	assert_almost_eq(game.aura_energy, 25.0, 0.001)

func test_enemy_weapons_have_distinct_projectiles_and_preserve_profiles() -> void:
	game.start_game()
	var scout: Dictionary = enemy_at("scout", Vector2(300, 200))
	scout["fire"] = 0.0
	game.enemy_weapons.fire(scout, scout["weapon"], game.rng)
	assert_eq(game.enemy_bullets.back()["style"], "capsule")
	var spinner: Dictionary = enemy_at("spinner", Vector2(300, 250))
	spinner["age"] = 2.0
	spinner["fire"] = 0.0
	game.enemy_weapons.fire(spinner, preload("res://missions/weapons/spinner.tres"), game.rng)
	assert_eq(game.enemy_bullets.back()["style"], "orb")
	var boss: Dictionary = enemy_at("boss", Vector2(300, 200))
	for phase in [0.0, 1.5, 3.0]:
		boss["age"] = phase
		boss["fire"] = 0.0
		game.enemy_weapons.fire(boss, boss["weapon"], game.rng)
		var expected: String = "orb" if phase == 0.0 else ("dart" if phase == 1.5 else "lance")
		assert_eq(game.enemy_bullets.back()["style"], expected)
	var profile = preload("res://missions/enemy_weapon_definition.gd").new()
	profile.projectile_style = "lance"
	profile.color = Color(0.8, 0.15, 0.7)
	profile.speed = 410.0
	scout["fire"] = 0.0
	game.enemy_weapons.fire(scout, profile, game.rng)
	assert_eq(game.enemy_bullets.back()["color"], profile.color)
	assert_almost_eq(game.enemy_bullets.back()["vel"].length(), 410.0, 0.01)
	assert_eq(game.enemy_bullets.back()["radius"], profile.radius)
	var missile: Dictionary = game.Missile.create(Vector2.ZERO, Vector2.DOWN)
	assert_eq(game.Missile.fragments(missile)[0]["style"], "orb")
	# Exercise all presentation branches without changing projectile state or RNG.
	var snapshot: Array = game.enemy_bullets.duplicate(true)
	var rng_state: int = game.rng.state
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.enemy_bullets, snapshot)
	assert_eq(game.rng.state, rng_state)

func test_laser_mirv_death_payload_and_laser_damage() -> void:
	game.start_game()
	game.enemy_bullets.clear()
	var carrier: Dictionary = game.Missile.create(Vector2(200, 200), game.player_pos)
	carrier["payload"] = "laser"
	carrier["count"] = 5
	carrier["age"] = 3.0
	game.enemy_bullets.append(carrier)
	game._update_enemy_bullets(0.01)
	assert_eq(game.enemy_lasers.size(), 5)
	assert_true(game.enemy_bullets.is_empty())
	game.player_invulnerable = 0.0
	game.enemy_lasers.clear()
	game.enemy_lasers.append(game.EnemyLaser.create(game.player_pos - Vector2(0, 200), PI * 0.5, 0.5, 0.3, 8))
	game._update_enemy_lasers(0.4)
	assert_eq(game.player_hp, 3, "Warning cannot damage the ship")
	game.queue_redraw()
	await get_tree().process_frame
	game._update_enemy_lasers(0.2)
	assert_eq(game.player_hp, 2)
	game.queue_redraw()
	await get_tree().process_frame
	game._update_enemy_lasers(1.0)
	assert_true(game.enemy_lasers.is_empty())
	var enemy: Dictionary = game.EnemyFactory.create(preload("res://missions/enemies/caged_mirv.tres"), 200, game.rng)
	game.enemies.append(enemy)
	game._destroy_enemy(game.enemies.size() - 1)
	assert_eq(game.enemy_bullets.size(), 8)
	for style in ["shuriken", "boomerang", "pellet"]:
		game.enemy_bullets.append(game.EnemyProjectile.create(Vector2(200, 300), Vector2.DOWN * 300, 6, Color.RED, style, 0.8))
	game.enemy_bullets.append(carrier)
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	game.start_game()
	assert_true(game.enemy_lasers.is_empty())

func test_new_lasers_cancel_with_source_and_are_blocked_by_personal_shield() -> void:
	game.select_ship(preload("res://ships/guardian.tres"))
	var boss: Dictionary = enemy_at("boss", Vector2(300, 200))
	boss["hp"] = boss["max_hp"] * 0.3
	boss["age"] = 5.0
	boss["fire"] = 0.0
	game.enemy_weapons.fire(boss, boss["weapon"], game.rng, game.player_pos, 0.1)
	assert_eq(game.enemy_lasers.size(), 1)
	assert_eq(game.enemy_lasers[0]["width"], 36.0)
	game.enemies.clear()
	game._update_enemy_lasers(0.1)
	assert_true(game.enemy_lasers.is_empty(), "Destroying the firing hull cancels its warning")
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.shields.advance(0.6, game.player_pos, true)
	game.player_invulnerable = 0.0
	var ray: Dictionary = game.EnemyLaser.create(game.player_pos - Vector2(0, 300), PI * 0.5, 0.1, 0.5, 8.0)
	game.enemy_lasers.append(ray)
	game._update_enemy_lasers(0.2)
	assert_eq(game.player_hp, 3)
	assert_lt(ray["blocked_end"].y, game.player_pos.y)

func test_doomsday_bomb_warning_barrier_destruction_and_personal_protection() -> void:
	game.select_ship(preload("res://ships/guardian.tres"))
	game.player_invulnerable = 0.0
	var enemy: Dictionary = enemy_at("boss", game.player_pos - Vector2(0, 100))
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.shields.deploy(100, 100)
	var blast: Dictionary = game.Doomsday.create(enemy, "bomb", 1.5, 300)
	game.doomsday_effects.append(blast)
	game._update_doomsday(1.0)
	assert_eq(game.player_hp, 3)
	assert_eq(game.shields.fields.size(), 1)
	game.queue_redraw()
	await get_tree().process_frame
	game._update_doomsday(0.6)
	assert_eq(game.player_hp, 2, "Barrier cannot protect against the bomb")
	assert_true(game.shields.fields.is_empty())
	game.queue_redraw()
	await get_tree().process_frame
	game._update_doomsday(1.0)
	assert_true(game.doomsday_effects.is_empty())
	game.player_invulnerable = 0.0
	game.shields.advance(0.6, game.player_pos, true)
	game.doomsday_effects.append(game.Doomsday.create(enemy, "bomb", 0.1, 300))
	game._update_doomsday(0.2)
	assert_eq(game.player_hp, 2, "Personal Shield protects against the blast")
	game.doomsday_effects.clear()
	game.doomsday_effects.append(game.Doomsday.create(enemy, "super", 1.5, 300))
	game.enemies.clear()
	game._update_doomsday(2.0)
	assert_true(game.doomsday_effects.is_empty(), "Destroyed launcher cannot finish charging")

func test_super_mirv_launch_split_overload_and_boss_cycle() -> void:
	game.select_ship(preload("res://ships/phalanx.tres"))
	var enemy: Dictionary = enemy_at("boss", Vector2(300, 200))
	game.doomsday_effects.append(game.Doomsday.create(enemy, "super", 0.1, 300, 3))
	game._update_doomsday(0.2)
	assert_eq(game.enemy_bullets.size(), 3)
	game.queue_redraw()
	await get_tree().process_frame
	game._update_doomsday(0.01)
	assert_eq(game.enemy_bullets.size(), 3, "Launch happens once")
	game.enemy_bullets.clear()
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.shields.deploy(100, 100)
	var super_mirv: Dictionary = game.Missile.create_super(game.player_pos - Vector2(0, game.shields.config.phalanx_radius + 30), game.player_pos)
	super_mirv["vel"] = Vector2.DOWN * 400
	game.enemy_bullets.append(super_mirv)
	game._update_enemy_bullets(0.1)
	assert_true(game.enemy_bullets.is_empty(), "Shield intercept occurs before splitting")
	assert_true(game.shields.fields[0]["fading"])
	assert_eq(game.shields.fields[0]["strength"], 0.0)
	game.shields.fields.clear()
	game.player_invulnerable = 99
	game.enemy_bullets.append(game.Missile.create_super(game.player_pos - Vector2(0, 150), game.player_pos))
	game._update_enemy_bullets(0.01)
	assert_eq(game.enemy_bullets.size(), 6)
	game._update_enemy_bullets(0.01)
	assert_eq(game.enemy_bullets.size(), 48)
	enemy["hp"] = enemy["max_hp"] * 0.3
	game.doomsday_effects.clear()
	for phase in [1, 2]:
		enemy["doom_phase"] = phase
		enemy["age"] = 20.0
		enemy["next_doom"] = 0.0
		enemy["fire"] = 0.0
		game.enemy_weapons.fire(enemy, enemy["weapon"], game.rng)
	assert_eq(game.doomsday_effects[0]["kind"], "bomb")
	assert_eq(game.doomsday_effects[1]["kind"], "super")
	game.start_game()
	assert_true(game.doomsday_effects.is_empty())

func test_player_default_twins_keep_launch_origin_and_draw_without_mutation() -> void:
	for name in ["interceptor", "guardian", "phalanx"]:
		game.select_ship(load("res://ships/%s.tres" % name))
		assert_true(game.twin_shots, "Selected default loadout uses the reference twin weapon")
	game._spawn_twin_shots()
	assert_eq(game.player_bullets.size(), 2)
	var original: Vector2 = game.player_bullets[0]["origin"]
	game.player_pos.x += 100
	game._update_player_bullets(0.05)
	assert_eq(game.player_bullets[0]["origin"], original, "Trail stays on its launch path when the player moves")
	assert_almost_eq(game.player_bullets[0]["pos"].x, original.x, 0.001)
	for age in [0.0, 0.08, 0.4]:
		for shot in game.player_bullets:
			shot["age"] = age
		var snapshot: Array = game.player_bullets.duplicate(true)
		game.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(game.player_bullets, snapshot)

func test_default_shield_loadout_and_art_sized_boundaries() -> void:
	var scene = load("res://main.tscn").instantiate()
	assert_eq(scene.ship_definition.display_name, "Shield")
	scene.free()
	for profile in [preload("res://ships/guardian.tres"), preload("res://ships/phalanx.tres")]:
		game.select_ship(profile)
		game.start_encounter_preview()
		game.shields.reset(profile.shields, game.player_pos)
		assert_gt(profile.shields.personal_radius, profile.visual_size.y * 0.5)
		game.shields.advance(profile.shields.personal_charge, game.player_pos, true)
		var hit: Dictionary = game.shields.intercept(game.player_pos - Vector2(0, 160), game.player_pos, 0.0)
		assert_almost_eq(hit["point"].distance_to(game.player_pos), profile.shields.personal_radius, 0.01)
		game.shields.reset(profile.shields, game.player_pos)
		game.shields.deploy(100, 100)
		var field: Dictionary = game.shields.fields[0]
		var radius: float = field["radius"]
		var blocked: Dictionary = game.shields.intercept(game.player_pos - Vector2(0, radius + 30), game.player_pos, 0.0)
		assert_false(blocked.is_empty())
		assert_almost_eq(blocked["point"].distance_to(game.player_pos), radius, 0.01)
		if profile.shields.aura == game.ShieldConfig.Aura.PHALANX:
			assert_true(game.shields.intercept(game.player_pos + Vector2(0, radius + 30), game.player_pos, 0.0).is_empty(), "Rear remains exposed")

func test_phoenix_shield_reserve_and_second_finger_controls() -> void:
	game.select_ship(preload("res://ships/guardian.tres"))
	game.start_encounter_preview()
	game.aura_energy = 0.0
	game._update_player(1.0)
	assert_almost_eq(game.aura_energy, 10.0 / 3.0, 0.001)
	game._update_player(5.0)
	assert_eq(game.aura_energy, 10.0, "Automatic reserve cannot fund a Barrier")
	assert_eq(game.shields.deploy(29.0, game.MAX_AURA), 0.0)
	assert_eq(game.shields.deploy(30.0, game.MAX_AURA), 30.0)
	game.aura_energy = 0.0
	game.zen_button = true
	game._update_player(0.1)
	assert_eq(game.aura_energy, 0.0, "Zen suspends reserve regeneration")
	game.zen_button = false
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.aura_energy = 100.0
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.position = Vector2(300, 700)
	finger.pressed = true
	game._unhandled_input(finger)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = Vector2(450, 700)
	second.pressed = true
	game._unhandled_input(second)
	assert_eq(game.shields.fields.size(), 1)
	assert_eq(game.pointer_index, 0, "Second finger must not steal movement")
	assert_eq(game.aura_energy, 0.0)
	second.pressed = false
	game._unhandled_input(second)
	assert_false(game.zen_released)
	finger.pressed = false
	game._unhandled_input(finger)
	game._update_player(0.6)
	assert_true(game.shields.protected(), "Lifting movement finger activates Personal Shield")
	game.select_ship(preload("res://ships/phalanx.tres"))
	assert_eq(game.MAX_AURA, 120.0)
	assert_eq(game.shields.deploy(59, game.MAX_AURA), 0.0)
	assert_eq(game.shields.deploy(60, game.MAX_AURA), 60.0)

func test_six_shield_charges_collect_then_spend_one_per_activation() -> void:
	game.select_ship(preload("res://ships/charged_shield.tres"))
	game.start_encounter_preview()
	assert_eq(game.MAX_AURA, 360.0)
	assert_false(game.ship_definition.shields.personal_enabled)
	for remaining in range(5, -1, -1):
		game.mouse_aura = true
		game._update_player(0.0)
		assert_eq(game.aura_energy, float(remaining * 60))
		assert_eq(game.shields.fields.size(), 1, "Reactivation replaces the current shield")
		game._update_player(0.0)
		assert_eq(game.aura_energy, float(remaining * 60), "Holding cannot spend another charge")
		game.mouse_aura = false
		game._update_player(0.0)
	game.shields.fields.clear()
	game.mouse_aura = true
	game._update_player(0.0)
	assert_true(game.shields.fields.is_empty(), "Empty circles cannot activate a shield")
	game.mouse_aura = false
	game._update_player(0.0)
	game.pickups.append({"pos": game.player_pos, "vel": Vector2.ZERO, "life": 1.0, "aura": 65.0})
	game._update_pickups(0.0)
	assert_eq(game.aura_energy, 65.0)
	assert_true(game.shields.fields.is_empty(), "Collection stores energy without activation")
	assert_true(game.shields.charge_pulses.has(0))
	game.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	game.mouse_aura = true
	game._update_player(0.0)
	assert_eq(game.aura_energy, 5.0, "One activation keeps partial progress for the next circle")
	game.mouse_aura = false
	game.shields.fields.clear()
	game.zen_released = true
	game._update_player(1.0)
	assert_false(game.shields.protected(), "Releasing touch cannot create a second shield type")
	assert_true(game.shields.fields.is_empty())
	assert_true(game.shields.charge_pulses.is_empty())
	game.nova_energy = game.MAX_NOVA
	game._try_nova()
	assert_eq(game.nova_energy, game.MAX_NOVA, "The single-shield loadout has no Nova")
