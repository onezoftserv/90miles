## ADDED Requirements

### Requirement: Mending a built raft
A built raft that has not launched (beached after a crossing, or built and still on the island) SHALL take a mend while its integrity is below its maximum: 1 driftwood and 1 rope, then 10 s of base work (Building skill, twice as fast for a Mecánico), then +20 integrity, never above the maximum. A mend can repeat. A raft at its maximum takes none. With exactly 1 player, that player deposits and works it alone. (Adds the numbers to docs/GAME_DESIGN.md §6 "Durability".)

#### Scenario: Solo mends on the coast cay
- **GIVEN** a 1-player run, offline, whose raft is beached on the coast cay at integrity 48 of 100, the player carrying 1 driftwood and 1 rope
- **WHEN** they start a mend at the raft, deposit both and work it for 10 s
- **THEN** the raft is at 68 of 100, the driftwood and the rope have left their inventory, and the raft can be launched at 68

#### Scenario: Two mends in a row
- **GIVEN** the same player at the same raft, carrying 2 driftwood and 2 rope
- **WHEN** they finish one mend and then a second
- **THEN** the raft is at 88 of 100

#### Scenario: A mend stops at the maximum
- **GIVEN** a 1-player run whose beached raft is at 90 of 100
- **WHEN** a mend completes
- **THEN** the raft is at 100 of 100

#### Scenario: A whole raft takes no mend
- **GIVEN** a 1-player run whose raft is at 100 of 100, the player carrying 1 driftwood and 1 rope
- **WHEN** they ask for a mend
- **THEN** no job starts and nothing leaves their inventory

#### Scenario: A Mecánico mends faster
- **GIVEN** a 1-player run whose only player is a Mecánico, at a beached raft at 50 of 100 with a mend's inputs deposited
- **WHEN** they work it for 5 s
- **THEN** the raft is at 70 of 100

### Requirement: Raft fittings
A built raft that has not launched SHALL take each fitting once, after its inputs and work time (Building skill, twice as fast for a Mecánico). The three fittings are clavazón (4 nails, 20 s: maximum and integrity +20), defensas (1 inner tube and 1 rope, 10 s) and toldo (1 tarp and 2 driftwood, 15 s). A fitting the raft has is refused. A new fitting whose effects use existing stats is a data file with no script change. With exactly 1 player, that player fits the raft alone.

#### Scenario: Solo nails the raft on the coast cay
- **GIVEN** a 1-player run, offline, whose raft is beached on the coast cay at 70 of 100, the player carrying the 4 nails of the observation post
- **WHEN** they start the clavazón at the raft, deposit the nails and work it for 20 s
- **THEN** the raft is at 90 of 120 and has the clavazón, and the nails have left their inventory

#### Scenario: Solo puts a toldo on the sandbar raft
- **GIVEN** a 1-player run on the sandbar whose player has just built the raft at 100 of 100 and carries the hut's tarp and 2 driftwood
- **WHEN** they fit the toldo and work it for 15 s
- **THEN** the raft has a toldo and is still at 100 of 100

#### Scenario: A fitting only once
- **GIVEN** a 1-player run whose raft has the clavazón, the player carrying 4 more nails
- **WHEN** they ask for the clavazón again
- **THEN** no job starts and the nails stay in their inventory

#### Scenario: Fittings from data
- **GIVEN** the content catalog
- **WHEN** it loads `recipes/`
- **THEN** `raft_mend`, `raft_clavazon`, `raft_defensas` and `raft_toldo` load with Spanish and English names, and the content check reports no errors

### Requirement: Raft jobs are shared
A mend or a fitting SHALL be one job on the raft at a time, started by any player at the raft's work point. Any player deposits its inputs from their own inventory, progress is shared and shown to every peer, and work advances only while at least one player works it and every input is in. A client's start, deposit and work are intents the host applies. With exactly 1 player, that player does all of it.

#### Scenario: Two players pool a mend
- **GIVEN** a 2-player run whose raft is beached at 50 of 100, the host's player carrying 1 driftwood and the client's 1 rope
- **WHEN** the host's player starts a mend, both deposit and the client's player works it for 10 s
- **THEN** the raft is at 70 of 100 on both peers

#### Scenario: One job at a time
- **GIVEN** a 1-player run whose raft has an unfinished mend
- **WHEN** the player asks for the toldo
- **THEN** no second job starts until the mend is finished

#### Scenario: Nobody working
- **GIVEN** a raft whose mend has every input in and half its work done
- **WHEN** no player works it for 30 s
- **THEN** its progress is still half

### Requirement: A launch ends an unfinished job
When a raft launches with an unfinished job, the host SHALL end the job and give each deposited item back to the player who deposited it, or drop it on the raft's cell when that player's inventory is full. Work done on it is lost. A job never stops a launch. With exactly 1 player, the deposits go back to that player.

#### Scenario: Solo launches in the middle of a mend
- **GIVEN** a 1-player run whose beached raft is at 60 of 100 with an unfinished mend holding the player's 1 driftwood and no rope
- **WHEN** the player launches the raft
- **THEN** the crossing starts at 60 of 100 and the driftwood is back in the player's inventory

### Requirement: The raft's state on every peer
A built raft's integrity, maximum, fittings and open job (its deposits and progress) SHALL be decided by the host and shown the same on every peer, including a peer that joins or rejoins while the raft lies on the island. A joiner rolls nothing. With exactly 1 player, offline, nothing is sent and the raft keeps its state.

#### Scenario: A joiner sees a fitted raft
- **GIVEN** a host whose beached raft is at 90 of 120 with the clavazón and a toldo, and a mend with its inputs in and half done
- **WHEN** a client joins and stands at the raft
- **THEN** the client shows the raft at 90 of 120 with both fittings and the mend at half

#### Scenario: Solo fits offline
- **GIVEN** a 1-player run, offline
- **WHEN** the player fits the toldo
- **THEN** the raft has the toldo and nothing is sent to anyone
