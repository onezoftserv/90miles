# Proposal

## Why

The ENet transport is already isolated in `NetPeers`. Everything around it, though, is synchronous and shaped by IP addresses, so a platform backend (Steam, then Epic Online Services for Android, then consoles) can't plug in there without touching gameplay:

- **Join order.** `GameShell._join()` builds the run and starts the session as soon as `NetManager.join()` returns. `CoopSession.start()` and `CreatureSpawner._begin()` check `multiplayer.is_server()`, which is true on the offline peer. So a Steam lobby join still in progress would make the joiner spawn the island's creatures and list itself as host.
- **Failures.** A failure carries no reason, and it only shows if the join screen happens to be up.
- **ENet-shaped pieces:**
  - the `hosted(port)` signal;
  - the address-only join screen;
  - the lobby note hardcoded to "7777";
  - `IP.get_local_addresses()` called in the shell.
- **Leaving** never tells a platform that the player left.
- **Joins from outside the game** (an invite, a launch argument) have no way in.

The owner asked whether the multiplayer approach ports to Steam, Nintendo, Android and PS5 (2026-11-13). On 2026-11-14 they chose to build the seam now, with ENet as the only backend, and to keep the Steam backend itself in v2 as decided on 2026-11-08. They chose the core UI only.

## What Changes

**A platform backend seam under the `NetManager` autoload.** The new classes are not autoloads and live in `game/scripts/net/`:
- `NetBackend`, a base class with safe defaults;
- `EnetBackend`, which wraps the unchanged `NetPeers`;
- `NetRequest`, one host or join attempt, which is both the answer and the cancel token;
- the value types `NetJoinTarget` and `NetHostInfo`;
- `NetFailure`, the failure reasons;
- `NetBackendProfile` and `NetBackendTable`, the data, held in `game/resources/net_backends.tres`. The backend is chosen once at startup by build feature tag, and ENet is the default.

**Hosting and joining may finish later.** A request comes back READY (peer installed), PENDING or FAILED. A request refused before the backend is asked changes nothing; a failure from the backend leaves the game offline.
- The shell builds the run and starts the session only in the step that installs the peer, never under the offline peer standing in for a pending request.
- Leaving, going solo or asking again cancels a pending request. A peer that arrives late is closed, never installed.
- A per-backend join timeout exists; for ENet it is 0, so ENet keeps its own.

**Failure reasons.** Every failed host or join carries a reason, and the screens show that reason's line from data, with Spanish first and English beside it. ENet's wording does not change: "No se pudo abrir el puerto %d." and "No se pudo conectar.". A join failure always shows on the join screen.

**Joins from outside the game.** An invite or a launch argument starts joining at once when the player is on the title, settings, credits, or an idle join screen. At any other moment it waits for the title; a lobby or a run is never interrupted. ENet gains a `--connect=<address[:port]>` launch argument, so this route is real in v1.

**The host's lobby.** It names the UDP port actually opened and takes the host's LAN addresses from the backend. While a slower backend opens the session, the lobby shows "Abriendo la partida…" and only Salir works, which cancels.

**What an ENet player sees.** Nothing else changes. Solo stays exactly the offline peer and makes no backend call. No existing test file is edited.

**Not in this change:**
- no Steam, EOS, WebRTC or console code;
- no SDK or GDExtension;
- no invite button or session browser;
- no new autoload;
- no change to `coop_session.gd`, to any `@rpc`, or to `NetHarness`.

## Capabilities

### New Capabilities

- `net-platform`: how the game reaches other players through one active platform backend: backend choice, asynchronous host and join requests, failure reasons, joins from outside the game, and the multiplayer contract every backend keeps.

### Modified Capabilities

- `coop-networking`: "Host and join". Hosting and joining go through the active backend; with ENet, a port and joining by IP as today.
- `ui-shell`:
  - "Screen flow": the lobby's opening state, host failures on the title, joins from outside the game, and join failures always on the join screen.
  - "Join screen": the connecting mode, the reason's line, and "Volver" cancels.
  - "Lobby": the port actually opened.
- `build-verification`: adds "No platform SDK needed". Import, smoke and GUT pass with no SDK, and backend scripts compile without one.

## Impact

**New code:**
- `game/scripts/net/`: `net_failure.gd`, `net_join_target.gd`, `net_host_info.gd`, `net_request.gd`, `net_backend.gd`, `enet_backend.gd`, `net_backend_profile.gd` and `net_backend_table.gd`.
- `game/resources/net_backends.tres`.

**Changed code:**
- `game/scripts/autoload/net_manager.gd`: additive; every existing member, signal and return code stays.
- `game/scenes/shell/game_shell.gd`.
- `game/scenes/shell/join_screen.gd`.
- `game/scenes/shell/lobby_screen.gd`.
- `game/scripts/net/net_peers.gd`: gains `lan_addresses()`.

**Tests:**
- A new helper, `game/tests/helpers/fake_net_backend.gd`.
- Six new suites:
  - `test_net_backend_table.gd`
  - `test_enet_backend.gd`
  - `test_net_requests.gd`
  - `test_net_backend_contract.gd`
  - `test_transport_seam.gd`
  - `test_shell_platform.gd`
- Every existing test stays unedited and green.

**Docs:** `docs/GAME_DESIGN.md` §17, the Multiplayer row (no numbers change), and `TASKS.md`.

**Unaffected:** gameplay networking, the session, spawners and synchronizers, solo, CI (Linux, no Steam), and the `core-services` set (no new autoload).
