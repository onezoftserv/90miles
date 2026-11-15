## MODIFIED Requirements

### Requirement: HUD layout
During a run the HUD SHALL keep to a 640×360 budget. The six meters sit top-left, each label inside its bar, a bar pulsing when critical (thirst, hunger, energy, morale or health at 25 or less, heat at 75 or more). The day phase sits top-centre. In co-op, teammates are listed top-right with name, health and a state word, and a teammate's name and health strip show over their head while health is not full. The bottom band is the inventory's and the centre holds no panel. An open sign note sits top-centre under the day phase, clear of the meters, the teammate list and the centre.

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

#### Scenario: The sign note keeps clear
- **GIVEN** a co-op run with three teammates listed and a sign note open showing the longest coast cay line
- **WHEN** the HUD is drawn
- **THEN** the note's rectangle overlaps none of the meters, the day phase, the teammate list, the inventory band or the centre
