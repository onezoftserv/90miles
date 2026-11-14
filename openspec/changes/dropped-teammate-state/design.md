# Design

## Context

- **Dropping a client.** `CoopSession._on_peer_disconnected` (host) calls `set_downed(true)` on the dropped body and starts a countdown in `_dropped` (peer → seconds, 90 s). `_physics_process` removes the body when the countdown ends. `_reclaim` erases the entry and stands the body up when the same `PlayerIdentity` joins again. `is_dropped(peer)` reads `_dropped`, so it is true only on the host.
- **The HUD row.** `RunHud.state_word(player, dropped)` already ranks "Muerto" > "Desconectado" > "Caído", and `refresh()` passes `session.is_dropped(peer)`. On a client that is always false. The body's `downed` state arrives through `StateSync` (`PlayerNet:net_downed`), so the row reads "Caído".
- **The landing.** `IslandTravel.check()` (escape-routes "Split parties") returns PLAYING while any living body has `left_island == false`. That includes a body in a crossing (`IslandRoutes.has_left` is true and `left_island` is still false) and a dropped body still on the island. It re-runs on `died`, `removal_recorded` and a crossing's end, but not on a drop. The shell's `_check_run_over` also calls `check()` on clients.
- **Arrivals.** `travel()` sends every body as an arrival. `checked_arrivals` refuses more than `MAX_ARRIVALS` = `MAX_PLAYERS` = 4 on every peer, the host included, because `travel_to` is `call_local`. Dropped bodies do not count toward the player cap, so the session can hold four connected bodies plus a dropped one.
- **Coordination.** The `structure-sync` sibling session may edit `coop_session.gd`, so the edits there stay small and inside the functions named below. The coordinating session owns `net_peers.gd`, `net_manager.gd` and the join screen; none of them is touched.

## Goals / Non-Goals

**Goals:**
- One source of truth for "this body is dropped" that every peer reads, late joiners included, and that survives a rebind with no extra handling.
- Waiting riders no longer sit out of play for 90 s because a teammate quit on the island (D3).
- Solo is untouched: one player never drops, and its crossing end loads the next island at once.

**Non-Goals:**
- Showing the seconds left in the row.
- Changing the 90 s, the player cap or the reconnect flow.
- Host migration.
- The flaky reconnect wait in `test_interact_prompt_net.gd` (still open from `art-pass-followups`).

## Decisions

**D1. Reference games: the state word comes from the body; a level change never waits for someone who cannot act.**

Shattered Pixel Dungeon, Brogue CE and DCSS are not networked, so none of them has a "disconnected" state. Their closest ideas come first; Don't Starve Together, which is networked, comes last:

- *Borrowed, Brogue CE, `IO.c` `printMonsterInfo`:* the sidebar shows one status word per creature, taken from a fixed priority chain over the creature's own flags ("(Captive)" before "(Sleeping)" before "(Ally)"). The cause of a state outranks the state itself. We take two things:
  - The word is read from state the body carries, the same on every view.
  - "Desconectado", the cause, outranks "Caído", the state it produces. "Muerto" stays first. `state_word` already ranks them this way; what was missing is the input on clients (D2).
- *Borrowed, Brogue CE, `RogueMain.c` `startLevel`:*
  - On a level change, followers that can move are given `STATUS_ENTERS_LEVEL_IN` from their distance to the stairs.
  - Captive, paralysed and entranced allies are not taken.
  - The level change never waits for an ally.
  - We borrow the principle that the party's departure does not wait on someone who cannot act.
- *Borrowed, DCSS, `mon-transit.cc` `tag_followers` / `_mons_can_follow_player_from` / `handle_followers`:*
  - Only followers that are not incapacitated or held, and are within a short radius of the stairs, travel.
  - The rest stay on the old level, which persists.
  - Our islands do not persist, so "stays behind" can only mean removal (option B), or a removal after a short wait (option A).
