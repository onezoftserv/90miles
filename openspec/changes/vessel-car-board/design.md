# Design

## Context

See proposal.md for why. What exists on `main`, and shapes the approach:

- **One vessel per crossing.** `Crossing` holds one `VesselIntegrity`, one 4×2-tile deck at the sea's centre and one lashing. Each rider has a climb point and a pull handle. Seven places assume that single vessel:
  - `_on_broke` throws every rider in.
  - `bring_aboard` puts a rider on a deck spot.
  - `_refresh_points` puts a climb point on the deck edge.
  - `receive_plan` and `receive_state` carry one value.
  - `CrossingSnapshot` has `maximum`, `value` and `broken`.
  - `CrossingResult` has `integrity` and `broken`.
  - Swimmers' routes have a vessel of maximum 0, so `has_integrity()` is false.
- **Threats.** `CreatureThreats` (the default) and `ScriptedThreats` call `crossing.hit_vessel(amount)` and `crossing.bite_swimmer(peer)`. Only `_squall` reads `RouteData.dump_triggers`. `SHARK_ATTACK` is declared and unused.
- **Arrival.**
  - `IslandTravel.travel()` sends `travel_to(layout_id, arrivals, raft_integrity)`, where `arrivals` maps peer to `{health, energy}`.
  - `CoopSession.checked_arrivals` keeps only those two keys.
  - Every peer then lands every player on `IslandArrival.landing_positions`, the layout's landing cells in sorted peer order.
  - `_beached_integrity` takes the best unbroken result, whatever its route. A board or car result would come back as a raft.
- **Routes.**
  - `IslandRoutes.start_for` checks `RouteLauncher.can_start` and `RouteLauncher.riders`, then departs. Nothing spends a route requirement.
  - `ConditionData.consume` is read only by `ItemUser` for `HAS_CAPABILITY`.
  - An `ITEM_USE` route starts from an item use whose `START_ROUTE` effect may be refused. That use's `spends_use` spends the item either way, which is why `binoculars` sets it false.
- **Content.**
  - Only two weathers exist, `calm` and `squall`; `trade_wind` is not a file yet. `ConditionCheck` evaluates `WEATHER_IS` by id, so a test can set the climate's id.
  - `FLAG_SET` is "not built yet" in `ConditionCheck`, and no chain `.tres` exists.
  - Capture is not built.
  - The routes `almendron` and `tabla` belong to content-batch-11 (`docs/CONTENT_MANIFEST.md`, `TASKS.md` §10, balsero-lore task 8.2).
- **Art.** `tools/art/structures.py` builds `game/assets/art/structures/*.png` from hand pieces in `tools/art/fixes/structures/` and cuts from packs. The packs are git-ignored and are present read-only in the main checkout under `game/assets/{itch,oga}`. Its recipe already maps the Zelda-like barrel (cut from `Overworld.png` for the rain catcher) to the master palette. `StructureArt.raft_frame` uses absolute thresholds: whole above 66, worn above 33.
- `CompanionData.can_swim` says "false also rules out the SWIMMERS and DOLPHIN_POD vessels". No companion `.tres` exists.

## Goals / Non-Goals

**Goals**
- Raft, swimmers and the island flows behave exactly as today. Every existing crossing, rescue, join, reconnect and arrival test passes unchanged.
- The car is the raft path with other numbers and another sprite.
- The board is per-rider state beside the shared vessel, not a second crossing per rider.
- The host decides everything new: board hits, dumps and landing cells. Clients and joiners show what they receive.
- 1-player tests first for every rule, then host-plus-client tests.

**Non-Goals**
- Content files (routes, items, recipes, the key, weather `trade_wind`).
- The car's build site and beaching it on the next island.
- Route start effects (noise, flag, botija, patrol alert).
- Drift on mid and far crossings.
- Companions riding vessels.
- The capture gate.

## Decisions

### D1. Boards are per-rider vessels inside the one crossing

The crossing keeps its shared `integrity`. For a `BOARD` route it also keeps `boards: Dictionary[int, VesselIntegrity]` (peer to board), each created at `route.vessel_integrity`. The shared vessel is then created at 0, like swimmers, so no shared deck or lashing exists and every raft-only path stays off.

A rider's vessel is looked up by `vessel_of(peer)`: the board on a board route, the shared vessel otherwise. Its deck rect comes from `deck_rect_of(peer)`. Each existing single-vessel place goes through those two:

| Place | Change |
| --- | --- |
| `_enter_rider` | Start aboard when the rider's own vessel has integrity. |
| `bring_aboard` | Use the rider's own vessel and deck. |
| `_refresh_points` | Put the climb point on the rider's own deck edge. |
| `_swim` | Push a swimmer out of any intact deck. |
| `_on_broke` | Becomes a per-vessel callback that throws in only that vessel's riders and sinks only its cells. |
| `tie` | Needs the shared vessel intact, so it is never possible on a board. |

