# Shield energy reference: September 24 clip

Source: `Phoenix2_2026-09-24-08-13-36_run.mov`, uploaded by the user.
Decoded 264 native frames at 884×1920, approximately 4.4 seconds. Native timestamps
are in `visual-reports/shield-energy-reference/frames/frames.json`. These observations
come from selected frames and the first-second sequence, not a measurement of every
pickup's energy value.

## Visible behavior

- Small cyan/white energy particles converge toward the moving player ship.
- Six purple outlined charge markers follow the ship, in two columns of three.
- At 0.000 seconds, the bottom-left marker is illuminated. Around 0.150 seconds,
  the next marker above it lights with an expanding purple ring; by 0.300 seconds,
  two markers have settled into persistent bright cores.
- Filled markers have layered hexagonal outlines, a bright patterned center,
  violet bloom and a thin horizontal flare. Empty markers remain faint outlines.
- The ship continues moving and firing during collection. The markers communicate
  stored ability charges; the clip does not establish a Personal Shield charging
  sequence or the exact energy required for each charge.
- Explosions and weapon glare obscure some later markers; do not infer exact
  pickup-to-charge ratios or the complete filling order from this short clip.

First-second contact sheet: `visual-reports/shield-energy-reference/charging-sequence.jpg`.

## Differences in our implementation

- We already credit Aura energy on pickup arrival, but collection removes the
  particle without a dedicated charge-completion pulse.
- Our Phalanx profile exposes two small hexagons below the ship, not the six large
  flanking markers visible here. Guardian instead uses the corner energy gauge.
- Our markers only switch outline brightness. They lack the reference's luminous
  center, animated completion ring and horizontal flare.
- Our pickup rendering is a generic green-white glow, rather than the visible cyan
  particle stream. Exact trajectory/speed matching requires tracking particles.

Next implementation target: match the clip's charge-display layout and completion
feedback, keep collection credit tied to arrival, and select a compatible six-charge
loadout explicitly. Do not silently turn the Personal Shield Zen into an energy
ability or claim all shield types use this counter display.

## Implemented after user clarification

The user confirmed each shield activation spends one purple circle. The default
loadout now has six stored charges and no separate release-to-charge Personal
Shield. Charge markers flank the ship, with a pulse when collection completes a
charge. One activation spends exactly one circle, retains fractional energy, and
never triggers from collection alone. Activation geometry is still the existing
forward arc; this clip only establishes collection and charge presentation.
