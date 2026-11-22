## MODIFIED Requirements

### Requirement: Coast cay items as data
Nails (*clavos*), the mirror (*espejo*), aloe (*sábila*) and the lighter (*fosforera*) SHALL be item data files following `docs/ITEMS.md`: nails a material; the mirror a shiny tool with no use yet; aloe a medicine whose 1 s use, on the user or a teammate within reach, stops bleeding and heals 5 health at once (it also cures sunburn, which nothing gives yet); the lighter a tool with the fire-lighting capability and 20 uses that lights a fire in 1 s instead of 30 s and spends 1 use. All four pass the content check. Exactly 1 player can pick up and use them alone.

#### Scenario: A solo player lights a fire with the lighter
- GIVEN one offline player holding the lighter, 3 driftwood and dry grass beside a fire build site
- WHEN they work the site
- THEN there is no fire at 0.9 s, the fire burns after 1 s and the lighter has 19 uses left

#### Scenario: A solo player uses aloe
- GIVEN one offline player at 70 health with sunburn and bleeding and an aloe leaf
- WHEN they use it
- THEN both statuses are gone, health is 75 and the leaf is used up

## ADDED Requirements

### Requirement: Sábila on a teammate
A sábila use sent for a teammate within reach SHALL treat that teammate on the host: their bleeding stops and they gain 5 health, and the user's own meters do not change. A teammate out of reach, or one with nothing to treat (not bleeding and at full health), is refused and the leaf stays. Solo has no teammate: the lone player treats themself the same way, offline.

#### Scenario: Treating a bleeding teammate
- **GIVEN** a host and a client, the client's player at 60 health and bleeding, and the host's player half a tile away holding sábila, not bleeding
- **WHEN** the host's player uses it on the client's player
- **THEN** the client's player stops bleeding and has 65 health, on the host and on the client, the host's own health is unchanged and the leaf is gone

#### Scenario: A teammate out of reach
- **GIVEN** a bleeding teammate 3 tiles away
- **WHEN** a client sends a sábila use for them anyway
- **THEN** the host changes nothing and the leaf stays

#### Scenario: Solo treats themself
- **GIVEN** a 1-player run, offline, whose player bleeds at 80 health and holds sábila
- **WHEN** they use it
- **THEN** they stop bleeding, have 85 health and the leaf is gone

#### Scenario: Sábila at full health with nothing to treat
- **GIVEN** a solo player, offline, at full health who does not bleed, holding sábila
- **WHEN** the use reaches the host
- **THEN** nothing changes and the sábila stays

#### Scenario: Sábila still heals without a wound
- **GIVEN** a solo player, offline, at 90 health who does not bleed, holding sábila
- **WHEN** they use it
- **THEN** they have 95 health and the leaf is gone
