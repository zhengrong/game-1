extends Resource
## Tunable weapon timings; state lives in WeaponCycle, not this resource.
@export var damage_interval: float = 0.066
@export var beam_duration: float = 0.27
@export var beam_pause: float = 0.135
@export var twin_interval: float = 0.28
@export var beam_damage: float = 17.0
@export var overcharge_damage: float = 31.0
@export var attack_time: float = 0.07
@export var twin_offsets: PackedVector2Array = PackedVector2Array([Vector2(-22, 0), Vector2(22, 0)])
@export var twin_speed: float = 2100.0
@export var twin_damage: float = 24.0
@export var twin_radius: float = 8.0
@export var twin_lifetime: float = 1.2
