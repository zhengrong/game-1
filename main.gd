extends Node2D

# Starfall Protocol: a self-contained vertical bullet-hell demo.
# Textured ships with procedural combat effects and synthesized audio.

const Missile = preload("res://combat/missile.gd")
const EnvironmentVisual = preload("res://combat/environment_visual.gd")
const BeamVisual = preload("res://combat/beam_visual.gd")
const HeavyEnemy = preload("res://combat/heavy_enemy.gd")

enum GameState { TITLE, PLAYING, GAME_OVER, VICTORY }

const PLAYER_RADIUS := 11.0
const PLAYER_SPEED := 680.0
const PLAYER_SHOT_INTERVAL := 0.066
const PLAYER_BEAM_FIRE_TIME := 0.22
const PLAYER_BEAM_PAUSE_TIME := 0.135
const PLAYER_BEAM_ATTACK_TIME := 0.07
const PLAYFIELD_MARGIN := 30.0
const AURA_RADIUS := 118.0
const MAX_AURA := 100.0
const MAX_NOVA := 100.0
const TAU_F := TAU
# Measured against the 589 px-wide Phoenix 2 reference screenshot, including
# the player's side pods and each enemy's dark outer nacelles.
const PLAYER_VISUAL_SIZE := Vector2(148.0, 154.0)
const SCOUT_VISUAL_SIZE := Vector2(134.0, 172.0)
const SPINNER_VISUAL_SIZE := Vector2(140.0, 180.0)
const HEAVY_VISUAL_SIZE := Vector2(174.0, 190.0)
const PLAYER_NOSE_OFFSET := Vector2(0.0, -72.0)
const PLAYER_ENGINE_Y := 65.0
const PLAYER_ENGINE_SPREAD := 17.0
const PLAYER_SHIP_TEXTURE: Texture2D = preload("res://assets/ships/player_interceptor_hd.png")
const SCOUT_TEXTURE: Texture2D = preload("res://assets/ships/enemy_scout.png")
const HEAVY_TEXTURE: Texture2D = preload("res://assets/ships/enemy_heavy.png")
const BOSS_TEXTURE: Texture2D = preload("res://assets/ships/enemy_boss.png")
const FIREBALL_TEXTURE: Texture2D = preload("res://assets/effects/fireball.png")
const SMOKE_TEXTURE: Texture2D = preload("res://assets/effects/smoke.png")
const BATTLEFIELD_BACKGROUND: Texture2D = preload("res://assets/backgrounds/amber_megastructure_hd.png")

var state: GameState = GameState.TITLE
var screen_size := Vector2(720.0, 1280.0)
var rng := RandomNumberGenerator.new()
var font: Font

var stars: Array[Dictionary] = []
var background_panels: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var player_bullets: Array[Dictionary] = []
var enemy_bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []

var player_pos := Vector2.ZERO
var player_target := Vector2.ZERO
var player_hp := 3
var player_invulnerable := 0.0
var shot_timer := 0.0
var aura_energy := MAX_AURA
var aura_active := false
var nova_energy := 0.0
var score := 0
var combo := 1.0
var combo_timer := 0.0
var graze_count := 0

var wave := 0
var wave_spawned := 0
var wave_goal := 0
var spawn_timer := 0.0
var wave_break := 0.0
var wave_banner := 0.0
var elapsed := 0.0
var boss_spawned := false
var mission_complete_timer := 0.0

var pointer_active := false
var pointer_index := -1
var aura_pointer_index := -1
var mouse_aura := false
var encounter_preview := false
var wrecks: Array[Dictionary] = []
var aura_exhausted := false
var paused := false
var flash := 0.0
var shake := 0.0
var muzzle_flash := 0.0
var shot_sequence := 0
var beam_end := Vector2.ZERO
var beam_contact := false
var beam_overcharged := false
var beam_visible_timer := 0.0
var beam_pause_timer := 0.0
var beam_age := 0.0
var beam_damage_sequence := 0
var thruster_timer := 0.0

var sound_pool: Array[AudioStreamPlayer] = []
var sound_cursor := 0
var sounds: Dictionary = {}


func _ready() -> void:
	rng.randomize()
	# Linear filtering preserves the deliberately broad, high-contrast armor
	# features in the gameplay-sized ship art. Mipmaps made these small hulls
	# visibly soft during the Retina-scale comparison pass.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_build_audio()
	if "--encounter" in OS.get_cmdline_user_args():
		start_encounter_preview()
	set_process(true)
	queue_redraw()


func _on_viewport_resized() -> void:
	screen_size = get_viewport_rect().size
	if screen_size.x < 1.0 or screen_size.y < 1.0:
		screen_size = Vector2(720.0, 1280.0)
	if stars.is_empty():
		_create_stars()
	if player_pos == Vector2.ZERO:
		player_pos = Vector2(screen_size.x * 0.5, screen_size.y * 0.79)
		player_target = player_pos


func _create_stars() -> void:
	stars.clear()
	for i in range(92):
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, screen_size.x), rng.randf_range(0.0, screen_size.y)),
			"speed": rng.randf_range(28.0, 170.0),
			"size": rng.randf_range(0.7, 2.5),
			"alpha": rng.randf_range(0.25, 0.9),
		})
	background_panels.clear()
	for i in range(18):
		background_panels.append({
			"pos": Vector2(rng.randf_range(-80.0, screen_size.x + 80.0), rng.randf_range(-100.0, screen_size.y + 100.0)),
			"speed": rng.randf_range(16.0, 46.0),
			"size": Vector2(rng.randf_range(45.0, 150.0), rng.randf_range(70.0, 230.0)),
			"layer": rng.randf_range(0.0, 1.0),
			"notches": rng.randi_range(2, 5),
		})


func start_game() -> void:
	state = GameState.PLAYING
	enemies.clear()
	player_bullets.clear()
	enemy_bullets.clear()
	particles.clear()
	pickups.clear()
	shockwaves.clear()
	wrecks.clear()
	aura_exhausted = false
	encounter_preview = false
	player_pos = Vector2(screen_size.x * 0.5, screen_size.y * 0.79)
	player_target = player_pos
	pointer_active = false
	pointer_index = -1
	aura_pointer_index = -1
	mouse_aura = false
	player_hp = 3
	player_invulnerable = 1.2
	shot_timer = 0.0
	aura_energy = MAX_AURA
	nova_energy = 18.0
	aura_active = false
	score = 0
	combo = 1.0
	combo_timer = 0.0
	graze_count = 0
	wave = 0
	wave_spawned = 0
	wave_goal = 0
	spawn_timer = 0.0
	wave_break = 0.55
	wave_banner = 0.0
	elapsed = 0.0
	boss_spawned = false
	mission_complete_timer = 0.0
	paused = false
	flash = 0.0
	muzzle_flash = 0.0
	shot_sequence = 0
	beam_end = Vector2(player_pos.x, -24.0)
	beam_contact = false
	beam_overcharged = false
	beam_visible_timer = 0.0
	beam_pause_timer = 0.0
	beam_age = 0.0
	beam_damage_sequence = 0
	thruster_timer = 0.0
	play_sound("start")


func _process(delta: float) -> void:
	_update_stars(delta)
	flash = maxf(0.0, flash - delta * 2.6)
	shake = maxf(0.0, shake - delta * 18.0)
	muzzle_flash = maxf(0.0, muzzle_flash - delta)

	if state == GameState.PLAYING and not paused:
		elapsed += delta
		_update_player(delta)
		if state != GameState.PLAYING:
			queue_redraw()
			return
		if not encounter_preview:
			_update_spawner(delta)
		_update_enemies(delta)
		if state != GameState.PLAYING:
			queue_redraw()
			return
		_update_beam_visual(delta)
		_update_player_bullets(delta)
		_update_enemy_bullets(delta)
		if state != GameState.PLAYING:
			queue_redraw()
			return
		_update_pickups(delta)
		_update_particles(delta)
		_update_shockwaves(delta)
		if not encounter_preview:
			_check_wave_complete()
		elif enemies.is_empty():
			state = GameState.VICTORY
	elif state == GameState.VICTORY:
		mission_complete_timer += delta
		_update_particles(delta)
		_update_shockwaves(delta)
	elif state == GameState.GAME_OVER:
		_update_particles(delta)
		_update_shockwaves(delta)

	if not paused:
		_update_wrecks(delta)
	queue_redraw()


func _update_stars(delta: float) -> void:
	var speed_scale := 0.25 if state == GameState.TITLE else 1.0
	for star in stars:
		star["pos"].y += star["speed"] * delta * speed_scale
		if star["pos"].y > screen_size.y + 4.0:
			star["pos"] = Vector2(rng.randf_range(0.0, screen_size.x), -4.0)
	for panel in background_panels:
		panel["pos"] = panel["pos"] + Vector2(0.0, panel["speed"] * delta * speed_scale)
		if panel["pos"].y - panel["size"].y * 0.5 > screen_size.y + 80.0:
			panel["pos"] = Vector2(rng.randf_range(-70.0, screen_size.x + 70.0), -panel["size"].y)


