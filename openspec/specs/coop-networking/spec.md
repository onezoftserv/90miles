# coop-networking

## Purpose
Host-and-join co-op for 1–4 players using Godot high-level multiplayer over ENet.

## Requirements

### Requirement: Host and join
A player SHALL host a session on a port (default 7777) and up to three others SHALL join by IP; a fifth connected player is refused. Solo play runs the same code path with the host as the only peer and opens no network port: a run that neither hosts nor joins is solo, and nothing waits for a second peer. A joining client receives the host's world state (island seed, current weather, time of day) and every spawned entity, and its player spawns at one of the island's beach spawn points.

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

### Requirement: Host authority
All world state (meters, inventory, creature positions, weather, patrol state) SHALL live on the host. Clients send input intents; the host validates and applies them and runs every interaction. The host's state of each player (position, energy, movement state) reaches clients 20 times per second. Each client predicts its own player from its own intents and, when host state arrives, takes it and re-applies the intents the host has not processed yet. Other players are drawn 100 ms behind the newest host state, interpolated between host states. The host's own player, and so the solo player, is simulated from its input on the same frame and is never predicted or corrected.

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

#### Scenario: Solo player moves without networking delay
- **GIVEN** a solo player and a player body with no session, on the same terrain with the same energy
- **WHEN** both get the same intents for 2 s
- **THEN** they end at the same position with the same energy

#### Scenario: Downed player is not predicted
- **GIVEN** a client whose own player is downed
- **WHEN** a teammate drags that player
- **THEN** the client draws its player where the host's state puts it and sends no movement intents

### Requirement: Spawning
Players, creatures, items and NPCs SHALL be spawned through `MultiplayerSpawner` so late joiners receive them.

#### Scenario: Late joiner sees existing entities
- GIVEN players, creatures, items and NPCs already spawned on the island
- WHEN a client joins
- THEN the client receives all of them through `MultiplayerSpawner`

### Requirement: Disconnect handling
If a client disconnects, its player SHALL stay in the world as downed for 90 s, then be removed from every peer; the host announces the removal with the player's last position so its inventory can be dropped there. A dropped player does not hold a place in the player cap, and a client that reconnects joins as a new player. If the host disconnects, the session ends and clients see a "host lost" screen; migration is out of scope for v1. Solo has no client to drop and no host to lose, so none of this applies with one player.

#### Scenario: Client drops
- GIVEN a client's player on the island
- WHEN that client disconnects
- THEN the player stays in the world downed for 90 s, then is removed from every peer, and the removal is announced with the player's last position so its inventory can be dropped there

#### Scenario: Reconnect into a full session
- **GIVEN** a session with four players
- **WHEN** one client drops and then connects again before its 90 s are up
- **THEN** it joins as a new player while its old player is still downed in the world

#### Scenario: Host drops
- **GIVEN** a session with a host and a client
- **WHEN** the host disconnects
- **THEN** the client's session ends and it shows the "host lost" screen

### Requirement: Difficulty scaling
Difficulty SHALL be counted from the living, connected players when each island is set up: resource spawn rates multiply by 0.8 per such player beyond the first, and patrol count adds 1 per 2 such players, rounded down. Dropped and dead players do not count. One player (solo, or the last survivor of a party) gets ×1 and +0 patrols. Solo uses the same base numbers as co-op; there is no separate solo tuning.

#### Scenario: Three players
- GIVEN a session with 3 players
- WHEN an island is set up
- THEN resource spawn rates are ×0.64 (0.8 × 0.8) and patrol count is +1

#### Scenario: Solo island
- **GIVEN** a solo session
- **WHEN** an island is set up
- **THEN** resource spawn rates are ×1 and the patrol count is unchanged

#### Scenario: Last survivor of four
- **GIVEN** a 4-player run in which 3 players are dead
- **WHEN** the next island is set up
- **THEN** resource spawn rates are ×1 and the patrol count is unchanged

### Requirement: Quick chat
Players SHALL have a radial quick-chat, opened by holding the quick-chat button, with 8 phrases (¡Dale!, ¡Agua!, ¡Pa'llá no!, ¡Tiburón!, ¡Patrulla!, ¡Ayuda!, ¡Comida aquí!, ¡Vámonos!). The phrases are content data. A picked phrase goes through the host, which shows it to every player as a speech bubble over the speaker. Each phrase also plays its short voice clip once that clip exists; recorded voice lines arrive with Milestone G. In solo the wheel works the same and the bubble shows over the solo player.

#### Scenario: Shark warning
- GIVEN a player with the radial quick-chat open
- WHEN they pick ¡Tiburón!
- THEN every player sees a ¡Tiburón! speech bubble over that player, and its short voice clip plays if one exists for that phrase

#### Scenario: Rewording a phrase
- **WHEN** a writer changes a phrase in the quick-chat content file
- **THEN** the wheel and the bubbles show the new wording with no script change

### Requirement: Intents reach only the host and act only for their sender
A client SHALL send intents only to the host. The host SHALL ignore intents that arrive anywhere but on the host and SHALL apply each intent only to the sending peer's own player, whatever the intent contains. Messages from the host to clients SHALL be accepted only from the host, and clients SHALL NOT relay messages to each other. The host's own (and the solo) player's intents take the same path.

#### Scenario: Client acts as a teammate
- **GIVEN** a session with clients A and B
- **WHEN** client A sends movement intents, including ones addressed to B's player
- **THEN** only A's player moves and B's player stays where B's own intents put it

#### Scenario: Client forges a host message
- **GIVEN** a session with clients A and B
- **WHEN** client A sends a message only the host may send, such as showing a quick-chat bubble
- **THEN** no peer shows the bubble

### Requirement: Pause
In a solo session (one player, offline) the pause button SHALL open the pause menu and freeze the whole simulation (clock, meters, creatures, patrols, weather) until the player resumes. Co-op has no pause: with other players, or while hosting, the pause button does nothing. Save-and-quit is out of scope.

#### Scenario: Solo pause
- **GIVEN** a solo player
- **WHEN** they press pause
- **THEN** the pause menu shows and nothing in the simulation advances, and when they resume it runs again from where it stopped

#### Scenario: No pause in co-op
- **GIVEN** a host with a client
- **WHEN** either player presses pause
- **THEN** nothing pauses and no pause menu shows

### Requirement: Per-peer rate limits
The host SHALL limit each client to 90 intents per second with a burst of 30, and to 1 s of simulated movement per second of real time with 0.25 s of slack, each intent counting at least one 1/60 s frame and at most 0.1 s. Every player, solo included, gets 3 quick-chat phrases in a burst, then one every 2 s. Over-limit messages are dropped. The host's own (solo) player's intents are never limited.

#### Scenario: Client claims extra time
- **GIVEN** a client whose player is walking east
- **WHEN** it sends, within 1 s, 60 intents that each claim 0.1 s
- **THEN** the host moves that player at most 5 tiles (1.25 s of walking at 4 tiles/s)

#### Scenario: Solo player during a long frame
- **GIVEN** a solo player walking east
- **WHEN** 120 frames of input are stepped at once
- **THEN** all 120 are applied and the player walked 8 tiles

#### Scenario: Quick-chat spam
- **GIVEN** a player who has not used quick chat
- **WHEN** they pick 5 phrases at once
- **THEN** 3 bubbles are shown and the next phrase is accepted 2 s later
