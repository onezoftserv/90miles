# coop-networking

## Purpose
Host-and-join co-op for 1–4 players using Godot high-level multiplayer through a platform backend (ENet by default).

## Requirements

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
If a client disconnects, its player SHALL stay in the world as downed for 90 s, then be removed from every peer; the host announces the removal with the player's last position so its inventory can be dropped there. Every peer, a client joining later included, SHALL know that the player is disconnected until it is removed or taken back. If the same player joins again before its 90 s are up (see "Player identity"), it takes back that same body, standing again unless its meters had it downed. When a dropped player's body still on the island is all that keeps the party from landing on the next island (escape-routes "Split parties"), its time left is cut to at most 30 s. A removed player counts as dead for the rest of the run: the run summary lists them as dead, they are not a survivor for the ending, and they earn no further Experiencia. A dropped player does not hold a place in the player cap. If the host disconnects, the session ends and clients see a "host lost" screen; migration is out of scope for v1. Solo has no client to drop and no host to lose, so none of this applies with one player.

#### Scenario: Client drops
- **GIVEN** a client's player on the island
- **WHEN** that client disconnects
- **THEN** the player stays in the world downed for 90 s, then is removed from every peer, and the removal is announced with the player's last position so its inventory can be dropped there

#### Scenario: Every peer knows who dropped
- **GIVEN** a host and two clients, Dayana and Papo, on the sandbar
- **WHEN** Papo's client disconnects
- **THEN** the host and Dayana's client both hold Papo's player as disconnected, and a third client that joins during Papo's 90 s holds it as disconnected too

#### Scenario: Rejoin within 90 s
- **GIVEN** Papo's player at health 60 and thirst 40, standing on the beach, and Papo's client drops
- **WHEN** Papo's client joins again 20 s later from the same install
- **THEN** Papo controls the same body again, standing where it lay, with health 60 and thirst 40, and every other player sees that body come back as Papo's and no longer disconnected

#### Scenario: The hold is cut when it alone keeps the party waiting
- **GIVEN** a 2-player run where the host's crossing has ended and they wait, and the client's player is on the sandbar
- **WHEN** the client disconnects
- **THEN** the client's player is removed 30 s later, not 90 s, and counts as dead

#### Scenario: Reconnect into a full session
- **GIVEN** a session with four players
- **WHEN** one client drops and a client from another install connects before the 90 s are up
- **THEN** it joins as a new player while the dropped player is still downed in the world

#### Scenario: Rejoin after removal
- **GIVEN** Papo's client dropped and his player was removed after 90 s
- **WHEN** Papo's client joins again
- **THEN** Papo joins as a new player at a spawn point, and the run summary still lists the removed player as dead

#### Scenario: Removed player in the summary
- **GIVEN** a co-op run in which Papo was removed after a disconnect
- **WHEN** every remaining player dies
- **THEN** the run summary lists Papo as dead along with the others

#### Scenario: Host drops
- **GIVEN** a session with a host and a client
- **WHEN** the host disconnects
- **THEN** the client's session ends and it shows the "host lost" screen

#### Scenario: Solo run stays closed
- **GIVEN** a solo run, offline
- **WHEN** another game tries to join it mid-run
- **THEN** there is no port to reach, and the solo player keeps playing alone

### Requirement: Difficulty scaling
Difficulty SHALL be counted from the living, connected players when each island is set up: resource spawn rates multiply by 0.8 per such player beyond the first, and patrol count adds 1 per 2 such players, rounded down. Dropped and dead players do not count. One player (solo, or the last survivor of a party) gets ×1 and +0 patrols. Solo uses the same base numbers as co-op; there is no separate solo tuning. The secret cay (secret-cay) is never scaled: its handmade contents are the same for 1–4 players and it has no patrols. (Changes docs/GAME_DESIGN.md §10 "Co-op rules" for the cay only.)

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

#### Scenario: The cay is not scaled
- **GIVEN** a session with 4 players
- **WHEN** the secret cay is set up
- **THEN** it holds the same pick-ups, palms and coconuts as for one player, and no patrol

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