func _update_player(delta: float) -> void:
	player_invulnerable = maxf(0.0, player_invulnerable - delta)
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = move_toward(combo, 1.0, delta * 0.45)

	var keyboard := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() < 0.18:
		joy = Vector2.ZERO
	var movement := keyboard.normalized() if keyboard.length() > 0.0 else joy
	if movement.length() > 0.0:
		pointer_active = false
		player_pos += movement.limit_length(1.0) * PLAYER_SPEED * delta
	elif pointer_active:
		player_target.x = clampf(player_target.x, PLAYFIELD_MARGIN, screen_size.x - PLAYFIELD_MARGIN)
		player_target.y = clampf(player_target.y, screen_size.y * 0.16, screen_size.y - 96.0)
		player_pos = player_pos.lerp(player_target, 1.0 - exp(-delta * 24.0))

	player_pos.x = clampf(player_pos.x, PLAYFIELD_MARGIN, screen_size.x - PLAYFIELD_MARGIN)
	player_pos.y = clampf(player_pos.y, screen_size.y * 0.16, screen_size.y - 96.0)

	if aura_exhausted and aura_energy >= 25.0:
		aura_exhausted = false
	aura_active = not aura_exhausted and (Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or mouse_aura or aura_pointer_index >= 0) and aura_energy > 0.0
	if aura_active:
		aura_energy = maxf(0.0, aura_energy - 31.0 * delta)
		_absorb_bullets()
		if aura_energy <= 0.0:
			aura_exhausted = true
	else:
		aura_energy = minf(MAX_AURA, aura_energy + 6.5 * delta)

	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		_try_nova()

	_update_player_weapon_cycle(delta)
	thruster_timer -= delta
	if thruster_timer <= 0.0:
		_spawn_thruster(player_pos + Vector2(-PLAYER_ENGINE_SPREAD, PLAYER_ENGINE_Y), Color(0.1, 0.78, 1.0), 1.0)
		_spawn_thruster(player_pos + Vector2(PLAYER_ENGINE_SPREAD, PLAYER_ENGINE_Y), Color(0.1, 0.78, 1.0), 1.0)
		thruster_timer = 0.018


func _update_player_weapon_cycle(delta: float) -> void:
	# Consume the elapsed interval across shot and phase boundaries. Damage rate
	# stays consistent at 30/60/120 FPS, including frames spanning recovery.
	var remaining := delta
	while remaining > 0.000001:
		if beam_visible_timer <= 0.000001:
			var pause_step := minf(remaining, beam_pause_timer)
			beam_pause_timer -= pause_step
			remaining -= pause_step
			if beam_pause_timer <= 0.000001:
				_start_player_beam()
		else:
			var step := minf(remaining, minf(beam_visible_timer, shot_timer))
			beam_visible_timer -= step
			beam_age += step
			shot_timer -= step
			remaining -= step
			if beam_visible_timer <= 0.000001:
				beam_visible_timer = 0.0
				beam_contact = false
				beam_pause_timer = PLAYER_BEAM_PAUSE_TIME
			elif shot_timer <= 0.000001:
				_fire_player_weapon()
				shot_timer = PLAYER_SHOT_INTERVAL


func _start_player_beam() -> void:
	shot_sequence += 1
	beam_overcharged = shot_sequence % 4 == 0
	beam_visible_timer = PLAYER_BEAM_FIRE_TIME
	beam_pause_timer = 0.0
	beam_age = 0.0
	shot_timer = PLAYER_SHOT_INTERVAL
	_fire_player_weapon()
	muzzle_flash = PLAYER_BEAM_ATTACK_TIME
	_spawn_muzzle_flash(player_pos + PLAYER_NOSE_OFFSET)


func _fire_player_weapon() -> void:
	beam_damage_sequence += 1
	var hit := _query_beam_hit(beam_overcharged)
	var target_index: int = hit["index"]
	if target_index >= 0:
		var target := enemies[target_index]
		var hit_pos := Vector2(player_pos.x, hit["end_y"])
		if target.has("turrets"):
			HeavyEnemy.damage(self, target, 31.0 if beam_overcharged else 17.0, hit_pos, hit["part"])
		else:
			target["hp"] -= 31.0 if beam_overcharged else 17.0
		if not target.has("turrets"):
			target["hit_flash"] = minf(1.0, target["hit_flash"] + (0.72 if beam_overcharged else 0.42))
		if beam_damage_sequence % 2 == 0 or beam_overcharged:
			_spawn_player_impact(hit_pos, Vector2.UP, beam_overcharged)
			if float(target.get("shield", 0.0)) <= 0.0:
				_spawn_sparks(hit_pos, Color(2.0, 0.6, 0.08), 3, 110.0)
		if target["hp"] <= 0.0:
			_destroy_enemy(target_index)


func _query_beam_hit(overcharged: bool) -> Dictionary:
	var result := {"index": -1, "end_y": -24.0, "part": -1}
	var beam_radius := 8.5 if overcharged else 6.5
	var muzzle := player_pos + PLAYER_NOSE_OFFSET
	for i in range(enemies.size()):
		var enemy := enemies[i]
		var surfaces: Array[Dictionary] = []
		if enemy.has("turrets"):
			surfaces = HeavyEnemy.surfaces(enemy)
		else:
			surfaces.append({"pos": enemy["pos"], "radius": enemy["radius"] * 0.72, "part": -1})
		for surface in surfaces:
			var center: Vector2 = surface["pos"]
			var radius: float = surface["radius"]
			var dx := absf(center.x - muzzle.x)
			if dx > radius + beam_radius or center.y >= muzzle.y:
				continue
			var end_y := minf(muzzle.y - 1.0, center.y + sqrt(maxf(0.0, radius * radius - minf(dx, radius) * minf(dx, radius))))
			if end_y > result["end_y"]:
				result = {"index": i, "end_y": end_y, "part": surface["part"]}
	return result


func _update_beam_visual(_delta: float) -> void:
	if beam_visible_timer <= 0.0:
		beam_contact = false
		return
	var hit := _query_beam_hit(beam_overcharged)
	beam_contact = hit["index"] >= 0
	var desired_end := Vector2(player_pos.x, hit["end_y"])
	# Contact is pinned to the current collision surface; no endpoint lag.
	beam_end = desired_end


func _update_spawner(delta: float) -> void:
	if wave_break > 0.0:
		wave_break -= delta
		if wave_break <= 0.0:
			_begin_next_wave()
		return

	if wave >= 1 and wave <= 3 and wave_spawned < wave_goal:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_wave_enemy()
			wave_spawned += 1
			spawn_timer = [0.0, 0.72, 0.62, 0.52][wave]
	elif wave == 4 and not boss_spawned:
		_spawn_boss()
		boss_spawned = true


func _begin_next_wave() -> void:
	wave += 1
	wave_spawned = 0
	wave_banner = 2.2
	spawn_timer = 0.15
	match wave:
		1:
			wave_goal = 10
		2:
			wave_goal = 13
		3:
			wave_goal = 17
		4:
			wave_goal = 1
		_:
			wave_goal = 0


func _spawn_wave_enemy() -> void:
	var kind := "scout"
	if wave == 2:
		kind = "spinner" if wave_spawned % 3 != 0 else "scout"
	elif wave == 3:
		kind = "heavy" if wave_spawned % 4 == 0 else ("spinner" if wave_spawned % 2 == 0 else "scout")

	var radius := 24.0
	var hp := 55.0
	var value := 650
	var speed := 70.0
	match kind:
		"spinner":
			radius = 29.0
			hp = 92.0
			value = 1050
			speed = 54.0
		"heavy":
			radius = 41.0
			hp = 340.0
			value = 1900
			speed = 38.0

	var lane_count := 5 if wave < 3 else 6
	var lane := wave_spawned % lane_count
	var x := lerpf(75.0, screen_size.x - 75.0, (float(lane) + 0.5) / float(lane_count))
	if wave_spawned % 2 == 1:
		x = screen_size.x - x
	if wave == 3:
		var formation := [0.5, 0.23, 0.77, 0.5]
		x = screen_size.x * float(formation[wave_spawned % 4])
	enemies.append({
		"kind": kind,
		"pos": Vector2(x, -radius - 20.0),
		"vel": Vector2(0.0, speed),
		"hp": hp,
		"max_hp": hp,
		"radius": radius,
		"value": value,
		"age": 0.0,
		"phase": rng.randf_range(0.0, TAU_F),
		"fire": rng.randf_range(0.5, 1.2),
		"anchor_x": x,
		"hit_flash": 0.0,
		"damage_tick": rng.randf_range(0.02, 0.12),
	})
	if kind == "heavy":
		HeavyEnemy.equip(enemies.back())


