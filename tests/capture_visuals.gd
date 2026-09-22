extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_encounter_preview()
	game.rng.seed = 42
	game.player_pos = Vector2(360, 910)
	var enemy: Dictionary = game.enemies[0]
	enemy["pos"] = Vector2(360, 290)
	var laser: Dictionary = enemy["turrets"][1]
	laser["angle"] = PI * 0.5 - 0.22
	laser["origin"] = enemy["pos"] + laser["offset"] + Vector2.from_angle(laser["angle"]) * 24.0
	laser["state"] = "locked"
	laser["timer"] = 0.5
	game.elapsed = 4.0
	game.beam_visible_timer = 0.14
	game.beam_age = 0.08
	game._update_beam_visual(0.01)
	game.enemy_bullets.append(game.Missile.create(Vector2(210, 560), game.player_pos))
	game.enemy_bullets[0]["age"] = 1.1
	for i in range(7):
		game.enemy_bullets.append({"pos": Vector2(260 + i * 33, 600 + sin(i) * 40), "vel": Vector2.DOWN * 200, "radius": 5.0, "color": Color.RED, "age": 1.0, "grazed": false, "style": "dart"})
	DirAccess.make_dir_recursive_absolute("/tmp/starfall-captures")
	await save_frame(game, "shield-warning")
	enemy["shield"] = 0.0
	enemy["shield_break"] = 0.35
	laser["state"] = "firing"
	game.player_pos.x = 403.0
	game._update_beam_visual(0.01)
	await save_frame(game, "laser-active")
	game.HeavyEnemy.damage(game, enemy, 85.0, enemy["pos"] + laser["offset"], 1)
	game.beam_visible_timer = 0.014
	game._update_beam_visual(0.01)
	await save_frame(game, "turret-destroyed-release")
	game.beam_visible_timer = 0.0
	await save_frame(game, "recovery")
	game.beam_visible_timer = 0.19
	game.beam_age = 0.03
	game.muzzle_flash = 0.05
	game._update_beam_visual(0.01)
	game._spawn_explosion(Vector2(180, 470), Color.ORANGE, 24, 220.0)
	await save_frame(game, "flare-ignition")
	game._update_particles(0.11)
	await save_frame(game, "flare-decay")
	print("Visual captures saved to /tmp/starfall-captures")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit()

func save_frame(game, label: String) -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var error := img.save_png("/tmp/starfall-captures/%s.png" % label)
	if error != OK:
		push_error("Capture failed: " + label)
