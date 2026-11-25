# Tasks

Build after menu-clarity's group 1 (fonts) is merged, so each window here is sized once in the settled fonts. Every test with players starts with exactly 1 player, offline, and uses `UserTmp.path()` for any file. Godot: `/c/Users/liann/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe --path game`.

## 1. Held input and the run menu

- [x] 1.1 Test first (`test_pause.gd`, `test_run_menu.gd`): solo opens "Pausa" with four buttons and freezes; a host alone and a co-op session open "Menú" with "La partida sigue." and do not freeze; "Seguir" resumes; Esc closes one layer at a time (confirm, settings, controls, then the menu); `ui_cancel` never opens the menu; the crafting list still takes pause first.
- [x] 1.2 `PlayerBody.menu_holds_input` and `PlayerInput.build_intent()`: no direction, run or interact while held, crouch kept from the last intent (test with 1 player: walk east crouched, hold, step frames, the body has not moved and is still crouched).
- [x] 1.3 `pause_menu.gd/.tscn`: tab and line by mode, the four buttons, the `Views` stack, `open()` that always shows and freezes only when `set_paused` allows, the local body's hold set and cleared, D3's single-layer Esc.
- [x] 1.4 The abandon confirm: question, role line (solo, host, client), "Cancelar" focused, "Abandonar" emits `abandon_confirmed`.
- [x] 1.5 `game_shell.gd`: after `hud.bind()`, hand the menu the settings and connect `abandon_confirmed` to `back_to_title`, `display_changed` and `flashes_changed`; `_on_host_lost` resumes an open menu first (test: solo abandon reaches the title offline with no summary and the tree unpaused).
- [x] 1.6 Import, smoke run and GUT pass.

## 2. Ajustes in a run and the dark look

- [x] 2.1 Test first (`test_menu_look.gd`): `MenuLook.to_run` turns the settings screen's panel into `HudPanel`, its labels cream, its check boxes `HudCheckBox`, and every label still reaches 4.5:1 on the dark window.
- [x] 2.2 `game/scripts/ui/menu_look.gd` and the `HudCheckBox` theme variation (palette colours only).
- [x] 2.3 `SettingsScreen.hide_name()`; the run menu embeds the settings, dark, nameless; a change saves and applies at once; Esc returns to the menu with "Ajustes" focused (1-player test).
- [x] 2.4 Import, smoke run and GUT pass.

## 3. The Controles card

- [x] 3.1 Test first (`test_controls_card.gd`): rows read from the input map (interact "E" / "A", menu "Esc" / "Start", move "W A S D" / "Palanca izq."); rebinding interact to F shows "F"; the title's quick chat row is marked "(en grupo)", a solo run's card has none; Esc and "Volver" emit `back_requested`.
- [x] 3.2 `controls_card.gd/.tscn` (paper), the named-key words, and a check that Press Start 2P draws the arrows (else "Arriba"/"Abajo").
- [x] 3.3 The title's "Controles" button between "Ajustes" and "Créditos" with its description; the shell shows the card on paper and Esc returns to the title with "Controles" focused (`Flow.CONTROLS`).
- [x] 3.4 The run menu's "Controles" opens the card dark, inside the 640×360 view (1-player test of its rect).
- [x] 3.5 Import, smoke run and GUT pass.

## 4. First-launch name and host lost

- [x] 4.1 Test first (`test_first_launch_name.gd`): a fresh settings file opens the window with the field focused; "Dayana" + Enter saves it and focuses "Jugar solo"; Esc keeps "Balsero"; both set `name_asked`, and a second shell on the same file opens no window; a saved "Yuni" with no `name_asked` opens none; an outside join replaces the title and the next title asks.
- [x] 4.2 `GameSettings.name_asked`, `name_prompt.gd/.tscn`, the title's `ask_name()`, the shell's check in `show_title()`; mark fresh settings as asked in the shell test helpers that show the title.
- [x] 4.3 Host lost: focus "Volver", `ui_cancel` = Volver, the next-step line, the body label (extend `test_menu_windows.gd` and `test_game_shell.gd`).
- [x] 4.4 Import, smoke run and GUT pass.

## 5. Co-op checks

- [x] 5.1 ShellHarness test (`test_run_menu_net.gd`): a host and a client in a run; the client opens the menu, nothing pauses, and within 0.2 s the host's copy of the client's body stands still; closing lets it move; the host's "Abandonar" sends the client to the host-lost screen with "Volver" focused; a client's "Abandonar" leaves the host listing it "Desconectado".
- [x] 5.2 Two processes on UDP 7801 (`game/tests/manual/run_menu_run.gd`, modes host and client): the client opens the menu with real input, the host's clock and player keep going, the client abandons, the host's HUD shows "Desconectado"; 0 engine errors on both.
- [x] 5.3 Captures at 640×360 (scaled 2×): solo menu, co-op menu, confirm, Ajustes dark, Controles dark and on paper, the name window, host lost.
- [x] 5.4 `TASKS.md` and `docs/CONTROLS.md` (if it lists the pause button's job) updated; import, smoke run and GUT pass.
