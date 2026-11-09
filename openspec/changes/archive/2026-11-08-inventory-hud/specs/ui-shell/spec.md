# Spec Delta

## MODIFIED Requirements

### Requirement: HUD layout
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit top-left, each label inside its bar, a bar pulsing when critical (thirst, hunger, energy, morale or health at 25 or less, heat at 75 or more). The day phase sits top-centre. In co-op, teammates are listed top-right with name, health and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band is the inventory's and the centre holds no panel.

#### Scenario: Solo HUD
- **GIVEN** a solo run
- **WHEN** the HUD is shown
- **THEN** it shows the meters, the day phase and the inventory strip, and no teammate list or quick-chat wheel

#### Scenario: Critical thirst
- **GIVEN** a player whose thirst is 20
- **WHEN** the HUD draws the thirst bar
- **THEN** the bar pulses, and it stops pulsing once thirst is above 25

#### Scenario: Teammate down
- **GIVEN** a co-op run with Papo downed
- **WHEN** a teammate looks at the HUD
- **THEN** Papo's row reads "Caído" with his health, and his name and health strip show over his head

## ADDED Requirements

### Requirement: Inventory band and world marks
During a run the HUD's bottom band (y 306 to 360) SHALL hold the local player's inventory strip, its selected item's line and refusal line, and the crafting list opens above it at the left edge (4,162 to 244,302) while the player is at a workbench (inventory-hud). In the centre the HUD draws only marks anchored to something in the world: a teammate's name tag, the interact prompt and the hidden mark. Solo the same.

#### Scenario: Marks in the centre
- **GIVEN** a solo player standing within 1 tile of a coconut, crouched in brush
- **WHEN** the HUD is drawn
- **THEN** the interact prompt shows over the coconut and the hidden mark over the player, both anchored to their world positions, and no panel covers the centre

#### Scenario: The band in co-op
- **GIVEN** a host with one client
- **WHEN** each peer draws its HUD
- **THEN** the strip and its lines lie inside y 306 to 360 and overlap neither the meters, the day phase nor the teammate list
