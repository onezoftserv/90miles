## MODIFIED Requirements

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
