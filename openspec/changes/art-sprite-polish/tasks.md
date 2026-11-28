# Tasks

Rebuilds: `python -I tools/art/compose.py --packs C:/Users/liann/src/90miles/game/assets` (player parts), `python -I tools/art/creatures.py --packs C:/Users/liann/src/90miles/game/assets` (creatures), `python -I tools/art/fx.py` (ring and lying shadow), then `python -I tools/art/check.py game/assets/art` and the import twice. Every group ends with `godot --headless --path game --import` (twice), the smoke run and GUT passing, plus `python -m unittest` in `tools/art` when a tool changed. Headless GUT tests assert node state, z, draw order and sheet bytes, never a rendered screen; each group's windowed capture is its own task. "AR/" is the review's scratchpad folder named in design.md. Test paths are as on main; if the test-folders change has moved them, follow it.

## 0. Gate

- [x] 0.1 Start only after art-coast-pass (art wave 1) has merged into `main` and the coordinator says go. Branch from `main`. Re-read the merged `player_look.gd`, `player_pose.gd`, `creature_look.gd`, `crossing.gd` and `creature_threats.gd`, and update this design where they moved.
- [x] 0.2 Check that the before captures this change compares against are in `docs/art-pass/review-2026-11-14/before/` (tracked with the proposal; `before/README.md` names each source): `sandbar_day_swimming_west.png`, `cr_swim_deep_left_crop8.png`, `cr_lineup_day_crop6.png`, `cr_gull_swoop_down_crop8.png`, `cr_player_downed_crop8.png`, `hud_downed_solo.png`, `scrub_three.png`, `cr_water_day_crop5.png`, `crossing_shark.png` and `crossing_raft_squall.png`.
- Groups 1–4 need only 0.1. Group 5 also waits for art-terrain-polish C10 (scrub variants). Groups 6 and 7 also wait for crossing-gameplay (its shark tell, group 7 there) to merge.

## 1. Swim bob and ripple ring (C19, C20; SP3, SP2)

- [x] 1.1 Write the tests and see them fail:
  - `test_poses.py`: the swim cells come from walk frames 1 and 3, and the two swim cells of each facing differ above the water row;
  - `test_fx.py`: `fx.py` draws 3 ring frames of about 20×5 in #ffffff and #cbdbfc only, whole alpha, the same bytes on a second run, and nothing outside its out folder;
  - `test_player_art.gd`: a solo swimmer shows `Look/SwimRing`, ordered after Shadow and before Sprite, playing; a standing, diving or downed player hides it;
  - `test_palette_swap.gd`: `player_look.gdshader` no longer reads `art_on_ripple` or `art_water_alpha`, still cuts on the node-local y, and `art_common.gdshaderinc` is unchanged.
- [x] 1.2 Set `SWIM_FROM = (1, 3)` and rebuild the player parts. Verify that `test_the_head_anchors_of_the_default_look` still reads swim −16, and that only the swim cells changed in each part sheet.
- [x] 1.3 Add `tools/art/fx.py`, `fx.json` and the ring; add `game/assets/art/fx/swim_ring.tres` (4 fps) and its licence block; add `Look/SwimRing` and `PlayerPose.shows_swim_ring`; make the shader's cut hard (design D1). Verify `test_a_slot_0_swimmer_is_cut_at_the_feet_line_with_no_shadow` (updated to the hard cut), `test_swimmers_stand_out_on_shallows_and_deep` (counting the ring), `test_the_composed_look_keeps_the_frame_budget_with_the_ripple` and the `Look/Ripple` tests.
- [x] 1.4 Windowed 1-player capture with `tests/manual/capture_looks.tscn` and a solo sandbar swim west: compare with `before/sandbar_day_swimming_west.png` and `before/cr_swim_deep_left_crop8.png`. Record the ring's size and the bob in the build notes.

## 2. Crab (C25; SP8)

