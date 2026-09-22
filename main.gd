extends Node2D

# Starfall Protocol: a self-contained vertical bullet-hell demo.
# Textured ships with procedural combat effects and synthesized audio.

const CollisionQueries = preload("res://combat/collision_queries.gd")
const Missile = preload("res://combat/missile.gd")
const EnvironmentVisual = preload("res://combat/environment_visual.gd")
const BeamVisual = preload("res://combat/beam_visual.gd")
const HeavyEnemy = preload("res://combat/heavy_enemy.gd")
const FireVisual = preload("res://combat/fire_visual.gd")

const GameState = preload("res://systems/game_types.gd").GameState

var PLAYER_RADIUS: float:
	get:
		return ship_definition.collision_radius
var PLAYER_SPEED: float:
	get:
		return ship_definition.speed
var PLAYER_SHOT_INTERVAL: float:
	get:
		return ship_definition.weapon.damage_interval
var PLAYER_BEAM_FIRE_TIME: float:
	get:
		return ship_definition.weapon.beam_duration
var PLAYER_BEAM_PAUSE_TIME: float:
	get:
		return ship_definition.weapon.beam_pause
var PLAYER_BEAM_ATTACK_TIME: float:
	get:
		return ship_definition.weapon.attack_time
const PLAYFIELD_MARGIN := 30.0
var AURA_RADIUS: float:
	get:
		return ship_definition.abilities.aura_radius
var MAX_AURA: float:
	get:
		return ship_definition.abilities.aura_capacity
var MAX_NOVA: float:
	get:
		return ship_definition.abilities.nova_capacity
const TAU_F := TAU
# Measured against the 589 px-wide Phoenix 2 reference screenshot, including
# the player's side pods and each enemy's dark outer nacelles.
var PLAYER_VISUAL_SIZE: Vector2:
	get:
		return ship_definition.visual_size
const SCOUT_VISUAL_SIZE := Vector2(134.0, 172.0)
const SPINNER_VISUAL_SIZE := Vector2(140.0, 180.0)
const HEAVY_VISUAL_SIZE := Vector2(174.0, 190.0)
var PLAYER_NOSE_OFFSET: Vector2:
	get:
		return ship_definition.muzzle
var PLAYER_SHIP_TEXTURE: Texture2D:
	get:
		return ship_definition.texture
const SCOUT_TEXTURE: Texture2D = preload("res://assets/ships/enemy_scout.png")
const HEAVY_TEXTURE: Texture2D = preload("res://assets/ships/enemy_heavy.png")
const BOSS_TEXTURE: Texture2D = preload("res://assets/ships/enemy_boss.png")
const FIREBALL_TEXTURE: Texture2D = preload("res://assets/effects/fireball.png")
const SMOKE_TEXTURE: Texture2D = preload("res://assets/effects/smoke.png")
const BATTLEFIELD_BACKGROUND: Texture2D = preload("res://assets/backgrounds/amber_megastructure_hd.png")

const EnemyMovement = preload("res://combat/enemy_movement.gd")
var enemy_weapons = preload("res://combat/enemy_weapons.gd").new()
const EnemyFactory = preload("res://missions/enemy_factory.gd")
const MissionDefinition = preload("res://missions/mission_definition.gd")
@export var mission_definition: MissionDefinition = preload("res://missions/industrial_assault.tres")
var mission = preload("res://missions/mission_runner.gd").new()

const ShipDefinition = preload("res://ships/ship_definition.gd")
@export var ship_definition: ShipDefinition = preload("res://ships/interceptor.tres")
const ShieldConfig = preload("res://shields/shield_config.gd")
var shields = preload("res://shields/shield_system.gd").new()
var zen_released := false
var zen_button := false
var zen_pointer := -1
var shield_reflections: Array[Dictionary] = []
var reflected_rays: Array[Dictionary] = []
var ship = preload("res://ships/ship_state.gd").new()
var weapon:
	get:
		return ship.weapon
var effects = preload("res://systems/effects_system.gd").new()
var audio = preload("res://systems/game_audio.gd").new()
var hud = preload("res://systems/hud_presenter.gd").new()

var state: GameState = GameState.TITLE
var twin_shots: bool:
	get:
		return weapon.twin_shots
	set(value):
		weapon.twin_shots = value
var twin_timer: float:
	get:
		return weapon.twin_timer
	set(value):
		weapon.twin_timer = value
var screen_size := Vector2(720.0, 1280.0)
var rng := RandomNumberGenerator.new()
var font: Font

var stars: Array[Dictionary] = []
var background_panels: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var player_bullets: Array[Dictionary] = []
var enemy_bullets: Array[Dictionary] = []
var particles: Array[Dictionary]:
	get:
		return effects.particles
var pickups: Array[Dictionary] = []
var shockwaves: Array[Dictionary]:
	get:
		return effects.shockwaves

var player_pos: Vector2:
	get:
		return ship.position
	set(value):
		ship.position = value
var player_target: Vector2:
	get:
		return ship.target
	set(value):
		ship.target = value
var player_hp: int:
	get:
		return ship.health
	set(value):
		ship.health = value
var player_invulnerable: float:
	get:
		return ship.invulnerability
	set(value):
		ship.invulnerability = value
var shot_timer: float:
	get:
		return weapon.shot_timer
	set(value):
		weapon.shot_timer = value
var aura_energy: float:
	get:
		return ship.aura_energy
	set(value):
		ship.aura_energy = value
var aura_active: bool:
	get:
		return ship.aura_active
	set(value):
		ship.aura_active = value
var nova_energy: float:
	get:
		return ship.nova_energy
	set(value):
		ship.nova_energy = value
var score := 0
var combo := 1.0
var combo_timer := 0.0
var graze_count := 0

var wave := 0
var wave_spawned := 0
var wave_goal := 0
var wave_break := 0.0
var wave_banner := 0.0
var elapsed := 0.0
var mission_complete_timer := 0.0

var pointer_active := false
var pointer_index := -1
var aura_pointer_index := -1
var mouse_aura := false
var encounter_preview := false
var wrecks: Array[Dictionary] = []
var aura_exhausted: bool:
	get:
		return ship.aura_exhausted
	set(value):
		ship.aura_exhausted = value
