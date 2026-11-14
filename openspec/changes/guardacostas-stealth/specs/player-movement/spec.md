## MODIFIED Requirements

### Requirement: Walk, run, crouch
The player SHALL move on land with WASD/left stick at 4 tiles/s walking, 6 running, 2 crouching. Running drains 0.5 energy/s. Crouching sets the player's stealth state to hidden while on brush tiles; on mangrove tiles and on roofed cells (a hut or post the island marks) the stealth state is hidden in any posture (guardacostas-stealth "Hidden states"). At energy 0 on land the player can only crawl, at 1 tile/s, and cannot run.

#### Scenario: Running on sand
- GIVEN a player with energy 50 on a beach tile
- WHEN the player holds run for 10 s
- THEN energy is 45 and the player moved 60 tiles

#### Scenario: Crouching in brush
- **GIVEN** a player standing on a brush tile
- **WHEN** the player holds crouch
- **THEN** the player moves at 2 tiles/s and their stealth state is hidden

#### Scenario: Crawling at zero energy
- **GIVEN** a player on land with energy 0
- **WHEN** the player holds run and moves for 4 s
- **THEN** the player moved 4 tiles and energy is still 0

#### Scenario: Standing under a roof
- **GIVEN** a solo player walking into the sandbar's hut
- **WHEN** they stand upright on a roofed cell
- **THEN** their stealth state is hidden, and visible again once they step out onto sand

#### Scenario: Walking through mangrove
- **GIVEN** a player walking upright on a mangrove tile
- **WHEN** they keep walking
- **THEN** their stealth state is hidden

#### Scenario: Standing on brush
- **GIVEN** a player standing upright on a brush tile
- **WHEN** they do not crouch
- **THEN** their stealth state is visible
