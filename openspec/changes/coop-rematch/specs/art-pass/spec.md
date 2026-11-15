## ADDED Requirements

### Requirement: Look slots in a rematch
In a co-op rematch (coop-networking "Rematch with the same party") the host SHALL give each player still connected the look slot their body had when the run ended, whatever order their join requests come in. A player new to the party takes the lowest slot that nobody holds or keeps for a connected player. A kept slot of a player who disconnects before the run starts becomes free. Solo has no rematch: a solo player is slot 0.

#### Scenario: The same looks again
- **GIVEN** a host in slot 0 and clients Papo in slot 2 and Dayana in slot 1, after a player who held slot 1 was removed and Dayana joined
- **WHEN** the host picks "Otra vez", Papo and Dayana answer in that order, and the host starts the run
- **THEN** Papo is drawn in slot 2 and Dayana in slot 1 on every peer

#### Scenario: A newcomer to the rematch
- **GIVEN** a rematch lobby where the host keeps slot 0 and Papo keeps slot 1
- **WHEN** a new client joins the lobby before Papo's join request arrives, and the host starts the run
- **THEN** the newcomer gets slot 2 and Papo keeps slot 1

## MODIFIED Requirements

### Requirement: Player look slots
When a player body spawns, the host SHALL give it the lowest look slot (0–3) that no other body holds and send it with the spawn, so every peer and every late joiner draws the same slot; if all four are held (a dropped body still waiting out its 90 s), it takes the lowest slot a dropped body holds. A rejoiner who reclaims their body keeps its slot; a removed player's slot becomes free. A rematch keeps each player's slot ("Look slots in a rematch"). A solo player is slot 0. The slot changes only drawing.

#### Scenario: Join, removal and a new joiner
- **GIVEN** a host in slot 0 and two clients who joined in that order and got slots 1 and 2
- **WHEN** the first client is removed and a third client joins
- **THEN** the third client gets the freed slot 1, and the second client keeps slot 2

#### Scenario: A joiner while a dropped body waits
- **GIVEN** four players in slots 0 to 3
- **WHEN** the client in slot 2 drops and a new client joins within 90 s
- **THEN** the new client gets slot 2 while the dropped body is still drawn in slot 2, and no other body changes slot

#### Scenario: A rejoin keeps the slot
- **GIVEN** a client in slot 1 who drops and rejoins within the downed window
- **WHEN** they reclaim their body
- **THEN** it is still drawn in slot 1 on every peer

#### Scenario: Solo
- **WHEN** a solo player starts a run offline
- **THEN** their body is slot 0
