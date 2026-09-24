# Enemy weapon behavior reference

Implemented September 23, 2026. These are playable reference approximations,
not an exact Phoenix 2 reproduction. Source: light_rock_zz's
[Invader Weaponry guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/invader-weaponry).
The guide distinguishes dart streamers/launchers/spreads/spinners, shuriken
variants, straight/split boomerangs, pellet/laser/caged MIRVs, normal/speed
lasers and Doomsday weapons. Do not import values from its Phoenix HD appendix:
that describes a different game.

## Separation of responsibilities

- EnemyWeaponDefinition specifies pattern, aim mode, tier, burst cadence and
  projectile family independently of the enemy hull.
- EnemyWeapons owns per-enemy aim and burst state and emits projectile/ray
  requests. Fixed guns hold their angle; tracking guns turn during a burst;
  locked guns keep a burst angle; spinning guns sweep their emission angle.
  Tier currently selects one to four lanes, not every original turret variant.
- EnemyProjectile owns flight. Shurikens leave quickly and settle into slow
  drift. Split boomerangs curve apart for a bounded interval, then travel
  straight. Their motion integrates from age and is consistent at 30/60/120 Hz.
  These are tuned trajectories, not reverse-engineered Phoenix equations.
- EnemyLaser owns warning/active visual phases and active-time overlap. The
  scene routes damage and shield interception. Firing-hull destruction cancels
  its rays; detached laser MIRVs survive their launcher.
- EnemyBulletVisual draws shapes using age and velocity without changing motion.

## Playable mission changes

First Contact mixes ordinary scouts with fixed three-dart streams. Crossfire
adds spinning shuriken emitters and scouts with on-death pellet payloads. Break
The Line introduces locked split boomerangs, speed-laser scouts and laser MIRVs.
The damaged boss periodically charges a wide downward Doomsday-style laser.
Spawn counts are unchanged; balance has not been matched to Phoenix 2.

Laser MIRVs emit five or nine warned rays according to tier. Pellet MIRVs and
on-death carriers still use our eight-pellet payload. All projectile families
participate in the existing shield, graze and collision systems. Curved-motion
updates use short collision substeps; laser warnings cannot damage the player.
Restart clears hazards and burst state. Pause stops simulation updates.

## Remaining gaps

Original turret artwork, firing sounds, complete tier/Mk tables, exact tracking
rates, locking delays, projectile dimensions, speeds and burst intervals need
reference measurement. Doomsday Bomb and Super MIRV now have functional implementations; exact
launcher counts, cadence, visuals and all defensive interactions remain approximate. Laser
variants currently use locked straight rays; full rotating laser-turret behavior
and all original defensive interactions remain incomplete. The legacy boss
cycle still includes our lance variant. Do not label this as full parity.

## Verification

The unit suite covers burst counts/aim modes/cooldowns, split lane curvature,
frame-rate-independent motion, warning safety, active laser damage, source
cancellation, Personal Shield blocking, MIRV ray counts, on-death payloads,
rendering and reset. GPU fixture `tests/capture_enemy_patterns.gd` shows real
weapon simulation at four times; output is in ignored
`visual-reports/enemy-weapons/patterns-*.png`. It holds emitters stationary for
comparison and does not reproduce a Phoenix encounter or certify mobile speed.

## Doomsday follow-up

The damaged boss rotates through a wide laser, area bomb, and Super MIRV volley
at five-second opportunities. Bombs show a 300-unit red boundary and 1.5-second
charge, followed by a short active blast. Intersecting Barrier/Phalanx fields are
removed; Personal Shield still prevents hull damage. The boundary follows its
launcher during charging, then freezes at detonation. Destroying the source
before discharge cancels the attack. The game retains its existing hull health.

A Super MIRV is a slower, larger carrier with inward chevrons. It is immediately
armed and has a larger proximity trigger. On activation it releases six ordinary
MIRVs, also immediately armed; each can release eight pellets. Children cannot
produce another Super MIRV. One carrier exhausts a struck Barrier or Phalanx
into its existing fade state, while Personal Shield can intercept it. Shield
interception precedes splitting. Normal MIRV arming now uses 0.5 seconds.

The guide supports the qualitative hierarchy, immediate arming, bomb radius,
Barrier vulnerability and Personal Shield protection. Charge/duration values,
110-unit carrier speed, 320-unit trigger radius, six children and eight-pellet
payload are this project's tuning, not measured Phoenix 2 values. No full parity
or mobile performance claim is made. Ray and bomb warnings pause with gameplay;
restart clears charges. On a long update the blast crossing is still processed,
and each launcher discharges only once per charge.

GPU fixture: `tests/capture_doomsday.gd`; captures are ignored under
`visual-reports/doomsday/`. Tests exercise warning safety, source cancellation,
blast protection, carrier overload, finite splitting, timer overshoot and reset.
