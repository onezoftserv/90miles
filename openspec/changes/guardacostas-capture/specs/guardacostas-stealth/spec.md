## MODIFIED Requirements

### Requirement: Alert
When a boat spots a player or raises a smoke or noise alert, it SHALL stop and run an alert: its loudhailer calls out, and at night its light aims at the cause. A spotted swimmer is chased (Boat chase at sea). An alert whose cause is on land lands the squad when none is ashore, and lasts until the squad is back aboard. Otherwise a spotted player stays locked while visible within 10 tiles, then the light sweeps 30° round the last known position and the alert ends 20 s later unless a new spot restarts it. The boat then resumes its lap where it stopped. One player meets the same alert.

#### Scenario: Solo player spotted, hides and gets away
- **GIVEN** a solo player spotted on the sandbar at night, 3 tiles from a scrub patch
- **WHEN** they crouch on the scrub and crouch-walk through it until they are more than 2 tiles from where they hid
- **THEN** the lock breaks where they hid, the light sweeps round that place, the squad lands and searches it without finding them, and once the squad is back aboard the boat resumes its lap

#### Scenario: Out of range
- **GIVEN** a locked player at night
- **WHEN** they get more than 10 tiles from the boat
- **THEN** the lock breaks and the light sweeps round the last known position

#### Scenario: Spotted again during the search
- **GIVEN** a boat sweeping a last known position 12 s into its search, with no squad of its own ashore
- **WHEN** a player who is not hidden fills their spot meter in its light
- **THEN** that player is locked and the 20 s starts again once the lock breaks

#### Scenario: The lap waits for the alert
- **GIVEN** a boat that stops 30 s into its lap for an alert lasting 25 s
- **WHEN** the alert ends
- **THEN** the boat goes on from the same place, ends its lap 70 s later, and that loop lasted 205 s

#### Scenario: A smoke alert by day
- **GIVEN** a day fire within 6 tiles of the sea and a boat coming into sight
- **WHEN** the boat raises the smoke alert
- **THEN** it stops with no light, its loudhailer calls out, it lands the squad, and it resumes its lap once the squad is back aboard

#### Scenario: The alert is reported
- **GIVEN** a boat in sight
- **WHEN** it spots a player, or raises a smoke or noise alert
- **THEN** the alert is reported once with its cause (sight, water, smoke or noise) and the position it aims at

#### Scenario: A second boat while the squad is ashore
- **GIVEN** a coast cay with two boats, a squad from the first ashore, and the second boat in sight at night
- **WHEN** the second boat spots a player on the beach
- **THEN** it runs the plain alert and lands no squad, and the squad's last known position moves to where that player was spotted

### Requirement: Chase and shore squad
When a boat in sight spots a swimmer it SHALL chase them (Boat chase at sea). When it raises an alert whose cause is on land (a player spotted on land, smoke or noise) and no squad is ashore on the island, it SHALL land a 3-soldier squad by dinghy on the nearest beach, which searches for 180 s: every lit fire first, then the last known position, then a random walk. Soldiers capture on a 2 s touch within 1 tile and walk captives to the dinghy. One player meets the same three. (Changes docs/BESTIARY.md "Shore squad".)

#### Scenario: Squad lands
- **GIVEN** the party is spotted while on land
- **WHEN** the boat responds
- **THEN** it lands a 3-soldier squad that searches for 180 s: the fire first, then the last known position, then a random walk

#### Scenario: A solo player on the beach at night
- **GIVEN** a solo player on the sandbar at night, standing on open sand inside a boat's cone
- **WHEN** their spot meter reaches 2 s
- **THEN** the boat stops, its dinghy rows to the beach nearest the boat at 2 tiles/s, and three soldiers step ashore there and start searching

#### Scenario: A day fire brings the squad
- **GIVEN** a solo player's lit fire 5 tiles from the sea by day, with no player spotted
- **WHEN** a boat comes into sight and raises the smoke alert
- **THEN** a squad lands, and the fire is the first point it searches

#### Scenario: One squad at a time
- **GIVEN** a squad ashore on the coast cay
- **WHEN** another alert is raised on land
- **THEN** no second squad lands

