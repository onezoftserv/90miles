# Design

## Context

- **Handmade islands today.** `IslandLayoutData` (`game/scripts/data/island_layout_data.gd`) is text rows plus a legend: every glyph has a terrain, and the marker fields say which glyphs are palms, the workbench, spawns, tide pools, the raft site, drinking spots, signs and pick-ups. `IslandLayout.build` reads it into a `GridTerrain` (cells default to deep water) and placement lists, and `IslandLayout.reachable_from` is the 4-connected walk over `WALKABLE` (beach, dune, scrub, rock, shallows). `SandbarIsland` builds whatever layout it is given before it enters the tree ("Any handmade layout builds the island"); `CreatureSpawner.setup(session, layout)` builds the same layout again and reads `layout.chain_family`; `IslandTravel._load(layout_id, …)` fetches the next layout from the catalog's `islands` folder, and `CoopSession.travel_to` refuses any id that is not there. Joiners hear `island` (a layout id), `waiting` and `raft` in the world state.
- **Data waiting for a generator.** `ChainData` and `PoiData` exist (project-skeleton) and the catalog registers `chains/` and `pois/`, but both folders are empty and no code reads either class. `ChainData.layout_rule` already names painters (`REEF_RING` among them), and creature rules live on `CreatureSpawnRuleData.chain_families`.
- **Seeds.** `run-end` (PR #31, open) has the host roll `run_seed` into the world state and adds `islands` (islands stood on); joiners receive both. Its design rejects the engine's `hash()` as unstable across versions. The world state's older `island_seed` key is a dev value from coop-networking that nothing reads; this change does not use it.
- **Art.** `art-pass` (proposed) draws terrain as tile layers from `GridTerrain` on every peer, with cosmetic variants from a hash of the layout and the cell, never a simulation RNG.

## Goals / Non-Goals

**Goals:** one chain generated from data, deterministic on every peer from a reference the host shares; the same contract as the handmade islands; validation with a capped, deterministic reroll; every number a GUT test can check, solo included.

**Non-goals:** other chains, the run graph, new routes, NPCs, tides, set pieces, found texts, art.

## Decisions

### 1. The chain: `reef_traps`

| | Reef cay, traps (`reef_traps`) | Mangrove cay, maze (`mangrove_maze`) |
| --- | --- | --- |
| Routes in `docs/ISLANDS.md` | turtle (quest), binoculars-and-swim, raft | repair the boat (boss), raft, dolphins |
| Built today | raft, binoculars-and-swim: 2 routes | raft only: below "2–3 routes" |
| Threats | reef sharks ×3 (exist), barracuda, morays | crocodiles, mosquitoes, the old crocodile (none exist) |
| Terrain | rock, beach, scrub, shallows, deep: all walkable, drawn and costed | mangrove (hides a crouching player, slows nobody), channels, brackish |
| Shape | one blob with bands | channels through a maze; the mangrove-only-touches-shallow-or-brackish rule |
| Waits for later | lobsters, morays, Ramón's quest, Vieja and the turtle, the blue hole's dives, reef flats' fish | the boat, the boss, the dolphins, crocodiles, slow mangrove, tides on the channels |

The reef has fewer "until X exists" clauses and exercises exactly the generic steps every chain needs. Tide-only parts are handled as the sandbar's tide pools were: the reef flats are left out until their items exist, not placed as dry land.

### 2. The output is an in-memory `IslandLayoutData`

`IslandGenerator.generate(run_seed, index, chain, catalog) -> GeneratedIsland` (`layout: IslandLayoutData`, `built: IslandLayout`, `island_hash: String`, `attempts: int`, `fallback: bool`, `report: Dictionary` with the measured numbers for tests and the dev scene). The generator works on integer grids, then `IslandLayoutWriter` turns the grid and placements into rows and a legend; `IslandLayout.build(layout)` reads it back, and its `problems()` must be empty (the existing reader is the writer's self-check). The layout's id is `<chain id>_<index>` (`reef_traps_3`), its names come from the chain, `next_island` is empty, `chain_family` is the chain's family, `route_ids` the rolled routes, `workbench_glyph`, `tide_pool_glyph` and `drink_glyph` are empty, and `climb_effects` and `climb_hold_s` come from the palm grove POI (`harvest_effects`, 2 s).

The writer's alphabet: fixed terrain glyphs (`~` deep, `-` shallows, `.` beach, `^` rock, `,` scrub), the landing `1234` (beach; `solo_spawn_glyph` is `1`, as on the coast cay), the raft site `B` (beach), palms `P` (beach: palms only go on the template's palm terrain, because a palm glyph has one terrain), and one glyph per distinct (terrain, shaded, item, units, respawn, group, scaling) tuple from a fixed pool of letters in a fixed order. Shaded glyphs are listed in `shade_glyphs`. The canonical text is the rows joined by newlines followed by the legend and every marker field in a fixed order; `island_hash` is its SHA-256 (`String.sha256_text`). The same text, parsed back by `IslandLayoutWriter.parse`, is what the host sends a mismatched client.

*Rejected:* emitting an `IslandLayout` directly. It saves the round trip (6,144 cells, well under a millisecond) but needs a second entry point in `SandbarIsland`, `CreatureSpawner.setup` and `IslandTravel`, and a separate settings resource for the climb, drink, routes and family fields those read off the layout.

`IslandLayout.problems()` changes in one place: "no palms" is reported only when the layout names a palm glyph, so a palm-less reef (no grove rolled) is sound.

### 3. Data shapes

**`ChainData` (new fields; existing fields reused as noted):**

| Field | Type | `reef_traps` |
| --- | --- | --- |
| `grid_size` | `Vector2i` | (96, 64) |
| `edge_margin_tiles` | `int` | 8 |
| `land_cells` | `Vector2i` (min, max; 0 means use `land_fraction` only) | (1000, 1300) |
| `shore_terrain` | `Terrain` (shore band away from the lee) | ROCK |
| `lee_terrain` | `Terrain` | BEACH |
| `lee_facing` | `Vector2i` (outward direction of the lee coast) | (-1, 0), west |
| `shape_length_tiles`, `shape_bend_degrees`, `shape_half_width_tiles` | `Vector2i` each (painter parameters) | (50, 66), (0, 60), (7, 11) |
| `landing_cell_count`, `landing_spread_tiles` | `int` | 4, 5 |
| `raft_site_walk_s`, `far_end_walk_s` | `Vector2` (seconds for a lone arrival) | (0.5, 3), (9, 22) |
| `poi_walk_s` | `Dictionary[StringName, Vector2]` (POI id to walk band of its anchor) | `flotsam_line` (1, 7), `limestone_cave` (6, 18), `lobster_traps` (6, 22), `palm_grove` (3, 15) |
| `max_attempts`, `relaxed_attempts`, `fallback_seed` | `int` | 50, 5, 9090 |

Reused: `family` REEF, `distance_band` MID, `fixed_slot` BRANCH, `layout_rule` REEF_RING, `land_fraction` (0.16, 0.22), `landmass_count` 1, `max_inland_distance_tiles` 10, `shallows_width_tiles` (2, 2), `beach_width_tiles` (2, 4) as the shore band's width, `biome_weights` {SCRUB 0.7, ROCK 0.3} for the interior, `poi_count` (3, 6), `signature_poi_id` `lobster_traps`, `guaranteed_poi_ids` [`limestone_cave`, `flotsam_line`], `poi_chances` {`palm_grove`: 0.5}, `route_count` (2, 3), `routes` [raft guaranteed, `binoculars_swim` weight 1], `ambient_resources` [driftwood], `set_piece_chance` 0, `bottle_note_count` (0, 0), `important_text_count` 0. `creature_types_per_island`, `hazards`, `tileset`, `crossing_events` are not read yet. The `poi_walk_s` keys are references to `pois` for the content check.

**`PoiData` (new fields):** `anchor_terrain: Array[Terrain]` (empty: any cell its `placement` allows), `anchor_min_water_tiles: int` (Chebyshev distance from water; the cave 3), `shade_tiles: int` (-1 none; the cave 1, the 3×3 round the anchor), and a palm group: `palm_count: Vector2i`, `palm_coconuts: Vector2i` (total over the grove), `palm_terrain: Terrain`, `palm_within_tiles: int`, `palm_apart_tiles: int`. Reused: `placement` (SHORELINE for traps and flotsam, INTERIOR for the cave, BEACH for the grove), `needs_shoreline_access`, `min_distance_tiles` 12, `loot` (with the placement fields below), `harvest_effects` (the grove's climb: energy −5), and the water group: a POI with `water_item_id` and `water_capacity_cups` gets one pick-up of that many cups on its anchor, coming back on its `water_refill` (the cave: `rain_cup`, 2 cups, DAILY).

**`SpawnEntryData` (new "Placement" group, read only by the island generator):** `per_cell: int = 1` (units in each pick-up; `count` stays the total units, so the coast cay's rope cache would be count 4, per cell 4), `on_terrain: Array[Terrain]` (empty: any walkable land), `beside_terrain: Array[Terrain]` (the cell needs a 4-neighbour of one of these), `within_tiles: int` (from the POI's anchor; 0 is the anchor itself; ignored for ambient entries), `apart_tiles: int` (from the entry's other cells), `group: StringName` (defaults to the POI id; required for ambient entries). Existing `chance`, `respawn` and `party_scaling_per_extra_player` carry through.

**`IslandGlyphData`:** `party_scaling_per_extra_player: float = 1.0`, so a handmade layout keeps its fixed counts.

**The reef's POI files:** `lobster_traps` (SHORELINE, anchor on ROCK; loot rope count 6, per cell 1, on SHALLOWS, beside ROCK, within 10, apart 3, NEVER, group `traps`); `limestone_cave` (INTERIOR, anchor on ROCK, 3 from water, shade 1, features [SHADE], water `rain_cup` 2 cups DAILY); `flotsam_line` (SHORELINE, anchor on BEACH, shoreline access; loot inner tube 2, plastic jug 2–3, rope 2, each per cell 1 on BEACH within 6 apart 2, SQUALL, group `flotsam`); `palm_grove` (BEACH; 3 palms on BEACH within 5 apart 2, 5 coconuts, climb energy −5). Ambient driftwood: count 8, per cell 1, on BEACH, apart 3, SQUALL, scaling 0.8, group `beach`.

### 4. The algorithm, step by step

Grids are `PackedInt32Array` indexed `y * width + x`. Distances are integers: Chebyshev rings by breadth-first search, squared Euclidean by a bounded window, walks by an 8-way chamfer (2 per orthogonal step, 3 per diagonal, in half-tiles; a diagonal only where both orthogonal neighbours are walkable, like `AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`). Ties always break by reading order (y, then x). Chances are integer tests (`randi_range(0, 9999) < roundi(chance * 10000)`).

1. **Seeds.** `IslandSeeds.seed_for(run_seed, index, chain_id, attempt, stage)` is the first 15 hex digits of the SHA-256 of `"%d|%d|%s|%d|%s"` as an integer; each stage (`land`, `bands`, `landing`, `pois`, `pickups`, `routes`) gets its own `RandomNumberGenerator` with that seed.
2. **Spine (`land`).** Roll the length, total bend and a start half-width from the template. The spine walks in 3-tile steps over a fixed table of 16 integer direction vectors, starting roughly along the grid's long axis, turning one notch at seeded steps so the total turn stays inside the bend; it is shifted so that every point plus its half-width lies inside the edge margin. The half-width drifts by at most 1 per step inside its band. No trigonometry.
3. **Heights (`land`).** For each spine point, every cell within its half-width gains (half-width² − distance²), a rounded cap; a few single-cell bumps at seeded offsets add roughness. Two integer smoothing passes (each cell becomes the weighted mean of its 3×3, centre weight 2).
4. **Sea level by rank (`land`).** Roll the target land count inside `land_cells`; sort the heights of the cells inside the margin, highest first, ties by reading order; the first that many cells are land. The land count is exact before clean-up.
5. **One landmass and clean-up.** Label 4-connected land bodies and keep the largest; enclosed water bodies under 12 cells become land; a land cell touching other land only diagonally, or with at most one land neighbour, becomes water; repeat until nothing changes or 20 passes. Recount (the attempt fails if the count left the band).
6. **Water bands.** Water within Chebyshev 2 of land is shallows, the rest deep.
7. **Shore and lee (`bands`).** Roll the shore width (2–4). Land within that Chebyshev distance of water is the shore band. A coast cell (distance 1) is a lee coast cell if any of three straight rays from it (the lee direction and its two 45° neighbours: west, north-west, south-west) reaches the grid edge over water only. Shore cells within the shore width of a lee coast cell (a breadth-first walk over shore cells) take `lee_terrain` (beach); the rest of the shore takes `shore_terrain` (rock).
8. **Interior (`bands`).** On land beyond the shore band: a seeded fill at the rock weight, two clustering passes (3×3 majority), then cells are grown or eroded at patch edges in reading order until rock is within ±5% of the interior of its weight. Rock patches, scrub elsewhere.
9. **Landing (`landing`).** Candidates are lee beach coast cells beside shallows. Take the candidate nearest the candidates' integer centroid, then a seeded pick among the five nearest it; add the 3 nearest beach cells to it (squared distance, reading order) so all 4 are pairwise at most 5 tiles apart. The first is where a lone arrival stands.
10. **Walk map.** Chamfer walk distances from the first landing cell over land and shallows. The chamfer is never shorter than `AStarGrid2D`'s Euclidean path and at most 6.1% longer, so the generator checks upper bands as they are and lower bands raised by 7%: an island it accepts also passes the tests' `AStarGrid2D` measure.
11. **Raft site (`landing`).** A beach cell, not a landing cell, in the raft band, nearest the band's middle, seeded among equals.
12. **POIs (`pois`).** Order: the signature, the guaranteed POIs in data order, then the rolled POIs by id (sorted as text), each rolled with its chance (skipped in the relaxed attempts). For each, candidate anchors match its placement, anchor terrain, distance from water, shoreline access and walk band, are reachable, are at least its minimum distance from every placed anchor and are not a marker cell. Up to 20 seeded candidates are tried in turn; for each, its pieces are placed (shade cells, all of which must be land; the water pick-up on the anchor; palms; loot entries by their cell rules, never on another piece or marker). The first candidate whose pieces all fit is kept. A guaranteed POI that fits nowhere fails the attempt; a rolled one is skipped. The POI count must end inside `poi_count`.
13. **Ambient pick-ups (`pickups`).** Each `ambient_resources` entry: roll the units, then pick cells on its terrain, reachable, apart from the entry's other cells and off every piece and marker, by a seeded walk through the candidates in reading order.
14. **Routes (`routes`).** The guaranteed rows, then weighted picks among the rest until the rolled route count or the rows run out. The reef: `raft`, `binoculars_swim`.
15. **Write and read back.** `IslandLayoutWriter` emits the layout; `IslandLayout.build` reads it; `problems()` must be empty.
16. **Validate** (`IslandValidator`, decision 5) and hash.

### 5. Validation and rerolls

The checks: land count inside `land_cells` and share inside `land_fraction`; no land inside the edge margin; one landmass; every land cell within `max_inland_distance_tiles` of water (Euclidean, as `test_coast_cay_layout` measures); every guaranteed POI present, kinds unique, count inside `poi_count`; anchors at least their minimum distance apart; every landing cell, the raft site, every pick-up, palm and shaded cell reachable from the first landing cell (`reachable_from`); the landing's count, terrain and spread; every walk band (raft site, each POI anchor, the far end); and the layout reads with no problems.

For tests, `generate` takes an optional extra check (a `Callable` that returns failure messages) run after the built-in ones; nothing in the game passes one. The `report` lists every attempt with its failures and its POIs, so tests can see which attempt rolled what.

Attempts run 0 to `max_attempts − 1`, each with its own seeds (step 1), so every peer runs the same attempts and accepts the same one. From attempt `max_attempts − relaxed_attempts` on, rolled POIs are not rolled. If every attempt fails, the island is the chain's fallback island: the first valid attempt for run seed `fallback_seed` and index 0, given the requested island's id; `test_island_validation` proves that it validates, so a template edit that breaks it fails CI. Should even that fail at run time, its last attempt is used and the generator logs an error.

### 6. Determinism and the network

- **Inputs.** Run seed, island index, chain id and the template and POI files (the same build on every peer). Never the party size, the connected peers, the clock or the weather. Pick-up scaling (decision 7) and cosmetic variation happen after generation and never touch the layout or its hash.
- **No float decisions, no `hash()`.** Godot's `RandomNumberGenerator` (PCG32) gives the same integers for the same seed everywhere; `randi_range` is the only draw used for choices. SHA-256 is stable across platforms and versions.
- **Pinned hash.** A test pins the hash of island 3 of `reef_traps` for run seed 1. CI runs on Linux, development on Windows: any platform drift fails CI. The constant is re-recorded on purpose whenever the template or the algorithm changes.
- **Travel.** A layout's `next_island` may name a chain. `IslandSource.resolve(id, index, run_seed, catalog)` returns the handmade layout for an `islands` id or the generated one for a `chains` id (cached per run seed, chain and index). The host's `IslandTravel.travel` resolves first, then calls `travel_to(island_id, island_index, island_hash, arrivals, raft_integrity)`; `island_index` is the current index plus 1 (the sandbar is 1, the coast cay 2) and `island_hash` is empty for a handmade layout. `travel_to` accepts only the host's call with a known `islands` or `chains` id, an index from 1 to 8, a 64-character lowercase hex hash for a chain (empty for a layout) and well-formed arrivals. Every peer resolves the island from its own `run_seed` and compares the hash before landing anyone.
- **World state.** `join_extras` adds `island_index` (int) and `island_hash` (`StringName`); `island` is the chain id for a generated island. `follow` resolves the same way. `run-end`'s `islands` counter and `island_index` agree in a plain run; `island_index` is the number the seed uses.
- **Mismatch (decision 6).** A client whose hash differs logs a warning and asks the host once (`request_island`, any peer, rate-limited to one per island); the host answers with `receive_island(text)` (authority, reliable), the canonical text, which the client parses with a size limit (at most 128×128 cells, glyphs from the writer's alphabet, a legend that reads with no problems), checks against the host's hash and builds.
- **Captures.** "Previous island after capture" regenerates from the run seed: the same reference gives the same island.
- **Art.** `art-pass` keys cosmetic variants on a layout and cell hash; for a generated layout that should be `island_hash`, so variants differ between seeds and stay identical across peers.

### 7. Party scaling and the dawn refill

`SandbarIsland.place_pickups` (host only) reads the party size the creature spawner reads (`session.island_difficulty().players`, living and connected players). For a glyph with scaling below 1, it keeps `floor(cells × scaling^(players − 1))` of its cells, the first ones in reading order. Then, for each input of the `raft` recipe (read from `recipes/raft.tres`), if the island's placed units fall below the recipe's amount, cells of that item are put back in reading order until they reach it. Driftwood: 8, 6, 6, 6 for 1–4 players. Everything else on the reef is unscaled. Handmade layouts have no scaled glyphs and are unchanged.

The island listens to `WeatherManager.phase_changed`; when dawn begins and the session is the server, every taken pick-up whose respawn is DAILY is put back at its cell (pick-ups still lying there are not doubled), as the squall refill does for SQUALL. A client runs the handler but places nothing.

### 8. Solo

Nothing in generation reads the party. One offline player is the server: they generate, place every pick-up at ×1, and the dawn refill runs for them. Reach and walk bands are measured from the first landing cell, where a lone arrival stands. The raft is the guaranteed route: no background skill, no starting item, every input on the island.

## Scale

From the sandbar-size comparison (`openspec/changes/archive/2026-11-08-sandbar-size/design.md`): Brogue CE's map is 79×29 = 2,291 cells and DCSS's 80×70 = 5,600; a roguelike crossing of 80 columns is about 16 s at an assumed 0.2 s a turn (an estimate). Our sandbar is 80×72 with 991 land cells (17.2%) and a 90-tile arc (22 s at 4 tiles/s); the coast cay 88×64 with 1,021 (18.1%) and a 60-tile long axis (15 s). The reef keeps the doc's 96×64 (6,144 cells, DCSS-sized) with 1,000–1,300 land cells (16.3–21.2%) and its farthest land 9–22 s from the landing: the same size class, a little longer, with a 50–66 tile spine. The doc's "lighthouse ~45%" would be about 2,760 land cells on this grid, 2.8× the handmade islands; that is for the lighthouse template to decide (owner decision 3).

## Reference games (ideas and structure only; nothing copied or translated)

Read at `C:/Users/liann/src/90miles/reference/`.

**Brogue CE**
- **Borrowed: `Grid.c` `createBlobOnGrid`, `cellularAutomataRound`, `fillContiguousRegion`.** A blob is random fill, rounds of a birth/survival rule over the 8-neighbour count, then flood-fill labelling that keeps the largest region and retries until it meets its size bounds. We keep the labelling and "largest body wins" (step 5) and use cellular clustering for the interior rock patches (step 8); the landmass itself comes from heights so its land count can be exact.
- **Borrowed: `Architect.c` `createWreath` and `fillLakes`.** Deep liquid gets a wreath of shallow liquid of a fixed width by an integer radius test: our shallows band round the land (step 6).
- **Borrowed: `cleanUpLakeBoundaries` and `removeDiagonalOpenings`.** Repeated passes that remove one-cell irregularities and corner-only openings until nothing changes, with a failsafe count: our clean-up (step 5), capped at 20 passes, so the 4-connected reachability and the drawn coast agree.
- **Borrowed: `designLakes` and `lakeDisruptsPassability`.** A feature is proposed at a spot and accepted only if a flood fill shows the level stays connected, with a fixed number of placement attempts before giving up on it: each POI tries up to 20 anchors and keeps the first whose pieces fit (step 12).
- **Borrowed: `buildAMachine` (distance bounds from `distance25` and `distance75`, personal space through `occupied`, `levelIsDisconnectedWithBlockingMap`) and `addMachines` (failsafe loops).** A machine's features carry placement rules relative to an origin (near, far, in view), keep personal space, and must not disconnect the level. Our POI pieces are the same idea in data: an anchor, cell rules, "within" and "apart" distances. *Adapted:* our walk bands are seconds from the landing instead of percentiles of distance from the origin, because the owner sets walk times.
- **Borrowed: `RogueMain.c` (`startLevel`: up to 50 `digDungeon` attempts until `placeStairs` succeeds).** The cap of 50. *Rejected:* exiting the game when the cap is hit; we fall back to a proven island.

**Shattered Pixel Dungeon**
- **Borrowed: `levels/Patch.java` `generate` (fill, clustering passes, `forceFillRate`).** Clustering pushes fill rates towards all or nothing, so the fill is corrected by growing or eroding cells until the rate is met. We use that correction for the interior rock share (step 8) and the same "hit the count exactly" goal for the land, by rank instead of erosion (step 4).
- **Borrowed: `painters/RegularPainter.java` `paint`, `paintWater`, `paintGrass`.** Terrain is painted in ordered passes after the layout exists, each from its own patch map. Our bands are ordered passes over the landmass (steps 6–8).
- **Borrowed: `Dungeon.seedForDepth` and `Random.pushGenerator` in `Level.create` and `RegularLevel.createItems`.** A level's seed is derived from the run seed and the depth, and items are drawn from separate generators so that held items and progress never change the level. Our seed per (run seed, index, chain, attempt, stage) and the separate streams (step 1), so a new POI roll never moves the land. *Changed:* SHA-256 of the inputs instead of stepping one generator, so no stage depends on how many numbers another drew.
- **Borrowed, adapted: `builders/LoopBuilder.java` `setLoopShape`, `targetAngle`, `curveEquation`.** A whole level's outline follows one curve set by a few parameters. Our spine (step 2) is one bent line set by length, bend and width. *Rejected:* rooms, corridors and `FigureEightBuilder`'s two loops round a landmark room: open sand has no corridors to loop.
- **Rejected: `Level.create`'s `do … while (!build())` and `RegularLevel.build`'s retry until the builder returns rooms.** Both are unbounded; ours stops at 50 with a fallback.

**DCSS**
- **Borrowed: `dgn-shoals.cc` `dgn_build_shoals_level`, `_shoals_island_plan`, `_shoals_init_islands`, and `dgn-height.cc` `dgn_island_centred_at`, `dgn_island_plan::build_island`, `dgn_smooth_heights`.** The Shoals are an integer heightmap: island centres with many point bumps inside a radius, auxiliary centres at offsets, a border margin (`_shoals_margin`), smoothing passes, then features by height thresholds (`shoals_height_thresholds`: floor, shallow, deep). That is our landmass (steps 2–4) and edge margin, with two changes: centres follow a spine so the island is long and walkable, and the sea level is chosen by rank to hit a land count instead of a fixed threshold.
- **Borrowed, inverted: `_shoals_windshadows` and `_shoals_generate_wind_sheltered_plants`.** A wind direction is traced across the map to find sheltered cells. We trace rays from the coast to open water on the lee side to decide where the beach goes (step 7), so the beach faces away from the trade wind.
- **Borrowed: `dungeon.cc` `builder` (50 tries; when fewer than 5 remain, random vaults and minivaults are switched off) and `dgn_count_disconnected_zones` with `_dgn_fill_zone`.** Our cap, our relaxed last 5 attempts without rolled POIs, and our connectivity check.
- **Borrowed: `dat/des/builder/layout_cc.des` (`layout_shoals`).** The layout itself is a data entry (with depth and weight) that names a builder in code. `ChainData.layout_rule` names a painter the same way: a new chain with an existing painter is data only.
- **Borrowed: `random.h` `rng::subgenerator` (shop and item rolls isolated from level generation in `dungeon.cc`).** Same reason as SPD's separate generators.
- **Rejected for now: minivaults and vault stamps (`dat/des/`), `SUBST`, `ORIENT`.** A stamped block carries its own terrain, which fights a generated coastline and needs a second validation pass; the reef's POIs fit rules on top of the generated terrain. Stamps stay the likely tool for designed set pieces and the shipwreck interiors.

## Risks / follow-ups

- **GDScript speed.** About 6,144 cells, a few smoothing and clustering passes and several breadth-first searches per attempt: roughly 50–150 ms in GDScript with packed arrays. A run that hits rerolls costs a short pause at travel on every peer. If it is too slow, the first optimisation is fewer smoothing passes; the dev scene prints the time.
- **Trap pick-ups in shallows.** They sit beside rock so a player standing on the rock can reach them; taking one while swimming costs swim energy. The build checks a player on the shore cell can take a trap's rope.
- **Party floor tied to the raft recipe.** If the raft recipe changes, the floor follows it; if the guaranteed route stops being the raft on some chain, the floor needs that chain's route inputs (later).
- **Template tuning.** The shape parameters and bands interact; the 200-seed tests record the reroll rate. If it is above 2 attempts per island on average, the builder tunes the template (data), not the checks.
- **`island_seed`.** Left as the dev key it is; a later cleanup can drop it.
- **Later:** the other reef POIs as data when their items exist; the bluehole variant; the cave roof's sighting for the swim route; found texts and bottle notes; the resource rules' +4 driftwood after a squall; wiring generated islands into runs with the run graph.
