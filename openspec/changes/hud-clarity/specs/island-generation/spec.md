## ADDED Requirements

### Requirement: The hut note
The sandbar SHALL hold one sign on the sand just south of the ruined hut, on the side facing the spawn points, read like every flavour sign ("Flavour signs"): a note left by an earlier balsero ("The hut note's words"). The sign is reachable on foot from every spawn point, and reading it changes nothing else. The sandbar's pick-ups, palms, tide pools, workbench and raft build site are unchanged. Exactly 1 player, offline, reads it the same way.

#### Scenario: A solo player reads the hut note
- **GIVEN** one offline player at the sandbar's solo spawn, language Spanish
- **WHEN** they walk to the hut note and press E
- **THEN** a sign note shows its Spanish line, and the player's inventory and meters are unchanged

#### Scenario: The note is in reach from every spawn
- **GIVEN** the built sandbar
- **WHEN** paths over land and shallows are checked from the solo spawn and every co-op spawn point
- **THEN** the hut note's cell can be reached from each

#### Scenario: The sandbar's contents are unchanged
- **GIVEN** the sandbar layout file with the hut note
- **WHEN** the island is built
- **THEN** it holds the same palms, coconuts, pick-ups, workbench and raft build site as before, and one sign

### Requirement: The hut note's words
The hut note's Spanish line SHALL state the run's goal in Cuban voice: Florida lies ninety miles to the north, a raft is built from wood, inner tubes and rope, and the crossing starts at night or in a squall, since by day the patrol sees a launch. It names no recipe count and quotes no real person. Its English line says the same and keeps the slang. Each wraps to at most 8 lines in the sign note. With exactly 1 player, offline, the words are the same.

#### Scenario: The note names the goal
- **GIVEN** the sandbar layout file
- **WHEN** the hut note's Spanish and English lines are read
- **THEN** the Spanish line names "la Florida", "norte" and "noche", the English one "Florida", "north" and "night", neither holds a digit, and each wraps to 8 lines or fewer
