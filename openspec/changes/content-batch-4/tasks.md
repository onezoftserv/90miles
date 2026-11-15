# Tasks

Every group is test-first: write its tests, watch them fail for the right reason, then add the data until they pass. Every group ends with these commands passing (on a fresh checkout run the import twice):

- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`. Run the full suite sparingly. A group may run only its own scripts plus `test_item_icons.gd`, `test_art_tracked.gd`, `test_content_validator.gd`, `test_crafting_content.gd`, `test_food_items.gd` and `test_data_classes.gd`, with `-gdir=res://tests/unit -gselect=<name>`. The full suite runs in 4.3.
- `python -I -m unittest discover -s tools/art -p "test_*.py"` whenever icons change

Known flake: `test_crossing_art.gd` "the scrolled sea still covers the crossing's sea"; rerun it alone.

## 0. Decisions and base

- [ ] 0.1 Record the coordinator's answers to Q1–Q9 in design.md: "Decisions waiting for the coordinator" becomes "Decisions", with the date. Adjust the item tables, the specs and these tasks to the answers, and verify that `openspec validate content-batch-4 --strict` passes
- [ ] 0.2 Rebase on `origin/main` and re-read `item_data.gd`, `modifier_data.gd`, `inventory.gd`, `item_user.gd`, `crafter.gd`, `conch.tres`, `item_icons.json` and `tools/art/test_items.py` as merged. Note any drift in design.md, and verify the three commands pass on the untouched branch

## 1. Tools that run today: pliers, machete, flint and steel, and the conch horn

- [ ] 1.1 Write `game/tests/unit/test_gear_items.gd` (content). It holds a table of the batch's ids by category. For every id it asserts:
  - the item loads from the catalog with its category and tags;
  - its Spanish and English names and descriptions are not empty and differ;
  - the Cuban-speech rule: no "para" or "nada" as words, and each Spanish description has a spoken contraction or Cuban word from a list kept in the test;
  - the validator reports nothing under `items/`.

  For the four tools that run today:
  - pliers: 50 uses, with PRY_NAILS, OPEN_CAN and REPAIR;
  - machete: 60 uses, OPEN_COCONUT and CUT_PATH, BLADE 20;
  - flint and steel: no counter, LIGHT_FIRE, tool time 10;
  - `conch.tres`: durability 1 and remainder `conch_horn`;
  - `conch_horn`: one repeatable PLAY use whose only effect is `NOISE` radius 15.

  Verify it fails because the files are missing.
- [ ] 1.2 Write `game/tests/unit/test_gear_items_solo.gd`: 1 player, offline, a real `CoopSession` as in `test_food_items_solo.gd`.
  - With pliers and no knife, a can takes hunger 40 → 70 and the pliers 50 → 49 uses.
  - With a machete and no knife, a coconut is drunk and the machete goes 60 → 59.
  - With flint and steel, three driftwood, dry grass and no lighter, `recipe_time` for the fire is 10 s; after the site is built, the flint is still carried.
  - Eating 1 of 2 conchs leaves 1 conch and 1 horn; eating the last leaves 2 horns.

  Verify it fails.
- [ ] 1.3 Draw the four icons (pliers, machete, flint and steel, conch horn; the conch keeps its own) as hand sources in `tools/art/fixes/items/`. Add "hand" entries to `tools/art/item_icons.json`, run `python -I tools/art/items.py --packs <main checkout>/game/assets`, and update `tools/art/test_items.py`'s icon count and `License.txt`'s own-work list. Verify that the Python art tests, `test_item_icons.gd` and `test_art_tracked.gd` pass
- [ ] 1.4 Add `pliers.tres`, `machete.tres`, `flint_steel.tres` and `conch_horn.tres` per design.md decision 1, and give `conch.tres` its durability, remainder and new description lines. In `test_crafting_content.gd`, assert the pliers' `OPEN_CAN` beside the knife's. Verify that `test_gear_items.gd` (these four), `test_gear_items_solo.gd`, `test_crafting_content.gd` and `test_food_items.gd` (conch) pass
- [ ] 1.5 Run the import, the smoke run and the scripts listed above; verify all pass

