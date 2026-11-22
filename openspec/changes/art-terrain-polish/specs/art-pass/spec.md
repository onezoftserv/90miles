## ADDED Requirements

### Requirement: Land and water read apart by value
The beach and the dune SHALL stand apart from the shallows by value, not by hue alone: the mean colour of the sand ground and of the dune ground SHALL each reach a contrast ratio of at least 1.6:1 with the mean colour of the shallows, the shallows staying lighter than deep water and brackish water lying between them, every colour on the master palette. The sand's 1 px wet lip SHALL show at the water's edge below the foam. The threshold is art tuning data, and a solo player sees the same coast.

#### Scenario: The coast reads in greyscale
- **GIVEN** the art tuning's ground means for sand, dune, shallows, brackish and deep
- **WHEN** their contrast ratios are computed
- **THEN** sand and dune each reach at least 1.6:1 against the shallows, shallows against brackish at least 1.4:1, and deep is darker than brackish and brackish darker than the shallows

#### Scenario: The wet lip shows below the foam
- **GIVEN** the straight sand edge tiles and their foam pieces
- **WHEN** each of the 8 foam frames is laid over its sand tile
- **THEN** the sand's last opaque row, its lip, is covered by no foam pixel in at least 4 of the 8 frames, while the foam still touches the sand in every frame (on the lip or the water pixel beyond it)

#### Scenario: A solo player's beach on the sandbar
- **GIVEN** the sandbar built for one offline player
- **WHEN** the sea's shallows step and the sand tiles under its shore cells are read
- **THEN** the shallows use the darkened ramp, every colour is on the master palette, and the swimmer's and the fin's contrast checks against shallows and deep still pass

### Requirement: A palm stands in its dune
A palm cell SHALL be drawn on the dune layer when at least 3 of its 4 orthogonal neighbours are dune or scrub, so the dune round it keeps its corners, and SHALL never be drawn on the brush layer. Walking, climbing and hiding treat the palm's cell as before. A solo player sees the same.

#### Scenario: A palm on the dune's edge
- **GIVEN** the sandbar built for one offline player, whose palm at (23, 31) has dune or scrub on all four orthogonal sides and beach at its south-east diagonal
- **WHEN** its dune tile is picked
- **THEN** the palm's cell is on the dune layer with corner mask 7, and the dune cells beside it keep the corner they lost before

#### Scenario: A palm out on the beach
- **GIVEN** a palm with only one dune neighbour
- **WHEN** the dune and brush layers are built
- **THEN** the palm's cell is on neither, and its sand tile is unchanged

#### Scenario: Enclosed palms are whole dune
- **GIVEN** a handmade layout and every palm in it whose eight neighbours are all dune or scrub
- **WHEN** their dune tiles are picked
- **THEN** each takes the full dune tile, mask 15

### Requirement: Dune corners are rounded
The dune layer's corner tiles SHALL be rounded like the beach's. An outer dune corner ends in a quarter arc round its dune corner; an inner corner, and each side of a diagonal, ends in a rounded bite as deep as the straight edges allow. Neighbouring dune tiles join without a jog. The straight edges, their tufts and the hand-drawn islet stay as they are. A solo player sees the same dune.

#### Scenario: Dune corners have no stair step
- **GIVEN** the dune tiles of the outer corners, the inner corners and the two diagonals
- **WHEN** their pixels are read
- **THEN** each outer corner's dune lies on a quarter ellipse round its dune corner, reaching along the two border strips as far as today's straight edges do, at most 4 px off it; and each inner corner and diagonal side ends in a bite at least 2 px deep along the diagonal
- **AND** every pair of dune tiles that can sit side by side meets at the cell border without a jog, and the straight edges and the islet are unchanged

#### Scenario: The sandbar's dunes, solo
- **GIVEN** the sandbar built for one offline player
- **WHEN** the dune tile of each dune cell with a corner or diagonal mask is read
- **THEN** it is one of the rounded tiles, and its four corner pixels still say which of its corners are dune

### Requirement: Scrub varies
Whole scrub cells SHALL show one of several bush picks chosen by the cell's hash, which share their four corner quarters with the plain full tile so neighbours join and differ only inside, with no sand showing between the lobes; shore scrub cells SHALL show one of two or three whole bushes chosen the same way, each placed on the sand as wave 1's fit places it. Every pick is on the master palette with a 1 px outline. A solo player sees the same picks every build.

#### Scenario: A block of scrub is not wallpaper
- **GIVEN** the secret cay's (`cayo_sin_norte`) scrub block built for one offline player
- **WHEN** the brush tile of each whole scrub cell is picked
- **THEN** more than one pick is used, and every pick's four corner quarters are identical to the full tile's

#### Scenario: Shore bushes vary and stay whole
- **GIVEN** the sandbar's shore scrub cells
- **WHEN** their brush shore tiles are read
- **THEN** at least two different whole bushes are used, and every bush pixel lies on the sand under it

#### Scenario: No hole in a bush
- **GIVEN** every brush pick
- **WHEN** its pixels inside the bush's outline are read
- **THEN** none is transparent and none is a sand colour

### Requirement: The beach shows no grid
The beach SHALL be drawn in one sand tone without the pack's diagonal stripes, its whole cells showing one of four distinct picks (none a mirror of another) chosen by the cell's hash with weights from art data, about 70% of cells taking the clean pick, so no pattern repeats on the 16 px grid. The dune's lip stays 1 px. A solo player sees the same beach every build.

