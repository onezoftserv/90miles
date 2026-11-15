# Spec Delta

## MODIFIED Requirements

### Requirement: Steering and current
The Gulf Stream SHALL push the vessel east at 1 tile/s on mid and far crossings. Any player aboard steers against it with no held station, cutting drift to 0.25 tile/s; a Maestro, a player with Navigation ≥ 2 or anyone with compass+charts aboard cancels drift. With nobody aboard, drift stays 1 tile/s. Drift is a lateral offset capped at 40 tiles and never lengthens the crossing; a crossing whose offset reached the cap skips to a harder chain. The broken compass and the map without north (secret-cay) never count as the compass or the charts. Paddling (crossing "Paddling") moves the vessel within the sea to dodge and reach things; it never adds to, cuts or cancels the drift offset. (Changes docs/GAME_DESIGN.md §8.)

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

#### Scenario: Paddling is not drift
- **GIVEN** a 1-player run whose only player paddles a raft 6 tiles east of the line and holds it there for 20 s on a 120 s far crossing
- **WHEN** the crossing runs to its end
- **THEN** the drift offset is the same as if they had never paddled

### Requirement: Threat plan
On entering, the host SHALL roll the crossing's plan in time order from the route's risk profile, the distance band, the weather and the number of riders: a squall line that follows a squall the sky has warned or is running, or else is rolled by the squall's chance when the crossing is long enough for its warning; a shark pass by the band's chance times the route's factors; and the paced beats of "Crossing pacing". Clients receive the plan and never roll it. With exactly 1 player the plan is rolled for one rider.

#### Scenario: A squall warned on the island follows the riders
- GIVEN a squall warned 40 s before a 90 s raft crossing starts
- WHEN the crossing starts
- THEN its plan holds a squall line hitting at 40 s

#### Scenario: Same seed, same plan
- GIVEN the same route, band, weather, number of riders and seed
- WHEN the plan is rolled twice
- THEN both plans hold the same beats at the same times, in the same lanes and on the same sides

#### Scenario: A solo plan is rolled for one rider
- **GIVEN** a 1-player run launching the raft
- **WHEN** the host rolls the plan
- **THEN** the plan is the one the same seed rolls for one rider, and it reaches nobody else

### Requirement: Raft integrity on the crossing
A raft on the crossing SHALL start at its integrity when launched (100 for a new raft) and lose 30 per squall times the route's squall factor, 20 per shark hit, 40 per rock that hits it, 5 per debris that hits it and 0.5 per second for each open leak, and gain 10 per plank lashed on, never below 0 or above its starting maximum. At 0 it breaks: every rider aboard or tied falls in, nobody can climb or be pulled back, and they swim the rest of the crossing. Swimmers' routes have no integrity and take no vessel hits. The same holds with exactly 1 player, who swims the rest alone. (Adds debris, leaks and planks to docs/GAME_DESIGN.md §8.)

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

#### Scenario: A leak finishes a raft
- **GIVEN** a 1-player crossing on a raft at integrity 3 with one open leak
- **WHEN** 6 s pass and nobody plugs it
- **THEN** the raft broke at 6 s and the player is in the water

### Requirement: Shark pass event
A shark pass SHALL be warned 5 s before its strike by a fin circling beside the side of the vessel the pass names (crossing "Shooing the shark"). At the strike, unless the shark was shooed, it hits, in this order of choice, a swimmer who is bleeding or below 20 energy (25 health and bleeding), otherwise an intact raft (-20), otherwise nobody. The shark pass is resolved through a replaceable threat hook (`CrossingThreats`) so the creatures-ai change can put a reef shark behind it without changing the crossing. With exactly 1 player, the lone player or their raft is the only target.

#### Scenario: Shark hits the raft
- GIVEN a raft crossing at integrity 100 with nobody in the water
- WHEN a shark pass comes
- THEN the raft is at 80

#### Scenario: Shark prefers a weak swimmer
- GIVEN a 1-player raft crossing whose player is in the water at energy 15 and health 100
- WHEN a shark pass comes
- THEN the player has health 75 and is bleeding, and the raft is untouched

#### Scenario: The fin shows before the strike
- **GIVEN** a 1-player raft crossing whose plan holds a shark pass striking at 30 s on the east side
- **WHEN** the crossing reaches 25 s
- **THEN** the shark's fin circles 1 tile off the raft's east edge, and the raft is still at 100

