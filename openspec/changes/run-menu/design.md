# Design

## Context

- **The pause menu today:** `PauseMenu` (`game/scenes/ui/pause_menu.gd`) is a `CanvasLayer` that `RunHud.bind` makes for every run.
  - It calls `CoopSession.set_paused`, which refuses unless `can_pause()` holds (the offline peer and one player). In co-op, pressing pause therefore shows nothing.
  - `RunHud.input_open()` already refuses HUD input while `pause_menu.visible`, so the strip, the prompt and the crafting list are blocked by the menu whatever the mode.
  - The crafting list and the sign note take the `pause` press in `_input` before the menu sees it, so the "a panel closes first" rule already holds.
- **Player input:** `PlayerInput.build_intent()` reads `Input` straight into the body's `MoveIntent` each physics frame. On a client, `PlayerNet` sends that intent to the host.
  - Turning `PlayerInput.enabled` off would leave the last intent in place, so the player would keep walking.
  - `PlayerBody.hud_holds_interact` is already used by HUD panels to hold the interact press.
- **The shell:** `GameShell` builds the HUD in `_enter_run` and frees it in `_check_run_over`. `_show()` replaces the screen and changes `flow`.
  - If a run's Ajustes went through `_show()`, the flow would leave `RUN`. `_check_run_over` would then return early, and a co-op run that ends behind the settings would be missed.
- **Sibling work:**
  - hud-clarity owns `run_hud.gd` (objective row, clock, Calor row). This change does not edit it.
  - The crossing branch rewrites `rescue_point.gd`; that file belongs to menu-clarity's vessel words, not here.
- **Fonts:** menu-clarity's font group lands first, so every window here is sized once, in Press Start 2P 8 px for body and buttons and Pixelify for tabs and headings.

## Goals / Non-Goals

**Goals:**
- One menu, one window and one set of keys in every mode. The mode changes only whether the simulation freezes, and the tab and line that say so.
- Esc never closes two layers at once, and never opens the menu from a screen that is not the run.
- The Controles card is drawn from the input map, so it cannot disagree with the bindings.
- Every piece is tested with exactly 1 player, offline. The co-op menu is tested with a host and a client in one process (ShellHarness) and in two processes on UDP 7801.

