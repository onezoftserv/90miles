# Spec Delta

## ADDED Requirements

### Requirement: Statuses are synced
A player's statuses (bleeding, and any later one) SHALL be host-authoritative and synced like the meters: only the host starts or ends one, and every peer, including one that joins later, reads the host's statuses for every player. A client never starts or ends a status. With exactly 1 player, offline, the player's own peer is the host and statuses work as before.

#### Scenario: A client knows it bleeds
- **GIVEN** a host and a client whose player is in the water during a crossing
- **WHEN** a shark bites the client's player on the host
- **THEN** the client's game has its own player bleeding, and when the host ends the bleeding, it ends on the client too

#### Scenario: A late joiner sees who bleeds
- **GIVEN** a host whose own player is bleeding
- **WHEN** a client joins
- **THEN** the client's game has the host's player bleeding

#### Scenario: Solo bleeding unchanged
- **GIVEN** a 1-player crossing, offline, whose player swims at energy 15
- **WHEN** the shark pass comes
- **THEN** the player bleeds, as before

### Requirement: Bleeding tag on the HUD
While the local player bleeds, their screen SHALL show a red "Sangrando" tag in the committed pixel font under the meter bars, and hide it when the bleeding ends. It follows the player's synced status, so a client's tag follows the host. The bars panel with the tag still fits the top-left quarter of 640×360. With exactly 1 player, offline, the tag works the same.

#### Scenario: Solo player sees they bleed
- **GIVEN** the HUD of a 1-player run, offline, whose player is not bleeding
- **WHEN** a shark bite makes the player bleed, and later the bleeding ends
- **THEN** the "Sangrando" tag shows under the bars while they bleed and is hidden after

#### Scenario: A client's tag follows the host
- **GIVEN** a host and a client whose player is in the water during a crossing
- **WHEN** the host's shark bites the client's player, and later the host ends the bleeding
- **THEN** the client's screen shows "Sangrando" under its bars, then hides it
