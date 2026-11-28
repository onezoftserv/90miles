# guardacostas-stealth

## Purpose
The human threat: patrol boats, searchlights, shore squads and capture. Plus the player stealth model. Study: Brogue's stealth range and noise (`Monsters.c`, `playerMoves`), DCSS stealth skill.

## Requirements

### Requirement: Patrol route
Each patrol boat SHALL circle its island once per loop, through deep water 4 tiles outside the island's convex hull. A loop lasts 180 s plus 10 s per Experiencia level: 20 s on the horizon, then a 100 s lap in sight that starts and ends at the hull's east (windward) end, then out of sight. While the weather keeps patrols in port no boat is in sight. (Changes docs/BESTIARY.md "Guardacostas patrol boat".)

#### Scenario: Patrol on the horizon
- **GIVEN** a coast-chain island with one patrol boat
- **WHEN** the boat is 20 s from starting its lap
- **THEN** it is on the horizon, not in sight and with no light; its lap starts 20 s later at the east end and ends there 100 s after that; and the next horizon warning comes 180 s after the first

#### Scenario: One lap round the island
- **GIVEN** a solo player on the sandbar with its one boat
- **WHEN** a whole lap runs
- **THEN** the boat stayed on deep water at least 4 tiles outside the island's convex hull, went once round the island and ended at the east end where it started

#### Scenario: A squall keeps the patrol in port
- **GIVEN** a solo player on the coast cay and a boat in sight halfway through its lap
- **WHEN** a squall starts
- **THEN** the boat leaves sight at once with its light off, and no boat comes into sight until the squall has ended and a new 20 s horizon warning has run

#### Scenario: Experiencia lengthens the loop
- **GIVEN** a run at Experiencia level 2
- **WHEN** a boat's loop runs
- **THEN** the loop lasts 200 s, its horizon warning 20 s and its lap 100 s

### Requirement: Searchlight
At night each patrol boat in sight SHALL project a light cone 60° wide and 10 tiles long, sweeping back and forth at 30°/s over a 120° arc centred on the direction from the boat to the island's centre. Terrain does not block the light. It is off at dawn, by day and at dusk, and in weather that disables sight. A player inside a cone who is not hidden fills their spot meter.

#### Scenario: Caught in the cone
- **GIVEN** night and a patrol's searchlight sweeping the beach
- **WHEN** a player who is not hidden stays inside the 60°, 10-tile cone for 2 s
- **THEN** the player is spotted

#### Scenario: No light by day
- **GIVEN** a solo player standing on open sand by day, out of the water
- **WHEN** a boat in sight passes 4 tiles from them
- **THEN** no cone is drawn and the player's spot meter stays at 0

#### Scenario: The sweep faces the island
- **GIVEN** a boat in sight at night, its alert not running
- **WHEN** its beam is followed for 8 s
- **THEN** the beam's centre stayed within 60° of the direction from the boat to the island's centre, reversed at each end of that arc, and came back to where it started

### Requirement: Hidden states
A player SHALL be hidden from a patrol's sight while crouching on brush, while on mangrove in any posture, while on a roofed cell (a hut or post the island marks) in any posture, or while diving (at most 5 s). A hidden player's spot meter never fills. In weather that disables sight (fog) no player can be spotted by sight. Each Stealth level adds 1 s to the player's spot time, up to +3.

#### Scenario: Crouching in mangrove
- **GIVEN** a player crouching on a mangrove tile
- **WHEN** a searchlight cone covers them
- **THEN** they are hidden and are not spotted

#### Scenario: Standing in mangrove
- **GIVEN** a player standing upright on a mangrove tile at night
- **WHEN** a searchlight cone covers them for 5 s
- **THEN** they are hidden and are not spotted

#### Scenario: Standing in the hut
- **GIVEN** a solo player standing upright inside the sandbar's hut at night
- **WHEN** a searchlight cone covers them for 5 s
- **THEN** their spot meter stays at 0 and the hidden mark shows over them

#### Scenario: Crouch-walking through scrub
- **GIVEN** a solo player crouch-walking across scrub at night
- **WHEN** a cone covers them for 5 s and they then step onto sand still inside it
- **THEN** their spot meter stayed at 0 on the scrub and starts filling on the sand

#### Scenario: Diving under the light
- **GIVEN** a solo swimmer inside a cone at night with 1 s on their spot meter
- **WHEN** they dive and stay under for 4 s
- **THEN** their meter did not fill while they were under, and fills again once they surface inside the cone

#### Scenario: Fog hides everyone
- **GIVEN** night in weather that disables sight and a solo player standing on open beach
- **WHEN** a boat laps the island
- **THEN** no light is drawn and the player is never spotted

