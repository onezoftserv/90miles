# player-movement

## Purpose
Top-down movement, swimming and basic interaction for 1–4 players.

## Requirements

### Requirement: Walk, run, crouch
The player SHALL move on land with WASD/left stick at 4 tiles/s walking, 6 running, 2 crouching. Running drains 0.5 energy/s. Crouching sets the player's stealth state to hidden while on brush or mangrove tiles. At energy 0 on land the player can only crawl, at 1 tile/s, and cannot run.

#### Scenario: Running on sand
- GIVEN a player with energy 50 on a beach tile
- WHEN the player holds run for 10 s
- THEN energy is 45 and the player moved 60 tiles

#### Scenario: Crouching in brush
- **GIVEN** a player standing on a brush tile
- **WHEN** the player holds crouch
- **THEN** the player moves at 2 tiles/s and their stealth state is hidden

#### Scenario: Crawling at zero energy
- **GIVEN** a player on land with energy 0
- **WHEN** the player holds run and moves for 4 s
- **THEN** the player moved 4 tiles and energy is still 0

### Requirement: Swimming
The player SHALL swim in shallow and deep water at 3 tiles/s, draining 3 energy/s. At energy 0 the player can only float and drifts with current. Diving (hold crouch in water) hides the player from searchlights for 5 s and costs 10 energy.

#### Scenario: Exhausted swimmer
- GIVEN a player swimming with energy 3
- WHEN 1 s passes
- THEN the player is floating, speed 0, and drifts 1 tile/s in the current direction

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

### Requirement: Camera and viewport
The game SHALL render the world at 640×360 with integer scaling. The enlarged picture uses nearest filtering by default; the optional pixel filter setting (ui-shell "Pixel filter") smooths it instead, keeping the 640×360 base and the integer scale. In co-op each client follows its own player; the host sees the same.

#### Scenario: Two players apart
- **GIVEN** two players in a co-op session
- **WHEN** they move apart
- **THEN** each client's camera follows its own player, rendered at 640×360 with integer scaling and nearest filtering by default

#### Scenario: Smooth filter keeps the base
- **GIVEN** a player whose pixel filter is Suave
- **WHEN** their camera follows them at 2×
- **THEN** the world is still rendered at 640×360 and enlarged by exactly 2, with the smoothing applied only to the enlarged picture

### Requirement: Movement follows intents
The player's movement SHALL be driven by an intent (move direction, run, crouch, interact) produced by that player's input, so the same body behaves identically whether the intent comes from local input or from another peer.

#### Scenario: Same intent, same result
- **GIVEN** two players on the same terrain with the same energy
- **WHEN** both receive the intent "move east, running" for 2 s
- **THEN** both moved 12 tiles east and spent 1 energy

### Requirement: Named input actions
The game SHALL define named input actions, each with a keyboard or mouse default and, where one exists, a gamepad default: moving up, down, left and right (WASD; left stick), run (Shift; a shoulder button), crouch (Ctrl or C; a face button), interact (E; another face button), use the selected item (F; a third face button, X), slots 1 to 12 (the number row 1-9, 0, - and =; none on a gamepad, where D-pad cycling reaches them), next and previous slot (mouse wheel down and up; D-pad right and left) and list up and down (arrow keys up and down; D-pad up and down).

#### Scenario: Gamepad movement
- **WHEN** a player pushes the left stick fully right
- **THEN** the move intent points east with full strength and the player walks at 4 tiles/s

#### Scenario: Use on a gamepad
- **GIVEN** a solo player on a gamepad with a rain cup selected
- **WHEN** they hold X for 1 s
- **THEN** the cup is drunk, exactly as holding F would
