# Proposal

## Why

Since inventory-hud (#35), a fire site or a rain-catcher site can only be placed from a workbench's crafting list (crafting-inventory "Placing a build site", "Workbench"). The coast cay has no workbench (`docs/ISLANDS.md` §2: "no workbench"). Its lighter therefore has no use there. No fire can be lit on island 2, and the land crab's hint, "Enciende una candela y deja la comida a su luz", cannot be followed. The island-generator re-check (2026-11-14) logged this as a follow-up. On 2026-11-14 the owner chose "Add a bench there (Recommended)", data only.

## What Changes

- The coast cay layout (`game/resources/islands/coast_cay.tres`) gets one workbench, a flat rock on the beach. It sits on the bay side of the west arm, the lee arm, 9 steps (about 2 s) north-east of the first landing cell. It is the layout's `workbench_glyph` on a beach cell, so the island's terrain, land count, hull and patrol loop do not change.
- The cell is outside the patrol searchlight's coverage. In one lap, the beam never lights the bench cell or any of the 8 cells round it. Every cell where a fire placed at the bench can land is more than 2 tiles from the sea, so a night fire there raises no smoke alert. A day fire is still seen, as almost every day fire on this island is (`guardacostas-stealth`).
- A solo player who lands on the cay, takes the lighter from the rope cache and 3 driftwood from the beach, and carries tinder can place a fire site at the bench and light it in 1 s.
- In co-op, every peer has the bench at the same place, and a fire built there reaches every client, lit.
- The docs follow: `docs/ISLANDS.md` §2 says the cay has a workbench, gives its walk from the landing and lists it among the POIs.

## Open question for the owner

The coast cay ships no tinder. Its `y` pick-up is aloe, and dry grass, the only item tagged TINDER, lies only on the sandbar (3 on the dune). A player keeps their inventory across the crossing, so tinder carried from the sandbar works here. A player who lands with none still cannot light a fire.
- (a) Also put 2 dry grass on the cay's north dune, near the cache's lighter. This is data only, but it changes "Coast cay contents" and the counts in `docs/ISLANDS.md` §2.
- (b) Bench only: tinder comes from the sandbar.

The question was sent to the coordinating session on 2026-11-14. Until it is answered, this change is (b), and the 1-player test carries one dry grass from the sandbar.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `island-generation` adds three requirements. "Coast cay contents" and "Coast cay reach" keep their text.
  - "Coast cay workbench": where the bench is, and its reach and walk from the landing.
  - "Coast cay workbench out of the patrol's sight": the smoke and searchlight rules it keeps clear of.
  - "Fire at the coast cay's workbench": a solo fire lit at it, and the bench and its fire on a client.

## Impact

- Data: `game/resources/islands/coast_cay.tres` (one row cell, one legend entry, `workbench_glyph`).
- Tests: a new `game/tests/unit/test_coast_cay_bench.gd` (layout checks and the 1-player fire, offline), a new `game/tests/unit/test_coast_cay_bench_net.gd` (host plus client over ENet), and the bench added to the reach goals in `test_coast_cay_layout.gd`.
- Docs: `docs/ISLANDS.md` §2 and `TASKS.md`.
- No script, scene, autoload or backend change. `IslandLayout` already reads a workbench glyph, and `SandbarIsland.furnish` already puts that layout's bench in the session on every peer.
- The bench is also an island feature for code that already reads `built.workbench`: wide arrival scatter skips its cell, secret-cay hiding spots measure from it, and the terrain view draws a foot shade under it.
