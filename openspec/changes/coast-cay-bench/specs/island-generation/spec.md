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
A player within reach of the coast cay's workbench SHALL be able to place fire and rain-catcher sites there, as at any workbench (crafting-inventory "Workbench", "Placing a build site"). The cay holds everything a fire needs: the cache's lighter, the beach's driftwood and its own dry grass. The bench, and what is built at it, SHALL reach every peer. Exactly 1 player, offline, places and lights a fire there alone with what the cay holds.

#### Scenario: A solo player lights a fire at the coast cay's bench
- **GIVEN** one offline player who has landed on the coast cay carrying nothing
- **WHEN** they take the lighter from the rope cache, 3 driftwood from the beach and 1 dry grass from the dune beside the bench, choose the fire at the bench, deposit everything and work the site
- **THEN** there is no fire at 0.9 s, one lit fire stands at 1 s within 2 tiles of the bench, and the lighter has 19 uses left

#### Scenario: The bench and its fire on a client
- **GIVEN** a host and a client whose party has travelled to the coast cay
- **WHEN** the client's player places a fire site at the bench, and the fire is built
- **THEN** the client's bench stands where the host's does, on the layout's bench cell, and the client's copy of the fire is lit where the host's is

## MODIFIED Requirements

### Requirement: Coast cay contents
The coast cay SHALL hold the observation post on the rocky point (4 nails, 1 mirror; a dead radio and two wall slogans as signs; the only shade), the lagoon, 4 aloe on a dune, a rope cache on the north dune (4 rope, 1 lighter, a crossed-stick sign), a flotsam line (2 inner tubes, 2 plastic jugs), 8 driftwood, 2 dry grass on the dune beside the workbench, 5 palms with 10 coconuts and the raft build site. This changes the counts in `docs/ISLANDS.md` §2, which listed no dry grass. Flotsam and driftwood return after a squall; the dry grass does not. Counts are fixed, not scaled by party size. Exactly 1 player finds the same counts.

#### Scenario: The coast cay loads
- GIVEN the coast cay layout file
- WHEN the island is built
- THEN it has 5 palms holding 10 coconuts, its pick-ups are 4 nails and 1 mirror at the post, 4 aloe on the dune, 4 rope and 1 lighter in the cache, 2 inner tubes and 2 plastic jugs on the flotsam line, 8 driftwood on the beach and 2 dry grass on the dune within 3 tiles of the workbench, it has 4 signs (the radio and two slogans at the post, and the crossed-stick sign), one lagoon drinking spot and one raft build site, and the post's cells are the only shaded cells
