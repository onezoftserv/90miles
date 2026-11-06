# Design

## Context

The shell builds the run in `GameShell._build_run()` from a `DevIsland` scene and sets the session's spawn points from it; it places no pick-ups. `DevIsland` is a `GridTerrain` from `DevIslandTerrain` drawn in colored rectangles. `WorldItem` has no network sync: a host-only free does not reach a client. Crafting requests name a station by a path relative to the session, so the hut's workbench has to sit at the same path on every peer. `WeatherManager.weather_changed(weather_id)` fires on every change, also on a client when the host's sky arrives. No tide exists. See proposal.md for the numbers and provisional decisions.

## Goals / Non-Goals

**Goals:** the layout is data; every behaviour in the spec is a GUT test with exact numbers, solo included; the host alone places and refreshes pick-ups.

**Non-Goals:** creatures, NPCs, escape routes, tides, generation, party scaling, UI.

## Decisions

### Layout format
A `.tres` of `IslandLayoutData`: `rows` (text), `terrain_glyphs` (every glyph in the rows has an explicit terrain), the glyphs for shade, palms, workbench, spawns and tide pools, and `pickups`, an array of `IslandGlyphData` (glyph → item, count, respawn trigger, group). `IslandLayout.build` reads it into a `GridTerrain` and lists, with no scene, so tests read the real file. `problems()` reports an unknown glyph, a row of another length, a missing spawn point or no palms. A scene of hand-placed nodes was rejected: it still needs a terrain source, and markers dragged around a scene cannot be checked by tests as easily. The content validator checks the item ids inside the glyph parts.

### Who places what
Terrain, palms and the workbench are built locally on every peer from the same data (the host's interaction runs the palm; a client never acts on a palm). Pick-ups are spawned by the host through `CoopSession.spawn_pickup`, a `MultiplayerSpawner` with a `spawn_function` that checks its payload (`name`, `item_id` StringName, `count` ≥ 1, finite position) the way `_spawn_player` does. Each pick-up is one unit, so a partial pick-up never desyncs a count; freeing the node on the host removes it on clients. The shell passes `as_client` into `_build_run`, because a joining client's session exists before its peer is set and would otherwise read as a host.

### Refresh
`SandbarIsland.furnish` listens to `WeatherManager.weather_changed` and remembers the last weather. When it leaves `squall` and the session is the server, every `respawn == SQUALL` pick-up whose node is gone is spawned again at its own cell. Hut loot is `NEVER`. A client runs the handler too but never places anything.

### Spawn points
Solo uses the `S` glyph (3 tiles from the hut). Co-op uses `1`–`4` in join order. The map was drawn so every pair among the four is 10–20 tiles apart; a test checks all six pairs, so every prefix of 2, 3 and 4 holds. Distance is Euclidean in tiles.

### Palm
`Palm` holds a coconut count, the climb effects and the hold time from the layout. The host-side interaction adds 1 `coco` to the climber's inventory first; only if it fit does the palm lose a coconut and the effects (energy −5) apply. Counts are not synced to clients.

### Solo
Everything above runs on the offline peer, which is the server. The hut knife opens coconuts (crafting-inventory "Using items").

### Reference games (ideas only; nothing copied or translated)
Studied at `reference/`.

- **DCSS vaults as data** (`crawl-ref/source/dat/des/arrival/simple.des`, `mapdef.h` `map_lines` with `subst`/`nsubst`/`keyed_mapspec`, `maps.cc` `find_map_by_name`, `random_map_for_tag`). **Borrowed:** a vault is a block of text rows between `MAP` and `ENDMAP` whose glyphs a legend turns into terrain and features, and `KFEAT`/`KITEM`-style keyed glyphs put a feature or item on that exact cell. That is the sandbar's format: `rows`, `terrain_glyphs` and keyed `IslandGlyphData`. A designer moves a palm by moving its letter. The layout is loaded by name (the `find_map_by_name` idea), through the content catalog. **Rejected for now:** `SUBST`/`NSUBST` random substitution, `TAGS`/`WEIGHT` selection and `ORIENT` mirroring: the sandbar is fixed and must hold exact counts (6 palms, 10 coconuts); randomizing belongs to the twin-bars variant and island-generation.
- **Brogue machines** (`src/brogue/Architect.c` `buildAMachine`; the feature flags in `Rogue.h` such as `MF_GENERATE_ITEM`, `MF_BUILD_AT_ORIGIN`, `MF_NEAR_ORIGIN`; the blueprint catalog in `Globals*.c`). **Borrowed:** a point of interest is a set of features that belong together (the hut = shade cells + workbench + loot; the flotsam line = items under one refresh rule), so each placed item records its `group` and a rule can apply to the set. **Rejected:** Brogue's runtime placement search (origin distance, blocking checks, retries): the hand layout already fixes every cell; that search is island-generation's job in Milestone C.
- **Shattered Pixel Dungeon** (`levels/painters/Painter.java` abstract `paint`, `levels/LastLevel.java` `build`, `Level.java` `createItems`, `drop`, `respawner`/`respawnCooldown`). **Borrowed:** the split between building the cells (`IslandLayout.build`, pure and testable) and drawing them (`DevIslandTerrain.draw`, reused), and a separate items step after the terrain (`createItems` → `SandbarIsland.place_pickups`, host only). **Rejected:** SPD's timer respawner (a cooldown for mobs): the sandbar refreshes on an event, a squall ending, as `docs/ISLANDS.md` says; and hard-coding the layout in code as `LastLevel.build` does with `Painter.fill` calls, which is what `DevIslandTerrain.fill` does today and what this change moves into data.

## Changes from the build plan

- Terrain for marker glyphs is explicit in `terrain_glyphs`; no separate `marker_terrain`.
- `IslandLayoutData.climb_hold_s` feeds `Palm.hold_s`; `IslandLayout` also lists the hut cells (`hut_cells`) for the shade check.
- `_build_run(as_client)`: the plan's `multiplayer.is_server()` test cannot tell a joining client from a host, because the client's peer is set after the session is built.
- The harness calls a session's setup after the session is in the tree, so the net tests furnish the island in the setup and place the host's pick-ups once its peer is open.
- The 32 planned tests were grouped into four files (`test_island_layout`, `test_palm`, `test_sandbar_island`, `test_sandbar_net`); the shell checks live in `test_sandbar_island`.
- `test_data_classes.gd` needed the new class and folder counts and a sample for a `PackedStringArray` field.

## Risks / Follow-ups

Tide (pools low-tide only), the shiny item, the bottle note, Experiencia +1 coconut or driftwood per level, party scaling (×0.8 driftwood), palm counts synced to clients for drawing, gull palms, throwing a coconut, removing `DevIsland`, and using `ChainData.spawn_scatter_tiles` when chain files exist.
