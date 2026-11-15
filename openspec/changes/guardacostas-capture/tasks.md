# Tasks

Do not build until the coordinating session relays that the owner approved building.

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

- [ ] 0.1 Get the owner's answers to the eleven decisions in proposal.md.
  - Where an answer differs from the recommended option, first update proposal.md, design.md, the spec delta and these tasks.
  - Verify: `openspec validate guardacostas-capture --type change --strict` passes.
- [ ] 0.2 Wait for the `guardacostas-stealth` build to merge.
  - Branch from the updated `main`.
  - Re-read these files as merged: `patrol_route.gd`, `spot_meter.gd`, `hidden_rules.gd`, `patrol_triggers.gd`, `world_events.gd`, `patrol_data.gd`, `creature.gd`, `creature_spawner.gd`, `creature_world.gd`, `player.gd`, `player_net.gd`, `coop_session.gd`, `body_marks.gd` and `patrol_boat.tres`.
  - Verify by recording in design.md "Changes from the build plan" any name that differs from design.md.

## 1. Data and content

- [ ] 1.1 Write `game/tests/unit/test_capture_data.gd` and verify it fails. It checks:
  - the new `PatrolData` fields and their defaults (design.md §15);
  - that `shore_soldier.tres`, `rodriguez.tres`, `beat_la_captura.tres`, `maestro.tres` and `medico.tres` load and pass the content check;
  - that the patrol boat's squad, scene and commander references resolve;
  - that the validator reports a patrol whose squad creature lacks `SEARCH_CAPTURE`, and a missing call list.
- [ ] 1.2 Add the fields, the validator check and the content files, with the draft lines of design.md §10 and §11. Then:
  - Write `beat_la_captura.tres` as the state table in design.md §9.
  - Fill the existing squad and capture fields in `patrol_boat.tres`.
  - Verify `test_capture_data.gd` passes.
- [ ] 1.3 Add these fixtures under `game/tests/fixtures/` and verify each loads in `test_capture_data.gd`:
  - a chain of three tiny islands (`chain_a` → `chain_b` → `chain_c`, the last naming no next island);
  - a tiny off-graph island;
  - a tiny island of family REEF;
  - fixture backgrounds that set `PlayerBody.background_id` to `medico` or `maestro`;
  - a fixture keepsake item (KEEPSAKE tag) that stands in for the Foto de la familia until keepsakes exist;
  - a test soldier and a test patrol (`squad_test`) with a 2-soldier squad and a 120 s search.
- [ ] 1.4 Run the import, smoke run and GUT commands, and verify all three pass.

## 2. Island history and travel

