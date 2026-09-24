extends RefCounted
## Presentation snapshot: no reference to the game or mutable combat services.
const GameState = preload("res://systems/game_types.gd").GameState
var MAX_AURA: float = 100.0
var MAX_NOVA: float = 100.0
const TAU_F = TAU
var state: GameState = GameState.TITLE
var screen_size := Vector2(720.0, 1280.0)
var font: Font
var paused := false
var twin_shots := false
var score := 0
var encounter_preview := false
var wave := 0
var stage_count := 4
var stage_title := ""
var elapsed := 0.0
var player_hp := 3
var player_max_hp := 3
var enemies: Array[Dictionary] = []
var aura_energy := MAX_AURA
var aura_active := false
var nova_energy := 0.0
var aura_exhausted := false
var wave_banner := 0.0
var graze_count := 0
var aura_label := "PULSE"
var zen_label := "NOVA"
var zen_fill := 0.0
var zen_active := false
var zen_status := ""

func _draw_ui(canvas: Node2D) -> void:
	match state:
		GameState.TITLE:
			_draw_title(canvas)
		GameState.PLAYING:
			_draw_hud(canvas)
			if paused:
				_draw_pause(canvas)
		GameState.GAME_OVER:
			_draw_hud(canvas)
			_draw_end_panel(canvas, false)
		GameState.VICTORY:
			_draw_hud(canvas)
			_draw_end_panel(canvas, true)


func _draw_title(canvas: Node2D) -> void:
	var center := Vector2(screen_size.x * 0.5, screen_size.y * 0.36)
	for i in range(5, 0, -1):
		canvas.draw_arc(center, 72.0 + float(i) * 18.0 + sin(Time.get_ticks_msec() * 0.001 + i) * 6.0, -1.1, 4.2, 56, Color(0.15, 0.65, 1.0, 0.05 * i), 3.0)
	_draw_centered(canvas, "STARFALL", center.y - 14.0, 58, Color(0.78, 0.95, 1.0))
	_draw_centered(canvas, "PROTOCOL", center.y + 40.0, 30, Color(0.24, 0.82, 1.0))
	_draw_centered(canvas, "A ONE-MISSION BULLET HELL", center.y + 84.0, 15, Color(0.62, 0.7, 0.87))
	var panel := Rect2(Vector2(screen_size.x * 0.13, screen_size.y * 0.57), Vector2(screen_size.x * 0.74, 190.0))
	canvas.draw_rect(panel, Color(0.025, 0.04, 0.11, 0.86), true)
	canvas.draw_rect(panel, Color(0.2, 0.68, 1.0, 0.36), false, 2.0)
	_draw_centered(canvas, "DRAG / WASD / LEFT STICK TO MOVE", panel.position.y + 43.0, 17, Color(0.82, 0.9, 1.0))
	_draw_centered(canvas, ("SECOND FINGER: " + aura_label + "  /  SPACE" if zen_label != "NOVA" else "HOLD PULSE  •  SPACE / LB"), panel.position.y + 79.0, 16, Color(0.28, 0.9, 1.0))
	_draw_centered(canvas, ("COLLECT ENERGY · ONE CIRCLE PER USE" if zen_label.is_empty() else ("LIFT FINGER: PERSONAL SHIELD" if zen_label == "SHIELD" else "TRIGGER NOVA  •  E / RB")), panel.position.y + 112.0, 16, Color(1.0, 0.67, 0.24))
	_draw_centered(canvas, "AUTO FIRE · V: SWITCH WEAPON", panel.position.y + 153.0, 15, Color(0.58, 0.65, 0.79))
	if not zen_label.is_empty():
		_draw_text(canvas, "GUARDIAN · F3", Vector2(screen_size.x * 0.12, screen_size.y * 0.96), 16, Color(0.5, 0.75, 1.0))
		_draw_text(canvas, "PHALANX · F4", Vector2(screen_size.x * 0.61, screen_size.y * 0.96), 16, Color(1.0, 0.45, 0.85))
	var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.004) * 0.2
	_draw_centered(canvas, "F2  /  HEAVY ENCOUNTER", screen_size.y * 0.89, 16, Color(0.65, 0.8, 0.92))
	_draw_centered(canvas, "CLICK OR TAP TO LAUNCH", screen_size.y * 0.83, 22, Color(0.76, 0.94, 1.0, pulse))


