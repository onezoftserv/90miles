# Design

## Context

See proposal.md for why. The review that found these problems, with root causes, measurements and mockups, is `docs/art-pass/review-2026-11-14/DESIGN_PASS.md`. It lands in the repo with art-coast-pass. The relevant parts are section 2.1 (TR7), section 2.2 (TR9 to TR15) and section 3, wave 2 (C7, C9 to C14). The review's own folder, with the "before" captures, is the AR path named at the top of that file.

How the terrain art is made after wave 1 (archived art-pass K35 to K47, plus art-coast-pass D1 to D6):
- `tools/art/terrain.py` builds every terrain sheet from the recipe `terrain_tiles.json`, three read-only packs, and the hand overlays in `tools/art/fixes/terrain/`. Run again on the same packs, it gives the tracked PNGs byte for byte (K35).
- The sand corner set is the shape behind the plain tiles, the three shore sheets, the foam and the shade.
- After wave 1:
  - corners are arcs and fillets;
  - every side ends in one 1 px #d9a066 lip, and the pack's #c08a5a ledge band is gone;
  - shore bushes are fitted whole, or replaced by a tuft on convex tips;
  - the cell hash goes through fmix32;
  - the deep edge is blurred and warped.
- At run time:
  - `TerrainArt.tile` picks atlas tiles by corner masks;
  - variants come from `cell_hash >> 1`;
  - `ShoreRule` gives every shore cell foam source 0 at atlas (0, mask), and the shore shader plays the 8 frames from the cell's phase;
  - `TerrainView._build_decals` lays the palm, workbench, shaded-cell and raft-site shade decals;
  - `StructureLook` draws the raft site's stages and the raft bottom-centre on the structure's origin, with the shadow its kind names in `structure_art.tres`.
- `CrossingDeck` draws the crossing deck from the same `raft` SpriteFrames.

Constraints:
- Art never changes the simulation. The tile sets have no physics, navigation or occlusion layer. A palm counted for the dune is a drawing rule; the palm cell stays beach for walking, climbing and stealth.
- Keep the 1 px outlines, the master palette (at most 64 colours, art-pass "Master palette") and nearest filtering.
- `test_the_tracked_overlays_hold_only_hand_pixels` holds for every overlay that is touched.
- Every rebuild stays reproducible byte for byte (K35).

## Goals / Non-Goals

**Goals:**
- Fix TR7 and TR9 to TR15 at their root: in the recipe, the overlays, the art data and the drawing scripts.
- Round the dune's own inland corners, the part of C3 that wave 1 left out (D9).
- Pin each fix with a test that fails on the sheets as wave 1 leaves them.
- Keep every peer's drawing identical, with no new random number generator.
- Keep every test that names a coast cay cell valid through coast-cay-reshape (C6). Expectations for the cay are derived from its layout at test time, and only sandbar tests pin exact cells.

**Non-Goals:**
- The bush drawn over a crouched body (C8, PR1). That is wave 3, art-sprite-polish, and it lands after C10, because its `BushFront` copies the Brush layer's tile, variants included.
- The garita and signs, the secret cay's decor, the lean-to and the small props (C15 to C18). The 2026-11-15 queue left them out.
- Slope tiles (C5), the coast cay reshape and the sandbar's notches (C6), and the forest rows (TR16).
- A drop-off ramp row for the deep edge. K39 left it for later, and it is not needed for value contrast.
- A new terrain kind, a layout edit or a tile set with physics.

## Decisions

### D1. A palm counts for the dune by its neighbours (C9, TR11)
- **The rule.** For the dune layer only, a palm cell counts as a member when at least 3 of its 4 orthogonal neighbours count for the dune by the raw rule (dune or scrub). It is never a brush member. It counts for its own tile and for its neighbours' corner masks.
- **Plumbing.** The rule needs the layout's palm cells, which `GridTerrain` does not hold. An optional trailing `palms: Array[Vector2i] = []` parameter is added to `TerrainArt.is_member`, `layer_cells`, `corner_mask` and `tile`. `TerrainView` passes `built.palms`. Callers that pass nothing keep today's result, so the fixture tests and `ShoreRule` are untouched.
- **Measured** with the review's rule on today's layouts:
  - sandbar: 3 palms join, (23, 31), (23, 36) and (24, 42), so the Dune count goes 422 → 425;
  - coast cay: 4 palms join, (28, 19), (51, 21), (38, 24) and (11, 35), so 393 → 397.
- **The sandbar's palm (23, 31) takes Dune mask 7, not 15.** Its south-east diagonal (24, 32) is beach. The review's 1-player test said 15. Only the cay's enclosed palms (28, 19) and (51, 21) take mask 15 today. The cay test derives "every palm whose eight neighbours count takes mask 15" from the layout instead of naming cells.
- **The shade decal.** It still marks every palm base. A palm on the dune keeps its own sprite and shadow.
- **Rejected:**
  - Mapping "P" to dune in the layout. It is content, it changes `test_layer_cell_counts_of_the_two_islands` and the sandbar's approved terrain counts, and some palms stand on the open beach.
  - Counting a palm with fewer than 3 dune neighbours. It turns a beach palm into a lone dune blob, which is today's defect in reverse.

