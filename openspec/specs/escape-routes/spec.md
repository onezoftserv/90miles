# escape-routes

## Purpose
The ways off an island. Each is a POI with requirements, a capacity, and a crossing profile.

## Requirements

### Requirement: Route resource
Each route SHALL be a `.tres` with: id, display name, requirements (items, quest flags, weather, skill), capacity (int or "all"), risk profile for the crossing, and the NPC or object that starts it.

#### Scenario: Route from data
- GIVEN a route `.tres` whose requirements are met
- WHEN a player uses the NPC or object that starts it
- THEN the route starts with the capacity in its resource and its crossing uses the resource's risk profile

### Requirement: Routes
The game SHALL implement these routes: raft, repair-wreck, turtle, binoculars-swim, tarp-sail, dolphins, signal-boat, gulf-stream, with the requirements in `docs/GAME_DESIGN.md` §7.

#### Scenario: Turtle capacity
- GIVEN a party of 4 and a freed, fed turtle
- WHEN two players board her
- THEN the route starts for those two only; the other two remain on the island with the other routes available

### Requirement: Shared crafting
A raft SHALL be a shared build site: any player can deposit materials into it; progress is visible to all; building requires at least one player working. A Mecánico builds at 2×.

#### Scenario: Nobody working
- GIVEN a raft build site with materials deposited
- WHEN no player is working on it
- THEN build progress does not advance

### Requirement: Weather gating
Tarp-sail SHALL require trade wind; binoculars-swim SHALL require clear weather and energy ≥ 100 for each swimmer; signal-boat SHALL only succeed in the first hour after dusk or the last before dawn.

#### Scenario: Tarp-sail without trade wind
- GIVEN a party with everything else the tarp-sail route needs
- WHEN the weather is calm
- THEN the route cannot start

### Requirement: Split parties
When a route takes a subset of the party, the island SHALL remain active for the others; the next island waits until all living players arrive or die. Because a session runs one live level (coop-networking, decided 2026-11-05), riders whose crossing has ended wait on the next island's shore instead of playing it: they are out of play (hidden, not hurt by anything, their meters frozen), they do not count as company or as a teammate who could revive someone, and they see who is still playing. When no living player is left on the island (each has died, been removed or left by a route) and no crossing is still running, the host SHALL load the next island for every peer: the waiting and arriving players land on its landing cells, within 5 tiles of each other, with the health and energy they had, and can survive there. A dropped player who is still on the island keeps it open until removed; a removed player counts as dead; a waiting rider who drops and rejoins stays a waiting rider. A client never loads an island on its own. With exactly 1 player there is no wait: the next island loads as soon as the player's crossing ends, and if they die in the crossing the run ends as a death.

#### Scenario: Half the party leaves
- GIVEN two of four players leave by a route
- WHEN those two arrive on the next island
- THEN they wait on its shore out of play, the previous island stays active for the other two, and the next island loads for everyone when those two arrive or die, with the waiting two on its beach

#### Scenario: The one who stayed dies
- GIVEN a 2-player run where the first player's crossing has ended and the second is still on the sandbar
- WHEN the second player dies
- THEN the coast cay loads on both peers and the first player stands on its first landing cell with the health and energy their crossing left them

#### Scenario: A crossing still running holds the load
- GIVEN a 2-player run where the first player's crossing has ended and the second is still on the sandbar or in a crossing
- WHEN the host checks the party
- THEN the sandbar stays the live island on both peers, and the coast cay loads when the second player's crossing ends, or they die or are removed

#### Scenario: A waiting rider drops and rejoins
- GIVEN a 2-player run where the second player's crossing has ended and they drop
- WHEN they rejoin with the same identity before the first player leaves or dies
- THEN they are still a waiting rider under their new peer, on the host and on their own screen, and they land with the rest when the coast cay loads

#### Scenario: A removed player counts as dead
- GIVEN a 2-player run where the first player's crossing has ended and the second drops on the sandbar
- WHEN the second player's 90 s run out and they are removed
- THEN the coast cay loads for the first player alone, and the removed player is listed as dead

#### Scenario: A solo player never waits
- GIVEN a 1-player run, offline, whose crossing ends
- WHEN the crossing ends
- THEN the coast cay loads at once for the one player, with no wait and no other player needed

### Requirement: Route discovery
Routes SHALL be hidden until discovered (seen, told by an NPC, or revealed by charts/keepsake). Discovered routes show on the island map with their requirements.

#### Scenario: Told by an NPC
- GIVEN a route on the island that has not been discovered
- WHEN an NPC tells the party about it
- THEN the route shows on the island map with its requirements

### Requirement: Sandbar routes as data
The raft and binoculars-and-swim SHALL be `RouteData` files `game/resources/routes/raft.tres` and `binoculars_swim.tres`. The raft is started by its built vessel (recipe `raft`: 6 driftwood, 2 inner tubes, 3 rope, a shared build site, 60 s base work), takes everyone within the boarding radius and is always known. Binoculars-and-swim is started by using `binoculars`. A new route is a new `.tres`; no script changes. Both files pass the content check.

#### Scenario: Routes load from data
- GIVEN the content catalog
- WHEN it loads `routes/`
- THEN `raft` (capacity all, starter recipe `raft`, discovered from the start) and `binoculars_swim` (capacity per swimmer, starter item `binoculars`) load with Spanish and English names and the content check reports no errors

