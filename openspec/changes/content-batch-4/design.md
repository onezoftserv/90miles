# Design

## Context

- Items are `ItemData` resources (`game/scripts/data/item_data.gd`). The data model already has every field this batch needs:
  - the `Equipment` group: `equip_slot` (NONE, HEAD, FACE, BODY, VEST, HANDS, FEET, WAIST), `capabilities`, `tool_action_time_s`, `modifiers` (`ModifierData`: stat, op, value, context, scope), `drops_in_weather_ids` and `blood_scent_when_carried`;
  - the `Weapon` group: `weapon_class`, `weapon_damage`, `weapon_reach_tiles`, `throw_mode`, plus `hit_effects`;
  - the `Fishing and Traps` group: `catch_per_use`, `trap_catches`;
  - `durability` and `remainder_item_id`.

  `DataEnums.Capability` already holds every capability the docs name for these items (CUT_PATH, SPEAR_FISH, LINE_FISH, NET_FISH, TRAP, PRY_NAILS, REPAIR, STEER, NAVIGATE_STREAM, REVEAL_LAYOUT, LIGHT_FIRE, DIG, BURY_STASH, HAND_PROTECTION, GLARE_PROTECTION, FLOAT_AT_ZERO_ENERGY...).
- The runtime reads only part of that:
  - **Capabilities.** `Inventory.capability_slot` counts any carried item. It ignores `equip_slot`, so "only while equipped" is not enforced, and nothing can be worn.
  - **Durability.** `uses_left`, `spend_use` and a remainder at the last use all work. `ItemUser.use` calls `spend_use` only when `durability > 0`; otherwise it removes the unit with `remove_id`, which never gives the remainder. That is why `coco.tres` has `durability` 1, and `conch.tres` needs it too.
  - **The fast tool.** `Crafter.recipe_time` uses a carried fast tool's `tool_action_time_s`.
  - **Nothing reads** `modifiers`, the weapon fields, `hit_effects`, `catch_per_use`, `trap_catches` or `drops_in_weather_ids`.
  - **Effects.** `EffectApplier` skips `NOISE`.
  - **Spawns.** No script reads `spawn_weight` except the secret-item check, so no tag spawn draws items today.
- Content that exists: creatures `land_crab`, `reef_shark` and `seagull`; weather `calm` and `squall`; recipes `fire`, `raft` and `rain_catcher`. There is no `hutia`, `rock`, `stick` or background yet. The validator fails any reference to a missing id.
- `CreatureCounterData` is "the home of sandals immunity": a creature's `ITEM_WORN` → `NEGATE` counter. The immunity therefore lives on the urchin, stingray and fire-ant files (creature batches), not on the sandals.
- HUD verbs (`hud_text.tres` `use_verbs`): `PLAY` reads "Tocar" / "Play", which is how one says *tocar el guamo*.
- Icons and their art checks are as in content-batch-3: `test_item_icons.gd` fails an item without a 16×16 icon that has its outline and a silhouette of its own, and `test_art_tracked.gd` checks the palette and `License.txt`. `tools/art/test_items.py` counts the recipe's icons (44 today).
- Shipped and skipped: `knife`, `lighter`, `mirror` and `binoculars` (tools); `driftwood`, `dry_grass`, `inner_tube`, `plastic_jug`, `rope`, `tarp` and `nails` (materials); `sombrero_cinta_roja` (wearable). `balsero-lore` task 8.1 builds `tabla_surf`, `tabla_vela`, `tanque_55`, `propela`, `bidon_combustible`, `azucar` and `camara_bici` in content-batch-11.

## Goals / Non-Goals

**Goals:**
- Every tool, material and wearable of batch 4, plus the conch horn, exists as validated data with an icon, Spanish first.
- The numbers match `docs/ITEMS.md` exactly where the doc gives them. Where it does not, first-pass numbers are marked as such.
- A solo offline player can use, today and through the existing use and craft paths, every new item whose behaviour already runs: the pliers on a can, the machete on a coconut, flint and steel at a fire, and the conch's shell. A test proves each one.

**Non-Goals:**
- No script, enum, scene or autoload change. Behaviour the runtime lacks is listed under "Gaps" for later code changes.
- No recipes: the spear, snare, flint and steel, sandals, gloves and resin recipes are content-batch-5's. Crafted gear only drops from sources until then.
- No item sources: POI loot, wrecks, background starting kits and NPC gifts each belong to their own batch.
- No backfill of shipped items. The knife has no description, and the mirror and binoculars carry no capabilities. That is listed, not changed (Q9).

