# Spec Delta

## MODIFIED Requirements

### Requirement: Camera and viewport
The game SHALL render the world at 640×360 with integer scaling. The enlarged picture uses nearest filtering by default; the optional pixel filter setting (ui-shell "Pixel filter") smooths it instead, keeping the 640×360 base and the integer scale. In co-op each client follows its own player; the host sees the same.

#### Scenario: Two players apart
- **GIVEN** two players in a co-op session
- **WHEN** they move apart
- **THEN** each client's camera follows its own player, rendered at 640×360 with integer scaling and nearest filtering by default

#### Scenario: Smooth filter keeps the base
- **GIVEN** a player whose pixel filter is Suave
- **WHEN** their camera follows them at 2×
- **THEN** the world is still rendered at 640×360 and enlarged by exactly 2, with the smoothing applied only to the enlarged picture
