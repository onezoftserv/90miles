# Spec Delta

## MODIFIED Requirements

### Requirement: Run structure
A run SHALL be 6–8 islands: sandbar, coast, then 3–5 from the mid/far chains with branching, then the final approach. The run seed determines the branch graph; players choose at branch points when two routes lead to different chains. The secret cay (secret-cay) is an optional off-graph detour, at most once per run: it is not one of the 6–8 islands, takes no island index and is no branch, and after it the party goes on to the island it was heading for. A 1-player run counts the same way. (Changes docs/GAME_DESIGN.md §2 "Run length" and the run length in docs/ISLANDS.md.)

#### Scenario: Run length
- GIVEN a new run seed
- WHEN the branch graph is generated
- THEN every path through it is sandbar, coast, 3–5 islands from the mid/far chains, then the final approach (6–8 islands)

#### Scenario: The detour is not an island
- GIVEN a 1-player run that leaves island 4 for the secret cay and leaves the cay for the island it was heading to
- WHEN the run's islands are counted
- THEN the cay is not among them, the island after the cay is island 5, and the path is still 6–8 islands

### Requirement: Experiencia levels (world easing)
Each death SHALL add one Experiencia level (max 8), persisted in `user://profile.cfg`. Per level the world SHALL apply: thirst and hunger drain ×0.97 (compounding, min ×0.76), patrol period +10 s, +1 driftwood and +1 coconut per island, downed timer +5 s. A win SHALL subtract 2 levels (min 0). In co-op the host's level applies to the world; each player's own level applies to their downed timer. The secret cay is not an island for the per-island driftwood and coconut: its contents never grow with levels, solo or co-op. (Changes docs/GAME_DESIGN.md §14 "Difficulty and carry-over".)

#### Scenario: Fourth run
- GIVEN three deaths and no wins
- WHEN a new run starts
- THEN thirst drains at 0.913/min base, patrols loop every 3:30, and the sandbar spawns 11 driftwood and 13 coconuts

#### Scenario: No bonus on the cay
- GIVEN a 1-player run at Experiencia level 3
- WHEN the party lands on the secret cay
- THEN it holds its 7 coconuts and its listed driftwood, with no extra driftwood or coconut

### Requirement: Experiencia carry-over
On death the game SHALL persist to `user://profile.cfg`: 50% of skill XP earned that run per skill (floor), all plant identifications, escape routes used (per chain), 50% of NPC trust earned, all NPC-taught recipes, and POI map knowledge for chains reached. On a win it SHALL persist 100% of skill XP and trust. Carried skill XP SHALL NOT raise a skill above level 3 unless a run earned it. No map knowledge, route or hiding spot from the secret cay or its pieces (secret-cay) is ever carried, solo or co-op. (Changes docs/GAME_DESIGN.md §14 "Difficulty and carry-over".)

#### Scenario: Death on island 3
- GIVEN a run that earned 40 fishing XP, identified manchineel and used the turtle route on the reef chain
- WHEN the party dies on island 3
- THEN the next run starts with 20 fishing XP, manchineel already identified, and the turtle route shown as discovered on the first reef-chain island

#### Scenario: The cay leaves no trace
- GIVEN a 1-player run that found both pieces, visited the secret cay, left it by raft and died on island 5
- WHEN the next run starts
- THEN the profile holds no map knowledge, route or hiding spot from the cay or the pieces

### Requirement: Experiencia points
Each island reached SHALL grant 1 Experiencia point (banked, max 12). At run start the player SHALL spend points on permanent boosts from a fixed list (+10 max thirst, +1 inventory slot, +10 s downed timer, start with a known plant, start with 1 rope); unspent points stay banked. In co-op each player spends their own. The secret cay is not an island reached and grants no point, solo or co-op. (Changes docs/GAME_DESIGN.md §14 "Difficulty and carry-over".)

#### Scenario: Bank cap
- GIVEN a player with 11 banked Experiencia points
- WHEN the party reaches two more islands
- THEN the player has 12 banked points

#### Scenario: The detour pays nothing
- GIVEN a 1-player run whose player has 3 banked Experiencia points
- WHEN they reach the secret cay and then the island they were heading to
- THEN they have 4 banked points

### Requirement: Run summary
On death or ending, a summary SHALL show islands reached, days survived, companions saved and lost, texts found, and the cause of death with its Cuban one-liner. Islands reached never counts the secret cay, solo or co-op. (Counts islands as docs/GAME_DESIGN.md §2 "Run length" does.)

#### Scenario: Death summary
- GIVEN the party dies
- WHEN the summary shows
- THEN it lists islands reached, days survived, companions saved and lost, texts found, and the cause of death with its Cuban one-liner

#### Scenario: The cay is not listed as an island
- GIVEN a 1-player run that reached island 4, visited the secret cay, and died on island 5
- WHEN the summary shows
- THEN it lists 5 islands reached

### Requirement: Challenges
Challenge toggles (no fire, storm season, sinking raft, patrols everywhere) SHALL modify generation and rules, and are recorded on the run summary. Patrols everywhere places no patrol on the secret cay, which is never generated; the other toggles apply there as on any island. The same holds with 1 player. (Changes docs/GAME_DESIGN.md §14 "patrols on every island".)

#### Scenario: No-fire challenge recorded
- GIVEN a run with the no fire challenge on
- WHEN the run ends
- THEN the run summary records the no fire challenge

#### Scenario: No patrol on the cay
- GIVEN a 1-player run with the patrols everywhere challenge on
- WHEN the party lands on the secret cay
- THEN no patrol is on it