var paused := false
var flash := 0.0
var shake := 0.0
var muzzle_flash := 0.0
var shot_sequence: int:
	get:
		return weapon.shot_sequence
	set(value):
		weapon.shot_sequence = value
var beam_end := Vector2.ZERO
var beam_contact: bool:
	get:
		return weapon.beam_contact
	set(value):
		weapon.beam_contact = value
var beam_overcharged: bool:
	get:
		return weapon.beam_overcharged
	set(value):
		weapon.beam_overcharged = value
var beam_visible_timer: float:
	get:
		return weapon.beam_visible_timer
	set(value):
		weapon.beam_visible_timer = value
var beam_pause_timer: float:
	get:
		return weapon.beam_pause_timer
	set(value):
		weapon.beam_pause_timer = value
var beam_age: float:
	get:
		return weapon.beam_age
	set(value):
		weapon.beam_age = value
var beam_damage_sequence := 0
var thruster_timer := 0.0

var sound_pool: Array[AudioStreamPlayer]:
	get:
		return audio.sound_pool


func _ready() -> void:
	ship.reset(ship_definition)
	shields.reset(ship_definition.shields, player_pos)
	weapon.twin_shots = ship_definition.default_twin_shots
	enemy_weapons.aimed.connect(_fire_aimed)
	enemy_weapons.fan.connect(_fire_fan)
	enemy_weapons.radial.connect(_fire_radial)
	enemy_weapons.missile.connect(func(origin): enemy_bullets.append(Missile.create(origin, player_pos)))
	mission.spawn_requested.connect(_spawn_mission_enemy)
	mission.stage_started.connect(_on_stage_started)
	mission.stage_cleared.connect(_on_stage_cleared)
	mission.completed.connect(_on_mission_completed)
	mission.failed.connect(func(): state = GameState.GAME_OVER)
	weapon.damage_requested.connect(_fire_player_weapon)
	weapon.beam_started.connect(_on_beam_started)
	weapon.twin_requested.connect(_spawn_twin_shots)
	effects.rng = rng
	$Backdrop.game = self
	$World.game = self
	$Flares.game = self
	$Fire.game = self
	$ThreatLayer/Threats.game = self
	$InterfaceLayer/Interface.render = _draw_ui
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
	ship.reset(ship_definition)
	mission.reset(mission_definition)
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
	shields.reset(ship_definition.shields, player_pos)
	zen_released = false
	zen_button = false
	zen_pointer = -1
	shield_reflections.clear()
	reflected_rays.clear()
	pointer_active = false
	pointer_index = -1
	aura_pointer_index = -1
	mouse_aura = false
	shot_timer = 0.0
	aura_energy = MAX_AURA
	aura_active = false
	score = 0
	combo = 1.0
	combo_timer = 0.0
	graze_count = 0
	wave = 0
	wave_spawned = 0
	wave_goal = 0
	wave_break = 0.55
	wave_banner = 0.0
	elapsed = 0.0
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
	twin_timer = 0.0
	play_sound("start")


func _process(delta: float) -> void:
	if paused:
		zen_button = false
		zen_released = false
		zen_pointer = -1
	if state == GameState.PLAYING and not paused and shields.personal > 0.0:
		delta *= 0.75
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
		reflected_rays.clear()
		_update_enemies(delta)
		_apply_shield_reflections()
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
		_update_pickups(delta)
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
	var manual_zen := ship_definition.shields.personal_enabled and (zen_button or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER))
	if movement.length() > 0.0 and not manual_zen:
		pointer_active = false
		player_pos += movement.limit_length(1.0) * PLAYER_SPEED * delta
	elif pointer_active and not manual_zen:
		player_target.x = clampf(player_target.x, PLAYFIELD_MARGIN, screen_size.x - PLAYFIELD_MARGIN)
		player_target.y = clampf(player_target.y, screen_size.y * 0.16, screen_size.y - 96.0)
		player_pos = player_pos.lerp(player_target, 1.0 - exp(-delta * ship_definition.drag_response))

	player_pos.x = clampf(player_pos.x, PLAYFIELD_MARGIN, screen_size.x - PLAYFIELD_MARGIN)
	player_pos.y = clampf(player_pos.y, screen_size.y * 0.16, screen_size.y - 96.0)

	var aura_pressed := Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or mouse_aura or aura_pointer_index >= 0
	var zen_held := ship_definition.shields.personal_enabled and (zen_released or zen_button or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_E) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER))
	if movement.length() > 0.0 or pointer_active:
		zen_released = false
		zen_held = zen_button or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_E)
	shields.advance(delta, player_pos, zen_held)
	if ship_definition.shields.aura == ShieldConfig.Aura.PULSE:
		if aura_exhausted and aura_energy >= ship_definition.abilities.aura_restart:
			aura_exhausted = false
		aura_active = not aura_exhausted and (Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or mouse_aura or aura_pointer_index >= 0) and aura_energy > 0.0
		if aura_active:
			aura_energy = maxf(0.0, aura_energy - ship_definition.abilities.aura_drain * delta)
			_absorb_bullets()
			if aura_energy <= 0.0:
				aura_exhausted = true
		else:
			aura_energy = minf(MAX_AURA, aura_energy + ship_definition.abilities.aura_recharge * delta)
	else:
		aura_active = false
		if aura_pressed and not shields.aura_held:
			aura_energy -= shields.deploy(aura_energy, MAX_AURA)
		# Shield Auras refill from collected energy/grazes, not passive regeneration.
	shields.aura_held = aura_pressed
	if not ship_definition.shields.personal_enabled and (Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)):
		_try_nova()

	if not zen_held and shields.personal <= 0.0:
		_update_player_weapon_cycle(delta)
	else:
		beam_visible_timer = 0.0
		beam_contact = false
	thruster_timer -= delta
	if thruster_timer <= 0.0:
		for offset in ship_definition.engines.offsets:
			_spawn_thruster(player_pos + offset, ship_definition.engines.color, ship_definition.engines.scale)
		thruster_timer = ship_definition.engines.emission_interval


func _update_player_weapon_cycle(delta: float) -> void:
	weapon.advance(delta)


