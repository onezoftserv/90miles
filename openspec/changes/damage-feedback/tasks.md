# Tasks

The groups follow option A of each owner question in design.md (Q1–Q4), the recommended answers, pending the owner's choice. A different answer changes groups 3 to 5 only.

The commands below run from the repo root, using the Godot 4.7.2 console binary:
- "Import" is `godot --headless --path game --import`, run twice on a fresh checkout.
- "Smoke" is `godot --headless --path game -s res://tests/smoke.gd`.
- "GUT" is `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`.

## 1. Tuning data and the classifier (survival-meters "Hits and drains are told apart")

- [ ] 1.1 Tests first: write `game/tests/unit/test_hurt_watch.gd` (pure; 1 player, offline). It drives `observe(health, dead, delta)` by hand and covers:
  - the first observation, a rise, and every observation while dead return NONE;
  - an isolated loss of 5 is a HIT of 5, and a loss of 2.9 is a DRAIN;
  - 2/s thirst at 60 Hz and at 20 Hz steps is a DRAIN for 3 s;
  - 10/s drowning in 20 Hz steps, with one 0.5 s gap of 5, is a DRAIN;
  - 25 inside a 10/s drain is a HIT of about 25;
  - `reset()` makes the next observation a baseline;
  - the rate is forgotten after 1 s with no loss, so a later 5 is a HIT.

  Verify: it fails to parse with no `HurtWatch`, then passes.
- [ ] 1.2 Write `game/scripts/ui/hurt_cue_tuning.gd` (`HurtCueTuning`, a `Resource` with every number in design D3 to D5) and `game/resources/hurt_cue_tuning.tres`. Add `test_hurt_cue_tuning.gd`, which checks that the `.tres` loads with the values in the design. Verify: GUT.
- [ ] 1.3 Write `game/scripts/ui/hurt_watch.gd` (`HurtWatch`, `RefCounted`, NONE/HIT/DRAIN, `last_hit`, `reset()`), as design D3. Also write `game/scripts/ui/hurt_cues.gd` (`HurtCues`, holding the static `reduce_flashes` and the shared tuning). Verify: 1.1 passes.
- [ ] 1.4 Import ×2, Smoke and GUT pass.

## 2. Reduce flashes and the sound hook (ui-shell "Settings")

- [ ] 2.1 Tests first: extend the settings tests (`test_game_settings.gd`, or the one that covers `GameSettings` save and load). They cover:
  - `reduce_flashes` defaults to false;
  - it survives save and load;
  - an old file without the key reads false;
  - the settings screen's "Reducir destellos" box toggles it, saves, and sets `HurtCues.reduce_flashes`;
  - `GameShell` sets the static from loaded settings.

  Verify: they fail first, then pass.
- [ ] 2.2 Add `GameSettings.reduce_flashes` (`display/reduce_flashes`), the `ReduceFlashes` `CheckBox` in `settings_screen.tscn` and `.gd`, and the shell's write to `HurtCues.reduce_flashes` on load and change. Check that the settings panel still fits 640×360 in the existing layout test. Verify: 2.1 and the settings layout tests pass.
- [ ] 2.3 Add `AudioManager.play_sfx(id: StringName) -> void`, a documented no-op. Verify: GUT, with a call from a test that does not error.
- [ ] 2.4 Import ×2, Smoke and GUT pass.

## 3. Body cue (survival-meters "Hurt cue on the body")

- [ ] 3.1 Tests first: write `game/tests/unit/test_hurt_blink.gd`. It covers the pure `HurtBlink` state (white on the first frame, hidden at 10 Hz until 0.6 s, then clear; the tint with reduce flashes on), and a solo, offline `PlayerLook` on a body:
  - `meters.harm(5, &"land_crab")`, then stepping `look.step(1/60)` by hand: the shader's `hurt_white` is 1 on the first step, then `hurt_hidden` toggles, and everything is clear after 0.6 s;
  - thirst at 0 for 3 s of steps never sets them;
  - a dead body never sets them.

  Verify: it fails first, then passes.
- [ ] 3.2 Add `hurt_white`, `hurt_hidden` and `hurt_tint` to `player_look.gdshader`, applied after the water-line cut. Add the `HurtWatch` and `HurtBlink` to `PlayerLook.step`, with time from `delta` only: no Tween, Timer, await, RNG or `_enter_tree`. Verify: 3.1, and the existing art tests (`test_player_look*`, `test_crossing_art`, the look tests) still pass.
- [ ] 3.3 Extend `test_art_sim_invariance.gd`: in both runs, the nearest land crab pinches the player at a fixed frame through the host's own `CreatureWorld.pinch`, or `meters.harm` if no crab is in reach. The built run then asserts that the look's blink ran. Verify: the invariance test passes, and its bad-look guard tests still fail as they should.
- [ ] 3.4 Import ×2, Smoke and GUT pass.

