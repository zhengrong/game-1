extends SceneTree

var failures := 0
var game
const Heavy = preload("res://combat/heavy_enemy.gd")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_encounter_preview()
	var enemy: Dictionary = game.enemies[0]
	var hp: float = enemy["hp"]
	game._damage_heavy(enemy, 102.0, enemy["pos"], 1)
	check(enemy["shield"] == 0.0 and enemy["hp"] == hp, "Shield must absorb the breaking hit without hurting hull")
	check(enemy["turrets"][1]["hp"] == 85.0, "Shield must protect turret health")
	game.player_pos.x = enemy["pos"].x + 43.0
	var hit: Dictionary = game._query_beam_hit(false)
	check(hit["part"] == 1, "Side aim should select laser turret rather than hull")
	var laser: Dictionary = enemy["turrets"][1]
	laser["state"] = "tracking"
	laser["timer"] = 0.01
	Heavy.update(game, enemy, 0.02)
	check(laser["state"] == "locked", "Tracking must enter a locked warning")
	var locked_origin: Vector2 = laser["origin"]
	var locked_angle: float = laser["angle"]
	game.player_pos.x += 120.0
	enemy["pos"].x += 20.0
	Heavy.update(game, enemy, 0.2)
	check(laser["state"] == "locked" and laser["origin"] == locked_origin and laser["angle"] == locked_angle, "Locked warning must not follow player/carrier")
	Heavy.update(game, enemy, 0.56)
	check(laser["state"] == "firing", "Laser must fire after its warning")
	game.player_invulnerable = 0.0
	game.player_pos = locked_origin + Vector2.from_angle(locked_angle) * 200.0
	Heavy.update(game, enemy, 0.01)
	check(game.player_hp == 2, "Active laser must damage within its displayed path")
	game._damage_heavy(enemy, 85.0, enemy["pos"] + laser["offset"], 1)
	check(laser["state"] == "destroyed" and enemy["hp"] == hp, "Turret destruction must preserve carrier hull")
	game.player_invulnerable = 0.0
	Heavy.update(game, enemy, 0.1)
	check(game.player_hp == 2, "Destroyed turret must stop laser damage immediately")
	game.enemy_bullets.clear()
	for distance in [100.0, 0.0]:
		game.enemy_bullets.append({"pos": game.player_pos + Vector2(distance, 0), "vel": Vector2.ZERO, "radius": 6.0, "age": 0.0, "grazed": false, "color": Color.RED})
	game._update_enemy_bullets(0.01)
	check(game.enemy_bullets.is_empty() and game.player_hp == 1, "Damage must clear nearby bullets safely")
	# Hold Pulse from exhaustion: no immediate alternate-frame activation.
	game.start_game()
	game.mouse_aura = true
	game.aura_energy = 0.01
	game._update_player(1.0 / 120.0)
	check(game.aura_exhausted, "Depleted Pulse must enter recharge lockout")
	for i in range(120):
		game._update_player(1.0 / 120.0)
	check(not game.aura_active, "Held exhausted Pulse must stay off below recharge threshold")
	# A missile announces its split before creating distinct secondary bullets.
	var missile: Dictionary = game.Missile.create(Vector2(100, 100), Vector2(100, 300))
	missile["age"] = 0.8
	check(not game.Missile.ready_to_split(missile, Vector2(100, 150)), "Missile must not split before its warning interval")
	missile["age"] = 1.4
	check(game.Missile.ready_to_split(missile, Vector2(100, 150)), "Armed missile must split near the player")
	check(game.Missile.fragments(missile).size() == 8, "Missile must produce eight radial fragments")
	# Relative pointer placement must not teleport the ship or accumulate an offset.
	game.start_game()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(70, 400)
	game._unhandled_input(press)
	check(game.player_target == game.player_pos, "Pointer placement must preserve ship position")
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(35, -20)
	game._unhandled_input(drag)
	check(game.player_target == game.player_pos + Vector2(35, -20), "Movement must follow relative pointer delta")
	# Weapon cycles must produce the same damage ticks at each refresh rate.
	var tick_counts: Array[int] = []
	for fps in [30, 60, 120]:
		game.start_game()
		for i in range(fps * 10):
			game._update_player_weapon_cycle(1.0 / fps)
		tick_counts.append(game.beam_damage_sequence)
	check(tick_counts[0] == tick_counts[1] and tick_counts[1] == tick_counts[2], "Weapon damage ticks must be frame-rate independent: %s" % str(tick_counts))
	# Exercise the real update path at multiple rates with effects and targeting.
	for fps in [30, 60, 120]:
		game.start_encounter_preview()
		for i in range(fps * 12):
			game.player_invulnerable = 100.0
			game.player_pos.x = 90.0 + fmod(i * 2.0, 520.0)
			game._process(1.0 / fps)
	# Exercise normal mission spawning, including spinner missiles and heavy escorts.
	game.start_game()
	for i in range(60 * 80):
		game.player_invulnerable = 100.0
		if not game.enemies.is_empty():
			game.player_pos.x = game.enemies[0]["pos"].x
		game._process(1.0 / 60.0)
	check(game.wave >= 3, "Normal mission must progress through the new heavy formations")
	print("COMBAT TESTS: %d failures" % failures)
	for player: AudioStreamPlayer in game.sound_pool:
		player.stop()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
