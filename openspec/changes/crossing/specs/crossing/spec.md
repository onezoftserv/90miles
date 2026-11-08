# Spec Delta

## ADDED Requirements

### Requirement: Entering the crossing
When a route starts, its riders SHALL leave the island into a crossing scene on every peer, with the vessel the route names: the launched raft at its current integrity, or, for a swimmers' route, the swimmers themselves with no integrity. Players who stay keep playing the island. The host owns the crossing and every client shows the same sea, vessel, events and riders. With exactly 1 player, launching a route takes that player into the crossing.

#### Scenario: Solo launches the raft
- GIVEN a 1-player run with a built raft at integrity 100
- WHEN the player launches it
- THEN the crossing scene holds that player aboard a raft at integrity 100, and the run has not ended

#### Scenario: One crosses, one stays
- GIVEN a 2-player run where only the first player uses the binoculars
- WHEN the route starts
- THEN on both peers the first player is in the crossing as a swimmer and the second is still on the island

### Requirement: Crossing length
A crossing SHALL last a length rolled on the host from the route's crossing duration (`duration_s`, within 60-120 s), and SHALL end when that time has passed whatever happened on the way. Sandbar routes are coast-band crossings: the raft lasts 60-90 s and binoculars-and-swim 60 s. The same holds with exactly 1 player.

#### Scenario: Crossing lasts its length
- GIVEN a raft route whose crossing duration is 75-75 s
- WHEN the crossing has run 74.9 s
- THEN it has not ended, and at 75 s it ends

#### Scenario: Solo finishes a coast crossing alone
- GIVEN a 1-player run on a 60 s raft crossing with no threat events
- WHEN the crossing runs to its end
- THEN it ends at 60 s with the player aboard and the raft at integrity 100

### Requirement: Threat plan
On entering, the host SHALL roll the crossing's events in time order from the route's risk profile, the distance band and the weather: a squall line that follows a squall the sky has warned or is running, or else is rolled by the squall's chance when the crossing is long enough for its warning; a shark pass and a rock by the band's chances times the route's factors. Clients receive the plan and never roll it. The plan is the same with exactly 1 player.

#### Scenario: A squall warned on the island follows the riders
- GIVEN a squall warned 40 s before a 90 s raft crossing starts
- WHEN the crossing starts
- THEN its plan holds a squall line hitting at 40 s

#### Scenario: Same seed, same plan
- GIVEN the same route, band, weather and seed
- WHEN the plan is rolled twice
- THEN both plans hold the same events at the same times

### Requirement: Raft integrity on the crossing
A raft on the crossing SHALL start at its integrity when launched (100 for a new raft) and lose 30 per squall times the route's squall factor, 20 per shark hit and 40 per rock, never below 0. At 0 it breaks: every rider aboard or tied falls in, nobody can climb or be pulled back, and they swim the rest of the crossing. Swimmers' routes have no integrity and take no vessel hits. The same holds with exactly 1 player, who swims the rest alone.

#### Scenario: Raft hits add up
- GIVEN a raft at integrity 100
- WHEN it takes a squall and a shark hit
- THEN its integrity is 50

#### Scenario: Squall, rock, squall break the raft
- GIVEN a 2-player crossing on a raft at integrity 100, one player tied down
- WHEN it takes a squall, a rock and a squall
- THEN integrity is 0, the raft is broken and both players are in the water, the tied one included

#### Scenario: Solo raft breaks
- GIVEN a 1-player crossing on a raft at integrity 40
- WHEN it hits a rock
- THEN the raft breaks, the player is in the water and holding interact at its edge for 3 s does not bring them aboard

### Requirement: Squall line on the crossing
A squall reaching the crossing SHALL be warned 60 s ahead by weather-daynight's warning and horizon line, shown in the crossing too. When it starts (or 10 s into a crossing launched during a running squall) it hits the raft once, and on a route that a squall dumps from, it throws every rider aboard who is not tied down into the water, with no chance roll. A tied-down rider stays aboard. With exactly 1 player, the player ties down alone.

#### Scenario: Squall warned 60 s ahead
- GIVEN a 90 s raft crossing whose plan rolls a squall warning at 10 s and its hit at 70 s
- WHEN the crossing reaches 10 s
- THEN the squall is warned with 60 s to go and the horizon line shows

#### Scenario: Tied down stays aboard
- GIVEN a 2-player raft crossing at integrity 100 where one player is tied down and the other is not
- WHEN the squall hits
- THEN the raft is at 70, the tied player is aboard and the other is in the water

