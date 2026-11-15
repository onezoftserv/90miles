## MODIFIED Requirements

### Requirement: Host and join
A player SHALL host a session through the active platform backend (net-platform) and up to three others SHALL join it; with the default ENet backend the host listens on a port (default 7777) and others join by IP. A fifth connected player is refused. Solo play runs the same code path with the host as the only peer and opens no network port: a run that neither hosts nor joins is solo, and nothing waits for a second peer. A co-op session first gathers in a lobby: each client sends its player name once when it joins, and players spawn when the host starts the run; a client that joins once the run has started spawns at once. A joining client receives the host's world state (island seed, current weather, time of day) and every spawned entity, and its player spawns at one of the island's beach spawn points.

#### Scenario: Second player joins mid-island
- GIVEN a host on island 2
- WHEN a client connects
- THEN the client receives the island seed, current weather, time of day and all entity states, and spawns on the beach

#### Scenario: Solo session
- **GIVEN** a player who starts a run without hosting or joining
- **WHEN** the session starts
- **THEN** no network port is open and no second peer is waited for, their player spawns at once on the beach, simulated by the same host code as in co-op, and it moves and interacts exactly as player-movement specifies (running 10 s from energy 50 covers 60 tiles and leaves energy 45)

#### Scenario: Fifth player refused
- **GIVEN** a session with four players
- **WHEN** a fifth client tries to connect
- **THEN** its connection is refused and the four players stay in the session

#### Scenario: Players spawn when the run starts
- **GIVEN** a host and two clients in the lobby
- **WHEN** the host starts the run
- **THEN** all three players spawn on the beach on every peer, and none was spawned before
