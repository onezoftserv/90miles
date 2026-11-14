# Spec Delta

## ADDED Requirements

### Requirement: Intent delivery
Each intent message a client sends SHALL carry its newest movement intent and the intents before it that the host has not acknowledged, up to 8. The message SHALL NOT depend on ordered or reliable delivery. The host SHALL apply each intent once, the first time it arrives, and ignore older and repeated ones. The host's own player, and so the solo player, sends one intent per frame and applies it on that frame, with no copies.

#### Scenario: A lost message costs no movement
- **GIVEN** a client walking east whose host has acknowledged nothing for its last 3 frames
- **WHEN** the messages of 2 of those frames are lost and the third arrives
- **THEN** the host moves the player for all 3 frames, and once the host's state arrives the client's player is exactly where the host has it, with no correction

#### Scenario: A repeated intent is applied once
- **GIVEN** a host that has applied a client's intents up to number 40
- **WHEN** a message arrives carrying intents 38 to 42
- **THEN** the host applies 41 and 42 once each and nothing else, and the rate limits are charged for those two only

#### Scenario: Messages arrive out of order
- **GIVEN** a client that sends a message carrying intents 10 to 12 and then one carrying 11 to 13
- **WHEN** the second arrives before the first
- **THEN** the host applies 11, 12 and 13 once each and ignores the first message when it comes

#### Scenario: Solo player sends one intent a frame
- **GIVEN** a solo player, offline, walking east for 60 frames
- **WHEN** each frame's input is made
- **THEN** each intent is applied once, on the frame it was made, and no intent is ever sent or applied twice

### Requirement: Unreliable traffic is not thinned on a lossless link
On a link that loses no packets, the transport SHALL deliver every unreliable message (intents and host states), however the round trip varies. On ENet, this means the host keeps ENet's packet throttle open on every connection. Solo uses no transport and is unaffected.

#### Scenario: Round trips slow down after a calm start
- **GIVEN** a client that joined over a calm link with round trips of about 2 ms
- **WHEN** both machines' frames slow to 120 ms for 16 frames while the client walks and sends requests
- **THEN** the host receives every intent the client sent in those frames and the client receives one host state per host frame

#### Scenario: A solo run
- **GIVEN** a solo player, offline
- **WHEN** they play
- **THEN** no transport exists and nothing is throttled

## MODIFIED Requirements

### Requirement: Per-peer rate limits
The host SHALL limit each client to 90 intents per second with a burst of 90, and to 1.05 s of simulated movement per second of real time with 1.25 s of slack, each intent counting at least one 1/60 s frame and at most 0.1 s. An intent counts once, when the host first applies it; repeats of it cost nothing. Every player, solo included, gets 3 quick-chat phrases in a burst, then one every 2 s. Over-limit messages are dropped. The host's own (solo) player's intents are never limited.

#### Scenario: Client claims extra time
- **GIVEN** a client whose player is walking east
- **WHEN** it sends, within 1 s, 60 intents that each claim 0.1 s
- **THEN** the host moves that player at most 9.2 tiles (2.3 s of walking at 4 tiles/s)

#### Scenario: Client after a host hitch
- **GIVEN** a client walking east whose host has been sending states every frame
- **WHEN** one host frame lasts 1 s, so the client's 60 intents of that second arrive together
- **THEN** the host applies all 60 and the client's player is not corrected

#### Scenario: The limit refills after a hitch
- **GIVEN** a client whose simulated-time slack a hitch has used up
- **WHEN** it then walks for 30 s at one intent per 1/60 s frame with arrivals up to 20 ms early or late
- **THEN** no intent is refused after the first 2 s, and the full 1.25 s of slack is back by the end

#### Scenario: Solo player during a long frame
- **GIVEN** a solo player walking east
- **WHEN** 120 frames of input are stepped at once
- **THEN** all 120 are applied and the player walked 8 tiles

#### Scenario: Quick-chat spam
- **GIVEN** a player who has not used quick chat
- **WHEN** they pick 5 phrases at once
- **THEN** 3 bubbles are shown and the next phrase is accepted 2 s later
