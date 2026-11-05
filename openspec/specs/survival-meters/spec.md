# survival-meters

## Purpose
The six meters that drive the survival loop: thirst, hunger, heat, energy, morale, health.

## Requirements

### Requirement: Meter component
Each player SHALL have a `SurvivalMeters` node holding six floats (0–100) with the drain and restore rules in `docs/GAME_DESIGN.md` §4. Values are host-authoritative and synced.

#### Scenario: Client shows host values
- GIVEN a client's player whose thirst is 40 on the host
- WHEN the client draws its meters
- THEN it shows thirst 40, the host's value

### Requirement: Thirst
Thirst SHALL drain 1/min at rest, ×2 in direct sun, ×3 while swimming, ×0.5 at night. At 0, health drains 2/s. Coconut +15, rain cup +25, still cup +40, well cup +30. Seawater +10 then −30 over 120 s.

#### Scenario: Seawater
- GIVEN thirst 20
- WHEN the player drinks seawater
- THEN thirst reads 30 immediately and 0 after 120 s with no other input

### Requirement: Hunger
Hunger SHALL drain 0.5/min, ×2 while crafting or swimming. At 0, the energy cap is 50. Foods restore per `docs/GAME_DESIGN.md`. Raw crab and raw fish have a 30% poison chance (−20 health over 30 s) unless the eater is a Pescador.

#### Scenario: Pescador eats raw fish
- GIVEN a Pescador
- WHEN they eat raw fish
- THEN there is no poison chance

### Requirement: Heat
Heat SHALL rise 2/min in direct sun between in-game 10:00 and 16:00, fall 4/min in shade or water, and reset at night. At 100, sunstroke: screen blur and speed −40% until heat < 60.

#### Scenario: Sunstroke lingers
- GIVEN a player whose heat reached 100
- WHEN they move into shade and heat falls to 70
- THEN the screen blur and −40% speed still apply, and both end once heat drops below 60

### Requirement: Energy
Energy SHALL drain per activity (swim 3/s, build 1/s, run 0.5/s) and restore +50 per sleep (a full night in shelter) and +10 per meal. At 0, the player can only crawl.

#### Scenario: Running out of energy
- GIVEN a player on land with energy 5
- WHEN they run for 10 s
- THEN energy is 0 and they can only crawl

### Requirement: Morale
Morale SHALL drain −30 on an ally's death, −10 per squall, −5/min alone at night, and restore +2/min with a teammate within 5 tiles, +5 per fire lit, +15 per song (Músico), +10 per found text read. At < 20, hallucinations: the game spawns fake island silhouettes and fake voice lines (never fake resources).

#### Scenario: Ally dies
- GIVEN a player with morale 45
- WHEN an ally dies
- THEN morale is 15 and hallucinations start: fake island silhouettes and fake voice lines, never fake resources

### Requirement: Health and downed state
Health SHALL drop from attacks, thirst, heat and poison. At 0 the player is downed for 90 s: immobile, draggable. Giving water (any cup) revives at 30 health. If the timer ends, the player dies (permadeath for the run). Solo players die immediately at 0.

#### Scenario: Revive
- GIVEN a downed player with 40 s left
- WHEN a teammate uses a rain cup on them
- THEN the player stands with health 30 and thirst +25
