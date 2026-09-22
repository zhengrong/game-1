extends Resource
const WeaponConfig = preload("res://combat/weapon_config.gd")
const AbilityConfig = preload("res://ships/ability_config.gd")
const EngineConfig = preload("res://ships/engine_config.gd")
@export var display_name: String = "Interceptor"
@export var texture: Texture2D = preload("res://assets/ships/player_interceptor_hd.png")
@export var visual_size: Vector2 = Vector2(148, 154)
@export var collision_radius: float = 11.0
@export var health: int = 3
@export var speed: float = 680.0
@export var drag_response: float = 24.0
@export var spawn_invulnerability: float = 1.2
@export var hit_invulnerability: float = 1.8
@export var muzzle: Vector2 = Vector2(0, -72)
@export var default_twin_shots: bool = false
@export var weapon: WeaponConfig = WeaponConfig.new()
@export var abilities: AbilityConfig = AbilityConfig.new()
@export var engines: EngineConfig = EngineConfig.new()
@export var hit_sound: String = "hit"
@export var nova_sound: String = "nova"

const ShieldConfig = preload("res://shields/shield_config.gd")
@export var shields: ShieldConfig = ShieldConfig.new()
