# Spec Delta

## MODIFIED Requirements

### Requirement: Item resource
Each item SHALL be a `.tres` with: id, name (es/en), sprite, stack size, weight, tags (food, water, tool, material, shiny, keepsake, text, secret), use effect, durability, identify group, spawn weight, and a concealment radius in tiles (0 for an ordinary item). The secret tag means only that no discovery, map, marker or AI system ever shows the item and that no item-tag spawn or found-text placement ever picks it (secret-cay), so a secret item's spawn weight is 0; a concealment radius above 0 makes it concealed on the ground until a player comes within that radius. Both work the same with 1 player. (Adds the `secret` tag to docs/ITEMS.md's tag list.)

#### Scenario: Item loaded from data
- GIVEN an item `.tres` with id, name (es/en), sprite, stack size, weight, tags, use effect, durability and identify group
- WHEN the game loads it
- THEN the item exists in game with exactly those values

#### Scenario: A secret, concealed item from data
- GIVEN the broken compass's `.tres`, tagged secret with a concealment radius of 3
- WHEN a solo offline game loads it
- THEN the item has the secret tag, a spawn weight of 0 and a concealment radius of 3, and an ordinary item such as driftwood has neither the tag nor a radius

### Requirement: Pick-up
Items on the ground SHALL be picked up through the player-movement interaction (nearest interactable within 1 tile, instant unless the item sets a hold time or is concealed: an item whose concealment radius is above 0 takes the secret tuning's concealed pick-up hold, 1.5 s today, secret-cay). The host applies the pick-up; if the inventory cannot take the item it stays on the ground. Items with pick-up disabled cannot be picked up. Pick-up effects of the item apply to the player who took it.

#### Scenario: Solo pick-up
- GIVEN one offline player next to driftwood on the ground
- WHEN they press interact
- THEN the driftwood is in their inventory

#### Scenario: Solo pick-up of a concealed item
- **GIVEN** one offline player within 1 tile of the concealed map, with room in their inventory
- **WHEN** they press interact once, then hold it for 1.5 s
- **THEN** the map is still on the ground after the press and in their inventory after the hold
