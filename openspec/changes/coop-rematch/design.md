# Design

## Context

See proposal.md, "Why". The files below were read at `main` 9b90289 on 2026-11-14.

**How a run is built today**
- `GameShell` (`game/scenes/shell/game_shell.gd`) builds one run at a time in its World: an island and a `CoopSession`, the session named `CoopSession` under `WorldView/Viewport/World`.
  - `_build_run()` frees the old run first (`_end_run()`, with `free()`, not `queue_free()`), so the new session gets the same name and path.
  - The host or solo rolls the run seed into `world_state` and calls `island.furnish(session)` and `island.place_pickups(session)` straight away, so the pick-up and entity spawners send as soon as the session is built.
- `_on_hosting()` and `_on_joining()` wire a session to the installed peer. `_continue()` calls them once a `NetRequest` is READY (net-platform-seam, #51).
  - Neither asks NetManager for anything.
  - A client's `CoopSession.start()` sends its join request at once when its peer is already connected (`coop_session.gd`, `start()`).
  - A host's `start(true)` treats peers that connected before it as new: each gets the 10 s join timeout (`_awaiting`), and each joins the roster when its `request_join` arrives.
- `IdentityRegistry` is per session, so a new session claims each id as NEW.
- Look slots are given at spawn by `_free_look_slot()`: the lowest slot no body holds.
- The summary (`_check_run_over`) offers "Otra vez" only in solo (`_restart_solo`, which goes offline and starts a solo run). A client keeps its summary when the host leaves (`_on_host_lost`).

**Engine facts that decide the order** (Godot `4.7.2-stable`, `modules/multiplayer/`, read 2026-11-14)
- `SceneCacheInterface::get_cached_object` first tries the object it stored for a path id. If that object is gone, it resolves the stored path again and keeps the new node. So an RPC aimed at a freed session reaches whatever node now sits at that path.
- A new node at an old path gets a new path id (`last_send_cache_id` only grows), which is announced again.
- `SceneReplicationInterface::on_spawn_receive` resolves the spawner by path when the spawn arrives.
- `on_despawn_receive` logs an error (`!pinfo.recv_nodes.has(net_id)`) for a net id the receiver no longer has.
- `_untrack` erases the net id of a remote node the receiver freed itself.
- Unreliable synchronizer packets are sent only after a reliable spawn, or after a path the receiver has confirmed.

**Spike** (two real shells in one process, each on its own `SceneMultiplayer` branch; throwaway code, not in the tree)
- **Host frees its run, calls, then opens its lobby; the client rebuilds inside the call.**
  - No engine error.
  - The client's lobby lists both players.
  - The client's sandbar has 20 of 20 pick-ups and 5 of 5 creatures.
  - The look slots and the identity carry over, and the client gets the new seed.
- **Host opens its lobby first, then calls:** the client had 0 of 20 pick-ups. They landed in its old session and were freed with it.
- **A client still in its run when the host calls, and the host starts at once:** the client got the run with no HUD. `_enter_run()` returns early when the flow is already RUN.

## Goals / Non-Goals

**Goals:**
- A co-op rematch on the connections the party already has, built by the same code that builds a run from the title. A rematch's run is then as clean as a first run by construction.
- No packet of either side's new run is handled by the other side's old run.
- No engine error on any peer.
- Solo stays exactly as it is.

**Non-Goals:**
- A ready check or vote (owner Q2 option C, not chosen).
- Rematch for a client whose host is gone.
- Keeping anything across runs: Experiencia and keepsakes are not built yet.
- Seeding islands from `run_seed` (island-generation; `TASKS.md` §4).
- A host kick (REFERENCE_DST "Server settings, admin and votes" borrows one, in its own change).

## Decisions

**D1. Rebuild the run, don't reset it in place.**
- The host and every client free their run and build a new one with `_build_run()`, `_on_hosting()` and `_on_joining()`, as a run from the title is built.
- Rejected: resetting the session in place (clear the bodies, entities, run record, travel, island and serials). Every per-run field would need its own reset, and one missed would leak the old run into the new one ("A fresh run starts clean").
- The `TASKS.md` line also asked for "every client rebuilding its session".

**D2. The call lives on a small node outside the session (owner Q4, option A).**
- `RunRematch` (`game/scripts/net/run_rematch.gd`) is the shell's child, named `Rematch`. It has:
  - the host's `call_party()`;
  - one RPC, `begin`: `@rpc("authority", "call_remote", "reliable")`, which returns unless the receiver is a client and the sender is peer 1;
  - a `called` signal.
- The session is what the rematch replaces, so the call must travel on a node that exists on both sides, before and after. The shell is the main scene at the same path everywhere (and named alike in the test harness).
- This is the one RPC outside `CoopSession`, whose header calls itself "the one RPC hub". That hub is per run; this message sits between runs.
- Rejected alternatives:
  - **The host's old session calls before it is freed.** The client would handle the call and free its run, and the old run's despawns arriving afterwards would hit the `on_despawn_receive` error for every body, pick-up and creature.
  - **The host's new session calls** (it would reach the client's old session by path). Its spawns are queued before the call, and the spike lost every pick-up.
  - **An RPC on GameShell itself.** The shell has no RPCs today, and a separate node keeps the sender checks testable alone.
