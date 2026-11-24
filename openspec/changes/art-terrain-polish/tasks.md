# Tasks

**Art rebuilds.** Every rebuild:
- runs `python -I tools/art/terrain.py --packs C:/Users/liann/src/90miles/game/assets`, plus `structures.py` or `remap.py` where a group says so;
- then runs `python -I tools/art/check.py game/assets/art`;
- then imports twice.

**Art rules.**
- Art changes go only through the `tools/art/` recipes and the `fixes/` overlays, with `png.py`. Never Pillow, and never paint into `game/`.
- The packs stay read-only.
- Every colour is on the master palette, with 1 px outlines.

**Every group ends with:**
- `godot --headless --path game --import` twice, the smoke run (`-s res://tests/smoke.gd`) and GUT (`-s res://addons/gut/gut_cmdln.gd -gexit`) passing;
- `python -m unittest` in `tools/art` when a tool or a fix file changed;
- `test_art_sim_invariance` and `test_draw_order` green.

**Paths.** Test paths are as on main. If the test-folders session has moved them, follow its layout.

**"Before" captures** are tracked in `docs/art-pass/review-2026-11-14/before/` (copied from the review folder with the proposal; `before/README.md` names each source). A path written `before/<name>` below means that folder.

## 0. Gate

- [x] 0.1 art-coast-pass (wave 1) merged into main at c0a1915 on 2026-11-15. Wait until this docs change is merged and the coordinating session says go. Then:
  - branch from main;
  - re-read the merged `terrain.py`, `terrain_tiles.json`, `sand.png` and `dune.png` overlays, `TerrainArt`, `ShoreRule`, `SeaMask` and the art-coast-pass build notes;
  - check that the design's assumptions still hold: the 1 px #d9a066 lip, the fit and tuft placements, the `"corners"` foam key, and fmix32 in `cell_hash`.
- [x] 0.2 Re-sync the MODIFIED "Shoreline overlay" block in `specs/art-pass/spec.md` with the art-pass text as art-coast-pass archived it (its scenarios included). Run `openspec validate art-terrain-polish --strict`.

## 1. TR14: the hole in a bush pick

- [x] 1.1 Write these tests first and see them fail on pick 3:
  - in `tools/art/test_terrain.py`, on the tracked recipe's made brush sheet: no row-4 brush pick has a clear or sand-coloured pixel inside its outline (a pixel the pick's opaque pixels enclose);
  - in `test_terrain_art.gd`, the same on `brush.png` as the game loads it.
  Add the 1-player test: on the sandbar built for one offline player, every lone scrub cell's brush tile (whichever pick its hash takes) has no sand pixel inside the bush's outline. It reads the sheet's bytes, not a render.
- [x] 1.2 Paint the 6 px gap at (55–57, 68–70) of `tools/art/fixes/terrain/brush.png` #37946e with a #4b692f and #323c39 inner edge (design D5, "The hole"). This reverses K39 (g)'s erase for that pick only. Rebuild. Verify that only `brush.png` and the sheets built from its picks change, and that `test_the_tracked_overlays_hold_only_hand_pixels` and the brush tests pass.
- [x] 1.3 Windowed 1-player capture of the sandbar's west shore at x6. Compare with wave 1's after capture, `docs/art-pass/review-2026-11-14/west_shore_bushes_x6_before_after.png`: its middle-right bush shows the hole.

## 2. C9: palms count as dune (TR11)

- [x] 2.1 In `test_terrain_art.gd`, write these tests and see them fail:
  - on a fixture, a palm with 3 or 4 dune or scrub orthogonal neighbours is a Dune member and never a Brush member, and a palm with 1 is on neither;
  - notch fixtures give a palm masks 3 and 10;
  - with no `palms` argument, every call gives today's result.
  Add the 1-player test: on the sandbar built for one offline player, palm (23, 31) is a Dune member with mask 7, and (23, 36) and (24, 42) are members. On the coast cay, derive from the layout that every palm whose eight neighbours all count takes Dune mask 15.
