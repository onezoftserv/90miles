# Tasks

The owner answered (a) on all eight questions on 2026-11-15 (design.md "Owner decisions"). Groups 1–2 are PR 1 (the mend) and can go before crossing-gameplay. Group 3 is PR 2 (the fittings) and waits for crossing-gameplay's three PRs.

## 0. Owner answers and sequencing

- [x] 0.1 Record the owner's answers to Q1–Q8 in design.md "Owner decisions" and in proposal.md. If any answer is not (a), update the affected specs and these tasks. Verify that `openspec validate island-stop --strict` passes.
- [ ] 0.2 Before group 3, confirm that crossing-gameplay's three PRs are merged. Before task 2.6, rebase onto the guardacostas-capture build if it has landed, because both edit `game/scripts/levels/island_travel.gd`. Verify that `git log main` shows the merges.

## 1. Vessel recipes as data

- [x] 1.1 Change the data scripts and the content check:
  - add `vessel_modifiers: Array[ModifierData]` to `game/scripts/data/recipe_data.gd`;
  - append `VESSEL_HAZARD_DAMAGE` and `VESSEL_DECK_SHADE` to the end of `ModifierData.Stat`;
  - teach the content check that a `VESSEL_REPAIR` recipe needs `integrity_delta` > 0, that a `VESSEL_UPGRADE` recipe needs `integrity_delta` or a vessel-scoped modifier, and that both use `station = NONE` and `build_site = false`.
  Verify with a new `game/tests/unit/test_vessel_recipes.gd`: it accepts a valid repair recipe, refuses one with neither field, refuses one on the workbench station, and existing enum values keep their numbers.
- [x] 1.2 Add `game/resources/recipes/raft_mend.tres`: "Remiendo", 1 driftwood and 1 rope, 10 s, Building ×2, `integrity_delta` 20, `station = NONE`, with Spanish and English names and the D9 draft description. Verify that the content check reports no errors and that the workbench list on the sandbar still reads only "Fogata" and "Recogedor de lluvia".
- [x] 1.3 Update the crafting-inventory test for "A solo player crafts every recipe" so that a vessel recipe is crafted at a built raft. Verify that the test passes with `raft_mend` in the catalog.

## 2. The mend on the island (PR 1)

- [x] 2.1 Give `Raft` (`game/scenes/structures/raft.gd`) a maximum, a fittings list and at most one open job, reusing the build-site deposit and work logic. The mend gives +20 up to the maximum and is refused at the maximum.
  Verify with a 1-player, offline GUT test of each escape-routes "Mending a built raft" scenario:
  - 48 → 68 on the coast cay;
  - two mends to 88;
  - stopping at 100;
  - a whole raft refusing a mend;
  - a Mecánico in 5 s.
  Built: `Crafter.recipe_time` divides by the recipe's `skill_speed_multiplier` when the player's background lists the recipe's skill, which also gives the raft build its promised 2×. No Mecánico background ships yet (only the Maestro and the Médico), so the test checks the rule with the Maestro and a Navigation recipe. The Mecánico's own 5 s mend is tested when the backgrounds change adds it.
- [x] 2.2 Add the raft's work point on the land-side neighbour cell, picked by the host from the layout, and keep the launch Interactable and its 1 s hold unchanged. Verify with tests:
  - from the sea side the picker offers "Zarpar en la balsa", and from the land side "Arreglar la balsa";
  - both peers place the point on the same cell;
  - the existing launch tests still pass.
- [x] 2.3 Build the raft's HUD:
  - the raft list in the crafting-list panel, with its state head line;
  - the dimmed rows and the two refusal reasons;
  - the state line and warning line in the launch prompt;
  - the job prompt "[E] Trabajar en <recipe>" with build-site lines;
  - the new ids appended to `game/resources/hud_text.tres`.
  Verify with 1-player tests of every inventory-hud scenario in this change ("Solo at a worn raft", "A fitted raft" as 90 of 120 with no warning, its fittings on a line of their own (the mend's name stands in for a fitting's until PR 2), "Solo opens the raft's list on the coast cay", the two refusals, "Solo mend missing its rope").
