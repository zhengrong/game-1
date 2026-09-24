extends SceneTree

class Gallery extends Node2D:
	const Visual = preload("res://combat/enemy_bullet_visual.gd")
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 1280), Color("09121d"))
		draw_string(ThemeDB.fallback_font, Vector2(35, 55), "ENEMY WEAPON SIGNATURES", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		var names := ["SCOUT / aimed capsules", "SPINNER / radial plasma", "HEAVY / dart spread", "BOSS / fast lances", "MIRV / splitting missile"]
		var styles := ["capsule", "orb", "dart", "lance", "missile"]
		var colors := [Color(1, 0.11, 0.025), Color(1, 0.16, 0.04), Color(1, 0.45, 0.04), Color(1, 0.06, 0.35), Color(1, 0.1, 0.5)]
		for row in range(5):
			var y := 115.0 + row * 220.0
			draw_string(ThemeDB.fallback_font, Vector2(35, y), names[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color(0.7, 0.85, 1))
			for i in range(7):
				var angle := PI * 0.5 + (i - 3) * 0.22
				var pos := Vector2(390, y + 12) + Vector2.from_angle(angle) * 125
				Visual.draw(self, {"pos": pos, "vel": Vector2.from_angle(angle) * 300, "radius": 7.0, "color": colors[row], "age": 1.0, "style": styles[row]})
			draw_set_transform(Vector2(90, y + 100), 0, Vector2.ONE * 1.5)
			Visual.draw(self, {"pos": Vector2.ZERO, "vel": Vector2.DOWN * 300, "radius": 8.0, "color": colors[row], "age": 1.0, "style": styles[row]})
			draw_set_transform(Vector2.ZERO)
			draw_line(Vector2(35, y + 175), Vector2(680, y + 175), Color(0.1, 0.2, 0.3), 1)

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Gallery.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://visual-reports/enemy-weapons")
	viewport.get_texture().get_image().save_png("res://visual-reports/enemy-weapons/signatures.png")
	quit()
