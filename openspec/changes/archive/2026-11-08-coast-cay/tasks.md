# Tasks

## 1. Tests first
- [x] 1.1 RED: `test_coast_cay_layout`, `test_coast_cay_solo`, `test_coast_cay_net`, `test_effect_delay`; the four existing assertions that ended a solo run in the summary now expect the coast cay (`test_crossing_solo`, `test_escape_routes_solo`). The new scripts failed to parse or load (the layout file and the classes were missing); `test_effect_delay` failed 2 of 4

## 2. Data and the island scene
- [x] 2.1 `IslandSignData`; `IslandLayoutData` gets `chain_family`, `next_island`, `drink_glyph`, `drink_hold_s`, `drink_effects`, `signs`; `IslandLayout` reads drink spots and signs, `landing_cells()`, `ROCK` walkable; `DevIslandTerrain` colours `ROCK`
- [x] 2.2 `nails.tres`, `mirror.tres`, `aloe.tres`, `lighter.tres`
- [x] 2.3 `coast_cay.tres`; `next_island = &"coast_cay"` in `sandbar.tres`
- [x] 2.4 `SandbarIsland`: `layout` setter that rebuilds terrain, bounds and lists; `furnish` skips a missing workbench and places drink spots and signs; `beach_raft`

## 3. Lagoon, signs, effects
- [x] 3.1 `DrinkSpot` and `IslandSign` interactables; `CoopSession.show_sign`
- [x] 3.2 `SurvivalMeters.delay_effect` and `effect_due`, `EffectApplier.apply_now`, `delay_s` honoured, `CURE_STATUS` interpreted

## 4. Arrival
- [x] 4.1 `IslandArrival` (hold, land, landing positions, camera fit) replaces `ArrivalStub`
- [x] 4.2 `IslandTravel` (check, travel, load, follow); `CoopSession.travel_to`, `join_extras` and the `island`, `waiting` and `raft` world-state keys
- [x] 4.3 The shell: builds the keeper, hands crossing results to it, reconnects routes on `island_loaded`, wait label; `_check_run_over` asks the keeper
- [x] 4.4 A waiting rider is skipped by `PlayerBody._has_living_teammate`

## 5. Creatures
- [x] 5.1 The spawner reads `layout.chain_family`; COAST added to `reef_shark.tres` and `land_crab.tres` rules

## 6. Docs and specs
- [x] 6.1 Spec deltas (MODIFIED `crossing` Arrival and `escape-routes` Split parties, copied whole from `openspec/specs/`; ADDED for `island-generation`, `crafting-inventory`, `creatures-ai`), proposal and design with the reference-games comparison
- [x] 6.2 `docs/ISLANDS.md` §2 size line, `HANDOFF.md` decision, `TASKS.md` tick and log entry (not archived)

## 7. Checks
- [x] 7.1 import (twice), smoke, GUT (twice), the 300-frame run, `openspec validate coast-cay --type change --strict` and `openspec validate --all` pass
