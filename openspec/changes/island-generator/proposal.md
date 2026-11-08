# Proposal

## Why

Every island so far is handmade: the sandbar (island 1) and the coast cay (island 2) are text rows in `game/resources/islands/`. `docs/ISLANDS.md` says islands 3–5 come from the mid chains and are generated fresh each run from chain templates, and `TASKS.md` §5 opens Milestone C with "`island-generation`: seeded landmass, bands, POI placement, validation". The owner scoped it to **the seeded island generator for one chain**. This change writes that generator's contract and build plan; nothing is built until the Milestone A/B playtest has been played.

The chain is the reef cay, traps variant (*el cayo del arrecife*, `reef_traps`): of the two mid chains a run could generate first, it is the one whose routes, creatures and terrain the game already has (owner decision 1).

## What Changes

- **A seeded generator** (`IslandGenerator`, GDScript, pure, no scene) turns `(run seed, island index, chain template)` into an island layout of the same kind as the handmade ones: text rows, a glyph legend, the landing cells, the raft build site, palms, shaded cells, pick-ups, routes and the chain family. It is held in memory, never written to the content folders, and the island scene, the creature spawner and island travel build it through the code path the sandbar and the coast cay already use (owner decision 4). The art pass can draw its `GridTerrain` cell by cell like any other island.
- **Integer-only and streamed.** Each stage (landmass, bands, landing, POIs, pick-ups, routes) draws from its own random stream seeded from the run seed, island index, chain id, attempt and stage name through SHA-256, never the engine's `hash()`. Every choice is integer arithmetic (no float noise, no trigonometry), so a Windows host and a Linux client build the same cells (owner decision 9). The island's hash is the SHA-256 of its canonical text.
- **One painter, `REEF_RING`.** A spine of integer height bumps across the grid (DCSS Shoals' idea), smoothed, cut at the sea level that gives the template's land count exactly (SPD `Patch`'s forced fill rate), largest landmass kept and cleaned (Brogue's blob and boundary clean-ups). Then bands: shallows to 2 tiles out and deep water from 3; a 2–4 tile shore band of rock with beach on the lee (west-facing) side; scrub inland with rock patches.
- **POIs placed by data rules.** Each POI's anchor goes on a cell its data allows, at least its minimum distance (12 tiles) from the others and inside the template's walk band from the landing; its pieces (pick-ups, palms, shade, a water source) go on the cells the data names around it (Brogue's machine features). The reef places the lobster traps, the limestone cave and the flotsam line always, and a small palm grove on about half of the islands.
- **Validation with a capped reroll.** Land band, inland limit, one landmass, POI spacing, guaranteed POIs, reachability of everything from the first landing cell over land and shallows, the landing shape and a lone arrival's walk bands. A failed attempt becomes the next attempt with its own derived seed, so every peer makes the same attempts. 50 attempts at most, the last 5 without rolled POIs; at the cap the island is the chain's fixed fallback island, which a test proves valid (owner decision 5).
- **The template is data.** `game/resources/chains/reef_traps.tres` (`ChainData`) and four POI files in `game/resources/pois/` (`lobster_traps`, `limestone_cave`, `flotsam_line`, `palm_grove`). New fields: grid size, edge margin, land-cell band, shore and lee terrain, shape parameters, landing and raft-site rules, per-POI walk bands, the attempt cap and the fallback seed on `ChainData`; anchor terrain, shade, palms on `PoiData`; placement rules on `SpawnEntryData`; party scaling on `IslandGlyphData`. A chain whose layout rule already has a painter needs no script edit.
- **Network.** The host only shares the reference: its travel message names the chain, the island index and the island hash; the run seed is the one the host already puts in the world state (`run-end`, PR #31). Every peer, a late joiner included, regenerates the island and compares the hash; a client that differs takes the host's layout in one reliable message (owner decision 6). Party size, who is connected and anything drawn only for looks never feed the generator.
- **Party scaling and the seep.** The host scales driftwood by ×0.8 per extra player when it places pick-ups, never below one raft's inputs (owner decision 7). Pick-ups marked to come back daily (the cave's seep: 2 rain cups) are put back at dawn.
- **Reaching play.** A layout's next island may name a chain template; island travel then generates it. No shipped layout names one yet: a dev scene walks generated reefs by seed, and the tests drive the real travel path (owner decision 2).
- **Creatures as data.** The reef shark gets a reef rule (3 offshore) and land crabs add the reef family; no gulls (no nest palms). No script edit.
- **Specs:** `island-generation` MODIFIED (Seeded generation, Landmass, POI placement, Navigation data, Validation, each copied whole from `openspec/specs/` with every scenario kept) and ADDED (template as data, a generated island builds like a handmade one, the reef cay's landmass numbers inside Landmass, contents, landing and walks, routes, creatures, party scaling, dawn refill, travel, dev scene). "Escape routes" and "Resource spawns" are left alone because `secret-cay` modifies them; the reef's routes and scaling are ADDED requirements instead.

## Solo

Solo is first class and nothing in the generator knows the party size. A 1-player run's island 3 is the same island a host with three clients gets from that run seed. One offline player standing on the first landing cell can reach every pick-up, palm, the cave and the raft build site over land and shallows, within the walk bands below, and builds the raft alone: the reef always holds 8 driftwood, 2 inner tubes and 8 rope for that player (the raft needs 6, 2 and 3), the raft route needs no background skill and no starting item, and the seep's 2 cups come back every dawn. Tests run with exactly 1 player, offline: generation, the walks, building the raft, travelling to a generated island, the dawn refill and the dev scene.

## Owner decisions (recommended option first)

1. **The chain.**
   a. *Recommended:* the reef cay, traps variant (`reef_traps`). Both of its non-quest routes exist today (raft, binoculars-and-swim), so it meets "2–3 routes" with no new route; its reef sharks exist (a data edit); its terrain (rock, beach, scrub, shallows, deep) is already walkable, drawn and costed; its shape is the plain blob-plus-bands pipeline every later chain needs.
   b. The mangrove cay, maze variant (`mangrove_maze`). Its own routes (repair the boat with the old crocodile's nest as boss, follow the dolphins) and threats (crocodiles, mosquitoes) are not built, so it would offer only the raft; it needs a channel and maze painter, the "mangrove touches only shallow or brackish water" rule and slow movement in mangrove (today mangrove only hides a crouching player).
2. **How a generated island reaches play.**
   a. *Recommended:* a dev scene that builds and walks generated reefs by seed, plus tests that drive the real travel path with an in-memory layout naming the chain; runs still end on the coast cay until the run structure (`TASKS.md` §5, Milestone C) picks the next island. No crossing spec changes.
   b. Point `coast_cay.tres`'s next island at `reef_traps` now, so every run goes sandbar, coast, generated reef. That changes crossing "Arrival" (its scenario "A beached raft launches again" ends the run on the coast cay) and island-generation "Handmade coast cay"; `balsero-lore` also modifies "Arrival", so this would wait for it to archive.
3. **Scale.**
   a. *Recommended:* the doc's 96×64 grid (6,144 cells, close to DCSS's 80×70) with a pinned land-cell band of 1,000–1,300 (16–21%), every land cell within 10 tiles of water, the farthest land 9–22 s from the landing. That is the scale the owner approved twice (the sandbar's 991 land cells on 80×72, the coast cay's 1,021 on 88×64), so island 3 does not jump in size.
   b. The template's current land fraction for a mid island (0.2–0.4 of 96×64: 1,230–2,460 land cells), walks up to about 30 s.
   c. Exactly the handmade band (940–1,150 land cells) on 88×64.
4. **The shared interface.**
   a. *Recommended:* the generator emits an in-memory `IslandLayoutData` (rows and legend) that every consumer reads through `IslandLayout.build`, as it reads the sandbar; the island scene, the creature spawner and travel need no second build path, and a generated island can be dumped as text for debugging or for the host's fallback message.
   b. The generator emits an `IslandLayout` (the built grid and lists) directly; `SandbarIsland`, `CreatureSpawner.setup` and `IslandTravel` each get a second entry point and a separate settings resource.
5. **Reroll cap and what happens at it.**
   a. *Recommended:* 50 attempts (Brogue CE and DCSS both stop at 50), the last 5 without rolled POIs (DCSS drops random vaults when few tries are left), then the chain's fallback island: the generator's own output for the template's fixed fallback seed, which a test proves valid. Same on every peer.
   b. 50 attempts, then a handmade fallback layout per chain (`.tres`): certain, but one more hand-drawn file per chain.
   c. 50 attempts, then end the run with an error (Brogue exits).
6. **A client whose island hash differs from the host's.**
   a. *Recommended:* it logs a warning and takes the host's layout (one reliable message, about 7 KB for 96×64), so the session survives; a pinned hash test on Linux CI and Windows catches drift long before players do.
   b. It disconnects with a "versions differ" message.
   c. It plays on its own island and ignores the difference.
7. **Party scaling on generated islands.**
   a. *Recommended:* driftwood ×0.8 per extra player, rounded down, applied by the host when it places pick-ups, never below one raft's inputs (8 / 6 / 6 / 6 driftwood for 1–4 players); everything else on the reef keeps its count. The layout and its hash never change with party size.
   b. No scaling until the resource-rules task (fixed counts, as on the handmade islands).
   c. ×0.8 with no floor (4 players get 4 driftwood, short of one raft unless they carry some).
8. **Water and coconuts on the reef** (`docs/ISLANDS.md` gives no reef coconut count).
   a. *Recommended:* the cave's seep holds 2 rain cups, put back each dawn, and a small palm grove (3 palms, 5 coconuts) on about half of the reefs.
   b. The seep only, no palms (the harshest island so far).
   c. The seep and always a grove.
9. **How the landmass is shaped.**
   a. *Recommended:* integer steps only (height bumps along a spine, integer smoothing, a sea level by rank), with the hash check as a guard. Changes `docs/ISLANDS.md` "Generation" ("noise-shaped") and `docs/GAME_DESIGN.md` §17 ("noise island shape").
   b. Godot's `FastNoiseLite` as the docs say, relying on the hash check and the host's fallback layout when a float differs between platforms.

## Provisional numbers

All data in `reef_traps.tres` and the POI files, for the owner to confirm or retune after walking generated reefs in the dev scene.

- Grid 96×64, no land within 8 cells of the edge, one landmass, 1,000–1,300 land cells, land share 0.16–0.22, every land cell within 10 tiles of water (Euclidean, as the handmade tests measure).
- Shallows: every water cell within 2 tiles of land (Chebyshev); deep water from 3 ("deep water 3 tiles out", `docs/ISLANDS.md` §4).
- Shore band 2–4 tiles (one width per island): rock, except beach where the coast faces west, north-west or south-west to open water (the lee of the trade wind). Interior scrub with rock patches on 20–40% of it.
- Shape (painter parameters): a spine 50–66 tiles long in 3-tile steps, bending 0–60° in all, half-width 7–11 tiles.
- Landing: 4 beach cells beside shallows on the lee beach, every pair at most 5 tiles apart; the first is the lone arrival's. Raft build site: a beach cell 0.5–3 s from the first landing cell.
- POIs: 3–6 by the generic rule; on the reef today 3 or 4, at least 12 tiles apart.
  - Lobster traps (signature): anchor on shoreline rock; 6 rope, one per trap, on shallows cells beside rock within 10 tiles of the anchor and at least 3 apart; never respawn (lobsters, morays and Ramón's quest come later).
  - Limestone cave (guaranteed): anchor on rock at least 3 tiles from water; the 3×3 cells round it are the island's only shade; the seep is a pick-up of 2 rain cups on the anchor, back each dawn.
  - Flotsam line (guaranteed): anchor on beach beside shallows; 2 inner tubes, 2–3 plastic jugs and 2 rope, one per cell, on beach within 6 tiles, at least 2 apart; back after a squall.
  - Palm grove (chance 0.5): 3 palms on beach within 5 tiles, at least 2 apart, 5 coconuts in all; climbing as on the sandbar (2 s, −5 energy).
- Ambient: 8 driftwood on beach, at least 3 apart, back after a squall, ×0.8 per extra player with the raft floor.
- Totals for 1 player: driftwood 8, inner tubes 2, plastic jugs 2–3, rope 8 (the resource rules' 2 plus 1 per trap), rain cups 2 a day, coconuts 0 or 5.
- Routes: raft (guaranteed) and binoculars-and-swim; 2 routes. Set pieces 0, bottle notes 0 and important texts 0 until those systems exist.
- Creatures: 3 reef sharks offshore (deep water, at least 2 tiles from shore), land crabs at night 6 per beach (creatures-ai's ×1.2 per extra player), no gulls.
- A lone arrival's walks at 4 tiles/s (`AStarGrid2D` as the coast cay test measures): raft site 0.5–3 s, flotsam pick-ups 1–7 s, the cave anchor 6–18 s, every trap 6–22 s, every palm 3–15 s, every driftwood at most 20 s, the farthest land cell 9–22 s.
- Attempts: cap 50, relaxed 5, fallback seed 9090. Mean attempts per island at most 2 over 200 seeds (to be measured and recorded by the build). One attempt should take under 150 ms on the dev machine (a target the dev scene prints, not a test).

## Not in this change

Chain templates beyond `reef_traps` (the bluehole variant, mangrove, rock, lighthouse and the rest); run structure and branching (Milestone C later), which decides when a run reaches a generated island; new routes (the turtle, the cave-roof sighting for the swim); NPCs and their camps (Dayana); the reef's POIs whose content does not exist yet (reef flats with fish, urchins, conch and the man o' war; the ghost net with Vieja; the blue hole's dives; the empty rafts of `balsero-lore`), each added later as data; tides; set pieces; found texts and bottle notes; Experiencia bonuses; the +4 driftwood after a squall and other resource-rule details; seeded and daily runs as a feature; AI dialogue; art (the art pass draws whatever `GridTerrain` it is given).

## Impact

- **Data classes:** `chain_data.gd` (new fields, a `poi_walk_s` reference to `pois`), `poi_data.gd` (anchor terrain, distance from water, shade, palms), `spawn_entry_data.gd` (placement group: per-cell units, terrain, beside, within, apart, group), `island_glyph_data.gd` (`party_scaling_per_extra_player`). No new data class, so the data-class and folder counts stay.
- **Content:** `chains/reef_traps.tres`; `pois/lobster_traps.tres`, `limestone_cave.tres`, `flotsam_line.tres`, `palm_grove.tres`; a reef rule in `creatures/reef_shark.tres`; the reef family in `creatures/land_crab.tres`.
- **Code:** new `game/scripts/levels/generation/` (`island_generator.gd`, `generated_island.gd`, `island_seeds.gd`, `island_grid.gd`, `reef_ring_painter.gd`, `poi_placer.gd`, `island_validator.gd`, `island_layout_writer.gd`, `island_source.gd`); `island_layout.gd` ("no palms" only when the layout names a palm glyph); `sandbar_island.gd` (party scaling with the raft floor, dawn refill); `island_travel.gd` (island index, chain references, late joiners); `coop_session.gd` (`travel_to` carries the island index and hash; world-state keys `island_index` and `island_hash`; the host's layout for a mismatched client); a dev scene in `game/scenes/dev/`.
- **Tests:** new GUT files for seeds, the landmass, POIs, validation and rerolls, the writer and hash, solo walks, party scaling and the dawn refill, travel (solo and host plus client) and the dev scene; `test_data_classes.gd` field samples if a new field type needs one.
- **Sequencing:** build after `run-end` (PR #31) is merged, since it adds `run_seed` to the world state; if it is not, task 0 adds that key the same way. `secret-cay` modifies "Escape routes" and "Resource spawns" of `island-generation` and may add a MODIFIED "Any handmade layout builds the island"; this change modifies none of those three. `balsero-lore` adds POIs (`balsa_vacia`, `balsa_marcada`) that the reef table can list later as data. `art-pass` draws terrain from `GridTerrain` with cosmetic variants from a hash of the layout and the cell; for a generated island that hash should be the island hash, so two reefs from different seeds look different.
- **Docs (after the owner confirms):** `docs/ISLANDS.md` ("Generation" paragraph, a size line under §4 Reef cay like the coast cay's, the reef's coconuts), `docs/GAME_DESIGN.md` §17 if decision 9a stands, `docs/CONTENT_MANIFEST.md` (the chain and four POIs ticked), `HANDOFF.md` §5 decisions, `TASKS.md`.
