# player-movement

## Purpose
Top-down movement, swimming and basic interaction for 1–4 players.

## Requirements

### Requirement: Walk, run, crouch
The player SHALL move on land with WASD/left stick at 4 tiles/s walking, 6 running, 2 crouching. Running drains 0.5 energy/s. Crouching sets the player's stealth state to hidden while on brush or mangrove tiles.

#### Scenario: Running on sand
- GIVEN a player with energy 50 on a beach tile
- WHEN the player holds run for 10 s
- THEN energy is 45 and the player moved 60 tiles

### Requirement: Swimming
The player SHALL swim in shallow and deep water at 3 tiles/s, draining 3 energy/s. At energy 0 the player can only float and drifts with current. Diving (hold crouch in water) hides the player from searchlights for 5 s and costs 10 energy.

#### Scenario: Exhausted swimmer
- GIVEN a player swimming with energy 3
- WHEN 1 s passes
- THEN the player is floating, speed 0, and drifts 1 tile/s in the current direction

### Requirement: Interaction
The player SHALL interact with the nearest interactable within 1 tile via a single button: pick up, talk, use, climb. Hold for 2 s on timed interactions (drag a downed player, pull a trap, cut a net).

#### Scenario: Drag a downed teammate
- GIVEN a downed teammate adjacent to the player
- WHEN the player holds interact
- THEN the teammate follows the player at 2 tiles/s until released

### Requirement: Camera and viewport
The game SHALL render at 640×360 with integer scaling and nearest filtering. In co-op each client follows its own player; the host sees the same.

#### Scenario: Two players apart
- GIVEN two players in a co-op session
- WHEN they move apart
- THEN each client's camera follows its own player, rendered at 640×360 with integer scaling and nearest filtering
