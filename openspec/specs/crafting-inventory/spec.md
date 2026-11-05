# crafting-inventory

## Purpose
Items, inventory, recipes, identification, durability and stashes. Study: Shattered Pixel Dungeon `items/` and alchemy; DCSS item data files.

## Requirements

### Requirement: Item resource
Each item SHALL be a `.tres` with: id, name (es/en), sprite, stack size, weight, tags (food, water, tool, material, shiny, keepsake, text), use effect, durability, identify group.

### Requirement: Inventory
Players SHALL have 12 slots and a weight limit (30); swimming with weight > 15 drains energy ×2 and drops a random heavy item at energy 0.

### Requirement: Recipes
Recipes SHALL be `.tres` with inputs, output, station (none, workbench, fire), time, and skill multiplier. Core recipes per `docs/GAME_DESIGN.md` §6.

### Requirement: Identification
Unknown fruit SHALL appear as a generic name per identify group until eaten or named by an NPC/Médico; identification is party-wide and run-scoped.

#### Scenario: Manchineel
- GIVEN an unidentified "fruta verde" that is manchineel
- WHEN a non-Médico eats it
- THEN the item is identified for the party and the eater takes 50 damage over 60 s

### Requirement: Durability
Tools SHALL lose durability per use; at 0 they break. Rafts lose 25% integrity per crossing. Repair recipes restore.

### Requirement: Stashes
Items on the ground or in open containers SHALL be subject to crab and gull theft; sealed containers (lidded jug, cooler, buried bag) are safe.

### Requirement: Shared builds
Build sites (raft, still, rain catcher, fire) SHALL accept deposits from any player and show progress to all.
