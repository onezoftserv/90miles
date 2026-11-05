# Spec Delta

## MODIFIED Requirements

### Requirement: Host and join
A player SHALL host a session on a port (default 7777) and up to three others SHALL join by IP; a fifth player is refused. Solo play runs the same code path with the host as the only peer and opens no network port. A joining client receives the host's world state (island seed, current weather, time of day) and every spawned entity, and its player spawns at one of the island's beach spawn points.

#### Scenario: Second player joins mid-island
- GIVEN a host on island 2
- WHEN a client connects
- THEN the client receives the island seed, current weather, time of day and all entity states, and spawns on the beach

#### Scenario: Solo session
- **GIVEN** a player who starts a solo run
- **WHEN** the session starts
- **THEN** they control one player simulated by the same host code as in co-op, and no network port is open

#### Scenario: Fifth player refused
- **GIVEN** a session with four players
- **WHEN** a fifth client tries to connect
- **THEN** its connection is refused and the four players stay in the session

### Requirement: Host authority
All world state (meters, inventory, creature positions, weather, patrol state) SHALL live on the host. Clients send input intents; the host validates and applies them and runs every interaction. The host's state of each player (position, energy, movement state) reaches clients 20 times per second. Each client predicts its own player from its own intents and, when host state arrives, takes it and re-applies the intents the host has not processed yet. Other players are drawn 100 ms behind the newest host state, interpolated between host states.

#### Scenario: Client claims an item it is not near
- GIVEN a client whose player is 10 tiles from a coconut
- WHEN it sends a pick-up intent for that coconut
- THEN the host rejects the intent and the coconut stays

#### Scenario: Own player responds at once
- **GIVEN** a client whose round trip to the host is 150 ms
- **WHEN** its player starts walking east
- **THEN** its own player moves on that same frame, before any answer from the host

#### Scenario: Correction from the host
- **GIVEN** a client's player that the host has moved somewhere the client did not predict
- **WHEN** the host's state for that player arrives
- **THEN** the client's player is at the host's position plus the movement of the intents the host has not processed yet, and once the host has processed all of them the client's player is exactly where the host has it

#### Scenario: Teammate drawn between host states
- **GIVEN** host states for a teammate at x = 0 tiles and, 50 ms later, at x = 1 tile
- **WHEN** a client draws the teammate 25 ms after the first state's time (100 ms behind a clock that reads 125 ms)
- **THEN** the teammate is drawn at x = 0.5 tiles

#### Scenario: Downed player is not predicted
- **GIVEN** a client whose own player is downed
- **WHEN** a teammate drags that player
- **THEN** the client draws its player where the host's state puts it and sends no movement intents

### Requirement: Disconnect handling
If a client disconnects, its player SHALL stay in the world as downed for 90 s, then be removed from every peer; the host announces the removal with the player's last position so its inventory can be dropped there. A client that reconnects joins as a new player. If the host disconnects, the session ends and clients see a "host lost" screen; migration is out of scope for v1.

#### Scenario: Client drops
- GIVEN a client's player on the island
- WHEN that client disconnects
- THEN the player stays in the world downed for 90 s, then is removed from every peer, and the removal is announced with the player's last position so its inventory can be dropped there

#### Scenario: Host drops
- **GIVEN** a session with a host and a client
- **WHEN** the host disconnects
- **THEN** the client's session ends and it shows the "host lost" screen

### Requirement: Quick chat
Players SHALL have a radial quick-chat, opened by holding the quick-chat button, with 8 phrases (¡Dale!, ¡Agua!, ¡Pa'llá no!, ¡Tiburón!, ¡Patrulla!, ¡Ayuda!, ¡Comida aquí!, ¡Vámonos!). The phrases are content data. A picked phrase goes through the host, which shows it to every player as a speech bubble over the speaker. Each phrase also plays its short voice clip once that clip exists; recorded voice lines arrive with Milestone G.

#### Scenario: Shark warning
- GIVEN a player with the radial quick-chat open
- WHEN they pick ¡Tiburón!
- THEN every player sees a ¡Tiburón! speech bubble over that player, and its short voice clip plays if one exists for that phrase

#### Scenario: Rewording a phrase
- **WHEN** a writer changes a phrase in the quick-chat content file
- **THEN** the wheel and the bubbles show the new wording with no script change

## ADDED Requirements

### Requirement: Intents reach only the host and act only for their sender
A client SHALL send intents only to the host. The host SHALL ignore intents that arrive anywhere but on the host and SHALL apply each intent only to the sending peer's own player, whatever the intent contains. Messages from the host to clients SHALL be accepted only from the host, and clients SHALL NOT relay messages to each other.

#### Scenario: Client acts as a teammate
- **GIVEN** a session with clients A and B
- **WHEN** client A sends movement intents, including ones addressed to B's player
- **THEN** only A's player moves and B's player stays where B's own intents put it

#### Scenario: Client forges a host message
- **GIVEN** a session with clients A and B
- **WHEN** client A sends a message only the host may send, such as showing a quick-chat bubble
- **THEN** no peer shows the bubble

### Requirement: Per-peer rate limits
The host SHALL limit each peer to 90 intents per second with a burst of 30, to 1 s of simulated movement per second of real time with 0.25 s of slack and at most 0.1 s per intent, and to 3 quick-chat phrases in a burst, then one every 2 s. The host SHALL drop messages over a limit without applying them.

#### Scenario: Client claims extra time
- **GIVEN** a client whose player is walking east
- **WHEN** it sends, within 1 s, 60 intents that each claim 0.1 s
- **THEN** the host moves that player at most 5 tiles (1.25 s of walking at 4 tiles/s)

#### Scenario: Quick-chat spam
- **GIVEN** a player who has not used quick chat
- **WHEN** they pick 5 phrases at once
- **THEN** 3 bubbles are shown and the next phrase is accepted 2 s later
