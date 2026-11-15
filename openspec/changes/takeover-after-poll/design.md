# Design

## Context

See proposal.md, Why. This section covers how the error comes about.

The engine (read at the `4.7.2-stable` tag, the version CI pins):

- `modules/enet/enet_multiplayer_peer.cpp`, `ENetMultiplayerPeer::poll` (server): drains every ENet event of the poll into `incoming_packets` before it returns, in a `do … while (check_events)` loop.
- `thirdparty/enet/protocol.c`, `enet_protocol_dispatch_incoming_commands`: after one packet, a peer with more goes back to the end of the dispatch queue. Received packets are handed out one per peer in turn, so the packets of two senders interleave. The `enet_protocol_handle_send_*` handlers refuse data from a peer that is neither connected nor `DISCONNECT_LATER`, so nothing more arrives from a disconnecting peer.
- `ENetMultiplayerPeer::disconnect_peer` (not forced) sends ENet's disconnect and keeps the peer until a later poll. It never filters `incoming_packets`, so packets from that peer already read in this poll stay queued.
- `modules/multiplayer/scene_multiplayer.cpp`, `SceneMultiplayer::poll`, reads that queue in a loop and runs each RPC as it comes. Each packet whose sender is no longer connected fails `ERR_CONTINUE(!connected_peers.has(sender))`: the packet is skipped and an engine error logged.
- `SceneMultiplayer::disconnect_peer` calls `_del_peer` first, which takes the peer out of `connected_peers` at once with no `peer_disconnected` signal. Only then does it close the transport connection.

The game:

- `scene/main/scene_tree.cpp`, `SceneTree::process`: polls every multiplayer, emits `process_frame`, then flushes the deferred calls, then runs the nodes' `_process`.
- `CoopSession.request_join` is an RPC, so it runs inside that loop.
- On a TAKEOVER it calls `_close_peer(old)` → `SceneMultiplayer.disconnect_peer(old)` there, then `_on_peer_disconnected(old)`, `_reclaim(old, new)` and the reply.
- Every packet from the old copy queued behind the join request in the same poll then logs the error.

Measured before the fix, with the new test `test_a_takeover_while_the_old_copy_still_sends_is_clean`:
- the old copy sends 4 intent messages a frame;
- the error appears 9 times, in 3 of 3 runs;
- with frame markers printed to stderr, every error came after "takeover closed" and before the same frame's `process_frame`, so all of them came in the poll that ran the takeover and none in a later frame.

ENet refuses data from a peer once it is disconnecting (`protocol.c` above), so nothing arrives later. That explains why each case fails or passes:

| Case | Error? | Why |
|---|---|---|
| Two-process check (net-platform-seam 7.3) | 2 lines | The old copy had 2 packets queued behind the request. |
| Drop and rejoin | none | The old peer is gone before the request. |
| Frozen client (`NetHarness.freeze`) | none | It sends nothing more. |
| 10 s join timeout | none | `_close_peer` runs from `_physics_process`, outside the poll. |

## Goals / Non-Goals

