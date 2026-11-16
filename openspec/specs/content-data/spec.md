# content-data Specification

## Purpose
Keeps all game content (creatures, items, recipes, NPCs, dialogue, island chains, POIs, set pieces, routes, backgrounds, weather, texts and keepsakes) as typed, validated data files, so content is added or tuned without changing code.

## Requirements

### Requirement: One content type per content folder
Each content folder listed in the content manifest SHALL have exactly one content type, and every content file in that folder SHALL be of that type.

#### Scenario: Content file matches its folder
- **WHEN** the content check loads every file in the creatures folder
- **THEN** each file is a creature definition and the check passes

#### Scenario: Wrong type in a folder
- **GIVEN** an item definition saved in the creatures folder
- **WHEN** the content check runs
- **THEN** it fails and names that file and the expected type

### Requirement: Content is identified by its file name
Every content file SHALL carry an id equal to its file name without extension, and ids SHALL be unique within a content type.

#### Scenario: Id matches file name
- **WHEN** the file `reef_shark` in the creatures folder is loaded
- **THEN** its id is `reef_shark`

#### Scenario: Mismatched id
- **GIVEN** a creature file named `reef_shark` whose id is `bull_shark`
- **WHEN** the content check runs
- **THEN** it fails and names the file and both ids

### Requirement: Spanish-first names
Every content entry that has a player-visible name SHALL have a Spanish name. When the English name is empty, the English text SHALL fall back to the Spanish name.

#### Scenario: Missing Spanish name
- **GIVEN** an item file with an empty Spanish name
- **WHEN** the content check runs
- **THEN** it fails and names the file

#### Scenario: English falls back to Spanish
- **GIVEN** an item with Spanish name "Coco" and no English name
- **WHEN** its English name is requested
- **THEN** "Coco" is returned

### Requirement: References between content resolve
Content SHALL refer to other content by id, and every referenced id SHALL exist in the content type it points to.

#### Scenario: Valid reference
- **GIVEN** a recipe that needs `driftwood` and an item file `driftwood` exists
- **WHEN** the content check runs
- **THEN** the reference passes

#### Scenario: Dangling reference
- **GIVEN** a recipe that needs `driftwod` and no such item exists
- **WHEN** the content check runs
- **THEN** it fails and names the recipe, the field and the missing id

### Requirement: New content needs no code change
Content SHALL be discovered by folder at runtime, in the editor and in exported builds, so a valid new content file is available without editing any script.

#### Scenario: Add a creature
- **GIVEN** the project with no `hutia` creature
- **WHEN** a valid `hutia` file is added to the creatures folder
- **THEN** the content catalog lists `hutia` and returns its definition with no script edited

#### Scenario: Exported build
- **WHEN** an exported build lists the creatures folder
- **THEN** it returns the same ids as the editor build

### Requirement: Water, food and plant items as data
The water, food and unknown-plant items `docs/ITEMS.md` lists SHALL each be one item file in the items folder that passes the content check, with the effect numbers the doc gives. Items that `docs/CONTENT_MANIFEST.md` gives to another batch, and items already shipped, are not duplicated. No script changes to add them.

#### Scenario: The batch loads and validates
- **GIVEN** the project with this batch's item files
- **WHEN** the content check runs
- **THEN** every water, food and plant item of the batch is listed by the content catalog, and the check reports no problem for any of them

#### Scenario: One file per item
- **GIVEN** the aloe already shipped as `aloe`, and the coco plum, which is the plant `hicaco`
- **WHEN** the items folder is listed
- **THEN** there is no `sabila` file beside `aloe` and no `coco_plum` file beside `hicaco`, and this batch adds no grapefruit, grapefruit steak or milordo, which the balsero gear batch builds

### Requirement: Spanish first, in Cuban speech
Every item of the batch SHALL have a Spanish name and a Spanish description, with English beside both. Spanish descriptions use spoken Cuban contractions (pa', na', to', 'tá) where the speech allows, never textbook "para" or "nada"; English keeps the key slang untranslated.

#### Scenario: Names and descriptions in both languages
- **WHEN** any item of the batch is loaded
- **THEN** its Spanish and English names and descriptions are not empty, and its Spanish description differs from its English one

#### Scenario: Spoken contractions
- **WHEN** the Spanish descriptions of the batch are read
- **THEN** none contains the word "para" or "nada", and each contains a spoken contraction or a Cuban word from the project's list

### Requirement: Unknown plants hide what they are
Each unknown plant of the batch SHALL belong to an identify group (fruit, mushroom or herb) and carry the unknown tag. Plants of one group SHALL carry the same tags, stack size and weight, so none of these tells a player which plant it is before it is identified. Manchineel always shows the green-fruit look.

#### Scenario: Same tags, stack and weight inside a group
- **GIVEN** the batch's unknown fruits, among them manchineel, noni and guanábana
- **WHEN** their tags, stack sizes and weights are compared
- **THEN** every one carries the same tags, stack size and weight, and every one carries the unknown tag

#### Scenario: Manchineel's fixed look
- **WHEN** the manchineel item is loaded
- **THEN** it is in the fruit group and its look is fixed to the green fruit

