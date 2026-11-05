# endings-progression

## Purpose
Run structure, chain branching, endings and between-run keepsakes.

## Requirements

### Requirement: Run structure
A run SHALL be 6–8 islands: sandbar, coast, then 3–5 from the mid/far chains with branching, then the final approach. The run seed determines the branch graph; players choose at branch points when two routes lead to different chains.

### Requirement: Ending selection
On reaching land, the game SHALL select an ending from flags in priority order: `devuelto` (captured on the final crossing) → `el_nino` (Yunior alive) → `todos` (all met companions and NPC allies alive) → `los_que_llegamos` (party alive, some companions lost) → `solo` (one survivor). Each ending has a handwritten scene with slots filled by who is present.

#### Scenario: Todos
- GIVEN Ramón came along, Caridad's lamp was lit, Dayana and Papo are alive, Yunior was never met
- WHEN the party reaches land
- THEN the `todos` ending plays with Ramón, Dayana and Papo on the beach and Caridad in the credits

### Requirement: Keepsakes
Keepsakes SHALL unlock per `docs/GAME_DESIGN.md` §14, persist in `user://profile.cfg`, and be chosen (max 2) at run start. In co-op each player brings their own.

### Requirement: Difficulty baseline
Run 1 SHALL use full difficulty: no drain reductions, full patrol rate, no tutorial beyond the intro.

### Requirement: Experiencia levels (world easing)
Each death SHALL add one Experiencia level (max 8), persisted in `user://profile.cfg`. Per level the world SHALL apply: thirst and hunger drain ×0.97 (compounding, min ×0.76), patrol period +10 s, +1 driftwood and +1 coconut per island, downed timer +5 s. A win SHALL subtract 2 levels (min 0). In co-op the host's level applies to the world; each player's own level applies to their downed timer.

#### Scenario: Fourth run
- GIVEN three deaths and no wins
- WHEN a new run starts
- THEN thirst drains at 0.913/min base, patrols loop every 3:30, and the sandbar spawns 11 driftwood and 13 coconuts

### Requirement: Experiencia carry-over
On death the game SHALL persist to `user://profile.cfg`: 50% of skill XP earned that run per skill (floor), all plant identifications, escape routes used (per chain), 50% of NPC trust earned, all NPC-taught recipes, and POI map knowledge for chains reached. On a win it SHALL persist 100% of skill XP and trust. Carried skill XP SHALL NOT raise a skill above level 3 unless a run earned it.

#### Scenario: Death on island 3
- GIVEN a run that earned 40 fishing XP, identified manchineel and used the turtle route on the reef chain
- WHEN the party dies on island 3
- THEN the next run starts with 20 fishing XP, manchineel already identified, and the turtle route shown as discovered on the first reef-chain island

### Requirement: Experiencia points
Each island reached SHALL grant 1 Experiencia point (banked, max 12). At run start the player SHALL spend points on permanent boosts from a fixed list (+10 max thirst, +1 inventory slot, +10 s downed timer, start with a known plant, start with 1 rope); unspent points stay banked. In co-op each player spends their own.

### Requirement: NPC memory
Important NPCs SHALL read carried trust and greet returning players differently (`returning: true` in the AI context; handwritten variants for minor NPCs).

### Requirement: Seeds and dailies
Players SHALL be able to enter a seed; the daily run uses the UTC date. Seeded runs do not unlock keepsakes.

### Requirement: Challenges
Challenge toggles (no fire, storm season, sinking raft, patrols everywhere) SHALL modify generation and rules, and are recorded on the run summary.

### Requirement: Run summary
On death or ending, a summary SHALL show islands reached, days survived, companions saved and lost, texts found, and the cause of death with its Cuban one-liner.