func _spawn_boss() -> void:
	var hp := 1750.0
	enemies.append({
		"kind": "boss",
		"pos": Vector2(screen_size.x * 0.5, -130.0),
		"vel": Vector2(0.0, 62.0),
		"hp": hp,
		"max_hp": hp,
		"radius": 92.0,
		"value": 25000,
		"age": 0.0,
		"phase": 0.0,
		"fire": 1.25,
		"anchor_x": screen_size.x * 0.5,
		"hit_flash": 0.0,
		"damage_tick": 0.0,
	})
	play_sound("warning")


func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		enemy["age"] += delta
		enemy["fire"] -= delta
		enemy["hit_flash"] = maxf(0.0, enemy["hit_flash"] - delta * 5.8)
		enemy["damage_tick"] -= delta
		var kind: String = enemy["kind"]
		match kind:
			"scout":
				enemy["pos"].y += enemy["vel"].y * delta
				enemy["pos"].x = enemy["anchor_x"] + sin(enemy["age"] * 1.8 + enemy["phase"]) * 52.0
				if enemy["pos"].y > 205.0:
					enemy["vel"].y = move_toward(enemy["vel"].y, 13.0, delta * 45.0)
				if enemy["fire"] <= 0.0:
					_fire_aimed(enemy["pos"], 265.0, Color(1.0, 0.11, 0.025), 6.0)
					enemy["fire"] = rng.randf_range(1.25, 1.8)
			"spinner":
				enemy["pos"].y += enemy["vel"].y * delta
				enemy["pos"].x = enemy["anchor_x"] + sin(enemy["age"] * 1.25 + enemy["phase"]) * 78.0
				if enemy["pos"].y > 270.0:
					enemy["vel"].y = move_toward(enemy["vel"].y, 5.0, delta * 34.0)
				if enemy["fire"] <= 0.0:
					if int(enemy["age"] / 1.65) % 3 == 0:
						enemy_bullets.append(Missile.create(enemy["pos"], player_pos))
					else:
						_fire_radial(enemy["pos"], 9, 180.0, enemy["age"] * 0.75, Color(1.0, 0.075, 0.018), 6.5)
					enemy["fire"] = 1.65
			"heavy":
				var laser: Dictionary = enemy["turrets"][1]
				if laser["state"] not in ["locked", "firing"]:
					enemy["pos"].y += enemy["vel"].y * delta
					enemy["pos"].x = move_toward(enemy["pos"].x, enemy["anchor_x"] + sin(enemy["age"] * 0.75 + enemy["phase"]) * 38.0, delta * 28.0)
				if enemy["pos"].y > 230.0:
					enemy["vel"].y = move_toward(enemy["vel"].y, 2.0, delta * 24.0)
				HeavyEnemy.update(self, enemy, delta)
			"boss":
				_update_boss(enemy, delta)

		var health_ratio: float = enemy["hp"] / enemy["max_hp"]
		if health_ratio < 0.48 and enemy["damage_tick"] <= 0.0:
			var vent_offset := Vector2(rng.randf_range(-enemy["radius"] * 0.55, enemy["radius"] * 0.55), rng.randf_range(-enemy["radius"] * 0.25, enemy["radius"] * 0.55))
			_spawn_damage_fire(enemy["pos"] + vent_offset, 1.35 if kind == "boss" else 0.72)
			enemy["damage_tick"] = rng.randf_range(0.045, 0.12) if kind == "boss" else rng.randf_range(0.12, 0.24)

		if enemy["pos"].y > screen_size.y + 150.0:
			enemies.remove_at(i)


func _update_boss(enemy: Dictionary, delta: float) -> void:
	if enemy["pos"].y < 195.0:
		enemy["pos"].y += enemy["vel"].y * delta
		return
	enemy["pos"].x = screen_size.x * 0.5 + sin(enemy["age"] * 0.55) * screen_size.x * 0.25
	if enemy["fire"] > 0.0:
		return

	var health_ratio: float = enemy["hp"] / enemy["max_hp"]
	var cycle := int(enemy["age"] * 0.75) % 3
	if cycle == 0:
		_fire_radial(enemy["pos"] + Vector2(0.0, 42.0), 18 if health_ratio > 0.45 else 24, 205.0, enemy["age"] * 0.42, Color(1.0, 0.065, 0.015), 7.0)
		enemy["fire"] = 0.82 if health_ratio > 0.45 else 0.58
	elif cycle == 1:
		_fire_fan(enemy["pos"] + Vector2(-52.0, 34.0), 7, 0.13, 285.0, Color(1.0, 0.1, 0.02), 7.0)
		_fire_fan(enemy["pos"] + Vector2(52.0, 34.0), 7, 0.13, 285.0, Color(1.0, 0.1, 0.02), 7.0)
		enemy["fire"] = 1.02
	else:
		for offset in [-58.0, 0.0, 58.0]:
			_fire_aimed(enemy["pos"] + Vector2(offset, 38.0), 340.0, Color(1.0, 0.16, 0.025), 8.0)
		enemy["fire"] = 0.48


func _fire_aimed(origin: Vector2, speed: float, color: Color, radius: float) -> void:
	var direction := origin.direction_to(player_pos)
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	enemy_bullets.append({"pos": origin, "vel": direction * speed, "radius": radius, "color": color, "grazed": false, "age": 0.0})


func _fire_fan(origin: Vector2, count: int, step: float, speed: float, color: Color, radius: float) -> void:
	var base_angle := origin.direction_to(player_pos).angle()
	for i in range(count):
		var angle := base_angle + (float(i) - float(count - 1) * 0.5) * step
		enemy_bullets.append({"pos": origin, "vel": Vector2.from_angle(angle) * speed, "radius": radius, "color": color, "grazed": false, "age": 0.0})


func _fire_radial(origin: Vector2, count: int, speed: float, rotation: float, color: Color, radius: float) -> void:
	for i in range(count):
		var angle := rotation + TAU_F * float(i) / float(count)
		enemy_bullets.append({"pos": origin, "vel": Vector2.from_angle(angle) * speed, "radius": radius, "color": color, "grazed": false, "age": 0.0})


func _update_player_bullets(delta: float) -> void:
	for i in range(player_bullets.size() - 1, -1, -1):
		var bullet := player_bullets[i]
		bullet["pos"] += bullet["vel"] * delta
		bullet["life"] -= delta
		bullet["age"] = float(bullet.get("age", 0.0)) + delta
		var consumed := false
		for j in range(enemies.size() - 1, -1, -1):
			var enemy := enemies[j]
			var hit_radius: float = bullet["radius"] + enemy["radius"] * 0.72
			if bullet["pos"].distance_squared_to(enemy["pos"]) <= hit_radius * hit_radius:
				enemy["hp"] -= bullet["damage"]
				enemy["hit_flash"] = minf(1.0, enemy["hit_flash"] + 0.42)
				_spawn_player_impact(bullet["pos"], bullet["vel"], bullet["overcharged"])
				consumed = true
				if enemy["hp"] <= 0.0:
					_destroy_enemy(j)
				break
		if consumed or bullet["life"] <= 0.0 or bullet["pos"].y < -35.0:
			player_bullets.remove_at(i)


func _destroy_enemy(index: int) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy := enemies[index]
	var kind: String = enemy["kind"]
	if kind in ["heavy", "boss"]:
		wrecks.append({"pos": enemy["pos"], "timer": 0.12, "remaining": 5 if kind == "boss" else 3, "scale": 1.5 if kind == "boss" else 0.8})
	var burst_count := 34 if kind == "boss" else (18 if kind == "heavy" else 11)
	_spawn_explosion(enemy["pos"], _enemy_color(kind), burst_count, enemy["radius"] * 3.0)
	shockwaves.append({"pos": enemy["pos"], "radius": enemy["radius"] * 0.4, "max": enemy["radius"] * 2.7, "life": 0.52, "color": _enemy_color(kind)})
	score += int(float(enemy["value"]) * combo)
	combo = minf(9.9, combo + (0.8 if kind == "boss" else 0.18))
	combo_timer = 3.2
	aura_energy = minf(MAX_AURA, aura_energy + (25.0 if kind == "boss" else 8.0))
	nova_energy = minf(MAX_NOVA, nova_energy + (42.0 if kind == "boss" else 7.5))
	var drop_count := 9 if kind == "boss" else (3 if kind == "heavy" else 1)
	for k in range(drop_count):
		pickups.append({
			"pos": enemy["pos"] + Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(4.0, enemy["radius"]),
			"vel": Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(30.0, 95.0),
			"life": 7.0,
		})
	enemies.remove_at(index)
	shake = 16.0 if kind == "boss" else 5.0
	play_sound("boss_down" if kind == "boss" else "explode")
	if kind == "boss":
		_clear_all_enemy_bullets(true)
		state = GameState.VICTORY
		flash = 1.0
		for k in range(8):
			_spawn_explosion(Vector2(rng.randf_range(100.0, screen_size.x - 100.0), rng.randf_range(90.0, screen_size.y * 0.5)), Color.from_hsv(rng.randf(), 0.65, 1.0), 16, 240.0)


