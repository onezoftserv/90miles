## MODIFIED Requirements

### Requirement: Credits screen
The title screen SHALL offer *Créditos*, a screen that shows every credits entry in Spanish, the CC-BY entries first, then the CC0 packs and the OFL fonts. Each CC-BY entry gives its author, "CC BY 4.0" and its source page, under a heading that gives the licence's address once (`https://creativecommons.org/licenses/by/4.0/`). The text is Press Start 2P at 8 px, readable at 640×360. The list scrolls when longer than the screen, with a cue while more of it lies below, and the screen returns to the title on back or Esc. It needs no network: a solo player, offline, reaches it from the title.

#### Scenario: A solo player reads the credits
- **GIVEN** the title screen, offline, with no session
- **WHEN** the player presses *Créditos*
- **THEN** the screen lists DawnLike (DragonDePlatino, paleta de DawnBringer), Tiny, Tiny Heroes - Animals (Kacper Woźniak) and Kyrise's icons, each with "CC BY 4.0" and its source page, under a heading with the licence's address, above the CC0 packs; no network port is opened, and Esc returns to the title

#### Scenario: The address once
- **GIVEN** the credits screen
- **WHEN** its text is read top to bottom
- **THEN** `https://creativecommons.org/licenses/by/4.0/` appears exactly once

#### Scenario: More below
- **GIVEN** the credits screen at the top of a list longer than its view
- **WHEN** it is drawn
- **THEN** "▼ Más abajo" shows under the list, and it is gone once the list is scrolled to its end
