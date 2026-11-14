# Tasks

Every group ends with the import (twice on a fresh checkout), the smoke run and GUT passing:
- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`

Every new suite that swaps the backend:
- asserts `NetManager.backend is EnetBackend` in `before_all` and `after_all`;
- in `after_each`, calls `NetManager.leave()`, then `NetManager.use_backend(null)`, then `FakeNetBackend.reset()`.

No existing file under `game/tests` is edited.

## 1. Baseline

- [x] 1.1 At the branch point, run the import twice, the smoke run and GUT. Record the GUT script, test and assert counts here.
  - Done 2026-11-14 at ca6a2a8 (branch point 528e2a5 plus docs only): import ×2 clean; smoke "10 frames, 0 problem(s)"; GUT 173 scripts, 1543 tests, 1543 passing, 54547 asserts, 0 failing, 61 deprecation notices, no leak at exit.

## 2. Value types, data and the ENet backend (tests first)

- [x] 2.1 Write `game/tests/unit/test_net_backend_table.gd`:
  - the shipped table loads and defaults to ENet;
  - profile ids are unique, and every profile's script loads by path to a `NetBackend`;
  - the ENet profile has `join_timeout_s` 0 and a lobby note containing "%d";
  - every reason except NONE and CANCELLED has a Spanish and an English line;
  - the ENet lines match the screens:
    - UNREACHABLE is `JoinScreen.FAILED`;
    - PORT_UNAVAILABLE with [7777] is "No se pudo abrir el puerto 7777.";
    - HOST_LEFT is the host-lost screen's text;
  - English is picked when asked;
  - `pick` prefers a present feature tag, then the default (in-memory tables with an injected `has_feature`);
  - a missing default or a bad script still gives ENet.
  - Done 2026-11-14: 13 tests, 110 asserts. Beyond the list:
    - each line sits on its own reason;
    - a line given no arguments shows as written;
    - an unreadable or wrong-type table gives ENet;
    - every load is a copy (see design.md "Changes from the build plan").
- [x] 2.2 Write `game/tests/unit/test_enet_backend.gd`:
  - host is READY before it returns, with an ENet server, `info.port` equal to `NetPeers.bound_port`, and LAN-only addresses;
  - a taken port fails with PORT_UNAVAILABLE, `reason_args == [port]` and no peer;
  - join is READY and CONNECTING at once, even with nobody at 127.0.0.1:7999;
  - `check_target` refuses "", "   ", port 0, port 65536 and a token target;
  - `--connect=10.0.0.5:7780` reads as written; `--connect=10.0.0.5` gives port 7777; `--connect=`, `--connect=h:0` and no flag give null;
  - the root peer stays offline when `EnetBackend.host()` is called directly.
  - Done 2026-11-14: 12 tests, 87 asserts.
    - The test stands in for `NetManager`: it settles each answer READY or FAILED (design.md "Changes from the build plan").
    - The taken port consumes ENet's own "Couldn't create an ENet host" engine error with `assert_engine_error`.
    - Beyond the list: an answer is given once; a peer for a cancelled request is closed; a reason of NONE becomes UNSUPPORTED; the base backend's safe defaults; join targets.
- [x] 2.3 See 2.1 and 2.2 fail. Then add, each with its committed `.uid`:
  - `game/scripts/net/net_failure.gd`
  - `net_join_target.gd`
  - `net_host_info.gd`
  - `net_request.gd`
  - `net_backend.gd`
  - `enet_backend.gd`
  - `net_backend_profile.gd`
  - `net_backend_table.gd`
  - Done 2026-11-14.
    - Red first: each suite run alone (`-gconfig= -gtest=<file>`) stopped at a parse error (`NetRequest`, `NetJoinTarget` and `EnetBackend` not found). GUT printed "Nothing was run" and still exited 0, which is why the 2.6 counts are the evidence.
    - Then the eight scripts went in, with `.uid` files from the import.
- [x] 2.4 Add `game/resources/net_backends.tres`:
  - `default_id &"enet"`;
  - one ENet profile with `feature_tag ""`, `join_timeout_s 0` and the [es, en] lobby note;
  - the [es, en] failure lines from design.md.
  - Done 2026-11-14: inline ENet profile with the script by path. The eleven lines are keyed by `Reason` value; `test_each_line_sits_on_its_reason` checks the keys.
- [x] 2.5 In `NetPeers`, add `lan_addresses(all)` and the doc-comment edit. Make `LobbyScreen.local_addresses()` forward to it.
  - Done 2026-11-14: `net_peers.gd` gains only `lan_addresses` and the doc comment. `test_lobby_screen.gd` passes unchanged: 9/9 run alone.
- [x] 2.6 2.1 and 2.2 pass. Run the import, smoke and GUT.
  - Done 2026-11-14:
    - Import ×2 clean; smoke "10 frames, 0 problem(s)".
    - GUT: 175 scripts (baseline +2), 1568 tests (+25), 1568 passing, 54766 asserts (+219), 0 failing, no leak at exit.
    - The new suites account for 197 of the added asserts. The other 22 come from existing suites; not traced per suite.
    - `test_net_manager.gd` passes 8/8 alone. `NetManager` and `GameShell` are unchanged.

## 3. NetManager through the backend (tests first)

- [x] 3.1 Write `game/tests/helpers/fake_net_backend.gd`:
  - `defer_frames`, `refuse_host`, `refuse_join`, `answer`, `deliver_after_leave`, `start_failure` and `launch`;
  - `calls` and `poll_count`;
  - a static lobby table of token to ENet port, with `make(timeout_s)`, `reset()` and `accept_invite(target)`.
  - Done 2026-11-14, with its `.uid`. It compiles in the red run and is driven by `SceneTree.process_frame`. Beyond the list (design.md "Changes from the build plan"): `offered` and `last_offered()`, `open_lobby(port)` and `has_lobby(token)`, address targets, and `reset()` closing every peer a fake opened.
- [x] 3.2 Write `game/tests/unit/test_net_requests.gd`. It starts with three 1-player offline tests:
  - solo never touches the backend: a refusing fake with a start failure, then `start_solo()`, gives the offline peer, unique id 1 and `is_server()`, and `calls` holds only "start";
  - a late peer after going solo is closed;
  - a startup failure refuses host and join, but not solo.

  Then:
  - a pending host installs nothing until it is answered, then `hosted` fires before `settled`, with an ENet server and the relay off;
  - asking again cancels the pending request;
  - leaving cancels and calls "leave";
  - a join nobody answers times out (profile 0.3 s → `join_failed`, TIMED_OUT, offline);
  - late refusals carry a reason (host NOT_SIGNED_IN → `host_failed`, join FULL → `join_failed`, both offline with "leave" called);
  - refusals inside the call emit nothing;
  - an outside join is kept until taken, and `use_backend(null)` clears it;
  - poll runs while paused;
  - restoring the backend returns to ENet.

  See them fail.
  - Done 2026-11-14: 18 tests.
    - Red first: run alone (`-gconfig= -gtest=<file>`), the suite stopped at parse errors ("Cannot infer the type of "request" variable…": `request_host` and `request_join` did not exist yet). GUT printed "Nothing was run" and exited 0.
    - Beyond the list:
      - ENet requests are READY before they return;
      - a join by token connects to the lobby's port;
      - a join still connecting times out, and the watchdog stops once the host is reached;
      - transport failures carry UNREACHABLE and HOST_LEFT, with "leave" called;
      - the failure lines and the lobby note come from the table, in Spanish and English.
- [x] 3.3 In `NetManager`:
  - `request_host` and `request_join`;
  - `_go_offline` and `_on_answered` with the fixed ordering from design.md;
  - the watchdog and `poll`, with `PROCESS_MODE_ALWAYS`;
  - outside joins and `use_backend`;
  - `failure_text`, `lobby_note`, `host_info`, `pending_request` and `backend_profile`;
  - `host`, `join`, `start_solo` and `leave` kept as wrappers with their return codes;
  - the backend chosen once in `_ready` with `NetBackendTable.pick(OS.has_feature)`.

  Add no const, enum, preload, inner class or export.
  - Done 2026-11-14. Every old member, signal and return code is kept, and the file names no transport peer class and no `NetPeers` factory call. Small additions are listed in design.md "Changes from the build plan".
- [x] 3.4 3.2 passes. `test_net_manager.gd`, `test_coop_session_disconnect.gd` and `test_core_services.gd` pass unchanged. Run the import, smoke and GUT.
  - Done 2026-11-14:
    - Run alone, unchanged: `test_net_requests` 18/18 (195 asserts after the follow-up emit-count check; the full-run total below predates it), `test_net_manager` 8/8, `test_coop_session_disconnect` 8/8, `test_core_services` 10/10, `test_enet_backend` 12/12 and `test_net_backend_table` 13/13.
    - Import ×2 clean; smoke "10 frames, 0 problem(s)".
    - GUT: 176 scripts (+1), 1586 tests (+18), 1586 passing, 54964 asserts (+198), 0 failing, no leak at exit, no orphans in the new suite.
    - The new suite accounts for 194 of the added asserts. The other 4 come from existing suites; not traced per suite.
    - `GameShell` is unchanged. It still builds a client's run before `NetManager.join()`, so that run now sees one extra offline-to-offline peer swap. `test_shell_sky`, `test_lobby_screen`, `test_game_shell` and the NetHarness suites stay green.

## 4. Contract and seam (tests first)

- [x] 4.1 Write `game/tests/unit/test_net_backend_contract.gd`, with two branches that each have their own SceneMultiplayer with the relay off. Every case runs for `EnetBackend` and for `FakeNetBackend`:
  - the host is peer 1 and the client is 2 or more;
  - a reconnect is a new peer;
  - `disconnect_peer` closes the client;
  - the host closing reaches the client;
  - a bad target fails with no peer (INVALID_TARGET or NOT_FOUND);
  - a peer after leave is closed.
  - Done 2026-11-14: 12 tests (each case as an `_enet` and a `_fake` test sharing one helper), 116 asserts, 12/12 alone, no orphans and no engine errors.
    - A mutation run, with `NetRequest.succeed()` changed to leave a late peer open, failed both "peer after leave" cases (10/12). The source was restored afterwards.
    - Each branch is a `Machine` with its own backend that stands in for `NetManager`. The fake answers 3 frames late, keeps answering after `leave()`, and is joined by its lobby token from a second fake.
    - It also asserts `NetManager.backend is EnetBackend` in `before_all` and `after_all` and cleans up in `after_each`, though it never swaps the backend.
    - "A peer after leave": the ENet form, and what a mutation run showed, are in design.md "Changes from the build plan".
- [x] 4.2 Write `game/tests/unit/test_transport_seam.gd`:
  - It scans `res://scripts` and `res://scenes`, except `res://scripts/net/`, for `ENetMultiplayerPeer`, `SteamMultiplayerPeer`, `EOSGMultiplayerPeer`, `NetPeers.create_server`, `NetPeers.create_client`, `NetPeers.bound_port` and `IP.get_local_addresses`.
  - A self-check plants a name in an in-memory text, so the scan can't pass vacuously.
  - See the scan fail on `game_shell.gd`'s `IP.get_local_addresses()` until group 5.
  - Done 2026-11-14: 3 tests, 17 asserts.
    - `test_the_scan_catches_a_planted_name` plants each of the seven names and checks near misses give no hit. `test_the_scan_reaches_the_game_scripts` checks the walk reaches real files and skips only the seam. Both pass.
    - `test_no_transport_outside_the_seam` fails, as expected, with exactly one hit: `res://scenes/shell/game_shell.gd:180 IP.get_local_addresses`.
