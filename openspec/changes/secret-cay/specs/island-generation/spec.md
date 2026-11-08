# Spec Delta

## ADDED Requirements

### Requirement: Off-graph handmade layouts
A handmade layout marked off-graph (the secret cay) SHALL never be generated, enumerated as an island of a chain or the run graph, given an island index, counted as an island, or scaled by party size or Experiencia. Only the feature that owns it opens it. The one listing of the layouts a run may use as numbered islands leaves it out. With 1 player it is set aside the same way.

#### Scenario: Listing the islands skips the cay
- **GIVEN** the island layouts in the content folder, one of them the cay marked off-graph
- **WHEN** the layouts a run may use as numbered islands are listed for a 1-player run
- **THEN** the sandbar is listed and the cay is not

## MODIFIED Requirements

### Requirement: Escape routes
Each island SHALL expose 2–3 escape-route POIs chosen from the chain's allowed list, with at least one always-buildable route (raft) unless the chain says otherwise. An island set up for exactly one living, connected player SHALL also expose at least one reachable route that needs no background skill and no starting item (docs/GAME_DESIGN.md §10), even where the chain overrides the raft rule. Solo otherwise uses the same base numbers as co-op. An off-graph handmade layout (the secret cay, secret-cay) exposes only the routes its layout lists instead of 2–3; the cay lists only the raft, which one player with an empty inventory can gather, build and launch, so it meets the solo guarantee. (Changes docs/ISLANDS.md "Each island rolls 2–3 escape routes" for off-graph layouts.)

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

#### Scenario: The cay's one route
- **GIVEN** one offline player with an empty inventory on the secret cay
- **WHEN** its escape routes are listed
- **THEN** the raft is the only route, it needs no background skill and no starting item, and its build site is reachable from the solo spawn

### Requirement: Resource spawns
Resources SHALL spawn per `docs/ISLANDS.md` resource rules, scaled by party size, with respawn hooks for squalls and nights. Party size SHALL be the number of living, connected players when the island is set up (the count coop-networking's difficulty scaling uses), and respawns on that island use the same count. An off-graph handmade layout (the secret cay, secret-cay) instead places exactly the pick-ups its layout lists, never scaled by party size, and none of them respawns after a squall or a night. (Changes docs/ISLANDS.md "Resource rules" for off-graph layouts.)

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

#### Scenario: Nothing respawns on the cay
- **GIVEN** one offline player on the secret cay who has taken every driftwood
- **WHEN** a squall passes and a night ends
- **THEN** no pick-up has respawned
