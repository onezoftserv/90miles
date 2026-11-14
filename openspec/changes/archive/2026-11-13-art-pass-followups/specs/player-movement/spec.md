## MODIFIED Requirements

### Requirement: Interaction
The player SHALL interact with one interactable within 1 tile via a single button: pick up, talk, use, climb, shoo. Among the enabled interactables within 1 tile that the player may use, the one with the highest interact priority wins, and among equal priorities the nearest. Things (pick-ups, palms, structures, signs) have the base priority; a creature that can be shooed has a higher one, so a perched gull is shooed before its palm is climbed. Dragging a downed player starts on press and lasts while the button is held. Timed interactions (pull a trap, cut a net) SHALL complete only while the player stays within 1 tile and while the button is held for that interactable's hold time, 2 s unless the interactable sets another. Exactly 1 player, offline, chooses the same way.

#### Scenario: Drag a downed teammate
- GIVEN a downed teammate adjacent to the player
- WHEN the player holds interact
- THEN the teammate follows the player at 2 tiles/s until released

#### Scenario: Nearest interactable wins
- **GIVEN** a coconut 0.5 tiles away and a crate 0.9 tiles away
- **WHEN** the player presses interact
- **THEN** the coconut is used and the crate is not

#### Scenario: Releasing early cancels a timed interaction
- **GIVEN** a net that takes 2 s to cut
- **WHEN** the player holds interact for 1.5 s and releases
- **THEN** the net is not cut and holding again starts from 0 s

#### Scenario: A solo player shoos the gull perched over a palm
- **GIVEN** one offline player at the foot of a nest palm whose gull is perched there, both within 1 tile
- **WHEN** the player presses interact
- **THEN** the gull flees and the palm's climb does not start

#### Scenario: With the gull gone, the palm is climbed
- **GIVEN** the same player after the gull has fled out of reach
- **WHEN** the player holds interact for the palm's hold time
- **THEN** the player climbs the palm and gets a coconut
