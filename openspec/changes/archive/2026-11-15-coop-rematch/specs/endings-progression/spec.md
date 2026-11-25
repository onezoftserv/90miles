## ADDED Requirements

### Requirement: Rematch from a co-op summary
A co-op host's summary SHALL offer "Otra vez", with the focus, beside "Volver al inicio". It takes every player still connected to the lobby of a new run, with no one joining again (coop-networking "Rematch with the same party"). A client's summary shows the note "Esperando al anfitrión…" instead. A host alone gets the same "Otra vez" and a lobby with only themselves; a solo run keeps its own "Otra vez" ("Restart from the summary").

#### Scenario: The co-op buttons
- **GIVEN** a host and a client whose run has ended
- **WHEN** their summaries show
- **THEN** the host's offers "Otra vez", with the focus, beside "Volver al inicio", and the client's offers only "Volver al inicio" with the note "Esperando al anfitrión…"

#### Scenario: A host alone again
- **GIVEN** exactly 1 player hosting, with nobody joined, whose run has ended
- **WHEN** they pick "Otra vez"
- **THEN** the lobby shows with them alone and "Empezar viaje", on the port they already opened

## MODIFIED Requirements

### Requirement: Restart from the summary
A 1-player run summary SHALL offer "Otra vez", which starts a fresh solo run at once (offline, with no title or lobby in between), beside "Volver al inicio". A co-op host's summary offers "Otra vez" too ("Rematch from a co-op summary"); a client's offers only "Volver al inicio", and a client's summary stays on screen when the host leaves.

#### Scenario: The solo buttons
- **GIVEN** a 1-player run that has ended
- **WHEN** the summary shows
- **THEN** "Otra vez" has the focus and "Volver al inicio" sits beside it

#### Scenario: The host leaves after the run
- **GIVEN** a client on its run summary
- **WHEN** the host goes back to the title
- **THEN** the client's summary stays, says the host closed the game, offers only "Volver al inicio", and that returns to the title

### Requirement: A fresh run starts clean
A run started from the summary SHALL start as a run from the title does: full meters and no cause of death, day 1 at 06:00, calm with nothing warned, the sandbar with its own pick-ups and creatures, no crossings, removed players or waiting riders, a new run seed and 1 island reached. Nothing from the run before stays, on the host or on any client of a rematch. This is tested with 1 player, and with a host and a client.

#### Scenario: Solo again
- **GIVEN** a 1-player run that reached the coast cay, ended on day 2 and left a crossing shark circling
- **WHEN** the player picks "Otra vez"
- **THEN** a run starts on the sandbar on day 1 at 06:00, calm, with full meters and no cause, no crossing, only the sandbar's own creatures, a new run seed and 1 island reached

#### Scenario: Drowned mid-crossing, then again
- **GIVEN** a 1-player run that ended when the rider drowned while the crossing still ran
- **WHEN** the player picks "Otra vez"
- **THEN** no crossing is left and the new run is on the sandbar

#### Scenario: The party again
- **GIVEN** a host and a client whose run ended on day 2 with a player removed
- **WHEN** the host picks "Otra vez" and then "Empezar viaje"
- **THEN** on both peers the run is on the sandbar on day 1 with full meters, no removed player, 1 island reached and the same new run seed, different from the old one