#### Scenario: Stealth adds time
- **GIVEN** a player with Stealth level 2, standing in a lit cone at night
- **WHEN** they stay lit
- **THEN** they are not spotted at 3.5 s and are spotted at 4 s; at Stealth level 5 they would be spotted at 5 s

### Requirement: Triggers
A patrol boat in sight SHALL also be alerted by smoke: a lit fire within 2 tiles of the sea at night that is not on a roofed cell, or any lit fire within 6 tiles of the sea by day (dawn and dusk count as night), once per fire per lap. It SHALL be alerted by noise of radius 8 tiles or more whose source is within that radius of the boat. A swimmer who is not diving and is within 6 tiles of the boat is spotted at once. The sea is deep or shallow water joined to the map edge.

#### Scenario: Fire in the hut
- **GIVEN** a fire inside the ruined hut at night
- **WHEN** the patrol passes
- **THEN** no smoke alert is raised and the party is not spotted

#### Scenario: A beach fire at night
- **GIVEN** a solo player's lit fire 1 tile from the sea at night
- **WHEN** a boat comes into sight
- **THEN** the boat raises one smoke alert at the fire, and no second one for that fire during that lap

#### Scenario: Put out in time
- **GIVEN** a solo player's lit fire 1 tile from the sea at night
- **WHEN** they put it out while the boat is on the horizon
- **THEN** no smoke alert is raised during the lap that follows

#### Scenario: An inland fire at night
- **GIVEN** a lit fire 4 tiles from the sea at night, on open ground
- **WHEN** a boat laps the island
- **THEN** no smoke alert is raised

#### Scenario: A day fire
- **GIVEN** a lit fire 5 tiles from the sea by day
- **WHEN** a boat comes into sight
- **THEN** the boat raises a smoke alert at the fire

#### Scenario: A loud noise near the boat
- **GIVEN** a boat in sight
- **WHEN** a noise of radius 15 tiles is made 12 tiles from it
- **THEN** the boat raises a noise alert at the noise's source

#### Scenario: Noises the boat does not hear
- **GIVEN** a boat in sight
- **WHEN** a noise of radius 15 tiles is made 20 tiles from it, and a noise of radius 6 tiles 3 tiles from it
- **THEN** neither raises an alert

#### Scenario: A swimmer near the boat
- **GIVEN** a solo player swimming 5 tiles from a boat in sight, by day
- **WHEN** the boat checks the water
- **THEN** the player is spotted at once

