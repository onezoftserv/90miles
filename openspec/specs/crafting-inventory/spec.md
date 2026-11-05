# crafting-inventory

## Purpose
Items, inventory, recipes, identification, durability and stashes. Study: Shattered Pixel Dungeon `items/` and alchemy; DCSS item data files.

## Requirements

### Requirement: Item resource
Each item SHALL be a `.tres` with: id, name (es/en), sprite, stack size, weight, tags (food, water, tool, material, shiny, keepsake, text), use effect, durability, identify group.

#### Scenario: Item loaded from data
- GIVEN an item `.tres` with id, name (es/en), sprite, stack size, weight, tags, use effect, durability and identify group
- WHEN the game loads it
- THEN the item exists in game with exactly those values

### Requirement: Inventory
Players SHALL have 12 slots and a weight limit (30); swimming with weight > 15 drains energy ×2 and drops a random heavy item at energy 0.

#### Scenario: Swimming overloaded
- GIVEN a player carrying weight 20
- WHEN they swim until energy reaches 0
- THEN energy drained at ×2 the whole way and a random heavy item is dropped at energy 0

### Requirement: Recipes
Recipes SHALL be `.tres` with inputs, output, station (none, workbench, fire), time, and skill multiplier. Core recipes per `docs/GAME_DESIGN.md` §6.

#### Scenario: Workbench recipe
- GIVEN a recipe `.tres` with station workbench
- WHEN a player holding its inputs crafts it at a workbench
- THEN after the recipe's time the inputs are consumed and the output is added

### Requirement: Identification
Unknown fruit SHALL appear as a generic name per identify group until eaten or named by an NPC/Médico; identification is party-wide and run-scoped.

#### Scenario: Manchineel
- GIVEN an unidentified "fruta verde" that is manchineel
- WHEN a non-Médico eats it
- THEN the item is identified for the party and the eater takes 50 damage over 60 s

### Requirement: Durability
Tools SHALL lose durability per use; at 0 they break. Rafts lose 25% integrity per crossing. Repair recipes restore.

#### Scenario: Raft after two crossings
- GIVEN a raft at full integrity
- WHEN it completes two crossings with no other damage
- THEN its integrity is 50%

### Requirement: Stashes
Items on the ground or in open containers SHALL be subject to crab and gull theft; sealed containers (lidded jug, cooler, buried bag) are safe.

#### Scenario: Sealed jug
- GIVEN food on the ground and food in a lidded jug
- WHEN crabs and gulls come to steal
- THEN they can take the food on the ground but not the food in the jug

### Requirement: Shared builds
Build sites (raft, still, rain catcher, fire) SHALL accept deposits from any player and show progress to all.

#### Scenario: Two players feed a still
- GIVEN a still build site
- WHEN two different players each deposit materials into it
- THEN both deposits count toward the build and every player sees the same progress
