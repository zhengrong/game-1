extends Resource
## Guide-based level-one defaults; visual scale and decay are project tuning.
enum Aura { PULSE, BARRIER, PHALANX }
@export var aura: Aura = Aura.PULSE
@export var personal_enabled: bool = false
@export var personal_radius: float = 50.0
@export var personal_charge: float = 0.6
@export var personal_duration: float = 2.5
@export var personal_fade: float = 0.2
@export var personal_penalty: float = 3.0
@export var personal_recovery: float = 6.0
@export var reflect_lasers: bool = false
@export var reflection_dps: float = 20.0
@export var barrier_radius: float = 250.0
@export var barrier_strength: float = 50.0
@export var barrier_decay: float = 5.0
@export var barrier_min_energy: float = 30.0
@export var barrier_fade: float = 0.3
@export var phalanx_radius: float = 60.0
@export var phalanx_half_angle: float = 50.0
@export var phalanx_strength: float = 24.0
@export var phalanx_charges: int = 2
@export var phalanx_fade: float = 0.3
@export var laser_drain: float = 12.5

@export var aura_regen_limit: float = 10.0
@export var aura_regen_rate: float = 10.0 / 3.0
@export var phalanx_charge_energy: float = 60.0
