## MODIFIED Requirements

### Requirement: Run summary
On death or ending, a summary SHALL show islands reached, days survived, companions saved and lost and texts found once there are any to count ("Run summary totals"), and for each player the cause of death with its Cuban one-liner, or for a survivor the route they left by with theirs. Islands reached never counts the secret cay, solo or co-op. (Counts islands as docs/GAME_DESIGN.md §2 "Run length" does.)

#### Scenario: Death summary
- GIVEN the party dies
- WHEN the summary shows
- THEN it lists islands reached, days survived, and the cause of death with its Cuban one-liner, and companions and texts only if there are any

#### Scenario: The cay is not listed as an island
- GIVEN a 1-player run that reached island 4, visited the secret cay, and died on island 5
- WHEN the summary shows
- THEN it lists 5 islands reached

### Requirement: Cause of death on the run summary
The run summary SHALL show one row per player: the name and fate, then a Cuban one-liner (for a player who died, the one for their cause, survival-meters "Cause ids" or `removed`; for a survivor, the one for the route they left by, "Survivor one-liners"), then one tip line that stays empty and hidden until something sets it. Each row's entry SHALL carry the cause as the field `cause`, empty for a survivor, whose row shows the route they left by. Solo shows the one row; co-op shows living players in peer order, then removed players in removal order.

#### Scenario: A solo death by thirst
- **GIVEN** a 1-player run with run seed 0
- **WHEN** the player dies of thirst and the summary shows
- **THEN** the one row reads "Balsero: Murió (sed)", its entry's `cause` is `thirst`, its one-liner is line `death_thirst_1` and its tip line is hidden and empty

#### Scenario: Every player's fate in co-op
- **GIVEN** a run with run seed 0 in which Balsero died of thirst, a reef shark killed Dayana while she was downed, and Papo was removed after a disconnect
- **WHEN** the summary shows
- **THEN** the rows read "Balsero: Murió (sed)", "Dayana: Murió (Tiburón de arrecife)" and "Papo: Murió (desconexión)", in that order, with the one-liners `death_thirst_1`, `death_reef_shark_1` and `death_removed_1`

#### Scenario: A survivor
- **GIVEN** a 1-player run with run seed 0 whose player left the coast cay by raft
- **WHEN** the summary shows
- **THEN** their row reads "Balsero: Sobrevivió (se fue en: Balsa)", their `cause` is empty and their one-liner is line `arrival_raft_1`

### Requirement: Run summary totals
The run summary SHALL show islands reached (the islands the party stood on this run, the sandbar being 1), days survived (the day the clock showed when the run ended, starting at 1) and how long the run lasted. Companions saved and lost show only while either is above 0, and texts found only while above 0; until npcs-dialogue adds companions and found texts, neither line shows. A joiner shows the host's island count. 1 player and co-op show the same totals.

#### Scenario: A first day on the sandbar
- **GIVEN** a 1-player run that ends on the sandbar on day 1 after 3 minutes
- **WHEN** the summary shows
- **THEN** it reads "Islas: 1", "Días: 1" and a length of 3:00, and shows no "Compañeros" or "Textos" line

#### Scenario: After the coast cay
- **GIVEN** a 1-player run that reached the coast cay and ends on day 2
- **WHEN** the summary shows
- **THEN** it reads "Islas: 2" and "Días: 2"

#### Scenario: A joiner on the coast cay
- **GIVEN** a host on the coast cay
- **WHEN** a client joins
- **THEN** the client counts 2 islands reached

#### Scenario: Companions to count
- **GIVEN** a 1-player summary with 1 companion saved and none lost
- **WHEN** it shows
- **THEN** it reads "Compañeros: 1 salvados, 0 perdidos" and shows no "Textos" line

## ADDED Requirements

### Requirement: Run summary heading
The run summary's heading SHALL follow the local player's own fate: "Llegaste" when this player left by a route and is alive, "Fin del viaje" when they died or were removed. In co-op each peer reads its own player's fate, so a party where some made it shows "Llegaste" to them and "Fin del viaje" to the others. Solo reads its one player.

#### Scenario: A solo arrival
- **GIVEN** a 1-player run whose player left the coast cay by raft
- **WHEN** the summary shows
- **THEN** its heading reads "Llegaste"

#### Scenario: A solo death
- **GIVEN** a 1-player run whose player died of thirst
- **WHEN** the summary shows
- **THEN** its heading reads "Fin del viaje"

#### Scenario: A split party
- **GIVEN** a host who left by raft and a client who drowned
- **WHEN** their summaries show
- **THEN** the host's reads "Llegaste" and the client's "Fin del viaje", and both list the same rows

### Requirement: Survivor one-liners
The survivor one-liners SHALL be content: one SURVIVOR_LINES dialogue (`survivor_one_liners.tres`) with one state per route id and an `other` state, each line in Spanish with an English translation that keeps the slang and a soft variant where it swears. A route with no lines uses `other`. Lines are picked as death one-liners are ("One-liner picked by the run seed"), counting survivors of the same route. Changing a line is a content edit.

#### Scenario: The content check
- **GIVEN** the shipped content
- **WHEN** the content is validated
- **THEN** there are no problems, the survivor lines have states `raft`, `binoculars_swim` and `other`, each with at least 2 lines, every line has Spanish and English of at most 120 characters, and every line that swears has a soft variant

#### Scenario: Two survivors on one raft
- **GIVEN** run seed 0 and a host and a client who both left by raft
- **WHEN** the summaries show
- **THEN** the first row's one-liner is `arrival_raft_1` and the second's `arrival_raft_2`, on both peers

#### Scenario: A route without lines
- **GIVEN** run seed 0 and a solo player who left by a route with no lines of its own
- **WHEN** the summary shows
- **THEN** their one-liner is `arrival_other_1`

### Requirement: No skipping the summary
For 0.8 s after the run summary shows, its buttons SHALL take no press from the keyboard, the gamepad or the mouse. The focus already sits on the first button, and presses made meanwhile are dropped, not kept for later. After that the buttons work as "Restart from the summary" says. Solo and co-op are the same.

#### Scenario: A held A button
- **GIVEN** a solo player, offline, holding the gamepad A button when they die
- **WHEN** the summary shows and they let go of A 0.3 s later
- **THEN** nothing is picked, the summary stays, and "Otra vez" keeps the focus

#### Scenario: After the delay
- **GIVEN** a solo summary shown 1 s ago
- **WHEN** the player presses Enter
- **THEN** a fresh solo run starts
