# crossing

## Purpose
The 60–120 s scrolling-sea scene between islands, where the run's tension peaks.

## Requirements

### Requirement: Crossing scene
A crossing SHALL be its own scene with a vertically scrolling sea, the vessel (raft, boat, turtle, swimmers), and threat spawns rolled from the route's risk profile, distance band and current weather.

#### Scenario: Crossing loads from the route
- GIVEN a route that starts a crossing
- WHEN the crossing scene loads
- THEN the sea scrolls vertically with the party's vessel, and threat spawns are rolled from that route's risk profile, its distance band and the current weather

### Requirement: Vessel integrity
Rafts and boats SHALL have integrity (raft 100, repaired boat 200). Squalls −30, shark hit −20, rock −40. At 0, the vessel breaks: players fall in and must swim the remainder (energy permitting) or drown.

#### Scenario: Raft breaks
- GIVEN a raft at integrity 100
- WHEN it takes a squall (−30), a rock (−40) and a second squall (−30)
- THEN integrity is 0, the raft breaks and the players fall in

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

### Requirement: Threat scripts
The scene SHALL support scripted events in order: shark pass, squall line (1 min warning), searchlight (coast only), tiger shark (reef only), lighthouse beam (final, if lit), Miami fisherman (final, if met).

#### Scenario: Searchlight on the first crossing
- GIVEN a coast-chain crossing at night
- WHEN the cutter's searchlight sweeps and a player is lit for 2 s
- THEN the cutter chases; players can cut the sail (go dark) or reach fog or the reef line to escape

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

### Requirement: Arrival
On arrival, players SHALL spawn on the next island's beach scattered within 5 tiles, the vessel beached with its remaining integrity (reusable if intact).

#### Scenario: Raft arrives damaged
- GIVEN a raft that ends the crossing with integrity 40
- WHEN the party arrives
- THEN the players spawn on the next island's beach within 5 tiles of each other and the raft is beached there with integrity 40
