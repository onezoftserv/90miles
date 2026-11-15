# Tasks

The groups follow option A of each owner question in design.md (Q1–Q4), all four chosen by the owner on 2026-11-14.

The commands below run from the repo root, using the Godot 4.7.2 console binary:
- "Import" is `godot --headless --path game --import`, run twice on a fresh checkout.
- "Smoke" is `godot --headless --path game -s res://tests/smoke.gd`.
- "GUT" is `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`.

## 1. Whom to watch (SpectateView, ui-shell "Whom a spectator watches", "Switching", "Losing")

- [x] 1.1 Tests first: write a new `game/tests/unit/test_spectate_view.gd`, offline, with an offline session plus extra bodies (`_add_player`, as in `test_run_hud.gd`). It covers:
  - 1 player, offline: a dead solo body never watches (`active()` false), and its camera stays its own.
  - The nearest living teammate is picked first.
  - "Next" and "previous" follow peer order and wrap round.
  - Dead teammates and `left_island` teammates are skipped.
  - A disconnected teammate is watched only when no connected one is, and is flagged as disconnected.
  - Losing the watched body to a death, to `left_island` or to a free moves the view to the nearest remaining teammate, or back to the own body when none is left.
  - A living, not-waiting body never watches.
  - A waiting rider (`left_island`) watches (Q4).

  Verify: the file fails to load first (no `SpectateView`), then passes.
  - Done 2026-11-14: 14 cases in `test_spectate_view.gd`, seen failing to parse with no `SpectateView`, then passing.
- [x] 1.2 Write `game/scripts/ui/spectate_view.gd` (`class_name SpectateView`, RefCounted, static typing) as design D4 and D5 describe:
  - `bind(session, local_peer, solo)`, `set_own(body)`, `update()`, `cycle(direction)`, `active()`, `watched()`, `watched_dropped()`.
  - Static helpers for the candidates, the nearest pick and the step.

  Verify: 1.1 passes.
  - Done 2026-11-14: `game/scripts/ui/spectate_view.gd`, with `watched_dropped()` in place of the planned flag.
- [x] 1.3 Cameras (D3), tests first in `test_spectate_view.gd`:
  - While watching, the own camera is disabled and the watched one enabled.
  - On stop, the watched camera is disabled and the own camera is enabled again.
  - After the watched body's `rebind()` (which calls `refresh_local()`), `update()` enables its camera again.
  - `make_current()` runs only when the watched body changes or its camera was off.

  Then build it. Verify: the camera tests pass. Finish the group with Import, Smoke and GUT clean.
  - Done 2026-11-14: the camera cases are in the same file. `make_current()` runs when the watched body changes, or when its camera is off or not current. Import 0 error lines, Smoke 10 frames 0 problems, GUT 1687 of 1687.

## 2. The HUD while watching (ui-shell "The HUD while watching")

- [x] 2.1 HUD text, tests first in `test_hud_text.gd` (or the existing HUD text test):
  - `HudText.LINES` gains `watching`, `watching_dropped` and `watch_keys`.
  - `hud_text.tres` holds "Mirando a: %s" / "Watching: %s", "Mirando a: %s (desconectado)" / "Watching: %s (disconnected)" and "[%s] [%s] Cambiar" / "[%s] [%s] Switch" (Q3).

  Verify: the test sees each line in both languages.
  - Done 2026-11-14: `test_the_watching_lines` in `test_hud_text.gd`, seen failing on the missing keys, then passing.
- [x] 2.2 The step keys (Q1). Tests first:
  - D, →, the D-pad's → and the wheel down step to the next teammate; A, ←, the D-pad's ← and the wheel up step back.
  - Stick motion, a release and an echo do not step.
  - The line names "A"/"D" on the keyboard and "Cruz ←"/"Cruz →" on a gamepad.
  - `test_input_map_hud.gd` still finds no input bound to two project actions.

  Verify: the tests pass and Import is clean.
  - Done 2026-11-14, changed while building (design D7): the two planned actions `spectate_prev` and `spectate_next` would have put A, D, the D-pad and the wheel on two actions each, which `test_input_map_hud.gd` (inventory-hud "Inputs do not collide") refuses. Stepping now reuses `move_left`/`move_right`, `ui_left`/`ui_right` and `slot_prev`/`slot_next`, with the same keys as the owner chose, and `project.godot` is unchanged. The cases are in `test_spectate_view.gd`.