- [x] 2.4 Route a client's start, deposit and work on a raft job through the host as interact intents. Verify with host-plus-client GUT tests:
  - "Two players pool a mend";
  - "One job at a time" (a forged second start is refused);
  - "Nobody working" (a 1-player test);
  - "A client starts a mend".
  Built in `test_raft_job_net.gd`. A client's start goes through `CoopSession.craft` with the raft's path, and its deposit through `CoopSession.deposit`.
- [x] 2.5 End an open job on launch: give each deposit back to its depositor, or drop it on the raft's cell when that inventory is full. Verify with a 1-player test of "Solo launches in the middle of a mend", a 1-player test whose depositor's inventory is full, and a 2-player test that gives a client's rope back.
- [x] 2.6 Carry the raft's state to every peer:
  - the host pushes the integrity, the maximum, the fittings and the open job on every change;
  - a client's raft asks for them as it appears, and again when the world state arrives, as a level site does;
  - a raft beached on the next island keeps its integrity, with the recipe's maximum.
  Verify with tests:
  - "A joiner reads a half-done mend" (integrity 90 and the job at 50 %, no host error);
  - "Solo fits offline" (nothing sent);
  - the existing arrival and late-join tests stay green.
  Changed from the plan: the record `{integrity, max, fittings}` through `travel_to` and the join extras moves to task 3.5. In PR 1 the maximum is always the recipe's 100, so the float `travel_to` already carries is enough, and `island_travel.gd` stays untouched while capture-build edits it.
- [x] 2.7 Write the docs:
  - GAME_DESIGN §6 "Durability": the mend's numbers and "no gate: a raft can always sail on";
  - TASKS.md: tick the mend and add the follow-ups (`night-ashore`, the launch seen by the patrol with the cutter boss).
  Verify that the docs match the specs' numbers.
- [x] 2.8 Run `godot --headless --path game --import` (twice on a fresh checkout), the smoke run `-s res://tests/smoke.gd` and GUT `-s res://addons/gut/gut_cmdln.gd -gexit`, and check that they all pass. Run the project through the Godot MCP and check that it runs clean. Run a host and a client locally, and check that a pooled mend and a late joiner work.
  Done 2026-11-15:
  - The import ran twice on a fresh worktree and is clean, and the smoke run reports 0 problems.
  - GUT gave 2408 of 2410. The two failures were this PR's own (the every-recipe test left the player at the raft; an unbuilt raft showed "Balsa 0/0"). Both are fixed, and every touched file was rerun green.
  - The Godot MCP run showed no errors and one new warning (a ternary in `craft_list.gd`), which is fixed.
  - Two processes on UDP 7798 (`tests/manual/island_stop_run.gd`): host 16/16 and client 11/11, with 0 engine errors. That run's client joined in the lobby. The late joiner is checked in-process over ENet (`test_raft_job_net.gd`, "A joiner reads a half-done mend").

## 3. The fittings (PR 2, after crossing-gameplay)

- [ ] 3.1 Add the fitting recipes, each with `station = NONE` and Spanish and English names and the D9 draft descriptions:
  - `raft_clavazon.tres`: 4 nails, 20 s, `integrity_delta` 20, raising the maximum and integrity by the same amount (D3), with no `VESSEL_MAX_INTEGRITY` modifier;
  - `raft_defensas.tres`: 1 inner tube and 1 rope, 10 s, `VESSEL_HAZARD_DAMAGE` MULTIPLY 0.75 (or the factor the owner picks in Q3);
  - `raft_toldo.tres`: 1 tarp and 2 driftwood, 15 s, `VESSEL_DECK_SHADE` SET 1.
  Each is refused once the raft has it. Verify with 1-player tests:
  - "Solo nails the raft on the coast cay" (70 of 100 → 90 of 120);
  - "Solo puts a toldo on the sandbar raft";
  - "A fitting only once";
  - "Fittings from data", which loads all four recipes with no content-check errors.