### D2. Still water gets a still piece (C13, TR13)
- **Which water is still.** `ShoreRule.still_water(terrain)` flood-fills the 4-connected water bodies once per build. A body with no DEEP cell is still. Tide pools are land for the sand layer (K39), so they are never bodies.
- **Which shore is still.** A shore cell takes the still piece when every water cell among its 8 neighbours lies in a still body. A cell that touches open water anywhere keeps the surf.
- **The still piece.**
  - A new sheet, `sea/foam_still.png`: one 16-mask column built by `terrain.py` from the same sand shape. It holds only a 1 px wet line on the first water step, in a shallows-ramp colour, with no white.
  - It is the second source of `sea/shore_tiles.tres`, at atlas (0, mask). Every frame of it is identical, so the shore shader's phase changes nothing.
  - `foam.png` keeps its size and its bytes.
- **What stays.**
  - The shore cell counts of `test_the_shore_cell_counts_of_the_two_islands`, because a still cell is still a shore cell.
  - The cay's inner bay keeps its surf, because it reaches deep water.
  - The phase mask is unchanged.
- **The cay test** finds the lagoon from the layout: the brackish body with no deep cell. It asserts that its rim takes source 1 and that every shore cell on open water takes source 0.
- **Rejected:**
  - No foam at all on a still rim. The brackish edge would then read by hue only, which is TR7's problem.
  - Slower surf on the lagoon. It still pulses, and one shader clock serves both.

### D3. The raft rests on the sand, with its shadow by stage (C14, TR15)
- **The offset.**
  - `StructureArtData` gains `look_offsets: Dictionary[StringName, Vector2]`. The `raft` and `raft_site` kinds take about 16 to 24 px. The builder measures the value so that the hull's opaque bottom rows lie over land cells on both islands.
  - `StructureLook` adds it to its sprite and shadow offsets for those kinds only.
  - The direction points toward land. It is picked once from the terrain beside the origin: west if the west neighbour is land, else east, else no offset. Both shipped sites have land to the west.
- **The crossing deck stays.** `CrossingDeck` reads `data.raft` itself and never `look_offsets`, so the deck, `deck_rect` and every crossing test stay where they are.
- **The shadow.**
  - `DropShadow.Size` gains `WIDE`: a 30×11 soft ellipse in the palette's darkest colour at partial alpha. It is a hand file drawn after MetroCity's ellipse, in its alpha, copied by the tools under `shadows/`, with an own-work block in `shadows/License.txt`.
  - `structure_art.tres` maps `raft` to `WIDE`. The site's shadow is picked by its stage: none while marked or holding materials, `WIDE` from the half-built frame on. The look reads the stage it already draws.
- **The decal goes.** `TerrainView` drops `WIDE_WEST`, `WIDE_EAST` and their offsets, and the raft-site branch of `_build_decals`. The workbench and shaded-cell decals stay.
- **What stays the same.** The interact prompt and the site's interactable stay on the structure's origin, because the offset is look-only. Archived K46 and K81 ("the raft stands bottom-centre on its cell") are amended for the beach only. K86 (no shadow on the raft and the site) is superseded.
- **Rejected:**
  - Moving the site in the layout. It is content, and the walk bands and the landing tests pin it.
  - Keeping the decal and adding the shadow. It shows a shade under an empty marked site, which is the defect.

### D4. A beach with no grid (C11, TR12)
- **Stripes.** In the sand set's `map`, the pack's two wave colours #e0f878 and #a0f868 go to one tone (#e4b488, the fill, unless the after-capture asks for #eec39a). The lip, the corner shapes and the alpha do not change, so no derived sheet moves its edges.
- **Picks.**
  - The four row-4 sand picks are redrawn in the `sand.png` overlay as four distinct tiles that are not mirrors of each other: one clean, three with sparse shells, specks or a footprint. Each keeps mask 15's edges, which `test_the_variants_on_row_4_have_their_masks_corners_and_differ` checks.
  - The specks are placed off the old 3-spot lattice.
- **Weights.**
  - `TerrainArtData` gains `variant_weights: Dictionary[StringName, PackedInt32Array]`.
  - `_variant` picks by a cumulative weight on `cell_hash >> 1`. For sand the clean pick has about 70% of the weight and the other three share the rest.
  - A layer with no weights keeps the uniform pick.
  - Bit 0 still drives the foam phase (K41).
- **The dune lip.** It is retoned one step toward the dune fill and stays 1 px.
- **The art tuning means are recomputed (K47).** The sand mean changes, which C7's contrast test reads, so C11 lands before C7.
- **Rejected:** a per-cell random rotation or mirror. It flips the upper-left light (K36).

