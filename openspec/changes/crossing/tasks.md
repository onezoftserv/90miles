# Tasks

## 1. Data and pure logic
- [x] 1.1 RED `test_vessel_integrity.gd`, `test_crossing_plan.gd`
- [x] 1.2 GREEN `CrossingTuning` and `resources/crossing_tuning.tres`, `VesselIntegrity`, `CrossingBeat`, `CrossingPlan`, `CrossingResult`
- [x] 1.3 Route data: raft `duration_s` 60-90, binoculars_swim `duration_s` 60-60 and `swim_drain_multiplier` 0.4

## 2. The crossing scene
- [x] 2.1 RED `test_crossing_squall.gd`, `test_crossing_rescue.gd`, `test_crossing_shark.gd`, `test_crossing_solo.gd`
- [x] 2.2 GREEN `Crossing` (sea, deck, rider states, fall-in, pace drain, drowning, end), `RescuePoint` (lashing, climb, pull), `CrossingThreats` and `ScriptedThreats`
- [x] 2.3 `PlayerBody.pinned` and `swim_energy_factor`; `Interactable.usable_by` and the picker's filter

## 3. Hand-off and shell
- [x] 3.1 `ArrivalStub` replaces `CrossingStub`
- [x] 3.2 `IslandRoutes` records the departing vessel's integrity and tells clients before it departs
- [x] 3.3 `GameShell` starts the crossing, keeps the run open while it runs and ends the run on the result
- [x] 3.4 Update `test_escape_routes_solo.gd` and `test_escape_routes_net.gd` (the run no longer ends at launch)

## 4. Sync
- [x] 4.1 Plan, state and result RPCs checked against the host; client interact intents applied by the host
- [x] 4.2 `test_crossing_net.gd` (tie-down, climb, plan never rolled by a client, one crosses and one stays)

## 5. Docs
- [x] 5.1 `design.md` with the reference games
- [x] 5.2 `TASKS.md` §4 tick, log line and follow-ups
- [x] 5.3 `docs/GAME_DESIGN.md` §8: the swim crossing's drain factor and drowning
- [x] 5.4 `openspec validate --all` and `openspec validate crossing --type change --strict`
