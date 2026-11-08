# Spec Delta

## ADDED Requirements

### Requirement: Joining during a crossing
A peer that joins the run, or rejoins and takes back its body, while a crossing is under way SHALL show that crossing as the host has it: the same route, riders, elapsed time, rider states and vessel integrity, and the crossing's later events and its end. Each rider's body is in the sea where the host has it, on sea ground, with the camera kept to the sea. The joiner rolls and replays nothing. With exactly 1 player, offline, nobody can join, and the crossing runs as before.

#### Scenario: A new player joins mid-crossing
- **GIVEN** a 2-player run whose host and client ride a raft 20 s into a 90 s crossing, the raft at integrity 70 of 100 and the client in the water
- **WHEN** a third player joins
- **THEN** the third player's screen shows that crossing at about 20 s, with the raft at 70 of 100, the host aboard and the client in the water where the host has them, and it ends there when it ends on the host

#### Scenario: A rider rejoins mid-crossing
- **GIVEN** a 2-player run whose host and client ride a raft, the client tied down
- **WHEN** the client drops and joins again 10 s later from the same install
- **THEN** the client's screen shows the crossing with their own body tied on the raft, on sea ground and with the camera kept to the sea, and the host still has them in the same slot

#### Scenario: Joining before the route's start reached the joiner
- **GIVEN** a client that connected and saw a route start before the host answered its join request
- **WHEN** the host's answer arrives
- **THEN** the client shows one crossing for that route, not two

#### Scenario: Solo crossing unchanged
- **GIVEN** a 1-player run, offline, whose player launches the raft
- **WHEN** the crossing runs to its end
- **THEN** it plays and ends as before, and nothing is sent to anyone

### Requirement: Crossing messages reach only peers that have the crossing
The host SHALL send a crossing's plan, rider states and result only to peers that have that crossing: those connected when it started, and each joiner once that joiner has been told of it. No peer receives a message for a crossing it does not have. With exactly 1 player, offline, there is no peer and nothing is sent.

#### Scenario: A peer still joining gets no crossing messages
- **GIVEN** a crossing under way and a client that has connected but whose join request the host has not answered yet
- **WHEN** the host sends the crossing's rider states
- **THEN** that client receives none, and it logs no error about a missing crossing
