extends Resource
const EnemyDefinition = preload("res://missions/enemy_definition.gd")
## A repeating archetype sequence allows mixed groups without special wave code.
@export var enemies: Array[EnemyDefinition] = []
@export var count: int = 1
@export var start_time: float = 0.15
@export var interval: float = 0.72
@export var formation: PackedFloat32Array = PackedFloat32Array([0.5])
