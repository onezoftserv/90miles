# Tasks

Every group is built test-first: write the group's tests, watch them fail, then build. Every group ends with the import (twice on a fresh checkout), the smoke run and GUT passing:
- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`

## 0. Before building

- [x] 0.1 Read the owner's answers to Q1–Q4 and fold any change into the specs and design.md (Owner decisions), then re-run `openspec validate hud-clarity --type change --strict`
- [x] 0.2 Take the "before" captures on this branch's base (solo sandbar first frame, top band at 3×, meters with bleeding, a sunstroke frame) into `docs/ui-shell/hud-clarity/before/` (`tests/manual/capture_hud_clarity.tscn`, which frames "after" the same way)

## 1. Content and data

- [x] 1.1 Tests (1 player, offline): `count_name` falls back from the short name to the name and from English to Spanish; driftwood, inner tube and rope have their short names; the sandbar's launch lines; the validator fails a 9-character or capitalised short name and a 28-character launch line and names the file
- [x] 1.2 `ItemData.short_name_es`/`short_name_en` and `count_name(locale)`; fill driftwood, inner tube and rope; `IslandLayoutData.launch_line_es`/`launch_line_en`; fill the sandbar; length checks in `ContentValidator`
- [x] 1.3 `HudText` gains `objective_lines` and `clock_words` export blocks with every key in Spanish and English in `hud_text.tres`, and a test that every key exists in both languages
- [ ] 1.4 Import, smoke and GUT pass

## 2. Clock row

- [x] 2.1 Tests for `DayStrip` (pure): segment edges, the marker's column, the time left and its format ("11h" at 09:00, "2h" orange at 18:30, "20m" at 05:40, "14h" at dawn), and the phase word for every stretch, including "Mañana" and "Tarde"
- [x] 2.2 Tests (1 player, offline) on a solo run: the clock row reads "Día 1 … 11h … Mañana" at 09:00; "Día 2" after travel to the coast cay; the row's rect is (152,4)–(380,18); and `PhasePanel`/`%Phase` still exist
- [x] 2.3 Build `DayStrip` and `ClockStrip`, and the kit icons `clock_moon` and `clock_sun` via `tools/art/ui.py`; grow `PhasePanel` to (152,4)–(380,18); `RunHud.phase_name()` returns the new words; update the test that read the old phase word (only `test_run_hud.gd` did)
- [ ] 2.4 Import, smoke and GUT pass

## 3. Objective row

- [x] 3.1 Tests for `Objective` (pure, 1 player, offline): every step in spec order (first frame "0/6 madera", carried plus deposited "0/2 cámaras", "Lleva to' pa' la balsa", "Dale a la balsa: 40%", "Espera la noche pa' zarpar" by day with a patrol boat out, "Zarpa pa'l cayo" at night and in a squall, the launch line with no boat out, "Aguanta hasta tierra", coast cay "Zarpa pa'l norte", English "Build the raft: 0/6 wood"); a bench-placed build site is ignored; on the hidden cay nothing names the cay, chest, map or compass
- [x] 3.2 Test that every objective line, filled to its longest (each vessel build-site recipe's inputs at their real need, 100%), fits 27 glyphs in Spanish and English
- [x] 3.3 Tests (1 player, offline) for `ObjectiveRow` in `RunHud`: shown under the clock inside (152,20)–(380,30); hidden while the hut note is open and shown again after; hidden while a screen is shown
- [x] 3.4 Build `Objective`, `ObjectiveRow` and the `RunHud` wiring (island layout from `Travel`, settable in tests); add a `BuildSite` progress accessor if none exists
- [ ] 3.5 Import, smoke and GUT pass

## 4. Top band and needle

- [x] 4.1 Tests (1 player, offline): the needle sits at (384,20)–(408,44); "The top band holds together" with a squall, the compass, the longest objective lines and the note label, against #75's crossing rects as constants; the teammate list stays clear (host with three clients)
- [x] 4.2 Move the needle in `compass_needle.tscn`; update `test_compass_needle.gd` and `test_run_hud.gd`'s weather-panel clearances
- [ ] 4.3 Import, smoke and GUT pass

## 5. Raft-site arrow

- [x] 5.1 Tests (1 player, offline): the arrow points west on the frame's left edge when the site is out of view to the west, and is gone when it is in view; its rect stays inside (8,96)–(632,300) and off every HUD window for targets in all eight directions; hidden at sea, with the crafting list or sign note open, and under a screen; it follows `Raft` once built
- [x] 5.2 Build `SiteArrow` and the kit icons `arrow_straight` and `arrow_diagonal`
- [ ] 5.3 Import, smoke and GUT pass

## 6. Meters: Calor last, Insolación and Sangrando rows

- [x] 6.1 Tests for the bleeding time (1 player, offline): `bleeding_left_s` counts down on the host, a new wound refills it, and it is 0 after the end; `player.tscn` replicates `SurvivalMeters:bleeding_left_s` (update `test_player_state_sync`)
- [x] 6.2 Tests (1 player, offline): rows read Salud, Sed, Hambre, Energía, Ánimo, Calor; Calor's track holds three zone tints and no plain empty colour at heat 2, with notches at 50 and 75; "Insolación" shows with the blur, with its bar full at 100, half at 80 and gone below 60; "Sangrando" with its icon, its bar half after 60 of 120 s and full again after a new bite; the window with both rows lies inside (4,4)–(136,90)
- [x] 6.3 Build `bleeding_left_s` and its replication entry; the `MeterBar` zones and notches; `StatusRow` and the icons `status_sunstroke` and `status_bleeding`; reorder `meters_hud.tscn`; keep `MetersHud.bleeding_tag()`
- [x] 6.4 Update the tests that read the meter order or the old tick (`test_hud_windows` and the meter tests)
- [ ] 6.5 Import, smoke and GUT pass

## 7. Hut note

- [x] 7.1 Tests (1 player, offline): the sandbar has one sign, glyph `n`, reachable from the solo spawn and every co-op spawn; its lines name Florida, the north and the night, hold no digit and wrap to 8 lines or fewer; reading it opens the sign note and changes nothing; the sandbar's other contents are unchanged
- [x] 7.2 Edit `sandbar.tres` (one cell, `terrain_glyphs`, the sign) with the D9 text (or the owner's)
- [ ] 7.3 Import, smoke and GUT pass

## 8. Co-op check and captures

- [x] 8.1 GUT net test (host plus client in one process): a client's clock row matches the host's after a resync; a client's objective row follows the host's deposits; a client's "Sangrando" bar follows the host's time left
- [x] 8.2 Two-process manual run on UDP 7800 (`tests/manual/hud_clarity_run.gd`): host and client each check the clock, the objective and the bleeding bar on the client, 3 runs, 0 engine errors
- [x] 8.3 "After" captures matching 0.2, plus the arrow and the hut note, in `docs/ui-shell/hud-clarity/after/`
- [x] 8.4 Update `docs/GAME_DESIGN.md` (the HUD list in §4 and §5), `TASKS.md` (this change's line, plus follow-ups: "Cayo 1/3", Energía and Ánimo, the sábila pulse) and the change's design.md with anything learned
- [ ] 8.5 Import, smoke and GUT pass; `openspec validate hud-clarity --type change --strict` passes

## Workflow follow-up

- Open the PR into main with before and after captures, and send its link to the coordinating session.
- Archive (`/opsx:archive hud-clarity`) after hud-window-kit, damage-feedback, bleeding-and-sabila and art-mood-pass, once the owner has played it.