The raft keeps its own code path because the shared vessel's callbacks and decks are untouched.

**Board layout.** Each board is a 1×2-tile deck, nose north, so a rider stands on it as on the raft. Boards sit in a row through the sea's centre, 3 tiles apart centre to centre, in rider order. That leaves a 2-tile gap, so a swimmer is within 1 tile of at most one board edge. The sea (24×22) holds four with room.

A teammate's pull uses the existing pull handle: it sits on the swimmer and is enabled while the swimmer's own board is intact. The puller must be aboard their own board, and `RescuePoint.usable_by` already requires the user to be aboard.

*Rejected:*
- One crossing node per rider. That means four plans, four clocks and four results for one route, and late join and reconnect would multiply.
- A `Vessel` node class. Larger than needed, and it would move the raft's code.

### D2. Board hits go round, and the shark says it is a shark

`Crossing.hit_vessel(amount, shark := false)` stays the one entry the threats call. On a shared vessel it hits that vessel, as today. On a board route it hits the next intact board from a host-only round-robin index that starts at the first rider and skips broken boards. With no intact board it hits nothing.

When `shark` is true and the route lists `SHARK_ATTACK`, the riders aboard the hit vessel who are not tied down are thrown in at the usual fall-in cost. On a board, that is its one rider. Both threat resolvers pass `shark = true` on their vessel hit; rocks pass false.

`hit_vessel` returns the hit vessel's deck centre, so `CreatureThreats` shows the shark beside the board it hit. A squall calls a separate `hit_every_vessel` and then applies the squall dump as today, which on a board route throws every board rider in.

*Chosen by the owner (Q2, 2026-11-14).* Rejected:
- A target rolled by the host into the plan. Fair, but it changes the plan's wire format and snapshot.
- The weakest board. Concentrates deaths.

### D3. The car is the raft path with its own art

`Vessel.CAR` uses the shared vessel, the 4×2 deck and the lashing, at `route.vessel_integrity` (160), with the squall times `squall_damage_multiplier` (1.5). Both are data in content-batch-11's route. `CrossingDeck` picks `StructureArtData.car` instead of `raft` when the route's vessel is `CAR`.

### D4. Damage frames by share of the route's vessel integrity

`StructureArt.vessel_frame(value, nominal)` returns `raft_frame(value / nominal × 100)`, so the existing 66 and 33 thresholds become shares: whole above 66 %, worn above 33 %. Results for each vessel:

- A raft (nominal 100) draws exactly as before.
- A car at 95 of 160 reads worn.
- A new board at 60 of 60 reads whole, and so does one at 40 (66.7 %).

The nominal is `route.vessel_integrity`, not the starting value. A raft beached at 40 still reads worn, as art-pass "Raft site and raft" says.

### D5. Board state on the wire

- `receive_state(states, vessel_value, time_s)` gains `board_values: Dictionary` (peer to value).
- `CrossingSnapshot` gains the key `boards` (peer to value; 0 means broken). `from_dict` keeps only riders' entries, finite numbers and values clamped to `[0, route.vessel_integrity]`.
- A client marks a board broken when it receives 0, as `_show_broken` does for the raft.
- `CrossingResult.riders[peer]` gains `board` (float) and `board_broken` (bool) on board routes only. `from_dict` copies rider entries whole, so it needs no change. The route-wide `integrity` is 0 and `broken` is false, as for swimmers.
- `_on_player_rebound` moves the board slot with the rider's peer.

### D6. Route items spent at the start

`RouteLauncher.spend(route, starter, riders)` removes, for each `HAS_ITEM` condition with `consume` and not `negate`, `max(round(amount), 1)` of `ref_id`:

- for `route.requirements`, from the starter;
- for `route.rider_requirements`, from each rider.

Only top-level conditions count; nested `ANY_OF` and `ALL_OF` groups are not spent. `IslandRoutes.start_for` calls it on the host after the riders are picked and before `receive_departure`. Inventories replicate as today.

Content-batch-11 must give `tabla_vela`'s use `spends_use = false`, as `binoculars` has, and add the `HAS_ITEM tabla_vela consume` rider requirement. That is recorded in `TASKS.md`.

*Rejected:* spending in `ItemUser` before the effect runs. It cannot know whether the route will start, and a refused start must spend nothing.

### D7. Arrival scatter: the host picks cells and sends them

