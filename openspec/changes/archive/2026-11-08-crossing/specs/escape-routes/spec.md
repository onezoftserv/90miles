# Spec Delta

## MODIFIED Requirements

### Requirement: Leaving before the crossing exists
Riders of a started route SHALL leave the island into the crossing (the crossing capability). Until arrival on the next island exists, riders who finish the crossing leave play (removed from play on every peer, meters stopped), and the run SHALL end with the summary once every player has left or died, at least one having left; each entry names the route its player left by. With exactly 1 player, the run ends when that player's crossing ends or they die.

#### Scenario: Solo ends the island by raft
- GIVEN a 1-player run with a built raft
- WHEN the player launches it and the crossing ends
- THEN the player has left the island and the summary shows them as having left by "Balsa"
