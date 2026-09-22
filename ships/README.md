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