### Requirement: Free a captive
A free player who holds interact for 1 s on a captive while no soldier is within 3 tiles of the captive SHALL free them, on the walk or in the squad's dinghy on the landing beach (sneaking aboard). A soldier coming within 3 tiles during the hold cancels it. A swimmer hauled aboard the boat cannot be freed. When no other living player is free (always so in a 1-player run), nobody is left to free the captive: the capture is a whole-party capture and follows Capture outcome at once.

#### Scenario: Unguarded captive
- **GIVEN** a captive with the nearest soldier 4 tiles away
- **WHEN** a teammate holds interact on the captive for 1 s
- **THEN** the captive is freed

#### Scenario: Solo player is never held on the dock
- **GIVEN** a 1-player run whose player is caught by a soldier's 2 s touch
- **WHEN** the capture completes
- **THEN** the player is not held in the dinghy or aboard; `la_captura` plays at once

#### Scenario: Sneaking aboard the dinghy
- **GIVEN** a host and a client, the client's player sitting captive in the dinghy and every soldier more than 3 tiles away
- **WHEN** the host's player holds interact on the captive for 1 s
- **THEN** the captive is freed and stands on the landing beach, on both peers

#### Scenario: The guard comes back
- **GIVEN** a teammate 0.5 s into freeing a captive
- **WHEN** a soldier comes within 3 tiles of the captive
- **THEN** the hold is cancelled and the captive stays a captive

### Requirement: Capture outcome
On a whole-party capture on an island (solo: the only player), `la_captura` SHALL play with Rodríguez. If the persuasion check passes, the party is released at the next island. Otherwise the party restarts the previous island, each player keeping their items except fire sources (items that can light a fire); keepsakes are always kept. A whole-party capture during the final crossing follows Capture on the final crossing instead. A captive taken while a player is still free follows Taken captives. (Changes docs/GAME_DESIGN.md §9.)

#### Scenario: Persuasion succeeds
- **GIVEN** every player is captured, and a captured Médico has morale 65
- **WHEN** the `la_captura` scene plays with Rodríguez
- **THEN** the party is released at the next island

#### Scenario: Solo Médico talks their way out
- **GIVEN** a 1-player run on the sandbar whose only player is a Médico with morale 65
- **WHEN** a soldier captures the player
- **THEN** `la_captura` plays, the check passes and the player is released on the coast cay

#### Scenario: Solo capture fails
- **GIVEN** a 1-player run on island 3 whose only player is a Pescador with morale 40, carrying a knife, 3 rope, a lighter and the Foto de la familia keepsake
- **WHEN** a soldier captures the player
- **THEN** `la_captura` plays, the check fails (morale 40 < 60, no Maestro or Médico), and the player restarts island 2 holding the knife, the 3 rope and the Foto, without the lighter

#### Scenario: A final-crossing capture skips the scene
- **GIVEN** a 1-player run whose only player is captured during the final crossing
- **WHEN** the capture is resolved
- **THEN** `la_captura` does not play and no persuasion check is rolled

### Requirement: Fade with distance
A mid-chain island (the mangrove, reef, rocky key and lighthouse families) SHALL get its patrol boats with a 30% chance, rolled once per island from the run seed, and then as many as a coast-chain island gets. A far-chain island (storm key, shipwreck reef) SHALL get none. The final crossing has exactly one patrol, which comes with the final crossing. Chain-specific limits (the mangrove's spit, the lighthouse's dawn pass) come with those chains. One player gets the base count. (Changes docs/ISLANDS.md "Chains and distance": "fewer patrols" is a 30% chance.)

#### Scenario: Far chain
- **GIVEN** a far-chain island
- **WHEN** it is generated
- **THEN** it has no patrols

#### Scenario: Mid chains have fewer patrols
- **GIVEN** a mid-chain island set up for 1 player
- **WHEN** it is set up under 1,000 different run seeds
- **THEN** between 26% and 34% of them have patrol boats, and each of those has one or two

#### Scenario: The same island keeps its patrol
- **GIVEN** a 1-player run whose mid-chain island rolled a patrol
- **WHEN** that island is set up again from the same run seed
- **THEN** it has the same number of boats

