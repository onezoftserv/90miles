# Tasks

Every group is test-first: write the listed tests, watch them fail for the right reason, then build until they pass. Every group ends with these three commands passing (run the import twice on a fresh checkout):

- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`

## 0. Preconditions: escape-routes and coast-cay merged and archived

- [ ] 0.1 Confirm `escape-routes` is merged to `main` and archived (`openspec/changes/archive/*-escape-routes` exists and `openspec/specs/escape-routes/spec.md` holds its requirements); verify with `git log origin/main` and `openspec list`
- [ ] 0.1b Confirm `coast-cay` is merged and archived and `openspec/specs/island-generation/spec.md` holds its "Any handmade layout builds the island" requirement (the owner decided on 2026-11-08 that coast-cay owns that rule; this change no longer adds its own copy). If that requirement lacks "a layout with no workbench gets none", this change adds a MODIFIED delta for it that copies the full text and adds the clause
- [ ] 0.2 Re-read `game/scenes/ui/run_hud.gd` and `run_hud.tscn` as merged (not a gate; `ui-shell` need not be archived) and note any drift from design.md decisions 5 and 8 in its "Changes from the build plan" section; verify the day-phase label and `RunHud.bind(session, local_peer_id, solo)` are where design.md says
- [ ] 0.3 Branch `feat/secret-cay` from the updated `main`, re-read `island_layout_data.gd`, `island_layout.gd`, `sandbar_island.gd`, `coop_session.gd`, `crossing_stub.gd` and `game/resources/recipes/raft.tres` as merged, and note any drift from design.md in its "Changes from the build plan" section; verify the three commands pass on the untouched branch

## 1. Data: enums, fields, tuning and the four items

- [ ] 1.1 Write `game/tests/unit/test_secret_data.gd`: `ItemTag.SECRET` is the last `ItemTag` and `Capability.POINT_TO_SECRET` the last `Capability`; `secret_tuning.tres` loads as `SecretTuning` with every value in the "Secret tuning data" scenario, its `map_item_id` and `compass_item_id` resolve in the content catalog, the compass id has `POINT_TO_SECRET`, both have a reveal radius of 3, and `spot_hints_es` and `spot_hints_en` have a phrase for every spot kind plus `default`; the four items load with the tags, spawn weight 0, reveal radii, capability, Spanish and English names and texts of the "Secret items", "Secrecy", "The late note", "The note's voice" and "The red-band yarey hat" scenarios and of `docs/ITEMS.md` "Secret items" (compass line exactly "La única brújula que nunca te manda pa'l Norte."; the map's description in both languages holds the `{pista}` slot and no "palma"; 5 note entries with headings and bodies in both languages and empty soft bodies, every Spanish body has "jueves", exactly one, `el_sombrero`, mentions that the hat has an owner; hat head slot, heat gain ×0.7, no knock-off weather, description names no owner, English name "Yarey hat with a red band"); the compass has no `STEER` or `NAVIGATE_STREAM` and the map no `REVEAL_LAYOUT` or `REVEAL_ROUTES`; `driftwood` has no secret tag and radius 0. Verify it fails
- [ ] 1.2 Append `ItemTag.SECRET` and `Capability.POINT_TO_SECRET` at the end of their enums in `data_enums.gd`; add `ItemData.conceal_radius_tiles` and the `IslandLayoutData` fields `off_graph`, `secret`, `chest_glyph`, `chest_item_id` (with its `items` reference in `get_reference_fields`), `decor_glyphs` and `decor_colors`; verify `test_data_classes.gd` still counts 36 classes and 12 folders (update only its field samples if a new field type needs one)
- [ ] 1.3 Add `game/scripts/components/secret_tuning.gd` (`SecretTuning`) and `game/resources/secret_tuning.tres` with the values in design.md decision 1, the piece ids, the feature kinds and the Spanish and English spot hints exactly as written in `docs/ITEMS.md` "Secret items"; verify the tuning part of `test_secret_data.gd` passes
- [ ] 1.4 Add `game/resources/items/brujula_rota.tres`, `mapa_sin_norte.tres`, `sombrero_cinta_roja.tres` and `nota_llegaste_tarde.tres` (all with `spawn_weight = 0`; the note a TextData, category TEXT, tags [TEXT, SECRET], handwritten, RANDOM_ONE, not important, 5 entries with ids `llegaste_tarde`, `decomisado`, `la_cola`, `ni_el_norte`, `el_sombrero`, and the names, headings and texts in `docs/ITEMS.md`); add a content-validator rule that an item tagged `SECRET` has `spawn_weight` 0, with a failing case in the validator's tests; verify `test_secret_data.gd` and the content validator pass
- [ ] 1.5 Add `SecretRules.is_secret(entry)` and `SecretRules.without_secrets(entries)` (`game/scripts/secret/secret_rules.gd`; true for an item with the secret tag or a layout marked secret, and a filter that drops those entries) with the "One shared secret check" scenario ("The shared check and filter") in `test_secret_data.gd`, for later systems to call; verify it passes
- [ ] 1.6 Run the import, smoke run and GUT commands; verify all three pass

## 2. Existence roll

- [ ] 2.1 Write `game/tests/unit/test_secret_plan.gd` for the "Existence roll" scenarios: 3,000 seeds give 30–36% with the secret, every success has two different indices in 2–5 (the first for `map_item_id`, the second for `compass_item_id`), the same seed gives the same plan, chance 0 never and chance 1 always (tuning copies made in the test); verify it fails
- [ ] 2.2 Implement `SecretPlan.roll` (`game/scripts/secret/secret_plan.gd`) with its own seeded generator (design.md decision 2); verify `test_secret_plan.gd` passes and no other test changes
- [ ] 2.3 Run the import, smoke run and GUT commands; verify all three pass

## 3. The cay reuses the island scene; walking distances and hiding spots

- [ ] 3.1 Write `game/tests/unit/test_handmade_layouts.gd`, building on coast-cay's layout tests instead of repeating them: the cay's layout and the dev hunt layout each build the island scene with their own size, palms, coconuts and spawn points, and no workbench when the layout has none; `IslandLayouts.numbered(catalog)` returns the sandbar and never a layout marked off-graph; verify it fails
- [ ] 3.2 Reuse coast-cay's layout rebuild (do not add a second one); add the workbench in `furnish()` only when the layout has one, if coast-cay does not already; create `IslandLayouts.numbered(catalog: ContentCatalog) -> Array[IslandLayoutData]` in `game/scripts/levels/island_layouts.gd`, the one listing of numbered-island layouts, dropping any marked off-graph (design.md decision 6); verify `test_handmade_layouts.gd`, `test_sandbar_island.gd` and `test_sandbar_net.gd` pass
- [ ] 3.3 Add the dev hunt layout `game/scenes/dev/secret_hunt_layout.tres` (outside `resources/`; palms, flotsam, beach and dune pick-ups, two tide pools, solo and co-op spawns, sparse enough for the strict rule) and extend `test_island_layout.gd`: it builds with no problems; `walk_distances_from` matches hand-counted distances on a small inline layout, wades through shallows and never enters deep water; the strict `hiding_spots` of the hunt layout hold at least 2 cells, each a land cell reachable from the solo spawn, between the 50th and 85th percentile of land walking distance from it, 4–10 tiles from the nearest feature of a kind in `spot_feature_kinds` (the same list the code reads) and on no feature or spawn cell; a small inline layout whose land is all within 3 tiles of a palm or pick-up still returns at least one spot, through the fallback, and every one is reachable land on no feature or spawn cell; `spot_kind` names the nearest feature (a palm, a pick-up's group, a tide pool); verify it fails
- [ ] 3.4 Implement `IslandLayout.walk_distances_from`, `hiding_spots` with its fallback order, and `spot_kind` (design.md decision 3); verify `test_island_layout.gd` passes
- [ ] 3.5 Run the import, smoke run and GUT commands; verify all three pass

## 4. Concealment, shimmer and the pick-up hold

- [ ] 4.1 Write `game/tests/unit/test_world_item_conceal.gd` with 1 offline player: with a tuning copy whose shimmer length is 0, the concealed map draws nothing distinct at 5 tiles and draws normally at 3; with the shipped tuning and `shimmer_phase_s` set so a shimmer starts at 0 s, over 12 s at 15 tiles it starts a shimmer exactly twice (at 0 s and 6 s), each lasting 0.75 s; with the shimmer period set to 4 s in a tuning copy it shimmers every 4 s; a press or a 1 s hold takes nothing and a 1.5 s hold takes it; driftwood still picks up instantly; the host emits `taken` with the picker and the item id; verify it fails
- [ ] 4.2 Implement concealment, the shimmer with its settable phase, the hold from the tuning and the `taken` signal in `world_item.gd` (design.md decision 4); verify `test_world_item_conceal.gd` and every existing pick-up test pass
- [ ] 4.3 Run the import, smoke run and GUT commands; verify all three pass

## 5. The needle on the carrier's HUD

- [ ] 5.1 Write `game/tests/unit/test_compass_needle.gd` with 1 offline player: no needle without the compass; picking it up shows a 24×24 needle top-centre under the day phase, inside 640×360 and not overlapping the meters, the teammate list or the bottom band; it points due east and holds still at a concealed map 5 tiles due east, and spins at 0.5 turn/s once the map is carried; at straight-line distances of 44, 30, 15, 8 and 4 tiles it spins, wobbles within ±90°, ±45° and ±20° of the bearing, and holds still; one rattle on entering 40 tiles, a second only after leaving to 44 and returning to 38; with no concealed item and an unopened chest it points at the chest, and spins once the chest is open; it never targets an item someone carries; verify it fails
- [ ] 5.2 Implement `CompassNeedle` (`game/scenes/ui/compass_needle.gd` + `.tscn`) and bind it in `run_hud.gd` for the local peer only (design.md decision 5); verify `test_compass_needle.gd` and the existing HUD tests pass
- [ ] 5.3 Run the import, smoke run and GUT commands; verify all three pass

## 6. The cay layout, the chest and the note label

- [ ] 6.1 Extend `test_island_layout.gd` and write `game/tests/unit/test_chest.gd`: `cayo_sin_norte.tres` builds 48×27 with no problems, is off-graph and secret, has 3 palms holding 7 coconuts, its shade cells are the lean-to's, the hat lies on a lean-to cell, the chest is on a land (non-shallows) cell whose walking distance from the solo spawn is the greatest of any land cell, co-op spawns are within 5 tiles of each other at the south end, the embers, smoking stub, drag mark (reaching shallows) and cut line are present with a colour in `decor_colors` for each decor id, there is no workbench, the raft is its only route and every pick-up glyph has `respawn = NEVER`; its pick-ups cover every input of the raft recipe read from `game/resources/recipes/raft.tres` (never hard-coded), plus a knife and 1–2 rain cups; with 1 offline player the chest opens on a 1 s hold, exactly one note lies beside it, a second hold changes nothing, and the note label shows the chosen Spanish body for 6 s + 50 ms per character and then hides; verify it fails
- [ ] 6.2 Write `game/resources/islands/cayo_sin_norte.tres` (design.md decision 10) and draw its decor cells in their `decor_colors` in `SandbarIsland._draw`, with no per-id branch; verify the layout part of the tests passes and the content validator passes
- [ ] 6.3 Implement `Chest` (`game/scenes/structures/chest.gd` + `.tscn`) built in `furnish()` under the name `Chest`, the host-only opening, the entry pick by weight, the note spawned through `spawn_pickup`, the authority `receive_state` RPC with the host-only sender check, and the late-joiner push on `player_spawned` (design.md decision 7); verify `test_chest.gd` passes
- [ ] 6.4 Implement `NoteLabel` (`game/scenes/ui/note_label.gd`) in `run_hud.tscn` under the needle's place (design.md decision 8); verify the label part of `test_chest.gd` passes
- [ ] 6.5 Run the import, smoke run and GUT commands; verify all three pass

## 7. The hunt: dev scene and 1-player test

- [ ] 7.1 Write `game/tests/unit/test_secret_hunt_solo.gd` with exactly 1 player, offline, on the dev hunt layout and a fixed seed: both pieces lie on two different hiding spots, the same two cells when placed again from that seed; walking within 3 tiles reveals each; holding interact 1.5 s takes each; picking up the map shows its text with the compass's spot-kind phrase in the `{pista}` slot and no cell, and with the compass moved to a spot whose nearest feature is flotsam the shown text has no "palma"; with the compass carried the needle points at the map and steadies band by band as the player walks in; verify it fails
- [ ] 7.2 Implement `SecretHunt` (`game/scripts/secret/secret_hunt.gd`: host placement from the seed of the pieces named by the tuning, the compass's spot kind, the map's `taken` hook and the `show_map_text` RPC) and the dev scene `game/scenes/dev/secret_hunt_playground.tscn` + `.gd` with `--solo`, `--host[=port]`, `--join=address[:port]`, the panel, an instanced `run_hud.tscn` bound with `RunHud.bind(session, local peer id, solo)` once the local player spawns (as `GameShell._enter_run` does), `secret:` log lines and a time-to-find log; verify `test_secret_hunt_solo.gd` passes and the scene starts headless with `-- --solo`
- [ ] 7.3 Run the import, smoke run and GUT commands; verify all three pass

## 8. The cay: dev scene and 1-player test

- [ ] 8.1 Write `game/tests/unit/test_secret_cay_solo.gd` with exactly 1 player, offline, on the cay layout, the map and the compass put in the inventory first: the needle points at the chest; the chest opens once and the note label shows; the player takes the hat and a second hat never exists; starting again from an empty inventory with thirst and hunger at 50, the player picks up the knife and a rain cup, climbs a palm, drinks the rain cup and the coconut through `CoopSession.use_for`, and thirst and hunger both end above 50; the player takes every raft input, deposits it in the raft site, builds the raft alone and launches it, and leaves the island; verify it fails
- [ ] 8.2 Implement the dev scene `game/scenes/dev/secret_cay_playground.tscn` + `.gd` (same arguments and the same bound `run_hud.tscn` as the hunt, plus `--with-pieces`); verify `test_secret_cay_solo.gd` passes and the scene starts headless with `-- --solo --with-pieces`
- [ ] 8.3 Write `game/tests/unit/test_secret_dev_scenes.gd`: both dev scenes start solo offline with no port open and the player at the solo spawn, each holds a `RunHud` bound to the local player with its needle and note label, the hunt holds the concealed map and compass, and a solo run from the title still starts on the sandbar with no secret item placed; verify it passes
- [ ] 8.4 Run the import, smoke run and GUT commands; verify all three pass

## 9. Co-op: host and client

- [ ] 9.1 Write `game/tests/unit/test_secret_net.gd` (host plus one client, the existing net harness): both see the pieces on the same hiding spots; the client's player coming within 3 tiles reveals a piece on both peers; the client's 1.5 s hold puts the map in the client's inventory and removes it on both; the needle shows only on the carrier's HUD; the client's 1 s hold opens the chest on both with the same entry and one note; a client that joins after the opening sees the chest open with the same entry and no second note; two players reaching for the hat leave exactly one holder; a client that leaves holding the compass has it laid at its last position after removal, seen by the remaining peers; a client whose player left the island by a route (`left_island`) and then disconnects has nothing laid on the island; verify it fails
- [ ] 9.2 Drop a removed player's secret items in `CoopSession._remove_player` on the host, skipping a body with `left_island` (design.md decision 9), and fix whatever the net test finds; verify `test_secret_net.gd` and every existing `test_coop_session_*` test pass
- [ ] 9.3 Run a host and a client as two local processes in each dev scene (`-- --host` and `-- --join=127.0.0.1`), find both pieces and open the chest from the client; verify from the `secret:` log lines that both peers agree on the spots, the opening and the entry
- [ ] 9.4 Run the import, smoke run and GUT commands; verify all three pass

## 10. Integration and docs

- [ ] 10.1 Check `docs/ITEMS.md`, `docs/ISLANDS.md`, `docs/GAME_DESIGN.md` and `docs/CONTENT_MANIFEST.md` against the files built (ids, counts, names, hint phrases, note texts, the cay's contents and exceptions) and fix any drift; verify the counts match the files in `game/resources/items/` and `game/resources/islands/`
- [ ] 10.2 Search the change, the docs, the new `.tres` files and the commit messages for any franchise, character, nickname, emblem or catchphrase wording, and for the compass line the owner rejected in the 2026-11-06 decisions, in either language; verify the search finds nothing
- [ ] 10.3 Tick the `secret-cay` line in `TASKS.md` and add a "Done" entry with the GUT count; verify the three commands pass on the final branch

## Workflow follow-up

- Open a small PR for the branch (conventional commits), then archive the change after review, together with any follow-ups recorded in design.md.
- The "Later" items in design.md stay open in `TASKS.md` until their capabilities exist.
