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
