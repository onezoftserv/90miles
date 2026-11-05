# Spec Delta

## MODIFIED Requirements

### Requirement: Escape routes
Each island SHALL expose 2–3 escape-route POIs chosen from the chain's allowed list, with at least one always-buildable route (raft) unless the chain says otherwise. An island set up for exactly one living, connected player SHALL also expose at least one reachable route that needs no background skill and no starting item (docs/GAME_DESIGN.md §10), even where the chain overrides the raft rule. Solo otherwise uses the same base numbers as co-op.

#### Scenario: Raft always offered
- GIVEN a chain that does not override the raft rule
- WHEN an island is generated
- THEN it exposes 2–3 escape-route POIs from the chain's allowed list, one of them the raft

#### Scenario: Solo island where the chain drops the raft
- GIVEN a 1-player run whose only player is a Músico, and a chain whose allowed list overrides the raft rule
- WHEN island 5 is generated
- THEN at least one of its 2–3 escape routes needs no background skill and no starting item, and is reachable from the player spawn

#### Scenario: Last survivor gets the same guarantee
- GIVEN a 3-player run in which 2 players died
- WHEN the next island is set up
- THEN it counts 1 living player and exposes at least one escape route that needs no background skill and no starting item

### Requirement: Resource spawns
Resources SHALL spawn per `docs/ISLANDS.md` resource rules, scaled by party size, with respawn hooks for squalls and nights. Party size SHALL be the number of living, connected players when the island is set up (the count coop-networking's difficulty scaling uses), and respawns on that island use the same count.

#### Scenario: Squall respawn
- GIVEN an island whose resources spawned per `docs/ISLANDS.md`
- WHEN a squall passes
- THEN the squall respawn hook runs and resources respawn per those rules, scaled by party size

#### Scenario: Solo island
- GIVEN a 1-player run
- WHEN island 2 is set up
- THEN party size is 1 and resources spawn at the `docs/ISLANDS.md` amounts with no party-size reduction (×1)

#### Scenario: Dead players do not count
- GIVEN a run that started with 4 players, 3 of whom died on island 3
- WHEN island 4 is set up
- THEN party size is 1, the same as a 1-player run
