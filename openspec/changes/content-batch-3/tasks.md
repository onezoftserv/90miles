# Tasks

Every group is test-first: write its tests, watch them fail for the right reason, then add the data until they pass. Every group ends with these commands passing (on a fresh checkout run the import twice):

- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit` (full GUT sparingly; a group may run its own scripts plus `test_item_icons.gd`, `test_art_tracked.gd`, `test_content_validator.gd`, `test_hud_text.gd` and `test_data_classes.gd`, and the full suite runs in 4.3)
- `python -I -m unittest discover -s tools/art -p "test_*.py"` whenever icons change

Known flake: `test_crossing_art.gd` "the scrolled sea still covers the crossing's sea"; rerun it alone.

## 0. Decisions and base

- [ ] 0.1 Record the coordinator's answers to Q1–Q10 in design.md ("Decisions waiting for the coordinator" becomes "Decisions", with the date), and adjust the item list, the specs and these tasks to them; verify `openspec validate content-batch-3 --strict` passes
- [ ] 0.2 Rebase on `origin/main` and re-read `item_data.gd`, `effect_data.gd`, `effect_applier.gd`, `item_icons.json` and `tools/art/test_items.py` as merged; note any drift in design.md; verify the three commands pass on the untouched branch

## 1. Drinks: still, well and seawater cups and rum

- [ ] 1.1 Write `game/tests/unit/test_food_items.gd` (content): a table of the batch's ids by category; for the drinks, each loads from the catalog with category water, Spanish and English names and descriptions that are not empty and differ, the doc numbers (still +40, well +30, seawater +10 then −30 over 120 s, rum thirst +5, morale +15, energy −10, thirst −10 delayed 60 s, durability 3), still and well cups have a second use that revives and can target others, and seawater and rum have no revive effect anywhere; the Cuban-speech rule (no "para" or "nada" as words; each Spanish description has a spoken contraction or Cuban word from a list kept in the test); the validator reports nothing under `items/`. Verify it fails because the files are missing
- [ ] 1.2 Write `game/tests/unit/test_food_items_solo.gd` (1 player, offline, a real `CoopSession` as in `test_use_button_solo.gd`): drinking a still cup takes thirst 40 → 80 and removes it; a well cup stands up a solo last stand at 30 health; rum and seawater used in a last stand change nothing and stay in the inventory; one rum swig gives morale +15 and energy −10, leaves 2 uses, and thirst falls by 10 once, 60 s later (meters ticked in a no-drain context); seawater gives +10 at once and −30 over 120 s. Verify it fails
- [ ] 1.3 Draw the four icons as hand sources in `tools/art/fixes/items/`, add "hand" entries to `tools/art/item_icons.json`, run `python -I tools/art/items.py`, and update `tools/art/test_items.py`'s icon count and `game/assets/art/items/License.txt`'s own-work list; verify the Python art tests, `test_item_icons.gd` (each icon distinct from `rain_cup` and from each other) and `test_art_tracked.gd` pass
- [ ] 1.4 Add `still_cup.tres`, `well_cup.tres`, `seawater_cup.tres` and `rum.tres` per design.md decision 1 (cups mirror `rain_cup.tres`; rum has no water tag); verify `test_food_items.gd` (drinks) and `test_food_items_solo.gd` pass
- [ ] 1.5 Run the import, smoke run and the scripts listed above; verify all pass

## 2. Foods

- [ ] 2.1 Extend `test_food_items.gd` for the foods: category food; hunger and thirst numbers per `docs/ITEMS.md`; meat and food tags per design.md; raw crab and raw fish carry poison as `APPLY_STATUS POISON`, meter health −20 over 30 s, chance 0.3 (canned food 0.2) and no `METER_ADD` with a chance below 1 that lowers a meter; `crab_raw` cooks into `crab_cooked` and `fish_raw` into `fish_cooked`, each in the agreed time, and the cooked forms have no poison effect; oysters' pick-up effect is bleeding, gated on the taker not having hand protection; canned food's eat use needs `OPEN_CAN` and spends a use; no food names a background, a weather or a missing item. Verify it fails
- [ ] 2.2 Extend `test_food_items_solo.gd`: eating 1 of 2 cooked fish takes hunger 40 → 75 and energy 40 → 50 and leaves 1; a can with no opener changes nothing; with a knife (if Q6 (a)) hunger rises by 30, energy by 10 and the knife has one use less. Verify it fails
- [ ] 2.3 Draw the food icons (raw and cooked pairs with different silhouettes), add them to `item_icons.json`, build them and update `test_items.py` and `License.txt`; verify the Python art tests, `test_item_icons.gd` and `test_art_tracked.gd` pass
- [ ] 2.4 Add the food files per design.md decision 1, as settled in 0.1 (`coco_plum` only if Q4 keeps it); if Q6 (a), add `OPEN_CAN` to `knife.tres`'s capabilities and assert it in `test_crafting_content.gd`'s knife test; verify `test_food_items.gd`, `test_food_items_solo.gd`, `test_crafting_content.gd` and `test_hud_text.gd` (the open-can phrase exists) pass
- [ ] 2.5 Run the import, smoke run and the scripts listed above; verify all pass

## 3. Unknown plants

- [ ] 3.1 Extend `test_food_items.gd` for the plants: category plant; each has an identify group (manzanillo, jagüey, uva caleta verde, hicaco, guanábana and noni fruit; hongo de playa mushroom; guao and tabaco silvestre herb) and the unknown tag; plants of one group share tags, stack size and weight; manzanillo's look is fixed to `fruta_verde`, its eat use takes health −50 over 60 s and sets a thirst ×2 drain multiplier for the agreed time; guao has no use and its pick-up effect is burning for 20 s; noni cures poison and heals 10; guanábana's spawn weight is below 1; the mushroom's two outcomes share one roll group with weights 0.4 (hallucinating 120 s) and 0.6 (hunger +10); wild tobacco smokes only with a lit fire within 2 tiles, for morale +10; no plant names a background. Verify it fails
- [ ] 3.2 Extend `test_food_items_solo.gd`: a solo player eats a guanábana (hunger 50 → 75, thirst 50 → 65, morale 50 → 60, energy +10); one tries to smoke wild tobacco with no fire and nothing happens. Verify it fails
- [ ] 3.3 Draw the plant icons, add them to `item_icons.json`, build them and update `test_items.py` and `License.txt`; verify the Python art tests, `test_item_icons.gd` and `test_art_tracked.gd` pass
- [ ] 3.4 Add the plant files per design.md decision 1; verify `test_food_items.gd` and `test_food_items_solo.gd` pass
- [ ] 3.5 Run the import, smoke run and the scripts listed above; verify all pass

## 4. Docs and the full run

- [ ] 4.1 Update `docs/ITEMS.md` (duplicates as settled in 0.1, counts, aloe as the sábila entry, the raw-food poison profile reused for canned food) and `docs/CONTENT_MANIFEST.md` (tick what shipped; name `aloe`; leave `milordo`, `toronja` and `bistec_toronja` to batch 11); verify every id in the manifest's water, food and plants lines either exists in `game/resources/items/` or is marked as batch 11
- [ ] 4.2 Update `TASKS.md`: tick content-batch-3; add to batches 1–2 (raw hutía and iguana loot), 4 (conch horn, pliers `OPEN_CAN`), 7 (red-tide oysters) and 9 (Pescador exemption on raw crab and fish, ex-militar spots wild tobacco) the rule each must add to this batch's items; add an "item effects runtime" change below the current milestone with the Gaps list of design.md; verify each logged line names the item and the rule
- [ ] 4.3 Run the import twice, the smoke run, full GUT and the Python art tests; verify all pass (rerun the known flake alone if it fails)

## Workflow follow-up

- Open a PR into `main` with the change, and report the link to the coordinating session when CI is green.
- Archive with `/opsx:archive` after the owner's review.
