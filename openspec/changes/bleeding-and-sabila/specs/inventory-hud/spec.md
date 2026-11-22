## MODIFIED Requirements

### Requirement: Which use the button picks
The use button SHALL send the item's first use, on the player themself, with three exceptions read from the item's data: during a solo last stand it sends the item's first use that revives; in co-op, when a teammate who is downed and not dead is within 1 tile and the item has a use that revives others, it sends that use on the nearest such teammate, and the selected item's line adds their name ("[F] Beber: Papo"); and a use that cures goes where "Who a cure goes to" says. When the use it needs does not exist the item counts as having no use.

#### Scenario: Solo last stand
- **GIVEN** a solo player in a last stand holding a rain cup, selected
- **WHEN** they hold F for 1 s
- **THEN** they stand at 30 health and the cup is gone

#### Scenario: Reviving a teammate
- **GIVEN** a co-op player holding a rain cup, selected, 0.5 tiles from a downed teammate
- **WHEN** they hold F for 1 s
- **THEN** the teammate stands at 30 health with thirst 25 higher and the cup is gone; with no downed teammate in reach the player drinks it instead

#### Scenario: A dead teammate is skipped
- **GIVEN** a co-op player holding a rain cup, selected, 0.5 tiles from a dead teammate and 3 tiles from anyone downed
- **WHEN** they hold F for 1 s
- **THEN** they drink it themself

## ADDED Requirements

### Requirement: Who a cure goes to
When the item's first use can go on others and cures a status, the use button SHALL send it on the player themself if they have a status it cures, otherwise on the nearest standing teammate within 1 tile who has one, with that teammate's name on the selected item's line ("[F] Untar: Papo"), otherwise on the player themself. A revive keeps its priority. A use that cures nothing (a cup, a coconut) never goes to a standing teammate. Solo: the cure always goes on the lone player.

#### Scenario: Sábila goes to a bleeding teammate
- **GIVEN** a co-op player who does not bleed, holding sábila, selected, 0.5 tiles from a bleeding teammate called Papo
- **WHEN** the selected item's line shows and they hold F for 1 s
- **THEN** the line reads "Sábila · [F] Untar: Papo", Papo stops bleeding and the leaf is gone

#### Scenario: The holder bleeds too
- **GIVEN** a co-op player who bleeds, holding sábila, selected, 0.5 tiles from a bleeding teammate
- **WHEN** they hold F for 1 s
- **THEN** the player stops bleeding and the teammate still bleeds

#### Scenario: A teammate beyond reach
- **GIVEN** a co-op player who does not bleed, at 90 health, holding sábila, selected, 3 tiles from a bleeding teammate
- **WHEN** they hold F for 1 s
- **THEN** the player has 95 health, the teammate still bleeds and the leaf is gone

#### Scenario: A cup never goes to a standing teammate
- **GIVEN** a co-op player at thirst 50 holding a rain cup, selected, 0.5 tiles from a standing teammate at thirst 10
- **WHEN** they hold F for 1 s
- **THEN** the player drinks it themself

#### Scenario: Solo sábila goes on the lone player
- **GIVEN** a 1-player run, offline, whose player bleeds and holds sábila, selected
- **WHEN** they hold F for 1 s
- **THEN** they stop bleeding and the leaf is gone
