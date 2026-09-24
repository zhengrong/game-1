extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(589, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.use_hdr_2d = true
	root.add_child(viewport)
	var game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.start_game()
	game.enemies.clear()
	game.player_invulnerable = 0.0
	game.player_pos = Vector2(342, 825)
	DirAccess.make_dir_recursive_absolute("res://visual-reports/player-shots")
	for age in [0.025, 0.05, 0.083333, 0.18, 0.32]:
		game.player_bullets.clear()
		game._spawn_twin_shots()
		game._update_player_bullets(age)
		game.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://visual-reports/player-shots/age-%03d.png" % int(age * 1000))
	game.queue_free()
	await process_frame
	quit()
