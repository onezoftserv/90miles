## MODIFIED Requirements

### Requirement: HUD bars
The local player's screen SHALL show six labelled bars in Spanish, Salud first, then Sed, Hambre, Calor, Energía and Ánimo, each label left of its bar and the value right of it, each bar filled to its meter's value out of 100 and updated when the value changes, readable at 640×360 in the committed pixel font. Heat fills as it rises. While the local player has sunstroke, their screen is blurred.

#### Scenario: Bars follow the meters
- **GIVEN** the HUD of a player with thirst 100
- **WHEN** thirst drops to 40
- **THEN** the Sed bar shows 40 of 100

#### Scenario: Heat fills up
- **GIVEN** the HUD of a player with heat 0
- **WHEN** heat rises to 75
- **THEN** the Calor bar is three quarters full

#### Scenario: Only the sunstruck player's screen blurs
- **GIVEN** the HUD of player A and a teammate B
- **WHEN** B gets sunstroke and A does not
- **THEN** A's screen is not blurred, and it blurs once A gets sunstroke

#### Scenario: Salud comes first
- **GIVEN** the HUD of a solo player, offline, with exactly 1 player
- **WHEN** the meters are drawn
- **THEN** the rows read Salud, Sed, Hambre, Calor, Energía and Ánimo from the top, each label left of its bar with the value right of it
