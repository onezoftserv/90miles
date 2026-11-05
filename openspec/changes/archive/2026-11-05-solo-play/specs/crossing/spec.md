# Spec Delta

## MODIFIED Requirements

### Requirement: Steering and current
The Gulf Stream SHALL push the vessel east at 1 tile/s on mid and far crossings. Any player aboard steers against it with no held station, cutting drift to 0.25 tile/s; a Maestro, a player with Navigation ≥ 2 or anyone with compass+charts aboard cancels drift. With nobody aboard, drift stays 1 tile/s. Drift is a lateral offset capped at 40 tiles and never lengthens the crossing; a crossing whose offset reached the cap skips to a harder chain. (Changes docs/GAME_DESIGN.md §8.)

#### Scenario: No one steers
- GIVEN a mid crossing with no Maestro and no compass+charts aboard
- WHEN the Gulf Stream pushes the vessel 20 tiles east
- THEN the drift offset is 20 tiles and the crossing's length is unchanged

#### Scenario: Solo player steers weakly
- GIVEN a 1-player run whose only player is a Pescador with Navigation 0 and no compass or charts, aboard a raft on a 120 s far crossing
- WHEN the crossing runs to its end, including a squall during which the player ties down
- THEN drift was 0.25 tile/s throughout, the offset ends at 30 tiles, the crossing lasted 120 s and the party arrives at the chosen island

#### Scenario: Solo Maestro cancels drift
- GIVEN a 1-player run whose only player is a Maestro aboard a raft on a 90 s mid crossing
- WHEN the crossing ends
- THEN the drift offset is 0 tiles

#### Scenario: Offset reaches the cap
- GIVEN a 1-player run on a 120 s far crossing whose player, at energy 100, falls in at 20 s and climbs back aboard at 40 s, with nobody aboard in between
- WHEN the crossing runs to its end
- THEN the offset is 25 tiles at 40 s, reaches 40 tiles at 100 s and grows no further, the crossing still ends at 120 s, and the party arrives on a harder chain

### Requirement: Fall in and rescue
A player who falls in SHALL swim alongside; a teammate can pull them aboard with a 2 s interact. A player in the water within 1 tile of the vessel's edge, while the vessel is intact (integrity above 0), SHALL also be able to climb aboard alone by holding interact for 3 s, so the teammate's pull stays faster but is never required. Sharks target swimmers who are bleeding or below 20 energy.

#### Scenario: Pulled aboard
- GIVEN a player who fell in, swimming alongside the vessel
- WHEN a teammate holds interact on them for 2 s
- THEN the player is back aboard

#### Scenario: Solo player climbs back aboard
- GIVEN a 1-player run whose player fell in and is swimming within 1 tile of a raft at integrity 60
- WHEN the player holds interact on the raft's edge for 3 s
- THEN the player is back aboard and no teammate was needed

#### Scenario: Releasing early does not climb
- GIVEN a 1-player run whose player is in the water within 1 tile of a raft at integrity 60
- WHEN the player holds interact for 2 s and releases
- THEN the player is still in the water and holding again starts from 0 s