## Decisions

### 1. The batch: 26 files

Every number is first-pass unless `docs/ITEMS.md` gives it. "Uses" is `durability`; "—" is 0, which means no counter and no wear. Every item has `spawn_weight` 1.0 (Q8).

**Tools (12, plus the horn).** Category TOOL, tag TOOL, stack 1, no equip slot (each works from any slot, as the knife does).

| id | tags | weight | uses | capabilities | weapon | other |
| --- | --- | --- | --- | --- | --- | --- |
| `machete` | tool, weapon | 1.5 | 60 | OPEN_COCONUT, CUT_PATH | BLADE 20 | |
| `broken_bottle` | tool, weapon, shiny | 0.3 | 5 | — | BLADE 8 | hit: `APPLY_STATUS BLEEDING` on the target, 10 s |
| `spear` | tool, weapon | 1.5 | 30 | SPEAR_FISH | SPEAR 12, reach 2 | the shark's nose hit is a creature counter (Q9) |
| `fishing_line` | tool | 0.2 | 25 | LINE_FISH | | |
| `lure` | tool, shiny | 0.1 | — | — | | modifier LINE_FISH_RATE ×2 (holder) |
| `net` | tool | 1.5 | 15 | NET_FISH, TRAP | | `catch_per_use` 3; `trap_catches` [land_crab] |
| `snare` | tool | 0.3 | 10 | TRAP | | `trap_catches` [land_crab]; hutía later (Q9) |
| `pliers` | tool | 0.5 | 50 | PRY_NAILS, OPEN_CAN, REPAIR | | modifier BUILD_SPEED ×1.5 (holder) |
| `compass` | tool | 0.2 | — | STEER | | |
| `charts` | tool | 0.1 | — | NAVIGATE_STREAM, REVEAL_LAYOUT | | |
| `flint_steel` | tool | 0.2 | — | LIGHT_FIRE | | `tool_action_time_s` 10 |
| `shovel_oar` | tool | 2.0 | 30 | DIG, BURY_STASH | | |
| `conch_horn` | tool | 0.5 | — | — | | use PLAY ("Tocar"), 1 s, repeatable: `NOISE` radius 15 at the player (Q3) |

**Materials (5).** Category MATERIAL, tag MATERIAL, no use.

| id | stack / weight | used in (docs) |
| --- | --- | --- |
| `hardwood` | 5 / 3.0 | mast, oars, stronger raft |
| `line_spool` | 5 / 0.1 | lines, snares, stitching |
| `resin` | 5 / 0.2 | sealing the wreck, waterproofing |
| `cloth` | 5 / 0.2 | gloves, bandages, sail patch |
| `tire` | 1 / 4.0 | sandals, raft fender |

**Wearables (8).** Category WEARABLE, tag WEARABLE, stack 1, no uses. Modifiers apply to the holder.

| id | slot | weight | capabilities | modifiers | other |
| --- | --- | --- | --- | --- | --- |
| `straw_hat` | HEAD | 0.3 | — | HEAT_GAIN ×0.7 | `drops_in_weather_ids` [squall] |
| `sunglasses` | FACE | 0.1 | GLARE_PROTECTION | — | tag shiny |
| `wetsuit_top` | BODY | 1.0 | — | SWIM_THIRST_FACTOR set 2.0 (in water); CORAL_DAMAGE ×0.5; HEAT_GAIN ×1.2 (on land) | |
| `life_vest` | VEST | 1.5 | FLOAT_AT_ZERO_ENERGY | SWIM_SPEED ×0.8 (in water) | "+buoyancy" is the float (data-model-questions 64) |
| `gloves` | HANDS | 0.2 | HAND_PROTECTION | — | the oyster cut already gates on it |
| `fins` | FEET | 1.0 | — | SWIM_SPEED ×1.3 (in water); WALK_SPEED ×0.7 (on land) | |
| `sandals` | FEET | 0.5 | — | — | the immunity is the creatures' `ITEM_WORN` counters (Q9) |
| `military_belt` | WAIST | 0.5 | — | INVENTORY_SLOTS +2 | |

