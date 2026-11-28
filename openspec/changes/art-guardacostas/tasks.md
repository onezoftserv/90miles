# Tasks

**Commands.**
- Godot: `G=/c/Users/liann/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe`, always run with `--path game`.
- Every group ends with:
  - `$G --headless --path game --import`, run twice;
  - the smoke run (`-s res://tests/smoke.gd`);
  - GUT (`-s res://addons/gut/gut_cmdln.gd -gexit`), all passing;
  - `python -I -m unittest discover -s tools/art -p 'test_*.py'` when a tool, recipe or hand source changed.

**Art rules.**
- Art goes only through the `tools/art/` recipes and hand sources, with `png.py`. Never Pillow, and never paint into `game/`.
- The packs (`--packs C:/Users/liann/src/90miles/game/assets`) are read-only.
- Use only master palette colours.
- Actors are rimmed in #000000.
- Run `python -I tools/art/check.py game/assets/art` after every rebuild.
- Art never changes the simulation. Every new drawing node joins `test_art_sim_invariance.gd`.
- Rodríguez is fictional, and nothing drawn resembles a real person, flag or insignia.

**Tests.**
- Tests write only under `UserTmp.path()`.
- Two-process runs use UDP 7803.
- Each group adds at least one test with exactly 1 player, offline.

## 0. Gate

- [x] 0.1 Record the owner's answers to QG1–QG4 in proposal.md. If an answer is not (a), update the specs, design and tasks to it, then run `openspec validate art-guardacostas --strict`. Done when it passes and the docs PR is open.
- [x] 0.2 Branch each build PR from the latest main. Re-read, as they are on main then:
  - `run_hud.gd`/`.tscn` (hud-clarity, run-menu);
  - `patrol_look.gd` and `patrol_horizon.gd` (sound-pass);
  - `ui_kit.json`, `look_parts.json` and `creature_sheets.json` (art-waves).

  Check whether PR #105 (the outline family check) has merged. Done when the re-read is noted in design.md's build notes.
- [x] 0.3 Take the "before" captures from main under `UserTmp`:
  - `capture_patrol.tscn`: the boat by day, and the alert at night;
  - `tests/manual/capture_squad.gd`: the squad ashore, and the dinghy rowing in;
  - `capture_la_captura.tscn`: lines 1 and 3, and after.

  Done when the PNGs are listed in the build notes.

## 1. Call windows (D6) — HUD PR

- [x] 1.1 Write these tests first and see them fail:
  - `test_call_windows.gd`: every alert, give-up and squad line of every patrol `.tres`, in ES and EN, wraps to at most 3 rows of 30 glyphs in the `HudCall` window;
  - a call shows for `max(3, 1 + length / 15)` s;
  - an off-screen speaker puts the window at the nearest edge with its tail toward the speaker;
  - the window never overlaps a top HUD window or the prompt, and stays above y 326;
  - the 1-player test: on the sandbar at night, a solo player's boat alert shows its Spanish line in a window over the boat, not in a `SpeechBubble`.
- [x] 1.2 Rewrite these first, so they fail on today's code:
  - `test_patrol_cues.gd`'s loudhailer tests;
  - `test_capture_cues.gd`'s "squad's landing, spot and leaving calls" test, to read the call window.
- [x] 1.3 Build the feature:
  - add `CoopSession.call_shown`;
  - make `PatrolLook._speak` and `SquadLook._speak` emit it;
  - add the `HudCall` theme variation (the `window_thin` stylebox, content margins 4/1/4/1);
  - add `scenes/ui/call_windows.gd`, created in `RunHud.bind`.

  Verify that the tests from 1.1 and 1.2 pass, that `test_quick_chat_session.gd` still shows quick chat in bubbles, and that `test_art_sim_invariance` covers `CallWindows`.
