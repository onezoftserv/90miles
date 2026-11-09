# Spec Delta

## MODIFIED Requirements

### Requirement: Workbench
A workbench (a flat rock or a wreck table placed by the level) SHALL be a station and an interactable: a player within 1 tile can craft any known workbench recipe whose inputs and tools they carry, or place the site of any known build-site recipe whose output is a structure. Crafting sets the crafting state for the hunger drain while it runs, and stops if the player leaves the bench's reach.

#### Scenario: Solo workbench craft
- GIVEN one offline player at a workbench holding a workbench recipe's inputs
- WHEN they craft it and stay for its time
- THEN the output is in their inventory

#### Scenario: Solo places a fire site at the bench
- **GIVEN** one offline player within 1 tile of a workbench, carrying nothing, standing on a free land cell that is not the bench's
- **WHEN** they choose the fire recipe there
- **THEN** an empty fire site lies on the land cell under them, ready for deposits

#### Scenario: A station that is not a workbench
- **GIVEN** a client within 1 tile of the raft site
- **WHEN** it asks to place a fire site naming the raft site as the station
- **THEN** nothing is placed and nothing changes

## ADDED Requirements

### Requirement: Placing a build site
When a player places a build-site recipe at a workbench in their reach, the host SHALL put an empty site of that recipe on the free cell nearest the player within 1 tile whose terrain the recipe allows (any land when it lists none): not the bench's cell and not one holding a structure or a site. An island holds at most one unfinished site per recipe; a second request, or one with no free cell, changes nothing. A solo player places and builds sites alone.

#### Scenario: One unfinished fire
- **GIVEN** one offline player who placed a fire site and has not built it
- **WHEN** they ask the bench for a fire site again
- **THEN** no second site appears, and once the first fire is built they may place another

#### Scenario: A client's request names only the recipe and the bench
- **GIVEN** a client within 1 tile of the workbench
- **WHEN** it asks for a rain catcher site
- **THEN** the host places the site by the client's own player, at a cell the host picks; the request carries no position

### Requirement: Placed sites on every peer
A site placed at a workbench, its deposits of items and of tags, its progress and the structure it becomes SHALL reach every player in the session, and players who join later get the current state. The structure exists once on every peer and its build effects apply once, on the host. Solo the same.

#### Scenario: One fire, once
- **GIVEN** one offline player who deposits 3 driftwood and 1 dry grass into a fire site placed at the bench, with morale 50
- **WHEN** they work it for 30 s
- **THEN** exactly one fire stands where the site was, it is the only lit fire there, and morale rose by 5 once

#### Scenario: Tag deposits reach a client
- **GIVEN** a host and a client next to a fire site placed at the bench
- **WHEN** the host's player deposits 3 driftwood and 1 dry grass
- **THEN** the client's copy of the site has every input in

#### Scenario: A joiner sees a built fire
- **GIVEN** a host who placed and built a fire at the workbench
- **WHEN** a client joins the run
- **THEN** the client sees the fire where the host built it

#### Scenario: A joiner mid-build
- **GIVEN** a host who filled a fire site and worked it to 50 %
- **WHEN** a client joins the run
- **THEN** the client's copy of the site has every input in and progress 50 %
