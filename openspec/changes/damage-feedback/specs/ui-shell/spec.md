## ADDED Requirements

### Requirement: Hit flash at the screen edges
On a hit to the body whose meters the HUD shows (the player's own, or the teammate they watch while dead), the screen edges SHALL flash red once and fade within 0.4 s. A bigger hit flashes stronger, and the smallest hit is still plain to see. It flashes at most three times a second, and never for another body's hit. With "Reducir destellos" on it does not flash. Solo shows it the same way with exactly 1 player, offline.

#### Scenario: Solo pinch flashes the edges
- **GIVEN** a solo run, offline, with exactly 1 player at 100 health
- **WHEN** a land crab pinches the player for 5
- **THEN** the screen edges flash red and are clear again 0.4 s later

#### Scenario: A bigger hit flashes stronger
- **GIVEN** two solo players at 100 health
- **WHEN** a crab pinches one for 5 and a shark bites the other for 25
- **THEN** the shark's flash is stronger than the crab's

#### Scenario: A client sees its own hit
- **GIVEN** a co-op run with Yuni hosting and Papo on a client
- **WHEN** a crab pinches Papo
- **THEN** Papo's screen edges flash, and Yuni's do not

#### Scenario: Watching a hurt teammate
- **GIVEN** a dead co-op player watching Papo
- **WHEN** a shark bites Papo
- **THEN** the watcher's screen edges flash

#### Scenario: No flashing with reduce flashes
- **GIVEN** a player with "Reducir destellos" on
- **WHEN** a shark bites them
- **THEN** the screen edges do not flash

### Requirement: Lost health shows on the bar
When health falls, the Salud bar SHALL show the lost part in pale red beside the remaining fill, hold it for 0.4 s, then shrink it to the new value over 0.5 s. A hit also shakes the bar sideways by 1 px for 0.2 s, unless "Reducir destellos" is on. A drain shows its loss the same way without the shake. Solo shows it the same way with exactly 1 player, offline.

#### Scenario: A shark's bite leaves a chunk
- **GIVEN** a solo player at 100 health
- **WHEN** a shark bites them for 25
- **THEN** the Salud bar shows 75 filled and 25 in pale red, the pale red is gone 0.9 s later, and the bar shakes during the first 0.2 s

#### Scenario: A drain does not shake
- **GIVEN** a solo player whose thirst is 0
- **WHEN** health drains for 3 seconds
- **THEN** the Salud bar never shakes

#### Scenario: Switching bodies shows no loss
- **GIVEN** a dead co-op player whose HUD shows a teammate at 40 health
- **WHEN** the HUD switches to another teammate at 90 health
- **THEN** the Salud bar shows 90 with no pale red part

### Requirement: Drain glow on the health bar
While the shown body's health drains, the Salud bar's frame SHALL glow a dim, steady red, and the glow stops 1 s after the last loss. No glow shows for a hit alone. Solo shows it the same way with exactly 1 player, offline.

#### Scenario: Thirst at 0 glows
- **GIVEN** a solo player whose thirst reaches 0
- **WHEN** health starts draining
- **THEN** the Salud bar's frame glows dim red, and it stops 1 s after the player drinks and the drain ends

#### Scenario: A single hit does not glow
- **GIVEN** a solo player with full thirst
- **WHEN** a crab pinches them
- **THEN** the Salud bar's frame does not glow

## MODIFIED Requirements

### Requirement: Settings
The settings screen SHALL hold the player name, fullscreen, the scale (automatic or 1× to 4×), the pixel filter and "Reducir destellos" (reduce flashes, off by default), and keep them per install across launches. Esc and the gamepad back button return to the previous screen from every menu screen, except the host's lobby: closing it ends the lobby for everyone, so only "Salir" does that.

#### Scenario: Name kept
- **GIVEN** a player who sets the name "Dayana" and closes the game
- **WHEN** the game starts again
- **THEN** the name is "Dayana" and it is the name the lobby shows

#### Scenario: Esc in the host's lobby
- **GIVEN** a host in the lobby with a joined player
- **WHEN** the host presses Esc
- **THEN** the lobby stays open; a client pressing Esc in its lobby leaves it

#### Scenario: Reduce flashes kept
- **GIVEN** a player who ticks "Reducir destellos" and closes the game
- **WHEN** the game starts again
- **THEN** the box is still ticked and hits show without flashes
