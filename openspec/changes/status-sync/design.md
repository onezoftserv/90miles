## Context

- `SurvivalMeters` (survival-meters) holds the six meters and the downed, last-stand and dead states as plain properties. The player scene's `MultiplayerSynchronizer` (`player.tscn`, `SceneReplicationConfig_state`) sends them from the host to every peer, spawn values included, so a late joiner gets them too.
- Statuses are a host-only `Dictionary[int, bool]` (`statuses`) behind `has_status` / `set_status`.
  - Nothing outside the class reads the dictionary.
  - `has_status` is read by `ConditionCheck`, the shark strike checks (`PatrolCircleStrike`, `ScriptedThreats`) and tests.
  - `set_status` is called by `Crossing.bite_swimmer` and `CreatureWorld`.
- `DataEnums.Status` has 12 values, from `NONE` to `SUNBURN`.

## Goals / Non-Goals

**Goals:**
- Every peer reads the host's statuses for every player, from the spawn on.
- A signal any peer's UI can listen to.

**Non-Goals:**
- How a status starts, lasts or ends. Bleeding still has no cure or timer; that comes with bandages.
- Icons or tags for the other statuses: each comes with the change that makes it reachable.

## Decisions

### Reference games

- **Borrowed from DCSS, `crawl-ref/source/tileweb.cc`, `TilesFramework::_send_player()`.**
  - The server sends the player's statuses (the `status` array of status lights) whenever `_update_statuses` sees a change, and all of them on a full update for a new spectator.
  - Clients only show what arrives.
  - Here, statuses travel in the player's existing replicated state, are sent when they change, and come with the spawn for a late joiner.
- **Borrowed from Brogue CE, `src/brogue/Rogue.h` (`status[NUMBER_OF_STATUS_EFFECTS]`) and `src/brogue/IO.c`, `printMonsterInfo()`.**
  - A creature's statuses are a fixed array indexed by the status enum, and the sidebar walks it.
  - Here, a fixed set indexed by `DataEnums.Status`, so one bit per status in one int.
- **Borrowed for the HUD:** Shattered Pixel Dungeon, `actors/buffs/Bleeding.java` (`icon()`) and `ui/BuffIndicator.java`. A buff only names its icon, and the indicator draws what the hero has. Here, the HUD tag only reads the synced status.
- **Rejected:** SPD's `Buff` as an actor with its own `act()` on every peer. Statuses here are host state, and a client must never run their effects.

### One int of bit flags

- `status_flags: int`, with bit `1 << status` set while that status is on.
- **Why an int and not the dictionary:**
  - A synchronizer sends a plain int with no type surprises. A typed `Dictionary[int, bool]` set by the sync on a client would have to convert on assignment.
  - The value changes rarely, so ON_CHANGE-style traffic stays tiny.
  - There are 12 statuses, far below 63 bits.
- Its setter emits `statuses_changed(flags)` when the value changes, on the host when `set_status` changes it and on a client when the sync does.
- `has_status` and `set_status` keep their contract. `set_status` ignores `NONE` and anything outside the enum.
- The `statuses` dictionary goes away. Nothing outside `SurvivalMeters` read it.

### Sync

- `player.tscn` gains `SurvivalMeters:status_flags` in `SceneReplicationConfig_state`, sent on spawn and replicated like the other meter properties.
- The host is the synchronizer's authority, as for the meters, so a client's own change would never be sent, and the host's value overwrites it.

### The HUD tag

- `meters_hud.tscn` gains a hidden `Label` "Sangrando" (red, the theme's pixel font at 8 px) as the last row of the bars panel, so it sits under Salud at the top-left. `MetersHud.bars()` still lists only `MeterBar` rows.
- `MetersHud.bind` sets it from `has_status(BLEEDING)`, and `statuses_changed` updates it; unbinding disconnects. `RunHud` already rebinds the meters HUD to the local player (also after a rejoin), so the tag needs nothing there. The inventory-hud change works in `run_hud.gd` and the HUD's bottom band, not here.

### Tests

- **Offline, 1 player (`test_status_flags.gd`):**
  - `set_status` sets and clears its bit and emits `statuses_changed` once per change, with nothing for a repeat.
  - `NONE` and out-of-range values change nothing.
  - A solo crossing shark bite still sets bleeding.
- **Offline, 1 player (`test_meters_hud.gd`):** the tag shows only while bleeding (not for another status), shows at once when binding a bleeding player, is red, under the bars and in the pixel font, keeps the panel in the corner, and stops following an unbound node.
- **ENet (`test_status_net.gd`, `NetHarness`):**
  - The host bites a client's swimming player in a crossing. The client's own body has `BLEEDING`, emitted `statuses_changed`, and a `MetersHud` bound to it shows the tag. Clearing it on the host clears both on the client.
  - A late joiner sees the host's bleeding.

## Risks / Trade-offs

- **[Replication interval]** Statuses ride the 0.05 s player sync, so a client learns of a bite up to one interval later. → That is the same delay as the health the bite takes.
- **[Removing `statuses`]** Removing a public field could break a caller outside the class. → The repo's only readers go through `has_status` / `set_status`; the search is in Context.