func _spawn_twin_shots(delay: float = 0.0) -> void:
	for offset in ship_definition.weapon.twin_offsets:
		player_bullets.append({"pos": player_pos + PLAYER_NOSE_OFFSET + offset,
			"vel": Vector2(0, -ship_definition.weapon.twin_speed), "radius": ship_definition.weapon.twin_radius, "damage": ship_definition.weapon.twin_damage,
			"life": ship_definition.weapon.twin_lifetime, "age": 0.0, "delay": delay, "overcharged": false, "style": "twin"})


func _start_player_beam() -> void:
	weapon.start_beam()


func _on_beam_started() -> void:
	muzzle_flash = PLAYER_BEAM_ATTACK_TIME
	_spawn_muzzle_flash(player_pos + PLAYER_NOSE_OFFSET)


func _fire_player_weapon() -> void:
	beam_damage_sequence += 1
	var hit := _query_beam_hit(beam_overcharged)
	var target_index: int = hit["index"]
	if target_index >= 0:
		var target := enemies[target_index]
		var hit_pos := Vector2(player_pos.x + PLAYER_NOSE_OFFSET.x, hit["end_y"])
		if target.has("turrets"):
			_damage_heavy(target, ship_definition.weapon.overcharge_damage if beam_overcharged else ship_definition.weapon.beam_damage, hit_pos, hit["part"])
		else:
			target["hp"] -= ship_definition.weapon.overcharge_damage if beam_overcharged else ship_definition.weapon.beam_damage
		if not target.has("turrets"):
			target["hit_flash"] = minf(1.0, target["hit_flash"] + (0.72 if beam_overcharged else 0.42))
		if beam_damage_sequence % 2 == 0 or beam_overcharged:
			_spawn_player_impact(hit_pos, Vector2.UP, beam_overcharged)
			if float(target.get("shield", 0.0)) <= 0.0:
				_spawn_sparks(hit_pos, Color(2.0, 0.6, 0.08), 3, 110.0)
				_spawn_damage_fire(hit_pos + Vector2(0, -7), 1.1 if beam_overcharged else 0.85)
				_spawn_hot_fragments(hit_pos, 2, 170.0)
		if target["hp"] <= 0.0:
			_destroy_enemy(target_index)


func _query_beam_hit(overcharged: bool) -> Dictionary:
	var hit := CollisionQueries.beam(enemies, player_pos + PLAYER_NOSE_OFFSET, overcharged)
	return {"index": hit.index, "end_y": hit.end_y, "part": hit.part}


func _update_beam_visual(_delta: float) -> void:
	if beam_visible_timer <= 0.0:
		beam_contact = false
		return
	var hit := _query_beam_hit(beam_overcharged)
	beam_contact = hit["index"] >= 0
	var desired_end := Vector2(player_pos.x + PLAYER_NOSE_OFFSET.x, hit["end_y"])
	# Contact is pinned to the current collision surface; no endpoint lag.
	beam_end = desired_end


func _update_spawner(delta: float) -> void:
	mission.advance(delta)
	wave_spawned = mission.spawned
	wave_break = mission.waiting if mission.transitioning else 0.0


func _on_stage_started(index: int) -> void:
	wave = index + 1
	wave_spawned = 0
	wave_banner = 2.2
	wave_goal = 0
	for group in mission_definition.stages[index].groups:
		wave_goal += group.count


func _spawn_mission_enemy(definition: Resource, x_fraction: float, token: int) -> void:
	var enemy := EnemyFactory.create(definition, screen_size.x * x_fraction, rng)
	enemy["mission_token"] = token
	enemies.append(enemy)
	if definition.kind == "boss":
		play_sound("warning")


func _spawn_wave_enemy() -> void:
	# Preview/test adapter reads the same content as the mission scheduler.
	var group = mission_definition.stages[wave - 1].groups[0]
	var definition = group.enemies[wave_spawned % group.enemies.size()]
	var x: float = group.formation[wave_spawned % group.formation.size()]
	enemies.append(EnemyFactory.create(definition, screen_size.x * x, rng))


func _spawn_boss() -> void:
	enemies.append(EnemyFactory.create(preload("res://missions/enemies/boss.tres"), screen_size.x * 0.5, rng))
	play_sound("warning")


func _on_stage_cleared() -> void:
	wave_break = mission.waiting
	_clear_all_enemy_bullets(true)
	if ship_definition.shields.aura == ShieldConfig.Aura.PULSE:
		aura_energy = minf(MAX_AURA, aura_energy + 28.0)
		nova_energy = minf(MAX_NOVA, nova_energy + 18.0)


func _on_mission_completed() -> void:
	state = GameState.VICTORY


func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		enemy["age"] += delta
		enemy["fire"] -= delta
		enemy["hit_flash"] = maxf(0.0, enemy["hit_flash"] - delta * 5.8)
		enemy["damage_tick"] -= delta
		var kind: String = enemy["kind"]
		var ready_to_fire := EnemyMovement.advance(enemy, enemy["movement"], delta, screen_size.x)
		if ready_to_fire:
			enemy_weapons.fire(enemy, enemy["weapon"], rng)
		if enemy.has("turrets"):
			HeavyEnemy.update(self, enemy, delta)

		var health_ratio: float = enemy["hp"] / enemy["max_hp"]
		if health_ratio < 0.48 and enemy["damage_tick"] <= 0.0:
			# Stable hull vents sustain a joined burn rather than random isolated dots.
			var severity := clampf((0.48 - health_ratio) / 0.48, 0.0, 1.0)
			var burn_scale := lerpf(0.75, 1.35, severity) * (1.5 if kind == "boss" else 1.0)
			for side in [-1.0, 1.0]:
				var vent_offset := Vector2(side * enemy["radius"] * 0.24, -enemy["radius"] * 0.16)
				_spawn_damage_fire(enemy["pos"] + vent_offset, burn_scale, enemy)
			enemy["damage_tick"] = lerpf(0.13, 0.065, severity)

		if enemy["pos"].y > screen_size.y + 150.0:
			mission.enemy_removed(enemy.get("mission_token", -1), false)
			enemies.remove_at(i)


