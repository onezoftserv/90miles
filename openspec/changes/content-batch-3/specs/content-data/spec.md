## ADDED Requirements

### Requirement: Water, food and plant items as data
The water, food and unknown-plant items `docs/ITEMS.md` lists SHALL each be one item file in the items folder that passes the content check, with the effect numbers the doc gives. Items that `docs/CONTENT_MANIFEST.md` gives to another batch, and items already shipped, are not duplicated. No script changes to add them.

#### Scenario: The batch loads and validates
- **GIVEN** the project with this batch's item files
- **WHEN** the content check runs
- **THEN** every water, food and plant item of the batch is listed by the content catalog, and the check reports no problem for any of them

#### Scenario: One file per item
- **GIVEN** the aloe already shipped as `aloe` and the grapefruit, its steak and milordo assigned to the balsero gear batch
- **WHEN** the items folder is listed
- **THEN** no second sábila, toronja, bistec de toronja or milordo file exists

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
