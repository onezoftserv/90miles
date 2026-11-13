## MODIFIED Requirements

### Requirement: Flavour signs
A layout MAY list signs: a glyph with a Spanish and an English line. A player who interacts with a sign SHALL see its line in a sign note on their own HUD (inventory-hud "Sign note"), in the game's language; teammates see nothing, and reading changes nothing else. The observation post's dead radio and wall slogans, and the cache's crossed sticks, are signs; their lines satirise the system and daily life and never quote a real person. Exactly 1 player, offline, reads them the same way.

#### Scenario: A solo player reads the wall
- GIVEN one offline player beside a wall slogan on the coast cay, language Spanish
- WHEN they interact with it
- THEN a sign note shows the slogan's Spanish line and the player's inventory and meters are unchanged

#### Scenario: A teammate's reading stays on their screen
- GIVEN a host and a client on the coast cay, the client beside the dead radio
- WHEN the client interacts with it
- THEN the client's HUD shows the radio's line in a note, and the host's HUD shows no note and no bubble