- [x] 2.1 Write the tests and see them fail: in `test_creature_art.gd`, the crab's `idle` has 3 unique frames in the order 0, 1, 0, 2 at 4–5 fps, `move` 4 frames at no more than 12 fps, no opaque pixel in a frame's two outer columns, the feet on row 15. Add the 1-player test: on the solo sandbar a still crab plays `idle` and a walking one `move`.
- [x] 2.2 Redraw `tools/art/fixes/creatures/land_crab.png` (design D6), update its sheet size in `creature_sheets.json` and its frames in `land_crab_frames.tres`. Verify `test_every_creature_has_frames_with_an_idle_within_the_budget`, `test_a_solo_crab_on_the_sand_has_its_shadow_under_it`, `test_a_client_crab_fed_positions_at_10_hz_plays_move_every_frame_then_idle`, the outline contrast check and `tools/art/test_creatures.py`.
- [x] 2.3 Windowed 1-player capture of the crab lineup by day and at night: compare with `before/cr_lineup_day_crop6.png`.

## 3. Gull flight (C25; SP10)

- [x] 3.1 Write the tests and see them fail: the gull's frames have `swoop_*`, `flee_*` and `return_*` facings in cells wider than 16 px, with no opaque pixel in a frame's outer column; the flying lift is 14–16 px. Rename `test_a_flying_gulls_shadow_stays_on_the_ground_8_px_below_its_sprite` and its `AIR_LIFT_PX` to the new lift. Add the 1-player test: a solo sandbar gull that swoops plays a flight animation with its shadow on the ground.
- [x] 3.2 Draw `tools/art/fixes/creatures/seagull_flight.png` (24×16 cells; design D7), add it to `creature_sheets.json` (a second gull sheet or a wider one), add the flight animations to `seagull_frames.tres`, and set the gull's `air_lift_px` to 15 in `creature_art.tres`. Record the fixes licence block (kitbashed from the Tiny Tiny Heroes gull; credit unchanged). Verify `test_the_shipped_recipe_names_tracked_hand_sources_and_whole_cells`, the perched-gull tests and the frame budget.
- [x] 3.3 Windowed 1-player capture of a swoop: compare with `before/cr_gull_swoop_down_crop8.png`.

## 4. Lying pose (C25; SP9)

- [x] 4.1 Write the tests and see them fail:
  - `test_poses.py`: the lying rule turns the rows below the neck and moves the head block unturned (the eye row stays one row); the lying figure is wider than tall; the per-layer invariant holds for every part;
  - replace `test_downed_is_the_down_frame_turned_clockwise_and_moved_down_with_a_chest_lift` with the lying rule and its chest lift;
  - `test_drop_shadow.gd`: the LYING size is a 22–24×5 ellipse in the darkest colour, and the existing sizes keep their enum values;
  - `test_player_art.gd`, 1-player: a solo downed player shows the lying frames over the LYING shadow, and a standing one the 12×7.
- [x] 4.2 Add the `LIE` rule in `poses.py` and use it for downed, the breath frame and dead (design D8). Rebuild the parts. Add the lying ellipse to `fx.py` and LYING to `DropShadow.Size`, appended; `PlayerLook` picks it for lying poses. Verify that `BALSERO_ANCHORS` downed and dead are re-measured and recorded, `test_a_solo_player_who_walks_crouches_swims_and_is_downed_is_drawn_from_those_cells` and the dead-is-not-downed tests pass.
- [x] 4.3 Windowed 1-player capture of a solo downed body and a dead one: compare with `before/cr_player_downed_crop8.png` and `before/hud_downed_solo.png`. If the remap still reads as a turned standing frame, stop and record it; a hand lying cell is a new task, not a silent switch.

## 5. Bush in front (C8; PR1) — after art-terrain-polish C10

- [x] 5.1 Write the tests and see them fail, in `test_player_art.gd` (or a new `test_bush_front.gd`):
  - 1-player: a solo sandbar player crouched on a scrub cell (read from the layout) shows `Look/BushFront` with the Brush layer's source, atlas coordinates and alternative at `body.cell()`, ordered after Sprite;
  - the same on a scrub variant cell (C10) and on a fitted shore bush;
  - off scrub, swimming and diving, it is hidden;
  - a palm one cell south is drawn after the body's subtree (the `test_draw_order.gd` reader);
  - host and client show the same tile for the client's player.
