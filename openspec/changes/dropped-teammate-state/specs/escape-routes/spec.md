## MODIFIED Requirements

### Requirement: Split parties
When a route takes a subset of the party, the island SHALL remain active for the others; the next island waits until all living players arrive or die. Because a session runs one live level (coop-networking, decided 2026-11-05), riders whose crossing has ended wait on the next island's shore instead of playing it: they are out of play (hidden, not hurt by anything, their meters frozen), they do not count as company or as a teammate who could revive someone, and they see who is still playing, a disconnected one marked as such. When no living player is left on the island (each has died, been removed or left by a route) and no crossing is still running, the host SHALL load the next island for every peer: the waiting and arriving players land on its landing cells, within 5 tiles of each other, with the health and energy they had, and can survive there. A dropped player who is still on the island keeps it open until removed, but once such dropped players are all that keep waiting riders from landing, each is removed within 30 s (coop-networking "Disconnect handling"); with no rider waiting, the full 90 s hold. A dropped rider still in a crossing holds the load until that crossing ends. A removed player counts as dead; a waiting rider who drops and rejoins stays a waiting rider. A client never loads an island on its own. With exactly 1 player there is no wait: the next island loads as soon as the player's crossing ends, and if they die in the crossing the run ends as a death.

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
- WHEN the second player's time runs out, 30 s after the drop, and they are removed
- THEN the coast cay loads for the first player alone, and the removed player is listed as dead

#### Scenario: A dropped player back within the short hold plays on
- GIVEN a 2-player run where the first player's crossing has ended and the second drops on the sandbar
- WHEN the second player rejoins with the same identity 20 s after the drop
- THEN they take their body back on the sandbar and play on, the sandbar stays the live island, and the first player still waits

#### Scenario: A dropped rider in a crossing holds the load
- GIVEN a 2-player run where the first player's crossing has ended and the second is in a crossing
- WHEN the second player's client drops before that crossing ends
- THEN the sandbar stays the live island until the crossing ends, and then the coast cay loads with both players on it

#### Scenario: Nobody waiting keeps the full hold
- GIVEN a 2-player run on the sandbar where the host's player is dead and nobody has left by a route
- WHEN the client drops
- THEN the run stays open and the client's player is removed only after the full 90 s

#### Scenario: On the last island the short hold ends the run
- GIVEN a 2-player run on the coast cay, which names no next island, where the first player's crossing has ended and the second drops there
- WHEN 30 s pass without the second player rejoining
- THEN the second player is removed and counts as dead, and the run is over

#### Scenario: The waiting line marks a dropped teammate
- GIVEN a 2-player run where the first player's crossing has ended and the second, Papo, drops on the sandbar
- WHEN the first player looks at their waiting line
- THEN it reads "En la orilla. Esperando a: Papo (desconectado)"

#### Scenario: A solo player never waits
- GIVEN a 1-player run, offline, whose crossing ends
- WHEN the crossing ends
- THEN the coast cay loads at once for the one player, with no wait and no other player needed
