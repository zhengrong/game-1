# Runtime design

`main.gd` is the composition root and mission coordinator. It binds renderers,
connects weapon events, routes damage outcomes to presentation, and retains player
input, spawning, encounter progression, enemy updates, and world drawing.

| Component | Owns | Boundary |
| --- | --- | --- |
| `systems/effects_system.gd` | Particle/shockwave collections, spawning, lifetimes | Injected RNG; updates receive live attachment targets, not the game |
| `systems/game_audio.gd` | Synthesized streams and audio voice pool | Child Node with an injected RNG and named playback requests |
| `systems/hud_presenter.gd` | HUD/menu drawing and button layout | Explicit display fields refreshed by the coordinator; never changes gameplay |
| `combat/weapon_cycle.gd` | Beam/twin timing and phase state | Emits damage, beam-start, and twin-shot signals; no scene dependency |
| `combat/weapon_config.gd` | Per-instance timing configuration | Typed Resource; default values preserve current balance |
| `combat/collision_queries.gd` | Beam and swept-projectile targeting | Reads supplied enemies; returns typed `HitResult`; no damage or effects |
| `combat/heavy_enemy.gd` damage | Shield, turret, and hull damage rules | Returns typed `DamageResult`; coordinator awards score and plays effects |
| Canvas scripts | Separate render passes/materials | Explicitly bound at startup; no parent-depth lookup |

Timing configuration values must remain positive. Gameplay collections still use
existing dictionary records, preserving hot-loop behavior and capture fixtures.
Hit results, damage outcomes, weapon configuration, and weapon phase state have
explicit types/fields at their boundaries. The HUD's enemy list is a borrowed,
read-only presentation input; rendering must never mutate it.

The coordinator retains forwarding methods and properties for existing combat
callers and regression fixtures. These delegate to the owning service; there is
no duplicate particle storage or weapon phase state. New code should use the
owning service's API instead of adding another responsibility to the coordinator.

The existing shared random stream and synchronous signal order are preserved so
this refactor does not change gameplay randomness or effect timing. Splitting RNG
streams would be a deliberate behavior change, not part of this refactor.

## Validation

`tests/unit/test_systems.gd` tests effects isolation/reproducibility, weapon cadence,
configuration isolation, collision selection/non-mutation, and heavy-damage
outcomes without loading `main.tscn`. Existing scene tests protect integration,
input, scoring, collision behavior, effect lifetimes, and rendering paths.

The full coverage runner must include every production script and retain the 95%
gate. Keep property accessor bodies on separate lines: the current instrumentation
does not correctly handle inline getter/setter bodies.

`tests/capture_visuals.gd` exercises shield warnings, active lasers, destroyed
turrets, beam recovery, and explosion ignition/decay with the real GPU renderer.
The particle CPU benchmark remains in `tests/performance/particles.gd`.

Further work can extract enemy AI/world drawing and replace remaining dictionary
schemas incrementally. Do not add an entity framework or per-particle scene nodes
solely for architectural uniformity.

## Missions

`missions/mission_runner.gd` now owns stage scheduling, completion, and enemy
membership. Typed Resource definitions hold mission/stage/group/archetype content;
`EnemyFactory` creates independent runtime records. `main.gd` responds to runner
signals and reports kills/escapes. See [mission authoring](missions/README.md).

Enemy movement and hull weapons are independent typed profiles. `EnemyMovement`
updates position from a profile; `EnemyWeapons` emits projectile requests connected
by the coordinator. Hull kind controls appearance/rewards, and optional mounts
retain their separate warning/fire state machines. Shared profiles contain no
runtime timers or mutable per-enemy health.

## Player ships

`ShipDefinition` composes hull/handling values with weapon, engine, and ability
resources. `ShipState` owns per-player mutable values and its weapon cycle.
The coordinator binds these services and reads the selected definition through
legacy forwarding properties. See [ship authoring](ships/README.md).

## Defensive abilities

`ShieldConfig` selects Aura geometry and Personal Shield rules; `ShieldSystem`
owns charging, deployed fields, durability, and swept intersections. `ShieldVisual`
reads state without changing combat. The coordinator routes inputs/energy and
applies deferred laser reflection. See [shield implementation notes](shields/README.md).