- [x] 4.3 Fix what fails; only the fake and the scan list should need work. Run the import, smoke and GUT; the seam scan is expected red until 5.2.
  - Done 2026-11-14: nothing needed fixing. The fake, the scan list and every non-test file are unchanged.
    - Import ×2 clean; smoke "10 frames, 0 problem(s)".
    - GUT: 178 scripts (+2), 1601 tests (+15), 1600 passing, 1 failing, 55102 asserts (+138), 55101 passing. The one failure is the expected seam-scan hit on `game_shell.gd:180`, which stays red until 5.2. No leak at exit, and no orphans in the new suites.
    - The new suites account for 133 of the added asserts. The other 5 come from existing suites, including the test_net_requests follow-up that the 3.4 total predates; not traced per suite.

## 5. Shell and screens (tests first)

- [x] 5.1 Write `game/tests/unit/test_shell_platform.gd`. It starts with three 1-player offline tests:
  - **Solo from the title with a broken platform:** use a fake with PLATFORM_UNAVAILABLE that refuses everything.
    - "Jugar solo" gives RUN with one body on the offline peer.
    - Death shows the summary, and "Otra vez" reaches RUN offline.
    - The backend gets no host or join call.
  - **Hosting alone on a slower backend:** defer 3.
    - First: LOBBY with `OPENING` and a null session.
    - Then the roster is the host alone.
    - "Empezar viaje" gives RUN with one body, and `can_pause()` is false.
  - **An outside join during a solo run waits for the title:** the run goes on offline with no "join". After `back_to_title()` and a frame, the shell sends the join, and the join screen is in connecting mode.

  Then:
  - **Salir while opening cancels.**
  - **Pressing host twice asks once.**
  - **A late host failure** returns to the title with its reason.
  - **A pending joiner never acts as host:** defer 5.
    - While pending: `shell.session` and `shell.island` are null.
    - After the answer: the session's `is_server()` is false, and the roster and `peer_ids()` are empty.
    - After 5 more frames: there is no `Creature` under `session.entities`.
  - **A launch argument joins after the title:** use the real `EnetBackend` with `--connect=127.0.0.1:<free port>`. The join screen shows the label, can't be edited and reads "Conectando…", and the session exists as a client.
  - **A failed outside join says why:** FULL shows "La partida está llena.".
  - **A join failure opens the join screen:** a NOT_FOUND token from the title shows "Esa partida ya no existe.".
  - **Volver cancels a pending join:** "leave" is called, a late answer is ignored, the session is null and the game is offline.
  - **The lobby names the port opened:** with real ENet on a probed free port.
  - **ENet wording is kept on a taken port:** the title shows "No se pudo abrir el puerto %d.".

  See them fail.
  - Done 2026-11-14: 13 tests, with its `.uid`.
    - Red first: run alone (`-gconfig= -gtest=<file>`), the suite stopped at a parse error (`Cannot find member "OPENING" in base "LobbyScreen"`). GUT printed "Nothing was run" and exited 0. The solo test alone would likely have passed on the old shell; the parse error is the only red seen.
    - The outside join during a solo run also checks the summary is not interrupted, and starts on "Volver al inicio" (the net-platform scenario).
    - Mutation run, after 5.2: with the outside-join guard always true and `_join_target` building the run before the request (the old order), 2 tests failed (11/13): the solo-run outside join and the pending joiner (session and island present while pending, and the session ran as host). The source was restored and the suite is 13/13 again.
