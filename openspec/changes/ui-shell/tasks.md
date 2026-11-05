# Tasks

Each group is written test-first: its tests are committed failing (RED), then the code that passes them (GREEN).

## 1. Display and settings

- [x] 1.1 Add `DisplayFit` and `GameSettings` (name cleaning, fullscreen, scale, a ConfigFile at an injectable path) and verify GUT tests for 1080p windowed (2×), fullscreen (3×), fixed scale, a reload of saved settings and the name cleaning
- [x] 1.2 Add the `toggle_fullscreen` action (F11, Alt+Enter) and verify a GUT test of its events
- [x] 1.3 Verify the import, smoke run and GUT pass with zero error lines

## 2. Theme and title

- [x] 2.1 Import both fonts crisp, add `game_theme.tres` with the tracked Kenney 9-slices (license, CREDITS row) as the project theme, and verify GUT tests that the theme is set, uses the two fonts at their sizes and only references tracked art
- [x] 2.2 Add `TitleScreen` (buttons, focus description, animated sea, version) and verify GUT tests for the button list, first focus, the description of each button and its signals
- [x] 2.3 Render the title at 1× and send the screenshot to the user for early feedback
- [x] 2.4 Verify the import, smoke run and GUT pass with zero error lines

## 3. Shell flow

- [x] 3.1 Add `GameShell` as the main scene with the title, settings, join and summary screens and the dev island run, and verify GUT tests for "solo from the title" (offline, no lobby, a player on the beach), the settings round trip, join-address validation, "end of a solo run" and Esc going back
- [x] 3.2 Verify the import, smoke run, GUT and a 300-frame run pass with zero error lines

## 4. Lobby

- [x] 4.1 Add the CoopSession lobby phase, `request_join`, the roster and `begin_run`, and verify ENet tests for "players spawn when the run starts", "two players meet", "client renames itself over and over", a join during a run, and that the existing coop-networking suites still pass
- [x] 4.2 Add `LobbyScreen` and the host/join paths through the shell, and verify GUT tests for "host and start" and "host lost"
- [x] 4.3 Verify the import, smoke run and GUT pass with zero error lines

## 5. HUD

- [x] 5.1 Re-lay `MetersHud` with labels inside the bars and the critical pulse, add the phase label, the teammate list and `NameTag`, and verify GUT tests for "solo HUD", "critical thirst" and "teammate down"
- [x] 5.2 Hide quick chat in solo and verify "no quick chat in solo" with one offline player
- [x] 5.3 Remove the per-scene theme overrides, render the lobby and run HUD at 1×, and verify the playground tests still pass
- [x] 5.4 Verify the import, smoke run, GUT, a 300-frame run and a two-process host and client run through the shell pass with zero error lines

## 6. Pixel filter

- [x] 6.1 Add the pixel filter to `GameSettings` (`[display] pixel_filter`, Nítido by default) and its option on the settings screen, and verify GUT tests for "setting persists" and "settings screen offers both modes"
- [x] 6.2 Move `World` into a 640×360 `SubViewport` with `PixelFilter` picking the stretch mode and material, write `scale2x.gdshader` from the published rules, and verify GUT tests for "presenter picks the material in each mode" and "solo run in Suave"
- [x] 6.3 Add `tests/manual/capture_pixel_filter.tscn`, capture Nítido before and after (pixel-identical) and Suave, and save the captures in `docs/ui-shell/`
- [ ] 6.4 Verify the import, smoke run, GUT and a two-process host and client run through the shell pass with zero error lines

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Add the ui-shell line to `TASKS.md` and a Done entry.
- Open the PR against `main` and get CI green; the user's other session merges it.
- Archive after the user answers the provisional decisions.
