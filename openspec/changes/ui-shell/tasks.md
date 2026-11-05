# Tasks

Each group is written test-first: its tests are committed failing (RED), then the code that passes them (GREEN).

## 1. Display and settings

- [x] 1.1 Add `DisplayFit` and `GameSettings` (name cleaning, fullscreen, scale, a ConfigFile at an injectable path) and verify GUT tests for 1080p windowed (2×), fullscreen (3×), fixed scale, a reload of saved settings and the name cleaning
- [x] 1.2 Add the `toggle_fullscreen` action (F11, Alt+Enter) and verify a GUT test of its events
- [x] 1.3 Verify the import, smoke run and GUT pass with zero error lines

## 2. Theme and title

- [ ] 2.1 Import both fonts crisp, add `game_theme.tres` with the tracked Kenney 9-slices (license, CREDITS row) as the project theme, and verify GUT tests that the theme is set, uses the two fonts at their sizes and only references tracked art
- [ ] 2.2 Add `TitleScreen` (buttons, focus description, animated sea, version) and verify GUT tests for the button list, first focus, the description of each button and its signals
- [ ] 2.3 Render the title at 1× and send the screenshot to the user for early feedback
- [ ] 2.4 Verify the import, smoke run and GUT pass with zero error lines

## 3. Shell flow

- [ ] 3.1 Add `GameShell` as the main scene with the title, settings, join and summary screens and the dev island run, and verify GUT tests for "solo from the title" (offline, no lobby, a player on the beach), the settings round trip, join-address validation, "end of a solo run" and Esc going back
- [ ] 3.2 Verify the import, smoke run, GUT and a 300-frame run pass with zero error lines

## 4. Lobby

- [ ] 4.1 Add the CoopSession lobby phase, `request_join`, the roster and `begin_run`, and verify ENet tests for "players spawn when the run starts", "two players meet", "client renames itself over and over", a join during a run, and that the existing coop-networking suites still pass
- [ ] 4.2 Add `LobbyScreen` and the host/join paths through the shell, and verify GUT tests for "host and start" and "host lost"
- [ ] 4.3 Verify the import, smoke run and GUT pass with zero error lines

## 5. HUD

- [ ] 5.1 Re-lay `MetersHud` with labels inside the bars and the critical pulse, add the phase label, the teammate list and `NameTag`, and verify GUT tests for "solo HUD", "critical thirst" and "teammate down"
- [ ] 5.2 Hide quick chat in solo and verify "no quick chat in solo" with one offline player
- [ ] 5.3 Remove the per-scene theme overrides, render the lobby and run HUD at 1×, and verify the playground tests still pass
- [ ] 5.4 Verify the import, smoke run, GUT, a 300-frame run and a two-process host and client run through the shell pass with zero error lines

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Add the ui-shell line to `TASKS.md` and a Done entry.
- Open the PR against `main` and get CI green; the user's other session merges it.
- Archive after the user answers the provisional decisions.