- [x] 5.2 In `game_shell.gd`:
  - `_end_run()` before every request;
  - `_join_target`, and `_continue` as the one continuation;
  - `_on_hosting` and `_on_joining`;
  - the opening lobby and the repeat-press guard;
  - host and join failures with reasons, and the join screen opening on failure;
  - outside joins (taken at once on TITLE, SETTINGS, CREDITS or an idle JOIN, otherwise when the title next shows);
  - lobby addresses and the note from `NetManager`;
  - `IP.get_local_addresses()` removed.
  - Done 2026-11-14. Small choices are in design.md "Changes from the build plan" (group 5): `start_solo()` ends the run first, outside joins are taken on the next idle step, and a join failure that is not this shell's is ignored.
- [x] 5.3 In `join_screen.gd`, add `show_failed(text)` and `show_connecting(label)`. In `lobby_screen.gd`, add `OPENING` and `show_opening()`. No `.tscn` changes.
  - Done 2026-11-14. `show_failed("")` shows `FAILED`, and `show_failed` makes the field editable again after `show_connecting`. No `.tscn` changed.
- [x] 5.4 These pass, with no test file edited:
  - 5.1 and the seam scan;
  - `test_lobby_screen.gd`, `test_shell_sky.gd`, `test_run_restart.gd`, `test_game_shell.gd` and `test_title_screen.gd`;
  - the NetHarness suites.

  Run the import, smoke and GUT.
  - Done 2026-11-14:
    - Run alone, unchanged: `test_shell_platform` 13/13 (133 asserts), `test_transport_seam` 3/3 (the seam scan is green), `test_lobby_screen` 9/9, `test_shell_sky` 11/11, `test_run_restart` 6/6, `test_game_shell` 17/17, `test_title_screen` 6/6, `test_net_requests` 18/18 and `test_net_manager` 8/8.
    - Import ×2 clean; smoke "10 frames, 0 problem(s)".
    - GUT: 179 scripts (+1), 1614 tests (+13), 1614 passing, 0 failing, 55237 asserts (+135), exit 0, no leak at exit. The 30 NetHarness suites are in that run.
    - The new suite accounts for 133 of the added asserts. The other 2 come from existing suites (the seam scan has 17 asserts both red and green); not traced per suite.
    - Orphans are reported only by suites that had them before. `test_use_on_crossing`, `test_coast_cay_solo` and `test_crossing_solo` give the same counts with the HEAD shell; none come from `test_shell_platform` or the shell suites.

