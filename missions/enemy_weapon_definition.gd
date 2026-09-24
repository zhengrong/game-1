extends Resource
## A shared weapon profile; cooldown is stored on each enemy instance.
enum Pattern { AIMED, SPINNER_CYCLE, BOSS_CYCLE, NONE, FAN, RADIAL, MISSILE, BURST, LASER, LASER_MIRV, DOOM_BOMB, SUPER_MIRV }
@export_enum("capsule", "orb", "lance", "dart", "pellet", "shuriken", "boomerang") var projectile_style: String = "capsule"
@export var pattern: Pattern = Pattern.AIMED
@export var cooldown: float = 1.25
@export var cooldown_max: float = 1.8
@export var speed: float = 265.0
@export var radius: float = 6.0
@export var color: Color = Color(1.0, 0.11, 0.025)
@export var count: int = 7
@export var spread: float = 0.13

# Independent turret behavior; numeric tuning is our own reference approximation.
enum Aim { FIXED, TRACKING, LOCKED, SPINNING }
@export var aiming: Aim = Aim.TRACKING
@export_range(1, 4) var tier: int = 1
@export var burst_count: int = 3
@export var burst_interval: float = 0.11
@export var turn_speed: float = 3.0
@export var fixed_angle: float = PI * 0.5
@export var curve: float = 0.0
@export var death_mirv: bool = false
@export var laser_warning: float = 0.75
@export var laser_duration: float = 0.5
@export var laser_width: float = 8.0
@export var charge_time: float = 1.5
@export var bomb_radius: float = 300.0
