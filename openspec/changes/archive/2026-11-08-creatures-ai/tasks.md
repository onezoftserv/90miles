# Tasks

## 1. Tests first
- [x] 1.1 RED: `test_creature_content`, `test_creature_nav`, `test_patrol_circle_strike`, `test_night_thief`, `test_swoop_steal`, `test_creature_spawner`, `test_creature_net`, `test_crossing_creature_shark` and `helpers/creature_rig.gd` (all fail on the old code: the classes and files are missing)

## 2. Data
- [x] 2.1 Append-only fields: `CreatureData.keep_off_shore_tiles`, `CreatureSpawnRuleData.per_beach` and `anchor`, `IslandLayoutData.nest_palms` (validated as palm indices), `Inventory.held_food()`
- [x] 2.2 `reef_shark.tres`, `land_crab.tres`, `seagull.tres`; `nest_palms` in `sandbar.tres`

## 3. Navigation and state machines
- [x] 3.1 `CreatureNav` (land grid, water grid with the shore margin, land distance, beach groups)
- [x] 3.2 `CreatureBrain` base and `for_behavior`; `CreatureWorld`
- [x] 3.3 `PatrolCircleStrike`, `NightThief`, `SwoopSteal`

## 4. Scene, sync and spawning
- [x] 4.1 `creature.tscn` and `creature.gd`; the synchronizer is attached for session creatures
- [x] 4.2 `CoopSession.spawn_creature`, the entity `spawn_function`, the shoo request (reach checked, rate limited)
- [x] 4.3 `CreatureSpawner`; `SandbarIsland.furnish` adds it

## 5. Crossing
- [x] 5.1 `CreatureThreats` and the `Crossing.threats` default (the existing crossing tests pass unchanged; `test_crossing_creature_shark` fails with the old default)

## 6. Docs and specs
- [x] 6.1 Spec delta (ADDED only), proposal and design with the reference-games comparison
- [x] 6.2 `docs/ISLANDS.md` §1 "Threats" (offshore shark), `docs/BESTIARY.md` "Seagulls" (held food)
- [x] 6.3 `TASKS.md`: log entry (not archived)

## 7. Checks
- [x] 7.1 import, smoke, GUT (twice), the 300-frame run and `openspec validate --all` pass