### Requirement: Squall line on the crossing
A squall reaching the crossing SHALL be warned 60 s ahead by weather-daynight's warning and horizon line, shown in the crossing too. When it starts (or 10 s into a crossing launched during a running squall) it hits the raft once, and on a route that a squall dumps from, it throws every rider aboard who is not tied down into the water, with no chance roll. A tied-down rider stays aboard. For 15 s after the hit the squall blows hardest on the crossing (its blow) and paddling runs at half speed. With exactly 1 player, the player ties down alone.

#### Scenario: Squall warned 60 s ahead
- GIVEN a 90 s raft crossing whose plan rolls a squall warning at 10 s and its hit at 70 s
- WHEN the crossing reaches 10 s
- THEN the squall is warned with 60 s to go and the horizon line shows

#### Scenario: Tied down stays aboard
- GIVEN a 2-player raft crossing at integrity 100 where one player is tied down and the other is not
- WHEN the squall hits
- THEN the raft is at 70, the tied player is aboard and the other is in the water

#### Scenario: Solo paddles slowly in the blow
- **GIVEN** a 1-player raft crossing on the line whose player was tied down when the squall hit at 40 s
- **WHEN** the player unties at 42 s and holds the east paddle from 43 s to 45 s
- **THEN** the raft is 1.5 tiles east of the line at 45 s, half what the same hold moves it in calm water

### Requirement: Coast drift
On coast crossings the crossing SHALL record a drift offset of 0 tiles: the Gulf Stream rule of Steering and current applies only to mid and far crossings, which are not built yet, and paddling never adds to the drift. The same holds with exactly 1 player.

#### Scenario: Solo coast raft has no drift
- GIVEN a 1-player raft crossing from the sandbar
- WHEN it ends
- THEN its result records a drift offset of 0 tiles

#### Scenario: Solo paddles and still records no drift
- **GIVEN** a 1-player raft crossing from the sandbar whose player paddled to 6 tiles east of the line and stayed there to the end
- **WHEN** it ends
- **THEN** its result records a drift offset of 0 tiles

### Requirement: Board hits
A shark pass on a board crossing SHALL first take a swimmer who meets its strike conditions, as on any crossing; otherwise it hits one intact board. A rock or debris SHALL hit one intact board when its lane overlaps the row of boards (crossing "Scrolling hazards"), and none when it misses the row. The first such board hit takes the first rider's board, and each later one takes the next intact board in rider order, wrapping round. With exactly 1 player, the lone board takes every hit.

#### Scenario: Hits go round the boards
- **GIVEN** 3 riders aboard their boards at 60, nobody in the water
- **WHEN** a rock and then a shark pass come
- **THEN** the first rider's board is at 20, the second rider's at 40, and the third rider's at 60

#### Scenario: A broken board is skipped
- **GIVEN** 2 riders whose first board broke and whose second board is at 60, with the first rider swimming at energy 50 and not bleeding
- **WHEN** a rock comes
- **THEN** the second board is at 20 and the swimmer is untouched

#### Scenario: A rock beside the row misses every board
- **GIVEN** 3 riders aboard their boards at 60, the row on the line
- **WHEN** a rock passes in lane 6
- **THEN** every board is still at 60

### Requirement: Joining during a crossing
A peer that joins the run, or rejoins and takes back its body, while a crossing is under way SHALL show that crossing as the host has it: the same route, riders, elapsed time, rider states and vessel integrity, the vessel's lateral position, its open leaks, the flotsam already taken and the shark passes already shooed, and the crossing's later events and its end. Each rider's body is in the sea where the host has it, on sea ground, with the camera kept to the sea. The joiner rolls and replays nothing. With exactly 1 player, offline, nobody can join, and the crossing runs as before.

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

#### Scenario: A joiner sees the raft off the line with a leak
- **GIVEN** a 2-player raft crossing 40 s in, the raft 3 tiles east of the line with one open leak, a coconut already taken and the shark pass already shooed
- **WHEN** a third player joins
- **THEN** the joiner's screen shows the raft 3 tiles east of the line with that leak open, does not show the coconut or the shark, and the raft keeps losing 0.5 a second there as on the host

## ADDED Requirements

### Requirement: Beat lanes and sides
Each rock, debris and flotsam beat in a crossing's plan SHALL name a lane: whole tiles east (positive) or west (negative) of the line the vessel sails, from -10 to 10. Each shark pass SHALL name a side, west or east. A beat that names no lane rides the line (lane 0), and a shark pass that names no side comes from the west. The same holds with exactly 1 player.

