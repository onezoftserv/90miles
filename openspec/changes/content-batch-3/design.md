# Design

## Context

- Items are `ItemData` resources (`game/scripts/data/item_data.gd`). A use is an `ItemUseData` holding `ConditionData` checks and `EffectData` outcomes, and statuses come from `DataEnums.Status`. The data model already has every field this batch needs: `chance` and `roll_group`, `delay_s` and `duration_s`, effect `conditions`, `pickup_effects`, `cooks_into` and `cook_time_s`, `identify_group` and `fixed_unknown_look`.
- The runtime interprets only part of that model:
  - `EffectApplier` (`game/scripts/crafting/effect_applier.gd`) applies `METER_ADD`, `CURE_STATUS`, `REVIVE`, `GIVE_ITEM`, `TAKE_ITEM` and `START_ROUTE`. It warns once for any other kind and skips it.
  - It never reads `chance`, `roll_group`, `limit` or an effect's `conditions`.
  - `ConditionCheck` knows `HAS_CAPABILITY`, `LIT_FIRE_NEARBY` and a few more.
  - Nothing reads `pickup_effects`, `cooks_into` or `identify_group` yet.
  - A hunger-restoring `METER_ADD` is a meal (+10 energy).
- No `backgrounds/` folder exists. Weather has only `calm` and `squall`. The validator fails any reference to a missing id.
- `test_item_icons.gd` fails any item file without a 16×16 icon that has its outline and a silhouette of its own. `test_art_tracked.gd` requires every PNG to be referenced, to use palette colours and to be named in its folder's `License.txt`.
- Already shipped: `coco`, `rain_cup` and `aloe` (sábila). `balsero-lore` task 8.1 builds `milordo`, `toronja` and `bistec_toronja`.

## Goals / Non-Goals

**Goals:**
- Every water, food and plant item of batch 3 exists as validated data with an icon, Spanish first.
- The numbers match `docs/ITEMS.md` exactly where the doc gives them. Where it does not, first-pass numbers are marked as such.
- A solo offline player can drink and eat the new items through the existing use path, and a test proves it.

**Non-Goals:**
- No script, enum, scene or autoload change. Behaviour the runtime lacks is listed under "Gaps" for a later code change.
- No spoilage or freshness. The docs do not ask for it and no field exists.
- No item sources (POI loot, creature loot, the still and the well). Each belongs to its own batch or change.
- Not built here: feeding a teammate, Papo's rum need, the red tide.

## Decisions

### 1. The batch: 26 files

Each cell gives the effects of the first use. "Poison" means `APPLY_STATUS POISON`, meter health −20 over 30 s; that is the only documented poison profile (data-model-questions 22).

