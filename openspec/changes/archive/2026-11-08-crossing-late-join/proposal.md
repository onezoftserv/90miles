## Why

A client that joins, or rejoins under a new peer (`coop-reconnect`), while a crossing is under way sees no crossing. Every peer builds its crossing when `IslandRoutes.route_started` fires, and a late client never got that signal. So it has no `Crossing` node, and the host's plan, rider-state and result messages target a node path that does not exist there. Its join state also leaves out who already left by a route. The host stays correct, but a player who drops mid-crossing and comes back watches their own body stand on the island while the host has them on the raft. `coop-reconnect` recorded this as a known gap. It is the next piece because the reconnect makes it reachable in an ordinary run.

## What Changes

- **A joiner learns the run's progress after its join reply.** Right after the host answers a join request in the run (a new player, or a rejoined player reclaiming their body), it sends that peer:
  - who left by which route (`IslandRoutes.departed`);
  - the crossing counter, so later crossings get the same node name on every peer;
  - a snapshot of each crossing under way: route, serial (so the node name), riders in slot order, plan, elapsed time, each rider's state and position, and the vessel's maximum, value and whether it broke.
- **The joiner builds each crossing under way from its snapshot.** It does not roll or replay anything. Each rider body, the joiner's own included, goes into the sea at the host's position, with the sea as its ground and its camera limited to the sea, as entering a crossing does. Tied riders are pinned. From then on the host's normal messages keep it current, and the crossing ends on the joiner when it ends on the host.
- **A crossing the joiner already has is refreshed, not duplicated.** This covers a peer that connected and saw the route start before its join request was answered.
- **The host sends a crossing's messages only to peers that have that crossing:** the peers in the run when it launched, plus each joiner it sent the snapshot to. A connected peer that has not been told yet gets nothing it cannot place, so no peer logs a missing-node error.
- **The joiner's shell follows a restored crossing like one it launched.** The crossing keeps the run open while it runs. When it ends, its riders leave play (`ArrivalStub`) and the run-over check runs.
- **Solo is unchanged.** One player offline has no joiner, sends nothing and builds its crossing as before. A 1-player test keeps that.

**Decisions (made here, to confirm):**
1. **A joiner also hides riders whose crossing already ended.** Those riders left play on the host (`ArrivalStub.hold`: hidden, no collision). Without this, a late joiner would see them standing visible where the crossing left them. Applied when the departures arrive: every departed rider not in a crossing under way is held.
2. **Riders appear where the host has them, not at their deck spot.** A swimmer three tiles off the raft is three tiles off it on the joiner's screen from the first frame. The host's position sync then takes over.
3. **The joiner's crossing clock starts at the host's elapsed time.** The sea's scroll and the deck art pick up from there. Nothing that already happened (a squall warning, a hit) replays on the joiner; it sees the result in the integrity and rider states.

## Confirmed by the owner (2026-11-08)

- A joiner hides riders whose crossing already ended, as on the host (`ArrivalStub.hold`).
- Riders appear where the host has them, not at their deck spot.
- The joiner's crossing clock starts at the host's elapsed time; nothing that already happened replays.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `crossing`: adds "Joining during a crossing". A peer that joins or rejoins while a crossing is under way builds it from the host's snapshot. The host sends crossing messages only to peers that have that crossing.
- `escape-routes`: adds "Departures reach joiners". A peer that joins or rejoins mid-run learns who left by which route, and riders whose crossing ended stay out of play on its screen.

## Impact

- **Code:**
  - `game/scenes/crossing/crossing.gd`: snapshot and restore, recipients.
  - New `game/scripts/crossing/crossing_snapshot.gd` (`CrossingSnapshot`: to and from a checked dictionary).
  - `game/scripts/routes/island_routes.gd`: send and receive the progress, apply departures without emitting `route_started`.
  - `game/scenes/net/coop_session.gd`: one call after the join reply.
  - `game/scenes/shell/game_shell.gd`: track restored crossings and hold departed riders.
- **Network:**
  - One new host-to-client RPC, `IslandRoutes.receive_progress`, authority-only with a sender check.
  - The existing crossing RPCs switch from broadcast to `rpc_id` per recipient.
  - No intent changes and no new autoloads.
- **Tests:** a new `game/tests/unit/test_crossing_join.gd` over ENet with `NetHarness` (late join and rejoin mid-crossing), offline snapshot round-trip tests, a 1-player offline test and a shell test.
- **Depends on** `coop-reconnect` (onezoftserv/90miles#9): `player_rebound`, `CoopSession.peer_of`, the owner map in `receive_lobby` and `join_state()`. Built on its branch, moved onto `main` once #9 merges.
