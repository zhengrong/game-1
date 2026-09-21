extends GutTest

var game

func before_each() -> void:
	game = load("res://main.tscn").instantiate()
	add_child_autofree(game)
	game.set_process(false)
	game.rng.seed = 12345

func after_each() -> void:
	for player: AudioStreamPlayer in game.sound_pool:
		player.stop()
	await get_tree().process_frame

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
	game.HeavyEnemy.damage(game, enemy, 102.0, enemy["pos"], 1)
	assert_eq(enemy["shield"], 0.0)
	assert_eq(enemy["hp"], hp)
	assert_eq(enemy["turrets"][1]["hp"], 85.0)
	game.player_pos.x = enemy["pos"].x + 43.0
	assert_eq(game._query_beam_hit(false)["part"], 1)
	game.HeavyEnemy.damage(game, enemy, 85.0, enemy["pos"], 1)
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
	game.HeavyEnemy.damage(game, enemy, 85.0, origin, 1)
	game.HeavyEnemy.damage(game, enemy, 85.0, origin, 1)
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
	game.wave_spawned = game.wave_goal
	game.wave_break = 0.0
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
