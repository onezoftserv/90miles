# Spec Delta

## MODIFIED Requirements

### Requirement: Devuelto
A `devuelto` ending (every living player captured on the final crossing) SHALL end the run as a loss: it counts as a death, so it adds one Experiencia level and persists the death carry-over (50%), and it is not a win, so no levels are removed. It SHALL unlock the *Pluma de galleguito* keepsake (docs/GAME_DESIGN.md §13, §14), except in a seeded run.

#### Scenario: Solo player returned
- GIVEN a 1-player run at Experiencia level 2 that earned 40 fishing XP, on an unseeded run
- WHEN the final patrol captures the player and `devuelto` plays
- THEN the profile is at level 3, carries 20 fishing XP, and has the Pluma de galleguito keepsake unlocked

## ADDED Requirements

### Requirement: Epilogue lines
Each ending card SHALL carry flag-gated one-liners as data without changing Ending selection: the galleguito line (`galleguito_a_bordo`, all five endings, the *Devuelto* variant for a returned party), the piling line (every landing ending, no condition), the almendrón line (`almendron_a_bordo`) and, in *Devuelto* only, the sunk-car line (`almendron_hundido`).

#### Scenario: Solo landing with the gull
- GIVEN a 1-player run that lands with `galleguito_a_bordo` set and no almendrón flag
- WHEN `solo` plays
- THEN its card shows the galleguito line and the piling line, and no almendrón line

#### Scenario: Solo returned after sinking the car
- GIVEN a 1-player run whose earlier capture sank the car (`almendron_a_bordo` and `almendron_hundido` set) and that ends in `devuelto`
- WHEN the card shows
- THEN it shows the galleguito Devuelto line (if `galleguito_a_bordo` is set) and the sunk-car line, and no piling line
