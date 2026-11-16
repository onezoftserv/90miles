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
The game SHALL open on the title screen. Solo goes straight to a run, with no lobby and nothing waiting for another player. Hosting opens the lobby; while a slower backend opens the session the lobby says "Abriendo la partida…" and only "Salir" works, which cancels, and asking to host again while it opens does nothing; if hosting fails the title says why. Joining opens the join screen, then the lobby, or the run if one is under way; a join requested from outside the game opens the join screen already connecting, and a join failure always shows on the join screen. When every player still in the run is dead the run summary shows, then the title or a new run; in co-op the host's "Otra vez" opens a new lobby on the host and every connected client, with nobody joining again. A disconnected player keeps the run open until they are removed. Losing the host shows the host-lost screen, then the title.

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

#### Scenario: Hosting on a slower backend
- **GIVEN** exactly 1 player and a backend that opens hosting a few frames after the request
- **WHEN** the player picks "Hospedar partida"
- **THEN** the lobby shows "Abriendo la partida…" with only "Salir" until hosting is ready, then lists the host alone with "Empezar viaje", which starts a run with one player

#### Scenario: Salir while the session opens
- **GIVEN** a lobby still showing "Abriendo la partida…"
- **WHEN** the player picks "Salir"
- **THEN** the title shows, the game is offline, and the backend has left its session

#### Scenario: The party again
- **GIVEN** a host and a client on their run summaries
- **WHEN** the host picks "Otra vez"
- **THEN** the lobby shows on both, listing both players, and the client's lobby shows as soon as the host's call arrives, before the host's answer fills in its list

### Requirement: Title screen
The title screen SHALL show the logo over an animated sea, the buttons "Jugar solo", "Hospedar partida", "Unirse", "Ajustes", "Créditos" and "Salir", a panel describing the focused button, and the game version. The first button has focus on arrival.

#### Scenario: Focus describes the option
- **GIVEN** the title screen
- **WHEN** the focus moves to "Hospedar partida"
- **THEN** the description panel explains hosting and that others join by IP on UDP port 7777

#### Scenario: Credits offered offline
- **GIVEN** a solo player on the title screen, offline, with no session
- **WHEN** the focus moves to "Créditos"
- **THEN** it sits between "Ajustes" and "Salir", the description panel says it lists who made the game's art and fonts and under which licences, and no network port is opened

### Requirement: Join screen
The join screen SHALL take a host address with an optional `:port` (default 7777). A blank address or a port outside 1 to 65535 is refused with a message and nothing connects. While connecting it shows "Conectando…"; a join requested from outside the game shows its target in the address field, which cannot be edited, while it connects. On failure it shows the reason's line ("No se pudo conectar." when nobody answers) and stays open; "Volver" cancels a join under way and returns to the title. Solo never shows this screen.

#### Scenario: Bad port
- **WHEN** the player enters "192.168.1.20:99999" and picks "Conectar"
- **THEN** the screen says the port is invalid and no connection starts

#### Scenario: Nobody there
- **GIVEN** no host at the address
- **WHEN** the connection attempt fails
- **THEN** the screen shows "No se pudo conectar." and the player can try again

#### Scenario: Volver cancels a join under way
- **GIVEN** a join still waiting on the backend
- **WHEN** the player picks "Volver"
- **THEN** the title shows, the game is offline, and no session starts later

### Requirement: Lobby
The lobby SHALL list up to four players by name, the host first and marked. Only the host can start the run ("Empezar viaje"), alone or with others; clients see that they wait for the host. The host's lobby shows how others join, from the active backend: with ENet, that they join on the UDP port the host opened (7777 by default), and the host's local addresses. Solo never shows the lobby.

#### Scenario: Two players meet
- **GIVEN** a host named Yuni in the lobby
- **WHEN** a client named Papo joins
- **THEN** both lobbies list Yuni (anfitrión) and Papo, and only Yuni's has "Empezar viaje"

#### Scenario: Host on another port
- **GIVEN** a host that opened UDP port 7780
- **WHEN** its lobby shows
- **THEN** the note names port 7780 and the host's LAN addresses are listed

### Requirement: HUD layout
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit top-left, each label inside its bar, a bar pulsing when critical (thirst, hunger, energy, morale or health at 25 or less, heat at 75 or more). The day phase sits top-centre. In co-op, teammates are listed top-right with name, health and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band is the inventory's and the centre holds no panel. An open sign note sits top-centre under the day phase, clear of the meters, the teammate list and the centre.

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

#### Scenario: The sign note keeps clear
- **GIVEN** a co-op run with three teammates listed and a sign note open showing the longest coast cay line
- **WHEN** the HUD is drawn
- **THEN** the note's rectangle overlaps none of the meters, the day phase, the teammate list, the inventory band or the centre

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
The run summary SHALL show what endings-progression's "Run summary", "Run summary totals", "Cause of death on the run summary", "Death one-liners" and "Restart from the summary" define, one row per player of the run with their name and fate, in the shell's theme. Those requirements own the summary's content and buttons. In solo it lists the one player.