func _update_enemy_bullets(delta: float) -> void:
	for i in range(enemy_bullets.size() - 1, -1, -1):
		var bullet := enemy_bullets[i]
		var previous: Vector2 = bullet["pos"]
		bullet["pos"] += bullet["vel"] * delta
		bullet["age"] += delta
		if Missile.ready_to_split(bullet, player_pos):
			enemy_bullets.append_array(Missile.fragments(bullet))
			_spawn_sparks(bullet["pos"], Color(1.0, 0.2, 0.6), 5, 120.0)
			enemy_bullets.remove_at(i)
			continue
		var dist: float = bullet["pos"].distance_to(player_pos)
		if not bullet["grazed"] and dist < bullet["radius"] + 31.0 and dist > bullet["radius"] + PLAYER_RADIUS:
			bullet["grazed"] = true
			graze_count += 1
			score += int(35.0 * combo)
			combo = minf(9.9, combo + 0.035)
			combo_timer = 2.0
			nova_energy = minf(MAX_NOVA, nova_energy + 1.35)
		var closest := Geometry2D.get_closest_point_to_segment(player_pos, previous, bullet["pos"])
		if player_invulnerable <= 0.0 and closest.distance_to(player_pos) < bullet["radius"] + PLAYER_RADIUS:
			enemy_bullets.remove_at(i)
			_damage_player()
			# Damage clears nearby bullets, invalidating the remaining indices.
			return
		if bullet["pos"].x < -70.0 or bullet["pos"].x > screen_size.x + 70.0 or bullet["pos"].y < -90.0 or bullet["pos"].y > screen_size.y + 90.0:
			enemy_bullets.remove_at(i)


func _damage_player() -> void:
	if player_invulnerable > 0.0 or state != GameState.PLAYING:
		return
	player_hp -= 1
	player_invulnerable = 1.8
	combo = 1.0
	combo_timer = 0.0
	shake = 18.0
	flash = 0.62
	_spawn_explosion(player_pos, Color(0.28, 0.9, 1.0), 24, 230.0)
	_clear_bullets_near(player_pos, 185.0)
	play_sound("hit")
	if player_hp <= 0:
		state = GameState.GAME_OVER
		aura_active = false
		pointer_active = false
		_spawn_explosion(player_pos, Color.WHITE, 42, 380.0)
		shockwaves.append({"pos": player_pos, "radius": 20.0, "max": 340.0, "life": 0.85, "color": Color(0.3, 0.9, 1.0)})


func _absorb_bullets() -> void:
	for i in range(enemy_bullets.size() - 1, -1, -1):
		var bullet := enemy_bullets[i]
		if bullet["pos"].distance_squared_to(player_pos) <= AURA_RADIUS * AURA_RADIUS:
			_spawn_sparks(bullet["pos"], Color(0.2, 0.92, 1.0), 3, 95.0)
			score += int(12.0 * combo)
			nova_energy = minf(MAX_NOVA, nova_energy + 0.55)
			enemy_bullets.remove_at(i)


func _try_nova() -> void:
	if nova_energy < MAX_NOVA or state != GameState.PLAYING:
		return
	nova_energy = 0.0
	flash = 0.9
	shake = 20.0
	shockwaves.append({"pos": player_pos, "radius": 18.0, "max": maxf(screen_size.x, screen_size.y) * 0.88, "life": 0.9, "color": Color(1.0, 0.58, 0.18)})
	_clear_all_enemy_bullets(true)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].has("turrets"):
			var had_shield: bool = enemies[i]["shield"] > 0.0
			HeavyEnemy.damage(self, enemies[i], 240.0, enemies[i]["pos"])
			if not had_shield:
				for part in range(enemies[i]["turrets"].size()):
					HeavyEnemy.damage(self, enemies[i], 240.0, enemies[i]["pos"], part)
		else:
			enemies[i]["hp"] -= 180.0 if enemies[i]["kind"] == "boss" else 240.0
		_spawn_sparks(enemies[i]["pos"], Color(1.0, 0.66, 0.2), 10, 170.0)
		if enemies[i]["hp"] <= 0.0:
			_destroy_enemy(i)
	play_sound("nova")


func _clear_bullets_near(center: Vector2, radius: float) -> void:
	for i in range(enemy_bullets.size() - 1, -1, -1):
		if enemy_bullets[i]["pos"].distance_squared_to(center) < radius * radius:
			enemy_bullets.remove_at(i)


func _clear_all_enemy_bullets(reward: bool) -> void:
	if reward:
		score += enemy_bullets.size() * 20
		for i in range(0, enemy_bullets.size(), 3):
			_spawn_sparks(enemy_bullets[i]["pos"], enemy_bullets[i]["color"], 2, 100.0)
	enemy_bullets.clear()


func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		pickup["life"] -= delta
		var distance: float = pickup["pos"].distance_to(player_pos)
		if distance < 280.0:
			pickup["vel"] = pickup["vel"].lerp(pickup["pos"].direction_to(player_pos) * 660.0, 1.0 - exp(-delta * 7.0))
		else:
			pickup["vel"] = pickup["vel"].lerp(Vector2(0.0, 70.0), 1.0 - exp(-delta * 2.0))
		pickup["pos"] += pickup["vel"] * delta
		if distance < 25.0:
			score += int(180.0 * combo)
			aura_energy = minf(MAX_AURA, aura_energy + 4.0)
			nova_energy = minf(MAX_NOVA, nova_energy + 3.0)
			pickups.remove_at(i)
			continue
		if pickup["life"] <= 0.0 or pickup["pos"].y > screen_size.y + 30.0:
			pickups.remove_at(i)


func _spawn_sparks(origin: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var life := rng.randf_range(0.16, 0.44)
		particles.append({
			"kind": "spark",
			"pos": origin,
			"vel": Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(speed * 0.25, speed),
			"life": life,
			"max_life": life,
			"size": rng.randf_range(1.5, 4.2),
			"growth": -1.2,
			"drag": 0.08,
			"color": color,
		})


func _spawn_muzzle_flash(origin: Vector2) -> void:
	for i in range(6):
		var life := rng.randf_range(0.055, 0.14)
		particles.append({
			"kind": "plasma",
			"pos": origin + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-7.0, 3.0)),
			"vel": Vector2(rng.randf_range(-46.0, 46.0), rng.randf_range(-230.0, -95.0)),
			"life": life,
			"max_life": life,
			"size": rng.randf_range(3.0, 7.5),
			"growth": -28.0,
			"drag": 0.12,
			"color": Color(0.16, 0.82, 2.4),
		})
	_spawn_sparks(origin + Vector2(0.0, -4.0), Color(0.42, 1.25, 2.8), 3, 145.0)


func _spawn_player_impact(origin: Vector2, velocity: Vector2, overcharged: bool) -> void:
	var impact_color := Color(0.28, 0.86, 2.4)
	var spark_count := 9 if overcharged else 5
	_spawn_sparks(origin, impact_color, spark_count, 210.0 if overcharged else 145.0)
	var bloom_life := 0.18 if overcharged else 0.12
	particles.append({
		"kind": "plasma",
		"pos": origin,
		"vel": -velocity.normalized() * 26.0,
		"life": bloom_life,
		"max_life": bloom_life,
		"size": 11.0 if overcharged else 7.0,
		"growth": 24.0,
		"drag": 0.08,
		"color": Color(0.58, 1.35, 3.2),
	})
	shockwaves.append({
		"pos": origin,
		"radius": 2.0,
		"max": 25.0 if overcharged else 16.0,
		"life": 0.19 if overcharged else 0.13,
		"color": impact_color,
	})


func _spawn_thruster(origin: Vector2, color: Color, scale: float) -> void:
	var life := rng.randf_range(0.12, 0.21)
	particles.append({
		"kind": "plasma",
		"pos": origin + Vector2(rng.randf_range(-2.0, 2.0), 0.0),
		"vel": Vector2(rng.randf_range(-35.0, 35.0), rng.randf_range(150.0, 250.0)) * scale,
		"life": life,
		"max_life": life,
		"size": rng.randf_range(3.2, 6.0) * scale,
		"growth": rng.randf_range(3.0, 12.0) * scale,
		"drag": 0.32,
		"color": color,
	})
	if rng.randf() < 0.28:
		var ember_life := rng.randf_range(0.22, 0.45)
		particles.append({
			"kind": "spark",
			"pos": origin,
			"vel": Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(120.0, 290.0)) * scale,
			"life": ember_life,
			"max_life": ember_life,
			"size": rng.randf_range(0.8, 2.0) * scale,
			"growth": -0.5,
			"drag": 0.45,
			"color": Color(0.4, 1.7, 3.4),
		})


