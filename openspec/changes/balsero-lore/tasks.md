# Tasks

Groups 1–5 are docs and specs, done in this change (no file under `game/` changes). Groups 6–10 are for later code and content changes and stay unticked. Every code group ends with the import, smoke run and GUT commands passing, and every requirement with players gets a 1-player, offline test.

## 1. Delta specs

- [x] 1.1 Write the five delta specs (escape-routes, crossing, creatures-ai, endings-progression, npcs-dialogue), copying every MODIFIED block whole from `openspec/specs/` and giving every new or changed requirement a scenario with exactly 1 player
- [x] 1.2 Verify `openspec validate balsero-lore --type change --strict` passes

## 2. Lore

- [x] 2.1 Write `docs/LORE.md`: the backdrop in our own words, every claim with its source URL, no real person's name, the usage rules, a table of where each lore item shows up
- [x] 2.2 Add the "Lore research notes, 2026-11-05" section to `docs/reviews/2026-11-05-repo-review.md` (Medalla, real names, the freighter slogan, the missing canonical year, open citations)

## 3. Design docs

- [x] 3.1 Update `docs/GAME_DESIGN.md` (era, §7 routes, §8 vessels and arrival, §13 epilogue lines, §14 keepsakes and Devuelto), `docs/ITEMS.md` (113 definitions), `docs/ISLANDS.md` (POIs, routes, set pieces 16–17, the piling and the final gull), `docs/BESTIARY.md` (galleguito, birds 36–39, 39 creatures), `docs/CHARACTERS.md` (Tomás, Ramón, Marisol, found texts) and `docs/ASSETS.md` (art for the car, board, gull, piling), and verify they agree with each other and with the delta specs
- [x] 3.2 Verify a search of `docs/` finds no real person's name in the new text and no song lyric

## 4. Manifest and task list

- [x] 4.1 Update `docs/CONTENT_MANIFEST.md`: new ids by folder, corrected counts (113 items, 22 recipes, 10 routes, 17 set pieces, ~50 POIs, 44 creatures, ~315 files) and the two batches
- [x] 4.2 Add content-batch-11 (19 files) and content-batch-12 (16 files plus entry edits) to `TASKS.md` §10, each within the 30-file cap, and extend the History and lore review in §11

## 5. Validation

- [x] 5.1 Verify `openspec validate --all` passes
- [x] 5.2 Verify `git diff --stat main...HEAD` shows only docs, `openspec/` and `TASKS.md`

## 6. Code: vessels (change `vessel-car-board`; Tier B)

- [ ] 6.1 Append `DataEnums.Vessel.CAR` and `Vessel.BOARD` (after `DOLPHIN_POD`); add the car sprite and one board sprite per rider to the crossing scene; review `CompanionData.allowed_vessels` (Marisol and Alfredo may ride the car, nobody who cannot swim the board)
- [ ] 6.2 Add `RouteData.arrival_scatter_tiles: Vector2i` (default (0, 5)) and apply it on arrival; `tabla` sets (10, 20) and stays on the beach
- [ ] 6.3 Per-rider boards in the crossing scene: integrity 60, squall and shark dump the rider, who self-climbs in 3 s; the board breaks at 0 and is lost on arrival
- [ ] 6.4 GUT tests: the integrity numbers (almendrón squall −45, board 60), a solo board rider dumped and climbing back, a solo arrival and a 3-rider scatter of 10–20 tiles, the almendrón's solo build (60 s with the pliers, 60 energy) and its fuel spend, `almendron_hundido` gating the chain rows after a solo capture
- [ ] 6.5 Verify the import, smoke run, GUT and a 300-frame run pass with no `ERROR:` lines

## 7. Code: creatures (change `creature-perch-ride`; Tier B)

- [ ] 7.1 Add `game/scripts/ai/ambient.gd` (songbird, booby, sperm whale, pelican) and a GUT test with 1 player
- [ ] 7.2 Append `CreatureData.Behavior.PERCH_RIDE` (after `TRADE_OR_ROB`) and `game/scripts/ai/perch_ride.gd`: head perch, turn with the player, shoo and re-land (solo circles, 5 s), wait overhead when its player falls in, theft once per 60 s at 50% from held food only, the most-food pick with the run-seed tie-break
- [ ] 7.3 GUT tests: the final crossing places the galleguito with 1 player and with 4 even when rolled threats are capped; +10 morale once per player; `galleguito_a_bordo` set once; the `pluma_galleguito` counter blocks theft on the galleguito and on the island gull; theft is held-only and at most twice in 120 s
- [ ] 7.4 Verify the import, smoke run, GUT and a 300-frame run pass with no `ERROR:` lines

## 8. Content batch 11, balsero gear (19 files)

- [ ] 8.1 Create the 10 items (`tanque_55`, `propela`, `bidon_combustible`, `tabla_surf`, `tabla_vela`, `toronja`, `bistec_toronja`, `azucar`, `milordo`, `camara_bici`) plus `botija`, the 4 recipes and `pluma_galleguito`; these do not need the new enums
- [ ] 8.2 Create the routes `almendron` and `tabla` and `llave_almendron` once group 6 lands (they use `Vessel.CAR` and `Vessel.BOARD`)
- [ ] 8.3 Verify the content catalog loads all 19, the import, smoke run and GUT pass

## 9. Content batch 12, balsero world (16 files plus edits)

- [ ] 9.1 Create the 5 POIs, the 2 set pieces, the 3 texts and `rabihorcado`; create `beat_pies_secos`
- [ ] 9.2 Create `galleguito` and `beat_galleguito` once 7.2 lands, and `pajarito` and `pajaro_bobo` once 7.1 lands
- [ ] 9.3 Edit existing entries: `bottle_note`, `wall_slogan`, `radio_fragment`, `diario_periodo_especial`, `seagull`, `la_captura`, the five ending dialogues, the chain route rows and `poi_chances`, and the loot of the fishermen's houses, the village dock, the resort generator and the galley, each with the lines in `docs/ITEMS.md`, `docs/BESTIARY.md` and `docs/GAME_DESIGN.md` §13 (Spanish first, English beside it, soft profanity variants where the line swears)
- [ ] 9.4 Verify the content catalog loads, the import, smoke run and GUT pass
- [ ] 9.5 When `backend/prompts/` is written, add the rule that the AI prompt bans the 1994 tugboat sinking (`docs/LORE.md`)

## 10. Review

- [ ] 10.1 The History and lore review (`TASKS.md` §11) checks `docs/LORE.md` and every balsero text against its sources, and decides entry 2 of *El sobre de tres generaciones*
- [ ] 10.2 The asset audit covers the car, the board, the gull and the other new rows in `docs/ASSETS.md`

## Workflow follow-up

- Still open elsewhere: the patrol plane and `cutter_us` (guardacostas-stealth), the three problems the user left in the existing docs, the canonical present year, and review item 29 (crossing durations and speeds, which keep these routes provisional).
- Archive this change only after groups 6–9 ship, then re-run `openspec validate --all`.
