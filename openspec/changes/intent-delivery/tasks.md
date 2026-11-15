# Tasks

The owner accepted the recommended answers to Q1 to Q3 on 2026-11-14 (design.md, "Owner decisions").
Groups 1 and 3 were built from `main`. Group 2 went into `game/scripts/net/enet_backend.gd` after `net-platform-seam` merged (e15369b, merged into this branch). Group 4 measures all three.

## 1. Redundant, unordered intents (Q1)

- [x] 1.1 Tests first:
  - `test_prediction_buffer.gd`: `newest(count)` returns the newest unacknowledged intents, oldest first, at most `count`, and none once they are acknowledged.
  - `test_player_net.gd`: a predicted body sends its newest intent plus up to 7 earlier unacknowledged ones each frame, then only the unacknowledged ones after an acknowledgement. A host-role body sends exactly one intent per frame. After a `rebind`, nothing from before it is sent again.
  - `test_coop_session_rate_limits.gd` (the host path, with a test clock):
    - A message carrying 38 to 42 after 40 queues 41 and 42 only, and charges the limits for those two.
    - A message arriving after a newer one queues nothing new.
    - A message with mismatched array lengths, more than 8 intents, or a non-finite value queues nothing.
  - `test_coop_session_solo.gd` (1 player, offline): over 60 frames each intent is applied once, on its own frame, and the body ends exactly where a body with no session ends.
  - Verify: the new tests are seen failing, then passing.
  - Done 2026-11-14: seen failing (`newest` and `MAX_INTENTS_PER_SEND` missing; the old three-argument send call), then passing.
- [x] 1.2 Build it:
  - `PredictionBuffer.newest(count)`.
  - `PlayerNet` hands the session a list of `PendingIntent`s: one for the host role, `newest(8)` for the predicted role. It exposes the last queued number to the host.
  - `CoopSession.send_intents` and `submit_intents`: `@rpc("any_peer", "call_local", "unreliable")`, sending the first `seq`, a `PackedVector2Array`, a `PackedByteArray` and a `PackedFloat64Array`.
  - `_receive_intents` checks each intent in turn: repeat, validity, limits, queue.
  - Delete `submit_intent`.
  - Verify: 1.1 passes, and so do `test_player_net.gd`, `test_coop_session_net.gd`, `test_coop_reconnect.gd`, `test_interact_prompt_net.gd` and `test_meters_net.gd`.
  - Done 2026-11-14: all of them pass, as do `test_player_state_sync.gd`, `test_net_harness_net.gd`, `test_dropped_teammate_net.gd` and `test_coop_session_disconnect.gd`.
