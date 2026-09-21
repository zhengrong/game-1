# Mission-play visual checklist

Scope: what the player sees during a mission. This excludes fleet collection, shops, progression, and online services. Based on the Phoenix 2 research and local code review recorded on 2026-09-21.

These are proposed visual requirements, not a claim that every detail has been measured in Phoenix 2. Exact appearance and timing still need reference captures. Check an item only after implementation and visual verification.

## Existing foundation

### Implementation update — 2026-09-21

The first playable milestone is implemented, with additional work from steps 2–6:

- Shielded heavy with two independently destructible, aiming turrets; dart and tracking-laser state machines; locked warning geometry; persistent wrecked mounts.
- Pink splitting missiles on spinners, distinct dart silhouettes, and swept bullet collision checks.
- Shield impact arcs and break fragments, localized component damage, and delayed large-enemy destruction bursts.
- Connected electrical beam, changing attached feather structures, attack fan, surface contact, and a thin residual release line.
- Third-wave escort lane layouts and two peripheral industrial parallax layers over the existing background.
- Core outline, live mission clock, wave markers, Pulse recharge feedback, and touch pause control.
- F2 isolated encounter, relative drag, controller launch/retry/pause, and F1 return to title.

Gameplay regression checks pass in Godot, including multi-rate weapon timing and normal mission progression. Controlled portrait frames were rendered and inspected for shield/warning, active laser, turret destruction/release, and recovery. The new behavior is in `combat/`, integrated through `main.gd`.

The checkboxes below remain full visual acceptance goals, not automatic implementation flags. Reference-matched recordings, actual phone testing, multiple environment art sets, all weapon/ability families, armor-specific mechanics, and the broader fleet remain outstanding. Generated sample frames do not establish performance or exact Phoenix 2 parity.

The demo already has large textured ships, HDR glow, thrusters, hit flashes, fire, smoke, sparks, shockwaves, screen shake, basic ability effects, and one drifting background. The goal is to add readable battlefield behavior and variety.

## 1. Enemy turrets — first priority

- [ ] Draw distinct weapon mounts on enemy hulls.
- [ ] Rotate tracking turrets toward their targets.
- [ ] Animate charge-up, firing, recoil where appropriate, and cooldown.
- [ ] Give different turret families recognizable silhouettes.
- [ ] Show individual turret destruction and persistent damaged mounts.
- [ ] Tie local fires and sparks to damaged components.

Acceptance: the player can identify which gun is about to fire and which gun has been disabled while its carrier remains alive. Requires individual turret gameplay state.

## 2. Projectile variety and attack warnings — first priority

- [ ] Distinct pellets, darts, spinning shurikens, and curved boomerangs.
- [ ] Missiles that visibly split into secondary threats.
- [ ] Laser hazards with charge, active, and cooldown phases.
- [ ] Tracking and sweeping attacks with readable aiming behavior.
- [ ] Clear warning areas for large beams and area attacks.
- [ ] Consistent silhouettes and contrast during dense patterns.
- [ ] Collision shapes that agree with the dangerous part of each effect.

Acceptance: players can distinguish incoming threats and their paths at normal speed. Warnings precede damage, and bright effects do not conceal hostile shots.

## 3. Shields, armor, and destruction — second priority

- [ ] Visible enemy shield surfaces and localized hit ripples.
- [ ] Shield-break effects that clearly expose the hull beneath.
- [ ] Different impact feedback for shields, armor, and exposed hull.
- [ ] Localized flashes and damage at struck weapon mounts.
- [ ] Progressive damaged states and fragments.
- [ ] Staged destruction for capital ships, scaled beyond ordinary enemy bursts.
- [ ] Preserve visibility of surviving weapons through smoke and fire.

Acceptance: players can tell whether an attack struck a shield, armor, hull, or turret without reading a health number. Requires corresponding defense and component states.

## 4. Formations and battlefield composition — second priority

- [ ] Deliberate entrance trajectories and formation settling.
- [ ] Greater variation in enemy scale and arrangement.
- [ ] Escorts arranged around large ships.
- [ ] Changing gaps and clear movement lanes between threats.
- [ ] Capital encounters that visually emphasize multiple weapons.
- [ ] Tune spacing for the intended portrait viewport.

