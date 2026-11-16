# Design

## Context

See proposal.md for why. The review that found these problems, with root causes, measurements and mockups, is copied to `docs/art-pass/review-2026-11-14/DESIGN_PASS.md` (section 2.1, findings TR1 to TR8; section 3, changes C1 to C4).

How the terrain art is made today (archived art-pass K35 to K47):
- `tools/art/terrain.py` builds every terrain sheet from the recipe `terrain_tiles.json`, three read-only packs, and the hand overlays in `tools/art/fixes/terrain/`. Run again on the same packs, it gives the tracked PNGs byte for byte.
- The sand corner set (`sand.png`, after its overlay) is the shape behind everything else: the plain tiles, the three shore sheets, the foam and the shade are all built from its alpha.
- At run time, `TerrainArt.tile` picks atlas tiles by corner masks. Variants come from `cell_hash`. `TerrainView` fills the layers and sets up the sea shader through the static `setup_sea`, which the crossing's sea also calls.

Constraints:
- Art never changes the simulation. The tile sets have no physics, navigation or occlusion layer, so a reshaped tile cannot move a walkable cell.
- Keep the 1 px outlines, the 53-colour master palette and nearest filtering.
- `test_the_tracked_overlays_hold_only_hand_pixels` requires that the sand overlay has no pixel in the islet cell (mask 0). Only the dune's islet is a "hand" cell.

## Goals / Non-Goals

**Goals:**
- Fix the owner's two complaints at their root, in the recipe and the overlays, so that every derived sheet follows the change.
- Pin each fix with a test that fails on today's sheets.
- Keep every peer's drawing identical.

**Non-Goals:**
- Slope tiles for true 45° stairs (C5).
- Reshaping the coast cay (C6).
- Darker shallows (C7).
- Shore bush variants (Q2 (a): later).
- Brush variety inland (C10).
- Rounding the dune's own inland corners. Its pack corners are already ragged; this is revisited only if the after-capture shows square dune tips.
- Recolouring the sand islet (mask 0). The overlay test above forbids hand pixels there, and no shipped layout's beach depends on it. TR6 is applied to every other mask that has a south ledge.

## Decisions

