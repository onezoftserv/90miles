# Spec Delta

## MODIFIED Requirements

### Requirement: Inventory
Players SHALL have 12 slots and a weight limit (30); swimming with weight > 15 drains energy ×2 and drops a random heavy item at energy 0. A slot holds one item id and a count up to that item's stack size; items with more than 1 durability do not stack and each keeps its own uses. Each player's inventory lives on the host and is synced to every peer; clients never change it themselves. Inventories are per player, so a solo player carries everything they use.

#### Scenario: Swimming overloaded
- GIVEN a player carrying weight 20
- WHEN they swim until energy reaches 0
- THEN energy drained at ×2 the whole way and a random heavy item is dropped at energy 0

#### Scenario: Pick up a coconut into an empty inventory
- GIVEN a solo player with an empty inventory standing within 1 tile of a coconut on the ground
- WHEN they press interact
- THEN slot 0 holds 1 coco, the coconut is gone from the ground and the carried weight is the coconut's weight (0.5)

#### Scenario: Stacking and the weight limit
- GIVEN a player whose slots hold coconuts up to the stack size (5) in one slot
- WHEN they pick up one more coconut
- THEN it goes into the next empty slot; and when the pick-up would take carried weight above 30 or no slot can take it, the item stays on the ground

#### Scenario: Another peer's inventory is shown, not owned
- GIVEN a client whose player holds 2 driftwood on the host
- WHEN the client reads its inventory
- THEN it shows the host's 2 driftwood and has no way to change it

### Requirement: Recipes
Recipes SHALL be `.tres` with inputs, output, station (none, workbench, fire), time, and skill multiplier. Core recipes per `docs/GAME_DESIGN.md` §6. A craft needs every input in the crafter's own inventory and every tool capability carried by the crafter; it consumes the inputs (and one use of each required tool per tool wear) only when it completes. A fast tool, when carried, replaces the time with that item's tool time. No recipe needs a second player: a solo player can craft every recipe alone.

#### Scenario: Workbench recipe
- GIVEN a recipe `.tres` with station workbench
- WHEN a player holding its inputs crafts it at a workbench
- THEN after the recipe's time the inputs are consumed and the output is added

#### Scenario: Missing inputs
- GIVEN a player at a workbench missing one input of a workbench recipe
- WHEN they try to craft it
- THEN nothing starts and nothing is consumed

#### Scenario: A solo player crafts every recipe
- GIVEN one offline player holding the inputs and tools of every recipe in `game/resources/recipes/`
- WHEN they craft each one at its station or build site
- THEN every recipe completes with that one player

### Requirement: Shared builds
Build sites (raft, still, rain catcher, fire) SHALL accept deposits from any player and show progress to all. A build site is placed by the first player who starts a build-site recipe; deposits move matching inputs from the depositor's inventory; work advances only while at least one player works it and its inputs are complete. One player can deposit everything and do all the work.

#### Scenario: Two players feed a still
- GIVEN a still build site
- WHEN two different players each deposit materials into it
- THEN both deposits count toward the build and every player sees the same progress

#### Scenario: One player builds a fire
- GIVEN a solo player holding 3 driftwood and 1 dry grass
- WHEN they place a fire build site, deposit everything and work it for the recipe's time (30 s)
- THEN the fire is built and lit, and 3 driftwood and 1 dry grass have left their inventory

## ADDED Requirements

### Requirement: Pick-up
Items on the ground SHALL be picked up through the player-movement interaction (nearest interactable within 1 tile, instant unless the item sets a hold time). The host applies the pick-up; if the inventory cannot take the item it stays on the ground. Items with pick-up disabled cannot be picked up. Pick-up effects of the item apply to the player who took it.

#### Scenario: Solo pick-up
- GIVEN one offline player next to driftwood on the ground
- WHEN they press interact
- THEN the driftwood is in their inventory

### Requirement: Using items
An item's use SHALL check every condition of that `ItemUseData`, apply its effects in order and, if it spends a use, take one use (removing the item at 0 uses and adding its remainder item). A failed condition stops the use without spending anything. A coconut gives thirst +15, hunger +5 and, as a meal, energy +10; a rain cup gives thirst +25. The use's `time_s` belongs to the caller (the UI holds the button); effects apply when the host receives the use.

