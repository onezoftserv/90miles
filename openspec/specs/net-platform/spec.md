# net-platform Specification

## Purpose
How 90 Millas reaches other players: one platform backend behind the `NetManager` autoload hosts, joins, leaves and reports joins from outside the game, with requests that may finish later, can be cancelled and fail with a reason. ENet is the default and only backend in v1; solo asks the backend for nothing.

## Requirements

### Requirement: Platform backend
The game SHALL reach other players only through one active platform backend, which hosts, joins, leaves its platform session and reports join requests from outside the game, and hands the game a multiplayer peer without ever setting one itself. ENet is the default and the only backend shipped: it hosts on a UDP port (7777 by default) and others join by IP. Solo uses no backend: it runs on the offline peer, asks the backend for nothing, and works even when the backend failed to start.

#### Scenario: ENet by default
- **GIVEN** a build with no platform feature tag
- **WHEN** the player hosts from the title
- **THEN** the session listens on UDP port 7777 over ENet, and a client joins it by IP

#### Scenario: Solo without a platform
- **GIVEN** exactly 1 player, offline, and a backend that failed to start and refuses to host and to join
- **WHEN** the player picks "Jugar solo"
- **THEN** a run starts with one player on the offline peer, no network port is open, and the backend received no host, join or leave call

#### Scenario: Transport stays in the seam
- **GIVEN** the game's scripts under `res://scripts` and `res://scenes`
- **WHEN** the seam scan runs
- **THEN** no script outside `res://scripts/net/` names `ENetMultiplayerPeer` or a platform peer class, calls `NetPeers.create_server`, `NetPeers.create_client` or `NetPeers.bound_port`, or calls `IP.get_local_addresses`

### Requirement: Backend choice
The backend SHALL be chosen once at startup from `game/resources/net_backends.tres`: the first listed backend whose build feature tag is present, otherwise the table's default (ENet). A backend's script is loaded only when it is chosen, and an unreadable table or script falls back to ENet. Adding a backend is a new profile and script, with no edit to `NetManager` or gameplay. Solo is the same whichever backend is chosen.

#### Scenario: CI picks ENet
- **GIVEN** the shipped table and no platform feature tag
- **WHEN** the game starts
- **THEN** the active backend is ENet and it started with no failure

#### Scenario: A platform build picks its backend
- **GIVEN** a table with a profile tagged "steam"
- **WHEN** the backend is chosen once with "steam" present and once with it absent
- **THEN** the first choice is that profile and the second is ENet

### Requirement: Hosting and joining may finish later
A host or join request SHALL answer at once as ready (the peer is installed), pending, or failed. The run and its session are built only in the step that installs the host or client peer, never while the offline peer stands in for a pending request, and a run already on is ended before the peer changes. With 1 player, solo never waits on a request.

#### Scenario: A pending joiner is never the host
- **GIVEN** a backend that answers a join 5 frames after the request
- **WHEN** the player connects from the join screen
- **THEN** until the client peer is installed no island or session exists, no creature spawns and the player is in no roster, and afterwards the session runs as a client

#### Scenario: ENet answers at once
- **GIVEN** the ENet backend
- **WHEN** the player hosts, or connects to an address
- **THEN** the request is ready before it returns, with the server or connecting client peer installed

### Requirement: What a request changes
A host or join request refused before the backend is asked (the backend failed to start, or it refuses the target) SHALL change nothing; any other request first ends the current connection and cancels a pending one, so a failure from the backend leaves the game offline. A caller that needs the answer at once is told it succeeded only when the peer is installed, and a request still pending is cancelled for it. Solo makes no request, so none of this touches it.

#### Scenario: A refused target changes nothing
- **GIVEN** a host on ENet with its server open
- **WHEN** a join to a blank address is requested
- **THEN** the request fails as an invalid target and the host's server stays installed

#### Scenario: A backend failure leaves the game offline
- **GIVEN** a host on ENet with its server open, and another UDP port already taken
- **WHEN** it asks to host on the taken port
- **THEN** the request fails with "port unavailable", the first server is closed and the game is offline

#### Scenario: A caller that cannot wait
- **GIVEN** a backend that answers a host or a join 3 frames after the request
- **WHEN** hosting or joining is asked through a call that answers at once
- **THEN** the call does not report success, the request is cancelled, the game is offline, and the peer the backend delivers later is closed