### D1. Fit, don't cut: a placement search in the recipe (C1, TR1)
- **The key.** The brush's shore entry gains `"fit": {"pick": 1, "fallback_inset": 0, "tuft": "shore_tuft.png"}`.
- **The search.** For every sand mask s from 1 to 14, the builder looks for a shift (dx, dy) in [-8, 8]² that keeps every pixel of the pick (column 1 of the brush's pick row, the small 11×10 bush) inside the tile, on the sand, and at least `inset` steps in by `shore_field`. It takes the smallest key (|dx| + |dy|, |dy|, dx, dy). The order of tries is:
  1. the pick at `inset`;
  2. the pick at `fallback_inset`;
  3. the tuft at `inset`;
  4. the tuft at `fallback_inset`.
  If nothing fits, the build is refused, because an empty tile would break the 65-tile count.
- **What is drawn.** The tile of own mask d is the brush stamp's north quarters for d's land corners, then the fitted piece, whole and with no rim, then the south quarters. The quarters are cut to the sand at inset 0 with no rim; they already lie on land corners.
- **Sand mask 0.** It keeps today's cut and rim.
- **Why not hard-code shifts.** The review's tables differ only by tie-breaks, and C3 changes the shapes, so the search re-runs on whatever the sand is.
- **The tuft.** It is a new hand file, 16×16 holding an 8×7 two-lobe sprig: brush greens lit from the upper left, with a #323c39 outline. It is never mirrored per corner, which would flip the light.
- **Rejected:** trimming a feature to the ground shape, which is today's cut (K39 (e)). This supersedes K39 (e)'s "the bush takes its outline colour on the cut". Also rejected: a new 9×10 hand bush now. Today's pick fits every mask, and the tuft covers the rounded tips.

### D2. An avalanche on the cell hash (C2, TR8)
- **The finaliser.** `cell_hash` returns murmur3's 32-bit finaliser (fmix32) of `hash("<layout id>:<x>,<y>")`.
- **32-bit arithmetic.** GDScript ints are 64-bit, so every multiply is split into 16-bit halves and masked to 32 bits. No signed overflow occurs, and the result is the same on every platform.
- **What stays.** Bit 0 still drives the foam phase and `>> 1` the variants (K41).
- **Rejected:** a per-layer salt. One mix is enough to break the diagonal stripes, and it keeps one seed per cell.

### D3. Rounded corners in the sand overlay (C3, TR2 tier A, TR6)
- **How the overlay is made.** It is regenerated as a diff against the pre-overlay `build_set` output:
  - an opaque pixel where the target differs;
  - `#ff00ff` where the target is clear and the built pixel is not.
  The existing row-4 hand pixels are kept.
- **Where the borders are.** The four straight edge tiles cross the cell borders at fixed points: the north edge's sand starts on row 4, the south edge's ends on row 11, the west edge's starts at x 4 and the east edge's ends at x 10. The corner shapes are anchored to those points.
- **Convex masks 1, 2, 4, 8.** The sand is an ellipse quarter round the land corner's outer point, for example (15.5, 15.5) in pixel-centre coordinates for mask 8. Its semi-axes reach the far edges' border points, which makes them 12 × 12 on today's sand: about the review's measured radius of 11.6 to 12. The cell centre toward the land stays on the sand.
- **Concave masks 7, 11, 13, 14.** The water corner is an ellipse-quarter bite that reaches the near edges' border points: 4 × 4, a 4 px fillet. Saddles 6 and 9 get two bites each.
- **The border.** Because both shapes pass through the straight edges' border points, every pair of masks that can sit side by side meets without a jog. Today's sheet has 30 jogging pairs; the new one has none. The four corner pixels pinned by `test_each_corner_set_holds_mask_m_at_its_place` stay as they are.
- **Colour (TR6).** Inside the new alpha, the fill is the full tile's ripple. The pack's #c08a5a ledge band and the extra #d9a066 above it become fill. Every sand pixel 4-adjacent to clear pixels inside the tile becomes the 1 px #d9a066 lip. The alpha of the straight masks is untouched, so their foam is too.
- **Rejected:**
  - chamfers (Q1 (b)): a chamfer leaves a tip cell's centre in drawn water and leaves no room for a bush;
  - the 47-tile blob and RPG Maker quarter tiles: each quadrant reads N, E and NE, which are all water both for a stair step and for a block corner, so they cannot draw slopes (C5's job);
  - marking the masks "hand", which breaks the overlay test.

### D4. A 4-adjacent rim (C3)
- `rimmed` and the rim of `shore_cut` at inset 0 mark only the kept pixels that have a 4-neighbour inside the tile that is off the shape.
- `shore_field` is unchanged. It feeds the foam, and its 8-adjacent steps are pinned by a fixture test.
- On a 45° edge the rim is then one pixel per row and column, not a 2 px stair.

### D5. Lighter foam corners, opt-in (C3, TR5)
- **The key.** The foam recipe gains `"corners": {"keep": 2, "colour": "#8fe0f0"}`.
- **Where the shore turns.** A pixel turns when every nearest pixel of the other kind (water for a sand pixel, sand for a water pixel, inside the tile) lies off its row and off its column. A straight run has none. Round a convex arc and a concave bite, both the sand and the water turn.
- **The damping.** On turning pixels:
  - on the sand, white is kept only on the last two steps (0 and -1); the wash further up becomes clear;
  - on the water, white is kept on step 1, and from step 2 on it takes #8fe0f0. This fades the outer diagonal of a convex corner and the inside of a bite.
- **What it never touches.** It never removes a step-1 water pixel, so the "no gap round a corner" rule holds. The fade step of the straight foam never changes.
- **The four straight masks are skipped.** The pack's west and east edges are wavy, so a few of their pixels have a diagonal nearest pixel. Damping them would change the straight foam and make seams against straight neighbours. A straight edge has no corner by definition, so masks 3, 5, 10 and 12 keep their foam byte for byte.
- **Why opt-in.** The fixture tests, which pass no key, keep today's foam.
- **The test.** In any 8×8 patch of a frame:
  - no corner frame is whiter than the straight edges' whitest patch (42 of 64);
  - inner corners and saddles are at most half white;
  - outer corners have at most 36 of 64 white.
  Today's sheet has 41 to 55. A whole-tile measure would pin nothing: today's whitest frame is 120 of 256.
- **Rejected:**
  - **scanning the pixel's row and column for water within a reach.** It misses the sand round a concave bite, which sees water only diagonally, and from a reach of 3 it already changes the wavy straight edges;
  - **`keep` 1.** It brings outer corners to 32 but thins the wash to one pixel, which reads as a gap beside the straight runs.

### D6. A soft, warped deep edge (C4, TR3)
- **Blur.** A pure `SeaMask.soft_channels(depth_bytes, size)` builds the RG8 bytes, blurs r and g with one separable Gaussian (σ 1 cell, radius 3, clamped at the grid's edge), and stays one texel per cell. The linear filter does the upsampling.
- **Clamp.** Each texel is clamped back to its own side of the cut:
  - r is at most 0.45 on a deep cell and at least 0.55 on any other;
  - g is at least 0.55 on a brackish cell and at most 0.45 on any other.
  The clamp keeps g ≤ r, so no shallows band appears between brackish and deep. Without it, the cay's lone deep cells flip at σ 1.
- **The fast path.** A grid that is all one step, such as the crossing, skips the blur.
- **Warp.**
  - The shader adds a static, position-only value-noise warp to the point where it samples the mask: an integer lattice hash every 48 px, smoothstep-interpolated, ±4 px. Its slope is at most 0.25, so the warp never folds the line.
  - `soft_channels` mirrors the warp in GDScript (the same integer hash). After the clamp it checks each water cell's centre at its warped point and pushes that cell's own texel toward its extreme until the centre keeps its step. The push only moves values back toward the unblurred mask, and that mask always holds (a texel's own weight is at least 0.56 when the point moves at most a quarter cell), so the loop ends.
- **Sway.** The time sway drops from 0.14 to 0.05. Measured on both islands' softened masks (build notes), the sway at its extremes now moves the line at most 2 px and the warp at most 3 px, about 5 px in all: within the review's 5.5 px, half a cell. At 0.14 the sway alone moved it 6 to 9 px.
- **Every pixel stays a ramp colour,** on nearest filtering.
- **The guard test** reads the bytes from `soft_channels`, not the texture, because the headless dummy renderer keeps no image. It checks every water cell's warped centre on both islands at the nominal cut.
- **Rejected:**
  - a 4× mask texture, which breaks the per-cell tests and the crossing's mask;
  - per-pixel noise in the cut, which gives a sawtooth edge (K39 (c));
  - varying the shallows ring's width in the maps, which is content (Q4 (b)).

## Reference games

Ideas and structure only, never code, data or text.

**Shattered Pixel Dungeon**
- *Borrowed:* `DungeonTileSheet.getVisualWithAlts` (DungeonTileSheet.java). Each cell's alternate visual is picked from a fixed per-cell variance value (`tileVariance`) against weighted chances. C2 gives our per-cell seed the same role: one stable value per cell that decides its cosmetic pick. Weighting the picks (about 70% clean) is C11.
- *Borrowed for C1:* `DungeonTileSheet.stitchWaterTile`. It changes only the water cell's own visual, and its neighbours stay whole. A feature is never trimmed to the ground.
- *Rejected for corners:* the same function's square 4-side mask. It suits rooms, not islands.

**DCSS**
- *Borrowed for C4:* `dgn_smooth_heights` (dgn-height.cc, used by dgn-shoals.cc), which smooths a height field before thresholding it into deep and shallow water.
- *Noted for C2:* `tile_init_flavour` (tileview.cc), DCSS's per-cell flavour.

**Brogue CE**
- *Noted, not used:* `createBlobOnGrid` and `cellularAutomataRound` (Grid.c) smooth shapes by cellular automata. They reshape content, which is C6.

**ALttP and Pokémon** (general knowledge of how they look; nothing copied)
- *Borrowed:* beaches and ledges end in rounded corners. Bushes are whole objects the ground never trims.
- *Rejected for stairs:* blob autotiling, as in D3.

**Don't Starve Together** (dontstarve.wiki.gg; nothing in `docs/REFERENCE_DST.md` covers terrain drawing)
- *Borrowed for C4:* on [Ocean/DST](https://dontstarve.wiki.gg/wiki/Ocean/DST), the ocean's depth is read by its shade, darker for deeper. Its coastal, swell, rough and hazardous waters grow darker with distance from land, as bands rather than tiles.
- *Rejected:* DST's four depth bands and its wave shapes per zone. They are more than a shallows-and-deep island needs (C7 handles value).
- How DST draws its coastline foam is not on that page [unverified], so nothing is borrowed for it.

## Risks / Trade-offs

- **[C2 re-rolls every pick]** Each cell's speck, bush variant and foam phase changes once. The `docs/art-pass` terrain images are re-shot. The tests recompute through `cell_hash`, so they need no new numbers.
- **[The arc leaves less room on tips]** The small bush no longer fits convex masks 1, 2, 4 and 8. The tuft covers them, and the build refuses a mask where neither fits.
- **[Shader and GDScript warp drift apart]** A test reads the shader's warp constants against the GDScript mirror's. The correction loop works on bytes with a margin, so float32 against float64 differences cannot flip a centre.
- **[The sea moves less]** Halving the sway makes the deep edge calmer. The warp's static bends carry the shape.
- **[Build time]** The blur and the check are O(cells × 7) in GDScript. The 1500 ms island build bound is checked by the existing test, and the crossing skips the blur.

## Migration Plan

Art only. Rebuild the sheets with `python -I tools/art/terrain.py --packs <main checkout>/game/assets` and re-import. To roll back, revert the commit: no save, network message or layout depends on these pixels.

## Build notes

Measured values and departures, as built on 2026-11-14 and 2026-11-15.

**C2.** On a 16×16 block, the djb2 string hash alone gave a pick equal to its north-east neighbour's for 240 of 256 cells, and (x, y) always equal to (y, x): 241 of 241 mirrored pairs. Through fmix32 the counts are 58 to 60 of 256 and 54 to 67 of 241, for the sandbar, the coast cay and a test id. Godot's `hash()` of a String is djb2 over its characters, so the Python model in the review reproduces it exactly.

**C1.** The fit's placements on today's sand match the review's table exactly:

| Sand mask | Piece | Shift | Inset |
|---|---|---|---|
| 1 | pick | (-3, -3) | 1 |
| 2 | pick | (1, -2) | 0 |
| 3 | pick | (0, -3) | 1 |
| 4 | pick | (-3, 2) | 1 |
| 5 | pick | (-3, 1) | 0 |
| 6 | pick | (2, -3) | 1 |
| 7 | pick | (0, -3) | 1 |
| 8 | pick | (1, 0) | 0 |
| 9 | pick | (0, 0) | 0 |
| 10 | pick | (2, 0) | 1 |
| 11 | pick | (2, 0) | 1 |
| 12 | pick | (0, 1) | 1 |
| 13 | pick | (0, 0) | 1 |
| 14 | pick | (0, 0) | 1 |

On the rounded sand (C3) the four convex tips take the tuft and the rest move slightly:

| Sand mask | Piece | Shift | Inset |
|---|---|---|---|
| 1 | tuft | (-4, -4) | 1 |
| 2 | tuft | (4, -3) | 1 |
| 3 | pick | (0, -3) | 1 |
| 4 | tuft | (-4, 1) | 1 |
| 5 | pick | (-3, 1) | 0 |
| 6 | pick | (-2, 0) | 1 |
| 7 | pick | (-2, 0) | 1 |
| 8 | tuft | (4, 3) | 1 |
| 9 | pick | (0, 0) | 1 |
| 10 | pick | (2, 0) | 1 |
| 11 | pick | (0, 0) | 1 |
| 12 | pick | (0, 1) | 1 |
| 13 | pick | (0, 0) | 1 |
| 14 | pick | (0, 0) | 1 |

The owner's spot, sandbar cell (20, 35), is sand mask 10 and takes the whole pick at (2, 0). C1 alone changed only `brush_shore.png`. Sand mask 0 keeps the cut and rim; no shipped layout has a scrub cell there.

**C3.**
- **The overlay.** It is regenerated as a diff against the pre-overlay `build_set` output. That gives 554 overlay pixels on rows 0 to 3, and row 4 keeps the old hand pixels.
- **The geometry, reproducible from these numbers.**
  - The straight edges cross the borders at west x 4, east x 10, north row 4 and south row 11, measured from masks 10, 5, 12 and 3.
  - A convex corner is the ellipse quarter ((x − cx) / A)² + ((y − cy) / B)² < 1 round the land corner's outer point, for example (15.5, 15.5) for mask 8. Its semi-axes are A = 16 − 4 or 10 + 1 across and B = 16 − 4 or 11 + 1 down, so 12 × 12.
  - A concave bite is the same shape round the water corner with semi-axes 4 × 4.
  - The colours are the pack tile's own pixel where it is sand and not #d9a066 or #c08a5a, else the full tile's ripple. Every sand pixel 4-adjacent to a clear pixel inside the tile is #d9a066.
  - Mask 3 keeps its alpha and is recoloured the same way. Masks 0, 5, 10, 12 and 15 are untouched.
- **What it fixed.**
  - Neighbouring masks that jog at their shared border: 30 pairs today, 0 now.
  - Every convex tile keeps the centre pixel toward its land.
  - The fit still finds a place on every mask.
- **Every derived sheet followed:** sand, plain, plain shore, dune shore, brush shore, foam and shade. Sizes and tile counts are unchanged. The straight foam rows 3, 5, 10 and 12 are byte-identical. A rebuild gives the twelve tracked sheets byte for byte.
- **The foam.** In any 8×8 patch of any frame, the whitest counts out of 64 are:

| Tiles | Today | Now |
|---|---|---|
| Convex corners | 49–53 | 34–35 |
| Concave corners and saddles | 41–44 | 26–29 |
| The islet (shape untouched) | 55 | 42 |
| Straight edges | 34–42 | 34–42 |

- **Departure.** The spec scenario "Corner foam is no heavier than a straight run" reads "no whiter than the whitest straight patch, inner corners at most half, outer corners about half (at most 36)". The design's first wording, "no patch more than half white", cannot hold without changing the straight runs, which are already 34 to 42.
- **A test that was dropped.** A GUT test that the second water pixel on the convex diagonal is the fade colour pinned nothing. On today's square corners that pixel is already three steps out and faded, and in some full frames the strip leaves it clear. The fade is pinned by the Python rule test and the patch counts.
- **Not done here: the dune's own inland corners.** The re-shot `sandbar_day.png` still shows stair steps where the light dune meets the darker inner beach, because the dune's own corner tiles are square. It is the same "too square" look, inland. It needs a `dune.png` overlay by the same method, a follow-up next to C9 (palms counted as dune).

**C4.**
- `SeaMask.soft_channels` takes 113 ms on the sandbar (80 × 72) and 104 ms on the coast cay (88 × 64), with the lattice values cached. It took 309 ms before the cache. The island build stays under its 1500 ms bound.
- Of the cells beside the other step, the warp check resets only 10 of 400 on the sandbar and 3 of 352 on the cay to a hard step. The rest are graded.
- The clamp is in bytes: at most 114 on a deep texel, at least 141 on any other. A float clamp at 0.55 rounded to 140, below the cut's side, and the guard caught it.
- Measured on the dumped masks, as the largest 8-connected distance from the rest line of a pixel that changes side: the warp moves the line at most 3 px on both islands. The sway at ±0.05 moves it at most 2 px; at ±0.14 it moved it 6 px on the sandbar and 9 px on the cay. K47's "±0.14" is superseded by 0.05.
- `TerrainView.setup_sea` keeps its parameters and now returns the mask's bytes, kept as `TerrainView.sea_channels` for the tests. `crossing_sea.gd` is untouched and ignores the return.
- The crossing's mask is all deep, so it skips the blur.
- The old per-texel test `test_a_shallows_cell_picks_the_shallows_row_and_a_deep_cell_the_deep_row` still holds by the clamp. Headless, it stays pending.
- The windowed captures compiled the shader with no error: `docs/art-pass/sandbar_day.png`, `coast_cay_day.png` and `sandbar_night.png` are re-shot, and the review driver's sandbar pass ran clean.

**Checked after review.**
- No scene or material saves a value for the sea's `wobble`, so the shader's 0.05 default is what runs. A test pins that default.
- Neither shipped island has a sand-mask-0 cell (counted on the built layouts), so leaving the islet's tile untouched changes nothing anyone sees today.
- The GPU's warp and the GDScript mirror agree. On the re-shot `sandbar_day.png` and `coast_cay_day.png`, each water cell's centre pixel was classified by its ramp colour: 1 of 4,769 and 1 of 4,611 show the other step. That fits the sway at the moment of capture; a drifted mirror would show far more.
- The shader was compiled only in the windowed Windows runs. Headless CI never compiles it.

**1-player check.** The after capture of the owner's spot comes from the review's own driver (`--only=sandbar`, solo, offline). The pair is kept in `docs/art-pass/review-2026-11-14/` as `before_west_shore_x3.png` and `after_west_shore_x3.png`, with the x4 inner bay and the x6 bush crop side by side. The bushes are whole, with no cut line. The coast's corners are round. The south-facing beaches end in the 1 px lip instead of a dark ledge. The deep edge curves instead of copying the coast's staircase. C2 re-rolls every pick, so specks and bush variants differ in the after capture by design.