- [x] 2.2 Add the optional trailing `palms` parameter to `TerrainArt.is_member`, `layer_cells`, `corner_mask` and `tile` (design D1). Pass `built.palms` from `TerrainView`. Update `test_layer_cell_counts_of_the_two_islands` to Dune 425 on the sandbar and to the cay count recomputed from its layout, which is 397 today. Verify that `test_dune_and_scrub_shore_cells_on_the_sandbar_take_their_shore_sheets` and `test_every_land_cell_has_a_sand_tile_and_every_layer_its_rule` pass, and that `ShoreRule` is untouched.
- [x] 2.3 Windowed 1-player capture: compare the sandbar's palms and the cay's north dunes with the review's `before/cay_day_north_dunes.png` and `before/cay_palm_pit.png`. Note the result in the build notes.

## 3. The dune's inland corners (C3's dune part)

- [x] 3.1 Write these tests first and see them fail on today's `dune.png`:
  - in `test_terrain_art.gd`, on the made dune sheet:
    - every outer corner (masks 1, 2, 4, 8) ends in a quarter arc round its dune corner, within 2 px of the ideal arc, so the ragged lip still passes;
    - every inner corner (7, 11, 13, 14) and each side of a saddle (6, 9) ends in a bite at least 2 px deep along the diagonal (the most the straight edges allow);
    - every pair of dune masks that can sit side by side meets at the cell border without a jog (count them first; wave 1 measured 30 jogging pairs on the sand before its fix);
  Add the 1-player test: on the sandbar built for one offline player, every dune cell whose dune mask is a corner or a saddle (found from the layout, palms counted as C9 counts them) takes a dune tile that passes the arc and bite checks, and its four pinned corner pixels hold.
- [x] 3.2 Regenerate `tools/art/fixes/terrain/dune.png` by design D9 with a one-off helper (kept in the coordinating session's notes folder, `art-waves-2-5/dune_corners.py`, since wave 1's was lost): arcs on masks 1, 2, 4 and 8, fillets on 7, 11, 13 and 14, two each on saddles 6 and 9, the dune's ragged lip along each new edge, no tuft on a corner, and the straight masks' hand pixels, the row-4 picks and the hand islet (mask 0) kept. Rebuild. Verify with a byte diff that only `dune.png`, `dune_shore.png` and the shade built from them change, and that the straight dune tiles are byte-identical.
- [x] 3.3 Verify that these pass on the rebuilt sheets:
  - `test_the_tracked_overlays_hold_only_hand_pixels`: the dune's hand cell is still only (0, 0) with all 256 pixels, and each row-4 pick has under 40 overlay pixels;
  - `test_the_dune_edges_carry_no_tuft_and_the_islet_is_ragged`;
  - `test_each_corner_set_holds_mask_m_at_its_place`;
  - `test_no_shore_tile_of_an_upper_layer_leaves_the_sand_under_it` (dune shore);
  - `test_dune_and_scrub_shore_cells_on_the_sandbar_take_their_shore_sheets`.
- [x] 3.4 Windowed 1-player capture of the whole sandbar and its inner dunes. Compare with wave 1's after capture (`art-wave-1/after_sandbar_whole_island.png` in the coordinating session's notes folder, and `docs/art-pass/sandbar_day.png` as wave 1 re-shot it): the stair steps where the light dune meets the darker inner beach are gone.

## 4. C13: still water is still (TR13)

- [x] 4.1 In `test_shoreline.gd`, write these tests and see them fail:
  - `ShoreRule.still_water` finds a pond with no deep cell on a fixture, and not a bay joined to deep;
  - a shore cell with all its water neighbours in the pond takes source 1, and a cell touching both takes source 0;
  - the shore cell counts of both islands are unchanged.
  Add the 1-player test: on the coast cay built for one offline player, find the lagoon from the layout (the brackish body with no deep cell); every rim cell takes source 1 and every open-sea shore cell source 0.
- [x] 4.2 In `tools/art/test_terrain.py`, write the still-foam fixture tests: one tile per mask, all frames identical, a 1 px line on the first water step, no white. Add the still step to `terrain.py` and the recipe, building `sea/foam_still.png`. Add it as source 1 of `sea/shore_tiles.tres`. Verify with a byte diff that `foam.png` is unchanged.
- [x] 4.3 Implement `ShoreRule.still_water` and the source pick (design D2), and use them in `TerrainView`. Verify that `test_terrain_tile_sets.gd` checks both sources (`test_every_source_has_a_tile_exactly_where_its_sheet_has_art`, `test_the_foam_source_has_no_texture_padding`) and that the phase tests pass.
- [x] 4.4 Windowed 1-player capture of the cay's lagoon, compared with `before/cay_day_lagoon_crop4.png`.

