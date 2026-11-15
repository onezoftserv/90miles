## ADDED Requirements

### Requirement: Pliers open cans
The pliers SHALL open canned food like the knife: a player carrying pliers and no knife can eat a can, and opening it spends one pliers use. A solo player opens it alone. (`docs/ITEMS.md` Tools: pliers "open cans".)

#### Scenario: A solo player opens a can with the pliers
- **GIVEN** one offline player with hunger 40 holding canned food and new pliers (50 uses), and no knife
- **WHEN** they eat the can
- **THEN** hunger is 70, the can is gone and the pliers have 49 uses left

### Requirement: The machete opens coconuts
A machete SHALL open a coconut like the knife, spending one machete use per coconut. A solo player opens it alone.

#### Scenario: A solo player opens a coconut with a machete
- **GIVEN** one offline player holding a coconut and a new machete (60 uses), and no knife
- **WHEN** they drink the coconut
- **THEN** thirst rises by the coconut's amount, the coconut is gone and the machete has 59 uses left

### Requirement: Flint and steel light a fire
Flint and steel SHALL be a fast tool for the fire: a player carrying them builds a fire in 10 s of work instead of the recipe's 30 s, and the flint never wears out. The lighter stays the faster tool (1 s, 20 uses). A solo player builds the fire alone.

#### Scenario: A solo player's fire with flint and steel
- **GIVEN** one offline player carrying flint and steel, three driftwood and dry grass, and no lighter
- **WHEN** they build a fire
- **THEN** the fire takes 10 s of work, and the flint and steel are still in their inventory afterwards

### Requirement: The conch leaves its horn
Eating the last bite of a conch SHALL leave its shell as a conch horn (*guamo*) in the eater's inventory, if it fits. Blowing the horn makes a noise of radius 15 tiles and never uses it up. A solo player gets and keeps the horn alone. (Adds the horn to `docs/ITEMS.md` Tools, 18 to 19, and Counts, 116 to 117 items.)

#### Scenario: A solo player keeps the shell
- **GIVEN** one offline player holding 1 conch
- **WHEN** they eat it
- **THEN** the conch is gone and they hold 1 conch horn

#### Scenario: A stack of conchs
- **GIVEN** one offline player holding 2 conchs
- **WHEN** they eat one
- **THEN** they hold 1 conch and 1 conch horn
