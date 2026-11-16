# Proposal

## Why

The owner's complaint, "things look too square sometimes", has a content half that art cannot fix. The art and HUD review of 2026-11-14 (`docs/art-pass/review-2026-11-14/DESIGN_PASS.md`, finding TR4 with PR5 and the rock outline part of TR9, change C6) found that the coast cay is authored as rectangles:

- the west coast is ruler-straight down column 9 (26 cells), the bay's north shore along row 26 (36 cells) and the outer north coast along row 15 (32 cells);
- the bay between the two arms is a rectangular shallows flat (columns 21–56 from row 27);
- the rocky point is a rectangular block 11 cells wide (columns 58–68) that meets the sand in a straight 23-cell seam and never narrows to a point;
- six of the eight driftwood stand on row 26 every 5–6 cells, and the 29 scrub cells are lone cells on exact diagonals.

The layout came from a throwaway "two 12-wide strips and a spur" script (archived `2026-11-08-coast-cay/design.md`). Wave 1 of the art pass (art-coast-pass, C1–C4) rounds every coast corner and softens the deep edge, but rounded corners on a ruler line still read as a ruler line.

On 2026-11-14 the owner accepted every recommended option in the review, including Q5 (a): reshape the coast cay's rectangles after the coast-cay-bench work merges (it merged in #58). Q4 (a) keeps the shallows ring art only, so this change does not vary its width.

## What Changes

A content change: it moves walkable, swimmable and hiding cells on the coast cay. Nothing else in the game changes.

- **Re-author `game/resources/islands/coast_cay.tres`'s rows.**
  - The bay becomes a bight with a curved shore, not a rectangle.
  - The rocky point narrows toward its southern tip, and its seam with the sand gets jogs.
  - The long straight coasts (west, outer north, the bay's shores, the rock's east face) get 1–2 cell jogs every 4–8 cells.
  - The 8 driftwood lie in groups of 1–3, on more than one row.
  - The scrub grows in clumps, each with a 2×2 core.
  - No pick-up, palm or sign stands on an outer corner of the coast.
- **What stays.** Every count, the four landing cells, the raft site (19, 45), the workbench (16, 39) and its dry grass, the observation post block (rows 38–40, columns 63–67), the lagoon and its drinking spot, the shallows ring rule, the land band (1,000–1,150, 16–22%), "no land more than 6 tiles from water", reach from every landing cell, the lone arrival's walk bands, the bench's patrol and smoke rules, and the patrol's lit raft site.
- **New requirements pin the shape** with measures that fail on today's map: no straight coast or rock seam longer than 10 cells, a rock point that narrows, driftwood and scrub in groups, nothing on an outer corner, and the places that do not move.
- **Tests and docs.** The outline tests are written first. The counts that the shape moves (land cells, layer counts, shore cells, the patrol loop's length and sea distances) are re-pinned with reasons. `docs/ISLANDS.md` §2 drops "a C of two 12-wide strips and a rocky spur round shallow flats" and gives the new land count and walks.

The sandbar is not in this change. Filling its four 2-cell notches is a new owner question (design.md, "Owner decisions"); a gated task group adds it only on a yes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `island-generation` adds "Coast cay coastline", "Coast cay rocky point", "Coast cay driftwood and scrub", "Coast cay pick-ups off outer corners" and "Coast cay reshape keeps its places". "Handmade coast cay", "Coast cay landing", "Coast cay contents" (modified by the open coast-cay-bench change), "Coast cay reach" and the bench's three requirements keep their text, and their tests stay green on the new map.

## Impact

- Data: `game/resources/islands/coast_cay.tres` (rows only; the glyph legend, pick-up entries, signs and fields stay).
- Tests:
  - `test_coast_cay_layout.gd` gains the outline tests;
  - re-pinned with a reason each: `test_coast_cay_bench.gd` `LAND_CELLS`, `test_terrain_art.gd` `test_layer_cell_counts_of_the_two_islands` (coast cay `[1021, 393, 29, 256]`), `test_shoreline.gd` (265 shore cells), `test_patrol_loop.gd` (perimeter 195), `test_patrol_triggers.gd` (farthest land 6.3, land beyond 2/3/6 tiles 632/436/2);
  - kept green with no edit: `test_coast_cay_solo.gd`, `test_coast_cay_bench.gd`'s rules, `test_coast_cay_net.gd`, `test_patrol_coverage.gd` (34% ± 3 spotted, the raft site lit), `test_structure_art.gd` (the raft site at (19, 45)), `test_arrival_scatter.gd`, `test_terrain_view.gd` (a rock shore cell, the post's corner set), `test_lean_to.gd`, `test_handmade_layouts.gd`.
- Gameplay: hiding spots move with the scrub, and the patrol's lap changes length. The share of land a lap spots must stay within today's pin (34% ± 3 points), or the build stops and asks.
- Docs: `docs/ISLANDS.md` §2, `TASKS.md`, and the `docs/art-pass/coast_cay_day.png` capture.
- No script, scene, autoload, network message or art file changes. The art changes of the art pass (art-coast-pass, art-terrain-polish) read the layout and follow it.
