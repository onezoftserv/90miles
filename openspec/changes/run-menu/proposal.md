# Proposal

## Why

The Fable review of 2026-11-22 (MN-01, MN-03, MN-06, priority 4) found that a run has no way out, the settings cannot be reached from a run, co-op has no menu at all, and nothing anywhere lists the controls. Every new player also plays as "Balsero", since nothing asks for a name. The pause menu has one button, "Seguir", and coop-networking "Pause" refuses it in co-op. The owner chose the review's recommended options on 2026-11-23.

## What Changes

- **A run menu in every mode.** The pause button (Esc, gamepad Start) opens one menu: "Seguir", "Ajustes", "Controles" and "Abandonar viaje".
  - **Solo:** it freezes the simulation, as the pause menu does today. Its tab reads "Pausa".
  - **Co-op:** it opens without freezing anything. The tab reads "Menú", a line says "La partida sigue.", and while it is open the local player's input is held. Their player stands still, keeps a crouch they were holding, and takes no interact or item press. The host simulates them as usual.
- **Ajustes in a run:** the settings open inside the run menu, in a dark window (the review's dark-in-run, paper-in-shell rule). Changes apply and save at once. The name field is left out, since a name only changes between runs.
- **Abandonar viaje asks first:** "¿Abandonar el viaje?", with "Cancelar" focused and "Abandonar" beside it. The line under the question says what happens in each role:
  - solo goes to the title;
  - the host closes the game for everyone, and each client sees the host-lost screen;
  - a client leaves as a disconnect does, so their player waits 90 s in case they come back.
- **Esc closes exactly one layer.** With the confirm, Ajustes or Controles open, Esc and the gamepad back button close that view; with only the menu open, they close the menu. The pause button only opens the menu. It still closes an open crafting list or sign note first, as now.
- **A Controles card**, reached from the title (a new "Controles" button between "Ajustes" and "Créditos") and from the run menu.
  - It lists each control with its keyboard key and its gamepad button, read from the input map, so the card never drifts from the bindings.
  - Quick chat shows only where co-op is possible: on the title it is marked "(en grupo)", and a solo run hides it.
- **First launch asks for a name.** While the name is still the default "Balsero" and the install has never been asked, the title opens a small window: "¿Cómo te llamas?", a text field and "Listo". Whatever is typed is cleaned and saved; a blank keeps "Balsero". Esc skips. Either way the install is not asked again; "Ajustes" still changes the name. A join from outside the game is never held up by the prompt.
- **Host lost takes the focus.** The host-lost screen focuses "Volver", answers Esc and the gamepad back button, and says what to do next. The host-lost screen also closes an open run menu first.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`, "Pause": the pause button opens the run menu in every mode. Only solo freezes. Co-op holds the local player's input while the menu is open and pauses nothing.
- `ui-shell`:
  - "Title screen" gains "Controles" and the first-launch name window.
  - "Pause and host-lost windows" (from hud-window-kit) becomes the run menu's window in every mode, with its confirm and views, and host-lost takes the focus and Esc.
  - Adds "Run menu", "Controles card" and "First-launch name".

## Impact

- **Changed:**
  - `game/scenes/ui/pause_menu.gd/.tscn`: the run menu. The class name `PauseMenu` stays, so `run_hud.gd` is untouched.
  - `game/scenes/ui/host_lost_screen.gd/.tscn`;
  - `game/scenes/shell/title_screen.gd/.tscn`, `game_shell.gd` and `settings_screen.gd`;
  - `game/scripts/ui/game_settings.gd`, which keeps `[player] name_asked`;
  - `game/scripts/player/player_input.gd` and `game/scenes/player/player.gd`, which get one field: `menu_holds_input`, beside `hud_holds_interact`.
- **New:**
  - `game/scenes/shell/controls_card.gd/.tscn`;
  - `game/scenes/shell/name_prompt.gd/.tscn`;
  - `game/scripts/ui/menu_look.gd`, which swaps a paper screen's theme variations to the dark run look;
  - a `HudCheckBox` theme variation.
- **Tests:** 1-player tests for each piece; a host-plus-client ShellHarness test that the menu pauses nothing and holds the client still; a two-process run on UDP 7801.
- **Not touched:** `run_hud.gd` (hud-clarity's), the crossing scripts, `coop_session.gd`, the network messages. No new autoload and no RPC.
- **Ordering:**
  - This change archives after hud-window-kit, which adds "Pause and host-lost windows", and after the archive PR #67 (coop-rematch, dead-spectate).
  - It builds after menu-clarity's font group, so each new window is measured once in the settled fonts.
  - It narrows the parked `controls-onboarding` proposal (branch `feat/controls-onboarding`, never built). That proposal's F1 overlay and pause rows give way to this card, and it keeps its hints and placeholders for when it is picked up.
