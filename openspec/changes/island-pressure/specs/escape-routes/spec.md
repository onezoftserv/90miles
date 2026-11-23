## MODIFIED Requirements

### Requirement: Sandbar routes as data
The raft and binoculars-and-swim SHALL be `RouteData` files `game/resources/routes/raft.tres` and `binoculars_swim.tres`. The raft is started by its built vessel (recipe `raft`: 6 driftwood, 2 inner tubes, 3 rope, a shared build site built in the four stages of "Raft stages", 120 s of base work in all), takes everyone within the boarding radius and is always known. Binoculars-and-swim is started by using `binoculars`. A new route is a new `.tres`; no script changes. Both files pass the content check.

#### Scenario: Routes load from data
- GIVEN the content catalog
- WHEN it loads `routes/`
- THEN `raft` (capacity all, starter recipe `raft`, discovered from the start) and `binoculars_swim` (capacity per swimmer, starter item `binoculars`) load with Spanish and English names and the content check reports no errors

### Requirement: Raft build site
Each sandbar SHALL have one raft build site at its marked beach cell, on every peer at the same path. Any player deposits driftwood, inner tubes and rope from their own inventory up to 6, 2 and 3; progress is shared and shown to every player; work advances only while at least one player holds interact on it, has energy, and the inputs of the stage being worked are in (crafting-inventory "Build stages", "Held work on staged builds", "Work costs"). When it completes it becomes a beached raft that starts the raft route. With exactly 1 player, that player deposits everything, works every stage alone, eating when their energy runs out, and launches it.

#### Scenario: Two players feed the raft
- GIVEN a 2-player run and the sandbar's raft site
- WHEN one player deposits 6 driftwood and 1 tube and the other 1 tube and 3 rope
- THEN the site holds 6, 2 and 3, and both peers show the same progress

#### Scenario: Solo raft
- **GIVEN** a 1-player run, offline, with a player at energy 100 holding 6 driftwood, 2 inner tubes, 3 rope, 2 coconuts and a knife
- **WHEN** they deposit everything and hold interact on the site until their energy runs out
- **THEN** the site's progress is 100 of 120 s, in the fourth stage, and their energy is 0
- **AND WHEN** they eat both coconuts, hold the site for 20 s more and launch the raft at night
- **THEN** the raft route starts for that player alone

#### Scenario: One builds while the other gathers
- **GIVEN** a 2-player run at the sandbar's raft site, the host's player holding 2 inner tubes and 1 rope and the client's player 6 driftwood and 2 rope at the far end of the island
- **WHEN** the host's player deposits and holds the site for 30 s while the client's player walks back, deposits and holds with them
- **THEN** both peers show the first stage done and the second under way

### Requirement: Starting a route
A player SHALL ask to start a route by an intent that names only the route. Only the host acts on it, for the sending peer's own player, alive, standing, still on the island and in reach of the starter. The host checks that the route is offered and discovered, that its requirements hold and that no patrol boat sees the launch (guardacostas-stealth "Launch in view"), picks the riders and emits `route_started` with the riders' peer ids. A refused request changes nothing; a seen one is a spot. With exactly 1 player the solo player is the host and takes the same path.

#### Scenario: Client asks, host picks
- GIVEN a 2-player session with a built raft and both players beside it at night, out of every searchlight
- WHEN the client sends a start request for `raft`
- THEN the host starts it for both players; a request naming a route that is not offered or not discovered starts nothing

#### Scenario: Solo launch seen by day
- **GIVEN** a 1-player run, offline, on the sandbar at 14:00 in calm weather with a built raft and its patrol boat out
- **WHEN** the player holds interact on the raft for 1 s
- **THEN** the route does not start, the raft stays on the beach and the patrol boat raises an alert on the player

## ADDED Requirements

### Requirement: Raft stages
The raft recipe SHALL be built in four stages, in this order: "Amarrar las cámaras" (2 inner tubes, 1 rope, 30 s), "Armar el piso" (4 driftwood, 1 rope, 30 s), "Amarrar la baranda" (2 driftwood, 1 rope, 30 s) and "Apretar los nudos" (no inputs, 30 s). A Mecánico works each stage at 2×. The stages are data on the recipe. With exactly 1 player, that player works all four. (Changes the 60 s base work of "Sandbar routes as data".)

#### Scenario: The raft's stages from data
- **GIVEN** the content catalog
- **WHEN** it loads `recipes/raft.tres`
- **THEN** the recipe lists the four stages with those names, inputs and times, their inputs add up to 6 driftwood, 2 inner tubes and 3 rope, their times to 120 s, and the content check reports no errors

#### Scenario: A solo Mecánico
- **GIVEN** a 1-player run, offline, whose only player is a Mecánico at the raft site with every input in
- **WHEN** they hold interact on it for 60 s
- **THEN** the raft is built and their energy fell by 60
