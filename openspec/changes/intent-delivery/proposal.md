# Proposal

## Why

The host steps a client's player once for each movement intent it receives, using that intent's own time step. Any intent that does not reach the host, or that the host refuses, is lost movement, and the client's prediction snaps back by it. Two headless processes on UDP 7788 (`tests/manual/intent_link_probe.tscn`, design.md "Measurements") show three causes in the game's own settings:

- **ENet's packet throttle.** `submit_intent` is unreliable, and ENet's default throttle drops a share of unreliable packets whenever round trips run above the last 5 s baseline. Every probe client started at a throttle of 28 of 32 and lost about 1 intent in 11 for its first 1 to 6 s. In the art-pass playthroughs (2026-11-09) the client's throttle fell to 6/32 and then 0/32 on a lossless localhost link with a 14 ms round trip, and the client's walk and palm hold snapped back for seconds.
- **The per-peer rate limits after a hitch.** When the host stalls, the client's intents queue and arrive together. In the probe, one 1 s host frame left 60 intents waiting. The intent burst (30) and the 0.25 s of simulated-time slack refused 46 to 48 of them in all 4 runs, and the client snapped back 34 to 37 px (about 2.3 tiles) in one jump.
- **Lost packets.** On a real link each lost packet is a lost frame of movement, because each packet carries one intent.

The coordinator's `net-platform-seam` design (Q5) adds one more reason to act now: Steam and EOS deliver `unreliable_ordered` reliably, so the intent path's delivery mode has to be chosen for every backend, not left to ENet.

## What Changes

- A client's intent message carries its newest intent plus the intents before it that the host has not acknowledged yet, up to a cap. The message is sent unreliable and unordered. The host queues each intent number once, the first time it sees it. It skips older and repeated numbers before the rate limits see them, so a repeat costs the client nothing. One lost packet no longer loses any movement. The host's own player and the solo player still apply exactly one intent on the frame it is made, with nothing repeated.
- ENet's packet throttle is kept open on every game connection, as `NetHarness` already does for the tests. The host sets it on each connection when it connects, and ENet passes the setting to the client. It goes in the `net-platform-seam` change's `enet_backend.gd` once that change merges (owner decision Q2, 2026-11-14).
- The per-peer limits get headroom for hitches (decision Q3 in design.md): an intent burst of 90 and 1.25 s of simulated-time slack, with the host holding up to 90 queued intents per player. The refill stays at 1 s per s. With these, a host frame of up to 1 s no longer snaps a client back.
- A manual two-process probe (`game/tests/manual/intent_link_probe.tscn`) stays in the repo to measure the link again. It logs intents sent, intents queued, numbers lost, refusals, snaps, throttle and round trip once a second.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`: "Host authority" says how intents travel and that the host applies each one once. "Per-peer rate limits" counts each intent once and changes the simulated-time numbers (decision Q3).

`player-movement` is unchanged: prediction, replay and reconciliation keep their rules, and they only see fewer corrections.

## Impact

- `game/scenes/net/coop_session.gd`: the intent RPC, its host handler, and the order of checks (repeat, validity, limits, queue). These are local edits to the intent path only. The disconnect, structure-sync, perch and spectate code is untouched.
- `game/scripts/net/player_net.gd` and `prediction_buffer.gd`: send the newest unacknowledged intents, and expose the host's last queued number.
- `game/scripts/net/peer_limits.gd` and `PlayerNet.MAX_QUEUED`: the limit numbers (decision Q3).
- `game/scripts/net/net_peers.gd`, or the seam's `enet_backend.gd`: the throttle setting. The coordinator owns these files (decision Q2).
- Tests: `test_player_net.gd`, `test_prediction_buffer.gd`, `test_coop_session_rate_limits.gd`, `test_coop_session_solo.gd` (the 1-player test), and a new `test_intent_delivery_net.gd` (host plus client over ENet with lost sends).
- Bandwidth: up to 8 intents of about 17 bytes per client message at 60 Hz, roughly 8 KB/s from each client to the host. No new autoloads and no new dependencies.