#### Scenario: Opening a coconut needs a blade
- GIVEN a solo player holding a coconut and no item with the open-coconut capability
- WHEN they try to drink it
- THEN nothing happens and they still hold the coconut; with a knife they drink it, gain thirst +15 and hunger +5 and energy +10, the coconut is gone and the knife has one use less

#### Scenario: Drinking a rain cup
- GIVEN a player with thirst 50 holding a rain cup
- WHEN they drink it
- THEN thirst is 75 and the cup is gone

### Requirement: Fresh-water revives
Only fresh-water cups SHALL revive: coconut, rain cup, still cup and well cup. Seawater and rum never revive. A reviving cup used on a downed teammate within 1 tile, or by a solo player on themselves during a last stand, stands them up at the survival-meters revive health (30) and then applies its drink effects; used on someone who is standing it does nothing and spends nothing.

#### Scenario: Seawater does not revive
- GIVEN a downed teammate and a player holding a seawater cup and a rain cup
- WHEN the player tries the seawater cup on the teammate
- THEN the teammate stays downed; the rain cup revives them

#### Scenario: Solo last stand
- GIVEN a solo player in a last stand holding a rain cup
- WHEN they use it on themselves
- THEN they stand at 30 health

### Requirement: Workbench
A workbench (a flat rock or a wreck table placed by the level) SHALL be a station: a player within 1 tile can craft any known workbench recipe whose inputs and tools they carry. Crafting sets the crafting state for the hunger drain while it runs, and stops if the player leaves the bench's reach.

#### Scenario: Solo workbench craft
- GIVEN one offline player at a workbench holding a workbench recipe's inputs
- WHEN they craft it and stay for its time
- THEN the output is in their inventory

### Requirement: Fire
A fire SHALL be a structure built from its recipe (3 driftwood + 1 tinder; 30 s by friction, less with a carried fire-lighting tool). When built it lights: players within 5 tiles get the fire-lit morale bonus (+5), and while lit it counts as company for the night morale drain within 5 tiles. It burns 360 s (12 in-game hours), then goes out as embers that are no company; any player can put it out with a 2 s interaction.

#### Scenario: A lit fire keeps a solo player company
- GIVEN one offline player with morale 50 at night, 3 tiles from a fire they built
- WHEN 60 s pass
- THEN morale is still 50; after the fire is put out, 60 more seconds take morale to 45

#### Scenario: A fire burns out
- GIVEN a fire lit 360 s ago
- WHEN the next second passes
- THEN it is out and no longer counts as company

### Requirement: Water structures
A rain catcher SHALL yield rain cups while it rains (squall): 1 rain cup into the catcher after 30 s of continuous rain, at most once per squall, held there until a player takes it. A solar still SHALL yield 1 still cup per 12 in-game hours (360 s), which changes `docs/ITEMS.md` ("1 per 2 in-game hours"); the still itself is built by a later change. Until weather-daynight drives the weather, rain is read from the weather id the level sets on the climate.

#### Scenario: A rain cup fills during a squall
- GIVEN a built rain catcher and a solo player
- WHEN a squall has been falling on it for 30 s
- THEN the catcher holds 1 rain cup and the player can take it

### Requirement: Host-authoritative crafting
Pick-ups, item uses, deposits, crafts and putting out fires SHALL be requests a player sends to the host; the host checks the sender's own inventory, reach and the recipe, applies the result and syncs it. A client never changes an inventory, a build site or a fire itself. A solo player is their own host and nothing is sent over a network.

#### Scenario: A client's craft is applied by the host
- GIVEN a host and one client at a workbench holding a recipe's inputs
- WHEN the client asks to craft it
- THEN the host consumes the client's inputs and adds the output, and the client sees the same inventory

#### Scenario: A forged request does nothing
- GIVEN a client that asks to craft without the inputs, or to use a slot it has nothing in, on another player
- WHEN the host receives it
- THEN nothing changes

#### Scenario: A downed player cannot craft, deposit or use items
- GIVEN a downed co-op player holding a recipe's inputs and a rain cup, next to a workbench and a build site
- WHEN the host receives their request to craft, deposit or use an item
- THEN the host refuses it and nothing is consumed, while a teammate within reach can still revive them with a rain cup or a coconut and a knife
- AND a solo player in a last stand, who has no teammate, may drink a reviving cup they carry to stand up, but cannot craft, deposit or use any other item
