extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_game()
	game.enemies.clear()
	game.player_pos = Vector2(360, 1000)
	game.player_invulnerable = 0.0
	var enemy: Dictionary = game.EnemyFactory.create(preload("res://missions/enemies/boss.tres"), 360, game.rng)
	enemy["pos"] = Vector2(360, 420)
	game.enemies.append(enemy)
	game.doomsday_effects.append(game.Doomsday.create(enemy, "bomb", 1.5, 300))
	game._update_doomsday(0.9)
	await save(game, "bomb-warning")
	game._update_doomsday(0.65)
	await save(game, "bomb-detonation")
	game.doomsday_effects.clear()
	game.doomsday_effects.append(game.Doomsday.create(enemy, "super", 1.5, 300, 3))
	game._update_doomsday(0.9)
	await save(game, "super-charge")
	game._update_doomsday(0.65)
	game._update_enemy_bullets(0.7)
	await save(game, "super-carriers")
	game.player_invulnerable = 99.0
	for step in range(360):
		game._update_enemy_bullets(1.0 / 120.0)
	await save(game, "super-payload")
	game.queue_free()
	await process_frame
	quit()

func save(game, label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-reports/doomsday")
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://visual-reports/doomsday/%s.png" % label)
