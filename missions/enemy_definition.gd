extends Resource
## Shared immutable archetype. Runtime dictionaries are created afresh by the factory.
@export var kind: String = "scout"
@export var radius: float = 24.0
@export var health: float = 55.0
@export var speed: float = 70.0
@export var score: int = 650
@export var entry_y: float = -44.0
@export var shielded_mounts: bool = false

const Movement = preload("res://missions/movement_definition.gd")
const Weapon = preload("res://missions/enemy_weapon_definition.gd")
@export var movement: Movement = preload("res://missions/movements/scout.tres")
@export var weapon: Weapon = preload("res://missions/weapons/scout.tres")