- **Data.** `RouteData.arrival_scatter_tiles: Vector2i = Vector2i(0, 5)` holds the minimum and maximum in tiles.
- **The picker.** `ArrivalScatter.pick(built, groups, seed)` is a pure helper in `game/scripts/levels/arrival_scatter.gd`. It takes peer ids grouped by route scatter and returns a `Dictionary[int, Vector2i]`. Placement runs in this order:
  1. Riders with the default scatter take the landing cells, in sorted peer order, as `landing_positions` does now.
  2. Every other rider is placed in sorted peer order. With nobody placed yet, the first takes the first landing cell, so solo is unchanged.
  3. After that, each candidate is a `BEACH` cell reachable on foot from the first landing cell, not already taken.
  4. A candidate fits when its straight-line distance in tiles to every placed rider lies within `[min, max]`. One fitting cell is picked with an RNG seeded from `hash([run_seed, islands_reached])`.
- **Fallback (spec "Arrival scatter fallback").**
  1. Among cells at least `min` from everyone, take the one with the smallest distance to the farthest placed rider.
  2. Otherwise, take the cell with the largest distance to its nearest placed rider.
  3. Ties go to the lower row, then column, so the pick is deterministic.
- **Grouping.** `IslandTravel.travel()` reads each rider's route from `_results`; a peer in no result gets the default. It adds `"cell": Vector2i` to each arrival.
- **Arrival check.** `CoopSession.checked_arrivals` keeps an optional `cell` when it is a `Vector2i`, and refuses the whole message if `cell` is present with another type. That is the only `coop_session.gd` edit.
- **Landing.** `_land` uses a sent cell when the built island has walkable land there, and otherwise falls back to `landing_positions`.

*Rejected:* computing the same cells on every peer from `_results`. A peer that joined after the crossing ended has no results, and the spec says the host decides. Sending cells costs a few bytes once per island.

### D8. Only a raft is beached

`IslandTravel._beached_integrity` counts a result only when its route, looked up in the catalog, has `vessel == RAFT` and `vessel_kept_on_arrival`. The board route sets `vessel_kept_on_arrival = false` as data. A car result beaches nothing until the almendrón has a site on the next island (Q4).

### D9. Art through the recipe

**Hand pieces.** These are drawn as pixel grids in master-palette colours and written with `tools/art/png.py`, with no Pillow:

| File | Content |
| --- | --- |
| `fixes/structures/car_body.png` | A 1950s sedan from above: rounded fenders, chrome bumper line, windshield and rear window, no grille badge or maker mark. |
| `car_worn.png`, `car_breaking.png` | Rust and dents, overlays for the worn and breaking frames. |
| `board.png` | A longboard with a tarp sail, no logo. |
| `board_worn.png`, `board_breaking.png` | Overlays for the worn and breaking frames. |

**Recipe.** In `structure_sheets.json`:

