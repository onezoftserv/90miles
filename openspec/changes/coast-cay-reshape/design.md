# Design

## Context

See proposal.md for why. The review's finding TR4 (with PR5 and the rock outline part of TR9) and its change C6 are in `docs/art-pass/review-2026-11-14/DESIGN_PASS.md` (sections 2.1, 2.2, 2.4 and 3). That path lands with art-coast-pass (wave 1).

How the coast cay is made today:
- `game/resources/islands/coast_cay.tres` is an `IslandLayoutData`: 64 rows of 88 glyphs, a legend (`terrain_glyphs`), pick-up entries, signs and named glyphs for palms, the raft site, the workbench, the drinking spot and the landing (`1`–`4`). `IslandLayout.build` reads it on every peer.
- The shape (measured 2026-11-15 on main 8edc5ab): a north band of dune and beach (rows 13–26), a west arm (columns 9–20, rows 27–48) with the landing, the workbench and the raft site, a rock spur (columns 58–68, rows 21–45) holding the observation post, and between them a shallows flat (columns 21–56, rows 27–49) open to the south. The brackish lagoon (42 cells) sits in the north-west.
- 1,021 land cells (18.1%), 29 scrub, 393 Dune-layer cells, 256 rock (`test_terrain_art.gd`), 265 shore cells (`test_shoreline.gd`).

What else reads the shape:
- **The patrol** (guardacostas-stealth, built): a loop round the island's hull, 4 tiles out. Its lap is 195 tiles on the cay (`test_patrol_loop.gd`), it spots 34% of the land (`test_patrol_coverage.gd`, ± 3 points), and it lights the cay's raft site, on purpose ("gives island 2 more teeth"). `PatrolTriggers` pins the cay's sea distances (`test_patrol_triggers.gd`).
- **The workbench** (coast-cay-bench): (16, 39), with every land cell within 2 tiles of it more than 2 tiles from the sea, out of the beam for a whole lap, and 2 dry grass at (15, 37) and (17, 37).
- **The art:** art-coast-pass rounds every corner the layout has, and art-terrain-polish (C9, C12, C13) derives its coast cay checks from the layout, so neither needs this change's cells.
- **Cover:** scrub is brush cover for a crouched player (guardacostas-stealth, player-movement), so moving scrub moves the cay's hiding spots. The post's shade stays the best hiding spot (`docs/ISLANDS.md` §2).

Constraints:
- No land cell more than 6 tiles from water caps every strip of land at about 12 cells wide, so land cannot be added by widening an arm.
- The land band is 1,000–1,150. Narrowing the rock's tip costs about 20 cells, which would put today's 1,021 on the lower bound.

## Goals / Non-Goals

**Goals:**
- A coast cay that reads as an island, not a set of rectangles, once art-coast-pass has rounded its corners.
- Every number and rule the cay already meets stays met, and a lone player plays it exactly as before.
- Pin the shape with tests that fail on today's map.

**Non-Goals:**
- The sandbar. Its notches are a new owner question (see "Owner decisions"); its horn tips and shallows ring stay.
- The shallows ring's width (Q4 (a): art only) and the bay's depth: the bay stays all shallows, so wading routes stay.
- The lagoon's shape. It is small and already meets the outline rule; its octagon look is the sea art's job (C4).
- Moving any point of interest, the landing, the raft site, the workbench, its dry grass, the post or the drinking spot.
- Any count, sign, item, creature, patrol rule or art file.
- A tracked generator for the cay. It stays handmade data (the island-generator change builds generated islands).

## Decisions

