## ADDED Requirements

### Requirement: Bleeding drains health
While a player bleeds, the host SHALL take 0.1 health per second from them (6 per minute, the pace of resting thirst), every tick, so the loss is a drain and not a hit. Bleeding never takes a player's last point: at 1 health or less it takes nothing, so bleeding alone never downs or kills and names no cause of death. The wound's own damage is taken at once, as before. Solo bleeds the same way, offline. (Adds bleeding to `docs/GAME_DESIGN.md` §4, Health, "Drains from".)

#### Scenario: Solo bleeding drains health
- **GIVEN** a 1-player run, offline, whose player is at 100 health and starts bleeding
- **WHEN** 30 s pass
- **THEN** the player has 97 health and still bleeds

#### Scenario: Bleeding never takes the last point
- **GIVEN** a solo player, offline, at 2 health who bleeds
- **WHEN** 60 s pass
- **THEN** the player has 1 health, is neither in a last stand nor dead, and no cause of death is recorded

#### Scenario: A shark's strike, then the drain
- **GIVEN** a solo player at 100 health swimming in deep water
- **WHEN** a reef shark strikes them and 10 s pass
- **THEN** the strike took 25 at once and the bleeding has taken 1 since, leaving 74 health

### Requirement: Bleeding stops on its own
Bleeding SHALL end on its own 120 s (4 in-game hours) after the latest wound that started it; a new wound while bleeding restarts the 120 s, and does not add a second drain. Only the host keeps the time left; every peer still sees only whether the player bleeds, through the synced status, so nothing new is sent. The time runs only while the player's meters run (not while waiting out of play). A revive leaves bleeding as it is. Solo works the same, offline.

#### Scenario: Solo bleeding ends after 120 s
- **GIVEN** a 1-player run, offline, whose player starts bleeding at 100 health
- **WHEN** 120 s pass
- **THEN** the player no longer bleeds, the "Sangrando" tag is hidden, and health is 88 and stops falling

#### Scenario: A second wound restarts the time
- **GIVEN** a solo player who started bleeding 100 s ago
- **WHEN** a shark strikes them again
- **THEN** they still bleed 119 s later, and no longer bleed 121 s after the second strike

#### Scenario: A client sees its bleeding end
- **GIVEN** a host and a client, where the host's shark struck the client's player
- **WHEN** 120 s pass on the host
- **THEN** the bleeding ends on the host, and the client's game has its own player no longer bleeding, with nothing new in the player's synchronizer

#### Scenario: Waiting out of play freezes the time
- **GIVEN** a bleeding rider who arrives on the next island and waits out of play for 60 s
- **WHEN** they come back into play
- **THEN** they still bleed with the same time left as when they started waiting