### Requirement: Risks the game cannot roll yet are never certain harm
An item risk that the docs give as a chance (raw crab and fish poison, canned food poison, the beach mushroom's hallucinations) SHALL be written as a chance-gated status, not as a certain meter loss, so that a game that does not yet roll chances skips the risk instead of applying it every time.

#### Scenario: Raw crab
- **GIVEN** the raw crab item
- **WHEN** its eat use is read
- **THEN** it restores 20 hunger, and its poison is a status with a 30% chance that takes 20 health over 30 s, never a health loss without a chance

### Requirement: References only to content that exists
The batch's items SHALL refer only to content that is shipped. A rule that needs content not yet built (the Pescador's exemption from raw-food poison, red-tide oysters, the ex-militar spotting wild tobacco, the conch horn, raw hutía and iguana) is left out and logged in `TASKS.md` under the batch that builds that content.

#### Scenario: No dangling reference
- **WHEN** the content check runs over the batch
- **THEN** no item of the batch names a missing background, weather, item or creature

#### Scenario: The follow-ups are logged
- **WHEN** `TASKS.md` is read after this change
- **THEN** the backgrounds batch, the weather batch, the tools batch and the creature batches each list the rule they must add to these items

### Requirement: Tool, material and wearable items as data
The tools, materials and wearables `docs/ITEMS.md` lists SHALL each be one item file in the items folder that passes the content check, with the uses, durability, capabilities and effects the doc gives. The conch horn is one more tool (`docs/ITEMS.md` Tools 18 to 19, Counts 116 to 117). Items already shipped, and items `docs/CONTENT_MANIFEST.md` gives to another batch, are not duplicated. No script changes to add them.

#### Scenario: The batch loads and validates
- **GIVEN** the project with this batch's item files
- **WHEN** the content check runs
- **THEN** every tool, material and wearable of the batch and the conch horn are listed by the content catalog, and the check reports no problem for any of them

#### Scenario: Nothing doubled, nothing taken from batch 11
- **GIVEN** the knife, lighter, mirror, binoculars, driftwood, dry grass, inner tube, plastic jug, rope, tarp, nails and red-band hat already shipped
- **WHEN** the items folder is listed
- **THEN** each of them is still one file, and this batch adds no surfboard, board sail, drum, propeller, fuel jug, sugar or bicycle tube, which the balsero gear batch builds

#### Scenario: Durability as the doc gives it
- **WHEN** the batch's tools are read
- **THEN** the machete has 60 uses, the broken bottle 5, the spear 30, the fishing line 25, the net 15, the snare 10, the pliers 50 and the shovel-oar 30. The lure, compass, charts, flint and steel, the horn and every wearable have no use counter and never wear out

### Requirement: Gear descriptions in Cuban speech
Every item of the batch SHALL have a Spanish name and a Spanish description, with English beside both. Spanish descriptions use spoken Cuban contractions (pa', na', to', 'tá) where the speech allows, never textbook "para" or "nada"; where swimming is meant they write "nadar", never the homograph. English keeps the key slang untranslated.

#### Scenario: Names and descriptions in both languages
- **WHEN** any item of the batch is loaded
- **THEN** its Spanish and English names and descriptions are not empty, and its Spanish description differs from its English one

#### Scenario: Spoken contractions
- **WHEN** the Spanish descriptions of the batch are read
- **THEN** none contains the word "para" or "nada", and each contains a spoken contraction or a Cuban word from the project's list

### Requirement: Gear the game cannot run yet is data, not code
Worn slots, passive modifiers, weapon damage and hit effects, fishing catches, trap catches and weather that knocks an item off SHALL be written as item data in the fields the data model has, with no script added. Until a later change reads a field, it changes nothing in play, for 1 player or for several. `TASKS.md` lists each such change.

#### Scenario: The yarey hat as data
- **WHEN** the straw hat item is loaded
- **THEN** it is a head wearable that lowers heat gain to 70% and is knocked off by a squall, and the red-band hat still differs from it by never being knocked off

#### Scenario: Fins carry their cost
- **WHEN** the fins item is loaded
- **THEN** it is a foot wearable that raises swim speed by 30% in the water and lowers walk speed by 30% on land

#### Scenario: The runtime follow-ups are logged
- **WHEN** `TASKS.md` is read after this change
- **THEN** it lists the code changes that will read the batch's data: equipment and modifiers, player weapons, fishing and traps, navigation tools at sea, and the horn's noise

### Requirement: Gear references only content that exists
The batch's items SHALL refer only to content that is shipped. A rule that needs content not yet built is left out and logged in `TASKS.md` under the batch that builds that content: hutía in the snare, the creatures that react to sandals, the spear or shiny items, the rock and stick some recipes need, and background starting kits.

#### Scenario: No dangling reference
- **WHEN** the content check runs over the batch
- **THEN** no item of the batch names a missing item, creature, weather or background, and the snare and the net catch only the land crab

#### Scenario: The follow-ups are logged
- **WHEN** `TASKS.md` is read after this change
- **THEN** the creature batches, the recipes batch and the backgrounds batch each list the rule or item they must add for this batch's gear