- [x] 1.3 Host-plus-client test, new `test_intent_delivery_net.gd` on `NetHarness`:
  - A client walks east for 60 frames while the test drops 2 of every 3 of its sends at the client's `PlayerNet` send hook.
  - The host's body ends where the client predicted it, and no host state moves the client's body by more than 0.01 px.
  - Verify: it fails on the code before 1.2 (a client that sends one intent per message), then passes.
  - Done 2026-11-14: with `MAX_INTENTS_PER_SEND` set to 1 for the check, it fails (the host stepped 21.3 px of the client's 23.5, with corrections up to 4.3 px). With 8 it passes 3 of 3.
- [x] 1.4 Run the import (twice on a fresh checkout), the smoke run and GUT. Verify: the second import prints no `ERROR` line, smoke reports 0 problems, and GUT passes.
  - Done 2026-11-14: the import prints no `ERROR` line, and smoke reports "10 frames, 0 problem(s)". GUT runs 189 scripts and 1684 tests, all passing; its only `Parse Error` line is the content validator's deliberately broken fixture.

## 2. ENet's throttle kept open (Q2)

- [x] 2.1 After `net-platform-seam` merges, in `game/scripts/net/enet_backend.gd`, the host calls `throttle_configure(5000, 2, 0)` on each client connection when it connects. Tests first, in that backend's test file:
  - A server peer from the factory, once a client connects, reports deceleration 0 on that connection.
  - The client's connection to the host reports the same once the setting arrives.
  - A solo session creates no peer at all.
  - Verify: seen failing, then passing; `test_net_harness_net.gd` still passes.
  - Done 2026-11-14: `EnetBackend.keep_throttle_open`, called by `host()`. The tests are in `test_enet_backend.gd`; they failed with the constants alone (deceleration 2 on both ends), then passed.
  - `NetHarness` now uses the same helper in place of its own `_unthrottle`.
  - `test_enet_backend.gd` (15), `test_net_backend_contract.gd` (12), `test_net_harness_net.gd`, `test_intent_delivery_net.gd`, `test_interact_prompt_net.gd` and `test_coop_session_net.gd` pass.
- [x] 2.2 Run the import, the smoke run and GUT. Verify: as in 1.4.
  - Done 2026-11-14 on `main` at e15369b merged in: the import prints no `ERROR` line, smoke reports "10 frames, 0 problem(s)", and GUT runs 218 scripts and 1916 tests, all passing.

## 3. Rate-limit headroom (Q3)

- [x] 3.1 Tests first in `test_coop_session_rate_limits.gd`:
  - The constants: burst 90, slack 1.25 s, refill 1.0 s per s.
  - "Client claims extra time" (at most 9 tiles in 1 s).
  - "Client after a host hitch": 60 intents of 1/60 s arrive at one instant after 1 s of host time, and all are queued.
  - "Jitter after a hitch": after that backlog, 30 s of intents with ±20 ms of jitter; none is refused.
  - The existing over-budget and tiny-step cases are updated to the new slack.
  - Verify: seen failing, then passing.
  - Done 2026-11-14: seen failing on today's numbers (15 of the 60 backlog intents queued, 15 of 75 tiny steps, burst 30), then passing.
- [x] 3.2 Change the numbers in `PeerLimits` and update the doc comment, and raise `PlayerNet.MAX_QUEUED` to 90 (a test in `test_player_net.gd`: 75 intents queued at once are all stepped). Verify: 3.1 passes, and so does `test_coop_session_rate_limits.gd` as a whole.
  - Done 2026-11-14: `test_coop_session_rate_limits.gd` (14), `test_player_net.gd` (31), `test_coop_session_solo.gd` and `test_intent_delivery_net.gd` pass.
- [x] 3.3 Run the import, the smoke run and GUT. Verify: as in 1.4.
  - Done 2026-11-14: the import prints no `ERROR` line, smoke reports "10 frames, 0 problem(s)", and GUT runs 189 scripts and 1687 tests, all passing.

## 4. Measured again, two processes

- [x] 4.1 Re-run the probe conditions from design.md "Measurements" on UDP 7788, with the change. Note each in design.md beside the baseline.
  - Verify: calm, client-requests and host-hitch runs lose 0 intents.
  - Verify: a 1 s host frame refuses none and snaps the client by less than 1 px.
  - Verify: 2% relay loss loses at most the intents of runs longer than 7 packets.
  - Verify: no `ERROR` line in any log.
  - Done 2026-11-14 (design.md, "After the change"): 11 runs, all with 0 intents lost, 0 refused and 0 snaps, including 2% loss, 1% reordering and three 1 s host frames.
  - The client's throttle stayed at 32/32 throughout, and no log had an `ERROR` line.
- [x] 4.2 Host plus client with the co-op playground on UDP 7788 (`--host=7788`, `--join=127.0.0.1:7788`), both headless, for 60 s with the client walking. Verify: both logs have no `ERROR` line, and the client spawns and moves on the host.
  - Done 2026-11-14: `coop_playground.tscn` as host on 7788 and client from 127.0.0.1:7788, both headless and quitting themselves (`--quit-after`).
  - The client's player spawned on both, and the host logged its drop when the client quit. No `ERROR` line in either log.
  - The playground has no autopilot, so the walking check is 4.1's probe, which runs the same playground scene with the client walking a square.
- [x] 4.3 Update `TASKS.md`: tick the "ENet throttle on `submit_intent`" follow-up and add the dated entry. Verify: `openspec validate intent-delivery --strict` passes.

## Workflow follow-up

- Open the PR into `main` once groups 1 to 4 are done.
- Archive with `/opsx:archive` after the owner's review.