## 4. Screen cue: edges, chunk, shake, glow, sound (ui-shell "Hit flash at the screen edges", "Lost health shows on the bar", "Drain glow on the health bar")

- [ ] 4.1 Tests first: write `game/tests/unit/test_hurt_screen.gd` (solo, offline, a `MetersHud` bound to one body's meters, stepped by hand). It covers:
  - a pinch of 5 shows the overlay, and it is clear 0.4 s later;
  - a bite of 25 shows it stronger than a pinch of 5;
  - two hits 0.1 s apart start one flash, not two;
  - with reduce flashes on, the overlay never shows and the bar never shakes;
  - the health bar's `Lost` part spans 75 to 100 after a bite of 25, holds 0.4 s, and is gone by 0.9 s;
  - the bar shakes for 0.2 s on a hit and never on a drain;
  - the glow shows while thirst drains and stops 1 s after the last loss, and a lone hit does not glow;
  - a rebind to other meters at 90 shows no `Lost` part and no flash;
  - `hurt_cued` fires `hurt_hit`, `hurt_big` and `hurt_drain` (once per drain);
  - the overlay is not counted by `RunHud.panel_rects()` and ignores the mouse.

  Verify: it fails first, then passes.
- [ ] 4.2 Write `game/scenes/ui/hurt_overlay.gd` and `.gdshader` (an edge-only red band) and add `HurtOverlay` to `meters_hud.tscn` beside `Blur`. Add the watch, the overlay strength and the gap, `hurt_cued` and the `AudioManager.play_sfx` calls to `MetersHud`, with `reset()` in `bind()`. Give `MeterBar` a `Lost` `ColorRect`, a `Glow` `Panel`, `shows_loss` (on for Health in `meters_hud.tscn` only), and `show_loss` and `step` for the chunk and shake. Keep the edits to these nodes only (HUD restyle in review). Verify: 4.1, `test_meters_hud.gd`, `test_run_hud*.gd` and the HUD layout tests pass.
- [ ] 4.3 Import ×2, Smoke and GUT pass.

## 5. Solo and co-op end to end

- [ ] 5.1 Write the solo test `game/tests/unit/test_damage_feedback_solo.gd`, with exactly 1 player, offline, `NetManager.start_solo()`, a sandbar session and its `RunHud`. It covers:
  - a land crab's `CreatureWorld.pinch` on the player blinks the body's look, flashes the HUD's edges and leaves a 5-point chunk on Salud;
  - thirst set to 0 for 3 s of host ticks glows the bar with no blink and no flash.

  Verify: it passes.
- [ ] 5.2 Tests first, in-process host plus client with `NetHarness` (as `test_status_net.gd`), written as `game/tests/unit/test_damage_feedback_net.gd`. Await only the sync, then step the cues by hand. It covers:
  - a crab pinch on the client's player, done on the host, flashes the client's HUD edges and blinks its own look, and the host's HUD does not flash;
  - a pinch on the host's player blinks the host's body on the client, with no flash on the client's HUD;
  - a late joiner who first sees a host at 60 health cues nothing on that body;
  - drowning on a client is a drain (no blink) while it lasts.

  Write the late-joiner case first. If it fails because spawn state lands late, add the `synchronized` baseline from design's Risks.

  Verify: it passes, and the GUT total stays under CI's 300 s.
- [ ] 5.3 Two processes: write `game/tests/manual/damage_feedback_run.gd` (host and client on UDP 7793, as `dead_spectate_run.gd`). The host pinches the client, and then the client's player drowns. The client asserts its HUD flash, its own blink and the drain glow, and the host asserts the client's body blinks. Run it 3 times. Verify: both processes report every check passing with 0 engine errors.
- [ ] 5.4 Import ×2, Smoke, GUT and CI's four headless game runs pass with 0 error lines.

## 6. Docs

- [ ] 6.1 Update `docs/GAME_DESIGN.md` (the HUD and health part) with the hit and drain cues and the setting, and tick the task in `TASKS.md`. Verify: the docs name only behaviour in the specs.
- [ ] 6.2 Run `openspec validate damage-feedback --strict`. Verify: valid.

## Workflow follow-up

- Archive once the owner has played it: `/opsx:archive damage-feedback`.
- Later changes to consider: per-cause sounds once AudioManager plays sounds, a hit flash on the teammate list's row, a one-off flash on crossing 25 health (DCSS `hp_warning`), and hit notices (Brogue's red line).
