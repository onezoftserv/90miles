# Tasks

## 1. Spec and data

- [x] 1.1 Write the proposal, spec delta and design; `openspec validate crafting-inventory --type change --strict` passes
- [x] 1.2 RED: `test_crafting_content.gd` (files load, validate, numbers); add `CraftingTuning` and `crafting_tuning.tres`
- [x] 1.3 Add items `coco`, `rain_cup`, `driftwood`, `dry_grass`, `knife`, `tarp` and recipes `fire`, `rain_catcher`
- [x] 1.4 Import, smoke and GUT pass

## 2. Inventory and pick-up

- [x] 2.1 RED: `test_inventory.gd`, `test_world_item.gd`
- [x] 2.2 `Inventory`, `InventorySlot`, `WorldItem`; `Inventory` and `Crafter` children of the player scene
- [x] 2.3 Import, smoke and GUT pass

## 3. Using items

- [x] 3.1 RED: `test_item_user.gd` (blade, drink numbers, meal, revive rules)
- [x] 3.2 `ItemUser`, `ConditionCheck`, `EffectApplier`
- [x] 3.3 Import, smoke and GUT pass

## 4. Workbench, build sites, fire, rain catcher

- [x] 4.1 RED: `test_crafter.gd`, `test_build_site.gd`, `test_fire.gd`, `test_rain_catcher.gd`
- [x] 4.2 `Crafter`, `Workbench`, `BuildSite`, `Fire`, `RainCatcher`; `ClimateState.weather_id`; `MeterContext.crafting` from the crafter
- [x] 4.3 Import, smoke and GUT pass

## 5. Co-op and solo

- [x] 5.1 RED: `test_crafting_net.gd` (client craft applied by the host, forged request ignored, inventory sync), `test_crafting_solo.gd`
- [x] 5.2 `CoopSession` requests, `PeerLimits.allow_action`, `PlayerNet.net_inventory`
- [x] 5.3 Movement playground: a workbench, a coconut, a knife, driftwood, dry grass, a tarp
- [x] 5.4 Import, smoke, GUT and a 300-frame run pass
- [x] 5.5 Tick `TASKS.md`; `docs/ITEMS.md` still rate

## 6. Sky integration (weather-daynight on main)

- [x] 6.1 RED: `test_crafting_sky.gd` (recipe names squall, catcher fills from the sky's weather cycle, fire is company at night by the sky clock, 1 player)
- [x] 6.2 `produce_on_weather_id = squall` on the rain catcher recipe; `CraftingTuning.rain_weather_id` removed; `WorldSky` writes `ClimateState.weather_id`
- [x] 6.3 Movement playground keeps the sky clock; doc comment fixed