- [x] 1.4 Two-process check: `test_patrol_cues.gd`'s "both peers show the same loudhailer line" and a new "both peers show the same spot call over the soldier giving chase" pass with the window. Done when both pass in GUT.

## 2. The plated eye (D7) — HUD PR

- [x] 2.1 Write these first and see them fail:
  - `test_ui.py`: `eye_open_plate` is 11×7, palette only, with an iris of 3×3 #222034;
  - `test_body_look.gd`: the open eye's rect is 11×9, centred over the head, its bottom 3 px above the head;
  - `test_patrol_cues.gd`: the bar's fill is `round(9 × fraction)` px, in cream below 0.5, orange from 0.5 and alert red from 0.75;
  - the closed eye still wins over the open eye, and the rope still wins over both;
  - the 1-player test: a solo player lit at night for 1.5 s of a 2 s spot shows a bar more than 3/4 full in the alert colour.
- [x] 2.2 Add the piece to `ui_kit.json` and rebuild with `ui.py`. Then:
  - draw the plate and bar in `BodyMarks`;
  - make `marker_rect` return 11×9 for an open eye.

  Verify that the tests from 2.1 pass, along with `test_capture_cues.gd`'s eye test and the speech-bubble and prompt stacking tests (`test_head_anchor.gd`, `test_quick_chat_session.gd`).

## 3. The warning chip (D8) — HUD PR

- [x] 3.1 Rewrite `test_patrol_cues.gd`'s 5×2 hull and 3×2 light tests and see them fail. They become:
  - a 9×7 day chip and a lit night chip;
  - placed by bearing, then slid clear of the meters, phase, weather and teammates windows;
  - blinking at 2 Hz;
  - blinking at 4 Hz in the last 5 s, from the synced `route_t`.

  The 1-player test: a solo player at night sees the lit chip for the 20 s warning and none once the lap starts.
- [x] 3.2 Add `boat_chip_day` and `boat_chip_night` to `ui_kit.json`, rebuild, and draw them in `PatrolHorizon`. Verify:
  - the tests from 3.1 pass;
  - `test_patrol_cues.gd`'s two-process horizon test passes;
  - `check.py` is clean.
- [x] 3.3 Capture the "after" HUD frames: the call window at night, the plated eye, and the chip by day and by night, at 1x and x3. Open the HUD PR with before and after images, and send its link to the coordinating session. Done when the PR is green.

## 4. Soldiers (D2, D5) — sprites PR

- [x] 4.1 Write these first and see them fail:
  - `test_look_parts.gd`: the shipped parts add `outfit_uniform` and `hair_cap`;
  - `test_look_composer.gd`: each soldier look composes with closed #000000 outlines and no key-ramp colour;
  - a new `test_guardacostas_art.gd`: `GuardacostasArt` lists three soldier looks; a soldier named `Creature<n>` takes look `n mod 3`; three consecutive soldiers take three looks;
  - `test_capture_cues.gd`: rewrite `test_the_soldier_and_the_dinghy_are_drawn_from_the_synced_state` so a soldier is an `AnimatedSprite2D` in a walk while moving, facing its motion, idle when still;
  - the 1-player test: a solo player's spot on the sandbar lands three soldiers drawn in three different looks.
- [x] 4.2 Make the art:
  - add the `outfit_uniform` and `hair_cap` entries to `look_parts.json`;
  - draw `tools/art/fixes/hair_cap.png`;
  - build with `compose.py outfit_uniform hair_cap`;
  - add the `LookPart` `.tres` files and the three looks;
  - add `scripts/art/guardacostas_art.gd` and `guardacostas_art.tres`.

  Rebuild, then verify that `check.py` is clean, that the other parts are byte-identical, and that `test_art_tracked.gd` and `test_look_composer.gd` pass.
- [x] 4.3 Draw soldiers in `SquadLook` from the composite (D2), and reword the soldier's exemption in `CreatureArt.frames_problems`. Verify that the tests from 4.1 pass, along with `test_art_sim_invariance` and `test_draw_order`.

