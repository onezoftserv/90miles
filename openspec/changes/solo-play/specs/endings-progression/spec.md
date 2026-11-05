# Spec Delta

## MODIFIED Requirements

### Requirement: Ending selection
When a run ends on land or by `devuelto`, the game SHALL select an ending from flags in priority order: `devuelto` (whole party captured on the final crossing) → `el_nino` (Yunior alive) → `solo` (exactly one survivor, any party size) → `todos` (at least one companion met; all met companions and NPC allies alive) → `los_que_llegamos` (any other outcome). Survivors are the players and companions who reach land. Each ending has a handwritten scene with slots filled by who is present.

#### Scenario: Todos
- GIVEN Ramón came along, Caridad's lamp was lit, Dayana and Papo are alive, Yunior was never met
- WHEN the party reaches land
- THEN the `todos` ending plays with Ramón, Dayana and Papo on the beach and Caridad in the credits

#### Scenario: Lone balsero
- GIVEN a 1-player run in which no companion was met
- WHEN the player reaches land
- THEN there is 1 survivor and the `solo` ending plays

#### Scenario: Solo player brings a companion
- GIVEN a 1-player run in which Dayana was met and is alive
- WHEN the player and Dayana reach land
- THEN there are 2 survivors and the `todos` ending plays with Dayana on the beach

#### Scenario: Solo player loses a companion
- GIVEN a 1-player run in which Dayana and Papo were met and Papo died
- WHEN the player and Dayana reach land
- THEN there are 2 survivors and the `los_que_llegamos` ending plays

#### Scenario: Last survivor of a party
- GIVEN a 4-player run in which 3 players died and no companion is with the last player
- WHEN that player reaches land
- THEN there is 1 survivor and the `solo` ending plays

## ADDED Requirements

### Requirement: Devuelto
A `devuelto` ending (every living player captured on the final crossing) SHALL end the run as a loss: it counts as a death, so it adds one Experiencia level and persists the death carry-over (50%), and it is not a win, so no levels are removed. It SHALL unlock the Devuelto keepsake (docs/GAME_DESIGN.md §13; its name and effect are still open), except in a seeded run.

#### Scenario: Solo player returned
- GIVEN a 1-player run at Experiencia level 2 that earned 40 fishing XP, on an unseeded run
- WHEN the final patrol captures the player and `devuelto` plays
- THEN the profile is at level 3, carries 20 fishing XP, and has the Devuelto keepsake unlocked

### Requirement: Solo last stand from Experiencia
For a player with no other living player (a 1-player run, or the last one alive), the downed-timer rewards SHALL lengthen the solo last-stand window that survival-meters defines: 0 s base, +5 s per Experiencia level and +10 s with the downed-timer boost. The same window carries the Medalla de la Caridad revive. (Changes docs/GAME_DESIGN.md §14.)

#### Scenario: Run 1 solo
- GIVEN a new profile with Experiencia level 0 and no boosts
- WHEN a 1-player run starts
- THEN the player's last-stand window is 0 s

#### Scenario: Eased solo
- GIVEN a profile at Experiencia level 4 that bought the +10 s downed-timer boost
- WHEN a 1-player run starts
- THEN the player's last-stand window is 30 s
