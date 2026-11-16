# Tasks

Do not build until the `guardacostas-stealth` build has merged and the coordinating session relays that the owner approved building.

Every group is test-first:
1. Write the listed tests.
2. Watch them fail for the right reason.
3. Build until they pass.

Every group ends with these three commands passing. On a fresh checkout, run the import twice.
- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`

How the tests are written:
- Pure tests step time in whole seconds, or in 1/60 s ticks summed to whole seconds, as `test_movement_model.gd` does.
- Threshold checks use the 1e-6 tolerance.
- Sort ids with a `String` comparator.
- "Solo" means exactly 1 player, offline, with no host or port.
- "Host plus client" uses `NetHarness` (`game/tests/helpers/net_harness.gd`).
- Test patrols, soldiers and islands are fixture files in the catalog, because `spawn_creature` re-reads data by id.

## 0. Preconditions

- [x] 0.1 Get the owner's answers to the eleven decisions in proposal.md.
  - Where an answer differs from the recommended option, first update proposal.md, design.md, the spec delta and these tasks.
  - Verify: `openspec validate guardacostas-capture --type change --strict` passes.
  - Done on 2026-11-14: the owner accepted (a) on all eleven. No artifact changed beyond recording the answers, and the strict validation passes.
- [x] 0.2 Wait for the `guardacostas-stealth` build to merge.
  - Branch from the updated `main`.
  - Re-read these files as merged: `patrol_route.gd`, `spot_meter.gd`, `hidden_rules.gd`, `patrol_triggers.gd`, `world_events.gd`, `patrol_data.gd`, `creature.gd`, `creature_spawner.gd`, `creature_world.gd`, `player.gd`, `player_net.gd`, `coop_session.gd`, `body_marks.gd` and `patrol_boat.tres`.
  - Verify by recording in design.md "Changes from the build plan" any name that differs from design.md.
  - Done on 2026-11-15: the stealth build (PR #62) is merged; the build branched from main 8edc5ab and rebased on 3b5f9b1. The merged files were re-read, and the names that differ are in design.md "Changes from the build plan" (task 0.2).

## 1. Data and content

- [x] 1.1 Write `game/tests/unit/test_capture_data.gd` and verify it fails. It checks:
  - the new `PatrolData` fields and their defaults (design.md §15);
  - that `shore_soldier.tres`, `rodriguez.tres`, `beat_la_captura.tres`, `maestro.tres` and `medico.tres` load and pass the content check;
  - that the patrol boat's squad, scene and commander references resolve;
  - that the validator reports a patrol whose squad creature lacks `SEARCH_CAPTURE`, and a missing call list.
  - Done: it failed to parse on the missing fields, `_check_squad`, `FixtureIslands` and `FixtureBackgrounds`, then passed (16 tests).
- [x] 1.2 Add the fields, the validator check and the content files, with the draft lines of design.md §10 and §11. Then:
  - Write `beat_la_captura.tres` as the state table in design.md §9.
  - Fill the existing squad and capture fields in `patrol_boat.tres`.
  - Verify `test_capture_data.gd` passes.
  - Done: the fields default to §15's numbers, with the squad off until a patrol names one (`has_squad()`). `_check_squad` holds a patrol with a squad, `la_captura` was written by a one-off script, and `patrol_boat.tres` carries every number and the calls.
- [x] 1.3 Add these fixtures under `game/tests/fixtures/` and verify each loads in `test_capture_data.gd`:
  - a chain of three tiny islands (`chain_a` → `chain_b` → `chain_c`, the last naming no next island);
  - a tiny off-graph island;
  - a tiny island of family REEF;
  - fixture backgrounds that set `PlayerBody.background_id` to `medico` or `maestro`;
  - a fixture keepsake item (KEEPSAKE tag) that stands in for the Foto de la familia until keepsakes exist;
  - a test soldier and a test patrol (`squad_test`) with a 2-soldier squad and a 120 s search.
  - Done: in `tests/fixtures/content/` (`soldier_test`, `squad_test`, `foto_test`, and islands `chain_a`, `chain_b`, `chain_c`, `chain_off` and `reef_test`), with `FixtureIslands` and `FixtureBackgrounds` in `tests/helpers/`. The broken squads are in `tests/fixtures/squad_broken/`.
- [x] 1.4 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done with groups 2 and 3 (one PR): import and smoke clean, GUT 247 scripts, 2252/2252; after the rebase on main 3b5f9b1, import twice and smoke clean, GUT 257 scripts, 2347/2347.

## 2. Island history and travel

- [x] 2.1 Write `game/tests/unit/test_island_history.gd` (pure) and verify it fails. It checks:
  - previous on index 1, 2 and 3;
  - the off-graph cay skipped (main spec "Caught after the detour");
  - islands reached as the highest index (the spec's "Counted once").
  - Done: it failed to parse on the missing `IslandHistory`, then passed (9 tests).
- [x] 2.2 Write `game/tests/unit/test_capture_travel_solo.gd` and verify it fails. It uses one offline player, the fixture chain, and the real sandbar and coast cay. It covers:
  - the restart of island 2 from island 3 with pick-ups as on first arrival ("Previous island is fresh");
  - island 1 restarting island 1 ("Caught on the sandbar");
  - a release from the sandbar onto the coast cay's first landing cell with no raft beached;
  - a release from the coast cay ending the run;
  - landing cells within 5 tiles.
  - Done: it failed on the missing `restart` and `release`, then passed (5 tests). The 5-tile check covers the islands a release lands on; island 1's landing cells are its four start spots (design.md, group 2).
- [x] 2.3 Implement `game/scripts/run/island_history.gd` and the `IslandTravel` changes (design.md §8): the index in the travel message, `previous()`, and `travel` with `raft_integrity` 0 for a restart or a release. Verify both tests pass, and that `test_coast_cay_solo.gd`, `test_coast_cay_net.gd`, `test_arrival_by_vessel.gd`, `test_arrival_scatter_net.gd`, `test_run_restart.gd` and `test_secret_cay_solo.gd` still pass.
  - Done, with a fix the solo test found: the session's `WorldEvents` bus is now one of `SESSION_NODES`, so it survives a travel. The six listed tests pass in the full run.
- [x] 2.4 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 2252/2252 (2347/2347 after the rebase).

## 3. Conditions and effects

- [x] 3.1 Write `game/tests/unit/test_capture_conditions.gd`, beside `test_condition_check_routes.gd` and `test_effect_flags.gd`, and verify it fails. Its cases are:
  - `ANY_PLAYER` over an `ALL_OF` (one Maestro at morale 50 and one Médico at 70 passes; no background never passes);
  - `BACKGROUND_PRESENT` reading `PlayerBody.background_id`;
  - `TAKE_ITEMS_WITH_CAPABILITY LIGHT_FIRE` removing the lighter and keeping a KEEPSAKE-tagged item;
  - `TRAVEL_NEXT_ISLAND` and `TRAVEL_PREVIOUS_ISLAND` calling `IslandTravel` on the host only.
  - Done: it failed to parse on the missing `take_capability` and the party parameter, then passed (10 tests, with `FLAG_SET`, the party's `PLAYERS_AT_LEAST` and a downed speaker added).
- [x] 3.2 Implement them in `condition_check.gd`, `effect_applier.gd` and `inventory.gd`, and add `PlayerBody.background_id`, empty by default. Verify the test passes, and that `test_condition_check_routes.gd`, `test_effect_flags.gd` and `test_effect_delay.gd` still pass.
  - Done: the travel effects reach `IslandTravel` through `CoopSession.party_travel_requested`, because naming the class in `effect_applier.gd` made a load cycle. The three listed tests pass in the full run.
- [x] 3.3 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 247 scripts, 2252/2252 (257 scripts, 2347/2347 after the rebase).

## 4. The chase at sea (pure, then the brain)

- [x] 4.1 Write `game/tests/unit/test_boat_chase.gd` (pure) and verify it fails. It checks:
  - the speed of 6 tiles/s;
  - deep water only;
  - the haul at 2 s within 1 tile, reset on leaving;
  - breaks on a dive, shallows, land and 10 tiles;
  - land turning into a landing cause.
  - Done: it failed to parse on the missing `BoatChase`, then passed (10 tests).
- [x] 4.2 Implement `game/scripts/stealth/boat_chase.gd` and the boat's `CHASE` state in `patrol_route.gd` (design.md §1, §3). Verify the test passes and the stealth tests still pass, except the water-spot cases in `test_patrol_route.gd` and `test_patrol_solo.gd` that expect the 20 s give-up. Update those to expect the chase, as the modified Alert says, and list each one in design.md "Changes from the build plan".
  - Done: the brain's `CHASE` state hands a haul, a landing and every break off as design.md "Changes from the build plan" (group 4) says, and the boat heads back to its loop while it searches. In `test_patrol_route.gd` the water case expects the chase, and five chase tests were added. `test_patrol_solo.gd` needed no change. `test_patrol_cues.gd` moved its spotted player out of deep water.
- [x] 4.3 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean. GUT 258 scripts, 2361/2362; the one failure was `test_patrol_cues.gd`'s player in deep water, fixed and that script re-run (14/14).

## 5. Soldier sight (pure)

- [x] 5.1 Write `game/tests/unit/test_soldier_sight.gd` and verify it fails. It checks the spec's "Soldier sight" scenarios on the cone geometry and the shared spot meter:
  - the day and night cones;
  - hidden players never seen;
  - fog;
  - the 5 against 6 tiles/s footrace breaking past 6 tiles.
  - Done: it failed to parse on the missing `SearchCapture` and `SightCone`, then passed (10 tests).
- [x] 5.2 Implement the soldier as a sight source in `SpotMeter`'s input, with the cone helper beside `searchlight.gd`. Verify the test passes and `test_spot_meter.gd` still passes.
  - Done: `SightCone` beside `searchlight.gd`, soldiers as sight sources of `PatrolWatch` (which steps every meter), and the start of `SearchCapture`. `test_spot_meter.gd` still passes (14/14).
- [x] 5.3 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 259 scripts, 2372/2372.

## 6. The squad plan (pure)

- [x] 6.1 Write `game/tests/unit/test_squad_plan.gd` and verify it fails. It checks:
  - the landing cell;
  - the dinghy's row time at 2 tiles/s;
  - the point order (fires nearest the landing first, then the last known position);
  - taking points, and the nearest free soldier taking a new last known position;
  - the 3 s point search finding within 2 tiles and not at 3;
  - the random walk being equal for equal seeds;
  - leaving at 180 s, the 60 s grace, no free player left, and a squall.
  - Done: it failed to parse on the missing `SquadPlan`, then passed (11 tests).
- [x] 6.2 Implement `game/scripts/stealth/squad_plan.gd` (design.md §6). Verify the test passes.
  - Done.
- [x] 6.3 Write `game/tests/unit/test_squad_search_coverage.gd`, which pins the built plan's outcomes on both islands with the shipped numbers. Verify it passes, and record its run time in design.md "Changes from the build plan" if it takes over 2 s. The design.md figures come from a throwaway model, not the real plan, so measure first:
  1. Run the real `SquadPlan` and soldier sight over 100 seeded runs per island.
  2. Record the share of runs in which a still player in the open is spotted, beside design.md's 66% and 54%.
  3. Pin that share to within ±10 points.
  - Done: the real plan spots a still player in the open in 50% of sandbar runs and 52% of coast cay runs (the model said 66% and 54%), pinned within ±10. Cover is a median of 3 steps away, with a maximum of 8 and 13, as design.md measured. It runs in about 7 s, which design.md "Changes from the build plan" (group 6) records.

  The test also checks, by rule:
  - a hidden player more than 2 tiles from every searched point is never found;
  - from each island's solo landing, cover more than 2 tiles from any cell is at most 13 steps away (design.md's measured maximum).
- [x] 6.4 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 261 scripts, 2386/2386.

## 7. The soldier, captives and freeing

- [x] 7.1 Write `game/tests/unit/test_search_capture.gd` on the brain with a test world and verify it fails. It checks:
  - the escort to the dinghy at 2 tiles/s;
  - the soldier going back to its plan;
  - the touch resetting when contact breaks;
  - downed and dropped bodies never targeted;
  - freeing on a 1 s hold with no soldier within 3 tiles;
  - the hold cancelled when a soldier comes within 3 tiles ("The guard comes back").
  - Done: it failed to parse on the missing `PatrolRoute.Squad`, then passed (9 tests, with the landing, a captive standing still, a hauled captive and the squad leaving with its captive added).
- [x] 7.2 Write `game/tests/unit/test_capture_solo.gd` with one offline player on the real sandbar, driven by the named input actions only. Verify it fails. It covers:
  - spotted at night, running 10 tiles, crouching in scrub away from the fire, and the squad leaving after 180 s with the boat resuming its lap;
  - hiding 1 tile from their own fire and being found;
  - outrunning a soldier;
  - being hauled aboard while swimming in deep water, and escaping into the shallows;
  - a day fire bringing the squad.
  - Done: it failed to parse on the missing squad state, then passed (6 tests, about 6 s; the haul and the shallows are two tests).
- [x] 7.3 Implement `game/scripts/ai/search_capture.gd`, the boat's `DOCKED` state, and the captive state on `PlayerBody` (design.md §5–§7). Verify the tests pass and that `test_creature_spawner.gd` and the stealth tests still pass. The exceptions are the land-alert cases in `test_patrol_route.gd` and `test_patrol_solo.gd` that expect the 20 s give-up, such as "Solo player spotted, hides and gets away" and "A smoke alert by day". Update those to expect the squad, as the modified Alert says, and list each one in design.md "Changes from the build plan". The work is:
  - `_acting_body` refuses intents from a captive except quick chat;
  - the dragger is set to the soldier;
  - the captive is pinned in the dinghy;
  - the "Soltar" `Interactable` is added.
  - Done. `test_creature_spawner.gd` and the stealth tests pass. The changed stealth cases are listed in design.md "Changes from the build plan" (group 7): `test_patrol_solo.gd`'s spotted-and-hides case follows the modified Alert, both loudhailer tests in `test_patrol_cues.gd` keep a squad-less boat, and `test_patrol_net.gd` expects `DOCKED`. `test_patrol_route.gd` needed none, because its bare world lands no squad.
- [x] 7.4 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 263 scripts, 2401/2401.

## 8. Whole-party capture, taken captives and the router

- [x] 8.1 Write `game/tests/unit/test_capture_rules.gd` (pure) and verify it fails. It checks:
  - who is free (downed, last stand, dropped, a waiting rider, a rider in a crossing);
  - the whole-party test;
  - "The last free player dies";
  - the taken rule;
  - the router: an island or a non-final crossing plays the scene, and a final-crossing capture skips both the scene and the check ("A final-crossing capture skips the scene").
  - Done: it failed to parse on the missing `CaptureRules.Member` and `CaptureOutcome`, then passed (12 tests).
- [x] 8.2 Write `game/tests/unit/test_capture_taken_net.gd` with host plus client and verify it fails. It covers the spec's "Taken captives" scenarios:
  - the client's player is taken and lands on the coast cay with the Foto only;
  - the compass is laid on the landing beach and seen on both peers;
  - the island empties when the only other player waits on the next shore.
  - Done: it failed to parse on the missing keeper (`CaptureScene`) and `PlayerBody.taken`, then passed (3 tests).
- [x] 8.3 Implement `capture_rules.gd` and `capture_outcome.gd`, the out-of-play taken state, and the `IslandTravel.check()` change. Verify the tests pass, and that `test_escape_routes_solo.gd`, `test_arrivals_cap.gd` and `test_dropped_teammate_net.gd` still pass.
  - Done: `CaptureScene` is the keeper (design.md "Changes from the build plan", group 8). `IslandTravel.check()` asks it first, and `CreatureWorld.players()` skips held bodies. `test_escape_routes_solo.gd`, `test_arrivals_cap.gd` and `test_dropped_teammate_net.gd` pass.
- [x] 8.4 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 265 scripts, 2416/2416.

## 9. The scene

- [x] 9.1 Write `game/tests/unit/test_capture_scene.gd` and verify it fails. Using solo play, it checks:
  - the singular lines;
  - the second-capture opening after a restart;
  - the formal act;
  - the outcome's lines and effects for release, return and the car return (`almendron_hundido` set);
  - the speaker on a tie;
  - a player with no background failing the check;
  - the "Solo capture fails" and "Solo Médico talks their way out" scenarios with the fixture background;
  - every player out of play during the scene;
  - a downed player taken along standing at 30 health after it.
  - Done: it failed to parse on the missing `ScenePanel`, then passed (12 tests). The downed teammate taken along needs two players, so it is in `test_capture_net.gd`.
- [x] 9.2 Implement `CaptureScene` and `game/scenes/ui/scene_panel.gd` (design.md §9). Verify the test passes, and verify by hand in a 300-frame solo run that the panel's text fits at 640×360.
  - Done. In the 300-frame solo run (`tests/manual/capture_la_captura.tscn`, windowed), the card first stayed one line tall while the text wrapped below it. The card now measures the wrapped text, the re-run shows the longest line inside it, and a test checks every line's height against the card and the card against 640×360.
- [x] 9.3 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 266 scripts, 2428/2428. The orphans rose by 8: the HUD made its scene panel before `bind`, so the unbound HUDs in `test_patrol_cues.gd` and `test_run_hud.gd` leaked it. The panel is now made in `bind`, and `test_run_hud.gd` reports none.

## 10. Network

- [x] 10.1 Write `game/tests/unit/test_capture_net.gd` with host plus client and verify it fails. It covers the spec's "Capture on every peer", "Captives", "Whole-party capture" and "The capture scene" scenarios:
  - a client frees a captive;
  - a client's interact hold from out of reach frees nobody;
  - a captive's intents are ignored while its quick chat goes through;
  - joining while the squad is ashore;
  - joining during the scene;
  - both peers showing the same line;
  - a downed teammate going along;
  - a captive client dropping and rejoining;
  - both peers' summaries counting the same islands reached.
  - Done: 5 of its 8 tests failed before the sync, for the right reason (nothing synced), and all 8 pass after it. It covers freeing, freeing from afar, a captive's intents and quick chat, joining with the squad ashore, joining during the scene, the same lines with a downed teammate standing at 30 health, a captive's drop and rejoin, and the islands reached.
- [x] 10.2 Implement the sync (design.md §13). Freeing uses the existing interact intent, so no new client message is added. Verify the test passes, and that `test_patrol_net.gd`, `test_creature_net.gd`, `test_coop_reconnect.gd` and `test_dead_spectate_net.gd` (if merged) still pass.
  - Done: `net_capture` on the bodies, the squad's fields on the boats, and the taken hold by RPC (design.md "Changes from the build plan", group 10). No client message was added. `test_patrol_net.gd`, `test_creature_net.gd`, `test_coop_reconnect.gd` and `test_dead_spectate_net.gd` pass.
- [x] 10.3 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 267 scripts, 2436/2436. The first run caught `test_player_state_sync.gd`'s property list and the stale taken hold, both fixed.

## 11. Fade with distance

- [x] 11.1 Write `game/tests/unit/test_patrol_fade.gd` and verify it fails. Using the REEF fixture, it checks:
  - 26–34% with patrols over 1,000 seeds, each with one or two boats;
  - the same count on a second set-up from the same seed;
  - no rule for STORM or SHIPWRECK ("Far chain");
  - one player getting the base count.
  - Done: it failed to parse on the missing `CreatureSpawner.patrol_stream` and `roll_patrol`, then passed (5 tests: 31.6% of 1,000 seeds have boats).
- [x] 11.2 Add the mid-chain rule to `patrol_boat.tres` (design.md §12). Verify the test passes and the stealth spawner tests still pass.
  - Done: the patrol's chance is now rolled from its own run-seed stream. `test_creature_spawner.gd` and the patrol spawner tests pass; `test_patrol_data.gd`'s rule count is now three.
- [x] 11.3 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 274 scripts, 2509/2509.

## 12. Cues, the two-process run and docs

- [x] 12.1 Write `game/tests/unit/test_capture_cues.gd` with solo, and with host plus client, and verify it fails. It covers the spec's "Capture cues" scenarios:
  - the rope mark on both peers;
  - the prompt hidden while a guard is near;
  - the landing, spot and leaving calls in Spanish;
  - the open eye filling under a soldier's sight.
  - Done: it failed to parse on the missing `SquadLook`, then passed (5 tests, solo and host plus client).
- [x] 12.2 Implement the cues (design.md §14), with all text in `hud_text.tres`. Verify:
  - the test passes;
  - art-pass's "drawing never changes the simulation" test is extended to the soldier and the dinghy.
  - Done: the rope mark in `BodyMarks`, `SquadLook` (the soldier, the dinghy and the calls), and the prompt words in `hud_text.tres`. `test_art_sim_invariance.gd`'s night lap now lands a squad, draws the soldiers, the dinghy and a call, and stays equal frame for frame.
- [x] 12.3 Run a host and a client as two processes on the sandbar at night, written as `game/tests/manual/guardacostas_capture_run.gd` after `patrol_run.gd`, on a free UDP port. Do not name it `capture_*.gd`, which is the screenshot tooling's prefix. Verify each of these by its log line:
  1. the squad lands and is seen on both;
  2. the client is captured and freed from the dinghy;
  3. both are captured;
  4. the scene plays on both;
  5. the restart lands both on the sandbar.
  - Done on UDP 7796: host 14/14, client 10/10, no engine errors. Each of the five steps has its log line. The stealth slice's `patrol_run.gd` was re-run with its boat squad-less: host 22/22, client 18/18.
- [x] 12.4 Update the docs with the confirmed numbers, and verify each edit by reading it back against the spec delta:
  - `docs/GAME_DESIGN.md` §9 (the dinghy, taken captives, the router);
  - `docs/BESTIARY.md` "Guardacostas patrol boat" (the chase) and "Shore squad" (sight, point searches, the dinghy, leaving, taken captives);
  - `docs/ISLANDS.md` "Chains and distance" (a 30% chance);
  - `docs/CHARACTERS.md` Rodríguez (*La captura*'s check and lines);
  - `docs/CONTENT_MANIFEST.md`;
  - `TASKS.md` §6, which ticks "Shore squad, capture, free-a-captive, `la_captura` scene" and keeps `balsero-lore` 9b.1 open for the chain rows.
  - Done: `GAME_DESIGN.md` §9, `BESTIARY.md` (the chase and landing on the patrol boat, and the whole "Shore squad"), `ISLANDS.md` (the 30% chance), `CHARACTERS.md` (Rodríguez's *La captura*), `CONTENT_MANIFEST.md` and `TASKS.md` §6 (ticked, with `balsero-lore` 9b.1 kept open). Each was read back against the spec delta.
- [x] 12.5 Run the import, smoke run and GUT commands, and verify all three pass.
  - Done: import and smoke clean, GUT 275 scripts, 2514/2514. Every task in this file is now ticked. After the review fix and the restack: GUT 275 scripts, 2519/2519, and the two-process run again host 14/14, client 10/10.

## Workflow follow-up

- Archive only after `guardacostas-stealth` is archived, because archive refuses this change's Alert delta until then. Before archiving, re-copy Alert from the merged main spec into this delta, re-apply this change's edits, and verify `openspec validate guardacostas-capture --type change --strict` passes with no archive warning.
- When the backgrounds change ships, it replaces the stub `maestro.tres` and `medico.tres`, and its tests drive the passing check without the fixture.
- When the final crossing exists, it connects `run_devuelto` and adds the main spec's "Solo player caught in the Straits" test.
- When chain route rows exist, `balsero-lore` 9b.1 adds its gate test on top of the flag this change sets.
