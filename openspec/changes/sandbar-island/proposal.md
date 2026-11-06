# Proposal

## Why

Milestone A needs "two players on a handmade island". The shell's run still starts on `DevIsland`, a test beach with no loot. The first island of every run is *el banco de arena* (`docs/ISLANDS.md` §1); survival-meters' "Three solo days on the sandbar" needs its 10 coconuts, and crafting-inventory's coconut, knife, tarp, driftwood and workbench need a place to be found.

## What Changes

- `IslandLayoutData` (new content type, folder `game/resources/islands/`) and `IslandGlyphData` (a part): a hand-drawn map as text rows plus a glyph legend (terrain, shade, palms, workbench, pick-ups, spawn points, tide pools). Moving a palm or adding a jug edits only `sandbar.tres`.
- `IslandLayout` (pure logic): turns a layout into a `GridTerrain` and lists of placements.
- `SandbarIsland` scene replaces `DevIsland` in the shell's run (solo, host, client). `DevIsland` stays, unused by the shell (playgrounds use `DevIslandTerrain`).
- `Palm` scene: hold interact 2 s to climb; one coconut per climb; climbing costs energy.
- Pick-ups on the run island are spawned by the host through a new `PickupSpawner` in `CoopSession`, so clients see them appear and disappear.
- Flotsam and beach driftwood refresh when a squall ends (host only).
- Items `inner_tube`, `plastic_jug`, `rope` (`docs/ITEMS.md`, ids from `docs/CONTENT_MANIFEST.md`).

Out of scope: escape routes (raft, binoculars-and-swim, Ramón), gulls, crabs, man o' war, urchins and all creatures, la señora's camp and NPCs, "se vende balsa", patrols, bottle notes and texts, the random shiny item (no shiny item data exists), throwing a coconut at a palm, island generation, the twin-bars variant, tides, Experiencia bonuses, party-size scaling of counts, syncing a palm's coconut count to clients.

## Solo

Every rule here works offline with exactly 1 player: the solo spawn point is next to the hut, the palms and the hut's knife need no teammate, the flotsam refreshes on the same squall rule, and the shell's solo run opens no port. Solo tests: `test_sandbar_island.gd` (palms, knife and coconut, all 10 coconuts, refresh, the shell's solo run) and `test_palm.gd`; the layout reachability test starts from the solo spawn point.

## Provisional decisions

Taken from the build plan's recommended options; each waits for the owner's confirmation.

1. **Driftwood: 8 on the sandbar** (2 in the hut, 6 on the beach, refreshed after a squall), the `docs/ISLANDS.md` "Resource rules" base. Contradiction for the owner: survival-meters' "Three solo days" has the player at a fire each night, and 3 fires need 9 driftwood (and 3 tinder), so a solo player needs one squall refresh or the sandbar needs 9. Not silently changed. The "+4 after a squall, ×0.8 per extra player" rule is simplified to "put back what was taken", with no party scaling.
2. **Dry grass: 3** on the dune, never refreshed (tinder for the fire recipe; not in `docs/ISLANDS.md` §1).
3. **Coconuts: 10** over 6 palms in reading order (2, 2, 2, 2, 1, 1), the resource-rules base (the table range is 8–12).
4. **Palm climb:** a 2 s hold (the timed-interaction default), 1 coconut per climb, **5 energy** per climb, nothing paid on failure. No number exists in any doc.
5. **Map size 64×40 tiles** (1024×640 px), crescent opening east, land about 13% of the cells.
6. **Hut** 4×3 cells on the north point; the solo spawn is 3 tiles from it.
7. **Co-op spawns** are fixed glyph points, joined in order (host first), every pair 10–20 tiles apart (Euclidean, in tiles).
8. **Tide pools** are always there (no tide exists yet): 3 shallows cells on the south point.
9. **Items:** inner tube stack 2 / 2.0 kg, plastic jug stack 3 / 0.5 kg, rope stack 5 / 0.5 kg; Spanish names *Cámara*, *Pomo plástico*, *Soga*; the jug has no water storage yet.
10. **No shiny item and no bottle note** (no item data exists for either).

## Impact

`island-generation` (ADDED requirements only; the unarchived ui-shell, weather-daynight and crafting-inventory changes are not touched, so archive this one after them), `game_shell.gd`, `coop_session.gd/.tscn`, `content_catalog.gd`, `DevIslandTerrain.COLORS`, `docs/CONTENT_MANIFEST.md`, `TASKS.md`. Two existing tests pinned `DevIsland.SPAWN_POINTS` and the content-model counts (`test_game_shell.gd`, `test_lobby_screen.gd`, `test_data_classes.gd`) and were updated. No new autoload.
