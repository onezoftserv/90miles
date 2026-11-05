# Design

## Context

See proposal.md for why. What exists on `main`:
- `scenes/main/main.tscn` (a title label).
- `CoopSession` (spawners, intents, quick chat, solo pause).
- `NetManager.host()/join()/start_solo()`.
- The survival-meters HUD (`MetersHud`, `MeterBar`, `hud_theme.tres` with Press Start 2P 8).
- `HostLostScreen`, `PauseMenu`, `QuickChatWheel`, `SpeechBubble`, each with its own theme sub-resource.
- Two dev playgrounds.

Settings in `project.godot`: a 640×360 viewport, stretch mode `viewport` with `integer` scaling, and a 1280×720 window override. Both fonts are imported with antialiasing, hinting and subpixel positioning on.

## What we took from the reference games

These are ideas only, from reading the code. No code or assets came from these GPL/AGPL projects.

**Shattered Pixel Dungeon:**
- *Integer zoom chosen from the window* (`PixelScene`). We keep the fixed 640×360 view and choose the window's whole-number scale the same way. SPD's variable virtual size is rejected: it would change every layout.
- *Vertical title menu over a moving background* (`TitleScene`, `TitleBackground`).
- *A compact status pane in a corner with thin pre-shaded bars and a red pulse when low* (`StatusPane`).
- *9-patch window chrome*: centred dialogs, 18 px buttons, disabled buttons at 30% alpha (`Window`, `Chrome`, `WndOptions`).
- *Teammate health strips over heads, shown only when not full* (`CharHealthIndicator`).

**Brogue CE:**
- *Bars with the label inside, readable over both the filled and the empty part* (`IO.c` `printProgressBar`).
- *A list in which teammates come first, each with a state word* (`refreshSideBar`).
- *F11 or Alt+Enter for fullscreen* (platform code).
- *Amber/yellow focus highlight*.
- Its stretch-to-fit, non-square cells are rejected.

**DCSS:**
- *One description panel that follows the focused menu item* (`outer-menu.cc`), used on the title screen.
- *A popup with the screen behind it dimmed* (`newgame.cc`).
- *Status colours*: yellow → orange → red for trouble (`status.cc`).
- *An end-of-run card per player* (`end.cc`).
- Deferred: its grouped background picker (no background content yet) and its gain/loss bar segments.

## Goals / Non-Goals

**Goals:**
- The game fills the screen at a whole-number scale.
- Every screen shares one theme, with crisp text.
- Title → solo/host/join → lobby → run → summary works with keyboard and gamepad.
- The lobby gathers names and starts the run without breaking mid-run joins.
- The HUD fits 640×360 and follows the solo rules.

**Non-Goals:**
- Inventory, crafting and map screens (they arrive with their own changes and fit into the HUD budget).
- An event log, hover panels and a minimap.
- Background choice.
- Audio and localisation settings.
- Reconnect identity (coop-reconnect extends the join request below).

## Decisions

### Display: whole-number fit, applied once by the shell
`DisplayFit.best_scale(area, base = 640×360)` returns `max(1, min(⌊w/640⌋, ⌊h/360⌋))`. On a 1920×1040 usable area it is 2; on a 1920×1080 fullscreen it is 3.

`GameShell._ready()` applies the settings:
- fullscreen → `WINDOW_MODE_FULLSCREEN`;
- otherwise the window size is `base × (fixed scale, or best_scale(usable screen))`, centred.

Godot's integer `stretch` then draws at that scale with black bars. The `toggle_fullscreen` action (F11, Alt+Enter) is handled by the shell and saved. Under the headless display server (smoke run, CI) nothing touches the window.

The dev playgrounds keep the project's 1280×720 window, which is 2×.

### Pixel filter: the world in its own 640×360 view, smoothed only when asked

- **The world renders in a 640×360 `SubViewport`.** The shell's `World` lives inside it, shown by a `SubViewportContainer` (`WorldView`) at the top-left of the 640×360 canvas.
  - A SubViewport does not take the project's render settings, so it sets them itself: 2D transform snapping, nearest default filter, an opaque clear in the project colour, and a redraw every frame.
  - The HUD, the screens and the host-lost screen stay outside it, on the root canvas.
