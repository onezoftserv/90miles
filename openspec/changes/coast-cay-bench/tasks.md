# Tasks

## 1. Tests first

- [ ] 1.1 In a new `game/tests/unit/test_coast_cay_bench.gd`, write the layout checks, offline, with no scene:
  - one bench on an unshaded beach cell that holds nothing else;
  - the post still the only shade, and land still 1,021;
  - every land cell within 2 tiles of the bench more than 2 tiles from the sea, with the sea flood-filled from the map edge;
  - the bench reachable from every landing cell, and 1–4 s from the first by the layout test's A* walk.
- [ ] 1.2 In the same file, write the 1-player run, offline, through the shell:
  - travel to the coast cay;
  - take the lighter and 3 driftwood with real pick-ups, and carry 1 dry grass as if from the sandbar;
  - place a fire site with `craft_for` at the session's bench, and deposit with `deposit_for`;
  - check: no fire at 0.9 s, one lit fire at 1 s within 2 tiles of the bench, and the lighter at 19 uses.
- [ ] 1.3 In a new `game/tests/unit/test_coast_cay_bench_net.gd`, write the host-plus-client check over ENet (NetHarness). Both peers build the real sandbar with an `IslandTravel`, and the host travels to the coast cay. Check:
  - the client's bench stands where the host's does, on the layout's cell;
  - the client's own request places a fire site at the bench;
  - once the host completes the work, the client's copy of the fire is lit where the host's is.
- [ ] 1.4 Add the bench to the reach goals in `test_coast_cay_layout.gd`. Run the new tests and see them fail for the missing bench.

## 2. The bench

- [ ] 2.1 In `game/resources/islands/coast_cay.tres`:
  - set (16, 39) to `W`;
  - map `"W": 3` (beach) in `terrain_glyphs`;
  - set `workbench_glyph = "W"`;
  - leave `shade_glyphs` alone.
- [ ] 2.2 Update `docs/ISLANDS.md` §2: one workbench with its walk in "Size", and a flat-rock row in the POI table. Update `TASKS.md`.
- [ ] 2.3 Leave a note for the guardacostas-stealth build in the shared notes folder: pin the bench neighbourhood as dark in its lap test.

## 3. Verify

- [ ] 3.1 Run `openspec validate coast-cay-bench --strict`.
- [ ] 3.2 Run the import twice (the second clean), the smoke run and GUT. Explain any pinned expectation that moved (design D3) here.