#### Scenario: The picks are weighted
- **GIVEN** the sandbar built for one offline player
- **WHEN** the sand picks of its whole sand cells are counted
- **THEN** between 60% and 80% of them take the clean pick, and every peer and rebuild gives the same picks

#### Scenario: No stripes
- **GIVEN** the sand tiles of every mask
- **WHEN** their fill pixels are read
- **THEN** none holds the second stripe tone, and the four picks differ from each other and from each other's mirror images

### Requirement: The rocky point has an edge
Rock SHALL be drawn with a dark 1 px outline, its seam with the sand softened by a ragged edge and small pebble decals, a 1 px lit lip on its north edge, and a low face only where it meets the water, lower and lighter than the cliff's, so it reads as a low rock shelf, never a drop. Pebbles never block or change movement. A solo player sees the same point.

#### Scenario: The rock meets the water
- **GIVEN** the coast cay built for one offline player, and a rock cell from its layout with water to its south
- **WHEN** its tile is picked
- **THEN** it takes the plain shore sheet's rock tile, whose rows above the water hold the face, and the face is shorter and lighter than the cliff's

#### Scenario: The seam is not a ruler
- **GIVEN** every sand cell beside rock on the coast cay
- **WHEN** the decals are built
- **THEN** pebble decals lie on some of them, chosen by the cell's hash, no pebble is larger than 8×6, and no cell's terrain or walkability changes

## MODIFIED Requirements

### Requirement: Shoreline overlay
Every shore cell, a land cell whose sand tile has at least one water corner, SHALL get a foam overlay picked by the same corner state and drawn on the line where its sand tile meets the sea, so each shore has exactly one foam line and it touches the sand. Water cells get no foam. Where the shore meets open water, a water body that holds a deep cell, the foam is animated: it cycles through 8 frames, each cell starting at its own frame, so the shore never pulses all at once. Where every water cell beside a shore cell belongs to still water, a body with no deep cell such as an enclosed lagoon, the cell gets a still piece instead: a thin wet line on the same edge that does not move.

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
- **THEN** no patch is whiter than the whitest patch of a straight edge's foam, an inner corner's patches are at most half white and an outer corner's about half
- **AND** where the shore turns the foam fades from its second step out, and the straight edges' foam is unchanged

#### Scenario: A still lagoon has a still edge
- **GIVEN** the coast cay built for one offline player, and its brackish lagoon found from the layout as a water body with no deep cell
- **WHEN** the shoreline overlay is built
- **THEN** every shore cell whose water neighbours all lie in the lagoon gets the still piece, whose frames are all the same, and every shore cell beside the open sea keeps the animated foam
- **AND** the number of shore cells on each island is unchanged

### Requirement: Tide pools and contact shade
Tide pools SHALL be drawn as rock-pool tiles on their cells, which the sand layer and the shoreline count as land, so a pool gets no foam ring; and the ground at the foot of each palm, the workbench and a layout's shaded cells (under the sandbar's lean-to, round the coast cay's watch post) SHALL get a soft shade decal, so tall things sit on the ground. The raft site's shade comes with its stage ("Raft site and raft"), never from a decal on bare sand. Decals never block or change movement. A solo player sees the same pools and shade.

#### Scenario: Pools and shade on the sandbar
- **GIVEN** the sandbar's three tide pools and six palms
- **WHEN** the island is drawn
- **THEN** each pool cell shows a rock-pool tile and each palm base has a shade decal under it

#### Scenario: No shade on an empty raft site
- **GIVEN** the sandbar built for one offline player, its raft site only marked
- **WHEN** the decals are built
- **THEN** no shade decal lies on or beside the raft site's cells, and the workbench's cell still has its shade

### Requirement: Raft site and raft
The raft build site SHALL show its stage: a staked outline while empty, the deposited materials once any are in, and a half-built frame from half its work; once built, the raft replaces it. The raft SHALL be one 64×32 sprite set used on the beach, a beached raft included, and as the crossing deck: whole above 66 integrity, worn from 66, breaking from 33; at 0 the deck sinks at once and no raft is drawn. On the beach, the site's frames and the raft are drawn shifted toward the land beside the site by an art-data offset, so the hull rests on the sand, and the half-built frame and the raft have a wide soft shadow under the hull while the marked site and its materials have none; the structure itself, its interaction and the crossing deck do not move. With exactly 1 player the same stages show.

#### Scenario: A solo build
- **GIVEN** a solo player at the empty raft site
- **WHEN** they deposit every material, work half the build and then finish it
- **THEN** the site shows the outline, then the materials, then the half-built frame, and then the whole raft in its place

#### Scenario: Damage states
- **GIVEN** a raft on the crossing at integrity 100
- **WHEN** it drops to 60, to 30 and to 0
- **THEN** the deck shows worn, then breaking, and then no deck, because it sank

#### Scenario: The hull rests on the sand
- **GIVEN** the sandbar and the coast cay built for one offline player, each with a built raft at its site
- **WHEN** the raft's look is drawn
- **THEN** its frame is moved toward the land beside the site by the art data's offset, the opaque pixels of its bottom rows lie over land cells, and the structure's own position is unchanged

#### Scenario: The shadow follows the stage
- **GIVEN** a solo player's raft site
- **WHEN** it is marked, holds materials, is half built and is built
- **THEN** it has no shadow while marked or holding materials, and the wide shadow under the hull once half built and once it is the raft

#### Scenario: The crossing deck does not move
- **GIVEN** a solo raft crossing
- **WHEN** the deck is drawn
- **THEN** it stands on the crossing's deck rect exactly as before, with no beach offset