func _draw_hud(canvas: Node2D) -> void:
	_draw_centered(canvas, "TWIN SHOTS · V" if twin_shots else "LANCE · V", screen_size.y - 32, 12, Color(0.45, 0.72, 0.9))
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(screen_size.x, 86.0)), Color(0.006, 0.012, 0.04, 0.72))
	_draw_text(canvas, "SCORE", Vector2(22.0, 27.0), 13, Color(0.42, 0.56, 0.75))
	_draw_text(canvas, _format_score(score), Vector2(22.0, 57.0), 25, Color(0.9, 0.97, 1.0))
	_draw_centered(canvas, "TURRET TRIAL" if encounter_preview else "WAVE %d/%d" % [mini(wave, stage_count), stage_count], 27.0, 16, Color(0.52, 0.82, 1.0))
	_draw_centered(canvas, "%02d:%05.2f" % [int(elapsed / 60.0), fmod(elapsed, 60.0)], 52.0, 17, Color(0.85, 0.93, 1.0))
	for step in range(stage_count):
		var c := Color(0.15, 0.8, 1.0) if step < wave else Color(0.16, 0.21, 0.3)
		canvas.draw_line(Vector2(screen_size.x * 0.5 - 42 + step * 22, 70), Vector2(screen_size.x * 0.5 - 26 + step * 22, 70), c, 3.0)

	_draw_text(canvas, "HULL", Vector2(screen_size.x - 105.0, 27.0), 13, Color(0.42, 0.56, 0.75))
	for i in range(player_max_hp):
		var c := Color(0.25, 0.9, 1.0) if i < player_hp else Color(0.16, 0.2, 0.29)
		canvas.draw_circle(Vector2(screen_size.x - 91.0 + i * minf(28.0, 84.0 / maxf(1.0, player_max_hp)), 55.0), 8.0, c)

	if not enemies.is_empty():
		for enemy in enemies:
			if enemy["kind"] == "boss":
				var bar_rect := Rect2(Vector2(80.0, 101.0), Vector2(screen_size.x - 160.0, 12.0))
				canvas.draw_rect(bar_rect, Color(0.11, 0.03, 0.13, 0.8))
				canvas.draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * maxf(0.0, enemy["hp"] / enemy["max_hp"]), bar_rect.size.y)), Color(1.0, 0.17, 0.54))
				_draw_centered(canvas, "DREADNOUGHT", 96.0, 12, Color(1.0, 0.65, 0.82))
				break

	var pause_rect := _pause_button_rect()
	canvas.draw_rect(pause_rect, Color(0.02, 0.05, 0.09, 0.85))
	_draw_text(canvas, "II", pause_rect.position + Vector2(17, 29), 22, Color(0.75, 0.9, 1.0))
	_draw_ability_button(canvas, _aura_button_rect(), aura_label, aura_energy / MAX_AURA, Color(0.15, 0.76, 1.0), aura_active)
	if not zen_label.is_empty():
		_draw_ability_button(canvas, _nova_button_rect(), zen_label, zen_fill, Color(1.0, 0.52, 0.14), zen_active)
	if not zen_status.is_empty():
		_draw_text(canvas, zen_status, Vector2(screen_size.x - 190, screen_size.y - 135), 12, Color(0.5, 0.8, 1.0))
	if aura_exhausted:
		_draw_text(canvas, "RECHARGING", Vector2(20, screen_size.y - 135), 12, Color(0.4, 0.75, 0.9))
	if encounter_preview:
		_draw_centered(canvas, "BREAK SHIELD · AIM AT SIDE TURRETS", 119.0, 14, Color(0.55, 0.85, 1.0))
		_draw_centered(canvas, ("PULSE CLEARS BULLETS · DODGE LASERS" if aura_label == "PULSE" else ("TAP SHIELD · ONE CIRCLE PER USE" if zen_label.is_empty() else "TAP " + aura_label + " · RELEASE TO SHIELD")), 145.0, 12, Color(0.85, 0.65, 0.42))
	if wave_banner > 0.0:
		var title := "FINAL WAVE" if wave == stage_count else "WAVE %d" % wave
		var subtitle: String = stage_title
		var alpha := minf(1.0, wave_banner * 1.4)
		_draw_centered(canvas, title, screen_size.y * 0.19, 28, Color(0.82, 0.95, 1.0, alpha))
		_draw_centered(canvas, subtitle, screen_size.y * 0.19 + 28.0, 13, Color(0.34, 0.78, 1.0, alpha))


