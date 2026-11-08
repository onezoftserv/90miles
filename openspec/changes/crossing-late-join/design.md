## Context

See proposal.md, "Why", for the gap. What the code does today, on `coop-reconnect` (onezoftserv/90miles#9):

- **How a crossing starts.** `IslandRoutes.start_for` (host) sends `receive_departure.rpc(route, peers)` to every connected peer, then runs `_depart` itself. On every peer `_depart` fills `departed` and emits `route_started`. The shell (`GameShell._on_route_started`) then calls `Crossing.launch`. That takes the next serial from the session meta `crossing_serial`, names the node `Crossing<serial>`, places the sea at `serial * 1024`, and on the host rolls the plan and broadcasts `receive_plan`. The shell connects `ended`, keeps the node in `crossings` and, when it ends, holds its riders with `ArrivalStub`.
- **What the host owns on a `Crossing`:** the plan, `elapsed_s`, rider states (`_states`), `integrity` (`maximum`, `value`, `broken`) and `_fired_to_s`. It broadcasts `receive_state` on change and every second, and `receive_result` at the end. Clients only show it.
- **What a joiner gets today** (`CoopSession.request_join`, run phase):
  - Spawns of the existing bodies, on connect, under each body's first peer.
  - Then its own spawn (`_admit`) or the reclaim (`_reclaim`: `rebind_player` to all).
  - Then `receive_world_state(join_state())`: the world and the sky, filtered key by key by `checked_world_state`.
  - Last, `receive_lobby`, whose owner map re-binds bodies that changed hands. Only after it do a joiner's bodies sit under their current peers.
- **Ordering.** All of these are reliable messages on transfer channel 0, so ENet delivers them in order. `coop-reconnect` relies on the same.
- **GUT fails a test on any engine error** (`failure_error_types` includes `engine`). An RPC that reaches a peer without its target node is one.
- `coop_session.gd` is over the 800-line ceiling (867), so the new logic goes elsewhere.

## Goals / Non-Goals

**Goals:**
- A joiner's crossing matches the host's within one message, and matches its later resyncs.
- No peer ever receives a crossing message for a node it does not have.
- The joiner's shell treats a restored crossing exactly like a launched one.

**Non-Goals:**
- Arrival on the next island. Riders still leave play through `ArrivalStub`.
- Replicating crossings through a `MultiplayerSpawner`; see Decisions.
- Bleeding status and the reef shark's state on clients.

## Decisions

### Reference games

- **Borrowed from DCSS, `crawl-ref/source/tileweb.cc`, `TilesFramework::_send_everything()`.** It runs on the `spectator_joined` message. A watcher who joins a game in progress gets everything once: the player first, then the full map (`_send_map(true)`, marked `clear`/`spect_only`), then the stack of open menus. After that it gets the same deltas as everyone else, and the comment there notes that order matters ("Map is sent after player").
  - Borrowed here: a one-off full state pushed by the host to just the joiner when the join completes. It is ordered after the bodies and their owners, crossings travel as the "open frames" of the run, and the normal periodic messages resume afterwards.
- **Borrowed from Shattered Pixel Dungeon, `actors/Actor.java`, `storeInBundle()` / `restoreFromBundle()`.** Each actor stores its own `time` and `id`, and the restore keeps the id. Borrowed: the snapshot carries the crossing's own clock (`elapsed_s`) and its serial, so the restored node keeps the same name, and with it the RPC path. The restore does not re-roll anything.
- **Rejected from Brogue CE, `src/brogue/Recordings.c`, `loadSavedGame()`.** It rebuilds a game by replaying every recorded event from the seed (`executeEvent`). Replaying the plan's beats on the joiner would re-fire squall warnings and hits, and stepping the crossing would have the client simulate, which the host-authority rule forbids. The joiner never had the intents anyway. The joiner takes the host's present state instead.

### The progress travels in its own RPC, right after the join reply

- `CoopSession.request_join` gets one call after `receive_lobby.rpc_id(sender, …)`: when the run is on and the sender has a body, `IslandRoutes.send_progress(sender)`.
- Both a new join (`_admit`) and a reclaim (`_reclaim`, takeover included) end there, and the lobby phase cannot have a crossing.
- **Why not inside `join_state()`:** it goes out before `receive_lobby`. At that moment a joiner still holds re-bound bodies under their first peer, while the host keys riders and departures by the current peer, so a rider would find no body. `checked_world_state` is also a flat key-and-type filter, and nested crossing data would need its own validation anyway.
- **Rejected alternatives:**
  - A spawner for crossings: its spawn data replays the launch-time riders, who predate later rebinds, and it changes how every peer builds a crossing.
  - The joiner asking for the progress: one more round trip. The host already knows when the join completes, as DCSS does.

### The message: `IslandRoutes.receive_progress(departed, next_serial, crossings)`

It is authority-only and checks that the sender is `HOST_ID`. It carries:

- **`departed`:** the host's `IslandRoutes.departed`, peer → route id. The joiner keeps only int keys and route ids it offers, and replaces its own map with the result (the host's is the truth). It emits nothing, so `route_started` never fires and no crossing is launched twice.
- **`next_serial`:** the host's `crossing_serial` meta. The joiner sets its own to `maxi(current, next_serial)`, so a route started later gets the same node name on every peer. This also fixes a late joiner after a crossing that has already ended.
- **`crossings`:** one `CrossingSnapshot.to_dict()` per crossing under way: not finished, with a plan.