func _spawn_damage_fire(origin: Vector2, scale: float) -> void:
	var fire_life := rng.randf_range(0.22, 0.48)
	particles.append({
		"kind": "fire",
		"pos": origin,
		"vel": Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-105.0, -45.0)) * scale,
		"life": fire_life,
		"max_life": fire_life,
		"size": rng.randf_range(7.0, 14.0) * scale,
		"growth": rng.randf_range(7.0, 18.0) * scale,
		"drag": 0.28,
		"color": Color(3.2, 0.68, 0.08),
	})
	if rng.randf() < 0.52:
		var smoke_life := rng.randf_range(0.75, 1.35)
		particles.append({
			"kind": "smoke",
			"pos": origin,
			"vel": Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-75.0, -25.0)) * scale,
			"life": smoke_life,
			"max_life": smoke_life,
			"size": rng.randf_range(9.0, 16.0) * scale,
			"growth": rng.randf_range(14.0, 25.0) * scale,
			"drag": 0.58,
			"color": Color(0.14, 0.12, 0.16),
		})
	_spawn_sparks(origin, Color(2.8, 0.7, 0.1), 1, 120.0 * scale)


func _spawn_explosion(origin: Vector2, color: Color, count: int, speed: float) -> void:
	var explosion_scale := clampf(speed / 180.0, 0.65, 1.8)
	for i in range(count):
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU_F))
		if i % 6 == 0:
			var smoke_life := rng.randf_range(0.8, 1.65)
			particles.append({
				"kind": "smoke", "pos": origin + direction * rng.randf_range(0.0, 14.0),
				"vel": direction * rng.randf_range(speed * 0.04, speed * 0.19) + Vector2(0.0, -22.0),
				"life": smoke_life, "max_life": smoke_life, "size": rng.randf_range(11.0, 24.0) * explosion_scale,
				"growth": rng.randf_range(18.0, 34.0), "drag": 0.36, "color": Color(0.16, 0.12, 0.18),
			})
		elif i % 3 == 0:
			var fire_life := rng.randf_range(0.28, 0.72)
			particles.append({
				"kind": "fire", "pos": origin + direction * rng.randf_range(0.0, 10.0),
				"vel": direction * rng.randf_range(speed * 0.08, speed * 0.38),
				"life": fire_life, "max_life": fire_life, "size": rng.randf_range(10.0, 24.0) * explosion_scale,
				"growth": rng.randf_range(5.0, 18.0), "drag": 0.12, "color": Color(3.6, 0.58, 0.06),
			})
		else:
			var spark_life := rng.randf_range(0.35, 0.95)
			particles.append({
				"kind": "spark", "pos": origin + direction * rng.randf_range(0.0, 12.0),
				"vel": direction * rng.randf_range(speed * 0.18, speed),
				"life": spark_life, "max_life": spark_life, "size": rng.randf_range(1.4, 5.5) * sqrt(explosion_scale),
				"growth": -1.0, "drag": 0.08, "color": color.lightened(0.28),
			})
	# A compact white-hot ignition flash gives the explosion physical punch.
	for i in range(4):
		var core_life := rng.randf_range(0.12, 0.24)
		particles.append({
			"kind": "fire", "pos": origin + Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(0.0, 7.0),
			"vel": Vector2.ZERO, "life": core_life, "max_life": core_life,
			"size": rng.randf_range(16.0, 30.0) * explosion_scale, "growth": 34.0 * explosion_scale, "drag": 0.1, "color": Color(5.0, 2.2, 0.5),
		})


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle := particles[i]
		particle["life"] -= delta
		particle["pos"] += particle["vel"] * delta
		particle["vel"] *= pow(particle["drag"], delta)
		particle["size"] = maxf(0.1, particle["size"] + particle["growth"] * delta)
		if particle["life"] <= 0.0:
			particles.remove_at(i)


func _update_shockwaves(delta: float) -> void:
	for i in range(shockwaves.size() - 1, -1, -1):
		var ring := shockwaves[i]
		ring["life"] -= delta
		ring["radius"] = lerpf(ring["radius"], ring["max"], 1.0 - exp(-delta * 8.0))
		if ring["life"] <= 0.0:
			shockwaves.remove_at(i)


func _check_wave_complete() -> void:
	wave_banner = maxf(0.0, wave_banner - get_process_delta_time())
	if wave >= 1 and wave <= 3 and wave_spawned >= wave_goal and enemies.is_empty() and wave_break <= 0.0:
		wave_break = 1.8
		_clear_all_enemy_bullets(true)
		aura_energy = minf(MAX_AURA, aura_energy + 28.0)
		nova_energy = minf(MAX_NOVA, nova_energy + 18.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		state = GameState.TITLE
		encounter_preview = false
		paused = false
		enemies.clear()
		enemy_bullets.clear()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		start_encounter_preview()
		return
	if event is InputEventJoypadButton and event.pressed:
		if state != GameState.PLAYING and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			_restart_selected_mode()
			return
		if state == GameState.PLAYING and event.button_index == JOY_BUTTON_START:
			paused = not paused
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if state == GameState.PLAYING:
				paused = not paused
				aura_active = false
				mouse_aura = false
			return
		if state != GameState.PLAYING and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			_restart_selected_mode()
			return
		if state == GameState.PLAYING and paused:
			paused = false
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state != GameState.PLAYING:
				if state == GameState.TITLE and event.position.y > screen_size.y * 0.855:
					start_encounter_preview()
				else:
					_restart_selected_mode()
				return
			if paused:
				paused = false
				return
			if _pause_button_rect().has_point(event.position):
				paused = true
				return
			if _aura_button_rect().has_point(event.position):
				mouse_aura = true
			elif _nova_button_rect().has_point(event.position):
				_try_nova()
			else:
				pointer_active = true
				player_target = player_pos
		else:
			mouse_aura = false
			pointer_active = false

	if event is InputEventMouseMotion and pointer_active:
		player_target += event.relative

	if event is InputEventScreenTouch:
		if event.pressed:
			if state != GameState.PLAYING:
				if state == GameState.TITLE and event.position.y > screen_size.y * 0.855:
					start_encounter_preview()
				else:
					_restart_selected_mode()
				return
			if paused:
				paused = false
				return
			if _pause_button_rect().has_point(event.position):
				paused = true
				return
			if _aura_button_rect().has_point(event.position):
				aura_pointer_index = event.index
			elif _nova_button_rect().has_point(event.position):
				_try_nova()
			elif pointer_index < 0:
				pointer_index = event.index
				pointer_active = true
				player_target = player_pos
		else:
			if event.index == pointer_index:
				pointer_index = -1
				pointer_active = false
			if event.index == aura_pointer_index:
				aura_pointer_index = -1

	if event is InputEventScreenDrag and event.index == pointer_index:
		player_target += event.relative


func _draw() -> void:
	var draw_offset := Vector2.ZERO
	if shake > 0.0:
		draw_offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
		draw_set_transform(draw_offset)
	_draw_background()
	_draw_world()
	draw_set_transform(Vector2.ZERO)
	_draw_ui()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.75, 0.94, 1.0, flash * 0.32))


func _draw_background() -> void:
	draw_rect(Rect2(Vector2(-30.0, -30.0), screen_size + Vector2(60.0, 60.0)), Color(0.008, 0.012, 0.045))
	# Preserve the source aspect ratio on both 16:9 desktop previews and tall
	# iPhones. A small overscan leaves room for restrained camera drift.
	var texture_size := BATTLEFIELD_BACKGROUND.get_size()
	var cover_scale := maxf(screen_size.x / texture_size.x, screen_size.y / texture_size.y) * 1.025
	var background_size := texture_size * cover_scale
	var drift := Vector2(sin(elapsed * 0.07) * 6.0, sin(elapsed * 0.045) * 9.0)
	var background_rect := Rect2((screen_size - background_size) * 0.5 + drift, background_size)
	draw_texture_rect(BATTLEFIELD_BACKGROUND, background_rect, false, Color(0.82, 0.86, 0.9, 1.0))
	# Reserve the brightest values for live bullets, impacts, and the player beam.
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.008, 0.015, 0.035, 0.23))
	EnvironmentVisual.draw_layers(self)
	for star in stars:
		var color := Color(0.68, 0.9, 1.0, star["alpha"] * 0.38)
		draw_line(star["pos"], star["pos"] - Vector2(0.0, star["size"] * 3.2), color, maxf(0.7, star["size"] * 0.72))


