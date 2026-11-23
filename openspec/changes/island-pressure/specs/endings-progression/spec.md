## MODIFIED Requirements

### Requirement: Solo last stand from Experiencia
For a player with no other living player (a 1-player run, or the last one alive), the downed-timer rewards SHALL lengthen the solo last-stand window that survival-meters defines: 12 s base on land (none at sea), +5 s per Experiencia level and +10 s with the downed-timer boost. The Medalla de la Caridad revive goes with this window but fires at 0 health before it starts (survival-meters), so it works on run 1 too. (Changes docs/GAME_DESIGN.md §14, whose base was 0 s.)

#### Scenario: Run 1 solo
- GIVEN a new profile with Experiencia level 0 and no boosts
- WHEN a 1-player run starts
- THEN the player's last-stand window is 12 s on land and 0 s at sea

#### Scenario: Eased solo
- GIVEN a profile at Experiencia level 4 that bought the +10 s downed-timer boost
- WHEN a 1-player run starts
- THEN the player's last-stand window is 42 s on land and 30 s at sea
