extends SceneTree
## A deterministic 120 Hz sequence at the reference's portrait dimensions.
## This validates our motion; it is not an automated reference similarity score.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(589, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.use_hdr_2d = true
	root.add_child(viewport)
	var game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.start_encounter_preview()
	game.rng.seed = 42
	game.player_pos = Vector2(294.5, 1010)
	game.player_target = game.player_pos
	game.player_invulnerable = 0.0
	var enemy: Dictionary = game.enemies[0]
	enemy["pos"] = Vector2(294.5, 310)
	enemy["shield"] = 0.0
	enemy["hp"] = 10000.0
	enemy["max_hp"] = 10000.0
	game.elapsed = 4.0
	game.shake = 0.0
	game.wave_banner = 0.0
	game.particles.clear()
	game._start_player_beam()
	var directory := "res://visual-reports/beam-cycle"
	DirAccess.make_dir_recursive_absolute(directory)
	var samples: Array[Dictionary] = []
	for frame in range(50):
		if frame > 0:
			game._update_player_weapon_cycle(1.0 / 120.0)
			game._update_particles(1.0 / 120.0)
			game._update_shockwaves(1.0 / 120.0)
		game._update_beam_visual(0.0)
		game.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var path := "%s/frame-%03d.png" % [directory, frame]
		if image.save_png(path) != OK:
			push_error("Failed to save " + path)
			quit(1)
			return
		samples.append({"frame": frame, "seconds": frame / 120.0,
			"phase": game.BeamVisual.envelope(game.beam_age, game.beam_visible_timer).phase,
			"beam_remaining": game.beam_visible_timer, "damage_ticks": game.beam_damage_sequence})
	var manifest := FileAccess.open(directory + "/frames.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(samples, "\t"))
	for player: AudioStreamPlayer in game.sound_pool:
		player.stop()
	viewport.queue_free()
	await process_frame
	print("Captured 50 fixed-timestep frames to " + directory)
	quit()