## 5. C14: the raft on the sand (TR15)

- [x] 5.1 Write these tests first and see them fail:
  - in `test_drop_shadow.gd`, `SIZES` gains the 30×11 `WIDE` ellipse, still a soft ellipse in the darkest colour;
  - in `test_structure_looks.gd`, a raft and a site's half-built stage show the wide shadow, a marked site and its materials show none, and their frames are moved by `look_offsets` toward the land beside the origin;
  - in `test_crossing_art.gd`, the crossing deck's position is unchanged.
  Add the 1-player test: on the sandbar and on the coast cay built for one offline player, with a raft built at the site, the opaque pixels of the raft frame's bottom rows lie over land cells (read from the frame's image and the layout).
- [x] 5.2 Draw the 30×11 shadow as a hand file, copy it into `game/assets/art/shadows/` through the tools, and add its own-work block to `shadows/License.txt` and `CREDITS.md` if needed. Add `DropShadow.Size.WIDE`, `StructureArtData.look_offsets` and the stage-keyed site shadow (design D3). Map `raft` to `WIDE` in `structure_art.tres`. Measure and record the offset (16–24 px).
- [x] 5.3 Remove `WIDE_WEST`, `WIDE_EAST`, their offsets and the raft-site branch from `TerrainView._build_decals`. Rewrite `test_the_raft_site_holds_the_wide_shade_and_the_workbench_is_shaded` to check that the site has no decal and the workbench still has its shade. Verify that `_assert_stands_on_origin` still holds for every other kind, and that the raft's foot rect and the size range in `test_structure_art.gd` pass.
- [x] 5.4 Windowed 1-player run: build a raft solo on the sandbar. Compare the marked, half-built and built stages with `before/sandbar_day_raft_site_crop4.png`, `before/raft_stages.png` and `before/cay_day_landing.png`. Check that the interact prompt still reads on the hull.

## 6. C11: a beach with no grid (TR12)

- [x] 6.1 Write these tests first and see them fail:
  - in `tools/art/test_terrain.py`, the sand fill holds one stripe tone, and the four picks are distinct and not mirrors of each other;
  - in `test_terrain_art.gd`, a weighted `_variant` gives the clean pick for 60–80% of a 32×32 block.
  Add the 1-player test: on the sandbar built for one offline player, between 60% and 80% of its whole sand cells take the clean pick, and the picks repeat across two builds.
- [x] 6.2 Change the sand `map`, redraw the row-4 picks in the `sand.png` overlay, and retone the dune lip in `dune.png` (design D4). Add `TerrainArtData.variant_weights` and the weighted pick in `_variant`. Rebuild. Recompute the `art_tuning.tres` ground means. Verify that `test_the_variants_on_row_4_have_their_masks_corners_and_differ`, `test_the_sheets_hold_16_masks_and_8_foam_frames`, `test_the_dune_edges_carry_no_tuft_and_the_islet_is_ragged`, wave 1's corner and lip tests and the overlay hand-pixel test pass.
- [x] 6.3 Windowed 1-player capture of the sandbar's tide pools and dune edge, compared with `before/sandbar_day_tide_pools_crop4.png` and `before/cap_dune_edge.png`.

## 7. C10: scrub variety (TR10), in two PRs: C10a inland picks and the canopy, C10b shore variants

- [x] 7.1 Write these tests first and see them fail:
  - in `tools/art/test_terrain.py`: three mask-15 brush picks whose corner quarters are byte-identical to mask 15's; and the fit's `"variants"` placing each piece by the search, falling back when one does not fit.
  - in `test_terrain_art.gd`: the per-mask picks in `TerrainArtData`.
  Add the 1-player test: the secret cay's scrub block (`cayo_sin_norte.tres`), built for one offline player, uses more than one mask-15 pick, and the sandbar's shore scrub cells use at least two shore pieces.