### D5. Scrub with variety (C10, TR10, TR14, Q2 (a))
- **Inland picks.**
  - The brush sheet gains a second pick row. Three whole-cell (mask 15) picks keep the four corner quarters byte-identical to today's mask 15, so neighbours join. Each varies the centre lobe and fills between the lobes with a dark under-canopy tone (#4b692f, outlined #323c39) instead of the sand showing through.
  - `TerrainArtData` gains `variant_masks: Dictionary[StringName, PackedInt32Array]` and a pick row per mask. The brush picks both mask 0 (its islet, as today) and mask 15.
  - `tile()` takes the variant whenever the cell's own mask is listed.
- **Shore variants.**
  - Wave 1's fit step places one pick, or the tuft, per sand mask.
  - C10 adds a `"variants"` list to the `"fit"` key: 2 or 3 pieces, the existing pick and 1 or 2 new hand-drawn small bushes of at most 11×10. Each piece is placed by the same search, and a piece that fits nowhere on a mask falls back to the next.
  - `brush_shore.png` gains rows: stride × piece. `tile()` picks the piece by hash on shore cells.
  - This amends K39 and K40's "variants only when the sand mask is 15".
- **The hole (TR14).** The 6 px gap at (55–57, 68–70) of `fixes/terrain/brush.png`, erased on purpose by K39 (g), is painted #37946e with a #4b692f and #323c39 inner edge. It ships first, as its own group, apart from the rest of C10. Wave 1's C2 re-rolled the picks, and the hole now shows on a bush beside the owner's spot on the west shore (the middle-right bush in wave 1's after capture, `docs/art-pass/review-2026-11-14/west_shore_bushes_x6_before_after.png`).
- **No ±2 px islet shifts.** They clip the islet against the tile edge.
- **Tests that change:**
  - `test_terrain_tile_sets.gd`'s brush shore tile count;
  - `test_no_shore_tile_of_an_upper_layer_leaves_the_sand_under_it`, which walks the new rows;
  - `test_dune_and_scrub_shore_cells_on_the_sandbar_take_their_shore_sheets`;
  - wave 1's 1-player test that shore scrub cell (20, 35) takes atlas (10, 0). It now takes (10, stride × piece), and the tile holds the whole piece.

### D6. A rocky point with an edge (C12, TR9)
- **Rim.**
  - The plain rock row's rim goes from #696a6a, which is also an interior crack colour, to #323c39. That is done only together with the seam softening below; alone, it would draw a dark ruler line.
  - The rim stays 4-adjacent (wave 1 D4).
- **Seam.**
  - The rock tiles' sand-facing edges get a ragged 1–2 px edge in the `plain.png` overlay.
  - `TerrainView` lays pebble decals of at most 8×6 on sand cells beside rock, chosen by `cell_hash`, with no collision.
  - The decals are a new `decals/` hand file, at most 3 variants.
- **Lip and face.**
  - A `terrain.py` step gives the rock a 1 px lit lip on its north edge.
  - Only on water edges, it adds a low 2–3 px face in `plain_shore.png`, where those cells draw.
  - The face stays lower and lighter than the cliff's, so the rock never reads as a fall (`test_the_cliff_has_a_lit_lip_and_a_dark_foot_and_the_wreck_has_long_boards`).
- **Picks.** Three of the four picks share one crack skeleton today. Each pick interior is redrawn in the overlay, keeping where cracks cross the cell edges (`test_each_plain_full_tile_is_seamless`, `test_the_tracked_rock_has_the_pack_variant_and_two_hand_ones_that_keep_its_border`).
- **Reshaping the point is content** (C6).
- **The 1-player test** finds a rock shore cell from the cay's layout at test time and checks that it draws a `plain_shore.png` tile with the face rows.

### D7. Land and water apart by value (C7, TR7, Q3 (a))
- **The shallows ramp.**
  - `terrain_tiles.json` water ramp row 1 drops to a base near #3f9fc0, chosen darkest-first in the range #3f9fc0 to #49a8c8 until the contrast test passes.
  - Measured against the sand fill #e4b488: #3f9fc0 gives 1.61:1 and #49a8c8 only 1.45:1, so the base sits at the dark end.
  - The ramp keeps four steps and its lighter-than-deep order (art-pass "Scrolling sea"): #306082 against #3f9fc0 is 2.22:1.
