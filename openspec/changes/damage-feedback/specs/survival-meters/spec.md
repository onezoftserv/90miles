## ADDED Requirements

### Requirement: Hits and drains are told apart
Every peer SHALL sort each body's losses of health from the health it already holds, with nothing sent for it. A loss at least 3 more than the body's recent steady loss would give in the same time is a hit (a shark's 25, a crab's 5). Any other loss is a drain (thirst at 0, drowning, manzanillo). The first health a peer sees for a body, a rise and a dead body never count. Solo sorts them the same way, offline.

#### Scenario: A crab's pinch is a hit, solo
- **GIVEN** a solo run, offline, with exactly 1 player at 100 health
- **WHEN** a land crab pinches the player for 5
- **THEN** that loss counts as a hit of 5

#### Scenario: Thirst at 0 is a drain
- **GIVEN** a solo player whose thirst is 0, losing 2 health per second
- **WHEN** 3 seconds pass
- **THEN** every loss counts as a drain and none as a hit

#### Scenario: A gap in the sync is not a hit
- **GIVEN** a client whose own player is drowning in the crossing at 10 health per second
- **WHEN** half a second of the host's updates is lost and the next one shows 5 health less
- **THEN** that loss counts as a drain

#### Scenario: A hit during a drain
- **GIVEN** a player drowning at 10 health per second
- **WHEN** a shark bites them for 25
- **THEN** that loss counts as a hit of 25

#### Scenario: A late joiner sees no old hit
- **GIVEN** a co-op host at 60 health after a shark's bite
- **WHEN** a client joins and first sees the host's body
- **THEN** that client counts no hit or drain on it

#### Scenario: Healing and revives are not losses
- **GIVEN** a downed player at 0 health
- **WHEN** a teammate revives them to 30
- **THEN** nothing counts as a hit or a drain

#### Scenario: Nothing is sent for it
- **GIVEN** the player's state synchronizer
- **WHEN** this change is in
- **THEN** it lists the same property paths as before, and no message is added for hits

### Requirement: Hurt cue on the body
On a hit, every peer SHALL draw the hurt body white for one frame, then blink it for 0.6 s. A drain shows nothing on the body. The cue is drawing only: it writes no position, meter, synced value or input, and a run with every art node stripped plays the same. With "Reducir destellos" on, the blink is a steady red tint for the same 0.6 s. Solo shows it the same way with exactly 1 player, offline.

#### Scenario: Solo pinch blinks the body
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** a land crab pinches the player
- **THEN** the player's sprite is white for one frame, then blinks, and is drawn as before 0.6 s after the pinch

#### Scenario: A drain does not blink
- **GIVEN** a solo player whose thirst is 0
- **WHEN** health drains for 3 seconds
- **THEN** the sprite never blinks

#### Scenario: A teammate's hit shows on their body
- **GIVEN** a co-op run with Yuni hosting and Papo on a client
- **WHEN** a crab pinches Yuni
- **THEN** Yuni's body blinks on Papo's screen as well as on Yuni's

#### Scenario: Reduce flashes
- **GIVEN** a player with "Reducir destellos" on
- **WHEN** a shark bites them
- **THEN** their sprite is tinted red for 0.6 s and is never drawn white or hidden by a blink

#### Scenario: Same run with a hit, art or no art
- **GIVEN** the solo sandbar run with fixed intents that checks drawing never changes the simulation
- **WHEN** a crab pinches the player during it, once with art and once with every art node stripped
- **THEN** the positions, meters, inventories and creature states are equal at every frame
