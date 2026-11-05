# Tasks

Each group is written test-first: its tests are committed failing (RED), then the code that passes them (GREEN).

## 1. Pure building blocks

- [x] 1.1 Add `RateLimiter` (token bucket with an injected clock) and verify GUT tests for burst, refill, fractional amounts and the "60 intents of 0.1 s within 1 s → 1.2 s accepted" case
- [x] 1.2 Add `PredictionBuffer` (numbered intents with their deltas, acknowledge up to a seq) and verify GUT tests for numbering, acknowledging, out-of-order acknowledgements and the stored intent being a copy
- [x] 1.3 Add `SnapshotInterpolator` and verify the spec scenario (states at 0 s → x 0 and 0.05 s → x 1 tile, sampled 100 ms behind 125 ms → x 0.5 tiles) plus clamping before the first and after the last state
- [x] 1.4 Add `MovementModel.get_state()`/`set_state()` and verify a GUT test that a model restored mid-dive continues the dive exactly like the original
- [x] 1.5 Verify the import, smoke run and GUT pass with zero error lines

## 2. Player body and its net component

- [x] 2.1 Split `PlayerBody._physics_process` into `advance(delta, with_interaction)` behind `auto_advance`, and verify every player-movement test still passes plus a test that `advance(delta, false)` moves the body without starting an interaction
- [x] 2.2 Add `PlayerNet` with `role_for()` and the HOST role (queued intents stepped one by one with their own deltas, acknowledged seq, downed bodies advancing per frame), and verify GUT tests for the role table, the queue and the shadow fields
- [x] 2.3 Add the PREDICTED and REMOTE roles against a recording stand-in session, and verify GUT tests for "own player responds at once", "correction from the host" (exact replay of unacknowledged intents), "downed player is not predicted" and remote interpolation
- [x] 2.4 Add `PlayerNet` and the `StateSync` synchronizer to `player.tscn` and verify a GUT test that it replicates the seven shadow fields at 0.05 s, with authority set by the spawn rule, and that the movement playground still behaves as before
- [x] 2.5 Verify the import, smoke run and GUT pass with zero error lines

## 3. NetManager and the session over ENet

- [ ] 3.1 Add `tests/helpers/net_harness.gd` (one `SceneMultiplayer` branch per peer, ENet on port 0, ordered teardown) and verify a GUT test that a host and a client connect and tear down with no engine error
- [ ] 3.2 Fill `NetManager` (peer factory, `host`, `join`, `start_solo`, `leave`, signals, relay off) and verify GUT tests that solo opens no port, hosting binds the requested port and joining a closed port emits `join_failed`
- [ ] 3.3 Add `CoopSession` (players and entity spawners, spawn points, world state on join, the four-player cap) and verify integration tests for "second player joins mid-island", a late joiner receiving existing bodies and a registered entity, and "fifth player refused"
- [ ] 3.4 Add the intent RPC with its host-only guard and sender mapping, and verify integration tests that a client's intents move its body on the host, that "client acts as a teammate" moves only the sender's body, that "client claims an item it is not near" leaves the coconut, and that a client's prediction equals the host's state exactly after idle and after a forced correction
- [ ] 3.5 Add the host-to-client authority checks and verify the "client forges a host message" integration test
- [ ] 3.6 Verify the import, smoke run and GUT pass with zero error lines

## 4. Disconnects

- [ ] 4.1 Add the disconnect countdown and removal announcement, and verify an integration test that a dropped client's body is downed, still present after 89.9 s, removed from every peer after 90 s, and announced with its last position
- [ ] 4.2 Add the host-lost path and `scenes/ui/host_lost_screen.tscn`, and verify an integration test that a client whose host closes emits `host_lost`, frees its players and logs no engine error
- [ ] 4.3 Verify the import, smoke run and GUT pass with zero error lines

## 5. Rate limits in the session

- [ ] 5.1 Wire the three per-peer buckets into the intent and quick-chat handlers with the session clock, and verify GUT tests for "client claims extra time" (at most 5 tiles) and an intent flood over 30 at once being cut to the burst
- [ ] 5.2 Verify the import, smoke run and GUT pass with zero error lines

## 6. Quick chat

- [ ] 6.1 Add `game/resources/dialogue/quick_chat.tres` (8 lines, Spanish and English) and verify a GUT test of its phrases and order and a clean content validation in the smoke run
- [ ] 6.2 Add the `quick_chat` input action and `QuickChatWheel` with `slot_for()`, and verify GUT tests for the 8 sectors, the dead zone and the wheel showing the phrase file's text
- [ ] 6.3 Add the quick-chat RPCs and `SpeechBubble`, and verify integration tests for "shark warning" (bubble over the speaker on every peer, voice clip looked up by line id), "quick-chat spam" (3 then one after 2 s) and "rewording a phrase"
- [ ] 6.4 Verify the import, smoke run and GUT pass with zero error lines

## 7. Dev playground and checks

- [ ] 7.1 Add `scenes/dev/coop_playground.tscn` (movement playground terrain, session, `--host`/`--join`/`--solo` arguments, Host/Join panel with the port-forwarding note, host-lost screen) and verify it loads in the smoke run and a GUT test that the arguments parse
- [ ] 7.2 Run a host and a client as two local processes on the playground and verify from their logs that the client joins, both see two players and neither logs an error
- [ ] 7.3 Verify the import, smoke run, GUT and a 300-frame game run all pass with zero error lines

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Tick the `coop-networking` line in `TASKS.md` §3 and add a Done entry.
- Open the PR against `main` and get CI green.
- Archive the change after the PR review and after the user answers the provisional decisions in proposal.md.
