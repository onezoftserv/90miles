# Proposal

## Why

In co-op a client draws palms, fires and rain catchers from its own copy of their state, and the host never sends that state. The art-pass host-plus-client playthrough (2026-11-13; `art-pass` design D18's risk note and K89, `art-pass-followups` task 3.3) showed it. On client A, the climbed nest palm kept drawing its last coconut. A fire the host had put out still burned, and the rain catcher stayed empty after a squall had filled it on the host. A late joiner is worse off: a fire comes with its spawn payload's `lit: true` even after it went out, and every palm shows the layout's full count. The same run left one "unconfirmed" note: a client that joined after the raft was built and launched listed a marked raft site and no raft. That joiner joined during the crossing, while the host's sandbar had a fresh, empty site and the raft was at sea. The joiner showed the host's state, and `test_build_site_net.gd` already covers that case with a hand-made launch.

## What Changes

- The host's state of a palm's coconuts, a fire (lit or out) and a rain catcher's cups reaches every client while it plays, and every client that joins or rejoins later. A client never changes these itself; it shows what the host sends.
- On a client a fire's interaction and its place among the lit fires follow the host's `lit`, as its look already does. The "[E] Apagar" prompt shows only over a fire that is lit on the host.
- A late joiner on the second island gets that island's palm counts after it has loaded the island.
- The raft and build sites keep their current sync (crafting-inventory "Placed sites on every peer", escape-routes "Raft build site"). A new regression test plays the real island with a real route start: a joiner during the crossing gets a marked site and no raft, matching the host, and a joiner before the launch gets the raft.
- Solo is unchanged: nothing is sent. The single player is their own host, so their palms, fire and catcher are the host's state.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`: adds "Structure state on every peer" (palms, fires and rain catchers, live and for late joiners and rejoiners; solo sends nothing), beside "Spawning", whose synchronizer-based late join it extends to the state a spawned structure holds.

## Impact

- `game/scenes/structures/fire.gd` (`lit` side effects in a setter, so a synced value takes effect), `game/scenes/structures/rain_catcher.gd`, `game/scripts/crafting/site_placer.gd` (a synchronizer on each spawned structure, and the host's fire lit before its spawn is sent).
- `game/scenes/levels/palm.gd` (a `coconuts_changed` signal), `game/scenes/levels/sandbar_island.gd` (keeps its palms in order and adds the palm sync to the session in `furnish`), a new `game/scripts/net/palm_sync.gd` (a session child with host-to-client RPCs, freed with the island's other furniture on travel).
- `game/scenes/net/coop_session.gd`: one host signal emitted at the end of `request_join`, after the world state, beside `send_progress`, and `_spawn_entity` passing one argument fewer to `SitePlacer.from_payload` (its `on_host` goes). No other session code changes.
- Tests: a 1-player offline test, and host-plus-client tests (live client, late joiner, rejoiner, joiner on the second island, forged messages, the raft regression on the real island).
- No new autoload, no new content, no change to the backend. `net_peers.gd`, `net_manager.gd` and the join screen are untouched.