### D1. Measures the new map must meet (and today's fails)
All on the built layout; "water" is deep, shallows or brackish.
- **Coast run.** For each side (north, south, east, west), a run is consecutive land cells along one row (north, south) or one column (east, west) whose neighbour on that side is water. No run is longer than 10. Today: 36 (row 26, the bay's north shore), 32 (row 15), 26 (column 9) and 19 (column 20); the rock's east face is 18.
- **Rock seam.** The same along the rock: consecutive rock cells whose neighbour on one side is beach, dune or scrub. No run is longer than 10. Today: 23 (column 58, its west side).
- **Why 10.** The review asks for a jog every 4–8 cells on the long coasts. A curve's apex rasterises to a flat run of about 2√R cells (7 at a radius of 12, 9 at 20), so 10 lets a bight be a curve without a forced step at its apex.
- **The rock narrows.** Counting rock cells per row (post cells are rock), each of the southmost three rows of the spur is at most half as wide as its widest row. The post block keeps rock on all four sides. Today: 11, 10 and 8 against 11.
- **Driftwood groups.** Two driftwood are linked when they are within 2 tiles (Chebyshev). Every linked group holds 1–3 pieces, and no row or column holds more than 3. Today one row holds 6, 5–6 cells apart.
- **Scrub clumps.** Every 8-connected clump of scrub holds at least 4 cells and a 2×2 block of scrub. The cay holds 25–45 scrub cells, so cover stays about what it is (29 today). Today every scrub cell is alone.
- **Nothing on an outer corner.** A cell's corner is land when the four cells that share it are land (art-pass "Land edges"). Every pick-up, palm and sign stands on a cell with at least two land corners. A cell with one is an outer corner: with art-coast-pass's arcs, most of it draws as water, and a pick-up there sits half on the sea (PR5).

### D2. Cells that do not move
The landing (10, 42), (12, 42), (10, 44), (12, 44); the raft site (19, 45) (`test_structure_art.gd` pins its pixel); the workbench (16, 39) and every cell within 2 tiles of it, so its smoke rule holds; the dry grass; the post block (rows 38–40, columns 63–67) and the nails, mirror and signs on it; the rope cache (q, l) and the crossed-stick sign; the aloe; the lagoon's brackish cells, its shallows ring and the drinking spot (22, 21); the five palms, unless the outer-corner rule moves one by a cell. Driftwood, scrub, the flotsam line and plain beach, dune and rock cells may move.

### D3. A bight, not a flat
- The bay's north shore curves north in its middle and rounds into each arm with a shoulder of 2–4 cells, so the bay's three straight sides become one curve.
- The curve takes land from the middle of the north band, and the shoulders give some back at the arms' roots. The north band stays at most 12 cells deep, so the 6-tile rule holds.
- The bay stays shallows everywhere it is today and wherever land is removed. No deep water is added, so the walks over land and shallows only get shorter.

### D4. A rock point that narrows
- The spur keeps its full width round the post (rows 37–41, columns 62–68) and tapers below it to its tip, about 9, 7, 5, 4 and 3 cells wide.
- The east face and the seam with the beach take 1–2 cell jogs, so neither runs straight for more than 10 cells. At least one rock cell stays on the coast (`test_terrain_view.gd` "Rock on the coast cay takes the plain tiles").
- Land lost at the tip is paid back by lengthening, not widening: the arms' ends, a short spit, or the shoulders of D3. The target is 1,010–1,080 land cells, clear of both ends of the band.

### D5. Jogs on the long coasts
The west coast, the outer north coast, the west arm's bay shore and the rock's east face step in or out by 1–2 cells every 4–8 cells. Jogs keep clear of the landing cells and of the bench's smoke margin: no water comes within 2 tiles of a land cell within 2 tiles of (16, 39). The shallows ring follows the land at the same width (Q4 (a)).

### D6. Driftwood, scrub and flotsam
- **Driftwood:** the 8 pieces in about four groups of 1–3 on the north beach and the west arm, on more than one row. A lone arrival can still reach 6 (the solo raft test).
- **Scrub:** 6–8 clumps of 4–6 cells, each with a 2×2 core, in the dune band and on the west arm's dune. At least one clump lies within a short walk of the landing and the bench, so a lone arrival keeps cover near camp. No scrub on the bench's cells, the landing, the post or a pick-up.
- **Flotsam:** the line stays on the west arm's bay shore (its walk band is 2–7 s), on straight-edge cells (two land corners), not on the tips of jogs.

### D7. Authoring
- A one-off helper, kept in the build session's scratchpad and not tracked, loads the rows, rounds the land mask with a few cellular-automaton passes with the D2 cells pinned, prints every D1 measure and the band checks for a candidate, and writes candidate rows. The author then places the jogs, the groups and the clumps by hand.
- Only the `.tres` is tracked. The tests in tasks.md are the check; the helper's settings and the final measures go in "Build notes".
- *Rejected:* tracking the helper, which would need its own tests for a one-off; rolling the outline from a seed, which would make the cay generated.

### D8. Re-pins, and when to stop
- **Re-pinned with a reason** (the shape moved, not the rule): `test_coast_cay_bench.gd` `LAND_CELLS`; `test_terrain_art.gd` `test_layer_cell_counts_of_the_two_islands` for the coast cay; `test_shoreline.gd`'s 265; `test_patrol_loop.gd`'s perimeter; `test_patrol_triggers.gd`'s farthest land and land beyond 2, 3 and 6 tiles. Whichever of this change and art-terrain-polish lands second re-pins the layer counts (C9 moves the cay's Dune count from 393 to 397 today).
- **Not re-pinned:** `test_patrol_coverage.gd`. If the cay's spotted share leaves 34% ± 3 points, its raft site stops being lit, or the bench or a cell round it is lit in the lap, that is a balance change: the build stops and the question goes to the coordinating session with the measures.
- The open guardacostas-stealth change's design table (1,021 land, 61% lit, 34% spotted) is a record of what was measured then, and is not edited.

