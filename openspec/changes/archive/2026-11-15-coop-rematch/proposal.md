# Proposal

## Why

Today "Otra vez" on the run summary works only in solo. A co-op summary, host or client, offers only "Volver al inicio", so a party that wants another run has to go back to the title, host again and have every friend type the address again. The run-end change left this open (`TASKS.md` §4: "A co-op rematch with the same peers (its own change: a host RPC, every client rebuilding its session)"). Now that the net-platform seam (#51) installs a peer once and the shell builds a run on whatever peer is installed, the party can start again on the connections it already has.

## What Changes

- **The host's co-op summary offers "Otra vez"** beside "Volver al inicio", with the focus, as solo does. Picking it ends the host's run and opens a new lobby on the same connection: the port stays open, NetManager is asked for nothing, and the new run has its own run seed.
- **Every client still connected follows by itself, and no one reconnects.** The host sends one call to every client. Each client ends its run and builds a new session on the connection it already has. That session sends the usual join request, with the same name and player id, so the host knows every player as before. The client's lobby shows at once and fills in when the host answers.
- **Each player keeps their look slot.** The host carries every connected player's slot from the run that ended into the new run's spawns, by peer id, since nobody reconnects. A player new to the party takes the lowest slot nobody holds or is keeping.
- **A client that left before the rematch is not pulled back.** Only connected peers get the call. A player who left, or a dropped player still waiting out their 90 s, can join the new lobby as anyone joins, with a new look slot.
- **Clients cannot start a rematch.** A client's summary offers only "Volver al inicio", with a note saying the host can start again (owner Q2). A rematch call from anyone but the host is ignored. A client's summary still stays when the host leaves.
- **The rematch goes through the lobby** (owner Q1): the host presses "Empezar viaje" again, so the host can wait for everyone and anyone may leave. The lobby is open as any lobby is (owner Q3).
- **Message order is part of the rule.** The host frees its old run first, so the old run's despawns reach every client. It then sends the call, and opens the new lobby last. Each client rebuilds while it handles the call. So nothing from the host's new run lands in a client's old session, which would lose the new island's pick-ups. A spike showed exactly that: with the host's lobby opened first, the client had 0 of the sandbar's 20 pick-ups. Messages from a client's old session that reach the host's new one are refused by the checks that already exist.
- **Solo is unchanged.** "Otra vez" still starts a clean solo run at once, offline, with no lobby. A host alone (1 player, hosting) gets the co-op "Otra vez" and a new lobby with only themselves in it.
- **Owner decisions, 2026-11-14:** the owner accepted the recommended option, A, for each of Q1 to Q4 (design.md).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`: adds "Rematch with the same party": the host's call, every connected client rebuilding its session on the same connection and joining again with the same identity, look slots carried, a client that left not pulled back, client calls ignored, the message order, and solo unchanged.
- `endings-progression`:
  - adds "Rematch from a co-op summary": the host's "Otra vez" with the focus, the client's note, and a host alone;
  - "Restart from the summary" now points to it instead of saying a co-op summary offers only "Volver al inicio";
  - "A fresh run starts clean": the rematch's run starts clean on every peer, and a host plus client test covers it beside the 1-player one.
- `ui-shell`:
  - "Screen flow": after the run summary, a co-op host's "Otra vez" opens the new lobby on every connected peer;
  - "Run summary": rewritten to point at endings-progression's summary requirements, so that one spec owns the summary's content (`TASKS.md` §4 asked for this the next time the summary changed).
- `art-pass`:
  - adds "Look slots in a rematch": each connected player keeps the slot they had when the run ended, and a newcomer takes the lowest slot nobody holds or keeps;
  - "Player look slots" points to it. The lowest free slot rule stays for everyone else.

## Impact

- New `game/scripts/net/run_rematch.gd` (`RunRematch`): a small node, the shell's child named `Rematch`, with the host's call and its sender checks. It sits outside `CoopSession` because the session is what the rematch replaces (design D2). No new autoload.
- `game/scenes/shell/game_shell.gd`:
  - the host's `_rematch()`;
  - the client's handler for the call;
  - "Otra vez" or the client's note on the co-op summary;
  - the client's lobby shown at once.
- `game/scenes/shell/summary_screen.gd`: a `show_waiting_for_host()` note.
- `game/scenes/net/coop_session.gd`: a host-only `carried_looks` map, read when a player spawns, and `look_slots()`, which hands it over. New functions only. `request_join` (rewritten by the open PR #57) and the intent path (intent-delivery, #55) are untouched.
- Tests:
  - A new `game/tests/helpers/shell_harness.gd`: real shells for the host and clients in one process, each on its own multiplayer branch.
  - A new `test_coop_rematch_net.gd`, host plus client:
    - lobby, roster, identity, look slots, the new seed, pick-ups and creatures matching;
    - a client still in its run;
    - the host starting at once;
    - a client who left;
    - a client's call ignored.
  - `test_run_restart.gd`: the co-op buttons, a host alone, and 1-player offline cases.
  - `test_run_rematch.gd`: unit tests of `RunRematch`.
  - `test_coop_session` look-slot cases.
- A manual two-process check (`game/tests/manual/coop_rematch_run.gd`) on UDP 7792.
- `TASKS.md` §4.
