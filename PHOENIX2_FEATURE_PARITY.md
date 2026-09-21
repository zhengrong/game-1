# Phoenix 2 — full feature gap analysis

Research date: 2026-09-21. Local baseline: Starfall Protocol in this repository.

The local inventory below records the pre-implementation research baseline. Subsequent combat and visual changes are tracked in [the mission visual checklist](MISSION_VISUAL_CHECKLIST.md), including turrets, shields, laser hazards, splitting missiles, and the connected beam.

This expands [the visual checklist](PHOENIX2_VISUAL_FEATURES.md) into a product and gameplay inventory. It records research, not completed implementation. Research used official descriptions/release notes and community mechanics guides; it did not include a hands-on session in Phoenix 2. Exact current balance, timings, UI flows, and every ship/mod combination still require direct verification.

## Target and evidence

Use the current game as the product target. The iOS listing inspected reports version 8.3. Version 8.0 introduced collectible ship mods and replaced existing ultimate upgrades with mods; later notes mention mod rarities, Engrams, mod purchasing, Traces conversion, and revised controller options. Older guides' ultimate-upgrade tables cannot be treated as current specifications. Current release notes also use “Counter”; older guides use “Zen.” Verify the present naming and controls before finalizing UI. [Official release notes](https://apps.apple.com/us/app/phoenix-2/id1134895689)

Evidence labels:

- **Official:** developer site, store description, or developer release notes.
- **Guide:** community mechanics documentation; useful for feature discovery, provisional for current rules.
- **Local:** direct inspection of this repository.
- **Proposal:** our implementation/acceptance plan, not a claim about Phoenix 2 internals.

“Missing” means no corresponding local implementation was found. “Partial” means we have a related effect or mechanic, not verified parity. An unchecked validation task does not prove a visual defect.

## 1. Current local baseline

The game is one scene, with almost all behavior in `main.gd`:

| System | Local implementation | Status against broader target |
|---|---|---|
| Player | One fixed ship, keyboard/mouse/touch/stick movement | Partial |
| Main weapon | Hitscan damage with separated electrical packet visuals | One weapon only; visual checklist also unmet |
| Abilities | Held Pulse clears nearby bullets; Nova clears screen and damages enemies | Custom substitutes |
| Survival | Three HP, temporary invulnerability, no enemy-contact damage | Different rules |
| Enemies | Scout, spinner, heavy, one boss; one HP pool per enemy | Partial |
| Hostile fire | Aimed shots, fans, radial patterns; circular projectile collision | Partial |
| Missions | Three formation waves followed by a boss | Demo only |
| Score | Kill/graze/clear/pickup points and a combo multiplier | Custom rules |
| Presentation | Textured ships, one backdrop, HDR/glow, sparks/fire/smoke | Partial; device/frame validation pending |
| Audio | Six synthesized event sounds | Basic |
| UI | Title, HUD, pause, defeat/victory panel | Basic |
| Persistence/services | No save system, inventory, account, missions service, or leaderboard | Missing |

Local anchors: `_update_player`, `_query_beam_hit`, `_spawn_wave_enemy`, `_update_boss`, `_damage_player`, `_try_nova`, `_check_wave_complete`, `_unhandled_input`, `_draw_ui`, `_build_audio`.

## 2. Combat feel and input

Guide baseline: relative touch preserves the ship's position when a finger is lifted and placed elsewhere. A second touch triggers Aura; releasing touch charges Zen. Certain abilities trigger automatically, others on returning to active control. Core contact with hostile bullets/lasers is lethal; the decorative hull is not the collision body. Controller and mouse/keyboard schemes provide equivalent combat actions. [Controls guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/basics)

Missing or different locally:

- [ ] Relative drag instead of chasing an absolute pointer position plus a fixed offset.
- [ ] Separate active-piloting and ability-charging states, including firing restrictions.
- [ ] Ability-specific cancel, release, and repeat behavior.
- [ ] Core-only lethal bullet/laser rules, if matching the reference survival model.
- [ ] Hazardous turret contact; currently enemies cannot hurt the player by contact.
- [ ] Full controller navigation from launch through retry and pause.
- [ ] Input settings and a visible touch pause control.

