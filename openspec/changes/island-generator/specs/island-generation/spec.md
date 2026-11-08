# Spec Delta

## MODIFIED Requirements

### Requirement: Seeded generation
An island SHALL be generated deterministically from (run seed, island index, chain id). The host generates and sends the seed; clients regenerate locally and verify a hash. The run seed is the one the host keeps in the world state, which every joiner receives; the host's travel message names the chain, the island index and the island's hash, and every peer, a late joiner included, regenerates the island from them before anyone lands. Each stage (landmass, bands, landing, POIs, pick-ups, routes) draws from its own random stream whose seed is derived from the run seed, island index, chain id, attempt and stage name through SHA-256, never the engine's `hash()`, and every choice the generator makes is integer arithmetic, so peers on Windows and Linux build the same cells. The island hash is the SHA-256 of the island's canonical text (its rows, legend and marker fields in a fixed order). Party size, which peers are connected and anything drawn only for looks are never inputs. A client whose hash differs from the host's logs a warning and builds the host's layout instead, sent once by the host. Regenerating the same reference, as after a capture, gives the same island. With exactly 1 player, offline, the island is the one a host with three clients gets from the same run seed.

#### Scenario: Client verifies the island
- GIVEN the host generated island 3 of chain C from run seed S
- WHEN a client regenerates it from the seed the host sent
- THEN the client's island hash matches the host's

#### Scenario: A solo island is the same every time
- GIVEN a 1-player run, offline, with run seed 1
- WHEN island 3 of `reef_traps` is generated twice offline, and once more by a host with one client and the same run seed
- THEN the three islands have the same rows, the same legend and the same island hash

#### Scenario: A POI roll never moves the land
- GIVEN a 1-player run with run seed 1 and a copy of the `reef_traps` template whose palm grove chance is 1 instead of 0.5
- WHEN island 3 is generated from each template
- THEN the first attempt of each has the same terrain, cell for cell, though their POIs may differ

#### Scenario: A late joiner builds the same island
- GIVEN a host on island 3 of `reef_traps` generated from its run seed
- WHEN a client joins and receives the world state
- THEN the client builds island 3 of `reef_traps` from the run seed, island index and chain in the world state, and its island hash equals the host's

#### Scenario: A mismatched client takes the host's island
- GIVEN a host and a client on island 3 of `reef_traps`, where the client's regenerated island hash differs from the host's
- WHEN the client checks the hash
- THEN it logs a warning, asks the host once, receives the host's layout, and ends on an island whose hash is the host's

### Requirement: Landmass
The generator SHALL produce a grid of the chain template's size (96×64 unless the template says otherwise) with a landmass shaped by the template's layout rule from seeded integer steps, never floating-point noise, with its land cell count inside the template's land band, no land inside the template's edge margin, and no land cell farther from water than the template allows. Land shares named elsewhere (sandbar ~15% land, lighthouse ~45%) become land bands when those templates are written. Bands from the shoreline: deep water, shallows (the template's width, 1–2 tiles), the shore band (2–4 tiles: beach, or the template's shore terrain with beach on its lee side), then the chain's interior biome (dune, mangrove, rock, scrub). With exactly 1 player the landmass is the one 4 players get. (Changes `docs/ISLANDS.md` "Generation": the "noise-shaped landmass on a 96×64 tile grid" becomes a template-sized grid shaped from integer steps, with a land-cell band per template.)

#### Scenario: Sandbar
- GIVEN chain = sandbar
- WHEN an island is generated
- THEN land is 10–20% of tiles, there is no interior biome beyond dune, and no tile is more than 6 tiles from water

#### Scenario: The reef cay's landmass
- GIVEN a 1-player run, offline
- WHEN island 3 of `reef_traps` is generated for each of 200 run seeds
- THEN every island is 96×64 with 1,000–1,300 land cells (16–22% of its cells) in one 4-connected landmass, no land within 8 cells of the grid's edge, every land cell within 10 tiles of water, every water cell within 2 tiles of land is shallows and every other water cell is deep, the shore band is 2–4 tiles deep with beach on the west-facing coast and rock elsewhere, and rock covers 20–40% of the interior beyond it with scrub on the rest

