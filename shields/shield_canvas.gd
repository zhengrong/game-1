extends Node2D
## One shader quad per shield; draw data never changes simulation state.
const SURFACE = preload("res://shields/shield_surface.gdshader")
const QUAD = preload("res://combat/flare_texture.tres")
const Config = preload("res://shields/shield_config.gd")
var game: Node2D

func _ready() -> void:
	var surface := ShaderMaterial.new()
	surface.shader = SURFACE
	surface.set_shader_parameter("hdr_canvas", get_viewport().use_hdr_2d)
	material = surface

func _draw() -> void:
	if game == null or game.state == game.GameState.TITLE:
		return
	var system = game.shields
	var dim := 0.25 if game.paused else 1.0
	if system.config.personal_enabled and system.protected():
		var alpha: float = 1.0 if system.personal > 0.0 else system.fade / maxf(0.001, system.config.personal_fade)
		_surface(system.position, system.config.personal_radius, Color(0, system.visual_time, 1, alpha * dim))
	for field in system.fields:
		var mobile: bool = field["kind"] == Config.Aura.PHALANX
		var center: Vector2 = system.position if mobile else field["center"]
		var duration: float = system.config.phalanx_fade if mobile else system.config.barrier_fade
		var alpha: float = clampf(field["fade"] / maxf(0.001, duration), 0.0, 1.0) if field["fading"] else 1.0
		var mode: float = 2.0 + system.config.phalanx_half_angle / 180.0 if mobile else 1.0
		_surface(center, field["radius"], Color(mode, field.get("age", 0.0), maxf(0.0, field["strength"] / field["maximum"]), alpha * dim))

func _surface(center: Vector2, radius: float, data: Color) -> void:
	var size := Vector2.ONE * radius * 2.4
	draw_texture_rect(QUAD, Rect2(center - size * 0.5, size), false, data)