### Requirement: Tying down
A rider aboard an intact raft SHALL tie down by holding interact for 1 s on the raft's lashing, and untie by using it again. A tied rider cannot move, stays aboard through a squall and falls in only when the raft breaks. A client's request goes to the host as its interact intent and the host decides. With exactly 1 player, the player ties down and unties alone.

#### Scenario: Solo ties down through a squall
- GIVEN a 1-player raft crossing at integrity 100
- WHEN the player holds interact on the lashing for 1 s and the squall hits
- THEN the player is aboard and tied, and the raft is at 70

### Requirement: Falling in
A rider who falls in (thrown by a squall, by the raft breaking or by stepping off the deck) SHALL lose 10 energy and swim alongside the vessel. Every second in the water costs 3 energy times the route's swim drain factor, moving or not. A swimmer at 0 energy floats and loses 10 health a second until pulled or climbed aboard, or dead. Solo rules (last stand) apply to a lone swimmer.

#### Scenario: Thrown in costs energy
- GIVEN a raft rider at energy 80 who is not tied down
- WHEN a squall throws them in and they stay in the water 5 s
- THEN their energy is 80 - 10 - 15 = 55

#### Scenario: A swimmers' route pays no fall-in cost
- GIVEN a swimmers' route
- WHEN its riders start the crossing in the water
- THEN nobody pays the 10 energy, only the per-second drain

#### Scenario: Solo swimmer finishes a swim crossing
- GIVEN a 1-player run whose player starts binoculars-and-swim at energy 100 on its 60 s crossing with swim drain factor 0.4
- WHEN the crossing runs to its end
- THEN the player is alive with energy 28 and the crossing ends at 60 s

### Requirement: Rescue timing on the crossing
Pulling and climbing aboard SHALL use the interaction hold rule: a rider aboard pulls a swimmer within 1 tile by holding interact on them for 2 s, and a swimmer within 1 tile of an intact vessel's edge climbs aboard alone by holding interact on it for 3 s. Releasing early resets the hold to 0 s. Both requests are a client's interact intent, applied by the host. With exactly 1 player, climbing alone is the way back aboard.

#### Scenario: Teammate pulls in 2 s
- GIVEN a 2-player raft crossing at integrity 60 with one player in the water beside the raft
- WHEN the player aboard holds interact on them for 2 s
- THEN the swimmer is aboard

#### Scenario: Solo climbs in 3 s, not 2
- GIVEN a 1-player raft crossing at integrity 60 whose player is in the water within 1 tile of the edge
- WHEN the player holds interact on the edge for 2 s and releases, then holds it for 3 s
- THEN the player is still in the water after the first hold, and aboard after the second

#### Scenario: Client requests are applied by the host
- GIVEN a 2-player raft crossing where the client's player is aboard
- WHEN the client holds interact on the lashing for 1 s, later falls in and holds interact on the edge for 3 s
- THEN the host ties the client's player down and then brings them aboard, and the client shows both states

### Requirement: Shark pass event
A shark pass SHALL hit, in this order of choice, a swimmer who is bleeding or below 20 energy (25 health and bleeding), otherwise an intact raft (-20), otherwise nobody. The shark pass is resolved through a replaceable threat hook (`CrossingThreats`) so the creatures-ai change can put a reef shark behind it without changing the crossing. With exactly 1 player, the lone player or their raft is the only target.

#### Scenario: Shark hits the raft
- GIVEN a raft crossing at integrity 100 with nobody in the water
- WHEN a shark pass comes
- THEN the raft is at 80

#### Scenario: Shark prefers a weak swimmer
- GIVEN a 1-player raft crossing whose player is in the water at energy 15 and health 100
- WHEN a shark pass comes
- THEN the player has health 75 and is bleeding, and the raft is untouched

### Requirement: Coast drift
On coast crossings the crossing SHALL record a drift offset of 0 tiles: steering is not built and the Gulf Stream rule of Steering and current applies only to mid and far crossings, which this change does not build. The same holds with exactly 1 player.

#### Scenario: Solo coast raft has no drift
- GIVEN a 1-player raft crossing from the sandbar
- WHEN it ends
- THEN its result records a drift offset of 0 tiles

### Requirement: End of the crossing
When the crossing ends, the host SHALL record a crossing result (route, vessel integrity and whether it broke, drift offset, and each rider's health, energy, whether they were aboard and whether they died) and send it to every client; the riders then leave play until arrival on the next island exists. A rider who died on the way counts as dead. With exactly 1 player, the result holds that player alone.

#### Scenario: Result carries the damaged raft
- GIVEN a 1-player raft crossing that took one squall while the player was tied down
- WHEN it ends
- THEN the result holds integrity 70, not broken, drift 0, and the player aboard and alive
