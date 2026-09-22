extends Resource
## Reusable flight profile, independent of hull and weapons.
enum Mode { STRAFE, ANCHORED, BOSS_ORBIT, STRAIGHT }
@export var mode: Mode = Mode.STRAFE
@export var frequency: float = 1.8
@export var amplitude: float = 52.0
@export var settle_y: float = 205.0
@export var cruise_speed: float = 13.0
@export var deceleration: float = 45.0
@export var lateral_speed: float = 28.0
@export var pause_for_laser: bool = true