func _draw_world() -> void:
	for pickup in pickups:
		_draw_glow(pickup["pos"], 8.0, Color(0.35, 1.0, 0.82), 3)
		draw_circle(pickup["pos"], 3.0, Color.WHITE)

	if state == GameState.PLAYING and beam_visible_timer > 0.0:
		_draw_player_beam()

	for enemy in enemies:
		_draw_enemy(enemy)

	for enemy in enemies:
		if enemy.has("turrets") and state == GameState.PLAYING:
			HeavyEnemy.draw_hazards(self, enemy)
	for bullet in enemy_bullets:
		_draw_enemy_bullet(bullet)

	for ring in shockwaves:
		var ring_color: Color = ring["color"]
		ring_color.a = clampf(ring["life"] * 1.5, 0.0, 0.8)
		draw_arc(ring["pos"], ring["radius"], 0.0, TAU_F, 72, ring_color.lightened(0.35), 2.2)
		ring_color.a *= 0.28
		draw_arc(ring["pos"], ring["radius"] * 1.035, 0.0, TAU_F, 72, ring_color, 7.0)

	for particle in particles:
		var color: Color = particle["color"]
		var ratio: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		color.a = ratio
		match particle["kind"]:
			"spark":
				draw_line(particle["pos"], particle["pos"] - particle["vel"].normalized() * particle["size"] * 4.2, Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, ratio), particle["size"])
				draw_circle(particle["pos"], particle["size"] * 0.6, Color(minf(color.r * 1.8, 2.2), minf(color.g * 1.8, 2.2), minf(color.b * 1.8, 2.2), ratio))
			"plasma":
				var fire_size: float = particle["size"]
				var fire_core := Color(minf(color.r * 1.7, 2.25), minf(color.g * 1.7, 2.25), minf(color.b * 1.7, 2.25), ratio)
				draw_circle(particle["pos"], fire_size * 1.75, Color(color.r, color.g * 0.45, color.b * 0.25, ratio * 0.1))
				draw_circle(particle["pos"], fire_size, Color(color.r, color.g, color.b, ratio * 0.58))
				draw_circle(particle["pos"] - particle["vel"].normalized() * fire_size * 0.18, fire_size * 0.42, fire_core)
			"fire":
				var flame_size: float = particle["size"] * 3.4
				var flame_rect := Rect2(particle["pos"] - Vector2.ONE * flame_size * 0.5, Vector2.ONE * flame_size)
				draw_texture_rect(FIREBALL_TEXTURE, flame_rect, false, Color(1.0, 0.82, 0.64, ratio * 0.92))
				draw_circle(particle["pos"], particle["size"] * 0.32, Color(2.2, 1.5, 0.62, ratio * 0.72))
			"smoke":
				var smoke_size: float = particle["size"] * 3.1
				var smoke_rect := Rect2(particle["pos"] - Vector2.ONE * smoke_size * 0.5, Vector2.ONE * smoke_size)
				draw_texture_rect(SMOKE_TEXTURE, smoke_rect, false, Color(0.72, 0.76, 0.84, ratio * 0.52))

	if state == GameState.PLAYING or state == GameState.GAME_OVER:
		_draw_player()


func _draw_enemy_bullet(bullet: Dictionary) -> void:
	if bullet.get("style", "") == "missile":
		Missile.draw_missile(self, bullet)
		return
	if bullet.get("style", "") == "dart":
		var pos: Vector2 = bullet["pos"]
		var direction: Vector2 = bullet["vel"].normalized()
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([pos + direction * 11.0, pos - direction * 7.0 + side * 5.0, pos - direction * 4.0, pos - direction * 7.0 - side * 5.0]), Color(1.8, 0.42, 0.04))
		draw_line(pos - direction * 3.0, pos + direction * 7.0, Color(3.0, 1.8, 0.6), 2.0, true)
		return
	# Phoenix-style hostile shots are glossy directional capsules, not comet trails.
	var pos: Vector2 = bullet["pos"]
	var direction: Vector2 = bullet["vel"].normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var normal := Vector2(-direction.y, direction.x)
	var radius: float = bullet["radius"] * 0.72
	var half_segment := radius * 0.74
	var back := pos - direction * half_segment
	var front := pos + direction * half_segment

	# Restrained soft aura: enough separation from the background without merging patterns.
	var glow_radius := radius * 1.48
	var glow_color := Color(1.0, 0.015, 0.0, 0.065)
	draw_line(back, front, glow_color, glow_radius * 2.0, true)
	draw_circle(back, glow_radius, glow_color, true, -1.0, true)
	draw_circle(front, glow_radius, glow_color, true, -1.0, true)

	# Dark rim, saturated red glass shell, then a narrow orange-hot interior.
	var rim_radius := radius * 1.04
	var rim_color := Color(0.32, 0.004, 0.001, 0.96)
	draw_line(back, front, rim_color, rim_radius * 2.0, true)
	draw_circle(back, rim_radius, rim_color, true, -1.0, true)
	draw_circle(front, rim_radius, rim_color, true, -1.0, true)

	var shell_radius := radius * 0.83
	var shell_color := Color(1.25, 0.025, 0.004, 0.98)
	draw_line(back, front, shell_color, shell_radius * 2.0, true)
	draw_circle(back, shell_radius, shell_color, true, -1.0, true)
	draw_circle(front, shell_radius, shell_color, true, -1.0, true)

	var inner_back := pos - direction * half_segment * 0.38
	var inner_front := pos + direction * half_segment * 0.46
	var inner_radius := radius * 0.47
	var inner_color := Color(1.8, 0.3, 0.018, 0.98)
	draw_line(inner_back, inner_front, inner_color, inner_radius * 2.0, true)
	draw_circle(inner_back, inner_radius, inner_color, true, -1.0, true)
	draw_circle(inner_front, inner_radius, inner_color, true, -1.0, true)

	var highlight_pos := front - direction * radius * 0.32 - normal * radius * 0.18
	draw_circle(highlight_pos, radius * 0.24, Color(2.0, 1.15, 0.34, 0.98), true, -1.0, true)


func _draw_player_beam() -> void:
	BeamVisual.draw_beam(self)


func _draw_player() -> void:
	if player_hp <= 0:
		return
	var invulnerability_pulse := 0.0
	if player_invulnerable > 0.0:
		invulnerability_pulse = 0.5 + sin(elapsed * 11.0) * 0.5
		var shield_radius := 82.0 + invulnerability_pulse * 4.0
		draw_circle(player_pos, shield_radius, Color(0.04, 0.58, 1.8, 0.035 + invulnerability_pulse * 0.018))
		draw_arc(player_pos, shield_radius, -elapsed * 2.1, -elapsed * 2.1 + PI * 1.35, 42, Color(0.25, 1.05, 2.5, 0.34 + invulnerability_pulse * 0.2), 1.8, true)
		draw_arc(player_pos, shield_radius - 4.0, elapsed * 1.7, elapsed * 1.7 + PI * 0.82, 30, Color(0.72, 1.55, 2.8, 0.2 + invulnerability_pulse * 0.16), 1.1, true)
	if aura_active:
		var pulse := 1.0 + sin(elapsed * 7.0) * 0.04
		draw_circle(player_pos, AURA_RADIUS * pulse, Color(0.04, 0.5, 1.2, 0.04))
		draw_arc(player_pos, AURA_RADIUS * pulse, -elapsed * 1.8, TAU_F - elapsed * 1.8, 64, Color(0.15, 0.9, 1.65, 0.82), 3.0)
		draw_arc(player_pos, AURA_RADIUS * 0.88, elapsed * 2.3, TAU_F + elapsed * 2.3, 48, Color(0.7, 1.4, 1.8, 0.34), 2.0)
		for spoke in range(6):
			var spoke_angle := elapsed * 0.65 + TAU_F * float(spoke) / 6.0
			var spoke_dir := Vector2.from_angle(spoke_angle)
			draw_line(player_pos + spoke_dir * AURA_RADIUS * 0.91, player_pos + spoke_dir * AURA_RADIUS, Color(0.25, 1.0, 1.8, 0.55), 2.0)

	_draw_glow(player_pos + Vector2(0.0, 3.0), 22.0, Color(0.06, 0.5, 1.15), 2)
	var engine_pulse := 1.0 + sin(elapsed * 42.0) * 0.18
	for engine_x in [-PLAYER_ENGINE_SPREAD, PLAYER_ENGINE_SPREAD]:
		draw_circle(player_pos + Vector2(engine_x, PLAYER_ENGINE_Y + 2.0), 8.5 * engine_pulse, Color(0.04, 0.55, 1.7, 0.18))
		draw_circle(player_pos + Vector2(engine_x, PLAYER_ENGINE_Y), 3.1 * engine_pulse, Color(1.3, 1.9, 2.0))
	var player_rect := Rect2(player_pos - PLAYER_VISUAL_SIZE * 0.5, PLAYER_VISUAL_SIZE)
	var ship_modulate := Color(1.0 + invulnerability_pulse * 0.08, 1.0 + invulnerability_pulse * 0.16, 1.0 + invulnerability_pulse * 0.28)
	draw_texture_rect(PLAYER_SHIP_TEXTURE, player_rect, false, ship_modulate)
	draw_circle(player_pos, PLAYER_RADIUS, Color(0.02, 0.12, 0.18, 0.9))
	draw_arc(player_pos, PLAYER_RADIUS, 0.0, TAU, 24, Color(0.4, 1.3, 1.8), 1.2, true)
	# Re-light the reactor and weapon ports after the textured hull is drawn.
	_draw_glow(player_pos + Vector2(0.0, 1.0), 5.0, Color(1.6, 0.65, 0.06), 2)
	draw_circle(player_pos + Vector2(0.0, 1.0), 2.4, Color(2.0, 1.15, 0.3))
	if muzzle_flash > 0.0:
		var flash_strength := muzzle_flash / PLAYER_BEAM_ATTACK_TIME
		var emitter := player_pos + PLAYER_NOSE_OFFSET
		var flare_tip := emitter + Vector2(0.0, -27.0 * flash_strength)
		var flare_wing := 13.0 * flash_strength
		draw_circle(emitter, 19.0 * flash_strength, Color(0.0, 0.48, 2.8, flash_strength * 0.1))
		draw_colored_polygon(PackedVector2Array([
			flare_tip,
			emitter + Vector2(flare_wing, 7.0),
			emitter + Vector2(0.0, 3.0),
			emitter + Vector2(-flare_wing, 7.0),
		]), Color(0.12, 0.78, 3.2, flash_strength * 0.48))
		for gun_x in [-17.0, 17.0]:
			var port := player_pos + Vector2(gun_x, -57.0)
			draw_line(port, emitter, Color(0.22, 1.0, 3.1, flash_strength * 0.62), 2.2, true)
		draw_circle(emitter, 6.5 * flash_strength, Color(0.36, 1.25, 3.8, flash_strength * 0.75))
		draw_circle(emitter, 2.5 * flash_strength, Color(3.4, 4.4, 4.8, flash_strength))
		draw_arc(emitter, 12.0 + (1.0 - flash_strength) * 10.0, -2.8, -0.34, 18, Color(0.32, 1.0, 3.0, flash_strength * 0.62), 1.4, true)


