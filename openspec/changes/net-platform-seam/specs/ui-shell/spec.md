## MODIFIED Requirements

### Requirement: Screen flow
The game SHALL open on the title screen. Solo goes straight to a run, with no lobby and nothing waiting for another player. Hosting opens the lobby; while a slower backend opens the session the lobby says "Abriendo la partida…" and only "Salir" works, which cancels, and asking to host again while it opens does nothing; if hosting fails the title says why. Joining opens the join screen, then the lobby, or the run if one is under way; a join requested from outside the game opens the join screen already connecting, and a join failure always shows on the join screen. When every player still in the run is dead the run summary shows, then the title or a new run; a disconnected player keeps the run open until they are removed. Losing the host shows the host-lost screen, then the title.

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
