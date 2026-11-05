# weather-daynight

## Purpose
Day-night cycle, weather states, tides and the hurricane boss.

## Requirements

### Requirement: Day cycle
A day SHALL last 12 real minutes: dawn 1, day 5, dusk 1, night 5. `WeatherManager` drives a `CanvasModulate` color curve and emits `phase_changed`.

### Requirement: Weather states
The manager SHALL hold one of: calm (scorching), trade-wind, squall, fog, hurricane. Transitions are rolled per phase with chain-based weights; a squall is announced 60 s early by a dark horizon line; a hurricane is announced one day early by an NPC.

### Requirement: Effects
Each state SHALL apply the effects in `docs/GAME_DESIGN.md` §5 (heat multipliers, sail availability, fire extinguish, visibility, patrol behavior).

#### Scenario: Squall puts out fires
- GIVEN a lit fire on the beach
- WHEN a squall starts
- THEN the fire goes out within 5 s unless it is inside a structure

### Requirement: Tides
Tide SHALL flip every half day. Low tide exposes reef flats and tide pools and strands the man o' war; high tide floods mangrove paths and floats beached boats.

### Requirement: Hurricane boss
On the storm key, the hurricane SHALL run a scripted night: wind pushes entities 1 tile/s, water rises 3 tiles over 2 minutes, unsecured structures and items are destroyed, players behind the dune or inside the family house take no damage. After it, the wreck field respawns resources ×3.

### Requirement: Weather sync
Weather state and phase SHALL be host-authoritative and synced to clients on change and on join.
