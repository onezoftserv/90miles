# Spec Delta

## ADDED Requirements

### Requirement: Departures reach joiners
A peer that joins the run, or rejoins and takes back its body, SHALL learn from the host which players already left by a route and by which one, under each player's current peer. Learning it starts nothing. Riders whose crossing already ended stay out of play on the joiner's screen, as on the host's. With exactly 1 player, offline, nobody can join, and leaving by a route works as before.

#### Scenario: A late joiner learns who left
- **GIVEN** a 2-player run in which the client left by "Prismáticos y a nadar" and the host stayed on the island
- **WHEN** a third player joins
- **THEN** the third player's game has the client as having left by that route and the host as still on the island, and no crossing starts because of it

#### Scenario: Riders of an ended crossing stay out of play
- **GIVEN** a 2-player run whose client crossed by raft and whose crossing has ended, while the host stays on the island
- **WHEN** a third player joins
- **THEN** the third player does not see the client's body on the island

#### Scenario: A rejoined rider is still gone
- **GIVEN** a 2-player run whose client left by raft, and the client's crossing still under way
- **WHEN** the client drops and joins again from the same install
- **THEN** the client's game has them as having left by "Balsa" under their new peer, and the run does not end while their crossing runs

#### Scenario: Solo departure unchanged
- **GIVEN** a 1-player run, offline, with a built raft
- **WHEN** the player launches it
- **THEN** the player leaves the island by "Balsa" as before, and nothing is sent to anyone
