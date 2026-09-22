# Fire frame matching

Status: uploaded reference decoded; first reference-guided renderer revisions implemented; exact-time capture in use. Full visual matching remains incomplete.

## Source evidence

The user supplied `Phoenix2_2026-09-21-07-35-17_run.mov`. It contains 884 × 1920 video. Decoding yields 125 presented frames from 0.000000 through 2.076667 seconds. Preserve the actual presentation timestamps: observed intervals are 15, 16.667, 18.333 and 25 milliseconds. The container average rate is not an exact frame clock.

The opening explosion is already active, so it cannot establish an ignition time. The selected later ship impact first appears in decoded frame 56 at 0.941667 seconds. Frame 55 still shows the incoming projectile. Reference frames 56–124 give 69 consecutive comparison frames spanning 1.135 seconds after impact. The clip ends while hull fire remains visible; it does not establish extinction time.

Observed sequence (timestamps refer to the uploaded clip):

| Frame | Time | Observation |
|---|---|---|
| 55 | 0.925000 s | Projectile approaches the lower ship; pre-impact hull visible. |
| 56 | 0.941667 s | Broad white impact over the hull. |
| 60 | 1.010000 s | Warm circular envelope becomes visible around the bright impact. |
| 63 | 1.058333 s | Expanding rim with irregular yellow-orange combustion over the hull. |
| 69 | 1.160000 s | Fire spreads over the upper hull; circular envelope fades. |
| 75 | 1.260000 s | Sustained, broad yellow-white flame with orange peripheral billows. |
| 93 | 1.558333 s | Hull fire continues while another nearby impact overlaps the scene. |
| 124 | 2.076667 s | Fire remains at the clip boundary. |

The warm ring is an observed impact effect; the footage alone does not establish its underlying gameplay mechanic or original rendering implementation.

## Implemented revisions

- Procedural low-frequency flow replaces the repeated static, grainy fire texture for flame bodies and hot fragments. Flame shapes evolve with particle age; the shader does not use wall-clock `TIME`.
- Explosion bodies expand radially, with a broad white-yellow core and orange boundaries. Hull flames retain an upward direction.
- A fading warm impact shell expands independently of the fire. It now has a thin pale rim, a broad translucent edge, and a faint interior wash instead of stacked line arcs. Its radius was reduced by 20% after comparing the early paired frames.
- A separate 65 ms white ignition glow precedes the warmer 220 ms optical flare and 420 ms expanding shell. These initial timing choices follow the observed ordering; exact brightness and morphology are still not fitted.
- Damaged hulls emit at two stable local vent locations. Severity changes their size and emission cadence. Fresh flame billows follow their emitting hull or turret for 280 ms, then detach and drift. Removing the source releases the attachment immediately.
- Burning fragments now follow analytically integrated, curved deceleration paths, with ripples and tapering along their trails. Position consistency is tested at 30/60/120 Hz.
- Hull flames have a narrow base, broader upper lobes and a gently varying lean. Reviewing all 69 paired-frame tiles showed that the previous sustained burn stayed too circular; the new taper specifically addresses that discrepancy. The orange-yellow boundary remains irregular.
- Fragment smoke retains the sampled path after the hot head expires, then disperses for up to 550 ms. Smoke age remains continuous through that transition, and long updates cannot resurrect expired particles.
- Cooling fire develops irregular boundary tongues and small gaps; hull smoke uses three drifting lobes. These aftermath choices are tuning decisions: the supplied clip ends before the main hull fire goes out.
- Added blue-white energy impacts and slower-growing pink-white bursts, with fine radial rays and matching translucent shells. Normal gameplay uses blue on shield breaks and pink on Nova; those mappings are adaptations, not claims about Phoenix 2 mechanics. The helper changes presentation only and consumes no gameplay randomness.
- The fire material uses a separate HDR canvas below hostile projectiles and HUD. Flame bodies now alpha-composite; optical flares remain additive.

## Reproduce

```sh
.venv-test/bin/pip install av pillow
.venv-test/bin/python tools/extract_reference.py /path/to/uploaded.mov
# GPU renderer required:
godot --path . --audio-driver Dummy --script tests/capture_fire.gd -- --reference
.venv-test/bin/python tools/build_fire_review.py --video
```

Open `visual-reports/fire-reference/review.html`. Each pair uses an actual source timestamp; playback follows those timestamps rather than assuming a constant frame rate. The generator checks all 69 timestamp mappings and rejects missing images. Reference images remain local, outside Git, and are not game assets.

