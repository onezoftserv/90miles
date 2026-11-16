## ADDED Requirements

### Requirement: A use that changes nothing is refused
The host SHALL refuse a use, changing and spending nothing, when none of its effects would change anything for its subject. That means each meter it adds to is already at its cap, or less than 1 point from it (energy's starving cap included), each status it cures is absent, there is no effect of another kind (a revive, an item given or taken, a route, a flag, a delay, a change over time or a loss), and the item leaves no remainder. Solo the same, offline.

#### Scenario: Solo sábila with nothing to cure
- **GIVEN** a solo player, offline, who is neither bleeding nor sunburnt and holds sábila
- **WHEN** the use reaches the host
- **THEN** nothing changes and the sábila stays

#### Scenario: A coconut that still feeds
- **GIVEN** a player with full thirst, hunger 80 and full energy, holding a knife and a coconut
- **WHEN** they drink it
- **THEN** hunger is 85, the coconut is gone and the knife has one use less

#### Scenario: Nearly full is full
- **GIVEN** a solo player whose thirst has drained to 99.9, with full hunger and energy, holding a knife and a coconut
- **WHEN** the use reaches the host
- **THEN** nothing changes and the coconut stays

#### Scenario: A remainder still counts
- **GIVEN** a solo player with full hunger and energy, holding a conch
- **WHEN** they eat it
- **THEN** the conch is gone and its horn is in the inventory

#### Scenario: A forged wasted use
- **GIVEN** a client whose player is at full thirst, hunger and energy and holds a coconut
- **WHEN** it sends that coconut's use anyway
- **THEN** the host changes nothing and the coconut stays