func _update_boss(enemy: Dictionary, delta: float) -> void:
	if EnemyMovement.advance(enemy, enemy["movement"], delta, screen_size.x):
		enemy_weapons.fire(enemy, enemy["weapon"], rng)


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
		var delay: float = bullet.get("delay", 0.0)
		var available := maxf(0.0, delta - delay)
		bullet["delay"] = maxf(0.0, delay - delta)
		if available <= 0.0:
			continue
		var step := minf(available, maxf(0.0, bullet["life"]))
		var previous: Vector2 = bullet["pos"]
		bullet["pos"] += bullet["vel"] * step
		bullet["life"] -= available
		bullet["age"] = float(bullet.get("age", 0.0)) + step
		var hit := CollisionQueries.sweep(enemies, previous, bullet["pos"], bullet["radius"])
		var nearest: float = hit.fraction
		var target_index: int = hit.index
		var target_part: int = hit.part
		if target_index >= 0:
			var target := enemies[target_index]
			var contact := previous.lerp(bullet["pos"], nearest)
			if target.has("turrets"):
				_damage_heavy(target, bullet["damage"], contact, target_part)
			else:
				target["hp"] -= bullet["damage"]
				target["hit_flash"] = minf(1.0, target["hit_flash"] + 0.42)
			_spawn_player_impact(contact, bullet["vel"], bullet["overcharged"])
			if target["hp"] <= 0.0:
				_destroy_enemy(target_index)
		if target_index >= 0 or bullet["life"] <= 0.0 or bullet["pos"].y < -35.0:
			player_bullets.remove_at(i)


func _damage_heavy(enemy: Dictionary, amount: float, point: Vector2, part: int = -1) -> void:
	var outcome := HeavyEnemy.damage(enemy, amount, point, part)
	match outcome.kind:
		HeavyEnemy.DamageResult.Kind.SHIELD:
			_spawn_sparks(point, Color(0.25, 1.4, 2.6), 4, 110.0)
			if outcome.destroyed:
				_spawn_energy_burst(enemy["pos"], Color(0.2, 0.85, 1.8), 0.75)
				shockwaves.append({"pos": enemy["pos"], "radius": HeavyEnemy.SHIELD_RADIUS, "max": 135.0, "life": 0.45, "color": Color(0.2, 0.8, 1.0)})
				play_sound("shield_break")
		HeavyEnemy.DamageResult.Kind.TURRET:
			_spawn_sparks(point, Color(2.0, 0.8, 0.2), 5, 160.0)
			if outcome.destroyed:
				_spawn_explosion(outcome.origin, Color(1.0, 0.45, 0.12), 10, 105.0)
				play_sound("turret_down")
				score += outcome.score
		HeavyEnemy.DamageResult.Kind.HULL:
			_spawn_sparks(point, Color(2.0, 0.65, 0.12), 3, 130.0)


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
	var drop_count := 9 if kind == "boss" else (3 if kind == "heavy" else 1)
	# Transfer the former kill reward into collectible energy; never grant it twice.
	var aura_per_drop := 4.0 + (25.0 if kind == "boss" else 8.0) / float(drop_count)
	var nova_per_drop := 3.0 + (42.0 if kind == "boss" else 7.5) / float(drop_count)
	for k in range(drop_count):
		pickups.append({
			"pos": enemy["pos"] + Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(4.0, enemy["radius"]),
			"vel": Vector2.from_angle(rng.randf_range(0.0, TAU_F)) * rng.randf_range(30.0, 95.0),
			"life": 7.0, "age": 0.0, "homing": true,
			"aura": aura_per_drop, "nova": nova_per_drop,
		})
	mission.enemy_removed(enemy.get("mission_token", -1), true)
	enemies.remove_at(index)
	shake = 16.0 if kind == "boss" else 5.0
	play_sound("boss_down" if kind == "boss" else "explode")
	if kind == "boss":
		_clear_all_enemy_bullets(true)
		if not enemy.has("mission_token"):
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
		var shield_hit := shields.intercept(previous, bullet["pos"], bullet["radius"], false, 0.0, bullet.get("style", "") == "missile")
		if not shield_hit.is_empty():
			enemy_bullets.remove_at(i)
			continue
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
			if ship_definition.shields.aura != ShieldConfig.Aura.PULSE:
				aura_energy = minf(MAX_AURA, aura_energy + MAX_AURA / (24.0 * maxf(1.0, ship_definition.shields.phalanx_charges)))
		var closest := Geometry2D.get_closest_point_to_segment(player_pos, previous, bullet["pos"])
		if player_invulnerable <= 0.0 and closest.distance_to(player_pos) < bullet["radius"] + PLAYER_RADIUS:
			enemy_bullets.remove_at(i)
			_damage_player()
			# Damage clears nearby bullets, invalidating the remaining indices.
			return
		if bullet["pos"].x < -70.0 or bullet["pos"].x > screen_size.x + 70.0 or bullet["pos"].y < -90.0 or bullet["pos"].y > screen_size.y + 90.0:
			enemy_bullets.remove_at(i)


