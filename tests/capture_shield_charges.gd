extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_encounter_preview()
	game.player_invulnerable = 0.0
	game.player_pos = Vector2(360, 880)
	game.shields.reset(game.ship_definition.shields, game.player_pos)
	game.aura_energy = 60.0
	await save(game, "one-charge")
	game.pickups.append({"pos": game.player_pos, "vel": Vector2.ZERO, "life": 1.0, "aura": 60.0})
	game._update_pickups(0.0)
	game.shields.advance(0.12, game.player_pos, false)
	await save(game, "collected-two-charges")
	game.mouse_aura = true
	game._update_player(0.0)
	game.shields.advance(0.5, game.player_pos, false)
	await save(game, "activated-one-remaining")
	game.queue_free()
	await process_frame
	quit()

func save(game, label: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://visual-reports/shield-charges")
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://visual-reports/shield-charges/%s.png" % label)
	print("Shield charge capture: " + label)