## 5. The launch and the dinghy (D3, D5) — sprites PR

- [x] 5.1 Write these first and see them fail:
  - a new `test_guardacostas_art.gd` case: every hull frame's opaque bounds are wider and taller than every raft frame's;
  - the hull mirrors by heading;
  - the lamp pixel sits on the creature's position, which is the light's apex;
  - the hull is hidden in AWAY and HORIZON;
  - `test_patrol_cues.gd`: rewrite the polygon-hull test for the sprite;
  - the dinghy is a `DinghyLook` at `dinghy_px` that sorts by its own y. It shows `row` while rowing and `beached` at `dinghy_t` 1 with the squad ashore;
  - the 1-player test: a solo player walking past the beached dinghy draws in front of it from the south and behind it from the north.
- [x] 5.2 Make the art:
  - draw `tools/art/fixes/creatures/patrol_boat.png` and `dinghy.png`;
  - add both to `creature_sheets.json`;
  - build with `creatures.py`;
  - add the frames to `guardacostas_art.tres`;
  - update `docs/ASSETS.md`'s "Patrol boat, cutter, dinghy" row.

  Verify that `check.py` is clean, the frame budget holds (at most 4 per animation), and the other creature sheets are byte-identical.
- [x] 5.3 Draw the hull sprite in `PatrolLook`, and add `DinghyLook`, created by `SquadLook`. Reword the boat's exemption. Verify:
  - the tests from 5.1 pass;
  - `test_patrol_cues.gd`'s "client joining mid-lap draws the boat and its cone in place" passes;
  - `test_art_sim_invariance`'s night-lap test passes.

## 6. The cone's edge (D4) — sprites PR

- [x] 6.1 Rewrite `test_patrol_cues.gd`'s "60 degree 10 tile wedge" test and see it fail:
  - every cell `Searchlight` lights reads at half strength or more in the texture, at its offset;
  - no texel beyond the rim's outer half is lit;
  - the near and far falloff is kept.

  The 1-player test: a solo player just inside the edge is drawn lit and their meter fills.
- [x] 6.2 Change `PatrolCone._build`, `length_px` and `height_px`. Verify that the tests from 6.1 pass and that the light's offset still puts the apex on the lamp.
- [x] 6.3 Two-process check on UDP 7803 (`test_capture_net.gd` or a new `test_guardacostas_art_net.gd`). With a squad ashore, the client has:
  - three soldier sprites with the host's looks;
  - the dinghy `beached` at the host's landing cell;
  - the hull drawn at the docked boat.

  Then run host plus client locally with `coop_playground.tscn` and watch them. Done when the test passes and the run is noted.
- [x] 6.4 Capture the "after" sprite frames: the squad ashore, the dinghy rowing in and beached, the boat by day, and the cone at night, at 1x and x3. Open the sprites PR with before and after images, and send the link. Done when the PR is green.

## 7. Pacing, portrait and advance cue (D10, D11, D12) — La captura PR

- [x] 7.1 Write these first and see them fail:
  - `test_capture_scene.gd`: `hold_s` is `max(length / 40 + 2, 1 + length / 15)`; the act holds 10 s and a 20-character line 2.5 s;
  - the panel is 440 px wide at x 100 with a 36×36 portrait frame, its bottom at y 330;
  - every la_captura line fits 7 rows at 49 glyphs in both languages;
  - Rodríguez's lines show `rodriguez.tres`'s portrait, and a plea shows the pleader's figure swapped to their slot row;
  - the arrow and "[E]" show once the line is revealed, blinking, on the host and in solo only;
  - a client shows the drain bar from the Spanish text's hold;
  - the 1-player test: a solo player's capture shows the portrait, then the arrow, and interact shows the next line.
