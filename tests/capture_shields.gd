extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.rng.seed = 42
	game.select_ship(preload("res://ships/guardian.tres"))
	game.start_encounter_preview()
	game.player_invulnerable = 0.0
	game.player_pos = Vector2(360, 880)
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.shields.deploy(75.0, 100.0)
	game.player_pos += Vector2(0, 60)
	game.shields.advance(0.1, game.player_pos, false)
	for x in range(160, 560, 30):
		game.enemy_bullets.append({"pos": Vector2(x, 650), "vel": Vector2.DOWN * 150, "radius": 5.0, "color": Color.RED, "age": 1.0, "grazed": false})
	await save(game, "barrier")
	game.shields.fields.clear()
	game.shields.advance(0.3, game.player_pos, true)
	await save(game, "charging")
	game.shields.advance(0.3, game.player_pos, true)
	game._intercept_laser(Vector2(360, 160), Vector2(360, 1280), 0.016)
	await save(game, "personal-reflection")
	game.shields.advance(0.01, game.player_pos, false)
	await save(game, "personal-fade")
	game.select_ship(preload("res://ships/phalanx.tres"))
	game.start_encounter_preview()
	game.player_invulnerable = 0.0
	game.player_pos = Vector2(360, 880)
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.shields.deploy(100, 100)
	game.shields.advance(0.3, game.player_pos, false)
	game.shields.intercept(game.player_pos - Vector2(0, 120), game.player_pos, 0.0)
	game.shields.advance(0.08, game.player_pos, false)
	await save(game, "phalanx")
	game.shields.fields[0]["strength"] = 2.0
	await save(game, "phalanx-weak")
	game.shields.fields[0]["fading"] = true
	game.shields.fields[0]["fade"] = 0.1
	await save(game, "phalanx-breaking")
	game.queue_free()
	await process_frame
	quit()

func save(game, label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-reports/shields")
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://visual-reports/shields/%s.png" % label)
	print("Shield capture: " + label)