### `CrossingSnapshot` (`scripts/crossing/crossing_snapshot.gd`)

- A `RefCounted` like `CrossingResult`. `of(crossing)` builds one on the host. `to_dict()` writes it, and `from_dict(data)` returns null on any malformed field.
- **Fields:**
  - `serial`: int from 0 to `Crossing.MAX_SERIAL` (1023, far more than a run holds; its sea stays where float positions are exact). The node name is built from it, never read from the network.
  - `route_id`: must be a route in the catalog.
  - `riders`: ints in slot order, 1 to `CoopSession.MAX_PLAYERS`, no repeats. The slot gives the deck spot.
  - `plan`: `CrossingPlan.from_array`, with a length above 0.
  - `elapsed_s`, `maximum` and `value`: finite. `value` is clamped to `[0, maximum]`.
  - `broken`: bool.
  - `states`: rider → int in `[0, Rider.size())`. Only listed riders are kept.
  - `positions`: rider → finite `Vector2`.
- `maximum` and `value` are separate fields: `setup()` turns its starting integrity into the maximum, so passing the current value would make a raft at 60 of 100 arrive as 60 of 60.

### Restore: `Crossing.restore(session, snapshot) -> Crossing`

- **If `Crossing<serial>` already exists on the joiner** (it saw the route start before its join was answered): apply the snapshot to it and return it. Nothing is duplicated.
- **Otherwise:**
  1. Instantiate the scene and name it `Crossing<serial>`.
  2. Add it to the session.
  3. `setup(session, route, riders, maximum, plan, serial)`. That runs `_enter_rider` for each rider: sea ground, no swim drain from the island and camera limits to the sea.
  4. Apply the snapshot.
- **Applying a snapshot:**
  - It goes through the same body as `receive_state`, factored out as `_apply_state(states, value, time)` with the sender check left outside. A snapshot and a live resync therefore cannot diverge.
  - A break (`broken`, or a value of 0) sinks the deck: its cells become deep water, as `_on_broke` does on the host. A live resync now does the same, so a client that was there all along no longer keeps a sand deck after a break.
  - Each rider's body is bound to the sea again (ground and camera limits, the half of `_enter_rider` split out as `_bind_body`). That covers a rider whose body was not under that peer yet when the crossing was built: a body re-bound before an early peer's join reply.
  - Each rider's body goes to its snapshot position, clamped into the sea, instead of the deck spot `_enter_rider` used.
  - `_apply_flags` then pins tied riders.
- The restored crossing never advances: `advance` returns on a client. It shows, scrolls and waits for `receive_state` and `receive_result` as any client's does.
- Restore never touches `launch`'s counter or rolls a plan.

### The host sends crossing messages only to peers that have the crossing

- **`Crossing._recipients`:**
  - **At launch, on the host:** it is seeded with the connected peers that are in the run (`roster`). `start_for` sends `receive_departure` to every connected peer just before, so each of them builds the crossing before the plan arrives. A peer still joining builds it too but gets no crossing messages until its join is answered; the snapshot then brings it the plan and the rest.
  - **`send_progress`:** adds the joiner (`share_with(peer)`) when it snapshots a crossing for that peer.
