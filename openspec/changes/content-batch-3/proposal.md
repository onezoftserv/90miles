# Proposal

## Why

Thirst and hunger are the game's clock, but the only things a player can drink or eat today are the coconut and the rain cup, and the only plant is aloe. `TASKS.md` §10 lists "content-batch-3: items water, food, plants" as the next content batch: the drinks, foods and unknown plants of `docs/ITEMS.md`, entered as data against the classes the project skeleton already defines, so that later changes (creature loot, POI loot, the identify game, cooking at a fire) have real items to point at.

## What Changes

- **27 new item files** in `game/resources/items/`, all `ItemData`, following `docs/ITEMS.md` and `docs/CONTENT_MANIFEST.md`:
  - Water (4): `still_cup`, `well_cup`, `seawater_cup`, `rum`.
  - Food (14): `crab_raw`, `crab_cooked`, `fish_raw`, `fish_cooked`, `lobster`, `oysters`, `conch`, `bird_eggs`, `sea_grapes`, `coco_plum`, `mango`, `hutia_cooked`, `iguana_cooked`, `canned_food`.
  - Unknown plants (9): `manzanillo`, `guao`, `jaguey`, `uva_caleta_unripe`, `hicaco`, `guanabana`, `noni`, `hongo_playa`, `tabaco_silvestre`.
  - Counts may drop by one or more depending on the coordinator's answers in design.md (for example `coco_plum` and `hicaco` are one fruit, `docs/ITEMS.md` lists it twice).
- **Already shipped, skipped:** `coco` and `rain_cup` (Milestone A), `aloe`, which is the manifest's `sabila` (coast cay). **Left to content-batch-11:** `milordo`, `toronja` and `bistec_toronja`, which `balsero-lore` task 8.1 builds with `azucar`.
- Every new item has a Spanish name and description in Cuban speech (pa', na', to', 'tá...), with English beside it that keeps the key slang, and a 16×16 icon, because the art-pass icon check fails any item file without one.
- Effects are written as the docs give them, using fields the data model already has: meter changes, poison and other statuses, chance rolls, cooking (`cooks_into`), the identify game (`identify_group`, `fixed_unknown_look`), pick-up harm. **No new field, enum value or script.**
- Several of those fields are not interpreted by the runtime yet (chance rolls, statuses with a meter, drain multipliers, effect conditions, pick-up effects, cooking, identification). They are listed as gaps for a later code change. The data is written so that nothing a player cannot yet roll is applied for sure: a poison risk is a status the runtime skips, never a certain health loss.
- References to content that does not exist yet (the Pescador background, the red-tide weather, the ex-militar, a conch horn, raw hutía and iguana) are left out and logged against the batch that creates the target.
- `knife.tres` may gain the can-opening capability, so canned food can be opened (see design.md).
- Docs: `docs/ITEMS.md`, `docs/CONTENT_MANIFEST.md` and `TASKS.md` record what shipped, the duplicates settled and the logged follow-ups.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-data`: adds the requirement that the water, food and plant items exist as validated data with Spanish-first names and descriptions in Cuban speech, and that a risk the runtime cannot roll yet is never written as a certain harm.
- `crafting-inventory`: adds what a single offline player gets from drinking and eating the batch's items (the numbers of `docs/ITEMS.md`, the meal energy, which cups revive and which never do).

## Impact

- Data: 27 `.tres` files in `game/resources/items/` (possibly fewer), possibly one capability added to `knife.tres`.
- Art: 27 icons in `game/assets/art/items/`, made by `tools/art/items.py` from `tools/art/item_icons.json`, with `License.txt` updated.
- Tests: a new content test for the batch and a 1-player test that eats and drinks new items, in `game/tests/unit/`.
- Docs: `docs/ITEMS.md`, `docs/CONTENT_MANIFEST.md`, `TASKS.md`.
- No script, scene, enum or autoload changes, so no overlap with the code sessions running now (net-platform-seam, structure-state-sync, creature-perch-ride, vessel-car-board, dead-spectate, intent-throttle).
- Follow-up (not in this change): a code change that interprets the effect fields this batch is the first to use.