- **The brackish ramp moves too.** Today's #3d8f77 against a #3f9fc0 base is only 1.29:1. Brackish moves darker and greener, so that shallows against brackish is at least 1.4:1 and brackish stays lighter than deep.
- **The palette budget.**
  - The review allowed 4 new colours (53 → 57) for the shallows. Moving brackish may need up to 4 more, so the palette takes at most 61 colours, within the 64 cap.
  - Colours are written to `master_palette.png` and `.gpl`, and `test_art_palette` follows.
  - An old ramp colour that is still used (the foam fade #8fe0f0) stays.
- **The wet edge.**
  - Wave 1 removed the pack's #c08a5a band (TR6), so the "existing wet band" the review uncovered is now wave 1's 1 px #d9a066 lip.
  - C7 makes that lip visible below the foam. The foam's `land_rows` climb is lowered until, on the straight masks, the lip row is uncovered in at least 4 of 8 frames. The wash still climbs in the others, and the foam touches the lip or the water pixel beyond it in every frame, as `test_in_every_frame_the_foam_is_one_band_on_the_sands_edge` already allows (it counts `sand_end` or `sand_end + 1`).
  - The dune and brush shore insets are raised from 1 to 2 so that the sand's lip shows under dune coasts.
  - Wave 1's "Foam meets the sand" scenario still holds: the foam starts where the sand ends, and it no longer climbs over the last row.
  - A second wet row is new owner question QT1.
- **Tide pool.** `fixes/terrain/tide_pool.png`'s water is repainted in the new ramp.
- **Means.** The `art_tuning.tres` `land_grounds` and `water_grounds` means are recomputed from the rebuilt sheets (K47).
- **The tests:**
  - new: sand and dune means against the shallows mean at 1.6:1 or more (brush excluded: its green is apart by hue and value already);
  - unchanged: the swimmer and fin contrast tests (art-pass "Actors stand out from the ground"; the review verified both bases).
- **Rejected:** a lighter beach. It loses the bright tropical sand of art direction C and lowers the outline contrast of every actor on land.

### D9. The dune's inland corners are rounded (C3's dune part)
- **Why here.** Wave 1 rounded the sand's corners but left the dune's own corner set square. Its design listed this as a non-goal ("its pack corners are already ragged"). The re-shot `docs/art-pass/sandbar_day.png` still shows stair steps where the light dune meets the darker inner beach: the same "too square" look, inland. On 2026-11-15 the owner chose "Next PR" for it, so it belongs to this change.
- **Method: wave 1's D3, on `fixes/terrain/dune.png`.** The overlay is regenerated as a diff against the pre-overlay dune set:
  - an opaque pixel where the target differs;
  - `#ff00ff` where the target is clear and the built pixel is not.
  - The overlay's existing hand pixels are kept: the four straight masks' tuft removals, the row-4 picks and the hand islet.
- **Where the borders are.** The dune's straight edge tiles cross the cell borders at their own points, which differ from the sand's. They are measured from the built straight tiles at the start of the task, not assumed.
- **Shapes.**
  - Outer masks 1, 2, 4 and 8: an ellipse quarter round the dune corner's outer point. Its semi-axes reach the far edges' border points.
  - Inner masks 7, 11, 13 and 14: a quarter-ellipse bite that reaches the near edges' border points. The dune's straight edges cross the border 3 px from the corner (the sand's cross at 4), so the bite is 2 px deep along the diagonal; the pack's mask 7 had 1.
  - Saddles 6 and 9: two bites each. They are assembled from quadrants before the overlay, so they need their own overlay pixels.
  - Every shape passes through the straight edges' border points, so every pair of masks that can sit side by side meets without a jog.
- **The edge stays ragged.** Along each new curve, the lip copies the straight dune edge's pattern: a broken #d9a066 outline with gaps and 1–2 px spikes. A smooth ruled arc would read as a different material from the straight edges. The tests allow 2 px from the ideal arc for that.
- **What must not change.** These are the overlay tests that pin the tufts and the islet:
  - the hand cell is still only the islet (0, 0), with all 256 pixels (`test_the_tracked_overlays_hold_only_hand_pixels`);
  - each row-4 pick keeps under 40 overlay pixels;
  - the straight edges carry no tuft, and the islet stays ragged with one small tuft (`test_the_dune_edges_carry_no_tuft_and_the_islet_is_ragged`);
  - the four corner pixels of each mask (`test_each_corner_set_holds_mask_m_at_its_place`);
  - no corner gets a tuft, because tufts come only from the full-tile picks and the islet (K39).
- **What follows.** `dune_shore.png` is built from the dune tiles cut to the sand, so dune corners on the coast round too. Nothing else is built from the dune.
- **With C9.** Counting palms as dune removes most pits and notches, so fewer corner tiles show. The corners that remain are the dune's real outline, and those are the ones rounded here.
- **Rejected:**
  - marking the dune's corner masks "hand", which breaks the overlay test;
  - a smooth arc with a rim, which reads unlike the pack's ragged straight edges;
  - the 47-tile blob, for the reason wave 1 gave: it cannot draw slopes.

### D8. Order and seams
1. TR14 (the hole), the smallest fix.
2. C9; then the dune's corners (D9), which read the dune cells C9 adds; then C13 and C14. They need only wave 1 merged.
3. C11 (after wave 1's C2, and after D9, because both edit the `dune.png` overlay: D9 the corner shapes, C11 the lip's tone).
4. C10 (after C1 and C2).
5. C12 (after C2 and C3).
6. C7 (after C3, and after C11, whose sand mean it reads).

Seams with other changes:
- **Wave 3 (art-sprite-polish), C8** copies the Brush tile at a body's cell, so it lands after C10.
- **coast-cay-reshape (C6)** re-authors the cay. Every cay expectation here is derived from the layout at test time, and only the pinned layer counts in `test_layer_cell_counts_of_the_two_islands` name the cay. C6 owns those numbers, so whichever of C9 and C6 lands second updates them.
- **art-mood-pass** may speed up the foam in a squall. The still piece has identical frames, so it stays still at any speed.
- **The test-folders session** may move test files. Follow its layout.

## Reference games

Ideas and structure only, never code, data or text.

**Shattered Pixel Dungeon**
- *Borrowed for C11:* `DungeonTileSheet.getVisualWithAlts` with its `tileAlt` chances (DungeonTileSheet.java). Each cell's alternate visual is picked by its fixed `tileVariance` value against cumulative chances, so most cells stay plain and a few carry a detail. C11's weighted picks follow that shape on our `cell_hash`.
- *Borrowed for C12:* `DungeonTileSheet.getRaisedWallTile`, used by `DungeonTerrainTilemap.getTileVisual`. A raised wall draws a lit top and a face only on the side the viewer sees. Our rock gets a lip on the north and a face only toward the water.
- *Borrowed for C14:* `ItemSprite`'s `shadowWidth`, `shadowHeight` and `shadowOffset` (ItemSprite.java) size a shadow from the sprite it belongs to. Our wide shadow belongs to the raft's stage, not to the ground under the site.

**DCSS**
- *Borrowed for C13:* `pack_cell_overlays` (tilecell.cc). It packs `_pack_shoal_waves`, moving surf, only in the Shoals branch. Elsewhere `_pack_default_waves` adds a static shoreline overlay to water beside land. Rough and still water get different edges. (The review said "waves only in the Shoals". The default branch still draws a quiet shore line, which is our still piece.)
- *Noted for C10:* `tile_init_flavour` (tileview.cc), per-cell flavour, as in wave 1.

**Brogue CE**
- *Borrowed for C13:* `lakeFloodFill` (Architect.c), which marks a lake by flood fill once. We label each water body once per build and ask whether it holds a deep cell.

**ALttP and Pokémon** (general knowledge of how they look; nothing copied)
- *Borrowed for C7:* land and water are told apart by value first; greyscale still shows the coast.
- *Borrowed for C10:* bush fields vary their middles and keep their edges.

**Don't Starve Together** (`docs/REFERENCE_DST.md`)
- *Borrowed for C7:* "The sea graded by distance from land" ([Ocean/DST](https://dontstarve.wiki.gg/wiki/Ocean/DST)) uses "darker means deeper" as a pure readability cue. Our shallows step down in value from the beach, and the deep steps down again.
- No REFERENCE_DST section covers palms on dunes, scrub variety, beach texture, rock edges, lagoon foam or a raft's shadow (C9 to C14), so nothing is borrowed from DST for them.

## Owner decisions

**Accepted on 2026-11-14 (the review's section 6):**
- **Q2 (a):** one fitted shore bush in wave 1, with shore variants in their own change. C10 is that change.
- **Q3 (a):** darker shallows plus a visible wet-sand edge (C7).
- **Q4 (a):** the deep edge is art only. Nothing here changes the shallows ring in the maps.

**Added on 2026-11-15 by the coordinating session:**
- **The dune's inland corners (D9).** When wave 1 merged, the owner chose "Next PR" for them, so they are in this change.
- **TR14 first.** The bush hole shows in wave 1's after capture, so it ships as the first group.

**Answered on 2026-11-15** (the owner, "Accept all recommended", relayed by the coordinating session):
- **QT1 (a):** uncover wave 1's 1 px lip below the foam; no second wet row.
- **QD1 (a), "Ship, look again later":** the dune's rounded corners ship as they are (D9). The staircase the layout's one-cell steps make stays for now; slope tiles (C5) and reshaping the sandbar's dune runs are logged as follow-ups in `TASKS.md`.

**Asked:**
- **QT1. The wet-sand edge.** Wave 1 already replaced the review's two-row band (#d9a066 over #c08a5a) with one 1 px lip on every side.
  - (a) *Recommended:* uncover that 1 px lip below the foam. It keeps wave 1's "same lip on every side" rule.
  - (b) Add a second, darker wet row on all four sides (a 2 px wet edge). It amends wave 1's lip scenario, and the south side again ends in a two-row band.

## Risks / Trade-offs

- **[C7's new colours shift every water frame]** The swimmer and fin contrast tests guard actors, and the review measured both bases passing. The deep ramp is untouched, so the crossing sea does not change.
- **[C14's offset leaves the raft off its interactable]** The prompt still anchors at the origin, 16–24 px east of the hull's centre. That is within the 16 px reach plus slack the prompt already allows, and the after-capture checks it. If it reads wrong, the prompt's anchor moves with the look offset (a drawing value) in the same PR.
- **[C10 adds tiles]** The brush shore sheet grows by its variant rows. The 1500 ms island build bound (`test_the_layer_build_of_both_islands_is_timed_and_bounded`) is re-run.
- **[C9 changes the cay's pinned counts]** C6 re-authors the cay and owns its numbers. The sandbar's 425 is the pinned value here.
- **[C13 on a generated island]** A generated island with an enclosed shallow pond gets still edges, which is intended.

## Migration Plan

Art only:
1. Rebuild with `python -I tools/art/terrain.py --packs C:/Users/liann/src/90miles/game/assets`, plus the structure and shadow steps C14 needs.
2. Run `python -I tools/art/check.py game/assets/art`.
3. Import twice.

To roll back, revert the commit. No save, network message or layout depends on these pixels or data fields.

This change archives after art-coast-pass. Before archiving, the MODIFIED "Shoreline overlay" block is re-synced with the archived art-pass text.

## Build notes

Measured values and departures are recorded here as the tasks ship.

**Gate (0.1, 0.2), 2026-11-15.** art-coast-pass merged at c0a1915 and this queue at 10b2723; the coordinating session said go. Its "Shoreline overlay" delta on main is byte-identical to the copy this change's MODIFIED block was made from, so the block needs no re-sync until art-coast-pass is archived.

**TR14 (group 1).**
- The hole was 6 clear pixels inside pick 3, at (56, 68), (57, 68), (55, 69), (56, 69), (57, 69) and (56, 70), where the overlay held #ff00ff erase marks. On the solo sandbar, 4 lone bushes take pick 3 after wave 1's re-rolled hash: (21, 36) beside the owner's spot, (27, 51), (33, 56) and (41, 59).
- Painted as a shaded crease between the two lobes: #4b692f at (56, 68) and (55, 69) beside the left lobe's #323c39 outline, and #37946e on the other four. The hole test counts clear pixels that no 4-connected clear run joins to the tile's border.
- Rebuilt: only `game/assets/art/terrain/brush.png` changed; `check.py` reports 0 problems.
- Checks: `tools/art` unit tests OK; import twice clean; smoke 0 problems; GUT 256 scripts, 2343 of 2343 passing.
- Windowed capture (`capture_terrain.tscn`, cells (17..24, 30..40) at x6): `docs/art-pass/terrain-polish/tr14_west_shore_x6_after.png`. The bush at (21, 36), the middle-right one in wave 1's after capture, is solid.

**C9 (group 2).**
- `TerrainArt.is_member`, `layer_cells`, `corner_mask`, `tile` and `_counts` take an optional trailing `palms`. On the dune layer a palm cell counts when `PALM_DUNE_SIDES` (3) of its four orthogonal neighbours count by their terrain alone (`_dune_sides`). `TerrainView` passes `built.palms`; `ShoreRule` and every caller that passes nothing keep the terrain-only rule.
- Measured: sandbar Dune 422 → 425 ((23, 31), (23, 36), (24, 42)); (23, 31) takes mask 7. The coast cay's count is derived in the test as the terrain-only count plus the palms that join, so coast-cay-reshape can move it. The Brush counts are unchanged with the palms.
- `test_terrain_view.gd` `test_every_land_cell_has_a_sand_tile_and_every_layer_its_rule` passes the palms, so the drawn layers still equal `TerrainArt`'s tiles.
- Windowed captures at x3, before (left) and after (right): `docs/art-pass/terrain-polish/c9_sandbar_palms_before_after_x3.png` and `c9_cay_north_before_after_x3.png`. The beach pits and notches round the palm bases are gone; a palm cell on a whole dune can now show one of the dune's tuft picks.

**The dune's inland corners (group 3, D9).**
- Measured first on the dune as wave 1 left it: no jog on any of the 128 neighbour pairs; outer corners 1, 2, 4 and 8 lay 21, 19, 24 and 38 px off the quarter ellipse their border reach allows; the inner bites were 1–2 px along the diagonal (mask 7 and saddle 6's south-east bite 1). The dune's straight edges cross the border 3 px from a corner (the sand's at 4), so 2 px is the deepest bite they allow.
- Regenerated `fixes/terrain/dune.png` with a one-off helper, kept as `art-waves-2-5/dune_corners.py` in the coordinating session's notes folder: each outer tile inside the quarter ellipse whose semi-axes are its reach along its two border strips, both strips byte-identical; a quarter-ellipse bite at each water corner of 7, 11, 13, 14, 6 and 9; colours kept where the tile was drawn, the fill where the shape grows, and the lip within 3 px of a changed edge redrawn from the facing straight mask's own lip by depth (south from 3, east from 5, west from 10, north from 12), never mirrored.
- After: every outer corner 0 px off its arc, every inner bite 2 px, still no jog. Outer corners hold 112–123 dune pixels, not 132–147. Only `dune.png` and `dune_shore.png` changed; `check.py` reports 0 problems; the hand islet, the row-4 picks, the straight edges and every corner pixel are unchanged (the overlay and tuft tests pass).
- The new GUT tests (`test_the_dune_corners_are_rounded`, `test_neighbouring_dune_tiles_meet_without_a_jog`, the solo sandbar test) failed on the old sheet (21–38 px off, a 1 px bite, and the sandbar's corner cells at (41, 14), (38, 15), (53, 15) and others) and pass on the new one.
- Checks: `tools/art` unit tests OK, import twice clean, smoke 0 problems, GUT 256 scripts, 2350 of 2350.
- Capture: `docs/art-pass/terrain-polish/dune_corners_north_before_after_x3.png` (the sandbar's north dunes, before above, after below). The step corners now read as curves. The staircase itself remains, because it is the layout's one-cell steps; tiles can only round each step, and true diagonals are C5's slope tiles.

**C13, still water (group 4, D2).**
- `ShoreRule.still_water(terrain, pools)` flood-fills 4-connected water (tide pools are land) and keeps the bodies with no deep cell that stay inside the grid. `foam_tile` takes an optional `still` and picks `STILL_SOURCE` (1) when the cell has water among its 8 neighbours and all of it is still; `TerrainView` computes the bodies once per build. With nothing passed, every caller keeps today's surf.
- On the coast cay the still body is the lagoon: its brackish water and the shallows ring round it, closed in by beach. The rim's shore cells take the still piece; every shore cell with open water beside it keeps the surf, and the 265 shore cells are unchanged. The sandbar has no still water.
- `terrain.py` builds `sea/foam_still.png` from the foam recipe's new `"still": {"colour": "#8fe0f0"}`: a 1 px line on the first water pixel round each sand shape, the same in all 8 frames, 128×256 like `foam.png`, so the shore shader's frame steps change nothing. `foam.png` is byte-identical. It is source 1 of `sea/shore_tiles.tres` (no texture padding), with an own-work block in `sea/License.txt`.
- The line is #8fe0f0, the shallows ramp's lightest step: on the lagoon's shallows ring it reads as a calm wet edge, not surf.
- Capture: `docs/art-pass/terrain-polish/c13_lagoon_before_after_x3.png` (before left, after right).

**C11, a beach with no grid (group 6, D4).**
- The sand `map` sends both pack stripe tones to the fill #e4b488 (#e0f878 went to #eec39a, the majority of today's pixels). Every derived sheet reads only the sand's alpha, so only `sand.png` changed.
- The sand overlay was rewritten by a one-off helper (`art-waves-2-5/c11_art.py` in the coordinating session's notes folder): wave 1's literal #eec39a stripe pixels in the corner tiles became #e4b488 and, now equal to the built pixel, left the overlay; row 4 was cleared and redrawn as one clean pick (the whole tile) and three marked ones, lit from the upper left, no position shared: a scallop shell and a pebble (9 px), scattered grit (5 px), a dry weed strand and a speck (6 px).
- `TerrainArtData.variant_weights` (`&"Sand": [70, 10, 10, 10]`); `_variant` takes the pick by a cumulative weight on `cell_hash >> 1`. A layer with no weights picks evenly, so the dune and the brush are unchanged. The solo sandbar's whole sand cells now take the clean pick in the 60–80% band; today's share was 25%.
- The sand ground mean in `art_tuning.tres` is the picks' mean weighted the same way: (0.893, 0.705, 0.533), from (0.920, 0.746, 0.581). The outline-contrast checks still pass.
- **Departure: the dune lip is not retoned.** Against the one-tone beach, the 1 px #d9a066 lip reads as a soft outline, not the heavy band it was over the stripes (`docs/art-pass/terrain-polish/c11_beach_dune_before_after_x2.png`, before above, after below). Retoning it to #eec39a, one step toward the dune fill, would blur the dune's outline. It stays 1 px, as the spec asks.
- Tests: `SandTextureTests` (one tone, distinct picks that are not mirrors, no shared mark position; it failed on today's lattice), the weighted share on a 32×32 block and on the solo sandbar (failed at 25%).

**C10a, inland scrub (group 7, first PR, D5).**
- **The canopy.** Measured first: the brush's only ground inside a thicket is at the four edge midpoints, (7, 0) (8, 0) (8, 1), (7, 15) (8, 15), (0, 7) (0, 8) (0, 9) and (15, 7) (15, 8), wherever both corners of that edge are scrub, and it joins across the border into a 2–3 px tan gap between the lobes. A recipe key, not hand pixels: the stamp set's `"canopy": "#4b692f"` fills the clear pixels within 3 px of an edge's middle when both its corners are land (`terrain.CANOPY_GAPS`), in every mask, so both sides of every edge match. `fit_tile` fills the same pixels on a fitted shore tile where they are on the sand, so a shore bush meets its inland neighbour exactly; `brush_shore.png` changes only there.
- **Whole-cell picks.** `"full_variants": ["15", "15", "15", "15"]` puts a row 5 on the brush sheet (64×96; the overlay grows with it). Pick 0 is the full tile; picks 1–3 redraw only the centre lobe (rows and columns 3–12), so every corner quarter is byte-identical and neighbours join: a sunnier lobe with one broad highlight, sea-grape berries (#76428a, #45283c) under the lobe, and a two-leaf top with a short crease. The helper is `art-waves-2-5/c10a_art.py` in the coordinating session's notes folder.
- `TerrainArtData.variant_masks` (`&"Brush": [0, 15]`): mask 0 picks on row 4 as before, mask 15 on row 5. `TerrainArt._pick_row` reads it, and a layer with no entry keeps `variant_mask`. `terrain_tiles.tres` gains the brush's four row-5 tiles (24).
- Tests: `CanopyTests` (the fill, an edge with one land corner unchanged, the 96-high sheet, the fitted shore tile matching its inland tile, the tracked brush: no ground in a whole cell, pick 0 the full tile, picks distinct and not mirrors, changes only in the centre, no hole; it failed on today's brush first), the per-mask pick rule on a fixture, the corner quarters of every full pick, and the 1-player test that the solo secret cay's (`cayo_sin_norte`) whole scrub cells use more than one pick.
- Capture: `docs/art-pass/terrain-polish/c10a_secret_cay_scrub_after_x3.png` (the secret cay's scrub block; before: `docs/art-pass/review-2026-11-14/before/secret_cay_decor.png`). No tan shows between the lobes, and the berries and lobes break the repeat. The coloured squares are the decor placeholders of C16 (art-prop-polish).

**C10b, shore bushes (group 7, second PR, D5; Q2 (a)'s "2–3 shore variants later").**
- Two hand pieces in `tools/art/fixes/terrain/`, drawn by `art-waves-2-5/shore_bushes.py` (notes folder) in the brush greens with a #323c39 outline, lit from the upper left: `shore_bush_a.png`, a squat two-lobed shrub (11×7), and `shore_bush_b.png`, a small round sea grape with a berry cluster (9×9).
- The fit's new `"variants"` list gives `brush_shore.png` one block of 16 rows per piece (256×768): block 0 the pick, blocks 1 and 2 the two bushes. Each piece is placed on every sand mask 1–14 by wave 1's search, falling back to the tuft where it fits nowhere (the four convex tips). Sand mask 0 keeps the cut in every block. The fixes are counted as read, and each is refused unless it is a drawn 16×16 tile.
- `TerrainArtData.shore_variants` (`&"Brush": 3`); `TerrainArt.shore_row(layer, cell, layout_id)` picks the block by `cell_hash >> 1`, and `tile()` uses it on a shore cell (sand mask 1–14). `terrain_tiles.tres`'s brush shore source has 195 tiles.
- Tests: the fixture (a variant's block placed by the same search; variants are read hand tiles, and an unread one is refused), the tracked sheet (three blocks, each bush at most 11×10 in the brush colours, each tile a whole moved piece or the tuft; it failed before the recipe key), wave 1's (20, 35) test now checks the whole piece of the cell's block, `test_dune_and_scrub_shore_cells_on_the_sandbar_take_their_shore_sheets` reads the block, and the 1-player test that the solo sandbar's shore scrub uses more than one block.
- Capture: `docs/art-pass/terrain-polish/c10b_west_shore_before_after_x3.png` (the west shore round the owner's spot; before left, after right).

**C12, the rocky point (group 8, D6).**
- **Rim, lip, face.** The rock row's rim goes from #696a6a (also a crack colour, so invisible) to #323c39. New plain-row keys, read by `terrain.py`: `"lip": "#9badb7"` lights the row under every north-facing rim (`lipped`), in `plain.png` and `plain_shore.png`; `"face": ["#696a6a", "#595652"]` draws a low 2-row face over every south-facing rim whose pixel below is water (`faced`), so only in `plain_shore.png` and never on a land seam. The cliff keeps its own deeper drop; the rock's face is two rows of mid greys, shorter and lighter than the cliff's dark foot.
- **Pebbles.** `tools/art/fixes/terrain/pebbles.png`, copied to `decals/pebbles.png` and source 2 of `decal_tiles.tres`: four tiles, two or three small stones in #9badb7, #847e87 and #595652 lit from the upper left, each at most 8×6 and kept inside the sand strip a straight rock seam leaves (west for own mask 10, east 5, north 12, south 3). `TerrainView` lays one on a rock cell whose sand is whole and whose own plain mask is one straight edge, about one cell in two by `TerrainView.has_pebbles` (`cell_hash >> 3`). They are decals: no collision, and every peer draws the same.
- **Departure: no ragged alpha edge.** `test_each_plain_tile_has_the_outline_of_the_sand_tile_of_its_column` pins every plain tile's outline to the sand tile's, so the rock's seam cannot be roughened in its alpha; the pebbles at its foot break the line instead. **Departure: the picks are not redrawn.** The four rock picks already differ inside; what they share is the border crack crossings, which must stay for seamless joins, and wave 1's mixed hash (C2) removed the diagonal stripe that made the lattice show. **Placement:** the pebbles sit on the rock cell's own sand strip rather than on the sand cell beside it, so they hug the rock's foot.
- Tests: `RockEdgeTests` (the lip only under a north-facing rim; the face only above a south-facing rim over water, two rows; the tracked rock's #323c39 rim, lit lip and face; the pebble tiles inside their strips and at most 8×6; all failed first), `test_pebbles_lie_only_at_the_foot_of_straight_inland_rock_seams` (only straight inland seams, the side facing the beach, by the hash, not every cell), the 1-player test that the solo coast cay's rock over the sea to its south draws the face, and the decal tile set's 4 pebble tiles.
- Captures: `docs/art-pass/terrain-polish/c12_rock_seam_and_face_before_after_x4.png` (the seam and the south water edge, before left, after right) and `c12_rock_seam_pebbles_after_x4.png` (the west seam with its pebbles and the lit north lip). The point's shape is content (C6).
