## MODIFIED Requirements

### Requirement: Noise and smell
Creatures SHALL subscribe to a world event bus that the island's session owns on the host: `noise(pos, radius)` and `blood(pos)` events drive investigation, and lighting a fire raises `smoke(pos)`, the bus also listing every lit fire. A noise's radius is in tiles, times the noise multiplier of the place it is made (a cave doubles it). Only the host raises and hears events; one offline player is the host. Patrols subscribe to `smoke` and `noise`.

#### Scenario: Blood draws investigation
- GIVEN a creature subscribed to the world event bus
- WHEN a `blood(pos)` event fires
- THEN the creature investigates `pos`

#### Scenario: A data effect makes the noise
- **GIVEN** a solo player holding an item whose use carries a noise effect of radius 15 tiles
- **WHEN** they use it on open sand
- **THEN** the bus carries one `noise` event at the player's position with radius 15

#### Scenario: A cave doubles a noise
- **GIVEN** a place whose noise multiplier is 2
- **WHEN** a noise of radius 10 tiles is made inside it
- **THEN** the bus carries it with radius 20

#### Scenario: Lighting a fire raises smoke
- **GIVEN** a solo player building a fire
- **WHEN** the fire is lit
- **THEN** the bus carries one `smoke` event at the fire and lists the fire among the lit fires until it goes out

#### Scenario: A client raises nothing
- **GIVEN** a host and a client
- **WHEN** the client's player uses an item with a noise effect
- **THEN** the noise is raised once, on the host, at the client's player's position, and the client's own bus carries nothing
