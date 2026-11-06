# Spec Delta

## MODIFIED Requirements

### Requirement: Disconnect handling
If a client disconnects, its player SHALL stay in the world as downed for 90 s, then be removed from every peer; the host announces the removal with the player's last position so its inventory can be dropped there. If the same player joins again before its 90 s are up (see "Player identity"), it takes back that same body, standing again unless its meters had it downed. A removed player counts as dead for the rest of the run: the run summary lists them as dead, they are not a survivor for the ending, and they earn no further Experiencia. A dropped player does not hold a place in the player cap. If the host disconnects, the session ends and clients see a "host lost" screen; migration is out of scope for v1. Solo has no client to drop and no host to lose, so none of this applies with one player.

#### Scenario: Client drops
- **GIVEN** a client's player on the island
- **WHEN** that client disconnects
- **THEN** the player stays in the world downed for 90 s, then is removed from every peer, and the removal is announced with the player's last position so its inventory can be dropped there

#### Scenario: Rejoin within 90 s
- **GIVEN** Papo's player at health 60 and thirst 40, standing on the beach, and Papo's client drops
- **WHEN** Papo's client joins again 20 s later from the same install
- **THEN** Papo controls the same body again, standing where it lay, with health 60 and thirst 40, and every other player sees that body come back as Papo's

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

## ADDED Requirements

### Requirement: Player identity
Each install SHALL keep a random player id and a separate secret, made on first launch and kept across launches. A client's join request carries both. For the run, the host remembers which player each id belongs to and a hash of its secret, and never sends ids or secrets to other clients. Solo sends no join request; its one player is always the host's own.

#### Scenario: The id is kept
- **GIVEN** a fresh install that is launched, closed and launched again
- **WHEN** it joins a session
- **THEN** it presents the same player id both times

### Requirement: Reclaiming a player
A join request SHALL reclaim a player only when its id belongs to a player who dropped and is still in the world, and its secret matches. Otherwise the client joins as a new player: no id, an id already held by a connected player, or a wrong secret. That includes a host and a client started from the same install. Solo has nobody to reclaim.

#### Scenario: Someone else's id
- **GIVEN** Papo's client dropped and his player lies downed
- **WHEN** another client joins presenting Papo's id with a different secret
- **THEN** it joins as a new player and Papo's body stays downed, waiting for Papo

#### Scenario: An id already in use
- **GIVEN** Papo is connected and playing
- **WHEN** a second client joins presenting Papo's id and secret
- **THEN** it joins as a new player and Papo keeps his player

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
