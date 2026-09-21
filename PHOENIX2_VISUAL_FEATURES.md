# Phoenix 2 Visual Match — Feature List

This checklist records the visual behavior observed in the Phoenix 2 reference footage and screenshot. It is the acceptance specification for the demo rather than a list of loosely similar effects.

Reference video: [Official Phoenix 2 weapons clip](https://video.fastly.steamstatic.com/store_trailers/2678070/797799/ccfeab03628337da155e49dfa6f63673d43cdafd/1750818537/microtrailer.mp4)

## 1. Electrical beam weapon

### Firing lifecycle

- [ ] Use explicit `idle`, `attack`, `sustain`, `release`, and `recovery` phases.
- [ ] Start almost instantly: reference changes from off at about `2.685 s` to a complete beam at about `2.744 s`.
- [ ] Keep the active beam visually continuous through the sustain phase.
- [ ] Begin a visible collapse by about `2.921 s` in the sampled reference sequence.
- [ ] Finish the collapse and become fully clear by about `3.010 s`.
- [ ] Leave a clearly visible empty pause before the next shot.
- [ ] Keep timing delta-time based so behavior does not change with frame rate.

### Continuous shaft

- [ ] Render one connected energy shaft from the ship to the hit point.
- [ ] Do not use separated bullets, packets, dashes, or dark gaps during the active phase.
- [ ] Use a narrow white-hot core for the full length of the shaft.
- [ ] Surround the core with a bright cyan inner layer.
- [ ] Add a softer blue outer glow without making the beam blurry.
- [ ] Give the shaft slight lateral instability and gentle bends rather than a perfectly rigid line.
- [ ] Keep the beam narrow enough that its animated structure remains readable.

### Dynamic internal shape

- [ ] Build repeating V-shaped, feather-like, or lightning-like energy structures along the shaft.
- [ ] Connect those structures to the central core; they must not read as individual projectiles.
- [ ] Continuously open, close, stretch, and deform the structures while firing.
- [ ] Move the energy pattern upward toward the target.
- [ ] Vary spacing, width, angle, and brightness along the beam.
- [ ] Avoid obvious repeated glyphs or evenly spaced identical shapes.
- [ ] Blend neighboring shapes so the entire beam reads as one changing electrical body.

### Muzzle behavior

- [ ] Emit a wide fan of white and cyan rays from the ship's nose during attack.
- [ ] Make the fan broader and brighter on the first firing frames.
- [ ] Narrow and stabilize the fan during sustain.
- [ ] Retract the fan during release instead of switching it off in one frame.
- [ ] Keep the beam, fan, and ship muzzle aligned while the ship moves.

### Target impact

- [ ] Place a large white-blue contact bloom exactly where the beam reaches the enemy.
- [ ] Add short blue radial rays and electrical particles around the contact point.
- [ ] Layer orange fire, hot fragments, and sparks over the blue energy impact.
- [ ] Make the contact effect track the enemy surface rather than a fixed screen position.
- [ ] Synchronize impact intensity with attack, sustain, and release phases.

### Release behavior

- [ ] Collapse the feather structures before removing the central beam.
- [ ] Briefly leave a thin blue residual line after the white core contracts.
- [ ] Reduce the muzzle fan and impact bloom at the same time.
- [ ] Remove all residual light before recovery ends.
- [ ] Ensure the next firing cycle begins from a genuinely empty frame interval.

### Current implementation status

- [ ] Replace the current separated packet-chain treatment.
- [ ] Replace per-packet morphing with deformation across one connected shaft.
- [ ] Remove uniform packet spacing and repeated static symbols.
- [ ] Strengthen the continuous core from muzzle to impact.
- [ ] Make the release visibly contract into a thin residual line.

## 2. Ship scale and framing

Measurements are based on the supplied `589 × 1280` iPhone screenshot.

- [x] Player ship target size is approximately `148 × 154` logical pixels.
- [x] Standard enemy target size is approximately `134 × 172` logical pixels.
- [x] Spinner enemy target size is approximately `140 × 180` logical pixels.
- [x] Heavy enemy target size is approximately `174 × 190` logical pixels.
- [x] Muzzle, weapon, shield, and thruster offsets scale with the enlarged ships.
- [ ] Verify the apparent sizes on an actual iPhone viewport, including safe-area scaling.
- [ ] Preserve enemy spacing and negative space seen in the reference composition.

## 3. Background and environment

- [x] Use a high-resolution amber-and-teal megastructure background plate.
- [x] Preserve the source aspect ratio while covering the portrait viewport.
- [x] Add restrained background drift for depth.
- [x] Remove cheap-looking procedural rectangles and rails.
- [ ] Match the reference's large foreground machinery scale and strong depth layers.
- [ ] Keep the center combat lane readable without making the environment flat or empty.
- [ ] Tune local contrast so bright cyan weapons remain clear against teal machinery.

## 4. Rendering and animation quality

- [x] Target `120 FPS` with `120` physics ticks per second.
- [ ] Verify motion with consecutive-frame captures rather than judging a single screenshot.
- [ ] Eliminate ship flicker caused by alternating visibility, z-order, or unstable transforms.
- [ ] Use delta-time animation for movement, particles, beam phases, and shader motion.
- [ ] Keep sprite filtering, texture resolution, and viewport scaling sharp on Retina displays.
- [ ] Avoid resolution-dependent line widths and particle sizes.
- [ ] Confirm that glow does not clip at the viewport edge or ship bounds.

## 5. Acceptance criteria

- [ ] At normal speed, the weapon reads as a continuous braided electrical lance.
- [ ] No active frame reads as a dashed line or a chain of separate bullets.
- [ ] Internal feather shapes visibly change between consecutive frames.
- [ ] The firing start has a strong muzzle expansion without hiding the ship.
- [ ] The target impact combines blue-white energy with orange fire and sparks.
- [ ] The release visibly becomes thinner before it disappears.
- [ ] A brief empty pause is obvious between firing cycles.
- [ ] Player and enemy ships match the screenshot's apparent scale.
- [ ] The ship remains stable and does not flicker during firing.
- [ ] The effect remains smooth at the target frame rate on an iPhone-sized viewport.
- [ ] A side-by-side frame comparison is completed for attack, sustain, release, and recovery.

## 6. Validation captures

For every iteration, record or capture these four states at the same viewport size:

1. Attack: first frame with a complete beam.
2. Sustain: beam with clearly changed internal morphology.
3. Release: feather structures gone or collapsing, with a thin residual line.
4. Recovery: beam, muzzle fan, and impact light fully absent.

Do not mark the beam complete based only on a still image; the defining feature is how its connected shape changes over time.
