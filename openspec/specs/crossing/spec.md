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
On arrival, players SHALL spawn on the next island's beach scattered within 5 tiles, the vessel beached with its remaining integrity (reusable if intact). The next island is the one the departure island's layout names (the sandbar names the coast cay). Each rider keeps the health and energy the crossing result gives them. A raft that ends the crossing intact (not broken, integrity above 0) SHALL be beached at the next island's raft build site with that integrity and can be launched again from there (with more than one intact raft, the sturdiest is beached); a broken raft is lost and the site is empty. The host decides the arrival and every peer shows it. An island that names no next island ends its riders' part of the run as the run summary counts them. With exactly 1 player, the player arrives alone on the next island's first landing cell.

#### Scenario: Raft arrives damaged
- GIVEN a raft that ends the crossing with integrity 40
- WHEN the party arrives
- THEN the players spawn on the next island's beach within 5 tiles of each other and the raft is beached there with integrity 40

#### Scenario: A solo player lands on the coast cay
- GIVEN a 1-player run whose raft crossing from the sandbar ends with integrity 70 and the rider at health 80
- WHEN the crossing ends
- THEN the island is the coast cay, the player stands on its first landing cell with the health and energy the crossing left, the run has not ended, and a raft with integrity 70 stands at the raft build site and can be launched

#### Scenario: A broken raft is lost
- GIVEN a 1-player raft crossing that ends with the raft broken and the player swimming
- WHEN the crossing ends
- THEN the player stands on the coast cay's first landing cell and the raft build site is empty

#### Scenario: A beached raft launches again
- GIVEN a solo player on the coast cay beside the beached raft at integrity 70
- WHEN they launch it
- THEN a crossing starts at integrity 70, and when it ends the run shows the summary, since the coast cay names no next island

### Requirement: Entering the crossing
When a route starts, its riders SHALL leave the island into a crossing scene on every peer, with the vessel the route names: the launched raft at its current integrity, or, for a swimmers' route, the swimmers themselves with no integrity. Players who stay keep playing the island. The host owns the crossing and every client shows the same sea, vessel, events and riders. With exactly 1 player, launching a route takes that player into the crossing.

#### Scenario: Solo launches the raft
- GIVEN a 1-player run with a built raft at integrity 100
- WHEN the player launches it
- THEN the crossing scene holds that player aboard a raft at integrity 100, and the run has not ended

#### Scenario: One crosses, one stays
- GIVEN a 2-player run where only the first player uses the binoculars
- WHEN the route starts
- THEN on both peers the first player is in the crossing as a swimmer and the second is still on the island

### Requirement: Crossing length
A crossing SHALL last a length rolled on the host from the route's crossing duration (`duration_s`, within 60-120 s), and SHALL end when that time has passed whatever happened on the way. Sandbar routes are coast-band crossings: the raft lasts 60-90 s and binoculars-and-swim 60 s. The same holds with exactly 1 player.

#### Scenario: Crossing lasts its length
- GIVEN a raft route whose crossing duration is 75-75 s
- WHEN the crossing has run 74.9 s
- THEN it has not ended, and at 75 s it ends

#### Scenario: Solo finishes a coast crossing alone
- GIVEN a 1-player run on a 60 s raft crossing with no threat events
- WHEN the crossing runs to its end
- THEN it ends at 60 s with the player aboard and the raft at integrity 100

### Requirement: Threat plan
On entering, the host SHALL roll the crossing's events in time order from the route's risk profile, the distance band and the weather: a squall line that follows a squall the sky has warned or is running, or else is rolled by the squall's chance when the crossing is long enough for its warning; a shark pass and a rock by the band's chances times the route's factors. Clients receive the plan and never roll it. The plan is the same with exactly 1 player.

#### Scenario: A squall warned on the island follows the riders
- GIVEN a squall warned 40 s before a 90 s raft crossing starts
- WHEN the crossing starts
- THEN its plan holds a squall line hitting at 40 s

#### Scenario: Same seed, same plan
- GIVEN the same route, band, weather and seed
- WHEN the plan is rolled twice
- THEN both plans hold the same events at the same times

### Requirement: Raft integrity on the crossing
A raft on the crossing SHALL start at its integrity when launched (100 for a new raft) and lose 30 per squall times the route's squall factor, 20 per shark hit and 40 per rock, never below 0. At 0 it breaks: every rider aboard or tied falls in, nobody can climb or be pulled back, and they swim the rest of the crossing. Swimmers' routes have no integrity and take no vessel hits. The same holds with exactly 1 player, who swims the rest alone.

