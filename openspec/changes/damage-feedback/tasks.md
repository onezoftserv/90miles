# Tasks

The owner chose A for Q1, Q2 and Q4 to Q7, and no hit numbers for Q3 (2026-11-14 and 2026-11-15). Design D1 folds in the coordinator's research pass and lists its optional follow-ups.

The commands below run from the repo root, using the Godot 4.7.2 console binary:
- "Import" is `godot --headless --path game --import`, run twice on a fresh checkout.
- "Smoke" is `godot --headless --path game -s res://tests/smoke.gd`.
- "GUT" is `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`.

## 1. Tuning data and the watches (survival-meters "Hits and drains are told apart", "Jumps and cures are told apart")

- [x] 1.1 Tests first: write `game/tests/unit/test_meter_watch.gd` (pure; 1 player, offline). It drives `observe(value, dead, delta)` by hand and covers:
  - the first observation and every observation while dead return NONE;
  - an isolated loss of 5 is a HIT of −5, and a loss of 2.9 is a DRAIN;
  - 2/s thirst at 60 Hz and at 20 Hz steps is a DRAIN for 3 s;
  - 10/s drowning in 20 Hz steps, with one 0.5 s gap of 5, is a DRAIN;
  - 25 inside a 10/s drain is a HIT of about −25;
  - a rise of 15 at once is a JUMP of +15, and a rise of 1/s is NONE;
  - `reset()` makes the next observation a baseline;
  - the rate is forgotten after 1 s with no loss.

  Also write `test_status_watch.gd`:
  - a cleared bit is a cure;
  - a set bit, the first observation and a dead body are not.

  Verify: both fail to parse at first, then pass.
- [x] 1.2 Write `game/scripts/ui/hurt_cue_tuning.gd` (`HurtCueTuning`, a `Resource` with every number in design D3 to D10, plus `meter_colors`) and `game/resources/hurt_cue_tuning.tres`. Add `test_hurt_cue_tuning.gd`. It checks:
  - the values;
  - that `meter_colors` equals each `fill_color` in `meters_hud.tscn`.

  Verify: GUT.
- [x] 1.3 Write these in `game/scripts/ui/`, as design D3:
  - `meter_watch.gd` (`MeterWatch`);
  - `status_watch.gd` (`StatusWatch`);
  - `hurt_cues.gd` (`HurtCues`: the static `reduce_flashes` and the shared tuning).

  Verify: 1.1 passes.
- [x] 1.4 Import ×2, Smoke and GUT pass.

## 2. Reduce flashes and the sound hook (ui-shell "Settings")

- [x] 2.1 Tests first: extend the settings tests (`test_game_settings.gd`, or the one that covers `GameSettings` save and load). They cover:
  - `reduce_flashes` defaults to false;
  - it survives save and load;
  - an old file without the key reads false;
  - the settings screen's "Reducir destellos" box toggles it, saves, and sets `HurtCues.reduce_flashes`;
  - `GameShell` sets the static from the loaded settings.

  Verify: they fail first, then pass.
- [x] 2.2 Add:
  - `GameSettings.reduce_flashes` (`display/reduce_flashes`);
  - the `ReduceFlashes` `CheckBox` in `settings_screen.tscn` and `.gd`;
  - the shell's write to `HurtCues.reduce_flashes` on load and on change.

  Check that the settings panel still fits 640×360 in the existing layout test. Verify: 2.1 and the settings layout tests pass.
- [x] 2.3 Add `AudioManager.play_sfx(id: StringName) -> void`, a documented no-op. Verify: GUT, with a call from a test that does not error.
- [x] 2.4 Import ×2, Smoke and GUT pass.

## 3. Body cue (survival-meters "Hurt cue on the body")

- [x] 3.1 Tests first: write `game/tests/unit/test_hurt_blink.gd`. It covers the pure `HurtBlink` state:
  - white on the first frame;
  - hidden at 10 Hz until 0.6 s;
  - then clear;
  - the tint when reduce flashes is on.

  It also covers a solo, offline `PlayerLook` on a body, stepped by hand with `look.step(1/60)`:
  - after `meters.harm(5, &"land_crab")`, `hurt_white` is 1 on the first step, then `hurt_hidden` toggles, and everything is clear after 0.6 s;
  - thirst at 0 for 3 s never sets them;
  - a dead body never sets them.

  Verify: it fails first, then passes.