The reference-mode fixture renders at 589 × 1280, approximately two-thirds source scale, with impact centered at (263, 567). It retains this project's heavy ship and background. It exercises sustained hull fire, an initial blue impact, and a pink overlap introduced at pair 18 (about 0.302 seconds) at (350, 680). The secondary event is an approximate visual reconstruction, not a replay of Phoenix 2 mechanics. It now launches real twin projectiles at pairs 0, 17, 34 and 51 and runs their hit logic. This is an initial cadence reconstruction; the source ship path, other enemies and exact original weapon behavior still differ. The default capture mode remains a separate 181-frame, 60 Hz fixture; earlier captures are historical baselines, not the latest renderer.

## Acceptance gaps

Verification: all 31 tests passed; 12 production scripts were accounted for with 99.33% line coverage. The runner now rejects script/shader errors even when the test framework returns success. All 69 rendered PNGs passed integrity/dimension checks, every pair passed timestamp validation, and viewer first/next/final navigation was checked. GPU captures were inspected through ignition, expansion and sustained burn. Code coverage does not establish shader appearance or mobile performance.

Timing alignment of the capture is not proof of visual equivalence. The remaining visible differences include hull coverage and silhouette, source encounter movement, exact fragment trajectories and matching the smoke density to the footage, exact secondary-hit size/position, exact paired-shot trajectories and timing, smoke, background illumination and color grading. Ring size, alpha and duration are initial tuning values, not fitted pixel measurements. Exact ignition morphology and brightness still require iteration against the paired sequence.

To close these gaps, use one fixed spatial alignment across the sequence, compare fire regions rather than whole-screen pixel scores, and log remaining silhouette, luminance and trajectory errors for every frame. Do not independently reposition each frame to conceal drift. Review motion and hostile-projectile readability as well as stills. Unit coverage and successful shader compilation cannot certify a match, and mobile performance remains unmeasured.

## Latest energy-overlap review

The enlarged pink-white core is closer in scale to the clip than the first star-like version. Remaining issues: source event positions and timing are approximate; paired blue projectiles are now implemented, but their shape and cadence remain approximate; the pink core is still more circular and uniform; projectile contrast is now corrected by moving threats to a separate foreground CanvasLayer, with the interface on a higher layer. At the inspected crossing in pair 40, a red capsule remains saturated red over the white-pink core; the saved projectile-contrast.jpg shows the before/after crop.

## Twin shots and foreground compositing

Press V in normal play to select the twin-shot profile. It emits two blue-white blades with electric tails, at 44 px separation and a 280 ms interval. Initial speed is 2100 px/s. These are tuning values, not exact measurements of the original. Swept collision chooses the nearest surface, respects shields/turrets and avoids tunneling during large updates. Damage tuning has not been balance-tested.

Hostile projectiles use CanvasLayer 1 and the interface uses layer 2, outside the world environment canvas limit of 0. See [Godot glow/canvas documentation](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html) and [segment-circle collision documentation](https://docs.godotengine.org/en/4.4/classes/class_geometry2d.html). Captures, not layer numbers alone, determine whether contrast is acceptable.

## Fire compositing correction (September 22)

The former additive flame bodies clipped overlapping hull fire to a nearly solid
white patch. Fire bodies now alpha-composite HDR emission, retaining orange folds
and yellow channels as billows overlap. Only the hottest local regions approach
white; the separate ignition and optical-flare pass still provides the brief
impact flash. The optical-flare canvas now draws after the fire canvas so opaque
flame bodies cannot cover ignition. Advected channels and cooling folds shape the interior as well as
the silhouette. This is a renderer correction, not a new gameplay effect.

The blast shell now has a broader, dimmer rim with subtle spatial variation.
Background modulation was reduced from (0.82, 0.86, 0.90) to (0.55, 0.66, 0.74),
giving combat effects more contrast without changing the background asset.
Enemy bullets remain in their protected foreground layer.

Use `tools/review_fire_detail.py` after the reference capture to produce a fixed
crop contact sheet and white-pixel diagnostic. It expects saved baseline frames
0/12/30/60 in `visual-reports/fire-before/`; those baseline captures are local
review artifacts, not shipped assets. All rows use the same crop and reference
scale. The white-pixel statistic diagnoses clipping only: lower is not necessarily
closer to Phoenix 2, which also has deliberately saturated highlights.

Remaining differences include the reference's wider, asymmetric flame silhouette,
shot and enemy motion, smoke integration, secondary energy-burst shape, ship art,
and environment. This pass does not establish full visual parity or iPhone frame
time.
