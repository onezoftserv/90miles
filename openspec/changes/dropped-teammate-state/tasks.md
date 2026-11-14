# Tasks

Group 3 follows option A of design D3, which the owner chose on 2026-11-14.

## 1. Every peer knows who dropped (coop-networking)

- [x] 1.1 Tests first:
  - In `test_player_state_sync.gd`, the shadow field list gains `PlayerNet:net_dropped`, sent at spawn and replicated always.
  - A new `test_dropped_teammate_net.gd` runs a host and two clients, Dayana and Papo, on `NetHarness`.
  - When Papo drops, the host and Dayana both answer `is_dropped(papo)` true, and on the host `_dropped` and the body's flag agree.
  - A third client that joins during Papo's 90 s answers it true too.
  - When Papo rejoins within 90 s, it is false on the host, on Dayana and on the rejoiner, under his new peer.
  - Verify: the tests are seen failing, then passing.
  - Done 2026-11-14: `test_dropped_teammate_net.gd` (3 cases for the flag) and the field list in `test_player_state_sync.gd`; seen failing with the bare field (no peer set it), then passing.
- [x] 1.2 Add `net_dropped` to `PlayerNet` and the `StateSync` property in `player.tscn`. In `coop_session.gd`, `_on_peer_disconnected` sets the flag, `_reclaim` clears it, and `is_dropped` reads the body's flag on a client. Verify: 1.1 passes, and `test_coop_reconnect.gd`, `test_coop_session_disconnect.gd`, `test_death_cause.gd`, `test_death_cause_net.gd`, `test_status_flags.gd` and `test_art_sim_invariance.gd` still pass.
  - Done 2026-11-14: all of them pass, as do `test_run_hud.gd` and `test_difficulty_scaling.gd`.

## 2. The teammate state word (ui-shell)

- [x] 2.1 Tests first in `test_dropped_teammate_net.gd`, with the run HUD bound on each branch as `test_interact_prompt_net.gd` does:
  - Papo's row reads "Papo 100 Desconectado" on the host's HUD and on Dayana's, not "Caído".
  - A late joiner's HUD shows the same row.
  - After Papo rejoins within 90 s, his row on the host and on Dayana has no state word.
  - A Papo downed by his meters who drops and rejoins reads "Caído".
  - A dropped Papo whose meters die before removal reads "Muerto" on Dayana's HUD.
  - 1 player, offline: in `test_run_hud.gd`, a solo session's HUD shows no teammate row, and `is_dropped(1)` is false.
  - Verify: the tests are seen failing where group 1 is missing, then passing.
  - Done 2026-11-14: 5 HUD cases plus the solo case. Before group 1 they failed: Dayana and the joiner read 'Papo 100 Caído'. After it, all pass. The downed case downs Papo by the meters, with time left on the downed timer.
- [x] 2.2 No `run_hud.gd` change is expected, since `state_word` already ranks the words. If any 2.1 case still fails after group 1, fix it in `run_hud.gd`. Verify: 2.1 and all of `test_run_hud.gd` pass. Import (twice), smoke run and GUT pass.
  - Done 2026-11-14: no HUD change was needed. Import 0 error lines, smoke 10 frames 0 problems, GUT 1552 of 1552.

## 3. The short hold (escape-routes, design D3 option A, D4, D6)

- [x] 3.1 Tests first in `test_coast_cay_net.gd`:
  - "A removed player counts as dead" is updated: after the drop, `disconnect_time_left` is at most 30 s; the sandbar is still live just before 30 s; once 30 s pass, the coast cay loads and "Papo" is in `removed_names`.
  - New, "a dropped player back within the short hold plays on": Papo rejoins 20 s after the drop, his body stands, the sandbar stays live and the host still waits.
  - New, "a dropped rider in a crossing holds the load": the client in a crossing drops; its countdown is not cut and the sandbar stays live; when that crossing ends, the coast cay loads with both players.
  - New, "nobody waiting keeps the full hold": the host's player is dead and nobody has left; the client drops; its countdown is not cut, `check()` answers PLAYING on both peers before 90 s, and the run is not over.
  - New, "the waiting line": the host and Dayana wait and Papo drops on the sandbar; `GameShell.waiting_text` reads "En la orilla. Esperando a: Papo (desconectado)" for Dayana's branch.
  - 1 player, offline, in `test_coast_cay_solo.gd`: the crossing's end loads the coast cay at once, nothing is dropped and no countdown runs.
  - Verify: the tests are seen failing, then passing.
  - Done 2026-11-14. With a stub `DROPPED_HOLD_S` and a static `waiting_text` that marks nothing, these failed:
    - the removal case, at 90 s, not 30 s;
    - the waiting line, which read "Esperando a: Papo".
  - These passed as guards before and after:
    - the rejoin within the hold;
    - the rider in a crossing;
    - nobody waiting;
    - solo.
  - After 3.2, all of them pass.
