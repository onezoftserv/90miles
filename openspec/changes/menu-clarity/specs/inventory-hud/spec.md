## ADDED Requirements

### Requirement: Vessel words in crossing prompts
A crossing prompt that names the vessel (tie down, untie, climb aboard) SHALL name the route's own vessel with its article, from the HUD text: "Amarrarse al almendrón" on the car, "Amarrarse a la balsa" on the raft, "Subir a tu tabla" on a board. A vessel with no words of its own uses the raft's. Adding a vessel's words is a HUD text edit, with no script change. Solo and co-op read the same words.

#### Scenario: The car
- **GIVEN** a solo player, offline, aboard the car on a crossing, untied
- **WHEN** the HUD draws the lashing's prompt
- **THEN** it reads "[E] Amarrarse al almendrón", and once tied "[E] Soltarse del almendrón"

#### Scenario: The raft is unchanged
- **GIVEN** a solo player aboard the raft on a crossing, untied
- **WHEN** the HUD draws the lashing's prompt
- **THEN** it reads "[E] Amarrarse a la balsa"

#### Scenario: A board
- **GIVEN** a solo player in the water beside their own board on a board crossing
- **WHEN** the HUD draws the climb point's prompt
- **THEN** it reads "[E] Subir a tu tabla"
