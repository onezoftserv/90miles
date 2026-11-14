# Design

## Context

Every file and line cited here was checked read-only at `main` 528e2a5.

**Today's transport**
- `NetPeers` (`game/scripts/net/net_peers.gd`) is the only place that creates the transport:
  - `ENetMultiplayerPeer` in `create_server`, `create_client` and `bound_port`;
  - `DEFAULT_PORT` 7777;
  - `MAX_PLAYERS` 4.
- The `NetManager` autoload (`game/scripts/autoload/net_manager.gd`):
  - installs the peer in `_use()`, with `server_relay = false`;
  - uses `OfflineMultiplayerPeer` for solo;
  - reports `hosted(port)`, `joined`, `join_failed` and `host_lost`.
- Gameplay networking is transport-agnostic: `@rpc`, `MultiplayerSynchronizer`, and `CoopSession`'s join handshake by `PlayerIdentity`.

**What blocks a platform backend**
- **Join order.** `GameShell._join()` (game_shell.gd:187-200) builds the run and calls `session.start()` as soon as `NetManager.join()` returns.
  - `CoopSession.start()` (coop_session.gd:192) and `CreatureSpawner._begin()` (creature_spawner.gd:54-59) branch on `multiplayer.is_server()`.
  - That is true on the offline peer.
  - So a joiner whose platform join is still pending would act as host.
- **Failures.** `join_failed` carries no reason. It only shows if a `JoinScreen` happens to be up (game_shell.gd:203-207).
- **ENet-shaped pieces:**
  - the `hosted(port)` signal;
  - the address-only join screen;
  - the lobby note's literal "7777" (lobby_screen.tscn:44), even when `GameShell.port` differs;
  - `IP.get_local_addresses()` in the shell (game_shell.gd:180).
- **Leaving.** `leave()` only swaps the peer, so a platform lobby would stay open.
- **No outside joins.** There is no entry point for invites or launch-time joins.

