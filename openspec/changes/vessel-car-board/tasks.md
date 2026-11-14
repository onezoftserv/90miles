# Tasks

The tasks follow the owner's answers to design.md Q1–Q4 (2026-11-14: the recommended option on all four).

Every group ends with all of these clean:
- the import (`godot --headless --path game --import`, twice on a fresh checkout);
- the smoke run (`-s res://tests/smoke.gd`);
- GUT (`-s res://addons/gut/gut_cmdln.gd -gexit`);
- a 300-frame run (`--quit-after 300`) with no `ERROR:` line.

Fixture routes live in `game/tests/fixtures/routes/`, outside the catalog folder. A test puts a route into `GameState.content`'s cache by id and removes it in `after_each`. The fixtures:
- `test_board`: vessel `BOARD`, integrity 60, `PER_SWIMMER`, rider requirement `HAS_ITEM tarp consume`, requirement `WEATHER_IS trade_wind`, dumps on squall and shark, scatter (10, 20), not kept on arrival.
- `test_car`: vessel `CAR`, integrity 160, squall ×1.5, requirement `HAS_ITEM plastic_jug consume`.

## 1. Data

- [x] 1.1 Append `CAR` and `BOARD` to `DataEnums.Vessel` after `DOLPHIN_POD`. Add `RouteData.arrival_scatter_tiles: Vector2i = Vector2i(0, 5)` with its doc comment. Add `BOARD` to `CompanionData.can_swim`'s comment. Verify with a GUT test that `Vessel.DOLPHIN_POD`, `CAR` and `BOARD` are 4, 5 and 6, that a new `RouteData` scatters (0, 5), and that `binoculars_swim.tres` and `raft.tres` load unchanged; `test_data_classes.gd` still passes.
- [x] 1.2 Add the two fixture routes and a `FixtureRoutes` test helper that puts them in and takes them out of the catalog cache. Verify that a test can `get_entry(&"routes", &"test_board")` and that the content validator's run over `res://resources/` does not see them.

## 2. Route items spent at the start (escape-routes "Route items spent at the start")

- [x] 2.1 Write `test_route_consume.gd` first, with these cases:
  - solo in calm: the start is refused and the tarp is kept;
  - solo in trade wind: the route starts and the tarp is spent;
  - a party of 3 where two carry a tarp: both carriers ride and each spent their own, and the third stays with nothing spent;
  - a solo starter with 2 jugs on `test_car`: 1 is left;
  - a negated or nested condition spends nothing.

  See it fail.
- [x] 2.2 Add `RouteLauncher.spend(route, starter, riders)` and call it from `IslandRoutes.start_for` on the host after riders are picked and before departure. Verify `test_route_consume.gd`, `test_route_launcher.gd`, `test_escape_routes_solo.gd` and `test_escape_routes_net.gd` pass.

## 3. Shark dumps (crossing "Shark dumps")

- [x] 3.1 Add these tests:
  - a raft route listing only `SQUALL`: a shark hit leaves the rider aboard at 80;
  - a route listing `SHARK_ATTACK`: a shark hit throws untied riders in at −10 energy and leaves a tied rider aboard.

  See them fail. Then change `Crossing.hit_vessel(amount, shark := false)` to apply the trigger. `CreatureThreats` and `ScriptedThreats` pass `shark = true` on their vessel hit and show the shark at the deck centre the hit returns. Verify the new tests and every existing `test_crossing_*` pass.

## 4. Per-rider boards (crossing "Per-rider boards", "Board hits", "Board rescue")

