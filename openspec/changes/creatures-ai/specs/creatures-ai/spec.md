# Spec Delta

## ADDED Requirements

### Requirement: First creatures
The reef shark (`reef_shark`), the land crab (`land_crab`) and the seagull (`seagull`) SHALL be `.tres` files in `game/resources/creatures/` that pass the content check, each naming its behavior (`patrol_circle_strike`, `night_thief`, `swoop_steal`) and domain. A creature SHALL read everything it does from its file, so a new file with an existing behavior spawns with no script edited. The same files serve exactly 1 player and 4.

#### Scenario: The three creatures load
- GIVEN the content catalog
- WHEN `reef_shark`, `land_crab` and `seagull` are read
- THEN each has a Spanish name, health, speed, domain, spawn rules and its behavior, and the content check reports no problem

#### Scenario: A new shark from data only
- GIVEN a valid creature file `tiburon_prueba` with behavior `patrol_circle_strike` added to a creatures folder
- WHEN a 1-player sandbar spawns creatures from that folder
- THEN `tiburon_prueba` is placed in deep water and runs the shark state machine, and no script was changed

### Requirement: Reef shark patrol, circle and strike
A reef shark SHALL patrol water at least 2 tiles from land, investigate a swimmer within 8 tiles, circle them for 6–10 s and then strike only if they are bleeding or below 20 energy: 25 damage and bleeding, a 4 s retreat, then it circles again. Otherwise it leaves and ignores that swimmer for 20 s. It never enters land or water within 1 tile of land, so the shallows by the shore are out of reach. A lone swimmer is handled the same way and escapes alone by reaching the shallows or land.

#### Scenario: Solo clean swimmer
- GIVEN a 1-player sandbar whose player swims clean at energy 100 in deep water 4 tiles from a reef shark
- WHEN 15 s pass
- THEN the shark circled, struck nothing and went back to patrol, and the player's health is unchanged

#### Scenario: Solo bleeding swimmer
- GIVEN a 1-player sandbar whose player at 100 health swims bleeding and still in deep water next to a reef shark, circle time 6 s
- WHEN 6.1 s pass
- THEN the player was struck once, health is 75 and still bleeding, and the shark is retreating

#### Scenario: Energy 20 exactly is not struck
- GIVEN a 1-player sandbar whose player swims clean at energy 20 next to a reef shark
- WHEN the circle ends
- THEN the player's health is unchanged, and at energy 19 it would be 75

#### Scenario: Solo tired swimmer escapes to the shallows
- GIVEN a 1-player sandbar whose player at energy 15 swims 6 tiles from the shore line while a reef shark starts circling
- WHEN the player swims straight to shallows next to land at 3 tiles/s
- THEN they reach it before the circle ends, are never struck, and the shark never enters a cell within 1 tile of land

### Requirement: Land crab night theft
Land crabs SHALL spawn at night, 6 per beach (4-connected, 8+ beach cells) times the party scaling, and leave at dawn. Each takes 1 food item per minute from the nearest food pick-up on the ground. A crab never enters within 5 tiles of a lit fire. A fire lit at night start halves the crabs spawned and one lit later sends half the living crabs away (rounded down). A crab pinches a player who stays next to it for 5 damage. A lone player guards a stash alone with one fire.

#### Scenario: Solo night on the sandbar
- GIVEN a 1-player sandbar at dusk with no fire
- WHEN night begins
- THEN 6 land crabs stand on beach cells; none existed during the day, and none is left after dawn begins

#### Scenario: Solo fire halves the crabs
- GIVEN a 1-player sandbar at dusk with one lit fire
- WHEN night begins
- THEN 3 land crabs spawn, and none stands within 5 tiles of the fire

#### Scenario: Party scaling
- GIVEN a sandbar at dusk with 1, 2, 3 and 4 players in turn
- WHEN night begins
- THEN 6, 7, 8 and 10 land crabs spawn

#### Scenario: Crab steals from a stash
- GIVEN a 1-player night with a pick-up of 3 coconuts on the beach and one crab beside it, no fire
- WHEN 60 s pass
- THEN the pick-up holds 2 coconuts and the crab is fleeing with 1

