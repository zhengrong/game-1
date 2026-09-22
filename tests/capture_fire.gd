extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var reference_mode := "--reference" in OS.get_cmdline_user_args()
	var reference: Dictionary = {}
	var reference_start := 56
	var times: Array[float] = []
	var directory := "res://visual-reports/fire"
	if reference_mode:
		reference = JSON.parse_string(FileAccess.get_file_as_string("res://visual-reports/phoenix-reference/frames.json"))
		var onset: float = reference["frames"][reference_start]["seconds"]
		for sample in reference["frames"].slice(reference_start):
			times.append(float(sample["seconds"]) - onset)
		directory = "res://visual-reports/fire-reference"
	else:
		for frame in range(181):
			times.append(frame / 60.0)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(589, 1280) if reference_mode else Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.use_hdr_2d = true
	root.add_child(viewport)
	var game = load("res://main.tscn").instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.twin_shots = reference_mode
	game.rng.seed = 42
	game._create_stars()
	game.start_encounter_preview()
	game.player_pos = Vector2(360, 1020)
	game.player_invulnerable = 0.0
	var enemy: Dictionary = game.enemies[0]
	enemy["pos"] = Vector2(250, 350)
	enemy["anchor_x"] = 250.0
	enemy["vel"] = Vector2.ZERO
	enemy["shield"] = 0.0
	enemy["hp"] = enemy["max_hp"] * 0.3
	enemy["turrets"][0]["hp"] = 0.0
	enemy["turrets"][0]["state"] = "destroyed"
	enemy["turrets"][1]["timer"] = 999.0
	if reference_mode:
		enemy["pos"] = Vector2(263, 567)
		enemy["anchor_x"] = 263.0
		game.player_pos = Vector2(294.5, 1020)
	game.beam_visible_timer = 0.0
	game.elapsed = 4.0
	game.flash = 0.0
	game.shake = 0.0
	game._spawn_explosion(Vector2(263, 567) if reference_mode else Vector2(440, 570), Color.ORANGE, 24, 260.0)
	if reference_mode:
		game._spawn_energy_burst(Vector2(263, 567), Color(0.2, 0.85, 1.8), 0.6)
	for i in range(7):
		game.enemy_bullets.append({"pos": Vector2(180 + i * 50, 690), "vel": Vector2.DOWN * 180, "radius": 7.0, "color": Color.RED, "grazed": false, "age": 1.0})
	DirAccess.make_dir_recursive_absolute(directory)
	var samples: Array[Dictionary] = []
	for frame in range(times.size()):
		if not reference_mode and frame == 90:
			game.enemies.clear()
		if frame > 0:
			var delta := times[frame] - times[frame - 1]
			game._update_enemies(delta)
			game._update_particles(delta)
			if reference_mode:
				game._update_player_bullets(delta)
			game.elapsed += delta
		if reference_mode and frame in [0, 17, 34, 51]:
			game._spawn_twin_shots()
		if reference_mode and frame == 18:
			# Reconstruct the visible secondary overlap, not its unknown game mechanic.
			game._spawn_energy_burst(Vector2(350, 680), Color(1.5, 0.18, 0.9), 1.0)
		game.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := directory + "/frame-%03d.png" % frame
		if viewport.get_texture().get_image().save_png(path) != OK:
			push_error("Capture failed: " + path)
			quit(1)
			return
		samples.append({"frame": frame, "seconds": times[frame],
			"reference_frame": reference_start + frame if reference_mode else -1,
			"file": "frame-%03d.png" % frame, "particles": game.particles.size()})
	var manifest := FileAccess.open(directory + "/frames.json", FileAccess.WRITE)
	if manifest == null:
		push_error("Could not write fire capture manifest")
		quit(1)
		return
	manifest.store_string(JSON.stringify({"fps": 0 if reference_mode else 60, "width": viewport.size.x, "height": viewport.size.y,
		"reference_start": reference_start if reference_mode else -1,
		"seed": 42, "burn_source_removed_at_frame": -1 if reference_mode else 90, "frames": samples}, "\t"))
	manifest.close()
	for player: AudioStreamPlayer in game.sound_pool:
		player.stop()
	viewport.queue_free()
	await process_frame
	print("Captured %d consecutive fire frames to %s with frames.json" % [times.size(), directory])
	quit()