**Non-Goals:**
- Rebinding keys, glyph sets for other gamepads, and a volume or language setting (MN-10 is its own change).
- Save-and-quit. Abandoning ends the run; nothing is kept.
- Hints, placeholders and nudges from the parked `controls-onboarding` proposal.
- Numbering duplicate names in a lobby (MN-03's last part): a follow-up (owner, 2026-11-23).

## Decisions

### D1. The pause menu grows into the run menu in place

`PauseMenu` keeps its class name, its scene and its place under `RunHud`, so `run_hud.gd` needs no edit. It gains:
- a "Menú" or "Pausa" tab, and the "La partida sigue." line;
- four buttons, plus a `Views` stack (confirm, settings, controls) inside the same `PROCESS_MODE_ALWAYS` layer;
- signals the shell connects after `hud.bind()`: `abandon_confirmed`, `display_changed` and `flashes_changed`;
- a `settings` field the shell sets.

`open()` asks `session.set_paused(true)`, which succeeds only in solo. Whatever the answer, the menu shows. In co-op it also sets `menu_holds_input` on the local body. `resume()` undoes both.

- **Alternative: a new `RunMenu` scene beside `PauseMenu`.** Rejected: it would need `run_hud.gd` edits (its `PAUSE_SCENE`, `pause_menu` and `input_open`) in hud-clarity's file, and the name buys nothing.
- **Alternative: the shell's own screens (`_show`).** Rejected: they leave `Flow.RUN` (see Context), and in solo the paused tree would freeze them.

### D2. Held input in co-op

`PlayerBody.menu_holds_input: bool`, beside `hud_holds_interact`. While it is set, `PlayerInput.build_intent()` returns:
- no direction, no run and no interact;
- the crouch of the body's last intent, so a crouched player stays hidden.

The intent still goes to the host every frame, so the host sees a player standing still, not a stalled client.

- **Alternative: `PlayerInput.enabled = false`.** Rejected, because the last intent sticks.
- **Alternative: let go of crouch.** Rejected: opening a menu in brush would give the player away, and DST's idle player does not stand up either.

### D3. Esc and back close one layer

The menu handles `pause` and `ui_cancel` in one `_unhandled_input`, checks either action once per event, and marks the event handled:
- with a view open, it closes the view and focuses the button that opened it;
- otherwise, it resumes.

The embedded settings screen handles `ui_cancel` itself (its `_back`) and marks the event handled first, because Godot hands `_unhandled_input` to the deepest node first. Then Start, which is `pause` but not `ui_cancel`, still reaches the menu and closes the view. A test presses Esc twice and checks one layer per press.

`ui_cancel` never opens the menu, since the gamepad B button is also crouch.

### D4. The dark run look

`MenuLook.to_run(root)` (`game/scripts/ui/menu_look.gd`) walks a screen and swaps its paper variations for the run look:
- the default panel becomes `HudPanel`;
- `PanelLabel` becomes the cream `Label`;
- `PanelHeading` becomes `HeadingLabel`;
- `CheckBox` becomes a new `HudCheckBox` with cream text;
- `PaperInset` becomes `HudPanelTight`.

The settings screen and the Controles card are built once, on paper, and turned dark by this call in a run. That is the review's rule (MN-01) in one place.

- **Alternative: second dark copies of the scenes.** Rejected: two copies drift apart.

`SettingsScreen.hide_name()` hides the name row in a run, since the session has already sent the name.

### D5. Abandonar viaje by role

The question is a `ConfirmBox` (`game/scenes/ui/confirm_box.gd/.tscn`): a question, a line, "Cancelar" (focused) and an action button. It is built on paper and turned dark by `MenuLook`. menu-clarity's lobby close reuses it.

The confirm's line is picked from the session:
- solo: "Este viaje se pierde.";
- host: "La partida se cierra para todos.";
- client: "Sales de la partida. Tu balsero espera 90 s por si vuelves."

On "Abandonar" the shell's `back_to_title()` runs for every role: it ends the run, then `NetManager.leave()` (with `get_tree().paused = false` first, as `_end_run` does).
- Host: the clients' existing host-lost path shows "Conexión perdida".
- Client: the host's existing disconnect handling keeps the body for 90 s.

So no new message and no RPC is needed. "Cancelar" has the focus, so an accept press that is still held, or a double press, keeps the run (DCSS's `yesno` defaults to no).

### D6. The Controles card

`ControlsCard` (`game/scenes/shell/controls_card.gd/.tscn`) is a paper panel with:
- the heading "Controles";
- a three-column `GridContainer` (action, "Teclado", "Mando");
- "Volver".

Its rows are a const table. Each row has:
- a Spanish label;
- the actions whose keyboard labels it joins: the four walk actions give "W A S D"; crouch gives its two keys, "Ctrl / C";
- the actions for the gamepad column;
- `range`, for the slot keys, which give "1 … =".

Labels come from `InputLabels.label_for` and `HudText`'s button names, read when the card opens. A few named keys get short words (`KEY_ESCAPE` "Esc", `KEY_SHIFT` "Mayús", the arrows "↑ ↓"). Press Start 2P has no arrow glyphs, so the build checks those glyphs and falls back to "Arriba"/"Abajo" if they are missing. `for_run(solo)` hides the quick chat row in a solo run; the title shows it marked "(en grupo)".

### D7. The first-launch name window

`GameSettings` gains `name_asked`, saved under `[player] name_asked`. A file without it reads false.

`GameShell.show_title()` opens the title's `NamePrompt` when `player_name == DEFAULT_NAME and not name_asked`.
- The prompt is a paper window over the menu.
- The title's buttons give up the focus while it is open.
- "Listo" or Enter saves `player_name` (cleaned by the existing setter; blank keeps the default) and `name_asked = true`. Esc saves only `name_asked`.

An install with a chosen name never sees it. An outside join replaces the title; since `name_asked` is still false, the next title asks.

The tests and `smoke.gd` start from fresh settings, so the window opens in any test that shows the title through the shell. Those tests mark the settings as asked first. `test_title_screen.gd` builds the title alone and sees no window.

### D8. The host-lost screen

`_ready()` focuses "Volver". `_unhandled_input` turns `ui_cancel` into `back_requested`. The message gets a second line: "Vuelve al inicio para unirte otra vez o jugar solo."

Its `Message` label moves from `HeadingLabel` to the body label, because menu-clarity limits Pixelify to headings. The shell's `_on_host_lost` calls `hud.pause_menu.resume()` before it adds the screen, so a menu left open neither keeps the focus nor holds the input.

## Reference games (ideas only)

**Shattered Pixel Dungeon** (`core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`)
- **Borrowed:**
  - `GameScene.onBackPressed()` opens `windows/WndGame.java` (`WndGame`) only when nothing else is open to cancel. That is our "a panel closes first".
  - `WndGame` builds its buttons from state; we change only the tab and one line between solo and co-op.
  - `WndSettings` and its `InputTab` open the same window from `TitleScene.SettingsButton` and from the run. Our settings and card are likewise built once and reached from both places.
  - `WndKeyBindings` is one class, with a boolean for keyboard or controller. We use one card with two columns instead of two pages, since the 640×360 view fits both.
- **Rejected:**
  - `WndGame` has no Resume button (back closes it). We keep "Seguir" so a gamepad has a visible way back.
  - `WndKeyBindings` swallows back so that edits are not lost. We have no edits, so back always works.
  - `WelcomeScene`'s first-run flow is version-driven. We key on the name instead.

**DCSS** (`crawl/crawl-ref/source/`)
- **Borrowed:**
  - `class GameMenu` in `main.cc` (`process_command(CMD_GAME_MENU)`) puts "Return to game" first, with Esc as its key, and "abandon character" last, set apart.
  - `CMD_QUIT` asks first, and `yesno` (prompt.cc) defaults to no. Our confirm focuses "Cancelar".
  - `show_help` and `_add_formatted_keyhelp` (command.cc) print each key through `command_to_string`, so the help follows rebinding. The card reads the input map the same way.
  - `_choose_name` (newgame.cc) asks only when the name is empty, and `is_good_name` (ng-input.cc) checks it as it is typed. Our window asks only while the name is the default, and the existing `clean_name` setter cleans it.
- **Rejected:**
  - `confirm_prompt` makes the player type a word, which a gamepad cannot do.
  - The Random name button and the empty-name-means-random rule: a blank keeps "Balsero", which the owner's default already is.

**Brogue CE** (`BrogueCE/src/brogue/`)
- **Borrowed:**
  - `IO.c` `actionMenu` leaves toggles open in place (`takeActionOurselves`). Ajustes changes apply at once, with the menu still open.
  - `confirm` (IO.c) treats N and Esc as no. Esc in our confirm is "Cancelar".
- **Rejected:** `actionMenu` opens from a bottom-bar button, not Esc; our Esc and Start must open it.

**Don't Starve Together** (`docs/REFERENCE_DST.md`, "Host pause" and "When a player disconnects"; wiki pages "Don't Starve Together" and "Dedicated Server")
- **Borrowed:**
  - The online game goes on while a player is in a menu. We do the same, and say so with "La partida sigue.".
  - A player who leaves keeps their items in the world. Our client's "Abandonar" is a disconnect, so the existing 90 s wait and the item drop apply.
- **Rejected:** the host pause with a banner for every peer. The owner's no-pause-in-co-op rule stands; the notes keep it as the fallback if playtests ask for it.
- **Not in our notes:** DST's own controls screen (keyboard and controller tabs) and its disconnect screen. The wiki pages that would cover them ("Controls", "Options") were not read, so nothing is taken from them.

## Risks / Trade-offs

- **Two shells share `Input`, focus and `get_tree().paused`.** ShellHarness tests can't fully hold one shell's keys apart from another's. → The co-op hold test sets `menu_holds_input` through the client shell's menu and checks the host's copy of the body. The UDP 7801 two-process run checks real keys.
- **A client in the menu still takes damage**, as DST players do. → The co-op tab and line say the game goes on. That is the honest rule, not a bug.
- **Test churn from the name window.** Shell tests that show the title would find it open. → One helper marks fresh test settings as asked. `test_suite_integrity.gd` catches a suite that stops parsing.
- **GUT time is near CI's limit.** → The new suites are pure scene tests, under 5 s each. There is one ShellHarness test, not one per scenario.
- **The `feat/controls-onboarding` proposal also has a Controles screen** (as an F1 overlay). → The owner chose (2026-11-23) that this card replaces its overlay and its pause rows; its hints and placeholders stay parked.

## Owner answers (2026-11-23)

The owner picked the recommended option on each question:
- **Abandonar viaje** goes straight out: solo to the title with no summary, the host closes the game for everyone, a client leaves as a disconnect.
- **The first-launch name window** shows once per install; Esc skips it.
- **The Controles card** replaces the parked controls-onboarding overlay.
- **Follow-ups stay follow-ups:** numbering duplicate names in a lobby, tie-down in squalls and MN-10.

## Migration Plan

Settings files from before this change have no `name_asked`.
- Any install already named something else never sees the window.
- An install still named "Balsero" sees it once.

Nothing else is stored. The change archives after hud-window-kit and the archive PR #67, as the proposal says.
