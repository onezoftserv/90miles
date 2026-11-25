# Tasks

## 1. Tests first

- [x] 1.1 In a new `game/tests/unit/test_coast_cay_bench.gd`, write the layout checks, offline, with no scene:
  - one bench on an unshaded beach cell that holds nothing else;
  - the post still the only shade, and land still 1,021;
  - every land cell within 2 tiles of the bench more than 2 tiles from the sea, with the sea flood-filled from the map edge;
  - the bench reachable from every landing cell, and 1–4 s from the first by the layout test's A* walk.
- [x] 1.2 In the same file, write the 1-player run, offline, through the shell:
  - travel to the coast cay;
  - take the lighter and 3 driftwood with real pick-ups, and carry 1 dry grass as if from the sandbar;
  - place a fire site with `craft_for` at the session's bench, and deposit with `deposit_for`;
  - check: no fire at 0.9 s, one lit fire at 1 s within 2 tiles of the bench, and the lighter at 19 uses.
- [x] 1.3 In a new `game/tests/unit/test_coast_cay_bench_net.gd`, write the host-plus-client check over ENet (NetHarness). Both peers build the real sandbar with an `IslandTravel`, and the host travels to the coast cay. Check:
  - the client's bench stands where the host's does, on the layout's cell;
  - the client's own request places a fire site at the bench;
  - once the host completes the work, the client's copy of the fire is lit where the host's is.
- [x] 1.4 Add the bench to the reach goals in `test_coast_cay_layout.gd`. Run the new tests and see them fail for the missing bench.
  - Done 2026-11-14. Before the data change GUT ran 1,905 tests and 6 failed, all of them new and all for the missing bench:
    - in `test_coast_cay_bench.gd`: the bench is data, the 25 cells round it, the reach and walk, and the solo fire (no bench in the session);
    - the client test (no bench on the coast cay);
    - the reach goals in `test_coast_cay_layout.gd`.
  - `test_the_bench_is_on_the_bay_side_of_the_west_arm` passed before too, because the missing cell (−1, −1) is "west". It stays as a guard on the bench's side once the bench exists.

## 2. The bench

- [x] 2.1 In `game/resources/islands/coast_cay.tres`:
  - set (16, 39) to `W`;
  - map `"W": 3` (beach) in `terrain_glyphs`;
  - set `workbench_glyph = "W"`;
  - leave `shade_glyphs` alone.
- [x] 2.2 Update `docs/ISLANDS.md` §2: one workbench with its walk in "Size", and a flat-rock row in the POI table. Update `TASKS.md`.
- [x] 2.3 Leave a note for the guardacostas-stealth build in the shared notes folder: pin the bench neighbourhood as dark in its lap test.

## 2b. Dry grass beside the bench (owner, 2026-11-14: "Bench + 2 dry grass")

- [x] 2b.1 Tests first:
  - `test_coast_cay_layout.gd` `test_the_coast_cay_loads` expects 2 `dry_grass`, which never respawn;
  - `test_coast_cay_bench.gd` checks the 2 dry grass on dune within 3 tiles of the bench, outside its 8 neighbours;
  - the solo run lands carrying nothing and takes the cay's own dry grass.
  - See them fail.
  - Done 2026-11-14: 3 failed before the data, all for the missing grass: the counts, the grass beside the bench, and the solo fire, which now has no tinder.
- [x] 2b.2 In `coast_cay.tres`:
  - set (15, 37) and (17, 37) to `h`;
  - map `"h": 4` (dune) in `terrain_glyphs`;
  - add a pick-up entry: `h`, `dry_grass`, count 1, group `dune`, no respawn.
- [x] 2b.3 Update the delta: MODIFIED "Coast cay contents", and the solo scenario in "Fire at the coast cay's workbench". Update `docs/ISLANDS.md` §2 (counts and the flat-rock row) and `TASKS.md`.

## 3. Verify

- [x] 3.1 Run `openspec validate coast-cay-bench --strict`.
  - Valid. Before the rebase the CLI also printed a warning that `openspec/config.yaml` `rules.design[1]` reads as a mapping. That warning was not from this change, and #56 fixed it on main.
- [x] 3.2 Run the import twice (the second clean), the smoke run and GUT. Explain any pinned expectation that moved (design D3) here.
  - Done 2026-11-14: second import 0 `ERROR` lines; smoke "10 frames, 0 problem(s)"; GUT 219 scripts, 1905 of 1905.
  - After the rebase on main 9b90289 (bench only): GUT 221 scripts, 1941 of 1941.
  - With the dry grass: second import 0 `ERROR` lines, smoke clean, GUT 221 scripts, 1942 of 1942.
  - No pinned secret-cay or arrival-scatter expectation moved.
  - The log has 11 `ERROR` lines, the same as the run before the change apart from the red run's one A* error from the missing bench. They are three taken ENet ports, the forged RPCs and the content validator's broken fixture, each asserted by its own test.
