## ADDED Requirements

### Requirement: Sign note
Pressing interact at a flavour sign SHALL open a sign note on this peer's HUD only; it does not pause, and the press reaches the host as an ordinary interact that changes nothing. The note is a light card with dark text (contrast 7:1 or more), 240 px wide, centred under the day phase, fitted to its text: the sign's line in the game's language, word-wrapped to at most 8 lines, then "[E] Cerrar" with the device's key. Solo the same.

#### Scenario: A solo player reads the radio and walks away
- GIVEN one offline player within 1 tile of the coast cay's dead radio, language Spanish
- WHEN they press E, then walk 2 tiles away
- THEN a note opens on the press showing the radio's Spanish line wrapped to the card and "[E] Cerrar", it closes when they leave reach, and the clock kept running

### Requirement: Closing the sign note
An open sign note SHALL close when the player presses interact or pause, leaves the sign's reach (1 tile and the slack), goes down or leaves, or a screen opens. A press while it is open only closes it; it never acts on another sign or thing in reach. Solo the same.

#### Scenario: E closes the note
- GIVEN a solo player with a sign note open
- WHEN they press E
- THEN the note closes and nothing is picked up or climbed

#### Scenario: English and the gamepad
- GIVEN a solo player in English who last used a gamepad, beside the crossed sticks
- WHEN they press A
- THEN the note shows the sticks' English line and "[A] Close"

#### Scenario: Every line fits
- GIVEN every sign in every island layout, in Spanish and in English
- WHEN each line is wrapped to the card
- THEN it takes at most 8 lines and no line is wider than the card's inner width

#### Scenario: Only the reader sees it
- GIVEN a host and a client, the host beside a wall slogan
- WHEN the host presses E
- THEN the host's HUD shows the note and the client's HUD shows no note

## MODIFIED Requirements

### Requirement: Screens take input first
While the pause menu, the run summary or the host-lost screen is shown, the strip, the use button, the prompt, the crafting list and the sign note SHALL ignore input, and they hide once the local body is gone. While the crafting list or a sign note is open, interact acts on it only, the player's intent carries no interact press, and the use button does nothing. The pause button first closes an open list or note; in solo it pauses only on the next press, and in co-op it does nothing else.

#### Scenario: Paused
- **GIVEN** a solo player with the pause menu open
- **WHEN** they press 3 and F
- **THEN** the selection does not change and nothing is used

#### Scenario: Run summary
- **GIVEN** a solo player whose crossing ended and whose run summary shows
- **WHEN** they press 3, F and E
- **THEN** nothing changes and no request is sent

#### Scenario: Host lost
- **GIVEN** a client whose host went away
- **WHEN** the host-lost screen shows
- **THEN** no strip or prompt shows and the HUD reads no freed body

#### Scenario: Interact goes to the list
- **GIVEN** a solo player with the list open and driftwood on the ground within reach
- **WHEN** they press E
- **THEN** the highlighted recipe is chosen and the driftwood stays on the ground

#### Scenario: Use while the list is open
- **GIVEN** a solo player with the list open and a rain cup selected
- **WHEN** they hold F for 1 s
- **THEN** nothing is used and the list stays open

#### Scenario: Esc closes before it pauses
- **GIVEN** a solo player with the crafting list open
- **WHEN** they press Esc once, then again
- **THEN** the first press closes the list and does not pause, and the second opens the pause menu

#### Scenario: Esc in co-op
- **GIVEN** a host and a client, the client with the crafting list open
- **WHEN** the client presses Esc
- **THEN** the list closes, nothing pauses and no pause menu shows

#### Scenario: Esc closes the note before it pauses
- **GIVEN** a solo player with a sign note open
- **WHEN** they press Esc once, then again
- **THEN** the first press closes the note and does not pause, and the second opens the pause menu

#### Scenario: Use while the note is open
- **GIVEN** a solo player with a sign note open and a rain cup selected
- **WHEN** they hold F for 1 s
- **THEN** nothing is used and the note stays open