- [x] 3.2 Add `hurt_white`, `hurt_hidden` and `hurt_tint` to `player_look.gdshader`, applied after the water-line cut. Add the health `MeterWatch` and `HurtBlink` to `PlayerLook.step`, with time from `delta` only (no Tween, Timer, await, RNG or `_enter_tree`). Verify: 3.1 passes, and the existing art and look tests still pass.
- [x] 3.3 Extend `test_art_sim_invariance.gd`. In both runs, at a fixed frame, the nearest land crab pinches the player through the host's own `CreatureWorld.pinch`, or `meters.harm` if no crab is in reach. The built run asserts that the look's blink ran. Verify: the invariance test passes, and its bad-look guard tests still fail as they should.
- [x] 3.4 Import ×2, Smoke and GUT pass.

## 4. Screen cue and bar slices (ui-shell "Hit flash at the screen edges", "Changes show on the bars", "Drain glow on the health bar")

- [x] 4.1 Tests first: write `game/tests/unit/test_hurt_screen.gd` (solo, offline, a `MetersHud` bound to one body's meters, stepped by hand). It covers:
  - **Edge flash:**
    - a pinch of 5 shows the overlay, and it is clear 0.4 s later;
    - a bite of 25 shows it stronger;
    - two hits 0.1 s apart start one flash;
    - with reduce flashes on, there is no overlay, no bar flash and no shake.
  - **Bar slices:**
    - Salud's `Lost` part spans 75 to 100 after a bite of 25 and is gone by 0.9 s;
    - Salud shakes for 0.2 s on a hit and never on a drain;
    - Sed's `Gain` part spans 50 to 65 after +15 at once, flashes, and is gone by 1 s.
  - **Drain glow:** it shows while thirst drains and stops 1 s after the last loss, and a lone hit does not glow.
  - **Rebind:** a rebind to other meters at 90 shows no slice and no flash.
  - **Sound hook:** `hurt_cued` fires `hurt_hit`, `hurt_big`, `hurt_drain` (once per drain) and `use_done`.
  - **Overlay rules:** the overlay is not counted by `RunHud.panel_rects()` and ignores the mouse.

  Verify: it fails first, then passes.
- [x] 4.2 Write `game/scenes/ui/hurt_overlay.gd` and `.gdshader` (an edge-only red band) and add `HurtOverlay` to `meters_hud.tscn` beside `Blur`. Then make these edits:
  - **`MetersHud`:**
    - one `MeterWatch` per bar;
    - the overlay strength and the gap between flashes;
    - `hurt_cued`;
    - the `AudioManager.play_sfx` calls;
    - `reset()` in `bind()`.
  - **`MeterBar`:**
    - `Lost` and `Gain` `ColorRect`s, and a `Glow` `Panel` on health only;
    - `show_change(old, new, kind)` and `step`.

  Keep the edits to these nodes only, since a HUD restyle is in review. Verify: 4.1 passes, and `test_meters_hud.gd`, `test_run_hud*.gd` and the HUD layout tests pass.
- [x] 4.3 Import ×2, Smoke and GUT pass.

## 5. Change floats (survival-meters "Change floats over the body")

- [x] 5.1 Tests first: write `game/tests/unit/test_change_floats.gd` (solo, offline, a `RunHud` on a sandbar session, stepped by hand). It covers:
  - a coconut at thirst 50 and hunger 50 floats "+15 Sed" in Sed's colour and "+5 Hambre", stacked 9 px apart, above the head anchor and clear of the name tag;
  - the floats rise 12 px and are gone after 1 s;
  - a second float on a body pushes the first one up by 9 px;
  - a coconut at thirst 94 floats "+6 Sed", the gain that fit;
  - a bite of 25 floats nothing (Q3 A);
  - clearing BLEEDING floats "Sin sangrado";
  - thirst draining floats nothing;
  - a body freed from the session frees its floats.

  Verify: it fails first, then passes.
- [x] 5.2 Write `game/scenes/ui/change_floats.gd`, add `ChangeFloats` to `run_hud.tscn` beside `Marks`, and follow every body as `_follow` does. Add the meter and status words for floats to `hud_text.gd` and `hud_text.tres` (Spanish first, English beside). Verify: 5.1, `test_hud_text.gd` and `test_run_hud*.gd` pass.
- [ ] 5.3 Import ×2, Smoke and GUT pass.

## 6. Effect line and wasted uses (inventory-hud "Effect line", "Uses that would do nothing"; crafting-inventory "A use that changes nothing is refused")

- [ ] 6.1 Before touching `ItemUser`, grep the tests for item uses (`ItemUser.use`, `use_for`, `use_item`, `_send_use`). Wherever a test means a use to happen at default (full) meters, lower the meter first. Verify: GUT is still green with no behaviour change.
- [ ] 6.2 Tests first: write `game/tests/unit/test_effect_line.gd` (pure). It covers:
  - coco reads "Sed +15 · Hambre +5 · Energía +10";
  - at thirst 94 and energy 50 it reads "Sed +15 (+6 útil) · Hambre +5 · Energía +10", and at full energy the energy part reads "Energía +10 (+0 útil)";
  - aloe reads "Cura quemadura y sangrado";
  - manzanillo reads "Salud −50 en 60 s";
  - the revive use reads "Levanta · …";
  - driftwood reads "";
  - lines are cut at 50 characters with "…";
  - the set of kinds `EffectLine` handles equals `EffectApplier`'s interpreted kinds;
  - every item in the catalog builds its line without a missing word.

  Verify: it fails first, then passes.
- [ ] 6.3 Tests first: extend the `ItemUser` tests (`test_item_user*.gd`). They cover:
  - `NOTHING_TO_DO` for aloe with no status;
  - a coconut at full thirst, hunger and energy;
  - not for a coconut at hunger 80 (it still drinks);
  - not for any use with a revive, a give, a route, a flag, a delay, a change over time or a loss;
  - a forged wasted use through `use_for` changes and spends nothing.

  Extend `test_inventory_strip.gd` with the refusal lines ("No hay na' que curar.", "No tienes sed.", "A Papo no le hace falta.") and the effect line on the notice row, which returns after a refusal. Verify: they fail first, then pass.
- [ ] 6.4 Write `game/scripts/ui/effect_line.gd` (`EffectLine`) as design D11. Add `ItemUser.Reason.NOTHING_TO_DO` and its dry run as design D12. Add the strip's refusal keys and effect line in `inventory_strip.gd`, and the refusal and effect words in `hud_text.tres`, Cuban for the refusals. Verify: 6.2 and 6.3 pass, and `test_hud_text.gd` passes.
- [ ] 6.5 Import ×2, Smoke and GUT pass.

## 7. Solo and co-op end to end

- [ ] 7.1 Write the solo test `game/tests/unit/test_damage_feedback_solo.gd`, with exactly 1 player, offline, `NetManager.start_solo()`, a sandbar session and its `RunHud`. It covers:
  - a land crab's `CreatureWorld.pinch` blinks the look, flashes the edges and leaves a 5-point chunk, with no number floating;
  - thirst at 0 for 3 s of host ticks glows the bar with no blink, flash or float;
  - drinking a coconut through the strip floats "+15 Sed" and lights the Sed bar;
  - sábila with nothing to cure is refused with "No hay na' que curar." and stays.

  Verify: it passes.
- [ ] 7.2 Tests first, in-process host plus client with `NetHarness` (as `test_status_net.gd`), written as `game/tests/unit/test_damage_feedback_net.gd`. Await only the sync, then step the cues by hand. It covers:
  - a host-side crab pinch on the client's player flashes the client's edges and blinks its own look, and the host's HUD does not flash;
  - a pinch on the host's player blinks that body on the client, with no number floating;
  - the host drinking a coconut floats "+15 Sed" over the host's body on the client;
  - a late joiner who first sees a host at 60 health cues nothing;
  - a walking client's own energy floats nothing;
  - a forged wasted use from the client changes nothing on the host.

  Write the late-joiner case first. If it fails because spawn state lands late, add the `synchronized` baseline from design's Risks. Verify: it passes, and the GUT total stays under CI's 300 s.
- [ ] 7.3 Two processes: write `game/tests/manual/damage_feedback_run.gd` (host and client on UDP 7793, as `dead_spectate_run.gd`). The run:
  1. the host pinches the client;
  2. the client's player drowns;
  3. the host drinks a coconut.

  The client asserts its HUD flash, its own blink, the drain glow and the "+15 Sed" float over the host. The host asserts that the client's body blinks. Run it 3 times. Verify: both processes report every check passing with 0 engine errors.
- [ ] 7.4 Import ×2, Smoke, GUT and CI's four headless game runs pass with 0 error lines.

## 8. Docs

- [ ] 8.1 Update `docs/GAME_DESIGN.md` (the HUD and health part, and item use) with the hit, drain and use cues, the wasted-use rule and the setting. Tick the task in `TASKS.md`. Verify: the docs name only behaviour in the specs.
- [ ] 8.2 Run `openspec validate damage-feedback --strict`. Verify: it is valid.

## Workflow follow-up

- Archive once the owner has played it: `/opsx:archive damage-feedback`.
- Later changes to consider:
  - per-cause sounds once AudioManager plays sounds;
  - a hit flash on the teammate list's row;
  - a one-off flash on crossing 25 health (DCSS `hp_warning`);
  - hit notices (Brogue's red line);
  - item descriptions in play.
