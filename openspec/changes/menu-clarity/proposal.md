# Proposal

## Why

The Fable review of 2026-11-22 (priorities 9 and 10; MN-04, MN-05, MN-07, MN-08, MN-09, MN-12, H19) found menus that say less than they should:
- A win and a death show the same card.
- The gamepad A button can skip the summary.
- A host failure is written into the hover text and erased by the next mouse move.
- A rematch lobby looks like a fresh one, with no seat count, and the host's "Salir" ends it for everyone without asking.
- Digits in the address field are ambiguous in Pixelify Sans.
- The credits are a wall of repeated licence addresses.
- The car's crossing prompt calls it "la balsa".

The owner settled the font question (Q16) on 2026-11-23: Press Start 2P for body text, fields and controls, and Pixelify Sans only for the logo and headings.

## What Changes

- **Fonts (Q16 settled):**
  - Buttons, check boxes, dropdowns and their lists, text fields, error lines, the credits and every body line use Press Start 2P at 8 px.
  - Pixelify Sans stays only on the logo (32 px) and on headings and window tabs (16 px).
  - Digits in the join address, the lobby's IP and the settings read unambiguously.
- **Win and death look different.** The summary's heading follows the local player's own fate: "Llegaste" for a player who left by a route, "Fin del viaje" for one who died. Solo is the one player.
- **Survivor one-liners.** A survivor's row gets a Cuban one-liner, as a death's does. The lines are content: a new dialogue `survivor_one_liners.tres` with one state per route and an `other` state, picked by the run seed exactly as death lines are.
- **Empty totals are hidden.** The "Compañeros" and "Textos" line shows only once there is something to count, so today it never shows. The list inset fits its rows instead of filling the card.
- **The summary can't be skipped by a held button.** For 0.8 s after it shows, its buttons take no press from the keyboard, gamepad or mouse. The focus is already on the first button, and nothing pressed meanwhile is queued.
- **Host failure on a red band.** A failure to host shows on the title as an error line in cream on a red band, as Join's does, and stays until the title is left. The hover description is left alone.
- **The lobby:**
  - The heading counts who is aboard, "A bordo (2/4)", over four seat rows, with empty seats reading "Libre".
  - The host's IP comes first, above the port note.
  - A lobby opened by "Otra vez" says "Otro viaje con el mismo grupo.".
  - The host's leave button reads "Cerrar partida". While anyone else is aboard it asks first, with "Cancelar" focused: "¿Cerrar la partida? Los demás vuelven al inicio."
- **Credits:**
  - The licence's address is shown once, under the CC BY heading, and each entry keeps "(CC BY 4.0)", its author and its source.
  - A "▼ Más abajo" cue shows while more of the list lies below.
  - The text is Press Start 2P at 8 px.
- **Vessel words in crossing prompts (H19).** Tie down, untie and climb aboard name the route's own vessel with its article, from the HUD text: "Amarrarse al almendrón" on the car, "a la balsa" on the raft, "a tu tabla" on a board.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ui-shell`:
  - "Shared theme", "Readable HUD and menu text" and "Menu windows" (all from hud-window-kit) get the fonts and the title's error band;
  - "Lobby" gets the seats, the count, the IP first, the rematch line and the host's confirm;
  - "Settings" names "Cerrar partida" in its Esc rule.
- `endings-progression`:
  - "Run summary", "Cause of death on the run summary" and "Run summary totals" get the survivor one-liner and the hidden empty totals;
  - adds "Run summary heading", "Survivor one-liners" and "No skipping the summary".
- `inventory-hud`: adds "Vessel words in crossing prompts".
- `art-pass`: "Credits screen" shows the licence address once, adds the scroll cue, and uses the body font.

## Impact

- **Theme and fonts:** `game/scenes/ui/theme/game_theme.tres` (font lines only); `game/scenes/shell/title_screen.tscn` (button heights, the error band).
- **Summary:** `summary_screen.gd/.tscn` and `summary_row.gd`; `game/scripts/run/run_summary.gd`; `death_lines.gd`, made general enough to load another set; `game/scripts/data/dialogue_data.gd` gains one Kind, `SURVIVOR_LINES`, appended.
- **New content:** `game/resources/dialogue/survivor_one_liners.tres`.
- **Lobby and shell:** `lobby_screen.gd/.tscn`, `game_shell.gd` (host failure, rematch flag), `title_screen.gd`.
- **Credits:** `credits_screen.gd/.tscn`.
- **Crossing prompts:** `game/scenes/ui/interact_prompt.gd` (a vessel key read from a crossing's rescue point); `game/resources/hud_text.tres` (new `prompt_labels` keys such as `tie_down.car`). `rescue_point.gd` is not edited, because the crossing branch rewrites it.
- **Tests:** 1-player tests for each piece. A host-plus-client ShellHarness test for the rematch lobby's seats and the host's confirm, and its two-process run on UDP 7801 (shared with run-menu's run, mode `lobby`).
- **Ordering:**
  - Archives after hud-window-kit, damage-feedback (its "Settings") and the archive PR #67 (coop-rematch).
  - Group 1 (fonts) builds first, then run-menu, then groups 2 to 5.
- **No new autoload, no RPC, no network message.**
