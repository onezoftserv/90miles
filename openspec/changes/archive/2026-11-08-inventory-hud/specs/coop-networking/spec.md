# Spec Delta

## MODIFIED Requirements

### Requirement: Pause
In a solo session (one player, offline) the pause button SHALL open the pause menu and freeze the whole simulation (clock, meters, creatures, patrols, weather) until the player resumes. Co-op has no pause: with other players, or while hosting, the pause button pauses nothing and opens no menu; it only closes an open HUD panel (inventory-hud's crafting list). Save-and-quit is out of scope.

#### Scenario: Solo pause
- **GIVEN** a solo player
- **WHEN** they press pause
- **THEN** the pause menu shows and nothing in the simulation advances, and when they resume it runs again from where it stopped

#### Scenario: No pause in co-op
- **GIVEN** a host with a client
- **WHEN** either player presses pause
- **THEN** nothing pauses and no pause menu shows

#### Scenario: Pause closes a panel in co-op
- **GIVEN** a host with a client whose crafting list is open
- **WHEN** the client presses pause
- **THEN** the list closes, and nothing pauses
