## MODIFIED Requirements

### Requirement: Handmade sandbar
The first island of every run SHALL be the handmade sandbar (*el banco de arena*, `docs/ISLANDS.md` §1), read from an island layout data file, not generated: an open crescent of beach, dune and sea-grape brush opening east, in shallows and deep water, larger than the 640×360 view, with 940–1,100 land cells, land 10–20% of its cells and no land cell more than 6 tiles from water. Its arc is about 90 tiles along the middle, a walk of about 22–25 s for one player at the walking speed (4 tiles/s). Moving or adding a palm, a pick-up or a spawn point SHALL need only a data change.

#### Scenario: The sandbar is data
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it is larger than 640×360 px, it has 940–1,100 land cells, 10–20% of its cells are land, and no land cell is more than 6 tiles from water

### Requirement: Sandbar contents
The sandbar SHALL hold the ruined hut, a palm grove, the flotsam line and tide pools (always there until a tide exists), spread along the crescent: the hut on the north horn, the palm grove mid-arc (every palm at least 20 tiles from the hut), the tide pools on the south horn, the flotsam line on the inside curve and the raft build site on the beach where the flotsam lands. Every pick-up, palm, tide pool, the workbench and the raft build site SHALL be reachable on foot or wading from every spawn point, so exactly 1 player, offline, can reach and take all of it alone. The island holds 3 rope in all (1 on the flotsam line, 2 in the hut) so a player can build the raft on day 1.

#### Scenario: The sandbar loads
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it has 6 palms holding 10 coconuts in all (`docs/ISLANDS.md` "Resource rules"), one workbench, the hut's cells are the only shaded cells, and its pick-ups are 1 tarp, 2 driftwood, 1 knife and 2 rope in the hut, 2 inner tubes, 3 plastic jugs and 1 rope on the flotsam line, 6 driftwood on the beach and 3 dry grass on the dune

#### Scenario: Everything is in reach of a lone player
- GIVEN the built sandbar and its solo spawn point
- WHEN paths over land and shallows are checked from that point
- THEN every palm, pick-up, tide pool, the workbench and the raft build site can be reached, and the same holds from every co-op spawn point

#### Scenario: A lone player's walks
- GIVEN one offline player at the solo spawn point, walking at 4 tiles/s
- WHEN the shortest walk over land and shallows is measured
- THEN every palm is 6–11 s away, the raft build site 4.5–8 s and every tide pool 13–17.5 s, and the far horn is 15 s or more

### Requirement: Scattered landing
On the sandbar each player SHALL spawn at a layout spawn point on the sand. In co-op each spawn point in use is 20–30 tiles from the next one in join order (1 to 2, 2 to 3, 3 to 4; `docs/ISLANDS.md` §1, "Scattered landing"), spread along the arc, so the party has to find each other first; the first and the last may be much farther apart. Exactly 1 player, offline, spawns at the solo spawn point near the hut, with no one to look for.

#### Scenario: Four players land apart
- GIVEN a co-op run on the sandbar
- WHEN 2, 3 or 4 players spawn
- THEN each is at least 20 and at most 30 tiles from the next in join order, each on beach or dune

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
- THEN both are on the sandbar at co-op spawn points 20–30 tiles from the next in join order, and the client sees the same pick-ups as the host

#### Scenario: A client's pick-up is applied by the host
- GIVEN a hosted sandbar run and a client next to an inner tube
- WHEN the client interacts with it
- THEN the host puts the tube in the client's inventory, the client's inventory shows it, and the tube is gone on both peers
