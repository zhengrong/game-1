extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_game()
	game.enemies.clear()
	game.player_invulnerable = 99.0
	game.player_pos = Vector2(360, 1100)
	game.rng.seed = 42
	var definitions := [preload("res://missions/enemies/dart_stream.tres"), preload("res://missions/enemies/shuriken.tres"), preload("res://missions/enemies/boomerang.tres"), preload("res://missions/enemies/laser_mirv.tres")]
	for i in range(definitions.size()):
		var enemy: Dictionary = game.EnemyFactory.create(definitions[i], 110 + i * 165, game.rng)
		enemy["pos"] = Vector2(110 + i * 165, 220 + i % 2 * 100)
		enemy["fire"] = 0.0
		game.enemies.append(enemy)
	DirAccess.make_dir_recursive_absolute("res://visual-reports/enemy-weapons")
	for step in range(361):
		var delta := 1.0 / 120.0
		for enemy in game.enemies:
			enemy["age"] += delta
			enemy["fire"] -= delta
			game.enemy_weapons.fire(enemy, enemy["weapon"], game.rng, game.player_pos, delta)
		game._update_enemy_bullets(delta)
		game._update_enemy_lasers(delta)
		game.elapsed += delta
		if step in [24, 120, 240, 360]:
			game.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://visual-reports/enemy-weapons/patterns-%03d.png" % step)
	game.queue_free()
	await process_frame
	quit()
