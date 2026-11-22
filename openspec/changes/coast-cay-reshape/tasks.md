# Tasks

Every group ends with the import twice (`godot --headless --path game --import`, the second run clean), the smoke run (`-s res://tests/smoke.gd`) and GUT (`-s res://addons/gut/gut_cmdln.gd -gexit`) passing. Test paths are as on main; if the test-folders work has moved them, follow it.

## 0. Gate

- [x] 0.1 Start only when art-coast-pass (wave 1) has merged into main, so the authors see rounded corners, and the coordinating session has said go. Branch from main.
- [x] 0.2 Read the merged state of everything that pins the cay: the coast-cay-bench change (archived or still open) and its tests, guardacostas-stealth's patrol tests, and art-terrain-polish if it has landed. Confirm on main the cells of design D2 (landing, raft site, bench and its dry grass, post block rows 38–40 × columns 63–67, rope cache, aloe, lagoon, drinking spot (22, 21), palms), and note today's pinned numbers in this design's build notes.

## 1. Tests first

- [x] 1.1 In `game/tests/unit/test_coast_cay_layout.gd`, write the outline tests of design D1 on the built layout:
  - no coast run and no rock seam run is longer than 10 cells;
  - the rocky point's southmost three rows are each at most half its widest row, and the post block has rock on all four sides;
  - driftwood groups of 1–3 and at most 3 per row or column;
  - 25–45 scrub cells, every clump at least 4 with a 2×2 block;
  - every pick-up, palm and sign cell has at least two land corners.
  See them fail on today's map, and record the failing measures (expected: runs of 36, 32, 26 and 19, a seam of 23, tip rows 11, 10 and 8 of 11, one row holding 6 driftwood, 29 lone scrub cells).
- [x] 1.2 In `game/tests/unit/test_patrol_coverage.gd`, if not already pinned, add the coast-cay-bench rule that the bench and its 8 neighbours are never lit in one lap. Verify it passes on today's map.
- [x] 1.3 The 1-player check is the existing set, which must stay green on the new map with no edit: `test_coast_cay_solo.gd` (`test_solo_arrives_on_the_coast_cay`, `test_solo_takes_the_post_nails_and_builds_a_raft`, `test_solo_drinks_the_lagoon`, `test_solo_lights_a_fire_with_the_lighter_in_one_second`), `test_coast_cay_layout.gd` `test_a_lone_arrivals_walks` and `test_everything_is_in_reach_of_a_lone_arrival`, and `test_coast_cay_bench.gd` `test_solo_lights_a_fire_at_the_coast_cays_bench`. Add one assertion to `test_a_lone_arrivals_walks` that the workbench is a 1–4 s walk, if it is not there yet.

## 2. The new outline

- [x] 2.1 Write the one-off helper of design D7 in the build session's scratchpad (not tracked): it reads the rows, rounds the land mask with a few cellular-automaton passes with the D2 cells pinned, and prints every D1 measure, the land count and share, the farthest land from water and the bench's smoke margin for a candidate.
- [x] 2.2 Re-author the rows of `game/resources/islands/coast_cay.tres` (design D3–D6): the bight, the rock taper and its seam jogs, the jogs on the long coasts, the driftwood groups, the scrub clumps and the flotsam line on straight-edge cells. The legend, pick-up entries, signs and fields stay. Aim at 1,010–1,080 land cells. Verify that the outline tests pass and that the rest of `test_coast_cay_layout.gd` passes: the land band and share, the 6-tile rule, the counts, the post, the landing, the reach, the walk bands and the lagoon's 30–60 cells.
- [x] 2.3 Verify that the coast-cay-bench tests pass unchanged apart from `LAND_CELLS`: the bench on unshaded beach, its smoke margin, its walk and the dry grass beside it.
- [x] 2.4 Run `test_patrol_coverage.gd`. If the cay's spotted share leaves 34% ± 3 points, its raft site is no longer lit, or the bench neighbourhood is lit, stop: send the measures to the coordinating session as an owner question and do not re-pin (design D8).

## 3. Re-pins

- [x] 3.1 Re-pin, each with a one-line reason in the test's comment and in the build notes: `test_coast_cay_bench.gd` `LAND_CELLS`; the coast cay row of `test_terrain_art.gd` `test_layer_cell_counts_of_the_two_islands` (with art-terrain-polish's C9 counted if it has landed); `test_shoreline.gd`'s shore-cell count; `test_patrol_loop.gd`'s perimeter; `test_patrol_triggers.gd`'s farthest land and land beyond 2, 3 and 6 tiles.
- [x] 3.2 Verify, with no edit, that these pass: `test_structure_art.gd` (the raft site at (19, 45)), `test_terrain_view.gd` (a rock shore cell, the post's corner set), `test_arrival_scatter.gd` and `test_arrival_scatter_net.gd`, `test_lean_to.gd`, `test_handmade_layouts.gd`, `test_draw_order.gd`, `test_creature_spawner.gd`, `test_coast_cay_net.gd`, `test_coast_cay_bench_net.gd` and the secret-cay tests. Any other pinned number that moved is explained here, never edited away silently.

## 4. Docs

- [x] 4.1 Update `docs/ISLANDS.md` §2: the shape sentence, the land count and share, and the walks from the first landing cell as measured. Update `TASKS.md`.

## 5. Sandbar notches (QC1 (a), the owner's "Yes, fill them", 2026-11-15)

- [x] 5.1 In `game/tests/unit/test_terrain_art.gd` or the sandbar's layout test, assert that cells (45, 20), (46, 20), (45, 51) and (46, 51) are beach. See it fail.
- [x] 5.2 Set those four cells of `game/resources/islands/sandbar.tres` to beach. Verify the sandbar's land band (940–1,100), share and 6-tile rule, its walk and reach tests, and re-pin its land (991 → 995), its Sand layer (994 → 998) and any shore, patrol or trigger count that moved, each with a reason. Update `docs/ISLANDS.md` §1 if it gives the land count.

## 6. Integration

- [x] 6.1 Run the import twice, smoke and GUT. All must be clean. No networking file changed, so no host-plus-client run is needed beyond the net tests in GUT; if one did change, run host and client locally before merging.
- [ ] 6.2 Windowed 1-player check: with `game/tests/manual/capture_terrain.tscn`, capture the coast cay by day and compare it with the review's before captures in `docs/art-pass/review-2026-11-14/before/` (`before/cay_day_inner_water.png`, `before/cay_day_rocky_point.png`, `before/coast_cay_day.png`, under `C:/Users/liann/AppData/Local/Temp/claude/3e391225d1d53c33/033b02a6-abc6-4589-bc32-d2c7f6771443/scratchpad/art_review/`). Re-shoot `docs/art-pass/coast_cay_day.png`. Walk a solo run from the landing to the post and back, and read the run log for errors.
- [ ] 6.3 Record the final measures, land count and re-pins in this design's build notes, and run `openspec validate coast-cay-reshape --strict`.

## Workflow follow-up

- Open the PR into `main` and send the coordinating session the link and the before and after captures.
- Archive the change after the owner has seen the captures (not in this PR).