## ADDED Requirements

### Requirement: Boat chase at sea
A boat in sight that spots a swimmer SHALL leave its lap and chase them at twice the base swim speed (6 tiles/s) through deep water only. After 2 s within 1 tile it hauls them aboard, which captures them. The chase breaks when the swimmer dives, reaches shallows or land, or gets 10 tiles away; the alert then searches as usual, and a swimmer who reached land brings the squad. With 1 player a haul is a whole-party capture.

#### Scenario: Solo swimmer hauled aboard
- **GIVEN** a solo player swimming in deep water 6 tiles from a boat in sight, by day
- **WHEN** they keep swimming in the open sea
- **THEN** the boat closes in at 6 tiles/s, hauls them aboard after 2 s within 1 tile, and `la_captura` plays at once

#### Scenario: Into the shallows
- **GIVEN** a swimmer chased by a boat, 2 tiles from the shallows
- **WHEN** they reach shallow water
- **THEN** the boat stops at the edge of the deep water, the chase breaks and nobody is hauled aboard

#### Scenario: Under the boat
- **GIVEN** a solo swimmer chased by a boat at night
- **WHEN** they dive
- **THEN** the chase breaks, and the light sweeps round where they dived

#### Scenario: Ashore with the boat behind
- **GIVEN** a swimmer chased by a boat
- **WHEN** they reach land before being hauled aboard
- **THEN** the boat lands its squad, with the place they came ashore as the last known position

### Requirement: Soldier sight
Each soldier SHALL see in a cone ahead of it: 6 tiles and 120° by day, and a 5-tile, 60° flashlight at night. A player inside a soldier's cone who is not hidden fills their spot meter as a searchlight does. A spotted player is chased at 5 tiles/s while they stay visible within the cone's length. Hidden players are never seen, and in weather that disables sight no soldier sees anyone. One player is seen by the same rules.

#### Scenario: Seen on open sand
- **GIVEN** a solo player standing on open sand by day, 4 tiles in front of a soldier
- **WHEN** 2 s pass
- **THEN** the player is spotted and the soldier runs at them

#### Scenario: Crouching in scrub
- **GIVEN** a solo player crouching on scrub 3 tiles in front of a soldier by day
- **WHEN** the soldier walks past
- **THEN** the player's spot meter stays at 0

#### Scenario: Outrunning a soldier
- **GIVEN** a solo player spotted by a soldier 3 tiles behind them by day
- **WHEN** they run straight away at 6 tiles/s
- **THEN** the soldier falls behind at 5 tiles/s, the chase breaks once the player is more than 6 tiles away, and the soldier searches where it last saw them

#### Scenario: A flashlight at night
- **GIVEN** a solo player standing on open sand at night, 6 tiles in front of a soldier
- **WHEN** 3 s pass
- **THEN** the player's spot meter stays at 0

### Requirement: Squad search
The squad SHALL search points in order: every lit fire on the island, nearest the landing first, then the last known position, then a random walk between land cells drawn from the run seed. Each soldier takes the next point nobody has taken. On arrival it searches the point for 3 s, which finds any hidden player within 2 tiles of it. With 1 player the search is the same.

#### Scenario: Hiding by your own fire
- **GIVEN** a solo player crouching on scrub 1 tile from their lit fire when a squad lands
- **WHEN** a soldier reaches the fire and searches it
- **THEN** the player is found within the 3 s and the soldier runs at them

#### Scenario: Hiding away from the search
- **GIVEN** a solo player spotted on open sand at night, who runs inland until the light loses them and then crouches on scrub more than 2 tiles from that place and from any lit fire
- **WHEN** the squad searches its points and walks the island for its 180 s
- **THEN** no soldier finds them

#### Scenario: Hiding where you were seen
- **GIVEN** a solo player spotted by a soldier by day, who crouches on a lone scrub cell while still inside its cone
- **WHEN** the soldier reaches that cell and searches it
- **THEN** the player is found within the 3 s

### Requirement: Last known position
The last known position SHALL be where a spotted player was last seen by a boat's lock or a soldier's chase: the cell where they hid, or where they left the lock's 10 tiles or the soldier's sight length. A newer one replaces it, and the nearest soldier that is not escorting or chasing goes to search it. With 1 player it works the same.

