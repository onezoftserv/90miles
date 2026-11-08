# Design

## Shape

- `Crossing` (`scenes/crossing/crossing.gd`) is one node per departure, `Crossing<n>` under the `CoopSession`, so its path matches on every peer. `Crossing.launch` runs on every peer when `IslandRoutes.route_started` fires: the host rolls the plan (`CrossingPlan.roll`) and sends it with `receive_plan`; a client builds the same node and waits. The host sends the departure RPC before it starts its own crossing, so a client's node exists when the plan arrives.
- The sea is a `GridTerrain` (all DEEP, zero current, the deck BEACH) set as each rider's `terrain`, placed far above the island so riders keep their `PlayerNet` sync and meters. The vessel stays put and the sea lines scroll past (visual only).
- `Crossing.advance(delta)` is the host's whole step (`_physics_process` calls it): elapsed time, due plan events, per-rider fall-in / pace drain / drowning / deck push-out, point refresh, end check, state sync. Tests call it directly in 0.1 s steps.
- Interaction reuses the existing hold rule. `RescuePoint` (an `Interactable`) comes in three kinds: LASH (one on the raft), CLIMB (one per swimmer, kept at the deck edge nearest them, on within 1 tile of an intact raft) and PULL (one per swimmer, on the swimmer, on for riders aboard). `Interactable.usable_by` lets `InteractionPicker` skip a point that is not for the presser. A client's hold already reaches the host as `interact` intents, so the host applies tie, pull and climb from the sender.
- `receive_state` (on change and every 1 s) and `receive_result` are `authority` RPCs checked against sender 1. Plan, state and result from anyone else, or malformed, are ignored.
- `CrossingThreats.resolve(beat, crossing)` is the hook; `ScriptedThreats` is the default (rock hit, shark pass choice). creatures-ai swaps `crossing.threats` and ends in `hit_vessel` / `bite_swimmer`.
- `GameShell` builds the crossing from `route_started`, keeps the run open while a rider is in a running crossing, and on `ended` holds the riders (`ArrivalStub.hold`), keeps the result in `crossing_results` and checks whether the run is over.

## Solo

Every rule has a 1-player path in the spec and a test: launch into the crossing, tie down alone, thrown in alone, climb alone (3 s), finish alone, swim alone, die alone (the run ends as a death).

## Reference games (ideas only; nothing copied or translated)

- **DCSS Abyss** (`crawl-ref/source/abyss.cc`).
  - *Borrowed:* the player stays at a fixed centre and the world moves. `maybe_shift_abyss_around_player` shifts only when the player passes `ABYSS_SHIFT_DISTANCE`, and `abyss_area_shift` / `_abyss_shift_level_contents_around_player` move what is kept and regenerate the rest. Our vessel stays put in world space and the sea lines scroll past.
  - *Rejected:* `_abyss_generate_monsters` spawns by random level-wide picks (`pick_random_monster`, `PROX_ANYWHERE`) with no schedule. We want a short, readable, seed-stable ordered plan (`CrossingPlan`), so spawns are timed events, not ambient respawns. Also rejected: terrain morphing (`_abyss_apply_terrain`); the sea is uniform deep water plus the deck.
- **Brogue CE** (`src/brogue/Time.c`, `Movement.c`).
  - *Borrowed:* `updateEnvironment` advances all environmental state once per turn in one place; `Crossing.advance` likewise advances time, fires due events, drains and drowns in one ordered step. The `rogue.inWater` toggle at the top of `Time.c` (entering and leaving deep water is a state change with a one-time cost) becomes the ABOARD/TIED to IN_WATER state with the one-time 10 energy. `monstersFall` running before the environment pass: thrown-in riders are resolved before the drain tick.
  - *Rejected:* the deep-water item loss (a chance, then `dropItem` "floats away in the current") is out of scope and too punishing at 60-90 s; it is a follow-up. Also rejected: volumetric gas spread (`updateVolumetricMedia`) as a model for the squall; the squall is one timed event from the shared weather.
- **Shattered Pixel Dungeon** (`actors/blobs/Blob.java`, `GooWarn.java`, `StormCloud.java`, `levels/Level.java`, `levels/PrisonBossLevel.java`).
  - *Borrowed:* `GooWarn` is a cosmetic warning that decays (`evolve` counts down) before the real effect, like the 60 s horizon line before the squall hit. `PrisonBossLevel`'s `State` enum with `progress()`, a level driven through scripted phases in order, matches `CrossingPlan` as an ordered event list consumed by elapsed time.
  - *Rejected:* `Level`'s respawner cooldown (`TIME_TO_RESPAWN`, scaled by mob count); endless respawns do not fit a fixed-length crossing. Also rejected: blobs as the squall model, because the squall acts on the whole vessel at once.

## Decisions and risks

- **Plan changes found in the code.** `CrossingEvent` clashes with an enum inside `ChainData`, so the class is `CrossingBeat`. The tuning file is `resources/crossing_tuning.tres` (the content validator treats every folder of `resources/` as a content type). `Crossing.setup` and `launch` take the plan and a serial; the vessel is drawn by the crossing; `RescuePoint` replaces the separate `ClimbPoint` / `PullHandle` / `Lashing` classes (one class, three kinds). Plan events fire against a cursor a hair past the clock so 0.1 s steps meet exact times without firing twice.
- **Squall.** One sky: the crossing's squall warning is `sky.weather.warn_weather(&"squall")`, so players left on the island get the same squall. The hit itself is the crossing's own timed event, so it does not depend on the sky's clock running. Only riders ABOARD are thrown; a break throws everyone.
- **Pace drain.** In the water the crossing spends the energy (`swim_energy_factor = 0` stops the movement model's moving-only drain on the host and the predicting client alike).
- **Prediction.** `pinned` and `swim_energy_factor` are set on every peer from the crossing, so reconciliation does not jitter.
- **Typed arrays of own classes leak at exit**, so plan events are `Array[RefCounted]`, crossings `Array[Node]`, results `Array[RefCounted]`, points `Dictionary[int, Interactable]`.
- **Not hand-tested.** Host plus client by hand (CLAUDE.md) is not possible in this unattended run; `test_crossing_net.gd` covers the ENet host-and-client path in one process.