#### Scenario: A diver near the boat
- **GIVEN** a solo player diving 3 tiles from a boat in sight
- **WHEN** the boat checks the water during the dive
- **THEN** the player is not spotted

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
When a capture sends the party back, the previous island SHALL be regenerated from the run seed and set up again for the living, connected players at that moment (Resource spawns, Escape routes), and the party SHALL restart on its landing beach. On island 1, which has no previous island, the party SHALL restart island 1, regenerated from the run seed the same way, with the same inventory rule (minus fire sources, keepsakes kept). The secret cay (secret-cay) is never the previous island: a party captured on the island it reached after the cay restarts the island it left for the cay. A regenerated island never places a secret piece the run has already spawned (the run's ledger of spawned pieces), so a capture never makes a second map or compass; the later work that places pieces in real runs tests this. The same holds with 1 player. (Changes docs/GAME_DESIGN.md §9 "Guardacostas and stealth" for the cay and the pieces.)

#### Scenario: Previous island is fresh
- GIVEN a 1-player run whose player used all the driftwood on island 2 for a raft and was then captured on island 3 with persuasion failing
- WHEN the player restarts island 2
- THEN island 2 has the terrain, POIs and resources it had on first arrival, from the same run seed

#### Scenario: Caught on the sandbar
- GIVEN a 1-player run on island 1 whose player carries a knife, 3 rope, a lighter and the Foto de la familia keepsake, with morale 40
- WHEN a shore squad captures the player and persuasion fails
- THEN island 1 is regenerated from the run seed and the player lands on its beach with the knife, the 3 rope and the Foto, without the lighter

#### Scenario: Caught after the detour
- GIVEN a 1-player run that left island 4 for the secret cay, went on to island 5 and was captured there with persuasion failing
- WHEN the player restarts
- THEN they restart island 4, regenerated from the run seed, not the cay

#### Scenario: A taken piece is not placed again
- **GIVEN** a 1-player run that took the map on island 3 and was captured on island 4 with persuasion failing
- **WHEN** the player restarts island 3, regenerated from the run seed
- **THEN** island 3 holds no map, and the player still carries the one they took

### Requirement: Capture on the final crossing
If every living player is captured during the final crossing, the run SHALL end with the `devuelto` ending (endings-progression) instead of Capture outcome: no persuasion check is rolled and no island is restarted.

#### Scenario: Solo player caught in the Straits
- GIVEN a 1-player run on the final crossing with morale 70 and a Maestro as the only player
- WHEN the final patrol captures the player
- THEN no persuasion check is rolled, the run ends and the `devuelto` ending plays

### Requirement: Spot meter
The host SHALL keep a spot meter in seconds for each living player in the run. It fills 1 s per second while the player is inside any lit cone and not hidden, and drains 0.5 s per second otherwise, never below 0. When it reaches the player's spot time (2 s plus their Stealth bonus), the player is spotted by the boat whose cone lit them and the meter goes back to 0. Dead and dropped players have no meter.

#### Scenario: Out of the light in time
- **GIVEN** a solo player lit and not hidden at night
- **WHEN** they leave the cone after 1.5 s
- **THEN** they are not spotted, their meter reads 1.5 s and drains to 0 over the next 3 s

#### Scenario: Two sweeps catch a still player
- **GIVEN** a solo player standing still on open sand at night, lit for 1.5 s and then out of the cone for 1 s
- **WHEN** the cone comes back over them
- **THEN** they are spotted 1 s later, their meter having held 1 s when the cone returned

#### Scenario: The meter follows its player
- **GIVEN** a host and a client, each with a player standing on open sand at night
- **WHEN** only the client's player is lit for 1 s
- **THEN** the client's player's meter reads 1 s and the host's player's meter reads 0

### Requirement: Patrol count
Each island SHALL get its patrol boats when it is set up: one on the sandbar, one on a coast-chain island plus a 50% chance of a second, and one more per 2 living, connected players, rounded down. The boats on one island share its loop, their loops offset evenly in time. An off-graph island (the secret cay) gets none. One player gets the base count.

#### Scenario: Solo on the sandbar
- **GIVEN** a solo run
- **WHEN** the sandbar is set up
- **THEN** it has exactly one patrol boat

#### Scenario: Four players on the coast cay
- **GIVEN** four living, connected players and a coast cay whose roll gave a second boat
- **WHEN** the coast cay is set up
- **THEN** it has four boats on one loop, each starting its horizon warning 45 s after the one before

#### Scenario: No patrol on the secret cay
- **GIVEN** a solo party arriving at the secret cay
- **WHEN** the cay is set up
- **THEN** it has no patrol boat and nothing is drawn on the horizon

### Requirement: Alert
When a boat spots a player or raises a smoke or noise alert, it SHALL stop and run an alert: its loudhailer calls out, and at night its light aims at the cause. A spotted player stays locked while visible and within 10 tiles of the boat. Once no player is locked, the light sweeps 30° either side of the last known position, and the alert ends 20 s later unless a new spot restarts it. The boat then resumes its lap where it stopped.

#### Scenario: Solo player spotted, hides and gets away
- **GIVEN** a solo player spotted on open sand at night, 3 tiles from scrub
- **WHEN** they crouch on the scrub
- **THEN** the lock breaks, the light sweeps round where they were last seen, they are not spotted again, and 20 s later the boat resumes its lap

#### Scenario: Out of range
- **GIVEN** a locked player at night
- **WHEN** they get more than 10 tiles from the boat
- **THEN** the lock breaks and the 20 s search begins

#### Scenario: Spotted again during the search
- **GIVEN** a boat sweeping a last known position 12 s into its search
- **WHEN** a player who is not hidden fills their spot meter in its light
- **THEN** that player is locked and the 20 s starts again once the lock breaks

#### Scenario: The lap waits for the alert
- **GIVEN** a boat that stops 30 s into its lap for an alert lasting 25 s
- **WHEN** the alert ends
- **THEN** the boat goes on from the same place, ends its lap 70 s later, and that loop lasted 205 s

#### Scenario: A smoke alert by day
- **GIVEN** a day fire within 6 tiles of the sea and a boat coming into sight
- **WHEN** the boat raises the smoke alert
- **THEN** it stops for 20 s with no light, its loudhailer calls out, and it resumes its lap

#### Scenario: The alert is reported
- **GIVEN** a boat in sight
- **WHEN** it spots a player, or raises a smoke or noise alert
- **THEN** the alert is reported once with its cause (sight, water, smoke or noise) and the position it aims at

### Requirement: Patrols on every peer
The host SHALL run every patrol boat, spot meter and trigger; a client never decides a spot or a hidden state. Every peer SHALL draw each boat in sight and its cone from the host's loop clock and beam aim, so a client's cone matches the host's to within one sync interval. A client that joins mid-lap SHALL get every boat's clock and aim with the island. One offline player is the host.

#### Scenario: The client's cone matches the host's
- **GIVEN** a host and a client at night with a boat in sight
- **WHEN** the client draws the boat for 5 s
- **THEN** at every sync the client's boat position and beam centre match the host's within one sync interval's movement

#### Scenario: Joining mid-lap
- **GIVEN** a host whose boat is 40 s into its lap at night
- **WHEN** a client joins
- **THEN** the client's first drawn frame shows the boat at the host's place on the loop with its cone at the host's aim

#### Scenario: A client cannot hide by claiming it
- **GIVEN** a client whose player stands on open sand at night inside a lit cone
- **WHEN** the client sends crouch intents while standing on sand
- **THEN** the host still fills that player's meter and spots them at 2 s

### Requirement: Patrol cues
Every peer SHALL show three cues. During each boat's 20 s horizon warning, the HUD horizon band shows a light at night or a grey hull by day. While a player's spot meter is above 0, an open-eye mark shows over them, drawn by the HUD like the hidden mark and filling with the meter. When an alert starts and ends, the loudhailer's line shows over the boat, in formal Spanish when the language is Spanish.

#### Scenario: A solo player sees the warning
- **GIVEN** a solo player on the sandbar at night
- **WHEN** the boat starts its horizon warning
- **THEN** a light shows on the HUD horizon band for 20 s and goes when the lap starts

#### Scenario: The eye opens while lit
- **GIVEN** a host and a client at night
- **WHEN** the client's player has been lit for 1 s
- **THEN** both peers show the open-eye mark over that player half filled, and neither shows it once the meter is back at 0

#### Scenario: The loudhailer speaks
- **GIVEN** a solo player whose language is Spanish
- **WHEN** a boat starts an alert
- **THEN** one of the boat's Spanish alert lines shows over the boat

### Requirement: Patrol data
Each patrol kind's numbers and lines SHALL be data in its creature file: the loop's period, horizon warning, lap, hull offset and boat counts; the cone's width, length, sweep speed and arc; the spot time, fill and drain; the trigger distances; the alert's length and search sweep; and the loudhailer lines in Spanish and English. A new patrol kind with the existing behavior needs no script edit.

#### Scenario: Retuned by data
- **GIVEN** a copy of the patrol boat's file with a 45° cone and a 90 s lap
- **WHEN** a solo island is set up with it
- **THEN** its boat sweeps a 45° cone and laps the island in 90 s, with no script changed

#### Scenario: The patrol boat passes the content check
- **GIVEN** the game's content
- **WHEN** the content check runs
- **THEN** the patrol boat's file loads with its patrol part and no problems

### Requirement: Launch in view
A route marked as seen at launch (the raft) SHALL be seen when it starts while one of the island's patrol boats is out and sight works. In a phase when that boat's searchlight is off (dawn, day, dusk) it always sees it: by day the guard sees the whole sea. In a searchlight phase (night) it sees it only while its light covers the starter. A squall (patrols in port), a weather that blinds sight, or an island with no patrol hides it. Solo the same. (Adds to docs/GAME_DESIGN.md §9.)

#### Scenario: Solo by day
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather, its one patrol boat away beyond the horizon
- **WHEN** the player asks to launch the built raft
- **THEN** the launch is seen

#### Scenario: Solo at night, out of the light
- **GIVEN** a 1-player run, offline, on the sandbar at 22:00 in calm weather, its patrol boat on its lap with the searchlight not on the player
- **WHEN** the player asks to launch the built raft
- **THEN** the launch is not seen and the raft route starts

#### Scenario: Solo at night, in the light
- **GIVEN** the same run at 22:00 with the searchlight's cone on the player at the raft
- **WHEN** the player asks to launch
- **THEN** the launch is seen

#### Scenario: Solo in a squall
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 during a squall, its patrol boat in port
- **WHEN** the player asks to launch the built raft
- **THEN** the launch is not seen and the raft route starts into the squall

#### Scenario: A swim is not a launch
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather, a player at energy 100 carrying binoculars
- **WHEN** they start binoculars-and-swim
- **THEN** the route starts, since a swim is not marked as seen at launch and the water rule still applies to the swimmer

### Requirement: A seen launch is a spot
A launch that is seen SHALL NOT start: nothing is spent, the vessel stays on the beach and no rider leaves. The boat that saw it raises an alert on land on the starter, cause `launch`, as for any spot of a player on land: it lands its squad when it has one and none is ashore, otherwise it locks on or searches. When several boats see it, the first by member index raises it. With exactly 1 player, the shore squad hunts that player, and a capture follows "Capture outcome".

#### Scenario: Solo spotted at launch
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather with a built raft at 100 and no squad ashore
- **WHEN** the player asks to launch
- **THEN** the raft stays at 100 on the beach, the player stays on the island, and the patrol boat docks and lands its squad, whose search starts at the player's cell

#### Scenario: Co-op party spotted
- **GIVEN** a 2-player run on the sandbar by day with a built raft and both players beside it
- **WHEN** the client asks to launch
- **THEN** neither player leaves, the alert names the client's player, and both peers see the boat dock