- **Nítido (default)** keeps the root window in `viewport` stretch mode: the whole 640×360 picture is enlarged by the window with nearest filtering, exactly as before. The capture script checks that this is pixel-identical to the picture before the change.
- **Suave** switches the root to `canvas_items` stretch mode, still with integer scaling and black bars. The world view is then drawn at the window's resolution, and its material runs `scale2x.gdshader` per screen pixel:
  - It takes the world texel under the pixel and its four edge neighbours, and applies the Scale2x/EPX rules to pick the colour of the texel's quarter.
  - At 3× and 4× each quarter is more than one pixel, so it is Scale2x enlarged with nearest.
  - The shader is written from the published rules (Eric Johnston's EPX, Andrea Mazzoleni's Scale2x description); no reference code was used, so it needs no CREDITS row.
- **What gets smoothed:** world-space marks (name tags, speech bubbles) are part of the world, so Suave smooths them too. The HUD and menus never are.
- `PixelFilter` (`scripts/ui/pixel_filter.gd`) maps a mode to the root stretch mode, root font oversampling and the world view's material. The shell applies it on start and whenever a setting changes, headless too, so tests check it.
- **Checked by capture** (`tests/manual/capture_pixel_filter.tscn`, 2× window, solo run on the dev island):
  - Nítido after the change against Nítido before it: 0 of 921,600 pixels differ.
  - Suave against Nítido: only world pixels differ (corners and the player's outline); the HUD is identical.
  - The captures are in `docs/ui-shell/`.

### Settings: one ConfigFile per install
`GameSettings` loads and saves `user://settings.cfg`; tests inject the path. Fields:
- `player_name`, cleaned by `GameSettings.clean_name()`: control characters stripped, 16 characters at most, "Balsero" when blank;
- `fullscreen`;
- `ui_scale`: 0 is automatic, 1 to 4 is fixed.

It is a plain RefCounted that the shell owns, so no new autoload is needed.

### Theme: one project theme, tracked art, crisp fonts
- **Theme file:** `scenes/ui/theme/game_theme.tres`, set as `gui/theme/custom`.
- **Fonts:** default Press Start 2P 8. Pixelify Sans 16 for `Button`, `LineEdit` and the type variations `TitleLabel` (32) and `HeadingLabel` (16). Both font `.import` files are switched to antialiasing none, hinting none and no subpixel positioning.
- **Panels:**
  - tan 9-slice (`Panel`, `PanelContainer`);
  - `HudPanel`: dark navy at 75%, 1 px light border.
- **Buttons:**
  - normal: sea-blue 9-slice, pressed: sea-blue pressed;
  - focus: a 1 px sun-yellow frame;
  - disabled: 30% alpha.
- **Art:** the three 9-slice PNGs are copied from the Kenney Pixel UI Pack (CC0) into `assets/art/ui/` with its `License.txt`, a CREDITS row and committed `.import` files. Nothing points into the git-ignored `assets/kenney/`.
- **Clean-up:** the per-scene theme sub-resources (wheel, pause, playground panel) and `hud_theme.tres` go away, so everything inherits.

### Screen flow: a shell that swaps screens and keeps the session
`scenes/shell/game_shell.tscn` is the main scene and owns two layers:
- `Screens`: a CanvasLayer; one screen at a time, swapped by the shell.
- `World`: a Node2D holding the level and the `CoopSession` during a run.

Flow states: TITLE, JOIN, LOBBY, RUN, SUMMARY, SETTINGS, HOST_LOST.

Screens emit intent signals (`solo_requested`, `host_requested`, `join_requested(address, port)`, `back_requested`, ...). The shell alone calls `NetManager` and creates the session. This keeps screens testable without a network.

- **Solo:** `start_solo()`, a session with `start()`, straight to RUN.
- **Host:** `host()`, then the session is created in LOBBY phase.
- **Join:** `join()`; on `joined` the session starts as a client and shows LOBBY or RUN, whichever the host's phase says.
- **Esc** is "back" on every menu screen. During a solo run it goes to `PauseMenu`, which still checks `can_pause()`.

### The lobby is a phase of CoopSession
- **Phase:** `CoopSession.phase` is LOBBY or RUN. `start(lobby := false)`. In LOBBY the host does not spawn on `peer_connected`. `begin_run()` (host only) switches to RUN, spawns every connected peer at the spawn points, and tells clients `run_begun()` (authority RPC). In RUN, `peer_connected` spawns at once, as today.
- **Names:** `request_join(name)` is `any_peer`, reliable and host-only. It is accepted once per peer, a cleaned name is stored in `roster`, and `roster_changed(roster)` is broadcast (authority). Later requests from the same peer are ignored, so a client cannot make the host flood roster updates.
- **Joining:** clients call `request_join` as soon as their session starts on a connected peer. The host adds its own name directly.
- **Reconnect:** coop-reconnect adds a player id and secret to the same request.

### HUD: one run HUD inside a 640×360 budget
`scenes/ui/run_hud.tscn` (a CanvasLayer) is added by the shell in RUN:

| Region | Rect | Contents |
| --- | --- | --- |
| Top-left | 4,4 · 104×86 | `MetersHud`: six 96×10 bars, label and value inside each bar (Brogue), a 1 Hz red pulse when critical (SPD) |
| Top-centre | 220,4 · 200×14 | day phase in Spanish ("Amanecer", "Día", "Mediodía", "Atardecer", "Noche") from `ClimateState` |
| Top-right | 532,4 · 104×… | co-op only: one row per teammate (name, 64×4 health bar, state word "Caído", "Muerto" or "Desconectado"), teammates in join order |
| Bottom band | 0,320 · 640×40 | reserved for the inventory (nothing drawn yet) |
| Centre | | the world, always clear |
| Overheads | | `NameTag` on each teammate's body: name in 8 px plus a 16×1 health strip, health strip only when health < 100 |

Critical means: heat ≥ 75, or any other meter ≤ 25. `MeterBar.is_critical()` is pure and tested. The quick-chat wheel lives in the HUD; in solo it is not added at all, so neither the button nor bubbles do anything. The pause menu stays as it is (solo only).

### Run summary
When every player in the session is dead (`SurvivalMeters.dead`), the host announces the end with `run_ended(summary)` (authority RPC, a list of `{name, dead}`, plus the run length from the session clock). Every peer then shows `SummaryScreen`. In solo the shell shows it directly.

### Tests and checks
- **Pure:** `DisplayFit`, `GameSettings` (temporary path), `MeterBar.is_critical`, `JoinScreen` address parsing.
- **Screens:** instantiated alone: focus, descriptions and signals.
- **Shell:** stepped by calling its intent handlers. Solo uses the offline peer; host and join use `NetHarness` branches with a lobby session.
- **Lobby (ENet):** spawn timing, the once-per-peer join request, joiners during a run.
- **Screenshots:** a scratch script renders the title, lobby and run HUD at 1× and they are reviewed by eye. They are no test, but the first one goes to the user before the rest is built.
- **Two processes:** a host and a client through the shell.

## Risks / Trade-offs

- **The spawn timing change could break the coop-networking ENet suites.** → `start()` defaults to RUN, which keeps every current caller and test on today's behaviour; only the shell asks for the lobby.
- **Removing per-scene themes changes how the playgrounds and the existing screens look.** → Their tests check text and behaviour, not pixels; screenshots are reviewed.
- **The fixed 640×360 view leaves black bars at sizes that are not multiples** (1366×768 shows 2× with bars). → That is the cost of crisp pixels; the fullscreen toggle helps.
- **Suave renders the root canvas at the window's resolution.** With font oversampling on, the HUD's text would be redrawn by the font at the enlarged size, and its 1 px shadows come out thinner. → Suave turns oversampling off on the root (`PixelFilter.font_oversampling`), so the 8 px glyphs are enlarged like every other HUD pixel. The captures show the HUD pixel-identical in both modes.
- **Moving `World` into a SubViewport changes the node path of every networked node.** → Host and client both run the shell, so the paths still match. The two-process run through the shell checks it.
- **Two fonts.** → Each is used where it is crisp (Pixelify at 16 and 32, Press Start 2P at 8), and the rendered comparison is in the PR.
- **A joiner refused because the lobby or run is full sees "host lost"** (the host drops the peer, and the client cannot tell why). → Accepted for now. coop-reconnect's handshake adds a refusal reason ("partida llena") before the disconnect.
- **A peer that connects but never sends its join request holds a slot without appearing in the lobby.** → It spawns as "Balsero N" when the run starts. coop-reconnect's handshake times out peers that never identify.
