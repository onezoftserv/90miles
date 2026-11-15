# Proposal

## Why

The owner's two complaints about the islands: "things look too square sometimes, and grass at the border of the beach looks cut". The art and HUD review of 2026-11-14 (80 agents; `docs/art-pass/review-2026-11-14/DESIGN_PASS.md`) traced both to how the beach tiles are built, not to the drawing order:

- Bushes on shore cells are sliced on purpose by the tile builder: an old fix (archived art-pass K39 (e)) cut them to the sand with a dark rim. 59 of the sandbar's 84 scrub cells are shore cells (TR1).
- Every coast corner is a right-angle block or notch, so the shore is the cell grid shrunk by 3–4 px (TR2). The foam outlines every right angle in white (TR5), and the deep-water edge copies the coast's staircase one cell further out (TR3).
- Variant picks repeat along diagonals, because the cell hash is a string hash whose low bits barely mix (TR8).

On 2026-11-14 the owner accepted every recommended option in the review and approved starting this wave. Q1 (a): rounded arcs on convex corners and 4 px fillets on concave ones, with a small hand-drawn tuft on convex tips. Q2 (a): one fitted whole bush on shore cells now. Q4 (a): the deep edge is art only.

## What Changes

The changes go in this order, smallest first. They are art only: no layout, terrain kind, walkable cell or simulation value changes.

- **C1, fit, don't cut (TR1).** An opt-in `"fit"` key on the brush's shore recipe. On a shore cell the builder places the whole small bush where a placement search says it fits on the sand, with no cut line and no dark rim. Where it does not fit, it places a small hand-drawn two-lobe tuft (`tools/art/fixes/terrain/shore_tuft.png`). The quarter stamps for the brush's own land corners stay. A lone sand cell (sand mask 0) keeps today's cut.
- **C2, random-looking picks (TR8).** `TerrainArt.cell_hash` passes the string hash through a 32-bit avalanche (the murmur3 finaliser, fmix32), every step masked to 32 bits. It stays deterministic on every peer and every build. Every cell's cosmetic pick and foam phase bit changes once.
- **C3, rounded coast (TR2 tier A, TR5, TR6).**
  - The sand overlay redraws the convex corners (masks 1, 2, 4, 8) as quarter arcs and the concave corners (7, 11, 13, 14) and saddles (6, 9) as 4 px fillets.
  - The sand's 3 px south ledge face becomes the same 1 px lip the other sides have (TR6). The alpha of the straight edges does not change.
  - Every sheet derived from the sand follows: plain, plain shore, dune shore, brush shore, foam and shade.
  - The rim of a cut plain tile marks only pixels 4-adjacent to water, so it stays 1 px on a diagonal.
  - An opt-in foam `"corners"` key keeps white only on the two sand pixels nearest the water where the sand faces water two ways, and fades the outer diagonal of convex corners. The straight foam pieces stay byte for byte.
- **C4, a soft deep edge (TR3).**
  - The sea's depth mask is blurred with a separable Gaussian (σ 1 cell), still one texel per cell.
  - Each cell's texel is then clamped back to its own side of the cut, so no cell centre changes step.
  - The sea shader adds a static, position-only noise warp of about ±4 px to bend long straight runs. Its sway is halved so the line moves no more than half a cell.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `art-pass`:
  - "Land edges" gains scenarios for rounded coast corners, the even 1 px lip, and a bush on a shore cell drawn whole.
  - "Shoreline overlay" gains "Corner foam is no heavier than a straight run".
  - "Scrolling sea" says the deep and shallow steps meet in a curved line, and that each cell's centre keeps its own step at the nominal cut.
  - "Seeded cosmetic variants" gains "Neighbouring cells are not striped".

## Impact

- Art tools (`tools/art/`):
  - `terrain.py`: the fit step, the 4-adjacent rim and the foam corner damping.
  - `terrain_tiles.json`: the `"fit"` and `"corners"` keys.
  - `fixes/terrain/sand.png`: the new corner shapes and the even lip.
  - The new `fixes/terrain/shore_tuft.png`.
  - `test_terrain.py`.
- Rebuilt sheets: `game/assets/art/terrain/` (sand, plain, plain_shore, dune_shore, brush_shore), `game/assets/art/sea/foam.png` and `game/assets/art/decals/shade.png`. No sheet changes size and no tile set changes its tile count.
- Game scripts:
  - `game/scripts/art/terrain_art.gd`: `cell_hash`.
  - `game/scripts/art/sea_mask.gd`: a pure `soft_channels` and the warp it mirrors.
  - `game/scenes/art/terrain_view.gd`: `setup_sea` uses `soft_channels`, with its signature unchanged (the crossing's sea calls it).
  - `game/scenes/art/sea/world_sea.gdshader`: the warp and the smaller sway.
- Tests: `test_terrain_art.gd`, `test_terrain_view.gd`, `test_shoreline.gd` and the art tool tests gain the pins below. `test_art_sim_invariance`, `test_draw_order` and the terrain tests stay green.
- Docs: the design pass and its four mockups are copied to `docs/art-pass/review-2026-11-14/`. The `docs/art-pass` terrain images are re-shot, because every pick changes.
- No layout, simulation, networking or HUD file changes. The coast cay's rectangles (C6), the darker shallows (C7) and slope tiles (C5) are later changes.
