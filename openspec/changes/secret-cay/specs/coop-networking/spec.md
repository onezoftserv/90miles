# Spec Delta

## MODIFIED Requirements

### Requirement: Difficulty scaling
Difficulty SHALL be counted from the living, connected players when each island is set up: resource spawn rates multiply by 0.8 per such player beyond the first, and patrol count adds 1 per 2 such players, rounded down. Dropped and dead players do not count. One player (solo, or the last survivor of a party) gets ×1 and +0 patrols. Solo uses the same base numbers as co-op; there is no separate solo tuning. The secret cay (secret-cay) is never scaled: its handmade contents are the same for 1–4 players and it has no patrols. (Changes docs/GAME_DESIGN.md §10 "Co-op rules" for the cay only.)

#### Scenario: Three players
- GIVEN a session with 3 players
- WHEN an island is set up
- THEN resource spawn rates are ×0.64 (0.8 × 0.8) and patrol count is +1

#### Scenario: Solo island
- **GIVEN** a solo session
- **WHEN** an island is set up
- **THEN** resource spawn rates are ×1 and the patrol count is unchanged

#### Scenario: Last survivor of four
- **GIVEN** a 4-player run in which 3 players are dead
- **WHEN** the next island is set up
- **THEN** resource spawn rates are ×1 and the patrol count is unchanged

#### Scenario: The cay is not scaled
- **GIVEN** a session with 4 players
- **WHEN** the secret cay is set up
- **THEN** it holds the same pick-ups, palms and coconuts as for one player, and no patrol
