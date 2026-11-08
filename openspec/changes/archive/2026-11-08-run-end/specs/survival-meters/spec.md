## ADDED Requirements

### Requirement: Cause of death
When a player dies the host SHALL record one cause id for the death: the cause of the health loss that took health to 0. A downed player, or a player in a solo last stand, keeps the cause of the loss that put them down until they die; a revive forgets it, and a free revive records nothing. Clients show the host's cause and already have it when their copy of the player dies. The rule is the same for 1 player and in co-op.

#### Scenario: A solo player dies of thirst
- **GIVEN** a solo player on run 1 with thirst 0 and health 2
- **WHEN** 1 s passes
- **THEN** the player is dead and the cause is `thirst`

#### Scenario: Downed by a shark, dry while down
- **GIVEN** a co-op player struck to 0 health by a reef shark
- **WHEN** their thirst empties while they are downed and the 90 s run out
- **THEN** the player is dead and the cause is `reef_shark`

#### Scenario: Revived, then dry
- **GIVEN** a co-op player downed by a reef shark and revived at 30 health with thirst 0, who is now the last one alive
- **WHEN** 15 s pass
- **THEN** the player is dead and the cause is `thirst`

#### Scenario: A solo last stand keeps its cause
- **GIVEN** a solo player with 15 s of downed-timer bonus pinched to 0 health by a land crab
- **WHEN** the 15 s run out
- **THEN** the player is dead and the cause is `land_crab`

#### Scenario: The Medalla records nothing
- **GIVEN** a solo player holding an unused free revive
- **WHEN** a reef shark strikes them to 0 health
- **THEN** they stand at 30 health and no cause is recorded

#### Scenario: A client has the cause with the death
- **GIVEN** a host and a client in a run
- **WHEN** the host's copy of the client's player dies of a reef shark strike
- **THEN** on the client, the cause reads `reef_shark` at the moment its copy of that player dies

### Requirement: Cause ids
Every loss of health SHALL name one cause id: `thirst` (health lost while thirst is empty), `drowning` (a swimmer with no energy left in a crossing), the attacking creature's id (`reef_shark` for a strike or a crossing bite, `land_crab` for a pinch), or `other` (poison, item effects, and a death with no recorded cause). Hunger, heat, energy and morale never take health, so none of them is a cause. A creature added as data names its own cause with its id, with no script change.

#### Scenario: Drowning in a crossing
- **GIVEN** a 1-player crossing with the rider in the water at 0 energy and 100 health
- **WHEN** 10 s pass
- **THEN** the rider is dead and the cause is `drowning`, and after 9.9 s they were still alive

#### Scenario: A shark bite in a crossing
- **GIVEN** a 1-player crossing with the rider in the water at 25 health
- **WHEN** the shark pass bites them
- **THEN** the rider is dead and the cause is `reef_shark`

#### Scenario: Poison
- **GIVEN** a solo player with health 10
- **WHEN** they are poisoned (20 health over 30 s) and 15 s pass
- **THEN** the player is dead and the cause is `other`

#### Scenario: Empty meters that do not kill
- **GIVEN** a solo player with hunger, energy and morale at 0, heat 100 and thirst full
- **WHEN** 5 minutes pass
- **THEN** the player is alive with full health and no cause
