# Proposal

## Why

A run needs gear: the machete for the mangrove, the pliers for the wreck, the fins and the yarey hat for the sun and the swim. Of the 44 tools, materials and wearables in `docs/ITEMS.md`, only 12 ship today (the Milestone A kit, the coast cay's nails, mirror and binoculars, and the secret hat). `TASKS.md` §10 lists "content-batch-4: items tools, materials, wearables" next, with the conch horn and the pliers' can opener. It enters them as data against the classes the project skeleton already defines, so later changes (equipment, fishing, traps, weapons, recipes, POI loot, backgrounds) have real items to point at.

## What Changes

- **26 new item files** in `game/resources/items/`, all `ItemData`, following `docs/ITEMS.md` and `docs/CONTENT_MANIFEST.md`:
  - Tools (12): `machete`, `broken_bottle`, `spear`, `fishing_line`, `lure`, `net`, `snare`, `pliers`, `compass`, `charts`, `flint_steel`, `shovel_oar`.
  - The conch horn (1): `conch_horn`, the shell left when the last bite of a conch is eaten (noise radius 15).
  - Materials (5): `hardwood`, `line_spool`, `resin`, `cloth`, `tire`.
  - Wearables (8): `straw_hat`, `life_vest`, `wetsuit_top`, `fins`, `sandals`, `gloves`, `sunglasses`, `military_belt`.
- **Already shipped, skipped:** `knife`, `binoculars`, `mirror`, `lighter`, `driftwood`, `dry_grass`, `inner_tube`, `plastic_jug`, `rope`, `tarp`, `nails` and `sombrero_cinta_roja`. **Left to content-batch-11:** `tabla_surf`, `tabla_vela`, `tanque_55`, `propela`, `bidon_combustible`, `azucar` and `camara_bici`, which `balsero-lore` task 8.1 builds.
- `conch.tres` gains `durability` 1 and `remainder_item_id` `conch_horn`, so eating the last conch leaves the horn. Its description now mentions the shell.
- The pliers open cans (`OPEN_CAN`), each can spending one pliers use, as with the knife.
- Every new item has a Spanish name and a description in Cuban speech (pa', na', to', 'tá...), with English beside it that keeps the key slang. Each also has a 16×16 icon, because the icon check fails any item file without one.
- Effects are written as the docs give them, using fields the data model already has: capabilities, durability, equip slots, modifiers, weapon and fishing fields, trap catches, hit effects, and weather that knocks an item off. **No new field, enum value or script.**
- Today the runtime reads only part of this data: capabilities while carried, durability, the fast-tool time and remainders. It reads none of these:
  - equipping and worn slots;
  - modifiers;
  - weapons and hit effects;
  - fishing and traps;
  - navigation capabilities;
  - weather knock-off;
  - the horn's noise.

  Each is listed as a gap for a later code change. Some solo players get value today: the pliers open cans, the machete opens coconuts, flint and steel light a fire in 10 s, and the horn arrives after the conch.
- References to content that does not exist yet are left out and logged against the batch that creates the target:
  - hutía in the snare;
  - the creatures that read sandals, the spear and shiny items;
  - the `rock` and `stick` that the spear, snare and flint recipes need;
  - background starting kits.
- Docs: `docs/ITEMS.md`, `docs/CONTENT_MANIFEST.md` and `TASKS.md` record what shipped, the horn as a tool (tools 18 → 19, items 116 → 117) and the logged follow-ups.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-data`: adds the requirement that the tool, material and wearable items exist as validated data, Spanish first in Cuban speech. Gear behaviour the game cannot run yet is written as data, never as a script, and references only content that exists.
- `crafting-inventory`: adds what a single offline player gets from the batch today:
  - the pliers open cans;
  - the machete opens coconuts;
  - flint and steel light a fire in 10 s and never wear out;
  - the last conch leaves a horn.

## Impact

- Data: 26 `.tres` files in `game/resources/items/`, plus `durability` and `remainder_item_id` on `conch.tres`.
- Art: 26 icons in `game/assets/art/items/`, made by `tools/art/items.py` from `tools/art/item_icons.json`, with `License.txt` updated.
- Tests: a new content test for the batch and a 1-player test that opens a can with the pliers (no knife), in `game/tests/unit/`. `tools/art/test_items.py`'s icon count goes from 44 to 70.
- Docs: `docs/ITEMS.md`, `docs/CONTENT_MANIFEST.md`, `TASKS.md`.
- No script, scene, enum or autoload changes, so this does not overlap the code sessions running now (guardacostas-stealth, coop-rematch, crossing polish, run-structure).
- Follow-ups (not in this change), one code change each:
  - equipment and modifiers (the first equipment change that `TASKS.md` already names for the red-band hat);
  - player weapons;
  - fishing and traps;
  - navigation tools at sea;
  - the noise the horn makes, which belongs to the guardacostas noise bus.
