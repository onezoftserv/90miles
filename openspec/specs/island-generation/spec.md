# island-generation

## Purpose
Procedural islands from chain templates, with biome bands, POIs and escape routes placed by rules. Study: Shattered Pixel Dungeon `levels/builders` and `levels/painters` for the room/painter split; Brogue `Architect.c` for lakes, bridges and machines.

## Requirements

### Requirement: Seeded generation
An island SHALL be generated deterministically from (run seed, island index, chain id). The host generates and sends the seed; clients regenerate locally and verify a hash.

#### Scenario: Client verifies the island
- GIVEN the host generated island 3 of chain C from run seed S
- WHEN a client regenerates it from the seed the host sent
- THEN the client's island hash matches the host's

### Requirement: Landmass
The generator SHALL produce a 96×64 grid with a noise-shaped landmass sized by chain (sandbar ~15% land, lighthouse ~45%). Bands from the shoreline inward: deep water, shallows (1–2 tiles), beach (2–4 tiles), then the chain's interior biome (dune, mangrove, rock, scrub).

#### Scenario: Sandbar
- GIVEN chain = sandbar
- WHEN an island is generated
- THEN land is 10–20% of tiles, there is no interior biome beyond dune, and no tile is more than 6 tiles from water

### Requirement: Biome rules
Mangrove tiles SHALL only touch shallow or brackish water. Rock chains SHALL have cliff edges (impassable from the low side). Lagoons SHALL be enclosed shallow water with one channel.

#### Scenario: Lagoon and mangrove rules
- GIVEN a generated island with a lagoon and mangrove
- WHEN its tiles are checked
- THEN the lagoon is enclosed shallow water with exactly one channel, and no mangrove tile touches water other than shallow or brackish

### Requirement: POI placement
The generator SHALL place 3–6 POIs from the chain's table (`docs/ISLANDS.md`) honoring: minimum distance 12 tiles between POIs, shoreline access for boats/wrecks, no duplicate kinds, at most one set piece. Guaranteed POIs (e.g. binoculars cairn on rock) SHALL always be placed.

#### Scenario: Rock island POIs
- GIVEN chain = rock
- WHEN an island is generated
- THEN it has 3–6 POIs from the rock table, at least 12 tiles apart, no two of the same kind, at most one set piece, and the binoculars cairn among them

### Requirement: Escape routes
Each island SHALL expose 2–3 escape-route POIs chosen from the chain's allowed list, with at least one always-buildable route (raft) unless the chain says otherwise. An island set up for exactly one living, connected player SHALL also expose at least one reachable route that needs no background skill and no starting item (docs/GAME_DESIGN.md §10), even where the chain overrides the raft rule. Solo otherwise uses the same base numbers as co-op.

#### Scenario: Raft always offered
- GIVEN a chain that does not override the raft rule
- WHEN an island is generated
- THEN it exposes 2–3 escape-route POIs from the chain's allowed list, one of them the raft

#### Scenario: Solo island where the chain drops the raft
- GIVEN a 1-player run whose only player is a Músico, and a chain whose allowed list overrides the raft rule
- WHEN island 5 is generated
- THEN at least one of its 2–3 escape routes needs no background skill and no starting item, and is reachable from the player spawn

#### Scenario: Last survivor gets the same guarantee
- GIVEN a 3-player run in which 2 players died
- WHEN the next island is set up
- THEN it counts 1 living player and exposes at least one escape route that needs no background skill and no starting item