func _damage_player() -> void:
	if player_invulnerable > 0.0 or shields.protected() or state != GameState.PLAYING:
		return
	player_hp -= 1
	player_invulnerable = ship_definition.hit_invulnerability
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
	if ship_definition.shields.personal_enabled:
		return
	if nova_energy < MAX_NOVA or state != GameState.PLAYING:
		return
	nova_energy = 0.0
	_spawn_energy_burst(player_pos, Color(1.5, 0.18, 0.9), 1.2)
	flash = 0.9
	shake = 20.0
	shockwaves.append({"pos": player_pos, "radius": 18.0, "max": maxf(screen_size.x, screen_size.y) * 0.88, "life": 0.9, "color": Color(1.0, 0.58, 0.18)})
	_clear_all_enemy_bullets(true)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].has("turrets"):
			var had_shield: bool = enemies[i]["shield"] > 0.0
			_damage_heavy(enemies[i], ship_definition.abilities.nova_damage, enemies[i]["pos"])
			if not had_shield:
				for part in range(enemies[i]["turrets"].size()):
					_damage_heavy(enemies[i], ship_definition.abilities.nova_damage, enemies[i]["pos"], part)
		else:
			enemies[i]["hp"] -= ship_definition.abilities.nova_boss_damage if enemies[i]["kind"] == "boss" else ship_definition.abilities.nova_damage
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
		if pickup["life"] <= 0.0:
			pickups.remove_at(i)
			continue
		pickup["age"] = pickup.get("age", 0.0) + delta
		var previous: Vector2 = pickup["pos"]
		var distance: float = previous.distance_to(player_pos)
		var homing: bool = pickup.get("homing", false)
		# A brief outward burst makes energy leaving the hull visible before attraction.
		if (homing and pickup["age"] >= 0.18) or (not homing and distance < 280.0):
			pickup["vel"] = pickup["vel"].lerp(previous.direction_to(player_pos) * 660.0, 1.0 - exp(-delta * 7.0))
		else:
			pickup["vel"] = pickup["vel"].lerp(Vector2(0.0, 70.0), 1.0 - exp(-delta * 2.0))
		pickup["pos"] += pickup["vel"] * delta
		var closest := Geometry2D.get_closest_point_to_segment(player_pos, previous, pickup["pos"])
		if closest.distance_to(player_pos) < 25.0:
			score += int(180.0 * combo)
			aura_energy = minf(MAX_AURA, aura_energy + float(pickup.get("aura", 4.0)))
			if not ship_definition.shields.personal_enabled:
				nova_energy = minf(MAX_NOVA, nova_energy + float(pickup.get("nova", 3.0)))
			pickups.remove_at(i)
			continue
		if pickup["pos"].y > screen_size.y + 30.0:
			pickups.remove_at(i)


func _spawn_sparks(origin: Vector2, color: Color, count: int, speed: float) -> void:
	effects._spawn_sparks(origin, color, count, speed)


func _spawn_muzzle_flash(origin: Vector2) -> void:
	effects._spawn_muzzle_flash(origin)


func _spawn_player_impact(origin: Vector2, velocity: Vector2, overcharged: bool) -> void:
	effects._spawn_player_impact(origin, velocity, overcharged)


func _spawn_thruster(origin: Vector2, color: Color, scale: float) -> void:
	effects._spawn_thruster(origin, color, scale)


func _spawn_damage_fire(origin: Vector2, scale: float, source: Dictionary = {}) -> void:
	effects._spawn_damage_fire(origin, scale, source)


func _spawn_hot_fragments(origin: Vector2, count: int, speed: float) -> void:
	effects._spawn_hot_fragments(origin, count, speed)


func _spawn_energy_burst(origin: Vector2, tint: Color, scale: float) -> void:
	effects._spawn_energy_burst(origin, tint, scale)


func _spawn_explosion(origin: Vector2, color: Color, count: int, speed: float) -> void:
	effects._spawn_explosion(origin, color, count, speed)


func _update_particles(delta: float) -> void:
	effects._update_particles(delta, enemies)


func _update_shockwaves(delta: float) -> void:
	effects._update_shockwaves(delta)


func _check_wave_complete() -> void:
	wave_banner = maxf(0.0, wave_banner - get_process_delta_time())
	mission.check_completion()


func _unhandled_input(event: InputEvent) -> void:
	if state == GameState.TITLE and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		if event.position.y > screen_size.y * 0.925:
			select_ship(preload("res://ships/guardian.tres") if event.position.x < screen_size.x * 0.5 else preload("res://ships/phalanx.tres"))
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			select_ship(preload("res://ships/guardian.tres"))
			return
		if event.keycode == KEY_F4:
			select_ship(preload("res://ships/phalanx.tres"))
			return
	if state == GameState.PLAYING and not paused and ship_definition.shields.personal_enabled:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				zen_released = false
				if _nova_button_rect().has_point(event.position):
					zen_button = true
					return
			else:
				zen_released = pointer_active
				zen_button = false
		if event is InputEventScreenTouch:
			if event.pressed:
				zen_released = false
				if _nova_button_rect().has_point(event.position):
					zen_pointer = event.index
					zen_button = true
					return
			else:
				if event.index == pointer_index:
					zen_released = true
				if event.index == zen_pointer:
					zen_pointer = -1
					zen_button = false
					return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		twin_shots = not twin_shots
		twin_timer = 0.0
		beam_visible_timer = 0.0
		beam_pause_timer = 0.0
		beam_contact = false
		return
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
	$Backdrop.position = draw_offset
	$Backdrop.queue_redraw()
	$World.position = draw_offset
	$World.queue_redraw()
	for enemy in enemies:
		if enemy.has("turrets") and state == GameState.PLAYING:
			HeavyEnemy.draw_hazards(self, enemy)
	$ThreatLayer/Threats.position = draw_offset
	$ThreatLayer/Threats.queue_redraw()
	$Flares.position = draw_offset
	$Flares.queue_redraw()
	$Fire.position = draw_offset
	$Fire.queue_redraw()
	draw_set_transform(Vector2.ZERO)
	$InterfaceLayer/Interface.queue_redraw()
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.75, 0.94, 1.0, flash * 0.32))


func _draw_background(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2(-30.0, -30.0), screen_size + Vector2(60.0, 60.0)), Color(0.008, 0.012, 0.045))
	# Preserve the source aspect ratio on both 16:9 desktop previews and tall
	# iPhones. A small overscan leaves room for restrained camera drift.
	var background: Texture2D = mission_definition.background if mission_definition.background != null else BATTLEFIELD_BACKGROUND
	var texture_size := background.get_size()
	var cover_scale := maxf(screen_size.x / texture_size.x, screen_size.y / texture_size.y) * 1.025
	var background_size := texture_size * cover_scale
	var drift := Vector2(sin(elapsed * 0.07) * 6.0, sin(elapsed * 0.045) * 9.0)
	var background_rect := Rect2((screen_size - background_size) * 0.5 + drift, background_size)
	canvas.draw_texture_rect(background, background_rect, false, Color(0.55, 0.66, 0.74, 1.0))
	# Reserve the brightest values for live bullets, impacts, and the player beam.
	canvas.draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.008, 0.015, 0.035, 0.23))
	EnvironmentVisual.draw_layers(self, canvas)
	for star in stars:
		var color := Color(0.68, 0.9, 1.0, star["alpha"] * 0.38)
		canvas.draw_line(star["pos"], star["pos"] - Vector2(0.0, star["size"] * 3.2), color, maxf(0.7, star["size"] * 0.72))