### Requirement: Pause
In a solo session (one player, offline) the pause button SHALL open the pause menu and freeze the whole simulation (clock, meters, creatures, patrols, weather) until the player resumes. Co-op has no pause: with other players, or while hosting, the pause button pauses nothing and opens no menu; it only closes an open HUD panel (inventory-hud's crafting list). Save-and-quit is out of scope.

#### Scenario: Solo pause
- **GIVEN** a solo player
- **WHEN** they press pause
- **THEN** the pause menu shows and nothing in the simulation advances, and when they resume it runs again from where it stopped

#### Scenario: No pause in co-op
- **GIVEN** a host with a client
- **WHEN** either player presses pause
- **THEN** nothing pauses and no pause menu shows

#### Scenario: Pause closes a panel in co-op
- **GIVEN** a host with a client whose crafting list is open
- **WHEN** the client presses pause
- **THEN** the list closes, and nothing pauses

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

### Requirement: Removed player's cause
A player removed after their 90 s SHALL count as dead with the cause `removed`, unless their meters had already died while they were away, in which case that cause stays. Every peer keeps the causes with the removed names, in removal order, and a client that joins later receives both. Solo has no client to remove, so this never applies with 1 player.

#### Scenario: Removed after 90 s
- **GIVEN** a host, Dayana and Papo in a run
- **WHEN** Papo drops and 90 s pass
- **THEN** the host and Dayana list Papo as removed with the cause `removed`

#### Scenario: Drowned while away
- **GIVEN** Papo dropped while swimming in a crossing, and his player drowned before his 90 s were up
- **WHEN** his 90 s run out
- **THEN** every peer lists Papo as removed with the cause `drowning`

#### Scenario: A later joiner
- **GIVEN** a run in which Papo was removed
- **WHEN** Yuni joins
- **THEN** Yuni's session lists Papo as removed with the cause `removed`

### Requirement: Player identity
Each install SHALL keep a random player id and a separate secret, made on first launch and kept across launches. A client's join request carries both. For the run, the host remembers which player each id belongs to and a hash of its secret, and never sends ids or secrets to other clients. Solo sends no join request; its one player is always the host's own.

#### Scenario: The id is kept
- **GIVEN** a fresh install that is launched, closed and launched again
- **WHEN** it joins a session
- **THEN** it presents the same player id both times

### Requirement: Reclaiming a player
A join request SHALL reclaim a player only when its id and secret match a player who is still in the world: one who dropped, or one whose old connection the host still holds (a client that crashed and came back before the host noticed; the host closes the old connection first). The host's own player is never reclaimed. Otherwise the client joins as a new player: no id, a wrong secret, or the host's id (a host and a client started from the same install). Solo has nobody to reclaim.

#### Scenario: Someone else's id
- **GIVEN** Papo's client dropped and his player lies downed
- **WHEN** another client joins presenting Papo's id with a different secret
- **THEN** it joins as a new player and Papo's body stays downed, waiting for Papo

#### Scenario: Back before the host noticed
- **GIVEN** Papo's client crashed and the host still holds his old connection
- **WHEN** Papo's client joins again from the same install
- **THEN** the host closes the old connection and Papo takes back the same body

#### Scenario: The host's id
- **GIVEN** a host and a client started from the same install
- **WHEN** the client joins presenting the host's id and secret
- **THEN** it joins as a new player and the host keeps its own player

#### Scenario: Rejoin during a crossing
- **GIVEN** Papo is a rider on a raft crossing when his client drops
- **WHEN** he rejoins within 90 s
- **THEN** the host keeps him as the same rider: his state on the raft, his own climb point, a teammate's pull handle on him, and his entry in the crossing's result

#### Scenario: Rejoin after leaving by a route
- **GIVEN** Papo left the island by a route and his client drops
- **WHEN** he rejoins within 90 s
- **THEN** he still counts as gone by that route, so the run can end without him

### Requirement: Join request
A joining client's player SHALL spawn when the host receives its join request, not when it connects, so that the host can match the player id first. A peer that connects but sends no join request within 10 s is disconnected, and its slot is free again. The host's start of the run spawns only players whose join request has arrived. Solo has no joiners: its one player spawns at once.

#### Scenario: A peer that never asks to join
- **GIVEN** a host in a run
- **WHEN** a peer connects and sends no join request for 10 s
- **THEN** the host disconnects it, no player spawned for it, and another client can take the slot

#### Scenario: Solo spawns at once
- **GIVEN** a player who starts a solo run, offline
- **WHEN** the session starts
- **THEN** their player spawns at once, with no join request and no wait

### Requirement: Structure state on every peer
The host's state of each palm (coconuts left), fire (lit or out) and rain catcher (cups waiting) SHALL reach every client in the run when it changes, and a client SHALL show that state in its look; a fire also counts as lit there, and can be put out there, only while it is lit on the host. A client never changes these itself. Exactly 1 player, offline, is their own host: their structures behave as before and nothing is sent.

#### Scenario: A solo player's structures
- **GIVEN** one offline player on the sandbar beside a palm with 2 coconuts, a lit fire they built and a rain catcher
- **WHEN** they climb the palm, a squall fills the catcher for 30 s, they take the cup and they put the fire out
- **THEN** the palm has 1 coconut, they carry the rain cup and the catcher holds none, the fire is out and no longer a lit fire, and no structure message was sent

#### Scenario: A client sees a palm climbed on the host
- **GIVEN** a host and a client on the sandbar, a palm with 2 coconuts on both
- **WHEN** the host's player climbs it
- **THEN** the client's palm has 1 coconut and draws 1

#### Scenario: A client sees a fire go out
- **GIVEN** a host and a client, and a fire the host built, lit on both
- **WHEN** a player puts it out on the host, or it burns its 360 s out there
- **THEN** on the client it is out: drawn as embers, not a lit fire, and no "[E] Apagar" prompt over it

#### Scenario: A client sees the catcher fill and empty
- **GIVEN** a host and a client, and a rain catcher the host built
- **WHEN** a squall fills it on the host and later the host's player takes the cup
- **THEN** the client's catcher first holds 1 cup and draws water, then holds none and draws empty

### Requirement: Structure state for joiners
A client that joins the run, or rejoins and takes back its player, SHALL get the host's current palm, fire and rain-catcher state once it stands on the host's island, also when that island is not the first. Raft sites and rafts keep reaching joiners as the host has them (crafting-inventory "Placed sites on every peer"). Exactly 1 player, offline, has no joiner and sends nothing.

#### Scenario: A late joiner sees what was used
- **GIVEN** a host who climbed a palm from 2 coconuts to 1, put out a fire it built and has a filled rain catcher
- **WHEN** a client joins the run
- **THEN** the client's palm has 1 coconut, its fire is out and its catcher holds 1 cup

#### Scenario: A rejoined player sees what changed while away
- **GIVEN** a client that dropped, and a palm the host climbed while it was away
- **WHEN** the client rejoins within 90 s and takes back its player
- **THEN** its palm has the host's count

#### Scenario: A joiner on the second island
- **GIVEN** a host whose party travelled to the coast cay, where the host's player climbed a palm
- **WHEN** a client joins the run
- **THEN** the client builds the coast cay and its palm has the host's count, not the layout's

#### Scenario: A joiner during the crossing
- **GIVEN** a host who built the raft at the sandbar's raft site and launched it, so the sandbar has a fresh, empty site and the raft is at sea
- **WHEN** a client joins during the crossing
- **THEN** the client's sandbar has an unbuilt raft site with nothing deposited and no raft, as the host's has

#### Scenario: A joiner before the launch
- **GIVEN** a host who built the raft at the sandbar's raft site and has not launched it
- **WHEN** a client joins the run
- **THEN** the client has the raft and no site

### Requirement: Structure messages come only from the host
A client SHALL apply a structure message only when the host sent it, and only to a structure on its own current island or in its own session, with a palm's count held between 0 and its layout's count. Anything else is dropped. A client cannot change another peer's structures, by a message or by changing its own copy. Exactly 1 player, offline, receives no messages.

#### Scenario: A client forges a structure message
- **GIVEN** a host and two clients
- **WHEN** one client sends the host and the other client a message saying a palm has 0 coconuts, and puts out its own copy of a lit fire
- **THEN** the host's and the other client's palm and fire are unchanged

#### Scenario: A count out of range
- **GIVEN** a client on the sandbar
- **WHEN** a message from the host gives a palm 9 coconuts, more than its layout's 2, or a negative count
- **THEN** the palm shows 2, or 0
