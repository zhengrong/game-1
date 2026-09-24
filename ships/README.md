# Player ship configuration

Select the root `StarfallProtocol` node in Godot and assign its **Ship Definition**
property to `ships/interceptor.tres` (the original defaults) or
`ships/bulwark.tres` (a tougher, slower twin-shot example). Both currently use the
existing interceptor artwork. Ship configuration is independent of mission content.

To create another ship, duplicate a definition and make edited nested resources
unique in the Inspector. Shared resources are configuration, not runtime state.

- **Hull:** display name, texture, visual dimensions, collision radius, health.
- **Handling:** movement speed, drag response, spawn/hit invulnerability.
- **Weapons:** initial beam/twin mode, muzzle offset, cadence, beam damage and
  overcharge damage, twin muzzle offsets, damage, speed, radius, and lifetime.
  Twin offsets are relative to the ship muzzle. The V key still switches modes.
- **Engines:** arbitrary local exhaust positions, color, size, emission interval.
- **Abilities:** pulse radius/capacity/drain/recharge/restart threshold, nova
  capacity/initial charge and damage against ordinary enemies and bosses.
- **Audio:** hit and nova sound keys from the existing sound bank.

`select_ship(definition)` is the runtime selection API. It restarts the mission,
clears projectiles/effects, applies the selected default weapon mode, and resets
health/energy/cooldowns. Ordinary retries keep the current weapon selection.
Changing the exported resource in the Inspector applies it at startup. There is
no in-game hangar selection screen yet.

`ShipState` owns health, position, target, invulnerability, ability energy/status,
and the `WeaponCycle`. Reset preserves the cycle object and its signal bindings.
The game exposes forwarding properties for existing combat/rendering callers.
The HUD uses configured hull health and ability capacities; collisions, beam hit
origin, shots, engine rendering and emitted exhaust read the same definition.

Use positive health, capacities, movement response, weapon intervals, and projectile
lifetimes. Keep pulse restart charge within capacity and aimed muzzle positions
inside the intended ship silhouette. Existing ability mechanics are pulse and nova;
adding a different ability algorithm or a new visual style still requires code.
Reward-based energy gains and the beam's procedural visual style remain shared.

Tests cover independent state, independent newly created nested resources, ship
switch/reset, twin shot stats/ports, and offset beam damage. Capture the alternate
loadout with:

```sh
godot --path . --script tests/capture_visuals.gd -- --bulwark
```

Interceptor, Guardian and Phalanx now start with the paired traveling-shot weapon
to follow the uploaded gameplay reference. Bulwark retains its own twin-shot
stats. V toggles the legacy beam for comparison. `default_twin_shots` remains a
per-loadout setting; a freshly authored ShipDefinition can still choose either.

Player shield presentation now uses separate GPU surfaces: a smooth blue Personal
Shield shell, a faint stationary Barrier with a violet boundary, and a thick
forward Phalanx panel. Hit ripples and reflected rays remain separate effects.
Shader animation follows simulation time, including pause. The six-charge Shield profile is the default
loadout; Interceptor remains available for the legacy Pulse/Nova abilities.
Guardian and Phalanx use an 85-unit Personal Shield radius and Phalanx uses a
95-unit forward radius, sized for this project's 148×154 ship art. These are
project scaling choices, not measured Phoenix 2 dimensions. Visual boundaries
use the same radii and arc angle as collision. This is an approximation, not a
verified frame-for-frame match to every Phoenix 2 shield animation.

Legacy Guardian/Phalanx controls and recharge follow the documented Phoenix 2 interaction:
second-finger tap deploys Aura while the original finger keeps control; lifting
the movement finger charges Personal Shield. The HUD reports charging,
protection, and recovery without requiring the player to track penalty math.
Aura regenerates roughly 3.33 energy/second up to a reserve of 10 while piloting,
not during Zen. Barrier needs 30/100 energy. Each Phalanx costs 60 energy (120
capacity for our two-charge profile); grazing gives 2 energy. Enemy drops still
use our mission reward tuning, so complete progression parity is not claimed.
Sources: [Firi controls](https://firigames.com/phoenix2/support),
[Aura energy guide](https://elegater.github.io/Resources/GameFAQs/Auras.html).

The default `charged_shield.tres` is the user's requested single shield ability:
six charges, 60 energy per charge, 360 capacity. Collection alone never deploys
it. A tap spends one charge; holding does not repeatedly spend. Purple markers
flank the ship in two columns of three; completed charges pulse on collection.
This loadout has neither a Personal Shield Zen nor Nova. Its deployed forward
arc is retained as an approximation until activation footage establishes shape.
