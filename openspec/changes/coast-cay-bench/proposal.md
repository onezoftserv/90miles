# Proposal

## Why

Since inventory-hud (#35), a fire site or a rain-catcher site can only be placed from a workbench's crafting list (crafting-inventory "Placing a build site", "Workbench"). The coast cay has no workbench (`docs/ISLANDS.md` §2: "no workbench"). Its lighter therefore has no use there. No fire can be lit on island 2, and the land crab's hint, "Enciende una candela y deja la comida a su luz", cannot be followed. The island-generator re-check (2026-11-14) logged this as a follow-up. On 2026-11-14 the owner chose "Add a bench there (Recommended)", data only.

## What Changes

- The coast cay layout (`game/resources/islands/coast_cay.tres`) gets one workbench, a flat rock on the beach. It sits on the bay side of the west arm, the lee arm, 9 steps (about 2 s) north-east of the first landing cell. It is the layout's `workbench_glyph` on a beach cell, so the island's terrain, land count, hull and patrol loop do not change.
- The cell is outside the patrol searchlight's coverage. In one lap, the beam never lights the bench cell or any of the 8 cells round it. Every cell where a fire placed at the bench can land is more than 2 tiles from the sea, so a night fire there raises no smoke alert. A day fire is still seen, as almost every day fire on this island is (`guardacostas-stealth`).
- The cay also gets 2 dry grass, its own tinder, on the dune 2 tiles north of the bench (owner, 2026-11-14: "Bench + 2 dry grass (Recommended)"). Until now dry grass, the only item tagged TINDER, lay only on the sandbar; the cay's `y` pick-up is aloe. A player who landed with no tinder carried over could not light a fire.
- A solo player who lands on the cay carrying nothing can take the lighter from the rope cache, 3 driftwood from the beach and dry grass from beside the bench, then place a fire site at the bench and light it in 1 s.
- In co-op, every peer has the bench at the same place, and a fire built there reaches every client, lit.
- The docs follow: `docs/ISLANDS.md` §2 says the cay has a workbench and 2 dry grass, gives the bench's walk from the landing and lists it among the POIs.

## Owner decision

The tinder question was put to the owner through the coordinating session on 2026-11-14:
- (a) the bench plus 2 dry grass;
- (b) the bench only, with tinder carried from the sandbar.

The owner chose (a). The option's first wording said "on the north dune near the bench", which was written before the bench's cell was chosen. The cache's north dune (rows 15–19) is about 10 s from the bench, so the grass lies on the west arm's dune just north of the bench, which keeps it near the bench.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `island-generation` adds three requirements and modifies "Coast cay contents" (2 dry grass beside the workbench). "Coast cay reach" keeps its text; it already covers every pick-up.
  - "Coast cay workbench": where the bench is, and its reach and walk from the landing.
  - "Coast cay workbench out of the patrol's sight": the smoke and searchlight rules it keeps clear of.
  - "Fire at the coast cay's workbench": a solo fire lit at it, and the bench and its fire on a client.

## Impact

- Data: `game/resources/islands/coast_cay.tres`. The bench is one row cell, one legend entry and `workbench_glyph`. The dry grass is two row cells, one legend entry and one pick-up entry.
- Tests:
  - a new `game/tests/unit/test_coast_cay_bench.gd`: layout checks and the 1-player fire, offline;
  - a new `game/tests/unit/test_coast_cay_bench_net.gd`: host plus client over ENet;
  - in `test_coast_cay_layout.gd`: the bench added to the reach goals, and 2 dry grass added to the cay's counts.
- Docs: `docs/ISLANDS.md` §2 and `TASKS.md`.
- No script, scene, autoload or backend change. `IslandLayout` already reads a workbench glyph, and `SandbarIsland.furnish` already puts that layout's bench in the session on every peer.
- The bench is also an island feature for code that already reads `built.workbench`: wide arrival scatter skips its cell, secret-cay hiding spots measure from it, and the terrain view draws a foot shade under it.
