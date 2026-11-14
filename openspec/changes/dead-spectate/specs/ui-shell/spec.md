## ADDED Requirements

### Requirement: Spectating a teammate
In co-op, a player whose meters say dead SHALL watch a living teammate instead of their own body: their view follows that teammate's body and stays inside that body's view limits, on the island or on a crossing's sea. A rider waiting on the next island's shore watches the same way until the party lands. The run summary still shows when every player still in the run is dead. Solo has no teammate to watch: a solo death goes straight to the run summary.

#### Scenario: A solo death goes to the summary
- **GIVEN** a solo run, offline, with exactly 1 player
- **WHEN** the player dies
- **THEN** the run summary shows, the view never leaves the player's own body, and no "Mirando a:" line shows

#### Scenario: A dead player watches a teammate
- **GIVEN** a co-op run with Yuni and Papo on the sandbar
- **WHEN** Yuni dies
- **THEN** Yuni's view follows Papo's body and no longer Yuni's own

#### Scenario: Watching a teammate at sea
- **GIVEN** Yuni is dead on the sandbar and Papo rides a raft crossing
- **WHEN** Yuni's view follows Papo
- **THEN** it shows Papo on the crossing's sea and stays inside that sea

#### Scenario: The last teammate dies
- **GIVEN** Yuni is dead and watches Papo, the only player still alive
- **WHEN** Papo dies
- **THEN** the run summary shows on every peer, as it did before this change

#### Scenario: A waiting rider watches the one still playing
- **GIVEN** a 2-player run where Yuni's crossing has ended and Papo still plays on the sandbar
- **WHEN** Yuni waits on the shore
- **THEN** Yuni's view follows Papo under the line "En la orilla. Esperando a: Papo", and it goes back to Yuni's own body when the party lands

### Requirement: Whom a spectator watches
A teammate SHALL be watchable while they are not dead and not waiting out of play on the shore. A disconnected teammate is watchable only while no connected teammate is, and is then marked as disconnected. On death the view goes to the watchable teammate nearest the dead player's body. Solo has no watchable teammate.

#### Scenario: The nearest teammate first
- **GIVEN** a co-op run with Yuni, Papo and Dayana, Dayana standing nearer to Yuni than Papo
- **WHEN** Yuni dies
- **THEN** Yuni's view follows Dayana

#### Scenario: Waiting riders are not watched
- **GIVEN** Yuni is dead, Papo waits on the next island's shore and Dayana still plays on the sandbar
- **WHEN** Yuni's view picks a teammate
- **THEN** it follows Dayana and never Papo

#### Scenario: Only a disconnected teammate left
- **GIVEN** Yuni is dead and the only other player, Papo, has a disconnected client whose body waits on the sandbar
- **WHEN** Yuni's view picks a teammate
- **THEN** it follows Papo's body and the line reads "Mirando a: Papo (desconectado)"

#### Scenario: A connected teammate comes before a disconnected one
- **GIVEN** Yuni is dead, Papo's client is disconnected and Dayana is connected and alive
- **WHEN** Yuni's view picks a teammate
- **THEN** it follows Dayana, and stepping through teammates never reaches Papo while Dayana can be watched

### Requirement: Switching the watched teammate
A spectator SHALL step to the next or previous watchable teammate with the "spectate next" and "spectate previous" actions. These step in the teammate list's order and wrap round. By default the actions are A and D, ← and →, the gamepad's D-pad ← and →, and the mouse wheel. They do nothing for a living player who is not waiting. Solo has nobody to step to.

#### Scenario: Stepping and wrapping
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive; the teammate list reads Dayana, then Papo
- **WHEN** Yuni presses "spectate next" twice
- **THEN** the view follows Papo after the first press and Dayana again after the second

#### Scenario: Stepping back
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive; the teammate list reads Dayana, then Papo
- **WHEN** Yuni presses "spectate previous"
- **THEN** the view follows Papo

#### Scenario: The keys work on a gamepad
- **GIVEN** Yuni is dead and plays with a gamepad
- **WHEN** Yuni presses the D-pad's →
- **THEN** the view steps to the next watchable teammate

#### Scenario: A living player's keys walk
- **GIVEN** a co-op run with Yuni alive on the sandbar
- **WHEN** Yuni presses D
- **THEN** Yuni walks right and the view stays on Yuni's own body

### Requirement: Losing the watched teammate
When the watched teammate dies, is removed, or leaves play, the spectator's view SHALL move to the watchable teammate nearest that teammate's last position. A teammate leaves play by going to wait on the shore. With nobody watchable, the view goes back to the spectator's own body and the line hides. Solo never watches, so it never loses anyone.

#### Scenario: The watched teammate dies
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive
- **WHEN** Dayana dies
- **THEN** Yuni's view follows Papo

#### Scenario: The watched teammate leaves by a route
- **GIVEN** Yuni is dead and watches Dayana, and Papo is alive on the sandbar
- **WHEN** Dayana's crossing ends and she waits on the shore
- **THEN** Yuni's view follows Papo

#### Scenario: The watched teammate is removed
- **GIVEN** Yuni is dead and watches Papo, whose client dropped, and Dayana's crossing has ended
- **WHEN** Papo is removed after his time runs out
- **THEN** Yuni's view never points at a body that is gone: it follows a watchable teammate or goes back to Yuni's own body

### Requirement: The HUD while watching
While a player watches a teammate, the HUD's bottom band SHALL read "Mirando a: <name>" with the keys that switch. The meters panel shows the watched teammate's meters. The inventory strip and the interact prompt are hidden, and quick chat still works. When watching ends, the HUD shows the player's own meters again. The line's text is HUD text data. Solo never shows the line.

#### Scenario: The line and the meters
- **GIVEN** Yuni is dead and watches Papo, whose thirst is 30
- **WHEN** Yuni looks at the HUD
- **THEN** the bottom band reads "Mirando a: Papo" with the switch keys, the thirst bar reads 30, and Yuni's inventory strip is hidden

#### Scenario: Quick chat from the dead
- **GIVEN** Yuni is dead and watches Papo
- **WHEN** Yuni picks a quick-chat phrase
- **THEN** the phrase is said, as it is for a living player

#### Scenario: Back to the own HUD
- **GIVEN** a 2-player run where Yuni waits on the shore and watches Papo
- **WHEN** the party lands on the next island
- **THEN** Yuni's meters panel shows Yuni's meters, the strip shows again and the "Mirando a:" line hides

### Requirement: Spectating on every peer
Spectating SHALL be worked out on each peer from the state it already holds, with nothing sent over the network. It works the same for the host, a client, a client who joined during the run, and a player who took back a body that died while they were away. That last player watches as soon as they are back. Solo has no peer to reach.

#### Scenario: A client watches the host
- **GIVEN** a host, Yuni, and a client, Papo, in a run
- **WHEN** Papo dies
- **THEN** Papo's view follows Yuni with the line "Mirando a: Yuni", and Yuni's view stays on Yuni

#### Scenario: The host watches a client
- **GIVEN** a host, Yuni, and a client, Papo, in a run
- **WHEN** Yuni dies
- **THEN** Yuni's view follows Papo with the line "Mirando a: Papo"

#### Scenario: Back to a dead body
- **GIVEN** Papo's client dropped and his body died during his 90 s, and Yuni is alive
- **WHEN** Papo joins again from the same install within the 90 s
- **THEN** Papo's view follows Yuni at once

#### Scenario: A late joiner who dies
- **GIVEN** Dayana joined a run under way with Yuni and Papo alive
- **WHEN** Dayana dies
- **THEN** her view follows the nearer of Yuni and Papo, and the line names them as the roster does
