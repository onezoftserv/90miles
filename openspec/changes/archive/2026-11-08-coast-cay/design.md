# Design

## Shape

- **The island is data, the scene is generic.** `SandbarIsland` (class name kept; a rename to `IslandLevel` is churn for a later change) has a `layout` setter that rebuilds `built`, `terrain` and `bounds`, so the shell sets the layout before the island enters the tree and `_ready` builds the palms from it. The default is still the sandbar, so every existing test and call site is unchanged. `furnish` skips the workbench when the layout has none, and also places the drinking spots and signs; `beach_raft(integrity)` puts a built raft on the raft site.
- **New layout fields** (data only, defaults keep the sandbar as it was): `chain_family`, `next_island`, `drink_glyph`, `drink_hold_s`, `drink_effects` and `signs` (`IslandSignData`, a `DataPart`: glyph, Spanish and English line). `IslandLayout` reads the drink spots and signs, adds `ROCK` to `WALKABLE`, and gets `landing_cells()`, which is the co-op spawn cells in join order: the layout's `solo_spawn_glyph` is the first of them, so no second landing field is needed and `spawn_points()` (what late joiners use) is already right for the cay.
- **Lagoon and signs are session children** (`DrinkSpot0`, `Sign0`...), placed by `furnish` on every peer at the same path. Interactions only run on the host (or offline), so a `DrinkSpot` applies its effects directly, like a palm; a sign asks the session for a `show_sign` RPC so every peer sees the bubble.
- **Delayed effects live in the meters.** `EffectApplier.apply` hands an effect with `delay_s` to the subject's `SurvivalMeters.delay_effect`; `tick` counts it down and emits `effect_due`, which `PlayerBody` applies with `EffectApplier.apply_now`. Steppable in tests, paused with the game, frozen while a rider waits out of play (their meters do not tick), and a freed body takes nothing.

## Arrival

A session runs one live level (coop-networking, 2026-11-05). `IslandTravel` (a `Node` child of the session, not an autoload) keeps the live island and the wait:

1. A crossing ends on every peer; the shell hands the result to `crossing_ended`, which holds each rider with `IslandArrival.hold` (out of play: hidden, no collision, `left_island`, meters not ticked; collision layers are remembered for landing).
2. `check()` is pure: someone living not held (on the island, or in a crossing, which holds nobody until it ends) is `PLAYING`; living riders waiting and a next island named is `TRAVEL`; otherwise `OVER` (the shell then shows the summary as before). On the host `TRAVEL` queues the travel for after the frame, so it never runs from inside the signal that asked (a death, a removal, a crossing end).
3. The host calls `session.travel_to` (authority RPC, call_local) with the arrivals (peer id to health and energy, read from the host's meters: frozen since the crossing ended, so they are the crossing result) and the sturdiest intact raft's integrity. `travel_to` accepts only the host's own call and a well-formed message, and emits `island_travel_requested`.
4. On every peer `IslandTravel._load` frees the old island and every session child but the session's own nodes (workbench, routes, build site, raft, spots, signs, creature spawner), and on the host the pick-ups and creatures too (the spawners remove them on clients); builds the next island from its layout; sets `session.terrain` and `spawn_points`; fits every camera and ground; lands every player in sorted peer order on the landing cells (`IslandArrival.land` restores collision, terrain, the pin, the swim drain and clears the network history so a remote body does not slide from the sea); then furnishes, beaches the raft and, on the host, places the pick-ups. The shell reconnects its route signal on `island_loaded`.
5. Late joiners and rejoined players: the host's `join_state()` adds `island`, `waiting` and `raft` through `CoopSession.join_extras`; a client's `IslandTravel.follow` builds the same island, beaches the raft and holds the waiting riders, also when their body arrives (spawn or rebind) after the message.

Reconnects fall out of using body state rather than peer-keyed bookkeeping: a waiting rider's body keeps `left_island` when it is rebound to a new peer; a dropped player on the island counts as living on it until the countdown removes them; a removed player is gone from `peer_ids()` and counts as dead (the removal triggers the check).

## Departures from the build plan

- `IslandTravel` is a session child with its own tests, not shell-only glue, so the two-peer tests drive it without a `GameShell` (the shell talks to the `NetManager` autoload).
- No `landing_glyphs` field: landing cells are the co-op spawn glyphs and the solo spawn is the first one.
- The delay runs in the meters' ticks, not a `SceneTreeTimer`: steppable in tests, frozen while held, resumes on landing. This also means a rider who waits out of play takes a pending delayed effect when they land, not while they wait.
- `EffectApplier` gets `CURE_STATUS` (the plan assumed it existed; aloe needs it).
- Signs show through a host `show_sign` RPC so every peer sees the bubble, not locally.
- `CoopSession.join_extras` and the world-state keys `island`, `waiting` and `raft` (the plan had only `island`).
- Arrivals are read from the host's meters at travel time instead of stored `CrossingResult`s: same numbers, and nothing keyed by a peer id that a reconnect changes.
- A waiting rider is skipped by `PlayerBody._has_living_teammate`: they are out of play, so the last player on the island is solo (a last stand rather than a wait for a revive nobody can give). This is part of the Split parties requirement.
- The shared hold test: a rider in a running crossing is not held until it ends, so "a crossing still running" and "still on the island" are the same condition in code; the test is named for what it checks.
- Spectating a teammate while waiting is not built; the wait is a label.

## Decisions and risks

- **The map.** Two 12-wide strips and a spur (a C around shallow flats): any strip 12 cells wide keeps every land cell within 6 tiles of water, and the flats in the bay are wadeable, so the walks from the west landing to the east point are straight lines across shallows. Corners are rounded by removing cells only, which can only shorten distances to water. The rows are generated once (a throwaway script) and committed as data; the numbers are asserted by `test_coast_cay_layout`.
- **Chain family on creatures.** Reef shark and land crab rules list SANDBAR and COAST; gulls stay sandbar-only. The crossing's shark pass reads the same rule for the departing chain.
- **Late joiner raft.** The host reports a raft's integrity whenever one lies on the island, built or beached, so a joiner sees the same raft.
- **Risk: freeing under synchronizers.** The two-peer tests run the swap with live spawners and synchronizers and log no engine errors.

## Reference games (ideas and structure only; nothing copied or translated)

- **Borrowed: Shattered Pixel Dungeon `scenes/InterlevelScene.java` and `Dungeon.switchLevel`.** The level switch is one host step: hold the old level's party state, build or load the new level, and only then place the hero. We do the same in one call (`travel_to`): tear down, build, place; never a half-loaded island.
- **Borrowed: SPD `Mob.holdAllies` and `Mob.restoreAllies`.** Allies near the hero are held off-level during the switch and re-placed beside the arrival point. Our waiting riders are held bodies placed on the landing cells when the level loads.
- **Borrowed: SPD `levels/features/LevelTransition.java`.** A transition is data on the level (destination depth, branch and type), not code. `IslandLayoutData.next_island` is the same idea; the generator's pick replaces it when `docs/ISLANDS.md` chains arrive.
- **Borrowed, adapted: DCSS `files.cc` `load_level` and `_grab_followers_and_expire_summons`.** Only followers within reach and able to move go along; the rest stay. We make the rule party-wide instead: nobody is left on a level that is no longer live, so the next island waits for everyone (the split-party rule).
- **Rejected: DCSS `save_level` and SPD `Dungeon.saveLevel` (keeping old levels to return to).** One live level and no return to the sandbar: the old island is freed.
- **Rejected: Brogue CE `RogueMain.c` `startLevel` with followers arriving later** (`STATUS_ENTERS_LEVEL_IN` from the distance map `mapToStairs`, so a follower turns up some turns after the player). Staggered arrival on a live level is exactly the second live space we avoid; we load once, when the last one is in.
- **Borrowed: Brogue CE `startLevel` keeps the player's state exactly** (health, items and statuses move with the player). Health and energy carry over from the crossing; inventories stay on the same `PlayerBody`.
- **Borrowed: DCSS `dat/des/arrival/*.des` vaults** (a map drawn in glyph rows with a legend of features and items). The coast cay is glyph rows with a legend, like the sandbar; each new glyph is one legend entry. **Rejected:** random glyph substitution (`SUBST`): the base cay is fixed and testable; variety waits for the village variant and generation.
- **Borrowed: Brogue CE machine blueprints (`Architect.c` `buildAMachine`).** A feature set placed together (the post: shaded walls, nails, mirror, radio, slogans) is one block of glyphs in the rows, so it can later be dropped as one set piece. **Rejected:** the blueprint's placement rules at spawn time; the coast cay is hand-placed.
