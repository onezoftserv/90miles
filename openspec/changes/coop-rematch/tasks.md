# Tasks

Groups 1 to 4 follow the owner's answers of 2026-11-14: option A for each of Q1 to Q4 (design.md).

## 1. The host's call (coop-networking "Rematch is the host's call")

- [x] 1.1 Tests first in a new `test_run_rematch.gd`:
  - `call_party()` returns false on the offline peer and sends nothing.
  - On a host with a connected client, it reaches the client's `RunRematch`, which emits `called` once.
  - `begin()` called locally on the client (no sender) is ignored.
  - `begin()` on the host itself is ignored.
  - A client's `call_party()` returns false.
  - Host plus client on two branches, each with a `RunRematch` named `Rematch`.
  - Verify: seen failing (no class), then passing.
- [x] 1.2 Add `game/scripts/net/run_rematch.gd` (`RunRematch`, design D2): `called`, `call_party()`, and the `begin` RPC with its sender checks. Verify: 1.1 passes.

## 2. Look slots kept (art-pass "Look slots in a rematch", design D6)

- [x] 2.1 Tests first in a new `test_look_slots_rematch.gd`, with `CoopSession` on the offline peer and `_add_player`, as `test_look_slots.gd` does:
  - A kept slot is given whatever the spawn order.
  - A held slot is not given twice.
  - A newcomer skips a slot kept for a connected peer not spawned yet.
  - A kept slot of a peer that is not connected is free.
  - `look_slots()` maps the host and every connected peer with a body, and nothing on a client.
  - 1 player, offline: a solo session with nothing kept gives slot 0.
  - Verify: seen failing, then passing.
- [x] 2.2 In `coop_session.gd`, add the host-only `carried_looks`, `look_slots()`, and the slot pick in `_add_player` and `_free_look_slot`. Edit no other function. Verify: 2.1, `test_look_slots.gd` and `test_coop_reconnect.gd` pass.

## 3. The shell's rematch (endings-progression, ui-shell, coop-networking, design D3, D4, D9, D11)

- [ ] 3.1 Add `game/tests/helpers/shell_harness.gd` (`ShellHarness`). It runs real shells for a host and clients, each in its own branch with its own `SceneMultiplayer`. The peers are installed on the branch and `_on_hosting()` and `_on_joining()` are called directly. Every shell is named `Shell`, settings are per peer, and `teardown()` ends each run before closing its peer. Verify: a host and a client meet in the lobby with no engine error (the first case of 3.2).
- [ ] 3.2 Tests first in a new `test_coop_rematch_net.gd`, host plus client on `ShellHarness`:
  - **Two players again:** after a run that ended, the host's summary has "Otra vez" focused and the client's has only "Volver al inicio" with "Esperando al anfitrión…". The host picks it, and both reach the lobby listing Yuni (anfitrión) and Papo. The client's peer object is the same and opened no new connection. The host's registry has Papo's id under his peer.
  - **The new island is whole:** after "Empezar viaje", the client's pick-up and creature counts equal the host's. Each player keeps their look slot. Both peers have the same new `run_seed`, different from the old one. Day 1, full meters, no removed player, 1 island.
  - **A client still in its run:** the host calls while the client's flow is RUN. The client reaches its lobby.
  - **The host starts at once:** the host calls and begins the run in the same frame. The client enters the run with a HUD.
  - **A client who left:** with two clients, one goes back to the title and the host then calls. The new roster has the host and the other client only, and the one who left stays on the title.
  - **Old messages:** the client's old session sends an intent, an action and a site-state request just before the host's call. The host's lobby stays unchanged and spawns no body.
  - **The same looks again:** a removal and a join give Papo slot 2 and Dayana slot 1. After the rematch, with Papo answering first, they keep 2 and 1.
  - Verify: seen failing, then passing, with no engine error (GUT fails on them).
- [ ] 3.3 Tests first in `test_run_restart.gd`:
  - `test_a_co_op_summary_offers_only_home` becomes "a host alone gets Otra vez": 1 player hosting on port 0 sees "Otra vez" focused. It leads to a lobby with only the host and "Empezar viaje". The server peer and NetManager's request are unchanged, and the old session is freed.
  - New: a client's summary shows the waiting note and no "Otra vez", and the host-left note still replaces it.
  - New, 1 player offline: "Otra vez" sends no call and starts the solo run at once (the existing solo cases stay).
  - Verify: seen failing, then passing.
- [ ] 3.4 Build it:
  - `SummaryScreen.show_waiting_for_host()`.
  - In `game_shell.gd`: the `Rematch` child, the host's `_rematch()` (D3 order: looks, `_end_run()`, `call_party()`, `_on_hosting()` with the looks), and the client's `_on_rematch_called()`, which rebuilds at once and shows its lobby (D4).
  - The co-op summary buttons and note, solo kept on `_restart_solo()`.
  - Verify: 3.2 and 3.3 pass, as do `test_game_shell.gd`, `test_run_summary.gd`, `test_shell_platform.gd`, `test_shell_join_rules.gd`, `test_lobby_net.gd` and `test_shell_sky.gd`.
- [ ] 3.5 Import (twice), smoke run and GUT pass. Verify: the import's second pass has 0 error lines, smoke is clean, and GUT is all green with `test_suite_integrity.gd`.

## 4. Two processes (CLAUDE.md: host plus client before merging networking)

- [ ] 4.1 Add `game/tests/manual/coop_rematch_run.gd`, after `dead_spectate_run.gd`. It runs the real shell in two headless processes on UDP 7792. The host Yuni and the client Papo meet in the lobby, start, and die. Yuni picks "Otra vez". Both reach the new lobby with the same names, then start again. Papo checks:
  - his peer id is unchanged;
  - his pick-ups and creatures equal the host's (sent by the host as a line);
  - his look slot is kept;
  - his `run_seed` is new;
  - his log has no engine error.
  - Each check prints `REMATCH PASS|FAIL`.
  - Verify: both processes exit 0 with every check passing.
- [ ] 4.2 Docs: in `TASKS.md` §4, tick the rematch line, note the ui-shell "Run summary" rewrite on its line, and add any follow-up found. Verify: `openspec validate coop-rematch --strict` passes.
- [ ] 4.3 Import (twice), smoke run and GUT pass on the final tree. Verify: as in 3.5.

## Workflow follow-up

- Open the PR into `main` and send the link to the coordinating session when CI is green.
- Archive the change after the owner's review, keeping the archived specs' wording.