### Requirement: POI placement
The generator SHALL place 3–6 POIs from the chain's table (`docs/ISLANDS.md`) honoring: minimum distance 12 tiles between POIs, shoreline access for boats/wrecks, no duplicate kinds, at most one set piece. Guaranteed POIs (e.g. binoculars cairn on rock) SHALL always be placed. The table is the chain template's: its signature and guaranteed POIs first, then the rolled ones by their chances, until the template's POI count; a rolled POI that finds no valid spot is skipped, never forced. Each POI's anchor goes on a cell its data allows (placement, anchor terrain, distance from water, shoreline access), at least its own minimum distance (12 tiles unless its data says otherwise) from every other POI's anchor, reachable from the first landing cell over land and shallows and inside the template's walk band for that POI; its pieces (pick-ups, palms, shaded cells, a water source) go on the cells its data names around the anchor. No data names a cell: where a POI may go is a data change. Until set pieces exist the generator places none. With exactly 1 player the same POIs are placed, and each can be reached alone.

#### Scenario: Rock island POIs
- GIVEN chain = rock
- WHEN an island is generated
- THEN it has 3–6 POIs from the rock table, at least 12 tiles apart, no two of the same kind, at most one set piece, and the binoculars cairn among them

#### Scenario: The reef cay's POIs
- GIVEN a 1-player run, offline
- WHEN island 3 of `reef_traps` is generated for each of 200 run seeds
- THEN every island has the lobster traps, the limestone cave and the flotsam line, 35–65% of the islands also have a palm grove and the rest have no palms, no two POIs are of the same kind, every pair of POI anchors is at least 12 tiles apart, and no island has a set piece

### Requirement: Navigation data
The island's navigation data SHALL come from its terrain, handmade or generated, through the creature navigation grids (creatures-ai "Creature navigation"): an `AStarGrid2D` with costs: beach 1, dune 1.5, mangrove 3, shallows 2 (wade), rock 1, scrub 1, deep water impassable for land AI; and a separate water grid for sea creatures. The generator outputs terrain and placements only, never a second navigation grid. With exactly 1 player the grids are the same.

#### Scenario: Path costs
- GIVEN a generated island
- WHEN its navigation data is read
- THEN the `AStarGrid2D` costs beach 1, dune 1.5, mangrove 3, shallows 2, deep water is impassable for land AI, and a separate water grid exists for sea creatures

#### Scenario: A solo reef's grids
- GIVEN island 3 of `reef_traps` generated for a 1-player run
- WHEN the creature navigation grids are built from its terrain
- THEN rock and scrub cells cost 1 on the land grid, every deep-water cell is solid on it, and the water grid holds only shallow and deep water

### Requirement: Validation
A generated island SHALL be rejected and regenerated if any POI is unreachable from the player spawn by land+shallows, or if no escape route is reachable. The player spawn is the first landing cell. An island is also rejected if its land count or land share leaves the template's band, land lies inside the edge margin, it has more than one landmass, a land cell is farther from water than the template allows, a guaranteed POI is missing, two POI anchors are closer than their minimum distance, a landing cell, the raft build site, a pick-up, a palm or a shaded cell cannot be reached from the first landing cell over land and shallows, the landing is not the template's number of beach cells within its spread, a lone arrival's walk to the raft site, a POI anchor or the farthest land cell leaves the template's band, or its layout reads with problems. Each regeneration is the next attempt with its own derived seeds, so every peer makes the same attempts and accepts the same one. The template caps the attempts (50 for the reef cay) and names how many of the last ones skip rolled POIs (5); if every attempt fails, the island is the chain's fallback island, the first valid attempt from the template's own fallback seed, the same on every peer. No check depends on party size: the island that passes for one player is the island for four.

#### Scenario: Unreachable POI
- GIVEN a generated island where one POI cannot be reached from the player spawn by land and shallows
- WHEN validation runs
- THEN the island is rejected and regenerated

