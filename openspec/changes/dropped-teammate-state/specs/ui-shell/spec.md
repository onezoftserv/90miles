## ADDED Requirements

### Requirement: Teammate state word
In co-op, a teammate's row SHALL end with one state word, the first that applies: "Muerto" when their meters say dead, "Desconectado" while their client is disconnected and their body waits, "Caído" when they are downed, else none. The word for a given teammate is the same on the host, on every client and on a client that joined later. Solo has no teammate rows.

#### Scenario: A dropped teammate on a client
- **GIVEN** a host and two clients, Dayana and Papo, in a run
- **WHEN** Papo's client disconnects
- **THEN** Papo's row reads "Desconectado" on the host's HUD and on Dayana's, not "Caído"

#### Scenario: A late joiner sees the same word
- **GIVEN** Papo's client disconnected and his body waits on the sandbar
- **WHEN** another client joins the run during his 90 s
- **THEN** Papo's row on the joiner's HUD reads "Desconectado"

#### Scenario: Back from a drop
- **GIVEN** Papo's client disconnected and Dayana's HUD shows his row as "Desconectado"
- **WHEN** Papo joins again within 90 s from the same install
- **THEN** Papo's row on Dayana's HUD and on the host's shows no state word, and if his meters had him downed it reads "Caído"

#### Scenario: Dead comes first
- **GIVEN** Papo's client disconnected and his body waits
- **WHEN** his meters kill him before he is removed
- **THEN** his row reads "Muerto" on every peer

#### Scenario: Solo has no rows
- **GIVEN** a solo run, offline
- **WHEN** the HUD is shown
- **THEN** there is no teammate row and no state word anywhere
