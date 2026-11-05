# Spec Delta

## Purpose

The player-facing shell of 90 Millas: how the game fills the screen, the shared look of every screen, the flow from the title through a run and back, the HUD layout at 640×360, and the settings each install keeps.

## ADDED Requirements

### Requirement: Display scaling
The game SHALL draw its 640×360 view at the largest whole-number scale that fits the window, with nearest filtering and black bars for the rest. At launch the window opens at the largest multiple that fits the usable screen, or fullscreen if the player chose it, unless a fixed scale (1× to 4×) is set. F11 or Alt+Enter toggles fullscreen at any time. Solo and co-op behave the same.

#### Scenario: Launch on a 1080p desktop
- **GIVEN** a 1920×1080 screen whose usable area is 1920×1040
- **WHEN** the game launches windowed with the automatic scale
- **THEN** the window is 1280×720 and the view is drawn at 2×

#### Scenario: Fullscreen on a 1080p screen
- **WHEN** the player presses F11
- **THEN** the game goes fullscreen and the view is drawn at 3×, and pressing F11 again returns to the window

#### Scenario: Fixed scale
- **GIVEN** the scale setting is 1×
- **WHEN** the game launches windowed
- **THEN** the window is 640×360

### Requirement: Shared theme
Every screen SHALL use one theme: Pixelify Sans at 16 or 32 px for titles and buttons, Press Start 2P at 8 px for small text, both drawn without smoothing; tan panels, sea-blue buttons with a sun-yellow focus frame, and see-through dark panels over the world. Player-facing text is Spanish first. Keyboard and gamepad move the focus on every screen.

#### Scenario: A new screen
- **WHEN** a screen is added without styling of its own
- **THEN** it shows the game's fonts, panels and buttons

#### Scenario: Crisp text
- **WHEN** any text is drawn
- **THEN** its pixels are whole (no smoothing between font pixels)

### Requirement: Screen flow
The game SHALL open on the title screen. Solo goes straight to a run, with no lobby and nothing waiting for another player. Hosting opens the lobby; joining opens the join screen, then the lobby, or the run if one is under way. When every player is dead the run summary shows, then the title. Losing the host shows the host-lost screen, then the title.

#### Scenario: Solo from the title
- **GIVEN** the title screen
- **WHEN** the player picks "Jugar solo"
- **THEN** a run starts with their player on the beach, no network port is open and no lobby is shown

#### Scenario: Host and start
- **GIVEN** the title screen
- **WHEN** the player picks "Hospedar partida" and then "Empezar viaje" in the lobby
- **THEN** a co-op run starts with every player in the lobby spawned on the beach

#### Scenario: Join a run under way
- **GIVEN** a host whose run has started
- **WHEN** a player joins from the join screen
- **THEN** the joiner goes straight to the run and spawns on the beach

#### Scenario: End of a solo run
- **GIVEN** a solo run
- **WHEN** the player dies
- **THEN** the run summary shows, and "Volver al inicio" returns to the title

#### Scenario: Host lost
- **GIVEN** a client in a run
- **WHEN** the host disconnects
- **THEN** the host-lost screen shows, and "Volver" returns to the title

### Requirement: Title screen
The title screen SHALL show the logo over an animated sea, the buttons "Jugar solo", "Hospedar partida", "Unirse", "Ajustes" and "Salir", a panel describing the focused button, and the game version. The first button has focus on arrival.

#### Scenario: Focus describes the option
- **GIVEN** the title screen
- **WHEN** the focus moves to "Hospedar partida"
- **THEN** the description panel explains hosting and that others join by IP on UDP port 7777

### Requirement: Join screen
The join screen SHALL take a host address with an optional `:port` (default 7777). A blank address or a port outside 1 to 65535 is refused with a message and nothing connects. While connecting it shows "Conectando…"; on failure it shows "No se pudo conectar." and stays open; "Volver" returns to the title.

#### Scenario: Bad port
- **WHEN** the player enters "192.168.1.20:99999" and picks "Conectar"
- **THEN** the screen says the port is invalid and no connection starts

#### Scenario: Nobody there
- **GIVEN** no host at the address
- **WHEN** the connection attempt fails
- **THEN** the screen shows "No se pudo conectar." and the player can try again

### Requirement: Lobby
The lobby SHALL list up to four players by name, the host first and marked. Only the host can start the run ("Empezar viaje"), alone or with others; clients see that they wait for the host. The host's lobby shows that others join on UDP port 7777 and lists the host's local addresses. Solo never shows the lobby.

#### Scenario: Two players meet
- **GIVEN** a host named Yuni in the lobby
- **WHEN** a client named Papo joins
- **THEN** both lobbies list Yuni (anfitrión) and Papo, and only Yuni's has "Empezar viaje"

### Requirement: HUD layout
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit top-left, each label inside its bar, a bar pulsing when critical (thirst, hunger, energy, morale or health at 25 or less, heat at 75 or more). The day phase sits top-centre. In co-op, teammates are listed top-right with name, health and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band and the centre stay clear.

#### Scenario: Solo HUD
- **GIVEN** a solo run
- **WHEN** the HUD is shown
- **THEN** it shows the meters and the day phase, and no teammate list or quick-chat wheel

#### Scenario: Critical thirst
- **GIVEN** a player whose thirst is 20
- **WHEN** the HUD draws the thirst bar
- **THEN** the bar pulses, and it stops pulsing once thirst is above 25

#### Scenario: Teammate down
- **GIVEN** a co-op run with Papo downed
- **WHEN** a teammate looks at the HUD
- **THEN** Papo's row reads "Caído" with his health, and his name and health strip show over his head

### Requirement: Settings
The settings screen SHALL hold the player name (up to 16 characters, default "Balsero"), fullscreen and the scale (automatic or 1× to 4×), and keep them per install across launches. A blank or unprintable name falls back to "Balsero". Esc and the gamepad back button return to the previous screen from every menu screen.

#### Scenario: Name kept
- **GIVEN** a player who sets the name "Dayana" and closes the game
- **WHEN** the game starts again
- **THEN** the name is "Dayana" and it is the name the lobby shows

#### Scenario: Name cleaned
- **WHEN** the player enters a 30-character name with control characters
- **THEN** the control characters are removed and the name is cut to 16 characters

### Requirement: Run summary
The run summary SHALL list each player of the run with their name, whether they died, and how long the run lasted, then offer "Volver al inicio". In solo it lists the one player.

#### Scenario: Solo summary
- **GIVEN** a solo player who died after 3 minutes
- **WHEN** the summary shows
- **THEN** it lists their name as dead and a run length of 3:00