#### Scenario: A lone arrival reaches everything
- GIVEN island 3 of `reef_traps` generated for a 1-player run, for each of 200 run seeds
- WHEN paths over land and shallows are checked from the first landing cell
- THEN every landing cell, the raft build site, every pick-up, every palm and every shaded cell can be reached, and every island was accepted within 50 attempts

#### Scenario: The cap gives the fallback island
- GIVEN a 1-player run with run seed 1 and an extra check, added by the test, that rejects every attempt made from run seed 1
- WHEN island 3 of `reef_traps` is generated twice
- THEN both stop after 50 attempts and give the same island, marked as the fallback, which is the first valid attempt from the template's fallback seed with id `reef_traps_3`, and it passes every check of `reef_traps`

#### Scenario: The last attempts drop rolled POIs
- GIVEN a 1-player run, a copy of the `reef_traps` template with the palm grove at chance 1, and an extra check, added by the test, that rejects any island with a palm grove
- WHEN island 3 is generated
- THEN no attempt from the 46th on rolls a palm grove, and the accepted island has none

## ADDED Requirements

### Requirement: Chain template as data
A chain template SHALL be a `ChainData` file in `game/resources/chains/`, its POIs `PoiData` files in `game/resources/pois/`, together holding every number and rule the generator reads. The layout rule names a painter in code: a chain whose rule has a painter needs no script edit, and changing a POI, a pick-up or a number is a data change. Creature rules stay on the creatures' spawn rules. With exactly 1 player the template is read the same way.

#### Scenario: The reef cay's template loads
- GIVEN the content catalog
- WHEN `chains/reef_traps.tres` and the POI files `lobster_traps`, `limestone_cave`, `flotsam_line` and `palm_grove` load
- THEN `reef_traps` has family reef, layout rule reef ring, a 96×64 grid, edge margin 8, land 1,000–1,300 cells, inland limit 10, shallows 2, a shore band 2–4 of rock with beach on the west, the lobster traps as signature, the cave and the flotsam line guaranteed, the palm grove at 0.5, 3–6 POIs, the raft guaranteed and binoculars-and-swim, 50 attempts with 5 relaxed, and the content check reports no errors

#### Scenario: A re-weighted POI is data
- GIVEN a 1-player run and two copies of the `reef_traps` template made in a test, one with the palm grove at chance 1 and one at chance 0
- WHEN island 3 is generated from each for 20 run seeds
- THEN every island from the first has a palm grove, no island from the second has one, and no script changed

### Requirement: A generated island builds like a handmade one
The generator SHALL output an island layout of the same kind as a handmade one, held in memory and never written to the content folders, so the island scene, the creature spawner and island travel build it as they build the coast cay, and its terrain is a `GridTerrain` like theirs. Its id is the chain id and island index (`reef_traps_3`) and it reads with no problems; a layout that names no palm glyph has no palms, which is not a problem. With exactly 1 player nothing differs.

#### Scenario: The island scene builds a generated reef
- GIVEN island 3 of `reef_traps` generated for a 1-player run
- WHEN the island scene is given its layout before it enters the tree
- THEN its terrain, bounds (96×64 cells) and palms are the generated island's, its layout reads with no problems, and the creature spawner reads chain family reef

#### Scenario: A reef with no grove is sound
- GIVEN a 1-player run whose island 3 of `reef_traps` rolled no palm grove
- WHEN its layout is read
- THEN it has no palms and its layout reports no problems

