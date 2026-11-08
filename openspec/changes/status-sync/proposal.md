## Why

A player's statuses (bleeding today; burning, poison and the rest later) live only on the host. `SurvivalMeters.statuses` is a host-side dictionary, and the player's synchronizer sends the six meters and the downed and dead states but not statuses. So when a shark bites a client's player, the host knows they bleed, which makes them the shark's next target, and the client's own game doesn't: `has_status(BLEEDING)` is false there. Found while building `crossing-late-join`; the user queued it (2026-11-08).

## What Changes

- **Statuses are one replicated value.** `SurvivalMeters` keeps them as `status_flags`, one bit per `DataEnums.Status`. The player's synchronizer sends it to every peer like the meters, and a late joiner gets it with the body.
  - `has_status` and `set_status` keep their names and meaning. Only the host sets a status; a client only reads it.
- **`statuses_changed` is emitted on every peer** whenever the flags change, whether the host set them or the sync brought them. Anything that shows a status can listen.
- **Solo is unchanged.** One player offline sets and reads statuses on their own peer, as before.

**Decision (asked 2026-11-08, waiting for the owner):** whether this change also shows a red "Sangrando" tag under the local player's meter bars while they bleed. The recommendation is yes: the change otherwise has no visible effect, and a bleeding swimmer is who the shark goes for.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `survival-meters`: adds "Statuses are synced". A player's statuses are host-authoritative and reach every peer, as the meters do.

## Impact

- **Code:**
  - `game/scripts/components/survival_meters.gd`: `status_flags`, `statuses_changed`, and the bit-based `has_status` / `set_status`, replacing the host-only `statuses` dictionary, which nothing outside the class read.
  - `game/scenes/player/player.tscn`: one more replicated property.
- **Network:** one int in the player's existing synchronizer. No RPC, and no intent change.
- **Tests:**
  - Offline, 1 player: flags, signal, and that a solo shark bite still bleeds.
  - A new `test_status_net.gd` (ENet): a client sees its own bleeding and its clearing, and a late joiner sees a teammate's bleeding.
