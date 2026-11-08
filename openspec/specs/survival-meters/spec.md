# survival-meters

## Purpose
The six meters that drive the survival loop: thirst, hunger, heat, energy, morale, health.

## Requirements

### Requirement: Meter component
Each player SHALL have a `SurvivalMeters` node holding six floats (0–100): thirst, hunger, energy, morale and health start full and drain; heat starts at 0 and rises toward sunstroke at 100. Values are host-authoritative and synced: only the host advances them and clients show what the host sent; offline solo play is its own host. Every rate and threshold lives in one tuning resource in real seconds; one in-game hour is 30 real seconds (`docs/GAME_DESIGN.md` §4, §5).

#### Scenario: Client shows host values
- GIVEN a client's player whose thirst is 40 on the host
- WHEN the client draws its meters
- THEN it shows thirst 40, the host's value

#### Scenario: Fresh player
- **WHEN** a player spawns
- **THEN** thirst, hunger, energy, morale and health are 100 and heat is 0

### Requirement: Thirst
Thirst SHALL drain 0.1/s (6/min) at rest, ×2 in direct sun (day phase, on land, not in shade), ×3 while swimming instead of the sun factor, ×0.5 at night. At 0, health drains 2/s. Coconut +15, rain cup +25, still cup +40, well cup +30. Seawater +10 then −30 over 120 s. (Base rate changed from 1/min in `docs/GAME_DESIGN.md` §4.)

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

### Requirement: Hunger
Hunger SHALL drain 0.05/s (3/min), ×2 while crafting or swimming. At 0, the energy cap is 50: energy above 50 drops to 50 and cannot rise past it until hunger is above 0. Foods restore per `docs/GAME_DESIGN.md`. Raw crab and raw fish have a 30% poison chance (−20 health over 30 s) unless the eater is a Pescador. (Rate changed from 0.5/min in `docs/GAME_DESIGN.md` §4.)

#### Scenario: Pescador eats raw fish
- GIVEN a Pescador
- WHEN they eat raw fish
- THEN there is no poison chance

#### Scenario: Crafting doubles hunger
- **GIVEN** a player with hunger 50
- **WHEN** they craft for 60 s
- **THEN** hunger is 44

#### Scenario: Starving caps energy
- **GIVEN** a player at rest with energy 80 and hunger 0.5
- **WHEN** 10 s pass and then they gain 20 energy
- **THEN** hunger is 0 and energy is 50

### Requirement: Heat
Heat SHALL rise 0.75/s (45/min) in direct sun between in-game 10:00 and 16:00, ×2 in scorching calm; fall 0.75/s in shade, in water or outside that window; and reset to 0 at night. At 100, sunstroke: screen blur and speed −40% until heat < 60. (Rates changed from +2/min and −4/min in `docs/GAME_DESIGN.md` §4; at 30 s per in-game hour the window is 3 real minutes.)

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

### Requirement: Energy
Energy SHALL drain per activity (swim 3/s, build 1/s, run 0.5/s) and restore +50 per sleep (a full night in shelter) and +10 per meal, where a meal is anything that restores hunger. It does not regenerate otherwise. At 0, the player can only crawl.

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

### Requirement: Morale
Morale SHALL drain −30 on an ally's death and −10 per squall (both hit every player), −5/min at night with no teammate and no lit fire within 5 tiles, and restore +2/min with a teammate within 5 tiles, +5 per fire lit, +15 per song (Músico), +10 per found text read. Below 20 the player is hallucinating: the systems that own islands and dialogue show fake islands and fake voices, never fake resources. (Threshold changed from 0 in `docs/GAME_DESIGN.md` §4.)

#### Scenario: Ally dies
- GIVEN a player with morale 45
- WHEN an ally dies
- THEN morale is 15 and the player is hallucinating

#### Scenario: Alone at night
- **GIVEN** a player with morale 50 and no teammate within 5 tiles at night
- **WHEN** 60 s pass
- **THEN** morale is 45

#### Scenario: Company
- **GIVEN** a player with morale 50 and a teammate 4 tiles away
- **WHEN** 60 s pass
- **THEN** morale is 52

#### Scenario: A fire ends the hallucinations
- **GIVEN** a hallucinating player with morale 15
- **WHEN** they light a fire
- **THEN** morale is 20 and they are no longer hallucinating

#### Scenario: A fire keeps a lone player company
- **GIVEN** a player with morale 50, no teammate within 5 tiles and a lit fire 3 tiles away at night
- **WHEN** 60 s pass
- **THEN** morale is 50

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
- **GIVEN** a solo player on run 1 with no downed-timer bonus
- **WHEN** their health reaches 0
- **THEN** they die at once, without a downed timer

#### Scenario: Last one alive
- **GIVEN** a co-op player with no downed-timer bonus whose only teammate has died
- **WHEN** their health reaches 0
- **THEN** they die at once, without a downed timer

#### Scenario: Experiencia lengthens the downed timer
- **GIVEN** a co-op player with 10 s of downed-timer bonus
- **WHEN** their health reaches 0
- **THEN** they are downed for 100 s