## 6. Docs

- [ ] 6.1 In `docs/GAME_DESIGN.md` §17, change the Multiplayer row to: "ENet by default behind a platform backend (net-platform); MultiplayerSpawner, MultiplayerSynchronizer". No numbers change.
- [ ] 6.2 In `TASKS.md`:
  - Add `net-platform-seam` under Milestone G (v1), noting that the owner chose the seam now and Steam in v2 (2026-11-14).
  - The v2 "Steam/relay joining" item stays, and gains a pointer to design.md's "Deferred to the Steam change".
- [ ] 6.3 Here, record the archive-time hand edit of the coop-networking Purpose line ("…through a platform backend (ENet by default).").
- [ ] 6.4 Run the import, smoke and GUT.

## 7. Verification

- [ ] 7.1 Check the diff against the branch point:
  - only `A` lines under `game/tests`;
  - `coop_session.gd`, `player_look.gd`, `net_harness.gd`, `coop_playground.gd` and `title_screen.gd` unmodified;
  - `net_peers.gd` gains only `lan_addresses` and the comment;
  - every old `NetManager` member name is still present.
- [ ] 7.2 Run the game through the Godot MCP (solo, host, back to the title) and read the errors: there should be none.
- [ ] 7.3 Do the manual host and client check with two local instances:
  1. Host from the title and join 127.0.0.1 from the join screen, in the lobby.
  2. Join once mid-run; the client's creature count matches the host's.
  3. Drop the client and rejoin within 90 s; the body is reclaimed.
  4. Close the host; the client shows the host-lost screen.
  5. Start a second instance with `-- --connect=127.0.0.1`.
  6. Repeat with `coop_playground -- --host` and `-- --join=127.0.0.1`.
- [ ] 7.4 CI is green on Linux with no Steam.
- [ ] 7.5 Run the import twice, smoke and GUT one final time. GUT equals the baseline plus the new tests, with 0 failures and 0 skipped scripts.

## Workflow follow-up

- Archive after the owner's review.
- **Later (v2):** the Steam change, built from design.md's "Deferred to the Steam change". Its questions Q3–Q7 go to the owner then.
- **Possibly earlier**, if the owner wants it: a small change for Q5 (`submit_intent` unreliable, with stale `seq` dropped on the host), tied to the open ENet throttle follow-up.