## 2. The other tools and the materials

- [ ] 2.1 Extend `test_gear_items.gd` for the other eight tools and the five materials.
  - Durability per `docs/ITEMS.md`: bottle 5, spear 30, line 25, net 15, snare 10, shovel-oar 30; lure, compass and charts have no counter.
  - Capabilities per design.md (doc only, as settled in 0.1).
  - Weapon class, damage and reach: bottle BLADE 8, spear SPEAR 12 reach 2.
  - The bottle's hit effect is bleeding on the target. The lure's modifier is LINE_FISH_RATE ×2.
  - The net catches 3 per cast, and both net and snare trap only `land_crab`.
  - SHINY on the bottle and the lure only.
  - Every material is MATERIAL with no use, and its stack and weight match the table.

  Verify it fails
- [ ] 2.2 Draw the 13 icons (8 tools, 5 materials). `fishing_line`, `line_spool` and `rope` get different shapes, and so do `cloth` and `tarp`, and `compass` and `brujula_rota`. Add them to `item_icons.json`, build them, update `test_items.py` and `License.txt`, and verify that the Python art tests, `test_item_icons.gd` and `test_art_tracked.gd` pass
- [ ] 2.3 Add the 13 files per design.md decision 1; verify `test_gear_items.gd` passes for them
- [ ] 2.4 Run the import, the smoke run and the scripts listed above; verify all pass

## 3. Wearables

- [ ] 3.1 Extend `test_gear_items.gd` for the eight wearables:
  - category WEARABLE, tag WEARABLE, stack 1, no counter;
  - slots per design.md (as settled in 0.1); fins and sandals share FEET;
  - the modifiers with their contexts per the table;
  - capabilities: gloves HAND_PROTECTION, sunglasses GLARE_PROTECTION, life vest FLOAT_AT_ZERO_ENERGY;
  - the straw hat drops in `squall`, and `sombrero_cinta_roja` drops in no weather;
  - the sunglasses are SHINY;
  - the sandals carry no immunity of their own.

  Verify it fails
- [ ] 3.2 Draw the eight icons. The straw hat gets a silhouette different from the red-band hat's, and the fins one different from the sandals'. Build them, update `test_items.py` (70 icons) and `License.txt`, and verify that the Python art tests, `test_item_icons.gd` and `test_art_tracked.gd` pass
- [ ] 3.3 Add the eight files per design.md decision 1; verify `test_gear_items.gd` passes in full
- [ ] 3.4 Run the import, the smoke run and the scripts listed above; verify all pass

## 4. Docs and the full run

- [ ] 4.1 Update `docs/ITEMS.md`:
  - the conch horn as a tools row and in the food table's conch note;
  - Tools 19, Counts 117;
  - a "Built by content-batch-4" note: first-pass numbers, what is data until its runtime, and the sandals immunity on creatures.

  Update `docs/CONTENT_MANIFEST.md`: tick the tools, materials and wearables lines with what shipped and what batch 11 builds, add `conch_horn`, and set the totals to 117. Verify that every id in those three lines exists in `game/resources/items/` or is marked as batch 11
- [ ] 4.2 Update `TASKS.md`:
  - tick content-batch-4;
  - add to batches 1–2 the sandals counters (urchins, stingray, fire ants), the spear's nose hit on sharks and hutía in the snare;
  - add to batch 5 `rock` and `stick` for the flint, spear and snare recipes;
  - add to batch 9 the starting kits;
  - add the runtime changes below the current milestone, beside `item-effects-runtime`: equipment and modifiers, player weapons, fishing and traps, navigation at sea and the horn's noise.

  Verify that each logged line names the item and the rule
- [ ] 4.3 Run the import twice, the smoke run, full GUT and the Python art tests, and run the main scene headless; verify all pass (rerun the known flake alone if it fails)

## Workflow follow-up

- Open a PR into `main` with the change, and report the link to the coordinating session when CI is green.
- Archive with `/opsx:archive` after the owner's review.
