## MODIFIED Requirements

### Requirement: Title screen
The title screen SHALL show the logo over an animated sea, the buttons "Jugar solo", "Hospedar partida", "Unirse", "Ajustes", "Controles", "Créditos" and "Salir", a panel describing the focused button, and the game version. The first button has focus on arrival, unless the first-launch name window is open over the menu.

#### Scenario: Focus describes the option
- **GIVEN** the title screen
- **WHEN** the focus moves to "Hospedar partida"
- **THEN** the description panel explains hosting and that others join by IP on UDP port 7777

#### Scenario: Credits offered offline
- **GIVEN** a solo player on the title screen, offline, with no session
- **WHEN** the focus moves to "Créditos"
- **THEN** it sits between "Controles" and "Salir", the description panel says it lists who made the game's art and fonts and under which licences, and no network port is opened

#### Scenario: Controls offered offline
- **GIVEN** a solo player on the title screen, offline, with no session
- **WHEN** they pick "Controles"
- **THEN** the Controles card shows on paper, no network port is opened, and Esc returns to the title with "Controles" focused

### Requirement: Pause and host-lost windows
The run menu and the host-lost screen SHALL show their title and buttons in one dark window centred in the view, over the dimmed run, with the title on a tab on the window's top edge and every button inside the window. The run menu shows in every mode (ui-shell "Run menu"). The host-lost screen shows only to clients. It closes an open run menu, takes the focus on "Volver", treats Esc and the gamepad back button as "Volver", and says what to do next.

#### Scenario: Solo pause in a window
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player presses Esc
- **THEN** a dark window centred in the 640×360 view shows the "Pausa" tab, "Seguir", "Ajustes", "Controles" and "Abandonar viaje", with focus on "Seguir", and the window lies inside the view

#### Scenario: Host lost
- **GIVEN** a client in a run with its run menu open
- **WHEN** the host disconnects
- **THEN** the run menu closes, the host-lost line, the next step and "Volver" show inside one centred dark window with its title tab, and "Volver" has the focus

#### Scenario: Esc leaves the host-lost screen
- **GIVEN** a client showing the host-lost screen
- **WHEN** the player presses Esc
- **THEN** the title shows and the game is offline

## ADDED Requirements

### Requirement: Run menu
The run menu SHALL offer "Seguir", "Ajustes", "Controles" and "Abandonar viaje", with "Seguir" focused when it opens. Its tab reads "Pausa" in solo and "Menú" in co-op, where a line under it says "La partida sigue.". "Ajustes" and "Controles" open inside it in the dark run look, and Ajustes holds every setting but the name. Esc and the gamepad back button close one layer: an open view, else the menu. Solo and co-op show the same buttons.

#### Scenario: Solo menu
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player presses Esc
- **THEN** the menu shows "Pausa" and the four buttons with "Seguir" focused, and the simulation is frozen

#### Scenario: Co-op menu
- **GIVEN** a host with a client in a run
- **WHEN** the host presses Start on the gamepad
- **THEN** the host's menu shows "Menú", the line "La partida sigue." and the same four buttons, and nothing pauses

#### Scenario: Settings from a run
- **GIVEN** a solo run with the run menu open
- **WHEN** the player picks "Ajustes" and ticks "Reducir destellos"
- **THEN** the setting is saved and applies at once, the view is a dark window with no name field, and Esc returns to the menu with "Ajustes" focused

#### Scenario: Esc closes one layer
- **GIVEN** a solo run with the run menu open on "Controles"
- **WHEN** the player presses Esc twice
- **THEN** the first press returns to the menu and the second closes it and resumes the run

#### Scenario: Seguir
- **GIVEN** a solo run with the run menu open
- **WHEN** the player picks "Seguir"
- **THEN** the menu closes and the run goes on from where it stopped

### Requirement: Abandoning a run
"Abandonar viaje" SHALL ask "¿Abandonar el viaje?" with "Cancelar" focused beside "Abandonar", and a line for the player's role. Confirming ends this player's run with no summary. Solo returns to the title, offline. A host closes the game for everyone, and their clients show the host-lost screen. A client leaves as a disconnect does: its player waits 90 s for a rejoin (coop-networking "Disconnect handling"). "Cancelar", Esc and the gamepad back button return to the menu.

#### Scenario: Solo abandons
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player picks "Abandonar viaje" and then "Abandonar"
- **THEN** the title shows, no summary was shown, the game is offline, and the simulation is no longer frozen

#### Scenario: Cancel keeps the run
- **GIVEN** a solo run with the confirm showing
- **WHEN** the player presses Enter at once
- **THEN** "Cancelar" was focused, so the menu shows again and the run is kept

#### Scenario: The host abandons
- **GIVEN** a host with a client in a run
- **WHEN** the host confirms "Abandonar"
- **THEN** the host shows the title and the client shows the host-lost screen

#### Scenario: A client abandons
- **GIVEN** a host with a client named Papo in a run
- **WHEN** Papo confirms "Abandonar"
- **THEN** Papo's game shows the title, and the host's HUD lists Papo as "Desconectado" while his player waits

### Requirement: Controles card
A Controles card SHALL list each control with its keyboard key and its gamepad button, read from the input map when it opens: moving, running, crouching and diving, interacting, using the item, picking an item, the crafting list, quick chat, the menu and fullscreen. It opens from the title on paper and from the run menu in the dark run look. Esc, the gamepad back button and "Volver" close it. On the title quick chat is marked "(en grupo)", and a solo run leaves it out.

#### Scenario: The card in a solo run
- **GIVEN** a solo run, offline, with exactly 1 player and the run menu open
- **WHEN** the player picks "Controles"
- **THEN** the card shows "Interactuar" with "E" and "A", "Menú" with "Esc" and "Start", no quick chat row, in a dark window inside the 640×360 view

#### Scenario: The card follows the bindings
- **GIVEN** the interact action bound to F instead of E
- **WHEN** the card opens from the title
- **THEN** its interact row shows "F"

#### Scenario: Quick chat on the title
- **GIVEN** the title screen
- **WHEN** the card opens
- **THEN** the quick chat row reads "Chat rápido (en grupo)" with "Q" and "RB"

### Requirement: First-launch name
While the player name is "Balsero" and this install has never been asked, the title SHALL open a name window over the menu: "¿Cómo te llamas?", a text field with the focus and "Listo". "Listo" or Enter saves the cleaned name, and a blank keeps "Balsero". Esc skips. Either way the install is marked as asked and never asked again; "Ajustes" still changes the name. A join from outside the game goes ahead, and the window waits for a later title.

#### Scenario: A first launch, solo
- **GIVEN** a fresh install, offline, with exactly 1 player
- **WHEN** the title shows
- **THEN** the name window is open with the text field focused, and no title button has the focus

#### Scenario: A name given
- **GIVEN** the name window on a first launch
- **WHEN** the player types "Dayana" and presses Enter
- **THEN** the name is "Dayana" and saved, the window closes, "Jugar solo" has the focus, and the next launch opens no window

#### Scenario: Skipped
- **GIVEN** the name window on a first launch
- **WHEN** the player presses Esc
- **THEN** the name stays "Balsero", the window closes, and the next launch opens no window

#### Scenario: A name already chosen
- **GIVEN** an install whose saved name is "Yuni" from before this change
- **WHEN** the title shows
- **THEN** no name window opens
