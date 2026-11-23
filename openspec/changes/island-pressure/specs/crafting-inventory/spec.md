## MODIFIED Requirements

### Requirement: Shared builds
Build sites (raft, still, rain catcher, fire) SHALL accept deposits from any player and show progress to all. A build site is placed by the first player who starts a build-site recipe; deposits move matching inputs from the depositor's inventory; work advances only while at least one player works it and its inputs are complete (for a staged build, the inputs of the stage being worked: "Build stages"). One player can deposit everything and do all the work.

#### Scenario: Two players feed a still
- GIVEN a still build site
- WHEN two different players each deposit materials into it
- THEN both deposits count toward the build and every player sees the same progress

#### Scenario: One player builds a fire
- GIVEN a solo player holding 3 driftwood and 1 dry grass
- WHEN they place a fire build site, deposit everything and work it for the recipe's time (30 s)
- THEN the fire is built and lit, and 3 driftwood and 1 dry grass have left their inventory

## ADDED Requirements

### Requirement: Build stages
A build-site recipe SHALL be able to list stages in order, each with a name, its own inputs and its own work time, adding up to the recipe's inputs and time. A deposit takes any of the recipe's inputs. A stage can be worked once its inputs and every earlier stage's are in, and work never passes into a stage whose inputs are missing. Progress stays one shared value; the stage being worked is the one progress has reached. With exactly 1 player, that player works every stage.

#### Scenario: Solo raft waits at a stage
- **GIVEN** a 1-player run, offline, at the raft site, the player holding 2 inner tubes and 3 rope and no driftwood, at energy 100
- **WHEN** they deposit everything and hold interact on the site for 40 s
- **THEN** the first stage, "Amarrar las cámaras", is done after 30 s, the site's progress stays at 30 of 120 s, and the site asks for 4 driftwood for "Armar el piso"

#### Scenario: Everything in at once
- **GIVEN** a 1-player run, offline, whose player deposits 6 driftwood, 2 inner tubes and 3 rope into the raft site
- **WHEN** they hold interact on the site for 60 s
- **THEN** the site's progress is 60 of 120 s and the stage being worked is the third, "Amarrar la baranda"

#### Scenario: A recipe without stages
- **GIVEN** a solo player at a fire site with its 3 driftwood and 1 dry grass deposited
- **WHEN** they work it for 30 s
- **THEN** the fire is built, as before

### Requirement: Held work on staged builds
A staged build SHALL advance only while a worker in reach holds interact on it. Letting go stops the work and keeps the progress; holding again continues where it stopped. Each worker who holds adds their own work, so two workers finish a stage in half the time. A build without stages keeps the rule that a worker in reach works it. With exactly 1 player, that player holds alone.

#### Scenario: Letting go keeps the work
- **GIVEN** a 1-player run, offline, at the raft site with every input in
- **WHEN** the player holds interact for 10 s, lets go and walks away for 20 s, then comes back and holds for 20 s more
- **THEN** the first stage is done and the site's progress is 30 of 120 s

#### Scenario: Two hold together
- **GIVEN** a 2-player run at the raft site with every input in
- **WHEN** both players hold interact on it for 15 s
- **THEN** the first stage is done

### Requirement: Work costs
A build-site recipe MAY name a work cost in energy and thirst per second. Every worker SHALL pay it for each second they work, on top of the normal drains; a worker whose energy is empty does no work until they have energy again. A recipe that names no cost costs nothing extra. The raft names 1 energy and 0.25 thirst per second. With exactly 1 player, that player pays it all. (Implements docs/GAME_DESIGN.md §4 Energy "building 1/s"; adds the thirst cost there.)

#### Scenario: Solo stage at dawn
- **GIVEN** a 1-player run, offline, at dawn, a player at energy 100 and thirst 80 at the raft site with the first stage's inputs in
- **WHEN** they hold interact on the site for 30 s
- **THEN** the first stage is done, their energy is 70 and their thirst is 69.5

#### Scenario: Out of strength
- **GIVEN** a 1-player run, offline, a player at energy 5 holding interact on the raft site with every input in
- **WHEN** 10 s pass
- **THEN** the site's progress rose by 5 s of work and stopped, and the player's energy is 0

#### Scenario: A free fire
- **GIVEN** a solo player at energy 100 at a fire site with its inputs in
- **WHEN** they work it for its 30 s
- **THEN** their energy is still 100
