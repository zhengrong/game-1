extends Resource
## A shared weapon profile; cooldown is stored on each enemy instance.
enum Pattern { AIMED, SPINNER_CYCLE, BOSS_CYCLE, NONE, FAN, RADIAL, MISSILE }
@export var pattern: Pattern = Pattern.AIMED
@export var cooldown: float = 1.25
@export var cooldown_max: float = 1.8
@export var speed: float = 265.0
@export var radius: float = 6.0
@export var color: Color = Color(1.0, 0.11, 0.025)
@export var count: int = 7
@export var spread: float = 0.13