#### Scenario: Solo summary
- **GIVEN** a solo player who died after 3 minutes
- **WHEN** the summary shows
- **THEN** it lists their name as dead and a run length of 3:00, and offers "Otra vez" and "Volver al inicio"

#### Scenario: Co-op summary
- **GIVEN** a host Yuni and a client Papo who both died
- **WHEN** their summaries show
- **THEN** each lists Yuni and Papo as dead; Yuni's offers "Otra vez" and "Volver al inicio", and Papo's only "Volver al inicio"

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

### Requirement: Teammate state word
In co-op, a teammate's row SHALL end with one state word, the first that applies: "Muerto" when their meters say dead, "Desconectado" while their client is disconnected and their body waits, "Caído" when they are downed, else none. The word for a given teammate is the same on the host, on every client and on a client that joined later. Solo has no teammate rows.

#### Scenario: A dropped teammate on a client
- **GIVEN** a host and two clients, Dayana and Papo, in a run
- **WHEN** Papo's client disconnects
- **THEN** Papo's row reads "Desconectado" on the host's HUD and on Dayana's, not "Caído"

#### Scenario: A late joiner sees the same word
- **GIVEN** Papo's client disconnected and his body waits on the sandbar
- **WHEN** another client joins the run during his 90 s
- **THEN** Papo's row on the joiner's HUD reads "Desconectado"

#### Scenario: Back from a drop
- **GIVEN** Papo's client disconnected and Dayana's HUD shows his row as "Desconectado"
- **WHEN** Papo joins again within 90 s from the same install
- **THEN** Papo's row on Dayana's HUD and on the host's shows no state word, and if his meters had him downed it reads "Caído"

#### Scenario: Dead comes first
- **GIVEN** Papo's client disconnected and his body waits
- **WHEN** his meters kill him before he is removed
- **THEN** his row reads "Muerto" on every peer

#### Scenario: Solo has no rows
- **GIVEN** a solo run, offline
- **WHEN** the HUD is shown
- **THEN** there is no teammate row and no state word anywhere

### Requirement: Spectating a teammate
In co-op, a player whose meters say dead SHALL watch a living teammate instead of their own body: their view follows that teammate's body and stays inside that body's view limits, on the island or on a crossing's sea. A rider waiting on the next island's shore watches the same way until the party lands. The run summary still shows when every player still in the run is dead. Solo has no teammate to watch: a solo death goes straight to the run summary.

#### Scenario: A solo death goes to the summary
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player dies
- **THEN** the run summary shows, the view never leaves the player's own body, and no "Mirando a:" line shows

#### Scenario: A dead player watches a teammate
- **GIVEN** a co-op run with Yuni and Papo on the sandbar
- **WHEN** Yuni dies
- **THEN** Yuni's view follows Papo's body and no longer Yuni's own

#### Scenario: Watching a teammate at sea
- **GIVEN** Yuni is dead on the sandbar and Papo rides a raft crossing
- **WHEN** Yuni's view follows Papo
- **THEN** it shows Papo on the crossing's sea and stays inside that sea

#### Scenario: The last teammate dies
- **GIVEN** Yuni is dead and watches Papo, the only player still alive
- **WHEN** Papo dies
- **THEN** the run summary shows on every peer, as it did before this change

#### Scenario: A waiting rider watches the one still playing
- **GIVEN** a 2-player run where Yuni's crossing has ended and Papo still plays on the sandbar
- **WHEN** Yuni waits on the shore
- **THEN** Yuni's view follows Papo under the line "En la orilla. Esperando a: Papo", and it goes back to Yuni's own body when the party lands

### Requirement: Whom a spectator watches
A teammate SHALL be watchable while they are not dead and not waiting out of play on the shore. A disconnected teammate is watchable only while no connected teammate is, and is then marked as disconnected. On death the view goes to the watchable teammate nearest the dead player's body. Solo has no watchable teammate.

#### Scenario: The nearest teammate first
- **GIVEN** a co-op run with Yuni, Papo and Dayana, Dayana standing nearer to Yuni than Papo
- **WHEN** Yuni dies
- **THEN** Yuni's view follows Dayana

#### Scenario: Waiting riders are not watched
- **GIVEN** Yuni is dead, Papo waits on the next island's shore and Dayana still plays on the sandbar
- **WHEN** Yuni's view picks a teammate
- **THEN** it follows Dayana and never Papo

#### Scenario: Only a disconnected teammate left
- **GIVEN** Yuni is dead and the only other player, Papo, has a disconnected client whose body waits on the sandbar
- **WHEN** Yuni's view picks a teammate
- **THEN** it follows Papo's body and the line reads "Mirando a: Papo (desconectado)"

