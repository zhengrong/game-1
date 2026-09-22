# Phoenix 2 shield reference implementation

Choose **Guardian** or **Phalanx** at the bottom of the title screen (also F3/F4).
Guardian equips Barrier plus Personal Shield; Phalanx equips the forward shield
plus Personal Shield. Existing Interceptor and Bulwark loadouts retain pulse/nova.

Controls:

- Tap the left ability button, Space, or LB to deploy the configured Aura.
- Release the movement touch/mouse drag to charge Personal Shield. Touch again
  to cancel charging or leave protection through its brief fade.
- Desktop alternative: hold Shift/E, RB, or the right SHIELD button.
- Charging/active Zen holds position and stops new main-weapon fire. Personal
  Shield slows simulation to 75% while active. Pausing freezes shield simulation.

## Mechanics and evidence

The community [Aura guide](https://elegater.github.io/Resources/GameFAQs/Auras.html)
describes stationary Barrier protection and forward Phalanx coverage. Our defaults
use a 50-hit Barrier and a 24-hit Phalanx at radius 60 with ±50° coverage. Phalanx
has two charges, weakens through color thresholds, and clears during a 0.3-second
break fade. MIRVs cost three ordinary bullet hits; laser drain is time-based.

The [Zen guide](https://elegater.github.io/Resources/GameFAQs/Zens.html) documents
Personal Shield charging, temporary invulnerability, a short exit fade, slowdown,
and upgraded laser reflection. The base configuration uses 0.6-second charge,
2.5-second duration, radius 50, and 0.2-second fade. Reuse adds charging time that
recovers while released. Reflection is configurable at 20 damage/second per laser.
The sample loadouts enable reflection independently of the base timing defaults;
they do not represent a particular fully upgraded Phoenix 2 ship.

## Integration

Shield state is independent per run. Barrier remains at its deployment position;
Phalanx follows the player and cannot stack. Deploying consumes Aura energy rather
than draining a held bubble. Shield Auras do not passively regenerate; current game
pickups and grazes supply energy. Enemy kills release energy that briefly spreads
from the hull, then homes toward the player. Kill energy is credited only on
collection, including after victory; shield loadouts receive no stage-clear
energy bonus. Drop amounts preserve our previous kill-plus-pickup totals and
are still project tuning, not measured Phoenix 2 values. Personal Shield uses charging,
not the nova energy meter. Restart/ship selection clears all shield state.

Swept projectile paths hit shields before missile splitting and hull collisions.
Bullets already inside a Barrier or under a Phalanx are not automatically erased.
Lasers stop at the first shield surface; reflected damage is deferred until after
enemy iteration, preventing removal from invalidating that loop. Personal Shield
protection includes its exit fade. Timers account for overshoot on long frames.

## Visual presentation

Shields use translucent animated membrane cells, layered edge glow, an inward
filament and an expanding deployment front. Phalanx keeps its forward silhouette
and illuminated tips. Weakening changes color; breaking fragments the rim into
outward sparks. Hits create two expanding ripples, with mobile-shield impacts
following the ship. Visual time advances with simulation, so pause freezes it.
Impact effects are capped at 48 and expire after 0.32 seconds. Rendering uses no
random sampling and does not modify collision boundaries or gameplay state.

## Remaining fidelity gaps

This is a functional reference implementation, **not verified frame-for-frame
parity**. Player shield animations are not established by the existing upload.
The current rims, colors, fades, radius-to-screen scaling, Barrier decay rate and
energy-to-radius mapping are procedural approximations. Barrier's Ultimate inner
lining, Apex variants, exact energy economics, and different laser classes are not
implemented. Break fades currently block lasers for their remaining time, rather
than modeling the reference's finite fade durability. Enemy blue-shield art is
unchanged by this work. Guide values are community documentation, not measurements
of the uploaded recording.

`tests/unit/test_shields.gd` covers directionality, gaps, sweeping, durability,
reflection flags, fades, time-step consistency, and reset behavior. Scene tests
cover actual damage routing, touch input, Zen control, and drawing. Run GPU capture
with `godot --path . --script tests/capture_shields.gd`; output is ignored under
`visual-reports/shields/`.