- [ ] 2.1 Write `game/tests/unit/test_island_history.gd` (pure) and verify it fails. It checks:
  - previous on index 1, 2 and 3;
  - the off-graph cay skipped (main spec "Caught after the detour");
  - islands reached as the highest index (the spec's "Counted once").
- [ ] 2.2 Write `game/tests/unit/test_capture_travel_solo.gd` and verify it fails. It uses one offline player, the fixture chain, and the real sandbar and coast cay. It covers:
  - the restart of island 2 from island 3 with pick-ups as on first arrival ("Previous island is fresh");
  - island 1 restarting island 1 ("Caught on the sandbar");
  - a release from the sandbar onto the coast cay's first landing cell with no raft beached;
  - a release from the coast cay ending the run;
  - landing cells within 5 tiles.
- [ ] 2.3 Implement `game/scripts/run/island_history.gd` and the `IslandTravel` changes (design.md §8): the index in the travel message, `previous()`, and `travel` with `raft_integrity` 0 for a restart or a release. Verify both tests pass, and that `test_coast_cay_solo.gd`, `test_coast_cay_net.gd`, `test_arrival_by_vessel.gd`, `test_arrival_scatter_net.gd`, `test_run_restart.gd` and `test_secret_cay_solo.gd` still pass.
- [ ] 2.4 Run the import, smoke run and GUT commands, and verify all three pass.

## 3. Conditions and effects

- [ ] 3.1 Write `game/tests/unit/test_capture_conditions.gd`, beside `test_condition_check_routes.gd` and `test_effect_flags.gd`, and verify it fails. Its cases are:
  - `ANY_PLAYER` over an `ALL_OF` (one Maestro at morale 50 and one Médico at 70 passes; no background never passes);
  - `BACKGROUND_PRESENT` reading `PlayerBody.background_id`;
  - `TAKE_ITEMS_WITH_CAPABILITY LIGHT_FIRE` removing the lighter and keeping a KEEPSAKE-tagged item;
  - `TRAVEL_NEXT_ISLAND` and `TRAVEL_PREVIOUS_ISLAND` calling `IslandTravel` on the host only.
- [ ] 3.2 Implement them in `condition_check.gd`, `effect_applier.gd` and `inventory.gd`, and add `PlayerBody.background_id`, empty by default. Verify the test passes, and that `test_condition_check_routes.gd`, `test_effect_flags.gd` and `test_effect_delay.gd` still pass.
- [ ] 3.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 4. The chase at sea (pure, then the brain)

- [ ] 4.1 Write `game/tests/unit/test_boat_chase.gd` (pure) and verify it fails. It checks:
  - the speed of 6 tiles/s;
  - deep water only;
  - the haul at 2 s within 1 tile, reset on leaving;
  - breaks on a dive, shallows, land and 10 tiles;
  - land turning into a landing cause.
- [ ] 4.2 Implement `game/scripts/stealth/boat_chase.gd` and the boat's `CHASE` state in `patrol_route.gd` (design.md §1, §3). Verify the test passes and the stealth tests still pass.
- [ ] 4.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 5. Soldier sight (pure)

- [ ] 5.1 Write `game/tests/unit/test_soldier_sight.gd` and verify it fails. It checks the spec's "Soldier sight" scenarios on the cone geometry and the shared spot meter:
  - the day and night cones;
  - hidden players never seen;
  - fog;
  - the 5 against 6 tiles/s footrace breaking past 6 tiles.
- [ ] 5.2 Implement the soldier as a sight source in `SpotMeter`'s input, with the cone helper beside `searchlight.gd`. Verify the test passes and `test_spot_meter.gd` still passes.
- [ ] 5.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 6. The squad plan (pure)

- [ ] 6.1 Write `game/tests/unit/test_squad_plan.gd` and verify it fails. It checks:
  - the landing cell;
  - the dinghy's row time at 2 tiles/s;
  - the point order (fires nearest the landing first, then the last known position);
  - taking points, and the nearest free soldier taking a new last known position;
  - the 3 s point search finding within 2 tiles and not at 3;
  - the random walk being equal for equal seeds;
  - leaving at 180 s, the 60 s grace, no free player left, and a squall.
- [ ] 6.2 Implement `game/scripts/stealth/squad_plan.gd` (design.md §6). Verify the test passes.
- [ ] 6.3 Write `game/tests/unit/test_squad_search_coverage.gd`, which pins the simulated outcomes of design.md "The search, simulated". Verify it passes, and record its run time in design.md "Changes from the build plan" if it takes over 2 s. On both islands with the real plan and the shipped numbers, it checks:
  - a hidden player more than 2 tiles from every searched point is never found;
  - a still player in the open is spotted in 45–75% of 100 seeded runs.
- [ ] 6.4 Run the import, smoke run and GUT commands, and verify all three pass.

## 7. The soldier, captives and freeing

- [ ] 7.1 Write `game/tests/unit/test_search_capture.gd` on the brain with a test world and verify it fails. It checks:
  - the escort to the dinghy at 2 tiles/s;
  - the soldier going back to its plan;
  - the touch resetting when contact breaks;
  - downed and dropped bodies never targeted;
  - freeing on a 1 s hold with no soldier within 3 tiles;
  - the hold cancelled when a soldier comes within 3 tiles ("The guard comes back").
- [ ] 7.2 Write `game/tests/unit/test_capture_solo.gd` with one offline player on the real sandbar, driven by the named input actions only. Verify it fails. It covers:
  - spotted at night, running 10 tiles, crouching in scrub away from the fire, and the squad leaving after 180 s with the boat resuming its lap;
  - hiding 1 tile from their own fire and being found;
  - outrunning a soldier;
  - being hauled aboard while swimming in deep water, and escaping into the shallows;
  - a day fire bringing the squad.
- [ ] 7.3 Implement `game/scripts/ai/search_capture.gd`, the boat's `DOCKED` state, and the captive state on `PlayerBody` (design.md §5–§7). Verify the tests pass and `test_creature_spawner.gd` and the stealth tests still pass. The work is:
  - `_acting_body` refuses intents from a captive except quick chat;
  - the dragger is set to the soldier;
  - the captive is pinned in the dinghy;
  - the "Soltar" `Interactable` is added.
- [ ] 7.4 Run the import, smoke run and GUT commands, and verify all three pass.

## 8. Whole-party capture, taken captives and the router

- [ ] 8.1 Write `game/tests/unit/test_capture_rules.gd` (pure) and verify it fails. It checks:
  - who is free (downed, last stand, dropped, a waiting rider, a rider in a crossing);
  - the whole-party test;
  - "The last free player dies";
  - the taken rule;
  - the router: an island or a non-final crossing plays the scene, and a final-crossing capture skips both the scene and the check ("A final-crossing capture skips the scene").
- [ ] 8.2 Write `game/tests/unit/test_capture_taken_net.gd` with host plus client and verify it fails. It covers the spec's "Taken captives" scenarios:
  - the client's player is taken and lands on the coast cay with the Foto only;
  - the compass is laid on the landing beach and seen on both peers;
  - the island empties when the only other player waits on the next shore.
- [ ] 8.3 Implement `capture_rules.gd` and `capture_outcome.gd`, the out-of-play taken state, and the `IslandTravel.check()` change. Verify the tests pass, and that `test_escape_routes_solo.gd`, `test_arrivals_cap.gd` and `test_dropped_teammate_net.gd` still pass.
- [ ] 8.4 Run the import, smoke run and GUT commands, and verify all three pass.

## 9. The scene

- [ ] 9.1 Write `game/tests/unit/test_capture_scene.gd` and verify it fails. Using solo play, it checks:
  - the singular lines;
  - the second-capture opening after a restart;
  - the formal act;
  - the outcome's lines and effects for release, return and the car return (`almendron_hundido` set);
  - the speaker on a tie;
  - a player with no background failing the check;
  - the "Solo capture fails" and "Solo Médico talks their way out" scenarios with the fixture background;
  - every player out of play during the scene;
  - a downed player taken along standing at 30 health after it.
- [ ] 9.2 Implement `CaptureScene` and `game/scenes/ui/scene_panel.gd` (design.md §9). Verify the test passes, and verify by hand in a 300-frame solo run that the panel's text fits at 640×360.
- [ ] 9.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 10. Network

- [ ] 10.1 Write `game/tests/unit/test_capture_net.gd` with host plus client and verify it fails. It covers the spec's "Capture on every peer", "Captives", "Whole-party capture" and "The capture scene" scenarios:
  - a client frees a captive;
  - a far free request is refused;
  - a captive's intents are ignored while its quick chat goes through;
  - joining while the squad is ashore;
  - joining during the scene;
  - both peers showing the same line;
  - a downed teammate going along;
  - a captive client dropping and rejoining;
  - both peers' summaries counting the same islands reached.
- [ ] 10.2 Implement the sync and the `request_free` intent (design.md §13). Verify the test passes, and that `test_patrol_net.gd`, `test_creature_net.gd`, `test_coop_reconnect.gd` and `test_dead_spectate_net.gd` (if merged) still pass.
- [ ] 10.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 11. Fade with distance

- [ ] 11.1 Write `game/tests/unit/test_patrol_fade.gd` and verify it fails. Using the REEF fixture, it checks:
  - 26–34% with patrols over 1,000 seeds, each with one or two boats;
  - the same count on a second set-up from the same seed;
  - no rule for STORM or SHIPWRECK ("Far chain");
  - one player getting the base count.
- [ ] 11.2 Add the mid-chain rule to `patrol_boat.tres` (design.md §12). Verify the test passes and the stealth spawner tests still pass.
- [ ] 11.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 12. Cues, the two-process run and docs

- [ ] 12.1 Write `game/tests/unit/test_capture_cues.gd` with solo, and with host plus client, and verify it fails. It covers the spec's "Capture cues" scenarios:
  - the rope mark on both peers;
  - the prompt hidden while a guard is near;
  - the landing, spot and leaving calls in Spanish;
  - the open eye filling under a soldier's sight.
- [ ] 12.2 Implement the cues (design.md §14), with all text in `hud_text.tres`. Verify:
  - the test passes;
  - art-pass's "drawing never changes the simulation" test is extended to the soldier and the dinghy.
- [ ] 12.3 Run a host and a client as two processes on the sandbar at night, written as `game/tests/manual/guardacostas_capture_run.gd` after `patrol_run.gd`, on a free UDP port. Do not name it `capture_*.gd`, which is the screenshot tooling's prefix. Verify each of these by its log line:
  1. the squad lands and is seen on both;
  2. the client is captured and freed from the dinghy;
  3. both are captured;
  4. the scene plays on both;
  5. the restart lands both on the sandbar.
- [ ] 12.4 Update the docs with the confirmed numbers, and verify each edit by reading it back against the spec delta:
  - `docs/GAME_DESIGN.md` §9 (the dinghy, taken captives, the router);
  - `docs/BESTIARY.md` "Guardacostas patrol boat" (the chase) and "Shore squad" (sight, point searches, the dinghy, leaving, taken captives);
  - `docs/ISLANDS.md` "Chains and distance" (a 30% chance);
  - `docs/CHARACTERS.md` Rodríguez (*La captura*'s check and lines);
  - `docs/CONTENT_MANIFEST.md`;
  - `TASKS.md` §6, which ticks "Shore squad, capture, free-a-captive, `la_captura` scene" and keeps `balsero-lore` 9b.1 open for the chain rows.
- [ ] 12.5 Run the import, smoke run and GUT commands, and verify all three pass.

## Workflow follow-up

- Archive only after `guardacostas-stealth` is archived, because archive refuses this change's Alert delta until then. Before archiving, re-copy Alert from the merged main spec into this delta, re-apply this change's edits, and verify `openspec validate guardacostas-capture --type change --strict` passes with no archive warning.
- When the backgrounds change ships, it replaces the stub `maestro.tres` and `medico.tres`, and its tests drive the passing check without the fixture.
- When the final crossing exists, it connects `run_devuelto` and adds the main spec's "Solo player caught in the Straits" test.
- When chain route rows exist, `balsero-lore` 9b.1 adds its gate test on top of the flag this change sets.