### Requirement: Raft build site
Each sandbar SHALL have one raft build site at its marked beach cell, on every peer at the same path. Any player deposits driftwood, inner tubes and rope from their own inventory up to 6, 2 and 3; progress is shared and shown to every player; work advances only while at least one player works it and every input is in. When it completes it becomes a beached raft that starts the raft route. With exactly 1 player, that player deposits everything, works it alone and launches it.

#### Scenario: Two players feed the raft
- GIVEN a 2-player run and the sandbar's raft site
- WHEN one player deposits 6 driftwood and 1 tube and the other 1 tube and 3 rope
- THEN the site holds 6, 2 and 3, and both peers show the same progress

#### Scenario: Solo raft
- GIVEN a 1-player run, offline, with a player holding 6 driftwood, 2 inner tubes and 3 rope at energy 100
- WHEN they deposit everything, work the site for 60 s and launch the raft
- THEN the raft route starts for that player alone

### Requirement: Swimmers' condition
Binoculars-and-swim SHALL start only while the weather is clear, when the starter carries binoculars, and only for swimmers whose energy is 100 and who are not bleeding; the binoculars are not used up. With exactly 1 player, that player is the only swimmer and needs all of it. (Implements docs/GAME_DESIGN.md §7 "Binoculars and swim"; "bandaged cuts" is read as "not bleeding".)

#### Scenario: Solo swimmer refused, then accepted
- GIVEN a 1-player run, a player carrying binoculars
- WHEN they use them in a squall, or in calm at energy 99, or in calm at energy 100 while bleeding
- THEN the route does not start; in calm at energy 100 and not bleeding it starts for that player and the binoculars stay in the inventory

### Requirement: Starting a route
A player SHALL ask to start a route by an intent that names only the route. Only the host acts on it, for the sending peer's own player, alive, standing, still on the island and in reach of the starter. The host checks that the route is offered and discovered and that its requirements hold, picks the riders and emits `route_started` with the riders' peer ids. A refused request changes nothing. With exactly 1 player the solo player is the host and takes the same path.

#### Scenario: Client asks, host picks
- GIVEN a 2-player session with a built raft and both players beside it
- WHEN the client sends a start request for `raft`
- THEN the host starts it for both players; a request naming a route that is not offered or not discovered starts nothing

### Requirement: Riders by capacity
The host SHALL pick riders among living, standing players on the island within the boarding radius (5 tiles, provisional) of the starter: `ALL` takes all of them, `PER_SWIMMER` those who pass every rider requirement, `FIXED` the sender and then the nearest. The sender must ride or nothing starts. Players not picked stay, keep every route the island offers and get a fresh raft site if a raft left. With exactly 1 player, the rider is that player.

#### Scenario: One stays behind
- GIVEN a 2-player run in calm weather, both carrying binoculars and beside each other, one at energy 100 and one at energy 99
- WHEN the first uses the binoculars
- THEN only the first leaves; the second stays on the island, can still build and launch the raft, and can swim once at energy 100

### Requirement: Leaving before the crossing exists
Riders of a started route SHALL leave the island into the crossing (the crossing capability). Until arrival on the next island exists, riders who finish the crossing leave play (removed from play on every peer, meters stopped), and the run SHALL end with the summary once every player has left or died, at least one having left; each entry names the route its player left by. With exactly 1 player, the run ends when that player's crossing ends or they die.

#### Scenario: Solo ends the island by raft
- GIVEN a 1-player run with a built raft
- WHEN the player launches it and the crossing ends
- THEN the player has left the island and the summary shows them as having left by "Balsa"

### Requirement: Sandbar route discovery
The raft SHALL be known from the start. Binoculars-and-swim SHALL become discovered the first time the weather is clear while any player is on the island (the next island shows on the horizon) and stays discovered. Undiscovered routes cannot be started. With exactly 1 player that player's presence is enough.

#### Scenario: Squall start
- GIVEN a 1-player run that starts in a squall
- WHEN the squall ends and the weather turns calm
- THEN binoculars-and-swim becomes discovered; before that a start request for it is refused

### Requirement: Departures reach joiners
A peer that joins the run, or rejoins and takes back its body, SHALL learn from the host which players already left by a route and by which one, under each player's current peer. Learning it starts nothing. Riders whose crossing already ended stay out of play on the joiner's screen, as on the host's. With exactly 1 player, offline, nobody can join, and leaving by a route works as before.

#### Scenario: A late joiner learns who left
- **GIVEN** a 2-player run in which the client left by "Prismáticos y a nadar" and the host stayed on the island
- **WHEN** a third player joins
- **THEN** the third player's game has the client as having left by that route and the host as still on the island, and no crossing starts because of it

#### Scenario: Riders of an ended crossing stay out of play
- **GIVEN** a 2-player run whose client crossed by raft and whose crossing has ended, while the host stays on the island
- **WHEN** a third player joins
- **THEN** the third player does not see the client's body on the island

#### Scenario: A rejoined rider is still gone
- **GIVEN** a 2-player run whose client left by raft, and the client's crossing still under way
- **WHEN** the client drops and joins again from the same install
- **THEN** the client's game has them as having left by "Balsa" under their new peer, and the run does not end while their crossing runs

#### Scenario: Solo departure unchanged
- **GIVEN** a 1-player run, offline, with a built raft
- **WHEN** the player launches it
- **THEN** the player leaves the island by "Balsa" as before, and nothing is sent to anyone
