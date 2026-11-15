## ADDED Requirements

### Requirement: Finishing a takeover
When a join request takes back a player whose old connection the host still holds (Reclaiming a player), the host SHALL finish the takeover only after it has read every packet that arrived with that request. Until then the old connection still plays that player and nothing new is sent to it. The host then closes the old connection first, and the new one takes back the player. No packet from either connection logs an error on the host. Solo has nobody to take over.

#### Scenario: A second copy while the first still sends
- **GIVEN** Papo's game is connected in the run and still sends his moves every frame
- **WHEN** a second copy of his game, from the same install, joins
- **THEN** the host closes the first copy's connection, the second copy takes back the same body, and the host's log has no error

#### Scenario: A repeated join request during the takeover
- **GIVEN** Papo's game is connected and still sending
- **WHEN** a second copy of his game sends its join request twice before the host has finished taking over
- **THEN** the second request is ignored: the second copy takes back the body once and stays connected

#### Scenario: A second copy in the lobby
- **GIVEN** Papo's game is in the lobby and still connected
- **WHEN** a second copy of his game joins the lobby
- **THEN** the host closes the first copy's connection, the roster lists Papo once, under the second copy, and the host's log has no error

#### Scenario: Solo has nobody to take over
- **GIVEN** one player plays offline
- **WHEN** a join request reaches the session
- **THEN** it is ignored, nothing is taken over, and the player keeps their own body