func _draw_world(canvas: Node2D) -> void:
	for pickup in pickups:
		_draw_glow(pickup["pos"], 8.0, Color(0.35, 1.0, 0.82), 3, canvas)
		canvas.draw_circle(pickup["pos"], 3.0, Color.WHITE)

	for enemy in enemies:
		_draw_enemy(enemy, canvas)


	for ring in shockwaves:
		var ring_color: Color = ring["color"]
		ring_color.a = clampf(ring["life"] * 1.5, 0.0, 0.8)
		canvas.draw_arc(ring["pos"], ring["radius"], 0.0, TAU_F, 72, ring_color.lightened(0.35), 2.2)
		ring_color.a *= 0.28
		canvas.draw_arc(ring["pos"], ring["radius"] * 1.035, 0.0, TAU_F, 72, ring_color, 7.0)

	for particle in particles:
		if particle["kind"] in ["fire", "ember", "ember_wake"]:
			FireVisual.draw_smoke(canvas, particle)
		var color: Color = particle["color"]
		var ratio: float = clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		color.a = ratio
		match particle["kind"]:
			"spark":
				canvas.draw_line(particle["pos"], particle["pos"] - particle["vel"].normalized() * particle["size"] * 4.2, Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, ratio), particle["size"])
				canvas.draw_circle(particle["pos"], particle["size"] * 0.6, Color(minf(color.r * 1.8, 2.2), minf(color.g * 1.8, 2.2), minf(color.b * 1.8, 2.2), ratio))
			"plasma":
				var fire_size: float = particle["size"]
				var fire_core := Color(minf(color.r * 1.7, 2.25), minf(color.g * 1.7, 2.25), minf(color.b * 1.7, 2.25), ratio)
				canvas.draw_circle(particle["pos"], fire_size * 1.75, Color(color.r, color.g * 0.45, color.b * 0.25, ratio * 0.1))
				canvas.draw_circle(particle["pos"], fire_size, Color(color.r, color.g, color.b, ratio * 0.58))
				canvas.draw_circle(particle["pos"] - particle["vel"].normalized() * fire_size * 0.18, fire_size * 0.42, fire_core)
			"smoke":
				var smoke_size: float = particle["size"] * 3.1
				var smoke_rect := Rect2(particle["pos"] - Vector2.ONE * smoke_size * 0.5, Vector2.ONE * smoke_size)
				canvas.draw_texture_rect(SMOKE_TEXTURE, smoke_rect, false, Color(0.72, 0.76, 0.84, ratio * 0.52))

	if state == GameState.PLAYING or state == GameState.GAME_OVER:
		_draw_player(canvas)

func _draw_enemy_bullet(bullet: Dictionary, canvas: Node2D) -> void:
	if bullet.get("style", "") == "missile":
		Missile.draw_missile(canvas, bullet)
		return
	if bullet.get("style", "") == "dart":
		var pos: Vector2 = bullet["pos"]
		var direction: Vector2 = bullet["vel"].normalized()
		var side := direction.orthogonal()
		canvas.draw_colored_polygon(PackedVector2Array([pos + direction * 11.0, pos - direction * 7.0 + side * 5.0, pos - direction * 4.0, pos - direction * 7.0 - side * 5.0]), Color(1.8, 0.42, 0.04))
		canvas.draw_line(pos - direction * 3.0, pos + direction * 7.0, Color(3.0, 1.8, 0.6), 2.0, true)
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
	canvas.draw_line(back, front, glow_color, glow_radius * 2.0, true)
	canvas.draw_circle(back, glow_radius, glow_color, true, -1.0, true)
	canvas.draw_circle(front, glow_radius, glow_color, true, -1.0, true)

	# Dark rim, saturated red glass shell, then a narrow orange-hot interior.
	var rim_radius := radius * 1.04
	var rim_color := Color(0.32, 0.004, 0.001, 0.96)
	canvas.draw_line(back, front, rim_color, rim_radius * 2.0, true)
	canvas.draw_circle(back, rim_radius, rim_color, true, -1.0, true)
	canvas.draw_circle(front, rim_radius, rim_color, true, -1.0, true)

	var shell_radius := radius * 0.83
	var shell_color := Color(1.25, 0.025, 0.004, 0.98)
	canvas.draw_line(back, front, shell_color, shell_radius * 2.0, true)
	canvas.draw_circle(back, shell_radius, shell_color, true, -1.0, true)
	canvas.draw_circle(front, shell_radius, shell_color, true, -1.0, true)

	var inner_back := pos - direction * half_segment * 0.38
	var inner_front := pos + direction * half_segment * 0.46
	var inner_radius := radius * 0.47
	var inner_color := Color(1.8, 0.3, 0.018, 0.98)
	canvas.draw_line(inner_back, inner_front, inner_color, inner_radius * 2.0, true)
	canvas.draw_circle(inner_back, inner_radius, inner_color, true, -1.0, true)
	canvas.draw_circle(inner_front, inner_radius, inner_color, true, -1.0, true)

	var highlight_pos := front - direction * radius * 0.32 - normal * radius * 0.18
	canvas.draw_circle(highlight_pos, radius * 0.24, Color(2.0, 1.15, 0.34, 0.98), true, -1.0, true)


func _draw_player_beam(canvas: Node2D) -> void:
	BeamVisual.draw_beam(self, canvas)


