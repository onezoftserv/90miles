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
The Gulf Stream SHALL push the vessel east at 1 tile/s on mid and far crossings. A Maestro or anyone with compass+charts can steer against it; otherwise the party drifts and the crossing lengthens 30 s per 10 tiles of drift. Overshooting by 40 tiles skips to a harder chain.

#### Scenario: No one steers
- GIVEN a mid crossing with no Maestro and no compass+charts aboard
- WHEN the Gulf Stream pushes the vessel 20 tiles east
- THEN the crossing lengthens by 60 s

### Requirement: Threat scripts
The scene SHALL support scripted events in order: shark pass, squall line (1 min warning), searchlight (coast only), tiger shark (reef only), lighthouse beam (final, if lit), Miami fisherman (final, if met).

#### Scenario: Searchlight on the first crossing
- GIVEN a coast-chain crossing at night
- WHEN the cutter's searchlight sweeps and a player is lit for 2 s
- THEN the cutter chases; players can cut the sail (go dark) or reach fog or the reef line to escape

### Requirement: Fall in and rescue
A player who falls in SHALL swim alongside; a teammate can pull them aboard with a 2 s interact. Sharks target swimmers who are bleeding or below 20 energy.

#### Scenario: Pulled aboard
- GIVEN a player who fell in, swimming alongside the vessel
- WHEN a teammate holds interact on them for 2 s
- THEN the player is back aboard

### Requirement: Arrival
On arrival, players SHALL spawn on the next island's beach scattered within 5 tiles, the vessel beached with its remaining integrity (reusable if intact).

#### Scenario: Raft arrives damaged
- GIVEN a raft that ends the crossing with integrity 40
- WHEN the party arrives
- THEN the players spawn on the next island's beach within 5 tiles of each other and the raft is beached there with integrity 40
