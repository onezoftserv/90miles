## MODIFIED Requirements

### Requirement: Shared theme
Every screen SHALL use one theme. Pixelify Sans, at 32 px for the logo and 16 px for headings and window tabs only, has its word spaces widened so a space is at least 5 px at 16 px. Press Start 2P at 8 px is used for every other text: body lines, buttons, check boxes, dropdowns and their lists, text fields and error lines. Both are drawn without smoothing. One window kit is drawn only in master palette colours, each piece with a 1 px dark outline and corners rounded by a stepped pixel: dark windows 94% opaque over the world, cream paper windows for notes, paper panels in menus, and sea-blue buttons with a sun-yellow focus ring. Player-facing text is Spanish first. Keyboard and gamepad move the focus on every screen.

#### Scenario: A new screen
- **WHEN** a screen is added without styling of its own
- **THEN** it shows the game's fonts, panels and buttons

#### Scenario: Crisp text
- **WHEN** any text is drawn
- **THEN** its pixels are whole (no smoothing between font pixels)

#### Scenario: Windows in the game palette
- **WHEN** the window kit's images are checked
- **THEN** every pixel is a master palette colour, fully opaque or fully transparent, and every window piece's outer corner pixel is transparent

#### Scenario: HUD windows over the world
- **GIVEN** a solo run, offline, with exactly 1 player standing on sand
- **WHEN** the HUD is drawn
- **THEN** the meters, the day phase and the strip each sit on a dark window drawn at 94% opacity, with no window square-cornered and no window in a colour outside the master palette

#### Scenario: Word gaps in menus
- **GIVEN** a solo player whose run has ended in a death
- **WHEN** the run summary shows its heading "Fin del viaje"
- **THEN** each space between two words of the heading is at least 5 px wide at 16 px

#### Scenario: Focus keeps the corner
- **GIVEN** the title screen with "Jugar solo" focused
- **WHEN** the button is drawn
- **THEN** its sun-yellow focus ring follows the button's stepped corner and no backdrop pixel shows between the ring and the button

#### Scenario: Digits in a text field
- **GIVEN** a solo player, offline, on the join screen
- **WHEN** they type "192.168.1.70"
- **THEN** the field draws it in Press Start 2P at 8 px, and the buttons below it are in Press Start 2P at 8 px too

### Requirement: Readable HUD and menu text
HUD and menu text SHALL have a contrast of at least 4.5:1 against the fill it is drawn on, except the alert red, which may go down to 4:1 on the dark window for a short alert word (Sangrando, Caído, Muerto), a critical meter's label or a pulsing value. HUD text is Press Start 2P at 8 px. In menus the logo is Pixelify Sans at 32 px and headings and window tabs at 16 px; buttons, fields and body text are Press Start 2P at 8 px. Meter labels sit on the window, never on a bar.

#### Scenario: Meter labels on the window
- **GIVEN** a solo run, offline, with exactly 1 player and every meter at 50
- **WHEN** the meters window is drawn
- **THEN** each label is cream on the dark window at 13:1 or more, and no label pixel lies on a bar

#### Scenario: Menu text
- **WHEN** the title, settings, lobby, join, credits and run summary screens are drawn
- **THEN** every label drawn on a panel or a button that is not disabled reaches at least 4.5:1 against it, a heading in Pixelify Sans at 16 or 32 px and everything else in Press Start 2P at 8 px

#### Scenario: Alert words
- **GIVEN** a co-op HUD showing a downed teammate and its own player bleeding
- **WHEN** "Caído" and "Sangrando" are drawn
- **THEN** each is in the alert red at 4:1 or more on the dark window

### Requirement: Menu windows
The title, settings, lobby, join, credits and run summary screens SHALL draw their panels as paper windows with even edges, their content centred, and a focused button with its ring inside the panel's inner area. An error line shows in cream on a red band: on the join screen for a failed join, and on the title for a failed host, where it stays until the title is left and no focus or pointer move clears it. Check boxes, dropdowns, their popups and scroll bars use the kit's pieces. Solo reaches the title, settings, credits and summary screens and sees them the same way.

