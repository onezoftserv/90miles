## ADDED Requirements

### Requirement: Coast cay creatures
The creature spawner SHALL read the island's chain family from its layout, not assume the sandbar. On the coast cay one reef shark patrols offshore (deep water at least 2 tiles from shore) and land crabs come out on its beaches at night with the same rules and numbers as on the sandbar; there are no gulls, since no palm on it is a nest. Exactly 1 player meets the same creatures.

#### Scenario: Creatures of a solo arrival
- GIVEN one offline player who has just arrived on the coast cay at dawn
- WHEN the island's creatures start
- THEN one reef shark is in deep water at least 2 tiles from shore and no gull or crab is present, and at night crabs spawn on its beach
