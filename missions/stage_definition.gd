extends Resource
const SpawnGroup = preload("res://missions/spawn_group.gd")
enum Completion { CLEAR_FIELD, DEFEAT_ALL }
@export var title: String = "FIRST CONTACT"
@export var groups: Array[SpawnGroup] = []
@export var completion: Completion = Completion.CLEAR_FIELD
@export var transition_delay: float = 1.8
