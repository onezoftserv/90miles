## ADDED Requirements

### Requirement: The raft's prompt shows its state
A built raft's launch prompt SHALL add a line with its integrity and maximum as this peer has them ("Balsa 90/120"), then, when it has fittings, a line with their Spanish names ("Clavazón · Toldo"). While its integrity is below half its maximum, it adds the raft's warning line from the HUD text file. The warning never refuses a launch. Solo the same.

#### Scenario: Solo at a worn raft
- **GIVEN** a solo player beside the coast cay's beached raft at 48 of 100 with no fittings
- **WHEN** the HUD is drawn
- **THEN** the prompt reads "[E] Zarpar en la balsa", its lines read "Balsa 48/100" and the raft's warning line, and holding E for 1 s still launches the raft

#### Scenario: A fitted raft
- **GIVEN** a solo player beside a beached raft at 90 of 120 with the clavazón and a toldo
- **WHEN** the HUD is drawn
- **THEN** its lines read "Balsa 90/120" and "Clavazón · Toldo", and no warning line shows

### Requirement: Raft work list
Pressing interact at a built raft's work point with no job open SHALL open the raft's list where the crafting list opens: the raft's state line (and its fittings' line when it has any), then every known mend and fitting recipe by Spanish name, with carried/needed counts as on the workbench list. A row the raft cannot take now (at its maximum, a fitting it has) is dimmed, and choosing it shows a Spanish reason and sends nothing; another starts that job. Solo the same.

#### Scenario: Solo opens the raft's list on the coast cay
- **GIVEN** a solo player at the work point of a beached raft at 48 of 100 with no fittings, carrying 4 nails, 1 driftwood and 1 rope
- **WHEN** they press E
- **THEN** the list's head reads "Balsa 48/100", its rows read "Clavazón", "Defensas", "Remiendo" and "Toldo", and with "Clavazón" highlighted it shows "4/4 Clavos"

#### Scenario: A whole raft refuses a mend
- **GIVEN** a solo player at the work point of a raft at 100 of 100
- **WHEN** they choose "Remiendo"
- **THEN** "La balsa está entera." shows, nothing is sent and the list stays open

#### Scenario: A fitting it already has
- **GIVEN** a solo player at the work point of a raft with a toldo
- **WHEN** they choose "Toldo"
- **THEN** "La balsa ya lo tiene." shows, nothing is sent and the list stays open

#### Scenario: A client starts a mend
- **GIVEN** a host and a client, the client's player at the work point of a beached raft at 50 of 100
- **WHEN** the client chooses "Remiendo"
- **THEN** the host opens the mend on the raft and both peers show it

### Requirement: Raft jobs in the prompt
While a raft has an open job, its work point's prompt SHALL name the job and add the build-site lines (inventory-hud "Build site prompt"): a "Falta:" line for each missing input, then the shared progress bar. Interact there deposits and works as at a build site. Every peer, joiners included, reads the same state. Solo the same.

#### Scenario: Solo mend missing its rope
- **GIVEN** a solo player who opened a mend on the raft and carries 1 driftwood and no rope
- **WHEN** they press E at the work point
- **THEN** the driftwood is deposited, the prompt reads "[E] Trabajar en Remiendo" and its line reads "Falta: Soga x1"

#### Scenario: A joiner reads a half-done fitting
- **GIVEN** a host whose raft's toldo has every input in and half its work done
- **WHEN** a client joins and stands at the work point
- **THEN** the client's prompt shows the bar at 50 % and no "Falta:" line
