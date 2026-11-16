## MODIFIED Requirements

### Requirement: Shared theme
Every screen SHALL use one theme: Pixelify Sans at 16 or 32 px for titles and buttons, its word spaces widened so a space is at least 5 px at 16 px, and Press Start 2P at 8 px for small text, both drawn without smoothing; and one window kit drawn only in master palette colours, each piece with a 1 px dark outline and corners rounded by a stepped pixel: dark windows 94% opaque over the world, cream paper windows for notes, paper panels in menus, and sea-blue buttons with a sun-yellow focus ring. Player-facing text is Spanish first. Keyboard and gamepad move the focus on every screen.

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
- **GIVEN** a solo player whose run has ended
- **WHEN** the run summary shows "Fin del viaje" and "Volver al inicio"
- **THEN** each space between two words is at least 5 px wide at 16 px

#### Scenario: Focus keeps the corner
- **GIVEN** the title screen with "Jugar solo" focused
- **WHEN** the button is drawn
- **THEN** its sun-yellow focus ring follows the button's stepped corner and no backdrop pixel shows between the ring and the button

### Requirement: HUD layout
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit in one window inside (4,4) to (136,90), Salud first, each row a label, a thin bar at a fixed x and the value. A label turns a steady orange at the warning step (50 or less, heat 50 or more) and a steady alert red at the critical one (25 or less, heat 75 or more), where the bar's outline and value also pulse; the label never pulses. The day phase sits top-centre. In co-op, teammates are listed top-right inside x 502 to 636, each with their name, a health bar and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band is the inventory's and the centre holds no panel. An open sign note sits top-centre under the day phase, clear of the meters, the teammate list and the centre.

#### Scenario: Solo HUD
- **GIVEN** a solo run
- **WHEN** the HUD is shown
- **THEN** it shows the meters, the day phase and the inventory strip, and no teammate list or quick-chat wheel

#### Scenario: Critical thirst
- **GIVEN** a player whose thirst is 20
- **WHEN** the HUD draws the thirst row
- **THEN** the Sed bar's outline and its value pulse while the label "Sed" is a steady alert red, and the pulse stops once thirst is above 25

#### Scenario: Warning step
- **GIVEN** a solo player, offline, with exactly 1 player, whose thirst is 40 and heat 60
- **WHEN** the HUD draws the meters
- **THEN** the labels "Sed" and "Calor" are a steady orange, nothing pulses, and every other label is cream

#### Scenario: Teammate down
- **GIVEN** a co-op run with Papo downed
- **WHEN** a teammate looks at the HUD
- **THEN** Papo's block reads "Caído" beside his health bar, and his name and health strip show over his head

#### Scenario: The sign note keeps clear
- **GIVEN** a co-op run with three teammates listed and a sign note open showing the longest coast cay line
- **WHEN** the HUD is drawn
- **THEN** the note's rectangle overlaps none of the meters, the day phase, the teammate list, the inventory band or the centre

#### Scenario: The meters stay in their corner
- **GIVEN** a solo run, offline, with exactly 1 player who bleeds
- **WHEN** the HUD is drawn
- **THEN** the meters window with its "Sangrando" tag lies inside (4,4) to (136,90), with Salud as its first row, and left of x 140, where the secret cay's note label starts

#### Scenario: The longest teammate block
- **GIVEN** a host with three clients, one named with 16 characters whose client is disconnected
- **WHEN** the host's HUD is drawn
- **THEN** the teammate list lies inside x 502 to 636 and y 4 to 90, shows that whole name and "Desconectado", and overlaps neither the day phase, the needle's place nor the sign note's place

## ADDED Requirements

### Requirement: Readable HUD and menu text
HUD and menu text SHALL have a contrast of at least 4.5:1 against the fill it is drawn on, except the alert red, which may go down to 4:1 on the dark window for a short alert word (Sangrando, Caído, Muerto), a critical meter's label or a pulsing value. HUD text is Press Start 2P at 8 px; menu titles and buttons Pixelify Sans at 16 or 32 px, menu body text Press Start 2P at 8 px. Meter labels sit on the window, never on a bar.

#### Scenario: Meter labels on the window
- **GIVEN** a solo run, offline, with exactly 1 player and every meter at 50
- **WHEN** the meters window is drawn
- **THEN** each label is cream on the dark window at 13:1 or more, and no label pixel lies on a bar

#### Scenario: Menu text
- **WHEN** the title, settings, lobby, join, credits and run summary screens are drawn
- **THEN** every label drawn on a panel or a button that is not disabled reaches at least 4.5:1 against it, in Pixelify Sans at 16 or 32 px or Press Start 2P at 8 px

#### Scenario: Alert words
- **GIVEN** a co-op HUD showing a downed teammate and its own player bleeding
- **WHEN** "Caído" and "Sangrando" are drawn
- **THEN** each is in the alert red at 4:1 or more on the dark window

### Requirement: Pause and host-lost windows
The pause menu and the host-lost screen SHALL show their title and buttons in one dark window centred in the view, over the dimmed run, with the title on a tab on the window's top edge and every button inside the window. The pause menu shows only in solo, exactly 1 player, offline; co-op refuses it. The host-lost screen shows only to clients.

#### Scenario: Solo pause in a window
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player presses Esc
- **THEN** a dark window centred in the 640×360 view shows the "Pausa" tab and "Seguir" with focus on it, and the window lies inside the view

#### Scenario: Host lost
- **GIVEN** a client in a run
- **WHEN** the host disconnects
- **THEN** the host-lost line and "Volver" show inside one centred dark window with its title tab

### Requirement: Menu windows
The title, settings, lobby, join, credits and run summary screens SHALL draw their panels as paper windows with even edges, their content centred, and a focused button with its ring inside the panel's inner area. An error line shows in cream on a red band. Check boxes, dropdowns, their popups and scroll bars use the kit's pieces. Solo reaches the title, settings, credits and summary screens and sees them the same way.

#### Scenario: Join fails
- **GIVEN** the join screen and no host at the address
- **WHEN** the connection attempt fails
- **THEN** "No se pudo conectar." shows in cream on a red band inside the join panel, at 4.5:1 or more

#### Scenario: A focused button inside its panel
- **GIVEN** a host's lobby with two players
- **WHEN** "Empezar viaje" has focus
- **THEN** the button and its focus ring lie inside the panel's inner area, clear of its border

#### Scenario: Solo summary
- **GIVEN** a solo player, offline, whose run has ended
- **WHEN** the run summary shows
- **THEN** its rows and buttons sit centred inside a paper window, and the panel's edges show the same border along their whole length
