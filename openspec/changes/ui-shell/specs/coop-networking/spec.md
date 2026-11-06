# Spec Delta

## MODIFIED Requirements

### Requirement: Host and join
A player SHALL host a session on a port (default 7777) and up to three others SHALL join by IP; a fifth connected player is refused. Solo play runs the same code path with the host as the only peer and opens no network port: a run that neither hosts nor joins is solo, and nothing waits for a second peer. A co-op session first gathers in a lobby: each client sends its player name once when it joins, and players spawn when the host starts the run; a client that joins once the run has started spawns at once. A joining client receives the host's world state (island seed, current weather, time of day) and every spawned entity, and its player spawns at one of the island's beach spawn points.

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

### Requirement: Quick chat
Players SHALL have a radial quick-chat, opened by holding the quick-chat button, with 8 phrases (¡Dale!, ¡Agua!, ¡Pa'llá no!, ¡Tiburón!, ¡Patrulla!, ¡Ayuda!, ¡Comida aquí!, ¡Vámonos!). The phrases are content data. A picked phrase goes through the host, which shows it to every player as a speech bubble over the speaker. Each phrase also plays its short voice clip once that clip exists; recorded voice lines arrive with Milestone G. In solo the wheel is hidden: the button does nothing and no bubble shows (decided 2026-11-05).

#### Scenario: Shark warning
- GIVEN a player with the radial quick-chat open
- WHEN they pick ¡Tiburón!
- THEN every player sees a ¡Tiburón! speech bubble over that player, and its short voice clip plays if one exists for that phrase

#### Scenario: Rewording a phrase
- **WHEN** a writer changes a phrase in the quick-chat content file
- **THEN** the wheel and the bubbles show the new wording with no script change

#### Scenario: No quick chat in solo
- **GIVEN** a solo player
- **WHEN** they hold the quick-chat button
- **THEN** no wheel opens and no bubble shows

### Requirement: Intents reach only the host and act only for their sender
A client SHALL send intents only to the host. The host SHALL ignore intents that arrive anywhere but on the host and SHALL apply each intent only to the sending peer's own player, whatever the intent contains. Messages from the host to clients SHALL be accepted only from the host, and clients SHALL NOT relay messages to each other. The host's own (and the solo) player's intents take the same path. A client's join request, which carries its player name, is accepted once per peer; later ones are ignored, and the name is cleaned (unprintable, direction and invisible characters removed, at most 16 characters; when empty, "Balsero N" with the first N from the lobby's size up that no one in the lobby has).

#### Scenario: Client acts as a teammate
- **GIVEN** a session with clients A and B
- **WHEN** client A sends movement intents, including ones addressed to B's player
- **THEN** only A's player moves and B's player stays where B's own intents put it

#### Scenario: Client forges a host message
- **GIVEN** a session with clients A and B
- **WHEN** client A sends a message only the host may send, such as showing a quick-chat bubble
- **THEN** no peer shows the bubble

#### Scenario: Client renames itself over and over
- **GIVEN** a client that has joined as "Papo"
- **WHEN** it sends 50 more join requests with other names
- **THEN** the roster still shows "Papo" and the host sends no further roster updates for those requests
