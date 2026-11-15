## ADDED Requirements

### Requirement: A use that changes nothing is refused
The host SHALL refuse a use, changing and spending nothing, when none of its effects would change anything for its subject. That means each meter it adds to is already at its cap (energy's starving cap included), each status it cures is absent, and there is no effect of another kind (a revive, an item given or taken, a route, a flag, a delay, a change over time or a loss). Solo the same, offline.

#### Scenario: Solo sábila with nothing to cure
- **GIVEN** a solo player, offline, who is neither bleeding nor sunburnt and holds sábila
- **WHEN** the use reaches the host
- **THEN** nothing changes and the sábila stays

#### Scenario: A coconut that still feeds
- **GIVEN** a player with full thirst, hunger 80 and full energy, holding a knife and a coconut
- **WHEN** they drink it
- **THEN** hunger is 85, the coconut is gone and the knife has one use less

#### Scenario: A forged wasted use
- **GIVEN** a client whose player is at full thirst, hunger and energy and holds a coconut
- **WHEN** it sends that coconut's use anyway
- **THEN** the host changes nothing and the coconut stays
