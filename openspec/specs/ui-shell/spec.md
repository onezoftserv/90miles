# ui-shell Specification

## Purpose
The player-facing shell of 90 Millas: how the game fills the screen, the shared look of every screen, the flow from the title through a run and back, the HUD layout at 640×360, and the settings each install keeps.

## Requirements

### Requirement: Display scaling
The game SHALL draw its 640×360 view at the largest whole-number scale that fits the window, with black bars for the rest, and with nearest filtering unless the pixel filter is Suave. At launch the window opens at the largest multiple that fits the usable screen, or fullscreen if the player chose it, unless a fixed scale (1× to 4×) is set. F11 or Alt+Enter toggles fullscreen at any time. Solo and co-op behave the same.

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

### Requirement: Pixel filter
The settings screen SHALL offer "Filtro de píxeles" with two modes: Nítido (the default) draws the enlarged world with nearest filtering; Suave smooths it with a Scale2x-family pixel-art filter. Both keep the 640×360 base and the whole-number scale with black bars; only the enlarged world picture changes. The HUD and menus stay sharp in both modes. The setting is per install, kept with the other settings and never synced; each player picks their own, in solo and in co-op.

#### Scenario: Sharp by default
- **GIVEN** a fresh install
- **WHEN** a run starts
- **THEN** the pixel filter is Nítido and the world looks as it did before the setting existed

#### Scenario: Smooth chosen and kept
- **GIVEN** a solo player, offline, who picks Suave and restarts the game
- **WHEN** a run starts at 2×
- **THEN** the world's diagonal edges are smoothed, the window is still 1280×720 and the HUD's text is still sharp

#### Scenario: Each player's own choice
- **GIVEN** a host with Suave and a client with Nítido
- **WHEN** they play together
- **THEN** each sees their own choice and neither changes the other's

### Requirement: Shared theme
Every screen SHALL use one theme: Pixelify Sans at 16 or 32 px for titles and buttons, Press Start 2P at 8 px for small text, both drawn without smoothing; tan panels, sea-blue buttons with a sun-yellow focus frame, and see-through dark panels over the world. Player-facing text is Spanish first. Keyboard and gamepad move the focus on every screen.

#### Scenario: A new screen
- **WHEN** a screen is added without styling of its own
- **THEN** it shows the game's fonts, panels and buttons

#### Scenario: Crisp text
- **WHEN** any text is drawn
- **THEN** its pixels are whole (no smoothing between font pixels)

### Requirement: Screen flow
The game SHALL open on the title screen. Solo goes straight to a run, with no lobby and nothing waiting for another player. Hosting opens the lobby; joining opens the join screen, then the lobby, or the run if one is under way. When every player still in the run is dead the run summary shows, then the title or a new run; a disconnected player keeps the run open until they are removed. Losing the host shows the host-lost screen, then the title.

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
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit top-left, each label inside its bar, a bar pulsing when critical (thirst, hunger, energy, morale or health at 25 or less, heat at 75 or more). The day phase sits top-centre. In co-op, teammates are listed top-right with name, health and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band is the inventory's and the centre holds no panel.

#### Scenario: Solo HUD
- **GIVEN** a solo run
- **WHEN** the HUD is shown
- **THEN** it shows the meters, the day phase and the inventory strip, and no teammate list or quick-chat wheel

#### Scenario: Critical thirst
- **GIVEN** a player whose thirst is 20
- **WHEN** the HUD draws the thirst bar
- **THEN** the bar pulses, and it stops pulsing once thirst is above 25

#### Scenario: Teammate down
- **GIVEN** a co-op run with Papo downed
- **WHEN** a teammate looks at the HUD
- **THEN** Papo's row reads "Caído" with his health, and his name and health strip show over his head

### Requirement: Settings
The settings screen SHALL hold the player name, fullscreen, the scale (automatic or 1× to 4×) and the pixel filter, and keep them per install across launches. Esc and the gamepad back button return to the previous screen from every menu screen, except the host's lobby: closing it ends the lobby for everyone, so only "Salir" does that.

#### Scenario: Name kept
- **GIVEN** a player who sets the name "Dayana" and closes the game
- **WHEN** the game starts again
- **THEN** the name is "Dayana" and it is the name the lobby shows

#### Scenario: Esc in the host's lobby
- **GIVEN** a host in the lobby with a joined player
- **WHEN** the host presses Esc
- **THEN** the lobby stays open; a client pressing Esc in its lobby leaves it

### Requirement: Player name
The player name SHALL be at most 16 characters, default "Balsero". Cleaning removes control characters and the marks that change text direction or draw nothing (zero-width characters, bidi overrides and isolates). A blank or unprintable name falls back to "Balsero".

#### Scenario: Name cleaned
- **WHEN** the player enters a 30-character name with control characters
- **THEN** the control characters are removed and the name is cut to 16 characters

#### Scenario: A name with a right-to-left override
- **GIVEN** a name that wraps "Yuni" in a right-to-left override
- **WHEN** it is cleaned
- **THEN** it reads "Yuni", with no direction marks left

### Requirement: Run summary
The run summary SHALL list each player of the run with their name, whether they died, and how long the run lasted, then offer "Volver al inicio". In solo it lists the one player.

#### Scenario: Solo summary
- **GIVEN** a solo player who died after 3 minutes
- **WHEN** the summary shows
- **THEN** it lists their name as dead and a run length of 3:00

### Requirement: Inventory band and world marks
During a run the HUD's bottom band (y 306 to 360) SHALL hold the local player's inventory strip, its selected item's line and refusal line, and the crafting list opens above it at the left edge (4,162 to 244,302) while the player is at a workbench (inventory-hud). In the centre the HUD draws only marks anchored to something in the world: a teammate's name tag, the interact prompt and the hidden mark. Solo the same.

#### Scenario: Marks in the centre
- **GIVEN** a solo player standing within 1 tile of a coconut, crouched in brush
- **WHEN** the HUD is drawn
- **THEN** the interact prompt shows over the coconut and the hidden mark over the player, both anchored to their world positions, and no panel covers the centre

#### Scenario: The band in co-op
- **GIVEN** a host with one client
- **WHEN** each peer draws its HUD
- **THEN** the strip and its lines lie inside y 306 to 360 and overlap neither the meters, the day phase nor the teammate list