func _draw_player(canvas: Node2D) -> void:
	if player_hp <= 0:
		return
	var invulnerability_pulse := 0.0
	if player_invulnerable > 0.0:
		invulnerability_pulse = 0.5 + sin(elapsed * 11.0) * 0.5
		var shield_radius := 82.0 + invulnerability_pulse * 4.0
		canvas.draw_circle(player_pos, shield_radius, Color(0.04, 0.58, 1.8, 0.035 + invulnerability_pulse * 0.018))
		canvas.draw_arc(player_pos, shield_radius, -elapsed * 2.1, -elapsed * 2.1 + PI * 1.35, 42, Color(0.25, 1.05, 2.5, 0.34 + invulnerability_pulse * 0.2), 1.8, true)
		canvas.draw_arc(player_pos, shield_radius - 4.0, elapsed * 1.7, elapsed * 1.7 + PI * 0.82, 30, Color(0.72, 1.55, 2.8, 0.2 + invulnerability_pulse * 0.16), 1.1, true)
	if aura_active:
		var pulse := 1.0 + sin(elapsed * 7.0) * 0.04
		canvas.draw_circle(player_pos, AURA_RADIUS * pulse, Color(0.04, 0.5, 1.2, 0.04))
		canvas.draw_arc(player_pos, AURA_RADIUS * pulse, -elapsed * 1.8, TAU_F - elapsed * 1.8, 64, Color(0.15, 0.9, 1.65, 0.82), 3.0)
		canvas.draw_arc(player_pos, AURA_RADIUS * 0.88, elapsed * 2.3, TAU_F + elapsed * 2.3, 48, Color(0.7, 1.4, 1.8, 0.34), 2.0)
		for spoke in range(6):
			var spoke_angle := elapsed * 0.65 + TAU_F * float(spoke) / 6.0
			var spoke_dir := Vector2.from_angle(spoke_angle)
			canvas.draw_line(player_pos + spoke_dir * AURA_RADIUS * 0.91, player_pos + spoke_dir * AURA_RADIUS, Color(0.25, 1.0, 1.8, 0.55), 2.0)

	_draw_glow(player_pos + Vector2(0.0, 3.0), 22.0, Color(0.06, 0.5, 1.15), 2, canvas)
	var engine_pulse := 1.0 + sin(elapsed * 42.0) * 0.18
	for offset in ship_definition.engines.offsets:
		canvas.draw_circle(player_pos + offset + Vector2(0, 2), 8.5 * engine_pulse * ship_definition.engines.scale, Color(ship_definition.engines.color.r * 0.4, ship_definition.engines.color.g * (0.55 / 0.78), ship_definition.engines.color.b * 1.7, 0.18))
		canvas.draw_circle(player_pos + offset, 3.1 * engine_pulse * ship_definition.engines.scale, Color(1.3, 1.9, 2.0))
	var player_rect := Rect2(player_pos - PLAYER_VISUAL_SIZE * 0.5, PLAYER_VISUAL_SIZE)
	var ship_modulate := Color(1.0 + invulnerability_pulse * 0.08, 1.0 + invulnerability_pulse * 0.16, 1.0 + invulnerability_pulse * 0.28)
	canvas.draw_texture_rect(PLAYER_SHIP_TEXTURE, player_rect, false, ship_modulate)
	canvas.draw_circle(player_pos, PLAYER_RADIUS, Color(0.02, 0.12, 0.18, 0.9))
	canvas.draw_arc(player_pos, PLAYER_RADIUS, 0.0, TAU, 24, Color(0.4, 1.3, 1.8), 1.2, true)
	# Re-light the reactor and weapon ports after the textured hull is drawn.
	_draw_glow(player_pos + Vector2(0.0, 1.0), 5.0, Color(1.6, 0.65, 0.06), 2, canvas)
	canvas.draw_circle(player_pos + Vector2(0.0, 1.0), 2.4, Color(2.0, 1.15, 0.3))

func _draw_enemy(enemy: Dictionary, canvas: Node2D) -> void:
	var pos: Vector2 = enemy["pos"]
	var kind: String = enemy["kind"]
	var color := _enemy_color(kind)
	var radius: float = enemy["radius"]
	_draw_glow(pos, radius * 0.55, color * 0.9, 2, canvas)
	var hit_light: float = clampf(enemy["hit_flash"], 0.0, 1.0)
	var hull_modulate := Color(1.0 + hit_light * 0.28, 1.0 + hit_light * 0.35, 1.0 + hit_light * 0.45)
	match kind:
		"scout":
			_draw_enemy_engines(pos, 31.0, 1.32, color, canvas)
			canvas.draw_texture_rect(SCOUT_TEXTURE, Rect2(pos - SCOUT_VISUAL_SIZE * 0.5, SCOUT_VISUAL_SIZE), false, hull_modulate)
		"spinner":
			_draw_enemy_engines(pos, 34.0, 1.42, color, canvas)
			var spinner_modulate := hull_modulate * Color(1.08, 0.62, 1.28)
			canvas.draw_texture_rect(SCOUT_TEXTURE, Rect2(pos - SPINNER_VISUAL_SIZE * 0.5, SPINNER_VISUAL_SIZE), false, spinner_modulate)
			canvas.draw_arc(pos, radius * 1.13, enemy["age"] * 1.8, enemy["age"] * 1.8 + PI * 1.35, 32, Color(1.2, 0.3, 2.6, 0.72), 2.0)
			canvas.draw_arc(pos, radius * 1.25, -enemy["age"] * 1.15, -enemy["age"] * 1.15 + PI * 0.92, 24, Color(0.7, 0.2, 2.2, 0.42), 1.2)
		"heavy":
			_draw_enemy_engines(pos, 46.0, 1.8, color, canvas)
			canvas.draw_texture_rect(HEAVY_TEXTURE, Rect2(pos - HEAVY_VISUAL_SIZE * 0.5, HEAVY_VISUAL_SIZE), false, hull_modulate)
			_draw_glow(pos + Vector2(0.0, 7.0), 7.0, Color(3.0, 1.0, 0.08), 3, canvas)
		"boss":
			_draw_boss(pos, enemy, canvas)
	if enemy.has("turrets"):
		HeavyEnemy.draw_components(canvas, enemy)
	_draw_enemy_health(enemy, canvas)

func _draw_enemy_engines(pos: Vector2, spread: float, scale: float, color: Color, canvas: Node2D) -> void:
	var pulse := 1.0 + sin(elapsed * 31.0 + pos.x * 0.01) * 0.2
	for side in [-1.0, 1.0]:
		var engine_pos := pos + Vector2(spread * 0.5 * side, -spread * 0.75)
		canvas.draw_circle(engine_pos, 7.5 * scale * pulse, Color(color.r * 1.4, color.g * 0.5, color.b * 0.45, 0.12))
		canvas.draw_circle(engine_pos, 2.6 * scale * pulse, Color(3.8, 0.7, 0.32))

