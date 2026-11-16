# Proposal

## Why

Wave 1 of the 2026-11-14 art pass (art-coast-pass, C1–C4) fixes the owner's two complaints: cut shore bushes and square coasts. The same review (`docs/art-pass/review-2026-11-14/DESIGN_PASS.md`, sections 2.1 and 2.2) found seven smaller terrain problems that are still on screen after wave 1. Wave 1 itself left one more:

- **Land and water read apart by hue only (TR7).** The sand #e4b488 and the shallows #5fcde4 have the same value (1.01:1). In greyscale the coast vanishes, and the white foam line is its only value edge.
- **Palms stand in square pits (TR11).** A palm cell is beach, so the dune cells round it lose a corner. 4 of the cay's 5 palms and 3 of the sandbar's 6 stand in notches or pits.
- **Dense scrub is wallpaper (TR10), and one pick has a hole (TR14).** Every whole brush cell draws the same round bush on an 8 px pitch, which covers most of the secret cay. Shore bushes never vary (Q2 (a) left their variants for a later change: this one). One bush pick shows a 6 px hole of sand.
- **The beach shows its grid (TR12).** The sand is a recoloured grass field: busy diagonal stripes, and pebble specks on a fixed lattice in 75% of cells.
- **The rocky point is a flat crack carpet (TR9).** It has no lip or face, and it meets the sand in a straight 24-cell seam whose rim is invisible.
- **The lagoon has surf (TR13).** The cay's enclosed brackish lagoon has the same animated surf as the open sea.
- **The dune's own corners are still square (C3's dune part).** Wave 1 rounded the sand's corners but not the dune's. Where the light dune meets the darker inner beach, its corners still step like stairs (see wave 1's re-shot `docs/art-pass/sandbar_day.png`). On 2026-11-15 the owner chose "Next PR" for it.
- **The raft hangs over the water (TR15).** Before a raft exists, a wide shade lies on bare sand west of the site. Once built, the 64×32 raft hangs half over the shallows, with its shade under the left tube only.

On 2026-11-14 the owner accepted every recommended option in the review. Q2 (a): one fitted shore bush in wave 1, and 2–3 shore variants "later, in their own change". Q3 (a): darker shallows plus a visible wet-sand edge. Q4 (a): the deep edge is art only. On 2026-11-15 the owner approved queuing waves 2, 3 and 5.

## What Changes

Nine parts, built smallest first, one PR each. All of them are art only: no layout, terrain kind, walkable cell, synced value or simulation number changes.

- **TR14, the hole in a bush pick.** The 6 px gap of sand inside one brush pick is painted over. It shows beside the owner's spot on the west shore in wave 1's after capture, so it ships first.
- **C9, palms count as dune (TR11).** A palm cell lies on the dune layer when at least 3 of its 4 orthogonal neighbours count for the dune. The brush never takes a palm cell. The dune counts go from 422 to 425 on the sandbar and from 393 to 397 on today's coast cay.
- **The dune's inland corners.** The `dune.png` overlay is redrawn by wave 1's method:
  - quarter arcs on outer corners;
  - 4 px bites on inner corners and saddles;
  - every shape through the straight edges' border points, keeping the dune's ragged lip.
  The hand islet, the row-4 picks and the straight edges stay, and `dune_shore.png` follows.
- **C13, still water is still (TR13).** One flood fill per build finds water bodies with no deep cell. A shore cell whose water neighbours are all in such a body gets a still foam piece: a thin line that does not move. The open sea keeps its animated surf.
- **C14, the raft on the sand (TR15).** On the beach, the raft site's stage frames and the raft are drawn shifted toward land by an art-data offset (16–24 px), so the hull rests on the sand. A wide soft drop shadow comes with the half-built and built stages, and none with the marked site or its materials. The terrain view's wide raft shade decal is removed. The crossing deck uses the same frames and does not move.
- **C11, a beach with no grid (TR12).** The sand recipe maps both stripe colours to one tone. The four row-4 sand picks are redrawn so that they are distinct and not mirrored. The picks are weighted, about 70% clean, through art data. The dune lip is retoned and stays 1 px.
- **C10, scrub variety (TR10).**
  - Three whole-cell brush picks that keep the four corner quarters identical and vary the centre, with a dark under-canopy fill between the lobes.
  - 2–3 fitted shore bush variants, picked by hash on shore cells.
  - `TerrainArtData` names its picks per mask.
- **C12, a rocky point with an edge (TR9).**
  - The rock rim moves to #323c39, together with a softened seam: a ragged edge and pebble decals of at most 8×6 on the sand side.
  - A 1 px lit lip on the north edge, and a 2–3 px face only on water edges (in `plain_shore.png`).
  - The pick interiors are redrawn, keeping where their cracks cross the cell edges.
  - The point stays lower and lighter than the cliff.
- **C7, land and water apart by value (TR7, Q3 (a)).**
  - The shallows ramp drops to a base near #3f9fc0. The brackish ramp moves so that it stays between the shallows and the deep. At most 8 new palette colours; the palette stays within its 64 cap.
  - The foam stops short of the sand's wet lip, so the lip shows below it.
  - The tide pool's water is repainted, and the art tuning means are recomputed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `art-pass`:
  - New requirements: "Land and water read apart by value", "A palm stands in its dune", "Dune corners are rounded", "Scrub varies", "The beach shows no grid" and "The rocky point has an edge".
  - "Shoreline overlay" (as wave 1 leaves it): still water gets a still piece instead of surf. This change archives after art-coast-pass.
  - "Tide pools and contact shade": the raft site leaves the decal list.
  - "Raft site and raft": the frames rest on the sand, a wide shadow comes with the stage, and the crossing deck stays where it is.

## Impact

- Art tools (`tools/art/`):
  - `terrain_tiles.json`: the water ramps, the stripe map, the pick weights, the brush picks, the shore variants, the rock rim, the face and lip step, the still foam, and the foam's land climb.
  - `terrain.py`: the rock face and lip step, the still foam sheet, and the shore variant fit.
  - `fixes/terrain/sand.png`, `brush.png`, `plain.png`, `dune.png` and `tide_pool.png`.
  - New hand files: a pebble decal and a 30×11 wide shadow.
  - `test_terrain.py`.
- Rebuilt art:
  - `game/assets/art/terrain/`: every sheet, `terrain_art.tres` and `terrain_tiles.tres`;
  - `sea/` (`water_ramps.png`, `foam.png`, a new still-foam sheet, `shore_tiles.tres`);
  - `decals/` (pebbles), `shadows/` (the wide shadow);
  - `palette/master_palette.png` and `.gpl`;
  - `game/resources/art_tuning.tres` (the ground means).
- Game scripts:
  - `game/scripts/art/terrain_art.gd`: the palm rule and the weighted, per-mask picks;
  - `terrain_art_data.gd`: the per-mask pick fields;
  - `shore_rule.gd`: the still-water flood fill;
  - `game/scenes/art/terrain_view.gd`: passes the palms, removes the wide raft shade, places the pebble decals;
  - `structure_look.gd`, `structure_art_data.gd`, `structure_art.tres` and `shadow.gd` / `shadow.tscn`: the raft offset and the wide shadow.
- Tests: the terrain, shoreline, tile set, terrain view, structure look, drop shadow and palette tests named in tasks.md. `test_art_sim_invariance` and `test_draw_order` stay green.
- No layout, simulation, networking or HUD file changes.
- Not in this change:
  - the bush over a crouched body (C8, wave 3; it lands after C10);
  - the garita, decor, lean-to and small props (C15–C18);
  - slope tiles (C5);
  - the coast cay's reshape (C6, coast-cay-reshape);
  - the forest rows (TR16).
