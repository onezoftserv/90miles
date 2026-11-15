# Spec Delta

## MODIFIED Requirements

### Requirement: Title screen
The title screen SHALL show the logo over an animated sea, the buttons "Jugar solo", "Hospedar partida", "Unirse", "Ajustes", "Créditos" and "Salir", a panel describing the focused button, and the game version. The first button has focus on arrival.

#### Scenario: Focus describes the option
- **GIVEN** the title screen
- **WHEN** the focus moves to "Hospedar partida"
- **THEN** the description panel explains hosting and that others join by IP on UDP port 7777

#### Scenario: Credits offered offline
- **GIVEN** a solo player on the title screen, offline, with no session
- **WHEN** the focus moves to "Créditos"
- **THEN** it sits between "Ajustes" and "Salir", the description panel says it lists who made the game's art and fonts and under which licences, and no network port is opened
