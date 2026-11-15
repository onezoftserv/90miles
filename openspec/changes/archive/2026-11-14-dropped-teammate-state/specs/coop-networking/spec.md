## MODIFIED Requirements

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
