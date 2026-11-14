# Proposal

## Why

When a co-op player dies today, their camera stays on their own body, which lies still while the others play on. They can watch nothing their team does until the last of them dies and the run summary shows. The owner asked on 2026-11-08 that a dead co-op player watch a living teammate instead, with a key that cycles between teammates. This is Milestone G in `TASKS.md` and answers question 7 of the archived `ui-shell` proposal, which noted "Until that Milestone G task ships, the camera stays on their own body".

## What Changes

**What a dead co-op player sees**
- The view follows a living teammate's body, inside that body's own camera limits: the island, or the crossing's sea while they ride.
- On death the view goes to the nearest living teammate.
- Two new input actions, "spectate previous" and "spectate next", step through the living teammates in the teammate list's order and wrap round. The default bindings are A/D, ←/→, the D-pad's ←/→ and the mouse wheel; this is an owner decision, Q1.

**The HUD while watching**
- The bottom band, where the inventory strip sits, reads "Mirando a: Papo" with the keys that switch. The wording is an owner decision, Q3.
- The meters panel shows the watched teammate's meters (owner decision Q2).
- The inventory strip and the interact prompt are hidden.
- Quick chat still works.

**Who can be watched**
- A living teammate is one who is not dead and not waiting out of play on the shore.
- A disconnected teammate is watched only when no connected one is alive, and the line then marks them "(desconectado)".
- When the watched teammate dies, is removed or leaves play, the view moves to the nearest one left. With nobody left, the view goes back to the player's own body. The run summary still shows when every player still in the run is dead, as before.

**Rejoiners, late joiners and the network**
- A player who takes back a body that died while they were away watches at once.
- A client who joined late watches like anyone else when they die.
- None of this is sent over the network: each peer works it out from replicated state it already has (`dead`, `net_dropped`, `left_island`, positions).

**Solo:** unchanged. A solo death goes straight to the run summary, with no watching. A 1-player test checks this.

**Owner decision Q4:** a rider waiting on the next island's shore, who today stares at the empty sea, could watch a teammate who is still playing in the same way. This closes the coast-cay follow-up "a spectate camera for waiting riders".

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ui-shell`: adds the requirement "Spectating a teammate": what a dead co-op player's view follows, how it switches, what the HUD shows meanwhile, and that solo is unchanged. It is a new requirement rather than an edit to "Screen flow" or "HUD layout". "Screen flow" still holds as written: the summary shows when every player still in the run is dead. The unarchived `dropped-teammate-state` change only adds to `ui-shell`, so nothing collides.

## Impact

- New `game/scripts/ui/spectate_view.gd` (`SpectateView`): picks whom the local player watches and switches cameras on the bodies. It holds the watched body rather than its peer id, because removal frees bodies and a rejoin changes the peer.
- `game/scenes/ui/run_hud.gd` and `.tscn`: own a `SpectateView` and update it each frame, re-asserting the camera after `player_rebound`. They also gain a "Watching" label in the bottom band, swap the meters panel's source, hide the strip and the prompt while watching, and handle the two actions.
- `game/scenes/ui/inventory_strip.gd`: hides while its owner is watching, as it already hides for a waiting rider.
- `game/project.godot`: the `spectate_prev` and `spectate_next` actions.
- `game/resources/hud_text.tres` and `game/scripts/ui/hud_text.gd`: the lines `watching`, `watching_dropped` and `watch_keys`.
- No edits to `coop_session.gd`, `game_shell.gd`, `player.gd` or `net_manager.gd`. No new RPC, synced property or autoload.
- Tests:
  - `test_spectate_view.gd`: offline, with several bodies.
  - `test_dead_spectate_net.gd`: host plus clients over NetHarness.
  - A 1-player shell test: death goes to the summary.
  - A two-process manual run of the real shell on UDP 7787.
