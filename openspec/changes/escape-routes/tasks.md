# Tasks

## 1. Data
- [x] 1.1 RED `test_route_content.gd`, `test_sandbar_island.gd` and `test_island_layout.gd` (3 rope)
- [x] 1.2 GREEN `items/binoculars.tres`, `recipes/raft.tres`, `routes/raft.tres`, `routes/binoculars_swim.tres`, `RouteData.board_radius_tiles` and `discover_conditions`
- [x] 1.3 `sandbar.tres`: 2 rope in the hut (`q`), raft site marker (`B`), `route_ids`

## 2. Conditions
- [x] 2.1 RED `test_condition_check_routes.gd`
- [x] 2.2 GREEN `SurvivalMeters` statuses; `ConditionCheck` METER_AT_LEAST, STATUS_ACTIVE, WEATHER_IS_CLEAR, STRUCTURE_BUILT; `EffectApplier` START_ROUTE

## 3. Launcher
- [x] 3.1 RED `test_route_launcher.gd`
- [x] 3.2 GREEN `RouteLauncher`

## 4. Island routes and raft
- [x] 4.1 RED `test_raft_site.gd`, `test_escape_routes_solo.gd`
- [x] 4.2 GREEN `IslandRoutes`, `Raft`, layout marker, `SandbarIsland.furnish`, `BuildSite` state push

## 5. Session and shell
- [x] 5.1 RED `test_escape_routes_net.gd`
- [x] 5.2 GREEN `CoopSession.start_route`, departed players, `GameShell` run end, summary text, `CrossingStub`

## 6. Close
- [x] 6.1 `docs/ISLANDS.md` §1 (hut rope, flotsam line), `TASKS.md` log and follow-ups
- [x] 6.2 import, smoke, GUT, 300-frame run, `openspec validate --all` and `escape-routes --type change --strict`
