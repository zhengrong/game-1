extends RefCounted
const Definition = preload("res://ships/ship_definition.gd")
var weapon = preload("res://combat/weapon_cycle.gd").new()
var position: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var health: int = 3
var invulnerability: float = 0.0
var aura_energy: float = 100.0
var nova_energy: float = 0.0
var aura_active: bool = false
var aura_exhausted: bool = false

func reset(definition: Definition) -> void:
	# Keep the cycle object: the coordinator's signal connections remain valid.
	weapon.config = definition.weapon
	weapon.twin_timer = 0.0
	weapon.shot_timer = 0.0
	weapon.shot_sequence = 0
	weapon.beam_overcharged = false
	weapon.beam_visible_timer = 0.0
	weapon.beam_pause_timer = 0.0
	weapon.beam_age = 0.0
	weapon.beam_contact = false
	health = definition.health
	invulnerability = definition.spawn_invulnerability
	aura_energy = definition.abilities.aura_capacity
	nova_energy = clampf(definition.abilities.nova_initial, 0.0, definition.abilities.nova_capacity)
	aura_active = false
	aura_exhausted = false