func _draw_ability_button(canvas: Node2D, rect: Rect2, label: String, fill: float, color: Color, active: bool) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.5
	canvas.draw_circle(center, radius, Color(0.015, 0.03, 0.08, 0.78))
	canvas.draw_arc(center, radius - 4.0, -PI * 0.5, -PI * 0.5 + TAU_F * clampf(fill, 0.0, 1.0), 40, color, 6.0)
	if active:
		canvas.draw_circle(center, radius - 10.0, Color(color.r, color.g, color.b, 0.16))
	var size := 15
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, center + Vector2(-text_width * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.88, 0.96, 1.0))


func _draw_pause(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.01, 0.04, 0.76))
	_draw_centered(canvas, "PAUSED", screen_size.y * 0.46, 44, Color(0.78, 0.94, 1.0))
	_draw_centered(canvas, "Press Esc or tap to resume", screen_size.y * 0.51, 17, Color(0.55, 0.68, 0.86))


func _draw_end_panel(canvas: Node2D, victory: bool) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.008, 0.03, 0.7))
	var panel := Rect2(Vector2(screen_size.x * 0.11, screen_size.y * 0.28), Vector2(screen_size.x * 0.78, 420.0))
	canvas.draw_rect(panel, Color(0.02, 0.035, 0.09, 0.96), true)
	canvas.draw_rect(panel, Color(0.24, 0.8, 1.0, 0.45) if victory else Color(1.0, 0.22, 0.38, 0.5), false, 3.0)
	_draw_centered(canvas, "MISSION COMPLETE" if victory else "SHIP LOST", panel.position.y + 76.0, 34, Color(0.64, 0.94, 1.0) if victory else Color(1.0, 0.5, 0.58))
	_draw_centered(canvas, _format_score(score), panel.position.y + 144.0, 44, Color.WHITE)
	_draw_centered(canvas, "FINAL SCORE", panel.position.y + 173.0, 13, Color(0.45, 0.56, 0.75))
	_draw_centered(canvas, "GRAZES  %03d" % graze_count, panel.position.y + 226.0, 18, Color(0.7, 0.79, 0.92))
	_draw_centered(canvas, "TIME  %02d:%02d" % [int(elapsed / 60.0), int(elapsed) % 60], panel.position.y + 261.0, 18, Color(0.7, 0.79, 0.92))
	_draw_centered(canvas, "CLICK / TAP / ENTER TO RETRY", panel.position.y + 351.0, 17, Color(0.35, 0.84, 1.0))


func _draw_text(canvas: Node2D, text: String, pos: Vector2, size: int, color: Color) -> void:
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_centered(canvas: Node2D, text: String, y: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2((screen_size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _format_score(value: int) -> String:
	var raw := str(maxi(value, 0))
	var output := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			output = "," + output
		output = raw.substr(i, 1) + output
		count += 1
	return output


func _aura_button_rect() -> Rect2:
	return Rect2(Vector2(24.0, screen_size.y - 122.0), Vector2(92.0, 92.0))


func _nova_button_rect() -> Rect2:
	return Rect2(Vector2(screen_size.x - 116.0, screen_size.y - 122.0), Vector2(92.0, 92.0))


func _pause_button_rect() -> Rect2:
	return Rect2(Vector2(screen_size.x - 62.0, 96.0), Vector2(44.0, 44.0))



