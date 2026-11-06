## ADDED Requirements

### Requirement: Handmade sandbar
The first island of every run SHALL be the handmade sandbar (*el banco de arena*, `docs/ISLANDS.md` §1), read from an island layout data file, not generated: a crescent of beach, dune and sea-grape brush in shallows and deep water, larger than the 640×360 view, with land 10–20% of its cells and no land cell more than 6 tiles from water. Moving or adding a palm, a pick-up or a spawn point SHALL need only a data change.

#### Scenario: The sandbar is data
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it is larger than 640×360 px, 10–20% of its cells are land, and no land cell is more than 6 tiles from water

### Requirement: Sandbar contents
The sandbar SHALL hold the ruined hut, a palm grove, the flotsam line and tide pools (always there until a tide exists). Every pick-up, palm, tide pool and the workbench SHALL be reachable on foot or wading from every spawn point, so exactly 1 player, offline, can reach and take all of it alone.

#### Scenario: The sandbar loads
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it has 6 palms holding 10 coconuts in all (`docs/ISLANDS.md` "Resource rules"), one workbench, the hut's cells are the only shaded cells, and its pick-ups are 1 tarp, 2 driftwood and 1 knife in the hut, 2 inner tubes, 3 plastic jugs and 1 rope on the flotsam line, 6 driftwood on the beach and 3 dry grass on the dune

#### Scenario: Everything is in reach of a lone player
- GIVEN the built sandbar and its solo spawn point
- WHEN paths over land and shallows are checked from that point
- THEN every palm, pick-up, tide pool and the workbench can be reached, and the same holds from every co-op spawn point

### Requirement: Palm climbing
A player SHALL gather a coconut by holding interact on a palm that still has one for the timed-interaction hold (2 s): the host puts 1 coconut in their inventory and takes 5 energy from them. A palm with no coconut left, or a player whose inventory cannot take the coconut, gains nothing and pays nothing. Climbing needs no teammate; exactly 1 player can take all 10 coconuts alone.

#### Scenario: A solo player climbs every palm
- GIVEN one offline player at energy 100 on the sandbar with room for 10 coconuts
- WHEN they climb the 6 palms until none has a coconut left
- THEN they hold 10 coconuts, their energy is 50 and climbing again gives nothing and costs nothing

#### Scenario: Opening the first coconut with the hut's knife
- GIVEN one offline player who climbed a palm and picked up the hut's knife
- WHEN they drink the coconut
- THEN thirst rises 15, hunger 5, energy 10, the coconut is gone and the knife has 39 uses left

### Requirement: Flotsam refresh
When a squall ends on the sandbar the host SHALL put back every flotsam-line pick-up (inner tubes, plastic jugs, rope) and every beach driftwood pick-up that was taken, at its own spot; pick-ups still lying there are not doubled, and hut loot never comes back. A client sees the refreshed pick-ups. With exactly 1 player, offline, the same refresh happens.

#### Scenario: A solo player's flotsam comes back after a squall
- GIVEN one offline player who picked up both inner tubes and one plastic jug, and the hut's knife
- WHEN a squall starts and then ends
- THEN the flotsam line again holds 2 inner tubes, 3 plastic jugs and 1 rope, and the knife is not back in the hut

#### Scenario: No refresh while the squall falls
- GIVEN a taken inner tube
- WHEN a squall starts and has not ended
- THEN the tube is not back

### Requirement: Scattered landing
On the sandbar each player SHALL spawn at a layout spawn point on the sand. In co-op the spawn points in use are 10–20 tiles apart from each other (`docs/ISLANDS.md` §1), so the party has to find each other first. Exactly 1 player, offline, spawns at the solo spawn point near the hut, with no one to look for.

#### Scenario: Four players land apart
- GIVEN a co-op run on the sandbar
- WHEN 2, 3 or 4 players spawn
- THEN every pair of them is at least 10 and at most 20 tiles apart, each on beach or dune

#### Scenario: A solo landing
- GIVEN a solo run
- WHEN the player spawns
- THEN they stand on the solo spawn point, on sand, within 4 tiles of the hut

### Requirement: The run starts on the sandbar
A run started from the game shell (solo, hosted, or a client joining) SHALL start on the handmade sandbar; the camera stays inside the island. The host places the island's pick-ups and refreshes them; a client sees the host's pick-ups appear and vanish and never places or removes one itself. A client's pick-up on the sandbar is applied by the host. With exactly 1 player, offline, the run starts on the sandbar with every pick-up placed and no network port open.

#### Scenario: Solo run on the sandbar
- GIVEN the title screen
- WHEN the one player starts a solo run
- THEN the island is the sandbar, the player is at its solo spawn point, and the hut's 4 pick-ups, the flotsam line's 6 pick-ups and the 6 palms are there

#### Scenario: Hosted run on the sandbar
- GIVEN a host and a client in the lobby
- WHEN the host begins the run
- THEN both are on the sandbar at co-op spawn points 10–20 tiles apart, and the client sees the same pick-ups as the host

#### Scenario: A client's pick-up is applied by the host
- GIVEN a hosted sandbar run and a client next to an inner tube
- WHEN the client interacts with it
- THEN the host puts the tube in the client's inventory, the client's inventory shows it, and the tube is gone on both peers
