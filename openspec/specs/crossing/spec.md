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
The Gulf Stream SHALL push the vessel east at 1 tile/s on mid and far crossings. Any player aboard steers against it with no held station, cutting drift to 0.25 tile/s; a Maestro, a player with Navigation ≥ 2 or anyone with compass+charts aboard cancels drift. With nobody aboard, drift stays 1 tile/s. Drift is a lateral offset capped at 40 tiles and never lengthens the crossing; a crossing whose offset reached the cap skips to a harder chain. The broken compass and the map without north (secret-cay) never count as the compass or the charts. (Changes docs/GAME_DESIGN.md §8.)

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

#### Scenario: The broken compass and the map do not cancel drift
- GIVEN a 1-player run whose only player is a Pescador with Navigation 0 carrying the broken compass and the map without north, aboard a raft on a 120 s far crossing
- WHEN the crossing runs to its end with the player aboard
- THEN drift was 0.25 tile/s throughout, as with no compass or charts

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

### Requirement: Per-rider boards
On a board route each rider SHALL ride their own board, which starts at the route's vessel integrity (60). Nobody shares a board or stands on another rider's. A board has no lashing, so its rider cannot tie down. A squall hits every intact board (−30 times the route's squall factor) and throws every board rider who is aboard into the water. At 0 a board breaks: only its own rider falls in and swims the rest. With exactly 1 player there is one board. (Adds to docs/GAME_DESIGN.md §8.)

#### Scenario: Solo rider on one board
- **GIVEN** a 1-player run whose player starts a board route
- **WHEN** the crossing starts
- **THEN** the player is aboard one board at integrity 60, and there is no other vessel and no lashing to use

#### Scenario: A squall on three boards
- **GIVEN** 3 riders aboard their boards, each at integrity 60
- **WHEN** a squall hits
- **THEN** each board is at 30 and all three riders are in the water

#### Scenario: Solo board breaks
- **GIVEN** a 1-player board crossing with the board at 60
- **WHEN** a rock hits it and then a shark hits it
- **THEN** the board is at 0 and broken, the rider is in the water, and holding interact at its edge for 3 s does not bring them aboard

#### Scenario: One board breaks, the others ride on
- **GIVEN** 2 riders aboard their boards, the first at 40 and the second at 60
- **WHEN** a rock hits the first rider's board
- **THEN** the first board breaks and its rider is in the water, while the second rider is still aboard a board at 60

### Requirement: Board hits
A shark pass on a board crossing SHALL first take a swimmer who meets its strike conditions, as on any crossing; otherwise it hits one intact board. A rock SHALL hit one intact board. The first such board hit takes the first rider's board, and each later one takes the next intact board in rider order, wrapping round. With exactly 1 player, the lone board takes every hit.

#### Scenario: Hits go round the boards
- **GIVEN** 3 riders aboard their boards at 60, nobody in the water
- **WHEN** a rock and then a shark pass come
- **THEN** the first rider's board is at 20, the second rider's at 40, and the third rider's at 60

#### Scenario: A broken board is skipped
- **GIVEN** 2 riders whose first board broke and whose second board is at 60, with the first rider swimming at energy 50 and not bleeding
- **WHEN** a rock comes
- **THEN** the second board is at 20 and the swimmer is untouched

### Requirement: Shark dumps
On a route whose dump triggers include a shark attack, a shark hit on a vessel SHALL throw that vessel's riders who are aboard and not tied down into the water, at the usual fall-in cost. On a board route that is the one rider of the hit board. Routes without the trigger are unchanged. With exactly 1 player, the lone rider is the one thrown in.

#### Scenario: Solo rider dumped and climbing back
- **GIVEN** a 1-player run, a board rider at energy 80 on a board at integrity 60, on a route that a shark attack dumps from
- **WHEN** a shark hits the board, and the rider then holds interact for 3 s within 1 tile of the board's edge
- **THEN** the board is at 40, the rider fell in at energy 70, and is aboard again with no teammate needed

#### Scenario: A raft route without the trigger
- **GIVEN** a raft crossing whose route lists only the squall as a dump trigger, with one rider aboard
- **WHEN** a shark hits the raft
- **THEN** the raft is at 80 and the rider is still aboard

### Requirement: Board rescue
A board rider in the water SHALL climb back onto their own intact board by holding interact for 3 s within 1 tile of its edge. A teammate aboard their own board SHALL pull a swimmer within 1 tile back onto the swimmer's own intact board by holding interact on them for 2 s. Nobody climbs or is pulled onto a broken board or onto another rider's board. With exactly 1 player, climbing alone is the way back.

#### Scenario: Releasing early does not climb a board
- **GIVEN** a 1-player board crossing whose rider is in the water within 1 tile of their board at 40
- **WHEN** the rider holds interact for 2 s and releases, then holds it for 3 s
- **THEN** the rider is still in the water after the first hold, and aboard their board after the second

#### Scenario: A teammate pulls a rider back onto their own board
- **GIVEN** 2 board riders, the second in the water within 1 tile of the first, both boards intact
- **WHEN** the first holds interact on the second for 2 s
- **THEN** the second rider is aboard their own board, and the first is still aboard theirs

### Requirement: Board crossing state
When a board crossing ends, the result SHALL record each rider's board integrity and whether it broke. Every client, and a peer that joins or rejoins during the crossing, SHALL show every board at the integrity the host has and a broken board as gone. The joiner rolls and replays nothing. With exactly 1 player, offline, the result holds one board and nothing is sent.

#### Scenario: Solo result holds the board
- **GIVEN** a 1-player board crossing whose board took a shark hit
- **WHEN** it ends
- **THEN** the result holds that rider's board at 40, not broken, and the rider aboard and alive

#### Scenario: A client sees every board
- **GIVEN** a host and a client riding boards, where the host's board took a rock
- **WHEN** the client shows the crossing
- **THEN** it shows the host's board at 20 and its own at 60

#### Scenario: A joiner sees a broken board as gone
- **GIVEN** a 2-player board crossing in which the client's board broke
- **WHEN** a third player joins during the crossing
- **THEN** the joiner shows the host's board at the host's integrity and no board for the client, who is in the water where the host has them

### Requirement: Vessel look on the crossing
The crossing SHALL draw the vessel the route names: the raft for a raft, a car for the almendrón, one board under each board rider, and nothing for swimmers. Each vessel shows whole, worn or breaking by the share it has left of its route's vessel integrity, with the raft's thresholds (whole above 66 %, worn above 33 %), and nothing once it has sunk. Drawing never changes the crossing. A client and a late joiner draw from the state they receive. A solo crossing looks the same.

#### Scenario: Solo car in a squall
- **GIVEN** a 1-player car crossing at integrity 160
- **WHEN** a squall and then a shark hit it
- **THEN** the car is at 95 and is drawn worn (95 of 160)

#### Scenario: A new board reads whole
- **GIVEN** a 1-player board crossing whose board is at 60 of 60
- **WHEN** the crossing is drawn
- **THEN** the board is drawn whole, under its rider

#### Scenario: Boards on two peers
- **GIVEN** a host and a client riding boards, the client's board broken
- **WHEN** both draw the crossing
- **THEN** on both peers the host's board is drawn under the host and no board is drawn for the client

### Requirement: Arrival scatter
Each route SHALL name an arrival scatter in tiles, a minimum and a maximum (default 0–5). The host SHALL pick each arriving rider's landing cell; every peer lands them there. Default-scatter riders land on the landing cells as before. Each rider of a wider route lands, in peer order, on a reachable, unfurnished beach cell within its range from every rider already placed, rolled from the run seed. With exactly 1 player, the player lands on the first landing cell.

#### Scenario: Three board riders land apart
- **GIVEN** 3 riders who end a board crossing whose route scatters 10–20 tiles
- **WHEN** they arrive
- **THEN** each stands on a beach cell 10–20 tiles from each of the others, the same cell on every peer

#### Scenario: Solo board rider lands on the first landing cell
- **GIVEN** a 1-player run whose rider ends a board crossing
- **WHEN** the player arrives
- **THEN** the player stands on the next island's first landing cell

#### Scenario: Same seed, same landing
- **GIVEN** the same run seed, island and riders
- **WHEN** the host picks the landing twice
- **THEN** both picks hold the same cells

#### Scenario: A raft party and a board rider
- **GIVEN** 2 riders who crossed by raft and 1 who crossed by board, in one landing
- **WHEN** they arrive
- **THEN** the raft riders stand on the landing cells, and the board rider on a beach cell 10–20 tiles from both

### Requirement: Arrival scatter fallback
When no beach cell meets a rider's scatter, the host SHALL pick the beach cell that keeps the minimum from every rider already placed and is nearest to the farthest of them. When no cell keeps the minimum, it SHALL pick the beach cell farthest from its nearest placed rider. A rider never lands on another rider's cell while a free beach cell remains. A solo rider never needs the fallback.

#### Scenario: A beach too small for four boards
- **GIVEN** 4 board riders arriving on an island whose reachable beach cannot fit 4 cells 10–20 tiles apart from each other
- **WHEN** they arrive
- **THEN** every rider stands on a different beach cell, as far apart as the rule above allows

### Requirement: Beaching by vessel
A crossing result SHALL beach a vessel at the next island's raft site only when its route's vessel is a raft kept on arrival, intact. A board, a car, swimmers or any other vessel never puts a raft there. A route whose vessel is lost on arrival, such as the board, leaves nothing on the beach. With exactly 1 player the same holds.

#### Scenario: Solo board rider leaves nothing behind
- **GIVEN** a 1-player run whose rider ends a board crossing with the board at 30
- **WHEN** the player arrives
- **THEN** the board is gone, the raft site is empty, and nothing is left to find

#### Scenario: A raft and a board arrive together
- **GIVEN** 2 riders who crossed by raft, ending at 70, and 1 by board, ending at 50
- **WHEN** they arrive
- **THEN** a raft at 70 stands at the raft site and no other vessel is beached
