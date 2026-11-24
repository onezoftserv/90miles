# Design

## Context

- **Fonts:** `game_theme.tres` sets Press Start 2P 8 px as the default font. Its `Button`, `CheckBox`, `LineEdit`, `OptionButton`, `PopupMenu`, `ErrorLabel`, `CreditsLabel`, `HeadingLabel` and `TitleLabel` entries use `menu_font.tres` (Pixelify Sans with `spacing_space = 2`) at 16 or 32 px. The host-lost `Message` label uses `HeadingLabel` for a body line.
- **The summary:**
  - `SummaryScreen` always shows the scene's heading, "Fin del viaje", and a `PaperInset` scroll at least 200 px tall.
  - `SummaryRow` hides the one-liner for survivors. `RunSummary._survivor` gives them `line = ""`.
  - Its buttons are plain `Button`s, which fire on release, so an A button held through death fires "Otra vez" the moment it is let go (MN-05).
- **Host failure:** `GameShell._show_host_failure` writes the failure into `title.description`, which `_describe` rewrites on the next focus or mouse move (MN-07).
- **The lobby:**
  - `LobbyScreen` lists names only. It has one leave button, "Salir", which for the host ends the lobby for everyone at once.
  - The host's addresses come after the port note.
  - The shell knows whether a lobby is a rematch (`_rematch`, `_on_rematch_called`), but does not tell the lobby.
- **Crossing prompts:** `InteractPrompt.head_parts` takes the target from `Interactable.prompt_target`, and falls back to `HudText.prompt_label(id)`. That gives "a la balsa" for every vessel. The crossing branch (`claude/crossing-gameplay-shark-hud`) rewrites `RescuePoint.prompt_target`, so that function is off limits here.

## Goals / Non-Goals

**Goals:**
- Settle Q16 in the theme alone. Scenes keep their variations, and only the theme's font lines change.
- Every new word on screen fits 640×360 in Press Start 2P 8 px, checked by rect tests and captures.
- Survivor lines are content, loaded and picked by the same code as death lines.

