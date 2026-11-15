# Tasks

Every art rebuild runs `python -I tools/art/terrain.py --packs C:/Users/liann/src/90miles/game/assets`, then `python -I tools/art/check.py game/assets/art`, then the import twice. Every group ends with the import, the smoke run and GUT passing, plus `python -m unittest` in `tools/art`.

## 1. Setup

- [ ] 1.1 Copy `DESIGN_PASS.md` and the four `mockups/m*.png` into `docs/art-pass/review-2026-11-14/`. Verify the five files are there and `DESIGN_PASS.md`'s mock paths still name them.

## 2. C2: random-looking picks (TR8)

- [ ] 2.1 In `test_terrain_art.gd`, write the stripe tests and see them fail on today's hash:
  - over a 16×16 block the 2-bit pick equals its north-east neighbour's in under 40% of cells;
  - (x, y) and (y, x) are not always equal.
  Add a 1-player test: a solo sandbar build gives the same picks twice.
- [ ] 2.2 Pass `TerrainArt.cell_hash` through fmix32 with 32-bit masking (design D2). Verify that the new tests and every test that recomputes through `cell_hash` pass.

## 3. C1: whole bushes on the waterline (TR1)

- [ ] 3.1 In `tools/art/test_terrain.py`, write the fit tests on fixtures:
  - a fit at the inset;
  - an inset-0 fallback;
  - the tuft fallback;
  - a refusal when nothing fits;
  - sand mask 0 keeps the cut and rim;
  - a fitted tile of own mask 0 is a pixel-exact shift of the pick;
  - `"fit"` keys are validated;
  - the tuft file is a read fix file.
  See them fail.
- [ ] 3.2 Implement the `"fit"` key in `terrain.py` (design D1) and draw `tools/art/fixes/terrain/shore_tuft.png`. Add the key to the brush shore in `terrain_tiles.json`. Rebuild. Verify that only `brush_shore.png` changes against a scratch rebuild of today's recipe.
- [ ] 3.3 In `test_terrain_art.gd`, verify on the made sheet that every own-mask-0 tile of `brush_shore.png` for sand masks 1–14 is a whole, unchanged shift of the pick or the tuft ("no shore bush pixel is cut"). Add the 1-player test: on the solo sandbar, shore scrub cell (20, 35) takes atlas (10, 0) of the brush shore source, and that tile holds all 90 pixels of the pick.

## 4. C3: rounded coast corners, an even lip, lighter corner foam (TR2, TR5, TR6)

- [ ] 4.1 In `tools/art/test_terrain.py`, write the rim and foam-corner tests on fixtures and see them fail:
  - the rim of a 45° fixture is exactly the pixels with a 4-neighbour off the shape;
  - with `"corners"` set, white on sand pixels that face water two ways is only at steps 0 and -1;
  - the outer diagonal of a convex fixture fades;
  - the step-1 ring stays white;
  - a straight fixture is unchanged.
- [ ] 4.2 Make `rimmed` and the inset-0 rim of `shore_cut` 4-adjacent (design D4), and add the foam `"corners"` key (design D5) to `terrain.py` and the recipe.
- [ ] 4.3 Regenerate `tools/art/fixes/terrain/sand.png` (design D3):
  - arcs on masks 1, 2, 4 and 8;
  - fillets on 7, 11, 13 and 14, and two each on saddles 6 and 9;
  - the even 1 px lip on every mask but 0;
  - row 4 kept.
  Rebuild. Verify with a byte diff that the straight foam rows 3, 5, 10 and 12 are unchanged and that every derived sheet keeps its size.
- [ ] 4.4 In `test_terrain_art.gd`, pin the result and see these fail on today's sheets:
  - no corner foam frame has an 8×8 patch more than half white;
  - the sand tiles of the four straight edges and the corners end in the one #d9a066 lip with no #c08a5a band;
  - convex tiles keep their land corner's quarter arc.
  Add the 1-player test: on the solo sandbar every shore cell's sand tile keeps opaque the centre pixel that faces its land. Verify that `test_each_corner_set_holds_mask_m_at_its_place`, the plain and shore tests, and C1's tests still pass on the rebuilt sheets.

## 5. C4: a soft deep-water edge (TR3)

- [ ] 5.1 In `test_terrain_view.gd`, write the guard and see it fail on today's code:
  - `SeaMask.soft_channels` exists;
  - on the sandbar and the coast cay, every water cell's warped centre is on its own side of 0.5, by a margin, in both channels;
  - g ≤ r on every texel;
  - a deep cell beside shallows is graded, neither 0 nor 255.
  Add the 1-player test: a solo sandbar run's sea material holds the softened mask, and a shallows cell beside deep keeps the shallows row.
- [ ] 5.2 Implement `SeaMask.soft_channels` and its warp mirror (design D6). Use it in `TerrainView.setup_sea`, with the signature unchanged. Add the warp and the 0.06 sway to `world_sea.gdshader`. Verify that the guard, the crossing art test, the movement playground test and the 1500 ms build bound pass.
- [ ] 5.3 Pin the shader's warp constants against the GDScript mirror in `test_terrain_view.gd`, and update K47's sway number in this design's build notes.

## 6. Integration

- [ ] 6.1 Rebuild to scratch and `cmp` every terrain sheet against the tracked ones, so the build is byte-for-byte reproducible. Run `check.py`, `python -m unittest` in `tools/art`, the import twice, smoke and GUT. All must be clean.
- [ ] 6.2 Windowed 1-player check: capture the sandbar's west shore at x3 and compare it with `captures/sandbar_day_west_shore_mid_x3.png`. Re-shoot `docs/art-pass/sandbar_day.png`, `coast_cay_day.png` and `sandbar_night.png` with `tests/manual/capture_terrain.tscn`. Read the run logs for shader errors.
- [ ] 6.3 Update `TASKS.md`, record the measured placements and numbers in this design's build notes, and run `openspec validate art-coast-pass --strict`.

## Workflow follow-up

- Open the PR into `main` and send the coordinating session the link and the before and after captures.
- Archive the change after the owner has seen the captures (not in this PR).