#### Scenario: Lost where they hid
- **GIVEN** a solo player locked by a boat's light at night, standing on sand beside scrub
- **WHEN** they crouch on the scrub
- **THEN** the last known position is that scrub cell

#### Scenario: Lost at the edge of the light
- **GIVEN** a solo player locked by a docked boat's light at night
- **WHEN** they walk inland until they are more than 10 tiles from the boat
- **THEN** the last known position is where they crossed the 10 tiles, and a soldier goes to search it

#### Scenario: The same search from the same seed
- **GIVEN** two solo runs with the same run seed, each with a squad landing at the same moment and place
- **WHEN** both squads finish their points and walk the island
- **THEN** both pick the same random-walk cells in the same order

### Requirement: The squad leaves
The squad SHALL leave when its 180 s search ends, but never sooner than 60 s after its latest capture. It leaves at once when no free player is left on the island, or when a squall comes. Leaving soldiers walk back to the dinghy, call their give-up line and row out with their captives, and the boat resumes its lap. With 1 player, a squad that caught nobody leaves after 180 s. (Changes docs/BESTIARY.md "Shore squad".)

#### Scenario: A solo player outlasts the squad
- **GIVEN** a solo player hidden away from every search point when a squad lands
- **WHEN** 180 s pass
- **THEN** the soldiers walk back to the dinghy and row out, and the boat resumes its lap

#### Scenario: A late capture holds the squad
- **GIVEN** a host and a client, and a squad that captures the client's player 170 s into its search
- **WHEN** the search time runs out
- **THEN** the squad stays until 60 s after that capture, then leaves

#### Scenario: A squall recalls the squad
- **GIVEN** a squad ashore 40 s into its search
- **WHEN** a squall starts
- **THEN** the soldiers walk back and row out with any captives, and the boat leaves sight

### Requirement: Captives
A captured player SHALL be a captive: they cannot move, use, craft or pick up, but keep quick chat, and their meters run as usual. Their soldier leads them at walking pace to the dinghy, then returns to the search; a soldier leading a captive does not search. The captive sits in the dinghy until freed or taken. A soldier never captures a downed or dropped body, and the touch count resets when contact breaks. With 1 player the first capture is a whole-party capture.

#### Scenario: Led to the dinghy
- **GIVEN** a host and a client, and a soldier that captures the client's player 12 tiles from the landing
- **WHEN** the soldier leads them away
- **THEN** both peers show the captive following the soldier to the dinghy, where they sit, and the soldier walks back to its search

#### Scenario: A captive cannot act
- **GIVEN** a client whose player is a captive
- **WHEN** the client sends move, use and pick-up intents
- **THEN** the host ignores them, and the client's quick chat still reaches every peer

#### Scenario: Breaking contact
- **GIVEN** a solo player whom a soldier has touched for 1.5 s
- **WHEN** the player runs out of reach and the soldier touches them again 3 s later
- **THEN** the player is captured only after a fresh 2 s of touch

### Requirement: Whole-party capture
A player SHALL count as free while living, connected, standing (not downed and not in a last stand) and not a captive, wherever they are, a rider in a crossing or waiting on the next shore included. When no free player is left and at least one player is a captive or taken, it is a whole-party capture, checked before Split parties loads an island: Capture outcome follows at once, and the downed and dropped bodies on the island go along. With 1 player, the first capture is one.

#### Scenario: A downed teammate goes along
- **GIVEN** a host and a client, the client's player downed with 40 s left
- **WHEN** a soldier captures the host's player
- **THEN** `la_captura` plays at once with both players, and after it the client's player stands at 30 health

#### Scenario: A rider waits on the next shore
- **GIVEN** a 2-player run whose first player has crossed and waits on the coast cay's shore
- **WHEN** a soldier captures the second player on the sandbar
- **THEN** it is not a whole-party capture, and the squad leaves at once with the captive

#### Scenario: The last free player dies
- **GIVEN** a 2-player run with one player sitting captive in the dinghy
- **WHEN** the only free player dies
- **THEN** it is a whole-party capture and `la_captura` plays with the captive

