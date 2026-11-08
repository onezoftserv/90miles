# Proposal

## Why

The sandbar is 339 land tiles, about 1.5 screens, and takes a 9 s walk end to end. The co-op spawns are 10–17 tiles apart, so "find each other first" never happens. The owner approved (2026-11-06) about 3× bigger: around 1,000 land tiles, a crescent about 90 tiles long, a ~25 s walk, the POIs spread out, spawns 20–30 tiles apart, still sparse.

## What Changes

- `game/resources/islands/sandbar.tres` gets new rows: an 80×72 grid with 991 land cells in an open crescent opening east (`docs/ISLANDS.md` §1), a mid-line arc of about 90 tiles, a dune spine with sea grapes on the outer side, 1–2 tiles of shallows round it and deep water to the edge. Only `rows` changes: the legend, the pick-ups and every count stay.
- POIs spread along the arc: the hut on the north horn, the palm grove mid-arc (palms 26+ tiles from the hut), the tide pools on the south horn, the flotsam line on the inside curve and the raft site on the inside beach among the flotsam.
- **Owner's decision (2026-11-06): chain spawn rule.** Each co-op spawn is 20–30 tiles from the next in join order (1→2, 2→3, 3→4); spawns 1 and 4 may be much farther apart. `docs/ISLANDS.md` §1 "Scattered landing" goes from "10–20 tiles apart" to this. The solo spawn stays within 4 tiles of the hut.
- Specs: `island-generation` MODIFIED (Handmade sandbar, Sandbar contents, Scattered landing, The run starts on the sandbar). There is no `escape-routes` delta: its "Raft build site" pins only the marked beach cell, not a position.
- Tests: new and changed GUT tests (grid size, land count, chain spawns in the layout and network tests, palms 20+ tiles from the hut, the raft site in the reachability test and a 1-player walk test).

Out of scope: new POIs or items, la señora's camp, creatures, tides, art, any script.

## Solo

One offline player spawns 2 tiles from the hut and walks to everything: every palm 7–10 s, the raft site about 6 s, the tide pools 15–16 s (`test_a_solo_player_walks_the_crescent`). Every pick-up, palm, pool and the raft site is reachable from the solo spawn and from each co-op spawn. The raft is unchanged: 60 s of work, the same inputs.

## Decided by the owner (2026-11-06)

1. The plan's C-shaped crescent round a lagoon is rejected; keep the open crescent opening east.
2. Spawns: 20–30 tiles from the next one in join order, not every pair.

## Provisional decisions

The owner confirmed these as they stand on 2026-11-08, with the open crescent and the chained spawn rule (each spawn 20–30 tiles from the next in join order).

- 80×72 grid, mid radius 20.6, band about 10, 250° of arc (55° mouth each side of east), 991 land tiles, all cell positions.
- Walk bands in the 1-player test (palms 6–11 s, raft site 4.5–8 s, pools 13–17.5 s, far horn 15 s or more) and the 940–1,100 land band.
- The camera is unchanged (it clamps to the grid): the crescent spans about 41×51 tiles, so there are about 20 tiles of open sea on each side.
