# Starfall Protocol

An original one-mission vertical bullet-hell demo for Godot 4.7, inspired by the fluid controls, short score-attack structure, ability-driven survival, and escalating enemy patterns of modern arcade shooters.

## Play

Open `project.godot` in Godot and press **F6/F5**, or run the project from the editor.

- Move: drag, mouse, WASD, arrow keys, or left stick
- Pulse field: hold the lower-left button, Space, or left shoulder
- Nova: press the lower-right button, E, Enter, or right shoulder when charged
- Pause: Escape
- Heavy-enemy trial: F2, or click/tap the trial entry at the bottom of the title screen
- Return to title: F1
- Controller: A/Start launches or retries; Start pauses/resumes
- Weapons fire automatically; press **V** to switch between the electrical lance and twin blue shots

Pulse consumes cyan energy and destroys nearby hostile projectiles. Grazing shots, destroying enemies, and collecting energy shards charge the orange Nova. Nova clears the screen and damages every enemy.

The demo contains three escalating formations and one boss wave. It uses original AI-generated ship and VFX artwork combined with Godot-native HDR lighting, projectile trails, parallax scenery, damage fires, smoke, sparks, shockwaves, UI, enemy patterns, and synthesized sound. No third-party game assets are included.

Asset-generation provenance and prompts are recorded in `ASSET_NOTES.md`.

## Mission visual implementation

Heavy ships now have an energy shield and two independently destructible turrets. Aim at the side mounts after breaking the shield to disable dart fire or the tracking laser. Dashed laser boundaries show the warning path; it locks before becoming a solid damaging beam. Pulse clears bullets, including unsplit missiles, but does not block lasers. Exhausted Pulse must recharge to 25% before reactivation.

Spinner enemies also launch pink missiles that announce their arming state before splitting. The player weapon is a connected electrical beam with an attack fan and residual release line. Damaged mounts, shield fragments, delayed destruction bursts, peripheral parallax machinery, a live timer, wave markers, and a touch pause button complete the first visual pass. Dragging now uses relative movement.

F2 starts an isolated heavy encounter with a stronger hull so there is time to inspect and disable both turrets. Retrying preserves this trial. You can also launch with `-- --encounter` after Godot's project arguments.

Weapon energy uses an additive layer above hulls and below hostile threats and the HUD. The lance has open moving feathers, a directional muzzle fan, a radial contact bloom, and a contracting blue residual. Hull impacts shed orange fire and hot fragments. Shield breaks add blue-white energy bursts; Nova adds a growing pink-white core with radial rays and a translucent shell. Explosions combine a 65 ms ignition glow, optical streaks fading over 0.22 seconds, and a translucent expanding shell lasting 0.42 seconds. See [the reference review](BEAM_VISUAL_REVIEW.md) for evidence, remaining acceptance gaps, and the full-cycle capture command.

### Validation

Fire uses an age-driven procedural shader with hot cores, orange edges and cooling smoke. Damaged hulls and destroyed mounts emit flames that initially follow the moving source, then detach. Burning fragments follow curved, slowing trajectories and leave a sampled, tapering trail along their path. Trails keep at most 12 points and sample at a fixed interval. After the fragment cools, its smoke path expands and fades for up to another 550 ms. Fire light draws below hostile bullets and the HUD. To capture every frame of the three-second effects fixture, run `godot --path . --audio-driver Dummy --script tests/capture_fire.gd`; 181 images and a timing manifest are saved under `visual-reports/fire/`. Open `tools/fire_review.html` to pair these with local reference images. See [fire frame matching](FIRE_FRAME_MATCH.md) for the uploaded reference, exact-timestamp capture commands, and remaining visual gaps; a full match has not been verified.

For the automated GUT suite and enforced **95% executable-line coverage** gate, use Python 3.12 and Godot 4.7.2:

```sh
python3 -m venv .venv-test
.venv-test/bin/pip install -r requirements-test.txt
GODOT_BIN=/path/to/godot .venv-test/bin/python tools/run_tests.py
```

The runner downloads GUT 9.7.0 on first use, caches test dependencies, and imports/runs a temporary project copy. It leaves the normal game configuration unchanged. A failing test, missing production script in the coverage plan, or total line coverage below 95% causes a nonzero exit. All production GDScript, including rendering, is measured; tests and the two testing addons are excluded. Reports are regenerated under `coverage/`: `index.html`, `summary.json`, `results.xml`, and `run.log`.

The suite combines focused behavior tests with scene integration and actual draw callbacks: mission completion, shields/turrets, collision and grazing, abilities, pickups, input methods, pause/retry, audio generation, and rendering without combat-state mutation. Line coverage measures execution, not exhaustive branch combinations or screenshot fidelity; Phoenix 2 visual matching and device testing still require visual review.

With Godot 4.7 installed, run from the project directory:

```sh
godot --headless --path . --audio-driver Dummy --script tests/combat_test.gd
godot --path . --audio-driver Dummy --script tests/capture_visuals.gd
```

The combat suite exercises shields, targeting, turret cancellation, laser damage, bullet clearing, Pulse depletion, missile splitting, relative input, weapon timing at 30/60/120 FPS, and normal mission progression. The rendering script requires a graphical session and saves diagnostic state captures to `/tmp/starfall-captures`. These are controlled state samples, not a reference-matched gameplay recording. Actual iPhone safe-area and performance validation remain pending.

## Reference and roadmap

- [Mission-play visual checklist](MISSION_VISUAL_CHECKLIST.md): battlefield visual gaps, priorities, and acceptance criteria.
- [Full Phoenix 2 feature gap analysis](PHOENIX2_FEATURE_PARITY.md): researched systems inventory, current implementation gaps, and development milestones.
- [Visual acceptance checklist](PHOENIX2_VISUAL_FEATURES.md): detailed weapon and presentation requirements.
