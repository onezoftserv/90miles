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

## 0. Preconditions

- [x] 0.1 Get the owner's answers to the ten decisions in proposal.md.
  - Where an answer differs from the recommended option, first update proposal.md, design.md, the three spec deltas and these tasks.
  - Verify: `openspec validate guardacostas-stealth --type change --strict` passes.
  - Done on 2026-11-14: the owner accepted (a) on all ten, so no artifact changed, and the strict validation passes.
- [x] 0.2 Wait for `structure-state-sync` (PR #42) and `creature-perch-ride` (PR #46) to merge. #42 merged on 2026-11-14 (main 4f8a92b) and #46 on the same day (main c20ad97). The build branch `claude/guardacostas-stealth-build` is main c20ad97 plus the docs commits. On the untouched branch: imports clean, smoke 10 frames with 0 problems, and GUT 197 scripts, 1728/1728 passing in 150 s.
  - Branch from the updated `main`.
  - Re-read these files as merged: `fire.gd`, `coop_session.gd`, `creature.gd`, `creature_spawner.gd`, `creature_world.gd`, `player.gd`, `player_net.gd`, `movement_model.gd`, `body_marks.gd`, `effect_applier.gd`, `sandbar_island.gd`, `horizon_line.gd`, `difficulty_scaling.gd` and `patrol_data.gd`.
  - If they drift from design.md, note the drift in a new design.md section, "Changes from the build plan".
  - Verify: the three commands pass on the untouched branch.

## 1. Patrol data

- [x] 1.1 Write `game/tests/unit/test_patrol_data.gd`. Verify it fails. It checks:
  - `PatrolData` has the new fields of design.md §12, with their defaults.
  - `creatures/patrol_boat.tres` loads with every value in design.md §12: category, tag, domain, behavior, senses, party fields, the two spawn rules, and every patrol number.
  - The patrol boat has at least one alert line and one give-up line in Spanish and in English, and the Spanish lines are formal (no `pa'` or `'tá` contractions).
  - The content check reports no problems for the shipped content, and reports each broken patrol fixture: a lap not shorter than its period minus its warning, a cone of 0° or more than 180°, a range of 0, a drain of 0, and missing lines.
- [x] 1.2 Append the new fields to `patrol_data.gd`, which keeps today's defaults for the old ones. Add the PATROL check to `content_validator.gd`, then add `game/resources/creatures/patrol_boat.tres` with the draft lines of design.md §9. Verify:
  - `test_patrol_data.gd` passes;
  - `test_data_classes.gd` still counts the same classes and folders;
  - `test_creature_content.gd` still passes.
- [x] 1.3 Add fixtures under `game/tests/fixtures/`. Verify each loads in `test_patrol_data.gd`:
  - `weather/fog_test.tres`: a `WeatherData` with `disabled_senses` [SIGHT];
  - `items/noise_test.tres`: an item whose use carries a NOISE effect of radius 15;
  - a small inline island layout helper for the loop tests;
  - `content/creatures/patrol_test.tres`: a copy of the patrol boat with a 45° cone and a 90 s lap, for "Retuned by data". It must live in the catalog, after `creature-perch-ride`'s fixtures, because `CoopSession.spawn_creature` re-reads a creature's data by id.
- [x] 1.4 Run the import, smoke run and GUT commands, and verify all three pass. Done: import clean, smoke 10 frames with 0 problems, GUT 198 scripts, 1743/1743 passing in 187 s (`test_patrol_data.gd` has 15 tests).

## 2. The loop (pure)

- [x] 2.1 Write `game/tests/unit/test_patrol_loop.gd`. Verify it fails. It checks, on `sandbar.tres` and `coast_cay.tres` and on a small inline island:
  - The loop (hull edges offset 4 tiles, mitred) has every half-tile sample on deep water, and no sample closer than 4 tiles to the hull.
  - The perimeter is within 1 tile of 180 on the sandbar and 195 on the coast cay.
  - The lap starts at the most easterly point and runs clockwise as seen on screen: the first step goes south.
  - `pose_at(t)` is the start point at 0 and at the lap's end, and moves at perimeter / lap tiles per second.
  - The phase is HORIZON in [0, 20), LAP in [20, 120) and AWAY in [120, 180).
  - Experiencia level 2 makes the period 200 s and leaves the lap at 100 s.
  - With four boats, each boat's clock runs 45 s behind the one before.
  - An island whose hull cannot be pushed onto deep water within 4 extra tiles gets no loop and logs a warning.
  - Every result is the same on a second build.
- [x] 2.2 Implement `game/scripts/stealth/patrol_loop.gd` (design.md §3) and an Experiencia seam that returns 0 until Experiencia exists. Verify `test_patrol_loop.gd` passes.
- [x] 2.3 Run the import, smoke run and GUT commands, and verify all three pass. Done: import clean, smoke 10 frames with 0 problems, GUT 199 scripts, 1763/1763 passing in 187 s (`test_patrol_loop.gd` has 20 tests).

## 3. The searchlight and the spot meter (pure)

- [x] 3.1 Write `game/tests/unit/test_searchlight.gd`. Verify it fails. It checks:
  - The beam's centre stays within 60° of the boat-to-centroid line, reverses at the ends and is back after 8 s.
  - A point 9.9 tiles away on the beam's centre is lit, and one at 10.1 tiles is not.
  - A point 29° off the centre is lit, and one 31° off is not.
  - Wrapping across ±180° is handled.
  - The light is on only in NIGHT, and off when the weather disables SIGHT (the fog fixture).
  - A copy of the data with a 45° cone sweeps a 45° cone.
- [x] 3.2 Write `game/tests/unit/test_spot_meter.gd`. Verify it fails. It checks the spec's "Spot meter" and "Stealth adds time" scenarios:
  - 1.5 s lit gives no spot, then the meter drains to 0 in 3 s;
  - 1.5 s lit, then 1 s out, then lit again: spotted 1 s later;
  - Stealth level 2 is spotted at 4 s and not at 3.5 s;
  - Stealth level 5 is capped at 5 s;
  - a hidden player never fills;
  - the meter resets after a spot;
  - a dead or dropped player is cleared.
- [x] 3.3 Implement `game/scripts/stealth/searchlight.gd` and `spot_meter.gd`, plus the Stealth seam, which sums `PATROL_SPOT_TIME` modifiers and gives 0 today. Verify both tests pass.
- [x] 3.4 Write `game/tests/unit/test_patrol_coverage.gd`, which pins the tuning. Verify it passes, and record its run time in design.md "Changes from the build plan" if it takes over 2 s.

  It steps one lap at 0.1 s on each island with the real loop, beam and meter. A still, unhidden player on every land cell must be spotted on 45% ± 3% of the sandbar's land and 34% ± 3% of the coast cay's (design.md's table). It also checks that the sandbar's raft site is never lit and the coast cay's is.

  If the owner picked other numbers in decision 4, use the matching row of the table.
- [x] 3.5 Run the import, smoke run and GUT commands, and verify all three pass. Done: import clean, smoke 10 frames with 0 problems, GUT 202 scripts, 1794/1794 passing in 211 s (31 new tests; `test_patrol_coverage.gd` takes about 3.5 s).

## 4. Hidden states

- [x] 4.1 Extend `test_movement_model.gd` with the new player-movement scenarios. Verify they fail:
  - standing on a roofed cell is HIDDEN, and stepping onto sand makes the player VISIBLE;
  - walking upright on mangrove is HIDDEN;
  - standing upright on scrub is VISIBLE;
  - crouching on scrub is HIDDEN;
  - diving is still SUBMERGED for at most 5 s.

  The existing "Crouching in brush" and "Crawling at zero energy" tests still pass.
- [x] 4.2 Write `game/tests/unit/test_hidden_solo.gd`. Verify it fails. It runs one offline player on the real sandbar, driven by the named input actions:
  - walking into the hut makes their stealth state HIDDEN;
  - `BodyMarks.has_mark` is true for them inside the hut;
  - outside the hut both are false.
- [x] 4.3 Implement `game/scripts/stealth/hidden_rules.gd`, `MovementModel.step(..., roofed)` and `player.gd`, which passes `terrain.is_shaded(cell)`. The client's prediction calls the same `step`. Verify:
  - both tests pass;
  - `test_movement_model_state.gd`, `test_body_look.gd`, `test_body_look_net.gd` and `test_hud_screens.gd` still pass.
- [x] 4.4 Run the import, smoke run and GUT commands, and verify all three pass. Done: import clean, smoke 10 frames with 0 problems, GUT 203 scripts, 1805/1805 passing in 210 s (10 new movement tests, 1 solo test).

## 5. The world event bus

- [x] 5.1 Write `game/tests/unit/test_world_events.gd`. Verify it fails. It checks:
  - A solo player using the noise fixture item puts one `noise` event on the bus, at their position with radius 15.
  - A place whose noise multiplier is 2 doubles a radius-10 noise to 20, through the `noise_multiplier_at` seam.
  - Lighting a fire raises one `smoke` event, `smoke_sources()` lists the fire until it goes out, and then it does not.
  - The bus is a child of the session, not an autoload, so `project.godot`'s autoload list is unchanged.
  - The existing creatures-ai scenario "Blood draws investigation" is not exercised. No creature emits blood yet; the main spec has the same gap today.
- [x] 5.2 Write `game/tests/unit/test_world_events_net.gd` with host plus client. Verify it fails. It checks that the client's player using the noise item raises the noise once, on the host, at that player's position, and that the client's bus emits nothing.
- [x] 5.3 Implement `game/scripts/world/world_events.gd`. Then:
  - add it in `coop_session.gd`;
  - expose it as `CreatureWorld.events`;
  - route NOISE and SMOKE in `effect_applier.gd`;
  - add a host-only `smoke_rose` call in `Fire.light()`.

  Verify both tests pass, and that `test_fire.gd` and `test_effect_delay.gd` still pass.
- [x] 5.4 Run the import, smoke run and GUT commands, and verify all three pass. Done: import clean, smoke 10 frames with 0 problems, GUT 225 scripts, 1986 tests with every test passing except `test_suite_integrity`, which flagged the unimported draft of group 6's test file lying in the tree during the run (10 new tests: 8 in `test_world_events.gd`, 2 in `test_world_events_net.gd`).

## 6. Trigger rules (pure)

- [ ] 6.1 Write `game/tests/unit/test_patrol_triggers.gd`. Verify it fails. It checks:
  - **Distance to the sea:** it matches design.md's table (farthest 5.7 on the sandbar and 6.3 on the coast cay; 617 and 632 cells more than 2 tiles from the sea), and the coast cay's lagoon is not sea.
  - **Smoke at night:** fires 1 and 4 tiles from the sea, and a fire on a roofed cell. Only the first alerts.
  - **Smoke by day:** a fire 5 tiles from the sea alerts, and dawn and dusk follow the night rule.
  - **Once per lap:** a fire alerts once per fire per lap.
  - **Noise:** radius 15 at 12 tiles is heard; radius 15 at 20 tiles and radius 6 at 3 tiles are not.
  - **Water:** a swimmer at 5 tiles is spotted, a diver at 3 tiles is not, and a floater at 5 tiles is spotted.
  - **Fog:** the water rule is off in the fog fixture.
  - **Out of sight:** a boat that is not in sight never triggers.
- [ ] 6.2 Implement `game/scripts/stealth/patrol_triggers.gd` (design.md §7). Verify the test passes.
- [ ] 6.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 7. The brain, the alert and spawning

- [ ] 7.1 Write `game/tests/unit/test_patrol_route.gd` on the brain with a test world. Verify it fails. It checks the states in order (AWAY, HORIZON, LAP and the two alert states, with the state names) and the spec's "Alert" scenarios:
  - **Lock and search:** a locked player keeps the beam on them while visible. Hiding or moving more than 10 tiles away gives a 20 s search 30° either side of the last known position, then LAP. A spot during the search re-locks and restarts the 20 s.
  - **The lap waits:** an alert 30 s into the lap, lasting 25 s, gives a 205 s loop.
  - **Smoke by day:** the boat stops for 20 s with no beam.
  - **The report:** `patrol_alerted` is emitted once per alert, with the cause and position.
  - **The lines:** `alert_serial` steps up at the start and at the give-up.
  - **A squall:** it ends any alert, sends the boat AWAY with no light, and the next HORIZON comes only after the squall ends.
- [ ] 7.2 Extend `test_creature_spawner.gd`. Verify it fails. It checks:
  - The sandbar gets one patrol for one player, and two for two or three players.
  - The coast cay's second boat comes from a roll seeded by the run seed and the island id: different run seeds give both outcomes, and one run seed always gives the same one.
  - With four players and a second boat, there are four boats 45 s apart.
  - The secret cay gets no patrol.
  - The reef shark, crab and gull counts are unchanged.
- [ ] 7.3 Write `game/tests/unit/test_patrol_solo.gd` with one offline player on the real sandbar, driven by the named input actions only. Verify it fails. It covers:
  - **(a) A whole night, never spotted.** The test grants the materials. The player builds and lights a fire in the hut at dusk, crouches in scrub or stands in the hut through every lap, and is never spotted. No smoke alert is raised.
  - **(b) Spotted, hide and get away.** Standing on open sand in the beam gets the player spotted at 2 s and locked. They walk 3 tiles to scrub and crouch, and are not spotted again. The boat resumes its lap 20 s later, and its loudhailer line showed.
  - **(c) A beach fire.** A fire 1 tile from the sea at night raises one smoke alert per lap. Putting it out during HORIZON raises none.
  - **(d) A swimmer.** Swimming 5 tiles from the boat by day is spotted at once. Diving 3 tiles away is not.
  - **(e) Fog.** In the fog fixture there is no light, and standing on open sand all night is never spotted.
  - **(f) A squall.** No boat is in sight during a squall.
  - **(g) The secret cay.** It has no patrol and no horizon light (via `test_secret_cay_solo.gd`'s setup).
- [ ] 7.4 Implement `game/scripts/ai/patrol_route.gd` (design.md §9). Then:
  - in `creature.gd`, add the `patrol_alerted` signal and the patrol fields;
  - in `creature_spawner.gd`, honor `party_extra_count_every_n_players`, pass member index and count, and seed the patrol roll from the run seed.

  Verify that the three tests above pass, and that `test_creature_net.gd`, `test_coast_cay_solo.gd` and `test_inventory_hud_solo_run.gd` still pass. A patrol now runs on both islands, so if a solo run gets spotted, it shows only the alert.
- [ ] 7.5 Run the import, smoke run and GUT commands, and verify all three pass.

## 8. Network

- [ ] 8.1 Write `game/tests/unit/test_patrol_net.gd` with host plus client. Verify it fails. It checks the spec's "Patrols on every peer" and "Spot meter" scenarios:
  - **The cone matches:** at night, at every sync over 5 s, the client's boat position and beam centre match the host's to within one sync interval's movement (0.1 s × speed, and 3° of beam).
  - **A mid-lap join:** a client that joins 40 s into a lap draws the host's pose and aim on its first frame.
  - **The client cannot claim hidden:** the client's player standing on sand inside the beam while sending crouch is still spotted at 2 s.
  - **The meter follows its player:** the client's player's meter reads 1 s and the host's player's 0, on both peers through `net_spot`.
  - **Two players:** a host plus one client on the sandbar gets two boats, 90 s apart.
  - **Nothing on the client:** the client runs no trigger and no spot, and `patrol_alerted` is never emitted on the client.
- [ ] 8.2 Implement the network side. Verify `test_patrol_net.gd` passes and `test_creature_net.gd`, `test_coop_reconnect.gd` and `test_weather_sync_net.gd` still pass. It is:
  - in `Creature.attach_sync`, `route_t`, `beam` and `alert_serial` for patrol creatures, as spawn properties;
  - the client derives the pose and beam between syncs (design.md §10);
  - `PlayerNet.net_spot` is added.
- [ ] 8.3 Run the import, smoke run and GUT commands, and verify all three pass.

## 9. Drawing and cues

- [ ] 9.1 Write `game/tests/unit/test_patrol_cues.gd` with solo, and host plus client. Verify it fails. It checks the spec's "Patrol cues" scenarios:
  - **The horizon light:** it shows for exactly the 20 s of HORIZON at night (a grey hull by day), clamped to the band, and goes when the lap starts.
  - **The open eye:** it shows over a player whose `net_spot` is above 0, half filled at 1 s, on both peers. It does not show while the closed eye does, and it goes at 0.
  - **The loudhailer:** a Spanish alert line shows over the boat for 3 s at an alert's start, and a give-up line at its end. Both peers show the same line.
  - **The text:** all HUD text is read from `hud_text.tres`.
- [ ] 9.2 Implement the cues. Verify:
  - `test_patrol_cues.gd` passes, along with `test_art_sim_invariance.gd` (extended to the patrol look), `test_draw_order.gd` and `test_hud_screens.gd`;
  - a `capture_looks` frame of the sandbar at night with the beam on the sand is saved to `docs/guardacostas-stealth/` for the owner.

  The cues are:
  - the patrol look (placeholder hull, and a `PointLight2D` cone under the night tint);
  - the horizon light on the HUD band;
  - the open-eye mark in `BodyMarks`;
  - the loudhailer speech bubble;
  - new `hud_text.tres` keys.
- [ ] 9.3 Run a host and a client as two processes on the coast cay at night. Write it as `game/tests/manual/patrol_run.gd`, after `art_pass_run.gd`, using a free UDP port. It checks:
  - the client's player is lit, spotted and locked, then hides in scrub and the boat gives up;
  - the client sees the same beam, horizon light, eye and line as the host;
  - the client quits and rejoins mid-lap, and draws the boat in place.

  Record the check counts and confirm there are 0 error lines.
- [ ] 9.4 Run the import, smoke run and GUT commands, and verify all three pass.

## 10. Docs

- [ ] 10.1 Update the docs with the confirmed numbers. Verify each edit by reading it back against the spec delta:
  - `docs/BESTIARY.md` "Guardacostas patrol boat": the loop, lap, arc, meter and alert;
  - `docs/GAME_DESIGN.md` §17 "Stealth": already updated with the docs PR on 2026-11-14; re-check it against the build;
  - `docs/ISLANDS.md`: the mangrove line (decision 7a);
  - `docs/CONTENT_MANIFEST.md`: tick `patrol_boat`.
- [ ] 10.2 Update `TASKS.md`:
  - tick `guardacostas-stealth` under Milestone D;
  - rename the next line to the `guardacostas-capture` change;
  - add a Done entry with the GUT count and the two-process run's numbers.
- [ ] 10.3 Run the import, smoke run and GUT commands, and verify all three pass.

## Workflow follow-up

- Open the PR, then archive the change after the owner's review (`/opsx:archive`).
- Next, propose `guardacostas-capture`: chase, shore squad, capture, free a captive, `la_captura`, the previous-island restart and capture on the final crossing, hooked to `patrol_alerted`.
