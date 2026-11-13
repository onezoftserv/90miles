# Tasks

## 1. The note

- [x] 1.1 Tests first in `game/tests/unit/test_sign_note.gd`:
  - `open(sign)` shows the sign's Spanish line and "[E] Cerrar".
  - In English it shows the English line and "[E] Close", and with a gamepad "[A] Close".
  - The card sits at (200, 22), 240 px wide, with its height fitted to the text.
  - The card overlaps none of the meters, the day phase, the teammate list, the inventory band or the centre (the ui-shell scenario).
  - Every sign line in `game/resources/islands/*.tres` wraps to at most 8 lines in both languages (design D5).
  - See them fail, then pass.
  - Done 2026-11-13: test_sign_note.gd, 7 tests (open text and close line in es, en and gamepad; card at (200,22), 240 wide, fitted height; light card with dark text at 7:1 or more; text inside the card; clear of the phase, meters, teammates, strip and centre; every sign line of every layout in both languages in at most 8 lines). Seen failing, then passing.
- [x] 1.2 Add the `HudNote` and `HudNoteText` theme variations, the `close_note` line in `hud_text.tres` (and its id in `test_hud_text.gd`), and `game/scenes/ui/sign_note.gd/.tscn`. Verify: 1.1 passes.
  - Done 2026-11-13: HudNote and HudNoteText in game_theme.tres, close_note in hud_text.tres and HudText.LINES (test_hud_text.gd checks LINES), scenes/ui/sign_note.gd/.tscn with SignNote.wrap_count. 7/7 pass.

## 2. Opening and closing

- [x] 2.1 Tests first: a 1-player test in `test_coast_cay_solo.gd` replaces the bubble check.
  - The player stands beside the dead radio and presses E (the `interact` action): the note opens.
  - The clock keeps running.
  - Walking 2 tiles away closes the note.
  - E again closes it, and nothing is picked up.
  - Esc closes it without pausing, and a second Esc pauses.
  - F with a rain cup selected uses nothing while the note is open.
  - Going down closes it.
  - See them fail, then pass.
  - Done 2026-11-13: five 1-player tests in test_coast_cay_solo.gd replace the bubble check: open on E with the clock running, walking 2 tiles away, E closes with nothing picked up, Esc then Esc, F with a rain cup, going down. Seen failing, then passing.
- [x] 2.2 Implement:
  - `InteractPrompt.sign_pressed`.
  - `RunHud` opens `%SignNote`, routes pause to it first, passes `set_screen_shown`, and makes the note hold interact (`hud_holds_interact`).
  - Remove `IslandSign._on_interacted` and `CoopSession.show_sign` (design D4).
  - Verify: 2.1 passes, and the crafting list and prompt tests still pass.
  - Done 2026-11-13: InteractPrompt.sign_pressed, RunHud wiring (open, pause and interact first, set_screen_shown, hud_holds_interact, list_open so the prompt hides and F does nothing), IslandSign._on_interacted and CoopSession.show_sign removed. test_coast_cay_solo.gd 17/17.
- [x] 2.3 Host-plus-client test in `test_interact_prompt_net.gd` (or a new net test): when the host reads a slogan, the host's note opens and the client's HUD has none. When the client reads the radio, the client's note opens and the host's has none. No sign RPC is sent. Verify: passes.
  - Done 2026-11-13: new test_sign_note_net.gd (2 tests, host and client, each on its own coast cay): the reader gets the note, the other HUD none, no show_sign method, no bubbles. 2/2 pass.

## 3. Checks

- [x] 3.1 Update the manual harness `game/tests/manual/art_pass_run.gd`: the sign step checks the note (open, text, closes on walking away) instead of the bubble. Run it solo in a window and save a capture of the note to `docs/art-pass/`, a window capture at 1×. Look at the capture. Done 2026-11-13: the sign step checks the note (open, line, close line, no bubble, closes on walking away) and saves a window capture; solo coast cay run in a window 29 of 29; `docs/art-pass/coast_cay_sign_note.png` is the window at 2× (1280×720), the crossed sticks' line on 3 lines with "[E] Cerrar", looked at.
- [x] 3.2 Run the import (twice), the smoke run and GUT, and `openspec validate sign-note-panel --strict`. Run the game once through the Godot MCP and read a sign. Update `TASKS.md`. Done 2026-11-13: import 0 error lines, smoke 10 frames 0 problems, GUT 173 scripts 1543 of 1543 (after group 2; since then only the manual harness changed, which parses), change valid. The game was played in a window through the harness instead of the Godot MCP: it read the crossed sticks and walked away. `TASKS.md` updated.

## Workflow follow-up

- Archive after the owner's review.
- Later, outside this change: a journal of read signs (SPD's Documents), and a message log for short look-at lines (Brogue's `flavorMessage`).