- `structures/car.png`, 64×32 with 3 frames: the body, plus four `barrel` cuts from the Zelda-like `Overworld.png` (the rain catcher's barrel and its `barrel` map) turned on their sides as drums, two behind the car and two in its wheel wells, plus an outboard shaft at the stern.
- `structures/board.png`, 16×32 with 3 frames.

**Build.** Run with `--packs C:/Users/liann/src/90miles/game/assets` (read-only). Re-running must leave every existing sheet byte-identical; `git diff --stat` shows only the new files.

**Wiring.** Add the SpriteFrames `car_frames.tres` and `board_frames.tres` (animations `whole`, `worn`, `breaking`) and the fields `StructureArtData.car` and `board`. The license and credits rows follow the art-pass pattern: hand pieces are CC0 by us, and the Zelda-like barrel keeps its existing credit.

**Drawing.** A new `CrossingBoards` (`game/scenes/crossing/crossing_boards.gd`, `Boards` in `crossing.tscn`, z -20 like the deck) keeps one `Sprite2D` per board. It reads `crossing.boards` every frame and shows nothing for a broken board. It reads only, as `CrossingDeck` does.

### D10. Companions

`CompanionData.can_swim`'s comment gains `BOARD`. No code reads `allowed_vessels` yet, and no companion exists. Marisol and Alfredo (cannot swim) may ride `CAR` and never `BOARD`; Tomás refuses boards via his `allowed_vessels` (content). Nothing else changes here.

## Reference games

Read in `reference/`; ideas only, no code.

**Arrival placement**
- **SPD.** `levels/Level.java: fallCell` and `randomRespawnCell` pick a random passable cell not in view and not occupied. `actors/mobs/Mob.java: holdAllies` and `restoreAllies` keep nearby allies and put them on free neighbours of the arrival cell, optionally nearest a "gravitate" cell.
  - *Borrowed:* never stack two arrivals on one cell while a free one exists (fallback rule).
  - *Rejected:* fully random falls with no distance rule, since the board's scatter is a distance band.
- **Brogue CE.**
  - `RogueMain.c: startLevel` lands a fall at `getQualifyingLocNear` the old position, with a dry-cell rescue when that is an enclosed lake.
  - Followers get `STATUS_ENTERS_LEVEL_IN` from their path distance, so they arrive later.
  - *Borrowed:* restrict the landing to qualifying cells reachable on foot (beach reachable from the landing), so nobody lands in an enclosed pocket.
  - *Rejected:* delayed arrival, because a whole party lands in one host message (and `dropped-teammate-state` rejects it too).
- **DCSS.**
  - `files.cc: _place_player_on_stair` places on the stair.
  - `_shaft_safely` tries random cells with a safety predicate and a fallback.
  - `mon-transit.cc: _place_lost_ones` with `follower::place` tries near the player, then anywhere.
  - *Borrowed:* a predicate (beach, reachable, inside the band) with a tiered fallback (keep the minimum, then spread as far as possible), and a deterministic tie-break.

**Knocked off, getting back on, per-object durability**
- **SPD.** No deep water or breakable platform; a chasm fall is a level change.
  - *Nothing borrowed.*
- **Brogue CE.**
  - `Time.c: playerFalls` deals fall damage, softened by liquid.
  - `handleDamage` makes deep water drop unequipped pack items.
  - Bridges are terrain that burns and falls (`BRIDGE_FALLING` in `Globals.c`), with no per-bridge hit points.
  - *Rejected:* item loss in water, because the crossing's cost of falling in is energy, and losing gear there would be a survival lever no spec asks for.
- **DCSS.**
  - `terrain.cc: fall_into_a_pool` is a message plus emergency flight.
  - `spl-summoning.cc` summons a block of ice as a monster with its own hit points.
  - *Borrowed:* a breakable thing is an ordinary hit-point holder (`VesselIntegrity` per board) rather than terrain.
  - None of the three has a "climb back on" timer. Ours is the crossing's existing 3 s hold, unchanged.

**Use refused by the environment, nothing spent**
- **DCSS.** `item-name.cc: cannot_read_item_reason` runs before `item-use.cc: read` spends anything.
- **SPD.** `items/scrolls/Scroll.java: execute` returns on `Blindness` before `doRead`.
- **Brogue CE.** `Items.c: readScroll` spends most scrolls even when they do nothing.
- *Borrowed:* DCSS and SPD's "check everything, then spend" order (D6).
- *Rejected:* Brogue's spend-anyway, because the spec says a refused start spends nothing.

## Decisions taken (owner, 2026-11-14; the recommended option on all four)

- **Q1. Route files and task 6.4's deferred tests.**
  - *(a, chosen)* `almendron`, `tabla` and `llave_almendron` stay in content-batch-11, as the manifest says; this change tests with fixture routes in `game/tests/fixtures/routes/`. The almendrón's solo build test (60 s with pliers, 60 energy) moves to content-batch-11 (task 8.3), with its recipe and items. The `almendron_hundido` gate test moves to the change that builds capture at sea, which also needs `FLAG_SET` and chain rows. Both are added as unticked tasks.
  - *(b)* Ship the two routes here too. Their starters (`tabla_vela`, `almendron_flotante`) do not exist, so the content validator would fail unless half of batch 11 came along.
- **Q2. Which board a shark or rock hits in co-op.** A squall hits every board in every option.
  - *(a, chosen)* Round-robin over intact boards in rider order.
  - *(b)* A target rolled by the host into the plan.
  - *(c)* The weakest board.
- **Q3. Rescue and tying down on a board.**
  - *(a, chosen)* No lashing on a board. The 3 s self-climb, and a teammate's 2 s pull onto the swimmer's own board.
  - *(b)* Self-climb only.
  - *(c)* A lashing on each board, as on the raft, so a squall need not dump a tied rider.
- **Q4. The car on arrival.**
  - *(a, chosen)* Beach nothing for now: the result keeps its integrity and never becomes a raft. Beaching the car at its own site waits for content-batch-11's `almendron_flotante` structure and the chain islands, recorded as a task.
  - *(b)* Build a generic beached-vessel structure now.

## Risks / Trade-offs

- **[`receive_state` and the snapshot change shape]** Every peer runs the same build, and the snapshot check refuses a missing key, so an old peer is refused rather than half-read.
- **[Shark dumps change the raft if a route lists the trigger]** The raft lists only `SQUALL`, so no shipped route changes. A test pins that.
- **[`checked_arrivals` is also edited by `dropped-teammate-state`]** Its change is the cap constant, and this change adds an optional key further down. Whichever lands second rebases, and the arrival tests are re-run.
- **[Fixture routes in the catalog's cache]** Tests put fixture `RouteData` into `GameState.content`'s cache by id and remove them in `after_each`, so they never leak into another test or into the content validator (fixtures live outside `res://resources/`).
- **[Hand-drawn art]** Rough first is accepted. The asset audit (`TASKS.md` §11) revisits it, and no maker's badge or logo is drawn.
- **[Provisional numbers]** Board spacing (3 tiles) and the 1×2 deck are ours. Crossing durations and speeds stay provisional until review item 29.
