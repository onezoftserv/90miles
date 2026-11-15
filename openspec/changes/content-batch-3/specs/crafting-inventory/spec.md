## ADDED Requirements

### Requirement: Drinking the batch's cups and rum
A player SHALL get from each drink of the batch the thirst and other meter changes `docs/ITEMS.md` gives: still cup thirst +40, well cup +30, seawater +10 and then −30 over 120 s, rum thirst +5, morale +15 and energy −10 and then thirst −10 after 60 s. A solo player drinks alone, and the drink is used up.

#### Scenario: A solo player drinks a still cup
- **GIVEN** one offline player with thirst 40 holding a still cup
- **WHEN** they drink it
- **THEN** thirst is 80 and the cup is gone

#### Scenario: A solo player drinks seawater
- **GIVEN** one offline player with thirst 50 holding a seawater cup
- **WHEN** they drink it
- **THEN** thirst is 60 at once, and 120 s later it has lost 30 more than the normal drain alone would take

#### Scenario: Rum has three swigs
- **GIVEN** one offline player holding a full bottle of rum
- **WHEN** they drink from it once
- **THEN** morale rose by 15, energy fell by 10, the bottle has 2 swigs left, and 60 s later thirst falls by 10 once

### Requirement: Which of the batch's drinks revive
The still cup and the well cup SHALL revive like the rain cup: used on a downed teammate within 1 tile, or by a solo player on themselves in a last stand, they stand the player up at 30 health and then apply the drink. Seawater and rum SHALL never revive. This applies "Fresh-water revives" to the new cups.

#### Scenario: A solo last stand on a well cup
- **GIVEN** one offline player in a last stand holding a well cup
- **WHEN** they drink it
- **THEN** they stand at 30 health and the cup is gone

#### Scenario: Rum and seawater never revive
- **GIVEN** one offline player in a last stand holding only rum and a seawater cup
- **WHEN** they try each on themselves
- **THEN** they stay down and both are still in their inventory

### Requirement: Eating the batch's foods
A player SHALL get from each food and edible plant of the batch the hunger and other meter changes `docs/ITEMS.md` gives, and, because it restores hunger, the meal energy (+10). A solo player eats alone, and one unit is used up per meal.

#### Scenario: A solo player eats cooked fish
- **GIVEN** one offline player with hunger 40 and energy 40 holding 2 cooked fish
- **WHEN** they eat one
- **THEN** hunger is 75, energy is 50 and they hold 1 cooked fish

#### Scenario: Guanábana feeds, waters and cheers
- **GIVEN** one offline player with hunger 50, thirst 50 and morale 50 holding a guanábana
- **WHEN** they eat it
- **THEN** hunger is 75, thirst is 65 and morale is 60

### Requirement: Opening canned food
Canned food SHALL need a carried item that opens cans; opening it spends one use of that item, like a coconut and its blade. Without one, nothing happens and the can stays. A solo player opens it alone.

#### Scenario: A solo player and a can
- **GIVEN** one offline player holding canned food and no item that opens cans
- **WHEN** they try to eat it
- **THEN** nothing happens and they still hold the can; with a knife they eat it, hunger rises by 30 and the knife has one use less

### Requirement: Raw food names its cooked form
Raw crab and raw fish SHALL each name the cooked item they become at a fire and the seconds it takes, so cooking needs no recipe. The cooked forms carry no poison risk.

#### Scenario: Raw fish at a fire
- **WHEN** the raw fish item is read
- **THEN** it becomes cooked fish after 20 s at a fire, and cooked fish has no poison effect
