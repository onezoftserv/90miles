## ADDED Requirements

### Requirement: No platform SDK needed
The import, the smoke run and GUT SHALL pass on a machine with no platform SDK, client or GDExtension installed. Every backend script compiles without its SDK: it reaches platform classes only through `Engine.get_singleton()` and `ClassDB`, never by name. Tests run on ENet over localhost or on the offline peer, and solo on the shipped backend runs offline.

#### Scenario: CI without Steam
- **GIVEN** a Linux CI machine with no Steam client and no GodotSteam
- **WHEN** import, smoke and GUT run
- **THEN** all three pass and the active backend is ENet

#### Scenario: Solo offline on the shipped backend
- **GIVEN** the shipped backend (ENet) and exactly 1 player
- **WHEN** the main scene boots to the title and the player picks "Jugar solo"
- **THEN** the run is on the offline peer, no network port is opened and the backend receives no host, join or leave call
