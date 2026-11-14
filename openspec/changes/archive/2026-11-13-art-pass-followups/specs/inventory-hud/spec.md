## MODIFIED Requirements

### Requirement: Interact prompt
While the local player can act and holds no interact press, the HUD SHALL show one prompt over the interactable that the interaction picker would choose for them now (among the enabled ones within 1 tile that they may use, the highest interact priority, then the nearest; player-movement "Interaction"), as the interact key, a verb and a target: "[E] Recoger Coco". It shows nothing with no candidate in reach, while the player is down or out of play, while the crafting list is open or while a screen is shown. This peer computes it; the host still decides. Solo the same.

#### Scenario: Nearest one wins
- **GIVEN** a solo player 0.5 tiles from a coconut and 0.9 tiles from a palm
- **WHEN** the HUD is drawn
- **THEN** one prompt shows, over the coconut: "[E] Recoger Coco"

#### Scenario: Out of reach
- **GIVEN** a solo player 2 tiles from every interactable
- **WHEN** the HUD is drawn
- **THEN** no prompt shows

#### Scenario: A client's prompt
- **GIVEN** a client whose player stands within 1 tile of the raft site
- **WHEN** the client draws its HUD
- **THEN** it shows "[E] Construir Balsa" over the site without waiting for the host

#### Scenario: The perched gull's shoo shows over its palm
- **GIVEN** a solo player at the foot of a nest palm whose gull is perched there
- **WHEN** the HUD is drawn
- **THEN** one prompt shows, the gull's shoo ("[E] Espantar …"), and not "[E] Trepar Mata de coco"
