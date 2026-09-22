# Electrical-lance reference review

Target confirmed by the user: the existing Phoenix 2 beam reference, including its firing cycle and surrounding impact effects. A larger flare alone does not meet this target.

## Reference evidence

- Existing [official weapons microtrailer](https://video.fastly.steamstatic.com/store_trailers/2678070/797799/ccfeab03628337da155e49dfa6f63673d43cdafd/1750818537/microtrailer.mp4), with the sampled timestamps recorded in `PHOENIX2_VISUAL_FEATURES.md`.
- The direct MP4 failed to decode in this session's browser. The full **Phoenix 2 — Different ships, different weapons** trailer on the [official Steam page](https://store.steampowered.com/app/2678070/Phoenix_2/) played successfully. The electrical lance is visible around 47–52 seconds. Paused and playing frames were inspected there.
- Observed: open feathers swept toward the enemy, a broad directional muzzle fan, a continuous blue shaft with a narrow bright center, strong blue-white surface contact, orange fire/fragments, and a clear off interval. Explosion streaks differ from the weapon's directional fan.

## Implementation and verification

- Replaced uniformly repeated closed triangles with irregularly spaced, asymmetric, upward-moving open feathers. Every feather attaches to a continuously deforming shaft.
- Shared time envelope for attack, sustain, release and recovery. The feathers collapse before the white core; a thin blue line remains briefly, then disappears. Active time is 270 ms with a 135 ms recovery interval, tuned from the existing sampled timing notes. This is a tuning choice, not a new frame-accurate measurement of the original.
- Separate directional muzzle fan, radial surface contact, and optical explosion flare. Contact adds warm fire and traveling hot fragments only after a shield is gone.
- Added explicit background → hulls/particles → additive energy → hostile hazards/HUD layers. Impact light remains visible on hulls, while threats and interface draw above it.
- Reduced whole-hull hit overexposure so localized contact does not erase ship detail.
- Unit checks cover phase ordering, endpoints, temporal deformation, empty recovery, draw order, and consistent damage cadence at 30/60/120 Hz. Rendering tests still exercise actual draw notifications.
- `tests/capture_beam_cycle.gd` captures 50 successive simulation frames at 120 Hz into `visual-reports/beam-cycle/`, at 589 × 1280. `frames.json` records timing and phase for each frame.

## Reproduce the review

```sh
godot --path . --audio-driver Dummy --script tests/capture_beam_cycle.gd
```

Open `tools/beam_review.html` in a browser after capture. It includes attack, sustain, residual and recovery frames plus a motion player and frame scrubber. Generated images are ignored by Git and excluded from test staging.

## Acceptance remains visual

The implementation has been compared against the official trailer's observed behavior, but a full frame-aligned match is **not certified**. The new sequence captures are our own renderer, not reference frames. Exact feather morphology, flare luminance and color grading require aligned reference frames at the same scale; the project also retains its own ships and amber environment. Passing tests and high line coverage do not close those visual differences. Phone performance remains unmeasured.
