# Proposal

## Why

The `art-pass-followups` playthrough (2026-11-13) found two problems with a dropped client.
- On a client, a disconnected teammate's row reads "Caído", not "Desconectado". Only the host knows who dropped (`CoopSession._dropped`). It downs the dropped body, and clients see only the downed state, so the host and the clients disagree, and so would a late joiner.
- A dropped body left on the sandbar holds the party's landing until it is removed, so the riders who crossed wait out of play for about 90 s after the last client leaves.

The second is what the `escape-routes` "Split parties" rule says today ("A dropped player who is still on the island keeps it open until removed"), so changing it was the owner's call; they chose the 30 s short hold (design.md, decision D3).

## What Changes

- The host writes whether each body is dropped into the body's own synced state, so every peer knows, late joiners included (they get it with the spawn). On every peer a dropped teammate's HUD row reads "Desconectado". "Muerto" still comes first, and a body the meters downed reads "Caído" once its player is back.
- A waiting rider's "Esperando a:" line marks a dropped teammate "(desconectado)", so the riders see why they are waiting.
- **Owner decision D3 (2026-11-14, option A):** once a dropped body still on the island is the only thing keeping the party from landing (every other living player has left by a route, at least one rider is waiting, and no crossing is running), its countdown is cut to at most 30 s. When the countdown runs out the body is removed, counts as dead, and the party lands. A rejoin within those 30 s takes the body back and the player plays on. With nobody waiting (every connected player dead), the full 90 s still hold, so a drop never ends the run early. A dropped rider in the middle of a crossing still holds the landing until that crossing ends.
- The host re-checks the party when a player drops, not only when someone dies, is removed or ends a crossing.
- An arrivals message and the world state's `waiting` list may name up to 8 players instead of 4. Dropped bodies do not hold a place in the player cap, so four connected players plus a dropped rider who is waiting are five arrivals. Every peer refused that landing, and the refused landing then made the host loop until it crashed.
- Found while applying (design D5): a refused landing no longer re-queues itself forever. The host waits for the next change, then tries again.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`: "Disconnect handling": every peer knows that a player is dropped, late joiners included, and the hold is shortened when it alone keeps the party from landing.
- `ui-shell`: adds "Teammate state word": which word a teammate row shows ("Muerto", "Desconectado", "Caído"), in that order, the same on the host, on the clients and on late joiners. It is a new requirement rather than an edit to "HUD layout", which the unarchived `sign-note-panel` change also modifies. "Screen flow" is unchanged: a disconnected player still keeps the run open until removed.
- `escape-routes`: "Split parties": a dropped body still on the island holds the landing for at most 30 s once it is alone in holding it (D3), and the waiting line marks a dropped teammate.

## Impact

- `game/scripts/net/player_net.gd` (a `net_dropped` shadow field) and `game/scenes/player/player.tscn` (one more `StateSync` property).
- `game/scenes/net/coop_session.gd`: small, local edits. `_on_peer_disconnected` and `_reclaim` write the flag. `is_dropped` reads it on clients. A host-only `shorten_drop(peer, at_most_s)`. `MAX_ARRIVALS` becomes 2 × `MAX_PLAYERS`. Nothing near the structure-sync work.
- `game/scripts/levels/island_travel.gd`: `check()` skips a dropped body on the island when riders wait and asks the host to shorten its hold. It also listens to `player_disconnected`. `_travel_when_idle` keeps its queued flag up while it runs.
- `game/scenes/shell/game_shell.gd`: the waiting line.
- `game/scenes/ui/run_hud.gd`: unchanged logic, since `state_word` already ranks the words. Its inputs now agree on every peer.
- Tests:
  - `test_player_state_sync.gd` (the field list).
  - `test_run_hud.gd` and a new `test_dropped_teammate_net.gd` (host plus clients: the observer, a late joiner, a rejoin within 90 s, the word ranks).
  - `test_coast_cay_net.gd`: the shortened hold, a rejoin within it, a dropped rider mid-crossing, nobody waiting. Its "removed player counts as dead" case is updated.
  - `test_arrivals_cap.gd`: the cap, five bodies landing together, and a refused landing that does not spin the host.
  - A 1-player offline test.
- No new autoload, no new RPC, no change to `net_peers.gd`, `net_manager.gd` or the join screen.
