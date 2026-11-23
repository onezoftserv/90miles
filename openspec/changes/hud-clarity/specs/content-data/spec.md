## ADDED Requirements

### Requirement: Short names for counts
An item MAY have a Spanish and an English short name, and the HUD SHALL count the item with it ("0/6 madera"). A short name is lower case and at most 10 characters. An empty short name falls back to the item's name, and an empty English short name to the Spanish one. Driftwood's short names are "madera" and "wood", the inner tube's "cámaras" and "tubes", and rope's "sogas" and "ropes". Adding or changing one needs no code change.

#### Scenario: A count uses the short name
- **GIVEN** driftwood with the name "Madera de la costa" and the short name "madera"
- **WHEN** the HUD asks for its count noun in Spanish
- **THEN** "madera" is returned

#### Scenario: No short name
- **GIVEN** an item with the name "Coco" and no short names
- **WHEN** the HUD asks for its count noun in English
- **THEN** "Coco" is returned

#### Scenario: A short name too long
- **GIVEN** an item file whose Spanish short name has 11 characters
- **WHEN** the content check runs
- **THEN** it fails and names the file

### Requirement: Launch lines
An island layout MAY have a Spanish and an English launch line, and the objective row SHALL show it while the island's raft is built (ui-shell "Objective at launch and at sea"). A launch line has at most 27 characters and never names a secret island. An empty one uses the HUD's default line ("Zarpa pa'l norte"), and an empty English one the Spanish one. The sandbar's is "Zarpa pa'l cayo" ("Set off for the cay"). Adding or changing one needs no code change.

#### Scenario: The sandbar's launch line
- **GIVEN** the sandbar layout file
- **WHEN** its launch line is read in Spanish and in English
- **THEN** it is "Zarpa pa'l cayo" and "Set off for the cay"

#### Scenario: A launch line too long
- **GIVEN** an island layout file whose Spanish launch line has 28 characters
- **WHEN** the content check runs
- **THEN** it fails and names the file