#### Scenario: Raft hits add up
- GIVEN a raft at integrity 100
- WHEN it takes a squall and a shark hit
- THEN its integrity is 50

#### Scenario: Squall, rock, squall break the raft
- GIVEN a 2-player crossing on a raft at integrity 100, one player tied down
- WHEN it takes a squall, a rock and a squall
- THEN integrity is 0, the raft is broken and both players are in the water, the tied one included

#### Scenario: Solo raft breaks
- GIVEN a 1-player crossing on a raft at integrity 40
- WHEN it hits a rock
- THEN the raft breaks, the player is in the water and holding interact at its edge for 3 s does not bring them aboard

### Requirement: Squall line on the crossing
A squall reaching the crossing SHALL be warned 60 s ahead by weather-daynight's warning and horizon line, shown in the crossing too. When it starts (or 10 s into a crossing launched during a running squall) it hits the raft once, and on a route that a squall dumps from, it throws every rider aboard who is not tied down into the water, with no chance roll. A tied-down rider stays aboard. With exactly 1 player, the player ties down alone.

#### Scenario: Squall warned 60 s ahead
- GIVEN a 90 s raft crossing whose plan rolls a squall warning at 10 s and its hit at 70 s
- WHEN the crossing reaches 10 s
- THEN the squall is warned with 60 s to go and the horizon line shows

#### Scenario: Tied down stays aboard
- GIVEN a 2-player raft crossing at integrity 100 where one player is tied down and the other is not
- WHEN the squall hits
- THEN the raft is at 70, the tied player is aboard and the other is in the water

### Requirement: Tying down
A rider aboard an intact raft SHALL tie down by holding interact for 1 s on the raft's lashing, and untie by using it again. A tied rider cannot move, stays aboard through a squall and falls in only when the raft breaks. A client's request goes to the host as its interact intent and the host decides. With exactly 1 player, the player ties down and unties alone.

#### Scenario: Solo ties down through a squall
- GIVEN a 1-player raft crossing at integrity 100
- WHEN the player holds interact on the lashing for 1 s and the squall hits
- THEN the player is aboard and tied, and the raft is at 70

### Requirement: Falling in
A rider who falls in (thrown by a squall, by the raft breaking or by stepping off the deck) SHALL lose 10 energy and swim alongside the vessel. Every second in the water costs 3 energy times the route's swim drain factor, moving or not. A swimmer at 0 energy floats and loses 10 health a second until pulled or climbed aboard, or dead. Solo rules (last stand) apply to a lone swimmer.

#### Scenario: Thrown in costs energy
- GIVEN a raft rider at energy 80 who is not tied down
- WHEN a squall throws them in and they stay in the water 5 s
- THEN their energy is 80 - 10 - 15 = 55

#### Scenario: A swimmers' route pays no fall-in cost
- GIVEN a swimmers' route
- WHEN its riders start the crossing in the water
- THEN nobody pays the 10 energy, only the per-second drain

#### Scenario: Solo swimmer finishes a swim crossing
- GIVEN a 1-player run whose player starts binoculars-and-swim at energy 100 on its 60 s crossing with swim drain factor 0.4
- WHEN the crossing runs to its end
- THEN the player is alive with energy 28 and the crossing ends at 60 s

### Requirement: Rescue timing on the crossing
Pulling and climbing aboard SHALL use the interaction hold rule: a rider aboard pulls a swimmer within 1 tile by holding interact on them for 2 s, and a swimmer within 1 tile of an intact vessel's edge climbs aboard alone by holding interact on it for 3 s. Releasing early resets the hold to 0 s. Both requests are a client's interact intent, applied by the host. With exactly 1 player, climbing alone is the way back aboard.

#### Scenario: Teammate pulls in 2 s
- GIVEN a 2-player raft crossing at integrity 60 with one player in the water beside the raft
- WHEN the player aboard holds interact on them for 2 s
- THEN the swimmer is aboard

#### Scenario: Solo climbs in 3 s, not 2
- GIVEN a 1-player raft crossing at integrity 60 whose player is in the water within 1 tile of the edge
- WHEN the player holds interact on the edge for 2 s and releases, then holds it for 3 s
- THEN the player is still in the water after the first hold, and aboard after the second

