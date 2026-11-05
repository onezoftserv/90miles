# escape-routes

## Purpose
The ways off an island. Each is a POI with requirements, a capacity, and a crossing profile.

## Requirements

### Requirement: Route resource
Each route SHALL be a `.tres` with: id, display name, requirements (items, quest flags, weather, skill), capacity (int or "all"), risk profile for the crossing, and the NPC or object that starts it.

### Requirement: Routes
The game SHALL implement these routes: raft, repair-wreck, turtle, binoculars-swim, tarp-sail, dolphins, signal-boat, gulf-stream, with the requirements in `docs/GAME_DESIGN.md` §7.

#### Scenario: Turtle capacity
- GIVEN a party of 4 and a freed, fed turtle
- WHEN two players board her
- THEN the route starts for those two only; the other two remain on the island with the other routes available

### Requirement: Shared crafting
A raft SHALL be a shared build site: any player can deposit materials into it; progress is visible to all; building requires at least one player working. A Mecánico builds at 2×.

### Requirement: Weather gating
Tarp-sail SHALL require trade wind; binoculars-swim SHALL require clear weather and energy ≥ 100 for each swimmer; signal-boat SHALL only succeed in the first hour after dusk or the last before dawn.

### Requirement: Split parties
When a route takes a subset of the party, the island SHALL remain active for the others; the next island waits until all living players arrive or die. Arrived players spawn on the next island's beach and can survive there meanwhile.

### Requirement: Route discovery
Routes SHALL be hidden until discovered (seen, told by an NPC, or revealed by charts/keepsake). Discovered routes show on the island map with their requirements.