### Requirement: Cancelling a pending request
Leaving, going solo or a new host or join request SHALL cancel a pending host or join request, make the backend leave its platform session, and return to the offline peer; a peer the backend delivers for a cancelled request is closed and never installed. With 1 player, going solo always cancels any request.

#### Scenario: Going solo during a pending join
- **GIVEN** exactly 1 player whose join is still waiting on the backend
- **WHEN** they go back and pick "Jugar solo"
- **THEN** the solo run is on the offline peer, and a peer the backend delivers later is closed, not used

#### Scenario: Asking again
- **GIVEN** a pending host request
- **WHEN** host is requested again through NetManager
- **THEN** the first request is cancelled and only the second can install a peer

### Requirement: Join timeout
A backend's profile SHALL be able to set a join timeout: a join that has not reached the host in that time fails as timed out and the game goes offline. ENet sets none and keeps its own transport timeout and wording. Solo has no join to time out.

#### Scenario: A join nobody answers
- **GIVEN** a backend whose profile sets a 15 s join timeout and which never answers
- **WHEN** 15 s pass
- **THEN** the join fails as timed out, the game is offline, and the join screen says "El anfitrión no respondió."

### Requirement: Failure reasons
Every failed host or join SHALL carry one reason (unreachable, timed out, full, not found, platform unavailable, not signed in, no privilege, port unavailable, host left, invalid target or unsupported). Screens show the reason's line from `net_backends.tres`, Spanish first with English beside it, never text from the platform; a failure with no reason shows "No se pudo conectar.". Solo cannot fail this way.

#### Scenario: ENet wording kept
- **GIVEN** UDP port 7777 already taken on the machine
- **WHEN** the player picks "Hospedar partida"
- **THEN** the title stays and its panel says "No se pudo abrir el puerto 7777."

#### Scenario: Full session
- **GIVEN** a backend that refuses a join because the session is full
- **WHEN** the player joins
- **THEN** the join screen says "La partida está llena." and the game is offline

#### Scenario: Every reason has a line
- **GIVEN** the shipped table
- **WHEN** each reason other than none and cancelled is looked up
- **THEN** it has a non-empty Spanish line and an English line

### Requirement: Join requests from outside the game
An invite, a platform "join game" or a launch argument SHALL start joining at once when the player is on the title, settings, credits, or a join screen with no join under way; otherwise the latest request is kept and taken the next time the title shows, and a lobby or a run is never interrupted. ENet reads the launch argument `--connect=<address[:port]>`, port 7777 by default. With 1 player, a request from outside never ends a solo run.

#### Scenario: Launch argument joins
- **GIVEN** the game started with `-- --connect=127.0.0.1:7780`
- **WHEN** the title shows
- **THEN** the join screen shows "127.0.0.1:7780" with "Conectando…" and the run is built as a client

#### Scenario: Request during a solo run
- **GIVEN** exactly 1 player in a solo run
- **WHEN** a join request from outside the game arrives
- **THEN** the run goes on offline with no backend call, and after "Volver al inicio" the join starts

#### Scenario: Request on the title
- **GIVEN** the title screen
- **WHEN** a join request from outside the game arrives
- **THEN** the join screen opens already connecting, showing the request's label

### Requirement: Every backend keeps the session contract
Every backend's peers SHALL keep the contract the session relies on: the host is peer 1; a client gets an id of 2 or more, new on every connection, so a reconnect is a new peer and reclaiming by player identity works; the host's `disconnect_peer` closes that client; the host closing reaches every client as a lost host. NetManager keeps the server relay off for every backend. The session's four-player cap stays the authority. Solo is exactly the offline peer, so none of this applies to it.

#### Scenario: Two peers through a backend
- **GIVEN** two multiplayer branches using the same backend
- **WHEN** one hosts and the other joins it
- **THEN** the host is peer 1 and the client is 2 or more

#### Scenario: The relay stays off
- **GIVEN** the ENet backend or a slower one
- **WHEN** NetManager installs a host or client peer it answered with
- **THEN** the server relay is off

#### Scenario: A reconnect is a new peer
- **GIVEN** a connected client
- **WHEN** it closes and joins again
- **THEN** it gets an id it did not have before

#### Scenario: The host closing is a lost host
- **GIVEN** a connected client
- **WHEN** the host closes its peer
- **THEN** the client reports the host as lost
