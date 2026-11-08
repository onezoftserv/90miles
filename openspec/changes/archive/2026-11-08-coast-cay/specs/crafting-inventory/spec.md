## ADDED Requirements

### Requirement: Coast cay items as data
Nails (*clavos*), the mirror (*espejo*), aloe (*sábila*) and the lighter (*fosforera*) SHALL be item data files following `docs/ITEMS.md`: nails a material; the mirror a shiny tool with no use yet; aloe a medicine whose 1 s use cures sunburn and bleeding (on the user or an adjacent teammate); the lighter a tool with the fire-lighting capability and 20 uses that lights a fire in 1 s instead of 30 s and spends 1 use. All four pass the content check. Exactly 1 player can pick up and use them alone.

#### Scenario: A solo player lights a fire with the lighter
- GIVEN one offline player holding the lighter, 3 driftwood and dry grass beside a fire build site
- WHEN they work the site
- THEN there is no fire at 0.9 s, the fire burns after 1 s and the lighter has 19 uses left

#### Scenario: A solo player uses aloe
- GIVEN one offline player with sunburn and bleeding and an aloe leaf
- WHEN they use it
- THEN both statuses are gone and the leaf is used up

### Requirement: Delayed effects
An effect with a delay SHALL apply on the host that many seconds after its source fires, to the same player, counted in that player's own time: the clock stops while their meters do not tick (a rider waiting out of play), and a player who is gone from the session never takes it. A cure effect (a status removed) is interpreted like a meter change. Exactly 1 player takes delayed effects the same way.

#### Scenario: A delayed thirst loss
- GIVEN one offline player and an effect that lowers thirst by 5 after 30 s
- WHEN the effect fires
- THEN thirst is unchanged at 29.9 s and 5 lower at 30 s, once

#### Scenario: The delay waits while out of play
- GIVEN a player with such an effect pending who becomes a waiting rider for 25 s
- WHEN they are back in play
- THEN the effect lands after the rest of its 30 s, not before
