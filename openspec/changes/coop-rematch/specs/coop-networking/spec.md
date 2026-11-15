## ADDED Requirements

### Requirement: Rematch with the same party
A co-op host's rematch SHALL start a new run with every client still connected, on the connections they already have. The host opens a new lobby. Each connected client ends its run and sends its join request again with the same name and player id, so the host knows each player as before. Nobody reconnects and the port stays open. Solo has no rematch: its "Otra vez" starts a solo run at once (endings-progression "Restart from the summary").

#### Scenario: Two players again
- **GIVEN** a host Yuni and a client Papo, both on their run summaries
- **WHEN** Yuni picks "Otra vez"
- **THEN** both lobbies list Yuni (anfitrión) and Papo, Papo's client opened no new connection, and the host knows Papo by the same player id as in the run that ended

#### Scenario: A client still in its run
- **GIVEN** a host whose run has ended and a client whose summary has not shown yet
- **WHEN** the host picks "Otra vez"
- **THEN** the client's run ends and its lobby shows, as everyone's does

#### Scenario: The host starts at once
- **GIVEN** a host who picks "Otra vez" and then "Empezar viaje" before a client's join request has arrived
- **WHEN** that join request arrives
- **THEN** the client joins the new run under way with its HUD, as any joiner does

#### Scenario: A client that never asks again
- **GIVEN** a host who picked "Otra vez"
- **WHEN** a connected client sends no join request for 10 s
- **THEN** the host disconnects it, as it does any peer that never asks to join

#### Scenario: Solo again
- **GIVEN** exactly 1 player, offline, whose run has ended
- **WHEN** they pick "Otra vez"
- **THEN** a solo run starts at once with no lobby, and nothing is sent over the network

### Requirement: Rematch is the host's call
Only the host SHALL start a rematch. A rematch message from anyone else is ignored, and a client's summary never offers one. Only clients connected when the host starts it follow it. A client that left before, or a dropped player still waiting out their 90 s, is not brought back; they can join the new lobby as anyone joins.

#### Scenario: A rematch message not from the host is ignored
- **GIVEN** a host and a client on their run summaries
- **WHEN** a rematch message reaches the client from anyone but the host, or reaches the host itself
- **THEN** nobody's run ends and every summary stays

#### Scenario: A client who left is not pulled back
- **GIVEN** a host and two clients, Papo and Dayana, on their run summaries
- **WHEN** Dayana picks "Volver al inicio" and the host then picks "Otra vez"
- **THEN** the new lobbies list only the host and Papo, and Dayana stays on her title screen

#### Scenario: A dropped player joins later
- **GIVEN** a client who dropped during the run and whose body still waited when the run ended
- **WHEN** the host picks "Otra vez" and that player joins the host again from the join screen
- **THEN** they join the new lobby as a new joiner

### Requirement: Rematch message order
In a rematch, the host's old run SHALL be gone on every client before anything of the new run reaches that client, so each client receives the new island whole: the same pick-ups, creatures, sites and structures as the host. What a client's old run sent before it ended is ignored by the host's new run: no player spawns from it and nothing changes. No peer logs an engine error during a rematch.

#### Scenario: The new island is whole on the client
- **GIVEN** a host and a client after a rematch
- **WHEN** the client's lobby shows and the host starts the run
- **THEN** the client's sandbar has the same pick-ups and creatures as the host's, and neither peer logged an engine error

#### Scenario: An old message reaches the new lobby
- **GIVEN** a client whose old run sent movement and actions just before the host's rematch
- **WHEN** those messages reach the host's new lobby
- **THEN** the host ignores them: no body spawns and no state changes
