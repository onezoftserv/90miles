# Spec Delta

## MODIFIED Requirements

### Requirement: Crossing scene
A crossing SHALL be its own scene with a vertically scrolling sea, the vessel (raft, boat, car, one board per rider, turtle, swimmers), and threat spawns rolled from the route's risk profile, distance band and current weather.

#### Scenario: Crossing loads from the route
- GIVEN a route that starts a crossing
- WHEN the crossing scene loads
- THEN the sea scrolls vertically with the party's vessel, and threat spawns are rolled from that route's risk profile, its distance band and the current weather

#### Scenario: Solo board crossing
- GIVEN a 1-player run whose player starts the board route
- WHEN the crossing scene loads
- THEN it shows one board with its rider, and no second vessel

### Requirement: Vessel integrity
Rafts and boats SHALL have integrity (raft 100, repaired boat 200, almendrón 160, board 60 per rider). Squalls −30 (−45 for the almendrón), shark hit −20, rock −40. At 0, the vessel breaks: players fall in and must swim the remainder (energy permitting) or drown. A board that breaks drops only its own rider. (Changes docs/GAME_DESIGN.md §8.)

#### Scenario: Raft breaks
- GIVEN a raft at integrity 100
- WHEN it takes a squall (−30), a rock (−40) and a second squall (−30)
- THEN integrity is 0, the raft breaks and the players fall in

#### Scenario: Almendrón in a squall
- GIVEN an almendrón at integrity 160
- WHEN it takes a squall and then a shark hit
- THEN integrity is 160 − 45 − 20 = 95

#### Scenario: Solo board breaks
- GIVEN a 1-player run, a board at integrity 60 whose rider takes a rock (−40) and a shark hit (−20)
- WHEN integrity reaches 0
- THEN the board breaks and the rider swims the rest of the crossing

### Requirement: Arrival
On arrival, players SHALL spawn on the next island's beach scattered within the route's arrival scatter (default 0–5 tiles; board riders 10–20), the vessel beached with its remaining integrity (reusable if intact) unless the route says it is lost (the board). (Changes docs/GAME_DESIGN.md §8.)

#### Scenario: Raft arrives damaged
- GIVEN a raft that ends the crossing with integrity 40
- WHEN the party arrives
- THEN the players spawn on the next island's beach within 5 tiles of each other and the raft is beached there with integrity 40

#### Scenario: Solo board rider lands
- GIVEN a 1-player run whose rider ends a board crossing with the board at integrity 30
- WHEN the player arrives
- THEN the player spawns on the beach, the board is gone, and nothing is left to find

#### Scenario: Co-op board riders land apart
- GIVEN 3 riders who start the board route together
- WHEN they arrive
- THEN each lands 10–20 tiles from the others

## ADDED Requirements

### Requirement: Car and board profiles
The almendrón crossing SHALL last 60–90 s at speed ×1.4, drift ×0.5, sharks ×0.6, threats ×1.2. The board crossing SHALL last 60–70 s at speed ×1.8, drift ×1.5, sharks ×1.3, threats ×0.7 and never alerts a patrol. A squall or shark attack dumps a board rider, who climbs back by the Fall in and rescue rule. Durations and speeds are provisional until review item 29 sets them per band.

#### Scenario: Solo rider dumped
- GIVEN a 1-player run, a board rider at integrity 60 hit by a shark
- WHEN the rider falls in and holds interact for 3 s at the board's edge
- THEN the board is at 40 and the rider is aboard again, with no teammate needed

#### Scenario: Almendrón stays inside the range
- GIVEN an almendrón crossing rolled at its longest
- WHEN the crossing runs to its end
- THEN it lasted 90 s, inside the 60–120 s range of `docs/GAME_DESIGN.md` §8
