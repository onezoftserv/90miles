# Tasks

## 1. Spec

- [x] 1.1 Write proposal.md, design.md (with the reference study) and specs/island-generation/spec.md; `openspec validate sandbar-island --type change --strict` and `openspec validate --all` pass

## 2. Items

- [x] 2.1 RED: item cases in `test_island_layout.gd` (inner_tube, plastic_jug, rope load, names, tags, validate)
- [x] 2.2 GREEN: `items/inner_tube.tres`, `plastic_jug.tres`, `rope.tres`

## 3. Layout data and builder

- [x] 3.1 RED: `test_island_layout.gd` (parsing, counts, shade, spawns, distances, reachability, land share)
- [x] 3.2 GREEN: `IslandGlyphData`, `IslandLayoutData`, the catalog's `islands` folder, `IslandLayout.build`
- [x] 3.3 GREEN: `resources/islands/sandbar.tres`, the hand-drawn crescent

## 4. Island scene, palms, pick-ups

- [x] 4.1 RED: `test_palm.gd`, `test_sandbar_island.gd` (solo: palms, knife, coconut, refresh)
- [x] 4.2 GREEN: `Palm`, `SandbarIsland`, `CoopSession` pick-up spawner, dune color

## 5. Shell and network

- [x] 5.1 RED: shell cases in `test_sandbar_island.gd`, `test_sandbar_net.gd` (client pick-up, refresh seen by a client, co-op spawn spacing)
- [x] 5.2 GREEN: `GameShell` builds `SandbarIsland`; the two `DevIsland` spawn assertions updated
- [x] 5.3 Import, smoke, GUT and the 300-frame run are clean

## 6. Docs

- [x] 6.1 `TASKS.md`: tick the sandbar item, log the provisional numbers; `CONTENT_MANIFEST.md`

## Follow-ups

- [ ] Sync palm coconut counts when palms get an empty visual (today only the host's copy changes; every climb is applied on the host)