- [x] 7.2 Draw the mask-15 picks and 1–2 small shore bushes as hand pixels. Add the second pick row, the `"variants"` fit key and `TerrainArtData.variant_masks` (design D5). Rebuild.
- [x] 7.3 Update `test_terrain_tile_sets.gd`'s brush shore count, `test_no_shore_tile_of_an_upper_layer_leaves_the_sand_under_it`, `test_dune_and_scrub_shore_cells_on_the_sandbar_take_their_shore_sheets`, and wave 1's (20, 35) atlas test. Verify that the 1500 ms bound in `test_the_layer_build_of_both_islands_is_timed_and_bounded` holds.
- [x] 7.4 Windowed 1-player capture of the secret cay's scrub and the sandbar's west shore, compared with `before/secret_cay_decor.png` and `before/sandbar_day_west_shore_mid_x3.png`.

## 8. C12: a rocky point with an edge (TR9)

- [x] 8.1 Write these tests first and see them fail:
  - in `tools/art/test_terrain.py`: the rock's rim is #323c39 and 4-adjacent; its north lip is lit; its water-edge face is 2–3 px and lighter and shorter than the cliff's; the pebble decal is at most 8×6.
  - in `test_terrain_view.gd`: pebble decals lie only on sand cells beside rock, chosen by hash.
  Add the 1-player test: on the coast cay built for one offline player, a rock cell with water to its south, found from the layout, draws the faced `plain_shore.png` tile.
- [x] 8.2 Implement the rim, the ragged edge and redrawn interiors in the `plain.png` overlay, the lip and face step in `terrain.py`, and the pebble decals (design D6). Rebuild. Verify that `test_each_plain_full_tile_is_seamless`, `test_no_tile_set_has_a_physics_navigation_or_occlusion_layer`, `test_the_art_scripts_call_no_random_number_generator`, `test_the_tracked_rock_has_the_pack_variant_and_two_hand_ones_that_keep_its_border` and the cliff test pass.
- [x] 8.3 Windowed 1-player capture of the cay's rocky point, compared with `before/cay_day_rocky_point.png` and `before/cay_day_rock_edge_crop4.png`.

## 9. C7: land and water apart by value (TR7)

- [x] 9.1 Write these tests first and see them fail:
  - in `test_art_palette.gd` or a new contrast test: the sand and dune means against the shallows mean at 1.6:1 or more, shallows against brackish at 1.4:1 or more, and deep < brackish < shallows in value;
  - in `test_terrain_art.gd`: the straight masks' lip uncovered in at least 4 of 8 foam frames.
  Add the 1-player test: on the sandbar built for one offline player, the sea uses the new shallows ramp, and the swimmer and fin contrast checks pass on shallows and deep.
- [x] 9.2 Darken the shallows ramp and move the brackish ramp in `terrain_tiles.json` (design D7). Add the new colours to `master_palette.png` and `.gpl` (at most 8, the palette at most 61 of 64). Lower the foam's `land_rows`, raise the dune and brush shore insets to 2, and repaint `fixes/terrain/tide_pool.png`'s water. Rebuild. Recompute the `art_tuning.tres` means. Verify that `test_in_every_frame_the_foam_is_one_band_on_the_sands_edge`, wave 1's foam corner tests, `test_the_tide_pool_is_irregular_with_a_few_stones_and_a_wet_sand_lip`, the crossing sea tests (the deep ramp is unchanged) and the palette tests pass. If the owner answers QT1 (b), add the second wet row in the same pass and amend wave 1's lip scenario.
- [x] 9.3 Windowed 1-player capture of the sandbar's west shore in colour and greyscale, compared with `before/sandbar_day_west_shore_mid_x3.png` and `before/west_mid_x3_grey.png`.

## 10. Integration

- [ ] 10.1 Rebuild every terrain, sea, decal and shadow sheet to scratch, and `cmp` each against the tracked file, so the build is reproducible byte for byte. Then run `check.py`, `python -m unittest` in `tools/art`, the import twice, smoke and GUT. All must be clean.
- [ ] 10.2 Re-shoot `docs/art-pass/sandbar_day.png`, `coast_cay_day.png` and `sandbar_night.png` with `tests/manual/capture_terrain.tscn`, and read the run logs for shader errors.
- [ ] 10.3 Update `TASKS.md`. Record the measured offsets, colours, pick shares and counts in this design's build notes. Run `openspec validate art-terrain-polish --strict`.

## Workflow follow-up

- Open one PR per group into `main`, and send the coordinating session each link with its before and after captures.
- Archive the change after art-coast-pass is archived and the owner has seen the captures (not in these PRs).
