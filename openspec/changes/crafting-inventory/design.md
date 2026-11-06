# Design

## Context

`ItemData`, `ItemUseData`, `EffectData`, `ConditionData` and `RecipeData` already exist; there were no item or recipe files. `Interactable` and the picker are in, and the host already runs every player's interaction (`PlayerBody` returns early unless it is the server), so a pick-up needs no request of its own. `PlayerBody.FIRE_GROUP` was waiting for a fire, and `MeterContext.crafting` for a crafter. See proposal.md for the numbers and the provisional decisions.

## Goals / Non-Goals

**Goals:** every behaviour in the spec is a GUT test with exact numbers, solo included; all numbers in `.tres`; the host alone changes inventories, sites and fires.

**Non-Goals:** UI, other recipes, replicating dynamically placed structures, weather (weather-daynight).

## Decisions

### Components
- `Inventory` (`Node`, child of the player): `InventorySlot`s (`RefCounted`), `add`, `remove_id`, `take_tag`, `spend_use`, `capability_slot`, `weight`, `to_net` / `from_net`. Items resolve through `GameState.content`; `register(item)` lets tests add fixtures without files. `Array[InventorySlot]` lives in a different class, so no self-typed array leaks.
- `ItemUser`, `ConditionCheck`, `EffectApplier` are static, `RefCounted` helpers: they interpret the data. Unbuilt kinds warn once and are skipped (effects) or false (conditions), so later data cannot crash a use. Condition scope is read as the player themself; pooled party scope waits for a feature that needs it.
- `Crafter` (`Node`, child of the player): `start` (workbench), `place_site`, `start_work`, `advance`, `cancel`. The host steps it in `PlayerBody._tick_meters`, before the meters tick, so `MeterContext.crafting` is current.
- `BuildSite`: deposits by id and by tag, progress 0..1 shared by every worker, completes into `scenes/structures/<recipe id>.tscn` (RecipeData's own convention) and frees itself.
- `Fire`, `RainCatcher`, `WorldItem`, `Workbench`: one scene each, drawn with colored rectangles (no textures, so CI needs no assets).

### Requests
`CoopSession.craft`, `use_item`, `deposit` send `@rpc("any_peer", "call_local", "reliable")` requests; the host handlers (`craft_for`, `use_for`, `deposit_for`) take the sender from the RPC, never the payload, check reach and the sender's own inventory, and are rate limited per peer (`PeerLimits.allow_action`, numbers in `CraftingTuning`). The host's own player is trusted. Station and site are named by a path relative to the session. No pick-up or put-out request: both are host-side `Interactable.interacted`.

### Sync
`PlayerNet.net_inventory` (`[id, count, uses]` per slot) is written by the host each physics frame and replicated by `StateSync` like the other shadow fields; clients call `Inventory.from_net` on every state.

### Rain
`ClimateState.weather_id` is new. `RainCatcher` compares it with `CraftingTuning.rain_weather_id` until the recipe's `produce_on_weather_id` can point at a `weather/` file.

## Risks

- **Structures are host-only.** Dynamically placed build sites, fires and catchers are not replicated to clients: there is no world spawner yet. Level-placed ones exist on every peer and the host's state is authoritative, but a client does not see a site the host's player placed. The next world-sync change (or island-generation) must add a spawner; the placement request is left out for the same reason.
- `weather-daynight` (parallel branch) also touches `ClimateState`; the field here is one documented line.
- Rate-limit numbers (10/s, burst 10) are provisional.
