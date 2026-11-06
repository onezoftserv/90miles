# Proposal

## Why

Milestone A needs players to carry, use and craft the sandbar's survival basics: coconuts, rain water, driftwood and dry grass, a knife, a workbench and a fire. The survival-meters change already consumes "coconut +15", "rain cup +25", "a cup that revives" and "a lit fire within 5 tiles"; nothing produced them yet.

## What Changes

- A per-player `Inventory` component (12 slots, weight limit 30, stacking by stack size), host state replicated to every peer through `PlayerNet.net_inventory`.
- Pick-up through `Interactable` (`WorldItem`); what does not fit stays on the ground.
- Item use from data: `ItemUser` checks the `ConditionData` list and applies the `EffectData` kinds this change needs (METER_ADD, REVIVE, GIVE_ITEM, TAKE_ITEM; other kinds warn once and are skipped). The coconut needs a blade; hunger restores go through the meal rule; only fresh-water cups carry a REVIVE use.
- `Workbench` (station placed by the level), `Crafter` (runs `RecipeData`: inputs, tags, tools, fast tool, wear), `BuildSite` (shared deposits and progress), `Fire` (lights, joins `lit_fires`, burns 360 s, put out with a 2 s hold), `RainCatcher` (30 s of rain, once per squall).
- Host requests `craft`, `use_item` and `deposit` on `CoopSession`, rate limited per peer; the host's own player (solo included) is never limited.
- Content: items `coco`, `rain_cup`, `driftwood`, `dry_grass`, `knife`, `tarp`; recipes `fire`, `rain_catcher`; `crafting_tuning.tres`.
- `ClimateState.weather_id` (`WorldSky` writes it from the sky; tests may set it by hand).
- The solar still yields 1 cup per 12 in-game hours: `docs/ITEMS.md` changes from "1 per 2 in-game hours".

Out of scope: rafts and other recipes, identification, stashes and theft, swimming overload, cooking, the inventory and craft UI (ui-shell), squalls putting fires out (weather-daynight), replicating placed structures to clients (see design.md, Risks), the solar still itself.

## Solo

Every recipe here has no player-count condition. A build site accepts all deposits and all the work from one player. A solo player can open a coconut, drink, craft, light a fire and sit by it alone; all of it is tested with exactly one offline player.

## Provisional decisions

Taken from the build plan's recommended options; each waits for the owner's confirmation.

1. **Coconut opening** needs a blade capability (knife, later machete), spending 1 knife use per coconut. The "or a rock" alternative is not built (no `rock` item in the manifest). A solo level must place a knife (the hut).
2. **Coconut servings:** 1 per coconut, not the 2 `docs/ITEMS.md` mentions.
3. **Rain catcher inputs:** 1 tarp + 4 driftwood (the design says "tarp + 4 sticks"; driftwood stands for sticks). This adds `items/tarp.tres`, one file beyond the brief's list.
4. **Rain source:** Resolved: weather-daynight is on main, so the rain catcher recipe carries `produce_on_weather_id = squall` and `RainCatcher` reads it against `ClimateState.weather_id`, which `WorldSky` writes. `CraftingTuning.rain_weather_id` is removed.
5. **Stations:** the workbench is a placed scene; fire and rain catcher are `station = NONE` build sites. The workbench is proven with a fixture recipe because no shipped recipe needs it yet.
6. **Fire:** 30 s by friction; a carried `LIGHT_FIRE` item replaces that with its own tool time. Fire needs `input_tags {TINDER: 1}`, and dry grass carries TINDER.
7. **Revive:** per-item REVIVE use on a `can_target_others` use; coconut and rain cup now, still and well cup later. Reviving needs a downed or last-stand target.
8. **Meal rule:** a coconut restores hunger, so it counts as a meal (+10 energy).
9. **Use time:** `ItemUseData.time_s` is carried by the data; effects apply when the host receives the use (the UI will hold for the time).
10. **Numbers:** coco stack 5 / 0.5 kg; rain cup stack 4 / 0.5; driftwood stack 10 / 2.0; dry grass 10 / 0.2; knife 1 / 1.0 with 40 uses; tarp 1 / 2.0; fire 360 s; rain 30 s; action rate 10/s with a burst of 10.
11. **UI:** none beyond code calls; the inventory and craft UI belong to ui-shell.
12. **Placement of items for the manual check:** the movement playground gets a workbench and the supplies.
