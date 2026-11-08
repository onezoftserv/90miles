# Spec Delta

## MODIFIED Requirements

### Requirement: Sandbar contents
The sandbar SHALL hold the ruined hut, a palm grove, the flotsam line and tide pools (always there until a tide exists). Every pick-up, palm, tide pool and the workbench SHALL be reachable on foot or wading from every spawn point, so exactly 1 player, offline, can reach and take all of it alone. The island holds 3 rope in all (1 on the flotsam line, 2 in the hut) so a player can build the raft on day 1.

#### Scenario: The sandbar loads
- GIVEN the sandbar layout file
- WHEN the island is built
- THEN it has 6 palms holding 10 coconuts in all (`docs/ISLANDS.md` "Resource rules"), one workbench, the hut's cells are the only shaded cells, and its pick-ups are 1 tarp, 2 driftwood, 1 knife and 2 rope in the hut, 2 inner tubes, 3 plastic jugs and 1 rope on the flotsam line, 6 driftwood on the beach and 3 dry grass on the dune

#### Scenario: Everything is in reach of a lone player
- GIVEN the built sandbar and its solo spawn point
- WHEN paths over land and shallows are checked from that point
- THEN every palm, pick-up, tide pool and the workbench can be reached, and the same holds from every co-op spawn point
