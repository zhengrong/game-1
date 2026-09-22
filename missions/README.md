# Authoring missions

Assign a `MissionDefinition` resource to the main scene's **Mission Definition**
property. `industrial_assault.tres` contains the existing four-stage mission.
Resources can be edited in the Godot Inspector without modifying the scheduler.

A mission has a title, optional background, initial delay, and ordered stages.
Each stage has a title, spawn groups, completion rule, and transition delay.
Each group has a repeating list of enemy definitions, total count, start time in
seconds relative to stage entry, spawn interval, and repeating normalized x
positions. Multiple groups may overlap; a gap between groups cannot end a stage.
Use positive intervals, nonnegative counts/start times, and nonempty enemy and
formation arrays for every group that spawns enemies.

Enemy resources set hull kind (`scout`, `spinner`, `heavy`, or `boss`), health,
radius, speed, score, entry y, and optional shielded mounts. Movement and hull
weapon are separate shared resources. Duplicate an archetype to create stat or
behavior combinations; runtime health, cooldowns, and turret state remain separate
for every spawn.

Movement profiles support strafe, anchored strafe, boss orbit, and straight flight.
Tune frequency, amplitude, settling height, cruise speed, and deceleration. Strafe
amplitude is in pixels; boss orbit amplitude is a fraction of viewport width.
Profiles can pause while an attached laser is locked or firing. Straight flight
continues through the screen without settling.

Weapon profiles support aimed shots, fan, radial, missile, no hull weapon, and
the original spinner/boss attack cycles. Generic patterns expose cooldown,
projectile speed/radius/color, count, and fan spread. Aimed shots choose a cooldown
between `cooldown` and `cooldown_max`; fan/radial/missile use `cooldown`. The original
spinner/boss cycles retain their authored phase timing and projectile settings.
Turret weapons remain an independent mount system selected by `shielded_mounts`.

For an example, `enemies/fan_scout.tres` combines the scout hull, straight movement,
and a seven-shot fan. Assign it to any group's enemy list; no new enemy-kind branch
is needed. The default mission deliberately retains its original archetypes.
Completely new movement algorithms or attack patterns still require implementation
in `combat/enemy_movement.gd` or `combat/enemy_weapons.gd`.

Formation values are fractions of viewport width (0.0 left, 1.0 right). For
example, `[0.2, 0.5, 0.8]` distributes successive ships across three columns.
Entry movement uses the selected movement profile, not editable curves.
The default mission preserves its enemy counts, archetype sequence, spawn
intervals, and formation at the 720px design width. Spawn scheduling catches up
on delayed frames instead of silently losing elapsed spawn time.

Completion rules:

- **CLEAR_FIELD:** all scheduled spawns have happened and every stage-owned enemy
  has died or left the field. This preserves the original first three waves.
- **DEFEAT_ALL:** all scheduled enemies must be defeated; an escape fails the
  mission. Used by the final boss stage.

The runner emits spawn requests with unique tokens. The game must report both
kills and escapes with that token. Tokens remain unique across restarts, so stale
callbacks cannot clear a new encounter. Killing a boss in an intermediate stage
does not win the mission; only the runner completing the final stage does.
The HUD derives stage count and subtitles from mission content. The heavy preview
remains independent of the selected mission.

Validation: independent scheduler tests cover mixed groups, late reinforcements,
transition delay, strict escape rules, restart isolation, empty stages/missions,
and independent enemy state. Integration tests complete the default mission and
a custom boss-then-scout mission.