**Non-Goals:**
- The "continuará" scene after crossing 2, a keepsake, a best time (G6), and the settings' volume and descriptions (MN-10).
- Showing the tie-down prompt only in squalls (H19's second half). That is crossing behaviour, left to the crossing session.
- Numbering duplicate names in the lobby (MN-03's last part).

## Decisions

### D1. Q16 lives in the theme

In `game_theme.tres`, the font entries move to Press Start 2P (`2_small`) at 8 for `Button`, `CheckBox`, `LineEdit`, `OptionButton`, `PopupMenu`, `ErrorLabel` and `CreditsLabel`. `HeadingLabel`, `PanelHeading` (through its base) and `TitleLabel` keep `menu_font.tres` at 16 and 32. `menu_font.tres` stays, for headings only.

The host-lost `Message` label becomes a body `Label` (run-menu D8). With the smaller text, buttons are shorter: the title's seven buttons get `custom_minimum_size.y = 20` so they stay easy targets, and the captures check the rest.

- **Alternative: Pixelify with redrawn digits (Q16 b).** The owner chose (a).

### D2. Survivor lines reuse the death-lines loader

`DeathLines` gets a second content id. `DeathLines.from_catalog(catalog, id := CONTENT_ID)` loads any line set keyed by state, and `line_for(state, seed, nth)` already falls back to `other`.

`RunSummary.collect` takes a second set, `arrival_lines`. A survivor's entry gets:
- `line`, the text;
- `line_id`, the line's id (`arrival_raft_1`);
- `route_id`.

`nth` counts the earlier survivors on the same route, as `_add_dead` counts causes.

`DialogueData.Kind` gains `SURVIVOR_LINES`, appended so stored ints stay valid. The new file `game/resources/dialogue/survivor_one_liners.tres` has these states:
- `raft`, with 4 lines;
- `binoculars_swim`, with 2;
- `other`, with 2.

The lines are handwritten in the narrator's Cuban voice, and none swears, so none needs a soft variant. A content test checks the states, the line lengths and the soft-variant rule, as `test_death_lines.gd` does for death lines.

- **Alternative: a `survived` state in `death_one_liners.tres`.** Rejected: "Death one-liners" pins that file at 20 lines.

### D3. The heading by the local fate

`SummaryScreen.show_summary(made, restart_text, local_peer)` sets the heading:
- "Llegaste" when the entry whose `peer` is `local_peer` is alive and has a `route`;
- "Fin del viaje" otherwise, including when no entry is the local player's (a removed client).

The shell passes `session.multiplayer.get_unique_id()`. The words live in `SummaryScreen` consts; the menu headings stay in standard Spanish, while the one-liners carry the voice.

### D4. Hidden empty totals and a fitted inset

`ExtrasRow` is split into two labels that each hide at zero: `Companions` while saved and lost are both 0, and `Texts` while found is 0. The row hides when both do.

The scroll's minimum height becomes 0. It grows with its rows up to a cap of 200 px, set in `show_summary` from the rows' combined minimum height. The panel is centred with anchors, so the card shrinks with its content.

### D5. The 0.8 s gate

`SummaryScreen` keeps `shown_at_s`, read from an injectable `clock: Callable` (as `GameShell.clock` is), and `ACCEPT_DELAY_S = 0.8`.
- Both buttons' `pressed` go through `_on_restart` and `_on_home`, which drop a press before the gate.
- For the gate's length the buttons are also `focus_mode`-kept but set to `mouse_filter = IGNORE`, and an `_input` hook marks `ui_accept` handled, so a release is dropped, not queued.
- Tests set `clock` and check a press at 0.3 s and at 1 s. They never wait on the wall clock (a timing flake is already on record in `test_secret_net.gd`).

- **Alternative: disable the buttons for 0.8 s.** Rejected: a disabled button drops the focus ring and greys out, which reads as broken. SPD's `WndHardNotification` disables its button only with a countdown on it.
- **Alternative: an "any key" whitelist after a delay**, as Brogue's `gameOver` does. Not needed, because our summary has real buttons.

### D6. The title's error band

`TitleScreen` gets a `Status` label (`ErrorLabel`), hidden, under the description panel. `show_error(text)` shows it. `_describe` never touches it, and it goes with the title when the title is left. The shell's `_show_host_failure` calls `show_error` instead of writing `description.text`.

### D7. Lobby seats, rematch line and the host's confirm

- `LobbyScreen.SEATS = 4`. `show_roster` fills four rows (filled seats first, then "Libre" in a dimmed colour) and sets the heading to "A bordo (%d/4)".
- The addresses label moves above the note. The `Tu IP:` line is in Press Start 2P, so the digits read clearly.
- `LobbyScreen.rematch: bool`, set by the shell in `_rematch` (host) and `_on_rematch_called` (client), shows a line under the heading.
- The host's button text becomes "Cerrar partida", while the opening lobby keeps "Salir", as "Screen flow" says.
- `back_requested` from the host's button goes through `_ask_close()`:
  - with more than one seat filled, a small `Confirm` box replaces the buttons row, holding the question, "Cerrar" and "Cancelar" (focused). Esc in the box cancels.
  - otherwise it emits at once.
- The confirm box is the same piece run-menu's abandon question uses (`ConfirmBox`, `game/scenes/ui/confirm_box.gd/.tscn`), built once and styled paper or dark by `MenuLook`. If run-menu lands first, this change reuses it; otherwise this change adds it, and run-menu reuses it.

### D8. Vessel words

`InteractPrompt.vessel_key(on)` returns the route's vessel as a lowercase key (`raft`, `car`, `board`) when `on` is a `RescuePoint` with a live crossing and route, and "" otherwise.

`head_parts` looks up `prompt_labels["<id>.<vessel>"]` first, then `prompt_labels[id]`. `hud_text.tres` gains:
- `tie_down.car` ("al almendrón", "to the car");
- `untie.car` ("del almendrón", "from the car");
- `climb_aboard.car` ("al almendrón", "aboard the car");
- `climb_aboard.board` ("a tu tabla", "onto your board").

The raft keeps the plain keys. Reading the crossing from the prompt side leaves `rescue_point.gd` alone, for the crossing branch.

- **Alternative: a `prompt_vessel()` override on `RescuePoint`.** Cleaner, but it is a hunk in a file under active rewrite. Moving the key into `RescuePoint` later is a two-line follow-up.
- **Alternative: build the phrase from `name_es`.** Rejected: Spanish contracts the article ("al almendrón", "del almendrón"), so the phrase must be written out whole.

### D9. Credits

`CreditsScreen.entry_text` drops the per-entry "Licencia: …" line. The CC BY heading becomes two lines: "Con licencia CC BY 4.0" and the address.

A `More` label, "▼ Más abajo", sits under the scroll. It is visible while `scroll_vertical` plus the view's height is less than the list's height, and is updated on the scroll bar's `value_changed` and after `show_credits`. If Press Start 2P lacks "▼", the label reads "v Más abajo", checked by a glyph test.

The makers' group waits for names and wording from the owner (owner, 2026-11-23); this change lists each licence once and adds no makers' group.

## Reference games (ideas only)

**Shattered Pixel Dungeon** (`core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`)
- **Borrowed:**
  - `RankingsScene.Record` marks a win with a warm flare and the amulet, and a death with a tomb. Our win and death differ in heading and line; there are no icons yet.
  - `windows/WndHardNotification.java` keeps its OK button from working until a countdown ends. That is the idea behind the 0.8 s gate, without the visible countdown, which is too short to need one.
  - `scenes/AmuletScene.java` disables both buttons after the first press, against double transitions. The lobby confirm and the gate guard the same moment.
- **Rejected:** `WndKeyBindings`' swallowed back press. Esc always works on our screens.

**DCSS** (`crawl/crawl-ref/source/`)
- **Borrowed:** `end.cc` `end_game` shows a gravestone tile for a death and a dungeon-exit tile for a win in the same popup. That is the same layout with one telling difference, which is our heading.
- **Rejected:**
  - Its popup closes on any key, which is exactly MN-05's problem.
  - `more()` after death does not flush input (`user_forced` is false, so `flush_input_buffer` in message.cc does not run). We gate instead.

**Brogue CE** (`BrogueCE/src/brogue/`)
- **Borrowed:**
  - `RogueMain.c` `gameOver` and `victory` are deliberately different screens: a dark fade with the death line, against a white fade with congratulations. Our "Llegaste" and its one-liner are the small version of that.
  - `gameOver` continues only on space, Esc or a click. We keep it to the focused button, after the gate.
  - `confirm` (IO.c) treats Esc as no. Esc on the lobby confirm is "Cancelar".

**Don't Starve Together** (`docs/REFERENCE_DST.md`, "When everyone is dead", "When a player disconnects"; wiki pages "Death/DST", "Don't Starve Together")
- **Borrowed:** a server host who leaves ends the world for everyone, and clients drop to their menus. That is why the host's "Cerrar partida" asks first while others are aboard, and a host alone does not.
- **Not in our notes:** DST's end-of-world and death screen UI and its lobby seat display. Our notes cover only the world reset, so nothing is taken from those screens.

## Risks / Trade-offs

- **Narrower buttons and text** can change layouts that tests measure (`test_menu_windows.gd`, `test_theme.gd`, `test_fonts.gd`). → Group 1 updates those tests first, and captures check each screen at 640×360.
- **Press Start 2P is wide**, so long lines wrap more: the lobby note, the title descriptions and the summary rows. → The panels autowrap already; the captures check for overflow.
- **`hud_text.tres` is shared** with hud-clarity, which may add lines. → New keys go in alphabetical order inside `prompt_labels`, so a merge conflict stays a one-line hunk.
- **The heading by local fate** (owner, 2026-11-23: each peer reads its own fate) reads oddly for a removed client who rejoins after the run (none can today). → "Fin del viaje" is the fallback.

## Migration Plan

No stored data changes. The change archives after hud-window-kit, damage-feedback and the archive PR #67. Their requirements are the base of this change's MODIFIED blocks ("Shared theme", "Readable HUD and menu text", "Menu windows" and "Settings").