func _draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind: String = enemy["kind"]
	var color := _enemy_color(kind)
	var radius: float = enemy["radius"]
	_draw_glow(pos, radius * 0.55, color * 0.9, 2)
	var hit_light: float = clampf(enemy["hit_flash"], 0.0, 1.0)
	var hull_modulate := Color(1.0 + hit_light * 1.15, 1.0 + hit_light * 1.48, 1.0 + hit_light * 1.85)
	match kind:
		"scout":
			_draw_enemy_engines(pos, 31.0, 1.32, color)
			draw_texture_rect(SCOUT_TEXTURE, Rect2(pos - SCOUT_VISUAL_SIZE * 0.5, SCOUT_VISUAL_SIZE), false, hull_modulate)
		"spinner":
			_draw_enemy_engines(pos, 34.0, 1.42, color)
			var spinner_modulate := hull_modulate * Color(1.08, 0.62, 1.28)
			draw_texture_rect(SCOUT_TEXTURE, Rect2(pos - SPINNER_VISUAL_SIZE * 0.5, SPINNER_VISUAL_SIZE), false, spinner_modulate)
			draw_arc(pos, radius * 1.13, enemy["age"] * 1.8, enemy["age"] * 1.8 + PI * 1.35, 32, Color(1.2, 0.3, 2.6, 0.72), 2.0)
			draw_arc(pos, radius * 1.25, -enemy["age"] * 1.15, -enemy["age"] * 1.15 + PI * 0.92, 24, Color(0.7, 0.2, 2.2, 0.42), 1.2)
		"heavy":
			_draw_enemy_engines(pos, 46.0, 1.8, color)
			draw_texture_rect(HEAVY_TEXTURE, Rect2(pos - HEAVY_VISUAL_SIZE * 0.5, HEAVY_VISUAL_SIZE), false, hull_modulate)
			_draw_glow(pos + Vector2(0.0, 7.0), 7.0, Color(3.0, 1.0, 0.08), 3)
		"boss":
			_draw_boss(pos, enemy)
	if enemy.has("turrets"):
		HeavyEnemy.draw_components(self, enemy)
	_draw_enemy_health(enemy)


func _draw_enemy_engines(pos: Vector2, spread: float, scale: float, color: Color) -> void:
	var pulse := 1.0 + sin(elapsed * 31.0 + pos.x * 0.01) * 0.2
	for side in [-1.0, 1.0]:
		var engine_pos := pos + Vector2(spread * 0.5 * side, -spread * 0.75)
		draw_circle(engine_pos, 7.5 * scale * pulse, Color(color.r * 1.4, color.g * 0.5, color.b * 0.45, 0.12))
		draw_circle(engine_pos, 2.6 * scale * pulse, Color(3.8, 0.7, 0.32))


func _draw_boss(pos: Vector2, enemy: Dictionary) -> void:
	var hit_light: float = clampf(enemy["hit_flash"], 0.0, 1.0)
	var boss_modulate := Color(1.0 + hit_light * 0.95, 1.0 + hit_light * 1.22, 1.0 + hit_light * 1.52)
	_draw_enemy_engines(pos + Vector2(0.0, -23.0), 122.0, 2.1, _enemy_color("boss"))
	draw_texture_rect(BOSS_TEXTURE, Rect2(pos - Vector2(185.0, 123.0), Vector2(370.0, 247.0)), false, boss_modulate)
	var core_size: float = 25.0 + sin(enemy["age"] * 5.0) * 4.0
	_draw_glow(pos + Vector2(0.0, -5.0), core_size * 1.2, Color(2.6, 0.12, 1.2), 4)
	draw_circle(pos + Vector2(0.0, -5.0), core_size * 0.32, Color(3.8, 0.36, 1.6, 0.72))


func _draw_enemy_health(enemy: Dictionary) -> void:
	if enemy["hp"] >= enemy["max_hp"] or enemy["kind"] == "boss":
		return
	var width: float = enemy["radius"] * 1.5
	var pos: Vector2 = enemy["pos"] + Vector2(-width * 0.5, -enemy["radius"] - 12.0)
	draw_rect(Rect2(pos, Vector2(width, 4.0)), Color(0.04, 0.04, 0.09, 0.8))
	draw_rect(Rect2(pos, Vector2(width * maxf(0.0, enemy["hp"] / enemy["max_hp"]), 4.0)), _enemy_color(enemy["kind"]))


func _draw_glow(pos: Vector2, radius: float, color: Color, layers: int) -> void:
	for i in range(layers, 0, -1):
		var c := color
		c.a = 0.018 * float(layers - i + 1)
		draw_circle(pos, radius * (1.0 + float(i) * 0.32), c)


func _enemy_color(kind: String) -> Color:
	match kind:
		"scout":
			return Color(1.0, 0.32, 0.3)
		"spinner":
			return Color(0.84, 0.28, 1.0)
		"heavy":
			return Color(1.0, 0.63, 0.13)
		"boss":
			return Color(1.0, 0.16, 0.55)
	return Color.WHITE


func _draw_ui() -> void:
	match state:
		GameState.TITLE:
			_draw_title()
		GameState.PLAYING:
			_draw_hud()
			if paused:
				_draw_pause()
		GameState.GAME_OVER:
			_draw_hud()
			_draw_end_panel(false)
		GameState.VICTORY:
			_draw_hud()
			_draw_end_panel(true)


func _draw_title() -> void:
	var center := Vector2(screen_size.x * 0.5, screen_size.y * 0.36)
	for i in range(5, 0, -1):
		draw_arc(center, 72.0 + float(i) * 18.0 + sin(Time.get_ticks_msec() * 0.001 + i) * 6.0, -1.1, 4.2, 56, Color(0.15, 0.65, 1.0, 0.05 * i), 3.0)
	_draw_centered("STARFALL", center.y - 14.0, 58, Color(0.78, 0.95, 1.0))
	_draw_centered("PROTOCOL", center.y + 40.0, 30, Color(0.24, 0.82, 1.0))
	_draw_centered("A ONE-MISSION BULLET HELL", center.y + 84.0, 15, Color(0.62, 0.7, 0.87))
	var panel := Rect2(Vector2(screen_size.x * 0.13, screen_size.y * 0.57), Vector2(screen_size.x * 0.74, 190.0))
	draw_rect(panel, Color(0.025, 0.04, 0.11, 0.86), true)
	draw_rect(panel, Color(0.2, 0.68, 1.0, 0.36), false, 2.0)
	_draw_centered("DRAG / WASD / LEFT STICK TO MOVE", panel.position.y + 43.0, 17, Color(0.82, 0.9, 1.0))
	_draw_centered("HOLD PULSE  •  SPACE / LB", panel.position.y + 79.0, 16, Color(0.28, 0.9, 1.0))
	_draw_centered("TRIGGER NOVA  •  E / RB", panel.position.y + 112.0, 16, Color(1.0, 0.67, 0.24))
	_draw_centered("Weapons fire automatically", panel.position.y + 153.0, 15, Color(0.58, 0.65, 0.79))
	var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.004) * 0.2
	_draw_centered("F2  /  HEAVY ENCOUNTER", screen_size.y * 0.89, 16, Color(0.65, 0.8, 0.92))
	_draw_centered("CLICK OR TAP TO LAUNCH", screen_size.y * 0.83, 22, Color(0.76, 0.94, 1.0, pulse))