**The conch.** `conch.tres` gains `durability` 1 and `remainder_item_id` `conch_horn`. Its Spanish and English descriptions gain the shell line in place of "no deja na' en el plato", which the horn now contradicts. The horn (0.5) weighs less than the conch (1.0), so swapping one for the other never pushes a player over the carry limit.

### 2. Encoding rules

- **The docs' words map onto existing fields, one to one.** "Weapon N dmg" is `weapon_damage`, "bleeding" a hit effect, "×N rate" or "−N%" a `ModifierData` multiply, "+2 slots" an add, "instead of ×3" a set, "on land" and "when swimming" the modifier's `context`. "Blows off in squalls" is `drops_in_weather_ids`, "traps crabs" is `trap_catches` and "per cast" is `catch_per_use`.
- **Nothing is invented.** A doc phrase with no field is not written as a hack: life-vest "+buoyancy", fins "must remove", cloth "your own shirt (heat +)" and the shark's nose hit. It is listed under Gaps or logged against the batch that can express it.
- **Capabilities only from the doc's "Use" column** (Q6). The machete gets no CRAFT_BLADE or CUT_NET, and the shovel-oar no ROW, until the owner says otherwise.
- **SHINY only where the doc says shiny** (Q7): broken bottle, lure, sunglasses. Whether a drawn machete shines is data-model-questions 33.
- **Wearables never wear out.** The docs give them no durability, and time-worn wear has no field (DST's Durability page; Q4).
- **Descriptions** say what the item does in play, so a player reading one learns its trade-off. Each Spanish description has a spoken contraction (pa', na', to', 'tá), none uses "para" or "nada", and swimming is written "nadar". English keeps the key slang: picúa, atarraya, guamo, pulóver, chancletas, espejuelos, el Norte.

### 3. Icons: own-work hand pixels through the existing tool (Q1)

As content-batch-3 did: each item gets `tools/art/fixes/items/<id>.png`, a 16×16 sketch near the palette drawn by a script in the scratchpad that uses `tools/art/png.py`, with no Pillow. Each gets a `"hand"` entry in `item_icons.json`, and `python -I tools/art/items.py --packs <main checkout>/game/assets` remaps it to the master palette, rims it and checks the box, outline and silhouette. The silhouette check compares exact alpha masks, so several pairs are drawn with different shapes, not only different colours:

- `straw_hat` and `sombrero_cinta_roja`: a wider, flatter brim with no chin cord;
- `fishing_line`, `line_spool` and `rope`: a hook on a can, a spool, a coil;
- `fins` and `sandals`;
- `cloth` and `tarp`;
- `compass` and `brujula_rota`.

`License.txt`'s own-work line names the 26 new files. The asset audit (`TASKS.md` §11) may replace them later; they are first-pass art.

### 4. Tests

- `test_gear_items.gd` (content):
  - every batch id loads, validates and has the right category, tags and both languages;
  - every Spanish description uses Cuban speech, and none uses "para" or "nada";
  - durability, capabilities, weapon numbers, slots and modifiers per the tables above;
  - the conch's remainder is the horn, and the horn's use is repeatable `NOISE` radius 15;
  - only the land crab is caught by the net and the snare;
  - shipped ids are untouched, and no batch-11 id exists;
  - the straw hat drops in a squall, and the red-band hat does not.
- `test_gear_items_solo.gd` (1 player, offline, a real `CoopSession` as in `test_food_items_solo.gd`):
  - the pliers open a can with no knife (hunger +30, pliers 50 → 49);
  - the machete opens a coconut with no knife (machete 60 → 59);
  - flint and steel make the fire recipe take 10 s of work and stay in the inventory, with no lighter carried;
  - eating 1 of 2 conchs leaves 1 conch and 1 horn, and eating the last leaves 2 horns.

  Every test uses only behaviour the runtime has, so the numbers are exact. Nothing calls the horn's use, whose `NOISE` the applier skips with a warning.
- `test_crafting_content.gd` gains the pliers' `OPEN_CAN` beside the knife's. `tools/art/test_items.py` counts 70 icons.

### 5. Docs

- `docs/ITEMS.md`:
  - the horn as a tools row (Tools 19, total 117);
  - a "Built by content-batch-4" note: first-pass numbers, the remainder, what is data until its runtime, and the sandals immunity living on creatures;
  - Counts.
- `docs/CONTENT_MANIFEST.md`: the tools, materials and wearables lines ticked with what shipped, what batch 11 builds, and `conch_horn`. Totals 117.
- `TASKS.md`:
  - tick batch 4;
  - log the follow-ups in batches 1–2 (sandals counters on urchins, stingray and fire ants; the spear's nose hit on sharks; hutía in the snare), batch 5 (`rock` and `stick` for the spear, snare and flint recipes) and batch 9 (starting kits);
  - list the runtime changes (equipment and modifiers, weapons, fishing and traps, navigation at sea) below the current milestone, beside `item-effects-runtime`.

## Decisions (owner, 2026-11-14: the recommended option (a) on all nine, through the coordinating session)

The options are kept as they were put; every answer is (a), so the table in decision 1 stands as written. The owner also asked that the two things found in passing (a remainder that does not fit is lost; a fast tool with no counter goes to −1 uses) be logged in `TASKS.md`.

- **Q1 Icons.** Every item file needs an icon or GUT fails.
  - (a) Hand-drawn own-work icons for all 26 through `tools/art/items.py`, as batch 3: first-pass art, no new licence.
  - (b) Cut from Kyrise (CC BY, already credited; it has hat, gloves, boots and sword cells) where one fits, with hand overlays, and hand-drawn for the rest; Kyrise credits updated.
  - (c) Another session draws them, and this one waits.
- **Q2 Gear the game cannot run yet** (see Gaps).
  - (a) Ship all 26 now as data. What runs today is the pliers on cans, the machete on coconuts, flint and steel at a fire, and the horn arriving. Wearing, modifiers, weapons, fishing, traps, navigation and the horn's noise wait for their code changes, each logged in `TASKS.md`.
  - (b) Ship only the items whose behaviour runs today (pliers, machete, flint and steel, horn, materials), and hold the rest until their runtime exists.
- **Q3 The conch horn.**
  - (a) Id `conch_horn`, named *Guamo* (the Cuban conch-shell trumpet). It is a TOOL with one repeatable "Tocar" use, `NOISE` radius 15 at the player, skipped until the guardacostas noise bus. `conch.tres` gets `durability` 1 and the remainder. Tools 18 → 19, items 116 → 117.
  - (b) The same horn counted as an oddity (15 → 16).
  - (c) The horn with no use until the noise bus exists.
- **Q4 Worn slots.**
  - (a) Hat HEAD, sunglasses FACE, wetsuit BODY, life vest VEST, gloves HANDS, belt WAIST. Fins and sandals share FEET, so a player chooses speed in the water or safe feet on the reef. Wearables never wear out.
  - (b) As (a), but the wetsuit and the life vest also share one slot (BODY): no swimming in both.
  - (c) As (a), plus wear while worn (DST's time-worn clothing). That needs a new field, so it is logged, not built.
- **Q5 Modifiers for the doc's numbers.**
  - (a) As in the table:
    - the lure's "×2 rate" is LINE_FISH_RATE ×2 while carried;
    - the pliers' "building ×1.5" is BUILD_SPEED ×1.5 while carried;
    - the wetsuit's "×2 instead of ×3" sets the swim thirst factor to 2.0;
    - "on land" and "when swimming" are the modifier contexts.

    How the pliers stack with the Mecánico's ×2 (data-model-questions 32) is left to the modifiers runtime.
  - (b) As (a), but leave the pliers' ×1.5 and the lure's ×2 out until data-model-questions 32 is settled.
- **Q6 Capabilities beyond the doc's words.**
  - (a) Doc only:
    - machete: OPEN_COCONUT and CUT_PATH;
    - shovel-oar: DIG and BURY_STASH;
    - net: NET_FISH and TRAP;
    - charts: NAVIGATE_STREAM and REVEAL_LAYOUT;
    - compass: STEER.
  - (b) Also give the machete CRAFT_BLADE and CUT_NET (a blade is a blade), and the shovel-oar ROW. Whether the oars recipe makes `shovel_oar` is data-model-questions 8.
- **Q7 Shiny.**
  - (a) Only the doc's shiny items: broken bottle, lure and sunglasses (plus the shipped mirror).
  - (b) Also the machete, a drawn blade flashing in the sun (data-model-questions 33).
- **Q8 First-pass numbers** (all in item data, tuned at the playtest):
  - the weights and stacks in the tables;
  - broken-bottle bleeding lasts 10 s (what bleeding does per second is data-model-questions 22, for `item-effects-runtime`);
  - "—" durability is 0, so the item never wears;
  - `spawn_weight` 1.0 everywhere, since nothing draws by tag yet.

  Alternatives: flint and steel wear out (for example 50 uses); the tire weighs 6 like the drum.
- **Q9 Follow-ups to other batches and backfills.**
  - (a) Log in `TASKS.md`:
    - batches 1–2: sandals `ITEM_WORN` → `NEGATE` counters on `urchin_field`, `stingray` and `fire_ants`; the spear's nose hit as a `WEAPON_HIT` counter on the sharks; `hutia` in the snare's catches;
    - batch 5: the missing `rock` and `stick` items for the flint, spear and snare recipes (data-model-questions 6);
    - batch 9: starting kits (machete and belt for the ex-militar, pliers for the Mecánico, the fishing line for the Pescador);
    - the knife's missing description and the mirror's and binoculars' missing capabilities as a small backfill.
  - (b) Add `rock` and `stick` now (2 more items), and backfill the knife, mirror and binoculars in this change.

## Gaps (surfaced, not decided)

For later code changes; none needs a new data field.

1. **Equipment.** There is no equip or unequip action and no worn-slot state. `capability_slot` counts carried items whatever their `equip_slot`, so gloves, sunglasses and the life vest would grant their capability from the pack once anything reads it. The red-band hat waits on the same change ("the first equipment change", `TASKS.md` §4). Fins' "must remove" is the unequip action.
2. **Modifiers.** No script reads `ModifierData`: heat gain, swim and walk speed, swim thirst, coral damage, inventory slots, build speed and the line-fish rate all do nothing yet. Stacking order is data-model-questions 32.
3. **Weather knock-off.** Nothing reads `drops_in_weather_ids`, so the straw hat never blows off.
4. **Weapons.** No player attack reads `weapon_class`, `weapon_damage`, `weapon_reach_tiles` or `hit_effects`, so the broken bottle never makes anyone bleed.
5. **Fishing and traps.** SPEAR_FISH, LINE_FISH, NET_FISH, `catch_per_use`, TRAP and `trap_catches` have no runtime.
6. **Navigation and other capabilities nobody reads yet.** STEER, NAVIGATE_STREAM and REVEAL_LAYOUT at sea (the `gulf_stream` route does not exist yet); CUT_PATH, DIG, BURY_STASH, PRY_NAILS, REPAIR, GLARE_PROTECTION and FLOAT_AT_ZERO_ENERGY.
7. **Noise.** `EffectApplier` skips `NOISE`, so the horn is silent. The noise bus is guardacostas-stealth's.
8. **A remainder that does not fit is lost.** `Inventory.spend_use` adds the remainder with `add`, which returns 0 on a full inventory or the weight limit. A horn with no room vanishes, and the HUD says nothing.

Found in passing, not changed here:

- A fast tool with no counter (flint and steel) leaves its slot's `uses_left` at −1 after a craft, because `Crafter` calls `spend_use` on it. That is harmless: the strip shows nothing for items with fewer than 2 uses, and the item stays. The tests do not assert it.
- The knife has no description, and the mirror and binoculars have no SIGNAL_DAY, SPOT_ISLANDS or REVEAL_ROUTES capability (Q9).

## Reference record (ideas only; nothing copied or translated)

- **Shattered Pixel Dungeon:**
  - **Borrowed:** `actors/hero/Belongings.java` keeps one field per worn place (`weapon`, `armor`, `artifact`, `misc`, `ring`), and `items/EquipableItem.java` `execute()` swaps an item in or out with `AC_EQUIP` / `AC_UNEQUIP`. That is a fixed set of named slots holding one item each, which is the shape of our `EquipSlot`. The swap action is the equipment change's.
  - **Borrowed:** in `items/weapon/missiles/MissileWeapon.java`, only thrown weapons wear (`MAX_DURABILITY`, `baseUses`, `durabilityPerUse()`), while melee weapons and armour never do. Here only items whose action spends them wear: tools with a number in ITEMS. Wearables, the compass and the charts never wear.
  - **Borrowed as a later idea:** `items/weapon/missiles/FishingSpear.java` `proc()` hits a water creature far harder. The spear's nose hit on a shark is the same idea, written as a creature counter in a later batch, not as item damage.
  - **Rejected:** `items/bags/Bag.java` `capacity()` and `VelvetPouch.canHold()` make containers that hold only one kind. The belt adds two general slots (INVENTORY_SLOTS +2), with no new UI.
  - **Rejected:** cursed gear that refuses to come off (`EquipableItem.doUnequip()` checks `cursed`). Fins are a cost you choose to take off, never a trap.
- **DCSS:**
  - **Borrowed:** in `item-prop.cc`, each row of `Armour_prop[]` gives an armour its slot (read by `get_armour_slot()`), its protection and its encumbrance penalty (`evp`). A wearable is its slot plus a benefit and a cost, all data. Ours pair the same way: fins trade water speed against walking, the wetsuit thirst against heat, the vest floating against speed.
  - **Borrowed:** the `ARMF_*` property flags that `armour_type_prop()` reads (fire, cold and poison resistance...) are named properties a worn item grants and other systems check. Our HAND_PROTECTION, GLARE_PROTECTION and FLOAT_AT_ZERO_ENERGY capabilities work the same way.
  - **Rejected:** DCSS has no item durability at all. Our tools wear because ITEMS gives them uses and scavenging pressure is the point.
  - **Noted:** `MI_THROWING_NET` in `Missile_prop[]` is a thrown net that pins a monster. Ours catches fish per cast and crabs overnight; pinning a creature is not in the docs.
- **Brogue CE:**
  - **Later (equipment change):** `equipItem()` (`Items.c`) puts the player in `STATUS_DONNING` for armour/10 turns, during which the armour counts for less (`recalculateEquipmentBonuses()`), and `Time.c` counts it down. Putting on a wetsuit or fins could take a few seconds the same way.
  - **Borrowed for the modifiers runtime:** `recalculateEquipmentBonuses()` recomputes worn bonuses when equipment changes, not every tick.
  - **Rejected:** strength requirements on armour (`armorTable` in `Globals.c`). There is no strength stat; weight against the limit of 30 is the cost.
- **Don't Starve Together** (dontstarve.wiki.gg pages Inventory, Durability, Backpack/DST and Overheating; project notes `REFERENCE_DST.md`, crafting-inventory "Equipment slots", "Durability", "Backpacks", and survival-meters "Temperature: overheating and freezing"):
  - **Borrowed:** worn slots each hold one item with a real trade-off (Inventory page). Our seven body slots come from the project skeleton, and the sun hat is the case our notes name.
  - **Borrowed:** the Durability page splits wear into four kinds: by use, by time worn, by damage soaked and by charges. Tools here wear by use. Clothing wearing out with time is rejected for now: no field, and the docs give no number (Q4).
  - **Borrowed:** clothing insulation divides the heat rise instead of blocking it (Overheating page), so the hat is HEAT_GAIN ×0.7, never immunity, and the wetsuit's ×1.2 on land is the cost side.
  - **Kept against DST:** "carried counts" for tools (REFERENCE_DST "Equipment slots"): no hand slot, so the pliers, machete and flint work from any inventory slot today.
  - **Rejected:** DST's body-slot backpacks (Backpack/DST page) take the armour slot. Our belt is WAIST, so it never competes with the vest or the wetsuit.
  - No DST value or text was copied.

## Risks / Trade-offs

- [Data written now, behaviour later: a reader may think the hat already cools or the belt adds slots] → The tests name it ("data until the equipment change"), the Gaps list it, and `TASKS.md` logs each runtime change.
- [Gloves, sunglasses and the vest will grant their capability from the pack once something reads it, before equipping exists] → Gap 1. The equipment change makes `capability_slot` honour `equip_slot`, and a test there must cover it.
- [The conch now has a use counter of 1] → It still stacks (items with at most 1 use stack), and the strip shows no counter for it, as for the coconut. Batch 3's conch test checks only its first use's effects, which do not change.
- [26 hand icons are rough] → They pass the art checks. The asset audit (§11) may replace them.
- [Another session edits `conch.tres` or the docs' counts] → Only batch 5 or 11 would touch these lines. A rebase keeps both.
- [The file cap] → 26 new data files plus one edited, under the 30-file content cap. Icons are art, not content files.

## Migration Plan

Data only: adding files changes nothing that exists, except `conch.tres`, which gains a use counter and the remainder. To roll back, delete the files, revert `conch.tres` and revert the docs.
