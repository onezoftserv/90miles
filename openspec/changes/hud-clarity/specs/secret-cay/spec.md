## MODIFIED Requirements

### Requirement: Needle on the carrier's HUD
While the local player carries an item with the point-to-secret capability, their HUD SHALL show a 24×24 px needle at the top centre, at (384,20) to (408,44): right of the objective row and under the weather window's place, inside the 640×360 HUD budget and clear of the meters, the clock row, the objective row, the teammate list, the centre and the bottom band. Other players' screens do not show it. A solo player sees it on their own HUD.

#### Scenario: A solo player picks up the compass
- **GIVEN** one offline player with no compass and no needle on screen
- **WHEN** they pick up the broken compass
- **THEN** a 24×24 px needle shows at (384,20) to (408,44), clear of the objective row

#### Scenario: Only the carrier sees it
- **GIVEN** a host and a client, the client's player carrying the compass
- **WHEN** both HUDs are drawn
- **THEN** the client's HUD shows the needle and the host's does not
