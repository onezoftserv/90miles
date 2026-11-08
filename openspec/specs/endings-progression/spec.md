# endings-progression

## Purpose
Run structure, chain branching, endings and between-run keepsakes.

## Requirements

### Requirement: Run structure
A run SHALL be 6–8 islands: sandbar, coast, then 3–5 from the mid/far chains with branching, then the final approach. The run seed determines the branch graph; players choose at branch points when two routes lead to different chains.

#### Scenario: Run length
- GIVEN a new run seed
- WHEN the branch graph is generated
- THEN every path through it is sandbar, coast, 3–5 islands from the mid/far chains, then the final approach (6–8 islands)

### Requirement: Ending selection
When a run ends on land or by `devuelto`, the game SHALL select an ending from flags in priority order: `devuelto` (whole party captured on the final crossing) → `el_nino` (Yunior alive) → `solo` (exactly one survivor, any party size) → `todos` (at least one companion met; all met companions and NPC allies alive) → `los_que_llegamos` (any other outcome). Survivors are the players and companions who reach land. Each ending has a handwritten scene with slots filled by who is present.

#### Scenario: Todos
- GIVEN Ramón came along, Caridad's lamp was lit, Dayana and Papo are alive, Yunior was never met
- WHEN the party reaches land
- THEN the `todos` ending plays with Ramón, Dayana and Papo on the beach and Caridad in the credits

#### Scenario: Lone balsero
- GIVEN a 1-player run in which no companion was met
- WHEN the player reaches land
- THEN there is 1 survivor and the `solo` ending plays

#### Scenario: Solo player brings a companion
- GIVEN a 1-player run in which Dayana was met and is alive
- WHEN the player and Dayana reach land
- THEN there are 2 survivors and the `todos` ending plays with Dayana on the beach

#### Scenario: Solo player loses a companion
- GIVEN a 1-player run in which Dayana and Papo were met and Papo died
- WHEN the player and Dayana reach land
- THEN there are 2 survivors and the `los_que_llegamos` ending plays

#### Scenario: Last survivor of a party
- GIVEN a 4-player run in which 3 players died and no companion is with the last player
- WHEN that player reaches land
- THEN there is 1 survivor and the `solo` ending plays

### Requirement: Keepsakes
Keepsakes SHALL unlock per `docs/GAME_DESIGN.md` §14, persist in `user://profile.cfg`, and be chosen (max 2) at run start. In co-op each player brings their own.

#### Scenario: Choosing keepsakes
- GIVEN a profile with three unlocked keepsakes in `user://profile.cfg`
- WHEN a run starts
- THEN the player can choose at most 2 of them

### Requirement: Difficulty baseline
Run 1 SHALL use full difficulty: no drain reductions, full patrol rate, no tutorial beyond the intro.

#### Scenario: First run
- GIVEN a new profile
- WHEN run 1 starts
- THEN meters drain at full rate, patrols run at full rate, and no tutorial plays after the intro

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

#### Scenario: Bank cap
- GIVEN a player with 11 banked Experiencia points
- WHEN the party reaches two more islands
- THEN the player has 12 banked points

### Requirement: NPC memory
Important NPCs SHALL read carried trust and greet returning players differently (`returning: true` in the AI context; handwritten variants for minor NPCs).

#### Scenario: Returning player
- GIVEN carried trust with an important NPC from a previous run
- WHEN a player talks to that NPC in the new run
- THEN the AI context includes `returning: true`

### Requirement: Seeds and dailies
Players SHALL be able to enter a seed; the daily run uses the UTC date. Seeded runs do not unlock keepsakes.

#### Scenario: Seeded run
- GIVEN a run started from an entered seed
- WHEN a keepsake's unlock condition is met
- THEN the keepsake is not unlocked

### Requirement: Challenges
Challenge toggles (no fire, storm season, sinking raft, patrols everywhere) SHALL modify generation and rules, and are recorded on the run summary.

#### Scenario: No-fire challenge recorded
- GIVEN a run with the no fire challenge on
- WHEN the run ends
- THEN the run summary records the no fire challenge