- [x] 4.1 Write `test_crossing_board.gd` first, with in-process riders through `CrossingRig` (the fixture routes load by id from the catalog's cache, so no overload is needed). The cases:
  - solo: one board at 60, no lashing, no shared deck;
  - 3 riders: a squall puts every board at 30 and every rider in the water;
  - solo: a rock and then a shark break the board, and a 3 s hold does not climb;
  - 2 riders: one board breaks and the other rides on;
  - hits go round: rock, then shark, gives 20, 40 and 60;
  - a broken board is skipped;
  - solo dumped by a shark: fell in at energy 70, the board at 40, back aboard after a 3 s hold;
  - releasing at 2 s does not climb;
  - a teammate's 2 s pull onto the swimmer's own board;
  - no pull onto a broken board;
  - a rejoined rider keeps their board.

  See it fail.
- [x] 4.2 Build the boards in `crossing.gd` per design D1 and D2:
  - `boards`, `vessel_of`, `deck_rect_of`;
  - the 1×2 decks 3 tiles apart;
  - per-board break;
  - `hit_every_vessel` for the squall;
  - the round-robin board pick;
  - climb and pull to the rider's own board;
  - the slot move in `_on_player_rebound`.

  Verify `test_crossing_board.gd`, and that `test_crossing_solo.gd`, `test_crossing_rescue.gd`, `test_crossing_squall.gd`, `test_crossing_shark.gd`, `test_crossing_creature_shark.gd`, `test_vessel_integrity.gd`, `test_use_on_crossing.gd` and `test_crossing_prompt.gd` pass unchanged.
- [x] 4.3 Write `test_crossing_car.gd` with `test_car`:
  - 160 − 45 (squall) − 20 (shark) = 95;
  - a plan rolled at `duration_s` (60, 90) never exceeds 90 s;
  - the car's lashing ties a solo rider through a squall.

  Verify it passes.

## 5. Board state on the wire (crossing "Board crossing state")

- [x] 5.1 Write the unit tests first:
  - `test_crossing_board_state.gd` holds a board crossing's snapshot round trip (boards by rider, 0 as broken), refusals (a non-finite value, a key that is not a peer, the key missing) and a non-rider's board dropped;
  - a solo result holds `board` 40 and `board_broken` false after a shark hit.

  See them fail. Then add `board_values` to `receive_state`, the `boards` snapshot key, `apply_snapshot`, client-side board breaks, and the result's per-rider `board` and `board_broken`. Verify those tests pass.
- [x] 5.2 Write `test_crossing_board_net.gd` over `NetHarness` (ENet on localhost):
  - the client shows the host's board at 20 after a rock and its own at 60;
  - the client's climb onto its own board is applied by the host;
  - a third peer joining sees the client's broken board as gone and the client in the water where the host has them.

  Verify it passes. Re-run `test_crossing_net.gd`, `test_crossing_join.gd`, `test_reconnect_crossing.gd` and `test_crossing_shark_net.gd`.

## 6. Arrival (crossing "Arrival scatter", "Arrival scatter fallback", "Beaching by vessel")

- [x] 6.1 Write `test_arrival_scatter.gd` first, a pure test on the coast cay's built layout. The cases:
  - 1 board rider takes the first landing cell;
  - 3 board riders stand pairwise 10–20 tiles apart on reachable beach cells;
  - the same seed gives the same cells and another seed gives other cells;
  - 2 raft riders take the landing cells and a board rider is 10–20 from both;
  - 4 riders on a small fixture beach all land on distinct beach cells by the fallback;
  - default-scatter parties match `IslandArrival.landing_positions` exactly.

  See it fail. Add `game/scripts/levels/arrival_scatter.gd` per design D7 and verify it passes.
- [x] 6.2 Wire it in:
  - `IslandTravel.travel()` groups riders by their result's route scatter and sends `cell` with each arrival;
  - `CoopSession.checked_arrivals` keeps an optional `Vector2i` `cell` and refuses another type;
  - `_land` uses a valid sent cell and otherwise falls back;
  - `_beached_integrity` counts only `RAFT` routes kept on arrival.

  Verify with these tests:
  - a `checked_arrivals` unit test;
  - a solo shell test where a `test_board` crossing ends with the board at 30, the player stands on the coast cay's first landing cell and the raft site is empty;
  - a raft at 70 and a board at 50 in one landing beach the raft at 70;
  - `test_coast_cay_net.gd` and the existing arrival tests pass.
- [x] 6.3 Add a host-plus-client test, `test_arrival_scatter_net.gd`: 2 board riders over ENet land 10–20 tiles apart and on the same cells on both peers. Verify it passes.

## 7. Art (crossing "Vessel look on the crossing")

- [x] 7.1 Draw the hand pieces as master-palette pixel grids, written with `tools/art/png.py` (no Pillow): `car_body`, `car_worn`, `car_breaking`, `board`, `board_worn`, `board_breaking` in `tools/art/fixes/structures/`. There is no maker's badge, grille logo or board logo. Add the `car` (64×32, 3 frames, with four `barrel` cuts from the Zelda-like `Overworld.png`, the recipe's existing barrel, and a propeller) and `board` (16×32, 3 frames) sheets to `tools/art/structure_sheets.json`. Run `python -I tools/art/structures.py --packs C:/Users/liann/src/90miles/game/assets`. Verify:
  - the python art tests pass (`python -I -m unittest discover -s tools/art -p "test_*.py"`; pytest is not installed);
  - `check.py` passes on the new sheets;
  - every existing sheet is byte-identical (`git status` shows only the new files).