func _draw_hud() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen_size.x, 86.0)), Color(0.006, 0.012, 0.04, 0.72))
	_draw_text("SCORE", Vector2(22.0, 27.0), 13, Color(0.42, 0.56, 0.75))
	_draw_text(_format_score(score), Vector2(22.0, 57.0), 25, Color(0.9, 0.97, 1.0))
	_draw_centered("TURRET TRIAL" if encounter_preview else "WAVE %d/4" % mini(wave, 4), 27.0, 16, Color(0.52, 0.82, 1.0))
	_draw_centered("%02d:%05.2f" % [int(elapsed / 60.0), fmod(elapsed, 60.0)], 52.0, 17, Color(0.85, 0.93, 1.0))
	for step in range(4):
		var c := Color(0.15, 0.8, 1.0) if step < wave else Color(0.16, 0.21, 0.3)
		draw_line(Vector2(screen_size.x * 0.5 - 42 + step * 22, 70), Vector2(screen_size.x * 0.5 - 26 + step * 22, 70), c, 3.0)

	_draw_text("HULL", Vector2(screen_size.x - 105.0, 27.0), 13, Color(0.42, 0.56, 0.75))
	for i in range(3):
		var c := Color(0.25, 0.9, 1.0) if i < player_hp else Color(0.16, 0.2, 0.29)
		draw_circle(Vector2(screen_size.x - 91.0 + i * 28.0, 55.0), 8.0, c)

	if wave == 4 and not enemies.is_empty():
		for enemy in enemies:
			if enemy["kind"] == "boss":
				var bar_rect := Rect2(Vector2(80.0, 101.0), Vector2(screen_size.x - 160.0, 12.0))
				draw_rect(bar_rect, Color(0.11, 0.03, 0.13, 0.8))
				draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * maxf(0.0, enemy["hp"] / enemy["max_hp"]), bar_rect.size.y)), Color(1.0, 0.17, 0.54))
				_draw_centered("DREADNOUGHT", 96.0, 12, Color(1.0, 0.65, 0.82))
				break

	var pause_rect := _pause_button_rect()
	draw_rect(pause_rect, Color(0.02, 0.05, 0.09, 0.85))
	_draw_text("II", pause_rect.position + Vector2(17, 29), 22, Color(0.75, 0.9, 1.0))
	_draw_ability_button(_aura_button_rect(), "PULSE", aura_energy / MAX_AURA, Color(0.15, 0.76, 1.0), aura_active)
	_draw_ability_button(_nova_button_rect(), "NOVA", nova_energy / MAX_NOVA, Color(1.0, 0.52, 0.14), nova_energy >= MAX_NOVA)
	if aura_exhausted:
		_draw_text("RECHARGING", Vector2(20, screen_size.y - 135), 12, Color(0.4, 0.75, 0.9))
	if encounter_preview:
		_draw_centered("BREAK SHIELD · AIM AT SIDE TURRETS", 119.0, 14, Color(0.55, 0.85, 1.0))
		_draw_centered("PULSE CLEARS BULLETS · DODGE LASERS", 145.0, 12, Color(0.85, 0.65, 0.42))
	if wave_banner > 0.0:
		var title := "FINAL WAVE" if wave == 4 else "WAVE %d" % wave
		var subtitle: String = "DREADNOUGHT INBOUND" if wave == 4 else ["", "FIRST CONTACT", "CROSSFIRE", "BREAK THE LINE"][wave]
		var alpha := minf(1.0, wave_banner * 1.4)
		_draw_centered(title, screen_size.y * 0.19, 28, Color(0.82, 0.95, 1.0, alpha))
		_draw_centered(subtitle, screen_size.y * 0.19 + 28.0, 13, Color(0.34, 0.78, 1.0, alpha))


func _draw_ability_button(rect: Rect2, label: String, fill: float, color: Color, active: bool) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.5
	draw_circle(center, radius, Color(0.015, 0.03, 0.08, 0.78))
	draw_arc(center, radius - 4.0, -PI * 0.5, -PI * 0.5 + TAU_F * clampf(fill, 0.0, 1.0), 40, color, 6.0)
	if active:
		draw_circle(center, radius - 10.0, Color(color.r, color.g, color.b, 0.16))
	var size := 15
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, center + Vector2(-text_width * 0.5, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.88, 0.96, 1.0))


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.01, 0.04, 0.76))
	_draw_centered("PAUSED", screen_size.y * 0.46, 44, Color(0.78, 0.94, 1.0))
	_draw_centered("Press Esc or tap to resume", screen_size.y * 0.51, 17, Color(0.55, 0.68, 0.86))


func _draw_end_panel(victory: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.008, 0.03, 0.7))
	var panel := Rect2(Vector2(screen_size.x * 0.11, screen_size.y * 0.28), Vector2(screen_size.x * 0.78, 420.0))
	draw_rect(panel, Color(0.02, 0.035, 0.09, 0.96), true)
	draw_rect(panel, Color(0.24, 0.8, 1.0, 0.45) if victory else Color(1.0, 0.22, 0.38, 0.5), false, 3.0)
	_draw_centered("MISSION COMPLETE" if victory else "SHIP LOST", panel.position.y + 76.0, 34, Color(0.64, 0.94, 1.0) if victory else Color(1.0, 0.5, 0.58))
	_draw_centered(_format_score(score), panel.position.y + 144.0, 44, Color.WHITE)
	_draw_centered("FINAL SCORE", panel.position.y + 173.0, 13, Color(0.45, 0.56, 0.75))
	_draw_centered("GRAZES  %03d" % graze_count, panel.position.y + 226.0, 18, Color(0.7, 0.79, 0.92))
	_draw_centered("TIME  %02d:%02d" % [int(elapsed / 60.0), int(elapsed) % 60], panel.position.y + 261.0, 18, Color(0.7, 0.79, 0.92))
	_draw_centered("CLICK / TAP / ENTER TO RETRY", panel.position.y + 351.0, 17, Color(0.35, 0.84, 1.0))


func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_centered(text: String, y: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2((screen_size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


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


func _build_audio() -> void:
	sounds["shield_break"] = _make_tone(1200.0, 180.0, 0.3, 0.2, 2)
	sounds["turret_down"] = _make_tone(210.0, 60.0, 0.22, 0.2, 2)
	sounds["laser"] = _make_tone(170.0, 650.0, 0.5, 0.13, 1)
	sounds["dart"] = _make_tone(800.0, 280.0, 0.09, 0.10, 2)
	sounds["start"] = _make_tone(420.0, 720.0, 0.23, 0.24, 0)
	sounds["explode"] = _make_tone(150.0, 48.0, 0.18, 0.2, 2)
	sounds["hit"] = _make_tone(110.0, 34.0, 0.34, 0.32, 2)
	sounds["warning"] = _make_tone(240.0, 180.0, 0.52, 0.25, 1)
	sounds["nova"] = _make_tone(180.0, 860.0, 0.62, 0.34, 0)
	sounds["boss_down"] = _make_tone(360.0, 52.0, 0.9, 0.38, 2)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -5.0
		add_child(player)
		sound_pool.append(player)


func _make_tone(start_hz: float, end_hz: float, duration: float, volume: float, waveform: int) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(maxi(sample_count - 1, 1))
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU_F * hz / float(mix_rate)
		var sample := sin(phase)
		if waveform == 1:
			sample = 1.0 if sample >= 0.0 else -1.0
		elif waveform == 2:
			sample = sin(phase) * 0.62 + rng.randf_range(-1.0, 1.0) * 0.38
		var envelope := pow(1.0 - t, 2.2)
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func play_sound(sound_name: String) -> void:
	if not sounds.has(sound_name) or sound_pool.is_empty():
		return
	var player := sound_pool[sound_cursor]
	sound_cursor = (sound_cursor + 1) % sound_pool.size()
	player.stop()
	player.stream = sounds[sound_name]
	player.play()


func start_encounter_preview() -> void:
	start_game()
	encounter_preview = true
	player_pos.x = screen_size.x * 0.28
	player_target = player_pos
	wave = 3
	wave_spawned = 0
	_spawn_wave_enemy()
	var heavy: Dictionary = enemies.back()
	heavy["pos"] = Vector2(screen_size.x * 0.5, 235.0)
	heavy["hp"] = 680.0
	heavy["max_hp"] = 680.0
	heavy["anchor_x"] = screen_size.x * 0.5
	heavy["vel"] = Vector2.ZERO
	wave_banner = 0.0
	nova_energy = MAX_NOVA


func _update_wrecks(delta: float) -> void:
	for i in range(wrecks.size() - 1, -1, -1):
		var wreck := wrecks[i]
		wreck["timer"] -= delta
		if wreck["timer"] <= 0.0:
			var pos: Vector2 = wreck["pos"] + Vector2(rng.randf_range(-50, 50), rng.randf_range(-40, 40)) * wreck["scale"]
			_spawn_explosion(pos, Color(1.0, 0.5, 0.15), 8, 110.0 * wreck["scale"])
			wreck["remaining"] -= 1
			wreck["timer"] = 0.16
			if wreck["remaining"] <= 0:
				wrecks.remove_at(i)


func _pause_button_rect() -> Rect2:
	return Rect2(Vector2(screen_size.x - 62.0, 96.0), Vector2(44.0, 44.0))



func _restart_selected_mode() -> void:
	if encounter_preview:
		start_encounter_preview()
	else:
		start_game()