**Research** (2026-11-14 workflow; sources in the change's PR description)
- **Steam:** GodotSteam's `SteamMultiplayerPeer` is a drop-in `MultiplayerPeer` for Godot 4.
  - Joining is asynchronous, through a lobby.
  - Its client never reports a failed connect, so the game needs a join timeout of its own.
  - Before 4.24, a client could claim peer 1.
  - It has no player cap of its own.
- **Epic Online Services:** the EOSG plugin covers desktop and Android with a P2P peer, and it does not fragment packets.
- **Consoles:** Switch and PS5 ports go through licensed porters (W4 Games lists Godot 4.4–4.6). Their networking sits behind a custom `MultiplayerPeerExtension` over the platform SDK.
- **Platform rules:** every platform adds sign-in, privilege and online-service checks that a join flow must be able to report.

**Owner decisions, 2026-11-14 (option dialogs)**
- Build the seam now with ENet only, and keep the Steam backend in v2, as decided on 2026-11-08.
- Core UI only.

## Goals / Non-Goals

**Goals:**
- A platform backend (Steam, EOS, a console) plugs in as one script plus one data row, with no edit to `NetManager` or to gameplay.
- Hosting and joining may finish later without a pending joiner ever acting as host.
- Failures carry a reason, shown in Spanish first.
- An ENet player sees nothing new beyond the real port in the lobby note and a `--connect=` launch argument.
- Solo stays exactly the offline peer, with zero backend calls, and works when the platform is broken.
- No existing test file is edited. CI on Linux needs no SDK.

**Non-Goals:**
- No Steam, EOS, WebRTC or console backend, and no GDExtension, export preset or `steam_appid.txt`.
- No invite button, platform join view, `set_joinable`/open slots, kick hook or session browser (owner: core UI only).
- No change to `coop_session.gd`, any `@rpc` or transfer mode, the spawners, the synchronizers, `PlayerNet`, `PeerLimits`, `RateLimiter`, `IdentityRegistry`, `NetHarness` or `coop_playground.gd`.
- `NetPeers.MAX_PLAYERS` and `DEFAULT_PORT` are not moved; test_look_slots.gd:227-230 pins their literal lines.
- No platform identity, achievements, rich presence, DTLS, version handshake, UPnP or NAT traversal.
- No new autoload and no `core-services` delta. No ui-shell "Title screen" delta: art-pass owns a pending delta on it until PR #40 archives it.

## Interface

All code is GDScript with static typing. `NetManager` keeps the core-services rule: no `const`, `enum`, `preload`, inner class or `@export` (test_core_services.gd:70-82). Every enum lives in a non-autoload class.

```gdscript
class_name NetFailure extends RefCounted          # enum holder only
enum Reason { NONE, UNREACHABLE, TIMED_OUT, FULL, NOT_FOUND, CANCELLED, UNSUPPORTED,
	PLATFORM_UNAVAILABLE, NOT_SIGNED_IN, NO_PRIVILEGE, PORT_UNAVAILABLE, HOST_LEFT, INVALID_TARGET }

class_name NetJoinTarget extends RefCounted       # opaque "where to join"
var address: String; var port: int; var token: String; var label: String
static func at_address(host_address: String, host_port: int) -> NetJoinTarget   # label "address:port"
static func with_token(platform_token: String, shown_label: String) -> NetJoinTarget
func is_address() -> bool

class_name NetHostInfo extends RefCounted         # what the host's lobby shows
var port: int                                     # 0 when the backend has none
var addresses: PackedStringArray                  # ENet: LAN IPv4; empty elsewhere

class_name NetRequest extends RefCounted          # one attempt; also the cancel token
enum Kind { HOST, JOIN }
enum State { PENDING, READY, FAILED, CANCELLED }
signal answered(request: NetRequest)              # backend -> NetManager only
signal settled(request: NetRequest)               # once, when it leaves PENDING; READY after install
var kind: Kind; var state: State; var reason: NetFailure.Reason; var reason_args: Array
var port: int; var target: NetJoinTarget; var info: NetHostInfo; var peer: MultiplayerPeer
func succeed(offered: MultiplayerPeer, host_info: NetHostInfo = null) -> void  # first answer only; closes the peer if not pending
func fail(why: NetFailure.Reason, args: Array = []) -> void                     # first answer only; NONE -> UNSUPPORTED
func cancel() -> void; func settle(final_state: State) -> void; func is_pending() -> bool

class_name NetBackend extends RefCounted          # safe defaults; never touches `multiplayer`
signal join_requested(target: NetJoinTarget)      # an invite or platform "join game", any time
var profile: NetBackendProfile
func start(_args: PackedStringArray) -> NetFailure.Reason      # NONE; anything else refuses host/join, never solo
func check_target(_target: NetJoinTarget) -> Error             # ERR_INVALID_PARAMETER
func host(request: NetRequest, _port: int) -> void             # must succeed() or fail() exactly once
func join(request: NetRequest) -> void
func leave() -> void                                           # leaves the platform session; never closes the peer
func launch_target(_args: PackedStringArray) -> NetJoinTarget  # null
func poll(_delta: float) -> void                               # every frame, also while paused

class_name EnetBackend extends NetBackend         # answers inside every call, through NetPeers
const LAUNCH_FLAG: String = "--connect="

class_name NetBackendProfile extends Resource     # one row of net_backends.tres
@export var id: StringName
@export_file("*.gd") var backend_script: String   # a path: loaded only when chosen
@export var feature_tag: String                   # "" never auto-picks
@export_range(0.0, 60.0, 0.5) var join_timeout_s: float   # 0 = the transport's own
@export var lobby_note: PackedStringArray         # [es, en]; "%d" = the port opened

class_name NetBackendTable extends Resource
const PATH: String = "res://resources/net_backends.tres"
@export var default_id: StringName = &"enet"
@export var profiles: Array[NetBackendProfile]
@export var failure_texts: Dictionary[NetFailure.Reason, PackedStringArray]   # [es, en]
static func load_shipped() -> NetBackendTable; static func enet_only() -> NetBackendTable
func pick(has_feature: Callable) -> NetBackendProfile
func create(chosen: NetBackendProfile) -> NetBackend    # EnetBackend if the script is missing or wrong
func failure_text(reason: NetFailure.Reason, args: Array = [], locale: String = "es") -> String
func lobby_note(chosen: NetBackendProfile, port: int, locale: String = "es") -> String
```

**`NetManager`:**
- **Kept:** `hosted(port)` (0 when the backend has no port), `joined`, `join_failed` with zero arguments, `host_lost`, `host()`, `join()`, `start_solo()`, `leave()`, `is_online()`, `_use()` and `_on_server_disconnected()`.
- **New signals:**
  - `host_failed`: a late host failure;
  - `outside_join_requested(target)`.
- **New state:** `backend`, `table`, `last_failure`, `last_failure_args` and `startup_failure`.
- **New methods:**
  - `request_host(port) -> NetRequest` and `request_join(target) -> NetRequest`;
  - `pending_request()`, `host_info()` and `backend_profile()`;
  - `failure_text()` and `lobby_note()`;
  - `take_outside_join()`;
  - `use_backend(next, args)`, for tests; `null` restores the startup choice.
- **Processing:** `process_mode = PROCESS_MODE_ALWAYS`. `_process` calls `backend.poll()` and runs the join watchdog.

**Fixed ordering, pinned by spec and tests**
- **When a request is made:**
  1. Refuse first, with nothing changed: a startup failure, or a target that `check_target` rejects.
  2. `_go_offline()`.
  3. Reset `last_failure`.
  4. Set `_request`.
  5. Call `backend.host()` or `backend.join()`.
  6. For a profile that sets a timeout, start the join watchdog.
- **When a peer answers** (`_on_answered`):
  1. A cancelled or stale request: close the peer and stop.
  2. Otherwise `_use(peer)`.
  3. For a host, store the info and emit `hosted`.
  4. `settle(READY)`.
- **A failure inside the call:** set `last_failure` and settle FAILED, with no signal; the caller reads the return value.
- **A failure later:**
  1. Settle FAILED.
  2. `_go_offline()`, which calls `backend.leave()`.
  3. Set `last_failure`.
  4. Emit `host_failed` or `join_failed`.

**`GameShell`:**
- **Kept, because tests pin it:** `@export var port`, `start_host()`, `_join(address, join_port)`, `_on_host_lost()` and the `join_failed` listener.
- **New methods:** `_join_target(target)`, `_continue(request)`, `_on_hosting()`, `_on_joining()`, `_on_host_failed()`, `_on_outside_join()` and `_take_outside_join()`.
- **Removed:** `IP.get_local_addresses()` leaves the shell.

**`JoinScreen`** gains `show_failed(text = FAILED)` and `show_connecting(label)`.

**`LobbyScreen`:**
- gains `OPENING = "Abriendo la partida…"` and `show_opening()`;
- `local_addresses()` forwards to the new `NetPeers.lan_addresses(all)`.

## Decisions

**D1. `NetRequest` is both the answer and the cancel token.**
- `request_host` and `request_join` return READY, PENDING or FAILED.
- A pending request settles once.
- Leaving, going solo or asking again cancels it, and a peer delivered for a cancelled request is closed.
- *Rejected:*
  - Bare re-entrant signals (`host_ready`, `join_ready`) emitted inside the call. Every caller would have to set its state beforehand, the handlers would run inside `NetManager`, and the names aren't past tense.
  - Signals carrying payloads.

**D2. The run is built only in the step that installs the peer, and `_end_run()` runs before every request.**
- ENet's join order changes from "build, then connect" to "connect, then build". Both still happen in one call with no frame between, so the session exists before SceneMultiplayer polls the first packet. The host path already works this way (game_shell.gd:162-167).
- `_end_run()` first keeps the rule "freed at once, before the peer is closed" (game_shell.gd:321-323).
- *Rejected:* building under the offline peer and starting later. `CreatureSpawner._begin` and `SandbarIsland._on_weather_changed` (sandbar_island.gd:227) would act as host.

**D3. One continuation, two triggers.**
- The shell calls `_continue(request)` directly on READY, and connects it to `settled` on PENDING.
- ENet and slower backends therefore share one success path, and no shell handler runs inside `NetManager`'s call.

**D4. `NetManager` changes are additive, and `join_failed` keeps zero arguments.**
- The reason goes in `last_failure`.
- The shell falls back to `JoinScreen.FAILED` with no reason, so test_lobby_screen.gd:97's bare emit and coop_playground.gd:118 stay as they are.
- *Rejected:*
  - a `NetFailure` payload;
  - a line for NONE, which would hide a missing reason.

**D5. Capabilities are code; tuning and text are data.**
- `net_backends.tres` sits at the top of `res://resources`, beside `hud_text.tres`, so `ContentCatalog.unregistered_folders()` (content_catalog.gd:102-110) sees no new folder.
- Backend scripts are referenced by path and loaded only when picked. smoke.gd:15 loads every `.tres`, and with it every Script ext_resource.
- Lines are [es, en] pairs read with `HudText.pick`.
- *Rejected:*
  - `Script` exports;
  - a `resources/net/` folder;
  - Spanish-only strings;
  - capability flags as data.

**D6. Fake the platform, not the transport.**
- `FakeNetBackend` (tests only) scripts:
  - deferral by frames;
  - refusals with reasons;
  - a start failure;
  - a lobby directory of token to ENet port;
  - invites and late delivery.
- It does this over real ENet-localhost peers from `NetPeers`.
- One contract suite runs against both `EnetBackend` and the fake.
- *Rejected:* a GDScript `MultiplayerPeerExtension` loopback. It is unverified and would test a transport nobody ships.

**D7. Solo is exactly `OfflineMultiplayerPeer`.**
- A fresh solo run makes no backend call.
- The `is OfflineMultiplayerPeer` checks stay as they are (coop_session.gd:480; game_shell.gd:268, 316, 419).
- *Rejected:* a global `NetManager.is_solo()`. NetHarness branches have their own SceneMultiplayer, and test_pause.gd:114 needs "hosting alone is not solo".

**D8. The join watchdog is per profile, and 0 for ENet.**
- It counts from the request until `connected_to_server`.
- It exists because GodotSteam's client never reports a failed connect.
- *Rejected:* a global 15 s cap. It would change ENet's failure timing and text.

**D9. Outside joins start at once only from menu screens; otherwise they wait for the title.**
- A host that is still opening shows the lobby in its "Abriendo la partida…" state, not a held title. The title rewrites its description on focus (title_screen.gd:38-39, 54-55), and its buttons would stay live.
- Interrupting a lobby or a run needs a dialog. That belongs to the Steam change (Q3 below).

**D10. The session's four-player cap is the authority.**
- ENet keeps `create_server(port, MAX_PLAYERS - 1)`, and `CoopSession._add_player` keeps its check (coop_session.gd:1074-1077).
- A platform lobby's member limit is advisory and at least as large. Otherwise a dropped player inside the 90 s window could lose the reclaim.

**D11. `server_relay` stays false for every backend.**
- This matches `NetManager._use` and coop-networking.
- The GodotSteam tutorial turns the relay on. That is rejected; the spawners and synchronizers with relay off become a verify task in the Steam change.

**D12. `NetPeers` keeps every constant and function.** It only gains `lan_addresses()`, and its doc comment now calls it the ENet peer factory behind `EnetBackend` and the tests.

**D13. The backend is chosen by build feature tag only; no `--net=` override yet.** `CoopPlayground.parse_args` passes unknown arguments to its panel (coop_playground.gd:52-53). The override comes with the second backend.

**D14. Signals carry the request instead of a bound copy.** A callable bound to a RefCounted and stored in that object's own signal would be a reference cycle and leak.

**D15. Platform UI stays narrow (owner, 2026-11-14: core only).**
- The outside-join route is real on ENet through `--connect=`.
- The lobby's opening state is reachable only through the fake in v1.

## Reference games

None of Shattered Pixel Dungeon, Brogue CE or DCSS has peer co-op, matchmaking, invites or NAT traversal, so these are structural analogues only. Ideas, no code.

**Borrowed**
- **Brogue CE, `src/platform/platform.h` `struct brogueConsole`:** a required core plus optional slots, where having the operation is the capability (`platformdependent.c` checks `currentConsole.notifyEvent`). Here: `NetBackend`'s safe defaults, and capabilities in code.
- **Brogue CE, `main.c`:** sets `currentConsole` in one place. Here: `NetManager._ready` with `NetBackendTable.pick`.
- **Brogue CE, `null-platform.c` `nullConsole` and `web-platform.c`:**
  - a no-op headless backend. Here: the offline peer for solo, and ENet on loopback for tests.
  - networking as just another backend behind the same interface.
- **SPD, `SPD-classes/.../watabou/utils/PlatformSupport.java`:** safe defaults injected through the `Game` constructor. Here: base defaults, and `use_backend` injection in tests.
- **SPD, `services/.../updates/UpdateService.java` `UpdateResultCallback`:** asynchronous results with an explicit failure path. Here: `NetRequest` READY or FAILED with a reason.
- **SPD, `Updates.java` (`supportsUpdates()`, the service may be null) and the build-time `UpdateImpl` choice:** no service is a normal state, and the implementation is picked per build. Here: solo needs no backend, and the backend is picked by feature tag.
- **DCSS, `webserver/webtiles/ws_handler.py`:**
  - `start_crawl` picks the handler at one point.
  - `CrawlWebSocket.on_message` accepts input only from the player's socket. This confirms that host-authoritative checks stay above the transport.
- **DCSS, `tileweb.cc` `TilesFramework::_send_everything`:** a full snapshot goes to the new peer only. This confirms that the existing `request_join` → `receive_lobby` path fits any backend.

**Deferred**
- DCSS `process_handler.py` `lobby_entry()`, for a session browser if the owner ever wants one.
- DCSS `_send_version`, for a version check in the handshake.
- Brogue's `--server-mode` style override, which becomes `--net=` with the second backend.

**Rejected**
- DCSS's `USE_TILE_WEB` `#ifdef`s scattered across `menu.cc`, `ui.cc` and `libunix.cc`. `test_transport_seam.gd` enforces this rejection.
- SPD's grab-bag `PlatformSupport` plus `DeviceCompat`. `NetBackend` stays transport-only: no identity, achievements or store.
- DCSS's app-level ping (`reset_timeout`, `check_connection`). Only the per-profile join watchdog exists.
- Brogue's hand-packed byte protocol (`web_notifyEvent`). Godot's RPC already serialises.

## Player flow and strings

Menus stay standard Spanish. Status and failure lines are system messages, so they are also standard Spanish.

**Solo, hosting and joining**
- **Jugar solo:** straight to a run on the offline peer, with no backend call. It works with the platform missing or broken.
- **Hospedar partida:** with ENet it looks exactly as it does today.
  - The lobby note now names the port actually opened: "Los demás se unen por IP en el puerto UDP %d. Por internet, abre ese puerto en tu router."
  - If the port is taken, the title stays and says "No se pudo abrir el puerto %d.".
  - With a slower backend:
    - The lobby opens with "Abriendo la partida…" and only Salir, which cancels.
    - A late failure returns to the title with the reason's line.
    - Pressing "Hospedar partida" again while a request is pending does nothing.
- **Unirse:** the join screen is unchanged.
  - On failure it shows the reason's line and stays open.
  - "Volver" cancels a join still under way.
- **Outside join** (`--connect=` in v1): on the title, settings, credits or an idle join screen, the join screen opens already connecting. The field shows the target's label and cannot be edited.

**Failure lines** in `net_backends.tres`, as [es, en] pairs. NONE and CANCELLED have no line.

| Reason | es | en |
|---|---|---|
| UNREACHABLE | No se pudo conectar. | Could not connect. |
| TIMED_OUT | El anfitrión no respondió. | The host did not answer. |
| FULL | La partida está llena. | The game is full. |
| NOT_FOUND | Esa partida ya no existe. | That game no longer exists. |
| UNSUPPORTED | Esta versión del juego no puede hacer eso. | This version of the game cannot do that. |
| PLATFORM_UNAVAILABLE | La plataforma en línea no está disponible. | The online platform is not available. |
| NOT_SIGNED_IN | Inicia sesión en la plataforma para jugar en línea. | Sign in to the platform to play online. |
| NO_PRIVILEGE | Tu cuenta no puede jugar en línea. | Your account cannot play online. |
| PORT_UNAVAILABLE | No se pudo abrir el puerto %d. | Could not open port %d. |
| HOST_LEFT | Se perdió la conexión con el anfitrión. | The connection to the host was lost. |
| INVALID_TARGET | Esa dirección no sirve. | That address is not valid. |

## Risks / Trade-offs

**ENet's join order changes** (D2). The run is now built just after the client peer is installed, not just before, in the same call.
- Build-time code already defers anything role-dependent (creature_spawner.gd:48-51), and `as_client` gates the host-only work.
- Guards:
  - test_shell_sky's client tests;
  - the pending-joiner test;
  - the manual mid-run creature-count check.

**Re-entrancy.** ENet answers inside `backend.host()`/`join()`, so `NetManager` installs the peer inside `_on_answered`. The order is fixed (install, then `hosted`, then settle), and the shell acts only after the call returns or on `settled`.

**Global state leaking between suites.** A swapped backend, kept outside joins and the fake's static lobby table can all leak.
- Every new suite asserts `NetManager.backend is EnetBackend` in `before_all` and `after_all`.
- In `after_each` it calls `leave()`, then `use_backend(null)`, then `FakeNetBackend.reset()`.

**The core-services rule.** test_core_services rejects any constant or enum on `NetManager`. The enums live in `NetFailure` and `NetRequest`, and the table path lives in `NetBackendTable.PATH`.

**Smoke compiles every script.** A future `steam_backend.gd` must never write `Steam` or `SteamMultiplayerPeer`. That is the build-verification requirement.

**The asynchronous path runs only on the fake in CI.**
- Steam peers cannot connect to themselves, so the contract suite doubles as the two-machine checklist for the Steam change.
- CI cannot catch:
  - transfer modes;
  - relay behaviour;
  - lobby ownership moving;
  - peer-id reuse.

**`NetManager` gains `_process` and `PROCESS_MODE_ALWAYS`.** The cost is negligible.

**`--connect=`** lets a launched game join any ENet host. That is the same exposure as typing an IP.

**Merge neighbours.** Sibling changes in flight touch other requirements, so nothing collides:
- dropped-teammate-state: coop-networking "Disconnect handling", escape-routes "Split parties", ui-shell "Teammate state word";
- structure-state-sync: three ADDED coop-networking requirements;
- secret-cay: coop-networking "Difficulty scaling";
- art-pass: ui-shell "Title screen".

**Archive-time hand edit.** The coop-networking Purpose line "…over ENet." becomes "…through a platform backend (ENet by default).". It is not a requirement, so no delta can carry it.

## Deferred to the Steam change (v2)

**`steam_backend.gd`**
- GodotSteam GDExtension 4.24 or later, on stock 4.7.2 templates.
- No `Steam` identifier anywhere in it.
- What it does:
  - `start()`: `steamInitEx`.
  - `poll()`: `run_callbacks`.
  - Hosting: a FRIENDS_ONLY lobby of `MAX_PLAYERS`, then `create_host(0)`.
  - Joining: `joinLobby`, then `create_client(owner, 0)`.
  - Join requests: `join_requested` and `join_game_requested` go to `join_requested(target)`.
  - `+connect_lobby` gives the launch target.
  - `leave()`: `leaveLobby`, and clearing rich presence.

**Data:** a profile row with feature_tag "steam", join_timeout_s 15, and a Spanish lobby note.

**Platform UI and session hooks:**
- an "Invitar amigos" button and the platform join view;
- `set_joinable`/open slots;
- a `peer_closed` session signal for lobby bookkeeping;
- `--net=`;
- a ui-shell "Title screen" delta with per-backend texts, once art-pass is archived.

**Two-machine verify list:**
- the relay off with spawners and synchronizers;
- losing peer 1 gives `server_disconnected`;
- no client is promoted when lobby ownership moves;
- a reconnect gets a new peer id;
- kicked members don't keep a slot.

**Open questions for that change** (recommended answer first, not asked yet):
- **Q3. An invite accepted while in a lobby or a run.**
  - (a) Ask "¿Dejar esta partida y unirte a %s?", pausing a solo run while asking.
  - (b) Keep it with a notice.
  - (c) Keep it silently.
- **Q4. Steam is not running in a Steam build.**
  - (a) Stay on Steam with "La plataforma en línea no está disponible."; solo still works.
  - (b) Fall back to ENet.
  - (c) Ask the player.
- **Q5. `submit_intent` is `unreliable_ordered`, which Steam and EOS make reliable.**
  - (a) A small change before any Steam playtest: send intents unreliable and drop stale `seq` on the host. Tie it to the open ENet throttle follow-up.
  - (b) Accept reliable delivery.
  - (c) Measure first.
- **Q6. The development app id.**
  - (a) 480 (Spacewar) with a unique lobby tag until playtests.
  - (b) Buy the game's own App ID now.
- **Q7. How friends find a game.**
  - (a) Friends-only lobbies plus invites.
  - (b) Invite-only.
  - (c) Public lobbies with an in-game list.

**After Steam:**
- **EOS:** sign-in in `start()`, and chunk large join RPCs, since EOSG does not fragment packets.
- **Consoles:** privilege checks and suspend/resume through a separate narrow interface.
