## ADDED Requirements

### Requirement: Coast cay coastline
The coast cay's coast SHALL bend and step rather than run in ruler lines (this replaces `docs/ISLANDS.md` §2's "a C of two 12-wide strips and a rocky spur round shallow flats"). No more than 10 consecutive land cells along one row or column have water (deep, shallows or brackish) on the same side, and the rock meets the sand in no straight seam longer than 10 cells. The shallows ring keeps its width. Exactly 1 player, offline, finds the same coast.

#### Scenario: No ruler-straight coast
- **GIVEN** the coast cay layout file, built for one offline player
- **WHEN** every row and column is scanned for land cells with water on the same side, and for rock cells with beach, dune or scrub on the same side
- **THEN** no such run is longer than 10 cells

### Requirement: Coast cay rocky point
The coast cay's rocky point SHALL narrow toward its southern tip: each of its southmost three rows is at most half as wide, in rock cells, as its widest row. The observation post keeps its cells and has rock on all four sides. Exactly 1 player, offline, finds the same point.

#### Scenario: The rocky point narrows round the post
- **GIVEN** the built coast cay
- **WHEN** the rock cells of the rocky point are counted row by row
- **THEN** each of its southmost three rows holds at most half as many rock cells as its widest row
- **AND** every cell next to the observation post's block, on all four sides, is rock

### Requirement: Coast cay driftwood and scrub
The coast cay's 8 driftwood SHALL lie in groups of 1 to 3 (pieces within 2 tiles of each other are one group), with no more than 3 on any row or column. Its scrub SHALL grow in clumps: every 8-connected clump holds at least 4 scrub cells and a 2×2 block of scrub, and the cay holds 25 to 45 scrub cells, so its cover stays about what it was. Exactly 1 player, offline, finds the same groups.

#### Scenario: Driftwood and scrub in groups
- **GIVEN** the built coast cay
- **WHEN** its driftwood and scrub cells are read
- **THEN** no group of driftwood holds more than 3 pieces, no row or column holds more than 3 driftwood, there are 25 to 45 scrub cells, and every clump of scrub holds at least 4 cells and a 2×2 block

### Requirement: Coast cay pick-ups off outer corners
No pick-up, palm or sign on the coast cay SHALL stand on an outer corner of the coast: each stands on a cell with at least two land corners, a corner counting as land when all four cells that share it are land. Exactly 1 player, offline, finds them the same way.

#### Scenario: Nothing stands on an outer corner
- **GIVEN** the built coast cay
- **WHEN** the four corners of every pick-up's, palm's and sign's cell are read
- **THEN** each of those cells has at least two land corners

### Requirement: Coast cay reshape keeps its places
Reshaping the coast cay SHALL keep the cells of its landing, raft site, workbench and dry grass, observation post, rope cache, aloe, lagoon and drinking spot, and every rule of its other requirements: the land band, counts, reach, walk bands and the workbench's patrol and smoke rules. Changing the outline needs only a data change. Exactly 1 player, offline, reaches everything and builds a raft alone.

#### Scenario: A lone arrival on the new outline
- **GIVEN** the reshaped coast cay built for one offline player, standing on the first landing cell
- **WHEN** the shortest walks over land and shallows are measured at 4 tiles/s and the player gathers alone
- **THEN** every walk band of "Coast cay reach" holds, the workbench is a 1–4 s walk, and with the nails, the mirror, 2 inner tubes, 6 driftwood and the 4 rope the player builds a raft at integrity 100 with nobody else
