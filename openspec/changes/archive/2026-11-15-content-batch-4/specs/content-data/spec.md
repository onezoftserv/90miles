## ADDED Requirements

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
