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
A teammate touching a captive with no soldier within 3 tiles SHALL free them. Captives on the docked boat can be freed by sneaking aboard. When no other living player is free (always so in a 1-player run), nobody is left to free the captive: the capture is a whole-party capture and follows Capture outcome at once.

#### Scenario: Unguarded captive
- GIVEN a captive with the nearest soldier 4 tiles away
- WHEN a teammate touches the captive
- THEN the captive is freed

#### Scenario: Solo player is never held on the dock
- GIVEN a 1-player run whose player is caught by a soldier's 2 s touch
- WHEN the capture completes
- THEN the player is not held on the boat for 3 minutes; `la_captura` plays at once

### Requirement: Capture outcome
If every living player is captured (solo: the only player), `la_captura` SHALL play with Rodríguez; a persuasion check (morale ≥ 60 and a Maestro or Médico present) releases the party at the next cay; otherwise the party restarts the previous island with inventory intact minus fire sources, keepsakes always kept. A single captive left aboard when the boat departs, while another player is still free, respawns on the previous island with no items. (Changes docs/GAME_DESIGN.md §9.)

#### Scenario: Persuasion succeeds
- GIVEN every player is captured, morale is 65 and a Médico is in the party
- WHEN the `la_captura` scene plays with Rodríguez
- THEN the party is released at the next cay

#### Scenario: Solo Médico talks their way out
- GIVEN a 1-player run on island 2 whose only player is a Médico with morale 65
- WHEN a soldier captures the player
- THEN `la_captura` plays, the check passes and the player is released at the next cay

#### Scenario: Solo capture fails
- GIVEN a 1-player run on island 3 whose only player is a Pescador with morale 40, carrying a knife, 3 rope, a lighter and the Foto de la familia keepsake
- WHEN a soldier captures the player
- THEN `la_captura` plays, the check fails (morale 40 < 60, no Maestro or Médico), and the player restarts island 2 holding the knife, the 3 rope and the Foto, without the lighter

### Requirement: Fade with distance
Mid chains SHALL spawn patrols at 30% of coast rate, far chains at 0%, the final crossing exactly one.

#### Scenario: Far chain
- GIVEN a far-chain island
- WHEN it is generated
- THEN it has no patrols

### Requirement: Previous island after capture
When a capture sends the party back, the previous island SHALL be regenerated from the run seed and set up again for the living, connected players at that moment (Resource spawns, Escape routes), and the party SHALL restart on its landing beach. On island 1, which has no previous island, the party SHALL restart island 1, regenerated from the run seed the same way, with the same inventory rule (minus fire sources, keepsakes kept).

#### Scenario: Previous island is fresh
- GIVEN a 1-player run whose player used all the driftwood on island 2 for a raft and was then captured on island 3 with persuasion failing
- WHEN the player restarts island 2
- THEN island 2 has the terrain, POIs and resources it had on first arrival, from the same run seed

#### Scenario: Caught on the sandbar
- GIVEN a 1-player run on island 1 whose player carries a knife, 3 rope, a lighter and the Foto de la familia keepsake, with morale 40
- WHEN a shore squad captures the player and persuasion fails
- THEN island 1 is regenerated from the run seed and the player lands on its beach with the knife, the 3 rope and the Foto, without the lighter

### Requirement: Capture on the final crossing
If every living player is captured during the final crossing, the run SHALL end with the `devuelto` ending (endings-progression) instead of Capture outcome: no persuasion check is rolled and no island is restarted.

#### Scenario: Solo player caught in the Straits
- GIVEN a 1-player run on the final crossing with morale 70 and a Maestro as the only player
- WHEN the final patrol captures the player
- THEN no persuasion check is rolled, the run ends and the `devuelto` ending plays
