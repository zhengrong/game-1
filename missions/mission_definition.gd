extends Resource
const StageDefinition = preload("res://missions/stage_definition.gd")
@export var background: Texture2D
@export var title: String = "Industrial Assault"
@export var stages: Array[StageDefinition] = []
@export var initial_delay: float = 0.55
