# guardacostas-stealth

## Purpose
The human threat: patrol boats, searchlights, shore squads and capture. Plus the player stealth model. Study: Brogue's stealth range and noise (`Monsters.c`, `playerMoves`), DCSS stealth skill.

## Requirements

### Requirement: Patrol route
Coast-chain islands SHALL have 1–2 patrol boats on fixed loops with a 3-minute period, visible on the horizon 20 s before passing the island's windward side.

#### Scenario: Patrol on the horizon
- GIVEN a coast-chain island with a patrol boat
- WHEN the boat is 20 s from passing the windward side
- THEN it is visible on the horizon, and it passes again 3 minutes later

### Requirement: Searchlight
At night a patrol SHALL project a 60° light cone of 10 tiles sweeping 30°/s across beach and water. A player inside the cone and not hidden for 2 s is spotted.

#### Scenario: Caught in the cone
- GIVEN night and a patrol's searchlight sweeping the beach
- WHEN a player who is not hidden stays inside the 60°, 10-tile cone for 2 s
- THEN the player is spotted

### Requirement: Hidden states
A player SHALL be hidden when: crouching on brush or mangrove, inside a structure, diving (5 s), or in fog. Stealth skill adds +1 s to the spot timer per level (max +3).

#### Scenario: Crouching in mangrove
- GIVEN a player crouching on a mangrove tile
- WHEN a searchlight cone covers them
- THEN they are hidden and are not spotted

### Requirement: Triggers
Spotting SHALL also happen from: smoke (any fire within 2 tiles of open shore at night, or any fire by day within 6 tiles of the shoreline), noise events ≥ radius 8 near the shore, and a player in the water within 6 tiles of the boat.

#### Scenario: Fire in the hut
- GIVEN a fire inside the ruined hut at night
- WHEN the patrol passes
- THEN no smoke event fires and the party is not spotted

### Requirement: Chase and shore squad
On spotting, the boat SHALL chase swimmers at 2× swim speed and, if the party is on land, land a 3-soldier squad that searches for 180 s (fire → last known position → random walk). Soldiers capture on a 2 s touch and walk captives to the boat.

#### Scenario: Squad lands
- GIVEN the party is spotted while on land
- WHEN the boat responds
- THEN it lands a 3-soldier squad that searches for 180 s: the fire first, then the last known position, then a random walk

### Requirement: Free a captive
A teammate touching a captive with no soldier within 3 tiles SHALL free them. Captives on the docked boat can be freed by sneaking aboard.

#### Scenario: Unguarded captive
- GIVEN a captive with the nearest soldier 4 tiles away
- WHEN a teammate touches the captive
- THEN the captive is freed

### Requirement: Capture outcome
If every player is captured, the `la_captura` scene plays with Rodríguez; a persuasion check (morale ≥ 60 and a Maestro or Médico present) releases the party at the next cay; otherwise the party restarts the previous island with inventory intact minus fire sources. A single captive left aboard when the boat departs respawns on the previous island with no items.

#### Scenario: Persuasion succeeds
- GIVEN every player is captured, morale is 65 and a Médico is in the party
- WHEN the `la_captura` scene plays with Rodríguez
- THEN the party is released at the next cay

### Requirement: Fade with distance
Mid chains SHALL spawn patrols at 30% of coast rate, far chains at 0%, the final crossing exactly one.

#### Scenario: Far chain
- GIVEN a far-chain island
- WHEN it is generated
- THEN it has no patrols
