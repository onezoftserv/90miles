## MODIFIED Requirements

### Requirement: Land edges
A land layer's tile SHALL be picked from the state of its cell's four corners, a corner counting as land when all four cells that share it are land, so straight shores, outer and inner corners, diagonal touches and a lone land cell all join without gaps. A land tile's water side is transparent over the sea, with no water or foam of its own. Each layer counts its own kinds and those of the layers on it as land: sand every land kind, dune both dune and scrub, brush scrub only.

#### Scenario: Inner corner
- **GIVEN** a land cell whose only water neighbour is to its north-west
- **WHEN** its tile is picked
- **THEN** it gets the inner-corner tile with water at its north-west corner

#### Scenario: Lone land cell
- **GIVEN** a land cell with water on all eight sides
- **WHEN** its tile is picked
- **THEN** it gets the islet tile, land inside the cell and water at all four corners

#### Scenario: Scrub inside a dune
- **GIVEN** a scrub cell whose eight neighbours are all dune
- **WHEN** its dune and brush tiles are picked
- **THEN** the dune layer gives it the full tile and the brush layer the islet tile

#### Scenario: No water in land tiles
- **GIVEN** every tile of the sand, dune and brush corner sets
- **WHEN** the art check reads their pixels
- **THEN** none holds an opaque colour of the sea or foam ramps

#### Scenario: Coast corners are rounded
- **GIVEN** the sand tiles of an outer corner (one land corner), an inner corner (one water corner) and a diagonal (two opposite water corners)
- **WHEN** their pixels are read
- **THEN** the outer corner's sand ends in a quarter arc round its land corner, and each water corner of the others is a rounded bite about 4 px deep, with no right-angle step inside the tile
- **AND** each tile's sand meets the cell's border where the straight edge tiles' sand meets it, so neighbouring tiles join without a jog

#### Scenario: A walkable cell's middle is drawn as land
- **GIVEN** the sandbar built for one offline player
- **WHEN** the sand tile of each of its shore cells is read
- **THEN** the pixel of the tile's centre four that lies toward the cell's land is drawn, so no walkable cell's middle shows the sea

#### Scenario: The beach has the same lip on every side
- **GIVEN** the sand tiles of the four straight edges and of the corners
- **WHEN** the sand pixels beside the sea are read
- **THEN** every side ends in the same 1 px lip colour, and no side ends in a darker ledge band

#### Scenario: A bush on a shore cell is drawn whole
- **GIVEN** a scrub cell on the sandbar's shore, built for one offline player
- **WHEN** its brush tile is drawn
- **THEN** the bush is whole, every one of its pixels on the sand under it, with no straight cut line and no dark rim on its water side
- **AND** where the small bush cannot fit on the sand, a smaller hand-drawn tuft stands there, whole

### Requirement: Scrolling sea
Water cells SHALL show one moving sea under the land layers: a seamless water texture drifting at a constant speed, with shallows drawn a palette step lighter than deep water and brackish water in a step of its own, every colour on the master palette. The steps SHALL meet in a curved line that does not follow the cell squares, and each water cell's centre is drawn in its own step while the line is at rest. The sea's motion comes from its own clock and never from simulation state.

#### Scenario: Shallows read lighter than deep water
- **GIVEN** a shallows cell beside a deep cell
- **WHEN** the sea is drawn
- **THEN** the shallows cell's colours are the lighter step and the deep cell's the darker one, both from the master palette

#### Scenario: The sea moves on its own
- **GIVEN** a solo game on the sandbar with the player standing still
- **WHEN** two frames are drawn a second apart
- **THEN** the water texture has moved and no cell has changed its terrain

#### Scenario: The deep edge is soft and every cell keeps its step
- **GIVEN** the sandbar and the coast cay built for one offline player
- **WHEN** the sea's depth mask is read at each water cell's centre, with the line at rest
- **THEN** every deep, shallows and brackish cell's centre shows its own step
- **AND** between a deep cell and a shallows cell beside it the mask is graded, not a step at the cell border, so the line rounds the corners of the coast instead of copying them

### Requirement: Shoreline overlay
Every shore cell, a land cell whose sand tile has at least one water corner, SHALL get an animated foam overlay picked by the same corner state and drawn on the line where its sand tile meets the sea, so each shore has exactly one foam line and it touches the sand. Water cells get no foam. The foam cycles through 8 frames, each cell starting at its own frame, so the shore never pulses all at once.

#### Scenario: Edges and corners
- **GIVEN** three land cells: one with water only on its three southern neighbours, one with water only at its south-east diagonal, and one with land only to its north, north-west and west
- **WHEN** the shoreline overlay is built
- **THEN** the first gets a straight foam edge on its south side, the second a concave foam corner at its south-east, the third a convex foam corner facing south-east, and no water cell gets foam

#### Scenario: Foam meets the sand
- **GIVEN** the straight sand edge tile and the straight foam edge on the same cell
- **WHEN** they are drawn
- **THEN** the foam starts on the row where the sand ends, with no gap and no second foam line

#### Scenario: Corner foam is no heavier than a straight run
- **GIVEN** the foam of every corner and diagonal tile, in every frame
- **WHEN** the white pixels in each 8×8 patch of a frame are counted
- **THEN** no patch is more than half white, the outer diagonal of an outer corner fades out of white, and the straight edges' foam is unchanged

### Requirement: Seeded cosmetic variants
Decorative variants (sand speckles, shell tufts, foam starting frames) SHALL be chosen from a hash of the island layout's id and the cell, never from a random generator the simulation uses, so every peer and every rebuild of the same layout shows the same variants and drawing never shifts a simulation roll.

#### Scenario: Same layout, same variants
- **GIVEN** the sandbar built twice in one process and once on a client
- **WHEN** the variants are compared
- **THEN** every cell has the same variant all three times, and the creature spawner's next roll is the same as with no art built

#### Scenario: Neighbouring cells are not striped
- **GIVEN** a 16×16 block of cells of one layout, each picking one of four variants
- **WHEN** each cell's pick is compared with its north-east neighbour's, and cell (x, y)'s with cell (y, x)'s
- **THEN** fewer than 40% of the cells share their north-east neighbour's pick, and the mirrored pairs do not always share theirs
