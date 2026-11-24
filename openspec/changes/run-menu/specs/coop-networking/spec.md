## MODIFIED Requirements

### Requirement: Pause
The pause button SHALL open the run menu (ui-shell "Run menu") in every mode, unless a HUD panel is open (inventory-hud's crafting list, the sign note), which it closes instead. In a solo session (one player, offline) the menu also freezes the whole simulation (clock, meters, creatures, patrols, weather) until the player resumes. In co-op, or while hosting, nothing pauses: while the menu is open the local player moves, runs, interacts and uses nothing, and keeps a crouch they held. Save-and-quit is out of scope.

#### Scenario: Solo pause
- **GIVEN** a solo player
- **WHEN** they press pause
- **THEN** the run menu shows and nothing in the simulation advances, and when they resume it runs again from where it stopped

#### Scenario: No pause in co-op
- **GIVEN** a host with a client
- **WHEN** the client presses pause
- **THEN** the run menu shows on the client only, nothing pauses on either peer, and the host's player and the clock keep going

#### Scenario: Held still while the menu is open
- **GIVEN** a host with a client whose player walks east, crouched
- **WHEN** the client opens the run menu
- **THEN** within 0.2 s the host has that player standing still and still crouched, its meters keep running on the host, and once the client closes the menu it moves again

#### Scenario: Pause closes a panel in co-op
- **GIVEN** a host with a client whose crafting list is open
- **WHEN** the client presses pause
- **THEN** the list closes, nothing pauses and the run menu stays closed

#### Scenario: A host alone pauses nothing
- **GIVEN** exactly 1 player hosting a run with nobody joined
- **WHEN** they press pause
- **THEN** the run menu shows with the "Menú" tab and the clock keeps going