#### Scenario: An old-form rock rides the line
- **GIVEN** a 1-player raft crossing whose hand-written plan holds a rock at 30 s with no lane
- **WHEN** the player does nothing and the crossing reaches 30 s
- **THEN** the rock was in lane 0 and the raft is at 60, as before this change

### Requirement: Paddling
A shared vessel SHALL have a paddle point on its west edge and one on its east edge; a board has one on each side. A rider aboard who holds interact on one moves the vessel toward that side at 1.5 tiles/s, or 2.25 with two or more riders on that side; the two sides' speeds subtract. With nobody paddling, the vessel drifts back toward the line at 0.5 tiles/s. It stays within 6 tiles of the line. The host applies it. A solo rider paddles alone.

#### Scenario: Solo paddles off the line and drifts back
- **GIVEN** a 1-player raft crossing with the raft on the line
- **WHEN** the player holds interact on the east paddle for 2 s, then lets go for 2 s
- **THEN** the raft is 3 tiles east of the line when they let go, and 2 tiles east 2 s later

#### Scenario: Two paddlers on one side
- **GIVEN** a 2-player raft crossing with the raft on the line
- **WHEN** both riders hold interact on the west paddle for 2 s
- **THEN** the raft is 4.5 tiles west of the line

#### Scenario: Paddles on both sides cancel
- **GIVEN** a 2-player raft crossing with the raft on the line
- **WHEN** one rider holds the west paddle and the other the east paddle for 2 s
- **THEN** the raft is still on the line

#### Scenario: Solo paddles to the limit
- **GIVEN** a 1-player raft crossing with the raft on the line
- **WHEN** the player holds the east paddle for 5 s
- **THEN** the raft is 6 tiles east of the line

#### Scenario: A client paddles
- **GIVEN** a 2-player raft crossing whose client rides aboard
- **WHEN** the client holds the east paddle for 2 s
- **THEN** the host moves the raft 3 tiles east of the line and the client's screen shows it there

#### Scenario: The row of boards paddles as one
- **GIVEN** 2 riders on a board route, their boards on the line
- **WHEN** the first rider holds their board's east paddle for 2 s
- **THEN** both boards are 3 tiles east of the line, still 3 tiles apart

### Requirement: Scrolling hazards
A rock or debris beat SHALL show at the sea's north edge in its lane 5 s before its time and reach the vessel's deck rows at its time. Then it hits the vessel when its lane is closer to the vessel's lateral position than half the vessel's width plus half its own (rock 2 tiles wide, debris 1; raft and car 4; the row of boards from its first edge to its last). A miss changes nothing. A solo rider dodges alone. (Adds debris to docs/GAME_DESIGN.md §8.)

#### Scenario: Solo leaves a rock in line alone and takes it
- **GIVEN** a 1-player raft crossing at integrity 100 with the raft on the line and a rock in lane 0 at 30 s
- **WHEN** the player does nothing
- **THEN** the raft is at 60 at 30 s

#### Scenario: Solo dodges a rock
- **GIVEN** a 1-player raft crossing at integrity 100 with the raft on the line and a rock in lane 0 at 30 s
- **WHEN** the player holds the east paddle from 27 s until 30 s
- **THEN** the raft is 4.5 tiles east of the line at 30 s, the rock passes it and the raft is at 100

#### Scenario: The rock is seen coming
- **GIVEN** a 1-player raft crossing with a rock in lane 2 at 30 s
- **WHEN** the crossing reaches 25 s
- **THEN** the rock shows at the sea's north edge, 2 tiles east of the line

#### Scenario: A rock out of line passes by
- **GIVEN** a 1-player raft crossing at integrity 100 with the raft on the line and a rock in lane 4 at 30 s
- **WHEN** the player does nothing
- **THEN** the rock passes and the raft is at 100

#### Scenario: Debris holes the raft
- **GIVEN** a 1-player raft crossing at integrity 100 with the raft on the line and debris in lane 1 at 20 s
- **WHEN** the player does nothing
- **THEN** the raft is at 95 at 20 s and has one open leak on its east half

### Requirement: Hazards and swimmers
A rock or debris SHALL cut each swimmer it passes over once: a rock takes 15 health and starts bleeding, debris takes 5 health. Swimmers on a vessel route keep pace with the vessel, so a hazard's place beside them follows the vessel's lateral position; on a swimmers' route the line never moves. A swimmer who swims out of its lane in time is not cut. The same holds for a lone swimmer. (Adds to docs/GAME_DESIGN.md §8 and docs/BESTIARY.md "Reef shark": coral cuts.)

