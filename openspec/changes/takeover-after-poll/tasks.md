# Tasks

## 1. Takeover after the poll

- [x] 1.1 Tests first, in `game/tests/unit/test_coop_reconnect.gd` (NetHarness). Run each alone and see it fail:
  - A takeover in the run while the old copy still sends 4 intent messages a process frame, until it loses its connection: the second copy takes back the same body, the host closes the old connection, and the old copy loses its connection. GUT fails it on any engine error.
  - The same in the lobby: the roster lists Papo once, under the second copy.
  - A repeated join request: a silent client with Papo's identity sends its request twice in one frame while the old copy still sends. It takes back the body once and stays connected.
  - Done 2026-11-14:
    - Before the fix the suite ran 16/19. The three new net tests failed only on "Unexpected Errors", every one `Condition "!connected_peers.has(sender)" is true` (63 lines in all). The run test alone failed 3 of 3 with 9 lines.
    - Frame markers printed to stderr put every line after the takeover's close and before that frame's `process_frame`, so they all came in the poll that ran the takeover (design.md, Context).
- [x] 1.2 Test, offline with 1 player: a join request reaching a solo session is ignored, nothing is pending, and the one player keeps their body. Verify it passes before and after (a guard).
  - Done 2026-11-14: `test_solo_has_nobody_to_take_over`, checked through the session's signals (no `player_rebound` or `player_disconnected`), so it does not read private state. It passed before the fix and after.
- [x] 1.3 Implement design D2 and D3 in `game/scenes/net/coop_session.gd`:
  - `request_join` returns early for a peer in `_taking_over`. On TAKEOVER it adds the new peer and calls `_take_over` deferred.
  - `_take_over` erases the mark, then runs `_close_peer(old)`, `_on_peer_disconnected(old)` and `_answer_join`.
  - `_answer_join` is the unchanged tail of `request_join`.
  - Verify: 1.1 and 1.2 pass, and so does all of `test_coop_reconnect.gd`, `test_coop_session_disconnect.gd`, `test_coop_session_net.gd` and `test_identity_registry.gd`.
  - Done 2026-11-14:
    - Results: `test_coop_reconnect.gd` 19/19 in 3 of 3 runs, with no `ERROR` line. `test_coop_session_disconnect.gd` 8/8, `test_coop_session_net.gd` 10/10, `test_identity_registry.gd` 10/10.
    - D3 mutation: without the `_taking_over` check, the repeat test fails. The second copy takes itself over and is closed ("and stays connected"), and the host logs "Attempt to call RPC with unknown peer ID".
    - D2 alternative tried first: deferring only `_close_peer` passed the new test. It failed `test_back_before_the_host_noticed_takes_over` with 8 engine errors on the frozen client (design.md D2).
- [x] 1.4 Two processes on UDP 7791: a headless host and two clients with the same identity. The second client starts while the first is still connected and sending.
  - Run it against the code before 1.3 and see the engine error on the host.
  - Then run it with 1.3 and see none. Record the counts here.
  - Done 2026-11-14 with scratch scripts outside the repo:
    - `peer_run.gd` puts one `CoopSession` on the root multiplayer, over ENet with the game's default throttle.
    - `run3.sh` runs a host, client A joining at 1 s, and client B with A's identity joining at 4 s while A still sends.
    - Every process was ended by its own exit or by `timeout` on its own PID, and 7791 was free afterwards.
  - **Before the fix** (`coop_session.gd` from 23f1d24), `--max-fps 60`:
    - the host logged 2, 2 and 1 `connected_peers` lines in 3 of 3 runs, and they were its only `ERROR` lines.
    - 60 fps is about the game's drawn rate, so the old copy's intents pile up one per host poll. Uncapped runs before the fix were not repeated: the first launcher started the host's session before the root had its multiplayer, so that run does not count.
  - **After the fix:** 5 runs at 60 fps and 2 uncapped. Every run had 0 `ERROR` lines on the host, A and B. The host logged "rebound A → B", A logged "host lost", and B owned the body at the end. The host ended with players `[1, B]`.
  - **Again after merging main at 8f1eaae** (archive #53, intent-delivery #55, content batches). The host now opens ENet's throttle at connect through `EnetBackend.keep_throttle_open`, as the game does.
    - Before the fix (`main`'s `coop_session.gd`), 60 fps: the host logged 1, 2 and 2 `connected_peers` lines in 3 of 3 runs.
    - After the fix: 0 `ERROR` lines on all three processes in 7 of 7 runs (5 at 60 fps, 2 uncapped), each with the rebind, "host lost" on A and B owning the body.
- [x] 1.5 Import (twice), smoke run and full GUT pass with no new engine error lines. Record the counts against the branch point.
  - Done 2026-11-14 at f197076 (branch point bd9df3f):
    - Import ×2: exit 0, no `ERROR` lines.
    - Smoke: "10 frames, 0 problem(s)", exit 0.
    - GUT: 217 scripts, 1903 tests, 1903 passing, 65981 asserts, exit 0. No "Nothing was run", no leak at exit, no `connected_peers` line.
    - The log's other `ERROR` lines are the suite's expected ones, each asserted by its test: 5 forged RPCs refused, the content validator's broken fixture, and "Couldn't create an ENet host" ×3.
    - Against the branch point, `game/` changes only `coop_session.gd` and `test_coop_reconnect.gd` (+4 tests). GUT was not rerun at bd9df3f, so the baseline count is not measured here.
  - Again after merging main at 8f1eaae:
    - The burst helper now sends through intent-delivery's `send_intents`; `send_intent` is gone.
    - Import ×2: exit 0, no `ERROR` lines. Smoke: "10 frames, 0 problem(s)". `test_coop_reconnect.gd`: 19/19 with no `ERROR` lines.
    - GUT: 220 scripts, 1956 tests, 1956 passing, 66749 asserts, exit 0. No "Nothing was run", no leak, no `connected_peers` line.
    - The `ERROR` lines are the same expected set as above.
    - Against `origin/main`, `game/` differs only in `coop_session.gd` (the takeover hunk) and `test_coop_reconnect.gd`.
- [x] 1.6 `TASKS.md`: add and tick this change below the current milestone.
  - Done 2026-11-14: a line under Milestone B beside `structure-state-sync`, and an entry in Done.

## Workflow follow-up

- net-platform-seam was archived before this merged. Its open TAKEOVER item in `TASKS.md` §9 is ticked here, pointing to this change.
- Archive with `/opsx:archive` after the PR merges.
