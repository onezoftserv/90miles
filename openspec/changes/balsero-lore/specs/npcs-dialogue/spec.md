# Spec Delta

## MODIFIED Requirements

### Requirement: Ending flags
NPCs, companions, routes and creatures SHALL set flags consumed by `endings-progression` (`ramon_photo`, `caridad_lamp`, `yunior_alive`, `companion_<id>_alive`, `rodriguez_deal`, `others_helped|robbed`, `almendron_a_bordo`, `almendron_hundido`, `galleguito_a_bordo`).

#### Scenario: Caridad's lamp
- GIVEN Caridad's lamp was lit during the run
- WHEN `endings-progression` selects an ending
- THEN it reads the `caridad_lamp` flag as set

#### Scenario: Solo gull flag
- GIVEN a 1-player run on the final crossing
- WHEN the galleguito lands on the player
- THEN `galleguito_a_bordo` is set once and `endings-progression` can read it