#### Scenario: Solo swimmer cut by a rock
- **GIVEN** a 1-player binoculars-and-swim crossing whose player, at health 100, floats in lane 0 when a rock in lane 0 reaches them
- **WHEN** the rock passes over them
- **THEN** the player has health 85 and is bleeding

#### Scenario: Solo swimmer swims clear
- **GIVEN** a 1-player binoculars-and-swim crossing with a rock in lane 0 at 30 s
- **WHEN** the player swims 3 tiles east of it before it reaches them
- **THEN** the rock passes and the player's health is unchanged

### Requirement: Leaks
Debris that hits a vessel SHALL open a leak on the half of its deck nearer the debris (on a board, on that board). Each open leak drains 0.5 integrity a second until a rider aboard that vessel holds interact on it for 2 s, which plugs it; letting go early resets the hold. A vessel holds at most 3 open leaks; a hit beyond that opens none. A solo rider plugs alone.

#### Scenario: An unplugged leak drains the raft
- **GIVEN** a 1-player raft crossing at integrity 100 whose raft takes debris at 20 s
- **WHEN** nobody plugs the leak
- **THEN** the raft is at 90 at 30 s

#### Scenario: Solo plugs a leak
- **GIVEN** a 1-player raft crossing at integrity 100 whose raft takes debris at 20 s
- **WHEN** the player holds interact on the leak from 22 s to 24 s
- **THEN** the leak is plugged and the raft is at 93 at 30 s

#### Scenario: Letting go early does not plug
- **GIVEN** a 1-player raft crossing with one open leak
- **WHEN** the player holds interact on it for 1.5 s, lets go, then holds it for 2 s
- **THEN** the leak is still open after the first hold and plugged after the second

#### Scenario: A fourth hole opens nothing
- **GIVEN** a 1-player raft crossing at integrity 80 with 3 open leaks
- **WHEN** debris hits the raft
- **THEN** the hit takes 5, to 75, and the raft still has 3 open leaks

#### Scenario: A board rider plugs their own board
- **GIVEN** a 1-player board crossing whose board, at 60, takes debris
- **WHEN** the rider holds interact on the leak for 2 s from their board, starting at once
- **THEN** the board's leak is plugged and the board is at 54

### Requirement: Flotsam
A flotsam beat SHALL carry one piece from the crossing tuning's flotsam table (an item, or a plank) down its lane like a hazard, harmless. A rider aboard within 1 tile of it as it passes takes it by holding interact on it for 0.3 s, and a swimmer takes it by touching it. An item goes into the taker's inventory, or the piece passes on if it is full; a plank is lashed at once: +10 to the taker's vessel. The first to take it gets it. A solo rider takes flotsam alone.

#### Scenario: Solo grabs a coconut
- **GIVEN** a 1-player raft crossing with the raft on the line and a coconut in lane 3 at 40 s
- **WHEN** the player stands at the raft's east edge and holds interact on the coconut for 0.3 s as it passes
- **THEN** the player carries one more coconut

#### Scenario: Out of reach
- **GIVEN** a 1-player raft crossing with the raft on the line and a rope piece in lane 6 at 40 s
- **WHEN** the player does nothing
- **THEN** the rope passes by and the player's inventory is unchanged

#### Scenario: Solo lashes a plank
- **GIVEN** a 1-player raft crossing at integrity 70 with a plank passing within reach
- **WHEN** the player takes it
- **THEN** the raft is at 80, and a plank taken at 95 brings it to 100, no higher

#### Scenario: A full inventory leaves the piece
- **GIVEN** a 1-player raft crossing whose player's inventory has no room for driftwood, with driftwood passing within reach
- **WHEN** the player holds interact on it for 0.3 s
- **THEN** the driftwood stays in the sea and passes by

#### Scenario: A swimmer touches a piece
- **GIVEN** a 1-player raft crossing whose player swims beside the raft with a rope piece passing them
- **WHEN** the player swims into it
- **THEN** the player carries one more rope and the piece is gone

#### Scenario: Two riders reach for one coconut
- **GIVEN** a 2-player raft crossing with both riders within reach of a passing coconut
- **WHEN** both hold interact on it and the client's hold completes first on the host
- **THEN** the client carries the coconut and the host carries nothing new, on both peers