Acceptance: encounters have recognizable compositions and remain readable at the target screen size, rather than appearing as repeated ships in fixed lanes.

## 5. Environment depth — second priority

- [ ] Several coherent mission environments.
- [ ] Independently moving background and foreground layers.
- [ ] Large machinery and structures that establish scale.
- [ ] Stronger sense of forward travel.
- [ ] Environment lighting and contrast that preserve projectile visibility.
- [ ] Foreground elements that do not obscure the playable field.

Acceptance: depth and movement are apparent during play while the combat lane remains readable. One drifting background plate alone does not complete this requirement.

## 6. Player weapon presentation

- [ ] Distinct visuals for direct shots, spreads, bursts, beams, missiles, and piercing attacks as those weapons are implemented.
- [ ] Weapon-specific muzzle flashes, trajectories, impacts, and firing rhythms.
- [ ] Keep muzzle and impact effects aligned during movement.
- [ ] Make charging, firing, and recovery visually distinguishable.
- [ ] Complete the connected electrical beam specified in [the detailed visual checklist](PHOENIX2_VISUAL_FEATURES.md).

For that reference beam specifically:

- [ ] Continuous white/cyan shaft without packet gaps.
- [ ] Connected feather structures that deform throughout firing.
- [ ] Broad attack fan that narrows during sustain.
- [ ] Surface-tracking blue-white impact with orange fire and fragments.
- [ ] Visible contraction into a thin blue residual line before disappearing.
- [ ] A fully empty recovery interval.

Acceptance: verify consecutive attack, sustain, release, and recovery frames. This beam treatment applies to the sampled weapon, not every ship.

## 7. Ability effects

- [ ] Expanding bullet-clear and stun waves with distinguishable effects.
- [ ] Persistent barriers and personal shields with readable boundaries.
- [ ] Laser reflection with a clear return direction.
- [ ] Teleport destination preview, departure, and arrival.
- [ ] Time-field boundaries and affected-object feedback.
- [ ] Missile swarms, lances, and other offensive ability effects.
- [ ] Charge, ready, activation, expiration, and recovery cues.
- [ ] Effects that accurately represent ability range and duration.

Acceptance: visual boundaries agree with gameplay behavior. Each ability remains identifiable when multiple effects overlap. Requires the corresponding ability mechanics.

## 8. Player feedback

- [ ] Clear player core/hitbox presentation.
- [ ] Readable invulnerability or protection state.
- [ ] Distinct graze feedback without excessive flashes.
- [ ] Readable energy pickups, attraction, collection, and resource feedback.
- [ ] Ability charge and recovery indicators visible during combat.
- [ ] Screen shake and impact brightness tuned for aiming and dodging.

Acceptance: the player can locate the vulnerable core and understand ability readiness without losing track of incoming threats.

## 9. Mission HUD and transitions

- [ ] Act and wave progress display.
- [ ] Personal-best progress and live clear-time feedback where applicable.
- [ ] Mission entry and launch presentation.
- [ ] Clear wave and act transitions that do not cover active threats.
- [ ] Capital-threat introduction and appropriate status display.
- [ ] Mission completion and defeat presentation consistent with the gameplay style.
- [ ] Safe-area-aware layout and a visible touch pause control.

Acceptance: progress, timing, and warnings remain readable on the intended phone viewport and do not compete with the combat field.

## 10. Verification

- [ ] Capture current Phoenix 2 reference sequences with platform/version noted.
- [ ] Compare matching viewport sizes and representative encounter density.
- [ ] Review consecutive frames, not just screenshots.
- [ ] Check warning-to-damage timing and effect-to-collision alignment.
- [ ] Check effect overlap, edge clipping, ship stability, and contrast.
- [ ] Measure frame pacing at the target frame rate on intended hardware.
- [ ] Check portrait layout, safe areas, and resized desktop windows.

## Recommended implementation sequence

1. Enemy turrets and their visible states.
2. Varied projectiles and lasers with warnings.
3. Shields, localized damage, and component destruction.
4. Formations and environment depth.
5. Player weapon and ability presentation alongside their mechanics.
6. HUD, transitions, and device-level visual validation.

## Implementation plan