- [ ] 3.2 Bring a raft's maximum to sea: the crossing starts at the beached integrity and maximum, planks stop at the maximum, and the frame's look uses the share of the maximum (crossing "Vessel look on the crossing", modified). Verify with 1-player tests:
  - "Solo launches a nailed raft" (90 of 120, then 60 after a tied squall);
  - "A plank stops at the maximum";
  - "The look follows a fitted raft's maximum";
  - the existing car and board look tests still pass.
- [ ] 3.3 Apply `VESSEL_HAZARD_DAMAGE` to rocks and debris, the reef line's rocks included, leaving leaks, squalls and sharks unchanged. Verify with 1-player tests:
  - "Solo rock on the defensas" (70);
  - "A squall is unchanged" (70);
  - "Debris on the defensas" (96.25 and a leak).
- [ ] 3.4 Make the toldo shade the deck: mark the crossing's deck cells as shaded on its `GridTerrain` when the vessel has `VESSEL_DECK_SHADE`. Verify with 1-player tests:
  - "Solo midday crossing under the toldo" (11:00, calm, 75 s: heat 0, thirst 72.5);
  - "The same crossing without the toldo" (thirst 65, sunstroke).
  Set the clock after `solo_requested`, as in the crossing-gameplay notes.
- [ ] 3.5 Carry fittings through the crossing, replacing the beached-integrity float with the record `{integrity, max, fittings}` in `IslandRoutes` (departure), `CrossingResult`, `IslandTravel` (`_beached_raft()`, `travel_to`, the join extras "raft") and the island's beaching (moved here from task 2.6):
  - the record's fittings go in the crossing result;
  - the beached raft keeps them;
  - a broken raft loses them;
  - the sturdiest raft keeps its own fittings;
  - the crossing snapshot gains a required key "raft", and the hand-built snapshot dictionaries in the tests are updated.
  Verify with tests:
  - "Solo carries a toldo to the coast cay";
  - "A broken raft loses its fittings";
  - "The sturdiest raft keeps its own fittings";
  - "A joiner sees the fittings mid-crossing";
  - a snapshot without "raft" is refused.
- [ ] 3.6 Draw the toldo, the defensas and the clavazón on the raft frame, on the island and at sea. They are client-side and kitbashed from the tracked packs, with any new files under `game/assets/art/` and their licence. Verify that drawing changes no simulation test, and take a screenshot through the Godot MCP of a fully fitted raft on the coast cay and at sea.
- [ ] 3.7 Write the docs:
  - GAME_DESIGN §6 "Crafting": the three fittings;
  - GAME_DESIGN §8: the toldo and the defensas at sea;
  - ITEMS.md: the uses of nails, tarp, inner tube and tire;
  - `game/assets/CREDITS.md`, if new art was copied.
  Verify that the docs match the specs.
- [ ] 3.8 Run the import, the smoke run and GUT, and check that they pass. Run the project through the Godot MCP and check that it runs clean. Run a host and a client locally, and check that the fittings show on both peers at sea and after arrival.

## 4. Integration check

- [ ] 4.1 Play one solo run, offline, through the Godot MCP:
  1. Build the sandbar raft and fit the toldo.
  2. Cross at midday and check that there is no sunstroke.
  3. On the coast cay, mend, nail and fit the defensas.
  4. Relaunch, and check that the summary shows. Also relaunch at once on a second run, and check that the warning line shows and the launch is not refused.
  Verify that the run is clean, with no errors in the debug output.
- [ ] 4.2 Run a co-op host and client. Pool a mend on the coast cay, fit a toldo, and have a third peer join both while the raft is beached and during the next crossing. Verify that every peer shows the same raft state.

## Workflow follow-up

- Archive the change with `/opsx:archive` once both PRs are merged and the owner has played the stop.
- Propose `night-ashore` next if the owner keeps Q8(a).
