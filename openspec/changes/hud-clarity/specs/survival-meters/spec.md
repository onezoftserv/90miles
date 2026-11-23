## MODIFIED Requirements

### Requirement: HUD bars
The local player's screen SHALL show six labelled bars in Spanish, Salud first, then Sed, Hambre, Energía and Ánimo, and Calor last, apart from them, each label left of its bar and the value right of it, each bar filled to its meter's value out of 100 and updated when the value changes, readable at 640×360 in the committed pixel font. Calor is a thermometer: it fills as heat rises, and its empty track is tinted by zone instead of the meters' plain empty colour (calm below the warning step at 50, warning from 50, critical from 75), with a notch standing 1 px above and below the bar at 50 and at 75. While the local player has sunstroke, their screen is blurred and an "Insolación" row says why ("Sunstroke tag on the HUD").

#### Scenario: Bars follow the meters
- **GIVEN** the HUD of a player with thirst 100
- **WHEN** thirst drops to 40
- **THEN** the Sed bar shows 40 of 100

#### Scenario: Heat fills up
- **GIVEN** the HUD of a player with heat 0
- **WHEN** heat rises to 75
- **THEN** the Calor bar is three quarters full

#### Scenario: Only the sunstruck player's screen blurs
- **GIVEN** the HUD of player A and a teammate B
- **WHEN** B gets sunstroke and A does not
- **THEN** A's screen is not blurred, and it blurs once A gets sunstroke

#### Scenario: Salud comes first, Calor last
- **GIVEN** the HUD of a solo player, offline, with exactly 1 player
- **WHEN** the meters are drawn
- **THEN** the rows read Salud, Sed, Hambre, Energía, Ánimo and Calor from the top, each label left of its bar with the value right of it

#### Scenario: A cool player's thermometer is not empty
- **GIVEN** the HUD of a solo player, offline, with exactly 1 player, whose heat is 2
- **WHEN** the Calor row is drawn
- **THEN** its track shows the calm, warning and critical zones in their own tints, the notches stand at 50 and 75, and no part of the track is the meters' plain empty colour

### Requirement: Bleeding tag on the HUD
While the local player bleeds, their screen SHALL show a "Sangrando" status row in the meters window, under the meter rows: a red drop icon, the word in the alert red in the committed pixel font, and a time bar that holds the bleeding time left out of the tuning's full bleeding time and drains as it runs out, starting full again when a new wound restarts it. The row is hidden when the bleeding ends. It follows the player's synced status and synced time left ("Bleeding time on every peer"), so a client's row follows the host. The meters window with the row still fits inside (4,4) to (136,90). With exactly 1 player, offline, the row works the same.

#### Scenario: Solo player sees they bleed
- **GIVEN** the HUD of a 1-player run, offline, whose player is not bleeding
- **WHEN** a shark bite makes the player bleed, and later the bleeding ends
- **THEN** the "Sangrando" row shows with its icon and a full time bar while they bleed, and is hidden after

#### Scenario: The time bar drains
- **GIVEN** a solo player, offline, with exactly 1 player, who started bleeding 60 s ago with a 120 s bleeding time
- **WHEN** the "Sangrando" row is drawn
- **THEN** its time bar is half full

#### Scenario: A new wound fills the bar again
- **GIVEN** a solo player, offline, bleeding with 30 s of 120 s left
- **WHEN** a second bite lands
- **THEN** the time bar is full again

#### Scenario: A client's tag follows the host
- **GIVEN** a host and a client whose player is in the water during a crossing
- **WHEN** the host's shark bites the client's player, 60 s pass, and later the host ends the bleeding
- **THEN** the client's screen shows the "Sangrando" row with its time bar about half full at 60 s, then hides it

## ADDED Requirements

### Requirement: Bleeding time on every peer
The host SHALL keep each player's bleeding time left (bleeding-and-sabila D1) in a plain meter property that is synced like the other meters, and set it to 0 when the bleeding ends. Clients only read it. A late joiner gets it with the rest of the player's state. With exactly 1 player, offline, the property is the host's own and nothing is sent.

#### Scenario: A client reads the time left
- **GIVEN** a host and a client, the client's player bleeding on the host with 90 s left
- **WHEN** the client's game reads its own player's bleeding time
- **THEN** it reads 90 s, to within one sync interval

#### Scenario: Solo sends nothing
- **GIVEN** a 1-player run, offline, whose player bleeds
- **WHEN** the bleeding runs its course
- **THEN** the time left counts down to 0 on the player's own game and nothing is sent to anyone

### Requirement: Sunstroke tag on the HUD
While the local player has sunstroke, their screen SHALL show an "Insolación" status row in the meters window, above any "Sangrando" row: a sun icon, the word in the alert red in the committed pixel font, and a cooling bar ("Sunstroke cooling bar"). The row and the blur come and go together. It follows the player's synced sunstroke, so a client's row follows the host. With exactly 1 player, offline, the row works the same.

#### Scenario: A solo player sees why the screen blurs
- **GIVEN** the HUD of a 1-player run, offline, whose player's heat reaches 100
- **WHEN** sunstroke starts
- **THEN** the screen blurs and the "Insolación" row shows with its sun icon and a full bar

### Requirement: Sunstroke cooling bar
The "Insolación" row's bar SHALL show the heat still to shed before sunstroke ends: full at the tuning's sunstroke heat (`sunstroke_at`, 100) and empty at the heat where sunstroke ends (`sunstroke_ends_below`, 60), read from the tuning and the player's synced heat. With exactly 1 player, offline, the bar works the same.

#### Scenario: Cooling down
- **GIVEN** a solo player, offline, with sunstroke, whose heat falls to 80
- **WHEN** the "Insolación" row is drawn
- **THEN** its bar is half full, and the row and the blur go away once heat falls below 60