### Requirement: Shooing the shark
A shark pass's fin SHALL circle 1 tile off the side its pass names for the 5 s before the strike: beside the shared vessel's edge, beside the board next in turn, or beside the swimmers with no vessel. A rider aboard within 1 tile of the fin who holds interact on it for 1 s before the strike shoos it: it leaves and bites and hits nothing. A hold still running at the strike shoos nothing. A solo rider shoos alone, or a lone swimmer climbs aboard before the strike.

#### Scenario: Solo shoos the shark
- **GIVEN** a 1-player raft crossing at integrity 100 whose shark pass strikes at 30 s on the west side
- **WHEN** the player stands at the west edge and holds interact on the fin from 27 s to 28 s
- **THEN** the shark leaves and the raft is at 100 at 30 s

#### Scenario: Too late to shoo
- **GIVEN** a 1-player raft crossing at integrity 100 whose shark pass strikes at 30 s on the west side
- **WHEN** the player starts holding interact on the fin at 29.5 s
- **THEN** the shark strikes at 30 s and the raft is at 80

#### Scenario: A tired solo swimmer climbs out in time
- **GIVEN** a 1-player raft crossing whose player swims at energy 15 within 1 tile of the raft at 100, and whose shark pass strikes at 30 s
- **WHEN** the player holds interact on the raft's edge from 25 s to 28 s
- **THEN** the player is aboard at 28 s, nobody is bitten, and the raft is at 80 after the strike

#### Scenario: A teammate saves a tired swimmer
- **GIVEN** a 2-player raft crossing whose client swims at energy 15 and whose shark pass strikes at 30 s on the east side
- **WHEN** the host stands at the east edge and holds interact on the fin from 26 s to 27 s
- **THEN** the shark leaves, the client's health is unchanged and the raft is at 100

### Requirement: Jobs aboard
Paddling, plugging a leak, taking flotsam from the deck and shooing the shark SHALL each need a rider aboard and not tied down. A tied rider keeps only untying; a swimmer keeps only climbing back, being pulled and touching flotsam. So tying down early for a squall costs the jobs that come before it. A solo rider faces the same trade.

#### Scenario: Solo ties down too early
- **GIVEN** a 1-player raft crossing at integrity 100 with the raft on the line, a rock in lane 0 at 35 s and a squall hitting at 40 s
- **WHEN** the player ties down at 30 s and holds the east paddle from 31 s to 35 s
- **THEN** the raft does not move, the rock hits at 35 s and the squall at 40 s, and the raft is at 30

#### Scenario: Solo dodges, then ties down
- **GIVEN** the same 1-player crossing
- **WHEN** the player holds the east paddle from 32 s to 35 s and ties down from 37 s to 38 s
- **THEN** the rock misses and the player is tied when the squall hits at 40 s, and the raft is at 70

### Requirement: Which job a press takes
When a rider's press could reach more than one crossing point, it SHALL go, in this order, to a fin to shoo, a swimmer to pull, flotsam to take, a leak to plug, then a paddle, the lashing or a climb point, and on a tie to the nearest; a perched creature's shoo stays below all of them. The same holds with exactly 1 player.

#### Scenario: Solo at the edge with the fin coming
- **GIVEN** a 1-player raft crossing whose player stands at the west edge, within reach of the west paddle and of a fin circling the west side
- **WHEN** the player holds interact for 1 s
- **THEN** the shark is shooed and the raft has not moved

#### Scenario: Solo plugs before paddling
- **GIVEN** a 1-player raft crossing whose player stands at the east edge, within reach of the east paddle and of an open leak
- **WHEN** the player holds interact for 2 s
- **THEN** the leak is plugged and the raft has not moved

### Requirement: Crossing pacing
The host's rolled plan SHALL roll no beat in the first 6 s, put its first rolled beat between 6 and 9 s, and end with the reef line: two rocks 10 tiles apart (lanes g−5 and g+5, g from −3 to 3) at the length minus 4 s. Consecutive beats are 3 to 9 s apart, the 9 s times 0.9 per rider past the first. Solo is the base. (Changes docs/GAME_DESIGN.md §8.)

#### Scenario: A solo plan never goes quiet
- **GIVEN** any plan rolled for a 1-player raft crossing of 60 to 90 s from the sandbar
- **WHEN** its beat times are read in order
- **THEN** the first rolled beat is between 6 and 9 s unless a squall's blow covers that time, the last is the reef line at the length minus 4 s, and no two consecutive times (the squall's hit counted, its warning not) are more than 9 s or less than 3 s apart, except across a squall's blow