- [x] 7.2 Make the art:
  - draw `tools/art/fixes/portraits/rodriguez.png`;
  - add `tools/art/portraits.py`, `portraits.json` and `test_portraits.py`;
  - build `game/assets/art/portraits/rodriguez.png` with its `License.txt`;
  - set `rodriguez.tres`'s `portrait`;
  - add the portraits folder to `docs/ASSETS.md`.

  Verify that `check.py` is clean and that `test_art_tracked.gd` and `test_art_credits.gd` pass.
- [x] 7.3 Change `hold_s`, then lay out the panel's portrait, arrow and drain bar. Pass `RunHud.device` to the panel. Verify the tests from 7.1 pass.

## 8. Staging (D9) — La captura PR

- [x] 8.1 Write these first and see them fail, in a new `test_capture_stage.gd`:
  - on `scene_started` the bars slide in over 0.5 s;
  - `RunHud.set_staged(true)` hides the meters, phase, weather, teammates, strip, prompt, marks, floats and chips, keeps the scene panel and the run menu, and leaves input open;
  - the camera offset eases to the docked boat and its landing midpoint, and back to 0 at the end;
  - with no boat in sight the offset stays 0;
  - the 1-player test: a solo player caught by a soldier on the sandbar sees the bars, a HUD with only the panel, and a view that frames the docked boat and the beached dinghy; after the scene the HUD is back.
- [x] 8.2 Build the feature: add `scenes/ui/capture_stage.gd`, created in `RunHud.bind`, and `RunHud.set_staged`. Add `CaptureStage` to `test_art_sim_invariance`. Verify the tests from 8.1 pass, along with every `test_capture_*.gd`.

## 9. The confiscation notice (D13) — La captura PR

- [x] 9.1 Write these first and see them fail:
  - `test_capture_scene.gd`: the report holds what the outcome removed; the release reports nothing;
  - a `TAKE_ITEM` outcome in a fixture is reported by id;
  - a non-host call is ignored, and unknown ids are dropped;
  - the 1-player test: a solo player with a fosforera and a coconut whose capture restarts sees "Te quitaron: Fosforera" in the notice row for 5 s after landing.
- [x] 9.2 Build the feature:
  - add the record and `show_confiscated` to `CaptureScene`;
  - add the notice text keys to `hud_text.tres`;
  - make `CaptureStage` write the row.

  Verify the tests from 9.1 pass.
- [x] 9.3 Two-process check on UDP 7803. A host with a lighter and a client with nothing that lights fire are caught together: after landing, only the host's notice names the lighter. Then run host plus client locally and watch. Done when the test passes and the run is noted.
- [x] 9.4 Update `docs/GAME_DESIGN.md` §9 "Guardacostas and stealth": "in a minimal scene panel" becomes "in a staged scene panel with Rodríguez's portrait, each line held long enough to read", and add the notice. Done when the doc reads so.
- [ ] 9.5 Capture the "after" frames of La captura: the letterbox with the portrait at line 1, the act at line 3 with the arrow, the plea with the player's figure, and the closing notice after landing. Open the La captura PR with before and after images, and send the link. Done when the PR is green.

## 10. Integration

- [ ] 10.1 Rebuild every touched sheet to scratch and `cmp` each against the tracked file. Run `check.py`, the art unittests, the import twice, smoke and GUT. Done when all are clean.
- [x] 10.2 Tick `TASKS.md`'s coast guard art items, and add the follow-ups below under the current milestone. Record the measured sizes and departures in design.md's build notes. Run `openspec validate art-guardacostas --strict`. Done when it passes.

## Workflow follow-up

- Archive only after `guardacostas-stealth` and then `guardacostas-capture` are archived, and the owner has seen the captures.
- Follow-ups, not in this change:
  - the closed eye and the rope at the plated size;
  - the outline of a body hidden under a roof (H6, SP12);
  - H5's notice line;
  - a notice for what taken captives lost;
  - emotion portraits;
  - the held party shown in the staged scene.