### Requirement: Run summary
On death or ending, a summary SHALL show islands reached, days survived, companions saved and lost, texts found, and the cause of death with its Cuban one-liner.

#### Scenario: Death summary
- GIVEN the party dies
- WHEN the summary shows
- THEN it lists islands reached, days survived, companions saved and lost, texts found, and the cause of death with its Cuban one-liner

### Requirement: Devuelto
A `devuelto` ending (every living player captured on the final crossing) SHALL end the run as a loss: it counts as a death, so it adds one Experiencia level and persists the death carry-over (50%), and it is not a win, so no levels are removed. It SHALL unlock the Devuelto keepsake (docs/GAME_DESIGN.md §13; its name and effect are still open), except in a seeded run.

#### Scenario: Solo player returned
- GIVEN a 1-player run at Experiencia level 2 that earned 40 fishing XP, on an unseeded run
- WHEN the final patrol captures the player and `devuelto` plays
- THEN the profile is at level 3, carries 20 fishing XP, and has the Devuelto keepsake unlocked

### Requirement: Solo last stand from Experiencia
For a player with no other living player (a 1-player run, or the last one alive), the downed-timer rewards SHALL lengthen the solo last-stand window that survival-meters defines: 0 s base, +5 s per Experiencia level and +10 s with the downed-timer boost. The Medalla de la Caridad revive goes with this window but fires at 0 health before it starts (survival-meters), so it works on run 1 too. (Changes docs/GAME_DESIGN.md §14.)

#### Scenario: Run 1 solo
- GIVEN a new profile with Experiencia level 0 and no boosts
- WHEN a 1-player run starts
- THEN the player's last-stand window is 0 s

#### Scenario: Eased solo
- GIVEN a profile at Experiencia level 4 that bought the +10 s downed-timer boost
- WHEN a 1-player run starts
- THEN the player's last-stand window is 30 s

### Requirement: Cause of death on the run summary
The run summary SHALL show one row per player: the name and fate, then for a player who died their cause (survival-meters "Cause ids", or `removed`) with a Cuban one-liner for it, then one tip line that stays empty and hidden until something sets it. Each row's entry SHALL carry the cause as the field `cause`, empty for a survivor, whose row shows the route they left by and no one-liner. Solo shows the one row; co-op shows living players in peer order, then removed players in removal order.

#### Scenario: A solo death by thirst
- **GIVEN** a 1-player run with run seed 0
- **WHEN** the player dies of thirst and the summary shows
- **THEN** the one row reads "Balsero: Murió (sed)", its entry's `cause` is `thirst`, its one-liner is line `death_thirst_1` and its tip line is hidden and empty

#### Scenario: Every player's fate in co-op
- **GIVEN** a run with run seed 0 in which Balsero died of thirst, a reef shark killed Dayana while she was downed, and Papo was removed after a disconnect
- **WHEN** the summary shows
- **THEN** the rows read "Balsero: Murió (sed)", "Dayana: Murió (Tiburón de arrecife)" and "Papo: Murió (desconexión)", in that order, with the one-liners `death_thirst_1`, `death_reef_shark_1` and `death_removed_1`

#### Scenario: A survivor
- **GIVEN** a player who left the coast cay by raft
- **WHEN** the summary shows
- **THEN** their row reads "Balsero: Sobrevivió (se fue en: Balsa)", their `cause` is empty and no one-liner shows

### Requirement: Death one-liners
The death one-liners SHALL be content: one DEATH_LINES dialogue, `game/resources/dialogue/death_one_liners.tres`, with one state per cause id and 20 lines (thirst 4, drowning 4, reef_shark 4, land_crab 2, removed 3, other 3), each in Spanish with an English translation that keeps the slang, and a soft variant where it swears. A cause with no lines uses the `other` lines. Changing a line is a content edit. Solo and co-op read the same lines.

