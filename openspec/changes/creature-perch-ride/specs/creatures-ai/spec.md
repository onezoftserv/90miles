# Spec Delta

## ADDED Requirements

### Requirement: Crossing creature roll
When a crossing launches, the host SHALL roll creatures from every CROSSING spawn rule that matches the departing island's chain family, the distance band, the day phase and the weather. Chance-1.0 rules are always placed within `max_per_run`; at most 2 rolled ones are placed. The plan's beats are rolled first and are unchanged. Clients never roll, and a crossing with 1 player rolls the same way.

#### Scenario: Solo crossing places a matching bird
- **GIVEN** a 1-player crossing out of a coast-family island, and a booby with a CROSSING rule for that family at chance 1.0
- **WHEN** the crossing launches
- **THEN** one booby is placed by the vessel, and the crossing's plan holds the same beats as when no creature has a crossing rule

#### Scenario: Rules for other islands stay out
- **GIVEN** a 1-player crossing out of a coast-family island, and the galleguito's rule for the final family at chance 1.0
- **WHEN** the crossing launches
- **THEN** no galleguito is placed

#### Scenario: Rolled creatures are capped
- **GIVEN** a 1-player crossing whose matching rules hold three rolled creatures at chance 0.99 and one at chance 1.0, with the dice always succeeding
- **WHEN** the crossing launches
- **THEN** two rolled creatures and the chance-1.0 creature are placed

#### Scenario: A creature capped per run comes once
- **GIVEN** a 1-player run with a creature whose crossing rule has chance 1.0 and `max_per_run` 1
- **WHEN** two such crossings launch, one after the other
- **THEN** it is placed on the first crossing only

### Requirement: Crossing creatures leave with the crossing
A crossing's creatures SHALL keep to the vessel's sea and are passing creatures: the island's phases, fires and counts never touch them. When the crossing ends, the host removes them and they leave every peer's screen. With exactly 1 player, offline, they go when the crossing ends.

#### Scenario: Solo crossing ends
- **GIVEN** a 1-player crossing with a booby riding along
- **WHEN** the crossing ends
- **THEN** the booby is gone, and the island's creature counts never included it

### Requirement: Sighting effects
Each player who sees a creature SHALL get its sighting effects: every living rider of its crossing, or on an island each player within its sight radius. A once-per-run effect reaches each player once per run, and a once-per-day effect once per day, counted by the player, not the connection, so a rejoin never pays twice. Meter changes apply to that player. A flag effect sets a run flag that the host keeps until the run ends.

#### Scenario: Solo songbird, once a day
- **GIVEN** a 1-player run at morale 50 and songbirds whose sighting gives +5 morale once a day
- **WHEN** a songbird joins a crossing on day 1, a second one on day 1, and a third on day 2
- **THEN** the player's morale goes to 55 after the first bird, stays 55 after the second, and reaches 60 after the third

#### Scenario: A flag is set once
- **GIVEN** a 1-player run and a creature whose sighting sets `galleguito_a_bordo`
- **WHEN** the player sees it
- **THEN** the run's `galleguito_a_bordo` flag is set, and a new run starts with no flags

#### Scenario: A rejoined player is not paid twice
- **GIVEN** a host and a client riding a crossing, and a creature whose sighting gives +10 morale once per run
- **WHEN** the client drops after the sighting, rejoins and sees it again
- **THEN** the client's player got +10 morale once

### Requirement: Ambient visits
An `ambient` creature SHALL arrive at its station (beside the vessel on a crossing, its spawn spot on an island), stay and leave. It leaves when a flee counter's condition holds, when its stay time ends (none means the whole crossing), or when its crossing ends. It never attacks, steals or touches the vessel. With exactly 1 player it behaves the same.

#### Scenario: Solo booby leaves in a squall
- **GIVEN** a 1-player crossing with a booby beside the vessel, whose flee counter holds while the weather is a squall
- **WHEN** the squall starts
- **THEN** the booby leaves, and the player's health, inventory and the vessel's integrity are unchanged

#### Scenario: Solo songbird stays the crossing
- **GIVEN** a 1-player crossing with a songbird that has no stay time
- **WHEN** the crossing runs to its end
- **THEN** the songbird stayed beside the vessel the whole time and never attacked or stole

### Requirement: Perch ride details
The `perch_ride` creature SHALL circle for its circle time, then land on its pick. Its first theft roll comes 60 s after it lands; a roll that falls while it is not perched is skipped. A shoo with nobody else aboard makes it circle for 5 s and land on the same rider. If its rider dies, it picks again among the riders aboard. With exactly 1 player, the pick is that player.

#### Scenario: Solo theft roll timing
- **GIVEN** a 1-player final crossing whose player holds 3 food items, with the dice always succeeding
- **WHEN** the galleguito lands and 59 s pass, then 1 s more, then 60 s more
- **THEN** nothing was taken after 59 s, one item after 60 s, and two after 120 s

#### Scenario: Solo shoo and re-land
- **GIVEN** a 1-player final crossing with the galleguito perched on the player
- **WHEN** the player shoos it
- **THEN** it circles for 5 s and lands on the player again, and a theft roll that fell in those 5 s took nothing

#### Scenario: Waiting over a swimmer
- **GIVEN** a 1-player final crossing with the galleguito perched and the player thrown into the water
- **WHEN** the player climbs back aboard
- **THEN** it waited overhead while the player swam, took nothing then, and lands on the player again

### Requirement: Perched creature never hides the rescue points
A perched creature's shoo prompt SHALL rank below the crossing's tie-down, climb and pull points, so a creature on a rider's head never stops that rider tying down, climbing or pulling. With exactly 1 player the solo rider can still tie down and climb with the gull on their head.

#### Scenario: Solo tie-down with the gull aboard
- **GIVEN** a 1-player final crossing with the galleguito perched on the player, who stands at the tie-down point
- **WHEN** the player holds interact for the tie-down time
- **THEN** the player is tied down and the galleguito is still perched

### Requirement: Perched creature on every peer
A perched creature SHALL be drawn on its rider's head on every peer, facing the way that peer draws the rider. A peer that joins mid-crossing sees it on the same rider's head. A rejoined rider keeps it. A client's shoo is a request the host checks for reach. Solo, offline, the lone player sees it on their own head.

#### Scenario: A client sees the gull on the right head
- **GIVEN** a host and a client on a final crossing, the galleguito perched on the client's player
- **WHEN** the client's player walks across the deck
- **THEN** on both peers the galleguito is drawn on the client's player's head

#### Scenario: A late joiner sees the perched gull
- **GIVEN** a final crossing with the galleguito perched on the host's player
- **WHEN** a client joins mid-crossing
- **THEN** the client sees the galleguito on the host's player's head

#### Scenario: A client shoos it
- **GIVEN** a host and a client on a final crossing, the galleguito perched on the host's player, the client's player beside them
- **WHEN** the client shoos it
- **THEN** the host makes it hop to the client's player's head

### Requirement: Carried-item immunity
A creature with a carried-item negate counter SHALL take nothing from a player who carries that item, both an island gull's swoop and a perched gull's theft roll. Solo, the lone holder is never robbed.

#### Scenario: Solo holder on the island and at sea
- **GIVEN** a 1-player run whose player carries the item named by a gull's and a galleguito's negate counters and holds 2 food items
- **WHEN** an island gull swoops, and later the galleguito's theft roll comes up with the dice always succeeding
- **THEN** the player still holds 2 food items
