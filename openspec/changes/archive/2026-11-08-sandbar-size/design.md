# Design

## Shape

An open crescent opening east: an annulus of mid radius 20.6 and band about 10, kept where the angle from east is more than 55° (250° of arc), with round caps at the two horns. The arc along the middle is 20.6 × 250° ≈ 90 tiles (22 s at 4 tiles/s; the shortest walk from the solo spawn to the farthest land is about 72 tiles, 18 s). Beach fills the inside, a dune spine (about a third of the land) the outer side, sea grapes dot the outer edge. Shallows are cells within 1.9 tiles of land; the rest is deep.

The grid is 80×72 = 5,760 cells. It cannot be much smaller: land at 10–20% of the cells and about 1,000 land tiles need 5,000–10,000 cells, and the crescent itself spans only about 41 wide and 51 tall, so it is taller than wide and sits in a wide margin of open sea. The camera (`game_shell.gd`) already clamps to `island.bounds` = `built.size * TILE`, so the bounds are 1,280×1,152 px against a 640×360 view and no code changes.

Numbers (from the rows in `sandbar.tres`): 991 land cells (17.2%), 276 shallows, 3 tide-pool cells, 4,490 deep; sand 533, dune 335, sea grapes 84, the rest object glyphs. The farthest land cell from water is 5.7 tiles, so "no land cell more than 6 tiles from water" holds with the band at 10 (a band of 10.3 reaches exactly 6.0).

## Spawns and POIs

Spawns sit on the mid-line at 276°, 205°, 135° and 66° (angle from east, y down): 23.3 tiles from each other in join order, 38–40 tiles between 1 and 3, 2 and 4, and 1 and 4. The solo spawn is 2 tiles from the hut, below it. Chord length 2R sin(Δ/2) fixes it: a Δ of 70° is 23.6 tiles. A crescent has no four points whose six distances are all 20–30, so the owner chose the chain rule.

Palms are on the mid-arc at 163–200° (28–40 tiles from the solo spawn, at least 26 from the hut), the tide pools on the south horn (60–64 tiles from the solo spawn, 3–5 tiles apart), the flotsam on the inside curve and the raft site on the inside beach at 202°, 3.6 tiles from the nearest flotsam pick-up (a jug).

## Solo

Everything the solo spawn needs is a walk of seconds (see the proposal). `test_a_solo_player_walks_the_crescent` builds an `AStarGrid2D` in the test over land and shallows and converts path length to seconds with `MovementModel.WALK_SPEED`. Nothing needs a second player.

## Reference games (ideas only; nothing copied or translated)

- **Brogue CE, `Rogue.h` and `Architect.c`:** `DCOLS` × `DROWS` is 79 × 29 = 2,291 cells (`COLS` 100 minus `STAT_BAR_WIDTH` 20 minus 1; `ROWS` 31 + `MESSAGE_LINES` 3 minus 3 minus 2). Levels are accreted from rooms and caves (`designCavern`, `designRandomRoom`, `attachRooms`). The share of standable floor was not measured here, so none is claimed. Crossing the width is about 79 turns; at an assumed 0.2 s per held-key step that is about 16 s (an estimate).
- **DCSS, `defines.h` and `dgn-shoals.cc`:** the map is `GXM` × `GYM` = 80 × 70 = 5,600 cells, almost the same as our grid. The Shoals branch (`_shoals_margin` = 6, `shoals_height_thresholds` for floor, shallow and deep) makes land the minority in water inside a dry margin. Crossing 80 columns is about 80 turns, about 16 s at 0.2 s per turn (estimate).
- **Shattered Pixel Dungeon, `RegularPainter.paint`:** the level is sized from its rooms: `setSize(rightMost + 1, bottomMost + 1)` after the rooms' bounding box plus `padding` (1, or 2 on a chasm level). So there is no fixed size and no crossing time was measured; none is quoted.
- **Borrowed:** DCSS Shoals' idea of island levels that are mostly water with land as shaped blobs and a margin to the edge (our deep border and the 10–20% land share), and the habit of measuring a level in cells you can stand on (we pin the land count, not just the grid).
- **Rejected:** SPD's size-from-rooms (one handmade island, no rooms); Brogue and DCSS turn-based pacing as a yardstick: our real-time walk covers 4 tiles/s, so the 90-tile arc (22 s) is somewhat longer than a roguelike crossing (about 16 s, estimated). That fits: the island is a base for 3 in-game days, not a level cleared once, and 17% land keeps it barely an island.

## Provisional

Listed in the proposal. The walk bands are set from the built map (the test uses Godot's A*; the scratch numbers came from an 8-way Dijkstra, which agrees within a tile or two).
