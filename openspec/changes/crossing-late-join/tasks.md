## 1. Snapshot and restore (offline)

- [x] 1.1 Write `test_crossing_snapshot.gd` (RED) and verify it fails. It covers: the round trip keeps every field, keeps maximum and value apart and keeps slot order; `from_dict` refuses each malformed field; a restore into a second session builds `Crossing<serial>` with the riders on sea ground, the camera kept to the sea, tied riders pinned and the host's positions; restoring twice keeps one node; a 1-player offline session restores at its elapsed time.
- [x] 1.2 Add `CrossingSnapshot` (`scripts/crossing/crossing_snapshot.gd`: `of`, `to_dict`, `from_dict`) and `Crossing.restore` / `apply_snapshot`, factor `receive_state`'s body into `_apply_state`, and verify 1.1 passes and the crossing suites (`test_crossing_*.gd`) and `test_reconnect_crossing.gd` stay green.
- [x] 1.3 Verify the import, the smoke run and GUT pass.

## 2. Recipients and the progress message

- [x] 2.1 Write `test_crossing_join.gd` over ENet with `NetHarness` (RED) and verify it fails. It covers: a late joiner mid-crossing gets the host's plan, elapsed time (within 1 s), states, maximum and value, rider positions, the later states and the result, with no engine error; a rider who drops and rejoins mid-crossing shows their own body tied in their slot on sea ground, camera kept to the sea and `departed` under the new peer; a late joiner learns `departed` without `route_started`; a peer still awaiting its join answer receives no crossing message. Add the 1-player test: a solo launch keeps no recipients and sends nothing.
- [x] 2.2 Add `Crossing._recipients` (seeded at launch, `share_with`) and send `receive_plan`, `receive_state` and `receive_result` by `rpc_id` to recipients still connected, and verify `test_crossing_net.gd` stays green.
- [x] 2.3 Add `IslandRoutes.send_progress` / `receive_progress` (departures replaced without a signal, `crossing_serial` raised to the host's, each snapshot restored, `progress_received` emitted) and the one call after `receive_lobby` in `CoopSession.request_join`, and verify 2.1 passes along with `test_coop_reconnect.gd`, `test_reconnect_routes.gd` and the lobby suites.
- [x] 2.4 Verify the import, the smoke run and GUT pass with no engine errors.

## 3. Shell

- [x] 3.1 Write the shell tests (RED: a restored crossing is tracked, keeps the run open and holds its riders when it ends; a departed rider with no crossing under way is held, with 1 player offline) and verify they fail.
- [x] 3.2 Connect `progress_received` in `GameShell._build_run` (track, connect `ended`, hold departed riders outside a crossing, check run over) and verify 3.1 passes.
- [x] 3.3 Verify the import, the smoke run and GUT pass, and a 300-frame shell run is clean.

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Add the `crossing-late-join` line to `TASKS.md` (Milestone B) and a Done entry.
- Once onezoftserv/90miles#9 merges: move the branch onto `main` (merge if #9 was merged, rebase `--onto origin/main 75b4f7c` if squashed, before any push for review), open the PR against `main` and get CI green. The user's other session merges it.
- Ask the owner to confirm the proposal's three decisions before archiving.
- Follow-up change: on clients a broken vessel's deck cells stay sand (`receive_state` sets `broken` without changing the terrain).
