# Design

## Context

- A workbench is level furniture. `IslandLayoutData.workbench_glyph` names it. `IslandLayout._read_cell` records the cell in `built.workbench`, and `SandbarIsland.furnish` adds one `Workbench` to the session on every peer, at the path `HutWorkbench`, when the layout has one (`game/scenes/levels/sandbar_island.gd`, `BENCH_NAME`). `IslandTravel._clear_level` frees it when the party moves on.
- The sandbar's bench is its `W` glyph, a hut cell on BEACH, in `shade_glyphs` because it is inside the hut. The coast cay layout has no `workbench_glyph` and no `W`.
- A fire site is placed at the bench (crafting-inventory "Placing a build site"). The player must be within `PlayerBody.HOLD_REACH_PX` (18 px) of the bench, so they stand in its 3×3. The host then puts the site on the player's own cell, or on the free cell nearest them within 1 tile. A placed fire can therefore land up to 2 tiles from the bench.
- The fire recipe is 3 driftwood plus 1 item tagged TINDER. The lighter (fire-lighting tool) cuts the work from 30 s to 1 s. On the coast cay the cache holds the lighter and the beach holds 8 driftwood. `dry_grass` is the only TINDER item, and before this change it lay only on the sandbar.
- `guardacostas-stealth` (docs merged in #50, build in progress) runs a patrol boat round each island's hull, pushed 4 tiles out. Its searchlight lights about 60% of the coast cay's land in one lap. Its smoke rule sees a lit fire within 2 tiles of the sea at night, and within 6 tiles by day, where the sea is deep or shallow water joined to the map edge.

## Goals / Non-Goals

**Goals:**
- One workbench on the coast cay, placed by data, near the landing, on walkable land in the lee, off every path and pick-up, and outside the searchlight's coverage.
- Tinder on the cay itself, so a player who lands with nothing can light a fire there (owner, 2026-11-14).
- A solo player can light a fire there. In co-op the bench and the fire show on every peer.

**Non-Goals:**
- Renaming the session node `HutWorkbench` (a code constant the tests use). The coast cay's bench uses the same name.
- Bench art beyond the existing one-frame workbench look, a second bench, a stone-ring fire, or refuelling.
- New tinder items, regrowing grass or a grass-cutting tool.

## Decisions

### D1. Data only: a `W` glyph on a beach cell

`coast_cay.tres` changes in three places:
- one row cell becomes `W`;
- the legend maps `"W": 3` (BEACH, the terrain the cell already had);
- `workbench_glyph = "W"`.

`W` is not added to `shade_glyphs`, so the observation post stays the only shade. The terrain does not change, so the land count (1,021), the hull, the patrol loop (195 tiles) and the stealth change's simulated shares stay as they are. No script changes: the reader and `furnish` already handle any layout's bench. This follows the project rule that moving or adding a point of interest is a data change (island-generation "Coast cay landing").

### D2. The cell: (16, 39), on the bay side of the west arm

The west arm is the lee arm: the trade wind comes from the east, the windward rocky point holds the observation post, and the stealth notes' windward pass lies along that rock. The landing cells are (10, 42), (12, 42), (10, 44) and (12, 44). The bench sits at column 16, row 39, on beach.

How it was chosen: `guardacostas-stealth` design decisions 3 to 5 were re-run per cell in a throwaway script. The run used:
- the monotone-chain hull of the land cell centres;
- each edge offset 4 tiles and mitred;
- a lap starting at the most easterly point and running south first, 100 s at 0.1 s steps;
- the beam aimed at the land centroid with a ±60° triangle wave at 30°/s;
- a 60° cone with a 10-tile range;
- the meter filling at 1/s, draining at 0.5/s and spotting at 2 s.

It reproduces the design's table exactly: 621 of 1,021 land cells lit (61%) and 350 spotted (34%) on the coast cay, and 680 and 452 on the sandbar. Candidate cells were then filtered:
- beach, dune or scrub, not on a palm, pick-up, sign, spawn, drink spot or raft site;
- the cell and its 8 neighbours lit 0 s in the lap;
- the cell and its 8 neighbours more than 2 tiles from the sea, so no fire placed from there raises a night smoke alert;
- at least 2 free land neighbours, so a fire site and a rain-catcher site fit at once;
- the fewest walking steps from the first landing cell.

The best is (16, 39):

| Measure | Value |
| --- | --- |
| Walk from landing cell 1 (4-neighbour steps over land and shallows) | 9 steps, about 2.3 s at 4 tiles/s |
| Light on the bench cell and its 8 neighbours in one lap | 0 s |
| Nearest lit cell | (14, 39), 2 tiles west, which faces the open sea |
| Lit cells within 2 tiles | 6, all on the west or south-west side: (14, 37–41) and (15, 41) |
| Nearest sea | the bay, 5 tiles east |
| Every cell within 2 tiles more than 2 tiles from the sea | yes, so a night fire anywhere a bench fire can land raises no smoke alert |
| Day smoke | within 6 tiles of the sea, so a day fire is seen, as almost every day fire on this island is (stealth notes: every day fire on both islands is within 6 tiles of the sea) |
| Free land neighbours | 8 |
| Nearest other features | the palm at (18, 40), and the dry grass at (15, 37) and (17, 37) (D4), each 2.2 tiles |

Alternatives:
- **The middle of the north arm (row 22).** It is the only stretch where every cell within 2 tiles is dark, but it is 32 or more steps (8 s or more) from the landing. Rejected: the bench should be by the landing.
- **Beside the landing cells.** That beach is lit and mostly spotted in the lap, so a party camped at the bench would be seen every lap. Rejected.
- **The observation post.** It is windward rock on the beam's line and mostly spotted. Its cells are the island's only shade and a hiding spot, and a bench there would crowd the nails, the mirror and three signs. Rejected.
- **(17, 39) or (17, 40), a step closer to the bay.** They are just as dark, but some cells 2 tiles east are only 2 tiles from the bay, so a displaced night fire would be seen. (17, 40) also touches the palm. Rejected for (16, 39).

Brogue's `MF_NOT_IN_HALLWAY` asks whether a feature cell is a chokepoint. Here the arm is 12 cells wide at row 39, so one bench cell is no chokepoint. A `Workbench` has no collision either: it is a `Node2D` with an `Interactable` and a look, and movement reads only terrain. The bench can therefore never cut a path. The layout test adds it to the reach goals from every landing cell anyway.

### D3. What already reads `built.workbench`

These pieces of code read the bench cell, and they now apply on the coast cay, with no edit:
- **`ArrivalScatter.beach_cells`:** a wide arrival (boards) never lands a rider on the bench's cell.
- **Secret-cay `IslandLayout.hiding_spots` and `spot_kind`:** they measure from the bench as a feature (`SecretTuning.spot_feature_kinds` lists `workbench`) and never hide a piece on its cell.
- **`TerrainView`:** it draws a foot shade under it.

Full GUT is the check that no pinned expectation moved. Any that did is listed in tasks.md with the reason.

### D4. Two dry grass on the dune beside the bench

The owner chose "Bench + 2 dry grass (Recommended)" on 2026-11-14. The grass uses a new glyph, `h` (*hierba*): `y` is the cay's aloe and stays so. `"h": 4` (DUNE) is in the legend, and one pick-up entry gives `dry_grass`, count 1, group `dune`, no respawn, as the sandbar's three do. The grass lies on (15, 37) and (17, 37), which were already dune, so the land count and the hull stay as they are. Both cells are dark in the lap re-run, and both lie 2 tiles north of the bench, outside its 8 neighbours, so they are never the first-choice cell for a site placed at the bench. Pick-ups are not taken spots for site placement (`CoopSession._taken_spots` counts only sites and structures). A site displaced 2 tiles out could therefore share a grass cell, and the grass would stay there to be picked up.

The option's first wording said "on the north dune near the bench". It was written before the bench's cell was chosen. The cache's north dune (rows 15–19) is about 10 s from the bench, while the west arm's own dune runs up to row 38, just north of the bench. "Near the bench" therefore wins, and the grass sits on that dune. Two, not the sandbar's three: one fire and one spare. The cay's fire also needs 3 of its 8 driftwood, and the raft needs 6. That is 9 driftwood for a fire and a raft, so a player who wants both has to wait for a squall's refresh or bring wood. That is a fair trade, logged as a risk.

### D5. Tests

- **`test_coast_cay_bench.gd`, 1 player, offline:**
  - layout checks: the bench cell, its terrain, no shade, no overlap, reach from every landing cell, the 1–4 s walk, the smoke margin;
  - a shell solo run that travels to the coast cay;
  - the player lands carrying nothing and takes the lighter from the cache, 3 driftwood from the beach and 1 dry grass from beside the bench, all with real pick-ups;
  - they place a fire site through `CoopSession.craft_for` at the session's bench and deposit through `deposit_for`;
  - they work it: no fire at 0.9 s, a lit fire at 1 s, and the lighter at 19 uses.
- **`test_coast_cay_bench_net.gd`, host and client over ENet (NetHarness):**
  - both peers build the real sandbar with an `IslandTravel`, and the host travels to the coast cay;
  - the client follows, and its bench is at the host's bench position, on the layout's cell;
  - the client's player, by its own request, places a fire site at the bench and is given the inputs on the host;
  - the host completes the work, and the client's copy of the fire is lit, at the host's position.
  - A hand-made bench on a featureless beach would pass without this change, so the test uses the real layout.

## Reference games

### Don't Starve Together (dontstarve.wiki.gg, read 2026-11-14; `docs/REFERENCE_DST.md` "crafting-inventory and inventory-hud")

- **Campfire/DST.** Rejected: DST's campfire needs no station or prototype. It is made from logs and grass wherever the player stands, and players build them at temporary camps far from base. The fetch covered only the page's first 100k characters, so "no placement limit" is as far as that part reads. We keep fire sites bench-placed (owner, inventory-hud, 2026-11-08), so an island where fire should be possible needs a bench. That is this change.
- **Science Machine/DST.** Rejected: in DST the player builds the station anywhere. The wiki says only that the player stands "near" it, and gives no range. REFERENCE_DST already advises level-placed benches, because islands are left behind. This change places one by level data.
- **Spawn Biome.** Borrowed: players start where basic resources are a short walk away. The bench is 2 s from the landing, as the cay's raft site is 3 s.
- **Grass Tuft.** Borrowed in part: DST's tinder (cut grass) grows in large clusters in most biomes and regrows in about three days, so a fire is possible wherever players camp. The cay gets its own tinder (D4). Regrowth is rejected for now: islands stay mostly finite, as REFERENCE_DST's "Resource regrowth" advises.

### Shattered Pixel Dungeon (`reference/shattered-pixel-dungeon`)

- **Borrowed: a guaranteed station per stage.** `levels/rooms/special/SpecialRoom.java` `initForFloor` adds a `LaboratoryRoom` when `Dungeon.labRoomNeeded()` says a chapter needs one. The cay's bench is the same guarantee per island.
- **Borrowed: the station off the line of entry.** `LaboratoryRoom.paint` puts the alchemy pot in a corner on the far side from the room's entrance, so it is never in the doorway's walking line. The bench sits beside the landing's walking band, on the bay side of the arm, not on the landing cells.

### Brogue CE (`reference/BrogueCE`)

- **Borrowed, as a check: a feature never cuts the map.** In `src/brogue/Architect.c`, `cellIsFeatureCandidate` refuses an `MF_NOT_IN_HALLWAY` feature on a chokepoint (`passableArcCount(x, y) > 1`). `buildAMachine` refuses a blocking feature when `levelIsDisconnectedWithBlockingMap` says it would split the level. Our bench does not block and the arm is wide, and the reach test keeps the rule.
- **Borrowed in spirit: `MF_NEAR_ORIGIN`** (`src/brogue/Rogue.h`). A feature spawns in the quarter of cells nearest its machine's origin. Our origin is the landing.

### DCSS (`reference/crawl`)

- **Borrowed: connectivity as the gate.** `crawl-ref/source/dungeon.cc` counts disconnected zones (`dgn_count_disconnected_zones`), and `_valid_dungeon_level` checks that the first level is stair-connected. A layout is refused when a feature cuts it off. Ours is the reach test from every landing cell.
- **Rejected: a station list drawn at random.** The Temple fills its altars from `_setup_temple_altars` and `_pick_temple_altar`. A handmade island's one bench is fixed, not rolled.

## Risks / Trade-offs

- **[A displaced fire 2 tiles west of the bench can be lit by the beam.]** It happens only when the player's own cell is taken and the nearest free one is on the west side. Five of the six lit cells within 2 tiles are on column 14. → The cell under the player is the first choice, and every cell within 1 tile is dark, so a player who stands on or east of the bench gets a dark fire. A night fire anywhere there raises no smoke alert.
- **[The patrol is not built yet.]** The coverage numbers come from the stealth design's own algorithm, re-run, and they reproduce its table exactly. → A note for the guardacostas-stealth build is in the shared notes folder: pin "the coast cay bench and its 8 neighbours are never lit in one lap" when the lap simulation exists.
- **[Pinned expectations in secret-cay or arrival-scatter tests may move]** (D3). → Full GUT. Any change is explained in tasks.md, never edited away silently.
- **[A fire and a raft need 9 driftwood, and the cay holds 8.]** → The cay's driftwood returns after a squall, and a player can carry wood from the sandbar. Raft first is still possible with 2 to spare. Retune at the playtest if it bites.

## Open Questions

None. The tinder question was answered by the owner on 2026-11-14 (D4).
