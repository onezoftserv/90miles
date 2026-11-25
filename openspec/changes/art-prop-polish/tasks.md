# Tasks

**Art rebuilds.** Each rebuild runs the tool for the group with `--packs C:/Users/liann/src/90miles/game/assets` (`structures.py`, `items.py`, `terrain.py` for the shade row, the decor step), then `python -I tools/art/check.py game/assets/art`, then the import twice.

**Art rules.**
- Art goes only through the `tools/art/` recipes and the hand sources in `tools/art/fixes/`, with `png.py`. Never Pillow, and never paint into `game/`.
- The packs stay read-only.
- Every colour is on the master palette, and frames have 1 px outlines (D1's rule).
- Art never changes the simulation.

**Every group ends with:**
- `godot --headless --path game --import` twice, the smoke run (`-s res://tests/smoke.gd`) and GUT (`-s res://addons/gut/gut_cmdln.gd -gexit`) passing;
- `python -m unittest` in `tools/art` when a tool or a fix file changed;
- `test_art_sim_invariance` and `test_draw_order` green.

**Paths.** Test paths are as on main; if the test-folders session moved them, follow its layout. A path written `before/<name>` is in `docs/art-pass/review-2026-11-14/before/`.

## 0. Gate

- [x] 0.1 Wait for the coordinating session's go. Branch from main. Re-read `structure_sheets.json`, `item_icons.json`, `structure_art.tres`, `shelter_art.tres`, `decor_view.gd`, `island_sign.gd`, `palm.gd` and `TerrainView._build_decals` as they are then, since art-terrain-polish may have changed the decals.
- [x] 0.2 Group 4 waits for the owner's answer to QP1. Group 7 waits for coast-cay-reshape to merge.

## 1. The outline rule (D1; PR8, Q15 (a))

- [x] 1.1 In `tools/art/test_check.py`, write the family rule tests on fixtures and see them fail:
  - a creature sheet with a plum edge fails and is named;
  - the same edge on a structure passes;
  - an item icon with a #222034 edge fails.
  Add the 1-player test in GUT: the composed frames of a solo player's look have only black outline pixels.
- [x] 1.2 Add the family rule to `check.py` (family from the folder) and write it into `docs/ASSETS.md`'s "Outlines" line. Run it on the tracked tree. If any tracked file breaks it, stop and record the file in the build notes, and send it to the coordinating session as a question; do not redraw it here.

## 2. Five icons (D2; PR6)

- [x] 2.1 In `tools/art/test_items.py` and `test_item_icons.gd`, write the thickness test and see it fail on today's five: outline pixels at most half of each icon's opaque pixels. Add the 1-player test: a solo player picks up the nails on the coast cay and the redrawn icon shows on the ground and in the strip.
- [x] 2.2 Draw `nails`, `tarp`, `crab_cooked`, `hutia_cooked` and `iguana_cooked` as hand sources in `tools/art/fixes/items/` and point `item_icons.json` at them. Rebuild. Verify `test_no_two_items_share_a_silhouette`, `test_every_item_has_a_16x16_icon_inside_the_box_with_its_outline` and that `dry_grass` is byte-identical.
- [x] 2.3 Windowed 1-player capture of the strip holding the five, compared with `before/items_sheet.png` and `before/p17_icons_x3.png`.

## 3. The rain catcher's tarp (D3; PR8)

- [x] 3.1 In `test_rain_catcher.gd` or `test_structure_looks.gd`, write the test and see it fail: every catcher frame holds the tarp's colours over the barrel. Add the 1-player test: a solo player's catcher shows the funnel empty and with water in its mouth at one cup.
- [x] 3.2 Draw the funnel as a hand layer in `tools/art/fixes/structures/` and add it to the catcher's recipe. Rebuild. Verify the frame size is unchanged and the existing catcher tests pass.

## 4. Palm looks (D4; PR7) — after QP1

- [x] 4.1 Write these tests first and see them fail:
  - in `test_structure_art.gd`, the look pick is `cell_hash` based and gives the same look twice;
  - every look keeps `nest_point` and the trunk base;
  - the foot shade is centred under each look.
  Add the 1-player test: the sandbar built for one offline player twice uses more than one look with the same look per palm both times, and a gull perches on the nest point of a nest palm of each look.
- [x] 4.2 Draw the looks as the owner chose in QP1, with their coconut and nest overlays, in `tools/art/fixes/structures/`. Add them to the recipe and a palm look table to `StructureArtData`, and pick the look in `palm.gd`. Rebuild. Verify `test_the_palm_stands_on_its_trunk_base_with_the_nest_in_its_crown`, the coconut and nest tests in `test_structure_art.gd` and `test_structure_looks.gd`, and `test_the_art_scripts_call_no_random_number_generator`.
- [x] 4.3 Windowed 1-player capture of the sandbar's palms, compared with `before/sandbar_day_palms_crop3.png` and `before/two_palms_col_x3.png`.

## 5. The lean-to (D5; PR2)

- [x] 5.1 Write these tests first and see them fail:
  - in `test_lean_to.gd`: the frame stays 64×48 on its anchor; no transparent pixel lies inside the roof's outline; the eave's lowest row is not one straight run; each post has a contact shadow;
  - in `test_terrain_view.gd`: a shelter's shaded cells take the north-weighted shade row.
  Add the 1-player test: on the sandbar built for one offline player, all 12 shaded cells have a shade decal whose alpha is highest on its north rows.
- [x] 5.2 Redraw `lean_to_frame.png`, `lean_to_roof.png` and `lean_to_eave.png`, and add the post shadows to `lean_to.tscn`. Add the north-weighted shade row to the shade step in `terrain.py` and its pick in `TerrainView`, rebased on art-terrain-polish's C14 decal edits. Rebuild. Verify `test_the_lean_to_stands_on_the_hut_back_edge_with_its_roof_over_the_row_north`, `test_a_solo_player_in_the_hut_and_its_tarp_and_driftwood_sort_in_front_on_the_shade` and `test_a_solo_player_one_tile_north_of_the_hut_sorts_behind_the_roof`, and the tile-set counts.
- [x] 5.3 Windowed 1-player capture of the hut, compared with `before/sandbar_day_hut_crop4.png`, `before/hut_c3.png` and `before/s_lean_to.png`.

## 6. The hidden cay's scenery (D6; PR4)

- [x] 6.1 Write these tests first and see them fail:
  - in a new `test_decor_art.gd`: each decor id of `cayo_sin_norte.tres` draws its piece; upright pieces are children of the y-sorted `DecorPieces` and sort by foot position; the post in the shallows has its foot; an id with no art draws its colour square;
  - the stub's wisp has at most 4 unique frames at most 12 fps.
  Add the 1-player test: the hidden cay built for one offline player shows every piece and no colour square, and Platino stands on the chest's ledge.
- [x] 6.2 Draw the pieces as hand sources and cut Platino from DawnLike `Characters/Reptile0.png` through a `tools/art/` recipe. Add DawnLike's licence block and credit to the tracked folder, `CREDITS.md` and the credits data. Add `DecorArtData` and `decor_art.tres`, and draw from it in `DecorView`. Rebuild. Verify `test_he_left_minutes_ago`, `test_art_tracked` and the credits tests.
- [x] 6.3 Tick TASKS.md's Platino item and the decor-cell part of the secret-cay art item. Windowed 1-player capture of the hidden cay with `scenes/dev/secret_cay_playground.tscn`, compared with `before/secret_cay_decor.png`.

## 7. The garita and the sign looks (D7; PR3, Q12 (a)) — after coast-cay-reshape

- [x] 7.1 Write these tests first and see them fail:
  - rewrite `test_lean_to.gd`'s `test_the_coast_cay_shaded_cells_get_no_lean_to` into "the coast cay's shaded cells get the garita", anchored on the post's back edge;
  - in `test_structure_art.gd`, a sign with no look draws `sign_post.png`, and a look draws its texture;
  - every post cell is as walkable with the garita as without it.
  Add the 1-player tests on the coast cay built for one offline player:
  - on the post's back row, the player, the nails, the mirror and the radio draw in front of the garita;
  - one tile north of the post, the roof draws over the player;
  - the four signs show their looks and reading each opens its note.
- [x] 7.2 Draw the garita and the three sign looks as hand sources, with no legible letters. Add `garita.tscn`, `coast_cay` in `shelter_art.tres`, `IslandSignData.look`, `StructureArtData.sign_looks` and the pick in `island_sign.gd`. Set `look` on the coast cay's four signs. Rebuild. Verify `test_island_layout.gd`, the coast cay tests, `test_structure_looks.gd` and `test_structure_art.gd` with the default key, and the content validator.
- [x] 7.3 Windowed 1-player capture of the post, compared with `before/cay_day_observation_post_crop4.png`, `before/cay_day_observation_post_x3.png` and `before/cay_day_rocky_point.png`.

## 8. Integration

- [x] 8.1 Rebuild every touched sheet to scratch and `cmp` each against the tracked file, so the build is reproducible. Run `check.py`, `python -m unittest` in `tools/art`, the import twice, smoke and GUT. All must be clean.
- [x] 8.2 Update `TASKS.md`. Record the measured sizes, looks and placements in this design's build notes. Run `openspec validate art-prop-polish --strict`.

## Workflow follow-up

- Open one PR per group into `main`, and send the coordinating session each link with its before and after captures.
- Archive the change after the owner has seen the captures (not in these PRs).