- No new autoload.

**D3. The host's order: free, call, open.**
On "Otra vez", the host runs four steps in one frame:
1. Note each connected player's look slot (D6).
2. Free its run (`_end_run()`). The old run's despawns go out on the reliable channel.
3. `RunRematch.call_party()`, on the same reliable channel, after the despawns.
4. Build and start the new session in the lobby (`_on_hosting()`). Its spawns, path announcements and clock come after the call.

ENet delivers one reliable channel in order. The new run's unreliable synchronizer packets wait for a spawn or a confirmed path, both of which come after the call (see Context). The port, the NetRequest and the backend are untouched. The new seed comes from `seed_source`, as for any run.

**D4. The client rebuilds inside the call, not deferred.**
- `GameShell._on_rematch_called()` runs in the call's own handling. It ignores the call when there is no session or when this peer is the server. Then it:
  - frees the run (`_end_run()`);
  - builds and starts the new client session on the same peer (`_on_joining()`), which sends the join request at once;
  - shows its lobby straight away.
- Deferring it would let the packets after the call, which are the new run's spawns, land in the old session within the same poll.
- Freeing during the poll is safe here. The call runs on `RunRematch`, not on the session being freed. `host_lost` is different: the session emits it itself, so the shell defers there.
- Showing the lobby at once takes the client out of `Flow.RUN`. If the host starts at once, `lobby_received(true)` then enters the run with its HUD (the spike's third case). Until the host answers, the lobby's list is empty. A newer screen replaces it when `lobby_received` arrives.

**D5. Old client messages reaching the host's new run.**
- A client's old run may have sent messages just before it handled the call. The path cache delivers them to the host's new session by path.
- Each one is already refused, with no change needed:
  - intents: no body in the lobby;
  - actions: `_acting_body` is null;
  - a site's state: `_allow_request` has no limits for a peer in the lobby;
  - quick chat: no body;
  - a route: no body.
- A test sends each kind into a rematch lobby.

**D6. Looks are kept by peer id.**
- Nobody reconnects, so every peer id survives the rematch, and a guest (a player with no valid identity) keeps their slot too.
- The host's old session hands over `look_slots()`: the peer → slot map of the host and every connected peer with a body. The shell gives it to the new session's host-only `carried_looks` before `start()`.
- In `_add_player` a peer with a kept slot gets it, unless a body holds it. `_free_look_slot()` skips slots kept for peers that are still connected and not spawned yet. A kept slot of a peer that disconnects becomes free.
- Only the function that gives the slot changes. `request_join` (PR #57) and the intent path (PR #55) are untouched.

**D7. Identity.**
- Each client's new join request carries the same `PlayerIdentity` (from its settings).
- The new session's empty `IdentityRegistry` claims it as NEW, so for the new run the host knows each player by the same id.
- No claim crosses runs. A dropped body of the old run is gone with it, so there is nothing to reclaim.

**D8. Through the lobby (owner Q1, option A).**
- The new session starts in `LOBBY`. The host sees the lobby fill as join requests arrive and presses "Empezar viaje".
- Rejected: starting at once when every kept peer has asked, or after 10 s. A slow client would hold everyone up or be left behind, and the lobby already shows who is aboard.

**D9. What a client sees (owner Q2, option A).**
- A client's summary keeps only "Volver al inicio" and adds the note "Esperando al anfitrión…", the same words as the client's lobby. It uses the existing `Note` label through a new `SummaryScreen.show_waiting_for_host()`. When the host leaves, `show_host_left()` replaces the note's text.
- The host's "Otra vez" has the focus, as in solo. A mistaken press only takes everyone to a lobby they can leave.

**D10. Who may enter the rematch lobby (owner Q3, option A).**
- It is an ordinary lobby: a new friend may join, and so may a player who left, from their join screen.
- Rejected: a lobby closed to anyone outside the old party. It needs a new refusal reason and a join-screen line.

**D11. Solo and a host alone.**
- Solo still goes through `_restart_solo()`. `RunRematch.call_party()` returns false offline, so nothing is sent.
- A host alone (1 player, hosting) takes the co-op path: a new lobby with themselves, on the open port. That is the 1-player test of the co-op path.

### Reference games

- **Shattered Pixel Dungeon**, `windows/WndGame.java`: after death, the "start" button keeps the dead hero's class (`GamesInProgress.selectedClass = Dungeon.hero.heroClass`) and opens `HeroSelectScene` rather than starting at once.
  - *Borrowed:* go back through the selection screen with the old choices filled in. Our lobby shows the same party, and each player keeps their look.
  - *Rejected:* the rankings button beside it. We have no rankings.
- **DCSS**, `end.cc`, `crawl_should_restart()`, with the `restart_after_game` option (`options.h`): when a game ends, the process goes back to the start menu instead of exiting, and keeps the player's name.
  - *Borrowed:* the game process and its connections stay. Nothing is relaunched and no one types an address again.
  - *Rejected:* making it an option. The summary always offers it.
- **Brogue CE**, `MainMenu.c`, `mainBrogueJunction()`: it loops on `rogue.nextGame`, and `NG_NEW_GAME` starts the next game in the same process. `IO.c`'s `NEW_GAME_KEY` asks for confirmation only after 50 turns.
  - *Borrowed:* the shell's flow builds the next run on what is already installed.
  - *Rejected:* a confirmation prompt. A rematch is offered only once the run has ended.
- **Don't Starve Together**, wiki "Death/DST" and docs/REFERENCE_DST.md "When everyone is dead": in Survival, once every player is dead and nobody revives within 120 s, the world is lost and a fresh one is made, while the server stays up.
  - *Borrowed:* the same host and the same people, with a world made fresh.
  - *Rejected:* the 120 s grace. Our downed timer and solo last stand already give a last chance, and the summary waits for a person to choose.
  - Whether DST players stay connected through the reset and pick their character again is not stated on the wiki pages read on 2026-11-14 [unverified].
- **DST**, wiki "Console/Don't Starve Together Commands": `c_regenerateworld()` is a server command. docs/REFERENCE_DST.md "Server settings, admin and votes" notes regenerate votes, which forum threads say get used for griefing [unverified].
  - *Borrowed:* only the host can start again.
  - *Rejected:* votes, as REFERENCE_DST already rejects them.

### Owner decisions (2026-11-14: the owner accepted every recommended option, A for Q1 to Q4)

- **Q1. Lobby or at once?**
  - A: through the lobby; the host presses "Empezar viaje" again (recommended, D8).
  - B: the new run starts by itself once everyone is back, or after 10 s.
- **Q2. What a client sees on its summary while the host decides.**
  - A: only "Volver al inicio", plus the note "Esperando al anfitrión…" (recommended, D9).
  - B: as today, with no note.
  - C: the note plus a "Listo" button whose mark the host sees on its summary.
- **Q3. Who may join the rematch lobby.**
  - A: anyone, as in any lobby (recommended, D10).
  - B: only the party still connected.
- **Q4. Where the host's call lives.**
  - A: a small `Rematch` node under the shell, the one RPC outside `CoopSession` (recommended, D2).
  - B: keep every RPC in `CoopSession` and reset the session in place instead of rebuilding it (D1's rejected alternative: much larger, and every per-run field needs its own reset).

## Risks / Trade-offs

- **[The despawns and the call reach a client in different frames while it is still in its run]** For one frame its HUD could read its despawned body. The despawns and the call are sent in the same host frame and bundled by ENet, so they normally arrive together. A client is almost never still in its run when a person on the host has already picked "Otra vez". → Mitigation if a playtest shows it: free the HUD when the local body leaves the tree.
- **[Two shells in one process share `WeatherManager.sky`]** The client's `receive_sky` applies the state to the same sky, `changed` fires, and the host resends, so clock messages loop while both runs exist. The client's `_end_run()` also stops the shared weather. → The harness tests assert nothing about the client's weather. The two-process run on UDP 7792 is the authority for the full flow.
- **[A client that is joining the old run when the call arrives]** It rebuilds like any client and joins the new lobby. If its old join request reaches the host's new session first, the new session answers it, and the client asks again after the call. The repeat is ignored (`roster.has(sender)`).
- **[Open PRs]** #57 and #55 edit `coop_session.gd`. This change adds `carried_looks`, `look_slots()` and the slot pick, and edits no function they touch. #52 (dead-spectate) does not touch `game_shell.gd` or `summary_screen.gd`; rebase if it lands first.

## Migration Plan

None. Nothing is saved. A rematch only connects peers that already run this build, because the host's call is a new RPC: a client from an older build would log an unknown-method error. Hosts and clients of a LAN party run the same build, as they must already for every RPC.
