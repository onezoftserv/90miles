# Spec Delta

## MODIFIED Requirements

### Requirement: Shark targeting
Sharks SHALL only strike a target that is bleeding or has energy < 20, or one that is ALONE when the shark strikes on ALONE (the bull shark); otherwise they circle for 6–10 s and leave. ALONE holds when no other player and no living companion is within 5 tiles of the target. A noise event that reaches a shark striking on ALONE makes it leave for 20 s instead of investigating. A thrown raw fish SHALL decoy all sharks within 8 tiles for 10 s. (Defines docs/BESTIARY.md #16.)

#### Scenario: Clean swimmer
- GIVEN a swimmer with no bleeding and energy 80
- WHEN a reef shark investigates
- THEN it circles and leaves without striking

#### Scenario: Solo swimmer alone in bull-shark water
- GIVEN a 1-player run whose player swims clean with energy 80 in a lagoon, with no companion within 5 tiles
- WHEN a bull shark investigates
- THEN it strikes for 30 damage

#### Scenario: Solo swimmer with a companion
- GIVEN a 1-player run whose player swims clean with energy 80 in a lagoon, with a living companion 3 tiles away
- WHEN a bull shark investigates
- THEN it circles and leaves without striking

#### Scenario: Noise scares a bull shark
- GIVEN a 1-player run whose player swims alone with energy 80 and a bull shark circles 6 tiles away
- WHEN the player blows a conch horn (noise radius 15)
- THEN the bull shark leaves for 20 s without striking

### Requirement: Grab and rescue
The crocodile grab SHALL drag 1 tile/s toward deep water; three weapon hits within 5 s by teammates release the player (the old crocodile needs six). In any party size the grabbed player may mash interact: each second first rolls a 50% escape, and only a failed roll costs that second's 10 health. The grab, its damage and the mash are the same for every party size. (Changes docs/BESTIARY.md "Sea crocodile".)

#### Scenario: Teammates break the grab
- GIVEN a crocodile dragging a player 1 tile/s toward deep water
- WHEN teammates land three weapon hits on it within 5 s
- THEN the player is released

#### Scenario: Solo mash, roll before damage
- GIVEN a 1-player run whose player, at 60 health after the lunge, is grabbed by a crocodile 3 tiles from deep water
- WHEN the player mashes, the first roll fails and the second succeeds
- THEN the player is released after 2 s at 50 health, 1 tile from deep water

#### Scenario: Solo player and the old crocodile
- GIVEN a 1-player run whose player at 100 health is lunged at by the old crocodile for 80 damage
- WHEN the player mashes and the first roll succeeds
- THEN the player is released at 20 health, the same as in co-op

## ADDED Requirements

### Requirement: Crocodile death roll
When a crocodile's drag reaches deep water before the grab ends, the crocodile SHALL death-roll: the player takes 20 damage and starts bleeding, and the grab ends there.

#### Scenario: Solo player dragged into deep water
- GIVEN a 1-player run whose player, at 60 health after the lunge, is grabbed 2 tiles from deep water and does not mash
- WHEN the drag reaches deep water after 2 s
- THEN the player takes 20 damage (40 health), starts bleeding and is released in deep water

### Requirement: Boa grab
The boa grab SHALL constrict the player for 10 health/s for up to 5 s. Two weapon hits by teammates free the player. In any party size the grabbed player may mash interact: each second first rolls a 50% escape, and a success frees them before that second's damage. (Defines docs/BESTIARY.md #30.)

#### Scenario: Solo player mashes free of a boa
- GIVEN a 1-player run whose player at 40 health is grabbed by a boa
- WHEN the player mashes, the first roll fails and the second succeeds
- THEN the player is released after 2 s at 30 health

#### Scenario: Solo player who never escapes
- GIVEN a 1-player run whose player at 60 health is grabbed by a boa
- WHEN every mash roll fails for 5 s
- THEN the player is released at 10 health