- *Rejected, Shattered Pixel Dungeon, `actors/mobs/Mob.java` `holdAllies` / `restoreAllies`:*
  - SPD carries directable allies wherever they are, and intelligent allies within 5 tiles, to the new floor.
  - Carrying a dropped body that took no route (option C) would let a disconnect skip the crossing, the run's tension peak.
- *Rejected, Brogue's delayed arrival* (`STATUS_ENTERS_LEVEL_IN` counting down on the new level), for the same reason.
- *Compared, Don't Starve Together.* The owner added it as a fourth reference on 2026-11-14. It is closed source (Klei), so it was read on the wiki (dontstarve.wiki.gg) only.
  - On disconnect, the leaving player's character leaves the world with them. The "Drop Items on Disconnect" world setting decides whether only its irreplaceable items or everything it carries is dropped on the way out.
  - A dead player becomes a ghost that still moves and haunts. It comes back with 50 health and none of the items it dropped at death. Among the ways to revive it:
    - A living player gives it a Telltale Heart, which costs 25 % of its max health.
    - The ghost haunts a Touch Stone, once per player per stone.
    - The ghost activates the Meat Effigy attuned to it.
  - The world never waits for an absent or dead player. In Survival, when every player is a ghost, a 120 s timer (a server setting) starts and the world resets unless someone is revived first.
  - We share the principle: nobody's absence holds the party, and a bounded timer settles the case where nobody can act.
  - We do not take the instant vanish (option B). Our body stays 30 s so a quick rejoin keeps it, because a crossing cannot be redone.
  - Ghosts and revive items are outside this change. Our downed and revive rules are unchanged.
- No code, data or text copied.
- The 30 s in option A has no reference number. It is our estimate:
  - Godot's ENet peer timeout already lets up to 30 s pass before the host notices a dead connection.
  - A client that crashed and restarts at once needs about that long again to reach the join screen.
  - The owner can change it.

**D2. The dropped flag lives on the body, in `StateSync`.**
- `PlayerNet` gets a host-written shadow field, `net_dropped: bool`, replicated by the player's `StateSync` with `spawn = true` and mode ALWAYS, like every other field (`test_player_state_sync.gd` pins both).
- `CoopSession` writes it in the two places that change `_dropped`: `_on_peer_disconnected` sets it, `_reclaim` clears it. Removal frees the body.
- `is_dropped(peer)` keeps reading `_dropped` on the host, which also owns the countdown, and reads the body's flag on a client.
- A late joiner gets the flag with the spawn state. A reclaimed body carries it under its new peer with no owner-map work.
- *Rejected:* a reliable `player_dropped` / `player_back` RPC plus a dropped list in `receive_lobby`.
  - The list is keyed by peer, so it needs the rebind handling that `waiting` needed in `IslandTravel`.
  - It adds two RPCs and more lines in `coop_session.gd`, where the sibling session works.
- *Rejected:* letting `PlayerNet._write_shadow` derive the flag every frame. The body does not know it is dropped; the session does.

**D3. What a dropped body still on the island does to the landing. This was the owner's decision: they chose option A, the 30 s short hold, on 2026-11-14 through the coordinating session. They kept the waiting-line mark, the re-check on a drop and D5.**

| Option | What happens to the dropped body on the island | Effect |
|---|---|---|
| **A, recommended** | Once dropped bodies are all that keep waiting riders from landing, and no crossing is running, each one's time left is cut to at most 30 s. It is then removed and counts as dead, and the party lands. With nobody waiting, the full 90 s hold. | The wait drops from 90 s to 30 s at most. A crash or a short outage can still come back and play on. No free crossing. |
| B | Removed at once, as soon as it alone holds the landing; counts as dead. Its player may join the next island as a new player. | No wait at all, but a hiccup at the wrong moment costs the body. |
| C | Travels along: it lands with the party, still downed, with its countdown running, and can be reclaimed on the next island. | Kindest, but a disconnect skips the crossing (SPD-style, rejected in D1). |
| D | Today's rule: it holds the landing until removed, up to 90 s. Only the row word is fixed. | No gameplay change; the 90 s wait stays. |

