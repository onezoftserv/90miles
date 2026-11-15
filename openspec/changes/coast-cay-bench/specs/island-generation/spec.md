## ADDED Requirements

### Requirement: Coast cay workbench
The coast cay SHALL hold one workbench, a flat rock placed by its layout data (this changes `docs/ISLANDS.md` §2, "no workbench"). It lies on an unshaded beach cell on the bay side of the west arm, the lee arm, beside the landing, on no other feature's cell. It is reachable on foot from every landing cell, within a 1–4 s walk of the first one at 4 tiles/s. Moving it needs only a data change. Exactly 1 player, offline, reaches it alone.

#### Scenario: The bench is data
- **GIVEN** the coast cay layout file
- **WHEN** the island is built
- **THEN** it has one workbench on an unshaded beach cell that holds no palm, pick-up, sign, spawn point, drinking spot or raft site
- **AND** the observation post's cells are still the only shaded cells, and the land count is unchanged

#### Scenario: A lone arrival reaches the bench
- **GIVEN** the built coast cay and one offline player on the first landing cell, walking at 4 tiles/s
- **WHEN** paths over land and shallows are checked from every landing cell and the shortest walk is measured
- **THEN** the bench can be reached from every landing cell, and it is 1–4 s from the first

### Requirement: Coast cay workbench out of the patrol's sight
The coast cay's workbench SHALL stand where a fire placed at it is hidden from the patrol at night. Every land cell within 2 tiles of it is more than 2 tiles from the sea (guardacostas-stealth smoke rule), and the bench and the 8 cells round it lie outside the searchlight's sweep for a whole lap (guardacostas-stealth design decisions 3–5). A day fire there is still seen. Exactly 1 player is covered the same way.

#### Scenario: No night smoke from the bench
- **GIVEN** the built coast cay, with the sea as deep or shallow water joined to the map edge
- **WHEN** the distance to the sea is measured from every land cell within 2 tiles of the bench
- **THEN** every one is more than 2 tiles

### Requirement: Fire at the coast cay's workbench
A player within reach of the coast cay's workbench SHALL be able to place fire and rain-catcher sites there, as at any workbench (crafting-inventory "Workbench", "Placing a build site"). The bench, and what is built at it, SHALL reach every peer. Exactly 1 player, offline, places and lights a fire there alone.

#### Scenario: A solo player lights a fire at the coast cay's bench
- **GIVEN** one offline player who has landed on the coast cay, carrying one dry grass from the sandbar
- **WHEN** they take the lighter from the rope cache and 3 driftwood from the beach, choose the fire at the bench, deposit everything and work the site
- **THEN** there is no fire at 0.9 s, one lit fire stands at 1 s within 2 tiles of the bench, and the lighter has 19 uses left

#### Scenario: The bench and its fire on a client
- **GIVEN** a host and a client whose party has travelled to the coast cay
- **WHEN** the client's player places a fire site at the bench, and the fire is built
- **THEN** the client's bench stands where the host's does, on the layout's bench cell, and the client's copy of the fire is lit where the host's is
