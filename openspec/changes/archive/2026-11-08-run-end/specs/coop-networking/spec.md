## ADDED Requirements

### Requirement: Removed player's cause
A player removed after their 90 s SHALL count as dead with the cause `removed`, unless their meters had already died while they were away, in which case that cause stays. Every peer keeps the causes with the removed names, in removal order, and a client that joins later receives both. Solo has no client to remove, so this never applies with 1 player.

#### Scenario: Removed after 90 s
- **GIVEN** a host, Dayana and Papo in a run
- **WHEN** Papo drops and 90 s pass
- **THEN** the host and Dayana list Papo as removed with the cause `removed`

#### Scenario: Drowned while away
- **GIVEN** Papo dropped while swimming in a crossing, and his player drowned before his 90 s were up
- **WHEN** his 90 s run out
- **THEN** every peer lists Papo as removed with the cause `drowning`

#### Scenario: A later joiner
- **GIVEN** a run in which Papo was removed
- **WHEN** Yuni joins
- **THEN** Yuni's session lists Papo as removed with the cause `removed`
