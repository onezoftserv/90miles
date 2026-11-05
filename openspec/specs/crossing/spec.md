# crossing

## Purpose
The 60–120 s scrolling-sea scene between islands, where the run's tension peaks.

## Requirements

### Requirement: Crossing scene
A crossing SHALL be its own scene with a vertically scrolling sea, the vessel (raft, boat, turtle, swimmers), and threat spawns rolled from the route's risk profile, distance band and current weather.

### Requirement: Vessel integrity
Rafts and boats SHALL have integrity (raft 100, repaired boat 200). Squalls −30, shark hit −20, rock −40. At 0, the vessel breaks: players fall in and must swim the remainder (energy permitting) or drown.

### Requirement: Steering and current
The Gulf Stream SHALL push the vessel east at 1 tile/s on mid and far crossings. A Maestro or anyone with compass+charts can steer against it; otherwise the party drifts and the crossing lengthens 30 s per 10 tiles of drift. Overshooting by 40 tiles skips to a harder chain.

### Requirement: Threat scripts
The scene SHALL support scripted events in order: shark pass, squall line (1 min warning), searchlight (coast only), tiger shark (reef only), lighthouse beam (final, if lit), Miami fisherman (final, if met).

#### Scenario: Searchlight on the first crossing
- GIVEN a coast-chain crossing at night
- WHEN the cutter's searchlight sweeps and a player is lit for 2 s
- THEN the cutter chases; players can cut the sail (go dark) or reach fog or the reef line to escape

### Requirement: Fall in and rescue
A player who falls in SHALL swim alongside; a teammate can pull them aboard with a 2 s interact. Sharks target swimmers who are bleeding or below 20 energy.

### Requirement: Arrival
On arrival, players SHALL spawn on the next island's beach scattered within 5 tiles, the vessel beached with its remaining integrity (reusable if intact).