### Requirement: Reef cay contents
Island `reef_traps` SHALL hold the lobster traps, the limestone cave (the island's only shade, with a seep that refills each dawn), the flotsam line, 8 driftwood and, on about half of the islands, a palm grove, with the counts and cell rules of its template and POI files. It has no workbench, drinking spot, sign or tide pool. The other `docs/ISLANDS.md` §4 reef POIs join as data when their items exist. Exactly 1 player finds all of it.

#### Scenario: A solo reef's contents
- GIVEN island 3 of `reef_traps` generated for a 1-player run, for each of 200 run seeds
- WHEN its pick-ups, palms and shaded cells are counted
- THEN it has 6 trap rope, 2 inner tubes, 2–3 plastic jugs, 2 flotsam rope, 8 driftwood and one pick-up of 2 rain cups that comes back at dawn, its shaded cells are the cave's 9 and no others, and it has either 3 palms holding 5 coconuts or no palm

#### Scenario: Where a solo reef's pieces lie
- GIVEN island 3 of `reef_traps` generated for a 1-player run, for each of 200 run seeds
- WHEN its pieces are located
- THEN each trap rope lies on a shallows cell beside rock within 10 tiles of the traps' anchor on shoreline rock, at least 3 tiles from the other traps, and never comes back; the cave's anchor is rock at least 3 tiles from water with the 3×3 round it shaded and the rain cups on it; each flotsam pick-up lies on beach within 6 tiles of its anchor, at least 2 tiles from the others, and comes back after a squall; each driftwood lies on beach at least 3 tiles from the others and comes back after a squall; and each palm, when there is a grove, stands on beach within 5 tiles of its anchor, at least 2 tiles from the others, and is climbed as on the sandbar (2 s, 5 energy)

### Requirement: Reef cay landing
Island `reef_traps` SHALL have a landing of 4 beach cells beside shallows on its west-facing beach, every pair at most 5 tiles apart; players land on them in join order, and the first is where a lone arrival stands. Its raft build site is a beach cell that is not a landing cell. Exactly 1 player lands alone on the first cell.

#### Scenario: The reef's landing
- GIVEN island 3 of `reef_traps` generated for a 1-player run, for each of 200 run seeds
- WHEN its landing cells are read
- THEN there are 4, all beach and each beside shallows, every pair at most 5 tiles apart, the first is where a lone arrival stands, and the raft build site is a beach cell that is none of them

### Requirement: Reef cay walks
A lone arrival's shortest walk over land and shallows at 4 tiles/s from the first landing cell of `reef_traps` SHALL be 0.5–3 s to the raft site, 1–7 s to every flotsam pick-up, 6–18 s to the cave's anchor, 6–22 s to every trap, 3–15 s to every palm, at most 20 s to every driftwood and 9–22 s to the farthest land cell, so exactly 1 player, offline, can reach and take everything and build the raft alone.

#### Scenario: A lone arrival's walks on the reef
- GIVEN island 3 of `reef_traps` generated for a 1-player run, for each of 50 run seeds, and one offline player on its first landing cell walking at 4 tiles/s
- WHEN the shortest walks over land and shallows are measured
- THEN every walk is inside its band

#### Scenario: A solo player builds a raft on the reef
- GIVEN one offline player on the first landing cell of island 3 of `reef_traps` for run seed 1
- WHEN they take 6 driftwood, both inner tubes and 3 rope and build at the raft site
- THEN a raft stands at integrity 100 and nobody else was needed

### Requirement: Reef cay routes
Island `reef_traps` SHALL offer the raft (always) and binoculars-and-swim, the two routes of its table that exist, so it meets "Escape routes" with 2 routes; the raft needs no background skill and no starting item, so an island set up for one living player always has a route they can take. The turtle joins the table as data when it exists. Exactly 1 player can build and launch the raft alone.

#### Scenario: A solo reef's routes
- GIVEN island 3 of `reef_traps` generated for a 1-player run whose only player is a Músico with no binoculars
- WHEN its routes are listed
- THEN they are the raft and binoculars-and-swim, the raft needs no background skill and no starting item, and its build site is reachable from the first landing cell

### Requirement: Reef cay creatures
On island `reef_traps` the creature spawner SHALL place 3 reef sharks offshore (deep water at least 2 tiles from shore) and, at night, land crabs on each beach as on the coast cay; it places no gulls, since the reef has no nest palms. These come from the creatures' own spawn rules naming the reef family; no script names the reef. With exactly 1 player there are 3 sharks and 6 crabs per beach.

#### Scenario: A solo reef's creatures
- GIVEN the host of a 1-player run on island 3 of `reef_traps`
- WHEN the creature spawner starts and the night begins
- THEN 3 reef sharks swim in deep water at least 2 tiles from shore, each beach of at least 8 cells has 6 land crabs, and there are no gulls

### Requirement: Party scaling on generated islands
On a generated island the host SHALL scale each pick-up group its data marks with a party factor as it places pick-ups, keeping the floor of (cells × factor^(players − 1)) in reading order, players being the living, connected players at set-up; then it puts back cells of each raft-recipe input until the island holds that recipe's amount. The layout and its hash never change; a client never places a pick-up; handmade layouts keep their counts. With exactly 1 player nothing is scaled.

#### Scenario: The reef's driftwood by party size
- GIVEN island 3 of `reef_traps`, whose only scaled group is driftwood at ×0.8 per extra player
- WHEN its host places the pick-ups for 1, 2, 3 and 4 living, connected players
- THEN 8, 6, 6 and 6 driftwood are placed

#### Scenario: A solo reef keeps every driftwood
- GIVEN the host of a 1-player run, offline, arriving on island 3 of `reef_traps`
- WHEN the pick-ups are placed
- THEN all 8 driftwood are placed, as listed in the layout

#### Scenario: Four players never lose the raft
- GIVEN a host with 3 clients arriving on island 3 of `reef_traps`
- WHEN the host places the pick-ups
- THEN 6 driftwood, 2 inner tubes and 8 rope are placed, every client sees the same pick-ups, and the island hash is the one a 1-player run gets

### Requirement: Dawn refill
When dawn begins, the host SHALL put back every pick-up whose respawn is daily and that was taken, at its own cell; pick-ups still lying there are not doubled. A client sees the refilled pick-ups and never places one. With exactly 1 player, offline, the same refill happens.

#### Scenario: A solo player's seep fills again
- GIVEN one offline player on island 3 of `reef_traps` who took the cave's 2 rain cups during the day
- WHEN the next dawn begins
- THEN a pick-up of 2 rain cups lies on the cave's anchor again, and the trap rope they took is not back

### Requirement: Travelling to a generated island
A layout's next island SHALL be able to name a chain template; island travel then generates it from the run seed, the next island index and that chain on every peer and lands the riders as on a handmade island. The host's travel message carries the island id, its index (1–8) and, for a chain, the island hash; any other message is ignored. The world state tells joiners the same three. No shipped layout names a chain yet. With exactly 1 player, offline, the crossing's end loads it at once.

#### Scenario: A solo crossing lands on a generated reef
- GIVEN a 1-player run, offline, on a test copy of the coast cay whose next island names `reef_traps`, with run seed 1
- WHEN the player's raft crossing ends with the raft at integrity 70
- THEN the island is island 3 of `reef_traps` for run seed 1, the player stands on its first landing cell, a raft with integrity 70 stands at its raft build site, and the run has not ended

#### Scenario: Host and client land on the same reef
- GIVEN a host and a client on a test copy of the coast cay whose next island names `reef_traps`
- WHEN the host travels
- THEN both peers build island 3 of `reef_traps` with the same island hash, both players stand on its landing cells, and the client sees the host's pick-ups

#### Scenario: A bad travel message is ignored
- GIVEN a client in a hosted run
- WHEN a travel message arrives from the client itself, or names an unknown id, or carries index 9 or a hash that is not 64 hex characters
- THEN no island is loaded on any peer

### Requirement: Dev scene for generated islands
A dev scene SHALL build a generated island from a chain, a run seed and an island index, let one offline player walk it from its first landing cell, step to the next or previous seed on a key, and show the template's numbers it measured (land cells, attempts, whether it is the fallback island, the walks to the raft site and the POIs, the generation time). It lives in `game/scenes/dev/`, outside the content folders, so no run offers it.

#### Scenario: Walking generated reefs alone
- GIVEN the dev scene with chain `reef_traps`, run seed 1 and island index 3
- WHEN it loads, and then steps to run seed 2
- THEN one offline player stands on each island's first landing cell, the shown numbers are that island's, and no error is logged