func _draw_boss(pos: Vector2, enemy: Dictionary, canvas: Node2D) -> void:
	var hit_light: float = clampf(enemy["hit_flash"], 0.0, 1.0)
	var boss_modulate := Color(1.0 + hit_light * 0.95, 1.0 + hit_light * 1.22, 1.0 + hit_light * 1.52)
	_draw_enemy_engines(pos + Vector2(0.0, -23.0), 122.0, 2.1, _enemy_color("boss"), canvas)
	canvas.draw_texture_rect(BOSS_TEXTURE, Rect2(pos - Vector2(185.0, 123.0), Vector2(370.0, 247.0)), false, boss_modulate)
	var core_size: float = 25.0 + sin(enemy["age"] * 5.0) * 4.0
	_draw_glow(pos + Vector2(0.0, -5.0), core_size * 1.2, Color(2.6, 0.12, 1.2), 4, canvas)
	canvas.draw_circle(pos + Vector2(0.0, -5.0), core_size * 0.32, Color(3.8, 0.36, 1.6, 0.72))

func _draw_enemy_health(enemy: Dictionary, canvas: Node2D) -> void:
	if enemy["hp"] >= enemy["max_hp"] or enemy["kind"] == "boss":
		return
	var width: float = enemy["radius"] * 1.5
	var pos: Vector2 = enemy["pos"] + Vector2(-width * 0.5, -enemy["radius"] - 12.0)
	canvas.draw_rect(Rect2(pos, Vector2(width, 4.0)), Color(0.04, 0.04, 0.09, 0.8))
	canvas.draw_rect(Rect2(pos, Vector2(width * maxf(0.0, enemy["hp"] / enemy["max_hp"]), 4.0)), _enemy_color(enemy["kind"]))

func _draw_glow(pos: Vector2, radius: float, color: Color, layers: int, canvas: Node2D) -> void:
	for i in range(layers, 0, -1):
		var c := color
		c.a = 0.018 * float(layers - i + 1)
		canvas.draw_circle(pos, radius * (1.0 + float(i) * 0.32), c)

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


func _draw_ui(canvas: Node2D) -> void:
	hud.state = state
	hud.screen_size = screen_size
	hud.font = font
	hud.paused = paused
	hud.twin_shots = twin_shots
	hud.score = score
	hud.encounter_preview = encounter_preview
	hud.wave = wave
	hud.stage_count = mission_definition.stages.size()
	hud.stage_title = mission_definition.stages[wave - 1].title if wave > 0 and wave <= mission_definition.stages.size() else ""
	hud.elapsed = elapsed
	hud.player_hp = player_hp
	hud.player_max_hp = ship_definition.health
	hud.MAX_AURA = MAX_AURA
	hud.MAX_NOVA = MAX_NOVA
	hud.aura_label = ["PULSE", "BARRIER", "PHALANX"][ship_definition.shields.aura]
	hud.zen_label = "SHIELD" if ship_definition.shields.personal_enabled else "NOVA"
	hud.zen_fill = clampf(shields.charge / maxf(0.001, shields.config.personal_charge + shields.penalty), 0.0, 1.0) if ship_definition.shields.personal_enabled else nova_energy / MAX_NOVA
	hud.zen_active = shields.protected() if ship_definition.shields.personal_enabled else nova_energy >= MAX_NOVA
	hud.enemies = enemies
	hud.aura_energy = aura_energy
	hud.aura_active = aura_active
	hud.nova_energy = nova_energy
	hud.aura_exhausted = aura_exhausted
	hud.wave_banner = wave_banner
	hud.graze_count = graze_count
	hud._draw_ui(canvas)


func _format_score(value: int) -> String:
	return hud._format_score(value)


func _aura_button_rect() -> Rect2:
	hud.screen_size = screen_size
	return hud._aura_button_rect()


func _nova_button_rect() -> Rect2:
	hud.screen_size = screen_size
	return hud._nova_button_rect()




func _build_audio() -> void:
	audio.rng = rng
	add_child(audio)
	audio._build_audio()


func _make_tone(start_hz: float, end_hz: float, duration: float, volume: float, waveform: int) -> AudioStreamWAV:
	return audio._make_tone(start_hz, end_hz, duration, volume, waveform)


func play_sound(sound_name: String) -> void:
	if sound_name == "hit":
		sound_name = ship_definition.hit_sound
	elif sound_name == "nova":
		sound_name = ship_definition.nova_sound
	audio.play_sound(sound_name)


func start_encounter_preview() -> void:
	start_game()
	encounter_preview = true
	player_pos.x = screen_size.x * 0.28
	player_target = player_pos
	wave = 3
	wave_spawned = 0
	enemies.append(EnemyFactory.create(preload("res://missions/enemies/heavy.tres"), screen_size.x * 0.5, rng))
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
	hud.screen_size = screen_size
	return hud._pause_button_rect()


func _restart_selected_mode() -> void:
	if encounter_preview:
		start_encounter_preview()
	else:
		start_game()


func select_ship(definition: ShipDefinition) -> void:
	ship_definition = definition
	weapon.twin_shots = definition.default_twin_shots
	start_game()


func _intercept_laser(start: Vector2, end: Vector2, delta: float) -> Vector2:
	var hit := shields.intercept(start, end, HeavyEnemy.LASER_RADIUS, true, delta)
	if hit.is_empty():
		return end
	if hit["reflect"] and not enemies.is_empty():
		var target: Dictionary = enemies[rng.randi_range(0, enemies.size() - 1)]
		shield_reflections.append({"target": target, "damage": shields.config.reflection_dps * delta})
		reflected_rays.append({"start": hit["point"], "end": target["pos"]})
	return hit["point"]


func _apply_shield_reflections() -> void:
	for hit in shield_reflections:
		var index := enemies.find(hit["target"])
		if index < 0:
			continue
		var enemy := enemies[index]
		if enemy.has("turrets"):
			_damage_heavy(enemy, hit["damage"], enemy["pos"])
		else:
			enemy["hp"] -= hit["damage"]
		if enemy["hp"] <= 0.0:
			_destroy_enemy(index)
	shield_reflections.clear()