**Goals:**
- No engine error on the host, whether the old copy still sends or not.
- Keep "Reclaiming a player" as it is: the host closes the old connection first, and nothing more is sent to a connection that is closing (`_close_peer`'s comment).

**Non-Goals:**
- Everything else in the engine: a peer closed from inside the packet loop always makes the engine log its queued packets.
- The other place that closes a peer inside a join request: `_add_player` when the session is full, which uses the transport's `disconnect_peer` (see Risks).
- Intent delivery, rate limits and the ENet throttle (`intent-delivery`).

## Decisions

### D1. Reference games: finish the handover after the event that noticed it

- **DCSS webtiles, `webserver/webtiles/process_handler.py`** (studied; ideas only):
  - A second connection can start a game that another process still holds by its lock. `CrawlProcessHandler._purge_locks_and_start` does not tear the old one down inside the handler that noticed it.
  - It signals the stale process (`_kill_stale_process` with SIGHUP) and tells the sockets (`send_to_all("stale_processes")`).
  - It schedules the forced kill on the event loop (`IOLoop.add_timeout`). It starts the new game (`_start_process`) only once the old lock is gone (`_purge_stale_lock` loops back to `_purge_locks_and_start`).
  - `CrawlProcessHandlerBase.stop(delay=True)` also defers its stop through `IOLoop.call_later`.
  - **Borrowed:** the old session ends before the new one starts, and the handover runs from the loop, after the current event. Here, that means after the current network poll.
  - **Rejected:** the 10 s SIGHUP grace and the "stale processes" message. Our old connection needs only the rest of the poll, a fraction of a frame, and a player who started a second copy wants it at once.
- **DCSS webtiles, `ws_handler.py`:**
  - `CrawlWebSocket.start_crawl` ignores a repeated request for a game that is already starting ("can happen when logging in with cookies"). **Borrowed** as D3.
  - `CrawlWebSocket.write_message` catches writes to a closed socket and only logs a warning. **Rejected:** we do not send to a closing connection at all, rather than tolerating it.
- **Don't Starve Together** (`docs/REFERENCE_DST.md`, "When a player disconnects"; wiki page "Console/Don't Starve Together Commands"):
  - The notes say the server keeps a leaver's character and puts it back on rejoin. Our reclaim already does this, and the body comes back whole here too.
  - The notes say nothing about a second login with the same account while the first is still connected, so nothing is inferred from DST about takeovers.
- **Shattered Pixel Dungeon and Brogue CE:** single-player, with no network code and no second connection, so they have nothing to borrow here.

### D2. Defer the whole takeover, not only the close

`request_join` claims the identity as now. On TAKEOVER it marks the new peer (D3) and calls `_take_over` with `call_deferred`, then returns. `_take_over` runs in this order, as the current code does:
1. `_close_peer(old)`;
2. `_on_peer_disconnected(old)`;
3. `_answer_join(new)`, the unchanged tail of `request_join`: the reclaim or a new player, `receive_lobby`, the crossing progress, `join_state_sent` and the roster.

`SceneTree.process` flushes deferred calls right after every multiplayer poll of the frame. So the takeover runs before the next poll, after the engine has read every packet of this one.

During the rest of the poll the old copy still owns its body, so its queued intents and requests act on that body, as they would have a frame earlier. Its repeat `request_join`, if any, is ignored because it is still in the roster.

Alternatives considered:
- **Defer only `_close_peer`, and keep the drop and the reclaim synchronous.** Tried and measured:
  - The new test passes.
  - `test_back_before_the_host_noticed_takes_over` fails with 8 engine errors on the frozen client's branch: "Node not found: Session", "Failed to get cached node from peer 1", "Invalid packet received. Requested node was not found".
  - The cause: the reclaim broadcasts `rebind_player`, `_share_roster` sends `update_roster` to every peer, and replication goes to a peer the host is about to close.
  - It also breaks "the host closes the old connection first". Rejected.
- **Use the transport's `disconnect_peer` (not `SceneMultiplayer`'s), as `_add_player` does.** The queued packets would pass, because the peer stays in `connected_peers`. But the host would keep sending RPCs and replication to a closing connection, which `_close_peer` exists to prevent, and a second `peer_disconnected` would arrive later. Rejected; not needed once D2 holds.
- **Drain a pending set in `_physics_process` instead of `call_deferred`.** It works, but it waits for the next physics tick, which can come after the next poll in a fast frame. It also adds a per-frame loop. Rejected.
- **Defer `request_join` itself before the claim.** That needs the claim's result to know it is a TAKEOVER, so the claim's logic would have to be repeated. Rejected.

### D3. A repeat join request from the new peer is ignored while its takeover is pending

Today a repeat is ignored because `roster.has(sender)` is true right after the first request. During a deferred takeover the new peer is not yet in the roster. A second request in the same poll would therefore claim the identity again: `IdentityRegistry.claim` would find the new peer itself as the holder, which is a TAKEOVER of itself.

A `_taking_over: Dictionary[int, bool]` holds the new peer from the claim until `_take_over` starts, and `request_join` returns early for a peer in it. A real client sends one request per connection, so this guards against a broken or hostile client only. It is still worth one line: without it, such a client could make the host close the client's own connection and then reply to a closed peer, which logs another engine error.

### D4. Tests

All tests use NetHarness on ENet localhost; the solo test is offline.

- **The run, old copy still sending:** the old copy (a live session, not frozen) sends 4 intent messages every process frame until it loses its connection. 2 would do, because the per-peer interleave then always puts at least one behind the join request; 4 leaves a margin. Red before the fix (9 errors, 3 of 3). Each message holds one standing-still intent numbered 1. After intent-delivery (`send_intents`/`submit_intents`), the host skips a number its body has already queued, so the body never moves and only the engine's sender check is exercised. Before that merge the test sent number 0 through `send_intent`, which the host's `enqueue` refused.
- **The same in the lobby,** where the second copy takes the roster entry.
- **A repeat join request:** a silent client with Papo's identity sends two requests in one frame while the old copy still sends.
- **Solo (1 player, offline):** a join request reaching a solo session is ignored, nothing is pending, and the player keeps their body.
- `test_back_before_the_host_noticed_takes_over` (frozen old copy) and the rest of `test_coop_reconnect.gd` stay green unchanged.

## Risks / Trade-offs

- [`_take_over` runs after the poll, so the new peer could in principle leave in between] → It cannot: the engine handles transport connect and disconnect events at the start of the poll, before the packet loop, and the deferred call runs before the next poll. No guard is added for a case that cannot happen; the test covers the order.
- [The old copy's queued requests act for a little longer] → Only within the poll that brought the join request, and only on the old copy's own body, as a frame earlier. It sends nothing to the new copy.
- [A sibling session changes `request_join`] → The tail of `request_join` moves into `_answer_join` at the same indentation, so its lines show as unchanged in the diff. A conflict is a rebase of a few lines.
- [`_add_player` closes a peer from inside `request_join` when the session is full] → It uses the transport's `disconnect_peer`, so it does not hit this engine check. `request_join` then still sends `receive_lobby` to that peer. Whether that logs anything is not checked here; it is a follow-up outside this change.