- [x] 2.3 `RunHud`, tests first in `test_spectate_view.gd` with the HUD bound (`solo = false`):
  - The `Watching` panel shows "Mirando a: Papo  [A] [D] Cambiar".
  - `hud.meters.shown()` is the watched teammate's meters.
  - The strip and the prompt are hidden.
  - A pressed step key steps the view.
  - The quick-chat wheel stays.
  - When watching stops, the own meters are back, the strip shows and the panel hides.
  - Solo: no panel ever shows.
  - A dead body's position does not change while A or D steps the view.

  Then build it: add the `Watching` HudPanel to `run_hud.tscn` (bottom band, centred), and the `SpectateView` in `bind` / `_bind_local` / `_on_player_rebound` / `refresh()`. `_input` steps on the walk, arrow and slot actions, and `InventoryStrip.watching` hides the strip. Verify: the tests pass, and `test_run_hud.gd`, `test_inventory_strip*.gd` and `test_interact_prompt*.gd` still pass.
  - Done 2026-11-14: 8 HUD cases in `test_spectate_view.gd`, written before the HUD code. They cover the line, the marked disconnected teammate, the step keys including the arrows, the D-pad and the wheel, a stick that does not step, landing, solo, a living player, and no key bound twice. They pass, as do `test_run_hud.gd`, `test_inventory_strip.gd`, `test_interact_prompt.gd`, `test_meters_hud.gd`, `test_hud_screens.gd` and `test_input_map_hud.gd`.
  - Found while building: `update()` passed a freed own body into a typed parameter, which the host-lost teardown would hit. It now checks `is_instance_valid` first, and `test_a_freed_own_body_watches_nobody` covers it.
- [x] 2.4 The 1-player shell test: in `test_game_shell.gd`, a solo run whose player dies reaches `Flow.SUMMARY` and the HUD never watched. Verify: it passes. Finish the group with Import, Smoke and GUT clean.
  - Done 2026-11-14: `test_a_solo_death_goes_to_the_summary_without_watching`. Import 0 error lines, Smoke 10 frames 0 problems, GUT 1697 of 1697.

## 3. Every peer (ui-shell "Spectating on every peer"), host plus clients

- [ ] 3.1 Tests first: write a new `game/tests/unit/test_dead_spectate_net.gd` on NetHarness, with a `RunHud` bound per branch as `test_dropped_teammate_net.gd` does. Cases:
  - The client dies and watches the host ("Mirando a: Yuni"), while the host's own view is unchanged.
  - The host dies and watches the client.
  - Papo's client drops, his body dies during the 90 s, and on his rejoin his HUD watches at once.
  - A late joiner who dies watches with the roster's name.
  - Papo is dropped and alone alive, so a dead Dayana's line reads "Mirando a: Papo (desconectado)", and the mark goes when he rejoins.

  The tests assert the watched body, `camera.enabled` and the line, never `is_current()`. Verify: they pass, and the cases that rely on group 1 or 2 were seen failing before those were built.
- [ ] 3.2 Write a two-process manual run, `game/tests/manual/dead_spectate_run.gd`. It boots the real `GameShell` with `--mode=host|client --port=7787`:
  - The host kills the client's player through the meters hook.
  - The client checks that its current camera belongs to the host's body and that the line reads "Mirando a: <host>".
  - The host dies, and both reach `Flow.SUMMARY`.

  It prints `SPECTATE PASS|FAIL` lines. Run host and client as two headless processes on UDP 7787. Verify: every line is PASS and there are 0 error lines in both logs.

## 4. Wrap-up

- [ ] 4.1 Update the docs:
  - `TASKS.md`: tick the Milestone G item and add a Done entry.
  - `docs/` (the HUD or co-op section that describes death): one line on spectating.
  - Note in the coast-cay follow-ups list that the waiting riders' camera has shipped (Q4).

  Verify: the files read correctly.
- [ ] 4.2 Final checks: `openspec validate dead-spectate --strict`, Import (twice), Smoke, GUT (full) and the group 3.2 run, all clean. Rerun a `test_crossing_art.gd` "scrolled sea" failure alone before treating it as ours. Verify: the counts are recorded in the PR body.

## Workflow follow-up

- Open a PR into `main` and report the link once CI is green.
- Archive with `/opsx:archive` after merge, with the owner's answers recorded.