#### Scenario: The last free player dies after the squad has left
- **GIVEN** a 2-player run whose second player was taken, and whose first player is alone on the sandbar
- **WHEN** the first player dies
- **THEN** no island loads; it is a whole-party capture and `la_captura` plays with the taken player

### Requirement: Taken captives
When the squad leaves with captives while a free player is left, each captive SHALL be taken: out of play like a rider waiting on the next shore (hidden, unhurt, meters frozen), with every item gone except keepsakes, and with their secret items laid on the landing beach. A taken captive has left the island for Split parties. They land with the party on the next island loaded and join a later whole-party capture. Solo never gets here. (Changes docs/BESTIARY.md "Shore squad".)

#### Scenario: Taken, and back on the next island
- **GIVEN** a host and a client, the client's player taken with a knife, 2 rope and the Foto de la familia keepsake
- **WHEN** the host's player later crosses to the coast cay
- **THEN** both players land on the coast cay, and the client's player holds only the Foto

#### Scenario: The compass stays behind
- **GIVEN** a host and a client, the client's player sitting captive with the broken compass
- **WHEN** the squad leaves and takes them
- **THEN** the compass lies on the landing beach on the host, and every peer sees it there

#### Scenario: The island empties
- **GIVEN** a 2-player run whose first player waits on the coast cay's shore, and whose second player is taken on the sandbar
- **WHEN** the squad has left
- **THEN** the coast cay loads, and both players land on it

### Requirement: The capture scene
Every whole-party capture on an island SHALL play `la_captura` on every peer. Rodríguez reads the interception act in formal Spanish and speaks Baracoa Spanish in person. Lines address one captured player in the singular and two or more in the plural, and a party captured before in the run hears the second-capture opening. The host paces the lines, and every player is out of play while the scene plays. One player plays it alone.

#### Scenario: Alone with the captain
- **GIVEN** a solo player whose language is Spanish
- **WHEN** they are captured for the first time in the run
- **THEN** the scene's lines address them in the singular, the act is read in formal Spanish, and the scene ends with the outcome's lines

#### Scenario: Caught again
- **GIVEN** a solo run whose player was captured once and restarted
- **WHEN** they are captured again
- **THEN** the scene opens with the second-capture line

#### Scenario: Every peer reads the same line
- **GIVEN** a host and a client in a whole-party capture
- **WHEN** the scene plays
- **THEN** both peers show the same line at the same time, and neither player can move

#### Scenario: Joining during the scene
- **GIVEN** a host in a whole-party capture, its scene on its third line
- **WHEN** a client joins
- **THEN** the client sees the scene from its current line, stays out of play, and lands with the party

### Requirement: Persuasion check
The host SHALL decide `la_captura` by one check: it passes when a captured, standing player has the Maestro or Médico background and morale 60 or more, and then that player's plea is shown. A player with no background never passes. A party that used the almendrón and fails gets the car variant (escape-routes "Almendrón capture"). With 1 player, only that player is checked.

#### Scenario: No background, no way out
- **GIVEN** a solo player with no background and morale 90
- **WHEN** they are captured
- **THEN** the check fails and they restart the previous island

#### Scenario: One good speaker is enough
- **GIVEN** a host and a client both captured: a Maestro with morale 50 and a Médico with morale 70
- **WHEN** the check is made
- **THEN** it passes, and the Médico's plea is shown

#### Scenario: The car went down
- **GIVEN** a solo run that crossed in the almendrón, whose player is captured with the check failing
- **WHEN** the scene plays
- **THEN** the car variant's lines play and `almendron_hundido` is set

### Requirement: Release at the next island
When the check passes, the party SHALL land on the next island its current island's layout names, on the landing cells within 5 tiles of each other, keeping every item and meter, with no vessel beached. Downed players taken along stand at 30 health. That island counts as reached. When the current island names no next island, the run ends as leaving that island does. With 1 player, they land alone on the first landing cell.

#### Scenario: A solo player released from the sandbar
- **GIVEN** a solo Médico with morale 65 captured on the sandbar, holding a lighter and 3 rope
- **WHEN** the check passes
- **THEN** they stand on the coast cay's first landing cell holding the lighter and the 3 rope, and the raft build site is empty

