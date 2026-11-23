# Tasks

Group 1 builds first, then run-menu, then groups 2 to 5. Every test with players starts with exactly 1 player, offline, and uses `UserTmp.path()` for any file. Godot: `/c/Users/liann/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe --path game`.

## 1. Fonts (Q16)

- [ ] 1.1 Test first (`test_theme.gd`, `test_menu_windows.gd`): buttons, check boxes, dropdowns and popups, text fields, error and credits labels are Press Start 2P at 8; `HeadingLabel`, `PanelHeading` and `TitleLabel` stay Pixelify at 16 and 32; the join field draws "192.168.1.70" in Press Start 2P; the "Word gaps" check measures the summary's heading only.
- [ ] 1.2 `game_theme.tres` font lines; the title's buttons at least 20 px tall; the host-lost `Message` as a body label.
- [ ] 1.3 Captures at 640×360 of the title, settings, join (failed), lobby, credits and summary; fix any overflow.
- [ ] 1.4 `docs/ASSETS.md` (fonts line) and `TASKS.md`: Q16 settled (owner, 2026-11-23); import, smoke run and GUT pass.

## 2. Win and death

- [ ] 2.1 Test first (`test_run_summary.gd`, `test_survivor_lines.gd`): with run seed 0 a solo raft survivor gets `arrival_raft_1` and the heading "Llegaste"; a solo thirst death keeps `death_thirst_1` and "Fin del viaje"; two raft survivors get `_1` and `_2`; an unknown route uses `arrival_other_1`; the content check (states, at least 2 lines each, at most 120 characters, soft variant when swearing); no "Compañeros" or "Textos" line at zero, and "Compañeros: 1 salvados, 0 perdidos" with one saved.
- [ ] 2.2 `DialogueData.Kind.SURVIVOR_LINES`, `survivor_one_liners.tres` (8 lines, Spanish and English, Cuban voice), `DeathLines.from_catalog(catalog, id)`, `RunSummary` survivor lines, `SummaryRow` showing them.
- [ ] 2.3 `SummaryScreen`: heading by local fate, hidden empty totals, fitted inset, centred panel; the shell passes the local peer.
- [ ] 2.4 Test first: the 0.8 s gate with an injected clock (press at 0.3 s dropped, focus kept; at 1 s works; a mouse click inside the gate dropped); then the gate.
- [ ] 2.5 Host-plus-client ShellHarness check that a split party shows "Llegaste" on the host and "Fin del viaje" on the client, with the same rows; import, smoke run and GUT pass.

## 3. Failures on red bands

- [ ] 3.1 Test first (`test_game_shell.gd`): with the port taken, hosting shows the reason on the title's red band, and focusing every button and moving the pointer leaves it unchanged.
- [ ] 3.2 `TitleScreen.show_error()` and its `Status` label; `GameShell._show_host_failure` uses it.
- [ ] 3.3 Import, smoke run and GUT pass.

## 4. The lobby

- [ ] 4.1 Test first (`test_lobby_screen.gd`): four seats with "Libre", "A bordo (1/4)" and "(2/4)", addresses before the note, the rematch line, "Cerrar partida" for the host and "Salir" while opening and for a client, the confirm with "Cancelar" focused only while someone else is aboard, Esc in the confirm cancels.
- [ ] 4.2 `lobby_screen.gd/.tscn`, `ConfirmBox` (reuse run-menu's if merged), the shell's rematch flag.
- [ ] 4.3 ShellHarness test (`test_coop_rematch_net.gd` or a new `test_lobby_seats_net.gd`): after "Otra vez" both lobbies show the rematch line and "A bordo (2/4)"; the host's "Cerrar partida" asks, "Cerrar" sends the client to host-lost.
- [ ] 4.4 Two processes on UDP 7801 (`run_menu_run.gd` mode `lobby`): a client joins, both print the seat rows, the host confirms the close, the client shows host-lost; 0 engine errors.
- [ ] 4.5 Import, smoke run and GUT pass.

## 5. Credits and vessel words

- [ ] 5.1 Test first (`test_credits_screen.gd`): the CC BY address appears exactly once; each CC BY entry still has "CC BY 4.0" and its source; the "▼ Más abajo" cue at the top of a long list and gone at its end; the labels are Press Start 2P at 8.
- [ ] 5.2 `credits_screen.gd/.tscn`; the makers' group only if the owner gives names.
- [ ] 5.3 Test first (`test_vessel_prompts.gd`, 1 player): a crossing built with a car route shows "[E] Amarrarse al almendrón", tied "[E] Soltarse del almendrón"; a raft "[E] Amarrarse a la balsa"; a board's climb point "[E] Subir a tu tabla"; a vessel with no words of its own reads the raft's.
- [ ] 5.4 `InteractPrompt.vessel_key` and the label lookup; the `hud_text.tres` keys.
- [ ] 5.5 Captures (summary win and death, lobby with seats and confirm, title with the error band, credits, car prompt); import, smoke run and GUT pass; `TASKS.md` updated.

## 6. Volumen in Ajustes (sound-pass owner decision Q1 A, 2026-11-23)

sound-pass owns the level: the `[audio] volume` settings key in `game_settings.gd` and `AudioManager.set_volume`. This group adds only the row. If this branch lands before sound-pass, the key name is agreed through the coordinator first, and the row ships with it.

- [ ] 6.1 Test first (`test_display_settings.gd` or `test_settings_volume.gd`, 1 player, `UserTmp.path()`): a fresh settings screen shows "Volumen 80 %"; stepping down three times shows 50 %, saves it, and calls the volume setter each step; a second load of the same file reads 50 %; the row is in the dark in-run Ajustes too.
- [ ] 6.2 The "Volumen" row in `settings_screen.gd/.tscn` (a left/right stepper or an `HSlider` with step 10, focusable by keyboard and gamepad), wired to the settings and `AudioManager.set_volume`.
- [ ] 6.3 Import, smoke run and GUT pass.