Build and verify one complete combat encounter at a time. Visuals must reflect gameplay state: a turret aims, charges, fires, takes damage, and breaks. An animation alone does not complete the feature.

### Step 1: One detailed heavy enemy

- Give the heavy ship two visible turrets with separate health and targeting.
- Add rotating barrels, charge lights, muzzle flashes, and persistent destroyed mounts.
- Add a shield surface, localized hit ripples, and a shield-break transition.
- Use this enemy to establish reusable visual and gameplay components.

### Step 2: Three distinct threats

- Start with dart bursts, a tracking laser, and a splitting missile.
- Give each a recognizable silhouette, trajectory, warning, and impact.
- Keep visible danger aligned with collision geometry and damage timing.
- Show the laser's aiming, lock, charge, active, and cooldown states clearly.

### Step 3: Localized damage and staged destruction

- Attach sparks, fires, and smoke to the struck or disabled component.
- Stage large explosions through ignition flash, component bursts, fragments, and fading smoke.
- Keep surviving turrets and hostile projectiles visible through overlapping effects.

### Step 4: Player weapon treatment

- Replace the electrical packet chain with the connected shaft specified in the detailed visual checklist.
- Implement attack expansion, sustained deformation, surface contact, and release contraction.
- Leave a thin residual line during release, followed by a genuinely empty recovery interval.
- Keep damage timing and muzzle/contact visuals synchronized while either ship moves.

### Step 5: Battlefield composition and depth

- Author formations with escorts, large ships, and deliberate open lanes.
- Separate distant scenery, middle structures, and foreground details.
- Move these layers at different speeds to establish depth and travel.
- Tune contrast and foreground placement around combat readability.

### Step 6: Feedback and HUD

- Clarify the player core, energy collection, and ability readiness/recovery.
- Add readable wave progress and threat warnings.
- Keep large banners clear of active combat and account for phone safe areas.

## Code and asset approach

Extract responsibilities from `main.gd` incrementally as the first encounter is built:

| Component | Responsibility |
|---|---|
| Enemy | Hull/shield state, movement, turret mounts, overall destruction |
| Turret | Targeting, charge/fire/cooldown state, local health, disabled visuals |
| Projectile or hazard | Trajectory, collision, warning/active lifetime, splitting behavior |
| Weapon effect | Muzzle, shaft or projectile presentation, surface impact, release |
| Encounter definition | Formation layout, enemy loadouts, entrance and wave timing |

Use sprites for detailed artwork, shaders for shields and energy surfaces, and particles for short-lived sparks and debris. Keep gameplay state authoritative so effects cannot continue firing after their turret has been destroyed. This is a proposed architecture, not an assertion about Phoenix 2's implementation.

## First playable milestone

One polished heavy-enemy encounter containing:

- [ ] Two independently destructible, visibly aiming turrets.
- [ ] Shield hit feedback and a clear shield-break transition.
- [ ] Dart fire and a tracking laser with a readable warning sequence.
- [ ] Localized damage and persistent destroyed turret mounts.
- [ ] A staged final explosion that preserves projectile visibility.

Verify before expanding the roster:

- [ ] Capture the encounter at the intended phone viewport size.
- [ ] Confirm a destroyed turret immediately stops firing while the carrier can survive.
- [ ] Confirm laser warnings precede damage and show the eventual dangerous area accurately.
- [ ] Check that shield, hull, and turret hits are distinguishable during normal-speed play.
- [ ] Review consecutive frames for timing, alignment, clipping, and flicker.
- [ ] Measure frame pacing during maximum effect overlap on target hardware.

The splitting missile, expanded environments, and additional ships follow this milestone. Completion means one verified encounter, not full visual parity.

## References

- [Full feature gap analysis](PHOENIX2_FEATURE_PARITY.md): broader mechanics, content, and implementation dependencies.
- [Detailed visual acceptance checklist](PHOENIX2_VISUAL_FEATURES.md): sampled electrical weapon, framing, and capture requirements.
- [Phoenix 2 turret guide](https://gamefaqs.gamespot.com/iphone/193681-phoenix-ii/faqs/76704/invader-turrets): component targeting and destruction.
- [Phoenix 2 weaponry guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/invader-weaponry): hostile weapon families.

Community guides establish feature categories; they do not replace direct verification of the current game's visuals.