The specs and tasks are written for A, the owner's choice.

**D4. How option A is checked.**
- `IslandTravel.check()` sorts each living body into one of three cases:
  - Waiting: `left_island`.
  - A dropped holder: dropped, not `left_island`, and not `has_left`, so not in a crossing.
  - Playing: anything else.
- Any playing body gives PLAYING, as today. A dropped rider in a crossing has `has_left` and so is playing, which holds the load until its crossing ends.
- Dropped holders with at least one rider waiting:
  - On the host, `check()` calls `session.shorten_drop(peer, DROPPED_HOLD_S)` for each, which caps that peer's countdown at `minf(left, 30)`.
  - It returns PLAYING.
  - The removal fires `removal_recorded`, `check()` runs again, and the party travels.
- Dropped holders with no rider waiting: PLAYING, never OVER, so a drop never ends the run early. This is `ui-shell` "Screen flow" unchanged.
- `IslandTravel` also listens to `session.player_disconnected` (host), so the check runs at the drop.
- On a client, `check()` gives the same answer: dropped holders give PLAYING either way, and `shorten_drop` is host-only.
- `DROPPED_HOLD_S = 30.0` is a const on `IslandTravel`, since the rule belongs to "Split parties". It sits beside `CoopSession.DISCONNECT_DOWNED_S`.

**D5. Arrivals cap: `MAX_ARRIVALS = 2 × MAX_PLAYERS`.**
- `checked_arrivals` and the world state's `waiting` list are sanity bounds on a host message. They are not the player cap.
- Four connected players plus a dropped waiting rider is a legal state, and every peer refuses that landing.
- Doubling covers four connected plus four dropped bodies. More than that needs four drop-and-replace cycles inside 90 s; the landing then waits for removals.
- **Found while applying, 2026-11-14: a refused landing crashed the host.**
  - `_travel_when_idle` cleared `_travel_queued` before calling `check()`.
  - That `check()` queued `_travel_when_idle` again, inside the same deferred-call flush.
  - So a refused `travel_to` (more arrivals than the cap, or an unknown next island) re-ran forever within one frame, sending a reliable RPC on each pass, until the engine crashed with signal 11. The five-body test crashed this way on the old cap.
  - The fix: the flag now drops after the attempt. A refused landing waits for the next change and is tried again then.
  - This is a two-line reorder in `island_travel.gd`, with its own regression test.

**D6. The waiting line.**
- `GameShell.waiting_text(session)` (now static, so tests can read it without a shell) appends " (desconectado)" to the name of a dropped teammate it lists, from `session.is_dropped`, which now works on clients.
- The line is a sentence, so the word is lower case. It keeps the standard Spanish of the HUD's other state words.

**D7. Tests.**
- They use `NetHarness` branches in one process, and the run HUD bound on the observer's branch, as `test_interact_prompt_net.gd` does. Time is skipped with `host._physics_process(...)`, as the reconnect tests do.
- The 1-player case runs on `OfflineMultiplayerPeer`: no drop is possible, no teammate row, and the crossing's end loads the coast cay at once with no countdown cut.

## Risks / Trade-offs

- **[`_dropped` and the flag disagree on the host]** → Both are written in the same two functions, and the host-plus-client tests assert both.
- **[The flag lags the drop by up to one 50 ms sync]** → The HUD row refreshes every frame, so it shows within a frame of arrival.
- **[Option A removes a player whose network failed just after the last crossing ended]** → They had the crossing's length plus up to 30 s, and they can join the next island as a new player ("Rejoin after removal"). The owner accepted this trade-off when they chose A.
- **[Edits to `coop_session.gd` collide with `structure-sync`]** → The edits are a few lines in named functions plus one const. Rebase on `main` before the PR.
- **[A new synced field changes the frame the art-invariance test snapshots]** → `test_art_sim_invariance.gd` reads the field list live, so the new field is covered rather than broken.

## Migration Plan

None. No save data or data files change. Rolling back reverts the field and the check.
