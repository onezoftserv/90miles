## MODIFIED Requirements

### Requirement: Thirst
Thirst SHALL drain 0.1/s (6/min) at rest, ×2 in direct sun (day phase, on land, not in shade), ×3 while swimming instead of the sun factor, ×0.5 at night. Work on a build that names a thirst cost adds that cost on top (a raft stage: +0.25/s, crafting-inventory "Work costs"). At 0, health drains 2/s. Coconut +15, rain cup +25, still cup +40, well cup +30. Seawater +10 then −30 over 120 s. (Base rate changed from 1/min in `docs/GAME_DESIGN.md` §4; the work cost adds to §4.)

#### Scenario: Seawater
- GIVEN a player resting in shade at night with thirst 50
- WHEN the player drinks seawater
- THEN thirst reads 60 immediately and 24 after 120 s with no other input

#### Scenario: Working in the sun
- **GIVEN** a player on land in direct sun with thirst 80
- **WHEN** 60 s pass
- **THEN** thirst is 68

#### Scenario: Swimming does not add the sun
- **GIVEN** a player swimming in the midday sun with thirst 80
- **WHEN** 60 s pass
- **THEN** thirst is 62

#### Scenario: A day in the shade
- **GIVEN** a player with full thirst resting in shade at dawn
- **WHEN** one full day passes (12 real minutes)
- **THEN** thirst is 43

#### Scenario: Dry
- **GIVEN** a player with thirst 0 and health 100
- **WHEN** 10 s pass
- **THEN** health is 80

#### Scenario: Building the raft in the sun
- **GIVEN** a solo player in direct sun with thirst 80 holding interact on a raft site whose stage inputs are in
- **WHEN** 20 s pass
- **THEN** thirst is 71

### Requirement: Heat
Heat SHALL rise 0.75/s (45/min) in direct sun between in-game 10:00 and 16:00, ×2 in scorching calm; fall 0.75/s in shade, in water or outside that window; and reset to 0 at night. At 100, sunstroke: screen blur and speed −40% until heat < 60. A rider aboard a vessel in a crossing never gains heat past the sea cap, 59: above it their heat falls at the shade rate down to it, so nobody is sunstruck at sea; the island-stop toldo replaces this cap. (Rates changed from +2/min and −4/min in `docs/GAME_DESIGN.md` §4; at 30 s per in-game hour the window is 3 real minutes; the sea cap adds to §4.)

#### Scenario: Sunstroke lingers
- GIVEN a player whose heat reached 100
- WHEN they move into shade and heat falls to 70
- THEN the screen blur and −40% speed still apply, and both end once heat drops below 60

#### Scenario: Midday sun
- **GIVEN** a player with heat 0 in direct sun at 10:00
- **WHEN** 120 s pass
- **THEN** heat is 90 and there is no sunstroke

#### Scenario: Scorching calm
- **GIVEN** a player with heat 0 in direct sun at 10:00 in scorching calm
- **WHEN** 70 s pass
- **THEN** heat is 100 and sunstroke has started

#### Scenario: Night resets heat
- **GIVEN** a player with heat 50
- **WHEN** night falls
- **THEN** heat is 0

#### Scenario: Solo midday at sea
- **GIVEN** a 1-player crossing launched at 11:00 in calm weather, the rider aboard the raft with heat 40
- **WHEN** 60 s pass aboard
- **THEN** their heat is 59 and they have no sunstroke

#### Scenario: Boarding sunstruck
- **GIVEN** a 1-player run whose player has heat 100 and sunstroke when their raft crossing starts at 12:00
- **WHEN** 55 s pass aboard
- **THEN** their heat is 59 and the sunstroke is over

#### Scenario: Back on land
- **GIVEN** a solo rider who arrived on the coast cay at 12:00 with heat 59
- **WHEN** they stand 60 s in direct sun on the beach
- **THEN** their heat is 100 and sunstroke has started

