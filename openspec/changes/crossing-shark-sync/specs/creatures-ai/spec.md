# Spec Delta

## ADDED Requirements

### Requirement: Every peer sees the crossing shark
The crossing's reef shark SHALL be a host-run creature like the island's: every peer in the crossing's session sees it beside its victim or the vessel, a peer that joins during its circle sees it too, and it leaves every screen when its circle ends on the host. It is a passing creature, not one of the island's: phases, fires and island counts ignore it. With exactly 1 player, offline, the lone player sees it and it leaves after its circle time, as before.

#### Scenario: A client sees the shark that bites them
- **GIVEN** a host and a client on a raft crossing, the client in the water at energy 15
- **WHEN** the shark pass comes
- **THEN** the client's screen shows a reef shark beside the client's player, and after its circle time it is gone there too

#### Scenario: A late joiner sees the circling shark
- **GIVEN** a reef shark circling during a crossing
- **WHEN** a client joins before the circle ends
- **THEN** the client sees the shark where the host has it

#### Scenario: The crossing shark is not an island creature
- **GIVEN** a crossing whose shark is circling while the island's night creatures are out
- **WHEN** dawn comes or a fire is lit on the island
- **THEN** the island's spawner neither counts nor removes the crossing's shark

#### Scenario: Solo crossing shark is unchanged
- **GIVEN** a 1-player raft crossing, offline, whose player swims at energy 15
- **WHEN** the shark pass comes
- **THEN** a reef shark appears, the player loses 25 health and bleeds, and the shark is gone after its circle time
