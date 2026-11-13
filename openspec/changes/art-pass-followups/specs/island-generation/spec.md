## MODIFIED Requirements

### Requirement: Flavour signs
A layout MAY list signs: a glyph with a Spanish and an English line. A player who interacts with a sign SHALL see its line in a speech bubble over it, in the game's language, on every peer; reading changes nothing else. A sign's interact prompt reads "[E] Mirar" ("[E] Look" in English), because signs are looked at as much as read. The observation post's dead radio and wall slogans, and the cache's crossed sticks, are signs; their lines satirise the system and daily life and never quote a real person. Exactly 1 player, offline, reads them the same way.

#### Scenario: A solo player reads the wall
- GIVEN one offline player beside a wall slogan on the coast cay, language Spanish
- WHEN they interact with it
- THEN a speech bubble shows the slogan's Spanish line and the player's inventory and meters are unchanged

#### Scenario: A sign's prompt has its verb
- **GIVEN** one offline player within 1 tile of a sign on the coast cay and of nothing else, language Spanish
- **WHEN** the HUD is drawn
- **THEN** the prompt over the sign reads "[E] Mirar"
