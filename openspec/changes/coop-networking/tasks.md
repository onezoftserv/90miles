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

- [x] 3.1 Add `tests/helpers/net_harness.gd` (one `SceneMultiplayer` branch per peer, ENet on port 0, ordered teardown) and verify a GUT test that a host and a client connect and tear down with no engine error
- [x] 3.2 Add `NetPeers` (the ENet factory, the default port and the player cap; autoloads hold no constants) and fill `NetManager` (`host`, `join`, `start_solo`, `leave`, signals, relay off), and verify GUT tests that solo opens no port, a server binds the requested port, hosting turns relay off and reports the port, and joining refuses a blank address or a bad port (a closed port only fails after ENet's connect timeout, too slow for a unit test)
- [x] 3.3 Add `CoopSession` (players and entity spawners, spawn points, world state on join, the four-player cap) and verify integration tests for "second player joins mid-island", a late joiner receiving existing bodies and a registered entity, and "fifth player refused"
- [x] 3.4 Add the intent RPC with its host-only guard and sender mapping, and verify integration tests that a client's intents move its body on the host, that "client acts as a teammate" moves only the sender's body, that "client claims an item it is not near" leaves the coconut, and that a client's prediction equals the host's state exactly after idle and after a forced correction
- [x] 3.5 Add the host-to-client authority checks and verify the "client forges a host message" integration test
- [x] 3.6 Verify the import, smoke run and GUT pass with zero error lines

## 4. Disconnects

- [x] 4.1 Add the disconnect countdown and removal announcement, and verify an integration test that a dropped client's body is downed, still present after 89.9 s, removed from every peer after 90 s, and announced with its last position
- [x] 4.2 Add the host-lost path and `scenes/ui/host_lost_screen.tscn`, and verify an integration test that a client whose host closes emits `host_lost`, frees its players and logs no engine error
- [x] 4.3 Verify the import, smoke run and GUT pass with zero error lines

## 5. Rate limits in the session

- [x] 5.1 Wire the intent-count and simulated-time buckets into the intent handler with the session clock, and verify GUT tests for "client claims extra time" (at most 5 tiles) and an intent flood over 30 at once being cut to the burst (the quick-chat bucket is wired and tested with the quick-chat handler in 6.3)
- [x] 5.2 Verify the import, smoke run and GUT pass with zero error lines

## 6. Quick chat

- [x] 6.1 Add `game/resources/dialogue/quick_chat.tres` (8 lines, Spanish and English) and verify a GUT test of its phrases and order and a clean content validation in the smoke run
- [x] 6.2 Add the `quick_chat` input action and `QuickChatWheel` with `slot_for()`, and verify GUT tests for the 8 sectors, the dead zone and the wheel showing the phrase file's text
- [x] 6.3 Add the quick-chat RPCs and `SpeechBubble`, and verify integration tests for "shark warning" (bubble over the speaker on every peer, voice clip looked up by line id), "quick-chat spam" (3 then one after 2 s) and "rewording a phrase"
- [x] 6.4 Verify the import, smoke run and GUT pass with zero error lines

## 7. Dev playground and checks

- [x] 7.1 Add `scenes/dev/coop_playground.tscn` (movement playground terrain, session, `--host`/`--join`/`--solo` arguments, Host/Join panel with the port-forwarding note, host-lost screen) and verify it loads in the smoke run and a GUT test that the arguments parse
- [x] 7.2 Run a host and a client as two local processes on the playground and verify from their logs that the client joins, both see two players and neither logs an error
- [x] 7.3 Verify the import, smoke run, GUT and a 300-frame game run all pass with zero error lines

## 8. Solo first-class and review fixes

- [x] 8.1 Add `test_solo_play.gd` (offline peer, no second peer, spawns at once, 10 s of running is 60 tiles and 5 energy, identical to a body with no session, never predicted or corrected, 120 frames at once all applied, interacts) and verify it fails before the host's own player skips the intent limits and passes after
- [x] 8.2 Count only connected players toward the cap, add peers that connected before `start()`, charge each intent at least one 1/60 s frame, ignore non-finite host states and spawn positions, forget unacknowledged intents when going down, and ignore a q typed into a text field; verify each with a GUT test that failed first (reconnect into a full session over ENet included)
- [x] 8.3 State the solo case in every requirement of the spec delta, add the solo scenarios, and list the rules that only make sense with 2+ players as questions in proposal.md; verify `openspec validate coop-networking --type change --strict`
- [x] 8.4 Verify the import, smoke run, GUT and a 300-frame game run all pass with zero error lines

## 9. Difficulty scaling and solo pause (approved 2026-11-05)

- [x] 9.1 Add `DifficultyScaling` and `CoopSession.island_difficulty()` (living, connected players; dropped and dead ones not counted) and verify GUT tests for 1 to 4 players, "solo island", "last survivor of four" and dropped players, failing before the code exists
- [x] 9.2 Add `CoopSession.can_pause()`/`set_paused()`, the `pause` action (Esc, gamepad Start) and `PauseMenu`, and verify GUT tests that solo pause freezes the players, the session, the weather clock and run state while the menu keeps running, that resuming runs them again, and that co-op and a host waiting alone cannot pause
- [x] 9.3 Put both rules and "solo uses the same base numbers" in the spec delta, record the decisions in proposal.md and design.md, and verify `openspec validate coop-networking --type change --strict`
- [x] 9.4 Verify the import, smoke run, GUT and a 300-frame game run all pass with zero error lines

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Tick the `coop-networking` line in `TASKS.md` §3 and add a Done entry.
- Open the PR against `main` and get CI green.
- Archive the change after the PR review and after the user answers the provisional decisions in proposal.md.