#### Scenario: The content check
- **GIVEN** the shipped content
- **WHEN** the content is validated
- **THEN** there are no problems, the 20 lines split by cause as listed, every line has Spanish and English of at most 120 characters, and every line that swears has a soft variant

#### Scenario: A creature without lines
- **GIVEN** a cause `barracuda` with no lines of its own and run seed 0
- **WHEN** its one-liner is picked
- **THEN** it is `death_other_1`

### Requirement: One-liner picked by the run seed
A cause SHALL pick its one-liner from the run seed: the n-th player (counting from 0) in the summary with that cause gets line number (run seed + n) modulo the cause's line count, so two players with one cause get different lines while there are enough. The host rolls a new run seed at every run start and sends it with the world state, so every peer, a late joiner included, shows the same line. With 1 player the first player of a cause is n = 0.

#### Scenario: Pinned by the seed
- **GIVEN** run seed 5 and four thirst lines
- **WHEN** one player dies of thirst
- **THEN** the one-liner is `death_thirst_2`

#### Scenario: Two players with one cause
- **GIVEN** run seed 0
- **WHEN** two players die of thirst
- **THEN** the first in the summary gets `death_thirst_1` and the second `death_thirst_2`

#### Scenario: The same line on every peer
- **GIVEN** a host and a client in a run with run seed 7
- **WHEN** the client joins
- **THEN** the client's world state has run seed 7, so both summaries pick the same lines

### Requirement: Run summary totals
The run summary SHALL show islands reached (the islands the party stood on this run, the sandbar being 1), days survived (the day the clock showed when the run ended, starting at 1), how long the run lasted, companions saved and lost, and texts found. Until companions and found texts exist (npcs-dialogue), both read "ninguno". A joiner shows the host's island count. 1 player and co-op show the same totals.

#### Scenario: A first day on the sandbar
- **GIVEN** a 1-player run that ends on the sandbar on day 1 after 3 minutes
- **WHEN** the summary shows
- **THEN** it reads "Islas: 1", "Días: 1", a length of 3:00, "Compañeros: ninguno" and "Textos: ninguno"

#### Scenario: After the coast cay
- **GIVEN** a 1-player run that reached the coast cay and ends on day 2
- **WHEN** the summary shows
- **THEN** it reads "Islas: 2" and "Días: 2"

#### Scenario: A joiner on the coast cay
- **GIVEN** a host on the coast cay
- **WHEN** a client joins
- **THEN** the client counts 2 islands reached

### Requirement: Restart from the summary
A 1-player run summary SHALL offer "Otra vez", which starts a fresh solo run at once (offline, with no title or lobby in between), beside "Volver al inicio". A co-op summary, host or client, offers only "Volver al inicio", and a client's summary stays on screen when the host leaves.

#### Scenario: The solo buttons
- **GIVEN** a 1-player run that has ended
- **WHEN** the summary shows
- **THEN** "Otra vez" has the focus and "Volver al inicio" sits beside it

#### Scenario: The host leaves after the run
- **GIVEN** a client on its run summary
- **WHEN** the host goes back to the title
- **THEN** the client's summary stays, says the host closed the game, offers only "Volver al inicio", and that returns to the title

### Requirement: A fresh run starts clean
A run started from the summary SHALL start as a run from the title does: full meters and no cause of death, day 1 at 06:00, calm with nothing warned, the sandbar with its own pick-ups and creatures, no crossings, removed players or waiting riders, a new run seed and 1 island reached. Nothing from the run before stays. This is tested with 1 player.

#### Scenario: Solo again
- **GIVEN** a 1-player run that reached the coast cay, ended on day 2 and left a crossing shark circling
- **WHEN** the player picks "Otra vez"
- **THEN** a run starts on the sandbar on day 1 at 06:00, calm, with full meters and no cause, no crossing, only the sandbar's own creatures, a new run seed and 1 island reached

#### Scenario: Drowned mid-crossing, then again
- **GIVEN** a 1-player run that ended when the rider drowned while the crossing still ran
- **WHEN** the player picks "Otra vez"
- **THEN** no crossing is left and the new run is on the sandbar
