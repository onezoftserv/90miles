# island-generation

## Purpose
Procedural islands from chain templates, with biome bands, POIs and escape routes placed by rules. Study: Shattered Pixel Dungeon `levels/builders` and `levels/painters` for the room/painter split; Brogue `Architect.c` for lakes, bridges and machines.

## Requirements

### Requirement: Seeded generation
An island SHALL be generated deterministically from (run seed, island index, chain id). The host generates and sends the seed; clients regenerate locally and verify a hash.

### Requirement: Landmass
The generator SHALL produce a 96×64 grid with a noise-shaped landmass sized by chain (sandbar ~15% land, lighthouse ~45%). Bands from the shoreline inward: deep water, shallows (1–2 tiles), beach (2–4 tiles), then the chain's interior biome (dune, mangrove, rock, scrub).

#### Scenario: Sandbar
- GIVEN chain = sandbar
- WHEN an island is generated
- THEN land is 10–20% of tiles, there is no interior biome beyond dune, and no tile is more than 6 tiles from water

### Requirement: Biome rules
Mangrove tiles SHALL only touch shallow or brackish water. Rock chains SHALL have cliff edges (impassable from the low side). Lagoons SHALL be enclosed shallow water with one channel.

### Requirement: POI placement
The generator SHALL place 3–6 POIs from the chain's table (`docs/ISLANDS.md`) honoring: minimum distance 12 tiles between POIs, shoreline access for boats/wrecks, no duplicate kinds, at most one set piece. Guaranteed POIs (e.g. binoculars cairn on rock) SHALL always be placed.

### Requirement: Escape routes
Each island SHALL expose 2–3 escape-route POIs chosen from the chain's allowed list, with at least one always-buildable route (raft) unless the chain says otherwise.

### Requirement: Resource spawns
Resources SHALL spawn per `docs/ISLANDS.md` resource rules, scaled by party size, with respawn hooks for squalls and nights.

### Requirement: Navigation data
The generator SHALL output an `AStarGrid2D` with costs: beach 1, dune 1.5, mangrove 3, shallows 2 (wade), deep water impassable for land AI; and a separate water grid for sea creatures.

### Requirement: Validation
A generated island SHALL be rejected and regenerated if any POI is unreachable from the player spawn by land+shallows, or if no escape route is reachable.