- [x] 7.2 Wire the frames:
  - add `car_frames.tres` and `board_frames.tres` (whole, worn, breaking) and `StructureArtData.car` and `board` in `structure_art.tres`;
  - add `StructureArt.vessel_frame(value, nominal)`;
  - `CrossingDeck` draws the car for `CAR`;
  - a new `CrossingBoards` (`Boards` in `crossing.tscn`, z -20) draws one board per intact board;
  - add the license and `CREDITS.md` rows.

  Verify `test_crossing_art.gd` unchanged and the new `test_crossing_vessel_art.gd`, with these cases:
  - the car worn at 95 of 160;
  - a new board whole at 60 of 60;
  - a broken board not drawn;
  - on host and client, the host's board drawn and the client's broken one not;
  - freeing `Boards` changes nothing the crossing does.

## 8. Integration and docs

- [x] 8.1 Run a host and a client locally on UDP port 7785, not 7777, because other sessions share the machine: two Godot processes, with a dev hook that starts `test_board` for both riders (`tests/manual/board_run.gd -- --mode=host` and `--mode=client`). Check that both see their boards, that a squall dumps both, that they climb back and land 10–20 tiles apart, and that no `ERROR:` line appears in either log. Record the run in the PR.
- [x] 8.2 Update the docs:
  - `docs/GAME_DESIGN.md` §8: boards have no lashing; board hits go round; only a raft is beached.
  - `docs/ASSETS.md`: the car and board rows point to the new sheets.
  - `balsero-lore/tasks.md`:
    - tick 6.1–6.5 with notes;
    - move the almendrón build test into 8.3;
    - add a task for the `almendron_hundido` gate to the capture-at-sea work (balsero-lore 9b.1);
    - add to 8.2 that `tabla_vela`'s use sets `spends_use = false` and the routes set `arrival_scatter_tiles` and `vessel_kept_on_arrival`.
  - `TASKS.md`: content-batch-11 notes that group 6 has landed.

  Verify `openspec validate vessel-car-board --type change --strict` and `openspec validate --all` pass.
- [x] 8.3 Final check: the import, smoke run, full GUT and a 300-frame run are all clean, and `git diff --stat main...HEAD` shows only the files this change names. (2026-11-14, rebased on main with dropped-teammate-state: import, smoke and 300 frames clean; GUT 1646 of 1647, the one failure `test_crossing_art.gd`'s "the scrolled sea still covers the crossing's sea", an existing flake that waits physics frames before the sea's `_process` has run; it fails in about half the full runs on this loaded machine, failed before any code here, and passes alone.)

## Workflow follow-up

- Open the PR into `main` and report the link to the coordinating session.
- Archive after merge. content-batch-11 then adds the real `almendron` and `tabla` routes on these enums.
