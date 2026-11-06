# Spec Delta

## MODIFIED Requirements

### Requirement: Routes
The game SHALL implement these routes: raft, repair-wreck, turtle, binoculars-swim, tarp-sail, dolphins, signal-boat, gulf-stream, almendron, tabla, with the requirements in `docs/GAME_DESIGN.md` §7 (which gains the almendrón and board rows).

#### Scenario: Turtle capacity
- GIVEN a party of 4 and a freed, fed turtle
- WHEN two players board her
- THEN the route starts for those two only; the other two remain on the island with the other routes available

### Requirement: Weather gating
Tarp-sail SHALL require trade wind; binoculars-swim SHALL require clear weather and energy ≥ 100 for each swimmer; signal-boat SHALL only succeed in the first hour after dusk or the last before dawn; the board (tabla) SHALL require trade wind. (Changes docs/GAME_DESIGN.md §7.)

#### Scenario: Tarp-sail without trade wind
- GIVEN a party with everything else the tarp-sail route needs
- WHEN the weather is calm
- THEN the route cannot start

#### Scenario: Solo board in calm weather
- GIVEN a 1-player run, a player carrying one `tabla_vela` and no bleeding status
- WHEN the player activates the board in calm weather
- THEN the route does not start and the board is not used up; when the weather turns to trade wind, activating it starts the route

## ADDED Requirements

### Requirement: Almendrón route
The almendrón SHALL be a build-site route (capacity all) on a car wreck: recipe `almendron_flotante` (4 drums, 4 rope, 6 nails, 4 driftwood, 1 propeller; pliers; 90 s base, 1 energy/s per worker). Each crossing SHALL spend one fuel jug. Starting it makes noise in 25 tiles with a 50% patrol alert, sets `almendron_a_bordo` and gives the starter a botija; the car stays beached with its integrity.

#### Scenario: Solo builds and starts it
- GIVEN a 1-player run, a non-Mecánico at energy 100 on `coast_village` with the almendrón rolled, who takes the pliers, propeller, 6 nails, 2 rope and 2 drums at the car, 2 more rope and 4 driftwood found in flotsam and along the beach, 2 drums at the fishermen's houses and 1 fuel jug at the dock
- WHEN the player works the build site alone, with the pliers' ×1.5, and then starts it
- THEN it completes in 60 s using 60 energy, the jug is spent, a 25-tile noise is made, the flag `almendron_a_bordo` is set, and the player holds a botija

#### Scenario: Fuel is contested
- GIVEN a party whose only fuel jug is also one of the 2 jugs Caridad's lamp needs
- WHEN the jug goes into the car
- THEN the lamp quest still needs 2 jugs from elsewhere; no rule makes the jug free

### Requirement: Almendrón capture
When a party that used the almendrón (`almendron_a_bordo` set) is captured and persuasion fails, `la_captura` SHALL play the car variant and set `almendron_hundido`, and the chain rows that offer the almendrón SHALL require `almendron_hundido` unset. The guardacostas-stealth Capture outcome is not changed: the previous island still regenerates from the run seed.

#### Scenario: Solo captured after using the car
- GIVEN a 1-player run that crossed in the almendrón from `coast_village` and is captured on the next island with persuasion failing
- WHEN `coast_village` is regenerated from the run seed
- THEN `almendron_hundido` is set, the island offers no almendrón route, and the raft is still offered

### Requirement: Board route
The board SHALL be an item-use route (capacity one per rider): each rider spends their own `tabla_vela` (board, tarp, hardwood and 2 rope crafted at a workbench, 60 s) and must not be bleeding; the route needs trade wind. Its starter POI `caseta_alquiler` always holds at least one board, a tarp, a hardwood and 2 rope, so one player can finish it.

#### Scenario: Solo rider
- GIVEN a 1-player run on `storm_resort` with the board rolled and trade wind
- WHEN the player takes a board, a tarp, a hardwood and 2 rope from the shack, crafts the sail and activates it
- THEN the route starts for that player only and the `tabla_vela` is used up

#### Scenario: Co-op riders with a spare board
- GIVEN a party of 3 with 2 boards rigged, one member who cannot swim and one who refuses boards
- WHEN the route starts
- THEN only the two rigged riders go; the others stay with the other routes available

### Requirement: Rolled routes are never the guarantee
The almendrón and the board SHALL be rolled chain-route rows (almendrón: `coast_village` 0.6, `storm_resort` 0.8; board: `storm_resort` 1.0, `mangrove_maze` 0.4, `wreck_yachts` 0.5), never an island's only route. A rolled row forces its starter POI onto the island. The raft stays guaranteed.

#### Scenario: Solo island with a rolled board
- GIVEN an island set up for 1 living player on `wreck_yachts` where the board is rolled
- WHEN the island is generated
- THEN the raft is still offered, `caseta_alquiler` is on the island with its tarp, hardwood and rope, and the island-generation solo guarantee is met by the raft