### Requirement: Energy
Energy SHALL drain per activity (swim 3/s, run 0.5/s, and work on a build at its work cost: 1/s on a raft stage, crafting-inventory "Work costs") and restore +50 per sleep (a full night in shelter) and +10 per meal, where a meal is anything that restores hunger. It does not regenerate otherwise. At 0, the player can only crawl and cannot work a build that costs energy. (`docs/GAME_DESIGN.md` §4 "building 1/s" is the raft's work cost.)

#### Scenario: Running out of energy
- GIVEN a player on land with energy 5
- WHEN they run for 10 s
- THEN energy is 0 and they can only crawl

#### Scenario: A meal
- **GIVEN** a player with energy 40 and hunger 50
- **WHEN** they eat food that restores 20 hunger
- **THEN** hunger is 70 and energy is 50

#### Scenario: A night's sleep
- **GIVEN** a player with energy 20
- **WHEN** they sleep a full night in shelter
- **THEN** energy is 70

#### Scenario: A raft stage
- **GIVEN** a solo player with energy 100 at a raft site whose first stage's inputs are in
- **WHEN** they hold interact on it for its 30 s
- **THEN** energy is 70

### Requirement: Health and downed state
Health SHALL drop from attacks, thirst and poison. At 0 a player with another living player in the run is downed for 90 s plus their downed-timer bonuses: immobile, draggable, and still losing thirst and hunger. Giving water (a cup whose item revives) brings them up at 30 health. If the timer ends, the player dies (permadeath for the run). A player with no other living player (a one-player run, or the last one alive) is not downed: they get a last stand instead.

#### Scenario: Revive
- GIVEN a downed player with 40 s left
- WHEN a teammate uses a rain cup on them
- THEN the player stands with health 30 and thirst +25

#### Scenario: Nobody comes
- **GIVEN** a co-op player whose health just reached 0
- **WHEN** 90 s pass without a revive
- **THEN** the player is dead

#### Scenario: Solo
- **GIVEN** a solo player on run 1 with no downed-timer bonus, on land
- **WHEN** their health reaches 0
- **THEN** they are not downed but in a last stand, alive after 11.9 s and dead after 12 s

#### Scenario: Last one alive
- **GIVEN** a co-op player with no downed-timer bonus whose only teammate has died, on land
- **WHEN** their health reaches 0
- **THEN** they are in a 12 s last stand, without a 90 s downed timer

#### Scenario: Experiencia lengthens the downed timer
- **GIVEN** a co-op player with 10 s of downed-timer bonus
- **WHEN** their health reaches 0
- **THEN** they are downed for 100 s

#### Scenario: Poison
- **GIVEN** a player with health 100
- **WHEN** they are poisoned
- **THEN** health is 90 after 15 s and 80 after 30 s

### Requirement: Solo last stand
At 0 health a player with no other living player SHALL get a last stand lasting 12 s on land plus their downed-timer bonuses (Experiencia levels and the point boost; endings-progression owns those numbers). A rider of a crossing gets the bonuses alone, since nothing can be used at sea. They lie where they fell, still losing thirst and hunger, and can use a cup whose item revives on themselves to stand at 30 health. When the last stand ends they die; at sea with no bonus (run 1) they die at once. (Changes the 0 s base of `docs/GAME_DESIGN.md` §4 "Last stand" and §14.)

#### Scenario: Last stand with Experiencia
- **GIVEN** a solo player on land with 15 s of downed-timer bonus (3 Experiencia levels)
- **WHEN** their health reaches 0
- **THEN** they are in a last stand, alive after 26 s and dead after 27 s

#### Scenario: Saving yourself
- **GIVEN** a solo player in a last stand with 5 s left and a rain cup
- **WHEN** they use the rain cup on themselves
- **THEN** they stand with health 30 and thirst +25

#### Scenario: Run 1 alone and dry
- **GIVEN** a 1-player run, offline, on run 1, a player on the sandbar with thirst 0, health 2, a coconut and a knife
- **WHEN** 1 s passes and then they drink the coconut
- **THEN** they were in a last stand and stand again at 30 health with thirst 15

#### Scenario: Run 1 at sea
- **GIVEN** a 1-player crossing on run 1 whose rider swims at 0 energy and 10 health
- **WHEN** 1 s passes
- **THEN** the rider is dead, with no last stand

### Requirement: Free revive
A player holding an unused free revive (the Medalla de la Caridad keepsake: one per run) SHALL, when their health reaches 0, stand at 30 health instead of going down, starting a last stand or dying, and the free revive is used up. It needs no reviver, so it works solo.

#### Scenario: The Medalla saves a solo player once
- **GIVEN** a solo player on run 1 on land holding the Medalla with its revive unused
- **WHEN** their health reaches 0, and later reaches 0 again
- **THEN** the first time they stand at 30 health and the revive is used up; the second time they are in a 12 s last stand

#### Scenario: The Medalla in co-op
- **GIVEN** a co-op player holding the Medalla with its revive unused
- **WHEN** their health reaches 0
- **THEN** they stand at 30 health instead of going down

### Requirement: Cause of death
When a player dies the host SHALL record one cause id for the death: the cause of the health loss that took health to 0. A downed player, or a player in a solo last stand, keeps the cause of the loss that put them down until they die; a revive forgets it, and a free revive records nothing. Clients show the host's cause and already have it when their copy of the player dies. The rule is the same for 1 player and in co-op.

#### Scenario: A solo player dies of thirst
- **GIVEN** a solo player on run 1 on land with thirst 0 and health 2
- **WHEN** 13 s pass
- **THEN** the player is dead and the cause is `thirst`

#### Scenario: Downed by a shark, dry while down
- **GIVEN** a co-op player struck to 0 health by a reef shark
- **WHEN** their thirst empties while they are downed and the 90 s run out
- **THEN** the player is dead and the cause is `reef_shark`

#### Scenario: Revived, then dry
- **GIVEN** a co-op player on land downed by a reef shark and revived at 30 health with thirst 0, who is now the last one alive
- **WHEN** 27 s pass
- **THEN** the player is dead and the cause is `thirst`

#### Scenario: A solo last stand keeps its cause
- **GIVEN** a solo player on land with 15 s of downed-timer bonus pinched to 0 health by a land crab
- **WHEN** the 27 s run out
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
- **GIVEN** a solo player on land with health 10
- **WHEN** they are poisoned (20 health over 30 s) and 27 s pass
- **THEN** the player is dead and the cause is `other`, and after 16 s they were in a last stand

#### Scenario: Empty meters that do not kill
- **GIVEN** a solo player with hunger, energy and morale at 0, heat 100 and thirst full
- **WHEN** 5 minutes pass
- **THEN** the player is alive with full health and no cause
