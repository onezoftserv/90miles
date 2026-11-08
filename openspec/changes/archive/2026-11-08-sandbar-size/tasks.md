# Tasks

## 1. Tests first
- [x] 1.1 RED `test_island_layout.gd`: 80×72, 940–1,100 land cells, chain spawns, palms 20+ tiles from the hut, the raft site in reach, the 1-player walk test; `test_sandbar_net.gd`: hosted spawns 20–30 tiles from the next (6 tests fail on the old map)

## 2. The map
- [x] 2.1 GREEN `sandbar.tres`: new rows only (80×72, 991 land cells); `test_sandbar_island.gd` camera limits follow the new size

## 3. Docs and specs
- [x] 3.1 `docs/ISLANDS.md` §1 "Scattered landing": 20–30 tiles from the next in join order
- [x] 3.2 Spec delta (four MODIFIED blocks), proposal and design with the reference-games comparison
- [x] 3.3 `TASKS.md`: log entry (not archived)

## 4. Checks
- [x] 4.1 Import, smoke, GUT, 300-frame run, `openspec validate --all` and `sandbar-size --type change --strict`
