# Proposal

## Why

Running `main` shows how the game looks today:
- The main scene is a bare "90 Millas" title. Hosting and joining go through a dev panel in Godot's default style.
- The fonts are imported with smooth-text settings (antialiasing, hinting, subpixel positioning), so the pixel fonts look soft.
- A window that is not a whole multiple of 640×360 shows the game at 1× in a black frame.
- Every screen styles itself.

The user found it "really small" and the UI "crappy". No spec or task owns the player-facing shell (review item 23). Every later screen (inventory, crafting, map, run summary) needs one theme, one screen flow and a HUD budget to fit into. So the shell comes before them.

The user asked to take the best-fitting ideas from the three reference games; design.md lists what was taken from each and what was rejected. These are ideas only: no code or assets from Shattered Pixel Dungeon, DCSS (GPL) or Brogue CE (AGPL-3.0).

## What Changes

- **Display (SPD, Brogue):**
  - The game keeps its 640×360 view with whole-number scaling.
  - At start the window opens at the largest multiple that fits the screen: 2× on a 1080p desktop, 3× in fullscreen.
  - F11 or Alt+Enter toggles fullscreen. A scale setting (auto, 1× to 4×) and the fullscreen choice are saved per install.
  - A "Filtro de píxeles" setting (the user's request, 2026-11-05): Nítido (default, today's look) or Suave, a Scale2x-style smoothing of the enlarged world only. The HUD and menus stay sharp, the base and whole-number scale stay, and the choice is per install and never synced.
- **One game theme** for every screen, set project-wide:
  - Fonts: Pixelify Sans at 16 and 32 px for buttons and titles, and Press Start 2P at 8 px for small text and the HUD. Both are imported crisp: no antialiasing, hinting or subpixel positioning.
  - Panels and buttons use a tracked copy of a few CC0 Kenney Pixel UI 9-slices: tan sand for dialogs, sea blue for buttons, sun yellow for focus. HUD panels are dark and see-through.
  - Keyboard and gamepad move focus everywhere.
- **The shell** becomes the main scene, with this screen flow:
  - Title (DCSS, SPD): a vertical menu ("Jugar solo", "Hospedar partida", "Unirse", "Ajustes", "Salir"), a panel describing the focused option, an animated sea behind the logo, and the version.
  - "Unirse" opens a join screen: address with an optional `:port`, connecting status and a failure message.
  - "Hospedar" and a successful join open the lobby. Solo goes straight to the run.
  - The run shows the HUD. When every player is dead, a run summary card appears (DCSS, Brogue), then the title.
  - "Ajustes" holds the player name, fullscreen, scale and pixel filter.
  - The host-lost screen is restyled into the flow.
- **The lobby is a phase of the co-op session.** Each client sends its player name once when it joins. The host sees the roster (up to four) and starts the run, and players spawn when it starts. A client that joins during a run spawns at once, as today. Solo has no lobby.
- **HUD within a 640×360 budget** (Brogue, DCSS, SPD):
  - Meters top-left: the label is inside the bar and the bar pulses when critical. Heat is inverted: high is bad.
  - Teammates top-right, co-op only: name, health and a state word.
  - Day phase top-centre.
  - A name and a thin health strip over each teammate's head, shown only when health is not full.
  - The bottom band and the screen centre stay free for the inventory and the world.
- **Quick chat is hidden in solo**, as the user decided (2026-11-05). The wheel neither shows nor reacts, and no bubble appears.
- **Esc** means "back" in menus and "pause" during a solo run.

**Provisional decisions to confirm:**
1. **Windowed at the largest whole-number scale that fits** (2× on 1080p with a taskbar), not fullscreen by default. F11 or Alt+Enter gives 3× fullscreen on 1080p. Should the first launch be fullscreen?
2. **Fonts:** Pixelify Sans 16/32 for titles and buttons, Press Start 2P 8 for small text and the HUD. Both were rendered and compared: Pixelify blurs below 16 and Press Start 2P is crisp at 8.
3. **Palette** from the Kenney pack: tan dialogs, sea-blue buttons, sun-yellow focus, a dark navy see-through HUD, and coral red for danger.
4. **Default player name** "Balsero", editable in Ajustes. Up to 16 characters. A blank or unprintable name falls back to "Balsero N".
5. **Run summary** shows each player's name, whether they died and how long the run lasted, then "Volver al inicio". The Cuban one-liner and the rest of the content stay with the Milestone B "death, run summary, restart" task.
6. **The run** is the dev beach island (the movement playground's terrain) until the handmade sandbar exists.
7. **A dead player in co-op** keeps watching the run; the run ends when every player is dead. Should the dead player spectate a teammate instead?
8. **Title flavour line** under the logo: "De Cuba a la Florida: 90 millas de mar."

**Left out (later changes):** DCSS's flashing gain/loss bar segments, an event log, hover info panels, a minimap, and the background picker in the lobby (no background content exists yet). SPD's variable viewport is rejected: the view stays 640×360.

## Capabilities

### New Capabilities

- `ui-shell`: the player-facing shell. Display scaling and fullscreen, the shared theme, the screen flow (title, join, lobby, run, summary, settings, host lost), the HUD layout budget and the per-install settings.

### Modified Capabilities

- `coop-networking`:
  - "Host and join" adds the lobby phase: players spawn when the host starts the run, and joiners during a run spawn at once.
  - "Quick chat" hides the wheel in solo.
  - "Intents reach only the host and act only for their sender" now also covers the join request that carries a player's name.
- `player-movement`:
  - "Camera and viewport" keeps nearest filtering by default and allows the optional smooth pixel filter setting.

## Impact

- **New:**
  - `game/scenes/shell/` (shell and screens)
  - `game/scenes/ui/` additions (theme, run HUD, teammate list, name tag)
  - `game/scripts/ui/` (display fit, settings, flow)
  - `game/assets/art/ui/` (tracked CC0 9-slices with their license)
  - `game/scenes/levels/dev_island.tscn`
- **Changed:**
  - `project.godot`: main scene, project theme, `toggle_fullscreen` action
  - both font `.import` files
  - `CoopSession`: lobby phase, roster, join request
  - the existing screens drop their own theme overrides
  - `MovementPlayground`'s terrain moves into a shared builder
  - `game/assets/CREDITS.md`
- **Removed:** `game/scenes/main/` (the placeholder title scene; the shell is the main scene now).
- **Docs:** `docs/ui-shell/` (pixel filter captures).
- **Tests:** GUT for display fit, settings, the flow, the lobby over ENet, the HUD and solo. A two-process run goes through the shell (title → host → lobby → start; title → join).
