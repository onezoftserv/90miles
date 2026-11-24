## MODIFIED Requirements

### Requirement: Build site prompt
A build site's prompt SHALL add lines from the site's state as this peer has it: while inputs are missing, one line per missing input or tag as "<Spanish name> x<count>", the first headed "Falta:"; once every input is in, the shared build progress as a bar with a percentage. A staged build first adds the stage line, "Etapa 2/4: Armar el piso"; its "Falta:" lines name what that stage still needs and its bar shows that stage's own progress. While the local player has no energy for a build that costs energy, a line reads "Sin fuerzas: come algo." Deposited items, deposited tags and progress reach every peer, later joiners included, so every peer reads the same state. Solo the same.

#### Scenario: The raft site
- **GIVEN** a solo player next to the raft site holding 2 driftwood, with nothing deposited
- **WHEN** they press E
- **THEN** the lines under the prompt read "Etapa 1/4: Amarrar las cámaras", "Falta: Cámara x2" and "Soga x1"

#### Scenario: A fire site on a client
- **GIVEN** a host and a client next to a fire site placed at the bench, with nothing deposited
- **WHEN** the host's player deposits 3 driftwood, then 1 dry grass, then works the site
- **THEN** the client's prompt reads "Falta: Madera de la costa x3" and "Yesca x1", then "Falta: Yesca x1" alone, then shows the bar rising

#### Scenario: Progress seen by a client
- **GIVEN** a host holding interact on a raft site with every input in and 45 of its 120 s of work done, and a client next to it
- **WHEN** the client draws the prompt
- **THEN** its lines read "Etapa 2/4: Armar el piso" and the bar at 50 %

#### Scenario: A joiner mid-build
- **GIVEN** a host who deposited everything into a fire site and worked it to 50 %
- **WHEN** a client joins and stands next to it
- **THEN** the client's prompt shows the bar at 50 % and no "Falta:" line

#### Scenario: Solo out of strength
- **GIVEN** a solo player at energy 0 next to a raft site with every input in
- **WHEN** the HUD is drawn
- **THEN** the lines under the prompt include "Sin fuerzas: come algo."

## ADDED Requirements

### Requirement: Launch warning
While a launch from a built vessel would be seen by a patrol (guardacostas-stealth "Launch in view"), its launch prompt SHALL add warning lines from the HUD text file, each within the prompt's 30-glyph line: by day "De día te ve la lancha." and "Sal de noche o con turbonada.", at night "La luz te 'tá alumbrando." Each peer works it out from the phase, the weather and the boats' synced state. The warning never refuses: holding still asks the host, which decides. Solo the same.

#### Scenario: Solo by day
- **GIVEN** a solo player beside a built raft on the sandbar at 14:00 in calm weather
- **WHEN** the HUD is drawn
- **THEN** the prompt reads "[E] Zarpar en la balsa" and its lines include "De día te ve la lancha." and "Sal de noche o con turbonada."

#### Scenario: Solo at night, out of the light
- **GIVEN** a solo player beside a built raft on the sandbar at 22:00, no searchlight on them
- **WHEN** the HUD is drawn
- **THEN** no warning line shows

#### Scenario: A client sees the warning
- **GIVEN** a host and a client beside a built raft on the sandbar at 14:00 in calm weather
- **WHEN** the client draws its HUD
- **THEN** its launch prompt shows the day warning, as the host's does
