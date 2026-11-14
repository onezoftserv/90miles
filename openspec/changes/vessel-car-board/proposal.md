# Proposal

## Why

`balsero-lore` (docs and specs only) adds two rolled crossings: the *almendrón flotante*, a 1950s car on four drums, and *la tabla*, one rigged surfboard per rider. Its task group 6 is the code those two need before content-batch-11 can write their route files. The crossing today has exactly one vessel shared by every rider, and arrival lands everyone on the landing cells. The board breaks both assumptions. Nothing else in content-batch-11 can land without the two enum values this change appends.

## What Changes

- **Data.** Append `DataEnums.Vessel.CAR` and `Vessel.BOARD` after `DOLPHIN_POD`. Add `RouteData.arrival_scatter_tiles: Vector2i`, default `(0, 5)`. The car needs no new field: integrity 160 and squall ×1.5 already fit `vessel_integrity` and `squall_damage_multiplier`.
- **Per-rider boards in the crossing.** A `BOARD` route gives each rider their own board, at the route's integrity (60), with its own small deck.
  - A squall hits every board and throws every board rider in. Boards have no lashing.
  - A shark pass or a rock hits one board, and a shark throws that board's rider in.
  - A rider climbs back onto their own board by the 3 s hold, with no teammate needed. A teammate's 2 s pull also works.
  - A board at 0 sinks and drops only its own rider, who swims the rest.
  - The crossing result, the resync and the late-join snapshot carry every board.
  - Raft, swimmer and car crossings keep their single-vessel path unchanged.
- **The `SHARK_ATTACK` dump trigger works.** It is declared on `RouteData` but nothing reads it yet. On a route that lists it, a shark hit on a vessel throws in that vessel's untied riders.
- **Arrival.**
  - The host picks each arriving rider's landing cell and sends it with the arrival. A rider whose route scatters wider than the default lands on a beach cell 10–20 tiles from every rider already placed, rolled from the run seed, with a fallback when the beach is too small.
  - A solo rider still lands on the first landing cell.
  - Only a raft result is beached at the raft site, so a board or a car never comes back as a raft. The board is lost on arrival, as its route says.
- **Route items spent at the start.** A route requirement of kind `HAS_ITEM` marked `consume` is taken from the starter, and a rider requirement from each rider, only when the route actually starts. A refused start, such as the board in calm weather, spends nothing. This is how the board's `tabla_vela` and the car's fuel jug are spent.
- **Art.** Both are kitbashed through `tools/art/structures.py` from hand pieces and pack cuts; packs are read-only and no Pillow is used.
  - The car: a 64×32 sheet, whole, worn and breaking, with four drums cut from the Zelda-like objects sheet.
  - One 16×32 board sheet in the same three states.
  - The crossing deck draws the car for `CAR` and one board under each rider for `BOARD`. Damage frames follow the share of the vessel's maximum, so a new board at 60 reads whole.
- **Tests.** GUT tests for every rule above, with 1-player cases. The crossing is networked, so there are host-plus-client tests for boards, the scatter and the late-join snapshot.

**Not in this change.** These are left to the owners named in `design.md`:
- The route files `almendron` and `tabla` and the key `llave_almendron`, which belong to content-batch-11 per `docs/CONTENT_MANIFEST.md` and `TASKS.md`.
- The almendrón's solo build test, which needs that batch's recipe and items.
- The `almendron_hundido` capture gate, which needs capture at sea, chain route rows and `FLAG_SET`, none of which exist yet.
- The route's start effects (noise, flag, botija).
- Beaching the car at its own site on the next island.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `crossing`: adds "Per-rider boards", "Board hits", "Shark dumps", "Board rescue", "Board crossing state", "Vessel look on the crossing", "Arrival scatter", "Arrival scatter fallback" and "Beaching by vessel". `balsero-lore` is unarchived and modifies "Crossing scene", "Vessel integrity" and "Arrival", so this change only adds requirements and modifies none.
- `escape-routes`: adds "Route items spent at the start". `balsero-lore`'s modified "Weather gating" stays its own.

## Impact

- **Code:**
  - Data: `data_enums.gd`, `route_data.gd`.
  - Crossing: `crossing.gd`, `crossing_deck.gd`, a new `crossing_boards.gd`, `crossing_result.gd`, `crossing_snapshot.gd`, `creature_threats.gd`, `scripted_threats.gd`.
  - Routes and arrival: `island_routes.gd` (consume at the start), `island_travel.gd` and `island_arrival.gd` (scatter, raft-only beaching), and the arrival check in `coop_session.gd` (one optional `cell` field).
  - Art: `structure_art.gd` and `structure_art_data.gd`.
  - Docs: the `companion_data.gd` doc comment, since `can_swim` false rules out the board.
- **Art:** `tools/art/structure_sheets.json` and new hand pieces in `tools/art/fixes/structures/`. New sheets `game/assets/art/structures/car.png` and `board.png` with their frames, `structure_art.tres` and the license and credits rows.
- **Tests:** new `game/tests/unit/test_crossing_board*.gd`, `test_crossing_car.gd`, `test_arrival_scatter*.gd` and `test_route_consume.gd`. Fixture routes live in `game/tests/fixtures/routes/` (not in the catalog folder) and are put in the catalog's cache by the tests.
- **Siblings:**
  - `dropped-teammate-state` edits `checked_arrivals` (its cap) and `IslandTravel.check()`. This change touches other lines of `checked_arrivals` and `travel()`/`_land()`, and rebases if it lands first.
  - `secret-cay` touches `crossing_stub.gd` and islands, not the crossing scene.
- **Docs:** tick `balsero-lore` group 6 with the deferred items moved to their owners, and update `TASKS.md`.
