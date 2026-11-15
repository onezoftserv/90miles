# Spec Delta

## ADDED Requirements

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