- [x] 3.2 Make the changes:
  - `IslandTravel.check()` sorts each body as waiting, a dropped holder or playing (D4).
  - Add `DROPPED_HOLD_S = 30.0`.
  - `IslandTravel` re-checks on `player_disconnected`.
  - Add `CoopSession.shorten_drop(peer, at_most_s)`, host only.
  - Turn `GameShell._waiting_text` into a static `waiting_text(session)` that marks a dropped teammate (D6).
  - Verify: 3.1 passes, and `test_coast_cay_net.gd`, `test_coast_cay_solo.gd`, `test_crossing_join.gd` and `test_game_shell.gd` pass. Import (twice), smoke run and GUT pass.
  - Done 2026-11-14: those suites pass (12, 18, 7 and 17 tests). Import, smoke and GUT are the same run as 4.2's.

## 4. Arrivals past four bodies (D5)

- [x] 4.1 Tests first:
  - In the test file that covers `checked_arrivals` (or a new `test_arrivals_cap.gd`): `checked_arrivals` keeps 8 entries and refuses 9, and `checked_world_state` keeps a `waiting` list of 5.
  - Over `NetHarness`, a host and three clients. One client's crossing ends and it drops while waiting, and a fourth client joins. The other four then end their crossings, and the coast cay loads at once with all five bodies landed, not 90 s later.
  - Verify: the tests are seen failing, then passing.
  - Done 2026-11-14 in `test_arrivals_cap.gd`.
    - On the old cap the two unit cases failed, and the five-body case crashed the engine (signal 11).
    - Cause: a refused landing re-queued `_travel_when_idle` within the same deferred flush, forever (design D5).
    - With that loop fixed, the old cap fails cleanly: the coast cay never loads.
    - A fourth case, "a refused landing does not spin the host", guards the loop fix.
- [x] 4.2 Set `MAX_ARRIVALS` to `2 * MAX_PLAYERS`, and keep `_travel_queued` up while `_travel_when_idle` runs (design D5, found while applying). Verify: 4.1 passes, and import (twice), smoke run and GUT pass.
  - Done 2026-11-14:
    - `test_arrivals_cap.gd` 4 of 4.
    - Second import 0 error lines; smoke 10 frames, 0 problems.
    - GUT: 175 scripts, 1560 of 1561. The one failure is `test_crossing_art.gd` "the scrolled sea still covers the crossing's sea", which reads the sea after a wall-clock wait and is not touched here. It passed 3 of 3 alone and in the previous full run.

## 5. Integration

- [ ] 5.1 Run the import twice, the smoke run, the whole of GUT and `openspec validate dropped-teammate-state --strict`. Verify: 0 error lines from the second import, the smoke run passes, GUT passes in full, and validation is clean.
- [ ] 5.2 Run a host and two clients locally with `tests/manual/art_pass_run.gd` (headless). Verify:
  - While B is away, A's row for B reads "Desconectado".
  - After B's last leave, the coast cay loads within about 30 s, not 90 s.
  - Zero error lines in the three logs.
- [ ] 5.3 Update the records. Verify: the edits are in place.
  - Tick the two items in `TASKS.md`.
  - In `openspec/changes/art-pass-followups/tasks.md` "Still open", note that this change addresses the "Caído" row and the 90 s landing.

## Workflow follow-up

- Archive after the owner's review. `sign-note-panel` also modifies ui-shell "HUD layout"; this change adds a separate requirement, so the two archive in either order.