#### Scenario: Client requests are applied by the host
- GIVEN a 2-player raft crossing where the client's player is aboard
- WHEN the client holds interact on the lashing for 1 s, later falls in and holds interact on the edge for 3 s
- THEN the host ties the client's player down and then brings them aboard, and the client shows both states

### Requirement: Shark pass event
A shark pass SHALL hit, in this order of choice, a swimmer who is bleeding or below 20 energy (25 health and bleeding), otherwise an intact raft (-20), otherwise nobody. The shark pass is resolved through a replaceable threat hook (`CrossingThreats`) so the creatures-ai change can put a reef shark behind it without changing the crossing. With exactly 1 player, the lone player or their raft is the only target.

#### Scenario: Shark hits the raft
- GIVEN a raft crossing at integrity 100 with nobody in the water
- WHEN a shark pass comes
- THEN the raft is at 80

#### Scenario: Shark prefers a weak swimmer
- GIVEN a 1-player raft crossing whose player is in the water at energy 15 and health 100
- WHEN a shark pass comes
- THEN the player has health 75 and is bleeding, and the raft is untouched

### Requirement: Coast drift
On coast crossings the crossing SHALL record a drift offset of 0 tiles: steering is not built and the Gulf Stream rule of Steering and current applies only to mid and far crossings, which this change does not build. The same holds with exactly 1 player.

#### Scenario: Solo coast raft has no drift
- GIVEN a 1-player raft crossing from the sandbar
- WHEN it ends
- THEN its result records a drift offset of 0 tiles

### Requirement: End of the crossing
When the crossing ends, the host SHALL record a crossing result (route, vessel integrity and whether it broke, drift offset, and each rider's health, energy, whether they were aboard and whether they died) and send it to every client; the riders then leave play until arrival on the next island exists. A rider who died on the way counts as dead. With exactly 1 player, the result holds that player alone.

#### Scenario: Result carries the damaged raft
- GIVEN a 1-player raft crossing that took one squall while the player was tied down
- WHEN it ends
- THEN the result holds integrity 70, not broken, drift 0, and the player aboard and alive

### Requirement: Joining during a crossing
A peer that joins the run, or rejoins and takes back its body, while a crossing is under way SHALL show that crossing as the host has it: the same route, riders, elapsed time, rider states and vessel integrity, and the crossing's later events and its end. Each rider's body is in the sea where the host has it, on sea ground, with the camera kept to the sea. The joiner rolls and replays nothing. With exactly 1 player, offline, nobody can join, and the crossing runs as before.

#### Scenario: A new player joins mid-crossing
- **GIVEN** a 2-player run whose host and client ride a raft 20 s into a 90 s crossing, the raft at integrity 70 of 100 and the client in the water
- **WHEN** a third player joins
- **THEN** the third player's screen shows that crossing at about 20 s, with the raft at 70 of 100, the host aboard and the client in the water where the host has them, and it ends there when it ends on the host

#### Scenario: A rider rejoins mid-crossing
- **GIVEN** a 2-player run whose host and client ride a raft, the client tied down
- **WHEN** the client drops and joins again 10 s later from the same install
- **THEN** the client's screen shows the crossing with their own body tied on the raft, on sea ground and with the camera kept to the sea, and the host still has them in the same slot

#### Scenario: Joining before the route's start reached the joiner
- **GIVEN** a client that connected and saw a route start before the host answered its join request
- **WHEN** the host's answer arrives
- **THEN** the client shows one crossing for that route, not two

#### Scenario: Solo crossing unchanged
- **GIVEN** a 1-player run, offline, whose player launches the raft
- **WHEN** the crossing runs to its end
- **THEN** it plays and ends as before, and nothing is sent to anyone

### Requirement: Crossing messages reach only peers that have the crossing
The host SHALL send a crossing's plan, rider states and result only to peers that have that crossing: those in the run when it started, and each joiner once that joiner has been told of it. No peer receives a message for a crossing it does not have. With exactly 1 player, offline, there is no peer and nothing is sent.

#### Scenario: A peer still joining gets no crossing messages
- **GIVEN** a crossing under way and a client that has connected but whose join request the host has not answered yet
- **WHEN** the host sends the crossing's rider states
- **THEN** that client receives none, and it logs no error about a missing crossing
