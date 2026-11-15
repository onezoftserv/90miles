# Proposal

## Why

When a second copy of a player's game joins while the first is still connected and sending (coop-reconnect TAKEOVER), the host logs `Condition "!connected_peers.has(sender)" is true` from Godot's `SceneMultiplayer.poll`, once for each packet the old copy still had queued. net-platform-seam found it in its two-process check (`openspec/changes/net-platform-seam/tasks.md` 7.3, "One error, attributed"), and no test covered it. The host takes the join request inside the engine's packet loop and closes the old connection there. The packets from the old copy that the same poll already read are then dropped with an engine error. The game state ends up right, but a host that logs engine errors during normal play hides real ones, and GUT fails a test on any engine error.

## What Changes

- The host finishes a takeover after the current network poll, not inside it. In order, it closes the old connection, treats the old peer as dropped, hands the body to the new connection and answers it, as today, all in one step after the poll.
- Until then the old copy still owns its body. Its packets from that poll are read as normal: its intents and requests still go to its own body, as they did a frame earlier. Nothing new is sent to the old copy before it is closed.
- A repeat join request from the new connection, sent before the takeover finishes, is ignored, as a repeat is ignored today once the joiner is in the roster.
- Drop and rejoin (RECLAIM), a new player, a guest and the 10 s join timeout are unchanged. So is a takeover whose old copy sends nothing more (a crashed client).
- Solo is unchanged: no client joins, so no takeover happens.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`: adds "Finishing a takeover" beside "Reclaiming a player", whose text stays as it is. The host finishes a takeover only after it has read every packet that came with the join request. The new requirement has scenarios for a second copy that is still sending, in the run and in the lobby, for a repeated join request, and for solo.

## Impact

- `game/scenes/net/coop_session.gd`: `request_join` hands a TAKEOVER to a new `_take_over`, deferred until the current poll is done. The rest of the reply moves unchanged into `_answer_join`, and a small `_taking_over` set holds new peers whose takeover is pending. `_close_peer`, `_reclaim`, `_on_peer_disconnected`, `submit_intent` and the rate limits are not touched.
- Tests: `test_coop_reconnect.gd` gains a takeover with an old copy still sending, a repeat join request during the takeover, and a lobby takeover with an old copy still sending, plus a 1-player offline case.
- No new autoload, no content, no backend, and no change to `NetHarness`, `NetManager`, `EnetBackend` or `IdentityRegistry`.