#### Scenario: Four riders get a denser plan
- **GIVEN** any plan rolled for a 4-player raft crossing of 60 to 90 s
- **WHEN** its beat times are read in order
- **THEN** no two consecutive times between the first beat and the reef line are more than 9 × 0.9³ s (about 6.56 s) apart, except across a squall's blow

#### Scenario: Solo steers through the reef line
- **GIVEN** a 1-player raft crossing at integrity 100 whose reef line has its gap at lane 3, the raft on the line
- **WHEN** the player paddles the raft to 3 tiles east of the line before the reef line arrives
- **THEN** both rocks pass the raft and it is still at 100, while a raft left on the line takes the west rock and is at 60

### Requirement: The squall's blow in the plan
A squall's blow (the 15 s after its hit) SHALL hold no rolled beat, and it overrides Crossing pacing's calm start, first-beat window and spacing, but it never moves the reef line. A rock or debris falls in the 10 s before a squall hit at 16 s or later. The same holds with exactly 1 player.

#### Scenario: The squall's blow is left clear
- **GIVEN** a rolled plan whose squall hits at 50 s
- **WHEN** its beats are read
- **THEN** no rolled beat falls after 50 s and before 65 s, and a rock or debris falls between 40 and 50 s

#### Scenario: A squall carried from the island hits early
- **GIVEN** a 1-player raft crossing launched with a squall warned on the island to hit 4 s in
- **WHEN** its plan is rolled
- **THEN** the squall hits at 4 s, no rolled beat falls before 19 s, and the first rolled beat falls between 19 and 28 s

#### Scenario: Solo meets the reef line in the blow
- **GIVEN** a 1-player 75 s raft crossing whose squall hits at 62 s, the player tied down, and whose reef line has its gap at lane 3 at 71 s
- **WHEN** the player unties at once after the hit and holds the east paddle from 66 s to 70 s
- **THEN** the raft is 3 tiles east of the line at 70 s, both reef rocks pass it at 71 s, and the raft is at 70

### Requirement: Crossing HUD and telegraphs
Each peer in a crossing SHALL draw, top-centre below the day phase and clear of the sign note's place, a progress strip from the departure island to the next (the vessel at the elapsed share) and the vessel's integrity out of its maximum. Short lines show: 30 s and 10 s before a squall hit, when a fin appears (naming its side), and when a leak opens. Hazards, flotsam, leaks and fins are drawn where the host's state puts them. Drawing never changes the crossing. A solo player sees the same.

#### Scenario: Solo reads the strip
- **GIVEN** a 1-player 60 s raft crossing whose raft took a squall while the player was tied
- **WHEN** the crossing reaches 30 s
- **THEN** the strip shows the raft halfway and the integrity reads 70 of 100

#### Scenario: The squall counts down
- **GIVEN** a 1-player raft crossing whose squall hits at 70 s
- **WHEN** the crossing reaches 40 s and then 60 s
- **THEN** "La raya negra viene pa'cá." shows at 40 s and "¡Amárrate, que ahí viene!" at 60 s

#### Scenario: A fin and a leak are called out
- **GIVEN** a 1-player raft crossing whose shark pass strikes on the west side at 30 s and whose raft takes debris at 40 s
- **WHEN** the crossing reaches 25 s and then 40 s
- **THEN** "¡Aleta! Por la izquierda." shows at 25 s and "¡Un hueco! Tápalo." at 40 s

### Requirement: Crossing play state on every peer
The host SHALL send each peer that has the crossing the vessel's lateral position and paddling, its open leaks, the flotsam taken and by whom, and the shark passes shooed, on change and with each resync; a joiner gets them in the snapshot. Clients show what they receive and decide none of it; hazards and flotsam move by the plan and the received position. With exactly 1 player, offline, nothing is sent.

#### Scenario: A client sees the host paddle
- **GIVEN** a host and a client riding a raft on the line
- **WHEN** the host holds the west paddle for 2 s
- **THEN** the client's screen shows the raft 3 tiles west of the line and the hazards and flotsam beside it where the host has them

#### Scenario: A client sees a leak plugged
- **GIVEN** a host and a client riding a raft with one open leak
- **WHEN** the client holds interact on the leak for 2 s
- **THEN** the host plugs it and both peers show it plugged

#### Scenario: Solo sends nothing
- **GIVEN** a 1-player run, offline, whose player paddles, plugs a leak, takes a coconut and shoos the shark
- **WHEN** the crossing runs to its end
- **THEN** every change applied and nothing was sent to anyone
