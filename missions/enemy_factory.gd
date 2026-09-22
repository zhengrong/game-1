extends RefCounted
const Definition = preload("res://missions/enemy_definition.gd")
const HeavyEnemy = preload("res://combat/heavy_enemy.gd")
static func create(definition: Definition, x: float, rng: RandomNumberGenerator) -> Dictionary:
	var boss := definition.kind == "boss"
	var enemy := {"kind": definition.kind, "movement": definition.movement, "weapon": definition.weapon, "pos": Vector2(x, definition.entry_y),
		"vel": Vector2(0, definition.speed), "hp": definition.health, "max_hp": definition.health,
		"radius": definition.radius, "value": definition.score, "age": 0.0,
		"phase": 0.0 if boss else rng.randf_range(0.0, TAU),
		"fire": 1.25 if boss else rng.randf_range(0.5, 1.2), "anchor_x": x,
		"hit_flash": 0.0, "damage_tick": 0.0 if boss else rng.randf_range(0.02, 0.12)}
	if definition.shielded_mounts:
		HeavyEnemy.equip(enemy)
	return enemy