#### Scenario: Released from the last island
- **GIVEN** a solo Médico with morale 65 captured on the coast cay, which names no next island
- **WHEN** the check passes
- **THEN** the run ends and the run summary shows

### Requirement: Island history
The host SHALL keep the run's island history: each island the party has stood on, in order, with its index. The previous island is the last on-graph island before the current one: on island 1 it is island 1, and the secret cay is never it. Islands reached is the highest index reached, so a restart or a second arrival never counts an island twice (Experiencia points included). Every peer counts the same islands reached. The same holds with 1 player.

#### Scenario: Counted once
- **GIVEN** a 1-player run captured on island 3, restarted on island 2, and arriving on island 3 again
- **WHEN** the islands reached are counted
- **THEN** they are 3

#### Scenario: Both peers count the same
- **GIVEN** a host and a client whose whole party was captured on the coast cay and restarted the sandbar
- **WHEN** the run ends there
- **THEN** both peers' run summaries show 2 islands reached

### Requirement: Capture on every peer
The host SHALL decide every chase, touch, capture, rescue, check and outcome, and a client never captures or frees by claiming it. Every peer SHALL see the soldiers, the dinghy, each captive and the scene's current line, a client that joins while the squad is ashore included. One offline player is the host, and nothing goes over a network.

#### Scenario: A client frees a captive
- **GIVEN** a host and a client, the host's player captive in the dinghy with every soldier more than 3 tiles away
- **WHEN** the client's player holds interact on them for 1 s
- **THEN** the host frees them, and both peers show them standing

#### Scenario: A client cannot free from afar
- **GIVEN** a host and a client, the host's player captive and the client's player 6 tiles away
- **WHEN** the client holds interact toward the captive
- **THEN** the host frees nobody and the captive stays a captive

#### Scenario: Joining while the squad is ashore
- **GIVEN** a host whose island has a squad ashore with one captive in the dinghy
- **WHEN** a client joins
- **THEN** the client sees the three soldiers where the host has them, the dinghy on the beach and the captive in it

### Requirement: Capture cues
Every peer SHALL show a rope mark over each captive, and the open-eye mark while a soldier's sight fills a meter. A free player in reach of a captive SHALL see an "[E] Soltar" prompt with a 1 s ring, shown only while no soldier is within 3 tiles of the captive. Every peer SHALL show the squad's calls in speech bubbles when it lands, spots a player and leaves, in formal Spanish when the language is Spanish. A solo player sees every cue but the prompt.

#### Scenario: The rope mark
- **GIVEN** a host and a client, the client's player captive
- **WHEN** both peers draw the island
- **THEN** both show the rope mark over that player, and neither shows it once they are freed

#### Scenario: No prompt while a guard is near
- **GIVEN** a free player 1 tile from a captive, with a soldier 2 tiles from the captive
- **WHEN** the soldier walks 4 tiles away
- **THEN** the "[E] Soltar" prompt appears only then

#### Scenario: A solo player hears the landing
- **GIVEN** a solo player whose language is Spanish
- **WHEN** a squad lands
- **THEN** one of the squad's Spanish landing calls shows over a soldier

### Requirement: Shore squad data
Each patrol kind's response SHALL be data: chase factor and haul; the squad's size, landing speed, search length, point search, grace and soldier creature; the soldiers' sight by day and night and chase speed; the capture touch; the free hold and radius; the persuasion morale and backgrounds; the scene; and the squad's calls in Spanish and English. A new patrol kind with these behaviors needs no script edit.

#### Scenario: Retuned by data
- **GIVEN** a copy of the patrol boat's file with a 2-soldier squad and a 120 s search
- **WHEN** a solo island is set up with it and a squad lands
- **THEN** two soldiers search for 120 s, with no script changed

#### Scenario: The capture content passes the content check
- **GIVEN** the game's content
- **WHEN** the content check runs
- **THEN** the shore soldier, Rodríguez and `beat_la_captura` load with no problems, and the patrol boat's squad, scene and commander references resolve
