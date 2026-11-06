# Spec Delta

## MODIFIED Requirements

### Requirement: Behavior state machines
Behaviors SHALL be implemented as reusable state machines in `game/scripts/ai/`: `patrol_circle_strike` (sharks), `hidden_ambush` (eels, crocodile), `pack_swarm` (barracuda), `drift_trap` (man o' war), `night_thief` (crabs), `swoop_steal` (gulls, frigatebird), `gas_cloud` (mosquitoes), `grab_drag` (crocodile), `static_hazard` (ants, manchineel), `ambient` (sperm whale, pelican, songbird, booby), `perch_ride` (the final gull).

#### Scenario: Shared ambush behavior
- GIVEN an eel and a crocodile
- WHEN they are spawned
- THEN both use the same `hidden_ambush` state machine from `game/scripts/ai/`

#### Scenario: Shared ambient behavior
- GIVEN a songbird and a booby, each with `ambient` and no other script
- WHEN a solo player's mid crossing spawns both
- THEN both use the same `ambient` state machine and each gives its +5 morale once a day to that player

## ADDED Requirements

### Requirement: Perch ride
The `perch_ride` behavior SHALL perch a creature on one player's head for a whole crossing and turn with the player. Interact makes it hop to another head (in solo it circles and lands again, 5 s); if its player falls in it waits overhead. Every 60 s it has a 50% chance to take one held food item (never inventory) without leaving. It never changes speed, drift, threats or the outcome.

#### Scenario: Solo final crossing
- GIVEN a 1-player run on the final crossing, the player holding 2 food items, and the galleguito perched
- WHEN 120 s pass with the dice always succeeding
- THEN it took 2 held items at most (one per 60 s), stayed perched, and speed, drift and threats were unchanged

#### Scenario: Co-op pick
- GIVEN a party of 3 where one player holds 3 food items and the others hold 1 each
- WHEN the galleguito lands
- THEN the host picks the player with 3, breaking ties with the run seed, and a client only sends the shoo

### Requirement: Final gull
The `galleguito` SHALL spawn on every final crossing once per run (a CROSSING rule on the final chain family at chance 1.0, `max_per_run` 1), with no set piece added. Each player who sees it land gets +10 morale once per run; solo and co-op get the same per-player amount. It sets `galleguito_a_bordo` once. A carried *Pluma de galleguito* stops it, and every island gull, from stealing from the holder.

#### Scenario: Solo final crossing
- GIVEN a 1-player run at morale 50 that pushes off the final island
- WHEN the crossing loads
- THEN one galleguito lands on the player, morale is 60, `galleguito_a_bordo` is set, and the island's set-piece roll was not affected

#### Scenario: Feather holder
- GIVEN a 1-player run whose player carries the *Pluma de galleguito* and holds 2 food items
- WHEN a gull swoops on the island or the galleguito's 60 s theft roll comes up
- THEN nothing is taken

### Requirement: Crossing spawn rules
The crossing threat roll SHALL place every creature whose CROSSING spawn rule matches the crossing and has chance 1.0, respecting `max_per_run`, even when the crossing has a cap on rolled threats.

#### Scenario: Chance 1.0 beats the cap
- GIVEN a final crossing whose roll already placed its capped number of rolled threats
- WHEN the galleguito's rule (chance 1.0) is checked
- THEN the galleguito is still placed, with 1 player or 4

### Requirement: Frigatebird
The `rabihorcado` SHALL use `swoop_steal` on the fishing catch at 20%, flee after one steal, stay airborne and never be catchable, and replace the pelican where it spawns (reef and rock cays, 40%) so two catch thieves never stack.

#### Scenario: Solo fisher on a reef cay
- GIVEN a 1-player run fishing on a reef cay where a rabihorcado spawned in place of the pelican
- WHEN the player reels in 10 catches with the dice at 20%
- THEN 2 are taken, each theft ends the bird's visit, and no pelican steals
