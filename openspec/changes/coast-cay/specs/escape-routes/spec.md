## MODIFIED Requirements

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
