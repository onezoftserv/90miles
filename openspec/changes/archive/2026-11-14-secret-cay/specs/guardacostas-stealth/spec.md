# Spec Delta

## MODIFIED Requirements

### Requirement: Previous island after capture
When a capture sends the party back, the previous island SHALL be regenerated from the run seed and set up again for the living, connected players at that moment (Resource spawns, Escape routes), and the party SHALL restart on its landing beach. On island 1, which has no previous island, the party SHALL restart island 1, regenerated from the run seed the same way, with the same inventory rule (minus fire sources, keepsakes kept). The secret cay (secret-cay) is never the previous island: a party captured on the island it reached after the cay restarts the island it left for the cay. A regenerated island never places a secret piece the run has already spawned (the run's ledger of spawned pieces), so a capture never makes a second map or compass; the later work that places pieces in real runs tests this. The same holds with 1 player. (Changes docs/GAME_DESIGN.md §9 "Guardacostas and stealth" for the cay and the pieces.)

#### Scenario: Previous island is fresh
- GIVEN a 1-player run whose player used all the driftwood on island 2 for a raft and was then captured on island 3 with persuasion failing
- WHEN the player restarts island 2
- THEN island 2 has the terrain, POIs and resources it had on first arrival, from the same run seed

#### Scenario: Caught on the sandbar
- GIVEN a 1-player run on island 1 whose player carries a knife, 3 rope, a lighter and the Foto de la familia keepsake, with morale 40
- WHEN a shore squad captures the player and persuasion fails
- THEN island 1 is regenerated from the run seed and the player lands on its beach with the knife, the 3 rope and the Foto, without the lighter

#### Scenario: Caught after the detour
- GIVEN a 1-player run that left island 4 for the secret cay, went on to island 5 and was captured there with persuasion failing
- WHEN the player restarts
- THEN they restart island 4, regenerated from the run seed, not the cay

#### Scenario: A taken piece is not placed again
- **GIVEN** a 1-player run that took the map on island 3 and was captured on island 4 with persuasion failing
- **WHEN** the player restarts island 3, regenerated from the run seed
- **THEN** island 3 holds no map, and the player still carries the one they took
