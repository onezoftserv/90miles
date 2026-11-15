# Design

## Context

- **The intent path today.**
  - `PlayerNet._predict` (a client's own body) pushes each frame's intent into `PredictionBuffer`, sends it, and predicts.
  - `CoopSession.send_intent` sends it as `submit_intent(seq, direction, run, crouch, interact, delta)`, `unreliable_ordered`, on channel 0.
  - The host's `_receive_intent` checks the body, `is_valid_intent`, then `accept_intent` (the `PeerLimits` buckets). Only then does `PlayerNet.enqueue` refuse a `seq` that is not newer than the last.
  - `PlayerNet._step_host` steps the body once per queued intent with that intent's `delta`, at most 8 per frame, and writes `net_ack_seq`.
  - On each host state, the client drops what the host acknowledged and replays the rest (`_reconcile`). A number the host never queued is acknowledged by any later one, so its movement is gone from both sides. The client sees that as a snap back.
- **The host's own player and solo** go through the same RPC with `call_local`, one intent a frame, applied at once, and never limited (`accept_intent` trusts `HOST_ID`).
- **ENet.** The game's `ENetMultiplayerPeer`s keep ENet's throttle defaults: interval 5000 ms, acceleration 2, deceleration 2, scale 32.
  - On each acknowledged reliable command, ENet lowers the throttle by 2 when the round trip is more than twice the variance above the epoch's lowest, and raises it by 2 when the round trip is at or below that lowest.
  - When it sends an unreliable packet, sequenced or not, it adds 7 to a counter modulo 32 and drops the packet if the counter is above the throttle.
  - Intents carry no acknowledgement, so the client's throttle moves only when the client sends something reliable (a pick-up, a craft, a chat, a join).
  - `NetHarness` (tests only) opens the throttle on every connection since PR #43.
- **Ownership.** `net_peers.gd`, `net_manager.gd`, `game/scripts/net/` backends and `game_shell.gd` belong to the coordinator's `net-platform-seam` change. The dead-spectate, structure-state-sync and creature-perch-ride sessions also edit `coop_session.gd`, so this change edits only the intent functions there.

## Measurements

`game/tests/manual/intent_link_probe.tscn` runs the co-op playground as two headless processes:
- The host is on UDP 7788.
- In relay runs, the host is on 7789 behind a UDP relay on 7788 that adds delay, jitter and loss and keeps packets in order.
- The client walks a 1.5 s square by setting its intent each frame.

The host wraps the session clock to count intents that reach the rate limits. It counts queued intent numbers and gaps, and reads the simulated-time bucket. The client counts host states that move its predicted body by more than 0.5 px ("snaps"). One frame of walking is 1.1 px. Runs are 40 s (batch 3: 10 s), after the art-pass recipe's 5 s idle before hosting and joining (batch 3: 2 s). Other sessions were loading the machine, as in real play.

In batches 1 and 2, "throttle open" means the host set deceleration 0 when the client's body spawned, after the join request. Batch 3 shows that this is too late.

The relays add 40 ms plus 0 to 20 ms each way, so the round trip is about 100 ms. Batch 1's relay swapped packets that were due at the same moment (a bug); batch 2's relay keeps order unless told to reorder.

Each cell lists one value per run, in run order (for example "1, 20, 1" is three runs).

| condition | runs | intents lost (of about 2400) | refused by the limits | worst snap | client throttle: lowest (seconds below 32) |
|---|---|---|---|---|---|
| **Batch 1: the client sends only intents** | | | | | |
| calm localhost | 3 | 1, 20, 1 | 0 | 1.1 px | 28 (1, 6, 1) |
| host frames of 100 ms for 3 s | 2 | 1, 13 | 0 | 1.1 px | 28 (1, 4) |
| client frames of 100 ms for 3 s | 2 | 4, 4 | 0 | 1.1 px | 28 (1, 1) |
| one host frame of 1 s | 2 | 77, 50 | 46, 46 | 37 px | 28 (6, 1) |
| relay that reorders ties | 2 | 47, 56 | 0 | 2.1 px | 30, 32 |
| the same relay with 3% loss, throttle open | 1 | 128 | 0 | 2.1 px | 32 |
| the same relay with host frames of 100 ms (2 runs; the second was meant to be `unreliable`, see the note under the table) | 2 | 32, 22 | 0 | 2.1, 1.1 px | 32 |
| calm localhost, windowed (rendering) client | 1 | 31 | 0 | 1.1 px | 28 (6) |
| **Batch 2: the client also sends 1 reliable request a second** | | | | | |
| calm localhost | 2 | 0, 0 | 0 | none | 28 (1, 1) |
| host frames of 100 ms for 3 s | 2 | 19, 12 | 0 | 2.1 px | 28 (6), 26 (5) |
| the same, throttle open | 1 | 0 | 0 | none | 28 (1) |
| the same again (meant to be `unreliable`) | 1 | 0 | 0 | none | 28 (1) |
| in-order relay | 1 | 2 | 0 | 1.1 px | 30 (2) |
| the same, throttle open | 1 | 0 | 0 | none | 32 |
| in-order relay with 2% loss, throttle open | 1 | 51 | 0 | 2.1 px | 32 |
| in-order relay with 1% reordering (34 and 19 packets reordered; the second run was meant to be `unreliable`) | 2 | 20, 13 | 0 | 1.1 px | 32 |
| **Sustained load: both processes at 20 ms frames after a calm join, the client sending 2 requests a second** | | | | | |
| default throttle | 1 | 2 | 0 | 1.1 px | 28 (4) |
| throttle opened only after the join request (at `player_spawned`) | 1 | 31 | 0 | 1.1 px | 28 (6) |
| **Batch 3: joins, 10 s each, 1 request a second** | | | | | |
| ENet's defaults | 4 | 0, 11, 0, 0 | 0 | 1.1 px | 28 (1, 4, 1, 1) |
| opened at connect on the host only (`peer_connected`, as `NetHarness`) | 4 | 0, 0, 0, 0 | 0 | none | 32 |
| opened at connect on both ends (and `connected_to_server` on the client) | 4 | 0, 0, 0, 0 | 0 | none | 32 |
| **Checks: 1 request a second** | | | | | |
| in-order relay, one host frame of 1 s, today's limits | 1 | 48 | 48 | 34 px | 32 |
| intents `reliable` (the annotation edited for the run), in-order relay with 2% loss, throttle open | 1 | 72 | 72 | 20 px; the host's view stalled up to 517 ms | 32 |
| intents `reliable`, one host frame of 1 s | 1 | 47 | 47 | 37 px | 0 (3) |

The probe's `--transfer` option set the mode with `Node.rpc_config` at run time. A `reliable` run behind 2% loss lost the same intents as the relay dropped, so the script's `@rpc` annotation won and the option did nothing. The rows above that were meant to be `unreliable` therefore ran `unreliable_ordered`, and the option is removed. The two `reliable` checks edited the annotation for the run and put it back.

**Readings:**

- **The throttle at join.** Every client starts at 28/32, so about 1 intent in 11 is dropped before it is sent.
  - A client that sends only intents gets no round-trip samples, so it stays there for 1 to 6 s (calm and windowed runs).
  - A client that also sends requests is back at 32 within a second.
  - Windowed and headless clients behave the same.
- **The throttle under load.** Slow frames while the client sends requests lower its throttle (26 to 28 for 5 to 6 s, 12 to 19 intents lost). Keeping it open removed every such loss in batch 2 (0 in each open run). How early it is set matters too; see the next reading.
  - The deep fall that the art-pass playthroughs logged (6/32, then 0/32, `2026-11-13-art-pass/tasks.md` task 3.6 and the follow-up note) did not happen at these loads.
  - It needs much more reliable traffic from the client than a player's requests make. A sustained slowdown after a calm join did not deepen it (2 lost). With every intent sent reliable (60 a second), one 1 s host frame took the client to 0/32, which is the same mechanism.
- **When to open it.** Setting deceleration 0 stops further falls but does not undo a fall that has already happened.
  - Opened only after the join request, the client stayed at the join's 28/32 for 6 s and lost 31 intents. The throttle came back only when ENet's 5 s baseline rolled over.
  - So the setting has to be made before the join's reliable traffic.
  - Batch 3: opened by the host at `peer_connected`, the client never left 32/32 (4 of 4 joins), because ENet sends the setting before the join's traffic. Opening it on the client as well added nothing.
- **Redundancy against the throttle.** ENet decides each drop by stepping a counter by 7 through 0 to 31, so at a throttle of T it sends the packets whose counter is at or below T.
  - At 6/32 or more, it never drops more than 4 packets in a row, and 8 intents a message (covering 7 lost in a row) lose nothing.
  - At 3/32 to 5/32 it drops up to 8 in a row; at 2/32, 13; at 0/32, 31 (1 in 32 sent).
  - So redundancy alone covers everything but the deep fall, and the throttle setting covers that.
- **The limits after a hitch.** One host frame of 1 s queues 60 intents together.
  - The intent burst (30) and the simulated-time slack (0.25 s, 15 frames) refused 46 to 48 of them in every run (localhost twice, the relay once, reliable once). The client snapped back 34 to 37 px, about 2.3 tiles, in one jump.
  - The host's clock runs during the hitch, so the bucket refills to its slack. A bigger slack therefore absorbs a longer hitch, whatever the refill.
  - Afterwards the refill equals the honest rate, so the bucket keeps only the headroom it has left: 1 to 20 ms, about one frame, won back by refusing one intent. Behind the in-order relay with 0 to 20 ms of jitter that refused nothing more for 30 s. A jittered burst larger than one frame would cost one intent each time.
- **Loss.** With the throttle open, 2% relay loss each way still lost 51 intents, each a snap. Only redundancy (or reliability) fixes that.
- **Reordering.** 1% reordering lost about every reordered packet (`unreliable_ordered` makes ENet discard a late packet).
  - `unreliable` would deliver it, but `PlayerNet.enqueue` refuses a number older than the last one it queued. So a mode change alone does not save it (from the code; not measured, see the note under the table).
  - Redundancy does, because the newer packet already carried the late intent.
- **Reliable intents.** Behind 2% loss, each resend held up every later intent:
  - The host's view of the client stalled for up to 517 ms.
  - The resent intents then arrived in bursts, and the limits refused 72 of them. The worst snap was 20 px.
  - That is worse than unreliable (51 intents lost, about 1 px each), and teammates would see that player freeze and jump.
- **ENet's source** (`protocol.c`, `enet_protocol_check_outgoing_commands`) applies the throttle to every packet that is not reliable, unsequenced ones included. A move to `unreliable` does not escape it.

### After the change

The same probe and relay on UDP 7788 with Q1 to Q3 built: `main` at e15369b merged in, and the game's own ENet settings (the throttle now opened by `EnetBackend` at connect). 40 s runs.

| condition | runs | intents lost | refused by the limits | snaps | client throttle: lowest |
|---|---|---|---|---|---|
| calm localhost, intents only | 2 | 0, 0 | 0 | 0 | 32 |
| calm localhost, 1 request a second | 1 | 0 | 0 | 0 | 32 |
| host frames of 100 ms for 3 s, requests | 2 | 0, 0 | 0 | 0 | 32 |
| one host frame of 1 s, requests | 2 | 0, 0 | 0 | 0 | 32 |
| in-order relay, requests | 1 | 0 | 0 | 0 | 32 |
| in-order relay with 2% loss (46 client packets dropped) | 1 | 0 | 0 | 0 | 32 |
| in-order relay with 1% reordering (24 client packets reordered) | 1 | 0 | 0 | 0 | 32 |
| in-order relay, one host frame of 1 s | 1 | 0 | 0 | 0 | 32 |

After each 1 s host frame the simulated-time bucket fell from about 1230 ms to 208 to 235 ms, and it refused nothing. No log had an `ERROR` line.

## Goals / Non-Goals

**Goals:**
- A lost or thinned packet costs a client no movement as long as a later packet arrives within 8 frames.
- A host hitch of up to 1 s costs a client no movement, and leaves 0.25 s of headroom for jitter afterwards.
- The delivery mode works unchanged on ENet, Steam and EOS. It relies on neither ordered nor reliable delivery.
- Solo and the host's own player are untouched: one intent a frame, applied on its frame, never copied or limited.

**Non-Goals:**
- Changing prediction, replay, interpolation or the 20 Hz host state (`player-movement` is unchanged).
- Filling a gap longer than the redundancy, for example by repeating the last intent on the host. The next host state corrects it, as today.
- Making the host's state messages redundant. They already carry absolute state, so a lost one costs only freshness.
- Steam or EOS code (net-platform-seam's later changes).

## Decisions

**Owner decisions (2026-11-14, "Accept all recommended", relayed by the coordinator):**
- Q1(a): redundant, unordered intents.
- Q2(a): ENet's throttle kept open from connect. It goes in the seam's `enet_backend.gd` after `net-platform-seam` merges.
- Q3(a): intent burst 90, slack 1.25 s, queue 90, refill unchanged.

**D1. References (ideas only).**

- **Shattered Pixel Dungeon and Brogue CE** are single-player and turn-based, with no network input path. Nothing to borrow.
- **DCSS webtiles** (`crawl-ref/source/webserver/webtiles/ws_handler.py` `on_message`, `process_handler.py` `CrawlProcessHandler.handle_input`; the client's `game_data/static/menu.js` sends `comm.send_message("key", ...)`):
  - Every key press goes as one message over a WebSocket (TCP: reliable and ordered), and the server writes it into the game's input. Nothing predicts; the server's answer is what is drawn.
  - **Borrowed:** an input that changes state must never be lost on its way, however it travels.
  - **Rejected:** a reliable, ordered stream for 60 Hz movement. A turn-based game can wait for a resend. Our host would stop stepping this player for a resend's round trip and then get a burst, and every later intent waits behind the lost one.
- **Don't Starve Together:**
  - Its "Lag Compensation" option (Predictive or None) turns movement prediction on or off. Players describe the trade as prediction with rubber-banding against input delay [unverified: from search snippets of Klei forum and support pages, which refuse fetching; the wiki has no page for the option].
  - REFERENCE_DST.md ("Client-hosted and dedicated servers", Dedicated Server page) gives a tick rate of 15 to 60, default 15 (for comparison).
  - **Borrowed:** rubber-banding is the visible symptom of client movement the server never applied. It is the probe's metric ("snaps").
  - **Rejected:** a lower send rate with intents bundled (for example 15 or 30 Hz). It adds up to one send interval before the host sees an input, and it does not change the throttle's odds, which are per packet. Redundancy (D2) already makes each packet carry several intents.
  - **Rejected:** an option to turn prediction off. Players should not have to choose between two kinds of lag.
- **Godot docs** (high-level multiplayer "Transfer modes" and "Channels"; `ENetPacketPeer.throttle_configure`, `PEER_PACKET_THROTTLE*`, `PACKET_THROTTLE_SCALE` = 32):
  - Unreliable-ordered drops a packet that arrives after a newer one.
  - Channel 0 is really one channel per mode.
  - The throttle is the probability, out of 32, that an unreliable packet is sent at all.
  - The docs name no mode for movement input. They say to send intents, not positions, and to rate-limit them.
  - **Borrowed:** intents, never positions; a host-side rate limit.
  - **Rejected:** a separate channel for intents. Unsequenced unreliable packets have no per-channel order to protect, so a channel buys nothing, and it would need a channel count in `NetPeers`.

**D2. How intents survive loss (decision Q1).** Each client message carries the newest intent and up to 7 earlier unacknowledged ones, as packed arrays: first `seq`, directions, flags, deltas. The message is sent unreliable (unsequenced). The host checks and applies it in this order:
1. It drops the whole message if it is empty, holds more than 8 intents, has arrays of different lengths, starts below 1, or holds any intent that fails `is_valid_intent`. A corrupt message never applies in part.
2. It walks the numbers from oldest to newest and skips each one not newer than the body's last queued one, so a repeat is never charged.
3. It charges the limits for each new one.
4. It queues it.

The cap of 8 covers 7 lost packets in a row (117 ms). On the probe's 100 ms relay a client usually has 7 or 8 unacknowledged intents. Up to 8 intents of about 17 bytes each (`Vector2` direction, a flag byte, a `float64` delta) is roughly 8 KB/s per client at 60 Hz.

The host's own player (and solo) sends a message of one intent, applied on the same frame through `call_local` as today. `rebind` already clears the buffer, so a rejoined client starts from 1 with no stale copies.

Options for Q1 (recommended first):
- (a) **Redundant unreliable**, as above. It covers loss and a thinned throttle, and it works on ENet, Steam and EOS alike (it answers net-platform-seam Q5 with that design's recommended direction).
- (b) **Reliable on its own channel.** Nothing is lost and the code change is smallest. But each loss stalls this player on the host for a resend (about one and a half round trips) and then bursts, which the limits must absorb. Teammates see that player pause and jump.
- (c) **Net-platform-seam Q5(a) only:** unreliable, one intent per message, stale numbers dropped. It fixes Steam's and EOS's reliable mapping, but every lost or thinned packet still costs a frame of movement.

**D3. ENet's throttle (decision Q2).** On the host, as soon as a client connects (`peer_connected`), call `throttle_configure(5000, 2, 0)` on that connection, as `NetHarness._unthrottle` does.
- ENet sends the setting to the client, so the client's own sends stay open too.
- It must happen at connect: set after the join request, it left the join's 28/32 in place for 6 s (sustained-load rows). Set at connect, the client never left 32/32 (batch 3).
- Our traffic is a few kilobytes a second each way, so ENet's congestion control protects nothing here and costs intents and host states.
- Built as `EnetBackend.keep_throttle_open(peer)`, called by `EnetBackend.host()` and by `NetHarness`. It connects to the server peer's own `peer_connected` through a weak reference, so the signal does not keep the peer alive.

Options for Q2 (recommended first):
- (a) **Keep the throttle open** on every game connection. Built in the seam's `enet_backend.gd` after `net-platform-seam` merged, as the coordinator asked.
- (b) **Keep ENet's defaults** and rely on D2 alone. That covers a throttle down to 6/32 completely, but not the deep fall the art-pass logged (0/32: 31 packets dropped in a row). Host states to the client, which carry no copies, stay thinned too (the PR #43 rejoin flake).

**D4. Rate-limit headroom (decision Q3).**
- `PeerLimits`:
  - Intent burst 30 → 90.
  - Simulated-time slack 0.25 s → 1.25 s.
  - Refill unchanged at 1.0 s per s.
- `PlayerNet.MAX_QUEUED` 60 → 90. The limits now admit up to 75 intents in one poll, and `enqueue` silently drops the oldest beyond the queue's size. The machine's own load produced a 1.09 s stall (65 intents) in one trial.

A token bucket absorbs a backlog only up to its capacity, so a 1 s host frame needs more than 1 s of slack. The host's clock runs during the hitch, so the bucket is back at its slack when the backlog arrives. After a 1 s hitch, 0.25 s of headroom is left for jitter, which is today's whole slack.

A cheating client gains at most one extra 1.25 s of movement (5 tiles) and no lasting speed. Today's bound is 0.25 s (1 tile).

Today's numbers are the coop-networking proposal's provisional decision 6.

Options for Q3 (recommended first):
- (a) **Burst 90, slack 1.25 s, queue 90, refill unchanged**, as above.
- (b) **The same, plus refill 1.05 s per s.**
  - A hitch near or over 1.25 s leaves about one frame of headroom, and that never grows back at 1.0. At 1.05 the full slack returns within 25 s.
  - The price is a standing 5% speed allowance for a cheating client.
  - In the probe, one frame of headroom refused nothing over 30 s of ±20 ms jitter, so this is optional.
- (c) **Keep 0.25 s, burst 30 and queue 60.** Every host hitch over 0.25 s snaps clients back by the rest (37 px for 1 s).

**D5. The probe stays.**
- `game/tests/manual/intent_link_probe.tscn` and its header document the command lines. Batch 1's runs predate its `--requests-hz` option. Its `--transfer` option is gone, because it never worked.
- `tools/net/udp_relay.py` (delay, jitter, loss, reordering; in order unless told otherwise) is the batch 2 relay.
- Neither is run in CI.

## Risks / Trade-offs

- [More bytes per client message] → At most 8 intents, and fewer once acks arrive. That is about 8 KB/s up per client, far below any home uplink.
- [The throttle was ENet's protection against a congested link] → Our rates are fixed and small. A link too slow for them was already unplayable, and the host's 10 s silence timeout still drops a dead peer.
- [A cheating client gains one 5-tile jump (and 5% speed with Q3(b))] → Accepted for a 1 to 4 friend co-op game. The rate limits exist to stop teleports and floods, which they still do.
- [Two unordered messages can arrive swapped] → The host takes each number once, the first time it arrives, so order does not matter.
- [Other sessions edit `coop_session.gd`] → The edits stay inside `send_intent`, `submit_intent` and `_receive_intent`, and that RPC's name changes. Merge order is checked before the PR.

## Migration Plan

The protocol changes for clients and hosts together: the old `submit_intent` is gone. Both sides run the same build, as for every change so far, and there is no version handshake yet. Rollback is reverting the change.