- [x] 5.2 Add `Look/BushFront` (design D5): it reads the island `TerrainView`'s Brush layer, shows the tile's front rows at the cell, and hides off scrub. Verify `test_art_sim_invariance`, `test_draw_order.gd`, `test_hidden_solo.gd` and the `test_terrain_view.gd` layer tests.
- [x] 5.3 Windowed 1-player capture of a crouched and a standing player in scrub: compare with `before/scrub_three.png`.

## 6. Shark redraw, facings and the fin off the deck (C24, SP4, SP1) — after crossing-gameplay merges

- [x] 6.1 Write the tests and see them fail:
  - `test_creature_art.gd`: `patrol`, `circle` and `move` have `_side`, `_up` and `_down`; no side frame's water-line row holds an opaque run longer than the fin's base plus a short dash; every frame's drawn pixels lie within 15 px of its centre; the `patrol` assertion follows the default down facing; `test_the_shark_fin_stands_out_on_shallows_and_deep_water` on today's and C7's shallows;
  - 1-player: a solo sandbar shark heading mostly north plays `patrol_up`;
  - a new crossing test, 1-player: in a solo raft crossing whose shark pass names the east side, and in a solo board crossing, the fin's drawn box (from its frame's non-clear texels and `CreatureLook`'s placement) never overlaps an intact deck or board rect from the warning to the retreat, and stays inside `sea_rect()`.
- [x] 6.2 Redraw `tools/art/fixes/creatures/reef_shark.png` with the facing rows (design D4), update `creature_sheets.json` and `reef_shark_frames.tres`. Verify `tools/art/test_creatures.py`, `test_crossing_creature_shark.gd`, `test_crossing_shark_dump.gd`, `test_crossing_shark_net.gd` and `test_crossing_art.gd`.
- [x] 6.3 If the fin test fails at the strike because crossing-gameplay still places the shark at `deck_center() + SHARK_OFFSET_PX`, do not move it in art: send the coordinator the failing frame and the seam (design "Owner decisions").
- [x] 6.4 Windowed 1-player captures: an island shark heading north and west, and a solo crossing's shark tell and strike. Compare with `before/cr_water_day_crop5.png` and `before/crossing_shark.png`.

## 7. Swimmer behind the deck (C22; SP5) — after crossing-gameplay merges

- [x] 7.1 Write the tests and see them fail, in `test_crossing_art.gd`:
  - 1-player: a swimmer 1 px north of the deck's top edge, within its span, is drawn after the sea and before the deck (Look z −21);
  - a swimmer beside the deck (`put_beside_deck`, east), one south of it, a rider aboard and an island swimmer keep z 0;
  - after the deck sinks, a north swimmer is back at z 0;
  - on a board route, a swimmer north of a board goes under that board.
  Update `test_the_crossing_sea_and_deck_lie_under_its_riders` with the north swimmer.
- [x] 7.2 Add the z swap to `PlayerLook.step` (design D2). Verify `test_art_sim_invariance`, `test_draw_order.gd` and the crossing tests.
- [x] 7.3 Windowed 1-player capture of a squall throw-in on the north side: compare with `before/crossing_raft_squall.png`.

## 8. Integration

- [x] 8.1 Rebuild every touched sheet to scratch and `cmp` it against the tracked ones, so the build is byte-for-byte reproducible. Run `check.py`, `python -m unittest` in `tools/art`, the import twice, smoke and GUT. All must be clean.
- [x] 8.2 Re-shoot `docs/art-pass/looks_swim.png`, `looks_downed.png`, `looks_crouch.png` and `crossing.png` with `tests/manual/capture_looks.tscn` and `capture_crossing.tscn`. Read the run logs for shader errors.
- [x] 8.3 Update `TASKS.md` and `docs/ASSETS.md` (the fx recipe), record the measured sizes and anchors in this design's build notes, and run `openspec validate art-sprite-polish --strict`.

## Workflow follow-up

- One PR per group (or two small groups together) into `main`, each with its before and after captures sent to the coordinating session.
- Archive the change after art-coast-pass is archived and the owner has seen the captures.
