# Tasks

## 1. The note

- [ ] 1.1 Tests first in `game/tests/unit/test_sign_note.gd`:
  - `open(sign)` shows the sign's Spanish line and "[E] Cerrar".
  - In English it shows the English line and "[E] Close", and with a gamepad "[A] Close".
  - The card sits at (200, 22), 240 px wide, with its height fitted to the text.
  - The card overlaps none of the meters, the day phase, the teammate list, the inventory band or the centre (the ui-shell scenario).
  - Every sign line in `game/resources/islands/*.tres` wraps to at most 8 lines in both languages (design D5).
  - See them fail, then pass.
- [ ] 1.2 Add the `HudNote` and `HudNoteText` theme variations, the `close_note` line in `hud_text.tres` (and its id in `test_hud_text.gd`), and `game/scenes/ui/sign_note.gd/.tscn`. Verify: 1.1 passes.

## 2. Opening and closing

- [ ] 2.1 Tests first: a 1-player test in `test_coast_cay_solo.gd` replaces the bubble check.
  - The player stands beside the dead radio and presses E (the `interact` action): the note opens.
  - The clock keeps running.
  - Walking 2 tiles away closes the note.
  - E again closes it, and nothing is picked up.
  - Esc closes it without pausing, and a second Esc pauses.
  - F with a rain cup selected uses nothing while the note is open.
  - Going down closes it.
  - See them fail, then pass.
- [ ] 2.2 Implement:
  - `InteractPrompt.sign_pressed`.
  - `RunHud` opens `%SignNote`, routes pause to it first, passes `set_screen_shown`, and makes the note hold interact (`hud_holds_interact`).
  - Remove `IslandSign._on_interacted` and `CoopSession.show_sign` (design D4).
  - Verify: 2.1 passes, and the crafting list and prompt tests still pass.
- [ ] 2.3 Host-plus-client test in `test_interact_prompt_net.gd` (or a new net test): when the host reads a slogan, the host's note opens and the client's HUD has none. When the client reads the radio, the client's note opens and the host's has none. No sign RPC is sent. Verify: passes.

## 3. Checks

- [ ] 3.1 Update the manual harness `game/tests/manual/art_pass_run.gd`: the sign step checks the note (open, text, closes on walking away) instead of the bubble. Run it solo in a window and save a capture of the note to `docs/art-pass/`, a window capture at 1×. Look at the capture.
- [ ] 3.2 Run the import (twice), the smoke run and GUT, and `openspec validate sign-note-panel --strict`. Run the game once through the Godot MCP and read a sign. Update `TASKS.md`.

## Workflow follow-up

- Archive after the owner's review.
- Later, outside this change: a journal of read signs (SPD's Documents), and a message log for short look-at lines (Brogue's `flavorMessage`).
