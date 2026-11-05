# creatures-ai

## Purpose
Creature definitions and state-machine AI for every threat in `docs/BESTIARY.md`. Study: Brogue `Monsters.c` for Dijkstra-map movement and flee/approach logic; DCSS `mon-behv.cc` for behavior flags.

## Requirements

### Requirement: Creature resource
Each creature SHALL be a `.tres` with: id, sprite, health, speed, damage, domain (land/shallow/deep), spawn rules (chain, time of day, weather, tide), behavior id, loot. Adding a creature requires no script change.

### Requirement: Behavior state machines
Behaviors SHALL be implemented as reusable state machines in `game/scripts/ai/`: `patrol_circle_strike` (sharks), `hidden_ambush` (eels, crocodile), `pack_swarm` (barracuda), `drift_trap` (man o' war), `night_thief` (crabs), `swoop_steal` (gulls), `gas_cloud` (mosquitoes), `grab_drag` (crocodile), `static_hazard` (ants, manchineel).

### Requirement: Shark targeting
Sharks SHALL only strike a target that is bleeding or has energy < 20; otherwise they circle for 6–10 s and leave. A thrown raw fish SHALL decoy all sharks within 8 tiles for 10 s.

#### Scenario: Clean swimmer
- GIVEN a swimmer with no bleeding and energy 80
- WHEN a reef shark investigates
- THEN it circles and leaves without striking

### Requirement: Grab and rescue
The crocodile grab SHALL drag 1 tile/s toward deep water; three weapon hits within 5 s by teammates release the player; solo escape is 50%/s at 10 health/s cost.

### Requirement: Bosses
Tiger shark, old crocodile and the cutter SHALL be set-piece encounters with a trick (drive-off, dusk window, go dark), not kill targets. The hurricane and the Straits are weather bosses in `weather-daynight` and `crossing`.

### Requirement: Noise and smell
Creatures SHALL subscribe to a world event bus: `noise(pos, radius)` and `blood(pos)` events drive investigation. Fire emits light; patrols subscribe to `smoke`.

### Requirement: Pathfinding
Land creatures SHALL use the island `AStarGrid2D`; sea creatures the water grid. Recompute paths at most every 0.5 s per creature.