#### Scenario: A connected teammate comes before a disconnected one
- **GIVEN** Yuni is dead, Papo's client is disconnected and Dayana is connected and alive
- **WHEN** Yuni's view picks a teammate
- **THEN** it follows Dayana, and stepping through teammates never reaches Papo while Dayana can be watched

### Requirement: Switching the watched teammate
A spectator SHALL step to the next or previous watchable teammate with D or A, → or ←, the gamepad's D-pad → or ←, and the mouse wheel. These step in the teammate list's order and wrap round. Holding a key or the stick does not repeat. A living player who is not waiting walks and picks slots with these keys, as before. Solo has nobody to step to.

#### Scenario: Stepping and wrapping
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive; the teammate list reads Dayana, then Papo
- **WHEN** Yuni presses D twice
- **THEN** the view follows Papo after the first press and Dayana again after the second

#### Scenario: Stepping back
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive; the teammate list reads Dayana, then Papo
- **WHEN** Yuni presses A
- **THEN** the view follows Papo

#### Scenario: The keys work on a gamepad
- **GIVEN** Yuni is dead and plays with a gamepad
- **WHEN** Yuni presses the D-pad's →
- **THEN** the view steps to the next watchable teammate

#### Scenario: A living player's keys walk
- **GIVEN** a co-op run with Yuni alive on the sandbar
- **WHEN** Yuni presses D
- **THEN** Yuni walks right and the view stays on Yuni's own body

#### Scenario: No key is bound twice
- **GIVEN** the project's input map
- **WHEN** the stepping keys are read
- **THEN** each is a key, button or wheel direction of an action a spectator has no other use for (walking, the slot strip, the engine's arrows), and no input is bound to two of the project's actions

### Requirement: Losing the watched teammate
When the watched teammate dies, is removed, or leaves play, the spectator's view SHALL move to the watchable teammate nearest that teammate's last position. A teammate leaves play by going to wait on the shore. With nobody watchable, the view goes back to the spectator's own body and the line hides. Solo never watches, so it never loses anyone.

#### Scenario: The watched teammate dies
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive
- **WHEN** Dayana dies
- **THEN** Yuni's view follows Papo

#### Scenario: The watched teammate leaves by a route
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive on the sandbar
- **WHEN** Dayana's crossing ends and she waits on the shore
- **THEN** Yuni's view follows Papo

#### Scenario: The watched teammate is removed
- **GIVEN** Yuni is dead and watches Papo, whose client dropped, and Dayana's crossing has ended
- **WHEN** Papo is removed after his time runs out
- **THEN** Yuni's view never points at a body that is gone: it follows a watchable teammate or goes back to Yuni's own body

### Requirement: The HUD while watching
While a player watches a teammate, the HUD's bottom band SHALL read "Mirando a: <name>" with the keys that switch. The meters panel shows the watched teammate's meters. The inventory strip and the interact prompt are hidden, and quick chat still works. When watching ends, the HUD shows the player's own meters again. The line's text is HUD text data. Solo never shows the line.

#### Scenario: The line and the meters
- **GIVEN** Yuni is dead and watches Papo, whose thirst is 30
- **WHEN** Yuni looks at the HUD
- **THEN** the bottom band reads "Mirando a: Papo" with the switch keys, the thirst bar reads 30, and Yuni's inventory strip is hidden

#### Scenario: Quick chat from the dead
- **GIVEN** Yuni is dead and watches Papo
- **WHEN** Yuni picks a quick-chat phrase
- **THEN** the phrase is said, as it is for a living player

#### Scenario: Back to the own HUD
- **GIVEN** a 2-player run where Yuni waits on the shore and watches Papo
- **WHEN** the party lands on the next island
- **THEN** Yuni's meters panel shows Yuni's meters, the strip shows again and the "Mirando a:" line hides

### Requirement: Spectating on every peer
Spectating SHALL be worked out on each peer from the state it already holds, with nothing sent over the network. It works the same for the host, a client, a client who joined during the run, and a player who took back a body that died while they were away. That last player watches as soon as they are back. Solo has no peer to reach.

#### Scenario: A client watches the host
- **GIVEN** a host, Yuni, and a client, Papo, in a run
- **WHEN** Papo dies
- **THEN** Papo's view follows Yuni with the line "Mirando a: Yuni", and Yuni's view stays on Yuni

#### Scenario: The host watches a client
- **GIVEN** a host, Yuni, and a client, Papo, in a run
- **WHEN** Yuni dies
- **THEN** Yuni's view follows Papo with the line "Mirando a: Papo"

#### Scenario: Back to a dead body
- **GIVEN** Papo's client dropped and his body died during his 90 s, and Yuni is alive
- **WHEN** Papo joins again from the same install within the 90 s
- **THEN** Papo's view follows Yuni at once

#### Scenario: A late joiner who dies
- **GIVEN** Dayana joined a run under way with Yuni and Papo alive
- **WHEN** Dayana dies
- **THEN** her view follows the nearer of Yuni and Papo, and the line names them as the roster does
