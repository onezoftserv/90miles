# Tasks

Written for the recommended answers to Q1–Q3 (design.md "Open decisions for the owner"). Every group ends with the import, the smoke run and GUT passing:
- `godot --headless --path game --import` (twice on a fresh checkout);
- `godot --headless --path game -s res://tests/smoke.gd`;
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`.

## 0. Owner answers and groundwork

- [x] 0.1 Record the owner's answers to Q1–Q3 in design.md and proposal.md. If any answer is not (a), update the specs and these tasks first. Verify that `openspec validate island-pressure --strict` passes.
- [x] 0.2 Rebase onto main. Sweep the tests that start a route (`start_for`, `request_route`, a raft launch) or work a raft site, and list in design.md which ones launch by day on an island with a spawned patrol boat or work the raft by standing. Verify that the list names every file `grep` finds, and that GUT passes on the rebased branch before any change.

## 1. Stages as data

- [x] 1.1 Add `game/scripts/data/build_stage_data.gd` (`BuildStageData`: `name_es`, `name_en`, `inputs`, `time_s`, typed) and three fields on `RecipeData`: `stages`, `work_energy_per_s` and `work_thirst_per_s`, all defaulting to off.
  Teach the content check that a staged recipe needs:
  - stage inputs summing to its inputs;
  - no tag inputs;
  - stage times summing to `time_s`, each above 0;
  - names in both languages.

  Verify with `game/tests/unit/test_build_stages_data.gd`: a valid staged recipe passes; mismatched inputs, mismatched times, a zero-time stage and a staged recipe with tags each fail.
- [x] 1.2 Give `game/resources/recipes/raft.tres` the four stages of escape-routes "Raft stages" ("Amarrar las cámaras", "Armar el piso", "Amarrar la baranda", "Apretar los nudos"; English "Lash the tubes", "Build the deck", "Lash the rail", "Tighten the knots"), `time_s` 120, `work_energy_per_s` 1 and `work_thirst_per_s` 0.25. Verify that the scenario "The raft's stages from data" passes and that the content check of the whole catalog reports no errors.

## 2. Staged, held and paid work (host and clients)

- [x] 2.1 Teach `BuildSite` (`game/scenes/structures/build_site.gd`):
  - add `stage_index()`, `stage_count()`, `stage_missing_items()`, `stage_progress()` and `work_limit()`, all derived from the synced progress and deposits (design D1);
  - make `work()` stop at the limit;
  - keep `missing_items()`, `inputs_complete()` and `progress()` meaning the whole recipe.

  Verify with 1-player, offline GUT tests of the crafting-inventory "Build stages" scenarios ("Solo raft waits at a stage", "Everything in at once", "A recipe without stages").
- [x] 2.2 Teach `Crafter` (`game/scripts/crafting/crafter.gd`) the held work, the costs and the energy gate:
  - **held work:** a staged site advances only while the body's intent holds interact, and letting go ends the work;
  - **costs:** each second of work charges `work_energy_per_s` and `work_thirst_per_s`, with the Mecánico paying per second at 2× speed;
  - **the gate:** no work at 0 energy.

  Verify with 1-player, offline GUT tests of "Letting go keeps the work", "Solo stage at dawn", "Out of strength", "A free fire", survival-meters "Building the raft in the sun" and "A raft stage", and escape-routes "Solo raft" and "A solo Mecánico".
- [x] 2.3 Add host-plus-client GUT tests, in-process like `test_build_site_net.gd`:
  - "Two hold together";
  - escape-routes "Two players feed the raft" and "One builds while the other gathers";
  - inventory-hud "Progress seen by a client";
  - a joiner mid-stage reading the same stage and stage progress.

  Verify that both peers report the same `stage_index()` and `stage_progress()` at every check.
- [x] 2.4 Update every test from the 0.2 sweep that works the raft by standing, so it holds interact. Verify that GUT passes with no test skipped.

## 3. Launch in view

- [x] 3.1 Add `RouteData.seen_at_launch` (raft true, binoculars-and-swim false). Add a pure `LaunchSight` (`game/scripts/stealth/launch_sight.gd`): from the boats, phase, weather and a point, it returns the first boat that sees a launch, or none (design D4).
  Verify with 1-player, offline GUT tests of guardacostas-stealth "Launch in view":
  - by day with the boat away;
  - at night outside and inside the cone;
  - in a squall;
  - a swim is not a launch;
  - an island with no boat.

  Add a sweep test: for the sandbar and the coast cay, with 1 and 2 boats, one full night period always has a moment when no light covers the raft site.
- [x] 3.2 Wire `IslandRoutes.start_for` to refuse a seen launch with nothing spent. Add `PatrolRoute.launch_seen(body)`: a boat away or on the horizon comes onto its lap at the loop point nearest the starter, then responds with cause `launch`.
  Verify with 1-player, offline GUT tests of escape-routes "Solo launch seen by day" and guardacostas-stealth "Solo spotted at launch": the raft stays at 100, nothing is spent, the boat docks, the squad lands and the search starts at the player's cell.
- [x] 3.3 Add host-plus-client GUT tests: guardacostas-stealth "Co-op party spotted"; escape-routes "Client asks, host picks" at night out of the light; and a client's day request refused with no `route_started` on either peer.
- [x] 3.4 Update every test from the 0.2 sweep that launches by day on an island with a spawned boat: it sets night, pins a squall, or uses an island without creatures, whichever keeps that test's intent. Verify that GUT passes with no test skipped.

## 4. Heat at sea and the last stand

- [x] 4.1 Add `sea_heat_cap` (59) to `SurvivalTuning` and `survival_tuning.tres`, `at_sea` to `MeterContext` and `SurvivalMeters`, and the cap in `SurvivalRules.next_heat`. `PlayerBody._meter_context` sets `at_sea` from the session's departures (design D6).
  Verify with 1-player, offline GUT tests of survival-meters "Solo midday at sea", "Boarding sunstruck" and "Back on land", plus a real 1-player crossing at 11:00 where the rider never gets sunstroke.
- [x] 4.2 Set `solo_last_stand_s` to 12 and make `_on_health_empty` use no base at sea. Update the tests of these scenarios:
  - survival-meters "Health and downed state" ("Solo", "Last one alive");
  - "Solo last stand" (with Experiencia, "Run 1 alone and dry", "Run 1 at sea");
  - "Free revive";
  - "Cause of death" ("A solo player dies of thirst", "Revived, then dry", "A solo last stand keeps its cause");
  - "Cause ids" ("Poison", and drowning and the shark bite unchanged);
  - endings-progression "Solo last stand from Experiencia".

  Verify that every test that times a solo death on land passes with the 12 s window, and that a host-plus-client test of "Last one alive" passes.

## 5. Prompt lines

- [x] 5.1 Add the stage line, the stage's "Falta:" lines, the stage bar and "Sin fuerzas: come algo." to `interact_prompt.gd`, with the words in `hud_text.tres`. Verify with 1-player, offline GUT tests of inventory-hud "The raft site" and "Solo out of strength", and the unchanged fire scenarios.
- [x] 5.2 Add the launch warning lines (day and night) to the raft's launch prompt through `LaunchSight`. Verify with 1-player, offline GUT tests of inventory-hud "Launch warning" ("Solo by day", "Solo at night, out of the light") and a host-plus-client test ("A client sees the warning").

## 6. The measured bot and two processes

- [x] 6.1 Add a GUT test `game/tests/unit/test_island_pressure_day.gd` that plays design D9's policy against the pure rules over a scripted sandbar day:
  - distances from the sandbar layout;
  - the build costs from `raft.tres`;
  - meters from `survival_tuning.tres`;
  - `LaunchSight` from the patrol data.

  Verify that it asserts midday seen, thirst under 50 before launch, launch at or after 20:00 and no death.
- [x] 6.2 Add `game/tests/manual/island_pressure_run.gd`: the design D9 bot on the real shell, solo, offline, calm weather pinned, headless with a fixed physics step.
  Verify by running it to the summary. It must print and pass:
  - midday seen;
  - minimum thirst on the sandbar under 50;
  - launch after 20:00;
  - alive at the summary;
  - 0 engine or script errors.

  Record the measured timeline (launch time, arrival, run length, meters every 30 s) in design.md "Measured run" and in TASKS.md.
- [x] 6.3 Add `game/tests/manual/island_pressure_coop_run.gd` on UDP 7799 for two processes, host first:
  1. the client holds the first stage while the host gathers;
  2. both finish the raft;
  3. a day launch is seen and both see the boat dock;
  4. after the squad leaves (or with time skipped to 22:00 by a printed hook), a night launch out of the light carries both to the coast cay.

  Verify that both processes print PASS for each step and log no error.

## 7. Docs and seams

- [x] 7.1 Update `docs/GAME_DESIGN.md`:
  - §4: the Energy row ("building 1/s" is the raft's work cost), the Thirst row (+0.25/s while working the raft), the Heat row (the sea cap of 59 until the toldo), and "Last stand" (12 s on land, none at sea);
  - §6: the raft's four stages;
  - §9: the launch rule;
  - §14: the 12 s base, and the example 30 s → 42 s.

  Verify that every number the specs name matches the doc.
- [x] 7.2 Update `TASKS.md`: tick the tuning task's island-1 part, add this change under Milestone B, and record the follow-ups (`night-ashore`, daytime sight on open beach, a launch-energy warning for HUD clarity, a cutter after a seen launch). Leave a note in the shared notes folder for the HUD-clarity, island-stop and crossing-gameplay sessions about the seams in design.md "Risks". Verify that the note exists.
- [ ] 7.3 Run the full suite (import twice, smoke, GUT) and a headless run of the project from the title through a solo raft build (owner, 2026-11-23: every Godot run is headless, so the Godot MCP's windowed run is replaced by `tests/manual/island_pressure_run.gd`). Verify that GUT reports 0 failures and the run logs 0 errors.
