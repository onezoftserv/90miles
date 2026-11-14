# Spec Delta

## ADDED Requirements

### Requirement: Route items spent at the start
A route requirement that asks for an item and is marked to be used up SHALL take that many of the item from the player who starts the route. A rider requirement so marked SHALL take it from each rider. Both happen only once the route starts, after every check has passed. A refused start spends nothing. With exactly 1 player, that player is both the starter and the only rider.

#### Scenario: Solo board refused in calm, then started
- **GIVEN** a 1-player run, a player carrying one rigged board, on an island offering a route that needs trade wind and uses up one rigged board per rider
- **WHEN** the player asks to start it in calm weather, and then again once the weather is trade wind
- **THEN** the first request starts nothing and the board stays in the inventory; the second starts the route for that player and the board is gone

#### Scenario: Each rider spends their own
- **GIVEN** a party of 3 in trade wind beside each other, two of them carrying one rigged board each, on that route
- **WHEN** one of the two asks to start it
- **THEN** the two board carriers ride and each has spent their own board; the third stays on the island with nothing spent

#### Scenario: The starter's fuel jug
- **GIVEN** a 1-player run, a player carrying 2 fuel jugs, on a route that uses up 1 fuel jug from the starter
- **WHEN** the route starts
- **THEN** the player holds 1 fuel jug
