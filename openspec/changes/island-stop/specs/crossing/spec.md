## ADDED Requirements

### Requirement: Raft maximum and fittings at sea
A raft SHALL enter the crossing with the integrity, maximum and fittings it had on the beach. Its maximum is its recipe's integrity (raft 100) plus its fittings' bonuses, and nothing on the crossing raises integrity above it. Its look (whole, worn, breaking) is the share of that maximum it has left. Only a raft takes fittings: boards, the car and swimmers never do. With exactly 1 player the same holds.

#### Scenario: Solo launches a nailed raft
- **GIVEN** a 1-player run whose beached raft is at 90 of 120 with the clavazón
- **WHEN** the player launches it and a squall hits while they are tied down
- **THEN** the crossing started at 90 of 120 and the raft is at 60 of 120

#### Scenario: A plank stops at the maximum
- **GIVEN** a 1-player raft crossing at 115 of 120 with the clavazón
- **WHEN** the player lashes on a plank
- **THEN** the raft is at 120 of 120

#### Scenario: The look follows the maximum
- **GIVEN** two 1-player raft crossings, each raft at integrity 70, one at 70 of 100 with no fittings and one at 70 of 120 with the clavazón
- **WHEN** both are drawn
- **THEN** the first is drawn whole and the second worn

### Requirement: Defensas at sea
A raft with defensas SHALL lose half the usual integrity to every rock and debris that hits it, the reef line's rocks included. A debris that hits still opens its leak, and squalls and shark hits are unchanged. A rock or debris that cuts a swimmer is unchanged. With exactly 1 player the same holds.

#### Scenario: Solo rock on the defensas
- **GIVEN** a 1-player raft crossing at 100 of 100 with defensas
- **WHEN** a rock hits it
- **THEN** the raft is at 80

#### Scenario: A squall is unchanged
- **GIVEN** a 1-player raft crossing at 100 of 100 with defensas and the player tied down
- **WHEN** a squall hits
- **THEN** the raft is at 70

#### Scenario: Debris on the defensas
- **GIVEN** a 1-player raft crossing at 100 of 100 with defensas
- **WHEN** a debris hits it
- **THEN** the raft is at 97.5 and a leak is open

### Requirement: Toldo at sea
A raft with a toldo SHALL count its deck as shade for every rider aboard: their thirst takes no sun factor and their heat falls as it does in shade (survival-meters "Thirst" and "Heat"). A rider in the water follows the swimming rules. With exactly 1 player the same holds.

#### Scenario: Solo midday crossing under the toldo
- **GIVEN** a 1-player run whose raft has a toldo, launched at 11:00 in calm weather with the player at thirst 80 and heat 0, aboard the whole 75 s crossing
- **WHEN** the crossing ends
- **THEN** the player's heat is 0 and their thirst is 72.5

#### Scenario: The same crossing without the toldo
- **GIVEN** the same run and crossing with a raft that has no toldo
- **WHEN** the crossing ends
- **THEN** the player's thirst is 65 and their heat reached 100, bringing sunstroke, before the end

### Requirement: Fittings ride with the raft
The crossing result SHALL record a raft's maximum and fittings with its integrity, and a raft beached on the next island (crossing "Arrival") SHALL keep them. A raft that breaks loses its fittings, and a raft built later starts at 100 of 100 with none. Every client, and a peer that joins during the crossing or after the arrival, shows the same maximum and fittings. With exactly 1 player, offline, the result holds them and nothing is sent.

#### Scenario: Solo carries a toldo to the coast cay
- **GIVEN** a 1-player run whose raft with a toldo leaves the sandbar at 100 of 100
- **WHEN** the crossing ends with the raft intact at 70
- **THEN** a raft at 70 of 100 with the toldo stands at the coast cay's raft build site

#### Scenario: A broken raft loses its fittings
- **GIVEN** a 1-player run whose raft with the clavazón breaks on the crossing
- **WHEN** the player arrives on the coast cay
- **THEN** the raft build site is empty, and a raft built there is at 100 of 100 with no fittings

#### Scenario: The sturdiest raft keeps its own fittings
- **GIVEN** 2 rafts that end their crossings intact for the same landing, one at 80 of 100 with a toldo and one at 60 of 120 with the clavazón
- **WHEN** the riders arrive
- **THEN** the beached raft is at 80 of 100 with the toldo and no clavazón

#### Scenario: A joiner sees the fittings mid-crossing
- **GIVEN** a host and a client riding a raft at 90 of 120 with the clavazón and a toldo
- **WHEN** a third player joins during the crossing
- **THEN** the third player's screen shows the raft at 90 of 120 with the toldo drawn