Proposal: test finger repositioning, simultaneous touches, controller disconnect, focus loss, pause, and charging interruptions. Measure input latency and collision behavior at multiple frame rates. Preserve the current three-HP mode only as an explicitly separate assist/demo mode if desired.

## 3. Ships, weapons, and defenses

The developer describes roughly 100 collectible ships, distinct main weapons, two special abilities per ship, upgrades, and Apex variants. This is a content system, not just a skin selector. [Developer overview](https://firigames.com/phoenix2)

Guides describe High Impact, Shield Breaker, and Armor Piercing weapon affinities. Their effectiveness differs against hull, shields, and armor. [Ship mechanics](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/ships)

- [ ] Ship catalog, ownership, selection, preview, and ability descriptions.
- [ ] Distinct weapon families: direct shots, spreads, bursts, beams, tracking/homing fire, explosive and piercing attacks.
- [ ] Per-weapon timing, targeting, damage affinity, firing origin, visuals, and sound.
- [ ] Separate enemy hull/shield/armor treatment and readable feedback.
- [ ] Ship upgrades and Apex selection.
- [ ] Current mod inventory and equip flow; compatibility and stacking rules.
- [ ] Content coverage ledger for every ship, weapon, ability pair, and variant.

Proposal: first build six original ships that exercise different weapon and ability behaviors. This is a development milestone, not full roster parity. Keep stats and equipment in data resources so expanding the fleet does not require adding another branch to a giant script.

## 4. Ability coverage

The older Aura catalog includes Bullet EMP, Stun EMP, Barrier, Laser Storm, Missile Swarm, Point Defense, Chrono Field, Vorpal Lance, Phalanx, Ion Cannon, Goliath Missile, and Blade Storm. It includes radius-based energy use and stored-charge abilities; kills and grazing contribute energy. Our fixed-radius held Pulse does not reproduce that system. [Aura guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/auras)

The older Zen catalog includes Kappa Drive, Mega Laser, Mega Bomb, Teleport, Reflex EMP, Personal Shield, Focus Lance, Clover ATS, Tracking Minigun, and Nightfury. Our Nova approximates a broad blast effect but lacks this charge/recovery system. [Zen guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/zens)

All these ability families need tracking; exact current counts and mod-dependent variants remain unverified.

| Behavior to implement | Local coverage |
|---|---|
| Bullet clearing | Partial: Pulse and Nova |
| Turret stun/interrupt | Missing |
| Barriers, shields, laser reflection | Missing |
| Local time manipulation | Missing |
| Teleport and destination preview | Missing |
| Energy generation | Passive refill exists; no dedicated ability |
| Homing salvos, lances, large missiles, blades | Missing |
| Charged beam/bomb and sustained special weapons | Nova blast is only a loose analogue |
| Charge, cancel, cooldown, recovery, resource-dependent range | Missing as a general system |
| Upgrade/mod interaction rules | Missing |

Proposal: an ability must specify valid states, targets, costs, timing, interaction with every hazard family, and audiovisual cues. A blue circle is not sufficient evidence of shield parity; demonstrate what it blocks, reflects, fails against, and when it expires.

## 5. Enemies and independently destructible turrets

Guides distinguish small through capital-sized invaders and turret mount points with their own hitboxes/health. Destroying individual turrets removes threats before the carrier dies. Turret collision also matters. [Turret guide](https://gamefaqs.gamespot.com/iphone/193681-phoenix-ii/faqs/76704/invader-turrets)

- [ ] Multiple independently aimable, destructible weapons per enemy.
- [ ] Damage routing between shields, turrets, and hull.
- [ ] Turret charge/fire/recover/stun/destroyed states.
- [ ] Small, medium, large, and capital enemy layouts with different tactical roles.
- [ ] Formation designs where target selection creates safe lanes.
- [ ] Damage visuals tied to disabled components, not just overall HP.
- [ ] Capital encounters built from weapon systems rather than only a large HP pool and pattern switch.

Proposal acceptance: destroy a dangerous turret while leaving its carrier alive; its firing stops immediately and the damage state remains visible. Repeat through shielding, area damage, piercing attacks, and stun recovery.

## 6. Hostile weapons and pattern vocabulary

The guide catalogs darts, pellets, shurikens, boomerangs, normal/speed lasers, pellet/laser/caged MIRVs, and Doomsday laser/bomb/super-MIRV threats. They require distinct counters and readable preparation, not merely different projectile colors. [Weaponry guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/invader-weaponry)

- [ ] Separate projectile shapes and corresponding collision geometry.
- [ ] Tracking and sweeping laser hazards with warning/charge/active/cooldown phases.
- [ ] Curved or returning trajectories.
- [ ] Split-projectile behavior, including proximity-triggered and death-triggered patterns where verified.
- [ ] Large area hazards and heavy weapon telegraphs.
- [ ] Turret tiers, burst sequences, synchronized and staggered patterns.
- [ ] Explicit interactions with clear, block, reflect, stun, teleport, and time effects.

Proposal: maintain a hazard-versus-ability matrix with tests for each supported interaction. Fix collision-array invalidation before adding more hazards.

## 7. Missions, difficulty, and replayability

Official descriptions advertise 30 campaign missions, worldwide shared daily challenges, leaderboards, and large bosses. [Official Steam description](https://store.steampowered.com/app/2678070/Phoenix_2/)

Older guides additionally document acts/waves, rank-dependent daily difficulty, specialist restrictions, mission intel, venue changes, and UTC daily rollover. Current exact rank/reward rules need verification. [Daily mission guide](https://elegater.github.io/Resources/GameFAQs/Daily%20Missions.html)

- [ ] Mission selection and briefing/intel.
- [ ] Campaign progression, tutorials, story presentation, and unlocks.
- [ ] Multiple environments and authored encounter sequences.
- [ ] Seeded daily missions shared across players.
- [ ] Difficulty/rank progression and eligible ship/loadout restrictions.
- [ ] Specialist, community, and VIP mission categories.
- [ ] Multi-act progress display and mission history.
- [ ] Stable retry behavior: same mission definition and enemy patterns.

Local `rng.randomize()` plus hard-coded spawning is not a reproducible daily mission system. Proposal: separate cosmetic randomness from mission/combat randomness, version every mission definition, and freeze a mission's rules for all its attempts.

## 8. Progression, rewards, and the surrounding UI

Current official notes establish mods, Engrams, Traces conversion, VIP missions, custom player tags, wave progress/timing UI, and failed-score-upload retry. Exact costs and acquisition probabilities are not established here. [Official release notes](https://apps.apple.com/us/app/phoenix-2/id1134895689)

Older documentation covers Warp Gate acquisition, revive inventory with act restart/penalty rules, and account-based progress recovery. [Systems guide](https://gamefaqs.gamespot.com/pc/435101-phoenix-2/faqs/76704/basics)

- [ ] Persistent profile, wallet, owned ships, upgrades, equipment, and mission results.
- [ ] Reward grants and claim history that survive restarts.
- [ ] Hangar, ship detail, upgrade, equipment inventory, and shop screens.
- [ ] Warp Gate/reward-opening flow; current mod acquisition and conversion flow.
- [ ] Pilot rank/experience, achievements or badges, and player identity screens.
- [ ] Retry versus revive handling and eligible-mode restrictions.
- [ ] Results showing completion, time, personal best, rewards, and ranking.
- [ ] Tutorial/help and settings screens.
- [ ] Purchase/VIP entitlement handling if targeting commercial feature parity.

Proposal: implement the complete earn → unlock → equip → play → reward → save loop locally first. Record current economy values separately after direct verification; do not use old guide prices as defaults.

## 9. Competition and online services

The developer confirms shared daily missions and community-specific missions. Official listings also describe cross-platform progress. [Developer overview](https://firigames.com/phoenix2) · [App listing](https://apps.apple.com/us/app/phoenix-2/id1134895689)

- [ ] Account/profile and cross-device synchronization.
- [ ] Daily mission delivery and rollover handling.
- [ ] Global and community leaderboards.
- [ ] Progress-based results and clear-time competition, with exact sorting/ties verified.
- [ ] Communities, membership, mission access, and community results.
- [ ] Score submission, error visibility, and retry.
- [ ] Persistent mission log and personal records.

Proposal engineering requirements: validated submissions, duplicate-safe reward/score processing, versioned rules, save conflict handling, and expired-mission behavior. These are our required implementation properties, not verified details of Phoenix 2's backend. The local combo score should not be assumed compatible with its ranking rules.

## 10. Visuals, audio, and platform quality

Keep the detailed beam acceptance criteria in [PHOENIX2_VISUAL_FEATURES.md](PHOENIX2_VISUAL_FEATURES.md). Those describe one reference weapon; not every ship should use that beam.

- [ ] Connected electrical shaft, staged collapse, attack fan, surface impact, and residual light for that weapon.
- [ ] Unique readable silhouettes and effects for each added weapon, ability, turret, and hazard.
- [ ] Shield/armor hits, component explosions, and capital destruction sequences.
- [ ] Several coherent environments with foreground/background depth.
- [ ] UI transitions and feedback for selection, charging, rewards, equipment, and rank changes.
- [ ] Dedicated weapon, ability, warning, impact, engine, and interface audio.
- [ ] Audio mix and dense-action readability review; verify reference music/ambience directly.
- [ ] Portrait/landscape layout, safe areas, and touch/controller/desktop navigation.
- [ ] Measured frame pacing on target devices; 120 FPS configuration alone is not proof.
- [ ] Localization-ready text/layout and device lifecycle handling.

Proposal validation: synchronized captures of identical encounters; attack/sustain/release/recovery frame strips; stress scenes; 30/60/120 FPS simulation checks; reference device size and input-latency checks. Keep original artwork and content identity while measuring equivalent behavior.

## 11. Implementation order

These are proposed milestones, not time estimates or a claim that a small subset equals full parity.

1. **Reliable combat foundation:** fix reviewed collision/Pulse/controller issues; separate input, combat, rendering, and content data; establish deterministic scenario tests.
2. **One representative encounter:** relative input, active/charge states, hull/shield/armor, destructible turrets, bullets/lasers/MIRVs, one offensive and one defensive ability. Prove the tactical loop.
3. **Representative fleet:** six ships, contrasting weapons and ability pairs, hangar selection, clear charge/cooldown UI. Compare actual gameplay footage.
4. **Replayable mission loop:** campaign/tutorial structure, acts, difficulty, seeded missions, intel, results, and local records.
5. **Persistent progression:** wallet, unlocks, upgrades, mods, rewards, save/load, and the associated screens.
6. **Online competition:** accounts, shared daily missions, score validation/submission, leaderboards, and communities.
7. **Complete content and platform coverage:** remaining fleet/abilities/hazards/environments, current variant rules, economy/entitlements, localization, and device validation.

Visual/audio work accompanies each milestone. Deferring it entirely would hide important readability and timing problems.

## 12. Remaining research before claiming “everything matches”

- [ ] Directly inspect the current version's menus and representative gameplay; retain platform/version/date with observations.
- [ ] Inventory every current ship, weapon, ability pair, Apex, and mod; separate new entries from older guide material.
- [ ] Verify current Aura/Counter/Zen terminology and control schemes per platform.
- [ ] Measure movement, hitboxes, projectile timing, charging, invulnerability, and resource rules.
- [ ] Verify score ordering, revive penalties, ranking, daily rollover, and reward eligibility.
- [ ] Capture the full mod/Engram/Traces workflow and exact equip/stacking constraints.
- [ ] Confirm current mission categories, campaign gates, VIP entitlements, and platform differences.
- [ ] Capture HUD, hangar, upgrade, reward, mission, profile, settings, and results flows.
- [ ] Record audio and consecutive-frame references, not just promotional stills.

This is a broad systems inventory and implementation roadmap. It is not yet a complete measured specification of every piece of current content. The largest gap is the missing tactical combat and progression systems, not another particle effect.