#### Scenario: Poison
- **GIVEN** a player with health 100
- **WHEN** they are poisoned
- **THEN** health is 90 after 15 s and 80 after 30 s

### Requirement: Solo play
Every meter rule SHALL work for a single player: no meter needs a teammate to recover. A player with no living teammate is never downed, so being revived, fed or dragged by a teammate never applies to them. A lit fire keeps a lone player company at night. Drinking, eating, sleeping, fires, songs and found texts all work alone, and the drains leave one player able to survive 3 days on the sandbar on its coconuts.

#### Scenario: A night alone by the fire
- **GIVEN** a solo player with morale 40 at dusk
- **WHEN** they light a fire and stay within 5 tiles of it through the night
- **THEN** morale is 45 at dawn and they never hallucinate

#### Scenario: Three solo days on the sandbar
- **GIVEN** one player starting full at dawn with 10 coconuts (+15 thirst, +5 hunger each), spending half of each day phase in the sun and each night by a fire
- **WHEN** they drink a coconut whenever thirst drops below 15, for 3 in-game days
- **THEN** thirst and hunger never reach 0, at most 10 coconuts are used and morale never drops below 20

### Requirement: Solo last stand
At 0 health a player with no other living player SHALL get a last stand lasting 0 s plus their downed-timer bonuses (Experiencia levels and the point boost; endings-progression owns those numbers). They lie where they fell, still losing thirst and hunger, and can use a cup whose item revives on themselves to stand at 30 health. When the last stand ends they die; with no bonus (run 1) they die at once.

#### Scenario: Last stand with Experiencia
- **GIVEN** a solo player with 15 s of downed-timer bonus (3 Experiencia levels)
- **WHEN** their health reaches 0
- **THEN** they are in a last stand, alive after 14 s and dead after 15 s

#### Scenario: Saving yourself
- **GIVEN** a solo player in a last stand with 5 s left and a rain cup
- **WHEN** they use the rain cup on themselves
- **THEN** they stand with health 30 and thirst +25

### Requirement: Free revive
A player holding an unused free revive (the Medalla de la Caridad keepsake: one per run) SHALL, when their health reaches 0, stand at 30 health instead of going down, starting a last stand or dying, and the free revive is used up. It needs no reviver, so it works solo.

#### Scenario: The Medalla saves a solo player once
- **GIVEN** a solo player on run 1 holding the Medalla with its revive unused
- **WHEN** their health reaches 0, and later reaches 0 again
- **THEN** the first time they stand at 30 health and the revive is used up; the second time they die

#### Scenario: The Medalla in co-op
- **GIVEN** a co-op player holding the Medalla with its revive unused
- **WHEN** their health reaches 0
- **THEN** they stand at 30 health instead of going down

### Requirement: HUD bars
The local player's screen SHALL show six labelled bars in Spanish (Sed, Hambre, Calor, Energía, Ánimo, Salud), each filled to its meter's value out of 100 and updated when the value changes, readable at 640×360 in the committed pixel font. Heat fills as it rises. While the local player has sunstroke, their screen is blurred.

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

### Requirement: Statuses are synced
A player's statuses (bleeding, and any later one) SHALL be host-authoritative and synced like the meters: only the host starts or ends one, and every peer, including one that joins later, reads the host's statuses for every player. A client never starts or ends a status. With exactly 1 player, offline, the player's own peer is the host and statuses work as before.

#### Scenario: A client knows it bleeds
- **GIVEN** a host and a client whose player is in the water during a crossing
- **WHEN** a shark bites the client's player on the host
- **THEN** the client's game has its own player bleeding, and when the host ends the bleeding, it ends on the client too

#### Scenario: A late joiner sees who bleeds
- **GIVEN** a host whose own player is bleeding
- **WHEN** a client joins
- **THEN** the client's game has the host's player bleeding

#### Scenario: Solo bleeding unchanged
- **GIVEN** a 1-player crossing, offline, whose player swims at energy 15
- **WHEN** the shark pass comes
- **THEN** the player bleeds, as before

### Requirement: Bleeding tag on the HUD
While the local player bleeds, their screen SHALL show a red "Sangrando" tag in the committed pixel font under the meter bars, and hide it when the bleeding ends. It follows the player's synced status, so a client's tag follows the host. The bars panel with the tag still fits the top-left quarter of 640×360. With exactly 1 player, offline, the tag works the same.

#### Scenario: Solo player sees they bleed
- **GIVEN** the HUD of a 1-player run, offline, whose player is not bleeding
- **WHEN** a shark bite makes the player bleed, and later the bleeding ends
- **THEN** the "Sangrando" tag shows under the bars while they bleed and is hidden after

#### Scenario: A client's tag follows the host
- **GIVEN** a host and a client whose player is in the water during a crossing
- **WHEN** the host's shark bites the client's player, and later the host ends the bleeding
- **THEN** the client's screen shows "Sangrando" under its bars, then hides it

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