### Requirement: Resource spawns
Resources SHALL spawn per `docs/ISLANDS.md` resource rules, scaled by party size, with respawn hooks for squalls and nights. Party size SHALL be the number of living, connected players when the island is set up (the count coop-networking's difficulty scaling uses), and respawns on that island use the same count.

#### Scenario: Squall respawn
- GIVEN an island whose resources spawned per `docs/ISLANDS.md`
- WHEN a squall passes
- THEN the squall respawn hook runs and resources respawn per those rules, scaled by party size

#### Scenario: Solo island
- GIVEN a 1-player run
- WHEN island 2 is set up
- THEN party size is 1 and resources spawn at the `docs/ISLANDS.md` amounts with no party-size reduction (×1)

#### Scenario: Dead players do not count
- GIVEN a run that started with 4 players, 3 of whom died on island 3
- WHEN island 4 is set up
- THEN party size is 1, the same as a 1-player run

### Requirement: Navigation data
The generator SHALL output an `AStarGrid2D` with costs: beach 1, dune 1.5, mangrove 3, shallows 2 (wade), deep water impassable for land AI; and a separate water grid for sea creatures.

#### Scenario: Path costs
- GIVEN a generated island
- WHEN its navigation data is read
- THEN the `AStarGrid2D` costs beach 1, dune 1.5, mangrove 3, shallows 2, deep water is impassable for land AI, and a separate water grid exists for sea creatures

### Requirement: Validation
A generated island SHALL be rejected and regenerated if any POI is unreachable from the player spawn by land+shallows, or if no escape route is reachable.

#### Scenario: Unreachable POI
- GIVEN a generated island where one POI cannot be reached from the player spawn by land and shallows
- WHEN validation runs
- THEN the island is rejected and regenerated

### Requirement: Handmade sandbar
The first island of every run SHALL be the handmade sandbar (*el banco de arena*, `docs/ISLANDS.md` §1), read from an island layout data file, not generated: an open crescent of beach, dune and sea-grape brush opening east, in shallows and deep water, larger than the 640×360 view, with 940–1,100 land cells, land 10–20% of its cells and no land cell more than 6 tiles from water. Its arc is about 90 tiles along the middle, a walk of about 22–25 s for one player at the walking speed (4 tiles/s). Moving or adding a palm, a pick-up or a spawn point SHALL need only a data change.

#### Scenario: The sandbar is data
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it is larger than 640×360 px, it has 940–1,100 land cells, 10–20% of its cells are land, and no land cell is more than 6 tiles from water

### Requirement: Sandbar contents
The sandbar SHALL hold the ruined hut, a palm grove, the flotsam line and tide pools (always there until a tide exists), spread along the crescent: the hut on the north horn, the palm grove mid-arc (every palm at least 20 tiles from the hut), the tide pools on the south horn, the flotsam line on the inside curve and the raft build site on the beach where the flotsam lands. Every pick-up, palm, tide pool, the workbench and the raft build site SHALL be reachable on foot or wading from every spawn point, so exactly 1 player, offline, can reach and take all of it alone. The island holds 3 rope in all (1 on the flotsam line, 2 in the hut) so a player can build the raft on day 1.

#### Scenario: The sandbar loads
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it has 6 palms holding 10 coconuts in all (`docs/ISLANDS.md` "Resource rules"), one workbench, the hut's cells are the only shaded cells, and its pick-ups are 1 tarp, 2 driftwood, 1 knife and 2 rope in the hut, 2 inner tubes, 3 plastic jugs and 1 rope on the flotsam line, 6 driftwood on the beach and 3 dry grass on the dune

#### Scenario: Everything is in reach of a lone player
- GIVEN the built sandbar and its solo spawn point
- WHEN paths over land and shallows are checked from that point
- THEN every palm, pick-up, tide pool, the workbench and the raft build site can be reached, and the same holds from every co-op spawn point

#### Scenario: A lone player's walks
- GIVEN one offline player at the solo spawn point, walking at 4 tiles/s
- WHEN the shortest walk over land and shallows is measured
- THEN every palm is 6–11 s away, the raft build site 4.5–8 s and every tide pool 13–17.5 s, and the far horn is 15 s or more

### Requirement: Palm climbing
A player SHALL gather a coconut by holding interact on a palm that still has one for the timed-interaction hold (2 s): the host puts 1 coconut in their inventory and takes 5 energy from them. A palm with no coconut left, or a player whose inventory cannot take the coconut, gains nothing and pays nothing. Climbing needs no teammate; exactly 1 player can take all 10 coconuts alone.

#### Scenario: A solo player climbs every palm
- GIVEN one offline player at energy 100 on the sandbar with room for 10 coconuts
- WHEN they climb the 6 palms until none has a coconut left
- THEN they hold 10 coconuts, their energy is 50 and climbing again gives nothing and costs nothing

#### Scenario: Opening the first coconut with the hut's knife
- GIVEN one offline player who climbed a palm and picked up the hut's knife
- WHEN they drink the coconut
- THEN thirst rises 15, hunger 5, energy 10, the coconut is gone and the knife has 39 uses left

### Requirement: Flotsam refresh
When a squall ends on the sandbar the host SHALL put back every flotsam-line pick-up (inner tubes, plastic jugs, rope) and every beach driftwood pick-up that was taken, at its own spot; pick-ups still lying there are not doubled, and hut loot never comes back. A client sees the refreshed pick-ups. With exactly 1 player, offline, the same refresh happens.

#### Scenario: A solo player's flotsam comes back after a squall
- GIVEN one offline player who picked up both inner tubes and one plastic jug, and the hut's knife
- WHEN a squall starts and then ends
- THEN the flotsam line again holds 2 inner tubes, 3 plastic jugs and 1 rope, and the knife is not back in the hut

#### Scenario: No refresh while the squall falls
- GIVEN a taken inner tube
- WHEN a squall starts and has not ended
- THEN the tube is not back

### Requirement: Scattered landing
On the sandbar each player SHALL spawn at a layout spawn point on the sand. In co-op each spawn point in use is 20–30 tiles from the next one in join order (1 to 2, 2 to 3, 3 to 4; `docs/ISLANDS.md` §1, "Scattered landing"), spread along the arc, so the party has to find each other first; the first and the last may be much farther apart. Exactly 1 player, offline, spawns at the solo spawn point near the hut, with no one to look for.

#### Scenario: Four players land apart
- GIVEN a co-op run on the sandbar
- WHEN 2, 3 or 4 players spawn
- THEN each is at least 20 and at most 30 tiles from the next in join order, each on beach or dune

#### Scenario: A solo landing
- GIVEN a solo run
- WHEN the player spawns
- THEN they stand on the solo spawn point, on sand, within 4 tiles of the hut

### Requirement: The run starts on the sandbar
A run started from the game shell (solo, hosted, or a client joining) SHALL start on the handmade sandbar; the camera stays inside the island. The host places the island's pick-ups and refreshes them; a client sees the host's pick-ups appear and vanish and never places or removes one itself. A client's pick-up on the sandbar is applied by the host. With exactly 1 player, offline, the run starts on the sandbar with every pick-up placed and no network port open.

#### Scenario: Solo run on the sandbar
- GIVEN the title screen
- WHEN the one player starts a solo run
- THEN the island is the sandbar, the player is at its solo spawn point, and the hut's 4 pick-ups, the flotsam line's 6 pick-ups and the 6 palms are there

#### Scenario: Hosted run on the sandbar
- GIVEN a host and a client in the lobby
- WHEN the host begins the run
- THEN both are on the sandbar at co-op spawn points 20–30 tiles from the next in join order, and the client sees the same pick-ups as the host

#### Scenario: A client's pick-up is applied by the host
- GIVEN a hosted sandbar run and a client next to an inner tube
- WHEN the client interacts with it
- THEN the host puts the tube in the client's inventory, the client's inventory shows it, and the tube is gone on both peers

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