| id | cat. | tags | stack / weight | use (time) | effects | notes |
| --- | --- | --- | --- | --- | --- | --- |
| `still_cup` | water | water | 4 / 0.5 | drink 1 s | thirst +40 | 2nd use: revive a teammate, then thirst +40 (as `rain_cup`) |
| `well_cup` | water | water | 4 / 0.5 | drink 1 s | thirst +30 | 2nd use revives |
| `seawater_cup` | water | water | 4 / 0.5 | drink 1 s | thirst +10; thirst −30 over 120 s | no revive use |
| `rum` | water | — | 1 / 1.0, 3 uses | drink 1 s | thirst +5, morale +15, energy −10; thirst −10 after 60 s (Q8) | no water tag, like milordo; never revives |
| `crab_raw` | food | food, meat | 3 / 0.5 | eat 2 s | hunger +20; poison 30% | cooks into `crab_cooked`, 20 s (Q8) |
| `crab_cooked` | food | food, meat | 3 / 0.5 | eat 2 s | hunger +25 | |
| `fish_raw` | food | food, meat | 2 / 1.0 | eat 2 s | hunger +30; poison 30% | cooks into `fish_cooked`, 20 s |
| `fish_cooked` | food | food, meat | 2 / 1.0 | eat 2 s | hunger +35 | |
| `lobster` | food | food, meat | 2 / 1.0 | eat 2 s | hunger +35 | moray in the trap is the POI's |
| `oysters` | food | food, meat | 6 / 0.1 | eat 1 s | hunger +12, thirst +2 | pick-up: bleeding unless the taker has `HAND_PROTECTION` (effect condition, negated) |
| `conch` | food | food, meat | 2 / 1.0 | eat 2 s | hunger +25 | no remainder until the horn exists (Q5) |
| `bird_eggs` | food | food | 5 / 0.1 | eat 1 s | hunger +10 | |
| `sea_grapes` | food | food | 10 / 0.1 | eat 1 s | hunger +5 | |
| `mango` | food | food | 4 / 0.3 | eat 1 s | hunger +20, thirst +10 | |
| `hutia_cooked` | food | food, meat | 2 / 1.0 | eat 2 s | hunger +40 | |
| `iguana_cooked` | food | food, meat | 2 / 1.0 | eat 2 s | hunger +35 | |
| `canned_food` | food | food | 3 / 0.5 | eat 3 s | hunger +30; poison 20% | needs `HAS_CAPABILITY OPEN_CAN`, consume (spends a use, like coco) (Q6) |
| `manzanillo` | plant | food, unknown | 5 / 0.3 | eat 1 s | health −50 over 60 s; `DRAIN_MULTIPLIER` thirst ×2 for 60 s (Q8) | fruit group, look fixed `fruta_verde` |
| `guao` | plant | unknown | 5 / 0.1 | none | — | herb group; pick-up: `APPLY_STATUS BURNING` 20 s (data-model-questions 22: burning's damage is the status's, not the item's) |
| `jaguey` | plant | food, unknown | 5 / 0.3 | eat 1 s | hunger +15 | fruit group |
| `uva_caleta_unripe` | plant | food, unknown | 5 / 0.3 | eat 1 s | hunger +3, thirst −5 | fruit group |
| `hicaco` | plant | food, unknown | 5 / 0.3 | eat 1 s | hunger +8, thirst +3 | fruit group |
| `guanabana` | plant | food, unknown | 5 / 0.3 | eat 1 s | hunger +25, thirst +15, morale +10 | fruit group, `spawn_weight` 0.25 ("rare") |
| `noni` | plant | food, unknown | 5 / 0.3 | eat 1 s | hunger +5, health +10, cures poison | fruit group; no medicine tag, which would give it away |
| `hongo_playa` | plant | food, unknown | 5 / 0.1 | eat 1 s | roll group 1: hallucinating 120 s (weight 0.4) or hunger +10 (weight 0.6) | mushroom group |
| `tabaco_silvestre` | plant | unknown | 5 / 0.1 | smoke 5 s | morale +10 | herb group; needs `LIT_FIRE_NEARBY` within 2 tiles |

### 2. Encoding rules

- **A risk is a status, never a chance-gated loss.** Raw crab, raw fish and canned food carry poison as `APPLY_STATUS POISON`: meter health, amount −20, `duration_s` 30, `chance` 0.3 or 0.2. This is the "meter-bearing status" `EffectData.meter` documents. Today the applier skips `APPLY_STATUS`, so nobody is poisoned yet. A `METER_ADD` with `chance` 0.3 would instead poison every eater, because `chance` is not read. The mushroom's feed outcome is a `METER_ADD` with `chance`, so today it always feeds and never hallucinates. That is the benign direction, and it is listed under Gaps.
- **Plants of one identify group share tags, stack size and weight.** The fruit group is food and unknown, stack 5, weight 0.3. The herb group is unknown, stack 5, weight 0.1. Then nothing on the item gives its identity away before the identify runtime exists. Noni therefore has no medicine tag and guanábana no extra weight. The herb group's uses differ (guao has none, tobacco smokes); hiding uses of unidentified items is runtime work (Gaps).
- **Food that is meat** (crab, fish, lobster, oysters, conch, hutía, iguana) carries `MEAT` for the feral dogs. The sealed can does not.
- **Cups mirror `rain_cup`**: the first use drinks; the second use, `can_target_others`, is `REVIVE` on the use target and then the drink on them. Seawater and rum have only the first use.
- **Use times** are first-pass: cups and rum 1 s, small food 1 s, meat 2 s, the can 3 s, smoking 5 s. Each is the caller's hold, as for coco.
- **Stack sizes and weights** are first-pass, as data-model-questions 33 notes ("undocumented"). "Oysters (6)" and "Bird eggs (5)" are read as stack sizes (Q8).

### 3. Icons: own-work hand pixels through the existing tool (Q1)

Each item gets `tools/art/fixes/items/<id>.png`, drawn as a 16×16 palette-near sketch by a script in the scratchpad. It gets a `"hand"` entry in `tools/art/item_icons.json`, and `python -I tools/art/items.py` remaps it to the master palette, rims it and checks box, outline and silhouette. The generated PNGs land in `game/assets/art/items/`, Godot imports them, and `License.txt`'s own-work block names them. Raw and cooked pairs, the three new cups and the fruits get different silhouettes, because the silhouette check compares exact alpha masks. The asset audit (`TASKS.md` §11) may replace these icons later; they are first-pass art.

### 4. Tests

- `test_food_items.gd` (content):
  - every batch id loads and validates, with Spanish and English names and descriptions, the Spanish different from the English;
  - every Spanish description has a spoken contraction or Cuban word, and none has "para" or "nada";
  - the doc numbers per item; the revive structure (still and well cups revive, seawater and rum do not);
  - poison written as a chance-gated status; fruit-group tags, stack and weight equal; manchineel's fixed look;
  - raw→cooked links and cook times; no reference to backgrounds or red tide.
- `test_food_items_solo.gd` (1 player, offline, a real `CoopSession` like `test_use_button_solo.gd`):
  - drink a still cup: thirst +40;
  - eat a cooked fish: hunger +35 and energy +10;
  - a well cup stands up a solo last stand at 30;
  - rum and seawater do not;
  - canned food needs an opener and spends one knife use;
  - a rum swig takes 10 thirst once, 60 s later.

  Each test uses only effects the runtime interprets, so the numbers are exact.

### 5. Docs

- `docs/ITEMS.md`: the duplicates as settled, the counts, aloe as the sábila entry, a note that the poison profile is the raw-food one.
- `docs/CONTENT_MANIFEST.md`: tick the water, food and plants lines with what shipped, and what is left to batch 11.
- `TASKS.md`:
  - tick batch 3;
  - add the follow-ups to batches 1, 2, 4, 7 and 9: Pescador exemption, red tide, ex-militar on sight, conch horn, raw hutía and iguana;
  - add the "item effects runtime" code change below the current milestone.

## Decisions (owner, 2026-11-14: the recommended option (a) on all ten, through the coordinating session)

The options are kept as they were put; every answer is (a). Q1 adds that icons are hand-drawn through the `tools/art/` recipe or as overlays on the read-only packs, with no Pillow and the master palette only.

- **Q1 Icons.** Every item file needs an icon or GUT fails, and this session was scoped to item data, tests and docs.
  - (a) Hand-drawn own-work icons for all 26 through `tools/art/items.py`: first-pass art, no new licence.
  - (b) Cut from Kyrise (CC BY, already credited; it has fish, fruit, leaf, cup and potion cells) where one fits, hand-drawn for the rest, and the Kyrise credits updated.
  - (c) Another session draws them, and this one waits.
- **Q2 Runtime gaps** (list under Gaps).
  - (a) Write the data as the docs give it now, with risks as statuses so nothing is certain harm. A follow-up code change interprets the fields.
  - (b) Hold the risky items (raw crab and fish, canned food, oysters, manzanillo, guao, the mushroom) until the runtime exists.
- **Q3 `aloe` vs `sabila`** (data-model-questions 11).
  - (a) `aloe` is the sábila entry and stays known: the Médico starts with it and ISLANDS has "Dune with aloe". ITEMS.md moves sábila out of the unknown table (9 unknown plants), and the manifest names `aloe`.
  - (b) Aloe joins the identify game (herb group). That changes the shipped coast-cay requirement.
  - (c) Add a separate `sabila` file, a duplicate.
- **Q4 `coco_plum` and `hicaco` are one fruit** (data-model-questions 11; both "+8, thirst +3").
  - (a) One file, `hicaco`, as the unknown plant; drop `coco_plum`. Food 16→15, total 117→116, and GAME_DESIGN §6 "coco plum" stays as the fruit's English name.
  - (b) One file, `coco_plum`, as known dune food; drop `hicaco`, leaving 8 unknown plants.
  - (c) Ship both as listed.
  - Ripe sea grapes (known, +5) and unripe uva caleta (unknown, +3, thirst −5) differ, so both stay either way.
- **Q5 Content the items point at that no list has** (data-model-questions 6).
  - (a) Ship `conch` with no remainder and the two cooked meats as listed. Log the conch horn for content-batch-4 (tools; it then sets `conch.remainder_item_id`) and raw hutía and iguana for the creature batches, whose loot decides.
  - (b) Add `conch_horn`, `hutia_raw` and `iguana_raw` now: 3 more items and doc changes.
- **Q6 Opening cans.** ITEMS.md says "needs a knife to open", but the knife lacks `OPEN_CAN`, so nothing shipped can open a can.
  - (a) Add `OPEN_CAN` to `knife.tres`, spending one knife use per can, as coconuts do. The pliers get it in batch 4.
  - (b) Canned food stays unopenable until the pliers (batch 4).
- **Q7 Rules that need content not yet built:** the Pescador exemption (backgrounds, batch 9), red-tide 60% poison on oysters (weather `red_tide`, batch 7), the ex-militar spotting tobacco (batch 9).
  - (a) Leave them out now and log each in TASKS.md under its batch.
  - (b) Create stub `pescador`, `ex_militar` and `red_tide` files now. That is outside this batch.
- **Q8 Numbers the docs leave open** (first-pass, all in item data). Recommended:
  - rum's "thirst −10 after" lands at once, 60 s after the swig;
  - manzanillo's thirst ×2 lasts the same 60 s as its damage;
  - raw crab and fish cook in 20 s, like toronja;
  - "(6)" and "(5)" are stack sizes.

  Alternatives: rum's −10 spread over 120 s like seawater; manzanillo ×2 for 120 s; crab 15 s and fish 25 s; "(6)" and "(5)" as servings on one item.
- **Q9 Meal rule** (data-model-questions 32). Every hunger-restoring item gives +10 energy, so a sea grape (+5 hunger) is cheap energy.
  - (a) Keep the survival-meters rule and tune at the playtest.
  - (b) A meal needs at least 10 hunger; that is a survival-meters change.
- **Q10 Spoilage** (DST freshness).
  - (a) None in this batch, recorded as a later idea.
  - (b) Propose a spoilage change now: it needs a perish time, a timer, stages and container rates.

## Gaps (surfaced, not decided)

For a later code change, "item effects runtime". None needs a new data field.

1. `chance` and `roll_group` are never rolled. Today the mushroom always feeds, and poison never lands because it is a status.
2. `APPLY_STATUS` is skipped: poison with its meter, burning (guao), hallucinating (mushroom) and bleeding (oysters).
3. `DRAIN_MULTIPLIER` is skipped, so manchineel's thirst ×2 does nothing.
4. Effect `conditions` are not checked, so the oyster cut cannot honour gloves yet. It also cannot happen, because pick-up effects are not run.
5. `pickup_effects` are not applied: guao's burn and the oyster cut.
6. `cooks_into` and `cook_time_s` have no fire interaction.
7. Identification: looks, per-run shuffling, "first bite identifies the kind", hiding an unidentified item's name, verbs and description. The look pool has no home (data-model-questions 2).
8. `limit` is not claimed for items. creature-perch-ride's `RunRecord` (PR #46) claims `ONCE_PER_*` for creature effects and could serve items too.
9. A use refused by a condition that is not a tool reads the generic "Ahora no se puede." (`InventoryStrip.refusal_line`). Wild tobacco with no fire says that and does not name the missing candela. Naming it is HUD work.

Status magnitudes are also undefined (data-model-questions 22): what burning, bleeding and hallucinating do per second. That is a design question for the same change.

Found in passing, not changed here: `docs/ITEMS.md` gives coco "2 uses", while the shipped `coco.tres` has 1 and the spec says "the coconut is gone". The doc line probably means the two ways to use it (on yourself or on a teammate).

## Reference record (ideas only; nothing copied or translated)

- **Shattered Pixel Dungeon:**
  - **Borrowed:** `items/food/MysteryMeat.java` `effect()` makes one exclusive roll among bad outcomes and a no-op. The mushroom's `roll_group` and the raw-meat poison chance follow it.
  - **Borrowed:** in `items/Heap.java`, `burn()` turns meat in a burning heap into `ChargrilledMeat` with the same filling. Cooking here removes the risk and adds only a little food (+5), so the choice is "safe and slow, or risky and now".
  - **Borrowed:** `items/ItemStatusHandler.java` shuffles labels per run, and one use identifies the whole kind. Our `identify_group` and the per-run look come from this; the runtime is a gap.
  - **Rejected:** passive heap cooking (cooking is an explicit fire action) and `freeze()` (no frost in the Straits).
  - **Rejected:** `actors/buffs/Hunger.java` starving damage via `partialDamage`. Our hunger only caps energy, and thirst is the clock.
- **Brogue CE:**
  - **Rejected:** `decrementPlayerStatus()` (`Time.c`) ticks `STATUS_NUTRITION` down per turn, and `forceEatFood()` auto-eats. Auto-eating would spend items in real-time co-op.
  - **Later (generation):** `populateItems()` (`Items.c`) tracks `rogue.foodSpawned` against the `POW_FOOD` curve and forces food when a run falls behind. Fresh water, our real clock, could be metered the same way, but that is island generation, not items.
  - **Borrowed:** `shuffleFlavors()` names unknown kinds per run, which is our look pool.
  - **Later (runtime gap):** `tryIdentifyLastItemKind()` reveals the last unknown kind of a category.
- **DCSS:**
  - `crawl-ref/docs/changelog.txt`, 0.26.0: "Food and hunger are removed". Earlier releases automated eating step by step (auto-eat chunks, one-turn eating, rations only) until it held no decision. The changelog gives no reason, so linking it to tedium is our inference. 0.27 later added an explicit level timer instead.
  - **Borrowed as a check:** every food here poses a decision. Raw or cooked is risk against time. Unknown plants are a gamble. Rum and seawater trade now against later. The can costs a knife use. Nothing is a flat refill except the safe cooked meats, which cost a fire.
- **Don't Starve Together** (dontstarve.wiki.gg pages Food, Spoilage, Cooking, Meat, Monster Meat; project notes `REFERENCE_DST.md`, crafting-inventory and survival-meters sections):
  - **Borrowed:** food as several meter values at once, any of which may be negative. They are written as separate `METER_ADD` effects (hunger, thirst, morale, health).
  - **Borrowed:** quick per-item cooking at any lit fire (`cooks_into`).
  - **Considered, not adopted:** DST's small sanity cost for raw meat and none for cooked. A morale cost on raw meat would add numbers `docs/ITEMS.md` does not have; the owner may opt in later.
  - **Rejected for now:** freshness stages (fresh, stale, spoiled) that scale food values over time. The docs do not ask for them, and no field exists (Q10).
  - **Noted:** DST has no drinking water. The wiki's Thirst and Water pages do not exist. Our cups take nothing from DST.
  - No DST value or text was copied.

## Risks / Trade-offs

- [Data written now, behaviour later: a reader may think raw crab already poisons] → The tests name it ("poison is data until the effects runtime"), the Gaps list it and TASKS.md logs the runtime change.
- [The always-feeding mushroom makes the identify gamble safe for now] → Benign. It is fixed by the same runtime change, and noted.
- [26 hand icons are rough] → They pass the art checks. The asset audit (§11) may replace them.
- [Another session edits `knife.tres`] → Only batch 4 would; this batch adds one capability value, and a rebase keeps it.
- [The file cap] → The batch is 26 data files and 26 icon sources, under the 30-file content cap that `balsero-lore` uses per batch. Icons are art, not content files.

## Migration Plan

Data only: adding files changes nothing that exists, except `knife.tres`, which gains `OPEN_CAN`. To roll back, delete the files and revert the docs.
