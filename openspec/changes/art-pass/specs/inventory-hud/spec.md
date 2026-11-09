# Spec Delta

## MODIFIED Requirements

### Requirement: Crouch cue
While a player's movement state is crouch, their body SHALL be drawn in the crouch pose of art-pass's "Crouch pose" requirement, its full 32×32 frames with the feet line where it was and the head lower, and in its standing or moving pose otherwise; while they are also hidden, the hidden mark shows over the crouch pose's head anchor. Every peer draws it from the state the host replicates, so teammates see it too. A solo player sees their own body lowered.

#### Scenario: Solo crouch
- **GIVEN** a solo player walking on sand
- **WHEN** they hold C
- **THEN** their body is drawn in the crouch pose at its full 32×32 frame size with its feet line unchanged, and in the standing pose again when they let go

#### Scenario: A teammate crouches
- **GIVEN** a host and a client
- **WHEN** the client's player crouches
- **THEN** the host draws that player in the crouch pose

#### Scenario: Solo crouch in brush
- **GIVEN** a solo player standing on a brush tile
- **WHEN** they hold C until hidden
- **THEN** their body is drawn in the crouch pose and the hidden mark shows over the crouch pose's head anchor, lower than it would sit over the standing pose