- `receive_plan`, `receive_state` and `receive_result` go out through `rpc_id`, to each recipient still in `get_peers()`.
- A peer that connected but whose join is unanswered gets nothing. With the broadcast it got `receive_state` for a path it lacks and logged an engine error.
- Solo has no peers, so the list stays empty and nothing is sent, as today.
- The `crossing_serial` counter is only read and written by the existing launch and by the joiner's `maxi`. Nothing else moves it.

### The shell follows restored crossings

- `IslandRoutes` emits `progress_received(restored: Array[Crossing])` on the joiner after applying the progress.
- `GameShell` connects to it in `_build_run`, next to `route_started`. For each restored crossing it does what `_on_route_started` does after launching: connect `ended` to `_on_crossing_ended` and append to `crossings`. Already-tracked nodes are skipped.
- Then it holds, with `ArrivalStub.hold`, every departed rider who is in no crossing under way: their crossing ended before the join (proposal decision 1). Then `_check_run_over`.
- A rejoined rider whose crossing is still running keeps the run open, as on the host.

### Tests

- **Offline (`test_crossing_snapshot.gd`):**
  - A snapshot round trip keeps every field, keeps maximum and value apart, and keeps slot order.
  - `from_dict` refuses each malformed field: a bad serial, an unknown route, too many riders, a repeated rider, an out-of-range state, a non-finite time or integrity, a malformed plan.
  - A restore into a second offline session builds `Crossing<serial>` with the riders on sea ground, the camera kept to the sea, tied riders pinned and the host's positions.
  - Restoring twice keeps one node.
  - **1 player, offline:** a solo session with 1 rider restores and shows the crossing at its elapsed time; a solo launch keeps no recipients and sends nothing.
- **ENet (`test_crossing_join.gd`, with `NetHarness` and `_crossings`'s pattern of building the client node first):**
  - **Late join mid-crossing:** a host and client A ride a raft and A falls in; client B joins. B gets `Crossing0` with the host's plan, elapsed time (within 1 s), states, maximum and value, and A's body at the host's position in the sea. Later host states reach B. The crossing ends on B with the host's result. No engine error is logged.
  - **Rejoin mid-crossing:** A carries an identity, rides with the host and ties down. A drops and joins again. On the rejoiner, the crossing has the new peer in A's slot, A is tied, A's own body is on sea ground with the camera limits equal to `sea_rect()`, and `departed` has A under the new peer. On the host the slot is unchanged.
  - **Routes:** a late joiner learns `departed` without `route_started` firing. A peer that connected while still awaiting its join request receives no crossing messages.
- **Shell (`test_game_shell.gd`, offline):** a restored crossing is tracked, keeps the run open and holds its riders when it ends; a departed rider with no crossing under way is held.

## Risks / Trade-offs

- **[Ordering]** The restore relies on `receive_progress` arriving after `receive_lobby` and after the spawns. → All of them are reliable messages on channel 0. That is the same guarantee `coop-reconnect` relies on, and the ENet tests exercise it.
- **[Elapsed skew]** The joiner's clock starts one latency behind the host's. → The 1 s resync corrects it, and the test allows 1 s.
- **[Positions]** The joiner's own predicted body is placed at the snapshot position, and prediction then reconciles it to the host's state. → It is placed only once, and the host's position sync owns it after that.
- **[A new joiner path through `IslandRoutes`]** `IslandRoutes` now depends on `Crossing`. → It already starts what becomes a crossing, and the shell stays the only place that launches one from a route start.
- **[Recipients]** Seeding recipients from the roster at launch assumes every peer in the run has `Routes`, so that it built the crossing. → Every session furnished by an island has it, and NetHarness tests furnish both sides.
- **[A forged host]** The host is trusted by design: it can already spawn bodies and set any state. The joiner still refuses malformed snapshots and caps the serial and the number of snapshots, so a bad message cannot crash it or place a sea at a huge offset.

## Migration Plan

- Built on `claude/coop-reconnect` (75b4f7c), on its own branch.
- Once #9 merges into `main`: after a normal merge, merge `origin/main` into this branch; after a squash merge, rebase this branch onto `origin/main` from 75b4f7c, before pushing it for review.
- Then open the PR against `main`.
- No save data or settings change, and nothing to roll back beyond the code.