## Reference games

Ideas and structure only, never code, data or text. The three roguelikes were read in `C:/Users/liann/src/90miles/reference/` on 2026-11-15.

**Brogue CE**
- *Borrowed:* `createBlobOnGrid` (src/brogue/Grid.c, line 417) grows a random fill and smooths it with rounds of `cellularAutomataRound` (Grid.c, line 362), a birth and survival rule on each cell's eight neighbours. D7's helper rounds the cay's land mask the same way, with the fixed cells pinned, before the hand jogs.
- *Rejected:* letting the blob decide the island. The cay is handmade; the automaton only suggests a smoother outline.

**Shattered Pixel Dungeon**
- *Borrowed:* `Patch.generate` (levels/Patch.java, line 42) fills a grid to a rate and then clusters it, and `RegularPainter.paintGrass` and `paintWater` (levels/painters/RegularPainter.java, lines 388 and 366) use it, so grass and water come in clumps, never on a lattice. D6's scrub clumps follow the idea, placed by hand.

**DCSS**
- *Borrowed:* `_shoals_plant_cluster` and `_shoals_plant_supercluster` (crawl-ref/source/dgn-shoals.cc) put the Shoals' plants in small clusters round a point, and clusters of clusters. Driftwood in groups of 1–3 and scrub in clumps follow it.
- *Noted:* `_shoals_smooth_water` (dgn-shoals.cc, line 196) smooths the water's heights. Wave 1's soft deep edge (C4) already borrows the smoothing for the art; this change does not touch depth.

**Don't Starve Together** (`docs/REFERENCE_DST.md`, island-generation)
- *Kept as an invariant:* "Shipwrecked's world of islands" (wiki: [Ocean](https://dontstarve.wiki.gg/wiki/Ocean), [Set Pieces](https://dontstarve.wiki.gg/wiki/Set_Pieces)): every island has a ring of shallow water and deep water never touches land. The reshaped cay keeps its ring at the same width (Q4 (a)).
- *Rejected:* "Handmade versus random, overall" ([World Generation](https://dontstarve.wiki.gg/wiki/World_Generation)): DST authors the rules and rolls the layout. The cay stays fully handmade, which our notes already prefer for the first islands.
- "Set pieces" does not apply: no set piece moves. Nothing in `docs/REFERENCE_DST.md` describes how DST shapes a coastline, so nothing is borrowed for the outline itself.

**ALttP and Pokémon** (general knowledge of how they look; nothing copied)
- *Borrowed:* coasts bend and step at irregular intervals, and no beach runs straight across a screen.

## Owner decisions

- **Q5 (a), accepted 2026-11-14:** reshape the coast cay's rectangles after coast-cay-bench merges (#58 merged).
- **Q4 (a), accepted 2026-11-14:** the deep edge is art only, so the shallows ring keeps its width here.
- **New, S1 (sent to the coordinating session):** the sandbar has four 2-cell notches at the tips of its inner bay, (45, 20), (46, 20), (45, 51) and (46, 51), all shallows today. Q5 covered only the cay, and the sandbar's shape was approved twice.
  - (a) *Recommended:* fill the four cells as beach. Land goes 991 → 995 and the Sand layer 994 → 998, inside the sandbar's 940–1,100 band. It ships as task group 5, only on the owner's yes.
  - (b) Leave the sandbar as approved.
  - Not offered: tapering the horn tips or varying its shallows ring.

## Risks / Trade-offs

- **[Hiding spots move]** Scrub moves into clumps. → 25–45 scrub cells (29 today), and a clump near the landing and the bench.
- **[The patrol's lap changes]** The hull and its length change. → D8: the spotted share, the lit raft site and the dark bench are kept or the build stops and asks.
- **[Walk bands near their edges]** The post is 14 s away in a 13–19 s band. → The bight only shortens walks over shallows; `test_a_lone_arrivals_walks` runs on every candidate.
- **[Land near its lower bound]** The rock taper costs about 20 cells. → A 1,010–1,080 target, paid back by lengthening (D4).
- **[Two changes pin the same counts]** art-terrain-polish's C9 and this change both move `test_layer_cell_counts_of_the_two_islands`. → The second to land re-pins it, with both reasons.
- **[Clients]** Every peer loads the same `.tres`, and no message changes. → `test_coast_cay_net.gd`, `test_coast_cay_bench_net.gd` and `test_arrival_scatter_net.gd` stay green.

## Migration Plan

Data only. To roll back, revert the commit: runs are not saved, and no network message carries the shape.

## Build notes

The helper's settings, the final measures, the land count and the re-pinned numbers are recorded here as the tasks ship.
