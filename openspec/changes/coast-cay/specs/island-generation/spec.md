## ADDED Requirements

### Requirement: Handmade coast cay
The second island of every run SHALL be the handmade coast cay (*el cayo de la costa*, `docs/ISLANDS.md` §2, base variant), read from a layout data file, not generated: beach, dunes, a rocky point and a small brackish lagoon, larger than the 640×360 view, with 1,000–1,150 land cells (16–22% of its cells) and no land cell more than 6 tiles from water. Its long axis is about 60 tiles. The layout names its chain family (coast) and no next island yet. Exactly 1 player changes none of this.

#### Scenario: The coast cay is data
- GIVEN the coast cay layout file
- WHEN the island is built
- THEN it is larger than 640×360 px, it has 1,000–1,150 land cells, 16–22% of its cells are land, no land cell is more than 6 tiles from water, and its chain family is coast

### Requirement: Coast cay landing
The coast cay SHALL have a landing of 4 beach cells, every pair at most 5 tiles apart, read from its layout; players land on them in join order, and the first is also where a lone arrival stands. Moving or adding a point of interest, a pick-up or the landing SHALL need only a data change. Exactly 1 player lands alone on the first cell.

#### Scenario: The landing
- GIVEN the built coast cay
- WHEN its landing cells are read
- THEN there are 4, all beach, every pair at most 5 tiles apart, and the first is where a lone arrival stands

### Requirement: Coast cay contents
The coast cay SHALL hold the observation post on the rocky point (4 nails, 1 mirror; a dead radio and two wall slogans as signs; the only shade), the lagoon, 4 aloe on a dune, a rope cache on the north dune (4 rope, 1 lighter, a crossed-stick sign), a flotsam line (2 inner tubes, 2 plastic jugs), 8 driftwood, 5 palms with 10 coconuts and the raft build site. Flotsam and driftwood return after a squall. Counts are fixed, not scaled by party size.

#### Scenario: The coast cay loads
- GIVEN the coast cay layout file
- WHEN the island is built
- THEN it has 5 palms holding 10 coconuts, its pick-ups are 4 nails and 1 mirror at the post, 4 aloe on the dune, 4 rope and 1 lighter in the cache, 2 inner tubes and 2 plastic jugs on the flotsam line and 8 driftwood on the beach, it has 4 signs (the radio and two slogans at the post, and the crossed-stick sign), one lagoon drinking spot and one raft build site, and the post's cells are the only shaded cells

### Requirement: Coast cay reach
Every pick-up, palm, sign, the lagoon shore and the raft build site on the coast cay SHALL be reachable on foot or wading from every landing cell, and a lone arrival's walks SHALL fit the bands below, so exactly 1 player, offline, can reach and take all of it and build a raft alone.

#### Scenario: Everything is in reach of a lone arrival
- GIVEN the built coast cay
- WHEN paths over land and shallows are checked from every landing cell
- THEN every palm, pick-up, sign, the lagoon drinking spot and the raft build site can be reached

#### Scenario: A lone arrival's walks
- GIVEN one offline player on the first landing cell, walking at 4 tiles/s
- WHEN the shortest walk over land and shallows is measured
- THEN the raft build site is 0.5–3 s away, the flotsam line 2–7 s, the lagoon drinking spot 4–9 s, the aloe 7–13 s, the rope cache 9–15 s and the observation post 13–19 s

#### Scenario: A solo player builds a raft on the cay
- GIVEN one offline player on the coast cay
- WHEN they take the nails and mirror, 2 inner tubes, 6 driftwood and the 4 rope and build at the raft site
- THEN a raft stands at integrity 100 and nobody else was needed

### Requirement: Drinking from the lagoon
A player SHALL drink from the coast cay's lagoon by holding interact on its shore for the timed-interaction hold (2 s): the host raises their thirst by 10 at once and lowers it by 5 thirty seconds later (`docs/ISLANDS.md` §2, brackish). The effects are the layout's data. The lagoon never runs dry (confirmed by the owner, 2026-11-08). A brackish drink is not a fresh-water cup and never revives. Exactly 1 player, offline, drinks the same way.

#### Scenario: A solo player drinks brackish water
- GIVEN one offline player on the coast cay at thirst 50 with thirst drain stopped
- WHEN they hold interact at the lagoon shore for 2 s
- THEN their thirst is 60 at once and 55 after 30 more seconds, and a fifth drink works as the first did

### Requirement: Flavour signs
A layout MAY list signs: a glyph with a Spanish and an English line. A player who interacts with a sign SHALL see its line in a speech bubble over it, in the game's language, on every peer; reading changes nothing else. The observation post's dead radio and wall slogans, and the cache's crossed sticks, are signs; their lines satirise the system and daily life and never quote a real person. Exactly 1 player, offline, reads them the same way.

#### Scenario: A solo player reads the wall
- GIVEN one offline player beside a wall slogan on the coast cay, language Spanish
- WHEN they interact with it
- THEN a speech bubble shows the slogan's Spanish line and the player's inventory and meters are unchanged

### Requirement: Any handmade layout builds the island
The island scene SHALL build whatever handmade layout it is given before it enters the tree (terrain, palms, pick-ups, markers, bounds, drinking spots, signs), so the sandbar and the coast cay share one scene and one code path, and the creature spawner reads the layout's chain family. With exactly 1 player nothing differs.

#### Scenario: The island scene builds the coast cay
- GIVEN the island scene with the coast cay layout set before it enters the tree
- WHEN it is built
- THEN its terrain, bounds and palms are the coast cay's, not the sandbar's
