## ADDED Requirements

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
