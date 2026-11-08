## MODIFIED Requirements

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