#### Scenario: Join fails
- **GIVEN** the join screen and no host at the address
- **WHEN** the connection attempt fails
- **THEN** "No se pudo conectar." shows in cream on a red band inside the join panel, at 4.5:1 or more

#### Scenario: Hosting fails
- **GIVEN** exactly 1 player on the title, with the host port already taken
- **WHEN** they pick "Hospedar partida"
- **THEN** the title shows why on a red band, and moving the focus or the pointer over the buttons changes the description panel but leaves the band as it is

#### Scenario: A focused button inside its panel
- **GIVEN** a host's lobby with two players
- **WHEN** "Empezar viaje" has focus
- **THEN** the button and its focus ring lie inside the panel's inner area, clear of its border

#### Scenario: Solo summary
- **GIVEN** a solo player, offline, whose run has ended
- **WHEN** the run summary shows
- **THEN** its rows and buttons sit centred inside a paper window, and the panel's edges show the same border along their whole length

### Requirement: Lobby
The lobby SHALL show four seats, the host first and marked, then the others in join order, with empty seats reading "Libre"; its heading counts who is aboard ("A bordo (2/4)"). Only the host can start ("Empezar viaje"), alone or with others; clients see that they wait for the host. The host's lobby shows its local addresses first, then how others join from the active backend (with ENet, the UDP port the host opened, 7777 by default). A lobby opened by "Otra vez" says "Otro viaje con el mismo grupo.". Solo never shows the lobby.

#### Scenario: Two players meet
- **GIVEN** a host named Yuni in the lobby
- **WHEN** a client named Papo joins
- **THEN** both lobbies read "A bordo (2/4)" over the seats Yuni (anfitrión), Papo, Libre and Libre, and only Yuni's has "Empezar viaje"

#### Scenario: Host on another port
- **GIVEN** a host that opened UDP port 7780
- **WHEN** its lobby shows
- **THEN** the host's LAN addresses show first, then the note naming port 7780

#### Scenario: A host alone
- **GIVEN** exactly 1 player hosting, with nobody joined
- **WHEN** the lobby shows
- **THEN** it reads "A bordo (1/4)" with three seats "Libre" and "Empezar viaje" focused

#### Scenario: The rematch lobby
- **GIVEN** a host and a client on their run summaries
- **WHEN** the host picks "Otra vez"
- **THEN** both lobbies say "Otro viaje con el mismo grupo." and read "A bordo (2/4)" once the client is listed

#### Scenario: The host closes the lobby
- **GIVEN** a host's lobby with a joined client
- **WHEN** the host picks "Cerrar partida"
- **THEN** "¿Cerrar la partida? Los demás vuelven al inicio." shows with "Cancelar" focused; "Cancelar" keeps the lobby, and "Cerrar" returns the host to the title and the client to the host-lost screen

#### Scenario: A host alone closes at once
- **GIVEN** exactly 1 player hosting, with nobody joined
- **WHEN** they pick "Cerrar partida"
- **THEN** the title shows with no question asked and the game is offline

### Requirement: Settings
The settings screen SHALL hold the player name, fullscreen, the scale (automatic or 1× to 4×), the pixel filter and "Reducir destellos" (reduce flashes, off by default), and keep them per install across launches. Esc and the gamepad back button return to the previous screen from every menu screen, except the host's lobby: closing it ends the lobby for everyone, so only "Cerrar partida" does that, after a question while anyone else is aboard.

#### Scenario: Name kept
- **GIVEN** a player who sets the name "Dayana" and closes the game
- **WHEN** the game starts again
- **THEN** the name is "Dayana" and it is the name the lobby shows

#### Scenario: Esc in the host's lobby
- **GIVEN** a host in the lobby with a joined player
- **WHEN** the host presses Esc
- **THEN** the lobby stays open; a client pressing Esc in its lobby leaves it

#### Scenario: Reduce flashes kept
- **GIVEN** a player who ticks "Reducir destellos" and closes the game
- **WHEN** the game starts again
- **THEN** the box is still ticked and hits and uses show without flashes
