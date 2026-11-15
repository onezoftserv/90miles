# Tasks

## 1. Takeover after the poll

- [ ] 1.1 Tests first, in `game/tests/unit/test_coop_reconnect.gd` (NetHarness). Run each alone and see it fail:
  - A takeover in the run while the old copy still sends 4 intents a process frame, until it loses its connection: the second copy takes back the same body, the host closes the old connection, and the old copy loses its connection. GUT fails it on any engine error.
  - The same in the lobby: the roster lists Papo once, under the second copy.
  - A repeated join request: a silent client with Papo's identity sends its request twice in one frame while the old copy still sends. It takes back the body once and stays connected.
- [ ] 1.2 Test, offline with 1 player: a join request reaching a solo session is ignored, nothing is pending, and the one player keeps their body. Verify it passes before and after (a guard).
- [ ] 1.3 Implement design D2 and D3 in `game/scenes/net/coop_session.gd`:
  - `request_join` returns early for a peer in `_taking_over`. On TAKEOVER it adds the new peer and calls `_take_over` deferred.
  - `_take_over` erases the mark, then runs `_close_peer(old)`, `_on_peer_disconnected(old)` and `_answer_join`.
  - `_answer_join` is the unchanged tail of `request_join`.
  - Verify: 1.1 and 1.2 pass, and so does all of `test_coop_reconnect.gd`, `test_coop_session_disconnect.gd`, `test_coop_session_net.gd` and `test_identity_registry.gd`.
- [ ] 1.4 Two processes on UDP 7791: a headless host and two clients with the same identity. The second client starts while the first is still connected and sending.
  - Run it against the code before 1.3 and see the engine error on the host.
  - Then run it with 1.3 and see none. Record the counts here.
- [ ] 1.5 Import (twice), smoke run and full GUT pass with no new engine error lines. Record the counts against the branch point.
- [ ] 1.6 `TASKS.md`: add and tick this change below the current milestone.

## Workflow follow-up

- Close net-platform-seam's "One error, attributed" note (its tasks.md 7.3) by pointing to this change, if that change is still open when this one merges.
- Archive with `/opsx:archive` after the PR merges.