#### Scenario: A stash by the fire is safe
- GIVEN the same pick-up 3 tiles from a lit fire
- WHEN 120 s of night pass
- THEN the pick-up still holds 3 coconuts

### Requirement: Seagull swoop and steal
Seagulls SHALL nest in two palms, 2 per palm, from dawn to dusk and perch at night. A gull swoops on food within 8 tiles of its nest (on the ground, or held: the first FOOD slot of a player on land, `Inventory.held_food()`), takes 1 item and flies off for 30 s before returning. A player within 2 tiles who interacts shoos it for 30 s. A gull never takes other slots and never damages anyone. A lone player keeps food by covering it, keeping it from the nests or shooing.

#### Scenario: Solo gull takes one held food item
- GIVEN a 1-player sandbar by day whose player holds 2 coconuts, 4 tiles from a nest palm
- WHEN a gull swoops
- THEN the player holds 1 coconut and the gull flies off for 30 s, and is perched again when they are up

#### Scenario: Solo shoo
- GIVEN a 1-player sandbar by day whose player stands 1 tile from a gull about to swoop
- WHEN the player shoos it
- THEN it flees for 30 s and nothing is taken

### Requirement: Creature navigation
Each island SHALL build two `AStarGrid2D`s from its terrain: a land grid (beach 1, dune 1.5, mangrove 3, shallows 2, deep water solid) and a water grid (deep and shallow water only, cells closer to land than the creature's shore margin solid). A creature moves only on the grid of its domain, air creatures ignore terrain, and each creature recomputes its path at most every 0.5 s. The same holds with exactly 1 player.

#### Scenario: Shark stays in the water
- GIVEN a 1-player sandbar whose player stands on the beach and a reef shark that saw them swim
- WHEN 60 s pass
- THEN every cell the shark occupied was deep or shallow water at least 2 tiles from land

### Requirement: Offshore reef shark
The sandbar SHALL have one reef shark offshore at the start (docs/ISLANDS.md §1 "Threats"), in deep or shallow water at least 2 tiles from land. Setting that rule's spawn chance to 0 SHALL turn it off with no script change. With exactly 1 player the shark is the same single shark.

#### Scenario: Solo sandbar has one shark
- GIVEN a 1-player sandbar
- WHEN the island is set up
- THEN one reef shark is in water at least 2 tiles from land, and none is on land

### Requirement: Host-run creatures
Creatures SHALL live on the host: it spawns them through the session's entity spawner, runs their state machines and syncs position, facing and state to clients, who draw them and never move, damage or steal with them. A shoo is a request the host checks for reach. A solo player is their own host and nothing goes over a network.

#### Scenario: A client cannot move a creature
- GIVEN a host and one client with a land crab spawned on both
- WHEN the client runs its own creature tick
- THEN the crab on the client stays where the host put it

#### Scenario: A shoo is checked for reach
- GIVEN a host and one client, a gull on both and the client's player 6 tiles away
- WHEN the client sends a shoo, and later again from 1 tile
- THEN the gull does not flee the first time and flees the second

#### Scenario: Late joiner sees the creatures
- GIVEN a host with 6 crabs at night
- WHEN a client joins
- THEN the client has 6 crabs at the host's positions

### Requirement: Crossing reef shark
The crossing's shark pass SHALL be resolved by a reef shark from `reef_shark.tres` through the `CrossingThreats` hook: it appears beside the vessel, applies the crossing's choice (a swimmer who meets its strike conditions, else an intact raft, else nobody) through `bite_swimmer` and `hit_vessel`, then circles for its circle time and leaves. The crossing's numbers and "Shark pass event" scenarios are unchanged. With exactly 1 player, the lone player or their raft is the only target.

#### Scenario: Solo crossing shark
- GIVEN a 1-player raft crossing whose player swims at energy 15 beside an intact raft
- WHEN the shark pass comes
- THEN a reef shark creature appears, the player loses 25 health and bleeds, the raft keeps its integrity, and the shark is gone after its circle time
